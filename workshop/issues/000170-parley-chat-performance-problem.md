---
id: 000170
status: working
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-11
estimate_hours:
started: 2026-07-11T21:57:07-07:00
---

# parley chat performance problem
when parley chat goes long at about 1K line, nvim slows down, to user's edit command, just typing anything has noticeable delay. We should do an audit on the rendering path and figure out why it's so slow.

Actually, nm, it seems the perf degradation is mostly from :MarkdownPreview. 

While we are at this, some questions: 

1. is the rendering code of any style etc. only around the view port, maybe +/1 100 lines of current view port. is it the advisable strategy to keep rendering complexity constant, instead of proportional size of document. 

2. when is in memory exchange structure being maintained. I guess the parley protocol all relies on special unicode at start of line. thus any edits not changing the character at start of the line, we don't need to recompute exchange structure, or big portion of rendering. 

Do an audit and let's discuss if there are improvements to be made. 

## Problem

## Spec

## Done when

-

## Plan

- [ ]

## Log

### 2026-07-08
