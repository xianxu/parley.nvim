---
gate: boundary-review
issue: 262
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-16T13:53:02-07:00"
      agent: claude
      boundary: M1
      blocked: false
      protocol_error: no valid findings block
    - "n": 2
      timestamp: "2026-09-16T14:06:15-07:00"
      agent: claude
      findings:
        - id: BR-1
          severity: Critical
          title: header floor exists only for chat-classified buffers; dae on line 1 of a markdown-classified transcript empties the file
          detail: "entity_range.lua:206 derives floor from parsed.header_end, and parsed is\nnon-nil only when not_chat() passed. not_chat rejects for five reasons\nunrelated to document shape (not under a chat root, non-timestamp\nfilename, <5 lines, missing topic, missing file header). Reproduced: a\ntranscript saved as notes-about-entities.md is classified markdown, the\nae map is still installed, and dae on line 1 reduces the buffer to a\nsingle empty line. With a blank \"# topic:\" both surfaces also delete a\nsection through EOF across the next \U0001F4AC:. Violates the issue Done-when and\natlas/chat/entity_delete.md:37. Fix: derive the floor from a pure\ntranscript_header_end(lines) (topic-shaped line 1 or front matter, plus a\n--- terminator) whenever parsed is absent."
          family: guard-gated-on-classification
          round: 2
        - id: BR-2
          severity: Critical
          title: the command path's unparsable-header refusal is unreachable when not_chat fails, so the two surfaces diverge
          detail: |-
            init.lua:4534-4545 puts the new refusal inside `if not reason then`.
            Editing the --- away leaves the latch at "chat" but makes not_chat return
            "missing header separator", so the guard is skipped and parsed_chat stays
            nil -- unclamped markdown semantics, no log line. Reproduced:
            :ParleyDeleteEntity on a heading inside the first answer deletes through
            EOF and swallows the next exchange, while `normal dae` on the identical
            state refuses. Breaks the parity claim the parity spec exists to defend.
          family: guard-gated-on-classification
          round: 2
        - id: BR-3
          severity: Important
          title: plan Task 11 Step 4 is ticked but no test exercises the streaming refusal
          detail: |-
            grep over tests/ for DeleteEntity/DeleteToEnd/replace_user_lines finds
            only the parity spec's two vim.cmd calls. The refusal is the single
            documented asymmetry between the surfaces, named in the issue Done-when,
            in the plan's ARCH-ORDER paragraph ("Task 11 tests the refusal") and in
            the parity spec's scoping comment. Deliver it or untick Step 4 and record
            the deferral.
          family: checkbox-without-artifact
          round: 2
        - id: BR-4
          severity: Important
          title: the parity spec varies only the cursor row, never the document shape, so classification divergence is invisible to it
          detail: |-
            tests/integration/entity_delete_parity_spec.lua always builds a
            well-formed chat, so all 24 rows exercise the same classification branch.
            Both Criticals above stay green under it. Parameterise fresh() over a
            valid fixture, one with the --- removed, and one with the `- file:`
            header removed, and loop the existing assertions over all three.
          family: parity-varies-only-cursor
          round: 2
        - id: BR-5
          severity: Minor
          title: section_range's floor parameter is dead code
          detail: |-
            entity_range.lua:88-90 can never fire: M.range:207 already returns nil
            for row < floor, and the to_end back-scan at :255 starts at floor. The
            second call site (:257) omits the argument. Drop it or make it the real
            enforcement point.
          family: unreachable-guard
          round: 2
        - id: BR-6
          severity: Minor
          title: parse_chat is pcall-wrapped on one surface and bare on the other, with two different warning strings for one condition
          detail: |-
            entity_textobj.lua:41 wraps parse_chat in pcall; init.lua:4544 calls
            M.parse_chat bare on identical input. The same "unreadable header"
            condition warns as "Parley: entity object needs a readable chat header…"
            on one surface and "DeleteEntity: chat header is unreadable…" on the
            other.
          family: inconsistent-error-handling
          round: 2
        - id: BR-7
          severity: Minor
          title: Core concepts table still names only outline.lua:52-60 as the modified outline consumer
          detail: |-
            plan.md:43 reads `lua/parley/outline.lua:52-60`; the diff also changed
            the token path at :254. The Revisions entry records this but the table
            row was never updated, so the table still understates the consumer set.
          family: plan-table-understates-code
          round: 2
        - id: BR-8
          severity: Minor
          title: README documents dae/daE/yae/cae but not ie, <C-g>k or <C-g>K
          detail: |-
            README.md:16-20 covers the outer objects only. atlas/ui/keybindings.md
            lists the full set, so this is a README-side omission of user-typed
            surface introduced in the same range.
          family: readme-omits-new-surface
          round: 2
        - id: BR-9
          severity: Minor
          title: the atlas perf figures cannot be re-derived from the repo
          detail: |-
            atlas/chat/entity_delete.md:80-88 records 13.6 / 24.7 / 97.8 ms, but no
            perf spec landed, so the numbers go stale silently when parse_chat
            changes.
          family: unreproducible-measurement
          round: 2
      boundary: M1
      blocked: true
    - "n": 3
      timestamp: "2026-09-16T14:31:20-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: 'Verified by revert: dropping the transcript_header_end fallback at entity_range.lua:211-213 turns two tests red.'
          round: 3
        - id: BR-2
          disposition: not-addressed
          note: Code verified correct by execution (HEAD refuses; reverted, the command takes 15 lines to 8 while dae is a no-op) but NO test fails without it - the whole suite stayed green on the reverted tree.
          round: 3
        - id: BR-3
          disposition: addressed
          note: 'Real pin: pcall-wrapping replace_user_lines in a scratch copy turns the refusal test red.'
          round: 3
        - id: BR-4
          disposition: not-addressed
          note: The new axis varies filename/classification, not document shape; the --- removed and `- file:` removed shapes are absent, and that is exactly where BR-2 lived.
          round: 3
        - id: BR-5
          disposition: not-addressed
          note: section_range's floor guard at entity_range.lua:91-93 is still unreachable; the second call site at :262 still omits the argument.
          round: 3
        - id: BR-6
          disposition: addressed
          note: One shared parsed_for means one parse site and one pcall; the two message strings remain but each names its own surface, matching ExchangeCut/ExchangePaste convention.
          round: 3
        - id: BR-7
          disposition: addressed
          note: plan.md:43 now reads `lua/parley/outline.lua:52-60` **and `:254`**, and both paths are changed in the diff.
          round: 3
        - id: BR-8
          disposition: not-addressed
          note: README.md:16-20 is unchanged since round 2 - still no ie, <C-g>k or <C-g>K.
          round: 3
        - id: BR-9
          disposition: addressed
          note: atlas/chat/entity_delete.md:89-92 now states no spec guards the numbers and names the re-derivation recipe; tests/perf/chat_typing.lua:13 build_fixture verified to exist.
          round: 3
      findings:
        - id: BR-10
          severity: Important
          title: transcript_header_end validates only line 1, then delegates to an unbounded find_header_end scan
          detail: |-
            chat_parser.lua:79-84 gates on `^#%s*topic:` and then returns the first `---` anywhere in the file.
            Reproduced: for a genuine note `{ "# topic: how to cook", "", "Intro paragraph.", "", "## Step one",
            "prep", "", "---", "", "## Step two", "cook" }` it returns 8, so the floor is 9 and range() returns nil
            for rows 1-8 - dae is silently dead over two real sections and a paragraph. Same shape hits a transcript
            whose --- was edited away. Fails closed (no data loss), hence Important. Fix: require the terminator to
            close a contiguous run of header-shaped lines, the shape parse_chat_headers already knows. ARCH-DRY note
            at the same site: `^#%s*topic:` is a third hardcoding of the transcript first-line shape.
          family: partial-shape-test
          round: 3
        - id: BR-11
          severity: Important
          title: the unit test for that property uses a non-topic-shaped title, so it never reaches the scan
          detail: |-
            entity_range_spec "does not floor a thematic break in a genuine markdown note" uses `# My Note`, which
            exits at the line-1 guard. It reads as pinning the stated property but pins only half of it. Add the
            `# topic: ...`-titled fixture.
          family: partial-shape-test
          round: 3
        - id: BR-12
          severity: Important
          title: REPEAT (2nd) - the parity spec still cannot see the axis BR-2 lived on; state the rule, not the instance
          detail: |-
            Measured prevalence 2/2. Evidence: reverting the BR-2 fix in a git-backed scratch left all 5 parity tests
            and all 15 entity_textobj tests green, while a direct probe on that same tree showed the surfaces diverging
            15 lines to 8. RULE - a parity spec must vary every axis along which the two surfaces could disagree, and
            each axis must be demonstrated red-without-its-fix. Enumeration for this spec - (a) cursor row, done;
            (b) classification, done; (c) document shape (--- removed, `- file:` removed), MISSING. Write the
            enumeration into the spec as a comment so the next axis is added rather than rediscovered.
          family: parity-varies-only-cursor
          round: 3
        - id: BR-13
          severity: Minor
          title: REPEAT (2nd) - plan body still describes the implementation BR-2 removed
          detail: |-
            plan.md:86 and :937 both say DeleteEntity uses "ExchangeCut's preamble verbatim (init.lua:4423-4436)";
            the code now uses entity_textobj.parsed_for. The Revisions entry records the delta but the body was not
            updated - the same pattern as BR-7 on the Core-concepts table. RULE - a Revisions entry recording a delta
            must be applied to the plan body it contradicts in the same edit.
          family: plan-table-understates-code
          round: 3
        - id: BR-14
          severity: Minor
          title: the gate pinned base == head, so the machine-read review window contained zero changes
          detail: |-
            Both required recipes exit 0 with no output. Reviewed the tree at HEAD and 85e116c2..HEAD instead. Worth
            checking before the next boundary - a gate that reviews an empty range passes silently.
          family: empty-review-window
          round: 3
      boundary: M1
      blocked: true
    - "n": 4
      timestamp: "2026-09-16T14:51:59-07:00"
      agent: claude
      dispose:
        - id: BR-2
          disposition: addressed
          note: init.lua:4529-4540 routes both surfaces through entity_textobj.parsed_for; reverting it in a scratch worktree turned the two separator-edited-away parity tests red ("surfaces diverge at row 1").
          round: 4
        - id: BR-4
          disposition: addressed
          note: SHAPES now has five entries varying document shape on disk and in-buffer; content_for() sizes each sweep correctly.
          round: 4
        - id: BR-5
          disposition: not-addressed
          note: entity_range.lua is not in this window at all; the floor parameter at :86/:91-93 is still unreachable and the :265 call site still omits it.
          round: 4
        - id: BR-8
          disposition: not-addressed
          note: README.md unchanged in this window; ie, <C-g>k, <C-g>K and the two :ParleyDelete* commands are still undocumented there.
          round: 4
        - id: BR-10
          disposition: addressed
          note: 'The BR-10 fixture now yields nil and rows 1/3/5/10 stay editable; the ^#%s*topic: hardcoding is gone. A sibling gap on the positive side is raised new as I-1.'
          round: 4
        - id: BR-11
          disposition: addressed
          note: The new title-shaped fixture reaches the terminator scan - verified red without the contiguous-run change (1 Fail in a scratch worktree).
          round: 4
        - id: BR-12
          disposition: addressed
          note: The rule and the (a)-(e) axis enumeration are written into the spec at :48-62, and the new axis was demonstrated red without its fix.
          round: 4
        - id: BR-13
          disposition: not-addressed
          note: plan.md:86 and :937 still say "ExchangeCut's preamble (init.lua:4423-4436)"; round 3 also added no Revisions entry for the contiguous-run change.
          round: 4
        - id: BR-14
          disposition: not-addressed
          note: Window is non-empty now, but base aa001961 IS the fix commit for BR-1/BR-2/BR-6/BR-7/BR-9, so its content sits in the base tree and those dispositions again had to be verified from the tree rather than the diff.
          round: 4
      findings:
        - id: BR-15
          severity: Important
          title: transcript_header_end rejects the header defaults.chat_template writes, so a long-template transcript has no floor at all
          detail: '3rd finding in this family (prevalence 3/3), so do NOT fix the instance - state the rule and write its enumeration. THE RULE - the header floor must accept every header shape Parley itself can write; its predicate may not be stricter than its writer. Measured - transcript_header_end(long_template_chat) = nil, and entity_range.range(nil, lines, 1) then returns paragraph 1..11 of 14, taking the header AND the first question on one dae in a markdown-classified buffer (the BR-1 scenario). Two independent disqualifiers - defaults.lua:80-83 are prose lines inside the front matter, and init.lua:3933''s blanket gsub("_", "\\_") turns the always-present system_prompt key (config.lua:226-230) into system\_prompt, which ^([%w_%.%+]+): cannot match. The enumeration - short_chat_template (passes), chat_template (fails), legacy topic/file/--- (passes), any rendered front matter carrying optional_headers (fails). Fix - a conformance test rendering every defaults.lua template through the real renderer and asserting a non-nil terminator, so a new template shape fails the suite instead of silently removing the floor. Its negative side belongs in the same test - transcript_header_end({"\# Recipe: soup", "", "---", "", "\#\# Two", "y"}) returns 3, so rows 1-3 of a genuine note are undeletable.'
          family: guard-gated-on-classification
          round: 4
        - id: BR-16
          severity: Minor
          title: chat_parser.lua:106 - a ternary whose two branches are both 2
          detail: 2nd finding in this family (BR-5 is the 1st and still open). THE RULE - a parameter or branch that cannot change the outcome is deleted, not documented. Enumeration - chat_parser.lua:106 `(front_matter and 2 or 2)`, and entity_range.lua:86/:91-93's floor parameter, unreachable because the row guard at :214-216 already returns nil and the only other call site (:265) omits it.
          family: unreachable-guard
          round: 4
        - id: BR-17
          severity: Minor
          title: the header-protection test's else-branch asserts a property of its own SHAPES literal, not of the code
          detail: 3rd in this family. entity_delete_parity_spec.lua:165-169 falls into an else-branch for the two shapes with no `---` and asserts `s.drop == 3 or s.edit == 3` - a tautology over the fixture table. THE RULE - a branch a test takes must assert something about the code, not about the fixture that selected it. The true assertion is available and holds - with no separator parsed_for returns "unparsable" and both surfaces leave the buffer byte-identical.
          family: partial-shape-test
          round: 4
        - id: BR-18
          severity: Minor
          title: the atlas insert swallowed the following paragraph and left the header table overstated
          detail: atlas/chat/entity_delete.md:41-53 - "In a plain markdown buffer there is no exchange kind..." is now glued onto the end of an over-long line instead of standing as its own paragraph. Separately :37 still says a header line is "at or above the ---" without the new contiguous-run qualifier.
          family: docs-edit-mangles-prose
          round: 4
      boundary: M1
      blocked: false
    - "n": 5
      timestamp: "2026-09-16T15:13:11-07:00"
      agent: claude
      findings:
        - id: BR-19
          severity: Important
          title: README still omits ie, <C-g>k, <C-g>K and both :ParleyDelete* commands while plan Task 14 Step 3 is ticked
          detail: |-
            2nd finding in this family; BR-8 was also disposed not-addressed at M1 rounds 3 and 4 and the M1 close
            commit 0d0b3801 does not touch README.md. README.md:13-20 covers dae/daE/yae/cae only, though README
            already documents peer commands (:ParleyStop, :ParleyToolOperations). Do NOT just add the missing line.
            THE RULE: every registry entry carrying a config_key and every M.cmd.* a milestone introduces must be
            reachable from README before that milestone closes. The enumeration is mechanical - registry entries whose
            config_key appears in the branch diff of lua/parley/config.lua, plus M.cmd. symbols added to init.lua -
            so ship the check (a spec beside single_source_sweeps_spec.lua, which already owns the identically shaped
            "every spec this branch ADDED is routed somewhere" sweep), not the paragraph.
          family: readme-omits-new-surface
          round: 5
        - id: BR-20
          severity: Important
          title: plan body claims a reuse and a file set the tree does not have - three live instances
          detail: |-
            3rd finding in this family (BR-7, BR-13, this). Instances - plan.md:7 says entity_range reuses
            highlight_structure.code_block_memo and it references it nowhere; the Integration-points table omits
            lua/parley/starter_config.lua and tests/unit/starter_config_spec.lua, the only change in the branch that
            alters what packaged-app users receive; and BR-13's instance is untouched, with :86 and :937 still naming
            "ExchangeCut's preamble (init.lua:4423-4436)" when ExchangeCut is at :4439 and the handler at :4529.
            BR-13 already stated the rule as an intention and the family repeated, so the enforceable form is
            mechanical - at the close gate, every path in git diff --name-only branch-point..HEAD over lua/ and tests/
            must appear in the Core-concepts table, and every file or file:line the plan names must resolve.
          family: plan-table-understates-code
          round: 5
        - id: BR-21
          severity: Important
          title: the paragraph walk has no fence wall, so dae inside a code block leaves an unterminated fence
          detail: |-
            Reproduced on a real parsed transcript - with lines 10..14 = ```lua / local a = 1 / blank / local b = 2 /
            ```, range(parsed, lines, 10) returns paragraph 10..12, so dae deletes the opener and its first stanza and
            leaves a bare closing fence; every following line then renders as code. Undo recovers it and dap behaves
            the same in plain markdown, hence Important not Critical - but the issue explicitly ruled strict dap parity
            a bug in a transcript and already added walls for headings and structural markers, and a fence is the same
            class. Plan Task 7 Step 3 is ticked and required EITHER wiring highlight_structure.code_block_memo into
            is_wall/section_range OR a test pinning current behavior plus an atlas note; the atlas note covers only
            heading-in-fence and no test pins either (entity_range_spec.lua:416 asserts only not-inverted/in-range, so
            it would stay green under any fence behavior). That also makes it the 2nd checkbox-without-artifact.
          family: range-splits-a-structure
          round: 5
        - id: BR-22
          severity: Important
          title: the M2 boundary pinned base == head, so the whole milestone sits outside the reviewed range
          detail: |-
            2nd finding in this family; BR-14 raised it at M1 round 3 and again at round 4. Both required recipes exit
            0 with no output at base == head == 0d0b3801, and M2's entire deliverable (e007f6c5, 49064ec4, cb17a0a6)
            predates that base because M1 and M2 were implemented together and M1 closed last. Measured prevalence -
            3 of 4 rounds on this issue could not verify from the pinned diff. Do NOT re-derive the window by hand.
            THE RULE - a boundary's BASE_SHA must be the parent of the milestone's own first commit rather than the
            previous boundary's tip, and a gate whose computed range is empty must refuse to record a verdict instead
            of accepting one over zero changes. The current derivation is correct only when milestones close in the
            order they were implemented, which is not what happened here and will recur.
          family: empty-review-window
          round: 5
        - id: BR-23
          severity: Minor
          title: the ARCH-CONSTRAINTS numbers exist only as atlas prose, with no spec guarding them
          detail: |-
            2nd in this family. atlas/chat/entity_delete.md states 13.6 / 24.7 / 97.8 ms and then says itself that no
            perf spec guards them, so they go stale silently when parse_chat changes. The rule - a declared operating
            envelope gets an executable check or the declaration is deleted; a prose number that the suite cannot
            re-derive is a claim, not a measurement. The page already records the recipe
            (tests.perf.chat_typing.build_fixture(n)), so turning that recipe into a spec with a wide assertion is the
            cheap fix.
          family: unreproducible-measurement
          round: 5
        - id: BR-24
          severity: Minor
          title: the parity spec mutates a module-level `shape` upvalue that fresh() reads
          detail: |-
            tests/integration/entity_delete_parity_spec.lua:78 declares `shape` at module scope and each it() body
            assigns it before looping; fresh() reads it. Correct only because busted runs the bodies sequentially.
            Pass the shape through fresh(s) instead.
          family: shared-mutable-test-fixture
          round: 5
        - id: BR-25
          severity: Minor
          title: help_desc strings for the entity family list operators inconsistently
          detail: |-
            keybinding_registry.lua:483 reads "dae/yae/cae" and :493 "die/yie/cie", but :503 lists only "(daE)".
            Cosmetic inconsistency in the :ParleyKeyBindings output for one family.
          family: inconsistent-error-handling
          round: 5
      boundary: M2
      blocked: true
---

# Gate ledger — parley.nvim#262 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-16T13:53:02-07:00 (claude) — passed

**Protocol error:** no valid findings block — this round contributed no findings.

## Round 2 — 2026-09-16T14:06:15-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Critical] `guard-gated-on-classification` header floor exists only for chat-classified buffers; dae on line 1 of a markdown-classified transcript empties the file
  entity_range.lua:206 derives floor from parsed.header_end, and parsed is
  non-nil only when not_chat() passed. not_chat rejects for five reasons
  unrelated to document shape (not under a chat root, non-timestamp
  filename, <5 lines, missing topic, missing file header). Reproduced: a
  transcript saved as notes-about-entities.md is classified markdown, the
  ae map is still installed, and dae on line 1 reduces the buffer to a
  single empty line. With a blank "# topic:" both surfaces also delete a
  section through EOF across the next 💬:. Violates the issue Done-when and
  atlas/chat/entity_delete.md:37. Fix: derive the floor from a pure
  transcript_header_end(lines) (topic-shaped line 1 or front matter, plus a
  --- terminator) whenever parsed is absent.
- **BR-2** [Critical] `guard-gated-on-classification` the command path's unparsable-header refusal is unreachable when not_chat fails, so the two surfaces diverge
  init.lua:4534-4545 puts the new refusal inside `if not reason then`.
  Editing the --- away leaves the latch at "chat" but makes not_chat return
  "missing header separator", so the guard is skipped and parsed_chat stays
  nil -- unclamped markdown semantics, no log line. Reproduced:
  :ParleyDeleteEntity on a heading inside the first answer deletes through
  EOF and swallows the next exchange, while `normal dae` on the identical
  state refuses. Breaks the parity claim the parity spec exists to defend.
- **BR-3** [Important] `checkbox-without-artifact` plan Task 11 Step 4 is ticked but no test exercises the streaming refusal
  grep over tests/ for DeleteEntity/DeleteToEnd/replace_user_lines finds
  only the parity spec's two vim.cmd calls. The refusal is the single
  documented asymmetry between the surfaces, named in the issue Done-when,
  in the plan's ARCH-ORDER paragraph ("Task 11 tests the refusal") and in
  the parity spec's scoping comment. Deliver it or untick Step 4 and record
  the deferral.
- **BR-4** [Important] `parity-varies-only-cursor` the parity spec varies only the cursor row, never the document shape, so classification divergence is invisible to it
  tests/integration/entity_delete_parity_spec.lua always builds a
  well-formed chat, so all 24 rows exercise the same classification branch.
  Both Criticals above stay green under it. Parameterise fresh() over a
  valid fixture, one with the --- removed, and one with the `- file:`
  header removed, and loop the existing assertions over all three.
- **BR-5** [Minor] `unreachable-guard` section_range's floor parameter is dead code
  entity_range.lua:88-90 can never fire: M.range:207 already returns nil
  for row < floor, and the to_end back-scan at :255 starts at floor. The
  second call site (:257) omits the argument. Drop it or make it the real
  enforcement point.
- **BR-6** [Minor] `inconsistent-error-handling` parse_chat is pcall-wrapped on one surface and bare on the other, with two different warning strings for one condition
  entity_textobj.lua:41 wraps parse_chat in pcall; init.lua:4544 calls
  M.parse_chat bare on identical input. The same "unreadable header"
  condition warns as "Parley: entity object needs a readable chat header…"
  on one surface and "DeleteEntity: chat header is unreadable…" on the
  other.
- **BR-7** [Minor] `plan-table-understates-code` Core concepts table still names only outline.lua:52-60 as the modified outline consumer
  plan.md:43 reads `lua/parley/outline.lua:52-60`; the diff also changed
  the token path at :254. The Revisions entry records this but the table
  row was never updated, so the table still understates the consumer set.
- **BR-8** [Minor] `readme-omits-new-surface` README documents dae/daE/yae/cae but not ie, <C-g>k or <C-g>K
  README.md:16-20 covers the outer objects only. atlas/ui/keybindings.md
  lists the full set, so this is a README-side omission of user-typed
  surface introduced in the same range.
- **BR-9** [Minor] `unreproducible-measurement` the atlas perf figures cannot be re-derived from the repo
  atlas/chat/entity_delete.md:80-88 records 13.6 / 24.7 / 97.8 ms, but no
  perf spec landed, so the numbers go stale silently when parse_chat
  changes.

## Round 3 — 2026-09-16T14:31:20-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — addressed — Verified by revert: dropping the transcript_header_end fallback at entity_range.lua:211-213 turns two tests red.
- BR-2 — not-addressed — Code verified correct by execution (HEAD refuses; reverted, the command takes 15 lines to 8 while dae is a no-op) but NO test fails without it - the whole suite stayed green on the reverted tree.
- BR-3 — addressed — Real pin: pcall-wrapping replace_user_lines in a scratch copy turns the refusal test red.
- BR-4 — not-addressed — The new axis varies filename/classification, not document shape; the --- removed and `- file:` removed shapes are absent, and that is exactly where BR-2 lived.
- BR-5 — not-addressed — section_range's floor guard at entity_range.lua:91-93 is still unreachable; the second call site at :262 still omits the argument.
- BR-6 — addressed — One shared parsed_for means one parse site and one pcall; the two message strings remain but each names its own surface, matching ExchangeCut/ExchangePaste convention.
- BR-7 — addressed — plan.md:43 now reads `lua/parley/outline.lua:52-60` **and `:254`**, and both paths are changed in the diff.
- BR-8 — not-addressed — README.md:16-20 is unchanged since round 2 - still no ie, <C-g>k or <C-g>K.
- BR-9 — addressed — atlas/chat/entity_delete.md:89-92 now states no spec guards the numbers and names the re-derivation recipe; tests/perf/chat_typing.lua:13 build_fixture verified to exist.

### Raised

- **BR-10** [Important] `partial-shape-test` transcript_header_end validates only line 1, then delegates to an unbounded find_header_end scan
  chat_parser.lua:79-84 gates on `^#%s*topic:` and then returns the first `---` anywhere in the file.
  Reproduced: for a genuine note `{ "# topic: how to cook", "", "Intro paragraph.", "", "## Step one",
  "prep", "", "---", "", "## Step two", "cook" }` it returns 8, so the floor is 9 and range() returns nil
  for rows 1-8 - dae is silently dead over two real sections and a paragraph. Same shape hits a transcript
  whose --- was edited away. Fails closed (no data loss), hence Important. Fix: require the terminator to
  close a contiguous run of header-shaped lines, the shape parse_chat_headers already knows. ARCH-DRY note
  at the same site: `^#%s*topic:` is a third hardcoding of the transcript first-line shape.
- **BR-11** [Important] `partial-shape-test` the unit test for that property uses a non-topic-shaped title, so it never reaches the scan
  entity_range_spec "does not floor a thematic break in a genuine markdown note" uses `# My Note`, which
  exits at the line-1 guard. It reads as pinning the stated property but pins only half of it. Add the
  `# topic: ...`-titled fixture.
- **BR-12** [Important] `parity-varies-only-cursor` REPEAT (2nd) - the parity spec still cannot see the axis BR-2 lived on; state the rule, not the instance
  Measured prevalence 2/2. Evidence: reverting the BR-2 fix in a git-backed scratch left all 5 parity tests
  and all 15 entity_textobj tests green, while a direct probe on that same tree showed the surfaces diverging
  15 lines to 8. RULE - a parity spec must vary every axis along which the two surfaces could disagree, and
  each axis must be demonstrated red-without-its-fix. Enumeration for this spec - (a) cursor row, done;
  (b) classification, done; (c) document shape (--- removed, `- file:` removed), MISSING. Write the
  enumeration into the spec as a comment so the next axis is added rather than rediscovered.
- **BR-13** [Minor] `plan-table-understates-code` REPEAT (2nd) - plan body still describes the implementation BR-2 removed
  plan.md:86 and :937 both say DeleteEntity uses "ExchangeCut's preamble verbatim (init.lua:4423-4436)";
  the code now uses entity_textobj.parsed_for. The Revisions entry records the delta but the body was not
  updated - the same pattern as BR-7 on the Core-concepts table. RULE - a Revisions entry recording a delta
  must be applied to the plan body it contradicts in the same edit.
- **BR-14** [Minor] `empty-review-window` the gate pinned base == head, so the machine-read review window contained zero changes
  Both required recipes exit 0 with no output. Reviewed the tree at HEAD and 85e116c2..HEAD instead. Worth
  checking before the next boundary - a gate that reviews an empty range passes silently.

## Round 4 — 2026-09-16T14:51:59-07:00 (claude) — passed

### Disposed

- BR-2 — addressed — init.lua:4529-4540 routes both surfaces through entity_textobj.parsed_for; reverting it in a scratch worktree turned the two separator-edited-away parity tests red ("surfaces diverge at row 1").
- BR-4 — addressed — SHAPES now has five entries varying document shape on disk and in-buffer; content_for() sizes each sweep correctly.
- BR-5 — not-addressed — entity_range.lua is not in this window at all; the floor parameter at :86/:91-93 is still unreachable and the :265 call site still omits it.
- BR-8 — not-addressed — README.md unchanged in this window; ie, <C-g>k, <C-g>K and the two :ParleyDelete* commands are still undocumented there.
- BR-10 — addressed — The BR-10 fixture now yields nil and rows 1/3/5/10 stay editable; the ^#%s*topic: hardcoding is gone. A sibling gap on the positive side is raised new as I-1.
- BR-11 — addressed — The new title-shaped fixture reaches the terminator scan - verified red without the contiguous-run change (1 Fail in a scratch worktree).
- BR-12 — addressed — The rule and the (a)-(e) axis enumeration are written into the spec at :48-62, and the new axis was demonstrated red without its fix.
- BR-13 — not-addressed — plan.md:86 and :937 still say "ExchangeCut's preamble (init.lua:4423-4436)"; round 3 also added no Revisions entry for the contiguous-run change.
- BR-14 — not-addressed — Window is non-empty now, but base aa001961 IS the fix commit for BR-1/BR-2/BR-6/BR-7/BR-9, so its content sits in the base tree and those dispositions again had to be verified from the tree rather than the diff.

### Raised

- **BR-15** [Important] `guard-gated-on-classification` transcript_header_end rejects the header defaults.chat_template writes, so a long-template transcript has no floor at all
  3rd finding in this family (prevalence 3/3), so do NOT fix the instance - state the rule and write its enumeration. THE RULE - the header floor must accept every header shape Parley itself can write; its predicate may not be stricter than its writer. Measured - transcript_header_end(long_template_chat) = nil, and entity_range.range(nil, lines, 1) then returns paragraph 1..11 of 14, taking the header AND the first question on one dae in a markdown-classified buffer (the BR-1 scenario). Two independent disqualifiers - defaults.lua:80-83 are prose lines inside the front matter, and init.lua:3933's blanket gsub("_", "\\_") turns the always-present system_prompt key (config.lua:226-230) into system\_prompt, which ^([%w_%.%+]+): cannot match. The enumeration - short_chat_template (passes), chat_template (fails), legacy topic/file/--- (passes), any rendered front matter carrying optional_headers (fails). Fix - a conformance test rendering every defaults.lua template through the real renderer and asserting a non-nil terminator, so a new template shape fails the suite instead of silently removing the floor. Its negative side belongs in the same test - transcript_header_end({"\# Recipe: soup", "", "---", "", "\#\# Two", "y"}) returns 3, so rows 1-3 of a genuine note are undeletable.
- **BR-16** [Minor] `unreachable-guard` chat_parser.lua:106 - a ternary whose two branches are both 2
  2nd finding in this family (BR-5 is the 1st and still open). THE RULE - a parameter or branch that cannot change the outcome is deleted, not documented. Enumeration - chat_parser.lua:106 `(front_matter and 2 or 2)`, and entity_range.lua:86/:91-93's floor parameter, unreachable because the row guard at :214-216 already returns nil and the only other call site (:265) omits it.
- **BR-17** [Minor] `partial-shape-test` the header-protection test's else-branch asserts a property of its own SHAPES literal, not of the code
  3rd in this family. entity_delete_parity_spec.lua:165-169 falls into an else-branch for the two shapes with no `---` and asserts `s.drop == 3 or s.edit == 3` - a tautology over the fixture table. THE RULE - a branch a test takes must assert something about the code, not about the fixture that selected it. The true assertion is available and holds - with no separator parsed_for returns "unparsable" and both surfaces leave the buffer byte-identical.
- **BR-18** [Minor] `docs-edit-mangles-prose` the atlas insert swallowed the following paragraph and left the header table overstated
  atlas/chat/entity_delete.md:41-53 - "In a plain markdown buffer there is no exchange kind..." is now glued onto the end of an over-long line instead of standing as its own paragraph. Separately :37 still says a header line is "at or above the ---" without the new contiguous-run qualifier.

## Round 5 — 2026-09-16T15:13:11-07:00 (claude) — BLOCKED

### Raised

- **BR-19** [Important] `readme-omits-new-surface` README still omits ie, <C-g>k, <C-g>K and both :ParleyDelete* commands while plan Task 14 Step 3 is ticked
  2nd finding in this family; BR-8 was also disposed not-addressed at M1 rounds 3 and 4 and the M1 close
  commit 0d0b3801 does not touch README.md. README.md:13-20 covers dae/daE/yae/cae only, though README
  already documents peer commands (:ParleyStop, :ParleyToolOperations). Do NOT just add the missing line.
  THE RULE: every registry entry carrying a config_key and every M.cmd.* a milestone introduces must be
  reachable from README before that milestone closes. The enumeration is mechanical - registry entries whose
  config_key appears in the branch diff of lua/parley/config.lua, plus M.cmd. symbols added to init.lua -
  so ship the check (a spec beside single_source_sweeps_spec.lua, which already owns the identically shaped
  "every spec this branch ADDED is routed somewhere" sweep), not the paragraph.
- **BR-20** [Important] `plan-table-understates-code` plan body claims a reuse and a file set the tree does not have - three live instances
  3rd finding in this family (BR-7, BR-13, this). Instances - plan.md:7 says entity_range reuses
  highlight_structure.code_block_memo and it references it nowhere; the Integration-points table omits
  lua/parley/starter_config.lua and tests/unit/starter_config_spec.lua, the only change in the branch that
  alters what packaged-app users receive; and BR-13's instance is untouched, with :86 and :937 still naming
  "ExchangeCut's preamble (init.lua:4423-4436)" when ExchangeCut is at :4439 and the handler at :4529.
  BR-13 already stated the rule as an intention and the family repeated, so the enforceable form is
  mechanical - at the close gate, every path in git diff --name-only branch-point..HEAD over lua/ and tests/
  must appear in the Core-concepts table, and every file or file:line the plan names must resolve.
- **BR-21** [Important] `range-splits-a-structure` the paragraph walk has no fence wall, so dae inside a code block leaves an unterminated fence
  Reproduced on a real parsed transcript - with lines 10..14 = ```lua / local a = 1 / blank / local b = 2 /
  ```, range(parsed, lines, 10) returns paragraph 10..12, so dae deletes the opener and its first stanza and
  leaves a bare closing fence; every following line then renders as code. Undo recovers it and dap behaves
  the same in plain markdown, hence Important not Critical - but the issue explicitly ruled strict dap parity
  a bug in a transcript and already added walls for headings and structural markers, and a fence is the same
  class. Plan Task 7 Step 3 is ticked and required EITHER wiring highlight_structure.code_block_memo into
  is_wall/section_range OR a test pinning current behavior plus an atlas note; the atlas note covers only
  heading-in-fence and no test pins either (entity_range_spec.lua:416 asserts only not-inverted/in-range, so
  it would stay green under any fence behavior). That also makes it the 2nd checkbox-without-artifact.
- **BR-22** [Important] `empty-review-window` the M2 boundary pinned base == head, so the whole milestone sits outside the reviewed range
  2nd finding in this family; BR-14 raised it at M1 round 3 and again at round 4. Both required recipes exit
  0 with no output at base == head == 0d0b3801, and M2's entire deliverable (e007f6c5, 49064ec4, cb17a0a6)
  predates that base because M1 and M2 were implemented together and M1 closed last. Measured prevalence -
  3 of 4 rounds on this issue could not verify from the pinned diff. Do NOT re-derive the window by hand.
  THE RULE - a boundary's BASE_SHA must be the parent of the milestone's own first commit rather than the
  previous boundary's tip, and a gate whose computed range is empty must refuse to record a verdict instead
  of accepting one over zero changes. The current derivation is correct only when milestones close in the
  order they were implemented, which is not what happened here and will recur.
- **BR-23** [Minor] `unreproducible-measurement` the ARCH-CONSTRAINTS numbers exist only as atlas prose, with no spec guarding them
  2nd in this family. atlas/chat/entity_delete.md states 13.6 / 24.7 / 97.8 ms and then says itself that no
  perf spec guards them, so they go stale silently when parse_chat changes. The rule - a declared operating
  envelope gets an executable check or the declaration is deleted; a prose number that the suite cannot
  re-derive is a claim, not a measurement. The page already records the recipe
  (tests.perf.chat_typing.build_fixture(n)), so turning that recipe into a spec with a wide assertion is the
  cheap fix.
- **BR-24** [Minor] `shared-mutable-test-fixture` the parity spec mutates a module-level `shape` upvalue that fresh() reads
  tests/integration/entity_delete_parity_spec.lua:78 declares `shape` at module scope and each it() body
  assigns it before looping; fresh() reads it. Correct only because busted runs the bodies sequentially.
  Pass the shape through fresh(s) instead.
- **BR-25** [Minor] `inconsistent-error-handling` help_desc strings for the entity family list operators inconsistently
  keybinding_registry.lua:483 reads "dae/yae/cae" and :493 "die/yie/cie", but :503 lists only "(daE)".
  Cosmetic inconsistency in the :ParleyKeyBindings output for one family.

## Open findings

- **BR-5** [Minor] `unreachable-guard` section_range's floor parameter is dead code
- **BR-8** [Minor] `readme-omits-new-surface` README documents dae/daE/yae/cae but not ie, <C-g>k or <C-g>K
- **BR-13** [Minor] `plan-table-understates-code` REPEAT (2nd) - plan body still describes the implementation BR-2 removed
- **BR-14** [Minor] `empty-review-window` the gate pinned base == head, so the machine-read review window contained zero changes
- **BR-15** [Important] `guard-gated-on-classification` transcript_header_end rejects the header defaults.chat_template writes, so a long-template transcript has no floor at all
- **BR-16** [Minor] `unreachable-guard` chat_parser.lua:106 - a ternary whose two branches are both 2
- **BR-17** [Minor] `partial-shape-test` the header-protection test's else-branch asserts a property of its own SHAPES literal, not of the code
- **BR-18** [Minor] `docs-edit-mangles-prose` the atlas insert swallowed the following paragraph and left the header table overstated
- **BR-19** [Important] `readme-omits-new-surface` README still omits ie, <C-g>k, <C-g>K and both :ParleyDelete* commands while plan Task 14 Step 3 is ticked
- **BR-20** [Important] `plan-table-understates-code` plan body claims a reuse and a file set the tree does not have - three live instances
- **BR-21** [Important] `range-splits-a-structure` the paragraph walk has no fence wall, so dae inside a code block leaves an unterminated fence
- **BR-22** [Important] `empty-review-window` the M2 boundary pinned base == head, so the whole milestone sits outside the reviewed range
- **BR-23** [Minor] `unreproducible-measurement` the ARCH-CONSTRAINTS numbers exist only as atlas prose, with no spec guarding them
- **BR-24** [Minor] `shared-mutable-test-fixture` the parity spec mutates a module-level `shape` upvalue that fresh() reads
- **BR-25** [Minor] `inconsistent-error-handling` help_desc strings for the entity family list operators inconsistently
