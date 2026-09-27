---
id: 000288
status: open
deps: []
github_issue:
created: 2026-09-27
updated: 2026-09-27
estimate_hours:
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

## Spec

- Add a native blink source (e.g. `lua/parley/completion/blink_source.lua`)
  exposing `new()` + `get_completions(ctx, callback)` around the existing pure
  `neighborhood.completion_candidates(policy, base)`, with the same token rule
  as the cmp adapter (`[^%s%(%[%{]+$`).
- Register it only for Parley chat buffers (per-buffer `sources` or an
  `enabled` predicate), and load it only if `pcall(require, "blink.cmp")`
  succeeds. **No hard dependency.** The cmp adapter and `completefunc` stay
  (ARCH-DRY: both adapters share `completion_candidates`; move shared glue into
  one place rather than duplicating the token/label logic).
- Spelling: a source backed by `vim.fn.spellsuggest()` for the word at the
  cursor when `spell` flags it (or blink's spell source, if a good one exists).
  Decide the trigger: as-you-type on a flagged word vs. an explicit key.
  pair's draft nvim already has a spell popup UX (`z=` → numbered menu), see
  pair#334; reuse its lessons.
- Keep room for more sources later (chat/issue references, agent names);
  design the registration so adding one is a single entry.
- App: once #287 ships blink, switch the app from `sources.default = {}` to
  enabling the Parley sources in chat buffers only. Decide whether that's in
  this issue or a follow-up.
- Update `health.lua` to report which completion backend attached (cmp,
  blink, or completefunc only).

## Done when

- With blink installed, typing a partial path in a chat buffer offers the
  same candidates as `completion_candidates` (and **not** files outside the
  read roots); without blink, behavior is unchanged (cmp adapter +
  completefunc).
- A misspelled word in a chat buffer can be corrected from a blink menu
  of `spellsuggest()` results.
- Unit tests for the source's `get_completions` (with a fake ctx), and an
  integration test with blink loaded asserting policy-scoped candidates plus a
  no-blink test asserting graceful absence.
- `:checkhealth parley` shows the attached completion backend.
- atlas updated for the completion surface.

## Plan

- [ ] Design: source registration, shared glue with the cmp adapter, spell trigger
- [ ] Blink neighborhood-path source + tests
- [ ] Spell source + tests
- [ ] Health reporting; atlas
- [ ] App wiring (here or follow-up, per design)

## Log

### 2026-09-27
- Filed with #287 (app blink cmdline). Observation: `python3` and `curl`
  are used by the plugin but not declared in `lua/parley/deps.lua`; unrelated
  to this issue, noted in case it's worth its own issue.

