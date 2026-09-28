---
topic: 4. VIM Basics
file: vim-basics.md
tags:
---

@@Table of Contents@@
[Welcome to Parley](welcome.md)
[Parley Basics](basics.md)
[Parley Advanced](advanced.md)
[VIM Basics](vim-basics.md)

# VIM Basics

Parley is a text editor as well as a chat app. These few habits make it easier
to edit questions, explore answers, and recover from mistakes. Try them in your
copy of this lesson; you can undo your edits.

## First: check your mode

The bar at the bottom says **NORMAL**, **INSERT**, or **VISUAL**.

- **NORMAL** is for moving and giving commands. Press `ESC` to return here.
- **INSERT** is for typing. From NORMAL, press `i` to type before the cursor,
  or `a` to type after it, or `A` to type at the end of the line. Press `ESC` when
  finished to return to NORMAL mode.
- **VISUAL** is for selecting. Use your mouse to select text.

Shortcuts below start in **NORMAL** unless stated otherwise. `Ctrl+o` means
hold Control and press o; `gg` means press g twice.

## Move around

Use the arrow keys in NORMAL or INSERT. In NORMAL and VISUAL, Up/Down follow
visible wrapped lines; in INSERT, they move between text lines. In NORMAL, `w`
moves to the next word, `b` to the previous word, `^` to the first nonblank character of a text
line, and `$` to its end. `gg` goes to the top of the chat; `G` (Shift+g) goes
to the bottom.

Press `Ctrl+o` to go back to an earlier jump location; press `Ctrl+i` to go
forward again. This also works across files.

Think of `Ctrl+o` / `Ctrl+i` as Back / Forward for **jump locations**, including
searches and large jumps, rather than every arrow-key movement.

## Find something, then go back

In NORMAL, type `/` followed by text and press `Return`. `n` goes to the next
match; `N` goes to the previous one. Press `ESC` to cancel an unfinished search.

The app uses **smart-case search**: `/rainbow` finds both `rainbow` and
`Rainbow`; `/Rainbow` finds only the capitalized version. These examples use
plain text; some punctuation has special meaning in searches.

Try it in this chat:

1. In NORMAL, press `gg`, then type `/^practice-rainbow` and press `Return` to
   jump to the practice line near the bottom (`^` means start of line).
2. Press `Ctrl+o` to go **back** to where you searched from.
3. Press `Ctrl+i` to go **forward** to the practice line again.
4. Type `/rainbow` and press `Return`, then try `n` and `N`. Repeat with
   `/Rainbow` to see the difference. Type `:nohlsearch` and press `Return` to
   clear highlighting.

## Fix a mistake

At the practice line, press `A` (Shift+a) in NORMAL to type at the end. Add
` hello`, then press `ESC`. Press `u` in NORMAL to **undo** that edit; press
`Ctrl+r` in NORMAL to **redo** it. You can repeat undo to step farther back.
Escape ends a typing session; several characters typed together can undo as
one edit.

## Select, copy, cut, and paste

Drag with your mouse to select text and enter VISUAL mode. While in VISUAL, `y`
**copies** the selection and `d` **cuts** it; both return to NORMAL. In NORMAL,
`p` pastes after the cursor, or on the next line for copied whole lines.
`P` pastes before the cursor (above for whole lines). With a working clipboard
provider, copied text also goes to your system clipboard. In a macOS terminal,
try `Command+v` in INSERT mode to paste what you just copied.

For a whole line, use `V` (Shift+v) in NORMAL, then `y` or `d`. Try `V`, `y`,
then `p` on the practice line to duplicate it; press `u` to undo the paste.

## Save and keep going

Parley autosaves chats. To save explicitly, press `ESC`, type `:w`, then press
`Return`. To save and quit, use `:wq` then `Return` in NORMAL.

## Practice

practice-rainbow: rainbow Rainbow RAINBOW

💬: Help me practice one everyday editing action in Parley. Give me a small
exercise, tell me which mode to start in, and wait for me to try it.
