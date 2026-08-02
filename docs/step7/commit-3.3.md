# Commit 3.3 — ApiKey + dual authentication (narrated)

Goal: let third parties authenticate to the REST API with a per-tenant **API
key**, alongside the first-party user JWT — normalized into `Current.actor` so
downstream code doesn't care which (ADR-0009/0010).

Depends on: 2.6 (tenant stack), 3.1 (error envelope).

---

## The `ApiKey` model

`Identity::ApiKey` (public schema, tenant-scoped). Same hashing discipline as
RefreshToken: `issue` returns `[record, raw]`, stores only `SHA256(raw)`, and the
raw key carries an **`ik_` prefix** so a leaked key is recognizable to secret
scanners. It has a `role`, `expires_at` (nil = never), and `revoked_at`; the
`active` scope filters both. `find_active(raw)` hashes then does an indexed lookup.

Added to Apartment's excluded models (global) and `Tenant has_many :api_keys`.

---

## Dual authentication — one `Current.actor`

The key idea: a request's **actor** is either a `User` (via JWT) or an `ApiKey`.
`Current` now carries both, plus helpers:

```ruby
Current.actor  # => user || api_key
Current.role   # => membership&.role || api_key&.role
```

`ActorAuthentication` (a concern on `TenantBaseController`) reads the
`Authorization` header and branches on the scheme:

- **`Bearer <jwt>`** → decode → load user → require an **active membership** in the
  resolved tenant → set `Current.user` + `Current.membership`. (Same as before,
  now unified here — it replaces the old `authenticate_user!` + `require_membership!`.)
- **`Api-Key <key>`** → `find_active` → the key **must belong to the resolved
  tenant** (else 403) → stamp `last_used_at` → set `Current.api_key`.
- anything else → 401.

So every tenant-scoped controller now accepts either credential, and reads
`Current.role` for authorization without caring which actor it is.

> GraphQL (Milestone 4) will NOT use this — it's first-party only and takes the
> user JWT exclusively (ADR-0009). API keys are a REST-only credential.

---

## Why identity management stays user-only (a safety property)

`MembershipPolicy` and `ApiKeyPolicy` check **`Current.membership&.admin?`**, not
`Current.role`. For an API-key actor `Current.membership` is `nil`, so those
policies return false — meaning **an API key can never manage members or mint
other API keys**. Inventory endpoints (Milestone 4) will use `Current.role`, which
*does* honor keys. That split is deliberate: keys operate on data, not identity.

---

## API key management endpoints (admin users)

`Api::V1::ApiKeysController < TenantBaseController`:

- `POST /api/v1/api_keys` → issue; returns the raw `token` **once** (201).
- `GET /api/v1/api_keys` → list metadata (never the token).
- `DELETE /api/v1/api_keys/:id` → revoke (204).

Admin-only via `Identity::ApiKeyPolicy`.

---

## Tests

- `spec/models/identity/api_key_spec.rb` — issue/digest/prefix, find_active
  (unknown/blank/revoked/expired), nil-expiry = never expires.
- `spec/requests/api/v1/api_keys_spec.rb` — create (raw token once), non-admin
  403, list (no token), revoke; **plus the consumption path**: an `Api-Key`
  authenticating `GET /context` (actor_type "api_key"), a wrong-tenant key → 403,
  a bogus key → 401.

```bash
docker compose exec web bin/rails db:migrate
docker compose exec -e RAILS_ENV=test web bin/rails db:migrate
docker compose exec web bundle exec rspec spec/models/identity/api_key_spec.rb spec/requests/api/v1
```

Note: `TenantMembership` is now unused (folded into `ActorAuthentication`); the
file remains harmlessly. Tenant-scoped endpoints' OpenAPI/rswag coverage
(memberships, api_keys) is a follow-up — they're plain request specs for now
because rswag + subdomain hosts needs a helper.

---

## Commit message

```
feat(auth): ApiKey model + dual authentication (Bearer JWT or Api-Key)

- Identity::ApiKey (public, tenant-scoped, hashed, ik_ prefix, role/expiry/revoke)
- Current.actor / Current.role; ActorAuthentication concern on TenantBaseController
- API keys authorize on Current.role; identity policies stay user-only (safety)
- ApiKeysController (issue once / list / revoke) + Identity::ApiKeyPolicy (admin)
- ContextController supports both actor types; factory + model/request specs
```
