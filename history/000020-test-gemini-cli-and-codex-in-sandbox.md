---
id: 000020
status: done
deps: []
created: 2026-03-29
updated: 2026-03-29
---

# test gemini-cli and codex in sandbox

need to test that, and also integration with `make c`

## Done when

- All three CLI agents (gemini-cli, codex, claude) respond to a simple prompt inside sandbox
- `make c` runs successfully inside sandbox
- Any issues found are fixed or documented

## Plan

### Prerequisites
- [x] Login to codex and gemini, through either API_KEY or subscription login
- [x] Sandbox image built: `make sandbox-build`

### Test agents
- [x] Enter sandbox: `make sandbox`
- [x] gemini-cli: `which gemini && gemini --version && echo $GEMINI_CLI_AUTO_APPROVE`
- [x] gemini-cli prompt: `echo "say hello" | gemini`
- [x] codex: `which codex && codex --version && alias codex`
- [x] codex prompt: `codex "say hello"`
- [x] claude (baseline): `claude --version && claude -p "say hello"`

### Test `make c`
- [x] Run `scripts/parallel-checks.sh --audit` directly (bypasses threshold gate)
- [x] Or create enough diff to trigger `make c` threshold (400 lines / 10 files)

### Fix issues
- [x] Document and fix any failures

## Log

### 2026-03-29

