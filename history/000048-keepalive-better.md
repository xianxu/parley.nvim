---
id: 000048
status: done
deps: []
created: 2026-04-01
updated: 2026-04-03
---

# keepalive better

Sandbox would still time out despite I use zellij. I can recover, but would be nicer if we simply don't get disconnected.

## Resolution

Two changes:

1. **Increased SSH keepalive tolerance** — `ServerAliveCountMax` from 3 → 40 (15s × 40 = 10 min). SSH now survives most sleep/wake cycles without dropping.
2. **Terminal restore on disconnect** (issue 000044 adjacent) — `stty sane` after `openshell sandbox connect` so terminal state is clean even if SSH exits abnormally.

Zellij inside the sandbox preserves agent sessions regardless — the SSH drop only affects the interactive terminal, not running agents.

Note: if the sandbox pod itself gets reaped by OpenShell's idle timeout (not just SSH dropping), that's a platform-level setting we can't control from policy.yaml. `make sandbox` will rebuild transparently in that case.

## Done when

- [x] SSH survives short sleep/wake without disconnecting
- [x] Terminal state restored on abnormal disconnect
