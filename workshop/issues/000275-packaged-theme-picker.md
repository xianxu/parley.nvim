---
id: 000275
status: working
deps: []
github_issue:
created: 2026-09-25
updated: 2026-09-25
estimate_hours:
started: 2026-09-25T18:16:29-07:00
---

# Add a packaged Parley theme picker with live preview

## Problem

## Spec

Parley should expose `:ParleyTheme`, a compact floating picker that selects
among four packaged full Neovim colorschemes and restores the startup scheme.
The initial choices are Catppuccin Mocha (dark/colorful), Tokyo Night Storm
(dark/subdued), Catppuccin Latte (light/colorful), and Solarized Light
(light/subdued); Moonfly remains the packaged startup default. The picker
reuses the existing agent-picker/`float_picker` surface, supports cursor
navigation and mouse selection, and applies the highlighted candidate on every
selection change so the open chat and picker visibly preview the result.

The theme registry is the single source for ids, labels, colorscheme names,
contrast descriptions, and packaged dependency metadata (ARCH-DRY and
ARCH-PURPOSE). Applying a theme runs through one boundary that records the
active scheme, reapplies Parley's semantic highlight groups, and persists the
selected id under Parley's state directory. Opening the picker snapshots the
current scheme; Escape or cancellation restores that snapshot, while Enter or
mouse selection keeps and persists the current candidate. A malformed or
missing persisted id falls back to Moonfly without blocking startup
(ARCH-SECURE). Theme application is synchronous and bounded to the local
Neovim process; it creates no background work or durable artifacts beyond the
one state value (ARCH-CONSTRAINTS and ARCH-FUNERAL).

The packaged starter registers pinned theme plugins alongside Moonfly and
chooses the persisted theme before starting Parley. Normal plugin use can
invoke the same command and registry without the starter. Compatibility tests
load every packaged colorscheme, verify the expected `vim.g.colors_name`, and
verify Parley's question, thinking, annotation, picker, float, and statusline
groups remain defined after each switch. Picker tests cover preview on move,
commit on selection, cancellation restore, persistence, invalid state, and
keyboard/mouse entry through the production command.

## Done when

- `:ParleyTheme` opens the existing floating-picker style with the four packaged
  options plus startup-theme restore.
- Moving the cursor or selecting with the mouse applies the highlighted full
  colorscheme immediately to the surrounding Neovim UI and Parley buffer.
- Enter/mouse selection persists the theme; Escape/cancel restores the scheme
  active when the picker opened.
- A fresh packaged launch restores the saved selection and invalid state falls
  back safely to Moonfly.
- Every packaged option is tested with Parley's semantic highlight groups,
  syntax, float, and statusline surfaces.
- User documentation names the startup theme and `:ParleyTheme` command.

## Plan

- [ ] Add the pure theme registry and persistence/apply seam with unit coverage.
- [ ] Add packaged theme dependencies and startup restoration.
- [ ] Add the `:ParleyTheme` picker with live preview, commit, and cancel restore.
- [ ] Add compatibility/integration tests and user documentation.
- [ ] Run the focused suite and full required verification; log evidence.

## Log

### 2026-09-25

- Filed and claimed as #275. Approved design: full colorscheme switching with
  live preview in the existing floating picker; four packaged dark/light,
  colorful/subdued options; startup restoration and cancel rollback.
- ARCH decisions: one registry owns theme metadata (ARCH-DRY/PURPOSE), invalid
  persisted ids degrade to the default (ARCH-SECURE), local synchronous apply
  has a bounded lifecycle (ARCH-CONSTRAINTS/FUNERAL).
