---
id: 000128
status: working
deps: []
github_issue:
created: 2026-06-11
updated: 2026-06-12
estimate_hours: 40
---

# Skill system redesign: declarative modules over one engine

## Problem

Parley has **two execution engines that duplicate concerns**: the chat tool
loop (`chat_respond`/`dispatcher` — multi-turn, recursive, readonly-capable) and
`skill_runner.run` (single-shot, `tool_choice = review_edit` forced-write). They
each re-implement agent resolution, payload prep, tool decode, and result
handling.

The v1 skill system (#106) is hardwired to "force a structured edit on the
current buffer." That is the wrong shape for the direction parley is taking: a
**readonly research/exploration harness** whose value is a better *chat*
experience (tree-of-chats, markdown-as-state), and whose agent substrate should
be *composed per turn* (persona + skills) rather than run through a fixed
forced-write pipeline. v1 was built in a rush and is effectively unused — low
confidence in the design. Redo it, salvaging the good pure pieces.

Settled in the brain design conversation 2026-06-11 (product behavior agreed;
implementation pending a plan doc). Siblings: #116 (the discovery registry this
consumes) and #129 (the permission model layered on the manifest's tool grants).

## Spec

**One engine.** There is a single engine — the chat tool loop. A skill is a
declarative module that *configures a turn* of that loop; it has no pipeline of
its own. This deletes the parallel `skill_runner` engine (DRY).

**Skill manifest (declarative).** Four independent axes — identity, source,
activation, capability:

```lua
{
  name        = "review",
  description = "Edit this document per its 🤖 markers",  -- menu entry for model selection
  scope       = "global",          -- global | repo | super_repo
  activation  = { manual = true, auto = true },  -- independent flags, any combination:
                                   --   always = preloaded; auto = in model's menu; manual = hotkey
  source      = function(ctx) ... end,           -- UNIFIED signature (disk + virtual)
  tools       = { "read_file" },                 -- granted whenever active (incl. auto)  [see #129]
  elevated    = { "propose_edits" },             -- granted only on MANUAL invocation     [see #129]
  force_tool  = "propose_edits",                 -- optional: compel structured output this turn
  args        = { ... },                          -- optional: keep the completable-arg picker
}
```

**Unified `source(ctx)` thunk (no disk/virtual fork).** A disk skill's `source`
is a closure the *disk provider* builds with the absolute path it already found
(`return read(captured_path)`) — this deletes the current `debug.getinfo`
path-guessing dance. A virtual skill's `source` generates its body. So
`read_skill(name)` never forks: it calls `registry.get(name).source(ctx)` and
the branch is absorbed into the closure.

**Providers (skill sources), all emitting uniform manifests** — `discover_skills()`
unions them:
- plugin-bundled (disk: `lua/parley/skills/*`),
- user-config (disk: `~/.config/parley/skills/`),
- **repo-provided** (the inspected repo can ship skills via its readonly manifest — not just the discovery registry),
- **virtual** (generated at runtime — e.g. `repo_discovery`).

**`read_skill(name)` tool.** Source-agnostic; name-based; **exempt from
cwd-scope** (a skill is a parley-namespace concept, not a repo file — same
rationale as `chat_history_search` bypassing cwd). Loading a skill renders as a
🔧/📎 block in the transcript (expose-the-harness-in-transcript; the human can
see and prune what's loaded).

**Per-turn assembly (thin, deterministic — no heavy assembler).**
1. always: persona (parley's own AGENTS.md) + the `always` skills for the current scope;
2. menu: append `(name, description)` of `auto` skills (cheap);
3. pull: model calls `read_skill(name)` mid-loop, or a hotkey pre-activates a `manual` skill;
4. run the existing loop with the assembled context + active tool set.

**`repo_discovery` — the first virtual skill, and the merge point with #116.**
`scope = repo`, `activation = { always = true }`, `tools = <read set>`,
`source = function(ctx) return registry.render(ctx.repo_root) end` (the #116
registry). Description: *"what file types (nouns) exist in this repo and how to
find their instances."* This is how a repo's borrowed substrate merges into
parley's own — situational facts only, so it's conflict-free.

**Salvage from v1** (keep the good pure code, drop the orchestration):
- `compute_edits`/`apply_edits` → the `propose_edits` tool handler (batch edits + `explain`; **batch-edit UX is kept** — decided);
- `highlight_edits`/`attach_diagnostics` → that tool's result rendering;
- `discover_skills` (extend with providers); SKILL.md-as-body; agent-resolution cascade; the arg picker.

**Delete from v1:** `skill_runner.run` single-shot path, its separate
`dispatcher.query` call, the hardcoded `tool_choice`/`max_tokens`,
`_in_flight`/resubmit. Skills feed the one loop instead.

**Finish or cut the dead builtin tools `glob.lua` + `list_dir.lua`** (present in
`builtin/` but not in `BUILTIN_NAMES`). For `repo_discovery` they're *better*
than shelling out to `ls`/`find` (structured, no command-injection surface) —
likely finish + register and have `repo_discovery` grant them.

## Done when

- `review` and `voice_apply` run through the chat loop as declarative manifests, not a separate pipeline; `review` keeps the batch-edit-with-explanations UX via `propose_edits` + `force_tool`.
- `read_skill(name)` loads disk and virtual skills uniformly (no fork), exempt from cwd-scope, visible as transcript blocks.
- The model can pull an `auto` skill mid-conversation; an `always` skill is preloaded by scope.
- A virtual `repo_discovery` skill is always-loaded in repo mode, its body sourced from #116's registry.
- `skill_runner`'s forced-write pipeline is deleted; the duplicate engine is gone; `glob.lua`/`list_dir.lua` are resolved (registered or removed).

## Plan

_Non-trivial — write a plan doc (`superpowers-writing-plans` →
`workshop/plans/000128-*-plan.md`) before implementing; milestones TBD there.
Rough shape:_

- [ ] manifest schema + provider-based `discover_skills` (disk / user / repo / virtual)
- [ ] `read_skill` tool (source-agnostic, cwd-scope-exempt, transcript-visible)
- [ ] route skills through the chat loop; delete `skill_runner` forced pipeline; salvage edit/diagnostic helpers into `propose_edits`
- [ ] per-turn assembly (always-on + menu + pull); activation flags
- [ ] port `review` + `voice_apply` to manifests
- [ ] `repo_discovery` virtual skill (consumes #116 registry)
- [ ] resolve `glob.lua` / `list_dir.lua`
- [ ] layer #129 permission model onto `tools`/`elevated`

## Log

### 2026-06-11

Filed from the brain design conversation. Supersedes the architecture of #106
(v1 skill system) — see #106 log. Product behavior settled; this issue records
the design, implementation pending a plan doc.

**Dependency corrected (2026-06-11):** #128 does **not** depend on #116. Its
architecture — one engine, declarative manifests, `read_skill`, the provider
system, porting review/voice — is built against the existing disk skills and the
chat loop. Only the single `repo_discovery` virtual-skill *task* needs #116
**M1** (`render()`), and it's bridged in after both exist. `deps` set to `[]`
accordingly (was `[000116]`, which overstated the coupling). Permission model
split to **#129** (which does dep #128). **Operator-approved sequencing:** #116
M1 (ready now) → **#128 (the main event; needs its own plan doc)** → bridge
`repo_discovery` → #129 → circle back for #116 M2/M3.
