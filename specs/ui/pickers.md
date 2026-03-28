# Spec: UI Pickers

## Architecture
- Single custom `float_picker` for all selection UIs — no external dependencies
- Two stacked floats: results (top, read-only) + prompt (bottom, 1-line insert-mode)
- Centered, clamped to screen (`MARGIN_H=4`, `MARGIN_V=3`)
- `anchor` option: `"bottom"` (default, Chat Finder) = item 1 nearest prompt; `"top"` = item 1 at top row
- `VimResized` repositions; `WinLeave` (to unrelated window) closes
- `initial_query` seeds prompt text for first filter pass

## Fuzzy Search
- Query split on whitespace; ALL words must match (AND); order irrelevant
- Bracket stripping: `[tech]` matches same as `tech`
- Token-prefix matching scored highest; bounded edit-distance typo tolerance (first char must match)
- Subsequence fallback for fzf-like feel; full-word queries must match within single token
- Matched chars highlighted with `Search`; typo-tolerance edits with `ParleyPickerApproximateMatch`
- Empty query = all items, original order, no highlights
- `TextChangedI`/`TextChanged` drives filtering; control keys handled separately

## Mouse
- Single click: move selection, keep prompt focus
- Double click: confirm and close

## Keyboard (prompt insert mode)
- `<CR>`: confirm (MUST NOT be overridden by `<C-m>` equivalents)
- `<Esc>`/`<C-c>`: cancel
- `<C-j>`/`<Down>`: select visually downward; `<C-k>`/`<Up>`: select visually upward
- Scroll only when selection crosses visible edge

## Standard Action Keys (not all apply to every picker)
- `<CR>` select, `<C-d>` delete, `<C-n>` new, `<C-r>` rename, `<C-e>` edit
- `<C-x>` move, `<C-a>` recency left, `<C-s>` recency right, `<C-g>?` help

## Agent Picker (`:ParleyAgent`)
- Shows agent name, provider, model; current marked `✓` sorted to top

## System Prompt Picker (`:ParleySystemPrompt`)
- Current marked `✓` sorted to top; descriptions truncated to 80 chars

## Chat Finder (`:ParleyChatFinder` / `<C-g>f`)
- Bottom-anchored, sorted by mtime (newest first)
- Recency filter: configurable `chat_finder_recency.months` + `presets` cycle + `All`
- Search ranked against filename+tags+topic (not display row)
- Extra-root chats show `{label}` marker; search text includes label
- Bare `{}` matches only primary-root chats
- Sticky filter fragments (`[tag]`, `{root}`, bare `{}`) preserved across reopen flows
- Bracketed filters match tags only; braced filters match root-labels only — no fallback
- `<C-d>`: delete with confirmation (reopen on cancel; preserve visual row position)
- `<C-x>`: move to another chat root (reopen on cancel)
- `<C-a>`/`<C-s>`: recency cycle

## Note Finder (`:ParleyNoteFinder` / `<C-n>f`)
- Same mechanics as Chat Finder (bottom-anchored, sticky fragments, recency cycle)
- Recursive scan excluding `notes_dir/templates/`
- Recency uses directory-derived dates, not just mtime
- First-level non-date/non-template folders bypass recency, show `{base_folder}` prefix
- Bare `{}` matches only dated Year/Month/Week notes
- Braced filters match special folder labels only
- `<C-d>`: delete with confirmation + reopen

## Chat Roots Picker (`:ParleyChatDirs` / `<C-g>h`)
- Shows configured roots in order (primary first, then extras with labels)
- `<C-n>`: add new root, `<C-r>`: rename label, `<C-d>`: remove (primary not removable)
- Confirmation prompt opens while picker stays visible

## Outline Picker (`:ParleySearchChat` `<C-g>n` / `:ParleyOutline` `<C-g>t`)
- Document-order headings and conversation turns
- Selecting jumps cursor with brief highlight flash
