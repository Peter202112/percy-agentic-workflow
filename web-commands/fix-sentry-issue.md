---
name: fix-sentry-issue
description: Investigate and fix a Sentry error with root cause analysis — no suppression, no defensive null checks
argument-hint: "[Sentry issue URL or description of the error]"
---

# Fix Sentry Issue

You are fixing a Sentry error in the Percy web codebase (Ember.js 3.28, Glimmer components, Ember Data with JSON:API).

Your input: $ARGUMENTS

---

## CRITICAL RULE: No Suppression Fixes

**NEVER** apply any of these as the primary fix:
- Optional chaining (`?.`) to skip over null
- Nullish coalescing (`?? defaultValue`) to hide missing data
- Early returns (`if (!x) return`) to bail out silently
- `try/catch` wrapping to swallow errors
- Template guards (`{{#if value}}`) on values that should always exist
- `{{or value "fallback"}}` in templates to mask missing data

These are suppression patterns. They hide the bug from Sentry but leave users with broken/incomplete UI. The goal is to fix WHY the value is null, not to tolerate it.

---

## Phase 1: Understand the Error

### Step 1: Gather Sentry Context

If a Sentry URL was provided, use the Sentry MCP tools to:
1. Fetch the issue details — get the full stack trace, affected file, and line number
2. Check the event breadcrumbs — what user actions led to the crash?
3. Check event count and regression window (`first_seen` → `last_seen`)
4. Check affected browser/OS/release tags
5. Look at the issue's tag values to understand patterns (specific orgs, builds, projects?)

If no Sentry URL was provided, search for the error using `mcp__sentry__list_issues` with the description.

### Step 2: Read the Crashing Code

Read the exact file and line from the stack trace. Understand:
- What value is null/undefined?
- What was the code expecting to find there?
- Is this a model attribute, a relationship, a computed value, or a service?

### Step 3: Check Git History for Regression

```bash
git log --after="<first_seen date>" --before="<last_seen date>" --oneline -- <affected file>
```

Look at recent commits that touched the crashing file or its data source.

---

## Phase 2: Root Cause Analysis

Work through this decision tree **before writing any code**. Determine which category the bug falls into:

### Category 1: Missing `include:` Parameter (Most Common)

**Symptoms:** `Cannot read properties of null (reading 'x')` where `x` is a relationship field.

**Investigation:**
1. Identify the model and relationship from the stack trace
2. Find which query loads this model — check:
   - `app/services/build-query.js`
   - `app/services/snapshot-query.js` (look at `SNAPSHOT_COMPARISON_INCLUDES`)
   - Route `model()` hooks in `app/routes/`
   - Any `this.store.query()` or `this.store.loadRecord()` calls
3. Check if the relationship is listed in the `include:` parameter
4. Check the model definition in `app/models/` — is the relationship `{async: false}`? If sync and not included, it WILL be null.

**Fix location:** Add the missing relationship to the `include:` string/array in the service or route that loads the data. Then update Mirage handlers and factories to match.

### Category 2: Race Condition / Timing

**Symptoms:** Error happens intermittently. Component accesses data before a fetch completes. Stack trace shows access during initial render.

**Investigation:**
1. Check if the component accesses `this.args.model.relationship` without a loading guard
2. Check if the route's `model()` hook returns a promise that may not resolve before `setupController`
3. Check if a service fetch (`ember-concurrency` task) is still in-flight when the component renders
4. Look for `@tracked` state that starts as `undefined` and is only set after an async operation

**Fix location:** Add proper loading state management:
- Use `ember-concurrency` task with `.isRunning` check in the template
- Add `@tracked isLoaded = false` pattern if the component owns the fetch
- Ensure the route's `model()` hook properly awaits all required data
- Do NOT just add `?.` — that hides the race condition and shows blank UI

### Category 3: Stale Cache / Invalid Store State

**Symptoms:** Error happens after navigation or after a model update. The store has a record but a relationship that should exist is missing.

**Investigation:**
1. Check if the record was loaded via a different query path that didn't include the relationship
2. Check if polling (`app/services/resource-refresh.js`) reloads the model without the needed includes
3. Check if a route transition pushes a partial record into the store, overwriting a complete one

**Fix location:** Ensure all query paths for the model include the required relationships. If the polling service reloads the model, update it to include the missing relationship.

### Category 4: Missing Default Value in Model

**Symptoms:** `@attr` field is `undefined` when accessed. The API sometimes omits the field.

**Investigation:**
1. Check the model definition in `app/models/`
2. Check the API response — does it always include this field?
3. Check the serializer in `app/serializers/` — is there field mapping that could drop the value?

**Fix location:** Add `defaultValue` to the `@attr` declaration:
```js
@attr('boolean', {defaultValue: false}) isApproved;
@attr('number', {defaultValue: 0}) screenshotCount;
```

### Category 5: Legitimately Optional Value

**Symptoms:** The API documentation says the field is optional. The business logic genuinely branches on presence.

**Investigation:**
1. Confirm with API docs or backend code that the field is truly optional
2. Check if there's a design spec for the "no data" state

**Fix location:** This is the ONLY category where null checks are the correct fix. When applying:
- Add a code comment explaining WHY it's optional
- Handle the null case explicitly in the template with a meaningful empty state, not just hiding the section
- Update the model declaration to reflect optionality

### Category 6: Component Lifecycle / Destroyed Component

**Symptoms:** `Calling set on destroyed object` or accessing properties after `willDestroy`.

**Investigation:**
1. Check if an async operation (fetch, setTimeout, ember-concurrency task) resolves after the component is torn down
2. Check if a service callback fires after route transition

**Fix location:**
- Use `ember-concurrency` tasks (they auto-cancel on destroy)
- Check `this.isDestroying || this.isDestroyed` before setting tracked properties in async callbacks
- Use `registerDestructor` for cleanup

### Category 7: Serializer / Adapter Mismatch

**Symptoms:** Data arrives from the API but relationships or attributes are not populated on the model.

**Investigation:**
1. Check the API response shape in Sentry breadcrumbs (network requests)
2. Compare with what the serializer in `app/serializers/` expects
3. Check if `keyForAttribute`, `keyForRelationship`, or `normalize` methods are transforming data incorrectly

**Fix location:** Fix the serializer to correctly map the API response to the model.

---

## Phase 3: Write a Failing Test FIRST

Before touching any `app/` source code, write a test that reproduces the crash.

### For Component Crashes (Integration Test)

```js
import {setupRenderingTest} from 'ember-qunit';
import {module, test} from 'qunit';
import {render} from '@ember/test-helpers';
import hbs from 'htmlbars-inline-precompile';
import {make} from 'ember-data-factory-guy';
import setupFactoryGuy from 'percy-web/tests/helpers/setup-factory-guy';

module('Integration: <ComponentName>', function (hooks) {
  setupRenderingTest(hooks);
  hooks.beforeEach(function () { setupFactoryGuy(this, hooks); });

  test('renders when <relationship> is not sideloaded', async function (assert) {
    const model = make('<model>'); // factory WITHOUT the relationship — reproduces the bug
    this.set('model', model);
    await render(hbs`<ComponentName @model={{this.model}}/>`);
    assert.dom('[data-test-<element>]').exists();
  });
});
```

### For Route/Data-Loading Crashes (Acceptance Test)

```js
import setupAcceptance, {setupSession} from '../helpers/setup-acceptance';
import {module, test} from 'qunit';
import {visit} from '@ember/test-helpers';

module('Acceptance: <Feature>', function () {
  module('when <condition that causes crash>', function (hooks) {
    setupAcceptance(hooks);
    setupSession(hooks, function (server) {
      this.organization = server.create('organization');
      // Create models WITHOUT the missing relationship
    });

    test('page renders without crashing', async function (assert) {
      await visit('/...');
      assert.dom('[data-test-page-root]').exists();
    });
  });
});
```

**Confirm the test FAILS before proceeding to the fix.**

---

## Phase 4: Apply the Fix

### Fix at the Source

Apply the minimal change at the earliest point in the data flow where the value should exist:

```
API response → Serializer → Adapter → Store → Model → Service → Component → Template
              ^--- fix here, not here ---^                                    ^--- not here
```

### Update Mirage Layer (if you changed `include:` params)

1. **Mirage route handler** (`mirage/config.js`): ensure the endpoint sideloads the new relationship
2. **Mirage factory** (`mirage/factories/<model>.js`): add `afterCreate` to associate the relationship
3. **Factory Guy factory** (`tests/factories/<model>.js`): update so `make('<model>')` includes the relationship by default, or add a trait

### Add a Code Comment at the Fix Site

```js
// Fix: <file>#L<line> was null because '<relationship>' was not in the include param.
// Sentry: <issue URL>
```

---

## Phase 5: Verify the Fix

Run in sequence:

1. Confirm the test that was failing now passes:
```bash
ember test --filter "<test name>"
```

2. Run lint:
```bash
yarn lint
```

3. Run the full test suite (or a broader subset):
```bash
yarn test
```

If tests fail, investigate — do NOT suppress test failures.

---

## Phase 6: Self-Review Checklist

Before declaring the fix complete, verify:

- [ ] **Root cause identified**: Can you explain in one sentence WHY the value was null?
- [ ] **No suppression patterns**: Search your diff for `?.`, `?? `, `if (!`, `try {` — if any exist, justify each one. Are they the fix or a band-aid?
- [ ] **Fix is at the source**: Did you fix the data provider (service/route/serializer/model), not the consumer (component/template)?
- [ ] **Test reproduces the original error**: Does the test fail without your fix and pass with it?
- [ ] **Mirage updated**: If you changed `include:` params, did you update Mirage handlers and factories?
- [ ] **No scope creep**: Did you only change what's necessary for this fix? No drive-by refactors.
- [ ] **Lint passes**: `yarn lint` exits clean
- [ ] **Tests pass**: `yarn test` exits clean

---

## Phase 7: QA Verification — Reproduce the Sentry Error in Browser

After the fix passes tests, verify it in a real browser by attempting to reproduce the original Sentry error.

### Step 1: Ask for App URL and Reproduction Context

Ask the user for:
- **App URL** — the running instance to test against (e.g., `http://localhost:4200`, staging URL, or review app URL)
- **Reproduction steps** — if known from Sentry breadcrumbs, or the user may provide specific steps
- **Test account/org** — if the error is specific to certain orgs or user states

If the user doesn't provide reproduction steps, derive them from the Sentry event breadcrumbs gathered in Phase 1.

### Step 2: Reproduce the Error (Before Fix)

Use Chrome DevTools MCP to attempt to trigger the original error:

1. **Navigate to the affected page:**
   Use `navigate_page` to visit the URL where the error occurs (from Sentry route/URL tags).

2. **Follow the breadcrumb trail:**
   Replay the user actions from Sentry breadcrumbs:
   - `click` on elements the user interacted with
   - `fill` form fields if the flow involves input
   - `navigate_page` for route transitions
   - `wait_for` elements that load asynchronously

3. **Check for console errors:**
   Use `list_console_messages` to capture any JavaScript errors.
   Look for the exact error message from Sentry.

4. **Take a screenshot:**
   Use `take_screenshot` to document the broken state (if visible).

5. **Check network requests:**
   Use `list_network_requests` to verify API responses — check if the expected `include` relationships are present in JSON:API responses.

### Step 3: Verify the Fix

After applying the fix to the running instance:

1. **Repeat the same reproduction steps** from Step 2
2. **Confirm the error is gone:**
   - `list_console_messages` — the original error should NOT appear
   - `take_screenshot` — the UI should render correctly with complete data
   - `list_network_requests` — verify the API response now includes the missing relationship/data
3. **Check for regressions:**
   - Navigate to related pages that use the same component/data
   - Verify no new console errors are introduced
   - Verify the UI looks correct (no blank sections, no missing data)

### Step 4: Document QA Results

Include QA findings in the PR description:

```
### QA Verification
- [ ] Reproduced original error before fix: <yes/no>
- [ ] Error no longer occurs after fix: <yes/no>
- [ ] No console errors on affected page: <yes/no>
- [ ] API response includes expected data: <yes/no>
- [ ] UI renders correctly with complete data: <yes/no>
- [ ] No regressions on related pages: <yes/no>
- **Screenshots:** <before/after if applicable>
```

### QA Troubleshooting

If you CANNOT reproduce the error:
- Check if the error requires specific data state (certain org, build, or project configuration)
- Check if the error is browser-specific (Sentry tags may show Safari-only, Firefox-only, etc.)
- Check if the error requires specific timing (race conditions may not reproduce reliably)
- Note in the PR: "Could not reproduce locally — fix is based on stack trace analysis. Monitor Sentry after deploy."

If the fix does NOT resolve the error:
- Go back to Phase 2 and re-examine the root cause
- The initial analysis may have been wrong — investigate deeper
- Do NOT proceed with a fix that doesn't actually resolve the issue

---

## Phase 8: Create PR

Create a branch, commit, push, and open a PR with `run_tests`, `ready_for_review`, and `sentry_claude` labels:

```bash
git checkout -b fix/sentry-<short-description>
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

**Sentry issue:** <link>
**Regression window:** <first_seen> to <last_seen>
**Events:** <count> | **Users affected:** <count>

### Root cause
<1-2 sentences explaining WHY this crashed. E.g.: "The `project` relationship was not included
in the `include:` param of `BuildQueryService.getBuildsForProject()`, so `build.project` was
always `null` when accessed in `BuildCard`.">

### Fix
<1-2 sentences on what changed and why it addresses the root cause.>

### What this does NOT do
Does not add optional chaining (`?.`) or nullish coalescing (`??`) at the crash site.
The fix ensures the value is always present when accessed.

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

---

## Anti-Patterns Reference

These are real patterns that have been seen in PRs. **Do NOT do any of these:**

### 1. The "just add ?." fix
```js
// BAD: Suppresses the error, user sees blank data
get projectName() {
  return this.args.build?.project?.name;
}
```

### 2. The "fallback string" fix
```js
// BAD: User sees "Unknown" instead of real data — that's a bug, not a fix
get projectName() {
  return this.args.build?.project?.name ?? 'Unknown';
}
```

### 3. The "early return" fix
```js
// BAD: Component silently renders nothing — user sees broken UI
get comparisonData() {
  if (!this.args.snapshot) return null;
  if (!this.args.snapshot.comparisons) return [];
  // ...
}
```

### 4. The "template guard on required data" fix
```handlebars
{{! BAD: Hides the section entirely when data is missing }}
{{#if @build.project}}
  <span>{{@build.project.name}}</span>
{{/if}}
```

### 5. The "try-catch swallow" fix
```js
// BAD: Error disappears from Sentry but bug still exists
get buildStatus() {
  try {
    return this.args.build.latestSnapshot.status;
  } catch {
    return 'unknown';
  }
}
```

### What to do instead
Trace the data flow upstream. Find where the value SHOULD have been loaded. Fix THAT. The component/template should not need to defend against missing data that the data layer is responsible for providing.
