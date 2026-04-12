# Spec: UI Pickers

Custom `float_picker` for all selection UIs — no external dependencies. Two or three stacked floats: results + optional tag bar + prompt.

## Navigation
Up/down arrow keys wrap around at list boundaries (top wraps to bottom, bottom wraps to top).

## Fuzzy Search
AND-matching across whitespace-split tokens. Token-prefix scoring, bounded edit-distance typo tolerance, subsequence fallback.

## Tag Bar
Optional filterable tag row between results and prompt. OR logic — file visible if any enabled tag matches. Caller owns state; picker fires toggle callbacks.

## Picker Types
- **Agent** (`:ParleyAgent`): select active agent
- **System Prompt** (`:ParleySystemPrompt`): select active system prompt
- **Chat Finder** (`:ParleyChatFinder` / `<C-g>f`): browse chats by recency, tags, and roots; mtime-cached metadata; sticky filter fragments across reopens
- **Note Finder** (`:ParleyNoteFinder` / `<C-n>f`): same mechanics as Chat Finder for notes; special folders bypass recency
- **Chat Roots** (`:ParleyChatDirs` / `<C-g>h`): manage configured chat directories
- **Outline** (`:ParleySearchChat` / `:ParleyOutline`): jump to headings and turns
