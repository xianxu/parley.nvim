---
gate: boundary-review
issue: 208
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-13T13:18:42-07:00"
      agent: codex
      findings:
        - id: BR-1
          severity: Important
          title: README update appears missing for standalone contributor setup and verification commands
          detail: Makefile.parley:233–251 adds dependency checking and verification commands, documented at TOOLING.md:13–46, while README.md is unchanged. Add a short contributor entry near README.md:24 showing the PLENARY override and linking to standalone setup; the explicit README gate requires this surface to be discoverable there.
          family: readme-surface-discoverability
          round: 1
        - id: BR-2
          severity: Minor
          title: Standalone make help succeeds without displaying product targets
          detail: Makefile:16 depends on WF_HELP_TARGETS supplied by the absent maintainer overlay. Reproduced with make --no-print-directory WF_WORKFLOW= help, which returns no output. Connect help-parley in Makefile.local and verify help with the overlay absent.
          family: optional-overlay-help-ownership
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-09-13T13:23:25-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: README.md:24–31 now documents the PLENARY override, help, archive acceptance, and standalone TOOLING.md instructions. The documented commands match the Makefile targets.
          round: 2
        - id: BR-2
          disposition: addressed
          note: Makefile.local:7 supplies help-parley independently of the overlay. In isolated scratch, portable_make_spec.lua passes 3/3; removing that prerequisite makes the help regression fail while the other two tests pass.
          round: 2
      findings:
        - id: BR-3
          severity: Minor
          title: A test-strategy row is misplaced in the core-concepts table
          detail: workshop/plans/000208-fresh-clone-installability-plan.md:35 puts materialize test inputs and assertions into the location/status columns. Move this duplicate strategy row into Function-level test strategies; the preceding entity row correctly identifies its implementation and classification.
          family: plan-table-structure
          round: 2
      blocked: false
---

# Gate ledger — parley.nvim#208 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-13T13:18:42-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Important] `readme-surface-discoverability` README update appears missing for standalone contributor setup and verification commands
  Makefile.parley:233–251 adds dependency checking and verification commands, documented at TOOLING.md:13–46, while README.md is unchanged. Add a short contributor entry near README.md:24 showing the PLENARY override and linking to standalone setup; the explicit README gate requires this surface to be discoverable there.
- **BR-2** [Minor] `optional-overlay-help-ownership` Standalone make help succeeds without displaying product targets
  Makefile:16 depends on WF_HELP_TARGETS supplied by the absent maintainer overlay. Reproduced with make --no-print-directory WF_WORKFLOW= help, which returns no output. Connect help-parley in Makefile.local and verify help with the overlay absent.

## Round 2 — 2026-09-13T13:23:25-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — README.md:24–31 now documents the PLENARY override, help, archive acceptance, and standalone TOOLING.md instructions. The documented commands match the Makefile targets.
- BR-2 — addressed — Makefile.local:7 supplies help-parley independently of the overlay. In isolated scratch, portable_make_spec.lua passes 3/3; removing that prerequisite makes the help regression fail while the other two tests pass.

### Raised

- **BR-3** [Minor] `plan-table-structure` A test-strategy row is misplaced in the core-concepts table
  workshop/plans/000208-fresh-clone-installability-plan.md:35 puts materialize test inputs and assertions into the location/status columns. Move this duplicate strategy row into Function-level test strategies; the preceding entity row correctly identifies its implementation and classification.

## Open findings

- **BR-3** [Minor] `plan-table-structure` A test-strategy row is misplaced in the core-concepts table
