# ADR-0005: Stateless JWT authentication

**Status:** Accepted
**Date:** 2026-07-24

## Context

Backend is a Rails API consumed by a fully decoupled React SPA. Need horizontal scalability without sticky sessions.

## Decision

Use stateless JWT access tokens plus a persisted, revocable refresh token (`Identity::RefreshToken`: token_digest, expires_at, revoked_at, belongs_to :user). Token encode/decode is isolated behind `Identity::JwtCodec`, a thin wrapper around the `jwt` gem, so the underlying library can be swapped without touching callers.

## Alternatives Considered

- Session/cookie-based auth — simpler CSRF story if frontend and API share a domain, but reintroduces server-side session state, complicating horizontal scaling, and is a worse fit for a subdomain-per-tenant architecture (ADR-0004) where cookies would need to be shared or reissued across subdomains.
- Pure stateless JWT with no refresh/revocation record — simplest, but offers no way to revoke a compromised token or support "log out of all devices" before natural expiry.
- JWT access token + persisted refresh token (chosen) — access tokens stay short-lived and stateless for scaling; the refresh token gives a revocation point without making every request stateful.

## Consequences

- Access tokens are not tenant-scoped (see ADR-0004) — they identify the user only; tenant context comes from the subdomain plus a membership check on every request.
- Revocation requires checking the refresh token table on refresh, not on every access-token-authenticated request — accepted latency/consistency tradeoff (a revoked user's existing access token remains valid until it naturally expires, so access token TTL should be kept short).
- Need key/secret management and rotation strategy for signing tokens (implementation detail, not re-litigated here).

## Related

Depends on: none
Related to: ADR-0004 (tenant is resolved independently of the token)
