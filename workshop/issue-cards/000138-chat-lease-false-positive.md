---
id: '000138'
status: done
started: 2026-06-25T15:33:57-07:00
created: 2026-06-25
updated: 2026-06-25
estimate_hours: 2
actual_hours: 2
---

# Chat-lease false-positives cancel valid chat requests

## Problem

Since #137 (chat lease), **valid chat requests are cancelled** with the warning
`chat transcript changed during pending request` and produce **no output**. It
reproduces on a plain prompt (e.g. "hello") to a cliproxyapi Claude agent with
web search disabled, and is **worse with web_search** (where it was near-100%).

The same root cause also surfaced earlier in the session as:
- `cliproxyapi response is empty: ""`, and
- upstream `cliproxyapi` 500s logged as `{"error":{"message":"context canceled"}}`
  (because cancelling the pending request kills parley's in-flight `curl`, so the
  proxy sees the client disconnect mid-stream).
