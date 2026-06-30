# Document Review Tool — Design Spec

## Overview

A headless LLM-powered review workflow for markdown files. Users annotate
documents with `㊷[comments]`, then trigger an agent to address those comments.
Two editing levels: light edit (preserve structure/tone) and heavy revision
(rewrite freely). No chat buffer — direct API call, edits applied to file,
diagnostics for change explanations.

## Marker Syntax

```
㊷[user comment]{agent question}[user reply]{agent question}[user reply]
```

- `[]` = user turn, `{}` = agent turn
- Strictly alternating: `[user]{agent}[user]{agent}...`
- First bracket is always `[]` (user initiates)
- Odd section count = ready for agent submission
- Even section count = agent asked a question, awaiting user response
- Markers inside fenced code blocks are ignored by the parser

Examples:
- `㊷[too offensive]` — ready for agent (1 section, odd)
- `㊷[too offensive]{which part specifically?}` — needs user response (2 sections, even)
- `㊷[too offensive]{which part?}[the Asian joke]` — ready for agent (3 sections, odd)

Bracket handling: the parser matches brackets greedily to the outermost
closing bracket of the same type. Nested brackets within content are allowed.

## Editing Levels

Two levels on a single axis — same markers, different system prompts:

| Binding   | Level           | Behavior                                                    |
|-----------|-----------------|-------------------------------------------------------------|
| `<C-g>ve` | Light edit      | Fix what's pointed out. Keep structure, tone, wording intact. Copy editing level. |
| `<C-g>vr` | Heavy revision  | Rewrite paragraphs if needed. Substantive editing level.    |

The comment text itself carries intent — `㊷[typo: "teh"]` is obviously light,
`㊷[this argument is unconvincing, needs examples]` is obviously heavy. The
editing level sets the guardrails on how far the agent is allowed to go, not
what it should do.

Note: idea forming / document formalization (the far end of the spectrum) stays
with parley chat / `<C-g>C` where it belongs. This feature covers editing of
existing text, not generation.

## Keybindings (markdown files only)

| Binding    | Action                                                      |
|------------|-------------------------------------------------------------|
| `<C-g>vi`  | Insert `㊷[]`, cursor inside brackets, enter insert mode    |
| `<C-g>ve`   | Light edit — submit markers for conservative editing        |
| `<C-g>vr`   | Heavy revision — submit markers for substantive rewriting   |

Visual mode support for `<C-g>vi`: if text is selected, wrap selection with
`㊷[` and `]`.

Registered as buffer-local keymaps via `FileType markdown` autocmd.

Configured via `config.lua`:
```lua
review_shortcut_insert  = { modes = { "n", "v" }, shortcut = "<C-g>vi" },
review_shortcut_edit    = { modes = { "n" }, shortcut = "<C-g>ve" },
review_shortcut_revise  = { modes = { "n" }, shortcut = "<C-g>vr" },
```

## Submit Flow (`<C-g>ve` / `<C-g>vr`)

1. If buffer has unsaved changes, save first (`:write`)
2. Scan buffer for all `㊷` markers
3. Parse each marker's section count (odd/even)
4. If any markers have even section count (pending agent questions):
   - Populate quickfix with those locations + the agent's question
   - Notify user: "N markers need your response"
   - Stop — do not submit
5. If all markers have odd section count (all ready):
   - Send full buffer content to LLM with the appropriate system prompt
     (light edit vs heavy revision, based on which keybinding was used)
   - Agent responds with `review_edit` tool call
   - Apply edits to file on disk, reload buffer via `:checktime`
   - Temporarily highlight edited regions (fade after configured duration)
   - Attach `explain` fields as diagnostics (INFO level, `parley_review` namespace)
   - Re-scan buffer for remaining `㊷` markers:
     - If markers with `{}` questions remain → populate quickfix, notify user
     - If markers without `{}` remain (agent missed them) → auto-resubmit once
     - If no markers remain → notify "All comments addressed"

## Custom Tool: `review_edit`

**Not registered in global tool registry.** Private tool definition passed to
the LLM in the request payload, handled locally by `review.lua`.

Single tool call with all edits bundled:

```json
{
  "name": "review_edit",
  "input": {
    "file_path": "/path/to/file.md",
    "edits": [
      {
        "old_string": "The joke about Asian people was hilarious.\n㊷[too offensive]",
        "new_string": "Cultural exchange creates mutual understanding.",
        "explain": "Replaced offensive joke with constructive framing"
      },
      {
        "old_string": "㊷[too casual]",
        "new_string": "㊷[too casual]{do you mean this section or the whole doc?}",
        "explain": "Scope unclear, asking for clarification"
      }
    ]
  }
}
```

Schema:
```lua
{
  name = "review_edit",
  kind = "write",
  description = "Edit a document to address review comments. Each edit replaces old_string with new_string and includes an explanation.",
  input_schema = {
    type = "object",
    properties = {
      file_path = { type = "string", description = "Absolute path to the file" },
      edits = {
        type = "array",
        items = {
          type = "object",
          properties = {
            old_string = { type = "string", description = "Exact text to find and replace" },
            new_string = { type = "string", description = "Replacement text" },
            explain = { type = "string", description = "Brief explanation of why this change was made" },
          },
          required = { "old_string", "new_string", "explain" },
        },
      },
    },
    required = { "file_path", "edits" },
  },
}
```

### Apply Strategy

Edits are applied to the **file on disk**, then buffer reloaded via `:checktime`:
- Reuses the same file I/O pattern as the existing `edit_file` tool
- Works naturally with undo (reload creates a single undo point)
- Edits applied in **reverse document order** (bottom-to-top) to prevent position shifts
- `file_path` validated against current buffer's file; mismatch → reject with warning

## System Prompts

### Shared preamble

```
You are a collaborative document editor. The user has annotated their markdown
document with review comments using ㊷[comment] markers.

Marker syntax — strictly alternating turns:
  ㊷[user comment]{agent question}[user reply]{agent question}...
- [] brackets are always user comments or responses
- {} brackets are always your (agent) questions
- If a marker has a conversation (e.g. ㊷[comment]{question}[answer]),
  the user has answered your question — now address it using that context.

Use the review_edit tool to make all changes in a single call. Include a brief
explanation for each edit. The old_string must include the ㊷ marker and
enough surrounding context to be unique in the document.
```

### Light edit suffix (`<C-g>ve`)

```
Editing level: LIGHT EDIT (copy editing)

Rules:
- Fix only what each comment points out. Do not rewrite surrounding text.
- Preserve the author's structure, tone, voice, and wording.
- Make the minimum change that addresses the comment.
- When a comment's intent is ambiguous, ask — don't guess.
  Use ㊷[original comment]{your question} and do NOT edit surrounding text.
```

### Heavy revision suffix (`<C-g>vr`)

```
Editing level: HEAVY REVISION (substantive editing)

Rules:
- You have license to rewrite paragraphs, restructure sections, and make
  substantial changes to address each comment.
- Preserve the author's core intent and meaning, but feel free to change
  wording, tone, structure, and flow.
- Address the spirit of the comment, not just the literal request.
- When a comment's intent is ambiguous, make your best judgment and explain
  in the edit's explanation field. Only ask via {} for truly unclear cases.
```

## Architecture

### New module: `lua/parley/review.lua`

Responsibilities:
- `parse_markers(lines)` — pure function: scan lines, return list of markers.
  Skips markers inside fenced code blocks.
- `submit_review(buf, level)` — orchestrate: save, collect text, call LLM,
  apply edits, highlight, diagnostics. `level` is `"edit"` or `"revise"`.
  Includes one auto-retry if markers remain without agent questions.
- `check_pending(buf)` — find markers needing user input, populate quickfix
- `apply_edits(file_path, edits)` — apply old/new replacements to file, bottom-to-top
- `highlight_edits(buf, edits)` — temporary extmark highlights in
  `parley_review_hl` namespace, cleared at start of each review cycle
- `attach_diagnostics(buf, edits)` — INFO diagnostics in `parley_review`
  namespace, cleared at start of each review cycle

### Headless LLM call

Direct API call without chat_respond/tool_loop pipeline:

1. Build payload manually: system prompt + user message (full document) +
   `review_edit` tool definition
2. Call `D.query()` with no-op streaming handler, collect full response in callback
3. Extract tool_use blocks from response — requires factoring out tool call
   parsing from existing provider pipeline into a reusable function
   (e.g., `providers.extract_tool_calls(response)`)
4. Execute `review_edit` handler locally (not through `tools/dispatcher`)
5. Apply results, highlight, diagnostics

### Provider compatibility

Review requires tool_use support. Currently only Anthropic (and cliproxyapi)
providers support tool use. If the configured review agent uses an unsupported
provider, show error: "Review requires a provider that supports tool use."

### Reused infrastructure

- **Provider API calls** — `dispatcher.lua` (`D.query()`)
- **Config keybinding pattern** — same as `chat_shortcut_*`, buffer-local via autocmd
- **Highlight** — extmarks with dedicated namespace

### Not reused

- **Tool registry** — `review_edit` is private to this module
- **chat_respond / tool_loop** — no chat buffer, no exchange model
- **Tool dispatcher** — edits handled locally

## Config

```lua
-- Agent to use for review. Empty = last-used agent. Falls back to first
-- agent with tool-use-capable provider. Error if none found.
review_agent = "",
-- How long edit highlights persist (ms)
review_highlight_duration = 2000,
-- Keybindings
review_shortcut_insert  = { modes = { "n", "v" }, shortcut = "<C-g>vi" },
review_shortcut_edit    = { modes = { "n" }, shortcut = "<C-g>ve" },
review_shortcut_revise  = { modes = { "n" }, shortcut = "<C-g>vr" },
```

## Syntax Highlighting

Applied to markdown buffers via `FileType` autocmd:
- `ParleyReviewUser` — `㊷[...]` user comment markers (linked to `DiagnosticWarn`)
- `ParleyReviewAgent` — `{...}` agent questions within a marker chain (linked to `DiagnosticInfo`)
- `ParleyReviewEdit` — temporary highlight on edited regions (linked to `DiffChange`),
  cleared after `review_highlight_duration`

## Edge Cases

- **Multiple markers on same line**: each parsed independently
- **Marker spans multiple lines**: `old_string` handles this naturally
- **Markers inside code fences**: skipped by parser
- **Nested brackets**: balanced bracket matching
- **Agent returns no edits**: notify "Agent made no changes"
- **Agent misses markers**: auto-resubmit once, then stop and notify
- **Unsaved buffer**: auto-save before submitting
- **`file_path` mismatch**: reject edits, warn user
- **Review while highlights active**: clear previous highlights/diagnostics first
- **Non-tool-use provider**: error with clear message

## Testing Strategy

- `parse_markers` — pure function, unit-testable: various patterns, code fences,
  nested brackets, edge cases
- `apply_edits` — unit-testable: file string manipulation with reverse ordering
- System prompt — integration test with mock LLM response for full flow
- Keybinding registration — verify buffer-local on markdown, absent on other filetypes
