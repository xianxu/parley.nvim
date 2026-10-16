---
id: 000332
status: codecomplete
created: 2026-10-15
updated: 2026-10-15
estimate_hours: 5.9075
github_issue:
started: 2026-10-15T13:07:57-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 12.89
tracker:
    version: 1
    completion:
        token: close-862c9f55a3c9
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 2fee90247e1fef6cddb9402f80b828cbbb29ba45
        evidence_commit: fbe5c42376545e56e9cb6e67eab2d85a5491c4f7
---

# Agentic documents: Alt+Return makes any right-pane markdown file a session-sync document (universal-agent-input-interface S1, parley side)

## Problem

Project universal-agent-input-interface (ops `teams/devinfra/projects/universal-agent-input-interface/`, design in
`design.md`, slice S1): today only files with `type: session-sync` get the operator lock, Alt+Return submit and the
red winbar. The operator wants any markdown file opened in Couch's right-pane nvim to become an **agentic document**
at its first Alt+Return.
