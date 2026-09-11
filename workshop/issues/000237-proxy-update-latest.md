---
id: 000237
status: working
deps: []
github_issue:
created: 2026-09-11
updated: 2026-09-11
estimate_hours:
started: 2026-09-11T12:35:20-07:00
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

## Spec

Update:

- `:ParleyProxy update` installs `cliproxy.download_version` when it is set,
  exactly as today; that is the pin. Otherwise it installs the latest release.
- Resolve "latest" from the `releases/latest` redirect
  (`https://github.com/router-for-me/CLIProxyAPI/releases/latest` →
  `…/tag/vX.Y.Z`), which needs no API token or quota.
- Keep the existing checksum verification against that release's
  `checksums.txt`. `cliproxy_config.asset_name` already builds the 7.2.x asset
  name (`darwin_aarch64`).
- Report the outcome with versions: "updated 7.1.71 → 7.2.158", "already at
  7.2.158", or "pinned to 7.1.71 by cliproxy.download_version".
- Restart a running proxy that parley started, so the new binary is the one
  serving. Leave a proxy parley did not start alone, and say that it needs a
  restart.
- If GitHub is unreachable, fail with a clear message and leave the installed
  binary untouched.
- Decide at plan time what first-run `auto_download` installs: the built-in pin
  (reproducible, but it goes stale) or latest. Either way, `PINNED_VERSION` and
  its "reproducible" comment must say what they now mean.

Status:

- `:ParleyProxy status` shows the running proxy's version, read from its
  `X-CPA-VERSION` response header. That covers every binary source (managed
  download, `binary_path`, brew on PATH).
- Show the latest available version too, and flag when the running one is
  behind. Sources: the binary's `latest-version` management route (the
  management key lives in the managed dir), or the same redirect `update` uses.
- When the proxy is not running, say so rather than print a guessed version.
- `X-CPA-VERSION` and `latest-version` appear in both the 7.1.71 and 7.2.158
  binaries' strings; confirm their exact shapes against a live proxy at plan
  time.

This is an external-service feature, so it ships a stateful fake of the release
endpoint (latest redirect, assets, checksums) behind the same seam the download
uses, plus one live check.

## Done when

- With no `download_version`, `:ParleyProxy update` installs the latest release
  and reports old → new; with it set, it installs exactly that version and says
  it is pinned.
- After `update`, the proxy serving requests is the new binary, confirmed by
  `:ParleyProxy status`.
- `:ParleyProxy status` shows the running version and whether a newer one exists.
- `update` with GitHub unreachable fails clearly and changes nothing, tested with
  the fake.
- Live: after `update`, a Fable chat through cliproxyapi succeeds.
- `atlas/providers/cliproxy-managed.md:374-380` and the `update` description in
  `init.lua`'s `:ParleyProxy` subcommand table no longer say it fetches the pin.
- `make test` passes.

## Plan

- [ ] Resolve the target version (config pin, else latest via the redirect), with a fake release endpoint and tests.
- [ ] Download, verify and install it; restart a parley-started proxy; report old → new.
- [ ] Decide what first-run `auto_download` installs; update `PINNED_VERSION` and its comment.
- [ ] Show the running version (`X-CPA-VERSION`) and the latest in `:ParleyProxy status`.
- [ ] Update the subcommand description and atlas, check README, and live-check a Fable chat.

## Log

### 2026-09-11

Filed after Fable failed through cliproxyapi with the HTTP 400 above. The
operator had run `:ParleyProxy update` expecting the newest release; it
re-fetched the pin. Confirmed from the binaries: the installed 7.1.71 carries
`claude-cli/2.1.63`, the v7.2.158 release carries `claude-cli/2.1.258`. Until
this lands, the workaround is `cliproxy = { download_version = "7.2.158" }`,
then `:ParleyProxy update` and `:ParleyProxy restart`.

Once Fable 5.1 works through the proxy, review and voice_apply force a tool call
and will hit Fable 5.1's 400 on forced `tool_choice` (recorded in #216's "Not
fixed here").
