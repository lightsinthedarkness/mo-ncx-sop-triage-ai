# AGENTS.md — MO NCX SOP Triage & Autonomous AI (`LLM`)

Short operating map for AI coding agents working in `c:/Users/Administrator/LLM`.
Read `CONSTRAINTS.md` before writing code. Do not weaken it to make a change pass.

## Authoritative Docs
- Intent: [docs/intent/sop-triage-ai.md](docs/intent/sop-triage-ai.md)
- Architecture (Design 2.2): [DESIGN.md](DESIGN.md)
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
- **UI Design (Module 4):** **OpenDesign** local-first HTML/CSS/JS preview before integrating into `C:/Users/Administrator/web` (also obey `C:/Users/Administrator/web/AGENTS.md`)
- **Build & Verify:** `incremental-implementation` + `test-driven-development` (RED → GREEN → REFACTOR) + `observability-and-instrumentation` + `verification-before-completion`
- **Review & Ship:** `code-review-and-quality` + `security-and-hardening` + `code-simplification` + `documentation-and-adrs`

## Project Domain Skills (`.agents/skills/` — 22 Installed)
- **Discovery:** `find-skills`
- **Module 1 (`sop-ingestion`):** `docling`
- **Module 2 (`sop-memory-rag`):** `qdrant-search-quality`, `rag-implementation`, `hybrid-search-implementation`, `langchain-rag`, `deep-agents-memory`
- **Module 3 (`triage-engine-api`):** `langgraph-fundamentals`, `langgraph-persistence`, `langgraph-human-in-the-loop`, `fastapi`, `vllm-deploy-docker`
- **Module 4 (`dashboard-live-chat`):** `frontend-design`, `web-design-guidelines`, `design-brief`, `workers-best-practices`
- **Observability, Testing & Eval:** `langfuse`, `python-testing-patterns`, `llm-evaluation`, `deepeval`, `agent-self-evaluation`, `promptfoo-evals`

## Verification Commands
```powershell
powershell -ExecutionPolicy Bypass -File .\init.ps1
ruff check src tests
mypy src
pytest --cov=src --cov-fail-under=80
```

## Non-Negotiable Rules
1. **One module / feature at a time** — work strictly in `spec/capability-map.md` build order.
2. **Never commit secrets or real customer/server credentials** (including passwords found inside sample SOP docs) into code, tests, docs, or git.
3. **Never weaken `CONSTRAINTS.md`** or skip failing tests to reach green.
4. **Evidence before claims:** Only mark a feature `done` in `feature_list.json` and `progress.md` after running real verification commands and recording observed output.
5. **No production deploy without explicit Owner approval.**
