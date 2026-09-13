---
id: 000243
status: open
deps: []
github_issue:
created: 2026-09-13
updated: 2026-09-13
estimate_hours:
---

# HTML export: branch topic is inserted unescaped by make_branch_div

## Problem

Found during #231's M2 review (2026-09-13). `exporter.make_branch_div` inserts
the branch **topic** into the exported HTML without escaping `<`, `>`, `&` or
`"`. A topic containing `<script>` lands raw in the export. The placeholder
mechanism around it is now non-recursive (#231 BR-9), so this is the separate
output-escaping class, not placeholder recursion. The markdown export's Jekyll
`{% post_url %}` form and the inline branch anchors should be checked for the
same gap.

## Spec

## Done when

-

## Plan

- [ ]

## Log

### 2026-09-13
