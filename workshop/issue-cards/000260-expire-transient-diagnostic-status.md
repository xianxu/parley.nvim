---
id: 000260
status: open
created: 2026-09-15
updated: 2026-09-15
estimate_hours:
github_issue:
---

# Expire transient diagnostic status messages

## Problem

The Parley status row can retain a diagnostic/error message indefinitely. In the
observed session it displayed `COUCH_MOUSE_TRACE: diagnostic generation changed
outside protocol` long after the event, even though the operator expected a
transient message to disappear after roughly 10 seconds. A stale warning makes
the status row look continuously unhealthy and obscures newer state.
