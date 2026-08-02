# ADR-0014: RailsAdmin — attempted, then deferred (asset pipeline)

**Status:** Deferred
**Date:** 2026-07-25
**Refines:** ADR-0011 (which deferred RailsAdmin)

> **Outcome:** We attempted to enable RailsAdmin v3 but hit its hard requirement
> for a JavaScript-based asset build (esbuild via its install generator + an
> importmap/cssbundling/webpacker pipeline). It doesn't ship Sprockets-ready
> `.css`/`.js`, so hand-wiring a manifest + Sass compiler doesn't produce the
> assets. In an API-first app this is disproportionate setup for the current
> value, so we **reverted the gem/mount/initializer** and kept only the
> `users.super_admin` flag (harmless, already migrated) for when we revisit.
>
> **To re-enable later:** add `rails_admin` + `importmap-rails`, run
> `bin/rails importmap:install` and `bin/rails g rails_admin:install` (choose
> importmap), set `config.asset_source = :importmap`, restore the mount + gate.
> The design below (path/host, gate, scope) still stands as the target.

## Context

ADR-0011 deferred RailsAdmin because `api_only` blocked it. We since switched to
the full Rails stack (api_only = false), so the middleware blocker is gone. We now
want a working platform admin UI, safely, in a schema-per-tenant app.

## Decision

Enable **RailsAdmin now**, with these guardrails:

- **Path mount:** mounted at `/admin`. (Originally isolated to an `admin`
  subdomain; changed to a path mount for simpler local/dev access. The primary
  gate is HTTP Basic below; a super-admin session/SSO is the follow-up that
  hardens it further. If stronger isolation is wanted later, re-add a host
  constraint.)
- **Schema scope:** it operates on `public`, managing the global identity models
  (`Identity::User/Tenant/Membership/RefreshToken`) via `included_models`.
  Tenant-scoped data + a tenant switcher are a later iteration.
- **Access gate:** HTTP Basic against `ADMIN_USER`/`ADMIN_PASSWORD` env vars
  (constant-time compare). A **stopgap** — a proper super-admin session login/SSO
  keyed on the new `users.super_admin` flag is the follow-up.
- **super_admin flag:** added to `users` (platform admin, distinct from a tenant
  "admin" role) to support the future session-based gate.
- **Assets:** RailsAdmin v3 needs an asset pipeline; we add `sprockets-rails` and
  run `rails g rails_admin:install` once to wire assets/manifest.

## Alternatives Considered

- Keep deferring (ADR-0011) — rejected; the blocker's gone and an admin UI is
  useful now.
- Avo / ActiveAdmin — also need an asset pipeline; RailsAdmin was requested.
- Full super-admin SSO up front — deferred; HTTP Basic on an isolated host is an
  acceptable stopgap for an internal tool while the surface is small.

## Consequences

- New infra: `sprockets-rails` + `rails_admin`; an asset install step
  (`rails g rails_admin:install`) that must run in the app environment.
- `ADMIN_USER`/`ADMIN_PASSWORD` must be set (see `.env.example`); without them the
  gate denies all access (fails closed).
- Admin actions currently have no per-record authorization beyond the Basic gate;
  when the super-admin session lands, wire `current_user_method` + audit.
- CI/tests don't exercise RailsAdmin UI; the gate + mount are config, and the
  identity models are covered by their own specs.

## Related

Refines: ADR-0011. Depends on: the full-stack (not api_only) switch — see
`docs/step7/rails-scaffold.md` — and ADR-0002 (schema-per-tenant shapes the admin
scope).
