# Boundary Review — parley.nvim#338 (whole-issue close)

| field | value |
|-------|-------|
| issue | 338 — Starter adopts an enclosing git project when its profile cwd or TMPDIR is nested in one, escaping the chat root and seeding a tutorial into that repo |
| repo | parley.nvim |
| issue file | workshop/issues/000338-starter-adopts-an-enclosing-git-project-when-its-profile-cwd-or-tmpdir-is-nested-in-one-escaping-the-chat-root-and-seeding-a-tutorial-into-that-repo.md |
| boundary | whole-issue close |
| milestone | — |
| window | e23163d1bb9f42765fdd899f18951b6f32c6208e..9092ea24ef63454cc83d16ce61524c7fcbde11e4 |
| command | sdlc close --issue 338 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-15T17:20:26-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Still reviewing — checking whether the plan's claim that "the launcher sets PARLEY_REPO_MODE=0" is actually true.

Finding the test command so I can revert the fix and confirm the new regression test fails without it.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The core fix is correct. `starter.welcome()` now seeds and opens the tutorials in `options.chat_dir`, which is the profile directory captured before `setup()` (or the `PARLEY_CHAT_DIR` override). The primary `chat_dir` from project mode is restored afterwards. I checked the regression by reverting it: with `lua/parley/starter.lua` set back to base, `starter_project_spec` fails 4 of 6, and the old code actually wrote `workshop/parley/vim-basics.md` into this checkout. With the fix the spec passes 6/0 when TMPDIR is outside the checkout. `packaging_vm_spec` passes 17/0 with TMPDIR inside this marked checkout, which meets Done-when bullet 2. One thing should be fixed first, and it is cheap. The issue exists because a test's temp dir sat inside a marked checkout. The guest test in `packaging_vm_spec` was made immune to that, but `starter_project_spec` was not. With TMPDIR inside this checkout it fails 5/1, in "keeps the global app profile without a marker". The spec this issue added fails in the exact sandbox setup that triggered the issue.

1. **Strengths**
   - `lua/parley/starter.lua:183`: the profile directory is passed in explicitly as `options.chat_dir` and never re-read from the changed config. `migrate_welcome` now also runs against the profile, which is where old `welcome/` directories live.
   - `lua/parley/starter.lua:123,155`: the variable is renamed to `primary` and restored after `xpcall`. This keeps the old invariant that `parley.config.chat_dir` comes back unchanged.
   - `tests/integration/starter_project_spec.lua:29-41`: the assertions check real behaviour, with no mocks. They check that the opened buffer is the profile's `welcome.md`, that it is a recognized chat (`not_chat == nil`), that every tutorial is in the profile and none is in the project. The red→green result is real: I confirmed it by reverting the fix.
   - `packaging_vm_spec.lua:170`: `PARLEY_REPO_MODE=0` matches `parley_app:119` for the guest scenario, so the claim "as the launcher does" holds.
   - The atlas entry at `atlas/infra/starter.md:253` is updated, and its wording is accurate.

2. **Critical findings:** none.

3. **Important findings**
   - `tests/integration/starter_project_spec.lua:93` ("keeps the global app profile without a marker"): this case breaks when the test process's TMPDIR is inside any `.parley`-marked ancestor. `scratch` comes from `tempname()`, and `detect_root` walks up past the scratch project to the checkout's `.parley`. I reproduced it twice, with `TMPDIR=$PWD/.rvtmp` and with `TMPDIR=""`. Both runs failed with `wrong primary chat dir: <checkout>/workshop/parley`. Nothing was written, because the fix holds.
     - The rule is that integration specs must not depend on a marked ancestor (ARCH-PURPOSE: sweep the class, not just the instance that was reported).
     - Instances in this window: `packaging_vm_spec` guest (fixed), and `starter_project_spec` no-marker case (open). The marker cases pass only because the nearer scratch marker wins.
     - Fix sketch: create the no-marker case's scratch under a directory with no `.parley` ancestor. Alternatively, assert that precondition (`repo_mode.detect_root(scratch, '.parley') == nil`) and `pending()` otherwise. Don't set `PARLEY_REPO_MODE=0` there, because that case exists to test discovery.

4. **Minor findings**
   - The plan's Verify step says "TMPDIR in- and outside a checkout" but only shows packaging_vm run with TMPDIR inside. starter_project was evidently never run that way, which is how the finding above was missed.

5. **Test coverage notes**
   - Done-when bullet 1 is covered by all three marked-project cases: the explicit TMPDIR case, plus marker-only and nested, which now share the assertions.
   - Bullet 2: I verified 17/0 with TMPDIR inside the marked checkout.
   - I did not run the full suite. The Log reports `make -k test` exit 0 on 544ef394.

6. **Architectural notes**
   - ARCH-DRY: pass. No duplicated logic is introduced. The directory is threaded through as a parameter.
   - ARCH-PURE: pass. The change is a parameter in an existing INTEGRATION seam. The tests are subprocess integration tests, which is what the Core concepts table says (INTEGRATION).
   - ARCH-PURPOSE: flagged under Important, because the test-hermeticity class was not swept across the specs this issue touched. The product purpose itself (never write into a project the operator didn't choose) is delivered.

7. **Plan revision recommendations**
   - Add the starter_project_spec hermeticity fix to the Plan checklist. Extend the Verify item to run starter_project_spec with TMPDIR inside the checkout as well.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: spec-hermetic-to-marked-ancestor
    title: |
      starter_project_spec no-marker case fails when TMPDIR is inside a .parley-marked checkout
    detail: |
      tests/integration/starter_project_spec.lua:93 "keeps the global app profile without a marker" builds scratch via tempname(); with TMPDIR inside this checkout (the exact sandbox condition from issue 338) detect_root climbs to the checkout's .parley and the case fails 5/1 with "wrong primary chat dir: <checkout>/workshop/parley" (reproduced with TMPDIR=$PWD/.rvtmp and TMPDIR=""). Family instances in this window: packaging_vm_spec guest (fixed via PARLEY_REPO_MODE=0) and starter_project_spec no-marker case (open). Fix: place that case's scratch under a dir with no marked ancestor, or assert/pending on repo_mode.detect_root(scratch) == nil; do not set PARLEY_REPO_MODE=0 there since the case tests discovery. Add starter_project_spec to the Verify step's TMPDIR-inside run.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"070cc84f-f11d-4c7c-9d00-87c73d9a45c1","repository":"github.com/xianxu/parley.nvim","issue_id":"000338","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/f847ba6be2d997df","reviewed_head":"9092ea24ef63454cc83d16ce61524c7fcbde11e4","slot":"parley.nvim:3","requested_at":"2026-10-16T00:18:45.481Z"},"phase":"finished","pid":92257,"started_at":"2026-10-16T00:18:45.700001Z","finished_at":"2026-10-16T00:20:26.386328Z","session_id":"6561c8df-53b1-4a60-ae7d-11198e60261b","outcome":"returned"}] -->

---

## Re-review — 2026-10-15T18:08:45-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 338 — Starter adopts an enclosing git project when its profile cwd or TMPDIR is nested in one, escaping the chat root and seeding a tutorial into that repo |
| repo | parley.nvim |
| issue file | workshop/issues/000338-starter-adopts-an-enclosing-git-project-when-its-profile-cwd-or-tmpdir-is-nested-in-one-escaping-the-chat-root-and-seeding-a-tutorial-into-that-repo.md |
| boundary | whole-issue close |
| milestone | — |
| window | e23163d1bb9f42765fdd899f18951b6f32c6208e..57a01cb7a5314ab43df667f38e7d2adab55f994a |
| command | sdlc close --issue 338 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-15T18:08:45-07:00 |
| verdict | SHIP |

## Review

Checking the BR-1 fix by running the two affected specs, once with TMPDIR inside the checkout and once with it outside.

Specs reproduce as expected. Next, I'm checking that the new guard catches a marked ancestor outside the repo, and that reverting the starter fix turns the regression red.

Both checks go red as they should. Last step: reading the full `welcome()` and spec probe against the Done-when clauses.

```verdict
verdict: SHIP
confidence: high
```

This change is ready to ship. `welcome()` now always seeds the tutorials and opens `welcome.md` in the profile's own chat directory (`options.chat_dir`, read before `setup()`), never in project mode's primary root. Project mode itself still behaves as documented. I checked the fix by reverting it: with the old `starter.lua`, all three marked-project cases in `starter_project_spec` fail, each opening `welcome.md` from `<project>/workshop/parley`. With the fix the spec passes 6/0 when TMPDIR is outside the checkout. With TMPDIR inside this marked checkout, `packaging_vm_spec` passes 17/0. BR-1 is addressed at the harness level rather than spec by spec. When TMPDIR is inside the checkout, the no-marker case still fails, but every existing scratch-placement guard (#202) fails there too, so that setup was already unsupported. The new guard also catches the gap #202 didn't cover: a marked directory outside the repo. With TMPDIR under such a directory, it fails 6/1 and names the reason. Nothing blocks shipping; the remaining notes are Minor.

1. **Strengths**
   - `lua/parley/starter.lua:91,183`: a small fix in the right place. The profile directory is captured before `setup()` and passed in explicitly, and the primary chat root is still restored after seeding (`starter.lua:155`).
   - The new spec checks the files on disk, not mocks. Every tutorial must exist in the profile and none in the project, and the opened buffer must be the profile's `welcome.md` as a recognized chat (`tests/integration/starter_project_spec.lua:29-41`). Reverting the fix turns it red.
   - `tests/arch/scratch_placement_spec.lua:52-63`: the guard checks the actual rule ("scratch has no `.parley`-marked ancestor") and explains itself when it fails. I confirmed it fails for a marked directory outside the repo and passes under the normal harness (7/0).
   - The no-marker case was correctly not given `PARLEY_REPO_MODE=0`, since it tests project discovery. The opt-out sits only in the VM guest, matching what the `parley_app` launcher does.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - `scratch_placement_spec.lua:59`: applying `:h` to `$HOME` starts the search at HOME's parent, so a `.parley` file in `$HOME` itself would be missed. Check `$HOME` directly; keep `:h` only for `tempname()`.
   - The atlas says the `PARLEY_CHAT_DIR` override is honoured in project mode (`atlas/infra/starter.md:253`), but no test covers that combination.

5. **Test coverage**
   - Done-when clause 1: project mode on (three marked-project cases) and off (the no-marker case) are both checked against the profile `welcome.md` and its tutorials.
   - Done-when clause 2: I ran `packaging_vm_spec` with TMPDIR inside this marked checkout: 17/0.

6. **Architecture**
   - ARCH-DRY: pass. The guard reuses `repo_mode.detect_root` and `config.repo_marker`.
   - ARCH-PURE: pass. The change is a parameter at the existing IO edge; no logic was pulled into IO.
   - ARCH-PURPOSE: pass. The spec's rule "never write into a repository the operator did not choose" holds for everything the starter installs. Whether the app should enter project mode at all is explicitly marked out of scope as a product decision.

7. **Plan revisions:** none needed. The existing Revisions entry already matches the code.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Class fix at the harness: the new guard (scratch_placement_spec.lua:52) fails for a marked ancestor outside the repo (verified 6/1, the reason names $HOME under the marked dir) and passes under the normal harness (7/0). With TMPDIR inside the checkout, the pre-existing #202 guards already fail, so that setup is declared unsupported. starter_project passes 6/0 with TMPDIR outside and 5/1 inside (expected, explained by the guard). The no-marker case correctly keeps discovery on, without PARLEY_REPO_MODE=0.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: spec-hermetic-to-marked-ancestor
    title: |
      Ancestor guard checks the parent of $HOME, so a marker in $HOME itself is missed
    detail: |
      scratch_placement_spec.lua:59 applies :h to both paths. That is right for tempname() (a file) but skips $HOME itself (a directory). Check detect_root on $HOME directly. Only this one site in the window.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"a0ce1e5e-338c-4e01-8d94-1d3a29e162ab","repository":"github.com/xianxu/parley.nvim","issue_id":"000338","recipe":"small-diff-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/4d99f9c643e9ef42","reviewed_head":"57a01cb7a5314ab43df667f38e7d2adab55f994a","slot":"parley.nvim:3","requested_at":"2026-10-16T00:57:52.282735Z"},"phase":"finished","pid":37408,"started_at":"2026-10-16T00:57:52.564789Z","finished_at":"2026-10-16T01:08:36.137352Z","session_id":"887339a4-b56e-470e-80e5-783b2738c49e","outcome":"returned"}] -->

---

## Re-review — 2026-10-15T18:13:08-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 338 — Starter adopts an enclosing git project when its profile cwd or TMPDIR is nested in one, escaping the chat root and seeding a tutorial into that repo |
| repo | parley.nvim |
| issue file | workshop/issues/000338-starter-adopts-an-enclosing-git-project-when-its-profile-cwd-or-tmpdir-is-nested-in-one-escaping-the-chat-root-and-seeding-a-tutorial-into-that-repo.md |
| boundary | whole-issue close |
| milestone | — |
| window | 36e79af6c737cc323a957f64f128345c5a35940b..9b518f2d19e311e84bc8dbeeaee1a8c4c95d26de |
| command | sdlc close --issue 338 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-15T18:13:08-07:00 |
| verdict | SHIP |

## Review

Still checking the BR-2 fix. Next I'll find the test runner and run the guard spec.

Found a writable temp dir outside the checkout. Next I rerun the spec there, then revert the fix and run it again.

```verdict
verdict: SHIP
confidence: high
```

The BR-2 fix is correct, and I proved it by reverting it. `marked_scratch` in `tests/arch/scratch_placement_spec.lua:54-62` now takes the parent (`:h`) only of `tempname()`, which names a file, and passes `$HOME` to `detect_root` unchanged. The new case at `:73-81` puts a `.parley` marker directly inside a fake `$HOME`. With TMPDIR outside the checkout, the spec passes 8/0 at head. When I put `:h` back on `$HOME`, the new case fails and the other 7 still pass, so the test only goes green with the fix. I then restored the file, and the working tree was clean. The main #338 fix still holds: `starter_project_spec` passes 6/0 with TMPDIR outside the checkout.

One run is not a defect but you should know about it. With the review's own TMPDIR, which sits inside this marked checkout (`.sdlc-review/tmp`), `scratch_placement_spec` fails 8/8. That is the guard working as designed: round 2 declared that setup unsupported. It is not a problem with this change.

1. **Strengths**
   - `lua/parley/starter.lua:91,183`: the profile chat directory (`options.chat_dir`) is passed into `welcome()` explicitly. The project-mode primary is saved in `primary` and restored afterwards (`:123,155`), so `parley.config.chat_dir` comes back unchanged after startup.
   - `tests/integration/starter_project_spec.lua:29-41`: the tests check real behaviour, with no mocks. The opened buffer must be the profile's `welcome.md` and a recognized chat, every tutorial must be in the profile, and none may be in the project.
   - `tests/arch/scratch_placement_spec.lua:54`: the guard is one function, `marked_scratch`. The real check and the self-test both call it, so the self-test exercises exactly the code that guards the suite.
   - `atlas/infra/starter.md:253-254` is updated, and its wording matches the code.

2. **Critical findings:** none.

3. **Important findings:** none.

4. **Minor findings**
   - `scratch_placement_spec.lua:78`: `delete(home)` runs after `marked_scratch`. If that call throws, the temp dir is left behind. It is harmless (scratch space only), and nothing needs to change.

5. **Test coverage notes**
   - The guard is checked both ways: no marker (the real-environment case) and a marker in `$HOME` (the self-test).
   - The `tempname()` side is protected through the same function by the first `it`. No separate case puts a marker above `tempname()`. Round 2 verified that path by hand (6/1).

6. **Architectural notes**
   - ARCH-DRY: pass. The guard logic is now one shared helper.
   - ARCH-PURE: pass. The helper takes its paths as arguments, which is why the self-test can inject a fake `$HOME`. The IO is limited to the existing `detect_root` file check.
   - ARCH-PURPOSE: pass. The product purpose is delivered: the starter never seeds tutorials into a project the operator didn't choose. The hermetic-scratch rule is enforced once at the harness, as round 2 accepted. No new instance of the `spec-hermetic-to-marked-ancestor` family turned up.

7. **Plan revision recommendations:** none.

```findings
dispose:
  - id: BR-2
    disposition: addressed
    note: |
      marked_scratch passes $HOME to detect_root without :h (scratch_placement_spec.lua:60); the new case at :73 goes red (7/1) when :h on $HOME is reinstated and green (8/0) at head, with TMPDIR outside the checkout.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"129ff7b3-230f-41dd-a8ce-c988021afdba","repository":"github.com/xianxu/parley.nvim","issue_id":"000338","recipe":"small-diff-review","round":3,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/97873e164baa1a7c","reviewed_head":"9b518f2d19e311e84bc8dbeeaee1a8c4c95d26de","slot":"parley.nvim:3","requested_at":"2026-10-16T01:11:30.67895Z"},"phase":"finished","pid":80254,"started_at":"2026-10-16T01:11:30.822849Z","finished_at":"2026-10-16T01:13:07.784153Z","session_id":"997ba0fe-bddb-462d-a3e7-4f5a6efee9bb","outcome":"returned"}] -->
