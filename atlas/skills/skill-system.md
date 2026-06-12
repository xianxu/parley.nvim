# Skill System

> **Redesign in progress (#128):** the skill system is moving from a separate
> forced-write pipeline (`skill_runner`) to **one engine** — the chat tool loop
> — where a skill is a declarative *manifest* that configures a single turn. See
> "Redesign (#128)" below. The v1 pipeline in the lower sections is still the
> **live runtime** until the port completes (M4); the new declarative layer (M1)
> coexists alongside it and is inert until the chat-loop wiring (M2).

## Redesign (#128) — declarative modules over one engine

A skill is **data, not a pipeline**: a `SkillManifest`
(`{name, description, scope, activation, source, tools?, elevated?, force_tool?, args?, agent?}`)
that the per-turn assembly consumes. Uniform-manifest **providers** (plugin-disk
/ user-disk / repo / virtual) are unioned by a registry; a thin pure assembly
maps the buffer's active-skill set + scope → (extra system context, granted
tools, optional forced tool); the existing chat loop runs that. `skill_runner`'s
forced-write engine is deleted once `review`/`voice-apply` run through the loop.

**Milestones** (plan: `workshop/plans/000128-skill-system-redesign-plan.md`):
M1 manifest + providers + registry (delivered) · M2 `read_skill` tool + per-turn
assembly + loop wiring · M3 `propose_edits` builtin + `force_tool` + port
`review` · M4 port `voice-apply` + delete `skill_runner` · M5 `repo_discovery`
virtual skill (the #116 bridge).

**M1 modules (delivered, no chat-loop change yet):**
- `lua/parley/skill_manifest.lua` — `SkillManifest` shape + `validate` (PURE); `SCOPES`/`ACTIVATION_FLAGS`.
- `lua/parley/skill_providers.lua` — `disk(root)` (closure `source` over the captured abs path — kills the v1 `debug.getinfo` dance) + `virtual(generators)` seam.
- `lua/parley/skill_registry.lua` — `discover(providers)` (union + validate-drop + dedup, **last-provider-wins**), `default_stack`/`current()`; exposed as `parley.skills`.
- `review`/`voice-apply` carry declarative fields (scope/activation/tools/elevated/force_tool); discoverable as manifests.

Key design points: the unified `source(ctx)` closure (no disk/virtual fork at
the read site); per-turn grants must derive from a per-buffer active-skill state
re-read each turn (the recursive `respond()` rebuilds `agent_info`, M2);
`read_skill` will be cwd-scope-exempt like `chat_history_search`.

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

Redesign (#128, M1):
- `lua/parley/skill_manifest.lua` — declarative `SkillManifest` shape + `validate` (PURE)
- `lua/parley/skill_providers.lua` — `disk(root)` + `virtual(generators)` providers (uniform manifests)
- `lua/parley/skill_registry.lua` — `discover`/`get`/`names`/`default_stack`/`current()` (exposed as `parley.skills`)
- `tests/unit/skill_manifest_spec.lua`, `tests/integration/skill_providers_spec.lua`, `tests/integration/skill_registry_spec.lua`

v1 pipeline (live until M4):
- `lua/parley/skill_runner.lua` — shared pipeline: discovery, agent resolution, run(), edit application, diagnostics
- `lua/parley/skill_picker.lua` — `<C-g>s` picker UI
- `lua/parley/skills/review/` — review skill (ported from review.lua)
- `lua/parley/skills/voice_apply/` — voice-apply skill
- `lua/parley/review.lua` — backward-compatible shim delegating to skill system
- `tests/unit/skill_runner_spec.lua` — unit tests
