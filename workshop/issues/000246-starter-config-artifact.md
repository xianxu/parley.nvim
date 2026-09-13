---
id: 000246
status: working
deps: [000211, 000209]
github_issue:
created: 2026-09-13
updated: 2026-09-13
estimate_hours:
started: 2026-09-13T14:26:23-07:00
---

# Starter config as a product artifact: NVIM_APPNAME=parley, lazy.nvim bootstrap, derived from the operator config without personal data

## Problem

The `parley-packaging` project needs a Neovim configuration a non-Neovim user
can start from: lazy.nvim bootstrap, the parley plugin spec, sensible
defaults for a chat-first editor. Today the only such config is the
operator's personal one (`~/.config/nvim`), which #211 is separating from
the product. This issue makes the starter config a **product artifact** in
this repo, derived from the operator's config with personal data removed.

## Spec

- Lives in the repo (`packaging/starter-config/`), versioned with the plugin,
  and is what #247's formula installs. It is loaded under
  **`NVIM_APPNAME=parley`** (`~/.config/parley/`, state under
  `~/.local/share/parley/`), so it never reads, writes or merges an existing
  `~/.config/nvim` — installation and removal are each one directory.
- Contents: lazy.nvim bootstrap pinned to a tag; the parley plugin spec
  pointing at the released plugin (not a dev path); the keymaps and options
  from the operator's config that a chat-first user needs (leader, clipboard,
  markdown conceal defaults that keep pasted image labels visible — see
  #231's alt-text decision), and nothing personal: no API keys, no iCloud or
  blog paths, no ariadne repo hooks, no note or vision directories (#211
  owns the product defaults this leans on; #209 owns the safe posture).
- First run: opens a new chat with a one-screen key hint (`<M-CR>` respond,
  `<M-v>` paste image, `<M-t>` outline, `:ParleyProxy login`); cliproxyapi is
  the default provider route so no API key is typed.
- A generated-from test: a script diffs the artifact against a denylist of
  personal markers (email, home-relative paths, ariadne names) and fails on a
  hit, so the artifact cannot silently regain personal data.

## Done when

- `NVIM_APPNAME=parley nvim -u <artifact>/init.lua` on a machine with no
  `~/.config/parley` boots, installs lazy.nvim and parley, and opens a chat.
- The same machine's `~/.config/nvim` is byte-identical before and after.
- The personal-marker test passes and is wired into `make test`.
- The README's install section points here for non-Neovim users.

## Plan

- [ ] Derive the artifact from the operator config; strip per the denylist
- [ ] Personal-marker test; pin lazy.nvim
- [ ] First-run hint and default provider route
- [ ] README section (with #206)

## Log

### 2026-09-13
