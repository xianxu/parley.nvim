---
id: 000094
status: open
deps: []
created: 2026-04-10
---

# Debug tracing infrastructure

## Summary

Add toggle-able debug tracing for the chat response pipeline. Currently debugging requires adding ad-hoc file dumps (payload/response to /tmp/claude/parley-debug/) and removing them after. Need a proper infrastructure that can be turned on/off without code changes.

## Context

During #90, multiple rounds of ad-hoc trace logging were added and removed. The pattern: dump request payload, raw SSE response, model state, and buffer state to files for post-mortem analysis. This should be a first-class feature.

## Possible approach

- Config flag `debug.trace_responses = true/false`
- When enabled, write to a structured log directory per session
- Include: messages JSON, payload JSON, raw SSE response, model state (block kinds/sizes), buffer snapshot
- Toggle via command: `:ParleyDebug on/off`

## Plan

_TBD_

## Log

- **2026-04-10 — filed** from #90 follow-up.
