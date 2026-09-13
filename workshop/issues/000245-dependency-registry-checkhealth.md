---
id: 000245
status: working
deps: []
github_issue:
created: 2026-09-13
updated: 2026-09-13
estimate_hours:
started: 2026-09-13T13:20:58-07:00
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

## Revisions

### 2026-09-13 — independent packaging dependency section; design pending approval

**Reason.** The operator confirmed project order #208 → #245 → #246 → #247.
The existing health entry point accepts a dependency section without #213's
credential/provider diagnostics or Copilot removal. Those remain v1-release work.

**Delta.** Removed the blocking dependency on #213. The original Plan row saying
“after #213” is superseded by the independent section designed in
`workshop/plans/000245-dependency-registry-plan.md`. Centralization includes the
existing pandoc install message and cliproxy advice; it does not expand into
#213's broad external-tool or credential audit. Discovery must not create folders.

**Approval pending.** #245's all-advisory formula parity conflicts with #247's
“ImageMagick only if needed beyond sips.” Recommend a registry-marked default
macOS package subset (ripgrep), with alternative converters and optional pandoc
remaining advisory. The operator must approve this delta before implementation;
until then the original all-advisory requirement has not been silently waived.
The formula parity test still lands with #247, against whichever policy is approved.

**Design checkpoint.** Claimed in isolated `/tmp/parley245-plan`, then ran
`sdlc start-plan --issue 245`. No runtime changes or estimate made. Read-only
code evidence: `cliproxy.managed_binary()` currently creates its directory;
clipboard missing-tool notices currently repeat, while shrink notices already
reset once per configure. The durable plan specifies tests for both findings.
