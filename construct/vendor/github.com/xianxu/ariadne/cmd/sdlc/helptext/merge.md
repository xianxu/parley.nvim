Merge the current worktree branch into main via GitHub, archive any
completed issues, and clean up the worktree. The longest + most
safety-conscious checkpoint guard — every step has a refusal or
confirmation, because the actions are irreversible.

REFUSES IF

  - current branch is empty (detached HEAD)
  - current branch == main (use `sdlc push` instead)
  - uncommitted changes exist (commit or stash first)
  - no upstream is configured for the branch
  - branch is ahead of upstream (unpushed local commits — push first)

WHAT IT DOES

  1. Verifies the four refusal conditions above.
  2. Runs pre-merge judges: `sdlc judge plan`, `specs`, `lessons`.
     Skip with `--no-judge`.
  3. Locates the main worktree via `git worktree list --porcelain`.
  4. Shows unmerged commits (`git log main..HEAD --oneline`) for
     situational awareness.
  5. Scans touched issue files vs `main` for not-done statuses;
     warns + prompts unless `--yes`.
  6. INTERACTIVE CONFIRMATION (skippable with `--yes`):
       "Final confirmation: proceed with irreversible merge/cleanup
        actions? [y/N]"
  7. Finds the open PR for the branch via `gh pr list`.
       - if PR exists: `gh pr merge --merge --delete-branch`, then
         `git pull` in the main worktree.
       - if no PR + unmerged commits: prompts to either create a PR
         (re-run after `sdlc pr`) OR remove the worktree without
         merging (operator confirms each).
  8. Archives done/wontfix/punt issue files into `workshop/history/`
     in the MAIN worktree (not the feature worktree); commits + pushes
     on main if any moved. Unlike `sdlc push`, does NOT call
     `gh issue close` — the PR merge already closes linked issues
     via the "Fixes #N" body.
  9. `git worktree remove <wt-path>` + `git branch -D <branch>`,
     both run from the main worktree (worktree-remove on self is
     undefined). Writes the main worktree path to `<wt-path>/.goto`
     so the `g` shell alias lands the operator back on main.

FLAGS

  --yes                 skip both the not-done warn AND the final confirm
  --no-judge            skip pre-merge judges (emergency only)
  --dry-run             print would-be operations; do nothing
  --issues-dir <path>   override $WF_ISSUES_DIR / workshop/issues
  --history-dir <path>  override $WF_HISTORY_DIR / workshop/history

EXAMPLES

  sdlc merge                    # full flow, both prompts presented
  sdlc merge --yes              # skip not-done + final confirm
  sdlc merge --no-judge         # emergency: bypass pre-merge judges
  sdlc merge --dry-run          # see what would happen

EXIT CODES

  0   merged + worktree cleaned (or dry-run completed)
  1   any refusal condition, judge failure, gh pr merge failure,
      operator-aborted at confirmation

IRREVERSIBLE ACTIONS

  - `gh pr merge --merge --delete-branch` — the PR merges and the
    GitHub branch is deleted. Reopening means re-pushing the local
    branch.
  - `git branch -D <branch>` — local branch deleted from the main
    worktree's index.
  - `git worktree remove <wt-path>` — the feature worktree directory
    is removed.

  All of the above gate behind the "Final confirmation:" prompt
  unless `--yes` was passed. `--yes` exists for scripted flows where
  the operator has already confirmed elsewhere.

RELATED

  sdlc pr         open the PR this verb merges
  sdlc push       direct-on-main counterpart (no PR, no worktree)
  sdlc judge      one-category check (run by merge as pre-flight)
