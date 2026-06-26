---
id: 000147
status: open
deps: []
github_issue:
created: 2026-06-26
updated: 2026-06-26
estimate_hours:
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

## Spec

Resolve relative paths against the artifact's **reference neighborhood** — a
*derived* property, not `getcwd()`. **Type-derived only**, no frontmatter override
(deliberately avoid config sprawl). Two cases:

- **Repo-backing parley artifact** (repo-moded chat / issue / note) → **repo root**.
  It backs the repo; you think in repo-root-relative paths (`lua/parley/foo.lua`).
- **Everything else** (global chat, content file under review) → **the artifact's
  own folder**. Global chat = its own folder (minimal blast radius — to keep local
  state, make a repo). A content doc (e.g. blog post) references its siblings.

So one predicate ("does this back a repo?"), two answers. The only thing that earns
"repo root" is *being a repo-moded parley artifact*; anything self-contained → own
folder.

**One source of truth** — a pure-ish `neighborhood(artifact/buf) → root` — feeding
**two consumers**:

1. **Tool-call `cwd`**: replace `agent_info.cwd or vim.fn.getcwd()` with
   `neighborhood()` in `tool_loop` (and `skill_invoke`, where it already correctly
   uses the artifact's folder).
2. **Buffer-local file completion** for chat buffers: parley owns it, because only
   parley has the "this buffer is a repo-moded chat" context. A buffer-local override
   *inside parley buffers* — the operator's global `~/.config/nvim` completion is
   untouched everywhere else.

Plus: **tell the agent its root** in the tool-use context, so it stops guessing from
`getcwd()`.

**Consumer status (one concept, two consumers):** `read_file` and any
`path`/`file_path` field already resolve faithfully against `cwd` via
`resolve_path_in_cwd`, so they're correct *for free* once `cwd = neighborhood()`.
`ls`/`grep`/`find` do **not** consume `cwd` (they run in nvim's *process* cwd) — so
full consistency for them lands **with #144**, which rewires them to honor cwd +
confine. This issue is independent of #144 for the `read_file` + completion +
tell-the-agent parts; the shell-tool half is a #144 dependency, not a blocker.

(Origin: brainstorm 2026-06-26 — reframed from "improve safety" #139/#144 once we
realized `./` was keyed to incidental editor state.)

## Done when

- Tool-call `cwd` = `neighborhood()` (repo root for repo-moded chats; the chat's
  folder for global chats), not raw `getcwd()`.
- `read_file` + path fields resolve relative paths against the neighborhood.
- Parley provides a buffer-local, neighborhood-rooted file completion in chat
  buffers, independent of the operator's `~/.config/nvim`.
- The agent is told its neighborhood root in the tool-use context.
- Shell-tool (`ls`/`grep`/`find`) consistency tracked with #144 (they honor cwd
  once #144 lands).

## Plan

- [ ] Pure `neighborhood(artifact/buf) → root` (repo-moded chat → repo root; else → own folder); reuse parley's repo-mode detection.
- [ ] Wire tool-call cwd to `neighborhood()` (`tool_loop` / `skill_invoke`).
- [ ] Buffer-local neighborhood-rooted file completion for chat buffers.
- [ ] Surface the neighborhood root in the agent's tool-use context.
- [ ] Tests: neighborhood derivation (repo-moded / global / content), cwd wiring.
- [ ] Atlas + docs.

## Log

### 2026-06-26
