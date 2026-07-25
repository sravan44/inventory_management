# Commit 2.2 — Identity::Membership (narrated)

Goal: the join between User and Tenant that makes "one user, many tenants" real
and becomes the **authorization boundary** — no membership means no access to that
tenant.

Depends on: 2.1 (User), 1.2 (Tenant).

---

## The idea

Three global records, one relationship:

```
User  ──< Membership >──  Tenant
              │
           role + status
```

- The **JWT** (commit 2.4) says *who you are* — globally.
- The **subdomain** (commit 1.4) says *which tenant* you're acting in.
- The **Membership** says *whether you may act there, and in what role*.

That third piece is the gate. Auth (Milestone 2/3) will check
`Membership.exists?(user:, tenant:)` on every tenant-scoped request.

---

## Step A — Migration

`db/migrate/20260724000003_create_memberships.rb`. In the **public** schema (all of
user/tenant/membership are global). Notable choices:

- `t.references :user, index: false` + `t.references :tenant` — the composite
  unique index below already covers user-prefixed lookups, so a separate `user_id`
  index would be redundant; `tenant_id` keeps its own index (for "list a tenant's
  members").
- `role` (int, required) and `status` (int, default 0 = invited) back the enums.
- `invited_at` / `joined_at` / `revoked_at` — lifecycle timestamps.
- **`add_index [:user_id, :tenant_id], unique: true`** — one membership per pair,
  enforced by the DB (races can't create duplicates), mirrored by a validation for
  friendly errors.

```bash
docker compose exec web rails db:migrate
```

---

## Step B — Model

`app/models/identity/membership.rb`:

- **`belongs_to :user` / `belongs_to :tenant`** with explicit `class_name:
  "Identity::…"` so the namespaced classes resolve unambiguously.
- **`enum :role { admin, staff, purchasing, sales }`** and
  **`enum :status { invited, active, revoked }, default: :invited`**. Enums give
  you a lot for free: query scopes (`Membership.active`, `Membership.admin`),
  predicates (`m.admin?`), and bang setters (`m.active!`).
- **`activate!` / `revoke!`** — richer lifecycle methods that flip status *and*
  stamp the matching timestamp. (We add these on top of the enum's plain setters
  precisely because we want the timestamp side-effect.)
- **`before_create :stamp_invited_at`** — records when the invite was created.
- **uniqueness validation** scoped to `tenant_id` — the friendly-error partner of
  the DB unique index.

---

## Step C — Wire the many-to-many

Associations added to the two ends so you can traverse both ways:

```ruby
# User
has_many :memberships, class_name: "Identity::Membership", dependent: :destroy
has_many :tenants, through: :memberships, source: :tenant

# Tenant
has_many :memberships, class_name: "Identity::Membership", dependent: :destroy
has_many :users, through: :memberships, source: :user
```

Now `user.tenants` and `tenant.users` work. And `Identity::Membership` is added to
Apartment's `excluded_models` (it's global, lives in `public`).

---

## Step D — Tests

`spec/models/identity/membership_spec.rb`: validity, role required, default status
+ invited_at stamp, uniqueness (same pair rejected / same user in another tenant
allowed), `activate!`/`revoke!` timestamps, and the many-to-many traversal.

```bash
docker compose exec web bundle exec rspec spec/models/identity/membership_spec.rb
```

Try it live:
```bash
docker compose exec web rails console
> u = Identity::User.create!(email: "sam@acme.io", password: "hunter2pw")
> t = Identity::Tenant.create!(name: "Acme", subdomain: "acme")
> m = Identity::Membership.create!(user: u, tenant: t, role: :admin)
> m.status              # => "invited"
> m.activate!; m.status # => "active"
> u.tenants             # => [#<Tenant acme>]
> t.users               # => [#<User sam@acme.io>]
```

---

## What this commit does and doesn't do

Does: the user↔tenant link with roles and lifecycle; the data the auth gate will
read.

Doesn't: enforce the gate on requests yet (that's the membership gate + policies,
commit 2.6), issue tokens (2.4), or send invitation emails (a later commit using
the mailer from ADR-0011).

## Commit message

```
feat(identity): add Identity::Membership (user <-> tenant <-> role)

- memberships table in public schema, unique(user_id, tenant_id)
- role + status enums; invited/joined/revoked lifecycle timestamps
- activate!/revoke! helpers; uniqueness validation
- has_many :tenants/:users through memberships on both ends
- add Membership to Apartment excluded_models
```
