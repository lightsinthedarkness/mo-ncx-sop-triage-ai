# ADR-001: Hybrid Python (Module 1) + Rust (Modules 2–3) & Jev (`TypeSafe AI`) Orchestrator/Judge

## Status
Partially Superseded by [ADR-003](ADR-003-pure-rust-backend-workspace.md) (2026-11-27: Module #1 migrated from Python to 100% Pure Rust; Rust Modules #2–#3 & optional Jev `E1` contract remain active, refined as offline-first by [ADR-002](ADR-002-internal-siebel16-oracle12c-zero-db-advisory-and-knowledge-automation.md))

## Date
2026-11-27

## Context
Proyek `ykztir-ncx-ai` (Design 2.2 → 2.3) membutuhkan:
1. **Multimodal SOP Ingestion akurat** untuk `.docx`/`.pdf`/`.xlsx`/`.pptx` berisi tabel kompleks, blok CLI/XML, dan 20+ *screenshot `before/after`* (ekosistem terbaik berada di Python via `docling`).
2. **Backend Retrieval, State Machine 4-Tahap (`INTERVIEW → ANALYZE → CONFIRM → VERDICT`), & SSE Streaming berkinerja tinggi** dengan *compile-time type safety* dan jejak memori rendah.
3. **Decision Router & Evaluation Judge yang cepat dan terkalibrasi** (Owner telah memiliki `TYPESAFE_API_KEY` untuk **Jev / TypeSafe AI System One** `/v1/systemone`).

## Decision
1. **Modul #1 (`sop-ingestion`) tetap Python 3.12+ (`Docling` + Local Vision-LLM + Pydantic v2):** Bertugas sebagai *ingestion worker/CLI* yang menghasilkan JSON terstruktur `IngestResult` + aset gambar tersimpan di LocalFS/MinIO.
2. **Modul #2 (`sop-memory-rag`) & Modul #3 (`triage-engine-api`) dibangun dengan Rust (`Axum` + `Tokio` + `Rig` + `qdrant-client` + `sqlx`):**
   - Menangani *Qdrant Native Hybrid Search* (Dense `BAAI/bge-m3` + Sparse BM25 + temporal filter `is_active=true` + reranker), *4-Stage Triage State Machine* deterministik, PostgreSQL session persistence, dan SSE Streaming API.
3. **Jev (`TypeSafe AI` `/v1/systemone`, via `TYPESAFE_API_KEY`) berperan sebagai Decision Orchestrator Router & Evaluation Judge:**
   - **State-Transition Router (`Choice` primitive):** Memutuskan secara cepat dan terkalibrasi apakah konteks interview sudah cukup (`INTERVIEW` vs `ANALYZE`), apakah respons pengguna berarti setuju/menolak (`CONFIRM → VERDICT` vs balik ke `INTERVIEW`), dan klasifikasi segmen (`EBIS / RETAIL / WIBS / GENERAL`).
   - **Evaluation Judge (`Score` primitive — `jev-as-a-judge`):** Menilai kepatuhan terhadap *Zero-Premature-Verdict* dan kualitas alur triage pada dataset evaluasi/CI.
4. **Redacted-Payload Privacy Boundary (Wajib — Exception `E1` di `CONSTRAINTS.md`):**
   - Karena Jev adalah Cloud API (`console.typesafe.ai`), **dilarang keras** mengirim teks SOP mentah, *path* server sensitif, IP produksi, atau kredensial/password ke Jev.
   - Payload ke Jev hanya boleh berisi **ringkasan ter-redaksi / status slot / pertanyaan uji sintetis**. Seluruh isi penuh SOP dan generasi panduan langkah + command tetap berjalan **100% di Local/Private Hugging Face LLM (`Ollama`/`vLLM` via `LiteLLM`)**.
   - `TYPESAFE_API_KEY` wajib dibaca hanya dari environment variable (tidak pernah di-commit ke Git).

## Alternatives Considered

### Pure Python Full-Stack (Design 2.2 sebelumnya)
- **Pros:** Satu bahasa, ekosistem LangGraph/DeepEval native.
- **Cons:** Jejak RAM lebih tinggi, *type safety* hanya lewat static linter (`mypy`), dan keputusan transisi state bergantung pada LLM autoregresif generatif yang lebih lambat.

### 100% Pure Rust (termasuk Document Parsing)
- **Pros:** Satu binary Rust tanpa Python sama sekali.
- **Cons:** Belum ada library Rust setara `Docling` untuk parsing `.docx`/`.pdf` tabel kompleks + OCR + ekstraksi *screenshot* berurutan.
- **Rejected:** Memaksa parsing dokumen di Rust akan memperlambat Fase 1 secara drastis.

## Consequences

> [!WARNING]
> Poin "Modul #1" dan "Kontrak Antar-Bahasa" di bawah **usang** — digantikan [ADR-003](ADR-003-pure-rust-backend-workspace.md) (Modul #1 kini Rust; tidak ada kontrak lintas bahasa). Poin Modul #2/#3 dan kontrak Jev `E1` tetap berlaku.
- **Modul #1 (`sop-ingestion`):** Spec (`spec/SPEC-sop-ingestion.md`) & Plan (`tasks/plan.md`) tetap 100% utuh dan langsung siap masuk Phase 4 TDD (Python 3.12.10 sudah terpasang).
- **Modul #2 & #3:** Prasyarat `rustup` (`rustc` + `cargo` + `clippy`) perlu dipasang saat memulai Modul #2; kualitas kode Rust dikunci lewat `cargo clippy --all-targets -- -D warnings` dan `cargo test`.
- **Kontrak Antar-Bahasa:** JSON `IngestResult` (didefinisikan di `SPEC-sop-ingestion.md` §5) menjadi kontrak resmi lintas Python → Rust (diverifikasi via JSON Schema / `serde` structs).
- **Jev Contract Gotcha (tercatat dari riset sebelumnya):** Endpoint `/v1/systemone` mewajibkan field `model`, `questions` berbentuk MAP, dan format `criteria` berbeda per primitive (`Choice` = dict, `Score` = array); wajib diuji lewat mock unit test + *fallback* ke Local LLM bila Jev offline.
