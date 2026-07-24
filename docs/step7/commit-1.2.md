# Commit 1.2 — Identity::Tenant model + migration (narrated)

Goal: create the `tenants` table and the `Identity::Tenant` model — the record
that represents one customer organization — with the validations that keep
subdomains safe, and wire Apartment to read its list of tenant schemas from this
table. Still no request-time schema switching (that's 1.4).

Depends on: commit 1.1 (Apartment configured).

Architecture note: we're using a **namespaced module** (`Identity::Tenant`), not a
full Rails engine yet — see the amendment in ADR-0003. Same boundary, less
ceremony, promotable to an engine later.

---

## Step A — The migration

`db/migrate/20260724000001_create_tenants.rb` (in the repo). Creates `tenants` in
the **public** schema (Tenant is a global record — a user belongs to many tenants,
ADR-0006). Columns: `name`, `subdomain`, `schema_name`, `status` (integer for the
enum), `deleted_at` (soft delete), timestamps.

Two **unique indexes** — on `subdomain` and `schema_name`. Why both a DB index and
a model validation? The model validation gives friendly errors; the DB index is
the real guarantee — a uniqueness validation alone can race under concurrent
inserts (two requests both see "no existing row" and both insert). The index
makes the second insert fail hard.

Generate an equivalent yourself with:

```bash
docker compose exec web rails generate migration CreateTenants
# then edit the file to match, or just use the one in the repo
```

Run it:

```bash
docker compose exec web rails db:migrate
```

---

## Step B — The model and its validations

`app/models/identity/tenant.rb`. The parts worth understanding:

- **`self.table_name = "tenants"`** — because the class is namespaced, Rails would
  otherwise look for a table called `identity_tenants`. We want plain `tenants`;
  the module is a *code* boundary, not a table prefix.

- **`enum :status, { pending_provisioning: 0, active: 1, suspended: 2 }`** — stores
  an integer, exposes readable states (`tenant.active?`, `tenant.suspended!`).
  Default `pending_provisioning`: a tenant isn't usable until its schema is built
  (commit 1.3).

- **`before_validation :normalize_subdomain`** — downcases + strips the subdomain
  *before* the uniqueness/format checks run, so "ACME", " acme " and "acme" are one
  value. This is why the case-insensitive uniqueness test passes without a special
  index.

- **`before_validation :assign_schema_name, on: :create`** — derives
  `schema_name = "tenant_#{subdomain}"`. The `tenant_` prefix keeps tenant schemas
  visually distinct from `public` and avoids a schema literally named `admin`, etc.
  It won't overwrite an explicitly supplied value.

- **Subdomain validations** — presence, max length 63 (the DNS label limit),
  a format regex (one lowercase DNS label), uniqueness, and **exclusion against
  `RESERVED_SUBDOMAINS`** so nobody grabs `www`/`api`/`admin` (ADR-0004).

- **`scope :kept`, `soft_delete!`** — soft delete via `deleted_at`. We deliberately
  avoid `default_scope` (a footgun that silently filters every query and
  association); callers opt in with `Tenant.kept`.

---

## Step C — Point Apartment at the Tenant table

Edit `config/initializers/apartment.rb` (already updated in the repo):

- `excluded_models` now includes `"Identity::Tenant"` — so the tenants table stays
  in `public` and is not copied into every tenant schema.
- `tenant_names` now returns `Identity::Tenant.pluck(:schema_name)`, **guarded by
  `table_exists?("tenants")`**. The guard keeps it boot-safe: during the very
  migration that creates `tenants`, the table doesn't exist yet, so it returns `[]`
  instead of raising. After that, `rake apartment:migrate` will fan migrations
  across every tenant schema this returns.

---

## Step D — Tests

Two specs (in the repo):

- `spec/models/identity/tenant_spec.rb` — normalization, schema_name derivation,
  reserved words, format, length, uniqueness (incl. case-insensitive), default
  status, soft delete.
- `spec/config/apartment_spec.rb` (updated) — now asserts `Identity::Tenant` is
  excluded and that creating a Tenant makes its schema_name show up in
  `Apartment.tenant_names`.

```bash
docker compose exec web bundle exec rspec spec/models/identity/tenant_spec.rb spec/config/apartment_spec.rb
```

Expected: all green. Try it live too:

```bash
docker compose exec web rails console
> Identity::Tenant.create!(name: "Acme", subdomain: "  ACME ")
> _.subdomain      # => "acme"
> _.schema_name    # => "tenant_acme"
> Identity::Tenant.new(subdomain: "www").tap(&:valid?).errors[:subdomain]
> # => ["is reserved"]
```

---

## What this commit does and doesn't do

Does: real Tenant records with safe subdomains; Apartment knows the tenant list.

Doesn't: actually create Postgres schemas, or switch schemas per request. Creating
the schema on tenant creation is commit 1.3 (provisioning service + job); switching
by subdomain is commit 1.4 (TenantResolver).

## Commit message

```
feat(identity): add Identity::Tenant model + tenants migration

- tenants table in public schema (global record, ADR-0006) with unique
  indexes on subdomain and schema_name
- namespaced model (self.table_name = "tenants"); status enum; soft delete
- subdomain normalization + format/length/reserved-word/uniqueness validations
- schema_name derived as tenant_<subdomain>
- wire Apartment excluded_models + tenant_names to the Tenant table (guarded)
```
