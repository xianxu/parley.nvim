# Boundary Review — parley.nvim#247 (whole-issue close)

| field | value |
|-------|-------|
| issue | 247 — Homebrew tap and parley launcher: brew install xianxu/parley/parley, tested on a clean tart VM |
| repo | parley.nvim |
| issue file | workshop/issues/000247-homebrew-tap-launcher.md |
| boundary | whole-issue close |
| milestone | — |
| window | c1395685f69f53a2953cdbaeb01a77d410f105e8..b5e48b7c35e53d5e97df6bf5a11e83212c378114 |
| command | sdlc close --issue 247 |
| reviewer | codex |
| timestamp | 2026-09-13T16:21:58-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The launcher and release tooling have strong failure-path coverage, but the required upgrade acceptance fails against the formula’s actual installed layout. The current fake hides that mismatch. Public release and live VM acceptance remain pending, as the tracker acknowledges.

1. **Strengths**

   - Launcher tests exercise real competing publishers, killed processes, symlinks, settings preservation and exact argument forwarding.
   - Release tests verify archive-local dependency generation, immutable-tag checks and retry after a failed push.
   - README, atlas and traceability updates cover the new packaging surface.

2. **Critical findings**

   - [scripts/test-parley-upgrade.sh:64](/Users/xianxu/workspace/parley.nvim/scripts/test-parley-upgrade.sh:64): The upgrade fixture reads `runtime/packaging/starter-config/init.lua`, but [packaging/formula.lua:38](/Users/xianxu/workspace/parley.nvim/packaging/formula.lua:38) **moves** that file into `share/parley/config`. Homebrew’s installed `Pathname.install` implementation confirms the move. Reproducing that layout in scratch storage makes the upgrade script exit 1 with `FileNotFoundError`, before either version installs. Read the installed starter from its actual location or preserve it in `libexec`; make the fixture model the same installation layout. **ARCH-PURPOSE, ARCH-MOCK.**

3. **Important findings**

   - [tests/unit/packaging_formula_spec.lua:26](/Users/xianxu/workspace/parley.nvim/tests/unit/packaging_formula_spec.lua:26): The PURE projection test writes a temporary file and executes Ruby. Move syntax validation into an integration test, retaining direct string/metadata assertions in the unit suite. The renderer itself can remain PURE. **ARCH-PURE.**

4. **Minor findings**

   None.

5. **Test coverage notes**

   - Passed: 21 architecture checks, 10 launcher tests, 6 release tests, 3 upgrade tests and 2 formula tests.
   - VM tests: 9 passed; the fake-chat test failed because this sandbox denies loopback binding. An independent socket probe confirmed `Operation not permitted`; this is a verification limitation.
   - The installed-layout scratch reproduction independently demonstrated the upgrade defect.
   - `git diff --check` passed.

6. **Architectural notes**

   | Marker | Assessment |
   |---|---|
   | ARCH-DRY | Pass: dependencies derive from the release-local registry. |
   | ARCH-PURE | Flag: Ruby execution belongs outside the pure unit test. |
   | ARCH-PURPOSE | Flag: required upgrade acceptance cannot run against the installed package. |
   | ARCH-MOCK | Flag: fake installation preserves a source-tree layout that Homebrew changes. |
   | ARCH-CONSTRAINTS | Pass: bounded file reads, launcher waits and VM phases. |
   | ARCH-SECURE | Pass: inspected publication paths reject symlinks; guest reports omit credentials. |
   | ARCH-ORDER | Pass: launcher interleavings have explicit test barriers; release retries are exercised. |
   | ARCH-FUNERAL | Pass: one upgrade candidate, owned staging cleanup and explicit VM removal/recovery. |

7. **Plan revision recommendations**

   Append a timestamped `## Revisions` entry defining the installed starter location and requiring upgrade fixtures to reproduce Homebrew’s installation semantics. Clarify that Ruby syntax validation is INTEGRATION coverage. Keep public publication and live acceptance unchecked until their evidence exists.

```findings
findings:
  - id: new
    severity: Critical
    family: installed-layout-conformance
    title: |
      Upgrade acceptance reads a starter file that the formula moves elsewhere
    detail: |
      scripts/test-parley-upgrade.sh:64-65 reads the starter from copied libexec, but packaging/formula.lua:38 moves it into share/parley/config. A scratch reproduction of the installed layout exits 1 with FileNotFoundError before either fixture version installs. Correct the source location or preserve the runtime file, and update packaging_upgrade_spec.lua plus fake_packaging_upgrade_brew to model the actual installed layout (ARCH-PURPOSE, ARCH-MOCK).
  - id: new
    severity: Important
    family: pure-test-io-separation
    title: |
      Pure formula unit coverage includes filesystem and subprocess operations
    detail: |
      tests/unit/packaging_formula_spec.lua:26-31 writes a temporary Ruby file and executes ruby -c. Move that validation into integration coverage and keep the PURE renderer tests as direct metadata and string assertions; the renderer itself need not be reclassified (ARCH-PURE).
```

---

## Re-review — 2026-09-13T16:28:14-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 247 — Homebrew tap and parley launcher: brew install xianxu/parley/parley, tested on a clean tart VM |
| repo | parley.nvim |
| issue file | workshop/issues/000247-homebrew-tap-launcher.md |
| boundary | whole-issue close |
| milestone | — |
| window | c1395685f69f53a2953cdbaeb01a77d410f105e8..b318335cc8e7a94aa38cfd5572d16c3c296b6d7c |
| command | sdlc close --issue 247 |
| reviewer | codex |
| timestamp | 2026-09-13T16:28:14-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

Both prior findings are addressed, including confirmed regression failures when BR-1’s fix is removed. One Important test-isolation issue remains: fake VM tests require 60 GiB of actual host disk. Public release and live VM acceptance remain pending under the plan’s post-review sequence.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      The upgrade harness reads the installed share path; public and fixture layouts move the starter out of libexec. All three upgrade tests pass. Reverting only the source-path correction in a scratch copy makes two tests fail.
  - id: BR-2
    disposition: addressed
    note: |
      Filesystem writes and ruby -c moved from packaging_formula_spec.lua into release integration coverage. Both direct renderer tests and all six release integration tests pass.
findings:
  - id: new
    severity: Important
    family: integration-environment-isolation
    title: |
      Fake VM tests require 60 GiB of real host disk
    detail: |
      tests/integration/packaging_vm_spec.lua:10-18 substitutes Tart but scripts/test-parley-vm.py:245-250 still reads actual host disk capacity. Ordinary tests therefore fail below 60 GiB despite creating no VM. A scratch reproduction supplying 59 GiB rejects prepare before fake Tart receives any command. Inject the disk-capacity probe, supply deterministic test budgets, and cover insufficient-space rejection explicitly (ARCH-MOCK, ARCH-CONSTRAINTS).
```

**1. Strengths**

- Launcher tests exercise real publication races, interrupted ownership, symlinks, exact argv and exit-status preservation.
- Release rendering consumes the tagged archive’s registry; tests verify publication retry after a failed push.
- Upgrade coverage now exercises the installed layout and restores the real public launcher.
- README and atlas document installation, profile updates, release tooling and removal.

**2. Critical findings**

None.

**3. Important findings**

The disk-probe isolation issue above. Preserve the production preflight while separating fake-test capacity from the machine running the suite.

**4. Minor findings**

None.

**5. Test coverage notes**

- Passed: 21 architecture checks, 10 launcher tests, 6 release tests, 3 upgrade tests and 2 formula tests.
- VM coverage: 9 passed; the fake-provider chat case failed because this sandbox prohibits loopback binding. A direct socket probe confirmed `PermissionError: Operation not permitted`; this is a verification limitation, not an additional code finding.
- BR-1 mutation: two expected failures.
- Repository files remain unchanged.

**6. Architectural notes**

| Principle | Assessment |
|---|---|
| ARCH-DRY | Pass: dependency projection derives from the release registry. |
| ARCH-PURE | Pass: renderer assertions are separated from executable syntax validation. |
| ARCH-PURPOSE | Pass for the planned local-review stage; public/live acceptance remains outstanding. |
| ARCH-MOCK | Flag: fake VM tests retain a real disk-capacity dependency. |
| ARCH-CONSTRAINTS | Flag: the production disk threshold incorrectly constrains fake tests. |
| ARCH-SECURE | Pass: quoted argv, symlink checks, isolated profiles and redacted guest output. |
| ARCH-ORDER | Pass: launcher barriers exercise competing publishers; upgrade invalidates earlier live evidence. |
| ARCH-FUNERAL | Pass: bounded candidate/staging ownership and explicit VM/profile cleanup. |

**7. Plan revision recommendations**

Append a `## Revisions` entry specifying an injectable disk-capacity probe, deterministic sufficient/insufficient-space fixtures, and preservation of the 60 GiB requirement for real VM runs.

---

## Re-review — 2026-09-13T16:32:52-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 247 — Homebrew tap and parley launcher: brew install xianxu/parley/parley, tested on a clean tart VM |
| repo | parley.nvim |
| issue file | workshop/issues/000247-homebrew-tap-launcher.md |
| boundary | whole-issue close |
| milestone | — |
| window | c1395685f69f53a2953cdbaeb01a77d410f105e8..9202b955a8ca8746388bad353b69b99a1f55b1d5 |
| command | sdlc close --issue 247 |
| reviewer | codex |
| timestamp | 2026-09-13T16:32:52-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: medium
```

BR-3 is addressed, and inspection found no new code defect. Verification remains blocked: the fake-chat integration test failed because this sandbox prohibits loopback socket binding, confirmed independently with `PermissionError(1, 'Operation not permitted')`. Rerun that test in an environment permitting local sockets. Public release and live VM acceptance also remain explicitly pending under the plan’s pre-publication review sequence.

```findings
dispose:
  - id: BR-3
    disposition: addressed
    note: |
      Both capacity probes use the injected callable. The insufficient-space test verifies refusal and reservation release before Tart runs. An in-memory mutation reverting the probe calls fails with simulated host capacity of 59 GiB, while the fixed implementation accepts the injected 120 GiB.
  - id: BR-1
    disposition: addressed
    note: |
      Upgrade reconstruction reads prefix/share/parley/config/init.lua; the fixture reproduces Homebrew's move out of libexec. All three upgrade integration cases passed.
  - id: BR-2
    disposition: addressed
    note: |
      Formula unit cases contain validation and projection assertions; subprocess-based Ruby syntax validation resides in release integration coverage. Both formula unit cases and all six release cases passed.
```

1. **Strengths**
   - Launcher tests exercise real competing publishers, interrupted ownership, symlink refusal, exact argv forwarding, and settings preservation.
   - Formula generation consumes the selected release’s dependency registry; an archive-specific fixture verifies that provenance.
   - Release tests verify interrupted-push retries and preservation of unrelated tap changes.
   - README, atlas, and traceability cover the new packaging surface.

2. **Critical findings:** None.

3. **Important findings:** No new code findings. The failed fake-chat test at `tests/integration/packaging_vm_spec.lua:97` requires verification outside this socket-restricted sandbox.

4. **Minor findings:** None.

5. **Test coverage notes**
   - Passed: 21 architecture, 10 launcher, 6 release, 3 upgrade, 10 VM, and 2 formula checks.
   - Blocked: one VM fake-chat case; its download attempted `127.0.0.1:0` after socket allocation failed.
   - BR-3’s mutation check demonstrated sensitivity to reverting the fix.
   - Pinned stat/name-status inspection and `git diff --check` succeeded. Repository files were unchanged.

6. **Architectural notes**
   - **ARCH-DRY — pass:** dependencies derive from the release-local registry.
   - **ARCH-PURE — pass:** formula validation/rendering remain separate from orchestration.
   - **ARCH-PURPOSE — pass for this planned review checkpoint:** final public/live acceptance remains unchecked.
   - **ARCH-MOCK — flag, verification only:** stateful fixtures exist, but the socket-dependent case could not complete here.
   - **ARCH-CONSTRAINTS — pass:** capacity rejection is deterministic; launcher waits and VM phases have bounds.
   - **ARCH-SECURE — pass:** reviewed publication paths reject unsafe targets; argv forwarding preserves argument boundaries.
   - **ARCH-ORDER — pass:** publisher barriers exercise competing and interrupted operations; completion requires phase evidence.
   - **ARCH-FUNERAL — pass:** staging cleanup, explicit abandoned-lock recovery, owned-VM deletion, and profile removal are defined.

7. **Plan revision recommendations:** None. Preserve the unchecked release/live-acceptance items until their evidence exists.

---

## Re-review — 2026-09-13T16:44:47-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 247 — Homebrew tap and parley launcher: brew install xianxu/parley/parley, tested on a clean tart VM |
| repo | parley.nvim |
| issue file | workshop/issues/000247-homebrew-tap-launcher.md |
| boundary | whole-issue close |
| milestone | — |
| window | c1395685f69f53a2953cdbaeb01a77d410f105e8..9202b955a8ca8746388bad353b69b99a1f55b1d5 |
| command | sdlc close --issue 247 |
| reviewer | claude |
| timestamp | 2026-09-13T16:44:47-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The three prior findings are genuinely fixed: I re-ran every packaging spec (2 formula, 6 release, 3 upgrade, 10 launcher, 11 VM, 21 arch cases all green in this sandbox, including the loopback fake-chat case that blocked earlier rounds), and mutation checks for BR-1 and BR-3 go red when the fix is reverted. The launcher, formula projection and release script are solid and well tested. What keeps this off SHIP is the failure path of the VM orchestrator that the operator is about to run live for the first time: I reproduced, with real tart's exit code for deleting a nonexistent VM, that a failed `tart clone` leaks the ownership reservation, masks the original error, and makes the documented `cleanup` recovery fail too. The fake tart hides this because it lets `delete`/`stop` of an unknown VM succeed. That is fixable in minutes and does not block the gate on its own, but it should land before the live run. The whole-issue Done-when (public tap, live VM chat, one real release) is by plan still pending; the close must not archive or merge before that evidence exists.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      test-parley-upgrade.sh:67 reads prefix/share/parley/config/init.lua; fake brew moves the starter out of libexec (fixture:46-50). Reverting the path in a scratch copy fails 2 of 3 upgrade cases.
  - id: BR-2
    disposition: addressed
    note: |
      packaging_formula_spec.lua contains only validate/render assertions; ruby -c lives in packaging_release_spec.lua:63-65. Both suites green.
  - id: BR-3
    disposition: addressed
    note: |
      main(disk_usage=) injected at test-parley-vm.py:175,248,258; run_packaging_vm.py supplies capacity. Mutating back to shutil.disk_usage makes an injected 59 GiB proceed to clone; the real code refuses before any Tart call.
findings:
  - id: new
    severity: Important
    family: fake-conformance-to-real-dependency
    title: |
      Clone failure leaks the VM ownership reservation and the fake tart hides it
    detail: |
      scripts/test-parley-vm.py:254 sets clone_attempted before the clone; on clone failure cleanup() calls delete with check=True (line 41), which real tart 2.32.1 exits 2 on for a nonexistent VM. Reproduced with a tart-faithful wrapper: the lock at ~/.cache/parley-vm-acceptance.owner survives, the error is reported as "Tart command failed: delete" (the clone error is lost), every later prepare fails FileExistsError, and `cleanup RUN_DIR` fails the same way. tests/fixtures/fake_tart:27-29 lets delete/stop of an unknown VM succeed, so no test can see it. This generalizes BR-1's rule (a fake must reproduce the real dependency's semantics the orchestrator's control flow depends on, ARCH-MOCK/ARCH-FUNERAL/ARCH-ORDER). Class fix: (1) fake_tart delete/stop exit 2 on unknown names; (2) a conformance spec, skipped when tart is absent, asserting the fake's exit codes for delete/stop-unknown equal the real binary's; (3) preflight failure path releases the lock in a finally and deletes with check=False; (4) a FAKE_TART_FAIL=clone case asserting the lock is released and the original error is reported.
  - id: new
    severity: Important
    family: failure-diagnosability
    title: |
      Every guest-phase failure destroys the VM and reports only an exception type
    detail: |
      test-parley-vm.py:196-224 wraps install/probe/package phases in except BaseException → cleanup → raise, and main's handler (line 297-300) prints only the exception class. command() discards captured output. A guest failure in the never-yet-run live path (e.g. parley exits before writing phase.json → json.loads('') → JSONDecodeError) deletes the only evidence. The plan's Operating envelope promises "except an explicitly retained diagnosis run"; no retain option exists. Add a --keep-on-failure flag (or manifest field) that skips cleanup and prints the manifest path, and keep redaction for the console while optionally writing guest stderr to a 0600 file inside the private run dir.
  - id: new
    severity: Minor
    family: acceptance-evidence-before-archive
    title: |
      Done-when is unmet at this whole-issue close by design; do not archive or tick the project row yet
    detail: |
      No public tap exists, no live guest chat has run, and release-parley.sh has not been used for a release. The plan's Chunk 1 step 4 sequences these after this review; the issue Plan items 1/3/4 are unchecked accordingly. Record it as a plan revision and keep merge/archive blocked until the manifest shows outcome=complete.
  - id: new
    severity: Minor
    family: live-path-input-validity
    title: |
      Live model selection may pass the codex-device login alias to list_models
    detail: |
      tests/packaging/vm_chat.lua:109-118 iterates proxy.login_providers() (includes codex-device) and calls proxy.list_models(login); cliproxy_config PROVIDER_OWNED_BY has no codex-device key, so if codex is healthy but lists zero models the loop reaches codex-device, list_models errors, await() asserts and the phase fails. Iterate cc.providers() for the model axis, or resolve the alias first.
  - id: new
    severity: Minor
    family: duplicate-helper
    title: |
      Headless formula-render one-liner and guest upload snippet are duplicated
    detail: |
      release-parley.sh:51 and test-parley-upgrade.sh:82-88 embed the same nvim -c render program; test-parley-vm.py duplicates the base64 upload in install() (55-59), probe_phase() (76-82) and upload() (112-116). Extract one packaging/render-formula entry and use upload() everywhere (ARCH-DRY).
```

**Strengths**

- `packaging/launcher.lua:34-79` is a genuinely careful publication protocol: lstat-only reads with a 1 MiB bound, no-clobber hard-link publish, atomic candidate rename, explicit non-stealing lock with bounded wait. The spec drives real competing processes through filesystem barriers (`packaging_launcher_spec.lua:41-61`), which is the right oracle for ARCH-ORDER.
- `packaging/formula.lua:19` derives dependencies from the registry; the release spec's archive-only `archive-ripgrep` mutation (`packaging_release_spec.lua:39-42`) proves rendering uses the tagged tree's registry, not the checkout's.
- `scripts/release-parley.sh` checks tag identity before and after download (lines 30, 42), stages on the destination filesystem, and the interrupted-push retry is tested against a real bare remote with a rejecting hook.
- Fake brew (`fake_packaging_upgrade_brew:46-50`) now models Homebrew's install-time move; the upgrade spec asserts the libexec starter is absent on both sides.
- Docs gate met: README install section leads with brew, `packaging/README.md`, tap README, `atlas/infra/packaging.md`, index and traceability all updated; lessons carry the three prior findings as rules.

**Critical findings**

None.

**Important findings**

1. `scripts/test-parley-vm.py:254,41` — reservation lock leaks on clone failure; fake tart lenient on unknown-VM delete/stop. Reproduction and class fix in the findings block. Real tart output observed: `the specified VM "…" does not exist`, exit 2.
2. `scripts/test-parley-vm.py:196-224,297` — no retained-diagnosis run; guest failures leave only an exception class name. Plan promised the retain path.

**Minor findings**

- Live loop may call `list_models('codex-device')` (`vm_chat.lua:109`).
- Duplicated render one-liner and upload snippet.
- `libexec.install Dir["*", ".*"]` ships `workshop/`, `docs/`, `atlas/` into every user's prefix. Public repo, so no secret exposure, but it is bloat; `tests/` is needed by the fake phase, the rest is not.
- Manifest carries `status`/`phase`/`outcome` as three free strings; the legal combinations are unwritten (ARCH-ORDER). A single tagged state would remove the redundancy seen in the failed manifest (`status: failed`, `outcome: failed`).
- `owned.mkdir()` in `test-parley-upgrade.sh:24` surfaces as a raw traceback rather than the script's `sys.exit` message.

**Test coverage notes**

- Ran in this sandbox: formula 2/2, release 6/6, upgrade 3/3, launcher 10/10, VM 11/11 (including the loopback fake-chat case prior rounds could not run), arch 21/21, luacheck 0 warnings over 16 packaging files, python syntax clean, `git diff --check` clean.
- Mutation evidence: BR-1 revert → 2 failures; BR-3 revert → injected 59 GiB proceeds to clone.
- Uncovered: the live branch of `vm_chat.lua:103-126` (health, model listing, osascript clipboard seed, image paste) runs only in the real guest. API names it uses all exist (`credential_health_for_login`, `list_models`, `managed_binary`, `_config_path`, `has_image`, `paste_image`, query `payload`/`provider`), and the clipboard reader is osascript, so no missing formula dependency. Clone-failure and unknown-VM delete paths have no test.

**Architectural notes**

- ARCH-DRY: flag (Minor) — duplicated render and upload snippets.
- ARCH-PURE: pass — `formula.lua` is a projection; unit tests are IO-free.
- ARCH-PURPOSE: conditional pass — code delivers the full local scope; the Done-when's public/live evidence is sequenced after this review by plan and must gate merge/archive.
- ARCH-MOCK: flag (Important) — fake tart diverges from real tart on delete/stop of unknown VMs and has no live conformance probe; fake brew and local git remotes are good seams.
- ARCH-CONSTRAINTS: pass — 1 MiB read bound, 5 s lock wait, 180 s readiness, 900 s phases, disk preflight with injected probe.
- ARCH-SECURE: pass — symlink refusal, lstat-verified reads, argv arrays, forged-manifest rejection, redacted guest output, tests never touch real HOME.
- ARCH-ORDER: flag (Important) — the preflight error path unwinds without releasing the lock; launcher interleavings are otherwise explicit and barrier-tested.
- ARCH-FUNERAL: flag (Important) — same lock leak; otherwise one `.new` candidate, owned staging removed with the lock, VM removed on verify.

**Plan revision recommendations**

- Add a `## Revisions` entry: the preflight/cleanup lifecycle releases the ownership reservation on every failure, fake tart reproduces real tart's unknown-VM exit code, and a conformance check keeps them aligned.
- Add an entry stating whether the promised "retained diagnosis run" is implemented as a flag, or strike the promise.
- Core concepts table lists fixtures as `tests/fixtures/fake_packaging_*`; `fake_tart` and `run_packaging_vm.py` do not match that glob. Name them.
- The project file's `done_when` still says `:ParleyProxy login`; the shipped command is `:ParleyConnect`. Correct it when the close sweep touches the project.
