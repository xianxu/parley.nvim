---
id: 000260
status: open
deps: []
github_issue:
created: 2026-09-15
updated: 2026-09-15
estimate_hours:
---

# Expire transient diagnostic status messages

## Problem

The Parley status row can retain a diagnostic/error message indefinitely. In the
observed session it displayed `COUCH_MOUSE_TRACE: diagnostic generation changed
outside protocol` long after the event, even though the operator expected a
transient message to disappear after roughly 10 seconds. A stale warning makes
the status row look continuously unhealthy and obscures newer state.

## Spec

Classify status-row diagnostics by lifetime. Messages that report a transient
observation or recoverable protocol anomaly should expire automatically after a
bounded interval (about 10 seconds, subject to the existing status refresh
cadence). Persistent failures that require operator action must remain visible
or use an explicit persistent-error surface. A later message should replace an
older one, and an expired message must not erase newer state. Keep the lifetime
and replacement behavior in the shared status/message controller rather than
adding per-caller timers.

## Done when

- The diagnostic shown in the report disappears automatically after the agreed
  transient lifetime when no newer status supersedes it.
- New status updates replace stale transient messages without being cleared by
  an old timer.
- Persistent actionable errors remain visible through their deliberate path.
- Tests cover expiration, replacement/race ordering, redraws, and the no-message
  state after expiry.
- Atlas or user-facing help documents which status messages are transient and
  which persist.

## Plan

- [ ] Trace the status-row producer and message controller for the diagnostic in
  the screenshot; identify whether it is already intended to be transient.
- [ ] Define the transient/persistent lifetime contract and implement one shared
  expiry/replacement mechanism.
- [ ] Add deterministic timer-injected tests for expiry and stale-timer races.
- [ ] Verify the live status row and update the relevant atlas documentation.

## Log

### 2026-09-15

Filed from operator screenshot. `COUCH_MOUSE_TRACE: diagnostic generation changed
outside protocol` remained in the status row indefinitely; the expected behavior
was for this kind of transient error to disappear after about 10 seconds.
