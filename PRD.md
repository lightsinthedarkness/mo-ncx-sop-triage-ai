# PRD.md — NCX Triage & Self-Evolving Autonomous AI Platform (PRD 2.2)

> [!NOTE]
> Dokumen ini berpasangan dengan [DESIGN.md](DESIGN.md) (**Design 2.2**) dan mengacu pada *Statement of Intent* di [docs/intent/sop-triage-ai.md](docs/intent/sop-triage-ai.md).

---

## 1. Visi Produk & Masalah yang Diselesaikan

Tim operasional **MO NCX** membutuhkan sistem AI internal privat (berbasis model *open-weight* Hugging Face di VM/GPU VPS) yang dimulai dari fondasi **Multimodal SOP Triage RAG** yang sangat akurat, lalu berkembang bertahap menjadi **Enterprise Self-Evolving Autonomous AI Platform** (bergaya Kortix AI + Hermes Two-Loop):
1. **Fase 1 (Core RAG & Triage):** Membantu seluruh rekan tim kantor menyelesaikan kendala operasional (`EBIS`, `RETAIL`, `WIBS`) dengan alur disiplin **Interview → Berpikir & Analisa → Konfirmasi → Pengerucutan → Vonis Langkah & Command Resmi SOP**, langsung dari Live Chat di **`https://ncxall.my.id/dashboard`**.
2. **Fase 2 (Continuous Self-Evaluation — Pola Hermes):** Mengevaluasi kualitas jawaban secara otomatis, memperbarui memori temporal (**Graphiti**), dan mengusulkan perbaikan playbook `skills/*.md` lewat Git PR yang wajib lolos **Promptfoo** + persetujuan manusia.
3. **Fase 3 (Autonomous Execution — Pola Kortix):** Menambahkan eksekusi otonom *end-to-end* (coding sandbox **OpenHands**, otomasi browser **Browser Use**, konektor **Composio/MCP**, dan *Approvals Queue* **HumanLayer** `Allow/Ask/Block`).

---

## 2. Persona & Hak Akses

| Persona | Hak Akses (Fase 1) | Kebutuhan Utama |
| :--- | :--- | :--- |
| **Engineer / Tim MO NCX** | Akses Live Chat Triage di `ncxall.my.id/dashboard` ke seluruh SOP aktif (`EBIS`, `RETAIL`, `WIBS`). | Bantuan diagnosis masalah cepat & akurat lengkap dengan blok *command* siap salin + gambar langkah SOP. |
| **Admin / Owner** | Seluruh akses Engineer + **Panel Admin SOP** (upload, update versi, arsip/hapus dokumen SOP) berautentikasi PIN/Token. | Menjaga memori AI selalu merujuk ke versi SOP terbaru tanpa perlu *re-training* dataset manual. |

---

## 3. Kebutuhan Fungsional (Functional Requirements)

### FR-1: Multimodal SOP Ingestion & Versioning (Fase 1)
* Admin dapat mengunggah dokumen SOP (`.docx`, `.pdf`, `.xlsx`, `.pptx`, dan skrip/kode) dengan label segmen (`EBIS`, `RETAIL`, `WIBS`) dan nomor versi (`doc_version`).
* Jalur *parsing* dipisah secara cerdas:
  * Dokumen bisnis & tabel via **Docling** dengan *command-safe chunker* (blok CLI Linux, path `/opt/...`, tag XML dilarang terpotong di tengah).
  * Gambar *screenshot* tertanam (`before changes` / `after changes` / UI Siebel) diekstrak ke **MinIO** dan dideskripsikan secara teknis oleh **Vision-LLM lokal**, lalu ditautkan ke chunk langkahnya.
  * File kode/skrip via **AST / Tree-sitter**.
* Ketika Admin mengunggah revisi SOP (`v1 → v2`), versi lama otomatis ditandai `is_active = false` (`valid_until = now`) di **Qdrant** (dan **Graphiti** di Fase 2) sehingga aturan basi tidak pernah muncul lagi.

### FR-2: Hybrid SOP Memory & Grounded Retrieval (Fase 1)
* Pencarian memori memakai **Qdrant Native Hybrid Search** (*Dense* `BAAI/bge-m3` + *Sparse* BM25) dilanjutkan **Cross-Encoder Reranker (`bge-reranker-v2-m3`)**.
* Setiap potongan hasil retrieval wajib mengembalikan sitasi lengkap: nama file SOP, segmen, versi, judul bab/langkah, dan URL aset gambar *screenshot* terkait (bila ada).
* Jika tidak ditemukan bukti SOP yang relevan di atas ambang skor, AI **wajib menyatakan tidak menemukan SOP terkait** dan dilarang mengarang langkah/command.

### FR-3: Deterministic 4-Stage SOP Triage Loop (Fase 1)
* Diatur oleh **LangGraph State Machine** dengan 4 tahap eksplisit:
  1. **`INTERVIEW`:** Menggali konteks wajib yang belum lengkap (segmen `EBIS/RETAIL/WIBS`, *environment* `Prod/CONS/SIT`, gejala/error log, prasyarat komponen). AI **dilarang** memberi vonis di tahap ini.
  2. **`ANALYZE`:** Melakukan *Hybrid Retrieval* ke memori SOP berdasarkan fakta terhimpun, memetakan akar masalah & kandidat prosedur resmi.
  3. **`CONFIRM`:** Menyajikan ringkasan analisa dan menanyakan konfirmasi pengguna (*"Apakah analisa ini sudah sesuai dengan kondisi di lapangan?"*). Jika pengguna menjawab **"Belum/Tidak sesuai"**, sistem kembali ke **`INTERVIEW`** untuk mengerucutkan konteks.
  4. **`VERDICT`:** Hanya dapat dicapai setelah konfirmasi **"Ya/Sesuai"**. Menampilkan langkah resmi berurutan, blok *command* utuh (tombol *copy*), gambar referensi SOP dari MinIO, dan sitasi dokumen resmi.

### FR-4: OpenDesign Live Chat UI di `ncxall.my.id/dashboard` (Fase 1)
* Komponen UI diiterasi terlebih dahulu menggunakan **OpenDesign** (pratinjau HTML/CSS/JS nyata selaras tema *Midnight Iris* & palet terkunci [AGENTS.md](file:///C:/Users/Administrator/web/AGENTS.md)) sebelum diintegrasikan ke `meadow-dashboard.html`.
* Interaksi 3 tahap:
  1. **Idle:** Tombol kapsul kaca kecil di pojok kanan bawah (tidak menghalangi KPI/tabel).
  2. **Hover (~150ms):** Melebar halus (*Hover-Peek Pill*) menampilkan status & label SOP AI (tidak membuka panel besar secara tidak sengaja).
  3. **Klik:** Membuka *Slide-Over Drawer* (~420px di kanan) dengan tombol perbesar `[⤢]` (*Full Workspace*) untuk membaca blok *command* panjang, gambar *screenshot*, serta tab **Admin Upload SOP**.
* Layar pembuka (*Guided Empty State*) menampilkan identitas AI khusus SOP MO NCX, indikator tahap `① Interview → ② Analisa → ③ Konfirmasi → ④ Solusi SOP`, dan tombol pilih cepat segmen (`EBIS`, `RETAIL`, `WIBS`).
* Komunikasi UI ↔ Backend melalui **Cloudflare Worker** (`/api/sop-ai/*`) dengan *SSE Streaming* menuju VM/GPU VPS via HTTPS terproteksi.

### FR-5: Continuous Self-Evaluation & Temporal Memory — Pola Hermes (Fase 2)
* **Loop 1** merekam 100% trace ke **Langfuse (OTel)**.
* **Loop 2** mengevaluasi 100% sesi gagal + 10–20% sesi sukses, memperbarui **Graphiti** (*bi-temporal memory* dengan *provenance* + *snapshot rollback*), serta mengusulkan perbaikan `skills/*.md` lewat **Session-Branch Git PR** (dioptimalkan **DSPy**).
* Setiap PR wajib lulus **Promptfoo** terhadap *Golden Holdout Dataset* + persetujuan manusia. File `soul.md` bersifat **immutable** oleh agent.

### FR-6: Autonomous Multi-Worker & Governance — Pola Kortix (Fase 3)
* Eksekusi otonom terjadwal/event-driven (**Kestra/Temporal**) dengan worker **OpenHands** (sandbox Daytona/E2B + *egress firewall*), **Browser Use** (Steel + *2FA Human Takeover*), dan **Composio/MCP**.
* Klasifikasi aksi `Allow / Ask / Block` di `workspace.yaml` ditegakkan oleh **AgentGateway** (CEL RBAC) + **HumanLayer** (*Approvals Queue*).

---

## 4. Kebutuhan Non-Fungsional (Non-Functional Requirements)

| Kategori | Target & Batasan Terukur |
| :--- | :--- |
| **Privasi & Keamanan** | 100% dokumen SOP diproses secara lokal/privat (zero cloud LLM API untuk data SOP); *zero hardcoded secrets* di repo; mutasi Admin SOP wajib PIN/Token. |
| **Akurasi Triage & RAG** | *Zero-Premature-Verdict* = **100%**; *Citation Grounding / Faithfulness* ≥ **95%**; *Expired SOP Leakage* = **0%**. |
| **Performa** | TTFT (*Time to First Token*) ≤ **3 detik** di GPU VPS (`vLLM`); respons retrieval hybrid ≤ **800 ms**. |
| **Aksesibilitas & Responsive** | Live Chat Drawer wajib bebas *overflow* di desktop dan mobile `390px`, mendukung navigasi keyboard (`Esc` tutup, `Enter` kirim). |
| **Observability & Isolasi** | 100% request memiliki `trace_id` OTel di Langfuse; Fase 2 memisahkan `redis-cache` vs `redis-queue` serta kuota LiteLLM *Prod vs Eval*. |

---

## 5. Roadmap Implementasi 3 Fase

* **Fase 1 — Multimodal SOP RAG & Triage Core + Live Chat Dashboard (Prioritas Utama / Proyek RAG Pertama)**
  1. Modul `sop-ingestion`: Parser Docling + Vision Captioner + Command-Safe Chunker + MinIO Assets.
  2. Modul `sop-memory-rag`: Qdrant Native Hybrid (`bge-m3` + BM25) + Reranker + Temporal Versioning.
  3. Modul `triage-engine-api`: FastAPI + LangGraph 4-Stage Triage + LiteLLM (`Ollama` ↔ `vLLM`) + PostgreSQL + Langfuse OTel + Admin Auth.
  4. Modul `dashboard-live-chat`: Desain via **OpenDesign** → Integrasi `meadow-dashboard.html` + proxy `cloudflare/worker.js` + QA E2E.
* **Fase 2 — Hermes Continuous Evaluation & Temporal Graph**
  * Integrasi **Graphiti**, **Promptfoo Golden Dataset**, **DSPy**, *Session-Branch Git PR*, & pemisahan **Redis Cache/Queue**.
* **Fase 3 — Kortix-Style Autonomous Multi-Worker**
  * Integrasi **Kestra/Temporal**, **AgentGateway (CEL RBAC)**, **HumanLayer**, **OpenHands (Daytona/E2B)**, **Browser Use (Steel)**, & **Reversible PII Tokenization**.
