---
name: job-safety
description: Validate Sidekiq job safety including idempotency, argument serialization, error handling, and queue routing.
agent: percy-job-reviewer
argument-hint: "[optional: file path to specific job]"
---

Review changed Sidekiq jobs for idempotency, argument safety, error handling, queue routing, and Redis pool correctness. $ARGUMENTS
