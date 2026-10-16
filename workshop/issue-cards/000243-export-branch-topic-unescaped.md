---
id: 000243
status: done
created: 2026-09-13
updated: 2026-10-16
estimate_hours:
github_issue:
started: 2026-10-16T00:44:49-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.08
tracker:
    version: 1
    completion:
        token: close-fc4296e872ac
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 005efb89b09844672572bcc97ef0600a95303bf7
        evidence_commit: ecf1e0a563a6a3a0ed6ab96a2b360d752800aec3
        landed_commit: 94d6f66b850eaf46554969bffc2b4eaabb6acf14
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
