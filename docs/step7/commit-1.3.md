# Commit 1.3 — Tenant provisioning service + async job (narrated)

Goal: actually build a tenant's Postgres schema. When a `Tenant` is created it
starts as `pending_provisioning`; this commit adds the service that runs
`CREATE SCHEMA` (via Apartment) and flips it to `active`, plus a background job so
the work happens off the request thread.

Depends on: commit 1.2 (Tenant model).

---

## Step A — The service (the workflow owner)

`app/services/identity/tenant_provisioning_service.rb`.

A **service object** is a plain Ruby class that owns one workflow. Why not put
this in the model or controller?

- Not the model: creating a schema is an *action/side-effect*, not part of what a
  Tenant *is*. Keeping it out of the model keeps the model thin and testable, and
  avoids a schema being created every time a Tenant is instantiated in a test.
- Not the controller: controllers should stay thin (parse request → call a
  service → render). Business orchestration lives in services so it's reusable
  from the job, a rake task, or the console.

What it does:

```ruby
def call
  create_schema   # Apartment::Tenant.create(tenant.schema_name)
  activate!       # tenant.update!(status: :active)
  @tenant
end
```

Key design points:

- **Delegation, not raw SQL.** It calls `Apartment::Tenant.create`, never
  `execute("CREATE SCHEMA ...")`. Apartment is our tenancy boundary (ADR-0002);
  if we ever replace it, only this file and the resolver change. That's the
  "Apartment behind a boundary" promise from our earlier discussion, made real.
- **Idempotent.** If the schema already exists (a job retry, a double-click),
  Apartment raises `Apartment::TenantExists`; we rescue it, log, and continue to
  `activate!`. Re-running the service is always safe — important because
  background jobs can and do run more than once.
- **`self.call` shortcut.** `TenantProvisioningService.call(tenant)` is a common
  convention: a class method that news-up and runs, so callers don't care about
  the instance.

---

## Step B — The job (do it off the request thread)

`app/jobs/identity/provision_tenant_job.rb`.

```ruby
def perform(tenant_id)
  tenant = Identity::Tenant.find(tenant_id)
  TenantProvisioningService.call(tenant)
end
```

- **Why async:** creating a schema and loading structure takes time. In
  Milestone 3 the `POST /tenants` endpoint will enqueue this and return
  **202 Accepted** immediately; the client polls until the tenant is `active`.
  Blocking the request on schema creation would be slow and fragile.
- **Pass the id, not the record.** ActiveJob serializes arguments onto the queue.
  Passing a bare `tenant_id` and refetching inside `perform` avoids serializing a
  whole object and guarantees the job sees the current row, not stale state.
- **Queue backend:** for now this runs on ActiveJob's default adapter. Sidekiq
  (backed by Redis) gets wired in Milestone 5; the job code won't change.

The job is a *thin wrapper* — all logic is in the service, so both the job and a
console call share identical behavior (DRY).

---

## Step C — Tests

- `spec/services/identity/tenant_provisioning_service_spec.rb` — an **integration**
  spec: it creates a real schema in the test database, asserts the schema exists
  in `information_schema.schemata`, that the tenant becomes `active`, and that
  calling twice doesn't raise (idempotency). It **disables transactional fixtures**
  (`self.use_transactional_tests = false`) and cleans up manually in an `after`
  block (drop the schema, destroy the tenant).

  **Why transactional fixtures had to go here** (a real ros-apartment gotcha worth
  knowing): by default each example runs inside one transaction that RSpec rolls
  back at the end. But when `Apartment::Tenant.create` is called against a schema
  that already exists (the idempotency case), ros-apartment issues a **raw
  `ROLLBACK;`** internally instead of releasing a savepoint. That raw rollback
  unwinds the *entire* example's transaction — including the `tenant` row created
  in the spec — so the subsequent `tenant.reload` fails with `RecordNotFound`.
  Turning transactional fixtures off (and cleaning up by hand) sidesteps it. This
  is the concrete case the note in `spec/rails_helper.rb` warns about.

- `spec/jobs/identity/provision_tenant_job_spec.rb` — uses `ActiveJob::TestHelper`
  to `perform_enqueued_jobs` and asserts the tenant ends up active, plus that the
  job enqueues on the `default` queue. It provisions the schema only **once**, so
  it never hits the raw-rollback path above and keeps transactional fixtures.

```bash
docker compose exec web bundle exec rspec spec/services spec/jobs
```

Try it live:

```bash
docker compose exec web rails console
> t = Identity::Tenant.create!(name: "Acme", subdomain: "acme")
> t.status                                   # => "pending_provisioning"
> Identity::ProvisionTenantJob.perform_now(t.id)
> t.reload.status                            # => "active"
> Apartment::Tenant.switch!("tenant_acme")   # schema now exists to switch into
```

---

## What this commit does and doesn't do

Does: create the Postgres schema for a tenant, idempotently, off the request
thread, and activate the tenant.

Doesn't: switch schemas based on the request subdomain (commit 1.4), or expose an
HTTP endpoint to create tenants (Milestone 3). Deprovisioning (dropping a schema
on tenant deletion) is a later hardening step, not in this commit.

## Commit message

```
feat(identity): tenant provisioning service + async job

- TenantProvisioningService: create schema via Apartment (idempotent), activate
- ProvisionTenantJob: run provisioning off-request, refetch by id
- integration specs for service (schema created, activated, idempotent) and job
- all schema access delegated to Apartment (tenancy boundary, ADR-0002)
```
