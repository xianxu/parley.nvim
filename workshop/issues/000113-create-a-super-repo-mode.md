---
id: 000113
status: working
deps: []
created: 2026-04-27
updated: 2026-04-27
---

# create a super-repo mode

right now, parley has a repo mode, in which chats/notes are localized into a local repo, instead of using global write location. 

I work across multiple repositories, all cloned under ~/workspace, e.g. parley.nvim, ariadne, charon, nous, brain. all of them have the parley infrastructure. sometimes I would want to check of notes/chats/issues or <C-g>m to find all recent markdown file changes, across the board. Let's make this work, and call it super-repo mode.

it should work like this:

1. all writes are going to brain by default. as a matter of fact, if the current folder has a brain folder and have marker brain/.parley, this is the signature enabling the super-repo mode.

2. all reads in all modes should poll in from all parley enabled repos. so for example, if we have charon/.parley, ariadne/.parley, but not diary/.parley, then for example, for notes search, we should search charon/workshop/notes, ariadne/workshop/notes, along with the global location. 

First inspect parley features, and design this out. 

## Done when

-

## Spec


## Plan

- [ ]

## Log

### 2026-04-27

