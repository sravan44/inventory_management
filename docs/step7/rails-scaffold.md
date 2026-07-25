# Rails core scaffolding (hand-authored)

Normally `rails new` generates these. They're hand-authored here so the repo is a
complete, bootable Rails 7.1 API app without you having to run the generator and
reconcile it against our custom files. Every file is annotated with what it does.

## What was added

Boot & config:
- `Gemfile` — all dependencies (rails, pg, puma, bcrypt, ros-apartment, rspec,
  rubocop-omakase, brakeman, bundler-audit, etc.)
- `config/boot.rb`, `config/application.rb`, `config/environment.rb`, `config.ru`,
  `Rakefile`
- `config/environments/{development,test,production}.rb`
- `config/puma.rb`
- `config/initializers/{filter_parameter_logging,cors}.rb`

App base classes:
- `app/controllers/application_controller.rb` (`ActionController::API`)
- `app/models/application_record.rb`
- `app/jobs/application_job.rb`

Executables & tests:
- `bin/rails`, `bin/rake`, `bin/setup` (chmod +x)
- `.rspec`, `spec/spec_helper.rb`, `spec/rails_helper.rb`

Key choices baked in:
- `config.api_only = false` (full middleware stack) but **API-first**: JSON
  controllers inherit `ActionController::API` (lean), so we get mailer/admin
  support without weighing down the API. ERB kept minimal (mailer layouts only).
- `config.active_record.schema_format = :sql` (preserve Postgres schemas, partial
  indexes, citext, jsonb — ADR-0002)
- `config.hosts.clear` in dev + test (tenant subdomains / subdomain specs)
- secret/PII params filtered from logs

## The one file you must still generate: Gemfile.lock

`Gemfile.lock` pins exact resolved versions and can only be produced by Bundler —
it's not safe to hand-write. Generate it (and bake the image) with:

```bash
docker compose build web        # runs `bundle install` inside the image
# then copy the lock out so it's committed, or run install against the mount:
docker compose run --rm web bundle install
```

`bundle install` writes `backend/Gemfile.lock`. **Commit it** — it's what
guarantees identical gems locally and in CI.

## First full boot + test run

```bash
cp .env.example .env
docker compose build
docker compose up -d
docker compose exec web bin/rails db:prepare
docker compose exec web bundle exec rspec
curl http://localhost:3000/up
```

Once `Gemfile.lock` is committed, CI (commit 0.3) goes green.
