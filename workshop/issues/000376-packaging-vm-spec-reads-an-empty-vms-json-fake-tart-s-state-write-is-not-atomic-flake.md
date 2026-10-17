---
id: 000376
status: open
deps: []
github_issue:
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
collaboration-mode: collaboration
card_mirror: '8777ee4608fee868869f9f75787e469ef55e94eb' # card fields mirrored from issue-cards; edit via sdlc
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

- [ ]

## Log

### 2026-10-17
