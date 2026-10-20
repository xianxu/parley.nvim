---
id: 000402
status: open
created: 2026-10-19
updated: 2026-10-19
estimate_hours:
github_issue:
---

# spec_runner's idle kill orphans a spec's embedded nvim children

## Problem

`tests/helpers/spec_runner.lua` ends a stalled or expired spec by sending SIGTERM to the spec child it started (`child:kill(15)` on its `vim.system` handle). It doesn't signal the child's process group. An embedded nvim that the spec started (`tests/helpers/embedded_nvim.lua`, `--clean --embed`) survives: its parent dies, it's reparented to pid 1, and a child spinning in Lua never reads its closed stdin. On 2026-10-19 three such children, started 18:36–18:55, spun at 100% CPU each for about 2.7 hours, ignored SIGTERM, and drove machine load to 130 until the hub SIGKILLed them. The source was #401's red check, which ran a wedged-child fixture through the runner with the idle-budget handoff removed.

Confirmed red: a fixture spec starts an embedded child, writes its pid, and runs `while true do end` in it. Its `REQUEST_MS` is 600000, so only the runner's idle kill can end it. Through `Runner.execute` (3 s budget) the case ends `stalled`, and the child's pid is still alive afterwards.
