---
id: 000387
status: open
deps: []
github_issue:
created: 2026-10-18
updated: 2026-10-18
estimate_hours:
collaboration-mode: collaboration
card_mirror: '1bd8174f4a8e59867381e6559e4efe1b0d179fae' # card fields mirrored from issue-cards; edit via sdlc
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

- [ ] `highlighter.setup_highlights`:
  - a pure `blend(bg, tint, alpha)` in `lua/parley/color.lua` (new, unit-tested);
  - `ParleyEditAdd` = blend(Normal.bg, green, 0.15) and `ParleyEditChange` = blend(Normal.bg, blue, 0.15), unless a user override is set.
- [ ] `presentation.decorations`:
  - drop deletion spans;
  - replace the `deletion` flag with `kind = "add" | "change"`;
  - drop the deletion message.
- [ ] `skill_render`:
  - `publish_round` takes the group from `kind`;
  - `highlight_span` gains an optional group (default change), and define passes add;
  - `highlight_edits` takes the group from each edit's kind;
  - `attach_diagnostics` skips deletions;
  - snapshot spans carry `hl_group`.
- [ ] `skill_invoke`: the edit's kind is `delete` (empty new), `add` (empty old) or `change`.
- [ ] Specs: color blend, the groups (derived, recomputed on colorscheme, overridden), presentation kinds and no deletions, round marks, review edit kinds, deletion diagnostics gone, snapshot group.
- [ ] Atlas: ui/highlights, modes/review, modes/session_sync, chat/inline_define. README: the presentation paragraph.

## Log

