---
id: 000237
status: working
deps: []
github_issue:
created: 2026-09-11
updated: 2026-09-11
estimate_hours: 5.76
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

Detailed design and tasks: `workshop/plans/000237-proxy-update-latest-plan.md`.

Update:

- `:ParleyProxy update` installs `cliproxy.download_version` when it is set;
  that is the pin. Otherwise it installs the latest release.
- First-run `auto_download` follows the same rule. The built-in
  `PINNED_VERSION` is deleted: a pin in code is what locked users out, and a
  silent fallback to it would bring the stale version back.
- Resolve "latest" from the `releases/latest` redirect
  (`https://github.com/router-for-me/CLIProxyAPI/releases/latest` →
  `…/tag/vX.Y.Z`), which needs no API token or quota. If it cannot be resolved,
  fail and suggest `download_version`.
- Keep the checksum verification against that release's `checksums.txt`.
  Install atomically: extract into a staging dir, rename over the binary, then
  record the version beside it. A running proxy keeps its old file, and an
  interrupted update leaves the previous binary.
- Report the outcome with versions: "updated 7.1.71 → 7.2.158", "already at
  7.2.158", or "… (pinned by cliproxy.download_version)".
- Restart the proxy when parley launched it: its command line carries parley's
  rendered `-config`, from this nvim session or an earlier one. Restart through
  `restart_managed`, which waits for the old process to release the port. A
  proxy parley did not launch (a brew service, say) is left running, and the
  message says it still runs the old version and how to replace it.
- `:ParleyProxy restart` also goes through `restart_managed`; the no-wait
  `M.restart` is deleted.
- Refuse, with the reason, when `cliproxy.manage` is off, when `binary_path` is
  set, or when `download_version` is not a version.
- If GitHub is unreachable, fail with a clear message and leave the installed
  binary untouched.

Status:

- `:ParleyProxy status` shows the running proxy's version, read from the
  `X-Cpa-Version` header every `/v0/management/*` response carries — including
  the 401 an unauthenticated request gets, so no credential is sent (verified
  live on 7.1.71).
- Show the latest release from the same redirect `update` uses, and say when the
  running version is behind. When the proxy is not running, say so, with the
  installed version if parley recorded one, rather than a guess.
- Report a managed-dir binary as `managed`, not `PATH`.
- When `cliproxy.manage` is off, status does not check GitHub: an opted-out
  install makes no request on parley's behalf.

This is an external-service feature, so it ships a stateful fake of the release
endpoints (latest redirect, assets, checksums, request log) behind the same URL
seam the production code uses, plus live checks: the real binary's header in the
conformance spec, and the real redirect behind `PARLEY_LIVE_GITHUB=1`.

## Done when

- With no `download_version`, `:ParleyProxy update` installs the latest release
  and reports old → new; with it set, it installs exactly that version and says
  it is pinned.
- First-run `auto_download` installs the same target.
- After `update`, the proxy serving requests is the new binary, confirmed by
  `:ParleyProxy status`; a proxy parley did not launch is left running.
- An update that fails at any step (GitHub unreachable, bad checksum) leaves the
  installed binary and its version record unchanged, tested with the fake.
- `:ParleyProxy status` shows the running version and whether a newer one exists.
- Live: after `update`, a Fable chat through cliproxyapi succeeds.
- `atlas/providers/cliproxy-managed.md` and the `:ParleyProxy` help no longer say
  update fetches a pin.
- `make test` passes.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=1.0 impl=0.08
item: lua-neovim design=0.2 impl=0.4
item: lua-neovim design=0.2 impl=0.6
item: lua-neovim design=0.2 impl=0.3
item: api-integration design=0.2 impl=0.6
item: real-api-discovery design=0.0 impl=0.18
item: real-api-discovery design=0.0 impl=0.18
item: atlas-docs design=0.1 impl=0.05
item: atlas-docs design=0.1 impl=0.05
item: milestone-review design=0.1 impl=0.14
item: milestone-review design=0.1 impl=0.14
item: milestone-review design=0.1 impl=0.14
item: milestone-review design=0.1 impl=0.14
design-buffer: 0.15
total: 5.76
```

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only.* `sdlc estimate-source` flags that doc as
stale (the calibration ledger is newer, #127), so the per-primitive hours are
provisional.

How each item was picked, from the v2 table's ranges: design ×0.2 where the plan
already resolves the decisions (v2 Step 3), and `impl=` at 40% of the v2/v2.1
range (v3.1).

- `issue-spec` — the spec and plan were written after the claim (12:35), inside
  the measured window, with two plan-gate rounds: the middle of 0.5–1.5 design,
  undiscounted, because this item is the design work itself.
- `lua-neovim` ×3 — the pure `cliproxy_release` module with `parse_ps`; the
  update IO (resolve, atomic install, update and restart with its deadline,
  first-run, command glue), the largest piece, at the top of v2's 0.5–1.5
  impl; and the status version, the smallest. Design at the ×0.2 floor: the
  plan carries every task's code.
- `api-integration` — the stateful release fake, its helper, the watchdog,
  `fake_cliproxy`'s stamp, and the integration specs built on them. Design at
  the floor; impl at the top of the range, because async fixture ownership is
  where this module's time goes (#205 ran 3× over; PQ-1 and PQ-5 were both in
  that family).
- `real-api-discovery` ×2 — two external surfaces: GitHub's redirect, and the
  real binary's header (the management-disabled case may flip the fake), plus
  the live Fable check.
- `atlas-docs` ×2 — the M1 and M2 doc passes.
- `milestone-review` ×4 — M1, M2, and two rework rounds; recent parley issues on
  this module needed four or five gate rounds (#205, #214, #225).
- Step 2.5 (library check) does not apply: no new stack. Familiarity 1.0: the
  cliproxy module, its fakes and its conformance spec are recent, familiar code
  (#131, #197, #205).

Revised 2026-09-11 after the estimate-quality review (INFO): design moved to the
floor where the plan already holds the code, and the hours it freed moved to
integration-spec debugging, a second rework round and a second external
surface — 5.70 → 5.76.

## Plan

- [ ] M1 — `:ParleyProxy update` installs `download_version`, else the latest release, atomically, and restarts parley's own proxy; first-run auto_download follows the same rule; `:ParleyProxy restart` waits for the port (plan Tasks 1–10; Task 10's pure `version_summary` lands here).
- [ ] M2 — `:ParleyProxy status` shows the running version against the latest; conformance and live checks; docs; live Fable check (plan Tasks 11–13).

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

### 2026-09-11 — plan approved

The operator approved `workshop/plans/000237-proxy-update-latest-plan.md`, and
accepted that `download()` stays synchronous: `:ParleyProxy update` blocks the
editor while it fetches, bounded by curl's timeouts.

### 2026-09-12 — M1 implemented

Plan Tasks 1–8, plus Task 10's pure `version_summary`, are in. Verified one spec
at a time in the harness's isolation, unsandboxed so the identity cases run: all
14 cliproxy specs pass (update 26/0/0, none pending), both plan-symbol arch
checks pass, lint 0/0; an orphaned fixture exits within 1 s under the watchdog.

Two findings that belong to other issues:

- The agent sandbox refuses `ps` (EPERM). Production degrades to "not ours";
  the three identity cases report `pending` there instead of failing.
- `cliproxy_catalog_spec` orphans three `fake_cliproxy` per run: bare
  `uv.spawn(FAKE, { args = { "--port", … } })` at lines 19, 360 and 441, without
  the watchdog flag. A concrete source for #220.

## Revisions

### 2026-09-11 — planned: two milestones, auto_download settled, two defects added

**Reason.** Planning settled the question the Spec left open and found two
defects on the same path.

**Delta.**

- First-run `auto_download` installs the same target as `update`; the built-in
  `PINNED_VERSION` is deleted rather than kept as a fallback.
- "Parley's proxy" means launched with parley's rendered `-config`, not "spawned
  in this session": a proxy from an earlier nvim session is still parley's, and
  a script-based test fake cannot match an executable path.
- Added: atomic install (staging, rename, version record), because the old
  `tar -xzf` wrote over the live binary in place.
- Added: `:ParleyProxy restart` through `restart_managed`. The no-wait
  `M.restart` could reuse a proxy still shutting down, and the workaround in the
  Log tells the user to run exactly that command.
- Status gets "latest" from the same redirect as `update`, not from the proxy's
  `latest-version` management route, which needs the key and answers 401 on a
  proxy parley did not launch.
- Done when: added the first-run and failure-leaves-it-unchanged criteria.
- Plan rows regrouped into M1 (update) and M2 (status).

### 2026-09-11 — plan-quality round 1

The change-code gate refused on a fixture-process leak (PQ-1) and noted three
Minor findings; all four are fixed in the plan, whose Revisions has the detail.
The one Spec-level change: status no longer checks GitHub when
`cliproxy.manage` is off.

### 2026-09-12 — Task 10 moves into M1

The plan-symbol arch check requires every symbol a plan table names to be
defined, so M2's pure `version_summary` would have turned M1's boundary red. It
is small and pure, so it lands in M1; M2 keeps the status wiring. The plan's
Revisions has the table-naming detail.
