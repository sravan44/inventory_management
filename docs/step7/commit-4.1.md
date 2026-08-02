# Commit 4.1 — Inventory::Product + products migration (narrated)

Goal: the first **tenant-schema** table and the first real product-domain model.
Opens Milestone 4 (the Inventory vertical slice).

Depends on: Milestone 1 (tenancy).

---

## First tenant-scoped table

Unlike the identity tables (users/tenants/memberships/…) which are **excluded** from
Apartment and live in `public`, `products` is a **normal** table — so Apartment
creates it in **every tenant schema**. At request time the schema switch (commit
1.4) makes `Inventory::Product.all` read only the current tenant's products.

> A copy of `products` also exists in `public` (migrations run there too) — it's
> unused overhead, normal for Apartment. Tenant queries never touch it because the
> resolver switches the search_path to the tenant schema.

---

## The migration

`db/migrate/20260724000007_create_products.rb`: `sku`, `name`, `description`,
`unit_of_measure`, `active` (default true), `deleted_at` (soft delete), timestamps.

The interesting bit is the index:

```ruby
add_index :products, "lower(sku)", unique: true, where: "deleted_at IS NULL"
```

A **partial, case-insensitive unique index**: unique on `lower(sku)` but only
across **live** (non-deleted) rows. So `ABC-1` can be reused once the original is
soft-deleted — standard inventory practice. This is a Postgres feature MySQL
can't do cleanly (one of the reasons we stayed on Postgres, ADR-0002).

---

## The model

`app/models/inventory/product.rb` — namespaced `Inventory::Product`,
`self.table_name = "products"` (same trick as the identity models).

- `normalize_sku` strips whitespace before validation.
- **Uniqueness mirrors the index:** case-insensitive, `conditions: -> { where(deleted_at: nil) }`,
  and only validated for live rows — so it matches the partial DB index and a
  reissued SKU passes. (DB index = the real guarantee; the validation = friendly
  errors.)
- `scope :kept`, `soft_delete!` (also flips `active: false`), `deleted?`.

Not added to Apartment's excluded_models — it's tenant-scoped, which is the whole
point.

---

## Tests

`spec/models/inventory/product_spec.rb` (with factories): validity, required
fields, sku stripping, case-insensitive uniqueness among live products, **reuse
after soft-delete**, and soft delete behavior.

```bash
docker compose exec web bin/migrate
docker compose exec web bundle exec rspec spec/models/inventory/product_spec.rb
```

(Model specs run against the `public` copy of `products` since they don't switch
into a tenant — fine for unit-testing the model.)

---

## What this commit does and doesn't do

Does: the Product model + tenant table with the reusable-SKU index.

Doesn't: expose Product over the API — REST CRUD is commit 4.2, GraphQL list +
`setProductActive` is 4.3. Warehouses (4.4) and stock (4.5–4.6) follow.

## Commit message

```
feat(inventory): Product model + products tenant migration

- products table in tenant schema; partial unique index on lower(sku) where kept
  (reusable SKU after soft-delete, case-insensitive)
- Inventory::Product (namespaced): sku normalize, uniqueness among live rows,
  soft delete (+ deactivate)
- product factory + model spec
```
