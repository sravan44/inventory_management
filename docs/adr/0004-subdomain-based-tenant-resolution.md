# ADR-0004: Subdomain-based tenant resolution

**Status:** Accepted
**Date:** 2026-07-24

## Context

Users can belong to multiple tenants (ADR-0006), and tenant data lives in per-tenant Postgres schemas (ADR-0002). The request needs a deterministic way to know which tenant's schema to switch into before any tenant-scoped query runs, independent of which JWT the user presents.

## Decision

Resolve the active tenant from the request subdomain (e.g. `acme.app.com` → tenant with `subdomain: "acme"`), not from user selection after login or from a claim embedded in the JWT.

Request flow, in order:
1. `Identity::TenantResolver` (before_action, runs first) parses `request.subdomain`, looks up the `Identity::Tenant`, and calls `Apartment::Tenant.switch!(tenant.schema_name)`. No matching tenant → `404`, before authentication even runs.
2. JWT authentication resolves `Current.user`. This works regardless of the active schema because Identity models are Apartment-excluded (see ADR-0002) and always resolve against `public`.
3. Authorization gate: `Identity::Membership.exists?(user: Current.user, tenant: Current.tenant)`. No membership → `403` (the user is authenticated, but has no access to this particular tenant).

## Alternatives Considered

- Tenant selection via UI/session after login (Slack-style workspace switcher without subdomain routing) — works for one-user-many-tenants, but doesn't give each tenant a stable, linkable, brandable URL, and adds a stateful "current workspace" concept to an otherwise stateless JWT API.
- Tenant ID embedded as a JWT claim — would require reissuing/refreshing tokens on every tenant switch, and ties a stateless identity token to a specific tenant, undermining the "one identity, many tenants" model.
- Subdomain-based resolution (chosen) — tenant is a property of the URL, not the token. The same JWT works across every tenant subdomain the user has membership in.

## Consequences

- Reserved subdomains (`www`, `api`, `admin`, etc.) must be blocked at tenant-creation validation to avoid collision with real tenant slugs.
- Suspended/deactivated tenants must be checked in the resolver itself, not just membership existence.
- Subdomain must be normalized (lowercase) both on creation and on lookup.
- Local dev/test needs an explicit subdomain strategy (e.g. `lvh.me`, or a test host header helper) so specs aren't fighting DNS resolution.

## Related

Depends on: ADR-0002 (schema-per-tenant), ADR-0006 (user belongs to many tenants)
