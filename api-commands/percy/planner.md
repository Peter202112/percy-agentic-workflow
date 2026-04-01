---
name: planner
description: Plan safe implementation of migrations, API endpoints, or Sidekiq jobs. Reads relevant config files and produces an actionable checklist. Use before writing new migrations, endpoints, or background jobs.
argument-hint: "[migration|endpoint|job] description of what you plan to build"
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash(git *), Bash(ls *)
---

# Percy Pre-Code Planner

Plan safe implementation of a migration, API endpoint, or Sidekiq job for the Percy API Rails project. Parse the argument to determine the type, gather dynamic context, and produce an actionable checklist.

## Arguments

Parse `$ARGUMENTS` to determine the plan type. The first word should be one of: `migration`, `endpoint`, or `job`. The remainder is the description.

Examples:
- `migration add index to builds on branch`
- `endpoint POST /api/v1/projects/:id/archive`
- `job nightly stale build cleanup`

If the type is ambiguous, ask the user to clarify before proceeding.

---

## Dynamic Context (always gather)

Inject these for all plan types:

Recent migrations:
!`ls db/migrate/ | tail -5`

Sidekiq queue configuration:
!`cat config/sidekiq.yml 2>/dev/null`

Current routes summary:
!`cat config/routes.rb 2>/dev/null | head -80`

---

## MIGRATION Planning

When the type is `migration`, follow these steps.

### Step 1: Read the current schema

Read `db/schema.rb` to understand the target table structure, existing indexes, and column types.

### Step 2: Check restricted tables

The following tables are restricted by the `Custom/MigrationTableRestrictions` RuboCop cop. Direct schema changes to these tables require ghost migrations:

```
RESTRICTED_TABLES:
- snapshots
- comparisons
- builds
- screenshots
- snapshot_resources
- master_snapshots
- resource_manifests
- resources
- images
- base_build_strategies
- subscriptions
```

If the target table is in this list, flag it and require ghost migration format.

### Step 3: Determine migration strategy

Search for existing ghost migration examples:

- Use Grep to find `return if Rails.env.production?` in `db/migrate/` to see ghost migration patterns.
- Use Grep to find `gh-ost` references in the codebase for orchestration patterns.

**Ghost migration rules:**
- The Rails migration must contain `return if Rails.env.production?` at the top of `up` and `down`.
- The actual schema change runs via gh-ost in production, not through Rails.
- Ghost migrations are required for any DDL on restricted tables.

**Standard migration rules:**
- Keep migrations reversible when possible.
- Set `lock_wait_timeout` for any ALTER TABLE on large tables (MySQL 8.0 default can cause long locks).
- Avoid `change_column` on high-traffic tables without a ghost migration.

### Step 4: Produce checklist

Output a checklist with these items:

- [ ] Table name and whether it is restricted
- [ ] Migration type: standard or ghost
- [ ] If ghost: `return if Rails.env.production?` guard present
- [ ] If adding index: `algorithm: :concurrently` considered (if on large table)
- [ ] If adding column: default value strategy (backfill separately for large tables)
- [ ] If renaming/removing column: deprecation period needed
- [ ] Lock wait timeout consideration for MySQL 8.0
- [ ] Reversibility: `up`/`down` or `change`
- [ ] Migration filename follows Rails timestamp convention
- [ ] Run `make migrate` to apply and regenerate `db/schema.rb`
- [ ] Run `make t` on relevant model specs after migration

---

## ENDPOINT Planning

When the type is `endpoint`, follow these steps.

### Step 1: Determine the API namespace

Parse the endpoint path to determine which namespace it belongs to:

- `/api/v1/*` — Public API. Uses Percy token or BrowserStack auth. Requires Pundit authorization.
- `/api/browserstack/*` — BrowserStack integration. Uses service token auth. Requires Pundit + service token.
- `/api/internal/*` — Internal service endpoints. Uses basic auth. No Pundit needed.

### Step 2: Read routes and identify placement

Read `config/routes.rb` to find the correct namespace block and determine:

- The resource nesting (e.g., `resources :projects do resources :builds end`)
- Whether the route already exists or is new
- Which controller base class to inherit from

### Step 3: List all files to create or modify

For a new endpoint, you typically need:

1. **Controller** — `app/controllers/api/v1/<resource>_controller.rb` (thin, 5-7 lines per action)
2. **Service object** — `app/services/percy/<action>_<resource>.rb` (business logic)
3. **Policy** — `app/policies/<resource>_policy.rb` (Pundit authorization, V1/BrowserStack only)
4. **Serializer** — `app/serializers/<resource>_serializer.rb` (JSONAPI format)
5. **Contract** — `app/contracts/<resource>_contract.rb` (dry-validation for complex inputs)
6. **Route** — `config/routes.rb` entry
7. **Request spec** — `spec/requests/api/v1/<resource>_spec.rb` with `openapi:` metadata
8. **Service spec** — `spec/services/percy/<action>_<resource>_spec.rb`
9. **Policy spec** — `spec/policies/<resource>_policy_spec.rb`
10. **Factory updates** — `spec/factories.rb` if new model

### Step 4: Check for existing workflow documentation

Search for endpoint workflow documentation:

- Use Grep to find references to `rails_api_endpoint_modification_workflow` in `prompts/`.
- Read `prompts/rails_api_endpoint_modification_workflow.md` if it exists for the canonical 10-step workflow.

### Step 5: Determine authentication and authorization

Based on the namespace:

**V1 endpoints:**
- Security schemes: `percyTokenAuth`, `browserstackAuth`, `percyOrganizationTokenAuth`, `superAdminTokenAuth`
- Every non-index action must call `authorize @resource`
- Index actions must use `policy_scope(Resource)`
- `skip_authorization` requires a compensating control (documented reason)

**Internal endpoints:**
- Security scheme: `internalBasicAuth`
- Basic auth enforced at controller level, no Pundit needed
- Must not skip basic auth

**BrowserStack endpoints:**
- Security scheme: `browserstackServiceTokenAuth`
- Requires both Pundit authorization and service token validation
- Namespace enforcement at routing level

### Step 6: Determine OpenAPI security metadata

The request spec must include the correct security scheme(s):

```ruby
# Available schemes:
# percyTokenAuth, browserstackAuth, percyOrganizationTokenAuth,
# superAdminTokenAuth, internalBasicAuth, browserstackServiceTokenAuth,
# bitbucketJWTAuth
```

### Step 7: Produce checklist

- [ ] API namespace identified (v1 / browserstack / internal)
- [ ] Route added to correct namespace block in `config/routes.rb`
- [ ] Controller inherits from correct base class
- [ ] Controller actions are thin (5-7 lines, delegate to service)
- [ ] Service object created with `perform`, `call`, or `execute` public method
- [ ] Pundit policy created/updated (if V1 or BrowserStack)
- [ ] `authorize` called in every non-index action (if V1 or BrowserStack)
- [ ] `policy_scope` used in index action (if V1 or BrowserStack)
- [ ] Serializer created using `jsonapi-serializers` gem
- [ ] Contract created for complex input validation (dry-validation)
- [ ] Strong params defined for simple inputs
- [ ] Request spec includes `openapi:` metadata with correct security schemes
- [ ] Request spec covers happy path, auth failure, validation failure, not found
- [ ] Service spec covers business logic and edge cases
- [ ] Policy spec covers all roles and permissions
- [ ] Run `make rubocop` on new files
- [ ] Run `make t` on new specs
- [ ] Run `make openapi` to regenerate OpenAPI docs

---

## JOB Planning

When the type is `job`, follow these steps.

### Step 1: Determine the job base class

Percy uses two job base classes:

- **ApplicationJob** — Standard ActiveJob wrapper. Uses `perform` as the entry method.
- **SidekiqJob** — Direct Sidekiq worker. Uses `work` as the entry method (NOT `perform`).

Search for examples of each:

- Use Grep to find `< ApplicationJob` in `app/jobs/` for ActiveJob examples.
- Use Grep to find `< SidekiqJob` or `include Sidekiq::Job` in `app/jobs/` for Sidekiq examples.

### Step 2: Determine the queue

Read `config/sidekiq.yml` (injected above) to understand queue configuration.

Three Redis instances serve different purposes:

- **Primary Redis** — Default queues, high-priority work (comparisons, builds, webhooks)
- **Secondary Redis** — Deletion queues, low-priority work (`deletion`, `low_priority`)
- **Hub Redis** — Hub-specific processing

Match the job's purpose to the correct Redis instance and queue:

- Deletion work → secondary Redis, `deletion` queue
- Low-priority background work → secondary Redis, `low_priority` queue
- Standard processing → primary Redis, appropriate named queue
- Hub operations → hub Redis

### Step 3: Design for idempotency

All Sidekiq jobs must be idempotent. Verify:

- Can the job be safely retried without side effects?
- Does it use distributed locking if needed? (Redis-based with database fallback)
- Does it handle race conditions (e.g., record deleted between enqueue and execution)?
- Does it use `find_by` instead of `find` to avoid `RecordNotFound` on retry?

### Step 4: Check deletion pipeline patterns

If the job involves deletion, review the 8-step deletion pipeline:

- Use Grep to find `delete_by` in `app/jobs/` and `app/services/` for deletion patterns.
- Deletion uses `delete_by` not `destroy` (skips callbacks intentionally for performance).
- The pipeline has 8 sequential steps; understand where the new job fits.

### Step 5: Check feature flag patterns

If the job should be gated behind a feature flag, review the 5 wrapper types:

- `Percy::FeatureFlags` — Global flags
- `Percy::UserFeatureFlags` — User-scoped flags
- `Percy::OrganizationFeatureFlags` — Organization-scoped flags
- `Percy::ProjectFeatureFlags` — Project-scoped flags
- `Percy::FeatureFlagService` — Service-level flag evaluation

Search for examples:

- Use Grep to find `FeatureFlags` in `app/jobs/` for flag usage patterns in jobs.

### Step 6: Produce checklist

- [ ] Base class chosen: `ApplicationJob` (uses `perform`) or `SidekiqJob` (uses `work`)
- [ ] Queue identified and mapped to correct Redis instance (primary / secondary / hub)
- [ ] Queue declared in `config/sidekiq.yml` if new
- [ ] Job is idempotent (safe to retry)
- [ ] Distributed locking used if concurrent execution is dangerous
- [ ] Error handling: specific exception classes, not broad rescue
- [ ] `find_by` used instead of `find` to handle missing records gracefully
- [ ] If deletion: uses `delete_by` not `destroy`, fits into deletion pipeline
- [ ] If feature-flagged: correct flag wrapper chosen for scope
- [ ] Job file created at `app/jobs/percy/<job_name>.rb`
- [ ] Job spec created at `spec/jobs/percy/<job_name>_spec.rb`
- [ ] Job spec tests idempotency (run twice, same result)
- [ ] Job spec tests error scenarios (missing record, lock contention)
- [ ] Run `make rubocop` on new files
- [ ] Run `make t` on new specs

---

## Output Format

Present the checklist with:

1. A summary of what is being planned (one sentence).
2. The type-specific checklist from above.
3. Any warnings about restricted tables, auth gaps, or queue mismatches.
4. Suggested file paths for all files to create or modify.

Do NOT generate code. This is an advisory plan only.
