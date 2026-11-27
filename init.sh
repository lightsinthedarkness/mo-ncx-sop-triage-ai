#!/usr/bin/env bash
set -euo pipefail

echo "=== NCX Triage & Internal Autonomous AI (ykztir-ncx-ai — Pure Rust): Baseline Check ==="

required_docs=(
  "AGENTS.md"
  "CONSTRAINTS.md"
  "DESIGN.md"
  "PRD.md"
  "README.md"
  "feature_list.json"
  "progress.md"
  "session-handoff.md"
  "spec/capability-map.md"
  "spec/SPEC-sop-ingestion.md"
  "tasks/plan.md"
  "tasks/todo.md"
  "docs/adr/ADR-001-hybrid-python-rust-and-jev-orchestrator.md"
  "docs/adr/ADR-002-internal-siebel16-oracle12c-zero-db-advisory-and-knowledge-automation.md"
  "docs/adr/ADR-003-pure-rust-backend-workspace.md"
  "infra/HARDWARE-SIZING.md"
  "evals/README.md"
  "knowledge/domain-pack/README.md"
)

for doc in "${required_docs[@]}"; do
  if [[ ! -f "$doc" ]]; then
    echo "[FAIL] Missing required harness/doc file: $doc" >&2
    exit 1
  fi
done
echo "[OK] Core documentation, ADRs (001-003), Spec/Plan & harness files present."

if command -v cargo >/dev/null 2>&1; then
  echo "[OK] Rust detected: $(rustc --version 2>&1) | $(cargo --version 2>&1)"
else
  echo "[WARN] Rust toolchain (rustc/cargo) not installed yet — install via rustup before Phase 4 TDD."
fi

if [[ -f "Cargo.toml" ]]; then
  command -v cargo >/dev/null 2>&1 || { echo "[FAIL] Cargo.toml exists but cargo not found" >&2; exit 1; }
  echo "=== Running Rust blocking quality gates (CONSTRAINTS.md) ==="
  cargo fmt --all -- --check
  cargo clippy --workspace --all-targets -- -D warnings
  cargo test --workspace
  cargo test zero_db_policy
  command -v cargo-llvm-cov >/dev/null 2>&1 || { echo "[FAIL] cargo-llvm-cov required for >=80% coverage gate" >&2; exit 1; }
  cargo llvm-cov --workspace --fail-under-lines 80
  command -v gitleaks >/dev/null 2>&1 || { echo "[FAIL] gitleaks required for secrets gate" >&2; exit 1; }
  gitleaks detect --source . --redact --no-banner
else
  echo "[INFO] Cargo.toml / crates/ not scaffolded yet (paused at Coding Gate)."
fi

echo "=== Verification Complete ==="
echo "Next steps:"
echo "1. Read feature_list.json and session-handoff.md"
echo "2. Work on ONE unfinished feature (F1-sop-ingestion)"
echo "3. Re-run ./init.sh (or .\init.ps1) before claiming done"
