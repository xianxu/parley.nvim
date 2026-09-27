---
id: 000221
status: open
created: 2026-09-07
updated: 2026-09-07
estimate_hours:
github_issue:
---

# Tool discoverability: @all should mean @all public

## Problem

`emit_definition` is the define feature's **output channel** — the model calls it
to deliver `{term, definition}`, its handler is a deliberate no-op, and
`render_definition` (`init.lua:1863-1867`) reads the answer out of the call's
*arguments*. It is not a capability.

But it is registered in `BUILTIN_NAMES` (`tools/init.lua:167`), so `@all` picks
it up — and the only agent parley ships, `ToolOpus*`, declares
`tools = { "@all" }` (`config.lua:226`). So every chat advertises it, described
to the model as *"Return a concise definition of the selected term… Call this
exactly once with your answer."*

Found by the operator while smoke-testing #214: a branched child seeded with
`<M-q>` quotes reading "what's this" is a definition-shaped question, and the
model obliged. Outside `define`, nothing reads the arguments — the handler
returns `""`, the tool loop feeds that back, and the model answers again in
text. The cost is a wasted round-trip, a spurious `🔧:`/`📎:` pair in the
transcript, and an answer that arrives a hop late. Not data loss (I checked
before claiming it), but noise in the artifact the user is trying to read.

The instance is `emit_definition`. **The class is that a wildcard selector
offers every registered tool, including ones that belong to one feature.**
