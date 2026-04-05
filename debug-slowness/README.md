# Debugging: ~290s hang in AI agents inside OpenShell sandbox

## Filed issues

- **OpenShell**: https://github.com/NVIDIA/OpenShell/issues/759
  - Filed copy: `issue-openshell-final.md`
- **Claude Code**: https://github.com/anthropics/claude-code/issues/43954
  - Filed copy: `issue-claude-code-final.md`

## Problem

Claude Code and OpenAI Codex interactive sessions hang for ~290 seconds
between every API round-trip inside OpenShell sandboxes. First message is
fast (~4s), every subsequent message hangs ~290s then responds in ~4s.

**Not affected**: `--print` mode, `--print --resume`, same session on host.

## Minimal repro

1. `make sandbox` → `claude --permission-mode bypassPermissions`
2. Type `hello` → fast response (~4s)
3. Type `hello` again → hangs ~290s → then responds (~4s)

## Root cause (unknown)

During the ~290s gaps, the proxy log shows zero network activity from the
Claude Code process. The process is sleeping, not blocked on I/O. Something
internal to the interactive mode event loop is blocking before the next API
call can be sent. `--print` mode does not have this blocking dependency.

## What we ruled out

| Hypothesis | Result |
|-----------|--------|
| Proxy cold start / latency | curl is 1.5s consistently |
| API server slowness | No request sent during gap |
| HTTP/1.1 vs HTTP/2 | Both fast via curl |
| Large payload / context | --print with 60k system prompt: fast |
| Telemetry blocking (datadoghq.com) | DO_NOT_TRACK=1: still slow |
| Node.js EnvHttpProxyAgent | NODE_USE_ENV_PROXY=: still slow |
| Tool use required | Repros with just "hello" twice |
| --print mode | Always fast, even --resume |

## Evidence

- `evidence-session-f44890db.md` — detailed proxy + JSONL log analysis

## Test scripts

Tests run inside sandbox (`/sandbox/repo/debug-slowness/`):

| Script | What it tests | Result |
|--------|--------------|--------|
| test-01 | --print baseline | Fast (8s) |
| test-02 | --print with tool use | Fast (15s) |
| test-03 | --print with 60k system prompt | Fast (12s) |
| test-04 | Interactive piped | Fast (14s) — piped doesn't repro |
| test-05 | Interactive + DO_NOT_TRACK | Fast piped / slow manual |
| test-06 | Interactive + no plugins | Fast piped / slow manual |
| test-07 | Concurrent --print calls | Fast |
| test-08 | curl idle connection reuse | Fast |
| test-09 | Node.js keepalive + reuse | **req2 TIMEOUT 30s** (undici bug, but not root cause) |
| test-10 | Node.js streaming + idle | N/A |
| test-11 | Interactive + all telemetry blocked | Fast piped / slow manual |
| test-12 | --print + --resume (hello→hello) | Fast (12s) |
