---
id: '000106'
status: done
created: 2026-04-14
updated: 2026-06-25
actual_hours: N/A
---

# Unified skill system for AI-powered buffer editing

## Problem

Parley's AI features (review, voice-apply, future tools) each wire up their own keybindings, system prompts, and LLM call plumbing. They all follow the same pattern:

1. Build a system prompt (specialized for the task)
2. Attach the `review_edit` tool (old_string → new_string + explain)
3. Send current buffer content to LLM
4. Apply returned edits to the buffer
5. Show changes via diagnostics + highlights

As we add more features (voice-apply, code review, tone shift, etc.), keybindings get crowded and each feature duplicates the same edit-apply-display pipeline.
