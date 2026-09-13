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
