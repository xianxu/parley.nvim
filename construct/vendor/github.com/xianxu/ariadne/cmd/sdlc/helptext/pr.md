Open a GitHub pull request for the current worktree branch. Pushes the
branch with upstream tracking and links every touched issue file's
`github_issue:` frontmatter as `Fixes #N, #M, ...` in the PR body.

REFUSES IF

  - current branch is empty (detached HEAD)
  - current branch == main (use `sdlc push` for direct-on-main flow)

WHAT IT DOES

  1. Computes the merge base of main and HEAD (fallback: `main`).
  2. `git diff --name-only <base>..HEAD -- workshop/issues/*.md` →
     reads `github_issue:` from each, dedupes + numeric-sorts.
  3. `git log main..HEAD --pretty='- %s'` → the commit list for the body.
  4. `git push -u origin <branch>` (sets upstream tracking).
  5. `gh pr create --repo <owner/repo> --base main --head <branch>`:
       - if any github_issue numbers found → `--fill-first --body <body>`
         where body = "<commits>\n\n<Fixes #1, #2>" (or just one of the two)
       - if no numbers → `--fill` (let gh derive body from commits)

FLAGS

  --dry-run             print would-be push + gh command; do not run
  --issues-dir <path>   override $WF_ISSUES_DIR / workshop/issues

EXAMPLES

  sdlc pr                 # push, open PR
  sdlc pr --dry-run       # see PR body + would-be command

EXIT CODES

  0   PR created (or dry-run completed)
  1   on main / detached, push failure, gh pr create failure

PR BODY SHAPE

  When the diff touches workshop issues with github_issue frontmatter,
  the body has two halves separated by a blank line:

    - commit subject 1
    - commit subject 2
    - ...

    Fixes #42, #43

  The `Fixes` line uses GitHub's auto-close semantics: merging the PR
  closes those issues. That's why `sdlc push`'s archive logic only
  closes GH issues for direct-on-main work — for PR work, the merge
  itself handles it.

RELATED

  sdlc push       direct-on-main counterpart (no PR, ships from main)
  sdlc merge      after PR opens + reviews land, merge + clean up
  sdlc start      create the worktree branch this verb operates on
