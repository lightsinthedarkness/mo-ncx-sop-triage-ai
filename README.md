# NCX Triage & Internal Self-Evolving Autonomous AI (`ykztir-ncx-ai`)

Sistem **100% On-Prem Local LLM + Multimodal RAG & Knowledge Automation** khusus **internal kantor operasional MO NCX** berbasis **Siebel CRM 16 + Oracle Database 12c** (`SOP EBIS`, `SOP RETAIL`, `SOP WIBS`). Dirancang dengan arsitektur **Design 2.4** ([ADR-001](docs/adr/ADR-001-hybrid-python-rust-and-jev-orchestrator.md) & [ADR-002](docs/adr/ADR-002-internal-siebel16-oracle12c-zero-db-advisory-and-knowledge-automation.md)):
- **Zero Direct DB / Zero Prod Touch:** AI **tidak** melakukan `SELECT`/`UPDATE` ke Oracle 12c maupun eksekusi ke server Siebel 16 — fokus penuh pada panduan *"bagaimana caranya..."*, analisa log paste user, referensi query/command siap salin, *Auto Handover Note*, dan *Auto SOP-Gap Detector*.
- **Hybrid Stack On-Prem First:** **Python 3.12 (`Docling`)** untuk Modul #1, **Rust (`Axum` + `Rig` + `qdrant-client` + `sqlx`)** untuk Modul #2–#3 dengan *Offline-First Structured Router* (+ **Jev** opsional *redacted E1*), **vLLM/Ollama** untuk Local LLM, serta **Standalone OpenDesign Web Portal** (terpisah penuh dari `ncxall.my.id/dashboard`).

---

## Arsitektur Sistem (Design 2.4 — Archify)

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/diagrams/sop-triage-architecture-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="docs/diagrams/sop-triage-architecture-light.svg">
  <img alt="NCX Triage & Internal Autonomous AI (Design 2.4 — On-Prem Siebel 16 / Oracle 12c Advisory)" src="docs/diagrams/sop-triage-architecture-dark.svg" width="100%">
</picture>

> Versi interaktif (zoom, pan, dark/light toggle): [`docs/diagrams/sop-triage-architecture.html`](docs/diagrams/sop-triage-architecture.html)

---

## Ringkasan Alur Kerja AI (Fase 1 — SOP Triage)

AI **dilarang** langsung menebak solusi di pesan pertama. Setiap kendala operasional dipandu melalui *state machine* 4 tahap di **Rust (`Axum` + `Rig`)** dengan *Local Guided Router* (+ Jev opsional):

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/diagrams/sop-triage-lifecycle-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="docs/diagrams/sop-triage-lifecycle-light.svg">
  <img alt="NCX 4-Stage SOP Triage State Machine (Rust Axum/Rig + Jev)" src="docs/diagrams/sop-triage-lifecycle-dark.svg" width="100%">
</picture>

> Versi interaktif: [`docs/diagrams/sop-triage-lifecycle.html`](docs/diagrams/sop-triage-lifecycle.html)

---

## Peta Dokumentasi Proyek

Baca dokumen secara berurutan jika baru membuka proyek ini:

| Dokumen | Isi & Tujuan |
| :--- | :--- |
| [docs/intent/sop-triage-ai.md](docs/intent/sop-triage-ai.md) | *Statement of Intent* terkonfirmasi (*Internal Siebel 16/Oracle 12c, Zero Direct DB, Standalone Portal*). |
| [DESIGN.md](DESIGN.md) | **Design 2.4** — Arsitektur *Two-Loop On-Prem First*, diagram *4-Stage Triage*, 7 mitigasi celah kritis, & *3-Tier Rollout*. |
| [docs/adr/ADR-001-hybrid-python-rust-and-jev-orchestrator.md](docs/adr/ADR-001-hybrid-python-rust-and-jev-orchestrator.md) | **ADR-001** — Keputusan Hybrid Python (Mod 1), Rust (Mod 2–3), dan Jev *Redacted-Payload Boundary* (`E1`). |
| [docs/adr/ADR-002-internal-siebel16-oracle12c-zero-db-advisory-and-knowledge-automation.md](docs/adr/ADR-002-internal-siebel16-oracle12c-zero-db-advisory-and-knowledge-automation.md) | **ADR-002** — Batas keras *Zero Direct DB*, *On-Prem First*, *Domain Pack Siebel 16/Oracle 12c*, Office RBAC, & *Non-DB Automation*. |
| [PRD.md](PRD.md) | **PRD 2.4** — Kebutuhan Fungsional (`FR-1` s/d `FR-6`), Office RBAC 2-Tier, target NFR terukur, & roadmap 3 fase. |
| [CONSTRAINTS.md](CONSTRAINTS.md) | Kontrak mutu berangka (*Zero-Direct-DB Floor*, Python & Rust gates, `jev_redaction`, coverage ≥80%, 100% *Zero-Premature-Verdict*). |
| [infra/HARDWARE-SIZING.md](infra/HARDWARE-SIZING.md) | Panduan sizing GPU Server Kantor (24 GB / 48 GB VRAM `vLLM`) & topologi self-hosted intranet. |
| [knowledge/domain-pack/README.md](knowledge/domain-pack/README.md) | Struktur konteks statis Siebel 16 & Oracle 12c (*read-only*, nol koneksi DB). |
| [evals/README.md](evals/README.md) | Skema & rubrik **Golden Benchmark 50–100 Kasus NCX** sebelum rilis ke tim kantor. |
| [spec/capability-map.md](spec/capability-map.md) | Peta 4 modul Fase 1 (`sop-ingestion` → `sop-memory-rag` → `triage-engine-api` → `opendesign-web-portal`). |
| [spec/SPEC-sop-ingestion.md](spec/SPEC-sop-ingestion.md) | Spesifikasi resmi Modul #1 (`sop-ingestion` — Approved). |
| [tasks/plan.md](tasks/plan.md) & [tasks/todo.md](tasks/todo.md) | Rencana teknis & daftar tugas TDD Modul #1. |
| [AGENTS.md](AGENTS.md), [feature_list.json](feature_list.json), [progress.md](progress.md) | *Agent Harness* (24 skill proyek di `.agents/skills/` + pelacakan progres lintas sesi). |

---

## Quickstart Lokal (Windows / PowerShell)

### 1. Cek Kesehatan Baseline Proyek
```powershell
powershell -ExecutionPolicy Bypass -File .\init.ps1
```

### 2. Setup Python Virtual Environment (Mulai Modul #1)
```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -e ".[dev]"
```

### 3. Perintah Verifikasi Wajib (`CONSTRAINTS.md`)
```powershell
# Modul #1 (Python)
ruff check src tests
mypy src
pytest --cov=src --cov-fail-under=80

# Modul #2–#3 (Rust — setelah rustup & crates/ aktif)
cargo clippy --all-targets -- -D warnings
cargo test --workspace

# Keamanan Secret (semua commit)
gitleaks detect --source . --redact --no-banner
```

---

## Urutan Build 3 Fase (100% On-Prem Intranet Kantor)

1. **Fase 1 (Aktif — Core RAG, Advisory Triage, Domain Pack & Standalone Portal):**
   * `sop-ingestion` *(Python 3.12)*: Docling + Vision Captioner + Command-Safe Chunker + `knowledge/domain-pack/` + MinIO/LocalFS → JSON `IngestResult`
   * `sop-memory-rag` *(Rust)*: `qdrant-client` + `rig-qdrant` Hybrid `bge-m3` + BM25 + Reranker + Temporal Versioning
   * `triage-engine-api` *(Rust)*: `Axum` + `Rig` + `sqlx` 4-Stage Triage + Offline-First Local Router (+ **Jev** opsional `E1`) + Office RBAC & Immutable Audit Log + *Auto Handover Note* + *Auto SOP-Gap Detector* + LiteLLM (`Ollama`/`vLLM`) + Langfuse
   * `opendesign-web-portal`: Web App Mandiri berbasis OpenDesign (intranet kantor — terpisah penuh dari `ncxall.my.id/dashboard`)
2. **Fase 2 (Continuous Self-Evaluation — Self-Hosted):** `Graphiti` bi-temporal memory, **Golden Benchmark 50–100 Kasus NCX** (`Promptfoo` + `DeepEval` + opsi `Jev Score`), `DSPy`, *Session-Branch Git PR*, & pemisahan `Redis Cache/Queue`.
3. **Fase 3 (Self-Hosted Knowledge Automation — Non-DB):** `Kestra/Temporal` internal untuk *SOP freshness audit* & pelaporan berkala berbasis pengetahuan (tetap **Zero Direct DB / Zero Prod Execution**).
