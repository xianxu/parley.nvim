---
id: 000182
status: codecomplete
deps: []
github_issue:
created: 2026-07-10
updated: 2026-07-13
estimate_hours: 8.94
started: 2026-07-12T21:56:40-07:00
actual_hours: N/A
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
  Here an SSE event is one blank-line-delimited record: comments, `event:`, and
  multiple `data:` fields inside that record rotate the verb only once, and EOF
  terminates one final unterminated record. Activity is observed at the first
  field/comment and never delays semantic parsing; supported non-SSE JSONL
  streams treat each complete non-empty line as one activity record.
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
  became visible, then removes it. A provider failure—either a transport/process
  failure or an HTTP response outside 200–299—with a still-valid chat lease
  bypasses the minimum: remove the indicator, flush any staged real output once
  in original order, then surface the existing error. User cancellation,
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
- Give callers an additive post-start provider-error callback. Callers that do
  not opt in receive every historical completion surface they supplied—both
  `on_exit(qid)` and the assembled-response callback, when present—exactly once
  after transport drain, so topic generation, memory preferences, and other
  existing consumers cannot strand teardown.
- Preserve each HTTP response body while classifying its final status outside
  the SSE stream. Curl writes a qid-specific status trailer to stderr, leaving
  response stdout byte-for-byte untouched. The trailer is transport metadata:
  it is not an SSE event, visible content, raw provider response, or playful
  activity.
- Route failures before a transport starts through the existing pre-start abort
  class exactly once. Missing/unresolved vault secrets, a busy subprocess slot,
  and process-spawn rejection must all notify the chat/skill caller so it can
  remove pending extmarks and timers rather than waiting forever.
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
item: lua-neovim design=0.50 impl=0.60
item: lua-neovim design=0.60 impl=0.60
item: lua-neovim design=0.60 impl=0.60
item: lua-neovim design=0.40 impl=0.50
item: api-integration design=0.50 impl=0.60
item: cross-cutting-refactor design=0.40 impl=0.50
item: atlas-docs design=0.15 impl=0.08
item: milestone-review design=0.15 impl=0.20
design-buffer: 0.15
total: 8.94
```

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md`
against `baseline-v3.1.md`. Method A only. The four `lua-neovim` primitives
separate the pure response controller, chat adapter/integration, drain-safe
task/dispatcher transport, and Definition's selection-anchored lifecycle. The
API integration covers the real curl/SSE process fixture; the cross-cutting
item covers compatibility consumers and pre-launch vault/task ownership.
Implementation values already apply
v3.1's 40% AI-paired ship-wall-clock scale.

## Plan

- [x] Approve the durable plan at `workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md`.
- [x] Build the pure chat presentation reducer with exhaustive event-order tests.
- [x] Add separate raw-SSE activity and post-start transport-error callbacks.
- [x] Replace the buffer-backed web spinner with the extmark-backed chat adapter.
- [x] Add Definition's immediate selection spinner and generalized skill terminal cleanup.
- [x] Update README/atlas/traceability and pass targeted, process, mapped, and full verification.
- [ ] Close, publish, and merge through the SDLC gates.

## Revisions

### 2026-07-13T00:56:07-07:00 — framing precision gate correction

Pinned Definition's initial canonical frame to tick 1 (`⠙`), made every valid
SSE field part of one record while distinguishing JSONL structurally, and moved
the qid-specific HTTP status trailer to stderr so response stdout is preserved
byte-for-byte across unterminated bodies and arbitrary chunk splits. Reset plan
approval pending fresh review.

### 2026-07-13T00:50:00-07:00 — streaming-framing gate correction

Decoupled raw activity framing from semantic delivery: the first field marks
SSE activity, every semantic line still streams immediately, blank lines only
reset record ownership, and non-SSE JSONL lines remain independently streamed.
Reset revised-plan approval pending fresh review.

### 2026-07-13T00:45:35-07:00 — HTTP failure gate correction

Expanded provider failure to include non-2xx HTTP responses while preserving
streamed bodies and excluding curl's internal status trailer from SSE activity.
Added real 401 and partial-body 500 process coverage, reset revised-plan
approval, and recalibrated the API fixture work from 8.72 to 8.94 hours.

### 2026-07-13T00:38:31-07:00 — launch-failure gate correction

Required missing/unresolved secrets, busy subprocess rejection, and spawn
failure to reach the existing pre-start abort owner exactly once. Added
real-entry chat and Definition cleanup coverage, reset revised-plan approval,
and recalibrated the expanded compatibility work from 8.19 to 8.72 hours.

### 2026-07-13T00:32:14-07:00 — compatibility review correction

Expanded the dispatcher fallback to cover both historical completion surfaces:
topic generation's `on_exit` and memory preferences' assembled-response
callback. Reset plan approval while the materially revised plan returns through
fresh review.

### 2026-07-13T00:28:50-07:00 — SDLC plan-quality gate corrections

Defined blank-line-delimited SSE event framing, preserved a legacy completion
fallback for dispatcher consumers that omit the additive transport-error hook,
required Definition to own post-start transport failure, and made main-loop
FIFO scheduling part of the chat adapter contract. Recalibrated the estimate
from 4.62 to 8.19 hours for the expanded transport, compatibility, process-fake,
race-test, documentation, and review surface.

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

### 2026-07-13 — plan-quality gate revision
- 2026-07-13: closed — All mapped behavior, 7 real curl/SSE cases, 22 chat-pending, 25 Definition, 16 shared skill lifecycle, lint, full JOBS=1 make test, and diff checks pass; both REWORK rounds are fixed with real-entry setup-terminal and moving-anchor regressions; actual telemetry is unavailable and the sole unchecked row is this close/publish workflow.; review verdict: SHIP

The SDLC judge rejected the approved draft because post-start errors could
strand legacy dispatcher consumers, Definition omitted that terminal, SSE
activity was line-oriented rather than record-oriented, libuv callbacks lacked
an explicit main-loop queue, and the estimate understated the enlarged scope.
The durable plan and spec now close each gap before implementation begins.

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

### 2026-07-13 — implementation authorized

The operator approved the reviewed durable plan for execution. Implementation
will run in an SDLC-owned isolated worktree because the main checkout contains
an unrelated in-progress #162 issue edit.

### 2026-07-13 — corrected plan approved

A second fresh-eyes review approved the gate corrections after the dispatcher
compatibility path was extended to callback-only memory preference generation
and the process-level test was moved ahead of production chat wiring.

### 2026-07-13 — launch-failure gate revision

The second SDLC plan-quality pass found that vault resolution and subprocess
launch rejection could return without any terminal callback after the UI had
started. The revised plan makes those failures additive pre-start aborts and
tests cleanup through the real chat and Definition entries.

### 2026-07-13 — launch-failure correction approved

Fresh review approved the additive vault/task launch error channels, their
single dispatcher abort owner, and the real-entry cleanup coverage.

### 2026-07-13 — HTTP failure gate revision

The third SDLC plan-quality pass found that curl's default exit behavior treats
HTTP 401/429/500 as successful processes. The plan now carries an internal
status trailer outside SSE semantics and maps non-2xx responses to the same
body-preserving provider-failure terminal.

### 2026-07-13 — HTTP failure correction approved

Fresh review approved the body-preserving HTTP status channel, its exclusion
from SSE semantics, and the 401/partial-500 process coverage.

### 2026-07-13 — streaming-framing gate revision

The fourth SDLC plan-quality pass found that parsing a whole SSE record only at
its blank delimiter would regress current newline-driven semantic streaming.
The corrected plan observes activity without buffering semantic lines and adds
GoogleAI/Ollama-style JSONL regressions.

### 2026-07-13 — streaming-framing correction approved

Fresh review approved independent activity framing with immediate semantic
delivery for both SSE and newline-delimited provider streams.

### 2026-07-13 — framing precision gate revision

The fifth SDLC plan-quality pass found the wrong initial Definition glyph,
unknown SSE fields that could double-count activity, and an ambiguous stdout
status boundary. The plan now fixes all three with explicit tests.

### 2026-07-13 — framing precision correction approved

Fresh review approved the exact initial glyph, extension-field record ownership,
and stderr-based HTTP status framing with byte-split coverage.

### 2026-07-13 — Task 1 complete

Implemented the pure immutable presentation reducer and formatter with 41
focused tests. Fresh reviews caught and closed delayed-reveal minimum timing,
nil completion ownership, and quadratic staged-event copying; staging now uses
an O(1) persistent chain with one linear ordered flush.

### 2026-07-13 — Task 2 complete

Made subprocess completion drain-safe across process exit, stdout EOF, and
stderr EOF; added raw SSE/JSONL activity plus body-preserving provider failure
terminals; and preserved every legacy completion surface. The focused boundary
passes 110 tests. Fresh specification and quality reviews found no blocking
issues after callback exception containment, bounded diagnostics, and completion
isolation were added. `ARCH-PURE` kept transport framing deterministic at the
dispatcher seam while lifecycle ownership remains in the task integration.

### 2026-07-13 — Task 3 complete

Added the dedicated chat pending adapter: one extmark-backed virtual line per
buffer, canonical spinner frames, injected FIFO scheduler/clock seams, and
idempotent timer/registry cleanup. Sixteen integration tests include a real
libuv fast-event handoff and deterministic reveal, minimum, activity, idle,
status, cancellation, invalid-buffer, stale-lease, reentrancy, and callback
failure cases. Fresh reviews approved the boundary after closing three timer and
construction ownership gaps. `ARCH-PURE` keeps all timing policy in the reducer;
the adapter is the sole Neovim IO owner.

### 2026-07-13 — Task 4 review correction

The first fresh review reproduced an intermittent real-process stall and found
the real-entry behavioral matrix incomplete. The stall revealed that the
adapter compared high-resolution deadlines against millisecond libuv timers;
an early one-shot callback could be ignored without rescheduling. Task 4 now
fixes that timing contract at `chat_pending` itself, stress-runs the process
fixture, and adds the missing `M.respond` glue-path coverage before acceptance.

### 2026-07-13 — Task 4 complete

Removed the buffer/model-backed web spinner and routed every chat-producing
initial and recursive LLM leg through the extmark adapter. The accepted boundary
covers fast and slow output, exact deadline orders, semantic status, tool-only
completion, recursive verbs, topic exclusion, provider and pre-start failures,
Stop/stale/deleted discard cleanup, and force preflight. A real loopback curl/SSE
fixture verifies delayed success plus broken, HTTP 401, and partial HTTP 500
failures; it passed 12 consecutive stress runs. `ARCH-PURPOSE` drove the full
entry matrix, while `ARCH-DRY` moved deadline correction into the shared adapter.

### 2026-07-13 — Task 5 complete

Definition now renders an immediate selection-anchored ` ⠙` virtual spinner,
suppresses the detached luabar, and removes the transient mark before writing
the durable footnote. The generalized skill invocation terminal is exact-once
across synchronous setup failures, dispatcher abort/error, completion, cancel,
late delivery, and invalid buffers while existing Review and Voice Apply callers
retain their detached progress default. Fresh reviews approved the boundary
after malformed tool completion and every Definition-owned failure seam were
covered. `ARCH-DRY` centralizes terminal cleanup; `ARCH-PURPOSE` keeps the
selection spinner specific to Definition's natural inline anchor.

### 2026-07-13 — Task 6 complete

Mapped the new presentation boundary in README, atlas lifecycle, response
progress, web-search, inline-Definition, tool-use, provider, and traceability
documentation, then removed the orphaned buffer-progress editing API. Shadow
searches found no obsolete implementation (the sole `Submitting...` match is a
negative regression assertion). The four mapped feature groups, `make lint`,
`make test-changed`, and the full `make test` suite all exited 0; `git diff
--check origin/main...HEAD` was clean.

The noninteractive temporal smoke used real scratch-buffer extmarks, injected
production-shaped clocks, and the loopback curl/SSE process fixture. It
observed fast-answer/no-mark, delayed reveal and minimum-visible staged flush,
semantic remote-status handoff, tool recursion with the mark removed before
local execution, immediate Definition `CVR ⠙` cleanup before `CVR[^cvr]`, and
unchanged detached luabar behavior for Review. This automated substitute avoids
claiming an unavailable GUI-manual run while exercising the same user-visible
state transitions.

### 2026-07-13 — close-review correction

The mandatory boundary review reproduced a synchronous Definition cleanup leak:
payload or other setup failures after terminal registration could throw past
`skill_invoke.finish`. The invocation now protects every fallible synchronous
setup step and converges failure through the same exact-once terminal. A real
`define_visual` regression proves throwing payload preparation removes the
inline spinner, releases in-flight ownership, writes no footnote, and does not
escape to the caller. The review also corrected the durable plan's process
fixture description to enumerate only its implemented modes.
The corrected boundary passes 16 shared skill-lifecycle, 24 real Definition,
and 5 caller-teardown cases, lint, and the complete suite with `JOBS=1`; the
single-worker run avoids unrelated cross-worktree Neovim process contention.

### 2026-07-13 — moving-anchor close-review correction

The second mandatory review found that animation repaints reset chat and
Definition extmarks to their initial numeric coordinates after edits above the
anchor. Both renderers now resolve the live extmark position before repainting
and terminate on unexpected invalidation. Chat deliberately retains the current
position across its playful-to-semantic hide/recreate handoff. New real-buffer
regressions insert a line above each visible mark, advance animation, and prove
the mark remains on its tracked row. The focused boundaries pass 22 chat-pending
and 25 Definition cases; all 7 real curl/SSE cases, lint, and the complete
single-worker repository suite also exit 0.
