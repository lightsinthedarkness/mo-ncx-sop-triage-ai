# init.ps1 — Baseline Health Check for MO NCX SOP Triage AI
$ErrorActionPreference = "Stop"
Write-Host "=== MO NCX SOP Triage AI: Baseline Check ===" -ForegroundColor Cyan

$requiredDocs = @("AGENTS.md", "CONSTRAINTS.md", "DESIGN.md", "PRD.md", "feature_list.json", "progress.md", "spec\capability-map.md")
foreach ($doc in $requiredDocs) {
    if (-not (Test-Path $doc)) {
        throw "Missing required harness/doc file: $doc"
    }
}
Write-Host "[OK] Core documentation & harness files present." -ForegroundColor Green

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
    Write-Host "[WARN] Python interpreter not active via 'py' yet (will be configured in Module 1 setup)." -ForegroundColor Yellow
}

if (Test-Path "src") {
    if (Get-Command ruff -ErrorAction SilentlyContinue) { ruff check src tests }
    if (Get-Command pytest -ErrorAction SilentlyContinue) { pytest }
} else {
    Write-Host "[INFO] src/ not scaffolded yet (still in Spec/Plan phase)." -ForegroundColor Cyan
}
