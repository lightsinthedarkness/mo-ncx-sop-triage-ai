# Multimodal SOP Ingestion (`crates/sop-core` + `crates/sop-ingestion`) Implementation Plan — 100% Pure Rust

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` (or `superpowers:subagent-driven-development`) + `test-driven-development` + `incremental-implementation` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the deterministic, hardened, multimodal `crates/sop-core` + `crates/sop-ingestion` **Rust 2021** workspace crates that parse MO NCX SOP files (`.docx`, `.pdf`, `.xlsx`, `.pptx`, `.md`, `.yaml`, `.yml`, `.sh`, `.sql`, `.xml`) & `knowledge/domain-pack/`, scrub plaintext credentials, extract embedded screenshots safely into an async Windows-safe versioned `AssetStore` with DNS-pinned private-allowlist `VisionCaptioner`, and emit command/table-safe `SopChunk` records.

**Architecture:** Clean trait-injected vertical modules (`sop-core` + `sop-test-support` → `scrubber` + `assets` + `vision` → `parser/*` → `chunker` → `pipeline` & `main.rs` CLI). All external I/O (`AssetStore`, `S3PutObject`, `VisionCaptioner`) uses `#[async_trait]` and injected config structs (zero `std::env::set_var` in tests) so every test runs 100% offline with zero races and zero `dead_code` clippy warnings.

**Tech Stack (Rust 2021 — Verified Crates per `ADR-003`):** `serde` + `serde_json`, `chrono`, `sha2`, `thiserror`, `schemars`, `zip` (`zip-rs/zip2`), `quick-xml` (`tafia/quick-xml`), `calamine` (`tafia/calamine`), `oxidize-pdf` *(or `pdf-extract`)* + `lopdf` (`J-F-Liu/lopdf`) + `image` (`image-rs/image`), `encoding_rs`, `reqwest` (`.no_proxy()` + `redirect::Policy::none()` + `.resolve()`), `tokio` (`fs`, `rt-multi-thread`, `macros`), `async-trait`, `regex`, `clap`; dev-deps: `sop-test-support`, `tempfile`, `wiremock`.

**Spec:** [spec/SPEC-sop-ingestion.md](../spec/SPEC-sop-ingestion.md) (Hardened — all 19/19 Pure-Rust adversarial findings reconciled)

## Global Constraints
- Read [CONSTRAINTS.md](../CONSTRAINTS.md) before writing code; never weaken thresholds, add `#[allow(warnings)]`, use `unsafe`, mutate env vars in tests, or call `.unwrap()` on external inputs.
- `cargo fmt --all -- --check` = 0 diffs; `cargo clippy --workspace --all-targets -- -D warnings` = 0 warnings; `cargo test --workspace` = PASS; `cargo llvm-cov --workspace --fail-under-lines 80` = PASS; `gitleaks` = 0 findings.
- **Zero Direct DB (`ADR-002`):** `zero_db_policy` scans all workspace `Cargo.toml`/`Cargo.lock` for forbidden Oracle/SSH crates (`oracle`, `sibyl`, `oci`, `odpi`, `russh`, `ssh2`, `openssh`, `async-ssh2-tokio`) and scans source for `Command::new("sqlplus" | "ssh")`.
- **Zero Plaintext Credential Leaks:** `secret_scrubber` runs on every `SopChunk.content` and `ExtractedAsset.caption` before persistence or CLI JSON export.

## Review Focus (All 19 Adversarial Edge Cases Pinned by Tests)
1. **Windows-safe filenames & traversal defense:** Logical `asset_id` (`doc:v1:img0`) separated from physical filename `img0.<ext>` (no `:` on Windows); reject `..`, `/`, `\`, `:`, drive prefixes, `CON`/`NUL`/`AUX`/`COM1`, trailing dots/spaces, symlinks BEFORE `create_dir_all`; atomic temp-file rename + rollback `delete_version_dir()`.
2. **Decompression bombs & RAM cap (`< 128 MB`):** Enforce `max_file_bytes=50MB`, `max_zip_entries=1000`, `max_uncompressed_entry_bytes=25MB`, `max_total_uncompressed_bytes=100MB`, `max_xlsx_cells=200k`, `max_images_per_doc=100`, `max_image_bytes=10MB`, `max_total_image_bytes=50MB` + incremental image streaming.
3. **SSRF / proxy / DNS rebinding:** `.no_proxy()`, `redirect::Policy::none()`, `http`/`https`-only, pre-resolve DNS + block public/IPv4-mapped IPv6/IMDS `169.254.0.0/16`/`fe80::/10`/`0.0.0.0` + `ClientBuilder::resolve()` pinning; retry `5xx`/network only; `max_tokens=300`; 3-failure circuit breaker.
4. **PDF, OOXML, XLSX, & Encoding reality:** PDF text (`oxidize-pdf`/`pdf-extract`) + `lopdf` XObjects re-encoded to PNG via `image` + 0-text scanned PDF support; `.docx` run concat + `<w:br/>`/`<w:tab/>` + DrawingML/VML + `styles.xml` `<w:outlineLvl>`; `.pptx` `<p:sldIdLst>` order + `../media/`; `.xlsx` `calamine` + `xl/media/*`; `encoding_rs` UTF-8/UTF-16 BOM + binary NUL reject before cp1252.
5. **UTF-8 char-safe chunking, `make_doc_id` non-collision, & single `valid_from`:** `doc_id` includes ext + 6-char hash (≤ 64 chars); `NonZeroU32` `doc_version`; `SourceType` (`Sop` | `DomainPack`); `role_acl = ["user_kantor", "admin_sop"]`; `schemars::JsonSchema` derived; single `valid_from` passed from pipeline to chunker; `oversized_atomic_split` on `\n` boundaries only.

---

## Prerequisite (Before Task 1)
- [ ] **Step 0:** Install Rust stable toolchain via `rustup` (`winget install Rustlang.Rustup`), then run:
  ```powershell
  rustup component add rustfmt clippy llvm-tools-preview
  cargo install cargo-llvm-cov
  powershell -ExecutionPolicy Bypass -File .\init.ps1
  ```

---

## Task Breakdown (TDD Vertical Slices — Rust 2021)

### Task 1: Cargo Workspace, `crates/sop-core` Contracts, `crates/sop-test-support`, & `zero_db_policy`
**Files:**
- Create: `Cargo.toml` (workspace root: `members = ["crates/sop-core", "crates/sop-test-support", "crates/sop-ingestion"]`, `edition = "2021"`)
- Create: `crates/sop-core/{Cargo.toml,src/lib.rs,src/models.rs,src/error.rs}`
- Create: `crates/sop-test-support/{Cargo.toml,src/lib.rs}`
- Create: `crates/sop-ingestion/{Cargo.toml,src/lib.rs,tests/models_test.rs}`

- [ ] **Step 1:** Scaffold Cargo workspace & crate manifests (zero Oracle/SSH dependencies).
- [ ] **Step 2:** Write failing tests in `models_test.rs` pinning serde round-trips (incl. `ParsedDocument` with `#[serde(skip)]` on `data`), `schemars::schema_for!(IngestResult)`, `NonZeroU32` `doc_version`, `SourceType::DomainPack`, `role_acl = ["user_kantor", "admin_sop"]`, `SCREAMING_SNAKE_CASE` error Display, `make_doc_id()` non-collision (`deploy.docx` vs `deploy.sh`) & ≤ 64 char cap, and `zero_db_policy` workspace scan.
- [ ] **Step 3:** Run `cargo test --test models_test` — verify FAIL.
- [ ] **Step 4:** Implement `crates/sop-core` and `crates/sop-test-support` (synthetic `.docx`, `.pdf` incl. scanned 0-text PDF, `.xlsx`, `.pptx`, `.yaml`, `.sh` cp1252 & UTF-16LE, binary file, `.md`, 0-byte, corrupt, and zip-bomb fixtures — zero real credentials).
- [ ] **Step 5:** Run `cargo test --test models_test && cargo fmt --all -- --check && cargo clippy --workspace --all-targets -- -D warnings` — verify PASS.

### Task 2: Secret Scrubber & Async Windows-Safe Versioned Asset Storage
**Files:**
- Create: `crates/sop-ingestion/src/{scrubber.rs,assets.rs}`
- Test: `crates/sop-ingestion/tests/{scrubber_test.rs,assets_test.rs}`

- [ ] **Step 1:** Write failing tests in `scrubber_test.rs` (redacting `-storepass`, `-keypass`, `password=`, `passwd=`, Bearer tokens, PEM private keys while preserving surrounding CLI flags) and `assets_test.rs` (async `LocalFsAssetStore` writing Windows-safe `img<idx>.<ext>`, blocking `..`, `:`, drive prefixes, `CON`/`NUL`, trailing dots, symlinks BEFORE `create_dir_all`, atomic temp-file rename, `v1` vs `v2` isolation, re-ingest cleanup, `delete_version_dir()` rollback, and async `MinioAssetStore` via mock `S3PutObject`).
- [ ] **Step 2:** Run `cargo test --test scrubber_test --test assets_test` — verify FAIL.
- [ ] **Step 3:** Implement `scrubber.rs` and `assets.rs`.
- [ ] **Step 4:** Run `cargo test --test scrubber_test --test assets_test && cargo clippy --workspace --all-targets -- -D warnings` — verify PASS.

### Task 3: Hardened Async Vision Captioning (`Noop` + `OpenAiCompatibleVisionCaptioner`)
**Files:**
- Create: `crates/sop-ingestion/src/vision.rs`
- Test: `crates/sop-ingestion/tests/vision_test.rs`

- [ ] **Step 1:** Write failing tests in `vision_test.rs` using injected `VisionConfig` + `wiremock` (zero `std::env::set_var`!): `NoopVisionCaptioner` → `CaptionStatus::Noop`; `OpenAiCompatibleVisionCaptioner` enforces `.no_proxy()`, `redirect::Policy::none()`, scheme `http`/`https`-only, DNS resolution & IP validation blocking public IPs, IPv4-mapped IPv6 `::ffff:8.8.8.8`, IMDS `169.254.169.254`, `0.0.0.0` with `VisionHostBlocked`; retries 1x ONLY on `5xx`/network (not `400`/`401`); enforces `max_tokens=300` & output length cap; treats empty 200 body as `Failed`; trips circuit breaker after 3 consecutive failures.
- [ ] **Step 2:** Run `cargo test --test vision_test` — verify FAIL.
- [ ] **Step 3:** Implement `crates/sop-ingestion/src/vision.rs`.
- [ ] **Step 4:** Run `cargo test --test vision_test && cargo clippy --workspace --all-targets -- -D warnings` — verify PASS.

### Checkpoint 1 (After Tasks 1–3)
- [ ] `cargo fmt --all -- --check`, `cargo clippy --workspace --all-targets -- -D warnings`, and `cargo test --workspace` all PASS.

### Task 4: Multimodal Pure-Rust Document, PDF, OOXML & Script Parser
**Files:**
- Create: `crates/sop-ingestion/src/parser/{mod,docx,pptx,xlsx,pdf,script}.rs`
- Test: `crates/sop-ingestion/tests/parser_test.rs`

- [ ] **Step 1:** Write failing tests in `parser_test.rs`: parses `.docx` (run concat, `<w:br/>`/`<w:tab/>`, `styles.xml` `<w:outlineLvl>`, DrawingML + VML images, rejects `TargetMode="External"`, tables, raw CLI `--` & XML `<Connector/>`), `.pptx` (`<p:sldIdLst>` slide order + `../media/`), `.xlsx` (`calamine` + `xl/media/*`), `.pdf` (born-digital text + XObject PNG re-encode + 0-text scanned PDF), `.yaml`/`.yml`, `.md`, `.sh` (UTF-8, UTF-16LE BOM, cp1252, rejects binary NUL file as `CorruptFile`), uppercase `.DOCX`; enforces all decompression-bomb & resource limits (`ResourceLimitExceeded`).
- [ ] **Step 2:** Run `cargo test --test parser_test` — verify FAIL.
- [ ] **Step 3:** Implement `crates/sop-ingestion/src/parser/*`.
- [ ] **Step 4:** Run `cargo test --test parser_test && cargo clippy --workspace --all-targets -- -D warnings` — verify PASS.

### Task 5: UTF-8 Safe Command/Table Chunker & Positional Asset Linker
**Files:**
- Create: `crates/sop-ingestion/src/chunker.rs`
- Test: `crates/sop-ingestion/tests/chunker_test.rs`

- [ ] **Step 1:** Write failing tests in `chunker_test.rs`: deterministic `CodeCli` classification on `.docx` paragraphs; never splits CLI/XML/SQL/table blocks with `overlap_chars`; UTF-8 char-boundary safe slicing on `→`/curly quotes; oversized atomic block (> 4800) splits cleanly on `\n` with `oversized_atomic_split = true`; links `asset_ids` + `asset_captions` by `block_index` without cross-linking repeated `"Before Changes"` headings; attaches leading/trailing/image-only assets with 0 orphans; receives single `valid_from` from caller; `content_sha256` independent of Vision mode.
- [ ] **Step 2:** Run `cargo test --test chunker_test` — verify FAIL.
- [ ] **Step 3:** Implement `crates/sop-ingestion/src/chunker.rs`.
- [ ] **Step 4:** Run `cargo test --test chunker_test && cargo clippy --workspace --all-targets -- -D warnings` — verify PASS.

### Task 6: Async Streaming Pipeline (`ingest_document`) & CLI (`clap`)
**Files:**
- Create: `crates/sop-ingestion/src/{pipeline.rs,main.rs}`
- Test: `crates/sop-ingestion/tests/pipeline_test.rs`

- [ ] **Step 1:** Write failing integration tests in `pipeline_test.rs`: end-to-end `ingest_document()` on synthetic `.docx` (with plaintext `-storepass` scrubbed from chunks/captions/JSON!), scanned PDF, and `knowledge/domain-pack/` `.yaml`/`.md` (`SourceType::DomainPack`); verifies stable `doc_id` across `v1`/`v2`, Windows-safe `img<idx>.<ext>`, uniform `valid_from`, mid-doc failure triggers `delete_version_dir()` rollback, and CLI writes scrubbed `ingest_result.json`.
- [ ] **Step 2:** Run `cargo test --test pipeline_test` — verify FAIL.
- [ ] **Step 3:** Implement `pipeline.rs` and `main.rs`.
- [ ] **Step 4:** Run full verification suite:
  - `cargo fmt --all -- --check`
  - `cargo clippy --workspace --all-targets -- -D warnings`
  - `cargo test --workspace`
  - `cargo llvm-cov --workspace --fail-under-lines 80`
  - `gitleaks detect --source . --redact --no-banner`
  - `powershell -ExecutionPolicy Bypass -File .\init.ps1`

### Checkpoint 2 (Module 1 Complete Gate)
- [ ] All Rust tests pass with ≥ 80% coverage, zero clippy/fmt warnings, `zero_db_policy` & `secret_scrubber` PASS, `gitleaks` 0 leaks, `feature_list.json` & `progress.md` updated with observed evidence.
