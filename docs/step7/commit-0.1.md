# Commit 0.1 — Dockerized Rails API skeleton + health check (narrated)

Goal: an API-only Rails app that boots **inside Docker** and answers `GET /up`
with `{"status":"ok"}`, with RSpec wired up and a passing request spec. You need
**only Docker installed** — no Ruby, no Postgres on your laptop. This also folds
in the docker-compose dev environment (originally commit 0.2).

Prerequisite: **Docker Desktop** (or Docker Engine + Compose v2). Check with
`docker --version` and `docker compose version`.

---

## The mental model

- `docker-compose.yml` (repo root) describes the services: **`db`** (Postgres) and
  **`web`** (our Rails app). One command starts both, wired together.
- `backend/Dockerfile` describes how to build the `web` image: start from Ruby
  3.3.5, install build tools + Postgres client libs, install gems, run the server.
- Code lives on your machine but *runs* in the container. `docker-compose.yml`
  bind-mounts `./backend` into the container at `/app`, so editing a file locally
  is instantly visible inside — no rebuild for code changes.
- The app finds Postgres by the hostname **`db`** — Docker's internal DNS resolves
  a service name to its container. That's why `config/database.yml` reads
  `DATABASE_HOST`, which compose sets to `db`.

---

## Step A — Generate the Rails skeleton (inside a container)

We don't install Rails locally; we run `rails new` in a throwaway Ruby container.
From the repo root (`Inventory Management/`):

```bash
docker run --rm -v "$PWD/backend:/app" -w /app ruby:3.3.5-slim \
  bash -c "gem install rails -v '~> 7.1' && rails new . --force --api --database=postgresql --skip-test --skip-bundle"
```

Reading that command:

- `docker run --rm` — run a one-off container and delete it when done (`--rm`).
- `-v "$PWD/backend:/app"` — mount your local `backend/` folder into the container
  at `/app`, so the files Rails generates land on your machine.
- `-w /app` — set the working directory inside the container to `/app`.
- `ruby:3.3.5-slim` — the image to run (same Ruby as our Dockerfile).
- `gem install rails -v '~> 7.1'` — install the Rails CLI, pinned to the 7.1 line.
- `rails new .` — generate the app in the current dir (`/app` = your `backend/`).
- `--force` — overwrite conflicts. Our repo already ships a few authored files
  (`config/routes.rb`, `config/database.yml`, the health controller); `--force`
  will overwrite `routes.rb` and `database.yml` with generic versions — **you then
  restore ours** (they're in git / listed in Step D). The health controller and
  spec are new paths Rails won't touch.
- `--api` — API-only app: `ApplicationController < ActionController::API`. No
  cookies, sessions, views, or CSRF middleware — a JSON API for a separate React
  SPA needs none of that. Leaner and faster.
- `--database=postgresql` — Postgres config + the `pg` gem. Required for
  schema-per-tenant multi-tenancy later (ADR-0002).
- `--skip-test` — skip Minitest; we use **RSpec** (Step C).
- `--skip-bundle` — don't run `bundle install` now; it happens in the image build
  where the native gems (pg) can compile against the installed system libs.

> Most of the ~100 generated files are standard Rails scaffolding — don't hand-edit
> them. The files that make up *this commit* are in Step D.

---

## Step B — Restore the commit-0.1 files that `--force` overwrote

`rails new --force` replaced `config/routes.rb` and `config/database.yml` with
generic versions. Restore this repo's versions (they add the health route and the
env-driven DB config). If you're working from this repo, just:

```bash
git checkout -- backend/config/routes.rb backend/config/database.yml
```

(Or copy them back from `docs/step7`—their contents are shown in Step D.)

---

## Step C — Add the quality + test gems

Edit `backend/Gemfile`, adding:

```ruby
group :development, :test do
  gem "rspec-rails", "~> 6.1"   # test framework (instead of Minitest)
  gem "dotenv-rails"            # loads .env so config/secrets stay out of code
end

group :development do
  gem "rubocop-rails-omakase", require: false  # Rails-team style ruleset (CI lint gate)
  gem "brakeman", require: false               # static security scanner (CI gate)
  gem "bundler-audit", require: false          # flags gems with known CVEs (CI gate)
end
```

These get installed when we build the image in Step E.

---

## Step D — The files this commit authors

The meaningful diffs — the parts worth understanding. All already in the repo:

1. **`docker-compose.yml`** (root) — declares `db` + `web`, the bind-mount, the
   gem cache volume, and `depends_on: db healthy` so `web` waits for Postgres.
2. **`backend/Dockerfile`** — Ruby 3.3.5 base, system build deps, gem install
   layer (cached), server start command bound to `0.0.0.0`.
3. **`backend/config/database.yml`** — reads host/user/password from ENV so the
   same file works in Docker (`DATABASE_HOST=db`) and locally.
4. **`backend/config/routes.rb`** — `get "up" => "health#show"`.
5. **`backend/app/controllers/health_controller.rb`** — renders
   `{ status: "ok", time: ... }`, HTTP 200. No DB, no auth — cheapest possible
   action so monitors can hammer it safely.
6. **`backend/spec/requests/health_spec.rb`** — real `GET /up`, asserts 200 +
   `status == "ok"`.
7. **`.editorconfig`** + **`.env.example`** (root) — shared whitespace rules; env
   template (copy to `.env`, which is gitignored).

---

## Step E — Build and run the whole stack

```bash
docker compose build      # builds the web image (installs gems, compiles pg)
docker compose up         # starts db + web; web waits for db to be healthy
```

Then initialize RSpec and the databases INSIDE the running container. `exec` runs
a command in the already-running `web` service:

```bash
docker compose exec web rails generate rspec:install
docker compose exec web rails db:create
```

- `rails generate rspec:install` — scaffolds `spec/`, `rails_helper.rb`,
  `spec_helper.rb`, `.rspec`. (Our `spec/requests/health_spec.rb` then has its
  `require "rails_helper"` satisfied.)
- `rails db:create` — creates the `inventory_development` and `inventory_test`
  Postgres databases on the `db` container.

Check it:

```bash
curl http://localhost:3000/up
# => {"status":"ok","time":"2026-07-24T20:00:00Z"}
```

---

## Step F — Prove it with the test

```bash
docker compose exec web bundle exec rspec
```

Expected: the two examples in `health_spec.rb` pass (green). That green run is the
**definition of done** for commit 0.1.

Common commands from here on:

```bash
docker compose up -d        # run in background
docker compose logs -f web  # tail the app logs
docker compose exec web bash  # shell inside the container
docker compose down         # stop everything (add -v to also wipe volumes/data)
```

---

## What we deliberately did NOT do yet

No models, no tables, no auth, no tenancy, no GraphQL, no Redis/Mongo (those
services get added to `docker-compose.yml` in Milestones 3 and 5, when first
needed). Commit 0.1 is only "the containerized app boots and serves one endpoint,
proven by a test." Multi-tenancy starts in Milestone 1.

## Commit message

```
chore: dockerized API-only Rails skeleton with health check

- docker-compose (web + postgres), backend Dockerfile on ruby:3.3.5
- rails new backend --api --database=postgresql --skip-test
- env-driven database.yml; pin Ruby 3.3.5
- add rspec-rails + rubocop/brakeman/bundler-audit
- GET /up health endpoint + request spec
- repo-root .editorconfig, .env.example
```
