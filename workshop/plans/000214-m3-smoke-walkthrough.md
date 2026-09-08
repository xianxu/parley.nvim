# #214 smoke test — keybinding curation + the branch chord

Everything below is in a **chat buffer** unless it says otherwise.
Reference behaviour I verified headlessly is noted; what I cannot verify is how
it *feels*, and whether the terminal delivers the chord at all.

## 1. The branch chord — `<M-i>` (aliases `<M-S-CR>`, `<C-g>i`)

`<M-S-CR>` will still resize panes for you: couch's zellij config forwards it as
CSI-u, but that config is not installed at `~/.config/zellij/config.kdl`, so
zellij eats it first. Use `<M-i>`.

| # | do this | expect |
|---|---|---|
| 1.1 | select a phrase in an answer, `<M-i>` | the phrase becomes `[🌿:phrase](file)` **in place**, you stay in the parent; the child opens with `tell me more about "phrase"` and its `topic:` is the phrase |
| 1.2 | cursor anywhere, no `<M-q>` markers pending, `<M-i>` | a bare `🌿:` line lands **at the cursor** with a blank each side; **nothing else changes**; an empty child opens in insert mode |
| 1.3 | leave one or more `<M-q>` comments, then `<M-i>` | the markers are stripped, the quoted spans get `[…]`, the `🌿:` lands **at the cursor**, and the child opens seeded with those quotes |

Then, the two that used to be broken:

- **1.4** after 1.3, put the cursor on that same question and `<M-CR>` (resubmit).
  The `🌿:` line must **survive**. It used to be deleted, orphaning the child.
- **1.4b** the same after **1.1** (the visual case): resubmit that question, and
  the inline `[🌿:phrase](file)` must survive too — it is reformatted into a
  standalone `🌿:` line, because the sentence around it belonged to the answer
  being replaced. This was a separate bug from 1.4: the fix for the line form did
  not cover the inline one.
- **1.5** open the child from 1.3. It must contain real lines — not `^@^@`
  between the quotes. That was the NUL bug you caught.
- **1.6** while a response is streaming, press `<M-i>` in that chat. It should
  decline with a message, in **all three** of normal/insert/visual.

## 2. Annotations are single-line

- **2.1** drop a `🔒: note` in the *middle* of a long answer, then ask a
  follow-up. The text *after* the note must still reach the model — previously
  everything after it was silently dropped from the submission.
- **2.2** same for a `🌿:` line sitting mid-answer.
- **2.3** the `🔒:` line itself must not appear in what you send.

## 3. Keybinding policy

- **3.1** `<C-g>?` — the float should now show **aliases**, e.g.
  `<M-i>` … `(also <M-S-CR>, <C-g>i)`. `<M-q>` and `<M-t>` should be visible.
- **3.2** no `<leader>` key is bound by default. `<leader>cc`, `<leader>cl`,
  `<leader>fo` should all do nothing (they are one config line away — see the
  paste block in `lua/parley/config.lua`).
- **3.3** spell typeahead is **off** by default; squiggles stay on. Insert-mode
  `<CR>` should be yours (cmp/blink unaffected).
- **3.4** `<C-n>i` then `<C-n>I` (interview mode on, then off) must **restore**
  your own insert-mode `<CR>` map rather than delete it.
- **3.5** with interview mode ON, open a chat file. It must not error — that
  raised `Cannot deepcopy object of type userdata` for the last ~16 months.
- **3.6** put `default_keymaps = false` in your setup{}: parley should claim
  nothing. Add one explicit `shortcut = "…"` alongside it — that one must still
  bind.

## Known, not defects

- `<M-i>` into an agent pane fails when the pane wants a menu answer (#217 item 6).
- `<M-S-CR>` needs couch's zellij config actually installed; the repo has it,
  `~/.config/zellij/config.kdl` does not.
