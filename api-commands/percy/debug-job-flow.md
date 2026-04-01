---
name: debug-job-flow
description: Trace a Sidekiq job from trigger through queue routing to completion. Maps Redis instance, related jobs in the chain, lock contention, and retry behavior. Use when debugging job execution issues or understanding job flow.
argument-hint: "[job class name, e.g., Percy::BuildFinishingJob]"
context: fork
allowed-tools: Read, Glob, Grep, Bash
---

You are a Sidekiq job flow debugger for the Percy API codebase. Given $ARGUMENTS (a job class name like `Percy::BuildFinishingJob`), trace the full job lifecycle from trigger to completion and report on routing, chaining, locks, and retry behavior.

## Step 1: Find and Read the Job File

Parse $ARGUMENTS to identify the job class name. Search `app/jobs/percy/` for the matching job file. Read it and extract:

- Base class: `ApplicationJob`, `SidekiqJob`, or other
- `sidekiq_options`: queue name, pool, retry count, dead flag, backtrace
- `TransactionAwareJob` inclusion (delays enqueue until after DB commit)
- Any `unique_` or deduplication options

## Step 2: Determine Redis Instance

Map the job's queue/pool to a Redis instance:

- **Primary** (`SIDEKIQ_REDIS_URL` / `REDIS_CONNECTION_POOL`): All queues except deletion and low_priority
- **Secondary** (`SIDEKIQ_SECONDARY_REDIS_URL` / `REDIS_SECONDARY_CONNECTION_POOL`): `deletion`, `low_priority` queues
- **Hub** (`hub_redis_url` / `Percy::Hub::REDIS_CONNECTION_POOL`): Hub communication queues

Check `sidekiq_options` for explicit `pool:` setting. If none, the queue name determines the Redis instance.

## Step 3: Find All Triggers (Callers)

Search the entire codebase for anything that enqueues this job:

- `JobClassName.perform_async`
- `JobClassName.perform_later`
- `JobClassName.perform_in`
- `JobClassName.perform_at`
- `JobClassName.set(`.`).perform_later`

For each caller, note:
- File and line number
- What context triggers the enqueue (controller action, another job, service object, callback)
- Any arguments passed

## Step 4: Find Downstream Jobs

Within the job file itself, search for any jobs it enqueues:

- `*.perform_async`
- `*.perform_later`
- `*.perform_in`
- `*.perform_at`

Map the chain of downstream jobs.

## Step 5: Check Lock Usage

Look for distributed locking patterns within the job:

- `Percy::DistributedLock`
- `with_lock` blocks
- `Redis` lock primitives
- Database-level advisory locks
- `Redlock` usage

Note: lock key pattern, TTL, what happens on lock failure (retry? skip? raise?)

## Step 6: Check Error Handling and Retry Behavior

Analyze:

- `rescue` blocks within `perform` — what exceptions are caught?
- Are exceptions re-raised or swallowed? (swallowed = silent failure)
- `sidekiq_options retry:` value (default is 25)
- `sidekiq_retry_in` method override
- `sidekiq_retries_exhausted` callback
- Dead letter queue behavior (`dead: false` means discarded after retries)

## Step 7: Check for Cross-Pool Enqueue Issues

If this job enqueues other jobs, verify pool compatibility:

- A secondary-pool job enqueuing to primary must use `Sidekiq::Client.via(::REDIS_CONNECTION_POOL)`
- A primary-pool job enqueuing to secondary must use the secondary pool
- `ValidateRedisPool` middleware will catch mismatches in production

## Step 8: Generate Report

```
## Job Flow Analysis: [JobClassName]

### Job Configuration
- File:        [path]
- Base Class:  [ApplicationJob / SidekiqJob]
- Queue:       [queue name]
- Redis Pool:  [Primary / Secondary / Hub]
- Retry:       [count or false]
- Dead:        [true/false]
- Transaction-Aware: [yes/no]

### Trigger Points
| # | File                  | Context              | Arguments Passed       |
|---|-----------------------|----------------------|------------------------|
| 1 | [file:line]           | [description]        | [args]                 |

### Downstream Jobs
| # | Job Class             | Condition            | Redis Pool             |
|---|-----------------------|----------------------|------------------------|
| 1 | [class]               | [when enqueued]      | [pool]                 |

### Job Chain Diagram
[trigger] → [this job] → [downstream job 1] → ...
                       → [downstream job 2]

### Lock Analysis
- Uses distributed lock: [yes/no]
- Lock key pattern:      [pattern or N/A]
- Lock TTL:              [duration or N/A]
- On lock failure:       [behavior]

### Error Handling
- Rescued exceptions:    [list]
- Swallowed exceptions:  [list or none]
- Retry exhausted:       [behavior]

### Potential Issues
[List any concerns: cross-pool enqueue without via(), swallowed exceptions,
 missing locks for non-idempotent operations, AR objects passed as arguments, etc.]
```
