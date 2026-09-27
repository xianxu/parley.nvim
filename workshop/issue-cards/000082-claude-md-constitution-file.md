---
id: '000082'
status: punt
created: 2026-04-08
updated: 2026-05-05
---

# CLAUDE.md style constitution file

## Problem

Parent: [issue 000081](./000081-support-anthropic-tool-use-protocol.md)

A persistent "constitution" file (spiritual sibling of Claude Code's `CLAUDE.md`) that sets up how parley's personal-assistant agent should behave across sessions. Content is injected into the system prompt (or referenced via tool-use so the agent can update it itself).

Depends on #81 (tool use protocol) so the assistant can edit the file via tool calls rather than manual editing.
