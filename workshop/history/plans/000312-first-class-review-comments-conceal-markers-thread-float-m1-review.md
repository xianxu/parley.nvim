# Boundary Review — parley.nvim#312 (milestone M1)

| field | value |
|-------|-------|
| issue | 312 — First-class review comments: conceal markers + thread float |
| repo | parley.nvim |
| issue file | workshop/issues/000312-first-class-review-comments-conceal-markers-thread-float.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 7d1eb92a1ddaa26ac701bf1f1a46881e61b495fa..51cc77fc9341c775573b573d822f1e6431ca44e9 |
| command | sdlc milestone-close --issue 312 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-10-09T21:09:55-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

M1 delivers what the plan says for Tasks 1–6. There's a pure codec, a pure `view.layout`/`snap`/`marker_at`, and a shared `push_marker_decorations` that feeds conceal extmarks into the decoration provider, which already draws only the visible rows. `comment.attach` sets `conceallevel=2` and `concealcursor=nvic` and snaps the cursor in normal and insert mode. I checked out HEAD `51cc77fc` and ran `make test-spec SPEC=modes/review`; all six specs pass (4 / 5 / 4 / 25 / 113 / 48). The viewport check prints `layout calls: first frame 61, after edit 61` on a 5000-row buffer.

Nothing blocks the boundary. One Important issue should be fixed or explicitly accepted first: the new window options apply to every `.md` buffer, not just to markers. They also change how existing Neovim conceals behave in those buffers, and the documentation doesn't say so.

**1. Strengths**
- **One source for the marker geometry.** `lua/parley/comment/view.lua:35` is the only place that decides what is hidden and what is visible. The highlighter, the cursor snap and the `<CR>` lookup all read it. Section parsing still goes through `review._parse_marker_sections`, so there is no second parser (ARCH-DRY).
- **Duplicate marker code merged.** The markdown pass used to have its own marker loop, and chat buffers rendered no markers at all. Both now call one `push_marker_decorations` (`highlighter.lua:76`) and both skip fenced code. A test covers both buffer kinds (`comment_render_spec.lua:55`).
- **The pure parts are tested without IO.** That includes a 3000-case randomized test that every range stays in bounds, doesn't overlap, and starts and ends on character boundaries (`comment_view_spec.lua:80`).
- **The viewport claim is measured, not asserted.** The test counts `layout` calls through the real provider seam (`comment_render_spec.lua:73`).
- **The broken rule is one rule.** An "unclosed opener" check covers both legacy #125 markers and markers an edit just broke, and an unmatched `~` stays ordinary prose (`view.lua:55-64`).

**2. Critical:** none.

**3. Important**
- **The conceal options affect much more than markers** (`comment/init.lua:34-35`, called from `init.lua:3167` for every buffer `is_markdown` accepts, i.e. any `*.md`/`*.markdown` file).
  - **Plain markdown files.** Before this change these buffers kept the default `conceallevel=0`. Now Neovim's built-in treesitter markdown conceals take effect: link destinations, `**`/`*` emphasis markers and code-span backticks. Because `concealcursor=nvic` keeps them hidden even on the cursor line in insert mode, you can no longer see the link URL or the `**` you are typing.
  - **Chat buffers.** The `chat_conceal_model_params` matchadds (`init.lua:2939-2945`) and branch links now stay hidden while you edit those lines too. The comment only mentions branch links.
  - **No snap for these conceals.** The cursor snap only knows about marker ranges, so the cursor can now sit on, and edit, invisible bytes in all of these places.
  - **Not documented.** The atlas presents the options as covering markers only.
  - **Fix sketch:** at minimum, document the side effect in `atlas/modes/review.md` and log it as a decision. Better, keep treesitter conceal out of the way: set `conceal_lines`/disable the `@conceal` captures for markdown_inline in parley buffers, or keep `concealcursor=""` outside a line that has markers. Either way, add a test asserting the agreed behavior for a `[t](url)` line.

**4. Minor**
- **Snapping left can land inside a multi-byte character.** `view.snap` steps left to `s - 1`, which can be a continuation byte. I checked: for `a 🤖<é>[c] z`, snapping left lands on col 8, where `str_utf_start = -1`. Neovim adjusts the cursor itself, but `prev_col` records the wrong column, and the property test doesn't cover `snap`. Fix: move to the character start, e.g. pass `line` and apply `vim.str_utf_start`.
- **In insert mode you can't type immediately before a quoted marker.** The insertion point at the marker's start counts as hidden, so it snaps right into `<X`, and typed text becomes part of the anchor. It is visible, so not silent, but this isn't documented.
- **A test name contradicts its assertion.** "returns nil when no visible byte exists" (`comment_view_spec.lua:143`) actually checks a non-nil snap onto `X`. Rename it, or add a real all-hidden case.
- **A comment doesn't match the code.** `ParleyReviewStrike` now sets `reverse = true`, but the comment says it "gets the quoted highlight too". Either link to the quoted group or reword the comment.
- **Highlight groups left without consumers.** `ParleyReviewUser`/`ParleyReviewAgent` (`highlighter.lua:691-693`) are no longer used by any renderer. M2 plans new `ParleyComment*` groups, so retire these or reuse them (ARCH-FUNERAL, minor).
- **Scanning stops at the first broken marker.** `view.layout` gives up on the rest of the line, so a later valid marker on the same line renders raw. That's acceptable, but it isn't stated.
- **Options set from the current window.** `attach` uses `vim.opt_local` on whichever window is current, and those values carry over to other buffers later opened in that window (the same as chat's old behavior).

**5. Test coverage**
- **Covered:** every row of the display table, broken markers, inline code, fenced code (markdown and chat), the snap directions in both modes, viewport bounding, and codec round-trips.
- **Gaps:** there is no test that a buffer edit which breaks a marker repaints it as broken, though the unclosed-input cases at rest cover that logic. Nothing tests multi-byte snapping, and nothing tests the side effects on conceals that aren't markers.

**6. Architecture**
- **ARCH-DRY: pass.** The parser and layout each have one source. `in_code` re-scans the inline-code ranges per marker; a shared predicate would be cleaner (trivial).
- **ARCH-PURE: pass.** `view` and `codec` are pure. `attach` is a thin layer over autocmds and the cursor.
- **ARCH-PURPOSE: pass for M1.** The float, write-back and the grammar revision are in M2, per the plan. One caveat: the purpose was "only markers change"; the conceal options go further (Important finding).
- **ARCH-MOCK: N/A.** No external binary or service.
- **ARCH-CONSTRAINTS: pass.** Rendering only touches visible rows (measured). The snap costs one line parse per cursor move, and only on lines that contain 🤖.
- **ARCH-SECURE: N/A.** Only local buffer text, and malformed markers render raw so the problem stays visible.
- **ARCH-ORDER: pass.** `prev_col` per window only decides the snap direction, it is cleared on `WinClosed`, and there are no other state flags.
- **ARCH-FUNERAL: pass.** The augroup is deleted on BufWipeout and `prev_col` on WinClosed; nothing is persisted. The one minor note is the unused highlight groups above.
- **For M2:** `<CR>` will reach `marker_at` for an empty-anchor marker (`hidden = {}`), so make sure the float handles it. Keep the write-back on `view.layout` rather than re-deriving positions.

**7. Plan revisions**
- If the operator accepts the conceal side effect, add a `## Revisions` entry: "`conceallevel=2`/`concealcursor=nvic` apply window-wide; treesitter markdown conceals (links, emphasis, code spans) and chat header-param conceals now stay hidden on the cursor line too." Otherwise, add a revision recording the scoping mechanism you choose.

```findings
findings:
  - id: new
    severity: Important
    family: conceal-scope-widening
    title: |
      attach's conceallevel=2 + concealcursor=nvic applies to every .md buffer and all conceals, not just markers
    detail: |
      Markdown buffers newly get treesitter conceals (link URLs, emphasis, code spans) and chat header-param matchadds kept hidden on the cursor line in insert mode, where the marker-only snap does not protect them; undocumented in atlas. Scope it or document and test the accepted behavior.
  - id: new
    severity: Minor
    family: snap-char-boundary
    title: |
      view.snap moving left lands on a UTF-8 continuation byte when the preceding visible char is multibyte
    detail: |
      For `a 🤖<é>[c] z` the left snap returns col 8 (str_utf_start -1); nvim adjusts but prev_col records the wrong col. Snap to the char start and add multibyte cases to the snap tests.
  - id: new
    severity: Minor
    family: insert-edge-semantics
    title: |
      In insert mode the insertion point right before a quoted marker is snapped into the anchor
    detail: |
      Text typed "before" a quoted marker becomes part of `<X>`; visible, but undocumented.
  - id: new
    severity: Minor
    family: test-name-drift
    title: |
      Test "returns nil when no visible byte exists" asserts a non-nil snap
  - id: new
    severity: Minor
    family: orphaned-definitions
    title: |
      ParleyReviewUser/ParleyReviewAgent highlight groups have no renderer consumer after the marker loop was replaced
  - id: new
    severity: Minor
    family: comment-drift
    title: |
      ParleyReviewStrike comment says it gets the quoted highlight, but the code only adds reverse=true
```

---

## Re-review — 2026-10-09T21:14:37-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 312 — First-class review comments: conceal markers + thread float |
| repo | parley.nvim |
| issue file | workshop/issues/000312-first-class-review-comments-conceal-markers-thread-float.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 7d1eb92a1ddaa26ac701bf1f1a46881e61b495fa..42c987c121e287af660fce4b29be6ad4b444da7a |
| command | sdlc milestone-close --issue 312 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-10-09T21:14:37-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Prior-round dispositions are checked and the M1 specs pass. I'm checking two last edge cases, then writing the verdict.

```verdict
verdict: FIX-THEN-SHIP
confidence: medium
```

M1 does what it set out to do. `comment/view.lua` is the single pure source of marker geometry. The highlighter, the cursor snap and the `<CR>` lookup all read it. Chat and markdown share one decoration step, which also skips fenced code. The viewport-bound test gives the Done-when evidence (61 layout calls on a 5000-row buffer). I ran the specs at HEAD `42c987c1` and all pass: view 33/33, codec 4/4, attach 4/4, render 5/5, and the existing `review_spec` 48/48. I didn't run the full `make test`.

The round-2 fixes for BR-3, BR-4, BR-5, BR-6 and BR-8 are in place and covered by tests. Nothing blocks. Two cheap fixes are left:
- **Clobbering:** the `concealcursor` scoping added for BR-3 remembers the window's original value once and never re-reads it. It then overwrites any later change the user or `prep_chat` makes.
- **Stale references:** some comments and an atlas line still say marker sections are painted `ParleyReviewUser`/`ParleyReviewAgent`.

### 1. Strengths
- `lua/parley/comment/view.lua:34`: `layout` reuses `_parse_marker_sections` and `_inline_code_ranges`, so there is still only one parser (ARCH-DRY). The property test covers bounds, non-overlap and UTF-8 boundaries over 3000 generated lines.
- `lua/parley/highlighter.lua:76`: `push_marker_decorations` is shared by the chat and markdown passes, which fixes a gap where chat buffers rendered no markers at all.
- `view.lua:94` `blocked_spans` models normal mode (no hidden byte) separately from insert mode (positions between bytes), and the lesson behind it is recorded in `lessons.md`.
- `tests/integration/comment_render_spec.lua:75`: a measured, falsifiable test for the viewport bound.
- `comment_attach_spec.lua:29` checks the "elsewhere" case for `concealcursor`. It would fail against the old window-wide `nvic`, so it really guards the BR-3 fix.

### 2. Critical
None.

### 3. Important
None.

### 4. Minor
- **`comment/init.lua:20` — `concealcursor` overwrites later changes.** `sync_concealcursor` reads the window's original value once (in `parley_concealcursor_base`) and never updates it.
  - If the user runs `:setlocal concealcursor=…` on a line without a marker, the next cursor move puts the old value back.
  - If a markdown buffer recorded `"nc"` first, a later chat buffer in the same window loses the `""` that `prep_chat` (`init.lua:2934`) sets on purpose.
  - Rule: parley may write `concealcursor` only when it is entering or leaving `nvic`. Re-read the original whenever the current value isn't one parley set.
- **Stale comments (2nd in `comment-drift`).** Instances:
  - `highlighter.lua:365` says marker sections are "already highlighted ParleyReviewUser".
  - The comments at `:691`–`:697` describe `🤖<…>` popping.
  - `atlas/modes/review.md:257` lists the `ParleyReviewUser`/`ParleyReviewAgent` groups as marker renderers.
  - Rule: when a diff changes what a highlight group paints, grep the group name across `lua/` and `atlas/` and update every mention in the same edit.
- **Two insert positions at one screen spot (2nd in `insert-edge-semantics`).** Because the hidden text is concealed to `""`, "before 🤖" and "start of X" (and likewise "end of X" and "after the marker") show at the same screen column. One `<Right>` press appears to do nothing, and the user can't tell whether typing goes into the anchor. Rule: where concealment collapses several insert positions onto one screen spot, choose one of them deliberately and document it.
- **Issue Spec not updated for the BR-3 change (2nd in `done-when-contract-drift`).** The issue Spec and M1 row still say `concealcursor=nvic` without the "only on marker lines" scoping, and the issue has no Revisions entry for it. The plan's Revisions has the entry, but nothing carried it into the issue.

### 5. Test coverage
- The multibyte left-snap fix is pinned by "a leftward landing backs up to a multibyte char start".
- The insert-before-marker fix is pinned by "before the 🤖 is outside the marker".
- Missing: a test that the user's own `concealcursor` change (or chat's `""`) survives a cursor move.
- Snap is only tested on single-marker lines. A test with two adjacent markers (`🤖[a]🤖[b]`) would cover crossing spans that belong to different markers.

### 6. Architecture
- **ARCH-DRY:** pass. Only the stale comments above remain.
- **ARCH-PURE:** pass. `view` is pure (it calls only the pure `vim.str_utf_start`); `attach` is a thin glue layer.
- **ARCH-PURPOSE:** pass for M1. The float and `<CR>` are M2's job.
- **ARCH-MOCK:** N/A. No external dependency.
- **ARCH-CONSTRAINTS:** pass. Rendering stays within the viewport. On a marker line each keystroke runs `layout` twice (`has_marker`, then `snap`), which is cheap but could be done once.
- **ARCH-SECURE:** N/A. Buffer text only, no secrets.
- **ARCH-ORDER:** flagged. Per-window `concealcursor` ownership is spread across implicit flags (the saved original value plus the current value) with no written rule for when parley owns the option. That gap is where the clobbering finding comes from.
- **ARCH-FUNERAL:** pass. The window variable dies with the window, `prev_col` is cleared on `WinClosed`, and the autocmd group is removed on `BufWipeout`.

### 7. Plan revisions
- Issue `## Revisions`: add the BR-3 scoping (`nvic` only on marker lines, restored on `BufLeave`) and update the Spec/M1 row text.
- Plan: note that `ParleyReviewUser`/`ParleyReviewAgent` are kept on purpose for the M2 float colors.

```findings
dispose:
  - id: BR-1
    disposition: not-addressed
    note: |
      Plan Tasks 1-3 still carry full test code and Tasks 8/10 prose enumerations; Minor, non-blocking.
  - id: BR-2
    disposition: addressed
    note: |
      Spec and Done-when now say raw + ParleyReviewBroken; the BR-3 scoping drift is raised separately.
  - id: BR-3
    disposition: addressed
    note: |
      sync_concealcursor scopes nvic to marker lines; comment_attach_spec asserts the user's value elsewhere and fails against window-wide nvic.
  - id: BR-4
    disposition: addressed
    note: |
      snap backs up via vim.str_utf_start; the multibyte leftward unit test pins it.
  - id: BR-5
    disposition: addressed
    note: |
      Insert-mode blocked_spans allow m.start; test "before the 🤖 is outside the marker".
  - id: BR-6
    disposition: addressed
    note: |
      Test renamed to "a line that starts with a quoted marker rests on its anchor" and asserts the anchor col.
  - id: BR-7
    disposition: withdrawn
    note: |
      Plan Task 4 deliberately keeps the groups for the M2 float colors; stale references raised under comment-drift.
  - id: BR-8
    disposition: addressed
    note: |
      Comment now says reversed like a quoted anchor, matching reverse=true.
findings:
  - id: new
    severity: Minor
    family: conceal-scope-widening
    title: |
      sync_concealcursor reads the window's base once and overwrites later user or prep_chat values
    detail: |
      2nd in family. Rule: parley writes concealcursor only on entering/leaving nvic and re-reads the base whenever the current value isn't one parley set. comment/init.lua:20; prep_chat's "" is lost after a markdown buffer records "nc".
  - id: new
    severity: Minor
    family: comment-drift
    title: |
      highlighter.lua:365, :691-697 and atlas/modes/review.md:257 still describe ParleyReviewUser/Agent painting marker sections
    detail: |
      2nd in family. Rule: when a diff changes what a highlight group paints, grep the group name across lua/ and atlas/ and update every mention in the same edit.
  - id: new
    severity: Minor
    family: insert-edge-semantics
    title: |
      Concealed spans collapse two insert positions onto one screen column
    detail: |
      2nd in family. Before-🤖 and anchor-start (and anchor-end and after-marker) look identical; one Right press seems to do nothing and where text goes is ambiguous. Rule: where concealment merges insert positions, pick one deliberately and document it.
  - id: new
    severity: Minor
    family: done-when-contract-drift
    title: |
      Issue Spec/M1 row say concealcursor=nvic unqualified; BR-3 scoping revision recorded only in the plan
    detail: |
      2nd in family. Rule: every plan Revisions entry that changes a decision also updates the issue's Spec/Done-when/Plan rows and adds an issue Revisions entry in the same commit.
```
