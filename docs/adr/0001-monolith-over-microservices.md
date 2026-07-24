# ADR-0001: Monolith over microservices

**Status:** Accepted
**Date:** 2026-07-24

## Context

The product is a multi-tenant SaaS covering the full supply chain: inventory, purchasing, sales orders, logistics. These domains are transactionally related (e.g. a sales order decrementing stock must be consistent). Team is small at this stage; there is one deploy unit today.

## Decision

Build a single Rails monolith. Organize internal domains (Identity, Inventory, and later Purchasing, Sales, Logistics) as separate bounded contexts within the same codebase (see ADR-0003), not as separate services.

## Alternatives Considered

- Microservices per domain — rejected for now. Adds network calls, distributed transaction handling, and deployment/ops overhead with no current scaling or team-topology need. Violates YAGNI at this stage.
- Modular monolith (chosen) — keeps a single transaction boundary and deploy unit, while enforcing domain boundaries in code (Rails engines, ADR-0003) so a future extraction to services is possible without a rewrite.

## Consequences

- Simpler ops, single deploy, single database connection pool, easy cross-domain transactions.
- Must actively enforce module boundaries via code structure and review, since the framework won't stop a shortcut like one engine reaching into another's tables.
- Revisit if a specific module needs independent scaling or an independent release cadence.

## Related

Depends on: none
Informs: ADR-0003 (module structure)
