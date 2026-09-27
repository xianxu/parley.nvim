---
id: '000178'
status: done
started: 2026-07-08T23:33:32-07:00
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 0.27
actual_hours: 0.31
---

# recognize footnote footer without divider

## Problem

The #171 footnote-coloring fix still defines a managed footnote footer as a final
`---` divider followed by `[^id]: ...` lines. The desired footer boundary is
simpler: the first markdown footnote definition line (`[^id]: ...`) starts the
footer, even when no divider is present.
