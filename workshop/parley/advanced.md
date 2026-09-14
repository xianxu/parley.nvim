---
topic: 3. Advanced
file: advanced.md
tags:
---

# Advanced

Parley keeps your conversation in an editable document. This lesson explains
what the AI sees, how to navigate a growing conversation, and how to use a
project folder for chats, notes, and images.

Like `welcome.md` and `basics.md`, this tutorial has a stable filename.
Chat Finder displays its topic, "3. Advanced".

## 1. Transcripts, turns, and what the AI sees

A transcript is the record of a conversation. A question after the speech-bubble
marker and the answer after the robot marker form an exchange. Each message
sent or received is a turn. You can edit earlier text and ask again.

Sending does not upload the entire file unchanged. Parley builds a request from
the question at your cursor and the relevant conversation leading up to it,
including earlier answers. It also supplies the selected system instructions
and any included file contents, images, or tool results needed for that request.
Later questions below the selected exchange are not future knowledge for the AI.

The text before the first question is not sent. That is why these tutorial
instructions can live above a real question without becoming part of it.

A line beginning with the lock marker is a local note, excluded from the chat
text sent to the model. For example:

    🔒: Remember to check this answer with my teacher.

Only that line is excluded. The lock does not hide the following paragraph.
Put the marker on each line you want kept out of the conversation context.
It is not encryption: the note is still in the local Markdown file, and asking
a file-reading tool to read that file can return its contents.

Editing the transcript changes what a later request can see; it does not erase
anything already sent to a provider. Use a fresh chat when you want a new topic
without the preceding conversation.

## 2. Outline, branches, and markers

Press Option+t or run `:ParleyOutline`. The outline includes headings, questions,
and branches across the linked chat tree. Selecting an item jumps to it, opening
its chat file when needed. A branch lets you explore a side question separately
while keeping a link back to the main conversation.

You can also put an outline marker on its own line, using `@@tag@@` syntax:

@@Rainbow research@@

Open the outline now and look for "Rainbow research". This is a navigation
marker, not the `tags:` metadata at the top of the file.

The same `@@...@@` syntax can refer to a local file for context. Use a descriptive
label for an outline marker; use a real path only when you mean to reference a
file. A heading such as `## Research notes` is another way to label a section.

To make a branch, put the cursor where it belongs and press Option+i. Type and
send your side question in the new chat. Option+t helps you return to the main
thread. Option+o follows a branch link or an ordinary Markdown navigation link.

## 3. A project folder: repo mode

A project folder gives related chats and working files one home. To try it,
close Parley, then run these commands in your terminal:

```sh
mkdir -p ~/parley-practice
cd ~/parley-practice
touch .parley
parley
```

The `.parley` file marks this directory as a Parley project. You do not need
a Git repository or a configuration file. Project chats go in
`workshop/parley/` inside this folder. Use `ctrl+g` then `c` to start a chat there.

In repo mode, the repo root is the directory containing `.parley`. File paths
in requests to the AI's file tools are relative to that root:

- `notes.md` means `~/parley-practice/notes.md`.
- `research/rainbows.md` means `~/parley-practice/research/rainbows.md`.
- `workshop/parley/` is the project's chat directory.

The chat being inside `workshop/parley/` does not move that base directory.
Ordinary Markdown navigation links follow document-relative rules instead:
`[Basics](./basics.md)` points beside the file containing the link.

## 4. Local files as working material

Your chats are local Markdown files. Notes and other project files can be read
by you, by an editor, and by Parley's file tools. This lets a conversation produce
something useful beyond an answer on screen.

In your project chat, try asking:

> Create `research/rainbows.md` with a short explanation and three questions
> I could investigate. Then read the file back and tell me where it was saved.

The app provides file reading, directory listing, search, writing and editing
without a configuration step. In repo mode, default tool access stays inside
this project. Neighboring projects are not included automatically. Outside repo
mode, the chat's own directory is the base for file tools.

Local storage does not mean a local AI model. Text and images sent in requests,
including file contents returned by tools, go to your selected provider.

## 5. Local tool calls and searching past chats

The model cannot inspect your disk just by thinking about it. It can request a
tool call; Parley runs the tool locally and returns the result to the model.
You can see tool calls and results in the transcript, marked with the wrench
and paperclip symbols.

For example, ask: "What did we discuss about rainbows in this project? Search
our saved chats and point me to the matching conversation."

The `chat_history_search` tool searches saved chat text for words or patterns.
It returns matching excerpts and file references from allowed chat folders;
the AI uses those results to answer. It is not perfect recall, so a specific
keyword helps. In repo mode, the default search scope stays in this project.

This search is different from automatically generated memory summaries or
preference profiles. Those automatic memory features remain off in the app.
You can still ask it to search previous chats whenever you need them.

## 6. Paste an image into a question

Start a new chat with `ctrl+g` then `c` for this exercise. New chats have a unique
timestamp that also identifies their attachment folder.

1. Copy an image to the clipboard, such as a screenshot or a diagram.
2. In the new chat, type a question: "Explain what this diagram shows."
3. Put the cursor in that question and press Option+v.
4. Parley saves the image and inserts a Markdown image link into the question.
5. Choose a model that supports images, then press Option+Enter to send.

The image is stored beside the chat under `assets/<chat-id>/`, not merely kept
in the clipboard. Keep the chat and its linked assets together when moving or
sharing them. Pasting attaches the image locally; sending the question submits
the included image to the selected provider.

`:MarkdownPreview` opens a browser preview of the Markdown, including images.
`:MarkdownPreviewStop` stops the preview. You can keep editing in Parley.

## Try it

Use the question below for a guided explanation, or open a project chat and try
one of the exercises above.

💬: Help me understand how Parley turns this transcript into a request to the AI.
Then suggest a small project where I can practice research a topic, saving a note,
searching an earlier chat, and discussing an image.
