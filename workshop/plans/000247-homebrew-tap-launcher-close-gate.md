---
gate: boundary-review
issue: 247
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-13T16:21:58-07:00"
      agent: codex
      findings:
        - id: BR-1
          severity: Critical
          title: Upgrade acceptance reads a starter file that the formula moves elsewhere
          detail: scripts/test-parley-upgrade.sh:64-65 reads the starter from copied libexec, but packaging/formula.lua:38 moves it into share/parley/config. A scratch reproduction of the installed layout exits 1 with FileNotFoundError before either fixture version installs. Correct the source location or preserve the runtime file, and update packaging_upgrade_spec.lua plus fake_packaging_upgrade_brew to model the actual installed layout (ARCH-PURPOSE, ARCH-MOCK).
          family: installed-layout-conformance
          round: 1
        - id: BR-2
          severity: Important
          title: Pure formula unit coverage includes filesystem and subprocess operations
          detail: tests/unit/packaging_formula_spec.lua:26-31 writes a temporary Ruby file and executes ruby -c. Move that validation into integration coverage and keep the PURE renderer tests as direct metadata and string assertions; the renderer itself need not be reclassified (ARCH-PURE).
          family: pure-test-io-separation
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-09-13T16:28:14-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: The upgrade harness reads the installed share path; public and fixture layouts move the starter out of libexec. All three upgrade tests pass. Reverting only the source-path correction in a scratch copy makes two tests fail.
          round: 2
        - id: BR-2
          disposition: addressed
          note: Filesystem writes and ruby -c moved from packaging_formula_spec.lua into release integration coverage. Both direct renderer tests and all six release integration tests pass.
          round: 2
      findings:
        - id: BR-3
          severity: Important
          title: Fake VM tests require 60 GiB of real host disk
          detail: tests/integration/packaging_vm_spec.lua:10-18 substitutes Tart but scripts/test-parley-vm.py:245-250 still reads actual host disk capacity. Ordinary tests therefore fail below 60 GiB despite creating no VM. A scratch reproduction supplying 59 GiB rejects prepare before fake Tart receives any command. Inject the disk-capacity probe, supply deterministic test budgets, and cover insufficient-space rejection explicitly (ARCH-MOCK, ARCH-CONSTRAINTS).
          family: integration-environment-isolation
          round: 2
      blocked: true
    - "n": 3
      timestamp: "2026-09-13T16:32:52-07:00"
      agent: codex
      dispose:
        - id: BR-3
          disposition: addressed
          note: Both capacity probes use the injected callable. The insufficient-space test verifies refusal and reservation release before Tart runs. An in-memory mutation reverting the probe calls fails with simulated host capacity of 59 GiB, while the fixed implementation accepts the injected 120 GiB.
          round: 3
        - id: BR-1
          disposition: addressed
          note: Upgrade reconstruction reads prefix/share/parley/config/init.lua; the fixture reproduces Homebrew's move out of libexec. All three upgrade integration cases passed.
          round: 3
        - id: BR-2
          disposition: addressed
          note: Formula unit cases contain validation and projection assertions; subprocess-based Ruby syntax validation resides in release integration coverage. Both formula unit cases and all six release cases passed.
          round: 3
      blocked: false
    - "n": 4
      timestamp: "2026-09-13T16:44:47-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: test-parley-upgrade.sh:67 reads prefix/share/parley/config/init.lua; fake brew moves the starter out of libexec (fixture:46-50). Reverting the path in a scratch copy fails 2 of 3 upgrade cases.
          round: 4
        - id: BR-2
          disposition: addressed
          note: packaging_formula_spec.lua contains only validate/render assertions; ruby -c lives in packaging_release_spec.lua:63-65. Both suites green.
          round: 4
        - id: BR-3
          disposition: addressed
          note: main(disk_usage=) injected at test-parley-vm.py:175,248,258; run_packaging_vm.py supplies capacity. Mutating back to shutil.disk_usage makes an injected 59 GiB proceed to clone; the real code refuses before any Tart call.
          round: 4
      findings:
        - id: BR-4
          severity: Important
          title: Clone failure leaks the VM ownership reservation and the fake tart hides it
          detail: 'scripts/test-parley-vm.py:254 sets clone_attempted before the clone; on clone failure cleanup() calls delete with check=True (line 41), which real tart 2.32.1 exits 2 on for a nonexistent VM. Reproduced with a tart-faithful wrapper: the lock at ~/.cache/parley-vm-acceptance.owner survives, the error is reported as "Tart command failed: delete" (the clone error is lost), every later prepare fails FileExistsError, and `cleanup RUN_DIR` fails the same way. tests/fixtures/fake_tart:27-29 lets delete/stop of an unknown VM succeed, so no test can see it. This generalizes BR-1''s rule (a fake must reproduce the real dependency''s semantics the orchestrator''s control flow depends on, ARCH-MOCK/ARCH-FUNERAL/ARCH-ORDER). Class fix: (1) fake_tart delete/stop exit 2 on unknown names; (2) a conformance spec, skipped when tart is absent, asserting the fake''s exit codes for delete/stop-unknown equal the real binary''s; (3) preflight failure path releases the lock in a finally and deletes with check=False; (4) a FAKE_TART_FAIL=clone case asserting the lock is released and the original error is reported.'
          family: fake-conformance-to-real-dependency
          round: 4
        - id: BR-5
          severity: Important
          title: Every guest-phase failure destroys the VM and reports only an exception type
          detail: test-parley-vm.py:196-224 wraps install/probe/package phases in except BaseException → cleanup → raise, and main's handler (line 297-300) prints only the exception class. command() discards captured output. A guest failure in the never-yet-run live path (e.g. parley exits before writing phase.json → json.loads('') → JSONDecodeError) deletes the only evidence. The plan's Operating envelope promises "except an explicitly retained diagnosis run"; no retain option exists. Add a --keep-on-failure flag (or manifest field) that skips cleanup and prints the manifest path, and keep redaction for the console while optionally writing guest stderr to a 0600 file inside the private run dir.
          family: failure-diagnosability
          round: 4
        - id: BR-6
          severity: Minor
          title: Done-when is unmet at this whole-issue close by design; do not archive or tick the project row yet
          detail: No public tap exists, no live guest chat has run, and release-parley.sh has not been used for a release. The plan's Chunk 1 step 4 sequences these after this review; the issue Plan items 1/3/4 are unchecked accordingly. Record it as a plan revision and keep merge/archive blocked until the manifest shows outcome=complete.
          family: acceptance-evidence-before-archive
          round: 4
        - id: BR-7
          severity: Minor
          title: Live model selection may pass the codex-device login alias to list_models
          detail: tests/packaging/vm_chat.lua:109-118 iterates proxy.login_providers() (includes codex-device) and calls proxy.list_models(login); cliproxy_config PROVIDER_OWNED_BY has no codex-device key, so if codex is healthy but lists zero models the loop reaches codex-device, list_models errors, await() asserts and the phase fails. Iterate cc.providers() for the model axis, or resolve the alias first.
          family: live-path-input-validity
          round: 4
        - id: BR-8
          severity: Minor
          title: Headless formula-render one-liner and guest upload snippet are duplicated
          detail: release-parley.sh:51 and test-parley-upgrade.sh:82-88 embed the same nvim -c render program; test-parley-vm.py duplicates the base64 upload in install() (55-59), probe_phase() (76-82) and upload() (112-116). Extract one packaging/render-formula entry and use upload() everywhere (ARCH-DRY).
          family: duplicate-helper
          round: 4
      blocked: false
---

# Gate ledger — parley.nvim#247 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-13T16:21:58-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `installed-layout-conformance` Upgrade acceptance reads a starter file that the formula moves elsewhere
  scripts/test-parley-upgrade.sh:64-65 reads the starter from copied libexec, but packaging/formula.lua:38 moves it into share/parley/config. A scratch reproduction of the installed layout exits 1 with FileNotFoundError before either fixture version installs. Correct the source location or preserve the runtime file, and update packaging_upgrade_spec.lua plus fake_packaging_upgrade_brew to model the actual installed layout (ARCH-PURPOSE, ARCH-MOCK).
- **BR-2** [Important] `pure-test-io-separation` Pure formula unit coverage includes filesystem and subprocess operations
  tests/unit/packaging_formula_spec.lua:26-31 writes a temporary Ruby file and executes ruby -c. Move that validation into integration coverage and keep the PURE renderer tests as direct metadata and string assertions; the renderer itself need not be reclassified (ARCH-PURE).

## Round 2 — 2026-09-13T16:28:14-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — addressed — The upgrade harness reads the installed share path; public and fixture layouts move the starter out of libexec. All three upgrade tests pass. Reverting only the source-path correction in a scratch copy makes two tests fail.
- BR-2 — addressed — Filesystem writes and ruby -c moved from packaging_formula_spec.lua into release integration coverage. Both direct renderer tests and all six release integration tests pass.

### Raised

- **BR-3** [Important] `integration-environment-isolation` Fake VM tests require 60 GiB of real host disk
  tests/integration/packaging_vm_spec.lua:10-18 substitutes Tart but scripts/test-parley-vm.py:245-250 still reads actual host disk capacity. Ordinary tests therefore fail below 60 GiB despite creating no VM. A scratch reproduction supplying 59 GiB rejects prepare before fake Tart receives any command. Inject the disk-capacity probe, supply deterministic test budgets, and cover insufficient-space rejection explicitly (ARCH-MOCK, ARCH-CONSTRAINTS).

## Round 3 — 2026-09-13T16:32:52-07:00 (codex) — passed

### Disposed

- BR-3 — addressed — Both capacity probes use the injected callable. The insufficient-space test verifies refusal and reservation release before Tart runs. An in-memory mutation reverting the probe calls fails with simulated host capacity of 59 GiB, while the fixed implementation accepts the injected 120 GiB.
- BR-1 — addressed — Upgrade reconstruction reads prefix/share/parley/config/init.lua; the fixture reproduces Homebrew's move out of libexec. All three upgrade integration cases passed.
- BR-2 — addressed — Formula unit cases contain validation and projection assertions; subprocess-based Ruby syntax validation resides in release integration coverage. Both formula unit cases and all six release cases passed.

## Round 4 — 2026-09-13T16:44:47-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — test-parley-upgrade.sh:67 reads prefix/share/parley/config/init.lua; fake brew moves the starter out of libexec (fixture:46-50). Reverting the path in a scratch copy fails 2 of 3 upgrade cases.
- BR-2 — addressed — packaging_formula_spec.lua contains only validate/render assertions; ruby -c lives in packaging_release_spec.lua:63-65. Both suites green.
- BR-3 — addressed — main(disk_usage=) injected at test-parley-vm.py:175,248,258; run_packaging_vm.py supplies capacity. Mutating back to shutil.disk_usage makes an injected 59 GiB proceed to clone; the real code refuses before any Tart call.

### Raised

- **BR-4** [Important] `fake-conformance-to-real-dependency` Clone failure leaks the VM ownership reservation and the fake tart hides it
  scripts/test-parley-vm.py:254 sets clone_attempted before the clone; on clone failure cleanup() calls delete with check=True (line 41), which real tart 2.32.1 exits 2 on for a nonexistent VM. Reproduced with a tart-faithful wrapper: the lock at ~/.cache/parley-vm-acceptance.owner survives, the error is reported as "Tart command failed: delete" (the clone error is lost), every later prepare fails FileExistsError, and `cleanup RUN_DIR` fails the same way. tests/fixtures/fake_tart:27-29 lets delete/stop of an unknown VM succeed, so no test can see it. This generalizes BR-1's rule (a fake must reproduce the real dependency's semantics the orchestrator's control flow depends on, ARCH-MOCK/ARCH-FUNERAL/ARCH-ORDER). Class fix: (1) fake_tart delete/stop exit 2 on unknown names; (2) a conformance spec, skipped when tart is absent, asserting the fake's exit codes for delete/stop-unknown equal the real binary's; (3) preflight failure path releases the lock in a finally and deletes with check=False; (4) a FAKE_TART_FAIL=clone case asserting the lock is released and the original error is reported.
- **BR-5** [Important] `failure-diagnosability` Every guest-phase failure destroys the VM and reports only an exception type
  test-parley-vm.py:196-224 wraps install/probe/package phases in except BaseException → cleanup → raise, and main's handler (line 297-300) prints only the exception class. command() discards captured output. A guest failure in the never-yet-run live path (e.g. parley exits before writing phase.json → json.loads('') → JSONDecodeError) deletes the only evidence. The plan's Operating envelope promises "except an explicitly retained diagnosis run"; no retain option exists. Add a --keep-on-failure flag (or manifest field) that skips cleanup and prints the manifest path, and keep redaction for the console while optionally writing guest stderr to a 0600 file inside the private run dir.
- **BR-6** [Minor] `acceptance-evidence-before-archive` Done-when is unmet at this whole-issue close by design; do not archive or tick the project row yet
  No public tap exists, no live guest chat has run, and release-parley.sh has not been used for a release. The plan's Chunk 1 step 4 sequences these after this review; the issue Plan items 1/3/4 are unchecked accordingly. Record it as a plan revision and keep merge/archive blocked until the manifest shows outcome=complete.
- **BR-7** [Minor] `live-path-input-validity` Live model selection may pass the codex-device login alias to list_models
  tests/packaging/vm_chat.lua:109-118 iterates proxy.login_providers() (includes codex-device) and calls proxy.list_models(login); cliproxy_config PROVIDER_OWNED_BY has no codex-device key, so if codex is healthy but lists zero models the loop reaches codex-device, list_models errors, await() asserts and the phase fails. Iterate cc.providers() for the model axis, or resolve the alias first.
- **BR-8** [Minor] `duplicate-helper` Headless formula-render one-liner and guest upload snippet are duplicated
  release-parley.sh:51 and test-parley-upgrade.sh:82-88 embed the same nvim -c render program; test-parley-vm.py duplicates the base64 upload in install() (55-59), probe_phase() (76-82) and upload() (112-116). Extract one packaging/render-formula entry and use upload() everywhere (ARCH-DRY).

## Open findings

- **BR-4** [Important] `fake-conformance-to-real-dependency` Clone failure leaks the VM ownership reservation and the fake tart hides it
- **BR-5** [Important] `failure-diagnosability` Every guest-phase failure destroys the VM and reports only an exception type
- **BR-6** [Minor] `acceptance-evidence-before-archive` Done-when is unmet at this whole-issue close by design; do not archive or tick the project row yet
- **BR-7** [Minor] `live-path-input-validity` Live model selection may pass the codex-device login alias to list_models
- **BR-8** [Minor] `duplicate-helper` Headless formula-render one-liner and guest upload snippet are duplicated
