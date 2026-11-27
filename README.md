# NCX Triage & Self-Evolving Autonomous AI (`ykztir-ncx-ai`)

Sistem **Private Local LLM + Multimodal RAG** untuk tim operasional **NCX** (`SOP EBIS`, `SOP RETAIL`, `SOP WIBS`), dirancang bertahap dengan arsitektur **Design 2.3** ([ADR-001](docs/adr/ADR-001-hybrid-python-rust-and-jev-orchestrator.md)) — memadukan **Python (`Docling`)** untuk Modul #1, **Rust (`Axum` + `Rig` + `qdrant-client`)** untuk Modul #2–#3, **Jev (`TypeSafe AI`)** sebagai *calibrated Choice router & Score judge* (*redacted payload*, Exception `E1`), **LiteLLM/vLLM** untuk Private LLM, serta **Web App Mandiri berbasis OpenDesign** (terpisah penuh dari `ncxall.my.id/dashboard`).

---

## Arsitektur Sistem (Design 2.3 — Archify)

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/diagrams/sop-triage-architecture-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="docs/diagrams/sop-triage-architecture-light.svg">
  <img alt="NCX Triage & Self-Evolving Autonomous AI (Design 2.3 — Hybrid Python + Rust + Jev) Architecture" src="docs/diagrams/sop-triage-architecture-dark.svg" width="100%">
</picture>

> Versi interaktif (zoom, pan, dark/light toggle): [`docs/diagrams/sop-triage-architecture.html`](docs/diagrams/sop-triage-architecture.html)

---

## Ringkasan Alur Kerja AI (Fase 1 — SOP Triage)

AI **dilarang** langsung menebak solusi di pesan pertama. Setiap kendala operasional dipandu melalui *state machine* 4 tahap di **Rust (`Axum` + `Rig`) + Jev (`Choice` router)**:

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
| [docs/intent/sop-triage-ai.md](docs/intent/sop-triage-ai.md) | *Statement of Intent* terkonfirmasi (*Outcome, User, Success, Constraints, Out of Scope*). |
| [DESIGN.md](DESIGN.md) | **Design 2.3** — Arsitektur *Two-Loop* Hybrid Python + Rust + Jev, diagram *4-Stage Triage*, 7 mitigasi celah kritis, & *3-Tier Progressive Rollout*. |
| [docs/adr/ADR-001-hybrid-python-rust-and-jev-orchestrator.md](docs/adr/ADR-001-hybrid-python-rust-and-jev-orchestrator.md) | **ADR-001** — Keputusan resmi Python (Mod 1), Rust (Mod 2–3), dan Jev *Redacted-Payload Boundary* (`E1`). |
| [PRD.md](PRD.md) | **PRD 2.3** — Kebutuhan Fungsional (`FR-1` s/d `FR-6`), target NFR terukur, & roadmap 3 fase. |
| [CONSTRAINTS.md](CONSTRAINTS.md) | Kontrak mutu berangka (*Floor rules*, Python & Rust gates, `jev_redaction`, coverage ≥80%, 100% *Zero-Premature-Verdict*, 0% SOP kedaluwarsa). |
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

## Urutan Build 3 Fase

1. **Fase 1 (Aktif — Core RAG, Triage & Standalone Portal):**
   * `sop-ingestion` *(Python)*: Docling + Vision Captioner + Command-Safe Chunker + MinIO/LocalFS → JSON `IngestResult`
   * `sop-memory-rag` *(Rust)*: `qdrant-client` + `rig-qdrant` Hybrid `bge-m3` + BM25 + Reranker + Temporal Versioning
   * `triage-engine-api` *(Rust + Jev)*: `Axum` + `Rig` 4-Stage Triage + **Jev** *redacted Choice/Score* (`ADR-001`) + LiteLLM `Ollama`/`vLLM` + Langfuse
   * `opendesign-web-portal`: Web App Mandiri berbasis OpenDesign, mis. `ai.ncxall.my.id` / VPS — terpisah dari `ncxall.my.id/dashboard`
2. **Fase 2 (Continuous Self-Evaluation):** `Graphiti` bi-temporal memory, `Promptfoo` + `DeepEval` + **Jev `Score` judge** *Golden Holdout Dataset*, `DSPy`, *Session-Branch Git PR*, & pemisahan `Redis Cache/Queue`.
3. **Fase 3 (Best-of-Breed Autonomous Workers):** `Kestra/Temporal`, `AgentGateway (CEL RBAC)`, `HumanLayer`, `OpenHands`, `Browser-Use`, & *Reversible PII Tokenization*.
