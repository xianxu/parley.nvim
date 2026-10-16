---
gate: boundary-review
issue: 233
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: e44a0aa6-9f57-4bca-a58b-cf3e2f0a73dc
            repository: github.com/xianxu/parley.nvim
            issue_id: "000233"
            recipe: milestone-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/65150ce05fcfb88c
            reviewed_head: f2e1d5aaa40012ef930599bc1134ea5f3bd68c8b
            slot: parley.nvim:3
            requested_at: "2026-10-16T10:51:43.842652Z"
          phase: finished
          pid: 21282
          started_at: "2026-10-16T10:51:44.237447Z"
          finished_at: "2026-10-16T10:55:09.959142Z"
          session_id: 6611dd7f-dec9-40a8-a9b5-77abc6f0d4dd
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: f2e1d5aaa40012ef930599bc1134ea5f3bd68c8b
        tracker_head: f77f0575d4a4015824d9a169f4ae2631bb9f772c
        branch_point: 111893e128e74350964044dbe9b8007a38099149
        since: "2026-10-16T03:36:06-07:00"
        until: "2026-10-16T03:50:57-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T03:36:06-07:00"
              end: "2026-10-16T03:50:57-07:00"
              began: "2026-10-16T03:36:06-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 2891a64bee2054b4390972c64b379e3fb23d16fcbe11cfeab03ae60940091c97
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 10364436
              windows:
                - start: "2026-10-16T03:36:06-07:00"
                  end: "2026-10-16T03:50:57-07:00"
      "n": 1
      timestamp: "2026-10-16T03:55:11-07:00"
      dispatched: "2026-10-16T03:51:43-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: Remote @@url@@ references in other files of the tree are never resolved; the request carries a "not cached, refresh the question" error stub
          detail: 'resolve_remote_references still runs over input_parsed/input_index only (chat_respond.lua:1734), while build_messages pins every file-ref exchange in the sequence (:810) and falls through to format_missing_remote_reference_cache_content (:854). A probe with a parent `@@https://example.com/x@@` produced that system message in the child''s request, which contradicts atlas lifecycle "inlined as in their own file". Fix: resolve per item.file (cache lookup) or omit the stub, and add a regression test.'
          family: sequence-consumers-derive-from-tree
          round: 1
        - kind: defect
          id: BR-2
          severity: Important
          title: Batch-leg input_rows and the visual range drop current-file exchanges but keep the asides anchored on them
          detail: tree_sequence linearizes the full parsed file and filters only current items against input_parsed (chat_respond.lua:183-191); non-current subtree items always pass, and build_messages exempts them from start_index. A batch leg that excludes Q1 still sends Q1's aside, cut off from the exchange it is about. Tag subtree items with their anchoring exchange in linearize and drop those whose anchor is filtered out; add a test.
          family: sequence-consumers-derive-from-tree
          round: 1
        - kind: defect
          id: BR-3
          severity: Important
          title: Memory window now counts back from the cut, not the end of the file, which changes single-file mid-chat resubmits
          detail: 'total_exchanges became #sequence, and the sequence ends at the cut (chat_respond.lua:791); before, it was #parsed_chat.exchanges. Resubmitting exchange 3 of 10 with max_full_exchanges=4 now keeps exchanges 1-2 in full where they used to be summarized. The plan says "No change to how a file''s own exchanges render", and no test covers this. Declare it in Revisions with a test, or restore the old total.'
          family: undeclared-behavior-change
          round: 1
        - kind: defect
          id: BR-4
          severity: Minor
          title: tree_context sequence-to-text helper is copy-pasted in two integration specs
          detail: ancestor_chain_rename_spec.lua:43-55 and chat_respond_spec.lua:413-418 hold the same loop over non-current items; move it to a shared test helper.
          family: test-helper-duplication
          round: 1
        - kind: defect
          id: BR-5
          severity: Minor
          title: Every submission synchronously reads and parses the whole left subtree, with no latency envelope or measurement
          detail: Only request size was measured. The number of files read is bounded only by depth 20 per path, not by tree width, and the parsing runs inside build() on the UI loop.
          family: operating-envelope-undeclared
          round: 1
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: f71b39b0-22ed-41ef-befa-8b0f2d95315f
            repository: github.com/xianxu/parley.nvim
            issue_id: "000233"
            recipe: milestone-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/72f789953e7006da
            reviewed_head: e2ea2bb56b53eba6c413c4c7fc9b90747be3cf5d
            slot: parley.nvim:3
            requested_at: "2026-10-16T11:00:39.190762Z"
          phase: finished
          pid: 91668
          started_at: "2026-10-16T11:00:39.349994Z"
          finished_at: "2026-10-16T11:03:49.511299Z"
          session_id: cd414908-5754-4bbd-97d1-aebd5540b856
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: e2ea2bb56b53eba6c413c4c7fc9b90747be3cf5d
        tracker_head: 4876a7bfb1df214e6e6043bde9386b8b741026d1
        branch_point: 111893e128e74350964044dbe9b8007a38099149
        since: "2026-10-16T03:36:06-07:00"
        until: "2026-10-16T04:00:15-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T03:36:06-07:00"
              end: "2026-10-16T04:00:15-07:00"
              began: "2026-10-16T03:36:06-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 092a7eda509bd5eaa37bdd73b77e9ed597fb04269bbc555fd239ce790b080056
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 10686027
              windows:
                - start: "2026-10-16T03:36:06-07:00"
                  end: "2026-10-16T04:00:15-07:00"
        cuts:
            - dispatched: "2026-10-16T03:51:43-07:00"
              finalized: "2026-10-16T03:55:11-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-16T04:03:54-07:00"
      dispatched: "2026-10-16T04:00:39-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: resolve_remote_references walks the shared sequence with per-file caches; the chat_tree_context_spec test fails when the cache lookup is reverted. The new symlink regression is raised separately.
          round: 2
        - id: BR-2
          disposition: addressed
          note: linearize tags anchors and tree_sequence filters on them; both drop tests fail when the filter and anchor_row are reverted.
          round: 2
        - id: BR-3
          disposition: addressed
          note: The tail after the cut restores the single-file total; the mid-chat window test fails when the tail loop is removed.
          round: 2
        - id: BR-4
          disposition: addressed
          note: tests/helpers/tree_context.lua other_files is used by both specs; no other copies are left in tests/.
          round: 2
        - id: BR-5
          disposition: addressed
          note: Latency measured (0.25 ms/KB, median 11-16 ms on a 58 KB tree) and stated in atlas/chat/lifecycle.md.
          round: 2
      findings:
        - kind: defect
          id: BR-6
          severity: Critical
          title: Remote cache lookup compares a resolved path with the unresolved buffer name, so symlinked chat dirs refetch and can overwrite cached URLs with errors
          detail: 'chat_respond.lua:1245 picks the cache by item.file ~= chat_file. tree_sequence stores vim.fn.resolve''d paths, but chat_file is frame.file_name (the buffer name). Under a symlinked chat_dir, the current file''s earlier @@url@@ references miss chat_cache and are fetched again on every submit. A failed fetch writes error text into resolved and into chat_cache (saved), replacing good content. A probe with a symlinked dir returned the error stub instead of CACHED; before #233 the current file always read chat_cache. Ancestor caches miss the same way. Fix: use chat_cache for item.current, canonicalize keys in get_chat_remote_reference_cache with a legacy-key read fallback, and add a symlinked-dir regression test (write_chat''s resolve() hides it today).'
          family: canonical-file-identity
          round: 2
        - kind: defect
          id: BR-7
          severity: Minor
          title: Per-item cache lookup saves an empty chats entry for every tree file, with no pruning
          detail: 'This is the 2nd finding in family operating-envelope-undeclared. The rule: a lookup must not write. get_chat_remote_reference_cache creates chats[key] = {} for every item in every tree, including items with no URLs, and the next save persists those entries. Give it a read-only variant for lookups (ARCH-FUNERAL).'
          family: operating-envelope-undeclared
          round: 2
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: b95b1f8a-32be-4070-a097-46653a7f6c90
            repository: github.com/xianxu/parley.nvim
            issue_id: "000233"
            recipe: milestone-review
            round: 3
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/89f8b93c6b22efba
            reviewed_head: a6f6a26ec797089da0e3196b11ecffa113474839
            slot: parley.nvim:3
            requested_at: "2026-10-16T11:06:38.046538Z"
          phase: finished
          pid: 57070
          started_at: "2026-10-16T11:06:38.247333Z"
          finished_at: "2026-10-16T11:09:06.615845Z"
          session_id: aac05daf-6913-4597-b797-7a06e3b5cb5c
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: a6f6a26ec797089da0e3196b11ecffa113474839
        tracker_head: 2afa847cfdb56244ed1eb5741b9769511ec451e8
        branch_point: 111893e128e74350964044dbe9b8007a38099149
        since: "2026-10-16T03:36:06-07:00"
        until: "2026-10-16T04:06:08-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T03:36:06-07:00"
              end: "2026-10-16T04:06:08-07:00"
              began: "2026-10-16T03:36:06-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 190c81800f09db82a983cb7d485bcf852bb696ea251529c7b9e9734c4abf55f1
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 10805724
              windows:
                - start: "2026-10-16T03:36:06-07:00"
                  end: "2026-10-16T04:06:08-07:00"
        cuts:
            - dispatched: "2026-10-16T03:51:43-07:00"
              finalized: "2026-10-16T03:55:11-07:00"
              finalizing: false
            - dispatched: "2026-10-16T04:00:39-07:00"
              finalized: "2026-10-16T04:03:54-07:00"
              finalizing: false
      "n": 3
      timestamp: "2026-10-16T04:09:14-07:00"
      dispatched: "2026-10-16T04:06:38-07:00"
      agent: claude
      dispose:
        - id: BR-6
          disposition: addressed
          note: chat_cache_key canonicalizes with a legacy-key move, item.current picks the cache; the symlinked-dir regression test is red with chat_respond.lua reverted to e2ea2bb5 (8 passed, 2 failed) and green at head.
          round: 3
        - id: BR-7
          disposition: addressed
          note: peek_chat_remote_reference_cache is read-only; the "without creating an entry" test fails with the fix reverted and passes at head.
          round: 3
      findings:
        - kind: defect
          id: BR-8
          severity: Important
          title: A fetched remote reference from another tree file is written to the current file's cache, which no lookup reads, so it is fetched on every submit
          detail: 'resolve_remote_references looks up other-file items in peek(item.file) (chat_respond.lua:1264) but writes every fetch result into chat_cache (line 1338). A URL that misses in an ancestor''s cache, for example after a rename or prune, is fetched again on every submit. This is the 2nd finding in this family. The rule: a reference''s cache entry is read and written under the key of the file that holds it. Apply it to every read and write site, and add a two-submit test with a fake oauth.fetch_content that checks the fetch runs once.'
          family: canonical-file-identity
          round: 3
        - kind: defect
          id: BR-9
          severity: Minor
          title: Failed or fetched ancestor URLs pile up in the current file's cache, and the peek legacy fallback never matches
          detail: Error stubs and content for URLs the current file never references are saved under its key. The peek fallback looks up the already-resolved item.file again, so old entries saved under a symlinked name for an ancestor are never found.
          family: operating-envelope-undeclared
          round: 3
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 842e104a-bc79-4d78-b86b-3b835b8171a8
            repository: github.com/xianxu/parley.nvim
            issue_id: "000233"
            recipe: milestone-review
            round: 4
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/e4d339d87510afbd
            reviewed_head: 73d62dcd0172cadfa810791c9cffb937ad75db57
            slot: parley.nvim:3
            requested_at: "2026-10-16T11:11:19.749458Z"
          phase: finished
          pid: 88766
          started_at: "2026-10-16T11:11:19.885818Z"
          finished_at: "2026-10-16T11:16:45.222782Z"
          session_id: 5594be4e-ab01-4efe-a4c4-166784bb2c2a
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 73d62dcd0172cadfa810791c9cffb937ad75db57
        tracker_head: 2afa847cfdb56244ed1eb5741b9769511ec451e8
        branch_point: 111893e128e74350964044dbe9b8007a38099149
        since: "2026-10-16T03:36:06-07:00"
        until: "2026-10-16T04:10:56-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T03:36:06-07:00"
              end: "2026-10-16T04:10:56-07:00"
              began: "2026-10-16T03:36:06-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: a8f2648a9527bbd9cc229af4e0dc64b96d135eeae554828d6468223bf437038c
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 10909395
              windows:
                - start: "2026-10-16T03:36:06-07:00"
                  end: "2026-10-16T04:10:56-07:00"
        cuts:
            - dispatched: "2026-10-16T03:51:43-07:00"
              finalized: "2026-10-16T03:55:11-07:00"
              finalizing: false
            - dispatched: "2026-10-16T04:00:39-07:00"
              finalized: "2026-10-16T04:03:54-07:00"
              finalizing: false
            - dispatched: "2026-10-16T04:06:38-07:00"
              finalized: "2026-10-16T04:09:14-07:00"
              finalizing: false
      "n": 4
      timestamp: "2026-10-16T04:16:46-07:00"
      dispatched: "2026-10-16T04:11:19-07:00"
      agent: claude
      dispose:
        - id: BR-8
          disposition: addressed
          note: holder[url] routes each fetch to its holder's key (chat_respond.lua:1342); reverting that line makes the new two-submit test in chat_tree_context_spec fail, and restoring it makes it pass.
          round: 4
        - id: BR-9
          disposition: addressed
          note: Ancestor URLs (content or error stubs) now save under the ancestor's key, and the test asserts the child's cache stays empty; the dead peek fallback is removed (chat_respond.lua:274-276).
          round: 4
      recipe: milestone-review
      isolation: fenced
      reviewed: 73d62dcd0172cadfa810791c9cffb937ad75db57
      blocked: false
---

# Gate ledger — parley.nvim#233 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T03:55:11-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `sequence-consumers-derive-from-tree` (kind: defect) Remote @@url@@ references in other files of the tree are never resolved; the request carries a "not cached, refresh the question" error stub
  resolve_remote_references still runs over input_parsed/input_index only (chat_respond.lua:1734), while build_messages pins every file-ref exchange in the sequence (:810) and falls through to format_missing_remote_reference_cache_content (:854). A probe with a parent `@@https://example.com/x@@` produced that system message in the child's request, which contradicts atlas lifecycle "inlined as in their own file". Fix: resolve per item.file (cache lookup) or omit the stub, and add a regression test.
- **BR-2** [Important] `sequence-consumers-derive-from-tree` (kind: defect) Batch-leg input_rows and the visual range drop current-file exchanges but keep the asides anchored on them
  tree_sequence linearizes the full parsed file and filters only current items against input_parsed (chat_respond.lua:183-191); non-current subtree items always pass, and build_messages exempts them from start_index. A batch leg that excludes Q1 still sends Q1's aside, cut off from the exchange it is about. Tag subtree items with their anchoring exchange in linearize and drop those whose anchor is filtered out; add a test.
- **BR-3** [Important] `undeclared-behavior-change` (kind: defect) Memory window now counts back from the cut, not the end of the file, which changes single-file mid-chat resubmits
  total_exchanges became #sequence, and the sequence ends at the cut (chat_respond.lua:791); before, it was #parsed_chat.exchanges. Resubmitting exchange 3 of 10 with max_full_exchanges=4 now keeps exchanges 1-2 in full where they used to be summarized. The plan says "No change to how a file's own exchanges render", and no test covers this. Declare it in Revisions with a test, or restore the old total.
- **BR-4** [Minor] `test-helper-duplication` (kind: defect) tree_context sequence-to-text helper is copy-pasted in two integration specs
  ancestor_chain_rename_spec.lua:43-55 and chat_respond_spec.lua:413-418 hold the same loop over non-current items; move it to a shared test helper.
- **BR-5** [Minor] `operating-envelope-undeclared` (kind: defect) Every submission synchronously reads and parses the whole left subtree, with no latency envelope or measurement
  Only request size was measured. The number of files read is bounded only by depth 20 per path, not by tree width, and the parsing runs inside build() on the UI loop.

## Round 2 — 2026-10-16T04:03:54-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — addressed — resolve_remote_references walks the shared sequence with per-file caches; the chat_tree_context_spec test fails when the cache lookup is reverted. The new symlink regression is raised separately.
- BR-2 — addressed — linearize tags anchors and tree_sequence filters on them; both drop tests fail when the filter and anchor_row are reverted.
- BR-3 — addressed — The tail after the cut restores the single-file total; the mid-chat window test fails when the tail loop is removed.
- BR-4 — addressed — tests/helpers/tree_context.lua other_files is used by both specs; no other copies are left in tests/.
- BR-5 — addressed — Latency measured (0.25 ms/KB, median 11-16 ms on a 58 KB tree) and stated in atlas/chat/lifecycle.md.

### Raised

- **BR-6** [Critical] `canonical-file-identity` (kind: defect) Remote cache lookup compares a resolved path with the unresolved buffer name, so symlinked chat dirs refetch and can overwrite cached URLs with errors
  chat_respond.lua:1245 picks the cache by item.file ~= chat_file. tree_sequence stores vim.fn.resolve'd paths, but chat_file is frame.file_name (the buffer name). Under a symlinked chat_dir, the current file's earlier @@url@@ references miss chat_cache and are fetched again on every submit. A failed fetch writes error text into resolved and into chat_cache (saved), replacing good content. A probe with a symlinked dir returned the error stub instead of CACHED; before #233 the current file always read chat_cache. Ancestor caches miss the same way. Fix: use chat_cache for item.current, canonicalize keys in get_chat_remote_reference_cache with a legacy-key read fallback, and add a symlinked-dir regression test (write_chat's resolve() hides it today).
- **BR-7** [Minor] `operating-envelope-undeclared` (kind: defect) Per-item cache lookup saves an empty chats entry for every tree file, with no pruning
  This is the 2nd finding in family operating-envelope-undeclared. The rule: a lookup must not write. get_chat_remote_reference_cache creates chats[key] = {} for every item in every tree, including items with no URLs, and the next save persists those entries. Give it a read-only variant for lookups (ARCH-FUNERAL).

## Round 3 — 2026-10-16T04:09:14-07:00 (claude) — BLOCKED

### Disposed

- BR-6 — addressed — chat_cache_key canonicalizes with a legacy-key move, item.current picks the cache; the symlinked-dir regression test is red with chat_respond.lua reverted to e2ea2bb5 (8 passed, 2 failed) and green at head.
- BR-7 — addressed — peek_chat_remote_reference_cache is read-only; the "without creating an entry" test fails with the fix reverted and passes at head.

### Raised

- **BR-8** [Important] `canonical-file-identity` (kind: defect) A fetched remote reference from another tree file is written to the current file's cache, which no lookup reads, so it is fetched on every submit
  resolve_remote_references looks up other-file items in peek(item.file) (chat_respond.lua:1264) but writes every fetch result into chat_cache (line 1338). A URL that misses in an ancestor's cache, for example after a rename or prune, is fetched again on every submit. This is the 2nd finding in this family. The rule: a reference's cache entry is read and written under the key of the file that holds it. Apply it to every read and write site, and add a two-submit test with a fake oauth.fetch_content that checks the fetch runs once.
- **BR-9** [Minor] `operating-envelope-undeclared` (kind: defect) Failed or fetched ancestor URLs pile up in the current file's cache, and the peek legacy fallback never matches
  Error stubs and content for URLs the current file never references are saved under its key. The peek fallback looks up the already-resolved item.file again, so old entries saved under a symlinked name for an ancestor are never found.

## Round 4 — 2026-10-16T04:16:46-07:00 (claude) — passed

### Disposed

- BR-8 — addressed — holder[url] routes each fetch to its holder's key (chat_respond.lua:1342); reverting that line makes the new two-submit test in chat_tree_context_spec fail, and restoring it makes it pass.
- BR-9 — addressed — Ancestor URLs (content or error stubs) now save under the ancestor's key, and the test asserts the child's cache stays empty; the dead peek fallback is removed (chat_respond.lua:274-276).

## Open findings

(none — every finding has been disposed)
