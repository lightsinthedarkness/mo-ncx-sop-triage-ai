# Statement of Intent: NCX Triage & Internal Self-Evolving Autonomous AI (`ykztir-ncx-ai`)

- **Status:** Confirmed & Updated by Owner (2026-11-27 — Design 2.5: 100% Pure Rust Backend + Standalone OpenDesign Portal + Internal Siebel 16 / Oracle 12c Zero-Direct-DB Advisory)
- **Workspace (Full-Stack Standalone):** `c:/Users/Administrator/LLM` (terpisah penuh dari `https://ncxall.my.id/dashboard`)

## Confirmed Intent

- **Outcome:** Sistem **Local LLM Internal Kantor (100% On-Prem / Intranet First)** berbasis model *open-weight Reasoning + Vision* dari Hugging Face untuk operasional **Siebel CRM 16 + Oracle Database 12c** (`EBIS`, `RETAIL`, `WIBS`) dengan **Standalone Web App Mandiri berbasis OpenDesign** (`opendesign-web-portal`, tidak dicampur ke `ncxall.my.id/dashboard`), dimulai dengan *Guided SOP Empty State* + indikator progres `① Interview → ② Analisa → ③ Konfirmasi → ④ Solusi SOP`, serta automasi berbasis pengetahuan (*Non-DB Knowledge Automation*).
- **User:** **Khusus pengguna internal kantor MO NCX** dengan login kantor 2-tier RBAC: **`User Kantor`** (konsultasi troubleshooting, paste potongan log, generate *Handover/Escalation Note*) dan **`Admin SOP`** (pengelola upload/revisi/arsip SOP, `domain-pack/`, backlog *SOP-Gap*, dan approval playbook).
- **Why now:** Dokumen SOP operasional NCX (`SOP EBIS`, `SOP RETAIL`, `SOP WIBS`) dalam format campuran (`.docx`, `.pdf`, `.xlsx`, `.pptx`) berisi perintah CLI Linux/`srvrmgr`, referensi query Oracle 12c, konfigurasi XML, serta puluhan gambar *screenshot* teknis (*before/after*) yang rawan salah terap di server *Production* bila dicari manual tanpa verifikasi konteks masalah.
- **Success:**
  1. AI **dilarang** langsung menjatuhkan vonis solusi di giliran pertama saat informasi belum lengkap.
  2. AI menjalankan siklus wajib: **Interview Gali Fakta → Berpikir & Analisa SOP (+ Domain Context Pack Siebel 16/Oracle 12c & potongan log user) → Konfirmasi Analisa ke Pengguna → (Belum sesuai: balik bertanya mengerucut | Sesuai: keluarkan panduan resmi *"bagaimana caranya"*, blok command/query referensi siap salin + gambar & sitasi SOP)**.
  3. Setiap ada dokumen SOP baru atau revisi, Admin cukup *upload* file tanpa *re-training* manual; pertanyaan tanpa SOP otomatis tercatat sebagai *SOP-Gap*.
  4. Lulus **Golden Benchmark 80–100 Kasus Nyata NCX** sebelum dipakai sekantor.
- **Constraint:**
  1. **Zero Direct DB / Zero Prod Execution (`ADR-002`):** AI **TIDAK terhubung ke Oracle 12c** (baik `SELECT` maupun `UPDATE`/`DDL` dilarang) dan **TIDAK mengeksekusi perintah ke server Siebel 16**. AI hanya memberi informasi, analisa, panduan *"bagaimana caranya"*, dan referensi query/command untuk dieksekusi manual oleh Engineer.
  2. **100% Intranet / On-Prem First:** Seluruh dokumen SOP mentah & inferensi LLM/Vision/Qdrant dijalankan mandiri di server GPU internal kantor (`vLLM`/`Ollama`). Pengecualian opsional tunggal yang disetujui Owner diatur di [ADR-001](../adr/ADR-001-hybrid-python-rust-and-jev-orchestrator.md) & `CONSTRAINTS.md` Exception `E1`: **Jev (`TypeSafe AI`)** hanya boleh menerima *redacted metadata/slot state atau synthetic eval payload* dengan *offline local-LLM fallback* penuh.
  3. Antarmuka dibangun sebagai **Standalone Web App Mandiri (OpenDesign)** di repo ini, mendukung desktop & mobile `390px` tanpa *overflow*, serta bebas *secret* ter-commit (`gitleaks` 0 leaks).
- **Out of scope (Strictly Prohibited / Deferred):**
  1. **Koneksi langsung ke Database Oracle 12c (`SELECT` / `UPDATE` / `DDL`) maupun eksekusi SSH langsung ke server Siebel 16 produksi** — **DILARANG secara arsitektural (`ADR-002`)**.
  2. Pipeline *QLoRA fine-tuning* bobot model di V1 (digantikan RAG + `knowledge/domain-pack/`).
  3. Integrasi ke bot chat publik/pihak ketiga (WhatsApp, Telegram, Microsoft Teams).
