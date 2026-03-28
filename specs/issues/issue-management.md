# Issue Management

Repo-local issue tracking with single-file-per-issue markdown format, designed for agentic coding workflows.

## File Format

Each issue is a single `.md` file in `{issues_dir}/` with the naming pattern `NNNN-slug.md`:

```
issues/
  0001-auth-token-refresh.md
  0002-extract-parser.md
  0003-add-retry-tests.md
```

### YAML Frontmatter

```yaml
---
status: open
deps: [0002]
github_issue: 42
created: 2026-03-28
updated: 2026-03-28
---
```

- `status`: `open` | `blocked` | `done`
- `deps`: list of issue IDs (4-digit, zero-padded) that must be `done` before this issue is runnable
- `github_issue`: optional GitHub issue number (set by `make fetch` / `make issue`)
- `created` / `updated`: `YYYY-MM-DD` dates

### Markdown Sections

- `# Title` — issue description
- `## Done when` — acceptance criteria
- `## Plan` — checklist of steps (`- [x]` / `- [ ]`)
- `## Log` — append-only execution notes with `### YYYY-MM-DD` sub-headings

## Configuration

```lua
require("parley").setup({
    issues_dir = "issues",  -- relative to git root (traced up from cwd)
})
```

`issues_dir` is resolved against the git repo root (traced up from `vim.fn.getcwd()`), not Neovim's cwd directly. If not in a git repo, falls back to cwd.

## Commands

| Command | Default Binding | Description |
|---|---|---|
| `:ParleyIssueNew` | `<C-y>c` | Prompt for title, create issue with auto-incremented ID |
| `:ParleyIssueFinder` | `<C-y>f` | Float picker over issues with status badges |
| `:ParleyIssueNext` | `<C-y>x` | Open next runnable issue (cycles through list) |
| `:ParleyIssueStatus` | `<C-y>s` | Cycle frontmatter status: open → blocked → done → open |
| `:ParleyIssueDecompose` | `<C-y>i` | Create child issue from plan line at cursor, add to parent deps |

## Finder

The issue finder (`<C-y>f`) uses the float picker with:
- Display: `[status] NNNN title (#GH) [date]`
- Sort: open first, then blocked, then done (by ID within each group)
- Three view modes cycled via `<C-a>`: open+blocked → all → all+history
- `<C-s>`: cycle status of selected issue
- `<C-d>`: delete selected issue

## Scheduler

`IssueNext` implements a minimal scheduler: scan all issues, find the oldest `open` issue whose `deps` are all `done`. When called from an issue buffer, advances to the next runnable issue after the current one, cycling back to the first when at end. ID allocation scans both `issues/` and `history/` to avoid collisions.

## Decompose

When the cursor is on a plan checklist line (`- [ ] Some task`), `IssueDecompose` creates a child issue from that text, adds the child's ID to the parent's `deps` frontmatter, and appends `→ issue NNNN` to the plan line.

## Archival

Done issues are moved from `issues/` to `history/` by `make push` (main branch) or `make merge` (worktree branch). The issue finder's "all+history" view mode can browse archived issues. GitHub issues with `github_issue:` frontmatter are auto-closed on push/merge.

## Makefile Integration

- `make fetch N` — creates `issues/NNNN-slug.md` from GitHub issue #N with `github_issue: N` frontmatter
- `make issue N` — same as fetch + creates a sibling worktree
- `make push` — pushes, closes GitHub issues for done issues, moves done to `history/`
- `make pull-request` — diffs `issues/` between branch point and HEAD, gathers `github_issue:` IDs for PR body
- `make merge` — merges PR, moves done issues to `history/`, cleans up worktree

## Implementation

- `lua/parley/issues.lua` — core logic (parsing, scheduling, file operations, commands)
- `lua/parley/issue_finder.lua` — float picker UI
- `tests/unit/issues_spec.lua` — unit tests for pure functions
