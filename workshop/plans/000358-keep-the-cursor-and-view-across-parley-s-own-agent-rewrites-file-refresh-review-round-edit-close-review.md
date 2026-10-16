# Boundary Review — parley.nvim#358 (whole-issue close)

| field | value |
|-------|-------|
| issue | 358 — Keep the cursor and view across parley's own agent rewrites (file_refresh, review round edit!) |
| repo | parley.nvim |
| issue file | workshop/issues/000358-keep-the-cursor-and-view-across-parley-s-own-agent-rewrites-file-refresh-review-round-edit.md |
| boundary | whole-issue close |
| milestone | — |
| window | 7caca2c80ada693f2e0830bed2879f19fd196713..7ff97e390ce4d3f132cbcd87f118c8831f113a8b |
| command | sdlc close --issue 358 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T16:45:23-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Reviewing the diff is done; now I'm running the new specs to confirm they pass.

I'll add a throwaway make target in the disposable checkout to run single files.

Now mutation checks: remove each restore and confirm the tests go red.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The change does what the issue asks. `capture_views` and `restore_views` moved out of `session_sync` into `lua/parley/window_views.lua` without changes. Both of parley's remaining whole-buffer agent rewrites now go through it: `tools/file_refresh.complete` and `skill_invoke`'s `source_completion`. Both restore only after a confirmed apply. I ran the affected specs at head and all pass: the 15 files mapped to `modes/session_sync` (including `session_sync_spec` 63, `session_sync_native_spec` 64 and `window_views_spec` 2), `tool_file_refresh_spec` 21/21 and `skill_invoke_spec` 43/43. I also removed each restore in this throwaway checkout and re-ran. Without the `file_refresh` restore, both "lines added above" cases fail (plain buffer and attached document). Without the `skill_invoke` restore, its new case fails. That confirms the tests catch the bug they guard. One thing stands between this and SHIP: a `## Done when` clause only half-met. The review-round path has no "edit below leaves cursor and top line exact" test. The Done-when text also still says every test fails without the restore, which the Log itself shows is untrue for the below cases.

1. **Strengths**
   - `lua/parley/window_views.lua:14-44` is the #356 pair moved verbatim (the diff is a pure move). `session_sync` calls it at both reload sites (`session_sync.lua:320,326,664,683`), and the existing session_sync suites pass with no test edits. This is a clean ARCH-DRY lift.
   - `file_refresh.lua:74-77` restores only on the `matches()` branch. A refused or reconciling refresh never moves the operator's cursor, and the "refused" test pins this (`tool_file_refresh_spec.lua:152-160`).
   - The file_refresh tests use two windows and cover both plain-buffer and attached-document modes, so both branches of the pcall (`apply_user` and `replace_all_lines`) are exercised.
   - The `skill_invoke_spec` case drives a real `propose_edits` exchange, so it reaches `source_completion` instead of a stub. The Log correctly explains why `skill_invoke_review_spec` couldn't be used.
   - `window_views_spec` covers both curswant paths (column moved vs. `$`-sticky).

2. **Critical findings:** none.

3. **Important findings**
   - **`tests/integration/skill_invoke_spec.lua:409-430`: the review-round path has no "edit below" case.** Done-when says "for each path, an edit above the cursor shifts it, and an edit below leaves the cursor and the top line exactly in place." `file_refresh` has both cases. `skill_invoke`'s `source_completion` has only the above case.
     - Fix: add a sibling case where `propose_edits` appends after `line 60` and assert `{30, 2, 25}` stays exact.
     - Family sweep for this window: the session_sync paths are covered by #356's suites; the `file_refresh` below case exists at `tool_file_refresh_spec.lua:144-151`. `skill_invoke` is the only gap.

4. **Minor findings**
   - Two comments still say the review round reloads with `:edit!`: `lua/parley/skills/review/init.lua:632` and `lua/parley/skills/review/projection.lua:19`. The reload is actually `skill_invoke`'s whole-buffer `apply_user`. The issue's Problem section repeats the same claim. Both comments predate this diff, but #358 is the change that pinned down the real mechanism.
   - `skill_invoke.lua:540,543` calls `require('parley.window_views')` inline twice. `file_refresh.lua:6` hoists it to a local. Hoisting it would match.

5. **Test coverage notes**
   - The mutation checks above confirm the regression tests go red without each restore. The append-below cases pass with or without the restore. That is expected (a whole-buffer replace already keeps that view), and the Log says so. They guard against the restore disturbing the view rather than proving it is needed.
   - The ARCH-PURPOSE shadow-sweep turned up no other agent-driven whole-buffer rewrites. I checked every `region=1` `apply_user` and `replace_all_lines` call:
     - `chat_finder`, `init.lua:2239,4585,4602`, `spell_source`, `interview`, `paste_image` and `highlighter` replace small captured regions on user actions.
     - `cliproxy_login_ui` and `diag_display` rewrite parley-owned float or scratch buffers.

6. **Architectural notes**
   - **ARCH-DRY: pass.** There is one helper and all four call sites derive from it. No copy is left in `session_sync`.
   - **ARCH-PURE: pass.** The pure mapping stays in `view_map`. `window_views` is a thin window-IO shell, and its spec is correctly in `tests/integration/`.
   - **ARCH-PURPOSE: pass.** Both remaining rewrites named in the issue are wired, and the sweep found no deferred consumer.

7. **Plan revision recommendations**
   - Add a `## Revisions` entry: "Done when's 'Each test fails without the restore' applies to the edit-above cases only. The edit-below cases pass with or without the restore, because a whole-buffer replace already keeps that view; they guard that the restore doesn't disturb it." The Log records this correction, but the Done-when text still claims the original.
   - Correct the Problem section's "the review round reloads its document with `:edit!`" to the actual mechanism: `skill_invoke` `source_completion` → `apply_user`, which the Plan already states.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: done-when-clause-both-states
    title: |
      Review-round path (skill_invoke source_completion) lacks the edit-below test that Done-when requires for each path
    detail: |
      Done-when requires, for each path, an edit-above case and an edit-below case that leaves the cursor and top line exact. tool_file_refresh_spec has both; skill_invoke_spec.lua:409-430 has only the insert-above case. Add a propose_edits case that appends after line 60 and asserts the view stays at lnum 30, col 2, topline 25. That is the only missing instance in this window; the session_sync paths are covered by the 356 suites.
  - id: new
    severity: Minor
    kind: defect
    family: stale-doc-claim
    title: |
      Comments and issue text still say the review round reloads with :edit!, but it is skill_invoke's whole-buffer apply_user
    detail: |
      lua/parley/skills/review/init.lua:632 and lua/parley/skills/review/projection.lua:19 describe the round's own :edit! reload. The issue's Problem section repeats it. Done-when also still says each test fails without the restore, which the Log shows is false for the edit-below cases. Reword all of these.
  - id: new
    severity: Minor
    kind: defect
    family: module-require-style
    title: |
      skill_invoke.lua requires parley.window_views inline twice; file_refresh hoists it to a local
    detail: |
      skill_invoke.lua:540 and :543. Hoist it to a local, as file_refresh.lua:6 does.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"051b08cc-a6a8-4f88-a3b3-44847de82784","repository":"github.com/xianxu/parley.nvim","issue_id":"000358","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/6242c09c40a1aadf","reviewed_head":"7ff97e390ce4d3f132cbcd87f118c8831f113a8b","slot":"parley.nvim:4","requested_at":"2026-10-16T23:41:53.279748Z"},"phase":"finished","pid":48031,"started_at":"2026-10-16T23:41:53.516472Z","finished_at":"2026-10-16T23:45:23.12301Z","session_id":"4d48a41c-a8a2-49f2-ac6f-ea7f0a6dadfb","outcome":"returned"}] -->

---

## Re-review — 2026-10-16T16:48:37-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 358 — Keep the cursor and view across parley's own agent rewrites (file_refresh, review round edit!) |
| repo | parley.nvim |
| issue file | workshop/issues/000358-keep-the-cursor-and-view-across-parley-s-own-agent-rewrites-file-refresh-review-round-edit.md |
| boundary | whole-issue close |
| milestone | — |
| window | 7caca2c80ada693f2e0830bed2879f19fd196713..b31928c1200e7b0e3932dbbcf2d2c3f434a85c2d |
| command | sdlc close --issue 358 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T16:48:37-07:00 |
| verdict | SHIP |

## Review

Running the affected test files now, then a mutation check on skill_invoke's restore.

```verdict
verdict: SHIP
confidence: high
```

All three findings from round 1 are fixed, and I checked each one in the code, not just in the commit messages. The new review-round edit-below test exists, and the affected suites pass at head: `skill_invoke_spec`, `tool_file_refresh_spec`, `window_views_spec` and `session_sync_spec`. I also removed `skill_invoke`'s `Views.restore` in the throwaway checkout. Only "keeps the cursor and top line on their text when the round inserts above" then failed. That means the edit-above case is real evidence for the restore. The edit-below case passes either way, as the Revisions entry now says openly. I restored the checkout afterwards and it is clean. I found nothing new that blocks shipping.

Done-when: current. Its clauses cover what the diff builds: one shared helper, both paths, and an edit-above and edit-below test per path. The one overstated clause ("each test fails without the restore") is corrected by the round-1 `## Revisions` entry, and the Log matches what I measured.

1. **Strengths**
   - `lua/parley/window_views.lua` is #356's pair moved over unchanged (ARCH-DRY passes). `session_sync` now calls it at both reload paths, and the old local copies are gone. The Core concepts table matches the code row for row.
   - `file_refresh.lua:56,77`: views are captured before the apply and restored only on the branch where `matches()` holds. A refused refresh is tested and leaves Neovim's own cursor adjustment alone (`tool_file_refresh_spec`).
   - The `file_refresh` tests run in two windows, against both a plain buffer and an attached document, so each `apply_user` / `replace_all_lines` branch is reached.
   - `window_views_spec` pins both curswant paths: a column the text moved, and a `$`-sticky column.
2. **Critical:** none.
3. **Important:** none.
4. **Minor:** none new. The issue title still contains "review round edit!", but it is the issue's own slug and title, so I am not raising it.
5. **Test coverage:** each path now has an edit-above and an edit-below case. Removing the restore makes the edit-above cases fail (I confirmed this for `skill_invoke`; the Log reports the same for `file_refresh`). The edit-below cases only guard that the restore doesn't disturb a view that was already correct.
6. **Architecture:**
   - ARCH-DRY: pass. There is one helper with three consumers.
   - ARCH-PURE: pass. The pure mapping stays in `view_map`, and `window_views` is a thin window-IO wrapper around it.
   - ARCH-PURPOSE: pass. Every whole-buffer agent rewrite path named in the issue uses the helper: `session_sync` (×2), `file_refresh` and `skill_invoke` `source_completion`.
7. **Plan revisions:** none needed beyond the round-1 entry that is already there.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      skill_invoke_spec "leaves the cursor and top line exact when the round appends below" added and passes at head; the mutation run shows the above case goes red without Views.restore.
  - id: BR-2
    disposition: addressed
    note: |
      init.lua:632 and projection.lua:19 now name skill_invoke's whole-buffer apply_user; the Problem section is corrected; the Revisions entry scopes "fails without the restore" to the edit-above cases.
  - id: BR-3
    disposition: addressed
    note: |
      skill_invoke.lua:32 hoists local Views=require('parley.window_views'), matching file_refresh.lua:6.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"cefd60af-15dd-47cf-ae79-1e74a4478622","repository":"github.com/xianxu/parley.nvim","issue_id":"000358","recipe":"small-diff-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/f5313420c74d8a62","reviewed_head":"b31928c1200e7b0e3932dbbcf2d2c3f434a85c2d","slot":"parley.nvim:4","requested_at":"2026-10-16T23:47:22.971719Z"},"phase":"finished","pid":1285,"started_at":"2026-10-16T23:47:23.21472Z","finished_at":"2026-10-16T23:48:36.38153Z","session_id":"4c700dac-2eba-40bb-bf40-3ab8769bca2b","outcome":"returned"}] -->
