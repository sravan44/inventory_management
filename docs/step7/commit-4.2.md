# Commit 4.2 — Product REST CRUD (narrated)

Goal: individual Product create/show/update/delete over REST — the first real
resource endpoints, and the first use of the serializer + a role policy that
honors API keys.

Depends on: 4.1 (Product), 3.3 (dual auth), 2.6 (policy base).

---

## Which operations are REST (and which aren't)

Per ADR-0009: REST owns **individual** create/show/update/delete. **Listing** and
**activate/deactivate** are GraphQL (commit 4.3). So the route is:

```ruby
resources :products, only: %i[show create update destroy]   # no :index
```

`ProductsController < TenantBaseController`, so it inherits the whole pipeline for
free: subdomain → schema, dual auth (JWT or Api-Key), `verify_authorized`.

---

## The serializer (ADR-0011, first use)

`Inventory::ProductSerializer` (Blueprinter) owns the JSON output shape — id as a
string, plus sku/name/description/uom/active/created_at. The controller renders
`ProductSerializer.render(product)`. Keeping the output contract in a serializer
means the response can evolve without touching the model or controller logic.

---

## The policy that finally honors API keys

`Inventory::ProductPolicy` reads **`Current.role`** — which is a user's membership
role *or* an api_key's role. So `create?/update?/destroy?` allow `admin`/`staff`
whether the caller is a logged-in user or a third-party key; `show?` allows any
authenticated actor. This is the first policy where the dual-auth work from 3.3
pays off — the identity policies deliberately used `Current.membership` (blocking
keys); data policies use `Current.role` (allowing them).

---

## SKU conflict → 409, not 422

A duplicate SKU is a **conflict** (`409 sku_taken`), distinct from other validation
failures (`422`), matching API_DESIGN.md. The controller inspects
`product.errors.of_kind?(:sku, :taken)` and branches. Everything else flows through
the standard error envelope.

---

## Tests / docs

`spec/requests/api/v1/products_spec.rb` is written in the **rswag DSL** (ADR-0012),
so it both tests and feeds the OpenAPI docs. It's tenant-scoped, so it stubs the
Apartment switch and pins the host with `host! "acme.example.com"`, authenticating
as a sample admin member; individual responses override `Authorization` to
document each policy outcome: create 201 / 409 `sku_taken` / 422 / 403
(purchasing), show 200 / 404, update 200, delete 204.

```bash
docker compose exec web bundle exec rspec spec/requests/api/v1/products_spec.rb
docker compose exec -e RAILS_ENV=test web bin/rails rswag:specs:swaggerize   # regen OpenAPI
```

Live (user path):
```bash
TOKEN=... # login as an admin member of "acme"
curl -s -X POST http://acme.lvh.me:3000/api/v1/products \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"product":{"sku":"ABC-1","name":"Widget","unit_of_measure":"each"}}' | jq
```

---

## What this commit does and doesn't do

Does: individual Product CRUD over REST, serialized, role-authorized (users + keys).

Doesn't: list products or toggle `active` — that's GraphQL (commit 4.3). Warehouses
(4.4) and stock (4.5–4.6) come next.

## Commit message

```
feat(inventory): Product REST CRUD + serializer + policy

- Api::V1::ProductsController show/create/update/destroy (no index; GraphQL lists)
- Inventory::ProductSerializer (Blueprinter, first serializer)
- Inventory::ProductPolicy on Current.role (admin/staff manage; honors API keys)
- duplicate SKU -> 409 sku_taken; other invalids -> 422
- request specs incl. dual-auth (user + api-key) paths
```
