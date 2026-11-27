# Multimodal SOP Ingestion (`crates/sop-core` + `crates/sop-ingestion`) Implementation Plan — 100% Pure Rust

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` (or `superpowers:subagent-driven-development`) + `test-driven-development` + `incremental-implementation` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the deterministic, multimodal `crates/sop-core` + `crates/sop-ingestion` **100% Pure Rust** workspace crates that parse MO NCX SOP files (`.docx`, `.pdf`, `.xlsx`, `.pptx`, `.md`, `.sh`, `.sql`, `.xml`) & `knowledge/domain-pack/`, extract embedded screenshots in exact reading order to a versioned `AssetStore` with private-allowlist `VisionCaptioner`, and emit command/table-safe `SopChunk` records carrying stable `doc_id` and temporal metadata.

**Architecture:** Clean trait-injected vertical modules (`sop-core` → `assets` & `vision` → `parser/*` → `chunker` → `pipeline` & `main.rs` CLI). External I/O (`S3PutObject`, local Vision-LLM via `reqwest`) sits behind traits so all unit & integration tests run 100% offline using synthetic fixtures + `wiremock`.

**Tech Stack (Verified Rust Crates — `ADR-003`):** Rust stable, `serde` + `serde_json`, `chrono`, `sha2`, `thiserror`, `schemars`, `zip` (`zip-rs/zip2`), `quick-xml` (`tafia/quick-xml`), `calamine` (`tafia/calamine`), `lopdf` (`J-F-Liu/lopdf`), `encoding_rs`, `reqwest` (`redirect::Policy::none()`), `tokio`, `async-trait`, `clap`, dev-deps `tempfile`, `wiremock`.

**Spec:** [spec/SPEC-sop-ingestion.md](../spec/SPEC-sop-ingestion.md) (100% Pure Rust, preserving all 14 `doubt-driven-development` hardened requirements)

## Global Constraints
- Read [CONSTRAINTS.md](../CONSTRAINTS.md) before writing code; never weaken thresholds, add `#[allow(warnings)]`, use `unsafe`, or call `.unwrap()` on external inputs.
- `cargo fmt --all -- --check` = 0 diffs; `cargo clippy --workspace --all-targets -- -D warnings` = 0 warnings; `cargo test --workspace` = PASS; `cargo llvm-cov --workspace --fail-under-lines 80` = PASS; `gitleaks` = 0 findings.
- **Zero Direct DB (`ADR-002`):** Never add Oracle DB drivers (`oracle`/`sibyl`/`oci`) or prod SSH exec crates to `Cargo.toml`.
- **Zero raw SOP cloud calls:** `OpenAiCompatibleVisionCaptioner` enforces strict private-host allowlist + `redirect::Policy::none()`.
- Never log or embed raw SOP text/credentials in error messages or test fixtures.
- Preserve exact CLI/XML/SQL/table blocks — never slice into code/table blocks with `overlap_chars`.

## Review Focus (Edge Cases Pinned by Tests)
1. **Corrupt, empty, missing, directory, or non-UTF-8 inputs (`.DOCX` uppercase, 0-byte, cp1252 `.sh`):** Must return structured `SopIngestionError` (`FileNotFound`, `InvalidPath`, `UnsupportedFormat`, `EmptyFile`, `CorruptFile`) or decode gracefully (`UTF-8` / `UTF-8-BOM` → `Windows-1252`).
2. **Path traversal on BOTH `doc_id` and `filename`, plus `v1`/`v2` asset overwrite collision:** Must enforce canonical root containment and store under `<doc_id>/v<doc_version>/<asset_id>.<ext>`.
3. **Cloud exfiltration bypass (public hosts, public IPs, HTTP 30x redirects):** Must enforce strict private-host allowlist (loopback/RFC1918/`VISION_ALLOWED_HOSTS`) + `redirect::Policy::none()` and return `VisionHostBlocked`.
4. **Repeated SOP subheadings (`"Before Changes"`, `"After Changes"`) & Vision partial failure:** Must link assets by `block_index` + `section_path` (not heading string alone) and fall back non-destructively (`CaptionStatus::Failed`) after 1 retry without leaving orphaned assets; enforce `max_images_per_doc = 100` & `max_image_bytes = 10MB`.
5. **CLI/XML/SQL verbatim preservation & overlap slicing:** Must preserve verbatim `--`, `_`, `<Connector/>`, SQL, and tables intact in one `SopChunk`, forbid `overlap_chars` from slicing into atomic blocks, and keep oversized atomic blocks intact up to `max_atomic_chars = 4800`.

---

## Dependency Graph

```text
Cargo.toml (workspace) + crates/sop-core (models.rs, error.rs, make_doc_id, sha256)
    ├── crates/sop-ingestion/src/assets.rs (AssetStore, S3PutObject, LocalFsAssetStore, MinioAssetStore)
    ├── crates/sop-ingestion/src/vision.rs (VisionCaptioner, NoopVisionCaptioner, OpenAiCompatibleVisionCaptioner)
    ├── crates/sop-ingestion/src/parser/* (docx.rs, pptx.rs, xlsx.rs, pdf.rs, script.rs)
    └── crates/sop-ingestion/src/chunker.rs (CommandSafeChunker — CLI/XML/SQL/table-safe + positional asset linking)
                └── crates/sop-ingestion/src/pipeline.rs (SopIngestionPipeline::ingest_document)
                        └── crates/sop-ingestion/src/main.rs (`cargo run -p sop-ingestion -- ingest ...`)
```

---

## Prerequisite (Before Task 1)
- [ ] **Step 0:** Install Rust stable toolchain via `rustup` (`rustc`, `cargo`, `rustfmt`, `clippy`, `cargo-llvm-cov`) on this Windows PC and verify `powershell -ExecutionPolicy Bypass -File .\init.ps1` detects `cargo`.

---

## Task Breakdown (TDD Vertical Slices — 100% Rust)

### Task 1: Cargo Workspace, `crates/sop-core` Public Contracts & Synthetic Fixture Harness
**Files:**
- Create: `Cargo.toml` (workspace root)
- Create: `crates/sop-core/Cargo.toml`, `crates/sop-core/src/lib.rs`, `crates/sop-core/src/models.rs`, `crates/sop-core/src/error.rs`
- Create: `crates/sop-ingestion/Cargo.toml`, `crates/sop-ingestion/src/lib.rs`
- Create: `crates/sop-ingestion/tests/fixtures.rs`, `crates/sop-ingestion/tests/models_test.rs`

**Interfaces:**
- Produces: `SopSegment`, `SopMetadata`, `SopIngestionErrorCode`, `SopIngestionError`, `BlockType`, `CaptionStatus`, `ParsedBlock`, `ParsedImage`, `ParsedDocument`, `ExtractedAsset`, `SopChunk`, `IngestResult`, `make_doc_id(segment, filename) -> String`, `sha256_bytes(&[u8]) -> String`, `sha256_text(&str) -> String`, plus `zero_db_policy` Cargo dependency check test.

- [ ] **Step 1:** Scaffold root `Cargo.toml` workspace + `crates/sop-core` & `crates/sop-ingestion` manifests (zero Oracle/SSH dependencies).
- [ ] **Step 2:** Write failing tests in `crates/sop-ingestion/tests/models_test.rs` pinning all public serde contracts, `make_doc_id()` stability across `v1`/`v2`, `SopSegment::General`, `SopIngestionErrorCode`, non-leaking error formatting, and `zero_db_policy`.
- [ ] **Step 3:** Run `cargo test --test models_test` — verify FAIL.
- [ ] **Step 4:** Implement `crates/sop-core/src/{lib,models,error}.rs` and `crates/sop-ingestion/tests/fixtures.rs` (programmatic synthetic `.docx` ZIP+XML with repeated `"Before Changes"` headings + table + CLI `--importcert` + XML `<Connector/>` + 2 PNGs, synthetic `.pdf`, `.xlsx`, `.pptx`, `.sh` cp1252, `.md`, 0-byte, and corrupt files — zero real credentials).
- [ ] **Step 5:** Run `cargo test --test models_test`, `cargo fmt --all -- --check`, `cargo clippy --workspace --all-targets -- -D warnings` — verify PASS.

### Task 2: Versioned Asset Storage (`LocalFsAssetStore` + `MinioAssetStore`)
**Files:**
- Create: `crates/sop-ingestion/src/assets.rs`
- Test: `crates/sop-ingestion/tests/assets_test.rs`

- [ ] **Step 1:** Write failing tests in `assets_test.rs`: persists bytes to `<root>/<doc_id>/v<doc_version>/<asset_id>.<ext>`, returns canonical `local://...` URI, prevents `v2` overwriting `v1`, blocks path traversal in BOTH `doc_id` (`../../etc`) and `filename` (`../evil.png`), and verifies `MinioAssetStore` returns `s3://<bucket>/<key>` via mock `S3PutObject`.
- [ ] **Step 2:** Run `cargo test --test assets_test` — verify FAIL.
- [ ] **Step 3:** Implement `crates/sop-ingestion/src/assets.rs`.
- [ ] **Step 4:** Run `cargo test --test assets_test` & `cargo clippy --workspace --all-targets -- -D warnings` — verify PASS.

### Task 3: Private-Allowlist Vision Captioning (`Noop` + `OpenAiCompatibleVisionCaptioner`)
**Files:**
- Create: `crates/sop-ingestion/src/vision.rs`
- Test: `crates/sop-ingestion/tests/vision_test.rs`

- [ ] **Step 1:** Write failing tests in `vision_test.rs` (using `wiremock`): `NoopVisionCaptioner` returns `CaptionStatus::Noop`; `OpenAiCompatibleVisionCaptioner` allows `127.0.0.1`/`localhost`/RFC1918/`VISION_ALLOWED_HOSTS`, rejects ANY public host (`openrouter.ai`, `api.groq.com`, `8.8.8.8`) with `VisionHostBlocked`, enforces `redirect::Policy::none()`, retries once on transient HTTP 500/timeout, and degrades safely to `CaptionStatus::Failed` with fallback caption.
- [ ] **Step 2:** Run `cargo test --test vision_test` — verify FAIL.
- [ ] **Step 3:** Implement `crates/sop-ingestion/src/vision.rs`.
- [ ] **Step 4:** Run `cargo test --test vision_test` & `cargo clippy --workspace --all-targets -- -D warnings` — verify PASS.

### Checkpoint 1 (After Tasks 1–3)
- [ ] `cargo fmt --all -- --check`, `cargo clippy --workspace --all-targets -- -D warnings`, and `cargo test --workspace` all PASS.

### Task 4: Multimodal Pure-Rust Document & Script Parser (`.docx/.pdf/.xlsx/.pptx/.md/.sh/.sql/.xml`)
**Files:**
- Create: `crates/sop-ingestion/src/parser/{mod,docx,pptx,xlsx,pdf,script}.rs`
- Test: `crates/sop-ingestion/tests/parser_test.rs`

- [ ] **Step 1:** Write failing tests in `parser_test.rs`: parses `.docx` preserving headings, `section_path`, tables, raw CLI `--` & XML `<Connector/>` (zero Markdown escaping), and ordered PNGs with exact `block_index`; parses `.pdf` (`lopdf`), `.xlsx` (`calamine`), `.pptx` (`zip`+`quick-xml`), `.sh` (cp1252 via `encoding_rs`), `.sql`, `.xml`, `.md`, uppercase `.DOCX`; returns structured errors for `FileNotFound`, `InvalidPath` (directory), `UnsupportedFormat`, `EmptyFile`, `CorruptFile`, `ResourceLimitExceeded`.
- [ ] **Step 2:** Run `cargo test --test parser_test` — verify FAIL.
- [ ] **Step 3:** Implement `crates/sop-ingestion/src/parser/*`.
- [ ] **Step 4:** Run `cargo test --test parser_test` & `cargo clippy --workspace --all-targets -- -D warnings` — verify PASS.

### Task 5: Command/Table-Safe & Position-Linked Chunker
**Files:**
- Create: `crates/sop-ingestion/src/chunker.rs`
- Test: `crates/sop-ingestion/tests/chunker_test.rs`

- [ ] **Step 1:** Write failing tests in `chunker_test.rs`: never splits CLI/XML/SQL/table blocks (`has_code_or_cli = true`), never lets `overlap_chars` slice into atomic blocks, keeps oversized atomic blocks intact up to `max_atomic_chars = 4800`, links `asset_ids` + `asset_captions` by `block_index` without cross-linking repeated `"Before Changes"` headings, stamps uniform `valid_from` & versioned `chunk_id` (`<doc_id>:v<ver>:<idx>`), and keeps `content_sha256` independent of `asset_captions`.
- [ ] **Step 2:** Run `cargo test --test chunker_test` — verify FAIL.
- [ ] **Step 3:** Implement `crates/sop-ingestion/src/chunker.rs`.
- [ ] **Step 4:** Run `cargo test --test chunker_test` & `cargo clippy --workspace --all-targets -- -D warnings` — verify PASS.

### Task 6: Ingestion Pipeline (`ingest_document`) & Dry-Run CLI
**Files:**
- Create: `crates/sop-ingestion/src/pipeline.rs`
- Create: `crates/sop-ingestion/src/main.rs`
- Test: `crates/sop-ingestion/tests/pipeline_test.rs`

- [ ] **Step 1:** Write failing integration tests in `pipeline_test.rs`: end-to-end `ingest_document()` on synthetic `.docx` & `knowledge/domain-pack/` emits `IngestResult` with stable `doc_id` across `v1` & `v2`, non-colliding `chunk_id` & asset paths, uniform `valid_from`, linked `asset_ids`/`asset_captions`, and CLI writes `ingest_result.json` cleanly.
- [ ] **Step 2:** Run `cargo test --test pipeline_test` — verify FAIL.
- [ ] **Step 3:** Implement `crates/sop-ingestion/src/pipeline.rs` and `crates/sop-ingestion/src/main.rs`.
- [ ] **Step 4:** Run full verification suite:
  - `cargo fmt --all -- --check`
  - `cargo clippy --workspace --all-targets -- -D warnings`
  - `cargo test --workspace`
  - `cargo llvm-cov --workspace --fail-under-lines 80`
  - `gitleaks detect --source . --redact --no-banner`
  - `powershell -ExecutionPolicy Bypass -File .\init.ps1`

### Checkpoint 2 (Module 1 Complete Gate)
- [ ] All Rust tests pass with ≥ 80% coverage, `cargo fmt` & `cargo clippy` zero errors, `zero_db_policy` PASS, `gitleaks` 0 leaks, `feature_list.json` & `progress.md` updated with observed evidence.
