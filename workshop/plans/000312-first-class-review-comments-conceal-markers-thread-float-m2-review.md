# Boundary Review — parley.nvim#312 (milestone M2)

| field | value |
|-------|-------|
| issue | 312 — First-class review comments: conceal markers + thread float |
| repo | parley.nvim |
| issue file | workshop/issues/000312-first-class-review-comments-conceal-markers-thread-float.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | 5f6020e4ba4de11f4d929f8f4a3d3a1be2dece0e..459d1108fc46f8f2f001e0a0e1de83a8b10d97e2 |
| command | sdlc milestone-close --issue 312 --milestone M2 |
| reviewer | claude |
| timestamp | 2026-10-09T21:37:52-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

**Verdict: REWORK.** The M2 code is mostly sound, but one core write-back path is broken, and I confirmed it by running it. After a first `:w` in the thread float, every later `:w`, `:x` or `q` is refused with "marker changed underneath", unless the marker sits at column 0. The pure core holds up well: `thread.lua`, the codec, and `<br>` decoding only in turn text, with property tests behind each. Two more things need cheap fixes before the boundary. The `#312: log M2` commit pasted the M2 log into the middle of the Spec. And the plan still describes behavior the code no longer has, with no Revisions entry.

### 1. Strengths
- `lua/parley/comment/thread.lua` is pure, has no second parser (it reuses `_parse_marker_sections`), and has a 500-case round-trip property test over generated markers (`tests/unit/comment_thread_spec.lua:33`).
- `drill_in.resolve` / `format_block` decode only turn text and keep anchors verbatim. The tests pin both sides, including a literal `<br>` inside an anchor (`tests/unit/drill_in_spec.lua:1049`).
- The float refuses to lose user text: on stale-marker and unbalanced-bracket errors the float stays open, and the text goes to the `"` register (tested).
- `<CR>` respects `default_keymaps=false`, keeps the count on the native fallback, and is declared in `native_overrides`. The arch guard now checks the module named in `where`.

### 2. Critical
- **`lua/parley/comment/float.lua:41`: a second write-back is always refused.**
  - **Cause:** `replace_user_lines` rewrites row `row` from column 0. The tracking extmark at `m.start` moves (I observed it at col 29 after the first write). `write_back` then compares `line:sub(col+1, col+#st.raw)` against the new `st.raw`, finds a mismatch, and refuses.
  - **Reproduction:** in a scratch spec, open `see 🤖<X>[q]{a}[ok] end`, set `[r1]`, `:w`, edit to `[r1 more]`, `:w`. The line stays `…[r1] end` and the "marker changed underneath" warning fires. `:w` followed by `q` hits the same refusal.
  - **Fix:** re-anchor the extmark after the edit with `nvim_buf_set_extmark(src, NS, row, col, { id = st.mark })`, or narrow the edit to just the marker span.
  - **Missing test:** every existing float test writes exactly once, so no test reaches the second write. Add a test with two writes in a row and one with `:w` then `q`. ARCH-ORDER: the tests only exercise one event sequence.

### 3. Important
- **The issue file is corrupted (`workshop/issues/000312-…md:71`).**
  - The `#312: log M2` commit inserted the M2 log bullets inside the Spec sentence "as a `## Revisions` entry". It matched the first `## Revisions` substring instead of the `## Log` heading.
  - Result: the Spec now holds log text, `## Log` has no M2 entries, and the first bullet is cut off ("keeps text in "").
  - Fix: restore the Spec sentence and move the bullets under `### 2026-10-09` in `## Log`. Rule: append to a section by matching its heading line (`^## Log$`), never a substring.
- **The plan contradicts the M2 code, with no Revisions entry.** This is the 3rd finding in `done-when-contract-drift`, so per the escalation the rule is fixed rather than the instance: any change from a plan's Integration-point or Task text gets a `## Revisions` entry in the same commit that makes the change. Three places to fix now:
  - (a) The plan says `WinClosed → write_back`, and Task 8 test 4 closes with `:q`. The code instead keeps unsaved text in the `"` register on close; only `:w`, `:x` and `q` write. The issue's Spec and Done-when ("close writes") need the same revision.
  - (b) Task 10 Step 3 says to decode anchors too. The code correctly does not.
  - (c) The codec's "future extension" names a `<br\>` escape. The code uses `\<br>`.
- **Legacy `<br>` input is now decoded on accept (ARCH-SECURE: input crossing a version boundary).**
  - The grammar change (ariadne#316) is not merged, so agents following the currently deployed review-convention still write a literal `<br>` in a table-row proposal. `<M-a>` now turns that into a newline and breaks the table without warning.
  - Fix: block #312's merge until ariadne#316 lands and parley re-weaves, and record that dependency in the issue.

### 4. Minor
- **Codec escape is not total:** a turn ending in `\` followed by a newline encodes to `\<br>`, which decodes back to a literal `<br>`, losing the newline. A backslash is never escaped itself.
- **ARCH-DRY:** `comment/init.lua:72` re-implements `native_map`'s `default_keymaps` gate and skips its registration check. The arch guard had to grow a source-grep to allow the second install path. Hoisting `native_map` into `keybinding_registry` would fix both.
- **`paint_roles`:** a continuation line that starts with `[` or `{` (for example, a markdown link) switches the role color.
- **Register side effects:** `setreg('"')` overwrites the user's unnamed register on refused writes and closes, silently except for the notify message.
- **Native fallback:** `feedkeys(..., "n")` skips any user-defined `<CR>` mapping.
- **BR-1 (carried):** plan Tasks 8 and 10 still list test cases in prose. Still open.

### 5. Test coverage notes
- The thread and codec unit tests are strong.
- Float integration covers open, a single write, the no-edit close, the stale-marker and unbalanced refusals, and `q` / `:q!`. What's missing:
  - multiple writes;
  - a marker that isn't the first one on its line;
  - a source edit before the marker but on the same row (only the extmark gravity matters there).

### 6. Architectural notes (ARCH-* lenses)
- **ARCH-DRY:** flag (Minor, above).
- **ARCH-PURE:** pass — the thread and codec are pure, and `float.lua` is a thin shell over them.
- **ARCH-PURPOSE:** pass for parley's own writers. The agent writer depends on ariadne#316 (Important, above).
- **ARCH-MOCK:** not applicable — no external binary or service is involved.
- **ARCH-CONSTRAINTS:** pass — the per-keystroke repaint only covers the small float buffer.
- **ARCH-SECURE:** flag (legacy `<br>`, above).
- **ARCH-ORDER:** flag — the float's state (`st.raw`, extmark) across write events is implicit, and that's where the Critical bug lives.
- **ARCH-FUNERAL:** pass — the buffer is wiped, and the extmark and augroup are removed on `WinClosed`.

### 7. Plan revision recommendations
- **2026-10-09, M2 write-back semantics:** `:w`, `:x` and `q` write; any other close keeps the text in `"`; no auto-write on `WinClosed`. Update the Spec "On close/write" and the Done-when "close writes" to match.
- **2026-10-09, Task 10:** decode turn text only; anchors stay verbatim (ariadne#316 BR-1). Replace the codec's `<br\>` future-extension note with the `\<br>` escape that shipped.

```findings
dispose:
  - id: BR-1
    disposition: not-addressed
    note: |
      Plan unchanged in this window; Tasks 8/10 still enumerate test cases in prose.
findings:
  - id: new
    severity: Critical
    family: edit-tracking-extmark
    title: |
      Thread float second :w is always refused; extmark drifts after replace_user_lines rewrites the row
    detail: |
      float.lua write_back replaces the whole row, moving the extmark off m.start, so the next write-back compares the wrong bytes and fails with "marker changed underneath" (reproduced: write r1, edit, write again leaves r1). Rule: a position tracked across a self-applied edit must be re-anchored after the edit (set_extmark with id) or the edit narrowed to the tracked span. Add multi-write and :w-then-q tests.
  - id: new
    severity: Important
    family: artifact-append-anchor
    title: |
      The log M2 commit spliced the M2 Log bullets into the Spec "Grammar change" sentence
    detail: |
      The insert matched the first "## Revisions" substring inside Spec prose instead of the Log heading; Spec is corrupted, Log lacks M2 entries, and the first bullet is truncated. Rule: append by matching the section heading line, never a substring.
  - id: new
    severity: Important
    family: done-when-contract-drift
    title: |
      Plan/Spec still describe WinClosed auto-write and anchor decode; code does neither, and there is no M2 Revisions entry
    detail: |
      3rd finding in this family. Rule: every change from a plan's Integration-point or Task text lands as a Revisions entry in the same commit that makes the change. Sweep: (a) WinClosed write-back and close-writes in Spec/Done-when vs register-on-close, (b) Task 10 anchor decode vs turn-only, (c) codec future-extension <br\> vs shipped \<br>.
  - id: new
    severity: Important
    family: cross-version-input-decode
    title: |
      Accept now decodes a literal <br> in legacy or old-grammar turn text into a newline before ariadne#316 lands
    detail: |
      Agents following the currently deployed review-convention write a literal <br> in table-row proposals; M-a now inserts a newline and breaks the table without warning. Block the #312 merge on ariadne#316 landing and the re-weave, and record that dependency.
  - id: new
    severity: Minor
    family: escape-totality
    title: |
      codec escape is not total; a backslash before a newline decodes to a literal <br>
  - id: new
    severity: Minor
    family: keymap-install-single-path
    title: |
      comment/init re-implements native_map gating; the arch guard was widened to allow a second install path
```

---

## Re-review — 2026-10-09T21:41:57-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 312 — First-class review comments: conceal markers + thread float |
| repo | parley.nvim |
| issue file | workshop/issues/000312-first-class-review-comments-conceal-markers-thread-float.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | 5f6020e4ba4de11f4d929f8f4a3d3a1be2dece0e..18cd5bd81a10070f0e73f19a29d71b5aa05cd481 |
| command | sdlc milestone-close --issue 312 --milestone M2 |
| reviewer | claude |
| timestamp | 2026-10-09T21:41:57-07:00 |
| verdict | REWORK |

## Review

I found one new Critical bug and one new Important doc gap, so the verdict is REWORK.

```verdict
verdict: REWORK
confidence: high
```

Most of M2 is in good shape. The pure `thread.lua` is tested with a round-trip property test, and the float follows plain nvim write/quit semantics. Writing the thread back first checks that the original bytes are still in place, and the BR-13 re-anchor fix has a regression test. One new correctness bug blocks SHIP. In the main flow, `<M-q>` inserts `🤖<sel>[]` and `<CR>` then opens the float. That float has two empty `[]` lines. If you type in the reply slot and save, the result is `🤖<sel>[][comment]`: two human turns in a row, which the Spec lists as out of scope. I confirmed this in headless nvim. Smaller items: the chat drill-in atlas page still describes multi-line quotes, which M2 removed. BR-16 (no blocking dependency on ariadne#316), BR-17 and BR-18 are still open.

**1. Strengths**
- `lua/parley/comment/float.lua:28-49`: before writing, `write_back` checks that the original marker bytes are still at the tracked position. If they are not, it refuses and copies the float text to the `"` register, so nothing is lost silently. The re-anchor at :44-46 closes BR-13. The test "a second :w writes again" uses a line prefix (`lead text`), so it would fail without the fix.
- `lua/parley/comment/thread.lua` is pure and reuses the existing section parser instead of adding a second one (ARCH-DRY). `tests/unit/comment_thread_spec.lua` round-trips 500 generated markers, including `\<br>` and nested brackets.
- `drill_in.resolve` and `format_block` decode only the turn text. The anchor's X / D stays verbatim, and tests in `tests/unit/drill_in_spec.lua` pin this.
- `<CR>` is declared in `native_overrides`, keeps the count when it falls back to native `<CR>`, and respects `default_keymaps`. There is an integration test of the real key press.

**2. Critical**
- **Empty reply slot gets doubled.**
  - **Where:** `lua/parley/comment/thread.lua:25-26` (`to_lines` always appends `[]`) and `:48-50` (`from_lines` only drops *trailing* empty turns).
  - **What happens:** for `🤖<first>[]` (exactly what `<M-q>` writes), `to_lines` returns `{"[]","[]"}`. With the reply typed on the last line, the write produces `🤖<first>[][my comment]`. This was verified in headless nvim.
  - **Same rule, second symptom:** `:w` with no edits writes back `🤖<first>`, deleting the `[]`.
  - **Rule:** a thread has exactly one empty reply slot. `to_lines` should not append one when the last turn is already an empty human turn, or `from_lines` should drop empty turns wherever they appear.
  - **Test to add:** an integration test that runs `<M-q>`, then `<CR>`, types a reply, writes, and expects `🤖<X>[reply]`.

**3. Important**
- **Chat drill-in docs are out of date** (family `comment-drift`, 3rd finding).
  - `atlas/chat/drill_in.md:32-34` still says "multi-line allowed", and its quote-block examples show multi-line T. In chat, `<M-q>` now refuses a selection that spans lines.
  - In chat, pressing Enter inside a `[]` turn now produces a marker that renders as broken.
  - **Rule:** when behavior changes, update every prose description of it in the same commit. That means the atlas pages of every caller, not only the module's own page. The atlas page should explain the chat change and suggest `<CR>` / the float for multi-line questions.

**4. Minor**
- `:q!` overwrites the `"` register and warns "closed without :w". `WinClosed` can't tell an explicit discard from an accidental close (`float.lua:136-142`).
- `thread.to_lines` returns `roles`, but the float ignores it. `paint_roles` works out roles again with a different rule, so a continuation line that starts with `[` gets the wrong colour (ARCH-DRY).
- BR-17 and BR-18 are still present (see the dispositions below).

**5. Test coverage notes**
- The float tests only use markers that already have turns. None start from a fresh `[]` marker, which is how the Critical bug got through.
- No test covers `:x` or `q` when the brackets are unbalanced. As I read the code (not run), the window closes and the text goes to the register.

**6. Architecture**
- **ARCH-DRY:** flagged as Minor (roles worked out twice; BR-18).
- **ARCH-PURE:** passes. `thread` is pure and `float` is a thin layer around it.
- **ARCH-PURPOSE:** flagged by the Critical bug, since the main "insert, then comment" flow is broken.
- **ARCH-MOCK:** not applicable; there are no external dependencies.
- **ARCH-CONSTRAINTS:** passes. `<CR>` parses one line, and re-painting on every keystroke only covers the small thread buffer.
- **ARCH-SECURE:** passes. Edited float text is parsed, and failures are reported to the user.
- **ARCH-ORDER:** passes. An edit to the source underneath, or two floats on the same marker, is caught by the byte check before writing.
- **ARCH-FUNERAL:** passes. The extmark and augroup are removed on `WinClosed`, and the buffer is wiped when closed.

**7. Plan revisions**
- Add a Revisions entry for the reply-slot rule once it is fixed.
- Add a dependency on ariadne#316 to the issue (BR-16).

```findings
dispose:
  - id: BR-1
    disposition: withdrawn
    note: |
      Overtaken by implementation; the risky functions shipped with the property test the finding asked for.
  - id: BR-13
    disposition: addressed
    note: |
      float.lua:44-46 re-anchors; comment_float_spec "a second :w" uses a col>0 prefix, so it fails without the fix.
  - id: BR-14
    disposition: addressed
    note: |
      Spec Grammar-change sentence is clean; Log carries the M2 bullets under its own heading.
  - id: BR-15
    disposition: addressed
    note: |
      Plan Revisions "M2 as built" covers WinClosed, Task 10 anchor decode, and the codec escape; issue Spec and Done-when synced.
  - id: BR-16
    disposition: not-addressed
    note: |
      Recorded as an accepted edge in Spec, but deps is still [] and nothing ties the #312 merge to ariadne#316 plus the re-weave.
  - id: BR-17
    disposition: not-addressed
    note: |
      Still true: decode(encode("a\\\nb")) == "a<br>b" (verified headless).
  - id: BR-18
    disposition: not-addressed
    note: |
      comment/init.lua:72-73 still re-implements the default_keymaps gating; single_source_sweeps_spec still widened.
findings:
  - id: new
    severity: Critical
    family: reply-slot-normalization
    title: |
      Float on a fresh marker (empty []) writes back a doubled human turn
    detail: |
      thread.to_lines always appends [] and from_lines drops only trailing empty turns, so 🤖<X>[] (the <M-q> output) plus a reply becomes 🤖<X>[][reply], and a no-edit :w deletes the []. Rule: a thread has exactly one empty reply slot. Add an integration test that runs <M-q>, then <CR>, a reply, and :w.
  - id: new
    severity: Important
    family: comment-drift
    title: |
      atlas/chat/drill_in.md still documents multi-line quotes and multi-line compose; M2 made chat <M-q> single-line
    detail: |
      3rd finding in comment-drift. Rule: a behavior change updates every prose description of it, including every caller's atlas page, in the same commit. Document the chat change and point multi-line questions to the float.
  - id: new
    severity: Minor
    family: orphaned-definitions
    title: |
      thread.to_lines returns roles that the float ignores; paint_roles re-derives roles with a different rule
```

---

## Re-review — 2026-10-09T21:45:10-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 312 — First-class review comments: conceal markers + thread float |
| repo | parley.nvim |
| issue file | workshop/issues/000312-first-class-review-comments-conceal-markers-thread-float.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | 5f6020e4ba4de11f4d929f8f4a3d3a1be2dece0e..4e5e86c0ee245ce8385d27c8a16351496bc7ac94 |
| command | sdlc milestone-close --issue 312 --milestone M2 |
| reviewer | claude |
| timestamp | 2026-10-09T21:45:10-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: medium
```

**Summary.** The M2 window delivers what Plan Tasks 7–11 promise: a pure `thread` layout round-trip, the float glue, the `<CR>` native override, single-line `<M-q>`, decoding of turn text only, and the `\<br>` escape. The atlas was updated alongside. The one Critical from the last round (BR-19, a fresh `[]` written back as a doubled turn) is fixed, and a test fails without the fix. BR-16 and BR-20 are addressed. BR-17, BR-18 and BR-21 are Minor and remain open, so they don't block. I ran `make test-spec SPEC=modes/review` and it passed: 8 spec files, 0 failed. Those files include comment_float_spec (12 tests), comment_thread_spec (11, including a 500-case property test) and drill_in_spec (120). Nothing blocks SHIP. One new Minor: `:q!` triggers the "closed without :w" path.

1. **Strengths**
   - `lua/parley/comment/thread.lua` is pure and reuses the buffer's section parser (no second parser). It has a generated round-trip property test (`tests/unit/comment_thread_spec.lua:45-60`) that includes `\<br>` and nested-bracket words.
   - The `appended` flag (`thread.lua:31`) gives one clear rule for the reply slot: an existing trailing empty `[]` is the slot. That covers both a fresh `<M-q>` marker and `{R}[]` ("go ahead").
   - `write_back` checks that the marker's bytes are unchanged before writing. If they changed, it refuses and keeps the text in `"`. It also re-anchors the extmark after each write (`float.lua:31-48`). The tests cover a second `:w` with lead text and a source edit made underneath the float.
   - Decoding is limited to turn text in `resolve` and `format_block` (`drill_in.lua:558,679,694`). Tests check that anchors stay verbatim (`drill_in_spec.lua:1049-1060`).
   - The stale-override arch guard now reads the module named in `where`, so `<CR>` living outside `prep_chat` is still checked against the registry.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - `float.lua:142-151`: the WinClosed handler can't tell `:q!` apart from an accidental close. A deliberate `:q!` with edits still overwrites the unnamed register and warns "thread closed without :w". The Spec says `:q!` discards. Possible fixes: a `QuitPre` flag, or say in the Spec/atlas that `:q!` also stashes the text.
   - BR-17, BR-18 and BR-21 are still open (see the dispositions below).

5. **Test coverage**
   - The BR-19 integration test builds the `🤖<sel>[]` marker directly instead of typing `<M-q>`. It exercises the same path: it fails without the fix because the float would show `{"[]","[]"}`.
   - The `:q!` test checks the source buffer but not the register or the warning, which is why the Minor above went unnoticed.
   - Codec totality (BR-17) has no test for a turn that ends in a backslash.

6. **Architecture**
   - **ARCH-DRY:** flag. The `default_keymaps` gating in `comment/init.lua:72-73` repeats logic that exists elsewhere (BR-18, still open).
   - **ARCH-PURE:** pass. `thread` and `codec` are pure; `float` is thin glue around them.
   - **ARCH-PURPOSE:** pass. Every consumer of turn text decodes (resolve, the two `format_block` sites). The review skill hands raw markers to the agent, which is correct by design.
   - **ARCH-MOCK:** not applicable; there is no external binary or service.
   - **ARCH-CONSTRAINTS:** pass. `paint_roles` repaints the whole float on every TextChangedI, but a thread is only a few lines.
   - **ARCH-SECURE:** pass. File text goes through the parser, and unbalanced input is refused with a visible error. The `\1` sentinel is only a problem for buffers containing control bytes (same family as BR-17).
   - **ARCH-ORDER:** pass. The float's state (`raw` and `mark`) is checked against the live source bytes before every write, so a concurrent edit to the source is detected and refused rather than overwritten.
   - **ARCH-FUNERAL:** pass. The scratch buffer is wiped, the extmark and augroup are deleted on WinClosed, and the old extmark is removed when re-anchoring.
   - **Next:** collapse the unused `roles` return into the single role rule that `paint_roles` uses, or remove it.

7. **Plan revisions:** if the `:q!` behavior stays as it is, add a `## Revisions` line saying `:q!` also stashes unsaved thread text in `"`.

```findings
dispose:
  - id: BR-16
    disposition: addressed
    note: |
      Issue frontmatter now carries deps: [ariadne#316] (4e5e86c0); Spec records merge pending and the weave dependency.
  - id: BR-17
    disposition: not-addressed
    note: |
      codec.lua unchanged on this axis; encode("a\\\nb") yields "a\\<br>b", which decodes to "a<br>b". Backslash is still not escaped.
  - id: BR-18
    disposition: not-addressed
    note: |
      comment/init.lua:72-73 still re-derives default_keymaps gating; the arch guard still accepts a second install path.
  - id: BR-19
    disposition: addressed
    note: |
      thread.to_lines treats an existing trailing empty [] as the reply slot (appended=false), and from_lines keeps it. Unit test plus integration test "a fresh <M-q> marker's empty [] is the reply slot"; both fail without the fix.
  - id: BR-20
    disposition: addressed
    note: |
      atlas/chat/drill_in.md Lifecycle steps 1-2 and line 96 now describe single-line quotes, the float for multi-line, and decode at gather time; no other atlas page claims multi-line compose.
  - id: BR-21
    disposition: not-addressed
    note: |
      float.lua:96 still discards to_lines' roles; paint_roles (float.lua:65-75) re-derives them by first-char rule.
findings:
  - id: new
    severity: Minor
    family: discard-path-side-effects
    title: |
      :q! with edits overwrites the unnamed register and warns "closed without :w"
    detail: |
      The WinClosed handler (float.lua:142-151) cannot tell a deliberate :q! from an accidental close, so a discard clobbers " and shows a misleading warning, although the Spec says ":q! discards". Fix with a QuitPre/cmdline bang flag, or document the stash.
```
