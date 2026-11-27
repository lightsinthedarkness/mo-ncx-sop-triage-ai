# Constraints (`CONSTRAINTS.md`)

Last reviewed: 2026-11-27 by Owner + Agent (`constraint-driven-development` + `ADR-001` + `ADR-002`)

> **Rule:** Read this file before writing any code. Never weaken a threshold, silence a check, or skip a test to make a change pass.

---

## 1. Floor (Always Enforced — Zero Tolerance)

- **No suppression comments** added to bypass failures: no `# noqa`, `# type: ignore`, `@ts-ignore`, or `eslint-disable` without an explicit row in `## Exceptions`.
- **No unimplemented stubs** in production paths: no `raise NotImplementedError`, `pass` placeholders, or empty `except: pass`.
- **No skipped or deleted tests** without an explicit reason approved by Owner.
- **Zero secrets in source, logs, docs, or tests:** Never commit API keys, storepass/keystore passwords, tokens, PINs, TNS/production IPs, or `.env` files. Use synthetic fixtures in tests and `evals/`.
- **Zero direct database or production server connections (`ADR-002`):** Production code and dependencies must **NEVER** connect directly to Oracle 12c (neither `SELECT` nor `UPDATE`/`DDL`) or execute commands on Siebel 16 servers. AI outputs are strictly advisory (copyable reference queries/commands with manual-execution disclaimer) + non-DB knowledge automation.
- **On-prem / intranet-first & zero raw SOP cloud leakage:** All full SOP ingestion, embedding, vision captioning, and answer generation must route through private/local endpoints (`Ollama` / `vLLM` via `LiteLLM`) with full offline capability. Any optional cloud decision call to **Jev (`TypeSafe AI`)** is governed strictly by Exception `E1` below (redacted/metadata-only payloads; zero raw SOP text, IPs, or credentials; mandatory local-LLM fallback).
- **This file cannot be weakened** to get a build or test suite to green.

---

## 2. Enforced with Numbers (Blocking Gates)

| Dimension | Rule / Threshold | Checked By | Runs At |
| :--- | :--- | :--- | :--- |
| **Lint & Format (Python — Mod 1)** | Zero lint/format errors | `ruff check src tests` | every edit / task end |
| **Static Types (Python — Mod 1)** | Zero type errors | `mypy src` | every edit / task end |
| **Unit & Integration Tests (Python)** | 100% tests pass, changed lines ≥ 80% coverage | `pytest --cov=src --cov-fail-under=80` | task end & CI |
| **Lint & Types (Rust — Mod 2–3)** | Zero compiler/clippy warnings | `cargo clippy --all-targets -- -D warnings` | every edit / task end |
| **Unit & Integration Tests (Rust)** | 100% tests pass (incl. Triage State Guard, Office RBAC, & Temporal Isolation) | `cargo test --workspace` | task end & CI |
| **Secrets Scan** | Zero detected secrets (incl. `TYPESAFE_API_KEY`) | `gitleaks detect --source . --redact --no-banner` | every commit / task end |
| **Jev Privacy Redaction & Offline Fallback Guard** | 0% raw SOP/IP/credential leakage in Jev payloads + 100% offline local fallback pass | `cargo test jev_redaction` | task end & CI |
| **Zero-Direct-DB Policy Guard** | 0 Oracle DB client / prod SSH exec dependencies in `pyproject.toml` & `Cargo.toml` | Dependency & policy test (`cargo test zero_db_policy`) | task end & CI |
| **Frontend UI (`opendesign-web-portal`)** | Standalone OpenDesign Web App build + responsive desktop & mobile 390px + a11y PASS | E2E / Playwright check | Module 4 (`opendesign-web-portal`) |

---

## 3. Measured, Not Yet Enforced (Ratchet Targets — Enforced Once Live Model Connected)

| Metric | Target Direction | Measured By |
| :--- | :--- | :--- |
| **Citation Grounding / Faithfulness** | ≥ 95% (must not fall) | Promptfoo / DeepEval on `evals/golden_dataset/` (50–100 NCX cases) |
| **Retrieval Recall@5 (Hybrid BM25+Vector)** | ≥ 90% (must not fall) | `pytest tests/eval/test_retrieval_recall.py` |
| **Zero-Premature-Verdict & Zero-DB Refusal** | 100% (must not fall) | Golden Benchmark suite (`evals/README.md`) |
| **Hybrid Retrieval Latency (p95)** | ≤ 800 ms | Benchmark script / Langfuse trace |
| **LLM Time to First Token (TTFT, Office GPU Server)** | ≤ 3.0 s | Langfuse OTel trace |

---

## 4. Exceptions

| ID | Rule | Path | Reason | Owner | Expires |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `E1` | On-prem / zero external cloud API calls | `crates/triage-engine/src/jev/**` & `evals/**` | Optional Owner-approved **Jev (`TypeSafe AI` `/v1/systemone`, `TYPESAFE_API_KEY`)** as calibrated `Choice` state-router & `Score` eval judge per [ADR-001](docs/adr/ADR-001-hybrid-python-rust-and-jev-orchestrator.md) & [ADR-002](docs/adr/ADR-002-internal-siebel16-oracle12c-zero-db-advisory-and-knowledge-automation.md). Strictly restricted to **redacted metadata/slot state or synthetic eval payloads** (never raw SOP text, IPs, or credentials) with **mandatory offline local-LLM fallback**. | Owner | 2027-11-27 |
