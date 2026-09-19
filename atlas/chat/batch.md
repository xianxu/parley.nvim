# Answer a batch of questions

`:ParleyChatRespondAll` (Ctrl+g then Shift+g by default) answers the questions up
to your cursor in their captured order. Moving the cursor, switching chats, or
adding new questions does not change that selection or add them to the batch’s
later request history. You can continue editing
while answers arrive.

If a remaining question or earlier refreshed context changes, the batch pauses.
Completed answers stay completed. `:ParleyChatResumeBatch` retries after a known
failure when the captured questions and context still match.
`:ParleyChatResumeBatch!` explicitly accepts current edits before continuing.
Deleted questions are never replaced by whichever question now occupies that
position. Reload ends the old document's batch authority, and the batch says
so ("Batch stopped: the chat was reloaded"). A new `:ParleyChatRespondAll`
starts it over.

Stop cancels the selected generation and pauses its batch, without a warning:
the pause was your own doing. Cancellation may take time to finish; resume
cannot start another attempt until completion is known.
An unknown tool effect cannot be retried automatically.

A pause is said once, with how to continue (#261 M5). When the answering
response failed, that response says why, and the pause adds only the count
answered. A paused batch whose response has settled gives way to a new
`:ParleyChatRespondAll`, so a batch that can never resume (for example, one
whose question was reworded) does not block the chat. Only a running batch
refuses a new one. The words come from
[refusal.lua](../../lua/parley/refusal.lua).

## Implementation

[batch.lua](../../lua/parley/batch.lua) holds immutable membership and progress.
[batch_response.lua](../../lua/parley/batch_response.lua) validates private
Document question/context revision proofs and runs the same response Session as
single submission. Native edits, including undo and equal-text edit sequences,
invalidate affected revision proofs. Opaque structure defers admission until
repair can establish current evidence. Explicit submission materializes input;
rendering continues to use the shared incremental index.
