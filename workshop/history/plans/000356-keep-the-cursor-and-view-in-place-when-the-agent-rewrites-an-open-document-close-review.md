# Boundary Review — parley.nvim#356 (whole-issue close)

| field | value |
|-------|-------|
| issue | 356 — Keep the cursor and view in place when the agent rewrites an open document |
| repo | parley.nvim |
| issue file | workshop/issues/000356-keep-the-cursor-and-view-in-place-when-the-agent-rewrites-an-open-document.md |
| boundary | whole-issue close |
| milestone | — |
| window | 4c7e3dc94ec78cbae5fd05cad4715abc58e4a342..58023dd807a67782915211579177363542b767df |
| command | sdlc close --issue 356 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T11:52:24-07:00 |
| verdict | SHIP |

## Review

Diff and plan are read. Next I'll run the new unit and integration specs and check that the regression tests go red when the fix is reverted.

The specs refuse to run outside the isolated harness, so I'm switching to `make test-spec`.

```verdict
verdict: SHIP
confidence: high
```

The fix does what the issue asks. `lua/parley/view_map.lua` is a small, pure mapper built on `vim.diff`'s hunk indices. `session_sync.lua` wraps both external-write reload paths with capture and restore: the polled `reload()` that runs `silent edit!`, and the native `FileChangedShell` reload with `fcs_choice=reload`, which captures at that point and restores in `FileChangedShellPost`. I ran `make test-spec SPEC=modes/session_sync` on the pinned head and everything passed. That includes `view_map_spec` (10/10) and the four new #356 integration cases, which cover an edit above the cursor, an edit at it, an edit below it, and the native `:checktime` path, each with two windows on the buffer. The behavior matches the Spec, and the Core-concepts table matches the code. The atlas page and `traceability.yaml` were updated in the same range. README needs no change because the diff adds no keys, commands or config. I found only Minor issues, so nothing blocks SHIP.

**1. Strengths**
- `lua/parley/view_map.lua:20-34`: `locate` follows `vim.diff`'s index conventions correctly. An insertion with `a_count==0` counts as above the line only when `a_start < lnum`. A deletion with `b_count==0` lands on `b_start+1`. A position outside every hunk shifts by the running net offset. The unit tests pin each of these cases, including an insertion directly above the line and clamping at the end of the file.
- The text search in `map` (`view_map.lua:62-78`) uses plain `find`, so Lua pattern characters in the document can't break it. The cursor keeps its offset inside the matched needle, so it lands on the same character. Because the match is exact bytes, a multibyte character can't be split.
- `session_sync.lua:672,689-692`: the native-path snapshot is taken only on `fcs_choice=="reload"`, and it is restored and cleared in the existing Post handler before the `s.moving` early return. Neovim fires `FileChangedShellPost` whenever `FileChangedShell` ran, even when a deleted file means nothing was reloaded. The snapshot therefore never goes stale, and in that case it maps the unchanged text to itself.
- `session_sync.lua:326`: before restoring, it checks the window is still valid and still shows the buffer. A window closed or switched to another buffer during the reload is skipped.
- The tests check behavior from the outside: real files, real `checktime` and `edit!`, two windows, and line and column values computed by hand.

**2. Critical findings:** none.

**3. Important findings:** none.

**4. Minor findings**
- **`curswant` is always overwritten** (`session_sync.lua:328`). `view.curswant` is set to the byte column on every restore, even when the cursor's line is outside every hunk. That loses `$` stickiness, where `curswant` is MAXCOL, after any agent write. On lines with tabs or multibyte characters, the next `j`/`k` lands in the wrong column. Fix: leave `curswant` alone when `map` returns the column unchanged, or recompute it with `virtcol` after `winrestview`.
- **The diff is computed twice per window** (ARCH-DRY / ARCH-CONSTRAINTS, `view_map.lua:56,62`). `map` and `map_line` each call `hunks()` on the whole buffer, so a reload with N windows runs 2N full diffs on the 1-second poll path. Fix: compute the hunks once per restore, either by exposing a function that takes hunks or by having `restore_views` compute them and pass them in.
- **Wrong test comment** (`tests/integration/session_sync_spec.lua:381`). It says the cursor "sat on '02'", but the header has 8 lines. Doc line 20 is body line 12, so column 5 is the "1" of "12".
- **Two sibling rewrite paths are not mapped** (ARCH-PURPOSE). `lua/parley/tools/file_refresh.lua`, used when parley's built-in tools write a file, replaces the buffer lines. The review skill's round `:edit!` (`lua/parley/skills/review/init.lua:636`) reloads the buffer. Neither maps the cursor or view. Both are outside this issue's stated scope, which is external writes to documents attached via `session_sync`. They are the same kind of "rewrite under the cursor", so a follow-up could reuse `view_map` there.

**5. Test coverage notes**
- Every Done-when item is covered: edits above, at and below the cursor, two windows mapped independently, and a stable top line.
- I did not repeat the implementer's mutation check by reverting the restores. The `:checktime` case sets `POLL_MS=60000` so only the native path can catch the write, which makes it plausible that each path has its own test.
- Gaps (Minor): no test for `curswant` or virtual-column behavior, and no unit test for a short needle (one or two characters) matching inside a large hunk.

**6. Architectural notes**
- **ARCH-DRY:** pass, apart from the duplicate diff noted above.
- **ARCH-PURE:** pass. `view_map` is pure and tested without IO. `capture_views` and `restore_views` are a thin layer over the editor that is only invoked from the two reload paths.
- **ARCH-PURPOSE:** pass within the issue's scope. The two sibling paths are noted above as a possible follow-up.
- **ARCH-MOCK:** not applicable. No external binary or service is added; `vim.diff` is built into the editor.
- **ARCH-CONSTRAINTS:** pass. The work is synchronous and proportional to the buffer, and runs only on an actual reload. Avoiding the duplicate diff is cheap.
- **ARCH-SECURE:** pass. File text is used only as plain-search input and is never run as a pattern or command.
- **ARCH-ORDER:** pass. `s.views` is set together with `native_reads[buf]` inside one synchronous native check and cleared at its Post event, so there is no window between the two events where they can get out of step.
- **ARCH-FUNERAL:** pass. The snapshots exist only in memory and are cleared when restored or when the attachment is dropped.

**7. Plan revision recommendations:** none. The plan matches the code. The plan uses the shorter names `capture` and `restore`, but the Core-concepts table uses the actual names `capture_views` and `restore_views`.

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: view-restore-fidelity
    title: |
      restore_views overwrites curswant with the byte column on every reload
    detail: |
      session_sync.lua:328 sets view.curswant = pos[2] even when the cursor line is outside every hunk, so $-stickiness (MAXCOL) is lost and lines with tabs or multibyte characters get the wrong virtual column for the next j/k. Keep the original curswant when the column is unchanged, or recompute it via virtcol after winrestview.
  - id: new
    severity: Minor
    kind: defect
    family: repeated-derived-computation
    title: |
      view_map computes the full-buffer diff twice per window on each reload (ARCH-DRY)
    detail: |
      map and map_line each call hunks(old, new), so restoring N windows runs 2N vim.diff calls on the poll path. Compute the hunks once in restore_views and pass them in, or expose a variant of map/map_line that takes hunks.
  - id: new
    severity: Minor
    kind: defect
    family: test-comment-accuracy
    title: |
      at-cursor integration test comment says the cursor sat on "02"; it is on the "1" of "12"
    detail: |
      tests/integration/session_sync_spec.lua:381: the header has 8 lines, so doc line 20 is body line 12 ("line 12 of the body"), and column 5 is the "1" of "12".
  - id: new
    severity: Minor
    kind: defect
    family: rewrite-paths-map-views
    title: |
      Other agent-rewrite reload paths (file_refresh, review-skill edit!) do not map cursor/view (ARCH-PURPOSE)
    detail: |
      tools/file_refresh.lua replaces buffer lines, and skills/review/init.lua:636 runs an :edit! round reload, without view_map. Both are outside #356's stated session_sync scope; they are a candidate follow-up that can reuse view_map.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"b0e41b29-678e-493a-be81-f1f494ead2f2","repository":"github.com/xianxu/parley.nvim","issue_id":"000356","recipe":"milestone-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/5e43d11734c4c356","reviewed_head":"58023dd807a67782915211579177363542b767df","slot":"parley.nvim:4","requested_at":"2026-10-16T18:46:09.443071Z"},"phase":"finished","pid":13356,"started_at":"2026-10-16T18:46:09.703271Z","finished_at":"2026-10-16T18:52:24.128449Z","session_id":"4066e585-2f16-4213-b249-86a391cc0ab7","outcome":"returned"}] -->

---

## Re-review — 2026-10-16T15:00:20-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 356 — Keep the cursor and view in place when the agent rewrites an open document |
| repo | parley.nvim |
| issue file | workshop/issues/000356-keep-the-cursor-and-view-in-place-when-the-agent-rewrites-an-open-document.md |
| boundary | whole-issue close |
| milestone | — |
| window | b5629600f25f46ddb659e0d5651d035f93c6eff3..63020146bab5a5db78e91856fec4382d75cc5546 |
| command | sdlc close --issue 356 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T15:00:20-07:00 |
| verdict | SHIP |

## Review

Now a mutation check: put back the old curswant line and confirm the new test fails.

```verdict
verdict: SHIP
confidence: high
```

All four prior Minor findings are dealt with, and I found no Critical or Important defect in the fixes. BR-1: `restore_views` now keeps `curswant` when the mapped column hasn't changed, and works it out again with `virtcol` when it has. A new integration case covers the `$`-sticky case. I put back the old `view.curswant = pos[2]` line and that case went red; with the fix restored it passes. BR-2: the hunks are now computed once per reload with `view_map.hunks` and passed to `map` and `map_line` as an optional argument, so existing callers still work. BR-3: the test comment is corrected. BR-4: the implementer left it to a follow-up, since the original review said it was outside #356's scope. The edit to the issue file only records the close: status, log and `actual_hours`. It does not change Spec or Done-when, so the scope did not change. Running `make test-spec SPEC=modes/session_sync` on the pinned head passes every suite.

**1. Strengths**
- `lua/parley/view_map.lua:14`: `M.hunks` is now public, and `map` and `map_line` take an optional `hs` that falls back to `M.hunks(old, new)`. Existing callers keep working, which the unit specs confirm, and the reload path diffs once.
- `lua/parley/session_sync.lua:330-339`: the original `curswant` is kept whenever the column is unchanged, which covers the common case of an edit away from the cursor, so `$`-stickiness (MAXCOL) survives. The `virtcol(".") - 1` re-derivation runs after the first `winrestview`, so it reads the cursor's final position.
- `tests/integration/session_sync_spec.lua:380-388`: the new case would catch the bug. My revert check confirmed it fails without the fix.

**2. Critical findings:** none.

**3. Important findings:** none.

**4. Minor findings**
- No test covers the branch where the column moves (`virtcol` re-derivation, `session_sync.lua:337`). The new case only covers an unchanged column. Deleting the second `winrestview` is not caught by the "at the cursor's line" case, which checks only lnum and col. This is the 2nd finding in family `view-restore-fidelity`. The rule covering both: every field `restore_views` writes back (lnum, col, curswant, topline) is either carried over unchanged or derived from the mapped position. Each field should be checked on both the unchanged path and the moved path, not field by field as findings come in.

**5. Test coverage notes**
- Revert check for BR-1 done: the old line fails "a $-sticky cursor stays $-sticky across an edit above", and the fixed line passes.
- BR-2 is a performance and DRY change with no behavior change. The existing unit and integration specs still pass.

**6. Architectural notes**
- **ARCH-DRY:** pass. The duplicate diff is gone, and the hunks are computed once and shared.
- **ARCH-PURE:** pass. `view_map.hunks` stays pure. The `virtcol` and `winrestview` calls stay in the thin editor layer in `session_sync`.
- **ARCH-PURPOSE:** pass. Within #356's scope, both reload paths go through the one `restore_views`. BR-4's sibling paths were already judged out of scope and were moved to a follow-up issue.

**7. Plan revision recommendations:** none.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      curswant kept when the column is unchanged and re-derived via virtcol when it moved (session_sync.lua:330-339). The new $-sticky test fails with the old line put back and passes on head.
  - id: BR-2
    disposition: addressed
    note: |
      view_map.hunks is now public; restore_views computes it once and passes hs to map and map_line, with an optional fallback so existing callers still work.
  - id: BR-3
    disposition: addressed
    note: |
      The comment at session_sync_spec.lua:392 now says the cursor is on the "1" of "12".
  - id: BR-4
    disposition: addressed
    note: |
      Judged out of scope by the original review. The issue log records a follow-up (#358) for file_refresh and the review round's edit!. #358 is not visible in this code checkout, as the tracker head differs.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: view-restore-fidelity
    title: |
      No test covers the moved-column branch of restore_views (virtcol curswant re-derivation)
    detail: |
      2nd finding in view-restore-fidelity. Rule: every view field restore_views writes back (lnum, col, curswant, topline) is either carried over or derived from the mapped position, and each should be checked on both the unchanged and moved paths. session_sync.lua:337 (second winrestview) can be deleted without any spec going red; the at-cursor case should also assert curswant equals virtcol-1 of the new position.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"d862f487-7f64-4113-957b-5b29082c871b","repository":"github.com/xianxu/parley.nvim","issue_id":"000356","recipe":"fix-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/6f2e8b72a8946aa0","reviewed_head":"63020146bab5a5db78e91856fec4382d75cc5546","slot":"parley.nvim:4","requested_at":"2026-10-16T21:53:49.176473Z"},"phase":"finished","pid":8731,"started_at":"2026-10-16T21:53:49.378629Z","finished_at":"2026-10-16T22:00:17.786042Z","session_id":"5764ba4e-7e63-4cae-9ffe-874083e49f4c","outcome":"returned"}] -->
