# Skill System

Unified pipeline for AI-powered buffer editing. A skill sends the current buffer to an LLM with the `review_edit` tool, applies returned edits, and shows changes via highlights and diagnostics.

## Entry Points

- `<C-g>s` — skill picker (cascading typeahead: select skill → select args → run)
- `<C-g>ve` / `<C-g>vr` — fast paths for review skill (bypass picker)

## Skill Definition

Each skill is a folder under `lua/parley/skills/`:

```
lua/parley/skills/<name>/
  init.lua    -- returns { name, description, args, system_prompt, pre_submit, post_apply }
  SKILL.md    -- the system prompt sent to the LLM
```

`SKILL.md` IS the system prompt. `init.lua` defines mechanics: completable args, prompt composition, lifecycle hooks.

## Built-in Skills

- **review** — edit document based on ㊷ markers (light edit / heavy revision)
- **voice-apply** — rewrite to match a personal writing voice from `~/.personal/<slug>-writing-style.md`

## Config

```lua
skill_shortcut = { modes = { "n" }, shortcut = "<C-g>s" },
skill_agent = "Claude-Sonnet",   -- global default agent
skills = {},                      -- per-skill overrides: { { name = "review", agent = "..." }, { name = "...", disable = true } }
```

## Key Files

- `lua/parley/skill_runner.lua` — shared pipeline: discovery, agent resolution, run(), edit application, diagnostics
- `lua/parley/skill_picker.lua` — `<C-g>s` picker UI
- `lua/parley/skills/review/` — review skill (ported from review.lua)
- `lua/parley/skills/voice_apply/` — voice-apply skill
- `lua/parley/review.lua` — backward-compatible shim delegating to skill system
- `tests/unit/skill_runner_spec.lua` — unit tests
