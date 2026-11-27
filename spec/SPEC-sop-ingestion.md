# Spec: Multimodal SOP & Domain Pack Ingestion Pipeline (`crates/sop-core` + `crates/sop-ingestion`) — V1 (100% Pure Rust)

- **Module ID:** `sop-ingestion` (ref: [capability-map.md](capability-map.md))
- **Design Reference:** [DESIGN.md](../DESIGN.md) (Design 2.5 — [ADR-001](../docs/adr/ADR-001-hybrid-python-rust-and-jev-orchestrator.md), [ADR-002](../docs/adr/ADR-002-internal-siebel16-oracle12c-zero-db-advisory-and-knowledge-automation.md), & [ADR-003](../docs/adr/ADR-003-pure-rust-backend-workspace.md))
- **PRD Reference:** [PRD.md](../PRD.md) (PRD 2.5 — FR-1)
- **Quality Contract:** [CONSTRAINTS.md](../CONSTRAINTS.md)
- **Status:** Approved & Hardened via `doubt-driven-development` (2026-11-28 — all 19/19 Pure-Rust adversarial findings reconciled; ready for coding gate once `rustup` is installed)

---

## 1. Objective

Membangun crate *ingestion* multimodal **100% Pure Rust** (`crates/sop-core` + `crates/sop-ingestion`) yang mengubah file dokumen SOP mentah milik tim MO NCX (`.docx`, `.pdf`, `.xlsx`, `.pptx`, `.md`, `.yaml`, `.yml`, `.sh`, `.sql`, `.xml` — *case-insensitive*) serta file pengetahuan statis di `knowledge/domain-pack/` dari segmen **`EBIS`**, **`RETAIL`**, **`WIBS`**, atau **`GENERAL`** menjadi kumpulan **Structured SOP Chunks** (`SopChunk`) dan **Stored Screenshot Assets** (`ExtractedAsset`) yang langsung dikonsumsi secara *compile-time type-safe* oleh `crates/sop-memory-rag`.

**Masalah nyata yang diselesaikan:**
1. Dokumen SOP teknis MO NCX berisi **puluhan gambar *screenshot* terminal/UI `before changes` & `after changes`** di sela-sela teks pendek, sering kali dengan sub-judul berulang antar langkah. Gambar diekstrak berurutan dan ditautkan ke chunk lewat **posisi blok (`block_index` + `section_path`)**, bukan hanya mencocokkan nama sub-judul.
2. Blok perintah CLI Linux (`/opt/Siebel16/...`, `keytool`, `chmod`), referensi query Oracle 12c, konfigurasi XML (`<Connector .../>`), variabel `export`, serta tabel **tidak boleh terpotong di tengah** atau rusak karakternya (nol *Markdown escaping* `\_`, `\<`, `\-`), sekaligus **kredensial plaintext operasional** (seperti `-storepass ...`, `password=...`, PEM private key) **wajib disaring oleh Secret Scrubber** sebelum masuk ke chunk, caption, atau JSON output.
3. Setiap dokumen wajib membawa **ID deterministik & metadata temporal** (`doc_id` stabil lintas versi tanpa kolisi antar ekstensi & aman dari `MAX_PATH` Windows, `chunk_id`/`asset_id` logis terpisah dari nama file fisik bebas `:`, 1 stempel `valid_from` seragam per proses *ingest*, `source_type`, `doc_version: NonZeroU32`, `is_active`, `segment`, `role_acl`).

---

## 2. Tech Stack (100% Pure Rust 2021 Edition — Verified Crates)

- **Language & Toolchain:** **Rust 2021 edition** (`rustc` stable, `cargo fmt`, `cargo clippy --workspace --all-targets -- -D warnings`, `cargo test`, `cargo llvm-cov`) — **nol `unsafe`**, **nol `.unwrap()` pada input eksternal**, **nol `std::env::set_var` di test** (konfigurasi diinjeksikan lewat struct `VisionConfig`).
- **Shared Models & Serialization (`crates/sop-core`):** `serde` + `serde_json`, `chrono`, `sha2`, `thiserror`, `schemars` (seluruh struct & enum publik wajib `#[derive(schemars::JsonSchema)]`).
- **Shared Test Support (`crates/sop-test-support`, workspace dev-dependency):** Helper pembuat fixture sintetis terpisah agar integration test di `crates/sop-ingestion/tests/` menghasilkan **0 warning `dead_code`** di bawah `clippy -D warnings` tanpa `#[allow]`.
- **Document Parsing (`crates/sop-ingestion`):**
  - **OOXML Word (`.docx`):** `zip` (`zip-rs/zip2`) + `quick-xml` (`tafia/quick-xml`). Menggabungkan seluruh `<w:r><w:t>` runs per paragraf, mengonversi `<w:br/>` → `\n` dan `<w:tab/>` → `\t`, membaca `<w:outlineLvl>` dari `word/styles.xml` untuk deteksi heading independen dari bahasa/style custom, mengekstrak gambar dari **DrawingML (`<a:blip r:embed>`)** maupun **legacy VML (`<v:imagedata r:id>`)** termasuk di dalam tabel/textbox (menolak `TargetMode="External"` agar tidak pernah memuat URL eksternal).
  - **OOXML PowerPoint (`.pptx`):** `zip` + `quick-xml`. Menentukan urutan slide dari `ppt/presentation.xml` (`<p:sldIdLst>`) — bukan urutan leksikal file ZIP — serta meresolusi path relatif `../media/...` pada `ppt/slides/_rels/*.rels`.
  - **Excel Spreadsheets (`.xlsx` saja di V1):** `calamine` (`tafia/calamine`) untuk ekstraksi sheet/cell ke tabel Markdown (memangkas kolom kosong berlebih, menangani nilai tanggal & merged cells dengan aman) + pembacaan `xl/media/*` lewat `zip` agar gambar tertanam di `.xlsx` ikut terekstrak.
  - **PDF (`.pdf`):** Pemisahan tanggung jawab untuk mengatasi limitasi `lopdf` mentah:
    - Ekstraksi teks & CMap memakai *high-level pure-Rust extractor* (`oxidize-pdf` / `pdf-extract`),
    - Ekstraksi objek gambar `XObject` memakai `lopdf`, lalu seluruh gambar non-PNG/non-JPEG (`/FlateDecode` raw pixel buffer, BMP, TIFF) dinormalisasi & di-encode ke **PNG valid** memakai crate **`image`** (`image-rs/image`) sebelum disimpan ke `AssetStore` atau dikirim ke Vision-LLM (format tak didukung seperti `.emf`/`.wmf` dicatat aman sebagai *skipped/failed* tanpa crash),
    - PDF hasil scan (**0 teks + N gambar**) diproses valid sebagai *image-backed chunks* (bukan `EmptyFile`); PDF terenkripsi yang tidak terbaca mengembalikan `CorruptFile`.
  - **Scripts & Domain Pack (`.md`, `.yaml`, `.yml`, `.sh`, `.sql`, `.xml`):** Deteksi BOM (`UTF-8-BOM`, `UTF-16LE`, `UTF-16BE`) via `encoding_rs` + pemeriksaan byte NUL/biner sebelum fallback `Windows-1252` (file biner yang menyamar sebagai `.sh`/`.sql` wajib ditolak sebagai `CorruptFile`) + *deterministic structured block splitter*.
- **Secret Scrubber (`secret_scrubber.rs`):** Dijalankan secara wajib pada setiap `SopChunk.content` dan `ExtractedAsset.caption` sebelum disimpan/diekspor — mengganti pola kredensial plaintext (`-storepass <val>`, `-keypass <val>`, `password=<val>`, `passwd=<val>`, `Authorization: Bearer ...`, `-----BEGIN ... PRIVATE KEY-----`) dengan `<REDACTED_SECRET>` tanpa merusak struktur flag CLI (`-storepass <REDACTED_SECRET>`).
- **Chunking (`CommandSafeChunker`):**
  - `max_chars = 1200`, `overlap_chars = 150` (dihitung berdasarkan **char boundary UTF-8**, bukan byte index, agar tidak pernah panic pada karakter `→` atau kutip melengkung), `max_atomic_chars = 4800`.
  - Klasifikasi deterministik `BlockType::CodeCli` pada paragraf `.docx`/`.pdf` (mendeteksi awalan command/path `/opt/`, `keytool`, `chmod`, `systemctl`, `srvrmgr`, `export `, SQL `SELECT`/`ALTER`, atau tag XML `<...>`).
  - Blok atomik (`CodeCli`/`Table`) tidak pernah dipecah oleh `overlap_chars`; jika satu blok atomik melampaui `max_atomic_chars = 4800`, blok dipecah bersih hanya pada batas baris `\n` (`oversized_atomic_split = true`) — tidak pernah dipotong di tengah baris/token atau di-truncate diam-diam.
  - Penautan aset: gambar sebelum teks pertama ditautkan ke chunk #0; gambar setelah teks terakhir ditautkan ke chunk terakhir; dokumen *image-only* (PDF scan / slide gambar saja) menghasilkan *image-backed chunk* sehingga **0 aset yatim**.
  - Satu stempel `valid_from: DateTime<Utc>` dibuat sekali di `SopIngestionPipeline::ingest_document()` lalu diteruskan ke `SopMetadata` dan `CommandSafeChunker` agar `metadata.valid_from == chunk.valid_from` selalu identik.
- **Vision Captioning Trait (`#[async_trait]`):** `pub trait VisionCaptioner: Send + Sync`:
  - `NoopVisionCaptioner`: mode default dev lokal (`VisionMode::Noop`, `CaptionStatus::Noop`).
  - `OpenAiCompatibleVisionCaptioner` (`reqwest`):
    - Dibangun dengan `reqwest::Client::builder().no_proxy().redirect(reqwest::redirect::Policy::none())` (menutup celah bypass lewat `HTTP_PROXY`/`HTTPS_PROXY` & HTTP 30x).
    - Validasi ketat skema `http`/`https` saja + **resolusi DNS di muka lalu validasi IP** (izinkan hanya loopback `127.0.0.1`/`::1` & RFC1918 privat; **tolak keras** IP publik, IPv4-mapped IPv6 `::ffff:...`, link-local/cloud IMDS `169.254.0.0/16` & `fe80::/10`, serta `0.0.0.0`/`::`), kemudian pin alamat IP tervalidasi ke `ClientBuilder::resolve()` untuk mencegah **DNS rebinding (TOCTOU)**.
    - `VisionConfig.allowed_hosts`: daftar host/IP eksak (tanpa wildcard, tanpa item kosong) yang tetap wajib lolos validasi IP non-IMDS/non-publik kecuali diizinkan eksplisit oleh IP privat.
    - Resilience: `timeout = 30s` per gambar, `max_tokens = 300` & batas panjang output `2000` char (anti prompt-injection bloat), retry 1x **hanya** untuk error jaringan / HTTP `5xx` (tidak retry `4xx`), respons HTTP 200 kosong dianggap `CaptionStatus::Failed`, dan **circuit breaker** (setelah 3 kegagalan beruntun, sisa gambar pada dokumen tersebut langsung ditandai `CaptionStatus::Failed` agar tidak hang 100 menit saat VLM mati).
- **Asset Storage Trait (`#[async_trait]`):** `pub trait AssetStore: Send + Sync` + `pub trait S3PutObject: Send + Sync`:
  - **Pemisahan ID Logis vs Nama File Fisik (Windows-Safe):** `asset_id` logis tetap `"{doc_id}:v{doc_version}:img{order_index}"`, sedangkan jalur penyimpanan fisik memakai nama file aman bebas `:` yaitu `<doc_id>/v<doc_version>/img<order_index>.<ext>`.
  - `LocalFsAssetStore` (async via `tokio::fs`): memvalidasi `doc_id` & ekstensi secara ketat **sebelum membuat direktori apa pun** (menolak `..`, `/`, `\`, `:`, prefix drive `C:`, nama device Windows `CON`/`PRN`/`AUX`/`NUL`/`COM1..9`/`LPT1..9`, titik/spasi akhir, dan symlink lewat `symlink_metadata`), menulis lewat **temp-file + atomic rename**, membersihkan direktori versi target sebelum re-ingest `(doc_id, doc_version)` yang sama, serta menyediakan `delete_version_dir()` untuk rollback jika pipeline gagal di tengah dokumen.
  - `MinioAssetStore`: `storage_uri = "s3://<bucket>/<doc_id>/v<doc_version>/img<order_index>.<ext>"`.
- **CLI Binary:** `clap` (`clap-rs/clap`) — `cargo run -p sop-ingestion -- ingest --file ... --segment EBIS --version 1 --source-type sop --output-dir .scratch/ingest-preview`.

---

## 3. Hard Resource & Decompression-Bomb Limits

Untuk menjaga target memori server kantor (`< 128 MB RAM` di `infra/HARDWARE-SIZING.md`) dan mencegah serangan *zip bomb* / *FlateDecode bomb*, parser menerapkan batas keras sebelum/saat membaca stream:

| Limit | Nilai Default | Error Saat Dilanggar |
| :--- | :---: | :--- |
| `max_file_bytes` (ukuran file input mentah) | `50 MB` (`52_428_800`) | `ResourceLimitExceeded` |
| `max_zip_entries` (entri di `.docx`/`.pptx`/`.xlsx`) | `1_000` | `ResourceLimitExceeded` |
| `max_uncompressed_entry_bytes` (1 entri XML/ZIP/PDF stream) | `25 MB` (`26_214_400`) | `ResourceLimitExceeded` |
| `max_total_uncompressed_bytes` (total dekompresi 1 dokumen) | `100 MB` (`104_857_600`) | `ResourceLimitExceeded` |
| `max_xlsx_cells` (total cell terbaca per workbook) | `200_000` | `ResourceLimitExceeded` |
| `max_images_per_doc` | `100` | `ResourceLimitExceeded` |
| `max_image_bytes` (ukuran 1 gambar) | `10 MB` (`10_485_760`) | `ResourceLimitExceeded` |
| `max_total_image_bytes` (total byte gambar per dokumen) | `50 MB` (`52_428_800`) | `ResourceLimitExceeded` |

> **Streaming Persistence:** Pipeline memproses & menyimpan gambar secara inkremental ke `AssetStore` lalu melepaskan buffer `Vec<u8>` setelah tersimpan dan ter-caption, sehingga peak RAM tetap jauh di bawah `128 MB`.

---

## 4. Commands

```powershell
# Format, Lint, & Strict Clippy (Blocking Gates — CONSTRAINTS.md)
cargo fmt --all -- --check
cargo clippy --workspace --all-targets -- -D warnings

# Unit & Integration Tests + Coverage >= 80%
cargo test --workspace
cargo llvm-cov --workspace --fail-under-lines 80

# Mandatory Security & Policy Guards
cargo test -p sop-ingestion secret_scrubber
cargo test zero_db_policy
gitleaks detect --source . --redact --no-banner

# Dry-run CLI ingest 1 file SOP (output ke .scratch/ yang ter-gitignore)
cargo run -p sop-ingestion -- ingest --file "path/to/sample.docx" --segment EBIS --version 1 --output-dir .scratch/ingest-preview
```

---

## 5. Workspace Structure

```text
c:/Users/Administrator/LLM/
├── Cargo.toml                     # Workspace root (edition = "2021")
└── crates/
    ├── sop-core/
    │   ├── Cargo.toml
    │   └── src/
    │       ├── lib.rs             # Re-exports & make_doc_id / sha256_bytes / sha256_text
    │       ├── models.rs          # Public serde + schemars::JsonSchema contracts
    │       └── error.rs           # SopIngestionErrorCode (Display SCREAMING_SNAKE_CASE) & SopIngestionError
    ├── sop-test-support/          # Dev-only fixture crate (zero dead_code clippy warnings)
    │   ├── Cargo.toml
    │   └── src/lib.rs             # Programmatic synthetic .docx/.pdf/.xlsx/.pptx/.sh/.yaml/.md builders
    └── sop-ingestion/
        ├── Cargo.toml
        ├── src/
        │   ├── lib.rs
        │   ├── scrubber.rs        # Deterministic Secret Scrubber (-storepass, password=, PEM, Bearer)
        │   ├── assets.rs          # Async AssetStore, S3PutObject, LocalFsAssetStore (Windows-safe atomic), MinioAssetStore
        │   ├── vision.rs          # Async VisionCaptioner, VisionConfig, Noop, OpenAiCompatible (DNS-pinning + no_proxy + circuit breaker)
        │   ├── parser/
        │   │   ├── mod.rs         # Dispatcher, ResourceLimits, bomb guards
        │   │   ├── docx.rs        # zip + quick-xml (runs, styles outlineLvl, DrawingML + VML)
        │   │   ├── pptx.rs        # zip + quick-xml (sldIdLst order + ../media/ resolution)
        │   │   ├── xlsx.rs        # calamine + zip xl/media/*
        │   │   ├── pdf.rs         # oxidize-pdf/pdf-extract + lopdf XObjects + image PNG re-encode + scanned PDF support
        │   │   └── script.rs      # encoding_rs (UTF-8/UTF-16 BOM + binary reject + cp1252) + .md/.yaml/.yml/.sh/.sql/.xml
        │   ├── chunker.rs         # CommandSafeChunker (UTF-8 char-safe + positional asset linking)
        │   ├── pipeline.rs        # Async SopIngestionPipeline::ingest_document() + rollback on mid-doc error
        │   └── main.rs            # CLI binary (clap)
        └── tests/
            ├── models_test.rs     # + zero_db_policy (scans all Cargo.toml/Cargo.lock + subprocess ban)
            ├── scrubber_test.rs
            ├── assets_test.rs
            ├── vision_test.rs
            ├── parser_test.rs
            ├── chunker_test.rs
            └── pipeline_test.rs
```

---

## 6. Complete Public Data Contracts (`crates/sop-core/src/models.rs`)

```rust
use chrono::{DateTime, Utc};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use std::fmt;
use std::num::NonZeroU32;
use thiserror::Error;

fn default_true() -> bool { true }
fn default_role_acl() -> Vec<String> {
    vec!["user_kantor".to_string(), "admin_sop".to_string()]
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "UPPERCASE")]
pub enum SopSegment {
    Ebis,
    Retail,
    Wibs,
    General, // Cross-segment SOP & knowledge/domain-pack visible to all segments in Module 2
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Default, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum SourceType {
    #[default]
    Sop,
    DomainPack,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum SopIngestionErrorCode {
    FileNotFound,
    InvalidPath,
    InvalidMetadata,
    UnsupportedFormat,
    EmptyFile,
    CorruptFile,
    AssetStoreFailed,
    VisionHostBlocked,
    VisionFailed,
    ResourceLimitExceeded,
}

impl fmt::Display for SopIngestionErrorCode {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let s = match self {
            Self::FileNotFound => "FILE_NOT_FOUND",
            Self::InvalidPath => "INVALID_PATH",
            Self::InvalidMetadata => "INVALID_METADATA",
            Self::UnsupportedFormat => "UNSUPPORTED_FORMAT",
            Self::EmptyFile => "EMPTY_FILE",
            Self::CorruptFile => "CORRUPT_FILE",
            Self::AssetStoreFailed => "ASSET_STORE_FAILED",
            Self::VisionHostBlocked => "VISION_HOST_BLOCKED",
            Self::VisionFailed => "VISION_FAILED",
            Self::ResourceLimitExceeded => "RESOURCE_LIMIT_EXCEEDED",
        };
        f.write_str(s)
    }
}

#[derive(Debug, Error)]
#[error("[{code}] {message}")]
pub struct SopIngestionError {
    pub code: SopIngestionErrorCode,
    pub message: String, // MUST NEVER contain raw SOP body or credentials
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum BlockType {
    Heading,
    Paragraph,
    CodeCli,
    Table,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum CaptionStatus {
    Ok,
    Noop,
    Failed,
}

#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema)]
pub struct SopMetadata {
    pub doc_id: String,               // Deterministic, capped <= 64 chars: "{seg}-{slug_trunc}-{ext}-{hash6}"
    pub source_filename: String,
    pub source_file_sha256: String,
    pub segment: SopSegment,
    #[serde(default)]
    pub source_type: SourceType,
    pub doc_version: NonZeroU32,      // Guaranteed >= 1 at compile-time
    #[serde(default = "default_true")]
    pub is_active: bool,
    pub valid_from: DateTime<Utc>,    // Single UTC timestamp stamped once per ingest_document() call
    pub valid_until: Option<DateTime<Utc>>,
    #[serde(default = "default_role_acl")]
    pub role_acl: Vec<String>,        // 2-Tier Office RBAC: ["user_kantor", "admin_sop"]
}

#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema)]
pub struct ParsedBlock {
    pub block_index: usize,
    pub block_type: BlockType,
    pub section_path: Vec<String>,
    pub section_heading: String,
    pub text: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema)]
pub struct ParsedImage {
    pub order_index: usize,
    pub block_index: usize,
    pub section_path: Vec<String>,
    pub section_heading: String,
    pub filename: String,
    pub mime_type: String,
    #[serde(skip)]
    pub data: Vec<u8>,
}

#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema)]
pub struct ParsedDocument {
    pub source_filename: String,
    pub source_file_sha256: String,
    pub blocks: Vec<ParsedBlock>,
    pub images: Vec<ParsedImage>,
}

#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema)]
pub struct ExtractedAsset {
    pub asset_id: String,             // Logical ID: "{doc_id}:v{doc_version}:img{order_index}"
    pub doc_id: String,
    pub doc_version: NonZeroU32,
    pub filename: String,             // Windows-safe physical filename: "img{order_index}.{ext}"
    pub mime_type: String,
    pub storage_uri: String,          // "local://<doc_id>/v<ver>/img<idx>.<ext>" or "s3://<bucket>/..."
    pub caption: String,              // Scrubbed by Secret Scrubber
    pub caption_status: CaptionStatus,
    pub section_path: Vec<String>,
    pub section_heading: String,
    pub block_index: usize,
    pub order_index: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema)]
pub struct SopChunk {
    pub chunk_id: String,             // Logical ID: "{doc_id}:v{doc_version}:{chunk_index}"
    pub chunk_index: usize,
    pub doc_id: String,
    pub source_filename: String,
    pub source_file_sha256: String,
    pub segment: SopSegment,
    #[serde(default)]
    pub source_type: SourceType,
    pub doc_version: NonZeroU32,
    #[serde(default = "default_true")]
    pub is_active: bool,
    pub valid_from: DateTime<Utc>,
    pub valid_until: Option<DateTime<Utc>>,
    #[serde(default = "default_role_acl")]
    pub role_acl: Vec<String>,
    pub section_path: Vec<String>,
    pub section_heading: String,
    pub content: String,              // Scrubbed by Secret Scrubber
    pub has_code_or_cli: bool,
    pub oversized_atomic_split: bool,
    pub asset_ids: Vec<String>,
    pub asset_captions: Vec<String>,
    pub content_sha256: String,       // SHA-256 of scrubbed chunk `content` (independent of Vision mode)
}

#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema)]
pub struct IngestResult {
    pub metadata: SopMetadata,
    pub chunks: Vec<SopChunk>,
    pub assets: Vec<ExtractedAsset>,
}
```

---

## 7. Success Criteria & Boundaries

1. **Windows-Safe Multimodal & Positional Linking:** Ingest `.docx` dengan sub-judul berulang (`"Before Changes"`) dan 2+ gambar tertanam menyimpan seluruh gambar ke `<doc_id>/v<doc_version>/img<idx>.<ext>` (bebas `:`), menautkan `asset_ids` + `asset_captions` hanya ke chunk pemiliknya, dan PDF scan 0-teks menghasilkan *image-backed chunks* tanpa aset yatim.
2. **Command, XML, SQL, Table & Secret Scrubbing Integrity:** Blok CLI, XML, SQL, dan tabel tidak pernah terpotong oleh `overlap_chars`, aman pada UTF-8 multi-byte, dan seluruh pola kredensial (`-storepass`, `password=`, PEM, Bearer) ter-redaksi di chunk, caption, dan JSON output.
3. **Deterministic Versioning & Windows Path Defense:** `make_doc_id` stabil lintas `v1`/`v2`, tidak kolisi antara `deploy.docx` vs `deploy.sh`, panjang ≤ 64 char, dan `LocalFsAssetStore` memblokir traversal, drive prefix, device names (`CON`/`NUL`), serta symlink sebelum membuat direktori apa pun.
4. **Hardened SSRF, Bomb Defense & Zero-DB:** `OpenAiCompatibleVisionCaptioner` menerapkan `.no_proxy()` + `redirect::Policy::none()` + DNS IP pinning (blokir publik, IPv4-mapped IPv6, IMDS `169.254.0.0/16`) + circuit breaker; parser memblokir decompression bomb; `zero_db_policy` memverifikasi 0 crate Oracle/SSH di seluruh workspace & 0 panggilan `sqlplus`/`ssh`.
5. **Quality Gates:** `cargo fmt --check`, `cargo clippy --workspace --all-targets -- -D warnings`, `cargo test --workspace`, `cargo llvm-cov --workspace --fail-under-lines 80`, dan `gitleaks` semuanya **PASS (exit 0)**.

---

## 8. Out of Scope (Deferred)

- **Embedding & Qdrant Upsert / Version Invalidation:** Modul #2 (`crates/sop-memory-rag`).
- **Rust Axum Upload Endpoint, Office RBAC, & Non-DB Knowledge Automation:** Modul #3 (`crates/triage-engine`).
- **Auto-Sync SharePoint API & Graphiti Bi-Temporal Sync:** Ditunda ke V2 / Fase 2.
