# L7 proxy creates zombie CONNECT tunnels that never forward HTTP requests

## Environment
- OpenShell CLI: 0.0.16
- openshell-sandbox binary: 0.0.16
- Base image: Ubuntu 24.04 (community `base`)
- Node.js 22.22.1 (used by Claude Code and Codex)

## Description

CONNECT tunnels established through the L7 egress proxy intermittently become "zombies" — the tunnel shows as ESTABLISHED at the TCP level, but the HTTP request sent through it is never forwarded to the upstream server (no `HTTP_REQUEST` log entry appears). The client waits indefinitely until its own timeout fires.

This causes Claude Code and OpenAI Codex interactive sessions to experience ~300s delays on every API round-trip, making them effectively unusable inside OpenShell sandboxes.

## Reproduction

Claude Code opens ~10 CONNECT tunnels on startup (API, telemetry, plugin registry, MCP registry, etc.). One of these tunnels consistently becomes a zombie. The client awaits a response that never comes, blocking for its internal 300s timeout before retrying on a fresh connection.

### Proxy log evidence

Session startup opens multiple tunnels — all show `CONNECT ... action="allow"`:
```
18:45:06  CONNECT api.anthropic.com:443 (port 52412) → allow
18:45:07  CONNECT api.anthropic.com:443 (port 52416) → allow
18:45:07  CONNECT api.anthropic.com:443 (port 52424) → allow
18:45:07  CONNECT api.anthropic.com:443 (port 52426) → allow
18:45:07  CONNECT api.anthropic.com:443 (port 52436) → allow
18:45:07  CONNECT api.anthropic.com:443 (port 52448) → allow
18:45:07  CONNECT api.anthropic.com:443 (port 52428) → allow
18:45:07  CONNECT api.anthropic.com:443 (port 52452) → allow  ← zombie
```

Most tunnels produce `HTTP_REQUEST` entries. But port 52452 never does — the CONNECT succeeds but no HTTP traffic is relayed. `ss -tnp` shows the connection as ESTABLISHED with zero send/receive queues.

After the client's tool results are ready (18:45:23), there is **zero network activity** from the client PID for 285 seconds. The client is awaiting a response on the zombie tunnel. At 18:50:08, the client's 300s timeout fires, it opens fresh tunnels, and the request succeeds in ~5s.

This cycle repeats on every API round-trip.

### Minimal Node.js repro (partial)

The undici `EnvHttpProxyAgent` also exhibits a related issue — the 2nd request on a reused CONNECT tunnel hangs:

```javascript
// Run inside sandbox with HTTPS_PROXY set
const https = require("https");
async function req(label) {
    return new Promise((resolve) => {
        const r = https.request("https://api.anthropic.com/", {timeout: 30000}, (res) => {
            res.on("data", () => {});
            res.on("end", () => { console.log(label + ": " + res.statusCode + " in " + (Date.now()-start) + "ms"); resolve(); });
        });
        const start = Date.now();
        r.on("error", (e) => { console.log(label + ": ERROR " + e.message); resolve(); });
        r.on("timeout", () => { console.log(label + ": TIMEOUT " + (Date.now()-start) + "ms"); r.destroy(); resolve(); });
        r.end();
    });
}
(async () => { await req("req1"); await req("req2"); await req("req3"); })();
```

Output:
```
req1: 404 in 1644ms
req2: TIMEOUT in 30004ms    ← hangs on reused connection
req3: 404 in 1392ms         ← works on fresh connection
```

## Impact

Both Claude Code and OpenAI Codex are unusable in interactive mode — every API call takes ~5 minutes instead of ~5 seconds. `--print` (non-interactive, short-lived) mode is unaffected.

## Possibly related

- #260 — proxy buffered entire streaming response (fixed)
- #641 — 60s reqwest total timeout killed streaming (fixed)
- #652 — WebSocket frames dropped after CONNECT + 101 upgrade (fixed)

The zombie tunnel issue may share a root cause with these — the L7 relay's handling of concurrent/multiplexed requests through CONNECT tunnels.
