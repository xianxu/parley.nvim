---
id: 000119
status: done
deps: []
created: 2026-05-05
updated: 2026-05-06
actual_hours: 1.5
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

- [x] Add `recall_key` opt and `M._last_selection` to `float_picker.lua`. Wrap `on_select` to record; fold recall into the initial-index resolution.
- [x] Add `recall_id_fn` opt for pickers whose stable identity isn't on `item.value` (agent, root_dir, note template).
- [x] Pass a `recall_key` from each picker call site that has well-defined "selection" semantics: chat_finder, note_finder, issue_finder, vision_finder, markdown_finder, agent_picker, system_prompt_picker, root_dir_picker (per-domain key), skill_picker (top-level + per skill+arg), notes.lua "Select Template", init.lua "Move Chat To".
- [x] Skip pickers where recall doesn't fit semantics: outline (per-buffer line jump, not "same item across reopens"); test_agent_picker (test fixture, not a real picker); exchange_clipboard / exchange_model / custom_prompts (use Vim native UI, not float_picker).
- [x] Add unit specs covering record + restore + stale fallback + initial_index precedence + recall_id_fn + cancel-no-update (`tests/unit/float_picker_spec.lua`).
- [x] Update `atlas/ui/pickers.md` with the Recall section.
- [x] Manual smoke: user confirmed via screenshots — issue_finder works as intended; chat_finder also recalls correctly (the apparent surprise was downstream of a separate chat_finder sort bug, spun off as #122).

## Log


- 2026-05-06: closed — Recall verified by user via screenshots showing chat_finder reopen lands on previously-confirmed chat by identity (issue_finder confirmed working as intended). 6 unit specs in tests/unit/float_picker_spec.lua cover record / restore / stale fallback / initial_index precedence / custom recall_id_fn / cancel-no-update — full suite green. Atlas updated: atlas/ui/pickers.md gained Recall section. Spun off #122 for the unrelated chat_finder sort surprise that came up during smoke.
### 2026-05-05

Locked at status=working. Design aligned with user: in-memory, on-select only, all pickers, stale → initial_index fallback. Common mechanism via float_picker `recall_key`.

Implemented centrally in `float_picker.M.open` via two opts: `recall_key` (string, namespacing) and `recall_id_fn` (item → stable id, defaults to `item.value`). Storage on module-level `M._last_selection` table. Recall is only consulted when `opts.initial_index` is unset, so transient post-action restore (delete + reopen) keeps precedence.

Wired into 11 picker call sites; skipped 4 with justification above. 6 new unit specs; full suite green.

Atlas: added Recall section to `atlas/ui/pickers.md` next to Sticky Query — same family of within-session state preservation.

