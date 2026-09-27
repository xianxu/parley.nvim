---
id: '000171'
status: done
started: 2026-07-08T17:14:54-07:00
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 0.43
actual_hours: 0.16
---

# footnote coloring

## Problem

Managed definition footnotes are appended as a final markdown footer, but chat
highlighting treats an unanswered question as continuing to EOF. When the last
exchange is an open question, the footer inherits `ParleyQuestion`, so footnotes
take on the color of the last exchange instead of having a stable dedicated
appearance.
