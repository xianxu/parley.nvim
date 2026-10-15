---
id: 000338
status: open
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
github_issue:
---

# Starter adopts an enclosing git project when its profile cwd or TMPDIR is nested in one, escaping the chat root and seeding a tutorial into that repo

## Problem

When the starter runs in an isolated profile whose working directory or TMPDIR sits inside a git checkout, the starter's project discovery takes over. The chat root resolves into the enclosing project instead of the profile, and the starter seeds a bundled tutorial into that repository.

Evidence (the #336 close review, round 1; sidecar `workshop/plans/000336-packaging-vm-focus-flake-close-review.md` in history after #336 lands):
- The review sandbox's TMPDIR was inside the checkout. tests/integration/packaging_vm_spec.lua, "exercises guest fake first use, login prompt and real chat dispatch in an isolated profile", failed at the guest script's FIRST `confined()` call (fake-chat.lua:5, "guest chat root escaped isolated profile"). That call runs before `run("fake")`, so the #336 probe is not involved.
- In that run the starter wrote `workshop/parley/vim-basics.md` into the enclosing repository.
- With TMPDIR outside the repository, the same spec passes 17/0.
- This predates #336. Its trigger is `starter.start()` plus project discovery, not the VM probe.
