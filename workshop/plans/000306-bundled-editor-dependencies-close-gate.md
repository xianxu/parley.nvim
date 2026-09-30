---
gate: boundary-review
issue: 306
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-30T11:46:59-07:00"
      agent: codex
      findings:
        - id: BR-1
          severity: Critical
          title: Writable receipts can certify modified plugin source
          detail: scripts/editor-dependencies.py:203-214 compares source files against editable receipt hashes without binding that inventory to trusted archive identities. Modifying plugin source and regenerating its receipt passes verify_bundle and prepare_bundle. Bind expected payload identity to trusted manifest data or checksum-verified archives, with changed-receipt regressions (ARCH-SECURE, ARCH-PURPOSE).
          family: payload-identity-trust
          round: 1
        - id: BR-2
          severity: Important
          title: Streaming downloads can exceed the declared deadline inside read
          detail: scripts/editor-dependencies.py:277-286 checks elapsed time only after read(1 MiB); the socket timeout measures inactivity. A drip-response reproduction exceeded a 0.1-second budget for 0.535 seconds before rejection. Enforce the remaining deadline during IO and add a slow-response regression (ARCH-CONSTRAINTS).
          family: wall-clock-deadline-enforcement
          round: 1
      recipe: milestone-review
      blocked: true
    - "n": 2
      timestamp: "2026-09-30T12:03:41-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: Source inventories are bound to trusted manifest hashes in scripts/editor-dependencies.py:185-195. All five changed-receipt regressions pass; restoring the previous check_layout makes every variant fail.
          round: 2
        - id: BR-2
          disposition: addressed
          note: scripts/editor-dependencies.py:277-351 bounds blocking IO with worker deadlines and kill/reap cleanup. Slow-header/body regressions pass; restoring the previous fetch_archive makes them exceed the budget at approximately 0.8 seconds.
          round: 2
      findings:
        - id: BR-3
          severity: Important
          title: Standalone migration accepts runtimes missing newly required modules
          detail: packaging/starter-config/init.lua:97-109 checks only theme.lua before requiring editor_dependencies and editor_bundle. An isolated cached pre-change runtime reproduces module-not-found before Lazy loads, making the documented :Lazy update recovery unavailable. Validate required capabilities for both fresh and cached runtimes, reject incompatible staging before publication, provide external recovery instructions, and add regressions preserving existing checkout contents (ARCH-PURPOSE, ARCH-SECURE).
          family: starter-runtime-compatibility
          round: 2
      recipe: milestone-review
      blocked: true
---

# Gate ledger — parley.nvim#306 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-30T11:46:59-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `payload-identity-trust` Writable receipts can certify modified plugin source
  scripts/editor-dependencies.py:203-214 compares source files against editable receipt hashes without binding that inventory to trusted archive identities. Modifying plugin source and regenerating its receipt passes verify_bundle and prepare_bundle. Bind expected payload identity to trusted manifest data or checksum-verified archives, with changed-receipt regressions (ARCH-SECURE, ARCH-PURPOSE).
- **BR-2** [Important] `wall-clock-deadline-enforcement` Streaming downloads can exceed the declared deadline inside read
  scripts/editor-dependencies.py:277-286 checks elapsed time only after read(1 MiB); the socket timeout measures inactivity. A drip-response reproduction exceeded a 0.1-second budget for 0.535 seconds before rejection. Enforce the remaining deadline during IO and add a slow-response regression (ARCH-CONSTRAINTS).

## Round 2 — 2026-09-30T12:03:41-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — addressed — Source inventories are bound to trusted manifest hashes in scripts/editor-dependencies.py:185-195. All five changed-receipt regressions pass; restoring the previous check_layout makes every variant fail.
- BR-2 — addressed — scripts/editor-dependencies.py:277-351 bounds blocking IO with worker deadlines and kill/reap cleanup. Slow-header/body regressions pass; restoring the previous fetch_archive makes them exceed the budget at approximately 0.8 seconds.

### Raised

- **BR-3** [Important] `starter-runtime-compatibility` Standalone migration accepts runtimes missing newly required modules
  packaging/starter-config/init.lua:97-109 checks only theme.lua before requiring editor_dependencies and editor_bundle. An isolated cached pre-change runtime reproduces module-not-found before Lazy loads, making the documented :Lazy update recovery unavailable. Validate required capabilities for both fresh and cached runtimes, reject incompatible staging before publication, provide external recovery instructions, and add regressions preserving existing checkout contents (ARCH-PURPOSE, ARCH-SECURE).

## Open findings

- **BR-3** [Important] `starter-runtime-compatibility` Standalone migration accepts runtimes missing newly required modules
