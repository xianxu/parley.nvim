# Issue #91: Bug fixes in chat tree - relative paths show ⚠️

## Problem
Relative file paths in `🌿:` lines (both parent links and branch points) show ⚠️ warning icons even when the target file exists. This is because `vim.fn.filereadable()` resolves relative paths against Neovim's cwd, not the containing chat file's directory.

## Root Cause
`highlighter.lua:render_chat_branch_line()` uses `vim.fn.expand(path)` which only handles `~/` — relative paths like `../sibling.md` are checked against cwd. Navigation (`<C-g>o`) works because `:edit` handles relative paths differently.

## Fix
1. [x] Add `resolve_path` helper to `highlighter.lua` (same pattern as `chat_respond.lua:94-102`)
2. [x] Update `render_chat_branch_line(line)` → `render_chat_branch_line(line, base_dir)` to resolve paths relative to chat file
3. [x] Update caller at line ~645 to pass `base_dir` from buf name
4. [x] Also fix `render_chat_reference_label` and `render_markdown_chat_reference_line` which had the same issue for `@@` references
5. [x] Run tests and lint — all pass, pre-existing warning in outline.lua only
