# ADR-0002: Schema-per-tenant multi-tenancy via Apartment

**Status:** Accepted
**Date:** 2026-07-24

## Context

This is a multi-tenant SaaS. Tenant data isolation is security-critical. Two isolation models were viable: row-level (shared tables + tenant_id column) or schema-per-tenant (separate Postgres schema per tenant).

## Decision

Use schema-per-tenant isolation on Postgres, implemented with the Apartment gem for schema switching, per-tenant migrations, and tenant provisioning.

## Alternatives Considered

- Row-level isolation (tenant_id on every table) — simpler ops, single schema to migrate, but isolation depends entirely on every query remembering to scope by tenant_id. One missed `where(tenant_id: ...)` leaks data across tenants.
- Schema-per-tenant, custom middleware — full control over `search_path` switching, no dependency on Apartment's maintenance cadence, but more code to write and test upfront (tenant creation, migration fan-out, connection handling).
- Schema-per-tenant via Apartment (chosen) — isolation enforced at the database level, not just in application code. Faster to stand up than custom middleware. Tradeoff accepted: dependency on a less actively maintained gem, with some Rails-version lag risk.
- MySQL (revisited 2026-07-24) — considered switching the engine (partly to match a previous product that ran MySQL in prod). Rejected: MySQL has no schema-within-database namespace, so Apartment falls back to *database-per-tenant* rather than schema-per-tenant; MySQL also lacks partial/filtered unique indexes, which our reusable-after-soft-delete SKU/warehouse-code design depends on (`UNIQUE ... WHERE deleted_at IS NULL`). Running Postgres in dev but MySQL in prod was also rejected on dev/prod-parity grounds (tests would never exercise the prod engine). Decision: **PostgreSQL in all environments.**

## Consequences

- Strong isolation: a bug in a query can't leak another tenant's rows, because the wrong schema simply isn't in the search_path.
- Migrations must run per-tenant-schema in addition to the shared/public schema; tooling and CI need to account for this.
- Certain models must be excluded from schema switching (see ADR-0004/0005 context: `Identity::User`, `Identity::Tenant`, `Identity::Membership`, `Identity::RefreshToken` live in `public` and are marked as Apartment-excluded models) since identity is global across tenants.
- Gem risk accepted knowingly; if Apartment's maintenance stalls, this can be swapped for custom `search_path` middleware later without changing the schema-per-tenant decision itself.
- Implementation note (commit 1.1): we use the maintained fork **`ros-apartment`** (required as `apartment`), since the original `apartment` gem no longer supports modern Rails. This directly realizes the mitigation above. We also set `config.active_record.schema_format = :sql` so Postgres-specific features (multiple schemas, partial unique indexes, citext, jsonb) survive schema dumps.

## Related

Depends on: ADR-0006 (user belongs to many tenants — this is why identity models must be excluded from switching)
Informs: ADR-0004 (subdomain tenant resolution)
