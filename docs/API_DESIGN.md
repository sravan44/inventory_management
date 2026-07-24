# API Design (Step 5)

Two transport surfaces over the **same** service + policy layer (ADR-0009):

- **GraphQL** — `POST /graphql` on the tenant subdomain. First-party React SPA only, **user JWT**. Handles **listing (queries)** and **status-change mutations**.
- **REST** — `/api/v1` on the tenant subdomain. **Individual resource create/update/delete/show**. Consumed by third-party integrators (**per-tenant API key**, ADR-0010) and by the first-party SPA (**user JWT**) for create/update/delete.

Global auth/registration endpoints live on the apex host (a user may belong to zero or many tenants). Tenant context always comes from the subdomain (ADR-0004), never from the body or a token claim.

**Golden rule:** resolvers and controllers are thin adapters. Every business rule and authorization check lives in shared services (`Inventory::StockMovementService`, …) and policy objects. Neither surface re-implements the other's logic.

---

## Shared conventions (both surfaces)

- **IDs:** bigint serialized as strings (JS precision safety).
- **Timestamps:** ISO-8601 UTC.
- **Tenant context:** from subdomain; any tenant id in a payload is ignored.
- **Server-owned fields** (`tenant_id`, actor, `id`, timestamps) are never client-writable on either surface.
- **Authorization:** two gates — (1) membership/API-key belongs to the resolved tenant, (2) per-action policy object reads the role/scope. Fails closed by default.
- **Audit:** every state-changing operation on either surface emits an activity-log event (ADR-0007) recording the polymorphic actor (user or api_key), action, resource, tenant.

---

## Authentication

| Credential | Used by | Surfaces | Notes |
|---|---|---|---|
| User JWT (Bearer) | First-party SPA | GraphQL + REST | Short-lived (~15m) access token + rotating opaque refresh token (ADR-0005). Identifies user only, no tenant claim. |
| Tenant API key | Third-party integrators | REST only | `Authorization: Api-Key <key>`. Hashed at rest, shown once, scoped, revocable (ADR-0010). Rejected by GraphQL. |

REST accepts **either** credential and normalizes both into `Current.actor` (a user or an api_key) + `Current.tenant` before the policy layer runs. GraphQL accepts user JWT only.

---

## Global auth endpoints (REST, apex host — not tenant-scoped)

```
POST   /api/v1/auth/register        # create global user            201 | 422
POST   /api/v1/auth/login           # -> access + refresh tokens     200 | 401
POST   /api/v1/auth/refresh         # rotate access via refresh      200 | 401
POST   /api/v1/auth/logout          # revoke current refresh token   204
POST   /api/v1/auth/logout_all      # revoke all refresh tokens      204
GET    /api/v1/me                   # current user + memberships     200 | 401
```
Login returns the user's memberships (with each tenant's `subdomain`) so the SPA routes to the right tenant host. These stay REST even for the SPA because they precede tenant/GraphQL context.

---

## GraphQL surface (first-party SPA)

Single endpoint `POST /graphql` on the tenant subdomain. Queries = listing/reads. Mutations = status changes only. Create/update/delete of individual resources are **not** here — they go to REST.

### Queries (listing / reads)
```graphql
type Query {
  me: User!
  products(first: Int, after: String, active: Boolean, q: String): ProductConnection!
  product(id: ID!): Product
  warehouses(first: Int, after: String, active: Boolean): WarehouseConnection!
  stockLevels(productId: ID, warehouseId: ID): [StockLevel!]!
  stockMovements(first: Int, after: String, productId: ID, warehouseId: ID,
                 movementType: MovementType): StockMovementConnection!
  memberships(first: Int, after: String): MembershipConnection!
}
```
Connections use Relay-style cursor pagination (`edges`, `pageInfo.hasNextPage`, `endCursor`).

### Mutations (status changes only)
```graphql
type Mutation {
  setProductActive(id: ID!, active: Boolean!): ProductPayload!
  recordStockMovement(input: RecordStockMovementInput!): StockMovementPayload!
  changeMembershipRole(id: ID!, role: MembershipRole!): MembershipPayload!
  revokeMembership(id: ID!): MembershipPayload!
  setTenantStatus(status: TenantStatus!): TenantPayload!
}

input RecordStockMovementInput {
  productId: ID!
  warehouseId: ID!
  movementType: MovementType!   # RECEIPT | ADJUSTMENT | TRANSFER_IN | TRANSFER_OUT | SALE
  quantityDelta: Int!
  referenceType: String
  referenceId: ID
}
```
`recordStockMovement` calls `Inventory::StockMovementService` (same as REST). Actor is `Current.user`, never from input. Every payload type carries a `userErrors: [UserError!]!` field:
```graphql
type UserError { field: String, code: String!, message: String! }
```
Domain failures (insufficient stock, stale level, duplicate) surface as `userErrors` with the same stable `code`s as REST (`insufficient_stock`, `stale_stock_level`, …), **not** as HTTP status codes — GraphQL returns 200 with errors in the payload.

### GraphQL-specific controls
- **N+1:** all associations resolved via batch loading (`graphql-batch`).
- **Complexity/depth limiting:** max query depth + per-field complexity budget as the DoS control (GraphQL's equivalent of REST rate limits).
- **Introspection:** disabled in production (or restricted to authenticated staff).
- **Authorization:** field/mutation resolvers delegate to the same policy objects as REST.

---

## REST surface (individual CRUD + third-party)

Versioned `/api/v1` on the tenant subdomain. Standard resource semantics.

### Standard error envelope
```json
{
  "error": {
    "code": "validation_failed",
    "message": "Human-readable summary.",
    "details": [ { "field": "sku", "issue": "has already been taken" } ],
    "request_id": "req_01H..."
  }
}
```
`code` is a stable machine string shared with GraphQL `userErrors.code`.

### Status codes
| Code | When |
|---|---|
| 200 | GET / PATCH success |
| 201 | POST created |
| 202 | Accepted async work (tenant provisioning) |
| 204 | DELETE / no body |
| 400 | Malformed request |
| 401 | Missing/invalid credential (JWT or API key) |
| 403 | Authenticated but no membership/scope for this tenant/action |
| 404 | Not found, unresolved tenant subdomain, or cross-tenant resource (404 not 403 to avoid existence leaks) |
| 409 | Conflict — duplicate SKU/code, stale optimistic lock, insufficient stock |
| 422 | Validation failed |
| 429 | Rate limit exceeded (`Retry-After` header) |
| 500 | Unexpected (generic body, detail only in logs) |

### Products (individual CRUD)
```
POST   /api/v1/products             # create                 201 | 422 | 409(sku_taken)
GET    /api/v1/products/:id         # show                   200 | 404
PATCH  /api/v1/products/:id         # update fields          200 | 422 | 409
DELETE /api/v1/products/:id         # soft delete            204
```
Listing (`GET /products`) and activate/deactivate are **GraphQL** (status change), not REST. Payload:
```json
{ "product": { "sku": "ABC-123", "name": "Widget", "unit_of_measure": "each", "description": "..." } }
```

### Warehouses (individual CRUD)
```
POST   /api/v1/warehouses           201 | 422 | 409(code_taken)
GET    /api/v1/warehouses/:id       200 | 404
PATCH  /api/v1/warehouses/:id       200 | 422 | 409
DELETE /api/v1/warehouses/:id       204
```

### Stock movement (third-party record + individual read)
```
POST   /api/v1/stock_movements      # third-party records a movement   201 | 409 | 422
GET    /api/v1/stock_movements/:id  # individual movement              200 | 404
```
Same `Inventory::StockMovementService` as the GraphQL mutation. Actor is the API key (or user). Insufficient stock → 409 `insufficient_stock`; stale level → 409 `stale_stock_level`.

### Tenants & memberships (management)
```
POST   /api/v1/tenants              # create + async provision   202 | 422
GET    /api/v1/tenants/:id          # metadata (member only)     200 | 403/404
PATCH  /api/v1/tenants/:id          # update settings (admin)    200 | 403/422
DELETE /api/v1/tenants/:id          # soft delete (admin)        204 | 403

POST   /api/v1/memberships          # invite by email (admin)    201 | 422
DELETE /api/v1/memberships/:id      # revoke (admin)             204 | 403
```
Listing members and role changes are GraphQL (status change); invite/create/revoke individual records are REST. `POST /tenants` returns 202; provisioning runs async.

### API key management (admin, first-party)
```
GET    /api/v1/api_keys             # list tenant's keys (metadata only)   200
POST   /api/v1/api_keys             # create -> raw key shown ONCE          201
DELETE /api/v1/api_keys/:id         # revoke                                204
```

---

## Authorization model (both surfaces)

1. **Context gate** (middleware): resolve tenant from subdomain → resolve `Current.actor` from JWT or API key → verify actor belongs to this tenant (active membership, or API key owned by tenant). Else 403 (404 for cross-tenant resource probes).
2. **Policy gate** (per action/field): policy object reads role (membership role) or scope (API key scope). `admin` manages tenant/memberships/api_keys; `staff` records movements; reads broad, writes gated. Missing policy check → deny (fail closed), enforced by a `verify_authorized` hook in REST and a base resolver guard in GraphQL.

## Versioning

- **REST:** URL path (`/api/v1` → `/api/v2`), additive changes stay in v1, breaking changes bump the version with a published sunset window + `Deprecation`/`Sunset` headers.
- **GraphQL:** schema evolution — add fields freely, deprecate with `@deprecated(reason:)`, never breaking-remove. No URL version.

## Rate limiting

- REST: token-bucket per user and per IP; separate, key-scoped buckets for API-key (third-party) traffic; tighter buckets on auth + provisioning endpoints.
- GraphQL: query depth + complexity budget per request (the DoS control in place of per-endpoint limits), plus coarse per-user request rate.
- 429 carries `Retry-After` + `RateLimit-*` headers.

## Cross-cutting security (both surfaces)

- **Mass assignment:** strong-params allow-lists (REST) / typed input objects (GraphQL); server-owned fields never writable.
- **SQL injection:** ActiveRecord/parameterized only; filter/sort args allow-listed, never interpolated.
- **XSS:** JSON only, correct content-type, no server-side HTML.
- **CSRF:** header-based credentials (Bearer / Api-Key), not cookies, so the API is not CSRF-exposed; any future cookie flow needs SameSite + CSRF tokens.
- **CORS:** allow-list of known SPA origins (tenant subdomains), explicit credentials mode, never `*`.
- **API keys:** TLS-only, hashed at rest, never logged, least-privilege scopes, revocable/rotatable.
```
