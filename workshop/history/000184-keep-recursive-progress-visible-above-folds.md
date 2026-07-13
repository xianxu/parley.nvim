---
id: 000184
status: done
deps: []
github_issue:
created: 2026-07-13
updated: 2026-07-13
estimate_hours: 1.50
started: 2026-07-13T14:51:27-07:00
actual_hours: 2.03
---

# Keep recursive progress visible above folds

## Problem

After a client-side tool round, Parley starts the next LLM leg with its progress
extmark anchored to the last line of the final tool-result block. Tool results
are immediately closed into manual folds. Neovim does not render a virtual line
whose anchor is hidden inside a closed fold, so recursive generation can remain
visibly idle even though the pending session and spinner are active. The #183
regression asserts the extmark's semantic end row but does not assert that the
row is outside the closed fold, and therefore codifies the invisible placement.

## Spec

- Keep fresh-response placement unchanged: before content exists, progress is
  anchored to the agent header.
- For every recursive LLM leg, insert the stream placeholder first and anchor
  pending progress to its stable preceding separator row. That row is the
  visual append boundary after the completed answer/tool/result sequence, is
  excluded from every Parley-generated tool fold, and is not replaced by
  streaming.
- Do not derive placement from the current window's `foldclosed()` state or
  move/open folds. Folds are window-local while the pending extmark is
  buffer-owned; the separator must remain outside Parley's generated tool folds
  regardless of which of those folds a window has open (`ARCH-PURPOSE`). User-
  created manual folds outside Parley's tool-fold contract are out of scope.
- Once content arrives, retain #183's existing writer-owned relocation: move
  progress synchronously to the last written row after every chunk, preserving
  the same extmark ID, temporal reducer state, and repair authorization.
- Keep local tool execution spinner-free and preserve the one-second reveal,
  one-second minimum visibility, staging, failure ordering, Definition spinner,
  leases, and fold behavior unchanged.
- Reuse the exchange model's canonical stream-block position to derive the
  separator instead of adding a parallel scan of buffer lines or block kinds
  (`ARCH-DRY`). Keep the temporal reducer pure; this is a spatial decision in
  the existing `chat_respond` IO shell (`ARCH-PURE`).

## Done when

- A production-entry regression drives two consecutive recursive tool rounds
  (assistant tool call → local result → recursive LLM call, repeated), closes
  both rounds' tool-use/result folds, and then proves the third LLM leg has no
  decoration before the one-second reveal and visible progress afterward at a
  row for which `foldclosed(row + 1) == -1`.
- The recursive progress row is the stable separator immediately before the
  stream placeholder and visually follows the final folded tool result.
- Content received while the third leg's playful spinner is visible remains
  staged for the one-second minimum; the spinner stays at the fold-visible
  separator until it is hidden, then accumulated text flushes in order.
- After a folded recursive leg has released to normal streaming, meaningful
  semantic status appears at the written tip and a later chunk relocates that
  same status extmark ID to the new writer-reported tip.
- Through a folded recursive leg, cancellation removes the decoration, timers,
  pending ownership, and lease while discarding staged output; provider failure
  removes the decoration and releases staged partial output before surfacing
  the error. Neither terminal opens or moves Parley tool folds.
- Fresh responses, local-tool silence, fold compaction, staging, and external-
  invalidation behavior retain their existing coverage.
- Mapped response-progress tests, lint, and the full repository suite pass.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec       design=0.50 impl=0.08
item: lua-neovim       design=0.20 impl=0.28
item: atlas-docs       design=0.05 impl=0.04
item: milestone-review design=0.10 impl=0.12
design-buffer: 0.13
total: 1.50
```

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md`
against `baseline-v3.1.md`. Method A only. The established #182/#183 pending
adapter and tool-loop fixtures supply the library/pattern shortcut; v3.1's 40%
implementation calibration is already reflected in each `impl=` value.

## Plan

- [x] Approve the regression design and calibrated estimate.
- [x] Add a failing real-path folded recursive-progress regression.
- [x] Derive the recursive anchor from the stable pre-stream separator.
- [x] Update the response-progress atlas and pass targeted/full verification.
- [ ] Close, publish, and merge through the SDLC gates.

## Log

### 2026-07-13
- 2026-07-13: closed — Two-round recursive tool-loop regressions prove the delayed spinner is outside all closed tool folds; staged output obeys its minimum and now has an exact one-occurrence oracle before provider error, semantic status follows the stream tip, and cancellation cleans timers/ownership/lease. Mapped specs, lint, and serialized full suite pass. Re-closing performs the required post-review-fix audit; the sole unchecked row is this active publish gate.; review verdict: SHIP
- 2026-07-13: closed — Two-round recursive tool-loop regressions prove the delayed spinner is outside all closed tool folds, staged output obeys its minimum and flushes before provider error, semantic status follows the stream tip, and cancellation cleans timers/ownership/lease; mapped specs, lint, and serialized full suite pass. The sole unchecked row is this active close/publish/merge gate.; review verdict: FIX-THEN-SHIP

Traced the missing UI through the production tool loop. `process_response`
appends the final `tool_result`, schedules `tool_folds.apply_folds`, and then
schedules recursive `respond`; #183 initializes progress at
`last_nonempty_block_end`, which lies inside the closed result fold. The chosen
design anchors to the canonical separator before the new stream placeholder,
avoiding window-local fold queries and preserving the existing stream-tip
relocation contract.

The 1.50-hour v3.1 estimate and single-chunk durable implementation plan passed
fresh-context review after its placement, provider-failure ordering, and timer
cleanup oracles were made directly executable.

The SDLC plan-quality gate then required terminal tests to snapshot all four
tool-use/result folds across both rounds and to explicitly create staged partial
content before invoking provider failure. The durable plan now pins both.

Pre-implementation reducer review found that the earlier same-ID requirement
contradicted #182's minimum-visible staging: a visible playful mark is hidden
before staged content is written. The spec now requires that playful mark to
remain at the separator through the minimum and tests same-ID relocation on
semantic status after release, where the writer actually runs.

The production-entry regression reproduced the bug after two consecutive tool
rounds: at the one-second reveal, `foldclosed(spinner_row + 1)` returned the
final result fold's start instead of `-1`. Anchoring the recursive session to
the insertion row shared with the stream placeholder made that regression
GREEN while preserving the existing writer-owned relocation. The same fixture
proves all four tool folds remain closed through staged completion,
cancellation, and provider failure; partial output is flushed before the error
notification and every terminal closes its timers, pending owner, and lease.

Verification passed: `chat_respond_spec.lua` 48/48, mapped
`chat/exchange_model`, lint across 265 files with zero warnings/errors, and the
serialized full repository suite. Scoped diff checking is clean; the checkout
continues to preserve the operator's unrelated pre-existing #162 edit.

The first boundary review returned `FIX-THEN-SHIP` with one Important test-
oracle finding: post-minimum output was checked for presence but not exact
cardinality. The regression now counts the final staged answer and requires one
occurrence, directly proving the plan's exactly-once release contract.

## Revisions

### 2026-07-13 — fresh spec review

Scoped the fold guarantee to Parley-generated tool folds, made the screenshot's
multi-call reproduction explicit as two consecutive recursive rounds followed
by a waiting third LLM leg, pinned silent/reveal/minimum timing and same-ID
stream relocation, and required cancellation plus provider-failure cleanup to
run through the folded-recursive separator path.

### 2026-07-13 — estimate vocabulary correction

Renamed the unchanged review primitive from `boundary-review` to the canonical
`milestone-review` vocabulary required by the estimate-reconciliation gate.

### 2026-07-13 — temporal-contract correction

Separated the playful-minimum case from semantic-status movement. Visible
playful progress remains at the separator while content stages, then hides
before the flush; same-ID relocation applies to semantic status during released
streaming, matching the pure reducer's established actions.
