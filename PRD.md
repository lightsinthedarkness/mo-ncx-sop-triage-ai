# PRD.md — NCX Triage & Internal Self-Evolving Autonomous AI Platform (PRD 2.4)

> [!NOTE]
> Dokumen ini berpasangan dengan [DESIGN.md](DESIGN.md) (**Design 2.4**), [ADR-001](docs/adr/ADR-001-hybrid-python-rust-and-jev-orchestrator.md), dan [ADR-002](docs/adr/ADR-002-internal-siebel16-oracle12c-zero-db-advisory-and-knowledge-automation.md), serta mengacu pada *Statement of Intent* di [docs/intent/sop-triage-ai.md](docs/intent/sop-triage-ai.md).

---

## 1. Visi Produk & Batasan Operasional

Tim operasional **MO NCX** (internal kantor berbasis **Siebel CRM 16 + Oracle Database 12c**) membutuhkan sistem **Local LLM Internal** yang berjalan 100% di jaringan kantor (*on-prem / intranet first*) untuk:
1. **Fase 1 (Core Multimodal RAG, 4-Stage Triage & Standalone Portal):** Menjawab pertanyaan *"bagaimana caranya..."* dari rekan kantor (`EBIS`, `RETAIL`, `WIBS`) sesuai konteks SOP aktif + **Domain Context Pack Siebel 16 / Oracle 12c** melalui alur disiplin **Interview → Berpikir & Analisa → Konfirmasi → Pengerucutan → Vonis Langkah, Referensi Query/Command, & Screenshot SOP** di **Standalone OpenDesign Web Portal** (terpisah penuh dari `https://ncxall.my.id/dashboard`).
2. **Fase 1.5 (Non-DB Knowledge & Workflow Automation):** Menjalankan automasi operasional harian yang aman tanpa menyentuh database — analisa potongan log yang di-paste/upload user di chat, **Auto Handover / Escalation Note Generator**, **Auto SOP-Gap Detector**, serta *auto-versioning* SOP.
3. **Fase 2–3 (Continuous Self-Evaluation & Self-Hosted Knowledge Automation):** Evaluasi berkala terhadap **Golden Benchmark 50–100 Kasus NCX** ([evals/README.md](evals/README.md)), memori bi-temporal (**Graphiti**), serta usulan pembaruan playbook `skills/*.md` lewat Git PR + *Admin Approval* — 100% *self-hosted on-prem*.

> [!IMPORTANT]
> **Hard Boundary (`ADR-002` — Zero Direct DB / Zero Prod Execution):**
> AI **TIDAK terhubung ke Oracle 12c** (baik `SELECT` maupun `UPDATE`/`DDL` dilarang) dan **TIDAK mengeksekusi perintah langsung ke server Siebel 16**. Semua referensi query SQL / command `srvrmgr`/Linux yang dihasilkan AI bersifat **panduan siap salin untuk dieksekusi manual oleh Engineer**.

---

## 2. Persona & Hak Akses (Office Identity & 2-Tier RBAC)

| Persona | Autentikasi & Hak Akses | Kebutuhan Utama |
| :--- | :--- | :--- |
| **User Kantor (Engineer / Tim MO NCX)** | Login internal kantor (LDAP/AD atau akun internal JWT). Akses Chat Triage ke seluruh SOP aktif (`EBIS`, `RETAIL`, `WIBS`), *paste/upload* potongan log error, dan *Generate Handover/Escalation Note*. | Jawaban *"bagaimana caranya..."* yang akurat sesuai SOP + konteks Siebel 16 / Oracle 12c, lengkap dengan blok command/query referensi siap salin & gambar langkah SOP. |
| **Admin SOP (Owner / PIC)** | Login Admin berhak penuh + **Panel Admin SOP** (upload, update versi, arsip/hapus dokumen SOP & `domain-pack/`), **Dashboard SOP-Gap**, serta *Approval* PR perbaikan playbook `skills/*.md`. | Menjaga memori AI selalu merujuk ke versi SOP terbaru, memantau celah SOP yang belum terdokumentasi, dan mengaudit riwayat sesi chat. |

---

## 3. Kebutuhan Fungsional (Functional Requirements)

### FR-1: Multimodal SOP & Domain Pack Ingestion + Versioning (Fase 1 — Python 3.12)
* Admin dapat mengunggah dokumen SOP (`.docx`, `.pdf`, `.xlsx`, `.pptx`, dan skrip/kode) dengan label segmen (`EBIS`, `RETAIL`, `WIBS`) dan nomor versi (`doc_version`), serta menyinkronkan file statis **Domain Context Pack** (`knowledge/domain-pack/` — katalog struktur tabel Siebel 16/Oracle 12c, komponen `srvrmgr`, kamus NCX).
* Jalur *parsing* dipisah secara cerdas:
  * Dokumen bisnis & tabel via **Docling** dengan *command-safe chunker* (blok CLI Linux, path `/opt/...`, query SQL, & tag XML dilarang terpotong di tengah).
  * Gambar *screenshot* tertanam (`before changes` / `after changes` / UI Siebel) diekstrak ke **MinIO / LocalFS** dan dideskripsikan secara teknis oleh **Vision-LLM lokal**, lalu ditautkan ke chunk langkahnya.
* Output diekspor sebagai JSON kontrak `IngestResult` yang dikonsumsi oleh Modul #2 (Rust).
* Ketika Admin mengunggah revisi SOP (`v1 → v2`), versi lama otomatis ditandai `is_active = false` (`valid_until = now`) di **Qdrant** sehingga aturan basi tidak pernah muncul lagi.

### FR-2: Hybrid SOP Memory & Grounded Retrieval (Fase 1 — Rust)
* Pencarian memori memakai **Rust (`qdrant-client` + `rig-qdrant`)** terhadap **Qdrant Native Hybrid Search** (*Dense* `BAAI/bge-m3` + *Sparse* BM25) dilanjutkan **Cross-Encoder Reranker (`bge-reranker-v2-m3`)**.
* Setiap potongan hasil retrieval wajib mengembalikan sitasi lengkap: nama file SOP, segmen, versi, judul bab/langkah, dan URL aset gambar *screenshot* terkait (bila ada).
* Jika tidak ditemukan bukti SOP yang relevan di atas ambang skor, AI **wajib menyatakan tidak menemukan SOP terkait (`NO SOP MATCH`)**, dilarang mengarang langkah/command, dan otomatis mencatat laporan **SOP-Gap**.

### FR-3: Deterministic 4-Stage SOP Triage Loop (Fase 1 — Rust Axum/Rig + Offline-First Router)
* Diatur oleh **Rust Triage State Machine (`Axum` + `Rig` + `sqlx`)** dengan **Local Structured-Output Router (`vLLM` Guided JSON)** sebagai *primary offline-ready engine* (plus **Jev `Choice`** opsional via Exception `E1` bila jaringan mengizinkan):
  1. **`INTERVIEW`:** Menggali konteks wajib yang belum lengkap (segmen `EBIS/RETAIL/WIBS`, *environment* `Prod/CONS/SIT`, gejala/potongan log, prasyarat komponen). AI **dilarang** memberi vonis di tahap ini.
  2. **`ANALYZE`:** Melakukan *Hybrid Retrieval* ke memori SOP + *Domain Context Pack* (dan menganalisa potongan log yang di-paste user), memetakan akar masalah & kandidat prosedur resmi.
  3. **`CONFIRM`:** Menyajikan ringkasan analisa dan menanyakan konfirmasi pengguna (*"Apakah analisa ini sudah sesuai dengan kondisi di lapangan?"*). Jika pengguna menjawab **"Belum/Tidak sesuai"**, sistem kembali ke **`INTERVIEW`** untuk mengerucutkan konteks.
  4. **`VERDICT`:** Hanya dapat dicapai setelah konfirmasi **"Ya/Sesuai"**. Menampilkan langkah resmi berurutan, blok *command* / referensi query utuh (tombol *copy* + label peringatan eksekusi manual), gambar referensi SOP dari MinIO, dan sitasi dokumen resmi.

### FR-4: Non-DB Knowledge Automation & Standalone OpenDesign Web Portal (`opendesign-web-portal` — Fase 1 / 1.5)
* Antarmuka dibangun sebagai **Web App Mandiri berbasis OpenDesign** di intranet kantor (mis. `ai.ncxall.my.id` / VPS — **terpisah penuh dan tidak menyentuh `https://ncxall.my.id/dashboard`**).
* Fitur utama portal & automasi pengetahuan:
  1. **Login Kantor & Guided SOP Empty State:** Login user kantor (`User Kantor` / `Admin SOP`), indikator progres `① Interview → ② Analisa → ③ Konfirmasi → ④ Solusi SOP`, dan tombol pilih cepat segmen (`EBIS`, `RETAIL`, `WIBS`).
  2. **Workspace Chat Triage + Paste/Upload Log:** Tampilan lega untuk membaca blok *command*/SQL referensi (tombol 1-klik *copy*), pratinjau gambar *screenshot `before/after`*, sitasi SOP, dan kolom tempel potongan log error Siebel/Oracle.
  3. **Auto Handover / Escalation Note:** Tombol 1-klik setelah `VERDICT` untuk menghasilkan ringkasan investigasi siap tempel ke tiket internal kantor.
  4. **Panel Admin SOP & SOP-Gap Backlog:** Halaman khusus Admin untuk upload/arsip versi SOP, melihat daftar pertanyaan `NO SOP MATCH` (*SOP-Gap*), dan meninjau audit log.
  5. **SSE Streaming:** Respons mengalir *real-time* dari **Rust `Axum` API** lewat HTTPS intranet aman.

### FR-5: Continuous Self-Evaluation & Self-Hosted Temporal Memory — Pola Hermes (Fase 2)
* **Loop 1** merekam 100% trace ke **Langfuse (Self-Hosted OTel)** & *Immutable Audit Log* PostgreSQL.
* **Loop 2** mengevaluasi sesi terhadap **Golden Benchmark 50–100 Kasus NCX** ([evals/README.md](evals/README.md)) memakai `Promptfoo` + `DeepEval` (+ opsi `Jev Score` pada payload sintetis), memperbarui **Graphiti** (*bi-temporal memory*), serta mengusulkan perbaikan `skills/*.md` lewat **Session-Branch Git PR** + *Admin Approval*. File `soul.md` bersifat **immutable**.

### FR-6: Self-Hosted Knowledge & Workflow Automation (Fase 3 — Non-DB)
* Automasi terjadwal/event-driven berbasis **Kestra / Temporal (Self-Hosted)** untuk *SOP freshness audit*, sinkronisasi dokumentasi internal, dan pelaporan operasional berkala (tetap patuh pada batas **Zero Direct DB / Zero Prod Execution**).

---

## 4. Kebutuhan Non-Fungsional (Non-Functional Requirements)

| Kategori | Target & Batasan Terukur |
| :--- | :--- |
| **Zero Direct DB & On-Prem Privacy** | **0** koneksi/driver ke Oracle 12c (`SELECT`/`UPDATE`/`DDL`) & **0** eksekusi ke server Siebel 16; 100% dokumen SOP mentah diproses lokal di intranet kantor; **Jev (`E1`)** opsional & hanya menerima *redacted state/synthetic eval* dengan *local fallback*; *zero hardcoded secrets* (`gitleaks` = 0). |
| **Akurasi Triage & RAG** | *Zero-Premature-Verdict* = **100%**; *Citation Grounding / Faithfulness* ≥ **95%**; *Expired SOP Leakage* = **0%**; lolos **Golden Benchmark 50–100 Kasus NCX** sebelum go-live kantor. |
| **Identitas & Audit** | 100% sesi chat & mutasi SOP terikat ke `user_id` kantor (RBAC 2-tier) dan tercatat di *Immutable Audit Log* PostgreSQL. |
| **Performa (Server GPU Kantor)** | TTFT (*Time to First Token*) ≤ **3 detik** di GPU Server (`vLLM` — lihat [infra/HARDWARE-SIZING.md](infra/HARDWARE-SIZING.md)); respons retrieval hybrid ≤ **800 ms**. |
| **Aksesibilitas & Responsive** | **Standalone OpenDesign Web Portal** wajib bebas *overflow* di desktop dan mobile `390px`, mendukung navigasi keyboard (`Esc`, `Enter`) & kontras WCAG 2.2 AA. |

---

## 5. Roadmap Implementasi 3 Fase

* **Fase 1 — Core RAG, Advisory Triage, Domain Pack & Standalone Web Portal (Prioritas Utama)**
  1. Modul `sop-ingestion` *(Python 3.12)*: Parser Docling + Vision Captioner + Command-Safe Chunker + `knowledge/domain-pack/` + MinIO/LocalFS → JSON `IngestResult`.
  2. Modul `sop-memory-rag` *(Rust — `qdrant-client` + `rig-qdrant`)*: Qdrant Native Hybrid (`bge-m3` + BM25) + Reranker + Temporal Versioning.
  3. Modul `triage-engine-api` *(Rust — `Axum` + `Rig` + `sqlx`)*: 4-Stage Triage State Machine + Offline-First Local Router (+ Jev opsional `E1`) + Office RBAC & Immutable Audit Log + *Auto Handover Note* + *Auto SOP-Gap Detector* + LiteLLM (`Ollama` ↔ `vLLM`) + Langfuse OTel.
  4. Modul `opendesign-web-portal`: Web App Mandiri berbasis **OpenDesign** (intranet, terpisah penuh dari `ncxall.my.id/dashboard`) + Login Kantor + Paste Log + Handover Note + Panel Admin SOP/SOP-Gap + SSE Streaming.
* **Fase 2 — Continuous Self-Evaluation & Bi-Temporal Memory (Self-Hosted)**
  * Integrasi **Graphiti**, **Golden Benchmark 50–100 Kasus NCX** (`Promptfoo` + `DeepEval` + opsi `Jev Score`), **DSPy**, *Session-Branch Git PR*, & pemisahan **Redis Cache/Queue**.
* **Fase 3 — Self-Hosted Knowledge & Workflow Automation (Non-DB)**
  * Integrasi **Kestra/Temporal (Self-Hosted)** untuk *SOP freshness audit* & pelaporan berkala internal (tetap **Zero Direct DB**).
