---
id: 000403
status: working
deps: []
github_issue:
created: 2026-10-19
updated: 2026-10-19
estimate_hours:
collaboration-mode: collaboration
card_mirror: '6489efc4c8cc76f70a25964be57b7c62f5bd2312' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-19T22:31:29-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "b7b4ba3b", done: "60533640"}
---

# review diagnostics: CursorMoved error 'Invalid col: out of range' (fixed column 2 on short lines; stale lnum after a rewrite)

## Problem

The operator hit this while scrolling the TL session file (10-19 22:30, screenshot in ops
`teams/devinfra/assets/tl-status-xian-xu/2026-10-19.22-30-14.398.jpg`), as a blocking "Press ENTER" error on every
cursor move:

```
Error detected while processing CursorMoved Autocommands for "*":
Error executing lua callback: .../parley/skills/review/diag_display.lua:260: Invalid 'col': out of range
  nvim_buf_set_extmark ← render (diag_display.lua:260) ← refresh_tracked (:269) ← CursorMoved callback (:313)
```

`render` places each line's virtual-lines extmark at a fixed `DISPLAY_COL = 2`
(`nvim_buf_set_extmark(buf, display_ns_id, lnum, DISPLAY_COL, …)`). That column is out of range on any line shorter
than 2 characters (an empty line), and the `lnum` can also be stale: the session file is rewritten by the TL
(session-sync writes) while diagnostics from before the rewrite are still cached, so a diagnostic can point past the
end of the buffer or at a now-short line.

## Spec

- Anchor the virtual lines at column 0 (virt_lines don't need a column), or clamp the column to the line's length,
  and skip (not error on) a diagnostic whose `lnum` is past the buffer's end.
- A render error must never surface as a blocking message on CursorMoved: the autocmd callback degrades to no
  display for that refresh (and logs once), as other display code does.

## Done when

- Test: a diagnostic on an empty line renders without error; a diagnostic whose lnum is past the end after a
  buffer rewrite is skipped; CursorMoved with stale diagnostics raises no error.
- Red against the current code first.

## Plan

- [ ] Red tests through real extmarks/handler/CursorMoved: empty, one-byte and multibyte lines; stale cached start rows after shrink; injected partial-render failure, one warning and recovery.
- [ ] Anchor at column 0 with existing visual padding unchanged; validate start rows using one current line count; shared render boundary clears failed refreshes and warns once per module lifetime (ARCH-DRY).
- [ ] Count row-boundary lookup at N/2N, run focused/architecture guards and recorded suite, update atlas, send tested commit to hub for the required live check before landing.

## Log

### 2026-10-19

### 2026-10-19 — scoped design

The real module is lua/parley/skills/review/diag_display.lua. Its shared renderer
serves handler show, CursorMoved/resize refresh and scheduled rewrap; guard that
one boundary rather than patching each callback. Existing scan cost stays O(D)
plus message wrapping; one native line-count lookup per render, O(1) row checks,
with N/2N counted coverage. No new worker, timer, queue or durable data. A single
module-lifetime warning bit is bounded; failure shows no display for that refresh,
logs once, and the next normal refresh retries automatically. Text and original
diagnostic spans remain untouched. Workflow refresh changes to merge-check.yml
and local-gates-guard.yml were reverted exactly as the hub instructed (#398).
