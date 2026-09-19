# The transcript is the whole truth

A chat is one Markdown file, and that file is everything Parley needs to know
about it. This page maps the line between the file and everything else Parley
keeps (#261). It lists every state that can refuse a submission or hold a
generation, with what releases it. The invariant it serves is the target
[transcript-is-the-whole-truth](../../workshop/targets/transcript-is-the-whole-truth.md).

## The restart invariant

**Quitting and reopening a chat rebuilds every fact a submission depends on
from the file.** Nothing else survives, and nothing else needs to:

- Every piece of runtime state below belongs to one document epoch (one load of
  the buffer) or to the Neovim process. A reload, a closed buffer or an exit
  ends it.
- The only files outside the transcript are sidecars. Each one degrades when it
  is missing or corrupt, and none can refuse a submission.

What the file says, and what a reopen reads from it:

- **Exchanges** are `💬:` questions and `🤖:` answers. The answer header is
  written with a generation's first write. An exchange's identity is a handle
  for one epoch, rebuilt from the markers on every load.
- **An interrupted answer** is partial text under `🤖:` with no `💬:` prompt
  after it. Only a successful ending writes the next prompt
  (`response_completion.lua`). Stop, a failure, an edit and a reload each leave
  what was written, and the file is whatever it says.
- **There is no pending or error marker.** The next legal action follows from
  the text: with the cursor on an answered question, submitting regenerates it;
  on an unanswered one, it starts a new turn. Why a response stopped is said
  once, when it stops ([refusal.lua](../../lua/parley/refusal.lua)), and is not
  stored.

## Three buckets

- **Durable:** the transcript, read back on every load.
- **Runtime:** in memory. It is released on Stop, on an edit that revokes it,
  on reload or detach, or on exit, and nothing reads it across a reload.
- **External:** sidecar files under the state directory. They are advisory:
  losing one degrades a convenience and never blocks.

`:e!` reaches the document as a detach followed by a fresh attach, the same way
closing the buffer does. So everything a detach releases is also released by a
reload.

Two rules this page relies on are stated elsewhere, once each:
- a stopped response always ends and frees what it held
  ([lifecycle](lifecycle.md), "A stopped response always ends");
- how a generation's writes group into undo steps
  ([ownership](ownership.md), "Undo grouping").

## Inventory

| State | Lives in | Bucket | Released by | Pinned by |
|---|---|---|---|---|
| Exchanges, answers, the next prompt | the chat file | durable | nothing: it is the truth | `chat_respond_spec` (regenerate after reload, and after close and reopen) |
| Write grants, generations, the write turn | `document/state.lua` | runtime | a generation's finish; an output edit revokes its grant; reload and detach revoke all of them and clear the turn | `document_state_spec`, `generation_turn_spec`, `document_turn_wake_spec` |
| `prev_answer`, a regenerated answer's previous text | `document/init.lua` (`previous_answers`) | runtime | its generation's finish; a revoked grant or a deleted question on the next read; reload and detach | `document_previous_answer_spec` |
| Runner `active` count and staged bytes | `generation_runner.lua` | runtime | `finish`, which every Stop, edit, reload, detach and fault reaches | `generation_settles_spec` |
| Process records, admissions, stopped scopes | `tasker.lua` | runtime | a stopped scope gets TERM, then KILL at 2 s, and refuses new spawns; an unscoped run is killed at its deadline; a record is freed after exit plus both pipe EOFs; `leave()` on VimLeavePre | `tasker_supervision_spec`, `process_group_conformance_spec`, `unscoped_kill_spec` |
| A process that survives KILL | `tasker.held()` | runtime | the kernel; its pid is named in the capacity refusal it causes | `tasker_supervision_spec`, `chat_refusal_spec` |
| Pending answer targets (four per chat) | `response_target.lua` | runtime | cancel, a source edit, reload, detach, a step that throws | `response_target_spec` |
| Topic jobs | `response_topic.lua` | runtime | Stop, a failed origin response, reload, detach, a changed source | `response_topic_spec`, `chat_cancel_entry_spec` |
| Stop membership (`responses`) and batches (`batches`) | `chat_respond.lua` | runtime | a response's end; a batch retires on reload or detach, and a paused one gives way to a new batch | `chat_stop_generation_spec`, `batch_lifecycle_spec`, `chat_refusal_spec` |
| User edit guards (64 live) | `document/user_edits.lua` | runtime | the edit's end; reload and detach | `document_user_edits_spec` |
| First-use model setup in progress | `llm_readiness.lua` | runtime | the setup settling or being cancelled | `llm_readiness_spec`, `chat_refusal_spec` |
| A skill run in flight | `skill_invoke.lua` (`_in_flight`) | runtime | its end, cancel, and BufUnload (covering `:e!` and `:bd`) | `skill_invoke_spec` |
| A response paused on changed input | `response_session.lua` | runtime | Resume or Stop; it keeps its grants until then | `chat_stop_generation_spec` (continues a paused response with its original input) |
| Sidecars: state, vault state, system prompts, file access | the state directory (`tests/helpers/sidecars.lua` lists them) | external | never needed: each degrades field by field, and interrupted-write temp files are swept at setup | `sidecar_degrade_spec`, `sidecar_authority_spec` |
| Remote reference cache | the `remote_reference_cache.json` sidecar | external | never needed: a missing entry becomes placeholder text | `remote_references_spec` |

These show state but can refuse nothing: the pending-answer presentation
(`chat_pending.lua`) and the response status line (`response_status.lua`).
Both are released on reload and detach.

The legacy `<state_dir>/answer-recovery/` directory from before #261 is not read
or written by anything. It is safe to delete, and Parley leaves it where it is.
`chat_respond_spec` runs a submission with a corrupt copy of it present.

## What the user is told

Every refusal, and every ending other than success, reaches the user once, in
words that name what to do. The words live in
[refusal.lua](../../lua/parley/refusal.lua), which is pure: it returns the
message and says how it resolved, and the caller logs it. Two nets keep a
refusal from reaching a user as a bare token:

- `tests/arch/refusal_vocabulary_spec.lua` reads the producer files and fails on
  a reason it finds there without words. It sees the call shapes it knows, so it
  catches most at authoring time, not all.
- The harness (`tests/minimal_init.vim`) watches what `describe` actually
  resolves, across every spec in the suite, and fails the spec file that produces
  a token with no words.

A user's own Stop is silent. A refusal is never written into the file.
