# Commit 4.4 — Warehouse (narrated)

Goal: the Warehouse resource — a near-mirror of Product, establishing the second
inventory entity before the stock ledger ties them together (4.5–4.6).

Depends on: 4.1–4.3 (Product pattern).

---

## Same pattern, applied

Warehouse follows the exact Product shape, which is the point — the conventions
are now repeatable:

- **Migration** (tenant schema): `name`, `code`, `address` (jsonb), `active`,
  `deleted_at`; partial case-insensitive unique index on `lower(code)` where kept
  (code reusable after soft-delete).
- **Model** `Inventory::Warehouse`: code normalize, uniqueness among live rows,
  soft delete.
- **Serializer** `Inventory::WarehouseSerializer` (Blueprinter).
- **Policy** `Inventory::WarehousePolicy` on `Current.role` (admin/staff manage,
  any role reads — honors API keys).
- **REST** `WarehousesController` (show/create/update/destroy); duplicate code →
  `409 code_taken`.
- **GraphQL** `WarehouseType` + `warehouses` connection query (cursor pagination,
  `active` filter). `address` uses `GraphQL::Types::JSON`.

That a second resource drops in by copying the pattern is the signal the
architecture is sound — services/policies/serializers/dual-transport all compose.

---

## One new bit: jsonb address

`address` is a `jsonb` column (flexible structure without a schema migration per
field). REST permits it with `address: {}` (nested hash strong-param); GraphQL
exposes it via the `GraphQL::Types::JSON` scalar.

---

## Tests

- `spec/models/inventory/warehouse_spec.rb` — validity, required fields,
  case-insensitive unique code, reuse after soft-delete, soft delete.
- `spec/requests/api/v1/warehouses_spec.rb` — rswag (OpenAPI): create 201 / 409
  `code_taken` / 403, show 200 / 404, delete 204.
- `spec/requests/graphql_warehouses_spec.rb` — `warehouses` connection list.

```bash
docker compose exec web bin/migrate
docker compose exec web bundle exec rspec spec/models/inventory/warehouse_spec.rb spec/requests/api/v1/warehouses_spec.rb spec/requests/graphql_warehouses_spec.rb
docker compose exec -e RAILS_ENV=test web bin/rails rswag:specs:swaggerize
```

---

## What this commit does and doesn't do

Does: the Warehouse resource across REST + GraphQL, mirroring Product.

Doesn't: connect products to warehouses via stock — that's the ledger in commits
4.5 (StockLevel/StockMovement tables) and 4.6 (StockMovementService + endpoints),
which complete the vertical slice.

## Commit message

```
feat(inventory): Warehouse (model + REST CRUD + GraphQL list)

- warehouses tenant migration (jsonb address; partial unique lower(code) where kept)
- Inventory::Warehouse + serializer + policy (Current.role); code_taken -> 409
- WarehousesController (show/create/update/destroy); no index (GraphQL lists)
- WarehouseType + warehouses connection query
- model spec + rswag REST spec + GraphQL list spec
```
