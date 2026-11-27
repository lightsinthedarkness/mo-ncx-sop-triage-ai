# Task Checklist — Module 1 (`crates/sop-core` + `crates/sop-ingestion` — 100% Pure Rust)

Source spec: [spec/SPEC-sop-ingestion.md](../spec/SPEC-sop-ingestion.md)  
Source plan: [tasks/plan.md](plan.md)

## Prerequisite
- [ ] **Step 0: Install Rust Toolchain (`rustup`)**
  - Acceptance: `rustc`, `cargo`, `rustfmt`, `clippy`, and `cargo-llvm-cov` active; `init.ps1` reports `[OK] Rust detected`.

## Phase 1: Foundation (Tasks 1–3)

- [ ] **Task 1: Cargo Workspace, `crates/sop-core` Public Contracts & Synthetic Fixture Harness** *(Size: M)*
  - Acceptance: Root `Cargo.toml` workspace + `crates/sop-core` compiles with zero warnings; all public models (`SopSegment`, `SopMetadata`, `SopIngestionErrorCode`, `SopIngestionError`, `ParsedBlock`, `ParsedImage`, `ParsedDocument`, `ExtractedAsset`, `SopChunk`, `IngestResult`) + deterministic `make_doc_id()` + `zero_db_policy` validated; synthetic fixtures (`.docx`, `.pdf`, `.xlsx`, `.pptx`, `.sh` cp1252, `.md`, 0-byte, corrupt) ready with zero real credentials.
  - Verify: `cargo test --test models_test && cargo fmt --all -- --check && cargo clippy --workspace --all-targets -- -D warnings`
  - Dependencies: Step 0

- [ ] **Task 2: Versioned Asset Storage (`LocalFsAssetStore` + `MinioAssetStore`)** *(Size: S)*
  - Acceptance: `AssetStore` + `S3PutObject` traits implemented; persists to `<doc_id>/v<doc_version>/<asset_id>.<ext>` with canonical `local://` / `s3://` URI; blocks path traversal on BOTH `doc_id` and `filename`; `v2` never overwrites `v1`.
  - Verify: `cargo test --test assets_test && cargo clippy --workspace --all-targets -- -D warnings`
  - Dependencies: Task 1

- [ ] **Task 3: Private-Allowlist Vision Captioning (`Noop` + `OpenAiCompatibleVisionCaptioner`)** *(Size: S)*
  - Acceptance: `VISION_MODE=noop` returns `CaptionStatus::Noop`; `local_vlm` enforces strict private-host allowlist + `redirect::Policy::none()`, retries once on transient error (`wiremock`), and degrades non-destructively to `CaptionStatus::Failed` without orphaning assets.
  - Verify: `cargo test --test vision_test && cargo clippy --workspace --all-targets -- -D warnings`
  - Dependencies: Task 1

### Checkpoint 1 (After Tasks 1–3)
- [ ] All foundation unit tests pass, `cargo fmt --check` & `cargo clippy -D warnings` zero errors.

## Phase 2: Multimodal Rust Parsing & Command/Table-Safe Chunking (Tasks 4–5)

- [ ] **Task 4: Multimodal Pure-Rust Document & Script Parser (`.docx/.pdf/.xlsx/.pptx/.md/.sh/.sql/.xml`)** *(Size: M)*
  - Acceptance: Parses all supported extensions (case-insensitive) via `zip` + `quick-xml` + `calamine` + `lopdf` + `encoding_rs`; preserves verbatim CLI/XML/SQL (zero Markdown escaping) & tables; extracts ordered images with `block_index` + `section_path`; handles cp1252 fallback; enforces image count/size caps & structured errors (`FileNotFound`, `InvalidPath`, `UnsupportedFormat`, `EmptyFile`, `CorruptFile`, `ResourceLimitExceeded`).
  - Verify: `cargo test --test parser_test && cargo clippy --workspace --all-targets -- -D warnings`
  - Dependencies: Task 1

- [ ] **Task 5: Command/Table-Safe & Position-Linked Chunker** *(Size: M)*
  - Acceptance: CLI, XML, SQL, and table blocks never split mid-block; `overlap_chars` never slices into atomic blocks; oversized atomic blocks preserved up to `max_atomic_chars = 4800`; `asset_ids` + `asset_captions` linked by `block_index` (immune to repeated `"Before Changes"` headings); uniform `valid_from` & versioned `chunk_id` stamped; `content_sha256` independent of Vision mode.
  - Verify: `cargo test --test chunker_test && cargo clippy --workspace --all-targets -- -D warnings`
  - Dependencies: Task 1, Task 4

## Phase 3: Pipeline Orchestrator, CLI & Final Gate (Task 6)

- [ ] **Task 6: Ingestion Pipeline (`ingest_document`) & Dry-Run CLI** *(Size: M)*
  - Acceptance: End-to-end `SopIngestionPipeline::ingest_document()` emits valid `IngestResult` with stable `doc_id` across `v1`/`v2`, non-colliding assets/chunks, and redacted error messages; CLI (`clap`) writes `ingest_result.json` cleanly.
  - Verify: `cargo fmt --all -- --check && cargo clippy --workspace --all-targets -- -D warnings && cargo test --workspace && cargo llvm-cov --workspace --fail-under-lines 80 && gitleaks detect --source . --redact --no-banner && powershell -ExecutionPolicy Bypass -File .\init.ps1`
  - Dependencies: Tasks 1–5

### Checkpoint 2 (Module 1 Complete Gate)
- [ ] All Rust tests pass with ≥ 80% coverage, zero clippy/fmt warnings, `zero_db_policy` PASS, `gitleaks` 0 leaks, `feature_list.json` & `progress.md` updated with observed evidence.
