---
id: 000383
status: working
deps: [pair#661]
github_issue:
created: 2026-10-18
updated: 2026-10-18
estimate_hours: 2.16
collaboration-mode: collaboration
card_mirror: '466d2b4d1e82d1844778354d535e37881a3f063e' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-18T00:03:53-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: full, provenance: operator}
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

- Under the default presentation, an agent `apply` round shows each edit highlighted with its reason, and a `write` round shows its changed lines highlighted ("changed by the agent").
- The highlights follow the operator's edits, clear on the next confirmed submit, and stay cleared on reopen.
- Under `presentation: propose` the same request shows per-line accept/reject markers, and a large rewrite shows as a followable `→ [proposal]` link.
- `direct` draws nothing.
- Specs against the Couch fake cover the behavior, plus a live check on a real document.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim           design=0.3 impl=0.4
item: lua-neovim           design=0.3 impl=0.4
item: smaller-go-module    design=0.05 impl=0.15
item: real-api-discovery   design=0.0 impl=0.2
item: atlas-docs           design=0.05 impl=0.05
item: milestone-review     design=0.0 impl=0.15
design-buffer: 0.15
total: 2.16
```

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against `baseline-v3.1.md`. Method A only.* The calibration doc is tagged stale, so treat the numbers as provisional. The two `lua-neovim` items are pure `presentation` with its drawing, and `edit_round` with the session_sync hooks. Their design is v2's 1–3h at the ×0.2 spec discount, since the plan pre-resolves the decisions, and their impl is 40% of 0.5–1.5h. `smaller-go-module` is the closest slug for the Python fake's round verb. `real-api-discovery` is the conformance case against the real M1 binary. The design buffer is +15% because a thorough durable plan exists.

## Plan

Durable plan: [workshop/plans/000383-s4-presentations-plan.md](../plans/000383-s4-presentations-plan.md). Coding waits for pair#661 M1 (the hub, 10-18).

- [ ] Task 1: the Couch fake keeps a round (`round --json`, `--round` seed, `Cleared` after a submit)
- [ ] Task 2: `presentation` (pure): the key, and a round's spans placed or re-anchored
- [ ] Task 3: `skill_render.publish_round` / `clear_round`, a round kind beside footnotes
- [ ] Task 4: `edit_round` + `document_registry.request("round")`, generation-guarded
- [ ] Task 5: hooks: reload, attach, confirmed submit (`release_and_send`)
- [ ] Task 6: the `→ [proposal]` link spec, the real/fake conformance case, atlas, suite, live check

## Log

### 2026-10-18

- Claimed and started plan-only (hub, 10-18): code waits for pair#661 M1 to land, so nothing builds against an unlanded Couch verb. The fake's round shape follows the design's sidecar; the plan names it as an assumption to confirm against M1 before Task 1.
- Design choices: round diagnostics share skill_render's diagnostic namespace as a separate kind, as footnotes do, because `clear_decorations` would wipe footnotes on submit. The fetch reuses document_registry's bounded client (ARCH-DRY). A generation counter is the single guard against a stale reply (ARCH-concurrency). Clearing happens at `release_and_send`'s confirmed branch, the one send path for legacy and registered documents.
- pair#661 M1 landed (PR 426, merge f8b82353); the hub started #383. Checked the real verb against the plan's contract, using a couch built from pair main in scratch (not installed). sessionsync/round.go's `Round{base_hash, result_hash, at, presentation, spans:[{start, end, old, new, explain?}]}` gives positions in the result as 0-based [line, byte column], and a deletion has Start == End. couchcmd's `roundResponse{Code, Error, Round, Cleared}` and decodeRound's round-invalid cases all match the plan, so the fake shape stands as written. The hub noted two M1 details, and neither changes parley's side: propose-unencodable joins propose-too-large, and both refusals send the agent to a side-doc proposal, which parley sees only as the `→ [proposal]` link Task 6 covers. Under propose, a frontmatter change goes through `write --frontmatter`, an agent-side verb.
