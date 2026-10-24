---
id: 000441
status: working
deps: []
github_issue:
created: 2026-10-24
updated: 2026-10-24
estimate_hours:
card_mirror: '8dd91460720557bba3f55c4104849ab9403a8834' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-24T14:26:28-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "09c88959", done: "ad42cdfe"}
---

# Standalone review: forced tool choice rejected by claude-sonnet-5-5; expose upstream failure reason

## Problem

During parley.nvim#419's operator acceptance on 2026-10-24, standalone review in a plain-terminal Neovim failed twice (10:40:15 and 10:40:24), while inside-Couch review passed. The existing skill request forces a named tool, which claude-sonnet-5-5 rejects through CLIProxy API 8.0.12. This request construction is unchanged on main; TL b532446a classified it as a separate pre-existing defect.

Both upstream responses are HTTP 400, invalid_request_error, with the exact message:

`tool_choice: type "tool" and "any" are not supported for this model.`

The requests reached the local `/v1/messages` endpoint and upstream provider; the 142-byte rejection is not a missing credential or endpoint failure. The transport-error callback fires before the proposal/deferral validator. The operator saw `review: unchanged :messages` and `Parley.nvim: skill review transport error`, which hide the actionable upstream reason.

## Spec

Captured request shape (operator text and credentials omitted):

```json
{"model":"claude-sonnet-5-5","stream":true,"max_tokens":100000,"tool_choice":{"type":"tool","name":"propose_edits"}}
```

The request had no `thinking` member. Tools were web_search, web_fetch, read_file and propose_edits.

Fix direction approved by the TL: use tool_choice auto with the existing proposal validation, which already rejects a reply without a propose_edits call. Preserve exact classification coverage, protected source and existing write authority; a missing proposal must not become a successful no-op. The visible error caption/message should name the upstream reason rather than only saying transport error. Do not repair this by changing credentials or weakening proposal validation.

The raw request/response logs are local evidence (contain private request material; do not upload them):

- `/Users/xianxu/.cli-proxy-api/logs/error-v1-messages-2026-10-24T104015-9ed1164c.log`
- `/Users/xianxu/.cli-proxy-api/logs/error-v1-messages-2026-10-24T104024-2f63c66d.log`

Additional local evidence: `/Users/xianxu/.local/state/nvim/parley.nvim.log`, instance c832583d, both timestamps above; request JSON under `.cache/nvim/parley/query/2026-10-24.10-40-15.200.b5cd0a.json` and `2026-10-24.10-40-24.726.53337c.json`. The original screenshot is in ops/session.side/assets/2026-10-24-01-morning-combined-check/2026-10-24.10-40-59.784.png; keep this issue text-only.

Production seams: skill_invoke's payload tool-choice construction and on_error callback; tools/wire_anthropic.encode_tool_choice; review.run_via_invoke failure notices. Preserve provider-owned tool wire decisions.

## Done when

- Standalone review for the captured model/request uses an accepted automatic tool-choice form, with a recorded sanitized capture replayed through the normal suite and a real operator retry.
- A valid mixed question/command proposal applies only the command and leaves the question with the existing exact notice.
- Empty/no-proposal or malformed classifications still refuse before writes, backups or source reload.
- HTTP 400 and other transport failures expose the safe upstream reason to the operator without leaking credentials or request text.
- Both supported Neovim runtimes and relevant provider-wire/skill-invocation tests pass.

## Plan

- [x] Replay the sanitized captured 400 through the normal invocation seam, red first; pin automatic review payloads for Anthropic and OpenAI wires, retaining named forcing for other skills.
- [x] Replace review's named forcing with automatic choice, encoded by the existing provider-wire owner. Preserve the local proposal validator and all edit authority; no-proposal, malformed and missing classifications refuse before any write/backup/reload.
- [x] Format a bounded safe reason from the structured transport failure at the skill boundary; expose it in review's bounded caption and message history without dumping response/request envelopes, headers or credentials. Keep cancellation/stale-generation guards and notification bounds.
- [ ] Cover mixed command/question success, missing/invalid proposals, captured HTTP 400, other HTTP/transport failures and sensitive-envelope exclusion; run focused tests serially on both runtimes, then queued pre-close, close and hub-coordinated operator retry.


## Log

2026-10-24: filed unclaimed at TL b532446a's direction. No implementation or live configuration changes made while diagnosing #419. Inside-Couch #419 acceptance passes; this upstream rejection is excluded from #419's landing contract by that same instruction.

2026-10-24: Claimed and ran start-plan after verifying #428 landed and archived. Root cause confirmed in source: review manifest forces propose_edits, skill_invoke encodes that name in the selected wire and overwrites payload.tool_choice; its on_error retains the structured failure but replaces the visible message with the constant transport error. Existing proposal-count and collaboration validation already run before effects. ARCH-DRY: tool-choice shapes remain in the existing wire registry; ARCH-PURE: safe error formatting is a pure boundary helper, not a second transport/parser. No retry loop, durable state, concurrency or per-keystroke work is added. Alternatives rejected: model-specific forcing exceptions drift with model support; allowing missing proposals would weaken write authority. Actions remain submit/retry: success applies validated commands and defers questions; rejected/unknown transport completion leaves source unchanged with the reason and manual retry. No new persisted format or artifact family. Plan sent to hub before code.


2026-10-24: Implemented the approved auto choice through a validated optional manifest field, carried by disk provider and assembly; existing wires encode nil tool name as their own automatic form. Other named tools retain forcing. Zero proposals now return `no edit proposed`, including actual prose and empty streams, before read-only tools, backup or reload. Safe skill failure formatting only selects a bounded structured error.message, discards credential/request-bearing diagnostics and quoted arbitrary values, preserves enum names, and limits UTF-8 output to 240 bytes. Raw/malformed/partial/oversized envelopes and stderr never become a displayed reason. Both caption and :messages retain the reason; existing stale-generation/cancel guards remain.

Verification: initial red replay found forced-wire, no-proposal, masked transport and caption failures; new helper tests initially failed because the helper was absent. Fixed two fixture defects (inner JSON quote escaping and explicit CLIProxy route selection) and a caller fixture missing its transport envelope. Verified the sanitized error fields directly against the actual local 10:40:15 log, without printing or retaining request/header material. Final targeted run: 230/0/0 across 11 files; installed /opt/homebrew/bin/nvim repeats 230/0/0. Each run has a clean process census. JSON/arrival architecture controls: 4/0/0, clean census. Logs retained at /Volumes/TestScratch/parley441-j0dbwg8e/{red,focused-final,operator-runtime,arch}.log. Final lint and queued pre-close follow; operator retry awaits hub coordination. No stage touched.

## Revisions

2026-10-24 — Hub approved the plan and required explicit prose-only handling: automatic choice may produce no tool call, so zero proposals refuse visibly as `no edit proposed`, before any tool, backup or reload. More than one proposal remains a separate invalid-batch refusal.
