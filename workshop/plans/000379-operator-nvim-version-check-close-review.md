# Boundary Review — parley.nvim#379 (whole-issue close)

| field | value |
|-------|-------|
| issue | 379 — Check operator Neovim compatibility |
| repo | parley.nvim |
| issue file | workshop/issues/000379-operator-nvim-version-check.md |
| boundary | whole-issue close |
| milestone | — |
| window | 5cbad4b335ba1609bc5c481c99d4f6d36b076fbb..3f6ec81426a78f71a94b976be4632feb55899547 |
| command | sdlc close --issue 379 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-17T21:22:13-07:00 |
| verdict | SHIP |

## Review

Still reviewing the #379 diff. Next I'm running the new spec and the script flags against the real binaries.

```verdict
verdict: SHIP
confidence: high
```

The diff delivers the plan's policy. Neovim 0.11 or newer is supported, and that minimum is defined once, in `lua/parley/version_support.lua`. Both `setup()` and the `--supported` check in `scripts/test-nvim.sh` read it. `make test` now ends with a `test-compat` pass that reruns unit and integration on the nvim first on PATH whenever its `--version` differs from the preferred runtime. So the 0.12 runtime chosen for speed can no longer hide a break that only 0.11 has, like the SHA-256 one. I checked the behaviour myself:
- `--installed` printed `/opt/homebrew/bin`, the PATH nvim (0.11.7).
- With no flag, the script still printed `/opt/homebrew/opt/neovim/bin` (0.12.5).
- `--installed` ignored `PARLEY_TEST_NVIM`.
- `--supported` exited 0 on 0.11.7 and 127 on a missing directory.
- The new spec passed 5 of 5 under the harness on both 0.11.7 and 0.12.5.
- No path in the diff is on `local-gates-guard`'s protected list (`.github/workflows/local-gates-guard.yml:56-70`), so the plan is right that no operator verification or label is needed.

Only Minor findings remain, and none blocks SHIP.

1. **Strengths**
   - One owner for the minimum: `version_support.MINIMUM` is read by `setup()` (`lua/parley/init.lua:545`) and by the compat check, which loads the same module inside the installed nvim (`scripts/test-nvim.sh:29-33`). The policy cannot drift between them (ARCH-DRY pass).
   - `supported()` and `refusal()` are pure and tested without IO (`tests/unit/version_support_spec.lua:8-27`). Only the `setup()` wiring test stubs `vim.version` and `vim.notify` (ARCH-PURE pass).
   - Runtime discovery stays in `test-nvim.sh`. Adding `--installed` and `--supported` left the no-flag output unchanged, and the inner make reuses the existing `PARLEY_TEST_NVIM` override, so `TEST_NVIM_DIR` and PATH come from it with no new mechanism.
   - The compat pass is skipped when the two versions match (CI, or a machine with only 0.12) or when no nvim is on PATH, and it says why it skipped.
   - All four Done-when clauses are met (ARCH-PURPOSE pass):
     - The supported versions are documented in `TOOLING.md`, `atlas/infra/test_harness.md`, `atlas/infra/config.md` and `README.md`.
     - The installed version is now exercised.
     - The unsupported path gives a clear diagnostic both at `setup()` and in the compat pass.
     - The local-gate position is stated in the plan.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - **The `--supported` probe passes when it errors** (`scripts/test-nvim.sh:30-33`). I confirmed that nvim exits 0 after an error in a `-c` Lua command (`nvim --headless -c 'lua error("boom")' -c 'qa!'` gives rc=0). If `require` or `vim.version()` throws, `--supported` reports "supported" and the compat pass goes ahead. The suite would most likely still go red, but without the minimum-version message.
     - Fix: wrap the check in `pcall` and treat any error, or any outcome other than "supported", as `cquit 1`. Alternatively, print yes/no and grep for it, as `has_mcode_fix` does.
     - Family in this window: the `--supported` probe is the only instance. `has_mcode_fix` already fails safe because it greps for `^yes$`.
   - **`help-parley` does not list the new `make test-compat` target** (`Makefile.parley:7-26`). `TOOLING.md` documents it.
   - **The `setup()` refusal test leaves `parley._setup_called = nil`** (`tests/unit/version_support_spec.lua:36`) and does not restore it. This is harmless, since each spec file runs in its own process, but it is not tidy.

5. **Test coverage notes**
   - Both sides of the version rule are covered: versions at and above the minimum are supported, older ones are refused, and the refusal text is pinned. The `setup()` early return is shown by `_setup_called` staying nil and by the single ERROR notice.
   - The shell side is only manually verified: the skip branches, the `--supported` refusal under a raised MINIMUM, and propagation of a red compat run. The issue log records this as a mutation check. That is acceptable for glue this thin.
   - I did not run the full `make test`. The plan sequences the recorded suite after #373 lands, so on this base the compat pass is expected to fail on the five E976 specs.

6. **Architectural notes for upcoming work**
   - If more probes of the installed nvim are added, factor out a shared "run a Lua predicate in DIR/nvim and fail safe" helper in `test-nvim.sh`. That would serve `has_mcode_fix`, `--supported` and any new probe.

7. **Plan revision recommendations:** none. The plan matches the code.

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: probe-fail-open
    title: |
      scripts/test-nvim.sh --supported reports supported when its Lua check errors
    detail: |
      nvim headless exits 0 after a -c Lua error (verified rc=0), so if require or vim.version() throws, the probe passes and the compat pass runs without the minimum-version message. Fix by wrapping the check in pcall and doing cquit 1 on any error, or by printing yes/no and grepping like has_mcode_fix. The --supported probe is the only instance in this window.
  - id: new
    severity: Minor
    kind: defect
    family: help-listing-covers-targets
    title: |
      help-parley does not list the new make test-compat target
    detail: |
      Makefile.parley:7-26 lists every other test target; TOOLING.md documents test-compat but make help does not show it.
  - id: new
    severity: Minor
    kind: defect
    family: test-restores-global-state
    title: |
      version_support_spec does not restore parley._setup_called after the setup refusal case
    detail: |
      tests/unit/version_support_spec.lua:36 sets _setup_called to nil and never restores it. Harmless because each spec file runs in its own process.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"70f12047-441f-495f-b592-b4c283e9476d","repository":"github.com/xianxu/parley.nvim","issue_id":"000379","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/92f9b3e55b147601","reviewed_head":"3f6ec81426a78f71a94b976be4632feb55899547","slot":"parley.nvim:4","requested_at":"2026-10-18T04:18:53.78209Z"},"phase":"finished","pid":53810,"started_at":"2026-10-18T04:18:53.877099Z","finished_at":"2026-10-18T04:22:04.964318Z","session_id":"24186cc3-723c-449f-ba65-b8079098cb38","outcome":"returned"}] -->

---

## Re-review — 2026-10-17T21:29:04-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 379 — Check operator Neovim compatibility |
| repo | parley.nvim |
| issue file | workshop/issues/000379-operator-nvim-version-check.md |
| boundary | whole-issue close |
| milestone | — |
| window | 5faf003ee134d13aa7158fcd5ec6b51a921040eb..9d14002faac5989a513086a70facc27869593ef5 |
| command | sdlc close --issue 379 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-17T21:29:04-07:00 |
| verdict | SHIP |

## Review

I'm checking whether the spec still passes. My direct plenary run hung, so I'm stopping it and switching to the repo's make target.

```verdict
verdict: SHIP
confidence: high
```

All three prior Minor findings are fixed, and the interdiff adds no new defects. I tested the `--supported` probe in this checkout, including two deliberate breakages. It accepts 0.11.7 with rc=0. It returns rc=1 with a message in each failure case: a missing nvim binary, a `version_support` module that throws on `require`, a `supported()` that throws at runtime, and a MINIMUM raised to 0.99, which prints the refusal. `make help-parley` now lists `test-compat`. Run through the harness (`make test-spec SPEC=infra/test_harness`), `version_support_spec` passes 5 of 5. The issue-file diff only records the close and the fixes. `## Spec`, `## Revisions` and `## Done when` are unchanged, and nothing beyond what the findings asked for was added, so the scope has not changed. There were no conflict resolutions to judge.

1. **Strengths**
   - `scripts/test-nvim.sh:29-38`: the probe now uses the same rule as `has_mcode_fix`: only an exact `yes` on stdout passes. A runtime error that `pcall` doesn't catch is still covered, because stdout stays empty and the probe refuses. That fixes the whole fail-open class, not only the `require` failure.
   - The probe reports why it refused: the refusal message from `version_support.refusal`, "could not load parley.version_support", or "did not answer".
   - `tests/unit/version_support_spec.lua:31-40`: the test saves `_setup_called` before the call, restores it, and then asserts on the saved value. Restoring before asserting means the cleanup still happens when an assertion fails.

2. **Critical:** none.
3. **Important:** none.
4. **Minor:** none new.
5. **Test coverage**
   - BR-1 is shell glue with no automated test. I covered it by breaking the module on purpose, as listed above, which is reasonable for a probe this small.
   - BR-3 is test hygiene, so no failing test can demonstrate it. The fix is plainly visible in the diff.
6. **Architecture**
   - **ARCH-DRY:** pass. The probe reuses the pattern `has_mcode_fix` already uses. The earlier suggestion to share a "Lua predicate in DIR/nvim, fail closed" helper still applies, but only once a third probe appears.
   - **ARCH-PURE:** pass. The policy still lives only in the pure module `version_support`, and the shell does nothing but call it.
   - **ARCH-PURPOSE:** pass. All three fixes cover the class each finding named. There are two nvim probes in `test-nvim.sh`, and both now fail closed. `help-parley` lists every test target. The spec restores every global it changes: `vim.version`, `vim.notify` and `_setup_called`.
7. **Plan revisions:** none.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Probe accepts only an exact "yes". Verified: 0.11.7 rc=0; missing nvim, require throws, supported() throws, MINIMUM raised to 0.99 each rc=1 with a message.
  - id: BR-2
    disposition: addressed
    note: |
      Makefile.parley:14 lists test-compat, and make help-parley shows it.
  - id: BR-3
    disposition: addressed
    note: |
      The spec saves and restores _setup_called alongside vim.version and vim.notify, then asserts on the captured value. The spec passes 5 of 5 under the harness.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"cad3c3a9-d530-4e3c-98a3-3ec4d0ec64a3","repository":"github.com/xianxu/parley.nvim","issue_id":"000379","recipe":"fix-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/da63bc43dbfdeccd","reviewed_head":"9d14002faac5989a513086a70facc27869593ef5","slot":"parley.nvim:4","requested_at":"2026-10-18T04:23:35.924597Z"},"phase":"finished","pid":96448,"started_at":"2026-10-18T04:23:36.094026Z","finished_at":"2026-10-18T04:29:03.594372Z","session_id":"8270d301-2279-4a3b-9783-8e27da3644db","outcome":"returned"}] -->
