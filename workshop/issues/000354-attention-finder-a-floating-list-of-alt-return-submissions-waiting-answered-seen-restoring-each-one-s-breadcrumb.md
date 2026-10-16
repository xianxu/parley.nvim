---
id: 000354
status: working
deps: [parley.nvim#332, parley.nvim#353]
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours: 3.39
card_mirror: 'ceeda60e4f61f8f9c829179583ea002befe00762' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T11:20:37-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: full, provenance: inferred}
---

# Attention finder: a floating list of Alt+Return submissions (waiting / answered / seen), restoring each one's breadcrumb

## Problem

The operator uses Alt+o and Alt+Return as an attention pipeline: read, comment, submit, move on. Nothing brings them
back when the agent answers a submitted file. Operator design, 2026-10-16 (ops QA
`teams/devinfra/qa/xian-xu/2026-10-16-03-breadcrumb-winbar.md`). Part of ops project universal-agent-input-interface.

## Spec

- **An attention finder:** a floating window (the chat finder's typeahead) listing every file submitted with
  Alt+Return, newest first.
- **Row state from the authorities, not mtimes:** Couch's ledger (a submit's owed event folded means the agent
  answered) and #332's submit receipt (content hash at submit). States: **waiting**, **answered** (highlighted), and
  **seen** (opened after the answer). Opening a row marks it seen.
- **Each entry stores the breadcrumb** (the per-file trail from the breadcrumb issue) at submit time; jumping from the
  finder restores that trail, so the tree stays intact.
- **One free Alt chord** opens it in Couch's nvim; the session file's winbar may show a count of answered-but-unseen.

## Done when

- Tests: entries appear on submit; state transitions (waiting, answered via a fold, seen on open); breadcrumb
  restored on jump; typeahead; then the operator's live check.

## Estimate

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against `baseline-v3.1.md` (the source reads stale, so the hours are provisional). Method A only.*

- `issue-spec`: planning since the claim (the research into Couch's owed IDs, the durable plan, the #353 seam with parley.nvim:2, and two plan-quality rounds) is mostly spent already, so design is at the middle of the range.
- `lua-neovim` ×2, M1 (the model, the store with its lease, the record hook) and M2 (rows, refresh, open, the chord): design ×0.2, because the plan settles the schemas, events and seams. Impl is the middle of the range at 40%.
- `milestone-review` ×2 and `atlas-docs`: impl at 40% of the middle of the range.
- Familiar territory (`float_picker`, `couch.query`, `document_lease` and the fake Couch all exist): ×1.0. Design buffer +15%, for a thorough plan doc.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec        design=1.0 impl=0.08
item: lua-neovim        design=0.4 impl=0.4
item: lua-neovim        design=0.4 impl=0.4
item: milestone-review  design=0.0 impl=0.14
item: milestone-review  design=0.0 impl=0.14
item: atlas-docs        design=0.1 impl=0.04
design-buffer: 0.15
total: 3.39
```

## Plan

The durable plan is `workshop/plans/000354-attention-finder-plan.md` (milestones M1 and M2). Operator addition (TL, 2026-10-16), folded into the plan's model: a seen entry leaves after `attention.seen_grace_minutes` (default 60, pending the operator's 1 h vs 15 min); a new submit resets it to waiting; answered entries never opened don't expire.

- [ ] M1 — the model, store and submit recording
- [ ] M2 — the finder (rows, refresh, open, chord, docs)

## Log

### 2026-10-16
