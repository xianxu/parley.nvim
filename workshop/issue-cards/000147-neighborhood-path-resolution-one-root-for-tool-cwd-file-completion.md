---
id: '000147'
status: done
started: 2026-06-29T10:22:13-07:00
created: 2026-06-26
updated: 2026-06-29
estimate_hours: 2.2
actual_hours: 2.01
---

# neighborhood path resolution: one root for tool cwd + file completion

## Problem

Relative paths — both in agent tool calls and in nvim's file-completion — resolve
against `vim.fn.getcwd()`, which is **incidental editor state** (where nvim was
launched / last `:cd`), not anything tied to the artifact's meaning. It's confusing
exactly when the artifact's own location is out of mind: chats live in `chat_dir`
(global) or `<repo>/workshop/parley/` (repo mode), and neither human nor agent
thinks about where the chat file sits. So `./` is unpredictable, and the operator's
nvim completion (rooted at the *current file* via `~/.config/nvim`) is unhelpful
when you don't know where that file is.

(`./` resolution traced in #140/#139: `tool_loop` passes `agent_info.cwd or
vim.fn.getcwd()`; `resolve_path_in_cwd` joins `cwd .. "/" .. path`.)
