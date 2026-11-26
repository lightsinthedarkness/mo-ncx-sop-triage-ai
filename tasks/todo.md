# Task Checklist — Module 1 (`sop-ingestion`)

Source spec: [spec/SPEC-sop-ingestion.md](../spec/SPEC-sop-ingestion.md)  
Source plan: [tasks/plan.md](plan.md)

## Phase 1: Foundation (Tasks 1–3)

- [ ] **Task 1: Project Packaging, Complete Public Models & Synthetic Fixture Harness** *(Size: M — 5 files)*
  - Acceptance: `pyproject.toml` installed in `.venv`; all public models (`SopSegment`, `SopMetadata`, `SopIngestionErrorCode`, `SopIngestionError`, `ParsedBlock`, `ParsedImage`, `ParsedDocument`, `ExtractedAsset`, `SopChunk`, `IngestResult`) + deterministic `make_doc_id()` validated; synthetic fixtures (`.docx`, `.pdf`, `.xlsx`, `.pptx`, `.sh` cp1252, `.py`, `.md`, 0-byte, corrupt) ready with zero real credentials.
  - Verify: `pytest tests/sop_ingestion/test_models.py -v && ruff check src tests && mypy src`
  - Dependencies: None

- [ ] **Task 2: Versioned Asset Storage (`LocalFsAssetStore` + `MinioAssetStore`)** *(Size: S — 2 files)*
  - Acceptance: `AssetStore` + `S3ClientProtocol` implemented; persists to `<doc_id>/v<doc_version>/<asset_id>.<ext>` with canonical `local://` / `s3://` URI; blocks path traversal on BOTH `doc_id` and `filename`; `v2` never overwrites `v1`.
  - Verify: `pytest tests/sop_ingestion/test_assets.py -v && ruff check src tests && mypy src`
  - Dependencies: Task 1

- [ ] **Task 3: Private-Allowlist Vision Captioning (`Noop` + `OpenAICompatibleVisionCaptioner`)** *(Size: S — 2 files)*
  - Acceptance: `VISION_MODE=noop` returns `status="noop"`; `local_vlm` enforces strict private-host allowlist + `follow_redirects=False`, retries once on transient error, and degrades non-destructively to `status="failed"` without orphaning assets.
  - Verify: `pytest tests/sop_ingestion/test_vision.py -v && ruff check src tests && mypy src`
  - Dependencies: Task 1

### Checkpoint 1 (After Tasks 1–3)
- [ ] All foundation unit tests pass, `ruff check` & `mypy` zero errors.

## Phase 2: Multimodal Parsing & Command/Table-Safe Chunking (Tasks 4–5)

- [ ] **Task 4: Multimodal Document & Script Parser (`.docx/.pdf/.xlsx/.pptx/.md/.sh/.sql/.xml/.py`)** *(Size: M — 2 files)*
  - Acceptance: Parses all 9 supported extensions (`.suffix.lower()`); preserves verbatim CLI/XML (no Markdown escaping) & tables; extracts ordered images with `block_index` + `section_path`; handles cp1252 fallback; enforces image count/size caps & structured errors (`FILE_NOT_FOUND`, `INVALID_PATH`, `UNSUPPORTED_FORMAT`, `EMPTY_FILE`, `CORRUPT_FILE`, `RESOURCE_LIMIT_EXCEEDED`).
  - Verify: `pytest tests/sop_ingestion/test_parser.py -v && ruff check src tests && mypy src`
  - Dependencies: Task 1

- [ ] **Task 5: Command/Table-Safe & Position-Linked Chunker** *(Size: M — 2 files)*
  - Acceptance: CLI, XML, and table blocks never split mid-block; `overlap_chars` never slices into CLI/XML/table blocks; oversized atomic blocks preserved up to `max_atomic_chars=4800`; `asset_ids` + `asset_captions` linked by `block_index` (immune to repeated `"Before Changes"` headings); uniform `valid_from` & versioned `chunk_id` stamped; `content_sha256` independent of Vision mode.
  - Verify: `pytest tests/sop_ingestion/test_chunker.py -v && ruff check src tests && mypy src`
  - Dependencies: Task 1, Task 4

## Phase 3: Pipeline Orchestrator, CLI & Final Gate (Task 6)

- [ ] **Task 6: Ingestion Pipeline (`ingest_document`) & Dry-Run CLI** *(Size: M — 3 files)*
  - Acceptance: End-to-end `SopIngestionPipeline.ingest_document()` emits valid `IngestResult` with stable `doc_id` across `v1`/`v2`, non-colliding assets/chunks, and redacted error messages; CLI writes `ingest_result.json` cleanly.
  - Verify: `ruff check src tests && mypy src && pytest tests/sop_ingestion --cov=src/sop_ingestion --cov-fail-under=80 && powershell -ExecutionPolicy Bypass -File .\init.ps1` + Secrets Scan
  - Dependencies: Tasks 1–5

### Checkpoint 2 (Module 1 Complete Gate)
- [ ] All tests pass with ≥80% coverage, zero lint/type errors, Secrets Scan zero findings, `feature_list.json` & `progress.md` updated with observed evidence.
