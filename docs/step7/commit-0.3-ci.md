# Commit 0.3 — GitHub Actions CI (narrated)

Goal: every push and pull request automatically runs the test suite (plus lint and
security), and the badge goes green. Configured to be light on the **free plan**.

File: `.github/workflows/ci.yml`.

---

## IMPORTANT: when this actually turns green

CI runs `bundle install` and `rspec` against the app in `backend/`. That only
works once the **full generated Rails app is committed** — the `rails new` output
from commit 0.1 (`Gemfile`, `Gemfile.lock`, `config/`, `bin/rails`, etc.). Our repo
currently holds only the authored delta files, so the first CI run will be **red**
until you:

1. Generate the app (commit 0.1, Step A — the Dockerized `rails new`).
2. Add the gems (commit 0.1, Step C) — including `rubocop-rails-omakase`.
3. Commit `Gemfile`, `Gemfile.lock`, and the generated tree.

After that, CI is green. This is expected and correct — the workflow is ready and
waiting for the app it tests.

---

## The three jobs

They run in parallel, so total wall-clock ≈ the slowest one.

### 1. `backend-test` — the one you care about
- Starts a **Postgres 16 service container** with a healthcheck; the test steps
  don't begin until `pg_isready` passes.
- `ruby/setup-ruby@v1` installs Ruby from `backend/.ruby-version` and, with
  `bundler-cache: true`, **caches gems between runs** — the single biggest
  free-minute saver.
- Env vars (`DATABASE_HOST=localhost`, user/password `postgres`) match our
  `database.yml`, so no CI-specific DB config is needed.
- `bin/rails db:prepare` creates + loads the test database, then `bundle exec
  rspec` runs the suite.

### 2. `backend-lint` — RuboCop
- Uses the Rails-team **omakase** ruleset (`backend/.rubocop.yml` inherits it), so
  generated + our code passes without style bikeshedding. Add the gem:
  `gem "rubocop-rails-omakase", require: false`.
- If it ever flags something, `bundle exec rubocop -A` auto-corrects most of it.

### 3. `backend-security` — Brakeman + bundler-audit
- **Brakeman** statically scans for common Rails vulns (SQLi, mass assignment,
  etc.) — ties directly to the OWASP checks in your project rules. Run with
  `--no-exit-on-warn` **for now**: we're deliberately on EOL Rails 7.1.6 (to demo
  the upgrade in Milestone U), and that EOL warning must not fail the build.
  Brakeman still scans and prints findings; we restore blocking (drop the flag)
  after the upgrade. Do NOT confuse this temporary flag with ignoring real vulns.
- **bundler-audit** fails the build if any gem has a known CVE.

---

## Free-plan notes

- **Public repo → unlimited free Actions minutes.** Private repo → 2,000
  min/month on the free tier. This workflow is small; each run is a few minutes.
- `concurrency: cancel-in-progress` cancels a superseded run when you push again
  to the same branch/PR — no paying for two runs of stale code.
- `bundler-cache: true` avoids reinstalling gems every run.
- Optional further saving: add a `paths:` filter so docs-only commits skip CI.
  Left off for now so nothing surprising slips through; enable if minutes get
  tight.

---

## Make the badge visible (optional)

Add to the top of `README.md` (replace with your repo path if different):

```markdown
![CI](https://github.com/sravan44/inventory_management/actions/workflows/ci.yml/badge.svg)
```

---

## Push and watch it run

```bash
git add .github/workflows/ci.yml backend/.rubocop.yml
git commit -m "ci: add GitHub Actions (rspec + rubocop + brakeman + bundler-audit)"
git push
```

Then open the **Actions** tab on GitHub to watch the jobs. Green once the
generated app is committed (see the note above).

## Commit message

```
ci: add GitHub Actions pipeline (free-plan friendly)

- backend-test: postgres service + db:prepare + rspec, gem caching
- backend-lint: rubocop (rails omakase ruleset)
- backend-security: brakeman + bundler-audit
- concurrency cancel-in-progress to conserve minutes
```
