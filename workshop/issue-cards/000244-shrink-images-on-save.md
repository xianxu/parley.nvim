---
id: '000244'
status: done
started: 2026-09-13T11:25:16-07:00
created: 2026-09-13
updated: 2026-09-13
estimate_hours: 1.623
actual_hours: 1.70
---

# Shrink pasted and generated images before saving: sips first, probe other tools, keep the original when none

## Problem

Operator, 2026-09-13, after #231 landed. A macOS screenshot is a 2–6 MB
Retina PNG. Pasted assets are write-once, so git stores each exactly once —
the cost is size, not churn — but a hundred screenshots a month at that size
is hundreds of MB a year in `workshop/parley/assets/`, and every re-send of a
retained image spends tokens on pixels the providers downscale anyway
(Anthropic resizes above ~1568 px on the long edge). Neovim has no image
codec and no CLI exists by default on both macOS and Linux, so this is a
per-platform recipe, like the clipboard read.
