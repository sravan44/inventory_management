# Commit 2.5 — REST auth endpoints (narrated)

Goal: expose the auth workflows over HTTP — the first real API surface. Register,
login, refresh, logout, logout-everywhere, and `/me`.

Depends on: 2.4 (AuthenticationService, JwtCodec).

---

## Where these live (and don't)

All under `/api/v1`, on the **apex host** — NOT a tenant subdomain. A user may
belong to zero or many tenants (ADR-0006), so authentication precedes any tenant
context. These controllers inherit `ApplicationController` (via a new
`Api::V1::BaseController`), NOT `TenantScopedController`, so no schema switching
happens here.

```
POST /api/v1/auth/register     201 | 422 | 400
POST /api/v1/auth/login        200 | 401
POST /api/v1/auth/refresh      200 | 401
POST /api/v1/auth/logout       204
POST /api/v1/auth/logout_all   204 (auth required)
GET  /api/v1/me                200 | 401
```

---

## The pieces

### `Authenticatable` concern
`app/controllers/concerns/authenticatable.rb`. `authenticate_user!` pulls the
`Authorization: Bearer <jwt>`, decodes it via `JwtCodec`, and loads
`Current.user`. Any failure (bad/absent/expired token, missing user) → `401` with
a `WWW-Authenticate` header. It's nil-safe: no header → `JwtCodec.decode(nil)` →
`InvalidToken` → 401. This is separate from tenant resolution — the token says
*who*, the subdomain says *which tenant* (added in 2.6).

### `Api::V1::BaseController`
Holds the shared JSON presenters (`user_json`, `memberships_json`) and a
`rescue_from ParameterMissing` → `400`. The full standard error envelope arrives
in commit 3.1; this is the minimum the auth endpoints need.

### `AuthController`
- **register** — creates the user and **auto-logs-in** (returns a token pair), so
  the client doesn't have to immediately call login. Invalid data → `422` with
  per-field `details`; missing `user` param → `400`.
- **login** — delegates to `AuthenticationService.authenticate`; bad creds →
  `401 invalid_credentials` (same message for wrong password vs unknown email).
- **refresh** — `AuthenticationService.refresh` (rotation + reuse detection from
  2.4); invalid → `401`.
- **logout** — revokes the given refresh token; always `204` (idempotent).
- **logout_all** — `authenticate_user!` first, then `revoke_all`.

### `MeController`
`authenticate_user!`, then returns the user + memberships. The SPA reads
`memberships[].tenant.subdomain` to route into the correct tenant host.

### `wrap_parameters` disabled
`config/initializers/wrap_parameters.rb` turns off Rails' habit of copying JSON
params under a controller-named key (`auth: {...}`). With our strict
`action_on_unpermitted_parameters = :raise`, that surprise key would cause
spurious errors. We own our param shapes, so wrapping is off.

---

## Login/register response shape

```json
{
  "access_token": "<jwt>",
  "token_type": "Bearer",
  "expires_in": 900,
  "refresh_token": "<opaque>",
  "user": { "id": "1", "email": "sam@acme.io", "first_name": "Sam", "last_name": null },
  "memberships": [
    { "role": "admin", "status": "active",
      "tenant": { "id": "1", "name": "Acme", "subdomain": "acme" } }
  ]
}
```
`expires_in` is 900 = `JwtCodec::DEFAULT_TTL` (15 min) in seconds.

---

## Tests

`spec/requests/api/v1/auth_spec.rb`: register (success/422/400), login
(success/401), refresh (rotate/401), logout (204 then old token rejected), `/me`
(valid token / no token / garbage token).

```bash
docker compose exec web bundle exec rspec spec/requests/api/v1/auth_spec.rb
```

Try it live:
```bash
curl -s -X POST http://localhost:3000/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"user":{"email":"sam@acme.io","password":"hunter2pw"}}' | jq

TOKEN=$(curl -s -X POST http://localhost:3000/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"sam@acme.io","password":"hunter2pw"}' | jq -r .access_token)

curl -s http://localhost:3000/api/v1/me -H "Authorization: Bearer $TOKEN" | jq
```

---

## What this commit does and doesn't do

Does: the full public auth surface over HTTP.

Doesn't: enforce tenant membership/authorization on tenant-scoped requests — that's
commit 2.6 (membership gate + policy base), which finishes Milestone 2.

## Commit message

```
feat(api): REST auth endpoints (register/login/refresh/logout/logout_all/me)

- Authenticatable concern: Bearer JWT -> Current.user, 401 with WWW-Authenticate
- Api::V1::BaseController (shared presenters + ParameterMissing -> 400)
- AuthController + MeController; register auto-logs-in
- routes under /api/v1 (apex host); disable wrap_parameters
- request specs across all endpoints
```
