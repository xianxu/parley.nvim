---
id: 000376
status: working
deps: []
github_issue:
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
collaboration-mode: collaboration
card_mirror: '4c5b5a0c57643fd930eabe4de749dbe0ef3c7b6c' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-17T07:18:15-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "bc9b0b22", done: "ff519f53"}
---

# packaging_vm_spec reads an empty vms.json: fake_tart's state write is not atomic (flake)

## Problem

`tests/integration/packaging_vm_spec.lua` "disposable packaging VM ownership boots before publication then resumes public installation in the same clone" failed once in a full `make -k test`, at line 127: `vim.json.decode` raised "Expected value but found T_END at character 1". The spec's `state()` read `fake/vms.json` as an empty file.

- Seen: 2026-10-17, #375 branch at head 48513d91, during a direct `make -k test`. #375 touches only `tests/arch/single_source_sweeps_spec.lua`.
- Retained log: `/Volumes/AgentScratch/tmp/claude-501/retained/suite375-packaging_vm-flake.log`.
- The spec passed four focused runs in a row on the same head.

Likely cause: `tests/fixtures/fake_tart` saves its state with `statefile.write_text(json.dumps(state))` (line 52), which truncates and then writes. A reader that lands in between sees an empty file. That reader is the spec's `state()`, or another fake_tart process at line 10, if the script under test leaves one running past the step's return (for example a backgrounded `tart run`).

## Spec

The fake's state write is atomic: write a temporary file in the same directory, then `os.replace` it. If a fake process can outlive the step that started it, the spec waits for it before reading, rather than racing it.

## Done when

- fake_tart writes vms.json atomically.
- A deterministic regression exists, for example a reader polling vms.json while the fake writes it repeatedly, that fails before the change and passes after.

## Plan

Measured cause: scripts/test-parley-vm.py starts `tart run` detached (`subprocess.Popen`, `start_new_session`) and then polls the guest with `tart exec`, so fake_tart calls overlap. Each call read, changed and rewrote vms.json unlocked, using `write_text`, which truncates and then writes. That gives a torn read (the observed empty JSON) and lost updates. The fake's `exec` also succeeded on a VM that was not running, unlike real tart, so under load `boot` could return before the detached `run` had recorded the VM.

- [x] Regression first: "boot waits for a slow detached run before it reports ready", with `FAKE_TART_RUN_DELAY=1.5`. Red before the fix: `boot` returned 0 with the VM not running.
- [x] fake_tart holds one exclusive `flock` (vms.lock) over each read-modify-write and writes through a temp file plus `os.replace`. `exec` on a VM that is not running exits 1, as real tart does.
- [x] packaging_vm_spec 18/18 on three runs. With the `exec` check removed, the regression fails. fixture_lifecycle_spec 4/4. luacheck clean.
- [x] Close review BR-1: Done-when clause 2 asked for a deterministic regression for the atomic write. A spec seam, `FAKE_TART_HOLD`, holds a call with its new state staged but unpublished, under the lock, until the spec releases it. Two specs use it:
  - "a reader never sees a torn state file": the spec reads during the hold and gets the complete old state. Red under a mutation to the old truncate-then-write.
  - "a call overlapping another loses neither update": a second clone during the hold waits, and both land. Red with the `flock` removed.
  - packaging_vm_spec 20/20, and the arrival arch test is green.

## Log

### 2026-10-17
