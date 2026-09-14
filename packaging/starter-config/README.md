# Start chatting with Parley

This profile gives Parley its own configuration, chats and account login. Your
ordinary Neovim configuration stays separate. It requires Neovim 0.11 or newer,
Git, curl, and an internet connection. macOS supplies the image clipboard tools.

Copy this release's `init.lua` to `~/.config/parley/init.lua`, then run:

```sh
NVIM_APPNAME=parley nvim
```

The first launch downloads the pinned editor plugins and opens `chats/welcome.md`
with setup instructions and an example question. Later launches reuse it. The
app uses its own chat folder, separate from ordinary Neovim. Existing chats in
the old `chats/welcome/` folder move into `chats/` with their attachments.
You can edit `init.lua` to change your settings.

1. If no account is connected, the floating provider picker opens automatically.
   Type to filter, select your provider, and press Enter. Then
   follow the account login in your browser. Parley downloads its managed proxy
   on first connection. You need access to the chosen provider through that account.
2. After login, choose a model in the picker. A saved model selection is reused.
   You can reopen these prompts with `:ParleyProxy connect` and `:ParleyAgent`.
3. Press `i` and type a question. Press Alt+Enter to send it. If your terminal
   does not transmit Alt+Enter, press Escape and use `:ParleyChatRespond`.
4. Copy an image, then press Alt+v to attach it .
   Alt+t opens the conversation outline. Press Escape and type `:wq` to save
   and quit. Use `:ParleyChatNew` for a new conversation.

The starter keeps all Ctrl+g-prefixed shortcuts and Alt chords, plus finder-local
controls such as Ctrl+d to delete the selected chat after confirmation. Press Ctrl+g,
then `f` to find chats, `c` to create one, or `?` for shortcut help. Press Ctrl+g
twice to send. Other global/editor shortcut families remain disabled.

Pass a file to open it instead of the welcome chat:

```sh
NVIM_APPNAME=parley nvim 'my notes.md'
```

The starter disables chat memory summaries and preference generation by default.
It enables the registered local tools and web search. Answer-style 📝 summaries
remain enabled independently of automatic memory generation. In a project marked by `.parley`, file tools stay inside that
project by default. Relative file-tool paths start at the repo root: `notes.md`
means a file directly inside the folder containing `.parley`, not inside
`workshop/parley`. Outside repo mode, tools use the chat directory. Peer folders are not
granted automatically. Ask for these actions directly—no configuration is needed. Ask “What is Parley, and how do I use it?” for an introduction;
the model can consult this release’s README, tutorials, and atlas for further details. Image
attachments remain available. Login, model selection and chat commands use the
same Parley runtime as an ordinary plugin installation.

## Profile files and recovery

Neovim's standard XDG variables apply. With their default values, this profile owns:

- `~/.config/parley`: editable configuration and plugin lockfile.
- `~/.local/share/parley`: plugins, chats, exports and proxy binary.
- `~/.local/state/parley`: session state and logs.
- `~/.cache/parley`: caches and query scratch.

Provider logins live in the shared `~/.cli-proxy-api` directory, outside this
profile. Both the app and plugin use it. On upgrade, legacy profile credentials
are copied there without replacing existing accounts; originals are retained.

The managed proxy uses loopback port 8317 and API key `parley-local`, matching
`define`'s defaults. Start Parley and connect your account, then run `define`
on the same computer without additional environment variables. If that
port belongs to another service, stop that service or choose another port in
your configuration. Parley will not remove a foreign listener.

A failed download cleans its own staging so restarting can retry. If an initializer
was abruptly killed, the error names its lock directory: close all Parley
instances, remove only that named initializer directory, then retry. An invalid
welcome file is reported by path for explicit repair. Older releases' `client-key`
files are no longer read; existing files can be left in place.

When upgrading from the port-8318 release, run `:ParleyProxy stop` in the old
Parley session before upgrading, then close and reopen Parley. Remove any
`DEFINE_LLM_BASE_URL` and `DEFINE_LLM_API_KEY` overrides to use `define`'s defaults.

Before removing the profile, run `:ParleyProxy stop` to stop its managed proxy.
Then remove the four profile directories above (or their configured XDG locations).
This deletes your app settings and chats, so keep any files you want first.
Shared provider logins in `~/.cli-proxy-api` remain intact and may still be used
by your Neovim plugin or another proxy client. No ordinary `nvim` profile
directory is part of this removal.

Maintainers verify the artifact with `python3 scripts/check-starter.py` and
`make test-spec SPEC=infra/starter`. The full `make test` runs these checks too.

## Test the release profile from a checkout

From the repository root, run:

```sh
NVIM_APPNAME=parley PARLEY_RUNTIME="$PWD" nvim -u "$PWD/packaging/starter-config/init.lua"
```

This loads the working checkout with the release profile and its pinned plugin
dependencies, without Homebrew or copying a configuration file. It uses your
existing Parley chats and login. The first launch may download missing plugins.
The profile bootstrap lives in `packaging/starter-config/init.lua`; its options
come from `lua/parley/starter_config.lua`, layered over the plugin defaults in
`lua/parley/config.lua`.

LLM actions prompt for connection if necessary, then select an available model
from that provider. After selection the pending action resumes. Cancelling setup
cancels the action; changing its source while setup is open requires a retry.
Use `:ParleyProxy connect` to connect another account explicitly.

## Preview Markdown in a browser

The app includes `iamcco/markdown-preview.nvim`, pinned with the other editor
plugins. In a Markdown chat, run `:MarkdownPreview` to open a live browser preview.
Use `:MarkdownPreviewToggle` to toggle it and `:MarkdownPreviewStop` to stop it.
Preview starts only when requested and listens on localhost.

First installation downloads the upstream prebuilt preview server; Node and Yarn
are not required. A failed install can be retried with
`:Lazy build markdown-preview.nvim`. The preview renders Markdown, so Parley's
chat markers remain visible as text. This is an app dependency; installing the
parley.nvim plugin alone does not install MarkdownPreview.
