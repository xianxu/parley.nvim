---
id: 000247
status: working
deps: [000246]
github_issue:
created: 2026-09-13
updated: 2026-09-13
estimate_hours: 4.159
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

## Estimate

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only; calibration remains provisional. Formula maps
to a smaller module (base design 0.15h, impl 0.35h). Launcher maps to one API/IO
integration (1h/0.75h), release orchestration to API integration (1.5h/1h), and
VM orchestration to API integration (2h/1.5h). Guest chat acceptance maps to one
Lua feature (2h/1h). Docs use 0.1h/0.1h; review 0h/0.35h; two live discovery
surfaces use 0h/0.45h each; the generated tap handoff uses small cross-repo
coordination 0.2h/0.2h. Detailed approved contracts apply ×0.2 design discount;
v3.1 applies ×0.4 implementation scaling. Familiarity is 1.0 (existing shell,
Neovim and Git patterns); mature brew/Tart/gh CLIs avoid a novel VM API client.
15% design buffer, no vendor propagation multiplier. Operator OAuth availability
is an external dependency, not fabricated active implementation hours.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: smaller-go-module design=0.03 impl=0.14
item: api-integration design=0.2 impl=0.3
item: api-integration design=0.3 impl=0.4
item: api-integration design=0.4 impl=0.6
item: lua-neovim design=0.4 impl=0.4
item: atlas-docs design=0.02 impl=0.04
item: milestone-review design=0 impl=0.14
item: real-api-discovery design=0 impl=0.18
item: real-api-discovery design=0 impl=0.18
item: cross-repo-refactor-small design=0.04 impl=0.08
design-buffer: 0.15
total: 4.159
```

## Plan

- [ ] Tap repo + formula skeleton depending on neovim; launcher script
- [ ] First-run copy of the starter config; upgrade never overwrites
- [ ] tart VM recipe: image, install, scripted first chat, decoy-config check
- [ ] Release bump script; README install section (brew path first)

## Log

### 2026-09-13

## Revisions

### 2026-09-13T14:43:00-07:00 — packaging execution scope

The operator confirmed #246 then #247. The formula uses #245's default
Darwin projection (ripgrep) plus Neovim; alternate image backends stay optional.
This supersedes all-advisory dependency parity in the original spec.

The implementation plan is [Homebrew launcher](../plans/000247-homebrew-launcher-plan.md).
The launcher respects standard XDG roots, preserves editable init.lua and offers
one atomic init.lua.new candidate. Removal covers config/data/state/cache after
explicitly stopping the owned proxy. These supersede the original XDG_CONFIG_HOME
wording and two-directory removal shorthand.

Live VM acceptance must complete the shipped managed-proxy login → live model →
image-response path. A direct keyed-provider response cannot substitute for it.
A VM credential is usable only if it authenticates that same managed proxy;
otherwise the operator completes OAuth in the guest. That input remains pending.
Fresh-context plan review completed; implementation approval is pending.
