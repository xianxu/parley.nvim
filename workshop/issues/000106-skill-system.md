---
id: 000106
status: open
deps: []
created: 2026-04-14
updated: 2026-04-14
---

# Unified skill system for AI-powered buffer editing

## Problem

Parley's AI features (review, voice-apply, future tools) each wire up their own keybindings, system prompts, and LLM call plumbing. They all follow the same pattern:

1. Build a system prompt (specialized for the task)
2. Attach the `review_edit` tool (old_string → new_string + explain)
3. Send current buffer content to LLM
4. Apply returned edits to the buffer
5. Show changes via diagnostics + highlights

As we add more features (voice-apply, code review, tone shift, etc.), keybindings get crowded and each feature duplicates the same edit-apply-display pipeline.

## Proposal

A single entry point `<C-g>s` opens a floating input with typeahead. User types `/skill-name args` (prefilled with `/`). The skill runs the shared pipeline with its own system prompt.

### What a skill is

```
Skill = {
  name = "review",
  description = "Edit document based on ㊷ markers",
  args = { {name="level", values={"edit","revise"}, default="edit"} },
  system_prompt = function(args, file_path, content) ... end,
  pre_submit = function(buf, args) ... end,  -- optional (e.g. marker validation)
  post_apply = function(buf, args, result) ... end,  -- optional (e.g. re-scan markers)
  agent = "Claude-Sonnet",  -- or nil for config default
}
```

All skills share: `review_edit` tool definition, `compute_edits`/`apply_edits`, `highlight_edits`/`attach_diagnostics`.

### Skills to port

1. **review** — existing `<C-g>ve`/`<C-g>vr` → `/review edit` and `/review revise`
2. **voice-apply** — new → `/voice-apply xian` (reads `~/.personal/<slug>-writing-style.md`)

### UX flow

1. `<C-g>s` → float input opens, prefilled with `/`
2. Typeahead completes skill names after `/`, then skill-specific args after space
3. Enter → skill runner executes: build prompt → LLM call → apply edits → show diagnostics
4. Edits appear highlighted with `DiffChange`, explanations as INFO diagnostics

### Architecture

- `lua/parley/skill_runner.lua` — shared pipeline extracted from review.lua
- `lua/parley/skills/*.lua` — individual skill definitions (review, voice-apply)
- `lua/parley/skill_picker.lua` — `<C-g>s` input with typeahead
- review.lua retains marker parsing logic, exposed via skill hooks

## Spec

See `workshop/plans/000106-skill-system-plan.md` for the full spec covering:
- Skill definition interface (folder structure, init.lua, SKILL.md as prompt)
- Skill runner pipeline (12 steps from pre-submit to post-apply)
- Skill picker UX (`<C-g>s` with cascading typeahead)
- Discovery and configuration (lazy scan, per-skill config overrides)
- Two initial skills: review (ported) and voice-apply (new)
- Error handling and resubmit limits
- File layout and extraction plan from review.lua

## Plan

_Implementation plan will be written in `workshop/plans/000106-skill-system-plan.md` after spec section is moved there._

## Log

- 2026-04-14: Brainstormed design. Key decisions: SKILL.md IS the prompt, rigid completable args only, `<C-g>s` picker with cascading typeahead, skills as folders under `lua/parley/skills/`, shared pipeline in `skill_runner.lua`. Spec reviewed by subagent — addressed keybinding collision (`<C-g>s` vs system prompt → system prompt moves to `<C-g>p`), float_picker extension needed for dynamic items, Anthropic-only constraint documented.
