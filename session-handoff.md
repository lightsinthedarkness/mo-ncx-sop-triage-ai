# Session Handoff — `ykztir-ncx-ai`

- **Last Updated:** `2026-11-27T22:10:00+07:00`
- **Current Objective:** Design 2.4 / PRD 2.4 / ADR-002 (On-Prem Internal Siebel 16 + Oracle 12c, Zero-Direct-DB Advisory & Non-DB Knowledge Automation, Domain Context Pack, Office 2-Tier RBAC, Hardware Sizing, Golden Benchmark 50–100 NCX) locked & verified; holding cleanly at Coding Gate pending Owner decision on whether Module #1 stays Python (`Docling`) or unifies into 100% Pure Rust.
- **Active Branch:** `feat/sop-ingestion` (synced with `main`)

## Architecture Lock (Design 2.4 — `ADR-001` & `ADR-002`)
- **Hard Boundary:** Zero direct Oracle 12c DB connections (`SELECT`/`UPDATE`/`DDL` prohibited) and zero SSH execution on Siebel 16 production servers.
- **100% Intranet / On-Prem First:** Offline-ready local LLM (`vLLM` Guided JSON / `Ollama`), optional Jev (`E1` redacted only + local fallback), Office 2-Tier RBAC (`User Kantor` / `Admin SOP`) + Immutable Audit Log.
- **Standalone UI (Module #4):** `opendesign-web-portal` completely separate from `https://ncxall.my.id/dashboard` (`C:/Users/Administrator/web` untouched).

## Files Ready for Next Session
- Intent & ADRs: `docs/intent/sop-triage-ai.md`, `docs/adr/ADR-001-*.md`, `docs/adr/ADR-002-*.md`, `DESIGN.md`, `PRD.md`, `README.md`
- Domain, Infra & Evals: `knowledge/domain-pack/README.md`, `infra/HARDWARE-SIZING.md`, `evals/README.md`
- Quality & Harness: `CONSTRAINTS.md`, `AGENTS.md`, `feature_list.json`, `progress.md`, `init.sh`, `init.ps1`, `session-handoff.md`
- Module 1 Spec & Plan: `spec/capability-map.md`, `spec/SPEC-sop-ingestion.md`, `tasks/plan.md`, `tasks/todo.md`

## Blockers
- Coding intentionally paused at Coding Gate per Owner instruction.
- `rustup` (`rustc` / `cargo`) not yet installed locally (required for Modules #2–#3, or for Module #1 too if Owner chooses 100% Pure Rust).

## Recommended Next Step
1. Confirm Owner's choice: **100% Pure Rust (Mod 1+2+3)** vs **Hybrid (Python Mod 1 + Rust Mod 2–3)**.
2. If 100% Pure Rust → write `ADR-003`, update `SPEC-sop-ingestion.md` & `tasks/plan.md` to Rust (`crates/sop-core` + `crates/sop-ingestion`), install `rustup`, then start Phase 4 TDD.
3. If Hybrid → immediately begin Phase 4 TDD on Python Module #1 (`tasks/plan.md`).
