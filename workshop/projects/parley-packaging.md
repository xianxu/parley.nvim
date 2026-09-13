---
type: project
name: "parley-packaging"
goal: "A non-Neovim user installs parley with one brew command and is chatting with Claude, Codex and Gemini through the managed cliproxy within minutes, without touching an existing Neovim config."
done_when: "On a clean macOS tart VM with no ~/.config/nvim, 'brew install xianxu/parley/parley' then 'parley' opens a new chat under NVIM_APPNAME=parley, ':ParleyProxy login' completes for one provider, a question with a pasted image is answered, and an existing ~/.config/nvim on the same VM is left byte-identical."
status: ideation
created: 2026-09-13
updated: 2026-09-13
---

# parley-packaging

## PRD

### Goal

A non-Neovim user installs parley with one brew command and is chatting with
Claude, Codex and Gemini through the managed cliproxy within minutes — parley
billed as a research-oriented, command-line chat app that works with every
LLM provider — without touching an existing Neovim configuration.

### Why now

#231 made images first-class and #244 will make them small; the chat product
is close to complete for the operator. What stands between it and a public
user is installation: the plugin assumes a working Neovim, a hand-written
config, API keys, and a shell. `parley-v1-release` removes the blockers inside
the plugin (fresh-clone install, safe defaults, neutral config, honest
checkhealth); this project builds the layer above it — dependencies,
a starter config, a tap and a launcher — so the whole thing is one command.

### Requirements

1. **One command.** `brew install xianxu/parley/parley` then `parley`.
2. **Isolated.** Runs under `NVIM_APPNAME=parley`; an existing
   `~/.config/nvim` is never read, written or merged.
3. **No keys typed.** cliproxyapi is parley-managed and `:ParleyProxy login`
   covers Claude, Codex and Gemini.
4. **Dependencies are honest.** One registry decides what is managed
   (cliproxyapi), what the platform provides (`osascript`, `sips`) and what is
   a one-line install (ripgrep, image tools); checkhealth and the formula
   derive from it; parley never runs a package manager.
5. **Proven on a clean machine.** The tart VM install is the acceptance test,
   not the operator's laptop.

### Acceptance boundary

macOS first (the clipboard and shrink recipes are platform recipes; `sips`
and `osascript` make macOS the zero-install platform). Linux packaging, a
Windows story, and auto-upgrading advisory tools are out. The starter config
is a product artifact but not a full editor distribution: it is what a chat
user needs, nothing more.

### Decisions (operator, 2026-09-13)

- cliproxyapi stays **managed** by parley because its configuration is complex.
- Every other tool is a **brew one-liner**, listed as advice and as a formula
  dependency; stable enough that a user not upgrading is not a problem.
- Clean-machine testing uses the **tart** VM already at hand.
- Images: `sips` first, other tools probed, original kept as the ultimate
  default (#244).

## Estimate

Not yet costed. Each issue derives `estimate_hours` after its plan clears
`change-code`'s plan-quality gate. Sequencing below is dependency order.

## Breakdown

Prerequisites owned by `parley-v1-release` (tracked there, listed for order):
#208 fresh-clone install, #209 safe-by-default posture, #211 neutral defaults,
#213 honest checkhealth. This project's own rows:

- [ ] **#244** — shrink pasted and generated images before saving *(sips first; probe others; keep the original)*
- [ ] **#245** — dependency registry and honest install advice *(after #213; feeds checkhealth and the formula)*
- [ ] **#246** — starter config as a product artifact *(after #211 and #209; `NVIM_APPNAME=parley`)*
- [ ] **#247** — Homebrew tap and `parley` launcher, tested on a clean tart VM *(after #245, #246; the project's done_when)*
- [ ] **#206** — user documentation *(v1-release's row; the brew path becomes its install section)*

## Log

### 2026-09-13 — opened

Opened from the operator's three-part prompt after #231 shipped: (1) image
size in git (write-once binaries are fine; size is the concern → #244), (2)
installing dependencies with the plugin (three tiers; parley manages only
cliproxyapi; never runs a package manager → #245), (3) `brew install
parley.nvim` for non-Neovim users (a tap, a launcher, `NVIM_APPNAME`
isolation so no existing config is touched → #246, #247).

The single design choice that makes (3) tractable is `NVIM_APPNAME`: the
first draft imagined detecting and merging the user's `~/.config/nvim`; an
app name gives a separate config and state root, so the installer never has
to. Risks recorded: macOS-only recipes at first; formulas must be tested on a
clean machine (tart), never the operator's; a second repo (the tap) must
track releases, so a tag→formula bump script is in #247's scope.

Sequenced after `parley-v1-release`'s blockers rather than duplicating them:
#245 needs #213's honest checkhealth, #246 needs #211's neutral defaults and
#209's posture, and #247 is the end state of both projects.
