---
id: 000139
status: working
deps: []
created: 2026-06-25
updated: 2026-06-25
started: 2026-06-25T22:56:23-07:00
---

# improve safety of tool call

for example, ls call may return 1M files under a directory, we should have some upper limit, by doing some summarization, maybe when there are too many files, for each directory we should three files, then a ... on the next line. LLM would understand it. we may well add one summary line at the end: there are 9999999 files, we only showed 100 examples. if you need more, pass this flag and do paging etc. 

makes sense? 

## Done when

-

## Spec


## Plan

- [ ]

## Log

### 2026-06-25

