---
id: 000270
status: open
deps: []
github_issue:
created: 2026-09-19
updated: 2026-09-19
estimate_hours:
---

# Tree move's branch-reference rewrite never fires

## Problem

Found during parley#261 M2 (review BR-25). The `🌿:` rewrite pass in
`M.move_chat_tree` (`lua/parley/init.lua`, the loop that follows the moves)
did not fire in any configuration tried:

- **A timestamped reference resolves by glob.** Since #224, it goes to the
  file's new location, so the pass's check that a reference pointed at an old
  path (`ref_abs == old_abs`) never matches.
- **A stable-named tree (no timestamps) produced no rewrite either.** The
  reason is not yet established; tree discovery may not reach the child.

The existing test "a failed folder move is reported after the .md moved and
the 🌿 line was rewritten" passes without any rewrite happening: it reads the
file, whose line was already canonical.

## Spec

Establish when, if ever, the rewrite is reachable. If it is not, delete it and
correct that test's name. If it is, make it reachable only where it is needed,
and test its loaded-buffer arm: the rewrite goes into the buffer, and the file
under it is not written.

## Done when

- The rewrite pass is either removed as unreachable, or covered by a test that
  drives it for both a loaded and an unloaded chat.
- No test's name claims a rewrite that its assertions cannot distinguish from
  a no-op.

## Plan

- [ ] Probe reachability, decide, implement, test.

## Log

### 2026-09-19

Filed from #261 M2's boundary review. #261 kept the lookup change (a loaded
chat's buffer, via `helper.chat_lines`) behaviour-preserving, and pinned only
that a tree move leaves a loaded chat's unsaved text and its file alone.
