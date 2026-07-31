# Commit 3.1 — Standard error envelope + FactoryBot (narrated)

Goal: one consistent JSON error shape for the whole API, with common exceptions
mapped to it automatically. Also introduces FactoryBot (test-data factories) with
a build-first, DB-avoiding bias.

Depends on: Milestone 2.

---

## The error envelope

Every non-2xx response now has the same shape (API_DESIGN.md):

```json
{ "error": { "code": "validation_failed", "message": "…", "details": [ … ], "request_id": "…" } }
```

- **`code`** — a stable machine string; clients switch on this, not `message`.
- **`message`** — human-readable.
- **`details`** — per-field validation info (omitted when empty).
- **`request_id`** — correlates the response to server logs (from Rails'
  RequestId middleware).

### `ErrorResponses` concern
`app/controllers/concerns/error_responses.rb` provides `render_error(status, code,
message, details:)` and **maps common exceptions once** so controllers don't
repeat themselves:

| Exception | Status | code |
|---|---|---|
| `ActiveRecord::RecordNotFound` | 404 | `not_found` |
| `ActiveRecord::RecordInvalid` | 422 | `validation_failed` (+details) |
| `ActiveRecord::RecordNotUnique` | 409 | `conflict` |
| `ActionController::ParameterMissing` | 400 | `parameter_missing` |
| `ActionController::UnpermittedParameters` | 400 | `unpermitted_parameters` |
| `Pundit::NotAuthorizedError` | 403 | `forbidden` |

It's included in `Api::V1::BaseController`, so every API controller inherits it.
We did NOT add a catch-all `rescue_from StandardError` — an unexpected error
should surface as a real 500 (with the detail in logs/dev), not be silently
masked.

### Everything routes through it
The auth endpoints (`invalid_credentials`, `invalid_refresh_token`,
`validation_failed`), the auth gate (`unauthorized`), and the membership gate
(`no_membership`) now all call `render_error`, so they carry `request_id` and use
the identical shape. `TenantResolution` keeps its own small renderer (it's shared
with the non-API demonstrator) but matches the shape.

### Versioning
The version is in the URL (`/api/v1`). Additive changes stay in v1; a breaking
change introduces `/api/v2` with a published sunset window, both running during
deprecation. Documented at the top of `BaseController`.

---

## FactoryBot (test data)

`spec/factories/identity.rb` defines `:user`, `:tenant`, `:membership`,
`:refresh_token`. `rails_helper` includes `FactoryBot::Syntax::Methods` so specs
call `build_stubbed` / `build` / `create` directly.

**Performance rule (ADR-0013):** use the cheapest constructor the test needs —
`build_stubbed` (no DB) > `build` (unsaved) > `create` (persisted). Reflexively
calling `create` is the usual cause of a slow suite.

This commit uses factories in the new specs and refactors `context_spec` to them.
Existing specs migrate to factories incrementally (no need to rewrite passing ones
in a rush).

---

## Tests

- `spec/requests/api/v1/error_envelope_spec.rb` — asserts the shared shape across
  422 (with details), 401 (with `WWW-Authenticate`), and 400, each carrying
  `request_id`.
- `context_spec` — now built with factories.

```bash
docker compose exec web bundle exec rspec spec/requests/api/v1
```

---

## What this commit does and doesn't do

Does: one API-wide error contract + exception mapping; FactoryBot with a
build-first bias.

Doesn't: add GraphQL, API keys, or rate limiting — those are the rest of
Milestone 3 (commits 3.2–3.5).

## Commit message

```
feat(api): standard error envelope + FactoryBot

- ErrorResponses concern: {code,message,details,request_id} + exception mapping
  (404/422/409/400/403); included in Api::V1::BaseController
- route auth/membership/auth-gate errors through render_error (consistent shape)
- URL versioning documented on BaseController
- add factory_bot_rails + identity factories; build-first bias (ADR-0013)
- error-envelope request spec; context_spec on factories
```
