---
id: 000338
status: codecomplete
deps: []
github_issue:
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
card_mirror: 'a235e4561606a79e535df15f8f50a42d2f601d58' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-15T17:04:18-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "00ecb4cf", done: "dfdbf350"}
actual_hours: 0.57
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

- A regression starts the starter with cwd and TMPDIR inside a `.parley`-marked project. It asserts that the documented project mode engages, that welcome.md opens from the profile chat directory as a recognized chat, and that every tutorial is in the profile and none is in the project (revised 2026-10-15, see Revisions).
- The packaging_vm_spec guest case passes with TMPDIR inside a marked checkout, keeping its chat root under stdpath("data").

## Core concepts

| Entity | Kind | Status | Location | Responsibility |
| --- | --- | --- | --- | --- |
| `starter` | INTEGRATION | modified | `lua/parley/starter.lua` | Seeds and opens the bundled tutorials in the profile's own chat directory, whatever primary chat root project mode selects. |
| `packaging_vm_spec` | INTEGRATION | modified | `tests/integration/packaging_vm_spec.lua` | Host-side guest emulation stays hermetic to marked ancestors, as the launcher does. |
| `scratch_placement_spec` | INTEGRATION | modified | `tests/arch/scratch_placement_spec.lua` | Harness guard: test scratch has no project-marked ancestor. |
| `starter_project_spec` | INTEGRATION | modified | `tests/integration/starter_project_spec.lua` | Regression: a starter in a marked project, with TMPDIR inside it, writes no tutorial there. |

## Plan

Root cause (traced): the trigger is a `.parley` marker above cwd, not git. `repo_mode.detect_root` walks up from cwd, and `setup()`'s `apply_repo_local` makes `<root>/workshop/parley` the primary `chat_dir`, demoting the profile's chats to the "global" root. Project mode in the app is documented (atlas/infra/starter.md links project mode; starter_project_spec asserts it). The defect is `starter.welcome()`: it seeds the four tutorials and opens welcome.md in `parley.config.chat_dir`, so a no-argument start inside a marked project writes `welcome.md`, `basics.md`, `advanced.md` and `vim-basics.md` into that repository. In #336's review run, TMPDIR sat inside the parley.nvim checkout, which has a `.parley` marker, so the guest emulation entered project mode.

- [x] `starter.welcome()` targets the profile chat directory: `options.chat_dir`, i.e. `stdpath('data')/chats` or the `PARLEY_CHAT_DIR` override, captured before `setup()`. Tutorials never follow project mode. Project mode keeps its documented primary root, and the profile directory stays registered as its "global" root, so welcome.md is still a recognized chat.
- [x] Regression in starter_project_spec: a marked project with cwd and TMPDIR inside it. Assert repo mode engages as documented, no tutorial `.md` exists under `<project>/workshop/parley`, the tutorials exist under the profile chats, and the opened buffer is the profile's welcome.md. Show it fails before the fix.
- [x] packaging_vm_spec guest: set `PARLEY_REPO_MODE=0` in the guest env, as the `parley_app` launcher does. The probe models a fresh VM profile with no project, so a marked host ancestor is outside its scenario. Then run that spec with TMPDIR inside this checkout and show it passes.
- [x] Atlas starter entry: tutorials live in the profile even in project mode.
- [x] BR-1 (class fix): `scratch_placement_spec` also requires that tempname() and $HOME have no `.parley`-marked ancestor, so every spec's "no project" scenario is protected at the harness rather than one spec at a time.
- [x] Verify: focused starter_project and packaging_vm (TMPDIR in- and outside a checkout), then the full suite.

Not in scope: whether the installed app should enter project mode at all. That is documented behavior; changing it is a product decision for the TL.

## Log

- 2026-10-15 (:3): red: the regression (profile welcome opened, every tutorial in the profile, none under the project's workshop/parley, plus a new case with cwd and TMPDIR inside the marked project) failed all 3 marked-project cases 3/3 with welcome.md opened from `<project>/workshop/parley`. Green after `welcome(parley, roots, options.chat_dir)` (the primary chat_dir is still restored after seeding): starter_project 6/0, including the profile welcome being a recognized chat. packaging_vm_spec with TMPDIR inside this checkout (which has `.parley`): without `PARLEY_REPO_MODE=0` it fails 16/1 at `fake-chat.lua:4` "guest chat root escaped isolated profile" (the reviewer's finding reproduced), and no tutorial lands in the checkout's workshop now. With it: 17/0.

### 2026-10-15
- 2026-10-15: closed — Prior evidence stands (starter_project 6/0, packaging_vm 17/0 with TMPDIR in a marked checkout, full suite exit 0 on 544ef394, class guard red 6/1 / green 7/0). Round 2 Minor folded in: guard checks HOME itself; synthetic marked-HOME case red 7/1 before the one-line fix, 8/0 after; lint clean.; review verdict: SHIP
- 2026-10-15: closed — Red: starter_project regression failed all 3 marked-project cases; packaging_vm_spec with TMPDIR inside this .parley checkout failed 16/1. Green: welcome seeds/opens in the profile chat dir captured before setup; starter_project 6/0; packaging_vm 17/0 with TMPDIR inside checkout; full make -k test exit 0 on 544ef394. BR-1 class: suite with TMPDIR in a marked tree failed 14 files; scratch_placement_spec now rejects a marked scratch ancestor (red 6/1 under an outside marked TMPDIR, green 7/0).; review verdict: SHIP
- Full suite (make -k test) on 544ef394: exit 0, lint clean (738 files); starter_project, starter_* and packaging_vm_spec PASS.
- Close review round 1, BR-1 (Important): the starter_project no-marker case fails when TMPDIR sits inside this marked checkout. Class sweep: the full suite with TMPDIR inside the checkout failed 14 files (arch/scratch_placement, git_markdown_source, issue_card_view, issue_command, issue_finder_tracker, issue_tracker, issue_tracker_buffer, markdown_finder_async, packaging_release, open_reference, starter_bootstrap, starter_project, starter_config, zero_config) and left an empty chat in the checkout's workshop/parley, which I removed. That configuration already breaks the #202 harness invariant that scratch stays outside the repo, and scratch_placement_spec failed on it. The invariant's gap is a marked ancestor OUTSIDE this repo, which no guard covered. Fix at the harness: a guard case requiring tempname() and $HOME to have no `.parley`-marked ancestor. Red: TMPDIR under an outside marked directory fails it 6/1 with the reason. Green: 7/0 under the normal harness. Per-spec opt-outs were rejected: the no-marker case tests discovery, so it must not set PARLEY_REPO_MODE=0.

- Round 2 advisory (Minor, folded in at the TL's SHIP): the ancestor guard checked the parent of $HOME, so a marker in $HOME itself slipped through. It is now a `marked_scratch(tempname, home)` helper; a new case with a synthetic marked HOME failed before the one-line fix (7/1) and passes after (8/0). Lint clean.

## Revisions

- 2026-10-15: narrowed Done-when bullet 1. The trigger is a `.parley` marker (documented project mode), not any git repository. Inside a marked project the primary chat root legitimately becomes the project's; the invariant defended is that nothing is written into the project (tutorials and welcome stay in the profile). The chat-root-in-profile assertion stays where the scenario has no project: the VM guest, made hermetic with `PARLEY_REPO_MODE=0` like the launcher.
