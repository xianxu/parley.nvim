---
id: '000189'
status: done
started: 2026-07-15T17:02:57-07:00
created: 2026-07-14
updated: 2026-07-16
estimate_hours: 16.6
actual_hours: 11.65
---

# all finders should have a spinner in case of large input

## Problem

Parley's five disk-backed finders—Chat, Note, Issue, Vision, and Markdown—scan
their roots before opening the picker. On a large root or in super-repo mode,
that synchronous work can leave Neovim apparently unresponsive with no visible
indication that discovery is in progress. Markdown Finder is the clearest case:
it repeatedly expands depth globs across every peer and can inspect ignored or
imported package trees that are outside the repository's useful document set.
