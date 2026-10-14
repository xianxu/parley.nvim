---
id: 000321
status: working
deps: [pair#530]
github_issue:
created: 2026-10-13
updated: 2026-10-13
estimate_hours:
card_mirror: 'e6c96170eb4d190fa5badb3cd93ca8ad47e62c83' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-13T22:34:38-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "85beaec0", done: "94474f5c"}
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

- [x] Read pair#530's landed observation contract and plan this companion.
- [x] Update the existing ping computation, defaults, tests and docs.
- [x] Verify both halves together; report the baseline outcome to the hub.

## Log

### 2026-10-13

- Filed unclaimed from pair:7 at TL request. Dependencies are sequencing, not a
  request to start on an unlanded branch. No Parley implementation was changed.

## Revisions

### 2026-10-13 — landed producer contract (TL ops:0)

pair#530 landed as PR #324, merge 0fe5cc59e6e26212f04eea8b4085389c18607057,
without FileWriteAt. Supersedes the FileWriteAt/mtime requirement above: use
LastWrite alone, falling back to the oldest Owed.At only when LastWrite is
absent. Invalid LastWrite remains unknown. One ping per LastWrite value;
without a write, remember the fallback generation so changing deliveries
cannot rearm it. The fifteen-minute default, override, band, and Done-when
admission requirements remain.

### Implementation plan

- Reuse the existing probe and couch seam (ARCH-DRY), keeping owed-band age
  separate from write-age ping admission (ARCH-PURE).
- Remember the last pinged write value (or one absent-write sentinel) for the
  buffer lifetime; actor queries recheck the operator lock before sending.
- Exercise default boundary, recent writes, delivery changes, fallback,
  overrides, invalid status and admission through the existing fake couch.
- Run targeted session-sync specs, then the full suite and SDLC close review.

### Architecture assessment

ARCH-PURPOSE: fulfill the revised producer contract. ARCH-MOCK: retain the
external fake-couch seam. ARCH-CONSTRAINTS: same minute probe, one in-flight
query per buffer. ARCH-SECURE: invalid status never proves stale work.
ARCH-ORDER: writes rearm; delivery changes do not; lock acquisition while
querying suppresses sending. ARCH-FUNERAL: state dies with the existing buffer,
no new timer, persistent artifact or queue.

### 2026-10-13 — implementation and regression evidence

- Existing probe now keys age and one-shot memory to LastWrite, with the revised
  absent-write fallback. Ping default is 15; the owed band and stale-edit band
  retain their existing clocks. Operator lock suppresses a ping.
- Initial targeted regression run: six expected failures; core fix: 54/54 pass.
  Controlled actor-query races passed; extending to a write during status
  exposed one failure. Capture mtime before both queries so either write race
  postpones sending. Full suite queued for final verification.
- SDLC dependency catch-up generated unrelated vocabulary drift before branch
  creation. Preserved separately in stash named "weave generated vocabulary
  during 321 start-plan"; excluded from this consumer change.

### 2026-10-13 — generated vocabulary prerequisite

The required vocabulary freshness check fails against the dependency version
refreshed by start-plan. Include the generated area/severity metadata from
ariadne#348 (no lifecycle or policy changes); applying the preserved generated
output makes `make check-vocabulary` pass. This supersedes its initial exclusion
above. The consumer design is unchanged.

### 2026-10-13 — architecture guard documentation

The full suite requires a Core concepts table even for a small issue with no
new public entities. Record the modified owners so the symbol guard has an
explicit selection; no implementation change.

### Initial owner map

| Entity | Status | Location | Responsibility |
| --- | --- | --- | --- |
| `session_sync` | modified | `lua/parley/session_sync.lua` | Existing probe owns write-age admission and one-shot memory. |
| `config` | modified | `lua/parley/config.lua` | Fifteen-minute default; explicit overrides remain supported. |

- First full suite: lint clean (723 files), unit and session-sync integration
  pass; only failure was the architecture guard's absent Core concepts table.
  Table added above; rerunning the complete suite against the final tree.

- Final `make test` passed: 427 spec files; lint 723 files with zero warnings
  and errors; no surviving test processes. Includes session-sync write-age,
  both async write/lock races, and the corrected architecture symbol guard.
  `make check-vocabulary` and branch `git diff --check` passed. Baseline result
  reported to ops:0; PR #232 awaits close review before landing.

### 2026-10-13 — close review round 1

REWORK BR-1 through BR-4: validate the shared RFC3339 parser across LastWrite,
Owed.At and LastActivity; extract pure ping-generation and quiet-owner decisions;
test both shipped default and runtime fallback; document ping configuration in
README and upstream area/severity card metadata in the tracker atlas.

## Core concepts

| Entity | Kind | Status | Location | Responsibility |
| --- | --- | --- | --- | --- |
| `session_sync` | INTEGRATION | modified | `lua/parley/session_sync.lua` | Existing watcher, query and send shell. |
| `config` | INTEGRATION | modified | `lua/parley/config.lua` | Configuration data, with existing environment-derived paths. |
| `parse_time` | PURE | modified | `lua/parley/session_sync.lua` | Strict calendar, clock, fraction and offset parsing. |
| `ping_generation` | PURE | new | `lua/parley/session_sync.lua` | Write-age and one-shot admission from supplied observations. |
| `owner_quiet` | PURE | new | `lua/parley/session_sync.lua` | Known-owner quiet-time threshold. |

## Review fix verification

- Round-1 fixes verified with 66 targeted tests passing. Invalid-date regressions
  failed before the shared-parser correction through all three timestamp inputs.
  Pure policy tests cover threshold, override, absent-write identity and liveness.
  Reverting only the shipped default to five minutes makes the new boundary
  coverage fail; restored it to fifteen before the final full-suite rerun.

- The architecture guard selects the named Core concepts section, ending at
  the next level-two heading; tables inside revision prose did not satisfy its
  new-symbol direction. Promoted the revised table to that canonical section.

- Final full run passed the architecture guard but exposed a fixture race:
  changing only LastWrite in the fake response while advancing time let an
  older in-flight status reply become due. Real writes also change the file;
  the recent-write fixture now performs that write, exercising the mtime guard.

- Final post-review `make test` passed: all 427 spec files, lint clean across
  723 files, no surviving test processes; includes 66 session-sync cases.
  Vocabulary freshness and branch whitespace checks passed. All BR-1–BR-4
  fixes are ready for the second close review.
