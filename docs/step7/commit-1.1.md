# Commit 1.1 — Configure Apartment for schema-per-tenant (narrated)

Goal: install and configure the Apartment gem so the app *can* do schema-per-
tenant (ADR-0002), while the default schema still behaves normally because no
tenants exist yet. This commit adds **capability**, not behavior — a safe, boot-
able step. Every request still runs against `public`.

Depends on: commit 0.1 (running Dockerized app).

---

## Background: what Apartment does

PostgreSQL lets one database hold many **schemas** (namespaces). Apartment sits in
the request cycle and sets the connection's `search_path` to the active tenant's
schema, so `Product.all` transparently reads only that tenant's `products` table.
A short list of **excluded models** (global identity) always resolve against
`public` regardless of the active tenant.

We use **`ros-apartment`**, the maintained fork of the original `apartment` gem
(which no longer supports modern Rails). It's a drop-in: the module is still
`Apartment`. This is the mitigation ADR-0002 anticipated for "gem maintenance
risk."

---

## Step A — Add the gem

In `backend/Gemfile`:

```ruby
# Schema-per-tenant multi-tenancy (ADR-0002). Maintained fork of `apartment`;
# required as "apartment" so the module stays `Apartment`.
gem "ros-apartment", "~> 3.2", require: "apartment"
```

Install it inside the container (rebuild the image so the gem is baked in):

```bash
docker compose build web
# or, to install into the running container's bundle volume:
docker compose exec web bundle install
```

- `~> 3.2` — the 3.2 line, which supports Rails 7.x.
- `require: "apartment"` — the gem is *named* `ros-apartment` on RubyGems but its
  code is loaded as `apartment`; this tells Bundler the right file to require.

---

## Step B — The initializer (the heart of this commit)

`backend/config/initializers/apartment.rb` (already in the repo). Key settings and
*why each is what it is*:

- `config.use_schemas = true` — use Postgres **schemas** (one database, many
  namespaces), not a separate database per tenant. This is the "single instance,
  many tenants" model you wanted.
- `config.excluded_models = [...]` — models that live **once** in `public` instead
  of being duplicated per tenant. These are the global identity models (a user
  belongs to many tenants — ADR-0006). **Empty for now** because those models
  don't exist yet; each is added in the commit that creates it (Milestones 2-3).
- `config.tenant_names = -> { [] }` — the list of tenant schemas Apartment
  manages (used by `rake apartment:migrate` to run migrations across every
  tenant). **Stubbed to empty** until the `Tenant` model exists; commit 1.2 turns
  this into `-> { Identity::Tenant.pluck(:schema_name) }`.
- `config.default_schema = "public"` — where queries go when no tenant is active
  (e.g. the apex host handling login before a tenant is chosen).

The **subdomain elevator is intentionally left disabled** (commented at the bottom
of the file). That auto-switches schema by request subdomain — but it belongs to
commit 1.4 (`TenantResolver`), which also handles 404 for unknown subdomains and
blocks suspended tenants. Turning it on now would break every request, since there
are no tenants.

> Boot-safety rule followed here: nothing in this initializer references a model
> or table that doesn't exist yet. That's why `tenant_names` and `excluded_models`
> are stubs, not real lookups — the app must still boot.

---

## Step C — Use SQL schema format (important for Postgres features)

Edit `backend/config/application.rb`, inside the `class Application` block:

```ruby
# Dump the schema as structure.sql (not schema.rb). Required because we rely on
# Postgres-specific features that Ruby schema dumps can't represent: multiple
# schemas, partial unique indexes (reusable SKU after soft-delete), citext,
# jsonb. structure.sql captures them faithfully.
config.active_record.schema_format = :sql
```

Without this, `db/schema.rb` would silently drop the Postgres-specific bits and
tenant schemas wouldn't reproduce correctly.

---

## Step D — Prove it with a config spec

`backend/spec/config/apartment_spec.rb` (already in the repo) asserts the four
settings above. It needs no tenant to exist — it just guards the configuration so
nobody later flips `use_schemas` off or changes the default schema by accident.

```bash
docker compose exec web bundle exec rspec spec/config/apartment_spec.rb
```

Expected: 4 examples, all green. Also confirm the app still boots and the health
check from 0.1 still works:

```bash
curl http://localhost:3000/up      # still {"status":"ok",...}
```

---

## What this commit does and doesn't do

Does: installs Apartment, declares schema-per-tenant intent, keeps the app booting
on `public`, guards the config with a test.

Doesn't: create any tenant, switch schemas on requests, or add identity models.
Those are commits 1.2 (Tenant model), 1.3 (provisioning service), and 1.4
(subdomain resolver).

## Commit message

```
feat(tenancy): configure Apartment for schema-per-tenant (capability only)

- add ros-apartment (~> 3.2), maintained fork, required as "apartment"
- boot-safe initializer: use_schemas, default public, stubbed tenant_names
  and excluded_models (filled in as models arrive in M2-M3)
- schema_format = :sql to preserve Postgres schemas/partial indexes/citext/jsonb
- config spec guarding the settings
- subdomain elevator left disabled until commit 1.4 (TenantResolver)
```
