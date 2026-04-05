# Root Cause Analysis: ~300s delay in Claude Code inside OpenShell sandbox

## Symptom
Every API round-trip after the first takes ~290-295 seconds in interactive
Claude Code (and Codex) sessions inside OpenShell sandbox. First call is fast (~5s).

## Root Cause
Claude Code's process is **internally blocked for ~300s** between API calls.
During the gap, the process makes **zero network activity** — no CONNECT, no
HTTP requests, nothing. The proxy logs confirm this: there are no entries for
the Claude PID during the entire ~285s gap.

After ~300s, Claude Code resumes, opens a fresh CONNECT tunnel, and the API
call succeeds in ~5-7s. This matches the `timeout:300000` (300s = 5min) value
found in the Claude Code binary.

## Evidence

### Proxy log timeline (session 175ad6da)
```
18:45:08  POST /v1/messages?beta=true  (1st API call — fast)
18:45:19  POST /v1/messages?beta=true  (streaming response)
18:45:23  Tool results returned to Claude Code
          ... ZERO network activity from Claude PID for 285 seconds ...
18:50:08  CONNECT api.anthropic.com (fresh tunnel, 285s later)
18:50:08  POST /v1/messages?beta=true  (2nd API call — fast once sent)
```

### What we ruled out
| Theory | Result |
|--------|--------|
| Proxy cold start | Disproved — warm proxy is ~1.5s |
| HTTP/1.1 vs HTTP/2 | Disproved — curl through proxy is fast both ways |
| Large payload | Disproved — --print with 60k system prompt is fast |
| SSE streaming | Disproved — streaming curl is fast |
| NODE_USE_ENV_PROXY / undici bug | Partial — undici has a connection reuse bug (test-09) but Claude Code is blocked BEFORE reaching the proxy |
| Telemetry (datadoghq.com) blocking | Disproved — same delay with DO_NOT_TRACK=1 and no_proxy |
| Anthropic API server-side | Disproved — proxy shows no request sent during the gap |
| Piped vs interactive | Piped tests always fast; only manual interactive repros |

### What we confirmed
- Claude Code binary contains `timeout:300000` (300s)
- The process is sleeping (State: S) with idle connections during the gap
- Both Claude Code and Codex are affected (both use Node.js)
- `--print` mode is never affected (short-lived process)
- Only long-lived interactive sessions hit this

## Likely mechanism
1. During the first API call, Claude Code opens multiple CONNECT tunnels
   (for API, telemetry, plugin checks, update checks, etc.)
2. One of these connections silently fails through the proxy's L7 relay —
   the tunnel is ESTABLISHED but the response never arrives
3. Claude Code awaits this response with a 300s timeout
4. This await blocks the event loop, preventing the next API call
5. After 300s, the timeout fires, Claude Code recovers and proceeds
6. The cycle repeats on the next API call

## Potential fixes
1. **OpenShell proxy**: Fix L7 relay to not create zombie CONNECT tunnels
2. **Claude Code**: Don't block the main API call path on ancillary requests
   (telemetry, plugin checks, etc.) — fire-and-forget with short timeouts
3. **Claude Code**: Reduce the 300s timeout for non-critical operations
4. **Workaround**: None found so far — the issue is inside Claude Code's
   event loop, not configurable from outside

## Files to report
- OpenShell: NVIDIA/OpenShell — proxy creates zombie CONNECT tunnels
- Claude Code: Anthropic — internal 300s timeout blocks event loop in proxy environments
