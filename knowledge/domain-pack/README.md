# Domain Context Pack — Siebel CRM 16 & Oracle Database 12c (`knowledge/domain-pack/`)

Direktori ini menyimpan **file pengetahuan domain statis (read-only Markdown/YAML)** untuk memperkaya konteks retrieval AI agar mampu menjawab pertanyaan *"bagaimana caranya..."* seputar operasional **Siebel 16 + Oracle 12c** di **MO NCX** tanpa halusinasi nama tabel, komponen, atau istilah internal (per [ADR-002](../../docs/adr/ADR-002-internal-siebel16-oracle12c-zero-db-advisory-and-knowledge-automation.md)).

> [!CAUTION]
> **Hard Boundary (Zero Direct DB / Zero Production Secrets):**
> - Direktori ini **bukan** koneksi database — AI tidak pernah melakukan `SELECT` maupun `UPDATE` ke Oracle 12c.
> - **Dilarang keras** menyimpan kredensial, password keystore, TNS/IP produksi asli, atau data pelanggan nyata di sini. Gunakan hanya nama skema/struktur umum, definisi komponen, dan contoh template dengan placeholder (`<ORDER_NUM>`, `<SERVER_ALIAS>`).

---

## Struktur File yang Direncanakan (Diisi Bertahap oleh Tim MO NCX)

| File | Isi & Tujuan |
| :--- | :--- |
| `ncx-glossary.md` | Kamus istilah & singkatan internal NCX (`EBIS`, `RETAIL`, `WIBS`, `SC`, `MYIR`, status order, istilah bisnis & teknis) agar AI memahami terminologi tim kantor. |
| `siebel16-components.md` | Daftar komponen Siebel CRM 16 relevan (`eCommunicationsObjMgr_enu`, `EAIObjMgr_enu`, `WfProcMgr`, OHS/SWSE, Gateway) beserta peran fungsional & lokasi log generiknya. |
| `oracle12c-schema-catalog.md` | Katalog struktur tabel standar Siebel (`S_ORDER`, `S_ORDER_ITEM`, `S_ASSET`, `S_SRV_REQ`, `S_EVT_ACT`, `S_ORG_EXT`, `S_WFA_INST_LOG`) & deskripsi tabel custom relevan (`CX_*`) + relasi kunci (`ROW_ID`, `ORDER_ID`) untuk panduan analisa. |
| `verified-reference-templates.md` | Kumpulan *few-shot* contoh referensi query diagnostik Oracle 12c (sintaks valid 12c) & referensi perintah `srvrmgr` untuk **disalin dan dijalankan manual oleh Engineer** (selalu ditandai sebagai referensi non-eksekusi). |

Seluruh file di folder ini di-ingest ke Qdrant melalui **Modul #1 (`sop-ingestion`)** dengan tag segmen `GENERAL` dan tipe sumber `domain_pack` sehingga tersedia sebagai konteks pendukung resmi di setiap sesi triage.
