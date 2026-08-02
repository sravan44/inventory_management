# Commit 3.2 — Tenant + membership management (+ RailsAdmin) (narrated)

Two tracks: the management endpoints, and standing up RailsAdmin in parallel.

Depends on: 2.6 (tenant stack + policies), 3.1 (error envelope).

---

## Track A — management endpoints

### Tenants (apex host, authenticated)
`Api::V1::TenantsController < BaseController`. Creating/choosing a tenant precedes
tenant context, so these live on the apex host.

- **POST /tenants → 202.** Creates the tenant + an **admin membership for the
  creator**, in one transaction, then enqueues `ProvisionTenantJob` and returns
  202 Accepted (the schema builds asynchronously — the client polls `GET
  /tenants/:id` for `status: active`).
- **GET /tenants/:id** — members only. A non-member gets **404, not 403**, so we
  don't leak which tenant ids exist (the show action rescues the policy denial into
  a 404).
- **PATCH / DELETE** — admin only (soft delete).

Authorization: `Identity::TenantPolicy` computes membership from user + tenant
(these run on apex, where `Current.membership` isn't set).

### Memberships (tenant-scoped, admin)
`Api::V1::MembershipsController < TenantBaseController` — so it inherits the full
stack (resolution + auth + membership + `verify_authorized`).

- **POST /memberships** — invite an email. Find-or-create the user as `invited`
  (placeholder password until they accept), create an `invited` membership.
- **DELETE /memberships/:id** — revoke (soft). Scoped to `Current.tenant`, so a
  cross-tenant id → 404.

Authorization: `Identity::MembershipPolicy` — admin-only, reading
`Current.membership.role`. (Listing members + role changes are GraphQL in M4.)

### Tests
- `tenants_spec.rb` — rswag (feeds OpenAPI): 202 create, 401.
- `memberships_spec.rb` — plain request spec (tenant-scoped needs the Apartment
  switch stubbed + a Host header): invite 201, non-admin 403, revoke 204,
  cross-tenant 404. Built with **factories**.

---

## Track B — RailsAdmin (platform admin UI, ADR-0014)

Now that we're on the full Rails stack, RailsAdmin is viable. Guardrails:

- **Mounted at `/admin`** (path mount), HTTP-Basic-gated.
- **Scope:** operates on `public`; manages the identity models via
  `included_models`. Tenant data + a switcher come later.
- **Gate:** HTTP Basic against `ADMIN_USER`/`ADMIN_PASSWORD` (constant-time
  compare). A stopgap; a super-admin session/SSO using the new `users.super_admin`
  flag is the follow-up.

### RailsAdmin asset setup (no generator needed)
RailsAdmin v3 uses the Sprockets asset pipeline, which refuses to boot without a
manifest. We ship one at `app/assets/config/manifest.js` (links RailsAdmin's
precompiled CSS/JS) and add the `ostruct` gem (RailsAdmin uses OpenStruct, which
isn't a default gem on newer Ruby). So you do NOT need `rails g
rails_admin:install` — just install + boot:

```bash
docker compose run --rm web bundle install
docker compose build web
docker compose up -d
docker compose exec web bin/rails db:migrate          # adds users.super_admin
docker compose exec -e RAILS_ENV=test web bin/rails db:migrate
```

If boot still complains about a specific `rails_admin/...` asset link, the exact
asset name in `manifest.js` may differ by RailsAdmin patch version — paste the
error and adjust those two `//= link` lines. Then create a platform admin and
visit the admin host:

```bash
docker compose exec web bin/rails runner '
  u = Identity::User.find_or_create_by!(email: "root@platform.io") { |x| x.password = "change-me-please" }
  u.update!(super_admin: true)
'
# set ADMIN_USER / ADMIN_PASSWORD in .env, then open:
#   http://localhost:3000/admin
```

---

## Tests (both tracks)

```bash
docker compose exec web bundle exec rspec spec/requests/api/v1 spec/policies
```

---

## Commit message

```
feat(api): tenant + membership management; enable RailsAdmin (ADR-0014)

- TenantsController: create(202)+provision, show(404-for-non-members), update/destroy
- MembershipsController: invite/revoke (tenant-scoped, admin-only)
- Identity::TenantPolicy + Identity::MembershipPolicy
- RailsAdmin on admin subdomain, HTTP-Basic gate, identity models; users.super_admin
- rswag tenants spec + membership request spec (factories)
```
