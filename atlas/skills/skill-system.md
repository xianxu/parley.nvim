# Skill System

Skills run focused LLM tasks against the current artifact, using the same
provider dispatcher and client-side tools as chat. `<C-g>s` opens the skill
picker; in non-chat Markdown, `<M-s>` is another entry. The picker collects any
declared arguments, then runs the selected skill without creating a chat buffer.

## Built-in behavior

| Skill | What it does | Entry or requirement |
|---|---|---|
| `review` | Apply document edits from ready markers or a review mode; show edit explanations | `<C-g>ve` for marker review; `<M-CR>` in Markdown for the mode menu |
| `voice-apply` | Rewrite an artifact using a personal writing-style guide | Choose a style from `~/.personal/<slug>-writing-style.md` |
| `define` | Produce an inline definition for a selected term | Visual definition action supplies the selected phrase and bounded context |

See [document review](../modes/review.md) for markers, modes, journal, and undo
behavior. Skills can write the artifact: `propose_edits` uses the shared tool
execution path, writes a numbered `.parley-backup.N`, and reloads the buffer.
The driver prevents concurrent invocations on the same buffer and reports
progress; each ordinary invocation is one tool-use exchange. Review adds its
own bounded marker-resubmission loop.

## Discovery and customization

The plugin supplies skill folders under `lua/parley/skills/`. User skills under
`~/.config/parley/skills/` override a plugin skill with the same name. Each folder
contains `init.lua`, returning a `SkillManifest`:

```lua
{ name, description, scope, activation, source,
  tools = {}, elevated = {}, force_tool = nil, args = {}, agent = nil }
```

`SKILL.md` is the default prompt body. A manifest can instead provide a
`source(ctx)` function; `define` uses this and has no SKILL.md. The disk provider
injects `ctx.skill_dir` and, when present, `ctx.skill_md`, so dynamic prompts can
compose local resources. Manifest validation drops invalid entries; discovery
deduplicates by name with the last provider winning.

`skill_registry.default_stack` also accepts explicit repo/virtual generator
providers. These are extension seams, not automatic discovery of every repo's
agent skills. `config.skills` currently supplies per-skill agent overrides; the
picker does not implement a `disable` filter there.

## Agent selection

The first tool-capable candidate wins in this order:

1. `config.skills` entry for this skill, e.g. `{ name = "review", agent = "MyAgent" }`.
2. Legacy `review_agent`, for review only.
3. The manifest's `agent`.
4. Global `skill_agent`.
5. The selected transcript agent, including chat `provider:`/`model:` overrides.
6. The first tool-capable agent in roster order.

`review_agent` and `skill_agent` default to nil. A skill owns its prompt, so the
transcript's system prompt is not inherited. Candidates without a tool wire are
skipped; explicit unsupported choices emit a diagnostic. Supported wires are
Anthropic and OpenAI families, including proxy routes; direct Google AI is not
available for tool-driven skills. Unknown named agents retain `get_agent`'s
fallback-to-selection behavior.

## Module map

| Module | Responsibility |
|---|---|
| `skill_manifest.lua` | Validate the declarative manifest |
| `skill_providers.lua`, `skill_registry.lua` | Load disk/virtual providers and resolve overrides |
| `skill_picker.lua` | Select skill/arguments and dispatch review or generic invocation |
| `skill_assembly.lua` | Build invocation context and resolve the agent |
| `skill_invoke.lua` | Run one exchange, execute tools, refresh the captured source and call completion hooks |
| `skill_source_read.lua` | Pure admission, logical completion, deadline and physical retirement decisions for final source reads |
| `skill_edits.lua`, `tools/builtin/propose_edits.lua` | Compute and apply document edits |
| `tools/backup.lua`, `skill_render.lua` | Backups, highlights, diagnostics |
| `skills/review/`, `skills/voice_apply/`, `skills/define/` | Built-in manifests and behavior |

All module paths are under `lua/parley/`. There is no separate skill runner or
provider transport.

## Verification

Unit coverage: `tests/unit/skill_manifest_spec.lua`, `skill_assembly_spec.lua`,
`skill_edits_spec.lua`, `skill_picker_spec.lua`, `skill_source_read_spec.lua`, and
`skill_render_spec.lua`.
Integration coverage: `tests/integration/skill_registry_spec.lua`,
`skill_providers_spec.lua`, `skill_invoke_spec.lua`, `skill_invoke_review_spec.lua`,
`voice_apply_spec.lua`, and `define_spec.lua`.
