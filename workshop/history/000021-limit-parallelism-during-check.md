---
id: 000021
status: done
deps: []
created: 2026-03-29
updated: 2026-03-29
---

# limit parallelism during check-*

I think we need to limit parallelism, not in current uncontrolled fashion.

## Done when

- [x] `run_all_parallel()` respects a concurrency limit instead of spawning all checks at once

## Plan

- [x] Add job-slot semaphore to `run_all_parallel()` in `scripts/parallel-checks.sh`
- [x] Make limit configurable via `MAX_PARALLEL_CHECKS` env var (default: 2)

## Log

### 2026-03-29

Added concurrency limiter to `run_all_parallel()` in `scripts/parallel-checks.sh`. Uses a simple PID-tracking loop: before spawning a new check, waits for a slot to free up if at the limit. Default is 2 concurrent checks, configurable via `MAX_PARALLEL_CHECKS`.

