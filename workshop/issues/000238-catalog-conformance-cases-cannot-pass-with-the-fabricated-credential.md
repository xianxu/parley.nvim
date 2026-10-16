---
id: 000238
status: working
deps: []
github_issue:
created: 2026-09-12
updated: 2026-10-16
estimate_hours:
card_mirror: 'f1f4ab71a86485dd8a76527610ecb0368e9fa83a' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T06:07:45-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "e23da354", done: "5c9fcb31"}
---

# Catalog conformance cases cannot pass with the fabricated credential

## Problem

`tests/integration/cliproxy_conformance_spec.lua` has two #205 cases that boot the
real cliproxyapi and read its model catalog:

- "serves /v1beta/models with the naming fields parse() joins on"
- "joins its two model routes onto each other for real"

Both fail on every build tried (7.1.71, 7.2.158, and the latest release the spec
downloads under `PARLEY_LIVE_GITHUB=1`): `/v1beta/models` comes back empty. The
spec boots the proxy with a fabricated, expired Claude credential, by design, so
that its startup refresh is a harmless 401, and the proxy registers no models
for a credential it cannot refresh. Until #237 no real binary was ever on the
harness's `PATH`, so these cases always ran `pending` and nobody saw that they
cannot pass. With a real login the catalog works: the operator's proxy on
7.2.159 lists 17 claude models.

## Spec

Make the catalog cases observe a catalog the real binary actually serves, without
pointing it at a live credential (the #197 hazard in the spec's safety note).
Options to weigh:

- a provider entry the proxy lists models for without a refresh (an API-key
  entry in the throwaway config);
- an opt-in mode that reads the operator's real catalog read-only, never
  sharing their auth-dir;
- narrowing the cases to what a fabricated credential can prove (the route
  shape, and the `models/` prefix on whatever the proxy returns).

## Done when

- The two cases pass against a real binary under `PARLEY_LIVE_GITHUB=1`, or are
  replaced by cases that can, with the reason recorded.
- No real credential is ever written to, or refreshed from, the throwaway
  auth-dir.

## Plan

Measured 2026-10-16. Real binary 8.0.4 (the operator's installed copy, run read-only against a throwaway config and auth-dir in the scratchpad), and the latest release, which the spec downloads under `PARLEY_LIVE_GITHUB=1`.
- Spec as-is: the two catalog cases fail and the other 10 real-binary cases pass. The bug reproduces.
- Throwaway config with no provider entry: `/v1/models` is `{"data":[]}` and `/v1beta/models` is `{"models":[]}`, exactly the reported failure.
- With a FABRICATED `claude-api-key` entry (`sk-ant-fabricated-conformance`), both routes list the proxy's static Claude catalog. `/v1beta` carries `name: "models/<id>"` and `displayName`, which is what `parse()` joins on. An API key is never refreshed, so no network call is made and no credential can rotate (the #197 hazard does not apply). A `gemini-api-key` behaves the same.

This is the Spec's first option. The catalog cases observe a catalog the real binary actually serves, with nothing real in the auth-dir.

- [x] `boot()` takes a `catalog` option that adds a fabricated `claude-api-key` entry; only the two catalog cases use it, so the other cases keep the config they pin.
- [x] The SAFETY note says why the API-key entry is safe, and that the key is fabricated.
- [x] Both catalog cases pass under `PARLEY_LIVE_GITHUB=1`; the whole spec is green.

## Log

### 2026-09-12

### 2026-09-12 — filed from parley.nvim#237

Found when #237 put a real binary in front of the conformance spec for the first
time (M2 Task 13). The failures reproduce on 7.1.71 as well, so they predate the
upgrade. Details are in #237's Log and plan Revisions.

### 2026-10-16 (parley.nvim:4)
- 2026-10-16: closed — Full suite green on c0854305 (sdlc-local/suite; the catalog cases are pending there, with no binary on PATH, as before); the commit after it is atlas only. Live: PARLEY_LIVE_GITHUB=1 against the latest release, cliproxy_conformance_spec 12 of 12 pass (before: 10, the two catalog cases fail). The catalog cases boot with a FABRICATED claude-api-key entry; measured on 8.0.4: the built-in Claude catalog on both routes (models/<id> plus displayName), the auth-dir stays empty, an API key never refreshes (no #197 rotation), and it works offline. The atlas cliproxy-managed.md conformance paragraph is updated.; review verdict: FIX-THEN-SHIP

- Built as planned. `PARLEY_LIVE_GITHUB=1` against the latest release: 12 of 12 pass (before: 10 pass, the two catalog cases fail).
- Credential safety, measured on the 8.0.4 binary with the API-key entry:
  - the throwaway auth-dir stays EMPTY (the proxy writes nothing there);
  - its auth auto-refresh has nothing to refresh, because an API key does not rotate;
  - the only network activity is the binary's own model-catalog refresh from raw.githubusercontent.com, no credential involved.
- No network dependency: with every proxy variable pointed at a dead port, the startup catalog refresh fails ("keeping current data"), and the proxy still serves its built-in catalog with `models/<id>` names and `displayName`. So the cases pass offline too.
- Without `PARLEY_LIVE_GITHUB` and no binary on PATH (the default harness), these cases stay `pending` with their reason, unchanged.
- Correction (close round 1): "the throwaway auth-dir stays EMPTY" above was measured on a scratch setup that had no OAuth file. The spec's `boot()` always writes the fabricated, expired OAuth credential into it. The accurate claim, now in the atlas: the proxy writes nothing to the auth-dir, and nothing real is ever in it.

