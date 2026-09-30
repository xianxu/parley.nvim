# Parley

<!-- parley:introduction:start -->
Parley is a workspace for exploring ideas with AI. Conversations live in local
Markdown files that you can edit, search, and annotate. Ask different models in the
same conversation, revise earlier text, and add private notes as you learn. You can
tweak your questions and ask again if an answer is unsatisfactory; you can edit
the answer itself and delete AI slop, which improves subsequent answers. You
can start a side question anytime in a branched chat, and navigate back with the
outline without losing track.

The **Parley app** packages this workflow as a standalone Neovim app that is easy
to install. You do not need an existing Neovim setup; the built-in tutorials teach
the few editor controls needed to get started.
<!-- parley:introduction:end -->

[![Parley in action](docs/media/parley-nvim-v1.gif)](https://xianxu.dev/2026/09/parley-nvim-v1/)

*Parley in action. The full walkthrough is in [the launch post](https://xianxu.dev/2026/09/parley-nvim-v1/).*

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
[configuration and recovery](packaging/starter-config/README.md) for profile
paths and settings. Existing Neovim users can use the
[plugin setup guide](atlas/infra/config.md#install-as-a-neovim-plugin).

## Learn by chatting

These tutorials open as editable chats in the app. You can also read their
bundled originals here.

1. [Welcome](packaging/tutorials/welcome.md) — editor essentials, connecting an
   account, choosing a model, and sending a question.
2. [Basics](packaging/tutorials/basics.md) — finding conversations, navigating the
   outline, and branching into a side question.
3. [Advanced](packaging/tutorials/advanced.md) — what the model sees, project
   folders, local tools, chat-history search, and images.
4. [VIM Basics](packaging/tutorials/vim-basics.md) — modes, Back/Forward navigation,
   undo/redo, smart search, selection, clipboard editing, and saving.

As an AI-enhanced learning tool, Parley can teach you about Parley itself: it
ships its own help and points the model at it. Try asking Parley about a feature as you work. Its documentation tool reads the
README, tutorials, and [atlas](atlas/index.md) from your installed version.

## Contribute to Parley

Parley is built entirely by AI agents, so contributing works a little differently.
It uses `ariadne` as its base development layer, and everything is managed inside
this GitHub repo. For example, issue tracking is in
`./workshop/issues`. Check out [Ariadne](https://github.com/xianxu/ariadne) for
development processes. Roughly:

1. Clone this repo.
2. Run `weave compile`, which pulls the necessary base layers and compiles binaries that
   support the AI native development processes.
3. Start your favorite AI coding tool: `claude`, `codex`, etc.
   I use [pair and couch](https://github.com/xianxu/pair), which provides a much
   stronger local development environment while leveraging other coding agents.

## Report issues

Use [GitHub issues](https://github.com/xianxu/parley.nvim/issues) for feature requests
and bug reports.

## Acknowledgement

Parley was adapted from [gp.nvim](https://github.com/Robitx/gp.nvim) and has since
been redesigned so thoroughly that it bears little resemblance to it. See [LICENSE](LICENSE).

All sorts of AI coding agents were used to create Parley.

