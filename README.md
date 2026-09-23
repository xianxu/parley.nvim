# Parley

<!-- parley:introduction:start -->
Parley is a workspace for exploring ideas with AI. Conversations live in local
Markdown files that you can edit, search, and keep. Ask different models in the
same conversation, revise earlier text, add private notes, and branch a side
question into a linked chat without losing the main thread.

The Parley app brings this workflow to a dedicated Neovim environment. You do
not need an existing Neovim setup; the built-in tutorials teach the few editor
controls needed to get started. Parley is also available as a Neovim plugin.

Connect a provider account and choose a model. Sending a question shares the
conversation context and included attachments with that provider. Parley can
consult its installed documentation when you ask how a feature works; Ctrl+g
then `?` shows shortcuts for your current context and Parley configuration. In a
transcript, `ae` is a text object for whatever the cursor is in — a markdown
section, a paragraph, or a whole question-and-answer exchange — so `dae`
deletes it, `yae` yanks it and `cae` changes it. `ie` selects the inner form
(a section without its heading, a question without its answer), and `aE`
extends the range through the end of the answer. If you would rather not
think in text objects, `Ctrl+g k` deletes the entity at the cursor and
`Ctrl+g K` deletes through the end of the question; the same two actions are
available as `:ParleyDeleteEntity` and `:ParleyDeleteToEnd`.
<!-- parley:introduction:end -->

## Install the app

The recommended starting point is the **Parley app for macOS**, installed with
[Homebrew](https://brew.sh/):

```sh
brew install xianxu/parley/parley
parley
```

The first launch installs editor dependencies and opens the Welcome tutorial.
Follow it to connect an account, choose a model, and send your first question.
Your Parley editor settings and chats are separate from your existing Neovim
profile; provider logins are shared with other CLIProxyAPI clients.

See the [app guide](packaging/README.md) for updates and removal, or
[configuration and recovery](packaging/starter-config/README.md) for profile paths
and settings. Existing Neovim users can use the
[plugin setup guide](atlas/infra/config.md#install-as-a-neovim-plugin).

## Editing while an answer is generated

You can write the next question while one or more answers stream elsewhere in
this chat. Their requests run at the same time, but answers are written one at a
time: a later answer waits, showing which answer it is waiting for, then appears
in full once the earlier one finishes or pauses — so an undo step never mixes two
answers. An answer's header appears with its first output; regenerating keeps the
old answer visible until the new one starts arriving. Editing generated output
preserves your edit and stops that region's writer. Deleting an exchange
invalidates its writers; reloading the file invalidates all active writes. Undo
and redo remain native Neovim edits and can also revoke a writer; undo does not
restart a cancelled request.

Changing earlier input leaves an in-flight request on its original input. A
visible **input changed** note stays with the answer for this editor session.
A tool continuation pauses rather than silently combining edited input with
previous results. Use `:ParleyChatResumeResponse` to select and confirm continuing
with the **original input and confirmed tool results**, or stop and generate a
new answer. Edited output cannot regain its old write permission through resume.
The stale note clears when a fresh response starts or the file is reloaded.

- `:ParleyStop` cancels the response under the cursor. If none is selected, it
  offers the active responses in this chat. Cancelling the picker changes nothing.
- `:ParleyStopDocument` cancels all responses in the current chat.
- A tool round's tools run at once, but each call is written immediately before
  its own result, in the order the model asked for them; the status line counts
  the tools still running. A failed call is written as an error result and the
  answer goes on. Stopping during a tool round cancels its running tools and
  still writes the round out before the answer ends; what each call's result
  says, and what ends that early, is in
  [Stop during a tool round](atlas/providers/tool_use.md#stop-during-a-tool-round).
  Stopping does not undo an external effect.

These controls apply to concurrent work in one Neovim instance.

[Question batches](atlas/chat/batch.md) keep a fixed selection.

## Learn by chatting

These tutorials open as editable chats in the app. You can also read their
bundled originals here:

1. [Welcome](packaging/tutorials/welcome.md) — editor essentials, connecting an
   account, choosing a model, and sending a question.
2. [Basics](packaging/tutorials/basics.md) — finding conversations, navigating the
   outline, and branching into a side question.
3. [Advanced](packaging/tutorials/advanced.md) — what the model sees, project
   folders, local tools, chat-history search, and images.

To label a question in the outline, put `@@label@@` immediately above its question
line, with no blank line between them. `@@_@@` hides that question from the outline.
Both forms remain in AI context as a preface to the following question.

Ask Parley about a feature as you work. Its documentation tool reads the
README, tutorials, and [atlas](atlas/index.md) from your installed version.

For contributors: [development and tests](TOOLING.md), [architecture](ARCH.md),
and [code style](STYLE.md).
If an interrupted test run leaves processes behind, see the
[process census and cleanup command](TOOLING.md#orphaned-test-processes).

Parley was adapted from [gp.nvim](https://github.com/Robitx/gp.nvim) and has since
been extensively redesigned. See [LICENSE](LICENSE).

## Concurrent tools

Builtin tools run asynchronously. Independent resources can proceed together;
conflicting file operations wait for earlier work. Capabilities, roots and tool
configuration are captured for the response. A custom `execute_async` that
starts a process through `context.tasker.run` passes `context.logical_generation`
along, so the process is stopped with the response; a process with neither that
nor a `deadline_ms` is refused. Custom tools need an `execute_async`
implementation to run in this workflow; a synchronous handler alone is refused.

Reload prevents further chat writes, and so does Stop once it has written out a
tool round in progress. A stopped tool's process is ended — SIGTERM, then SIGKILL
2 s later ([Stopping a
process](atlas/providers/tool_execution.md#stopping-a-process)) — and the process
supervisor holds its resource claims until it has ended. A tool whose process has
ended holds nothing, even when its outcome is unknown: it is reported to the
model as a failure. `:ParleyToolOperations` shows
retained operations and their evidence. After independently inspecting an effect,
you can record whether it happened, did not happen, or partially happened. This
never reruns it or invents process/file cleanup; conflicting work remains blocked
until cleanup is confirmed. Known tool writes preserve a checked pre-image backup.

The `tool_execution` setup table exposes finite process, resource, result and
file-work limits. Limits may be lowered; changing them while work is retained is
refused. See [tool execution](atlas/providers/tool_execution.md) for defaults,
backup behavior and cancellation guarantees.
