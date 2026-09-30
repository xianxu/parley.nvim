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

## Open findings

- **BR-1** [Critical] `payload-identity-trust` Writable receipts can certify modified plugin source
- **BR-2** [Important] `wall-clock-deadline-enforcement` Streaming downloads can exceed the declared deadline inside read
