# Chat Response Progress

`chat_pending` is a per-generation timer/extmark renderer. `generation_runner`
owns transcript bytes, write grants and completion; presentation cannot authorize,
stage or delay a write.

## Timing and ownership

A response waits silently for one second, then may show a playful spinner at its
current grant tip. Frames advance every 120 ms; activity and 15 seconds of idle
time rotate the verb. The first committed output hides the playful line
immediately. There is no minimum-visible delay. Provider detail is bounded and
coalesced separately from output delivery.

Up to four pending presentations may coexist in a buffer. Their `(buffer,
generation)` identities belong to the captured response session. The extmark
never becomes Markdown, an undo entry, saved text or future request context.
Its location is a display projection of the current grant tip, not write authority.
Terminal cleanup closes all timers and removes registry membership and extmarks;
reload/detach also retire presentations. Native history and branch commands do
not consult pending identity to decide whether an edit is allowed.

## Provider and tool completion

Position-free provider chunks are admitted into bounded generation queues and
committed through document operations. Consecutive chunks of one operation extend
one queued item, so output held behind the write turn is bounded by bytes (1 MiB
per generation), not by how many deltas it arrived in. At the budget the
generation stops, and the host reports why — naming the answer it waited behind.

A generation held behind the write turn replaces its spinner with *Waiting for
the answer to line N (streaming | running tools | preparing | finishing);
:ParleyStop there stops it*. The runner recomputes the holder and its phase on
every sync, so on every holder write, and the line returns to a working status
when the turn arrives.

A round's tools run at once but their blocks land one at a time, in declared
order (#266 M2), so the transcript can lag them. While the round runs, the status
line counts them — *Running tools: 1 of 2 finished* — from the generation's
snapshot, re-presented whenever the count changes; a waiting note takes
precedence. Neither process exit alone nor successful signaling proves cleanup:
transport ownership persists until exit and both pipes settle.

A provider failure lets already-admitted valid bytes drain, then reports the
failure. Cancellation or source revocation rejects obsolete output. A positive
cleanup callback is still required before unresolved effects leave the supervisor.
Definition and other non-response skills retain their own presentation policy.

## Definition and Other Skills

Visual `<M-CR>` Definition deliberately does not use the delayed chat policy.
`selection_spinner` immediately anchors inline virtual text after the selected
term (`CVR ⠙`), with no reveal delay or minimum duration. `skill_invoke` runs
its idempotent `on_terminal` cleanup before `on_done`; a valid result then adds
the durable footnote (`CVR[^cvr]`). Every failure, cancellation, stale selection,
or deleted-buffer path removes the spinner without adding a footnote.

Definition sets `detached_progress=false` because the selection is its natural
progress anchor. Document Review, Voice Apply, and generic skill invocations
retain the detached luabar progress UI by default.

## Key files

- `chat_presentation.lua`, `chat_pending.lua`: presentation reducer and native renderer.
- `response_session.lua`, `generation_runner.lua`: composed response lifetime and delivery receipts.
- `response_provider.lua`, `response_tools.lua`: provider and ordered tool effects.
- `dispatcher.lua`, `tasker.lua`, `attempt.lua`: transport admission and positive cleanup.
- `response_topic.lua`: independent automatic-topic source and header ownership.
- `tests/integration/chat_progress_process_spec.lua`: native editor with a stateful process fixture.
- `tests/integration/response_session_spec.lua`: deferred preparation, held answers, the waiting note, tool continuation and cleanup.
- `tests/integration/generation_turn_spec.lua`: the write turn — enforcement, release matrix, wake, held budget, undo coherence.
