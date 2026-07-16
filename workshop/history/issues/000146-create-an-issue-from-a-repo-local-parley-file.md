---
id: 000146
status: punt
deps: []
created: 2026-06-26
updated: 2026-06-26
---

# create an issue from a repo local parley file

really just a shortcut to connect exploration, into an issue, using repo relative path. well, it's actually simple enough to just create an issue, then ../parley/something. the only part that's slow is to refinding the parley under discussion, so probably still worth it? though it's easy to just copy file name as well. unsure how valuable this is. 

## Done when

- There is a clear decision on whether repo-local Parley chats need a shortcut
  for promoting the current chat file into a workshop issue.
- If implemented, the shortcut links the generated issue back to the repo-relative
  Parley file without requiring the operator to refind the chat manually.

## Spec


## Plan

- [ ] Validate whether copying the repo-relative Parley path is enough for the
  intended workflow.
- [ ] If a shortcut is still useful, define the command/keybinding and the issue
  link format it should create.

## Log

### 2026-06-26
