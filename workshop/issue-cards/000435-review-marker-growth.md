---
id: 000435
status: open
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
github_issue:
---

# bound review marker excluded-range lookup growth

## Problem

The unchanged review.parse_markers path revisits prior fenced/excluded ranges for each later marker. A mechanical probe while integrating #419 measured 388659 VM instructions at64 fenced blocks+64 ready asks versus1352938 at128+128 (3.481041x) on Neovim0.11.7/LuaJIT2.1.1741730670. This is independent of #419 new eligibility indexing, which has its own linearithmic guard. No global linear claim is made for the old parser.
