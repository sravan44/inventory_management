# ADR-0011: Application layers (service/worker/serializer/decorator) + mailer + admin

**Status:** Accepted
**Date:** 2026-07-24

## Context

We need consistent, named seams for behavior so models and controllers stay thin,
logic is reusable across REST and GraphQL (ADR-0009), and everything is testable.
We also need transactional email and an internal admin capability.

## Decision

Adopt a layered convention (full detail in `docs/PATTERNS.md`):

- **Service objects** (`app/services`, `.call`) own business operations.
- **Workers** (`app/jobs`, ActiveJob → Sidekiq in M5) own async side-effects; thin
  wrappers over services; pass ids; idempotent.
- **Serializers** (`app/serializers`, **Blueprinter**) shape JSON output.
- **Decorators** (`app/decorators`, PORO `SimpleDelegator` via `ApplicationDecorator`)
  own presentation/computed values.
- **Mailers** (`app/mailers`, **ActionMailer**) send transactional email, always
  via `deliver_later` (enqueued on the worker queue).

## Alternatives Considered

- **Serializer library:** Blueprinter (chosen) vs. ActiveModel::Serializers
  (effectively unmaintained) vs. Alba/JBuilder. Blueprinter is fast, simple, and
  supports named views for versioning.
- **Decorators:** plain PORO/`SimpleDelegator` (chosen) vs. **Draper**. Draper is
  view-helper oriented and adds friction in an `api_only` app; a PORO base gives
  the same delegation with zero coupling. Draper remains an option if we later
  need view helpers.
- **Fat models/controllers:** rejected — the reason this ADR exists.

## RailsAdmin — evaluated, deferred

Requested for an internal admin UI. RailsAdmin needs the full Rails view/middleware
stack. We therefore run the app with **`config.api_only = false`** (full stack)
while staying **API-first**: JSON controllers inherit `ActionController::API` (lean,
no CSRF/session weight), and the heavier stack is available to a future
`Admin::BaseController < ActionController::Base`. This removes the middleware
blocker up front.

The remaining, real caveat is **schema-per-tenant** (ADR-0002): RailsAdmin operates
on whichever schema is active, so it must be (a) mounted on a separate platform host
(e.g. `admin.app.com`, never a tenant subdomain), (b) restricted to platform
super-admins, and (c) given an explicit tenant switcher to choose which schema to
inspect.

Decision: full stack now (done); **defer the RailsAdmin mount to its own milestone**
with the host/super-admin/tenant-switcher handling above. If a lighter touch
suffices, Avo or a hand-built admin namespace are alternatives to revisit then.

> UPDATE: RailsAdmin was subsequently enabled — see **ADR-0014** (isolated `admin`
> subdomain, HTTP-Basic gate, public/identity models, `super_admin` flag added).

## Consequences

- New code lands in the right layer by default; reviews enforce "no business logic
  in controllers/resolvers/models."
- Add gems when first used (Blueprinter in Milestone 4). `ApplicationDecorator`
  and `ApplicationMailer` base classes added now.
- ActionMailer configured per-environment (test uses `:test`; SMTP via ENV in
  prod). Mail always enqueued, never sent inline.
- RailsAdmin carries real multi-tenant + api_only caveats; it gets a proper
  milestone rather than a quick mount.

## Related

Depends on: ADR-0003 (domain namespaces), ADR-0009 (shared layer under two
transports), ADR-0002 (schema-per-tenant shapes the admin approach).
Detailed guide: `docs/PATTERNS.md`.
