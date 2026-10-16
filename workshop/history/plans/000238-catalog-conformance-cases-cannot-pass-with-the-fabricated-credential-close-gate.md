---
gate: boundary-review
issue: 238
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: b8ea1fd2-2b77-4313-a642-fa580d3b4d7f
            repository: github.com/xianxu/parley.nvim
            issue_id: "000238"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/16d134027ea8c1c2
            reviewed_head: 1ce2a9b36d82343b3be5d654e8cc58ad6c169305
            slot: parley.nvim:4
            requested_at: "2026-10-16T13:15:28.404729Z"
          phase: finished
          pid: 78587
          started_at: "2026-10-16T13:15:28.573365Z"
          finished_at: "2026-10-16T13:16:04.233999Z"
          session_id: 419c29ba-1067-48f9-b738-9b1666950b52
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 1ce2a9b36d82343b3be5d654e8cc58ad6c169305
        tracker_head: e7cd9bec5f490814e5182d5865851659c751bde9
        branch_point: a3e476c0e5b7a7354299e7f935bbf5c940509216
        since: "2026-10-16T06:07:45-07:00"
        until: "2026-10-16T06:14:57-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T06:07:45-07:00"
              end: "2026-10-16T06:14:57-07:00"
              began: "2026-10-16T06:07:45-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: fbb807d89982c86bee492e4371360a48bcd344cf0e1dc191d84512c8ec5f960c
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 10184728
              windows:
                - start: "2026-10-16T06:07:45-07:00"
                  end: "2026-10-16T06:14:57-07:00"
      "n": 1
      timestamp: "2026-10-16T06:16:05-07:00"
      dispatched: "2026-10-16T06:15:28-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Minor
          title: The atlas says the throwaway auth-dir "stays empty", but boot() always writes a fabricated OAuth credential into it
          detail: 'atlas/providers/cliproxy-managed.md:416 says "the throwaway auth-dir stays empty", but cliproxy_conformance_spec.lua:103-112 writes claude-conformance@example.invalid.json into that auth-dir on every boot, the catalog cases included. Reword it to "the proxy writes nothing to the throwaway auth-dir and nothing real is ever in it". Same claim in this window: the issue Log bullet "the throwaway auth-dir stays EMPTY", which was measured on a scratch setup without the OAuth file.'
          family: doc-claim-unverified-against-code
          round: 1
      recipe: small-diff-review
      isolation: checkout
      reviewed: 1ce2a9b36d82343b3be5d654e8cc58ad6c169305
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 4bcc1345-96b8-4a79-828f-549f370b1331
            repository: github.com/xianxu/parley.nvim
            issue_id: "000238"
            recipe: fix-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/02b2a7ef87ded736
            reviewed_head: 2be663329e6f2984be613a815bf7b860a705022e
            slot: parley.nvim:4
            requested_at: "2026-10-16T13:16:48.214478Z"
          phase: finished
          pid: 84752
          started_at: "2026-10-16T13:16:48.418883Z"
          finished_at: "2026-10-16T13:17:14.185293Z"
          session_id: ffa63610-04d3-4385-a005-bf9d053176a5
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 2be663329e6f2984be613a815bf7b860a705022e
        tracker_head: e7cd9bec5f490814e5182d5865851659c751bde9
        branch_point: a3e476c0e5b7a7354299e7f935bbf5c940509216
        since: "2026-10-16T06:07:45-07:00"
        until: "2026-10-16T06:16:22-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T06:07:45-07:00"
              end: "2026-10-16T06:16:22-07:00"
              began: "2026-10-16T06:07:45-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 230e67977f254f94d353804eec8a29a7346bc8a16ba248f2cfff43439cd749bf
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 10209656
              windows:
                - start: "2026-10-16T06:07:45-07:00"
                  end: "2026-10-16T06:16:22-07:00"
        cuts:
            - dispatched: "2026-10-16T06:15:28-07:00"
              finalized: "2026-10-16T06:16:05-07:00"
              finalizing: true
      "n": 2
      timestamp: "2026-10-16T06:17:21-07:00"
      dispatched: "2026-10-16T06:16:48-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: atlas/providers/cliproxy-managed.md:416-417 now says the proxy writes nothing to the auth-dir and nothing real is in it. That matches spec boot() lines 99-109, which write the fabricated OAuth file, and lines 125-127, which add the API-key config. The Log gets an appended correction bullet, and a sweep found no other living claim.
          round: 2
      recipe: fix-review
      isolation: checkout
      reviewed: 2be663329e6f2984be613a815bf7b860a705022e
      blocked: false
---

# Gate ledger — parley.nvim#238 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T06:16:05-07:00 (claude) — passed

### Raised

- **BR-1** [Minor] `doc-claim-unverified-against-code` (kind: defect) The atlas says the throwaway auth-dir "stays empty", but boot() always writes a fabricated OAuth credential into it
  atlas/providers/cliproxy-managed.md:416 says "the throwaway auth-dir stays empty", but cliproxy_conformance_spec.lua:103-112 writes claude-conformance@example.invalid.json into that auth-dir on every boot, the catalog cases included. Reword it to "the proxy writes nothing to the throwaway auth-dir and nothing real is ever in it". Same claim in this window: the issue Log bullet "the throwaway auth-dir stays EMPTY", which was measured on a scratch setup without the OAuth file.

## Round 2 — 2026-10-16T06:17:21-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — atlas/providers/cliproxy-managed.md:416-417 now says the proxy writes nothing to the auth-dir and nothing real is in it. That matches spec boot() lines 99-109, which write the fabricated OAuth file, and lines 125-127, which add the API-key config. The Log gets an appended correction bullet, and a sweep found no other living claim.

## Open findings

(none — every finding has been disposed)
