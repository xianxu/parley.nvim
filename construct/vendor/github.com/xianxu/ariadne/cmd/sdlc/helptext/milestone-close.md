Close one milestone of an issue AND auto-dispatch the post-milestone
fresh-context code review (AGENTS.md §3). The canonical closing path
for milestone work — bundles the mechanical close + the mandatory
review into one invocation so neither half is skipped.

WHAT IT DOES

  1. Runs `sdlc close --milestone Mx` semantics:
     - ticks the `- [ ] Mx — ...` item in ## Plan
     - updates the project file's task row + detail block (if any)
     - appends a verification log entry
     - refuses without --actual / --verified (unless --force)
     - refuses if atlas/ wasn't touched in the window (unless --force)

  2. Auto-dispatches `sdlc judge milestone-review`:
     - Finds the first commit referencing `#<issue> <milestone>` in the
       current branch's history
     - Diff window: that commit's parent..HEAD (matches close's atlas
       check window exactly)
     - Builds the milestone-review prompt with issue ref + base/head
     - Invokes the configured agent (claude by default)
     - Surfaces findings + classifies clean / info / failure
     - Parses the first line for SHIP | FIX-THEN-SHIP | REWORK

  3. Emits a trailer block to stdout — paste verbatim into the close
     commit message so `sdlc close` (full-issue close) can later verify
     each milestone was reviewed:

         Review-Verdict: SHIP
         Review-Window: abc1234..HEAD
         [Review-Reason: --no-judge]   (only when verdict is not-run)

  4. Appends "; review verdict: <verdict>" to the just-written log line
     in the issue file so a human grep finds it.

If the close succeeds but the judge dispatch fails (agent CLI missing,
no commits matched, etc.), the verb does NOT fail the close — it logs
a warning, records verdict as `not-run` with a reason, and exits
successfully. The close is the durable mutation; the review is a
follow-on. The trailer block is still emitted so the audit chain stays
intact (operator can re-run the judge and amend the trailer later).

FLAGS

  --issue <n>           ariadne workshop issue ID (required, positive)
  --milestone <Mx>      milestone tag (required)
  --actual <hours>      focused dev-hours for this milestone
  --verified '<line>'   one-line behavior evidence
  --force               bypass close's guards (record reason in --verified)
  --dry-run             plan only; skip both close mutation and judge dispatch
  --no-judge            run the close but skip the auto-dispatched judge
  --agent <name>        agent CLI for the judge: claude | codex | gemini.
                        Default: $AGENT_CMD or claude.
  --brain-dir <path>    project-file lookup root (default ../brain)
  --issues-dir <path>   directory holding issue files

USAGE

  sdlc milestone-close --issue 31 --milestone M4 --actual 6 --verified '...'

  # Skip the review (already ran it manually, or this is a no-code milestone):
  sdlc milestone-close --issue 31 --milestone M4 --actual 0.5 \
    --verified 'docs-only milestone, no code to review' --force --no-judge

  # Preview without mutating or dispatching:
  sdlc milestone-close --issue 31 --milestone M4 --actual 4 --verified '...' --dry-run

RELATED

  sdlc close             same close logic without milestone-review auto-dispatch
  sdlc judge milestone-review --base SHA --head HEAD
                         manual milestone-review invocation for ad-hoc windows
