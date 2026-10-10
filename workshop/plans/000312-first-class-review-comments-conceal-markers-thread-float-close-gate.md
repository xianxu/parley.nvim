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

## Open findings

- **BR-1** [Minor] `test-prose-enumeration` Tasks 8 and 10 enumerate test cases in prose and Tasks 1-3 carry full test code; compress to one strategy line per risky function
- **BR-9** [Minor] `conceal-scope-widening` sync_concealcursor reads the window's base once and overwrites later user or prep_chat values
- **BR-10** [Minor] `comment-drift` highlighter.lua:365, :691-697 and atlas/modes/review.md:257 still describe ParleyReviewUser/Agent painting marker sections
- **BR-11** [Minor] `insert-edge-semantics` Concealed spans collapse two insert positions onto one screen column
- **BR-12** [Minor] `done-when-contract-drift` Issue Spec/M1 row say concealcursor=nvic unqualified; BR-3 scoping revision recorded only in the plan
