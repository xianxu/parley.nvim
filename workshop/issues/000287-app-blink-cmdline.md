---
id: 000287
status: working
deps: []
github_issue:
created: 2026-09-27
updated: 2026-09-27
estimate_hours:
started: 2026-09-27T11:18:04-07:00
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

Quick flow (under 20 code lines, all in the app starter; the rest is tests and docs).

- [ ] `packaging/starter-config/init.lua`: add blink.cmp pinned to v1.10.2 with
      `fuzzy.implementation = "lua"`, `sources.default = {}`,
      `keymap.preset = "none"` (insert mode claims no keys, #262), and cmdline
      `preset = "cmdline"` minus `<Left>`/`<Right>` with `menu.auto_show`.
- [ ] Same file: telescope spec gains `keys = { "<C-g>:" → builtin.command_history }`
      for fuzzy history recall (blink has no history source; stock `<Up>`/`<Down>`
      prefix history stays).
- [ ] `tests/packaging/bootstrap_lazy.lua` (automated, via starter_bootstrap_spec):
      assert blink's pin and opts, and that the `<C-g>:` key calls `command_history`.
- [ ] `tests/packaging/completion_compatibility.lua`: release check against the
      real pinned blink (`PARLEY_BLINK_RUNTIME`): run the production starter,
      type `:mkpv`/`:thm` → menu shows `MarkdownPreview`/`ParleyTheme`; insert
      mode → no items, no menu, no blink insert keymaps; no native library in blink's dir.
- [ ] Starter README + `atlas/infra/starter.md` + `atlas/traceability.yaml`.

## Log

### 2026-09-27
- Filed from a session comparing cmdline fuzzy options (built-in
  `wildoptions+=fuzzy`, wilder.nvim, nvim-cmp, fzf-lua/snacks pickers); chose
  blink for the app. Companion: #288 (plugin nvim-cmp → blink), pair#334
  (audit of the draft nvim's completion).
- Design (headless prototype against blink v1.10.2 with the `lua` matcher):
  `:mkpv` → `MarkdownPreview`, `:thm` → `ParleyTheme`, and the menu shows on
  typing; `fuzzy/download/init.lua:15` returns before any download for
  `"lua"`. The default insert preset would claim `<C-n>`/`<C-p>`/`<C-k>`/
  `<Tab>`… so `keymap.preset = "none"` (verified: zero insert maps, zero items).
  The `cmdline` preset binds `<Left>`/`<Right>` to select_next/prev while the
  menu is open (always, with auto_show), so both are dropped to keep cursor
  movement. blink's cmdline sources are `buffer` + `cmdline` (getcompletion);
  there is no history source, so history is telescope `command_history` on
  `<C-g>:` (free key; telescope already packaged).

