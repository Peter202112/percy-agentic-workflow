---
name: percy-pr-validate
description: Comprehensive PR validation for Percy Web. Runs all applicable Percy review agents based on changed files.
context: fork
allowed-tools: Read, Glob, Grep, Bash
---

# Percy Web PR Validator

Run all applicable Percy Web review agents against the current branch diff.

## Step 1: Identify changed files

!`git diff --name-only $(git merge-base master HEAD)...HEAD`
!`git diff --stat $(git merge-base master HEAD)...HEAD`

## Step 2: Determine which agents to invoke

Based on the changed files above, run these checks:

- **If `app/components/**/*.hbs` or `app/templates/**/*.hbs` changed**: Apply all rules from the percy-design-system-reviewer agent (read `.claude/agents/percy-design-system-reviewer.md` and follow its instructions)
- **If `app/components/**/*.hbs` or `app/templates/**/*.hbs` changed**: Apply all rules from the percy-template-reviewer agent (read `.claude/agents/percy-template-reviewer.md`)
- **If `app/components/**/*.hbs` or `app/templates/**/*.hbs` changed**: Apply all rules from the percy-accessibility-reviewer agent (read `.claude/agents/percy-accessibility-reviewer.md`)
- **If `app/components/**/*.js` or `app/helpers/**/*.js` or `app/services/**/*.js` changed**: Apply all rules from the percy-component-reviewer agent (read `.claude/agents/percy-component-reviewer.md`)
- **If `app/models/**/*.js` or `app/adapters/**/*.js` or `app/serializers/**/*.js` or `app/routes/**/*.js` changed**: Apply all rules from the percy-ember-data-reviewer agent (read `.claude/agents/percy-ember-data-reviewer.md`)

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
