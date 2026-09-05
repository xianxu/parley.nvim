---
id: 000215
status: codecomplete
deps: []
github_issue:
created: 2026-09-04
updated: 2026-09-04
estimate_hours: 2.23
started: 2026-09-04T15:29:51-07:00
actual_hours: 1.67
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
- 2026-09-04: closed — make test: 193 spec files, 0 failures, MAKE_EXIT=0 (verified against make status, not a pipeline exit). luacheck clean, 346 files. Three boundary rounds, all findings addressed at CLASS level. Round 3 BR-12: both user-visible warnings this diff added live in the shell (skill_invoke), and neither was pinned -- the pure resolvers on_dropped callback had coverage but the logger.warning the user actually sees did not. Enumeration is exactly those two observables; both now tested and verified BY MUTATION, not asserted: demoting the BR-2 warning to debug fails 1, removing on_dropped fails 1, restored fails 0. Round 3 minor fixed: the dropped-agent message named dropped.name, but since get_agent never returns nil a typod skill_agent resolves to the SELECTION, so the warning would have named an agent the user never set; source now carries the configured name. Adequacy for the deliverable itself: 4 tests go red when current_agent is reverted to nil. Lessons recorded in workshop/lessons.md (remove the behaviour and confirm red; re-check open findings after each fix; the enumeration usually lives one level up; a double that returns what production cannot is not a double). NOT verified live against a provider: this is agent RESOLUTION. Operator has separately confirmed define now works on gpt-5.6-luna and claude-opus-5 post-215, though tool_choice remains auto so that is nondeterministic -- tracked as #216, which operator has asked to re-spec around KEEPING web_search rather than forcing the tool.; review verdict: FIX-THEN-SHIP

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

### 2026-09-04 — close review: FIX-THEN-SHIP, 4 Important addressed

Commit `39ae27e`. The boundary review did the check I should have run myself:
it scratch-reverted `current_agent = transcript_agent()` to `nil` — disabling
the entire deliverable — and **all 64 tests still passed**. The plan item
`[x] Integration coverage … header-override path` was ticked for three calls
into the *pure resolver* with hand-built `current_agent` tables; nothing in the
suite touched `find_header_end` / `parse_chat` / `get_agent_info`. ARCH-PURPOSE
at the level of the plan item rather than the feature.

- **I1** — real seam tests: drive `skill_invoke.invoke` against a registered
  chat root, capture `deps.current_agent`. **4 now go red** under that revert.
- **I2** — `logger.warning`, not `debug` (`logger.lua:94-96` never reaches
  `vim.notify`), and the pcall's discarded error object is now in the message.
- **I3** — `parse_header_metadata` instead of `parse_chat`: `parsed.headers` IS
  that call (`chat_parser.lua:258`); 4.84ms → 0.003ms on a keystroke path that
  had already parsed the same buffer once (ARCH-CONSTRAINTS).
- **I4** — `p.not_chat` instead of "buffer contains a `---`". `find_header_end`
  matches the first horizontal rule in any prose, and review/voice_apply run on
  arbitrary markdown, so a document's own frontmatter could steer which vendor
  received it (ARCH-SECURE). Latent — no `workshop/**/*.md` carries `provider:`.

**Two self-inflicted breaks, caught before re-closing.** The first seam test set
`config.chat_dir`, but `not_chat` resolves against the root *manager* — so it
silently exercised the non-chat path while claiming to test headers. And
hoisting `p.get_agent()` out of the pcall for I4 broke **14** `skill_invoke_spec`
tests, since it raises with no agents configured. The pcall now wraps the whole
tier: optional enrichment must never take down a turn that would otherwise work.

Minors cleared: one 1..6 tier scheme across code/tests/atlas/issue (it had
drifted four ways); dead `or selected.*` fallbacks removed; `define_spec` mapped
in `traceability.yaml`. Also fixed a fixture whose comment claimed to exercise
`agent_info.lua:73-85` — `"{bad json"` never matches `{.*}`, so the branch was
never entered; `{bad json}` does, and the log now shows the warning firing.

Deferred to a follow-up, per the review's forward-looking note: `get_agent`'s
never-nil contract is *documented* in three places but not *enforced*. A
`deps.lookup_agent` returning nil on a miss would make tiers 1-4 fall through on
a typo'd name — today a typo yields the selection **without** header overrides,
strictly worse than tier 5's selection **with** them.

### 2026-09-04 — close review round 2: repeat families, both self-inflicted

Commit `14c6200`. Round 2 disposed 8 of 8 prior findings but opened 2 repeat
families — "not converging: fix rules, not instances."

- **BR-3 (`redundant-buffer-reparse`) came back because the BR-4 fix
  reintroduced it.** `p.not_chat` is the right predicate, but it reaches
  `parse_chat_headers`, which ran a **full `parse_chat`** to read four header
  lines. I removed one full parse, added another, and asserted BR-3 was fixed.
  The class fix was never in the seam: `parsed.headers` **is**
  `parse_header_metadata(lines, header_end)` (`chat_parser.lua:258`) and
  `parse_config` is not an input to header parsing — so `parse_chat_headers`
  now calls it directly. Identical output, ~1000× cheaper, and it lands for
  **all 15+ `not_chat` call sites**, not just this diff. The tier is also a
  thunk now, so tiers 1-4 pay nothing.
- **BR-9 is the second member of `debug-level-silent-degrade`**, the family BR-2
  opened — which I had fixed only at the site BR-2 named. The rule covering
  both: *a fallback that overrides something the user asked for explicitly must
  reach them with its reason.* Enumeration = the four **configured** tiers;
  tiers 5-6 stay silent because the transcript is ambient and the roster is
  nobody's instruction. `resolve_agent` stays pure; the shell injects
  `on_dropped`. This is the behavior change I flagged in the previous Log entry
  and did not act on.
- **The shared `get_agent` double was corrected — then re-violated three tests
  below the fix**, in the same commit, by hand-rolling `... or nil` in a
  per-test override. Latent only because that fixture never reaches tiers 1-3.
  The reviewer's rule now sits in the file: a double stands in for a production
  contract; if it can return a value production cannot, it is not a double, and
  the correction belongs in the shared fixture.

Standing lesson from this issue, worth `workshop/lessons.md`: **I twice reported
a finding as fixed after fixing the instance it named.** The cheap check that
would have caught the coverage claim — disable the deliverable, confirm
something goes red — is one command, and the reviewer ran it when I did not.

### 2026-09-04 — close review round 3: the fixes for round 2 were themselves unpinned

Commit `4dbc9e9`. **BR-12** — the two warnings added for BR-2 and BR-9 both live
in `skill_invoke`, and neither had a test. Deleting either left the whole suite
green: the *pure resolver's* `on_dropped` callback had coverage; the *shell's*
`logger.warning` — the part a user actually sees — had none.

Enumeration = every user-visible behaviour this diff added at the shell, which
is exactly two. Both now pinned, and verified by mutation rather than asserted:

| mutation | result |
|---|---|
| BR-2 warning demoted to `debug` | 1 failed |
| BR-9 `on_dropped` removed | 1 failed |
| restored | 0 failed |

Round-3 minor worth keeping: the dropped-agent message reported `dropped.name`,
but `get_agent` never returns nil — a typo'd `skill_agent = "Typo"` resolves to
the **selection**, so the warning would have read `configured agent 'SEL' … has
no tool wire`, naming an agent the user never set. `source` now carries the
configured name, separating what was asked for from what it resolved to. That
is the same never-nil contract biting a third time, in a third place.

**The pattern across all three rounds was one thing:** verifying the adjacent
mechanism and reporting the real one as done. Round 1 — the deliverable had no
test (reverting it left 64/64 green). Round 2 — the BR-4 fix reintroduced BR-3,
and BR-9 was BR-2's family unswept. Round 3 — the round-2 fixes were unpinned.
The antidote is one command: remove the behaviour, confirm something goes red.
Recorded in `workshop/lessons.md`.
