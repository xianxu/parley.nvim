---
id: '000287'
status: done
started: 2026-09-27T11:18:04-07:00
created: 2026-09-27
updated: 2026-09-27
actual_hours: 1.13
---

# app: blink.cmp (lua matcher) for fuzzy cmdline completion and history search

## Problem

In the Parley app, the `:` command line only has Vim's stock prefix Tab
completion. People who aren't Vim experts can't find commands (`:ParleyTheme`,
`:MarkdownPreview`, …) or reuse earlier commands without knowing their exact
prefix. We want fzf-style fuzzy completion as you type on the command line,
covering both command names and command history.
