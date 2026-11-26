# Capability Map: MO NCX SOP Triage AI (`sop-triage-ai`) — Fase 1 Core

- **Design Reference:** [DESIGN.md](../DESIGN.md) (Design 2.2)
- **PRD Reference:** [PRD.md](../PRD.md) (PRD 2.2)
- **Status:** Approved Phase 0 Baseline (Fase 1 of 3-Tier Progressive Rollout)

## Module Table

| Module id | Responsibility | Depends on |
| :--- | :--- | :--- |
| `sop-ingestion` | Parser multimodal `.docx`/`.pdf`/`.xlsx`/`.pptx` & kode per segmen (`EBIS`/`RETAIL`/`WIBS`): Docling (teks & tabel), Command-Safe Chunker (blok CLI/XML utuh), Vision-LLM lokal (deskripsi *screenshot* `before/after`), & penyimpanan aset gambar ke MinIO | — |
| `sop-memory-rag` | Hybrid Memory Engine: Qdrant Native Hybrid Search (Dense `BAAI/bge-m3` + Sparse BM25) + Cross-Encoder Reranker (`bge-reranker-v2-m3`) + Temporal Versioning (`doc_version`, `valid_from`, `valid_until`, `is_active`, `segment`, `role_acl`) | `sop-ingestion` |
| `triage-engine-api` | FastAPI + LangGraph 4-Stage Triage State Machine (`INTERVIEW → ANALYZE → CONFIRM → VERDICT`), LiteLLM OpenAI-compatible Gateway (`Ollama` lokal ↔ `vLLM` GPU VPS), PostgreSQL checkpointer, Langfuse OTel trace, & endpoint Admin Upload/Delete SOP berautentikasi | `sop-memory-rag` |
| `dashboard-live-chat` | Iterasi UI via **OpenDesign** (pratinjau HTML/CSS/JS lokal) → integrasi *Hover-Peek Pill*, *Slide-Over Drawer* (`[⤢]` full-view), *Guided SOP Empty State*, & panel Admin SOP ke `C:/Users/Administrator/web` (`meadow-dashboard.html` + proxy `cloudflare/worker.js`) | `triage-engine-api` |

## Build Order

```text
sop-ingestion ──► sop-memory-rag ──► triage-engine-api ──► dashboard-live-chat
```

## Deferred Roadmap Boundary (Out of Scope for Fase 1 Specs)

- **Fase 2 (Hermes Loop):** `graphiti-temporal-memory`, `hermes-eval-loop` (Promptfoo + DSPy + Session-Branch Git PR), `redis-cache-queue`.
- **Fase 3 (Kortix Autonomous Workers):** `kestra-durable-triggers`, `agentgateway-humanlayer`, `openhands-sandbox`, `browser-use-worker`.
