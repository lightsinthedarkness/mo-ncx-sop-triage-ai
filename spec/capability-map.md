# Capability Map: MO NCX SOP Triage AI (`sop-triage-ai`) — Fase 1 Core (100% Pure Rust Backend)

- **Design Reference:** [DESIGN.md](../DESIGN.md) (Design 2.5 — 100% Pure Rust On-Prem Siebel 16 / Oracle 12c Advisory)
- **ADR Reference:** [ADR-001](../docs/adr/ADR-001-hybrid-python-rust-and-jev-orchestrator.md), [ADR-002](../docs/adr/ADR-002-internal-siebel16-oracle12c-zero-db-advisory-and-knowledge-automation.md), & [ADR-003](../docs/adr/ADR-003-pure-rust-backend-workspace.md)
- **PRD Reference:** [PRD.md](../PRD.md) (PRD 2.5)
- **Status:** Approved Phase 0 Baseline (Fase 1 of 3-Tier Progressive Rollout)

## Module Table

| Module id | Stack / Crate | Responsibility | Depends on |
| :--- | :--- | :--- | :--- |
| `sop-ingestion` | **Rust** (`crates/sop-core` + `crates/sop-ingestion`: `zip`, `quick-xml`, `calamine`, `lopdf`, `reqwest`) | Parser multimodal `.docx`/`.pdf`/`.xlsx`/`.pptx`, skrip, & `knowledge/domain-pack/` per segmen (`EBIS`/`RETAIL`/`WIBS`/`GENERAL`), *Command-Safe Chunker*, lokal Vision-LLM deskripsi *screenshot* `before/after`, penyimpanan aset gambar ke LocalFS/MinIO, & struct `IngestResult` | — |
| `sop-memory-rag` | **Rust** (`crates/sop-memory-rag`: `qdrant-client`, `rig-qdrant`, `fastembed`) | Hybrid Memory Engine: Qdrant Native Hybrid Search (Dense `BAAI/bge-m3` + Sparse BM25) + Reranker + Temporal Versioning (`doc_version`, `valid_from`, `valid_until`, `is_active`, `segment`, `role_acl`) mengonsumsi `IngestResult` | `sop-ingestion` |
| `triage-engine-api` | **Rust** (`crates/triage-engine`: `Axum`, `Rig`, `rmcp`, `sqlx`, `jsonwebtoken`) | 100% On-Prem 4-Stage Triage (`INTERVIEW → ANALYZE → CONFIRM → VERDICT`), *Offline-First Local Guided Router* (+ **Jev** opsional `E1`), **Zero Direct DB**, Office 2-Tier RBAC + *Immutable Audit Log*, Non-DB MCP Tools (`rmcp`: *Auto Handover Note*, *Auto SOP-Gap Detector*, *SOP Search*), Private LLM (`mistral.rs`/`vLLM`/`Ollama`), & Langfuse OTel | `sop-memory-rag` |
| `opendesign-web-portal` | **OpenDesign** (`web/` — Standalone Intranet App) | **Standalone Web App Mandiri berbasis OpenDesign** (intranet kantor, terpisah penuh dari `ncxall.my.id/dashboard`): Login Kantor, Chat Triage 4-tahap, Paste Log, *Auto Handover Note*, penampil blok CLI/query referensi & screenshot SOP, serta Panel Admin SOP & SOP-Gap | `triage-engine-api` |

## Build Order

```text
sop-ingestion (Rust) ──► sop-memory-rag (Rust) ──► triage-engine-api (Rust) ──► opendesign-web-portal (OpenDesign)
```

## Deferred Roadmap Boundary (Out of Scope for Fase 1 Specs)

- **Fase 2 (Self-Evaluation Loop — Self-Hosted):** `graphiti-temporal-memory`, `eval-loop` (`Promptfoo` + Golden Benchmark 80–100 NCX + Session-Branch Git PR), `redis-cache-queue`.
- **Fase 3 (Self-Hosted Knowledge Automation — Non-DB):** `kestra-temporal-onprem` (*SOP freshness audit* & pelaporan berkala — tetap **Zero Direct DB / Zero Prod Execution**).
