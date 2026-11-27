# NCX Triage & Internal Self-Evolving Autonomous AI (`ykztir-ncx-ai`)

Sistem **100% Pure Rust On-Prem Local LLM + Multimodal RAG & Knowledge Automation** khusus **internal kantor operasional MO NCX** berbasis **Siebel CRM 16 + Oracle Database 12c** (`SOP EBIS`, `SOP RETAIL`, `SOP WIBS`). Dirancang dengan arsitektur **Design 2.5** ([ADR-001](docs/adr/ADR-001-hybrid-python-rust-and-jev-orchestrator.md), [ADR-002](docs/adr/ADR-002-internal-siebel16-oracle12c-zero-db-advisory-and-knowledge-automation.md), & [ADR-003](docs/adr/ADR-003-pure-rust-backend-workspace.md)):
- **100% Pure Rust Backend Workspace (`ADR-003`):** Satu Cargo Workspace (`crates/sop-core`, `crates/sop-ingestion`, `crates/sop-memory-rag`, `crates/triage-engine`) tanpa Python runtime di server kantor — 1 binary statis (< 50 MB RAM idle), *compile-time type safety* lintas modul.
- **Zero Direct DB / Zero Prod Touch (`ADR-002`):** AI **tidak** melakukan `SELECT`/`UPDATE` ke Oracle 12c maupun eksekusi ke server Siebel 16 — fokus penuh pada panduan *"bagaimana caranya..."*, analisa log paste user, referensi query/command siap salin, *Auto Handover Note*, dan *Auto SOP-Gap Detector*.
- **100% On-Prem Intranet First + Standalone OpenDesign Portal:** Berjalan penuh di LAN kantor (`vLLM`/`Ollama`, Qdrant, MinIO, PostgreSQL 16, Langfuse, **OpenDesign Web Portal** yang terpisah penuh dari `ncxall.my.id/dashboard`), dengan **Jev (`E1`)** opsional + *offline local fallback*.

---

## Arsitektur Sistem (Design 2.5 — 100% Pure Rust — Archify)

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/diagrams/sop-triage-architecture-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="docs/diagrams/sop-triage-architecture-light.svg">
  <img alt="NCX Triage & Internal Autonomous AI (Design 2.5 — 100% Pure Rust On-Prem Advisory)" src="docs/diagrams/sop-triage-architecture-dark.svg" width="100%">
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
| [DESIGN.md](DESIGN.md) | **Design 2.5** — Arsitektur *100% Pure Rust On-Prem First*, tabel repo Rust terverifikasi, & *3-Tier Rollout*. |
| [docs/adr/ADR-003-pure-rust-backend-workspace.md](docs/adr/ADR-003-pure-rust-backend-workspace.md) | **ADR-003** — Penyatuan seluruh backend (Mod 1, 2, & 3) ke **100% Pure Rust Cargo Workspace**. |
| [docs/adr/ADR-002-internal-siebel16-oracle12c-zero-db-advisory-and-knowledge-automation.md](docs/adr/ADR-002-internal-siebel16-oracle12c-zero-db-advisory-and-knowledge-automation.md) | **ADR-002** — Batas keras *Zero Direct DB*, *On-Prem First*, *Domain Pack Siebel 16/Oracle 12c*, Office RBAC, & *Non-DB Automation*. |
| [docs/adr/ADR-001-hybrid-python-rust-and-jev-orchestrator.md](docs/adr/ADR-001-hybrid-python-rust-and-jev-orchestrator.md) | **ADR-001** — Keputusan awal Rust & Jev *Redacted-Payload Boundary* (`E1`, Mod 1 digantikan ADR-003). |
| [PRD.md](PRD.md) | **PRD 2.5** — Kebutuhan Fungsional (`FR-1` s/d `FR-6`), Office RBAC 2-Tier, target NFR terukur, & roadmap 3 fase. |
| [CONSTRAINTS.md](CONSTRAINTS.md) | Kontrak mutu berangka (*Zero-Direct-DB Floor*, 100% Rust `fmt`/`clippy`/`test`/`llvm-cov >= 80%`, `jev_redaction`, `gitleaks`). |
| [infra/HARDWARE-SIZING.md](infra/HARDWARE-SIZING.md) | Panduan sizing GPU Server Kantor (24 GB / 48 GB VRAM `vLLM`) & topologi self-hosted intranet. |
| [knowledge/domain-pack/README.md](knowledge/domain-pack/README.md) | Struktur konteks statis Siebel 16 & Oracle 12c (*read-only*, nol koneksi DB). |
| [evals/README.md](evals/README.md) | Skema & rubrik **Golden Benchmark 50–100 Kasus NCX** sebelum rilis ke tim kantor. |
| [spec/capability-map.md](spec/capability-map.md) | Peta 4 modul Fase 1 (`sop-ingestion` → `sop-memory-rag` → `triage-engine-api` → `opendesign-web-portal`). |
| [spec/SPEC-sop-ingestion.md](spec/SPEC-sop-ingestion.md) | Spesifikasi resmi Modul #1 (`crates/sop-core` + `crates/sop-ingestion` — Rust Approved). |
| [tasks/plan.md](tasks/plan.md) & [tasks/todo.md](tasks/todo.md) | Rencana teknis & daftar tugas TDD Rust Modul #1. |
| [AGENTS.md](AGENTS.md), [feature_list.json](feature_list.json), [progress.md](progress.md) | *Agent Harness* (24 skill proyek di `.agents/skills/` + pelacakan progres lintas sesi). |

---

## Quickstart Lokal (Windows / PowerShell — 100% Rust)

### 1. Cek Kesehatan Baseline Proyek
```powershell
powershell -ExecutionPolicy Bypass -File .\init.ps1
```

### 2. Pasang Toolchain Rust (Prasyarat Sebelum Phase 4 TDD)
```powershell
winget install Rustlang.Rustup
rustup component add rustfmt clippy llvm-tools-preview
cargo install cargo-llvm-cov
```

### 3. Perintah Verifikasi Wajib (`CONSTRAINTS.md`)
```powershell
cargo fmt --all -- --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
cargo llvm-cov --workspace --fail-under-lines 80
gitleaks detect --source . --redact --no-banner
```

---

## Urutan Build 3 Fase (100% Pure Rust On-Prem Intranet Kantor)

1. **Fase 1 (Aktif — Core RAG, Advisory Triage, Domain Pack & Standalone Portal):**
   * `crates/sop-core` + `crates/sop-ingestion` *(Rust)*: `zip` + `quick-xml` + `calamine` + `lopdf` + Local Vision (`reqwest`) + Command-Safe Chunker + `knowledge/domain-pack/` + LocalFS/MinIO
   * `crates/sop-memory-rag` *(Rust)*: `qdrant-client` + `rig-qdrant` + `fastembed` Hybrid `bge-m3` + BM25 + Reranker + Temporal Versioning
   * `crates/triage-engine` *(Rust)*: `Axum` + `Rig` + `sqlx` 4-Stage Triage + Offline-First Local Router (+ **Jev** opsional `E1`) + Office RBAC & Immutable Audit Log + *Auto Handover Note* + *Auto SOP-Gap Detector* + LiteLLM (`Ollama`/`vLLM`) + Langfuse OTel
   * `web/` (`opendesign-web-portal`): Web App Mandiri berbasis OpenDesign (intranet kantor — terpisah penuh dari `ncxall.my.id/dashboard`)
2. **Fase 2 (Continuous Self-Evaluation — Self-Hosted):** `Graphiti` bi-temporal memory, **Golden Benchmark 50–100 Kasus NCX** (`Promptfoo` + opsi `Jev Score`), *Session-Branch Git PR*, & pemisahan `Redis Cache/Queue`.
3. **Fase 3 (Self-Hosted Knowledge Automation — Non-DB):** `Kestra/Temporal` internal untuk *SOP freshness audit* & pelaporan berkala berbasis pengetahuan (tetap **Zero Direct DB / Zero Prod Execution**).
