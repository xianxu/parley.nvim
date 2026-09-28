---
topic: 4. VIM Basics
file: vim-basics.md
tags:
---

# VIM Basics

Parley is a text editor as well as a chat app. These few habits make it easier
to edit questions, explore answers, and recover from mistakes. Try them in your
copy of this lesson; you can undo your edits.

## First: check your mode

The bar at the bottom says **NORMAL**, **INSERT**, or **VISUAL**.

- **Normal** is for moving and giving commands. Press `Esc` to return here.
- **Insert** is for typing. From Normal, press `i` to type before the cursor,
  or `a` to type after it. Press `Esc` when finished.
- **Visual** is for selecting. From Normal, press `v`, then move to extend the
  selection. Press `Esc` to cancel.

Shortcuts below start in **Normal** unless stated otherwise. `Ctrl+o` means
hold Control and press o; `gg` means press g twice.

## Move around

Use the arrow keys in Normal or Insert. In Normal and Visual, Up/Down follow
visible wrapped lines; in Insert, they move between text lines. In Normal, `w` moves to the next word, `b` to the previous word,
`0` to the start of a text line, and `$` to its end. `gg` goes to the top of the
chat; `G` (Shift+g) goes to the bottom.

## Find something, then go back

In Normal, type `/` followed by text and press `Enter`. `n` goes to the next
match; `N` goes to the previous one. Press `Esc` to cancel an unfinished search.

The app uses **smart-case search**: `/rainbow` finds both `rainbow` and `Rainbow`;
`/Rainbow` finds only the capitalized version. These examples use plain text;
some punctuation has special meaning in searches.

Try it in this chat:

1. In Normal, press `gg`, then type `/^practice-rainbow` and press `Enter` to
   jump to the practice line near the bottom (`^` means start of line).
2. Press `Ctrl+o` to go **back** to where you searched from.
3. Press `Ctrl+i` to go **forward** to the practice line again.
4. Type `/rainbow` and press `Enter`, then try `n` and `N`. Repeat with `/Rainbow`
   to see the difference. Type `:nohlsearch` and press `Enter` to clear highlighting.

Think of Ctrl+o / Ctrl+i as Back / Forward for **jump locations**, including
searches and large jumps, rather than every arrow-key movement. Tab often sends
the same key as Ctrl+i; the app leaves both available for forward navigation in
Normal mode. They have different jobs while typing or inside a picker.

## Fix a mistake

At the practice line, press `A` (Shift+a) in Normal to type at the end. Add
` hello`, then press `Esc`. Press `u` in Normal to **undo** that edit; press
`Ctrl+r` in Normal to **redo** it. You can repeat undo to step farther back.
Escape ends a typing session; several characters typed together can undo as
one edit. These keys edit the document, not a request already sent to an AI.

## Select, copy, cut, and paste

In Normal, press `v` and use the arrows to select text. While in Visual, `y`
**copies** the selection and `d` **cuts** it; both return to Normal. In Normal,
`p` pastes after the cursor, or on the next line for copied whole lines.
`P` pastes before the cursor (above for whole lines).

For a whole line, use `V` (Shift+v) in Normal, then `y` or `d`. Try `V`, `y`,
then `p` on the practice line to duplicate it; press `u` to undo the paste.

The app connects these copy/cut/paste keys to the system clipboard when Neovim
has a working clipboard provider. Without one they still work inside Neovim,
but copying to another app may not. Terminal copy/paste shortcuts also depend
on your terminal; `Ctrl+c` / `Ctrl+v` are not Vim's copy/paste pair.

## Save and keep going

Parley autosaves chats. To save explicitly, press `Esc`, type `:w`, then press
`Enter`. To save and quit, use `:wq` then `Enter` in Normal.

For this exercise, edit only the practice text; keep the `💬:` question marker.
To return to the [Welcome](welcome.md), put the cursor on its link and press
`option+o` in Normal. Find these lessons again with `option+f` in Normal or
Insert. More Parley actions are in [Basics](basics.md) and [Advanced](advanced.md).

## Practice

practice-rainbow: rainbow Rainbow RAINBOW

💬: Help me practice one everyday editing action in Parley. Give me a small
exercise, tell me which mode to start in, and wait for me to try it.
