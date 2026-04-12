---
id: 000098
status: working
deps: []
created: 2026-04-11
updated: 2026-04-12
---

# a document review tool in parley

center around markdown files, and use special syntax to allow users to comment on a document. e.g. maybe with syntax like: ㊷[I found this too offending]

then create get agent to update the draft based on those notes, their goal is to remove those ㊷[comments] while incorporating the comment into their update. 

This would result in a series of edit_file tool call. 

We need some good system prompts. For example, comments assumed to be local, but can also be global, depending on the comment itself. 

I can also see agent decide to address some aspect of comment, and ask more questions for a command, thus creating a loop. In that case, I suspect it can look something like: 

㊷[I found this too offending]<can you be more specific?>

And then we can have binding for user to add more context, e.g. maybe the quick fix. and user is supposed to then replace that to.

㊷[I found this too offending]<can you be more specific?>[referring to the joke about Asian people]

So basically fix to quick fix is if you have odd number of those sections. do create coloring for <> for markdown.

There would be some key binding to check if there are any remaining things. 

keybindings:

<C-d>i: insert a ㊷[comment], cursor inside [] and in insert mode.
<C-d>r: trigger agent rewrite based on feedback in ㊷[comment]. 
<C-d>v: validation, e.g. are there user comment left unaddressed replaced or with <follow up questions>. there are two states here. after <C-d>r, in normal situation, all comments are addressed, or <follow up question asksed>. however, if this didn't happen, I guess we will just keep trying to submit to agent.

this needs tool call, basically agent both need to provide what to edit, and also tool calls (edit_file) to actually change the current file.

## Spec

See `workshop/plans/000098-document-review-plan.md` for full design spec.

Summary: Headless LLM-powered review for markdown files. Users annotate with
`㊷[comments]`, submit via `<C-g>v` (light edit) or `<C-g>V` (heavy revision).
Agent responds with `review_edit` tool call. Edits applied to file, highlighted
temporarily, explanations shown as diagnostics. Agent can ask follow-up via `{}`
brackets; quickfix used to navigate pending items.

## Done when

- `<C-g>vi` inserts marker, visual mode wraps selection
- `<C-g>v` and `<C-g>V` submit to LLM and apply edits
- Edits highlighted temporarily, explanations as diagnostics
- Quickfix populated for pending agent questions
- Auto-resubmit once if agent misses markers
- Syntax highlighting for `㊷[...]` and `{...}` in markdown
- Unit tests for marker parsing and edit application

## Plan

### M1: Core module — marker parsing + edit application (pure functions) ✓
- [x] 1.1 Create `lua/parley/review.lua` with module skeleton
- [x] 1.2 Implement `parse_markers(lines)` — scan lines for `㊷` markers, return structured list with line/col/sections/ready. Skip markers inside fenced code blocks. Handle nested brackets.
- [x] 1.3 Implement `apply_edits(file_path, edits)` — read file, apply old_string→new_string replacements in reverse document order, write file. Adapted from `edit_file.lua` handler logic.
- [x] 1.4 Write tests: `tests/unit/review_spec.lua` — 14 parse_markers tests + 8 apply_edits tests. All passing.
- [x] 1.5 Run tests, verify passing (0 new failures, 1 pre-existing in picker_items_spec)

### M2: Headless LLM call + tool response handling ✓
- [x] 2.1 Implement payload building inline in `submit_review` — system prompt (light/heavy), user message, `review_edit` tool definition
- [x] 2.2 Implement `submit_review(buf, level)` — save, read, build payload, `D.query()` headless, parse tool_use via `on_exit` + `tasker.get_query(qid).raw_response`, apply edits, `:checktime`
- [x] 2.3 `REVIEW_EDIT_TOOL` as local constant (not in global registry)
- [x] 2.4 Config entries added: `review_agent`, `review_highlight_duration`, 3 keybinding shortcuts
- [x] 2.5 `resolve_review_agent()`: configured → last-used → first tool-capable → error
- [x] 2.6 Provider guard in `resolve_review_agent()` (anthropic/cliproxyapi only)

### M3: Keybindings + UI feedback ✓
- [x] 3.1 `setup_keymaps(buf)` registers `<C-g>vi` (insert/wrap), `<C-g>ve` (light edit), `<C-g>vr` (heavy revision) as buffer-local on markdown. Called from `setup_markdown_keymaps` in init.lua.
- [x] 3.2 Submit calls `submit_review(buf, "edit")` / `submit_review(buf, "revise")`
- [x] 3.3 `populate_quickfix(buf, markers, "pending")` — quickfix with agent questions
- [x] 3.4 Post-edit flow in `submit_review`: re-scan, quickfix if questions, auto-resubmit once if missed
- [x] 3.5 `highlight_edits(buf, edits, new_content, duration)` — extmarks in `parley_review_hl` namespace, `vim.defer_fn` fade
- [x] 3.6 `attach_diagnostics(buf, edits, original_content)` — INFO diagnostics in `parley_review` namespace

### M4: Syntax highlighting + polish
- [x] 4.1 `ParleyReviewUser` (DiagnosticWarn) + `ParleyReviewAgent` (DiagnosticInfo) highlight groups in highlighter.lua. Decoration provider highlights ㊷[...] and {...} in markdown buffers.
- [x] 4.2 Notification messages via `_parley.logger.info/warning` throughout submit_review flow
- [ ] 4.3 Manual testing with real LLM — verify end-to-end flow
- [x] 4.4 Atlas updated: `atlas/modes/review.md` + index entry

## Log

### 2026-04-12
- Brainstorming complete. Design decisions:
  - `㊷` marker with `[]` user / `{}` agent alternating syntax
  - Two editing levels via keybinding: `<C-g>v` (light) / `<C-g>V` (heavy)
  - Headless (no chat buffer), stateless (full doc each call)
  - Custom `review_edit` tool (private, not in global registry) with `{old_string, new_string, explain}` triples
  - File-based edits + `:checktime` reload
  - Quickfix for pending agent questions
  - Diagnostics for edit explanations
- Can reuse `providers.decode_anthropic_tool_calls_from_stream()` directly for tool extraction
- Can adapt `edit_file.lua` handler's replacement logic for `apply_edits`

### 2026-04-11

