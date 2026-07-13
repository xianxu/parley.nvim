---
id: 000182
status: working
deps: []
github_issue:
created: 2026-07-10
updated: 2026-07-12
estimate_hours:
started: 2026-07-12T21:56:40-07:00
---

# claude code style progression text in parley chat

now that we are using parley chat to do more complex chat (moving to agentic direction), sometimes it takes a long time for agent to respond. we should have a consistent agent is doing something text in buffer. Several design decisions:

1. that line is ephemeral, not part of nvim history.
2. it would have some animation, we can use the ⠙ sequence. 
3. it would cycle through bunch of random verb, like brewing, cooking, dragon-slaying etc. 
4. verb would change on receiving any SSE response, or every 15 seconds, whichever is shorter. 
5. all those are just cosmetic, before real thing is displayed.

It looks something:

⠙ brewing

the verb is randomly picked from a list of playful verbs.  


## Problem

## Spec

## Done when

-

## Plan

- [ ]

## Log

### 2026-07-10
