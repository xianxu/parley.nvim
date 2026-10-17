---
gate: boundary-review
issue: 377
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: ef08c0a1-ed71-42f4-85e8-f036a2e1045e
            repository: github.com/xianxu/parley.nvim
            issue_id: "000377"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/9cb114540eb23ee8
            reviewed_head: 5e972a463e22da22aa39ee329ee611489ee0376a
            slot: parley.nvim:4
            requested_at: "2026-10-17T19:51:16.532636Z"
          phase: finished
          pid: 49552
          started_at: "2026-10-17T19:51:16.627681Z"
          finished_at: "2026-10-17T19:55:47.31533Z"
          session_id: cdd94c89-d492-4788-88b5-cdfcc98ea669
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 5e972a463e22da22aa39ee329ee611489ee0376a
        tracker_head: 1a9cffeede4a0e6702ca6cd0e2de5cd385dae75b
        branch_point: 81fecd406998589d02bd6724efdac42939399ea9
        since: "2026-10-17T12:11:42-07:00"
        until: "2026-10-17T12:14:46-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T12:11:42-07:00"
              end: "2026-10-17T12:14:46-07:00"
              began: "2026-10-17T12:11:42-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: d71f1e2e5c0c4a9a5a9088302b0a1c958f2ed35052ed233d4b9420ddd1849c0f
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 34132845
              windows:
                - start: "2026-10-17T12:11:42-07:00"
                  end: "2026-10-17T12:14:46-07:00"
      "n": 1
      timestamp: "2026-10-17T12:55:51-07:00"
      dispatched: "2026-10-17T12:51:16-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: Shipped tutorials and starter README still teach the old keys (option+i branches, option+v/Alt+v pastes)
          detail: 'All instances in the tree: packaging/tutorials/basics.md:76 (option+i on a selection creates a linked chat; should be option+b, since M-i is now n/i paste and unbound in v); packaging/tutorials/advanced.md:126 (option+v; should be option+i); packaging/starter-config/README.md:67 (Alt+v; should be Alt+i); workshop/parley/welcome.md:15 (Alt+v); workshop/parley/basics.md:61,72 (Option+i for branch); workshop/parley/advanced.md:63 (Option+i for branch), :139 (Option+v). ARCH-PURPOSE: no test ties tutorial key prose to the registry, so these drifted silently. Consider a cheap spec that greps the packaging/tutorials files for the paste_image/branch_ref keys.'
          family: key-remap-doc-sweep
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: History comments rewritten from M-i to M-b now misstate the past
          detail: atlas/chat/drill_in.md:166 says the 214 bug was on M-b, a key that did not exist then. Same rewrite at lua/parley/branch_submit.lua:22, lua/parley/drill_in.lua:349, lua/parley/buffer_edit.lua:231, atlas/chat/inline_branch_links.md:54, tests/unit/branch_submit_spec.lua:508, tests/integration/branch_child_spec.lua:5. Either say "the branch key" or keep M-i with a "(now M-b, 377)" note.
          family: history-notes-rewritten
          round: 1
        - kind: defect
          id: BR-3
          severity: Minor
          title: keybinding_agreement_spec.lua:280 still checks M-i, which now means paste_image instead of branch
          detail: It still passes, but the key it checks now belongs to paste_image. Add or replace it with M-b so the branch default is covered under default_keymaps=false.
          family: stale-test-intent
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 83cd24d2-92f8-4122-8af6-90b7a7e35b68
            repository: github.com/xianxu/parley.nvim
            issue_id: "000377"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/f148790c96a8508c
            reviewed_head: 131c684c6ca6fde3af69e7fb119e31c9c523510f
            slot: parley.nvim:4
            requested_at: "2026-10-17T20:44:56.255852Z"
          phase: finished
          pid: 21320
          started_at: "2026-10-17T20:44:56.435532Z"
          finished_at: "2026-10-17T20:50:06.981024Z"
          session_id: 66409077-9160-4053-a678-a9d59064d116
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 131c684c6ca6fde3af69e7fb119e31c9c523510f
        tracker_head: 27820006cab761f7d79f6fdd18973bdfb0bc7a1a
        branch_point: 81fecd406998589d02bd6724efdac42939399ea9
        since: "2026-10-17T12:11:42-07:00"
        until: "2026-10-17T12:59:37-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T12:11:42-07:00"
              end: "2026-10-17T12:59:37-07:00"
              began: "2026-10-17T12:11:42-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: ef157dd010ee0f139877315856ec3c25d9fc101822e573ce6d0214446c3b15fb
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 34531809
              windows:
                - start: "2026-10-17T12:11:42-07:00"
                  end: "2026-10-17T12:59:37-07:00"
        queue_waits:
            - attempt_id: 146a572d6f0d1a71f4276a28de0dc1fb
              slot: parley.nvim:4
              record_digest: 85931e95d75753b516637d0968db5ba67e3a74ccdbcba74f2f165e6036056abe
              start: "2026-10-17T19:14:54.796798Z"
              end: "2026-10-17T19:48:24.800858Z"
              queue_seconds: 2010.00406
              raw_seconds: 2010.00406
              exact: true
        excluded_brain_sessions: 1
        excluded_brain_minutes: 6.264183333333333
        cuts:
            - dispatched: "2026-10-17T12:51:16-07:00"
              finalized: "2026-10-17T12:55:51-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-17T13:50:08-07:00"
      dispatched: "2026-10-17T13:44:56-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: All listed sites fixed (packaging/tutorials basics.md:76 and advanced.md:126, starter README:67, workshop/parley welcome/basics/advanced). The new spec at keybinding_agreement_spec.lua:673 goes red when basics.md:76 is reverted to option+i (checked by mutation).
          round: 2
        - id: BR-2
          disposition: addressed
          note: All seven named sites now say "<M-i> (now <M-b>)". The one remaining stale history comment, init.lua:2472, is a separate Minor below.
          round: 2
        - id: BR-3
          disposition: addressed
          note: keybinding_agreement_spec.lua:281 now also asserts <M-b> is absent under default_keymaps=false. This is test-only, so no behavior revert applies.
          round: 2
      findings:
        - kind: defect
          id: BR-4
          severity: Minor
          title: init.lua:2472 says <M-b> did something before M3, but <M-b> was not bound then
          detail: 'This is the 2nd finding in family history-notes-rewritten. The rule: a comment that describes past behaviour (did, was, used to, before Mn, hardcoded) keeps the key that was bound at the time and adds "(now <M-b>)". Sweep check: git grep -n ''<M-b>'' -- lua tests atlas | grep -Ei ''did|was|used to|before|hardcod|were''. In this window that grep hits seven lines; every one except init.lua:2472 is either correct or present-tense, so init.lua:2472 is the whole remaining family.'
          family: history-notes-rewritten
          round: 2
        - kind: defect
          id: BR-5
          severity: Minor
          title: Tutorial key spec reads only packaging docs, not README.md or workshop/parley tutorials
          detail: 'This is the 2nd finding in family key-remap-doc-sweep. The rule: every file that teaches a key in prose must be in the spec''s file list. All of them are correct today. Unchecked files: README.md (Alt+i at line 183), workshop/parley/welcome.md:15, workshop/parley/basics.md:61,72, and workshop/parley/advanced.md:63,139. Add them to the file list at keybinding_agreement_spec.lua:684-685.'
          family: key-remap-doc-sweep
          round: 2
      recipe: small-diff-review
      isolation: fenced
      reviewed: 131c684c6ca6fde3af69e7fb119e31c9c523510f
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 36a19d47-50e7-410d-a40b-9d8853286105
            repository: github.com/xianxu/parley.nvim
            issue_id: "000377"
            recipe: fix-review
            round: 3
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/9fd9a3e675f77312
            reviewed_head: 0342dddacf2bd79268ec0c437ab515d28a5eddb3
            slot: parley.nvim:4
            requested_at: "2026-10-17T20:52:02.512405Z"
          phase: finished
          pid: 86218
          started_at: "2026-10-17T20:52:02.724423Z"
          finished_at: "2026-10-17T20:53:24.635143Z"
          session_id: bd014708-7538-43b1-ad4d-7b208420e193
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 0342dddacf2bd79268ec0c437ab515d28a5eddb3
        tracker_head: 27820006cab761f7d79f6fdd18973bdfb0bc7a1a
        branch_point: 81fecd406998589d02bd6724efdac42939399ea9
        since: "2026-10-17T12:11:42-07:00"
        until: "2026-10-17T13:51:18-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T12:11:42-07:00"
              end: "2026-10-17T13:51:18-07:00"
              began: "2026-10-17T12:11:42-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 60a9c59a816cafd3dbade51e4aa1b93deac64bfe5473c167df276f3c4ee18605
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 34651029
              windows:
                - start: "2026-10-17T12:11:42-07:00"
                  end: "2026-10-17T13:51:18-07:00"
        queue_waits:
            - attempt_id: 146a572d6f0d1a71f4276a28de0dc1fb
              slot: parley.nvim:4
              record_digest: 85931e95d75753b516637d0968db5ba67e3a74ccdbcba74f2f165e6036056abe
              start: "2026-10-17T19:14:54.796798Z"
              end: "2026-10-17T19:48:24.800858Z"
              queue_seconds: 2010.00406
              raw_seconds: 2010.00406
              exact: true
            - attempt_id: a4ad4a127b325723916577fdc0199a67
              slot: parley.nvim:4
              record_digest: 517a88fa96f95bb1ef0c147c18069f1b24c7fc486b861d08ea766b4330516718
              start: "2026-10-17T19:59:45.294553Z"
              end: "2026-10-17T20:41:57.482666Z"
              queue_seconds: 2532.188113
              raw_seconds: 2532.188113
              exact: true
        excluded_brain_sessions: 1
        excluded_brain_minutes: 51.22708333333333
        cuts:
            - dispatched: "2026-10-17T12:51:16-07:00"
              finalized: "2026-10-17T12:55:51-07:00"
              finalizing: false
            - dispatched: "2026-10-17T13:44:56-07:00"
              finalized: "2026-10-17T13:50:08-07:00"
              finalizing: true
      "n": 3
      timestamp: "2026-10-17T13:53:25-07:00"
      dispatched: "2026-10-17T13:52:02-07:00"
      agent: claude
      dispose:
        - id: BR-4
          disposition: addressed
          note: init.lua:2472 now reads "`<M-i>` (now `<M-b>`) did before M3"; the sweep grep shows every past-tense hit follows the rule.
          round: 3
        - id: BR-5
          disposition: addressed
          note: The spec now globs workshop/parley/*.md and adds README.md. Mutating basics.md:61 and README.md:183 each turned the test red; the clean run passes 36/0.
          round: 3
      recipe: fix-review
      isolation: fenced
      reviewed: 0342dddacf2bd79268ec0c437ab515d28a5eddb3
      blocked: false
---

# Gate ledger — parley.nvim#377 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-17T12:55:51-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `key-remap-doc-sweep` (kind: defect) Shipped tutorials and starter README still teach the old keys (option+i branches, option+v/Alt+v pastes)
  All instances in the tree: packaging/tutorials/basics.md:76 (option+i on a selection creates a linked chat; should be option+b, since M-i is now n/i paste and unbound in v); packaging/tutorials/advanced.md:126 (option+v; should be option+i); packaging/starter-config/README.md:67 (Alt+v; should be Alt+i); workshop/parley/welcome.md:15 (Alt+v); workshop/parley/basics.md:61,72 (Option+i for branch); workshop/parley/advanced.md:63 (Option+i for branch), :139 (Option+v). ARCH-PURPOSE: no test ties tutorial key prose to the registry, so these drifted silently. Consider a cheap spec that greps the packaging/tutorials files for the paste_image/branch_ref keys.
- **BR-2** [Minor] `history-notes-rewritten` (kind: defect) History comments rewritten from M-i to M-b now misstate the past
  atlas/chat/drill_in.md:166 says the 214 bug was on M-b, a key that did not exist then. Same rewrite at lua/parley/branch_submit.lua:22, lua/parley/drill_in.lua:349, lua/parley/buffer_edit.lua:231, atlas/chat/inline_branch_links.md:54, tests/unit/branch_submit_spec.lua:508, tests/integration/branch_child_spec.lua:5. Either say "the branch key" or keep M-i with a "(now M-b, 377)" note.
- **BR-3** [Minor] `stale-test-intent` (kind: defect) keybinding_agreement_spec.lua:280 still checks M-i, which now means paste_image instead of branch
  It still passes, but the key it checks now belongs to paste_image. Add or replace it with M-b so the branch default is covered under default_keymaps=false.

## Round 2 — 2026-10-17T13:50:08-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — All listed sites fixed (packaging/tutorials basics.md:76 and advanced.md:126, starter README:67, workshop/parley welcome/basics/advanced). The new spec at keybinding_agreement_spec.lua:673 goes red when basics.md:76 is reverted to option+i (checked by mutation).
- BR-2 — addressed — All seven named sites now say "<M-i> (now <M-b>)". The one remaining stale history comment, init.lua:2472, is a separate Minor below.
- BR-3 — addressed — keybinding_agreement_spec.lua:281 now also asserts <M-b> is absent under default_keymaps=false. This is test-only, so no behavior revert applies.

### Raised

- **BR-4** [Minor] `history-notes-rewritten` (kind: defect) init.lua:2472 says <M-b> did something before M3, but <M-b> was not bound then
  This is the 2nd finding in family history-notes-rewritten. The rule: a comment that describes past behaviour (did, was, used to, before Mn, hardcoded) keeps the key that was bound at the time and adds "(now <M-b>)". Sweep check: git grep -n '<M-b>' -- lua tests atlas | grep -Ei 'did|was|used to|before|hardcod|were'. In this window that grep hits seven lines; every one except init.lua:2472 is either correct or present-tense, so init.lua:2472 is the whole remaining family.
- **BR-5** [Minor] `key-remap-doc-sweep` (kind: defect) Tutorial key spec reads only packaging docs, not README.md or workshop/parley tutorials
  This is the 2nd finding in family key-remap-doc-sweep. The rule: every file that teaches a key in prose must be in the spec's file list. All of them are correct today. Unchecked files: README.md (Alt+i at line 183), workshop/parley/welcome.md:15, workshop/parley/basics.md:61,72, and workshop/parley/advanced.md:63,139. Add them to the file list at keybinding_agreement_spec.lua:684-685.

## Round 3 — 2026-10-17T13:53:25-07:00 (claude) — passed

### Disposed

- BR-4 — addressed — init.lua:2472 now reads "`<M-i>` (now `<M-b>`) did before M3"; the sweep grep shows every past-tense hit follows the rule.
- BR-5 — addressed — The spec now globs workshop/parley/*.md and adds README.md. Mutating basics.md:61 and README.md:183 each turned the test red; the clean run passes 36/0.

## Open findings

(none — every finding has been disposed)
