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
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 315dee3a-1a63-451f-a7f6-4d3104d6ec13
            repository: github.com/xianxu/parley.nvim
            issue_id: "000373"
            recipe: milestone-review
            round: 3
            attempt: 1
            agent: codex
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/4630b9b589dfe37b
            reviewed_head: 3485d3a5300a44300b1a93219e3549b8630acc22
            slot: parley.nvim:1
            requested_at: "2026-10-17T18:55:37.554347Z"
          phase: finished
          pid: 63203
          started_at: "2026-10-17T18:55:37.642889Z"
          finished_at: "2026-10-17T18:57:13.930791Z"
          session_id: 01a14b38-378e-7720-8013-ea0d87c3fbd8
          outcome: returned
      "n": 3
      timestamp: "2026-10-17T11:57:17-07:00"
      dispatched: "2026-10-17T11:55:37-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: Multiline-code preservation regressions remain present and pass through both rewrite APIs.
          round: 3
        - id: BR-2
          disposition: addressed
          note: Snapshot-wide leaf/ancestor preflight remains implemented; all 23 exporter contracts pass.
          round: 3
        - id: BR-3
          disposition: addressed
          note: Complete-rewrite malformed-delimiter scale tests remain present and pass.
          round: 3
        - id: BR-4
          disposition: addressed
          note: Both rewrite APIs consume shared markdown_blocks segmentation. The boundary regression passes at HEAD; restoring the pre-fix document_move_plan.lua in a disposable checkout produces 43 passes and one failure at the heading-separated live-link assertion.
          round: 3
      findings:
        - kind: defect
          id: BR-5
          severity: Important
          title: Atlas update appears missing for the expanded move projection contract
          detail: lua/parley/document_move_plan.lua:284 introduces rewrite_side_references, while :366 and :438 add orphan-displacement and parent-rewrite effects. The atlas changes describe fixture export only; atlas/modes/session_sync.md:237 still describes the projection as side/backlink effects. Document the new observations, effect ordering, refusal rules and orphan_destination result, explicitly distinguishing M1 projection support from M2 runtime execution.
          family: architecture-documentation
          round: 3
      boundary: M1
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 03bad37a-66c1-45bd-beab-76164b8f931d
            repository: github.com/xianxu/parley.nvim
            issue_id: "000373"
            recipe: milestone-review
            round: 4
            attempt: 1
            agent: codex
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/32eb3c4dd265a4e8
            reviewed_head: 2d1b280e0fdf980aa904c41476d795db59cbd948
            slot: parley.nvim:1
            requested_at: "2026-10-17T18:59:11.141652Z"
          phase: finished
          pid: 95463
          started_at: "2026-10-17T18:59:11.235995Z"
          finished_at: "2026-10-17T19:00:09.436209Z"
          session_id: 01a14b3b-79e5-7683-9cfa-468659429bca
          outcome: returned
      "n": 4
      timestamp: "2026-10-17T12:00:09-07:00"
      dispatched: "2026-10-17T11:59:11-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: Retained disposition; paragraph-wide inline-code preservation regressions pass through both rewrite APIs.
          round: 4
        - id: BR-2
          disposition: addressed
          note: Retained disposition; expected-file and ancestor preflight regressions pass and verify no mutation on refusal.
          round: 4
        - id: BR-3
          disposition: addressed
          note: Retained disposition; malformed destination scale regressions pass through both complete rewrites.
          round: 4
        - id: BR-4
          disposition: addressed
          note: Retained disposition; both scanners consume markdown_blocks, and boundary-preservation regressions pass.
          round: 4
        - id: BR-5
          disposition: addressed
          note: atlas/modes/session_sync.md:245–276 now documents observations, ordered effects, refusal rules, orphan_destination, and the M1/M2 distinction; these match document_move_plan.lua:284–444 and the existing runtime call at document_move.lua:368.
          round: 4
      boundary: M1
      recipe: milestone-review
      isolation: fenced
      reviewed: 2d1b280e0fdf980aa904c41476d795db59cbd948
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: e43725cd-bf48-4ced-8d9f-1504592838e2
            repository: github.com/xianxu/parley.nvim
            issue_id: "000373"
            recipe: milestone-review
            round: 1
            attempt: 1
            agent: codex
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/5c2b202540809e47
            reviewed_head: 140d8e541dc74626616f496f1d2acf49c7d51d7d
            slot: parley.nvim:1
            requested_at: "2026-10-18T01:15:47.419434Z"
          phase: finished
          pid: 40843
          started_at: "2026-10-18T01:15:47.796452Z"
          finished_at: "2026-10-18T01:24:11.101548Z"
          session_id: 01a14c94-466a-77e1-b674-8fdf41abf9fb
          outcome: returned
      "n": 5
      timestamp: "2026-10-17T18:24:12-07:00"
      dispatched: "2026-10-17T18:15:47-07:00"
      agent: codex
      findings:
        - id: BR-6
          severity: Critical
          title: Recovery releases protection before journal retirement is safely recoverable
          detail: 'lua/parley/document_move.lua:1084 calls the recovery finish hook before unlinking the journal. That hook releases the synthetic destination lock at lua/parley/agentic_document.lua:859, but the retained complete journal still requires that lock. A targeted fault-injection test confirmed that failing journal unlink after successful handoff leaves the journal permanently interrupted on reopening with "destination protection changed". ARCH-ORDER/ARCH-FUNERAL: model and persist partial finalization so lock release and journal retirement remain safely replayable; enumerate failures and crashes across these effects and add real editor recovery regressions.'
          family: replayable-local-finalization
          round: 5
      boundary: M2
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

## Round 3 — 2026-10-17T11:57:17-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — addressed — Multiline-code preservation regressions remain present and pass through both rewrite APIs.
- BR-2 — addressed — Snapshot-wide leaf/ancestor preflight remains implemented; all 23 exporter contracts pass.
- BR-3 — addressed — Complete-rewrite malformed-delimiter scale tests remain present and pass.
- BR-4 — addressed — Both rewrite APIs consume shared markdown_blocks segmentation. The boundary regression passes at HEAD; restoring the pre-fix document_move_plan.lua in a disposable checkout produces 43 passes and one failure at the heading-separated live-link assertion.

### Raised

- **BR-5** [Important] `architecture-documentation` (kind: defect) Atlas update appears missing for the expanded move projection contract
  lua/parley/document_move_plan.lua:284 introduces rewrite_side_references, while :366 and :438 add orphan-displacement and parent-rewrite effects. The atlas changes describe fixture export only; atlas/modes/session_sync.md:237 still describes the projection as side/backlink effects. Document the new observations, effect ordering, refusal rules and orphan_destination result, explicitly distinguishing M1 projection support from M2 runtime execution.

## Round 4 — 2026-10-17T12:00:09-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — Retained disposition; paragraph-wide inline-code preservation regressions pass through both rewrite APIs.
- BR-2 — addressed — Retained disposition; expected-file and ancestor preflight regressions pass and verify no mutation on refusal.
- BR-3 — addressed — Retained disposition; malformed destination scale regressions pass through both complete rewrites.
- BR-4 — addressed — Retained disposition; both scanners consume markdown_blocks, and boundary-preservation regressions pass.
- BR-5 — addressed — atlas/modes/session_sync.md:245–276 now documents observations, ordered effects, refusal rules, orphan_destination, and the M1/M2 distinction; these match document_move_plan.lua:284–444 and the existing runtime call at document_move.lua:368.

## Round 5 — 2026-10-17T18:24:12-07:00 (codex) — BLOCKED

### Raised

- **BR-6** [Critical] `replayable-local-finalization` Recovery releases protection before journal retirement is safely recoverable
  lua/parley/document_move.lua:1084 calls the recovery finish hook before unlinking the journal. That hook releases the synthetic destination lock at lua/parley/agentic_document.lua:859, but the retained complete journal still requires that lock. A targeted fault-injection test confirmed that failing journal unlink after successful handoff leaves the journal permanently interrupted on reopening with "destination protection changed". ARCH-ORDER/ARCH-FUNERAL: model and persist partial finalization so lock release and journal retirement remain safely replayable; enumerate failures and crashes across these effects and add real editor recovery regressions.

## Open findings

- **BR-6** [Critical] `replayable-local-finalization` Recovery releases protection before journal retirement is safely recoverable
