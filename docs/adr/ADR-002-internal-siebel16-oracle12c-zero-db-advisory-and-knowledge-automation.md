# ADR-002: Internal Office On-Prem First, Siebel 16 / Oracle 12c Domain Pack, & Zero-Direct-DB Advisory Automation

## Status
Accepted (Approved by Owner, 2026-11-27)

## Date
2026-11-27

## Context
Proyek `ykztir-ncx-ai` (Design 2.3 → **Design 2.4**) ditujukan **khusus untuk pengguna internal kantor operasional MO NCX** yang bekerja di atas ekosistem **Siebel CRM 16 + Oracle Database 12c**. Owner menegaskan batasan operasional yang ketat:
1. Sistem dipakai **hanya oleh user internal kantor** di jaringan internal (*intranet / on-prem first*).
2. AI **TIDAK boleh mengakses database secara langsung** — baik `UPDATE`/`DDL` maupun `SELECT` ke Oracle 12c, dan **TIDAK boleh mengeksekusi perintah langsung ke server produksi Siebel 16**.
3. AI berperan penuh sebagai **Advisor & Knowledge Automation Internal**: menjawab *"bagaimana caranya..."*, menganalisa gejala/potongan log yang ditempel/diunggah user di chat, mencocokkan dengan SOP aktif + domain Siebel 16 / Oracle 12c, menghasilkan langkah resmi + referensi query/command siap salin (dieksekusi manual oleh Engineer), serta menjalankan automasi berbasis pengetahuan (*knowledge & workflow automation*).

## Decision
1. **Hard Boundary — Zero Direct DB & Zero Prod Server Execution:**
   - Repositori dan runtime produksi **dilarang** memasang driver koneksi ke Oracle 12c (`SELECT`/`UPDATE`/`DDL`) maupun SSH/exec runner ke server Siebel 16 produksi.
   - Setiap referensi query SQL Oracle 12c atau command `srvrmgr`/Linux yang dihasilkan AI di tahap `VERDICT` wajib diberi label peringatan agar diverifikasi & dijalankan manual oleh Engineer di environment yang tepat.
2. **Non-DB Autonomous & Knowledge Automation Scope (Fase 1.5 – Fase 2):**
   - **Autonomous Multi-Step SOP Investigation:** AI secara mandiri memecah kendala user, mencari lintas dokumen SOP + deskripsi *screenshot `before/after`* + Domain Context Pack, serta menganalisa potongan log yang di-paste/di-upload manual oleh user di chat.
   - **Auto-Ingestion & Temporal Versioning:** Upload SOP baru/revisi otomatis mengekstrak blok CLI/XML + screenshot dan menonaktifkan versi lama (`is_active=false`).
   - **Auto Handover / Escalation Note Generator:** Setelah `VERDICT`, AI dapat otomatis menyusun ringkasan investigasi (*Handover / Escalation Note*) siap tempel ke tiket internal kantor.
   - **Auto SOP-Gap Detector:** Ketika pertanyaan kendala Siebel 16 / Oracle 12c tidak memiliki SOP aktif yang cocok (`NO SOP MATCH`), sistem otomatis mencatat entri *SOP Gap* ke backlog Panel Admin agar SOP resmi dibuat.
   - **Self-Evolving Playbook Loop (Fase 2 — Hermes):** Mengevaluasi sesi yang gagal/rendah skornya dan mengusulkan perbaikan `skills/*.md` lewat *Session-Branch Git PR* + *Golden Benchmark* + *Admin Approval*.
3. **Domain Context Pack Siebel 16 & Oracle 12c (`knowledge/domain-pack/`):**
   - Menyimpan file pengetahuan **statis & read-only** (bukan koneksi DB, tanpa data/kredensial produksi): katalog tabel standar & custom (`S_ORDER`, `S_ASSET`, `S_SRV_REQ`, `CX_*`), daftar komponen `srvrmgr`, kamus singkatan NCX (`EBIS`, `RETAIL`, `WIBS`), serta *few-shot* template query/command referensi agar jawaban *"bagaimana caranya"* bebas halusinasi.
4. **100% Intranet / On-Prem First Architecture:**
   - Seluruh komponen inti (**Python Docling**, **Rust Axum/Rig + Qdrant**, **vLLM/Ollama**, **MinIO**, **PostgreSQL**, **Langfuse**, **OpenDesign Portal**) berjalan 100% di jaringan internal kantor tanpa ketergantungan internet.
   - **Jev (`TypeSafe AI`, `ADR-001` Exception `E1`)** diposisikan **opsional**: digunakan hanya jika koneksi eksternal diizinkan (payload teredaksi), dengan **Local Structured-Output Engine (`vLLM` Guided JSON)** sebagai *primary offline-ready router* dan *fallback* penuh.
   - Seluruh komponen automasi Fase 2–3 wajib **self-hosted on-prem** (tanpa ketergantungan SaaS cloud seperti E2B/Composio/Steel).
5. **Office User Identity, 2-Tier RBAC, & Immutable Chat Audit Log:**
   - Autentikasi user internal kantor (LDAP/AD kantor atau akun internal JWT) dengan 2 role jelas: **`User Kantor`** (Chat Triage, paste log, generate Handover Note) dan **`Admin SOP`** (Upload/Update/Arsip SOP, kelola backlog *SOP Gap*, review PR playbook).
   - Setiap sesi chat, sitasi SOP, dan status `VERDICT`/`NO SOP MATCH` dicatat ke *Immutable Audit Log* di PostgreSQL.
6. **Office GPU Hardware Sizing (`infra/HARDWARE-SIZING.md`):**
   - Mengunci standar minimal server kantor untuk model tool-calling/reasoning lokal (`14B–32B` via `vLLM`): minimum **1× 24 GB VRAM** (`Qwen3-14B`), ideal **48 GB / 2×24 GB VRAM** (`Qwen3-32B` + `Qwen2.5-VL-7B`).
7. **Golden Benchmark Dataset 50–100 Kasus NCX (`evals/README.md`):**
   - Wajib lolos sebelum go-live ke tim kantor: 45% Q&A SOP Siebel 16/Oracle 12c, 25% *Multi-Turn Triage*, 20% *Versioning & Out-of-Scope*, dan 10% *Safety / Prompt-Injection Red-Team*.

## Consequences
- **Modul #1 (`sop-ingestion` — Python 3.12):** Tetap **100% utuh** tanpa perubahan breaking; kini juga mendukung ingestion file statis dari `knowledge/domain-pack/`.
- **Modul #2 (`sop-memory-rag`) & Modul #3 (`triage-engine-api` — Rust):** Diperkaya dengan *Office Auth/RBAC*, *Immutable Audit Log*, *Offline-First Local Structured Router* (+ Jev opsional), *Auto Handover Note*, dan *Auto SOP-Gap Detector*.
- **Keamanan Produksi:** Risiko modifikasi/gangguan ke Oracle 12c & Siebel 16 produksi dari AI = **0%** karena nol koneksi langsung secara arsitektural.
