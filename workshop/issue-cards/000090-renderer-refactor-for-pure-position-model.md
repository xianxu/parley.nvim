---
id: '000090'
status: done
created: 2026-04-09
actual_hours: N/A
---

# Renderer refactor — pure position model for chat buffer

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
