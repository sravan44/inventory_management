# Inventory Management — Architecture Overview

This document summarizes the architecture-level decisions for the platform. Individual decisions with full context, alternatives, and tradeoffs live in `docs/adr/`. This file is the map; the ADRs are the record.

## Business context

Multi-tenant SaaS covering the full supply chain: stock tracking, purchasing, sales order fulfillment, multi-warehouse logistics, reporting. This repo's initial scope is the foundation (auth, tenancy, CI) plus one vertical slice (Product/SKU CRUD via the Inventory module) proving the pattern end-to-end. Purchasing, Sales, and Logistics follow the same pattern later.

## Actors

- Tenant Admin — manages their org's users, warehouses, settings
- Warehouse Staff — stock movements, receiving
- Purchasing/Sales roles — POs, sales orders (future)
- Platform Admin — manages tenants themselves, not tenant data
- External API consumers (future integrations)

## Stack

- Backend: Rails, API-only
- Frontend: React SPA (Vite), fully decoupled. First-party via GraphQL, plus REST for individual CRUD
- Third-party integrators: REST `/api/v1` with per-tenant API keys (ADR-0009/0010)
- Database: Postgres, schema-per-tenant (all domain modules isolated per tenant)
- Audit/activity logs: Redis Streams buffer → MongoDB sink, written async (ADR-0007)

## Core decisions (see linked ADRs for full reasoning)

| # | Decision | ADR |
|---|---|---|
| 1 | Modular monolith, not microservices | [ADR-0001](adr/0001-monolith-over-microservices.md) |
| 2 | Schema-per-tenant multi-tenancy via Apartment | [ADR-0002](adr/0002-schema-per-tenant-via-apartment.md) |
| 3 | Domains structured as Rails engines | [ADR-0003](adr/0003-rails-engines-for-module-boundaries.md) |
| 4 | Tenant resolved from subdomain, not token or session | [ADR-0004](adr/0004-subdomain-based-tenant-resolution.md) |
| 5 | Stateless JWT + revocable refresh token | [ADR-0005](adr/0005-jwt-stateless-auth.md) |
| 6 | One user identity can belong to many tenants | [ADR-0006](adr/0006-user-belongs-to-many-tenants.md) |
| 7 | Audit logs via Redis Streams → MongoDB (async) | [ADR-0007](adr/0007-audit-logging-pipeline.md) |
| 8 | ~~RESTful JSON API over GraphQL~~ (superseded by 9) | [ADR-0008](adr/0008-rest-over-graphql.md) |
| 9 | Dual API: GraphQL (first-party) + REST (third-party) | [ADR-0009](adr/0009-dual-api-graphql-and-rest.md) |
| 10 | Per-tenant API keys for third-party REST | [ADR-0010](adr/0010-third-party-api-key-auth.md) |
| 11 | App layers (service/worker/serializer/decorator) + mailer + admin | [ADR-0011](adr/0011-application-layers-and-tooling.md) |
| 12 | API docs via rswag (OpenAPI) → Swagger UI + Postman | [ADR-0012](adr/0012-api-docs-via-rswag-openapi.md) |
| 13 | Dev/test performance strategy (tiered) | [ADR-0013](adr/0013-dev-test-performance-strategy.md) |
| 14 | RailsAdmin — attempted, deferred (asset pipeline); super_admin flag kept | [ADR-0014](adr/0014-rails-admin-enablement.md) |
| 15 | Motor Admin adopted (self-contained assets), gated + at /admin | [ADR-0015](adr/0015-motor-admin.md) |
| 16 | Observability: Sentry + pluggable LLM log viewer (Mongo + file) | [ADR-0016](adr/0016-observability-and-log-viewer.md) |

Detailed schema: [DATABASE.md](DATABASE.md). API contract: [API_DESIGN.md](API_DESIGN.md). Build sequence: [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md). App-layer patterns: [PATTERNS.md](PATTERNS.md).

## Module boundaries

- **Identity** (`public` schema, global) — users, tenants, memberships, refresh tokens, JWT issuance, tenant resolution, authorization policies. Nothing outside Identity touches its tables directly.
- **Inventory** (tenant schema, per-tenant) — products, warehouses, stock levels, stock movements. Depends on Identity for current user/tenant context; never the reverse.
- **Purchasing / Sales / Logistics** (future, tenant schema) — same engine pattern, depend on Inventory + Identity, integrate with each other via service calls/events rather than direct model access.

## Request lifecycle (every API call)

1. `Identity::TenantResolver` reads the subdomain, finds the `Tenant`, switches the Apartment schema. No match → 404.
2. JWT is decoded, `Current.user` is set (Identity tables are Apartment-excluded, always resolve against `public`).
3. `Identity::Membership.exists?(user:, tenant:)` gates access. No membership → 403.
4. Request proceeds with `Current.user`, `Current.tenant`, `Current.membership` available to any module via `Current`, never by reaching through association chains (Law of Demeter).

## Key entities (Identity)

`User` (global) — `Tenant` (global) — `Membership` (global, join: user/tenant/role) — `RefreshToken` (global)

## Key entities (Inventory)

`Product`, `Warehouse`, `StockMovement` (append-only ledger, source of truth), `StockLevel` (materialized projection, written only by `StockMovementService`)

## Patterns in use

Service objects (business operations, keep models thin), policy objects (authorization), ledger/projection pattern (StockMovement → StockLevel), CurrentAttributes (request-scoped context without threading tenant/user through every method signature).

## Non-functional priorities

Tenant data isolation (schema-level, security-critical), horizontal scalability (stateless auth), testability (RSpec/Jest + CI from day one), maintainable module boundaries (new domains added without reshaping the core).

## How to use this folder

- Read `ARCHITECTURE.md` (this file) first for the map.
- Each ADR is self-contained: context, decision, alternatives considered, consequences.
- When a decision changes, don't edit the old ADR's Decision section — add a new ADR that supersedes it and mark the old one's Status as `Superseded by ADR-XXXX`. This keeps the history of *why* intact.
