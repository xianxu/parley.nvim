---
id: 000051
status: open
deps: []
created: 2026-04-02
updated: 2026-04-02
---

# is post edit hook useful

It seems I never observed post edit hook like the following actually prompted agent to do anything.

PostToolUse:Edit says: Constitution reminder: You have made substantial changes (7
     files, ~686 lines). Consider running scripts/parallel-checks.sh --audit when you reach a good stopping point.

on the other hand, the force run did trigger it once. 

so I wonder if in those cases the return code was different, and that signals to agent if they need to pay attention? 

## Done when

-

## Plan

- [ ]

## Log

### 2026-04-02

