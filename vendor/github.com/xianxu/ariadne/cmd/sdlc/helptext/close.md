Close an issue or a milestone — perform AGENTS.md §5's mechanical closing
steps. Edits files in place; does NOT commit (the agent commits, usually
bundling close with other work).

MODES

  Issue close:      sdlc close --issue 15 --actual 7 --verified '<evidence>'
  Milestone close:  sdlc close --issue 15 --milestone M4 --actual 2.5 --verified '<evidence>'

  (`milestone-close` is also exposed as its own verb in M6; both forms remain
  valid — milestone-close adds auto-dispatch of `sdlc judge milestone-review`.)

WHAT THE GUARD DEFENDS

  --actual <hours>     focused dev-hours, derived from active-time-v3.
                       Required (refused without it, or --force).
  --verified '<line>'  one-line evidence the work meets done-when (behavior,
                       not artifacts: "tests pass" beats "code written").
                       Required.

  Plus structural checks:
    - atlas/ must have changed in the issue's commit window (§5 step 5)
    - issue's `## Plan` has no unchecked items (issue close only)
    - each milestone listed in ## Plan must carry a `Review-Verdict:`
      trailer on its close commit (issue close only; AGENTS.md §3)
    - milestone-close ticks the `- [ ] M4 — ...` row; refuses if absent
    - project file (if any, under <brain>/data/project/*.md referencing
      <repo>#<id>) gets its task row ticked + detail block updated

  Bypass with --force; the rationale belongs in --verified.

WHAT IT DOES

  - Ticks the milestone box in the issue's ## Plan (milestone mode)
  - Flips status: done, sets actual_hours and updated (issue mode)
  - Appends a log line to ## Log: "YYYY-MM-DD: closed — <verified>"
  - Ticks the project task row + upserts **actual:** and **closed:** in the
    detail block
  - Does NOT git-commit, does NOT move the file to workshop/history/

WARMUP

  On the first 2 invocations per shell session, prints the close-issue
  contract to stderr. After that, silent. Reset by starting a new shell.

FLAGS

  --issue <n>           ariadne workshop issue ID (numeric, zero-pad
                        applied internally; required)
  --milestone <Mx>      milestone tag; presence selects milestone mode
  --actual <hours>      focused dev-hours (required unless --force)
  --verified '<line>'   one-line behavior evidence (required unless --force)
  --force               bypass guards (record reason in --verified)
  --dry-run             print what would change, write nothing
  --brain-dir <path>    project-file lookup root (default ../brain)
  --issues-dir <path>   issues directory (default workshop/issues)

DEEP-DIVE REFERENCES

  AGENTS.md §5                       closing checklist
  brain/data/life/42shots/velocity/  v3 attribution method
    baseline-v3.md
  construct/datatype/project.md      project-file shape & detail blocks

If --actual or --verified is missing, the explainer prints a tailored
active-time-v3 command line for this issue's commit window (with peer
issues auto-discovered from window subject refs), plus a worked example
of a behavior-grounded VERIFIED string. Read the explainer; the contract
is load-bearing.
