---
id: 000441
status: codecomplete
deps: []
github_issue:
created: 2026-10-24
updated: 2026-10-24
estimate_hours:
card_mirror: 'ff84175497ebcedae600fedd3862061ea9e48211' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-24T14:26:28-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "09c88959", done: "ad42cdfe"}
actual_hours: 1.24
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
- [x] Cover mixed command/question success, missing/invalid proposals, captured HTTP 400, other HTTP/transport failures and sensitive-envelope exclusion; run focused tests serially on both runtimes, then queued pre-close, close and hub-coordinated operator retry.


## Log


- 2026-10-24: closed — Operator PASS delivered by hub: yes, works outside Couch on staged fc955fb249525287f25da4a472f23f6711ced846; command applied, question kept (BR-2). Operator reload-prompt side note recorded without filing an issue as requested. BR-1 replaced all arbitrary error prose filtering with exact fixed safe diagnostics and fixed status/type descriptions; eight disclosure controls failed red, then real caption/history sinks verified. Targeted241/0/0 on each supported runtime, arch4/0/0, lint4 clean. Recorded pre-close attempt0b05e4092133e3658d9ee0b9c4748122 passed exit0 in9m28s on fc955fb249525287f25da4a472f23f6711ced846, logSHA prefixc321d956565b, clean census; only issue bookkeeping since. Log /Users/xianxu/workspace/parley.nvim/.git/sdlc/local-checks/fc955fb249525287f25da4a472f23f6711ced846/suite.log. Auto choice through both provider wires; other skills keep forcing; proposal/classification/source/write guards intact; prose-only and empty replies show no edit proposed. Hub will clear the operator stage after merge. (done-when: contract moved since change-code; judged by the close review); review verdict: SHIP
2026-10-24: filed unclaimed at TL b532446a's direction. No implementation or live configuration changes made while diagnosing #419. Inside-Couch #419 acceptance passes; this upstream rejection is excluded from #419's landing contract by that same instruction.

2026-10-24: Claimed and ran start-plan after verifying #428 landed and archived. Root cause confirmed in source: review manifest forces propose_edits, skill_invoke encodes that name in the selected wire and overwrites payload.tool_choice; its on_error retains the structured failure but replaces the visible message with the constant transport error. Existing proposal-count and collaboration validation already run before effects. ARCH-DRY: tool-choice shapes remain in the existing wire registry; ARCH-PURE: safe error formatting is a pure boundary helper, not a second transport/parser. No retry loop, durable state, concurrency or per-keystroke work is added. Alternatives rejected: model-specific forcing exceptions drift with model support; allowing missing proposals would weaken write authority. Actions remain submit/retry: success applies validated commands and defers questions; rejected/unknown transport completion leaves source unchanged with the reason and manual retry. No new persisted format or artifact family. Plan sent to hub before code.


2026-10-24: Implemented the approved auto choice through a validated optional manifest field, carried by disk provider and assembly; existing wires encode nil tool name as their own automatic form. Other named tools retain forcing. Zero proposals now return `no edit proposed`, including actual prose and empty streams, before read-only tools, backup or reload. Safe skill failure formatting only selects a bounded structured error.message, discards credential/request-bearing diagnostics and quoted arbitrary values, preserves enum names, and limits UTF-8 output to 240 bytes. Raw/malformed/partial/oversized envelopes and stderr never become a displayed reason. Both caption and :messages retain the reason; existing stale-generation/cancel guards remain.

Verification: initial red replay found forced-wire, no-proposal, masked transport and caption failures; new helper tests initially failed because the helper was absent. Fixed two fixture defects (inner JSON quote escaping and explicit CLIProxy route selection) and a caller fixture missing its transport envelope. Verified the sanitized error fields directly against the actual local 10:40:15 log, without printing or retaining request/header material. Final targeted run: 230/0/0 across 11 files; installed /opt/homebrew/bin/nvim repeats 230/0/0. Each run has a clean process census. JSON/arrival architecture controls: 4/0/0, clean census. Logs retained at /Volumes/TestScratch/parley441-j0dbwg8e/{red,focused-final,operator-runtime,arch}.log. Final lint and queued pre-close follow; operator retry awaits hub coordination. No stage touched.

2026-10-24: Recorded pre-close attempt 01f0db5a697755df67bf12ec751394f2 on ee938b5a9dccf14b5022e5635ba11d33490c2d56 completed exit0 in 8m28s, SHA256 prefix4e6e9b947e81, clean process census. Log: /Users/xianxu/workspace/parley.nvim/.git/sdlc/local-checks/ee938b5a9dccf14b5022e5635ba11d33490c2d56/suite.log. Close exec42864 stopped before review on the final unchecked Plan row, which also includes close itself and the hub-coordinated operator retry. All automated work in that row has passed; re-close uses the precise no-plan-check acknowledgment for that post-check workflow, not a verification waiver. Hub now directs merge on pass; the operator retry remains explicitly unclaimed as evidence and follows the hub's rollout sequencing.

2026-10-24: Close round 1 returned REWORK with BR-1 (Critical, public-diagnostics-exclude-sensitive-values) and BR-2 (Important, required-acceptance-before-close). Verified all reported disclosure forms: privacy-red.log reports 8 failed/5 passed, including unquoted source text, unmatched single/double quotes, unfamiliar credential labels and a suffixed known diagnostic. Replaced the denylist and redaction path entirely with exact fixed-message/type/status maps. All public reason bytes now come from literals or a validated 100..599 integer; no unknown prose, enum/type strings or fragments are copied. Real review-path regressions assert both captions and message history exclude each leaking value and preserve source/no-backup. Hub approved the rule and will stage the candidate with Pair for the required outside-Couch operator retry. No merge until both findings clear. Targeted rework-final.log: 241/0/0, clean census; changed-code lint4 clean; second runtime and fresh recorded pre-close follow.

2026-10-24: Final rework verification: 241/0/0 on each supported runtime (rework-final.log and rework-operator-runtime.log), 4/0/0 JSON/arrival architecture controls (rework-arch.log), lint4 clean, all censuses clean. Evidence root /Volumes/TestScratch/parley441-j0dbwg8e. Queuing the fresh pre-close on this real code fix; then await the hub's combined stage and operator retry before re-close.

2026-10-24: Fresh pre-close attempt0b05e4092133e3658d9ee0b9c4748122 on fc955fb249525287f25da4a472f23f6711ced846 completed exit0 in9m28s, SHA256 prefixc321d956565b; clean process census and SysV owner-before/after0. Log: /Users/xianxu/workspace/parley.nvim/.git/sdlc/local-checks/fc955fb249525287f25da4a472f23f6711ced846/suite.log. After authenticated freeze lift, retained runner result was read without duplicate check. Authorized sdlc stage --build completed exit0: staged exact fc955fb249525287f25da4a472f23f6711ced846 on parley.nvim:0; plugin has no Go binaries to build. Operator steps sent to hub; hold re-close/merge for outside-Couch claude-sonnet-5-5 mixed question/command acceptance (BR-2).

2026-10-24: Hub delivered operator PASS on staged fc955fb249525287f25da4a472f23f6711ced846: “yes, works” outside Couch; the command applied and the question was kept. This closes BR-2's real retry requirement for the same claude-sonnet-5-5 / CLIProxy setup described in the handoff. Operator side note: after review rewrites the file, Neovim prompts whether to keep local changes; this is awkward. The operator wants to think about outside-Couch review's workflow before filing anything, so no issue or additional behavior change is made here. Hub directs re-close and merge, and will clear the stage afterward.

## Revisions

2026-10-24 — Hub approved the plan and required explicit prose-only handling: automatic choice may produce no tool call, so zero proposals refuse visibly as `no edit proposed`, before any tool, backup or reload. More than one proposal remains a separate invalid-batch refusal.

2026-10-24 — Close round 1 exposed the denylist's incomplete privacy proof (BR-1): arbitrary unquoted prose, unmatched quotations and unfamiliar credential spellings can bypass it. Hub approved exact safe-message recognition plus fixed status/type fallback. Replace filtering with a finite mapping whose output is only literals and a validated HTTP integer; unknown, altered, prefixed or suffixed messages cannot contribute any output bytes. Apply at all existing consumers: skill result, caption and history. Original sanitized rejection remains recognized exactly; source/write admission is unchanged. BR-2 remains pending the hub's combined operator retry, before re-close; the earlier merge-on-pass interpretation is superseded.
