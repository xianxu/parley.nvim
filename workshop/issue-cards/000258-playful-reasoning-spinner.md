---
id: 000258
status: open
created: 2026-09-15
updated: 2026-09-15
estimate_hours:
github_issue:
---

# Show playful spinner during reasoning status

## Problem

When a provider reports reasoning progress, the chat status switches to the
literal `Reasoning...`/`Reasoning: ...` message. Reasoning can take a long time,
so this loses the playful animated waiting language already used before the
first response bytes (`Cooking`, `Brewing`, and similar verbs). The static
reasoning label makes a normal wait look stuck.
