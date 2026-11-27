# Capability Map: MO NCX SOP Triage AI (`sop-triage-ai`) — Fase 1 Core

- **Design Reference:** [DESIGN.md](../DESIGN.md) (Design 2.3 — Hybrid Python + Rust + Jev)
- **ADR Reference:** [ADR-001](../docs/adr/ADR-001-hybrid-python-rust-and-jev-orchestrator.md)
- **PRD Reference:** [PRD.md](../PRD.md) (PRD 2.3)
- **Status:** Approved Phase 0 Baseline (Fase 1 of 3-Tier Progressive Rollout)

## Module Table

| Module id | Stack | Responsibility | Depends on |
| :--- | :--- | :--- | :--- |
| `sop-ingestion` | **Python 3.12** (`Docling`) | Parser multimodal `.docx`/`.pdf`/`.xlsx`/`.pptx` & kode per segmen (`EBIS`/`RETAIL`/`WIBS`/`GENERAL`), *Command-Safe Chunker*, lokal Vision-LLM deskripsi *screenshot* `before/after`, penyimpanan aset gambar ke LocalFS/MinIO, & ekspor JSON kontrak `IngestResult` | — |
| `sop-memory-rag` | **Rust** (`qdrant-client`, `rig-qdrant`) | Hybrid Memory Engine: Qdrant Native Hybrid Search (Dense `BAAI/bge-m3` + Sparse BM25) + Reranker + Temporal Versioning (`doc_version`, `valid_from`, `valid_until`, `is_active`, `segment`, `role_acl`) mengonsumsi `IngestResult` | `sop-ingestion` |
| `triage-engine-api` | **Rust** (`Axum`, `Rig`, `sqlx`) + **Jev** | Deterministic 4-Stage Triage State Machine (`INTERVIEW → ANALYZE → CONFIRM → VERDICT`) dengan **Jev (`TypeSafe AI`)** sebagai *calibrated Choice router & Score judge* (redacted payload + local fallback), Private LLM (`Ollama`/`vLLM` via `LiteLLM`), PostgreSQL checkpointer, OTel → Langfuse, & Admin Auth | `sop-memory-rag` |
| `opendesign-web-portal` | **OpenDesign** (Standalone Web App) | **Standalone Web App Mandiri berbasis OpenDesign** (terpisah penuh dari `ncxall.my.id/dashboard`, mis. `ai.ncxall.my.id` / VPS): antarmuka Chat Triage 4-tahap, *Guided SOP Empty State*, penampil blok CLI/gambar SOP, & Panel Admin Upload SOP | `triage-engine-api` |

## Build Order

```text
sop-ingestion ──► sop-memory-rag ──► triage-engine-api ──► opendesign-web-portal
```

## Deferred Roadmap Boundary (Out of Scope for Fase 1 Specs)

- **Fase 2 (Self-Evaluation Loop):** `graphiti-temporal-memory`, `eval-loop` (Promptfoo + DeepEval + DSPy + Session-Branch Git PR), `redis-cache-queue`.
- **Fase 3 (Best-of-Breed Autonomous Workers):** `kestra-durable-triggers`, `agentgateway-humanlayer`, `openhands-sandbox`, `browser-use-worker`.
