---
gate: boundary-review
issue: 231
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-12T23:24:30-07:00"
      agent: codex
      findings:
        - id: BR-1
          severity: Critical
          title: Path-keyed inclusion bypasses per-request image limits.
          detail: lua/parley/assets.lua:301 budgets occurrences but authorizes emission by path; 21 references to one image emitted 21 blocks under the 20-image cap. Preserve occurrence identity through planning and emission, and test duplicate references within and across questions. ARCH-CONSTRAINTS.
          family: budget-emission-identity
          round: 1
        - id: BR-2
          severity: Critical
          title: Initial and continuation builders apply different retention inputs.
          detail: lua/parley/chat_respond.lua:585 uses target_idx as the total and disables file-reference pinning. Probes reproduced both resurrection of an initially omitted image and loss of a pinned image; pass identical retention metadata and add differential tests. ARCH-DRY, ARCH-PURPOSE.
          family: retention-consumer-parity
          round: 1
        - id: BR-3
          severity: Critical
          title: Clipboard launch and insertion failures leave incomplete paste transactions.
          detail: lua/parley/clipboard_image.lua:203 lets spawn errors escape, leaving paste inflight permanently; lua/parley/paste_image.lua:82 saves before insertion and leaves an orphan when insertion fails. Route launch errors through completion and roll back saved bytes after insertion failure, with retry and residue assertions. ARCH-ORDER, ARCH-FUNERAL.
          family: async-operation-terminal-cleanup
          round: 1
        - id: BR-4
          severity: Critical
          title: Read errors and invalid image bytes are submitted as image content.
          detail: lua/parley/assets.lua:501 discards read errors and returns empty bytes; question_content also accepts plain text as PNG. Preserve IO errors, reject nonregular and invalid image inputs with visible notes, and cover these cases against the real read adapter. ARCH-SECURE.
          family: persisted-input-validation
          round: 1
        - id: BR-5
          severity: Critical
          title: The Core concepts table labels IO-dependent functions PURE.
          detail: workshop/plans/000231-chat-image-attachments-plan.md:299 onward includes filesystem probes, host_env, reader-driven question_content, and buffer/filesystem-dependent builders under the no-IO contract. Reclassify integration functions or extract pure transformations, expose injected dependencies, and append a plan revision. ARCH-PURE.
          family: core-concept-classification
          round: 1
        - id: BR-6
          severity: Important
          title: README documentation is missing for the new paste surface.
          detail: lua/parley/config.lua:412 introduces the M-v binding, and this range introduces assets.clipboard_cmd without updating README.md. Document the binding, override, and tool requirements at M1 instead of deferring them to M2.
          family: user-surface-documentation
          round: 1
      boundary: M1
      blocked: true
    - "n": 2
      timestamp: "2026-09-12T23:43:19-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: Both builders assign occurrence IDs through attach_question_images. Duplicate-reference tests cover within/across questions; an in-memory path-keyed planner mutation caused 12 failures.
          round: 2
        - id: BR-2
          disposition: addressed
          note: Continuation now uses the full exchange count and shared file-reference extraction. Differential regressions at tests/unit/build_messages_spec.lua:2139 and :2169 exercise both reported failures.
          round: 2
        - id: BR-3
          disposition: addressed
          note: Launch exceptions reach scheduled completion exactly once; insertion failures roll back saved assets. Tests cover launch errors, retries, removal of newly created folders, and preservation of existing assets.
          round: 2
        - id: BR-4
          disposition: not-addressed
          note: lua/parley/assets.lua:171 accepts signatures without valid image bodies. A read-only probe submitted the eight-byte PNG signature through question_content and obtained an image block. Tests explicitly accept signature-plus-"body" fixtures, so they cannot catch this remaining invalid-input case.
          round: 2
        - id: BR-5
          disposition: not-addressed
          note: workshop/plans/000231-chat-image-attachments-plan.md:290 still labels unique_name PURE despite its filesystem-backed exists callback; :302 likewise labels select PURE despite env.executable calling vim.fn.executable. The named reclassifications landed, but the classification rule was not swept across the table.
          round: 2
        - id: BR-6
          disposition: addressed
          note: README.md now documents M-v, platform tools, assets.clipboard_cmd, its output-token contract, and setup table replacement.
          round: 2
      boundary: M1
      blocked: true
---

# Gate ledger — parley.nvim#231 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-12T23:24:30-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `budget-emission-identity` Path-keyed inclusion bypasses per-request image limits.
  lua/parley/assets.lua:301 budgets occurrences but authorizes emission by path; 21 references to one image emitted 21 blocks under the 20-image cap. Preserve occurrence identity through planning and emission, and test duplicate references within and across questions. ARCH-CONSTRAINTS.
- **BR-2** [Critical] `retention-consumer-parity` Initial and continuation builders apply different retention inputs.
  lua/parley/chat_respond.lua:585 uses target_idx as the total and disables file-reference pinning. Probes reproduced both resurrection of an initially omitted image and loss of a pinned image; pass identical retention metadata and add differential tests. ARCH-DRY, ARCH-PURPOSE.
- **BR-3** [Critical] `async-operation-terminal-cleanup` Clipboard launch and insertion failures leave incomplete paste transactions.
  lua/parley/clipboard_image.lua:203 lets spawn errors escape, leaving paste inflight permanently; lua/parley/paste_image.lua:82 saves before insertion and leaves an orphan when insertion fails. Route launch errors through completion and roll back saved bytes after insertion failure, with retry and residue assertions. ARCH-ORDER, ARCH-FUNERAL.
- **BR-4** [Critical] `persisted-input-validation` Read errors and invalid image bytes are submitted as image content.
  lua/parley/assets.lua:501 discards read errors and returns empty bytes; question_content also accepts plain text as PNG. Preserve IO errors, reject nonregular and invalid image inputs with visible notes, and cover these cases against the real read adapter. ARCH-SECURE.
- **BR-5** [Critical] `core-concept-classification` The Core concepts table labels IO-dependent functions PURE.
  workshop/plans/000231-chat-image-attachments-plan.md:299 onward includes filesystem probes, host_env, reader-driven question_content, and buffer/filesystem-dependent builders under the no-IO contract. Reclassify integration functions or extract pure transformations, expose injected dependencies, and append a plan revision. ARCH-PURE.
- **BR-6** [Important] `user-surface-documentation` README documentation is missing for the new paste surface.
  lua/parley/config.lua:412 introduces the M-v binding, and this range introduces assets.clipboard_cmd without updating README.md. Document the binding, override, and tool requirements at M1 instead of deferring them to M2.

## Round 2 — 2026-09-12T23:43:19-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — addressed — Both builders assign occurrence IDs through attach_question_images. Duplicate-reference tests cover within/across questions; an in-memory path-keyed planner mutation caused 12 failures.
- BR-2 — addressed — Continuation now uses the full exchange count and shared file-reference extraction. Differential regressions at tests/unit/build_messages_spec.lua:2139 and :2169 exercise both reported failures.
- BR-3 — addressed — Launch exceptions reach scheduled completion exactly once; insertion failures roll back saved assets. Tests cover launch errors, retries, removal of newly created folders, and preservation of existing assets.
- BR-4 — not-addressed — lua/parley/assets.lua:171 accepts signatures without valid image bodies. A read-only probe submitted the eight-byte PNG signature through question_content and obtained an image block. Tests explicitly accept signature-plus-"body" fixtures, so they cannot catch this remaining invalid-input case.
- BR-5 — not-addressed — workshop/plans/000231-chat-image-attachments-plan.md:290 still labels unique_name PURE despite its filesystem-backed exists callback; :302 likewise labels select PURE despite env.executable calling vim.fn.executable. The named reclassifications landed, but the classification rule was not swept across the table.
- BR-6 — addressed — README.md now documents M-v, platform tools, assets.clipboard_cmd, its output-token contract, and setup table replacement.

## Open findings

- **BR-4** [Critical] `persisted-input-validation` Read errors and invalid image bytes are submitted as image content.
- **BR-5** [Critical] `core-concept-classification` The Core concepts table labels IO-dependent functions PURE.
