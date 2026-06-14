---
type: continuation
slug: parley-skill-system-resume
agent: claude
branch: main
issues: [000116, 000128]
created: 2026-06-14T23:40:09Z
---

# Continuation: parley skill-system / discovery resume

## NEXT ACTION
Resume **parley.nvim #128** (skill system redesign). M1 is **done but stranded
on an unmerged branch that is now 39 commits behind `main`**. First reconcile,
then decide merge-M1 vs. continue-M2:

```
cd /Users/xianxu/workspace/parley.nvim
git log --oneline 000128-skill-system-redesign-declarative-modules-over-one-engine   # the 10 M1 commits (head cbc53e1)
# Reconcile with the advanced main (39 commits ahead — #131 managed-cliproxy, #132 ParleyProxy models):
#   PREFERRED: cherry-pick the 10 #128 M1 commits onto a fresh branch off main
#   (the branch predates #131/#132; a clean replay avoids dragging a stale base).
#     git switch -c 000128-skill-system main
#     git cherry-pick 8720009^..cbc53e1     # the 10 #128 M1 commits in order
#   ALT: git switch 000128-… && git merge main   (resolve, but carries the 39-behind history)
# Then: make test (expect green), and either `sdlc pr`+`sdlc merge` to land M1,
#   or expand M2 to tasks and execute.
```

## State of play
Two milestones were executed this arc; both passed fresh-context boundary review.

- **#116 M1 (discovery registry) — DONE & MERGED to main** (PR #95). The whole
  `lua/parley/discovery/` module (matcher/descriptor/base/registry/merge/
  local_types/init) is on `main`, exposed as `parley.discovery`;
  `current():render()` yields the noun-vocabulary #128's `repo_discovery`
  consumes. Review arc REWORK→FIX-THEN-SHIP→**SHIP** (caught a real Critical:
  `current()` read the immutable default config → base-only in every mode; fixed
  via `discovery.setup(M)` live-config injection). #116 the *issue* stays
  `working`, **1/3** — M2 (finders source home root from registry) + M3
  (embedded descriptor format) deferred ("circle back after the harness").

- **#128 M1 (declarative skill system) — DONE on branch `000128-skill-system-redesign-declarative-modules-over-one-engine` (head `cbc53e1`), NOT merged.**
  10 commits. Delivered: `skill_manifest.lua` (shape+`validate`, pure),
  `skill_providers.lua` (`disk(root)` closure-source that kills the
  `debug.getinfo` dance + `virtual(generators)` seam), `skill_registry.lua`
  (`discover` union + validate-drop + **last-wins** dedup; `current()` resolves
  the plugin root via runtimepath; exposed as `parley.skills`), and
  `review`/`voice-apply` re-expressed as declarative manifests. **No chat-loop
  change.** Suite green (lint 0/0, 91 spec files; 31 new skill assertions);
  v1 `skill_runner` untouched (9/9). Boundary review ran **3 rounds**, all
  FIX-THEN-SHIP / no-Critical, every finding fixed (see `## Decisions`).
  On `main`, the #128 issue shows M1 **unchecked** and the atlas skill-system
  doc is still v1-only — because the branch is unmerged.

## NEXT milestone: #128 M2 (the engine-integration heart)
`read_skill` tool + per-turn assembly + route skills through the chat loop.
Detail in the plan (on the branch); expand the sketch to TDD tasks at M2 start.
**Load-bearing design note (verified against code, do NOT re-derive):**
*Per-turn skill grants MUST derive from a per-buffer `ActiveSkills` state
re-read every turn* — the recursive tool-loop call `chat_respond.lua:1533` does
NOT pass `agent_info`; each turn rebuilds it fresh, so a one-time mutation
silently drops skill tools/context on recursive turns. This also makes
"model pulls a skill mid-loop via `read_skill`" fall out for free (read_skill
records activation → next turn's assembly grants it). `assemble_turn` stays
PURE: `(active_manifests, scope, manual_active) → {system_context, tools, forced_tool}`.
`read_skill` is cwd-scope-exempt like `chat_history_search` (pass no path to the
dispatcher). `resolve_agent` salvage lands in M2 as a **pure fn of injected
config** (`(config, skill) → agent`), in `skill_assembly.lua`, NOT the manifest
module.

## Decisions & dead ends
**Decisions (why):**
- *Sequencing (operator-approved):* #116 M1 → #128 → bridge `repo_discovery` (M5) → #129 → circle back #116 M2/M3.
- *#128 last-wins dedup* (later provider overrides; default stack plugin→user→repo→virtual so user/repo shadow plugin) — operator-confirmable.
- *Removed the speculative v1 `system_prompt` source fallback* (branch #3): it called `system_prompt(ctx)` but v1's contract is 4-arg `(args,file_path,content,skill_md)`; no bundled skill hits it (all ship SKILL.md), and M4 retires it. Source priority is now explicit-fn → SKILL.md; a body-less dir → `source=nil` → registry validate-drops it.
- *`voice-apply`'s dynamic body* (SKILL.md + per-slug style guide) keeps its `system_prompt` as the live path under `skill_runner`; the manifest gets an explicit `source(ctx)` when ported in **M4**.
- *`glob.lua`/`list_dir.lua` DON'T EXIST* (the issue's "present but unregistered" is stale; `ls.lua`/`find.lua` are the registered structured tools). M4's task is a **YAGNI decision** (does `repo_discovery` need a structured glob tool, or do ls/find/grep + registry `query()` suffice — lean: suffice), not a file deletion.
- *#129 (capability permission model) is the NEXT issue, not a #128 milestone* — the `tools`/`elevated` split + the `assemble_turn` gate-point are its hooks; don't build it now.

**Dead ends:** putting `resolve_agent` in the pure `skill_manifest` module (it reads the parley module → not pure → moved to its M2 consumer site); a registry cache (YAGNI — `discover`/`current` recompute per call).

## Pointers
Work repo (cross-repo pin): **`/Users/xianxu/workspace/parley.nvim`**.
- Plan (on the branch, NOT on main): `workshop/plans/000128-skill-system-redesign-plan.md` — M1 task-detailed + closed; M2–M5 sketched; `## Revisions` has the boundary-review history.
- Issue: `workshop/issues/000128-…md` (on main = M1 unchecked, pre-merge state; on the branch = M1 ticked + boundary-findings log).
- M1 code (branch only): `lua/parley/skill_manifest.lua`, `skill_providers.lua`, `skill_registry.lua`; manifests in `lua/parley/skills/{review,voice_apply}/init.lua`; specs `tests/unit/skill_manifest_spec.lua`, `tests/integration/skill_{providers,registry}_spec.lua`.
- Reuse anchors for M2 (on main): chat loop `chat_respond.lua` (turn assembly ~:1341, recursive call ~:1533), `tool_loop.lua:36` (`state_by_buf` per-buffer-state pattern), `tools/builtin/chat_history_search.lua` (cwd-bypass), `tools/init.lua:129` (`BUILTIN_NAMES`), salvage from `skill_runner.lua` (compute_edits :54, apply_edits :115, highlight/diagnostics :172-213, resolve_agent :284) — M3/M4.
- Context: brain `data/` design notes; the #116 discovery registry on main is the `repo_discovery` source.

## Caveat
Between this arc (06-12) and now (06-14) the operator landed **#131** (managed
cliproxy) and **#132** (`:ParleyProxy models`) directly on `main`. The `000128`
branch predates both → 39 commits behind. Reconcile before merging M1.
