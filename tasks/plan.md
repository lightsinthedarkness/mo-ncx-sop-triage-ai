# Multimodal SOP Ingestion (`sop-ingestion`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` (or `superpowers:subagent-driven-development`) + `test-driven-development` + `incremental-implementation` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the deterministic, multimodal `sop-ingestion` Python package that parses MO NCX SOP files (`.docx`, `.pdf`, `.xlsx`, `.pptx`, `.md`, `.sh`, `.sql`, `.xml`, `.py`), extracts embedded screenshots to a versioned `AssetStore` with private-allowlist `VisionCaptioner`, and emits command/table-safe `SopChunk` records carrying stable `doc_id` and temporal metadata.

**Architecture:** Clean dependency-injected vertical modules (`models` → `assets` & `vision` → `parser` → `chunker` → `pipeline` & `cli`). External I/O (`S3ClientProtocol`, local Vision-LLM) sits behind `typing.Protocol` interfaces so `mypy` stays 100% clean without optional deps and all tests run offline with synthetic fixtures.

**Tech Stack:** Python 3.12+, Pydantic v2 (`>=2.10`), Docling (`>=2.81`, `PdfPipelineOptions(generate_picture_images=True, do_table_structure=True, enable_remote_services=False)`, `PdfBackendOptions(do_char_normalization=False)`), `httpx` (`follow_redirects=False`), `python-docx`, `openpyxl`, `python-pptx`, `pypdf`/`reportlab` (or minimal synthetic PDF fixture), `Pillow`, `pytest`, `pytest-cov`, `ruff`, `mypy`.

**Spec:** [spec/SPEC-sop-ingestion.md](../spec/SPEC-sop-ingestion.md) (Hardened after `doubt-driven-development` — 14/14 findings reconciled)

## Global Constraints
- Read [CONSTRAINTS.md](../CONSTRAINTS.md) before writing code; never weaken thresholds or use `# noqa` / `# type: ignore`.
- `ruff check src tests` = 0 errors; `mypy src` = 0 errors; `pytest tests/sop_ingestion --cov=src/sop_ingestion --cov-fail-under=80` = PASS; Secrets Scan = 0 findings.
- Zero external cloud LLM calls: `OpenAICompatibleVisionCaptioner` enforces strict private-host allowlist + `follow_redirects=False`; Docling enforces `enable_remote_services=False`.
- Never log or embed raw SOP text/credentials in exception messages or test fixtures.
- Preserve exact CLI/XML/table blocks — never slice into code/table blocks with `overlap_chars`.

## Review Focus (Edge Cases Pinned by Tests)
1. **Corrupt, empty, missing, directory, or non-UTF-8 inputs (`.DOCX` uppercase, 0-byte, cp1252 `.sh`):** Must raise structured `SopIngestionError` (`FILE_NOT_FOUND`, `INVALID_PATH`, `UNSUPPORTED_FORMAT`, `EMPTY_FILE`, `CORRUPT_FILE`) or decode gracefully (`utf-8-sig` → `cp1252`).
2. **Path traversal on BOTH `doc_id` and `filename`, plus `v1`/`v2` asset overwrite collision:** Must enforce `resolved.is_relative_to(root.resolve())` and store under `<doc_id>/v<doc_version>/<asset_id>.<ext>`.
3. **Cloud exfiltration bypass (non-OpenAI public hosts, public IPs, HTTP 30x redirects):** Must enforce strict private-host allowlist (loopback/RFC1918/`VISION_ALLOWED_HOSTS`) + `follow_redirects=False` and raise `VISION_HOST_BLOCKED`.
4. **Repeated SOP subheadings (`"Before Changes"`, `"After Changes"`) & Vision partial failure:** Must link assets by `block_index` + `section_path` (not heading string alone) and fall back non-destructively (`caption_status="failed"`) after 1 retry without leaving orphaned assets; enforce `max_images_per_doc=100` & `max_image_bytes=10MB`.
5. **CLI/XML Markdown escaping & overlap slicing:** Must preserve verbatim `--`, `_`, `<Connector/>`, and tables intact in one `SopChunk`, forbid `overlap_chars` from slicing into CLI/XML/table blocks, and keep oversized atomic blocks intact up to `max_atomic_chars=4800`.

---

## Dependency Graph

```text
pyproject.toml + models.py (SopSegment, SopMetadata, SopIngestionErrorCode, SopIngestionError,
                            ParsedBlock, ParsedImage, ParsedDocument, ExtractedAsset, SopChunk, IngestResult)
    ├── assets.py (AssetStore, S3ClientProtocol, LocalFsAssetStore, MinioAssetStore)
    ├── vision.py (VisionCaptioner, NoopVisionCaptioner, OpenAICompatibleVisionCaptioner, build_vision_captioner)
    ├── parser.py (SopParser, DoclingSopParser, ScriptSopParser, parse_sop_file)
    └── chunker.py (CommandSafeChunker — CLI/XML/table-safe + positional asset linking)
                └── pipeline.py (SopIngestionPipeline.ingest_document)
                        └── cli.py (`py -m sop_ingestion.cli ingest ...`)
```

---

## Task Breakdown (TDD Vertical Slices)

### Task 1: Project Packaging, Complete Public Models & Synthetic Fixture Harness
**Files:**
- Create: `pyproject.toml`
- Create: `src/sop_ingestion/__init__.py`
- Create: `src/sop_ingestion/models.py`
- Create: `tests/sop_ingestion/conftest.py`
- Test: `tests/sop_ingestion/test_models.py`

**Interfaces:**
- Consumes: none
- Produces: `SopSegment`, `SopMetadata`, `SopIngestionErrorCode`, `SopIngestionError`, `ParsedBlock`, `ParsedImage`, `ParsedDocument`, `ExtractedAsset`, `SopChunk`, `IngestResult`, `make_doc_id(segment: SopSegment, filename: str) -> str`, `sha256_bytes(data: bytes) -> str`, `sha256_text(text: str) -> str`

- [ ] **Step 1:** Create `pyproject.toml` (Python `>=3.12`, `pydantic`, `docling`, `httpx`; dev extras `pytest`, `pytest-cov`, `ruff`, `mypy`, `python-docx`, `openpyxl`, `python-pptx`, `Pillow`) and install editable `.venv`.
- [ ] **Step 2:** Write failing tests in `tests/sop_ingestion/test_models.py` pinning all public contracts, `make_doc_id()` stability across `v1`/`v2`, `SopSegment.GENERAL`, `SopIngestionErrorCode` enum, and non-leaking error formatting.
- [ ] **Step 3:** Run `pytest tests/sop_ingestion/test_models.py -v` — verify FAIL.
- [ ] **Step 4:** Implement `src/sop_ingestion/models.py` and `tests/sop_ingestion/conftest.py` (synthetic `.docx` with repeated `"Before Changes"` headings + table + CLI `--importcert` + XML `<Connector/>` + 2 PNGs, synthetic `.pdf`, `.xlsx`, `.pptx`, `.sh` cp1252, `.py`, `.md`, 0-byte, and corrupt files — zero real credentials).
- [ ] **Step 5:** Run `pytest tests/sop_ingestion/test_models.py -v`, `ruff check src tests`, `mypy src` — verify PASS.

### Task 2: Versioned Asset Storage (`LocalFsAssetStore` + `MinioAssetStore` via `S3ClientProtocol`)
**Files:**
- Create: `src/sop_ingestion/assets.py`
- Test: `tests/sop_ingestion/test_assets.py`

**Interfaces:**
- Consumes: `SopIngestionError`, `SopIngestionErrorCode` from `models.py`
- Produces: `AssetStore` (`Protocol` with `save(doc_id: str, doc_version: int, asset_id: str, filename: str, data: bytes, mime_type: str) -> str`), `S3ClientProtocol`, `LocalFsAssetStore`, `MinioAssetStore`

- [ ] **Step 1:** Write failing tests in `tests/sop_ingestion/test_assets.py`: persists bytes to `<root>/<doc_id>/v<doc_version>/<asset_id>.<ext>`, returns canonical `local://...` URI, prevents `v2` overwriting `v1`, blocks path traversal in BOTH `doc_id` (`../../etc`) and `filename` (`../evil.png`), and verifies `MinioAssetStore` returns `s3://<bucket>/<key>` via fake `S3ClientProtocol`.
- [ ] **Step 2:** Run `pytest tests/sop_ingestion/test_assets.py -v` — verify FAIL.
- [ ] **Step 3:** Implement `src/sop_ingestion/assets.py`.
- [ ] **Step 4:** Run `pytest tests/sop_ingestion/test_assets.py -v`, `ruff check src tests`, `mypy src` — verify PASS.

### Task 3: Private-Allowlist Vision Captioning (`Noop` + `OpenAICompatibleVisionCaptioner`)
**Files:**
- Create: `src/sop_ingestion/vision.py`
- Test: `tests/sop_ingestion/test_vision.py`

**Interfaces:**
- Consumes: `SopIngestionError`, `SopIngestionErrorCode` from `models.py`
- Produces: `CaptionResult(caption: str, status: Literal["ok", "noop", "failed"])`, `VisionCaptioner` (`Protocol`), `NoopVisionCaptioner`, `OpenAICompatibleVisionCaptioner`, `build_vision_captioner(mode: str, ...)`

- [ ] **Step 1:** Write failing tests in `tests/sop_ingestion/test_vision.py`: `NoopVisionCaptioner` returns `status="noop"`; `OpenAICompatibleVisionCaptioner` allows `127.0.0.1`/`localhost`/RFC1918/`VISION_ALLOWED_HOSTS`, rejects ANY other public host (`openrouter.ai`, `api.groq.com`, `8.8.8.8`) with `VISION_HOST_BLOCKED`, sets `follow_redirects=False`, retries once on transient HTTP 500/timeout, and degrades safely to `status="failed"` with fallback caption on exhausted failure.
- [ ] **Step 2:** Run `pytest tests/sop_ingestion/test_vision.py -v` — verify FAIL.
- [ ] **Step 3:** Implement `src/sop_ingestion/vision.py`.
- [ ] **Step 4:** Run `pytest tests/sop_ingestion/test_vision.py -v`, `ruff check src tests`, `mypy src` — verify PASS.

### Checkpoint 1 (After Tasks 1–3)
- [ ] `ruff check src tests`, `mypy src`, and `pytest tests/sop_ingestion` all PASS.

### Task 4: Multimodal Document & Script Parser (`.docx/.pdf/.xlsx/.pptx/.md/.sh/.sql/.xml/.py`)
**Files:**
- Create: `src/sop_ingestion/parser.py`
- Test: `tests/sop_ingestion/test_parser.py`

**Interfaces:**
- Consumes: `ParsedBlock`, `ParsedImage`, `ParsedDocument`, `SopIngestionError`, `SopIngestionErrorCode` from `models.py`
- Produces: `SopParser` (`Protocol`), `DoclingSopParser`, `ScriptSopParser`, `parse_sop_file(path: Path, *, max_images: int = 100, max_image_bytes: int = 10_485_760) -> ParsedDocument`

- [ ] **Step 1:** Write failing tests in `tests/sop_ingestion/test_parser.py`: parses `.docx` preserving headings, `section_path`, tables, raw CLI `--` & XML `<Connector/>` (no Markdown escaping `\_`/`\<`), and ordered PNGs with exact `block_index`; parses `.pdf`, `.xlsx`, `.pptx`, `.sh` (cp1252), `.py` (via `ast`), `.md`, uppercase `.DOCX`; raises structured errors for `FILE_NOT_FOUND`, `INVALID_PATH` (directory), `UNSUPPORTED_FORMAT`, `EMPTY_FILE`, `CORRUPT_FILE`, `RESOURCE_LIMIT_EXCEEDED`.
- [ ] **Step 2:** Run `pytest tests/sop_ingestion/test_parser.py -v` — verify FAIL.
- [ ] **Step 3:** Implement `src/sop_ingestion/parser.py` (with offline-safe Docling config `enable_remote_services=False`, `do_char_normalization=False`, `generate_picture_images=True`, plus direct `.docx` XML/media reading for exact CLI/image order).
- [ ] **Step 4:** Run `pytest tests/sop_ingestion/test_parser.py -v`, `ruff check src tests`, `mypy src` — verify PASS.

### Task 5: Command/Table-Safe & Position-Linked Chunker
**Files:**
- Create: `src/sop_ingestion/chunker.py`
- Test: `tests/sop_ingestion/test_chunker.py`

**Interfaces:**
- Consumes: `ParsedDocument`, `ExtractedAsset`, `SopChunk`, `SopMetadata` from `models.py`
- Produces: `CommandSafeChunker(max_chars: int = 1200, overlap_chars: int = 150, max_atomic_chars: int = 4800)` with `chunk(doc: ParsedDocument, assets: list[ExtractedAsset], metadata: SopMetadata) -> list[SopChunk]`

- [ ] **Step 1:** Write failing tests in `tests/sop_ingestion/test_chunker.py`: never splits CLI/XML/table blocks (`has_code_or_cli=True`), never lets `overlap_chars` slice into a CLI/XML/table block, keeps oversized atomic blocks intact up to `max_atomic_chars`, links `asset_ids` + `asset_captions` by `block_index` without cross-linking repeated `"Before Changes"` headings, stamps uniform `valid_from` & versioned `chunk_id` (`<doc_id>:v<ver>:<idx>`), and keeps `content_sha256` independent of `asset_captions`.
- [ ] **Step 2:** Run `pytest tests/sop_ingestion/test_chunker.py -v` — verify FAIL.
- [ ] **Step 3:** Implement `src/sop_ingestion/chunker.py`.
- [ ] **Step 4:** Run `pytest tests/sop_ingestion/test_chunker.py -v`, `ruff check src tests`, `mypy src` — verify PASS.

### Task 6: Ingestion Pipeline (`ingest_document`) & Dry-Run CLI
**Files:**
- Create: `src/sop_ingestion/pipeline.py`
- Create: `src/sop_ingestion/cli.py`
- Test: `tests/sop_ingestion/test_pipeline.py`

**Interfaces:**
- Consumes: `models.py`, `assets.py`, `vision.py`, `parser.py`, `chunker.py`
- Produces: `SopIngestionPipeline.ingest_document(path: Path, segment: SopSegment, doc_version: int = 1, doc_id: str | None = None, role_acl: list[str] | None = None) -> IngestResult`, CLI `py -m sop_ingestion.cli ingest --file ... --segment ... --version ... --output-dir ...`

- [ ] **Step 1:** Write failing integration tests in `tests/sop_ingestion/test_pipeline.py`: end-to-end `ingest_document()` on synthetic `.docx` produces `IngestResult` with stable `doc_id` across `v1` & `v2`, non-colliding `chunk_id` & asset paths, uniform `valid_from`, linked `asset_ids`/`asset_captions`, and CLI writes `ingest_result.json` cleanly.
- [ ] **Step 2:** Run `pytest tests/sop_ingestion/test_pipeline.py -v` — verify FAIL.
- [ ] **Step 3:** Implement `src/sop_ingestion/pipeline.py` and `src/sop_ingestion/cli.py`.
- [ ] **Step 4:** Run full verification suite:
  - `ruff check src tests`
  - `mypy src`
  - `pytest tests/sop_ingestion --cov=src/sop_ingestion --cov-fail-under=80`
  - Secrets scan (`gitleaks dir . --redact --no-banner` or regex fallback if `gitleaks` not installed)
  - `powershell -ExecutionPolicy Bypass -File .\init.ps1`

### Checkpoint 2 (Module 1 Complete Gate)
- [ ] All tests pass with ≥80% coverage, `ruff` & `mypy` zero errors, Secrets Scan zero findings, `feature_list.json` & `progress.md` updated with observed evidence.
