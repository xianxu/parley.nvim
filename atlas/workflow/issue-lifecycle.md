# Issue Lifecycle

## Flow

```
GitHub Issue → make fetch 42 → workshop/issues/000042-slug.md → work → make push (or make worktree → make pull-request → make merge)
```

## States

| Status | Meaning |
|--------|---------|
| open | Active work |
| working | An agent is working on something |
| done | Completed, awaiting archive |
| wontfix | Declined |
| punt | Deferred |

## Transitions

1. **Fetch**: `make fetch <num>` creates a local issue file from GitHub with frontmatter (id, status, github_issue, dates)
2. **Work**: Agent works within the issue file — updates Plan, Log, Spec sections
3. **Small work on main**: `make push` auto-commits, runs pre-merge checks, pushes, archives done issues to `history/`, closes GitHub issues
4. **Large work on branch**: `make worktree` → isolated branch → `make pull-request` → `make merge` → archives and cleans up

## Worktree layout

Worktrees are created at `../worktree/<repo-dir-name>/<branch-name>/`, keeping
worktrees from different repos separated. The `<repo-dir-name>` is the basename
of the current working directory (i.e., the repo folder name).

```
../worktree/
└── my-repo/
    ├── 000042-add-feature/    ← branch: 000042-add-feature
    └── 000051-fix-bug/        ← branch: 000051-fix-bug
```

**Auto-detection**: `make worktree` (no argument) looks for exactly one untracked
file in `issues/` matching `NNNNNN-*.md`. If found, it uses the basename (minus
`.md`) as both the branch name and worktree directory name. If zero or multiple
matches exist, it fails and lists them.

**Navigation**: worktree creation writes the path to `.goto`; the shell `g`
alias reads it to `cd` you there. `make merge` writes the main worktree path
back into `.goto` for the return trip.

## Issue file structure

```markdown
---
id: 000042
status: open
deps: []
github_issue: 42
created: 2026-04-20
updated: 2026-04-20
---

# Title

## Done when
- acceptance criteria

## Spec
- brainstorming results (if needed)

## Plan
- [ ] checklist of work

## Log
### 2026-04-20
- what happened
```
