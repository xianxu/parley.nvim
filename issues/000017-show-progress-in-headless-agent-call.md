---
id: 000017
status: open
deps: []
created: 2026-03-29
updated: 2026-03-29
---

# show progress in headless agent call

`make pre-merge` uses headless agent to check on coding principles (aka constitution). currently there's no progress shown. we should display output from agent, maybe just one line, so that we know progresses made.

## Done when

- Progress is visible in real-time during `make pre-merge` agent checks

## Plan

- [x] Add `run_agent_with_progress()` function using `--output-format stream-json` + `jq` parser
- [x] Replace plain pipe on agent invocation line with new function
- [x] Add `jq` fallback for environments without it
- [ ] Manual verification: run `scripts/pre-merge-checks.sh dry` and confirm progress displays

## Log

### 2026-03-29

- Added `run_agent_with_progress()` to `scripts/pre-merge-checks.sh`
- Uses `--output-format stream-json` to get real-time events from `claude -p`
- Parses `assistant` events for `tool_use` to show `⟳ ToolName hint` on a single updating line
- Extracts `result` event for final text display
- Falls back to original `sed` pipe when `jq` is unavailable
- Fixed `git_diff_context()`: on main, diffs against `origin/main` (was diffing against self → empty diff, silently skipping dry/pure/specs checks)
