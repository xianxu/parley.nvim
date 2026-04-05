# Debugging ~293s API delay in OpenShell sandbox

## Symptom
Claude Code (and Codex) interactive sessions experience ~293s delay on every
API round-trip after the first call. First call is fast (~5s).

## What we know
- Proxy logs show requests leave immediately, responses take ~290s
- `--print` mode (non-interactive) is fast even with large payloads + tool use
- Interactive mode is slow — loads superpowers skills, project context, etc.
- Same account/tier from host is fast (100k+ token context, normal speed)
- OpenShell proxy does L7 inspection inside CONNECT tunnels (MitM via CA cert)
- Proxy forces HTTP/1.1; host uses HTTP/2 direct
- `datadoghq.com` telemetry blocked by policy (denied after each API call)
- OpenShell sandbox binary: 0.0.16, Node: 22.22.1

## Theories tested
1. HTTP/1.1 downgrade (proxy forces it) — DISPROVED by curl tests (fast)
2. Large payload — DISPROVED (--print with 60k system prompt is fast)
3. SSE streaming — DISPROVED (curl streaming is fast)
4. NODE_USE_ENV_PROXY / undici EnvHttpProxyAgent — DISPROVED (still slow with it disabled)
5. Node.js undici connection reuse — CONFIRMED in isolated test (test-09: req2 hangs)
   but Claude Code has its own proxy handling, so this may not be the direct cause
6. Piped vs manual interactive — piped tests always fast, manual always slow
   Piped sessions are short-lived; the bug requires a long-lived process

## Key finding from proxy logs
Claude Code waits ~67s AFTER tool results before even opening a new CONNECT
tunnel. Then the CONNECT tunnel never sends an HTTP_REQUEST (or it hangs).
This means something inside Claude Code is blocking the event loop for ~67s
before it can make the next API call. The blocked datadoghq.com telemetry
connection (denied by proxy policy) is the top suspect.

## What to test manually
In sandbox, start an interactive claude session with:
```bash
export DO_NOT_TRACK=1
export no_proxy="127.0.0.1,localhost,::1,http-intake.logs.us5.datadoghq.com"
export NO_PROXY="$no_proxy"
claude --permission-mode bypassPermissions
```
Then run: "read ARCH.md and say project name"
Compare speed to a normal session without these env vars.

## Test scripts
- `test-01-baseline.sh` — Single-turn --print (fast baseline)
- `test-02-tool-use.sh` — Multi-turn --print with tool use
- `test-03-large-context.sh` — Large system prompt via --print
- `test-04-interactive.sh` — Interactive session (the slow path)
- `test-05-no-telemetry.sh` — Interactive with DO_NOT_TRACK=1
- `test-06-no-plugins.sh` — Interactive with --disable-slash-commands
- `test-07-concurrent.sh` — Parallel API calls to test connection pooling
