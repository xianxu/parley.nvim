# Boundary Review — parley.nvim#397 (whole-issue close)

| field | value |
|-------|-------|
| issue | 397 — breadcrumb tree path: trailing comment on parent: breaks the chain; per-node buffer scan; untested path fallbacks |
| repo | parley.nvim |
| issue file | workshop/issues/000397-breadcrumb-tree-path-trailing-comment-on-parent-breaks-the-chain-per-node-buffer-scan-untested-path-fallbacks.md |
| boundary | whole-issue close |
| milestone | — |
| window | a1b0a08b07d10b9902680e6aabba57d73c634601..d1dfab038d0bd6c595b903a8fe2f4dd965988f60 |
| command | sdlc close --issue 397 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | fenced |
| timestamp | 2026-10-19T01:14:23-07:00 |
| verdict | REWORK |

## Review

I've read the diff; next I'm running the three changed spec files.

Getting the test harness to run under the make environment; trying a simpler invocation.

```verdict
verdict: REWORK
confidence: high
```

The three code changes work, but the new path-display test fails at head, so the third Done-when clause is not met. Here is what I checked:

- **Comment-tolerant `parent:` parse (`side_tree_model.lua:9-25`).** It is correct, and its unit spec passes.
- **Buffer index for the chain walk (`helper.loaded_buffer_index` + `file_history.read_node`).** It is correct. I ran a revert check: with the old per-node `buffer_for` restored, the new depth test fails with 10 scans against 3. With the fix in place it passes.
- **Path-form selection.** It was moved into the pure `breadcrumb_model.located`. The new assertion at `tests/unit/breadcrumb_model_spec.lua:82` fails deterministically. `located("/h/r/lua/x.lua", …)` produces `lua › x.lua`, and the test expects `lua › x`. Only `.md` suffixes are stripped; the test 9 lines above already pins `x.lua`. That assertion aborts the `it` block, so the `~`, `/` and `/hx` lookalike assertions on lines 83-85 never run. The `~` and `/` branches are therefore still untested, and the issue Log's claim that they were "unit-tested" is wrong.

1. **Strengths**
   - `helper.lua:713-716`: `buffer_key` is lifted out and shared by `buffer_for` and `loaded_buffer_index`, so both use the same key with first-match-wins (ARCH-DRY pass).
   - `file_history.lua:65-68`: one index per chain computation. It is reachable on every observe, and the integration test counts `nvim_list_bufs` calls across depths 1 and 8, which is a good test of how cost grows rather than of the implementation.
   - `side_tree_model.lua:9-11`: the `scalar` edge cases are well chosen and pinned. `a#b.md` keeps its `#`, `parent: # none` gives no parent, a quoted value followed by a comment works, and so does a tab before `#`.
   - `breadcrumb_model.located` makes path-form choice pure and testable. The IO shell (`path_display`) is now two lines (ARCH-PURE pass).
   - `read_node` looks up `buffers[path]` with the raw path, which is safe: the leaf is resolved in `observation`, and every parent is resolved at `file_history.lua:52`, so keys always line up with `buffer_key`.

2. **Critical**
   - `tests/unit/breadcrumb_model_spec.lua:82`: the expected string `"lua › x"` is wrong. The actual value is `"lua › x.lua"`. Fix by expecting `"lua › x.lua"`, or by using `/h/r/lua/x.md`. Then re-run to confirm lines 83-85 pass. Other assertions in this window that expect stripped labels: line 83 (`plan.md` gives `plan`, correct), line 84 (`x.md` gives `x`, correct), line 85 (`y.md` gives `y`, correct). Only line 82 uses a non-`.md` leaf.

3. **Important**
   - None beyond the Critical item.

4. **Minor**
   - `tests/integration/file_history_spec.lua:165`: the winbar assertion is loose. `"0 › 1 › 2"` would also match a full, unelided depth-8 chain, so it doesn't pin which chain shows. Assert the exact depth-8 projection instead.
   - The issue's `## Plan` is still a bare `- [ ]`. That is acceptable for the quick flow, but the Log is the only record of what was done.
   - The YAML single-quote escape `'it''s.md'` parses to `it`. This was already wrong before the change and is very much an edge case.

5. **Test coverage**
   - `side_tree_model_spec`: 6/6 pass.
   - `breadcrumb_model_spec`: 1 failure, the Critical above.
   - `file_history_spec`: 46 pass and 1 fails ("commits the successful src Alt+o landing", line 350). That failure happens at base `a1b0a08b` too: in this review checkout, src link targets resolve outside the temp dir. It is not caused by this diff.
   - The new depth test fails with the fix reverted, as noted above.
   - The trailing-comment test would fail against base `parse`, which kept the `# note` in the value.

6. **Architecture**
   - **ARCH-DRY: pass.** `buffer_key` is shared, and `located` replaces the inline branching in `path_display`.
   - **ARCH-PURE: pass.** `located` and `scalar` are pure, and the IO stays in `file_history`.
   - **ARCH-PURPOSE: flag.** The third Done-when clause, coverage of the `~` and `/` branches, is not delivered because the block aborts before reaching them. The first two clauses are delivered.
   - **ARCH-EVOLVE: pass.** No persisted format is written. The frontmatter read now drops a trailing comment after whitespace, which matches YAML, and the atlas documents it.
   - The atlas is updated at `atlas/ui/breadcrumb.md:3`. No README surface changed.

7. **Plan revisions**
   - Fix the Log line "unit-tested for root, home, absolute and a home-prefix lookalike". It is only true once line 82 is corrected and the block passes.

```findings
findings:
  - id: new
    severity: Critical
    kind: defect
    family: test-expectation-unverified
    title: |
      New located() test fails at head, so the home and absolute branches never run
    detail: |
      tests/unit/breadcrumb_model_spec.lua:82 expects "lua › x" but located("/h/r/lua/x.lua", "/h/r", "/h") projects "lua › x.lua", since only .md is stripped (line 75 already pins x.lua). The failing assert aborts the it-block, so lines 83-85 (the ~ and / branches plus the /hx lookalike) never run, and Done-when clause 3 is unmet. Fix: expect "lua › x.lua" (or use x.md) and re-run. The other located() assertions in this window (lines 83, 84, 85) use .md leaves and are correct.
  - id: new
    severity: Minor
    kind: defect
    family: assertion-too-loose
    title: |
      Depth-scan test winbar assertion accepts either chain form
    detail: |
      tests/integration/file_history_spec.lua:165 ORs "0 › 1 › 2" with the elided form. The first substring also matches a full depth-8 chain, so the assertion does not pin which chain is displayed. Assert the exact depth-8 projection instead.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"226861a8-8c70-4a34-b23f-344278f68270","repository":"github.com/xianxu/parley.nvim","issue_id":"000397","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/426575a874c6971f","reviewed_head":"d1dfab038d0bd6c595b903a8fe2f4dd965988f60","slot":"parley.nvim:3","requested_at":"2026-10-19T08:06:45.543908Z"},"phase":"finished","pid":93383,"started_at":"2026-10-19T08:06:45.66995Z","finished_at":"2026-10-19T08:14:22.349562Z","session_id":"8545f63f-3a26-497d-b798-f195d5de6669","outcome":"returned"}] -->

---

## Re-review — 2026-10-19T01:18:10-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 397 — breadcrumb tree path: trailing comment on parent: breaks the chain; per-node buffer scan; untested path fallbacks |
| repo | parley.nvim |
| issue file | workshop/issues/000397-breadcrumb-tree-path-trailing-comment-on-parent-breaks-the-chain-per-node-buffer-scan-untested-path-fallbacks.md |
| boundary | whole-issue close |
| milestone | — |
| window | a1b0a08b07d10b9902680e6aabba57d73c634601..555ad10936db22758652a4a29f0a2ce861a8b1de |
| command | sdlc close --issue 397 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | fenced |
| timestamp | 2026-10-19T01:18:10-07:00 |
| verdict | SHIP |

## Review

Running the three changed spec files through make to verify the round-1 fixes.

```verdict
verdict: SHIP
confidence: high
```

Both findings from round 1 are fixed, and I re-ran the tests to confirm. In `make test-spec SPEC=ui/breadcrumb`, `breadcrumb_model_spec` now runs and passes 13/13, `side_tree_model_spec` passes 6/6, and the new depth test in `file_history_spec` passes with the exact 9-segment chain. One test in that file fails: "commits the successful src Alt+o landing". It is not caused by this diff; the first review saw it fail at the base commit `a1b0a08b` too, because of how this review checkout resolves paths. I also checked that the `located()` test catches real breakage. I deleted the home branch from `breadcrumb_model.located`, and the test failed at `breadcrumb_model_spec.lua:83`. I then restored the file, and the tree is clean. All three Done-when clauses are now met and each has a passing test.

1. **Strengths**
   - `helper.lua:713`: `buffer_key` is shared by `buffer_for` and `loaded_buffer_index`, and both keep the first match. **ARCH-DRY: pass.**
   - `breadcrumb_model.located` is pure and its tests cover the root, home, absolute and `/hx` lookalike cases, which leaves `path_display` as a two-line IO wrapper. **ARCH-PURE: pass.**
   - `file_history_spec.lua:146-167` counts `nvim_list_bufs` calls at depth 1 and depth 8, so it tests that cost doesn't grow with depth rather than restating the code. The first review confirmed it fails when the fix is reverted.
   - The new mapping in `atlas/traceability.yaml` makes the targeted `ui/breadcrumb` run include the model spec. That is the root cause of round 1's missed failure, and `lessons.md` records it.
2. **Critical:** none.
3. **Important:** none.
4. **Minor**
   - The issue Log has the `### 2026-10-19` heading twice. It is in the tracker only, so there is no runtime effect.
5. **Test coverage**
   - Each clause has a test that passes at head. The trailing-comment cases and the padded opener are in `side_tree_model_spec`. The scan count not growing with depth is in `file_history_spec`. The `~` and `/` branches are in `breadcrumb_model_spec`.
   - The home-branch test is shown to catch its removal (it went red when I deleted the branch).
6. **Architecture**
   - **ARCH-DRY: pass.**
   - **ARCH-PURE: pass.**
   - **ARCH-PURPOSE: pass.** Every Done-when clause is delivered. The family sweep found only one non-`.md` leaf among the `located()` assertions, and it is fixed.
   - **ARCH-EVOLVE: pass.** No persisted format is written. The frontmatter read now drops a trailing comment, as YAML does, and `atlas/ui/breadcrumb.md` documents that.
   - There is no new README surface.
7. **Plan revisions:** none. The Log matches the code.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Line 82 now uses x.md; breadcrumb_model_spec passes 13/13 under ui/breadcrumb (newly mapped). Deleting the home branch makes line 83 fail.
  - id: BR-2
    disposition: addressed
    note: |
      The assertion now pins the exact " 0 › 1 › … › 8%=" winbar (document_band_model emits a trailing %=), and the test passes at head.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"40147664-e921-4d3f-a972-08fcdd42ec6d","repository":"github.com/xianxu/parley.nvim","issue_id":"000397","recipe":"small-diff-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/e5b9a4369766c905","reviewed_head":"555ad10936db22758652a4a29f0a2ce861a8b1de","slot":"parley.nvim:3","requested_at":"2026-10-19T08:16:04.757865Z"},"phase":"finished","pid":62167,"started_at":"2026-10-19T08:16:05.00603Z","finished_at":"2026-10-19T08:18:09.54694Z","session_id":"de8468f5-3e87-4368-a3c6-8b130d9efbdb","outcome":"returned"}] -->
