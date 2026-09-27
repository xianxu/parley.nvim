---
id: '000187'
status: done
started: 2026-07-14T18:42:45-07:00
created: 2026-07-14
updated: 2026-07-15
estimate_hours: 2.96
actual_hours: 5.12
---

# markdown finder in repo mode should present repo facet search

## Problem

Markdown Finder uses one bespoke tag-bar implementation for two different
meanings: top-level directories in ordinary repo mode and repository names in
super-repo mode. The super-repo behavior currently emerges indirectly because
member scanning overwrites each entry's directory tag with its repo name. The
two modes also share module-local selection state, so directory and repository
keys can collide or leak across mode changes, and there is no finder-level test
that defends the intended super-repo UI.

The picker also preserves only structured `{repo}` fragments today. Ordinary
search text is lost when the finder is reopened, despite the desired workflow
being to resume the same Markdown search and facet selection.
