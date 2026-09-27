---
id: 000209
status: open
started: 2026-09-13T13:08:24-07:00
created: 2026-09-02
updated: 2026-09-13
estimate_hours:
github_issue:
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
