---
id: 000119
status: working
deps: []
created: 2026-05-05
updated: 2026-05-05
---

# finder windows should preserve last selection

if user selected on thing (file for example) from a picker, then next time when we open same picker, item should be selected.

## Done when

- After confirming an item with Enter in any parley picker, the next cold-open of the same picker places the cursor on that item.
- Stale recall (item no longer in the list) falls through to the existing `initial_index` resolution; never errors out.
- Esc / cancel does NOT update the recall — only Enter does.
- All parley pickers participate (chat / note / issue / vision / markdown finders + agent / system_prompt / root_dir / note_dir / skill / test_agent / exchange / custom_prompts pickers, etc.).

## Spec

In-memory only (no disk persistence). Lives until Neovim quits.

Centralize the mechanism in `float_picker.M.open` since every picker funnels through it. Each call site opts in by passing a unique `recall_key` string. Float_picker maintains a module-level `M._last_selection` table keyed by that string and stores `item.value` on confirm.

When opening, recall is used as a fallback to `opts.initial_index`. The existing transient state (reopen-after-delete using `initial_index`/`initial_value` per-finder) keeps precedence, so this feature doesn't disturb the post-delete cursor restoration.

Stale handling: if the recalled value no longer appears in `items`, fall through to whatever `opts.initial_index` would have been (typically 1 for cold open). Free, since recall is just an additional preferred index.

## Plan

- [ ] Add `recall_key` opt and `M._last_selection` to `float_picker.lua`. Wrap `on_select` to record; fold recall into the initial-index resolution.
- [ ] Pass a `recall_key` from each picker call site (chat_finder, note_finder, issue_finder, vision_finder, markdown_finder, agent_picker, system_prompt_picker, root_dir_picker, note_dir_picker, skill_picker, test_agent_picker, exchange_clipboard, exchange_model, custom_prompts).
- [ ] Add a unit spec covering record + restore + stale fallback.
- [ ] Manual smoke: open chat finder, pick a chat, reopen, confirm cursor lands on it. Repeat for one other picker.

## Log

### 2026-05-05

Locked at status=working. Design aligned with user: in-memory, on-select only, all pickers, stale → initial_index fallback. Common mechanism via float_picker `recall_key`.

