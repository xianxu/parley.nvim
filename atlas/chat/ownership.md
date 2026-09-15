# Chat Write Ownership

Neovim owns the text. The [document coordinator](document.md) assigns revocable
write grants over confirmed regions; an exchange number or cursor position never
authorizes a delayed write. [Response sessions](lifecycle.md#response-parleychatrespond--m-cr--c-gc-g)
capture their source before readiness and remote IO.

Disjoint generations may write separate answers while the human edits the next
question. Each tool round reserves ordered result slots before starting effects.
An edit intersecting owned output revokes the affected writer; reload invalidates
all grants from the former document epoch. Earlier context edits mark captured
input stale without redirecting output.

Explicit user commands use captured source transactions. Each native mutation
returns an exact receipt, and interrupted commands preserve intervening human
text. Undo and redo remain native edits observed by the same coordinator.

Cancellation revokes write authority immediately. Provider and tool cleanup
remain tracked until positive completion evidence arrives; a cancellation request
alone does not prove an effect stopped. Stop selects one generation, while
StopDocument explicitly selects every generation in the current chat.

See [response progress](response_progress.md) for the presentation lifecycle and
[tool use](../providers/tool_use.md) for ordered child slots and effect outcomes.

`ChatResumeResponse` captures the selected session, epoch, round and input identity
before its confirmation picker. `generation_runner.resume_original` validates
those identities, a ready continuation and every live grant before accepting the
explicit original-input policy. Unknown child outcomes and revoked output do not
qualify. `response_status` keeps at most 256 display-only stale annotations per
buffer, using indexed identity lookup and moving extmarks; reload/detach clears
them. No source scan is part of status rendering.
