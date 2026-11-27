# Constraints (`CONSTRAINTS.md`)

Last reviewed: 2026-11-28 by Owner + Agent (`constraint-driven-development` + `ADR-001` + `ADR-002` + `ADR-003` + 19/19 Adversarial Findings Reconciled)

> **Rule:** Read this file before writing any code. Never weaken a threshold, silence a check, or skip a test to make a change pass.

---

## 1. Floor (Always Enforced — Zero Tolerance)

- **No suppression comments or unsafe shortcuts** added to bypass failures: no `#[allow(warnings)]`, `#[allow(clippy::all)]`, `unsafe` blocks, `@ts-ignore`, or `eslint-disable` without an explicit row in `## Exceptions`.
- **No unimplemented stubs or panics in production paths:** no `todo!()`, `unimplemented!()`, or `.unwrap()` / `.expect()` on untrusted runtime input (use `Result<T, E>` + `thiserror`).
- **No skipped or deleted tests** (`#[ignore]` without an explicit reason approved by Owner) and **no `std::env::set_var` mutations inside parallel tests** (inject config structs directly).
- **Zero secrets in source, logs, chunks, captions, docs, or tests:** Never commit API keys, storepass/keystore passwords, tokens, PINs, TNS/production IPs, or `.env` files. Real SOP plaintext credentials (e.g., `-storepass`) **must** be scrubbed by `secret_scrubber` before entering `SopChunk.content`, `ExtractedAsset.caption`, Qdrant payloads, or CLI JSON output. The same shared scrubber (`sop-core`) **must also** run on chat/paste-log input, the Immutable Audit Log, and OTel/Langfuse trace payloads. SOP screenshots must **never** be served to users before `review_status = approved` by an Admin (scrubbing cannot see pixels).
- **Zero direct database or production server connections (`ADR-002`):** Production code and workspace `Cargo.toml`/`Cargo.lock` must **NEVER** depend on Oracle DB drivers (`oracle`/`sibyl`/`oci`/`odpi`), production SSH exec crates (`russh`/`ssh2`/`openssh`/`async-ssh2-tokio`), or invoke `Command::new("sqlplus" | "ssh")`. AI outputs are strictly advisory + non-DB knowledge automation.
- **100% Pure Rust Backend Application (`ADR-003`) & On-Prem / Intranet First:** All custom backend crates (`sop-core`, `sop-ingestion`, `sop-memory-rag`, `triage-engine`) compile inside one Rust 2021 Cargo Workspace without Python runtime dependencies (optional Docker sidecars like `vLLM`/`LiteLLM`/`Graphiti` stay isolated if used; default pure-Rust inference uses `mistral.rs`). Full SOP ingestion, embedding, vision captioning, and answer generation must stay private/local with full offline capability. Any optional cloud decision call to **Jev (`TypeSafe AI`)** is governed strictly by Exception `E1`.
- **This file cannot be weakened** to get a build or test suite to green.

---

## 2. Enforced with Numbers (Blocking Gates)

| Dimension | Rule / Threshold | Checked By | Runs At |
| :--- | :--- | :--- | :--- |
| **Formatting (Rust Workspace)** | Zero formatting diffs | `cargo fmt --all -- --check` | every edit / task end |
| **Lint & Static Types (Rust Workspace)** | Zero compiler/clippy warnings | `cargo clippy --workspace --all-targets -- -D warnings` | every edit / task end |
| **Unit & Integration Tests (Rust Workspace)** | 100% tests pass | `cargo test --workspace` | task end & CI |
| **Code Coverage (Rust Workspace)** | Line coverage ≥ 80% on workspace crates | `cargo llvm-cov --workspace --fail-under-lines 80` | task end & CI |
| **Secrets Scan (Repo)** | Zero detected secrets (incl. `TYPESAFE_API_KEY`) | `gitleaks detect --source . --redact --no-banner` | every commit / task end |
| **SOP Plaintext Secret Scrubber Guard** | 0% `-storepass`/`password=`/PEM leaks in chunks, captions, or CLI JSON | `cargo test -p sop-core secret_scrubber` | Module 1+ task end & CI |
| **Chat/Audit/Trace Input Scrub Guard** | 0% plaintext credentials in LLM prompts, audit log rows, or trace payloads derived from pasted logs | `cargo test -p triage-engine input_scrub` | Module 3+ task end & CI |
| **Asset Review Gate** | 0 screenshots served while `review_status != approved` | `cargo test -p triage-engine asset_review_gate` | Module 3+ task end & CI |
| **Zero-Direct-DB Policy Guard** | 0 forbidden Oracle/SSH crates across workspace `Cargo.toml`/`Cargo.lock` & 0 `sqlplus`/`ssh` subprocess calls | `cargo test zero_db_policy` | every task end & CI |
| **Jev Privacy Redaction & Offline Fallback Guard** | 0% raw SOP/IP/credential leakage in Jev payloads + 100% offline local fallback pass | `cargo test -p triage-engine jev_redaction` | Module 3+ task end & CI |
| **Frontend UI (`opendesign-web-portal`)** | Standalone OpenDesign Web App build + responsive desktop & mobile 390px + a11y PASS | E2E / Playwright check | Module 4 (`web/`) |

---

## 3. Measured, Not Yet Enforced (Ratchet Targets — Enforced Once Live Model Connected)

| Metric | Target Direction | Measured By |
| :--- | :--- | :--- |
| **Citation Grounding / Faithfulness** | ≥ 95% (must not fall) | Promptfoo on `evals/golden_dataset/` (80–100 NCX cases) |
| **Retrieval Recall@5 (Hybrid BM25+Vector)** | ≥ 90% (must not fall) | `cargo test -p sop-memory-rag retrieval_recall` |
| **Zero-Premature-Verdict & Zero-DB Refusal** | 100% (must not fall) | Golden Benchmark suite (`evals/README.md`) |
| **Hybrid Retrieval Latency (p95)** | ≤ 800 ms | Benchmark test / Langfuse trace |
| **LLM Time to First Token (TTFT, Office GPU Server)** | ≤ 3.0 s | Langfuse OTel trace |

---

## 4. Exceptions

| ID | Rule | Path | Reason | Owner | Expires |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `E1` | On-prem / zero external cloud API calls | `crates/triage-engine/src/jev/**` & `evals/**` | Optional Owner-approved **Jev (`TypeSafe AI` `/v1/systemone`, `TYPESAFE_API_KEY`)** as calibrated `Choice` state-router & `Score` eval judge per [ADR-001](docs/adr/ADR-001-hybrid-python-rust-and-jev-orchestrator.md) & [ADR-002](docs/adr/ADR-002-internal-siebel16-oracle12c-zero-db-advisory-and-knowledge-automation.md). Strictly restricted to **redacted metadata/slot state or synthetic eval payloads** (never raw SOP text, IPs, or credentials) with **mandatory offline local-LLM fallback**. | Owner | 2027-11-27 |

---

## 5. Dev-Only Tooling Notes

- `Promptfoo` (Node.js) hanya dipakai untuk evaluasi/CI di mesin dev/CI, **bukan** bagian runtime produksi (produksi tetap single-binary Rust tanpa Node).
- Sidecar opsional (`vLLM`, `LiteLLM`, Fase 2 `Graphiti`, `Kestra`/`Temporal`) berjalan sebagai container terpisah dan tidak mengubah klaim *zero-Python* untuk aplikasi inti.
- Target latensi/VRAM/TTFT pada bagian 3 adalah **target yang wajib diukur**, bukan klaim terbukti, sampai ada pengukuran di hardware kantor.
