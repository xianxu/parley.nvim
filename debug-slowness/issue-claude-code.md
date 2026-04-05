# Interactive sessions block for ~300s per API call behind HTTP CONNECT proxies

## Environment
- Claude Code: 2.1.92
- OS: Ubuntu 24.04 (inside OpenShell sandbox)
- Node.js: 22.22.1
- Network: HTTP CONNECT proxy with L7 inspection (OpenShell 0.0.16)

## Description

In interactive Claude Code sessions running behind an HTTP CONNECT proxy, every API round-trip after the first takes ~290-300 seconds. The Claude Code process is **internally blocked** — it makes zero network calls during this time. After ~300s it recovers and the actual API call succeeds in ~5s.

`claude --print` (non-interactive) is unaffected. Only long-lived interactive sessions repro.

## Root cause analysis

On startup, Claude Code opens ~10 concurrent connections through the proxy:
- `/v1/messages?beta=true` (the main API call)
- `/api/event_logging/v2/batch` (telemetry)
- `/api/oauth/account/settings`
- `/api/claude_code_grove`
- `/api/claude_code_penguin_mode`
- `/api/claude_cli/bootstrap`
- `/v1/mcp_servers`
- `/mcp-registry/v0/servers`
- `storage.googleapis.com` (update check)
- `downloads.claude.ai` (plugin check)
- `github.com` (superpowers git fetch)
- `http-intake.logs.us5.datadoghq.com` (Datadog — blocked by proxy policy)

One of these connections becomes a zombie through the proxy — the TCP connection is ESTABLISHED but no response data flows. Claude Code appears to `await` this response **in the critical path** before making the next `/v1/messages` call. The `timeout:300000` (300s) in the binary matches the observed delay.

## Evidence

From proxy logs, between tool results arriving (18:45:23) and the next API request being sent (18:50:08), there is **zero network activity** from the Claude Code process — no CONNECT, no HTTP requests, nothing. The process is sleeping with idle connections.

```
18:45:23  Tool results ready (JSONL log)
          ... 285 seconds of silence — no network activity from Claude PID ...
18:50:08  CONNECT api.anthropic.com (new tunnel)
18:50:08  POST /v1/messages?beta=true (succeeds in ~5s)
```

## Expected behavior

Ancillary operations (telemetry, plugin checks, update checks, MCP registry) should not block the main API call path. If a connection fails or times out, it should not prevent the next `/v1/messages` request from being sent.

## Suggested fix

- Use short timeouts (5-10s) for non-critical ancillary requests
- Fire-and-forget pattern for telemetry — don't await in the API call path
- Don't serialize ancillary requests with the main API call
- Consider adding a `--no-telemetry` or `--no-update-check` flag for proxy/restricted environments

## Workaround attempts (none successful)

| Attempted | Result |
|-----------|--------|
| `DO_NOT_TRACK=1` | Datadog requests stop but delay persists — other connections still zombie |
| `NODE_USE_ENV_PROXY=` (empty) | Claude has own proxy handling, delay persists |
| `--disable-slash-commands` | Piped test was fast but manual interactive still slow |
| `no_proxy=datadoghq.com` | Same — not the blocking connection |

## Reproduction

1. Create an OpenShell sandbox with L7 proxy policy allowing `api.anthropic.com`
2. Run `claude --permission-mode bypassPermissions` interactively
3. Send any prompt that triggers tool use (e.g., "read ARCH.md and say project name")
4. Observe: first API call is fast (~5s), every subsequent call takes ~300s
5. Proxy logs show zero network activity from Claude during the gap
