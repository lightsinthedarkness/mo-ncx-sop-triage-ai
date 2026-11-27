# Session Handoff — `ykztir-ncx-ai`

- **Last Updated:** `2026-11-27T15:15:00+07:00`
- **Current Objective:** Complete 100% of pre-coding gates (Design 2.3 + PRD 2.3 + ADR-001 Hybrid Python/Rust/Jev, Constraints with `E1` Jev Redaction + Rust gates, Harness 100/100, Archify Diagrams both Architecture & Lifecycle synced, 24 Skills, Module 1 Spec & Plan) and hold cleanly at the Coding Gate until Owner initiates Phase 4 TDD.
- **Active Branch:** `feat/sop-ingestion` (synced with `main`)

## Architecture Lock (Design 2.3 — `docs/adr/ADR-001-hybrid-python-rust-and-jev-orchestrator.md`)
- **Module #1 (`sop-ingestion`):** Python 3.12 (`Docling` + local Vision-LLM + Command-Safe Chunker). Ready immediately (`Python 3.12.10` installed).
- **Module #2 (`sop-memory-rag`) & Module #3 (`triage-engine-api`):** Rust (`Axum` + `Rig` + `qdrant-client` + `sqlx`) + **Jev (`TypeSafe AI`, `TYPESAFE_API_KEY`)** as calibrated `Choice` router & `Score` judge under `CONSTRAINTS.md` Exception `E1` (redacted metadata/slot state or synthetic eval payloads ONLY — never raw SOP files, IPs, or credentials; local-LLM fallback required).
- **Module #4 (`opendesign-web-portal`):** Standalone OpenDesign Web Portal (completely separate from `https://ncxall.my.id/dashboard`; never touch `C:/Users/Administrator/web`).

## Files Ready for Next Session
- Intent & Architecture: `docs/intent/sop-triage-ai.md`, `docs/adr/ADR-001-hybrid-python-rust-and-jev-orchestrator.md`, `DESIGN.md`, `PRD.md`, `README.md`, `docs/diagrams/sop-triage-*.{svg,html}`
- Quality & Harness: `CONSTRAINTS.md`, `AGENTS.md`, `feature_list.json`, `progress.md`, `init.sh`, `init.ps1`, `session-handoff.md`
- Module 1 Spec & Plan: `spec/capability-map.md`, `spec/SPEC-sop-ingestion.md`, `tasks/plan.md`, `tasks/todo.md`

## Blockers
- Coding intentionally paused at Coding Gate per Owner instruction.
- Note for future Module #2: `rustup` (`rustc` / `cargo`) is not yet installed on this Windows machine (not needed for Module #1).

## Recommended Next Step (Next Session)
1. Run `powershell -ExecutionPolicy Bypass -File .\init.ps1` (or `./init.sh`).
2. Start **Phase 4 (`BUILD & VERIFY` — TDD)** on branch `feat/sop-ingestion`: execute Tasks 1–3 in `tasks/plan.md` (`pyproject.toml`, `models.py`, `assets.py`, `vision.py`) to Checkpoint 1 with strict RED → GREEN → REFACTOR discipline.
3. Before Module #2 (`sop-memory-rag`), install `rustup` and configure `TYPESAFE_API_KEY` via local `.env` (never committed).
