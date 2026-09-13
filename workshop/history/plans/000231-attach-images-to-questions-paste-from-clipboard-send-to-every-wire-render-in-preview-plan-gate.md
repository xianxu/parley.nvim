---
gate: plan-quality
issue: 231
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-09-12T22:24:28-07:00"
      agent: codex
      findings:
        - id: PQ-1
          severity: Important
          title: Tool continuation re-sends images omitted by the memory window
          detail: The plan at workshop/plans/000231-chat-image-attachments-plan.md:2291 adds unconditional attachment loading to build_messages_from_model, whose existing loop visits every exchange (lua/parley/chat_respond.lua:451). Share the attachment retention decision across initial and continuation builders, and test continuation after an image exchange has been summarized; omitted images must remain unread and unsent (ARCH-DRY, ARCH-PURPOSE).
          family: shared-retention-policy
          round: 1
        - id: PQ-2
          severity: Important
          title: Per-image checks do not bound request size or file reads
          detail: The envelope at plan:244 and question_content at plan:812 permit arbitrarily many images despite the plan's own total inline-request limit; pinned exchanges also defeat its window-bound assumption (lua/parley/chat_respond.lua:794). Define request-wide byte/count limits and deterministic overflow behavior across both builders, and replace the unbounded read at plan:1054 with a bounded read; test accumulated attachments and oversized persisted files (ARCH-CONSTRAINTS, ARCH-SECURE).
          family: enforce-operating-envelope
          round: 1
        - id: PQ-3
          severity: Important
          title: Asset persistence and cleanup can report success after failed IO
          detail: At plan:1039 the writer ignores write/close failures; delete_with at plan:1162 ignores removal failure, and copy_into at plan:1172 ignores mkdir/write failures while incrementing its success count. Specify checked outcomes and partial-file cleanup through save, paste, delete, and export, with injected IO-failure strategies; callers must not claim durable success or completed cleanup when the underlying operation failed (ARCH-ORDER, ARCH-FUNERAL).
          family: durable-io-failure-contract
          round: 1
        - id: PQ-4
          severity: Important
          title: Compress the implementation script into contracts and risk-based test strategies
          detail: Tasks 1–12 contain extensive replacement code, line-numbered edit instructions, and prescribed test implementations rather than the required compact planning surface. Retain module/function contracts, decisions, dependencies, acceptance criteria, and review boundaries; replace the procedural diff with one adversarial-input and mechanical-guard strategy per risky function, including parsing, retention, aggregate budgeting, async paste, and filesystem failure handling.
          family: plan-strategy-over-diff
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-09-12T22:29:43-07:00"
      agent: codex
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Shared retention contracts cover both builders; the continuation strategy asserts summarized images are neither read nor sent.
          round: 2
        - id: PQ-2
          disposition: not-addressed
          note: 'Plan:209 and 330–336 budget raw image bytes rather than the serialized request: 20 MB becomes approximately 26.7 MB of base64 before text and JSON. Define shared encoded-request accounting, text-only overflow behavior, and a final-size guard (ARCH-CONSTRAINTS).'
          round: 2
        - id: PQ-3
          disposition: addressed
          note: Checked IO outcomes, partial cleanup, caller-visible errors, successful-copy counts, and injected failure strategies are specified.
          round: 2
        - id: PQ-4
          disposition: not-addressed
          note: Plan:401–459 still enumerates test cases, and tasks at 509–546 and 590–620 retain procedural edits and line-numbered call-site inventories. Compress these into contracts and per-function adversarial-input/mechanical-guard strategies.
          round: 2
      blocked: true
    - "n": 3
      timestamp: "2026-09-12T22:31:40-07:00"
      agent: codex
      dispose:
        - id: PQ-2
          disposition: not-addressed
          note: Bounded reads are addressed, but request accounting excludes serialization overhead and subsequently added notes; overflow only warns. State and enforce one rule covering the final payload and every image occurrence across both builders, including deterministic removal or refusal when attachment-bearing requests exceed it. Keep this within enforce-operating-envelope; test boundary-sized content and post-budget additions against the actual encoded payload.
          round: 3
        - id: PQ-4
          disposition: not-addressed
          note: 'Compression is substantial but incomplete: plan:81–117 retains line-numbered call-site inventories, and plan:489–505 and :589–618 prescribe edits and test procedures. Apply plan-strategy-over-diff document-wide: retain contracts, decisions, dependencies, acceptance criteria, review boundaries and one adversarial-input/mechanical-guard strategy per risky function; remove remaining procedural inventories.'
          round: 3
      blocked: true
    - "n": 4
      timestamp: "2026-09-12T22:34:01-07:00"
      agent: codex
      dispose:
        - id: PQ-2
          disposition: addressed
          note: Both builders share aggregate byte/count budgeting; final encoded image-bearing payloads over budget are refused, reads are bounded, and boundary strategies cover accumulated attachments and oversized persisted files.
          round: 4
        - id: PQ-4
          disposition: addressed
          note: The implementation script is compressed into contracts, acceptance criteria, review boundaries and function-level adversarial-input strategies with mechanical guards.
          round: 4
      blocked: false
content_hash: 12f598d54cbf1bd3ee4008f04f00584d10cce8bd6d728083774ab04b9554d776
---

# Gate ledger — parley.nvim#231 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-12T22:24:28-07:00 (codex) — BLOCKED

### Raised

- **PQ-1** [Important] `shared-retention-policy` Tool continuation re-sends images omitted by the memory window
  The plan at workshop/plans/000231-chat-image-attachments-plan.md:2291 adds unconditional attachment loading to build_messages_from_model, whose existing loop visits every exchange (lua/parley/chat_respond.lua:451). Share the attachment retention decision across initial and continuation builders, and test continuation after an image exchange has been summarized; omitted images must remain unread and unsent (ARCH-DRY, ARCH-PURPOSE).
- **PQ-2** [Important] `enforce-operating-envelope` Per-image checks do not bound request size or file reads
  The envelope at plan:244 and question_content at plan:812 permit arbitrarily many images despite the plan's own total inline-request limit; pinned exchanges also defeat its window-bound assumption (lua/parley/chat_respond.lua:794). Define request-wide byte/count limits and deterministic overflow behavior across both builders, and replace the unbounded read at plan:1054 with a bounded read; test accumulated attachments and oversized persisted files (ARCH-CONSTRAINTS, ARCH-SECURE).
- **PQ-3** [Important] `durable-io-failure-contract` Asset persistence and cleanup can report success after failed IO
  At plan:1039 the writer ignores write/close failures; delete_with at plan:1162 ignores removal failure, and copy_into at plan:1172 ignores mkdir/write failures while incrementing its success count. Specify checked outcomes and partial-file cleanup through save, paste, delete, and export, with injected IO-failure strategies; callers must not claim durable success or completed cleanup when the underlying operation failed (ARCH-ORDER, ARCH-FUNERAL).
- **PQ-4** [Important] `plan-strategy-over-diff` Compress the implementation script into contracts and risk-based test strategies
  Tasks 1–12 contain extensive replacement code, line-numbered edit instructions, and prescribed test implementations rather than the required compact planning surface. Retain module/function contracts, decisions, dependencies, acceptance criteria, and review boundaries; replace the procedural diff with one adversarial-input and mechanical-guard strategy per risky function, including parsing, retention, aggregate budgeting, async paste, and filesystem failure handling.

## Round 2 — 2026-09-12T22:29:43-07:00 (codex) — BLOCKED

### Disposed

- PQ-1 — addressed — Shared retention contracts cover both builders; the continuation strategy asserts summarized images are neither read nor sent.
- PQ-2 — not-addressed — Plan:209 and 330–336 budget raw image bytes rather than the serialized request: 20 MB becomes approximately 26.7 MB of base64 before text and JSON. Define shared encoded-request accounting, text-only overflow behavior, and a final-size guard (ARCH-CONSTRAINTS).
- PQ-3 — addressed — Checked IO outcomes, partial cleanup, caller-visible errors, successful-copy counts, and injected failure strategies are specified.
- PQ-4 — not-addressed — Plan:401–459 still enumerates test cases, and tasks at 509–546 and 590–620 retain procedural edits and line-numbered call-site inventories. Compress these into contracts and per-function adversarial-input/mechanical-guard strategies.

## Round 3 — 2026-09-12T22:31:40-07:00 (codex) — BLOCKED

### Disposed

- PQ-2 — not-addressed — Bounded reads are addressed, but request accounting excludes serialization overhead and subsequently added notes; overflow only warns. State and enforce one rule covering the final payload and every image occurrence across both builders, including deterministic removal or refusal when attachment-bearing requests exceed it. Keep this within enforce-operating-envelope; test boundary-sized content and post-budget additions against the actual encoded payload.
- PQ-4 — not-addressed — Compression is substantial but incomplete: plan:81–117 retains line-numbered call-site inventories, and plan:489–505 and :589–618 prescribe edits and test procedures. Apply plan-strategy-over-diff document-wide: retain contracts, decisions, dependencies, acceptance criteria, review boundaries and one adversarial-input/mechanical-guard strategy per risky function; remove remaining procedural inventories.

## Round 4 — 2026-09-12T22:34:01-07:00 (codex) — passed

### Disposed

- PQ-2 — addressed — Both builders share aggregate byte/count budgeting; final encoded image-bearing payloads over budget are refused, reads are bounded, and boundary strategies cover accumulated attachments and oversized persisted files.
- PQ-4 — addressed — The implementation script is compressed into contracts, acceptance criteria, review boundaries and function-level adversarial-input strategies with mechanical guards.

## Open findings

(none — every finding has been disposed)
