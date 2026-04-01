---
name: percy-ci-monitor
description: Monitor Buildkite CI status for a PR, diagnose failures, read logs, and retry builds. Use when checking if CI passed, debugging failures, or confirming a PR is ready to merge.
context: fork
allowed-tools: Read, Bash, Grep, Glob, mcp__github__pull_request_read, mcp__buildkite__get_build, mcp__buildkite__list_builds, mcp__buildkite__read_logs, mcp__buildkite__tail_logs, mcp__buildkite__list_annotations, mcp__buildkite__search_logs, mcp__buildkite__create_build
---

# Percy CI Monitor

Monitor, diagnose, and manage Buildkite CI for Percy API pull requests.

## Constants

- **GitHub owner**: `percy`
- **GitHub repo**: `percy-api`
- **Buildkite org**: `percy`
- **Buildkite pipeline**: `percy-api`

## Step 1: Identify the PR and build

If a PR number is provided, use it directly. Otherwise detect from current branch:

!`git branch --show-current`
!`gh pr view --json number,headRefOid,title,statusCheckRollup --jq '{number, sha: .headRefOid, title, checks: [.statusCheckRollup[] | {name: .name, status: .status, conclusion: .conclusion}]}'`

Extract the **PR number**, **head SHA**, and **build number** from the Buildkite status URL.

## Step 2: Get combined CI status from GitHub

Use `mcp__github__pull_request_read` with `method: "get_status"` to get the combined commit status. This shows all Buildkite job statuses reported back to GitHub.

Present a summary table:

| Check | Status | Duration |
|-------|--------|----------|
| Pipeline Upload | passed/pending/failed | time |
| Style (RuboCop) | ... | ... |
| ... | ... | ... |

**Status meanings for Buildkite commit statuses:**
- `success` — job passed
- `pending` — job is running or queued
- `failure` — job failed
- `error` — infrastructure error

Also use `mcp__github__pull_request_read` with `method: "get_check_runs"` to get GitHub Actions checks (e.g., PR comment bot).

## Step 3: Get Buildkite build details

Extract the build number from the Buildkite status URL (e.g., `Build #29906` from the description field).

Use `mcp__buildkite__get_build` with `detail_level: "detailed"` to get the job summary.

**Key fields in the response:**
- `state`: overall build state (`running`, `passed`, `failed`, `canceled`)
- `job_summary.by_state`: count of jobs in each state
- `finished_at`: null if still running

**Buildkite job states explained:**
- `passed` — completed successfully
- `failed` — completed with non-zero exit code (real failure)
- `broken` — will not run because an upstream dependency failed. **This is NOT a real failure** — it means the job's prerequisite didn't pass. Common for deploy/publish steps when tests fail.
- `running` — currently executing
- `scheduled` — queued, waiting for an agent
- `waiting` — waiting for an upstream job to complete
- `canceled` — manually canceled
- `skipped` — conditionally skipped

## Step 4: If build is still running, report progress and offer to wait

If `state: "running"`, show current progress and ask:

"Build is running ([X] passed, [Y] running, [Z] scheduled). Want me to wait and check again in 2 minutes?"

If user says yes, wait and re-check. Otherwise, stop here.

## Step 5: If build failed, diagnose

### 5a: Get failed jobs

Use `mcp__buildkite__get_build` with `detail_level: "full"` and `job_state: "failed"` to get details of failed jobs including their `job_id`.

**Important:** Filter out `broken` state — those are downstream jobs blocked by the actual failure, not independent failures.

### 5b: Read failure logs

For each failed job, use `mcp__buildkite__tail_logs` with `tail: 50` to get the last 50 lines. This is the most token-efficient way to diagnose failures since errors appear at the end.

If more context is needed, use `mcp__buildkite__read_logs` with `seek` and `limit` to read specific sections.

If searching for a specific error, use `mcp__buildkite__search_logs` to find matching lines.

### 5c: Get build annotations

Use `mcp__buildkite__list_annotations` to get build-level annotations. These often contain:
- Test failure summaries
- Coverage reports
- RuboCop violation counts

### 5d: Compare with master

Use `mcp__buildkite__list_builds` with `branch: "master"` and `per_page: 3` to check if the same step also fails on master (pre-existing failure).

If the same step fails on master, report: "This failure also occurs on master — it's pre-existing, not caused by this PR."

### 5e: Classify the failure

Present findings as:

**Failure: [job name]** (exit code [N])
- **Root cause:** [extracted from logs]
- **Related to PR changes?** Yes/No — [reasoning]
- **Pre-existing on master?** Yes/No
- **Action needed:** [fix/retry/ignore]

## Step 6: Offer actions

Based on the diagnosis, offer appropriate actions:

1. **If all tests pass but a non-test step failed (coverage, publish, deploy):**
   → "Tests passed. The [step] failure is [infrastructure/pre-existing]. Want me to retry the build?"

2. **If tests failed:**
   → Show the specific test failures and suggest fixes

3. **If build passed:**
   → "CI is green. PR is ready for review/merge."

### Retry a build

If user requests a retry, use `mcp__buildkite__create_build`:
- `org_slug`: "percy"
- `pipeline_slug`: "percy-api"
- `commit`: the head SHA from Step 1
- `branch`: the branch name
- `message`: "Retry: [original commit message]"

## Step 7: Final summary

Present a clear final status:

```
## CI Status: [PR title] (#[number])

Build: https://buildkite.com/percy/percy-api/builds/[number]

| Step | Status | Duration |
|------|--------|----------|
| ... | ... | ... |

Overall: PASSED / FAILED ([reason])
Ready to merge: Yes / No ([blocker])
```

## Percy CI Pipeline Steps (Reference)

The Percy API Buildkite pipeline typically includes these steps:

| Step | Type | What it does |
|------|------|-------------|
| Pipeline Upload | setup | Loads pipeline YAML |
| Style (RuboCop) | lint | Code style checks |
| OpenAPI Coverage | test | Validates OpenAPI spec coverage |
| Cloudflare Workers Test | test | Tests cloudflare-worker/ code (Vitest) |
| API Tests (x4) | test | RSpec suite split across 4 parallel workers |
| API Test Coverage | post-test | Collates SimpleCov results from test workers |
| Security | audit | bundle-audit for CVEs |
| Memory Leaks | audit | bundle-leak check |
| Upload JUnit | reporting | Sends test results to BrowserStack |
| Annotations | reporting | Posts coverage summary to build |
| Publish | deploy | Builds and pushes Docker image |
| Migrate Database | deploy | Runs pending migrations |
| Deploy API | deploy | Deploys to production |

Deploy steps only run on the `master` branch. On PR branches, they appear as `broken` (blocked) — this is expected.
