---
id: '000215'
status: done
started: 2026-09-04T15:29:51-07:00
created: 2026-09-04
updated: 2026-09-05
estimate_hours: 2.23
actual_hours: 1.67
---

# Skills resolve an arbitrary agent instead of the current chat's

## Problem

Surfaced in the #206 release shakedown: visual-select + `<M-CR>` (the `define`
skill) does not use the model the transcript is using.

The site is `define`, but the **class is every skill** — `define`, `review`,
`voice_apply`, and any disk-discovered skill resolve their agent through the one
cascade in `skill_assembly.resolve_agent` (`skill_assembly.lua:66-109`), whose
single call site is `skill_invoke.lua:196`. Fixing `define` alone leaves the same
defect under the other three (ARCH-PURPOSE).

### Mechanics

`get_agent` (`init.lua:4405-4451`) **never returns nil**. An unknown name warns
and falls back to `M._state.agent` (the `<C-g>a` selection); it only `error()`s
when the roster is empty:

```lua
local fallback = M.agents[M._state.agent] and M._state.agent or M._agents[1]
```

`config.skill_agent` / `config.review_agent` default to `"Claude-Sonnet"`
(`config.lua:385,390`), which is absent from the shipped roster — that roster has
exactly one live entry, `ToolOpus*` (`config.lua:202+`; the rest are commented
out). So tier 3 does not fall through. It **always returns an agent**, and that
agent is `M._state.agent`.

Four consequences:

- **C1 — the configured tier is a lie.** Every skill turn logs
  `Agent Claude-Sonnet not found, using <X>` — a warning naming a model the
  product does not ship, on a path the user did not misconfigure.
- **C2 — tier 4 is dead.** The first-tool-capable roster scan
  (`skill_assembly.lua:98-107`) is unreachable whenever the selection is valid,
  which is always: `init.lua:1374-1375` repairs `_state.agent` at startup.
- **C3 — tier 3 skips the tool-capability test that tier 4 applies.** It returns
  `get_agent`'s result unvetted, so a selection with no tool wire reaches a skill
  that requires one (`define` needs `emit_definition`).
- **C4 — the transcript is never consulted.** The resolved agent is the *global*
  selection. A chat whose frontmatter pins `model:` / `provider:`
  (`agent_info.lua:66-87`) is defined by a different model than the one it is
  visibly using. **This is the reported defect.**
