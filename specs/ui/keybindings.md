# Spec: Key Bindings Help

## Command
- `:ParleyKeyBindings`: centered floating scratch window (`nofile`), close with `q`/`<Esc>`

## Shortcuts
- `<C-g>?` (normal+insert) opens help; insert mode exits insert first
- `<C-g>h` (normal+insert) opens chat dirs picker

## Content Requirements
- MUST include: global chat/note shortcuts, chat/markdown shortcuts (`<C-g>i` branch ref, `<C-g>p` prune, `<C-g>s` system prompt, `<C-g>x` stop), mode toggles (web_search, raw request, raw response), interview mode (`<C-n>i` enter, `<C-n>I` exit)
- Chat Finder section: both recency-cycle keys + delete + move
- Note Finder section: both recency-cycle keys + delete
- Shortcuts resolved from active runtime keymaps; fallback to configured defaults
