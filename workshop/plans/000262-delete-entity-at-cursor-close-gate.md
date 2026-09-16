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

## Open findings

- **BR-2** [Critical] `guard-gated-on-classification` the command path's unparsable-header refusal is unreachable when not_chat fails, so the two surfaces diverge
- **BR-4** [Important] `parity-varies-only-cursor` the parity spec varies only the cursor row, never the document shape, so classification divergence is invisible to it
- **BR-5** [Minor] `unreachable-guard` section_range's floor parameter is dead code
- **BR-8** [Minor] `readme-omits-new-surface` README documents dae/daE/yae/cae but not ie, <C-g>k or <C-g>K
- **BR-10** [Important] `partial-shape-test` transcript_header_end validates only line 1, then delegates to an unbounded find_header_end scan
- **BR-11** [Important] `partial-shape-test` the unit test for that property uses a non-topic-shaped title, so it never reaches the scan
- **BR-12** [Important] `parity-varies-only-cursor` REPEAT (2nd) - the parity spec still cannot see the axis BR-2 lived on; state the rule, not the instance
- **BR-13** [Minor] `plan-table-understates-code` REPEAT (2nd) - plan body still describes the implementation BR-2 removed
- **BR-14** [Minor] `empty-review-window` the gate pinned base == head, so the machine-read review window contained zero changes
