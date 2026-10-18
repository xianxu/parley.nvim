---
id: 000389
status: open
created: 2026-10-18
updated: 2026-10-18
estimate_hours:
github_issue:
---

# Document mover skips pending side-doc links inside proposal markers

## Problem

A marker-free side-doc link under `presentation: propose` is emitted by the installed Pair apply engine as `🤖{ → \\[proposal\\](design.side/01-release.md)}`. The parent also gets a direct `discussions:` entry in the same apply. Parley's S3 document mover scans Markdown links through `reference_candidates.markdown_spans`, then `document_move_plan.rewrite_links` skips an escaped opening bracket. Moving `design.md` and its `.side/` folder rewrites the index and side-doc paths but leaves the pending marker's destination pointed at the old folder. The attention finder discovers side docs by scanning `.side/*.md` and `type: side-doc`, independently of the link, so the move is the observed gap.
