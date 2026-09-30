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

Homebrew installs the pinned editor dependencies with the app. The bundled
starter opens the Welcome tutorial without downloading editor plugins; follow
it to connect an account, choose a model, and send your first question. Editor
startup and local Markdown preview work offline; provider login and AI requests
still need a connection. Existing edited profiles must adopt the new
`init.lua.new` starter to use bundled dependencies.

Your Parley editor settings and chats are separate from your existing Neovim
profile; provider logins are shared with other CLIProxyAPI clients.

See the [app guide](packaging/README.md) for updates and removal, or
[configuration and recovery](packaging/starter-config/README.md) for profile paths
and settings. Existing Neovim users can use the
[plugin setup guide](atlas/infra/config.md#install-as-a-neovim-plugin).

In the packaged app, `:ParleyTheme` opens a floating preview for the
included themes, including all OneDark styles and Nightfox variants.
Nordfox is the startup theme; press Enter to persist another
choice or Escape to restore the opening colorscheme.
The app's bottom bar clearly shows NORMAL, INSERT or VISUAL mode, the chat
name, model/activity and cursor position, using the selected theme.

The packaged app also supports **Option+f** to find chats and **Option+n** to
create a new chat in Normal and Insert mode (Alt on other keyboards).

In chat and Markdown buffers, **Option+p** inserts a new private-note line
starting with `🔒:` and leaves you typing after the prefix. It works in Normal
and Insert mode. Configure the binding with `chat_shortcut_private_note` and
the prefix with `chat_local_prefix`. Chat pruning remains on **Ctrl+g b**;
Option+p now inserts private notes instead of pruning.
In regular chat buffers, pressing Return continues the private-note prefix on
the next line, so you can keep taking notes across multiple lines. Delete the
new prefix to resume ordinary text. Prompt buffers keep Return-to-submit.

To try the app from a checkout, run `./parley_app`. It loads the local starter
outside repo mode, using a separate demo home and profile. Subsequent launches
reuse that demo's chats and login. Python 3 provisions a bundle from the same
checksummed dependency manifest as Homebrew, then verifies it before each launch.
Initial provisioning needs a connection; a verified existing bundle can launch
offline. Its location is printed at startup; set `PARLEY_DEMO_DIR` to another directory to test a new profile.
Use `./parley_app --tutorials` to edit `packaging/tutorials/` directly through
the app. `./parley_app --nuke` clears its downloaded editor dependencies and exits;
the next launch downloads the pinned set again with terminal progress. Chats,
settings and login are retained. Local code edits are loaded directly from the
checkout on every launch; they do not require clearing dependencies.

For a recording setup, use `./parley_app --demo`. Its separate configuration
lives in [`demo/init.lua`](demo/init.lua); a disposable nested workspace opens
an empty chat with Screenkey enabled. The recording profile adds Screenkey from
the same manifest; it is not a shipped app dependency. `--demo --reset` clears
chats and editor state while retaining plugins and login; `--demo --nuke` clears
only downloaded dependencies. See [demo instructions](demo/README.md) for reset scope and asciinema.

Select text and press **Option+i** to start a linked follow-up chat. The draft
quotes your selection and leaves the cursor on an empty line beneath it.

## Editing while an answer is generated

You can write the next question while one or more answers stream elsewhere in
this chat. Their requests run at the same time, but answers are written one at a
time: a later answer waits, showing which answer it is waiting for, then appears
in full once the earlier one finishes or pauses — so an undo step never mixes two
answers. An answer's header appears with its first output. An accepted refresh
removes the old answer immediately, while keeping its complete content in memory
for concurrent questions until the replacement finishes. Submitting a question
that is already generating leaves its current response running. Editing generated output
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
4. [VIM Basics](packaging/tutorials/vim-basics.md) — modes, Back/Forward navigation,
   undo/redo, smart search, selection, clipboard editing, and saving.

In chat Insert mode, typing `@@` inserts `@@@@` with the cursor between the pairs.
Type the label, then type `@@` to move past the existing closing pair. Existing
Insert-mode `@` mappings take precedence. Disable pairing with
`chat_shortcut_pair_at = { shortcut = {} }`. The app explicitly enables this shortcut.

To label a question in the outline, put `@@label@@` immediately above its question
line, with no blank line between them. The outline shows `💬: label` (or your
configured question prefix). `@@_@@` hides that question from the outline.
Whole-line outline tags are local only: the entire tag line is excluded from
model context, including history. File/URL references such as `@@./notes.md@@`
still attach context; inline mentions and fenced examples remain literal.

The app also suggests words from the current buffer after two typed characters.
Use Tab/Down or Up to select, Enter to accept and Esc to dismiss. With no menu,
these keys keep their normal behavior. Ctrl-n/p, Ctrl-y and Ctrl-e also work. See [word completion](packaging/starter-config/README.md#complete-words-while-typing).

## Spelling suggestions

Spelling corrections appear after a short pause over a misspelling in
Normal or Insert mode. They replace the whole word, even from its middle, and
include short words such as `teh`. Tab/Down and Up select, Enter accepts the
selected or first item, and Esc dismisses without leaving the current mode.
No text changes until acceptance; with no spelling menu, these keys keep their
prior behavior. Esc suppresses suggestions on that word until you leave or
change it; `:lua require('parley.spell_blink').request()` requests them again.

The app includes this spelling integration. Plugin users need Blink **v1.10.2**
(commit `78336bc89ee5365633bcf754d93df01678b5c08f`) installed and loaded through
their plugin manager. For a fresh setup, initialize Blink before Parley:

```lua
require("blink.cmp").setup({
  fuzzy = { implementation = "lua" },
  sources = { default = { "buffer" } },
})
require("parley").setup({
  chat_spell = { blink = true, enable = true, debounce_ms = 180 },
})
```

If Blink is already configured, keep its provider list; Parley adds spelling to
it. `chat_spell.blink` defaults to `true` and activates once Blink is ready.
`enable` independently controls underlines. Missing or delayed Blink setup leaves
chats usable; the legacy Insert popup remains opt-in with `typeahead = true`
and `min_word = 4`. Blink spelling has no minimum word length, defaults to nine
suggestions and caps the count at twenty. See [spelling configuration and
limits](atlas/chat/spell_typeahead.md) for fallback, Unicode handling and
completion ownership.

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
