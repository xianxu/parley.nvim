---
id: 000350
status: open
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
github_issue:
---

# move_chat_tree's 🌿 rewrite pass looks unreachable since resolve_chat_path resolves by basename

## Problem

`M.move_chat_tree` (lua/parley/init.lua) runs a pass after the files move that
rewrites `🌿` references pointing at an old location. #265 tried to drive that
pass from a fixture, and it never fires. After the move, `resolve_chat_path`
resolves each reference to the file's NEW location: by its basename in the chat
directories (#224's candidate resolver; an exact hit at the new path wins),
whatever directory the reference names. Even an absolute path to the old place
does this. So `ref_abs == old_abs` and `resolve_chat_path(ref_path, current_root) == old_abs`
are never true for a reference into the moved tree. Traced 2026-10-16 with a
temporary trace in the loop: the reference resolved to `…/secondary/…child.md`,
while path_map's keys were the `…/primary/…` paths.

Either the pass is dead and should go, or there is a reference form that still
needs rewriting (a reference into a tree moved by name collision? a stale
basename?) that should be pinned by a test.
