---
topic: 1. Welcome to Parley
file: welcome.md
tags:
---

# Welcome to Parley

Parley is a chat workspace built on Neovim. This Markdown document is your
transcript. You ask questions after 💬: - the AI answers after 🤖:.

For those new to VIM, a crash course:
1. Press `ESC` to enter **NORMAL** mode, where pressing key moves cursor instead
   of inserting text. When in NORMAL mode, press `:` to enter i**COMMAND** mode.
2. Press `i` to enter **INSERT** mode at current cursor, then just type text in.
3. To exit parley, in NORMAL mode (so `ESC`), issue command `:q` and `return`.

For VIM users, all the usual keybindings work the same. You may also want to
install the parley.nvim plugin within your own Neovim configurations.

To start chatting, connect an AI account. You need a paid subscription.

1. Connect a provider when prompted. You can also run `:ParleyProxy connect`.
2. Choose a model when prompted, or use `:ParleyAgent`.
3. Press `i` to type after the question marker 💬: below.
4. Press `option+return` to send. `:ParleyChatRespond` also works.

Parley packages its own help and allow AI to query it through what's called a
tool call. That's why you can just ask in Parley, about how to use Parley!

To learn more: press `option+f`, select next chat: [Basics](basics.md). You 
can also navigate to that file by putting cursor on ./basics.md, and press
`option+o`.

One last thing: try command `:ParleyTheme` (in NORMAL mode), to switch to a
theme you love! Once you are in COMMAND mode (press `:`), you can just type
part of a command name; for example, `parthem` matches ParleyTheme.

New to Vim? Open [4. VIM Basics](vim-basics.md) for navigation, undo, search,
and everyday editing. In Normal mode, put the cursor on the link and press
`option+o`.

💬: Hello! What is Parley, and How do I use it? Keep it concise.

