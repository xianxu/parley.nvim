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

## Open findings

- **BR-3** [Important] `integration-environment-isolation` Fake VM tests require 60 GiB of real host disk
