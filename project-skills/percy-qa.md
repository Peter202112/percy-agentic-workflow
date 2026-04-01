---
name: percy-qa
description: Run the full QA verification pipeline with comprehensive test reports. Produces detailed test plans, test suites, and descriptive test cases with full context.
user-invocable: true
---

# Percy QA Agent

Autonomous QA verification pipeline triggered at the end of a development flow. Runs staged verification, diagnoses and fixes failures, and produces **comprehensive, descriptive test reports** with full test plans, suites, and cases.

## When to Use

- After completing a feature implementation across percy-api and percy-web
- Before creating a PR to validate the feature end-to-end
- When the user says "run QA", "verify the feature", "test everything", or "run the test pipeline"

## Prerequisites

Before running, the agent must know:
1. **Feature name** — from the current branch or user input
2. **PRD/user story** — from memory or ask the user
3. **What files were changed** — from `git diff --name-only` in both repos

## Execution Stages

Track progress with TaskCreate/TaskUpdate.

### Stage 1: Environment Setup

1. Check Docker: `docker ps 2>&1 | head -3`
2. If not running, start Colima: `colima start --cpu 4 --memory 8 --disk 60`
3. Start percy-api containers: `cd percy-api && docker-compose up -d db sidekiq-redis api`
4. Wait for containers: `sleep 15 && docker ps --format '{{.Names}} {{.Status}}' | grep percy`
5. Run migrations: `docker exec percy-api-api-1 bash -c "cd /app/src && bundle exec rake db:migrate RAILS_ENV=test"`
6. Record pass/fail

### Stage 2: API Service Tests

1. Find all new/modified spec files: `find percy-api/spec -name "*_spec.rb" -newer percy-api/app -type f`
2. Run each spec file:
   ```bash
   docker exec percy-api-api-1 bash -c "cd /app/src && bundle exec rspec SPEC_FILE --format documentation"
   ```
3. If a spec fails, read the error, diagnose, fix the source code, and re-run
4. Record examples count, failures count, and full output for each file

### Stage 3: API Request Tests

1. Find request specs: `find percy-api/spec/requests -name "*_spec.rb" -newer percy-api/app -type f`
2. Run each: `docker exec percy-api-api-1 bash -c "cd /app/src && bundle exec rspec SPEC_FILE --format documentation"`
3. Diagnose and fix any failures (common: Pundit policy errors, validation mismatches, missing auth)
4. Record results

### Stage 4: Frontend Build Verification

1. Kill port 4200: `lsof -ti:4200 | xargs kill 2>/dev/null`
2. Start with Mirage: `cd percy-web && source ~/.nvm/nvm.sh && nvm use && PERCY_DEV_MIRAGE=yes yarn start` (background, timeout 600s)
3. Wait ~100s, check output for "Build successful"
4. Check for compilation errors in output
5. Record pass/fail

### Stage 5: ESLint Verification

1. Run ESLint on all new/modified JS files:
   ```bash
   cd percy-web && source ~/.nvm/nvm.sh && nvm use
   npx eslint --fix [all new/modified JS files]
   ```
2. Record errors vs warnings (warnings acceptable, errors must be 0)

### Stage 6: Generate Test Report

Generate two files in `reviews/`:
1. `testresults.md` — Markdown test results
2. `testresults.html` — Styled HTML report

---

## Test Report Structure (MANDATORY)

Every report MUST include ALL of the following sections. Do not abbreviate or skip any section.

### 1. Header

```markdown
# Test Results: [Feature Name]
**Feature:** [Full feature name from PRD]
**User Story:** [The original user story]
**Date:** [Execution date]
**Branch:** [Branch name in both repos]
**Execution:** [Autonomous / Manual / Mixed]
```

### 2. Test Plan

The test plan provides the strategic context. It must answer "why are we testing this, what are we testing, and how."

```markdown
## Test Plan

### Feature Background
[2-3 paragraphs explaining the feature, what problem it solves, who it's for,
and how it works at a high level. Reference the PRD.]

### Testing Objective
[What we are trying to prove. E.g., "Verify that the recurring diff detection
algorithm correctly identifies coordinate-overlapping diffs across builds and
that the suggestion lifecycle (create → display → accept/dismiss) works
end-to-end."]

### Success Criteria
- [Specific, measurable criteria. E.g., "All IoU edge cases return correct values"]
- [E.g., "API endpoints return correct HTTP status codes with proper JSONAPI"]
- [E.g., "Frontend compiles without errors and renders the banner component"]

### Test Strategy
| Layer | Approach | Tools | What It Proves |
|-------|----------|-------|----------------|
| Unit (API) | RSpec service specs | RSpec, FactoryBot | Algorithm correctness, service logic |
| Integration (API) | RSpec request specs | RSpec, JSONAPI | HTTP layer, auth, serialization |
| Build (Web) | Ember CLI build | Ember, Webpack | No compilation errors, imports resolve |
| Lint (Web) | ESLint + Prettier | eslint | Code quality, formatting |
| Regression (Web) | Ember QUnit suite | QUnit, Mirage | No existing tests broken |

### Scope
| In Scope | Out of Scope | Rationale |
|----------|-------------|-----------|
| [Item] | [Item] | [Why excluded] |

### Environment Requirements
- Docker (Colima) with percy-api containers
- MySQL 8.0 test database
- Node 14.18.3 (via nvm) for percy-web
- No external services needed — all mocked/stubbed

### Entry Criteria
- [E.g., "All feature files committed to branch"]
- [E.g., "Docker containers healthy"]

### Exit Criteria
- [E.g., "All API specs pass (0 failures)"]
- [E.g., "Frontend builds with 0 compilation errors"]

### Risk Assessment
| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| [E.g., "GCS mock doesn't match real data shape"] | Medium | High | [Stub based on actual DiffRegion.fetch_by output] |
```

### 3. Test Suite

List every test file with its purpose and coverage mapping.

```markdown
## Test Suite

| Suite ID | File Path | Layer | Purpose | PRD Requirement Covered | # Cases |
|----------|-----------|-------|---------|------------------------|---------|
| TS-001 | `spec/services/percy/...` | API Unit | [Specific purpose] | [Which PRD must-have] | N |
```

### 4. Test Cases (DETAILED)

This is the most important section. Each test case must be fully self-contained — someone reading just this case should understand what it tests, why, and how.

**MANDATORY fields for every test case:**

```markdown
## Test Cases

### TS-001: [Suite Name]

#### TC-001: [Human-readable title]

| Field | Value |
|-------|-------|
| **TC-ID** | TC-001 |
| **Title** | [Descriptive title — what is being tested] |
| **Objective** | [WHY this test exists — what risk it mitigates or what behavior it proves] |
| **PRD Requirement** | [Which specific must-have from the PRD this validates] |
| **Preconditions** | [What must be true before this test runs — factories, DB state, mocks] |
| **Test Steps** | 1. [Specific action with exact values] |
|                | 2. [Next action] |
|                | 3. [Assert/verify step] |
| **Test Data** | [Exact inputs: coordinates, IDs, parameters used] |
| **Expected Result** | [Precise, measurable — exact return value, HTTP status, DB state change] |
| **Actual Result** | [What actually happened during the test run] |
| **Status** | PASS / FAIL |
| **Notes** | [Edge cases, observations, why this value was chosen, relationship to other tests] |
```

**DO NOT use abbreviated test cases like:**
- "IoU: identical rects → PASS" (too brief)
- "Returns suggestions → PASS" (no context)

**DO use descriptive cases like:**
- Full objective explaining why the test matters
- Exact test data with computed values
- Notes explaining edge cases and thresholds

### 5. Stage Results

```markdown
## Stage Results

| Stage | Description | Status | Duration | Details |
|-------|-------------|--------|----------|---------|
| 1 | Environment Setup | PASS/FAIL | Xs | [What happened] |
```

### 6. Bugs Found & Fixed

```markdown
## Bugs Found & Fixed

### Bug 1: [Title]
- **Symptom:** [What went wrong — error message or unexpected behavior]
- **Root Cause:** [Why it happened — code path trace]
- **Fix Applied:** [What was changed]
- **File:** [Exact file path and line if applicable]
- **Verification:** [How we confirmed the fix works]
```

### 7. Acceptance Criteria Coverage

Map every PRD acceptance criterion to its test coverage.

```markdown
## Acceptance Criteria Coverage

| AC-ID | Criteria (from PRD) | Tested By | Test Case IDs | Status |
|-------|---------------------|-----------|---------------|--------|
| AC-01 | [Exact text from PRD] | [How tested] | TC-001, TC-005 | COVERED |
```

### 8. Re-Run Commands

```markdown
## Re-Run Commands

[Full commands to reproduce the entire verification from scratch]
```

---

## Error Recovery

- **Docker won't start:** `colima stop --force && colima start`
- **Migration fails:** `bundle exec rake db:migrate:status`
- **Spec fails:** Read full error, check source, fix, re-run
- **Build fails:** Check compilation error, fix JS/HBS, rebuild
- **Port 4200 in use:** `lsof -ti:4200 | xargs kill`

## Stage 7: Cleanup (with approval)

After all test stages pass and the report is generated, perform graceful shutdown.

**IMPORTANT:** Do not tear down containers without asking — the user may want to keep them running for manual debugging or further exploration.

### Cleanup gate:

Present and explicitly warn about restart cost:
> "QA pipeline complete. The following resources are still running:
> - Docker containers: `percy-api-api-1`, `percy-api-db-1`, `percy-api-sidekiq-redis-1`, etc.
> - Dev server: `https://localhost:4200` (port 4200)
> - Browser session: agent-browser (if used)
>
> **Note:** Spinning up Docker containers again takes 2-5 minutes (Colima VM boot + container startup + DB readiness checks). If you plan to run more tests, debug, or iterate on the feature, I recommend keeping Docker running.
>
> Options:
> 1. **Shut down all** — stop Docker, kill port 4200, close browser (will need full restart later)
> 2. **Keep Docker running** — only kill dev server and browser (recommended if you might test again)
> 3. **Keep everything running** — I'll clean up manually later"

**DEFAULT:** If the user doesn't explicitly choose an option, **keep everything running**. Only shut down on explicit approval. Never auto-shutdown.

### Shutdown procedure (when approved):

```bash
# 1. Close browser session (if open)
agent-browser close 2>/dev/null

# 2. Kill percy-web dev server
lsof -ti:4200 | xargs kill 2>/dev/null

# 3. Graceful Docker shutdown (preserves data volumes)
cd percy-api && docker-compose down

# 4. Verify all stopped
docker ps --format '{{.Names}}' | grep percy || echo "All percy containers stopped"
lsof -ti:4200 2>/dev/null && echo "WARNING: port 4200 still in use" || echo "Port 4200 free"
```

**Order matters:** Browser first (lightweight), then dev server (Node process), then Docker containers (heaviest, may have DB writes to flush).

**DO NOT run:** `docker-compose down -v` (destroys volumes/data) or `colima stop` (kills ALL Docker, not just percy) unless the user explicitly asks.

### Post-cleanup:

1. Verify cleanup succeeded — report any lingering processes
2. Save report files to `reviews/`
3. Present final summary to user with pass/fail verdict
4. Suggest committing test files if not already committed
