# Commit 4.5 — StockLevel + StockMovement (narrated)

Goal: the inventory core — an **append-only ledger** (`stock_movements`, the source
of truth) plus a **materialized projection** (`stock_levels`, the fast read cache).
Tables + models only; the transactional writer is commit 4.6.

Depends on: 4.1 (Product), 4.4 (Warehouse).

---

## The pattern: ledger + projection

- **`stock_movements`** — every change to stock is an immutable, signed row
  (`quantity_delta`, `movement_type`). Insert-only: `created_at`, **no
  `updated_at`**. This is the truth; you can rebuild everything by replaying it.
- **`stock_levels`** — one row per (product, warehouse) holding current
  `quantity_on_hand` / `quantity_reserved`. It's a *cache* of the ledger, written
  only by the service (4.6), never edited by hand.

Why both: the ledger gives auditability and correctness (append-only, no
destructive edits); the projection gives O(1) reads of "how much do we have?"
without summing the whole ledger each time.

---

## StockLevel — the projection, guarded

- `unique(product_id, warehouse_id)` — exactly one level per pair.
- **CHECK constraints** `quantity_on_hand >= 0` / `quantity_reserved >= 0` — the
  DB refuses negative stock even if application logic slips.
- **`lock_version`** — Rails optimistic locking: two concurrent writers can't both
  win; the stale one gets `StaleObjectError`. (The service in 4.6 adds row-level
  `FOR UPDATE` on top for pessimistic safety.)
- `available_quantity = on_hand - reserved`.

## StockMovement — the ledger, immutable

- `enum movement_type` (receipt/adjustment/transfer_in/transfer_out/sale),
  signed `quantity_delta`.
- **Immutable:** `readonly?` returns true once persisted, so ActiveRecord refuses
  updates *and* destroys; a `before_update` guard backs it up. New (unpersisted)
  records stay writable so the initial insert works.
- **Polymorphic actor** (`actor_type`/`actor_id`) — a User or ApiKey in the public
  schema. No cross-schema FK (ADR-0010, 3A); `#actor` resolves by class + id.
- **Polymorphic reference** (`reference_type`/`reference_id`) — nil now; future
  PO/SO lines attach here with no schema change (the extensibility hook from LLD).

---

## Tests

- `stock_level_spec.rb` — available quantity, uniqueness per pair, non-negative
  validation, and **optimistic locking** (stale update → `StaleObjectError`).
- `stock_movement_spec.rb` — enum, **append-only** (update and destroy both raise
  `ReadOnlyRecord`), no `updated_at` column, polymorphic actor resolution.

```bash
docker compose exec web bin/migrate
docker compose exec web bundle exec rspec spec/models/inventory/stock_level_spec.rb spec/models/inventory/stock_movement_spec.rb
```

---

## What this commit does and doesn't do

Does: the ledger + projection tables and models, with the integrity guards.

Doesn't: actually move stock — that's commit 4.6 (`StockMovementService`: one
transaction that writes a movement and upserts the level with row locking + the
no-negative rule), plus the REST record endpoint and GraphQL `recordStockMovement`
mutation. That completes the vertical slice.

## Commit message

```
feat(inventory): StockLevel projection + StockMovement ledger

- stock_levels: unique(product,warehouse), CHECK >= 0, lock_version (optimistic)
- stock_movements: append-only (created_at only), enum type, signed delta,
  polymorphic reference + actor (no cross-schema FK)
- StockLevel#available_quantity; StockMovement immutable (readonly?/before_update)
- factories + model specs (uniqueness, non-negative, optimistic lock, immutability)
```
