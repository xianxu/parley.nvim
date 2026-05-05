---
id: 000087
status: done
deps: []
created: 2026-04-09
updated: 2026-05-05
actual_hours: 0.5
---

# in parley chat's repo mode, put the name of the repo as default filter in chat finder

this way offers both a long stronger signal of repo mode is on, also removes noises from other chats.

## Spec

In plain repo mode (the local repo's chat root carries the literal `"repo"` label per `init.lua:420`), pre-seed the chat finder's sticky-query fragment to `{repo}` on the first open of a parley session. The existing `finder_sticky` mechanism (#114, commit 0bd0322) already supports `{repo}` as a sticky filter — this issue just defaults it on rather than starting empty.

Triggers on:
- `config.repo_root` is set (parley detected the repo marker), AND
- `config.super_repo_root` is unset (super-repo mode is not active — that mode aggregates siblings, and narrowing to `{repo}` would defeat its whole purpose).

One-shot semantics: once seeded, the user can clear or modify the filter and sticky-query takes over normally. The default is never re-applied within a session — clearing means clearing.

Scope: chat finder only. Note / issue / vision / markdown finders are intentionally left alone — the issue text targets the chat finder.

## Done when

- [x] First chat-finder open in plain repo mode pre-fills `{repo}` filter.
- [x] Subsequent opens use whatever sticky-query the user left it at (including cleared).
- [x] Super-repo mode does not get the default.
- [x] No-repo mode does not get the default.
- [x] Unit test for `default_sticky_query_for_repo_mode` covering all three branches.
- [x] Atlas (`atlas/ui/pickers.md`) updated.
- [x] `make lint` clean, `make test-unit` clean.

## Plan

- [x] Add pure helper `chat_finder.default_sticky_query_for_repo_mode(config)` returning `"{repo}"` only when `config.repo_root` is set and `config.super_repo_root` isn't.
- [x] One-shot guard at the top of `chat_finder.M.open`: if `_chat_finder.sticky_query_initialized` is false, flip it to true and pre-seed `sticky_query` (only if currently nil) via the helper.
- [x] Add `sticky_query_initialized = false` field to `M._chat_finder` initial state in `init.lua:3400`.
- [x] Reset `sticky_query_initialized = false` in `chat_finder_logic_spec` `before_each`.
- [x] Add `default_sticky_query_for_repo_mode` describe block with three test cases.
- [x] Atlas: extend the Sticky Query section in `atlas/ui/pickers.md` to mention the repo-mode pre-seed.

## Log

### 2026-04-09

- Issue authored.

### 2026-05-05

- Confirmed local-repo chat root has the literal label `"repo"` (init.lua:420). Existing `finder_sticky.extract` already accepts `{repo}` as a sticky fragment via #114 (commit 0bd0322). So this issue is purely about choosing a sensible default — no new mechanism, just one-shot pre-seeding.
- Decision: skip in super-repo mode. Users explicitly toggle super-repo to *see* siblings; defaulting to `{repo}` would silently undo that.
- Implemented via pure helper + one-shot guard. Tests pass, lint clean.
- Side-quest atlas cleanup: `atlas/ui/pickers.md` had a dead entry for the removed `:ParleyChatDirs` / `<C-g>h` Chat Roots picker (removed in 8918ba3 alongside the keybindings_spec assertion fixed in commit fbd4f40). Dropped the line. Same dead-reference shape as the previous side-quest — atlas was simply behind.

