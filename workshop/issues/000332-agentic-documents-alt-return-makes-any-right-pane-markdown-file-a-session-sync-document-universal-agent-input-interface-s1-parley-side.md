---
id: 000332
status: working
deps: []
github_issue:
created: 2026-10-15
updated: 2026-10-15
estimate_hours: 5.9075
card_mirror: 'b189f5b9f50fdc780dec47c23145916f7413ce35' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-15T13:07:57-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: full, provenance: operator}
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
| Cross-editor operation lease | INTEGRATION | lua/parley/document_lease.lua | new |
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

- Verified TL design approval f96cd3f0-f712-4ed6-917f-eb348dc75b8c (submitted): approves the full draft with editable unknown/cache policy, durable rename journal and save→register→submit. Source inspection resolves queued pair questions: Register imports typed legacy state/shadow/path history; rename requires an existing registration, so typed OLD must be registered before native move. COUCH_ISOLATED_ROOT and an isolated adopt-store preview/apply are required for standalone CLI conformance; HOME/XDG alone do not isolate the OS-account singleton. Candidate CLI execution remains pending; no installed-binary/live claim is made.

- Plan-quality round1 raised PQ-1 cross-editor migration ownership, PQ-2 test-strategy inventories, and Minor PQ-3 cleanup coverage. Refined the whole ownership/cleanup class: per-ID POSIX kernel lease spans execution/recovery, exact pending tuples cannot be replaced, process death releases ownership, retired inode acquisition is revalidated, and only lease-owned manifested temps are cleaned. A local runtime probe confirmed LuaJIT FFI exports flock; unsupported platforms refuse unsafe migration while ordinary editing remains available. Test plan is now one strategy per risky function, with real two-editor ordering and native triggers.

- Plan-quality round2 returned CLEAN: PQ-1/PQ-2/PQ-3 all addressed, no new findings. Gate now asks for the estimate, so derive against v3.1/baseline-v3.1 after the design has cleared; no implementation yet.

## Revisions

- 2026-10-15 — spell out agreed registry boundary and native rename/recovery work in the durable plan without changing the original S1 purpose. Explicit couch-owner is a route override per this issue, superseding #316 refusal only where that new requirement applies. Pending admission-failure policy requires TL review.

- 2026-10-15 — replace the draft read-only admission proposal with the TL-approved editable unknown state, local known-agentic cache and recovery reconciliation. This resolves the failure-policy question; plan review and pair legacy-adoption/isolation details remain pending.

- 2026-10-15 — freeze callable boundaries and legacy/native-rename preflight from primary source; adopt the explicit temporary singleton setup for future conformance. Full design approved, ready for change-code plan-quality admission; estimate remains unset until it passes.

- 2026-10-15 — PQ-1/PQ-2/PQ-3 refinement adds explicit cross-editor ownership and cleanup, and compresses test case prose into function strategies. Retains the approved purpose and editable offline policy.

## Estimate

Produced via brain/data/life/42shots/velocity/estimate-logic-v3.1.md against baseline-v3.1.md. Method A only. Calibration source is marked stale, so figures remain provisional.

The now-admitted plan decomposes into four focused Lua/Neovim concerns (pure lifecycle/replies, admission/edit-turn integration, filesystem migration, and native lease; the registry transport/fake/conformance is the API-integration primitive), one shared-writer/transport refactor, docs and one close review. Tests belong to each component, not an extra duplicate testing primitive. The real-API discovery item owns active isolated singleton bootstrap/CLI inspection only; the API-integration item owns the actual driver/fake implementation. Idle dependency/operator/machine-gate waits are excluded from the estimate.

Raw table selections and discounts: lifecycle Lua1.5/1; registry API2/1.5; admission Lua3/1.5; migration Lua3/1.5; lease Lua1.5/1; refactor0.6/0.5; docs0.2/0.2; review0.2/0.5; API-discovery0/0.6 (design/implementation hours). Apply design×0.2 for the thorough approved/gate-cleared design. For the bounded native lease, the current kernel flock facility short-circuits hand-built ownership/recovery (library availability design×0.5 before spec discount); its symbol was probed locally. Existing Neovim/libuv helpers and the shared writer cover other concerns without new dependencies. Familiar current stack×1.0; v3.1 implementation×0.4; design buffer+15%.

Design subtotal2.25 + buffer0.3375 + implementation3.32 =5.9075h.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.3 impl=0.4
item: api-integration design=0.4 impl=0.6
item: lua-neovim design=0.6 impl=0.6
item: lua-neovim design=0.6 impl=0.6
item: lua-neovim design=0.15 impl=0.4
item: cross-cutting-refactor design=0.12 impl=0.2
item: atlas-docs design=0.04 impl=0.08
item: milestone-review design=0.04 impl=0.2
item: real-api-discovery design=0 impl=0.24
design-buffer: 0.15
total: 5.9075
```
