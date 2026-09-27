---
id: 000267
status: open
created: 2026-09-18
updated: 2026-09-18
estimate_hours:
github_issue:
---

# tool_resources_spec dies silently under parallel load in its JIT-off call-hook case

## Problem

`tests/unit/tool_resources_spec.lua` intermittently kills its Neovim process
under parallel load: exit code 1, no failing assertion, output ending right after
"reserves newly freed capacity for older runnable waiters" — i.e. inside the next
case, "bounds pump work for a full queue of maximum-width dependency chains",
which turns the JIT off (`jit.off(); jit.flush()`) and installs a per-call debug
hook around `R.pump`.

Because `make test` runs its phases in sequence, one abort in the unit phase
skips the whole integration phase. It did so twice in four full runs on the
#266 branch, leaving close evidence without integration results.
