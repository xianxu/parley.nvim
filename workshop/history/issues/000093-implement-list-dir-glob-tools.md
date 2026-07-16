---
id: 000093
status: done
deps: [000090]
created: 2026-04-10
---

# Implement list_dir and glob client-side tools

## Summary

Claude's tool-use agents currently waste rounds calling `list_dir` and `glob` which are registered as stubs (`not yet implemented`). Implementing them will reduce tool call chains significantly — Claude won't need to fall back to server-side `bash_code_execution` for directory listing.

## Context

Discovered during #90 manual testing: Claude called read_file → list_dir (error) → glob (error) → bash_code_execution (server-side, slow) just to explore a directory. With working list_dir and glob, it would be read_file → list_dir → done.

## Plan

_TBD_

## Log

- **2026-04-10 — filed** from #90 follow-up.
