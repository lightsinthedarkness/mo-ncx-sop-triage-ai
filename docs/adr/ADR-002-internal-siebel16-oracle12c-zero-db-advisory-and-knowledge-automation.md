# ADR-002: Internal Office On-Prem First, Siebel 16 / Oracle 12c Domain Pack, & Zero-Direct-DB Advisory Automation

## Status
Accepted (Approved by Owner, 2026-11-27 — Module #1 ingestion implementation unified to Pure Rust by [ADR-003](ADR-003-pure-rust-backend-workspace.md); all Zero-Direct-DB, On-Prem First, Domain Pack, RBAC, Sizing, & Benchmark decisions remain active)

## Date
2026-11-27

## Context
Proyek `ykztir-ncx-ai` (Design 2.4 → **Design 2.5**) ditujukan **khusus untuk pengguna internal kantor operasional MO NCX** yang bekerja di atas ekosistem **Siebel CRM 16 + Oracle Database 12c**. Owner menegaskan batasan operasional yang ketat:
1. Sistem dipakai **hanya oleh user internal kantor** di jaringan internal (*intranet / on-prem first*).
2. AI **TIDAK boleh mengakses database secara langsung** — baik `UPDATE`/`DDL` maupun `SELECT` ke Oracle 12c, dan **TIDAK boleh mengeksekusi perintah langsung ke server produksi Siebel 16**.
3. AI berperan penuh sebagai **Advisor & Knowledge Automation Internal**: menjawab *"bagaimana caranya..."*, menganalisa gejala/potongan log yang ditempel/diunggah user di chat, mencocokkan dengan SOP aktif + domain Siebel 16 / Oracle 12c, menghasilkan langkah resmi + referensi query/command siap salin (dieksekusi manual oleh Engineer), serta menjalankan automasi berbasis pengetahuan (*knowledge & workflow automation*).

## Decision
1. **Hard Boundary — Zero Direct DB & Zero Prod Server Execution:**
   - Repositori dan runtime produksi **dilarang** memasang driver koneksi ke Oracle 12c (`SELECT`/`UPDATE`/`DDL`) maupun SSH/exec runner ke server Siebel 16 produksi (maupun memanggil `sqlplus`/`ssh` lewat subprocess).
   - Setiap referensi query SQL Oracle 12c atau command `srvrmgr`/Linux yang dihasilkan AI di tahap `VERDICT` wajib diberi label peringatan agar diverifikasi & dijalankan manual oleh Engineer di environment yang tepat.
2. **Non-DB Autonomous & Knowledge Automation Scope (Fase 1.5 – Fase 2):**
   - **Autonomous Multi-Step SOP Investigation:** AI secara mandiri memecah kendala user, mencari lintas dokumen SOP + deskripsi *screenshot `before/after`* + Domain Context Pack, serta menganalisa potongan log yang di-paste/di-upload manual oleh user di chat.
   - **Auto-Ingestion & Temporal Versioning:** Upload SOP baru/revisi otomatis mengekstrak blok CLI/XML + screenshot, menjalankan **Secret Scrubber**, dan menonaktifkan versi lama (`is_active=false`).
   - **Auto Handover / Escalation Note Generator:** Setelah `VERDICT`, AI dapat otomatis menyusun ringkasan investigasi (*Handover / Escalation Note*) siap tempel ke tiket internal kantor.
   - **Auto SOP-Gap Detector:** Ketika pertanyaan kendala Siebel 16 / Oracle 12c tidak memiliki SOP aktif yang cocok (`NO SOP MATCH`), sistem otomatis mencatat entri *SOP Gap* ke backlog Panel Admin agar SOP resmi dibuat.
   - **Self-Evolving Playbook Loop (Fase 2 — Hermes):** Mengevaluasi sesi yang gagal/rendah skornya dan mengusulkan perbaikan `skills/*.md` lewat *Session-Branch Git PR* + *Golden Benchmark* + *Admin Approval*.
3. **Domain Context Pack Siebel 16 & Oracle 12c (`knowledge/domain-pack/`):**
   - Menyimpan file pengetahuan **statis & read-only** (`.md` / `.yaml`, bukan koneksi DB, tanpa data/kredensial produksi): katalog tabel standar & custom (`S_ORDER`, `S_ASSET`, `S_SRV_REQ`, `CX_*`), daftar komponen `srvrmgr`, kamus singkatan NCX (`EBIS`, `RETAIL`, `WIBS`), serta *few-shot* template query/command referensi agar jawaban *"bagaimana caranya"* bebas halusinasi.
4. **100% Intranet / On-Prem First Architecture:**
   - Seluruh komponen inti (**Rust Workspace**, **Qdrant**, **`mistral.rs` / `Ollama` / `vLLM`**, **MinIO**, **PostgreSQL 16**, **Langfuse**, **OpenDesign Portal**) berjalan 100% di jaringan internal kantor tanpa ketergantungan internet.
   - **Jev (`TypeSafe AI`, `ADR-001` Exception `E1`)** diposisikan **opsional**: digunakan hanya jika koneksi eksternal diizinkan (payload teredaksi), dengan **Local Structured-Output Engine** (`mistral.rs` `response_format` via `llguidance` atau `vLLM` `guided_json`) sebagai *primary offline-ready router* dan *fallback* penuh.
   - Seluruh komponen automasi Fase 2–3 wajib **self-hosted on-prem** (tanpa ketergantungan SaaS cloud seperti E2B/Composio/Steel).
5. **Office User Identity, 2-Tier RBAC, & Immutable Chat Audit Log:**
   - Autentikasi user internal kantor (LDAP/AD kantor atau akun internal JWT) dengan 2 role jelas: **`user_kantor`** (`User Kantor`: Chat Triage, paste log, generate Handover Note) dan **`admin_sop`** (`Admin SOP`: Upload/Update/Arsip SOP, kelola backlog *SOP Gap*, review PR playbook).
   - Setiap sesi chat, sitasi SOP, dan status `VERDICT`/`NO SOP MATCH` dicatat ke *Immutable Audit Log* di PostgreSQL.
6. **Office GPU Hardware Sizing (`infra/HARDWARE-SIZING.md`):**
   - Mengunci standar minimal server kantor untuk model reasoning/advisory lokal (`14B–32B`): minimum **1× 24 GB VRAM** (`Qwen3-14B`), ideal **48 GB / 2×24 GB VRAM** (`Qwen3-32B` + `Qwen2.5-VL-7B`).
7. **Golden Benchmark Dataset 80–100 Kasus NCX (`evals/README.md`):**
   - Wajib lolos sebelum go-live ke tim kantor: 45% Q&A SOP Siebel 16/Oracle 12c, 25% *Multi-Turn Triage*, 20% *Versioning & Out-of-Scope*, dan 10% *Safety / Zero-DB Prompt-Injection Red-Team*.

## Alternatives Considered

### Direct Read-Only Oracle 12c & Siebel 16 MCP Connectors (`SELECT` + SSH `srvrmgr`)
- **Pros:** AI dapat langsung mengecek status order (`S_ORDER`) dan status komponen `srvrmgr` secara otomatis tanpa user menempel potongan log.
- **Cons:** Memerlukan pembukaan port `1521` (Oracle) & `22` (SSH Siebel) dari server AI ke jaringan produksi, manajemen kredensial DB/SSH di runtime AI, risiko beban query tidak disengaja di DB produksi, dan siklus persetujuan IT Security yang jauh lebih panjang.
- **Rejected:** Owner secara eksplisit menetapkan batas keras *Zero Direct DB Access* (baik `SELECT` maupun `UPDATE`/`DDL` dilarang) demi keamanan produksi maksimum.

### Cloud SaaS Autonomous Agent Platform (Kortix / E2B / Cloud LLM)
- **Pros:** Fitur automasi siap pakai tanpa mengelola GPU internal.
- **Cons:** Melanggar kebijakan privasi internal kantor (dokumen SOP NCX & data operasional tidak boleh keluar ke cloud publik) dan gagal beroperasi di jaringan intranet terbatas.
- **Rejected:** Digantikan arsitektur 100% *On-Prem / Intranet First*.

## Consequences
- **Modul #1 (`crates/sop-core` + `crates/sop-ingestion` — Rust per `ADR-003`):** Mendukung ingestion file SOP dan file `.md`/`.yaml` statis dari `knowledge/domain-pack/` dengan tag `source_type = domain_pack`, serta menyaring kredensial plaintext lewat **Secret Scrubber**.
- **Modul #2 (`crates/sop-memory-rag`) & Modul #3 (`crates/triage-engine`):** Diperkaya dengan *Office 2-Tier RBAC* (`user_kantor`, `admin_sop`), *Immutable Audit Log*, *Offline-First Local Structured Router* (+ Jev opsional), *Auto Handover Note*, dan *Auto SOP-Gap Detector*.
- **Keamanan Produksi:** Risiko modifikasi/gangguan ke Oracle 12c & Siebel 16 produksi dari AI = **0%** karena nol koneksi langsung secara arsitektural.
