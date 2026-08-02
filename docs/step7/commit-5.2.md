# Commit 5.2 — Mongo sink + day-wise log management (narrated)

Goal: the **durable half** of the audit pipeline — drain the Redis stream into
MongoDB — plus **day-wise** organization, retention, and an admin browse endpoint.

Depends on: 5.1 (Redis emit). Brings **MongoDB** into the stack.

---

## The pipeline, completed

```
… Redis Stream (5.1)  →  StreamDrainer (consumer group)  →  ActivityLogStore (Mongo)
```

- **`Audit::StreamDrainer`** reads with a Redis **consumer group** (`XREADGROUP`),
  writes each entry to the store, then **`XACK`s** it. Consumer groups give
  **at-least-once** delivery (an un-acked entry is redelivered after a crash);
  combined with idempotent writes, that's exactly-once *effect*.
- **`Audit::ActivityLogStore`** — MongoDB in dev/prod, an in-memory backing in
  test (no Mongo in CI). Documents are keyed by the **stream entry id**, so
  re-draining the same entry is a no-op (`$setOnInsert` upsert) — that's the
  idempotency that makes at-least-once safe.
- **`rake audit:drain`** runs the drainer in a loop — the worker process. (A
  `docker compose` service or Sidekiq schedule can run it; for now it's a rake
  task you can run in a container.)

---

## Day-wise management

Every document gets a **`day`** field (`YYYY-MM-DD`, derived from `occurred_at`)
plus indexes on `{day, tenant_id}` and `{occurred_at}`. That powers:

- **`for_day(day, tenant_id:)`** — a tenant's logs for a date, newest first.
- **`day_counts(tenant_id:)`** — count per day (a calendar/overview).
- **TTL retention** — a TTL index on `created_at` auto-expires logs after
  `AUDIT_RETENTION_DAYS` (default 90), so old audit data ages out without a cron.

### Browse endpoint (admin only)
- `GET /api/v1/activity_logs?date=YYYY-MM-DD` → that day's logs.
- `GET /api/v1/activity_logs/summary` → per-day counts.

`ActivityLogPolicy` restricts these to **user admins** (`Current.membership.admin?`)
— API keys can't read the audit trail (identity-style policy, not data-style).

---

## Tests (no Mongo/Redis needed)

- `activity_log_store_spec.rb` — idempotent insert, day bucketing + tenant scope,
  per-day summary (against the in-memory backing).
- `stream_drainer_spec.rb` — stubs the Redis client: reads a batch, writes to the
  store, `XACK`s each id; JSON metadata decoded back to a hash; empty stream → 0.
- `activity_logs_spec.rb` — admin gets a day's logs + summary; non-admin → 403.

```bash
docker compose exec web bundle exec rspec spec/services/audit spec/requests/api/v1/activity_logs_spec.rb
```

Run the real pipeline locally:
```bash
docker compose up -d                      # now includes redis + mongo
docker compose exec web bin/rails runner 'Audit::Logger.log(action: "demo.ping")'
docker compose exec web bin/rails audit:drain   # Ctrl-C after it prints "wrote 1"
# then browse via GET /api/v1/activity_logs?date=<today> as an admin
```

---

## What this commit does and doesn't do

Does: durable, idempotent, day-organized audit storage with retention + admin
browsing. Full pipeline emit → buffer → sink works.

Doesn't: instrument the actual operations to emit events (commit 5.3 sprinkles
`Audit::Logger.log` into create/update/stock/auth), or move jobs to Sidekiq
(separate M5 step). The drainer runs as a rake loop, not yet a managed service.

## Commit message

```
feat(audit): MongoDB sink + day-wise log management (ADR-0007)

- add mongo (compose + driver); Audit::ActivityLogStore (Mongo/dev, memory/test)
  idempotent by stream id; day field + indexes + TTL retention
- Audit::StreamDrainer (consumer group XREADGROUP -> store -> XACK); rake audit:drain
- day-wise browse: GET activity_logs?date=, activity_logs/summary (admin only)
- specs against in-memory store + stubbed redis (no services in CI)
```
