---
id: 000405
status: open
created: 2026-10-20
updated: 2026-10-20
estimate_hours:
github_issue:
---

# remote-session: start a private RPC server when attached to a registered session file or side doc, and register its address with Couch

## Problem

Project remote-session (ops `teams/devinfra/projects/remote-session/`, operator-approved 10-20) makes the phone a
remote view of the live nvim buffer for each hub's session file and side docs. Couch needs to reach the nvim that has
the file open, without the operator starting nvim with special flags.
