Sync workshop/issues/ changes to origin/main, even from a feature
branch. The workstream-claim primitive: an agent flips `status:
working` on an issue, runs `sdlc lock`, and the claim is broadcast to
origin/main so peer agents see the lock before they start parallel
work.

TWO PATHS

  ON MAIN
    add changed/staged/untracked workshop/issues files
    commit -m "issue-sync: update issues"
    push origin main

  ON A FEATURE BRANCH (or worktree)
    1. find the main worktree via `git worktree list --porcelain`
    2. verify it's on `main`, has no uncommitted issue changes
    3. pull --rebase origin main on the main worktree
    4. detect conflicts (files changed on both branches since
       merge-base) — if any, refuse and print resolution steps
    5. copy each changed issue file from this worktree → main worktree
    6. commit + push on the main worktree
       (commit: "issue-sync: update issues from branch '<branch>'")

WHY THIS POSTURE

Issue files are workflow state, not feature state. They need to land
on `main` quickly so peer agents/workers see status changes without
waiting for the feature branch to merge. Same shape as the
"main is the bulletin board" pattern in ariadne's workflow.

CONFLICT BEHAVIOR

If the same issue file was modified on both your branch and main since
your last merge-base, `sdlc lock` refuses and prints a resolution
recipe (manual merge in the main worktree, then commit+push there). It
does NOT attempt to auto-merge — the file is operator-readable and
auto-merging issue prose has burned us before.

FLAGS

  --issue <n>           sync only this issue's NNNNNN-*.md file
  --issues-dir <path>   override $WF_ISSUES_DIR / workshop/issues
  --dry-run             print what would happen; do not commit/push

EXIT CODES

  0   synced (or no changes, or dry-run)
  1   missing main worktree, dirty main, conflicts, git error

EXAMPLES

  sdlc lock                       # sync all changed issue files
  sdlc lock --issue 31            # sync only #31's file
  sdlc lock --dry-run             # see what would happen
  WF_ISSUES_DIR=issues sdlc lock  # override location

RELATED

  sdlc start          create a worktree (often paired with lock right after)
  sdlc set-status     transition an issue's status: with guards
