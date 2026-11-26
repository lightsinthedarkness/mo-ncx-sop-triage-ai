# Task Checklist — Module 1 (`sop-ingestion`)

Source spec: [spec/SPEC-sop-ingestion.md](../spec/SPEC-sop-ingestion.md)  
Source plan: [tasks/plan.md](plan.md)

## Phase 1: Foundation (Tasks 1–3)

- [ ] **Task 1: Project Packaging, Core Models & Synthetic Fixture Harness** *(Size: M — 4 files)*
  - Acceptance: `pyproject.toml` installed in `.venv`; `SopSegment`, `ExtractedAsset`, `SopChunk`, `ParsedDocument`, `IngestResult`, `SopIngestionError` validated with Pydantic v2; synthetic `.docx`/`.sh`/corrupt fixtures ready with zero real credentials.
  - Verify: `pytest tests/sop_ingestion/test_models.py -v && ruff check src tests && mypy src`
  - Dependencies: None

- [ ] **Task 2: Asset Storage (`LocalFsAssetStore` + `MinioAssetStore`)** *(Size: S — 2 files)*
  - Acceptance: `AssetStore` protocol implemented; `LocalFsAssetStore` persists bytes and blocks path traversal (`../`); `MinioAssetStore` uploads via injected client.
  - Verify: `pytest tests/sop_ingestion/test_assets.py -v && ruff check src tests && mypy src`
  - Dependencies: Task 1

- [ ] **Task 3: Vision Captioning (`NoopVisionCaptioner` + `OpenAICompatibleVisionCaptioner`)** *(Size: S — 2 files)*
  - Acceptance: `VISION_MODE=noop` returns deterministic caption; `local_vlm` calls local OpenAI-compatible endpoint, rejects public cloud LLM hosts, and raises `SopIngestionError(code="VISION_FAILED")` on errors.
  - Verify: `pytest tests/sop_ingestion/test_vision.py -v && ruff check src tests && mypy src`
  - Dependencies: Task 1

### Checkpoint 1 (After Tasks 1–3)
- [ ] All foundation unit tests pass, `ruff check` & `mypy` zero errors.

## Phase 2: Multimodal Parsing & Command-Safe Chunking (Tasks 4–5)

- [ ] **Task 4: Multimodal Document & Script Parser (`Docling` + Embedded Images)** *(Size: M — 2 files)*
  - Acceptance: `.docx` parsed preserving headings, tables, verbatim `--`/XML, and ordered embedded PNGs; `.sh`/`.md`/`.sql`/`.xml` parsed cleanly; unsupported/corrupt files raise structured `SopIngestionError`.
  - Verify: `pytest tests/sop_ingestion/test_parser.py -v && ruff check src tests && mypy src`
  - Dependencies: Task 1

- [ ] **Task 5: Command-Safe & Structure-Aware Chunker** *(Size: M — 2 files)*
  - Acceptance: Multi-line CLI & XML blocks never split mid-block (`has_code_or_cli=True`); `asset_ids` linked to owning section chunks; temporal metadata (`doc_version`, `valid_from`, `valid_until`, `is_active`, `segment`, `role_acl`, `content_sha256`) stamped on every chunk.
  - Verify: `pytest tests/sop_ingestion/test_chunker.py -v && ruff check src tests && mypy src`
  - Dependencies: Task 1, Task 4

## Phase 3: Pipeline Orchestrator, CLI & Final Gate (Task 6)

- [ ] **Task 6: Ingestion Pipeline Orchestrator & Dry-Run CLI** *(Size: M — 3 files)*
  - Acceptance: End-to-end `ingest_file()` produces complete `IngestResult` with persisted assets & chunks; CLI `py -m sop_ingestion.cli ingest` outputs `ingest_result.json` cleanly.
  - Verify: `ruff check src tests && mypy src && pytest tests/sop_ingestion --cov=src/sop_ingestion --cov-fail-under=80 && powershell -ExecutionPolicy Bypass -File .\init.ps1`
  - Dependencies: Tasks 1–5

### Checkpoint 2 (Module 1 Complete Gate)
- [ ] All tests pass with ≥80% coverage, zero lint/type errors, zero secrets, `feature_list.json` & `progress.md` updated with observed evidence.
