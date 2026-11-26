# Constraints (`CONSTRAINTS.md`)

Last reviewed: 2026-11-26 by Owner + Agent (`constraint-driven-development`)

> **Rule:** Read this file before writing any code. Never weaken a threshold, silence a check, or skip a test to make a change pass.

---

## 1. Floor (Always Enforced — Zero Tolerance)

- **No suppression comments** added to bypass failures: no `# noqa`, `# type: ignore`, `@ts-ignore`, or `eslint-disable` without an explicit row in `## Exceptions`.
- **No unimplemented stubs** in production paths: no `raise NotImplementedError`, `pass` placeholders, or empty `except: pass`.
- **No skipped or deleted tests** without an explicit reason approved by Owner.
- **Zero secrets in source, logs, docs, or tests:** Never commit API keys, storepass/keystore passwords, tokens, PINs, or `.env` files. Use synthetic fixtures in tests.
- **Zero external cloud LLM calls with real SOP data:** All SOP ingestion, embedding, vision captioning, and triage inference must route through private/local endpoints (`Ollama` / `vLLM` via `LiteLLM`).
- **This file cannot be weakened** to get a build or test suite to green.

---

## 2. Enforced with Numbers (Blocking Gates)

| Dimension | Rule / Threshold | Checked By | Runs At |
| :--- | :--- | :--- | :--- |
| **Lint & Format (Python)** | Zero lint/format errors | `ruff check src tests` | every edit / task end |
| **Static Types (Python)** | Zero type errors | `mypy src` | every edit / task end |
| **Unit & Integration Tests** | 100% tests pass, changed lines ≥ 80% coverage | `pytest --cov=src --cov-fail-under=80` | task end & CI |
| **Secrets Scan** | Zero detected secrets | `gitleaks dir . --redact --no-banner` *(or regex pre-commit check)* | every commit / task end |
| **Triage State Guard** | 100% premature-verdict tests blocked (`INTERVIEW → ANALYZE → CONFIRM → VERDICT`) | `pytest tests/test_triage_state_machine.py` | task end & CI |
| **Temporal SOP Isolation** | 0% expired (`is_active=false`) SOP chunks returned in retrieval | `pytest tests/test_memory_temporal.py` | task end & CI |
| **Frontend Integration (`web`)** | Build Tailwind + Pages + Worker tests + QA E2E (desktop + mobile 390px) PASS | See `C:/Users/Administrator/web/AGENTS.md` | Module 4 (`dashboard-live-chat`) |

---

## 3. Measured, Not Yet Enforced (Ratchet Targets — Enforced Once Live Model Connected)

| Metric | Target Direction | Measured By |
| :--- | :--- | :--- |
| **Citation Grounding / Faithfulness** | ≥ 95% (must not fall) | Promptfoo / RAGAS eval on `evals/golden_dataset/` |
| **Retrieval Recall@5 (Hybrid BM25+Vector)** | ≥ 90% (must not fall) | `pytest tests/eval/test_retrieval_recall.py` |
| **Hybrid Retrieval Latency (p95)** | ≤ 800 ms | Benchmark script / Langfuse trace |
| **LLM Time to First Token (TTFT, GPU VPS)** | ≤ 3.0 s | Langfuse OTel trace |

---

## 4. Exceptions

| ID | Rule | Path | Reason | Owner | Expires |
| :--- | :--- | :--- | :--- | :--- | :--- |
| *(none)* | — | — | — | — | — |
