---
id: 000256
status: working
deps: []
github_issue:
created: 2026-09-15
updated: 2026-10-16
estimate_hours:
card_mirror: 'bdec6d009979dcf1694cb6f7fd5b996a3c2962b4' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T02:21:24-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "1a47ce32", done: "2f4161c2"}
---

# Remove conflicting branch shortcut alias

## Problem

The default branch shortcut includes `<M-S-CR>`, which conflicts with Pair's
pane-level shortcut. Another agent prepared removal; the operator requested
committing the non-chat changes after inspection.

## Spec

Remove `<M-S-CR>` from both shipped configuration and registry fallback. Retain
`<M-i>` as primary and `<C-g>i` as the legacy alias. Update help expectations,
comments and atlas descriptions without changing branch submission behavior.

## Done when

- [x] Both default key sources contain only `<M-i>` and `<C-g>i`.
- [x] Help and documentation agree with the bindings; branch regression tests pass.

## Plan

- [x] Inspect the existing code, test and documentation changes.
- [x] Verify keybindings, pure branch submission and native child creation.
- [x] Complete the publish review when these local commits are shipped.

## Log

### 2026-09-15

Operator authorized committing existing non-chat edits. Keybindings75,
branch_submit17 and branch_child62 tests pass (154 total, zero failures/errors).
Corrected a malformed explanatory comment before committing. Chat transcripts
are excluded. The unrelated SVG prompt instruction is a separate local commit.

### 2026-10-16
- 2026-10-16: closed — Shipped as c105136c (ancestor of origin/main). Both default key sources carry only <M-i> and <C-g>i, asserted by keybindings_spec. On current main: keybindings_spec 63, branch_submit_spec 18, branch_child_spec 81 pass. No code change in this window.; review verdict: SHIP

- Taken by parley.nvim:3. The removal shipped as c105136c, an ancestor of
  origin/main. `config.lua` and the registry fallback both carry only `<M-i>`
  and `<C-g>i`, and keybindings_spec asserts the shipped list and that the help
  leads with `<M-i>`. No `<M-S-CR>` remains in lua/, atlas/, README or doc/
  except that spec's comment. On current main: keybindings_spec 63,
  branch_submit_spec 18 and branch_child_spec 81 pass. This close is the review
  of the shipped work; no code change.
