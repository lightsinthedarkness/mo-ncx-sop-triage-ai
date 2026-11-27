# AGENTS.md — MO NCX SOP Triage & Internal Autonomous AI (`LLM` — 100% Pure Rust)

Short operating map for AI coding agents working in `c:/Users/Administrator/LLM`.
Read `CONSTRAINTS.md` before writing code. Do not weaken it to make a change pass.

## Authoritative Docs
- Intent: [docs/intent/sop-triage-ai.md](docs/intent/sop-triage-ai.md)
- Architecture (Design 2.5 — 100% Pure Rust): [DESIGN.md](DESIGN.md), [ADR-001](docs/adr/ADR-001-hybrid-python-rust-and-jev-orchestrator.md), [ADR-002](docs/adr/ADR-002-internal-siebel16-oracle12c-zero-db-advisory-and-knowledge-automation.md), & [ADR-003](docs/adr/ADR-003-pure-rust-backend-workspace.md)
- Product Requirements (PRD 2.5): [PRD.md](PRD.md)
- Infra & Evals: [infra/HARDWARE-SIZING.md](infra/HARDWARE-SIZING.md), [knowledge/domain-pack/README.md](knowledge/domain-pack/README.md), [evals/README.md](evals/README.md)
- Quality Contract: [CONSTRAINTS.md](CONSTRAINTS.md)
- Module Map: [spec/capability-map.md](spec/capability-map.md)
- State & Progress: [feature_list.json](feature_list.json), [progress.md](progress.md)

## Startup Workflow (Every Session)
1. Read `progress.md` and `feature_list.json` to identify the **single** active feature/module.
2. Read `CONSTRAINTS.md` and the active module spec in `spec/SPEC-<module>.md`.
3. Run `powershell -ExecutionPolicy Bypass -File .\init.ps1` (or `./init.sh`) to verify baseline health.
4. Follow the gated skill pipeline strictly — never skip from Spec to Code without Plan & Tasks approval.

## Mandatory Skill Pipeline (`superpowers` + `addyosmani/agent-skills`)
- **Define:** `interview-me` → `brainstorming` → `doubt-driven-development`
- **Specify:** `spec-driven-development` + `api-and-interface-design` + `constraint-driven-development`
- **Plan:** `planning-and-task-breakdown` + `writing-plans` + `source-driven-development`
- **UI Design (Module 4):** **OpenDesign** standalone Web App (`opendesign-web-portal`, terpisah penuh dari `ncxall.my.id/dashboard`)
- **Build & Verify:** `incremental-implementation` + `test-driven-development` (RED → GREEN → REFACTOR) + `observability-and-instrumentation` + `verification-before-completion`
- **Review & Ship:** `code-review-and-quality` + `security-and-hardening` + `code-simplification` + `documentation-and-adrs`

## Project Domain Skills (`.agents/skills/` — 24 Installed)
- **Discovery & Visual Docs:** `find-skills`, `archify`, `archify-pr`
- **RAG & Retrieval Patterns:** `qdrant-search-quality`, `rag-implementation`, `hybrid-search-implementation` *(plus legacy pattern refs: `docling`, `langchain-rag`, `deep-agents-memory`)*
- **Inference & Orchestration Patterns:** `vllm-deploy-docker` *(plus legacy pattern refs: `langgraph-fundamentals`, `langgraph-persistence`, `langgraph-human-in-the-loop`, `fastapi`)*
- **Module 4 (`web/` — `opendesign-web-portal`):** `frontend-design`, `web-design-guidelines`, `design-brief`, `workers-best-practices`
- **Observability, Testing & Eval:** `langfuse`, `llm-evaluation`, `agent-self-evaluation`, `promptfoo-evals` *(plus legacy refs: `python-testing-patterns`, `deepeval`)*

## Rust Workspace Crates (`ADR-003`)
- **Shared Core & Fixtures:** `crates/sop-core` (`serde`, `schemars`, `chrono`, `sha2`, `thiserror`) + `crates/sop-test-support`
- **Module 1 (`crates/sop-ingestion`):** `zip`, `quick-xml`, `calamine`, `oxidize-pdf`/`lopdf`, `image`, `encoding_rs`, `reqwest`, `clap`
- **Module 2 (`crates/sop-memory-rag`):** `qdrant-client` (`1.20.0`), `rig-core` (`0.47.0`), `rig-qdrant` (`0.47.1`), `fastembed` (`7.8.0`)
- **Module 3 (`crates/triage-engine`):** `axum`, `tokio`, `rig-core`, `rmcp` (`1.4.0`), `sqlx`, `jsonwebtoken`, `argon2`, `opentelemetry-otlp`

## Verification Commands
```powershell
./init.sh
powershell -ExecutionPolicy Bypass -File .\init.ps1
cargo fmt --all -- --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
cargo llvm-cov --workspace --fail-under-lines 80
gitleaks detect --source . --redact --no-banner
```

## Scope Rules
- **One feature at a time:** Work strictly on one unfinished feature in `feature_list.json` following `spec/capability-map.md` build order.
- **Stay in scope:** Never mix unrelated refactors, skip Spec/Plan gates, or touch `C:/Users/Administrator/web`.
- **Zero Direct DB / Zero Prod Execution (`ADR-002`):** Never add Oracle 12c DB drivers (`oracle`/`sibyl`/`oci`) or Siebel 16 SSH exec crates to `Cargo.toml`.
- **Never commit secrets or real customer/server credentials** (including passwords found inside sample SOP docs) into code, tests, docs, or git.
- **Never weaken `CONSTRAINTS.md`** or skip failing tests to reach green.
- **No production deploy without explicit Owner approval.**

## Definition of Done
A feature is **done only when**:
- Target behavior meets all acceptance criteria in its `spec/SPEC-<module>.md`.
- Required verification (`./init.sh` / `init.ps1`, `cargo fmt --check`, `cargo clippy -D warnings`, `cargo test --workspace`, `cargo llvm-cov >= 80%`, `gitleaks`) actually ran and passed.
- **Verification Evidence** (command and output) is recorded in `feature_list.json` and `progress.md`.
- The repository remains clean and restartable from `./init.sh` / `init.ps1`.

## End of Session
Before ending a session:
1. Re-run verification and record observed output in `progress.md` and `feature_list.json`.
2. Update `session-handoff.md` with `Last Updated`, `Current Objective`, `Blockers`, `Files`, and `Recommended Next Step`.
3. Leave a clean, restartable git state for the next session.
