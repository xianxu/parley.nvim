---
id: 000403
status: open
deps: []
github_issue:
created: 2026-10-19
updated: 2026-10-19
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'c59f4b05935c9a694a7fb066444b7ecc7504e7ec' # card fields mirrored from issue-cards; edit via sdlc
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

- [ ]

## Log

### 2026-10-19
