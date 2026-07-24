# ADR-0003: Rails engines for domain module boundaries

**Status:** Accepted
**Date:** 2026-07-24

## Context

The monolith (ADR-0001) will contain several bounded contexts: Identity, Inventory, and later Purchasing, Sales, Logistics. Left unstructured, a monolith tends to accumulate cross-domain coupling (e.g. Inventory code reaching directly into Identity's tables). Needed a way to make boundaries hard to violate, not just a convention.

## Decision

Structure each domain as a namespaced Rails engine under `app/domains/<domain>` (e.g. `app/domains/identity`, `app/domains/inventory`). Cross-domain access happens only through explicit service objects exposed by each engine (e.g. `Identity::CurrentUser`, `Identity::TenantContext`), never through direct ActiveRecord association traversal across domains.

## Alternatives Considered

- Plain namespaced modules (`Inventory::Product` under `app/models`) — faster to scaffold, no engine boilerplate, but boundaries are enforced only by code review discipline. Easy to accidentally couple domains under deadline pressure.
- Rails engines (chosen) — more setup ceremony (engine scaffolding, isolated namespaces, own routes/migrations per engine), but the framework itself makes cross-engine shortcuts more awkward to write, which is the point. Also makes a future extraction of a domain into its own service more mechanical if that ever becomes necessary (see ADR-0001).

## Amendment (2026-07-24, commit 1.2)

We start each domain as a **namespaced module** (`Identity::Tenant` under
`app/models/identity/`, `self.table_name` set explicitly), NOT a full mountable
engine, to avoid engine ceremony this early. The namespace gives the same code
boundary and dependency direction; promotion to a real engine later is largely a
file move plus mounting, with no model-code changes. The engine decision above
still stands as the target end-state — this defers the *mechanism*, not the
boundary. Discipline (no cross-domain table access; go through service objects)
is enforced by review until the engine makes it structural.

## Consequences

- New domains (Purchasing, Sales, Logistics) follow an established, repeatable scaffold.
- Slightly higher setup cost per domain than plain modules.
- Dependency direction must still be enforced by convention at the service-object layer: Inventory may depend on Identity, not vice versa; peer domains (Purchasing, Sales) integrate through events/service calls, not direct model access.

## Related

Depends on: ADR-0001 (monolith)
