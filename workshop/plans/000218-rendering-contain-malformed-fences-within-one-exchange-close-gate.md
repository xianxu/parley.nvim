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

## Open findings

- **BR-1** [Critical] `instance-not-class-sweep` outline.lua has a THIRD unswept fence tracker; #218's bug is live in the tree-outline picker
- **BR-2** [Critical] `config-ignored-at-new-seam` Both new is_partition call sites hardcode default prefixes, so containment does nothing under a custom chat_user_prefix
- **BR-3** [Important] `fix-without-failing-test` The skills/review containment change ships with no test — reverting it leaves all eight review specs green
- **BR-4** [Important] `single-source-bypassed` compute_fence_ranges matches only ^``` , so it misses every fence the new prompt convention tells models to indent
- **BR-5** [Important] `convention-not-derived-by-consumers` The two-space fence convention lands in one of five shipped system prompts
- **BR-6** [Important] `single-source-bypassed` refresh_goldens.lua re-hardcodes the openai provider/model that golden_fixture.lua exists to single-source
- **BR-7** [Important] `traceability-unmapped` The new containment spec is registered in no atlas/traceability.yaml entry
- **BR-8** [Minor] `redundant-recompute-on-render-path` classify is called twice per line per redraw in compute_chat_highlights
- **BR-9** [Minor] `shared-transition-partial-ownership` advance writes in_question/in_reasoning into the highlighter's walk table and the caller discards them
- **BR-10** [Minor] `doc-overstates-implementation` atlas claims a 3-space CommonMark indent limit the code does not enforce
- **BR-11** [Minor] `unreachable-guard` The outline lazy-fallback containment fix is unreachable and pins nothing
- **BR-12** [Minor] `instance-not-class-sweep` copy_code_fence pairs fences across a turn boundary
- **BR-13** [Minor] `atlas-stale-for-changed-surface` atlas/ui/outline.md still states the pre-218 rule
