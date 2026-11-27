# PRD.md — NCX Triage & Self-Evolving Autonomous AI Platform (PRD 2.3)

> [!NOTE]
> Dokumen ini berpasangan dengan [DESIGN.md](DESIGN.md) (**Design 2.3**) dan [ADR-001](docs/adr/ADR-001-hybrid-python-rust-and-jev-orchestrator.md), serta mengacu pada *Statement of Intent* di [docs/intent/sop-triage-ai.md](docs/intent/sop-triage-ai.md).

---

## 1. Visi Produk & Masalah yang Diselesaikan

Tim operasional **MO NCX** membutuhkan sistem AI internal privat (berbasis model *open-weight* Hugging Face di VM/GPU VPS) yang dimulai dari fondasi **Multimodal SOP Triage RAG** yang sangat akurat, lalu berkembang bertahap menjadi **Enterprise Self-Evolving Autonomous AI Platform** (arsitektur modular *vendor-neutral* berpola Hermes Two-Loop & Kortix Autonomous Workers):
1. **Fase 1 (Core RAG, Triage & Standalone Portal):** Membantu seluruh rekan tim kantor menyelesaikan kendala operasional (`EBIS`, `RETAIL`, `WIBS`) dengan alur disiplin **Interview → Berpikir & Analisa → Konfirmasi → Pengerucutan → Vonis Langkah & Command Resmi SOP**, melalui **Standalone OpenDesign Web Portal** (`opendesign-web-portal`, mis. `ai.ncxall.my.id` atau VPS — **terpisah penuh dari `https://ncxall.my.id/dashboard`**).
2. **Fase 2 (Continuous Self-Evaluation — Pola Hermes):** Mengevaluasi kualitas jawaban secara otomatis (**Jev `Score` judge** + Promptfoo/DeepEval), memperbarui memori temporal (**Graphiti**), dan mengusulkan perbaikan playbook `skills/*.md` lewat Git PR yang wajib lolos **Promptfoo** + persetujuan manusia.
3. **Fase 3 (Autonomous Execution — Pola Kortix):** Menambahkan eksekusi otonom *end-to-end* (coding sandbox **OpenHands**, otomasi browser **Browser Use**, konektor **Composio/MCP**, dan *Approvals Queue* **HumanLayer** `Allow/Ask/Block`).

---

## 2. Persona & Hak Akses

| Persona | Hak Akses (Fase 1) | Kebutuhan Utama |
| :--- | :--- | :--- |
| **Engineer / Tim MO NCX** | Akses **Standalone OpenDesign Web Portal** (`ai.ncxall.my.id` / VPS) ke seluruh SOP aktif (`EBIS`, `RETAIL`, `WIBS`). | Bantuan diagnosis masalah cepat & akurat lengkap dengan blok *command* siap salin + gambar langkah SOP. |
| **Admin / Owner** | Seluruh akses Engineer + **Panel Admin SOP** (upload, update versi, arsip/hapus dokumen SOP) berautentikasi PIN/Token. | Menjaga memori AI selalu merujuk ke versi SOP terbaru tanpa perlu *re-training* dataset manual. |

---

## 3. Kebutuhan Fungsional (Functional Requirements)

### FR-1: Multimodal SOP Ingestion & Versioning (Fase 1 — Python 3.12)
* Admin dapat mengunggah dokumen SOP (`.docx`, `.pdf`, `.xlsx`, `.pptx`, dan skrip/kode) dengan label segmen (`EBIS`, `RETAIL`, `WIBS`) dan nomor versi (`doc_version`).
* Jalur *parsing* dipisah secara cerdas:
  * Dokumen bisnis & tabel via **Docling** dengan *command-safe chunker* (blok CLI Linux, path `/opt/...`, tag XML dilarang terpotong di tengah).
  * Gambar *screenshot* tertanam (`before changes` / `after changes` / UI Siebel) diekstrak ke **MinIO / LocalFS** dan dideskripsikan secara teknis oleh **Vision-LLM lokal**, lalu ditautkan ke chunk langkahnya.
  * File kode/skrip via **AST / Tree-sitter**.
* Output diekspor sebagai JSON kontrak `IngestResult` yang dikonsumsi oleh Modul #2 (Rust).
* Ketika Admin mengunggah revisi SOP (`v1 → v2`), versi lama otomatis ditandai `is_active = false` (`valid_until = now`) di **Qdrant** (dan **Graphiti** di Fase 2) sehingga aturan basi tidak pernah muncul lagi.

### FR-2: Hybrid SOP Memory & Grounded Retrieval (Fase 1 — Rust)
* Pencarian memori memakai **Rust (`qdrant-client` + `rig-qdrant`)** terhadap **Qdrant Native Hybrid Search** (*Dense* `BAAI/bge-m3` + *Sparse* BM25) dilanjutkan **Cross-Encoder Reranker (`bge-reranker-v2-m3`)**.
* Setiap potongan hasil retrieval wajib mengembalikan sitasi lengkap: nama file SOP, segmen, versi, judul bab/langkah, dan URL aset gambar *screenshot* terkait (bila ada).
* Jika tidak ditemukan bukti SOP yang relevan di atas ambang skor, AI **wajib menyatakan tidak menemukan SOP terkait** dan dilarang mengarang langkah/command.

### FR-3: Deterministic 4-Stage SOP Triage Loop (Fase 1 — Rust Axum/Rig + Jev)
* Diatur oleh **Rust Triage State Machine (`Axum` + `Rig` + `sqlx`)** bersama **Jev (`TypeSafe AI`, `/v1/systemone`)** sebagai *calibrated `Choice` router* (berjalan dengan *Redacted-Payload Boundary* Exception `E1` + *fallback* ke Local LLM) dengan 4 tahap eksplisit:
  1. **`INTERVIEW`:** Menggali konteks wajib yang belum lengkap (segmen `EBIS/RETAIL/WIBS`, *environment* `Prod/CONS/SIT`, gejala/error log, prasyarat komponen). AI **dilarang** memberi vonis di tahap ini.
  2. **`ANALYZE`:** Melakukan *Hybrid Retrieval* ke memori SOP berdasarkan fakta terhimpun, memetakan akar masalah & kandidat prosedur resmi.
  3. **`CONFIRM`:** Menyajikan ringkasan analisa dan menanyakan konfirmasi pengguna (*"Apakah analisa ini sudah sesuai dengan kondisi di lapangan?"*). Jika pengguna menjawab **"Belum/Tidak sesuai"**, sistem kembali ke **`INTERVIEW`** untuk mengerucutkan konteks.
  4. **`VERDICT`:** Hanya dapat dicapai setelah konfirmasi **"Ya/Sesuai"**. Menampilkan langkah resmi berurutan, blok *command* utuh (tombol *copy*), gambar referensi SOP dari MinIO, dan sitasi dokumen resmi.

### FR-4: Standalone OpenDesign Web Portal (`opendesign-web-portal` — Fase 1)
* Antarmuka dibangun sebagai **Web App Mandiri berbasis OpenDesign** (mis. diakses di `ai.ncxall.my.id` atau langsung dari VM/VPS — **terpisah penuh dan tidak menyentuh `https://ncxall.my.id/dashboard`**).
* Fitur antarmuka utama:
  1. **Guided SOP Empty State:** Identitas AI khusus SOP NCX, indikator progres `① Interview → ② Analisa → ③ Konfirmasi → ④ Solusi SOP`, dan tombol pilih cepat segmen (`EBIS`, `RETAIL`, `WIBS`).
  2. **Workspace Chat Triage Layar Penuh:** Tampilan lega untuk membaca blok *command* Linux/XML (tombol 1-klik *copy*), pratinjau gambar *screenshot `before/after`* dari MinIO, dan sitasi nama file SOP.
  3. **Panel Admin SOP (PIN/Token Auth):** Halaman khusus Admin untuk *upload*, lihat daftar versi aktif/arsip, dan hapus dokumen SOP per segmen.
  4. **SSE Streaming:** Respons mengalir *real-time* dari **Rust `Axum` API** lewat HTTPS aman.

### FR-5: Continuous Self-Evaluation & Temporal Memory — Pola Hermes (Fase 2)
* **Loop 1** merekam 100% trace ke **Langfuse (OTel)**.
* **Loop 2** mengevaluasi 100% sesi gagal + 10–20% sesi sukses (termasuk **Jev `Score` judge** pada payload teredaksi/sintetis), memperbarui **Graphiti** (*bi-temporal memory* dengan *provenance* + *snapshot rollback*), serta mengusulkan perbaikan `skills/*.md` lewat **Session-Branch Git PR** (dioptimalkan **DSPy**).
* Setiap PR wajib lulus **Promptfoo** terhadap *Golden Holdout Dataset* + persetujuan manusia. File `soul.md` bersifat **immutable** oleh agent.

### FR-6: Autonomous Multi-Worker & Governance — Pola Kortix (Fase 3)
* Eksekusi otonom terjadwal/event-driven (**Kestra/Temporal**) dengan worker **OpenHands** (sandbox Daytona/E2B + *egress firewall*), **Browser Use** (Steel + *2FA Human Takeover*), dan **Composio/MCP**.
* Klasifikasi aksi `Allow / Ask / Block` di `workspace.yaml` ditegakkan oleh **AgentGateway** (CEL RBAC) + **HumanLayer** (*Approvals Queue*).

---

## 4. Kebutuhan Non-Fungsional (Non-Functional Requirements)

| Kategori | Target & Batasan Terukur |
| :--- | :--- |
| **Privasi & Keamanan** | 100% dokumen SOP mentah, embedding, vision, & generasi jawaban diproses lokal/privat (zero raw SOP ke cloud LLM); panggilan keputusan **Jev** dibatasi ketat oleh `CONSTRAINTS.md` Exception `E1` (*redacted metadata/slot state atau eval sintetis saja* + *local-LLM fallback*); *zero hardcoded secrets* (`gitleaks` = 0); mutasi Admin SOP wajib PIN/Token. |
| **Akurasi Triage & RAG** | *Zero-Premature-Verdict* = **100%**; *Citation Grounding / Faithfulness* ≥ **95%**; *Expired SOP Leakage* = **0%**. |
| **Performa** | TTFT (*Time to First Token*) ≤ **3 detik** di GPU VPS (`vLLM`); respons retrieval hybrid ≤ **800 ms**. |
| **Aksesibilitas & Responsive** | **Standalone OpenDesign Web Portal** wajib bebas *overflow* di desktop dan mobile `390px`, mendukung navigasi keyboard (`Esc` tutup modal/panel, `Enter` kirim) & kontras WCAG 2.2 AA. |
| **Observability & Isolasi** | 100% request memiliki `trace_id` OTel di Langfuse; Fase 2 memisahkan `redis-cache` vs `redis-queue` serta kuota LiteLLM *Prod vs Eval*. |

---

## 5. Roadmap Implementasi 3 Fase

* **Fase 1 — Multimodal SOP RAG, Triage Core & Standalone Web Portal (Prioritas Utama / Proyek RAG Pertama)**
  1. Modul `sop-ingestion` *(Python 3.12)*: Parser Docling + Vision Captioner + Command-Safe Chunker + MinIO/LocalFS Assets → JSON `IngestResult`.
  2. Modul `sop-memory-rag` *(Rust — `qdrant-client` + `rig-qdrant`)*: Qdrant Native Hybrid (`bge-m3` + BM25) + Reranker + Temporal Versioning.
  3. Modul `triage-engine-api` *(Rust — `Axum` + `Rig` + `sqlx` + **Jev Router/Judge**)*: 4-Stage Triage State Machine + Jev *redacted Choice/Score* (`ADR-001` / `E1`) + LiteLLM (`Ollama` ↔ `vLLM`) + PostgreSQL + Langfuse OTel + Admin Auth.
  4. Modul `opendesign-web-portal`: Web App Mandiri berbasis **OpenDesign** (terpisah penuh dari `ncxall.my.id/dashboard`) + SSE Streaming + QA E2E.
* **Fase 2 — Continuous Self-Evaluation & Bi-Temporal Memory**
  * Integrasi **Graphiti**, **Promptfoo + DeepEval + Jev `Score` Judge Golden Dataset**, **DSPy**, *Session-Branch Git PR*, & pemisahan **Redis Cache/Queue**.
* **Fase 3 — Best-of-Breed Autonomous Multi-Worker**
  * Integrasi **Kestra/Temporal**, **AgentGateway (CEL RBAC)**, **HumanLayer**, **OpenHands (Daytona/E2B)**, **Browser-Use (Steel)**, & **Reversible PII Tokenization**.
