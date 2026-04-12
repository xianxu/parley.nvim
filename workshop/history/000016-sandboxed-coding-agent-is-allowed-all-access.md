---
id: 000016
status: done
deps: []
created: 2026-03-29
updated: 2026-03-29
---

# sandboxed coding agent is allowed all access

allow agent to access whatever they want, install whatever they want. this is disabled by default upon cloning of repo, only set in sandbox.

## Done when

- [x] Claude Code has blanket permissions in sandbox (user-level `~/.claude/settings.json`)
- [x] Codex gets `--full-auto` via alias in sandbox zshrc
- [x] Gemini CLI gets `GEMINI_CLI_AUTO_APPROVE=true` env var in sandbox zshrc
- [x] No permissive settings leak to host or fresh clone

## Plan

- [x] Create `.openshell/dotfiles/claude/settings.json` with blanket permissions
- [x] Add `COPY` directive in Dockerfile for claude config
- [x] Add codex alias and gemini env var to `.openshell/dotfiles/zshrc`
- [x] Update issue and spec

## Log

### 2026-03-29

- Agent configs baked into Docker image under `/home/sandbox/`
- Named volume seeds from image on first run or after `sandbox-build`
- Claude Code: user-level settings.json with `Bash(*)`, `Read(*)`, etc.
- Codex: `--full-auto` alias in zshrc
- Gemini CLI: `GEMINI_CLI_AUTO_APPROVE=true` env var
- Amazon Q: skipped — no documented auto-approve mechanism yet
