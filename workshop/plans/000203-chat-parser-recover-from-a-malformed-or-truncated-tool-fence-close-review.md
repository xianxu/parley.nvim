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

---

## Re-review — 2026-08-22T18:55:56-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 203 — chat_parser: recover from a malformed or truncated tool fence |
| repo | parley.nvim |
| issue file | workshop/issues/000203-chat-parser-recover-from-a-malformed-or-truncated-tool-fence.md |
| boundary | whole-issue close |
| milestone | — |
| window | 5c65036ec43c303681e7969d7bb479b4c9a2c3e5..dbb2ed907de39412f6abca7c5e912fa86e70ecca |
| command | sdlc close --issue 203 |
| reviewer | claude |
| timestamp | 2026-08-22T18:55:56-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The rework fixes BR-1 cleanly and I verified it two ways: reverting the bound back into the shared `close_of` turns `fence_spec.lua:236` red, and a base-vs-HEAD parse sweep over all 321 parseable tracked markdown files (plus the deleted and untracked transcripts) is byte-identical, so `fold_marker_in_prose.md` is back to `ex1 = [text:10-16]`. BR-2/BR-3/BR-4 are genuinely delivered. What blocks SHIP is a new Critical: the producer-side invariant the whole #203 rule rests on — *"no tool emits a column-0 marker"* — is **false on a reachable, well-formed path**. `grep` and `ack` never pass `--with-filename`/`-H`, so a call with `path` set to a **single file** (the exact shape `tools_builtin_grep_spec.lua:12` itself uses) returns raw matched lines with no prefix at all. I parsed a transcript that `tools/serialize.render_result` would write for such a call: **3 exchanges at HEAD, 2 at base** — a well-formed body parley produced now forks, contradicting the Spec's "well-formed transcripts keep today's behaviour exactly". The producer guard misses it because its `grep`/`ack` builders receive the file and pass the directory instead.

## 1. Strengths

- **BR-1's fix is real and pinned, not asserted.** Verified by revert: putting the bound back into the shared `close_of` makes `fence_spec.lua` *"keeps a marker quoted in an ordinary fenced block non-structural"* fail (25 pass / 1 fail). The separate `body_close_of` at `lua/parley/fence.lua:154-161` is the right shape.
- **No regression on the real corpus.** My own base-vs-HEAD sweep of the parsed model (question line + content-block types/spans) over 321 files — every tracked transcript, fixture, `docs/`, `atlas/`, `workshop/` — diffs empty, and so do the two untracked transcripts and the deleted one restored from HEAD. That is stronger evidence than the suite provides.
- **BR-2's fix has teeth.** Removing `emit_definition` from `NOT_ECHOING` turns *"rules on every registered tool, none silently uncovered"* red. Requiring a documented reason per exclusion is the right shape.
- **BR-3's derivation is correct and behaviour-preserving** (`answer_structure.lua:13-16`): the derived `BOUNDARY` has exactly the previous 8 members, and the one legitimate difference (`reasoning`) is stated once rather than duplicated.
- **`fence_spec.lua:207-252` pins the rule where it lives**, including *"a refused body must not also lose its marker"* — the invariant a downstream exchange count would not have caught.
- `make lint` 0 warnings / 0 errors over 340 files; full unit + integration suites green.

## 2. Critical findings

**C1 — `lua/parley/tools/builtin/grep.lua:152-205`, `ack.lua:76-104`: the producer invariant is false, and a well-formed transcript now forks.**

Neither tool passes `--with-filename`/`-H` (nor `-n` by default). Measured on this machine:

```
grep { pattern="💬", path=<single file> }  ->  "💬: a question at column zero"   kind=user  structural=true
grep { pattern="💬", path=<directory>   }  ->  "/abs/path/transcript.md:💬: …"   kind=text  structural=false
ack  { pattern="💬", path=<single file> }  ->  "💬: a question at column zero"   kind=user  structural=true
```

Feeding the exact block `tools/serialize.render_result` writes for that call through `chat_parser.parse_chat`:

```
HEAD dbb2ed9 : exchanges = 3   ex1 q=6 | ex2 q=15 "how does folding work"  <- grep OUTPUT became a turn | ex3 q=21
BASE 5c65036 : exchanges = 2   ex1 q=6 | ex2 q=21
```

So the grep result line is promoted to a real question, the `📎:` block is destroyed, and the forked exchange starts feed `exchange_anchors` identity — the same path #200's destructive fold clear rides. This is not the malformed input the Spec licenses over-forking for; it is output parley itself produced, and Done-when bullet 2 ("Well-formed bodies are unaffected") is false as shipped.

**This is the 2nd finding in family `guard-covers-instance-not-class`.** BR-2 fixed the tool-set axis; the class is wider than the tool set. Per the escalation rule I am not asking for the grep instance to be patched — here is the rule and its enumeration:

> **A producer-side invariant must be ENFORCED by the producer, not observed on one hand-picked call, and its guard must enumerate the tool × call-shape × content-shape matrix.**

The enumeration, all verified on this machine:

| tool | shape that breaks the invariant | status |
|---|---|---|
| `grep` | `path` = a single file → no prefix | **verified broken** (parse regression above) |
| `ack` | `path` = a single file → no prefix | **verified broken** |
| `ls` | directory containing a file named `💬: notes.md` → `ls` emits **bare basenames, no prefix at all** | **verified**: `content = "💬: pasted note.md"`, `kind=user`, `structural=true` |
| `find` | prefix comes from the caller's path arg, not the tool | mechanism real, but `tool_output_prefix_spec.lua:94` case is vacuous (fixture has no marker-named file) |
| `chat_history_search` | excluded by assertion in `NOT_ECHOING`, never exercised — though `tools_builtin_chat_history_search_spec.lua` shows it is ~10 lines to set up | untested; its error branch also splices raw stderr into an `is_error = false` result |

The guard's own text names the fix: `tool_output_prefix_spec.lua:84` justifies excluding `chat_history_search` because it runs *"rg with `--with-filename --line-number`"* — the very flags `grep`/`ack` omit. Make `grep`/`ack` derive that same discipline (ARCH-DRY: one prefixing rule, three consumers), and drive `READ_INPUTS` off a `{tool} × {dir-path, single-file-path}` product plus a fixture directory that contains a marker-named file, so `ls`/`find` stop being unfalsifiable. `tests/unit/tools_builtin_grep_spec.lua`'s assertions are loose (`content:match("function M.new")`), so adding `-H -n` does not break them.

Whatever the enumeration cannot cover must move into the atlas's *"Known exception, stated not hidden"* paragraph, which currently lists only the stderr splice. Two consequential doc statements are false as written and must change with the fix: `atlas/providers/tool_use.md` ("**no tool emits a column-0 marker**: each one prefixes its output … `ls`/`find` paths"), the same claim restated in `lua/parley/fence.lua:134-139`, and `atlas/chat/format.md:12` ("markers inside a body are content when they are **INDENTED**, which is how every tool emits them") — only `read_file` indents; `grep`/`ack`/`chat_history_search` prefix, `ls` does neither, and a column-0 `🧠:` is still content because `reasoning` is not in `STRUCTURAL_KINDS`.

## 3. Important findings

None beyond the disposition of BR-5 below (still open, so not re-raised as new).

## 4. Minor findings

None new — BR-6 through BR-11 remain open and are disposed `not-addressed` below rather than re-raised.

## 5. Test coverage notes

- The suite is green and lint-clean, but it stayed green through C1, and it would have stayed green through BR-1 too. Both defects live at the `fence.scan`/producer seam and both were invisible to downstream exchange counts. `fence_spec.lua`'s new BR-1 block is the right correction for one half; the producer half still has no case that can fail for 2 of its 5 exercised tools.
- `fence_spec.lua:262-278` ("still establishes depth when the block spans several markers") passes with the BR-1 fix reverted — its `is_tool_marker` only matches `📎:`, so `markers[2]` was never going to be set. Only the sibling at :236 carries teeth. Worth noting so the pair is not mistaken for two independent pins.
- `tests/unit/highlight_structure_spec.lua` is still untouched and is not in `chat/parsing`'s `tests:` list in `atlas/traceability.yaml`, even though `highlight_structure.lua` was added to that entry's `code:` list. So `make test-spec SPEC=chat/parsing` does not run the spec for the module that now owns the rule's single source (compounds BR-10).

## 6. Architectural notes

- **ARCH-DRY — flag (C1).** Three prefixing implementations across `grep`, `ack`, `chat_history_search`; only one is correct, and the correct one's rationale is quoted in the test that excludes it. One shared "always emit `--with-filename --line-number`" helper is the consolidation. Separately, the three `fence.scan` call sites each spell out `is_structural_kind(classify(...))`; an exported `highlight_structure.structural_predicate(kinds)` would make a fourth consumer hard to get wrong. BR-3's fix is a genuine DRY win.
- **ARCH-PURE — pass.** `fence.lua` stays pure, the predicate is injected, `fence_spec` runs it with no IO. `fold_projection.lua:139-141`'s per-line `require` + second full `classify` (BR-7) is a purity-neutral efficiency blemish; the same shape now also exists at `answer_structure.lua:41`, which BR-7 did not name.
- **ARCH-PURPOSE — flag (C1).** The issue's purpose is "a malformed fence must not swallow later exchanges **without costing the well-formed case**". The bound delivers the first clause; C1 shows the second clause is not delivered, because the producer obligation the plan identified was documented rather than enforced. That is the deferred-consumer shape: the invariant is stated in three places and derived in none. It is also the class-vs-instance shape again — BR-2 was answered on the tool-set axis and the call-shape axis was never enumerated, which is why the same family fires twice.
- **ARCH-MOCK — pass, with a note.** The producer guard shells out to the real `rg`/`ack`/`ls`/`find` against a tempdir, which is defensible: the invariant *is* conformance with the real binary's output shape, so this is the live-conformance half, not a missing fake. It should be recorded in `atlas/providers/tool_use.md` as the conformance check so a future move to a fake does not silently drop it. Note `ack`'s case self-skips when `ack` is absent from the host — legitimate, but it means the guard's coverage varies by machine.

## 7. Plan revision recommendations

Add to `workshop/issues/000203-…md`'s `## Revisions`:

- **"The producer invariant must be enforced, not documented."** Record that `grep`/`ack` omit `--with-filename`, so a single-file search returns unprefixed content and a well-formed `📎: grep` body forks (evidence: 3 exchanges at `dbb2ed9` vs 2 at `5c65036` on the serialized block); that `ls` emits bare basenames with no prefix mechanism at all; and that the guard must enumerate call shapes and content shapes, not tools alone. Name `ls` (and any residue) in the atlas's "Known exception" paragraph rather than in the absolute claim.
- **Correct Done-when bullet 2.** "Well-formed bodies are unaffected" is false until C1 lands; and the parenthetical "`fold_invariants_spec` over every tracked transcript" is still false in this working tree (see BR-5 below) — the sentence was never rewritten despite the round-1 Log claiming it was.
- **Re-open the atlas step** for the three statements C1 falsifies (`tool_use.md`, `fence.lua`, `format.md:12`).

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Verified by revert (fence_spec goes red) and by a 321-file base-vs-HEAD parse sweep that diffs empty.
  - id: BR-2
    disposition: addressed
    note: |
      Verified by revert; removing emit_definition from NOT_ECHOING turns the new case red. Residual is the call-shape axis, raised as a new Critical in the same family.
  - id: BR-3
    disposition: addressed
    note: |
      BOUNDARY now derives; membership identical to the old hand-list, suite green.
  - id: BR-4
    disposition: addressed
    note: |
      format.md updated; its new wording is imprecise ("INDENTED", "how every tool emits them") and is folded into the new Critical's doc fix.
  - id: BR-5
    disposition: not-addressed
    note: |
      Tree state unresolved (the transcript is still deleted-but-unstaged), Done-when still claims "every tracked transcript", the <= 1 threshold encodes the current breakage, and Makefile.parley's RUN_SPEC discards the print on pass.
  - id: BR-6
    disposition: not-addressed
    note: |
      Docblock still has duplicate @param lines/@param is_tool_marker after @return, and the rework merged the bounded rationale into the comment above the UNBOUNDED close_of, so it now reads as its own contradiction on the function BR-1 turned on.
  - id: BR-7
    disposition: not-addressed
    note: |
      fold_projection.lua:139-141 unchanged; the same per-call require now also exists at answer_structure.lua:41.
  - id: BR-8
    disposition: not-addressed
    note: |
      tool_output_prefix_spec.lua:105 still iterates pairs(READ_INPUTS).
  - id: BR-9
    disposition: not-addressed
    note: |
      workshop/plans/203-experiment.patch still committed at 1760 lines, still deletes a tracked transcript on apply.
  - id: BR-10
    disposition: not-addressed
    note: |
      highlight_structure_spec.lua untouched, and it is not in chat/parsing's tests list even though highlight_structure.lua was added to that entry's code list.
  - id: BR-11
    disposition: not-addressed
    note: |
      fence.lua:126 signature unchanged; is_structural still optional.
findings:
  - id: new
    severity: Critical
    family: guard-covers-instance-not-class
    title: |
      grep/ack omit --with-filename, so a single-file search emits column-0 markers and a well-formed tool body now forks the chat
    detail: |
      This is the 2nd finding in family guard-covers-instance-not-class, so
      the ask is the RULE, not this instance: a producer-side invariant must be
      ENFORCED by the producer and guarded across the tool x call-shape x
      content-shape matrix, never observed on one hand-picked call.
      Verified enumeration on this machine: grep with path=<single file> returns
      the raw matched line, no prefix (kind=user, structural=true); ack the same;
      ls returns bare basenames with no prefix mechanism at all, so a directory
      holding a file named "the marker: notes.md" emits a column-0 marker on a
      success path; find's prefix comes from the caller's path arg and its guard
      case is vacuous; chat_history_search is excluded by assertion and never
      exercised. End-to-end on the block tools/serialize.render_result writes for
      grep-on-a-single-file: 3 exchanges at dbb2ed9 vs 2 at 5c65036 — the grep
      output line becomes a real question, so Spec bullet 2 and Done-when bullet 2
      ("well-formed bodies unaffected") are false as shipped. The guard misses it
      because tool_output_prefix_spec.lua:91-94 receives the file and passes the
      directory. NOT_ECHOING:84 names the fix itself — chat_history_search is
      excluded because it runs rg with --with-filename --line-number, the flags
      grep/ack omit. Consolidate that prefixing discipline (ARCH-DRY), drive
      READ_INPUTS off a call-shape product with a marker-named file in the
      fixture, and move whatever remains into the atlas's stated-exception
      paragraph. Three doc statements are falsified and must change with it:
      atlas/providers/tool_use.md's "no tool emits a column-0 marker … ls/find
      paths", the same claim at lua/parley/fence.lua:134-139, and
      atlas/chat/format.md:12's "content when they are INDENTED, which is how
      every tool emits them" (only read_file indents; a column-0 reasoning marker
      is still content).
```

---

## Re-review — 2026-08-22T19:17:37-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 203 — chat_parser: recover from a malformed or truncated tool fence |
| repo | parley.nvim |
| issue file | workshop/issues/000203-chat-parser-recover-from-a-malformed-or-truncated-tool-fence.md |
| boundary | whole-issue close |
| milestone | — |
| window | 5c65036ec43c303681e7969d7bb479b4c9a2c3e5..bd1a623f86259fd4708f9893eb14162d43c0c4bd |
| command | sdlc close --issue 203 |
| reviewer | claude |
| timestamp | 2026-08-22T19:17:37-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The rule this issue lands on is now correct and, more importantly, *proven* correct: I reverted each half of it independently and watched the right tests go red, and I ran my own base-vs-HEAD parse sweep over 343 chat files — including the deleted `global-warming-overview.md` restored from HEAD (26 tool markers) and the untracked 52-marker transcript — with a byte-identical result, after first catching that my own first sweep attempt was vacuous (Neovim's runtime loader won over `package.path`, so the "base" run was loading HEAD modules; the corrected run discriminates 2 vs 3 exchanges on the malformed shape). BR-12 is genuinely fixed at the producer and pinned: deleting `-H` turns both the `grep` and `ack` single-file cases red, and the end-to-end block `serialize.render_result` writes for `grep path=<single file>` now parses to 2 exchanges, matching base. Nothing here is Critical. What holds SHIP back is two cheap Important items, both in the "claim wider than the mechanism" shape this issue's own Log names: the `fence.lua` docblock rework **deleted** `M.scan`'s grammar prose and both `@return` lines while duplicating `extract_body`'s block — and two atlas pages designate those docstrings as *the* specification; and one test still asserts, by name, a premise the diff refuted, staying green because its assertion cannot see the difference.

## 1. Strengths

- **The rule is pinned at three levels, and each pin has teeth.** Reverting `body_close_of` → `close_of` reddens `fence_spec` ("refuses a close that lies beyond a structural marker"), `chat_parser_tools_spec` (3 cases), and `fold_projection_spec` — the scan's own model, the parser, and the fold guard, independently. Reverting the BR-1 fix (bound back into the shared `close_of`) reddens `fence_spec.lua:262` and nothing else, which is exactly why that pin had to exist: `fold_invariants_spec` **passed** with BR-1 reintroduced.
- **BR-12's fix is at the producer, not the call site** (`grep.lua:159`, `ack.lua:78`), so `paths = {file}` and every other single-target spelling is covered by construction rather than by an added fixture. Verified end-to-end, not just by unit assertion.
- **No drift on well-formed content.** 343 chat-bearing markdown files, base vs HEAD, parse to identical exchange counts, question lines, and content-block type/spans — with the tool-bearing subset (16 files, including both transcripts the corpus audit cannot reach) checked separately.
- **BR-5's fix converts an overclaim into a named, enforced exception.** Removing the `KNOWN_UNREADABLE` entry turns the new case red, so the exclusion is live rather than decorative; and I independently confirmed the excluded transcript shows no base-vs-HEAD divergence, so it is not concealing a failure.
- **BR-3's derivation is correct and complete**: `answer_structure.BOUNDARY` now has exactly the 8 members it hand-listed, and `STRUCTURAL_KINDS`' 7 names match `classify`'s vocabulary and the `^prefix` anchoring exactly — the "column-0" framing in the docs is literally true, not approximately.
- `luacheck` 0/0 over 340 files; full unit + integration suites green.

## 2. Critical findings

None.

## 3. Important findings

**I1 — `lua/parley/fence.lua:76-107`: the docblock rework deleted the specification the atlas points at, and duplicated the block above it.**

`extract_body`'s docblock is now present twice verbatim (lines 76-80 and 81-85). `M.scan`'s docblock (lines 102-107) lost the "One linear pass…" grammar prose *and* both `@return` lines — `bodies` (`marker_row -> {first,last,close}`, `first > last` for an empty body, `close` nil when none found) and `markers` are now undocumented, making `scan` the only public function in the module without a `@return`. That extent model is precisely what `#200 BR-52` says consumers must branch on rather than reconstruct, and it is now folklore.

Two atlas pages designate that docstring as the spec and are falsified by the deletion: `atlas/chat/parsing.md:19` ("see its docstrings for the grammar itself") and `atlas/providers/tool_use.md:153` ("**Its docstrings are the specification** — this page deliberately does not restate the rule, because prose cannot derive from a module and a restatement drifts silently"). That same page then restates the rule twice in the new #203 section — the single-source relationship is inverted, not just stale.

**This is the 2nd finding in family `docblock-hygiene`.** Earlier rounds fixed the instance (BR-6's duplicated `@param`s on `scan`), and the fix for it introduced this one in the same commit. Do not fix this instance — state the rule and sweep it. The rule: **a docblock rewrite must be diffed against the block it replaces, because `fence.lua`'s docstrings are a designated specification surface, not commentary — deleting contract text there is a docs regression, and the `## Log`'s own account says this edit was a recovered span-edit, which is exactly the failure mode that silently drops a block.** The enumeration is small and writable now: every docblock touched in `5c65036..bd1a623` — `fence.extract_body`, `fence.scan`, `highlight_structure.STRUCTURAL_KINDS`, `highlight_structure.is_structural_kind` (no `@param`/`@return` at all) — checked for (a) no duplication, (b) `@param` for each parameter, (c) `@return` for each return value, (d) any prose an atlas page claims to defer to.

**I2 — `tests/unit/chat_parser_tools_spec.lua:407`: a test still asserts, by name, the premise this issue refuted, and stays green because its assertion cannot see the change.**

`treats a tool-result marker inside a tool body as content` puts a column-0 `📎: read_file id=other` inside a `📎: grep` body and asserts `#exchanges == 1`. Measured on that exact window:

```
BASE 5c65036 : bodies[1] = { first = 3, last = 4, close = 5 }   <- the column-0 📎: IS body content
HEAD bd1a623 : bodies[1] = nil                                   <- body refused; the marker is skipped by DEPTH
```

`tool_result` is in `STRUCTURAL_KINDS`, so the body is bounded and refused; the inner marker then falls inside the ordinary-opener depth skip, which is why the exchange count is 1 either way. The test therefore reads as coverage for "in-body markers are content" while the code does the opposite.

Plan step 7 committed to re-pointing "the two tests encoding the unreachable shape"; the enumeration was the tests that *went red*, and this one did not, so it was never swept. Consequence beyond the stale name: **no test anywhere pins the tool-marker members of `STRUCTURAL_KINDS`.** `fence_spec`'s predicate is `^💬:`, the new `chat_parser` fork case uses `💬:`, and `fold_projection_spec`'s uses `💬:` — `tool_use`/`tool_result`/`summary`/`branch`/`local` bounding a body is asserted nowhere, in the issue that single-sourced that set. Fix: give this case the `%5d  ` prefix its sibling shapes got (preserving its real subject), and add a case pinning a column-0 `📎:` refusing the body — asserted on `fence.scan`'s `bodies`, since an exchange count provably cannot see it.

## 4. Minor findings

- `tests/integration/tool_output_prefix_spec.lua:141-151` — when `ack` is absent the case asserts only "is optional" and returns Success, silently dropping 2 of 7 cases; `atlas/providers/tool_use.md:197` claims the guard "fails loudly rather than skipping when a tool is unregistered". Same file: the marker-named fixture at `:47` says "without this the path-echoing tools were never exercised", but `ls`/`find` were moved to `NOT_ECHOING` at `:116-117`, so nothing reads it.
- `tests/integration/tool_output_prefix_spec.lua:3-8` — the header still states the absolute claim BR-12 falsified ("no tool EMITS one — every tool prefixes its output"), contradicting `:110-117` of the same file.
- `lua/parley/fold_projection.lua:94-101,140` — the new `is_structural` closure reads the `highlight_structure` upvalue, which is assigned only inside the `not patterns` branch or as a side effect of the *default* `classify` closure. With `M._classify` set (the seam at `:98` exists for exactly that), the first tool-kind range indexes a nil value. Unreachable today because nothing sets `M._classify`; one unconditional assignment removes the hazard.
- `atlas/traceability.yaml` — `highlight_structure.lua` was added to `chat/parsing`'s `code:` list but `tests/unit/highlight_structure_spec.lua` is not in its `tests:` list, so `make test-spec SPEC=chat/parsing` skips the spec for the module that now owns the rule's source (compounds BR-10).

## 5. Test coverage notes

- The suite is green and lint-clean, and it stayed green through BR-1 *and* BR-12. Both lived at the `fence.scan`/producer seam; both were invisible to downstream exchange counts. `fence_spec.lua:207-278` and the tool × call-shape product are the right corrections, and I verified each has teeth.
- `fence_spec.lua:270` ("still establishes depth when the block spans several markers") still passes with the BR-1 fix reverted — its `is_tool_marker` only matches `📎:`, so `markers[2]` was never going to be set. Only `:262` carries the pin; the pair should not be read as two.
- `survives a body truncated mid-write with no close at all` passes with the #203 bound entirely removed (no close exists anywhere, so both searches return nil). It is a valid regression pin, not a pin on the new rule.
- The `content-shape` axis of BR-12's matrix is one shape (a file of column-0 markers). The second content shape the fixture prepares — a marker-*named* file — is exercised by no case, because its only consumers were excluded.

## 6. Architectural notes

- **ARCH-DRY — flag (I1).** The producer invariant is now restated in ~7 places (`fence.lua` comment, `grep.lua`, `ack.lua`, `tool_output_prefix_spec` header, `tool_use.md`, `format.md`, `parsing.md`); six were updated for BR-12 and one was not, which is the predicted failure of a restated model. The designated single source (`fence.scan`'s docstring) simultaneously lost its content. Separately: BR-12 asked to consolidate the prefixing discipline, and the diff instead spells the flags per tool with a cross-reference comment — defensible here, since the spellings genuinely differ per binary (`grep -H -n` / `ack -H` / `rg --with-filename --line-number --no-heading`), but it means `argv.lua` is still not the one place a fourth search tool would look. Pass on BR-3's derivation, which is a real DRY win.
- **ARCH-PURE — pass.** `fence.lua` stays pure, the predicate is injected, and `fence_spec` exercises the new rule with no IO. `fold_projection`'s lazy `require` is now justified in-comment (the module must load without `vim`), and I confirm a module-level require would break that; the residue is the second full `classify` per line (BR-7) and the upvalue hazard above.
- **ARCH-PURPOSE — flag (I2), and the headline purpose is now delivered.** Spec bullet 2 ("well-formed transcripts keep today's behaviour exactly") is true as shipped — the 343-file sweep and the `grep`-single-file end-to-end both confirm it, which was false at `dbb2ed9`. The remaining class-vs-instance residue is I2: the sweep for "tests encoding the refuted premise" enumerated the tests that broke rather than the tests that *encode the premise*, and the one that stayed green is the one that now misdescribes the code. Note also that a refused body makes the rows up to the next bare fence depth-skipped, so `🔧:`/`📎:` markers inside that span lose their tool-ness — strictly better than base (which swallowed the questions too) and within the Spec's over-forking preference, but worth stating once in the atlas as the shape of the degradation.
- **ARCH-MOCK — pass, with a note.** The guard shells out to the real `rg`/`ack`/`ls`/`find` against a tempdir. That is the correct call here: the invariant *is* conformance with the real binary's output shape, so this is the live-conformance half rather than a missing fake — BR-12 is the proof, since no fake would have modelled rg's single-file filename suppression. It should be labelled as such in `atlas/providers/tool_use.md` so a later move to a fake does not silently drop it; and the machine-dependent `ack` coverage (Minor above) is the cost of that choice, which should be stated rather than skipped.

## 7. Plan revision recommendations

- **`## Revisions` — "the docstring is the spec, so treat it as one."** Record that `atlas/chat/parsing.md` and `atlas/providers/tool_use.md` both defer to `fence.lua`'s docstrings, that the round-2 rework deleted `M.scan`'s grammar prose and `@return` contract while duplicating `extract_body`'s block, and that the atlas step is re-opened until the docstring holds the specification those pages point at.
- **Amend Plan step 7's enumeration.** It reads "re-point the two tests encoding the unreachable shape"; the actual set is "every test encoding the refuted premise", which includes `chat_parser_tools_spec.lua:407` — a test that stayed green and so was never counted. Add the missing pin for the tool-marker members of `STRUCTURAL_KINDS`.
- **Correct the producer-guard step's coverage claim** to say what the guard actually delivers: every registered tool ruled, `read_file`/`grep`/`ack` exercised over a call-shape product, `ls`/`find`/`chat_history_search` excluded with reasons, and `ack` coverage contingent on the host — then make `atlas/providers/tool_use.md:197` ("fails loudly rather than skipping") match.

```findings
dispose:
  - id: BR-5
    disposition: addressed
    note: |
      Named exclusion with teeth — removing the KNOWN_UNREADABLE entry turns the new case red; I also confirmed the excluded transcript shows no base-vs-HEAD divergence.
  - id: BR-6
    disposition: addressed
    note: |
      scan's docblock is one block now; the same commit duplicated extract_body's and deleted scan's @return, raised as the family's 2nd finding rather than re-raised here.
  - id: BR-7
    disposition: not-addressed
    note: |
      answer_structure's per-call require is gone and fold_projection's laziness is now justified, but the second full classify per line remains — no shared kinds memo.
  - id: BR-8
    disposition: addressed
    note: |
      Both the tool names and the shape names are sorted before registration.
  - id: BR-9
    disposition: not-addressed
    note: |
      workshop/plans/203-experiment.patch still tracked at 1760 lines and still deletes a tracked transcript on apply.
  - id: BR-10
    disposition: not-addressed
    note: |
      highlight_structure_spec.lua untouched and still absent from chat/parsing's tests list though the module is in its code list.
  - id: BR-11
    disposition: not-addressed
    note: |
      fence.lua:108 signature unchanged; the guard at :145 is still `if is_structural and ...`.
  - id: BR-12
    disposition: addressed
    note: |
      Verified by revert (grep and ack single-file cases both go red without -H) and end-to-end (serialized grep-on-a-single-file block parses to 2 exchanges, matching base); 343-file base-vs-HEAD sweep diffs empty.
findings:
  - id: new
    severity: Important
    family: docblock-hygiene
    title: |
      The fence.lua docblock rework deleted M.scan's grammar prose and both @return lines, and duplicated extract_body's block
    detail: |
      This is the 2nd finding in family docblock-hygiene, so the ask is the
      RULE. fence.lua:76-85 carries extract_body's docblock twice verbatim, and
      M.scan's docblock at :102-107 lost the "One linear pass" grammar
      description and both @return entries — the bodies extent model
      (marker_row -> {first,last,close}, first > last for an empty body, close
      nil when none found) is now undocumented, though #200 BR-52 requires
      consumers to branch on exactly that. Two atlas pages designate this
      docstring as the specification and are falsified by the deletion:
      atlas/chat/parsing.md:19 ("see its docstrings for the grammar itself") and
      atlas/providers/tool_use.md:153 ("Its docstrings are the specification —
      this page deliberately does not restate the rule"), which then restates
      the rule twice in its own new section. The rule: fence.lua's docstrings
      are a designated specification surface, not commentary, so a docblock
      rewrite must be diffed against the block it replaces — the Log records
      this edit as a recovered span-edit, which is the exact failure mode that
      silently drops a block. Enumeration for this round: every docblock touched
      in 5c65036..bd1a623 (fence.extract_body, fence.scan,
      highlight_structure.STRUCTURAL_KINDS, highlight_structure.is_structural_kind
      — the last has no @param or @return at all), checked for no duplication, a
      @param per parameter, a @return per return value, and any prose an atlas
      page defers to.
  - id: new
    severity: Important
    family: stale-test-premise
    title: |
      A test still asserts by name the premise this issue refuted, and stays green because its assertion cannot see the change
    detail: |
      chat_parser_tools_spec.lua:407 "treats a tool-result marker inside a tool
      body as content" puts a column-0 tool-result marker inside a grep body and
      asserts only that there is 1 exchange. Measured on that exact window:
      base 5c65036 gives bodies[1] = {first=3,last=4,close=5} (the marker IS body
      content), HEAD gives bodies[1] = nil (the body is refused and the marker is
      skipped by depth). Both yield 1 exchange, so the assertion cannot
      distinguish, and the test now reads as coverage for the opposite of what
      the code does. Plan step 7 enumerated "the tests that went red" rather than
      "the tests that encode the premise", which is why this one was never swept.
      Consequence beyond the stale name: nothing anywhere pins the tool-marker
      members of STRUCTURAL_KINDS — fence_spec, the new chat_parser fork case and
      fold_projection_spec all use a user-marker predicate, so tool_use,
      tool_result, summary, branch and local bounding a body is asserted nowhere,
      in the issue that single-sourced that set. Fix: give this case the "%5d  "
      prefix its siblings got, and add a case pinning a column-0 tool-result
      marker refusing the body, asserted on fence.scan's bodies.
  - id: new
    severity: Minor
    family: silent-skip-guard
    title: |
      The producer guard silently drops ack coverage on a host without ack, while the atlas claims it fails loudly rather than skipping
    detail: |
      This is the 2nd finding in family silent-skip-guard, so the ask is the
      RULE, not this instance. tool_output_prefix_spec.lua:141-151 returns
      Success after asserting only "is optional" when tools.get returns nil, so
      on a host without ack 2 of 7 cases vanish with nothing reporting it —
      while atlas/providers/tool_use.md:197 states the guard "fails loudly
      rather than skipping when a tool is unregistered". Same file, same shape:
      the marker-named fixture at :47 says "without this the path-echoing tools
      were never exercised", but ls/find were moved to NOT_ECHOING at :116-117,
      so no case reads it. The rule: every coverage-dropping skip must be
      counted and asserted against a NAMED allowlist with a reason — which is
      exactly the mechanism fold_invariants_spec.lua:95-109 now has for its
      corpus. Apply that same shape here (a named OPTIONAL_ABSENT record, and a
      case that fails when a fixture no consumer reads is left behind), and make
      the atlas sentence state the exception instead of overstating it.
  - id: new
    severity: Minor
    family: atlas-surface-not-updated
    title: |
      The producer guard's own header still states the absolute claim BR-12 falsified, contradicting its body 100 lines down
    detail: |
      This is the 2nd finding in family atlas-surface-not-updated, so the ask is
      the RULE. tool_output_prefix_spec.lua:3-8 still reads "no tool EMITS one —
      every tool prefixes its output", which BR-12 disproved and which :110-117
      of the same file contradicts. Six of the invariant's seven prose
      restatements (fence.lua, grep.lua, ack.lua, tool_use.md, format.md,
      parsing.md) were updated for BR-12 and this one was not. The rule: the
      producer invariant must be STATED once — in atlas/providers/tool_use.md's
      bounded-claim paragraph — and every other site must point at it rather
      than restate it, because a restatement is a deferred consumer that drifts
      silently (ARCH-DRY). Enumeration: grep the tree for "prefixes its output",
      "column-0 marker" and "-H" and reduce each hit to a pointer.
  - id: new
    severity: Minor
    family: closure-captures-lazy-upvalue
    title: |
      fold_projection's new is_structural closure reads an upvalue initialized only as a side effect of another closure
    detail: |
      fold_projection.lua:140 calls highlight_structure.is_structural_kind on the
      local declared at :94, which is assigned only inside the `not patterns`
      branch or as a side effect of the DEFAULT classify closure at :98-101. With
      M._classify injected — the seam that line exists for — the first tool_use /
      tool_result range indexes a nil value and verify_anchors crashes. Nothing
      sets M._classify today so it is unreachable, but the diff introduced the
      coupling. One unconditional assignment of highlight_structure before the
      loop removes it.
```

---

## Re-review — 2026-08-22T19:30:42-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 203 — chat_parser: recover from a malformed or truncated tool fence |
| repo | parley.nvim |
| issue file | workshop/issues/000203-chat-parser-recover-from-a-malformed-or-truncated-tool-fence.md |
| boundary | whole-issue close |
| milestone | — |
| window | 5c65036ec43c303681e7969d7bb479b4c9a2c3e5..267dd65cce338601c3c91c2adba97baadfaa3635 |
| command | sdlc close --issue 203 |
| reviewer | claude |
| timestamp | 2026-08-22T19:30:42-07:00 |
| verdict | REWORK |

## Review

Verification complete — lint + unit + integration all green (exit 0), and I ran three independent probes plus a 343-file base-vs-HEAD parse sweep.

```verdict
verdict: REWORK
confidence: high
```

The rule itself is correct and I confirmed it three independent ways: a base-vs-HEAD parse sweep over 343 markdown files (all tracked + untracked, 14 tool-bearing) diffs empty, the deleted-but-unstaged transcript restored from HEAD (26 tool markers) is identical, and reverting the bound turns the discriminating pins red. `fence.lua` is genuinely restored — its code-only diff against `5c65036` is exactly the `is_structural` parameter, `body_close_of`, and one call site, so BR-13 is closed. What blocks the boundary is that this round's headline deliverable is not delivered: **the five new "refuses to span a column-0 X inside a body" cases assert an exchange count that is 2 at base and 2 at HEAD for every one of the five markers** — measured, not inferred — so they pass identically without the rule. That is BR-14's exact defect, reproduced inside BR-14's own fix, after the finding named the assertion to use (`fence.scan`'s `bodies`, which I confirmed *does* discriminate: `head=nil` vs `base={3,3,4}` for all five). Separately, a ticked Plan step ("Name the kind set once … do not hand-list kinds at the call sites") is undelivered at the two remaining sites — one of them 115 lines below the declaration in `highlight_structure.lua` itself. Both fixes are small; the code needs no change.

## 1. Strengths

- **The core rule holds on real data, and I checked it myself rather than taking the Log's word.** 343 files parsed at base (fence.scan with the predicate stripped) vs HEAD, comparing exchange count, question line, and every content-block type/span: **0 divergences**, including the 14 tool-bearing transcripts. The named-exclusion transcript, restored from `HEAD`, is also identical.
- **`fence.lua` is precisely restored (BR-13).** `M.scan`'s "One linear pass…" grammar prose and both `@return` lines are back (`fence.lua:97-126`), `extract_body`'s block appears exactly once (`:76-83`), and the two rationales sit on their own functions — `close_of` labelled UNBOUNDED with the BR-1 history, `body_close_of` BOUNDED with the producer argument and both stated exceptions.
- **The 💬-shaped pins have real teeth.** Measured base→HEAD: `forks on a column-0 question marker` 2→3, and the enabled `survives an unclosed body followed by a later bare fence` 2→3. `fence_spec.lua:220-236` pins the same at the scan's own model.
- **BR-5's mechanism is live, not decorative** (`fold_invariants_spec.lua:95-109`): a *named* `KNOWN_UNREADABLE` entry with a reason, and a case that fails on any other skip.
- **The producer fix is at the producer.** `grep.lua:159` / `ack.lua:78` emit `-H` unconditionally rather than relying on caller flags, so every single-target spelling is covered by construction. I also spot-checked the `NOT_ECHOING` exclusions rather than trusting them: `edit_file`/`write_file`/`propose_edits` all return word-initial status strings and `emit_definition` returns `""`, so those four rulings are true.

## 2. Critical findings

None. No correctness defect, no behavior drift, no crash path in the diff.

## 3. Important findings

**I1 — `tests/unit/chat_parser_tools_spec.lua:437-452`: the five cases added to pin the tool-marker members of `STRUCTURAL_KINDS` cannot see the rule they pin.** This is BR-14 re-opened, not a new id. Measured on the spec's exact fixture, via `parser.parse_chat(lines, 4, test_config())` with `fence.scan` patched to drop the predicate:

```
  📎: read_file id=other   base=2 head=2   CANNOT DISCRIMINATE
  🔧: read_file id=next    base=2 head=2   CANNOT DISCRIMINATE
  📝: a summary            base=2 head=2   CANNOT DISCRIMINATE
  🔒: local                base=2 head=2   CANNOT DISCRIMINATE
  🌿: branch               base=2 head=2   CANNOT DISCRIMINATE
```

None of the five markers starts an exchange, so the count is 2 either way — at base the body spans the marker and closes on the following fence; at HEAD the body is refused and the marker is depth-skipped by the ordinary-opener branch. The consequence BR-14 identified therefore still stands verbatim: **`tool_use`/`tool_result`/`summary`/`branch`/`local` bounding a body is asserted nowhere**, in the issue that single-sourced that set. The finding told you the assertion to use, and it works — on the same windows, `fence.scan` gives `bodies[1] = nil` at HEAD and `{first=3,last=3,close=4}` at base for all five. Fix: assert on `fence.scan`'s `bodies` (as `fence_spec.lua:227-236` already does for `💬:`), or build the shape the loop's own comment describes — a column-0 `📎:` swallowing the *next* tool block, which does differ (`bodies={}` vs one body). The `%5d`-prefixed sibling and the `truncated mid-write` case are legitimately non-discriminating regression pins and should stay as they are.

**I2 (new) — two hand-maintained restatements of `STRUCTURAL_KINDS` survive, one of them inside the module that declares it.** **This is the 2nd finding in family `hand-maintained-set-restates-source`.** BR-3 fixed the instance (`answer_structure.BOUNDARY`); the class was never enumerated. The rule: *the structural-marker set has exactly one source, `highlight_structure.STRUCTURAL_KINDS`; every site that asks "is this a structural marker?" calls `is_structural_kind`, and a site that spells the members out is a deferred consumer that drifts silently* (ARCH-DRY, ARCH-PURPOSE). I ran the enumeration so it does not have to be guessed — every `lua/` file with ≥3 kind-name occurrences, each hit inspected; all other hits are per-kind dispatch, which is legitimate. The complete remaining set is two:

- `lua/parley/highlight_structure.lua:137-141` — `token == TOKENS.user or … assistant or ["local"] or branch or summary or tool_use or tool_result`, 115 lines below `M.STRUCTURAL_KINDS`, deciding reasoning-block termination.
- `lua/parley/chat_parser.lua:761-765` — the same seven as kinds, same decision. This is the site Plan step 2 named as *the* source ("the set `chat_parser.lua:288` already calls structural"), and the step is ticked.

Both are exact supersets of nothing and subsets of nothing — membership is identical to `STRUCTURAL_KINDS`, and `reasoning_end` is already handled by an earlier branch at both sites, so `is_structural_kind(ahead_kind)` (and a `STRUCTURAL_TOKENS` derived from `TOKENS` for the fingerprint path) substitutes exactly. Nothing pins the agreement, so adding a kind to `STRUCTURAL_KINDS` would silently stop terminating reasoning blocks on it.

## 4. Minor findings

- BR-7, BR-9, BR-10, BR-11, BR-15, BR-16, BR-17 are all unchanged in this window and are disposed `not-addressed` below with per-finding evidence; I am not restating them here.
- `lua/parley/tools/builtin/grep.lua:110` — the `flags` schema still advertises `-n, --line-number` as caller-selectable, but `:159` now emits `-n` unconditionally, so the model is offered a no-op flag.
- `tests/fixtures/fold_adversarial.md:22-24` — after the (correct) `%5d  ` fidelity prefix, the inner ` ``` ` lines are no longer fences, so the line that still reads "this nested block uses a shorter fence" describes something the fixture no longer contains.

## 5. Test coverage notes

- Suite is clean: `luacheck` 0 warnings / 0 errors over 340 files; `make test-unit` and `make test-integration` both exit 0.
- The coverage that exists is real — I reverted the bound and watched `fence_spec`'s "refuses a close that lies beyond a structural marker" and the two `💬:` chat_parser cases go red. The gap is exactly I1: the marker axis is unpinned.
- With `fold_adversarial.md`'s read_file body now prefixed, the corpus-level fixture set no longer contains any nested-fence shape (its grep body uses a bare ` ``` `). The property is still pinned at `fence_spec.lua:246` and `chat_parser_tools_spec.lua:474-484`, so this is an observation rather than a hole — but the integration-level instance is gone and nothing records that.
- `survives a body truncated mid-write with no close at all` passes with the #203 bound removed entirely (no close exists anywhere, so both searches return nil). Valid as a regression pin; it is not a pin on the new rule, and the round-3 note on this still applies.

## 6. Architectural notes

- **ARCH-DRY — flag (I2).** The set is single-sourced for the *new* consumers and still hand-listed at the two *old* ones, including in its own module. Separately, all three `fence.scan` call sites spell out `is_structural_kind(classify(…))`; one exported `highlight_structure.structural_predicate(kinds)` would make a fourth consumer hard to get wrong, and would also retire BR-17's upvalue coupling and BR-7's second classify in one move.
- **ARCH-PURE — pass.** `fence.lua` remains pure and the predicate is injected; `fence_spec` exercises the new rule with zero IO. The residue is efficiency and initialization order (BR-7, BR-17), not purity.
- **ARCH-PURPOSE — flag (I1, I2).** Spec bullet 2 ("well-formed transcripts keep today's behaviour exactly") is true as shipped — the 343-file sweep is the evidence, and it holds for the deleted transcript too. What is under-delivered is the *class* on both open axes: the sweep for "the tests that encode the premise" produced five tests that cannot see the premise, and the sweep for "name the kind set once" stopped one file short of the file the Plan cited. Both are the same failure — answering the instance the finding named rather than writing the enumeration the finding implied.
- **ARCH-MOCK — pass, with the same note as round 3.** `tool_output_prefix_spec` shells out to the real `rg`/`ack`/`ls`/`find` against a tempdir, which is correct here: the invariant *is* conformance with the real binary's output shape, and BR-12 is the proof that no fake would have modelled rg's single-file filename suppression. `ack` is present on this host so all seven cases ran; BR-15's machine-dependence is real but untriggered here. Worth labelling this spec in `atlas/providers/tool_use.md` as the live-conformance check so a later move to a fake does not silently drop it.

## 7. Plan revision recommendations

- **Un-tick or complete Plan step 2 ("Name the kind set once").** It is ticked while `highlight_structure.lua:137-141` and `chat_parser.lua:761-765` still hand-list the set — and the second is the site the step itself cites as the source. Add a `## Revisions` entry recording the two-site enumeration and that the sweep is the deliverable, not the predicate.
- **Amend Plan step 7 again, and this time record the acceptance test for a pin.** The step now reads as satisfied, but five of the cases it produced pass without the change. State the criterion the issue's own `workshop/lessons.md` entry already prescribes — *"after writing a guard, break the thing it guards and watch it go red"* — as the condition for ticking a coverage step, since that lesson was written in this issue and violated by the commit that closed the finding about it.
- **Correct the round-3 Log entry.** It states BR-14 "now asserts the body extent, which is what actually differs"; the prefixed case asserts `#content_blocks > 0` (1 at base, 1 at HEAD) and the five new cases assert an exchange count that does not differ. Neither asserts the body extent.

```findings
dispose:
  - id: BR-7
    disposition: not-addressed
    note: |
      fold_projection.lua:140 unchanged — still a second full classify per line inside verify_anchors; no shared kinds memo.
  - id: BR-9
    disposition: not-addressed
    note: |
      workshop/plans/203-experiment.patch still tracked at 1760 lines and still deletes a tracked transcript on apply.
  - id: BR-10
    disposition: not-addressed
    note: |
      highlight_structure_spec.lua untouched and still absent from chat/parsing's tests list though the module is in its code list.
  - id: BR-11
    disposition: not-addressed
    note: |
      fence.lua:127 signature unchanged; the guard at :164 is still `if is_structural and ...`.
  - id: BR-13
    disposition: addressed
    note: |
      Verified by code-only diff against 5c65036 — fence.lua differs by exactly the is_structural param, body_close_of and one call site; extract_body's block appears once, scan's grammar prose and both @return lines are back. The enumeration's is_structural_kind item is consistent with its module, which carries zero @param/@return across all 8 exported functions.
  - id: BR-14
    disposition: not-addressed
    note: |
      Rename and the prefixed/column-0 split landed, but the pin did not — measured on the spec's exact fixture, all five new marker cases give 2 exchanges at base and 2 at HEAD, so they pass without the rule; fence.scan's bodies (nil vs {3,3,4}) is the assertion the finding asked for and it discriminates.
  - id: BR-15
    disposition: not-addressed
    note: |
      tool_output_prefix_spec.lua:141-151 unchanged; ack still self-skips with no counted allowlist, and the marker-named fixture at :47 is still read by no case.
  - id: BR-16
    disposition: not-addressed
    note: |
      tool_output_prefix_spec.lua:3-8 still states the absolute claim BR-12 falsified, contradicting :110-117 of the same file.
  - id: BR-17
    disposition: not-addressed
    note: |
      fold_projection.lua:94-101,140 unchanged; the highlight_structure upvalue is still assigned only as a side effect of the default classify closure, so an injected M._classify makes verify_anchors index nil.
findings:
  - id: new
    severity: Important
    family: hand-maintained-set-restates-source
    title: |
      Two hand-maintained restatements of STRUCTURAL_KINDS survive, one inside the module that declares it and one at the site the Plan named as the source
    detail: |
      This is the 2nd finding in family hand-maintained-set-restates-source, so
      the ask is the RULE. BR-3 fixed answer_structure.BOUNDARY; the class was
      never enumerated. The rule: the structural-marker set has exactly one
      source, highlight_structure.STRUCTURAL_KINDS, and every site deciding "is
      this a structural marker?" calls is_structural_kind — a site that spells
      the members out is a deferred consumer that drifts silently (ARCH-DRY,
      ARCH-PURPOSE). Enumeration run this round over every lua/ file with three
      or more structural-kind name occurrences, each hit inspected; all other
      hits are legitimate per-kind dispatch. The complete remainder is two, both
      deciding reasoning-block termination and both membership-identical to
      STRUCTURAL_KINDS with reasoning_end already handled by an earlier branch,
      so substitution is exact: highlight_structure.lua:137-141 (token form, 115
      lines below the declaration — needs a STRUCTURAL_TOKENS derived from
      TOKENS) and chat_parser.lua:761-765 (kind form). The second is the site
      Plan step 2 cites as the source of the set, and that step is ticked.
      Nothing pins the agreement, so adding a kind to STRUCTURAL_KINDS would
      silently stop terminating reasoning blocks on it.
```
