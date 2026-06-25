---
id: 000135
status: open
deps: [ariadne#122]
github_issue:
created: 2026-06-25
updated: 2026-06-25
estimate_hours:
---

# Consume the generated issue vocabulary (issue.json) — drive issue-creation status + frontmatter typeahead from the model, not a hardcoded Lua enum

## Problem

parley.nvim hardcodes its own status enum + status-cycle in Lua (parley#32) and handles
issue frontmatter with its own knowledge of the fields — a **shadow** of the issue model,
the exact duplication ariadne#122's vocabulary layer exists to delete. #122 ships the
generated `issue.json` (the Go side already derives from it; JSON is the cross-language
lingua franca), but parley still hardcodes — so for parley, `issue.cue` is just-documentation
it doesn't derive from. This is the **second consumer** of #122's per-language binding
model (Lua, the *runtime-read* form): parley reads `issue.json` and derives its status set,
typeahead, and cycle from it.

## Spec

parley consumes the generated issue vocabulary (`issue.json`) at startup
(`vim.json.decode`) into a vocab table, and drives from the model — deleting the hardcoded
Lua enum (the shadow):

- **Issue-creation flow** (`<C-y>c`): status options come from `categories` (open / active
  / terminal), not a Lua literal.
- **Frontmatter typeahead/autocomplete**: `status` (and other enumerable fields) complete
  from the model.
- **Status cycle**: the legal next-states come from the lifecycle `transitions` (so the
  cycle honors the same graph sdlc enforces), not a hardcoded order.
- **Artifact delivery**: parley is a descendant of ariadne, so it gets ariadne's generated
  vocabulary via the layer graph — resolve the `issue.json` path (runtimepath / the
  generated tree) at startup; runtime-read form per the binding model.
- **Conformance**: a Lua test that fails if parley doesn't cover the model's status domain
  (the fail-closed check for this consumer).

## Done when

- parley's create-flow status options, frontmatter typeahead, and status cycle all derive
  from `issue.json` — the hardcoded Lua status enum is **deleted**, not paralleled.
- Adding a status to `issue.cue` (regenerated) surfaces in parley with **no Lua edit**.
- A Lua conformance test goes red if parley fails to cover the model's statuses.

## Plan

- [ ] Design at start-plan: how `issue.json` reaches parley (path resolution); the vocab-loader shape; which UI surfaces rewire
- [ ] vocab loader: read + decode `issue.json` at startup into a table
- [ ] Rewire create-flow + frontmatter typeahead + status-cycle to the loader; delete the hardcoded enum
- [ ] Lua conformance test (covers the model's domain); verify a model change propagates with no Lua edit

## Log

### 2026-06-25

- Filed (in parley.nvim, where the work lands) as ariadne#122's deferred cross-repo
  consumer — the Lua half of "compiled to consumers" / the per-language binding model's
  second language. `deps: ariadne#122` (needs the generated `issue.json`).
