# Start chatting with Parley

This profile gives Parley its own configuration, chats and account login. Your
ordinary Neovim configuration stays separate. It requires Neovim 0.11 or newer,
Git, curl, and an internet connection. macOS supplies the image clipboard tools.

Copy this release's `init.lua` to `~/.config/parley/init.lua`, then run:

```sh
NVIM_APPNAME=parley nvim
```

The first launch downloads the pinned editor plugins and opens a welcome chat.
Later launches reuse it. You can edit `init.lua` to change your settings.

1. Press Escape, type `:ParleyConnect`, and press Enter. Choose your provider and
   follow the account login in your browser. Parley downloads its managed proxy
   on first connection. You need access to the chosen provider through that account.
2. After login, use `:ParleyAgent` to choose an available model.
3. Press `i` and type a question. Press Alt+Enter to send it. If your terminal
   does not transmit Alt+Enter, press Escape and use `:ParleyChatRespond`.
4. Copy an image, then press Alt+v to attach it .
   Alt+t opens the conversation outline. Press Escape and type `:wq` to save
   and quit. Use `:ParleyChatNew` for a new conversation.

Pass a file to open it instead of the welcome chat:

```sh
NVIM_APPNAME=parley nvim 'my notes.md'
```

The starter enables no local model tools and starts with web search off. Image
attachments remain available. Login, model selection and chat commands use the
same Parley runtime as an ordinary plugin installation.

## Profile files and recovery

Neovim's standard XDG variables apply. With their default values, this profile owns:

- `~/.config/parley`: editable configuration and plugin lockfile.
- `~/.local/share/parley`: plugins, chats, exports, proxy binary and credentials.
- `~/.local/state/parley`: session state and logs.
- `~/.cache/parley`: caches and query scratch.

The managed proxy uses loopback port 8318 and a private local client key. If that
port belongs to another service, stop that service or choose another port in
your configuration. Parley will not remove a foreign listener.

A failed download cleans its own staging so restarting can retry. If an initializer
was abruptly killed, the error names its lock directory: close all Parley
instances, remove only that named initializer directory, then retry. An invalid
client key or incomplete welcome file is reported by path for explicit repair.
If a process was killed while creating its client key, it may leave a private
`.client-key-*` staging file in the data directory. After closing all Parley
instances, remove those staging files; preserve `client-key` itself. Normal
failures clean their own staging, and profile removal removes all of it.

Before removing the profile, run `:ParleyProxy stop` to stop its managed proxy.
Then remove the four profile directories above (or their configured XDG locations).
This deletes your chats and saved provider login, so keep any files you want first.
No ordinary `nvim` profile directory is part of this removal.

Maintainers verify the artifact with `python3 scripts/check-starter.py` and
`make test-spec SPEC=infra/starter`. The full `make test` runs these checks too.
