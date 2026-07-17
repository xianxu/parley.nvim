---
id: 000193
status: working
deps: []
github_issue:
created: 2026-07-16
updated: 2026-07-16
estimate_hours:
started: 2026-07-16T22:54:13-07:00
---

# parley fold sometimes at wrong place

how does parley fold work, both at steady state and during streaming. it seems at final stage folding's more correct than during streaming. 

The folding rule is pretty simple. basically for each exchange's "select" entities, we fold, such as thinking (when available), summary, tool_result etc. you should list what are the exchange structure in parley, and we decide which one should fold. you then check code and update the logic. 

## Problem

## Spec

## Done when

-

## Plan

- [ ]

## Log

### 2026-07-16
