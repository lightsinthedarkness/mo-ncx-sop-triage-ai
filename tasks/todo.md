# Task Checklist — Module 1 (`crates/sop-core` + `crates/sop-ingestion` — Rust 2021)

Source spec: [spec/SPEC-sop-ingestion.md](../spec/SPEC-sop-ingestion.md)  
Source plan: [tasks/plan.md](plan.md)

## Prerequisite
- [ ] **Step 0: Install Rust Toolchain (`rustup`)**
  - Acceptance: `rustc`, `cargo`, `rustfmt`, `clippy`, `llvm-tools-preview`, and `cargo-llvm-cov` active; `init.ps1` reports `[OK] Rust detected`.

## Phase 1: Foundation & Security Guards (Tasks 1–3)

- [ ] **Task 1: Cargo Workspace, `crates/sop-core` Contracts, `crates/sop-test-support`, & `zero_db_policy`** *(Size: M)*
  - Acceptance: Rust 2021 workspace compiles with zero warnings; all public models derive `serde` + `schemars::JsonSchema`, `NonZeroU32` `doc_version`, `SourceType` (`Sop`/`DomainPack`), `role_acl = ["user_kantor", "admin_sop"]`, `SCREAMING_SNAKE_CASE` error Display; `make_doc_id()` non-colliding & ≤ 64 chars; `zero_db_policy` scans all workspace `Cargo.toml`/`Cargo.lock` & source; synthetic fixtures in `crates/sop-test-support` produce zero `dead_code` warnings.
  - Verify: `cargo test --test models_test && cargo fmt --all -- --check && cargo clippy --workspace --all-targets -- -D warnings`
  - Dependencies: Step 0

- [ ] **Task 2: Secret Scrubber & Async Windows-Safe Versioned Asset Storage** *(Size: M)*
  - Acceptance: `secret_scrubber` redacts `-storepass`, `-keypass`, `password=`, `passwd=`, Bearer tokens, PEM keys; async `AssetStore` + `S3PutObject` write Windows-safe `<doc_id>/v<ver>/img<idx>.<ext>` (no `:`) via atomic temp-file rename; blocks traversal, drive prefixes, `CON`/`NUL`, trailing dots, symlinks BEFORE `create_dir_all`; supports `delete_version_dir()` rollback.
  - Verify: `cargo test --test scrubber_test --test assets_test && cargo clippy --workspace --all-targets -- -D warnings`
  - Dependencies: Task 1

- [ ] **Task 3: Hardened Async Vision Captioning (`Noop` + `OpenAiCompatibleVisionCaptioner`)** *(Size: S)*
  - Acceptance: Uses injected `VisionConfig` (zero `std::env::set_var` in tests); enforces `.no_proxy()`, `redirect::Policy::none()`, `http`/`https`-only, DNS pre-resolve + IP pinning blocking public/IPv4-mapped IPv6/IMDS `169.254.0.0/16`/`0.0.0.0`; retries `5xx`/network only; caps `max_tokens=300`; 3-failure circuit breaker.
  - Verify: `cargo test --test vision_test && cargo clippy --workspace --all-targets -- -D warnings`
  - Dependencies: Task 1

### Checkpoint 1 (After Tasks 1–3)
- [ ] All foundation & security tests pass, `cargo fmt --check` & `cargo clippy --workspace --all-targets -- -D warnings` zero errors.

## Phase 2: Multimodal Rust Parsing & UTF-8 Safe Chunking (Tasks 4–5)

- [ ] **Task 4: Multimodal Pure-Rust Document, PDF, OOXML & Script Parser** *(Size: L)*
  - Acceptance: Parses `.docx`, `.pptx`, `.xlsx`, `.pdf`, `.md`, `.yaml`, `.yml`, `.sh`, `.sql`, `.xml` (case-insensitive); handles `.docx` run concat/`styles.xml`/DrawingML+VML, `.pptx` `<p:sldIdLst>`/`../media/`, `.xlsx` `xl/media/*`, `.pdf` text + `lopdf` XObjects re-encoded to PNG via `image` + 0-text scanned PDFs, `encoding_rs` UTF-8/UTF-16 BOM + binary reject; enforces all decompression-bomb & resource limits (`ResourceLimitExceeded`).
  - Verify: `cargo test --test parser_test && cargo clippy --workspace --all-targets -- -D warnings`
  - Dependencies: Task 1

- [ ] **Task 5: UTF-8 Safe Command/Table Chunker & Positional Asset Linker** *(Size: M)*
  - Acceptance: Deterministic `CodeCli` classification; UTF-8 char-boundary safe slicing; `overlap_chars` never slices atomic blocks; >4800 atomic blocks split cleanly on `\n` (`oversized_atomic_split = true`); `asset_ids` + `asset_captions` linked by `block_index` with zero orphans (incl. leading/trailing/image-only); single `valid_from` passed from pipeline; `content_sha256` independent of Vision mode.
  - Verify: `cargo test --test chunker_test && cargo clippy --workspace --all-targets -- -D warnings`
  - Dependencies: Task 1, Task 4

## Phase 3: Async Streaming Pipeline, CLI & Final Gate (Task 6)

- [ ] **Task 6: Streaming Pipeline (`ingest_document`), Rollback, & CLI (`clap`)** *(Size: M)*
  - Acceptance: End-to-end async `SopIngestionPipeline::ingest_document()` streams assets to stay < 128 MB RAM, scrubs secrets from chunks/captions/JSON, handles `SourceType::DomainPack`, rolls back via `delete_version_dir()` on mid-doc error, and CLI writes valid scrubbed `ingest_result.json`.
  - Verify: `cargo fmt --all -- --check && cargo clippy --workspace --all-targets -- -D warnings && cargo test --workspace && cargo llvm-cov --workspace --fail-under-lines 80 && gitleaks detect --source . --redact --no-banner && powershell -ExecutionPolicy Bypass -File .\init.ps1`
  - Dependencies: Tasks 1–5

### Checkpoint 2 (Module 1 Complete Gate)
- [ ] All Rust tests pass with ≥ 80% coverage, zero clippy/fmt warnings, `zero_db_policy` & `secret_scrubber` PASS, `gitleaks` 0 leaks, `feature_list.json` & `progress.md` updated with observed evidence.
