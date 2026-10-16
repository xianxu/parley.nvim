---
gate: boundary-review
issue: 243
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 4f4f5428-2fcf-45f5-a57a-ef1494a9d40a
            repository: github.com/xianxu/parley.nvim
            issue_id: "000243"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/a77483556ebaabae
            reviewed_head: eba015a3047130fe96ded4df63664dec59b25309
            slot: parley.nvim:3
            requested_at: "2026-10-16T07:47:41.37071Z"
          phase: finished
          pid: 55581
          started_at: "2026-10-16T07:47:41.565166Z"
          finished_at: "2026-10-16T07:48:50.636573Z"
          session_id: e58bcf4d-2e93-4cc8-9d42-1173ef77d44c
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: eba015a3047130fe96ded4df63664dec59b25309
        tracker_head: 729773411b0267cc5b9fe562e74e5d91383d0490
        branch_point: 45eda77e14d6dd2a2b5422a6ac954b817673b871
        since: "2026-10-16T00:44:49-07:00"
        until: "2026-10-16T00:47:18-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T00:44:49-07:00"
              end: "2026-10-16T00:47:18-07:00"
              began: "2026-10-16T00:44:49-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: c06e374dd86e3e9d0e2c40e7c78d0cf7dcd500db4d1d044185349a96447c336b
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 7790171
              windows:
                - start: "2026-10-16T00:44:49-07:00"
                  end: "2026-10-16T00:47:18-07:00"
      "n": 1
      timestamp: "2026-10-16T00:48:52-07:00"
      dispatched: "2026-10-16T00:47:41-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: HTML export inserts the chat topic into the page title without escaping (exporter.lua:884)
          detail: 'write_html_file builds `<title>` .. info.title .. `</title>`, where info.title is the chat''s raw `topic:` header (exporter.lua:75-76). A topic like `</title><script>alert(1)</script>` lands raw in the exported page, and a child chat''s topic usually equals its branch topic, so the script #243 removed from the nav link is still in the child''s page. Same class as #243 (ARCH-PURPOSE sweep). Every place the export inserts chat text was checked: branch nav div and inline anchor are fixed; image alt/src are covered by the body escape plus the quote escape; the Markdown Jekyll title is YAML-quoted; the plain-text fallbacks are body text. The title is the only remaining instance. Fix: escape_html(info.title), plus an end-to-end check that a `<script>` topic is not raw in the exported page.'
          family: chat-text-into-built-html-unescaped
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: simple_markdown_to_html repeats escape_html's work with its own gsubs
          detail: exporter.lua:474-476 escapes `&`, `<`, `>` with three separate gsubs, and exporter.lua:487-488 escapes `"` for the image src/alt itself. Both repeat what escape_html (exporter.lua:331-335) now does (ARCH-DRY). Make them use the helper, or a version without the quote escape for body text.
          family: duplicated-html-escape
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: a7e8f406-bb37-4e46-90c7-a3c9bc87684a
            repository: github.com/xianxu/parley.nvim
            issue_id: "000243"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/46e7de1be5806678
            reviewed_head: 005efb89b09844672572bcc97ef0600a95303bf7
            slot: parley.nvim:3
            requested_at: "2026-10-16T07:50:26.605098Z"
          phase: finished
          pid: 69111
          started_at: "2026-10-16T07:50:26.819942Z"
          finished_at: "2026-10-16T07:51:51.010262Z"
          session_id: bfc2a2c7-26c7-4fe5-809d-1f5ada2d26c2
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 005efb89b09844672572bcc97ef0600a95303bf7
        tracker_head: 729773411b0267cc5b9fe562e74e5d91383d0490
        branch_point: 45eda77e14d6dd2a2b5422a6ac954b817673b871
        since: "2026-10-16T00:44:49-07:00"
        until: "2026-10-16T00:49:53-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T00:44:49-07:00"
              end: "2026-10-16T00:49:53-07:00"
              began: "2026-10-16T00:44:49-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: cde48c6143ac91672a8e77a92992e9b61ccb2f3263538761b5eec8a6304b59e1
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 7909103
              windows:
                - start: "2026-10-16T00:44:49-07:00"
                  end: "2026-10-16T00:49:53-07:00"
        cuts:
            - dispatched: "2026-10-16T00:47:41-07:00"
              finalized: "2026-10-16T00:48:52-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-16T00:51:53-07:00"
      dispatched: "2026-10-16T00:50:26-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: exporter.lua:882 now uses escape_html(info.title). A0 checks the escaped title, and removing the escape makes A0 fail (12/13). Restored afterwards.
          round: 2
        - id: BR-2
          disposition: addressed
          note: simple_markdown_to_html now calls escape_html (exporter.lua:476), and the image code no longer escapes quotes itself. The quote-escape tests at exporter_tree_spec.lua:507-508 still pass.
          round: 2
      recipe: small-diff-review
      isolation: fenced
      reviewed: 005efb89b09844672572bcc97ef0600a95303bf7
      blocked: false
---

# Gate ledger — parley.nvim#243 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T00:48:52-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `chat-text-into-built-html-unescaped` (kind: defect) HTML export inserts the chat topic into the page title without escaping (exporter.lua:884)
  write_html_file builds `<title>` .. info.title .. `</title>`, where info.title is the chat's raw `topic:` header (exporter.lua:75-76). A topic like `</title><script>alert(1)</script>` lands raw in the exported page, and a child chat's topic usually equals its branch topic, so the script #243 removed from the nav link is still in the child's page. Same class as #243 (ARCH-PURPOSE sweep). Every place the export inserts chat text was checked: branch nav div and inline anchor are fixed; image alt/src are covered by the body escape plus the quote escape; the Markdown Jekyll title is YAML-quoted; the plain-text fallbacks are body text. The title is the only remaining instance. Fix: escape_html(info.title), plus an end-to-end check that a `<script>` topic is not raw in the exported page.
- **BR-2** [Minor] `duplicated-html-escape` (kind: defect) simple_markdown_to_html repeats escape_html's work with its own gsubs
  exporter.lua:474-476 escapes `&`, `<`, `>` with three separate gsubs, and exporter.lua:487-488 escapes `"` for the image src/alt itself. Both repeat what escape_html (exporter.lua:331-335) now does (ARCH-DRY). Make them use the helper, or a version without the quote escape for body text.

## Round 2 — 2026-10-16T00:51:53-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — exporter.lua:882 now uses escape_html(info.title). A0 checks the escaped title, and removing the escape makes A0 fail (12/13). Restored afterwards.
- BR-2 — addressed — simple_markdown_to_html now calls escape_html (exporter.lua:476), and the image code no longer escapes quotes itself. The quote-escape tests at exporter_tree_spec.lua:507-508 still pass.

## Open findings

(none — every finding has been disposed)
