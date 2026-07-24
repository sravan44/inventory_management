# ADR-0007: Audit/activity logging via Redis Streams buffer → MongoDB sink

**Status:** Accepted
**Date:** 2026-07-24

## Context

The product needs an audit/activity trail: who did what, in which tenant, when. This is high-volume, append-only, and read far less often than it is written. It is distinct from the `stock_movements` domain ledger, which is business truth and must be transactional and durable in Postgres. Logging must not add latency to, or risk failing, the main request path.

Two forces: ingestion needs to be fast and non-blocking; storage needs to be durable and queryable over time. No single store serves both cheaply.

## Decision

Two-stage pipeline, fully decoupled from the request transaction:

1. **Emit** — during a request, the app enqueues a log event asynchronously (ActiveJob/Sidekiq). The request transaction never blocks on or fails because of logging.
2. **Buffer** — events are pushed onto a **Redis Stream** for fast, in-memory ingestion.
3. **Sink** — a background worker drains the Redis Stream and writes to **MongoDB** for durable, queryable long-term storage.

Every log document carries `tenant_id` (and `user_id`, `action`, `resource_type`, `resource_id`, `metadata`, `occurred_at`) so tenant-scoped audit queries are possible even though the log store itself is shared infrastructure, not per-tenant schema.

## Alternatives Considered

- MongoDB only, written async — durable and simple, one fewer moving part. Rejected in favor of the buffer because a Redis Stream absorbs write spikes without back-pressuring the job queue, and decouples ingestion rate from Mongo write throughput.
- Redis Streams only — fast, but not durable long-term; stream entries can be trimmed/evicted, so it cannot be the system of record for an audit trail.
- Synchronous inline write to any store — couples request latency and success to the log store's availability; an outage there would break user actions. Rejected.
- Redis buffer → MongoDB sink (chosen) — Redis handles ingestion spikes, Mongo provides durability and query. Accepted cost: two datastores plus a drain worker to operate and monitor.

## Consequences

- Two additional pieces of infrastructure (Redis, MongoDB) plus a drain worker must be run, monitored, and capacity-planned.
- The pipeline is eventually consistent: a log event may lag the action that produced it by the queue + drain latency. Acceptable for an audit trail; unacceptable for the domain ledger, which is why the ledger stays in Postgres.
- Failure modes to handle: worker down (Redis Stream backs up — needs alerting and a max-length/trim policy), Mongo down (worker retries/holds), Redis eviction before drain (mitigate with stream max-length tuned to worst-case drain lag, and at-least-once delivery with idempotent writes keyed on an event id).
- Do NOT route `stock_movements` or any business-truth data through this pipeline — it is for audit/activity only.

## Related

Depends on: ADR-0002 (Postgres schema-per-tenant is the primary store)
Contrast with: `stock_movements` domain ledger (Postgres, transactional) — this ADR is explicitly the non-transactional audit path.
