---
id: 000096
status: working
deps: [000090]
created: 2026-04-10
---

# Migrate remaining nvim_buf_set_lines callers to buffer_edit

## Summary

The #90 arch test allows several UI/picker modules to still call `nvim_buf_set_lines` directly. Migrate them to `buffer_edit` for consistency, then tighten the arch test allow list.

## Context

Deferred during #90 as YAGNI for the renderer scope. These callers are outside the chat response pipeline (pickers, float windows, system prompt editor, etc.) so they don't cause the buffer-corruption bugs #90 fixed. Migration is for consistency.

## Modules to migrate

- chat_finder
- init (UI helpers)
- vision
- issues
- float_picker
- config
- system_prompt_picker
- highlighter

## Plan

_TBD_

## Log

- **2026-04-10 — filed** from #90 follow-up.
