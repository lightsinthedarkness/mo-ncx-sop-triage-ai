# init.ps1 — Baseline Health Check for NCX Triage & Internal Autonomous AI (Design 2.5 — 100% Pure Rust)
$ErrorActionPreference = "Stop"
Write-Host "=== NCX Triage & Internal Autonomous AI (ykztir-ncx-ai — Pure Rust): Baseline Check ===" -ForegroundColor Cyan

$requiredDocs = @(
    "AGENTS.md",
    "CONSTRAINTS.md",
    "DESIGN.md",
    "PRD.md",
    "README.md",
    "feature_list.json",
    "progress.md",
    "session-handoff.md",
    "spec\capability-map.md",
    "spec\SPEC-sop-ingestion.md",
    "tasks\plan.md",
    "tasks\todo.md",
    "docs\adr\ADR-001-hybrid-python-rust-and-jev-orchestrator.md",
    "docs\adr\ADR-002-internal-siebel16-oracle12c-zero-db-advisory-and-knowledge-automation.md",
    "docs\adr\ADR-003-pure-rust-backend-workspace.md",
    "infra\HARDWARE-SIZING.md",
    "evals\README.md",
    "knowledge\domain-pack\README.md"
)
foreach ($doc in $requiredDocs) {
    if (-not (Test-Path $doc)) {
        throw "Missing required harness/doc file: $doc"
    }
}
Write-Host "[OK] Core documentation, ADRs (001-003), Spec/Plan & harness files present." -ForegroundColor Green

$hasCargo = [bool](Get-Command cargo -ErrorAction SilentlyContinue)
if ($hasCargo) {
    $rustcVer = (& rustc --version 2>&1) | Out-String
    $cargoVer = (& cargo --version 2>&1) | Out-String
    Write-Host "[OK] Rust detected: $($rustcVer.Trim()) | $($cargoVer.Trim())" -ForegroundColor Green
} else {
    Write-Host "[WARN] Rust toolchain (rustc/cargo) not installed yet — install via 'winget install Rustlang.Rustup' before Phase 4 TDD." -ForegroundColor Yellow
}

if (Test-Path "Cargo.toml") {
    if (-not $hasCargo) {
        throw "Cargo.toml exists but 'cargo' is not installed in PATH."
    }
    Write-Host "=== Running Rust blocking quality gates (CONSTRAINTS.md) ===" -ForegroundColor Cyan
    cargo fmt --all -- --check; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    cargo clippy --workspace --all-targets -- -D warnings; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    cargo test --workspace; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    cargo test zero_db_policy; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if (Get-Command cargo-llvm-cov -ErrorAction SilentlyContinue) {
        cargo llvm-cov --workspace --fail-under-lines 80; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    } else {
        throw "cargo-llvm-cov is required for >= 80% coverage gate (install via 'cargo install cargo-llvm-cov')."
    }
    if (Get-Command gitleaks -ErrorAction SilentlyContinue) {
        gitleaks detect --source . --redact --no-banner; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    } else {
        throw "gitleaks is required for secrets gate."
    }
} else {
    Write-Host "[INFO] Cargo.toml / crates/ not scaffolded yet (paused at Coding Gate)." -ForegroundColor Cyan
}

Write-Host "=== Verification Complete ===" -ForegroundColor Green
Write-Host "Next steps:"
Write-Host "1. Read feature_list.json and session-handoff.md"
Write-Host "2. Work on ONE unfinished feature (F1-sop-ingestion)"
Write-Host "3. Re-run .\init.ps1 (or ./init.sh) before claiming done"
