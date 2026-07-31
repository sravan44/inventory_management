# ADR-0012: API documentation via rswag (OpenAPI), Postman by import

**Status:** Accepted
**Date:** 2026-07-25

## Context

We want an always-current API collection (for Postman and for humans) without
hand-maintaining a Postman JSON file on every endpoint change — that drifts and is
tedious.

## Decision

Describe each HTTP endpoint once, in an **rswag** request spec. rswag examples:
1. run as real **request tests** (`run_test!` issues the call and asserts status),
2. generate an **OpenAPI 3** document (`rake rswag:specs:swaggerize` →
   `swagger/v1/swagger.yaml`),
3. are served as **Swagger UI** at `/api-docs`.

**Postman** imports the generated OpenAPI file directly (File → Import →
`swagger/v1/swagger.yaml`), and re-imports to pick up changes. So the spec is the
single source of truth for tests, docs, and Postman.

## Alternatives Considered

- Hand-maintained Postman collection JSON (the previous approach) — no source of
  truth, drifts, tedious per-endpoint edits.
- A rake task introspecting routes → Postman — fully automatic but shallow (no
  request/response validation, bespoke code to maintain).
- rspec_api_documentation — viable, smaller ecosystem than rswag.
- rswag (chosen) — one artifact drives tests + docs + Postman; OpenAPI is a
  portable standard.

## Consequences

- HTTP endpoint specs are written in the rswag DSL (`require "swagger_helper"`),
  replacing plain request specs for the API surface. They still run in CI as tests.
- Generate the doc with `rake rswag:specs:swaggerize`; commit
  `swagger/v1/swagger.yaml` (or generate in CI). Swagger UI at `/api-docs`.
- The static `postman/*.json` collection is superseded; keep it only as a manual
  fallback. Importing the OpenAPI file is the supported path.
- Auth in the docs uses a `bearer_auth` security scheme; specs set
  `let(:Authorization)`.

## Related

Refines: API_DESIGN.md (that's the human spec; this is the executable/importable one).
Supersedes the hand-maintained Postman collection workflow.
