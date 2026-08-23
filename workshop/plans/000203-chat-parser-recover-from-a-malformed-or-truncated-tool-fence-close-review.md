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
