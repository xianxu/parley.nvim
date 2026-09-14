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

## Learn by chatting

These tutorials open as editable chats in the app. You can also read their
bundled originals here:

1. [Welcome](packaging/tutorials/welcome.md) — editor essentials, connecting an
   account, choosing a model, and sending a question.
2. [Basics](packaging/tutorials/basics.md) — finding conversations, navigating the
   outline, and branching into a side question.
3. [Advanced](packaging/tutorials/advanced.md) — what the model sees, project
   folders, local tools, chat-history search, and images.

Ask Parley about a feature as you work. Its documentation tool reads the
README, tutorials, and [atlas](atlas/index.md) from your installed version.

For contributors: [development and tests](TOOLING.md), [architecture](ARCH.md),
and [code style](STYLE.md).

Parley was adapted from [gp.nvim](https://github.com/Robitx/gp.nvim) and has since
been extensively redesigned. See [LICENSE](LICENSE).
