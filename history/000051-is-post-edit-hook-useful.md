---
id: 000051
status: done
deps: []
created: 2026-04-02
updated: 2026-04-02
---

# is post edit hook useful

It seems I never observed post edit hook like the following actually prompted agent to do anything.

PostToolUse:Edit says: Constitution reminder: You have made substantial changes (7
     files, ~686 lines). Consider running scripts/parallel-checks.sh --audit when you reach a good stopping point.

on the other hand, the force run did trigger it once. 

so I wonder if in those cases the return code was different, and that signals to agent if they need to pay attention? 

## Done when

- Understand why hook output is ignored and fix it

## Plan

- [x] Investigate how hook return codes affect agent behavior
- [x] Update hook to use JSON `additionalContext` output with exit 0

## Findings

The return code is critical:

| Exit code | Behavior |
|-----------|----------|
| **0** | stdout processed; JSON `additionalContext` fed to Claude |
| **non-zero (except 2)** | stdout/stderr ignored by Claude, only in verbose mode (`Ctrl+O`) |
| **2** | blocking error (no effect for PostToolUse) |

Plain `echo` text appears in the transcript UI but is NOT reliably processed by Claude as instructions. Must use structured JSON:

```bash
jq -n '{
  "additionalContext": "Constitution reminder: ..."
}'
exit 0
```

This explains why the hook appeared to work during "force run" but was ignored otherwise — likely a different exit code path.

## Log

### 2026-04-03
- Researched Claude Code hooks documentation
- Root cause: hook used `systemMessage` (user-visible only) instead of `additionalContext` (fed to Claude)
- Fixed `scripts/parallel-checks.sh`: changed all `systemMessage` → `additionalContext` in nag and force modes

### 2026-04-02

