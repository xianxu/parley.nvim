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
