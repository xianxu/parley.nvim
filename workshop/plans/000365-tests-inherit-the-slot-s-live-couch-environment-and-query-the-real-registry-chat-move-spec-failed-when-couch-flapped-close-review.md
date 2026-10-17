# Boundary Review — parley.nvim#365 (whole-issue close)

| field | value |
|-------|-------|
| issue | 365 — Tests inherit the slot's live Couch environment and query the real registry (chat_move_spec failed when Couch flapped) |
| repo | parley.nvim |
| issue file | workshop/issues/000365-tests-inherit-the-slot-s-live-couch-environment-and-query-the-real-registry-chat-move-spec-failed-when-couch-flapped.md |
| boundary | whole-issue close |
| milestone | — |
| window | e4ba9a07c715f6517597a3761647330afdc4c3de..d897fc1a33dc1e2832b67f6237e9688f12a7e98a |
| command | sdlc close --issue 365 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T18:12:55-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Diff and issue reviewed; now running the new isolation specs through the harness to verify them.

Sentinel gate verified end-to-end. Checking the couch live-conformance case that now always runs pending.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The issue's purpose is delivered, and I checked it by running the code rather than trusting the log. Every nvim launch in `Makefile.parley` now goes through `scripts/test-env.sh`, which starts from `env -i` and copies only an allowlist. The sentinel `couch` and `pair` record the call and refuse it, and the Makefile gate fails a run whose sentinel log is not empty.

I ran the `atlas/infra/test_harness.md` spec set with `COUCH_THREAD_SCOPE` and `COUCH_THREAD_TAG` exported, and all the new #365 cases passed. Two further checks:
- **Mutation test:** I added `COUCH_THREAD_SCOPE` to the allowlist, and both the in-process guard and the exact-allowlist case went red.
- **Gate probe:** I ran a bare `couch` through `TEST_RUN` followed by `SENTINEL_CHECK`. It printed the logged call and the target exited with an error.

`scratch_placement_spec` failed, but only because this review sandbox puts TMPDIR inside the checkout. That is not caused by this diff.

Nothing blocks the ship. There are three cheap Important fixes:
1. The allowlist quietly broke two opt-in live conformance paths.
2. Credentials passed through `PARLEY_TEST_ENV_PASS` end up in `env`'s command-line arguments.
3. The Couch `--actors` live check can no longer run anywhere.

**1. Strengths**
- An allowlist instead of a denylist (`scripts/test-env.sh:19-21`), with a single owner of the list. It is pinned by an exact-set test that runs the launcher with a polluted environment (`tests/integration/test_isolation_spec.lua:93-107`).
- The sentinel gate gives positive evidence that no spec reached the real CLI, and it is wired into every target beside the orphan gate (`Makefile.parley:63-64`).
- A structural guard (`tests/unit/test_isolation_spec.lua:97-110`) fails if any Makefile nvim launch bypasses the launcher, and it checks a minimum launch count so the scan can't go stale silently.
- `ambient()` is pure and unit-tested with a table input. The `NVIM` exclusion is documented in the code and in the Log.
- The atlas entry explains why the change was made, not just what it does.

**2. Critical findings:** none.

**3. Important findings**
- **The allowlist broke opt-in live checks (ARCH-MOCK, ARCH-PURPOSE).** `PARLEY_LIVE_CONFORMANCE=1` still gets through, but `CLIPROXYAPI_API_KEY` no longer does.
  - `tests/integration/cliproxy_tool_conformance_spec.lua:53` reads that key, and its skip message at `:120` tells the operator to "set CLIPROXYAPI_API_KEY … then re-run". Under the harness that advice now does nothing.
  - The atlas says only `make fixtures` names credentials.
  - Fix: either let a `PARLEY_LIVE_*` opt-in carry the credentials it needs (for example, the live conformance opt-in also passes `CLIPROXYAPI_API_KEY`), or document `PARLEY_TEST_ENV_PASS=CLIPROXYAPI_API_KEY make …` and update the skip message.
  - Sweep the other `PARLEY_LIVE_*` specs for the same problem. For example, the live clipboard check on Linux needs `DISPLAY`/`WAYLAND_DISPLAY`.
- **Credentials reach a subprocess's arguments (ARCH-SECURE).** `scripts/test-env.sh:60` runs `exec /usr/bin/env -i "NAME=value" …`. With `make fixtures`, the API keys passed through `PARLEY_TEST_ENV_PASS` become arguments of the `env` process and are briefly visible in `ps`. Fix: drop non-allowlisted names with `unset` in the script itself and then `exec "$@"`, so no value is ever placed in an argument list.
- **The Couch `--actors` live check is now permanently pending (ARCH-MOCK).** `tests/unit/couch_spec.lua:33-45` gates on `couch.thread()`, which can never be set under the launcher. Even if it were, `couch` would resolve to the sentinel and trip the gate. The Log calls this "by design", but no opt-in replaces it, and `check-couch-registry-conformance.py` covers the registry, not `--actors`. Fix: gate the case on a `PARLEY_LIVE_COUCH=1` opt-in that reads the real thread and binary from explicitly passed names, or move the check into the conformance script.

**4. Minor findings**
- No automated test checks that each target runs `SENTINEL_CHECK`. The launch scan covers the launcher only; I verified the gate by hand.
- A spec using `clear_env` drops `PARLEY_TEST_SENTINEL_LOG`. The sentinel then logs to `/dev/null`: the call is still refused, but it isn't recorded for the gate.
- `make -j test-unit test-integration` would let one target's `PREP_TEST_ENV` empty the other's sentinel log (ARCH-ORDER). Plain `make test` runs serially, so it is unaffected.
- `test-clean-env` doesn't remove `sentinel.log`. It is emptied on every run, so its size stays bounded (ARCH-FUNERAL passes).
- The "bad name in PARLEY_TEST_ENV_PASS" error message also fires for `PARLEY_LIVE_*` names (`scripts/test-env.sh:38`).

**5. Test coverage notes**
- The guard cases fail without the fix (mutation confirmed above).
- The sentinel's logging format and exit code 97 are pinned, as is the credential pass-through.
- Missing: a test that the Makefile gate fails on a non-empty log.

**6. Architectural notes**
- ARCH-DRY: pass. The list has one owner.
- ARCH-PURE: pass. `ambient()` is pure, and the launcher is the IO shell.
- ARCH-PURPOSE: pass on the core purpose (the shadow-sweep found 7 of 7 launches routed through the launcher). It is reduced only by the live-check regressions above.
- ARCH-MOCK: flagged above. Existing specs install a fake bin ahead of the sentinel, which is the right seam.
- ARCH-CONSTRAINTS: pass. The cost is one extra `sh` per spec process.
- ARCH-SECURE: flagged above (credentials in arguments). Otherwise this change improves isolation.
- ARCH-ORDER: minor note above.
- ARCH-FUNERAL: pass.
- README: no new end-user surface. `PARLEY_TEST_ENV_PASS` is a harness knob and is documented in the atlas.

**7. Plan revision recommendations**
- Add a `## Revisions` entry: live opt-in checks that need credentials or display variables must name them, and say how (this ties to the cliproxy finding).
- Add a `## Revisions` entry replacing "`couch_spec` live case runs pending by design" with an explicit `PARLEY_LIVE_COUCH` opt-in, or with a pointer to a conformance script that covers `--actors`.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: allowlist-strands-live-optins
    title: |
      Allowlist drops credentials and display variables that PARLEY_LIVE_* opt-in specs need (CLIPROXYAPI_API_KEY)
    detail: |
      scripts/test-env.sh passes PARLEY_LIVE_CONFORMANCE but not CLIPROXYAPI_API_KEY, which tests/integration/cliproxy_tool_conformance_spec.lua:53 reads. Its skip message at :120 ("set CLIPROXYAPI_API_KEY then re-run") does nothing under the harness. Let each live opt-in carry its named credentials, or document PARLEY_TEST_ENV_PASS for it, and sweep the other PARLEY_LIVE_* specs (for example DISPLAY for the live clipboard check). ARCH-MOCK / ARCH-PURPOSE.
  - id: new
    severity: Important
    kind: defect
    family: credential-in-argv
    title: |
      test-env.sh puts PARLEY_TEST_ENV_PASS credentials into the env -i argument list
    detail: |
      scripts/test-env.sh:60 runs exec /usr/bin/env -i NAME=value ..., so make fixtures exposes the API keys as process arguments (briefly visible in ps). Instead, unset non-allowlisted names in the shell and exec "$@", so values never reach an argument list. ARCH-SECURE.
  - id: new
    severity: Important
    kind: defect
    family: live-conformance-disabled
    title: |
      Couch --actors live conformance case in couch_spec can no longer run anywhere
    detail: |
      tests/unit/couch_spec.lua:33-45 gates on an ambient Couch thread, which the launcher now always strips, and a bare couch now resolves to the sentinel. No opt-in replaces it, and check-couch-registry-conformance.py does not cover --actors. Add a PARLEY_LIVE_COUCH opt-in that passes the thread names and uses the real binary explicitly, or move the check into the conformance script. ARCH-MOCK.
  - id: new
    severity: Minor
    kind: defect
    family: gate-wiring-untested
    title: |
      No test pins that every target runs SENTINEL_CHECK after its specs
    detail: |
      The launch scan in tests/unit/test_isolation_spec.lua checks only the launcher prefix. A target that drops SENTINEL_CHECK would go unnoticed. I verified the gate manually with a wrapper makefile.
  - id: new
    severity: Minor
    kind: defect
    family: shared-run-artifact-race
    title: |
      Concurrent make targets share and truncate a single sentinel.log
    detail: |
      PREP_TEST_ENV empties TEST_ENV_ROOT/sentinel.log for each target, so make -j test-unit test-integration can wipe the other target's evidence. Serial make test is unaffected. ARCH-ORDER.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"80a6e56b-def6-43fa-a6c3-c95034c669fd","repository":"github.com/xianxu/parley.nvim","issue_id":"000365","recipe":"milestone-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/334f9af077b2cfb6","reviewed_head":"d897fc1a33dc1e2832b67f6237e9688f12a7e98a","slot":"parley.nvim:4","requested_at":"2026-10-17T01:09:06.0834Z"},"phase":"finished","pid":3055,"started_at":"2026-10-17T01:09:06.251985Z","finished_at":"2026-10-17T01:12:52.418892Z","session_id":"7dc578d1-8f9e-44ab-ad57-9053abefe8ef","outcome":"returned"}] -->

---

## Re-review — 2026-10-16T18:21:01-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 365 — Tests inherit the slot's live Couch environment and query the real registry (chat_move_spec failed when Couch flapped) |
| repo | parley.nvim |
| issue file | workshop/issues/000365-tests-inherit-the-slot-s-live-couch-environment-and-query-the-real-registry-chat-move-spec-failed-when-couch-flapped.md |
| boundary | whole-issue close |
| milestone | — |
| window | e4ba9a07c715f6517597a3761647330afdc4c3de..1ce4859ca04e15040e23ecd8d8dc3310993ef5f2 |
| command | sdlc close --issue 365 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T18:21:01-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Sweeping the live opt-in specs for environment names they read, to verify BR-1's class fix.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

This round fixes the four prior findings that mattered, and each fix has a test that would fail without it. Specs now start from an allowlist. Live opt-ins carry their own names: `PARLEY_LIVE_CONFORMANCE` passes `CLIPROXYAPI_API_KEY`, `PARLEY_LIVE_CLIPBOARD` passes the display, and `PARLEY_LIVE_COUCH` passes the thread. The launcher now removes names with `env -u`, so values no longer reach an argument list. The live `--actors` check has its own target again, and that target does reach the real binary. I ran `make test-spec SPEC=infra/test_harness` on the pinned head. All the #365 specs pass and the sentinel gate stays quiet. The only failure was `tests/arch/scratch_placement_spec.lua`, and it comes from this review checkout, where TMPDIR sits inside the repo tree; the diff doesn't cause it. I also ran `make check-couch-actors-live`. It found the real couch past the sentinel and then reported "couch unreachable here", because the sandbox has no access to the Couch socket. Nothing blocks the ship. One prior Minor still has no regression test, and I'm raising two new Minors: the `PARLEY_LIVE_COUCH` flag is stripped by only one runner, and an atlas sentence is out of date.

1. **Strengths**
   - `scripts/test-env.sh:41-54` builds the child's environment by removing names, so the only `NAME=value` arguments are PATH, SHELL and the sentinel log. `tests/unit/test_isolation_spec.lua:576` pins that, and also forbids the old `eval "value=` pattern, so going back to the old code would fail it.
   - `tests/integration/test_isolation_spec.lua:453-475` tests each live flag with both checks: the flag's own names cross, and other flags' names do not (for example, the conformance flag passes no Couch thread).
   - `tests/unit/test_isolation_spec.lua:567` counts the orphan gates and the `SENTINEL_CHECK` lines and requires them to match. Removing any one sentinel check makes it fail (this fixes BR-4).
   - `couch_spec.lua:36-42` finds the real binary on PATH and skips the sentinel directory, so the live check doesn't depend on the sentinel shadowing `couch`.
   - The sentinel fails loudly and logs the CLI, the working directory and the arguments. That gives clear evidence when a spec reaches a real CLI.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - `Makefile.parley:101` vs `:153,211,234,264,276`: only `RUN_SPEC` strips `PARLEY_LIVE_COUCH`.
     - The other spec-running targets (`test-spec`, `test-changed`, `perf`, `goldens` and `fixtures`) pass an ambient `PARLEY_LIVE_COUCH=1` through. `test-env.sh:33` then hands every spec in that target the real `COUCH_THREAD_*`, `COUCH_STORE_DIR` and `COUCH_ISOLATED_ROOT`.
     - The atlas says this happens "only for `make check-couch-actors-live`", which is not true for those targets.
     - The failure is loud, not silent: the sentinel catches bare `couch`, and `ambient()` turns red.
     - Fix: put the rule in the launcher, for example "a live flag that carries a thread is honoured only when the target sets it". That could be a marker set only by the target, or the launcher could unset `PARLEY_LIVE_COUCH` unless the target passes it through `PARLEY_TEST_ENV_PASS`.
   - `atlas/infra/test_harness.md:195` still says the launcher "runs `env -i` and copies only a fixed list". The next sentence correctly says it uses `env -u`. Also, the `make fixtures` bullet at :206 runs on into the sentinel paragraph, so that paragraph renders as part of the bullet.

5. **Test coverage notes**
   - The launcher tests (exact allowlist, per-flag names, `PARLEY_TEST_ENV_PASS`) run the real script with `clear_env`. That is a real integration test, not a mock.
   - Nothing pins that the per-target `SENTINEL_LOG` includes `$@` (BR-5).
   - Nothing pins that a runner strips `PARLEY_LIVE_COUCH`.
   - Side note, not from this diff: plenary counts a live check that ends in `pending()` as both Pending and Success, so the summary totals overstate what the live check covered.

6. **Architectural notes**
   - **ARCH-DRY: pass.** The allowlist has one owner (`test-env.sh`), and the Makefile prefix is shared through `TEST_RUN`. The `perf` target spells out the prefix by hand, but the launch scan covers it.
   - **ARCH-PURE: pass.** `test_isolation.ambient(env)` is pure, takes its environment as an argument, and is tested without IO.
   - **ARCH-PURPOSE: pass.** I checked every `PARLEY_LIVE_*` consumer:
     - `CONFORMANCE` needs `CLIPROXYAPI_API_KEY`, and the flag carries it.
     - `CLIPBOARD` needs the display, and the flag carries it.
     - `GITHUB` and `SHRINK` read no other names.
     - `COUCH` needs the thread, and the flag carries it.
     - `record_fixtures.lua` reads exactly the three keys listed in `PARLEY_TEST_ENV_PASS`.
   - **ARCH-MOCK: pass.** The sentinel acts as a stateless guard, not a fake, which is right for its job. Live `--actors` conformance can run again.
   - **ARCH-CONSTRAINTS: pass.** The launcher adds about one process per spec, which is negligible.
   - **ARCH-SECURE: pass, with the Minor above.** Values stay out of argv, and credentials cross only when named.
   - **ARCH-ORDER: pass.** Logs are per target, so concurrent targets don't share one. Two `make` processes running the same target would still share a log, which is acceptable.
   - **ARCH-FUNERAL: pass.** Sentinel logs live under `TEST_ENV_ROOT`, are truncated on each run, and are removed by `test-clean-env`.

7. **Plan revision recommendations:** none. The code delivers what the plan claims; only the atlas sentence needs fixing.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      test-env.sh:29-33 maps each PARLEY_LIVE_* flag to its names; test_isolation_spec.lua:453 goes red without it; swept GITHUB/SHRINK (no extra names needed).
  - id: BR-2
    disposition: addressed
    note: |
      Launcher now builds env -u NAME only; tests/unit/test_isolation_spec.lua:576 forbids NAME=$value argv and the old eval pattern.
  - id: BR-3
    disposition: addressed
    note: |
      make check-couch-actors-live sets PARLEY_LIVE_COUCH; ran it, real_couch() resolved past the sentinel and reached the --actors call (pended only on sandbox socket).
  - id: BR-4
    disposition: addressed
    note: |
      tests/unit/test_isolation_spec.lua:567 requires SENTINEL_CHECK count == orphan-gate count; dropping one goes red.
  - id: BR-5
    disposition: not-addressed
    note: |
      Per-target SENTINEL_LOG (sentinel-$@.log) is in place and plausible, but no test pins it; add a scan asserting SENTINEL_LOG contains $@.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: live-optin-leaks-into-suite
    title: |
      PARLEY_LIVE_COUCH is stripped only by RUN_SPEC; test-spec/test-changed/perf/goldens/fixtures pass the real thread to every spec
    detail: |
      Makefile.parley:101 strips the flag only for test-unit/test-integration. An ambient PARLEY_LIVE_COUCH=1 with make test-spec makes test-env.sh:33 keep COUCH_THREAD_*/STORE_DIR/ISOLATED_ROOT for every spec, which contradicts atlas "only for make check-couch-actors-live". It fails loudly (sentinel, ambient()). Enforce in the launcher: honour thread-carrying flags only when the target itself sets them.
  - id: new
    severity: Minor
    kind: defect
    family: atlas-claim-drift
    title: |
      atlas/infra/test_harness.md:195 still says the launcher runs env -i; the fixtures bullet absorbs the sentinel paragraph
    detail: |
      The launcher now unsets names with env -u (scripts/test-env.sh:41-54). Fix the sentence, and add a blank line after the make fixtures bullet at :206.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"2b270b6f-63b8-4810-b65e-27ac49bc36a9","repository":"github.com/xianxu/parley.nvim","issue_id":"000365","recipe":"milestone-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/1c805fc94468a4a7","reviewed_head":"1ce4859ca04e15040e23ecd8d8dc3310993ef5f2","slot":"parley.nvim:4","requested_at":"2026-10-17T01:16:55.546313Z"},"phase":"finished","pid":95954,"started_at":"2026-10-17T01:16:55.765734Z","finished_at":"2026-10-17T01:21:00.674676Z","session_id":"489ed8d2-f399-44ca-924f-c0f1f63d6390","outcome":"returned"}] -->

---

## Re-review — 2026-10-16T18:26:59-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 365 — Tests inherit the slot's live Couch environment and query the real registry (chat_move_spec failed when Couch flapped) |
| repo | parley.nvim |
| issue file | workshop/issues/000365-tests-inherit-the-slot-s-live-couch-environment-and-query-the-real-registry-chat-move-spec-failed-when-couch-flapped.md |
| boundary | whole-issue close |
| milestone | — |
| window | 5e9da065cad592f90bdd4f37771dd0cb065a430d..2999bfba8d35a68d1436e301cc63b61e76ed2f65 |
| command | sdlc close --issue 365 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T18:26:59-07:00 |
| verdict | SHIP |

## Review

No scope change. Let me run the isolation spec and do a quick mutation check.

I disposed of all three open prior findings as **addressed** and raised one new Minor finding. Nothing blocks, so the verdict is SHIP.

```verdict
verdict: SHIP
confidence: high
```

**Summary.** The interdiff is small: `Makefile.parley`, `atlas/infra/test_harness.md`, `tests/unit/test_isolation_spec.lua` and one issue-log entry. The issue edit only records the fixes in `## Log`; `## Spec`, `## Revisions` and `## Done when` are unchanged, so scope did not change.
- **BR-6:** fixed in the shared prefix. `TEST_RUN` now strips `PARLEY_LIVE_COUCH`, so every target that uses it drops the flag. That covers the whole class, not just the site the finding named.
- **BR-5:** the per-target sentinel log (`sentinel-$@.log`) is in place, and the new test pins it.
- **BR-7:** the atlas no longer says `env -i`, and a blank line now separates the fixtures bullet from the sentinel paragraph.

I ran the harness-mapped specs. `tests/unit/test_isolation_spec.lua` and `tests/integration/test_isolation_spec.lua` both pass. I then removed the strip from `TEST_RUN`: the new test failed at `test_isolation_spec.lua:120` ("TEST_RUN keeps the Couch flag"), and I restored the Makefile afterwards (working tree clean). `tests/arch/scratch_placement_spec.lua` failed 8 cases, but that is the review sandbox: its TMPDIR sits inside the checkout (`.sdlc-review/tmp/...`). It is not something this interdiff caused.

1. **Strengths**
   - `Makefile.parley:64`: putting the strip in `TEST_RUN` closes the leak for every launch at once. `check-couch-actors-live` (`Makefile.parley:329`) is the one launch that bypasses `TEST_RUN`, and it sets the flag itself. That is exactly what the atlas promises.
   - `tests/unit/test_isolation_spec.lua:110-128`: the scan test checks three things. `TEST_RUN` strips the flag, exactly one launch keeps it, and that launch belongs to the `check-couch-actors-live` target. Removing the strip makes it fail.
   - `perf` (`Makefile.parley:238`) and `RUN_SPEC` (`:103`) each strip the flag too, and the scan test covers both.
2. **Critical:** none.
3. **Important:** none.
4. **Minor**
   - `scripts/test-env.sh:31-32` still says "RUN_SPEC strips this flag". After this fix, `TEST_RUN` does it for every target. The header at `:14` also still names the single `sentinel.log` rather than the per-target log. This is the 2nd finding in family `atlas-claim-drift` (details in the findings block).
   - `atlas/infra/test_harness.md:87`: the rewritten sentence is no longer wrapped like the rest of the file.
5. **Test coverage:** the new scan only matches launches where `scripts/test-env.sh" nvim` sits on one line. Today that matches every direct launch, and the separate `launches >= 7` check guards against the scan going stale.
6. **Architecture**
   - **ARCH-DRY: pass.** The strip lives once in `TEST_RUN`. `RUN_SPEC` and `perf` repeat it because they can't use the macro, and the test enforces all three.
   - **ARCH-PURE: n/a.** The interdiff only touches Makefile wiring.
   - **ARCH-PURPOSE: pass.** BR-6 was fixed for the whole class: every launch except the one live target, enforced by a scan.
7. **Plan revisions:** none.

```findings
dispose:
  - id: BR-5
    disposition: addressed
    note: |
      SENTINEL_LOG = $(TEST_ENV_ROOT)/sentinel-$@.log (Makefile.parley:66); PREP_TEST_ENV truncates only the target's own log; new spec asserts $@ in SENTINEL_LOG.
  - id: BR-6
    disposition: addressed
    note: |
      TEST_RUN (Makefile.parley:64), RUN_SPEC and perf all run env -u PARLEY_LIVE_COUCH; only check-couch-actors-live sets it. Scan test pins this; removing the strip from TEST_RUN makes it fail at test_isolation_spec.lua:120.
  - id: BR-7
    disposition: addressed
    note: |
      atlas/infra/test_harness.md:86-88 now says the launcher keeps a fixed list and removes the rest with env -u; blank line added after the make fixtures bullet.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: atlas-claim-drift
    title: |
      scripts/test-env.sh comments still say RUN_SPEC strips PARLEY_LIVE_COUCH and name a single sentinel.log
    detail: |
      This is the 2nd finding in family atlas-claim-drift. test-env.sh:31-32 says RUN_SPEC strips the flag, but the BR-6 fix moved the strip into TEST_RUN for every target. The header at :14 still names $PARLEY_TEST_ENV_ROOT/sentinel.log, but each target now writes its own sentinel-<target>.log. Rule: when a fix moves where an invariant is enforced, update every prose restatement of that invariant. Grep for the old enforcer's name (RUN_SPEC, sentinel.log) across scripts/, Makefile.parley and atlas/ in the same change.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"52619cbc-f10c-499e-9cbc-d1c616676e11","repository":"github.com/xianxu/parley.nvim","issue_id":"000365","recipe":"fix-review","round":3,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/346bae5e7aec2329","reviewed_head":"2999bfba8d35a68d1436e301cc63b61e76ed2f65","slot":"parley.nvim:4","requested_at":"2026-10-17T01:22:20.07942Z"},"phase":"finished","pid":20069,"started_at":"2026-10-17T01:22:20.205953Z","finished_at":"2026-10-17T01:26:57.563006Z","session_id":"c4b4b516-7748-4bdf-b6bd-cfec65f1f8cc","outcome":"returned"}] -->
