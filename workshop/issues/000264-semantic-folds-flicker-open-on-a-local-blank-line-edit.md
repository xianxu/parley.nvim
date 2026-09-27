---
id: 000264
status: working
deps: []
github_issue:
created: 2026-09-16
updated: 2026-09-27
estimate_hours: 3.71
started: 2026-09-27T11:51:45-07:00
flow: {kind: full, provenance: inferred}
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

## Estimate

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against `baseline-v3.1.md`. Method A only.*
Design ×0.2 (thorough plan doc resolves the decisions), +15% buffer; impl at 40% of the v2
table; familiarity ×1.5 (heavily guarded fold/parser code, new to this session). The
calibration doc is flagged stale (#127), so treat as provisional.

```estimate
model: estimate-logic-v3.1
familiarity: 1.5
item: lua-neovim        design=0.4 impl=0.4
item: lua-neovim        design=0.4 impl=0.4
item: lua-neovim        design=0.4 impl=0.4
item: milestone-review  design=0.0 impl=0.14
item: milestone-review  design=0.0 impl=0.14
item: atlas-docs        design=0.03 impl=0.05
design-buffer: 0.15
total: 3.71
```

## Plan

Durable plan: `workshop/plans/000264-semantic-fold-flicker-plan.md`.

- [ ] M1 — reconcile in place: continuity spec (red), pure `fold_diff`, inventory plus a
      single reconcile phase in `apply`, uncertainty clears only edit-intersected folds.
- [ ] M2 — local restart: extent spec (red), and `after_fragment` falls back to a restart at
      the edit's answer header (not row 0) when a fragment's end state changes.

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

Minimal repro harness (run with
`nvim --clean --headless -u NONE -l <file>` from the repo root). The load-bearing
part is polling `foldclosed()` *between* `F.step` calls — the existing oracle in
`tests/integration/tool_folds_spec.lua` only checks the settled state, which is
why this was never caught:

```lua
vim.opt.rtp:append(vim.fn.getcwd())
local D=require('parley.document')
local F=require('parley.tool_folds')
local lines={'💬: first question','🤖: first answer','some body text here',
  'more body text','📝: a reasonably long summary line for the exchange','','','💬: ',''}
local SUM=5                       -- 1-indexed row of the 📝: line
local buf=vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(buf,0,-1,false,lines)
vim.wo.foldmethod='manual'; vim.wo.foldenable=true
local doc=D.attach(buf,{schedule=false})
assert(D.drain(doc,100000).status=='idle')
F.setup(buf); assert(F.flush(buf)=='idle')
assert(vim.fn.foldclosed(SUM)==SUM,'summary should start folded')
vim.api.nvim_buf_set_lines(buf,5,6,false,{})    -- delete ONE of the two blanks
print('uncertain='..vim.inspect(D.uncertain_range(doc)))
local opened=false
for _=1,300 do
  local status=F.step(buf)
  if vim.fn.foldclosed(SUM)==-1 then opened=true end   -- continuity assertion
  if status=='idle' then break end
  if status=='pending' then D.drain(doc,100000) end
end
print('OPENED DURING REPAIR: '..tostring(opened))      -- true today; must be false
vim.cmd('qa!')
```

To be promoted into `tests/integration/` next to
`document_fold_uncertainty_retirement_spec.lua`, which covers only the 50k-row
suspended path and asserts nothing about continuity.

### 2026-09-19 — operator re-report, and the bounded-extent constraint it adds

Reported again, unprompted, and generalized past the blank-line trigger: *"folded
text (tool call, summary) sometimes expand temporarily when following text
change."* Same defect — both named kinds are in the four this issue already
scopes, and "following text change" is the same edit-below-the-fold shape as the
original report.

The operator's mechanism hypothesis: *"unsure how boundary's decided but this
seems pointing to undesired greedy matching algorithm that look beyond
necessary. For summary, which is always a single line, or worst can terminate at
next `💬:` start, this is not needed. Not sure about tool call, as there's code
fence involved. But with a proper state machine (not regex), we should be able
to do non-greedy look ahead."*

Checked against the code: there is **no regex scan** to make non-greedy. The
boundary is an incremental parser with a confirmed frontier
(`document/semantic.lua:205`, `confirmed_frontier`) over channel-partitioned
dependencies (`document/dependencies.lua`), and `uncertain_range`
(`document/structure.lua:111`) reports `frontier → EOF`. So the "looking beyond
necessary" is real, but it is **confirmation being retracted**, not a match
overrunning: the frontier retreats to row 0, and everything after it is
unconfirmed by definition. That is defect (a) above.

What the hypothesis *does* add, and what the design should carry, is a
**bounded-extent argument per foldable kind** — the reason the retraction is
provably unnecessary, stated in the grammar's own terms rather than as a
heuristic:

- **`summary`** — one line, terminating at worst at the next `💬:`. Nothing
  below a summary can change where it ends, so an edit below it can never
  invalidate it. If the frontier retreats past a summary, the retreat is
  provably over-conservative.
- **`tool_use` / `tool_result`** — bounded by a fence, so the extent is not
  single-line, but it is still closed by a token the grammar already
  recognizes (`lua/parley/fence.lua`). A fenced block's end is decidable from
  inside the block; it does not depend on what follows the close fence.
- **`thinking`** — the one kind with a genuine downstream dependency: a
  non-explicit reasoning block is terminated by a blank row
  (`highlight_structure.lua:81`, `answer_structure.lua:81`), which is exactly
  why the original blank-line edit could not be proven inert.

So three of the four foldable kinds have an extent that is closed from above and
cannot be lengthened by an edit below them. That asymmetry is the lever for
making the uncertain origin local (Spec (a)), and it also says the fix is not
uniform across kinds: `thinking` needs the deferred-clear half (Spec (b)) to stay
still, while the other three should not be invalidated at all.

Still ARCH-PURPOSE: fix the class. But "local to the affected block" now has a
per-kind proof obligation attached, and the tests should assert the negative —
an edit below a `summary` / fenced tool block leaves its confirmation intact —
not merely that the flicker stopped.

## Revisions

### 2026-09-27 — Scope extended to the streaming append path (from #281)

Reason: #281's headless repro shows the same clear-before-create flicker on
ordinary streaming appends, not only after a blank-line edit.

Delta:
- Second site: `apply()` (`tool_folds.lua:323`) clears every fold in the
  exchange in one turn (`zD`, :375-382) and recreates them in the next
  (:383-400). An earlier, closed, *unchanged* `🔧`/`📎` fold reads
  `foldclosed == -1` for exactly one step after each structural append: once
  per whole-block write, twice when a result's closing fence arrives in a
  later 4 KB write (#290 removes that second case).
- The fix direction is unchanged: create the replacement before removing
  anything, and leave folds whose topology didn't change untouched. It must
  cover `apply()` as well as `clear_uncertainty`.
- New regression test (must fail before the fix): open a chat with a closed
  tool pair, append a second tool block (whole, split across two writes, and
  as a one-line result), drain the document, then call `tool_folds.step`
  repeatedly, asserting after every step that the earlier fold's
  `foldclosed` never becomes -1. Repeat for thinking and summary (fix the
  class). The repro harness is `D.attach(buf,{schedule=false})`, then
  `F.setup`, then `nvim_buf_set_lines` appends, then `D.drain`, then a loop of
  `F.step`, probing `vim.fn.foldclosed(row)`.

### 2026-09-27 — Design (plan authored)

Reason: claimed for implementation after #281; the plan needed the mechanism behind
defect (a).

Delta:
- Defect (a) located: every blank-line case (summary, thinking, second exchange) reaches
  `semantic.after_fragment`'s end-checkpoint mismatch (:494-495), whose prepared fallback is
  hard-coded to restart 0 with a dependency rebuild (`before_fragment` :406-407), even
  though `before_fragment` already proved no earlier row depends on the edit. A tool block
  followed by a blank reports no uncertainty, which is consistent with the bounded-extent
  argument.
- #193/#200 checked: #193 required never rebuilding folds outside the rewritten span, and
  #200 was permanent drift. The plan keeps eager clearing only for folds the edit
  intersects (which Neovim corrupts) and keeps exact convergence when settled.

### 2026-09-27 — Plan review round 1 folded in

Reason: a fresh-context plan review found an undefined intersection rule (the obvious one
would have kept the summary flicker), an unbounded `s.edited`, a duplicated VimL walk,
`zc` mis-measuring nested groups, and post-splice dependency pruning that would usually
return `stale`.

Delta: the intersection rule counts only rows an edit *writes* (pure deletions never clear
eagerly); `s.edited` is capped at 8 ranges and cleared at idle, reload and detach; the walk
moves to `fold_native.lua` with a delete/inventory mode; inventory uses `zC`/`zO`;
dependency pruning is computed before the splice (`prune_from`) and installed only on a
mismatch; paths above `INTERACTIVE_ROWS` are unchanged. **Narrowed:** the Log's per-kind
"confirmation stays intact below a summary" negative isn't asserted. The restart is
bounded at the answer header instead (see the plan's "Deliberate narrowing").

### 2026-09-27 — Plan review round 2 folded in

Reason: the round-2 reviewer tested Neovim's manual-fold behaviour headless (brute-force
edit sweep plus native keys) and found that joins (Backspace at column 0, `J`, Delete at
end of line on the blank under a summary) rewrite the summary row. The round-1 rule would
have cleared that fold eagerly and kept the flicker.

Delta: only edits that add **net rows** are recorded for eager clearing (the only edits that
can make a fold absorb rows that aren't its own), measured against post-edit extents; the
continuity spec gains real-keystroke join cases; the "typing into a tool result" boundary
case is replaced by a net insertion inside it (the only kind that really grows a fold);
the nested-group inventory test no longer claims inner open state survives (nested groups
are always recreated from `capture`); M2 gains an O(1) guard that the dependency index is
the one pruned (`serial` doesn't cover `deps:add`), per-keystroke work accounting for
`prune_from`, and a handle-free comparison against the cold parse.

### 2026-09-27 — Operator direction: Parley owns folds; drop the eager clear

Reason: the operator pointed out that users never create folds (Parley makes every one), so
human edits almost never need a fold changed; and that the stream writer knows when a
write is foldable.

Delta: M1 Task 4 no longer clears any native fold on uncertainty (below 50k rows). Neovim
carries folds with their text, and the diff reconcile fixes the rare fold a net insertion
grew, one repair later. The edited-rows tracking is removed. New **zero-touch**
assertions: a plain streamed append and ordinary human edits remove no native fold
(`removed==0`, via the reconcile notify). Folding a block as the writer writes it moves
to #290 (now depends on #264 M1).

### 2026-09-27 — M1 Task 1: continuity spec (red)

`tests/integration/document_fold_continuity_spec.lua`: 23 red, 8 green.
- Red with "row N opened at step 3" (the flicker): summary and thinking blank matrix
  (12), second exchange, Backspace at column 0 under a summary and a thinking block, `J`
  and Delete at end of line on the summary row (confirming review round 2's join
  finding with real keys), all three streaming appends, and typing or Enter in a
  question.
- Red with "reconcile must report removed" (zero-touch counters not implemented yet):
  thinking and summary appended below a closed summary (its fold never opened; only the
  counter is missing).
- Green controls: the tool-pair blank matrix (6; no uncertainty) and both edge cases.

