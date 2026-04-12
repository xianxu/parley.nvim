---
id: 000056
status: done
deps: [54]
created: 2026-04-04
updated: 2026-04-04
---

# vision DOT graph export

Generate Graphviz DOT format from parsed vision data for dependency visualization.

- Node size mapped from `size` field (S=1.0, M=1.5, L=2.2, XL=3.0)
- Node color mapped from `type` (tech=blue `#a0d8ef`, business=orange `#ffe0b2`)
- Edges from `depends_on`
- Support subgraph rooted at a node (show ancestors, descendants, or both)
- Output `.dot` file; user runs `dot -Tsvg` to render

Parent: #52

## Done when

- DOT export produces valid Graphviz DOT syntax
- Node sizes and colors reflect initiative size/type
- Dependencies rendered as edges
- Optional `--root=node` filters to subgraph
- Output to file path
- Unit tests pass

## Plan

- [x] Implement `export_dot(initiatives, opts)` in `lua/parley/vision.lua` — returns DOT string
- [x] Map size → node width (S=1.0, M=1.5, L=2.2, XL=3.0), type → fillcolor (tech=#a0d8ef, business=#ffe0b2)
- [x] Generate edges from resolved depends_on
- [x] Implement subgraph filtering via `opts.root` + `opts.direction` (up/down/both) using BFS
- [x] Add unit tests (5 tests: valid DOT, size mapping, color mapping, error handling, subgraph filtering)

## Log

### 2026-04-04

