# Skill System

> **Redesign in progress (#128), re-scoped 2026-06-15.** Parley has **two modes**
> (see `workshop/pensive/parley-two-modes-chat-vs-artifact.md`): **P1** — parley
> *chat* as an ariadne workbench (read-only, repo-aware, tools); **P2** — a
> workbench around *one artifact* (the markdown file is the subject; *skills*
> construct context + mutation tools). **"Skill" is a P2 concept.** The redesign
> deletes the parallel `skill_runner` engine by having P2 **reuse the existing
> dispatcher/tools layer** — **P1's chat loop is untouched**, and **no new shared
> kernel is built.** The v1 pipeline (lower sections) is the live runtime until
> M4.

## Redesign (#128) — P2 rides the shared dispatcher; skill = P2 descriptor

A skill is **data, not a pipeline**: a `SkillManifest`
(`{name, description, scope, activation, source, tools?, elevated?, force_tool?, args?, agent?}`).
The "shared kernel" is the **existing dispatcher/tools layer**
(`prepare_payload` / `query` / `decode` / `execute_call`) that P1's chat loop
already rides; P2 gets a **thin driver** (`skill_invoke`, M3) that rides the same
layer instead of `skill_runner`'s bespoke copies. The keystone: **`propose_edits`
is a real registered tool**, so P2's edit-apply flows through the same
`execute_call` path as every chat tool — **cwd-scope is active now**; the backup
prelude is deferred to the dispatcher's write-path milestone (so M3 must secure a
backup — inline like `write_file`, or via the prelude — before `review` applies
destructive edits through it).

**Milestones** (plan: `workshop/plans/000128-skill-system-redesign-plan.md`):
M1 manifest + providers + registry (done) · **M2 `propose_edits` tool + pure P2
context-assembler (done)** · M3 thin `skill_invoke` driver + port `review` ·
M4 port `voice-apply` + delete `skill_runner` · ~~M5 `repo_discovery`~~ **dropped**
(it's P1 context, not a skill).

**M1 modules:**
- `lua/parley/skill_manifest.lua` — `SkillManifest` shape + `validate` (PURE).
- `lua/parley/skill_providers.lua` — `disk(root)` (closure `source` — kills the v1 `debug.getinfo` dance) + `virtual(generators)` seam.
- `lua/parley/skill_registry.lua` — `discover` (union + validate-drop + last-wins dedup), `current()`; exposed as `parley.skills`.

**M2 modules (the shared pieces P2 reuses — no LLM, no chat-loop change):**
- `lua/parley/skill_edits.lua` — `compute_edits` (PURE batch-edit transform; the single source — v1 `skill_runner` delegates to it).
- `lua/parley/tools/builtin/propose_edits.lua` — the real `propose_edits` builtin (`kind=write`); edit-apply via the shared dispatch path.
- `lua/parley/skill_assembly.lua` — PURE `build_invocation` (manifest + body + document → LLM-call inputs) + `resolve_agent` (the agent cascade, pure given injected config/registry deps).

Key design points: P2's edit-apply is a normal tool (not special-cased);
`build_invocation`/`compute_edits`/`resolve_agent` are pure (the `source()` IO +
`query` + `execute_call` stay in the M3 driver); the chat loop is never touched.

---

## v1 pipeline (transitional — live until M4)

Unified pipeline for AI-powered buffer editing. A skill sends the current buffer to an LLM with the `review_edit` tool, applies returned edits, and shows changes via highlights and diagnostics.

## Entry Points

- `<C-g>s` — skill picker (cascading typeahead: select skill → select args → run)
- `<C-g>ve` — fast path for review skill (bypass picker)

## Skill Definition

Each skill is a folder under `lua/parley/skills/`:

```
lua/parley/skills/<name>/
  init.lua    -- returns { name, description, args, system_prompt, pre_submit, post_apply }
  SKILL.md    -- the system prompt sent to the LLM
```

`SKILL.md` IS the system prompt. `init.lua` defines mechanics: completable args, prompt composition, lifecycle hooks.

## Built-in Skills

- **review** — edit document based on 🤖 markers (light edit / heavy revision)
- **voice-apply** — rewrite to match a personal writing voice from `~/.personal/<slug>-writing-style.md`

## Config

```lua
skill_shortcut = { modes = { "n" }, shortcut = "<C-g>s" },
skill_agent = "Claude-Sonnet",   -- global default agent
skills = {},                      -- per-skill overrides: { { name = "review", agent = "..." }, { name = "...", disable = true } }
```

## Key Files

Redesign (#128) — M1 (manifest + discovery):
- `lua/parley/skill_manifest.lua` — declarative `SkillManifest` shape + `validate` (PURE)
- `lua/parley/skill_providers.lua` — `disk(root)` + `virtual(generators)` providers (uniform manifests)
- `lua/parley/skill_registry.lua` — `discover`/`get`/`names`/`default_stack`/`current()` (exposed as `parley.skills`)
- `tests/unit/skill_manifest_spec.lua`, `tests/integration/skill_providers_spec.lua`, `tests/integration/skill_registry_spec.lua`

Redesign (#128) — M2 (shared pieces P2 reuses):
- `lua/parley/skill_edits.lua` — `compute_edits` (PURE; single source of the batch-edit transform)
- `lua/parley/tools/builtin/propose_edits.lua` — the real `propose_edits` builtin (P2 edit-apply via the shared dispatch path)
- `lua/parley/skill_assembly.lua` — PURE `build_invocation` + `resolve_agent` (injected-config cascade)
- `tests/unit/skill_edits_spec.lua`, `tests/unit/tools_builtin_propose_edits_spec.lua`, `tests/unit/skill_assembly_spec.lua`

v1 pipeline (live until M4):
- `lua/parley/skill_runner.lua` — shared pipeline: discovery, agent resolution, run(), edit application, diagnostics
- `lua/parley/skill_picker.lua` — `<C-g>s` picker UI
- `lua/parley/skills/review/` — review skill (ported from review.lua)
- `lua/parley/skills/voice_apply/` — voice-apply skill
- `lua/parley/review.lua` — backward-compatible shim delegating to skill system
- `tests/unit/skill_runner_spec.lua` — unit tests
