# Parley.nvim Atlas

## Overview
This index provides a central directory for all atlas entries of the `parley.nvim` plugin — practical pointers for future developers and agents to understand the sketch of functionalities, history, and intention. Details live in the code.

## 1. Core Chat System
- [Chat Format](chat/format.md): Transcript prefixes and front matter header metadata.
- [Chat Lifecycle](chat/lifecycle.md): Creation, slug rename (auto from topic), response, resubmission, and deletion.
- [Chat Memory](chat/memory.md): History management, summarization, and preservation.
- [Memory Preferences](chat/memory_prefs.md): Per-tag user preference profiles from chat history summaries.
- [Chat Parsing](chat/parsing.md): Buffer segmentation, turn identification, and branch link parsing.
- [Exchange Model](chat/exchange_model.md): Size-based positional model — single source of truth for buffer layout. Everything is a block.
- [Inline Branch Links](chat/inline_branch_links.md): Footnote-style `[🌿:text](file)` links within chat text.

## 2. LLM Providers & Agents
- [Provider Architecture](providers/architecture.md): Transport layer, payload construction, and streaming.
- [OpenAI Provider](providers/openai.md): Implementation for OpenAI-compatible backends.
- [CLIProxyAPI Provider](providers/cliproxyapi.md): OpenAI-compatible local proxy provider for multi-vendor models.
- [Anthropic Provider](providers/anthropic.md): Implementation for Claude models.
- [Google AI Provider](providers/googleai.md): Implementation for Gemini models.
- [Agents](providers/agents.md): Agent configuration and selection mechanisms.
- [Tool Use](providers/tool_use.md): Client-side tool loop, Unix tools (ls/find/grep), file operations (read/edit/write), safety mechanisms.
- [System Prompts](providers/system_prompts.md): Editable system prompts with built-in/custom/modified sources.

## 3. Context & References
- [File References (@@)](context/file_references.md): Syntax for local file and directory inclusion.
- [Google Drive Context](context/google_drive.md): Google Docs integration and OAuth flow.
- [Web Search](context/web_search.md): Provider-specific web search tools.

## 4. Notes & Templates
- [Note Finder](notes/finder.md): Recursive note picker with recency filtering and deletion.
- [Notes Structure](notes/structure.md): Year/Month/Week organization logic.
- [Note Templates](notes/templates.md): Template system for new notes.

## 5. Issue Management
- [Issue Management](issues/issue-management.md): Repo-local issue tracking with single-file-per-issue format, scheduler, and decomposition.

## 6. UI & UX Components
- [UI Pickers](ui/pickers.md): Custom floating-window pickers for agents, prompts, finder, and outline navigation.
- [Key Bindings Help](ui/keybindings.md): Shortcut reference command and default mapping.
- [Outline Navigation](ui/outline.md): Buffer navigation and outline logic.
- [Lualine Integration](ui/lualine.md): Statusline component and indicators.
- [Syntax Highlighting](ui/highlights.md): Highlighting groups and rules.

## 7. Infrastructure & Security
- [Repo Mode](infra/repo_mode.md): Marker-file detection for parley-enabled repos with auto-created local directories.
- [Configuration System](infra/config.md): Settings and merging logic.
- [Vault (Secret Management)](infra/vault.md): Secret retrieval and storage.
- [Logging System](infra/logging.md): Logging and inspection tools.
- [Linting](infra/linting.md): Lua static analysis baseline and `make lint` behavior.
- [OpenShell Sandbox](infra/openshell.md): Policy-enforced agent sandbox via NVIDIA OpenShell + mutagen file sync.
- [AI Workflow](infra/workflow.md): Issue-based development, worktree management, and pre-merge checks.

## 8. Skill System & Special Modes
- [Skill System](skills/skill-system.md): Unified pipeline for AI-powered buffer editing skills (`<C-g>s` picker, skill_runner, skill definitions).
- [Interview Mode](modes/interview.md): Mechanics, automatic timestamps, and `{thought}` highlighting.
- [Raw Mode](modes/raw_mode.md): API debugging via raw requests/responses.
- [Document Review](modes/review.md): LLM-powered document review via 🤖 markers (implemented as a skill).
- [Super-Repo Mode](modes/super_repo.md): Toggle (`<C-g>S`) to aggregate reads across sibling `.parley` repos under the workspace root.

## 9. Export
- [Export Formats](export/formats.md): Jekyll HTML and Markdown export logic.
- [Tree Export](export/tree_export.md): Exporting chat trees as multiple linked files with navigation.

## 10. Vision Tracker
- [Vision Format](vision/format.md): YAML schema, multi-file namespacing, and ID resolution rules.
- [Vision Exports](vision/exports.md): CSV, DOT graph export, and validation.

## 11. Traceability
- [Traceability Map](traceability.yaml): Mapping from each feature entry to implementation files and related tests.
