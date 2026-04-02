# Issue Management

Repo-local issue tracking with single-file-per-issue markdown format, designed for agentic coding workflows.

## File Format
Each issue is `{issues_dir}/NNNN-slug.md` with YAML frontmatter (`status`, `deps`, `github_issue`, `created`, `updated`) and markdown sections (title, done-when, plan checklist, log).

Status lifecycle: `open` -> `working` -> `blocked` -> `done` | `wontfix`.

## Commands
- `:ParleyIssueNew` (`<C-y>c`): create issue with auto-incremented ID
- `:ParleyIssueFinder` (`<C-y>f`): float picker with status badges and view mode cycling (active/all/all+history)
- `:ParleyIssueNext` (`<C-y>x`): open next runnable issue (oldest open with all deps done)
- `:ParleyIssueStatus` (`<C-y>s`): cycle frontmatter status
- `:ParleyIssueDecompose` (`<C-y>i`): create child issue from plan line, add to parent deps

## Archival
Done issues moved to `history/` by `make push` or `make merge`. GitHub issues auto-closed. History is low-signal — agents should avoid reading it unless directed.

## Makefile Integration
- `make fetch N` / `make issue N`: create local issue from GitHub issue
- `make push` / `make merge`: archive done issues, close GitHub issues
- `make pull-request`: gathers issue references for PR body
