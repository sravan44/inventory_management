# Commit 2.4 — JwtCodec + AuthenticationService (narrated)

Goal: turn credentials into tokens. Verify email/password, issue a short-lived
**access JWT** + a long-lived **refresh token**, and implement **refresh-token
rotation with reuse detection**. This is the brain behind the auth endpoints
(commit 2.5).

Depends on: 2.1 (User), 2.3 (RefreshToken).

---

## Step A — Add the jwt gem

```ruby
gem "jwt", "~> 2.8"   # in backend/Gemfile
```
Then `docker compose build web` (or `bundle install`).

---

## Step B — `JwtCodec` (the library boundary)

`app/services/identity/jwt_codec.rb`. A thin wrapper around the `jwt` gem:

- `encode(payload, ttl:)` — signs a payload (HS256) and adds `exp` (expiry) and
  `iat` (issued-at) claims. Default TTL 15 minutes — short on purpose (see below).
- `decode(token)` — verifies signature *and* expiry; raises our own
  `JwtCodec::InvalidToken` on any failure, so callers catch **one** error type
  instead of the jwt gem's several.
- `secret` — HS256 key from `JWT_SECRET` env, falling back to
  `secret_key_base` so dev/test work with no setup.

Why wrap it (DIP): nothing else in the app touches `JWT.*`. If we change algorithm
or swap libraries, only this file changes. This is the same "isolate the
dependency behind our own interface" move as `Apartment` behind the resolver.

---

## Step C — `AuthenticationService` (the workflows)

`app/services/identity/authentication_service.rb`. Returns a small `Result`
struct (`user`, `access_token`, `refresh_token`).

- **`authenticate(email:, password:)`** — finds the (kept) user, checks the
  password via `has_secure_password`'s `#authenticate`, and on success issues a
  pair. Wrong password *or* unknown email both raise the **same**
  `InvalidCredentials` — never reveal which, so attackers can't enumerate emails.
- **`refresh(raw_refresh_token)`** — the interesting one:
  - **Rotation:** a valid refresh token is *consumed* (revoked) and a new pair is
    issued. Refresh tokens are single-use.
  - **Reuse detection:** if the presented token isn't active, we check whether it
    matches a *known revoked* token. If so, the same token is in two places —
    a theft signal — so we **revoke ALL** the user's tokens, forcing a fresh
    login everywhere. Then reject.
- **`revoke` / `revoke_all`** — back the "log out" and "log out everywhere"
  endpoints (2.5).

### Why short access + rotating refresh?

The access JWT is stateless, so it's fast to verify but can't be revoked before it
expires — keeping it short (15 min) bounds the damage of a leaked one. The refresh
token is revocable, so it's the control point. Rotation + reuse detection means a
stolen refresh token gets caught the moment either party uses it after the other,
and the whole family is nuked.

Note (ADR-0004): the access token carries only `sub` (the user id). It does NOT
carry a tenant — tenant comes from the subdomain + a membership check per request.

---

## Step D — Tests

- `spec/services/identity/jwt_codec_spec.rb` — round-trip, tampered token raises,
  expired token raises.
- `spec/services/identity/authentication_service_spec.rb` — login success
  (case-insensitive email), wrong password / unknown email both raise
  `InvalidCredentials`, refresh rotates (old token spent), reuse of a revoked
  token revokes everything, `revoke_all` clears active tokens.

```bash
docker compose exec web bundle exec rspec spec/services/identity
```

Try it live:
```bash
docker compose exec web rails console
> Identity::User.create!(email: "sam@acme.io", password: "hunter2pw")
> r = Identity::AuthenticationService.authenticate(email: "sam@acme.io", password: "hunter2pw")
> r.access_token           # the JWT
> Identity::JwtCodec.decode(r.access_token)   # => {"sub"=>"1","exp"=>..., "iat"=>...}
> r2 = Identity::AuthenticationService.refresh(r.refresh_token)  # rotates
> Identity::AuthenticationService.refresh(r.refresh_token)       # raises (reuse -> revoke all)
```

---

## What this commit does and doesn't do

Does: credential verification and the full token lifecycle (issue, rotate, revoke,
theft-handle).

Doesn't: expose HTTP endpoints (commit 2.5 wires `/auth/login`, `/refresh`,
`/logout`, `/logout_all`, `/me`), or authorize tenant-scoped requests (commit 2.6).

## Commit message

```
feat(identity): JwtCodec + AuthenticationService (login, rotation, reuse detection)

- add jwt gem; JwtCodec wraps encode/decode (HS256, exp/iat, one error type)
- AuthenticationService: authenticate (generic InvalidCredentials), refresh with
  single-use rotation + revoked-token reuse detection (revoke-all on theft)
- revoke / revoke_all for logout and logout-everywhere
- specs for codec and service
```
