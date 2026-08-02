# Commit 5.4 — Instrument operations to emit audit events (narrated)

Goal: make the audit pipeline carry real data by emitting events from the actual
operations. Completes **Milestone 5** — the audit trail now records who did what,
and the day-wise / NL search have something to search.

Depends on: 5.1–5.3.

---

## One-liner instrumentation

`Auditable` (a controller concern on `TenantBaseController`) adds:

```ruby
audit("product.created", resource: product, metadata: { sku: product.sku })
```

It delegates to `Audit::Logger.log`, which reads the actor + tenant from `Current`
and enqueues the emit job — so tagging an action is a single line that never blocks
the request. Because it's on `TenantBaseController`, every tenant-scoped controller
already has it.

## What now emits events

| Operation | Action |
|---|---|
| Product create / update / delete | `product.created` / `updated` / `deleted` |
| Warehouse create / update / delete | `warehouse.created` / `updated` / `deleted` |
| Stock movement (REST + GraphQL) | `stock.recorded` (with type + delta) |
| Membership invite / revoke | `membership.invited` / `revoked` |
| API key create / revoke | `api_key.created` / `revoked` |
| `setProductActive` (GraphQL) | `product.activated` / `deactivated` |

Both transports emit: the REST controllers via `audit(...)`, the GraphQL mutations
via `Audit::Logger.log` directly (Current is populated during execution).

## Deliberately emit AFTER success

The `audit` call sits after the write succeeds — a failed create/validation emits
nothing (asserted in the spec). We log what happened, not what was attempted.

---

## Tests

`audit_instrumentation_spec.rb`: creating a product enqueues `EmitActivityLogJob`
with `action: "product.created"` + the tenant/actor from Current; a failed create
enqueues nothing.

```bash
docker compose exec web bundle exec rspec spec/requests/api/v1/audit_instrumentation_spec.rb
```

End-to-end locally:
```bash
# create a product via the API, then drain + browse:
docker compose exec web bin/rails audit:drain    # Ctrl-C after "wrote N"
curl -s "http://acme.lvh.me:3000/api/v1/activity_logs?date=$(date +%F)" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq
# or NL (with OPENAI_API_KEY): ?nl=products created today
```

---

## Milestone 5 complete

Audit pipeline end to end: operations emit → Redis Stream → drainer → Mongo,
day-wise organized with retention, browsable + keyword/NL searchable, plus Sentry
exception tracking and a pluggable file/Mongo log viewer.

Remaining M5 hardening (optional, when needed): move jobs to **Sidekiq** (durable,
Redis-backed) and point rate-limit counters at Redis; run the drainer as a managed
service. Next milestones: **M6 React SPA**, **Milestone U** framework upgrades.

## Commit message

```
feat(audit): instrument operations to emit activity events (finish M5)

- Auditable concern on TenantBaseController; audit(...) one-liners
- products/warehouses/stock/memberships/api_keys emit on success
- GraphQL setProductActive/recordStockMovement emit via Audit::Logger
- request spec: emits on success, silent on failure
```
