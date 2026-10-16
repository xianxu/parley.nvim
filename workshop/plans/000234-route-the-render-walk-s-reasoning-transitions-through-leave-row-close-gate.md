---
gate: boundary-review
issue: 234
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 07d3876f-539e-4e4a-9aa7-9a4aa2df7953
            repository: github.com/xianxu/parley.nvim
            issue_id: "000234"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/b2ac595aaeb33600
            reviewed_head: 0d857ce217bc60e8aec96af3e47191bcb8f5de8a
            slot: parley.nvim:4
            requested_at: "2026-10-16T13:41:17.15869Z"
          phase: finished
          pid: 77885
          started_at: "2026-10-16T13:41:17.505958Z"
          finished_at: "2026-10-16T13:44:42.105039Z"
          session_id: 5264aaae-3960-4232-9000-6bba0165ab12
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 0d857ce217bc60e8aec96af3e47191bcb8f5de8a
        tracker_head: 7ef8c9bd1d49003ba3f034dee613500d75884a7a
        branch_point: 4dec7d7dfb20ce53a8de297683a461a28f06adc8
        since: "2026-10-16T06:21:11-07:00"
        until: "2026-10-16T06:31:44-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T06:21:11-07:00"
              end: "2026-10-16T06:31:44-07:00"
              began: "2026-10-16T06:21:11-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 1f9fc910d7541551955f33d46c98cba2aa46960ef6850b2b3f5a8db8ffe5cb49
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 10925154
              windows:
                - start: "2026-10-16T06:21:11-07:00"
                  end: "2026-10-16T06:31:44-07:00"
      "n": 1
      timestamp: "2026-10-16T06:44:42-07:00"
      dispatched: "2026-10-16T06:41:17-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: document/grammar.lua:139-145 still hand-writes enter_row/leave_row for the production render_before path
          detail: 'The Spec required sweeping for other copies of the reasoning rules. grammar.lua restates the footer reset, reset_partition, advance, and the END/reasoning/blank transitions line for line, and its render_before feeds the document_rows path that compute_window_decorations uses for live buffers. Mutation: dropping reasoning_explicit_end=false from grammar''s END branch (the exact drift #234 names) leaves the render_walk_parity, highlighter_document, highlighting and highlight_typing specs green. Fix: call the shared halves, moving them into parley.document.lexical or giving enter_row an in_footer boolean, and add a parity property test of grammar render_before against build().state_before. Family: highlighter walk (fixed), derive (source), grammar.lua (open), chat_parser (documented as different).'
          family: shared-row-step-single-source
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: highlighter.lua:290 blank-row paint condition restates leave_row's blank terminator rule
          detail: line:match("^%s*$") and not in_reasoning_explicit_end duplicates leave_row's blank-token rule using line text. It could use classified.token == blank, or the state before and after leave_row.
          family: shared-row-step-single-source
          round: 1
        - kind: defect
          id: BR-3
          severity: Minor
          title: Parity test covers only the fingerprint-structure path with streaming off
          detail: render_walk_parity_spec passes a build() structure, so the document_rows production path and the streaming overlay at highlighter.lua:202-204 are never compared against state_before.
          family: render-parity-coverage-scope
          round: 1
        - kind: defect
          id: BR-4
          severity: Minor
          title: vim.deepcopy per rendered row where lexical.copy_state exists
          detail: highlighter.lua:213 deep-copies the state on every rendered row in the redraw path. The shared lexical.copy_state is the existing helper for this.
          family: hot-path-copy-helper
          round: 1
        - kind: defect
          id: BR-5
          severity: Minor
          title: render_walk_parity_spec mapped under chat/lifecycle rather than ui/highlights
          detail: atlas/ui/highlights.md documents the test, but make test-spec SPEC=ui/highlights does not run it.
          family: traceability-mapping-placement
          round: 1
      recipe: small-diff-review
      isolation: checkout
      blocked: true
---

# Gate ledger — parley.nvim#234 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T06:44:42-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `shared-row-step-single-source` (kind: defect) document/grammar.lua:139-145 still hand-writes enter_row/leave_row for the production render_before path
  The Spec required sweeping for other copies of the reasoning rules. grammar.lua restates the footer reset, reset_partition, advance, and the END/reasoning/blank transitions line for line, and its render_before feeds the document_rows path that compute_window_decorations uses for live buffers. Mutation: dropping reasoning_explicit_end=false from grammar's END branch (the exact drift #234 names) leaves the render_walk_parity, highlighter_document, highlighting and highlight_typing specs green. Fix: call the shared halves, moving them into parley.document.lexical or giving enter_row an in_footer boolean, and add a parity property test of grammar render_before against build().state_before. Family: highlighter walk (fixed), derive (source), grammar.lua (open), chat_parser (documented as different).
- **BR-2** [Minor] `shared-row-step-single-source` (kind: defect) highlighter.lua:290 blank-row paint condition restates leave_row's blank terminator rule
  line:match("^%s*$") and not in_reasoning_explicit_end duplicates leave_row's blank-token rule using line text. It could use classified.token == blank, or the state before and after leave_row.
- **BR-3** [Minor] `render-parity-coverage-scope` (kind: defect) Parity test covers only the fingerprint-structure path with streaming off
  render_walk_parity_spec passes a build() structure, so the document_rows production path and the streaming overlay at highlighter.lua:202-204 are never compared against state_before.
- **BR-4** [Minor] `hot-path-copy-helper` (kind: defect) vim.deepcopy per rendered row where lexical.copy_state exists
  highlighter.lua:213 deep-copies the state on every rendered row in the redraw path. The shared lexical.copy_state is the existing helper for this.
- **BR-5** [Minor] `traceability-mapping-placement` (kind: defect) render_walk_parity_spec mapped under chat/lifecycle rather than ui/highlights
  atlas/ui/highlights.md documents the test, but make test-spec SPEC=ui/highlights does not run it.

## Open findings

- **BR-1** [Important] `shared-row-step-single-source` (kind: defect) document/grammar.lua:139-145 still hand-writes enter_row/leave_row for the production render_before path
- **BR-2** [Minor] `shared-row-step-single-source` (kind: defect) highlighter.lua:290 blank-row paint condition restates leave_row's blank terminator rule
- **BR-3** [Minor] `render-parity-coverage-scope` (kind: defect) Parity test covers only the fingerprint-structure path with streaming off
- **BR-4** [Minor] `hot-path-copy-helper` (kind: defect) vim.deepcopy per rendered row where lexical.copy_state exists
- **BR-5** [Minor] `traceability-mapping-placement` (kind: defect) render_walk_parity_spec mapped under chat/lifecycle rather than ui/highlights
