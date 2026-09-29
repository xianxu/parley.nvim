---
id: 000297
status: working
deps: []
github_issue:
created: 2026-09-28
updated: 2026-09-28
estimate_hours:
card_mirror: 'b13b64f82bdedab5f284be4ddf188894795fa205' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-09-28T18:58:22-07:00
---

# Repo-local app demo and development loop

## Problem

Local app testing and introduction-video recordings need a repeatable setup
tracked with the checkout. The personal ~/parley-demo kit depends on Homebrew
and duplicates an older app profile, slowing the edit/relaunch loop.

## Spec

- Add `./parley_app --demo`: stage and launch `demo/workspace/` using this
  checkout's runtime, with no Homebrew lookup or app release. Existing default,
  tutorials and nuke behavior remains compatible.
- Keep tracked configuration in `demo/init.lua` and instructions in
  `demo/README.md`. Reuse the packaged starter via an additional-plugin hook;
  pin Screenkey and show it on startup only for this demo profile. Display
  common keys as plain text for asciinema.
- Generated workspace is ignored by Git. It contains a `.parley` marker, empty
  chat, isolated HOME/XDG profile and local editor state. The nearest marker
  selects the demo as the project root even within the parent marked checkout.
- `--demo --reset` resets chats and editor state and exits, retaining downloaded
  plugins for repeated takes. `--demo --nuke` deletes the owned workspace and
  exits for full first-run reproduction. These explicit commands discard demo
  content; keep recordings outside the disposable workspace. No backup promise.
- Reuse launcher ownership, lock and live-editor checks for every reset. Only
  the fixed `demo/workspace/` is allowed inside the checkout; reject symlinked
  demo ancestry. PARLEY_DEMO_DIR remains for the existing non-demo mode only.
- Running editor must be closed before reset. Ordinary launches retain edits.
  First launch downloads dependencies; subsequent launches use the same plugin
  cache. Default launch opens the empty chat; explicit Neovim arguments pass on.
- Preserve ordinary config, ~/parley-demo and ~/parley-demo-setup. This is a
  development-only configuration; Screenkey is not added to packaged defaults.

## Done when

- [ ] A real `--demo` startup loads the checkout, Screenkey and demo config,
  selects the nested root, and opens a recognized empty chat by default.
- [ ] Reset retains plugins but clears chats/state; full nuke clears owned
  workspace; repeated launches preserve trials until reset.
- [ ] Tests prove unrelated directories, symlink targets and tracked config
  survive; active/competing operations refuse; old launcher modes still pass.
- [ ] Repo-local demo commands, dependency/auth behavior, configuration and
  recording/reset instructions are documented with README/TOOLING/atlas links.

## Plan

- [ ] Extend launcher tests first: demo environment/default chat, reset/nuke,
  nested root, ownership/concurrency and legacy-mode regressions.
- [ ] Extend existing launcher staging and add thin demo config, reusing the
  starter through a plugin-spec extension. Ignore generated demo paths.
- [ ] Run launcher and starter checks plus a real startup from the checkout;
  document usage and close with the SDLC review.

## Log

### 2026-09-28

- User approved repo-local demo design and requested a ticket and clearly
  separate demo configuration. Related video work: #207; supersedes the
  packaging direction withdrawn in #296.
- Confirmed `repo_mode.detect_root` chooses the nearest marker in a real
  headless probe. Existing parley_app forces repo mode off and disallows all
  in-checkout profiles, so demo mode must explicitly change both boundaries.
- ARCH-DRY: reuse the launcher's existing ownership/serialization and packaged
  starter; do not import the separate personal Python/Homebrew launcher.
- ARCH-PURE: new surface is small launch/config IO glue; no new core entity.
- Scope is one atomic change targeting the quick-flow shell (<=100 code lines
  added, no milestones). Tests exercise the process boundary with the existing
  stateful fake editor and real Neovim; no new service or registry is added.
