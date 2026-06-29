---
id: 000152
status: open
deps: []
created: 2026-06-29
updated: 2026-06-29
---

# issue finder should default to display done items as well

## Problem

currently we hide done items in workshop/issues, and user can use <C-a> to toggle it on when issue finder is open. we should switch the default to display done items in workshop/issues. 

## Done when

- [ ] Issue finder shows done items by default.
- [ ] The existing toggle still lets the user hide done items.

## Spec

Issue finder should invert the current default visibility for done issues: done
items in `workshop/issues/` are visible on open, and the existing `<C-a>` toggle
switches them off instead of on.

## Plan

- [ ] Find the current done-item filter default in issue finder.
- [ ] Add or update tests for default visibility and toggle behavior.
- [ ] Change the default while preserving the toggle.

## Log

### 2026-06-29

Created from user feedback while landing #108. Scoped the desired behavior:
show done issues by default in the issue finder while preserving the existing
toggle as a way to hide them.
