---
id: 000361
status: working
created: 2026-10-16
updated: 2026-10-17
estimate_hours:
github_issue:
started: 2026-10-17T02:19:20-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# Cliproxy expired-token recovery intermittently retries instead of prompting

## Problem

tests/integration/cliproxy_auth_login_spec.lua intermittently fails “claims the #197 503, prompts the right login, and reports the real reason” at line128: expected settled=give_up for the fake expired OAuth credential and dismissed login, observed settled=retry. The whole spec passed on a focused run of the exact same head. This independently blocks #353's suite; it is not folded into the breadcrumb implementation.

First seen: 2026-10-16 during #353's final-head full suite. Head: f4239bccc3af35cd6fd0cbe65fafb1f128b45bb1. Failed run finished with446 spec files passing, two failing, lint749 clean and no surviving processes.

Retained failed-suite log: /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/bd9f02e9a941c6a23073857764765ecb.log (SHA256 3c666a396002ea5ad421f2d8042d2bb452182ddea7f675de21a3b2607d7a470a). Same-head focused rerun of both affected specs passed all43 cases: /tmp/parley353-cliproxy-repro.log. Earlier full suite on ed5af56cef2c8b6b917f0bd932eb18c1a36c0591 passed448/448; the only subsequent production change returns a snapshot failure reason in file_history.lua. Cliproxy source and these spec files are unchanged by #353.
