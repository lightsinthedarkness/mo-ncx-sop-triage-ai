# Spec: Multimodal SOP & Domain Pack Ingestion Pipeline (`crates/sop-core` + `crates/sop-ingestion`) — V1 (100% Pure Rust)

- **Module ID:** `sop-ingestion` (ref: [capability-map.md](capability-map.md))
- **Design Reference:** [DESIGN.md](../DESIGN.md) (Design 2.5 — [ADR-001](../docs/adr/ADR-001-hybrid-python-rust-and-jev-orchestrator.md), [ADR-002](../docs/adr/ADR-002-internal-siebel16-oracle12c-zero-db-advisory-and-knowledge-automation.md), & [ADR-003](../docs/adr/ADR-003-pure-rust-backend-workspace.md))
- **PRD Reference:** [PRD.md](../PRD.md) (PRD 2.5 — FR-1)
- **Quality Contract:** [CONSTRAINTS.md](../CONSTRAINTS.md)
- **Status:** Approved & Hardened via `doubt-driven-development` (all 14 adversarial findings preserved in Pure Rust conversion; ready for coding gate once `rustup` is installed)

---

## 1. Objective

Membangun crate *ingestion* multimodal **100% Pure Rust** (`crates/sop-core` + `crates/sop-ingestion`) yang mengubah file dokumen SOP mentah milik tim MO NCX (`.docx`, `.pdf`, `.xlsx`, `.pptx`, `.md`, `.sh`, `.sql`, `.xml` — *case-insensitive*) serta file pengetahuan statis di `knowledge/domain-pack/` dari segmen **`EBIS`**, **`RETAIL`**, **`WIBS`**, atau **`GENERAL`** *(SOP lintas segmen & domain pack yang dapat diakses oleh seluruh segmen pada Modul #2)* menjadi kumpulan **Structured SOP Chunks** (`SopChunk`) dan **Stored Screenshot Assets** (`ExtractedAsset`) yang langsung dikonsumsi secara *compile-time type-safe* oleh `crates/sop-memory-rag`.

**Masalah nyata yang diselesaikan:**
1. Dokumen SOP teknis MO NCX berisi **puluhan gambar *screenshot* terminal/UI `before changes` & `after changes`** di sela-sela teks pendek, sering kali dengan sub-judul berulang antar langkah. Gambar diekstrak berurutan dari relasi XML (`word/_rels/document.xml.rels` / `ppt/slides/_rels/`) dan ditautkan ke chunk lewat **posisi blok (`block_index` + `section_path`)**, bukan hanya mencocokkan nama sub-judul.
2. Blok perintah CLI Linux (`/opt/Siebel16/...`, `keytool`, `chmod`), referensi query Oracle 12c, konfigurasi XML (`<Connector .../>`), variabel `export`, serta tabel **tidak boleh terpotong di tengah** atau berubah karakternya (nol *Markdown escaping* `\_`, `\<`, `\-`).
3. Setiap dokumen wajib membawa **ID deterministik & metadata temporal** (`doc_id` stabil lintas versi, `chunk_id`/`asset_id` menyertakan `doc_version`, 1 stempel `valid_from` seragam per proses *ingest*, `valid_until`, `is_active`, `segment`, `role_acl`) agar Modul #2 (`crates/sop-memory-rag`) bisa menonaktifkan versi SOP lama tanpa *split-brain*.

---

## 2. Tech Stack (100% Pure Rust — Verified Crates)

- **Language & Toolchain:** Rust 2021/2024 edition (`rustc` stable, `cargo fmt`, `cargo clippy -- -D warnings`, `cargo test`, `cargo llvm-cov`) — **nol `unsafe`**, **nol `.unwrap()` pada input eksternal**.
- **Shared Models & Serialization (`crates/sop-core`):** `serde` + `serde_json` (`serde-rs/serde`), `chrono` (`chronotope/chrono`), `sha2` (`RustCrypto/hashes`), `thiserror` (`dtolnay/thiserror`), `schemars` (`GREsau/schemars`).
- **Document Parsing (`crates/sop-ingestion`):**
  - **OOXML (`.docx`, `.pptx`):** `zip` (`zip-rs/zip2`) + `quick-xml` (`tafia/quick-xml`) — membaca `word/document.xml`, tabel `<w:tbl>`, paragraf CLI/XML verbatim, dan `word/media/*` sesuai urutan bacaan eksak (`block_index`).
  - **Spreadsheets (`.xlsx`, `.xls`, `.ods`):** `calamine` (`tafia/calamine`).
  - **PDF (`.pdf`):** `lopdf` (`J-F-Liu/lopdf`) — pure-Rust zero-C-dependency ekstraksi teks & objek gambar tertanam.
  - **Scripts & Domain Pack (`.md`, `.sh`, `.sql`, `.xml`):** `encoding_rs` (`hsivonen/encoding_rs`) untuk fallback encoding (`UTF-8` / `UTF-8-BOM` → `Windows-1252`) + *deterministic structured block splitter*.
- **Chunking:** `CommandSafeChunker` (`max_chars: 1200` ~300–400 token aman untuk `BAAI/bge-m3`, `overlap_chars: 150` dilarang memotong blok CLI/XML/SQL/tabel, `max_atomic_chars: 4800` agar blok CLI/tabel besar tetap utuh).
- **Vision Captioning Trait:** `#[async_trait] pub trait VisionCaptioner: Send + Sync` dengan 2 implementasi:
  - `OpenAiCompatibleVisionCaptioner` (`seanmonstar/reqwest`): menghubungi endpoint Vision lokal (`vLLM`/`Ollama` `Qwen2.5-VL`) dengan **strict host allowlist** (hanya loopback `localhost`/`127.0.0.1`/`::1`, IP privat RFC1918, atau env `VISION_ALLOWED_HOSTS`), `reqwest::redirect::Policy::none()`, `timeout = 30s`, retry 1x pada transient error, dan *non-destructive fallback* (`CaptionStatus::Failed`) jika gagal.
  - `NoopVisionCaptioner`: mode default dev lokal tanpa GPU (`VISION_MODE=noop`, `CaptionStatus::Noop`).
- **Asset Storage Trait:** `pub trait AssetStore: Send + Sync` + `pub trait S3PutObject: Send + Sync` agar seluruh test berjalan 100% offline:
  - `LocalFsAssetStore` (default dev lokal → `.data/assets/`, `storage_uri = "local://<relpath>"`, wajib sanitasi `doc_id` & `filename` + validasi canonical path berada di bawah root).
  - `MinioAssetStore` (staging/produksi → `storage_uri = "s3://<bucket>/<key>"`).
- **CLI Binary:** `clap` (`clap-rs/clap`, derive API) — `cargo run -p sop-ingestion -- ingest --file ... --segment EBIS --version 1 --output-dir .scratch/ingest-preview`.

---

## 3. Commands

```powershell
# Format, Lint, & Strict Clippy (Blocking Gates — CONSTRAINTS.md)
cargo fmt --all -- --check
cargo clippy --workspace --all-targets -- -D warnings

# Unit & Integration Tests + Coverage >= 80%
cargo test --workspace
cargo llvm-cov --workspace --fail-under-lines 80

# Secrets Scan & Zero-DB Policy Guard
gitleaks detect --source . --redact --no-banner
cargo test zero_db_policy

# Dry-run CLI ingest 1 file SOP (output ke .scratch/ yang ter-gitignore)
cargo run -p sop-ingestion -- ingest --file "path/to/sample.docx" --segment EBIS --version 1 --output-dir .scratch/ingest-preview
```

---

## 4. Workspace Structure

```text
c:/Users/Administrator/LLM/
├── Cargo.toml                     # Workspace root (members = ["crates/sop-core", "crates/sop-ingestion"])
└── crates/
    ├── sop-core/
    │   ├── Cargo.toml
    │   └── src/
    │       ├── lib.rs             # Re-exports & helper make_doc_id / sha256_bytes / sha256_text
    │       ├── models.rs          # Seluruh kontrak data publik (serde + schemars)
    │       └── error.rs           # SopIngestionErrorCode & SopIngestionError (thiserror, zero raw SOP leak)
    └── sop-ingestion/
        ├── Cargo.toml
        ├── src/
        │   ├── lib.rs             # Re-exports public API
        │   ├── assets.rs          # AssetStore trait, S3PutObject trait, LocalFsAssetStore, MinioAssetStore
        │   ├── vision.rs          # VisionCaptioner trait, NoopVisionCaptioner, OpenAiCompatibleVisionCaptioner
        │   ├── parser/
        │   │   ├── mod.rs         # Dispatcher parse_sop_file() + resource caps
        │   │   ├── docx.rs        # zip + quick-xml (.docx paragraphs, tables, CLI/XML verbatim, ordered media)
        │   │   ├── pptx.rs        # zip + quick-xml (.pptx slides & media)
        │   │   ├── xlsx.rs        # calamine (.xlsx sheets -> markdown tables)
        │   │   ├── pdf.rs         # lopdf (.pdf text & embedded image objects)
        │   │   └── script.rs      # encoding_rs + structured block splitter (.md/.sh/.sql/.xml)
        │   ├── chunker.rs         # CommandSafeChunker (CLI/XML/SQL/table-safe + positional asset linking)
        │   ├── pipeline.rs        # SopIngestionPipeline::ingest_document() -> IngestResult
        │   └── main.rs            # CLI binary (clap)
        └── tests/
            ├── fixtures.rs        # Synthetic fixture builders (.docx, .pdf, .xlsx, .pptx, .sh cp1252, .md, corrupt, empty)
            ├── models_test.rs
            ├── assets_test.rs
            ├── vision_test.rs
            ├── parser_test.rs
            ├── chunker_test.rs
            └── pipeline_test.rs
```

---

## 5. Complete Public Data Contracts (`crates/sop-core/src/models.rs`)

```rust
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "UPPERCASE")]
pub enum SopSegment {
    Ebis,
    Retail,
    Wibs,
    General, // Cross-segment SOP & knowledge/domain-pack visible to all segments in Module 2
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum SopIngestionErrorCode {
    FileNotFound,
    InvalidPath,
    UnsupportedFormat,
    EmptyFile,
    CorruptFile,
    AssetStoreFailed,
    VisionHostBlocked,
    VisionFailed,
    ResourceLimitExceeded,
}

#[derive(Debug, Error)]
#[error("[{code:?}] {message}")]
pub struct SopIngestionError {
    pub code: SopIngestionErrorCode,
    pub message: String, // MUST NEVER contain raw SOP body or credentials
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum BlockType {
    Heading,
    Paragraph,
    CodeCli,
    Table,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CaptionStatus {
    Ok,
    Noop,
    Failed,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SopMetadata {
    pub doc_id: String,               // Stable across versions: "{segment_lower}-{slugify(stem)}"
    pub source_filename: String,
    pub source_file_sha256: String,   // SHA-256 of raw input bytes
    pub segment: SopSegment,
    pub doc_version: u32,             // >= 1
    pub is_active: bool,              // default: true
    pub valid_from: DateTime<Utc>,    // Single UTC timestamp stamped once per ingest_document() call
    pub valid_until: Option<DateTime<Utc>>,
    pub role_acl: Vec<String>,        // default: vec!["mo-ncx"]
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParsedBlock {
    pub block_index: usize,
    pub block_type: BlockType,
    pub section_path: Vec<String>,
    pub section_heading: String,
    pub text: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParsedImage {
    pub order_index: usize,
    pub block_index: usize,
    pub section_path: Vec<String>,
    pub section_heading: String,
    pub filename: String,
    pub mime_type: String,
    #[serde(skip_serializing)]
    pub data: Vec<u8>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParsedDocument {
    pub source_filename: String,
    pub source_file_sha256: String,
    pub blocks: Vec<ParsedBlock>,
    pub images: Vec<ParsedImage>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExtractedAsset {
    pub asset_id: String,             // Deterministic: "{doc_id}:v{doc_version}:img{order_index}"
    pub doc_id: String,
    pub doc_version: u32,
    pub filename: String,
    pub mime_type: String,
    pub storage_uri: String,          // Canonical: "local://<relpath>" or "s3://<bucket>/<key>"
    pub caption: String,
    pub caption_status: CaptionStatus,
    pub section_path: Vec<String>,
    pub section_heading: String,
    pub block_index: usize,
    pub order_index: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SopChunk {
    pub chunk_id: String,             // Deterministic: "{doc_id}:v{doc_version}:{chunk_index}"
    pub chunk_index: usize,
    pub doc_id: String,
    pub source_filename: String,
    pub source_file_sha256: String,
    pub segment: SopSegment,
    pub doc_version: u32,
    pub is_active: bool,
    pub valid_from: DateTime<Utc>,
    pub valid_until: Option<DateTime<Utc>>,
    pub role_acl: Vec<String>,
    pub section_path: Vec<String>,
    pub section_heading: String,
    pub content: String,
    pub has_code_or_cli: bool,
    pub asset_ids: Vec<String>,
    pub asset_captions: Vec<String>,  // Indexed by Module 2 alongside content
    pub content_sha256: String,       // SHA-256 of chunk `content` (independent of Vision mode)
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IngestResult {
    pub metadata: SopMetadata,
    pub chunks: Vec<SopChunk>,
    pub assets: Vec<ExtractedAsset>,
}
```

**Batas Keamanan Resource & Log:**
- Maksimal `100` gambar per dokumen (`max_images_per_doc = 100`) dan `10 MB` per gambar (`max_image_bytes = 10_485_760`); pelanggaran memicu `SopIngestionErrorCode::ResourceLimitExceeded`.
- Pesan error & `tracing` log **dilarang keras** mencetak isi teks mentah chunk SOP (mencegah kebocoran kredensial seperti `-storepass` yang ada pada dokumen operasional).

---

## 6. Testing Strategy

- **Framework:** `cargo test` + `tokio::test` + `tempfile` + `wiremock` (untuk uji HTTP private Vision allowlist & retry 100% offline) + `cargo llvm-cov`.
- **Fixtures Sintetis (`tests/fixtures.rs`):** Membangun file sintetis di `TempDir` secara programatik untuk `.docx` (ZIP+XML valid dengan sub-judul berulang `"Before Changes"`/`"After Changes"`, tabel, CLI `--importcert`, XML `<Connector/>`, 2 PNG tertanam), `.pdf`, `.xlsx`, `.pptx`, `.sh` (termasuk non-UTF-8 Windows-1252), `.md`, file 0-byte, file korup, dan ekstensi huruf besar `.DOCX` — **nol kredensial asli**.
- **Test Levels:**
  1. *Unit (`models_test`, `assets_test`, `vision_test`, `chunker_test`):* rumus ID deterministik lintas versi, sanitasi `doc_id` & `filename` anti *path-traversal*, versioned asset key (`v1` vs `v2` tidak saling menimpa), strict allowlist Vision + `redirect::Policy::none()` + retry 1x + fallback `CaptionStatus::Failed`, chunker tidak memotong CLI/XML/SQL/tabel dan `overlap_chars` tidak memotong blok kode, serta penautan aset berdasarkan `block_index` pada sub-judul berulang.
  2. *Integration (`parser_test`, `pipeline_test`):* parsing seluruh format (`.docx`, `.pdf`, `.xlsx`, `.pptx`, `.sh`, `.sql`, `.xml`, `.md`), error terstruktur (`FileNotFound`, `InvalidPath`, `UnsupportedFormat`, `EmptyFile`, `CorruptFile`, `ResourceLimitExceeded`), end-to-end `SopIngestionPipeline::ingest_document()`, CLI output JSON, serta `zero_db_policy` test memastikan nol dependency driver Oracle/SSH di `Cargo.toml`.
- **Coverage Gate:** ≥ 80% pada seluruh `crates/sop-core` & `crates/sop-ingestion`.

---

## 7. Boundaries

- **Always:**
  - Jalankan `cargo fmt --all -- --check`, `cargo clippy --workspace --all-targets -- -D warnings`, `cargo test --workspace`, `cargo llvm-cov --workspace --fail-under-lines 80`, dan `gitleaks` sebelum menandai selesai.
  - Gunakan trait (`AssetStore`, `S3PutObject`, `VisionCaptioner`) untuk seluruh I/O eksternal.
  - Redaksi seluruh pesan error agar tidak pernah mencetak konten mentah SOP.
- **Ask First:**
  - Menambah dependency eksternal berat di luar Tech Stack atau mengubah kontrak `SopChunk`/`IngestResult` setelah Modul #2 dimulai.
- **Never:**
  - Menambah driver koneksi Oracle 12c (`oracle`/`sibyl`/`oci`) atau SSH exec ke `Cargo.toml` (`ADR-002`).
  - Mengizinkan panggilan Vision-LLM ke host publik di luar allowlist privat.
  - Memakai `unsafe`, `#[allow(warnings)]`, atau `.unwrap()` pada input eksternal.

---

## 8. Success Criteria

1. **Multimodal & Positional Linking:** Ingest `.docx` dengan sub-judul berulang (`"Before Changes"`) dan 2+ gambar tertanam menyimpan seluruh gambar ke `<doc_id>/v<doc_version>/...`, mengisi `caption` + `caption_status`, dan menautkan `asset_ids` + `asset_captions` hanya ke chunk langkah pemiliknya.
2. **Command, XML, SQL & Table Integrity:** Blok CLI, XML `<Connector .../>`, SQL, dan tabel tidak pernah terpotong melintasi dua chunk, `overlap_chars` tidak pernah memotong blok kode, dan karakter `--`/`_`/`<` utuh verbatim.
3. **Deterministic Versioning:** Upload `v1` dan `v2` untuk dokumen yang sama menghasilkan `doc_id` identik, `chunk_id` & jalur aset berbeda (`v1` vs `v2`), serta 1 timestamp `valid_from` seragam per proses ingest.
4. **Privacy, Zero-DB & Security:** `OpenAiCompatibleVisionCaptioner` menolak seluruh host publik non-allowlist + menonaktifkan redirect; `LocalFsAssetStore` menolak *path traversal* baik dari `doc_id` maupun `filename`; `zero_db_policy` PASS.
5. **Quality Gates:** `cargo fmt --check`, `cargo clippy -D warnings`, `cargo test`, `cargo llvm-cov >= 80%`, dan `gitleaks` semuanya **PASS (exit 0)**.

---

## 9. Out of Scope (Deferred)

- **Embedding & Qdrant Upsert / Version Invalidation:** Modul #2 (`crates/sop-memory-rag`).
- **Rust Axum Upload Endpoint, Office RBAC, & Non-DB Knowledge Automation:** Modul #3 (`crates/triage-engine`).
- **Auto-Sync SharePoint API & Graphiti Bi-Temporal Sync:** Ditunda ke V2 / Fase 2.
