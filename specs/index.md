# Parley.nvim Specifications

## Overview
This index provides a central directory for all specifications of the `parley.nvim` plugin.

## 1. Core Chat System
- [Chat Format](chat/format.md): Transcript prefixes and header metadata.
- [Chat Lifecycle](chat/lifecycle.md): Creation, response, resubmission, and deletion.
- [Chat Memory](chat/memory.md): History management, summarization, and preservation.
- [Chat Parsing](chat/parsing.md): Buffer segmentation and turn identification.

## 2. LLM Providers & Agents
- [Provider Architecture](providers/architecture.md): Transport layer, payload construction, and streaming.
- [OpenAI Provider](providers/openai.md): Implementation for OpenAI-compatible backends.
- [Anthropic Provider](providers/anthropic.md): Implementation for Claude models.
- [Google AI Provider](providers/googleai.md): Implementation for Gemini models.
- [Agents](providers/agents.md): Agent configuration and selection mechanisms.

## 3. Context & References
- [File References (@@)](context/file_references.md): Syntax for local file and directory inclusion.
- [Google Drive Context](context/google_drive.md): Google Docs integration and OAuth flow.
- [Web Search](context/web_search.md): Provider-specific web search tools.

## 4. Notes & Templates
- [Notes Structure](notes/structure.md): Year/Month/Week organization logic.
- [Note Templates](notes/templates.md): Template system for new notes.

## 5. UI & UX Components
- [UI Pickers](ui/pickers.md): Telescope integrations for agents, prompts, and finder.
- [Outline Navigation](ui/outline.md): Buffer navigation and outline logic.
- [Lualine Integration](ui/lualine.md): Statusline component and indicators.
- [Syntax Highlighting](ui/highlights.md): Highlighting groups and rules.

## 6. Infrastructure & Security
- [Configuration System](infra/config.md): Settings and merging logic.
- [Vault (Secret Management)](infra/vault.md): Secret retrieval and storage.
- [Logging System](infra/logging.md): Logging and inspection tools.

## 7. Special Modes
- [Interview Mode](modes/interview.md): Mechanics and automatic timestamps.
- [Raw Mode](modes/raw_mode.md): API debugging via raw requests/responses.

## 8. Export
- [Export Formats](export/formats.md): Jekyll HTML and Markdown export logic.

## 9. Spec Traceability
- [Traceability Map](traceability.yaml): Mapping from each feature spec to implementation files and related tests.
