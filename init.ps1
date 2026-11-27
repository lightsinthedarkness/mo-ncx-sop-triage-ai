# init.ps1 — Baseline Health Check for NCX Triage & Self-Evolving Autonomous AI (Design 2.3)
$ErrorActionPreference = "Stop"
Write-Host "=== NCX Triage & Self-Evolving Autonomous AI (ykztir-ncx-ai): Baseline Check ===" -ForegroundColor Cyan

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
    "docs\adr\ADR-001-hybrid-python-rust-and-jev-orchestrator.md"
)
foreach ($doc in $requiredDocs) {
    if (-not (Test-Path $doc)) {
        throw "Missing required harness/doc file: $doc"
    }
}
Write-Host "[OK] Core documentation, ADR-001 & harness files present." -ForegroundColor Green

$pyCmd = $null
if (Get-Command py -ErrorAction SilentlyContinue) {
    $pyVer = (& py --version 2>&1) | Out-String
    if ($LASTEXITCODE -eq 0) { $pyCmd = "py"; Write-Host "[OK] Python detected (py): $($pyVer.Trim())" -ForegroundColor Green }
}
if (-not $pyCmd -and (Get-Command uv -ErrorAction SilentlyContinue)) {
    $uvVer = (& uv --version 2>&1) | Out-String
    if ($LASTEXITCODE -eq 0) { Write-Host "[OK] uv detected: $($uvVer.Trim())" -ForegroundColor Green }
}
if (-not $pyCmd) {
    Write-Host "[WARN] Python interpreter not active via 'py' yet (required for Module 1)." -ForegroundColor Yellow
}

if (Get-Command cargo -ErrorAction SilentlyContinue) {
    $cargoVer = (& cargo --version 2>&1) | Out-String
    if ($LASTEXITCODE -eq 0) { Write-Host "[OK] Rust detected: $($cargoVer.Trim())" -ForegroundColor Green }
} else {
    Write-Host "[INFO] Rust (cargo) not installed yet (required starting Module 2)." -ForegroundColor Cyan
}

if (Test-Path "src") {
    Write-Host "=== Running Python static checks & tests (Module 1) ===" -ForegroundColor Cyan
    ruff check src tests; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    mypy src; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    pytest --cov=src --cov-fail-under=80; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
    Write-Host "[INFO] src/ not scaffolded yet (paused at Coding Gate)." -ForegroundColor Cyan
}

if (Test-Path "Cargo.toml") {
    Write-Host "=== Running Rust clippy & tests (Modules 2-3) ===" -ForegroundColor Cyan
    cargo clippy --all-targets -- -D warnings; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    cargo test --workspace; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
    Write-Host "[INFO] Cargo.toml / crates/ not scaffolded yet (Modules 2-3)." -ForegroundColor Cyan
}
