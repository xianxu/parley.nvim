# Boundary Review — parley.nvim#203 (whole-issue close)

| field | value |
|-------|-------|
| issue | 203 — chat_parser: recover from a malformed or truncated tool fence |
| repo | parley.nvim |
| issue file | workshop/issues/000203-chat-parser-recover-from-a-malformed-or-truncated-tool-fence.md |
| boundary | whole-issue close |
| milestone | — |
| window | 5c65036ec43c303681e7969d7bb479b4c9a2c3e5..229d0fba0ee3c878268bf49f3812e0a64319eed1 |
| command | sdlc close --issue 203 |
| reviewer | claude |
| timestamp | 2026-08-22T18:38:31-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The model #203 lands on — bound the tool-body close search at a column-0 structural marker, safe because every tool prefixes its output — is correct, well-argued, and the producer-side guard that carries its weight is genuine (I broke `read_file`'s `%5d  ` prefix in a scratch tree and watched it go red). But the bound was placed in the **shared** `close_of` helper, so it also applies to the depth-establishing search for *ordinary* fenced blocks. The result is a verified regression on `tests/fixtures/fold_marker_in_prose.md` — the fixture that exists specifically to carry #200 BR-43's teeth: a `📎:` quoted inside a plain ```` ```text ```` block is now parsed as a real `tool_result` block whose body swallows the answer's closing sentence, and `fold_projection` folds it away. The full suite (unit + integration + arch) is green, so nothing catches it. That blocks the boundary; the fix is two tokens plus a regression test, and I verified a candidate keeps every #203 test green.

## 1. Strengths

- **The model decision is genuinely better than the plan's own guess.** The Revision that killed the fence-depth-parser approach by measuring `read_file`'s actual `%5d  ` format, rather than trusting #200's recorded rationale, is exactly the right instinct — and the lessons entry generalizes it correctly.
- **The producer guard is not vacuous.** I verified by reverting: in a scratch copy with `string.format("%5d  %s", n, line)` → `line`, `tests/integration/tool_output_prefix_spec.lua` fails with `read_file emitted a column-0 user marker` while the other four stay green. The `before_each` `tools.register_builtins()` and the refuse-to-skip-a-non-optional-tool branch are both load-bearing.
- **The re-pointed tests preserve their subject rather than deleting coverage.** `chat_parser_tools_spec.lua:361` (prefixed → content) plus the new `:387` (column-0 → forks) is the right two-sided pin, and `fold_projection_spec.lua:165/178` mirrors it.
- **`fence_spec.lua:207-252` tests the rule where it lives** — on `scan`'s own `bodies`/`markers` model, including "a refused body must not also lose its marker". That is the PQ-5 ask, delivered.
- **The known exception is stated, not hidden** (stderr splice → over-forking), in the spec header, `fence.lua`, and `atlas/providers/tool_use.md`.

## 2. Critical findings

**C1 — `lua/parley/fence.lua:140-146`: the #203 bound leaks into the ordinary-block depth search, re-creating BR-43.**

`close_of` serves two callers: the tool-body close search (line 154) and the "any other depth-0 opener skips to its own close" search (line 163). The `is_structural` guard was added inside the shared helper, so an *ordinary* fenced block whose content holds a column-0 structural marker never finds its close, never establishes depth, and the scan walks into it — the precise failure the module's own docstring names ("a `📎:` written inside an ordinary fenced block is not a marker at all, and treating it as one makes the enclosing block's CLOSER look like the body's opener").

Verified against base `5c65036` on the tracked fixture:

```
tests/fixtures/fold_marker_in_prose.md   (12 ```text / 13 📎: read_file id=example / 14 ``` / 16 prose)
  BASE: ex1 answer = [ text 10..16 ]
  HEAD: ex1 answer = [ text 10..12, tool_result 13..16 ]     <-- quoted marker became a real tool block
  fold_projection.desired_folds -> fold kind=tool_result rows 13..16
```

So line 16 ("That prefix is only structural at the top level.") is real answer prose now hidden inside a fabricated tool fold. A base-vs-HEAD `fence.scan` sweep over all 25 tracked transcripts + fixtures + `docs/*.md` found exactly this one divergence (`markers=[+13]`), and `fold_invariants_spec` cannot see it — its oracle only asserts "no question folded" and "foldable blocks fold", and a *spurious* foldable block satisfies both.

Note the safety argument does not extend here: it covers tool *output*, but this branch is assistant *prose*, and a model answering "what does a parley transcript look like?" emits column-0 markers freely.

Fix sketch (verified: `fence_spec`, `chat_parser_tools_spec`, `fold_projection_spec`, `answer_structure_spec`, `chat_parser_section_lines_spec`, `parse_chat_spec` all green, and the fixture returns to `text 10..16`):

```lua
local function close_of(open_len, from, bounded)
    for row = from, #lines do
        if M.closes(lines[row], open_len) then return row end
        if bounded and is_structural and is_structural(lines[row], row) then return nil end
    end
    return nil
end
...
local close = body_len and close_of(body_len, row + 2, true)  -- tool body: bounded (#203)
...
local close = open_len and close_of(open_len, row + 1)        -- ordinary block: depth, unbounded
```

Add the regression test at both levels: `fence.scan` returns empty `markers` for the `fold_marker_in_prose.md` shape, and `parse_chat` yields one `text` block for ex1.

## 3. Important findings

**I1 — `tests/integration/tool_output_prefix_spec.lua:66,71-79`: the guard is not registry-derived, and the atlas says it is.** The per-tool assertions iterate a hand-listed `READ_INPUTS` of five (`read_file`, `grep`, `ack`, `ls`, `find`); `registered()` is used only for `assert.is_true(#registered() >= 9)`, which **passes when the registry grows**. So `atlas/providers/tool_use.md` ("derives its subjects from `tools.BUILTIN_NAMES` + `OPTIONAL_NAMES`, so a new builtin is covered by construction") and the Plan step are both false. The unguarded five include `chat_history_search` — the one tool that greps chat transcripts, i.e. the likeliest producer of a column-0 marker — plus `emit_definition`, `edit_file`, `write_file`, `propose_edits`. Fix: drive the loop off `registered()`, with an explicit `NON_ECHOING` set (documented reason per tool) rather than an implicit omission, so a new builtin fails until someone classifies it.

**I2 — `lua/parley/answer_structure.lua:7-16`: the kind set is still restated by hand, in the same file that now imports `is_structural_kind`.** `BOUNDARY` enumerates exactly `STRUCTURAL_KINDS` plus `reasoning`. The Plan step was "Name the kind set once … do not hand-list kinds at the call sites"; the sweep stopped at the predicate. This is the drift class `fold_projection.lua:12-16` already warns about for `FOLDABLE` ("Two hand-maintained key sets would drift, and the drift is silent and total"). Fix: derive — `local BOUNDARY = { reasoning = true }; for k in pairs(hs.STRUCTURAL_KINDS) do BOUNDARY[k] = true end` (ARCH-DRY, ARCH-PURPOSE).

**I3 — `atlas/chat/format.md:12` not updated, though the ticked Plan step named it.** It states the fence grammar owns "the rule that markers inside a body are content" — now false for a column-0 structural marker. `parsing.md` and `tool_use.md` were updated; the third named surface was not.

**I4 — the corpus-audit evidence cited in Done-when ran over a silently shrunk corpus.** `workshop/parley/2026-05-03.22-29-53.828_global-warming-overview.md` is tracked at HEAD but deleted in the working tree, so `fold_invariants_spec`'s `filereadable` skip (`fold_invariants_spec.lua:60-62`) drops it, and the `>= 8` floor can't notice; the two untracked replacements aren't picked up either. I restored the file from HEAD and confirmed it shows **no** base-vs-HEAD scan divergence, so it is not hiding a failure — but the evidence claim ("over every tracked transcript") is stronger than what ran, and closing with an unstaged deletion of a tracked corpus file is the "a test that skips is not a test that passes" lesson this very issue wrote. Resolve the tree state (restore or stage deliberately) before close.

## 4. Minor findings

- `lua/parley/fence.lua:115-125` — the docblock now carries two `@param lines` and two `@param is_tool_marker` entries, with `@param`s after `@return`s. Collapse to one block.
- `lua/parley/fold_projection.lua:140-141` — a per-line `require(...)` plus a **second** full `classify(line, patterns)` for lines the scan's `is_tool_marker` already classified, inside a function whose own comment (lines 108-113) justifies avoiding full classification because it "runs per streamed chunk". Hoist the module and reuse one `kinds` memo.
- `tests/integration/tool_output_prefix_spec.lua:79` — `pairs(READ_INPUTS)` makes test registration order nondeterministic; use a sorted array.
- `workshop/plans/203-experiment.patch` — 1760 lines of which ~1690 are the full text of a deleted corpus transcript; applying it would delete `workshop/parley/…global-warming-overview.md`. Prune to the experiment hunks or drop it (the Revisions section already records the decision). It also doesn't follow the `NNNNNN-slug-plan.md` convention for `workshop/plans/`.
- `highlight_structure.STRUCTURAL_KINDS` / `is_structural_kind` have no direct unit test (`tests/unit/highlight_structure_spec.lua` untouched) despite being the set that decides the rule and the deliberate `reasoning` exclusion.
- `fence.scan`'s `is_structural` is documented "Required in practice" but optional in the signature; a fourth caller silently gets the pre-#203 search.

## 5. Test coverage notes

The suite is green (`make lint`, `make test-unit`, `make test-integration` — 0 failures, luacheck 0/340). The gap is shape-selection, not count:

- **Nothing covers a column-0 structural marker inside an ordinary fenced block.** Every new and re-pointed case puts the marker inside a *tool body*. `fold_marker_in_prose.md` holds the shape but its oracle is blind to it — that is why C1 shipped green.
- The `answer_structure`/`fold_projection` consumers are only tested through the tool-body path, so the shared-`close_of` leak has no assertion anywhere.
- `does not let the second fence tracker swallow the forked exchanges` (`chat_parser_tools_spec.lua:568`) is coupled to the main fix — its first assertion (`3 exchanges`) already fails at base, so it pins the outcome rather than the tracker's agreement. Pinning `cb_state.tool_fence_len`'s own resolution would make the PQ-6 claim independent.
- The producer guard covers 5 of 10 registered tools (see I1).

## 6. Architectural notes

- **ARCH-DRY — flag (I2).** Two hand-maintained restatements of the same kind set now sit in the same file as the single-source import. Also the three call sites each spell out `is_structural_kind(classify(...))`; one exported `hs.structural_predicate(kinds)` helper would make a fourth consumer hard to get wrong.
- **ARCH-PURE — pass.** `fence.lua` stays pure and the predicate is injected; the new tests exercise it without IO. Minor blemish: `fold_projection`'s injected predicate re-does IO-free but expensive classification (Minor above).
- **ARCH-PURPOSE — flag (C1, I1).** C1 is the class-vs-instance failure at the code level: the rule was written for the tool-body close search and applied to every close search, and no one enumerated the second caller. I1 is it at the guard level — PQ-4's `guard-covers-instance-not-class` was disposed `addressed` in the plan but the implementation reverted to the instance (5 hand-picked tools) while the atlas asserts the class. The shadow-sweep on "name the kind set once" also stops one consumer short (`answer_structure.BOUNDARY`).
- **ARCH-MOCK — pass, with a note.** The producer guard shells out to real `grep`/`ack`/`ls`/`find` against a tempdir. That is defensible here — the invariant *is* conformance with the real binary's output shape, so this is the live-conformance half rather than a missing fake, and it matches existing `tools_builtin_*_spec` practice. Worth recording in the atlas that this spec is the conformance check, so a future move to a fake doesn't silently drop it.

## 7. Plan revision recommendations

Add a `## Revisions` entry to `workshop/issues/000203-…md`:

- **"The bound is on the tool-body close search only."** Record that `fence.scan`'s `close_of` is shared with the depth-establishing search for ordinary blocks, that binding both re-creates #200 BR-43 (evidence: `fold_marker_in_prose.md`, `text 10..16` → `text 10..12` + `tool_result 13..16`, with a fold over 13-16), and that the rule therefore takes a `bounded` flag. Add the regression case to the Plan's test list.
- **Correct the producer-guard step** to state what the guard actually covers (five read-shaped tools + a registry-size floor) *or* keep the claim and deliver the derivation; then fix `atlas/providers/tool_use.md`, which currently asserts construction-coverage the code does not provide.
- **Un-tick or complete the atlas step** — it names `atlas/chat/format.md`, which was not updated.
- **Extend the "name the kind set once" step** to `answer_structure.BOUNDARY`, the one remaining hand-maintained restatement.

```findings
findings:
  - id: new
    severity: Critical
    family: shared-helper-gains-caller-specific-rule
    title: |
      The #203 structural bound was added to the shared close_of, so ordinary fenced blocks stop establishing depth and BR-43 returns
    detail: |
      fence.lua:140-146 guards both the tool-body close search (line 154) and
      the depth-establishing search for any other opener (line 163). An
      ordinary fenced block containing a column-0 structural marker therefore
      never finds its close, and the scan walks into it. Verified against base
      5c65036 on the tracked BR-43 fixture tests/fixtures/fold_marker_in_prose.md:
      ex1's answer goes from [text 10..16] to [text 10..12, tool_result 13..16],
      and fold_projection folds rows 13..16, hiding real answer prose on line 16
      inside a fabricated tool fold. A base-vs-HEAD scan sweep over all tracked
      transcripts and fixtures found exactly this one divergence; the full suite
      is green because fold_invariants_spec's oracle only checks that questions
      are not folded and that foldable blocks fold. Fix: pass a `bounded` flag
      to close_of and set it only at line 154; verified that keeps every #203
      test green and restores the fixture.
  - id: new
    severity: Important
    family: guard-covers-instance-not-class
    title: |
      The producer guard hand-lists five tools while the atlas claims it derives its subjects from the registry
    detail: |
      tool_output_prefix_spec.lua iterates a hand-written READ_INPUTS of five
      tools; registered() is used only for `#registered() >= 9`, which passes
      when the registry GROWS. So a new builtin is not covered by construction,
      contradicting atlas/providers/tool_use.md and the Plan step. Unguarded:
      chat_history_search (the tool that greps chat transcripts, i.e. the most
      likely producer of a column-0 marker), emit_definition, edit_file,
      write_file, propose_edits. Drive the loop off registered() with an
      explicit, justified NON_ECHOING exclusion set.
  - id: new
    severity: Important
    family: hand-maintained-set-restates-source
    title: |
      answer_structure.BOUNDARY still hand-lists the kind set the diff just single-sourced
    detail: |
      answer_structure.lua:7-16 enumerates exactly STRUCTURAL_KINDS plus
      `reasoning`, in the same file that now imports is_structural_kind at
      line 41. The Plan step was "name the kind set once ... do not hand-list
      kinds at the call sites"; the sweep stopped at the predicate. This is the
      silent-drift class fold_projection.lua:12-16 already warns about for
      FOLDABLE. Derive BOUNDARY from STRUCTURAL_KINDS + reasoning (ARCH-DRY,
      ARCH-PURPOSE).
  - id: new
    severity: Important
    family: atlas-surface-not-updated
    title: |
      atlas/chat/format.md was named by the ticked atlas Plan step and not updated, and its statement is now false
    detail: |
      Line 12 says fence.lua owns "the rule that markers inside a body are
      content". After #203 that holds only for markers that are not column-0
      structural markers. parsing.md and tool_use.md carry the new rule;
      format.md, which the Plan step explicitly named as the third surface,
      does not.
  - id: new
    severity: Important
    family: silent-skip-guard
    title: |
      The corpus audit cited as close evidence silently skipped a tracked transcript deleted in the working tree
    detail: |
      workshop/parley/2026-05-03.22-29-53.828_global-warming-overview.md is
      tracked at HEAD but deleted in the working tree; fold_invariants_spec's
      filereadable skip drops it and the `>= 8` floor cannot notice, and the
      two untracked replacements are not picked up. I restored the file from
      HEAD and confirmed it shows no base-vs-HEAD scan divergence, so it is not
      hiding a failure — but Done-when claims the audit ran "over every tracked
      transcript" and it did not. Resolve the tree state before close.
  - id: new
    severity: Minor
    family: docblock-hygiene
    title: |
      fence.scan's docblock now has duplicated @param lines / @param is_tool_marker entries, with @param after @return
    detail: |
      fence.lua:115-125. Collapse the two blocks into one.
  - id: new
    severity: Minor
    family: redundant-per-line-work-in-scan
    title: |
      fold_projection's is_structural predicate does a per-line require plus a second full classify in a function documented as per-streamed-chunk hot
    detail: |
      fold_projection.lua:140-141 re-classifies lines the scan's is_tool_marker
      already classified, inside verify_anchors, whose own comment (lines
      108-113) justifies using a raw prefix match precisely because full
      classification costs ~10 pattern matches plus a footnote lookup per line.
      Hoist the module reference and share one kinds memo.
  - id: new
    severity: Minor
    family: nondeterministic-test-registration
    title: |
      tool_output_prefix_spec iterates READ_INPUTS with pairs(), so test order varies run to run
    detail: |
      tool_output_prefix_spec.lua:79. Use a sorted array of names.
  - id: new
    severity: Minor
    family: experiment-artifact-committed-unpruned
    title: |
      workshop/plans/203-experiment.patch is 1760 lines, ~1690 of which are a corpus transcript it would delete on apply
    detail: |
      The actual experiment is ~40 lines; the rest is the full text of
      workshop/parley/...global-warming-overview.md as deletion lines. The
      issue Log says "tree restored, nothing committed", yet this was
      committed. Prune to the experiment hunks or drop it — the Revisions
      section already records the decision. It also does not follow the
      NNNNNN-slug-plan.md convention for workshop/plans/.
  - id: new
    severity: Minor
    family: single-source-untested-directly
    title: |
      STRUCTURAL_KINDS and is_structural_kind have no direct unit test despite deciding the rule
    detail: |
      tests/unit/highlight_structure_spec.lua is untouched. Nothing pins the
      set's membership against classify's kind vocabulary, nor the deliberate
      exclusion of `reasoning` / `reasoning_end` that the docstring calls out.
  - id: new
    severity: Minor
    family: optional-param-documented-as-required
    title: |
      fence.scan's is_structural is documented "Required in practice" but is optional in the signature
    detail: |
      fence.lua:122-126. A fourth caller that omits it silently gets the
      pre-#203 close search. Make it required, or assert on nil.
```
