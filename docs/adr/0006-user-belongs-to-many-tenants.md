# ADR-0006: One global user identity can belong to many tenants

**Status:** Accepted
**Date:** 2026-07-24

## Context

Needed to decide whether a user account is scoped to a single tenant (create a new account per organization) or is a single global identity that can be associated with multiple tenants (like a Slack account across workspaces).

## Decision

A single `Identity::User` (global, `public` schema) can hold multiple `Identity::Membership` records, each linking to a different `Identity::Tenant` with its own `role`. One login, many tenants; access to any given tenant requires an active membership.

## Alternatives Considered

- One user per tenant (user record lives inside the tenant's own data) — simpler mental model, but a consultant or user working with multiple client organizations would need a separate account and separate login per tenant.
- Global user with many tenant memberships (chosen) — one identity, one login, switch context via subdomain (ADR-0004) and membership check. Requires identity tables to be global/shared rather than duplicated per tenant schema (informs ADR-0002's excluded-models list).

## Consequences

- `Identity::User`, `Identity::Tenant`, `Identity::Membership`, `Identity::RefreshToken` must live in the `public` schema and be excluded from Apartment's schema switching.
- Membership becomes the sole authorization boundary between "who is this person" and "what can they do in this specific tenant" — must enforce one active membership per (user, tenant) pair.
- Role is currently a simple enum on Membership; if permission granularity grows, this can be extracted into a separate Role model without affecting Inventory or other domains, since only Identity owns Membership.

## Related

Informs: ADR-0002 (schema-per-tenant, excluded models), ADR-0004 (subdomain resolution + membership gate)
