# AI coding agents (Claude Code, Codex) hang for ~5 minutes between API calls in sandbox

## Environment
- OpenShell CLI + sandbox: 0.0.16
- Base image: community `base` (Ubuntu 24.04)
- Claude Code: 2.1.92 (Node.js 22.22.1)
- OpenAI Codex: 0.117.0
- macOS host, same account — works fine

## Summary

Claude Code and OpenAI Codex interactive sessions experience a consistent ~290 second delay between every API round-trip when running inside an OpenShell sandbox. The agents make progress in ~5 second bursts separated by ~5 minute hangs, making them effectively unusable.

This does NOT happen when running the same agents on the host machine with the same account and prompts.

## Observed behavior

### Simplest repro: just "hello" twice

```
19:21:43  USER  "hello"
19:21:47  ASST  "Hello!"                          (4s — fast)
19:21:47  USER  "hello"
           ─── 292 second hang ─────────────────
19:26:43  ASST  "Hi!"                             (4s once unblocked)
19:26:43  USER  "hello again"
           ─── 297 second hang ─────────────────
19:31:44  ASST  "Hey!"                            (4s once unblocked)
```

### Larger session (tool use)

| API call | Request sent | Response | Gap before request |
|----------|-------------|----------|-------------------|
| 1st | 19:00:02 | 19:00:08 | 0s (startup) |
| 2nd | 19:04:57 | 19:05:04 | **288s** |
| 3rd | 19:09:58 | 19:10:02 | **292s** |
| 4th | 19:14:58 | 19:15:01 | **295s** |

Each API call itself completes in ~4-8 seconds. The entire delay is **before the request is sent** — the agent's process makes zero network calls for ~290 seconds between rounds.

## What the proxy logs show

At startup, Claude Code opens ~12 CONNECT tunnels in rapid succession for various purposes:
- API calls (`api.anthropic.com`)
- Telemetry (`/api/event_logging/v2/batch`)
- Plugin updates (`downloads.claude.ai`)
- Superpowers plugin git fetch (`github.com/.../git-upload-pack`)
- Update checks (`storage.googleapis.com`)
- Datadog logging (`http-intake.logs.us5.datadoghq.com` — denied by policy)

During the ~290s gaps, the proxy log shows **zero CONNECT or HTTP_REQUEST entries** from the agent's PID. The agent is idle — not blocked on the proxy, not waiting for a response. Something internal to the process is blocking.

One anomaly: during the first gap, an orphan CONNECT tunnel (port 44778) was opened 65s into the gap with **no corresponding HTTP_REQUEST**. This tunnel was established at the TCP level but no HTTP traffic was relayed through it.

## What we ruled out

| Hypothesis | Test | Result |
|-----------|------|--------|
| Proxy cold start | curl through proxy | 1.5s consistently |
| API server slowness | Proxy logs show no request sent during gap | Not server-side |
| HTTP/1.1 vs HTTP/2 | curl tests with both | Both fast |
| Large payload | `--print` with 60k system prompt | Fast (~12s) |
| Telemetry blocking | `DO_NOT_TRACK=1 no_proxy=datadoghq.com` | Still slow |
| Node.js EnvHttpProxyAgent | `NODE_USE_ENV_PROXY=` | Still slow |
| `--print` mode | Same prompt via `--print` with tool use | Fast (~14s) |
| `--print --resume` | Resume same session non-interactively | Fast (~12s) |
| Tool use | Bug repros with just "hello" twice | Not needed |

The issue only affects **long-lived interactive sessions**. `--print` mode (short-lived process, exits after response) is always fast. Piped input to interactive mode is also fast (process is short-lived).

## Reproduction

### Minimal (just "hello" twice)
1. `make sandbox` into an OpenShell sandbox with policy allowing `api.anthropic.com`
2. `claude --permission-mode bypassPermissions` (interactive mode)
3. Type `hello` — response arrives in ~4s
4. Type `hello` again — **hangs for ~290s**, then responds in ~4s
5. Every subsequent message repeats the ~290s hang

### Not affected
- `claude --print -p "hello"` (non-interactive) — always fast, even with `--resume`
- Same interactive session on host (outside sandbox) — always fast

## Impact

Both Claude Code and OpenAI Codex are unusable in interactive mode inside OpenShell sandboxes. This started within the last few days (possibly related to a base image update, though reverting the base image didn't fix it).

## Repo with full setup and debug artifacts

https://github.com/xianxu/parley.nvim, sha: df98ad791f9403608b0ca10dbaeba2b937650113

- `.openshell/` — sandbox setup scripts, policy.yaml, bootstrap
- `debug-slowness/` — test scripts, evidence logs, findings
- `issues/` - open issues being worked on

## Notes

- During Gap 1, one CONNECT tunnel (port 44778 at 19:01:13) was opened with no corresponding `HTTP_REQUEST` in the proxy log. This was the only network activity from the agent during the 288s gap
- Prior proxy relay issues that may be related: #260 (SSE response buffering), #641 (60s total timeout on streaming), #652 (WebSocket frames dropped after CONNECT)
