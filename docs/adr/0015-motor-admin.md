# ADR-0015: Adopt Motor Admin for the platform admin UI

**Status:** Accepted
**Date:** 2026-07-25
**Follows:** ADR-0014 (RailsAdmin attempted, deferred)

## Context

We want a platform admin UI but RailsAdmin v3 required a JavaScript asset build
that doesn't fit this API-first app (ADR-0014). We need an admin that is
self-contained on assets.

## Decision

Use **Motor Admin** (`motor-admin`). It ships prebuilt assets in the gem (no JS
build step), auto-discovers models, and mounts as a Rack app.

- **Mount:** `mount Motor::Admin => "/admin"`.
- **Gate:** HTTP Basic against `ADMIN_USER` / `ADMIN_PASSWORD` (constant-time
  compare, fails closed), applied by reopening `Motor::ApplicationController` in a
  `to_prepare` block (`config/initializers/motor.rb`). Same stopgap posture as
  before; a super-admin session/SSO using `users.super_admin` remains the
  follow-up.
- **Scope:** operates on `public` (global identity models). Tenant-scoped data +
  a tenant switcher are a later iteration.

## Alternatives Considered

- RailsAdmin v3 — deferred (ADR-0014); asset build too heavy here.
- Administrate / Trestle — Sprockets-based, more setup than Motor.
- Avo / ActiveAdmin — importmap or webpacker/Sass; same asset class as RailsAdmin.
- Roll-your-own `Admin::` namespace — most control, best schema-per-tenant fit, but
  more code. Reserved as the fallback if Motor doesn't fit.
- Motor Admin (chosen) — self-contained assets, least setup friction, DB-driven.

## Consequences

- Adds Motor's own tables (its engine migrations). Install with
  `bin/rails railties:install:migrations` then `db:migrate` (dev + test).
- Motor stores dashboards/queries/config in the DB — flexible, but it's app state
  to be aware of (and it lives in `public`).
- Auth is a Basic-auth stopgap; harden with the `super_admin` session gate later.
- Motor auto-discovers all models; review what it exposes and restrict if needed.

## Related

Follows: ADR-0014. Depends on: full Rails stack (not api_only), ADR-0002
(schema-per-tenant shapes the admin scope).
