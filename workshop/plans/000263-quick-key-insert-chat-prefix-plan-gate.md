---
gate: plan-quality
issue: 263
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-09-16T20:38:55-07:00"
      agent: claude
      findings:
        - id: PQ-1
          severity: Important
          title: Spec and Done-when still describe the pre-revision cursor-position feature the plan no longer builds
          detail: |-
            Revision 1 moved the action from cursor-position to exchange-structural, but
            the acceptance contract was never restated. Spec still requires "On an empty
            line or at column 0, insert at line start. Otherwise insert at the cursor
            position", and Done-when still requires "inserts the prefix at the cursor"
            and "tests cover insertion on an empty line, mid-line, an already-prefixed
            line" — three criteria the structural design cannot satisfy, since cursor
            column never participates and the branches are insert/focus. sdlc close
            judges the diff against Done-when. Append a restated Done-when inside the
            existing Revisions block (exchange-relative insertion, focus-not-duplicate,
            the trailing-space post-condition, both modes plus single undo, the
            streaming refusal, the widened shadowing guard) and mark the originals
            superseded.
          family: stale-acceptance-criteria
          round: 1
        - id: PQ-2
          severity: Minor
          title: ARCH-FUNERAL has no entry, not even a reasoned N/A
          detail: |-
            The plan works through DRY, PURE, PURPOSE, MOCK, SECURE, ORDER and
            CONSTRAINTS explicitly, but never mentions ARCH-FUNERAL. The at-plan lens
            requires the exemption be written as "creates nothing durable because X"
            rather than omitted or left bare. One line covers it: the only durable bytes
            are question lines inside a transcript the user owns and edits, and the
            module and registry entry are code, not a growing artifact family.
          family: arch-lens-unaddressed
          round: 1
      blocked: true
---

# Gate ledger — parley.nvim#263 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-16T20:38:55-07:00 (claude) — BLOCKED

### Raised

- **PQ-1** [Important] `stale-acceptance-criteria` Spec and Done-when still describe the pre-revision cursor-position feature the plan no longer builds
  Revision 1 moved the action from cursor-position to exchange-structural, but
  the acceptance contract was never restated. Spec still requires "On an empty
  line or at column 0, insert at line start. Otherwise insert at the cursor
  position", and Done-when still requires "inserts the prefix at the cursor"
  and "tests cover insertion on an empty line, mid-line, an already-prefixed
  line" — three criteria the structural design cannot satisfy, since cursor
  column never participates and the branches are insert/focus. sdlc close
  judges the diff against Done-when. Append a restated Done-when inside the
  existing Revisions block (exchange-relative insertion, focus-not-duplicate,
  the trailing-space post-condition, both modes plus single undo, the
  streaming refusal, the widened shadowing guard) and mark the originals
  superseded.
- **PQ-2** [Minor] `arch-lens-unaddressed` ARCH-FUNERAL has no entry, not even a reasoned N/A
  The plan works through DRY, PURE, PURPOSE, MOCK, SECURE, ORDER and
  CONSTRAINTS explicitly, but never mentions ARCH-FUNERAL. The at-plan lens
  requires the exemption be written as "creates nothing durable because X"
  rather than omitted or left bare. One line covers it: the only durable bytes
  are question lines inside a transcript the user owns and edits, and the
  module and registry entry are code, not a growing artifact family.

## Open findings

- **PQ-1** [Important] `stale-acceptance-criteria` Spec and Done-when still describe the pre-revision cursor-position feature the plan no longer builds
- **PQ-2** [Minor] `arch-lens-unaddressed` ARCH-FUNERAL has no entry, not even a reasoned N/A
