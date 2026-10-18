---
id: 000386
status: open
deps: []
github_issue:
created: 2026-10-18
updated: 2026-10-18
estimate_hours:
collaboration-mode: collaboration
card_mirror: '21c33fdb1dd14848e7ef4e0ffc3a209b63a83d54' # card fields mirrored from issue-cards; edit via sdlc
---

# Edit rendering: subtle changed-span highlight; show full 🤖 marker text and links

## Problem

## Spec

Operator item 7 (ops tl-status-xian-xu, answer at qa/xian-xu/2026-10-18-08-collab-edit-rendering.md). A collaborative edit renders badly in two ways:

1. **Edited regions shout.** `skill_render.lua` paints every touched line from column 0 to the end with `DiffChange`. In the operator's theme that is a light-gray background, so the unchanged words get the loudest color on screen. Wanted: only the changed span is marked, with one subtle, dedicated, overridable group. Unchanged text keeps its normal color. A deletion keeps its small marker. This applies to the review skill's decorations and to #383's round (`ParleyAgentChange`, today linked to `DiffAdd`).
2. **Concealing confuses.** parley's #312 compact view (`comment/view.lua`'s `layout`, painted by `highlighter.lua`) hides each 🤖 turn's text behind `…`. Neovim can't shrink the line the text sat on, so a long hidden turn leaves near-empty lines holding a lone bracket. Markdown links are concealed down to their anchor text. Wanted: the full text of a 🤖[...] / 🤖{...} turn, and links shown in full. Turn off only what parley controls in its own buffers.

Findings from the code:
- **Marker conceal is parley's own:** the `m.hidden` ranges in `view.layout`, the cursor snap (`view.snap`) and `concealcursor` forcing in `comment/init.lua`.
- **Link conceal is treesitter's markdown_inline query**, active because `conceallevel` is 2. Two things set it to 2: parley sets it buffer-locally (`comment.attach`, for both chat and markdown buffers), and LazyVim sets it globally (the operator runs stock LazyVim, no extras). So removing parley's setter alone doesn't show links: parley has to set `conceallevel = 0` in the buffers it owns.
- **Other parley conceals in chat buffers:** inline branch links `[🌿:topic](path)` (highlighter.lua) and model-header params (`chat_conceal_model_params`, default true) both need conceallevel > 0.
- **Neovim 0.11.7:** `nvim_buf_add_highlight` is deprecated, so this uses extmarks. `ParleyAgentChange` is set once, at namespace creation, so a `:colorscheme` clears it. The new group belongs with highlighter.lua's other group definitions.

## Done when

- The review skill's edit highlights (`highlight_edits`, `highlight_span`, `apply_snapshot`) and #383's round mark only the changed spans, with one group, `ParleyEditChange` (`default = true`, so the operator can override it). No whole-line `DiffChange` remains in skill_render.lua. A pure deletion still shows only its marker or diagnostic.
- The group survives `:colorscheme`.
- A 🤖 marker's turns render in full: `view.layout` emits no hidden ranges. The turn colors stay, and the brackets are still re-asserted against treesitter's shortcut-link conceal. The cursor snap and `concealcursor` forcing are removed, since nothing is hidden for them to guard.
- Markdown links show in full in parley's markdown buffers. Chat buffers per the decision in the Plan.
- Specs cover all of this, nvim-cmp insert-mode typing on a marker line still works, and the suite is green.

## Plan

Recommendation, needs the hub's call (Q1, Q2):

- **Q1, the default look of `ParleyEditChange`.** Recommended: `{ underline = true, default = true }`. It changes neither text color nor background, it reads in light and dark themes, and it doesn't collide with `CursorLine`. A link to a quiet group was considered: `CursorLine` hides edits on the cursor's line, and the `Diff*` groups are the loud backgrounds being removed. Overridable either way.
- **Q2, links in chat buffers.** Recommended: markdown buffers get `conceallevel = 0`, so links, markers and everything else show literally. Chat buffers keep 2, because branch links and model params are parley's own compact view there, so markdown links in chat stay concealed. The alternative, 0 in chat too, shows `[🌿:topic](path)` and the model params raw.

Steps:
- [ ] Add `ParleyEditChange` to highlighter.lua's group setup, with the Q1 default.
- [ ] skill_render.lua:
  - `highlight_edits` marks the byte span of `new_string` (row and col from its offset) as one extmark.
  - `highlight_span` and the round's spans use `ParleyEditChange`.
  - Delete `highlight_line`, which has no callers.
  - Drop `apply_snapshot`'s whole-line `hl_lines` path. Projection records live in memory, so no old snapshot needs it.
  - Footnote spans (define) move to the same group.
  - Retire `ParleyAgentChange` (landed today, no other users).
- [ ] comment/view.lua: `lay_chain` and the quoted-anchor branch emit no `hidden`, and `snap` and `blocked_spans` go. comment/init.lua: drop the snap and `concealcursor` forcing. `<CR>` to open a thread stays. Update the module headers.
- [ ] conceallevel per Q2: `comment.attach` takes the buffer kind. Markdown buffers get 0, chat buffers 2.
- [ ] Tests:
  - Update comment_view_spec, comment_attach_spec, comment_render_spec and skill_render_spec, including span assertions that no whole-line mark is left.
  - Add a spec that the group survives `:colorscheme`.
  - Add a spec that the round renders with `ParleyEditChange`.
  - Typing in insert mode on a marker line, through the existing harness.
- [ ] Atlas: the review and comment-marker sections and session_sync's round section. README notes the group.
- [ ] Not in scope: the one-level marker rule, which is ariadne's (after ariadne#437); `ParleyCommentUser`'s float background (a float, not the document); treesitter queries (global, not parley's).

## Log

