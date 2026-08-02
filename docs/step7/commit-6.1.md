# Commit 6.1 — React SPA skeleton (narrated)

Goal: stand up the frontend — Vite + TypeScript + **React 16** — that boots, renders,
and has a passing test. React 16 is deliberate: it's the starting point for the
16 → 18 upgrade demo (Milestone U).

Opens Milestone 6. Lives in `frontend/` (monorepo alongside `backend/`).

---

## Why Vite (not Create React App)

Vite is the modern React build tool: instant dev server (native ESM, no bundling
in dev), fast HMR, and a simple production build. CRA is deprecated. `npm run dev`
serves `index.html` → `src/main.tsx`.

## The pieces

- **`package.json`** — React 16.14 + react-dom 16.14, Vite, TypeScript, Vitest +
  Testing Library, ESLint, Prettier. Scripts: `dev`, `build`, `lint`, `test`.
- **`index.html`** — the single page; `<div id="root">` + a module script loading
  `src/main.tsx`. (In Vite, the HTML is the entry point.)
- **`src/main.tsx`** — mounts the app. Note it uses **`ReactDOM.render(...)`** —
  React 16's API. Milestone U swaps this for React 18's
  `ReactDOM.createRoot(el).render(...)`. This one line is the crux of the upgrade.
- **`src/App.tsx`** — the root component (a placeholder for now).
- **`vite.config.ts`** — the React plugin, dev server on `0.0.0.0:5173` (reachable
  from the container), and the Vitest config (jsdom env + setup file).
- **TypeScript** (`tsconfig.json`) — `jsx: "react-jsx"` uses the new JSX transform
  (available since React 16.14), so components don't need `import React`.
- **Testing** — Vitest (Vite-native, Jest-compatible API) + Testing Library.
  `App.test.tsx` renders `<App/>` and asserts the heading is present.
- **ESLint + Prettier** — lint (react + hooks rules) and formatting.

## Why React 16.14 specifically

16.14 is the first React 16 with the **new JSX runtime**, so it works cleanly with
Vite's React plugin and `jsx: "react-jsx"`. Older 16.x would force
`import React from "react"` in every file. So we get a modern DX on an old React —
ideal for demonstrating the upgrade later without fighting tooling now.

---

## Running it

The `npm install` (which generates `package-lock.json`) happens on your machine /
in the container — like `rails new` / `bundle install`. Two ways:

**Docker (added to compose):**
```bash
docker compose up -d frontend
# open http://localhost:5173
docker compose exec frontend npm test
```
The `frontend` service builds `Dockerfile.dev`, and an anonymous `/app/node_modules`
volume keeps the image's installed deps from being shadowed by the source
bind-mount (the same shadowing lesson as the backend's gems).

**Local (if you have Node 20):**
```bash
cd frontend && npm install && npm run dev
```

CI runs a `frontend-test` job (install → lint → test) on Node 20.

---

## What this commit does and doesn't do

Does: a bootable, tested React 16 + TS skeleton with tooling + CI.

Doesn't: talk to the API yet. Commit 6.2 adds the Apollo GraphQL client + a REST
client and tenant-subdomain routing; 6.3+ build the auth flow and the product/stock
screens.

## Commit message

```
feat(frontend): React 16 + Vite + TypeScript skeleton

- Vite + @vitejs/plugin-react; React 16.14 (ReactDOM.render — 18 upgrade in M-U)
- TypeScript (react-jsx), Vitest + Testing Library (App test), ESLint + Prettier
- Docker frontend service (Dockerfile.dev, anonymous node_modules volume)
- CI frontend-test job (install/lint/test on Node 20)
```
