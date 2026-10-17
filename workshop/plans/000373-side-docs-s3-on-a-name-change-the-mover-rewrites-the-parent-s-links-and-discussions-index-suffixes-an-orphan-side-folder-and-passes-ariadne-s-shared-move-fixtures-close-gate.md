---
gate: boundary-review
issue: 373
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 2c0f9f4d-a166-42de-b6fa-36cd4b810334
            repository: github.com/xianxu/parley.nvim
            issue_id: "000373"
            recipe: milestone-review
            round: 1
            attempt: 1
            agent: codex
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/287636a3e395e856
            reviewed_head: e53020d4cceeb064d73331a91f03f5fd4c7f46f1
            slot: parley.nvim:1
            requested_at: "2026-10-17T18:05:59.354762Z"
          phase: finished
          pid: 47336
          started_at: "2026-10-17T18:05:59.453754Z"
          finished_at: "2026-10-17T18:09:52.939614Z"
          session_id: 01a14b0a-c609-7112-bd51-31973620b709
          outcome: returned
      "n": 1
      timestamp: "2026-10-17T11:09:53-07:00"
      dispatched: "2026-10-17T11:05:59-07:00"
      agent: codex
      findings:
        - kind: defect
          id: BR-1
          severity: Critical
          title: Multiline inline code is rewritten as a live Markdown link
          detail: lua/parley/document_move_plan.lua:123–129 builds code masks per line while markdown_spans recognizes multiline links. Input "`[example\nlabel](design.side/q.md)`\n" is changed to spec.side by rewrite_side_references; rewrite_parent likewise changes "../design.md" to "../spec.md" inside the same code shape. This violates unrelated-byte preservation and affects existing child-backlink callers (ARCH-PURPOSE). Mask inline code across paragraph lines and add failing preservation tests for both APIs.
          family: markdown-code-preservation
          round: 1
        - kind: defect
          id: BR-2
          severity: Important
          title: Expected file paths can pass preflight as directories and cause partial sync
          detail: scripts/sync-review-protocol.py:156–158 recursively accepts directories without checking expected leaf types. Replacing examples/move-test/before/nested/old.md with an empty directory and making SKILL.md stale caused sync to replace SKILL.md before failing with IsADirectoryError. Validate every expected file and ancestor type before writing, with mutation-free failure regressions for both modes and fixtures (ARCH-SECURE).
          family: output-preflight-before-mutation
          round: 1
        - kind: defect
          id: BR-3
          severity: Important
          title: Complete parent rewriting retains a quadratic malformed-link scan
          detail: lua/parley/document_move_plan.lua:150 copies and scans the remaining suffix for every unmatched "](" opener. Through rewrite_side_references, repeated "](" input measured approximately 0.025s/2KB, 0.095s/4KB, 0.374s/8KB, and 1.465s/16KB, despite accepting documents up to 4MiB. Use monotonic delimiter scanning and add complete-rewrite scale coverage; the existing opening-bracket test misses this path (ARCH-CONSTRAINTS).
          family: bounded-reference-scanning
          round: 1
      boundary: M1
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: ac49aa83-3627-4b07-8c11-2adb16760667
            repository: github.com/xianxu/parley.nvim
            issue_id: "000373"
            recipe: milestone-review
            round: 2
            attempt: 1
            agent: codex
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/585e79ecc387df91
            reviewed_head: c8dddf5bf201a8194f5d6bedd4b20bc344844c08
            slot: parley.nvim:1
            requested_at: "2026-10-17T18:22:25.958047Z"
          phase: finished
          pid: 12166
          started_at: "2026-10-17T18:22:26.058249Z"
          finished_at: "2026-10-17T18:24:31.875707Z"
          session_id: 01a14b19-d41d-7b32-b8ef-57054aa0d7f8
          outcome: returned
      "n": 2
      timestamp: "2026-10-17T11:24:33-07:00"
      dispatched: "2026-10-17T11:22:25-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: Paragraph-wide preservation tests cover both rewrite APIs; restoring the previous line-local masker produces three failing tests.
          round: 2
        - id: BR-2
          disposition: addressed
          note: Expected leaves and ancestors are validated before mutation. Removing that validation produces 21 failing regression subtests across protocol files, modes, and fixtures.
          round: 2
        - id: BR-3
          disposition: addressed
          note: Complete-rewrite scale coverage passes for both APIs. Restoring suffix scanning makes the malformed-destination regression fail.
          round: 2
      findings:
        - kind: defect
          id: BR-4
          severity: Critical
          title: Inline-code masks cross block boundaries and leave live links pointing at the old path
          detail: 'lua/parley/document_move_plan.lua:110 ends code-mask paragraphs only at blank lines or fences. Input "` unmatched\n# Heading\n[live](design.side/q.md) `\n" remains unchanged when design.md becomes spec.md, although the heading separates the backticks and the live destination must become spec.side/q.md. Both rewrite APIs fail equivalent probes across headings, thematic breaks, blockquotes, and list starts: eight failures. This is the 2nd finding in family `markdown-code-preservation`. Do NOT fix only this instance: state and enforce the block-boundary rule across the supported Markdown structures, sharing segmentation with reference_candidates.markdown_spans where appropriate, and test both APIs. ARCH-DRY and ARCH-PURPOSE.'
          family: markdown-code-preservation
          round: 2
      boundary: M1
      recipe: milestone-review
      isolation: fenced
      blocked: true
---

# Gate ledger — parley.nvim#373 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-17T11:09:53-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `markdown-code-preservation` (kind: defect) Multiline inline code is rewritten as a live Markdown link
  lua/parley/document_move_plan.lua:123–129 builds code masks per line while markdown_spans recognizes multiline links. Input "`[example\nlabel](design.side/q.md)`\n" is changed to spec.side by rewrite_side_references; rewrite_parent likewise changes "../design.md" to "../spec.md" inside the same code shape. This violates unrelated-byte preservation and affects existing child-backlink callers (ARCH-PURPOSE). Mask inline code across paragraph lines and add failing preservation tests for both APIs.
- **BR-2** [Important] `output-preflight-before-mutation` (kind: defect) Expected file paths can pass preflight as directories and cause partial sync
  scripts/sync-review-protocol.py:156–158 recursively accepts directories without checking expected leaf types. Replacing examples/move-test/before/nested/old.md with an empty directory and making SKILL.md stale caused sync to replace SKILL.md before failing with IsADirectoryError. Validate every expected file and ancestor type before writing, with mutation-free failure regressions for both modes and fixtures (ARCH-SECURE).
- **BR-3** [Important] `bounded-reference-scanning` (kind: defect) Complete parent rewriting retains a quadratic malformed-link scan
  lua/parley/document_move_plan.lua:150 copies and scans the remaining suffix for every unmatched "](" opener. Through rewrite_side_references, repeated "](" input measured approximately 0.025s/2KB, 0.095s/4KB, 0.374s/8KB, and 1.465s/16KB, despite accepting documents up to 4MiB. Use monotonic delimiter scanning and add complete-rewrite scale coverage; the existing opening-bracket test misses this path (ARCH-CONSTRAINTS).

## Round 2 — 2026-10-17T11:24:33-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — addressed — Paragraph-wide preservation tests cover both rewrite APIs; restoring the previous line-local masker produces three failing tests.
- BR-2 — addressed — Expected leaves and ancestors are validated before mutation. Removing that validation produces 21 failing regression subtests across protocol files, modes, and fixtures.
- BR-3 — addressed — Complete-rewrite scale coverage passes for both APIs. Restoring suffix scanning makes the malformed-destination regression fail.

### Raised

- **BR-4** [Critical] `markdown-code-preservation` (kind: defect) Inline-code masks cross block boundaries and leave live links pointing at the old path
  lua/parley/document_move_plan.lua:110 ends code-mask paragraphs only at blank lines or fences. Input "` unmatched\n# Heading\n[live](design.side/q.md) `\n" remains unchanged when design.md becomes spec.md, although the heading separates the backticks and the live destination must become spec.side/q.md. Both rewrite APIs fail equivalent probes across headings, thematic breaks, blockquotes, and list starts: eight failures. This is the 2nd finding in family `markdown-code-preservation`. Do NOT fix only this instance: state and enforce the block-boundary rule across the supported Markdown structures, sharing segmentation with reference_candidates.markdown_spans where appropriate, and test both APIs. ARCH-DRY and ARCH-PURPOSE.

## Open findings

- **BR-4** [Critical] `markdown-code-preservation` (kind: defect) Inline-code masks cross block boundaries and leave live links pointing at the old path
