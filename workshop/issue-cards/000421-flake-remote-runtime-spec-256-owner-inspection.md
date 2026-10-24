---
id: 000421
status: codecomplete
created: 2026-10-22
updated: 2026-10-23
estimate_hours:
github_issue:
flake_tests: [lua:tests/integration/remote_runtime_spec.lua#private editor RPC runtime ownership keeps inspection bounded when all 256 marked directory owners differ from this editor, lua:tests/integration/remote_runtime_spec.lua#private editor RPC runtime ownership retains a directory whose inode changes after inspection begins]
started: 2026-10-23T15:07:22-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 1.99
tracker:
    version: 1
    completion:
        token: close-78a02ac5d934
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 5cdcfa828869c68e4fc4aec0094f9f8a9ba0dd39
        evidence_commit: f2789c57fa176b321dfcc192555206d057aabe1b
---

# flake: lua:tests/integration/remote_runtime_spec.lua#private editor RPC runtime ownership keeps inspection bounded when all 256 marked directory owners differ from this editor, lua:tests/integration/remote_runtime_spec.lua#private editor RPC runtime ownership retains a directory whose inode changes after inspection begins

## Problem

Known flaky tests (#394), registered with same-head fail→pass evidence:

- lua:tests/integration/remote_runtime_spec.lua#private editor RPC runtime ownership keeps inspection bounded when all 256 marked directory owners differ from this editor: Same exact Git head a63c43605526bec39444f699060047790908366e on nvim0.12.5: focused make test-spec SPEC=modes/remote_session failed these two cases (266PASS/2FAIL/0ERROR, clean census), /Volumes/TestScratch/parley-405-landed-focused-green.log. Follow-up diagnostic make test-spec mapped only the unchanged remote_runtime_spec.lua:44PASS/0FAIL/0ERROR, clean census, /Volumes/TestScratch/parley-405-runtime-diagnostic.log. First case returned runtime deadline despite timeout_ms=arrival.MS; second did not reach fake source read before arrival wait. Native0.11.7 full mapping268PASS on the same head. Evidence is local targeted runs, not recorded-suite or CI evidence. Root cause not yet established; do not increase product deadlines or claim the failing mapping passed.
- lua:tests/integration/remote_runtime_spec.lua#private editor RPC runtime ownership retains a directory whose inode changes after inspection begins: Same exact Git head a63c43605526bec39444f699060047790908366e on nvim0.12.5: focused make test-spec SPEC=modes/remote_session failed these two cases (266PASS/2FAIL/0ERROR, clean census), /Volumes/TestScratch/parley-405-landed-focused-green.log. Follow-up diagnostic make test-spec mapped only the unchanged remote_runtime_spec.lua:44PASS/0FAIL/0ERROR, clean census, /Volumes/TestScratch/parley-405-runtime-diagnostic.log. First case returned runtime deadline despite timeout_ms=arrival.MS; second did not reach fake source read before arrival wait. Native0.11.7 full mapping268PASS on the same head. Evidence is local targeted runs, not recorded-suite or CI evidence. Root cause not yet established; do not increase product deadlines or claim the failing mapping passed.
