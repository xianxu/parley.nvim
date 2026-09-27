---
id: 000270
status: open
created: 2026-09-19
updated: 2026-09-19
estimate_hours:
github_issue:
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
