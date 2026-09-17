---
id: 000264
status: open
deps: []
github_issue:
created: 2026-09-16
updated: 2026-09-16
estimate_hours:
---

# Semantic folds flicker open on a local blank-line edit

## Problem

Operator report: while composing a question, the previous exchange's `📝:`
summary — two lines above the cursor — briefly expands and then re-collapses.
It is distracting during ordinary editing. The reported edit was removing blank
lines (not all of them) from the run between the summary and the `💬:` question
starter. Desired behavior: the summary stays folded.

Measured: the flicker is not local. On a 242-row transcript carrying 40 summary
folds, deleting **one** blank line near the end opens **all 40** folds at once
for 12 scheduler turns, then re-closes them. The settled state is always
correct; only the intermediate is wrong.

The operator's instinct ("nothing would materially change") is right at the
document level. A blank row is, however, a real grammar token — it terminates a
non-explicit reasoning block (`highlight_structure.lua:81`,
`answer_structure.lua:81`) — so the model cannot cheaply prove the edit is
inert. That justifies re-deriving; it does not justify repainting the buffer.

## Spec

Two compounding defects, both required for the symptom.

**(a) Over-invalidation — the uncertain span is the whole document.**
`document/structure.lua:109` reports `frontier → EOF`:

```lua
local first,last=frontier(current),sequence.size(current.index).rows
if first<last then return {first=first,last=last} end
```

For a blank-line edit adjacent to a summary the frontier retreats to row 0, so
every measured case reports `uncertain={0,N}` regardless of edit position. The
dependency lookahead origin should be local to the affected block.

**(b) The native clear is eager and unconditional.**
`tool_folds.lua:426` is the first thing `M.step` does:

```lua
if clear_uncertainty(s) then return 'more' end
```

It returns `'more'`, so `clear_folds_in_span` runs in its own event-loop turn,
before any replacement projection exists. The folds are therefore *observably*
open across the repair window. Even a correctly narrow span would flicker; a
whole-document span repaints everything on screen.

Open/closed state is already preserved across the cycle via
`s.opened[win][handle]`, which is why the settled result is correct. The fix is
to stop rendering the intermediate, not to rebuild the state.

Direction: defer the native clear until the replacement projection is ready and
restrict it to fold groups whose topology actually changed, so an unchanged
group is never touched. `atlas/chat/document.md` already states this intent for
the join path ("a deferred ordinary join can avoid native fold work when
unchanged topology is confirmed before invalidation runs"); the uncertainty path
is not wired to it.

Constraint to defend in the design: the eager clear exists so a stale fold is
not displayed at a wrong position during repair — the `#193` / `#200` failure
mode. Deferring trades a briefly-stale-but-stable fold for no flicker. The plan
must state why that trade is safe here and which invariant replaces the one the
eager clear was providing (ARCH-PURPOSE: fix the class — every foldable kind,
not just `summary`).

Scope note: `summary` is one of four foldable kinds (`fold_projection.lua:18`:
thinking / summary / tool_use / tool_result). The defect is kind-independent;
the fix and its tests must cover the class.

## Done when

- A local blank-line edit near a foldable block leaves every unaffected fold
  closed for the entire repair window — no observable open/close cycle.
- `uncertain_range` (or the fold consumer's use of it) no longer reports a
  whole-document span for an edit whose affected origin is local.
- A regression test asserts fold closure is continuous across repair, not merely
  correct once settled — the settled-state oracle already passes today and did
  not catch this.
- Coverage spans all four foldable kinds and the blank-count matrix
  (n blanks present, m deleted, m < n and m == n).
- No regression in `#193` (fold at wrong place), `#194` (preserve folds during
  inline comment submission), `#195` (reconcile semantic folds exactly),
  `#200` (user question is folded).

## Plan

- [ ] Design pending — run `sdlc start-plan` and author the durable plan via
      `superpowers-writing-plans` before implementing.

## Log

### 2026-09-16

Reproduced headlessly against the real `document` + `tool_folds` modules.

Blank-count matrix, summary at row 5, `💬:` starter immediately after the blank
run. Every combination reproduces; leaving blanks behind does not help:

```
blanks=1 delete=1 leaves=0 | uncertain={0,7}   OPENED=true  steps=7
blanks=2 delete=1 leaves=1 | uncertain={0,8}   OPENED=true  steps=7
blanks=3 delete=1 leaves=2 | uncertain={0,9}   OPENED=true  steps=7
blanks=4 delete=1 leaves=3 | uncertain={0,10}  OPENED=true  steps=7
blanks=4 delete=3 leaves=1 | uncertain={0,8}   OPENED=true  steps=7
```

Scale, 242 rows / 40 summary folds, deleting one blank near the end:

```
uncertain_range = {0,241}
MAX summary folds simultaneously OPEN during repair: 40/40
settled after 12 steps; final closed: 40
```

Negative controls — these do **not** flicker (`uncertain=nil`, 1 step), which is
why the symptom reads as "the summary two lines above":

- typing a character into an existing question line
- pressing Enter inside a question
- appending a line, or a new `💬:` marker, at EOF
- deleting the blank line directly *above* the question starter
- editing a body line above the summary

Repro scripts: `scratchpad/repro3.lua` (shapes), `repro4.lua` (scale),
`repro5.lua` (blank matrix). To be promoted into
`tests/integration/` next to `document_fold_uncertainty_retirement_spec.lua`,
which covers only the 50k-row suspended path and does not assert continuity.
