# Commit 3.4 — GraphQL setup (narrated)

Goal: stand up the first-party GraphQL surface (ADR-0009) — schema at `/graphql`,
authenticated, tenant-scoped, with the guardrails GraphQL specifically needs.
Real listing/mutation fields (products, stock, …) come in Milestone 4; this commit
is the plumbing, proven by a `viewer` query.

Depends on: 2.6 (tenant stack), 3.3 (auth actors).

---

## Layout (graphql-ruby)

Standard structure under `app/graphql/`:
- `types/base_*` — base classes all types inherit (field/argument/object/enum/input).
- `mutations/base_mutation.rb` — base for mutations (Relay classic).
- `types/query_type.rb` — the read root. Has `viewer` for now.
- `types/mutation_type.rb` — the write root. Has a `ping` placeholder (a GraphQL
  object can't be empty; real mutations arrive in M4).
- `types/viewer_type.rb` — "who am I here", resolved from request context.
- `inventory_management_schema.rb` — the schema, wiring query + mutation + controls.

---

## The schema's guardrails

```ruby
use GraphQL::Batch                 # batch-load associations -> no N+1
max_depth 12                       # reject absurdly nested queries
max_complexity 200                 # reject absurdly expensive queries
disable_introspection_entry_points if Rails.env.production?
rescue_from(StandardError) { ... } # generic error in prod; re-raise in dev
```

Why these matter: REST limits abuse per-endpoint, but a single GraphQL query can
ask for anything. **Depth + complexity limits are GraphQL's rate limit** — they
bound how expensive one request can be. Batch loading prevents the classic N+1
that nested GraphQL resolvers cause. Introspection is off in prod so the schema
isn't a public map.

---

## The controller — first-party, JWT only

`GraphqlController` (POST `/graphql`, tenant subdomain):

```
TenantResolution  -> Current.tenant (404 unknown / 403 inactive)
authenticate_user! -> Bearer JWT -> Current.user (Authenticatable)
require_membership! -> active membership -> Current.membership (403 otherwise)
```

Crucially it uses `authenticate_user!` (Bearer), **not** `ActorAuthentication`. So
an `Api-Key` credential fails JWT decoding → 401. That's ADR-0009 enforced in code:
**GraphQL is first-party, user-JWT only; API keys are REST-only.** The user,
membership, and tenant are passed into the GraphQL `context` for resolvers to read.

No GraphiQL UI is mounted (it needs Sprockets, which we removed); query via
Postman/curl, or add GraphiQL later if wanted.

---

## Tests

`spec/requests/graphql_spec.rb`: `viewer` for a member (email/role/subdomain),
`ping` mutation, 401 without a token, 403 non-member, and **Api-Key rejected**
(401) — proving the first-party-only rule.

```bash
docker compose exec web bundle exec rspec spec/requests/graphql_spec.rb
```

Try it live:
```bash
TOKEN=$(curl -s -X POST http://localhost:3000/api/v1/auth/login \
  -H 'Content-Type: application/json' -d '{"email":"sam@acme.io","password":"hunter2pw"}' | jq -r .access_token)

curl -s -X POST http://acme.lvh.me:3000/graphql \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"query":"{ viewer { email role tenantSubdomain } }"}' | jq
```

---

## What this commit does and doesn't do

Does: the GraphQL plumbing — schema, auth, context, DoS controls, batch loading.

Doesn't: expose domain data (products/stock queries + status mutations) — that's
Milestone 4, where types/resolvers call the same services the REST controllers use.

## Commit message

```
feat(graphql): first-party GraphQL surface at /graphql

- add graphql + graphql-batch; base types/mutation + schema
- QueryType#viewer, MutationType#ping placeholder
- schema: batch loading, max_depth/complexity, introspection off in prod
- GraphqlController: tenant resolution + Bearer-only auth + membership
  (rejects API keys -> ADR-0009); request specs
```
