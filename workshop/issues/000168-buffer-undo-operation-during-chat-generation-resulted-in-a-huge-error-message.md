---
id: 000168
status: codecomplete
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-14
estimate_hours: 4.01
started: 2026-07-13T20:23:23-07:00
actual_hours: 6.67
---

# buffer undo operation during chat generation resulted in a huge error message

I don't quite remember where we settled in terms of human edits during agent generation. but at least this shouldn't result in error that end user won't understand.

## Problem

Undoing or redoing chat history while Parley is waiting for an agent can remove
the response shell that owns the in-flight request. Parley already detects that
structural change and prevents stale callbacks from writing into the transcript,
but the standard history keys mutate first and cancel afterward. The user gets
no choice before losing the request, and the resulting technical warning does
not explain the relationship between history manipulation and cancellation.

## Spec

### Standard history keys ask before cancelling

In a prepared chat buffer, Parley wraps normal-mode `u` and `<C-r>` with a
pending-request guard. When that buffer has no active chat response, each key
performs its native undo or redo immediately, with no prompt and no change to
normal Neovim history behavior.

When the buffer owns an active chat response, either key opens a default-No
confirmation before changing history. The prompt names the active agent and
explains the consequence in user language:

> Parley is checking with <Agent>. Changing history will cancel this request. Proceed?

The agent label is normalized to one line and truncated so the complete prompt
is at most 160 UTF-8 bytes. Choosing No (the default), pressing Escape (the
confirmation API's dismissal return), or otherwise dismissing the prompt leaves
both the transcript and request untouched. Choosing Yes performs one
non-yielding, buffer-scoped history cancellation transaction:

1. stop only transport handles owned by this buffer, preventing new provider
   delivery;
2. execute the requested native undo or redo exactly once, preserving the
   user's numeric count (`3u`, `2<C-r>`); and
3. synchronously retire that buffer's pending session as structural drift,
   discarding its presentation, staged output, timers, lease, and late
   callbacks without trying to mutate the now-undone response shell.

No scheduled cancellation step may remain between the history mutation and
pending-session retirement; the mapping callback yields only after the
transaction is terminal. The stop/retire operations are idempotent so a racing
provider callback or lease validation cannot finalize the request twice.

### Pending request identity

The existing per-buffer pending-session registry remains the source of truth
for whether a response is active. A fully constructed session records the
agent's display name and exposes the read-only pending identity needed by the
history guard. It also owns synchronous retirement of that session. The tasker
owns a buffer-scoped transport stop; a chat-response orchestration function
combines transport stop, the injected native history mutation, and pending
retirement in the ordering above. No layer performs global cancellation for a
guarded history key, so a request in another buffer remains active.

The history mapping does not infer activity from UI marks, tasker globals, or
transcript text. This keeps ownership single-sourced (`ARCH-DRY`) and confines
confirmation/key execution to thin Neovim glue around a small deterministic
decision (`ARCH-PURE`).

### Safety fallback and scope

The confirmation covers only the standard normal-mode `u` and `<C-r>` keys in
prepared chat buffers. Command-line history operations (`:undo`, `:redo`,
`:earlier`, `:later`), user-defined mappings that bypass these keys, deletion of
the response header, and timing races are not pre-intercepted. The existing
structural chat lease remains mandatory for all such paths: it invalidates the
request after structural drift, suppresses stale stream/tool/progress/topic
writes, and surfaces at most one concise cancellation notice per request. A
fallback notice is at most 160 UTF-8 bytes and contains no provider response,
stderr, exception text, traceback, serialized payload, or internal table. A
confirmed standard-key transaction does not emit a second cancellation notice
after the confirmation itself. This fallback is also the final race guard after
a confirmed history operation
(`ARCH-PURPOSE`).

The mappings are chat-buffer behavior rather than configurable shortcuts: they
preserve the meaning of Neovim's standard history keys and exist only to add
the pending-request confirmation.

## Done when

- `u` and `<C-r>` retain native behavior, including numeric counts, without prompting when no chat response is pending.
- With a pending response, both keys show a default-No confirmation naming the active agent and explaining that proceeding cancels the request.
- Declining or dismissing the confirmation changes neither transcript history nor the pending request.
- Confirming stops only the current buffer's transport, performs the selected counted undo or redo exactly once, synchronously retires that pending session, and leaves no presentation, staged output, lease, or late write.
- A confirmed history operation in one chat buffer leaves an unrelated pending request in another buffer active.
- Command-line/custom history paths remain protected by the structural lease and produce at most one cancellation notice of 160 UTF-8 bytes with no provider/internal body, stderr, exception, traceback, payload, or table dump.
- Production-path integration tests cover inactive counted passthrough, concrete Yes/No/dismissal returns, confirmed counted undo and redo, bounded agent naming, exact-once synchronous cleanup, two-buffer isolation, and the lease fallback notice's cardinality/content/size.
- Chat lifecycle/keybinding documentation describes the guarded standard keys and the non-intercepted fallback paths.

## Plan

- [x] Add buffer-scoped transport stopping with isolation and idempotence tests.
- [x] Add immutable pending identity and synchronous stale-session retirement.
- [x] Add the protected, non-yielding history cancellation transaction.
- [x] Add bounded prompt policy plus counted `u`/`<C-r>` chat mappings.
- [x] Update lifecycle/README/traceability docs and pass focused plus full verification.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec       design=0.60 impl=0.04
item: lua-neovim      design=0.30 impl=0.60
item: lua-neovim      design=0.30 impl=0.60
item: lua-neovim      design=0.30 impl=0.60
item: atlas-docs      design=0.04 impl=0.08
item: milestone-review design=0.10 impl=0.20
design-buffer: 0.15
total: 4.01
```

The approved spec and established pending/lease/keymap patterns earn the ×0.2
design discount for the implementation and documentation primitives. Three
separate focused Lua primitives cover tasker filtering, pending lifecycle
retirement, and guarded history/keymap behavior; each implementation value is
40% of the v2 table's 1.5-hour high choice, which includes integration debugging
and verification. Documentation and review use the same v3.1 scaling. No
external library or API can short-circuit this Neovim lifecycle work. The single `milestone-review`
primitive represents the one issue-close boundary review, not a separate M1.

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only. Calibration source reported stale on
2026-07-14, so the per-primitive values are provisional.*

## Log

### 2026-07-08

### 2026-07-14
- 2026-07-14: closed — make test-spec SPEC=chat/lifecycle passed; make test passed with Luacheck 267 files/0 warnings/0 errors and all unit, architecture, integration specs; git diff --check passed; atlas/chat/lifecycle.md and atlas/traceability.yaml updated; production regressions cover counted history, default-No, exact-once cancellation, bounded fallback notice, and two-buffer isolation; review verdict: FIX-THEN-SHIP

Boundary-review resolution: scoped task stopping now reports sanitized signal
failure after still partitioning owned handles. Production mapping tests now
cover inactive counted redo, dismissal, bounded multibyte agent labels, counted
confirmed undo/redo with exact transcript states, and mutation observed before
synchronous retirement. The durable plan checklist was reconciled and the two
prevention rules were recorded in `workshop/lessons.md`.

Investigated the original symptom against the current response lifecycle. Later
#137/#138 lease work already prevents stale mutations after undo/redo; #168 now
focuses on giving the user a choice before the standard history keys cancel a
pending request. Design reuses the per-buffer pending owner (`ARCH-DRY`), keeps
history prompting as thin UI glue (`ARCH-PURE`), and retains the structural
lease for every bypass/race path (`ARCH-PURPOSE`). `make test-spec
SPEC=chat/lifecycle` passed during investigation.

### 2026-07-14 — spec review revision

Fresh-context review found underspecified cancellation ownership, asynchronous
ordering, count-prefix behavior, and notice bounds. The spec now assigns
buffer-scoped transport stop to tasker, synchronous session retirement to the
pending registry, and transaction orchestration to the chat-response boundary;
preserves numeric counts; and gives prompts/notices explicit size, content, and
cardinality oracles.

### 2026-07-14 — implementation

Added buffer-scoped transport retirement, immutable pending identity, guarded
standard history keys, and the structural-lease fallback notice. Focused tests
cover counted inactive history, default-No and dismissal, confirmed undo/redo,
exact-once synchronous cleanup, bounded messages, and two-buffer isolation.
The fallback now reports only “Parley stopped the response because the chat was
changed or undone.” and never exposes provider or internal error content.

Verification passed with `make test-spec SPEC=chat/lifecycle` and full
`make test` (Luacheck: 267 files, 0 warnings/errors; all unit, architecture, and
integration specs passed). `git diff --check` passed. Static reachability
confirmed the guarded transaction calls only `stop_buf`; remaining global-stop
hits belong to the explicit global Stop command and the lease fallback.

## Revisions

### 2026-07-14T10:50:00-07:00 — fresh-context spec review

- Reason: the first review found the approved interaction incomplete at its
  cancellation and native-history boundaries.
- Delta: defined buffer-scoped ownership and non-yielding ordering, numeric
  count preservation, two-buffer isolation, concrete confirmation outcomes,
  and bounded/cardinality-tested user messages.

### 2026-07-14T11:35:00-07:00 — implementation planning

- Reason: the approved spec was expanded into a durable, TDD-sequenced plan and
  reconciled v3.1 estimate before entering code changes.
- Delta: replaced the placeholder plan row with five atomic work items, added
  the 1.85-hour Method A derivation, and linked implementation to
  `workshop/plans/000168-buffer-undo-operation-during-chat-generation-resulted-in-a-huge-error-message-plan.md`.

### 2026-07-14T11:50:00-07:00 — plan-quality estimate revision

- Reason: the SDLC plan-quality judge found one `lua-neovim` primitive materially
  underrepresented three independently implemented/tested lifecycle concerns.
- Delta: decomposed tasker filtering, pending retirement, and guarded history
  into three high-range focused Lua primitives; raised the derived estimate from
  1.85 to 4.01 hours; implementation architecture and scope are unchanged.
