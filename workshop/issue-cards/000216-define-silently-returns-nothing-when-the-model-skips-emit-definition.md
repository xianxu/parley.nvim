---
id: '000216'
status: punt
created: 2026-09-04
updated: 2026-09-11
---

# define silently returns nothing when the model skips emit_definition

## Problem

Reported in the #206 release shakedown (item 5, inline term definition).
Visual-select + `<M-CR>` produces no definition. Operator sees:

```
Parley.nvim: Agent Claude-Sonnet not found, using claude-opus-5*
Parley.nvim: skill define: model returned no tool call (response may be truncated)
Parley.nvim: Define: no definition returned
```

The first line is #215 (spurious warning + fallback to the live selection) and is
a **red herring** for this issue — the fallback worked and reached a tool-capable
model. This issue is the second and third lines.

Two failures on record in `~/.local/state/nvim/parley.nvim.log`:

| when | agent | body | duration | outcome |
|---|---|---|---|---|
| 15:37:44 | `claude-opus-5` | 4,143 B | 2.2s | no tool call |
| 15:53:47 | `claude-sonnet-5` | 73,713 B | 24.4s | no tool call |

### Ruled out, from the logged payload — not inferred

The request is well-formed. Extracted verbatim from the log:

```
model:       claude-opus-5      _parley_route: anthropic
tool_choice: (absent → auto)    max_tokens: 100000
system:      the define prompt, verbatim, including
             "ALWAYS call the emit_definition tool exactly once …
              Do not reply in plain prose."
tools:       web_search      type=web_search_20260209  allowed_callers=["direct"]
             web_fetch       type=web_fetch_20260209
             emit_definition input_schema ✓
```

| Hypothesis | Verdict |
|---|---|
| Response truncated | **No** — 4,143 B against a 100000 cap; `raise_output_cap` writes the right key |
| Wire mismatch (wrong decoder) | **No** — the anthropic usage parser read the same body fine |
| `emit_definition` absent from payload | **No** — present with a valid schema |
| System prompt lost or overridden | **No** — verbatim, including the instruction |
| Server tools clobber client tools | **No** — `dispatcher.lua:127-139` appends after `format_payload` |
| `raw_response` not accumulated on the headless path | **No** — 73,713 B captured (`dispatcher.lua:369`) |
| web_search consumed the turn | **Not on the opus run** — 2.2s / 4 KB is too fast and too small |

### The control that settles it

Operator tested `"what's in current repo"` in an ordinary chat. The model called
`ls` and `read_file` without complaint — **same model, same anthropic route, same
`web_search`/`web_fetch` tools declared, same `tool_choice: auto`**, and
`emit_definition` was in that payload too (all 12 tools ship on every chat turn).

| | define (failed) | chat (tools worked) |
|---|---|---|
| route / model | anthropic / claude-sonnet-5 | identical |
| `tool_choice` | auto | identical |
| `web_search` decl | identical | identical |
| `system` field | real `system` block | absent — prompt rides as `messages[0]` user text |
| messages | **1** (cold) | **9**, incl. prior `tool_use`/`tool_result` |
| tools | 3 | 12 |
| `max_tokens` | 100000 | 4096 |

### Root cause

Not a plumbing bug. `define` ships with **no `force_tool`**
(`skills/define/init.lua:16`), deliberately, so that server-side `web_search` can
run under `tool_choice = auto` — and `web_search` defaults to on
(`config.lua:193`), so *every* define turn is unforced.

`auto` means "call a tool if you need one." `"what's in current repo"` is
unanswerable without a tool, so `auto` suffices there. A definition has an
excellent prose answer, so `auto` lets the model take it — and it did, on two
different models. The system prompt *asks*; nothing *enforces*.
`render_definition` (`init.lua:1731-1744`) then discards the prose and warns.

**`define` is the only forcing-eligible skill that does not force:**

| skill | `force_tool` |
|---|---|
| `review` | `"propose_edits"` — `skills/review/init.lua:500` |
| `voice_apply` | `"propose_edits"` — `skills/voice_apply/init.lua:31` |
| `define` | *none* |
