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
created: 2026-03-28
updated: 2026-03-28
---
```

- `status`: `open` | `blocked` | `done`
- `deps`: list of issue IDs (4-digit, zero-padded) that must be `done` before this issue is runnable
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

`issues_dir` is resolved against the git repo root, not Neovim's cwd. If not in a git repo, falls back to cwd.

## Commands

| Command | Default Binding | Description |
|---|---|---|
| `:ParleyIssueNew` | `<C-q>c` | Prompt for title, create issue with auto-incremented ID |
| `:ParleyIssueFinder` | `<C-q>f` | Float picker over issues with status badges |
| `:ParleyIssueNext` | `<C-q>x` | Open oldest open issue whose deps are all done |
| `:ParleyIssueStatus` | `<C-q>s` | Cycle frontmatter status: open → blocked → done → open |
| `:ParleyIssueDecompose` | `<C-q>i` | Create child issue from plan line at cursor, add to parent deps |

## Finder

The issue finder (`<C-q>f`) uses the float picker with:
- Display: `[status] NNNN title [date]`
- Sort: open first, then blocked, then done (by ID within each group)
- Default filter: shows open + blocked; toggle done visibility with `<C-a>`
- `<C-s>`: cycle status of selected issue
- `<C-d>`: delete selected issue

## Scheduler

`IssueNext` implements a minimal scheduler: scan all issues, find the oldest `open` issue whose `deps` are all `done`. Returns nil if no runnable issue exists (e.g., circular dependencies or all done).

## Decompose

When the cursor is on a plan checklist line (`- [ ] Some task`), `IssueDecompose` creates a child issue from that text, adds the child's ID to the parent's `deps` frontmatter, and appends `→ issue NNNN` to the plan line.

## Implementation

- `lua/parley/issues.lua` — core logic (parsing, scheduling, file operations, commands)
- `lua/parley/issue_finder.lua` — float picker UI
- `tests/unit/issues_spec.lua` — unit tests for pure functions
