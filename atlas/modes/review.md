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

- **Module**: `lua/parley/review.lua`
- **Headless**: Direct API call, no chat buffer, no exchange model
- **Stateless**: Each submit sends full document; markers carry conversation history
- **Tool**: Private `review_edit` tool (not in global registry) with
  `{old_string, new_string, explain}` triples
- **Edits**: Applied to file on disk, buffer reloaded via `:checktime`
- **Feedback**: Temporary highlights on edits (DiffChange), diagnostics
  from explain fields (INFO), quickfix for pending agent questions
- **Provider**: Requires Anthropic or cliproxyapi (tool_use support)

## Config

```lua
review_agent = "",              -- agent name (empty = auto-resolve)
review_highlight_duration = 2000, -- highlight fade time in ms
review_shortcut_insert = { modes = { "n", "v" }, shortcut = "<C-g>vi" },
review_shortcut_edit   = { modes = { "n" }, shortcut = "<C-g>ve" },
review_shortcut_revise = { modes = { "n" }, shortcut = "<C-g>vr" },
```

## Key Files

- `lua/parley/review.lua` — core: parsing, submission, edit application, UI
- `lua/parley/highlighter.lua` — `ParleyReviewUser`/`ParleyReviewAgent` groups
- `lua/parley/config.lua` — default keybindings and config
- `tests/unit/review_spec.lua` — unit tests for parser and edit application
