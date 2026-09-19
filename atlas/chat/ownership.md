# Chat Write Ownership

Neovim owns the text. The [document coordinator](document.md) assigns revocable
write grants over confirmed regions; an exchange number or cursor position never
authorizes a delayed write. [Response sessions](lifecycle.md#response-parleychatrespond--m-cr--c-gc-g)
capture their source before readiness and remote IO.

Generations run concurrently but write one at a time (#266). Requests stream
and tools execute in parallel; mutation is serialized by a per-document **write
turn** (`document/write_turn.lua`, held in the reducer), granted in admission
order and held for the holder's whole lifetime. It passes on terminal, stop,
pause, detach and reload — not on a transient grant suspension. A pause yields
the turn, so a resumed generation's writes start a new run. A queued
generation's output is held (one coalesced item, bounded by the 1 MiB staging
budget) and applied whole once the turn arrives; meanwhile its pending line names
the answer it is waiting for. Human edits are never subject to the turn.

A response's preparation — its answer header, and clearing a replaced answer — is
written immediately before its first write of any kind, so a response cancelled
before its first byte leaves the transcript unchanged and a regenerated answer
stays visible until something replaces it.

A tool round starts its tools at once and appends their blocks in declared
order, each call immediately before its own result, through the answer's own
grant (#266 M2); a failed call is written as an error result and the round goes
on. An edit intersecting owned output revokes the affected writer — inside a tool
round that is the whole answer, since its blocks have no grants of their own;
reload invalidates all grants from the former document epoch. A human edit to
earlier context marks captured input stale without redirecting output; another
generation's writes do not ([previous answer while
regenerating](lifecycle.md), #261).

**Undo grouping** — this page is the one statement of it; the
[target](../../workshop/targets/transcript-is-the-whole-truth.md) and plans point
here. It derives from `Editor:can_join_undo` (`document/editor.lua`), which joins
a generated write into the previous undo step only when its epoch, generation and
grant match the last write's receipt and native undo has not moved since.

- **Unconditional:** no undo step ever mixes two generations — a join requires
  the previous write's generation, so a step can never span two.
- **Conditional — while nothing intervenes:** a generation's consecutive writes
  through one grant form one undo step, with no partial 4 KiB slice. Whatever
  intervenes splits the run there, each piece still from that generation alone:
  any observed edit (human typing, undo, redo) or buffer lifecycle event (reload,
  detach, a changedtick-only update, an epoch change) clears the receipt; a write that did not fully apply clears it; and
  another generation's write breaks the match — which serialization allows only
  once the turn has moved, e.g. after a pause. Different grants — say an answer's
  main grant, then its completion prompt's — are always different steps.
  - *Tool rounds* (operator decision, #266 M2) get no deliberate break: a round's
    call and result blocks are ordinary writes through the answer's grant, so
    they join its step like its text — under this same condition. A human edit
    while the tools run (the usual case: the next question is being typed) splits
    the round where it lands, so a call block can sit one undo step before its
    own result. Each piece is still one generation's.

Only the unconditional bullet may be stated without a condition. Any other claim
about grouping belongs under the conditional one, names the event that splits it,
and ships with a test that drives that event
(`tests/integration/generation_turn_spec.lua`: a human edit between two slices of
one write, and one while a tool round runs).

Explicit user commands use captured source transactions. Each native mutation
returns an exact receipt, and interrupted commands preserve intervening human
text. Undo and redo remain native edits observed by the same coordinator.

Cancellation revokes write authority immediately — except a Stop that lands during
a tool round, which first writes the round out and only then stops
([what it writes, and what ends it early](../providers/tool_use.md#stop-during-a-tool-round)).
A stopped generation always reaches terminal and frees its slot
([A stopped response always ends](lifecycle.md#a-stopped-response-always-ends-261)).
Provider and tool cleanup
remain tracked until positive completion evidence arrives; a cancellation request
alone does not prove an effect stopped. Stop selects one generation, while
StopDocument explicitly selects every generation in the current chat.

See [response progress](response_progress.md) for the presentation lifecycle and
[tool use](../providers/tool_use.md) for ordered (call, result) insertion and effect outcomes.

`ChatResumeResponse` captures the selected session, epoch, round and input identity
before its confirmation picker. `generation_runner.resume_original` validates
those identities, a ready continuation and every live grant before accepting the
explicit original-input policy. Revoked output does not qualify. `response_status` keeps at most 256 display-only stale annotations per
buffer, using indexed identity lookup and moving extmarks; reload/detach clears
them. No source scan is part of status rendering.
