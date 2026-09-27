---
id: '000237'
status: done
started: 2026-09-11T12:35:20-07:00
created: 2026-09-11
updated: 2026-09-12
estimate_hours: 5.76
actual_hours: 7.20
---

# ParleyProxy update fetches the latest release unless pinned; status shows the version

## Problem

`:ParleyProxy update` does not update. It re-downloads the release pinned in
code: `M.update()` calls `M.download()` (`cliproxy.lua:1848-1851`), which picks
`opts.version or c.download_version or PINNED_VERSION` (`:1797`), and
`PINNED_VERSION = "7.1.71"` (`:1762`). The operator ran it expecting the newest
release and got 7.1.71 again.

A fixed pin now breaks on its own. cliproxyapi reaches Anthropic by presenting
itself as Claude Code, and Anthropic refuses models to Claude Code builds below a
minimum version. 7.1.71 presents `claude-cli/2.1.63`, so every Fable request
fails:

```
parley: provider request failed (HTTP 400): {"type":"error","error":{"type":"invalid_request_error","message":"Claude Code 2.1.63 does not support this model; version 2.1.251 or newer is required. ..."}}
```

CLIProxyAPI v7.2.149 moved to Claude Code 2.1.258. v7.2.158, the latest on
2026-09-11, carries `claude-cli/2.1.258 (external, cli)`, read from the release
binary.

Two smaller gaps:

- `update` only downloads. Parley reuses any proxy that answers healthy, so the
  old binary keeps serving until `:ParleyProxy restart`.
- `:ParleyProxy status` shows health, endpoint, binary and config drift
  (`config_drift`, `cliproxy.lua:808`), but not the version. A stale proxy is
  invisible until a model fails.
