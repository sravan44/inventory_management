# ADR-0013: Dev & test performance strategy (tiered, trigger-based)

**Status:** Accepted
**Date:** 2026-07-25

## Context

As the codebase and test suite grow, build and test times grow with them. We want
a plan so speed doesn't quietly degrade — without over-engineering early (YAGNI).

## Decision

Adopt performance techniques in **tiers, each gated by a measured trigger** (full
detail in `docs/DEV_PERFORMANCE.md`):

- **Gems (now, already in place):** rely on Docker layer caching (Gemfile copied
  before app code, `bundle install` in its own layer) + CI `bundler-cache`. No
  runtime bundle volume (it shadows the image's gems). Add `BUNDLE_JOBS`/`RETRY`.
  This already gives "reinstall only when a gem changes."
- **Tests (in place):** transactional fixtures, bootsnap, example-status
  persistence, random order.
- **Tier 1 (local suite ~>30s):** tag slow Apartment specs `:integration`; fast
  lane skips them; `--only-failures`.
- **Tier 2 (suite >1–2 min):** `parallel_tests` + CI shard matrix.
- **Tier 3 (DB setup slow):** snapshot the schema via a **Postgres template
  database** (migrate once, create per-run DBs `WITH TEMPLATE`), preferred over a
  committed schema dump (which reintroduces structure.sql + psql-in-CI + Apartment
  clone interactions).
- **Tier 4 (CI slow even sharded):** predictive test selection (crystalball) on PRs.

## Alternatives Considered

- Optimize everything up front — rejected (YAGNI; adds moving parts we don't need).
- Runtime bundle cache volume — rejected (shadows image gems; already bit us).
- Commit `structure.sql` and load it for speed — deferred to a fallback; the
  template-DB approach avoids the psql/Apartment friction we hit earlier.

## Consequences

- Immediate change: `BUNDLE_JOBS=4 BUNDLE_RETRY=3` in the Dockerfile.
- Future tiers are documented with triggers; adopt on measurement, not vibes.
- When Tier 2 lands, the Apartment provisioning specs must namespace tenant schema
  names per parallel worker to avoid collisions (noted in the strategy doc).

## Related

Depends on: ADR-0002 (Apartment shapes the DB-snapshot choice), commit-0.1/0.3
(Docker + CI). Detailed guide: `docs/DEV_PERFORMANCE.md`.
