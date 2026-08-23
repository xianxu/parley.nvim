---
id: 000203
status: working
deps: []
github_issue:
created: 2026-08-21
updated: 2026-08-22
estimate_hours: 2.18
started: 2026-08-22T17:34:39-07:00
---

# chat_parser: recover from a malformed or truncated tool fence

## Problem

A tool body whose fence is never closed makes `chat_parser` treat everything up
to the next unrelated bare fence as body content. Every `💬:` in between stops
starting an exchange, so the rest of the chat collapses into one exchange —
silently. Exchange starts feed `exchange_anchors` identity, which drives #200's
destructive fold clear, so the folds go with it.

Measured on the shape below: 2 exchanges where the pre-#200 parser gave 3.

    💬: q1
    🤖: [A]
    📎: r id=1
    ```                 <- opener, never closed
    never closed
    💬: q2              <- swallowed
    🤖: [A]
    ```                 <- unrelated bare fence, read as this body's close
    💬: q3              <- swallowed

**This is unreachable from anything parley writes.** `fence.for_content` picks a
fence strictly longer than the longest backtick run in the content, so a
parley-written body provably cannot close its own fence and the first matching
close is always the correct one. The shape requires input parley did not
produce: hand-edited, truncated mid-write, or pasted from elsewhere.

Deferred from #200 M2 (operator decision, 2026-08-21) after three local
heuristics each failed: bounding the search at the "next structural boundary" is
circular, because the boundary may itself be inside the body; and declining to
suppress when the body holds a question defeats M2's headline case, since
`read_file` on a transcript produces exactly that with a minimum-length fence.

## Spec

- A malformed or truncated tool fence must not silently swallow later exchanges.
- Well-formed transcripts keep today's behaviour exactly: the first matching
  close is correct and in-body markers are content (#200 M2).
- Failure on malformed input should be visible rather than silent — the operator
  chose over-forking as the preferred degradation, but only where it does not
  cost the well-formed case.

## Done when

- [x] The shape above yields 3 exchanges, and #200's adversarial fixture still
      yields 2.
- [x] Well-formed bodies are unaffected — measured by BEHAVIOUR, not by leaving
      fixtures byte-identical: `fold_tool_transcript.md` unchanged, and the
      live-corpus audit (`fold_invariants_spec` over every tracked transcript)
      still clean. `fold_adversarial.md` DOES change: its read_file body gains
      the `%5d  ` prefix that tool actually emits, which is a fidelity
      correction, not a relaxation — its grep body already models the real
      prefix and is untouched.
- [x] `tests/unit/chat_parser_tools_spec.lua`'s pending case is enabled.

## Plan

- [x] Decide the model — settled by experiment, and NOT the fence-depth pass
      this step guessed at. See the Revisions section below.
- [x] **Name the kind set once.** "Column-0 structural marker" is
      `📝/🔧/📎/💬/🤖/🌿/🔒` — the set `chat_parser.lua:288` already calls
      structural. Export it from one place and derive the predicate from it; do
      not hand-list kinds at the call sites. The experiment used only
      `user`+`assistant`, so widening to the full set must be re-measured
      against the corpus before this is ticked (expected no-op for well-formed
      input, since prefixed tool output has no column-0 markers at all).
- [x] **All three `fence.scan` consumers take the rule**, not just
      `chat_parser`. `answer_structure` and `fold_projection` resolve body
      extent from the same scan; leaving them on the old close search re-creates
      the three-way divergence #200 collapsed, and desyncs folds from structure
      on exactly the malformed input this issue is about. The predicate is part
      of the scan contract, supplied from `highlight_structure.classify`.
- [x] Implement in `parley.fence`: a tool body's close search stops at a
      column-0 structural marker, so a body can never span one.
- [x] **Unit-test `fence.scan` directly** on the returned `bodies`/`markers`
      model, not through a downstream exchange count. Adversarial class: openers
      that never close, and closes belonging to another pair.
- [x] **Guard the producer-side invariant this rests on**, derived from
      `tools.BUILTIN_NAMES` + `OPTIONAL_NAMES` so a future builtin is covered by
      construction — the first draft hand-listed four of ten and missed
      `emit_definition`. Run each registered read-shaped tool against a fixture
      full of column-0 markers and assert no output line begins with one.
      **Known exception, stated not hidden:** `grep`/`ack`/`ls`/`find` splice raw
      stderr after a prefixed first line, so a hostile error message can carry a
      column-0 marker. That degrades to over-forking, which is the Spec's stated
      preference.
- [x] **Rule on `chat_parser`'s second fence tracker** (`chat_parser.lua:456`,
      `cb_state.tool_fence_len`). It tracks body *end* for content-block
      accumulation, independent of `fence.scan`, and will not stop at a
      structural marker. Prove the two cannot disagree, or make it derive from
      the scan — a second grammar for the same fence is what #200 removed. Add a
      test pinning agreement either way.
- [x] Re-point the two tests encoding the unreachable shape: give
      `resumes structural parsing after the body closes` and `keeps a longer
      nested fence inside the body` the `%5d  ` prefix their tool actually
      emits (the correction their sibling at `chat_parser_tools_spec.lua:382`
      already models for `grep`), and the same for `fold_adversarial.md`'s
      read_file body. Coverage is re-pointed, not deleted: add a case pinning
      the reachable version — a column-0 marker from pasted or hand-edited
      content forks, visibly.
- [x] Enable the pending case; add the truncated-mid-write shape
- [x] Re-run the live-corpus audit
- [x] Atlas: the fence grammar's new rule and the producer-side invariant it
      depends on. The surface is not singular — `fence` appears in
      `atlas/chat/parsing.md`, `atlas/chat/format.md` and
      `atlas/providers/tool_use.md` — and the producer invariant is new surface,
      not an edit to an existing line.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim             design=0.20 impl=0.32
item: lua-neovim             design=0.20 impl=0.36
item: cross-cutting-refactor design=0.10 impl=0.16
item: atlas-docs             design=0.10 impl=0.06
item: milestone-review       design=0.00 impl=0.14
item: scope-pivot            design=0.30 impl=0.10
design-buffer: 0.15
total: 2.18
```

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only.* (`design-buffer: 0.15` is a rate, not hours.)

Derivation:

- **lua-neovim (the rule)** — the close-search change in `fence.scan`, the
  kind-set export, and wiring all three consumers. v2 design pick 1.0 (low end
  of 1–3: the model, the kind set, and the consumer list are all settled in the
  Plan), ×0.2 Step-3 → 0.20. v2 impl pick 0.8 of 0.5–1.5, ×0.40 → 0.32. The
  experiment already wrote a working version of the one-caller form, which is
  why impl sits below the midpoint despite touching three consumers.
- **lua-neovim (the guards)** — the registry-driven producer-invariant
  integration test, direct `fence.scan` unit tests, the re-pointed fixtures, and
  the new reachable-case test. Design 1.0 ×0.2 → 0.20. Impl pick **0.9, above
  the midpoint**: the producer guard has to drive real tools against a fixture
  and reason about the stderr-splice exception, which is the fiddliest part of
  the issue and the part no prior work exists for. ×0.40 → 0.36.
- **cross-cutting-refactor** — the second fence tracker
  (`cb_state.tool_fence_len`): prove it cannot disagree with `fence.scan`, or
  make it derive. Touches `chat_parser`'s content-block path, which is a
  different seam from the marker path. v2 design pick 0.5 of 0.2–1, ×0.2 → 0.10;
  impl pick 0.4 of 0.2–0.5, ×0.40 → 0.16. Priced as prove-or-derive; if it must
  derive, this is the item that grows.
- **atlas-docs** — the fence grammar's atlas entry gains the new rule and the
  producer-side invariant it depends on. Design 0.10, impl 0.15 ×0.40 → 0.06.
- **milestone-review** — one mandatory close review. Design 0.0; impl 0.35 of
  0.2–0.5, ×0.40 → 0.14.
- **scope-pivot** — the experiment that decided the model against the Plan's own
  guess, the round-1 gate, and recovering the issue file after a span-edit
  corrupted it. All inside the `sdlc actual` window, so priced. Design 0.30 of
  0.2–0.5 undiscounted — deciding the model *was* the design; impl 0.25 ×0.40 →
  0.10.
- **Step 2.5 (library availability)** — n/a: no external dependency; the change
  is internal grammar plus tests.
- **Step 5 familiarity ×1.0** — `fence`, `chat_parser`, `tool_folds` and
  `fold_projection` were all read closely and a working prototype was run before
  estimating.
- **Step 6 buffer +15%** — the ×0.2 discount was applied to the three
  code primitives, so the v2.1 rule of thumb halves the buffer.

Recompute: (0.20+0.20+0.10+0.10+0.00+0.30) × 1.15 + (0.32+0.36+0.16+0.06+0.14+0.10)
= 0.90 × 1.15 + 1.14 = 1.035 + 1.14 = **2.18**

## Revisions

### 2026-08-22 — the model is a one-line rule, not a fence-depth parser

**Reason.** Plan step 1 was open ("most likely a real fence-depth pass"). An
experiment settled it the other way, and disproved the premise the deferral
rested on.

**Delta.** #200 rejected "decline to suppress when the body holds a question"
because *"`read_file` on a transcript produces exactly that with a
minimum-length fence"*, reporting two M2 tests red when implemented. That
premise is false: `read_file` emits `string.format("%5d  %s", n, line)`, so a
marker it reads is never at column 0. Every registered tool prefixes its success
output — `grep`/`ack` with `file:line:`, `chat_history_search` with
`{label}/path:line:`, `ls`/`find` with paths, and
`edit_file`/`propose_edits`/`write_file` return status messages. There is no
external tool path.

The tests that went red model `read_file` *without* its prefix. Their sibling
one case below models `grep` faithfully — prefixed — and passes untouched.
`fold_adversarial.md` carries the same split: grep body prefixed, read_file body
not.

So the ambiguity #200 named — *"an unclosed body is locally indistinguishable
from a legitimate body quoting a transcript"* — dissolves: **that legitimate
body is not reachable from parley.** The only remaining source of a column-0
marker inside a body is hand-edited or pasted content, which is what `## Problem`
already identifies as the malformed case's origin. Both readings point the same
way, and over-forking is the degradation the Spec already records as preferred.

Consequence: the fence-depth pass is unnecessary, and the two red tests are the
deliverable's cost rather than an obstacle to it.

### 2026-08-22 — plan gate round 1: scope corrections

Three blocking findings, all scope gaps rather than model errors; the model
stands.

- **All three `fence.scan` consumers** take the rule. The first draft passed the
  predicate from one caller, leaving `answer_structure` and `fold_projection` on
  the old close search — three consumers, two grammars, folds desynced from
  structure on precisely the malformed input at issue. That is the divergence
  #200 collapsed.
- **The kind set is named** and sourced from the existing structural set rather
  than hand-listed. It decides which tests survive, so leaving it as prose left
  the deliverable undefined. The experiment's narrower `user`+`assistant` set
  must be re-measured when widened.
- **Done-when no longer contradicts the Plan.** It required
  `fold_adversarial.md` unchanged while the Plan corrects that fixture; the
  criterion is now behavioural, with the fixture change named as the fidelity
  correction it is.

Two factual corrections to the Revision above, found by the gate and verified:
parley registers **nine** builtins plus optional `ack` — not eleven — and
`emit_definition` was never checked; and `grep`/`ack`/`ls`/`find` splice raw
stderr after their prefixed first line, so the invariant is not total. It holds
on every success path, which is what the parser depends on; the error path
degrades to over-forking. Both are now Plan steps rather than assumptions.

## Log

### 2026-08-21

Filed from #200 M2's boundary review (BR-43 shape B). Full reasoning and the
three failed heuristics are in #200's `## Log`; the pending test carries a
pointer here.

### 2026-08-22 (experiment — model decision and the fold risk)

Ran the discriminator #200 rejected on a throwaway patch; tree restored, nothing
committed.

**Does the simple rule work?**

| case | before | after |
|---|---|---|
| pending `unclosed body + later bare fence` | 2 exchanges | **3** |
| BR-43 marker in an ordinary fenced block | 3 | 3 |
| transcript format shown in a plain block | 3 | 3 |
| `fold_invariants_spec` (122 corpus files + 4 fixtures) | pass | **pass** |
| full suite | 187 pass | 185 pass, 2 fail |

A third test failed identically until its fixture was given the `%5d  ` prefix —
then it passed. That is the cleanest single result: the shape, not the rule, was
wrong.

**Does over-forking cost folds?** This was the stop-and-escalate risk: exchange
starts feed `exchange_anchors` identity, which drives #200's destructive fold
clear. Probed through the production path (`hydrate_window` → `zM`) on a buffer
holding the malformed body followed by a well-formed exchange with foldable
blocks:

| | exchanges | questions folded | foldable blocks | folded |
|---|---|---|---|---|
| baseline | 2 (bug) | 0 | 3 | 3 |
| with rule | 3 (fixed) | 0 | 3 | **3** |

No fold loss. Corroborated by `tool_folds_spec` passing with the patch — its 14
cases cover the destructive paths directly, including *"reinstalls identity
after the chat gains an exchange"*, which is what over-forking does.

**Limit, stated rather than buried:** no bespoke incremental-reconcile test was
built for the forked shape; the claim rests on `tool_folds_spec`'s existing
drift/streaming coverage passing. Tightening that is a plan step, not a blocker.

### 2026-08-22 (implementation)

All plan steps landed; suite green at 188 spec files.

- **The rule**, in `fence.scan`: a tool body's close search stops at a column-0
  structural marker. All three consumers pass the predicate
  (`chat_parser`, `answer_structure`, `fold_projection`) — leaving one out was
  the round-1 gate finding, and would have re-created #200's divergence.
- **The kind set** is `highlight_structure.STRUCTURAL_KINDS`
  (`📝/🔧/📎/💬/🤖/🌿/🔒`; `reasoning` deliberately absent — 🧠: is terminated
  *by* a structural marker, it is not one). Widening from the experiment's
  `user`+`assistant` was re-measured as the Plan required: **the corpus audit is
  unaffected** (`fold_invariants_spec` green throughout), and the cost is five
  additional unit fixtures, all of one class.
- **Seven tests broke, and they split two ways.** Five had the marker as
  incidental colour — their subject is a final-line close or a nested fence — so
  they got the `%5d  ` prefix their tool actually emits and their point is
  preserved. Two had the marker as their *subject* and inverted: their
  expectation was `accept a column-0 marker inside a body`, on the stated
  premise *"because tool output quotes transcripts"*. That premise is what this
  issue refutes. Both were re-pointed rather than deleted — each now pins the
  reachable prefixed case, and a new sibling pins the column-0 case forking.
- **The producer guard** (`tests/integration/tool_output_prefix_spec.lua`)
  derives its subjects from `tools.BUILTIN_NAMES` + `OPTIONAL_NAMES`.
- **The second fence tracker** (`cb_state.tool_fence_len`) does not disagree
  with `fence.scan` — the fork finalizes the block before the later fence is
  reached — and that now has a test rather than an argument.

**A vacuous guard I wrote and caught.** The producer guard passed on its first
run *and* passed with `read_file`'s `%5d  ` prefix deleted. `tools.get` returns
nil without `register_builtins()`, and the guard's `if not def then return end`
skipped every case silently. It now registers the builtins, and refuses to skip
a non-optional tool. Re-verified: green on HEAD, and with the prefix removed it
fails with `read_file emitted a column-0 user marker`. Worth recording because
the guard was written *by* someone who had just spent a day on exactly this
failure mode.

**A file-corruption mistake, recovered.** A span edit computed
`s[index("## Plan"):index("## Revisions")]`, but the literal `## Revisions`
appeared inside the Done-when text I had just inserted — so the index came back
*before* `## Plan`, the slice was empty, and `str.replace("", ...)` inserted the
new text between every character: 409,224 lines. Restored from git and redone
with an exact-block helper that refuses on anything other than one match. This
is the second instance this session (ariadne#203 silently swallowed a
`## Done when` the same way), so it is now a rule in `workshop/lessons.md`
rather than a note.
