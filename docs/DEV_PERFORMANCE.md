# Dev & Test Performance Strategy

Principle: **measure, then optimize — and adopt each technique at a trigger, not
preemptively** (KISS/YAGNI). Below, each strategy has a "when to adopt it" so we
don't add machinery the suite doesn't need yet.

---

## 1. Gem caching — already solved

You asked for "reinstall gems only when a gem is added." That's already true, via
two independent layers:

### Docker image build (local)
`backend/Dockerfile` copies the Gemfile *before* the app code and runs
`bundle install` as its own layer:

```dockerfile
COPY Gemfile Gemfile.lock* ./
RUN bundle install          # cached; only re-runs when Gemfile/Gemfile.lock change
COPY . .                    # app code changes don't bust the gem layer
```

Docker's layer cache keys on the copied files' checksums, so **editing app code
never reinstalls gems** — only a Gemfile/lock change does. That's the
"symlink/only-if-added" behavior, built into Docker. We also set
`BUNDLE_JOBS=4 BUNDLE_RETRY=3` so the install that *does* happen is parallel.

### CI (GitHub Actions)
`ruby/setup-ruby@v1` with `bundler-cache: true` caches the installed gems keyed on
`Gemfile.lock`. Unchanged lock → cache hit → no reinstall across runs.

### Why NOT a runtime bundle volume
We deliberately removed the `bundle:/usr/local/bundle` compose volume: an empty
named volume shadows the image's gems on first run ("gem not found"). Gems live in
the image; a Gemfile change means `docker compose build web` (fast, thanks to the
layer cache above). See the note in `docker-compose.yml`.

**Net:** no action needed here as the app grows. It already scales.

---

## 2. Test-suite speed — adopt in tiers

### In place now (keep)
- **FactoryBot with a build-first bias.** Prefer the cheapest constructor that the
  test actually needs:
  - `build_stubbed(:x)` — no DB at all (fake id + associations). Use for
    validation/serializer/decorator/policy logic. **Fastest.**
  - `build(:x)` — in-memory unsaved record.
  - `create(:x)` — persists. Use only when a row must exist (uniqueness checks,
    `find_by`, association queries, request specs that read the DB).

  Reaching for `create` by reflex is the most common cause of a slow suite; every
  avoided `create` is saved DB round-trips.
- **Transactional fixtures** — each example runs in a transaction rolled back at
  the end (fast; no truncation). The few Apartment schema-DDL specs opt out
  (`use_transactional_tests = false`) and clean up manually.
- **Bootsnap** — caches expensive load work; faster boot.
- **Example status persistence** (`tmp/rspec_examples.txt`) — enables
  `rspec --only-failures` and `--next-failure` locally.
- **Random order** — catches order dependencies early.

### Tier 1 — when the suite gets annoying locally (~>30s)
- **Tag slow/integration specs.** The Apartment schema-creating specs
  (provisioning) are the slow ones. Tag them `:integration` and run a fast lane by
  default:
  ```ruby
  # provisioning spec
  RSpec.describe TenantProvisioningService, :integration do
  ```
  ```bash
  bundle exec rspec --tag ~integration   # fast lane (skip slow)
  bundle exec rspec                       # full (CI always runs full)
  ```
- **Fail-fast loop:** `rspec --only-failures`, then `--next-failure`.

### Tier 2 — when the full suite exceeds ~1–2 min
- **`parallel_tests` gem** — split specs across CPU cores, one test DB per worker
  (`inventory_test`, `inventory_test2`, …). Big linear speedup.
  - Setup: `rake parallel:create parallel:migrate`, run `parallel_rspec spec`.
  - Note: parallel workers + Apartment need per-worker schema handling; the
    provisioning specs (already non-transactional) must namespace their schema
    names by worker to avoid collisions.
- **CI sharding** — split the test job into a matrix (`shard: [1,2,3,4]`) and pass
  `--seed`/split files across shards. Wall-clock drops ~linearly.

### Tier 3 — when DB SETUP itself gets slow (migrations pile up, setup >~15s)
Running every migration on each CI run is the cost. "Snapshot" the schema instead:

- **Recommended: Postgres TEMPLATE DATABASE.** Migrate once into a template DB
  (including `shared_extensions` + the tenant clone template), then create each
  run's/worker's DB `WITH TEMPLATE` — a fast file copy, no migration replay. Plays
  well with Apartment (the template carries the base schema).
- **Alternative: commit a schema dump and load it.** Faster than migrating, but
  reintroduces `structure.sql` management + needs `postgresql-client` on the CI
  runner, and interacts with Apartment's per-tenant clone (why we avoided it so
  far). Revisit only if the template-DB route doesn't fit.

### Tier 4 — large suite, slow CI even sharded
- **Predictive test selection** (e.g. `crystalball`): on PRs, run only the specs a
  diff could affect; run the full suite on `main`. Keeps PR feedback fast without
  losing the safety net.

---

## 3. Adoption triggers (summary)

| Trigger | Adopt |
|---|---|
| App grows (any size) | Gem layer cache + CI bundler-cache (already on) |
| Local suite feels slow (~30s) | Tag `:integration`, fast lane, `--only-failures` |
| Full suite >1–2 min | `parallel_tests` + CI shard matrix |
| DB setup >~15s (many migrations) | Postgres template-DB snapshot |
| CI slow even sharded | Predictive selection (crystalball) on PRs |

Don't skip ahead — each tier adds moving parts. Add the next one only when a
measurement says the current setup hurts.

See ADR-0013 for the decision record.
