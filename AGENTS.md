# AGENTS.md — MO NCX SOP Triage & Autonomous AI (`LLM`)

Short operating map for AI coding agents working in `c:/Users/Administrator/LLM`.
Read `CONSTRAINTS.md` before writing code. Do not weaken it to make a change pass.

## Authoritative Docs
- Intent: [docs/intent/sop-triage-ai.md](docs/intent/sop-triage-ai.md)
- Architecture (Design 2.3): [DESIGN.md](DESIGN.md) & [ADR-001](docs/adr/ADR-001-hybrid-python-rust-and-jev-orchestrator.md)
- Product Requirements (PRD 2.2): [PRD.md](PRD.md)
- Quality Contract: [CONSTRAINTS.md](CONSTRAINTS.md)
- Module Map: [spec/capability-map.md](spec/capability-map.md)
- State & Progress: [feature_list.json](feature_list.json), [progress.md](progress.md)

## Startup Workflow (Every Session)
1. Read `progress.md` and `feature_list.json` to identify the **single** active feature/module.
2. Read `CONSTRAINTS.md` and the active module spec in `spec/SPEC-<module>.md`.
3. Run `powershell -ExecutionPolicy Bypass -File .\init.ps1` to verify baseline health.
4. Follow the gated skill pipeline strictly — never skip from Spec to Code without Plan & Tasks approval.

## Mandatory Skill Pipeline (`superpowers` + `addyosmani/agent-skills`)
- **Define:** `interview-me` → `brainstorming` → `doubt-driven-development`
- **Specify:** `spec-driven-development` + `api-and-interface-design` + `constraint-driven-development`
- **Plan:** `planning-and-task-breakdown` + `writing-plans` + `source-driven-development`
- **UI Design (Module 4):** **OpenDesign** standalone Web App (`opendesign-web-portal`, terpisah penuh dari `ncxall.my.id/dashboard`)
- **Build & Verify:** `incremental-implementation` + `test-driven-development` (RED → GREEN → REFACTOR) + `observability-and-instrumentation` + `verification-before-completion`
- **Review & Ship:** `code-review-and-quality` + `security-and-hardening` + `code-simplification` + `documentation-and-adrs`

## Project Domain Skills (`.agents/skills/` — 24 Installed)
- **Discovery:** `find-skills`
- **Visual Documentation:** `archify`, `archify-pr`
- **Module 1 (`sop-ingestion`):** `docling`
- **Module 2 (`sop-memory-rag`):** `qdrant-search-quality`, `rag-implementation`, `hybrid-search-implementation`, `langchain-rag`, `deep-agents-memory`
- **Module 3 (`triage-engine-api`):** `langgraph-fundamentals`, `langgraph-persistence`, `langgraph-human-in-the-loop`, `fastapi`, `vllm-deploy-docker`
- **Module 4 (`opendesign-web-portal`):** `frontend-design`, `web-design-guidelines`, `design-brief`, `workers-best-practices`
- **Observability, Testing & Eval:** `langfuse`, `python-testing-patterns`, `llm-evaluation`, `deepeval`, `agent-self-evaluation`, `promptfoo-evals`

## Verification Commands
```powershell
./init.sh
powershell -ExecutionPolicy Bypass -File .\init.ps1
ruff check src tests
mypy src
pytest --cov=src --cov-fail-under=80
cargo clippy --all-targets -- -D warnings   # Modules 2-3 (Rust)
cargo test --workspace                      # Modules 2-3 (Rust)
gitleaks detect --source . --redact --no-banner
```

## Scope Rules
- **One feature at a time:** Work strictly on one unfinished feature in `feature_list.json` following `spec/capability-map.md` build order.
- **Stay in scope:** Never mix unrelated refactors, skip Spec/Plan gates, or touch `C:/Users/Administrator/web`.
- **Never commit secrets or real customer/server credentials** (including passwords found inside sample SOP docs) into code, tests, docs, or git.
- **Never weaken `CONSTRAINTS.md`** or skip failing tests to reach green.
- **No production deploy without explicit Owner approval.**

## Definition of Done
A feature is **done only when**:
- Target behavior meets all acceptance criteria in its `spec/SPEC-<module>.md`.
- Required verification (`./init.sh` / `init.ps1`, `ruff`, `mypy`, `pytest --cov >= 80%`, `gitleaks`) actually ran and passed.
- **Verification Evidence** (command and output) is recorded in `feature_list.json` and `progress.md`.
- The repository remains clean and restartable from `./init.sh` / `init.ps1`.

## End of Session
Before ending a session:
1. Re-run verification and record observed output in `progress.md` and `feature_list.json`.
2. Update `session-handoff.md` with `Last Updated`, `Current Objective`, `Blockers`, `Files`, and `Recommended Next Step`.
3. Leave a clean, restartable git state for the next session.
