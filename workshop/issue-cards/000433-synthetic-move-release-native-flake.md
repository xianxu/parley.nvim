---
id: 000433
status: open
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
github_issue:
---

# Synthetic move release native test intermittently fails its baseline assertion

## Problem

The native case session-sync native edits releases synthetic move protection only at the unchanged acquisition baseline intermittently fails its embedded assertion at session_sync_native_spec.lua:1415 (fixture Lua line11). This reproduced on pure main, independently of #418's parser-only code.
