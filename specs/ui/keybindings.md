# Spec: Key Bindings Help

## Command
- `:ParleyKeyBindings`: centered floating scratch window (`nofile`), close with `q`/`<Esc>`
- Accepts optional context parameter; auto-detects from current buffer when not provided

## Shortcuts
- `<C-g>?` (normal+insert) opens help; insert mode exits insert first
- `<C-g>h` (normal+insert) opens chat dirs picker

## Context-Scoped Display

Help content is scoped to the current buffer context:

| Context | Title | Sections |
|---------|-------|----------|
| `other` | Parley Key Bindings | Global core only |
| `chat` | Parley Key Bindings (Chat) | Global core, Chat (review, toggles, buffer actions) |
| `markdown` | Parley Key Bindings (Markdown) | Global core, Markdown Buffer |
| `note` | Parley Key Bindings (Note) | Global core, Note (interview, template), Markdown Buffer |
| `issue` | Parley Key Bindings (Issue) | Global core, Issue (`<C-y>*`), Markdown Buffer |
| `chat_finder` | Parley Key Bindings (Chat Finder) | Chat Finder keys only |
| `note_finder` | Parley Key Bindings (Note Finder) | Note Finder keys only |
| `issue_finder` | Parley Key Bindings (Issue Finder) | Issue Finder keys only |

## Context Detection

- Chat: `not_chat()` returns nil
- Note: markdown file under `config.notes_dir`
- Issue: markdown file under `{git_root}/config.issues_dir`
- Markdown: `.md`/`.markdown` file that isn't a chat, note, or issue
- Other: everything else

## Content Requirements

### Global core (all non-finder contexts)
- Key bindings help, new chat, chat finder, chat dirs, new note, note finder, year root, oil

### Chat section (own header, not under Global)
- Review, toggle web_search/raw request/raw response
- Buffer actions: respond, respond all, stop, delete, agent, system prompt, follow cursor, search sections, branch ref, open file, outline, prune, export markdown/HTML, cut/paste exchange

### Note section (own header, not under Global)
- Interview mode enter/exit, note from template

### Issue section (own header, not under Global)
- New, finder, next, status cycle, decompose

### Markdown Buffer (shown for markdown/note/issue)
- Open file reference, find chat, add chat reference, insert new chat, delete file

### Finder contexts
- Chat Finder: recency cycle left/right, delete, delete tree, move
- Note Finder: recency cycle left/right, delete
- Issue Finder: cycle status, toggle done/history, delete

## Resolution
- Shortcuts resolved from active runtime keymaps; fallback to configured defaults
