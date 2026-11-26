# Multimodal SOP Ingestion (`sop-ingestion`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` (or `superpowers:subagent-driven-development`) + `test-driven-development` + `incremental-implementation` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the deterministic, multimodal `sop-ingestion` Python package that parses MO NCX SOP files (`.docx`, `.pdf`, `.xlsx`, `.pptx`, `.md`, `.sh`, `.sql`, `.xml`), extracts embedded screenshots to an `AssetStore` with optional local `VisionCaptioner`, and emits command-safe `SopChunk` records carrying temporal & segment metadata.

**Architecture:** Clean dependency-injected vertical modules (`models` → `assets` & `vision` → `parser` → `chunker` → `pipeline` & `cli`). External I/O (MinIO, local Vision-LLM) sits behind `typing.Protocol` interfaces so all unit and integration tests run offline with synthetic fixtures and zero GPU dependency.

**Tech Stack:** Python 3.12+, Pydantic v2 (`>=2.10`), Docling (`>=2.81`, `PdfBackendOptions(do_char_normalization=False)`), `python-docx` (synthetic `.docx` test fixtures), `httpx` (local OpenAI-compatible Vision client), `minio` (optional S3/MinIO store), `pytest`, `pytest-cov`, `ruff`, `mypy`.

**Spec:** [spec/SPEC-sop-ingestion.md](../spec/SPEC-sop-ingestion.md)

## Global Constraints
- Read [CONSTRAINTS.md](../CONSTRAINTS.md) before writing code; never weaken thresholds or use `# noqa` / `# type: ignore`.
- `ruff check src tests` = 0 errors; `mypy src` = 0 errors; `pytest tests/sop_ingestion --cov=src/sop_ingestion --cov-fail-under=80` = PASS.
- Zero external cloud LLM calls; `enable_remote_services=False` on Docling pipelines.
- Zero real customer/server credentials or passwords in code, logs, or test fixtures.
- Preserve exact CLI characters (`--`, quotes, paths `/opt/...`, XML tags) — never split a CLI/XML block across two chunks.

## Review Focus (5 Edge Cases / Failure Modes Pinned by Tests)
1. **Corrupted or zero-byte `.docx`/`.pdf` upload:** Must raise `SopIngestionError(code="CORRUPT_FILE")` cleanly instead of crashing with an unhandled `BadZipFile` / `RuntimeError`.
2. **Unsupported file extension (e.g. `.exe`, `.zip`) or path traversal filename (`../../etc/passwd`):** Must reject with `SopIngestionError(code="UNSUPPORTED_FORMAT")` and sanitize asset storage keys so no path escapes the asset root.
3. **CLI flag & XML corruption (`--` normalized to em-dash, or `<Connector .../>` split mid-tag):** Must preserve verbatim ASCII CLI/XML characters inside a single `SopChunk` with `has_code_or_cli=True`.
4. **DOCX containing 20+ embedded `before/after` screenshots with short captions:** Must extract every image in deterministic reading order, caption via `VisionCaptioner`, store via `AssetStore`, and link `asset_ids` onto the owning section chunk.
5. **Vision-LLM endpoint timeout/unavailable when `VISION_MODE=local_vlm`:** Must degrade gracefully or raise a structured `SopIngestionError(code="VISION_FAILED")` with clear context rather than silently dropping assets or hanging indefinitely.

---

## Dependency Graph

```text
pyproject.toml + models.py (SopSegment, ExtractedAsset, SopChunk, IngestResult, SopIngestionError)
    ├── assets.py (AssetStore Protocol, LocalFsAssetStore, MinioAssetStore)
    ├── vision.py (VisionCaptioner Protocol, NoopVisionCaptioner, OpenAICompatibleVisionCaptioner)
    │       └── parser.py (DoclingDocumentParser + ScriptDocumentParser + DOCX image extraction)
    └── chunker.py (CommandSafeChunker — preserves CLI/XML/tables + links asset_ids)
                └── pipeline.py (SopIngestionPipeline.ingest_document)
                        └── cli.py (`py -m sop_ingestion.cli ingest ...`)
```

---

## Task Breakdown (TDD Vertical Slices)

### Task 1: Project Packaging, Core Models & Synthetic Fixture Harness
**Files:**
- Create: `pyproject.toml`
- Create: `src/sop_ingestion/__init__.py`
- Create: `src/sop_ingestion/models.py`
- Create: `tests/sop_ingestion/conftest.py`
- Test: `tests/sop_ingestion/test_models.py`

**Interfaces:**
- Consumes: none
- Produces: `SopSegment`, `ExtractedAsset`, `SopChunk`, `ParsedBlock`, `ParsedDocument`, `IngestResult`, `SopIngestionError`

- [ ] **Step 1:** Create `pyproject.toml` (Python `>=3.12`, `pydantic`, `docling`, `httpx`, dev extras `pytest`, `pytest-cov`, `ruff`, `mypy`, `python-docx`, `Pillow`) and install editable venv (`.venv`).
- [ ] **Step 2:** Write failing tests in `tests/sop_ingestion/test_models.py` pinning `SopSegment` enum values (`EBIS`, `RETAIL`, `WIBS`, `GENERAL`), `doc_version >= 1`, default `is_active=True`, `role_acl=["mo-ncx"]`, deterministic `content_sha256`, and `SopIngestionError(code, message)`.
- [ ] **Step 3:** Run `pytest tests/sop_ingestion/test_models.py -v` and verify FAIL (`ModuleNotFoundError`).
- [ ] **Step 4:** Implement `src/sop_ingestion/models.py` and `tests/sop_ingestion/conftest.py` (synthetic `.docx` with headings, table, CLI command `--importcert`, XML `<Connector/>`, and 2 embedded PNGs; synthetic `.sh`; corrupted file).
- [ ] **Step 5:** Run `pytest tests/sop_ingestion/test_models.py -v`, `ruff check src tests`, `mypy src` — verify PASS.

### Task 2: Asset Storage (`LocalFsAssetStore` + `MinioAssetStore` Protocol)
**Files:**
- Create: `src/sop_ingestion/assets.py`
- Test: `tests/sop_ingestion/test_assets.py`

**Interfaces:**
- Consumes: `SopIngestionError` from `models.py`
- Produces: `AssetStore` (`Protocol` with `save(doc_id: str, filename: str, data: bytes, mime_type: str) -> str`), `LocalFsAssetStore`, `MinioAssetStore`

- [ ] **Step 1:** Write failing tests in `tests/sop_ingestion/test_assets.py`: saving PNG bytes creates file under `<root>/<doc_id>/...`, returns valid URI, sanitizes path-traversal filenames (`../../evil.png`), and `MinioAssetStore` delegates to injected S3/MinIO client cleanly.
- [ ] **Step 2:** Run `pytest tests/sop_ingestion/test_assets.py -v` — verify FAIL.
- [ ] **Step 3:** Implement `src/sop_ingestion/assets.py`.
- [ ] **Step 4:** Run `pytest tests/sop_ingestion/test_assets.py -v`, `ruff check src tests`, `mypy src` — verify PASS.

### Task 3: Vision Captioning (`NoopVisionCaptioner` + `OpenAICompatibleVisionCaptioner`)
**Files:**
- Create: `src/sop_ingestion/vision.py`
- Test: `tests/sop_ingestion/test_vision.py`

**Interfaces:**
- Consumes: `SopIngestionError` from `models.py`
- Produces: `VisionCaptioner` (`Protocol` with `caption(image_bytes: bytes, mime_type: str, context_hint: str) -> str`), `NoopVisionCaptioner`, `OpenAICompatibleVisionCaptioner`, `build_vision_captioner(mode: str, ...)`

- [ ] **Step 1:** Write failing tests in `tests/sop_ingestion/test_vision.py`: `NoopVisionCaptioner` returns deterministic placeholder caption; `OpenAICompatibleVisionCaptioner` sends base64 data-URI to configured local endpoint via mocked `httpx.Client` and raises `SopIngestionError(code="VISION_FAILED")` on timeout/HTTP 500; rejects non-local cloud URLs (`api.openai.com`, `generativelanguage.googleapis.com`, `api.anthropic.com`).
- [ ] **Step 2:** Run `pytest tests/sop_ingestion/test_vision.py -v` — verify FAIL.
- [ ] **Step 3:** Implement `src/sop_ingestion/vision.py`.
- [ ] **Step 4:** Run `pytest tests/sop_ingestion/test_vision.py -v`, `ruff check src tests`, `mypy src` — verify PASS.

### Checkpoint 1 (After Tasks 1–3)
- [ ] `ruff check src tests`, `mypy src`, and `pytest tests/sop_ingestion` all PASS.

### Task 4: Multimodal Document & Script Parser (`Docling` + Embedded Screenshot Extraction)
**Files:**
- Create: `src/sop_ingestion/parser.py`
- Test: `tests/sop_ingestion/test_parser.py`

**Interfaces:**
- Consumes: `ParsedBlock`, `ParsedDocument`, `SopIngestionError` from `models.py`
- Produces: `SopParser` (`Protocol`), `DoclingSopParser` (configured with `PdfBackendOptions(do_char_normalization=False)` & `enable_remote_services=False`, plus ordered embedded image extraction from `.docx`/Docling pictures), `ScriptSopParser` (`.md`, `.sh`, `.sql`, `.xml`), `parse_sop_file(path: Path) -> ParsedDocument`

- [ ] **Step 1:** Write failing tests in `tests/sop_ingestion/test_parser.py`: parses synthetic `.docx` preserving headings, table Markdown, exact CLI `--` & XML `<Connector/>`, and extracting both embedded PNGs with section headings; parses `.sh` script; raises `SopIngestionError(code="UNSUPPORTED_FORMAT")` for `.exe` and `SopIngestionError(code="CORRUPT_FILE")` for zero-byte/broken `.docx`.
- [ ] **Step 2:** Run `pytest tests/sop_ingestion/test_parser.py -v` — verify FAIL.
- [ ] **Step 3:** Implement `src/sop_ingestion/parser.py`.
- [ ] **Step 4:** Run `pytest tests/sop_ingestion/test_parser.py -v`, `ruff check src tests`, `mypy src` — verify PASS.

### Task 5: Command-Safe & Structure-Aware Chunker
**Files:**
- Create: `src/sop_ingestion/chunker.py`
- Test: `tests/sop_ingestion/test_chunker.py`

**Interfaces:**
- Consumes: `ParsedDocument`, `ExtractedAsset`, `SopChunk`, `SopSegment` from `models.py`
- Produces: `CommandSafeChunker(max_chars: int = 1200, overlap_chars: int = 150)` with `chunk(doc: ParsedDocument, assets: list[ExtractedAsset], *, doc_id: str, segment: SopSegment, doc_version: int, role_acl: list[str] | None = None) -> list[SopChunk]`

- [ ] **Step 1:** Write failing tests in `tests/sop_ingestion/test_chunker.py`: never splits a multi-line CLI/XML block across two chunks (`has_code_or_cli=True`); preserves exact `--` flags; attaches `asset_ids` + captions to the matching section chunk; stamps temporal metadata (`doc_version`, `valid_from`, `valid_until=None`, `is_active=True`, `segment`, `content_sha256`).
- [ ] **Step 2:** Run `pytest tests/sop_ingestion/test_chunker.py -v` — verify FAIL.
- [ ] **Step 3:** Implement `src/sop_ingestion/chunker.py`.
- [ ] **Step 4:** Run `pytest tests/sop_ingestion/test_chunker.py -v`, `ruff check src tests`, `mypy src` — verify PASS.

### Task 6: Ingestion Pipeline Orchestrator & Dry-Run CLI
**Files:**
- Create: `src/sop_ingestion/pipeline.py`
- Create: `src/sop_ingestion/cli.py`
- Test: `tests/sop_ingestion/test_pipeline.py`

**Interfaces:**
- Consumes: `models.py`, `assets.py`, `vision.py`, `parser.py`, `chunker.py`
- Produces: `SopIngestionPipeline.ingest_file(path: Path, segment: SopSegment, doc_version: int = 1, doc_id: str | None = None) -> IngestResult`, CLI `py -m sop_ingestion.cli ingest --file ... --segment ... --version ... --output-dir ...`

- [ ] **Step 1:** Write failing integration tests in `tests/sop_ingestion/test_pipeline.py`: end-to-end ingestion of synthetic `.docx` (2 screenshots + CLI + XML + table) via `LocalFsAssetStore` + `NoopVisionCaptioner` produces valid `IngestResult` with persisted images, linked `asset_ids`, deterministic `doc_id`/`content_sha256`, and CLI writes `ingest_result.json` cleanly.
- [ ] **Step 2:** Run `pytest tests/sop_ingestion/test_pipeline.py -v` — verify FAIL.
- [ ] **Step 3:** Implement `src/sop_ingestion/pipeline.py` and `src/sop_ingestion/cli.py`.
- [ ] **Step 4:** Run full verification suite:
  - `ruff check src tests`
  - `mypy src`
  - `pytest tests/sop_ingestion --cov=src/sop_ingestion --cov-fail-under=80`
  - `powershell -ExecutionPolicy Bypass -File .\init.ps1`

### Checkpoint 2 (Module 1 Complete Gate)
- [ ] All tests pass with ≥80% coverage, `ruff` & `mypy` zero errors, zero secrets, `feature_list.json` & `progress.md` updated with observed command output.
