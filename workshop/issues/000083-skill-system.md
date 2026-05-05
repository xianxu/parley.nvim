---
id: 000083
status: punt
deps: [000081, 000082]
created: 2026-04-08
updated: 2026-05-05
---

# skill system (folder of markdown pulled on demand)

Parent: [issue 000081](./000081-support-anthropic-tool-use-protocol.md)

A skill system similar in spirit to Claude Code skills: a folder of markdown files, each with a short description, that the agent can discover and pull into context on demand for specific task types.

Depends on #81 (tool use) for the discovery/read mechanism and #82 (constitution) for the place to document the skill system entry point.

## Done when

- (TBD — brainstorm after #81 and #82)

## Plan

- [ ] Brainstorm after dependencies land

## Log

### 2026-04-08

- Split out from original issue #81

### 2026-05-05

- Punted alongside #82. Both unlock technically post-#81, but parley's
  harness direction is still experimental and the user isn't ready to
  commit to a full agent harness. Revisit if/when that firms up.
