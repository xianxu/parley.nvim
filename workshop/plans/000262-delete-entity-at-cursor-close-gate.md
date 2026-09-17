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
    - "n": 6
      timestamp: "2026-09-16T15:35:52-07:00"
      agent: claude
      dispose:
        - id: BR-19
          disposition: addressed
          note: README.md:17-24 now covers ae/ie/aE, dae/yae/cae, Ctrl+g k, Ctrl+g K and both :ParleyDelete* commands - all five config_keys and both M.cmd symbols reachable; the enforcing check was NOT shipped, so the family stays hand-maintained (see ARCH-PURPOSE note).
          round: 6
        - id: BR-20
          disposition: not-addressed
          note: Two of four instances fixed (:87/:938 -> 4439, starter_config added to the table, code_block_memo reuse now real); plan.md:53 still says ChatPrune init.lua:4255 (actual 4271) and ExchangeCut init.lua:4423 (actual 4439), and :852 cites init.lua:2803 as chat_exchange_cut when that line is chat_search.
          round: 6
        - id: BR-21
          disposition: addressed
          note: Verified red without the fix in a scratch worktree at f53af775 - 4 of 5 new fence cases fail. The backtick instance is fixed with genuine regression evidence; the tilde/indented sibling is raised separately.
          round: 6
        - id: BR-22
          disposition: not-addressed
          note: Window is base == head == f53af775 - both required recipes exit 0 with no output, for the third round running. A correct prev-boundary..HEAD range (0d0b3801..f53af775) would have been non-empty here, so the derivation is pinning base to HEAD, not just mis-ordering milestones. Prevalence now 4 of 6 rounds on this issue.
          round: 6
        - id: BR-23
          disposition: not-addressed
          note: No perf spec added; atlas/chat/entity_delete.md still states the numbers and then says nothing guards them. I re-measured independently (parse_chat 29.6 ms, code_block_memo 0.79 ms at 5000 lines) - same shape, still unreproducible by the suite.
          round: 6
        - id: BR-24
          disposition: not-addressed
          note: entity_delete_parity_spec.lua:78 still declares `local shape = SHAPES[1]` at module scope with each it() assigning it and fresh() reading it.
          round: 6
        - id: BR-25
          disposition: not-addressed
          note: keybinding_registry.lua:483/493/503 unchanged - "dae/yae/cae", "die/yie/cie", then "(daE)" alone.
          round: 6
      findings:
        - id: BR-26
          severity: Important
          title: the fence wall recognizes only column-zero backticks while code_block_memo recognizes ~~~ and indented fences, so BR-21 still reproduces one fence flavor over
          detail: 2nd finding in family range-splits-a-structure. entity_range.lua:61 walls on fence.open_len (lexical.ordinary_open_len, pattern ^(`+)([^`]*)$, column zero, backticks only); entity_range.lua:230 builds in_code from code_block_memo, which uses lexical.is_fence_delim(line, true) - ^%s*(`+) plus ^%s*(~+). Two definitions of one fact, added in the same commit. Measured on real parsed transcripts - with rows 10..14 = ~~~lua / local a = 1 / blank / local b = 2 / ~~~, range(parsed, lines, 10) returns paragraph 10..12 and range(parsed, lines, 14) returns paragraph 13..15, so dae leaves a bare ~~~ and the rest of the transcript renders as code; a three-space-indented ``` opener gives the identical 10..12. Same undo-recoverable severity reasoning BR-21 carried. Do NOT add a tilde branch to is_wall. THE RULE - entity_range must consume ONE fence-delimiter predicate, and it must be the one code_block_memo uses (lexical.is_fence_delim), so a line the memo counts as a fence is necessarily a wall; that also removes the only require sitting inside a per-line loop. The parity spec structurally cannot see this axis (both surfaces share the range function and agree on the wrong answer), so the guard goes in entity_range_spec - parameterize the existing code fences block over the three delimiter shapes rather than adding a second fixture. fence.lua:9-14 records that this exact rule already had three independent implementations once (#200).
          family: range-splits-a-structure
          round: 6
        - id: BR-27
          severity: Minor
          title: the fence docs describe behavior the code does not have, in both the atlas page and the module docstring
          detail: 2nd finding in family docs-edit-mangles-prose. atlas/chat/entity_delete.md:94-95 says a "# heading" inside a fenced block "is content rather than a section"; measured, range() returns nil on that row - a no-op, neither section nor content - and the Precedence table gained a row for fence lines but none for this case. entity_range.lua:10 still opens "Five rules, each stated once" over six numbered rules, and the fence rule is not enumerated among them. THE RULE the family points at - a docs edit that accompanies a behavior change must be read back against the behavior, not just inserted; both sites here were written from the intent rather than from what range() returns.
          family: docs-edit-mangles-prose
          round: 6
        - id: BR-28
          severity: Minor
          title: the plan body was edited for the M2 review with no "## Revisions" entry recording the deltas
          detail: 4th finding in family plan-table-understates-code. plan.md:7, :82, :87, :797, :938 and the struck-through open item 3 all changed at f53af775; the plan's Revisions section still ends at "M1 boundary review round 2". AGENTS.md section 1 requires an appended Revisions entry (timestamp, reason, delta) rather than an overwrite. The issue "## Log" carries the narrative so nothing is lost, which is why this is Minor - but the plan's own history now misstates when it last moved, and BR-13 already stated the Revisions/body consistency rule for the opposite direction.
          family: plan-table-understates-code
          round: 6
      boundary: M2
      blocked: true
    - "n": 7
      timestamp: "2026-09-16T16:04:38-07:00"
      agent: claude
      dispose:
        - id: BR-20
          disposition: not-addressed
          note: 'File-set half now holds (all 16 branch lua/tests paths resolve; starter_config row at plan.md:82); file:line half does not - plan.md:53 still says ChatPrune init.lua:4255 (4271) and ExchangeCut init.lua:4423 (4439), :852 cites init.lua:2803 as chat_exchange_cut (that line is chat_search), and this round created a new instance: :7 still lists fence.open_len as a reused primitive after a3fcf7ea removed its only call.'
          round: 7
        - id: BR-22
          disposition: not-addressed
          note: Empty-range half no longer reproduces (f53af775..8c2e3150 is 6 files), but base is still the previous round's tip, so M2's actual deliverable (e007f6c5, 49064ec4, cb17a0a6) remains outside every M2 window - the parity-spec defect I raise this round lives in cb17a0a6 and has therefore never been in a reviewed range. Prevalence 4 of 7 rounds.
          round: 7
        - id: BR-23
          disposition: not-addressed
          note: 'No perf spec; atlas:105-116 still carries 13.6/24.7/97.8 ms plus its own admission that nothing guards them. The plan now records the drop as an explicit operator call (Task 13, "Perf module: dropped, measured instead"), so it is a documented residual rather than an oversight - but the declaration is neither guarded nor deleted.'
          round: 7
        - id: BR-24
          disposition: not-addressed
          note: entity_delete_parity_spec.lua:78 still declares `local shape = SHAPES[1]` at module scope with fresh() reading it; newly relevant because that spec now aborts nondeterministically and module-scope shared state is what makes such an abort hard to localize.
          round: 7
        - id: BR-25
          disposition: not-addressed
          note: keybinding_registry.lua:483/493/503 unchanged - "dae/yae/cae", "die/yie/cie", then "(daE)" alone.
          round: 7
        - id: BR-26
          disposition: addressed
          note: 'entity_range.lua:65 now calls lexical.is_fence_delim(line, true), the same predicate and tildes flag code_block_memo uses at :234-235; scratch-reverting that one line turns entity_range_spec red (43 pass / 1 fail), so the regression evidence is real. Residual: the require still sits inside the per-line is_wall loop, which the rule asked to remove.'
          round: 7
        - id: BR-27
          disposition: not-addressed
          note: atlas:94-95 unchanged - still says a "# heading" inside a fence "is content rather than a section" where range() returns nil; entity_range.lua:10 still opens "Five rules, each stated once" over six rules and still omits the fence rule. The added paragraph at atlas:100-104 is accurate but sits above the two sentences the finding named.
          round: 7
        - id: BR-28
          disposition: not-addressed
          note: This window edits plan.md:978-981 and the Revisions section still ends at "M1 boundary review round 2"; no entry for the f53af775 edits either.
          round: 7
      findings:
        - id: BR-29
          severity: Critical
          title: the parity spec - the milestone's named best guard - exits 1 without completing, while the plan ticks it as passing
          detail: '2nd finding in family checkbox-without-artifact. tests/integration/entity_delete_parity_spec.lua exits 1 with an EMPTY stderr and no busted summary, aborting after a nondeterministic subset of its 11 tests. Measured 6 of 6 runs - `make test-spec SPEC=chat/entity_delete` stopped after 1, 3 and 6 tests (the third with a fresh TEST_ENV_ROOT), a make-equivalent raw invocation stopped after 6 twice, and a variant limited to `for row = 1, 4` stopped after 4. No crash report in ~/Library/Logs/DiagnosticReports. So the last two SHAPES - including `separator-edited-away`, added by the M1 round-2 rework as "the axis BR-2 actually lived on" - and the `never reaches into a header` test have never executed. RUN_SPEC keys on exit status, so `make test-integration` on this branch lists the file under "Failed integration test files"; plan.md Task 13 Step 2 ("Run it and watch it pass") and Task 15 Step 1 (`make test`) are both ticked. Calibration - this environment has pre-existing failures (async_builtin_spec and parley_harness_golden_spec fail on main too, neither is this branch''s), but entity_range_spec and entity_textobj_spec pass cleanly here with proper summaries. THE RULE - a boundary may not record "watched it pass" for a spec file whose runner exits non-zero; the exit status is the evidence, not the Success lines that precede the abort. Likely cause to start from: run() at :120-125 calls fresh() twice per row and never wipes the buffer, so one process accumulates ~660 buffers, ~660 files and ~660 parley.setup() calls with no teardown. Also note base_tmp_dir at :16 hardcodes a "/claude/" path segment - an agent-sandbox artifact that should not be in a committed spec.'
          family: checkbox-without-artifact
          round: 7
        - id: BR-30
          severity: Important
          title: section_range and the to_end backward scan read heading.level with no in-code filter, so a section range ends ON the opening fence
          detail: '3rd finding in family range-splits-a-structure. Do NOT patch section_range alone. THE RULE - entity_range.range must classify each row ONCE per call and every walk must consume that one classification - blank / heading / fence / marker / text, with in_code[row] demoting a heading to text - so that is_wall, section_range''s forward scan and the to_end backward scan cannot disagree. The enumeration the rule implies, all in lua/parley/entity_range.lua - :58 (heading.level in is_wall), :65 (fence in is_wall), :99 and :108 (heading.level in section_range), :282 (heading.level in the to_end backward scan). Only :253 consults in_code, and only for the cursor row. BR-21 was :58/:65 missing the fence; BR-26 was :65 using a different fence predicate from :234; this is :108 and :282 using a different heading predicate from :253. Measured with real chat_parser.parse_chat - chat buffer `## Section / prose / ```lua / # inner heading / code / ``` / tail` gives range(parsed, lines, 8) -> section 8..10 where row 10 is the ```lua opener, and {inner=true} gives 9..10; plain markdown `# Top / alpha / "" / ```lua / # fake / code / ``` / omega` gives range(nil, lines, 1) -> section 1..4, again ending on the opener. dae there leaves a bare closing fence and the rest of the transcript renders as code - the same corruption and the same undo-recoverable severity BR-21 carried. Separately the to_end backward scan at :282 latches onto an in-fence heading and returned 8..9 where the correct answer was 8..#lines. This contradicts atlas/chat/entity_delete.md:94, which states "A fence line is never deleted, a range never spans one". GUARD at the rule''s level, not per flavour - extend the existing `entity_range invariants` property test over a fenced fixture and assert that no returned range contains an ODD number of is_fence_delim lines, for every row x {scope, inner}; that one invariant catches BR-21, BR-26 and this at once. The parity spec structurally cannot see any of them - both surfaces share the range function and agree on the wrong answer.'
          family: range-splits-a-structure
          round: 7
        - id: BR-31
          severity: Minor
          title: dead assignment in the new fence-flavour test - body[10] is computed and then immediately overwritten
          detail: '3rd finding in family unreachable-guard. tests/unit/entity_range_spec.lua:486 initializes body[10] to `delim:gsub("%S+$", ""):gsub("^%s*", "") ~= "" and "```" or delim`, which :488 discards. THE RULE covering BR-5 (section_range''s dead floor parameter), BR-16 (a ternary whose two branches are both 2) and this - no line in the diff may have zero consumers; a value that nothing reads is either a missing call site or dead code, and review should resolve which before the boundary. Here it is dead code: delete the computed initializer and build body[10] once.'
          family: unreachable-guard
          round: 7
      boundary: M2
      blocked: true
    - "n": 8
      timestamp: "2026-09-16T16:35:13-07:00"
      agent: claude
      dispose:
        - id: BR-20
          disposition: not-addressed
          note: File-set half holds. Three file:line instances still live - plan.md:7 lists fence.open_len as a reused primitive though a3fcf7ea removed its only call (entity_range requires parley.fence nowhere); plan.md:53 says ChatPrune init.lua:4255 (actual 4271) and ExchangeCut init.lua:4423 (actual 4439); plan.md:852 cites init.lua:2803-2812 as chat_exchange_cut when 2803 is chat_search and chat_exchange_cut is 2811. 4th round open, no mechanical check shipped.
          round: 8
        - id: BR-22
          disposition: not-addressed
          note: Empty-window symptom is gone (f53af775..4eca1d7d is 8 files), but base is the previous ROUND's base, not the parent of M2's own first commit - so M2's actual deliverable (e007f6c5, 49064ec4, cb17a0a6) has still never appeared in any reviewed range. Prevalence 5 of 8 rounds. Fix belongs in the sdlc derivation, not here.
          round: 8
        - id: BR-23
          disposition: not-addressed
          note: tests/perf holds chat_typing/document/harness/ownership; nothing under tests/perf or tests/arch references entity_range. atlas/chat/entity_delete.md:105-116 still states 13.6/24.7/97.8 ms alongside its own admission that no spec guards them.
          round: 8
        - id: BR-24
          disposition: not-addressed
          note: entity_delete_parity_spec.lua:78 still declares `local shape = SHAPES[1]` at module scope with each it() assigning it and fresh() reading it - and this round ADDED a second module-level mutable, `did_setup` at :86, also read by fresh(). Correct only because busted runs the bodies sequentially; there is still no seam to run them in any other order.
          round: 8
        - id: BR-25
          disposition: not-addressed
          note: keybinding_registry.lua:483/493/503 unchanged - "(dae/yae/cae)", "(die/yie/cie)", then "(daE)" alone.
          round: 8
        - id: BR-27
          disposition: not-addressed
          note: atlas/chat/entity_delete.md:94-95 is verbatim unchanged; re-measured, range() returns nil on a `# x` inside a fence (neither section nor content) and the Precedence table still has no row for it. entity_range.lua:10 still opens "Five rules, each stated once" over six, and plan.md:66 carries the identical "Five rules" claim over a set that now includes the header floor and the fence wall - the same drift in a third document.
          round: 8
        - id: BR-28
          disposition: not-addressed
          note: plan.md moved again in this window (:978-981, the perf-module strikethrough at 4eca1d7d) and the Revisions section still ends at "M1 boundary review round 2". Four body deltas since f53af775 are now unrecorded.
          round: 8
        - id: BR-29
          disposition: addressed
          note: Measured 4 consecutive `make test-spec SPEC=chat/entity_delete` runs - exit 0 every time, parity 11/11 with a real busted summary, all five SHAPES including separator-edited-away plus the header test executed, full mapped set 45/15/11/1/4 green. Withdrawing the sub-claim about base_tmp_dir's "/claude/" segment - it is an established repo convention in 34 test files, under the harness TMPDIR that test-clean-env wipes, not an agent-sandbox artifact.
          round: 8
        - id: BR-30
          disposition: not-addressed
          note: Instances fixed and genuinely pinned - scratch-revert at 4eca1d7d reds the new spec 44/1, and all three measured cases now return the correct range (section 8..14, 1..8, to_end 2..8). The CLASS was not swept - the odd-fence invariant the finding specified was not shipped, and running it now fails 8 times (see the new to_end finding); :58's heading read is still ungated (a `# x` in a fence is a no-op that splits a code sample into two paragraphs, benign but the fourth spelling of the same classification); and the fix itself writes "the effective heading level at row i" three different ways at :102, :111 and :285.
          round: 8
        - id: BR-31
          disposition: not-addressed
          note: entity_range_spec.lua:490 still computes a body[10] initializer that :492 immediately discards. Plus a new instance of the same rule inside the fix under review - section_range's `in_code and` nil-guards at :102 and :111 have zero reachable call sites (both callers, :256 and :286, pass the always-built memo), while :285 reads in_code[i] with no guard at all. A guard and its absence over one fact, three lines apart. 4th in family.
          round: 8
      findings:
        - id: BR-32
          severity: Important
          title: the to_end scope overwrites found.last from the exchange bound without re-applying the fence wall, so daE inside a code block strands the opening fence
          detail: 4th finding in family range-splits-a-structure. entity_range.lua:279-291 assigns found.last = bounds.last (or the enclosing section's end) with no fence check, bypassing is_wall entirely. Measured on a real parse_chat with two exchanges and a fence at rows 10-13 - range(p, L, 11, {scope="to_end"}) returns paragraph 11..15, and deleting it leaves ```lua at row 10 with no closer, so the second question and everything after it render as code. BR-21's exact corruption, undo-recoverable, hence Important rather than Critical - the same calibration BR-21 and BR-26 were given. Found by writing the guard BR-30 specified - over four fenced fixtures (chat backtick, chat tilde, indented, plain markdown) x every row x {entity,to_end} x {inner,outer}, the even-fence invariant fails 8 times, all on to_end, zero on entity. DO NOT patch to_end. The four instances broke four different producers (no fence test, wrong fence predicate, wrong heading predicate, and now bypassing the wall outright), so guarding producers one at a time is what keeps failing. THE RULE - guard the RESULT in one place - M.range has exactly one exit at :296-299; give it one post-condition, that the returned [first,last] may not contain an unmatched lexical.is_fence_delim line, and clamp or refuse there. That subsumes BR-21, BR-26, BR-30 and this. First resolve the contract conflict it exposes - atlas/chat/entity_delete.md:94 says "a range never spans one" (reaffirmed in this window at :99-104) while issue :189 says the extended range runs "through the end of the current exchange". Pick one; if to_end is an intentional exception it must be a named carve-out in both the atlas and the invariant, not an absent test.
          family: range-splits-a-structure
          round: 8
        - id: BR-33
          severity: Minor
          title: the parity spec writes one chat file per iteration with no removal path - run() now releases the buffer but not the file
          detail: ARCH-FUNERAL. entity_delete_parity_spec.lua:98-131 - fresh() writes a chat file into base_tmp_dir on every call and nothing deletes it; the teardown added this round frees the buffer only. make test-spec runs PREP_TEST_ENV but never test-clean-env, so the residue is collected only by a later full make test. Measured after a handful of runs - 2 902 files / 11 MB across 12 per-run directories under the harness scratch root. One vim.fn.delete(path) in run() bounds it.
          family: artifact-without-removal-path
          round: 8
      boundary: M2
      blocked: false
    - "n": 9
      timestamp: "2026-09-16T17:04:38-07:00"
      agent: claude
      dispose:
        - id: BR-5
          disposition: addressed
          note: section_range is now (lines, row, bounds, in_code) - the floor parameter is gone, and :106-107 documents why a second floor test could not change the outcome.
          round: 9
        - id: BR-8
          disposition: addressed
          note: README.md:16-25 now names ae, ie, aE, dae/yae/cae, Ctrl+g k, Ctrl+g K and both :ParleyDelete* commands.
          round: 9
        - id: BR-13
          disposition: not-addressed
          note: Line refs corrected to 4439, but plan.md:87 and :938 still say DeleteEntity is "ExchangeCut's preamble (verbatim)"; init.lua:4529-4540 uses entity_textobj.parsed_for, not ExchangeCut's not_chat preamble.
          round: 9
        - id: BR-14
          disposition: addressed
          note: This gate's base 85e116c2 is merge-base(main,HEAD); stat and name-status both return 31 files, so the window is real.
          round: 9
        - id: BR-15
          disposition: addressed
          note: 'Front-matter branch at chat_parser.lua:108-115 plus a conformance test rendering both defaults templates through the real renderer and new_chat''s underscore escape; scratch-reverting the branch reds entity_range_spec 43/2 on "chat_template must yield a header terminator". Negative side (# Recipe: soup) asserted too.'
          round: 9
        - id: BR-16
          disposition: addressed
          note: No occurrence of "and 2 or 2" remains anywhere under lua/ or tests/.
          round: 9
        - id: BR-17
          disposition: addressed
          note: entity_delete_parity_spec.lua:186-195 - the no-header branch now asserts that the two surfaces agree on rows 1-3, a property of the code rather than of the SHAPES literal.
          round: 9
        - id: BR-18
          disposition: addressed
          note: '"In a plain markdown buffer there is no exchange kind..." stands as its own paragraph again, and the header table row now points at the "What counts as a header" paragraph, which states the contiguous-run qualifier in full.'
          round: 9
        - id: BR-20
          disposition: not-addressed
          note: File-set half holds (all 16 changed lua/ and tests/ paths appear in the plan). File:line half does not - plan.md:7 still lists fence.open_len though entity_range requires parley.fence nowhere; :53 says ChatPrune 4255 (actual 4271) and ExchangeCut 4423 (actual 4439); :852 cites init.lua:2803-2812 as chat_exchange_cut when 2803 is chat_search and chat_exchange_cut is 2811-2821. 5th round open.
          round: 9
        - id: BR-22
          disposition: addressed
          note: The close gate's base is the true branch point, so M2's deliverable (e007f6c5, 49064ec4, cb17a0a6) appears in a reviewed range for the first time. The milestone-boundary derivation fix lives in sdlc, outside this repo's tree.
          round: 9
        - id: BR-23
          disposition: not-addressed
          note: Nothing under tests/perf or tests/arch references entity_range; atlas/chat/entity_delete.md:105-116 still states 13.6/24.7/97.8 ms alongside its own admission that no spec guards them.
          round: 9
        - id: BR-24
          disposition: not-addressed
          note: entity_delete_parity_spec.lua:80 (shape) and :86 (did_setup) are both module-scope mutables that fresh() reads; still no seam to run the it() bodies in any other order.
          round: 9
        - id: BR-25
          disposition: not-addressed
          note: keybinding_registry.lua:483/:493/:503 verbatim unchanged - "(dae/yae/cae)", "(die/yie/cie)", then "(daE)" alone.
          round: 9
        - id: BR-27
          disposition: not-addressed
          note: atlas:94-95 verbatim unchanged; re-measured, range() returns nil on a `# x` inside a fence (neither section nor content) and the Precedence table still has no row for it. entity_range.lua:10 and plan.md:66 both still say "Five rules" over six. The same passage's "a range never spans one" is now measurably false via to_end - see BR-32.
          round: 9
        - id: BR-28
          disposition: addressed
          note: 420d046a appends "### 2026-09-16 - M2 boundary review (four rounds)" to plan.md:1113-1138, recording the fence wall, the single fence predicate, the in_code threading, the parity-spec abort and the Integration-points/line-ref deltas.
          round: 9
        - id: BR-30
          disposition: not-addressed
          note: Instances remain fixed and pinned, but the class guard the finding specified was never shipped - I wrote the odd-fence invariant and it fails 10 times over four fenced fixtures, all on to_end. Separately the fix still spells "the effective heading level at row i" three ways at :102, :111 and :285, two of them behind an `in_code and` nil-guard no call site can reach (:256 and :286 both pass the always-built memo).
          round: 9
        - id: BR-31
          disposition: not-addressed
          note: The named dead assignment in entity_range_spec is fixed at 420d046a, but the sibling instances the round-8 disposition named inside the fix survive - the unreachable `in_code and` nil-guards at entity_range.lua:102/:111 against the unguarded read at :285. Instance fixed, class not swept; 5th in family.
          round: 9
        - id: BR-32
          disposition: not-addressed
          note: Reproduced on a real parse_chat - range(p, L, 11, {scope="to_end"}) returns paragraph 11..15 with the closing fence at row 13 inside the range and the opener at row 10 outside it. entity_range.lua:279-291 still assigns found.last from bounds.last with no fence check, and the single exit at :296-299 still has no post-condition. Odd-fence invariant fails 10 times across chat-backtick, chat-tilde, indented and plain-markdown fixtures, all on to_end, zero on entity.
          round: 9
        - id: BR-33
          disposition: not-addressed
          note: entity_delete_parity_spec.lua:108-110 still writes a chat file per fresh() call; run() at :135-139 deletes the buffer only.
          round: 9
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

## Round 6 — 2026-09-16T15:35:52-07:00 (claude) — BLOCKED

### Disposed

- BR-19 — addressed — README.md:17-24 now covers ae/ie/aE, dae/yae/cae, Ctrl+g k, Ctrl+g K and both :ParleyDelete* commands - all five config_keys and both M.cmd symbols reachable; the enforcing check was NOT shipped, so the family stays hand-maintained (see ARCH-PURPOSE note).
- BR-20 — not-addressed — Two of four instances fixed (:87/:938 -> 4439, starter_config added to the table, code_block_memo reuse now real); plan.md:53 still says ChatPrune init.lua:4255 (actual 4271) and ExchangeCut init.lua:4423 (actual 4439), and :852 cites init.lua:2803 as chat_exchange_cut when that line is chat_search.
- BR-21 — addressed — Verified red without the fix in a scratch worktree at f53af775 - 4 of 5 new fence cases fail. The backtick instance is fixed with genuine regression evidence; the tilde/indented sibling is raised separately.
- BR-22 — not-addressed — Window is base == head == f53af775 - both required recipes exit 0 with no output, for the third round running. A correct prev-boundary..HEAD range (0d0b3801..f53af775) would have been non-empty here, so the derivation is pinning base to HEAD, not just mis-ordering milestones. Prevalence now 4 of 6 rounds on this issue.
- BR-23 — not-addressed — No perf spec added; atlas/chat/entity_delete.md still states the numbers and then says nothing guards them. I re-measured independently (parse_chat 29.6 ms, code_block_memo 0.79 ms at 5000 lines) - same shape, still unreproducible by the suite.
- BR-24 — not-addressed — entity_delete_parity_spec.lua:78 still declares `local shape = SHAPES[1]` at module scope with each it() assigning it and fresh() reading it.
- BR-25 — not-addressed — keybinding_registry.lua:483/493/503 unchanged - "dae/yae/cae", "die/yie/cie", then "(daE)" alone.

### Raised

- **BR-26** [Important] `range-splits-a-structure` the fence wall recognizes only column-zero backticks while code_block_memo recognizes ~~~ and indented fences, so BR-21 still reproduces one fence flavor over
  2nd finding in family range-splits-a-structure. entity_range.lua:61 walls on fence.open_len (lexical.ordinary_open_len, pattern ^(`+)([^`]*)$, column zero, backticks only); entity_range.lua:230 builds in_code from code_block_memo, which uses lexical.is_fence_delim(line, true) - ^%s*(`+) plus ^%s*(~+). Two definitions of one fact, added in the same commit. Measured on real parsed transcripts - with rows 10..14 = ~~~lua / local a = 1 / blank / local b = 2 / ~~~, range(parsed, lines, 10) returns paragraph 10..12 and range(parsed, lines, 14) returns paragraph 13..15, so dae leaves a bare ~~~ and the rest of the transcript renders as code; a three-space-indented ``` opener gives the identical 10..12. Same undo-recoverable severity reasoning BR-21 carried. Do NOT add a tilde branch to is_wall. THE RULE - entity_range must consume ONE fence-delimiter predicate, and it must be the one code_block_memo uses (lexical.is_fence_delim), so a line the memo counts as a fence is necessarily a wall; that also removes the only require sitting inside a per-line loop. The parity spec structurally cannot see this axis (both surfaces share the range function and agree on the wrong answer), so the guard goes in entity_range_spec - parameterize the existing code fences block over the three delimiter shapes rather than adding a second fixture. fence.lua:9-14 records that this exact rule already had three independent implementations once (#200).
- **BR-27** [Minor] `docs-edit-mangles-prose` the fence docs describe behavior the code does not have, in both the atlas page and the module docstring
  2nd finding in family docs-edit-mangles-prose. atlas/chat/entity_delete.md:94-95 says a "# heading" inside a fenced block "is content rather than a section"; measured, range() returns nil on that row - a no-op, neither section nor content - and the Precedence table gained a row for fence lines but none for this case. entity_range.lua:10 still opens "Five rules, each stated once" over six numbered rules, and the fence rule is not enumerated among them. THE RULE the family points at - a docs edit that accompanies a behavior change must be read back against the behavior, not just inserted; both sites here were written from the intent rather than from what range() returns.
- **BR-28** [Minor] `plan-table-understates-code` the plan body was edited for the M2 review with no "## Revisions" entry recording the deltas
  4th finding in family plan-table-understates-code. plan.md:7, :82, :87, :797, :938 and the struck-through open item 3 all changed at f53af775; the plan's Revisions section still ends at "M1 boundary review round 2". AGENTS.md section 1 requires an appended Revisions entry (timestamp, reason, delta) rather than an overwrite. The issue "## Log" carries the narrative so nothing is lost, which is why this is Minor - but the plan's own history now misstates when it last moved, and BR-13 already stated the Revisions/body consistency rule for the opposite direction.

## Round 7 — 2026-09-16T16:04:38-07:00 (claude) — BLOCKED

### Disposed

- BR-20 — not-addressed — File-set half now holds (all 16 branch lua/tests paths resolve; starter_config row at plan.md:82); file:line half does not - plan.md:53 still says ChatPrune init.lua:4255 (4271) and ExchangeCut init.lua:4423 (4439), :852 cites init.lua:2803 as chat_exchange_cut (that line is chat_search), and this round created a new instance: :7 still lists fence.open_len as a reused primitive after a3fcf7ea removed its only call.
- BR-22 — not-addressed — Empty-range half no longer reproduces (f53af775..8c2e3150 is 6 files), but base is still the previous round's tip, so M2's actual deliverable (e007f6c5, 49064ec4, cb17a0a6) remains outside every M2 window - the parity-spec defect I raise this round lives in cb17a0a6 and has therefore never been in a reviewed range. Prevalence 4 of 7 rounds.
- BR-23 — not-addressed — No perf spec; atlas:105-116 still carries 13.6/24.7/97.8 ms plus its own admission that nothing guards them. The plan now records the drop as an explicit operator call (Task 13, "Perf module: dropped, measured instead"), so it is a documented residual rather than an oversight - but the declaration is neither guarded nor deleted.
- BR-24 — not-addressed — entity_delete_parity_spec.lua:78 still declares `local shape = SHAPES[1]` at module scope with fresh() reading it; newly relevant because that spec now aborts nondeterministically and module-scope shared state is what makes such an abort hard to localize.
- BR-25 — not-addressed — keybinding_registry.lua:483/493/503 unchanged - "dae/yae/cae", "die/yie/cie", then "(daE)" alone.
- BR-26 — addressed — entity_range.lua:65 now calls lexical.is_fence_delim(line, true), the same predicate and tildes flag code_block_memo uses at :234-235; scratch-reverting that one line turns entity_range_spec red (43 pass / 1 fail), so the regression evidence is real. Residual: the require still sits inside the per-line is_wall loop, which the rule asked to remove.
- BR-27 — not-addressed — atlas:94-95 unchanged - still says a "# heading" inside a fence "is content rather than a section" where range() returns nil; entity_range.lua:10 still opens "Five rules, each stated once" over six rules and still omits the fence rule. The added paragraph at atlas:100-104 is accurate but sits above the two sentences the finding named.
- BR-28 — not-addressed — This window edits plan.md:978-981 and the Revisions section still ends at "M1 boundary review round 2"; no entry for the f53af775 edits either.

### Raised

- **BR-29** [Critical] `checkbox-without-artifact` the parity spec - the milestone's named best guard - exits 1 without completing, while the plan ticks it as passing
  2nd finding in family checkbox-without-artifact. tests/integration/entity_delete_parity_spec.lua exits 1 with an EMPTY stderr and no busted summary, aborting after a nondeterministic subset of its 11 tests. Measured 6 of 6 runs - `make test-spec SPEC=chat/entity_delete` stopped after 1, 3 and 6 tests (the third with a fresh TEST_ENV_ROOT), a make-equivalent raw invocation stopped after 6 twice, and a variant limited to `for row = 1, 4` stopped after 4. No crash report in ~/Library/Logs/DiagnosticReports. So the last two SHAPES - including `separator-edited-away`, added by the M1 round-2 rework as "the axis BR-2 actually lived on" - and the `never reaches into a header` test have never executed. RUN_SPEC keys on exit status, so `make test-integration` on this branch lists the file under "Failed integration test files"; plan.md Task 13 Step 2 ("Run it and watch it pass") and Task 15 Step 1 (`make test`) are both ticked. Calibration - this environment has pre-existing failures (async_builtin_spec and parley_harness_golden_spec fail on main too, neither is this branch's), but entity_range_spec and entity_textobj_spec pass cleanly here with proper summaries. THE RULE - a boundary may not record "watched it pass" for a spec file whose runner exits non-zero; the exit status is the evidence, not the Success lines that precede the abort. Likely cause to start from: run() at :120-125 calls fresh() twice per row and never wipes the buffer, so one process accumulates ~660 buffers, ~660 files and ~660 parley.setup() calls with no teardown. Also note base_tmp_dir at :16 hardcodes a "/claude/" path segment - an agent-sandbox artifact that should not be in a committed spec.
- **BR-30** [Important] `range-splits-a-structure` section_range and the to_end backward scan read heading.level with no in-code filter, so a section range ends ON the opening fence
  3rd finding in family range-splits-a-structure. Do NOT patch section_range alone. THE RULE - entity_range.range must classify each row ONCE per call and every walk must consume that one classification - blank / heading / fence / marker / text, with in_code[row] demoting a heading to text - so that is_wall, section_range's forward scan and the to_end backward scan cannot disagree. The enumeration the rule implies, all in lua/parley/entity_range.lua - :58 (heading.level in is_wall), :65 (fence in is_wall), :99 and :108 (heading.level in section_range), :282 (heading.level in the to_end backward scan). Only :253 consults in_code, and only for the cursor row. BR-21 was :58/:65 missing the fence; BR-26 was :65 using a different fence predicate from :234; this is :108 and :282 using a different heading predicate from :253. Measured with real chat_parser.parse_chat - chat buffer `## Section / prose / ```lua / # inner heading / code / ``` / tail` gives range(parsed, lines, 8) -> section 8..10 where row 10 is the ```lua opener, and {inner=true} gives 9..10; plain markdown `# Top / alpha / "" / ```lua / # fake / code / ``` / omega` gives range(nil, lines, 1) -> section 1..4, again ending on the opener. dae there leaves a bare closing fence and the rest of the transcript renders as code - the same corruption and the same undo-recoverable severity BR-21 carried. Separately the to_end backward scan at :282 latches onto an in-fence heading and returned 8..9 where the correct answer was 8..#lines. This contradicts atlas/chat/entity_delete.md:94, which states "A fence line is never deleted, a range never spans one". GUARD at the rule's level, not per flavour - extend the existing `entity_range invariants` property test over a fenced fixture and assert that no returned range contains an ODD number of is_fence_delim lines, for every row x {scope, inner}; that one invariant catches BR-21, BR-26 and this at once. The parity spec structurally cannot see any of them - both surfaces share the range function and agree on the wrong answer.
- **BR-31** [Minor] `unreachable-guard` dead assignment in the new fence-flavour test - body[10] is computed and then immediately overwritten
  3rd finding in family unreachable-guard. tests/unit/entity_range_spec.lua:486 initializes body[10] to `delim:gsub("%S+$", ""):gsub("^%s*", "") ~= "" and "```" or delim`, which :488 discards. THE RULE covering BR-5 (section_range's dead floor parameter), BR-16 (a ternary whose two branches are both 2) and this - no line in the diff may have zero consumers; a value that nothing reads is either a missing call site or dead code, and review should resolve which before the boundary. Here it is dead code: delete the computed initializer and build body[10] once.

## Round 8 — 2026-09-16T16:35:13-07:00 (claude) — passed

### Disposed

- BR-20 — not-addressed — File-set half holds. Three file:line instances still live - plan.md:7 lists fence.open_len as a reused primitive though a3fcf7ea removed its only call (entity_range requires parley.fence nowhere); plan.md:53 says ChatPrune init.lua:4255 (actual 4271) and ExchangeCut init.lua:4423 (actual 4439); plan.md:852 cites init.lua:2803-2812 as chat_exchange_cut when 2803 is chat_search and chat_exchange_cut is 2811. 4th round open, no mechanical check shipped.
- BR-22 — not-addressed — Empty-window symptom is gone (f53af775..4eca1d7d is 8 files), but base is the previous ROUND's base, not the parent of M2's own first commit - so M2's actual deliverable (e007f6c5, 49064ec4, cb17a0a6) has still never appeared in any reviewed range. Prevalence 5 of 8 rounds. Fix belongs in the sdlc derivation, not here.
- BR-23 — not-addressed — tests/perf holds chat_typing/document/harness/ownership; nothing under tests/perf or tests/arch references entity_range. atlas/chat/entity_delete.md:105-116 still states 13.6/24.7/97.8 ms alongside its own admission that no spec guards them.
- BR-24 — not-addressed — entity_delete_parity_spec.lua:78 still declares `local shape = SHAPES[1]` at module scope with each it() assigning it and fresh() reading it - and this round ADDED a second module-level mutable, `did_setup` at :86, also read by fresh(). Correct only because busted runs the bodies sequentially; there is still no seam to run them in any other order.
- BR-25 — not-addressed — keybinding_registry.lua:483/493/503 unchanged - "(dae/yae/cae)", "(die/yie/cie)", then "(daE)" alone.
- BR-27 — not-addressed — atlas/chat/entity_delete.md:94-95 is verbatim unchanged; re-measured, range() returns nil on a `# x` inside a fence (neither section nor content) and the Precedence table still has no row for it. entity_range.lua:10 still opens "Five rules, each stated once" over six, and plan.md:66 carries the identical "Five rules" claim over a set that now includes the header floor and the fence wall - the same drift in a third document.
- BR-28 — not-addressed — plan.md moved again in this window (:978-981, the perf-module strikethrough at 4eca1d7d) and the Revisions section still ends at "M1 boundary review round 2". Four body deltas since f53af775 are now unrecorded.
- BR-29 — addressed — Measured 4 consecutive `make test-spec SPEC=chat/entity_delete` runs - exit 0 every time, parity 11/11 with a real busted summary, all five SHAPES including separator-edited-away plus the header test executed, full mapped set 45/15/11/1/4 green. Withdrawing the sub-claim about base_tmp_dir's "/claude/" segment - it is an established repo convention in 34 test files, under the harness TMPDIR that test-clean-env wipes, not an agent-sandbox artifact.
- BR-30 — not-addressed — Instances fixed and genuinely pinned - scratch-revert at 4eca1d7d reds the new spec 44/1, and all three measured cases now return the correct range (section 8..14, 1..8, to_end 2..8). The CLASS was not swept - the odd-fence invariant the finding specified was not shipped, and running it now fails 8 times (see the new to_end finding); :58's heading read is still ungated (a `# x` in a fence is a no-op that splits a code sample into two paragraphs, benign but the fourth spelling of the same classification); and the fix itself writes "the effective heading level at row i" three different ways at :102, :111 and :285.
- BR-31 — not-addressed — entity_range_spec.lua:490 still computes a body[10] initializer that :492 immediately discards. Plus a new instance of the same rule inside the fix under review - section_range's `in_code and` nil-guards at :102 and :111 have zero reachable call sites (both callers, :256 and :286, pass the always-built memo), while :285 reads in_code[i] with no guard at all. A guard and its absence over one fact, three lines apart. 4th in family.

### Raised

- **BR-32** [Important] `range-splits-a-structure` the to_end scope overwrites found.last from the exchange bound without re-applying the fence wall, so daE inside a code block strands the opening fence
  4th finding in family range-splits-a-structure. entity_range.lua:279-291 assigns found.last = bounds.last (or the enclosing section's end) with no fence check, bypassing is_wall entirely. Measured on a real parse_chat with two exchanges and a fence at rows 10-13 - range(p, L, 11, {scope="to_end"}) returns paragraph 11..15, and deleting it leaves ```lua at row 10 with no closer, so the second question and everything after it render as code. BR-21's exact corruption, undo-recoverable, hence Important rather than Critical - the same calibration BR-21 and BR-26 were given. Found by writing the guard BR-30 specified - over four fenced fixtures (chat backtick, chat tilde, indented, plain markdown) x every row x {entity,to_end} x {inner,outer}, the even-fence invariant fails 8 times, all on to_end, zero on entity. DO NOT patch to_end. The four instances broke four different producers (no fence test, wrong fence predicate, wrong heading predicate, and now bypassing the wall outright), so guarding producers one at a time is what keeps failing. THE RULE - guard the RESULT in one place - M.range has exactly one exit at :296-299; give it one post-condition, that the returned [first,last] may not contain an unmatched lexical.is_fence_delim line, and clamp or refuse there. That subsumes BR-21, BR-26, BR-30 and this. First resolve the contract conflict it exposes - atlas/chat/entity_delete.md:94 says "a range never spans one" (reaffirmed in this window at :99-104) while issue :189 says the extended range runs "through the end of the current exchange". Pick one; if to_end is an intentional exception it must be a named carve-out in both the atlas and the invariant, not an absent test.
- **BR-33** [Minor] `artifact-without-removal-path` the parity spec writes one chat file per iteration with no removal path - run() now releases the buffer but not the file
  ARCH-FUNERAL. entity_delete_parity_spec.lua:98-131 - fresh() writes a chat file into base_tmp_dir on every call and nothing deletes it; the teardown added this round frees the buffer only. make test-spec runs PREP_TEST_ENV but never test-clean-env, so the residue is collected only by a later full make test. Measured after a handful of runs - 2 902 files / 11 MB across 12 per-run directories under the harness scratch root. One vim.fn.delete(path) in run() bounds it.

## Round 9 — 2026-09-16T17:04:38-07:00 (claude) — BLOCKED

### Disposed

- BR-5 — addressed — section_range is now (lines, row, bounds, in_code) - the floor parameter is gone, and :106-107 documents why a second floor test could not change the outcome.
- BR-8 — addressed — README.md:16-25 now names ae, ie, aE, dae/yae/cae, Ctrl+g k, Ctrl+g K and both :ParleyDelete* commands.
- BR-13 — not-addressed — Line refs corrected to 4439, but plan.md:87 and :938 still say DeleteEntity is "ExchangeCut's preamble (verbatim)"; init.lua:4529-4540 uses entity_textobj.parsed_for, not ExchangeCut's not_chat preamble.
- BR-14 — addressed — This gate's base 85e116c2 is merge-base(main,HEAD); stat and name-status both return 31 files, so the window is real.
- BR-15 — addressed — Front-matter branch at chat_parser.lua:108-115 plus a conformance test rendering both defaults templates through the real renderer and new_chat's underscore escape; scratch-reverting the branch reds entity_range_spec 43/2 on "chat_template must yield a header terminator". Negative side (# Recipe: soup) asserted too.
- BR-16 — addressed — No occurrence of "and 2 or 2" remains anywhere under lua/ or tests/.
- BR-17 — addressed — entity_delete_parity_spec.lua:186-195 - the no-header branch now asserts that the two surfaces agree on rows 1-3, a property of the code rather than of the SHAPES literal.
- BR-18 — addressed — "In a plain markdown buffer there is no exchange kind..." stands as its own paragraph again, and the header table row now points at the "What counts as a header" paragraph, which states the contiguous-run qualifier in full.
- BR-20 — not-addressed — File-set half holds (all 16 changed lua/ and tests/ paths appear in the plan). File:line half does not - plan.md:7 still lists fence.open_len though entity_range requires parley.fence nowhere; :53 says ChatPrune 4255 (actual 4271) and ExchangeCut 4423 (actual 4439); :852 cites init.lua:2803-2812 as chat_exchange_cut when 2803 is chat_search and chat_exchange_cut is 2811-2821. 5th round open.
- BR-22 — addressed — The close gate's base is the true branch point, so M2's deliverable (e007f6c5, 49064ec4, cb17a0a6) appears in a reviewed range for the first time. The milestone-boundary derivation fix lives in sdlc, outside this repo's tree.
- BR-23 — not-addressed — Nothing under tests/perf or tests/arch references entity_range; atlas/chat/entity_delete.md:105-116 still states 13.6/24.7/97.8 ms alongside its own admission that no spec guards them.
- BR-24 — not-addressed — entity_delete_parity_spec.lua:80 (shape) and :86 (did_setup) are both module-scope mutables that fresh() reads; still no seam to run the it() bodies in any other order.
- BR-25 — not-addressed — keybinding_registry.lua:483/:493/:503 verbatim unchanged - "(dae/yae/cae)", "(die/yie/cie)", then "(daE)" alone.
- BR-27 — not-addressed — atlas:94-95 verbatim unchanged; re-measured, range() returns nil on a `# x` inside a fence (neither section nor content) and the Precedence table still has no row for it. entity_range.lua:10 and plan.md:66 both still say "Five rules" over six. The same passage's "a range never spans one" is now measurably false via to_end - see BR-32.
- BR-28 — addressed — 420d046a appends "### 2026-09-16 - M2 boundary review (four rounds)" to plan.md:1113-1138, recording the fence wall, the single fence predicate, the in_code threading, the parity-spec abort and the Integration-points/line-ref deltas.
- BR-30 — not-addressed — Instances remain fixed and pinned, but the class guard the finding specified was never shipped - I wrote the odd-fence invariant and it fails 10 times over four fenced fixtures, all on to_end. Separately the fix still spells "the effective heading level at row i" three ways at :102, :111 and :285, two of them behind an `in_code and` nil-guard no call site can reach (:256 and :286 both pass the always-built memo).
- BR-31 — not-addressed — The named dead assignment in entity_range_spec is fixed at 420d046a, but the sibling instances the round-8 disposition named inside the fix survive - the unreachable `in_code and` nil-guards at entity_range.lua:102/:111 against the unguarded read at :285. Instance fixed, class not swept; 5th in family.
- BR-32 — not-addressed — Reproduced on a real parse_chat - range(p, L, 11, {scope="to_end"}) returns paragraph 11..15 with the closing fence at row 13 inside the range and the opener at row 10 outside it. entity_range.lua:279-291 still assigns found.last from bounds.last with no fence check, and the single exit at :296-299 still has no post-condition. Odd-fence invariant fails 10 times across chat-backtick, chat-tilde, indented and plain-markdown fixtures, all on to_end, zero on entity.
- BR-33 — not-addressed — entity_delete_parity_spec.lua:108-110 still writes a chat file per fresh() call; run() at :135-139 deletes the buffer only.

## Open findings

- **BR-13** [Minor] `plan-table-understates-code` REPEAT (2nd) - plan body still describes the implementation BR-2 removed
- **BR-20** [Important] `plan-table-understates-code` plan body claims a reuse and a file set the tree does not have - three live instances
- **BR-23** [Minor] `unreproducible-measurement` the ARCH-CONSTRAINTS numbers exist only as atlas prose, with no spec guarding them
- **BR-24** [Minor] `shared-mutable-test-fixture` the parity spec mutates a module-level `shape` upvalue that fresh() reads
- **BR-25** [Minor] `inconsistent-error-handling` help_desc strings for the entity family list operators inconsistently
- **BR-27** [Minor] `docs-edit-mangles-prose` the fence docs describe behavior the code does not have, in both the atlas page and the module docstring
- **BR-30** [Important] `range-splits-a-structure` section_range and the to_end backward scan read heading.level with no in-code filter, so a section range ends ON the opening fence
- **BR-31** [Minor] `unreachable-guard` dead assignment in the new fence-flavour test - body[10] is computed and then immediately overwritten
- **BR-32** [Important] `range-splits-a-structure` the to_end scope overwrites found.last from the exchange bound without re-applying the fence wall, so daE inside a code block strands the opening fence
- **BR-33** [Minor] `artifact-without-removal-path` the parity spec writes one chat file per iteration with no removal path - run() now releases the buffer but not the file
