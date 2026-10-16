---
id: 000363
status: open
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
card_mirror: 'ead941662e6dd2b6a31347521ef9056038327296' # card fields mirrored from issue-cards; edit via sdlc
---

# Cliproxy credential-restart lifecycle cases intermittently time out and probe the killed port

## Problem

First seen 2026-10-16 during #353's required suite on `aa8a3408fd3338402eb949a7c275335bd9c9966f`. `tests/integration/cliproxy_lifecycle_spec.lua` failed two credential-restart cases under parallel load; the other453 spec files passed, lint760 clean, no surviving test processes. The same lifecycle spec passed earlier full runs on the preceding #353 source/integrated heads. This module, test and await helper have no branch diff against main.

## Spec

Investigate lifecycle fixture/restart completion ordering without a blind deadline increase. The suite reported:

- line967, `credential_health restarts a keyless proxy once, then reads health from the new one`: await.lua:30 async call timed out.
- line986, `credential_health does not restart twice — a persistent 404 is reported, not looped`: repair probed the just-killed proxy's port; actual1, expected0.

Root cause is not yet established. Determine whether the first timed-out callback leaks into the next case and make the fixture signal actual restart/probe completion deterministically.

## Done when

- A deterministic regression reproduces the failing ordering and proves its root cause.
- The completion/teardown boundary is corrected, both cases pass, and the required suite passes without loosening assertions or blind timeout increases.

## Plan

## Log

- First seen:2026-10-16. Head:`aa8a3408fd3338402eb949a7c275335bd9c9966f`. Required command: `sdlc local-check run --name suite --rev aa8a3408fd3338402eb949a7c275335bd9c9966f`. Failed file duration85s. Full suite finished3m46s after1306s queue wait.
- Retained failed log:`/Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/1faa0580088008736845350a044e2a30.log`; SHA256:`433c84052df7d9a2abef784e9e0ba7b353e338ec0172f8112c66ea7dec0c42a5`. All remaining specs ran through make -k.
- Earlier passing integrated suite:`/Users/xianxu/workspace/parley.nvim/.git/sdlc/local-checks/5ac7cd3548c3cdc11ec5d0812e6c042e2352c9e6/suite.log` (454pass,760lint).
- Same-head focused replay: `/tmp/parley353-lifecycle-repro.log`, all63 cases pass, no surviving processes. No lifecycle source, fixture, assertions or timeouts were edited. This confirms intermittence; the root-cause investigation remains open.
