# Boundary Review — parley.nvim#226 (whole-issue close)

| field | value |
|-------|-------|
| issue | 226 — Guard the sdlc resolve spawn behind an in-flight check |
| repo | parley.nvim |
| issue file | workshop/issues/000226-guard-the-sdlc-resolve-spawn-behind-an-in-flight-check.md |
| boundary | whole-issue close |
| milestone | — |
| window | 90c6262c54b10fc220d9c0c170d633105dca7053..5478f45fc9db5e3ae6e41fbbca41a81af60581c8 |
| command | sdlc close --issue 226 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T00:33:07-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Diff and issue read; now running the spec suite and checking a same-key/different-origin edge case.

I'm running the artifact_ref spec file. After that I'll add a temporary probe to confirm the cross-buffer edge case.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The change does what the issue asks. `gf`, the project jump (`ResolveRefProject`) and the reference fallback all go through `goto_ref_at_cursor`, so all three get the in-flight record and the default origin check. A different key kills and supersedes the outstanding resolve. The new runner-seam cases test real behaviour, and `tests/unit/artifact_ref_spec.lua` passes at head. One real defect remains, and it comes from combining two of the Spec's own rules. The in-flight key leaves out the origin, but the result is only delivered to the origin. If the user presses the same ref again from a different buffer or window, nothing opens: the second press is told "still resolving" and the first result is then dropped as stale. I reproduced this with a temporary probe spec: one spawn, zero opens. The fix is cheap, so FIX-THEN-SHIP.

1. **Strengths**
   - `lua/parley/artifact_ref.lua:256-258`: the completion guard `inflight ~= mine` drops a superseded result even when the process had already exited before the kill. The supersede test checks this: the first resolve completes after the kill and is still dropped.
   - `lua/parley/artifact_ref.lua:286-289`: if the spawn raises, the key is released, so the ref can't be stuck on "still resolving" forever. A test covers it.
   - `is_current` combines the new default origin check with `opts.is_current` using `and`, so a caller's check can only narrow the default, never widen it.
   - The tests go through the real `runner` seam (`goto_ref_at_cursor(opts.runner)`) with real Neovim buffers and windows. They never spawn `sdlc`, as the Done-when requires.
   - `run_resolve` now returns the runner's handle and is a small change. With the default runner, `vim.system`'s `SystemObj` reaches the kill path.

2. **Critical findings:** none.

3. **Important findings**
   - **The in-flight key has no origin, but delivery is tied to the origin** (`lua/parley/artifact_ref.lua:230-236` vs `:244-249`). Steps: press `<M-o>` on `#327` in buffer A, move to buffer B in the same repo (or `:split`), and press on `#327` again. The second press only says "still resolving". The first result lands, fails the buffer/window check and is dropped. Nothing opens. My probe (same flow, injected runner) confirmed 1 spawn and 0 opens.
     - **Fix sketch:** add `origin_buf` and `origin_win` to `key`, so a press from a new place counts as a change of mind and supersedes. Then update the Spec "Key" bullet, the atlas bullet and the doc comment, which all name only ref, kind and cwd.
     - **Regression test:** in-flight from buffer A, press the same ref from buffer B, and assert exactly one open (from the second spawn).
     - **Family:** the other place this mismatch could show up is the family-picker selection. It checks the origin too, but the picker only opens while the user is still at the origin, so it isn't affected.

4. **Minor findings**
   - **Doc comment separated from its function.** `local inflight` and `M._reset_inflight` were inserted between `goto_ref_at_cursor`'s doc block (ending "Delegated to by parley init's M.cmd.ResolveRef* commands.", `artifact_ref.lua:205`) and the function itself (`:212`). Move the two declarations above the doc block.
   - **Misplaced claim in the atlas.** In `atlas/context/artifact_refs.md:53`, "so a double-pressed `<M-o>` opens once" is attached to the sentence about a *different* ref superseding. The double-press case is the same-key no-op in the sentence before.
   - **Out of scope.** `workshop/lessons.md` gains a `#344` lesson that has nothing to do with this issue.
   - **ARCH-DRY.** `lua/parley/init.lua:5048-5052`: the reference fallback's own `is_current` re-checks buf/win, which the default check now covers. Its tick/generation checks still add something, so this is redundant but harmless.

5. **Test coverage notes**
   - Every Done-when clause is covered, and both modes are exercised where a clause names two: same ref vs different ref; result landing at the origin vs after leaving the buffer, and vs after leaving the window.
   - No new case covers the default origin check on a **family-picker selection** without `opts.is_current`. The existing #327 cases pass `is_current`.
   - Missing: a same-key press from a different origin (the Important finding).
   - In my second full unit run, `tests/unit/tools_builtin_find_spec.lua` failed. It passed in the first run, and that code isn't touched by this window, so it's likely flaky. I didn't look into it further.

6. **Architectural notes**
   - **ARCH-DRY:** pass, apart from the Minor redundant buf/win check above.
   - **ARCH-PURE:** pass. The in-flight decision lives inside the thin editor entry point but is driven entirely through the injected runner. Pulling the key/supersede decision into a pure function would be a reasonable later step.
   - **ARCH-PURPOSE:** pass. Every consumer (`gf`, the project jump, the reference fallback) goes through the guarded path, and nothing was deferred.

7. **Plan revision recommendations**
   - If the Important fix lands, add a `## Revisions` entry: "2026-10-16: the in-flight key includes the origin buffer and window; a same-ref press from another place supersedes rather than no-ops, since delivery is tied to the origin." Update the Spec "Key" bullet to match.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: inflight-key-vs-delivery-origin
    title: |
      Same-ref press from another buffer/window is a no-op, and the in-flight result is then dropped as stale; nothing opens
    detail: |
      artifact_ref.lua:230 keys in-flight on ref+kind+cwd only, but is_current (:244) delivers only to the origin buf/win. A probe spec (press #327 in buf A, press #327 in buf B, complete) gave 1 spawn, 0 opens. Fix: add origin_buf/origin_win to the key (a press from a new place supersedes), add a regression test asserting one open, and update the Spec Key bullet, atlas bullet and doc comment. The family-picker selection uses the same origin check but can only open while at the origin, so it is not affected.
  - id: new
    severity: Minor
    kind: defect
    family: hoist-separates-doc-comment
    title: |
      local inflight and _reset_inflight inserted between goto_ref_at_cursor's doc block and the function
    detail: |
      artifact_ref.lua:206-210 sits between the doc block ending at :205 and the function at :212; move the two declarations above the doc block.
  - id: new
    severity: Minor
    kind: defect
    family: doc-claim-misattributed
    title: |
      Atlas ties "a double-pressed M-o opens once" to the different-ref supersede sentence
    detail: |
      atlas/context/artifact_refs.md:53; the double-press guarantee comes from the same-key no-op in the sentence before.
  - id: new
    severity: Minor
    kind: defect
    family: test-both-modes
    title: |
      Default origin check on a family-picker selection (no opts.is_current) has no test
    detail: |
      The new describe only covers single-file dispatch; the #327 picker cases pass is_current.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"2e5badc5-4976-4e4d-ad9e-66047a42dc6a","repository":"github.com/xianxu/parley.nvim","issue_id":"000226","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/9dd0efd76a2952c0","reviewed_head":"5478f45fc9db5e3ae6e41fbbca41a81af60581c8","slot":"parley.nvim:3","requested_at":"2026-10-16T07:29:39.209437Z"},"phase":"finished","pid":13381,"started_at":"2026-10-16T07:29:39.389455Z","finished_at":"2026-10-16T07:32:53.631175Z","session_id":"e983eb5b-bbb3-4bb9-9fe7-d11076bc5d48","outcome":"returned"}] -->

---

## Re-review — 2026-10-16T00:37:15-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 226 — Guard the sdlc resolve spawn behind an in-flight check |
| repo | parley.nvim |
| issue file | workshop/issues/000226-guard-the-sdlc-resolve-spawn-behind-an-in-flight-check.md |
| boundary | whole-issue close |
| milestone | — |
| window | 90c6262c54b10fc220d9c0c170d633105dca7053..2f49f51bddfecf8a72586f4550fa40d0ceda761b |
| command | sdlc close --issue 226 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T00:37:15-07:00 |
| verdict | SHIP |

## Review

Running the artifact_ref spec now, then I'll revert the BR-1 fix to confirm its regression test goes red.

The test harness needs its isolated env; running the mapped spec set through `make test-spec`.

Now reverting the origin-in-key (BR-1) to confirm the regression test fails without it.

Confirmed: BR-1's test goes red without the fix. Doing a quick mutation check on BR-4's picker test as well.

```verdict
verdict: SHIP
confidence: high
```

All four prior findings are fixed, and I checked each one against the code at the pinned head. On BR-1, the in-flight key now includes the origin buffer and window (`lua/parley/artifact_ref.lua:234`). The new test for this, "lets the same ref pressed from another window supersede, and opens there", passes at head (40/40 via `make test-spec SPEC=context/file_references`). When I took `origin_buf, origin_win` out of the key, that test alone went red (39/1). When I took the window check out of `is_current`, both window-staleness cases went red (38/2), including the new BR-4 picker-selection case. The only thing left is one Minor: the Plan bullet and the Core concepts table in the issue file still describe the record's key and fields as they were before BR-1. Nothing blocks SHIP.

Done-when: current. Its four clauses (same ref gives one spawn and one open; a different ref supersedes; a default origin check for both buffer and window; everything asserted through the runner seam) are the guarantees this diff delivers, and each has a passing test. The BR-1 Spec change only tightens the key so that the no-op agrees with the staleness check, which is what keeps clauses 1 and 3 true together. It doesn't add a new guarantee that Done-when would need to name.

1. **Strengths**
   - `artifact_ref.lua:248-252`: `is_current` combines supersession (`inflight == mine`), the origin buf/win and the caller's `opts.is_current` with AND. A caller can only narrow the check, never widen it, as the Spec says.
   - `artifact_ref.lua:289-293`: a spawn that raises releases the key and then raises again with `error(handle, 0)`, so the error is not swallowed. The "releases the key when the spawn raises" test covers it.
   - `artifact_ref.lua:264`: a superseded resolve that had already exited is dropped through `inflight ~= mine`. The supersede test checks both the kill and the late completion.
   - The tests use the real runner seam with an observable fake handle, and both window and buffer departure are exercised. There is no mocking of the code under test.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - The issue file's Plan bullet (line 81) still says "keyed on the ref, kind and cwd", and the Core concepts row (line 68) says the record holds a "token", but the actual record is `{ key, handle, done }`, where identity (`mine`) does the work of a token. Both are restatements left over from before BR-1 (see the findings block).

5. **Test coverage**
   - All the Done-when modes are covered: buffer departure and window departure, result and picker selection, same key and different key (ref, kind, origin), and the spawn-raises path.
   - Mutation checks run in this review:
     - Removing the origin from the key fails 1 test.
     - Removing the window check fails 2 tests.

6. **Architecture**
   - **ARCH-DRY: pass.** Nothing is duplicated. The test `runner`/`drain` helpers are local to the new describe block and don't copy the existing guarded-completion fixtures in a way that calls for sharing.
   - **ARCH-PURE: pass.** `goto_ref_at_cursor` is the documented thin IO shell. The spawn is injected through `opts.runner`, and the parsing and picker-item logic stay in the existing pure helpers.
   - **ARCH-PURPOSE: pass.** `gf`, `<M-o>` and the project jump all go through `goto_ref_at_cursor`, so every consumer gets the dedup and the default staleness check, not just the reference-navigation fallback. The shadow sweep of the key restatements found the Spec Key bullet, the atlas bullet (`artifact_refs.md:50-57`) and the doc comment (`artifact_ref.lua:204-213`) all updated. Only the issue's Plan bullet and Core concepts row are stale (Minor below).

7. **Plan revision recommendations**
   - Plan line 81: change to "keyed on the ref, kind, cwd and origin buffer/window".
   - Core concepts row: change to "its key, process handle and done flag (record identity marks the latest)".

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Key includes origin_buf/origin_win (artifact_ref.lua:234); the supersede-from-another-window test fails when the origin is removed from the key (verified 39/1), passes at head 40/40; Spec, atlas and doc comment updated.
  - id: BR-2
    disposition: addressed
    note: |
      inflight and _reset_inflight now at artifact_ref.lua:182-186, above the goto_ref_at_cursor doc block, which runs contiguously into the function.
  - id: BR-3
    disposition: addressed
    note: |
      atlas/context/artifact_refs.md:51-53 now ties the double-press guarantee to the same-key no-op sentence; supersede is its own sentence.
  - id: BR-4
    disposition: addressed
    note: |
      New test "drops a family selection made after the user left the window" calls press() without is_current; it fails when the window check is removed from is_current (verified).
findings:
  - id: new
    severity: Minor
    kind: defect
    family: contract-restatement-sweep
    title: |
      Issue Plan bullet and Core concepts row still restate the record as it was before BR-1
    detail: |
      The issue's Plan item at line 81 says the record is keyed on "the ref, kind and cwd" (origin buf/win is missing), and the Core concepts row at line 68 lists a "token" the record does not have (it is { key, handle, done }). The rule: when a contract changes, update every restatement of it. Enumerating this window's restatements of the key and record: Spec Key bullet (updated), atlas artifact_refs.md:50 (updated), artifact_ref.lua:182 and :204 comments (updated), Plan line 81 (stale), Core concepts line 68 (stale). Fix the two stale ones.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"18d12083-adc4-4acd-84d7-ed1bd02d704c","repository":"github.com/xianxu/parley.nvim","issue_id":"000226","recipe":"small-diff-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/4ee6fa566e4e74c6","reviewed_head":"2f49f51bddfecf8a72586f4550fa40d0ceda761b","slot":"parley.nvim:3","requested_at":"2026-10-16T07:34:31.141842Z"},"phase":"finished","pid":77381,"started_at":"2026-10-16T07:34:31.376917Z","finished_at":"2026-10-16T07:37:12.473655Z","session_id":"5f4d0389-b029-491a-9e4a-0d33a66c743f","outcome":"returned"}] -->
