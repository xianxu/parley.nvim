---
id: 000321
status: open
deps: [pair#530]
github_issue:
created: 2026-10-13
updated: 2026-10-13
estimate_hours:
card_mirror: '2d944a66dc1810c44651d4cc1f79698233affd40' # card fields mirrored from issue-cards; edit via sdlc
---

# session-sync: ping once after 15 minutes without a write while deliveries remain owed (pair#530 companion)

## Problem

The session-sync watcher in lua/parley/session_sync.lua pings from the age of
the oldest owed delivery (default five minutes), ignoring a recent session-file
write. The operator requested a simple baseline: no write for fifteen minutes
while deliveries remain owed, then one ping. pair#530 discovered that this
consumer lives in Parley; adding another watcher in Couch would duplicate it.

## Spec

- Change the existing probe, not the watcher count. Default to fifteen minutes
  since the latest observed file write while Owed is nonempty. A write postpones
  the ping even if it folds none of the old deliveries.
- Consume pair#530's planned FileWriteAt status observation together with
  LastWrite; use the latest valid timestamp. An older Couch lacking FileWriteAt
  uses LastWrite plus the already-observed buffer file mtime. Missing/invalid
  status is unknown, never evidence that the file is stale.
- One ping per write generation in the existing buffer lifetime. More deliveries
  do not rearm it. Preserve live/quiet-owner admission and operator-lock behavior;
  do not create a second timer, offline queue, retry or redelivery mechanism.
- Retain an explicit configured threshold override; change the default and docs
  to fifteen minutes. The stale visual-band threshold is separate and unchanged.
- Pair owns feature sampling/logging and stuck-slot/restart prompts. This issue
  owns only the existing Parley ping consumer and its tests. Confirm the final
  producer contract after pair#530 lands before coding.

## Done when

- Fake-clock/integration tests prove no ping before fifteen minutes, one at the
  boundary while owed, a recent write resets the clock despite older owed rows,
  more deliveries do not repeat the ping, and no ping with no obligations,
  unknown status, active/unavailable owner, or operator lock.
- Legacy status fallback and a configured threshold remain covered; documented
  defaults match the consumer. Run the repository's required suite before close.

## Plan

- [ ] Read pair#530's landed observation contract and plan this companion.
- [ ] Update the existing ping computation, defaults, tests and docs.
- [ ] Verify both halves together; report the baseline outcome to the hub.

## Log

### 2026-10-13

- Filed unclaimed from pair:7 at TL request. Dependencies are sequencing, not a
  request to start on an unlanded branch. No Parley implementation was changed.
