# Commit 2.3 — Identity::RefreshToken (narrated)

Goal: the long-lived, revocable credential that lets a client obtain new
short-lived JWT access tokens without logging in again — and the mechanism behind
"log out everywhere." Sets up JWT issuance in commit 2.4.

Depends on: 2.1 (User).

---

## The idea (ADR-0005)

- **Access token** (commit 2.4): a JWT, short-lived (~15 min), stateless. Fast to
  verify, but you can't easily revoke one before it expires.
- **Refresh token** (this commit): long-lived (30 days), stored in the DB, and
  **revocable**. The client trades it for a fresh access token. Revoking it (or
  all of a user's) is how "log out everywhere" works.

Short access + revocable refresh gives you both speed and control.

---

## Step A — Migration

`db/migrate/20260724000004_create_refresh_tokens.rb`, in the **public** schema
(global identity). Columns: `user` reference, `token_digest`, `expires_at`,
`revoked_at`, timestamps. Indexes: unique on `token_digest`, plain on `expires_at`
(for a future cleanup job), and the `user_id` index (from `t.references`) supports
"revoke all of this user's tokens."

```bash
docker compose exec web rails db:migrate
```

---

## Step B — Model

`app/models/identity/refresh_token.rb`. The security-critical decisions:

- **Store the digest, never the raw token.** `issue` generates a random token,
  saves `SHA256(token)`, and returns the raw value to the caller exactly once. If
  the DB leaks, there are no usable tokens in it.
- **SHA-256, not bcrypt** (deliberately different from passwords). The raw token
  is 384 bits of `SecureRandom` — there's nothing to brute-force, so a fast hash
  is the right tool. bcrypt's slowness only matters for low-entropy human
  passwords. Using bcrypt here would be a performance mistake, not extra safety.
- **`issue(user)` → `[record, raw]`.** The two-value return makes the "shown
  once" contract explicit: the caller gets the raw token to hand to the client;
  the DB only ever holds the digest.
- **`find_active(raw)`** hashes the incoming value and looks it up against the
  `active` scope (not revoked, not expired). Lookup is an indexed digest match.
- **`revoke!` / `active?` / `expired?`** — the lifecycle. `active` scope +
  predicates keep the "is this usable?" logic in one place.

Also: `User has_many :refresh_tokens` (so `user.refresh_tokens` and a future bulk
revoke work), and `Identity::RefreshToken` joins Apartment's `excluded_models`.

---

## Step C — Tests

`spec/models/identity/refresh_token_spec.rb`: issue returns raw + stores digest,
`find_active` matches a raw value, returns nil for unknown/revoked/expired,
`revoke!` flips `active?`, and tokens are cleaned up when the user is destroyed.

```bash
docker compose exec web bundle exec rspec spec/models/identity/refresh_token_spec.rb
```

Try it live:
```bash
docker compose exec web rails console
> u = Identity::User.create!(email: "sam@acme.io", password: "hunter2pw")
> record, raw = Identity::RefreshToken.issue(u)
> raw                                   # the value the client keeps
> Identity::RefreshToken.find_active(raw) == record   # => true
> record.revoke!
> Identity::RefreshToken.find_active(raw)              # => nil
```

---

## What this commit does and doesn't do

Does: a secure, revocable refresh-token store with issue/lookup/revoke.

Doesn't: issue JWT access tokens or expose auth endpoints — that's commit 2.4
(`JwtCodec` + `AuthenticationService`) and 2.5 (the REST auth endpoints), which
will call `RefreshToken.issue` on login and `find_active` on refresh.

## Commit message

```
feat(identity): add Identity::RefreshToken (revocable, hashed)

- refresh_tokens table in public schema; unique token_digest, expires_at index
- store SHA-256 digest only; raw token returned once from .issue
- .find_active / #revoke! / #active? lifecycle; active scope
- User has_many :refresh_tokens; add to Apartment excluded_models
```
