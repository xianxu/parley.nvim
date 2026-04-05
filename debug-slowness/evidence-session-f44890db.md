# Evidence: Session f44890db (clean repro)

## Setup
- OpenShell 0.0.16, base image community `base`
- Claude Code 2.1.92, Node.js 22.22.1
- Default sandbox environment (no workarounds applied)
- Prompt: "work on issue 65, plan has been laid out, start with subtickets"

## Session timeline (from JSONL log)

```
19:00:01  USER    "work on issue 65..."
19:00:08  ASST    "Let me read the issue file..." (+7s)
19:00:08  ASST    tool:Read (issues/65.md — file not found)
19:00:08  USER    tool result returned
19:00:08  ASST    tool:Read (tasks/lessons.md)
19:00:08  USER    tool result returned
          ─── 288 second gap ───────────────────────────
19:04:56  SYS     (system reminder)
19:05:04  ASST    tool:Glob, tool:Bash (+8s after system)
19:05:04  USER    tool results returned
          ─── 292 second gap ───────────────────────────
19:09:56  SYS     (system reminder)
19:10:02  ASST    tool:Read (issue 65) (+6s after system)
19:10:02  USER    tool result returned
          ─── 295 second gap ───────────────────────────
19:14:57  SYS     (system reminder)
19:15:01  ASST    "Let me read the sub-tickets..." (+4.6s after system)
19:15:03  ASST    tool:Read (4 files)
19:15:05  USER    tool results returned
```

Pattern: every API round-trip after the first takes ~290s. Within each round-trip,
tool execution is instant and the API response arrives in ~5-8s once the request
is actually sent. The delay is BEFORE the request is sent.

## Proxy log (CONNECT + HTTP_REQUEST for Claude PID 19893)

### Startup (18:59:56 - 19:00:20)
```
18:59:56  CONNECT api.anthropic.com port=47216
18:59:56  CONNECT api.anthropic.com port=47232
18:59:56  CONNECT api.anthropic.com port=47242
18:59:57  CONNECT api.anthropic.com port=47250
18:59:57  CONNECT api.anthropic.com port=47266
18:59:58  CONNECT api.anthropic.com port=47274
18:59:58  CONNECT api.anthropic.com port=47284
18:59:58  CONNECT api.anthropic.com port=47290
18:59:58  CONNECT storage.googleapis.com port=47300
19:00:01  CONNECT api.anthropic.com port=47310
19:00:01  CONNECT downloads.claude.ai port=47326
19:00:07  CONNECT api.anthropic.com port=51504
19:00:11  CONNECT datadoghq.com port=51518 → DENIED
19:00:20  CONNECT api.anthropic.com port=33778
```

HTTP_REQUEST entries during startup:
```
19:00:02  POST /v1/messages?beta=true        ← 1st API call (fast)
19:00:02  GET  downloads.claude.ai/...plugins...
19:00:07  POST /api/event_logging/v2/batch
19:00:20  POST /api/event_logging/v2/batch
19:00:30  POST github.com/.../git-upload-pack  ← superpowers fetch
19:01:02  POST github.com/.../git-upload-pack
19:01:14  POST /api/event_logging/v2/batch
```

### Gap 1: 19:00:08 → 19:04:56 (288s)
**Zero CONNECT or HTTP_REQUEST from Claude PID during this period.**
The only activity is:
```
19:01:13  CONNECT api.anthropic.com port=44778   ← opened but NO HTTP_REQUEST
```
Then nothing until:
```
19:04:56  CONNECT api.anthropic.com port=37528   ← fresh tunnel
19:04:57  POST /v1/messages?beta=true            ← 2nd API call (fast once sent)
```

### Gap 2: 19:05:04 → 19:09:56 (292s)
**Zero activity from Claude PID.** Then:
```
19:09:57  CONNECT api.anthropic.com
19:09:58  POST /v1/messages?beta=true            ← 3rd API call
```

### Gap 3: 19:10:02 → 19:14:57 (295s)
Same pattern. Then:
```
19:14:58  CONNECT + POST /v1/messages?beta=true  ← 4th API call
```

## Key observation

During Gap 1, there is ONE orphan CONNECT (port 44778 at 19:01:13) that
has no corresponding HTTP_REQUEST. This tunnel was opened 65s after the
tool results were returned. It's unclear if Claude Code attempted to send
a request through this tunnel that the proxy failed to relay, or if this
is an unrelated connection.

The critical fact: Claude Code's process makes ZERO network calls for
~288 seconds between each API round-trip. The delay is internal to the
process, not in the proxy or the API server.

## Comparison with host

Same account, same prompt, same model (claude-opus-4-6), running on macOS
host (outside sandbox, direct internet). API calls with 100k+ token context
complete in normal time (~10-30s). No 290s gaps.
