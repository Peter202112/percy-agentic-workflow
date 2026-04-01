---
name: triage-sentry
description: Fetch top Sentry issues, fix them with root cause analysis, and open PRs with run_tests + ready_for_review + sentry_claude labels
argument-hint: "[number of issues to fix, default 1]"
---

# Triage and Fix Sentry Issues

You are a Sentry triage-and-fix agent for the Percy web frontend. Your job is to fetch the top unresolved Sentry issues, analyze root cause, apply a proper fix, and open a PR — all in one flow. No intermediate GitHub Issues.

**Number of issues to fix:** $ARGUMENTS (default: 1 if not specified)

---

## Step 1: Fetch Top Sentry Issues

Use the Sentry MCP tools with these parameters:
- **Organization:** `percy`
- **Project:** `prod-web`
- **Region URL:** `https://us.sentry.io`
- **Query:** `is:unresolved`
- **Sort:** `freq` (most frequent first)

Filter to issues that:
- Have more than 5 events
- Were last seen within the last 7 days
- Are NOT `<unknown>` title (these are typically noise)
- Culprit is in `percy-web` app code (not third-party/vendor)

## Step 2: Get Detailed Context for Each Issue

For each issue, use `get_sentry_resource` or `list_issue_events` to gather:

1. **Full stack trace** — the exact file, line, and function where it crashes
2. **Event breadcrumbs** — what user actions led to the crash
3. **Tag values** — check `get_issue_tag_values` for patterns (specific browsers, orgs, routes)
4. **Event count and user count** — severity signal
5. **First seen / last seen** — regression window
6. **Release tags** — which deploy introduced it

## Step 3: Check for Existing PRs

Before starting a fix, check if a PR already exists:

```bash
gh pr list --repo percy/percy-web --label sentry_claude --state open --search "<Sentry issue ID>"
```

If a PR already exists for this Sentry error, skip it and move to the next one.

## Step 4: Analyze Root Cause Category

Based on the stack trace and culprit, classify the issue:

| Category | Signal | Likely Fix Location |
|---|---|---|
| Missing `include:` param | `Cannot read properties of null` on a relationship | `app/services/*-query.js` or route `model()` hook |
| Race condition / timing | Intermittent, happens during render | Component loading state |
| Stale cache | After navigation or model update | Polling service or query path |
| Missing model default | `@attr` field is undefined | `app/models/*.js` |
| Component lifecycle | `set on destroyed object` | Async cleanup |
| Serializer mismatch | Data present in API but null on model | `app/serializers/*.js` |
| Legitimately optional | API docs say field is optional | Component null handling |

## Step 5: Fix the Issue

Now run the full `/fix-sentry-issue` workflow for this issue. This means:

### 5a: Create a fix branch

```bash
git checkout master
git pull origin master
git checkout -b fix/sentry-<short-description>
```

### 5b: Write a Failing Test FIRST

Before touching `app/` code, write a test that reproduces the crash:
- Component crash → integration test in `tests/integration/components/`
- Route crash → acceptance test in `tests/acceptance/`
- Use `ember-data-factory-guy` (`make()`) for test data
- Confirm the test **FAILS** before proceeding

### 5c: Apply the Fix at the Source

**CRITICAL — No Suppression Fixes:**
- NEVER add `?.`, `??`, `if (!x) return`, or `try/catch` as the primary fix
- NEVER add `{{#if}}` template guards on values that should always exist
- Fix at the earliest point in the data flow where the value should exist

Fix at the data source:
```
API query → Serializer → Model → Service → Component → Template
^--- fix here                                          ^--- NOT here
```

If you changed `include:` params, also update:
- Mirage handlers (`mirage/config.js`)
- Mirage factories (`mirage/factories/`)
- Factory Guy factories (`tests/factories/`)

Add a code comment at the fix site:
```js
// Sentry fix: <description>. See: <sentry-issue-url>
```

### 5d: Verify

```bash
yarn lint          # must pass
yarn test          # must pass
```

### 5e: QA Verification

Ask the user for the app URL (e.g., `http://localhost:4200` or staging URL).

Use Chrome DevTools MCP to:
1. Navigate to the affected page
2. Replay user actions from Sentry breadcrumbs
3. Check `list_console_messages` — original error should NOT appear
4. `take_screenshot` — UI should render correctly
5. Check `list_network_requests` — verify API includes expected data
6. Navigate to related pages to check for regressions

## Step 6: Create PR with Labels

Commit, push, and create a PR with `run_tests`, `ready_for_review`, and `sentry_claude` labels:

```bash
git add -A
git commit -m "fix: <description> [<SENTRY-ID>]"
git push -u origin fix/sentry-<short-description>
```

```bash
gh pr create --repo percy/percy-web \
  --title "fix: <short description> [<SENTRY-ID>]" \
  --label "run_tests" --label "ready_for_review" --label "sentry_claude" \
  --body "$(cat <<'PR_EOF'
## Sentry fix: <short description>

**Sentry issue:** <full Sentry URL>
**Error:** `<error message>`
**Culprit:** `<culprit from Sentry>`
**Events:** <count> | **Users affected:** <count>
**First seen:** <date> | **Last seen:** <date>

### Root cause

<1-2 sentences explaining WHY the value was null/undefined. E.g.: "The `project`
relationship was not included in the `include:` param of
`BuildQueryService.getBuildsForProject()`, so `build.project` was always `null`
when accessed in `BuildCard`.">

### Fix

<What changed and why it addresses the root cause>

### What this does NOT do

Does not add optional chaining (`?.`) or nullish coalescing (`??`) at the crash site.
The fix ensures the value is always present when accessed.

### Reproduction Steps (from Sentry breadcrumbs)

1. <step 1>
2. <step 2>
3. Error occurs at: <component/route>

### QA Verification

- [ ] Reproduced original error before fix
- [ ] Error no longer occurs after fix
- [ ] No console errors on affected page
- [ ] UI renders correctly with complete data
- [ ] No regressions on related pages

### Test plan

- [ ] Added test reproducing the original error (fails before fix, passes after)
- [ ] All existing tests pass (`yarn test`)
- [ ] Lint passes (`yarn lint`)
- [ ] Mirage factory/handler updated (if applicable)
PR_EOF
)"
```

## Step 7: Summary

After processing all issues, output a summary table:

| Sentry ID | Error | Events | Users | PR |
|---|---|---|---|---|
| PROD-WEB-XXX | <error> | <count> | <count> | #<pr number> |

Then remind the user:

```
PRs created with labels: run_tests, ready_for_review, sentry_claude
CI will run automatically. Review the PRs when tests pass.
```
