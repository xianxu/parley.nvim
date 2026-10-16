---
id: 000350
status: working
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
card_mirror: '7a1b5dcd9b192b61cc52c170f9909b8d65f49786' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T04:13:22-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
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

## Spec

## Done when

- [x] It is established, with a test or a measurement, whether any reference reaches the rewrite branch after a tree move.
- [x] If none does, the pass is removed with its live-buffer edit (#265 converted it to edit_user_lines); if some does, a test drives it.

## Plan

Outcome (2026-10-16): **the pass is reachable; it stays, and is now pinned.** The issue's premise was mine, from #265, and it is wrong.

Evidence: every tree file moves flat to `target/<basename>` before the pass runs. `resolve_chat_path` returns one of three things:
- an existing candidate;
- an existing timestamp-glob match;
- when neither exists, the first candidate unchanged.

The first two are existing files, and the old path no longer exists, so they never match. The third can:
- **Condition 1** (`ref_abs == old_abs`): a reference with an explicit directory (absolute, `~`, `../`) to a child WITHOUT a timestamp. No glob can find the moved copy, so the resolver returns the literal old path.
- **Condition 2** (resolving from the old root): `sub/<name>` to a non-timestamp child. The flattening moves it to `target/<name>`. From the new directory the fallback is `target/sub/<name>`; from the old root it is the old path.

#265's single trace used a TIMESTAMPED child, which the glob always finds, and generalized from it.

- [x] A test per condition. Mutation: with the branch disabled (`if false`) condition 1's case fails; with only condition 1 kept, condition 2's case fails.
- [x] The #265 coverage gap closed: a rewrite refused in an open buffer (real capacity hold) is reported, and the move still completes. Mutation: dropping the error collection fails it.
- [x] A code comment at the pass and the atlas `lifecycle.md` say when it fires, so it is not re-filed as dead.

## Log

### 2026-10-16
- 2026-10-16: closed — Full suite green on 0ea8a86d (sdlc-local/suite, main merged). Established by tests that the chat-move reference rewrite IS reachable: (1) an absolute reference to a non-timestamp child, (2) a sub/name reference to a flattened non-timestamp child; each case fails when its condition is removed (mutation). Kept, not deleted. Plus the refused-rewrite report (real capacity hold; the move completes; mutation of the error collection fails it). Documented at the pass and in atlas lifecycle.md.; review verdict: SHIP
