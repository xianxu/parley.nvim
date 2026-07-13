---
id: 000184
status: working
deps: []
github_issue:
created: 2026-07-13
updated: 2026-07-13
estimate_hours:
started: 2026-07-13T14:51:27-07:00
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
  excluded from tool folds, and is not replaced by streaming.
- Do not derive placement from the current window's `foldclosed()` state or
  move/open folds. Folds are window-local while the pending extmark is
  buffer-owned; the separator must remain a valid visible anchor in every
  window regardless of which folds are open (`ARCH-PURPOSE`).
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

- A real recursive response containing multiple client-side tool calls closes
  its tool folds and then shows delayed progress at a row for which
  `foldclosed(row + 1) == -1`.
- The recursive progress row is the stable separator immediately before the
  stream placeholder and visually follows the final folded tool result.
- The first streamed chunk still relocates progress to the written generation
  tip without changing presentation lifecycle state.
- Fresh responses, local-tool silence, fold compaction, cancellation, staging,
  and external-invalidation behavior retain their existing coverage.
- Mapped response-progress tests, lint, and the full repository suite pass.

## Plan

- [ ] Approve the regression design and calibrated estimate.
- [ ] Add a failing real-path folded recursive-progress regression.
- [ ] Derive the recursive anchor from the stable pre-stream separator.
- [ ] Update the response-progress atlas and pass targeted/full verification.
- [ ] Close, publish, and merge through the SDLC gates.

## Log

### 2026-07-13

Traced the missing UI through the production tool loop. `process_response`
appends the final `tool_result`, schedules `tool_folds.apply_folds`, and then
schedules recursive `respond`; #183 initializes progress at
`last_nonempty_block_end`, which lies inside the closed result fold. The chosen
design anchors to the canonical separator before the new stream placeholder,
avoiding window-local fold queries and preserving the existing stream-tip
relocation contract.
