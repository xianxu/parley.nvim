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

## Open findings

- **BR-1** [Critical] `installed-layout-conformance` Upgrade acceptance reads a starter file that the formula moves elsewhere
- **BR-2** [Important] `pure-test-io-separation` Pure formula unit coverage includes filesystem and subprocess operations
