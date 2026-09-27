---
id: '000197'
status: done
started: 2026-08-01T00:24:22-07:00
created: 2026-08-01
updated: 2026-08-15
estimate_hours: 9.2
actual_hours: 11.17
---

# cliproxy auth failures must self-heal: detect, diagnose, recover

## Problem

On 2026-08-01 every cliproxyapi query failed and parley reported only:

```
Parley.nvim: cliproxyapi response is empty: body_bytes=215
parley: provider request failed (HTTP 503): {"type":"error","error":{"type":"api_error",
"message":"auth_unavailable: no auth available (providers=claude, model=claude-opus-4-8);
check Claude auth/key session and cooldown state via /v0/management/auth-files"}}
```

Parley has an auth-failure→guided-login path (#131 M3) and it did **not** fire.
Root causes, all verified against the live system:

1. **Detection is a single stale pattern.** `cliproxy_config.detect_auth_failure`
   (`cliproxy_config.lua:131`) matches only `"unknown provider for model <X>"`.
   The two messages 7.1.71 actually emitted — `auth_unavailable: no auth
   available (providers=…, model=…)` (503) and, on 2026-07-27, `OAuth access
   token has expired. Re-authenticate to continue.` (401) — match nothing.
   `check_auth_failure` ran (it sits at `dispatcher.lua:312`, four lines after
   the `response is empty` log that appeared) and no-op'd.
2. **The pre-flight health gate is blind to auth state.** `classify`
   (`cliproxy.lua:91`) calls 200 + non-empty `/v1/models` "healthy" and reserves
   `needs_login` for an *empty* list. Probed live with the credential dead:
   `/v1/models` still returned 31 models including the whole claude family. So
   `needs_login` is unreachable for expired auth and `ensure_running` greenlights
   every query. #131's recorded assumption ("the dynamic registry drops models at
   auth-error time") does not hold for this failure mode.
3. **No introspection channel.** The 503 names `/v0/management/auth-files`, but
   the rendered config carries no `remote-management.secret-key`, so that route
   404s. Parley cannot see expiry, cooldown, or failure counts.
4. **Root cause of the expiry itself: refresh-token rotation race.** Four
   leaked proxies from #131 verification (Jun 12–14, ports 8327/8331/8333/8335,
   configs long deleted) were still running against the shared default auth-dir.
   Each proxy runs `core auth auto-refresh (interval=15m0s)` and attempts a
   refresh at startup — verified in an isolated probe. Claude OAuth refresh
   tokens rotate on use, so N proxies over one auth-dir invalidate each other.
   The credential expired 2026-07-25T20:06 and never recovered.
   `cliproxy.stop()` (`cliproxy.lua:368`) reaps only this session's PIDs plus the
   managed port, which is how they survived seven weeks.
5. **The login flow dies silently.** `:ParleyProxy login claude` jobstarts into a
   terminal split (`init.lua:423`). Tonight that process exited mid-flow; its
   callback listener on `:54545` went with it, so the browser's redirect had
   nowhere to land and the account chooser appeared inert. Nothing reported the
   death.
