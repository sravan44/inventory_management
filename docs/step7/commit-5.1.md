# Commit 5.1 — Activity-log emit (Redis Stream) (narrated)

Goal: the **emit half** of the audit pipeline (ADR-0007). State-changing operations
will fire `Audit::Logger.log(...)`; it enqueues a job that pushes the event onto a
**Redis Stream** buffer. A worker drains that stream to MongoDB in commit 5.2.

Depends on: 3.3 (Current.actor), Milestone 4.

Opens Milestone 5 and brings **Redis** into the stack (compose + gems).

---

## Why a stream + a job (not a direct DB write)

Audit logging must never slow or break a user's request:

```
request → Audit::Logger.log → enqueue EmitActivityLogJob → (job) XADD to Redis stream → (5.2) worker → MongoDB
```

- The request only pays an **enqueue** — async, off the request thread.
- **Redis Stream** absorbs write spikes fast; it's a buffer, not the system of
  record. `maxlen ~100k` caps it so a lagging drainer can't blow up memory.
- MongoDB (5.2) is the durable, queryable home.

This is deliberately NOT the `stock_movements` path: that's business truth in a
Postgres transaction. Audit is high-volume, eventually-consistent, best-effort.

---

## The pieces

- **`Audit::ActivityLog`** — a value object (Struct): tenant, actor, action,
  resource, metadata, occurred_at. `to_stream_hash` flattens it to strings (Redis
  stream fields are strings; metadata is JSON-encoded).
- **`Audit::ActivityStream`** — `publish(entry)` does `XADD` with `maxlen`. The
  Redis client is real in dev/prod (`REDIS_URL`) and an in-memory **MockRedis** in
  test, so specs and CI need no real Redis.
- **`Audit::Logger`** — the facade: reads `Current` (tenant + actor), builds the
  entry, enqueues `EmitActivityLogJob`. Every log carries `tenant_id`, so the
  shared stream/collection stays tenant-attributable.
- **`Audit::EmitActivityLogJob`** — thin async wrapper that publishes. Runs on the
  default adapter now; Sidekiq (durable, Redis-backed) replaces it later in M5.

---

## Tests (no real Redis needed)

- `activity_stream_spec.rb` — publish grows the stream; metadata round-trips as JSON.
- `logger_spec.rb` — enqueues the job; captures Current (tenant/actor/action).
- `emit_activity_log_job_spec.rb` — performing the job publishes to the stream.

```bash
docker compose exec web bundle exec rspec spec/services/audit spec/jobs/audit
```

---

## What this commit does and doesn't do

Does: capture + buffer audit events into Redis, fully async.

Doesn't: persist them durably (that's 5.2 — a drain worker → MongoDB), or wire
`Audit::Logger.log` into the actual operations (that's 5.3), or switch jobs to
Sidekiq yet.

## Commit message

```
feat(audit): activity-log emit via Redis Stream (ADR-0007)

- add redis (compose service + gem) and mock_redis for specs
- Audit::ActivityLog value object; Audit::ActivityStream (XADD + maxlen)
- Audit::Logger facade (from Current) -> enqueue; Audit::EmitActivityLogJob
- specs run against MockRedis (no real Redis in CI)
```
