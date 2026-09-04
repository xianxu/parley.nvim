---
id: 000215
status: working
deps: []
github_issue:
created: 2026-09-04
updated: 2026-09-04
estimate_hours: 2.23
started: 2026-09-04T15:29:51-07:00
---

# Skills resolve an arbitrary agent instead of the current chat's

## Problem

Surfaced in the #206 release shakedown: visual-select + `<M-CR>` (the `define`
skill) does not use the model the transcript is using.

The site is `define`, but the **class is every skill** — `define`, `review`,
`voice_apply`, and any disk-discovered skill resolve their agent through the one
cascade in `skill_assembly.resolve_agent` (`skill_assembly.lua:66-109`), whose
single call site is `skill_invoke.lua:196`. Fixing `define` alone leaves the same
defect under the other three (ARCH-PURPOSE).

### Mechanics

`get_agent` (`init.lua:4405-4451`) **never returns nil**. An unknown name warns
and falls back to `M._state.agent` (the `<C-g>a` selection); it only `error()`s
when the roster is empty:

```lua
local fallback = M.agents[M._state.agent] and M._state.agent or M._agents[1]
```

`config.skill_agent` / `config.review_agent` default to `"Claude-Sonnet"`
(`config.lua:385,390`), which is absent from the shipped roster — that roster has
exactly one live entry, `ToolOpus*` (`config.lua:202+`; the rest are commented
out). So tier 3 does not fall through. It **always returns an agent**, and that
agent is `M._state.agent`.

Four consequences:

- **C1 — the configured tier is a lie.** Every skill turn logs
  `Agent Claude-Sonnet not found, using <X>` — a warning naming a model the
  product does not ship, on a path the user did not misconfigure.
- **C2 — tier 4 is dead.** The first-tool-capable roster scan
  (`skill_assembly.lua:98-107`) is unreachable whenever the selection is valid,
  which is always: `init.lua:1374-1375` repairs `_state.agent` at startup.
- **C3 — tier 3 skips the tool-capability test that tier 4 applies.** It returns
  `get_agent`'s result unvetted, so a selection with no tool wire reaches a skill
  that requires one (`define` needs `emit_definition`).
- **C4 — the transcript is never consulted.** The resolved agent is the *global*
  selection. A chat whose frontmatter pins `model:` / `provider:`
  (`agent_info.lua:66-87`) is defined by a different model than the one it is
  visibly using. **This is the reported defect.**

## Spec

Retire the dead tier, honor the transcript, and vet every tier.

The cascade becomes:

1. per-skill config override (`config.skills[].agent`) — explicit, wins
2. legacy `review_agent` (review skill only)
3. manifest default (`manifest.agent`)
4. global `skill_agent` config — **now nil by default**, so it fires only when set
5. **current transcript agent** ← new: the selection with the chat's
   `provider:` / `model:` overrides applied
6. first tool-capable agent in roster order (terminal fallback, unchanged)

Every tier that can return an unvetted agent gets the same tool-wire test tier 6
applies (C3), falling through rather than handing a skill an agent that cannot
call its tool.

**Header merge reuses `agent_info.resolve` (ARCH-DRY).** That function
(`agent_info.lua:14-140`, reached via `p.get_agent_info`, `init.lua:4548`)
already performs the `model:` JSON decode and the string-to-table coercion that
`prepare_payload` depends on (`skill_invoke.lua:208`); hand-rolling the merge
would risk a model-shape mismatch at the wire. The IO seam calls it and then
takes **only `provider` + `model`** onto a copy of the agent record — the chat's
`system_prompt` and memory-pref folding are deliberately discarded, because a
skill owns its system prompt via `source(ctx)`.

**Purity (ARCH-PURE):** `resolve_agent` stays pure. `skill_invoke` computes the
transcript agent and injects it as `deps.current_agent`; the resolver only
tool-capability-tests and picks.

**Degradation:** a non-chat buffer (review/voice_apply on plain markdown) has no
headers, so tier 5 is the bare selection. Malformed frontmatter degrades as
`agent_info.resolve` already defines it — a `model:` that fails JSON decode warns
and passes the raw string through; a `provider:` naming a wireless provider fails
the tier-5 capability test and falls to tier 6.

## Done when

- a chat whose frontmatter pins `model:` / `provider:` drives `define`, `review`
  and `voice_apply` with that pair
- no skill turn logs `Agent Claude-Sonnet not found` on a default install
- an agent lacking a tool wire never reaches a skill, from any tier
- the chat's `system_prompt` does not leak into the skill turn
- malformed `model:` JSON and a wireless `provider:` both degrade without error
- `resolve_agent` remains pure — driven through injected `deps` in tests

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim         design=1.2  impl=0.4
item: atlas-docs         design=0.05 impl=0.05
item: milestone-review   design=0.0  impl=0.15
design-buffer: 0.30
total: 2.23
```

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only.* `sdlc estimate-source` reports the calibration
doc as **stale** (newer ledger; recalibration tracked in ariadne#127), so the
per-primitive hours are provisional.

Derivation notes:

- **`lua-neovim` design=1.2** — bottom of the v2 range (1–3). The cascade change
  is one focused feature in a module I have now read end-to-end, and the design
  is settled: the spec cleared plan-quality CLEAN with the judge verifying the
  mechanics independently. Picking the low end is where the dense-spec credit is
  taken, so the v2.1 buffer-halving rule of thumb is deliberately **not** also
  applied — that would double-count the same discount.
- **impl values are already scaled** to 40% of the v2/v2.1 table per v3.1: mid
  of `lua-neovim` 0.5–1.5 → 0.4; `atlas-docs` 0.1 → 0.05; `milestone-review`
  mid 0.35 → 0.15. Tests are inside the primitive, not a separate item.
- **design-buffer 0.30** — the v2 default, not the v3.1 +15%. That reduction is
  conditioned on a thorough *plan doc*; #215's design lives in the issue's own
  Spec with no separate `workshop/plans/` artifact, so the discount isn't
  cleanly earned.
- **`atlas-docs`** covers the two files that hand-restate the cascade
  (`atlas/skills/skill-system.md:97`, `atlas/modes/review.md:195`).
- **`milestone-review` ×1** — single-pass atomic work, so one boundary: the
  mandatory review at `sdlc close`.

## Plan

- [x] Correct the `get_agent` test double in `tests/unit/skill_assembly_spec.lua:68-72`
      to match production: never nil, unknown name falls back to the selection.
      The current strict-lookup double would pass green over the real behavior
- [x] Failing unit tests: tier 5 fires and applies header overrides; explicit
      `skill_agent` still outranks it; a wireless agent falls through from every
      tier
- [x] Add the `deps.current_agent` tier + the per-tier capability test to
      `skill_assembly.resolve_agent`
- [x] Compute `current_agent` at the `skill_invoke` seam via `agent_info.resolve`,
      taking provider+model only
- [x] Nil the `"Claude-Sonnet"` defaults for `skill_agent` / `review_agent`
- [x] Integration coverage in `tests/integration/define_spec.lua`: header-override
      path + malformed-frontmatter degradation
- [x] Update `atlas/skills/skill-system.md:97` and `atlas/modes/review.md:195` —
      both hand-restate the cascade and the default this issue changes
- [x] Full suite green

## Log

### 2026-09-04

Filed from the #206 shipping-surface shakedown (see
`workshop/projects/parley-v1-release.md`). Operator walked the Tier 1 inventory
and hit this on item 5 (inline term definition).

Scoped to the shared cascade rather than to `define` per ARCH-PURPOSE — one
resolver, four consumers.

## Revisions

### 2026-09-04 — root cause corrected at the plan-quality gate

`change-code`'s plan-quality judge rejected the first spec (1 Critical, 2
Important). The original Problem claimed two causes: that tier 3 "silently falls
through" because `get_agent` returns nil on an unknown name, and that the
arbitrary tier-4 roster scan was therefore the only tier that ever fired.

**Both were wrong.** `get_agent` never returns nil — it warns and falls back to
`M._state.agent`. So tier 3 always resolves, tier 4 is unreachable, and the
originally proposed tier (inserted *below* `skill_agent`) would have been a
**no-op**. The gate caught a fix that would have changed nothing.

Delta:
- Problem rewritten around the real mechanics; the four consequences C1-C4
  replace the two false causes. The reported defect is C4 (transcript ignored),
  not roster arbitrariness.
- Nilling the stale default is promoted from cleanup to **load-bearing**: while
  `skill_agent` is set, tier 5 is unreachable.
- C3 added — tier 3 returns an agent without the tool-wire test tier 4 applies.
  Not in the original spec; found while re-reading the cascade.
- ARCH-DRY: header merge now explicitly reuses `agent_info.resolve` rather than
  hand-rolling the JSON decode + string coercion.
- Plan step added to fix the `get_agent` test double, which modelled a strict
  lookup — the inverse of production, so the planned tests would have passed
  green over the behavior they were meant to guard.
- Plan step added for the two atlas files that hand-restate the cascade.

### 2026-09-04 — implemented

Commit `3d70331`. Full suite green: **193 spec files, 0 failures**, verified
against `make`'s own exit status (a first run reported green through a
`| tail -25` pipe, which returns *tail's* status — the pipeline hid whether
`make` had failed at all).

**The plan's first step found a second member of its own class.** Correcting the
`get_agent` double to production semantics passed immediately; enforcing
capability at every tier then broke **6 existing tier assertions**, because the
fixture agents were bare `{ name = "A1" }` with no provider, so `wire.resolve`
rejected them. Same defect as the double — a stub shaped like nothing
`init.lua:4405-4451` can build — in a second form the gate's finding did not
name. Fixed by giving the fixtures providers, not by weakening the predicate:
the tests were wrong, the code was right.

**Atlas had nothing to correct, only something missing.** `resolve_agent` was
referenced in three places but the cascade order was documented nowhere. Added
an "Agent resolution cascade" section recording the tier order, the
capability-at-every-tier rule, and the two traps that cost two plan rounds here
(`get_agent` never returns nil; tier 5 is unreachable while `skill_agent` is
set).

**Behavior change worth flagging beyond the reported bug:** an explicitly
configured but wireless agent now falls through instead of being returned. The
approved Spec committed to this, and a skill cannot work without its tool — but
a misconfigured `skill_agent` now fails quietly rather than loudly.

**Not fixed here:** this does NOT make `define` work. The reported symptom was
#216 (model skips `emit_definition` under `tool_choice: auto`); #215 removes the
spurious warning, honors the transcript, and closes the unvetted-agent hole.
