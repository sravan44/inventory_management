# ADR-0010: Per-tenant API keys for third-party REST access

**Status:** Accepted
**Date:** 2026-07-24

## Context

Third-party integrators consume the REST API (ADR-0009). They must not authenticate with a user's login JWT — those are short-lived, tied to a human session, and carry a person's identity. A machine credential is needed, scoped to a tenant.

## Decision

Introduce **per-tenant API keys**. A tenant admin generates a key (via the SPA); the raw key is shown once, and only its hash (`token_digest`) is stored. Third-party REST calls send it as `Authorization: Api-Key <key>` (or `X-Api-Key`). GraphQL does **not** accept API keys — it is first-party, user-JWT only.

An API key carries a role/scope so the same policy objects can authorize it exactly like a user membership. Because the ledger/audit actor can now be either a user or an API key, the audit actor becomes **polymorphic** (`actor_type` ∈ {user, api_key}, `actor_id`) rather than a plain `created_by_user_id`.

## Alternatives Considered

- OAuth2 client-credentials flow — industry standard for larger integration ecosystems, supports short-lived tokens and scoped clients, but significantly more to build (authorization server, token exchange, rotation). Deferred; API keys are the right first public-API credential and a cleaner learning step. Can be layered on later without changing the domain layer.
- Reuse user JWTs for third parties — least work, but conflates human and machine identity, leaks user session semantics to integrations, and complicates revocation. Rejected.
- Per-tenant API keys (chosen) — simple to build and reason about, standard for a first public API, cleanly revocable, scoped to one tenant.

## Consequences

- New table `api_keys` (public schema, tenant-scoped): `id`, `tenant_id` FK, `name`, `token_digest` (unique), `scopes`/`role`, `last_used_at`, `expires_at` nullable, `revoked_at` nullable, timestamps. Store only the hash; show raw key once.
- Audit/ledger actor is polymorphic: `stock_movements` and activity logs record `actor_type` + `actor_id` (user or api_key). This refines the earlier `created_by_user_id`-only design (DATABASE.md addendum).
- Key rotation and revocation are first-class: revoke sets `revoked_at`; rotation issues a new key and revokes the old after a grace window.
- Rate limiting keyed on API key id for third-party traffic, separate buckets from user traffic.
- Security: keys transmitted only over TLS, hashed at rest, never logged, scoped to least privilege.

## Related

Depends on: ADR-0009 (REST is the third-party surface), ADR-0005 (JWT remains the first-party/user credential)
Refines: DATABASE.md (`stock_movements` actor becomes polymorphic; adds `api_keys`)
