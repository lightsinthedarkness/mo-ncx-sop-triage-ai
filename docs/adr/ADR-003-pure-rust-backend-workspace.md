# ADR-003: 100% Pure Rust Backend Workspace (`crates/sop-core`, `sop-ingestion`, `sop-memory-rag`, `triage-engine`)

## Status
Accepted (Approved by Owner, 2026-11-27 — Supersedes Python Module #1 decision in [ADR-001](ADR-001-hybrid-python-rust-and-jev-orchestrator.md) and refines ingestion runtime in [ADR-002](ADR-002-internal-siebel16-oracle12c-zero-db-advisory-and-knowledge-automation.md); preserves optional Jev `E1` & Zero-Direct-DB On-Prem First)

## Date
2026-11-27

## Context
Di [ADR-001](ADR-001-hybrid-python-rust-and-jev-orchestrator.md), Modul #2 (`sop-memory-rag`) & Modul #3 (`triage-engine`) sudah memakai **Rust**, sementara Modul #1 (`sop-ingestion`) masih memakai Python (`Docling`). Setelah menetapkan target deployment **100% intranet / on-prem kantor (Siebel 16 + Oracle 12c, Zero Direct DB)** di [ADR-002](ADR-002-internal-siebel16-oracle12c-zero-db-advisory-and-knowledge-automation.md), mempertahankan 2 runtime bahasa berbeda untuk kode aplikasi backend (Python + PyTorch/Docling multi-GB **dan** Rust) di server internal kantor menambah beban *packaging*, RAM, *offline dependency mirroring*, dan risiko ketidaksinkronan kontrak tipe data lintas bahasa.

Owner memutuskan untuk **menyatukan seluruh aplikasi backend (Modul #1, #2, & #3) ke 100% Pure Rust** dalam satu **Cargo Workspace** tunggal (Rust 2021 edition), dengan opsi inference engine Pure Rust **`EricLBuehler/mistral.rs`** (`huggingface/candle`) dan protokol MCP standar **`modelcontextprotocol/rust-sdk` (`rmcp`)**.

## Decision
Seluruh aplikasi backend `ykztir-ncx-ai` (Design 2.5 / PRD 2.5) dibangun dengan **Rust 2021 edition** dalam satu Cargo Workspace (`Cargo.toml` di root) memakai repositori & versi crate resmi terverifikasi (`crates.io`, 2026-11-28):

| Crate Workspace | Peran | Repositori & Versi Crate Terverifikasi |
| :--- | :--- | :--- |
| **`crates/sop-core`** | Kontrak data publik tunggal (`SopSegment`, `SourceType`, `SopMetadata`, `SopChunk`, `ExtractedAsset`, `IngestResult`, `SopIngestionError`) dipakai compile-time oleh Mod 1, 2, & 3 | `serde-rs/serde`, `chronotope/chrono`, `RustCrypto/hashes` (`sha2`), `dtolnay/thiserror`, `GREsau/schemars` |
| **`crates/sop-test-support`** *(dev-only)* | Helper pembuat fixture sintetis bersama (`.docx`, `.pdf`, `.xlsx`, `.pptx`, `.sh`, `.md`, `.yaml`) untuk mencegah warning `dead_code` di integration tests | `zip`, `quick-xml`, `tempfile` |
| **`crates/sop-ingestion`** *(Modul #1)* | Parsing `.docx`/`.pptx` (ZIP+XML + ekstraksi berurutan `word/media/*`), `.xlsx` (`calamine` + `xl/media/*`), `.pdf` (`oxidize-pdf`/`pdf-extract` teks + `lopdf` objek gambar + `image` re-encode PNG), skrip/domain-pack (`.md`/`.yaml`/`.yml`/`.sh`/`.sql`/`.xml`), **Secret Scrubber**, *Command-Safe Chunker*, *Local Vision-LLM Client*, Async Versioned `AssetStore`, & CLI | `zip-rs/zip2` (`zip`), `tafia/quick-xml`, `tafia/calamine`, `J-F-Liu/lopdf`, `bzsanti/oxidize-pdf` *(atau `pdf-extract`)*, `image-rs/image`, `hsivonen/encoding_rs`, `seanmonstar/reqwest`, `clap-rs/clap` |
| **`crates/sop-memory-rag`** *(Modul #2)* | Qdrant Native Hybrid Search (Dense `BAAI/bge-m3` + Sparse BM25) + Reranker + Temporal Versioning (`is_active`, `doc_version`) + Local Embeddings | `qdrant/rust-client` (`qdrant-client` `1.20.0`), `0xPlaygrounds/rig` (`rig-core` `0.47.0`, `rig-qdrant` `0.47.1`), `Anush008/fastembed-rs` (`fastembed` `7.8.0` — *catatan: membungkus C++ ONNX Runtime, bobot & lib `ort` wajib di-pre-stage offline untuk mode air-gapped*, atau gunakan HTTP embedding lokal) |
| **`crates/triage-engine`** *(Modul #3)* | 4-Stage Triage State Machine, *Offline-First Local Structured Router* (+ **Jev** opsional `E1`), **Zero Direct DB Guard**, Office 2-Tier RBAC + *Immutable Audit Log*, *Auto Handover Note*, *Auto SOP-Gap Detector*, Standardized Non-DB MCP Tools (`rmcp`), SSE Streaming, Static Serving Portal `web/`, & OTel Trace | `tokio-rs/axum`, `tokio-rs/tokio`, `0xPlaygrounds/rig` (`0.47.0`), `modelcontextprotocol/rust-sdk` (`rmcp` `1.4.0`), `launchbadge/sqlx`, `Keats/jsonwebtoken`, `RustCrypto/password-hashes` (`argon2`), `open-telemetry/opentelemetry-rust` |
| **Local LLM & Vision Inference** | **Opsi A — 100% Pure Rust (`Recommended` untuk zero-Python server):** `EricLBuehler/mistral.rs` (`huggingface/candle`, structured JSON via `response_format` `llguidance`, kuantisasi ISQ/GGUF/UQFF).<br>**Opsi B — Sidecar Docker Opsional:** `vllm-project/vllm` (`guided_json`, AWQ/FP8 — berbasis Python/PyTorch di container terpisah) atau `ollama`. | `EricLBuehler/mistral.rs` (`huggingface/candle`) · atau container sidecar `vLLM` / `Ollama` |

### Penanganan PDF Kompleks & Scan di Pure Rust (Mitigasi Limitasi `lopdf`)
- Hasil riset `docs.rs` & adversarial audit membuktikan `lopdf` mentah tidak andal untuk ekstraksi teks font CID (`Identity-H` / `/ToUnicode` CMap) dan stream piksel `/FlateDecode` XObject bukan file PNG valid.
- Oleh karena itu `crates/sop-ingestion` **memisahkan tanggung jawab PDF**:
  1. Ekstraksi teks & urutan bacaan memakai *high-level pure-Rust extractor* (`oxidize-pdf` / `pdf-extract`),
  2. Ekstraksi objek gambar tertanam memakai `lopdf` lalu dinormalisasi/di-encode ulang ke PNG valid menggunakan crate **`image`** (`image-rs/image`),
  3. PDF hasil scan (**0 teks + N gambar**) diproses sebagai *image-backed chunks* yang dideskripsikan oleh **Local Vision-LLM (`Qwen2.5-VL`)** — tidak ditolak sebagai `EmptyFile`.

### Verifikasi Crate PDF (`crates.io` API, 2026-11-28)
| Crate | Versi | Lisensi | Unduhan | Update Terakhir |
| :--- | :--- | :--- | :--- | :--- |
| `oxidize-pdf` | `5.6.1` | MIT | ~219 rb | 2026-11-16 |
| `pdf-extract` | `0.12.1` | MIT | ~9,1 jt | 2026-09-16 |
| `lopdf` | `0.47.0` | MIT | ~33,5 jt | 2026-11-04 |

Ketiganya berlisensi MIT sehingga aman dipakai internal. Pilihan `oxidize-pdf` vs `pdf-extract` untuk teks **belum dikunci**: diputuskan lewat *spike* pada korpus PDF SOP nyata (lihat `tasks/plan.md` Spike S1); `pdf-extract` jauh lebih teruji, `oxidize-pdf` lebih baru tetapi kaya fitur.

### Batasan Tetap Tidak Berubah
- **Zero Direct DB / Zero Prod Execution (`ADR-002`):** Dilarang menambahkan crate driver Oracle (`oracle`, `sibyl`, `oci`, `odpi`) maupun crate SSH exec produksi (`russh`, `ssh2`, `openssh`, `async-ssh2-tokio`) di seluruh workspace `Cargo.toml`/`Cargo.lock`, maupun memanggil `Command::new("sqlplus" | "ssh")`.
- **Modul #4 (`web/` — `opendesign-web-portal`):** Tetap **Standalone OpenDesign Web App** (HTML/CSS/JS statis yang disajikan langsung oleh binary Rust `Axum` — nol Node.js di server produksi, terpisah penuh dari `https://ncxall.my.id/dashboard`).

## Alternatives Considered

### Hybrid Python Module #1 (`Docling`) + Rust Modules #2–#3 (`ADR-001` sebelumnya)
- **Pros:** `Docling` unggul *out-of-the-box* untuk PDF multi-kolom kompleks tanpa menulis kode parser OOXML/PDF sendiri.
- **Cons:** Memaksa server intranet kantor memelihara 2 runtime besar (Python 3.12 + PyTorch/Docling multi-GB + Rust), menambah kompleksitas *offline mirroring*, dan memutus *compile-time type safety* antara Modul #1 dan Modul #2.
- **Rejected:** Mayoritas SOP MO NCX adalah `.docx`/`.xlsx`/`.pptx` (ZIP+XML) dan skrip yang justru jauh lebih cepat, deterministik, dan ringan diparse native di Rust, sementara kasus PDF kompleks ditangani oleh `oxidize-pdf` + `image` + lokal `Qwen2.5-VL`.

### Frontend Rust WASM (`Dioxus` / `Leptos`) untuk Modul #4
- **Pros:** Satu bahasa Rust hingga lapisan UI browser.
- **Cons:** Tidak native dengan workflow desain **OpenDesign** (HTML/CSS/JS), ukuran bundle awal WASM lebih berat di browser PC kantor, dan iterasi layout/a11y lebih lambat.
- **Rejected:** HTML/CSS/JS statis OpenDesign yang disajikan langsung dari binary Rust `Axum` tetap menjaga server produksi **single-binary Rust tanpa Node.js**.

### Memakai `aaif-goose/goose` Mentah sebagai Platform Utama
- **Pros:** ~57K ★ Rust autonomous agent dengan dukungan MCP & YAML Recipes matang.
- **Cons:** Didesain sebagai *single-user desktop/CLI coding agent* tanpa login RBAC kantor, tanpa multimodal SOP RAG/versioning bawaan, dan tanpa kunci 4-stage *Zero-Premature-Verdict* state machine.
- **Rejected (Pola Diserap):** Kita menyerap protokol MCP Rust (`rmcp`) dan pola YAML Recipes non-DB sambil membangun platform multi-user intranet yang spesifik untuk MO NCX.

## Consequences
- **Single-Language Compile-Time Safety:** Kontrak `IngestResult` / `SopChunk` di `crates/sop-core` (lengkap dengan `schemars::JsonSchema` & `NonZeroU32`) dikompilasi bersama oleh Mod 1, Mod 2, dan Mod 3.
- **Klarifikasi Runtime Produksi Jujur:** Seluruh aplikasi backend kita + Qdrant + opsi `mistral.rs` berjalan **100% Pure Rust tanpa Python**. Jika Admin memilih sidecar opsional (`vLLM`, `LiteLLM`, atau Fase 2 `Graphiti`), komponen tersebut berjalan terisolasi sebagai container Docker terpisah.
- **Quality Gates Unified (`CONSTRAINTS.md`):** `cargo fmt --all -- --check`, `cargo clippy --workspace --all-targets -- -D warnings`, `cargo test --workspace`, `cargo llvm-cov --workspace --fail-under-lines 80`, `zero_db_policy`, `secret_scrubber`, & `gitleaks`.
- **Prasyarat Lokal Sebelum Phase 4 TDD:** Pasang toolchain Rust via `rustup` (`rustc`, `cargo`, `rustfmt`, `clippy`, `llvm-tools-preview`, `cargo-llvm-cov`) di PC pengembangan Windows ini.
