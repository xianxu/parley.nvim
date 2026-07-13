# Chat Response Progress

Parley gives each LLM leg that can become chat content a short, transient
pending presentation. This covers the initial `chat_respond.respond` request
and every recursive request around client-side tool calls. Topic generation,
memory preferences, skills, and other background LLM work are not eligible.
Definition has a separate immediate renderer described below.

## Timing and State

One `chat_pending` session owns one dispatched chat leg:

1. The leg waits silently for one second. Answer text, reasoning status, or
   remote-tool status received in that window is delivered normally, so fast
   responses never show pending copy. Raw transport activity is not visible
   output and does not end the wait.
2. A still-silent fresh leg shows a virtual line below its `🤖:` response
   header; a recursive tool leg starts on the stable pre-stream separator
   outside Parley-generated tool folds. The line initially takes the form
   `⠙ Baking`. The glyph animates from `progress.SPINNER`; SSE/JSONL activity
   and 15 seconds of transport idleness rotate the playful verb independently.
3. Once shown, the line remains visible for at least one second. Visible output
   arriving during that interval is staged in callback order. At the minimum
   deadline Parley removes the playful line and releases all staged output once;
   subsequent output streams normally. With no visible output, the playful line
   remains rather than returning to silence.
4. Meaningful provider progress uses the same extmark after release. Each
   ordinary stream write synchronously relocates that mark below its final
   written line before the writer yields. Reasoning details and remote-tool
   status therefore replace the playful copy without becoming transcript text
   and remain at the current generation tip as answer chunks arrive.

`chat_presentation` is the pure reducer for deadlines, staging, terminal
decisions, and provider-detail accumulation. `chat_pending` is the Neovim IO
shell: it serializes public callbacks and timer events through the main loop,
renders the reducer's actions, and owns all timers and the extmark.

## Decoration and Transcript Ownership

The pending/status line is an `invalidate=true` extmark with `virt_lines`; it
never enters Markdown, the exchange model, undo history, saved files, parser
input, or a future prompt. Its presentation anchor moves with the generation
tip: the response header before fresh content, the stable separator immediately
before a recursive stream placeholder, and the stream writer's tracked last line
after every write. The separator is outside Parley's tool folds, so closed tool
results cannot hide a waiting recursive leg. The writer reports that
extmark-adjusted row after buffer/model growth, and
`chat_pending` repairs a replacement-invalidated visible mark with the same ID
and text in that same scheduled callback. Immediately before mutation it also
requires the visible mark to be valid; that uninterrupted authorization allows
repair only for invalidation caused by the writer itself. A mark invalidated by
an earlier external edit terminates the pending session instead of being revived.

The independent chat lease remains anchored to the durable response-header
line and never follows the replaceable stream line. It decides whether that
header still owns the in-flight response. Deleting or invalidating the header
therefore cancels the session and suppresses late writes.

Only one active pending session may own a buffer. `:ParleyStop` cancels all
registered sessions before stopping subprocesses. Every terminal path removes
the extmark, closes timers, and releases registry ownership; callbacks that
arrive afterward are no-ops.

## Tool Continuation and Terminal Paths

A tool-use-only LLM leg that completes during the silent first second proceeds
directly to its local tool. If its playful line is already visible, completion
waits only for the one-second visible minimum; the line is removed before tool
execution begins. Local tool execution itself has no playful spinner. A
recursive LLM leg starts a fresh pending session after the tool result is added
to the transcript.

Successful empty completions follow the same minimum-visible rule. Provider
failures are different: while the lease is valid, Parley immediately removes
the decoration, releases any staged partial output in order, and then reports
the transport or non-2xx HTTP error. Cancellation, a stale lease, or an invalid
buffer removes the decoration immediately and discards staged output because
the request no longer owns a writable transcript. Pre-start failures (secret
resolution, busy process slot, or spawn rejection) converge on the same cleanup
without waiting for a timer.

Dispatcher transport activity is additive to semantic progress: one SSE record
or complete structural JSONL line reports one activity event without delaying
content/status parsing. HTTP status is captured in a stderr trailer after the
process and both pipes drain, leaving response stdout byte-for-byte available
for partial-output handling.

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

## Key Files

- `lua/parley/chat_presentation.lua` — pure response-presentation reducer.
- `lua/parley/chat_pending.lua` — main-loop timer/extmark adapter and registry.
- `lua/parley/chat_respond.lua` — eligible initial/recursive leg integration.
- `lua/parley/exchange_model.lua` — pure recursive initial-tip query.
- `lua/parley/dispatcher.lua`, `lua/parley/tasker.lua`, `lua/parley/vault.lua` —
  activity, drained terminal, HTTP failure, and pre-start failure boundaries.
- `lua/parley/selection_spinner.lua`, `lua/parley/skill_invoke.lua` — immediate
  Definition renderer and generalized skill terminal cleanup.
- `tests/unit/chat_presentation_spec.lua`,
  `tests/integration/chat_pending_spec.lua`, and
  `tests/integration/chat_progress_process_spec.lua` — state, Neovim adapter,
  and real curl/SSE process coverage.
