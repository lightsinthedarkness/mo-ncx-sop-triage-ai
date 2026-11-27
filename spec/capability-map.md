# Capability Map: MO NCX SOP Triage AI (`sop-triage-ai`) — Fase 1 Core

- **Design Reference:** [DESIGN.md](../DESIGN.md) (Design 2.4 — On-Prem Siebel 16 / Oracle 12c Zero-Direct-DB Advisory)
- **ADR Reference:** [ADR-001](../docs/adr/ADR-001-hybrid-python-rust-and-jev-orchestrator.md) & [ADR-002](../docs/adr/ADR-002-internal-siebel16-oracle12c-zero-db-advisory-and-knowledge-automation.md)
- **PRD Reference:** [PRD.md](../PRD.md) (PRD 2.4)
- **Status:** Approved Phase 0 Baseline (Fase 1 of 3-Tier Progressive Rollout)

## Module Table

| Module id | Stack | Responsibility | Depends on |
| :--- | :--- | :--- | :--- |
| `sop-ingestion` | **Python 3.12** (`Docling`) | Parser multimodal `.docx`/`.pdf`/`.xlsx`/`.pptx`, skrip, & `knowledge/domain-pack/` per segmen (`EBIS`/`RETAIL`/`WIBS`/`GENERAL`), *Command-Safe Chunker*, lokal Vision-LLM deskripsi *screenshot* `before/after`, penyimpanan aset gambar ke LocalFS/MinIO, & ekspor JSON kontrak `IngestResult` | — |
| `sop-memory-rag` | **Rust** (`qdrant-client`, `rig-qdrant`) | Hybrid Memory Engine: Qdrant Native Hybrid Search (Dense `BAAI/bge-m3` + Sparse BM25) + Reranker + Temporal Versioning (`doc_version`, `valid_from`, `valid_until`, `is_active`, `segment`, `role_acl`) mengonsumsi `IngestResult` | `sop-ingestion` |
| `triage-engine-api` | **Rust** (`Axum`, `Rig`, `sqlx`) | 100% On-Prem 4-Stage Triage (`INTERVIEW → ANALYZE → CONFIRM → VERDICT`), *Offline-First Local Guided Router* (+ **Jev** opsional `E1`), **Zero Direct DB**, Office 2-Tier RBAC + *Immutable Audit Log*, *Auto Handover Note*, *Auto SOP-Gap Detector*, Private LLM (`vLLM`/`Ollama` via `LiteLLM`), & Langfuse OTel | `sop-memory-rag` |
| `opendesign-web-portal` | **OpenDesign** (Standalone Intranet App) | **Standalone Web App Mandiri berbasis OpenDesign** (intranet kantor, terpisah penuh dari `ncxall.my.id/dashboard`): Login Kantor, Chat Triage 4-tahap, Paste Log, *Auto Handover Note*, penampil blok CLI/query referensi & screenshot SOP, serta Panel Admin SOP & SOP-Gap | `triage-engine-api` |

## Build Order

```text
sop-ingestion ──► sop-memory-rag ──► triage-engine-api ──► opendesign-web-portal
```

## Deferred Roadmap Boundary (Out of Scope for Fase 1 Specs)

- **Fase 2 (Self-Evaluation Loop):** `graphiti-temporal-memory`, `eval-loop` (Promptfoo + DeepEval + DSPy + Session-Branch Git PR), `redis-cache-queue`.
- **Fase 3 (Best-of-Breed Autonomous Workers):** `kestra-durable-triggers`, `agentgateway-humanlayer`, `openhands-sandbox`, `browser-use-worker`.
