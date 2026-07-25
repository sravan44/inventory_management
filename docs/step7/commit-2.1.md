# Commit 2.1 — Identity::User model + migration (narrated)

Goal: the global user identity — an account that can log in and (via Membership,
next commit) belong to many tenants. Secure password handling, case-insensitive
unique email, soft delete.

Depends on: Milestone 1.

---

## Step A — Enable bcrypt

`has_secure_password` needs the `bcrypt` gem. Rails ships it commented in the
Gemfile — uncomment it (or add it):

```ruby
gem "bcrypt", "~> 3.1.7"
```

Then `docker compose build web` (or `docker compose exec web bundle install`).

Why bcrypt: it's a deliberately *slow*, salted hash. We never store the raw
password — only its bcrypt digest. Even if the DB leaks, passwords aren't
recoverable in any practical time.

---

## Step B — The migration

`db/migrate/20260724000002_create_users.rb`. Creates `users` in **public** (global
identity). Two things worth understanding:

- **`t.citext :email`** — storing email as citext means "A@B.com" and "a@b.com"
  compare equal *at the database level*. So the unique index below is inherently
  case-insensitive — no `LOWER(email)` in every query, no separate functional
  index. This is a Postgres feature MySQL lacks cleanly (part of why we stayed on
  Postgres).
- **Where citext lives — `shared_extensions`, not `public`.** The extension is
  installed by an earlier migration (`SetupSharedExtensions`) into a dedicated
  `shared_extensions` schema, which Apartment keeps in every tenant's search_path
  (`persistent_schemas`). Reason: when Apartment provisions a tenant it clones the
  public structure and rewrites `public` → `tenant_x`; if citext lived in `public`
  the type reference would be rewritten to a non-existent `tenant_x.citext` and
  provisioning would fail (`type "tenant_x.citext" does not exist`). This bit us in
  CI — see the note in `commit-1.3.md`.

Run it:
```bash
docker compose exec web rails db:migrate
```

---

## Step C — The model

`app/models/identity/user.rb`:

- **`self.table_name = "users"`** — same namespaced-model trick as Tenant: the
  class is `Identity::User`, the table stays plain `users`.
- **`has_secure_password`** — the workhorse. It adds `password`/
  `password_confirmation` virtual attributes, hashes into `password_digest`, gives
  an `#authenticate` method (returns the user on match, `false` otherwise),
  requires a password on create, and caps length at bcrypt's 72-byte limit.
- **`enum :status`** — `active` / `invited` / `suspended`. `invited` supports the
  flow where an admin invites an email that has no account yet (Membership commit).
- **`normalize_email`** — strips + downcases before validation, so stored emails
  are tidy. citext handles comparison; this just keeps the display form canonical.
- **email validations** — presence, RFC-ish format (`URI::MailTo::EMAIL_REGEXP`),
  and case-insensitive uniqueness (backed by the DB unique index).
- **`scope :kept` + `soft_delete!`** — soft delete, same pattern as Tenant, no
  `default_scope`.

Also: `Identity::User` is added to Apartment's `excluded_models` so it lives once
in `public`, not per tenant.

---

## Step D — Tests

`spec/models/identity/user_spec.rb`: password authenticate (right/wrong), digest
never contains the raw password, password required on create, email normalization,
format rejection, case-insensitive uniqueness, default status, soft delete.

```bash
docker compose exec web bundle exec rspec spec/models/identity/user_spec.rb
```

Try it live:
```bash
docker compose exec web rails console
> u = Identity::User.create!(email: "  Sam@Acme.io ", password: "hunter2pw")
> u.email                      # => "sam@acme.io"
> u.authenticate("hunter2pw")  # => #<User ...>
> u.authenticate("nope")       # => false
> Identity::User.find_by(email: "SAM@ACME.IO")  # => finds it (citext)
```

---

## What this commit does and doesn't do

Does: a secure, global user with clean email handling.

Doesn't: connect users to tenants (that's Membership, commit 2.2), or issue tokens
(JWT, commit 2.4). A User right now can exist but can't yet access any tenant.

## Commit message

```
feat(identity): add Identity::User with secure password

- users table in public schema (global identity, ADR-0006); citext email
  with case-insensitive unique index
- has_secure_password (bcrypt); email normalize/format/uniqueness; status enum
- soft delete; add User to Apartment excluded_models
- model spec covering auth, normalization, uniqueness, soft delete
```
