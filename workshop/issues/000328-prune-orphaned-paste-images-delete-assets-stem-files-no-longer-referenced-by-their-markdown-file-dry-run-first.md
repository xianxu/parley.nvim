---
id: 000328
status: open
deps: []
github_issue:
created: 2026-10-14
updated: 2026-10-14
estimate_hours:
card_mirror: '90498969c349e99ab5fad4b8846a450969a3c94c' # card fields mirrored from issue-cards; edit via sdlc
---

# Prune orphaned paste images: delete assets/<stem>/ files no longer referenced by their markdown file (dry-run first)

## Problem

Since parley.nvim#325, Alt+v saves pasted images to `assets/<file-stem>/` next to ANY markdown file, and parley never deletes an image when its line is deleted (owner-managed). In the operator's TL session file and QA answers (ops, gitignored), lines are deleted all day (the operator `dd`s answered bullets), so images pile up as orphans. Committed documents get untracked image files, and nothing reports unused ones.

## Spec

A prune action (`:ParleyAssetsPrune [path]`, plus a headless CLI form the TL can run) for a markdown file or a directory tree: list `assets/<stem>/*` files not referenced by `<stem>.md` (any `](assets/<stem>/<file>)` link). **Dry-run by default**: print orphans with sizes; `--apply` deletes them, and removes an `assets/<stem>/` (and `assets/`) left empty. Never deletes a file still referenced, a file Git tracks (report those instead: committed docs keep their history), or anything outside `assets/<stem>/`. Chats' timestamp folders follow the same rule.

## Done when

- Dry-run lists exactly the unreferenced images (test with a referenced, an orphaned and a tracked one); `--apply` removes only the orphans and empty folders.
- The TL can run it headless on `ops/teams/*/` daily.

## Plan

- [ ]

## Log

### 2026-10-14
