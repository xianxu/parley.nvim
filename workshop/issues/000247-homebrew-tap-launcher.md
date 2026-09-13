---
id: 000247
status: working
deps: []
github_issue:
created: 2026-09-13
updated: 2026-09-13
estimate_hours:
started: 2026-09-13T14:26:40-07:00
---

# Homebrew tap and parley launcher: brew install xianxu/parley/parley, tested on a clean tart VM

## Problem

The `parley-packaging` project's end state: `brew install xianxu/parley/parley`
followed by `parley` starts a working chat for someone who has never used
Neovim, with Claude, Codex and Gemini available through the managed cliproxy
and no API key typed.

## Spec

- **A personal tap** (`xianxu/homebrew-parley`): Homebrew core will not take
  an editor-plugin app, and a tap keeps the release cadence in our hands.
  The formula depends on `neovim` and on the advisory tools #245 lists for
  macOS (ripgrep; ImageMagick only if #244 needs it beyond `sips`), installs
  the starter config from #246 as the app's config under
  `$(brew --prefix)/share/parley/config`, and installs a `parley` launcher.
- **The launcher**: `NVIM_APPNAME=parley` with `XDG_CONFIG_HOME` pointed at a
  per-user copy of the starter config (first run copies it to
  `~/.config/parley/` so the user may edit it; later formula upgrades never
  overwrite an edited copy — they place a `.new` beside it). Arguments pass
  through to nvim, so `parley notes.md` works.
- **cliproxyapi stays parley-managed** (downloaded on first use, updated by
  `:ParleyProxy update`) — it is not a formula dependency, by operator
  decision: its configuration is complex and parley owns it.
- **Testing on a clean machine** is part of the definition of done, not a
  manual step: a `tart` VM image with macOS and Homebrew, no `~/.config/nvim`,
  runs the formula install and a scripted first chat (headless nvim,
  `:ParleyProxy login` cannot be automated — the login step is asserted up to
  its prompt; a provider with an API key in the VM's keychain covers the send)
  plus the "existing `~/.config/nvim` untouched" check with a decoy config.
- A release process: tagging the plugin publishes a formula bump (a script
  in this repo writes the tap's formula with the new tag and sha256).
- Explicitly out for now: Linux and Windows packaging; auto-upgrading
  advisory tools.

## Done when

- The project's `done_when` holds on the tart VM: install, `parley`, a
  provider login reaches its prompt, a question with a pasted image is
  answered through a keyed provider, and a decoy `~/.config/nvim` is
  byte-identical afterwards.
- `brew uninstall parley` plus removing `~/.config/parley` and
  `~/.local/share/parley` leaves no trace.
- The formula's dependency list matches #245's advisory tier (test).
- The tag→formula bump script is documented and used for at least one release.

## Plan

- [ ] Tap repo + formula skeleton depending on neovim; launcher script
- [ ] First-run copy of the starter config; upgrade never overwrites
- [ ] tart VM recipe: image, install, scripted first chat, decoy-config check
- [ ] Release bump script; README install section (brew path first)

## Log

### 2026-09-13
