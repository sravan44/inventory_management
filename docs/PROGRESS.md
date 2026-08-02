# Inventory Management — Progress Recap

A single-page memory refresher. For deep detail see the linked docs; this is the
"where are we and how did we get here" overview.

**Status:** Milestones 0–5 complete (foundation, identity/auth, dual API, Inventory
slice, audit logging + observability). Next up: Milestone 6 (React SPA); Milestone U
(framework upgrades).

---

## What we're building

A **multi-tenant SaaS for full supply-chain inventory management** (stock,
purchasing, sales, logistics). Backend is a **Rails API-first app**; a **React SPA**
comes later. Sold to multiple organizations, each fully isolated.

Core product shape:
- **Multi-tenant**, schema-per-tenant on PostgreSQL (each tenant = its own schema).
- **One user → many tenants** (like Slack workspaces), tenant chosen by subdomain.
- **Dual API:** GraphQL for the first-party SPA; REST for third-party integrators.
- **Stock as an append-only ledger** (`stock_movements`) with a materialized
  `stock_levels` projection — the source of truth for inventory.

---

## Tech stack

| Area | Choice |
|---|---|
| Backend | Rails 7.1 (full stack, **API-first** — JSON controllers on `ActionController::API`) |
| Database | PostgreSQL, schema-per-tenant via **ros-apartment** |
| Auth | JWT access + rotating refresh tokens; per-tenant **API keys** for third parties |
| Authorization | Pundit policies + membership gate |
| APIs | REST (`/api/v1`) + GraphQL (`/graphql`) |
| API docs | rswag → OpenAPI → Swagger UI (`/api-docs`) + Postman import |
| Admin | Motor Admin (`/admin`), HTTP-Basic gated |
| Rate limiting / CORS | Rack::Attack + rack-cors |
| Testing | RSpec + FactoryBot (build-first) |
| Dev/CI | Docker Compose; GitHub Actions (tests + lint) |

---

## Milestones & commits

### Milestone 0 — Foundation
| Commit | Delivered |
|---|---|
| 0.1 | Dockerized API-only Rails skeleton + `/up` health check (absorbed compose) |
| — | Hand-authored Rails core (Gemfile, config, boot, bin, RSpec) |
| 0.3 | GitHub Actions CI (tests + lint; security job later parked) |

### Milestone 1 — Multi-tenancy
| Commit | Delivered |
|---|---|
| 1.1 | Configure Apartment (schema-per-tenant, `persistent_schemas`, `default_tenant`) |
| 1.2 | `Identity::Tenant` model + migration (subdomain validations, soft delete) |
| 1.3 | `TenantProvisioningService` + `ProvisionTenantJob` (create schema, idempotent) |
| 1.4 | `Current` + `TenantResolution` (subdomain → schema switch; 404/403 handling) |

### Milestone 2 — Identity & auth
| Commit | Delivered |
|---|---|
| 2.1 | `Identity::User` (citext email, `has_secure_password`, soft delete) |
| 2.2 | `Identity::Membership` (user↔tenant↔role — the authorization boundary) |
| 2.3 | `Identity::RefreshToken` (hashed, revocable) |
| 2.4 | `JwtCodec` + `AuthenticationService` (login, rotation, reuse detection) |
| 2.5 | REST auth endpoints (register/login/refresh/logout/logout_all/me) |
| 2.6 | Membership gate + Pundit policy base (deny-by-default, `verify_authorized`) |

### Milestone 3 — API infrastructure
| Commit | Delivered |
|---|---|
| 3.1 | Standard error envelope + FactoryBot |
| 3.2 | Tenant + membership management endpoints (+ policies) |
| 3.3 | `Identity::ApiKey` + **dual authentication** (Bearer JWT or Api-Key → `Current.actor`) |
| 3.4 | GraphQL surface (`/graphql`, first-party/JWT-only, batch + depth/complexity limits) |
| 3.5 | Rate limiting (Rack::Attack) + CORS; test-DB auto-migration |

### Milestone 4 — Inventory vertical slice
| Commit | Delivered |
|---|---|
| 4.1 | `Inventory::Product` + products tenant migration (partial-unique SKU) |
| 4.2 | Product REST CRUD + Blueprinter serializer + policy (honors API keys) |
| 4.3 | Product GraphQL (`products` connection + `setProductActive`) |
| 4.4 | `Warehouse` (model + REST CRUD + GraphQL list) |
| 4.5 | `StockLevel` projection + `StockMovement` append-only ledger |
| 4.6 | `StockMovementService` (txn + FOR UPDATE + no-negative) + REST/GraphQL record & queries |

### Milestone 5 — Audit logging & observability
| Commit | Delivered |
|---|---|
| 5.1 | Activity-log emit → Redis Stream (async job + producer) |
| 5.2 | Mongo sink (drain worker, idempotent) + day-wise mgmt (day field, TTL, browse endpoint) |
| 5.3 | Sentry exception tracking + pluggable LLM log viewer (Mongo + file sources, NL search) |
| 5.4 | Instrument operations to emit events (products/warehouses/stock/memberships/api_keys) |

---

## Architecture decisions (ADR index)

| ADR | Decision |
|---|---|
| 0001 | Modular monolith, not microservices |
| 0002 | Schema-per-tenant on Postgres via Apartment (MySQL considered, rejected) |
| 0003 | Domain modules (namespaced now, Rails engines later) |
| 0004 | Tenant resolved from **subdomain** |
| 0005 | Stateless JWT + revocable refresh token |
| 0006 | One user identity, many tenants |
| 0007 | Audit logs via Redis Streams → MongoDB (async) — *pipeline planned, M5* |
| 0008 | ~~REST-only~~ superseded by 0009 |
| 0009 | Dual API: GraphQL (first-party) + REST (third-party) |
| 0010 | Per-tenant API keys for third-party REST |
| 0011 | App layers: service / worker / serializer / decorator / mailer |
| 0012 | API docs via rswag (OpenAPI) → Swagger UI + Postman |
| 0013 | Dev/test performance strategy (tiered, trigger-based) |
| 0014 | RailsAdmin attempted, **deferred** (asset pipeline); `super_admin` flag kept |
| 0015 | **Motor Admin** adopted (self-contained assets) |

Full text: `docs/adr/`. Map: `docs/ARCHITECTURE.md`.

---

## Notable detours & lessons (the "why it looks like this")

- **MySQL → stayed on PostgreSQL.** MySQL has no schema-within-DB namespace
  (Apartment would fall back to DB-per-tenant) and no partial indexes; also
  dev/prod parity. (ADR-0002)
- **citext lives in a `shared_extensions` schema**, not `public` — Apartment
  rewrites `public` → `tenant_x` when cloning, which would break `public.citext`.
- **Not `rails/all`** — we require only the frameworks used; Active Storage /
  Action Mailbox pulled in a `storage.yml` requirement + eager-load conflict.
- **`RAILS_ENV=test` is forced** in `rails_helper` — the Docker `web` service sets
  `development`, which would otherwise make RSpec hit the dev DB.
- **Rails 7.1 is EOL, on purpose** — kept as an upgrade *demonstration*
  (Milestone U). Consequences: Brakeman EOL check skipped, bundler-audit ignores
  the one Rails advisory, and the whole security CI job is temporarily parked.
- **Puma CVE-2026-47737** — fixed immediately (bumped to ≥ 7.2.1); contrast with
  the deliberately-deferred Rails EOL.
- **RailsAdmin → Motor Admin.** RailsAdmin v3 needs a JS asset build that doesn't
  fit an API-first app; Motor ships prebuilt assets. (ADR-0014 → 0015)
- **Test-DB migration automated** — `rspec` self-migrates (`before(:suite)`), plus
  `bin/migrate` for dev+test. No more `PendingMigration` surprises.

---

## What actually runs today

With `docker compose up`:
- **API:** REST at `/api/v1/...`, GraphQL at `POST /graphql`.
- **Auth:** register/login/refresh/logout/logout_all/me; JWT + refresh rotation;
  per-tenant API keys.
- **Tenancy:** create a tenant (async schema provision), resolve by subdomain,
  membership-gated + policy-authorized access.
- **Docs:** Swagger UI at `/api-docs` (generated from rswag specs).
- **Admin:** Motor Admin at `/admin` (HTTP Basic).
- **Protection:** rate limiting + CORS.
- **CI:** tests + lint green on every push.

Not built yet: the inventory domain (products/warehouses/stock), the audit-log
pipeline (M5), the React SPA (M6), and the framework upgrade demo (Milestone U).

---

## Quickstart (Docker only)

```bash
cp .env.example .env
docker compose build
docker compose up -d
docker compose exec web bin/migrate          # dev + test DBs
docker compose exec web bundle exec rspec
curl http://localhost:3000/up
```

- Swagger UI: http://localhost:3000/api-docs
- Admin: http://localhost:3000/admin  (admin / change-me)
- Tenant endpoints use a subdomain, e.g. http://acme.lvh.me:3000/...

---

## Doc map

| File | What |
|---|---|
| `docs/ARCHITECTURE.md` | The map + ADR index |
| `docs/DATABASE.md` | Schema design (public + tenant tables) |
| `docs/API_DESIGN.md` | REST + GraphQL contract, status codes, security |
| `docs/PATTERNS.md` | Service/worker/serializer/decorator/mailer conventions |
| `docs/IMPLEMENTATION_PLAN.md` | Commit-by-commit build plan (all milestones) |
| `docs/DEV_PERFORMANCE.md` | Gem caching + test-speed strategy (tiered) |
| `docs/GRAPHQL.md` | GraphQL docs: GraphiQL IDE + SDL (why not Swagger) |
| `docs/adr/*` | Decision records 0001–0015 |
| `docs/step7/commit-*.md` | Narrated walkthrough of each implemented commit |
| `postman/` | Superseded by OpenAPI import (see `postman/README.md`) |

---

## What's next

- **Milestone 4 — Inventory vertical slice:** Product/SKU → Warehouse →
  StockLevel/StockMovement, `StockMovementService` (transactional, row-locked),
  exposed over both REST (CRUD) and GraphQL (list + status mutations). Proves the
  whole architecture end-to-end.
- **Milestone 5 — Audit logging** (Redis → Mongo) + Sidekiq/Redis for jobs & shared
  rate-limit counters.
- **Milestone 6 — React SPA.**
- **Milestone U — Framework upgrade demo** (Rails 7.1 → 7.2/8, React 16 → 18);
  removes the EOL CI accommodations.
