---
id: 000338
status: working
deps: []
github_issue:
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
card_mirror: 'a4de4bd1707beaff462a940710b24c244d4c44ea' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-15T17:04:18-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "00ecb4cf", done: "dfdbf350"}
---

# Starter adopts an enclosing git project when its profile cwd or TMPDIR is nested in one, escaping the chat root and seeding a tutorial into that repo

## Problem

When the starter runs in an isolated profile whose working directory or TMPDIR sits inside a git checkout, the starter's project discovery takes over. The chat root resolves into the enclosing project instead of the profile, and the starter seeds a bundled tutorial into that repository.

Evidence (the #336 close review, round 1; sidecar `workshop/plans/000336-packaging-vm-focus-flake-close-review.md` in history after #336 lands):
- The review sandbox's TMPDIR was inside the checkout. tests/integration/packaging_vm_spec.lua, "exercises guest fake first use, login prompt and real chat dispatch in an isolated profile", failed at the guest script's FIRST `confined()` call (fake-chat.lua:5, "guest chat root escaped isolated profile"). That call runs before `run("fake")`, so the #336 probe is not involved.
- In that run the starter wrote `workshop/parley/vim-basics.md` into the enclosing repository.
- With TMPDIR outside the repository, the same spec passes 17/0.
- This predates #336. Its trigger is `starter.start()` plus project discovery, not the VM probe.

## Spec

The starter's chat root and tutorial seeding must stay inside the editor profile whatever directory it starts in. That includes a cwd or TMPDIR nested in someone else's git project. Decide whether the starter should ignore project discovery entirely, or adopt a project only when the operator opened one explicitly. Never write into a repository the operator did not choose.

## Done when

- A regression starts the starter with cwd and TMPDIR inside a temporary git repository. It asserts the chat root stays under stdpath("data") and that nothing is written into that repository.
- The packaging_vm_spec guest case passes with TMPDIR inside a git checkout.

## Core concepts

| Entity | Kind | Status | Location | Responsibility |
| --- | --- | --- | --- | --- |
| `starter` | INTEGRATION | modified | `lua/parley/starter.lua` | Seeds and opens the bundled tutorials in the profile's own chat directory, whatever primary chat root project mode selects. |
| `packaging_vm_spec` | INTEGRATION | modified | `tests/integration/packaging_vm_spec.lua` | Host-side guest emulation stays hermetic to marked ancestors, as the launcher does. |
| `starter_project_spec` | INTEGRATION | modified | `tests/integration/starter_project_spec.lua` | Regression: a starter in a marked project, with TMPDIR inside it, writes no tutorial there. |

## Plan

Root cause (traced): the trigger is a `.parley` marker above cwd, not git. `repo_mode.detect_root` walks up from cwd, and `setup()`'s `apply_repo_local` makes `<root>/workshop/parley` the primary `chat_dir`, demoting the profile's chats to the "global" root. Project mode in the app is documented (atlas/infra/starter.md links project mode; starter_project_spec asserts it). The defect is `starter.welcome()`: it seeds the four tutorials and opens welcome.md in `parley.config.chat_dir`, so a no-argument start inside a marked project writes `welcome.md`, `basics.md`, `advanced.md` and `vim-basics.md` into that repository. In #336's review run, TMPDIR sat inside the parley.nvim checkout, which has a `.parley` marker, so the guest emulation entered project mode.

- [ ] `starter.welcome()` targets the profile chat directory: `options.chat_dir`, i.e. `stdpath('data')/chats` or the `PARLEY_CHAT_DIR` override, captured before `setup()`. Tutorials never follow project mode. Project mode keeps its documented primary root, and the profile directory stays registered as its "global" root, so welcome.md is still a recognized chat.
- [ ] Regression in starter_project_spec: a marked project with cwd and TMPDIR inside it. Assert repo mode engages as documented, no tutorial `.md` exists under `<project>/workshop/parley`, the tutorials exist under the profile chats, and the opened buffer is the profile's welcome.md. Show it fails before the fix.
- [ ] packaging_vm_spec guest: set `PARLEY_REPO_MODE=0` in the guest env, as the `parley_app` launcher does. The probe models a fresh VM profile with no project, so a marked host ancestor is outside its scenario. Then run that spec with TMPDIR inside this checkout and show it passes.
- [ ] Atlas starter entry: tutorials live in the profile even in project mode.
- [ ] Verify: focused starter_project and packaging_vm (TMPDIR in- and outside a checkout), then the full suite.

Not in scope: whether the installed app should enter project mode at all. That is documented behavior; changing it is a product decision for the TL.

## Log

### 2026-10-15
