# Parley.nvim Atlas

## Overview
Use this atlas to answer questions about the installed Parley release and find
the code and tests behind each feature. Pages describe current behavior and
limitations; optional maintainer/repository integrations are labeled separately.
Implementation details belong in the linked source, not a duplicate manual.

For hands-on learning, start with [Welcome](../packaging/tutorials/welcome.md),
[Basics](../packaging/tutorials/basics.md), and [Advanced](../packaging/tutorials/advanced.md).
For app defaults and storage, start with [application configuration](infra/starter.md).
For the active shortcuts, use `:ParleyKeyBindings` (Ctrl+g then `?` by default);
that help reflects your Parley configuration. `parley_help` lists this index,
its feature pages, and the three tutorials without reading personal files.

## 1. Core Chat System
- [Chat Format](chat/format.md): Transcript markers, header syntax, and tags.
- [Chat Lifecycle](chat/lifecycle.md): Create, rename, respond, stop, and delete conversations.
- [Answer Recovery](chat/recovery.md): Previous-answer snapshots and guarded restore.
- [Question Batches](chat/batch.md): Fixed selection, progress, and explicit resume.
- [Chat Response Progress](chat/response_progress.md)
- [Chat Attachments](chat/attachments.md): Image syntax, limits, and file ownership.
- [Chat Memory](chat/memory.md): Context windows and optional summarization.
- [Memory Preferences](chat/memory_prefs.md): Opt-in preference profiles from past conversations.
- [Chat Parsing](chat/parsing.md)
- [Incremental Document Structure](chat/document.md): Shared index and bounded structural repair.
- [Chat Write Ownership](chat/ownership.md): Captured sources, scoped write grants, and cancellation evidence.
- [Exchange Model](chat/exchange_model.md)
- [Inline Branch Links](chat/inline_branch_links.md): Create a sub-chat and follow a standalone or inline branch.
- [Drill-In Markers](chat/drill_in.md)
- [Inline Term Definition](chat/inline_define.md): Explain a selected term with a managed definition.
- [Spell Typeahead](chat/spell_typeahead.md)

## 2. LLM Providers & Agents
- [Provider Architecture](providers/architecture.md)
- [OpenAI Provider](providers/openai.md)
- [CLIProxyAPI Provider](providers/cliproxyapi.md)
- [Managed cliproxyapi](providers/cliproxy-managed.md)
- [Anthropic Provider](providers/anthropic.md)
- [Google AI Provider](providers/googleai.md)
- [Agents](providers/agents.md)
- [Tool Use](providers/tool_use.md)
- [System Prompts](providers/system_prompts.md)

## 3. Context & References
- [File References (@@)](context/file_references.md): Include local files or directories in model context.
- [Artifact-Ref Navigation](context/artifact_refs.md)
- [Google Drive Context](context/google_drive.md): Read Google documents with an authenticated account.
- [Web Search](context/web_search.md): Enable search and understand provider support.

## 4. Notes & Templates
- [Note Finder](notes/finder.md)
- [Notes Structure](notes/structure.md)
- [Note Templates](notes/templates.md)

## 5. Issue Management
- [Issue Management](issues/issue-management.md)

## 6. UI & UX Components
- [UI Pickers](ui/pickers.md): Chat Finder, model selection, filtering, and navigation.
- [Key Bindings Help](ui/keybindings.md): Configured shortcuts, aliases, disabled actions, and fixed picker controls.
- [Outline Navigation](ui/outline.md): Questions, markers, and branches; branch selection opens the child file.
- [Lualine Integration](ui/lualine.md)
- [Syntax Highlighting](ui/highlights.md)

## 7. Infrastructure & Security

- [macOS packaging](infra/packaging.md)
- [Parley application and release configuration](infra/starter.md): App versus plugin behavior and profile ownership.
- [Repo Mode](infra/repo_mode.md)
- [Configuration System](infra/config.md): App/plugin setup, defaults, overrides, and storage roots.
- [Vault (Secret Management)](infra/vault.md)
- [Logging System](infra/logging.md): Diagnostic messages and sensitive-data handling.
- [Raw-Mode Logging](infra/raw_logging.md): Opt-in transcript/request logs for debugging.
- [Linting](infra/linting.md)
- [Test Harness](infra/test_harness.md)
- [External dependencies](infra/dependencies.md)
- [OpenShell Sandbox](infra/openshell.md): Optional maintainer infrastructure, outside the app release.
- [AI Workflow](infra/workflow.md): Optional maintainer development workflow.

## 8. Skill System & Special Modes
- [Skill System](skills/skill-system.md): Review, voice application, and term definition.
- [Interview Mode](modes/interview.md)
- [Raw Mode](modes/raw_mode.md)
- [Document Review](modes/review.md)
- [Super-Repo Mode](modes/super_repo.md)

## 9. Export
- [Export Formats](export/formats.md): Export HTML/Markdown and keep linked assets available.
- [Tree Export](export/tree_export.md): Export linked conversations as a browsable tree.

## 10. Discovery Registry
- [Discovery Registry](discovery/registry.md): Repository vocabulary library and its current integration limits.

## 11. Traceability
- [Traceability Map](traceability.yaml)
