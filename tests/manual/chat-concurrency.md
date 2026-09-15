# Chat concurrency live testing (#254)

Use the feature checkout in one Neovim instance, with disposable chats and a
small temporary directory for tool writes. Record the commit, provider, commands,
and exact edit sequence for any failure. Keep the failed chat before retrying.
These checks complement the automated event-order and filesystem fault suites.

## Human edits during streaming

1. Start a long answer with `:ParleyChatRespond`. Type the next question while it
   streams. The draft stays intact and typing, highlighting and folds stay usable.
2. Start another response at a different question. Move between both answers and
   a different window. Each stream stays in its own answer.
3. Edit generated text directly. Your edit survives and that writer stops;
   independent responses continue. Undo/redo must not resurrect the old writer.
4. Delete a selection spanning an answer, several whole exchanges and part of the
   next question. No late output may recreate deleted text or attach to a neighbor.
   Repeat with a header, fence delimiter, and separator left partially deleted.
5. Reload the chat during generation. Old callbacks must not write into the
   reloaded buffer. Start a fresh response to verify new ownership can be acquired.

## Stop and changed input

- `:ParleyStop` targets the response under the cursor, otherwise offers a picker.
  Cancelling the picker leaves work running. `:ParleyStopDocument` stops the chat.
- Edit consumed earlier input while a tool response is running. Its answer shows
  changed-input status and continuation pauses. `:ParleyChatResumeResponse` asks
  to continue with original input and confirmed results. Switch buffers while the
  decision is open: it must still address the captured response.
- Editing only the next draft must not produce changed-input status on an earlier
  response. Editing the active answer must prevent resuming its revoked writer.

## Concurrent tools

Ask for independent reads or writes in the temporary directory in one tool round.
Try overlapping writes to the same file in a separate round. Independent work
can overlap; conflicting effects serialize. Results keep provider declaration
order even when completion order differs. Pending slots never claim success.

Stop or reload during tool activity. Already-started external effects may finish;
late output cannot overwrite the chat. Inspect retained work with
`:ParleyToolOperations`. An effect decision must not invent process or file
cleanup. Check edited files and the reported pre-image backups directly.

## Batch and answer recovery

1. Start `:ParleyChatRespondAll` through a chosen question. Insert a new question,
   move the cursor and switch windows. The original membership stays fixed.
2. Edit or delete a remaining question. The batch pauses without repeating a
   completed answer or substituting a neighbor. Try normal resume and the explicit
   edit-adopting `:ParleyChatResumeBatch!` separately.
3. Regenerate an existing answer, then stop midway. Use `:ParleyAnswerRecovery`
   to inspect/export the original and `:ParleyAnswerRestore` to restore it.
4. Edit the replacement before restoring; verify the preview and confirmation.
   Edit again while a picker is open; stale selection must not overwrite it.
5. Save a successful replacement. Its confirmed recovery copy can be cleaned up.
   Closing a buffer alone must not delete a needed recovery copy.

## Rendering and long chats

Repeat ordinary typing and concurrent streaming near the beginning, middle and
end of a long chat, with two windows and different fold states. Unrelated folds,
view positions and colors should remain stable. Test multiline deletion across
fences separately: broad structural repair is an explicitly more expensive case,
and provisional rendering may remain conservative until repair completes.
