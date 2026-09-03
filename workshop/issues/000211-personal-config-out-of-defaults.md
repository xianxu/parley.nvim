---
id: 000211
status: open
deps: []
github_issue:
created: 2026-09-02
updated: 2026-09-02
estimate_hours:
---

# remove personal configuration from product defaults

## Problem

The author's personal environment ships as the product's defaults, and the
author's private working notes ship in the repository.

Defaults:

| Key | Value | Where |
|---|---|---|
| `chat_dir` / `notes_dir` | `~/Library/Mobile Documents/.../parley` and `.../notes` | `config.lua:259,265` |
| `export_html_dir` / `export_markdown_dir` | `~/blogs/static`, `~/blogs/posts` | `config.lua:273-274` |
| notes path | hardcoded **in code**, not config | `lualine.lua:138,184` |
| voice skill source | `~/.personal/<slug>-writing-style.md`, no config key | `skills/voice_apply/init.lua:8,44` |

The `_dir$` sweep at `init.lua:725-728` auto-creates these at setup, so every
fresh install silently creates `~/blogs/` and, on Linux, a literal
`~/Library/Mobile Documents/...` directory. The iCloud default also makes the
chat finder silently empty on Linux, and causes raw-mode logs — verbatim prompt
and response bodies — to sync to Apple's servers.

Repository contents: `.parley` and `.ariadne-mode` are git-tracked, along with
~370 files under `workshop/` — 338 archived issue records and **11 real chat
transcripts** in `workshop/parley/`, plus `pensive/` and `continuation/`.

## Spec

Ship defaults that are correct for a stranger on any supported platform, and stop
publishing private working material.

- Replace iCloud paths with a platform-appropriate default derived from
  `stdpath("data")`; `config.lua:258` already carries that alternative commented
  out. Users who want iCloud set it explicitly.
- Remove the hardcoded notes path from `lualine.lua` — a path in code that
  contradicts config is not a default, it is a bug (`ARCH-DRY`: one source for
  the notes root).
- Give export directories a neutral default, and do not create any directory at
  setup that the user has not used. Creating `~/blogs/` on install is
  unrequested filesystem writing (`ARCH-PURPOSE`).
- Give the voice skill a config key with a sane fallback, or move it out of the
  shipped skill root — see #213.
- Decide what of `workshop/` is public. Archived issue records arguably belong in
  a repo that documents its own process; 11 real chat transcripts and
  `pensive/` are private working material. Untrack what should not ship, and
  record the decision so it is not re-added.
- Audit for any remaining author-specific absolute path before close
  (`ARCH-PURPOSE`: the deliverable is the class, not the four instances named
  here — enumerate and sweep in the same round).

## Done when

- A fresh install on Linux and on macOS creates no directory outside the
  platform data dir, and the chat finder is functional on both.
- No absolute path containing `Library/Mobile Documents`, `~/blogs`, or
  `.personal` remains in `lua/`. Asserted by a test, so a future addition fails.
- The tracked file list contains no private chat transcript or thinking note, and
  the inclusion/exclusion rule is written down.
- Raw-mode logs land somewhere the user chose.

## Plan

- [ ] Replace iCloud and blog defaults; stop auto-creating unused directories.
- [ ] Remove the hardcoded path from `lualine.lua`; single-source the notes root.
- [ ] Enumerate and sweep every remaining author-specific absolute path; pin with a test.
- [ ] Decide and apply the `workshop/` publication boundary; untrack private material.

## Log

### 2026-09-02

Split out of the `workshop/plans/000206-shipping-surface-inventory.md` audit as blockers B6 and B7.
The two are one issue because they are the same mistake at two altitudes: the
author's environment leaking into what other people receive.
