# Boundary Review — parley.nvim#310 (whole-issue close)

| field | value |
|-------|-------|
| issue | 310 — Issue view: overlay all tracker card fields generically |
| repo | parley.nvim |
| issue file | workshop/issues/000310-issue-view-overlay-all-tracker-card-fields-generically.md |
| boundary | whole-issue close |
| milestone | — |
| window | 44e451db6459f8462976f5669ca7a8bb472c08cb..6baa9f72d37924778aafbdc1172236cfe4bb5293 |
| command | sdlc close --issue 310 |
| reviewer | claude |
| timestamp | 2026-10-02T10:12:19-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The change does what #310 asks. Card-owned fields now come from the vocabulary everywhere. `RECORD_FIELDS` and `VIEW_FIELDS` are gone, and `overlay`, `annotations`, `missing` and `view_lines` all take `names` from `issue_tracker.field_names()`. One shared `frontmatter` reader now handles both card blobs and details buffers, so nested `claimant:` blocks compare the same way on both sides. Buffer bytes are never written: virtual lines are extmarks above the closing `---`. The repo's vocabulary (`construct/generated/vocabulary/issue.json`) declares `started`, `actual_hours` and `claimant`, so the Done-when example works end to end. I ran `make test-spec SPEC=issues/issue-management`: every mapped spec file reported 0 failures and 0 errors. Only one thing stands between this and SHIP. The "blank card value → nothing" case is listed in Done-when but no test reaches it: if the `blank()` guard in `missing` were deleted, every test would still pass.

1. **Strengths**
   - `lua/parley/issue_cards.lua:60` `frontmatter()` is one reader for cards and details (ARCH-DRY). It fixed a real false-stale bug, where a mirrored `claimant:` block read as `""`, and the regression test pins it (`issue_cards_spec.lua` "compares a nested local field as a block").
   - Block values are kept as ordered, dedented child lines and compared with `vim.deep_equal`. Order survives, indentation differences (2 vs 4 spaces) are normalized, and `field_lines`/`inline` turn them back into a YAML shape or an inline note.
   - The "field new to the vocabulary" test (`issue_cards_spec.lua`, `reviewer: ada`) proves the single-source claim directly.
   - The integration spec checks the exact virt_lines payload, its row, `virt_lines_above`, the highlight group, and that the buffer bytes are untouched.
   - The atlas is updated, including the card-view wording change.

2. **Critical:** none.

3. **Important**
   - The `not blank(value)` skip in `issue_cards.missing` (`issue_cards.lua:284`) is never exercised. In every fixture, the blank card fields (`estimate_hours`, `github_issue`) already have a local line, so `present` filters them out first. Fix: add a case where the details lack a key whose card value is blank (scalar `""` and empty block) and assert nil or an absent line. Done-when lists this explicitly.

4. **Minor**
   - `overlay`'s `tracker_stale` now also flags fields the details simply don't have (`started`, `claimant`), so its meaning has become "differs or absent". It's harmless today because `issue_finder_records.render` only paints status, title and github_issue. A comment on `tracker_stale` would stop a future consumer from counting it as "stale".
   - `view_lines` with `names == nil` shows no card fields. That's acceptable because the tracker is off without a vocabulary, but nothing documents it.
   - `frontmatter` takes the block indent from the first child line, so a later child with less (but non-zero) indent ends the block early. This is an edge case YAML itself would reject.
   - `set_of` is introduced but `missing` builds its own `present` set inline. This is trivial.

5. **Test coverage**
   - The unit tests cover missing → virtual line, stale → eol note, match → nothing, ordering (vocabulary order differs from card order and from Lua's `pairs` order), nested blocks, and inline rendering of a block.
   - The integration tests cover painting with a real git tracker fixture.
   - The only gap is the blank-value skip above.

6. **Architecture**
   - ARCH-DRY pass: one reader; the hardcoded lists are deleted.
   - ARCH-PURE pass: `missing`, `annotations` and `frontmatter` are pure; `paint` is a thin extmark shell.
   - ARCH-PURPOSE pass: all four consumers derive from the vocabulary, the class swept in one go.
   - ARCH-MOCK pass: no new external dependency; the existing git fixture is reused.
   - ARCH-CONSTRAINTS pass: parsing is linear in frontmatter size and runs on attach/refresh only.
   - ARCH-SECURE pass: card text from the tracker branch is parsed defensively; `parse_card` still rejects cards without a numeric `id`, and malformed blocks degrade to scalars.
   - ARCH-ORDER pass: holds no new state between events, because `paint` clears the namespace and repaints from scratch.
   - ARCH-FUNERAL pass: creates nothing durable beyond namespaced extmarks, which `nvim_buf_clear_namespace` removes on each paint and the buffer frees on wipe.

7. **Plan revisions:** none needed. The Core concepts table matches the code: every row exists at `lua/parley/issue_cards.lua` with the stated status, and both deleted constants are gone.

```findings
findings:
  - id: new
    severity: Important
    family: done-when-case-untested
    title: |
      missing() blank-card-value skip has no test reaching it
    detail: |
      All fixtures with blank card values (estimate_hours, github_issue) already have a local line, so `present` filters them first; deleting the `not blank(value)` guard at issue_cards.lua:284 leaves every test green. Add a case with a details file lacking a key whose card value is blank (scalar and empty block).
  - id: new
    severity: Minor
    family: field-semantics-undocumented
    title: |
      overlay tracker_stale now also flags fields absent from the details
    detail: |
      Harmless today (render paints only status/title/github_issue), but a comment on tracker_stale would stop a future consumer from treating it as a stale count.
  - id: new
    severity: Minor
    family: field-semantics-undocumented
    title: |
      view_lines shows no card fields when names is nil
    detail: |
      Acceptable since the tracker is off without a vocabulary; worth one line in the doc comment.
```

---

## Re-review — 2026-10-02T10:15:46-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 310 — Issue view: overlay all tracker card fields generically |
| repo | parley.nvim |
| issue file | workshop/issues/000310-issue-view-overlay-all-tracker-card-fields-generically.md |
| boundary | whole-issue close |
| milestone | — |
| window | 44e451db6459f8462976f5669ca7a8bb472c08cb..bb33472800137efccebb1e994e6dc276b060c254 |
| command | sdlc close --issue 310 |
| reviewer | claude |
| timestamp | 2026-10-02T10:15:46-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

All three findings from the last round are fixed, and the fix commit `bb334728` adds no new code paths. To check BR-1, I took a scratch copy of the head commit (`git archive bb334728`) and deleted the `not blank(value)` guard at `lua/parley/issue_cards.lua:286`. The new test "adds nothing for a blank card value the details lack, scalar or block" then failed. That proves this guard is now the only thing filtering that fixture: `DETAILS_296` has no `actual_hours`, `claimant` or `started` line, so the `present` check can't hide the bug. A second change, also removing the `name ~= "title"` check, made the new title/unterminated-frontmatter test fail too. At the head commit, `tests/unit/issue_cards_spec.lua` passes 32/0 and `tests/integration/issue_tracker_buffer_spec.lua` passes 5/0. BR-2 and BR-3 only needed comments, and the comments now say what the code does.

1. **Strengths**
   - `frontmatter()` (`issue_cards.lua:60`) is now the one frontmatter parser used by `parse_card`, `annotations` and `missing`. Before this change, `parse_card` and `annotations` each had their own copy of the parse loop (ARCH-DRY).
   - `RECORD_FIELDS` and `VIEW_FIELDS` are deleted. The overlay and the view now take their field list from the vocabulary through `names`, so no list repeats the model by hand (ARCH-PURPOSE).
   - The new test sets the scalar `""`, the empty block `{}` and `nil` in one case, so it covers every form `blank()` accepts.
   - The new rule in `workshop/lessons.md` (give each guard a case where only that guard filters, and check it by mutation) covers the whole `done-when-case-untested` family, not just this one test.

2. **Critical:** none.
3. **Important:** none.
4. **Minor:** none new.
5. **Test coverage:** each guard in `missing()` (`not card`, `not close`, `title`, `present`, `blank`) now has a test that fails when that guard is removed. All the logic is pure and the tests do no IO.
6. **Architecture:**
   - **Pass:** ARCH-DRY, ARCH-PURE, ARCH-PURPOSE.
   - **Not applicable**, with reasons:
     - ARCH-MOCK: no new external calls.
     - ARCH-CONSTRAINTS: the frontmatter scans are bounded by the file's size.
     - ARCH-SECURE: hand-edited or unterminated details files degrade to "nothing shown" (tested).
     - ARCH-ORDER: these functions keep no state between events.
     - ARCH-FUNERAL: nothing durable is created; the virtual lines live only in the buffer.
7. **Plan revisions:** none.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      New case at tests/unit/issue_cards_spec.lua:200 (details lack the keys; card values "", {}, nil); scratch-copy mutation removing `not blank(value)` turns it red.
  - id: BR-2
    disposition: addressed
    note: |
      Overlay doc comment now states tracker_stale is a per-field paint set that includes fields the details lack, not a stale count.
  - id: BR-3
    disposition: addressed
    note: |
      view_lines doc comment now states nil names shows no fields (tracker off without a vocabulary); matches the `names or {}` loop.
```
