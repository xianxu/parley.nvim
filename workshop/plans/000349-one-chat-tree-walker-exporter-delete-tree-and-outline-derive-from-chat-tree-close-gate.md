---
gate: boundary-review
issue: 349
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 05fa9639-26d5-473e-9d40-7bc25b068321
            repository: github.com/xianxu/parley.nvim
            issue_id: "000349"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/709234c26a20c6fc
            reviewed_head: 4ad18c79c7234acc80db7c525e8a4313a4887e60
            slot: parley.nvim:3
            requested_at: "2026-10-16T15:46:46.99939Z"
          phase: finished
          pid: 71586
          started_at: "2026-10-16T15:46:47.190334Z"
          finished_at: "2026-10-16T15:54:03.568498Z"
          session_id: 4f74fa47-0a0e-442f-9c74-c212fc1056d3
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 4ad18c79c7234acc80db7c525e8a4313a4887e60
        tracker_head: 06382080a83a2e88a131886c8fec84291b831603
        branch_point: 9bf2df8c374ae8665a294bb183dc2478842352c5
        since: "2026-10-16T03:39:20-07:00"
        until: "2026-10-16T08:46:18-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T03:39:20-07:00"
              end: "2026-10-16T03:39:30-07:00"
              began: "2026-10-16T03:39:20-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
            - start: "2026-10-16T08:31:39-07:00"
              end: "2026-10-16T08:46:18-07:00"
              began: "2026-10-16T08:31:39-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 02a567ce9443276df1c368163ddae889a14094a7b4d8dadc9119179b336e3098
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 12882709
              windows:
                - start: "2026-10-16T03:39:20-07:00"
                  end: "2026-10-16T03:39:30-07:00"
                - start: "2026-10-16T08:31:39-07:00"
                  end: "2026-10-16T08:46:18-07:00"
      "n": 1
      timestamp: "2026-10-16T08:54:04-07:00"
      dispatched: "2026-10-16T08:46:46-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: chat_tree.files stops 20 levels below the root, so delete-tree, move and export can silently act on part of a tree
          detail: 'lua/parley/chat_tree.lua:121 returns once depth > MAX_DEPTH (20). The old init.collect_tree_files and exporter.collect_tree had no depth limit and only tracked visited files. In a chain of 22 nested chats, delete-tree leaves the deepest file, move strands it with a broken parent link, and export leaves it out, all without telling the user. This contradicts the plan''s claim of a single deliberate behaviour change. The only site in this window is chat_tree.files; path_up keeps about the old upward limit. Fix: drop the depth check in files (the seen set already stops cycles) or report truncation to the caller, and add a test that a chain longer than 20 is listed in full by get_chat_tree_files.'
          family: walker-cap-truncates-tree
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: The resolve wrapper and the header-parse loader are repeated across io_deps, disk_deps and exporter tree_deps
          detail: The resolve lambda appears in chat_tree.lua io_deps, chat_tree.lua disk_deps and exporter.lua:143. The find_header_end plus parse_chat block is repeated in io_deps and disk_deps (ARCH-DRY).
          family: duplicated-deps-loader
          round: 1
        - kind: defect
          id: BR-3
          severity: Minor
          title: Comments overstate or omit what chat_tree_files and chat_tree.lua cover
          detail: init.lua:3724-3726 says chat_tree_files is the one walker for the request context, export and the outline, but only delete-tree, move and get_chat_tree_files call it. The header comment at chat_tree.lua:1-8 still covers only path_up, linearize and io_deps, not root, files or disk_deps.
          family: comment-claim-drift
          round: 1
        - kind: defect
          id: BR-4
          severity: Minor
          title: The single-source sweep only catches resolve(...parent_link.path written on one line
          detail: Pulling the link into a local first (local l = p.parent_link; resolve(l.path, d)) gets past the guard in tests/arch/single_source_sweeps_spec.lua.
          family: sweep-pattern-coverage
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 3961d485-8305-44f1-abf6-753592fe1185
            repository: github.com/xianxu/parley.nvim
            issue_id: "000349"
            recipe: milestone-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/6c0e44c40daa9047
            reviewed_head: 5f72682db64c82b47452ac2f7dcbde6a1c85a1ab
            slot: parley.nvim:3
            requested_at: "2026-10-16T15:59:09.138395Z"
          phase: finished
          pid: 53005
          started_at: "2026-10-16T15:59:09.263139Z"
          finished_at: "2026-10-16T16:06:05.822791Z"
          session_id: abd9eb45-9dc5-4297-8250-2f8b6214d727
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 5f72682db64c82b47452ac2f7dcbde6a1c85a1ab
        tracker_head: 06382080a83a2e88a131886c8fec84291b831603
        branch_point: 9bf2df8c374ae8665a294bb183dc2478842352c5
        since: "2026-10-16T03:39:20-07:00"
        until: "2026-10-16T08:56:24-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T03:39:20-07:00"
              end: "2026-10-16T03:39:30-07:00"
              began: "2026-10-16T03:39:20-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
            - start: "2026-10-16T08:31:39-07:00"
              end: "2026-10-16T08:56:24-07:00"
              began: "2026-10-16T08:31:39-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 5ce4200eeb5ce6d52b79288982628be93b1a9d44e4d28e593b62d5b68ef21d49
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 13072057
              windows:
                - start: "2026-10-16T03:39:20-07:00"
                  end: "2026-10-16T03:39:30-07:00"
                - start: "2026-10-16T08:31:39-07:00"
                  end: "2026-10-16T08:56:24-07:00"
        cuts:
            - dispatched: "2026-10-16T08:46:46-07:00"
              finalized: "2026-10-16T08:54:04-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-16T09:06:15-07:00"
      dispatched: "2026-10-16T08:59:09-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: All three caps are gone (path_up, linearize, files); the 31-file chain unit cases and the 23-file get_chat_tree_files integration case fail under a cap of 20; suites pass.
          round: 2
        - id: BR-2
          disposition: addressed
          note: chat_tree.resolve is shared by io_deps, disk_deps and exporter tree_deps; the header parse is one local parse() (chat_tree.lua:180-189).
          round: 2
        - id: BR-3
          disposition: addressed
          note: init chat_tree_files comment names delete-tree, move and get_chat_tree_files; chat_tree.lua header covers root, files, io_deps and disk_deps.
          round: 2
        - id: BR-4
          disposition: withdrawn
          note: The operator accepted this trade-off in Revisions (a per-line allow list would be more fragile); the guard still catches a re-pasted walker in the old one-expression form.
          round: 2
      findings:
        - kind: defect
          id: BR-5
          severity: Minor
          title: The Spec and Plan still say chat_tree.files is depth-capped; Revisions removed the cap
          detail: 'This is the 2nd finding in family comment-claim-drift. Earlier rounds fixed instances in code comments; this one is in the issue contract (the files row of the Core concepts table, the Plan bullet "under the same depth cap as linearize", and Step 1''s "the depth cap"). Rule: when a Revisions entry reverses a property, every restatement of that property (Spec table, Plan, Steps, atlas, code comments) is corrected in the same commit, found by grepping for the property''s name ("depth cap", "20"). Prevalence: 3 stale sites, all in the issue file; code and atlas are clean.'
          family: comment-claim-drift
          round: 2
      recipe: milestone-review
      isolation: fenced
      reviewed: 5f72682db64c82b47452ac2f7dcbde6a1c85a1ab
      blocked: false
---

# Gate ledger — parley.nvim#349 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T08:54:04-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `walker-cap-truncates-tree` (kind: defect) chat_tree.files stops 20 levels below the root, so delete-tree, move and export can silently act on part of a tree
  lua/parley/chat_tree.lua:121 returns once depth > MAX_DEPTH (20). The old init.collect_tree_files and exporter.collect_tree had no depth limit and only tracked visited files. In a chain of 22 nested chats, delete-tree leaves the deepest file, move strands it with a broken parent link, and export leaves it out, all without telling the user. This contradicts the plan's claim of a single deliberate behaviour change. The only site in this window is chat_tree.files; path_up keeps about the old upward limit. Fix: drop the depth check in files (the seen set already stops cycles) or report truncation to the caller, and add a test that a chain longer than 20 is listed in full by get_chat_tree_files.
- **BR-2** [Minor] `duplicated-deps-loader` (kind: defect) The resolve wrapper and the header-parse loader are repeated across io_deps, disk_deps and exporter tree_deps
  The resolve lambda appears in chat_tree.lua io_deps, chat_tree.lua disk_deps and exporter.lua:143. The find_header_end plus parse_chat block is repeated in io_deps and disk_deps (ARCH-DRY).
- **BR-3** [Minor] `comment-claim-drift` (kind: defect) Comments overstate or omit what chat_tree_files and chat_tree.lua cover
  init.lua:3724-3726 says chat_tree_files is the one walker for the request context, export and the outline, but only delete-tree, move and get_chat_tree_files call it. The header comment at chat_tree.lua:1-8 still covers only path_up, linearize and io_deps, not root, files or disk_deps.
- **BR-4** [Minor] `sweep-pattern-coverage` (kind: defect) The single-source sweep only catches resolve(...parent_link.path written on one line
  Pulling the link into a local first (local l = p.parent_link; resolve(l.path, d)) gets past the guard in tests/arch/single_source_sweeps_spec.lua.

## Round 2 — 2026-10-16T09:06:15-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — All three caps are gone (path_up, linearize, files); the 31-file chain unit cases and the 23-file get_chat_tree_files integration case fail under a cap of 20; suites pass.
- BR-2 — addressed — chat_tree.resolve is shared by io_deps, disk_deps and exporter tree_deps; the header parse is one local parse() (chat_tree.lua:180-189).
- BR-3 — addressed — init chat_tree_files comment names delete-tree, move and get_chat_tree_files; chat_tree.lua header covers root, files, io_deps and disk_deps.
- BR-4 — withdrawn — The operator accepted this trade-off in Revisions (a per-line allow list would be more fragile); the guard still catches a re-pasted walker in the old one-expression form.

### Raised

- **BR-5** [Minor] `comment-claim-drift` (kind: defect) The Spec and Plan still say chat_tree.files is depth-capped; Revisions removed the cap
  This is the 2nd finding in family comment-claim-drift. Earlier rounds fixed instances in code comments; this one is in the issue contract (the files row of the Core concepts table, the Plan bullet "under the same depth cap as linearize", and Step 1's "the depth cap"). Rule: when a Revisions entry reverses a property, every restatement of that property (Spec table, Plan, Steps, atlas, code comments) is corrected in the same commit, found by grepping for the property's name ("depth cap", "20"). Prevalence: 3 stale sites, all in the issue file; code and atlas are clean.

## Open findings

- **BR-5** [Minor] `comment-claim-drift` (kind: defect) The Spec and Plan still say chat_tree.files is depth-capped; Revisions removed the cap
