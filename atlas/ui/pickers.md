# Spec: UI Pickers

Custom `float_picker` for all selection UIs — no external dependencies. Two or three stacked floats: results + optional tag bar + prompt.

## Navigation
Up/down arrow keys wrap around at list boundaries (top wraps to bottom, bottom wraps to top).

## Fuzzy Search
AND-matching across whitespace-split tokens. Token-prefix scoring, bounded edit-distance typo tolerance, subsequence fallback. `{root}` / `[tag]` query tokens scope to bracketed haystack labels of the same kind; in-progress forms (`{char`, `[bu`) work the same way as their completed counterparts.

## Sticky Query
`lua/parley/finder_sticky.lua` extracts `{root}` (and `[tag]` for chat finder) fragments from the prompt on every keystroke and re-seeds them on the next reopen. Plain text is intentionally not preserved. Wired into chat, note, issue, vision, and markdown finders.

The chat finder additionally pre-seeds `{}` (the primary chat root, which in repo mode is the repo chat root) on the first open of a parley session in plain repo mode, so the default view is scoped to repo chats and global chats are filtered out. The pre-seed is a one-shot — once the user clears or modifies the filter, sticky-query takes over and the default is never re-applied. Skipped in super-repo mode (whose whole point is aggregating siblings, which a `{}` narrowing would defeat).

## Recall (Last Selection)
Pickers that opt in via `recall_key` remember the id of the last `<CR>`-confirmed item (in-memory only) and place the cursor there on the next open. `recall_id_fn` lets callers point at the stable identity field (defaults to `item.value`; e.g. `item.name` for agent_picker, `item.dir` for root_dir_picker). Stale recall (id no longer present in items) silently falls through to whatever `initial_index` resolves — typically the first item. Cancel/`<Esc>` does not update recall; only confirmation does. Storage lives on `float_picker._last_selection` keyed by the picker's `recall_key`.

## Tag Bar
Optional filterable tag row between results and prompt. OR logic — file visible if any enabled tag matches. Caller owns state; picker fires toggle callbacks.

## Picker Types
- **Agent** (`:ParleyAgent`): select active agent
- **System Prompt** (`:ParleySystemPrompt`): select active system prompt
- **Chat Finder** (`:ParleyChatFinder` / `<C-g>f`): browse chats by recency, tags, and roots; mtime-cached metadata; sticky filter fragments across reopens
- **Note Finder** (`:ParleyNoteFinder` / `<C-n>f`): same mechanics as Chat Finder for notes; special folders bypass recency
- **Outline** (`:ParleySearchChat` / `:ParleyOutline`): jump to headings and turns
