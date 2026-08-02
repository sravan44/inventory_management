# Commit 5.3 — Observability: Sentry + pluggable LLM log viewer (narrated)

Goal: catch application **errors/exceptions**, and search the audit logs in
**natural language** — over a reusable viewer that can read from **Mongo and/or a
log file** ("plug and view for any app"). ADR-0016.

Depends on: 5.1–5.2 (audit pipeline).

---

## Exception tracking (Sentry)

`sentry-ruby` + `sentry-rails`, initialized **only when `SENTRY_DSN` is set** —
inert in dev/test/CI (no account needed). Point the DSN at Sentry.io or a
self-hosted, Sentry-compatible server (**GlitchTip**) and unhandled exceptions +
job failures flow there. `send_default_pii = false` keeps user PII out of the
tracker. This is the "get the app errors" half.

---

## Pluggable log viewer + NL search (the "get the audit errors" half)

A **source abstraction** so any app can plug in what it has:

```
LogViewer.search(text:, tenant_id:, include_files:)
  → Audit::Llm.translate(text)        # NL → JSON filter (or nil)
  → Audit::LogSearch.sanitize(filter) # allow-list ONLY (security boundary)
  → MongoSource (tenant audit store)  + FileSource (a log file, super-admins)
  → merge newest-first
```

- **`Sources::MongoSource`** — the tenant-scoped audit store (structured query).
- **`Sources::FileSource`** — reads `AUDIT_LOG_FILE` (any app's log path): greps
  matching lines, best-effort-parses a leading timestamp for date filtering. It's
  global, so it's only included for platform **super-admins**.
- Set `MONGO_URL` and/or `AUDIT_LOG_FILE` to choose your source(s).

### Natural language, safely
- **`Audit::Llm`** (OpenAI via `ruby-openai`, gated on `OPENAI_API_KEY`) turns
  "failed logins yesterday" into a tiny JSON filter. If no key / it errors → nil,
  and we **fall back to keyword search** — the feature degrades, never breaks.
- **`Audit::LogSearch.sanitize`** is the security boundary: whatever the LLM
  returns, only `action_contains` / `actor_type` (∈ User/ApiKey) / date range
  survive. The model can **never** produce raw Mongo or grep — no
  injection-via-prompt. The endpoint also returns the `interpreted_filter` so the
  admin sees how their words were understood.

Exposed on the existing endpoint:
- `GET /api/v1/activity_logs?nl=<plain english>` — NL search.
- `GET /api/v1/activity_logs?q=<keyword>` — keyword search.
- `GET /api/v1/activity_logs?date=YYYY-MM-DD` — a day's logs (from 5.2).

---

## Tests (no keys/services needed)

- `log_search_spec.rb` — sanitize keeps only allow-listed keys; drops a bad
  `actor_type` and invalid dates (the injection guard).
- `log_viewer_spec.rb` — uses the (stubbed) LLM filter; falls back to keyword when
  the LLM is nil; tags entries with their `source`.
- `sources/file_source_spec.rb` — greps a tempfile, tags `file` entries, date-range
  filters, disabled when unconfigured.

```bash
docker compose exec web bundle exec rspec spec/services/audit
```

Live (optional keys):
```bash
# exception tracking: set SENTRY_DSN in .env
# NL search: set OPENAI_API_KEY in .env, then:
curl -s "http://acme.lvh.me:3000/api/v1/activity_logs?nl=failed%20logins%20yesterday" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq
# file source: set AUDIT_LOG_FILE and query as a super-admin
```

---

## What this commit does and doesn't do

Does: exception tracking; NL + keyword log search; a pluggable viewer over Mongo +
file sources, safely.

Doesn't: instrument the app to EMIT audit events yet (commit 5.3-instrument /
next: sprinkle `Audit::Logger.log` into create/update/stock/auth), build a rich UI
(that's the React SPA, M6), or adopt a real search engine (future, at scale).

## Commit message

```
feat(observability): Sentry exception tracking + pluggable LLM log viewer (ADR-0016)

- sentry-ruby/rails, gated on SENTRY_DSN (GlitchTip-compatible)
- Audit::Llm (OpenAI, gated) NL -> filter; Audit::LogSearch allow-list (injection guard)
- Audit::LogViewer over Sources::MongoSource + Sources::FileSource (AUDIT_LOG_FILE)
- activity_logs?nl=/?q= with interpreted_filter; ActivityLogStore#query
- specs with stubbed LLM + tempfile (no keys/services in CI)
```
