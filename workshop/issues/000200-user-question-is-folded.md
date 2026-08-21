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

- [x] `reconcile_exchange` verifies each projected range against its anchor
      marker *and its interior*, re-derives the model from the buffer on drift,
      and clears the exchange span before creating folds — no fold can outlive
      the projection.
- [x] A stale/drifted model never anchors a fold on a `💬:` line, never leaves a
      `💬:` line inside a fold's interior, and never throws `E16`.
- [x] Clearing an exchange span scales with the number of folds present, not
      with exchange length — the streaming path (`chat_respond.lua:1743`, one
      call per chunk) must not become quadratic in answer size. Measured
      per-chunk on a 600-row exchange and pinned by an in-suite scaling test.
- [x] A drifted exchange that cannot be folded says so — the refusal is not
      silent.
- [x] One `parley.fence` module owns the fenced-body grammar; `serialize`
      (writer *and* both readers), `answer_structure`, `chat_parser` and
      `fold_projection`'s drift scan all derive from it.
- [x] A nested ``` block inside a tool body no longer truncates its section.
- [x] A `💬:`/`🤖:`/`📎:` line inside a tool body is content, not a turn.
- [x] A durable corpus harness asserts both invariants against real transcripts
      plus an adversarial fixture, measured on actual Neovim fold state.
- [x] `make test` green; atlas + lessons updated.

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
- [x] M2 — one fence grammar
  - [x] Extract `lua/parley/fence.lua` (+ property and round-trip tests)
  - [x] `serialize` derives fence selection **and its reader-side matchers**
        from it (+ parity test) — the reader restatement was truncating bodies
  - [x] `answer_structure` matches fences by length; unterminated fence stops
        at the next boundary instead of swallowing the rest of the answer
  - [x] `chat_parser`'s existing `tool_fence_len` tracker derives from `fence`,
        and the main loop consults it — no second tracker
  - [x] Adversarial fixture added to the corpus harness — it immediately caught
        the M1/M2 interaction in `verify_anchors`

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
- 2026-08-20: closed M1 — M1 green: exchange_anchors 12/12, fold_projection 15/15, tool_folds 1/1 unit + 28/28 integration, fold_invariants 12/12 = 68 fold tests, inventory audited (zero duplicate it() names, counts diffed against HEAD); make test exit 0 on a clean scratch dir; lint 0 warnings/0 errors across 331 files. Latest Critical fixed: clear_folds_in_span navigates with zj and deletes with zD, both of which no-op under nofoldenable, so a stale fold survived the reconcile meant to remove it - reproducing the original reported render verbatim and permanently. Reachable from a user set nofoldenable, from zi, or from parley own chat_toggle_tool_folds. foldenable is now saved, forced and restored around the clear only; a test asserts the operator setting is unchanged. It shipped because every fold spec fixed foldenable = true in setup, so two foldenable = false variants were added and both verified to fail with the guard removed. Nine defects each reproduced and pinned: original reported symptom user question row 23 foldclosed=-1 (was 23, foldend 26); R1 neighbour fold destroyed -1 to 15; R2 assistant-first permanently refused, now reconcile true; R3 span slid inside a later answer -1 to 22; R4 positional aliasing closed structurally, probe 24; R5 identity inert after append, now {5,12}; R6 prefix-stale install, tail fold preserved; R7 prune-one-add-one keeps every tool fold; R8 ranges outside owned rows now refuse; R9 nofoldenable clear now removes the stale fold, probe foldclosed(3)=-1. Creation is verified, destruction is identified, and the two are tied by containment. E16 past-EOF crash gone; refusal provably creates nothing. Clear walks folds not rows, asserted on loop-iteration count not wall clock. Six lessons recorded.; review verdict: FIX-THEN-SHIP

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
  regression (`edit_total` @5000: 2.59→2.55ms median) — it attaches production
  chat handlers (`tests/perf/chat_typing.lua:21`), so it does exercise fold
  *hydration*, but not the streaming path; the direct per-chunk benchmark is
  the streaming evidence. (An earlier note here claimed the perf harness never
  touches folds at all — that was wrong.)
- **A scope bug lint caught, not the tests:** `default_model_provider` was
  defined *below* `reconcile_exchange`, so inside it the name resolved to a nil
  global and the drift re-derive could never run — the failure was silent
  because `pcall` swallowed it. Moved above first use. Worth a lessons entry:
  in Lua a `local function` is not in scope for functions defined earlier, and
  a `pcall` around the call site hides it.

**Perf test instrument.** The first version asserted wall-clock and passed in
isolation but failed under full-suite load (8.35ms vs 79.05ms — measuring the
machine, not the algorithm). Rewritten to compare best-of-N minimums.

**Verification:** `make test` exit 0 (run twice), full suite green; lint 0
warnings / 0 errors across 329 files.

Caveat on how that was obtained, corrected: `Makefile.parley:28` **does** set
`TMPDIR="$(TEST_TMP)"` (= `$(CURDIR)/.test-tmp`) in `TEST_ENV`, reaching the
top-level `Makefile` via `include Makefile.workflow` / `-include Makefile.local`.
An earlier note here claimed the Makefile sets no `TMPDIR`; that was wrong — it
came from grepping only `Makefile` and not the included sub-makefiles, and the
M1 review was right to reject it.

The full mechanism needs both halves: the harness redirects `TMPDIR` into the
repo at `.test-tmp`, **and** under the agent sandbox `git init` is denied the
write it needs to copy its template hooks there (`Operation not permitted`), so
`git_markdown_source_spec` and `markdown_finder_async_spec` fail. Outside the
sandbox the same `git init` under `.test-tmp` succeeds (verified, exit 0) and
`make test` exits 0. Neither spec contains the string `fold`.

### 2026-08-20 — M1 boundary review: REWORK, addressed

The M1 boundary review returned **REWORK** on 1 Critical + 5 Important + 8
Minor. Every finding was checked against the code before acting.

**C1 (Critical) — a regression this milestone introduced, confirmed by
reproduction.** Widening the clear from projected start rows to the whole
exchange span widened *destruction* without widening *verification*. The span
came from the same stale model and was never checked; worse, an exchange with
no foldable block yields an empty range list, so `verify_anchors` returned true
vacuously and the drift branch never ran. Reproduced: reconciling a drifted
exchange 1 deleted exchange 2's `📎:` fold —

    before: 📎 at 26 foldclosed=26
    after:  📎 at 15 foldclosed=-1   (want 15)

— and nothing recreates it, because `hydrate_window` latches. That is the
"always folded" invariant failing with the same persistence signature #200
exists to remove. Fixed with a pure `fold_projection.verify_span`, applied in
both destructive paths (`reconcile_exchange` and `prepare_exchange_update`);
the probe is now a regression test and reports `foldclosed=15`.

Also addressed: atlas section for the new reconcile contract (I1); a
tool-bearing corpus fixture, since the real corpus has **zero**
`tool_use`/`tool_result` blocks and the harness claimed coverage it lacked
(I2); the `Done when` line the removed memo made unmeetable (I3); drift
refusals now carry which half failed to the observer and one debug line (I5);
plus the minors — `is_foldable()` accessor instead of exporting a mutable
policy table, an injectable corpus seam, a per-file assertion floor, a
"refused ⇒ created nothing" assertion, an honest perf-test name, and three
`workshop/lessons.md` entries.

**One finding corrected rather than applied (I4).** The review attributed the
two sandbox test failures to `make` setting `TMPDIR=$(CURDIR)/.test-tmp` and
reported `make test` failing deterministically. The Makefile sets no `TMPDIR`
(`grep -rn TMPDIR Makefile` is empty) and `make test` exits 0 here. The cause
is where `TMPDIR` points under the agent sandbox. The finding's substance — my
Log wording was imprecise, and "run it unsandboxed" is not the mechanism — was
right, and the wording is fixed.

**Verification after rework:** `fold_projection_spec` 14/14,
`tool_folds_spec` 18/18, `fold_invariants_spec` 11/11 (now including a
transcript with real 🔧:/📎: blocks); `make test` exit 0; lint 0 warnings /
0 errors across 329 files. Note `chat_progress_process_spec.lua` is flaky under
full-suite load — it binds a local port and intermittently gets none; it passes
7/7 in isolation, contains no fold code, and the suite passes on retry.

### 2026-08-20 — M1 boundary review round 2: REWORK, addressed

**C1 (Critical) — my round-1 fix over-corrected, creating the same class of
failure it removed.** `verify_span` demanded the span's first row be a `💬:`
line. `chat_parser.lua:623-635` fabricates a question block when an answer has
no preceding question, so `exchange_start` lands on a blank line — verification
failed, the re-derive produced the identical anchor, and `reconcile_exchange`
refused permanently. Reproduced:

    reconcile -> false  which=span
    exchange_start(1)=4 -> line ""
    🧠: / 🔧: / 📎: / 📝:  all foldclosed=-1

Fixed by testing what the producer actually guarantees: **no question after the
first row**, rather than a question *at* it. A span reaching a neighbour still
fails, because reaching one means covering its question. Both C1 scenarios now
hold together — the assistant-first transcript folds all four markers, and the
neighbour's `📎:` keeps `foldclosed == its own row`. Pinned by
`tests/fixtures/fold_assistant_first.md`, verified to fail with the old rule.

**Streaming cost of the drift branch.** The re-derive re-parsed the whole
buffer on every refused reconcile — once per exchange and once per streamed
chunk. Measured **1356 ms** per refused reconcile on a 4805-line chat; memoized
on `changedtick` it is **1.05 ms** (1290×). The key is exact, not approximate:
identical buffer content gives an identical parse, and any edit moves the tick —
unlike the fold-state memo removed earlier, this one cannot go stale silently.
The drift log is emitted once per buffer state rather than once per call.

**A correction I owe the record.** My round-1 rebuttal of I4 was wrong.
`Makefile.parley:28` does set `TMPDIR="$(TEST_TMP)"`; I had grepped only
`Makefile` and missed the `include Makefile.workflow` / `-include
Makefile.local` chain. The review was right. Accurate mechanism: the harness
points `TMPDIR` into `.test-tmp`, and the agent sandbox denies `git init` the
template-hook write there. Unsandboxed both succeed.

Also withdrawn: the "injectable corpus seam" claim — `corpus_provider` is a
single point of definition, not an injection point, and the comment now says so.

**Verification:** `fold_projection_spec` 15/15, `tool_folds_spec` 18/18,
`fold_invariants_spec` 12/12; lint 0 warnings / 0 errors across 329 files.

### 2026-08-20 — M1 boundary review round 3: REWORK, addressed

**C1 (Critical) — round 2's narrowing was too loose, and my justification for
it was wrong.** I claimed an interior-only span check "still catches a span
reaching a neighbour — reaching one means covering its question." False: a
stale span can land *wholly inside* a neighbour's answer, covering its folds
while containing no question at all. Reproduced —

    stale ex2 span 1-based: 20..32
    span now covers rows 20..32; contains a question: false; 📎 now at 22
    RESULT: 📎 at 22 -> foldclosed=-1 (want 22)

The rule now requires **both**: the span starts on its own question, *and* no
question appears after the first row. The anchor requirement is waived for
exchange index 1 only — verified that `chat_parser`'s fabrication path
(`:623-635`) can produce no other index, because it fires only when
`current_exchange` is nil and `current_exchange` is never reset to nil once set
(assignments at `:278` init, `:572`, `:627`).

All four scenarios now hold together, each with a regression test:

| scenario | result |
|---|---|
| original reported symptom (question folded) | `foldclosed=-1` ✓ |
| R1 drifted span destroys neighbour | `foldclosed=15` ✓ |
| R2 assistant-first refused permanently | `reconcile -> true` ✓ |
| R3 span slid inside a later answer | `foldclosed=22` ✓ |

**Re-derive backoff added.** The `changedtick` key only collapses the same-tick
fan-out (reconcile runs per exchange); on the streaming path every chunk is a
new tick, so persistent drift still re-parsed per chunk. Since drift does not
clear by itself, a failed re-derive now backs off 250 ms before the next parse.
Refused-reconcile cost on a 4805-line chat: 1356 ms → 0.75 ms.

**On the `git init` question, settled with measurements rather than a third
guess.** Verified unsandboxed: `git init` succeeds under `.test-tmp`, under a
plain repo subdirectory, and outside the repo (all exit 0), and `make test`
exits 0. Verified sandboxed: it fails with `Operation not permitted`. So the
review's round-3 claim — that `git init` is blocked for any directory under the
repo root independent of the sandbox — does not hold here; the boundary-review
subprocess inherits this session's sandbox, which is what it is observing. What
*was* mine to fix stands corrected: `Makefile.parley:28` does set
`TMPDIR="$(TEST_TMP)"`, which is why the sandbox denial lands on the git specs
at all.

**Verification:** `fold_projection_spec` 16/16, `tool_folds_spec` 19/19,
`fold_invariants_spec` 12/12; `make test` exit 0; lint 0 warnings / 0 errors
across 329 files.

### 2026-08-20 — M1 round 4: extmark-anchored exchange identity

**C1 (Critical) — the positional span rule aliases.** Round 3's two-part check
("starts on its own question, no question after the first row") cannot
distinguish *this* exchange's rows from any other exchange's, so a stale span
aligned onto a later exchange's start satisfies both halves while the range
check is vacuous. Three rounds of sharpening a positional heuristic could not
fix this, because the underlying fact is that **a row-span is not an identity**
— and each round's fix introduced the next round's defect.

Operator decision: fix identity properly inside M1 rather than defer it.

**`lua/parley/exchange_anchors.lua`** (new, thin IO shell) holds one
`invalidate = true` extmark per exchange start — the mechanism `chat_lease`
already uses for the streaming insertion point (#138). Neovim moves marks
across ordinary edits and flags one invalid only when its own line is deleted,
so a mark set from a verified parse keeps describing the same exchange through
edits the model never saw. Demonstrated:

    anchored span ex2 before edit:      { 13, 20 }
    anchored span ex2 after +3 above:   { 16, 23 }   (model unchanged)

Reconcile and `prepare_exchange_update` now take the rows to clear from
identity, falling back to the positional check only when identity declines:
anchor count ≠ model exchange count (a structural edit re-indexed the
exchanges), or either bounding mark's line was deleted. Anchors are installed
only from a model that verified against the buffer — anchoring a stale parse
would make aliasing worse, not better.

`model_fits` no longer checks the span at all; creation is *verified*,
destruction is *identified*. That separation is the actual lesson from four
rounds: the two halves fail differently and cannot share one guard.

**Correction to my own framing.** When choosing this option I said identity
would "likely kill the per-tick re-parse." Measured: it does not — 10 full
parses over 10 tick-moving reconciles, unchanged. The creation half still needs
verified ranges, so healing a stale model still costs one parse per changedtick.
That cost applies only under *sustained* drift; normal streaming keeps the model
in sync through `with_exchange_update` and never reaches the re-derive. The
250 ms backoff bounds the unhealable case.

**Verification:** `exchange_anchors_spec` 10/10 (including both aliasing
guards), `fold_projection_spec` 16/16, `tool_folds_spec` 21/21,
`fold_invariants_spec` 12/12; `make test` exit 0; lint 0 warnings / 0 errors
across 331 files. All four earlier scenarios still hold — original symptom
`foldclosed=-1`, R1 `15`, R2 `reconcile -> true`, R3 `22`.

Note `tools_builtin_find_spec.lua` joins `chat_progress_process_spec.lua` as
load-flaky: 4/4 in isolation, intermittent under the full suite, no fold code
in either.

### 2026-08-20 — M1 round 5: identity refresh

**C1 (Critical) — the identity mechanism went inert on the first appended
exchange.** Round 4 refreshed anchors only at hydration and after a successful
re-derive. `hydrate_window` latches per buf/win, so once a chat gains an
exchange — normal flow — `#ids ~= #model.exchanges` and identity declines for
*every* exchange, permanently. Reproduced:

    after hydrate:            identity for ex1 = { 5, 12 }
    model now has 3 exchanges; anchors hold {}
    after reconcile ex3:      identity for ex1 = {}

With identity inert, every clear fell through to the positional check that
identity exists to replace — and with `ranges == {}` that check is vacuous, so
the round-1 hole was effectively reopened. Now:

    after reconcile ex3:      identity for ex1 = { 5, 12 }

Three changes, and the middle one is the point:

- `owned_span` reinstalls identity on decline before giving up.
- **The positional fallback is removed.** A decline returns nil and routes to
  the re-derive, which installs identity from a fresh parse. Falling through was
  clearing rows we could not prove we owned.
- `verify_span` becomes `verify_starts`: the positional logic now validates a
  whole model's exchange starts at *install* time (ascending, in-buffer, each on
  a question except exchange 1) instead of guarding every clear. That is the
  only place positional reasoning is sound, which is what five rounds were
  really about.

**Behaviour change worth flagging.** The last exchange's span now runs to
end-of-buffer rather than to `last_nonempty_block_end`, since trailing prose
belongs to that exchange's answer. A manual fold in the tail is therefore
cleared. `tool_folds_spec.lua:39` converts to assert that, matching `:57`. This
follows from the ownership contract chosen on 2026-08-20, but it is a wider
consequence than that decision anticipated.

Dead helpers `exchange_span` and `span_lines` removed.

**Verification:** `exchange_anchors_spec` 10/10, `fold_projection_spec` 22/22,
`tool_folds_spec` 22/22, `fold_invariants_spec` 12/12 — 66 fold tests;
`make test` exit 0 (second run; `tools_builtin_find_spec` is load-flaky and
passes 4/4 in isolation), lint 0 warnings / 0 errors across 331 files. All five
scenarios still hold: original symptom `foldclosed=-1`, R1 `15`, R2
`reconcile -> true`, R3 `22`, R4 alias probe `24`.

### 2026-08-20 — M1 round 6: identity may only come from a current-buffer parse

**C1 (Critical) — round 5's "reinstall identity on decline" was unsound.**
`verify_starts` can only judge the rows it is handed, and a *prefix-stale*
model — the buffer grew a trailing exchange the model never saw — passes it
trivially: its starts really are ascending question lines. Installing from it
lays down too FEW anchors, so the last anchor owns to end-of-buffer and its
clear swallows every exchange after it. Prefix-staleness is the canonical
drift, which makes the untrusted model exactly the one that must not define
identity. Reproduced through the production path (`with_exchange_update`, no
hand-built model):

    BEFORE:  📎 9->9   📎 17->17   📎 25->25
    AFTER:   📎 9->9   📎 17->17   📎 25->-1     drift_event=false

Fix: `owned_span` takes a `verified` flag and may install identity only from a
model just parsed from this buffer. `reconcile_exchange` passes `false` for the
caller's model and `true` for the re-derived one; `hydrate_window` passes
`true`. The cost is one extra parse when identity declines, already bounded by
the changedtick memo and the 250 ms backoff.

Deliberately *not* fixed by adding a completeness scan to `verify_starts`
("every question line in the buffer is a start"). That would be correct today
and a trap at M2: once `chat_parser` stops forking an exchange for a `💬:`
inside a fenced tool body, the scan would see a question that is not a start,
decline forever, and reopen round 2's permanent-refusal defect. If it is ever
added it must consume the M2 `fence` grammar, not a raw regex.

`prepare_exchange_update` now reports identity availability on its existing
`prepare` event rather than emitting a drift event: "identity not established
yet" is the ordinary first-call state, and a fault-shaped signal for it would
drown the real ones. Skipping the clear there is safe — finalize's reconcile
owns the span.

**Test-fixture consequence.** Seven pre-existing tests drive `reconcile_exchange`
with hand-built models against buffers that have no `---` frontmatter, so the
default provider cannot parse them and, with the caller's model no longer
trusted, nothing could establish identity. They now declare their model as the
buffer's truth through the module's existing `_model_provider` seam — which is
what that seam is for.

**Verification:** `exchange_anchors_spec` 10/10, `fold_projection_spec` 22/22,
`tool_folds_spec` 23/23 unit + integration, `fold_invariants_spec` 12/12;
lint 0 warnings / 0 errors across 331 files. All six scenarios hold: original
symptom `foldclosed=-1`, R1 `15`, R2 `reconcile -> true`, R3 `22`, R4 alias
`24`, R5 append `{5,12}`.

**`make test` and the `tools_builtin_find_spec` failure — diagnosed, not
waved off.** It failed on two consecutive full runs. Isolation passes 4/4
(three times), and it passes under the suite's own `TEST_ENV`. Running the full
suite with the #200 changes **stashed** reproduces the failure, so it is not
this issue's. Root cause: the spec runs the `find` tool over the repo root,
which includes a `.test-tmp` left populated by previous runs and actively
mutated by the current one — traversing a tree that is changing under it makes
`find` exit nonzero. `rm -rf .test-tmp .test-home .test-xdg` before `make test`
gives **exit 0** on the full suite. Worth its own issue: the harness should
clean its scratch dirs, or the spec should not scan them.

### 2026-08-20 — M1 round 7: validate the whole anchor mapping, not its ends

**C1 (Critical) — `span` checked only the two bounding anchors.** A
*compensating* edit — delete one exchange, add another — leaves the count
unchanged while re-indexing which exchange each anchor names, so index k could
resolve to a different exchange and the clear landed on a neighbour. The user
sequence is ordinary parley usage: prune an old exchange to shed context, then
ask the next question.

`span` now resolves **every** anchor, strictly ascending, and declines the whole
mapping if any one of them fails — a decline routes to the re-derive, which
reinstalls identity from a fresh parse.

Second half of the same finding: `owned_span` with `verified = true` consulted
the marks *before* reinstalling, so even the drift branch preferred
possibly-stale marks over the current-buffer parse it was already holding. It
now reinstalls first when it has a verified model — that parse is strictly
better evidence than marks predating the edit that caused the decline.

Same mistake class as rounds 1–6, stated plainly: I validated a *subset* of the
invariant (the ends of the mapping) rather than the invariant itself (the whole
index→exchange mapping).

One test premise of mine was also wrong and is corrected: I first tried to force
non-ascending anchors by collapsing the rows between two of them. Unreachable —
`invalidate = true` means deleting an anchor's line invalidates that mark rather
than letting two anchors coincide. The ascending check stays as defensive code;
the test now exercises the real prune-and-add sequence instead.

**Verification:** `exchange_anchors_spec` 12/12, `fold_projection_spec` 22/22,
`tool_folds_spec` 24/24, `fold_invariants_spec` 12/12 — 70 fold tests;
`make test` exit 0 (after `rm -rf .test-tmp .test-home .test-xdg`, per the
harness contention diagnosed in round 6), lint 0 warnings / 0 errors across 331
files. All six earlier scenarios still hold.

### 2026-08-20 — M1 round 8: tie creation to destruction

**C1 (Critical) — the two halves could describe different exchanges.**
`model_fits` proves a range matches the buffer's *text*; identity proves which
rows the exchange *owns*. Nothing proved they referred to the same exchange, so
a stale model's ranges could verify against a later exchange's markers while
the clear removed this one's rows:

    identity span for ex3 (0-based): 29..36
    model range: tool_result rows 24..27   INSIDE SPAN = false

`📎: t3` lost its fold with no drift event and no debug line, and nothing
recreated it. Reproduced by inserting one exchange's height into an earlier
exchange's answer — and it is a regression this milestone introduced, since
pre-#200 the deleter could only reach projected start rows.

Fix: an O(#ranges) containment check — every range must lie inside the rows
identity says this exchange owns. It cannot cause a permanent refusal, because
`anchor_from` installs marks at `model:exchange_start(k)` and `desired_folds`
already asserts each range lies inside the exchange bounds, so a freshly
installed identity always satisfies it.

**The scaling test is now deterministic.** It asserted wall-clock, and flaked
twice under load — once sending me chasing a regression that was contention.
`clear_folds_in_span` now reports its loop-iteration count, and the test asserts
that a 16× longer span costs no more iterations. It measures the algorithm
instead of the machine.

**A mistake of mine worth recording.** While replacing that test I sliced the
spec between two markers and deleted **nine** regression tests — every C1 pin
from rounds 1–7 — leaving 16 where there had been 25, all green. Caught by
comparing the test count against `HEAD`, not by the suite: deleted tests do not
fail. Restored from `HEAD` and reapplied the single intended edit. Rule: after
any structural edit to a spec file, diff the test inventory against `HEAD`
rather than trusting a green run.

**Verification:** `exchange_anchors_spec` 12/12, `fold_projection_spec` **15/15**,
`tool_folds_spec` 1/1 unit + 25/25 integration, `fold_invariants_spec` 12/12 —
**65** fold tests, stable across repeated runs; `make test` exit 0, lint 0
warnings / 0 errors across 331 files. All earlier scenarios hold.

**A third spec-surgery defect, and the count above is the corrected one.** The
boundary review found `describe("anchor verification")` present **twice** in
`fold_projection_spec.lua` — 7 tests duplicated by an earlier edit of mine. The
"22/22" reported in the round-7 entry was 15 distinct cases plus 7 copies, so
every fold-test total I have quoted from round 4 onward was inflated by 7. The
duplicate block is removed and all five fold specs are now audited for duplicate
`it()` names (zero) as well as for count against `HEAD`.

Three structural-edit defects in this file set now — nine tests deleted, seven
duplicated, one test premise unreachable — none of which a green run could
reveal. The `## Log` counts above are the audited ones.

**`make test` claim, narrowed.** Round 7 said cleaning the scratch dirs gives
exit 0. That holds here (verified again on a clean run), but the boundary review
saw `tools_builtin_find_spec` and both `git init` specs fail on separate clean
runs in its own environment. The accurate statement is: these three specs are
environment-sensitive, none contains fold code, and the failures reproduce with
all #200 changes stashed.

### 2026-08-20 — M1 boundary review: FIX-THEN-SHIP, five Importants addressed

First non-REWORK verdict. No Criticals. All five findings verified before
acting:

- **BR-1 — `FOLDABLE` restated `ANCHOR_KIND`'s key set.** Two hand-maintained
  tables with identical keys, and the drift mode is silent and *total*: a kind
  present in one and not the other yields a nil `anchor_kind`, verification
  fails, and the whole exchange stops folding. `FOLDABLE` is now derived from
  `ANCHOR_KIND` (`ARCH-DRY`).
- **BR-2 — only half the ownership contract was pinned.** Tests covered "Parley
  owns every fold within an exchange span" but nothing covered "folds outside
  every span are untouched", so re-widening the clear would have passed the
  suite. Added a test folding the frontmatter — owned by no exchange — and
  asserting it survives a full reconcile.
- **BR-5 — the re-derive memo leaked a parsed model per buffer.**
  `setmetatable({}, { __mode = "k" })` collects only GC-able keys, and the keys
  here are buffer *numbers*, which are never collected. It read as cleanup while
  retaining every parse. Dropped the misleading weak mode and cleared
  `rederived[buf]` on the buffer lifecycle events alongside `initialized` and
  the anchors.
- **BR-3 / BR-4 — docs described code from three rounds ago.**
  `atlas/chat/exchange_model.md` still named `verify_span` and "the positional
  fallback", both removed in round 5; the plan's Core-concepts entry contradicted
  both the code and its own later text. Both now describe what exists: no
  positional fallback, identity installable only from a current-buffer parse,
  `verify_starts` as the one surviving positional check, and the containment tie
  between creation and destruction.

**Verification:** `exchange_anchors_spec` 12/12, `fold_projection_spec` 15/15,
`tool_folds_spec` 1/1 unit + 26/26 integration, `fold_invariants_spec` 12/12 —
**66** fold tests, inventory audited (zero duplicate `it()` names in any fold
spec); `make test` exit 0 on a clean scratch dir; lint 0 warnings / 0 errors
across 331 files. All eight reproduced scenarios still hold.

### 2026-08-20 — M1: the clear silently no-opped under `nofoldenable`

**C1 (Critical) — the reported symptom returns verbatim when folding is
disabled in the window.** `clear_folds_in_span` navigates with `zj` and deletes
with `zD`; with `foldenable` off, neither acts, so the loop runs to completion
having removed nothing. A stale fold — including one anchored on a `💬:` line —
survives the reconcile that exists to remove it, permanently, since nothing else
deletes folds and `hydrate_window` latches. Reproduced:

    foldenable at reconcile=true  -> foldclosed(3)=-1
    foldenable at reconcile=false -> foldclosed(3)=3     💬: q (4 lines)

The trigger is ordinary: a user's `set nofoldenable`, `zi`, or **parley's own**
`chat_toggle_tool_folds` (`init.lua:2236`). A regression this milestone
introduced — the pre-#200 `zd` at projected start rows did not consult fold
navigation at all.

Fixed by saving, forcing and restoring `&l:foldenable` around the clear only,
inside the existing `nvim_win_call`. Creation needs no guard: `%d,%dfold` works
under either setting. The operator's setting is left exactly as found, and a
test asserts that.

**The reason it shipped is the more useful finding.** Every fold spec set
`foldenable = true` in setup, so no test could ever have caught it. Added two
`foldenable = false` variants — stale-fold clearing, and the "exactly one fold
level across repeated reconciles" property that would otherwise deepen nesting
once per streamed chunk. Both verified to fail with the guard removed and pass
with it, rather than assumed to pin anything.

**Verification:** `exchange_anchors_spec` 12/12, `fold_projection_spec` 15/15,
`tool_folds_spec` 1/1 unit + 28/28 integration, `fold_invariants_spec` 12/12 —
68 fold tests; `make test` exit 0 on a clean scratch dir; lint 0 warnings /
0 errors across 331 files. All eight earlier scenarios hold, plus the
`foldenable = false` probe now reporting `foldclosed(3)=-1`.

### 2026-08-20 — M1 FIX-THEN-SHIP: findings fixed, milestone closed

Verdict FIX-THEN-SHIP. Per #174 the findings are fixed before the close commit
and bundled into it; no re-review of this boundary.

**I-A — reconcile was O(number of exchanges in the chat), on the per-chunk
path.** `span()` resolves every anchor to detect re-indexing (the round-7 fix),
so cost tracked chat length rather than exchange length. Resolved rows are now
cached per `(buf, changedtick)` — exact, since extmarks move only on edits and
every edit bumps the tick. Measured, streaming exchange held constant:

    exchanges=10   0.0386 -> 0.0355 ms
    exchanges=50   0.0495 -> 0.0380 ms
    exchanges=200  0.1172 -> 0.0434 ms
    exchanges=500  0.2549 -> 0.0675 ms

Growth over 50× more exchanges falls from 6.6× to 1.9×, and 500 exchanges now
sits below the 0.078 ms pre-#200 baseline. The residual is **not** in this
module: `exchange_model:exchange_start(k)` (`exchange_model.lua:168-175`) walks
exchanges 1..k, so reconciling the last exchange of a long chat is inherently
O(k). Pre-existing and outside #200's scope — recorded rather than fixed here.

**I-B — the drift refusal was silenced for the buffer's lifetime.**
`rederived[buf].logged` was carried into each new tick's entry and never reset,
so only the *first* refusal in a session ever produced a line. The comment
claimed "once per buffer state" and the Done-when requires that a refusal not be
silent — silent persistent non-folding being #200's own pathology. `logged` no
longer inherits, and the memo is dropped on a successful reconcile so a later
unrelated drift reports again.

Minors fixed: `_last_clear_iters` reset on every early return (a stale count was
readable as if it described the current call); the iteration instrument moved
off a global to `vim.b`; `prepare_exchange_update` no longer computes
`desired_folds` per chunk purely to fill an observer payload; `verify_anchors`
requires `highlight_structure` only when patterns are not supplied, so the
module is nvim-free at *call* time and not merely at load — now pinned by a test
that nils `_G.vim` and calls it; containment moved out of the IO shell into
`fold_projection.ranges_within` with five unit cases; `_observer` reset in
`after_each` so a failing assertion cannot leak it; stale comments describing
wall-clock sampling corrected.

Bookkeeping the review asked for: **#202 filed** for the `make test` harness
contention diagnosed in round 6 (it would otherwise have been archived with this
issue); README now documents the fold-ownership contract, which is
operator-visible and had been atlas-only; M1's plan step checkboxes ticked; a
sixth lessons entry added for duplicate-detection, since the existing rule keys
on a *shrinking* suite and a duplicated `describe` makes it *grow*.

**Verification:** `exchange_anchors_spec` 12/12, `fold_projection_spec` 21/21,
`tool_folds_spec` 1/1 unit + 28/28 integration, `fold_invariants_spec` 12/12 —
74 fold tests, zero duplicate names in any spec; `make test` exit 0 on a clean
scratch dir; lint 0 warnings / 0 errors across 331 files. All nine reproduced
scenarios hold.

### 2026-08-21 — M2 implemented: one fence grammar

TDD throughout; each task red before green.

- **Task 6** — `lua/parley/fence.lua`: `open_len` / `closes` / `for_content` /
  `longest_run` / `extract_body`, pure. The property test pins what the grammar
  exists to guarantee — no line of a body can close the fence chosen for it —
  over malformed inputs rather than literals. A parity test asserts the grammar
  agrees with serialize's *existing* writer before anything was converted.
- **Task 7** — `serialize` derives both halves. The reader restatement was not
  merely duplication, it was **wrong**: a `%1` backreference matches a PREFIX of
  a longer run, so `parse_result("```\na\n`````\nb\n```")` returned `"a"`
  where the grammar returns the whole body. Reachable from any tool output not
  produced by `render_result`.
- **Task 8** — `answer_structure` matches by length. A nested ``` no longer ends
  a tool section early (its tail had been emitted as unfoldable `text`), and an
  unterminated fence rewinds to the first structural boundary instead of
  swallowing the rest of the answer.
- **Task 9** — smaller than planned, exactly as PQ-3 said. `chat_parser` already
  had a correct tracker; the main loop simply never consulted it. Two changes,
  no second state machine.
- **Task 10** — the adversarial fixture, which earned its place immediately.

**The fixture caught the M1/M2 interaction on the day it was added.** M1 had
recorded the hazard — that M2 would make an in-body `💬:` legitimate content and
any raw-prefix scan would then reject correct input — and it landed in
`verify_anchors`, the sibling of the function the note named. PQ-4's interior
drift scan rejected the whole exchange:

    observer: drift/ranges
    row 10  🧠:  foldclosed=-1        (every marker in exchange 1 unfolded)

The scan now consumes the fence grammar and skips the block's fenced body, while
still rejecting a question *after* the body closes — the end-drift it exists to
catch. Both directions pinned, plus a longer nested fence that must not close
the outer body early. Nothing else in the suite could have caught this: the real
corpus contains no in-body markers and no nested fences at all.

**Verification:** `fence_spec` 13/13, `tools_serialize_spec` 18/18,
`answer_structure_spec` 7/7, `chat_parser_tools_spec` 5/5,
`fold_projection_spec` 24/24, `exchange_anchors_spec` 12/12,
`tool_folds_spec` 1/1 unit + 30/30 integration, `fold_invariants_spec` 13/13;
`make test` exit 0 on a clean scratch dir; lint 0 warnings / 0 errors across 333
files. All six M1 drift probes still hold — checked deliberately, because
`chat_parser`'s exchange boundaries feed `exchange_anchors`, which drives a
destructive fold clear.

Two corrections of my own along the way: a `git stash` "teeth check" was a no-op
because the file was already committed, and re-running it properly against the
parent commit exposed one of three new serialize tests as vacuous (a single-line
JSON body cannot exercise a line-start run) — re-aimed, and two of three now
fail without the conversion. And one test expectation cited the in-body marker's
line number rather than the real question's.

### 2026-08-21 — M2 boundary review: REWORK, addressed

**BR-31 (Important) — I destroyed 11 pre-existing tests.** I wrote
`tests/unit/chat_parser_tools_spec.lua` with `cat >` believing it was a new
file; it existed, with 11 tests covering `content_blocks` recognition from #81.
The suite reported 16 green where it should have been 27. This is the **second**
deletion of tests in this issue, after I had already written the lessons entry
about the first — that rule keyed on "structural *edit*", and I did not apply it
because creating a file did not feel like editing one. Restored all 11 from
`9a6e939~1` and re-appended my 5, wired to the file's existing `parser` /
`test_config()` helpers rather than a second set. 16/16, zero duplicates.

**BR-33 (Important) — my fence-aware interior scan disabled its own guard.** It
entered body mode on *any* line the grammar accepted as an opener, for *any*
foldable kind. A bare closing run is indistinguishable from an opener, so one
grammar-rejected fence desynced the scan and it stopped checking for user
markers for the rest of the range. Not hypothetical: `render_buffer.lua:104`
emits ```` ```json {"type": "request"} ````, whose info string the grammar
rejects. Now tracked only for `tool_use`/`tool_result`, and only when the body
opens on the line immediately after the marker — the serialized shape. Two tests
pin it: a `thinking` range with a code fence inside, and a range whose opener
the grammar rejects.

**BR-34 (Important) — a tick with no evidence.** I bulk-ticked M2's plan steps,
including "re-run the audit against the operator's live `chat_dir`". It had not
been run. It has been now:

    AUDIT files=115 parsed=111 exchanges=463 assertions=1155
          question_violations=0 marker_violations=0

Recorded beside the tick, with a census that bounds what it proves: the live
corpus holds `thinking=406`, `summary=286`, and **zero tool blocks**. Neither
the in-repo transcripts nor the operator's own exercise the `🔧:`/`📎:` case
this issue is named for — the two fixtures are its only coverage, and "audited
115 transcripts" must not be read otherwise.

**BR-32 (Important)** — `atlas/chat/format.md` still named
`tools/serialize.lua` as the fence single source. It now points at
`lua/parley/fence.lua` for the grammar and keeps serialize for the schema.

Two lessons added: `cat >` on an assumed-new path is a silent overwrite, and
never bulk-tick checkboxes.

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
