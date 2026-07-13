---
id: 000182
status: working
deps: []
github_issue:
created: 2026-07-10
updated: 2026-07-12
estimate_hours: 4.62
started: 2026-07-12T21:56:40-07:00
---

# claude code style progression text in parley chat

## Problem

Agentic chat responses can remain silent long enough that users cannot tell
whether Parley is still working. The existing in-buffer progress indicator is
limited to web-search mode, mutates buffer text, and does not provide one
consistent waiting cue for every LLM response that will become chat content.

Inline definition has the same feedback gap at a smaller spatial scale: it
currently uses the detached luabar even though the selected term is the clear
place to show pending work.

## Spec

### Chat response presentation

- Apply the playful pending state only to dispatcher legs started by
  `chat_respond.respond`: both the initial response leg and each recursive LLM
  leg around local tool calls. Exclude `generate_topic`, memory preferences,
  generic skill invocations (including Document Review and Voice Apply), and
  every other background/utility LLM call. Definition uses its dedicated
  immediate adapter below. Do not show playful chat progress while a local tool
  itself is executing.
- Start each eligible call in a silent waiting state. If visible output arrives
  within one second, stream normally and never show the playful indicator.
  Visible output means answer text, reasoning status, or remote-tool status; a
  raw SSE event without visible content does not end the wait.
- If the call remains without visible output for one second, render an
  ephemeral virtual line below the response header in the form `⠙ brewing`.
  The line must be an extmark decoration: it does not enter buffer text, the
  exchange model, undo history, saved files, parsing, or later prompts.
- Animate the glyph from the canonical braille spinner sequence. Choose the
  verb from an internal playful vocabulary (for example `brewing`, `cooking`,
  and `dragon-slaying`) and avoid immediately repeating the visible verb. The
  vocabulary is cosmetic and is not user configuration in this issue.
- While the playful line is visible, change its verb on each received SSE event
  or after 15 seconds without an SSE event, whichever happens first. Spinner
  glyph animation remains independent of verb changes. Avoid immediate verb
  repetition within one call; consecutive calls do not share verb history.
- Once shown, keep the playful line visible for at least one second. Buffer all
  visible server output received during that minimum window. Hide the line at
  the later of (a) the first visible output and (b) the minimum-visible
  deadline, flush all buffered output once in original order, then resume
  ordinary streaming. If no visible output has arrived, retain the indicator
  beyond its minimum rather than hiding it into another silent state.
- After release, preserve existing provider-specific progress behavior such as
  reasoning and remote web-search status. The playful indicator is only the
  pre-output presentation stage, not a replacement for meaningful status.
- A tool-use-only LLM leg that completes before the playful indicator appears
  starts its local tool immediately. If the indicator is already visible, stage
  the transition until its minimum-visible deadline, then remove the indicator
  before starting the local tool. Never run a local tool behind a still-visible
  playful indicator.
- A successful empty completion honors the minimum duration if the indicator
  became visible, then removes it. A provider failure with a still-valid chat
  lease bypasses the minimum: remove the indicator, flush any staged real output
  once in original order, then surface the existing error. User cancellation,
  a stale lease, or an invalid/deleted buffer removes the indicator immediately
  and discards staged output because that response no longer owns a writable
  transcript. No terminal path may leave timers or extmarks alive.
- Callbacks are serialized through the Neovim event loop, and the controller
  applies events in callback order. The first event that crosses the reveal or
  minimum deadline performs that transition exactly once: visible output
  processed before reveal releases directly with no indicator; reveal processed
  first shows it; visible output at/after the minimum releases and flushes;
  failure preempts either timer using the valid-lease rule above; cancellation,
  stale lease, and invalid buffer preempt every write. Later callbacks become
  no-ops after the controller reaches its terminal state.

### Inline definition presentation

- On visual `<M-CR>`, immediately place an animated virtual spinner after the
  selected term, so `CVR` is presented as `CVR ⠙` without changing buffer text.
  Anchor it to the selection with an extmark and remove it on every terminal
  path.
- Definition does not use the detached luabar. Document Review remains a
  luabar consumer because it has no unambiguous inline anchor.
- The shared skill invocation boundary must therefore support two independent,
  backward-compatible controls: suppress detached progress for Definition, and
  run an idempotent terminal cleanup hook on success, failure, cancellation, or
  process abort. Review, Voice Apply, and existing generic callers retain their
  current luabar behavior by default.
- On a valid definition result, remove the virtual spinner immediately and run
  the existing durable footnote flow, producing `CVR[^cvr]` and its managed
  definition. There is no one-second delay or minimum-visible duration for
  definition.
- On failure, missing structured output, a stale selection, cancellation, or
  buffer deletion, remove the virtual spinner without adding a footnote.

### Design boundaries

- Use a small pure response-presentation controller for chat timing, state
  transitions, buffering decisions, and verb selection. Inject time and random
  choice so its behavior is deterministic under unit test (`ARCH-PURE`).
- Keep Neovim timers, extmarks, dispatcher callbacks, exchange-model access,
  and stream writes in thin adapters. The exchange model remains the sole owner
  of real chat positions; cosmetic virtual text is anchored to its durable
  response header rather than modeled as content.
- Reuse the existing canonical spinner frames. Keep the detached luabar,
  chat-pending virtual line, and selection-anchored definition spinner as
  separate renderers because they have different locations and lifecycle
  policies (`ARCH-DRY`, `ARCH-PURPOSE`).
- Expose raw SSE activity separately from semantic provider progress so playful
  verb changes do not alter existing progress-event contracts.
- Model provider failure, cancellation/invalidation, successful completion, and
  deferred local-tool transition as distinct terminal actions; do not collapse
  them into a single cleanup callback that loses real buffered output.

## Done when

- Fast chat output streams normally without ever showing playful progress.
- A chat call silent for one second shows an ephemeral animated playful line;
  once shown, it remains at least one second, stages incoming output, flushes it
  exactly once in order, and resumes streaming without transcript drift.
- SSE activity and a 15-second idle interval independently rotate the playful
  verb without coupling verb changes to spinner-frame animation.
- Every chat-producing LLM leg is covered, while topic generation and local
  tool execution do not show the playful line.
- Terminal, cancellation, stale-lease, and invalid-buffer paths clean up all
  timers, extmarks, and buffered state. Provider failures bypass the minimum
  and preserve valid partial output; cancellation or lost ownership discards it.
- Definition shows an immediate selection-anchored virtual spinner, never uses
  the luabar, and replaces the spinner with the existing durable footnote on
  success; all non-success paths remove it without a footnote.
- Document Review continues to use the detached luabar.
- Pure timing/state tests, real-entry-point chat and definition integration
  tests, atlas updates, and the full `make test` suite pass.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=1.20 impl=0.08
item: lua-neovim design=0.40 impl=0.60
item: lua-neovim design=0.30 impl=0.50
item: lua-neovim design=0.30 impl=0.40
item: atlas-docs design=0.10 impl=0.08
item: milestone-review design=0.10 impl=0.20
design-buffer: 0.15
total: 4.62
```

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md`
against `baseline-v3.1.md`. Method A only. The three `lua-neovim` primitives
separate chat response presentation, drain-safe task/dispatcher transport
coordination, and Definition's selection-anchored lifecycle; implementation
values already apply v3.1's 40% AI-paired ship-wall-clock scale.

## Plan

- [ ] Approve the durable plan at `workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md`.
- [ ] Build the pure chat presentation reducer with exhaustive event-order tests.
- [ ] Add separate raw-SSE activity and post-start transport-error callbacks.
- [ ] Replace the buffer-backed web spinner with the extmark-backed chat adapter.
- [ ] Add Definition's immediate selection spinner and generalized skill terminal cleanup.
- [ ] Update README/atlas/traceability and pass targeted, process, mapped, and full verification.
- [ ] Close, publish, and merge through the SDLC gates.

## Revisions

### 2026-07-13T00:13:49-07:00 — plan review corrections

Made subprocess draining an explicit production contract in `tasker.run`, added
injected clock/scheduler seams for deterministic adapter tests, assigned
semantic status rendering to the chat adapter, wired global user Stop to cancel
all sessions before process termination, and moved invalid-buffer Definition
cleanup ahead of completion-time Neovim access. Recalibrated the estimate from
4.09 to 4.62 hours by replacing the generic refactor item with a third focused
Lua/Neovim primitive for transport lifecycle work.

### 2026-07-13T00:07:30-07:00 — implementation plan

Added the calibrated v3.1 estimate and replaced the workflow placeholders with
the concrete durable-plan tasks. The plan adds a real curl/SSE process fixture
after code exploration found that dispatcher currently has neither raw-event
activity nor a post-start transport terminal; both are required to implement
the approved partial-output failure contract faithfully.

### 2026-07-12T23:53:24-07:00 — fresh-eyes spec review

Clarified the exact eligible LLM entry points, deferred tool-use-only
transitions until a visible indicator satisfies its minimum, separated provider
failure from cancellation/lost ownership, preserved valid partial output before
errors, defined callback-order tie breaking, and specified the shared
invocation controls required for Definition-owned cleanup without changing
Review or Voice Apply progress.

## Log

### 2026-07-10

### 2026-07-12

Claimed the issue and crystallized the temporal UI contract. The design uses a
pure chat presentation controller with extmark-backed renderers: delayed and
minimum-visible staging for chat, immediate selection-anchored feedback for
definition, and the existing detached luabar retained only where it has no
natural inline anchor. `ARCH-PURE` shaped the injected clock/random boundary;
`ARCH-DRY` keeps the spinner sequence canonical without conflating distinct UI
surfaces; `ARCH-PURPOSE` keeps every chat-producing LLM leg in scope.

### 2026-07-12 — spec review revision

The first independent review found ambiguous eligibility, tool-transition,
partial-output, tie-breaking, and Definition cancellation contracts. The spec
now classifies each path and preserves staged real output before a provider
error while discarding it only after cancellation or lost transcript ownership.

### 2026-07-13 — durable plan drafted

The 520-line implementation plan decomposes the work into a pure reducer,
dispatcher terminal coordination, chat extmark adapter, real chat wiring,
Definition terminal ownership, and documentation/verification. The estimate is
4.62 focused ship-hours under estimate-logic-v3.1, including the completed
brainstorm/spec and one SDLC boundary review.

### 2026-07-13 — plan review revision

The first plan review found that dispatcher correctness depends on tasker
draining pipes after process exit and that timer/cancellation/invalid-buffer
ownership needed explicit seams. The revised plan covers both EOF/exit orders,
uses injected production-shaped scheduling, cancels sessions before global
process Stop, and guarantees Definition terminal cleanup before buffer access.
