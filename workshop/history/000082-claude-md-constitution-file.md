---
id: 000082
status: punt
deps: [000081]
created: 2026-04-08
updated: 2026-05-05
---

# CLAUDE.md style constitution file

Parent: [issue 000081](./000081-support-anthropic-tool-use-protocol.md)

A persistent "constitution" file (spiritual sibling of Claude Code's `CLAUDE.md`) that sets up how parley's personal-assistant agent should behave across sessions. Content is injected into the system prompt (or referenced via tool-use so the agent can update it itself).

Depends on #81 (tool use protocol) so the assistant can edit the file via tool calls rather than manual editing.

## Done when

- (TBD — brainstorm after #81 lands)

## Plan

- [ ] Brainstorm after #81 is complete

## Log

### 2026-04-08

- Split out from original issue #81

### 2026-05-05

- Punted. #81's tool-use loop unlocks this technically, but the harness side
  of parley is still experimental and the user isn't yet committed to pushing
  parley further toward a full agent harness. Revisit once that direction
  firms up. Brainstorm notes from this session for future-us:
  - Two distinct flavors confused in the original framing — global "personal
    assistant identity" file vs. per-project "this repo's conventions" file.
    Layered (project on top of global) is the only design that doesn't paint
    us into a corner.
  - Post-#81, the elegant mechanism is a tiny system-prompt pointer + agent
    reads `AGENTS.md` via `read_file` at session start. Keeps content
    visible in the buffer (transcript-as-state, #84-friendly), lets the user
    see which version was loaded, and `edit_file` gives self-update for free.
  - Name `AGENTS.md` (industry convergence; parley already uses it at the
    dev-of-parley layer — same convention at two levels).
  - Compose-with-#83 question: is the constitution a skill that's
    auto-loaded, or a separate concept? Lean separate — different lifetime,
    different discovery — but worth deciding before either lands.
