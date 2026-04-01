---
name: redis-review
description: Validate Redis instance usage, key TTLs, connection pooling, and lock safety.
agent: percy-performance-reviewer
argument-hint: "[optional: file path to check]"
---

Review changed code for Redis misuse, distributed lock issues, and connection pool safety. $ARGUMENTS
