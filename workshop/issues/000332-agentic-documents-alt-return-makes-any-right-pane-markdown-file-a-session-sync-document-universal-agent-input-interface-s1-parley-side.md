---
id: 000332
status: working
deps: []
github_issue:
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
card_mirror: '9c4468c4ed58c358c791426f4cbb92cc8524f424' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-15T13:07:57-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# Agentic documents: Alt+Return makes any right-pane markdown file a session-sync document (universal-agent-input-interface S1, parley side)

## Problem

Project universal-agent-input-interface (ops `teams/devinfra/projects/universal-agent-input-interface/`, design in
`design.md`, slice S1): today only files with `type: session-sync` get the operator lock, Alt+Return submit and the
red winbar. The operator wants any markdown file opened in Couch's right-pane nvim to become an **agentic document**
at its first Alt+Return.

## Spec

- Any markdown buffer in the right-pane nvim (detected from the pane's pair environment) can be submitted with
  Alt+Return. The first submit registers the file as agentic with Couch (Couch-side registry keyed by canonical path;
  nothing is written into the file) and sends it to **the pane's own slot** ("the agent on the left"). An explicit
  `couch-owner:` in the frontmatter, if present, still wins.
- From then on the existing session-sync behaviour applies unchanged: operator lock on the first edit (parley#324),
  undo-to-baseline release (#330), the red winbar while the operator holds the lock, the band, owed pings.
- A file that was never submitted stays plain nvim: no lock, no band.
- Renaming or moving an agentic file keeps it agentic (registry follows the path) and renames its `<name>.side/`
  folder (S3 relies on this).

## Done when

- A plain note in the right pane, after one Alt+Return, is locked on the next edit (red winbar), an agent write is
  refused while it's held, and the submit reaches the pane's slot.
- A never-submitted file shows no lock or band.
- Headless tests with the real auto-save setup (as in #324) cover first submit, lock, rename, and an explicit
  `couch-owner:` override. Depends on the pair (Couch) S1 issue for the registry verbs.

## Core concepts

| Entity | Kind | Location | Status |
|---|---|---|---|
| Document lifecycle/reply model | PURE | lua/parley/document_session.lua | new |
| Migration/backlink projection | PURE | lua/parley/document_move_plan.lua | new |
| Registry transport/client | INTEGRATION | lua/parley/couch.lua, lua/parley/document_registry.lua | modified/new |
| Buffer admission and file migration | INTEGRATION | lua/parley/agentic_document.lua, lua/parley/document_move.lua | new |
| Existing turn engine | INTEGRATION | lua/parley/session_sync.lua | modified |
| Atomic byte writer | INTEGRATION | lua/parley/helper.lua | modified |
| Stateful registry fake | INTEGRATION | tests/helpers/fake_couch.lua | modified |

## Plan

Durable plan: [Agentic Markdown Documents](../plans/000332-agentic-documents-plan.md).

- [ ] Add the pure lifecycle/reply model, shared transport, typed registry client and stateful fake with red/green coverage.
- [ ] Integrate first-submit/reopen admission with the existing native edit-turn engine and real Alt+Return routing.
- [ ] Preserve document identity, side folder/backlinks and operator turn through native/Parley renames and partial failures.
- [ ] Add isolated real/fake conformance, docs/traceability and required checks; close on SHIP, then stage for the combined live check before landing.

## Log

### 2026-10-15

- Read the approved ops S1 project/design and the frozen pair#573 caller contract. #327 landed and its stage cleared before claiming/starting this branch; no stacked work. Used brainstorming/writing-plans and read-only bounded scouts; no production code or tests changed.
- Contract agreed with pair:5: capitalized envelope/effective Registration+Changed, null-only absence, nonzero/invalid envelope as unavailable, metadata-only rename after caller filesystem effects, stable ID and exact-argument uncertain retry. Pair public verbs/full review were still pending at the last peer report.
- Exploration found legacy couch.query erases explicit-null key presence, and session_sync disk/lock paths change immediately with buffer name while loaded/baseline/callback observations do not. Native temporary probe confirmed saveas emits paired buffer-name events before destination creation; destination exists only after BufWritePost. Plan owns both classes explicitly (ARCH-DRY/ARCH-ORDER).
- Asked hub to settle safe unknown-lookup editing policy and pair to clarify legacy typed-state adoption plus supported isolated real CLI conformance. These remain plan inputs; no change-code/estimate/implementation yet.

- TL settled availability policy (verified submitted a70bb84a-9070-4d6b-a505-60f22af1a603): never block operator editing on unreachable Couch. Keep full protection for known/cached agentic paths; unknown/unavailable is editable with a one-line band and bounded re-lookup. Couch is the exclusive agent CAS writer, so down means no concurrent agent writes. Plan revised to include bounded local knowledge and preserve unknown-period edit baselines through auto-save. Durable forward-only rename recovery approved.

## Revisions

- 2026-10-15 — spell out agreed registry boundary and native rename/recovery work in the durable plan without changing the original S1 purpose. Explicit couch-owner is a route override per this issue, superseding #316 refusal only where that new requirement applies. Pending admission-failure policy requires TL review.

- 2026-10-15 — replace the draft read-only admission proposal with the TL-approved editable unknown state, local known-agentic cache and recovery reconciliation. This resolves the failure-policy question; plan review and pair legacy-adoption/isolation details remain pending.
