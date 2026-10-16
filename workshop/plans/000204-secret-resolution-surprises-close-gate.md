---
gate: boundary-review
issue: 204
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 8abbacc5-0c7c-484a-9eb0-8530933c2e87
            repository: github.com/xianxu/parley.nvim
            issue_id: "000204"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/af3ba2b83126c07d
            reviewed_head: d76992f3d584e5b79b11ecf15057c4cc7eefaa00
            slot: parley.nvim:4
            requested_at: "2026-10-16T01:28:27.687286Z"
          phase: finished
          pid: 98388
          started_at: "2026-10-16T01:28:27.783648Z"
          finished_at: "2026-10-16T01:30:39.413748Z"
          session_id: 01a220eb-7af7-4abc-9b4d-3e7cd6eb3da5
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: d76992f3d584e5b79b11ecf15057c4cc7eefaa00
        tracker_head: 16b5bc00e4d2b91b82830a72f16c7ca9c4736d0a
        branch_point: be26f430498624ce9064b693ddc56f4ead113097
        since: "2026-10-15T17:50:06-07:00"
        until: "2026-10-15T18:28:06-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T17:50:06-07:00"
              end: "2026-10-15T18:28:06-07:00"
              began: "2026-10-15T17:50:06-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: ed13852b14f54b22afa822714c8e3915b432522212add7b1f2f4df46efef9fd5
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 1370270
              windows:
                - start: "2026-10-15T17:50:06-07:00"
                  end: "2026-10-15T18:28:06-07:00"
      "n": 1
      timestamp: "2026-10-15T18:30:39-07:00"
      dispatched: "2026-10-15T18:28:27-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Minor
          title: 'vault.setup reset does not cover state derived from secrets: copilot bearer cache and in-flight resolvers'
          detail: 'Instances in window: (a) V._state.copilot_bearer and the on-disk vault_state.json survive vault.setup, so a re-run setup with a new copilot key keeps the old bearer until it expires, which contradicts atlas/infra/vault.md saying re-sourcing "takes effect on the next request". (b) a resolve_secret command still running across a setup re-run writes secrets[name]=content into the new table and overwrites the new value. Fix: clear _state in setup (or key the bearer to its source secret), and have the resolver callback check a setup generation counter before writing.'
          family: setup-reset-leaves-derived-secret-state
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: The lifecycle 401 assertion matches both the ours=false and could-not-tell messages, so the port_identity wiring is unpinned
          detail: tests/integration/cliproxy_lifecycle_spec.lua:342 checks only for api_keys.cliproxyapi, which appears in both non-ours branches of mismatch_message. The test would still pass if ensure_running passed a constant identity. No integration test reaches the ours=true stale-proxy message. Assert the branch-specific text, or make the identity read injectable.
          family: wiring-assertion-not-discriminating
          round: 1
        - kind: defect
          id: BR-3
          severity: Minor
          title: 'ARCH-DRY: the cmd_prefix lookup is repeated three times in cliproxy.lua (782, 1136, 1455) plus agent_picker.lua:213'
          detail: (require("parley").config or {}).cmd_prefix or "Parley" is copy-pasted. Pull it into one local helper.
          family: arch-dry-cmd-prefix-lookup
          round: 1
      recipe: small-diff-review
      isolation: checkout
      reviewed: d76992f3d584e5b79b11ecf15057c4cc7eefaa00
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: b7837796-c11b-4be0-a5b1-38e57a526f2d
            repository: github.com/xianxu/parley.nvim
            issue_id: "000204"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/007c661a4c679597
            reviewed_head: cb9bbbb3d181b448faa66b652aae6c56272ff70f
            slot: parley.nvim:4
            requested_at: "2026-10-16T03:37:12.642235Z"
          phase: finished
          pid: 35792
          started_at: "2026-10-16T03:37:12.821846Z"
          finished_at: "2026-10-16T03:39:39.438116Z"
          session_id: b6989cdb-588e-4847-bf99-8000e8de873b
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: cb9bbbb3d181b448faa66b652aae6c56272ff70f
        tracker_head: 5d5f36ed52abdad192d03ccdeef5b0710e037e9f
        branch_point: 3d0c2369d1e25b61819b3554cdf1fd7950e7823f
        since: "2026-10-15T17:50:06-07:00"
        until: "2026-10-15T20:29:36-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T17:50:06-07:00"
              end: "2026-10-15T20:29:36-07:00"
              began: "2026-10-15T17:50:06-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 0c236ec2dd1c43b5ef0cc2fcae0086e4a1004bbd2b14b1efb9c07a8cc119d3cf
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 1867020
              windows:
                - start: "2026-10-15T17:50:06-07:00"
                  end: "2026-10-15T20:29:36-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 0.0299
        cuts:
            - dispatched: "2026-10-15T18:28:27-07:00"
              finalized: "2026-10-15T18:30:39-07:00"
              finalizing: true
      "n": 2
      timestamp: "2026-10-15T20:39:41-07:00"
      dispatched: "2026-10-15T20:37:12-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: vault.setup clears _state and bumps generation (vault.lua:40-44); fences at vault.lua:138 and 248; bearer keyed by sha256 at 217/269. Removing the fences or source check fails F3, V3/V4.
          round: 2
        - id: BR-2
          disposition: addressed
          note: Lifecycle 401 split into ours/foreign/unknown via fake_ps with branch-specific asserts; a constant identity at cliproxy.lua:787 fails 2 cases (verified by mutation).
          round: 2
        - id: BR-3
          disposition: addressed
          note: cmd_prefix() helper at cliproxy.lua:61 now used at 787, 1140, 1459; agent_picker reads an injected plugin.config in another module, acceptable.
          round: 2
      findings:
        - kind: defect
          id: BR-4
          severity: Minor
          title: Forward declaration of port_identity splits ensure_running's doc block from the function
          detail: 'cliproxy.lua:749-754: the triple-dash doc and param annotations now attach to local port_identity, not M.ensure_running. Move the declaration above the doc block. Only instance in the window; the vault.lua insertions do not detach any doc comment.'
          family: hoist-detaches-doc-comment
          round: 2
      recipe: small-diff-review
      isolation: checkout
      reviewed: cb9bbbb3d181b448faa66b652aae6c56272ff70f
      blocked: false
---

# Gate ledger — parley.nvim#204 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-15T18:30:39-07:00 (claude) — passed

### Raised

- **BR-1** [Minor] `setup-reset-leaves-derived-secret-state` (kind: defect) vault.setup reset does not cover state derived from secrets: copilot bearer cache and in-flight resolvers
  Instances in window: (a) V._state.copilot_bearer and the on-disk vault_state.json survive vault.setup, so a re-run setup with a new copilot key keeps the old bearer until it expires, which contradicts atlas/infra/vault.md saying re-sourcing "takes effect on the next request". (b) a resolve_secret command still running across a setup re-run writes secrets[name]=content into the new table and overwrites the new value. Fix: clear _state in setup (or key the bearer to its source secret), and have the resolver callback check a setup generation counter before writing.
- **BR-2** [Minor] `wiring-assertion-not-discriminating` (kind: defect) The lifecycle 401 assertion matches both the ours=false and could-not-tell messages, so the port_identity wiring is unpinned
  tests/integration/cliproxy_lifecycle_spec.lua:342 checks only for api_keys.cliproxyapi, which appears in both non-ours branches of mismatch_message. The test would still pass if ensure_running passed a constant identity. No integration test reaches the ours=true stale-proxy message. Assert the branch-specific text, or make the identity read injectable.
- **BR-3** [Minor] `arch-dry-cmd-prefix-lookup` (kind: defect) ARCH-DRY: the cmd_prefix lookup is repeated three times in cliproxy.lua (782, 1136, 1455) plus agent_picker.lua:213
  (require("parley").config or {}).cmd_prefix or "Parley" is copy-pasted. Pull it into one local helper.

## Round 2 — 2026-10-15T20:39:41-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — vault.setup clears _state and bumps generation (vault.lua:40-44); fences at vault.lua:138 and 248; bearer keyed by sha256 at 217/269. Removing the fences or source check fails F3, V3/V4.
- BR-2 — addressed — Lifecycle 401 split into ours/foreign/unknown via fake_ps with branch-specific asserts; a constant identity at cliproxy.lua:787 fails 2 cases (verified by mutation).
- BR-3 — addressed — cmd_prefix() helper at cliproxy.lua:61 now used at 787, 1140, 1459; agent_picker reads an injected plugin.config in another module, acceptable.

### Raised

- **BR-4** [Minor] `hoist-detaches-doc-comment` (kind: defect) Forward declaration of port_identity splits ensure_running's doc block from the function
  cliproxy.lua:749-754: the triple-dash doc and param annotations now attach to local port_identity, not M.ensure_running. Move the declaration above the doc block. Only instance in the window; the vault.lua insertions do not detach any doc comment.

## Open findings

- **BR-4** [Minor] `hoist-detaches-doc-comment` (kind: defect) Forward declaration of port_identity splits ensure_running's doc block from the function
