---
id: 000218
status: working
deps: []
github_issue:
created: 2026-09-05
updated: 2026-09-05
estimate_hours: 1.96
started: 2026-09-05T12:12:38-07:00
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
design-buffer: 0.30
total: 1.96
```

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only.* Calibration doc reported **stale** by
`sdlc estimate-source` (ariadne#127); hours provisional.

- Raised from 1.57 after plan-quality round 1 grew the scope from one tracker to
  **four**, added the fingerprint change, and replaced the phase-wrong
  deduplication with an extracted `advance()`.
- **Two `lua-neovim` items**, split by risk: the structure/highlighter core
  (phase, transition extraction, fingerprint) versus the `outline` +
  `skills/review` containment sweep, which is mechanical.
- **design=0.5 on the core** follows #215's calibration: its judge measured
  design=1.2 at ~2× the observed time and it closed 1.67 against 2.23. The
  design here is settled by this revision.
- **`milestone-review` impl=0.2** above the 0.14 midpoint — #215 needed four
  boundary rounds, and this plan has already burned one.

## Plan

- [ ] Fence fingerprint carries width (`"c"..n`); `:173`'s equality test becomes
      a prefix test — do this FIRST, the `M.replace` fast path depends on it
- [ ] Extract `M.advance(state, token, …)`; builder calls it, `highlighter`
      calls it instead of its private walk at `:148-153`
- [ ] Reset `in_code`/`code_fence_len`/`in_tool` at partition tokens,
      **pre-snapshot**, alongside the footer guard
- [ ] CommonMark closer rule: `code_fence_len` tracked, closer must be >= opener
- [ ] Sweep `outline.lua:31-33` and `skills/review/init.lua:166-172` for the same
      containment gap; fix or record why not
- [ ] Tests by function, one strategy line each:
      `highlight_structure.build` — property/fuzz over arbitrary fence-run
      interleavings, invariant `in_code == false` at every partition row;
      `highlight_structure.replace` — fence-width-edit input class (PQ-2);
      the highlighter render seam via `tests/unit/highlighter_spec.lua` — without
      it site #2 ships untested
- [ ] Verify by mutation: revert each change in turn, confirm a test goes red
- [ ] Atlas: record the partition rule and the two-grammar split
- [ ] Full suite green

## Log

### 2026-09-04

Filed from #217 gap 10. Operator proposed the hard-partition rule and correctly
predicted the render path was ignoring the boundary the structure already
tracks.

### 2026-09-04 — plan-quality round 1: 2 Critical, 3 Important

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
