---
id: 000154
status: done
deps: []
github_issue:
created: 2026-06-29
updated: 2026-06-29
estimate_hours: 0.5
started: 2026-06-29T18:30:05-07:00
actual_hours: 0.27
---

# raise max_tool_iterations default to 42

## Problem

The default `max_tool_iterations` (tool-loop rounds per chat response) should be
raised from 20 to 42. While mapping the current value, the "default" turned out
to be **three inconsistent literals** for the same concept:

- `init.lua:689` — `agent.max_tool_iterations or 20` (the canonical setup-time
  default applied to tool-enabled agents; this is what actually governs).
- `tool_loop.lua:233` — `agent_info.max_tool_iterations or 20` (defensive fallback).
- `chat_respond.lua:1693` — `agent_info.max_tool_iterations or 10` (defensive
  fallback — a **stale 10**, inconsistent with the real default).

The atlas also disagrees with itself: `providers/agents.md` says "default 20",
`providers/tool_use.md` says "default 10".

## Spec

Raise the default to **42**, and — per `ARCH-DRY` / Root-Cause — **single-source**
it instead of hand-syncing three literals (the stale `10` was the direct symptom
of that duplication; re-syncing copies re-arms the same footgun). Define the
value **once** in `lua/parley/defaults.lua` (`M.max_tool_iterations = 42`, the
existing home for default values, already imported via `require("parley.defaults")`)
and reference it from the canonical site (`init.lua:689`) and the two defensive
fallbacks (`tool_loop.lua:233`, `chat_respond.lua:1693`). After this, no code path
can structurally disagree about the default, and a single test pins the constant.
Explicit per-agent `max_tool_iterations` overrides are unaffected.

Sweep the config example comment and both atlas docs to 42 (lessons 2026-06-17:
reconcile behavioral descriptors, not just the primary doc).

Out of scope: `tool_result_max_bytes` has the same triple-literal pattern, but its
value is consistent (102400) everywhere and not the subject of this issue —
left as-is (a candidate for the same single-sourcing later).

## Done when

- The default lives in **one** place (`defaults.max_tool_iterations = 42`); the
  three former literals reference it (no duplicated magic number remains).
- Setup-time default for a tool-enabled agent with no explicit override is 42;
  explicit overrides still honored (regression tests assert both).
- `config.lua` example comment and `atlas/providers/{agents,tool_use}.md` say 42.
- `make test` + `make lint` green.

## Plan

- [x] TDD red: add a test pinning `require("parley.defaults").max_tool_iterations
  == 42`, and update the default-resolution assertions in `config_tools_spec.lua`
  (lines 79/89 DefaultIterAgent, 150/179 ToolSonnet) from 20 → 42.
- [x] Add `M.max_tool_iterations = 42` to `defaults.lua`; replace the literals at
  `init.lua:689` (`or 20`), `tool_loop.lua:233` (`or 20`), and
  `chat_respond.lua:1693` (`or 10`) with references to it.
- [x] Sweep docs: `config.lua:260` comment, `atlas/providers/agents.md`,
  `atlas/providers/tool_use.md` → 42.
- [x] Run `make test-spec SPEC=providers/tool_use` (covers config_tools +
  tool_loop), `make test`, `make lint`.

## Estimate

```estimate
model: estimate-logic-v2
familiarity: 1.0
item: lua-neovim design=0.0 impl=0.25
item: atlas-docs design=0.0 impl=0.05
item: milestone-review design=0.0 impl=0.2
design-buffer: 0.0
total: 0.5
```

Reconciles as Σ(impl) 0.5 + design-buffer 0.0 = 0.5. Pure mechanical value sweep
(no design): `lua-neovim impl` covers the 3 code literals + 4 test-assertion
updates; `atlas-docs` the comment + 2 atlas lines; `milestone-review` the single
close boundary review.

## Log

### 2026-06-29
- 2026-06-29: closed — TDD red→green: config_tools_spec.lua — new test pins require("parley.defaults").max_tool_iterations==42, and the two default-resolution tests (DefaultIterAgent, ToolSonnet incl. get_agent chain) updated 20→42; explicit-override tests still pass. make test-spec SPEC=providers/tool_use green; make test full suite exit 0, 0 failures/errors; make lint 0/0 (237 files). Single-sourced the default in defaults.lua (ARCH-DRY) referenced by init.lua/tool_loop.lua/chat_respond.lua (added requires to the latter two); swept config.lua comment + atlas agents.md/tool_use.md (corrected stale 10). No stray 20/10 default literal remains.; review verdict: SHIP

- Filed from a live request to raise the default. Mapped every default site
  (`init.lua:689`, `tool_loop.lua:233`, `chat_respond.lua:1693`, `config.lua:260`,
  `atlas/providers/agents.md`, `atlas/providers/tool_use.md`) and the tests that
  pin the default (`config_tools_spec.lua`). Found the 10-vs-20 inconsistency to
  fix alongside the bump.
- `change-code` plan-quality judge returned FAILURE (ARCH-DRY): hand-syncing the
  three literals would re-arm the drift that produced the stale `10`. Revised the
  plan to single-source the default in `defaults.lua` and reference it from all
  three sites — the Root-Cause fix. `defaults.lua` is the right home (config.lua
  returns the data table, so a constant there would pollute the config namespace).
