# Session Handoff — `ykztir-ncx-ai`

- **Last Updated:** `2026-11-28T01:10:00+07:00`
- **Current Objective:** Complete 100% conversion and adversarial hardening of **Design 2.5 / PRD 2.5 / ADR-003 (100% Pure Rust Backend Workspace + On-Prem Siebel 16 / Oracle 12c Zero-Direct-DB Advisory)** — all 19/19 Pure-Rust adversarial findings + `source-driven-development` crate checks + `documentation-and-adrs` checks reconciled (cross-model skipped per Owner); holding cleanly at Coding Gate pending `rustup` install & Phase 4 TDD go-ahead.
- **Active Branch:** `feat/sop-ingestion` (synced with `main`)

## Architecture Lock (Design 2.5 — `ADR-001`, `ADR-002`, & `ADR-003`)
- **100% Pure Rust Backend (`ADR-003`):** Single Cargo Workspace (`crates/sop-core`, `crates/sop-ingestion`, `crates/sop-memory-rag`, `crates/triage-engine` + `rmcp` Non-DB MCP Tools) + Pure-Rust inference option (`EricLBuehler/mistral.rs` / `huggingface/candle` alongside `vLLM`/`Ollama`) — zero Python production runtime.
- **Hard Boundary (`ADR-002`):** Zero direct Oracle 12c DB connections (`SELECT`/`UPDATE`/`DDL` prohibited) and zero SSH execution on Siebel 16 production servers.
- **100% Intranet / On-Prem First:** Offline-ready local LLM (`vLLM` Guided JSON / `Ollama`), optional Jev (`E1` redacted only + local fallback), Office 2-Tier RBAC (`User Kantor` / `Admin SOP`) + Immutable Audit Log.
- **Standalone UI (Module #4):** `web/` (`opendesign-web-portal`) completely separate from `https://ncxall.my.id/dashboard` (`C:/Users/Administrator/web` untouched).

## Files Ready for Next Session
- Intent & ADRs: `docs/intent/sop-triage-ai.md`, `docs/adr/ADR-001-*.md`, `docs/adr/ADR-002-*.md`, `docs/adr/ADR-003-*.md`, `DESIGN.md`, `PRD.md`, `README.md`
- Domain, Infra & Evals: `knowledge/domain-pack/README.md`, `infra/HARDWARE-SIZING.md`, `evals/README.md`
- Quality & Harness: `CONSTRAINTS.md`, `AGENTS.md`, `feature_list.json`, `progress.md`, `init.sh`, `init.ps1`, `session-handoff.md`
- Module 1 Rust Spec & Plan: `spec/capability-map.md`, `spec/SPEC-sop-ingestion.md`, `tasks/plan.md`, `tasks/todo.md`

## Blockers
- Coding intentionally paused at Coding Gate per Owner instruction.
- `rustup` (`rustc`, `cargo`, `rustfmt`, `clippy`, `cargo-llvm-cov`) must be installed on this Windows PC before executing Step 0 / Task 1 in `tasks/plan.md`.

## Recommended Next Step
1. Install Rust toolchain (`winget install Rustlang.Rustup` + `rustup component add rustfmt clippy llvm-tools-preview` + `cargo install cargo-llvm-cov`).
2. Run `powershell -ExecutionPolicy Bypass -File .\init.ps1` and verify `[OK] Rust detected`.
3. Begin **Phase 4 TDD** on branch `feat/sop-ingestion`: Tasks 1–3 in `tasks/plan.md` (`Cargo.toml` workspace, `crates/sop-core`, `assets.rs`, `vision.rs`).
