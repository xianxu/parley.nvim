---
id: 000351
status: open
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
card_mirror: '88c405083a83486388dd896440d70a25dabbccd9' # card fields mirrored from issue-cards; edit via sdlc
---

# Retry transient provider errors (429, 529/overloaded, 5xx) with bounded backoff

## Problem

parley has no retry for transient provider errors. A 429 (rate limit), 529 or
`overloaded_error` (Anthropic), or a 5xx ends the request at once as a
failure. Measured during #242's inventory (2026-10-16): the only restart in
`lua/parley/dispatcher.lua` is cliproxyapi's `adapter.recover_query`, which runs
once on `attempt == 0` and only for auth-class errors (`dispatcher.lua:810-844`).
No 429/overloaded path exists anywhere in `lua/`.

#242 tests HTTP errors as surfaced failures carrying the API's message. Retrying
them is a feature, and was split out here by TL decision.

## Spec

To be designed. Questions: which statuses and in-band errors are transient;
backoff and the `retry-after` header; the budget against the dispatcher's
recovery backstop (`recovery_timeout_ms`, 30 s); what the user sees while a
retry waits; and that a retry never duplicates partial output already written.

## Done when

- [ ] Transient provider errors are retried with bounded backoff, honoring `retry-after`, and the user sees that a retry is pending.
- [ ] #242's fake_provider drives it (`http_429_once`, `overloaded`), and a non-transient error is still not retried.

## Plan

- [ ]

## Log

### 2026-10-16
