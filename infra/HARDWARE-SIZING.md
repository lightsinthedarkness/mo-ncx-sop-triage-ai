# Hardware Sizing & On-Prem Deployment Guide (`infra/HARDWARE-SIZING.md`)

Panduan sizing server internal kantor (100% *intranet / on-prem first*) untuk menjalankan **NCX Triage & Internal Autonomous AI (Design 2.5 — 100% Pure Rust)** bagi tim operasional **Siebel 16 + Oracle 12c**.

> [!IMPORTANT]
> PC pengembangan lokal (`AMD Ryzen 5 5500U`, `16 GB RAM`, tanpa GPU NVIDIA) **hanya untuk development & unit test Modul #1–#4**. Untuk melayani user sekantor secara paralel (*concurrent chat + Vision captioning + hybrid RAG*), wajib menggunakan server/VM GPU internal kantor.

---

## 1. Pilihan Tier Hardware Server Kantor

| Tier | Kapasitas User Kantor | Spesifikasi Minimum Server | Model Lokal yang Dijalankan (`vLLM` / `Ollama`) | Catatan Operasional |
| :--- | :---: | :--- | :--- | :--- |
| **Tier A — Starter Kantor** | 5 – 15 user aktif | **1× GPU 24 GB VRAM** (RTX 3090 / RTX 4090 / NVIDIA L4 / A10G), CPU 8–16 core, **32–64 GB RAM**, NVMe SSD 500 GB | **LLM:** `Qwen3-14B` (AWQ / FP8, ~10–14 GB VRAM)<br>**Embed & Reranker:** `BAAI/bge-m3` + `bge-reranker-v2-m3` (CPU atau ~3 GB VRAM)<br>**Vision (on-demand saat admin upload SOP):** `Qwen2.5-VL-7B` | Cukup kuat untuk chat triage akurat + *structured JSON routing* offline. Vision dijalankan *batch/on-demand* saat ingestion agar tidak bentrok VRAM dengan chat. |
| **Tier B — Ideal Produksi Kantor** *(Recommended)* | 15 – 50 user aktif | **1× GPU 48 GB VRAM** (NVIDIA L40S / A6000) **atau 2× 24 GB VRAM**, CPU 16–32 core, **64–128 GB RAM**, NVMe SSD 1 TB | **LLM:** `Qwen3-32B` (AWQ / FP8, ~20–24 GB VRAM)<br>**Vision Always-On:** `Qwen2.5-VL-7B` (~8 GB VRAM)<br>**Embed & Reranker:** `bge-m3` + `bge-reranker-v2-m3` di GPU | Nol *model swapping*, TTFT ≤ 2–3 detik untuk multi-user serentak, akurasi *multi-turn triage* & pemahaman konteks Siebel 16 / Oracle 12c tertinggi. |

---

> [!NOTE]
> Angka VRAM, kapasitas user, dan latensi pada tabel ini adalah **estimasi yang wajib diukur** di hardware kantor. Kuantisasi bergantung engine: `mistral.rs` memakai ISQ/GGUF/UQFF; AWQ/FP8 relevan untuk `vLLM`. Reranker `bge-reranker-v2-m3` di CPU dapat melampaui target 800 ms; gunakan GPU atau kurangi jumlah kandidat bila terukur lambat.

## 2. Alokasi Layanan Self-Hosted (100% Intranet / LAN Kantor)

Seluruh komponen berjalan dalam jaringan internal kantor (`docker-compose.yml` di `infra/` saat tahap deployment):

| Service | Teknologi | Port Internal | Kebutuhan Resource | Catatan Keamanan |
| :--- | :--- | :---: | :--- | :--- |
| **Inference Engine** | **`mistral.rs` (`huggingface/candle`, Default Pure Rust)** *atau* sidecar Docker opsional `vLLM` / `Ollama` | `8000` | GPU VRAM (lihat tabel di atas) | `mistral.rs`: 1 binary Rust zero-Python (`response_format` via `llguidance`, kuantisasi ISQ/GGUF/UQFF); `vLLM` *(sidecar Python/PyTorch opsional)*: `guided_json`, AWQ/FP8 |
| **LLM Gateway** *(Opsional)* | `LiteLLM` *(sidecar Docker opsional bila perlu quota isolation multi-model)* | `4000` | 1 vCPU, 512 MB RAM | Dapat dilewati langsung ke `mistral.rs` untuk deployment **100% zero-Python**; Jev (`E1`) off secara default di mode *air-gapped* |
| **Vector Hybrid DB** | `Qdrant` (Dense `bge-m3` + Sparse BM25) | `6333` | 2–4 vCPU, 4–8 GB RAM | Volume persisten + snapshot backup harian; bila pakai `fastembed-rs`, pre-stage model & lib ONNX (`ort`) offline |
| **Relational & Audit DB** | `PostgreSQL 16` | `5432` | 2 vCPU, 2–4 GB RAM | Menyimpan session state, user RBAC, SOP Gap log, & Immutable Audit Log |
| **Screenshot Asset Store** | `MinIO` (S3-compatible) | `9000` | 1–2 vCPU, 1–2 GB RAM | Menyimpan *screenshot `before/after`* SOP |
| **Triage API & Orchestrator** | **Rust** (`Axum` + `Rig` + `sqlx`) | `8080` | 2 vCPU, < 256 MB RAM | **Zero Oracle 12c DB driver / Zero SSH exec** |
| **Ingestion Worker** | **Rust** (`crates/sop-ingestion`: `zip`/`quick-xml`/`calamine`/`oxidize-pdf`/`lopdf`/`image`) | Internal job / CLI | 2 vCPU, < 128 MB RAM | Streaming asset persistence + decompression-bomb limits (nol runtime Python) |
| **Web Portal UI** | **OpenDesign** Static Assets (`web/`, disajikan langsung oleh **Rust `Axum`**) | `443` (Reverse Proxy) | Static embedded/served | HTTPS internal kantor (nol server Node.js di produksi, terpisah penuh dari `ncxall.my.id/dashboard`) |
| **Observability** | `Langfuse` (Self-Hosted) + OTel | `3000` | 4+ vCPU, 8–16 GB RAM (Langfuse v3 butuh ClickHouse + Redis + blob storage; ukur ulang saat deploy) | Trace 100% lokal di intranet kantor |

---

## 2b. Backup, Pemulihan & Batas Beban

| Komponen | Backup | RPO / RTO target | Catatan |
| :--- | :--- | :--- | :--- |
| `PostgreSQL 16` (RBAC, sesi, audit log) | `pg_dump` harian + WAL archiving | RPO ≤ 24 jam (≤ 15 menit dengan WAL) / RTO ≤ 4 jam | Audit log append-only wajib ikut dan diverifikasi rantai hash-nya setelah restore. |
| `Qdrant` | Snapshot harian | RPO ≤ 24 jam / RTO ≤ 2 jam | Indeks dapat dibangun ulang dari dokumen sumber + `IngestResult`. |
| `MinIO` (screenshot) | Replikasi/`mc mirror` harian | RPO ≤ 24 jam | Sertakan status `review_status`. |
| Dokumen SOP sumber | Salinan terpisah di storage kantor | — | Sumber kebenaran untuk re-ingest. |

**Batas beban (nilai awal, disetel setelah Spike S3):** maks 3 sesi chat serentak per user, rate limit 30 request/menit per `user_id`, antrean ingestion Admin maks 2 dokumen paralel, ukuran paste log maks 200 KB, pemulihan diuji (*restore drill*) minimal per kuartal.

---

## 3. Aturan Jaringan & Air-Gapped Readiness
1. **Zero Egress Default:** Server kantor tetap beroperasi penuh (**100% fungsi chat, triage, ingestion, dan automasi pengetahuan**) meski akses internet keluar diblokir firewall kantor.
2. **Pre-Downloaded Model Weights:** Bobot model Hugging Face (`Qwen3-14B/32B`, `Qwen2.5-VL-7B`, `BAAI/bge-m3`, `BAAI/bge-reranker-v2-m3`) diunduh sekali ke storage internal / mirror kantor sebelum deployment.
3. **Zero Production DB Network Route:** VLAN/firewall server AI **tidak perlu dan tidak boleh** membuka port `1521` ke Oracle 12c produksi maupun port `22` ke server Siebel 16 produksi.
