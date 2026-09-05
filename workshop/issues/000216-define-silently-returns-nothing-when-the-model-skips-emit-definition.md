---
id: 000216
status: open
deps: []
github_issue:
created: 2026-09-04
updated: 2026-09-04
estimate_hours:
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

## Spec

Set `force_tool = "emit_definition"` on the define manifest. The machinery is
already end-to-end and needs no new code:

```
manifest.force_tool = "emit_definition"        -- a NAME, wire-agnostic
  → build_invocation → inv.force_tool           -- skill_assembly.lua:52
  → skill_invoke.lua:214-217
       payload.tool_choice = wire.encode_tool_choice(provider, model, name)
  → anthropic: {type="tool", name="emit_definition"}
    openai:    {type="function", function={name="emit_definition"}}
```

`tool_choice` is a decode-time constraint, not an instruction: the response is
shaped so the first content block must be that `tool_use`. There is no
text-only path left, which is exactly what the prompt could not achieve.

**Accepted consequence:** with `tool_choice` pinned, server-side `web_search`
cannot run on a define turn. That capability is what cost the guarantee, and the
reported failure was on «renaissance» — a term needing no search at all.

**Not fixed here, recorded deliberately:**

- **Forced `tool_choice` returns 400 on Claude Fable 5.1 / Mythos 5.1**
  (`tool_choice: type "tool" and "any" are not supported for this model`).
  parley is vendor-neutral — any Fable-family agent picked via `<C-g>a` would
  fail. `review` and `voice_apply` **already carry this exposure today**. The fix
  belongs in the wire once, not in three manifests → separate issue.
- `web_search_20260209` runs code execution under the hood, and programmatic tool
  calling is documented as incompatible with forced `tool_choice`. Whether
  declaring both trips a 400 is **unverified** and needs one live request.
- Forcing does not remove `web_search`/`web_fetch` from the payload — they are
  injected off the global `parley._state.web_search` (`providers.lua:608`), so
  they ship as unreachable dead weight. No per-skill opt-out seam exists today.

**Second defect, same failure signature.** `dispatcher.lua:142-147` stamps
`payload._parley_tool_wire` precisely because re-deriving the decoder from
provider+model "would lose an agent's `anthropic_tools_route` override and pick
the wrong decoder." The chat path honors that stamp (`dispatcher.lua:348`);
`skill_invoke.lua:272` **ignores it and re-derives**. It resolves correctly for
the reporting config, so it is not the reported bug — but it fails silently as
"model returned no tool call", i.e. indistinguishable from this issue. Same
class, same function, fixed here.

## Done when

- define returns a definition on `claude-opus-5` and `claude-sonnet-5`
- «renaissance» (needs no search) is covered as a regression case
- `skill_invoke` decodes with the stamped wire, not a re-derivation
- the Fable-400 exposure is filed rather than silently shipped
- the atlas no longer documents the unforced rationale as current

## Plan

- [ ] Failing tests: define's manifest carries `force_tool`; `skill_invoke`
      encodes `tool_choice` in both wire spellings
- [ ] Set `force_tool = "emit_definition"` and rewrite the manifest comment —
      it currently documents the opposite decision as deliberate
- [ ] Use `qt.tool_wire` in `skill_invoke.lua:272` instead of re-deriving
- [ ] Live check on opus-5 and sonnet-5, including whether
      `web_search_20260209` + forced `tool_choice` returns 400
- [ ] File the Fable-5.1/Mythos-5.1 forced-`tool_choice` wire issue
- [ ] Update `atlas/chat/inline_define.md:38-39` and `:177`, which both state the
      unforced rationale
- [ ] Full suite green

## Log

### 2026-09-04

Filed from the #206 shakedown. Diagnosis took three wrong turns before the log
settled it, all recorded above as the ruled-out table so they are not re-tried:
agent resolution (that is #215, unrelated to this failure), a suspected
clobber of `payload.tools` by `format_payload` (there is none — the dispatcher
appends), and truncation (the cap is correctly raised).

The operator's `"what's in current repo"` test is what converted this from
theory to diagnosis: it holds every variable constant except whether a tool call
was the *only* way to answer. That is the whole bug.
