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
- [x] First-run copy of the starter config; upgrade never overwrites
- [ ] tart VM recipe: image, install, scripted first chat, decoy-config check
- [ ] Release bump script; README install section (brew path first)

## Log

### 2026-09-13 — implementation and VM checkpoint

Operator approved implementation with “continue”; #246 is merged as PR #180
and released v2.2.0. #247 passed change-code plan quality round 1 and estimate
gates. Formula/release tests pass (8 cases); launcher passes 10 adversarial
filesystem/process cases, including the owner-record initialization race found
and repaired during testing. VM harness tests pass 7 cases; actual upgrade and
final removal verification are being integrated.

One owned clean VM is booted and guest Homebrew is ready. Its manifest is
`/private/tmp/parley-vm-247-20260913/manifest.json`; reservation is
`~/.cache/parley-vm-acceptance.owner`. Resume through the harness; preserve
`tools-test` and the cached image. Clone observed 184320 bytes additional disk
allocation with auto-pruning disabled. No public tap has been created yet.
Actual managed-proxy OAuth and image response remain pending guest login.

### 2026-09-13 — local checks

Launcher preparation measured over 20 warm runs: median 16.1 ms, maximum 20.1 ms.
Lint passed 428 Lua files plus all three packaging Lua files. First full suite
passed behavioral specs; the architecture-only failure identified omitted
packaging scan scope and missing traceability. Corrected both; all 21 focused
architecture checks now pass. Final VM reducer and guest upgrade conformance
remain in progress before the local close review.

### 2026-09-13 — local implementation accepted by tests

Final make test passed all 246 spec files and lint across 431 Lua files.
The owned VM harness now requires five evidence records and successful VM
removal before reporting completion. Actual public tap installation, real guest
Homebrew upgrade and managed OAuth/image response follow the local review under
the approved plan; these remain unchecked and must precede merge. The local tap
README and generated formula shape are reviewable; the real archive SHA is only
available after the reviewed immutable tag is published.

### 2026-09-13 — close review round 1 repaired

BR-1 installed-layout-conformance: reproduced the missing-starter failure with
an actual prefix/share vs libexec fixture, then read the installed share source
and made both fixture versions move it as Homebrew does. Public restoration now
runs the real launcher. All 3 upgrade cases pass, including a failure assertion
that proves brew upgrade itself was reached. BR-2 pure-test-io-separation:
moved Ruby syntax execution to release integration; 2 pure renderer and 6 release
cases pass. Lint remains clean across 431 files. Both finding classes are recorded
in lessons; public/live acceptance is still pending the reviewed release.

### 2026-09-13 — close review round 2 repaired

BR-1 and BR-2 were accepted as addressed. BR-3 found fake VM tests still consumed
the host's real disk budget. The VM entry now accepts an injected capacity probe;
its test-only runner supplies deterministic capacity and proves 59 GiB refuses
before any Tart call while releasing ownership. The production entry still uses
actual disk capacity with no bypass CLI/environment input. Test-first runner
failed before the seam; all 11 VM cases now pass. No real VM state was changed.

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
