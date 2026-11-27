# DESIGN.md — NCX Triage & Internal Self-Evolving Autonomous AI Architecture (Design 2.4)

> [!IMPORTANT]
> Dokumen ini merupakan **Design 2.4** (memperbarui Design 2.3 per [ADR-001](docs/adr/ADR-001-hybrid-python-rust-and-jev-orchestrator.md) & [ADR-002](docs/adr/ADR-002-internal-siebel16-oracle12c-zero-db-advisory-and-knowledge-automation.md)):
> 1. **Zero Direct DB / Zero Prod Server Execution (Hard Boundary):** Khusus internal kantor berbasis **Siebel CRM 16 + Oracle Database 12c**. AI **TIDAK terhubung ke Oracle 12c** (baik `SELECT` maupun `UPDATE/DDL` dilarang) dan **TIDAK mengeksekusi perintah ke server produksi**. AI berfokus penuh pada **Advisory ("bagaimana caranya...")**, analisa log yang di-paste/upload user di chat, referensi query/command siap salin, serta **Non-DB Knowledge & Workflow Automation**.
> 2. **100% Intranet / On-Prem First:** Seluruh stack inti (**Python `Docling`**, **Rust `Axum`/`Rig`/`sqlx`**, **Qdrant**, **vLLM/Ollama**, **MinIO**, **PostgreSQL**, **Langfuse**, **OpenDesign Web Portal**) berjalan mandiri di jaringan internal kantor tanpa ketergantungan internet. **Jev (`TypeSafe AI`, Exception `E1`)** bersifat **opsional** (*redacted payload only*) dengan **Local Structured-Output Engine (`vLLM` Guided JSON)** sebagai *primary offline-ready router*.
> 3. **Domain Context Pack (`knowledge/domain-pack/`):** File pengetahuan statis/read-only (katalog tabel `S_*`/`CX_*`, komponen Siebel 16 `srvrmgr`, kamus NCX, dan template referensi query/command) agar jawaban bebas halusinasi.
> 4. **Office User Identity & 2-Tier RBAC + Immutable Audit Log:** Login user kantor (`User Kantor` vs `Admin SOP`) dengan pencatatan audit sesi, sitasi SOP, dan *Auto SOP-Gap Detector*.
> 5. **Standalone OpenDesign Web Portal (`opendesign-web-portal`):** Berdiri sendiri di jaringan internal kantor (mis. `ai.ncxall.my.id` / intranet VPS — terpisah penuh dari `https://ncxall.my.id/dashboard`) dengan protokol SSE Streaming.

---

## 1. Tujuan Arsitektur (3 Pilar Utama — 100% On-Prem Internal Kantor)

1. **Multimodal SOP & Siebel 16 / Oracle 12c Domain Grounding (Fase 1):** Menyerap dokumen SOP operasional MO NCX (`SOP EBIS`, `SOP RETAIL`, `SOP WIBS` dalam format `.docx`, `.pdf`, `.xlsx`, `.pptx`, dan skrip) termasuk *screenshot* konfigurasi *before/after* + **Domain Context Pack** (`knowledge/domain-pack/`) tanpa kontradiksi antar versi.
2. **Deterministic 4-Stage Triage & Non-DB Knowledge Automation (Fase 1 – 1.5):**
   - **Loop 1 (Triage & Advisory):** **Rust Triage Engine (`Axum` + `Rig`)** dengan *Offline-First Structured Router* (serta **Jev `Choice`** opsional via Exception `E1`) mengunci alur `INTERVIEW → ANALYZE → CONFIRM → VERDICT` agar AI tidak pernah menebak solusi di pesan pertama.
   - **Non-DB Automation:** Auto-ingestion & versioning SOP (`v1 → v2`), analisa potongan log yang di-paste/upload user di chat, **Auto Handover / Escalation Note Generator**, serta **Auto SOP-Gap Detector** ke backlog Admin saat `NO SOP MATCH`.
3. **Continuous Self-Evaluation & Self-Hosted Workflow Automation (Fase 2 – 3):**
   - **Loop 2 (Pola Hermes — Fase 2):** Evaluasi otomatis terhadap **Golden Benchmark 50–100 Kasus NCX** ([evals/README.md](evals/README.md)) via `Promptfoo` + `DeepEval` (+ opsi `Jev Score` pada payload sintetis), memori bi-temporal (**Graphiti**), serta usulan perbaikan `skills/*.md` lewat **Session-Branch Git PR** + *Admin Approval*.
   - **Self-Hosted Internal Automation (Fase 3):** Ekstensi automasi *non-DB / non-prod-destructive* yang 100% *self-hosted on-prem* (mis. *scheduled SOP freshness audit*, *knowledge sync*, *drafting report* terjadwal via Kestra/Temporal internal + *Approvals Queue* manusia).

---

## 2. Diagram Arsitektur

### 2.1 Arsitektur Menyeluruh (Design 2.4 — On-Prem Internal Advisory & Knowledge Automation)

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/diagrams/sop-triage-architecture-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="docs/diagrams/sop-triage-architecture-light.svg">
  <img alt="NCX Triage & Internal Autonomous AI (Design 2.4 — On-Prem Siebel 16 / Oracle 12c Advisory)" src="docs/diagrams/sop-triage-architecture-dark.svg" width="100%">
</picture>

> Versi interaktif **Archify** (zoom, pan, dark/light toggle): [`docs/diagrams/sop-triage-architecture.html`](docs/diagrams/sop-triage-architecture.html)

<details>
<summary>Detail Topologi Lengkap (Mermaid Two-Loop On-Prem Source)</summary>

```mermaid
flowchart TD
    subgraph GIT["Git Repository (Single Source of Truth — On-Prem)"]
        W["workspace.yaml (Manifest Agent, Segmen, Policies)"]
        SOUL["soul.md (Aturan Tetap & Zero-Direct-DB Boundary — Immutable)"]
        SKILLS["skills/*.md (Playbook & SOP Dinamis)"]
        DOMAIN["knowledge/domain-pack/ (Static Siebel 16 & Oracle 12c Glossary/Schema)"]
        EVALS["evals/golden_dataset/ (50-100 Kasus Uji NCX Ter-anonymize)"]
    end

    subgraph INGEST["Ingestion & Multimodal Context Layer (Fase 1 — Python Mod 1 + Rust Mod 2)"]
        FILES["File SOP MO NCX (EBIS / RETAIL / WIBS: DOCX, PDF, XLSX, PPTX, Code)"]
        DOC["Docling (Python 3.12 · Docs/Tables + Command-Safe Chunker)"]
        VLM["Local Vision-LLM (Qwen2.5-VL Screenshot Captioner)"]
        ART["MinIO / S3 (SOP Screenshot Assets — Intranet)"]
        QDRANT["Qdrant Hybrid DB (Rust qdrant-client · bge-m3 + BM25 + Reranker + Temporal ACL)"]
        GRAPHITI["Graphiti (Bi-Temporal Knowledge Graph — Fase 2)"]
    end

    subgraph LOOP1["LOOP 1: TRIAGE ADVISORY & NON-DB KNOWLEDGE AUTOMATION (Rust Mod 3)"]
        UI["OpenDesign Web Portal (Standalone Intranet — Chat Triage, Paste Log, Handover Note & Admin SOP)"]
        AUTH["Office Auth & 2-Tier RBAC (LDAP/AD or JWT · User Kantor vs Admin SOP)"]
        TR["Rust Triage Orchestrator (Axum + Rig · 4-Stage State Machine + Local Guided JSON Router)"]
        AUTO["Non-DB Automation Workers (Auto Handover Note + Auto SOP-Gap Detector + Log Analyzer)"]
        JEV["Jev Router & Judge (Optional Cloud E1 · Redacted Choice/Score · Local Fallback)"]
    end

    subgraph INFRA["100% On-Prem GPU Inference, State & Observability"]
        LITE["LiteLLM Gateway (Quota Isolation Prod vs Eval)"]
        LLM["Local Hugging Face LLM (vLLM GPU Kantor / Ollama Dev: Qwen3-14B / 32B)"]
        PG["PostgreSQL (sqlx Session Checkpointer + Office RBAC + SOP-Gap + Immutable Audit Log)"]
        RC["Redis Cache / Queue (Self-Hosted — Fase 2)"]
        LF["Langfuse Self-Hosted + OpenTelemetry (Intranet Trace)"]
    end

    subgraph LOOP2["LOOP 2: CONTINUOUS EVALUATION — Pola Hermes (Fase 2, Self-Hosted)"]
        EV["Evaluator Pipeline (100% Fail + 10-20% Pass Sampling)"]
        PF["Promptfoo + DeepEval (Golden Benchmark Gate + Red-Team Zero-DB Check)"]
        DSPY["DSPy (Metric-Driven Playbook Optimizer)"]
        CR["Session-Branch Change Request (Git PR + Admin Approval)"]
    end

    FILES --> DOC --> QDRANT
    DOMAIN --> DOC
    FILES --> VLM --> QDRANT
    VLM --> ART
    DOC --> GRAPHITI

    GIT --> TR
    QDRANT --> TR
    GRAPHITI --> TR
    ART --> UI

    UI <--> AUTH <--> TR
    TR <--> AUTO
    TR -.->|"Optional Redacted State (E1)"| JEV
    TR --> LITE --> LLM
    TR <--> PG
    AUTO <--> PG
    LITE <--> RC

    TR -.-> LF
    LF --> EV
    EV -.->|"Optional Synthetic Eval (E1)"| JEV
    EV -->|"Provenance + Snapshot"| GRAPHITI
    EV --> DSPY --> CR --> PF
    EVALS --> PF
    PF -->|"Lolos Benchmark + Admin Approval"| SKILLS
```

</details>

### 2.2 Alur Wajib 4-Tahap SOP Triage State Machine (Rust Axum/Rig + Local/Jev Router — Fase 1)

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/diagrams/sop-triage-lifecycle-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="docs/diagrams/sop-triage-lifecycle-light.svg">
  <img alt="NCX 4-Stage SOP Triage State Machine (Rust Axum/Rig + Jev)" src="docs/diagrams/sop-triage-lifecycle-dark.svg" width="100%">
</picture>

> Versi interaktif **Archify** (zoom, pan, dark/light toggle): [`docs/diagrams/sop-triage-lifecycle.html`](docs/diagrams/sop-triage-lifecycle.html)

---

## 3. Batasan Arsitektural & Pola Terbaik (Design 2.4)

| Prinsip / Pola | Implementasi di Design 2.4 | Manfaat |
| :--- | :--- | :--- |
| **Zero Direct DB / Prod Touch (`ADR-002`)** | Nol koneksi Oracle 12c (`SELECT`/`UPDATE` dilarang), nol SSH exec ke server Siebel 16 | 0% risiko merusak/membebani database & server produksi kantor; AI aman dipakai seluruh tim operasional. |
| **On-Prem / Intranet First** | Semua layanan inti (`vLLM`, `Qdrant`, `MinIO`, `PostgreSQL`, `Langfuse`, `OpenDesign`) jalan 100% lokal di LAN kantor; **Jev (`E1`)** opsional dengan *local fallback* penuh | Sistem tetap 100% fungsional di jaringan kantor tanpa akses internet keluar (*air-gapped ready*). |
| **Domain Context Pack (`knowledge/domain-pack/`)** | Katalog statis tabel `S_*`/`CX_*`, komponen Siebel 16, kamus NCX, & template referensi | Menjawab *"bagaimana caranya..."* secara presisi tanpa halusinasi sintaks Oracle 12c atau komponen Siebel 16. |
| **Non-DB Knowledge Automation** | Auto-Versioning SOP, Analisa Log Paste User, Auto Handover/Escalation Note, Auto SOP-Gap Detector | Menghadirkan nilai automasi nyata harian bagi tim kantor tanpa menyentuh database produksi. |
| **OpenDesign Standalone Web Portal** | Portal web mandiri (`opendesign-web-portal`) terpisah penuh dari `ncxall.my.id/dashboard` | Ruang layar penuh untuk Chat Triage, blok CLI/query referensi, pratinjau screenshot SOP, & Panel Admin SOP + SOP-Gap. |

---

## 4. Stack Teknologi Bertahap (3-Tier Progressive Rollout — 100% Self-Hosted)

### Fase 1 — Multimodal SOP RAG, Advisory Triage & Standalone Portal (Intranet Kantor)
| Lapisan | Komponen | Repositori / Standar | Peran |
| :--- | :--- | :--- | :--- |
| **Manifest, Domain & Harness** | `workspace.yaml`, `soul.md`, `knowledge/domain-pack/`, `CONSTRAINTS.md`, `AGENTS.md` | Git | Aturan tetap (*Zero Direct DB*), konteks statis Siebel 16/Oracle 12c, & *session continuity*. |
| **Document Ingestion (Mod 1)** | **Python 3.12** (`Docling` + Local `Qwen2.5-VL` + Command-Safe Chunker) | `DS4SD/docling` | Parse `.docx`/`.pdf`/`.xlsx`/`.pptx` & `domain-pack/`, jaga blok CLI/XML/SQL utuh, ekstrak & deskripsikan *screenshot* `before/after`. |
| **Hybrid Memory & RAG (Mod 2)** | **Rust** (`qdrant-client` + `rig-qdrant`) → **Qdrant** (`BAAI/bge-m3` + BM25 + `bge-reranker-v2-m3`) | `qdrant/qdrant` | Pencarian hibrida akurat + metadata temporal (`doc_version`, `valid_from`, `valid_until`, `is_active`, `segment`, `role_acl`). |
| **State, Auth & Assets** | **PostgreSQL 16** + **MinIO** | `minio/minio` | Checkpointer sesi Rust (`sqlx`), Office RBAC (`User Kantor` / `Admin SOP`), *SOP-Gap* log, *Immutable Audit Log*, & gambar SOP. |
| **Triage Engine & Non-DB Auto (Mod 3)** | **Rust** (`Axum` + `Rig` + `sqlx`) + Local Structured Router (+ **Jev** opsional `E1`) | `tokio-rs/axum`, `0xPlaygrounds/rig` | State machine 4-tahap, analisa log paste user, *Auto Handover Note*, *Auto SOP-Gap Detector*, & SSE Streaming API. |
| **Private LLM Gateway** | **LiteLLM** → **Ollama** (dev lokal) / **vLLM** (GPU Server Kantor) | `BerriAI/litellm`, `vllm-project/vllm` | Model Hugging Face privat (`Qwen3-14B/32B` — lihat [infra/HARDWARE-SIZING.md](infra/HARDWARE-SIZING.md)). |
| **Observability** | **Langfuse** (Self-Hosted) + OpenTelemetry | `langfuse/langfuse` | Trace *end-to-end* tiap sesi *triage* & latensi retrieval di intranet kantor. |
| **Frontend UI (Mod 4)** | **OpenDesign** Standalone Web Portal (`opendesign-web-portal`) | Standalone di repo ini | Portal Web AI intranet mandiri (terpisah dari `ncxall.my.id/dashboard`): Login Kantor, Chat Triage, Paste Log, Handover Note, & Panel Admin SOP/SOP-Gap. |

### Fase 2 — Hermes Continuous Self-Evaluation & Bi-Temporal Memory (Self-Hosted)
- **Graphiti** (`getzep/graphiti`) untuk *bi-temporal knowledge graph* tersinkron dengan invalidasi Qdrant.
- **Promptfoo + DeepEval** terhadap **Golden Benchmark 50–100 Kasus NCX** ([evals/README.md](evals/README.md)) (+ opsi `Jev Score` pada payload sintetis).
- **DSPy** (`stanfordnlp/dspy`) + *Session-Branch Git PR* (dilarang *auto-merge*, wajib approval Admin).
- **Redis Cache** (`allkeys-lru`) terpisah dari **Redis Queue** (`noeviction` + AOF).

### Fase 3 — Self-Hosted Knowledge & Workflow Automation (Non-DB)
- **Kestra / Temporal (Self-Hosted)** untuk *scheduled SOP freshness checks*, *batch knowledge audit*, & pembuatan laporan operasional berkala berbasis dokumen/log input (tetap **Zero Direct DB/Prod Touch** kecuali ada ADR baru yang secara eksplisit disetujui Owner & IT Security).

---

## 5. Mitigasi 7 Celah Kritis (Design 2.4)

1. **Zero Direct DB / Prod Execution (`ADR-002`):** Nol driver Oracle 12c & nol SSH runner di kode; AI hanya memberi referensi query/command siap salin lengkap dengan peringatan verifikasi manual.
2. **Split-Brain Context (SOP Basi):** Satu *ingestion pipeline* (Python `Docling` + Vision); semua chunk Qdrant wajib membawa `doc_version`, `valid_from`, `valid_until`, `is_active`, `segment`, `role_acl`. Upload revisi otomatis menandai versi lama `is_active=false`.
3. **Multimodal SOP & Siebel/Oracle Blind Spot:** Gambar tertanam diekstrak ke MinIO + dideskripsikan Vision-LLM lokal; ditambah `knowledge/domain-pack/` agar istilah & struktur Siebel 16 / Oracle 12c selalu akurat.
4. **Premature Verdict / Hallucinated Command:** Transisi ke `VERDICT` dikunci oleh *compile-time & runtime state guard* Rust + *Local Guided JSON* (atau Jev opsional `E1`) dan blok CLI/XML/SQL dilindungi *command-safe chunker* + *Hybrid BM25+Vector*.
5. **Auto-Merge & Judge Gaming (Loop Hermes):** `soul.md` *immutable*; perubahan `skills/*.md` wajib via Git PR + *Golden Benchmark* + *Admin Approval*.
6. **On-Prem Privacy & Optional Cloud Boundary (`E1`):** Default 100% offline/intranet; panggilan Jev opsional dibatasi keras oleh `CONSTRAINTS.md` Exception `E1` (hanya *redacted slot state / synthetic eval*, nol SOP mentah/IP/kredensial).
7. **Indirect Prompt Injection & Blind Observability:** Potongan log yang di-paste user diperlakukan sebagai *untrusted data*; semua sesi & `NO SOP MATCH` tercatat di *Immutable Audit Log* PostgreSQL + `trace_id` OTel ke Langfuse lokal.

---

## 6. Struktur Repositori (`c:/Users/Administrator/LLM`)

```text
LLM/
├── AGENTS.md                   # Peta kerja & harness rules untuk AI coding agent
├── CONSTRAINTS.md              # Kontrak kualitas terukur (Floor + Zero-DB + Python/Rust + E1)
├── DESIGN.md                   # Dokumen ini (Design 2.4 — On-Prem Siebel 16 / Oracle 12c Advisory)
├── PRD.md                      # Product Requirements Document (PRD 2.4)
├── feature_list.json           # Pelacakan fitur & bukti verifikasi per slice
├── progress.md                 # Log progres & status terakhir lintas sesi
├── init.ps1 / init.sh          # Skrip baseline health-check Windows & Bash
├── docs/
│   ├── intent/sop-triage-ai.md # Statement of Intent terkonfirmasi
│   ├── adr/                    # ADR-001 (Hybrid Python+Rust+Jev) & ADR-002 (On-Prem Zero-DB)
│   └── diagrams/               # Diagram Archify (Architecture & 4-Stage Lifecycle)
├── knowledge/
│   └── domain-pack/            # Katalog statis Siebel 16, Oracle 12c, & glosarium NCX (Read-Only)
├── spec/
│   ├── capability-map.md       # Peta 4 modul & urutan build (Phase 0)
│   └── SPEC-<module>.md        # Spesifikasi detail per modul (Phase 1)
├── tasks/
│   ├── plan.md                 # Rencana teknis (Phase 2)
│   └── todo.md                 # Daftar tugas vertical-slice (Phase 3)
├── evals/                      # Golden Benchmark 50-100 Kasus NCX (README + dataset + config)
├── infra/                      # HARDWARE-SIZING.md & Docker Compose On-Prem
├── src/                        # Kode Python (Modul #1: sop-ingestion — Docling + Vision)
├── crates/                     # Workspace Rust (Modul #2: sop-memory-rag, Modul #3: triage-engine-api)
├── web/                        # Standalone OpenDesign Web Portal (Modul #4)
└── tests/                      # Unit, integration, & RAG eval tests (TDD)
```
