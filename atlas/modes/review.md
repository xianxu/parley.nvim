# Document Review

Headless LLM-powered review workflow for markdown files. Users annotate
documents with `🤖[comment]` markers, then an agent rewrites the document
to address the comments.

The same marker family is also used inside chat buffers for
[drill-in discussions](../chat/drill_in.md) (different keybindings + a chat-
side gather/strip on respond). The section parser is shared.

## Marker Syntax

Single marker `🤖`. Three section types:

- `<>` = quoted body (optional, at most one, must be the first slot)
- `[]` = human turns
- `{}` = agent turns

After an optional `<>`, `[]` and `{}` may appear in any order.

```
🤖[human comment]{agent question}[human reply]...
🤖{agent finding}[human response]{agent follow-up}...
🤖<the exact phrase>[fix this]
🤖<paragraph snippet>{suggested rewrite}
```

- Ready for agent = last section is `[]` (human spoke last)
- Pending (quickfix) = last section is non-empty `{}` (agent asked, needs human reply)
- Markers inside fenced code blocks are ignored
- `<text>` disambiguates "which text the marker refers to" — use it whenever the surrounding-text rule would be ambiguous (added in #123)

## Keybindings (non-chat markdown only)

| Binding         | Action                                                          |
|-----------------|-----------------------------------------------------------------|
| `<M-q>` / `<C-g>q` | Insert `🤖<sel>[]` (visual) or `🤖[]` (normal/insert). Shared with chat — see `atlas/chat/drill_in.md`. |
| `<M-a>`         | Accept the marker at cursor per [review-convention §5](../../../ariadne/workshop/targets/review-convention.md) |
| `<M-r>`         | Reject the marker at cursor per review-convention §5            |
| `<C-g>ve`       | Run the review skill (agent edits per ready markers)            |
| `<C-g>vf`       | Open the review finder (jump to files with pending markers)     |

The earlier `<C-g>vi` / `<C-g>vr` insertion shortcuts were retired in #124 M3 — `<M-q>` is the single canonical insertion path, and `<M-a>` / `<M-r>` handle per-marker accept/reject.

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
review_shortcut_edit   = { modes = { "n" }, shortcut = "<C-g>ve" },
review_shortcut_finder = { modes = { "n", "i" }, shortcut = "<C-g>vf" },
-- Marker insertion: see drill_in_callbacks in lua/parley/init.lua
-- (shared <M-q> / <C-g>q binding)
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
