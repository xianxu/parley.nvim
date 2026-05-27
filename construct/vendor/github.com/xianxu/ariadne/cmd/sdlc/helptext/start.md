Create a new git worktree on a fresh branch under
../worktree/<repo-dir-name>/<branch-name>/ and write the path to .goto
so the `g` shell alias can `cd` there. The "begin work" verb that
complements `sdlc fetch`.

NAME RESOLUTION PRIORITY

  1. --name <X>       use as-is for branch + worktree name
  2. --issue N        derive name from workshop/issues/NNNNNN-*.md
                      basename (e.g. 000042-add-feature)
  3. (no flag)        scan workshop/issues/ for untracked NNNNNN-*.md
                      files. If exactly one matches, use it. Zero or
                      multiple → error.

UNTRACKED ISSUE-FILE COMMIT

When modes 2 or 3 resolve to a file that's still untracked, `sdlc start`
commits + pushes it before creating the worktree so the new branch
starts from a tracked state. Commit message: "committing issue file
before creating worktree" (verbatim from the legacy `make worktree`
target). Push failure is a warning, not fatal — the worktree creation
proceeds.

WHAT IT DOES

  - Resolves the name (above), commits the untracked issue file if any
  - mkdir -p ../worktree/<repo-dir-name>/
  - git worktree add -b <name> ../worktree/<repo-dir-name>/<name> HEAD
  - Writes the worktree path to <repo-root>/.goto

WHAT IT DOES NOT DO

  - Switch your shell into the worktree. That's the `g` alias's job
    (defined in the operator's shell rc as `cd "$(cat .goto)"`).
  - Touch the worktree's content beyond `git worktree add`. The new
    branch starts at HEAD with no extra commits.

FLAGS

  --issue <n>           workshop ID; resolves to issues/NNNNNN-*.md
  --name <slug>         explicit branch + worktree name
  --issues-dir <path>   override $WF_ISSUES_DIR / workshop/issues
  --dry-run             print would-be operations; do nothing

EXAMPLES

  sdlc start                        # auto-detect from single untracked
  sdlc start --issue 42             # explicit issue file
  sdlc start --name codename-x      # ad-hoc branch, no issue link
  sdlc start --dry-run              # see what would happen

EXIT CODES

  0   worktree created (or dry-run completed)
  1   ambiguous auto-detect, missing issue file, git error,
      both --name and --issue given (mutually exclusive)

RELATED

  sdlc fetch          create a workshop issue file
  sdlc lock           sync issue files to origin/main
