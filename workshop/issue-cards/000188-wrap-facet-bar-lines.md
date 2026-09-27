---
id: '000188'
status: done
started: 2026-07-15T08:38:05-07:00
created: 2026-07-14
updated: 2026-07-15
estimate_hours: 2.27
actual_hours: N/A
---

# wrap facet bar across multiple lines

## Problem

The shared float-picker facet bar renders every action and facet on one
non-wrapping row. When the available facets exceed the picker width, later
facets are clipped and cannot be seen or selected. This is especially visible
in super-repo finders with many repository facets.
