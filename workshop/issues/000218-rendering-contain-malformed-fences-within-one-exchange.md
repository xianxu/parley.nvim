---
id: 000218
status: codecomplete
deps: []
github_issue:
created: 2026-09-05
updated: 2026-09-05
estimate_hours: 1.86
started: 2026-09-05T12:12:38-07:00
actual_hours: 2.13
---

# Rendering: contain malformed fences within one exchange

## Problem

Surfaced in the #206 release shakedown (#217 gap 10). When a model returns an
unmatched ``` fence, the damage does not stay in that answer — the rest of the
document renders as code.

The operator's diagnosis was right: **the render path does not honour the
exchange boundary that the structure already tracks.** `highlight_structure`
resets `in_question` and `in_reasoning` at every `💬:`/`🤖:` partition and never
`in_code`:

```lua
if token == TOKENS.user then
    state.in_question = true
    state.in_reasoning = false          -- reset
elseif token == TOKENS.assistant or token == TOKENS["local"] or token == TOKENS.branch then
    state.in_question = false
    state.in_reasoning = false          -- reset
```

### The class: four independent fence trackers, none of which reset

| # | site | shape | resets at partition? |
|---|---|---|---|
| 1 | `highlight_structure.lua:85,173` | boolean toggle on `^%s*```` | no |
| 2 | `highlighter.lua:148-153` | **duplicate** of #1, re-derived per window | no |
| 3 | `outline.lua:31-33` | boolean toggle, also `~~~` | no |
| 4 | `skills/review/init.lua:166-172` | fence-range pairing | no |

#2 is byte-identical logic to #1, seeded from it and then advanced privately —
so fixing #1 alone repairs the *seed* and leaves the in-window walk leaking.

## Spec

`💬:`/`🤖:` at line start are hard partitions: fence state resets at every
boundary, so a malformed answer corrupts at most its own section. Containment is
**positional**, not fence-matching — ``` is legitimate content inside a question
asking about fences, so no smarter matcher substitutes for the reset.

### Phase is explicit (PQ-1)

`state_before[row]` is written **before** the row's transitions
(`highlight_structure.lua:161`), while `highlighter.lua:149` toggles **before
use**. They therefore disagree on every fence-delimiter row — pinned today by
`highlight_structure_spec.lua:52`. Naively reading `state_before` per row would
invert the fence line's own render (`highlighter.lua:247`) and dim every tool
body's closing fence (`:223`).

Decisions:

- **Partition resets run BEFORE the snapshot**, unlike `in_question`, which is
  set after. Rationale: a `💬:`/`🤖:` line is itself not inside code, so
  `state_before[partition_row].in_code` must already be false. This matches the
  footer guard, which also runs pre-snapshot.
- **Deduplicate by extracting the transition, not by swapping the phase.**
  `highlight_structure` exports `M.advance(state, token, …)`; the builder and
  `highlighter` both call it. One transition function, no private copy, and the
  phase each caller wants stays its own choice. This replaces the earlier plan
  to have `highlighter` read `state_before` per row, which was phase-wrong.

### `in_code` stays boolean; the open length rides alongside (PQ-2, Minor)

Exposed state keeps `in_code` as a boolean — `highlight_structure_spec.lua:14,52,54`
assert against booleans with `assert.are.same`, so the earlier claim that
`highlighter.lua:140` was the only reader was wrong. The open fence's length
lives beside it as `code_fence_len` (nil when closed) so a closer shorter than
its opener does not close it.

**The fingerprint must encode the length.** `M.replace`
(`highlight_structure.lua:206-228`) takes a fast path on fingerprint equality and
reuses `structure.state_before` **verbatim**; it runs per keystroke via
`highlighter.lua:926`. `TOKENS.fence = "c"` is one token for every width, so
editing ``` to ```` in place keeps the fingerprint identical and serves stale
state for the rest of the buffer. Fence fingerprints become `"c" .. n`, so a
width edit invalidates correctly (ARCH-ORDER). The `token == TOKENS.fence`
equality test at `:173` becomes a prefix test.

### `parley.fence` is NOT adopted (PQ-3)

The earlier plan said deriving from `parley.fence` would "complete #200's sweep".
**That was wrong on both halves.** `fence.lua`'s own first line scopes it to
*tool bodies*: `open_len` matches `^(`+)([^`]*)$` — no leading whitespace — and
it closes only on an exactly-equal run. Prose needs CommonMark: indented fences
are legal inside list items, and a closer must be **at least** as long as its
opener, not exactly. Adopting it would silently stop recognising indented fences
and impose a tool-body rule on prose.

So the two grammars stay separate and the difference is documented at both ends.
Render-side tracking follows CommonMark; `fence.lua` keeps owning tool bodies.

## Done when

- an unmatched fence in one answer leaves every later exchange rendering clean
- a question containing a literal ``` renders correctly and does not corrupt the
  answer after it
- editing a fence's width in place does not serve stale state (the `M.replace`
  fast path invalidates)
- all four trackers reset at partitions, or say in-issue why they do not
- **each new test is verified by mutation** — reverting its change turns it red.
  A test that stays green with the fix reverted pins nothing (#215 lesson,
  `workshop/lessons.md`)

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim         design=0.5  impl=0.6
item: lua-neovim         design=0.15 impl=0.2
item: atlas-docs         design=0.05 impl=0.05
item: milestone-review   design=0.0  impl=0.2
design-buffer: 0.15
total: 1.86
```

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only.* Calibration doc reported **stale** by
`sdlc estimate-source` (ariadne#127); hours provisional.

- Raised from 1.57 after plan-quality round 1 grew the scope from one tracker to
  **four**, added the fingerprint change, and replaced the phase-wrong
  deduplication with an extracted `advance()`.
- **design-buffer 0.15, not 0.30** — corrected after estimate-quality round 1.
  v3.1 step 4 grants +15% "when the issue has a thorough plan doc", and this
  Spec qualifies (three named decisions, a four-row site enumeration, an 8-row
  Plan that survived a review round). More decisively, `baseline-v3.1.md`
  computes its whole calibration column with `est_design * 1.15` — using 1.30
  would price this row on a different multiplier than the baseline it claims to
  calibrate against. Same error was made on #215; the rule is baseline
  consistency, not whether a separate `workshop/plans/` file exists.
- **Two `lua-neovim` items**, split by risk: the structure/highlighter core
  (phase, transition extraction, fingerprint) versus the `outline` +
  `skills/review` containment sweep, which is mechanical.
- **design=0.5 on the core** sits inside v2.1 Step 3's discounted band: a spec
  that pre-resolves decisions takes ×0.2 on design, and ×0.2 of Lua/Neovim's
  1–3 is 0.2–0.6. It is at the *top* of that band, which #215's calibration
  supports (its judge measured design=1.2 at ~2× observed, closing 1.67 against
  2.23) — but the band, not the bespoke adjustment, is the justification.
- **`milestone-review` impl=0.2 is the scaled CEILING**, not "above the
  midpoint" as an earlier draft said: the table row is 0.2–0.5, which at ×0.40
  is 0.08–0.20. There is no headroom left in this item, so a close review that
  returns a Critical will overrun it. Recorded deliberately — #215 needed four
  boundary rounds and this plan has already burned one.
- **`impl=0.6` on the core is also at its scaled ceiling** (0.5–1.5 × 0.40) and
  must absorb both the property/fuzz suite and a serial revert/run/restore
  mutation loop over ~5 changes. That is the likeliest overrun.

## Plan

- [x] Fence fingerprint carries width (`"c"..n`); `:173`'s equality test becomes
      a prefix test — do this FIRST, the `M.replace` fast path depends on it
- [x] Extract `M.advance(state, token, …)`; builder calls it, `highlighter`
      calls it instead of its private walk at `:148-153`
- [x] Reset `in_code`/`code_fence_len`/`in_tool` at partition tokens,
      **pre-snapshot**, alongside the footer guard
- [x] CommonMark closer rule: `code_fence_len` tracked, closer must be >= opener
- [x] Sweep `outline.lua:31-33` and `skills/review/init.lua:166-172` for the same
      containment gap; fix or record why not
- [x] Tests by function, one strategy line each:
      `highlight_structure.build` — property/fuzz over arbitrary fence-run
      interleavings, invariant `in_code == false` at every partition row;
      `highlight_structure.replace` — fence-width-edit input class (PQ-2);
      the highlighter render seam via `tests/unit/highlighter_spec.lua` — without
      it site #2 ships untested
- [x] Verify by mutation: revert each change in turn, confirm a test goes red
- [x] Atlas: record the partition rule and the two-grammar split
- [x] Full suite green

## Log

### 2026-09-05
- 2026-09-05: closed — make test: 195 spec files, MAKE_EXIT=0 verified against make status; luacheck lua tests clean. Round 4 review previously died on auth (401 token revoked) producing verdict unknown and zero findings — that was a tooling failure, not a clean review, and BR-20/BR-21 were demoted past the round cap as a side effect; re-running so the round-3 fixes actually get reviewed rather than closing on a cap technicality. Round 3 fixes in dd5cb4e, all mutation-verified: BR-20 the exporter rewrite had dropped the blank lines the old gsub emitted incidentally so code blocks nested inside paragraphs (175 of 256 fence delimiters in this repos transcripts follow a non-blank line) — restored, plus an assertion that the div is not inside an unclosed paragraph, which goes red when the blank lines are removed. BR-21 the convention guard covered one of two arms since agent_info.resolve falls back to agent.system_prompt; now enumerated from config across system_prompts AND agents, verified by stripping an agents convention, with the unenforceable third arm (user-merged prompts, chat header system_prompt:) documented in README. BR-22 code_block_memo cost ~20x the toggles it replaced; four anchored prefix matches, 6.06ms to 0.84ms per 5000-line buffer, and since a perf refactor yields no behavioural red the EQUIVALENCE is pinned by a property test against classify across the grammar. BR-24 exporter uses its injected _parley handle. Earlier rounds: five then seven fence trackers swept behind one is_fence_delim and one code_block_memo, an arch rule in single_source_sweeps_spec so a new hand-rolled matcher fails, is_partition asserts on nil patterns making BR-2s silent no-op unrepresentable, and the mutation ledger is generated from the diff (config 1 red, copy 2, defaults 8, exporter 2, highlight_structure 82, outline 3, review 3). One suite run failed on helper.prepare_dirs check-then-act mkdir racing concurrent specs — not this diff, filed as #219. NOT verified live against a provider: the indentation convention is a model-compliance improvement measurable only once real answers arrive in the new format; it fails safe to the tested unindented path.; review verdict: FIX-THEN-SHIP

Filed from #217 gap 10. Operator proposed the hard-partition rule and correctly
predicted the render path was ignoring the boundary the structure already
tracks.

### 2026-09-05 — plan-quality round 1: 2 Critical, 3 Important

The gate reversed two parts of the plan and tripled the enumeration.

- **PQ-1** — deduplicating by having `highlighter` read `state_before` per row
  was **phase-wrong**: the snapshot is pre-transition, the accumulator
  post-transition, so they disagree on every fence-delimiter row. Replaced with
  an extracted `advance()`, and the reset's own phase is now stated.
- **PQ-2** — length-typed `in_code` would have made `M.replace`'s per-keystroke
  fast path serve stale state, since `TOKENS.fence` is one token for every
  width. Fingerprint now carries the width.
- **PQ-3** — `parley.fence` is scoped to *tool bodies* and is stricter than the
  render predicate (no leading whitespace, exact-length close). Adopting it
  would have dropped indented fences. **The "completes #200's sweep" framing was
  simply wrong**; the two grammars are now deliberately separate.
- **PQ-4** — the sweep named one site; `outline.lua` and `skills/review` carry
  their own non-derived trackers. Enumeration is four.
- **PQ-5** — the test plan was five prose cases naming no function under test.
  Now three functions with a strategy line each, including the render seam that
  pins the very site the plan calls "the one a site-level fix would miss".
- Minor — `highlighter.lua:140` was **not** the only `in_code` reader; the spec
  asserts booleans, which is why the exposed type stays boolean.

### 2026-09-05 — measurement-window caveat, carry this to close

**`sdlc actual` will under-report this issue for window reasons, not primitive
drift.** The claim commit (`499c227`, 12:12:38) opened the window, but the issue
was filed at 11:13 and the whole spec/plan — including the plan-quality round-1
revision that *raised the estimate from 1.57 to 1.86* — landed at 12:08. Design
is 0.805 of the 1.86 total (**43%**), and roughly an hour of it sits outside the
measured window.

This is AGENTS.md §2's "claim early" in miniature: the claim landed after the
design instead of at the start of it. Note it in the close `## Log` so this row
is not read as evidence for another downward recalibration of the design
column.

### 2026-09-05 — implemented

Commit `8274437`. Full suite green: **194 spec files, 0 failures, MAKE_EXIT=0**
(verified against `make`'s own status); luacheck clean across 347 files.

**The enumeration grew twice more during implementation.** The issue named one
tracker; self-review before the gate found the second (`highlighter`'s duplicate
walk); the gate found the third and fourth; and `outline.lua` turned out to have
**two** fence scans, not one — `build_code_block_memo` at `:8` as well as the
lazy fallback at `:31`. Final count: five. `is_partition()` is now exported so
the two outsiders share one definition rather than adding a fifth and sixth.

**Mutation-verified**, per the #215 lesson — each change reverted in turn:

| mutation | red |
|---|---|
| drop `in_code` reset in `reset_partition` | 2 |
| fence token loses its width (PQ-2) | 3 |
| CommonMark `>=` becomes "any closer" | 1 |
| `highlighter` skips `reset_partition` (site #2) | 1 |
| restored | 0 |

**The A/B/C fork was dissolved rather than decided.** A `💬:` inside a fence and
a partition that always wins are strictly incompatible — `picker_items_spec`
encoded the opposite decision deliberately. The operator's resolution was better
than any of the three options: ask the model to indent fenced blocks by two
spaces. The partition patterns are already anchored at column zero
(`user_pattern = "^" .. escape_pattern(user)`), so indented content never
matches and a properly formatted quoted transcript still nests. Two spaces, not
four — four makes it an indented code block and the ``` markers become literal.
Both paths are pinned: the unindented shape reads as a turn, the indented shape
nests. The convention is verified in code, not just requested in a prompt.

**Behaviour change worth calling out at review:** `skills/review`'s fence ranges
now close at turn boundaries, so a stray ``` no longer suppresses every review
marker to end-of-file. A fix, but it moves where markers appear in malformed
documents.

**side-quest — `refresh_goldens.lua` regenerated only half the goldens.** #198
added openai-wire goldens and a spec that verifies them without extending the
regenerator, so any prompt change refreshed `FIXTURES`, left `OPENAI_FIXTURES`
stale, and failed the suite with no supported fix but hand-editing JSON. Latent
until this issue touched the system prompt.

**Measurement caveat, as predicted at estimate time:** `sdlc actual` attributes
this window across #167, #217 and #218 together, and ~1h of the design landed
before the claim commit opened the window. Read the ratio with that in mind
rather than as primitive-table drift.

### 2026-09-05 — close refused: atlas

`sdlc close` refused with "no atlas/ changes", correctly. The Plan's atlas row
had been ticked by a bulk regex over the checkboxes rather than by doing the
work — the same shape of error as ticking a coverage box for an untested seam in
#215, and caught by a gate rather than by me.

`atlas/ui/highlights.md` now documents the partition rule, the single transition
function and its deliberate phase split, `is_partition` as the shared predicate,
the width-carrying fingerprint, the two separate fence grammars, and the
two-space indentation convention with the reason it is safe to degrade.

### 2026-09-05 — close review round 1: REWORK, 7 blocking

Commit `f1818ee`. Suite green: **194 spec files, MAKE_EXIT=0**; `luacheck lua
tests` clean across 347.

**The enumeration was wrong twice more.** This issue has now mis-counted its own
class three times: filed naming one tracker, self-review found a second, the
plan gate found the third and fourth, implementation found a fifth — and the
close review found a **sixth and seventh**. `outline.lua` had a *third* memo
build in `build_file_outline_items`, and the reviewer **reproduced the bug still
live in the tree picker** after the other two were fixed. `copy.lua` carried a
fourth shape. The lesson is not "count more carefully" — it is that a
copy-per-caller predicate cannot be swept by inspection. There is now one
`code_block_memo` and one `is_fence_delim`.

**The fix did nothing for configured prefixes (BR-2, Critical).** Both new
`is_partition` call sites passed `patterns()` with no config, so containment
disabled itself for any custom `chat_user_prefix` — reproduced by the reviewer.
`config` was already in scope at both sites.

**The convention broke its own enforcement (BR-4).** The review skill matched
`^```` at column zero, so it missed every fence the new prompt asks models to
indent. One commit added a convention and broke the code required to honour it.

**BR-3 recurred inside the rework for BR-3.** The review change had shipped with
no test — reverting it left all eight review specs green, despite mutation
verification being this issue's own Done-when. After fixing BR-2 I ran the
mutation check and the config fix came back **green**: unpinned in exactly the
way BR-3 described. Caught only by running the check rather than assuming it.
Eight mutations now verify.

Also: convention single-sourced across all five shipped prompts (BR-5),
`OPENAI_WIRE` shared by regenerator and verifier (BR-6), traceability mapped so
editing the atlas page runs the spec (BR-7), the atlas 3-space overclaim
corrected (BR-10), and outline's unreachable lazy fallback removed (BR-11).

### 2026-09-05 — close review round 2: REWORK, 2 blocking

Commit `bd92325`. Suite green: **195 spec files, MAKE_EXIT=0**; `luacheck lua
tests` clean.

**BR-14 (Critical) — the convention broke HTML export.** `exporter.lua` paired
fences with a document-wide gsub whose closer had to follow a newline directly,
so an indented closer never matched and the scan ran to the next flush-left
fence, swallowing the turns between. Reproduced by the reviewer. That is the
**second time in this issue** a convention this diff introduced broke code
required to honour it (the first was the review skill's column-zero predicate).

The demanded fix was the *rule*, and the home for it already existed:
`tests/arch/single_source_sweeps_spec.lua` now asserts a triple-backtick
**matcher** may live only in `is_fence_delim` (prose) or `fence.lua` (tool
bodies). My first version flagged seven files by also catching fence *emitters* —
writing fences is normal, hand-matching them is the defect.

**BR-15 — the mutation ledger was built from recall.** Three fixes reverted
green. The rule is to generate the ledger from the diff, which now happens:

| reverted | red |
|---|---|
| `config.lua` | 1 |
| `copy.lua` | 2 |
| `defaults.lua` | 8 |
| `exporter.lua` | 2 |
| `highlight_structure.lua` | 82 |
| `outline.lua` | 3 |
| `skills/review/init.lua` | 3 |

**The ledger itself nearly repeated the finding.** Three attempts reported
**all zeros** before I noticed: zsh does not word-split an unquoted `$SPECS`, so
every run passed seven paths as one filename and measured nothing. Zero was also
the result I wanted. The "sanity: nothing reverted → 0 red" control was useless
precisely because zero was the broken output too — a control that cannot
distinguish *passing* from *not running* is not a control. What caught it was
noticing that a whole-file revert of `highlight_structure` returning 0 is
impossible on its face.

Also taken, same family a second time: `is_partition` no longer defaults to
`patterns()`, it **asserts**. BR-2's silent no-op under a custom
`chat_user_prefix` is now unrepresentable rather than each caller's duty.

### 2026-09-05 — close review round 3: FIX-THEN-SHIP, 2 blocking

Commit `dd5cb4e`. Suite green: **195 spec files, MAKE_EXIT=0**; luacheck clean.

Both blocking findings were **regressions introduced while fixing round 2** —
a different failure mode from the unswept-instance pattern that dominated
rounds 1-2.

- **BR-20** — the BR-14 exporter rewrite dropped a guarantee the old gsub gave
  *incidentally*: it returned `"\n<div…</div>\n"`, and the line pass joined with
  single newlines, so the later `<p>…<div` cleanups stopped firing and code
  blocks nested inside paragraphs. The reviewer measured **175 of 256** fence
  delimiters in this repo's own transcripts as following a non-blank line — the
  majority shape. My three exporter tests asserted only that text survived.
  *Lesson: when replacing an implementation, enumerate what the old one
  guaranteed by side effect, not just what it was for.*
- **BR-21** — the convention guard covered one of two arms;
  `agent_info.resolve` falls back to `agent.system_prompt`. Now enumerated from
  config across both, with the unenforceable third arm (user-merged prompts,
  chat-header `system_prompt:`) documented in README with the reason.
- **BR-22** (Minor, but a real regression) — `code_block_memo` cost ~20× the
  toggles it replaced because `is_partition` ran the full classifier per line.
  Four anchored prefix matches: **6.06ms → 0.84ms** per 5000 lines. A perf
  refactor yields no behavioural red, so the thing needing a pin was the
  **equivalence** — a property test now compares the fast path to `classify`
  across the grammar, including indented, mid-line and quoted turn markers.
- **BR-24** — exporter reached for `require("parley")` despite the module's
  injected `_parley` handle.

**One full-suite run failed and was NOT this diff.** `helper.prepare_dir` is
check-then-act around `mkdir`, so concurrent `setup()` calls race and the loser
raises E739. The spec passed in isolation, the path existed and was a directory,
and a clean re-run was green. Filed as **#219** rather than dismissed — "re-run
until green" is how a real race gets normalised.
