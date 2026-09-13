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
