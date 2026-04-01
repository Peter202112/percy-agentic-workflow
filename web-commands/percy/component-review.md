---
description: Quick component quality check against Percy Ember conventions
allowed-tools: Read, Glob, Grep, Bash
---

# Percy Component Review

Run a quick quality check on Ember components.

## Instructions

1. Determine the target files:
   - If the user provided a file path or glob, use that
   - Otherwise, check files changed on the current branch: `git diff --name-only master...HEAD -- 'app/components/**/*.js' 'app/components/**/*.hbs'`

2. Read and apply the rules from `.claude/agents/percy-component-reviewer.md`

3. Read and apply the rules from `.claude/agents/percy-template-reviewer.md` for any `.hbs` files

4. Produce a consolidated findings report in the standard format
