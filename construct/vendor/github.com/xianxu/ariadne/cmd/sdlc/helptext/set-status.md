Flip an issue's `status:` frontmatter field with transition guards
that match the xx-issues skill's contract. Mutates one issue file
in place; bumps `updated:` to today.

STATUSES

  open       not started
  working    actively in progress (requires estimate_hours)
  blocked    waiting on something
  done       completed (closes through `sdlc close`, NOT here)
  wontfix    rejected by intent
  punt       deferred

TRANSITION GUARDS (refusable with --force)

  → working
    Requires `estimate_hours:` present + non-empty in the frontmatter.
    Per xx-issues: starting work without an estimate breaks velocity
    calibration. Add `estimate_hours: <number>` to the frontmatter
    first.

  → done
    Always refused. Use `sdlc close` instead:
      sdlc close --issue N --actual <hours> --verified '<evidence>'
    The close-issue contract (ACTUAL + VERIFIED + atlas check) is
    the real gate; bypassing it via set-status would skip §5 step 3+5.

  done → <anything-not-done>  (reopen)
    Requires a fresh ## Log entry dated today. Reopens carry a
    rationale; the log is where it lands. Add a line like:
      - YYYY-MM-DD: reopened — <reason>
    or a `### YYYY-MM-DD` subheading under ## Log before re-running.

  All other transitions are allowed without guards.

WHAT IT DOES

  - Reads workshop/issues/NNNNNN-*.md for the issue ID
  - Checks the transition is allowed (or --force)
  - Writes a new frontmatter line `status: <new>` (replaces in place,
    preserving field order)
  - Writes `updated: <today>` (replaces in place)
  - Leaves body unchanged. Does NOT commit.

FLAGS

  --issue <n>           workshop issue ID (required)
  <status>              positional: one of open|working|blocked|wontfix|punt
                        (done is refused — use `sdlc close`)
  --force               bypass transition guards
  --dry-run             print the would-be edit; do not write
  --issues-dir <path>   override $WF_ISSUES_DIR / workshop/issues

EXIT CODES

  0   status updated (or dry-run preview, or already at target)
  1   missing issue file, invalid status, transition refused (no --force)

EXAMPLES

  sdlc set-status --issue 42 working
  sdlc set-status --issue 42 blocked
  sdlc set-status --issue 42 open --force      # reopen, no log entry yet
  sdlc set-status --issue 42 punt --dry-run

RELATED

  sdlc close          close → done with the §5 contract (use this for done)
  sdlc lock           sync the new status to origin/main
  sdlc state          inspect current issue statuses
