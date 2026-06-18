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
- `<>`/`[]`/`{}` sections may span **multiple lines**, each bounded to ~50 lines (per-section budget) so a stray opener can't swallow the document; `~D~` strike stays single-line (added in #125). `parse_markers` parses over the whole buffer joined (offset→line/col map) rather than line-by-line; `find_matching_bracket` takes an optional `{budget, is_excluded}` so the shared `_parse_marker_sections` (highlighter, drill_in) keeps its single-text behavior. Unterminated openers fall back to silent non-recognition.

## Keybindings (non-chat markdown only)

| Binding         | Action                                                          |
|-----------------|-----------------------------------------------------------------|
| `<M-q>` / `<C-g>q` | Insert `🤖<sel>[]` (visual) or `🤖[]` (normal/insert). Shared with chat — see `atlas/chat/drill_in.md`. |
| `<M-a>`         | Accept the marker at cursor per [review-convention §5](../../../ariadne/workshop/targets/review-convention.md) |
| `<M-r>`         | Reject the marker at cursor per review-convention §5            |
| `<C-g>ve`       | Run the review skill (agent edits per ready markers)            |
| `<C-g>vf`       | Open the review finder (jump to files with pending markers)     |

## Architecture

Review is implemented as a **skill** in the unified skill system (see `atlas/index.md` §8).

- **Skill module**: `lua/parley/skills/review/init.lua` — marker parsing, `run_via_invoke` (marker pre-check + resubmit), keybindings
- **System prompt**: `lua/parley/skills/review/SKILL.md`
- **Driver**: `lua/parley/skill_invoke.lua` — one tool-use exchange on the existing dispatcher (the `skill_runner` engine was deleted in M4; both review and voice-apply run through this driver)
- **Rendering**: `lua/parley/skill_render.lua` — diagnostics + edit highlights
- **Shim**: `lua/parley/review.lua` — backward-compatible re-exports for existing callers
- **Headless**: Direct API call, no chat buffer, no exchange model
- **Stateless**: Each submit sends full document; markers carry conversation history
- **Tool**: `propose_edits` tool with `{old_string, new_string, explain}` triples (forced via `tool_choice`)
- **Edits**: Applied to file on disk via the `propose_edits` builtin, buffer reloaded via `:edit!`
- **Feedback**: Highlights on edits (DiffChange), diagnostics from explain fields (INFO), quickfix for pending agent questions
- **Provider**: Requires Anthropic or cliproxyapi (tool_use support)

## Review Modes (#133)

Review runs in a selectable **mode** (a stage of document construction). A mode is
a sub-markdown file `lua/parley/skills/review/modes/<name>.md` = YAML frontmatter
(behavior flags) + a prompt body. One skill owns all modes; there is no parallel
engine — the review skill's `source(ctx)` composes `SKILL.md ⊕ mode.body ⊕
mode.directives(flags) ⊕ operator-instruction`. No mode selected → base SKILL.md
(the legacy marker-only review).

- **`lua/parley/skills/review/mode.lua`** — `parse(content)` (PURE: frontmatter →
  `{name,scope,deletions,frontier,body}`), `directives(m)` (PURE: flags → prose the
  model obeys), and the thin IO seam `load(dir,name)`/`list(dir)`. Canonical name ==
  file basename (kebab), so `load` resolves by the selected name; the M4 menu
  prettifies for display.
- **Behavior flags:** `scope` (`whole-doc` | `markers-only`), `deletions`
  (`apply-with-gutter-why` | `propose-strike` | `apply`), `frontier` (`on` | `off`
  — when on, treat text above the topmost `🤖[]` as settled).
- **Six shipped modes:** developmental, line-editing, copy-editing, proofreading,
  fact-check (inserts `🤖{}` findings only — no edits; resolution handed to the
  main agent), free-form (operator instruction governs).
- **`ctx.skill_dir` injection** (`skill_providers.lua`): the disk provider injects
  the skill's own absolute dir into `source(ctx)` (alongside `ctx.skill_md`) so the
  review skill reads its `modes/` subdir without re-deriving the path.

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

- `lua/parley/skills/review/init.lua` — skill definition (+ `source(ctx)` mode composition, `mode` arg), marker parsing, `run_via_invoke` (marker pre-check + resubmit), keybindings
- `lua/parley/skills/review/mode.lua` — Mode parse/directives (PURE) + load/list IO seam (#133)
- `lua/parley/skills/review/modes/*.md` — the six review-mode prompt files (#133)
- `lua/parley/skills/review/SKILL.md` — system prompt (light edit + heavy revision sections)
- `lua/parley/skill_invoke.lua` — the P2 driver (one tool-use exchange via the existing dispatcher)
- `lua/parley/skill_render.lua` — diagnostics + edit highlights
- `lua/parley/tools/builtin/propose_edits.lua` — batch edit-apply (inline `.parley-backup`)
- `lua/parley/review.lua` — backward-compatible shim
- `lua/parley/highlighter.lua` — `ParleyReviewUser`/`ParleyReviewAgent` groups
- `lua/parley/config.lua` — default keybindings and config
- `tests/unit/review_spec.lua` — unit tests for the marker parser
- `tests/integration/skill_invoke_review_spec.lua` — review's marker pre-check + resubmit
- `tests/unit/skill_edits_spec.lua` / `tests/unit/tools_builtin_propose_edits_spec.lua` — batch edit-apply
