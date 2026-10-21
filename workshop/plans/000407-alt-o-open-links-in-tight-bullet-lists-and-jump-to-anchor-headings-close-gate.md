---
gate: boundary-review
issue: 407
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 82ab64a5-f261-4af6-9b8f-6e994ebdd019
            repository: github.com/xianxu/parley.nvim
            issue_id: "000407"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/a1538422336d9009
            reviewed_head: 97b6fdd13e633765a7eeafe6437f8044d725de6a
            slot: parley.nvim:2
            requested_at: "2026-10-21T20:03:01.342784Z"
          phase: finished
          pid: 95352
          started_at: "2026-10-21T20:03:01.450449Z"
          finished_at: "2026-10-21T20:06:19.838619Z"
          session_id: 01a1600f-5bde-7221-aef6-4347e72104db
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 97b6fdd13e633765a7eeafe6437f8044d725de6a
        tracker_head: 346dbbcc26b6d61639607e0526e7e3a923b97f7d
        branch_point: 220b67af621c39fce796dc9a901b81d4d33c8d50
        since: "2026-10-21T08:52:51-07:00"
        until: "2026-10-21T13:02:44-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-21T08:52:51-07:00"
              end: "2026-10-21T13:02:44-07:00"
              began: "2026-10-21T08:52:51-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
        sources:
            - harness: codex
              id: 01a13b56-32ec-7310-8650-104071939f2f
              slot: parley.nvim:2
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: 6062af71dcd911fb8dcd8baa619699786c93b20a8071fd85fbe9cdb2f2548051
              started: "2026-10-14T16:54:39.906Z"
              spawned: false
              bytes: 65195225
              windows:
                - start: "2026-10-21T08:52:51-07:00"
                  end: "2026-10-21T13:02:44-07:00"
            - harness: codex
              id: 01a15f2a-cb84-75e2-ac43-0756ea7d3166
              slot: parley.nvim:2
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: e11f7236b68fea41303a58d0d0f1f0c10584246b86a5f3fd310c34645cf5bb77
              started: "2026-10-21T15:53:22.681Z"
              spawned: true
              bytes: 464175
              windows:
                - start: "2026-10-21T15:53:22.681Z"
                  end: "2026-10-21T13:02:44-07:00"
            - harness: codex
              id: 01a15f2c-08fd-7e41-b003-4e483a250212
              slot: parley.nvim:2
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: 3266063c816da0abc2c4f9be4d55ca7f52432ce3cdba187da6556d3c134a4ef9
              started: "2026-10-21T15:54:44.03Z"
              spawned: true
              bytes: 365783
              windows:
                - start: "2026-10-21T15:54:44.03Z"
                  end: "2026-10-21T13:02:44-07:00"
        queue_waits:
            - attempt_id: b82743bbb46e9281aaf07b62cd3fa8a5
              slot: parley.nvim:2
              record_digest: a39c969e463bac1818051ab6d4b66ac7aa7c82947ea00df65413fef2cd65f422
              start: "2026-10-21T16:07:08.824199Z"
              end: "2026-10-21T17:33:16.104628Z"
              queue_seconds: 5167.280429
              raw_seconds: 5167.280429
              exact: true
      "n": 1
      timestamp: "2026-10-21T13:06:20-07:00"
      dispatched: "2026-10-21T13:03:01-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      findings:
        - id: BR-1
          severity: Critical
          title: GitHub-style anchors fail for whitespace and formatted headings
          detail: 'lua/parley/markdown_heading.lua:31-35 slugs raw Markdown without trimming heading whitespace or extracting rendered text. Probes return nil for fragment "target" against "# Target ", "# _Target_", "# [Target](file.md)", and "# <em>Target</em>". The whitespace conversion also turns tabs into hyphens rather than removing them. These are all instances in the new normalization pipeline: whitespace trimming/conversion and inline-markup removal. Normalize heading content before slugging, preserve literal underscores appropriately, and add regressions for these cases and their duplicate suffixes. ARCH-PURPOSE: the documented GitHub-style anchor contract is not yet fulfilled.'
          family: heading-anchor-normalization
          round: 1
        - id: BR-2
          severity: Critical
          title: Anchor lookup treats shorter or different fence delimiters as closers
          detail: 'lua/parley/markdown_heading.lua:28 uses document.lexical.code_block_memo, whose boolean toggle ignores opener character and length. For lines {"````md", "```", "# Fake", "````", "# Real"}, anchor_row returns row 3 for "fake" and nil for "real": it exposes a code example and hides the actual heading. All affected delimiter classes are shorter backtick closers, shorter tilde closers, and mixed backtick/tilde delimiters; the new anchor lookup consumes the shared memo for all of them. Correct the shared fence-state implementation, retaining the existing partition policy, and add regressions for false headings inside and real headings after each case. ARCH-DRY: repair the shared implementation rather than adding an anchor-only fence parser.'
          family: fence-containment
          round: 1
        - id: BR-3
          severity: Critical
          title: A dedented fenced block lets a bullet absorb an outside paragraph
          detail: 'lua/parley/entity_range.lua:419-428 skips boundary detection on a fence opener because that row is already marked in_code. For {"- Chosen prose", "", "```md", "sample", "```", "[outside](outside.md)"}, navigation_range at row 1 returns rows 1-6, and reference_candidates.collect returns the outside link as its sole candidate. Alt+O therefore opens a reference outside the selected item. The same probe reproduces with tilde fences; the shared branch affects all three accepted bullet markers (-, +, *). Detect a dedented block boundary before skipping fenced contents, while retaining genuinely indented fences inside items. Add range and mapped navigation regressions for both fence styles. ARCH-PURPOSE: item navigation must remain confined to its enclosing item.'
          family: navigation-item-boundaries
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
---

# Gate ledger — parley.nvim#407 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-21T13:06:20-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `heading-anchor-normalization` GitHub-style anchors fail for whitespace and formatted headings
  lua/parley/markdown_heading.lua:31-35 slugs raw Markdown without trimming heading whitespace or extracting rendered text. Probes return nil for fragment "target" against "# Target ", "# _Target_", "# [Target](file.md)", and "# <em>Target</em>". The whitespace conversion also turns tabs into hyphens rather than removing them. These are all instances in the new normalization pipeline: whitespace trimming/conversion and inline-markup removal. Normalize heading content before slugging, preserve literal underscores appropriately, and add regressions for these cases and their duplicate suffixes. ARCH-PURPOSE: the documented GitHub-style anchor contract is not yet fulfilled.
- **BR-2** [Critical] `fence-containment` Anchor lookup treats shorter or different fence delimiters as closers
  lua/parley/markdown_heading.lua:28 uses document.lexical.code_block_memo, whose boolean toggle ignores opener character and length. For lines {"````md", "```", "# Fake", "````", "# Real"}, anchor_row returns row 3 for "fake" and nil for "real": it exposes a code example and hides the actual heading. All affected delimiter classes are shorter backtick closers, shorter tilde closers, and mixed backtick/tilde delimiters; the new anchor lookup consumes the shared memo for all of them. Correct the shared fence-state implementation, retaining the existing partition policy, and add regressions for false headings inside and real headings after each case. ARCH-DRY: repair the shared implementation rather than adding an anchor-only fence parser.
- **BR-3** [Critical] `navigation-item-boundaries` A dedented fenced block lets a bullet absorb an outside paragraph
  lua/parley/entity_range.lua:419-428 skips boundary detection on a fence opener because that row is already marked in_code. For {"- Chosen prose", "", "```md", "sample", "```", "[outside](outside.md)"}, navigation_range at row 1 returns rows 1-6, and reference_candidates.collect returns the outside link as its sole candidate. Alt+O therefore opens a reference outside the selected item. The same probe reproduces with tilde fences; the shared branch affects all three accepted bullet markers (-, +, *). Detect a dedented block boundary before skipping fenced contents, while retaining genuinely indented fences inside items. Add range and mapped navigation regressions for both fence styles. ARCH-PURPOSE: item navigation must remain confined to its enclosing item.

## Open findings

- **BR-1** [Critical] `heading-anchor-normalization` GitHub-style anchors fail for whitespace and formatted headings
- **BR-2** [Critical] `fence-containment` Anchor lookup treats shorter or different fence delimiters as closers
- **BR-3** [Critical] `navigation-item-boundaries` A dedented fenced block lets a bullet absorb an outside paragraph
