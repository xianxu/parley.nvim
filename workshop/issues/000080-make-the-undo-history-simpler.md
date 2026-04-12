---
id: 000080
status: open
deps: []
created: 2026-04-08
updated: 2026-04-08
---

# make the undo history simpler

One of the power of parley is it's a text editor, so you can easily undo things, including agent's actions (e.g. what agent responded). One problem I'm facing is that after adding the status display inline when agent's using tools, we have a spinner. Each spinner update is a new state in the undo history, which makes it very hard to undo to the previous state before the agent response. We should make sure that the spinner updates don't create new states in the undo history.

## Done when

-

## Plan

- [ ]

## Log

### 2026-04-08

