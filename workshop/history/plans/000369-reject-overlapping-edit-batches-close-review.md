# Boundary Review — parley.nvim#369 (whole-issue close)

| field | value |
|-------|-------|
| issue | 369 — Reject overlapping edit batches |
| repo | parley.nvim |
| issue file | workshop/issues/000369-reject-overlapping-edit-batches.md |
| boundary | whole-issue close |
| milestone | — |
| window | 3e055bc1e3c11defa75743c020f2698204fb7bcc..be2bcad41a9e7bc27fa907b933c7e4993dd862aa |
| command | sdlc close --issue 369 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T21:09:25-07:00 |
| verdict | SHIP |

## Review

Running the three changed specs directly with headless nvim.

Rather than run whole spec groups, I'll invoke the per-file runner through the env script.

Now reverting the guard to confirm the regressions go red.

```verdict
verdict: SHIP
confidence: high
```

This change does what the issue asks. `skill_edits.compute_edits` now sorts the positioned edits by start and refuses the whole batch when an edit starts at the same place as the one before it, or before that one ends. The refused result has no content and an empty `applied`. Checking only neighbouring pairs is enough: once intervals are sorted by start, any overlapping pair (i, j) means i and i+1 also overlap. Adjacent spans pass, because an edit starting exactly where the previous one ends is allowed. All three changed spec files pass at head, along with the skill-system spec group and `tool_file_transform_spec`. I swapped `lua/parley/skill_edits.lua` back to its base version in the disposable checkout and ran the specs again: 6 of 12 pure specs failed, the sync IO spec failed and the async IO spec failed. Then I restored the file. So every new regression test fails without the fix. Nothing blocks SHIP; two Minor notes follow.

1. **Strengths**
   - The guard sits in the one shared engine (`lua/parley/skill_edits.lua:49-67`). Both callers inherit it: `tools/builtin/propose_edits.lua` and `tools/file_transform.lua:44`.
   - The tie-break on `index` (`skill_edits.lua:53-56`) makes the error message the same whichever order the batch is given in. The specs check both orders for every overlap shape (`tests/unit/skill_edits_spec.lua:86-91`).
   - The IO specs check what the user actually cares about: the file is unchanged and there is no `.parley-backup.1`. This holds on the sync path (`tests/unit/tools_builtin_propose_edits_spec.lua:117-128`) and the async path, which runs on the fake tool filesystem (`tests/integration/async_builtin_spec.lua:142-155`).
   - The "names the overlapping pair among other edits" spec confirms the batch numbers survive the sort.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - **Snippet can mislead** (`skill_edits.lua:62`): the error always shows the old_string of the edit that sits later in the file, not edit `#second`. For the batch `{pha, alpha}` you get "edits #1 and #2 overlap: pha", where `pha` is #1. Showing both snippets, or naming whose snippet it is, would fix it. This is the only error in the diff that names a pair.
   - **Stale header comment** (`skill_edits.lua:3-5`, not touched by this diff): it says propose_edits "is its one caller", but `tools/file_transform.lua:44` also calls `compute_edits`. It's a "the only" claim that is false today. Change it to name both callers.

5. **Test coverage notes:** The tests cover every clause of Done-when: the reproducer, containment, partial overlap, identical spans, same start, adjacency, disjoint spans, and both IO paths. The plan mentions an empty old_string as a same-start case, but it can only reach the overlap check when the content is empty, because the uniqueness check rejects it otherwise. That case has no spec and the risk is very low.

6. **Architecture**
   - **ARCH-DRY: pass.** There is one overlap check, in the shared engine. #362's local validator isn't in this tree, so nothing is duplicated yet. Once both are on main, #362's local check can likely be removed because the engine covers it.
   - **ARCH-PURE: pass.** The check is pure logic inside a pure function, and its unit tests use no IO. The IO tests use a tmpfile and the injected fake filesystem, and they only confirm the existing early return.
   - **ARCH-PURPOSE: pass.** Both consumers of the engine get the protection, and nothing was deferred. The atlas row is updated; there is no new README-facing surface.

7. **Plan revision recommendations:** none. The plan matches the code.

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: error-message-names-wrong-referent
    title: |
      Overlap error snippet is the later-positioned edit's old_string, not edit #second
    detail: |
      skill_edits.lua:62 shows edit.old_string (the edit later in the file) after "edits #first and #second", so the batch {pha, alpha} reads "edits #1 and #2 overlap: pha" where pha is #1. Show both snippets or label whose snippet it is. This is the only pair-naming error in the window.
  - id: new
    severity: Minor
    kind: defect
    family: doc-claim-only-caller
    title: |
      skill_edits.lua header says propose_edits is its one caller; file_transform.lua:44 also calls compute_edits
    detail: |
      This pre-existing comment sits next to the changed code, and a reader trusting it would miss that the async path also inherits the new refusal. Change it to name both callers (propose_edits.handler and tools/file_transform). No other doc claim in the window is affected.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"116b8a96-d2af-472d-9f2b-add4f8906332","repository":"github.com/xianxu/parley.nvim","issue_id":"000369","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/226c39ef00a92b50","reviewed_head":"be2bcad41a9e7bc27fa907b933c7e4993dd862aa","slot":"parley.nvim:3","requested_at":"2026-10-17T04:07:13.261809Z"},"phase":"finished","pid":66749,"started_at":"2026-10-17T04:07:13.433011Z","finished_at":"2026-10-17T04:09:18.192241Z","session_id":"e1558855-00d9-4a01-8f19-88fc7030c9e5","outcome":"returned"}] -->

---

## Re-review — 2026-10-16T21:11:41-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 369 — Reject overlapping edit batches |
| repo | parley.nvim |
| issue file | workshop/issues/000369-reject-overlapping-edit-batches.md |
| boundary | whole-issue close |
| milestone | — |
| window | e34b34d3863c3a823ab2d13ab6985dc31634d7fc..6184b45993c76622407b6a68bbdd97f7fb62bff9 |
| command | sdlc close --issue 369 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T21:11:41-07:00 |
| verdict | SHIP |

## Review

Both prior fixes look correct in the diff. Now I'm finding the test runner so I can run the changed specs.

Running the changed specs through the make harness so the test environment is set up correctly.

Now reverting the message fix to confirm the new assertions fail without it.

```verdict
verdict: SHIP
confidence: high
```

Both earlier findings are fixed, and each fix covers the whole class of problem, not just the line that was flagged. The overlap error now shows each edit's text next to its own batch number. Tests check the exact message in both batch orders, and they fail without the fix. The header comment in `skill_edits.lua` now names the real caller. A grep confirms `tools/file_transform.lua:44` is the only place outside the module that calls `compute_edits`, and both `propose_edits` paths go through it. The changes to the issue file only record the close: the status, `actual_hours` and a Log line. `## Spec`, `## Revisions` and `## Done when` are unchanged, and no new behaviour was added. Nothing blocks SHIP.

1. **Strengths**
   - `lua/parley/skill_edits.lua:60-65`: the two edits are put in batch order by swapping the records themselves, not just the index numbers. So each text snippet always stays with its own number, and the bug can't come back by this route.
   - `tests/unit/skill_edits_spec.lua:92-94`: the loop over overlap shapes now checks the exact message in the reversed order. That is the order where the old message was wrong.
   - The tests compare the whole message (`assert.equals`, or a plain-text match in the IO specs), so a wrong pairing can't slip through a loose pattern.

2. **Critical:** none.
3. **Important:** none.
4. **Minor:** none new. The generated "closed" Log line was inserted above the existing "Filed from #362" paragraph rather than after it. That's cosmetic and comes from the tool, so I'm not raising it.

5. **Test coverage notes:** I ran four specs at head through the make test environment, and all passed: `skill_edits_spec`, `tools_builtin_propose_edits_spec`, `integration/async_builtin_spec` and `tool_file_transform_spec`. I then put the base version of `skill_edits.lua` back in the disposable checkout and ran the first three again:
   - `skill_edits_spec`: 6 of 12 failed.
   - `propose_edits`: 1 failed.
   - `async_builtin`: 1 failed.

   Afterwards I restored the file, and the working tree is clean. So the fix is reachable, and the tests do fail without it.

6. **Architecture (this window only)**
   - **ARCH-DRY: pass.** The overlap message is still built in one place, the shared engine. The three test files assert the same text, which is acceptable for tests.
   - **ARCH-PURE: pass.** The message is built purely from data. The unit specs test it with no IO.
   - **ARCH-PURPOSE: pass.** For BR-1, I checked the window for any other error that names a pair; there are none. For BR-2, I checked every claim that something is the "single source" or the "one caller". `propose_edits.lua:7` ("single-source `parley.skill_edits.compute_edits`") is accurate, and no stale sibling claims remain.

7. **Plan revision recommendations:** none.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      skill_edits.lua:60-65 now shows "edits #a (snipA) and #b (snipB) overlap", with each snippet next to its own batch number. Exact-message asserts in skill_edits_spec (both orders), propose_edits and async_builtin specs fail with the base engine (6+1+1 red) and pass at head.
  - id: BR-2
    disposition: addressed
    note: |
      The header now names tools/file_transform as the one caller. A grep confirms file_transform.lua:44 is the only compute_edits call site, and propose_edits.lua:48 and :58 route through file_transform.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"9e6adc6e-7a89-4784-9b27-e10e1687682a","repository":"github.com/xianxu/parley.nvim","issue_id":"000369","recipe":"fix-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/0a856e0cd0a1f7da","reviewed_head":"6184b45993c76622407b6a68bbdd97f7fb62bff9","slot":"parley.nvim:3","requested_at":"2026-10-17T04:10:33.683113Z"},"phase":"finished","pid":97542,"started_at":"2026-10-17T04:10:33.880285Z","finished_at":"2026-10-17T04:11:40.673704Z","session_id":"21d0c211-d9dd-40aa-b7e5-0699115c0e46","outcome":"returned"}] -->
