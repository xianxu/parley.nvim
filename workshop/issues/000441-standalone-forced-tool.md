---
id: 000441
status: open
deps: []
github_issue:
created: 2026-10-24
updated: 2026-10-24
estimate_hours:
card_mirror: 'bb113d58d2082c4ad5dd6e65300ce6309829f838' # card fields mirrored from issue-cards; edit via sdlc
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

- [ ]

## Log

2026-10-24: filed unclaimed at TL b532446a's direction. No implementation or live configuration changes made while diagnosing #419. Inside-Couch #419 acceptance passes; this upstream rejection is excluded from #419's landing contract by that same instruction.
