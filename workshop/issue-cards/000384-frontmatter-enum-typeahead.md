---
id: 000384
status: open
created: 2026-10-18
updated: 2026-10-18
estimate_hours:
github_issue:
---

# Frontmatter typeahead for enum values (collaboration-mode first, generic registry)

## Problem

Frontmatter keys with a fixed set of values (`collaboration-mode:` today, `presentation:` with #383, the issue `status:`) are typed from memory, and a typo only surfaces when the review fails (`collaboration-mode` "fails: name the bad mode"). The operator asked for typeahead on these values (via the hub, 10-18). It must draw on the definition parley already enforces, not a second hardcoded list, and be generic, so other enum keys join by declaring their values.
