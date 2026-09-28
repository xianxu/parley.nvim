---
topic: 3. Advanced Topics
file: advanced.md
tags:
---

# Advanced Topics

Parley keeps your conversation in an editable document. This lesson explains
what the AI sees, how to navigate a growing conversation, and how to use a
project folder for chats, notes, and images.

Like `welcome.md` and `basics.md`, this tutorial has a stable file name.
Chat Finder displays its topic, "3. Advanced Topics".

## 1. Transcripts, turns, and what the AI sees

A transcript is the record of a conversation. A question after the 💬: marker 
and the answer after the 🤖: marker form an exchange. Each message sent or 
received is a turn. You can edit earlier text and ask again.

Sending does not upload the entire file unchanged. Parley builds a request from
the question at your cursor and the relevant conversation leading up to it,
including earlier questions and answers. It also supplies the selected system
instructions, any included file contents, images, or tool results needed for
that request. When the question asked is in a branched chat, all the exchanges 
on the path from that question to the root of the first question are included.

The text before the first question is not sent. That is why these tutorial
instructions live above the first question without becoming part of it
conversation. The span before first question can be used for Markdown style
notes.

A line beginning with the lock marker is a local note, excluded from the chat
text sent to the model, even if that line appears in the question/answer
exchange. For example:

@@Private notes@@
🔒: Remember to check this answer with my teacher; this is not included in
🔒: AI conversation.

Editing the transcript changes what a later request can see; it does not erase
anything already sent to a provider. Use a fresh chat when you want a new topic
without the preceding conversation.

## 2. Outline, branches, and markers

Press `option+t`. The chat outline includes questions, outline markers, and 
branches across the linked tree of chat. Selecting a branch opens its child 
file at the start; selecting a question or marker jumps to that line. A branch 
lets you explore a side question separately while keeping a link back to the
main conversation.

You can also put an outline marker using `@@tag@@` syntax, at a new line.

@@Rainbow research@@

Open the outline now and look for "Rainbow research". This is a navigation
marker, not the `tags:` metadata at the top of the file.

The same `@@...@@` syntax can refer to a local file for context. Use a 
descriptive label for an outline marker; use a real path only when you mean to
reference a file. 

## 3. A project folder: repo mode

When Parley is first installed, all chats created are at a common global 
folder. For advanced users who want to control more precisely where files 
are placed, enter the `repo mode`. 

A `repo`, or repository, is just a folder with a marker file `.parley` at its
root. When `parley` command is started from such a directory or its sub-
directories, chats go in `workshop/parley/` inside this folder. This folder
can be put in source control systems such as git, thus becomes a repository 
of your chats. This is also the origin of the `repo mode`.

To try it, close Parley, then run these commands in your terminal:

```sh
mkdir -p ~/parley-practice
cd ~/parley-practice
touch .parley
parley
```
One advanced topic is that by default, `Parley` is granted access to all files
in the repository, in `repo mode`. 

## 4. Local files as working material

Your chats are local Markdown files. Notes and other project files can be read
by you, by an editor, and by Parley's local tools. This gives a conversation 
additional context of those files, and lets a conversation produce something
useful beyond an answer on screen. You can ask AI to for example: 

  "Can you summarize what we talked about rainbows in research/rainbow.md?"

Parley will be able to generate that file, and summarize based on the 
conversation history.

## 5. Local tool calls and searching past chats

Parley support local memory through the same mechanism. Your chat history are
stored as files on your computer. When you ask: "did you remember the time
we talked about rainbow?", AI works with Parley to search your local files 
for such a conversation. Your AI becomes personal this way, and you have full
control of it.

With such local tool call mechanism, Parley gain agentic capabilities. Though
Parley foremost stays a research tool, not intended for full agentic workflows.

## 6. Paste an image into a question

A picture is worth a thousand words, oftentimes it is easier to ask the AI
about things by sending question with a picture. Parley support this workflow,
try the following:

1. Copy an image to the clipboard, such as a screenshot or a diagram. On Mac
   you can do this easily with `shift+control+command+4` then drag select.
2. Type a question: "Tell me what's in the picture".
3. Put the cursor in that question and press `option+v`.
4. Parley saves the image and inserts a Markdown image link into the question.
5. Choose a model that supports images, then press `option+return` to send.

The image is stored beside the chat under `assets/<chat-id>/`. Pasting attaches
the image locally; sending the question submits the included image to the 
selected AI provider.

`:MarkdownPreview` opens a browser preview of the Markdown, including images.
`:MarkdownPreviewStop` stops the preview. You can keep editing in Parley.

## Try it

Use the question below for a guided explanation, or open a project chat and try
one of the exercises above.

New to Vim? Open [4. VIM Basics](vim-basics.md) for navigation, undo, search,
and everyday editing. In Normal mode, put the cursor on the link and press
`option+o`.

💬: Help me understand how Parley turns this transcript into a request to the AI.
Then suggest a small project where I can practice research a topic, saving a note,
searching an earlier chat, and discussing an image.
