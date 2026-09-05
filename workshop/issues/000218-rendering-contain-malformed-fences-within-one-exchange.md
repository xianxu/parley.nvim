---
id: 000218
status: open
deps: []
github_issue:
created: 2026-09-05
updated: 2026-09-05
estimate_hours:
---

# Rendering: contain malformed fences within one exchange

## Problem

Surfaced in the #206 release shakedown (#217 gap 10). When a model returns an
unmatched ``` fence, the damage does not stay in that answer — the rest of the
document renders as code. `<M-q>` quoted text is also sometimes wrapped in a
fence incorrectly, likely the same root cause.

The operator's diagnosis was right and the code confirms it: **the render path
does not consult the exchange boundary that `exchange_model` already owns.**

### Two defects, both in `lua/parley/highlight_structure.lua`

**D1 — `in_code` is never reset at an exchange boundary.** The state machine
resets sibling state at every partition but leaves the fence flag standing:

```lua
if token == TOKENS.user then
    state.in_question = true
    state.in_reasoning = false          -- reset
elseif token == TOKENS.assistant or token == TOKENS["local"] or token == TOKENS.branch then
    state.in_question = false
    state.in_reasoning = false          -- reset
```

Neither branch touches `state.in_code`. So one unmatched fence flips it and it
stays flipped for **every subsequent question and answer in the file**. The
footer guard has the same shape — it resets `in_question` and `in_reasoning`
past `footer_start0`, not `in_code`.

**D2 — the fence predicate is a fifth, non-derived implementation.** #200
consolidated the fenced-block grammar into `lua/parley/fence.lua` precisely
because it "had three independent implementations", and pointed four consumers
at it: `fold_projection`, `chat_parser`, `answer_structure`, `tools/serialize`.
`highlight_structure` was missed. It still matches loosely:

```lua
elseif line:match("^%s*```") then kind = "fence"
...
if token == TOKENS.fence then
    state.in_code = not state.in_code   -- naked toggle
```

A bare toggle on any >=3-backtick run has no same-length closing rule, so a
nested or longer fence desyncs it — the exact failure `fence.lua`'s header
warns about ("every consumer downstream shifts by one fence"). ARCH-DRY: the
module exists, this consumer does not derive from it.

## Spec

**`💬:` / `🤖:` at line start are hard partitions.** Fence state resets at every
boundary, so a malformed answer can corrupt at most its own section. This is
containment by *position*, not by fence-matching — which is the point: ``` may
legitimately appear inside a question when the user is asking about fences, so
no amount of smarter fence-matching can substitute for the boundary reset.

Two changes:

1. Reset `state.in_code` (and `state.in_tool`, which rides on it) on every
   partition token — `user`, `assistant`, `local`, `branch` — and past the
   footer, alongside the resets already there.
2. Point `highlight_structure` at `parley.fence` so all five consumers derive
   the grammar from one source, completing #200.

**Explicitly rejected: a zero-width space after `💬:`.** It was considered to
make the marker more unique. It costs the property Tier 1 leads with — the
transcript is plain markdown the user can freely edit — since a hand-typed
`💬:` would carry no ZWSP and the parser must accept both anyway. No uniqueness
gained, editability spent. The positional reset achieves the containment alone.

**`exchange_model` already has the boundary** — it is documented as "the
size-based positional model, single source of truth for buffer layout;
everything is a block". This issue is not adding a boundary, it is making the
render path honour the one that exists. Confirm during planning whether
`highlight_structure` should consume `exchange_model` directly or just reset on
the same tokens; the latter is smaller and may be sufficient.

## Done when

- an unmatched fence in one answer leaves every later exchange rendering
  correctly
- a question containing a literal ``` renders correctly, and does not corrupt
  the answer after it
- `highlight_structure` derives its fence predicate from `parley.fence`
- a fixture suite of deliberately malformed transcripts asserts containment
  per-exchange, not merely "the file still parses"
- **at least one** unbalanced fence per exchange is contained (see scope note)

## Plan

- [ ] Fixture suite: unmatched opener in an answer; unmatched closer; a literal
      ``` inside a question; nested/longer fences; a fence opened in a tool
      body and never closed. Each asserts the NEXT exchange renders clean
- [ ] Reset `in_code`/`in_tool` on partition tokens and past the footer
- [ ] Point `highlight_structure` at `parley.fence` (completes #200's sweep)
- [ ] ~~Re-test `<M-q>` quoting~~ — **split out**, unrelated (see Revisions)
- [ ] Check whether `fold_projection` and `outline` share the containment gap —
      they consume the same structure and would show the same symptom
- [ ] Atlas: record the partition rule wherever buffer layout is described

## Scope note — one mismatch per exchange is enough

Containment does **not** require resolving arbitrary nesting. Operator's call:
patching a single unbalanced fence per exchange already removes the observed
damage, and the combinatorics of multiple mismatches are not worth chasing.

The boundary reset gives this for free — whatever `in_code` depth a section ends
in, the next partition clears it. So "N mismatches" is not a separate case at
the render layer; it only matters for a future *write-time sanitizer*, which is
a different issue. Fixtures should still include a multi-mismatch case, but only
to assert **containment**, not correct interpretation of the broken section
itself. A malformed answer is allowed to render wrong; it is not allowed to make
the next one render wrong.

## Log

### 2026-09-04

Filed from #217 gap 10. Operator proposed the hard-partition rule and correctly
predicted the render path was ignoring `exchange_model`'s boundary; reading the
state machine confirmed it and turned up D2 as well — #200 consolidated four
fence consumers onto `fence.lua` and left the fifth behind.

Containment must be positional because ``` is legitimate content inside a
question. That is also why the ZWSP marker idea is recorded as rejected rather
than deferred: it addresses uniqueness, which is not the failing property.

## Revisions

### 2026-09-04 — `<M-q>` fence copying split out; it is not this bug

The Problem section originally guessed the `<M-q>` mis-fencing shared this root
cause. **It does not.** Operator described it precisely — the quote *copies the
fence lines themselves* into the quoted text — and the cause is in
`lua/parley/drill_in.lua`, not the render layer:

`paragraph_top` scans backwards for the enclosing prose block and stops only on
`is_blank` or `is_boundary_line` (a configured turn prefix). A ```` ``` ```` line
is neither, so the scan walks straight through it and the fence delimiters land
inside the snippet. Nothing to do with `in_code` or `highlight_structure`.

Tracked as #217 item 12. Fixing it here would have coupled two unrelated modules
behind one verdict.
