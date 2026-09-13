---
id: 000245
status: open
deps: [000213]
github_issue:
created: 2026-09-13
updated: 2026-09-13
estimate_hours:
---

# Dependency registry and honest install advice: managed cliproxyapi, platform tools, brew one-liners in checkhealth

## Problem

parley depends on external binaries in three different ways and reports none
of them coherently. cliproxyapi is downloaded and managed by parley itself
(#131, #237) because its configuration is complex; `osascript` and `sips`
ship with macOS; ripgrep, ImageMagick, `wl-clipboard`/`xclip` are ordinary
package installs. A new user discovers a missing tool only when a feature
fails at runtime, and `:checkhealth parley` cannot tell them what to run.
Part of the `parley-packaging` project.

## Spec

- **One dependency registry** (pure data, `lua/parley/deps.lua`): each entry
  names the binary, its tier, how to detect it (`executable`, or the managed
  install record for cliproxyapi), which feature needs it, and the install
  advice. Tiers, decided by the operator 2026-09-13:
  - `managed` — cliproxyapi only: parley installs and updates it (existing
    `cliproxy` machinery), because its configuration is complex and its
    version matters for model access.
  - `platform` — `osascript`, `sips`: present on every Mac; detect and report.
  - `advisory` — ripgrep, ImageMagick/ffmpeg (#244's shrink recipes),
    `wl-clipboard`/`xclip` on Linux: detect, and print the exact one-line
    install command for the host (`brew install …`, `apt install …`). Parley
    never runs a package manager itself. No upgrade management: these tools
    are stable enough that a user not upgrading is not a problem.
- **`:checkhealth parley`** derives its dependency section from the registry
  (#213 makes checkhealth honest; this issue gives it the single source):
  OK / missing with the install line / managed with the installed version.
  Optional features degrade with a one-time notice naming the registry
  entry, not a stack trace (the #231 and #244 recipes already do this; they
  should read their advice from the registry, `ARCH-DRY`).
- The Homebrew formula (#247) lists the advisory tools as formula
  dependencies, so a brew user never sees the advice at all; this registry is
  the truth the formula's dependency list is checked against by a test.

## Done when

- `:checkhealth parley` shows every registry entry with its tier and status,
  and a missing advisory tool shows the exact install command for the host.
- The clipboard and shrink recipes take their install advice from the
  registry (no second copy of an install string anywhere in `lua/parley`).
- A test asserts the formula's dependency list (#247) equals the registry's
  advisory tier for macOS.
- No code path runs `brew`, `apt` or any package manager.

## Plan

- [ ] Registry as data with a decision-table test over tiers × detection
- [ ] checkhealth section derived from it (after #213's honesty work)
- [ ] Recipes (#231 clipboard, #244 shrink) read advice from the registry
- [ ] Formula-vs-registry parity test (lands with #247)

## Log

### 2026-09-13
