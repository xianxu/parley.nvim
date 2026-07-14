---
id: 000168
status: working
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-13
estimate_hours:
started: 2026-07-13T20:23:23-07:00
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

Choosing No, pressing Escape, or otherwise dismissing the prompt leaves both
the transcript and request untouched. Choosing Yes cancels that buffer's
pending response and then performs the requested native undo or redo exactly
once. Cancellation continues to own the existing cleanup of transport,
presentation, staged output, timers, leases, and late callbacks.

### Pending request identity

The existing per-buffer pending-session registry remains the source of truth
for whether a response is active. A fully constructed session records the
agent's display name and exposes only the read-only pending identity needed by
the history guard. The history mapping does not infer activity from UI marks,
tasker globals, or transcript text. This keeps ownership single-sourced
(`ARCH-DRY`) and confines confirmation/key execution to thin Neovim glue around
a small deterministic decision (`ARCH-PURE`).

### Safety fallback and scope

The confirmation covers only the standard normal-mode `u` and `<C-r>` keys in
prepared chat buffers. Command-line history operations (`:undo`, `:redo`,
`:earlier`, `:later`), user-defined mappings that bypass these keys, deletion of
the response header, and timing races are not pre-intercepted. The existing
structural chat lease remains mandatory for all such paths: it invalidates the
request after structural drift, suppresses stale stream/tool/progress/topic
writes, and surfaces at most one concise cancellation notice. This fallback is
also the final race guard after a confirmed history operation
(`ARCH-PURPOSE`).

The mappings are chat-buffer behavior rather than configurable shortcuts: they
preserve the meaning of Neovim's standard history keys and exist only to add
the pending-request confirmation.

## Done when

- `u` and `<C-r>` retain native behavior without prompting when no chat response is pending.
- With a pending response, both keys show a default-No confirmation naming the active agent and explaining that proceeding cancels the request.
- Declining or dismissing the confirmation changes neither transcript history nor the pending request.
- Confirming cancels the buffer's request, performs the selected undo or redo exactly once, and leaves no pending presentation, staged output, lease, or late write.
- Command-line/custom history paths remain protected by the structural lease and produce no raw stack trace or oversized provider/internal error.
- Production-path integration tests cover inactive passthrough, decline/dismissal, confirmed undo and redo, agent naming, cleanup, and the lease fallback.
- Chat lifecycle/keybinding documentation describes the guarded standard keys and the non-intercepted fallback paths.

## Plan

- [ ] Implement the approved spec through the durable implementation plan.

## Log

### 2026-07-08

### 2026-07-14

Investigated the original symptom against the current response lifecycle. Later
#137/#138 lease work already prevents stale mutations after undo/redo; #168 now
focuses on giving the user a choice before the standard history keys cancel a
pending request. Design reuses the per-buffer pending owner (`ARCH-DRY`), keeps
history prompting as thin UI glue (`ARCH-PURE`), and retains the structural
lease for every bypass/race path (`ARCH-PURPOSE`). `make test-spec
SPEC=chat/lifecycle` passed during investigation.
