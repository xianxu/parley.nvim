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

> **RE-SCOPED 2026-06-15 — read `## Revisions` first.** The original premise
> (skills "configure a turn of the chat loop") conflated two distinct modes and
> was partly premature. This issue is now scoped to **unifying the execution
> loop + context assembly**, with *skill* = the **P2 artifact-workbench**
> descriptor only. The framing lives in
> `workshop/pensive/parley-two-modes-chat-vs-artifact.md`. Parts of the Spec /
> Done-when below (read_skill-in-chat, `auto`/`always` chat activation,
> `repo_discovery`-as-skill) are **superseded** — see Revisions.

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

_(Re-scoped 2026-06-15 — see `## Revisions`. The original chat-skill bullets
below are **superseded**; the re-scoped done-when follows.)_

**Re-scoped done-when:**
- `review` and `voice_apply` run via the **thin P2 driver** (`skill_invoke`) that rides the **existing dispatcher layer** (`prepare_payload`/`query`/`execute_call`) — not a separate engine; `review` keeps the batch-edit-with-explanations UX.
- `propose_edits` is a **real registered builtin tool**, so P2's edit-apply flows through the same `execute_call` path (cwd-scope + backup) as every chat tool.
- `skill_runner`'s forced-write pipeline is **deleted**; the duplicate engine is gone; the salvaged pure pieces (`compute_edits`, agent cascade) survive as shared modules.
- **P1's chat loop is untouched**; no new shared-loop kernel was built.
- `glob.lua`/`list_dir.lua`: a recorded YAGNI **decision** (they don't exist; `ls`/`find`/`grep` suffice) — not a deletion task.

<details><summary>~~Original done-when (superseded — chat-skill conflation)~~</summary>

- ~~`review`/`voice_apply` run through the **chat loop** as declarative manifests~~
- ~~`read_skill(name)` loads disk and virtual skills uniformly, cwd-exempt, transcript-visible~~ (read_skill-in-chat dropped)
- ~~the model pulls an `auto` skill mid-conversation; an `always` skill is preloaded by scope~~ (chat-menu activation dropped)
- ~~a virtual `repo_discovery` skill is always-loaded in repo mode~~ (that's P1 context, not a skill)
</details>

## Plan

Decomposed into review-boundary milestones — task detail in
`workshop/plans/000128-skill-system-redesign-plan.md` (M1 task-detailed; M2–M5
sketched). The original rough shape is folded into the milestones below.

**Re-scoped 2026-06-15** (see `## Revisions`): #128 = *unify the execution loop
+ context assembly so P1 (chat) and P2 (skill/artifact) share one engine; skill
= the P2 descriptor.* M2–M5 below replace the original chat-turn framing; detailed
re-planning of the new M2+ happens when we tackle it (the plan doc's M2–M5
sketches are stale until then).

- [x] M1 — declarative manifest + provider-based discovery: `SkillManifest` shape+`validate`; disk/virtual providers (closure `source`, kills the `debug.getinfo` dance); registry union+dedup; `review`/`voice_apply` re-expressed as manifests. **Survives as the P2-skill descriptor** (chat-flavored fields `scope`/`activation.auto/always` to be revisited → "how a skill is surfaced in the P2 UI").
- [x] M2 — `propose_edits` real builtin (P2 edit-apply via the **existing** `execute_call` path) + the pure P2 pieces (`skill_edits.compute_edits`, `skill_assembly.build_invocation`/`resolve_agent`). **No new kernel** — P2 will ride the existing dispatcher via the M3 driver (the chat loop is untouched). _(Earlier wording said "extract a shared context-assembler + tool-loop core"; that kernel-extraction was abandoned for the lighter "P2 reuses the existing dispatcher" approach — see `## Revisions`.)_
- [x] M3 (re-scoped) — `propose_edits` mutation tool (salvage `compute_edits`/`apply_edits` + highlight/diagnostics); port `review` to **drive the shared loop on the artifact** (single-shot → recursive-capable), not a separate pipeline.
- [x] M4 (re-scoped) — port `voice_apply` likewise; **delete `skill_runner`** + reconcile callers (`skill_picker`/`review.lua`/keybindings); resolve `glob`/`list_dir` (YAGNI — they don't exist).
- [ ] ~~M5 — `repo_discovery` virtual skill~~ **DROPPED** — `repo_discovery` is **P1 context/tools**, not a skill (category error). #116 feeds P1 directly; see the P1 project below.

**Dropped from the original scope** (premature P1/P2 conflation): `read_skill`-in-chat, `auto`/`always` chat activation (skills pulled into the chat menu), `repo_discovery`-as-skill.

**P1 — "parley chat as ariadne workbench" (discovery + repo tools in chat context)** is a **distinct project** that #116 feeds; it likely deserves its **own issue** when tackled. Not created yet (deferred).

(**#129** capability permission model = tool permissions for **both** modes; layers on the shared tool infra **after** this issue — a separate issue, not a milestone here.)

## Revisions

### 2026-06-15 — RE-SCOPED: unify at the loop; skill = P2-only descriptor

A design conversation separated two modes the original ticket had prematurely
fused (operator: "I think I hallucinated a bit"). Full framing:
`workshop/pensive/parley-two-modes-chat-vs-artifact.md`. Deltas:

- **Two modes, two projects.** **P1** = parley *chat* as an ariadne workbench
  (repo-aware, read-only, tools-only; the transcript is the value). **P2** = a
  workbench around *one artifact* (the markdown file is the subject; "chat" is
  implicit via *skills*; mutation tools; single-shot→recursive; multi-headed
  marker→thread; document review is canonical).
- **Skill = P2 only. Tools = both.** "Skill" is the artifact-mode command
  (prompt-portion + tools + UI registration). Read-only repo tools serve P1.
- **`repo_discovery`-as-skill was a category error** → it's P1 context/tools, not
  a skill. **M5 dropped.** #116 feeds P1 directly.
- **Skills are NOT chat turns** → `read_skill`-in-chat + `auto`/`always` chat
  activation **dropped**. That was the premature P1/P2 bridge.
- **The genuine, retained DRY win** (the original Problem) = the **two execution
  engines** (`chat_respond` loop vs `skill_runner` single-shot) re-implement
  assemble→call→tool-loop→recurse. Re-scope = **one context-assembler + tool-loop
  core** that P1 (chat) and P2 (skill driver) both parameterize;
  `skill_runner` deletes. Unification is at the **loop**, not "skills are chat."
- **M1 survives** as the P2-skill descriptor (manifest + providers + registry);
  the chat-flavored fields (`scope`, `activation.auto/always`) trim toward "how a
  skill is surfaced in the P2 UI" — revisit at re-plan.
- **Detailed re-plan of M2+ deferred** to when we tackle it (operator pausing for
  an ariadne change first). The plan-doc M2–M5 sketches are stale until then.
- **P1 deserves its own issue** when tackled (not created yet).

## Log



- 2026-06-17: closed M4 — M4: voice_apply ported to source(ctx); skill_runner DELETED + all callers reconciled; picker reads registry; full suite green (107 specs) + lint 0/0 (203 files); glob/list_dir YAGNI recorded. ACTUAL=labeled ~1.5h (cf M3 1.5h) — auto-measure 14.37h is rebase-contaminated (orphaned base 96302e08 → window spans 11 issues #95-#132).; review verdict: FIX-THEN-SHIP
- 2026-06-17: **M4 boundary finding addressed** (FIX-THEN-SHIP, no Critical). Important: `skill_invoke.source()` was called outside `pcall` → a fallible source (voice_apply, missing style file) threw a raw error instead of routing through `on_done({ok=false})` like the other early-outs. Wrapped + tested (source throws → on_done ok=false, no query). Minors documented (ok-semantics, marker-shrank conservatism, applied-counts-calls). See plan `## Revisions`.
- 2026-06-16: **M4 implemented** (TDD, 5 tasks) — `voice_apply` ported to an
  explicit `source(ctx)` (SKILL.md ⊕ per-slug style guide), enabled by the
  DiskProvider injecting `ctx.skill_md`; `skill_picker` lists `parley.skills`
  and routes via `M.run_skill` (review→run_via_invoke, else→skill_invoke);
  **`skill_runner.lua` + its spec DELETED**, all callers reconciled (review/init
  dead v1 fields, review.lua shim trimmed, abort test ported to `skill_invoke`
  + `is_in_flight`). Full suite green (107 specs), lint 0/0 (203 files).
- 2026-06-16: **glob/list_dir YAGNI decision FINALIZED.** Decision: **add no
  structured `glob`/`list_dir` tool.** `glob.lua`/`list_dir.lua` never existed
  (the "present but unregistered" premise was stale); `builtin/` ships `ls`+`find`
  (registered) + `grep`, and P2's artifact mode needs only `read_file`+`propose_edits`.
  No consumer in P1 or P2 today → no tool. Side-fix: traceability listed phantom
  `tools_builtin_glob_spec`/`tools_builtin_list_dir_spec` (renamed to `find`/`ls`
  long ago, covered by `tools_builtin_registered_spec`) — removed. Recorded in
  `atlas/skills/skill-system.md` ("Tooling decision"). Revisit only on a real consumer.
- 2026-06-16: closed M3 — M3: skill_invoke driver (one exchange via existing dispatchers; chat loop untouched) + propose_edits inline backup + skill_render salvage + review ported (markers+resubmit); review-port 5/5, skill_invoke 2/2, arch+full suite green (lint 0/0, 106 spec files), voice on skill_runner 9/9. ACTUAL=labeled ~1.5h estimate — auto-measure 11.91h is rebase-contaminated (orphaned base 96302e08 → window spans 10 issues); review verdict: FIX-THEN-SHIP
- 2026-06-16: **M3 boundary findings addressed (2 review rounds, both FIX-THEN-SHIP, no Critical).** R1: I1 error-surfacing + resubmit-storm (on_done now derives ok/applied + logs; review stops on no-progress) · I2 restored max_tokens=100000 (was truncating multi-edit batches) · I3 review/SKILL.md review_edit→propose_edits · unnamed-buffer + in-flight guards. R2: closed the empty-edits/no-op hole in I1 (propose_edits rejects empty batch; review uses a marker-SHRANK guard) · extracted shared `tools/backup.lua` (ARCH-DRY; write_file+propose_edits delegate) · removed stray committed debug files. All fixes tested; full suite green throughout. See plan `## Revisions`.
- 2026-06-16: closed M2 — M2: propose_edits real tool + pure compute_edits/build_invocation/resolve_agent (19 assertions); full suite lint 0/0 + 103 spec files; chat loop + skill_runner untouched. ACTUAL=labeled estimate ~1h (cf #128 M1 measured 0.90h) — auto-measure 9.67h is rebase-contaminated (orphaned base 96302e08 → window spans #95-#132); review verdict: FIX-THEN-SHIP
### 2026-06-12 — M1 implemented (declarative manifest + provider discovery)
- 2026-06-12: closed M1 — declarative skill system M1: SkillManifest+validate (16 assertions), disk/virtual providers (8), registry union/dedup/current() incl real plugin skills (7); review+voice-apply discoverable as manifests; full suite lint 0/0 + 91 spec files pass; v1 skill_runner runtime untouched (9/9). No chat-loop change (M2); review verdict: FIX-THEN-SHIP.
- 2026-06-12: **boundary findings addressed** (two re-judge rounds, both FIX-THEN-SHIP, no Critical): R1 — plan Core-concepts `resolve_agent` table drift (→ M2/`skill_assembly`, pure-given-injected-config), dropped unbuilt "cache" claim, softened disk docstring; R2 — removed the broken speculative v1 `system_prompt` source fallback (4-arg contract, no consumer; M4 retires it), fixed the resulting plan-doc self-contradiction, and added the missing `pcall` error-path tests (throwing init.lua + erroring generator). All surfaced M1 findings resolved; suite green throughout. See plan `## Revisions`.

Plan `workshop/plans/000128-skill-system-redesign-plan.md` (fresh-review CLEAN;
change-code plan-quality: info). Executed M1 Tasks 1–5 TDD-first: `SkillManifest`
shape+`validate` (pure) · `skill_providers` (disk with closure `source` killing
the `debug.getinfo` dance + virtual seam) · `skill_registry` (provider union,
validate-drop, last-wins dedup; `current()` resolves the plugin root via
runtimepath; exposed as `parley.skills`) · `review`/`voice-apply` re-expressed as
declarative manifests. **No chat-loop change** (M2). v1 `skill_runner` runtime
untouched (its spec still 9/9). `resolve_agent` salvage deferred from Task 1 to
M2 (it reads the parley module → not pure; belongs where it's consumed).

**Done-when reconciliation (change-code advisory):** the last "Done when" bullet
says "`glob.lua`/`list_dir.lua` are resolved (registered or removed)" — but those
files **do not exist** (the "present but unregistered" framing was stale; the
registered structured tools are `ls.lua`/`find.lua`). Per the plan (Design note
2), M4's task is a **YAGNI decision** — does `repo_discovery` need a new
structured glob tool, or do `ls`/`find`/`grep` + the registry's `query()`
suffice (lean: suffice) — **not** a dead-file cleanup. The M4 closer should not
hunt for files to delete.

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
