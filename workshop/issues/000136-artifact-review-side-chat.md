---
id: 000136
status: open
deps: [000128, 000133]
github_issue:
created: 2026-06-25
updated: 2026-06-25
estimate_hours:
---

# artifact review as side chat transcript

## Problem

Parley's current skill/artifact path (`skill_invoke`) reuses the dispatcher and
tool execution layer from chat, but it is still a one-exchange artifact command:
assemble prompt -> query LLM -> decode tool calls -> execute `propose_edits` ->
reload/render -> call `on_done`. `review` adds its own bounded resubmit loop
around that based on remaining ready markers, not because the tool result was
fed back to the model as a continuing transcript.

That leaves an architectural mismatch with parley's original design philosophy:
LLM interaction state should be obvious, durable, and inspectable. In chat mode,
the transcript is the nvim buffer itself and tool calls/results are visible as
`🔧:` / `📎:` blocks. In artifact review mode, the interaction state is mostly
implicit/in-memory, while the artifact buffer only shows the projected result
(edits, diagnostics, journal summary).

We want artifact review to feel more like "run a side chat whose subject is this
file": the side conversation owns the LLM/tool transcript, `propose_edits`
mutates the referenced artifact, and parley projects the result back into the
artifact UI. This is closer to pair's review mode shape, where the agentic
harness owns the conversation and nvim is the embedded UX/projection layer.

And once we take this path, we are essentially recreating the pair's review mode (../pair) in parley. see pair#66 for details, pair atlas for current shape of the review mode. Pair review mode works fairly well, we just need to port the review protocol, UI treatment into parley. One benefit of it is one less dependency on a coding agent. 

## Spec

- Introduce a first-class **artifact review side transcript**: a durable,
  inspectable conversation associated with a reviewed artifact.
- The transcript is the canonical LLM interaction state for artifact review:
  prompt/context, assistant responses, tool calls, tool results, errors,
  cancellation, and continuation rounds are represented there rather than only
  in transient Lua state.
- The reviewed artifact remains the canonical document state. Tool calls such as
  `propose_edits` target that artifact, and parley projects resulting edits,
  diagnostics, highlights, and journal entries back onto the artifact buffer.
- Review invocation becomes "start/continue the artifact's side chat" rather
  than "run a hidden one-shot skill command." The model may continue across
  tool-result rounds when useful, with the transcript making that continuation
  visible.
- Preserve the useful #128 split: P1 chat and P2 artifact work still share the
  dispatcher/tool substrate, but P2 gets a transcript store instead of an
  invisible in-memory exchange.
- Reuse #133's journal ingredients where appropriate: per-round diffs, mode,
  rationale, decorations, timestamps, and drift detection. Decide during design
  whether the journal becomes the transcript itself or whether a compact journal
  indexes a fuller side transcript.
- Keep review modes and UX from #133: mode menu, free-form instruction,
  no-marker review, marker-aware review, frontier semantics, and durable history.
- Make the transcript discoverable from the artifact buffer with a direct command
  or binding. A user should be able to inspect what prompt was sent, what tool
  was called, what result came back, and why a projected edit exists.
- Avoid building a generic hidden recursive `skill_invoke` loop unless its
  transcript persistence is explicit. Recursion without visible state is a
  regression from parley's chat-buffer philosophy.
- Coordinate with #129: tool permissions should remain human-gated and
  chain-scoped. A side transcript must not accidentally turn one manual review
  invocation into ambient write authority for later unrelated turns.

## Done when

- Artifact review has a durable side transcript associated with the artifact.
- Review/tool continuation rounds can feed tool results back to the model using
  that transcript as state.
- `propose_edits` still mutates the artifact through the shared tool dispatcher,
  and the artifact UI shows projected edits/diagnostics/highlights.
- The user can open and inspect the side transcript from the artifact buffer.
- The review journal/diff history either is the transcript or is clearly linked
  to the transcript, with no duplicated source of truth.
- Existing `review` modes and no-marker review behavior continue to work.
- Permission behavior respects #129's intended model: manual review grants write
  capability only to the relevant review chain unless explicitly made sticky.

## Plan

- [ ] Decide transcript storage shape: journal-as-transcript vs separate side
      chat plus compact journal index.
- [ ] Define the artifact<->transcript association and open/discover UX.
- [ ] Design transcript adapter API for artifact review continuation rounds.
- [ ] Rework review invocation around starting/continuing the side transcript.
- [ ] Project tool results back onto the artifact buffer and journal.
- [ ] Add tests for continuation, transcript persistence, artifact projection,
      and permission scoping.

## Log

### 2026-06-25

- Filed from design discussion: option 3 ("artifact review as side chat") fits
  parley's original philosophy better than an invisible recursive skill driver.
  Key distinction: the transcript should be first-class and inspectable; nvim's
  artifact buffer is the projection surface for edits/results.
