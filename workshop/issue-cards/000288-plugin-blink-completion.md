---
id: 000288
status: open
created: 2026-09-27
updated: 2026-09-27
estimate_hours:
github_issue:
---

# plugin: move completion from nvim-cmp to blink (neighborhood paths, spelling)

## Problem

The plugin's chat-buffer completion only adapts to nvim-cmp.
`lua/parley/neighborhood.lua` (~L214–310) provides:
- `completefunc` (`<C-x><C-u>`): works everywhere, but hardly anyone knows it
  exists;
- a `parley_path` nvim-cmp source plus cmp's `buffer` source, attached per
  chat buffer only if `require("cmp")` succeeds.

Both offer **neighborhood paths**: files under the chat's `write_root` that
also pass `tools.dispatcher.resolve_read_path`, i.e. exactly the files the
model can read. blink.cmp users (now common, and the app is adopting blink in
#287) silently get none of this, and blink's generic `path` source ignores the
neighborhood policy, so it would suggest files the model can't read.

We also want more than paths: **spelling completion**, since the user often
mistypes words while writing questions.
