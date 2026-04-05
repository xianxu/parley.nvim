# Interactive mode hangs ~290s between API calls behind HTTP CONNECT proxy

## Environment
- Claude Code: 2.1.92
- Node.js: 22.22.1
- OS: Ubuntu 24.04 (inside OpenShell sandbox, 0.0.16)
- Proxy: HTTP CONNECT with L7 inspection (`HTTPS_PROXY=http://10.200.0.1:3128`)
- macOS host, same account, same prompt — works fine

## Summary

Claude Code interactive sessions hang for ~290 seconds between every API round-trip when running behind an HTTP CONNECT proxy (OpenShell sandbox). The first message is fast (~4s). Every subsequent message hangs for ~290s before the API request is even sent, then completes in ~4s.

`--print` mode is unaffected — even `--print --resume` on the same session is fast.

## Minimal repro

```
$ claude --permission-mode bypassPermissions
> hello
Hello! How can I help you?          ← 4 seconds

> hello
                                    ← hangs 292 seconds
Hi! What can I help you with?       ← 4 seconds once unblocked

> hello again
                                    ← hangs 297 seconds
Hey! I'm here and ready to help.    ← 4 seconds once unblocked
```

Compare:
```
$ claude --print -p "hello"         ← 4 seconds, always fast
$ claude --print --resume $SID -p "hello again"  ← 12 seconds, fast
```

## What we observed

During the ~290s gaps, proxy logs show **zero network activity** from the Claude Code process — no CONNECT, no HTTP requests, nothing. The process is sleeping with idle TCP connections. The delay is entirely internal to Claude Code, not in the proxy or the API server.

At startup, Claude Code opens ~12 CONNECT tunnels for:
- `/v1/messages?beta=true` (API)
- `/api/event_logging/v2/batch` (telemetry)
- `/api/oauth/account/settings`
- `/api/claude_cli/bootstrap`
- `/v1/mcp_servers`, `/mcp-registry/v0/servers`
- `downloads.claude.ai` (plugin check)
- `storage.googleapis.com` (update check)
- `github.com` (superpowers git fetch)
- `http-intake.logs.us5.datadoghq.com` (Datadog — denied by proxy policy)

Something in this startup/background work blocks the main API call path for ~290s on each turn.

## Key evidence

### The gap is before the request, not after

```
Proxy log for Claude PID during the session:

19:00:02  POST /v1/messages?beta=true     ← 1st API call
19:00:08  response received               ← fast

          ... zero network activity for 288s ...

19:04:57  POST /v1/messages?beta=true     ← 2nd API call (fast once sent)
19:05:04  response received

          ... zero network activity for 292s ...

19:09:58  POST /v1/messages?beta=true     ← 3rd API call
```

### --print is fast, interactive is slow (same session)

`--print --resume` with the same session ID, same context, same model responds in 12s. Only the interactive event loop path is affected.

### Attempted mitigations (none worked)

| Attempted | Result |
|-----------|--------|
| `DO_NOT_TRACK=1` | Datadog connections stop, still slow |
| `no_proxy=datadoghq.com` | Same — not the blocking connection |
| `NODE_USE_ENV_PROXY=` (disable undici experimental proxy) | Still slow |
| `--disable-slash-commands` | Still slow in interactive mode |

## Hypothesis

The interactive mode event loop has a blocking `await` on a background operation (telemetry flush, plugin check, update check, or a connection that silently fails through the proxy) with a long timeout. This blocks the next `/v1/messages` call from being sent. `--print` mode either doesn't perform these operations or doesn't await them in the critical path.

## Related

Filed as OpenShell issue: https://github.com/NVIDIA/OpenShell/issues/759

Full debug artifacts: https://github.com/xianxu/parley.nvim/tree/main/debug-slowness (sha: df98ad791f9403608b0ca10dbaeba2b937650113)
