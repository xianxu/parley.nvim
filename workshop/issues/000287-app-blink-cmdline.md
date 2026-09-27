---
id: 000287
status: open
deps: []
github_issue:
created: 2026-09-27
updated: 2026-09-27
estimate_hours:
---

# app: blink.cmp (lua matcher) for fuzzy cmdline completion and history search

## Problem

In the Parley app, the `:` command line only has Vim's stock prefix Tab
completion. People who aren't Vim experts can't find commands (`:ParleyTheme`,
`:MarkdownPreview`, …) or reuse earlier commands without knowing their exact
prefix. We want fzf-style fuzzy completion as you type on the command line,
covering both command names and command history.

## Spec

- Add `saghen/blink.cmp` to `additional_plugins` in
  `packaging/starter-config/init.lua`, **pinned by `commit`** like lualine,
  telescope and markdown-preview (candidate: v1.10.2 =
  `78336bc89ee5365633bcf754d93df01678b5c08f`, the commit behind the annotated
  tag; the tag object itself is `9b189bb…`).
- `fuzzy = { implementation = "lua" }`: the pure-Lua matcher, so there is **no
  prebuilt binary download and no Rust toolchain**. blink never looks for the
  binary in this mode, so the app installs nothing beyond the git clone.
- Cmdline only: `sources.default = {}`, so there are no insert-mode popups
  while writing chats (the app does not take ordinary editing keys, #262).
  Insert-mode completion is #288's scope.
- `cmdline = { enabled = true, keymap = { preset = "cmdline" }, completion =
  { menu = { auto_show = true } } }`, with Tab/S-Tab cycling as in the stock
  wildmenu.
- History search: confirm what blink's cmdline source offers from history
  (`:` and `/`). If it doesn't cover fuzzy history recall, add a key such as
  `<C-r>` in cmdline mode, or a telescope `command_history` picker (telescope
  is already packaged). Decide during design.
- Updates: a release bumps the SHA; users adopt it from `init.lua.new`, then
  run `:Lazy update blink.cmp` (Lazy does not move an installed plugin to a
  changed `commit` on its own). Note this in the release notes / starter
  README. The underlying gap (existing installs quietly stay on old pinned
  plugins) applies to every pinned plugin and is out of scope; file separately
  if wanted.
- The plugin itself stays dependency-free: blink is an app-layer choice only.

## Done when

- Launching the app and typing `:mkpv` offers `MarkdownPreview` in a
  fuzzy-ranked popup, and `:thm` offers `ParleyTheme`, with no network
  download beyond the git clone (no `.so`/`.dylib` fetched into blink's dir).
- Insert mode in a chat buffer shows no blink popup.
- Fuzzy recall of earlier commands works (by blink's source or the chosen
  history key).
- A headless test (`tests/integration/` or `tests/packaging/`) asserts
  blink's cmdline completions for a fuzzy query and the absence of an
  insert-mode menu; existing starter/packaging tests stay green.
- The starter README documents the completion behavior and the update step.

## Plan

- [ ] Check blink 1.10.x cmdline + history behavior with `implementation = "lua"`
- [ ] Add the pinned plugin entry to the starter init.lua
- [ ] Headless test: fuzzy cmdline completion; no insert-mode popup; no binary download
- [ ] Starter README: completion + update note

## Log

### 2026-09-27
- Filed from a session comparing cmdline fuzzy options (built-in
  `wildoptions+=fuzzy`, wilder.nvim, nvim-cmp, fzf-lua/snacks pickers); chose
  blink for the app. Companion: #288 (plugin nvim-cmp → blink), pair#334
  (audit of the draft nvim's completion).

