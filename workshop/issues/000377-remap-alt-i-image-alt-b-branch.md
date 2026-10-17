---
id: 000377
status: working
deps: []
github_issue:
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'dc5e2422c8f8e56ad7e8ecf988f64636ec15348a' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-17T12:11:42-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "787ab1ab", done: "650e0e1d"}
---

# Remap keys: Alt+i pastes an image (matching pair draft), Alt+b creates a sub-chat

## Problem

Pair's draft nvim puts "attach an image" on Alt+i. In parley, Alt+i creates a sub-chat (branch_ref), and image paste sits on Alt+v. The operator wants one image key across both editors, and wants sub-chat creation moved to Alt+b.

## Spec

- paste_image: `<M-i>` (n, i, parley buffers). `<M-v>` is dropped and left unbound. The TL approved this; adding it back is a one-line change.
- branch_ref: `<M-b>` plus the legacy `<C-g>i` alias (n, i, v, parley buffers).
- Conflict check, done before the change and reported to the hub:
  - Inside parley, `<M-b>` was unbound in every mode and buffer type.
  - Pair's own zellij config binds neither key.
  - Couch's chords and pair's global chords are clear of both. Couch's Ctrl+Alt+b is a different chord.
  - Pair's draft nvim, which never loads parley, uses Alt+b for scrollback.
- A user who sets `chat_shortcut_*` explicitly keeps their own keys.

## Done when

- The shipped defaults resolve paste_image to `{ "<M-i>" }` and branch_ref to `{ "<M-b>", "<C-g>i" }`.
- `<M-v>` is not bound by default.
- Help, README and atlas name the new keys.
- The specs that pin these keys are updated, and the suite passes.

## Plan

- [x] config.lua + registry defaults: paste_image <M-i>, branch_ref <M-b> + <C-g>i; <M-v> unbound
- [x] Comments, specs (keybindings, agreement, paste_image incl. <M-v> unbound, starter config + probe), README, atlas

## Log

### 2026-10-17

- Conflict check, run before any change and reported to the hub. The TL approved `<M-v>` being dropped.
  - parley: `<M-b>` was unbound in every mode and buffer type, and `<C-g>b` (prune) is a separate chord.
  - pair's draft nvim: it uses `<M-i>` to attach an image and `<M-b>` for scrollback. It never loads parley.
  - pair's zellij config (clear-defaults) binds neither key.
  - Couch's chords, including Ctrl+Alt+b broadcast, and pair's global chords are clear.
  - The operator's personal `~/.config/zellij/config.kdl` binds Alt i to MoveTab outside pair. The hub has been told; parley does not own that config.
- Swept every `<M-i>` that meant branch in lua/, tests/ and atlas/, changing each to `<M-b>`. The M1-migration history notes were left as they are.
- Targeted specs pass: keybindings 81, starter_config 7, paste_image 23 (it now also asserts `<M-v>` is unbound in n and i), keybinding_agreement 35, branch_submit 18, branch_child 63, config_tools 26.
- Close review round 1: FIX-THEN-SHIP.
  - BR-1 (Important): the shipped tutorials and the starter README still taught the old keys (`option+i` to branch, `option+v`/Alt+v to paste). My sweep missed them because it looked for `<M-…>`/`Alt+` only, and `git grep -E` has no `\b`. Re-swept with PCRE for every spelling (option/alt/⌥, any case). Fixed `packaging/tutorials/{basics,advanced}.md`, `packaging/starter-config/README.md` and `workshop/parley/{welcome,basics,advanced}.md`.
  - Added a spec in `keybinding_agreement_spec`, resolved under the starter options because the tutorials ship with the app. Every Alt/Option letter the tutorials name must be bound. When the text after a key says "attach" or "linked chat", the key must be paste_image's or branch_ref's. Mutation checks: restoring `option+i` (branch) in basics, Alt+v in the starter README, or `option+v` in advanced each fails it by name.
  - BR-2 (Minor): the rewrites that state history now keep `<M-i>` with "(now `<M-b>`)": drill_in.lua, buffer_edit.lua, branch_submit.lua, inline_branch_links.md, drill_in.md, branch_child_spec, branch_submit_spec.
  - BR-3 (Minor): the default_keymaps=false case now also asserts that `<M-b>` is absent.
