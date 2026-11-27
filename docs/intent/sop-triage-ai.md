# Statement of Intent: NCX Triage & Self-Evolving Autonomous AI (`ykztir-ncx-ai`)

- **Status:** Confirmed & Updated by Owner (2026-11-27 — Standalone OpenDesign Web Portal)
- **Workspace (Full-Stack Standalone):** `c:/Users/Administrator/LLM` (terpisah penuh dari `https://ncxall.my.id/dashboard`)

## Confirmed Intent

- **Outcome:** Sistem **NCX Triage & Self-Evolving Autonomous AI** berbasis model *open-weight Reasoning + Vision* dari Hugging Face dengan **Standalone Web App Mandiri berbasis OpenDesign** (`opendesign-web-portal`, mis. diakses di `ai.ncxall.my.id` atau langsung dari VPS — tidak dicampur ke `ncxall.my.id/dashboard`), dimulai dengan *Guided SOP Empty State* pilihan segmen `EBIS / RETAIL / WIBS` serta indikator progres `① Interview → ② Analisa → ③ Konfirmasi → ④ Solusi SOP`, lalu berkembang bertahap (3 Fase) menuju *Autonomous AI* modular.
- **User:** Seluruh rekan operasional **tim kantor NCX** (sebagai pengguna konsultasi *troubleshooting*) dan **Owner/Admin** (pengelola tunggal *upload*, pembaruan, dan penghapusan dokumen SOP resmi).
- **Why now:** Dokumen SOP operasional NCX terbagi ke dalam segmen (`SOP EBIS`, `SOP RETAIL`, `SOP WIBS`) dalam format campuran (`.docx`, `.pdf`, `.xlsx`, `.pptx`) berisi perintah CLI Linux/Siebel, konfigurasi XML/script, serta puluhan gambar *screenshot* teknis (*before/after*) yang rawan salah terap di server *Production* bila dicari manual tanpa verifikasi konteks masalah.
- **Success:**
  1. AI **dilarang** langsung menjatuhkan vonis solusi di giliran pertama saat informasi belum lengkap.
  2. AI menjalankan siklus wajib: **Interview Gali Fakta (segmen, environment, gejala/log, prasyarat) → Berpikir & Analisa SOP → Konfirmasi Analisa ke Pengguna → (Jika belum sesuai: balik bertanya mengerucut | Jika sesuai: keluarkan langkah resmi SOP + blok command utuh + cuplikan gambar/sumber file SOP)**.
  3. Setiap ada dokumen SOP baru atau revisi, Admin cukup melakukan *upload* file tanpa perlu membuat ribuan baris dataset *training* manual.
- **Constraint:**
  1. Seluruh dokumen SOP mentah bersifat internal/privat — dilarang dikirim ke API AI komersial publik (OpenAI, Gemini Cloud, Anthropic, dsb.). Pengecualian tunggal yang disetujui Owner diatur di [ADR-001](../adr/ADR-001-hybrid-python-rust-and-jev-orchestrator.md) & `CONSTRAINTS.md` Exception `E1`: **Jev (`TypeSafe AI`)** hanya boleh menerima *redacted metadata/slot state atau synthetic eval payload* (nol teks SOP mentah, IP, atau kredensial) dengan *fallback* ke Local LLM.
  2. Mesin inferensi LLM + Vision + *Hybrid Memory DB* dijalankan mandiri di **VM / VPS ber-GPU** dengan autentikasi Admin untuk mutasi SOP.
  3. Antarmuka dibangun sebagai **Standalone Web App Mandiri (OpenDesign)** di repo ini, mendukung desktop & mobile `390px` tanpa *overflow*, serta bebas *secret* ter-commit (`gitleaks` 0 leaks).
- **Out of scope (Deferred to Fase 2 / Fase 3 / V2+):**
  1. Eksekusi otomatis ke server produksi oleh AI di Fase 1 (masuk Fase 3 dengan sandbox + *Approvals Queue* `Allow/Ask/Block`).
  2. Pipeline *QLoRA fine-tuning* bobot model dengan ribuan pasang dataset manual di V1.
  3. Pembatasan hak baca SOP per sub-divisi di V1 (semua tim NCX dapat berkonsultasi ke seluruh SOP aktif; mutasi SOP dikunci khusus Admin).
  4. Integrasi ke bot chat pihak ketiga (WhatsApp, Telegram, Microsoft Teams).
