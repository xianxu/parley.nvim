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
