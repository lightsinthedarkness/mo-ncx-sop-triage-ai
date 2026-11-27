#!/usr/bin/env bash
set -euo pipefail

echo "=== NCX Triage & Self-Evolving Autonomous AI (ykztir-ncx-ai): Baseline Check ==="

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
  "docs/adr/ADR-001-hybrid-python-rust-and-jev-orchestrator.md"
)

for doc in "${required_docs[@]}"; do
  if [[ ! -f "$doc" ]]; then
    echo "[FAIL] Missing required harness/doc file: $doc" >&2
    exit 1
  fi
done
echo "[OK] Core documentation, ADR-001 & harness files present."

if command -v py >/dev/null 2>&1; then
  echo "[OK] Python detected (py): $(py --version 2>&1)"
elif command -v python3 >/dev/null 2>&1; then
  echo "[OK] Python detected (python3): $(python3 --version 2>&1)"
else
  echo "[WARN] Python interpreter not found in PATH."
fi

if command -v cargo >/dev/null 2>&1; then
  echo "[OK] Rust detected: $(cargo --version 2>&1)"
else
  echo "[INFO] Rust (cargo) not installed yet (required starting Module 2)."
fi

if [[ -d "src" ]]; then
  echo "=== Running Python static checks & tests (Module 1) ==="
  ruff check src tests
  mypy src
  pytest --cov=src --cov-fail-under=80
else
  echo "[INFO] src/ not scaffolded yet (paused at Coding Gate)."
fi

if [[ -f "Cargo.toml" ]]; then
  echo "=== Running Rust clippy & tests (Modules 2-3) ==="
  cargo clippy --all-targets -- -D warnings
  cargo test --workspace
else
  echo "[INFO] Cargo.toml / crates/ not scaffolded yet (Modules 2-3)."
fi

echo "=== Verification Complete ==="
echo "Next steps:"
echo "1. Read feature_list.json and session-handoff.md"
echo "2. Work on ONE unfinished feature (F1-sop-ingestion)"
echo "3. Re-run ./init.sh (or .\init.ps1) before claiming done"
