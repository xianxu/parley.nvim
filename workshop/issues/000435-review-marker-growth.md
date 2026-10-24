---
id: 000435
status: open
deps: []
github_issue:
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
card_mirror: '9e25ba15af4eb1f49ed52bd9c5d43f63afd96977' # card fields mirrored from issue-cards; edit via sdlc
---

# bound review marker excluded-range lookup growth

## Problem

The unchanged review.parse_markers path revisits prior fenced/excluded ranges for each later marker. A mechanical probe while integrating #419 measured 388659 VM instructions at64 fenced blocks+64 ready asks versus1352938 at128+128 (3.481041x) on Neovim0.11.7/LuaJIT2.1.1741730670. This is independent of #419 new eligibility indexing, which has its own linearithmic guard. No global linear claim is made for the old parser.

## Spec

Bound excluded-range/fence lookup in the existing marker parser without changing marker grammar, turn-boundary handling or literal exclusions. Use existing parsing and write owners; no cache/watcher. Leave this follow-up unclaimed.

## Done when

- A normal make-harness regression builds N four-line fenced blocks, then N ready robot markers and proves the same recognized markers at N/2N.
- With JIT disabled/flushed for the instruction counter, aggregate work no longer approaches quadratic growth; preserve normal marker/fence/inline-code behavior on both supported runtimes.
- Keep parser-call and byte-copy measurements distinct from the Lua instruction count.

## Plan

- [ ]

## Log

2026-10-23: Probe fixture repeats {triple-backtick, literal, triple-backtick, empty line} N times, appends N robot bracket asks, and counts debug hook instructions only around pcall(parse_markers). JIT/hook state restored afterward. Captured result in slot3 scratch parley-marker-growth.3z75uW/result.log; reproduction source in repro.lua. Diff inspection confirms parse_markers is unchanged by #419. Recreate the regression under make test-spec before implementation; the ad-hoc counter is discovery evidence, not a qualified suite result.
