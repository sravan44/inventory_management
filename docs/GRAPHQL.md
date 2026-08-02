# GraphQL documentation

**Why not Swagger?** Swagger/OpenAPI describes a **REST** API — resources, HTTP
verbs, status codes. GraphQL has a single endpoint (`POST /graphql`) and a type
system, so it doesn't map onto OpenAPI. It's documented the GraphQL-native way:

1. **Introspection + GraphiQL** — an interactive explorer that reads the live
   schema (types, fields, args, docs) and lets you run queries.
2. **SDL schema file** — `app/graphql/schema.graphql`, the committed contract
   (the GraphQL analogue of `swagger.yaml`).

So the split is: **Swagger UI (`/api-docs`) for REST**, **GraphiQL for GraphQL**.

---

## GraphiQL (interactive)

Served as a static page at `/graphiql.html`. GraphQL is tenant-scoped and
user-JWT-only, so:

1. Open it on a **tenant subdomain**: `http://acme.lvh.me:3000/graphiql.html`.
2. In the **Headers** panel, add your access token:
   ```json
   { "Authorization": "Bearer <access_token>" }
   ```
   (Get a token from `POST /api/v1/auth/login`.)
3. Explore: the Docs/Explorer panel is built from introspection; run queries and
   mutations live.

Introspection is enabled in dev/test and **disabled in production** (schema isn't a
public map), so GraphiQL's docs panel works locally but not against prod.

---

## SDL schema (the contract)

Regenerate the committed schema file whenever the GraphQL surface changes:

```bash
docker compose exec web bin/rails graphql:schema:dump
# writes app/graphql/schema.graphql
```

Commit `schema.graphql` — diffs to it show exactly how the GraphQL contract
changed, and it's what client codegen tools consume.

---

## Current surface (Milestone 4 so far)

- Query: `viewer`, `products(active:, query:, first:/after:)` (connection).
- Mutation: `setProductActive(input: { id, active })`, `ping`.

More arrives with warehouses and stock (commits 4.4–4.6).
