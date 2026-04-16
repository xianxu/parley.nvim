# Document Review

Headless LLM-powered review workflow for markdown files. Users annotate
documents with `㊷[comment]` markers, then an agent rewrites the document
to address the comments.

## Marker Syntax

```
㊷[user comment]{agent question}[user reply]{agent question}...
```

- `[]` = user turns, `{}` = agent turns, strictly alternating
- Odd section count = ready for agent, even = awaiting user response
- Markers inside fenced code blocks are ignored

## Keybindings (non-chat markdown only)

| Binding    | Action                                          |
|------------|-------------------------------------------------|
| `<C-g>vi`  | Insert `㊷[]` marker (visual: wrap selection)   |
| `<C-g>ve`  | Light edit — conservative, preserve voice/tone  |
| `<C-g>vr`  | Heavy revision — substantive rewriting allowed  |

## Editing Levels

- **Light edit** (`<C-g>ve`): Copy editing. Fix what's pointed out, preserve
  structure/tone/wording. Agent asks `{}` questions when ambiguous.
- **Heavy revision** (`<C-g>vr`): Substantive editing. Agent can rewrite
  paragraphs, restructure sections. Uses best judgment on ambiguity.

## Architecture

Review is implemented as a **skill** in the unified skill system (see `atlas/index.md` §8).

- **Skill module**: `lua/parley/skills/review/init.lua` — marker parsing, pre/post hooks, keybindings
- **System prompt**: `lua/parley/skills/review/SKILL.md`
- **Shared pipeline**: `lua/parley/skill_runner.lua` — edit application, diagnostics, highlights, LLM orchestration
- **Shim**: `lua/parley/review.lua` — backward-compatible re-exports for existing callers
- **Headless**: Direct API call, no chat buffer, no exchange model
- **Stateless**: Each submit sends full document; markers carry conversation history
- **Tool**: `review_edit` tool with `{old_string, new_string, explain}` triples
- **Edits**: Applied to file on disk, buffer reloaded via `:checktime`
- **Feedback**: Highlights on edits (DiffChange), diagnostics from explain fields (INFO), quickfix for pending agent questions
- **Provider**: Requires Anthropic or cliproxyapi (tool_use support)

## Config

```lua
review_agent = "",              -- agent name (deprecated; use skills config)
review_highlight_duration = 2000, -- highlight fade time in ms
review_shortcut_insert = { modes = { "n", "v" }, shortcut = "<C-g>vi" },
review_shortcut_edit   = { modes = { "n" }, shortcut = "<C-g>ve" },
review_shortcut_revise = { modes = { "n" }, shortcut = "<C-g>vr" },
-- Or via skill picker: <C-g>s → review → edit/revise
```

## Key Files

- `lua/parley/skills/review/init.lua` — skill definition, marker parsing, hooks, keybindings
- `lua/parley/skills/review/SKILL.md` — system prompt (light edit + heavy revision sections)
- `lua/parley/skill_runner.lua` — shared edit-apply-display pipeline
- `lua/parley/review.lua` — backward-compatible shim
- `lua/parley/highlighter.lua` — `ParleyReviewUser`/`ParleyReviewAgent` groups
- `lua/parley/config.lua` — default keybindings and config
- `tests/unit/review_spec.lua` — unit tests for parser and edit application
- `tests/unit/skill_runner_spec.lua` — unit tests for compute_edits and apply_edits
