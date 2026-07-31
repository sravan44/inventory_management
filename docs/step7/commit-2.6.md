# Commit 2.6 — Membership gate + policy base (narrated)

Goal: enforce the authorization boundary. Being authenticated isn't enough to act
in a tenant — you need an **active membership** there, and each action is checked
by a **policy**. This completes **Milestone 2**.

Depends on: 1.4 (resolution), 2.2 (Membership), 2.5 (auth endpoints).

---

## The full request pipeline (tenant-scoped endpoints)

```
within_tenant      (around)  subdomain -> Current.tenant, switch schema     -> 404 unknown / 403 inactive
authenticate_user! (before)  Bearer JWT -> Current.user                     -> 401
require_membership!(before)  active membership -> Current.membership        -> 403 no_membership
<action>                     must call `authorize` (policy)                 -> 403 forbidden
verify_authorized  (after)   fail closed if the action forgot to authorize  -> raises
```

Each layer answers a different question: *which tenant? who? may they act here?
may they do THIS?* — and each has its own status code so clients (and attackers)
get precise, non-leaky signals.

---

## The pieces

### `TenantMembership` concern
`require_membership!` looks up an **active** `Membership` for `Current.user` in
`Current.tenant`. Found → `Current.membership` (its role drives policies). Missing
→ **403 `no_membership`**. Distinct from 404 (tenant doesn't exist) and 401 (not
logged in): here you're authenticated and the tenant is real, you just have no
access to it.

### `ApplicationPolicy` (Pundit, deny-by-default)
`app/policies/application_policy.rb`. Every permission returns **false** unless a
subclass overrides it. You can't accidentally allow an action by forgetting to
define it — the safe default is "no." Resource policies (Milestone 4) subclass
this and open up only what each role may do, reading `Current.membership.role`.

### `Api::V1::TenantBaseController`
Stacks the pipeline: `TenantResolution` + `authenticate_user!` +
`require_membership!` + **`after_action :verify_authorized`**. That last one is the
**fail-closed** guard: if an action forgets to call `authorize`, Pundit *raises*
(surfacing the bug) rather than silently allowing the request. Apex auth endpoints
inherit `BaseController` directly and skip all this.

### `pundit_user` + 403 mapping
`BaseController` includes `Pundit::Authorization`, points `pundit_user` at
`Current.user`, and maps `Pundit::NotAuthorizedError` → a clean `403 forbidden`.

### `ContextController` (demonstrator)
`GET /api/v1/context` on a tenant subdomain returns "who am I in this tenant"
(user + tenant + role). It's the first consumer of `TenantBaseController` and
proves the whole stack. It `skip_after_action :verify_authorized` because it isn't
a Pundit resource action — real resource controllers will NOT skip it.

---

## Tests

- `spec/policies/application_policy_spec.rb` — every permission false; scope
  `resolve` raises until defined.
- `spec/requests/api/v1/context_spec.rb` — active member → 200 (+ role);
  authenticated non-member → 403 `no_membership`; inactive (invited) membership →
  403; no token → 401; unknown subdomain → 404. (Apartment switch stubbed — we're
  testing the gate, not schema machinery.)

```bash
docker compose exec web bundle exec rspec spec/policies spec/requests/api/v1/context_spec.rb
```

Live:
```bash
docker compose exec web rails runner '
  t = Identity::Tenant.create!(name: "Acme", subdomain: "acme"); Identity::ProvisionTenantJob.perform_now(t.id)
  u = Identity::User.create!(email: "sam@acme.io", password: "hunter2pw")
  Identity::Membership.create!(user: u, tenant: t, role: :admin, status: :active)
'
TOKEN=$(curl -s -X POST http://localhost:3000/api/v1/auth/login \
  -H 'Content-Type: application/json' -d '{"email":"sam@acme.io","password":"hunter2pw"}' | jq -r .access_token)
curl -s http://acme.lvh.me:3000/api/v1/context -H "Authorization: Bearer $TOKEN" | jq
```

---

## Milestone 2 complete

Identity + auth are done: users, memberships, refresh tokens, JWT issuance +
rotation, the REST auth surface, and now the membership gate + policy foundation.
Any tenant-scoped endpoint from here inherits `TenantBaseController` and is
resolved → authenticated → membership-checked → policy-authorized by default.

Next milestone: **API infrastructure** (standard error envelope, GraphQL setup,
API keys, rate limiting) — then the Inventory vertical slice.

## Commit message

```
feat(identity): membership gate + Pundit policy base (finish M2)

- TenantMembership: require active membership -> Current.membership, else 403
- ApplicationPolicy: deny-by-default (fail-closed) foundation
- Api::V1::TenantBaseController: resolution + auth + membership + verify_authorized
- Pundit wired into BaseController (pundit_user, NotAuthorized -> 403)
- ContextController demonstrator + GET /api/v1/context; policy + request specs
```
