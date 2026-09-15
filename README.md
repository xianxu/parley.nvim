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
then `?` shows shortcuts for your current context and Parley configuration.
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

## Editing during answers

You can edit the next question while an answer streams. Editing active output
stops its writer; reloading the file invalidates its active writes.
[Question batches](atlas/chat/batch.md) keep a fixed selection, and
[answer recovery](atlas/chat/recovery.md) preserves previous answers before
regeneration.

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

Parley was adapted from [gp.nvim](https://github.com/Robitx/gp.nvim) and has since
been extensively redesigned. See [LICENSE](LICENSE).

## Concurrent tools

Builtin tools run asynchronously. Independent resources can proceed together;
conflicting file operations wait for earlier work. Capabilities, roots and tool
configuration are captured for the response. Custom tools need an `execute_async`
implementation to run in this workflow; a synchronous handler alone is refused.

Stop and reload prevent further chat writes, while the process supervisor keeps
unfinished tool effects and their resource claims. `:ParleyToolOperations` shows
retained operations and their evidence. After independently inspecting an effect,
you can record whether it happened, did not happen, or partially happened. This
never reruns it or invents process/file cleanup; conflicting work remains blocked
until cleanup is confirmed. Known tool writes preserve a checked pre-image backup.

The `tool_execution` setup table exposes finite process, resource, result and
file-work limits. Limits may be lowered; changing them while work is retained is
refused. See [tool execution](atlas/providers/tool_execution.md) for defaults,
backup behavior and cancellation guarantees.
