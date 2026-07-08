---
id: 000163
status: open
deps: []
github_issue:
created: 2026-07-07
updated: 2026-07-07
estimate_hours:
---

# repo mode status bar improvements

Previously we simplified status bar when we are in repo mode. Though, it's
currently not very clear which repo we are in (the cwd). Let's display that
right beside the repo/super-repo symbol. I can't find the exact symbol, but
looks like ◉, and then we should display ◉-brain, for brain repo-ed cwd.

## Problem

In repo mode, the status bar indicates the mode but does not make the current
repo identity obvious enough. When working across repos, the user needs a compact
cwd/repo cue in the status bar itself.

## Spec

- Display the current repo name next to the repo/super-repo symbol in repo mode.
- Use the existing repo-mode symbol treatment and append the repo name compactly,
  e.g. `◉-brain` for the brain repo cwd.
- Keep the simplified status bar shape; this is a clarity tweak, not a new
  status area.

## Done when

- Repo mode status bar shows the current repo name beside the repo/super-repo
  symbol.
- The display is stable across at least the brain repo and a normal repo cwd.

## Plan

- [ ] Locate the repo-mode status bar renderer and its repo/super-repo symbol.
- [ ] Add the current repo name beside that symbol without disturbing the rest of
  the simplified status bar.
- [ ] Add or update focused tests for the repo-mode status bar output.

## Log

### 2026-07-07

- Moved from `pair#102` to `parley.nvim#163`; this belongs with the parley repo
  mode/status bar implementation.
