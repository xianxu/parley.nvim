---
id: 000100
status: done
deps: []
created: 2026-04-11
updated: 2026-04-11
---

# parley outline for all markdown files

I like parley outline for chat window. I want to enable similar thing on any markdown file. just display # and ##. 

## Done when

- Outline works on any `.md` file, showing `#` and `##` headings
- Chat files continue to work as before (tree outline with questions, branches, annotations)

## Spec

When `ParleyOutline` is invoked on a non-chat markdown file, show a flat outline of `#` and `##` headings. Each heading is displayed with indentation reflecting its level.

## Plan

- [x] Add `#`/`##`/`###` heading matching to `is_outline_item()` in `outline.lua`
- [x] Relax `not_chat` guard in `M.cmd.Outline` to allow `.md` files
- [x] Add `<C-g>t` keybinding in `setup_markdown_keymaps` (was only in chat keymaps)
- [x] Test — user verified working

## Log

### 2026-04-11

- Two-file change: `outline.lua` (heading detection) + `init.lua` (guard relaxation)

