Inspect SDLC workflow state for this repo — a read-only "where am I"
surface. Compaction recovery primitive: after a session resume, run
`sdlc state` instead of re-inferring from issue files.

WHAT IT SHOWS

  - Current branch + repo root
  - Issues in workshop/issues/ with status, plan-tick progress
  - Active git worktrees (path + branch)
  - Recent commits on this branch (main..HEAD)
  - Drift checks (inconsistencies between issue status, plan ticks,
    and recent commits)

WHAT IT DOES NOT DO

  - Mutate anything. State is read-only. All mutations funnel through
    `sdlc close`, `sdlc set-status`, `sdlc milestone-close`.
  - Touch network. Local git + filesystem only.

OUTPUT MODES

  - Default: human-readable, terminal-friendly with section headers.
  - `--json`: structured JSON, suitable for tool composition or
    machine consumption.

DRIFT DETECTION

State surfaces structural inconsistencies but does not enforce them
(the binary's enforcement is on the mutating path). Today's checks:

  - Issues with status=working but ## Plan has no ticked items — work
    not started or progress not recorded.
  - Issues with status=done|wontfix|punt but still in workshop/issues/
    (should be archived to workshop/history/).
  - Issue files with no frontmatter / missing status field — broken state.
  - File-read failures (permission denied, broken symlink, etc.) —
    surfaced as warnings so the inventory remains complete.

Drift checks are warnings, not errors. Use the surfaced output to
decide whether to flip status, tick a plan box, or move a done issue
to history.

Deferred to later milestones (not yet implemented):
  - working-but-no-recent-commits — needs commit-window cross-reference,
    lands with M4 (set-status).
  - project-file task-tick vs issue-tick mismatch — needs BRAIN_DIR
    resolution, lands with M6 (milestone-close).
  - atlas-touch surfacing — M7.

FLAGS

  --json                emit machine-readable JSON instead of prose
  --issues-dir <path>   issues directory (default workshop/issues)
  --history-dir <path>  history directory (default workshop/history)

EXAMPLES

  sdlc state                              human-readable summary
  sdlc state --json | jq '.issues'        all issues as JSON
  sdlc state --json | jq '.drift'         drift findings only

RELATED

  sdlc close          close an issue or milestone
  sdlc set-status     transition issue status with guards (M4)
