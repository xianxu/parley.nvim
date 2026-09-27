---
id: 000211
status: open
created: 2026-09-02
updated: 2026-09-11
estimate_hours:
github_issue:
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
| voice skill source | `~/.personal/<slug>-writing-style.md`, no config key | `skills/voice_apply/init.lua:7,48` |

The `_dir$` sweep at `init.lua:725-728` auto-creates these at setup, so every
fresh install silently creates `~/blogs/` and, on Linux, a literal
`~/Library/Mobile Documents/...` directory. The iCloud default also makes the
chat finder silently empty on Linux, and causes raw-mode logs — verbatim prompt
and response bodies — to sync to Apple's servers.

Repository contents: `.parley` and `.ariadne-mode` are git-tracked, along with
~370 files under `workshop/` — 338 archived issue records and **11 real chat
transcripts** in `workshop/parley/`, plus `pensive/` and `continuation/`.
