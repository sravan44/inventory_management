# ADR-0016: Observability — exception tracking + pluggable LLM log viewer

**Status:** Accepted
**Date:** 2026-07-25

## Context

We want (a) to catch application errors/exceptions, and (b) to search the audit
logs in natural language to find events/problems — over a reusable viewer that can
read from Mongo and/or a plain log file ("plug and view for any app").

## Decision

### Exception tracking
Use **Sentry** (`sentry-ruby`/`sentry-rails`), initialized only when `SENTRY_DSN`
is set (inert in dev/test/CI). Point `SENTRY_DSN` at Sentry.io or a self-hosted,
Sentry-compatible server (GlitchTip). `send_default_pii = false`.

### Pluggable log viewer + NL search
A source-abstracted viewer (`Audit::LogViewer`) queries **enabled sources** and
merges results newest-first:
- **`Sources::MongoSource`** — the tenant-scoped audit store.
- **`Sources::FileSource`** — any log file at `AUDIT_LOG_FILE` (grep + best-effort
  timestamp parse). Global, so surfaced only to platform super-admins.

Natural-language search:
- **`Audit::Llm`** (OpenAI via `ruby-openai`, gated on `OPENAI_API_KEY`) translates
  the query into a small JSON filter. Returns nil when unavailable → callers fall
  back to keyword search.
- **`Audit::LogSearch.sanitize`** reduces that (LLM- or user-provided) filter to a
  strict allow-list (`action_contains`, `actor_type` ∈ {User, ApiKey}, date range).
  **This is the security boundary** — the model never yields raw queries; only
  allow-listed, validated fields reach a source. No NoSQL/grep injection via prompt.

Exposed on the existing endpoint: `GET /api/v1/activity_logs?nl=...` (or `?q=`),
returning the `interpreted_filter` so users see how their NL was understood.

## Alternatives Considered

- Meilisearch / OpenSearch — great full-text/typo-tolerant search + UI, but adds a
  service and isn't literally NL. Good future upgrade at scale.
- Mongoid + rich query DSL exposed to clients — rejected; unsafe and couples clients
  to Mongo.
- Errbit (self-hosted exception app) — heavier than Sentry-compatible DSN; can still
  point `SENTRY_DSN` at a self-hosted GlitchTip.

## Consequences

- New optional deps (Sentry, ruby-openai) and env vars — all inert when unset, so
  CI/tests need no keys (LLM is stubbed in specs; file source uses a tempfile).
- NL quality depends on the LLM; the sanitize allow-list caps what it can do (safe
  by construction, but also bounds expressiveness — extend the allow-list as needed).
- File source is line-grep + best-effort dates; for large/structured logs, move to a
  real search engine. It's global, hence super-admin-only.
- Latency: an NL query makes one LLM call; keep it out of hot paths (it's an
  admin/ops feature).

## Related

Builds on ADR-0007 (audit pipeline). Detailed guide: `docs/step7/commit-5.3.md`.
