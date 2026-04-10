---
id: 000095
status: open
deps: [000090]
created: 2026-04-10
---

# Spinner and folding for tool call chains

## Summary

Long tool call chains (3+ rounds) leave the user staring at a static buffer with no feedback. Need progress indication and visual compaction.

## Context

During #90 testing, a simple "tell me about ARCH.md" triggered 5+ tool rounds (read_file, list_dir, glob, bash_code_execution, read_file). Each round takes 2-10 seconds. No spinner or progress indicator is shown during tool-use agent responses (spinner is disabled for tool agents).

## Requirements

1. **Progress indicator during tool rounds** — show which tool is being called and current round number (e.g., "🔧 read_file (round 2/10)")
2. **Fold completed tool blocks** — after a tool_result is written, fold the 🔧:/📎: pair so the buffer doesn't grow unboundedly. Show a summary line (e.g., "🔧 read_file → 7 lines")
3. **Unfold on demand** — user can expand any folded tool block to see full content

## Plan

_TBD_

## Log

- **2026-04-10 — filed** from #90 follow-up.
