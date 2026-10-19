---
id: 000400
status: open
deps: []
github_issue:
created: 2026-10-19
updated: 2026-10-19
estimate_hours:
severity: low
collaboration-mode: collaboration
card_mirror: 'b7ac64de7fbf5003388770ef2435dc910c396a40' # card fields mirrored from issue-cards; edit via sdlc
---

# couch.run: session-sync status/actors queries and sends have no deadline

## Problem

Some `parley.couch.run` callers give the child no deadline. `session_sync.probe` runs `couch --session-sync status --json` and `couch --actors --json` through `couch.query` with no `timeout`, and `couch.send` has none either. If `couch` hangs (a wedged supervisor, a blocked socket), the child and its two stdio pipes stay open for as long as it hangs. The probe's `s.probing` flag also stays set, so probing stops for that buffer. `document_registry` (deadline per operation, #382) and `attention` (`PROBE_TIMEOUT_MS`) already bound theirs. Found during #399 (no leak was measured on this path; this is the unbounded-lifetime gap, not the #399 root cause).

## Spec

## Done when

- Every `couch.run` caller passes a bounded deadline, or `couch.run` applies a default one, and the callback still fires once on expiry.
- A probe whose couch call times out clears `s.probing`, so the next poll probes again; a spec with a fake couch that sleeps past the deadline shows it.

## Plan

- [ ]

## Log

### 2026-10-19
