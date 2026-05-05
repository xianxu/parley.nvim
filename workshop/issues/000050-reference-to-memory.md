---
id: 000050
status: done
deps: []
created: 2026-04-02
updated: 2026-05-04
---

# reference to memory

Create a way to refer to past memory in the form of chat files. largely, memory is in the form of chat files, and agent can rg across it. I think we already have tool call setup, I don't quite remember if the grep tool in parley, uses rg, if not, we should just move over to rg.

The user interaction sequence would be something like this:

> do you remember what we talked about aws? 

this would trigger LLM to trigger local search tool call, and we would pipe rg result over. maybe the amount of context lines can be customized by agent, when they make tool call request, default to be -1, +2 lines.

chat file lives in multiple different repos, and a global location. we can use the following convention:

{global}/something-chat-file-in-the-global-location.md
{parley.nvim}/workshop/parley/chat-in-parley-repo.md
{brain}/workshop/parley/chat-in-brain-repo.md

the last two are repos from super-repo mode. note we choose to send for repo mode, or super repo mode to be rooted at parent of the repo. You can say always send in super-repo format. 

## Done when

- A new builtin tool lets the LLM ripgrep across all chat roots (global + repo + super-repo siblings) in one call.
- Results are prefixed with a `{repo}/...` marker so the LLM (and user) can tell which repo each hit lives in.
- Tool default context is `-B 1 -A 2`, with overrides from the agent.
- Existing `grep` tool stays cwd-confined; the new tool is the only escape hatch for searching past chats.

## Plan

### Spec

Tool name: `chat_history_search`. Distinct from `grep` because:
- `grep` is cwd-scoped (per dispatcher path-resolve guard); chat roots routinely live outside cwd (global iCloud dir, sibling super-repo members).
- Different default context lines, narrower argument surface (no raw command string — we choose the flags).

Inputs:
- `pattern` (string, required) — regex passed to rg.
- `before` (int, default 1) — `-B` context lines.
- `after` (int, default 2) — `-A` context lines.
- `glob` (string, optional) — passed as `--glob`. Default `*.md` enforced internally.
- `case_insensitive` (bool, default true) — `-i` toggle (chats are casual prose).
- `max_count` (int, optional) — `-m` per-file cap to prevent runaway output.

Backend selection mirrors `grep.lua`: detect rg first, fall back to system grep, surface which one is active in the tool description. Translate the structured args to whichever backend is present (rg uses `--glob`/`-B`/`-A`/`-i`/`-m`; grep uses `--include=`/`-B`/`-A`/`-i`/`-m`/`-r`).

Roots:
- Source from `parley.get_chat_roots()`. This already includes global, repo-local, and super-repo siblings.
- For each root, compute a display label and a display anchor:
  - If `root.dir` ends in `/workshop/parley`, anchor = parent dir, label = `basename(parent)`. Output paths become `{<repo_basename>}/workshop/parley/<file>`.
  - Otherwise anchor = `root.dir`, label = `root.label or basename(dir)`. Output paths become `{<label>}/<file>` (covers global iCloud dir → `{parley}/foo.md` or similar).
- Result paths are absolute from rg; we strip the anchor and prefix `{label}/`.

Behavior:
- Run grep-or-rg once per root, collect outputs, join with separator headers.
- If neither backend is present, return error.
- Confine to `*.md` files by default since chat files are markdown.
- Skip roots whose dir doesn't exist on disk (sibling repo without `workshop/parley`).

Wiring:
- Add `"chat_history_search"` to `BUILTIN_NAMES` in `lua/parley/tools/init.lua`.
- Add `"chat_history_search"` to the default `tools = {...}` lists for `ToolSonnet` and `ToolOpus` in `lua/parley/config.lua` (these are the chat-buffer agents).
- New file: `lua/parley/tools/builtin/chat_history_search.lua`.
- New test: `tests/unit/tools_builtin_chat_history_search_spec.lua`.
- Atlas: extend `atlas/providers/tool_use.md` with the new tool row + a brief mention under Chat Memory atlas.

Out of scope (not doing now):
- Migrating `grep` from system grep to rg-only — the existing tool already prefers rg when available; behavior is fine.
- A separate "list all chats" tool — `chat_history_search` with a permissive pattern serves that need.
- Surfacing this in agent default tool lists — adding to `BUILTIN_NAMES` makes it available; per-agent inclusion is a separate concern.

### Tasks

- [x] Implement `lua/parley/tools/builtin/chat_history_search.lua` (handler + description + schema).
- [x] Register in `lua/parley/tools/init.lua` `BUILTIN_NAMES`.
- [x] Wire into `ToolSonnet` and `ToolOpus` default agent tool lists in `lua/parley/config.lua`.
- [x] Unit test covering: basic match, root-prefix rewriting, missing-pattern error, no-matches case, glob filter, case-insensitive default.
- [x] Update `atlas/providers/tool_use.md` (tool table + cwd-scope note).
- [x] Update `atlas/chat/memory.md` with a pointer to the search tool.
- [x] Update `atlas/traceability.yaml` (code + test refs).
- [x] Refresh golden payloads (the `ToolSonnet` request shape now includes `chat_history_search`).
- [x] `make test` green except for pre-existing keybindings_spec failure (unrelated, present on main before this change).
- [x] `make lint` clean.

## Log

### 2026-04-02

- Issue authored.

### 2026-05-04

- Pulled context from `atlas/providers/tool_use.md`, `lua/parley/tools/builtin/grep.lua`, `lua/parley/super_repo.lua`, `lua/parley/init.lua` (apply_repo_local), and `lua/parley/root_dirs.lua`.
- Drafted plan; user approved with two adjustments: (a) keep system-grep fallback for parity with the existing `grep` tool, (b) wire the new tool into chat-buffer agents by default.
- Implemented `chat_history_search` builtin tool, registered, wired into `ToolSonnet` + `ToolOpus`, added 8 unit tests, refreshed golden payloads, updated atlas (`tool_use.md`, `memory.md`, `traceability.yaml`).
- One pre-existing test failure (`key bindings help other context shows global keys only`) verified via `git stash` — unrelated to this change.

