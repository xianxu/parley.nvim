---
id: 000094
status: punt
deps: []
created: 2026-04-10
updated: 2026-06-29
started: 2026-06-29T17:30:16-07:00
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

## Status: deferred (punt)

Most of this issue's "possible approach" was **already implemented after it was
filed**, by #121's side-file `raw_mode` logging. Deferred until a concrete
LLM-integration task (e.g. improving Claude prefix caching) makes the remaining
*agent-debug* gap concrete enough to build correctly rather than speculatively.

### What already exists (#121, `raw_mode` / `raw_log.lua` / `log_emit.lua`)

- Config: `raw_mode = { enable, log_exchange, log_raw }` (`config.lua:628`).
- Toggles: `:ParleyToggleExchangeLog` / `:ParleyToggleRawLog`
  (`init.lua:952-979`); lualine parley section turns red while on.
- Writes per-turn side files at `<chat-dir>/.parley-logs/<basename>/`:
  - `exchange.md` — the message lists sent (system/user/assistant).
  - `raw.md` — request payload (YAML), assembled response (YAML), and the
    **exact raw SSE** stream lines.
- #121 deleted the older *in-buffer* raw view (the human kept finding it hard to
  manipulate inside nvim); the side-file form is the human-readable record and is
  worth keeping as-is — good for building intuition about interactions.

### The remaining gap (the actual point of resuming #94)

`raw_log` is a **human-readable** record. What it does *not* serve well is an
**agent** debugging parley↔LLM interactions:

- Request is **re-serialized as YAML**, not the exact JSON sent over the wire —
  actively misleading for prefix-caching debugging, which needs byte-identical
  prefixes + correct `cache_control` placement (and the `vim.empty_dict()` vs
  `[]` gotcha, see lessons 2026-04-10).
- Response `usage` cache fields (`cache_creation_input_tokens` /
  `cache_read_input_tokens`) aren't surfaced distinctly — those are how an agent
  *proves* caching works.
- Everything is appended into one growing `raw.md`; no per-request isolation for
  diffing turn N vs N+1 or replaying a single failing request.

### Resume trigger + intended shape

Pick this up **alongside** the first substantial LLM-integration task. Likely a
small addition on the existing trace points (do NOT duplicate `raw_log`'s
plumbing): an agent-oriented capture mode — exact request JSON + response (incl.
cache usage) as per-request files (e.g. `turn-NNN-request.json`), behind a single
`:ParleyDebug on/off` toggle. Build it when a real bug makes the required fields
concrete; until then it's YAGNI.

## Plan

_TBD — deferred; see Status above._

## Log

- **2026-04-10 — filed** from #90 follow-up.
- **2026-06-29 — brainstormed + deferred.** Claimed and explored the chat
  pipeline. Discovered #121 already shipped side-file `raw_mode` logging covering
  most of the "possible approach". With the operator, scoped the real remaining
  value as an *agent*-debug log (exact JSON + cache usage + per-request files) and
  decided to defer (`punt`) until a concrete LLM-integration task makes the
  requirements precise. Keep `raw_log` human-readable log as-is. Details above.
