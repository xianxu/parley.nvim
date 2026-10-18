---
id: 000383
status: open
deps: [pair#661]
github_issue:
created: 2026-10-18
updated: 2026-10-18
estimate_hours:
collaboration-mode: collaboration
card_mirror: '0c9bfd9d6456457f8f90aac1615dbd8537b34441' # card fields mirrored from issue-cards; edit via sdlc
---

# S4 presentations: highlight agent rounds from Couch's round sidecar, propose and direct

## Problem

Slice 4 of the universal-agent-input-interface project (design: `ops:teams/devinfra/projects/universal-agent-input-interface/design.side/10-s4-edit-path.md`, sections 4, 6 and 8). Once Couch keeps each agent round as a sidecar (pair, M1), parley must show it according to the document's `presentation:`, so the operator sees what the agent changed and why.

## Spec

Design: `ops:teams/devinfra/projects/universal-agent-input-interface/design.side/10-s4-edit-path.md` (operator-reviewed, 2026-10-17). Depends on pair's M1 (`apply`, the derived round, `round --json`).
- **The key:** a frontmatter scalar `presentation:`, one of `direct`, `highlight` or `propose`. Missing or unknown means `highlight`. It is per document; the session file uses `highlight` throughout.
- **On an agent round** (the reload hook, `agentic_document.lua:437`), parley runs `couch --session-sync round FILE --json` asynchronously. Every agent write has a round, `write` included.
  - `direct`: draw nothing.
  - `highlight`, when not `cleared`: each span gets a `DiffChange` extmark and an INFO diagnostic through `skill_render` and `diag_display`. The diagnostic is the span's `explain`, or "changed by the agent" when it has none. A deletion is a zero-width span with `deleted: <old>`. When the file no longer has `result_hash`, re-anchor each span by its `new` text nearest its old position, and skip any span not found.
  - `propose`: the per-line markers are already in the file and today's `<M-a>`/`<M-r>` handle them. A larger rewrite arrives as a `→ [proposal](…)` side-doc link, which Alt+o follows. That side doc is registered and listed in the attention finder like any side doc.
- **Clearing:** a confirmed Alt+Return calls `skill_render.clear_decorations`; a later open draws nothing because Couch reports `cleared`.
- parley never writes the file for this; it only reads the round.
- The Couch fake gains a stateful `round`, covering the derived spans and `cleared` after a recorded submit.

## Done when

On a document under the default presentation, an agent `apply` round shows each edit highlighted with its reason, a `write` round shows its changed lines highlighted ("changed by the agent"), the highlights follow the operator's edits, and they clear on the next confirmed submit and stay cleared on reopen. Under `presentation: propose` the same request shows per-line accept/reject markers, and a large rewrite shows as a followable `→ [proposal]` link. `direct` draws nothing. The behavior is covered by specs against the Couch fake, plus a live check on a real document.

## Plan

- [ ]

## Log

### 2026-10-18
