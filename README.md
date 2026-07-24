# Inventory Management

Multi-tenant SaaS for full supply-chain inventory management.
Architecture and decisions live in [`docs/`](docs/ARCHITECTURE.md).

## Monorepo layout

```
Inventory Management/
├── backend/     # Rails 7 API-only app (Postgres, schema-per-tenant)
├── frontend/    # React SPA (Vite) — added in Milestone 6
├── docs/        # ARCHITECTURE.md, DATABASE.md, API_DESIGN.md, ADRs, build plan
└── .editorconfig
```

Why a monorepo: one place to version the API and the client together, atomic
cross-cutting changes (a new field + the UI that uses it in one PR), and shared
tooling/CI config. The two apps still deploy independently.

## Build sequence

Implemented commit-by-commit per [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md).
Current: **Milestone 0 — commit 0.1 (Rails API skeleton + health check).**

## Quickstart (Docker — no Ruby/Postgres install needed)

Only Docker is required. Full explained setup in
[`docs/step7/commit-0.1.md`](docs/step7/commit-0.1.md). Short version:

```bash
cp .env.example .env
docker compose build
docker compose up -d
docker compose exec web rails db:create
curl http://localhost:3000/up        # -> {"status":"ok",...}
docker compose exec web bundle exec rspec
```
