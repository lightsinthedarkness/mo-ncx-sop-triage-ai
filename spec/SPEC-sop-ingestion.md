# Spec: Multimodal SOP Ingestion Pipeline (`sop-ingestion`) — V1

- **Module ID:** `sop-ingestion` (ref: [capability-map.md](capability-map.md))
- **Design Reference:** [DESIGN.md](../DESIGN.md) (Design 2.2)
- **PRD Reference:** [PRD.md](../PRD.md) (FR-1)
- **Quality Contract:** [CONSTRAINTS.md](../CONSTRAINTS.md)
- **Status:** Approved by Owner (2026-11-26) — Open Questions #1 (`LocalFsAssetStore` dev default) & #2 (`VISION_MODE=noop` dev / `local_vlm` GPU VPS) approved.

---

## 1. Objective

Membangun modul *ingestion* multimodal (`sop-ingestion`) yang mengubah file dokumen SOP mentah milik tim MO NCX (`.docx`, `.pdf`, `.xlsx`, `.pptx`, `.md`, `.sh`, `.sql`, `.xml`) dari segmen **`EBIS`**, **`RETAIL`**, atau **`WIBS`** menjadi kumpulan **Structured SOP Chunks** dan **Stored Screenshot Assets** yang siap diindeks oleh modul `sop-memory-rag`.

**Masalah nyata yang diselesaikan:**
1. Dokumen SOP teknis MO NCX (seperti *Config HTTP to HTTPS Outbound Webservice*, *SAF Converter*, *Update SSL Truststore*) berisi **puluhan gambar *screenshot* terminal/UI `before changes` & `after changes`** di sela-sela teks pendek. Parser teks biasa kehilangan separuh konteks operasional tersebut.
2. Blok perintah CLI Linux (`/opt/Siebel16/...`, `keytool`, `chmod`), konfigurasi XML (`<Connector .../>`), dan variabel `export` **tidak boleh terpotong di tengah** atau berubah karakternya (misalnya `--` berubah menjadi em-dash).
3. Setiap dokumen wajib membawa **metadata temporal & versi** (`doc_id`, `doc_version`, `valid_from`, `valid_until`, `is_active`, `segment`, `role_acl`) sejak awal agar modul `sop-memory-rag` bisa menonaktifkan versi SOP lama tanpa *split-brain*.

---

## 2. Tech Stack

- **Language:** Python 3.12+ (strict type hints, `mypy` clean)
- **Schema & Validation:** `pydantic>=2.10`
- **Document Parsing:** `docling>=2.81` (`DocumentConverter`, `PdfFormatOption`, `PdfPipelineOptions`, `PdfBackendOptions(do_char_normalization=False)`, `HybridChunker`)
- **Vision Captioning Interface:** `VisionCaptioner` (`typing.Protocol`) dengan 2 implementasi:
  - `OpenAICompatibleVisionCaptioner` (menghubungi model Vision lokal via LiteLLM/Ollama/vLLM, mis. `Qwen2.5-VL` / `Qwen3-VL` — `enable_remote_services=False` ke cloud publik)
  - `NoopVisionCaptioner` (mode cepat/offline dev & unit testing tanpa GPU)
- **Asset Storage Interface:** `AssetStore` (`typing.Protocol`) dengan 2 implementasi:
  - `MinioAssetStore` (S3/MinIO untuk staging/produksi)
  - `LocalFsAssetStore` (penyimpanan folder lokal untuk dev/testing ringan)
- **Code/Script Parsing:** Pembaca teks terstruktur & pemisah blok fungsi/perintah untuk `.sh`, `.sql`, `.xml`, `.py` (fondasi *AST-ready* untuk Fase 2).

---

## 3. Commands

```powershell
# Setup virtual environment & install module dependencies
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -e ".[dev]"

# Lint & Typecheck (Blocking Gates — CONSTRAINTS.md)
ruff check src tests
mypy src

# Unit & Integration Tests (Coverage >= 80%)
pytest tests/sop_ingestion --cov=src/sop_ingestion --cov-fail-under=80

# Dry-run CLI ingest 1 file SOP (tanpa mengubah Qdrant)
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
│       ├── models.py        # Pydantic models: SopSegment, SopMetadata, ExtractedAsset, SopChunk, IngestResult
│       ├── assets.py        # AssetStore Protocol + LocalFsAssetStore + MinioAssetStore
│       ├── vision.py        # VisionCaptioner Protocol + OpenAICompatibleVisionCaptioner + NoopVisionCaptioner
│       ├── parser.py        # Docling wrapper (DOCX/PDF/XLSX/PPTX) + Code/Script parser + embedded image extractor
│       ├── chunker.py       # Command-Safe & Structure-Aware chunker (melindungi blok CLI/XML/tabel + tautan asset_ids)
│       ├── pipeline.py      # Orchestrator ingest_document() → IngestResult (deterministic, idempotent via content sha256)
│       └── cli.py           # CLI dry-run untuk verifikasi & inspeksi hasil parsing lokal
└── tests/
    └── sop_ingestion/
        ├── conftest.py      # Synthetic DOCX/PDF/Script generator (zero real credentials!)
        ├── test_models.py
        ├── test_assets.py
        ├── test_parser.py
        ├── test_chunker.py
        └── test_pipeline.py
```

---

## 5. Code Style & Boundary Contract

Contoh gaya penulisan dan kontrak data modul (`src/sop_ingestion/models.py`):

```python
from datetime import datetime, timezone
from enum import StrEnum
from pydantic import BaseModel, Field


class SopSegment(StrEnum):
    EBIS = "EBIS"
    RETAIL = "RETAIL"
    WIBS = "WIBS"
    GENERAL = "GENERAL"


class ExtractedAsset(BaseModel):
    asset_id: str
    filename: str
    mime_type: str
    storage_uri: str
    caption: str
    section_heading: str
    order_index: int


class SopChunk(BaseModel):
    chunk_id: str
    doc_id: str
    source_filename: str
    segment: SopSegment
    doc_version: int = Field(ge=1)
    is_active: bool = True
    valid_from: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    valid_until: datetime | None = None
    role_acl: list[str] = Field(default_factory=lambda: ["mo-ncx"])
    section_heading: str
    content: str
    has_code_or_cli: bool = False
    asset_ids: list[str] = Field(default_factory=list)
    content_sha256: str
```

Konvensi:
- Semua I/O eksternal (MinIO, Vision LLM) diinjeksi lewat `typing.Protocol` agar dapat diuji deterministik tanpa jaringan/GPU.
- Dilarang menyalin atau menuliskan password/kredensial nyata dari file SOP contoh ke dalam fixture test atau log.

---

## 6. Testing Strategy

- **Framework:** `pytest` + `pytest-cov` (mengikuti pola skill `python-testing-patterns`).
- **Fixtures Sintetis:** `conftest.py` membuat file `.docx` sintetis (teks langkah, tabel, blok CLI multi-baris, blok XML, dan 2 gambar PNG tertanam) serta `.sh`/`.md` sintetis di `tmp_path` — **nol ketergantungan pada file sensitif di `Downloads/`**.
- **Test Levels:**
  1. *Unit (`test_models.py`, `test_assets.py`, `test_chunker.py`):* validasi enum segmen, preservasi karakter CLI `--` & blok XML utuh dalam 1 chunk, penautan `asset_ids` ke chunk yang tepat, idempotensi `content_sha256`.
  2. *Integration (`test_parser.py`, `test_pipeline.py`):* pipeline penuh `ingest_document()` dari file `.docx`/`.md`/`.sh` → `LocalFsAssetStore` + fake `VisionCaptioner` → menghasilkan `IngestResult` valid dan menolak ekstensi tidak didukung / file rusak dengan error terstruktur.
- **Coverage Gate:** ≥ 80% pada seluruh file `src/sop_ingestion/`.

---

## 7. Boundaries

- **Always:**
  - Jalankan `ruff check src tests`, `mypy src`, dan `pytest --cov=src/sop_ingestion --cov-fail-under=80` sebelum menandai tugas selesai.
  - Pertahankan keutuhan karakter asli (`do_char_normalization=False`) dan keutuhan blok perintah CLI/XML/tabel saat *chunking*.
  - Sertakan metadata temporal lengkap (`doc_version`, `valid_from`, `valid_until`, `is_active`, `segment`, `role_acl`) pada setiap `SopChunk`.
- **Ask First:**
  - Menambahkan dependensi Python berat baru di luar daftar Tech Stack.
  - Mengubah skema kontrak `SopChunk` / `ExtractedAsset` setelah Modul 2 (`sop-memory-rag`) mulai bergantung padanya.
- **Never:**
  - Mengirim file SOP atau potongan gambarnya ke API cloud eksternal (OpenAI/Gemini/Anthropic).
  - Menyimpan password/kredensial dari dokumen SOP nyata ke dalam repo, test fixture, atau log.
  - Melemahkan aturan di `CONSTRAINTS.md` atau memakai `# noqa` / `# type: ignore`.

---

## 8. Success Criteria (Testable Acceptance Criteria)

1. **Multimodal Extraction:** Meng-ingest file `.docx` dengan 2+ gambar tertanam menghasilkan seluruh gambar tersimpan di `AssetStore` (`ExtractedAsset.storage_uri` valid), setiap gambar memiliki `caption` dari `VisionCaptioner`, dan `asset_id` tertaut pada `SopChunk` bab terkait.
2. **Command & XML Integrity:** Blok perintah CLI (mis. `keytool -importcert ...`, `export CATALINA_OPTS=...`) dan blok XML `<Connector .../>` tidak pernah terpotong melintasi dua `SopChunk`, serta tanda `--` / kutip tidak berubah.
3. **Temporal & Segment Metadata:** Setiap `SopChunk` membawa `segment` valid (`EBIS`/`RETAIL`/`WIBS`/`GENERAL`), `doc_version >= 1`, `is_active=True`, `valid_from` (UTC), `valid_until=None`, `role_acl=["mo-ncx"]`, dan `content_sha256` deterministik.
4. **Error Handling:** File dengan ekstensi tidak didukung, file kosong, atau file rusak mengembalikan `SopIngestionError` terstruktur (tidak *crash* tak terkendali).
5. **Quality Gates:** `ruff check`, `mypy`, dan `pytest --cov=src/sop_ingestion --cov-fail-under=80` semuanya **PASS (exit 0)**.

---

## 9. Out of Scope (Deferred)

- **Embedding & Qdrant Upsert / Version Invalidation:** Menjadi tanggung jawab Modul #2 (`sop-memory-rag`).
- **FastAPI Upload Endpoint & Admin PIN Auth:** Menjadi tanggung jawab Modul #3 (`triage-engine-api`).
- **Auto-Sync langsung dari SharePoint API:** Ditunda ke V2 (di V1 Admin melakukan *upload* manual dari panel Admin atau CLI).
- **Bi-Temporal Graphiti Ingestion:** Ditunda ke Fase 2.

---

## 10. Open Questions (Untuk Konfirmasi Owner)

1. **Penyimpanan Gambar Mode Dev Lokal:** Saat kita membangun & mengetes di PC lokal sebelum MinIO Docker dinyalakan, apakah oke `LocalFsAssetStore` (simpan ke folder `.data/assets/`) dipakai sebagai default lokal dan `MinioAssetStore` aktif via env saat di VM/VPS? *(Rekomendasi: Ya — jauh lebih ringan untuk dev & TDD).*
2. **Mode Vision Captioning saat Dev Tanpa GPU:** Di PC Ryzen 5 16GB tanpa GPU, apakah oke selama dev/tes lokal kita sediakan switch `VISION_MODE=noop` (fallback deskripsi placeholder/nama gambar) dan `VISION_MODE=local_vlm` saat GPU VPS (`Qwen2.5-VL`/`Qwen3-VL`) sudah siap? *(Rekomendasi: Ya — agar pipeline bisa dites cepat hari ini dan langsung aktif Vision penuh di GPU VPS tanpa ubah kode).*
