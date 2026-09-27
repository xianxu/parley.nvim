---
id: 000238
status: open
created: 2026-09-12
updated: 2026-09-12
estimate_hours:
github_issue:
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
