# Statement of Intent: MO NCX SOP Triage AI (`sop-triage-ai`)

- **Status:** Confirmed by Owner (2026-11-26)
- **Workspace Backend:** `c:/Users/Administrator/LLM`
- **Workspace Frontend Integration:** `c:/Users/Administrator/web` (`https://ncxall.my.id/dashboard`)

## Confirmed Intent

- **Outcome:** Sistem **AI Konsultan & Triage SOP MO NCX** berbasis model *open-weight Reasoning + Vision* dari Hugging Face yang terintegrasi langsung ke `https://ncxall.my.id/dashboard` melalui tombol kapsul kecil di pojok kanan bawah (*hover* = melebar halus menampilkan status/identitas, *klik* = membuka *slide-over drawer* dengan opsi perbesar `[⤢]`, dimulai dengan *Guided SOP Empty State* pilihan segmen `EBIS / RETAIL / WIBS` serta indikator progres `① Interview → ② Analisa → ③ Konfirmasi → ④ Solusi SOP`).
- **User:** Seluruh rekan operasional **tim kantor MO NCX** (sebagai pengguna konsultasi *troubleshooting*) dan **Owner/Admin** (pengelola tunggal *upload*, pembaruan, dan penghapusan dokumen SOP resmi).
- **Why now:** Dokumen SOP operasional MO NCX terbagi ke dalam segmen (`SOP EBIS`, `SOP RETAIL`, `SOP WIBS`) dalam format campuran (`.docx`, `.pdf`, `.xlsx`, `.pptx`) berisi perintah CLI Linux/Siebel, konfigurasi XML/script, serta puluhan gambar *screenshot* teknis (*before/after*) yang rawan salah terap di server *Production* bila dicari manual tanpa verifikasi konteks masalah.
- **Success:**
  1. AI **dilarang** langsung menjatuhkan vonis solusi di giliran pertama saat informasi belum lengkap.
  2. AI menjalankan siklus wajib: **Interview Gali Fakta (segmen, environment, gejala/log, prasyarat) → Berpikir & Analisa SOP → Konfirmasi Analisa ke Pengguna → (Jika belum sesuai: balik bertanya mengerucut | Jika sesuai: keluarkan langkah resmi SOP + blok command utuh + cuplikan gambar/sumber file SOP)**.
  3. Setiap ada dokumen SOP baru atau revisi, Admin cukup melakukan *upload* file tanpa perlu membuat ribuan baris dataset *training* manual.
- **Constraint:**
  1. Seluruh dokumen SOP bersifat internal/privat — dilarang dikirim ke API AI komersial publik (OpenAI, Gemini Cloud, Anthropic, dsb.).
  2. Mesin inferensi LLM + Vision + *Hybrid Memory DB* dijalankan mandiri di **VM / VPS ber-GPU** dan dihubungkan secara aman ke Cloudflare Worker `ncxall.my.id`.
  3. Integrasi antarmuka pada repo `web` wajib mematuhi aturan desain *Midnight Iris* / palet terkunci, iterasi mockup via **MCP FigCraft**, larangan ekspos *secret*, serta verifikasi build & E2E sesuai `C:/Users/Administrator/web/AGENTS.md`.
- **Out of scope (Deferred to V2+):**
  1. Eksekusi otomatis perintah SSH langsung oleh AI ke server produksi Siebel/Linux.
  2. Pipeline *QLoRA fine-tuning* bobot model dengan ribuan pasang dataset manual di V1 (ditunda ke V2 hanya bila penyelarasan gaya wawancara tambahan dibutuhkan).
  3. Pembatasan hak baca SOP per sub-divisi (di V1 semua anggota tim MO NCX dapat berkonsultasi ke seluruh SOP, namun mutasi/upload SOP dikunci khusus Admin).
  4. Integrasi ke bot chat eksternal (WhatsApp, Telegram, Microsoft Teams).
