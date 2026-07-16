---
id: 000019
status: done
deps: []
created: 2026-03-29
updated: 2026-03-29
---

# claude in sandbox still prompts to overwrite file

for example, when it tries to overwrite .claude/settings.json, it still asks me. why?

## Done when

- [x] Claude in sandbox auto-approves all tool uses without prompting

## Plan

- [x] Root cause: repo-level `.claude/settings.json` (no permissions) overrides sandbox user-level config (blanket permissions)
- [x] Add `alias claude="claude --permission-mode bypassPermissions"` to sandbox zshrc, matching codex/gemini pattern

## Log

### 2026-03-29

Root cause: Claude Code config precedence. The repo-level `.claude/settings.json` takes priority over `~/.claude/settings.json`, so the sandbox's blanket permissions were ignored. No env var exists for permission mode, so added a shell alias in `.openshell/dotfiles/zshrc` — same pattern as `codex --full-auto` and `GEMINI_CLI_AUTO_APPROVE`. Requires sandbox rebuild to take effect.

