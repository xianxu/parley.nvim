# Spec: UI Pickers

## Overview
Parley uses a single custom floating-window picker (`float_picker`) for all selection UIs.
No external picker dependency is required.
Pickers may seed the prompt via `initial_query`; that text is rendered immediately and used for the first filter pass before the user types.

## Layout
Each picker opens two stacked floating windows:
- **Results window** (top): read-only list of items, `cursorline` shows the current selection, linked through `PmenuSel` for stronger theme-driven contrast.
- **Prompt window** (bottom, 1 line): focused on open, implemented with a prompt buffer. The user types a fuzzy query here.

Both windows share the same width and are centered as a unit. Actual dimensions are clamped to the screen with `MARGIN_H = 4` cols and `MARGIN_V = 3` rows on each side. The prompt window adds a fixed overhead of 5 rows (two sets of borders + 1 content row) to the total vertical height.

Item display order is controlled by the `anchor` option passed to `float_picker.open()`:
- `"bottom"` (default): the logical first item (index 1) is shown on the bottom row nearest the prompt; later items extend upward; unused rows pad above. Used by Chat Finder so newest files stay closest to the prompt.
- `"top"`: the logical first item is shown on the top row; later items extend downward; unused rows pad below. Used by all other pickers (agent, system prompt, outline, etc.) for natural document order.

Keyboard navigation preserves the current view until selection crosses a visible edge, then scrolls just enough to keep the selected row visible.

`VimResized` repositions both windows (cleaned up on close).

## Fuzzy Search
Typing in the prompt filters and re-ranks the results live on every keystroke:
- Query is split on whitespace into **words**.
- Surrounding square brackets on query tokens are ignored for matching, so tag-style terms like `[tech]` match the same entries as `tech`.
- **All words must match** for an item to be included (AND logic).
- **Word order does not matter** — `"gpt open"` matches `"openai gpt-4"`.
- Matching is **word-aware**: candidate text is tokenized on non-word separators, and token-prefix matches score highest.
- Small typos are tolerated on token prefixes with bounded edit distance, so near-prefixes like `"anthrpic"` still match `"anthropic"`, but approximate prefix matching still requires the first query character to match the candidate token.
- A lower-ranked whole-string subsequence fallback keeps the picker feeling `fzf`-like for short plain fragments, but full-word plain queries must match within a single token rather than spanning word boundaries.
- Items are scored and sorted by match quality (prefix, early boundary, and consecutive compact matches score higher).
- Exact matched characters are highlighted with `Search`.
- Candidate positions consumed by typo-tolerance edits are highlighted with `ParleyPickerApproximateMatch`, so approximate hits show where the edits were applied.
- Empty query shows all items in their original order with no highlights.
- Prompt text changes are driven by prompt-buffer `TextChangedI` / `TextChanged` updates, while control-key actions are handled separately so non-text inputs do not reset selection.

## Mouse Interaction
- **Single click** in results: moves selection to clicked row without changing the current list view; focus stays in the prompt (insert mode).
- **Double-click** in results: confirms the selection and closes the picker.
- Insert-mode prompt mouse mappings intercept result clicks via `getmousepos()`, update the selection, and restore prompt focus without leaving the picker active state.

## Keyboard (from prompt)
| Key | Action |
|-----|--------|
| `<CR>` | Confirm selected item; picker-local extra mappings MUST NOT override this through equivalent keycodes such as `<C-m>` |
| `<Esc>` / `<C-c>` | Cancel and close |
| `<C-j>` / `<Down>` | Move selection visually downward toward the prompt; scroll only after reaching the bottom visible edge |
| `<C-k>` / `<Up>` | Move selection visually upward away from the prompt; scroll only after reaching the top visible edge |
| Extra mappings such as `<C-d>` / `<C-a>` | Routed through picker-local key handling so control keys work inside the prompt buffer without being treated as text edits |

## Sizing
- `desired_w` = max of title width + 4 and longest item width + 2, or `opts.width` if provided.
- `desired_h` = number of items, or `opts.height` if provided (controls results window only).
- Both are clamped to screen bounds.

## WinLeave Behaviour
The picker closes if focus moves to any window that is neither the results nor the prompt window.

## Agent Picker
- `:ParleyAgent`: Opens a picker with agent names, providers, and models.
- The current agent is marked with `✓` and sorted to the top; others are alphabetical.

## System Prompt Picker
- `:ParleySystemPrompt`: Opens a picker with named system prompts.
- The current prompt is marked with `✓` and sorted to the top; others are alphabetical.
- Descriptions are truncated to 80 characters in the display.

## Chat Finder
- `:ParleyChatFinder` (`<C-g>f`): Browse and open chat files.
- **Recency Filter**: By default shows files from the configured `chat_finder_recency.months`, and can cycle through additional `chat_finder_recency.presets` before reaching `All`.
- Finder search is ranked against a dedicated search string built from the chat filename, tags, and topic instead of the fully formatted display row.
- Chats from extra chat roots show a compact `{label}` marker between the filename and the tag/title portion so users can distinguish them from primary-root chats at a glance.
- Finder search text MUST include the extra-root label so users can filter by root name.
- Bare `{}` in Chat Finder MUST match only chats from the primary chat root.
- When the prompt contains sticky filter fragments such as `[workspace] [client-a]` or `{family}`, Chat Finder preserves those fragments between invocations and internal reopen flows (delete/move/recency cycling). Reopened prompts seed the preserved fragments with a trailing space so users can immediately continue with free-text filtering. Non-fragment free-text terms are not preserved.
- Bare `{}` MUST be preserved by the same sticky-filter mechanism.
- Bracketed filters MUST match only tag entities, and braced filters MUST match only root-label entities; they MUST NOT fall back to plain word matching elsewhere in the row text.
- **Extra mappings** (insert mode in prompt):
    - Next recency key (`<C-a>` by default): Move left through configured recency windows toward smaller cutoffs.
    - Previous recency key (`<C-s>` by default): Move right through configured recency windows toward larger cutoffs and `All`.
    - Delete key (`<C-d>` by default): Delete the selected chat file.
      The confirmation prompt is opened from the source window after the picker closes. If it is cancelled with `Esc` or answered negatively, ChatFinder reopens instead of being dismissed.
      After a confirmed delete, ChatFinder preserves the same visual row in the bottom-anchored list: it prefers the older surviving neighbor that slides into the deleted row, and falls back to the newer neighbor only when deleting the oldest visible entry.
    - Move key (`<C-r>` by default): Move the selected chat file to another registered chat root.
      The move picker opens after ChatFinder closes. Destination rows show primary/extra status, label, and directory path. If it is cancelled, ChatFinder reopens on the original chat.
    - `<C-g>?`: Open Parley key-bindings help.
- Files are sorted by modification date, newest first.

## Note Finder
- `:ParleyNoteFinder` (`<C-n>f`): Browse and open note files under `notes_dir`.
- Note Finder uses the same floating-picker mechanics as Chat Finder, including bottom anchoring and picker-local control-key mappings.
- The scan MUST be recursive and MUST exclude files under `notes_dir/templates/`.
- **Recency Filter**: By default shows files from `note_finder_recency.months`, and can cycle through additional `note_finder_recency.presets` before reaching `All`.
- For notes in dated directory trees, recency filtering MUST use directory-derived date ranges as a coarse inclusion heuristic rather than relying only on filesystem mtime.
- Notes under first-level non-date, non-template folders MUST bypass the recency filter and stay visible in all note-finder windows.
- Those special-folder notes MUST display a compact `{base_folder}` prefix ahead of the filename, and Note Finder search text MUST include the same braced folder label.
- Bare `{}` in Note Finder MUST match only notes from the dated Year/Month/Week tree.
- When the prompt contains sticky folder fragments such as `{K}`, Note Finder preserves those fragments between invocations and internal reopen flows. Non-fragment free-text terms are not preserved.
- Bare `{}` MUST be preserved by the same sticky-filter mechanism.
- Braced Note Finder filters MUST match only these special first-level folder labels.
- **Extra mappings**:
  - Next recency key (`<C-a>` by default): Move left through configured recency windows toward smaller cutoffs.
  - Previous recency key (`<C-s>` by default): Move right through configured recency windows toward larger cutoffs and `All`.
  - Delete key (`<C-d>` by default): Delete the selected note after confirmation, then reopen Note Finder on the surviving item that stays in the same visual row when possible.
  - `<C-g>?`: Open Parley key-bindings help.

## Chat Roots Picker
- `:ParleyChatDirs` (`<C-g>h`): Opens a picker showing the configured chat roots in order.
- The first item is the primary writable root used for new chats; later items are additional discovery roots.
- Every row shows the root role plus a user-facing label.
- Extra mappings:
  - `<C-n>`: Prompt for a new root, then prompt for a label (defaulting to the directory basename), and add it as an extra root.
  - `<C-r>`: Rename the selected extra-root label.
  - `<C-d>`: Remove the selected root after confirmation. The confirmation prompt opens while the picker stays visible; cancelling returns focus to the same picker instance.
- The primary root MUST NOT be removable from the picker.

## Navigation / Outline Picker
- `:ParleySearchChat` (`<C-g>n`) and `:ParleyOutline` (`<C-g>t`): Navigate headings and conversation turns.
- Items are listed in document order (top to bottom).
- Selecting an item jumps the cursor to that line with a brief highlight flash.
