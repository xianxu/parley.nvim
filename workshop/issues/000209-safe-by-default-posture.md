---
id: 000209
status: open
deps: []
github_issue:
created: 2026-09-02
updated: 2026-09-02
estimate_hours:
---

# safe-by-default posture for a public release

## Problem

Three shipped defaults take actions a public user did not ask for, on a fresh
install:

- `tool_read_roots = {'../'}` (`config.lua:294`) — the parent of cwd. Read tools
  are confined to cwd union that list (`tools/dispatcher.lua:129`), so an agent
  can read every sibling repo and directory on disk. Undocumented.
- `memory_prefs.enable = true` with `max_age_days = 1` (`config.lua:493`), fired
  from `setup()` via `maybe_generate()` (`init.lua:1199`). On first launch it
  shells `grep -r` across every chat root, sends summaries of up to 100 files per
  tag to a third-party model, and writes generated `.md` files back into
  `chat_dir`.
- `cliproxy.auto_download = true` (`config.lua:120`) fetches, verifies and
  `chmod 755`es a third-party release binary. It runs synchronously on the main
  loop with a 300s `--max-time` (`cliproxy.lua:1810-1817`), so a slow network
  freezes the editor; it is pinned to `7.1.71`, which the code elsewhere already
  treats as stale (`cliproxy.lua:911`); and `checksums.txt` is fetched from the
  same origin as the tarball, making it integrity rather than authenticity.
  `config.lua:122-124` already concedes a general distribution may prefer this
  off.

## Spec

Nothing that reads beyond the working directory, sends user data outward, or
places an executable on disk may happen without the user having asked for it.

- Narrow `tool_read_roots` to a default that does not escape cwd. Document the
  opt-in for users who want a wider corpus.
- Default `memory_prefs.enable = false`. Keep the feature and its opt-in path
  intact; the objection is to unrequested startup egress, not to the capability.
- Default `cliproxy.auto_download = false`, and when a binary is absent, tell the
  user what to install and offer the download as an explicit action rather than a
  silent prerequisite. If the download is kept for opted-in users, move it off the
  main loop (`ARCH-CONSTRAINTS`: an editor-startup path must not block on network
  IO; budget is the frame time, not 300s) and unpin or refresh the stale version.
- Each flip is a config-default change plus a test that pins the default, so a
  future edit that re-enables one fails (`ARCH-PURPOSE`: the guard asserts the
  invariant, not a proxy).

## Done when

- On a fresh install with no user config, launching Neovim performs no network
  request and writes no file outside `chat_dir`. Verified by observation, not by
  reading the defaults.
- A test pins each of the three defaults and has been seen red by flipping it.
- Tool read confinement is asserted against a path outside cwd.
- The cliproxy-absent path produces an actionable message naming what to install.

## Plan

- [ ] Flip the three defaults; pin each with a test seen red.
- [ ] Assert read-root confinement rejects a path above cwd.
- [ ] Replace silent auto-download with an explicit, off-main-loop opt-in.
- [ ] Document the opt-ins where a user will look for them.

## Log

### 2026-09-02

Split out of the `workshop/plans/000206-shipping-surface-inventory.md` audit as blockers B2, B4 and B5.
Grouped because all three are unrequested-action defaults with the same shape of
fix; B3 (write tools) is separated into #210 because it needs a consent design
rather than a default flip.
