# Database Design (Step 4)

Primary store: **PostgreSQL**, schema-per-tenant (ADR-0002).
Audit/activity logs: **Redis Streams → MongoDB** async pipeline (ADR-0007), separate from the domain data below.

Two Postgres schema tiers:
- **`public`** (global, Apartment-excluded): identity — shared across all tenants.
- **Per-tenant schemas** (one per tenant): all domain modules — Inventory now, Purchasing/Sales/Logistics later. Every tenant's modules are fully isolated in their own schema.

Decisions locked for this step: cross-schema references validated at the app layer, not by DB FK (3A); new tenants provisioned by replaying migrations (4A); logs written async (2A) via Redis→Mongo (1C).

---

## Public schema (global)

### users
| column | type | notes |
|---|---|---|
| id | bigint PK | |
| email | citext | **unique index**, normalized lowercase |
| password_digest | string | not null |
| first_name, last_name | string | |
| status | enum | active / invited / suspended, default active |
| deleted_at | timestamp | soft delete |
| created_at, updated_at | timestamp | |

Email uniqueness is **not** limited to non-deleted rows — an address stays reserved after deletion to prevent impersonation-via-reuse.

### tenants
| column | type | notes |
|---|---|---|
| id | bigint PK | |
| name | string | not null |
| subdomain | string | **unique index**, normalized lowercase; reserved words blocked at validation |
| schema_name | string | unique |
| status | enum | pending_provisioning / active / suspended, default pending_provisioning |
| deleted_at | timestamp | soft delete before hard schema drop (recovery window) |
| created_at, updated_at | timestamp | |

### memberships (join — one user, many tenants)
| column | type | notes |
|---|---|---|
| id | bigint PK | |
| user_id | bigint FK → users | on delete cascade |
| tenant_id | bigint FK → tenants | on delete cascade |
| role | enum | admin / staff / purchasing / sales, not null |
| status | enum | invited / active / revoked, default invited |
| invited_at, joined_at, revoked_at | timestamp | nullable |
| created_at, updated_at | timestamp | |

Indexes: **unique(user_id, tenant_id)**, index(tenant_id), index(user_id).
One row per pair; status flips on re-invite/revoke. No historical trail here — that lives in the audit log pipeline (ADR-0007), or a future `membership_events` ledger if a Postgres-durable trail is needed.

### refresh_tokens
| column | type | notes |
|---|---|---|
| id | bigint PK | |
| user_id | bigint FK → users | on delete cascade |
| token_digest | string | **unique index** — store hash, never the raw token |
| expires_at | timestamp | not null, index for cleanup |
| revoked_at | timestamp | nullable |
| created_at | timestamp | |

Index(user_id) supports "log out everywhere" (revoke all by user).

### api_keys (third-party REST credentials — ADR-0010)
| column | type | notes |
|---|---|---|
| id | bigint PK | |
| tenant_id | bigint FK → tenants | on delete cascade |
| name | string | human label |
| token_digest | string | **unique index** — store hash, show raw key once |
| scopes | jsonb / string[] | least-privilege scope list (or a role enum) |
| last_used_at | timestamp | nullable, for monitoring/rotation |
| expires_at | timestamp | nullable |
| revoked_at | timestamp | nullable |
| created_at, updated_at | timestamp | |

Index(tenant_id). Keys are tenant-scoped; GraphQL never accepts them (first-party only).

---

## Tenant schema (per tenant — each tenant's modules fully isolated)

### products
| column | type | notes |
|---|---|---|
| id | bigint PK | |
| sku | string | not null; **unique index on lower(sku) WHERE deleted_at IS NULL** — archived SKUs may be reissued |
| name | string | not null |
| description | text | |
| unit_of_measure | string | |
| active | boolean | default true |
| deleted_at | timestamp | soft delete |
| created_at, updated_at | timestamp | |

### warehouses
| column | type | notes |
|---|---|---|
| id | bigint PK | |
| name | string | not null |
| code | string | **unique index** |
| address | jsonb | |
| active | boolean | default true |
| deleted_at | timestamp | soft delete |
| created_at, updated_at | timestamp | |

### stock_levels (materialized projection — written only by StockMovementService)
| column | type | notes |
|---|---|---|
| id | bigint PK | |
| product_id | bigint FK → products | |
| warehouse_id | bigint FK → warehouses | |
| quantity_on_hand | integer | not null default 0, **CHECK >= 0** |
| quantity_reserved | integer | not null default 0, **CHECK >= 0** |
| lock_version | integer | default 0 (optimistic locking) |
| created_at, updated_at | timestamp | |

**Unique index (product_id, warehouse_id)** — exactly one row per pair.
Deliberate denormalization: a read cache of `stock_movements`, regenerable by replaying the ledger.

### stock_movements (append-only domain ledger — source of truth)
| column | type | notes |
|---|---|---|
| id | bigint PK | |
| product_id | bigint FK → products | |
| warehouse_id | bigint FK → warehouses | |
| movement_type | enum | receipt / adjustment / transfer_in / transfer_out / sale, not null |
| quantity_delta | integer | signed, not null |
| reference_type, reference_id | string / bigint | polymorphic, nullable (future PO/SO lines) |
| actor_type | string | **polymorphic actor** — 'user' or 'api_key' (ADR-0010) |
| actor_id | bigint | references public.users.id OR public.api_keys.id — **validated at app layer, no cross-schema FK** (3A) |
| created_at | timestamp | **no updated_at — never updated, insert-only** |

> Actor was originally `created_by_user_id`; ADR-0010 makes it polymorphic (`actor_type`/`actor_id`) because a third-party API key can also record a movement. Activity-log documents (ADR-0007) carry the same polymorphic actor fields.

Immutability enforced in Rails now (`before_update` raises); a DB rule/trigger is a stronger pre-production hardening step.
Indexes: (product_id, warehouse_id, created_at), (reference_type, reference_id), created_by_user_id, movement_type.

Writes go through `StockMovementService` in one transaction: insert movement + upsert stock_level with `SELECT ... FOR UPDATE` row locking to prevent concurrent-update races. "No negative stock" enforced in the service and backstopped by the CHECK constraint.

---

## Audit / activity logs (MongoDB, via Redis Streams — ADR-0007)

Not a Postgres table. Emitted async from the request, buffered in a Redis Stream, drained by a worker into MongoDB.

Example document (collection: `activity_logs`):
```json
{
  "_id": "<event uuid>",        // idempotency key, at-least-once safe
  "tenant_id": 42,
  "user_id": 7,
  "action": "product.created",
  "resource_type": "Product",
  "resource_id": 1001,
  "metadata": { "sku": "ABC-123" },
  "ip": "203.0.113.4",
  "occurred_at": "2026-07-24T19:50:00Z"
}
```
Indexes in Mongo: `tenant_id + occurred_at` (tenant-scoped timeline), `user_id`, `action`, `resource_type + resource_id`.
Every document carries `tenant_id` so audit queries stay tenant-scoped even though the store is shared infrastructure.

---

## Normalization

3NF throughout, except `stock_levels`, which is an intentional denormalized read cache of the `stock_movements` ledger.

## Auditing

`created_at`/`updated_at` on all Postgres tables. Business/user-action auditing handled by the MongoDB pipeline. No `paper_trail`-style Postgres audit table now (YAGNI — addable later without reshaping existing tables).

## Migration & provisioning strategy

- **Public schema:** standard `db/migrate`, runs once.
- **Tenant schemas:** Apartment migrations run across all existing tenant schemas (`rake apartment:migrate`) and against a fresh schema at provisioning time by **replaying all migrations** (4A). Standard default; revisit template-clone provisioning if tenant-creation time becomes a problem at scale.
- **CI must migrate both** a public test DB and at least one tenant fixture schema, so a tenant-only migration bug can't slip through.
