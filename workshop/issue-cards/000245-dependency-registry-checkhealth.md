---
id: '000245'
status: done
started: 2026-09-13T13:20:58-07:00
created: 2026-09-13
updated: 2026-09-13
estimate_hours: 1.76
actual_hours: 0.77
---

# Dependency registry and honest install advice: managed cliproxyapi, platform tools, brew one-liners in checkhealth

## Problem

parley depends on external binaries in three different ways and reports none
of them coherently. cliproxyapi is downloaded and managed by parley itself
(#131, #237) because its configuration is complex; `osascript` and `sips`
ship with macOS; ripgrep, ImageMagick, `wl-clipboard`/`xclip` are ordinary
package installs. A new user discovers a missing tool only when a feature
fails at runtime, and `:checkhealth parley` cannot tell them what to run.
Part of the `parley-packaging` project.
