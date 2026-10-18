---
id: 000387
status: codecomplete
deps: []
github_issue:
created: 2026-10-18
updated: 2026-10-18
estimate_hours:
collaboration-mode: collaboration
card_mirror: '46069bbab786345ef68165cc96cd26aed304e110' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-18T11:13:01-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "e47b51e1", done: "f377f425"}
actual_hours: 0.15
---

# Edit rendering: tint added and changed spans from Normal; deletions leave no trace

## Problem

## Spec

A follow-up to #386, from the operator's comment in ops qa/xian-xu/2026-10-18-08-collab-edit-rendering.md: an underline can't tell an added span from a changed one. The new rule:
- **Added text** gets a faint green-ish background tint, `ParleyEditAdd`.
- **Changed text** gets a faint blue-ish tint, `ParleyEditChange`.
- **A deletion leaves no trace:** no mark and no diagnostic.

Both tints are blended from the user's `Normal` background, so they stay subtle in any theme. They are recomputed on ColorScheme through `highlight_groups.keep`, and overridable with `highlight.edit_add` and `highlight.edit_change`.

A span is classified from its record: empty old text means added, anything else means changed. This covers:
- the round's spans (`old`/`new`);
- the review skill's edits (`old_string`, which the review tool always fills, so these read as changes);
- a define's term span, which inserts the `[^id]` reference without replacing anything, so it reads as added.

## Done when

- The tints are blended from `Normal`'s bg. Without a `Normal` bg, the blend falls back to black or white by `background`.
- After `:colorscheme`, the groups are recomputed from the new `Normal`.
- `highlight.edit_add` and `highlight.edit_change` override them.
- The round marks a span with empty old text as `ParleyEditAdd` and any other span as `ParleyEditChange`. A round deletion produces no extmark and no diagnostic.
- The review skill's edits mark `ParleyEditChange`. A pure deletion gets neither a highlight nor a gutter diagnostic.
- The define term span marks `ParleyEditAdd`.
- An undo/redo snapshot keeps each span's group.
- Specs cover all of this, the suite is green, and the atlas and README are updated.

## Plan

- [x] `highlighter.setup_highlights`:
  - a pure `blend(bg, tint, alpha)` in `lua/parley/color.lua` (new, unit-tested);
  - `ParleyEditAdd` = blend(Normal.bg, green, 0.15) and `ParleyEditChange` = blend(Normal.bg, blue, 0.15), unless a user override is set.
- [x] `presentation.decorations`:
  - drop deletion spans;
  - replace the `deletion` flag with `kind = "add" | "change"`;
  - drop the deletion message.
- [x] `skill_render`:
  - `publish_round` takes the group from `kind`;
  - `highlight_span` gains an optional group (default change), and define passes add;
  - `highlight_edits` takes the group from each edit's kind;
  - `attach_diagnostics` skips deletions;
  - snapshot spans carry `hl_group`.
- [x] `skill_invoke`: the edit's kind is `delete` (empty new), `add` (empty old) or `change`.
- [x] Specs: color blend, the groups (derived, recomputed on colorscheme, overridden), presentation kinds and no deletions, round marks, review edit kinds, deletion diagnostics gone, snapshot group.
- [x] Atlas: ui/highlights, modes/review, modes/session_sync, chat/inline_define. README: the presentation paragraph.

## Log


- 2026-10-18: closed — sdlc-local/suite green on 2842873c (6m19s). The first suite run on dc3788a3 failed only skill_invoke_spec, which still expected the old edit kind; fixed in 2842873c (log saved). Focused specs: color_spec (blend), presentation_spec (kind rule, deletions yield nothing, add/change), skill_render specs (round by kind, review edits add/change, deletion gets no diagnostic or highlight, snapshot keeps the kind), highlighting/define (the define term is add), and highlight_groups_spec (tints derived from Normal, re-derived on ColorScheme, fallback by background, overrides).; review verdict: SHIP
- 2026-10-18: plan posted to the hub, "proceeding unless you object" (quick flow).
- The empty-old rule has one owner, `presentation.kind(old, new)`, which the round and the review skill's edit records (skill_invoke) both use (ARCH-DRY). It returns delete, add or change.
- `highlight_span` now has one form, `(buf, lnum0, col, end_lnum0, end_col, kind)`. The four-argument same-line form had no production caller.
- Snapshot spans carry `kind`, so undo/redo keeps add and change apart.
- The tints are 15% toward 0x3fb950 for add and 0x58a6ff for change. A `'background'` change reloads the colorscheme, which fires ColorScheme, so the highlight_groups registry re-derives the tints there too. The fallback spec sets `'background'` before clearing Normal for that reason.
- Without 'termguicolors', a gui bg has no effect, so the spans show no tint. Parley's other bg groups behave the same way.
