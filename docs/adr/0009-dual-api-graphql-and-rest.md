# ADR-0009: Dual API surface — GraphQL (first-party) + REST (third-party)

**Status:** Accepted
**Date:** 2026-07-24
**Supersedes:** ADR-0008

## Context

ADR-0008 chose REST only. Two distinct consumers actually exist with different needs:
1. The first-party React SPA — wants flexible listing/reads and status-change operations, iterates quickly alongside the backend.
2. Third-party integrators — want a stable, versioned, simple contract for individual resource operations.

Serving both well with a single style forces a compromise. This is a recognised pattern (e.g. GitHub, Shopify expose both).

## Decision

Expose two transport surfaces over the **same** domain service and policy layer:

- **GraphQL** (`POST /graphql`, tenant subdomain, user JWT only) — first-party SPA. Handles **listing (queries)** and **status-change mutations** (activate/deactivate product, change/revoke membership role, record stock movement, change tenant status).
- **REST** (`/api/v1`, tenant subdomain) — **individual resource create/update/delete/show**. Consumed by third-party integrators (per-tenant API key, ADR-0010) and also by the first-party SPA (user JWT) for create/update/delete.

**Hard rule:** resolvers and controllers are thin transport adapters only. All business logic and authorization live in shared service objects and policy objects. Neither transport re-implements a rule the other has. This is what keeps a dual surface safe rather than a source of divergent behavior and security gaps.

## Alternatives Considered

- REST only (ADR-0008) — one surface, simplest, but no flexible first-party query surface.
- GraphQL only — great for the SPA, poor stable contract for third parties (introspection-driven, breaking-change management harder for external consumers).
- Both, sharing a domain layer (chosen) — each consumer gets the right tool; cost is two transports to maintain and a strict discipline that all logic stays in the shared layer.

## Consequences

- GraphQL introduces concerns REST didn't: N+1 resolution (needs batch loading, e.g. `graphql-batch`), query depth/complexity limiting as the DoS control (replacing simple per-endpoint rate limits), and introspection disabled/restricted in production.
- Authorization is enforced in both surfaces via the same policy objects — GraphQL at field/mutation resolvers, REST at controller actions. Fails closed by default in both.
- Two versioning stories: REST via URL path (`/api/v2`); GraphQL via schema evolution (deprecate fields, never breaking-remove).
- Overlap risk: recording a stock movement is available via GraphQL mutation (first-party) and REST (third-party). Acceptable precisely because both call `Inventory::StockMovementService` — identical behavior guaranteed.

## Related

Supersedes: ADR-0008
Depends on: ADR-0003 (engines expose both a GraphQL type set and REST controllers), ADR-0010 (API key auth for the REST third-party path)
