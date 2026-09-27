---
id: '000077'
status: done
created: 2026-04-06
updated: 2026-04-07
actual_hours: N/A
---

# openshell sandbox fail to start on a new mac

## Problem

error message:

```
Copying agent...
Error: unable to connect to beta: unable to connect to endpoint: unable to dial agent endpoint: unable to install agent: unable to copy agent binary: unable to run SCP process: Couldn't open /dev/null: Permission denied
/usr/bin/scp: Connection closed
```

First, document what are the steps a `make sandbox-build` would take. Then trace step by step to find out where that comes from. Whereever applicable, involve user's help for debugging.
