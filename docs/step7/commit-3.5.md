# Commit 3.5 — Rate limiting + CORS (+ migration automation) (narrated)

Goal: finish Milestone 3's cross-cutting infrastructure — throttle abusive
traffic, allow the SPA's cross-origin calls — and remove the "migrate the test DB"
toil.

Depends on: Milestone 3 so far.

---

## Migration automation (no more forgotten test migrations)

Two changes so the `PendingMigration` 500s stop happening locally:

- **`spec/rails_helper.rb`** now runs `ActiveRecord::Tasks::DatabaseTasks.migrate`
  in a `before(:suite)` hook — so `rspec` migrates its own DB first. Since we build
  the test schema by *migrating* (not loading structure.sql), this is safe and
  makes the suite self-sufficient.
- **`bin/migrate`** migrates dev + test in one command:
  ```bash
  docker compose exec web bin/migrate
  ```

So: tests self-prepare; `bin/migrate` keeps the dev DB (and the running app) in
lockstep. The manual two-line ritual is gone.

---

## CORS

`config/initializers/cors.rb` allows the React SPA's origin(s) from
`FRONTEND_ORIGINS` (comma-separated) — an **allow-list, never `*`**. Tokens ride in
the `Authorization` header (not cookies), so `credentials: false` — which also
means the API isn't exposed to CSRF (there's no ambient cookie to ride).

---

## Rate limiting (Rack::Attack)

`config/initializers/rack_attack.rb`:

- **`req/ip`** — 300 requests / 5 min per IP (skips `/api-docs` so browsing Swagger
  isn't throttled).
- **`auth/login/ip`** — 10 / min, and **`auth/refresh/ip`** — 20 / min. Tighter on
  auth endpoints because that's where credential-stuffing/token abuse happens.
- **429 responder** — uniform JSON `{ error: { code: "rate_limited" } }` with a
  `Retry-After` header.

Two operational notes:
- **Counter store:** in-memory here (fine for dev/test/single process). In
  production it must be **Redis** so limits are shared across processes/instances —
  wired in Milestone 5 alongside Sidekiq.
- **Disabled in test** by default (`Rack::Attack.enabled = !Rails.env.test?`) so it
  doesn't throttle unrelated request specs; the rate-limit spec flips it on.

---

## Tests

`spec/requests/rate_limiting_spec.rb` enables Rack::Attack, hammers `/auth/login`
past the limit, and asserts `429` + `Retry-After` + the `rate_limited` code.

```bash
docker compose exec web bundle exec rspec spec/requests/rate_limiting_spec.rb
```

---

## Milestone 3 complete

API infrastructure is done: standard error envelope + FactoryBot (3.1), tenant +
membership management (3.2), API keys + dual auth (3.3), GraphQL surface (3.4),
and now rate limiting + CORS (3.5). Both transports (REST + GraphQL) are live,
authenticated, authorized, documented (OpenAPI/Swagger), and protected.

Next: **Milestone 4 — the Inventory vertical slice** (Product/SKU → Warehouse →
StockLevel/StockMovement), the first real product domain, exposed over both
transports.

## Commit message

```
feat(api): rate limiting (Rack::Attack) + CORS; auto-migrate test DB

- rack-attack: per-IP ceiling + tighter login/refresh buckets; JSON 429 +
  Retry-After; memory store (Redis in prod, M5); disabled in test by default
- rack-cors: allow-list from FRONTEND_ORIGINS, header-based (no cookies/CSRF)
- rails_helper before(:suite) migrate + bin/migrate (dev+test) — no more
  forgotten test migrations
- rate-limiting request spec
```
