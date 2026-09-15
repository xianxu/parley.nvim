# Boundary Review — 000254-chat-ownership-concurrency#254 (milestone M1)

| field | value |
|-------|-------|
| issue | 254 — Harden chat ownership and concurrency |
| repo | 000254-chat-ownership-concurrency |
| issue file | workshop/issues/000254-chat-ownership-concurrency.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | c95231c73563ced097b95abce5ed938634519b96..82b5ddcaa954b32ca82a701b67e79e7445fd1be9 |
| command | sdlc milestone-close --issue 254 --milestone M1 |
| reviewer | codex |
| timestamp | 2026-09-14T23:35:44-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

M1 preserves typed-ahead text and improves transport lifetime handling. Both mapped suites pass. One reproduced cancellation regression blocks approval: automatic topic generation loses the response’s owner identity, so lease invalidation leaves its transport running. Deferred reconciliation also needs an explicit milestone assignment.

## 1. Strengths

- Completion checks current suffix text before deleting blanks or inserting another prompt.
- Private attempt records prevent public payload mutations, failed probes, and accepted signals from falsely retiring work.
- Admission releases before terminal callbacks, allowing retries without accidentally removing a successor with a reused PID.
- Tests exercise controlled process ordering and real Neovim behavior; atlas and performance documentation describe M1’s limitations.

## 2. Critical findings

**Cancellation ownership does not reach automatic topic generation — ARCH-PURPOSE, ARCH-ORDER.**

[chat_respond.lua:1755](/Users/xianxu/workspace/worktree/parley.nvim/000254-chat-ownership-concurrency/lua/parley/chat_respond.lua:1755) now cancels only `transport_owner`, but `generate_topic` launches its request without transport options at line 1216. The response starts that request during completion at line 2100.

Reproduced sequence: complete an answer with `topic: ?`, wait for topic generation, then delete the answer header. Lease invalidation runs, but the topic process receives **no signal**. Its scratch buffer and process remain until independent completion.

**Fix:** propagate response ownership through automatic topic generation. Enumerate response-owned launch paths, including retries and topic requests, and test that cancellation reaches them while preserving unrelated work.

## 3. Important findings

**Deferred reconciliation has no concrete delivery assignment — ARCH-CONSTRAINTS.**

The [plan:242](/Users/xianxu/workspace/worktree/parley.nvim/000254-chat-ownership-concurrency/workshop/plans/000254-chat-ownership-concurrency-plan.md:242) requires capped reconciliation followed by visible unresolved status. [tasker.lua:130](/Users/xianxu/workspace/worktree/parley.nvim/000254-chat-ownership-concurrency/lua/parley/tasker.lua:130) explicitly implements no polling, and `cleanup_stale_handles` has no production caller. The issue log defers admission/reconciliation scheduling, but the remaining milestone checklists do not explicitly assign attempt reconciliation.

**Fix:** record the deferral in `## Revisions` and assign the scheduler, diagnostic outcome, admission limits, and deterministic tests to a named milestone.

## 4. Minor findings

None.

## 5. Test coverage notes

- `chat/lifecycle`: **533 passed**, zero failures/errors.
- `chat/exchange_model`: **281 passed**, zero failures/errors.
- Additional [scratch regression](/tmp/parley-review-254-topic_spec.lua): **failed as expected**, observing zero cancellation signals instead of one for the topic process. [Output](/tmp/parley-review-254-topic.log).
- No repository files changed.
- Existing ownership fixtures use a completed topic header, so they miss the automatic-topic branch.

## 6. Architectural notes

| Principle | Assessment |
|---|---|
| ARCH-DRY | **Pass:** existing process and read-observer seams reused. |
| ARCH-PURE | **Pass:** M1 attempt reducer is IO-free; tasker owns integration. |
| ARCH-PURPOSE | **Flag:** cancellation propagation misses a response-owned request. |
| ARCH-MOCK | **Pass:** stateful process fake shares the production seam; real subprocess tests provide conformance evidence. |
| ARCH-CONSTRAINTS | **Flag:** deferred reconciliation needs an explicit delivery boundary. |
| ARCH-SECURE | **Pass:** lifecycle authority is private; tests use isolated storage and synthetic credentials. |
| ARCH-ORDER | **Flag:** topic transport escapes its parent’s cancellation scope. |
| ARCH-FUNERAL | **Flag:** that escaped transport retains its scratch buffer until independent completion. |

M1 core-concept classifications match the code. Atlas coverage is present. No new command, keybinding, or configuration surface requires a README change in this range.

## 7. Plan revision recommendations

Add a `## Revisions` entry assigning deferred attempt reconciliation and global admission enforcement to a specific milestone, with observable acceptance criteria. Expand M1’s cancellation verification to include automatic topic generation.

```findings
findings:
  - id: new
    severity: Critical
    family: cancellation-owner-propagation
    title: |
      Automatic topic generation escapes response cancellation ownership
    detail: |
      chat_respond.lua:1755 cancels transport_owner, but generate_topic launches dispatcher.query at line 1216 without that identity. A scratch production-response regression completed the answer, deleted its header during topic generation, and observed no cancellation signal. Propagate ownership through response-owned launch paths and add a regression covering topic cancellation and unrelated-owner preservation (ARCH-PURPOSE, ARCH-ORDER, ARCH-FUNERAL).
  - id: new
    severity: Important
    family: deferred-contract-traceability
    title: |
      Assign deferred attempt reconciliation to an explicit milestone
    detail: |
      The plan at line 242 promises bounded reconciliation and visible unresolved status, while tasker.lua:130 implements no polling and its reconciliation function has no production caller. The issue log defers this work without an explicit remaining milestone task; add a Revisions entry and assign implementation, admission bounds, diagnostics, and deterministic verification (ARCH-CONSTRAINTS).
```
