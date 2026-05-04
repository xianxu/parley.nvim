---
id: 000050
status: open
deps: []
created: 2026-04-02
updated: 2026-04-02
---

# reference to memory

Create a way to refer to past memory in the form of chat files. largely, memory is in the form of chat files, and agent can rg across it. I think we already have tool call setup, I don't quite remember if the grep tool in parley, uses rg, if not, we should just move over to rg.

The user interaction sequence would be something like this:

> do you remember what we talked about aws? 

this would trigger LLM to trigger local search tool call, and we would pipe rg result over. maybe the amount of context lines can be customized by agent, when they make tool call request, default to be -1, +2 lines.

chat file lives in multiple different repos, and a global location. we can use the following convention:

{global}/something-chat-file-in-the-global-location.md
{parley.nvim}/workshop/parley/chat-in-parley-repo.md
{brain}/workshop/parley/chat-in-brain-repo.md

the last two are repos from super-repo mode. note we choose to send for repo mode, or super repo mode to be rooted at parent of the repo. You can say always send in super-repo format. 

## Done when

-

## Plan

- [ ]

## Log

### 2026-04-02

