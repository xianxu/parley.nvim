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

Homebrew installs the pinned editor dependencies with the app. The bundled
starter opens the Welcome tutorial without downloading editor plugins; follow
it to connect an account, choose a model, and send your first question. Editor
startup and local Markdown preview work offline; provider login and AI requests
still need a connection. Existing edited profiles must adopt the new
`init.lua.new` starter to use bundled dependencies.

Your Parley editor settings and chats are separate from your existing Neovim
profile; provider logins are shared with other CLIProxyAPI clients.

See the [app guide](packaging/README.md) for updates and removal, or
[configuration and recovery](packaging/starter-config/README.md) for profile
paths and settings. Existing Neovim users can use the
[plugin setup guide](atlas/infra/config.md#install-as-a-neovim-plugin):
`require('parley').setup({})` works as is; see
[minimal config](atlas/infra/config.md#minimal-config) for typical overrides.

For Couch users, [session-sync files](atlas/modes/session_sync.md) name their
agent with `couch-owner:` (`owner:` is the legacy fallback). They ping a quiet
owner once when deliveries remain owed and its last write is at least 15 minutes
old. Set `session_sync_ping_minutes` in `require('parley').setup({...})` to
override that delay. A write postpones the ping; operator locks suppress it.
The separate `session_sync_stale_minutes` reminder for unsent edits remains 5.
The first edit in Normal or Insert mode takes your turn before auto-save runs.
Undoing back to the content before that first edit silently releases it, even
after auto-save; redo away from that baseline takes it again. Saves never move
the baseline, and saving changed text keeps the turn until Alt+Return. See the
[session-sync guide](atlas/modes/session_sync.md) for the full interaction.

Press **Alt+Shift+O** in Normal or Insert mode to return to the previous file
in the current window, restoring its cursor position. Follow links with Alt+o,
then use Alt+Shift+O repeatedly to return through answer and side documents to
your session file. A split or tab opened by a user command or Parley's openers
inherits the focused window's history and keeps its own later visits. Windows
created through APIs or RPC start with empty history. File-entry events begin
their history; Back can also establish the displayed file as their root.
See [file navigation](atlas/ui/keybindings.md#file-history-back)
for the command and configuration.

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

For local verification, run `./parley_app` from your checkout. It caches the pinned
dependencies on first launch; `--nuke` clears those dependencies while retaining
chats, settings and login. See [local launcher instructions](TOOLING.md) and the
[recording workspace guide](demo/README.md) for `--demo`.

Parley is built entirely by AI agents, so contributing works a little differently.
It uses `ariadne` as its base development layer, and everything is managed inside
this GitHub repo. For example, issue tracking is in
`./workshop/issues`. Check out [Ariadne](https://github.com/xianxu/ariadne) for
development processes. Roughly:

1. Clone this repo.
2. Run `weave compile`, which pulls the necessary base layers and compiles binaries that
   support the AI native development processes. `weave refresh` will update local clone 
   of ariadne dependencies, and current repo, then run `weave comple`.
3. Start your favorite AI coding tool: `claude`, `codex`, etc.
   I use [pair and couch](https://github.com/xianxu/pair), which provides a much
   stronger local development environment while leveraging other coding agents.

Before sending pull request, you should file an issue first, focusing on the feature
you want to create and getting alignment with maintainer first. All pull request without
agreement won't be checked. After all, in the era of AI coding, it's easy to write 
code; it's harder to agree what feature should be created.

## Report issues

Use [GitHub issues](https://github.com/xianxu/parley.nvim/issues) for feature requests
and bug reports.

## Acknowledgement

Parley was adapted from [gp.nvim](https://github.com/Robitx/gp.nvim) and has since
been redesigned so thoroughly that it bears little resemblance to it. See [LICENSE](LICENSE).

All sorts of AI coding agents were used to create Parley.


## Paste screenshots into Markdown

Press **Alt+v** in Normal or Insert mode to paste a clipboard image after the
current line in any named Markdown file. Parley inserts an image link and saves
it beside that file at `assets/<file-stem>/<timestamp>.<png|jpg>`. Chat files keep
their existing timestamp asset folders. Spaces and punctuation in stems are
percent-escaped in links; the on-disk folder keeps the stem.

The existing image shrink step runs before saving: large PNGs become smaller
JPEGs within the maximum edge. `assets.shrink` and `assets.shrink_cmd` retain
their configured behavior; the paste notice reports any retained original.
Deleting a link leaves its asset on disk. The Markdown file's owner handles
sidecar moves and sweeps unreferenced assets (the TL for session and QA files).
