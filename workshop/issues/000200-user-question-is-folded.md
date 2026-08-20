---
id: 000200
status: working
deps: []
github_issue:
created: 2026-08-18
updated: 2026-08-19
estimate_hours: 6.35
started: 2026-08-19T11:50:43-07:00
---

# user question is folded

let's do an audit how folding is done. user questions should not be folded. what's folded:

1. tool call
2. tool response
3. summary started with 📝:

only those should be folded and those should always be folded. 

## Problem

Two invariants are violated:

1. A user question (`💬:`) can end up as a fold header, rendered
   `💬: … (N lines)`. Confirmed by the operator and reproduced.
2. Tool calls (`🔧:`), tool results (`📎:`) and summaries (`📝:`) can fail to
   fold, or be swallowed into a neighbouring fold.

The intended policy was already correct — `fold_projection.FOLDABLE` is
`{thinking, summary, tool_use, tool_result}` and excludes questions. The
failures are in how that desired state is *applied* and in how answer sections
are *segmented*, not in the policy.

## Spec

Folding holds these two invariants at all times, not merely on a cold open:

- **A user question is never inside a fold.** Not as a fold header, not
  swallowed by an earlier fold.
- **`🔧:`, `📎:`, `📝:` and `🧠:` blocks are always folded**, each anchored on
  its own marker line.

`🧠:` stays foldable (operator decision, 2026-08-19): it is verbose and
fold-worthy, and it is already legacy — the shipped default prompt dropped the
`🧠:` protocol in #143, so it only appears under custom/back-compat prompts.

Two root causes, both fixed here:

- **`tool_folds.reconcile_exchange` does not reconcile.** It appends folds at
  model-computed rows and never removes one the projection no longer wants, so
  drift from any mutation not wrapped in `with_exchange_update` is permanent
  and survives the whole session (`hydrate_window` latches on
  `initialized[buf][win]`). Drift past EOF additionally throws an uncaught
  `E16: Invalid range`.
- **The fenced-tool-body grammar has three independent owners.**
  `tools/serialize.lua` implements it correctly (matching pair of the *same*
  backtick length) but restates it again on its reader side;
  `answer_structure.lua` closes on any ≥3-backtick run; `chat_parser.lua`
  carries its own separate — and correct — `tool_fence_len` tracker at
  `:455-469`, which the main loop at `:549` never consults. So a nested ```
  block truncates a tool section, and a `💬:` line inside tool output forks a
  spurious exchange even though the parser already knows it is inside a body
  (`ARCH-DRY`).

## Done when

- [ ] `reconcile_exchange` verifies each projected range against its anchor
      marker *and its interior*, re-derives the model from the buffer on drift,
      and clears the exchange span before creating folds — no fold can outlive
      the projection.
- [ ] A stale/drifted model never anchors a fold on a `💬:` line, never leaves a
      `💬:` line inside a fold's interior, and never throws `E16`.
- [ ] Reconciling an exchange whose fold set is unchanged does no fold work —
      the streaming path (`chat_respond.lua:1743`, one call per chunk) stays
      within the existing `tests/perf/chat_typing.lua` budget.
- [ ] One `parley.fence` module owns the fenced-body grammar; `serialize`,
      `answer_structure` and `chat_parser` all derive from it.
- [ ] A nested ``` block inside a tool body no longer truncates its section.
- [ ] A `💬:`/`🤖:`/`📎:` line inside a tool body is content, not a turn.
- [ ] A durable corpus harness asserts both invariants against real transcripts
      plus an adversarial fixture, measured on actual Neovim fold state.
- [ ] `make test` green; atlas + lessons updated.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec             design=1.5  impl=0.12
item: lua-neovim             design=0.4  impl=0.4
item: lua-neovim             design=0.3  impl=0.4
item: lua-neovim             design=0.2  impl=0.3
item: cross-cutting-refactor design=0.2  impl=0.2
item: scope-pivot            design=0.3  impl=0.12
item: milestone-review       design=0.0  impl=0.6
item: atlas-docs             design=0.15 impl=0.24
design-buffer: 0.30
total: 6.35
```

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only. Design hours are v2/v2.1 table values (v3.1
does not scale design); `impl=` values are v2 table values at v3.1's 40%.

- **`issue-spec` 1.5 / 0.12** — the primitive's ceiling, no spec-quality
  discount: the spec *is* the deliverable. It covers a three-scan corpus audit
  over 127 transcripts, a drift reproduction (`drift_probe.lua`), a 1399-line
  plan, and a nine-finding plan-quality round. This line is **ceiling-clamped** —
  the true design cost has already outrun what "issue authoring + spec" was
  calibrated to express, and the overflow is absorbed by `scope-pivot` and the
  buffer rather than by inflating a primitive past its table.
- **`lua-neovim` 0.4 / 0.4** — M1 Tasks 1–3: interior-aware verification in
  `fold_projection` plus span clearing, the memo and verify-first reconcile in
  `tool_folds`. Mid-range design under Step 3's ×0.2 discount (2.0 → 0.4); the
  plan gives literal code and literal test bodies.
- **`lua-neovim` 0.3 / 0.4** — M1 Task 4 and Task 3 Step 6: a *new* integration
  harness (`tests/integration/fold_invariants_spec.lua`) enumerating the tracked
  corpus, driving real Neovim fold state through a model-derived oracle, plus
  the before/after measurement against `tests/perf/chat_typing.lua`. Priced as
  its own unit — PQ-2 forced a redesign of this oracle, so it is not incidental
  to the reconciler.
- **`lua-neovim` 0.2 / 0.3** — M2 Tasks 6 and 10: the new pure `parley.fence`
  module with its property and round-trip cases, and the adversarial fixture.
- **`cross-cutting-refactor` 0.2 / 0.2** — M2 Tasks 7–9: one grammar to three
  consumers (`serialize` writer *and* reader, `answer_structure`,
  `chat_parser`). **Top of the impl range** (0.5 → 0.2 at 40%); design is top of
  range *with* the ×0.2 spec discount (1.0 → 0.2), not top of range unscaled —
  v3.1 leaves design alone, so the discount is what produces 0.2.
- **`scope-pivot` 0.3 / 0.12** — no discount. The fold-ownership contract needed
  an operator call mid-plan and PQ-3 invalidated a stated premise about
  `chat_parser`; that rework is exactly this primitive.
- **`milestone-review` 0.0 / 0.6** — **three** boundaries, not two: `milestone-close M1`, `milestone-close M2`, and the review `sdlc close` auto-dispatches
  (AGENTS.md §3). Top of the 0.2–0.5 impl range each — plan-quality found nine
  findings on the design alone, so nominal code reviews are unlikely.
- **`atlas-docs` 0.15 / 0.24** — three deliverables, not one: the atlas at M1
  (Task 5) and again at M2 (Task 11), plus `workshop/lessons.md`. Design at the
  0.05 floor × 3, undiscounted (the plan does not pre-write atlas prose).
- **familiarity ×1.0** — parley's own fold and parser surface, worked repeatedly
  in #193/#194/#195.
- **design-buffer 0.30 — a deliberate override of v3.1's plain rule, not the
  model's output.** v3.1 Step 4 conditions +15% on the *existence* of a thorough
  plan doc, which this issue has; taken literally it yields +15%. The override
  invokes v2.1's cross-check instead ("if Step 3 was ×0.5 or ×1.0, keep the v2
  +30%") on the grounds that ×0.2 covers only 0.9 of 3.05 design hours (30%),
  with `issue-spec`'s undiscounted 1.5 h dominating. Cost of the override:
  +0.46 h, ~7% of the total. Recorded here so the calibration ledger can back it
  out if the override proves wrong.

**Ledger caution.** The *reconciler and parser* rows specifically have run low:
#195 ratio 0.53, #190 0.57, #187 0.58, #168 0.56–0.60, #197 0.82 — and #195 built
the very reconciler this issue repairs, estimating 1.84 impl against a 6.56 h
actual. This is **not** a claim about parley large issues generally: the same
ledger holds #189 at 1.42, #198 at 3.24 and #186 at 0.91–0.96. 6.35 h is derived,
not fitted, so it stands as written; the rows to watch at close are
`milestone-review` (three boundaries priced at a *nominal*-review ceiling, when
plan-quality already returned nine findings against the design alone) and the new
corpus-harness row, whose oracle PQ-2 already forced a redesign of.

## Plan

Design: `workshop/plans/000200-fold-reconciliation-plan.md`

- [x] M1 — fold reconciliation
  - [x] Anchor **and interior** verification in `fold_projection` (pure)
  - [x] `clear_folds_in_span` replaces start-row-only fold deletion; convert the
        two tests encoding the old ownership contract
  - [x] `reconcile_exchange` verifies → re-derives on drift → clears → creates.
        The streaming hot path is handled by fold-to-fold clearing, not by the
        planned memo — see the Log for why the memo was removed.
  - [x] Corpus regression harness (`tests/integration/fold_invariants_spec.lua`),
        oracle derived from the parsed model
  - [x] Streaming perf measured (`make perf` plus a direct per-chunk benchmark)
- [ ] M2 — one fence grammar
  - [ ] Extract `lua/parley/fence.lua` (+ property and round-trip tests)
  - [ ] `serialize` derives fence selection **and its reader-side matchers**
        from it (+ parity test)
  - [ ] `answer_structure` matches fences by length; unterminated fence stops
        at the next boundary instead of swallowing the rest of the answer
  - [ ] `chat_parser`'s existing `tool_fence_len` tracker derives from `fence`,
        and the main loop consults it — no second tracker
  - [ ] Adversarial fixture added to the corpus harness

## Log

### 2026-08-19 — fold-surface audit

**The whole fold surface is one producer.** `lua/parley/tool_folds.lua` is the
only module that creates or deletes folds (`grep -rn "fold" lua/` — the only
other hits are `outline.lua`'s `zz` recentering, which is scrolling, not
folding). It runs `foldmethod=manual` and creates every fold explicitly from
`fold_projection.desired_folds`, which folds exactly:

    FOLDABLE = { thinking, summary, tool_use, tool_result }

So the *intended* policy already excludes questions — and includes `thinking`
(🧠:), which the issue's list of three does not mention.

**Corpus audit — the static path is clean.** Three scans over all 127 real
transcripts (`workshop/parley/` + the iCloud `chat_dir`):

1. Pure projection (parse → exchange_model → desired_folds): **0 violations**.
   No fold range covers a `💬:` line; every `🔧:`/`📎:`/`📝:` line is covered.
2. Runtime hydration in a real buffer (`tool_folds.hydrate_window` → `zM` →
   `foldclosed()`): **0 violations**. Same two invariants, measured on actual
   Neovim fold state.
3. Ground-truth raw-text scan for structural markers inside a tool block's
   fenced body: **0 hits**.

**Probes that cleared suspected live-path defects:**

- Appending the next `💬:` prompt right after a folded trailing block
  (`chat_respond.lua:1929`) does *not* grow the fold over it — Vim does not
  extend a manual fold at its end boundary.
- `initialized[buf][win]` gating hydration across a buffer switch does not lose
  folds or `foldmethod`; Neovim saves/restores both per buffer per window.

**Two latent structural defects found (both fence-naiveté, neither reproduced
by the current corpus):**

- `chat_parser.lua:549` — the main loop classifies every line with no
  fence-awareness, so a `💬:` line inside a `📎:` tool-result body starts a
  *new exchange*. The spurious question then absorbs the rest of the tool body
  (including the closing fence and any `📝:`), leaving it unfolded.
- `answer_structure.lua:88` — once `fence_open` is true the scanner ignores
  `BOUNDARY` kinds, but `highlight_structure.classify` treats *any* run of ≥3
  backticks as `fence`. A tool result whose body contains a nested ``` block
  (outer fence is longer per `tools/serialize.lua`) closes the section early;
  the tail is then emitted as unfoldable `text`.

Both violate "those should always be folded". Neither folds a user question.

### 2026-08-19 — ROOT CAUSE reproduced

Operator confirmed the symptom shape: the fold's **first line is the `💬:`
line**, rendered `💬: … (N lines)`. That text can only come from `foldtext()`'s
`else` fallback (`tool_folds.lua:154`) — i.e. a fold whose start row is not a
`🔧:`/`📎:`/`🧠:`/`📝:` marker.

**Reproduced** (`scratchpad/drift_probe.lua`): hydrate a chat, mutate the buffer
through a path that does not update the live model, then call
`reconcile_exchange` on the now-stale model. Output:

    23 💬: second question   foldclosed=23 foldend=26
    >>> foldtext: 💬: second question (4 lines)

**Root cause — `reconcile_exchange` does not reconcile; it only adds.**

    for _, range in ipairs(ranges) do
        vim.cmd(string.format("%d,%dfold", range.start_0 + 1, range.end_0 + 1))
    end

It creates folds at model-computed rows and never removes a fold the projection
does not want. The only deletion is `prepare_exchange_update`'s
`delete_projected_folds`, which `zd`s **only at the desired start rows** — so a
fold anywhere else in the exchange survives untouched. Consequences chain:

1. Any buffer mutation not wrapped in `with_exchange_update` drifts the live
   model from the buffer (the model is built once and mutated incrementally,
   never re-derived).
2. The next reconcile creates folds at stale rows, which can land exactly on a
   `💬:` line.
3. Nothing removes it, and `hydrate_window` will not re-run — `initialized[buf]
   [win]` latches after the first hydration — so the bad fold persists for the
   whole session. Reopening the file is the only cure, which is why all 127
   transcripts audit clean from a cold parse.
4. `foldtext()`'s `else` fallback renders the corrupt fold as ordinary text
   instead of failing loudly, masking the defect.

**Second defect, same probe:** when drift runs the range past EOF,
`reconcile_exchange` throws an uncaught `E16: Invalid range: 23,26fold` out of
`vim.cmd`. Stale model ⇒ hard error, not degraded folds.

This is architectural, not a position off-by-one: the projection is a *desired
state*, but the applier treats it as an *append list*. `ARCH-DRY` — the buffer's
fold state has two owners (the live model's incremental mutations and Vim's own
line-shifting) with nothing making them agree.

### 2026-08-18

### 2026-08-20 — design landed, plan-quality round 1

- Committed the audit, Spec and durable plan (`38a6cdd`). They had been authored
  the previous session but never committed, so the only record of the
  reproduction was an untracked working tree.
- Recovered the reproduction script (`drift_probe.lua`) from the prior session's
  scratchpad; it seeds Task 4's corpus harness rather than being rewritten.
- `sdlc change-code --issue 200` blocked at plan-quality: 1 Critical, 4
  Important, 4 Minor. Verified all five blocking findings against the code
  before revising — every one was real:
  - `tool_folds_spec.lua:57` does create a user fold at `25,26` inside the
    exchange span and asserts it survives (PQ-1).
  - `chat_parser.lua:455-469` **does** already track fences with same-length
    close matching, contradicting the plan's premise (PQ-3).
  - `chat_respond.lua:1743` wraps every streamed chunk in
    `with_exchange_update`, putting the new span clear on the hot path (PQ-5).
  - In-repo corpus is 11 files (10 tracked), not the 127 of the operator's
    iCloud `chat_dir`.
- Plan revised against all nine findings; deltas recorded in the plan's
  `## Revisions`.

### 2026-08-20 — M1 implemented

TDD throughout; each task red before green.

- **Task 1** — `fold_projection.anchor_kind` + `verify_anchors`, pure and
  nvim-free (the load-without-vim test still passes). Verification covers the
  anchor *and* the interior, so end-drift that keeps a valid anchor while
  overshooting the next question is rejected. 9/9.
- **Task 2** — `clear_folds_in_span` replaces the start-row-only `zd` loop.
  Red reproduced the surviving stale fold. As PQ-1 predicted,
  `tool_folds_spec.lua:57` then failed; converted per the ownership decision.
  `:39` was dispositioned by *running* it — its fold sits outside the span and
  survives, so the narrower contract still holds where it should.
- **Task 3** — verify → re-derive on drift → clear → create. Red reproduced
  both reported failures exactly: a fold anchored on `💬:` at row 22, and
  `E16: Invalid range: 7,46fold`.
- **Task 4** — corpus harness, 10/10 across the tracked transcripts.

**End-to-end proof.** Re-ran the original `drift_probe.lua`: row 23
`💬: second question` now reports `foldclosed=-1` (was `foldclosed=23
foldend=26`, rendering `💬: second question (4 lines)`), and the drifted
exchange's real `📎:` still folds at its own row — it healed rather than
merely refusing.

**Two corrections to the plan, both found by running the code:**

- **The planned memo was removed.** Memoizing the applied range set is
  *unsound*: verification proves the MODEL matches the buffer but says nothing
  about which folds actually exist, so short-circuiting let an externally-added
  fold survive inside the span — defeating the very contract the span clear
  enforces. Two tests caught it. PQ-5's concern was real, but the honest fix is
  algorithmic: clear fold-to-fold with `zj` instead of probing every row.
  Measured per-chunk reconcile on a 600-row exchange:
  `0.078ms` (pre-#200, no clearing at all) → `3.705ms` (row walk from Lua) →
  `1.198ms` (row walk in one VimL crossing) → **`0.067ms`** (fold-to-fold).
  Faster than the pre-#200 baseline *and* fully verified. `make perf` shows no
  regression (`edit_total` @5000: 2.59→2.55ms median).
- **A scope bug lint caught, not the tests:** `default_model_provider` was
  defined *below* `reconcile_exchange`, so inside it the name resolved to a nil
  global and the drift re-derive could never run — the failure was silent
  because `pcall` swallowed it. Moved above first use. Worth a lessons entry:
  in Lua a `local function` is not in scope for functions defined earlier, and
  a `pcall` around the call site hides it.

**Perf test instrument.** The first version asserted wall-clock and passed in
isolation but failed under full-suite load (8.35ms vs 79.05ms — measuring the
machine, not the algorithm). Rewritten to compare best-of-N minimums.

**Verification:** `make test` exit 0, full suite green; lint 0 warnings /
0 errors across 329 files. Two integration specs (`git_markdown_source`,
`markdown_finder_async`) fail under the sandbox because `git init` cannot copy
its template hooks — they pass unsandboxed and are unrelated to this issue.

## Revisions

### 2026-08-20 — Fold ownership contract + plan-quality round 1

Reason: `sdlc change-code` plan-quality blocked with 1 Critical + 4 Important
findings (all verified real against the code). One required an operator
decision; the rest are design corrections recorded in the plan's own
`## Revisions`.

Delta:

- **Ownership contract, operator decision:** Parley owns **every fold within an
  exchange span**, not just folds at projected start rows. A manual `zf` inside
  an exchange is deleted on the next reconcile; folds outside every exchange
  span are untouched. `tests/integration/tool_folds_spec.lua:57` encodes the old
  contract and converts.
- **Spec correction:** the earlier claim that `chat_parser` "does not model
  fences at all" was false — it has a correct tracker at `:455-469` that the
  main loop at `:549` fails to consult. The M2 parser change is correspondingly
  smaller, and must not add a second tracker (`ARCH-DRY`).
- **Done-when additions:** interior verification (a question must not sit inside
  a fold's *span*, not merely at its head), and a streaming-path performance
  criterion — the span clear now runs per streamed chunk.
