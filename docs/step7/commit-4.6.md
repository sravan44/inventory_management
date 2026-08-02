# Commit 4.6 — StockMovementService + stock endpoints (narrated)

Goal: make stock actually move — safely and identically across both transports.
This completes **Milestone 4**: the Inventory vertical slice works end to end.

Depends on: 4.5 (ledger + projection), 4.2/4.3 (Product patterns).

---

## The service — the only way stock changes

`Inventory::StockMovementService.call(product:, warehouse:, movement_type:,
quantity_delta:, actor:)` does everything in **one transaction**:

1. **Ensure + lock the level row.** `create_or_find_by!` survives the create race,
   then `StockLevel.lock.find_by!` re-reads it with `SELECT … FOR UPDATE` — so
   concurrent movements on the same (product, warehouse) serialize on that row.
2. **Enforce no-negative stock.** `on_hand + delta`; if it'd go negative, raise
   `InsufficientStock` (the transaction rolls back — no ledger row, level
   unchanged). The DB CHECK constraint from 4.5 is the backstop.
3. **Append the ledger row** (`stock_movements`) with the polymorphic actor.
4. **Update the projection** (`stock_levels`).

Two layers of concurrency safety: the pessimistic `FOR UPDATE` row lock here, and
the optimistic `lock_version` from 4.5 underneath.

---

## One service, both transports (the ADR-0009 payoff, complete)

- **REST** `POST /api/v1/stock_movements` (third-party + SPA) → calls the service;
  `InsufficientStock` → `409 insufficient_stock`. Plus `GET /stock_movements/:id`.
- **GraphQL** `recordStockMovement` mutation (first-party) → calls the **same
  service**; `InsufficientStock` → a `userErrors` entry (HTTP 200), role denial →
  top-level error. Plus `stockLevels` and `stockMovements` connection queries.

The record logic exists once, in the service. REST and GraphQL are just two doors
into it — they cannot compute stock differently. Authorization is the shared
`StockMovementPolicy` (admin/staff via `Current.role`, so API keys work too).

---

## Tests

- `stock_movement_service_spec.rb` — first receipt creates the level; signed deltas
  accumulate; a ledger row per movement; actor recorded; **insufficient stock
  raises and rolls back** (level unchanged, no stray ledger row).
- `stock_movements_spec.rb` — rswag (OpenAPI): record 201, insufficient → 409.
- `graphql_stock_spec.rb` — `recordStockMovement` updates the level, insufficient →
  userError, `stockMovements` lists the ledger.

```bash
docker compose exec web bin/migrate
docker compose exec web bundle exec rspec spec/services/inventory spec/requests/api/v1/stock_movements_spec.rb spec/requests/graphql_stock_spec.rb
docker compose exec -e RAILS_ENV=test web bin/rails rswag:specs:swaggerize
```

---

## Milestone 4 complete — the vertical slice works

Product + Warehouse + Stock, over REST and GraphQL, tenant-isolated, authorized
(users + API keys), documented (Swagger + GraphiQL), with the ledger/projection
integrity model. The architecture is proven end-to-end: a request →
resolve tenant → authenticate actor → authorize → shared service → ledger +
projection in one transaction → serialized response.

Next: **Milestone 5** (audit logging Redis→Mongo + Sidekiq/Redis for jobs and
shared rate-limit counters), then **Milestone 6** (React SPA), and **Milestone U**
(framework upgrade demo).

## Commit message

```
feat(inventory): StockMovementService + stock endpoints (finish M4)

- StockMovementService: one txn, FOR UPDATE row lock, no-negative rule,
  append ledger + update projection
- REST POST/GET stock_movements (insufficient_stock -> 409)
- GraphQL recordStockMovement mutation + stockLevels/stockMovements queries
- StockMovementPolicy (Current.role); serializers; service/REST/GraphQL specs
```
