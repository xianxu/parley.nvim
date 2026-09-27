---
id: '000056'
status: done
created: 2026-04-04
updated: 2026-04-04
actual_hours: N/A
---

# vision DOT graph export

## Problem

Generate Graphviz DOT format from parsed vision data for dependency visualization.

- Node size mapped from `size` field (S=1.0, M=1.5, L=2.2, XL=3.0)
- Node color mapped from `type` (tech=blue `#a0d8ef`, business=orange `#ffe0b2`)
- Edges from `depends_on`
- Support subgraph rooted at a node (show ancestors, descendants, or both)
- Output `.dot` file; user runs `dot -Tsvg` to render

Parent: #52
