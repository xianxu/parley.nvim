---
gate: boundary-review
issue: 379
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 70f12047-441f-495f-b592-b4c283e9476d
            repository: github.com/xianxu/parley.nvim
            issue_id: "000379"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/92f9b3e55b147601
            reviewed_head: 3f6ec81426a78f71a94b976be4632feb55899547
            slot: parley.nvim:4
            requested_at: "2026-10-18T04:18:53.78209Z"
          phase: finished
          pid: 53810
          started_at: "2026-10-18T04:18:53.877099Z"
          finished_at: "2026-10-18T04:22:04.964318Z"
          session_id: 24186cc3-723c-449f-ba65-b8079098cb38
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 3f6ec81426a78f71a94b976be4632feb55899547
        tracker_head: f66fa7c08ffe3d5d37e03227037d4bcecad3c63f
        branch_point: 5cbad4b335ba1609bc5c481c99d4f6d36b076fbb
        since: "2026-10-17T17:27:55-07:00"
        until: "2026-10-17T18:03:39-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T17:27:55-07:00"
              end: "2026-10-17T18:03:39-07:00"
              began: "2026-10-17T17:27:55-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 54091665499ca91405fb98abd5962df3ac97da7fc691e222e7da7b3168724999
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 39876622
              windows:
                - start: "2026-10-17T17:27:55-07:00"
                  end: "2026-10-17T18:03:39-07:00"
      "n": 1
      timestamp: "2026-10-17T21:22:13-07:00"
      dispatched: "2026-10-17T21:18:53-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Minor
          title: scripts/test-nvim.sh --supported reports supported when its Lua check errors
          detail: nvim headless exits 0 after a -c Lua error (verified rc=0), so if require or vim.version() throws, the probe passes and the compat pass runs without the minimum-version message. Fix by wrapping the check in pcall and doing cquit 1 on any error, or by printing yes/no and grepping like has_mcode_fix. The --supported probe is the only instance in this window.
          family: probe-fail-open
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: help-parley does not list the new make test-compat target
          detail: Makefile.parley:7-26 lists every other test target; TOOLING.md documents test-compat but make help does not show it.
          family: help-listing-covers-targets
          round: 1
        - kind: defect
          id: BR-3
          severity: Minor
          title: version_support_spec does not restore parley._setup_called after the setup refusal case
          detail: tests/unit/version_support_spec.lua:36 sets _setup_called to nil and never restores it. Harmless because each spec file runs in its own process.
          family: test-restores-global-state
          round: 1
      recipe: small-diff-review
      isolation: fenced
      reviewed: 3f6ec81426a78f71a94b976be4632feb55899547
      blocked: false
---

# Gate ledger — parley.nvim#379 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-17T21:22:13-07:00 (claude) — passed

### Raised

- **BR-1** [Minor] `probe-fail-open` (kind: defect) scripts/test-nvim.sh --supported reports supported when its Lua check errors
  nvim headless exits 0 after a -c Lua error (verified rc=0), so if require or vim.version() throws, the probe passes and the compat pass runs without the minimum-version message. Fix by wrapping the check in pcall and doing cquit 1 on any error, or by printing yes/no and grepping like has_mcode_fix. The --supported probe is the only instance in this window.
- **BR-2** [Minor] `help-listing-covers-targets` (kind: defect) help-parley does not list the new make test-compat target
  Makefile.parley:7-26 lists every other test target; TOOLING.md documents test-compat but make help does not show it.
- **BR-3** [Minor] `test-restores-global-state` (kind: defect) version_support_spec does not restore parley._setup_called after the setup refusal case
  tests/unit/version_support_spec.lua:36 sets _setup_called to nil and never restores it. Harmless because each spec file runs in its own process.

## Open findings

- **BR-1** [Minor] `probe-fail-open` (kind: defect) scripts/test-nvim.sh --supported reports supported when its Lua check errors
- **BR-2** [Minor] `help-listing-covers-targets` (kind: defect) help-parley does not list the new make test-compat target
- **BR-3** [Minor] `test-restores-global-state` (kind: defect) version_support_spec does not restore parley._setup_called after the setup refusal case
