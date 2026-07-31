# Implementation Plan (Step 6)

Small, individually-deployable commits. Rules applied to every one:

- **CI stays green** — RuboCop + RSpec + Brakeman + bundler-audit (backend), ESLint + Jest (frontend) all pass.
- **Migrations are expand/contract** — additive first; no destructive change in the same deploy that starts using it. Backward-compatible so a rollback is safe.
- **`main` is always deployable** — an unfinished vertical sits behind a feature flag; it never blocks a deploy.
- **One concern per commit** — a model, a service, a controller, a resolver, a type — not a whole feature at once (matches Step 7's one-component-at-a-time rule).
- **Tests ship with the code** they cover, in the same commit.

Commits are grouped into milestones. Each **milestone** is independently shippable to production; each **commit** within it is deployable on its own.

---

## Milestone 0 — Repo, tooling, CI

| # | Commit | Deployable because | Tests |
|---|---|---|---|
| 0.1 | **Dockerized** API-only Rails skeleton (absorbs 0.2's compose for db+web); Ruby pinned; env-driven database.yml; README, .editorconfig, .env.example | Boots in Docker, `/up` returns 200 | health-check request spec — DONE (see docs/step7/commit-0.1.md) |
| 0.2 | ~~separate docker-compose commit~~ — folded into 0.1. Redis + MongoDB services added to compose in Milestones 3 & 5 when first needed | — | — |
| 0.3 | Backend CI: RuboCop, RSpec, Brakeman, bundler-audit; GitHub Actions matrix migrating public + one tenant fixture schema | Pipeline green on skeleton | CI config itself |
| 0.4 | React SPA skeleton (Vite + TS); ESLint, Prettier, Jest/RTL; frontend CI | SPA builds + serves a blank shell | smoke render test |

Ship 0.x → you have a deployable empty app with quality gates.

---

## Milestone 1 — Multi-tenancy foundation (public schema)

| # | Commit | Deployable because | Tests |
|---|---|---|---|
| 1.1 | Add & configure Apartment; schema-per-tenant; excluded-models list stub | No tenants yet; default schema behaves normally | config spec |
| 1.2 | `Tenant` model + public migration (name, subdomain, schema_name, status, deleted_at); reserved-subdomain + lowercase-normalization validations | Table added, unused by request path | model spec incl. reserved words, normalization |
| 1.3 | `TenantProvisioningService` + async `ProvisionTenantJob` (create schema, seed) | Callable from console; not yet web-exposed | service spec (schema created), job spec |
| 1.4 | `Current` attributes + `TenantResolver` before_action (subdomain → switch!; 404 on miss; suspended → block) | Wired but tolerant when no subdomain (apex passes through) | request spec: valid/invalid/suspended subdomain |

Ship 1.x → tenants can be provisioned and resolved by subdomain.

---

## Milestone 2 — Identity & authentication

| # | Commit | Deployable because | Tests |
|---|---|---|---|
| 2.1 | `User` model + public migration (citext email unique, password_digest, status, deleted_at); has_secure_password | Table added, no endpoints | model spec (email normalization, uniqueness incl. soft-deleted) |
| 2.2 | `Membership` model + migration (user/tenant/role/status, unique(user,tenant)) | Join table; unused by requests | model spec (one active per pair) |
| 2.3 | `RefreshToken` model + migration (token_digest, expiry, revoked_at) | Table + logic, not yet issued | model spec |
| 2.4 | `JwtCodec` wrapper + `AuthenticationService` (verify creds, issue access+refresh, rotation, reuse-detection) | Service layer; console-usable | service specs incl. rotation & reuse revoke |
| 2.5 | REST auth endpoints: register, login, refresh, logout, logout_all, `/me` (apex host) | First usable feature; standalone | request specs incl. 401 paths |
| 2.6 | Membership authorization gate + `ApplicationPolicy` base + `verify_authorized` fail-closed hook | Gate active on tenant routes (none yet besides tenants) | policy specs, 403/404 cross-tenant |

Ship 2.x → users register/log in, JWT issued, tenant membership gate enforced.

---

## Milestone 3 — API infrastructure (both surfaces)

| # | Commit | Deployable because | Tests |
|---|---|---|---|
| 3.1 | REST `Api::V1` base controller: standard error envelope, exception→status mapping, request_id, strong-params conventions | Infra; a demo `GET /api/v1/ping` proves envelope | request spec (envelope shape, codes) |
| 3.2 | Tenant + membership REST management endpoints (create tenant 202, invite/revoke membership, api_key CRUD placeholder) | Uses gate from 2.6 | request specs |
| 3.3 | `ApiKey` model + migration (public, tenant-scoped, hashed) + dual-auth resolver normalizing JWT **or** Api-Key into `Current.actor` | REST accepts both credentials; GraphQL rejects keys | model + auth strategy specs |
| 3.4 | GraphQL setup: `graphql` gem, base schema mounted at `/graphql`, base resolver auth guard, `graphql-batch` loader, depth/complexity limits, introspection off in prod | `{ me }` query works end-to-end | GraphQL request spec (auth, complexity cap) |
| 3.5 | Rack::Attack rate limiting (per-user/IP/api-key buckets, tighter on auth) + CORS allow-list | Cross-cutting; safe defaults | throttling specs, CORS spec |

Ship 3.x → both transports live with auth, limits, error contract.

---

## Milestone 4 — Inventory vertical slice (tenant schema)

Behind an `inventory` feature flag until 4.6 is done.

| # | Commit | Deployable because | Tests |
|---|---|---|---|
| 4.1 | Inventory engine scaffold (`app/domains/inventory`) mounted; tenant migration for `products` (partial-unique SKU) | Engine loads; table in tenant schema | migration/tenant spec |
| 4.2 | `Product` model + soft delete; REST create/update/delete/show + policy + serializer | Third-party + SPA can CRUD a product | model + request + policy specs |
| 4.3 | `Product` GraphQL type + `products` query (cursor) + `setProductActive` mutation | SPA listing + status change | GraphQL specs |
| 4.4 | `Warehouse` model + migration + REST CRUD + GraphQL `warehouses` query | Independent resource | model + request + GraphQL specs |
| 4.5 | `StockLevel` + `StockMovement` migrations (CHECK >=0, polymorphic actor, append-only) | Tables only; not yet written | migration specs (constraints) |
| 4.6 | `StockMovementService` (single transaction, `SELECT … FOR UPDATE`, no-negative rule) + REST record/show + GraphQL `recordStockMovement`, `stockLevels`, `stockMovements` | Full slice; flip flag on | service specs (concurrency, insufficient stock, projection correctness) + request + GraphQL specs |

Ship 4.x → the end-to-end vertical proving the pattern.

---

## Milestone 5 — Audit logging pipeline (ADR-0007)

| # | Commit | Deployable because | Tests |
|---|---|---|---|
| 5.1 | `ActivityLog` value object + async `EmitActivityLogJob`; Redis Stream producer | Emits without a sink yet (buffered); no request impact | job spec, producer spec |
| 5.2 | Mongo connection + `activity_logs` collection + `DrainActivityLogWorker` (Redis→Mongo, idempotent on event id) | Consumer independent; at-least-once | worker spec (idempotency, retry) |
| 5.3 | Instrument state-changing operations (auth, product, stock, membership, api_key) to emit events with polymorphic actor | Cross-cutting; async so safe | integration specs asserting events emitted |

Ship 5.x → durable, queryable audit trail, decoupled from requests.

---

## Milestone 6 — Frontend integration

| # | Commit | Deployable because | Tests |
|---|---|---|---|
| 6.1 | Auth flow: login/register screens, token storage (in-memory + refresh), silent refresh, logout | SPA can authenticate | RTL + MSW specs |
| 6.2 | Apollo client for GraphQL + REST client; tenant-subdomain routing from `/me` memberships | Wiring; guarded routes | routing/auth specs |
| 6.3 | Product list (GraphQL) + create/edit (REST) + activate toggle (GraphQL mutation) | First real screen | component + integration specs |
| 6.4 | Warehouse + stock screens (levels view, record-movement form) | Completes the slice UI | component specs |

Ship 6.x → usable end-to-end product.

---

## Milestone U — Framework upgrade demonstrations (deliberate)

We intentionally start on **Rails 7.1.6** and **React 16**, then upgrade later as
worked examples — the upgrade *process* is itself a deliverable to demonstrate.

- **U.1 — Rails upgrade** (7.1 → 7.2 → 8.0): bump one minor at a time; run the
  `rails app:update` diff, reconcile `new_framework_defaults`, verify
  `ros-apartment` compatibility at each step, keep CI green between bumps. Removes
  the Brakeman EOL skip once on a supported line.
- **U.2 — React upgrade** (16 → 18): adopt the new `createRoot` API, review
  concurrent-rendering/StrictMode double-invoke effects, update testing-library
  and any class-lifecycle usages.

Until then, two CI accommodations are in place for the intentionally-old Rails,
both to be removed once U.1 lands:

- Brakeman is temporarily disabled (commented in `ci.yml`) — re-enable + configure
  after v1.
- bundler-audit ignores `CVE-2026-33176` (an Active Support DoS whose only fix is
  upgrading Rails off 7.1). All other advisories still fail the build.

## Cross-milestone notes

- **Feature flags:** inventory + frontend verticals flagged until their milestone's final commit; lets partial work merge to `main` safely.
- **Seeds:** a `db/seeds` path that provisions one demo tenant + admin user for local/staging, never prod.
- **Rollback:** because migrations are expand/contract and code reads both old/new shapes during a deploy, any single commit can be reverted without a data migration.
- **Definition of done per commit:** code + tests + docs/ADR touch (if a decision changed) + green CI + deployable. **If the commit adds or changes an API endpoint/payload/status code, it's described as an rswag request spec (ADR-0012) — which serves as the test, the Swagger UI docs, and the Postman import (via OpenAPI). No hand-editing collections.**
- **Sequencing rationale:** infrastructure (tenancy, auth, API surfaces) precedes domain, so the vertical slice in Milestone 4 drops onto finished rails; audit and frontend layer on last because they depend on the domain existing.
