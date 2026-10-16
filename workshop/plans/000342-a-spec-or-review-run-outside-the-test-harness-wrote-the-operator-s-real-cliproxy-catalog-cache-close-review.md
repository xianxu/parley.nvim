# Boundary Review — parley.nvim#342 (whole-issue close)

| field | value |
|-------|-------|
| issue | 342 — A spec or review run outside the test harness wrote the operator's real cliproxy catalog cache |
| repo | parley.nvim |
| issue file | workshop/issues/000342-a-spec-or-review-run-outside-the-test-harness-wrote-the-operator-s-real-cliproxy-catalog-cache.md |
| boundary | whole-issue close |
| milestone | — |
| window | 3d0c2369d1e25b61819b3554cdf1fd7950e7823f..8089b376b0b3ab06e3a566a96673079411191d44 |
| command | sdlc close --issue 342 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-15T21:06:04-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Checking the remaining child-spawn sites and stale direct-run docs.

```verdict
verdict: FIX-THEN-SHIP
confidence: medium
```

The core change works. `parley.test_isolation` is one small rule with no side effects, and it backs both guards: the harness init and cliproxy's `data_root()`. `TEST_ENV` exports the marker, and every cliproxy write path derives from `data_root()`: catalog at `lua/parley/cliproxy.lua:1682` and `:1735`, config at `:249` and `:257`, bin at `:2020`, staging at `:2113`. So the writer guard covers every cliproxy write. The `branch_point()` fix is one shared helper used at both call sites. Two cheap gaps keep this from SHIP:
- **`XDG_CONFIG_HOME` mismatch.** The harness does not pin `XDG_CONFIG_HOME`, but `check()` rejects it when it is set outside the root. An operator who exports it cannot run `make test` at all.
- **Stale run instructions.** The fix updated the usage comment in `refresh_goldens.lua`, but two other scripts still tell readers to run `nvim -u tests/minimal_init.vim` directly. The guard now refuses that run.

I did not re-run the suite or revert the guards to watch the tests fail. The red-first results come from the Log and have not been checked independently.

1. **Strengths**
   - `lua/parley/test_isolation.lua:7-27`: `resolved()` follows symlinks up to the nearest existing ancestor, so `/tmp` and `/private/tmp` compare equal even for roots that don't exist yet. `inside()` checks the `/` boundary, so a sibling path like `root-sibling` is not treated as inside; a unit test pins this.
   - `lua/parley/cliproxy.lua:227-239`: the writer guard sits at the one function every write goes through, rather than at each write. It is gated on `PARLEY_TEST_MODE`, which only the harness init sets, so production behaviour is unchanged.
   - `tests/integration/test_isolation_spec.lua` tests both the refusal and the normal run: no marker, a root outside the marked one, and a fully isolated child. In each case it checks whether the sentinel file appeared.
   - `scripts/check-spell-compatibility.sh:11-13` declares its own temp root as the isolation root instead of skipping the check, so there is one definition of isolation everywhere.
   - `tests/arch/single_source_sweeps_spec.lua:100-105`: both `merge-base` call sites now use one helper (ARCH-DRY).

2. **Critical findings:** none.

3. **Important findings**
   - **`Makefile.parley:54` / `lua/parley/test_isolation.lua:41-46`.** `check()` refuses an `XDG_CONFIG_HOME` that is set and points outside the root. `TEST_ENV` never sets or clears it, so a value from the operator's shell passes straight through. Result: `make test` fails for anyone who exports `XDG_CONFIG_HOME`, and the message tells them to run through make, which is what they just did. **Fix:** add `XDG_CONFIG_HOME="$(TEST_XDG)/config"` to `TEST_ENV` (or `env -u` it), and add a test that runs the harness with an outside `XDG_CONFIG_HOME` exported. Family members: `XDG_CONFIG_HOME` is the only root `check()` inspects that `TEST_ENV` does not set.
   - **ARCH-PURPOSE: documented direct runs not swept.** The fix updated `scripts/refresh_goldens.lua` and added `make goldens`. Two other documented direct runs are now refused:
     - `scripts/record_fixtures.lua:10-13` still says "or directly: … `nvim --headless --noplugin -u tests/minimal_init.vim`". `make fixtures` exists, so this is just a doc fix.
     - `tests/perf_chat_finder.lua:4` documents `nvim --headless -u tests/minimal_init.vim -l tests/perf_chat_finder.lua`. No make target runs it, so this benchmark now has no working entry point. It needs a make target, or a usage line that wraps the run in the harness env.

4. **Minor findings**
   - The Spec's third bullet (close-review instructions should say to use `make test-spec`) is deferred because the dispatcher lives in ariadne. The Log notes this, but there is no follow-up issue reference.
   - Done-when asks for "a child nvim on a spec file". The regression uses `-c` commands instead. That is equivalent, since the guard runs before plenary or any `-c`, but the wording differs.
   - `tests/minimal_init.vim:14`: if `require("parley.test_isolation")` fails (for example, nvim started from a cwd where `rtp+=.` doesn't find parley), the heredoc error does not stop startup, and the guard is skipped. This is unlikely in practice, but the guard should stop the run if the require fails.
   - Edge case: `PARLEY_TEST_ENV_ROOT="/"` is stripped to an empty string and then resolves to the cwd. Harmless, but surprising.

5. **Test coverage notes:**
   - **Unit tests** cover the marker being absent, roots outside the marked one, a prefix that is not a parent, symlinks, and cliproxy refusing or allowing a root.
   - **Integration test** covers the init refusing before any command runs, in all three states.
   - **Missing:** a harness run with an inherited `XDG_CONFIG_HOME` set.
   - The Done-when catalog clause is tested through `_catalog_path`, not through a real fetch against `fake_cliproxy`. That is acceptable because every write derives from `data_root()`.

6. **Architectural notes**
   - **ARCH-DRY: pass.** One isolation rule is shared by the init, cliproxy and the spell script, and `branch_point()` is a single helper.
   - **ARCH-PURE: pass.** `check(env)` and `inside` take their input as arguments and are unit-tested without mocks. The only file-system access is `fs_realpath` reads.
   - **ARCH-PURPOSE: flagged.** Most of the purpose is delivered, but the class of documented direct-run entry points was only partly swept (see Important).
   - Future writers outside cliproxy that touch real XDG paths get only the init-level protection. If more writers appear, consider a shared test-mode root assertion in `parley.fs`.

7. **Plan revision recommendations**
   - Add a `## Revisions` entry. It should say that `TEST_ENV` pins `XDG_CONFIG_HOME`, or that `check()` ignores it when the harness doesn't set it. It should also list the full set of direct-run usage docs (`refresh_goldens.lua`, `record_fixtures.lua`, `perf_chat_finder.lua`) and how each one is now run.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: harness-env-pins-every-checked-root
    title: |
      TEST_ENV does not pin XDG_CONFIG_HOME, but check() refuses an outside value, so make test fails for operators who export it
    detail: |
      Makefile.parley:54 sets HOME and the DATA, STATE and CACHE XDG roots only; test_isolation.lua:41-46 rejects a set XDG_CONFIG_HOME outside PARLEY_TEST_ENV_ROOT. An exported XDG_CONFIG_HOME is inherited into every harness nvim, and minimal_init then cquits on every spec with a "run through make" hint. Fix: add XDG_CONFIG_HOME="$(TEST_XDG)/config" to TEST_ENV (or unset it), plus a regression test. XDG_CONFIG_HOME is the only member of this family.
  - id: new
    severity: Important
    kind: defect
    family: direct-run-entry-points-swept
    title: |
      Documented direct nvim -u tests/minimal_init.vim runs left in record_fixtures.lua and perf_chat_finder.lua; the guard now refuses both
    detail: |
      refresh_goldens.lua was moved to make goldens, but scripts/record_fixtures.lua:10-13 still documents an "or directly" run. tests/perf_chat_finder.lua:4 documents a direct -l run and has no make target, so the benchmark has no working entry point. Sweep the family: point record_fixtures at make fixtures only, and give perf_chat_finder a make target under TEST_ENV or a harness-wrapped usage line.
  - id: new
    severity: Minor
    kind: defect
    family: spec-clause-deferred-untracked
    title: |
      Spec bullet 3 (close-review instructions say to use make test-spec) deferred to ariadne without a tracked follow-up
    detail: |
      The Log says the dispatcher is out of reach here. Record a follow-up issue reference so the deferral is tracked.
  - id: new
    severity: Minor
    kind: defect
    family: guard-fails-closed
    title: |
      minimal_init isolation heredoc does not stop the run if require of parley.test_isolation errors
    detail: |
      A Lua error in an init heredoc is reported and startup continues, so the guard is skipped. Wrap the check in pcall and cquit when it fails.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"25bc033e-e7a4-4ffb-b37b-41c680091573","repository":"github.com/xianxu/parley.nvim","issue_id":"000342","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/c750dab8ab35d7bb","reviewed_head":"8089b376b0b3ab06e3a566a96673079411191d44","slot":"parley.nvim:3","requested_at":"2026-10-16T04:04:41.906788Z"},"phase":"finished","pid":84955,"started_at":"2026-10-16T04:04:42.518822Z","finished_at":"2026-10-16T04:06:03.527915Z","session_id":"a2147ce9-5198-40a7-bc1d-2bf2c21b358f","outcome":"returned"}] -->

---

## Re-review — 2026-10-15T21:26:26-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 342 — A spec or review run outside the test harness wrote the operator's real cliproxy catalog cache |
| repo | parley.nvim |
| issue file | workshop/issues/000342-a-spec-or-review-run-outside-the-test-harness-wrote-the-operator-s-real-cliproxy-catalog-cache.md |
| boundary | whole-issue close |
| milestone | — |
| window | 3d0c2369d1e25b61819b3554cdf1fd7950e7823f..d4677890cc2ba8539394c6d4f9c97ded4d3176f3 |
| command | sdlc close --issue 342 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-15T21:26:26-07:00 |
| verdict | SHIP |

## Review

Prior findings are verified in the diff. Next I'm checking the help text and running the new specs.

```verdict
verdict: SHIP
confidence: high
```

All four findings from the earlier round are dealt with, and the window now does what #342 asked for. `tests/minimal_init.vim` refuses to run a spec unless HOME and every XDG root sit inside `PARLEY_TEST_ENV_ROOT`. If the isolation check itself can't load, it still refuses. Under test mode, `cliproxy.data_root()` refuses any root outside the isolated env. `TEST_ENV` now pins every root the check inspects, and a test enforces that. The direct `-u tests/minimal_init.vim` instructions were swept and now point at make targets.

I ran `make test-spec SPEC=infra/test_harness` in the pinned checkout:
- **New specs pass:** unit `test_isolation_spec` 9/0 and integration `test_isolation_spec` 4/0.
- **8 failures in `tests/arch/scratch_placement_spec.lua`:** these come from this review sandbox, not the diff. The sandbox sets `TMPDIR` under `.sdlc-review/tmp` inside the checkout, so `TEST_ENV_ROOT` lands inside the repo.

Nothing blocks SHIP. One Minor note: two new make targets are missing from `make help`.

1. **Strengths**
   - `lua/parley/test_isolation.lua:10`: `ROOTS` is the single list of guarded roots. `check()` iterates it, and `tests/unit/test_isolation_spec.lua:47-60` checks `Makefile.parley`'s `TEST_ENV` against it. A newly guarded root can't go unpinned without failing that test (ARCH-DRY pass).
   - `tests/minimal_init.vim:15-23`: the guard fails closed. A `require` error becomes a refusal plus `cquit 3`. The integration case "fails closed when the isolation check itself cannot load" exercises this by running from a directory where parley isn't on the runtimepath.
   - `lua/parley/cliproxy.lua:227-239`: the writer-side guard is gated on `PARLEY_TEST_MODE`, which only the harness sets, so production behaviour doesn't change. The unit test covers both directions: an outside root errors, and the isolated default plus a tempname override are allowed.
   - `tests/integration/test_isolation_spec.lua`: covers both states of the Done-when clause. Unmarked or outside-root runs are refused with no sentinel file written. A fully isolated run proceeds and writes the sentinel.
   - `inside()` resolves the nearest existing ancestor, so a root that doesn't exist yet is still compared correctly under `/tmp` vs `/private/tmp` links. A sibling path that only shares a prefix (`root-sibling`) is rejected.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - `Makefile.parley:5-21`: the `help-parley` text doesn't list the new `make goldens` or `make perf-finder`. TOOLING.md:8 names both, but `make help` won't show them. These are the only two new targets in the window, and both are missing.

5. **Test coverage notes**
   - The BR-1 regression reads `Makefile.parley` and asserts that every `ROOTS` entry is assigned. Without the `XDG_CONFIG_HOME` pin it would fail.
   - The BR-4 regression enters the pcall branch. I didn't do a revert run myself. The integration case reaches that path because `set rtp+=.` resolves to the scratch directory.
   - `tests/packaging/test_local_app.py:430` sets `PARLEY_TEST_MODE=1` and inherits the harness marker. Its scratch is under `TMPDIR` (inside the root), so the cliproxy guard is satisfied there.

6. **Architecture**
   - **ARCH-DRY: pass.** `branch_point()` replaces the two inline `merge-base` calls in `single_source_sweeps_spec.lua`, and `ROOTS` is the one list of guarded roots.
   - **ARCH-PURE: pass.** `check(env)` and `inside` take their inputs as arguments; `inside` only reads the filesystem to resolve links. The IO parts (the heredoc and `cquit`) are a thin shell in `minimal_init.vim`.
   - **ARCH-PURPOSE: pass.**
     - The harness refuses non-isolated runs.
     - The writer refuses to write outside the isolated env.
     - Every documented direct entry point now goes through make: goldens, fixtures, perf-finder and the init's own usage line.
     - The remaining direct-run references are archival handoff notes under `workshop/continuation`.
     - The review-instruction clause was deliberately left out by TL decision. The guard enforces the same thing more strongly.

7. **Plan revisions:** none. The Core concepts table matches the code: `check`, `inside` and `test_isolation` are new in `lua/parley/test_isolation.lua`, and the modified entries all show the expected changes.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Makefile.parley:54 TEST_ENV pins XDG_CONFIG_HOME, PREP_TEST_ENV creates it; test_isolation.ROOTS is the single list and tests/unit/test_isolation_spec.lua:47-60 asserts TEST_ENV assigns every entry (passes 9/0 here).
  - id: BR-2
    disposition: addressed
    note: |
      record_fixtures.lua and perf_chat_finder.lua point at make fixtures and the new make perf-finder (Makefile.parley:233-239, under TEST_ENV); tree grep finds no remaining live direct-run instructions outside archival workshop/continuation notes.
  - id: BR-3
    disposition: withdrawn
    note: |
      Log records a TL decision with rationale - the init guard enforces the make route with an actionable message, stronger than an instruction; the deferral is a recorded decision, not untracked.
  - id: BR-4
    disposition: addressed
    note: |
      minimal_init.vim:16-17 wraps the require+check in pcall and converts failure into a refusal; integration case "fails closed when the isolation check itself cannot load" exercises it (4/0 here).
findings:
  - id: new
    severity: Minor
    kind: defect
    family: make-help-lists-every-target
    title: |
      help-parley omits the new make goldens and make perf-finder targets
    detail: |
      Makefile.parley:5-21 help text lists test, perf, fixtures etc. but not the two targets this window adds (the only two new targets); TOOLING.md:8 names them, make help does not.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"4e7f66b2-bb41-44c0-a896-b70f2646446a","repository":"github.com/xianxu/parley.nvim","issue_id":"000342","recipe":"small-diff-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/2fe17c524fe833bc","reviewed_head":"d4677890cc2ba8539394c6d4f9c97ded4d3176f3","slot":"parley.nvim:3","requested_at":"2026-10-16T04:24:21.228857Z"},"phase":"finished","pid":66902,"started_at":"2026-10-16T04:24:21.325645Z","finished_at":"2026-10-16T04:26:25.733014Z","session_id":"f1f531f0-3fa2-4975-98b0-b752cf805f31","outcome":"returned"}] -->
