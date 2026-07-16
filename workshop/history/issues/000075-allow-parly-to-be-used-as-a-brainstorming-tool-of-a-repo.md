---
id: 000075
status: done
deps: []
created: 2026-04-05
updated: 2026-04-06
---

# allow parly to be used as a brainstorming tool of a repo

make this flow easier, we want:

1/ when current working directory is within a repo (let's say with parley enabled)
2/ add ./design/ as chat dir directly, and default writes to it. 

## Done when

- Repos with `.parley` marker file auto-detect as parley-enabled
- `design/`, `issues/`, `vision/`, `history/` dirs are auto-created in repo root
- `design/` becomes the primary chat dir, global chat dir demoted to extra

## Plan

- [x] Add config defaults: `repo_marker`, `repo_chat_dir`, `history_dir`
- [x] Add `apply_repo_local()` in `setup()` to detect marker and configure repo dirs
- [x] Make `issues.lua:get_history_dir()` use configurable `history_dir`
- [x] Run tests — all pass

## Log

### 2026-04-06
- Added `repo_marker = ".parley"` and `repo_chat_dir = "design"` to config defaults
- Added `history_dir = "history"` to config (was hardcoded in issues.lua)
- `apply_repo_local()` in init.lua setup: checks marker file, creates dirs, sets chat_dir
- Global chat_dir demoted to extra search dir when repo mode active
- All config values are user-overridable: marker file name, all directory names
- Tests: 43 pass, 0 fail

