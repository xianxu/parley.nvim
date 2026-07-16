---
id: 000023
status: done
deps: []
created: 2026-03-29
updated: 2026-03-29
---

# git config not set in sandbox

when building the container, local git config settings should be automatically set into the sandbox

## Done when

- git user.name and user.email from host are set inside sandbox on first creation

## Plan

- [x] Add git config propagation to `.openshell/Makefile` sandbox startup

## Log

### 2026-03-29

- Added `git config --global` calls after container creation in Makefile
- Extracts host's `user.name` and `user.email`, sets them inside container
- Only runs on first creation (not attach/restart) since home volume persists
