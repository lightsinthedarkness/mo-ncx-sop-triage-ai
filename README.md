# NCX Triage & Self-Evolving Autonomous AI (`ykztir-ncx-ai`)

Sistem **Private Local LLM + Multimodal RAG** untuk tim operasional **NCX** (`SOP EBIS`, `SOP RETAIL`, `SOP WIBS`), dirancang bertahap dengan arsitektur **Design 2.2** — menggabungkan komponen *open-source top-star* terbaik per lapisan (**LangGraph**, **Docling**, **Qdrant Hybrid**, **LiteLLM/vLLM**, **Langfuse/Promptfoo/DeepEval**, **OpenHands**, **Browser-Use**) serta **Web App Mandiri berbasis OpenDesign** (terpisah penuh dari `ncxall.my.id/dashboard`).

---

## Arsitektur Sistem (Design 2.2 — Archify)

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/diagrams/sop-triage-architecture-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="docs/diagrams/sop-triage-architecture-light.svg">
  <img alt="MO NCX SOP Triage & Autonomous AI (Design 2.2) Architecture" src="docs/diagrams/sop-triage-architecture-dark.svg" width="100%">
</picture>

> Versi interaktif (zoom, pan, dark/light toggle): [`docs/diagrams/sop-triage-architecture.html`](docs/diagrams/sop-triage-architecture.html)

---

## Ringkasan Alur Kerja AI (Fase 1 — SOP Triage)

AI **dilarang** langsung menebak solusi di pesan pertama. Setiap kendala operasional dipandu melalui *state machine* 4 tahap di **LangGraph**:

```text
① INTERVIEW (Gali segmen EBIS/RETAIL/WIBS, environment Prod/CONS, gejala)
       │
       ▼
② ANALYZE   (Qdrant Native Hybrid Search bge-m3 + BM25 + Reranker + Screenshot SOP)
       │
       ▼
③ CONFIRM   (Konfirmasi ketepatan analisa — jika belum pas, balik ke ① INTERVIEW)
       │
       ▼
④ VERDICT   (Langkah resmi SOP + blok command CLI/XML utuh + sitasi file & gambar)
```

---

## Peta Dokumentasi Proyek

Baca dokumen secara berurutan jika baru membuka proyek ini:

| Dokumen | Isi & Tujuan |
| :--- | :--- |
| [docs/intent/sop-triage-ai.md](docs/intent/sop-triage-ai.md) | *Statement of Intent* terkonfirmasi (*Outcome, User, Success, Constraints, Out of Scope*). |
| [DESIGN.md](DESIGN.md) | **Design 2.2** — Arsitektur *Two-Loop*, diagram *4-Stage Triage*, 7 mitigasi celah kritis, & *3-Tier Progressive Rollout*. |
| [PRD.md](PRD.md) | **PRD 2.2** — Kebutuhan Fungsional (`FR-1` s/d `FR-6`), target NFR terukur, & roadmap 3 fase. |
| [CONSTRAINTS.md](CONSTRAINTS.md) | Kontrak mutu berangka (*Floor rules*, coverage ≥80%, 100% *Zero-Premature-Verdict*, 0% SOP kedaluwarsa). |
| [spec/capability-map.md](spec/capability-map.md) | Peta 4 modul Fase 1 (`sop-ingestion` → `sop-memory-rag` → `triage-engine-api` → `opendesign-web-portal`). |
| [spec/SPEC-sop-ingestion.md](spec/SPEC-sop-ingestion.md) | Spesifikasi resmi Modul #1 (`sop-ingestion` — Approved). |
| [tasks/plan.md](tasks/plan.md) & [tasks/todo.md](tasks/todo.md) | Rencana teknis & daftar tugas TDD Modul #1. |
| [AGENTS.md](AGENTS.md), [feature_list.json](feature_list.json), [progress.md](progress.md) | *Agent Harness* (22 skill proyek di `.agents/skills/` + pelacakan progres lintas sesi). |

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
ruff check src tests
mypy src
pytest --cov=src --cov-fail-under=80
```

---

## Urutan Build 3 Fase

1. **Fase 1 (Aktif — Core RAG, Triage & Standalone Portal):**
   * `sop-ingestion` (Docling + Vision Captioner + Command-Safe Chunker + MinIO/LocalFS)
   * `sop-memory-rag` (Qdrant Hybrid `bge-m3` + BM25 + Reranker + Temporal Versioning)
   * `triage-engine-api` (FastAPI + LangGraph 4-Stage Triage + LiteLLM `Ollama`/`vLLM` + Langfuse)
   * `opendesign-web-portal` (Web App Mandiri berbasis OpenDesign, mis. `ai.ncxall.my.id` / VPS — terpisah dari `ncxall.my.id/dashboard`)
2. **Fase 2 (Continuous Self-Evaluation):** `Graphiti` bi-temporal memory, `Promptfoo` + `DeepEval` *Golden Holdout Dataset*, `DSPy`, *Session-Branch Git PR*, & pemisahan `Redis Cache/Queue`.
3. **Fase 3 (Best-of-Breed Autonomous Workers):** `Kestra/Temporal`, `AgentGateway (CEL RBAC)`, `HumanLayer`, `OpenHands`, `Browser-Use`, & *Reversible PII Tokenization*.
