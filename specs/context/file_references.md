# File References (@@)

## Syntax
- `@@<ref>@@` — only canonical form supported
- Ref types: `@@https://...@@`, `@@/absolute@@`, `@@~/home@@`, `@@./relative@@`
- No bare filenames, no colon syntax, no end-at-whitespace

## Behavior
- Inline anywhere in text: `review @@./file.lua@@ and improve it`
- Content loaded with filename header and line numbers
- Chat transcript refs render with topic: `@@2026-03-24.12-34-56.123.md: Topic@@`
- Non-chat refs keep original text

## Keybindings
- `<C-g>o`: Open file/directory under cursor

## Rules
- Exchanges with `@@` refs MUST be preserved in full during memory management (never summarized)
