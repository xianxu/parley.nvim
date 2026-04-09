---
id: 000090
status: open
deps: [000081]
created: 2026-04-09
---

# Renderer refactor — pure position model for chat buffer

## Summary

Extract a pure data model + pure render layer + single mutation entry point for the chat buffer, replacing the ad-hoc line-offset arithmetic that currently lives inside `lua/parley/chat_respond.lua::M.respond`. Unblocks #81 M2 Task 2.7 and everything downstream (M3 edit_file, M4 iteration cap + synthetic results, M5 write_file, M6 cancellation UI).

## Problem

`chat_respond.M.respond` computes buffer line positions imperatively through a chain of dependent variables:

```
response_line      ← helpers.last_content_line(buf)
                     OR answer.line_end (recursion branch)
                     OR question.line_end - 1 (new-question branch)
response_block_lines ← {"", "🤖: [Agent]", "", progress} (normal)
                     OR {""} (recursion)
raw_request_offset ← 0 or N (after inserting raw-request fence)
progress_line      ← response_line + 3 + raw_request_offset (normal)
                     OR response_line + 1 + raw_request_offset (recursion)
response_start_line ← spinner_active and (progress_line + 2) or progress_line
```

Each new scenario stacks another branch. The `+3` vs `+1` magic numbers are the direct cause of two M2 Task 2.7 bugs (progress_line offset mismatch, stuck-spinner cleanup failure), and a third bug — Anthropic rejecting the recursive call as "assistant message prefill" — is strongly suspected to come from the same mutation path corrupting buffer state.

As #81 M3/M4/M5/M6 add more states (multi-round tool use, iteration-cap synthetic `📎:`, cancellation mid-tool-call, error rendering, fold/expand, streaming-into-existing-sections), every new state multiplies the number of offset branches. The code becomes non-deterministic to reason about and increasingly hostile to test.

## Why now

- Blocks #81 M2 Task 2.7 manual verification (current Anthropic rejection bug)
- Blocks #81 M2 Task 2.11 code review gate
- Blocks all of #81 M3–M6 (each tool-use feature stacks more renderer branches)
- Cheaper to refactor now while the M2 surface is small than after M3–M6 have piled more branches on top
- Golden-snapshot test catalog (part of this refactor) is also the missing piece for regression detection in #81's remaining milestones

## Out of scope

- `chat_parser.lua` — already clean, only gains precise `lines = [start,end]` per section
- `providers.lua` payload shape — clean
- `tool_loop.lua` driver logic — clean, only its one line-offset call site (`_append_block_to_buffer`) gets rewritten on top of the new mutation layer
- `_build_messages` + `_emit_content_blocks_as_messages` — clean
- `tools/*` — untouched
- UI features (fold, highlight, lualine indicator refinements) — follow-ups
- Any #81 M3–M6 feature work — blocked on this landing

## Spec

_TBD — will be filled out in the brainstorm phase of the fresh session._

Placeholder structure:
- Pure data model (sections with line spans)
- Pure render module (`render_buffer.lua`)
- Single mutation entry point (`buffer_edit.lua`)
- Extmark-backed position handles for streaming
- Golden-snapshot catalog
- Migration order (incremental, never big-bang)

## Plan

_TBD — will be filled out after brainstorm, in the plan phase._

## Log

- **2026-04-09 — filed**. Problem + scope + why-now captured above. Next: fresh session, enter brainstorming mode, write `## Spec`, then write `docs/plans/000090-renderer-refactor.md`, then execute.
