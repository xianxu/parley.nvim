---
id: 000108
status: done
deps: []
created: 2026-04-18
updated: 2026-06-29
started: 2026-06-29T12:35:51-07:00
estimate_hours: 1.5
actual_hours: 0.28
---

# create diagosis display for timezone string in local timezone

## Problem

detect string format like 2026-04-18T00:00:00Z, and convert it to local timezone, not in the buffer but display as a diagnosis.

## Done when

- [x] Strict UTC ISO timestamps like `2026-04-18T00:00:00Z` are detected in Parley chat and markdown buffers.
- [x] Parley shows the local-time conversion through a Parley-owned diagnostic namespace without changing buffer text.
- [x] Invalid calendar dates and non-UTC date-like strings are ignored.
- [x] Unit and integration tests cover conversion, matching, diagnostic placement, and refresh behavior.

## Spec

Parley should recognize strict UTC ISO-8601 timestamps in visible Parley-managed
buffers and surface the local-time equivalent as a diagnostic. The initial scope
is intentionally narrow: match full timestamps shaped like
`YYYY-MM-DDTHH:MM:SSZ`, where the trailing `Z` means UTC. Do not parse timezone
offsets, natural-language dates, dates without times, or timestamps embedded in
invalid calendar values.

The feature must not mutate buffer contents. It should publish diagnostics under
a Parley-specific namespace so users can use normal Neovim diagnostic UI and
navigation while keeping Parley separate from LSP diagnostics. Diagnostic ranges
should cover the timestamp token. The diagnostic message should stay concise for
virtual text: `local time: <converted local time>`.

Keep the timestamp parsing and conversion logic pure and independently tested
(`ARCH-PURE`). UTC-to-local conversion must not read ambient timezone state in
the pure builder; it takes an injected `to_local(epoch) -> table` dependency so
unit tests can use deterministic fake localizers. The Neovim boundary computes
the real local table with `os.date("*t", epoch)` and injects it.

The highlighter/buffer-handler integration should be a thin Neovim boundary that
reads buffer lines, calls the pure detector, and updates diagnostics for chat and
markdown buffers already registered by Parley. Diagnostics are event-driven and
must not be published from the decoration provider. Follow the existing
`skill_render.lua` pattern for stable namespace ownership, but use a separate
timestamp namespace so review-skill diagnostics and timestamp diagnostics do not
clear each other (`ARCH-DRY`). Refresh on `BufEnter`, `WinEnter`, `TextChanged`,
`TextChangedI`, and `BufWritePost`, mirroring the event-driven
`interview.highlight_timestamps` path rather than ephemeral redraw highlights.
The delivered behavior must satisfy the issue's actual purpose: local-time
diagnostics for UTC strings, not just syntax highlighting or buffer edits
(`ARCH-PURPOSE`).

## Estimate

```estimate
model: estimate-logic-v2
familiarity: 1.0
item: lua-neovim design=0.2 impl=0.8
item: atlas-docs design=0.05 impl=0.1
item: milestone-review design=0.0 impl=0.3
design-buffer: 0.30
total: 1.5
```

## Plan

- [x] Add pure failing tests for strict UTC timestamp detection and local-time formatting.
- [x] Implement the pure timestamp diagnostic builder.
- [x] Add integration tests for publishing/clearing diagnostics in chat and markdown buffers.
- [x] Wire timestamp diagnostics into the existing Parley buffer handler refresh path.
- [x] Update atlas documentation for the new diagnostic surface.
- [x] Run targeted tests, issue validation, `make test`, and `make lint`.

## Log

### 2026-04-18

### 2026-06-29
- 2026-06-29: closed — UTC ISO timestamps render local-time diagnostics in chat/markdown buffers; unit/integration/full tests and lint pass; review verdict: SHIP

Claimed and designed the issue. The implementation will use a pure timestamp
detector plus a thin Neovim diagnostic publisher in the existing highlighter
buffer-handler path. Plan-quality review found and fixed three design gaps:
inject the local-time conversion seam for deterministic pure tests, mirror the
existing `skill_render.lua` diagnostic namespace pattern with a separate
timestamp namespace, and refresh from autocmds rather than the redraw decoration
provider.

Implemented timezone diagnostics. Verification passed:
`tests/unit/timezone_diagnostics_spec.lua`, `tests/integration/highlighting_spec.lua`,
`make test-spec SPEC=ui/highlights`, `sdlc issue validate`, `make test`, and
`make lint`.

Follow-up display tweak: enabled virtual text for the timezone diagnostic
namespace and simplified the message to `local time: <converted local time>`.
