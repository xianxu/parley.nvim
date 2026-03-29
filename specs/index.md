# Parley.nvim Specifications

## Overview
This index provides a central directory for all specifications of the `parley.nvim` plugin.

## 1. Core Chat System
- [Chat Format](chat/format.md): Transcript prefixes and front matter header metadata.
- [Chat Lifecycle](chat/lifecycle.md): Creation, response, resubmission, and deletion.
- [Chat Memory](chat/memory.md): History management, summarization, and preservation.
- [Chat Parsing](chat/parsing.md): Buffer segmentation, turn identification, and branch link parsing.
- [Inline Branch Links](chat/inline_branch_links.md): Footnote-style `[🌿:text](file)` links within chat text.

## 2. LLM Providers & Agents
- [Provider Architecture](providers/architecture.md): Transport layer, payload construction, and streaming.
- [OpenAI Provider](providers/openai.md): Implementation for OpenAI-compatible backends.
- [CLIProxyAPI Provider](providers/cliproxyapi.md): OpenAI-compatible local proxy provider for multi-vendor models.
- [Anthropic Provider](providers/anthropic.md): Implementation for Claude models.
- [Google AI Provider](providers/googleai.md): Implementation for Gemini models.
- [Agents](providers/agents.md): Agent configuration and selection mechanisms.
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
- [Configuration System](infra/config.md): Settings and merging logic.
- [Vault (Secret Management)](infra/vault.md): Secret retrieval and storage.
- [Logging System](infra/logging.md): Logging and inspection tools.
- [Linting](infra/linting.md): Lua static analysis baseline and `make lint` behavior.
- [OpenShell Sandbox](infra/openshell.md): Hermetic dev environment via NVIDIA OpenShell.
- [AI Workflow](infra/workflow.md): Issue-based development, worktree management, and pre-merge checks.

## 8. Special Modes
- [Interview Mode](modes/interview.md): Mechanics and automatic timestamps.
- [Raw Mode](modes/raw_mode.md): API debugging via raw requests/responses.

## 9. Export
- [Export Formats](export/formats.md): Jekyll HTML and Markdown export logic.
- [Tree Export](export/tree_export.md): Exporting chat trees as multiple linked files with navigation.

## 10. Spec Traceability
- [Traceability Map](traceability.yaml): Mapping from each feature spec to implementation files and related tests. 
