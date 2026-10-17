---
id: 000366
status: open
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
github_issue:
---

# check-couch-actors-live skips instead of passing: the real couch runs under the isolated HOME

## Problem

`make check-couch-actors-live` (#365) never really ran the live `--actors` conformance check. Run unsandboxed from ops:0 on 2026-10-16, `couch_spec`'s live case printed `Pending … couch unreachable here` followed by `Success`. Plenary prints that pair for any case that calls `pending()`, so the check was skipped, not passed.

The case reaches the real binary (past the sentinel), but its `couch --actors --json` exits non-zero or prints non-JSON. The likely cause is that the target runs under the harness's isolated HOME, XDG and TMPDIR, so the real CLI can't find the operator's Couch store or supervisor socket. The thread names alone are not enough.
