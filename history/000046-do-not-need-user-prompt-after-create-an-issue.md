---
id: 000046
status: done
deps: []
created: 2026-03-31
updated: 2026-04-01
---

# do not need user prompt after create an issue

## Done when

- No "Press ENTER or type command to continue" prompt after creating an issue

## Plan

- [x] Shorten the logger.info message to use filename only instead of full path

## Log

### 2026-04-01

- Root cause: `_parley.logger.info("Created issue: " .. filepath)` produced a message like
  `Parley.nvim: Created issue: /Users/xianxu/workspace/parley.nvim/issues/000046-...` which
  exceeded one terminal line, triggering Neovim's "Press ENTER" prompt.
- Fix: use `vim.fn.fnamemodify(filepath, ":t")` to show only the filename (e.g.
  `Parley.nvim: Created issue: 000046-do-not-need-user-prompt-after-create-an-issue.md`).
- Changed `lua/parley/issues.lua:488`.
