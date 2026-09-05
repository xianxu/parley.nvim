# Boundary Review — parley.nvim#218 (whole-issue close)

| field | value |
|-------|-------|
| issue | 218 — Rendering: contain malformed fences within one exchange |
| repo | parley.nvim |
| issue file | workshop/issues/000218-rendering-contain-malformed-fences-within-one-exchange.md |
| boundary | whole-issue close |
| milestone | — |
| window | a543542b28895f85656513a27f9b66ac262f3049..a2c192f9ba3dd8fb3e213dd77dfbc6c35368d635 |
| command | sdlc close --issue 218 |
| reviewer | claude |
| timestamp | 2026-09-05T13:36:15-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The core of #218 is well built and genuinely verified: I reproduced all four mutations the Log claims (drop `in_code` reset → 3 red; fence token loses width → 3 red; `>=` → any-closer → 1 red; highlighter skips `reset_partition` → 1 red), the full suite is green (194 spec files, `make test` exit 0), and luacheck is clean across 347 files. What blocks SHIP is that the enumeration is still an instance, not the class: `lua/parley/outline.lua:293` holds a **third** fence tracker in that same file — the tree-outline picker — that was never swept, and I reproduced the original #218 bug through it live (a stray fence swallows every later `💬:`; the buffer picker returns 3 items on the same document, the tree picker returns 1). Two of the five claimed sites also carry no failing test: reverting the entire `skills/review` containment change leaves all eight review specs green, and both new `is_partition` call sites hardcode default `💬:`/`🤖:` prefixes, so with `chat_user_prefix = 'U:'` the outline containment does not fire at all — I reproduced that too.

## 1. Strengths

- **`M.advance` / `M.reset_partition` / `M.is_partition` is the right decomposition.** Pure functions over a plain state table, no IO, injected into two different callers with different phase needs (`highlight_structure.lua:146`, `highlighter.lua:160-161`). PQ-1's phase split is not just asserted in a comment — the pre-snapshot reset at `highlight_structure.lua:255` and the post-snapshot `advance` at `:270` do disagree exactly where they should, and `highlight_structure_spec.lua:52` still passes.
- **The fingerprint-carries-width fix (PQ-2) is real and reachable.** `classify` returns `"c3"`/`"c4"` (`highlight_structure.lua:105`), `M.replace`'s fast path rejects a width edit, and mutating the token back to a bare `TOKENS.fence` turns three tests red. This is the one that would have been easiest to ship as decoration.
- **`tests/integration/fence_containment_spec.lua` pins the render seam, not a mock.** It drives `rebuild_structure` → `highlight_question_block` and reads real extmarks; removing `reset_partition` from `highlighter.lua:160` turns it red while every unit test stays green. That is exactly the site PQ-5 warned would otherwise ship untested.
- **The second test in that spec guards against the fix becoming a no-op** — "a well-formed fence still suppresses question highlighting inside it." Good instinct.
- **The `refresh_goldens.lua` side-quest is correct** and the diff regenerates all ten goldens consistently; the golden spec passes.

## 2. Critical findings

**C1 — `lua/parley/outline.lua:293-300`: a third, unswept fence tracker; the issue's own bug is still live in the tree-outline picker.**

`build_file_outline_items` builds its own `code_memo` with the same boolean toggle and no partition reset, then gates question items on it at `:320`. The Log claims outline had "two fence scans, not one … Final count: five" — it is three, and six overall. Reproduced on a real chat file:

```
tree picker  (_build_tree_outline_items) → 📋 c.md, 💬: first question            [COUNT=2]
buffer picker (_build_picker_items)      → first / second / third question        [COUNT=3]
```

Same document, two outline paths, two answers. Fix: hoist the memo build to one shared helper (the `build_code_block_memo` at `:10` is already the right shape) and have `build_file_outline_items` call it over `file_lines`. ARCH-PURPOSE, ARCH-DRY; family `instance-not-class-sweep` — the same family PQ-4 raised, recurring for the third time, which is the ledger telling you the enumeration was never actually written down.

**C2 — `lua/parley/outline.lua:15,39` and `lua/parley/skills/review/init.lua:166`: containment is hardcoded to the default prefixes and silently does nothing under a custom `chat_user_prefix`.**

Both sites call `highlight_structure.patterns()` with no config, while `highlight_structure.build` is driven with `patterns(_parley.config)` from `highlighter.lua:127`. `_build_picker_items(bufnr, config, opts)` has `config` in hand two lines above the memo build. Reproduced with `setup({ chat_user_prefix = 'U:', chat_assistant_prefix = 'A:' })`: the stray-fence document yields `COUNT=1` — the pre-#218 behaviour, unfixed. Fix: thread `config` into `build_code_block_memo` / `is_in_code_block`, and use `get_parley().config` in `compute_fence_ranges`.

## 3. Important findings

**I1 — `lua/parley/skills/review/init.lua:171-176`: site #4 ships with no test at all.** I reverted the whole partition branch and ran `review_spec`, `review_journal_spec`, `review_mode_spec`, `review_diag_display_spec`, `review_projection_spec`, `review_menu_spec`, `skill_invoke_review_spec`, `review_journal_io_spec` — 103 assertions, 0 failures. The Done-when says "each new test is verified by mutation — reverting its change turns it red"; there is no test to revert. The Log even flags this as a **behaviour change** ("markers move in malformed documents") — that is precisely what needs pinning. A `parse_markers` unit case (stray ``` in one answer, a `🤖{…}` marker in the next) costs three lines.

**I2 — `lua/parley/skills/review/init.lua:176`: `^```` now systematically misses the fences the new prompt tells models to indent.** `defaults.lua:31` instructs the model to indent every fence by two spaces; `compute_fence_ranges` matches only column-zero backticks. Every other fence scan in the tree uses `^%s*```` . Net effect: brackets inside model-authored code fences stop being excluded from marker parsing, regressing #125's guarantee for the now-normal output shape. The diff created a shared `is_partition` but left its sibling — the fence-open predicate — in six hand-maintained copies (`highlight_structure.lua:86`, `outline.lua:22,44,296`, `review/init.lua:176`, plus `copy.lua:16,32`). Export one predicate and derive them. ARCH-DRY.

**I3 — `lua/parley/config.lua:234-255`: the indentation convention lands in one of five shipped system prompts.** Only `default` derives from `defaults.chat_system_prompt`; `creative`, `concise`, `teacher`, `code_reviewer` are one `<C-g>P` away and carry no convention, so switching prompt silently changes how malformed output renders. Shadow-sweep: the convention is a hand-maintained restatement in one consumer. Fix: name it once (`defaults.fence_indent_convention`) and append it to every shipped prompt, or concatenate it at the seam that assembles the system prompt. ARCH-PURPOSE.

**I4 — `scripts/refresh_goldens.lua:38-44`: reintroduces the exact hand-sync `scripts/golden_fixture.lua` exists to abolish.** `provider = "cliproxyapi"` / `model = { model = "gpt-5.6-sol" }` is now duplicated against `tests/unit/parley_harness_golden_spec.lua:62-63`, with a comment that says so out loud ("pinned exactly as the verifier pins them"). `golden_fixture.lua`'s own header: "a golden must depend on nothing a person has to remember." Add `M.OPENAI_WIRE = { provider = …, model = … }` there and have both sides consume it. ARCH-DRY.

**I5 — `atlas/traceability.yaml:599-608`: the new spec is registered nowhere.** `tests/integration/fence_containment_spec.lua` appears in no mapping, and `ui/highlights` lists `highlighter.lua` but not `highlight_structure.lua`. So `make test-changed` after editing `atlas/ui/highlights.md` — the file this very diff edited — does not run the containment spec. Add both to `ui/highlights`.

## 4. Minor findings

- `lua/parley/highlighter.lua:148` + `:192` — `classify` is now called twice per line per redraw; reuse `classified`. ARCH-CONSTRAINTS (decoration path).
- `lua/parley/highlighter.lua:155-161` — the `walk` table is allocated per line per redraw, and `advance` writes `in_question`/`in_reasoning` into it which the caller discards while maintaining its own copies at `:245-252`. The comment "Both now go through the ONE transition function" overstates: only three of six fields do. Hoist the table out of the loop and say in the comment which fields the caller owns.
- `atlas/ui/highlights.md:35` — "CommonMark: up to 3 spaces of indent" is not what the code does; `^%s*```` accepts any run of whitespace including tabs and ≥4 spaces. Relatedly `defaults.lua:33` tells the model that four spaces makes the markers "literal visible text" — true in a CommonMark renderer, not in parley's own highlighter.
- `lua/parley/outline.lua:36-49` — the lazy fallback's containment fix is effectively unreachable: `build_code_block_memo` populates every line, and both callers pre-build it. Reverting it turns nothing red. Either drop the fallback or note it as dead.
- `lua/parley/copy.lua:16,32` — `copy_code_fence` scans up/down for the nearest ``` with no partition bound, so it can pair an opener from the previous exchange with a closer in this one. Different shape from the trackers, lower blast radius, but the same class.

## 5. Test coverage notes

- Mutation verification of the four claimed changes **reproduces exactly** — the Log's table is accurate for what it covers.
- Two of five sites are unpinned: `skills/review` (I1, mutation-green across all eight review specs) and the outline lazy fallback (mutation-green across `picker_items_spec` + `outline_spec`). C1's site has no test because it has no fix.
- The property test at `highlight_structure_spec.lua:200` is deterministic (`randomseed(218)`) and does go red under mutation, but its invariant — `in_code == false` at partition rows — is what `reset_partition` guarantees by construction. It generates only 💬:/🤖:, never 🔒:/🌿:, and never indented fences. A stronger invariant would be "state at row N equals a from-scratch build of the turn containing N."
- ARCH-ORDER: no test compares the incremental `M.replace` path against a full rebuild over a *sequence* of edits. The width-invalidation test observes one interleaving. The fingerprint argument makes this sound, but the seam to inject an edit sequence is cheap and would pin it.

## 6. Architectural notes

- **ARCH-DRY** — flag (I2, I4, and the double `classify`). The diff correctly extracted `is_partition`, then stopped one predicate short of the one that actually differs across the six sites.
- **ARCH-PURE** — pass. `advance`/`reset_partition`/`is_partition` are deterministic over a state table; IO stays in the highlighter and outline shells; the render test drives the real seam rather than a mock.
- **ARCH-PURPOSE** — flag (C1, I3). Two shadow-sweeps left incomplete, both of which the plan-quality gate had already named as the failure mode.
- **ARCH-MOCK** — N/A. No new external binary or service; the golden regenerator is offline against file fixtures.
- **ARCH-CONSTRAINTS** — pass with a Minor. `perf_chat_typing_spec`'s structural bounds gates are green. `is_partition` → full `classify` per line makes the outline memo ~6× more pattern-matching than before; not on the keystroke path, but worth a cheap prefix-only predicate if the tree picker grows.
- **ARCH-SECURE** — pass. Malformed model output is the untrusted input, and containment makes the failure local and visible rather than fabricating downstream state; `tonumber(token:sub(2)) or 0` degrades to "closes", not a crash. No credentials in scope.
- **ARCH-ORDER** — pass on the fix, Minor on the oracle. The width-carrying fingerprint closes the real cross-event staleness hole (mutation-confirmed); the gap is the missing multi-edit equivalence test noted above.

## 7. Plan revision recommendations

Append a `## Revisions` entry to `workshop/issues/000218-…md` recording:

1. **The enumeration is six, not five.** `outline.lua` has **three** fence scans (`:10`, `:36`, `:293`), not two; `copy.lua:16,32` is a fourth shape. The 2026-09-05 "implemented" Log entry states five and must be corrected — it is the claim that let C1 through.
2. **Two of the swept sites are unpinned.** The mutation table lists four reverts; sites #4 (`skills/review`) and the outline lazy fallback were not among them and stay green when reverted. The Done-when "each new test is verified by mutation" is not met as written.
3. **Containment is config-blind.** Both `is_partition` call sites use default prefixes; the Done-when "all trackers reset at partitions" holds only for unconfigured `chat_user_prefix`/`chat_assistant_prefix`.
4. **The test-plan row cites the wrong file.** The Plan names `tests/unit/highlighter_spec.lua` for the render seam; it landed as `tests/integration/fence_containment_spec.lua` (a better choice — record it, and register it in `atlas/traceability.yaml`).
5. **The two-space convention has four non-deriving consumers.** The Log presents it as resolved by the `defaults.lua` change; the other four shipped `system_prompts` entries do not carry it.

```findings
findings:
  - id: new
    severity: Critical
    family: instance-not-class-sweep
    title: |
      outline.lua has a THIRD unswept fence tracker; #218's bug is live in the tree-outline picker
    detail: |
      build_file_outline_items builds its own code_memo at lua/parley/outline.lua:293-300
      with the same boolean toggle and no partition reset, gating question items at :320.
      Reproduced: on one chat file with a stray fence, the tree picker returns 2 items
      (topic + first question) while the fixed buffer picker returns 3. The Log's claim
      that outline had "two fence scans, not one" and that the final count is five is
      wrong — outline has three, and copy.lua carries a fourth shape. ARCH-PURPOSE,
      ARCH-DRY. Hoist the memo build into one shared helper both outline paths call.
  - id: new
    severity: Critical
    family: config-ignored-at-new-seam
    title: |
      Both new is_partition call sites hardcode default prefixes, so containment does nothing under a custom chat_user_prefix
    detail: |
      outline.lua:15,39 and skills/review/init.lua:166 call highlight_structure.patterns()
      with no config, while highlight_structure.build is driven with patterns(_parley.config).
      Reproduced with setup({chat_user_prefix='U:', chat_assistant_prefix='A:'}): the
      stray-fence document yields COUNT=1, i.e. the pre-218 bug, unfixed. config is
      already in hand at _build_picker_items(bufnr, config, opts) and via
      get_parley().config in the review skill.
  - id: new
    severity: Important
    family: fix-without-failing-test
    title: |
      The skills/review containment change ships with no test — reverting it leaves all eight review specs green
    detail: |
      Reverting the entire partition branch at skills/review/init.lua:171-176 and running
      review_spec, review_journal_spec, review_mode_spec, review_diag_display_spec,
      review_projection_spec, review_menu_spec, skill_invoke_review_spec and
      review_journal_io_spec gives 103 assertions, 0 failures. The issue's Done-when
      requires every change be mutation-verified, and the Log itself calls this a
      behaviour change ("markers move in malformed documents") — the exact thing that
      needs pinning. A parse_markers case with a stray fence in one answer and a marker
      in the next costs three lines.
  - id: new
    severity: Important
    family: single-source-bypassed
    title: |
      compute_fence_ranges matches only ^``` , so it misses every fence the new prompt convention tells models to indent
    detail: |
      defaults.lua:31 now instructs the model to indent every fence by two spaces, while
      skills/review/init.lua:176 matches only column-zero backticks; every other fence
      scan in the tree uses ^%s*```. Brackets inside model-authored code fences therefore
      stop being excluded from marker parsing, regressing #125 for the now-normal output
      shape. The diff created a shared is_partition but left the sibling fence-open
      predicate in six hand-maintained copies (highlight_structure.lua:86,
      outline.lua:22,44,296, review/init.lua:176, copy.lua:16,32). ARCH-DRY.
  - id: new
    severity: Important
    family: convention-not-derived-by-consumers
    title: |
      The two-space fence convention lands in one of five shipped system prompts
    detail: |
      config.lua:234-255 ships default, creative, concise, teacher and code_reviewer;
      only default derives from defaults.chat_system_prompt. The others are one
      ParleySystemPrompt away and carry no convention, so switching prompt silently
      changes how malformed output renders. Name the convention once and append it to
      every shipped prompt, or concatenate it where the system prompt is assembled.
      ARCH-PURPOSE shadow-sweep.
  - id: new
    severity: Important
    family: single-source-bypassed
    title: |
      refresh_goldens.lua re-hardcodes the openai provider/model that golden_fixture.lua exists to single-source
    detail: |
      scripts/refresh_goldens.lua:41-42 duplicates provider="cliproxyapi" and
      model={model="gpt-5.6-sol"} against tests/unit/parley_harness_golden_spec.lua:62-63,
      with a comment saying so ("pinned exactly as the verifier pins them").
      golden_fixture.lua's header condemns exactly this ("a golden must depend on nothing
      a person has to remember"). Add M.OPENAI_WIRE there and consume it on both sides.
  - id: new
    severity: Important
    family: traceability-unmapped
    title: |
      The new containment spec is registered in no atlas/traceability.yaml entry
    detail: |
      tests/integration/fence_containment_spec.lua appears nowhere in traceability.yaml,
      and ui/highlights (:599-608) lists highlighter.lua but not highlight_structure.lua.
      So `make test-changed` after editing atlas/ui/highlights.md — the file this diff
      edited — does not run the spec that pins this issue.
  - id: new
    severity: Minor
    family: redundant-recompute-on-render-path
    title: |
      classify is called twice per line per redraw in compute_chat_highlights
    detail: |
      highlighter.lua:148 computes `classified` and :192 recomputes the same thing as
      `classification`. Reuse the first. ARCH-CONSTRAINTS, decoration path.
  - id: new
    severity: Minor
    family: shared-transition-partial-ownership
    title: |
      advance writes in_question/in_reasoning into the highlighter's walk table and the caller discards them
    detail: |
      highlighter.lua:155-161 allocates a walk table per line per redraw and copies back
      only in_code, code_fence_len and in_tool; in_question/in_reasoning stay owned by the
      loop at :245-252. The comment's claim that "Both now go through the ONE transition
      function" holds for three of six fields. Hoist the table out of the loop and state
      which fields the caller owns.
  - id: new
    severity: Minor
    family: doc-overstates-implementation
    title: |
      atlas claims a 3-space CommonMark indent limit the code does not enforce
    detail: |
      atlas/ui/highlights.md:35 says "up to 3 spaces of indent", but ^%s*``` accepts any
      whitespace run including tabs and four-plus spaces. Relatedly defaults.lua:33 tells
      the model four spaces makes the markers literal text — true in a CommonMark renderer,
      not in parley's highlighter.
  - id: new
    severity: Minor
    family: unreachable-guard
    title: |
      The outline lazy-fallback containment fix is unreachable and pins nothing
    detail: |
      outline.lua:36-49 only runs when memo[line_number] is nil, but build_code_block_memo
      populates every line and both callers pre-build it. Reverting the :42 partition reset
      turns nothing red. Either drop the fallback or record it as dead.
  - id: new
    severity: Minor
    family: instance-not-class-sweep
    title: |
      copy_code_fence pairs fences across a turn boundary
    detail: |
      copy.lua:16,32 scans up then down for the nearest ``` with no partition bound, so a
      stray opener in the previous exchange can pair with a closer in this one. Different
      shape from the accumulating trackers and much lower blast radius, but the same class
      and it belongs in the enumeration.
  - id: new
    severity: Minor
    family: atlas-stale-for-changed-surface
    title: |
      atlas/ui/outline.md still states the pre-218 rule
    detail: |
      ":13 Lines inside code blocks (``` / ~~~) are excluded" no longer tells the whole
      story now that a column-zero turn marker ends the fence. lua/parley/outline.lua
      changed in this window; its atlas page did not.
```

---

## Re-review — 2026-09-05T13:55:49-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 218 — Rendering: contain malformed fences within one exchange |
| repo | parley.nvim |
| issue file | workshop/issues/000218-rendering-contain-malformed-fences-within-one-exchange.md |
| boundary | whole-issue close |
| milestone | — |
| window | a543542b28895f85656513a27f9b66ac262f3049..ebc9bef2f195e98404ed876d9f0184f477beb909 |
| command | sdlc close --issue 218 |
| reviewer | claude |
| timestamp | 2026-09-05T13:55:49-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The rework is substantially real: I reproduced red-on-revert for BR-1 (tree-outline memo), BR-2's outline half, BR-3 and BR-4; the six hand-rolled fence walks really are consolidated into `is_partition` / `is_fence_delim` / `code_block_memo`; the convention is single-sourced as `defaults.fence_indent_convention`; `OPENAI_WIRE` is shared; traceability now maps the containment spec. Full suite green (194 spec files, `make test` exit 0), luacheck clean across 347 files. What blocks SHIP is that the class is *still* one instance short, and this time the diff caused the breakage rather than inheriting it: `lua/parley/exporter.lua:352` pairs fences with a whole-document `gsub` whose closer must be at column zero, so the two-space convention this very window added to all five shipped system prompts makes the HTML exporter swallow the closing fence, the following prose, and the next two turns into one `<pre><code>` block. I reproduced that against the real pattern. Secondarily, three of this round's own fixes revert green — the same Done-when the round claimed to have satisfied.

## 1. Strengths

- **The consolidation is genuine and mutation-confirmed.** Restoring the private third memo in `build_file_outline_items` turns `picker_items_spec` red on exactly one test; reverting `patterns(config)` → `patterns()` at `outline.lua:17,265` turns the custom-prefix test red; reverting the partition branch at `skills/review/init.lua:175` and swapping `is_fence_delim` back to `^```` each turn `review_spec` red on exactly the intended case. Four independent reverts, four correct reds.
- **`highlight_structure.lua:146-256` is the right shape.** `advance` / `reset_partition` / `is_partition` / `is_fence_delim` / `code_block_memo` are pure over plain tables; `code_block_memo` takes `lines`, not a `bufnr`, so outline's IO stays in its own `build_code_block_memo` wrapper. External consumers all read `.kind`, never `.token`, so widening the fence token to `c3`/`c4` drifted nothing (`fold_projection.lua:102`, `chat_parser.lua:539,755`, `chat_respond.lua:1679` all verified).
- **The BR-3 recurrence was caught by actually running the check.** The Log's admission that the BR-2 config fix came back green on the first mutation pass, and needed its own outline-level test, is the correct failure mode to have found and recorded.
- **`golden_fixture.lua:38` `M.OPENAI_WIRE`** cleanly closes BR-6, and the shadowing `local golden = read_json(...)` at `parley_harness_golden_spec.lua:65` is legal Lua (the outer `golden` is what `:62-63` binds) — I checked, it is not the bug it looks like.
- **The default prompt's convention is incidentally pinned** by the twelve regenerated golden payloads, which is why BR-5's *default* half cannot silently regress.

## 2. Critical findings

**C1 — `lua/parley/exporter.lua:352`: the two-space convention this window introduced breaks HTML export; a seventh fence pairing was never enumerated.**

`html:gsub("```([^\n]*)\n(.-)\n```", …)` requires the closing run to sit immediately after a newline, so an indented closer never matches and the scan runs on to the next flush-left fence anywhere in the document. Reproduced against the real pattern on the shape the prompt now asks for:

```
input:  🤖: answer one / "  ```lua" / "  local x = 1" / "  ```" /
        "Prose that must NOT be inside a code block." / 💬: next question /
        🤖: answer two / "```" / "flush block" / "```"

output: <CODE lang=lua>  local x = 1
          ```
        Prose that must NOT be inside a code block.
        💬: next question
        🤖: answer two</CODE>
        flush block            ← left bare, its own fence consumed
```

`tests/unit/pure_functions_spec.lua:163,170` cover only flush-left fences, so nothing goes red. It is also a cross-exchange pairing with no partition bound — the identical shape as BR-12's `copy.lua`, which this round *did* fix.

**This is the 3rd finding in family `instance-not-class-sweep`.** Rounds 1 and 2 fixed instances: the plan gate named one tracker, implementation found a fifth, close review found a sixth and seventh, and here is an eighth. Do NOT fix only `exporter.lua:352`. State the rule and enforce it: *a triple-backtick predicate may exist only in `highlight_structure.is_fence_delim` (prose) and `fence.lua` (tool bodies); every other consumer derives from one of those.* This repo already owns the mechanism — `tests/arch/single_source_sweeps_spec.lua` exists precisely because "a sweep without a guard is a snapshot: it says nothing about the ninth copy," and it got no `#218` entry. Measured prevalence after this round: `grep -rn '\`\`\`' lua/` leaves `exporter.lua:352` and `chat_respond.lua:811` as hand-rolled matchers outside the two sanctioned modules; `exporter.lua` is already mapped in `atlas/traceability.yaml` (three entries), so a guard there runs today.

## 3. Important findings

**I1 — three of this round's fixes revert green, measured.** The Done-when says "each new test is verified by mutation — reverting its change turns it red." I reverted each of this round's changes and ran the mapped specs:

| change | revert result |
|---|---|
| `skills/review/init.lua:169` live-config threading (BR-2's review half) | `review_spec` 47 ok / 0 fail — **green** |
| `copy.lua:15-16,20,39` partition bound (BR-12) | no `copy` spec exists anywhere in `tests/`; nothing to run |
| `config.lua:242,247,252,257` convention on four prompts (BR-5) | stripped all four; `custom_prompts_spec`, `config_tools_spec`, `build_messages_spec`, `picker_items_spec`, `pure_functions_spec` all **green** |

**This is the 2nd finding in family `fix-without-failing-test`.** Do not spot-add one test for the review skill. The rule that covers all three: *the mutation ledger must be generated from the round's own diff hunks, not from the list of changes the author remembers making* — enumerate every behavioural hunk in `git diff <round-base>..HEAD -- lua/`, revert each, and record the ones with no red. The two cheap guards that fall out: a `parse_markers` case driven through a configured `chat_user_prefix`, and an arch assertion that every entry in `config.system_prompts` contains `defaults.fence_indent_convention` (which also guards the sixth prompt someone adds later).

## 4. Minor findings

- `lua/parley/config.lua:242,247,252,257` — the convention is concatenated straight onto a sentence-final `.` with no separator, so `creative`/`concise`/`teacher`/`code_reviewer` ship "…in your responses.Indent every fenced code block…". The `default` prompt is fine only because `defaults.lua:46` happens to end in `\n\n`.
- `lua/parley/copy.lua:2` still reads "Pure utility module — no parley module dependencies", which this diff made false (`require("parley.highlight_structure")`, `require("parley").config`). Relatedly the atlas table at `atlas/ui/highlights.md:35` presents `code_block_memo`'s grammar as CommonMark ">= closer", but `code_block_memo` is a plain boolean toggle — only `advance` implements the width rule. **This is the 2nd finding in family `doc-overstates-implementation`** (BR-10 is still open below): the rule is that a comment or atlas row asserting a code property needs a grep-able referent, and the three live instances (atlas:35, atlas:45, copy.lua:2) should be swept together rather than patched one at a time.
- `lua/parley/copy.lua` appears in no `atlas/traceability.yaml` `code:` list, so `make test-changed` can never reach the containment fix it received. **This is the 2nd finding in family `traceability-unmapped`.** Prevalence measured: 22 of 146 `lua/` modules are unmapped, so the rule-level answer is either an arch guard requiring every module to appear in exactly one `code:` list, or an explicit allowlist — not a one-line addition for `copy.lua`.
- `lua/parley/highlight_structure.lua:180,219` — `is_partition(line, patterns or M.patterns())` silently substitutes default prefixes when `patterns` is nil, and `code_block_memo`'s docstring says patterns "MUST come from the live config" while nothing enforces it. **This is the 2nd finding in family `config-ignored-at-new-seam`**: the rule is to make the invalid state unrepresentable at the seam (`assert(patterns, …)`) rather than to fix each caller, which is what BR-2 already had to do twice.

## 5. Test coverage notes

- Mutation reproduction for BR-1, BR-2(outline), BR-3, BR-4: **all four confirmed red**, one test each, no collateral.
- The new `highlight_structure_spec` block (`:195-309`) is the strongest addition — the property test, the CommonMark shorter-run case, the width-invalidation `replace` case, and the two `code_block_memo` cases including the configured-prefix one.
- `tests/integration/fence_containment_spec.lua` drives `rebuild_structure` → `highlight_question_block` and reads real extmarks; its second test guards against the fix degenerating into a no-op. Good.
- Gaps: `lua/parley/copy.lua` has **zero** test coverage in the tree; `exporter.lua`'s fence tests cover only flush-left; no test asserts any shipped `system_prompts` entry carries the convention; still no `M.replace`-vs-rebuild equivalence test over a *sequence* of edits (round 1 noted this; unchanged).

## 6. Architectural notes

- **ARCH-DRY** — flag (C1). Six copies became one shared predicate, which is the right move; the seventh survived because the sweep has no fitness guard, and `tests/arch/single_source_sweeps_spec.lua` is the file that exists to hold one.
- **ARCH-PURE** — pass. `advance`, `reset_partition`, `is_partition`, `is_fence_delim`, `code_block_memo` are deterministic over plain tables; IO stays in the outline/highlighter/copy shells; the render test drives the real seam, not a mock.
- **ARCH-PURPOSE** — flag (C1, I1). The purpose is *the class*, and the class enumeration is still being discovered by the reviewer rather than written down by the plan.
- **ARCH-MOCK** — N/A. No new external binary or service; the golden regenerator is offline over file fixtures and now shares `OPENAI_WIRE` with the verifier.
- **ARCH-CONSTRAINTS** — pass with a note. `code_block_memo` runs a full `classify` (≈12 patterns plus a `require("parley.define")`) per line where the old loop ran two `line:match`es; every caller (`find_nearest_outline_line`, `_build_picker_items`, `build_file_outline_items`) is a user-triggered picker/jump path, and `perf_chat_typing_spec` is green. The render path still pays BR-8's double `classify` (`highlighter.lua:148` and `:192`) and BR-9's per-line `walk` allocation (`:155`).
- **ARCH-SECURE** — pass. Malformed model output is the untrusted input and containment makes the failure local and visible; `is_fence_delim` type-guards non-strings, `classify` nil-guards, `tonumber(token:sub(2)) or 0` degrades to "closes" rather than crashing, and the `pcall` at `skills/review/init.lua:169` degrades to defaults. No credentials in scope. The one soft spot is the nil-`patterns` default noted above.
- **ARCH-ORDER** — pass on the state model, flag on the oracle (unchanged from round 1). The width-carrying fingerprint closes the real cross-event staleness hole and is mutation-confirmed; the missing seam is a multi-edit `replace`-vs-rebuild equivalence test, which would observe more than one interleaving.

## 7. Plan revision recommendations

Append a `## Revisions` section to `workshop/issues/000218-…md` (the corrections currently live only as narrative in `## Log`, where the ledger cannot read them):

1. **The enumeration is eight, not six.** `## Problem`'s table still says four. Add `exporter.lua:352` (whole-document `gsub`, column-zero closer, no partition bound) and restate the class as *"every fence predicate in `lua/` derives from `highlight_structure.is_fence_delim` or `fence.lua`"*, with the fitness guard as the deliverable rather than another site fix.
2. **Done-when "each new test is verified by mutation" is still not met.** Name the three changes that revert green (review-skill live config, `copy.lua`, the four non-default prompts) and record how the mutation ledger will be derived from the diff rather than from recall.
3. **The two-space convention has a breaking consumer.** The Log presents the convention as verified in code; record that it regressed HTML export and that the convention's introduction needs a consumer sweep of its own.
4. **The two-grammar table is aspirational for `code_block_memo`.** `atlas/ui/highlights.md:35` describes a CommonMark ">= closer" rule that only `advance` implements; either implement it in `code_block_memo` or narrow the atlas row.

Prior-round dispositions and this round's new findings:

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      All three outline memos now call highlight_structure.code_block_memo; restoring the private build turns the tree-outline test red.
  - id: BR-2
    disposition: addressed
    note: |
      Both sites thread live config; outline half is mutation-red, review half is correct in code but unpinned (see I1).
  - id: BR-3
    disposition: addressed
    note: |
      review_spec now has three containment cases; reverting the partition branch turns one red.
  - id: BR-4
    disposition: addressed
    note: |
      is_fence_delim is shared and the indented-fence case goes red when swapped back to a column-zero match.
  - id: BR-5
    disposition: addressed
    note: |
      Convention single-sourced onto all five prompts; code is right but nothing pins it (see I1) and the concatenation lacks a separator.
  - id: BR-6
    disposition: addressed
    note: |
      golden_fixture.M.OPENAI_WIRE is consumed by both the regenerator and the verifier.
  - id: BR-7
    disposition: addressed
    note: |
      ui/highlights now lists highlight_structure.lua plus both specs.
  - id: BR-8
    disposition: not-addressed
    note: |
      classify is still computed at highlighter.lua:148 and recomputed at :192.
  - id: BR-9
    disposition: not-addressed
    note: |
      The per-line walk table at highlighter.lua:155 is unchanged and the comment still overstates field ownership.
  - id: BR-10
    disposition: not-addressed
    note: |
      defaults.lua was qualified, but atlas/ui/highlights.md was not touched by f1818ee; :35 still claims a 3-space limit and :45 the unqualified four-space claim.
  - id: BR-11
    disposition: addressed
    note: |
      The lazy fallback is gone; is_in_code_block is now a pure memo read.
  - id: BR-12
    disposition: addressed
    note: |
      Both copy.lua scans break at a partition — though nothing tests copy.lua at all (see I1).
  - id: BR-13
    disposition: not-addressed
    note: |
      atlas/ui/outline.md:13 still states the pre-218 rule; the file is unchanged in this window.
findings:
  - id: new
    severity: Critical
    family: instance-not-class-sweep
    title: |
      The new two-space convention breaks HTML export — exporter.lua pairs fences across turns and only closes at column zero
    detail: |
      lua/parley/exporter.lua:352 does html:gsub("```([^\n]*)\n(.-)\n```", ...). The
      closer must follow a newline directly, so an indented closer never matches and the
      scan runs to the next flush-left fence anywhere in the document. Reproduced against
      the real pattern: an indented block plus following prose, the next 💬: question and
      the next 🤖: answer are all swallowed into one code block, and the following
      flush-left block is left bare. tests/unit/pure_functions_spec.lua:163,170 cover only
      flush-left fences so nothing goes red. This is also a cross-exchange pairing with no
      partition bound — the same shape as BR-12's copy.lua. THIRD finding in this family:
      do not patch only this site. State the rule (a triple-backtick predicate may exist
      only in highlight_structure.is_fence_delim for prose and fence.lua for tool bodies)
      and enforce it in tests/arch/single_source_sweeps_spec.lua, which exists for exactly
      this and received no 218 entry. Prevalence after this round: exporter.lua:352 and
      chat_respond.lua:811 are the remaining hand-rolled matchers in lua/.
  - id: new
    severity: Important
    family: fix-without-failing-test
    title: |
      Three of this round's own fixes revert green — the mutation ledger was built from recall, not from the diff
    detail: |
      Measured by revert: skills/review/init.lua:169 live-config threading leaves
      review_spec at 47 ok / 0 fail; copy.lua's partition bound has no spec anywhere in
      tests/; stripping fence_indent_convention from all four non-default prompts in
      config.lua:242,247,252,257 leaves custom_prompts_spec, config_tools_spec,
      build_messages_spec, picker_items_spec and pure_functions_spec green. SECOND finding
      in this family — do not spot-add one test. The rule: generate the mutation ledger
      from the round's own behavioural hunks (git diff round-base..HEAD -- lua/), revert
      each, and record the ones with no red. Two cheap guards fall out: a parse_markers
      case driven through a configured chat_user_prefix, and an arch assertion that every
      config.system_prompts entry contains defaults.fence_indent_convention.
  - id: new
    severity: Minor
    family: shared-fragment-missing-separator
    title: |
      The convention is concatenated onto a sentence-final period in four of five prompts
    detail: |
      config.lua:242,247,252,257 append fence_indent_convention directly after "...in your
      responses." with no separator, producing "responses.Indent every fenced code block".
      The default prompt escapes this only because defaults.lua:46 ends in a double
      newline. Give the fragment a leading "\n\n" or add the separator at each seam.
  - id: new
    severity: Minor
    family: doc-overstates-implementation
    title: |
      copy.lua's header now contradicts the file, and the atlas grammar table overstates code_block_memo
    detail: |
      copy.lua:2 still reads "Pure utility module — no parley module dependencies" after
      the diff added require("parley.highlight_structure") and require("parley").config.
      atlas/ui/highlights.md:35 attributes a CommonMark ">= closer" rule to
      highlight_structure, but only M.advance implements it — M.code_block_memo (the
      helper outline, review and copy all use) is a plain boolean toggle. SECOND finding
      in this family, with BR-10 still open: the rule is that any comment or atlas row
      asserting a code property needs a grep-able referent, and the three live instances
      (atlas:35, atlas:45, copy.lua:2) should be swept together.
  - id: new
    severity: Minor
    family: traceability-unmapped
    title: |
      lua/parley/copy.lua changed in this window and is in no traceability code list
    detail: |
      make test-changed can never reach copy.lua's containment fix — it is in no atlas
      entry and has no spec. SECOND finding in this family. Measured prevalence: 22 of 146
      lua/ modules are unmapped, so the rule-level answer is an arch guard requiring every
      module to appear in exactly one code: list (or an explicit allowlist), not a one-line
      addition for copy.lua.
  - id: new
    severity: Minor
    family: config-ignored-at-new-seam
    title: |
      is_partition and code_block_memo still silently substitute default prefixes when patterns is nil
    detail: |
      highlight_structure.lua:180 does patterns or M.patterns(), and :219's docstring says
      patterns "MUST come from the live config" while nothing enforces it — the exact state
      BR-2 was about is still representable at the seam. SECOND finding in this family: the
      rule is to make it unrepresentable (assert on nil at the seam) rather than to audit
      each caller, which BR-2 already had to do twice.
```

---

## Re-review — 2026-09-05T14:17:11-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 218 — Rendering: contain malformed fences within one exchange |
| repo | parley.nvim |
| issue file | workshop/issues/000218-rendering-contain-malformed-fences-within-one-exchange.md |
| boundary | whole-issue close |
| milestone | — |
| window | a543542b28895f85656513a27f9b66ac262f3049..5cfa801240f663de8cf69d678aaa9b799f5cdc86 |
| command | sdlc close --issue 218 |
| reviewer | claude |
| timestamp | 2026-09-05T14:17:11-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

All inspections completed: full suite green (195 spec files, luacheck 0/0 across 348, `make test` exit 0), and I mutation-verified the round-2 claims independently.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The core of #218 is now genuinely solid and I could not break it. I property-checked the builder against the highlighter's per-window walk over 500 random fence/partition interleavings from random start rows — zero drift — and re-ran the round-2 mutation ledger myself rather than trusting it: reverting `exporter.lua` turns 2 specs red, `copy.lua` 2, the review skill's live-config threading 1, and stripping `fence_indent_convention` from the four non-default prompts 1. BR-14 and BR-15 are really fixed, and the `is_partition` assert (BR-19) is reachable and load-bearing. What blocks a clean SHIP is that the BR-14 rewrite traded one exporter defect for another: the old document-wide gsub guaranteed a blank line on each side of the emitted `<div class="code-block">`, the new line-based scan joins with single newlines, and so the div now nests inside `<p class='paragraph'>` for every fence not separated by a blank line — 175 of 256 fence delimiters in this repo's own chat files and transcripts. The three new exporter tests assert only that the text survives, so nothing goes red. Second Important: the convention's enforcement enumerates `config.system_prompts` but not `config.agents[*].system_prompt`, the other config-level prompt source `agent_info.resolve` reads.

## 1. Strengths

- **`advance` / `reset_partition` with an explicit phase split is the right shape** (`lua/parley/highlight_structure.lua:130-171`, `lua/parley/highlighter.lua:148-162`). I wrote an independent property check — 500 random documents of fence runs (3–5 ticks, flush and indented), partitions and tool markers, walked from a random start row — asserting the highlighter's post-`advance` state equals the next row's `state_before` after its own reset. Zero divergence. This is ARCH-ORDER done properly: the transition set is readable off one function and the two consumers cannot disagree.
- **The width-carrying fingerprint closes a real per-keystroke staleness hole** (`highlight_structure.lua:105`, consumed at `:352-358`). `M.replace`'s fast path reuses `state_before` verbatim; `"c"..n` makes an in-place ``` → ```` edit invalidate. Mutation-verified red.
- **The arch guard actually fires and is not vacuous** (`tests/arch/single_source_sweeps_spec.lua:254`). It enumerates 146 real files, and reverting either `copy.lua` or `exporter.lua` turns it red alongside the behavioural spec. The `chat_respond.lua` allowance is correctly justified as a typed envelope rather than a fence predicate.
- **BR-19's answer is the right one** — making the state unrepresentable, not auditable. Verified: `is_partition("💬: q")` and `code_block_memo({"a"}, nil)` both raise; only the empty-`lines` case slips through vacuously.
- **`refresh_goldens.lua` + `OPENAI_WIRE`** genuinely removes the hand-sync (`scripts/golden_fixture.lua:38`), and the golden spec's decoded-table comparison keeps it from flaking on key order.

## 2. Critical findings

None. BR-14 is confirmed fixed by revert.

## 3. Important findings

**(a) `lua/parley/exporter.lua:361-392` — the BR-14 rewrite drops the blank lines the old gsub guaranteed, so code blocks now nest inside `<p>`.**

The old `html:gsub("```([^\n]*)\n(.-)\n```", ...)` returned `'\n<div …></div>\n'`, and because the consumed text was itself newline-terminated on both sides the result always had `\n\n` around the div — which is what made the later `html:gsub("\n\n+", …)` split it into its own paragraph and the `<p[^>]*>%s*<div` / `</div>%s*</p>` cleanups fire. The new scan appends the div as one `out` entry joined with single `"\n"`, so those cleanups no longer match. Measured against the base implementation on the same input:

- before: `<p>🤖: Here is how:</p>` … `<div class="code-block">…</div>` … `<p>Then run it.</p>`
- after: `<p class='paragraph'>` `🤖: Here is how:` `<div class="code-block">…</div>` `Then run it.` `</p>`

Browsers implicitly close the `<p>` at the `<div>`, so the trailing prose loses its `.paragraph` styling and the `</p>` is stray. Prevalence: 175 of 256 fence-delimiter lines across `workshop/parley/*.md` and `tests/fixtures/transcripts/*.md` are preceded by a non-blank line, so this is the majority shape, not an edge case. Fix sketch: emit `out[#out+1] = ""` immediately before and after the div (restoring the old invariant), and add the assertion the three new tests are missing — that the div is not inside a paragraph, e.g. `assert.is_nil(html:match("<p[^>]*>[^<]*<div class=\"code%-block\""))`.

**(b) `tests/arch/single_source_sweeps_spec.lua:290` + `lua/parley/config.lua:224` — the convention guard enumerates one of two config-level prompt sources.**

**This is the 2nd finding in family `convention-not-derived-by-consumers`.** Earlier rounds fixed instances (BR-5 added the convention to the four missing `system_prompts`). Do not fix this instance — state the rule. The rule: *every prompt string in shipped config that `agent_info.resolve` can select must contain `defaults.fence_indent_convention`, and the enumeration must be derived from config rather than hand-picked.* `agent_info.lua:48-50` resolves `system_prompts[selected].system_prompt` **or `agent.system_prompt`**; `config.lua:199` documents `system_prompt` as a mandatory agent field and `config.lua:224` supplies one. Today it passes by construction (it reuses `chat_system_prompt`), so the guard is green while covering only one arm. Extend the same loop over `config.agents`. The second, non-enforceable arm of the class is user-supplied prompts: `README.md:214` explicitly tells users `system_prompts` merge by name, and a chat header `system_prompt:` replaces the prompt wholesale — neither carries the convention, and nothing tells the user that dropping it changes how malformed model output renders. That belongs in README (Docs gate) rather than in a guard.

## 4. Minor findings

- `code_block_memo` costs ~20× the inline toggles it replaced — measured 6.06 ms vs 0.31 ms per 5,000-line buffer, because `is_partition` runs the full classifier (~10 patterns plus a footnote lookup) per line. `fold_projection.lua:111` documents avoiding exactly this cost. On-demand picker path, so not urgent; a cheap prefix pre-check before `classify` recovers it. `make perf` was not run for this window. ARCH-CONSTRAINTS.
- The fence-matcher arch guard only fires when the literal ``` and the `match(`/`gsub(`/`find(` call are on the **same line**. A hoisted pattern constant, or a backtick-run pattern with no literal triple, evades it — `exporter.lua:375`'s `"^%s*`+%s*([%w_+-]*)"` is already invisible to it (benign, it is lang extraction, not a predicate).
- `exporter.lua:363` reaches for `require("parley").config` although the module already holds the injected `_parley` handle (`exporter.lua:2`, used at `:37`, `:693`, `:750`) — two ways into the same dependency in one file.
- `outline.lua:21`/`:64` — `M._is_in_code_block` is now a one-line memo lookup whose `_bufnr` parameter is ignored, exported "for testing" with no test and no external caller. Dead surface left by BR-11's fix.
- `highlight_structure.lua:85-92` — `classify` re-derives the backtick run that `is_fence_delim` just matched; `advance`'s `n >= (state.code_fence_len or 0)` defends a `(in_code=true, code_fence_len=nil)` pair that the transition function never actually produces. Both small ARCH-ORDER/DRY tidies.

## 5. Test coverage notes

- Full suite green at HEAD: 195 spec files pass, luacheck clean across 348 files, `make test` exit 0. Independently confirmed, not taken from the Log.
- Mutation checks I ran myself, all red as claimed: `exporter.lua` → `pure_functions_spec` 1F + arch 1F; review live-config → `review_spec` 1F; `copy.lua` → `copy_fence_spec` 1F + arch 1F; four prompts stripped → arch 1F.
- The gap that ships finding (a): the three new exporter tests assert only `find("code%-block")` and that the following turn text is present. Neither is sensitive to where the div sits in the paragraph tree, which is the property the rewrite actually changed.
- Secondary fixture-realism note: `write_html_file` runs `content:gsub("💬:", "## Question\n\n")` *before* `simple_markdown_to_html` (`exporter.lua:698`, `:703`), so in the real export path the `💬:` arm of `is_partition` never fires — containment is carried entirely by `🤖:`, one line later. The new exporter tests use pre-substitution input, so they exercise a shape production never sees. Behaviour is still correct; the coverage just claims more reach than it has.

## 6. Architectural notes

- **ARCH-DRY** — pass, and this is the diff's strongest axis: six fence predicates → one, three outline memo builds → one, `OPENAI_WIRE` and `fence_indent_convention` single-sourced. Residual nits in §4.
- **ARCH-PURE** — pass. `advance`/`reset_partition`/`is_partition`/`is_fence_delim`/`code_block_memo` are pure and unit-tested with no IO. The two new global-config reads (`exporter.lua:363`, `copy.lua:13`) sit in the IO shell where they belong.
- **ARCH-PURPOSE** — flagged, finding (b). The shadow sweep over the convention's consumers stops one source short.
- **ARCH-MOCK** — N/A; no external binary or service seam introduced. `refresh_goldens.lua` covering `OPENAI_FIXTURES` improves the existing regenerate/verify conformance loop.
- **ARCH-CONSTRAINTS** — flagged (§4, first bullet), plus BR-8/BR-9 still open on the decoration path.
- **ARCH-SECURE** — pass. HTML escaping still precedes fence processing; the unterminated-fence path emits already-escaped text verbatim and degrades visibly rather than fabricating a block; `is_partition` refuses nil patterns rather than substituting a plausible default.
- **ARCH-ORDER** — strong pass, the best-executed principle here. Worth carrying forward: the pattern of "one `advance(state, token)` both consumers call, phase stated in the docstring" is what made the drift property-checkable at all.

## 7. Plan revision recommendations

- The `## Plan` row *"the highlighter render seam via `tests/unit/highlighter_spec.lua`"* is ticked but the test landed at `tests/integration/fence_containment_spec.lua`. Substantively delivered; add a `## Revisions` line recording the relocation and why (it needs real buffers and extmarks, so it is an integration spec) so the row stops naming a file that does not exist.
- Add a `## Revisions` entry for the CommonMark rule's actual scope: the Plan row reads *"CommonMark closer rule: `code_fence_len` tracked, closer must be >= opener"* without qualification, but only `M.advance` implements it — `M.code_block_memo`, which outline, copy, the exporter and the review skill all use, is a plain boolean toggle. Two prose grammars now coexist; state which surface gets which, or say why the memo does not need width.

```findings
dispose:
  - id: BR-8
    disposition: not-addressed
    note: |
      highlighter.lua:148 `classified` and :192 `classification` still both call classify.
  - id: BR-9
    disposition: not-addressed
    note: |
      walk table still allocated per line at highlighter.lua:155-161; only 3 of 6 fields copied back.
  - id: BR-10
    disposition: not-addressed
    note: |
      atlas/ui/highlights.md:35 still says "up to 3 spaces of indent"; is_fence_delim uses ^%s* (any run, tabs included).
  - id: BR-13
    disposition: not-addressed
    note: |
      atlas/ui/outline.md:13 unchanged and still omits partition containment.
  - id: BR-14
    disposition: addressed
    note: |
      Verified by revert: base exporter.lua turns pure_functions_spec and the arch spec red. See new finding on the paragraph regression the rewrite introduced.
  - id: BR-15
    disposition: addressed
    note: |
      All three reverts independently red: review live-config 1F, copy.lua 2 specs, four stripped prompts 1F.
  - id: BR-16
    disposition: not-addressed
    note: |
      Measured seam: "aging in your responses.Indent ev" in all four non-default prompts; the new arch guard uses a plain substring find so it cannot see this.
  - id: BR-17
    disposition: not-addressed
    note: |
      copy.lua:2 still claims "no parley module dependencies"; atlas:35 still attributes the >= closer rule to a grammar code_block_memo does not implement.
  - id: BR-18
    disposition: not-addressed
    note: |
      Re-measured: 22 of 146 lua modules are in no code: list, copy.lua and copy_fence_spec.lua among them.
  - id: BR-19
    disposition: addressed
    note: |
      Assert verified reachable — is_partition and code_block_memo both raise on nil patterns; only the empty-lines call is vacuous.
findings:
  - id: new
    severity: Important
    family: rewrite-drops-incidental-guarantee
    title: |
      The BR-14 exporter rewrite drops the blank lines the old gsub guaranteed, so code blocks now nest inside <p>
    detail: |
      exporter.lua:361-392 joins `out` with single newlines, so the emitted
      <div class="code-block"> is no longer surrounded by \n\n and the later
      `<p[^>]*>%s*<div` / `</div>%s*</p>` cleanups stop firing. Reproduced against
      the base implementation on identical input: before, the div was a sibling of
      <p>; after, it sits inside one and the following prose loses .paragraph.
      175 of 256 fence delimiters in this repo's own chats and transcripts are
      preceded by a non-blank line, so this is the majority shape. The three new
      exporter tests assert only that text survives, so nothing goes red. Fix:
      emit an empty entry before and after the div, and assert the div is not
      inside a paragraph.
  - id: new
    severity: Important
    family: convention-not-derived-by-consumers
    title: |
      The convention guard enumerates config.system_prompts only, not config.agents system_prompt or user overrides
    detail: |
      This is the 2nd finding in family convention-not-derived-by-consumers. Do
      not fix this instance — state the rule: every prompt string in shipped
      config that agent_info.resolve can select must contain
      defaults.fence_indent_convention, derived from config rather than
      hand-picked. agent_info.lua:48-50 falls back to agent.system_prompt;
      config.lua:199 calls it mandatory and :224 supplies one, so the guard at
      single_source_sweeps_spec.lua:290 is green while covering one of two arms.
      The non-enforceable arm is user-supplied prompts — README.md:214 documents
      merging system_prompts by name, and a chat header system_prompt: replaces
      the prompt wholesale; neither carries the convention and no doc says why
      that matters. Docs gate: README update missing for that surface.
  - id: new
    severity: Minor
    family: shared-helper-unmeasured-cost
    title: |
      code_block_memo costs about 20x the inline toggles it replaced and no perf run was recorded
    detail: |
      Measured 6.06 ms vs 0.31 ms per 5000-line buffer, because is_partition runs
      the full classifier (~10 patterns plus a footnote lookup) per line.
      fold_projection.lua:111 documents deliberately avoiding exactly this cost on
      its own path. On-demand picker only, so not urgent, but the consolidation
      changed the per-line cost class and make perf was not run for this window.
      A prefix pre-check before classify recovers it. ARCH-CONSTRAINTS.
  - id: new
    severity: Minor
    family: single-source-bypassed
    title: |
      The fence-matcher arch guard only fires when the triple backtick and the match call share a line
    detail: |
      This is the 3rd finding in family single-source-bypassed. Do not patch the
      heuristic for one shape — state the rule the guard is meant to enforce and
      make the guard match it: a hoisted pattern constant, or any backtick-run
      pattern with no literal triple, evades detection entirely.
      exporter.lua:375's "^%s*`+%s*([%w_+-]*)" is already invisible to it (benign
      here — lang extraction, not a predicate). Measured live evasions in lua/: 0
      predicates, 1 non-predicate.
  - id: new
    severity: Minor
    family: injected-seam-bypassed
    title: |
      exporter.lua reaches for require("parley").config although the module already holds the injected _parley handle
    detail: |
      exporter.lua:363 uses require("parley").config while the same file declares
      _parley at :2 and uses it at :37, :693 and :750. Two ways into the same
      dependency in one module; the injected handle is the seam.
```
