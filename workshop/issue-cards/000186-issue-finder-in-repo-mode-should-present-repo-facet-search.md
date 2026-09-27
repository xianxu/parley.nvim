---
id: '000186'
status: done
started: 2026-07-14T12:24:51-07:00
created: 2026-07-14
updated: 2026-07-14
estimate_hours: 5.0
actual_hours: 5.48
---

# issue finder in repo mode should present repo facet search

## Problem

Issue Finder aggregates issues from every member repository in super-repo mode,
but the only repository discriminator is the `{repo}` prefix embedded in each
result row. Users can type that prefix into the fuzzy query, but cannot quickly
include/exclude repositories, select none, or restore all repositories through
the facet UI already established by Chat Finder. Reopening Issue Finder or
switching between its `issues` and `history` views must not discard either the
typed search or repository selection.
