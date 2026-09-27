---
id: 000136
status: open
created: 2026-06-25
updated: 2026-06-25
estimate_hours:
github_issue:
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
