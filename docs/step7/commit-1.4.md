# Commit 1.4 — Current + TenantResolution (narrated)

Goal: at request time, read the tenant from the **subdomain**, switch into that
tenant's Postgres schema for the action, and reject bad cases (unknown subdomain
→ 404, non-active tenant → 403). This completes **Milestone 1** — the app is now
genuinely multi-tenant end to end.

Depends on: commits 1.1–1.3.

---

## Step A — `Current` (request-scoped context)

`app/models/current.rb` — a `ActiveSupport::CurrentAttributes` subclass holding
`tenant` (user + membership come in Milestone 2).

Why: so any layer can read `Current.tenant` without passing it through every
method. Rails resets it automatically between requests, so there's no leakage from
one request to the next. Rule: only the resolver/auth layers *write* to it;
everything else reads.

---

## Step B — `TenantResolution` concern (the resolver)

`app/controllers/concerns/tenant_resolution.rb`. An `around_action` that wraps
every action in the controller:

```ruby
def within_tenant
  tenant = Identity::Tenant.kept.find_by(subdomain: request_subdomain)
  return render 404 if tenant.nil?
  return render 403 unless tenant.active?
  Current.tenant = tenant
  Apartment::Tenant.switch(tenant.schema_name) { yield }   # <- the important bit
end
```

The pieces worth understanding:

- **`request.subdomain`** — Rails parses this from the `Host` header. `acme.app.com`
  → `"acme"`; the apex `app.com` → `""` (which we turn into `nil` → 404).
- **`.kept`** — soft-deleted tenants don't resolve (they 404), reusing the scope
  from commit 1.2.
- **non-active → 403** — a suspended or still-provisioning tenant *exists* but
  isn't usable, so it's `403 tenant_unavailable`, distinct from a `404` for a
  subdomain that matches nothing. (Existence vs. permission — different signals.)
- **`Apartment::Tenant.switch(schema) { yield }`** — the **block form** is chosen
  deliberately: it sets the schema, runs the action (`yield`), and **always
  resets** the `search_path` afterward, even if the action raises. With a threaded
  server + pooled connections, a leaked schema would mean the *next* request on
  that connection reads the *wrong tenant's* data — a serious isolation bug. The
  block form is the guardrail.
- **Why not Apartment's built-in subdomain elevator?** Because we want explicit
  404/403 handling and to run this *before* authentication. This is exactly the
  "custom resolver over raw elevator" call recorded in ADR-0004.

---

## Step C — Base controller + a first consumer

- `app/controllers/tenant_scoped_controller.rb` — `TenantScopedController <
  ApplicationController` that `include`s `TenantResolution`. Every tenant-scoped
  endpoint inherits from this; the apex/health endpoints do **not** (so `/up`
  keeps working with no subdomain).
- `app/controllers/current_tenant_controller.rb` — a minimal `show` that returns
  the resolved tenant. It's a sanity endpoint and the first real user of the
  resolver. Route added in `config/routes.rb`: `get "current_tenant"`.

---

## Step D — One required test-env tweak (easy to miss)

Rails' Host Authorization middleware can reject the made-up hosts our specs use
(`acme.example.com`). Allow them in **test** only. In
`config/environments/test.rb`, inside the `configure` block:

```ruby
# Allow arbitrary Host headers so subdomain request specs work.
config.hosts.clear
```

(Do NOT do this in production — host allow-listing is a security control there.)

---

## Step E — Tests

`spec/requests/tenant_resolution_spec.rb` drives real HTTP with different `Host`
headers and asserts: active tenant resolves (200 + subdomain echoed), unknown
subdomain → 404 `unknown_tenant`, suspended tenant → 403 `tenant_unavailable`,
apex host → 404, soft-deleted tenant → 404.

```bash
docker compose exec web bundle exec rspec spec/requests/tenant_resolution_spec.rb
```

Try it live (Docker maps localhost; use a wildcard host like `lvh.me` which
resolves any subdomain to 127.0.0.1):

```bash
# create + provision a tenant first
docker compose exec web rails runner '
  t = Identity::Tenant.create!(name: "Acme", subdomain: "acme")
  Identity::ProvisionTenantJob.perform_now(t.id)
'
curl -H "Host: acme.lvh.me" http://localhost:3000/current_tenant
# => {"data":{"id":"1","name":"Acme","subdomain":"acme","status":"active"}}
curl -i -H "Host: nope.lvh.me" http://localhost:3000/current_tenant
# => HTTP/1.1 404 Not Found  {"error":{"code":"unknown_tenant",...}}
```

---

## Milestone 1 complete

The app now: provisions per-tenant schemas (1.3), resolves the tenant from the
subdomain, switches the schema safely per request, and rejects unknown/inactive
tenants (1.4). Everything reads tenant context from `Current`.

Next milestone: **Identity & authentication** (users, memberships, JWT).

## Commit message

```
feat(tenancy): resolve tenant from subdomain + switch schema per request

- Current (ActiveSupport::CurrentAttributes) holds request-scoped tenant
- TenantResolution around_action: subdomain lookup, 404 unknown, 403 inactive,
  Apartment block-form switch that always resets search_path
- TenantScopedController base + CurrentTenant sanity endpoint + route
- request specs (active/unknown/suspended/apex/soft-deleted)
- test.rb: config.hosts.clear to allow subdomain hosts in specs
```
