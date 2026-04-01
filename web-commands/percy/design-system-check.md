---
description: Quick design system token compliance check
allowed-tools: Read, Glob, Grep, Bash
---

# Percy Design System Check

Run a quick design system compliance check on templates and styles.

## Instructions

1. Determine the target files:
   - If the user provided a file path or glob, use that
   - Otherwise, check files changed on the current branch: `git diff --name-only master...HEAD -- 'app/components/**/*.hbs' 'app/templates/**/*.hbs' 'app/styles/**/*.css'`

2. Read and apply the rules from `.claude/agents/percy-design-system-reviewer.md`

3. Produce a findings report in the standard format
