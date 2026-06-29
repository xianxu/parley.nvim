# Neighborhood Path Resolution Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Resolve chat/artifact-relative paths from one derived neighborhood root and feed that root to tool cwd, skill invocation, file completion, and agent context.

**Architecture:** Add one pure-ish neighborhood module that derives a root from an artifact path plus injected config/root metadata, then keep all Neovim buffer and dispatcher wiring thin. This satisfies `ARCH-DRY` by making tool cwd and completion consume one source, `ARCH-PURE` by testing derivation without UI mocks, and `ARCH-PURPOSE` by wiring every Done-when consumer in this issue.

**Tech Stack:** Lua, Neovim APIs, plenary test harness via `make test-spec` / `make test`.

---

## Core Concepts

### Pure Entities

| Name | Lives in | Status |
|------|----------|--------|
| `Neighborhood` | `lua/parley/neighborhood.lua` | new |

**Neighborhood** — the derived reference root for an artifact path.
- **Relationships:** 1:1 with an artifact path at use time; N:1 with repo config because many repo-backed artifacts map to the same repo root.
- **DRY rationale:** Replaces duplicated `vim.fn.getcwd()` / artifact-folder choices in chat tool use, skill invocation, and completion.
- **Future extensions:** If issue/note buffers later need command-specific completion, widen the consumer set while keeping the same derivation.

### Integration Points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `ToolLoopNeighborhoodCwd` | `lua/parley/tool_loop.lua`, `lua/parley/chat_respond.lua` | modified | tool dispatcher cwd |
| `SkillInvokeNeighborhoodCwd` | `lua/parley/skill_invoke.lua` | modified | artifact tool exchange cwd |
| `ChatNeighborhoodCompletion` | `lua/parley/neighborhood.lua`, `lua/parley/init.lua` | new | buffer-local completion options |
| `ToolContextMessage` | `lua/parley/agent_info.lua` or payload assembly caller | modified | agent-visible system/tool context text |

**ToolLoopNeighborhoodCwd** — `chat_respond` passes `neighborhood.for_buf(buf).root` into `tool_loop.process_response`; `tool_loop` keeps accepting injected `agent_info.cwd`.
- **Injected into:** Existing dispatcher `execute_call`, which already resolves `path` / `file_path` against cwd.
- **Future extensions:** #144 shell tools inherit the same cwd once their handlers consume dispatcher cwd.

**SkillInvokeNeighborhoodCwd** — replaces artifact-folder-only cwd with `neighborhood.for_buf(buf).root`, preserving artifact-bound `propose_edits.file_path`.
- **Injected into:** Existing `tools_dispatcher.execute_call`.
- **Future extensions:** Non-review skills get the same semantics without a second path policy.

**ChatNeighborhoodCompletion** — attaches a buffer-local `completefunc` during `prep_chat`, rooted at `Neighborhood.root`.
- **Injected into:** Chat buffer only; global editor completion remains untouched.
- **Future extensions:** Can switch to a richer completion source if needed, while keeping the root provider unchanged.

**ToolContextMessage** — appends short agent-facing context to `agent_info.system_prompt` before `system_prompt_msgs.build(agent_info)` runs in `chat_respond.build_messages` / `build_messages_from_model`, so the model sees the same root tools use.
- **Injected into:** Existing system-prompt message assembly; no new provider-specific behavior.
- **Future extensions:** If providers get structured tool metadata, this string can become structured context from the same root.

## Chunk 1: Neighborhood Core

### Task 1: Add pure derivation tests

**Files:**
- Create: `lua/parley/neighborhood.lua`
- Test: `tests/unit/neighborhood_spec.lua`

- [x] Write tests for `derive_for_path(path, config, roots)`:
  - repo-moded chat under `<repo_root>/<repo_chat_dir>` returns `repo_root`.
  - global chat under a non-repo chat root returns its folder.
  - content artifact outside chat roots returns its own folder.
  - blank/invalid path returns `nil, "buffer has no file"`.
- [x] Run `make test-spec SPEC=neighborhood` and verify the new tests fail because the module does not exist.
- [x] Implement `derive_for_path` using injected data only; normalize paths with existing `root_dirs.resolve_dir_key`.
- [x] Add thin `for_buf(buf)` wrapper that reads `nvim_buf_get_name(buf)`, live config, and `chat_dirs.get_chat_roots()`.
- [x] Re-run `make test-spec SPEC=neighborhood` and verify it passes.

## Chunk 2: Tool Cwd Consumers

### Task 2: Wire chat tool cwd

**Files:**
- Modify: `lua/parley/chat_respond.lua`
- Test: `tests/unit/tool_loop_spec.lua` or a focused chat-response wiring spec if existing tests make `chat_respond` practical.

- [x] Add a failing test proving a relative `read_file` from a repo chat resolves under repo root, not `vim.fn.getcwd()`.
- [x] Replace the `cwd = vim.fn.getcwd()` call-site value with `require("parley.neighborhood").for_buf(buf).root`, falling back only when derivation fails.
- [x] Re-run the targeted test and confirm it passes.

### Task 3: Wire skill invocation cwd

**Files:**
- Modify: `lua/parley/skill_invoke.lua`
- Test: `tests/integration/skill_invoke_spec.lua`

- [x] Add a failing test where a skill on a repo-backed artifact executes a `read_file`/`propose_edits` call whose relative path is valid from repo root but invalid from the artifact folder.
- [x] Replace `cwd = vim.fn.fnamemodify(artifact_path, ":h")` with the neighborhood root, while keeping `propose_edits.file_path = artifact_path`.
- [x] Re-run `make test-spec SPEC=skills/skill-system` or the direct skill-invoke spec target and confirm it passes.

## Chunk 3: Completion and Agent Context

### Task 4: Attach neighborhood-rooted completion to chat buffers

**Files:**
- Modify: `lua/parley/neighborhood.lua`
- Modify: `lua/parley/init.lua`
- Test: `tests/integration/not_chat_spec.lua` or new `tests/integration/neighborhood_completion_spec.lua`

- [x] Add a failing integration test that opens a chat buffer, runs `prep_chat`, and verifies buffer-local completion/path root points at the derived neighborhood.
- [x] Implement `completefunc` over root-relative file candidates and attach it buffer-locally to chat buffers only.
- [x] Assert `vim.bo[buf].completefunc` points at Parley's neighborhood completion function and candidate paths are rooted at `Neighborhood.root`.
- [x] Ensure non-chat buffers do not receive the override.
- [x] Re-run the targeted integration test.

### Task 5: Surface the root to the agent

**Files:**
- Modify: `lua/parley/chat_respond.lua`
- Modify: `lua/parley/neighborhood.lua`
- Test: `tests/unit/build_messages_spec.lua`

- [x] Add a failing test that `build_messages` includes the neighborhood root string in the leading system context when tool use is active.
- [x] Feed the derived root into `agent_info.system_prompt` before `system_prompt_msgs.build(agent_info)` in both parse-based and model-based message builders.
- [x] Re-run the payload/context test.

## Chunk 4: Docs and Verification

### Task 6: Update atlas and traceability

**Files:**
- Modify: `atlas/providers/tool_use.md`
- Modify: `atlas/infra/repo_mode.md`
- Modify: `atlas/traceability.yaml`
- Modify: `workshop/issues/000147-neighborhood-path-resolution-one-root-for-tool-cwd-file-completion.md`

- [x] Document neighborhood cwd in tool-use behavior and repo-mode docs.
- [x] Add new module/tests to traceability.
- [x] Tick issue plan items and add dated log notes.
- [x] Run `make test-spec SPEC=providers/tool_use`, targeted new specs, `make test`, and `make lint`.

## Revisions

### 2026-06-29 — boundary-review fixes

Reason: the close boundary review found two architectural gaps after the first
implementation pass.

Delta:
- The `Neighborhood` API is a bare root string (`root, err`), not a `{ root = ... }`
  table, matching the plan-quality refinement to drop unused `kind` surface.
- `skill_invoke` uses `neighborhood.for_buf(buf)` so current-repo and super-repo
  sibling chat artifacts share the same root derivation path as chat tool use.
- `neighborhood` delegates path normalization and containment checks to
  `root_dirs.resolve_dir_key` / `root_dirs.path_within_dir`, as Task 1 intended.
