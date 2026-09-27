---
id: '000246'
status: done
started: 2026-09-13T14:26:23-07:00
created: 2026-09-13
updated: 2026-09-13
estimate_hours: 3.823
actual_hours: 1.18
---

# Starter config as a product artifact: NVIM_APPNAME=parley, lazy.nvim bootstrap, derived from the operator config without personal data

## Problem

The `parley-packaging` project needs a Neovim configuration a non-Neovim user
can start from: lazy.nvim bootstrap, the parley plugin spec, sensible
defaults for a chat-first editor. Today the only such config is the
operator's personal one (`~/.config/nvim`), which #211 is separating from
the product. This issue makes the starter config a **product artifact** in
this repo, derived from the operator's config with personal data removed.
