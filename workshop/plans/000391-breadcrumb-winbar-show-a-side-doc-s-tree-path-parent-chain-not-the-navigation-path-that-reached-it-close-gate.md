---
gate: boundary-review
issue: 391
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: bfbc4529-a015-4a46-9767-95cec9b97c51
            repository: github.com/xianxu/parley.nvim
            issue_id: "000391"
            recipe: milestone-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/245f86cdcf6be105
            reviewed_head: ffe3c155a23a8fbe2f638f1101f670361902ae16
            slot: parley.nvim:3
            requested_at: "2026-10-19T06:01:09.05184Z"
          phase: finished
          pid: 73548
          started_at: "2026-10-19T06:01:09.298025Z"
          finished_at: "2026-10-19T06:06:03.615444Z"
          session_id: bbd1dfbf-0ba5-468a-a452-64c445d8bb04
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: ffe3c155a23a8fbe2f638f1101f670361902ae16
        tracker_head: 5a33adec63b89fb7d34a5bb8c6cf588e45cac71d
        branch_point: db7248f16be76d951384a396fd8a1a344d093c22
        since: "2026-10-18T20:36:10-07:00"
        until: "2026-10-18T23:00:25-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-18T20:36:10-07:00"
              end: "2026-10-18T23:00:25-07:00"
              began: "2026-10-18T20:36:10-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 338ec900-e10b-4fe4-be14-0f0ef1bf7fbd
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 7ed3ffd14e7a11a05eb1e98fea656b8096e538694943319867e01b225c77a66c
              started: "2026-10-18T22:09:43.273Z"
              spawned: false
              bytes: 2996758
              windows:
                - start: "2026-10-18T20:36:10-07:00"
                  end: "2026-10-18T23:00:25-07:00"
        queue_waits:
            - attempt_id: 2373632091e630b7782d45187345b7e0
              slot: parley.nvim:3
              record_digest: 52ecf60afd58b67d2464e95398a1fd83f51b13764cb19979b76bc9514c4eee12
              start: "2026-10-19T04:57:01.75779Z"
              end: "2026-10-19T05:51:07.01241Z"
              queue_seconds: 3245.25462
              raw_seconds: 3245.25462
              exact: true
      "n": 1
      timestamp: "2026-10-18T23:06:04-07:00"
      dispatched: "2026-10-18T23:01:09-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      findings:
        - kind: defect
          id: BR-1
          severity: Critical
          title: Unreadable parent file throws E484 out of the BufEnter autocmd instead of ending the chain with the missing marker
          detail: 'file_history.lua:46 calls vim.fn.readfile unguarded; reproduced with a mode-000 parent: :edit of the child errors in observe, shown/repaint are skipped and the winbar is empty, on every BufEnter. pcall the read and return nil so side_tree_model marks missing; add a test.'
          family: untrusted-file-read-must-degrade
          round: 1
        - kind: defect
          id: BR-2
          severity: Critical
          title: A side-doc tree root (discussions only) shows no winbar, contrary to the Revision and atlas
          detail: 'side_tree_model.chain returns one path with no labels or marker, so breadcrumb_model.visible (line 84) is false and the band never paints; reproduced: opening A.md gives winbar empty. Make tree values visible (tree flag or labels) and add a root-open test.'
          family: display-contract-every-file-visible
          round: 1
        - kind: defect
          id: BR-3
          severity: Important
          title: Frontmatter edit is recomputed on window re-entry but not repainted, contrary to the atlas claim
          detail: 'file_history.lua:89-92 refreshes shown[win] on every visit but repaints only when the path or presentation proof changes; reproduced: after editing parent to a missing file and WinEnter back, display() reports marker=missing while the winbar still reads A › B. Repaint when the shown value changes; test same-buffer re-entry.'
          family: display-cache-repaint-drift
          round: 1
        - kind: defect
          id: BR-4
          severity: Important
          title: 'Done when is stale: says files outside trees keep today''s trail, but the revision shows their own path'
          detail: Done when does not cover file-path display, always-visible roots and repo-top files, or the breadcrumb.enable opt-out added in Revisions.
          family: done-when-tracks-revisions
          round: 1
        - kind: defect
          id: BR-5
          severity: Important
          title: README still describes the winbar as the Alt+o file trail and omits the breadcrumb.enable config key
          detail: README.md:226 is stale after this change, and the new user config key breadcrumb = { enable = false } is not documented.
          family: readme-tracks-user-surface
          round: 1
        - kind: defect
          id: BR-6
          severity: Important
          title: Frontmatter parsing and parent resolution live inside the IO adapter read_node and are not unit-tested (ARCH-PURE)
          detail: file_history.lua:47-57 mixes a key scan, quote stripping and relative-path resolution with stat, cache and readfile. Extract a pure parse(lines, dir) into side_tree_model with unit tests, and consider reusing chat_parser's header key/value parser (ARCH-DRY).
          family: parsing-in-io-adapter
          round: 1
        - kind: defect
          id: BR-7
          severity: Minor
          title: Plan names trees[win] and a trail fallback; the code uses shown[win] and falls back to the file path
          detail: Add a Revisions entry or edit the Plan bullet so it matches file_history.lua.
          family: plan-matches-code
          round: 1
      recipe: milestone-review
      isolation: fenced
      blocked: true
---

# Gate ledger — parley.nvim#391 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-18T23:06:04-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Critical] `untrusted-file-read-must-degrade` (kind: defect) Unreadable parent file throws E484 out of the BufEnter autocmd instead of ending the chain with the missing marker
  file_history.lua:46 calls vim.fn.readfile unguarded; reproduced with a mode-000 parent: :edit of the child errors in observe, shown/repaint are skipped and the winbar is empty, on every BufEnter. pcall the read and return nil so side_tree_model marks missing; add a test.
- **BR-2** [Critical] `display-contract-every-file-visible` (kind: defect) A side-doc tree root (discussions only) shows no winbar, contrary to the Revision and atlas
  side_tree_model.chain returns one path with no labels or marker, so breadcrumb_model.visible (line 84) is false and the band never paints; reproduced: opening A.md gives winbar empty. Make tree values visible (tree flag or labels) and add a root-open test.
- **BR-3** [Important] `display-cache-repaint-drift` (kind: defect) Frontmatter edit is recomputed on window re-entry but not repainted, contrary to the atlas claim
  file_history.lua:89-92 refreshes shown[win] on every visit but repaints only when the path or presentation proof changes; reproduced: after editing parent to a missing file and WinEnter back, display() reports marker=missing while the winbar still reads A › B. Repaint when the shown value changes; test same-buffer re-entry.
- **BR-4** [Important] `done-when-tracks-revisions` (kind: defect) Done when is stale: says files outside trees keep today's trail, but the revision shows their own path
  Done when does not cover file-path display, always-visible roots and repo-top files, or the breadcrumb.enable opt-out added in Revisions.
- **BR-5** [Important] `readme-tracks-user-surface` (kind: defect) README still describes the winbar as the Alt+o file trail and omits the breadcrumb.enable config key
  README.md:226 is stale after this change, and the new user config key breadcrumb = { enable = false } is not documented.
- **BR-6** [Important] `parsing-in-io-adapter` (kind: defect) Frontmatter parsing and parent resolution live inside the IO adapter read_node and are not unit-tested (ARCH-PURE)
  file_history.lua:47-57 mixes a key scan, quote stripping and relative-path resolution with stat, cache and readfile. Extract a pure parse(lines, dir) into side_tree_model with unit tests, and consider reusing chat_parser's header key/value parser (ARCH-DRY).
- **BR-7** [Minor] `plan-matches-code` (kind: defect) Plan names trees[win] and a trail fallback; the code uses shown[win] and falls back to the file path
  Add a Revisions entry or edit the Plan bullet so it matches file_history.lua.

## Open findings

- **BR-1** [Critical] `untrusted-file-read-must-degrade` (kind: defect) Unreadable parent file throws E484 out of the BufEnter autocmd instead of ending the chain with the missing marker
- **BR-2** [Critical] `display-contract-every-file-visible` (kind: defect) A side-doc tree root (discussions only) shows no winbar, contrary to the Revision and atlas
- **BR-3** [Important] `display-cache-repaint-drift` (kind: defect) Frontmatter edit is recomputed on window re-entry but not repainted, contrary to the atlas claim
- **BR-4** [Important] `done-when-tracks-revisions` (kind: defect) Done when is stale: says files outside trees keep today's trail, but the revision shows their own path
- **BR-5** [Important] `readme-tracks-user-surface` (kind: defect) README still describes the winbar as the Alt+o file trail and omits the breadcrumb.enable config key
- **BR-6** [Important] `parsing-in-io-adapter` (kind: defect) Frontmatter parsing and parent resolution live inside the IO adapter read_node and are not unit-tested (ARCH-PURE)
- **BR-7** [Minor] `plan-matches-code` (kind: defect) Plan names trees[win] and a trail fallback; the code uses shown[win] and falls back to the file path
