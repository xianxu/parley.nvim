# Chat concurrency live testing (#254)

Use the feature checkout in one Neovim instance, with disposable chats and a
small temporary directory for tool writes. Record the commit, provider, commands,
and exact edit sequence for any failure. Keep the failed chat before retrying.
These checks complement the automated event-order and filesystem fault suites.

## Human edits during streaming

1. Start a long answer with `:ParleyChatRespond`. Type the next question while it
   streams. The draft stays intact and typing, highlighting and folds stay usable.
2. Start another response at a different question. Both requests stream, but
   only one answer is written at a time: the second one's pending line names the
   answer it waits for, and its held text lands at once when the turn reaches it
   ([ownership](../../atlas/chat/ownership.md), #266). Move between both answers
   and a different window. Each answer's text stays in its own answer.
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
order even when completion order differs: each call's block lands just before its
own result, and a tool still running shows only in the pending line, never as
transcript text ([tool use](../../atlas/providers/tool_use.md#loop-model)).

Stop during tool activity: the round is written out in declared order, then the
answer ends — what each call gets is listed once in
[Stop during a tool round](../../atlas/providers/tool_use.md#stop-during-a-tool-round).
Stop during a long tool: ask for `find /`, `:ParleyStop` while it runs, then submit
again at once. The answer ends within about 2 s, `ps` shows no `find` left, and the
new submission is admitted without waiting for the old process
([Stopping a process](../../atlas/providers/tool_execution.md#stopping-a-process)).
Reload during tool activity: already-started external effects may finish; late
output cannot write into the reloaded chat. Inspect retained work with
`:ParleyToolOperations`. An effect decision must not invent process or file
cleanup. Check edited files and the reported pre-image backups directly.

## Skill file refresh

Run an editing skill on a disposable file with `autoread` enabled. Its own tool
writes should appear once at completion. Repeat while typing in the source:
your newer buffer text must survive and the result should request reconciliation.
Cancel a skill while its tools are active, then inspect disk and buffer separately;
unfinished I/O must not permit a new conflicting run or apply a late source refresh.

## Batch

1. Start `:ParleyChatRespondAll` through a chosen question. Insert a new question,
   move the cursor and switch windows. The original membership stays fixed.
2. Edit or delete a remaining question. The batch pauses without repeating a
   completed answer or substituting a neighbor. Try normal resume and the explicit
   edit-adopting `:ParleyChatResumeBatch!` separately.
3. Regenerate an existing answer, edit it while it streams, then regenerate it
   again — also after `:e!`, and after closing and reopening the chat. Each
   regeneration starts; `u` walks back to the earlier answers (#261).

## Rendering and long chats

Repeat ordinary typing and concurrent streaming near the beginning, middle and
end of a long chat, with two windows and different fold states. Unrelated folds,
view positions and colors should remain stable. Test multiline deletion across
fences separately: broad structural repair is an explicitly more expensive case,
and provisional rendering may remain conservative until repair completes.
