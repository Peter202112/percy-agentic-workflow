---
name: percy-pr-validate
description: Comprehensive PR validation. Runs all applicable Percy review agents based on changed files.
context: fork
allowed-tools: Read, Glob, Grep, Bash
---

# Percy PR Validator

Run all applicable Percy review agents against the current branch diff.

## Step 1: Identify changed files

!`git diff --name-only $(git merge-base master HEAD)...HEAD`
!`git diff --stat $(git merge-base master HEAD)...HEAD`

## Step 2: Determine which agents to invoke

Based on the changed files above, run these checks:

- **If `app/controllers/` or `app/policies/` or `config/routes.rb` changed**: Apply all rules from the percy-endpoint-reviewer agent (read `.claude/agents/percy-endpoint-reviewer.md` and follow its instructions)
- **If `db/migrate/` or `db/schema.rb` changed**: Apply all rules from the percy-migration-reviewer agent (read `.claude/agents/percy-migration-reviewer.md`)
- **If `app/jobs/` changed**: Apply all rules from the percy-job-reviewer agent (read `.claude/agents/percy-job-reviewer.md`)
- **If `spec/` changed**: Apply all rules from the percy-spec-reviewer agent (read `.claude/agents/percy-spec-reviewer.md`)
- **Always**: Apply all rules from the percy-security-reviewer agent (read `.claude/agents/percy-security-reviewer.md`)
- **Always**: Apply all rules from the percy-code-quality-reviewer agent (read `.claude/agents/percy-code-quality-reviewer.md`)
- **Always**: Apply all rules from the percy-lint-reviewer agent (read `.claude/agents/percy-lint-reviewer.md`) — run RuboCop on all changed Ruby/ERB files and report violations
- **If `app/models/` or `db/migrate/` changed**: Apply GDPR rules from the percy-data-compliance-reviewer agent (read `.claude/agents/percy-data-compliance-reviewer.md`)
- **If any Ruby file references FeatureFlag**: Apply feature flag rules from the percy-data-compliance-reviewer agent
- **If queries, Redis, or caching code changed**: Apply rules from the percy-performance-reviewer agent (read `.claude/agents/percy-performance-reviewer.md`)

## Step 3: Consolidate report

Produce a single consolidated report:

### PR Validation Report

**Branch**: (branch name)
**Files changed**: N
**Agents invoked**: (list)

#### Findings by Severity

| # | Rule ID | Severity | File:Line | Description | Agent |
|---|---------|----------|-----------|-------------|-------|

#### Summary
- HIGH: N findings
- MEDIUM: N findings
- LOW: N findings
- Total: N

If no findings: "All checks passed."
