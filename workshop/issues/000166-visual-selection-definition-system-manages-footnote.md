---
id: 000166
status: working
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-08
estimate_hours:
started: 2026-07-08T08:45:50-07:00
---

# move visual selection definition system to be based on durable footnote

Right now, the definition is inserted as diagnosis, and convert the text to [anchor text]. Persisting the definition is useful, and let's do that. It works roughly like the following:

1. when a `definition` is selected and queried, we do the same LLM call, get back definition. 
2. then we insert a footnote for that definition: [^definition]: .... 
3. at end of chat transcript, we manage a section of footnote. footnote is separated from main chat with a divider line ---. 
4. then we stop converting definition to anchor text [definition] as we have definition [^definition]. 
5. diagnosis should pull definition stored in footnote directly. 
6. footnote is not submitted to LLM.

## Problem

## Spec

## Done when

-

## Plan

- [ ]

## Log

### 2026-07-08
