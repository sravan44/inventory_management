# Commit 4.3 — Product GraphQL (list + setProductActive) (narrated)

Goal: the GraphQL half of the Product surface — a cursor-paginated `products`
query and a `setProductActive` status mutation — reusing the same model and policy
as REST. This is where the dual API (ADR-0009) becomes real: REST does individual
CRUD, GraphQL does listing + status changes.

Depends on: 4.2 (Product + policy), 3.4 (GraphQL plumbing).

---

## The list query (cursor pagination for free)

`QueryType#products` returns `Types::ProductType.connection_type`. Declaring a
**Relay connection** gives cursor pagination out of the box — `first/after`,
`last/before`, `edges { node }`, `pageInfo { hasNextPage endCursor }` — bounded by
the schema's `default_max_page_size`. The resolver just returns an ActiveRecord
relation:

```ruby
def products(active: nil, query: nil)
  scope = Inventory::Product.kept.order(created_at: :desc)
  scope = scope.where(active: active) unless active.nil?
  scope = scope.where("name ILIKE :q OR sku ILIKE :q", q: "%#{query}%") if query.present?
  scope
end
```

Cursor over offset because it stays correct under concurrent inserts. The search
uses a **bound parameter** (`:q`), not string interpolation into SQL — no injection.

---

## The status mutation

`Mutations::SetProductActive` (input: `id`, `active`) returns a payload with
`product` and `userErrors`. Two error styles, deliberately:

- **Domain problem** (product not found) → a `userErrors` entry with a stable
  `code` (`not_found`) and **HTTP still 200**. GraphQL convention: expected
  failures live in the payload, not the transport (ADR-0009). The codes mirror
  REST's so clients switch on the same strings.
- **Authorization denial** → a **top-level error** via `authorize!` — it's not a
  normal outcome, so it surfaces in the GraphQL `errors` array.

---

## Same policy, both transports

`authorize!` (in `BaseMutation`) calls `Pundit.policy!(Current.user, record)` →
`Inventory::ProductPolicy#update?`. That's the **exact policy REST uses**, and it
reads `Current.role`, so it honors both user and api-key actors identically. One
authorization source of truth across REST and GraphQL — the "shared layer under
two transports" promise from ADR-0009, made concrete. (`Current.*` is still
populated because GraphQL executes inside the request, after the controller's
before-actions set it.)

---

## Tests

`spec/requests/graphql_products_spec.rb`: list returns the tenant's products as a
connection, `active` filter works; `setProductActive` deactivates (empty
userErrors), returns `not_found` userError for a missing id, and denies a
`purchasing` user with a top-level error (product unchanged).

```bash
docker compose exec web bundle exec rspec spec/requests/graphql_products_spec.rb
```

Live:
```bash
curl -s -X POST http://acme.lvh.me:3000/graphql \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"query":"{ products(first: 5) { edges { node { sku name active } } } }"}' | jq
```

---

## What this commit does and doesn't do

Does: GraphQL list + status mutation for products, authorized by the shared policy.

Doesn't: warehouses (4.4) or stock (4.5–4.6). Product REST CRUD stays in 4.2;
together they complete the Product slice across both transports.

## Commit message

```
feat(inventory): Product GraphQL (products query + setProductActive)

- ProductType + connection (cursor pagination); active/query filters
- Mutations::SetProductActive: userErrors payload (200) + authorize! for denial
- BaseMutation#authorize! reuses Inventory::ProductPolicy (Current.role) — same
  policy as REST, honors user + api-key actors
- UserErrorType; GraphQL request specs (list/filter/mutation/authz)
```
