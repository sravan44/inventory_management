# Application Layers & Patterns

The conventions every domain follows. The goal: **thin models, thin controllers,
thin resolvers** — behavior lives in named, single-responsibility objects that are
easy to test and reuse across the REST and GraphQL surfaces (ADR-0009).

Request flow, top to bottom:

```
HTTP request
  → Controller (REST)  /  Resolver (GraphQL)   ── thin: parse input, authorize, delegate
      → Service Object                          ── business operation / workflow
          → Model (ActiveRecord)                ── persistence + invariants only
      → Worker (ActiveJob)                      ── async side-effects (email, logs, provisioning)
  ← Decorator                                   ── presentation logic (computed/display fields)
  ← Serializer (Blueprinter)                    ── shape the JSON response
Mailer (ActionMailer)                           ── transactional email, itself enqueued as a job
```

Each layer has ONE reason to change. Details below.

---

## 1. Service Objects — business operations

**Where:** `app/services/<domain>/*.rb` (e.g. `Identity::TenantProvisioningService`).
**Shape:** a PORO with a `.call` class-method convention.
**Owns:** a single workflow/use-case — the "verb" of the system (provision a
tenant, record a stock movement, authenticate a user).

Why: keeps controllers and models thin, and makes the operation reusable from a
controller, a GraphQL mutation, a job, a rake task, or the console — identical
behavior everywhere (DRY). Already in use: `TenantProvisioningService`.

```ruby
module Inventory
  class StockMovementService
    def self.call(...) = new(...).call
    def call
      # validate → write ledger row → update projection, in one transaction
    end
  end
end
```

Rules: no HTTP concerns inside; raise domain errors or return a result object;
one public `#call`.

---

## 2. Workers — async side-effects

**Where:** `app/jobs/<domain>/*.rb` (e.g. `Identity::ProvisionTenantJob`).
**Shape:** `ActiveJob` subclass of `ApplicationJob`; a **thin wrapper** that calls
a service. Runs on the default adapter now, **Sidekiq (Redis)** from Milestone 5.
**Owns:** anything that shouldn't block the request — provisioning, sending email,
emitting audit logs.

Why: keeps requests fast and resilient (a slow/broken side-effect can't fail the
user's action). Rules: pass **ids, not records** (queue-serialization safe);
assume **at-least-once** delivery → make the work idempotent.

---

## 3. Serializers — shape the JSON

**Where:** `app/serializers/<domain>/*_serializer.rb` (or `app/blueprints/`).
**Library:** **Blueprinter** (`gem "blueprinter"`).
**Owns:** which fields go out, field names, versioned "views" of a resource.

Why a dedicated layer: response shape is a contract with clients; keeping it out
of models/controllers means the shape can change without touching business logic,
and REST + GraphQL can reuse the same field definitions.

```ruby
module Inventory
  class ProductSerializer < Blueprinter::Base
    identifier :id
    fields :sku, :name, :unit_of_measure, :active
    view(:detail) { association :stock_levels, blueprint: StockLevelSerializer }
  end
end
```

Serializer vs. Decorator: the serializer decides **what JSON comes out**; the
decorator decides **how a value is computed/presented**. Serializers call
decorators, not the other way around.

---

## 4. Decorators — presentation logic

**Where:** `app/decorators/<domain>/*_decorator.rb`.
**Shape:** PORO wrapping a model via `SimpleDelegator` (base:
`ApplicationDecorator`). No gem needed; avoids Draper's view-layer coupling in an
api_only app.
**Owns:** computed/display values derived from a model — full name, formatted
status label, `available_quantity = on_hand - reserved`.

Why: keeps derived-for-display logic out of the model (which should own
persistence + invariants, not presentation) and out of serializers (which should
just pick fields).

```ruby
module Inventory
  class StockLevelDecorator < ApplicationDecorator
    def available_quantity = quantity_on_hand - quantity_reserved
  end
end
```

---

## 5. Mailers — transactional email

**Where:** `app/mailers/*.rb` (base `ApplicationMailer`), templates in
`app/views/<mailer>/`.
**Library:** built-in **ActionMailer**.
**Owns:** user-facing email: membership invitations, password resets, tenant-ready
notifications.

Why/how: mail is a side-effect, so **always deliver via a job**
(`.deliver_later`, which enqueues on our worker queue) — never block a request on
SMTP. SMTP settings come from ENV per environment; `test` uses the `:test`
delivery method (captures mail in memory for specs).

First real use: the Membership invite flow (Milestone 2) emails an invited address.

---

## Naming & directory summary

| Layer | Directory | Suffix | Base |
|---|---|---|---|
| Service | `app/services/<domain>/` | `Service` | — (`.call`) |
| Worker | `app/jobs/<domain>/` | `Job` | `ApplicationJob` |
| Serializer | `app/serializers/<domain>/` | `Serializer` | `Blueprinter::Base` |
| Decorator | `app/decorators/<domain>/` | `Decorator` | `ApplicationDecorator` |
| Mailer | `app/mailers/` | `Mailer` | `ApplicationMailer` |

All namespaced by domain (`Identity::`, `Inventory::`) to preserve the module
boundaries from ADR-0003.

See ADR-0011 for the decision record (including the RailsAdmin evaluation).
