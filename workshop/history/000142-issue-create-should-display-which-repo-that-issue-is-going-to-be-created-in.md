---
id: 000142
status: done
deps: []
created: 2026-06-25
updated: 2026-06-25
started: 2026-06-25T16:48:55-07:00
estimate_hours: 0.5
actual_hours: 0.5
---

# issue create should display which repo that issue is going to be created in

I sometimes accidentally creating in wrong repo, so in the prompt do:

[Brain] Issue Title: ...

## Done when

- `cmd_issue_new`'s prompt shows the target repo, e.g. `[parley.nvim] Issue title: `
  / `[brain] Issue title: `, so the operator sees which repo the issue lands in
  before typing.
- The label is the basename of the git root the issue is created in (the same
  resolution `create_issue` uses), so it always matches the actual destination.
- A unit test pins the pure label derivation.

## Spec

`config.issues_dir` is relative (`workshop/issues`), so `create_issue` resolves it
against **cwd's git root** (`get_issues_dir` → `find_git_root(getcwd())`). The
destination repo therefore follows the editor's cwd — creating from the wrong cwd
silently lands the issue in the wrong repo. Fix: prefix `cmd_issue_new`'s
`vim.ui.input` prompt with `[<repo>]`, where `<repo>` is the basename of that same
git root. Add a pure `repo_label(root)` (basename, vim-free, unit-tested) and an
IO `get_issues_repo_root()` that mirrors `get_issues_dir`'s root resolution
(relative → cwd git root; absolute `issues_dir` → git root above it).

## Plan

- [x] Pure `M.repo_label(root)` (basename; `nil`/empty → "?") + unit test.
- [x] IO `M.get_issues_repo_root()` mirroring `get_issues_dir`'s root logic.
- [x] Prefix `cmd_issue_new`'s prompt: `[<label>] Issue title: `.
- [x] Verify: issues unit spec green; headless check label = current repo.

## Log

### 2026-06-25
- 2026-06-25: closed — issues_spec 84/84 (incl 4 new repo_label cases); full make test green for the change — only failure is parley_harness_golden 7/7, PRE-EXISTING (fails on clean main, unrelated); no integration test touches issue creation; luacheck clean; headless: get_issues_repo_root() → /Users/xianxu/workspace/parley.nvim → prompt renders "[parley.nvim] Issue title: ". Atlas: atlas/issues/issue-management.md documents the [<repo>] prompt label. Actual labeled — active-time found no measurable window.; review verdict: SHIP

- Implemented: pure `repo_label(root)` (basename, vim-free) + IO
  `get_issues_repo_root()` (mirrors `get_issues_dir`'s root resolution) +
  prefixed `cmd_issue_new`'s prompt with `[<label>] `. Verified: `issues_spec`
  84/84 (incl. 4 new `repo_label` cases), luacheck clean, and a headless eval
  confirms the prompt renders `[parley.nvim] Issue title: ` in this repo
  (`[<repo>]` follows the cwd git root, so `[brain]` etc. when in another repo).

