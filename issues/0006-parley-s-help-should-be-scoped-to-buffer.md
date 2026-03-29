---
id: 0006
status: done
deps: []
created: 2026-03-28
updated: 2026-03-28
---

# parley's help should be scoped to buffer

For example, when in chat buffer, the help should contain global hotkeys plus what are available in chat buffer. 

Same goes for notes and issues files. Not sure if there are strict definition of what are notes or issues. Show me a design proposal here.

## Done when

- `:ParleyKeyBindings` / `<C-g>?` shows only the keybindings relevant to the current buffer context

## Design Proposal

### Current State

`keybinding_help_lines()` in `init.lua:997` always builds the same flat list with sections: **Global**, **Chat / Markdown**, **Chat Finder**, **Note Finder**. Every section is always shown regardless of buffer type.

### Buffer Context Detection

Parley already distinguishes buffer types at `BufEnter` time (in `highlighter.setup_buf_handler()`):
- **Chat buffer**: `M.not_chat(buf, file_name)` returns nil → valid chat
- **Markdown buffer**: `M.is_markdown(buf, file_name)` → markdown but not a chat

We need to add two more:
- **Note buffer**: markdown file whose path is under `config.notes_dir`
- **Issue buffer**: markdown file whose path is under `{git_root}/{config.issues_dir}`

Detection function (pure, testable):

```lua
-- Returns one of: "chat", "note", "issue", "markdown", "other"
local function detect_buffer_context(buf)
  local file_name = vim.api.nvim_buf_get_name(buf)
  if not M.not_chat(buf, file_name) then return "chat" end
  if M.is_markdown(buf, file_name) then
    -- Check note vs issue by path prefix
    local notes_dir = vim.fn.resolve(M.config.notes_dir)
    if file_name:sub(1, #notes_dir) == notes_dir then return "note" end
    local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1] or ""
    local issues_dir = vim.fn.resolve(git_root .. "/" .. M.config.issues_dir)
    if file_name:sub(1, #issues_dir) == issues_dir then return "issue" end
    return "markdown"
  end
  return "other"
end
```

### Help Content by Context

| Section | `other` | `chat` | `markdown` | `note` | `issue` |
|---------|---------|--------|------------|--------|---------|
| Global (always) | yes | yes | yes | yes | yes |
| Global > Chat shortcuts | yes | yes | — | — | — |
| Global > Note shortcuts | yes | — | — | yes | — |
| Global > Issue shortcuts | yes | — | — | — | yes |
| Global > Toggles | yes | yes | — | — | — |
| Chat Buffer | — | yes | — | — | — |
| Markdown Buffer | — | — | yes | yes | yes |
| Chat Finder | — | — | — | — | — |
| Note Finder | — | — | — | — | — |

Key decisions:
- **`other` (no special buffer)**: Show all global keybindings as a complete reference since user isn't in any context yet.
- **Finder sections omitted from buffer help**: Finder keybindings are contextual to the finder itself; they're visible in the finder's `<C-g>?` if we wire that up. For buffer help, they add noise.
- **`markdown` gets markdown-specific keys**: `<C-g>o` (open file), `<C-g>f` (find chat refs), `<C-g>a` (add chat ref), `<C-g>i` (insert new chat ref), `<C-g>d` (delete file).
- **`note` and `issue` inherit markdown keys**: Since both are markdown files with `setup_markdown_keymaps()` applied.
- **Title reflects context**: e.g. "Parley Key Bindings (Chat)" or "Parley Key Bindings (Note)".

### Implementation Approach

1. Add `detect_buffer_context(buf)` function (pure logic, easy to test)
2. Refactor `keybinding_help_lines()` to accept context string and conditionally include sections
3. The existing `resolve_shortcut()` mechanism stays unchanged — it already reads runtime keymaps for the current buffer
4. Break the monolithic `keybinding_help_lines()` into helper functions per section: `_add_global_lines()`, `_add_chat_lines()`, `_add_markdown_lines()`, `_add_finder_lines()`
5. Update `specs/ui/keybindings.md`

### Open Questions for User

1. **Should `other` show everything?** When `<C-g>?` is pressed from a non-parley buffer, should it show all sections as a complete reference, or just globals?
2. **Issue-specific keybindings**: Currently issues have no buffer-local keybindings (only global shortcuts like `<C-y>s` status, `<C-y>i` decompose). Should we show these in the issue context's global section?
3. **Finder help**: Should each finder (`<C-g>?` within a finder) show its own contextual help? Currently `<C-g>?` in chat finder opens the global help window.

## Plan

- [x] Design approval
- [x] Implement `detect_buffer_context()`
- [x] Refactor `keybinding_help_lines(context)` to be context-aware
- [x] Add issue-specific global shortcuts to help (`<C-y>c/f/x/s/i`)
- [x] Update finder `<C-g>?` handlers to pass finder context
- [x] Add `<C-g>?` to issue finder
- [x] Update `specs/ui/keybindings.md`
- [x] Update tests
- [x] Manual verification in Neovim

## Log

### 2026-03-28

- Explored current help system: `keybinding_help_lines()` at init.lua:997 builds flat list, always shows all sections
- Buffer detection exists for chat (`not_chat`) and markdown (`is_markdown`) but not for notes or issues
- Notes = markdown under `config.notes_dir`, Issues = markdown under `{git_root}/config.issues_dir`
- Issue keybindings (`<C-y>*`) were missing from the help window entirely — now added
- Implemented `detect_buffer_context()` to classify buffers as chat/note/issue/markdown/other
- Refactored `keybinding_help_lines(context)` to show only relevant sections per context
- Finder contexts (chat_finder/note_finder/issue_finder) show only finder-specific keys
- Added `<C-g>?` mapping to issue finder (was missing)
- Updated chat_finder and note_finder to pass explicit context to KeyBindings
- Rewrote keybindings_spec.lua to test each context independently — all pass
- Lint clean (1 pre-existing warning in outline.lua), all 44 test suites pass
