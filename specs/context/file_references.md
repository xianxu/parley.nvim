# File References (@@)

## Syntax
- `@@<ref>@@` — only canonical form supported
- Ref types: `@@https://...@@`, `@@/absolute@@`, `@@~/home@@`, `@@./relative@@`
- No bare filenames, no colon syntax, no end-at-whitespace

## Behavior
- Inline anywhere in text: `review @@./file.lua@@ and improve it`
- Content loaded with filename header and line numbers
- Non-chat refs keep original text
- Chat-to-chat references now use `🌿:` branch links (see `chat/inline_branch_links.md`)

## Keybindings
- `<C-g>o`: Open file/directory under cursor

## Rules
- Exchanges with `@@` refs MUST be preserved in full during memory management (never summarized)
