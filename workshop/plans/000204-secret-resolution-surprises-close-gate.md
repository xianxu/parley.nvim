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

## Open findings

- **BR-1** [Minor] `setup-reset-leaves-derived-secret-state` (kind: defect) vault.setup reset does not cover state derived from secrets: copilot bearer cache and in-flight resolvers
- **BR-2** [Minor] `wiring-assertion-not-discriminating` (kind: defect) The lifecycle 401 assertion matches both the ours=false and could-not-tell messages, so the port_identity wiring is unpinned
- **BR-3** [Minor] `arch-dry-cmd-prefix-lookup` (kind: defect) ARCH-DRY: the cmd_prefix lookup is repeated three times in cliproxy.lua (782, 1136, 1455) plus agent_picker.lua:213
