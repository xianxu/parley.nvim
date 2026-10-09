---
id: 000311
status: open
deps: []
github_issue:
created: 2026-10-08
updated: 2026-10-08
estimate_hours:
card_mirror: 'd56cfbad6ac359b072de138e2b280719bfcf5527' # card fields mirrored from issue-cards; edit via sdlc
---

# demo: hand recording tooling to castcut

## Problem

The demo's recording pipeline — `demo/viewer.html` (annotate) and `demo/cut.py` (cut) — has no
parley-specific part, and it now lives as a standalone tool: `castcut` (tools#83,
`brew install xianxu/tools/castcut`; `castcut --help` is its manual). Keeping both copies lets
them drift, along with the `captions` header contract the blog's `CastEmbed.astro` reads.

## Spec

Parley keeps only its per-app parts: the isolated launcher (`./parley_app --demo`) and the shot
list (`demo/REHEARSAL.md`). Recording, annotating and cutting go to castcut:

```sh
castcut record -- ./parley_app --demo        # → recordings/take-NN.cast, at the window's size
castcut annotate recordings/take-01.cast     # Alt+T stamps; notes → take-01.captions.txt
castcut cut recordings/take-01.cast          # → recordings/take-01-cut.cast
```

Differences from the prototype worth knowing: notes save beside the take (no browser-storage
drafts), a caption that outlasts the take holds the final frame instead of being truncated, and
the cut is not byte-identical to `cut.py` (same timing model and flags).

## Done when

- `demo/README.md`'s "Record" and "Review a recording" sections point at castcut (the commands above
  and `castcut --help`), and keep the parley-specific notes (provider proxy, `demo/recordings/` ignore).
- `demo/cut.py`, `demo/viewer.html` and `tests/packaging/test_cast_viewer.js` are removed, and every
  reference to them outside `workshop/history/` is gone (`atlas/infra/starter.md:66-74`,
  `demo/README.md:93-111`) — `git grep -e cut.py -e viewer.html -e test_cast_viewer` is empty outside history.
- Whatever runs `test_cast_viewer.js` (test target / CI) no longer does.

## Plan

- [ ]

## Log

### 2026-10-08

- Filed from tools#83 (castcut) at its M3, by agreement with the operator.
