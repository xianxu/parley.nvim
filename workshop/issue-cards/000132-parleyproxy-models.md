---
id: '000132'
status: done
created: 2026-06-14
updated: 2026-06-14
estimate_hours: 2.5
actual_hours: 0.18
---

# ParleyProxy models + providers commands

## Problem

After #131 (managed cliproxyapi), the `:ParleyProxy` command exposes lifecycle +
login, but there's no way to (a) list the models a provider currently serves, or
(b) discover which provider names are even supported. And the usage line only
names `{status|start|stop|restart|login}` with no per-subcommand help.
