---
id: 000376
status: done
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
github_issue:
started: 2026-10-17T07:18:15-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.18
tracker:
    version: 1
    completion:
        token: close-fbf4489b9f93
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 9a2a54c3aed9aee6d7142fb7a85d951bc5918516
        evidence_commit: 036ccad8125ea90abbf786aee387882ddbd9c8e1
        landed_commit: 09b98872038c916431d470df42fe1a657061fed7
kind: bug
---

# packaging_vm_spec reads an empty vms.json: fake_tart's state write is not atomic (flake)

## Problem

`tests/integration/packaging_vm_spec.lua` "disposable packaging VM ownership boots before publication then resumes public installation in the same clone" failed once in a full `make -k test`, at line 127: `vim.json.decode` raised "Expected value but found T_END at character 1". The spec's `state()` read `fake/vms.json` as an empty file.

- Seen: 2026-10-17, #375 branch at head 48513d91, during a direct `make -k test`. #375 touches only `tests/arch/single_source_sweeps_spec.lua`.
- Retained log: `/Volumes/AgentScratch/tmp/claude-501/retained/suite375-packaging_vm-flake.log`.
- The spec passed four focused runs in a row on the same head.

Likely cause: `tests/fixtures/fake_tart` saves its state with `statefile.write_text(json.dumps(state))` (line 52), which truncates and then writes. A reader that lands in between sees an empty file. That reader is the spec's `state()`, or another fake_tart process at line 10, if the script under test leaves one running past the step's return (for example a backgrounded `tart run`).
