---
id: 000278
status: done
deps: []
github_issue:
created: 2026-09-25
updated: 2026-09-26
estimate_hours:
started: 2026-09-25T23:34:16-07:00
flow: {kind: quick, provenance: inferred, spec: "f0dd18db", done: "4f4e3c8d"}
actual_hours: N/A
---

# Enable smart case search in the app

## Problem

The app should use smart case for default text search.

## Spec

Enable Neovim ignorecase and smartcase in the packaged starter (ARCH-DRY).
Lowercase searches ignore case; searches containing uppercase match case.

## Done when

- App searches use smart case; lowercase and mixed-case searches are verified.

## Plan

- [x] Set starter options, document behavior, and verify using Neovim search.

## Log

### 2026-09-25
- 2026-09-25: closed — Five native forward/backward searches through the production starter passed: lowercase matches every casing; uppercase matches exact case. All 19 real theme/statusline checks passed using temporary /tmp/parley-278-search.lua harness. Starter Lua lint, artifact check and scoped whitespace pass. User tutorial edits excluded. Actual telemetry reports no measurable activity; N/A avoids fabricated hours.; review verdict: SHIP

- Verified production starter via /tmp/parley-278-search.lua: five native forward/backward searches prove lowercase matches all cases and uppercase matches exact case; all 19 real theme/statusline checks pass.
- Two declarative options only; reused existing compatibility harness for a temporary behavioral smoke check. Starter lint/artifact and scoped whitespace checks pass.

## Manual shipment — 2026-09-26

Closed and archived at the operator’s explicit direction as part of the completed local stack. Prior SDLC review records remain historical; no new gate verdict is claimed.

Existing codecomplete review and acceptance evidence are retained; this shipment publishes the completed implementation.

Final verification: lint passed all 656 Lua files; `make test` passed 391 spec files, with the remaining performance spec passing all three cases on a standalone normal-harness rerun. Both runs ended with no surviving test processes. Startup also passed 183 cases in a tracked isolated checkout.
