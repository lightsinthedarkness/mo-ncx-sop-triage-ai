# Spec: Multimodal SOP Ingestion Pipeline (`sop-ingestion`) — V1

- **Module ID:** `sop-ingestion` (ref: [capability-map.md](capability-map.md))
- **Design Reference:** [DESIGN.md](../DESIGN.md) (Design 2.3 — [ADR-001](../docs/adr/ADR-001-hybrid-python-rust-and-jev-orchestrator.md))
- **PRD Reference:** [PRD.md](../PRD.md) (PRD 2.3 — FR-1)
- **Quality Contract:** [CONSTRAINTS.md](../CONSTRAINTS.md)
- **Status:** Approved & Hardened via `doubt-driven-development` (2026-11-26 — all 14 adversarial findings reconciled; ready for coding gate)

---

## 1. Objective

Membangun modul *ingestion* multimodal (`sop-ingestion`) yang mengubah file dokumen SOP mentah milik tim MO NCX (`.docx`, `.pdf`, `.xlsx`, `.pptx`, `.md`, `.sh`, `.sql`, `.xml`, `.py` — *case-insensitive*) dari segmen **`EBIS`**, **`RETAIL`**, **`WIBS`**, atau **`GENERAL`** *(SOP lintas segmen yang dapat diakses oleh seluruh segmen pada Modul #2)* menjadi kumpulan **Structured SOP Chunks** (`SopChunk`) dan **Stored Screenshot Assets** (`ExtractedAsset`) yang siap diindeks oleh modul `sop-memory-rag`.

**Masalah nyata yang diselesaikan:**
1. Dokumen SOP teknis MO NCX berisi **puluhan gambar *screenshot* terminal/UI `before changes` & `after changes`** di sela-sela teks pendek, sering kali dengan sub-judul berulang antar langkah. Gambar harus diekstrak berurutan dan ditautkan ke chunk lewat **posisi blok (`block_index` + `section_path`)**, bukan hanya mencocokkan nama sub-judul.
2. Blok perintah CLI Linux (`/opt/Siebel16/...`, `keytool`, `chmod`), konfigurasi XML (`<Connector .../>`), variabel `export`, serta tabel **tidak boleh terpotong di tengah** atau berubah karakternya (mis. `--` berubah menjadi em-dash, atau karakter CLI terkena *Markdown escaping* `\_`, `\<`, `\-`).
3. Setiap dokumen wajib membawa **ID deterministik & metadata temporal** (`doc_id` stabil lintas versi, `chunk_id`/`asset_id` menyertakan `doc_version`, 1 stempel `valid_from` seragam per proses *ingest*, `valid_until`, `is_active`, `segment`, `role_acl`) agar Modul #2 (`sop-memory-rag`) bisa menonaktifkan versi SOP lama tanpa *split-brain*.

---

## 2. Tech Stack

- **Language:** Python 3.12+ (strict type hints, `mypy` clean tanpa `# type: ignore`)
- **Schema & Validation:** `pydantic>=2.10`
- **Document Parsing:** `docling>=2.81` (`DocumentConverter`, `PdfFormatOption`, `PdfPipelineOptions(do_ocr=True, do_table_structure=True, generate_picture_images=True, enable_remote_services=False)`, `PdfBackendOptions(do_char_normalization=False)`). Untuk `.docx`, teks blok CLI/XML diambil dari teks blok mentah agar terhindar dari *Markdown escaping* (`\_`, `\<`, `\-`).
- **Code/Script Parsing (V1):** Python `ast` (untuk `.py`) + *deterministic structured block splitter* (untuk `.md`, `.sh`, `.sql`, `.xml`) dengan *encoding fallback* (`utf-8-sig` → `cp1252`).
- **Chunking:** `CommandSafeChunker` (`max_chars=1200` ~300–400 token aman untuk `BAAI/bge-m3`, `overlap_chars=150` dilarang memotong blok CLI/XML/tabel, `max_atomic_chars=4800` agar blok CLI/tabel besar tetap utuh).
- **Vision Captioning Interface:** `VisionCaptioner` (`typing.Protocol`) dengan 2 implementasi:
  - `OpenAICompatibleVisionCaptioner`: menghubungi endpoint Vision lokal via LiteLLM/Ollama/vLLM dengan **strict host allowlist** (hanya loopback `localhost`/`127.0.0.1`/`::1`, IP privat RFC1918, atau env `VISION_ALLOWED_HOSTS`), `follow_redirects=False`, `timeout_seconds=30.0`, retry 1x, dan *non-destructive fallback* (`caption_status="failed"`) jika gagal.
  - `NoopVisionCaptioner`: mode default dev lokal tanpa GPU (`VISION_MODE=noop`, `caption_status="noop"`).
- **Asset Storage Interface:** `AssetStore` (`typing.Protocol`) + `S3ClientProtocol` (`typing.Protocol`) agar `mypy` lulus tanpa mewajibkan paket `minio` terpasang saat dev lokal:
  - `LocalFsAssetStore` (default dev lokal → `.data/assets/`, `storage_uri="local://<relpath>"`, wajib sanitasi `doc_id` & `filename` + cek `resolved.is_relative_to(root.resolve())`).
  - `MinioAssetStore` (staging/produksi → `storage_uri="s3://<bucket>/<key>"`).

---

## 3. Commands

```powershell
# Setup virtual environment & install module dependencies
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -e ".[dev]"

# Lint, Typecheck & Secrets Scan (Blocking Gates — CONSTRAINTS.md)
ruff check src tests
mypy src
gitleaks dir . --redact --no-banner

# Unit & Integration Tests (Coverage >= 80%)
pytest tests/sop_ingestion --cov=src/sop_ingestion --cov-fail-under=80

# Dry-run CLI ingest 1 file SOP (output ke .scratch/ yang ter-gitignore)
py -m sop_ingestion.cli ingest --file "path/to/sample.docx" --segment EBIS --version 1 --output-dir .scratch/ingest-preview
```

---

## 4. Project Structure

```text
c:/Users/Administrator/LLM/
├── pyproject.toml
├── src/
│   └── sop_ingestion/
│       ├── __init__.py
│       ├── models.py        # Seluruh kontrak data publik & SopIngestionError
│       ├── assets.py        # AssetStore Protocol, S3ClientProtocol, LocalFsAssetStore, MinioAssetStore
│       ├── vision.py        # VisionCaptioner Protocol, NoopVisionCaptioner, OpenAICompatibleVisionCaptioner
│       ├── parser.py        # DoclingSopParser (.docx/.pdf/.xlsx/.pptx) + ScriptSopParser (.md/.sh/.sql/.xml/.py)
│       ├── chunker.py       # CommandSafeChunker (CLI/XML/tabel utuh + positional asset linking)
│       ├── pipeline.py      # SopIngestionPipeline.ingest_document() → IngestResult
│       └── cli.py           # CLI dry-run (`py -m sop_ingestion.cli ingest ...`)
└── tests/
    └── sop_ingestion/
        ├── conftest.py      # Synthetic fixtures (.docx, .pdf, .xlsx, .pptx, .sh, .py, .md, corrupt, empty — zero real credentials!)
        ├── test_models.py
        ├── test_assets.py
        ├── test_vision.py
        ├── test_parser.py
        ├── test_chunker.py
        └── test_pipeline.py
```

---

## 5. Code Style & Complete Public Data Contracts

Seluruh kontrak data publik didefinisikan eksplisit di `src/sop_ingestion/models.py`:

```python
from datetime import datetime
from enum import StrEnum
from typing import Literal
from pydantic import BaseModel, Field


class SopSegment(StrEnum):
    EBIS = "EBIS"
    RETAIL = "RETAIL"
    WIBS = "WIBS"
    GENERAL = "GENERAL"  # Cross-segment SOP visible to EBIS, RETAIL, and WIBS in Module 2


class SopIngestionErrorCode(StrEnum):
    FILE_NOT_FOUND = "FILE_NOT_FOUND"
    INVALID_PATH = "INVALID_PATH"
    UNSUPPORTED_FORMAT = "UNSUPPORTED_FORMAT"
    EMPTY_FILE = "EMPTY_FILE"
    CORRUPT_FILE = "CORRUPT_FILE"
    ASSET_STORE_FAILED = "ASSET_STORE_FAILED"
    VISION_HOST_BLOCKED = "VISION_HOST_BLOCKED"
    VISION_FAILED = "VISION_FAILED"
    RESOURCE_LIMIT_EXCEEDED = "RESOURCE_LIMIT_EXCEEDED"


class SopIngestionError(Exception):
    def __init__(self, code: SopIngestionErrorCode, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message  # MUST NEVER contain raw SOP body/credentials


class SopMetadata(BaseModel):
    doc_id: str                  # Stable across versions: f"{segment.lower()}-{slugify(stem)}"
    source_filename: str
    source_file_sha256: str      # SHA-256 of raw input bytes
    segment: SopSegment
    doc_version: int = Field(ge=1)
    is_active: bool = True
    valid_from: datetime         # Single UTC timestamp stamped once per ingest_document() call
    valid_until: datetime | None = None
    role_acl: list[str] = Field(default_factory=lambda: ["mo-ncx"])


class ParsedBlock(BaseModel):
    block_index: int = Field(ge=0)
    block_type: Literal["heading", "paragraph", "code_cli", "table"]
    section_path: list[str] = Field(default_factory=list)
    section_heading: str
    text: str


class ParsedImage(BaseModel):
    order_index: int = Field(ge=0)
    block_index: int = Field(ge=0)
    section_path: list[str] = Field(default_factory=list)
    section_heading: str
    filename: str
    mime_type: str
    data: bytes


class ParsedDocument(BaseModel):
    source_filename: str
    source_file_sha256: str
    blocks: list[ParsedBlock]
    images: list[ParsedImage] = Field(default_factory=list)


class ExtractedAsset(BaseModel):
    asset_id: str                # Deterministic: f"{doc_id}:v{doc_version}:img{order_index}"
    doc_id: str
    doc_version: int = Field(ge=1)
    filename: str
    mime_type: str
    storage_uri: str             # Canonical: "local://<relpath>" or "s3://<bucket>/<key>"
    caption: str
    caption_status: Literal["ok", "noop", "failed"]
    section_path: list[str] = Field(default_factory=list)
    section_heading: str
    block_index: int = Field(ge=0)
    order_index: int = Field(ge=0)


class SopChunk(BaseModel):
    chunk_id: str                # Deterministic: f"{doc_id}:v{doc_version}:{chunk_index}"
    chunk_index: int = Field(ge=0)
    doc_id: str
    source_filename: str
    source_file_sha256: str
    segment: SopSegment
    doc_version: int = Field(ge=1)
    is_active: bool = True
    valid_from: datetime
    valid_until: datetime | None = None
    role_acl: list[str] = Field(default_factory=lambda: ["mo-ncx"])
    section_path: list[str] = Field(default_factory=list)
    section_heading: str
    content: str
    has_code_or_cli: bool = False
    asset_ids: list[str] = Field(default_factory=list)
    asset_captions: list[str] = Field(default_factory=list)  # Indexed by Module 2 alongside content
    content_sha256: str          # SHA-256 of chunk `content` (independent of Vision mode)


class IngestResult(BaseModel):
    metadata: SopMetadata
    chunks: list[SopChunk]
    assets: list[ExtractedAsset]
```

**Batas Keamanan Resource & Log:**
- Maksimal `100` gambar per dokumen (`max_images_per_doc=100`) dan `10 MB` per gambar (`max_image_bytes=10_485_760`); pelanggaran memicu `SopIngestionError(RESOURCE_LIMIT_EXCEEDED)`.
- Pesan exception & log **dilarang keras** mencetak isi teks mentah chunk SOP (mencegah kebocoran kredensial seperti `-storepass` yang ada pada dokumen operasional).

---

## 6. Testing Strategy

- **Framework:** `pytest` + `pytest-cov` (offline-safe, tanpa download model internet saat unit test).
- **Fixtures Sintetis (`conftest.py`):** Membuat file sintetis di `tmp_path` untuk `.docx` (headings berulang `"Before Changes"`/`"After Changes"`, tabel, CLI `--importcert`, XML `<Connector/>`, 2 PNG tertanam), `.pdf`, `.xlsx`, `.pptx`, `.sh` (termasuk non-UTF-8 cp1252), `.py`, `.md`, file 0-byte, file korup, dan ekstensi huruf besar `.DOCX` — **nol kredensial asli**.
- **Test Levels:**
  1. *Unit (`test_models.py`, `test_assets.py`, `test_vision.py`, `test_chunker.py`):* rumus ID deterministik lintas versi, sanitasi `doc_id` & `filename` anti *path-traversal*, versioned asset key (`v1` vs `v2` tidak saling menimpa), strict allowlist Vision + `follow_redirects=False` + fallback `caption_status="failed"`, chunker tidak memotong CLI/XML/tabel dan `overlap_chars` tidak memotong blok kode, serta penautan aset berdasarkan `block_index` pada sub-judul berulang.
  2. *Integration (`test_parser.py`, `test_pipeline.py`):* parsing semua format (`.docx`, `.pdf`, `.xlsx`, `.pptx`, `.sh`, `.py`, `.md`), penolakan error terstruktur (`FILE_NOT_FOUND`, `INVALID_PATH`, `UNSUPPORTED_FORMAT`, `EMPTY_FILE`, `CORRUPT_FILE`), dan end-to-end `SopIngestionPipeline.ingest_document()` + CLI.
- **Coverage Gate:** ≥ 80% pada seluruh `src/sop_ingestion/`.

---

## 7. Boundaries

- **Always:**
  - Jalankan `ruff check src tests`, `mypy src`, `pytest tests/sop_ingestion --cov=src/sop_ingestion --cov-fail-under=80`, dan *Secrets Scan* sebelum menandai selesai.
  - Gunakan `Protocol` untuk `AssetStore`, `S3ClientProtocol`, dan `VisionCaptioner`.
  - Redaksi seluruh pesan error agar tidak pernah mencetak konten mentah SOP.
- **Ask First:**
  - Menambah dependensi berat di luar Tech Stack atau mengubah kontrak `SopChunk`/`IngestResult` setelah Modul #2 dimulai.
- **Never:**
  - Mengizinkan panggilan Vision-LLM ke host publik di luar allowlist privat.
  - Menyimpan password/kredensial dari dokumen SOP nyata ke repo/fixture/log.
  - Melemahkan `CONSTRAINTS.md` atau memakai `# noqa` / `# type: ignore`.

---

## 8. Success Criteria

1. **Multimodal & Positional Linking:** Ingest `.docx` dengan sub-judul berulang (`"Before Changes"`) dan 2+ gambar tertanam menyimpan seluruh gambar ke `<doc_id>/v<doc_version>/...`, mengisi `caption` + `caption_status`, dan menautkan `asset_ids` + `asset_captions` hanya ke chunk langkah pemiliknya.
2. **Command, XML & Table Integrity:** Blok CLI, XML `<Connector .../>`, dan tabel tidak pernah terpotong melintasi dua chunk, `overlap_chars` tidak pernah memotong blok kode, dan karakter `--`/`_`/`<` tidak rusak oleh escaping.
3. **Deterministic Versioning:** Upload `v1` dan `v2` untuk dokumen yang sama menghasilkan `doc_id` identik, `chunk_id` & jalur aset berbeda (`v1` vs `v2`), serta 1 timestamp `valid_from` seragam per proses ingest.
4. **Privacy & Security:** `OpenAICompatibleVisionCaptioner` menolak seluruh host publik non-allowlist + menonaktifkan redirect; `LocalFsAssetStore` menolak *path traversal* baik dari `doc_id` maupun `filename`.
5. **Quality Gates:** `ruff check`, `mypy`, `pytest --cov >= 80%`, dan *Secrets Scan* semuanya **PASS (exit 0)**.

---

## 9. Out of Scope (Deferred)

- **Embedding & Qdrant Upsert / Version Invalidation:** Modul #2 (`sop-memory-rag`).
- **Rust Axum Upload Endpoint & Admin Auth:** Modul #3 (`triage-engine-api`).
- **Full Tree-sitter Multi-Language AST Parsing:** Ditunda ke V2 (di V1 menggunakan Python `ast` + *structured block splitter* untuk `.sh`, `.sql`, `.xml` guna menjaga kesederhanaan & kecepatan instalasi).
- **Auto-Sync SharePoint API & Graphiti Bi-Temporal Sync:** Ditunda ke V2 / Fase 2.
