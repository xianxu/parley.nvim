---
topic: 1. Welcome to Parley
file: welcome.md
tags:
---

# Welcome to Parley

Parley is a chat workspace built on Neovim. This Markdown document is your
transcript. You ask questions after 💬:; the AI answers after 🤖:.
Everything is editable.

VIM crash course:
1. `ESC` to enter NORMAL mode, where you press `:` to issue commands, like
   `:ParleyProxy connect` and press `return` key.
2. `i` to enter INSERT mode at current cursor, and you can then just type.
3. To exit, be in NORMAL mode (so `ESC`), then issue command `:q` and `return`.

To start chatting, connect an AI account:

1. Connect a provider when prompted. You can also run `:ParleyProxy connect`.
2. Choose a model when the picker opens, or use `:ParleyAgent`.
3. Press `i` to type after the question marker 💬: below.
4. Press Option+Enter to send. `:ParleyChatRespond` also works.

To learn more: press `ctrl+g` then `f`, and select chat [Basics](./basics.md).
You can also navigate to that file by putting cursor on ./basics.md, and press
`Option+o`.

💬: Hello! What is Parley, and How do I use it?
