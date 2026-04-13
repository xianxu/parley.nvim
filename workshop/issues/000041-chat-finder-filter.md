---
id: 000041
status: wontfix
deps: []
created: 2026-03-30
updated: 2026-03-30
---

# chat finder filter

previous issue ../history/000039-more-ways-to-show-or-hide-chat-files.md we created a tag bar. the intention was to automatically hide some of the files that are of less value, but still allow us to quickly search for them. 

the following are types of files that are potentially less interesting:

1/ files created with <C-g>C, which is used to critic some other file, for proof reading. 
2/ files in a chat tree, that's not the root. particularly those inline chat branch files. 

one way to hide them from chat finder by default are use a particular tag, e.g. ~, to indicate they are less interesting. 

so we need to: 

1/ automatically insert such tag when creating chat file from the above mechanisms: 1/ <C-g>C, 2/ <C-g>i on visual selection. 
2/ default chat finder, select all tags but not [~]. 

## Reason to abandon

Feels too complex, and heavily depending on how user uses things. Also with the new review feature, this might be a lesser of an issue.

## Done when

-

## Plan

- [ ]

## Log

### 2026-03-30

