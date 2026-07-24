# ADR-0008: REST API over GraphQL

**Status:** Superseded by ADR-0009
**Date:** 2026-07-24

> Superseded: we now expose BOTH a GraphQL surface (first-party SPA) and a REST
> surface (third-party integrators + individual CRUD). See ADR-0009. The REST
> reasoning below still holds for the REST surface; the "no GraphQL" conclusion
> was reversed.

## Context

The React SPA (ADR: decoupled frontend) needs an API contract. Two options: a RESTful JSON API or GraphQL.

## Decision

Expose a versioned RESTful JSON API (`/api/v1/...`). No GraphQL for now.

## Alternatives Considered

- GraphQL — lets the client compose arbitrary queries and fetch exactly the fields it needs, avoiding over/under-fetching. Rejected for now: the domain is strongly resource-oriented, the SPA's data needs are predictable, and GraphQL complicates per-field authorization, caching, and rate limiting — all of which matter for a multi-tenant SaaS with strict isolation requirements.
- REST (chosen) — resource-oriented, maps cleanly onto the entities (products, warehouses, stock movements), keeps HTTP caching and per-endpoint authorization straightforward, and has a simple versioning story via URL path.

## Consequences

- Some endpoints may over-fetch; mitigate with sparse-fieldsets / `include` params only if a real need appears.
- Nested/aggregate reads (e.g. dashboards) may need purpose-built endpoints rather than client-composed queries.
- Revisit GraphQL only if the frontend develops genuinely variable, deeply-nested read requirements that REST endpoints can't serve without proliferation.

## Related

Depends on: ADR-0001 (monolith), ADR-0003 (engines expose their own controllers/routes)
