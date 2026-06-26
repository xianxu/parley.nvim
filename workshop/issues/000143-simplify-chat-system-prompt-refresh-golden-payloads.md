---
id: 000143
status: done
deps: []
github_issue:
created: 2026-06-25
updated: 2026-06-25
estimate_hours: 0.25
started: 2026-06-25T21:32:15-07:00
actual_hours: 0.25
---

# simplify chat system prompt; refresh golden payloads

## Problem

The chat system prompt (`M.chat_system_prompt`, `lua/parley/defaults.lua`) was
simplified — the explicit `🧠:` thinking-block protocol (marker, `[END]`, the
reserved-marker note) was dropped. The 7 golden payloads embed the system prompt
verbatim, so they no longer match `build_payload`'s output and
`tests/unit/parley_harness_golden_spec.lua` fails 7/7 in the working tree.

## Spec

Land the simplified prompt and refresh the goldens to match. The golden test
round-trips `build_payload` (which pulls the prompt from the ToolSonnet agent →
`chat_system_prompt`) against `tests/fixtures/golden_payloads/*.json`. The two
land **together**: a golden-only change would fail on `main` against the still-old
committed prompt. Regenerated via the existing `scripts/refresh_goldens.lua` (same
`ToolSonnet` + `READONLY_TOOLS` as the spec). The only changed payload field is
`.system[0].text` (4029→3170 chars) — no parser/build/payload-chain drift.

(Decoupling the goldens from the personal prompt — pinning a fixed test prompt —
was considered and deferred; re-capture keeps the existing test semantics.)

## Done when

- `parley_harness_golden_spec` passes 7/7 with the committed prompt + goldens.
- The only golden delta is `.system[0].text`; all other payload fields unchanged.

## Plan

- [x] Simplify `chat_system_prompt` (drop the `🧠:` thinking-block protocol).
- [x] Refresh goldens via `scripts/refresh_goldens.lua`.
- [x] Verify `parley_harness_golden_spec` 7/7; confirm only `.system[0].text` changed.

## Revisions

### 2026-06-25 — boundary review (FIX-THEN-SHIP) addressed
- Scope: the prompt edit did slightly more than drop the `🧠:` protocol — it also
  added "Strive to understand the question behind my questions" and trimmed "as I
  may be merely commenting, not asking". The original framing/Log understated this.
- The `--no-atlas` waiver was incomplete. `atlas/chat/parsing.md` ("canonical mode
  for chats authored under the current prompt") and `atlas/chat/format.md`
  described `🧠:` as default-prompt behavior. Reworded both to scope `🧠:` parsing
  to custom/back-compat prompts — the shipped default no longer emits `🧠:` (`📝:`
  is kept); the parser still handles `🧠:` whenever present.

## Log

### 2026-06-25
- 2026-06-25: closed — parley_harness_golden_spec 7/7 green (committed prompt + refreshed goldens). Structural diff confirms the ONLY changed payload field is .system[0].text (4029→3170 chars) across all 7 fixtures — no parser/build/payload chain drift. Goldens regenerated via scripts/refresh_goldens.lua (same ToolSonnet + READONLY_TOOLS as the spec). --no-atlas: config prompt edit + regenerated test fixtures, no new architectural surface (the 🧠: marker feature is unchanged; only the default prompt instruction to emit it was dropped). Actual labeled — active-time found no window.; review verdict: FIX-THEN-SHIP
