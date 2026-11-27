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
Write-Host "[OK] Core documentation, ADR-001/002/003 & harness files present." -ForegroundColor Green

if (Get-Command cargo -ErrorAction SilentlyContinue) {
    $rustcVer = (& rustc --version 2>&1) | Out-String
    $cargoVer = (& cargo --version 2>&1) | Out-String
    Write-Host "[OK] Rust detected: $($rustcVer.Trim()) | $($cargoVer.Trim())" -ForegroundColor Green
} else {
    Write-Host "[WARN] Rust toolchain (rustc/cargo) not installed yet — install via 'winget install Rustlang.Rustup' before Phase 4 TDD." -ForegroundColor Yellow
}

if (Test-Path "Cargo.toml") {
    Write-Host "=== Running Rust fmt, clippy, & workspace tests ===" -ForegroundColor Cyan
    cargo fmt --all -- --check; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    cargo clippy --workspace --all-targets -- -D warnings; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    cargo test --workspace; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
    Write-Host "[INFO] Cargo.toml / crates/ not scaffolded yet (paused at Coding Gate)." -ForegroundColor Cyan
}
