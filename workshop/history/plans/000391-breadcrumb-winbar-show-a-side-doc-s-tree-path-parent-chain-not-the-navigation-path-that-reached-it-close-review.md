# Boundary Review — parley.nvim#391 (whole-issue close)

| field | value |
|-------|-------|
| issue | 391 — breadcrumb winbar: show a side doc's tree path (parent chain), not the navigation path that reached it |
| repo | parley.nvim |
| issue file | workshop/issues/000391-breadcrumb-winbar-show-a-side-doc-s-tree-path-parent-chain-not-the-navigation-path-that-reached-it.md |
| boundary | whole-issue close |
| milestone | — |
| window | db7248f16be76d951384a396fd8a1a344d093c22..ffe3c155a23a8fbe2f638f1101f670361902ae16 |
| command | sdlc close --issue 391 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | fenced |
| timestamp | 2026-10-18T23:06:04-07:00 |
| verdict | REWORK |

## Review

Inspecting the code done; now running headless checks for two suspected bugs (tree root shows no band; re-entry after frontmatter edit may not repaint).

I'm writing a probe spec to check whether a tree root shows a band and whether re-entry after a frontmatter edit repaints.

Both suspected bugs confirmed (tree root shows empty winbar; re-entry recomputes but doesn't repaint). One more probe: an unreadable parent file.

Confirmed: an unreadable parent throws E484 out of the BufEnter autocmd. Now a quick run of the issue's own specs.

One mapped test failed (`src Alt+o landing`). Checking whether it's flaky or pre-existing at base.

```verdict
verdict: REWORK
confidence: high
```

The core works. The pure `parent:` chain walk is bounded and tested, the band's three "is there a trail?" checks are now one `breadcrumb_model.visible`, and the navigation trail still drives Back and snapshot/restore. But headless probes against the pinned head show three behaviour bugs:

- **Crash on an unreadable parent.** A parent file that can't be read raises E484 out of the BufEnter autocmd. The Spec says this case should end the chain with a marker.
- **Tree roots show no winbar.** A tree root (a file with only `discussions:`) gets an empty winbar. The Revisions and the atlas both promise one segment.
- **Edits don't show on re-entry.** A frontmatter edit is recomputed when you switch back to the window, but the winbar isn't repainted. The atlas promises the edit shows on re-entry.

Docs also lag the scope change: `## Done when` is stale, and README line 226 still describes the old "Alt+o file trail" winbar and doesn't mention the new `breadcrumb.enable` key.

Done-when: stale — its third bullet ("Files outside trees keep today's trail") contradicts the operator revision. Files outside a tree now show their own repo-, home- or root-relative path. Nothing in it covers the file-path display, roots and repo-top files always showing a band, or the `breadcrumb.enable` opt-out.

### 1. Strengths
- `lua/parley/side_tree_model.lua:8-25` is pure, takes the reader as a parameter, and is bounded (cycle via `seen`, cap 32, missing parent). The counted-reads test (`tests/unit/side_tree_model_spec.lua:57-64`) checks the cost bound, not just the result.
- The display value (`shown[win]`) is kept separate from the trail (`peek`). Snapshot, restore and Back are untouched, and `document_band_spec` now asserts the trail survives behind Back (lines 478-479).
- One `breadcrumb_model.visible` replaces three duplicate gates (ARCH-DRY, done well).
- Lifecycles are bounded: `shown[win]` is cleared on WinClosed (`file_history.lua:264`) and the parse cache stops at 256 entries (ARCH-FUNERAL passes).

### 2. Critical findings
- **`lua/parley/file_history.lua:46`: an unreadable parent crashes.** `vim.fn.readfile` throws E484 on a parent that exists but can't be read (e.g. mode 000). Reproduced: `:edit B.md` errors in the BufEnter callback, `observe` aborts before `shown` and the repaint, and the winbar stays empty. This repeats on every BufEnter.
  - Fix: `local ok, lines = pcall(vim.fn.readfile, path, "", 200); if not ok then return nil end`, so the walk ends with the `missing` marker.
  - Add an integration test with an unreadable parent.
- **`lua/parley/breadcrumb_model.lua:84`: tree roots show nothing.** `chain` returns `{paths={root}}` with no labels and no marker, so `visible()` is false and the band never paints. Reproduced: opening `A.md` (`discussions:` only) gives winbar `[]`. That contradicts the Revision ("Every file, including roots … shows a winbar") and the atlas ("A tree root … show[s] one segment").
  - Fix: make a tree value visible, e.g. have `chain` set `tree = true` and have `visible` accept it, or give the value `labels`.
  - Add a test that opens A.

### 3. Important findings
- **`file_history.lua:89-92`: re-entry doesn't repaint.** `shown[win]` is recomputed on every visit, but a repaint happens only if the path changed or the presentation proof differs. Reproduced: edit B's `parent:` to a missing file, leave the window, then come back. `display()` now returns `marker="missing"` but the winbar still reads `A › B` (ARCH-ORDER: the cached value and the painted band have drifted).
  - Fix: repaint when `not vim.deep_equal(old.value, new.value)`.
  - Test re-entry to the same buffer. The current test switches buffers, which happens to repaint through BufWinEnter.
- **`## Done when` is stale.** See the judgement above.
- **README is out of date.** README.md:226 still says the winbar combines the lock cell "with the current window's Alt+o file trail", and the new config key `breadcrumb = { enable = false }` isn't documented.
- **Parsing logic sits inside the IO adapter (ARCH-PURE / ARCH-DRY).** `read_node` (`file_history.lua:47-57`) does the frontmatter key scan, quote stripping and relative `parent:` resolution, and none of it is unit-tested. This is where quoting and path bugs would live.
  - Extract a pure `side_tree_model.parse(lines, dir)` and unit-test it (quotes, absolute vs relative, no closing `---`, indented keys).
  - Leave stat, the cache and readfile in the adapter.
  - Consider reusing `chat_parser`'s header key/value parser instead of a new pattern.

### 4. Minor findings
- The Plan text says `trees[win]` and "else the trail"; the code uses `shown[win]` and falls back to the file path, not the trail.
- `readfile(path, "", 200)` limits lines, not bytes, so a huge parent file with no newlines is read whole.
- `path_display` calls `vim.fs.root` and `expand("~")` on every visit without caching. Cheap, but repeated work.
- `M.display` reads global `package.loaded["parley"].config` from inside `file_history`. Injecting the option would be cleaner.

### 5. Test coverage notes
- `make test-spec SPEC=ui/breadcrumb`: the new unit specs pass. `file_history_spec` "commits the successful src Alt+o landing to the trail" fails 3 of 3 runs at head, and also 3 of 3 at base `db7248f`. So it's an existing problem in this environment, not caused by this diff.
- Missing coverage:
  - an unreadable parent through the real reader (not the fake);
  - opening a tree root;
  - same-buffer re-entry after a frontmatter edit;
  - the frontmatter parser's edge cases.

### 6. Architectural notes
- ARCH-DRY: flagged as part of the ARCH-PURE finding above (possible duplicate of the existing header key/value parser); `visible` consolidation is good.
- ARCH-PURE: flagged (`read_node`).
- ARCH-PURPOSE: flagged. The root case falls short of the revision's "every file shows a winbar".
- ARCH-MOCK: passes. There are no external binaries, and the reader is injected into the pure chain.
- ARCH-CONSTRAINTS: passes. Depth is capped at 32, the parse cache at 256, and reads are counted in tests.
- ARCH-SECURE: flagged. Frontmatter from disk is untrusted input, and a read failure crashes instead of degrading to the `missing` marker. Statusline text is still escaped.
- ARCH-ORDER: flagged. The display cache and the painted band can drift (re-entry repaint).
- ARCH-FUNERAL: passes.

### 7. Plan revision recommendations
- Rewrite `## Done when` bullet 3 to say: non-tree files show their own path; tree roots and repo-top files show one segment; `breadcrumb.enable = false` opts out; Back is unchanged.
- Update the Plan's file_history bullet: `shown[win]` instead of `trees[win]`, and `display` falls back to the file path, not the trail.

```findings
findings:
  - id: new
    severity: Critical
    kind: defect
    family: untrusted-file-read-must-degrade
    title: |
      Unreadable parent file throws E484 out of the BufEnter autocmd instead of ending the chain with the missing marker
    detail: |
      file_history.lua:46 calls vim.fn.readfile unguarded; reproduced with a mode-000 parent: :edit of the child errors in observe, shown/repaint are skipped and the winbar is empty, on every BufEnter. pcall the read and return nil so side_tree_model marks missing; add a test.
  - id: new
    severity: Critical
    kind: defect
    family: display-contract-every-file-visible
    title: |
      A side-doc tree root (discussions only) shows no winbar, contrary to the Revision and atlas
    detail: |
      side_tree_model.chain returns one path with no labels or marker, so breadcrumb_model.visible (line 84) is false and the band never paints; reproduced: opening A.md gives winbar empty. Make tree values visible (tree flag or labels) and add a root-open test.
  - id: new
    severity: Important
    kind: defect
    family: display-cache-repaint-drift
    title: |
      Frontmatter edit is recomputed on window re-entry but not repainted, contrary to the atlas claim
    detail: |
      file_history.lua:89-92 refreshes shown[win] on every visit but repaints only when the path or presentation proof changes; reproduced: after editing parent to a missing file and WinEnter back, display() reports marker=missing while the winbar still reads A › B. Repaint when the shown value changes; test same-buffer re-entry.
  - id: new
    severity: Important
    kind: defect
    family: done-when-tracks-revisions
    title: |
      Done when is stale: says files outside trees keep today's trail, but the revision shows their own path
    detail: |
      Done when does not cover file-path display, always-visible roots and repo-top files, or the breadcrumb.enable opt-out added in Revisions.
  - id: new
    severity: Important
    kind: defect
    family: readme-tracks-user-surface
    title: |
      README still describes the winbar as the Alt+o file trail and omits the breadcrumb.enable config key
    detail: |
      README.md:226 is stale after this change, and the new user config key breadcrumb = { enable = false } is not documented.
  - id: new
    severity: Important
    kind: defect
    family: parsing-in-io-adapter
    title: |
      Frontmatter parsing and parent resolution live inside the IO adapter read_node and are not unit-tested (ARCH-PURE)
    detail: |
      file_history.lua:47-57 mixes a key scan, quote stripping and relative-path resolution with stat, cache and readfile. Extract a pure parse(lines, dir) into side_tree_model with unit tests, and consider reusing chat_parser's header key/value parser (ARCH-DRY).
  - id: new
    severity: Minor
    kind: defect
    family: plan-matches-code
    title: |
      Plan names trees[win] and a trail fallback; the code uses shown[win] and falls back to the file path
    detail: |
      Add a Revisions entry or edit the Plan bullet so it matches file_history.lua.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"bfbc4529-a015-4a46-9767-95cec9b97c51","repository":"github.com/xianxu/parley.nvim","issue_id":"000391","recipe":"milestone-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/245f86cdcf6be105","reviewed_head":"ffe3c155a23a8fbe2f638f1101f670361902ae16","slot":"parley.nvim:3","requested_at":"2026-10-19T06:01:09.05184Z"},"phase":"finished","pid":73548,"started_at":"2026-10-19T06:01:09.298025Z","finished_at":"2026-10-19T06:06:03.615444Z","session_id":"bbd1dfbf-0ba5-468a-a452-64c445d8bb04","outcome":"returned"}] -->

---

## Re-review — 2026-10-18T23:18:12-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 391 — breadcrumb winbar: show a side doc's tree path (parent chain), not the navigation path that reached it |
| repo | parley.nvim |
| issue file | workshop/issues/000391-breadcrumb-winbar-show-a-side-doc-s-tree-path-parent-chain-not-the-navigation-path-that-reached-it.md |
| boundary | whole-issue close |
| milestone | — |
| window | db7248f16be76d951384a396fd8a1a344d093c22..0c9ab358822e20670a58467ad050217d830ff25c |
| command | sdlc close --issue 391 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | fenced |
| timestamp | 2026-10-18T23:18:12-07:00 |
| verdict | SHIP |

## Review

Running the affected spec files now.

Tests ran; checking which one failed.

Consistent failure; checking whether base also fails it.

The `src` failure also happens at base, so this diff didn't cause it. Next: running the other changed integration specs.

Now verifying each claimed fix by reverting it and checking that its test goes red.

All three fixes go red when reverted. Now checking helper semantics and config merging for new issues.

```verdict
verdict: SHIP
confidence: high
```

All seven round-1 findings are fixed, and I found nothing new that blocks the gate. For the three behaviour fixes (BR-1/2/3) I reverted each fix in the disposable checkout, and each one turned its regression test red. The prose fixes (BR-4/5/7) are in the issue's Done-when/Revisions sections and in `README.md`, and they match the code. The parsing was moved into the pure `side_tree_model.parse`, which now has unit tests (BR-6). The `ui/breadcrumb` and `modes/session_sync` spec groups pass, with one exception: `file_history_spec` "commits the successful src Alt+o landing" fails the same way at base `db7248f1`. It comes from the environment and predates this diff. Only three Minor notes remain, and none of them blocks.

1. **Strengths**
   - `breadcrumb_model.visible` (`lua/parley/breadcrumb_model.lua:164`) is now the single gate used by `project`, `document_band_model.compose:37` and `document_band.refresh:177`. Before, three separate "is there a trail?" checks could drift apart (ARCH-DRY).
   - `side_tree_model.chain` is pure, with an injected reader. It is bounded by a cap of 32, cycle detection via `seen`, and a missing marker. Counted-read tests check the cost: CAP+1 reads.
   - `read_node` checks `stat.type ~= "file"` before `readfile`, so a `parent:` pointing at a FIFO or device can't block BufEnter. Reads are guarded by `pcall` (`lua/parley/file_history.lua:49`).
   - The display value (`display`) stays separate from the trail (`peek`). Snapshot, restore and Back are untouched, and the integration test checks this (`snapshot(0).paths == {C2, C1}`, then Back returns to C2).
   - Lifecycle is handled: `shown[win]` is cleared on WinClosed, and the parse cache is capped at 256 entries and resets when full.

2. **Critical findings:** none.

3. **Important findings:** none.

4. **Minor findings**
   - `file_history.lua:35`: `helpers.buffer_for(path, true)` runs before the cache check. It walks every buffer and calls `vim.fn.resolve` on each one, for every node in the chain, on every BufEnter. The cost is O(buffers × (depth+1)), but the plan's hot-path note only counts frontmatter reads (ARCH-CONSTRAINTS).
   - The `~` and `/` fallbacks of `path_value` / `path_display` have no tests. I probed them by hand and they are correct: `etc › hosts`, `~ › a › b`.
   - `side_tree_model.parse` checks `lines[1] == "---"` exactly, while `find_header_end` trims whitespace. A trailing `# comment` on a `parent:` line also becomes part of the path, so the chain shows the missing marker (visible, not silent).

5. **Test coverage notes**
   - Revert checks:
     - BR-1: removing `pcall` gives E484 at `file_history_spec.lua:142`.
     - BR-2: restoring the old `>1` visibility rule fails lines 61 and 122.
     - BR-3: removing the `moved` repaint fails line 133.
   - The opt-out test changes `parley.config.breadcrumb.enable` and only resets it at the end of the test. If an assertion fails partway through, the change leaks into later tests.
   - The base-failing `src` Alt+o test is unrelated to #391, but it should get its own issue.

6. **Architectural notes (one line per principle)**
   - ARCH-DRY pass: the three visibility gates now share one helper.
   - ARCH-PURE pass: parsing and the chain walk are pure; `resolve`, `stat` and the cache stay in the thin adapter.
   - ARCH-PURPOSE pass: every file window gets its value from `display()`, and no consumer still renders the trail.
   - ARCH-MOCK: does not apply. The only dependency is the local filesystem, which tests exercise through real temp files. No external binary or service is involved.
   - ARCH-CONSTRAINTS pass, with the Minor note above.
   - ARCH-SECURE pass: an unreadable or non-regular parent becomes a visible `?` marker, never an error.
   - ARCH-ORDER pass: `shown[win]` changes only in `observe`, `display` re-checks the path against the trail leaf, and re-entry ordering is tested.
   - ARCH-FUNERAL pass: the cache is capped, and per-window state dies on WinClosed.

7. **Plan revision recommendations:** none. The round-1 Revisions entry already reconciles `trees[win]` → `shown[win]` and the trail → own-path fallback.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      pcall(readfile) at file_history.lua:49; reverting it makes file_history_spec.lua:142 fail with E484.
  - id: BR-2
    disposition: addressed
    note: |
      visible() is now paths>0; reverting to >1 fails file_history_spec lines 61 and 122 (root shows " A").
  - id: BR-3
    disposition: addressed
    note: |
      observe repaints when shown[win] changes; removing the moved check fails file_history_spec.lua:133.
  - id: BR-4
    disposition: addressed
    note: |
      Done when now lists own-path display, roots and repo-top files, the unreadable-parent and re-entry behaviour, and the opt-out.
  - id: BR-5
    disposition: addressed
    note: |
      README.md:226 describes the tree path or own path and documents breadcrumb = { enable = false }, which matches config.lua:704.
  - id: BR-6
    disposition: addressed
    note: |
      side_tree_model.parse is pure with unit tests (side_tree_model_spec); not reusing chat_parser is justified in Revisions (top-level keys only).
  - id: BR-7
    disposition: addressed
    note: |
      Round-1 Revisions entry records shown[win] and the own-path fallback.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: hot-path-cost-matches-budget
    title: |
      read_node scans every buffer with resolve() before the cache check, on each node of every BufEnter
    detail: |
      file_history.lua:35 calls helpers.buffer_for for each chain node. That walks all buffers and calls vim.fn.resolve on each, so the cost is O(buffers x (depth+1)) per event, while the plan's hot-path budget counts only frontmatter reads (ARCH-CONSTRAINTS). Consider one resolved name-to-buffer map per observe.
  - id: new
    severity: Minor
    kind: defect
    family: untested-fallback-branches
    title: |
      path_value's home (~) and filesystem-root (/) fallbacks have no test
    detail: |
      Only the .git-relative branch is covered, in file_history_spec. I probed path_value directly and the other two branches are correct today; a short unit test in breadcrumb_model_spec would keep them that way.
  - id: new
    severity: Minor
    kind: defect
    family: frontmatter-parse-consistency
    title: |
      side_tree_model.parse checks the opening --- exactly while find_header_end trims it; a trailing comment on parent: is kept as part of the path
    detail: |
      A file whose opening line is "--- " is treated as having no tree, and "parent: x.md # note" resolves to a path that doesn't exist, which shows the missing marker. Both cases are visible, not silent.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"7b2d3e49-5f6f-4f5f-a4ba-778d54a4b5b7","repository":"github.com/xianxu/parley.nvim","issue_id":"000391","recipe":"milestone-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/a4adf50dc5c0eefc","reviewed_head":"0c9ab358822e20670a58467ad050217d830ff25c","slot":"parley.nvim:3","requested_at":"2026-10-19T06:10:57.319906Z"},"phase":"finished","pid":15150,"started_at":"2026-10-19T06:10:57.574476Z","finished_at":"2026-10-19T06:18:11.566298Z","session_id":"2e93f784-95d5-4fa8-890f-8d55a829e2c3","outcome":"returned"}] -->
