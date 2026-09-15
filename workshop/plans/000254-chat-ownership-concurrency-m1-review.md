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

---

## Re-review — 2026-09-14T23:46:39-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 254 — Harden chat ownership and concurrency |
| repo | 000254-chat-ownership-concurrency |
| issue file | workshop/issues/000254-chat-ownership-concurrency.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | c95231c73563ced097b95abce5ed938634519b96..2ab8f40e302d9d316ac9b32016f405f2ed3d6d37 |
| command | sdlc milestone-close --issue 254 --milestone M1 |
| reviewer | codex |
| timestamp | 2026-09-14T23:46:39-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: medium
```

The pinned range satisfies the M1 containment scope. Both prior findings are addressed, including regression evidence that fails when topic ownership propagation is removed. No new blocking findings emerged. Confidence is limited by sandbox restrictions preventing the broader response-progress suite’s local server fixtures from starting.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      chat_respond.lua:2127 propagates response ownership into automatic topics; dispatcher.lua:881 preserves it across retries. Removing topic ownership in a scratch copy makes both deletion regressions fail at chat_ownership_spec.lua:157. The pinned tests verify unrelated-owner preservation and retention until exit/drain.
  - id: BR-2
    disposition: addressed
    note: |
      The pinned plan adds an explicit M6 task at line 310 covering bounded reconciliation, admission limits, diagnostics, timer cleanup, and deterministic verification. Its Revisions entry at lines 443–451 accurately distinguishes tasker.lua:130's current retention-only behavior from future supervision.
```

## 1. Strengths

- Private attempt/admission records prevent public query payloads or handle snapshots from falsely retiring outstanding work (`lua/parley/tasker.lua:17`).
- Completion requires exit and both stream terminations; tests exercise reordered evidence, uncertain probes, failed signals, and retry admission (`tests/unit/attempt_spec.lua:4`).
- Completion preserves typed-ahead questions and unmarked human text, with production-response regressions (`tests/integration/chat_ownership_spec.lua:73`).
- Performance instrumentation measures actual anchor/fold work and clearly documents baseline scaling costs.

## 2. Critical findings

None.

## 3. Important findings

None.

## 4. Minor findings

None.

## 5. Test coverage notes

Independent verification:

- `chat/lifecycle`: **536 passed**.
- `chat/exchange_model`: **281 passed**.
- Scoped lint: **12 files, zero warnings/errors**.
- Pinned diff whitespace check passed.
- BR-1 mutation check: **both topic cancellation regressions failed as expected** without ownership propagation.

The additional `chat/response_progress` run stopped after **32 passes and four fixture-startup failures**. Loopback binding independently returned `EPERM`; those live-server cases remain unverified here. Repository files remain unchanged.

## 6. Architectural notes

| Principle | Result |
|---|---|
| **ARCH-DRY** | Pass: shared attempt transitions, scoped cancellation helper, and centralized performance fields. |
| **ARCH-PURE** | Pass: the M1 attempt core has no IO or mocks; tasker owns process effects. |
| **ARCH-PURPOSE** | Pass for M1: containment and baseline evidence delivered; later concurrency work remains explicitly assigned. |
| **ARCH-MOCK** | Pass structurally: production and stateful fake share `_uv`; real subprocess tests complement controlled schedules. Live-server validation has the limitation above. |
| **ARCH-CONSTRAINTS** | Pass for M1: measured costs are identified as baselines; bounded reconciliation/admission is explicitly assigned to M6. |
| **ARCH-SECURE** | Pass: mutable public payloads cannot forge lifecycle evidence; reviewed tests use isolated stores. |
| **ARCH-ORDER** | Pass: private lifecycle changes use the reducer; tests control completion ordering and verify independent invariants. |
| **ARCH-FUNERAL** | Pass for M1: topic scratch buffers and process resources have tested termination paths; unresolved supervision remains an explicit M6 obligation. |

The M1 core-concept entries match their files and classifications. Atlas and traceability updates cover the new internal surface. No new user command, flag, keybinding, or configuration key requires a README update.

## 7. Plan revision recommendations

None beyond the verified BR-2 revision already present.
