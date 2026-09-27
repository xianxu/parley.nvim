---
id: 000129
status: open
created: 2026-06-11
updated: 2026-06-11
estimate_hours:
github_issue:
---

# Capability-based tool permission model for skills

## Problem

Today tools are controlled per **agent definition** (e.g. `ToolSonnet` carries
write tools, plain `Sonnet` doesn't). Two problems:

1. Even with a write-capable agent, you usually want writes only during a
   *deliberate* skill invocation (e.g. `/review`), not ambiently for the whole
   session. Ambient write authority is a footgun and the source of a
   confused-deputy risk (the LLM can mutate without a human asking).
2. It bloats the agent zoo: `ToolSonnet` vs `Sonnet` exist only to carry
   different tool sets.

The settled model: **knowledge is free; power requires a human act.** The LLM can
*think* like a reviewer on its own initiative, but can only *act* (mutate) when a
human deliberately invoked the skill. The model can never self-escalate its own
permissions. This is the concrete mechanism behind "readonly harness with a
human-gated write middle-tier."

Settled in the brain design conversation 2026-06-11. Builds on the manifest's
`tools`/`elevated` fields from #128.
