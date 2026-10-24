---
id: 000439
status: open
created: 2026-10-24
updated: 2026-10-24
estimate_hours:
github_issue:
---

# Native acknowledgement receipt winbar wait flakes under suite load

## Problem

One native acknowledgement/submit-receipt case failed under integration-suite load while landing #425. The exact integrated head subsequently passed ten matched original-file repetitions, as did its pinned main parent. The hub classifies this as a load-sensitive flake not attributable to #425; its underlying mechanism remains unproven.
