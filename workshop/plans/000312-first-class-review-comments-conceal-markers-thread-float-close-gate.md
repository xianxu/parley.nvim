---
gate: boundary-review
issue: 312
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-10-09T21:09:56-07:00"
      agent: sdlc
      findings:
        - id: BR-1
          severity: Minor
          title: Tasks 8 and 10 enumerate test cases in prose and Tasks 1-3 carry full test code; compress to one strategy line per risky function
          detail: |-
            e.g. view.layout -> property-test range bounds/non-overlap/UTF-8 boundaries over generated lines seeded with truncated/nested markers; thread.from_lines -> round-trip property over generated single-line markers.
            (carried from plan-quality PQ-8, deferred to the boundary review)
          family: test-prose-enumeration
          round: 1
        - id: BR-2
          severity: Minor
          title: Issue M1 row still says concealcursor=nc, and Spec/Done-when say "diagnostic" where the plan paints ParleyReviewBroken
          detail: |-
            2nd finding in this family. Rule: a revision that changes a decision must sweep every restatement in the issue (Spec, Done-when, Plan rows, Log) in the same edit; the Revisions entry triggers that sweep and does not replace it. Prevalence so far: 2 of 2 rounds.
            (carried from plan-quality PQ-9, deferred to the boundary review)
          family: done-when-contract-drift
          round: 1
      boundary: '*'
      no_cap: true
      blocked: false
    - "n": 2
      timestamp: "2026-10-09T21:09:56-07:00"
      agent: claude
      findings:
        - id: BR-3
          severity: Important
          title: attach's conceallevel=2 + concealcursor=nvic applies to every .md buffer and all conceals, not just markers
          detail: Markdown buffers newly get treesitter conceals (link URLs, emphasis, code spans) and chat header-param matchadds kept hidden on the cursor line in insert mode, where the marker-only snap does not protect them; undocumented in atlas. Scope it or document and test the accepted behavior.
          family: conceal-scope-widening
          round: 2
        - id: BR-4
          severity: Minor
          title: view.snap moving left lands on a UTF-8 continuation byte when the preceding visible char is multibyte
          detail: "For `a \U0001F916<é>[c] z` the left snap returns col 8 (str_utf_start -1); nvim adjusts but prev_col records the wrong col. Snap to the char start and add multibyte cases to the snap tests."
          family: snap-char-boundary
          round: 2
        - id: BR-5
          severity: Minor
          title: In insert mode the insertion point right before a quoted marker is snapped into the anchor
          detail: Text typed "before" a quoted marker becomes part of `<X>`; visible, but undocumented.
          family: insert-edge-semantics
          round: 2
        - id: BR-6
          severity: Minor
          title: Test "returns nil when no visible byte exists" asserts a non-nil snap
          family: test-name-drift
          round: 2
        - id: BR-7
          severity: Minor
          title: ParleyReviewUser/ParleyReviewAgent highlight groups have no renderer consumer after the marker loop was replaced
          family: orphaned-definitions
          round: 2
        - id: BR-8
          severity: Minor
          title: ParleyReviewStrike comment says it gets the quoted highlight, but the code only adds reverse=true
          family: comment-drift
          round: 2
      boundary: M1
      recipe: milestone-review
      blocked: true
    - "n": 3
      timestamp: "2026-10-09T21:14:37-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: not-addressed
          note: Plan Tasks 1-3 still carry full test code and Tasks 8/10 prose enumerations; Minor, non-blocking.
          round: 3
        - id: BR-2
          disposition: addressed
          note: Spec and Done-when now say raw + ParleyReviewBroken; the BR-3 scoping drift is raised separately.
          round: 3
        - id: BR-3
          disposition: addressed
          note: sync_concealcursor scopes nvic to marker lines; comment_attach_spec asserts the user's value elsewhere and fails against window-wide nvic.
          round: 3
        - id: BR-4
          disposition: addressed
          note: snap backs up via vim.str_utf_start; the multibyte leftward unit test pins it.
          round: 3
        - id: BR-5
          disposition: addressed
          note: "Insert-mode blocked_spans allow m.start; test \"before the \U0001F916 is outside the marker\"."
          round: 3
        - id: BR-6
          disposition: addressed
          note: Test renamed to "a line that starts with a quoted marker rests on its anchor" and asserts the anchor col.
          round: 3
        - id: BR-7
          disposition: withdrawn
          note: Plan Task 4 deliberately keeps the groups for the M2 float colors; stale references raised under comment-drift.
          round: 3
        - id: BR-8
          disposition: addressed
          note: Comment now says reversed like a quoted anchor, matching reverse=true.
          round: 3
      findings:
        - id: BR-9
          severity: Minor
          title: sync_concealcursor reads the window's base once and overwrites later user or prep_chat values
          detail: '2nd in family. Rule: parley writes concealcursor only on entering/leaving nvic and re-reads the base whenever the current value isn''t one parley set. comment/init.lua:20; prep_chat''s "" is lost after a markdown buffer records "nc".'
          family: conceal-scope-widening
          round: 3
        - id: BR-10
          severity: Minor
          title: highlighter.lua:365, :691-697 and atlas/modes/review.md:257 still describe ParleyReviewUser/Agent painting marker sections
          detail: '2nd in family. Rule: when a diff changes what a highlight group paints, grep the group name across lua/ and atlas/ and update every mention in the same edit.'
          family: comment-drift
          round: 3
        - id: BR-11
          severity: Minor
          title: Concealed spans collapse two insert positions onto one screen column
          detail: "2nd in family. Before-\U0001F916 and anchor-start (and anchor-end and after-marker) look identical; one Right press seems to do nothing and where text goes is ambiguous. Rule: where concealment merges insert positions, pick one deliberately and document it."
          family: insert-edge-semantics
          round: 3
        - id: BR-12
          severity: Minor
          title: Issue Spec/M1 row say concealcursor=nvic unqualified; BR-3 scoping revision recorded only in the plan
          detail: '2nd in family. Rule: every plan Revisions entry that changes a decision also updates the issue''s Spec/Done-when/Plan rows and adds an issue Revisions entry in the same commit.'
          family: done-when-contract-drift
          round: 3
      boundary: M1
      recipe: milestone-review
      blocked: false
    - "n": 4
      timestamp: "2026-10-09T21:37:52-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: not-addressed
          note: Plan unchanged in this window; Tasks 8/10 still enumerate test cases in prose.
          round: 4
      findings:
        - id: BR-13
          severity: Critical
          title: Thread float second :w is always refused; extmark drifts after replace_user_lines rewrites the row
          detail: 'float.lua write_back replaces the whole row, moving the extmark off m.start, so the next write-back compares the wrong bytes and fails with "marker changed underneath" (reproduced: write r1, edit, write again leaves r1). Rule: a position tracked across a self-applied edit must be re-anchored after the edit (set_extmark with id) or the edit narrowed to the tracked span. Add multi-write and :w-then-q tests.'
          family: edit-tracking-extmark
          round: 4
        - id: BR-14
          severity: Important
          title: The log M2 commit spliced the M2 Log bullets into the Spec "Grammar change" sentence
          detail: 'The insert matched the first "## Revisions" substring inside Spec prose instead of the Log heading; Spec is corrupted, Log lacks M2 entries, and the first bullet is truncated. Rule: append by matching the section heading line, never a substring.'
          family: artifact-append-anchor
          round: 4
        - id: BR-15
          severity: Important
          title: Plan/Spec still describe WinClosed auto-write and anchor decode; code does neither, and there is no M2 Revisions entry
          detail: '3rd finding in this family. Rule: every change from a plan''s Integration-point or Task text lands as a Revisions entry in the same commit that makes the change. Sweep: (a) WinClosed write-back and close-writes in Spec/Done-when vs register-on-close, (b) Task 10 anchor decode vs turn-only, (c) codec future-extension <br\> vs shipped \<br>.'
          family: done-when-contract-drift
          round: 4
        - id: BR-16
          severity: Important
          title: Accept now decodes a literal <br> in legacy or old-grammar turn text into a newline before ariadne#316 lands
          detail: 'Agents following the currently deployed review-convention write a literal <br> in table-row proposals; M-a now inserts a newline and breaks the table without warning. Block the #312 merge on ariadne#316 landing and the re-weave, and record that dependency.'
          family: cross-version-input-decode
          round: 4
        - id: BR-17
          severity: Minor
          title: codec escape is not total; a backslash before a newline decodes to a literal <br>
          family: escape-totality
          round: 4
        - id: BR-18
          severity: Minor
          title: comment/init re-implements native_map gating; the arch guard was widened to allow a second install path
          family: keymap-install-single-path
          round: 4
      boundary: M2
      recipe: milestone-review
      blocked: true
    - "n": 5
      timestamp: "2026-10-09T21:41:58-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: withdrawn
          note: Overtaken by implementation; the risky functions shipped with the property test the finding asked for.
          round: 5
        - id: BR-13
          disposition: addressed
          note: float.lua:44-46 re-anchors; comment_float_spec "a second :w" uses a col>0 prefix, so it fails without the fix.
          round: 5
        - id: BR-14
          disposition: addressed
          note: Spec Grammar-change sentence is clean; Log carries the M2 bullets under its own heading.
          round: 5
        - id: BR-15
          disposition: addressed
          note: Plan Revisions "M2 as built" covers WinClosed, Task 10 anchor decode, and the codec escape; issue Spec and Done-when synced.
          round: 5
        - id: BR-16
          disposition: not-addressed
          note: 'Recorded as an accepted edge in Spec, but deps is still [] and nothing ties the #312 merge to ariadne#316 plus the re-weave.'
          round: 5
        - id: BR-17
          disposition: not-addressed
          note: 'Still true: decode(encode("a\\\nb")) == "a<br>b" (verified headless).'
          round: 5
        - id: BR-18
          disposition: not-addressed
          note: comment/init.lua:72-73 still re-implements the default_keymaps gating; single_source_sweeps_spec still widened.
          round: 5
      findings:
        - id: BR-19
          severity: Critical
          title: Float on a fresh marker (empty []) writes back a doubled human turn
          detail: "thread.to_lines always appends [] and from_lines drops only trailing empty turns, so \U0001F916<X>[] (the <M-q> output) plus a reply becomes \U0001F916<X>[][reply], and a no-edit :w deletes the []. Rule: a thread has exactly one empty reply slot. Add an integration test that runs <M-q>, then <CR>, a reply, and :w."
          family: reply-slot-normalization
          round: 5
        - id: BR-20
          severity: Important
          title: atlas/chat/drill_in.md still documents multi-line quotes and multi-line compose; M2 made chat <M-q> single-line
          detail: '3rd finding in comment-drift. Rule: a behavior change updates every prose description of it, including every caller''s atlas page, in the same commit. Document the chat change and point multi-line questions to the float.'
          family: comment-drift
          round: 5
        - id: BR-21
          severity: Minor
          title: thread.to_lines returns roles that the float ignores; paint_roles re-derives roles with a different rule
          family: orphaned-definitions
          round: 5
      boundary: M2
      recipe: milestone-review
      blocked: true
    - "n": 6
      timestamp: "2026-10-09T21:45:10-07:00"
      agent: claude
      dispose:
        - id: BR-16
          disposition: addressed
          note: 'Issue frontmatter now carries deps: [ariadne#316] (4e5e86c0); Spec records merge pending and the weave dependency.'
          round: 6
        - id: BR-17
          disposition: not-addressed
          note: codec.lua unchanged on this axis; encode("a\\\nb") yields "a\\<br>b", which decodes to "a<br>b". Backslash is still not escaped.
          round: 6
        - id: BR-18
          disposition: not-addressed
          note: comment/init.lua:72-73 still re-derives default_keymaps gating; the arch guard still accepts a second install path.
          round: 6
        - id: BR-19
          disposition: addressed
          note: thread.to_lines treats an existing trailing empty [] as the reply slot (appended=false), and from_lines keeps it. Unit test plus integration test "a fresh <M-q> marker's empty [] is the reply slot"; both fail without the fix.
          round: 6
        - id: BR-20
          disposition: addressed
          note: atlas/chat/drill_in.md Lifecycle steps 1-2 and line 96 now describe single-line quotes, the float for multi-line, and decode at gather time; no other atlas page claims multi-line compose.
          round: 6
        - id: BR-21
          disposition: not-addressed
          note: float.lua:96 still discards to_lines' roles; paint_roles (float.lua:65-75) re-derives them by first-char rule.
          round: 6
      findings:
        - id: BR-22
          severity: Minor
          title: :q! with edits overwrites the unnamed register and warns "closed without :w"
          detail: The WinClosed handler (float.lua:142-151) cannot tell a deliberate :q! from an accidental close, so a discard clobbers " and shows a misleading warning, although the Spec says ":q! discards". Fix with a QuitPre/cmdline bang flag, or document the stash.
          family: discard-path-side-effects
          round: 6
      boundary: M2
      recipe: milestone-review
      blocked: false
    - "n": 7
      timestamp: "2026-10-10T11:23:56-07:00"
      agent: claude
      dispose:
        - id: BR-9
          disposition: addressed
          note: sync_concealcursor re-reads the base each time it starts forcing and writes only when entering or leaving nvic; comment_attach_spec "keeps a later change to the window's own value" pins it.
          round: 7
        - id: BR-10
          disposition: addressed
          note: 'Overtaken by the smoke-test redesign: turns_hl paints turn ranges with ParleyReviewUser/Agent again (highlighter.lua:86-88), so the comments at :372 and :698 and atlas review.md:62 are accurate.'
          round: 7
        - id: BR-11
          disposition: not-addressed
          note: "Partially narrowed by the visible reply, but before-\U0001F916 and anchor-start are still two allowed insert points on one screen column (view.lua:117-118), and the choice is not documented."
          round: 7
        - id: BR-12
          disposition: addressed
          note: Issue Spec line 55 and the M1 row (line 123) now say nvic on marker lines; the issue Revisions carries the BR-3 entry.
          round: 7
        - id: BR-17
          disposition: not-addressed
          note: codec.lua is unchanged since M2; a backslash before a newline still decodes to a literal <br>.
          round: 7
        - id: BR-18
          disposition: not-addressed
          note: comment/init.lua:75-77 still re-derives the default_keymaps gating instead of using native_map.
          round: 7
        - id: BR-21
          disposition: addressed
          note: 'paint_roles now iterates thread.roles (float.lua:69), the same function to_lines returns; unit test "roles: continuation lines inherit, prefixes switch".'
          round: 7
        - id: BR-22
          disposition: not-addressed
          note: The WinClosed handler (float.lua:144-154) is unchanged; :q! with edits still overwrites the unnamed register and shows the warning.
          round: 7
      findings:
        - id: BR-23
          severity: Minor
          title: The float's line grammar is not injective; :w silently splits or truncates turns containing its delimiters
          detail: "2nd finding in escape-totality (BR-17 is the codec instance). Verified headless: \U0001F916[a<br>\U0001F4AC: b] becomes \U0001F916[a][b]; {a<br>\U0001F916: z} becomes {a}{z}; [a<br>] becomes [a]. Rule: every layout the codec or float encodes into must be injective, and the round-trip property test must generate turn text from the grammar's own delimiters (<br>, backslash, ]/}, line-start \U0001F4AC:/\U0001F916:, trailing <br>). Fix it by escaping prefix-led continuation lines and backslashes, then extend the generator's word list at comment_thread_spec.lua:54."
          family: escape-totality
          round: 7
      recipe: milestone-review
      blocked: false
---

# Gate ledger — parley.nvim#312 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-09T21:09:56-07:00 (sdlc) — passed

### Raised

- **BR-1** [Minor] `test-prose-enumeration` Tasks 8 and 10 enumerate test cases in prose and Tasks 1-3 carry full test code; compress to one strategy line per risky function
  e.g. view.layout -> property-test range bounds/non-overlap/UTF-8 boundaries over generated lines seeded with truncated/nested markers; thread.from_lines -> round-trip property over generated single-line markers.
  (carried from plan-quality PQ-8, deferred to the boundary review)
- **BR-2** [Minor] `done-when-contract-drift` Issue M1 row still says concealcursor=nc, and Spec/Done-when say "diagnostic" where the plan paints ParleyReviewBroken
  2nd finding in this family. Rule: a revision that changes a decision must sweep every restatement in the issue (Spec, Done-when, Plan rows, Log) in the same edit; the Revisions entry triggers that sweep and does not replace it. Prevalence so far: 2 of 2 rounds.
  (carried from plan-quality PQ-9, deferred to the boundary review)

## Round 2 — 2026-10-09T21:09:56-07:00 (claude) — BLOCKED

### Raised

- **BR-3** [Important] `conceal-scope-widening` attach's conceallevel=2 + concealcursor=nvic applies to every .md buffer and all conceals, not just markers
  Markdown buffers newly get treesitter conceals (link URLs, emphasis, code spans) and chat header-param matchadds kept hidden on the cursor line in insert mode, where the marker-only snap does not protect them; undocumented in atlas. Scope it or document and test the accepted behavior.
- **BR-4** [Minor] `snap-char-boundary` view.snap moving left lands on a UTF-8 continuation byte when the preceding visible char is multibyte
  For `a 🤖<é>[c] z` the left snap returns col 8 (str_utf_start -1); nvim adjusts but prev_col records the wrong col. Snap to the char start and add multibyte cases to the snap tests.
- **BR-5** [Minor] `insert-edge-semantics` In insert mode the insertion point right before a quoted marker is snapped into the anchor
  Text typed "before" a quoted marker becomes part of `<X>`; visible, but undocumented.
- **BR-6** [Minor] `test-name-drift` Test "returns nil when no visible byte exists" asserts a non-nil snap
- **BR-7** [Minor] `orphaned-definitions` ParleyReviewUser/ParleyReviewAgent highlight groups have no renderer consumer after the marker loop was replaced
- **BR-8** [Minor] `comment-drift` ParleyReviewStrike comment says it gets the quoted highlight, but the code only adds reverse=true

## Round 3 — 2026-10-09T21:14:37-07:00 (claude) — passed

### Disposed

- BR-1 — not-addressed — Plan Tasks 1-3 still carry full test code and Tasks 8/10 prose enumerations; Minor, non-blocking.
- BR-2 — addressed — Spec and Done-when now say raw + ParleyReviewBroken; the BR-3 scoping drift is raised separately.
- BR-3 — addressed — sync_concealcursor scopes nvic to marker lines; comment_attach_spec asserts the user's value elsewhere and fails against window-wide nvic.
- BR-4 — addressed — snap backs up via vim.str_utf_start; the multibyte leftward unit test pins it.
- BR-5 — addressed — Insert-mode blocked_spans allow m.start; test "before the 🤖 is outside the marker".
- BR-6 — addressed — Test renamed to "a line that starts with a quoted marker rests on its anchor" and asserts the anchor col.
- BR-7 — withdrawn — Plan Task 4 deliberately keeps the groups for the M2 float colors; stale references raised under comment-drift.
- BR-8 — addressed — Comment now says reversed like a quoted anchor, matching reverse=true.

### Raised

- **BR-9** [Minor] `conceal-scope-widening` sync_concealcursor reads the window's base once and overwrites later user or prep_chat values
  2nd in family. Rule: parley writes concealcursor only on entering/leaving nvic and re-reads the base whenever the current value isn't one parley set. comment/init.lua:20; prep_chat's "" is lost after a markdown buffer records "nc".
- **BR-10** [Minor] `comment-drift` highlighter.lua:365, :691-697 and atlas/modes/review.md:257 still describe ParleyReviewUser/Agent painting marker sections
  2nd in family. Rule: when a diff changes what a highlight group paints, grep the group name across lua/ and atlas/ and update every mention in the same edit.
- **BR-11** [Minor] `insert-edge-semantics` Concealed spans collapse two insert positions onto one screen column
  2nd in family. Before-🤖 and anchor-start (and anchor-end and after-marker) look identical; one Right press seems to do nothing and where text goes is ambiguous. Rule: where concealment merges insert positions, pick one deliberately and document it.
- **BR-12** [Minor] `done-when-contract-drift` Issue Spec/M1 row say concealcursor=nvic unqualified; BR-3 scoping revision recorded only in the plan
  2nd in family. Rule: every plan Revisions entry that changes a decision also updates the issue's Spec/Done-when/Plan rows and adds an issue Revisions entry in the same commit.

## Round 4 — 2026-10-09T21:37:52-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — not-addressed — Plan unchanged in this window; Tasks 8/10 still enumerate test cases in prose.

### Raised

- **BR-13** [Critical] `edit-tracking-extmark` Thread float second :w is always refused; extmark drifts after replace_user_lines rewrites the row
  float.lua write_back replaces the whole row, moving the extmark off m.start, so the next write-back compares the wrong bytes and fails with "marker changed underneath" (reproduced: write r1, edit, write again leaves r1). Rule: a position tracked across a self-applied edit must be re-anchored after the edit (set_extmark with id) or the edit narrowed to the tracked span. Add multi-write and :w-then-q tests.
- **BR-14** [Important] `artifact-append-anchor` The log M2 commit spliced the M2 Log bullets into the Spec "Grammar change" sentence
  The insert matched the first "## Revisions" substring inside Spec prose instead of the Log heading; Spec is corrupted, Log lacks M2 entries, and the first bullet is truncated. Rule: append by matching the section heading line, never a substring.
- **BR-15** [Important] `done-when-contract-drift` Plan/Spec still describe WinClosed auto-write and anchor decode; code does neither, and there is no M2 Revisions entry
  3rd finding in this family. Rule: every change from a plan's Integration-point or Task text lands as a Revisions entry in the same commit that makes the change. Sweep: (a) WinClosed write-back and close-writes in Spec/Done-when vs register-on-close, (b) Task 10 anchor decode vs turn-only, (c) codec future-extension <br\> vs shipped \<br>.
- **BR-16** [Important] `cross-version-input-decode` Accept now decodes a literal <br> in legacy or old-grammar turn text into a newline before ariadne#316 lands
  Agents following the currently deployed review-convention write a literal <br> in table-row proposals; M-a now inserts a newline and breaks the table without warning. Block the #312 merge on ariadne#316 landing and the re-weave, and record that dependency.
- **BR-17** [Minor] `escape-totality` codec escape is not total; a backslash before a newline decodes to a literal <br>
- **BR-18** [Minor] `keymap-install-single-path` comment/init re-implements native_map gating; the arch guard was widened to allow a second install path

## Round 5 — 2026-10-09T21:41:58-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — withdrawn — Overtaken by implementation; the risky functions shipped with the property test the finding asked for.
- BR-13 — addressed — float.lua:44-46 re-anchors; comment_float_spec "a second :w" uses a col>0 prefix, so it fails without the fix.
- BR-14 — addressed — Spec Grammar-change sentence is clean; Log carries the M2 bullets under its own heading.
- BR-15 — addressed — Plan Revisions "M2 as built" covers WinClosed, Task 10 anchor decode, and the codec escape; issue Spec and Done-when synced.
- BR-16 — not-addressed — Recorded as an accepted edge in Spec, but deps is still [] and nothing ties the #312 merge to ariadne#316 plus the re-weave.
- BR-17 — not-addressed — Still true: decode(encode("a\\\nb")) == "a<br>b" (verified headless).
- BR-18 — not-addressed — comment/init.lua:72-73 still re-implements the default_keymaps gating; single_source_sweeps_spec still widened.

### Raised

- **BR-19** [Critical] `reply-slot-normalization` Float on a fresh marker (empty []) writes back a doubled human turn
  thread.to_lines always appends [] and from_lines drops only trailing empty turns, so 🤖<X>[] (the <M-q> output) plus a reply becomes 🤖<X>[][reply], and a no-edit :w deletes the []. Rule: a thread has exactly one empty reply slot. Add an integration test that runs <M-q>, then <CR>, a reply, and :w.
- **BR-20** [Important] `comment-drift` atlas/chat/drill_in.md still documents multi-line quotes and multi-line compose; M2 made chat <M-q> single-line
  3rd finding in comment-drift. Rule: a behavior change updates every prose description of it, including every caller's atlas page, in the same commit. Document the chat change and point multi-line questions to the float.
- **BR-21** [Minor] `orphaned-definitions` thread.to_lines returns roles that the float ignores; paint_roles re-derives roles with a different rule

## Round 6 — 2026-10-09T21:45:10-07:00 (claude) — passed

### Disposed

- BR-16 — addressed — Issue frontmatter now carries deps: [ariadne#316] (4e5e86c0); Spec records merge pending and the weave dependency.
- BR-17 — not-addressed — codec.lua unchanged on this axis; encode("a\\\nb") yields "a\\<br>b", which decodes to "a<br>b". Backslash is still not escaped.
- BR-18 — not-addressed — comment/init.lua:72-73 still re-derives default_keymaps gating; the arch guard still accepts a second install path.
- BR-19 — addressed — thread.to_lines treats an existing trailing empty [] as the reply slot (appended=false), and from_lines keeps it. Unit test plus integration test "a fresh <M-q> marker's empty [] is the reply slot"; both fail without the fix.
- BR-20 — addressed — atlas/chat/drill_in.md Lifecycle steps 1-2 and line 96 now describe single-line quotes, the float for multi-line, and decode at gather time; no other atlas page claims multi-line compose.
- BR-21 — not-addressed — float.lua:96 still discards to_lines' roles; paint_roles (float.lua:65-75) re-derives them by first-char rule.

### Raised

- **BR-22** [Minor] `discard-path-side-effects` :q! with edits overwrites the unnamed register and warns "closed without :w"
  The WinClosed handler (float.lua:142-151) cannot tell a deliberate :q! from an accidental close, so a discard clobbers " and shows a misleading warning, although the Spec says ":q! discards". Fix with a QuitPre/cmdline bang flag, or document the stash.

## Round 7 — 2026-10-10T11:23:56-07:00 (claude) — passed

### Disposed

- BR-9 — addressed — sync_concealcursor re-reads the base each time it starts forcing and writes only when entering or leaving nvic; comment_attach_spec "keeps a later change to the window's own value" pins it.
- BR-10 — addressed — Overtaken by the smoke-test redesign: turns_hl paints turn ranges with ParleyReviewUser/Agent again (highlighter.lua:86-88), so the comments at :372 and :698 and atlas review.md:62 are accurate.
- BR-11 — not-addressed — Partially narrowed by the visible reply, but before-🤖 and anchor-start are still two allowed insert points on one screen column (view.lua:117-118), and the choice is not documented.
- BR-12 — addressed — Issue Spec line 55 and the M1 row (line 123) now say nvic on marker lines; the issue Revisions carries the BR-3 entry.
- BR-17 — not-addressed — codec.lua is unchanged since M2; a backslash before a newline still decodes to a literal <br>.
- BR-18 — not-addressed — comment/init.lua:75-77 still re-derives the default_keymaps gating instead of using native_map.
- BR-21 — addressed — paint_roles now iterates thread.roles (float.lua:69), the same function to_lines returns; unit test "roles: continuation lines inherit, prefixes switch".
- BR-22 — not-addressed — The WinClosed handler (float.lua:144-154) is unchanged; :q! with edits still overwrites the unnamed register and shows the warning.

### Raised

- **BR-23** [Minor] `escape-totality` The float's line grammar is not injective; :w silently splits or truncates turns containing its delimiters
  2nd finding in escape-totality (BR-17 is the codec instance). Verified headless: 🤖[a<br>💬: b] becomes 🤖[a][b]; {a<br>🤖: z} becomes {a}{z}; [a<br>] becomes [a]. Rule: every layout the codec or float encodes into must be injective, and the round-trip property test must generate turn text from the grammar's own delimiters (<br>, backslash, ]/}, line-start 💬:/🤖:, trailing <br>). Fix it by escaping prefix-led continuation lines and backslashes, then extend the generator's word list at comment_thread_spec.lua:54.

## Open findings

- **BR-11** [Minor] `insert-edge-semantics` Concealed spans collapse two insert positions onto one screen column
- **BR-17** [Minor] `escape-totality` codec escape is not total; a backslash before a newline decodes to a literal <br>
- **BR-18** [Minor] `keymap-install-single-path` comment/init re-implements native_map gating; the arch guard was widened to allow a second install path
- **BR-22** [Minor] `discard-path-side-effects` :q! with edits overwrites the unnamed register and warns "closed without :w"
- **BR-23** [Minor] `escape-totality` The float's line grammar is not injective; :w silently splits or truncates turns containing its delimiters
