---
id: '000214'
status: done
started: 2026-09-05T22:03:29-07:00
created: 2026-09-02
updated: 2026-09-08
estimate_hours: 3.83
actual_hours: 17.14
---

# audit and curate the default keybinding surface

## Problem

Parley claims a large share of the user's keyspace by default, and the claim was
never curated — bindings accumulated as features were added. Today
`lua/parley/config.lua` ships **65 default shortcuts** across six prefix
families:

| Family | Count | Keys |
|---|---|---|
| `<C-g>` chat/parley | 24 | the core chat surface |
| `<C-n>` notes | 4 | `c f h r` |
| `<C-y>` issues | 6 | `c f g i s x` — ariadne |
| `<C-j>` vision | 6 | `ec ed f n o v` — ariadne |
| `<leader>` | 6 | `cc cC cf cl cL` **plus `fo`, which maps oil.nvim** — a plugin parley never requires |
| other | 19 | `gf`, `gP`, `<M-CR>`, `<M-o>`, and finder-local keys |

Three separate defects sit underneath that count.

**1. Ten bindings cannot be rebound or disabled at all.** The registry
(`keybinding_registry.lua`) holds 78 entries, 68 with a `config_key` the user can
override and **10 registry-only**:

```
interview_start         <C-n>i            note
interview_stop          <C-n>I            note
note_template           <C-n>t            note
outline                 <C-g>t, <M-t>     parley_buffer
branch_ref              <C-g>i            parley_buffer
chat_toggle_web_search  <C-g>w            chat
chat_drill_in           <C-g>q, <M-q>     parley_buffer
chat_accept_drill_in    <M-a>             parley_buffer
chat_reject_drill_in    <M-r>             parley_buffer
md_delete_file          <C-g>d            markdown
```

`<M-q>` is a headline feature and `md_delete_file` **deletes a file** — neither
can be moved off a colliding key.

**2. Four bindings are made outside the registry entirely**, so they appear in no
audit surface, in no `<C-g>?` help, and in no config:

- `u` and `<C-r>` are shadowed in chat buffers (`init.lua:2213,2216`)
- `<CR>` is rebound in insert mode by spell typeahead (`spell.lua:168`) and again
  by interview mode (`interview.lua:85`) — colliding with cmp/blink, which nearly
  every Neovim user has on `<CR>`

**3. The core/peripheral line was never drawn.** Ariadne workflow keys
(`<C-y>*`, `<C-j>*`), the `<leader>` copy helpers, and an oil.nvim mapping all
ship with the same default status as `<C-g>c`.
