---
gate: boundary-review
issue: 218
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-05T13:36:15-07:00"
      agent: claude
      findings:
        - id: BR-1
          severity: Critical
          title: 'outline.lua has a THIRD unswept fence tracker; #218''s bug is live in the tree-outline picker'
          detail: |-
            build_file_outline_items builds its own code_memo at lua/parley/outline.lua:293-300
            with the same boolean toggle and no partition reset, gating question items at :320.
            Reproduced: on one chat file with a stray fence, the tree picker returns 2 items
            (topic + first question) while the fixed buffer picker returns 3. The Log's claim
            that outline had "two fence scans, not one" and that the final count is five is
            wrong — outline has three, and copy.lua carries a fourth shape. ARCH-PURPOSE,
            ARCH-DRY. Hoist the memo build into one shared helper both outline paths call.
          family: instance-not-class-sweep
          round: 1
        - id: BR-2
          severity: Critical
          title: Both new is_partition call sites hardcode default prefixes, so containment does nothing under a custom chat_user_prefix
          detail: |-
            outline.lua:15,39 and skills/review/init.lua:166 call highlight_structure.patterns()
            with no config, while highlight_structure.build is driven with patterns(_parley.config).
            Reproduced with setup({chat_user_prefix='U:', chat_assistant_prefix='A:'}): the
            stray-fence document yields COUNT=1, i.e. the pre-218 bug, unfixed. config is
            already in hand at _build_picker_items(bufnr, config, opts) and via
            get_parley().config in the review skill.
          family: config-ignored-at-new-seam
          round: 1
        - id: BR-3
          severity: Important
          title: The skills/review containment change ships with no test — reverting it leaves all eight review specs green
          detail: |-
            Reverting the entire partition branch at skills/review/init.lua:171-176 and running
            review_spec, review_journal_spec, review_mode_spec, review_diag_display_spec,
            review_projection_spec, review_menu_spec, skill_invoke_review_spec and
            review_journal_io_spec gives 103 assertions, 0 failures. The issue's Done-when
            requires every change be mutation-verified, and the Log itself calls this a
            behaviour change ("markers move in malformed documents") — the exact thing that
            needs pinning. A parse_markers case with a stray fence in one answer and a marker
            in the next costs three lines.
          family: fix-without-failing-test
          round: 1
        - id: BR-4
          severity: Important
          title: compute_fence_ranges matches only ^``` , so it misses every fence the new prompt convention tells models to indent
          detail: |-
            defaults.lua:31 now instructs the model to indent every fence by two spaces, while
            skills/review/init.lua:176 matches only column-zero backticks; every other fence
            scan in the tree uses ^%s*```. Brackets inside model-authored code fences therefore
            stop being excluded from marker parsing, regressing #125 for the now-normal output
            shape. The diff created a shared is_partition but left the sibling fence-open
            predicate in six hand-maintained copies (highlight_structure.lua:86,
            outline.lua:22,44,296, review/init.lua:176, copy.lua:16,32). ARCH-DRY.
          family: single-source-bypassed
          round: 1
        - id: BR-5
          severity: Important
          title: The two-space fence convention lands in one of five shipped system prompts
          detail: |-
            config.lua:234-255 ships default, creative, concise, teacher and code_reviewer;
            only default derives from defaults.chat_system_prompt. The others are one
            ParleySystemPrompt away and carry no convention, so switching prompt silently
            changes how malformed output renders. Name the convention once and append it to
            every shipped prompt, or concatenate it where the system prompt is assembled.
            ARCH-PURPOSE shadow-sweep.
          family: convention-not-derived-by-consumers
          round: 1
        - id: BR-6
          severity: Important
          title: refresh_goldens.lua re-hardcodes the openai provider/model that golden_fixture.lua exists to single-source
          detail: |-
            scripts/refresh_goldens.lua:41-42 duplicates provider="cliproxyapi" and
            model={model="gpt-5.6-sol"} against tests/unit/parley_harness_golden_spec.lua:62-63,
            with a comment saying so ("pinned exactly as the verifier pins them").
            golden_fixture.lua's header condemns exactly this ("a golden must depend on nothing
            a person has to remember"). Add M.OPENAI_WIRE there and consume it on both sides.
          family: single-source-bypassed
          round: 1
        - id: BR-7
          severity: Important
          title: The new containment spec is registered in no atlas/traceability.yaml entry
          detail: |-
            tests/integration/fence_containment_spec.lua appears nowhere in traceability.yaml,
            and ui/highlights (:599-608) lists highlighter.lua but not highlight_structure.lua.
            So `make test-changed` after editing atlas/ui/highlights.md — the file this diff
            edited — does not run the spec that pins this issue.
          family: traceability-unmapped
          round: 1
        - id: BR-8
          severity: Minor
          title: classify is called twice per line per redraw in compute_chat_highlights
          detail: |-
            highlighter.lua:148 computes `classified` and :192 recomputes the same thing as
            `classification`. Reuse the first. ARCH-CONSTRAINTS, decoration path.
          family: redundant-recompute-on-render-path
          round: 1
        - id: BR-9
          severity: Minor
          title: advance writes in_question/in_reasoning into the highlighter's walk table and the caller discards them
          detail: |-
            highlighter.lua:155-161 allocates a walk table per line per redraw and copies back
            only in_code, code_fence_len and in_tool; in_question/in_reasoning stay owned by the
            loop at :245-252. The comment's claim that "Both now go through the ONE transition
            function" holds for three of six fields. Hoist the table out of the loop and state
            which fields the caller owns.
          family: shared-transition-partial-ownership
          round: 1
        - id: BR-10
          severity: Minor
          title: atlas claims a 3-space CommonMark indent limit the code does not enforce
          detail: |-
            atlas/ui/highlights.md:35 says "up to 3 spaces of indent", but ^%s*``` accepts any
            whitespace run including tabs and four-plus spaces. Relatedly defaults.lua:33 tells
            the model four spaces makes the markers literal text — true in a CommonMark renderer,
            not in parley's highlighter.
          family: doc-overstates-implementation
          round: 1
        - id: BR-11
          severity: Minor
          title: The outline lazy-fallback containment fix is unreachable and pins nothing
          detail: |-
            outline.lua:36-49 only runs when memo[line_number] is nil, but build_code_block_memo
            populates every line and both callers pre-build it. Reverting the :42 partition reset
            turns nothing red. Either drop the fallback or record it as dead.
          family: unreachable-guard
          round: 1
        - id: BR-12
          severity: Minor
          title: copy_code_fence pairs fences across a turn boundary
          detail: |-
            copy.lua:16,32 scans up then down for the nearest ``` with no partition bound, so a
            stray opener in the previous exchange can pair with a closer in this one. Different
            shape from the accumulating trackers and much lower blast radius, but the same class
            and it belongs in the enumeration.
          family: instance-not-class-sweep
          round: 1
        - id: BR-13
          severity: Minor
          title: atlas/ui/outline.md still states the pre-218 rule
          detail: |-
            ":13 Lines inside code blocks (``` / ~~~) are excluded" no longer tells the whole
            story now that a column-zero turn marker ends the fence. lua/parley/outline.lua
            changed in this window; its atlas page did not.
          family: atlas-stale-for-changed-surface
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-09-05T13:55:49-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: All three outline memos now call highlight_structure.code_block_memo; restoring the private build turns the tree-outline test red.
          round: 2
        - id: BR-2
          disposition: addressed
          note: Both sites thread live config; outline half is mutation-red, review half is correct in code but unpinned (see I1).
          round: 2
        - id: BR-3
          disposition: addressed
          note: review_spec now has three containment cases; reverting the partition branch turns one red.
          round: 2
        - id: BR-4
          disposition: addressed
          note: is_fence_delim is shared and the indented-fence case goes red when swapped back to a column-zero match.
          round: 2
        - id: BR-5
          disposition: addressed
          note: Convention single-sourced onto all five prompts; code is right but nothing pins it (see I1) and the concatenation lacks a separator.
          round: 2
        - id: BR-6
          disposition: addressed
          note: golden_fixture.M.OPENAI_WIRE is consumed by both the regenerator and the verifier.
          round: 2
        - id: BR-7
          disposition: addressed
          note: ui/highlights now lists highlight_structure.lua plus both specs.
          round: 2
        - id: BR-8
          disposition: not-addressed
          note: classify is still computed at highlighter.lua:148 and recomputed at :192.
          round: 2
        - id: BR-9
          disposition: not-addressed
          note: The per-line walk table at highlighter.lua:155 is unchanged and the comment still overstates field ownership.
          round: 2
        - id: BR-10
          disposition: not-addressed
          note: defaults.lua was qualified, but atlas/ui/highlights.md was not touched by f1818ee; :35 still claims a 3-space limit and :45 the unqualified four-space claim.
          round: 2
        - id: BR-11
          disposition: addressed
          note: The lazy fallback is gone; is_in_code_block is now a pure memo read.
          round: 2
        - id: BR-12
          disposition: addressed
          note: Both copy.lua scans break at a partition — though nothing tests copy.lua at all (see I1).
          round: 2
        - id: BR-13
          disposition: not-addressed
          note: atlas/ui/outline.md:13 still states the pre-218 rule; the file is unchanged in this window.
          round: 2
      findings:
        - id: BR-14
          severity: Critical
          title: The new two-space convention breaks HTML export — exporter.lua pairs fences across turns and only closes at column zero
          detail: "lua/parley/exporter.lua:352 does html:gsub(\"```([^\\n]*)\\n(.-)\\n```\", ...). The\ncloser must follow a newline directly, so an indented closer never matches and the\nscan runs to the next flush-left fence anywhere in the document. Reproduced against\nthe real pattern: an indented block plus following prose, the next \U0001F4AC: question and\nthe next \U0001F916: answer are all swallowed into one code block, and the following\nflush-left block is left bare. tests/unit/pure_functions_spec.lua:163,170 cover only\nflush-left fences so nothing goes red. This is also a cross-exchange pairing with no\npartition bound — the same shape as BR-12's copy.lua. THIRD finding in this family:\ndo not patch only this site. State the rule (a triple-backtick predicate may exist\nonly in highlight_structure.is_fence_delim for prose and fence.lua for tool bodies)\nand enforce it in tests/arch/single_source_sweeps_spec.lua, which exists for exactly\nthis and received no 218 entry. Prevalence after this round: exporter.lua:352 and\nchat_respond.lua:811 are the remaining hand-rolled matchers in lua/."
          family: instance-not-class-sweep
          round: 2
        - id: BR-15
          severity: Important
          title: Three of this round's own fixes revert green — the mutation ledger was built from recall, not from the diff
          detail: |-
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
          family: fix-without-failing-test
          round: 2
        - id: BR-16
          severity: Minor
          title: The convention is concatenated onto a sentence-final period in four of five prompts
          detail: |-
            config.lua:242,247,252,257 append fence_indent_convention directly after "...in your
            responses." with no separator, producing "responses.Indent every fenced code block".
            The default prompt escapes this only because defaults.lua:46 ends in a double
            newline. Give the fragment a leading "\n\n" or add the separator at each seam.
          family: shared-fragment-missing-separator
          round: 2
        - id: BR-17
          severity: Minor
          title: copy.lua's header now contradicts the file, and the atlas grammar table overstates code_block_memo
          detail: |-
            copy.lua:2 still reads "Pure utility module — no parley module dependencies" after
            the diff added require("parley.highlight_structure") and require("parley").config.
            atlas/ui/highlights.md:35 attributes a CommonMark ">= closer" rule to
            highlight_structure, but only M.advance implements it — M.code_block_memo (the
            helper outline, review and copy all use) is a plain boolean toggle. SECOND finding
            in this family, with BR-10 still open: the rule is that any comment or atlas row
            asserting a code property needs a grep-able referent, and the three live instances
            (atlas:35, atlas:45, copy.lua:2) should be swept together.
          family: doc-overstates-implementation
          round: 2
        - id: BR-18
          severity: Minor
          title: lua/parley/copy.lua changed in this window and is in no traceability code list
          detail: |-
            make test-changed can never reach copy.lua's containment fix — it is in no atlas
            entry and has no spec. SECOND finding in this family. Measured prevalence: 22 of 146
            lua/ modules are unmapped, so the rule-level answer is an arch guard requiring every
            module to appear in exactly one code: list (or an explicit allowlist), not a one-line
            addition for copy.lua.
          family: traceability-unmapped
          round: 2
        - id: BR-19
          severity: Minor
          title: is_partition and code_block_memo still silently substitute default prefixes when patterns is nil
          detail: |-
            highlight_structure.lua:180 does patterns or M.patterns(), and :219's docstring says
            patterns "MUST come from the live config" while nothing enforces it — the exact state
            BR-2 was about is still representable at the seam. SECOND finding in this family: the
            rule is to make it unrepresentable (assert on nil at the seam) rather than to audit
            each caller, which BR-2 already had to do twice.
          family: config-ignored-at-new-seam
          round: 2
      blocked: true
    - "n": 3
      timestamp: "2026-09-05T14:17:11-07:00"
      agent: claude
      dispose:
        - id: BR-8
          disposition: not-addressed
          note: highlighter.lua:148 `classified` and :192 `classification` still both call classify.
          round: 3
        - id: BR-9
          disposition: not-addressed
          note: walk table still allocated per line at highlighter.lua:155-161; only 3 of 6 fields copied back.
          round: 3
        - id: BR-10
          disposition: not-addressed
          note: atlas/ui/highlights.md:35 still says "up to 3 spaces of indent"; is_fence_delim uses ^%s* (any run, tabs included).
          round: 3
        - id: BR-13
          disposition: not-addressed
          note: atlas/ui/outline.md:13 unchanged and still omits partition containment.
          round: 3
        - id: BR-14
          disposition: addressed
          note: 'Verified by revert: base exporter.lua turns pure_functions_spec and the arch spec red. See new finding on the paragraph regression the rewrite introduced.'
          round: 3
        - id: BR-15
          disposition: addressed
          note: 'All three reverts independently red: review live-config 1F, copy.lua 2 specs, four stripped prompts 1F.'
          round: 3
        - id: BR-16
          disposition: not-addressed
          note: 'Measured seam: "aging in your responses.Indent ev" in all four non-default prompts; the new arch guard uses a plain substring find so it cannot see this.'
          round: 3
        - id: BR-17
          disposition: not-addressed
          note: copy.lua:2 still claims "no parley module dependencies"; atlas:35 still attributes the >= closer rule to a grammar code_block_memo does not implement.
          round: 3
        - id: BR-18
          disposition: not-addressed
          note: 'Re-measured: 22 of 146 lua modules are in no code: list, copy.lua and copy_fence_spec.lua among them.'
          round: 3
        - id: BR-19
          disposition: addressed
          note: Assert verified reachable — is_partition and code_block_memo both raise on nil patterns; only the empty-lines call is vacuous.
          round: 3
      findings:
        - id: BR-20
          severity: Important
          title: The BR-14 exporter rewrite drops the blank lines the old gsub guaranteed, so code blocks now nest inside <p>
          detail: |-
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
          family: rewrite-drops-incidental-guarantee
          round: 3
        - id: BR-21
          severity: Important
          title: The convention guard enumerates config.system_prompts only, not config.agents system_prompt or user overrides
          detail: |-
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
          family: convention-not-derived-by-consumers
          round: 3
        - id: BR-22
          severity: Minor
          title: code_block_memo costs about 20x the inline toggles it replaced and no perf run was recorded
          detail: |-
            Measured 6.06 ms vs 0.31 ms per 5000-line buffer, because is_partition runs
            the full classifier (~10 patterns plus a footnote lookup) per line.
            fold_projection.lua:111 documents deliberately avoiding exactly this cost on
            its own path. On-demand picker only, so not urgent, but the consolidation
            changed the per-line cost class and make perf was not run for this window.
            A prefix pre-check before classify recovers it. ARCH-CONSTRAINTS.
          family: shared-helper-unmeasured-cost
          round: 3
        - id: BR-23
          severity: Minor
          title: The fence-matcher arch guard only fires when the triple backtick and the match call share a line
          detail: |-
            This is the 3rd finding in family single-source-bypassed. Do not patch the
            heuristic for one shape — state the rule the guard is meant to enforce and
            make the guard match it: a hoisted pattern constant, or any backtick-run
            pattern with no literal triple, evades detection entirely.
            exporter.lua:375's "^%s*`+%s*([%w_+-]*)" is already invisible to it (benign
            here — lang extraction, not a predicate). Measured live evasions in lua/: 0
            predicates, 1 non-predicate.
          family: single-source-bypassed
          round: 3
        - id: BR-24
          severity: Minor
          title: exporter.lua reaches for require("parley").config although the module already holds the injected _parley handle
          detail: |-
            exporter.lua:363 uses require("parley").config while the same file declares
            _parley at :2 and uses it at :37, :693 and :750. Two ways into the same
            dependency in one module; the injected handle is the seam.
          family: injected-seam-bypassed
          round: 3
      blocked: true
---

# Gate ledger — parley.nvim#218 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-05T13:36:15-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Critical] `instance-not-class-sweep` outline.lua has a THIRD unswept fence tracker; #218's bug is live in the tree-outline picker
  build_file_outline_items builds its own code_memo at lua/parley/outline.lua:293-300
  with the same boolean toggle and no partition reset, gating question items at :320.
  Reproduced: on one chat file with a stray fence, the tree picker returns 2 items
  (topic + first question) while the fixed buffer picker returns 3. The Log's claim
  that outline had "two fence scans, not one" and that the final count is five is
  wrong — outline has three, and copy.lua carries a fourth shape. ARCH-PURPOSE,
  ARCH-DRY. Hoist the memo build into one shared helper both outline paths call.
- **BR-2** [Critical] `config-ignored-at-new-seam` Both new is_partition call sites hardcode default prefixes, so containment does nothing under a custom chat_user_prefix
  outline.lua:15,39 and skills/review/init.lua:166 call highlight_structure.patterns()
  with no config, while highlight_structure.build is driven with patterns(_parley.config).
  Reproduced with setup({chat_user_prefix='U:', chat_assistant_prefix='A:'}): the
  stray-fence document yields COUNT=1, i.e. the pre-218 bug, unfixed. config is
  already in hand at _build_picker_items(bufnr, config, opts) and via
  get_parley().config in the review skill.
- **BR-3** [Important] `fix-without-failing-test` The skills/review containment change ships with no test — reverting it leaves all eight review specs green
  Reverting the entire partition branch at skills/review/init.lua:171-176 and running
  review_spec, review_journal_spec, review_mode_spec, review_diag_display_spec,
  review_projection_spec, review_menu_spec, skill_invoke_review_spec and
  review_journal_io_spec gives 103 assertions, 0 failures. The issue's Done-when
  requires every change be mutation-verified, and the Log itself calls this a
  behaviour change ("markers move in malformed documents") — the exact thing that
  needs pinning. A parse_markers case with a stray fence in one answer and a marker
  in the next costs three lines.
- **BR-4** [Important] `single-source-bypassed` compute_fence_ranges matches only ^``` , so it misses every fence the new prompt convention tells models to indent
  defaults.lua:31 now instructs the model to indent every fence by two spaces, while
  skills/review/init.lua:176 matches only column-zero backticks; every other fence
  scan in the tree uses ^%s*```. Brackets inside model-authored code fences therefore
  stop being excluded from marker parsing, regressing #125 for the now-normal output
  shape. The diff created a shared is_partition but left the sibling fence-open
  predicate in six hand-maintained copies (highlight_structure.lua:86,
  outline.lua:22,44,296, review/init.lua:176, copy.lua:16,32). ARCH-DRY.
- **BR-5** [Important] `convention-not-derived-by-consumers` The two-space fence convention lands in one of five shipped system prompts
  config.lua:234-255 ships default, creative, concise, teacher and code_reviewer;
  only default derives from defaults.chat_system_prompt. The others are one
  ParleySystemPrompt away and carry no convention, so switching prompt silently
  changes how malformed output renders. Name the convention once and append it to
  every shipped prompt, or concatenate it where the system prompt is assembled.
  ARCH-PURPOSE shadow-sweep.
- **BR-6** [Important] `single-source-bypassed` refresh_goldens.lua re-hardcodes the openai provider/model that golden_fixture.lua exists to single-source
  scripts/refresh_goldens.lua:41-42 duplicates provider="cliproxyapi" and
  model={model="gpt-5.6-sol"} against tests/unit/parley_harness_golden_spec.lua:62-63,
  with a comment saying so ("pinned exactly as the verifier pins them").
  golden_fixture.lua's header condemns exactly this ("a golden must depend on nothing
  a person has to remember"). Add M.OPENAI_WIRE there and consume it on both sides.
- **BR-7** [Important] `traceability-unmapped` The new containment spec is registered in no atlas/traceability.yaml entry
  tests/integration/fence_containment_spec.lua appears nowhere in traceability.yaml,
  and ui/highlights (:599-608) lists highlighter.lua but not highlight_structure.lua.
  So `make test-changed` after editing atlas/ui/highlights.md — the file this diff
  edited — does not run the spec that pins this issue.
- **BR-8** [Minor] `redundant-recompute-on-render-path` classify is called twice per line per redraw in compute_chat_highlights
  highlighter.lua:148 computes `classified` and :192 recomputes the same thing as
  `classification`. Reuse the first. ARCH-CONSTRAINTS, decoration path.
- **BR-9** [Minor] `shared-transition-partial-ownership` advance writes in_question/in_reasoning into the highlighter's walk table and the caller discards them
  highlighter.lua:155-161 allocates a walk table per line per redraw and copies back
  only in_code, code_fence_len and in_tool; in_question/in_reasoning stay owned by the
  loop at :245-252. The comment's claim that "Both now go through the ONE transition
  function" holds for three of six fields. Hoist the table out of the loop and state
  which fields the caller owns.
- **BR-10** [Minor] `doc-overstates-implementation` atlas claims a 3-space CommonMark indent limit the code does not enforce
  atlas/ui/highlights.md:35 says "up to 3 spaces of indent", but ^%s*``` accepts any
  whitespace run including tabs and four-plus spaces. Relatedly defaults.lua:33 tells
  the model four spaces makes the markers literal text — true in a CommonMark renderer,
  not in parley's highlighter.
- **BR-11** [Minor] `unreachable-guard` The outline lazy-fallback containment fix is unreachable and pins nothing
  outline.lua:36-49 only runs when memo[line_number] is nil, but build_code_block_memo
  populates every line and both callers pre-build it. Reverting the :42 partition reset
  turns nothing red. Either drop the fallback or record it as dead.
- **BR-12** [Minor] `instance-not-class-sweep` copy_code_fence pairs fences across a turn boundary
  copy.lua:16,32 scans up then down for the nearest ``` with no partition bound, so a
  stray opener in the previous exchange can pair with a closer in this one. Different
  shape from the accumulating trackers and much lower blast radius, but the same class
  and it belongs in the enumeration.
- **BR-13** [Minor] `atlas-stale-for-changed-surface` atlas/ui/outline.md still states the pre-218 rule
  ":13 Lines inside code blocks (``` / ~~~) are excluded" no longer tells the whole
  story now that a column-zero turn marker ends the fence. lua/parley/outline.lua
  changed in this window; its atlas page did not.

## Round 2 — 2026-09-05T13:55:49-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — addressed — All three outline memos now call highlight_structure.code_block_memo; restoring the private build turns the tree-outline test red.
- BR-2 — addressed — Both sites thread live config; outline half is mutation-red, review half is correct in code but unpinned (see I1).
- BR-3 — addressed — review_spec now has three containment cases; reverting the partition branch turns one red.
- BR-4 — addressed — is_fence_delim is shared and the indented-fence case goes red when swapped back to a column-zero match.
- BR-5 — addressed — Convention single-sourced onto all five prompts; code is right but nothing pins it (see I1) and the concatenation lacks a separator.
- BR-6 — addressed — golden_fixture.M.OPENAI_WIRE is consumed by both the regenerator and the verifier.
- BR-7 — addressed — ui/highlights now lists highlight_structure.lua plus both specs.
- BR-8 — not-addressed — classify is still computed at highlighter.lua:148 and recomputed at :192.
- BR-9 — not-addressed — The per-line walk table at highlighter.lua:155 is unchanged and the comment still overstates field ownership.
- BR-10 — not-addressed — defaults.lua was qualified, but atlas/ui/highlights.md was not touched by f1818ee; :35 still claims a 3-space limit and :45 the unqualified four-space claim.
- BR-11 — addressed — The lazy fallback is gone; is_in_code_block is now a pure memo read.
- BR-12 — addressed — Both copy.lua scans break at a partition — though nothing tests copy.lua at all (see I1).
- BR-13 — not-addressed — atlas/ui/outline.md:13 still states the pre-218 rule; the file is unchanged in this window.

### Raised

- **BR-14** [Critical] `instance-not-class-sweep` The new two-space convention breaks HTML export — exporter.lua pairs fences across turns and only closes at column zero
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
- **BR-15** [Important] `fix-without-failing-test` Three of this round's own fixes revert green — the mutation ledger was built from recall, not from the diff
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
- **BR-16** [Minor] `shared-fragment-missing-separator` The convention is concatenated onto a sentence-final period in four of five prompts
  config.lua:242,247,252,257 append fence_indent_convention directly after "...in your
  responses." with no separator, producing "responses.Indent every fenced code block".
  The default prompt escapes this only because defaults.lua:46 ends in a double
  newline. Give the fragment a leading "\n\n" or add the separator at each seam.
- **BR-17** [Minor] `doc-overstates-implementation` copy.lua's header now contradicts the file, and the atlas grammar table overstates code_block_memo
  copy.lua:2 still reads "Pure utility module — no parley module dependencies" after
  the diff added require("parley.highlight_structure") and require("parley").config.
  atlas/ui/highlights.md:35 attributes a CommonMark ">= closer" rule to
  highlight_structure, but only M.advance implements it — M.code_block_memo (the
  helper outline, review and copy all use) is a plain boolean toggle. SECOND finding
  in this family, with BR-10 still open: the rule is that any comment or atlas row
  asserting a code property needs a grep-able referent, and the three live instances
  (atlas:35, atlas:45, copy.lua:2) should be swept together.
- **BR-18** [Minor] `traceability-unmapped` lua/parley/copy.lua changed in this window and is in no traceability code list
  make test-changed can never reach copy.lua's containment fix — it is in no atlas
  entry and has no spec. SECOND finding in this family. Measured prevalence: 22 of 146
  lua/ modules are unmapped, so the rule-level answer is an arch guard requiring every
  module to appear in exactly one code: list (or an explicit allowlist), not a one-line
  addition for copy.lua.
- **BR-19** [Minor] `config-ignored-at-new-seam` is_partition and code_block_memo still silently substitute default prefixes when patterns is nil
  highlight_structure.lua:180 does patterns or M.patterns(), and :219's docstring says
  patterns "MUST come from the live config" while nothing enforces it — the exact state
  BR-2 was about is still representable at the seam. SECOND finding in this family: the
  rule is to make it unrepresentable (assert on nil at the seam) rather than to audit
  each caller, which BR-2 already had to do twice.

## Round 3 — 2026-09-05T14:17:11-07:00 (claude) — BLOCKED

### Disposed

- BR-8 — not-addressed — highlighter.lua:148 `classified` and :192 `classification` still both call classify.
- BR-9 — not-addressed — walk table still allocated per line at highlighter.lua:155-161; only 3 of 6 fields copied back.
- BR-10 — not-addressed — atlas/ui/highlights.md:35 still says "up to 3 spaces of indent"; is_fence_delim uses ^%s* (any run, tabs included).
- BR-13 — not-addressed — atlas/ui/outline.md:13 unchanged and still omits partition containment.
- BR-14 — addressed — Verified by revert: base exporter.lua turns pure_functions_spec and the arch spec red. See new finding on the paragraph regression the rewrite introduced.
- BR-15 — addressed — All three reverts independently red: review live-config 1F, copy.lua 2 specs, four stripped prompts 1F.
- BR-16 — not-addressed — Measured seam: "aging in your responses.Indent ev" in all four non-default prompts; the new arch guard uses a plain substring find so it cannot see this.
- BR-17 — not-addressed — copy.lua:2 still claims "no parley module dependencies"; atlas:35 still attributes the >= closer rule to a grammar code_block_memo does not implement.
- BR-18 — not-addressed — Re-measured: 22 of 146 lua modules are in no code: list, copy.lua and copy_fence_spec.lua among them.
- BR-19 — addressed — Assert verified reachable — is_partition and code_block_memo both raise on nil patterns; only the empty-lines call is vacuous.

### Raised

- **BR-20** [Important] `rewrite-drops-incidental-guarantee` The BR-14 exporter rewrite drops the blank lines the old gsub guaranteed, so code blocks now nest inside <p>
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
- **BR-21** [Important] `convention-not-derived-by-consumers` The convention guard enumerates config.system_prompts only, not config.agents system_prompt or user overrides
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
- **BR-22** [Minor] `shared-helper-unmeasured-cost` code_block_memo costs about 20x the inline toggles it replaced and no perf run was recorded
  Measured 6.06 ms vs 0.31 ms per 5000-line buffer, because is_partition runs
  the full classifier (~10 patterns plus a footnote lookup) per line.
  fold_projection.lua:111 documents deliberately avoiding exactly this cost on
  its own path. On-demand picker only, so not urgent, but the consolidation
  changed the per-line cost class and make perf was not run for this window.
  A prefix pre-check before classify recovers it. ARCH-CONSTRAINTS.
- **BR-23** [Minor] `single-source-bypassed` The fence-matcher arch guard only fires when the triple backtick and the match call share a line
  This is the 3rd finding in family single-source-bypassed. Do not patch the
  heuristic for one shape — state the rule the guard is meant to enforce and
  make the guard match it: a hoisted pattern constant, or any backtick-run
  pattern with no literal triple, evades detection entirely.
  exporter.lua:375's "^%s*`+%s*([%w_+-]*)" is already invisible to it (benign
  here — lang extraction, not a predicate). Measured live evasions in lua/: 0
  predicates, 1 non-predicate.
- **BR-24** [Minor] `injected-seam-bypassed` exporter.lua reaches for require("parley").config although the module already holds the injected _parley handle
  exporter.lua:363 uses require("parley").config while the same file declares
  _parley at :2 and uses it at :37, :693 and :750. Two ways into the same
  dependency in one module; the injected handle is the seam.

## Open findings

- **BR-8** [Minor] `redundant-recompute-on-render-path` classify is called twice per line per redraw in compute_chat_highlights
- **BR-9** [Minor] `shared-transition-partial-ownership` advance writes in_question/in_reasoning into the highlighter's walk table and the caller discards them
- **BR-10** [Minor] `doc-overstates-implementation` atlas claims a 3-space CommonMark indent limit the code does not enforce
- **BR-13** [Minor] `atlas-stale-for-changed-surface` atlas/ui/outline.md still states the pre-218 rule
- **BR-16** [Minor] `shared-fragment-missing-separator` The convention is concatenated onto a sentence-final period in four of five prompts
- **BR-17** [Minor] `doc-overstates-implementation` copy.lua's header now contradicts the file, and the atlas grammar table overstates code_block_memo
- **BR-18** [Minor] `traceability-unmapped` lua/parley/copy.lua changed in this window and is in no traceability code list
- **BR-20** [Important] `rewrite-drops-incidental-guarantee` The BR-14 exporter rewrite drops the blank lines the old gsub guaranteed, so code blocks now nest inside <p>
- **BR-21** [Important] `convention-not-derived-by-consumers` The convention guard enumerates config.system_prompts only, not config.agents system_prompt or user overrides
- **BR-22** [Minor] `shared-helper-unmeasured-cost` code_block_memo costs about 20x the inline toggles it replaced and no perf run was recorded
- **BR-23** [Minor] `single-source-bypassed` The fence-matcher arch guard only fires when the triple backtick and the match call share a line
- **BR-24** [Minor] `injected-seam-bypassed` exporter.lua reaches for require("parley").config although the module already holds the injected _parley handle
