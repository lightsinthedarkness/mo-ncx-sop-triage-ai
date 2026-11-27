# ADR-003: 100% Pure Rust Backend Workspace (`crates/sop-core`, `sop-ingestion`, `sop-memory-rag`, `triage-engine`)

## Status
Accepted (Approved by Owner, 2026-11-27 — Supersedes Python Module #1 decision in [ADR-001](ADR-001-hybrid-python-rust-and-jev-orchestrator.md); preserves Jev optional `E1` & [ADR-002](ADR-002-internal-siebel16-oracle12c-zero-db-advisory-and-knowledge-automation.md) Zero-Direct-DB On-Prem First)

## Date
2026-11-27

## Context
Di [ADR-001](ADR-001-hybrid-python-rust-and-jev-orchestrator.md), Modul #2 (`sop-memory-rag`) & Modul #3 (`triage-engine-api`) sudah memakai **Rust**, sementara Modul #1 (`sop-ingestion`) masih memakai Python (`Docling`). Setelah menetapkan target deployment **100% intranet / on-prem kantor (Siebel 16 + Oracle 12c, Zero Direct DB)** di [ADR-002](ADR-002-internal-siebel16-oracle12c-zero-db-advisory-and-knowledge-automation.md), mempertahankan 2 runtime bahasa berbeda (Python + PyTorch/Docling multi-GB **dan** Rust) di server internal kantor menambah beban *packaging*, RAM, *offline dependency mirroring*, dan risiko ketidaksinkronan kontrak tipe data lintas bahasa.

Owner memutuskan untuk **menyatukan seluruh backend (Modul #1, #2, & #3) ke 100% Pure Rust** dalam satu **Cargo Workspace** tunggal.

## Decision
Seluruh backend `ykztir-ncx-ai` (Design 2.5 / PRD 2.5) dibangun dengan **100% Pure Rust** dalam satu Cargo Workspace (`Cargo.toml` di root) dengan 4 crate modular dan repo open-source Rust terbaik yang telah diverifikasi:

| Crate Workspace | Peran | Repositori Open-Source Rust Terverifikasi |
| :--- | :--- | :--- |
| **`crates/sop-core`** | Kontrak data publik tunggal (`SopSegment`, `SopMetadata`, `SopChunk`, `ExtractedAsset`, `IngestResult`, `SopIngestionError`) dipakai compile-time oleh Mod 1, 2, & 3 | `serde-rs/serde`, `chronotope/chrono`, `RustCrypto/hashes` (`sha2`), `dtolnay/thiserror`, `GREsau/schemars` |
| **`crates/sop-ingestion`** *(Modul #1)* | Parsing `.docx`/`.pptx` (ZIP+XML + ekstraksi berurutan `word/media/*`), `.xlsx`, `.pdf`, & skrip/domain-pack (`.md`/`.sh`/`.sql`/`.xml`), *Command-Safe Chunker*, *Local Vision-LLM Client*, Versioned `AssetStore` (LocalFS/MinIO), & CLI | `zip-rs/zip2` (`zip`), `tafia/quick-xml`, `tafia/calamine`, `J-F-Liu/lopdf` *(opsi alternatif: `bzsanti/oxidize-pdf`)*, `hsivonen/encoding_rs`, `seanmonstar/reqwest`, `clap-rs/clap` |
| **`crates/sop-memory-rag`** *(Modul #2)* | Qdrant Native Hybrid Search (Dense `BAAI/bge-m3` + Sparse BM25) + Reranker + Temporal Versioning (`is_active`, `doc_version`) + Local ONNX/HTTP Embeddings | `qdrant/rust-client` (`qdrant-client`), `0xPlaygrounds/rig` (`rig-core`, `rig-qdrant`), `Anush008/fastembed-rs` (`fastembed`) |
| **`crates/triage-engine`** *(Modul #3)* | 4-Stage Triage State Machine, *Offline-First Local Guided JSON Router* (+ **Jev** opsional `E1`), **Zero Direct DB Guard**, Office 2-Tier RBAC + *Immutable Audit Log*, *Auto Handover Note*, *Auto SOP-Gap Detector*, SSE Streaming, & OTel Trace | `tokio-rs/axum`, `tokio-rs/tokio`, `0xPlaygrounds/rig`, `launchbadge/sqlx`, `Keats/jsonwebtoken`, `RustCrypto/password-hashes` (`argon2`), `open-telemetry/opentelemetry-rust` |

### Penanganan Khusus PDF Kompleks / Scan di Pure Rust
- PDF born-digital diekstrak langsung secara native oleh `lopdf` (zero C-dependency, 100% offline).
- Gambar tertanam di `.docx`/`.pptx`/`.pdf` (termasuk 24+ *screenshot `before/after`* SOP NCX) diekstrak secara deterministik dan dikirim ke **Local Vision-LLM (`Qwen2.5-VL` via `reqwest` dengan strict private-host allowlist + `redirect::Policy::none()`)** untuk deskripsi teknis.

### Batasan Tetap Tidak Berubah
- **Zero Direct DB / Zero Prod Execution (`ADR-002`):** Dilarang menambahkan crate driver Oracle (`oracle`, `sibyl`, `oci`) maupun crate SSH exec produksi (`russh`/`ssh2` ke server Siebel) di `Cargo.toml`.
- **100% Intranet / On-Prem First:** Seluruh binary Rust dapat dikompilasi dan di-deploy sebagai artefak mandiri (< 50 MB RAM idle) tanpa Python/virtualenv di server kantor.
- **Modul #4 (`web/` — `opendesign-web-portal`):** Tetap **Standalone OpenDesign Web App** (HTML/CSS/JS/TS), terpisah penuh dari `https://ncxall.my.id/dashboard`.

## Consequences
- **Single-Language Compile-Time Safety:** Kontrak `IngestResult` / `SopChunk` di `crates/sop-core` dikompilasi bersama oleh Mod 1, Mod 2, dan Mod 3 — mustahil terjadi *schema drift* antar bahasa.
- **Quality Gates Unified (`CONSTRAINTS.md`):** Seluruh gate backend kini seragam memakai `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test --workspace`, `cargo llvm-cov --workspace --fail-under-lines 80`, plus `gitleaks`.
- **Prasyarat Lokal Sebelum Phase 4 TDD:** Pasang toolchain Rust via `rustup` (`rustc`, `cargo`, `rustfmt`, `clippy`, `cargo-llvm-cov`) di PC pengembangan Windows ini sebelum menulis baris kode pertama Modul #1.
