---
id: 000238
status: open
deps: []
github_issue:
created: 2026-09-12
updated: 2026-09-12
estimate_hours:
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

- [ ]

## Log

### 2026-09-12

### 2026-09-12 — filed from parley.nvim#237

Found when #237 put a real binary in front of the conformance spec for the first
time (M2 Task 13). The failures reproduce on 7.1.71 as well, so they predate the
upgrade. Details are in #237's Log and plan Revisions.
