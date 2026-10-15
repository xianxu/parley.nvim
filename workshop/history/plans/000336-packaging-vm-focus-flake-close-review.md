# Boundary Review — parley.nvim#336 (whole-issue close)

| field | value |
|-------|-------|
| issue | 336 — Flake: packaging VM guest chat confinement follows transient focus |
| repo | parley.nvim |
| issue file | workshop/issues/000336-packaging-vm-focus-flake.md |
| boundary | whole-issue close |
| milestone | — |
| window | 35d876d55d7940f20c3d6087846f4247d2b9b14d..00221b88dc4012d833acf04d2d14012e8e19b00e |
| command | sdlc close --issue 336 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-15T16:02:01-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Checking whether the guest nvim runs with a UI — that decides if the login's own float can satisfy the new picker wait.

Building a one-off map so I can run just the packaging spec at head.

The focused spec fails at head in this checkout. Getting the full failure message to see whether it's the fix or this environment.

TMPDIR here sits inside the repo checkout, so the guest root is nested in the repository. The starter likely discovers the repo as a project. Rerunning with TMPDIR outside the tree.

Green at head (17/0) once TMPDIR is outside the repo. Now reverting only the probe fix in `vm_chat.lua` to confirm the regression goes red.

With the settle block removed, the spec still passes 17/0 on two runs, so nothing pins the picker-settle half of the fix. Checking where the stray untracked file came from before writing up.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The main fix works and the tests prove it. `ask()` now returns the file of the chat it actually created, and the guest script asserts confinement on that file after a deliberate `enew`. That deterministically removes the flake, which came from asserting on whatever buffer had focus. I ran the focused spec at head and it passed 17/0 (with TMPDIR outside the repo; see the test coverage notes). The second half of the fix has no regression test. That half is the probe waiting for the model picker that login reopens and closing it with `<Esc>` before dispatching the chat. I deleted that block from `tests/packaging/vm_chat.lua` and the spec still passed 17/0 on two runs. The spec's new "no floating window" check runs right after `run("fake")` returns, without letting Neovim process pending events, so a picker reopen scheduled after the probe finishes is never seen. Done-when clause 2 says the probe "settles the login flow's reopened picker before chat dispatch", and nothing currently catches its removal. This is cheap to fix and doesn't block the boundary, so the verdict is FIX-THEN-SHIP.

1. **Strengths**
   - `tests/packaging/vm_chat.lua:78-79`: `ask()` reports `chat_file` from the captured `buf`, not from focus. This is the correct fix for the root cause.
   - `tests/integration/packaging_vm_spec.lua:157-160`: `enew` before the assertions makes the test independent of focus. The old buffer-0 assertion would fail every time under this.
   - The root-cause trace in the Plan is accurate. `agent_picker.lua:328-330` schedules `M.agent_picker` after login succeeds. The guest runs `--headless` (`packaging_vm_spec.lua:164`), so the login progress window (`cliproxy.lua:1374`) never opens. The new "wait for a floating window" therefore can only match the reopened picker.
   - The picker is closed through its real cancel mapping (`float_picker.lua:1482/1500`), the same way a user would close it. No internals are poked.
   - The new assertions don't weaken the old ones: `chat_file ~= ""` blocks the empty-name case that used to fail.

2. **Critical findings:** none.

3. **Important findings**
   - `tests/integration/packaging_vm_spec.lua:156`: nothing pins the picker-settle step (family `fix-without-failing-regression`). Without the settle block in `vm_chat.lua:129-136` the spec stays green (I measured 17/0 twice). The guest's floating-window check runs synchronously after `run()` returns, so a reopen still queued in `vim.schedule` lands after the check.
     - **Fix sketch:** let pending events run before the check, e.g. `vim.wait(<login settle bound>, function() return false end)` or a `vim.wait` until the picker would have appeared, then assert there is no float. Alternatively, assert inside the probe after `ask()` that no floating window is open after a yield.
     - Then re-run the revert experiment and confirm it goes red.
     - This is the only instance of this family in the window. The `chat_file` and `enew` half does have a regression that fails without it.

4. **Minor findings**
   - `tests/packaging/vm_chat.lua:133`: `maparg('<Esc>', 'n', false, true).callback()` doesn't check that a callback exists, unlike the `<CR>` lookup at :121-122. If the mapping is missing, you get "attempt to call nil" instead of a clear message. The same applies to the existing `<Down>` call at :120.
   - ARCH-DRY (minor): the check "current window is floating" (`nvim_win_get_config(0).relative ~= ''`) now appears three times in `vm_chat.lua` (:117, :131, :135) and again in the spec (:156). A small `is_float(win)` helper would make it one definition.

5. **Test coverage notes**
   - At head, with TMPDIR outside the repo, the focused spec passed 17/0.
   - With the review sandbox's TMPDIR, which sits *inside* the checkout, the test failed at the guest script's first `confined()` call (`fake-chat.lua:5`, "guest chat root escaped"). That line is before `run("fake")`. In that run the starter also wrote `workshop/parley/vim-basics.md` into the enclosing repo, which I've left in this disposable checkout. This behaviour predates the diff: when the guest root sits inside a git project, the starter's project discovery takes over. It isn't caused by this change, but it's a real hole in confinement that you may want to track separately.
   - The red half of Done-when clause 1 (old assertion plus `enew`) is deterministic by construction.

6. **Architectural notes**
   - ARCH-DRY: pass, apart from the minor float-check duplication above.
   - ARCH-PURE: pass. All changes are in integration test glue, and there's no business logic to extract.
   - ARCH-PURPOSE: pass on the main purpose. Confinement is now asserted on the created object. The settle half is delivered in code but has no test pinning it (the Important finding).
   - Docs gate: no atlas or README change is needed, since this is test-only with no new user-facing surface. The `lessons.md` entry is accurate.

7. **Plan revision recommendations:** the Plan's regression bullet says the no-float assertion proves "the login UI settled inside the probe". Either make it actually prove that (the Important fix), or add a `## Revisions` entry saying the no-float check only covers picker reopens that land before `run()` returns.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: fix-without-failing-regression
    title: |
      Picker-settle half of the fix has no test that fails without it
    detail: |
      Deleting the settle block (wait for the reopened picker, then send Esc) at tests/packaging/vm_chat.lua:126-136 leaves the focused packaging_vm_spec green (17/0, two runs). The guest no-float assertion at tests/integration/packaging_vm_spec.lua:156 runs synchronously after run() returns, so a picker reopen still queued in vim.schedule is never seen. Done-when clause 2 ("settles the reopened picker before chat dispatch") is therefore unpinned. Fix: yield the event loop (vim.wait for a bounded window) before asserting no floating window, or assert it in the probe after ask() following a yield, then confirm the revert goes red. This is the only instance of this family in the window.
  - id: new
    severity: Minor
    kind: defect
    family: unguarded-keymap-callback
    title: |
      maparg Esc callback is invoked without checking it exists
    detail: |
      tests/packaging/vm_chat.lua:133 calls maparg('<Esc>','n',false,true).callback() directly. The sibling <CR> lookup at :121-122 checks the type first. The existing <Down> call at :120 has the same gap.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"60238089-c04f-4a99-a6c9-32c929b28ce4","repository":"github.com/xianxu/parley.nvim","issue_id":"000336","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/d38bcd8bd61a81eb","reviewed_head":"00221b88dc4012d833acf04d2d14012e8e19b00e","slot":"parley.nvim:3","requested_at":"2026-10-15T22:58:47.635331Z"},"phase":"finished","pid":94669,"started_at":"2026-10-15T22:58:48.131766Z","finished_at":"2026-10-15T23:01:58.562967Z","session_id":"6df3d759-2d5b-47a8-9d2c-93fbda2d5324","outcome":"returned"}] -->

---

## Re-review — 2026-10-15T16:10:43-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 336 — Flake: packaging VM guest chat confinement follows transient focus |
| repo | parley.nvim |
| issue file | workshop/issues/000336-packaging-vm-focus-flake.md |
| boundary | whole-issue close |
| milestone | — |
| window | 35d876d55d7940f20c3d6087846f4247d2b9b14d..01ebf08816a07f290c4382c016fc195792b43c19 |
| command | sdlc close --issue 336 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-15T16:10:43-07:00 |
| verdict | SHIP |

## Review

Checking the BR-1 fix: I'll run the focused packaging spec at head, then again with the settle block removed.

Green at head. Now removing the settle block (wait for picker, Esc, wait for settle).

Mutation goes red on both runs (16/1, `chat dispatch began while account connection was still open`), and the file is restored. Running the unit spec and lint as a last check.

```verdict
verdict: SHIP
confidence: high
```

Both prior findings are fixed, and I checked each fix by running the tests rather than trusting the commit messages. For BR-1, I deleted the settle block in a disposable copy: the lines in `tests/packaging/vm_chat.lua` that wait for the reopened model picker, press `<Esc>` and wait for the connection to close. With that block gone, the focused `packaging_vm_spec` failed 16/1 on both runs with `vm_chat.lua:45: chat dispatch began while account connection was still open`. With the block restored it passed 17/0. The new check is deterministic. The open-connection flag is set when `connect` starts and is cleared only when the picker's `on_select`/`on_cancel` runs, or when the picker fails to open (`lua/parley/starter_onboarding.lua:22-36`). So if the probe never dismisses the picker, `ask()` always sees an open connection. For BR-2, the `<Down>`, `<CR>` and `<Esc>` presses now all go through one guarded `press()` helper (`vm_chat.lua:35-39`). I found nothing new that blocks the close.

1. **Strengths**
   - `lua/parley/starter_onboarding.lua:43-45`: `is_connecting` reads the state the flow already keeps; nothing new is tracked. Because that state is cleared only when the returned picker resolves, it fits the Spec's point that the credential file appearing does not mean login is done.
   - `tests/packaging/vm_chat.lua:45-46`: the assertion sits at the start of chat dispatch, so it fires on any path that skips the settle step, not only the one that was deleted.
   - `tests/unit/starter_onboarding_spec.lua:49-60`: covers both outcomes, select and cancel, plus the state before connecting. It runs with no IO.
   - `tests/integration/packaging_vm_spec.lua:158-160`: running `enew` before the confinement assertion, and asserting on `result.chat_file`, removes the dependence on focus. The `~= ""` guard blocks the old empty-name failure.
   - The issue's Revisions entry honestly says the no-float check after `run()` can't see a picker reopen that is still queued, and names `is_connecting` as the real check.

2. **Critical findings:** none.

3. **Important findings:** none.

4. **Minor findings:** none new. The comment at `packaging_vm_spec.lua:155` reads as if the no-float assertion is what pins the settle step. The Revisions entry already says otherwise, so I'm not raising it.

5. **Test coverage notes** (all run with TMPDIR set outside the checkout)
   - Focused `packaging_vm_spec` at head: 17/0.
   - With the settle block deleted: 16/1 on both runs, failing on the expected assertion. The file is restored and the tree is clean.
   - `starter_onboarding_spec`: 7/0.
   - `make lint`: 0 warnings, 0 errors in 732 files.
   - I did not re-run the full parallel suite. That evidence is in the implementer's Log.

6. **Architecture**
   - ARCH-DRY: pass. The floating-window check is now one `is_float` helper, and the keymap calls go through one `press` helper.
   - ARCH-PURE: pass. `is_connecting` is a deterministic read of module state, unit-tested without IO. The rest of the change is test glue.
   - ARCH-PURPOSE: pass. Both halves of Done-when clause 2 now have a test that fails without them, and confinement is asserted on the chat the probe created.
   - Docs gate: `atlas/infra/starter.md` documents the new `is_connecting` query. No README change is needed because nothing user-facing changed.

7. **Plan revision recommendations:** none. The existing Revisions entry already matches the code.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Reverted settle block in disposable checkout; focused packaging_vm_spec went 16/1 twice (vm_chat.lua:45 "chat dispatch began while account connection was still open"); restored 17/0.
  - id: BR-2
    disposition: addressed
    note: |
      All three maparg presses (Down, CR, Esc) now go through press() at vm_chat.lua:35-39, which asserts a callback exists; no other unguarded instance in the window.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"3e3d67fb-4aa1-4947-9408-620cb6dc89c9","repository":"github.com/xianxu/parley.nvim","issue_id":"000336","recipe":"small-diff-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/1e411a8717f267e7","reviewed_head":"01ebf08816a07f290c4382c016fc195792b43c19","slot":"parley.nvim:3","requested_at":"2026-10-15T23:08:18.663769Z"},"phase":"finished","pid":54092,"started_at":"2026-10-15T23:08:18.767704Z","finished_at":"2026-10-15T23:10:35.918953Z","session_id":"28c82759-0ee7-42c5-965e-f7a19479ab88","outcome":"returned"}] -->
