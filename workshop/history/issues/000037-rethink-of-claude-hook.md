---
id: 000037
status: done
deps: []
created: 2026-03-30
updated: 2026-03-30
---

# rethink of claude hook

right now, we have "constitution check" hook to run with the following condition:

1. if N lines and M files changed, then run the constitution check. 
2. constitution check calls to subagent to check for DRY, PURE etc. If there are violation, insert into context, and instruct main agent to address. 
3. once ran, it should keep track of state, so that next trigger condition, will be N*(1+X%)^Z lines and M*(1+X%)^Z files changed, Z is the time of constitution check has been ran.

I want you to first check if the above condition is true. If true, we should consider the following changes:

1. the line of change and # files changed, should be OR, not AND. 
2. consider a hook to mere nag, e.g. remind main agent that it has made substantial change, and it should consider run constitution check, on its own, not directly running and injecting result as context. this gives the main agent autonomy to postpone if it is in the middle of something. 
3. and when main agent did invoke the constitution check (parallel_check.sh), that should increase Z (time of constitution check been ran), thus delaying future nagging. 
4. the next time we should nag should not be statically decided as N*(1+X%)^Z lines OR M*(1+X%)^Z, but use the actual line of change or # file changed when the check was ran.
5. if main agent keeps postponing, this will result each hook print a nagging line
6. when the current change (either lines of change or # file changed) are Y times greater than the current warning threshold, force run constitution check, and insert result as context, and ask main agent to MUST address the violation before proceeding.

## Done when

- Hook-gate nags (no check run) when diff crosses nag threshold
- Hook-gate force-runs checks when diff is 3x nag threshold
- Voluntary `--audit` run updates state, delaying future nags
- State file tracks both lines and files

## Plan

- [x] Audit current implementation — found `should_run_checks()` was never called
- [x] Change state file to two-line format (lines, files)
- [x] Add `read_state()`, `check_action()` functions
- [x] Hook-gate: none/nag/force logic with OR on lines/files
- [x] Audit mode: always call `update_state` to reset nag threshold
- [x] Reset state file baseline

## Log

### 2026-03-30

- Found `should_run_checks()` was defined but never called — hook always ran full checks unconditionally
- State file only stored `DIFF_LINES`; growth gate ignored file count
- Rewrote hook-gate to: none (silent) / nag (print reminder, exit 0) / force (run checks, exit 2 if violations)
- Voluntary `--audit` now always updates state → resets nag threshold
- FORCE_MULTIPLIER=3: force kicks in at 3× nag threshold
