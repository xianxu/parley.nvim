---
gate: plan-quality
issue: 252
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-09-14T12:07:04-07:00"
      agent: codex
      findings:
        - id: PQ-1
          severity: Important
          title: Identify the approved inventory and authoritative checkout before deletion.
          detail: Plan lines 21–22 reference an unnamed inventory and literal ./~, while this checkout contains 55 root transcripts but no ./~. The supplied artifacts live in parley.nvim despite the ariadne#252 label. Name the authoritative checkout and a durable private inventory containing the exact eleven retained paths and approved removal roots; resolve the missing tilde target without substituting another directory. Counts alone cannot establish deletion authorization (ARCH-PURPOSE, ARCH-SECURE).
          family: explicit-destructive-scope
          round: 1
        - id: PQ-2
          severity: Important
          title: Define how verified backup state remains valid through deletion and retry.
          detail: Plan line 21 compares source and destination before deletion but does not govern intervening edits, partial backup/deletion, or reruns. State how source mutation is excluded or detected before removal, how incomplete backups are distinguished from verified ones, and how retries preserve the original recovery copy. Abort before deletion on incomplete enumeration, copy/hash failure, or insufficient space; record backup byte size and explicitly handle symlinks or unsupported file types (ARCH-ORDER, ARCH-SECURE, ARCH-CONSTRAINTS, ARCH-FUNERAL).
          family: verified-deletion-contract
          round: 1
        - id: PQ-3
          severity: Important
          title: Name the cleanup decision functions and their adversarial verification strategy.
          detail: Plan lines 24–25 describe folding integration checks but name no unit-tested functions or strategy for the destructive cleanup script. Name the inventory/path-validation and backup-verification decision functions, with one strategy line each covering adversarial paths and changed or incomplete backup state; exercise the filesystem shell against an isolated temporary tree that cannot reach user state (ARCH-PURE, ARCH-SECURE). Keep the existing fold oracles and name the mapped suite command.
          family: risky-function-test-strategy
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-09-14T12:08:35-07:00"
      agent: codex
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Revision names the authoritative checkout, exact retained set, durable private removal inventory, and absent literal tilde target without substitution.
          round: 2
        - id: PQ-2
          disposition: addressed
          note: Complete verification gates deletion; source and backup rechecks, fail-closed IO handling, type restrictions, and journal-based retries preserve the original recovery copy.
          round: 2
        - id: PQ-3
          disposition: addressed
          note: Revision names validate_relative and verify_digest with adversarial guards, isolates filesystem tests, preserves both folding oracles, and specifies the mapped suite command.
          round: 2
      blocked: false
content_hash: a378bfd3af71009ca215243c1131f98060b74bf755397089078bf4ff669eaf51
---

# Gate ledger — parley.nvim#252 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-14T12:07:04-07:00 (codex) — BLOCKED

### Raised

- **PQ-1** [Important] `explicit-destructive-scope` Identify the approved inventory and authoritative checkout before deletion.
  Plan lines 21–22 reference an unnamed inventory and literal ./~, while this checkout contains 55 root transcripts but no ./~. The supplied artifacts live in parley.nvim despite the ariadne#252 label. Name the authoritative checkout and a durable private inventory containing the exact eleven retained paths and approved removal roots; resolve the missing tilde target without substituting another directory. Counts alone cannot establish deletion authorization (ARCH-PURPOSE, ARCH-SECURE).
- **PQ-2** [Important] `verified-deletion-contract` Define how verified backup state remains valid through deletion and retry.
  Plan line 21 compares source and destination before deletion but does not govern intervening edits, partial backup/deletion, or reruns. State how source mutation is excluded or detected before removal, how incomplete backups are distinguished from verified ones, and how retries preserve the original recovery copy. Abort before deletion on incomplete enumeration, copy/hash failure, or insufficient space; record backup byte size and explicitly handle symlinks or unsupported file types (ARCH-ORDER, ARCH-SECURE, ARCH-CONSTRAINTS, ARCH-FUNERAL).
- **PQ-3** [Important] `risky-function-test-strategy` Name the cleanup decision functions and their adversarial verification strategy.
  Plan lines 24–25 describe folding integration checks but name no unit-tested functions or strategy for the destructive cleanup script. Name the inventory/path-validation and backup-verification decision functions, with one strategy line each covering adversarial paths and changed or incomplete backup state; exercise the filesystem shell against an isolated temporary tree that cannot reach user state (ARCH-PURE, ARCH-SECURE). Keep the existing fold oracles and name the mapped suite command.

## Round 2 — 2026-09-14T12:08:35-07:00 (codex) — passed

### Disposed

- PQ-1 — addressed — Revision names the authoritative checkout, exact retained set, durable private removal inventory, and absent literal tilde target without substitution.
- PQ-2 — addressed — Complete verification gates deletion; source and backup rechecks, fail-closed IO handling, type restrictions, and journal-based retries preserve the original recovery copy.
- PQ-3 — addressed — Revision names validate_relative and verify_digest with adversarial guards, isolates filesystem tests, preserves both folding oracles, and specifies the mapped suite command.

## Open findings

(none — every finding has been disposed)
