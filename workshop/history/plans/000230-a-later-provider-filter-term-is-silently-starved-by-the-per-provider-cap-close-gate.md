---
gate: boundary-review
issue: 230
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: e1c016e3-15c6-4bab-bae5-2d13bf7c566e
            repository: github.com/xianxu/parley.nvim
            issue_id: "000230"
            recipe: milestone-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/e7d2337a8009131c
            reviewed_head: f0904b58358c78ab3cd6a809ab8c80011a96d67b
            slot: parley.nvim:3
            requested_at: "2026-10-16T02:44:20.035712Z"
          phase: finished
          pid: 20205
          started_at: "2026-10-16T02:44:20.126325Z"
          finished_at: "2026-10-16T02:53:21.626393Z"
          session_id: ca9aa192-6d03-4f42-aa2d-8b7818fa2d66
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: f0904b58358c78ab3cd6a809ab8c80011a96d67b
        tracker_head: 4ca16e5b2e02cf5006e5eb08ea5de70e88f953c8
        branch_point: 0f9b3add0e4cd33763435db02622f6dd2f9cf491
        since: "2026-10-15T19:35:17-07:00"
        until: "2026-10-15T19:43:58-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T19:35:17-07:00"
              end: "2026-10-15T19:43:58-07:00"
              began: "2026-10-15T19:35:17-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: c999d6f1830e9c2900ae4dc9af705893562cfe0ec5875b09900e9aad0507f602
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 4762743
              windows:
                - start: "2026-10-15T19:35:17-07:00"
                  end: "2026-10-15T19:43:58-07:00"
      "n": 1
      timestamp: "2026-10-15T19:53:38-07:00"
      dispatched: "2026-10-15T19:44:20-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: Shipped default "codex:gpt-6,gpt-5!3" makes diagnose warn on every catalog refresh when the catalog has no gpt-6
          detail: 'agent_picker.lua:371 diagnoses the effective providers, including the config.lua:154 default. On a catalog like tests/fixtures/cliproxy_catalog_v1.json (no gpt-6), each refresh (picker open, about every 10 min) logs a WARN ''"gpt-6" matches no codex model'' that the operator never wrote. Fix: diagnose only user-set providers, or skip "matches nothing" for default searches, or drop gpt-6 from the default; then test that the default config against the v1 fixture yields no diagnostics.'
          family: diagnostics-fire-on-shipped-defaults
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: diagnose re-implements the term-match loop instead of sharing a helper with _select
          detail: cliproxy_catalog.lua:269-276; extract a matches_any(pool, text) helper (ARCH-DRY).
          family: duplicated-match-loop
          round: 1
        - kind: defect
          id: BR-3
          severity: Minor
          title: A provider cap combined with terms (codex!2:gpt-5) is rejected, but atlas/config comments do not say so
          detail: Stricter than the Spec and reasonable; document it in atlas/providers/cliproxy-managed.md next to the malformed-count sentence.
          family: undocumented-parse-rejection
          round: 1
      recipe: milestone-review
      isolation: checkout
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 57a8f176-abed-417d-bfe3-1c62859e3183
            repository: github.com/xianxu/parley.nvim
            issue_id: "000230"
            recipe: milestone-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/b241fa65a69aef21
            reviewed_head: d9e812c83ee6fdf62194bd5083ae592f7a187f35
            slot: parley.nvim:3
            requested_at: "2026-10-16T02:56:25.191677Z"
          phase: finished
          pid: 85113
          started_at: "2026-10-16T02:56:25.420776Z"
          finished_at: "2026-10-16T03:01:01.830372Z"
          session_id: 6ba2ee10-b9e8-4d19-824b-efc0eed8e35c
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: d9e812c83ee6fdf62194bd5083ae592f7a187f35
        tracker_head: 4ca16e5b2e02cf5006e5eb08ea5de70e88f953c8
        branch_point: 0f9b3add0e4cd33763435db02622f6dd2f9cf491
        since: "2026-10-15T19:35:17-07:00"
        until: "2026-10-15T19:55:27-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T19:35:17-07:00"
              end: "2026-10-15T19:55:27-07:00"
              began: "2026-10-15T19:35:17-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 17119ff3b72e3ecd37ef4497519c3b96270685c804f343bab40d456e23db3ed2
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 4853469
              windows:
                - start: "2026-10-15T19:35:17-07:00"
                  end: "2026-10-15T19:55:27-07:00"
        cuts:
            - dispatched: "2026-10-15T19:44:20-07:00"
              finalized: "2026-10-15T19:53:38-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-15T20:01:04-07:00"
      dispatched: "2026-10-15T19:56:25-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: agent_picker.lua:25-29 _operator_specs filters verbatim defaults; reverting to diagnose(models, configured) turns picker_items_spec "diagnoses only what the operator wrote" red (56/1), restored green (57/0).
          round: 2
        - id: BR-2
          disposition: addressed
          note: cliproxy_catalog.lua:269-271 diagnose now calls M._select with a cap-1 single search; the private match loop is gone.
          round: 2
        - id: BR-3
          disposition: addressed
          note: atlas/providers/cliproxy-managed.md:166-167 and config.lua:147-148 now state a provider cap beside terms is rejected; matches parse_provider_spec line 152 and the codex!2:gpt-5 rejection test.
          round: 2
      findings:
        - kind: defect
          id: BR-4
          severity: Minor
          title: _operator_specs was inserted between _providers_without_models and its doc annotations
          detail: agent_picker.lua:16-18 param/return annotations for _providers_without_models now precede the _operator_specs block, so LuaLS attaches them to the wrong function. Move the new block above line 16.
          family: misplaced-doc-annotation
          round: 2
      recipe: milestone-review
      isolation: checkout
      reviewed: d9e812c83ee6fdf62194bd5083ae592f7a187f35
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 245bf454-75f2-46e6-aa91-2103420cd7c8
            repository: github.com/xianxu/parley.nvim
            issue_id: "000230"
            recipe: fix-review
            round: 3
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/eaa73ef30bf6e57d
            reviewed_head: 3646bebb2a5bfe06aed4447122e08f41e137c92b
            slot: parley.nvim:3
            requested_at: "2026-10-16T03:21:49.812498Z"
          phase: finished
          pid: 38149
          started_at: "2026-10-16T03:21:49.977193Z"
          finished_at: "2026-10-16T03:22:39.073003Z"
          session_id: 924a5f7b-22ca-4c15-9a0b-82eac31f6211
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 3646bebb2a5bfe06aed4447122e08f41e137c92b
        tracker_head: edd8da6a1dbbbfa5a1888da4abc373a83b642446
        branch_point: 0f9b3add0e4cd33763435db02622f6dd2f9cf491
        since: "2026-10-15T19:35:17-07:00"
        until: "2026-10-15T20:20:38-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T19:35:17-07:00"
              end: "2026-10-15T20:20:38-07:00"
              began: "2026-10-15T19:35:17-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 45f1272a111fbd251f5231d5aa11d8959e33096c7089f9f8ac7a383467ec5c95
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 5098953
              windows:
                - start: "2026-10-15T19:35:17-07:00"
                  end: "2026-10-15T20:20:38-07:00"
        cuts:
            - dispatched: "2026-10-15T19:44:20-07:00"
              finalized: "2026-10-15T19:53:38-07:00"
              finalizing: false
            - dispatched: "2026-10-15T19:56:25-07:00"
              finalized: "2026-10-15T20:01:04-07:00"
              finalizing: true
      "n": 3
      timestamp: "2026-10-15T20:22:39-07:00"
      dispatched: "2026-10-15T20:21:49-07:00"
      agent: claude
      dispose:
        - id: BR-4
          disposition: addressed
          note: 'agent_picker.lua:8-30 _operator_specs now sits above the _providers_without_models doc block. The class is enforced tree-wide by tests/arch/superseded_comment_spec: red with the base file (8/1, agent_picker.lua:8 @param models vs (providers)), green at head (9/0).'
          round: 3
      recipe: fix-review
      isolation: checkout
      reviewed: 3646bebb2a5bfe06aed4447122e08f41e137c92b
      blocked: false
---

# Gate ledger — parley.nvim#230 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-15T19:53:38-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `diagnostics-fire-on-shipped-defaults` (kind: defect) Shipped default "codex:gpt-6,gpt-5!3" makes diagnose warn on every catalog refresh when the catalog has no gpt-6
  agent_picker.lua:371 diagnoses the effective providers, including the config.lua:154 default. On a catalog like tests/fixtures/cliproxy_catalog_v1.json (no gpt-6), each refresh (picker open, about every 10 min) logs a WARN '"gpt-6" matches no codex model' that the operator never wrote. Fix: diagnose only user-set providers, or skip "matches nothing" for default searches, or drop gpt-6 from the default; then test that the default config against the v1 fixture yields no diagnostics.
- **BR-2** [Minor] `duplicated-match-loop` (kind: defect) diagnose re-implements the term-match loop instead of sharing a helper with _select
  cliproxy_catalog.lua:269-276; extract a matches_any(pool, text) helper (ARCH-DRY).
- **BR-3** [Minor] `undocumented-parse-rejection` (kind: defect) A provider cap combined with terms (codex!2:gpt-5) is rejected, but atlas/config comments do not say so
  Stricter than the Spec and reasonable; document it in atlas/providers/cliproxy-managed.md next to the malformed-count sentence.

## Round 2 — 2026-10-15T20:01:04-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — agent_picker.lua:25-29 _operator_specs filters verbatim defaults; reverting to diagnose(models, configured) turns picker_items_spec "diagnoses only what the operator wrote" red (56/1), restored green (57/0).
- BR-2 — addressed — cliproxy_catalog.lua:269-271 diagnose now calls M._select with a cap-1 single search; the private match loop is gone.
- BR-3 — addressed — atlas/providers/cliproxy-managed.md:166-167 and config.lua:147-148 now state a provider cap beside terms is rejected; matches parse_provider_spec line 152 and the codex!2:gpt-5 rejection test.

### Raised

- **BR-4** [Minor] `misplaced-doc-annotation` (kind: defect) _operator_specs was inserted between _providers_without_models and its doc annotations
  agent_picker.lua:16-18 param/return annotations for _providers_without_models now precede the _operator_specs block, so LuaLS attaches them to the wrong function. Move the new block above line 16.

## Round 3 — 2026-10-15T20:22:39-07:00 (claude) — passed

### Disposed

- BR-4 — addressed — agent_picker.lua:8-30 _operator_specs now sits above the _providers_without_models doc block. The class is enforced tree-wide by tests/arch/superseded_comment_spec: red with the base file (8/1, agent_picker.lua:8 @param models vs (providers)), green at head (9/0).

## Open findings

(none — every finding has been disposed)
