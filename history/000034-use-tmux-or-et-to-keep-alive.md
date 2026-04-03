---
id: 000034
status: done
deps: []
created: 2026-03-29
updated: 2026-04-03
---

# use tmux or et to keep alive

Terminal sessions inside the sandbox drop when SSH disconnects. Need a multiplexer to keep agent sessions alive across reconnects.

## Resolution

Chose **zellij** over tmux — simpler config, better defaults, single static binary (easy to bootstrap).

Setup:
- `bootstrap.sh` downloads `zellij-aarch64-unknown-linux-musl.tar.gz` on host
- `post-install.sh` copies binary to `~/.local/bin/zellij`
- `apply_config` in `sandbox.sh` copies `dotfiles/zellij/config.kdl` to sandbox
- Shell aliases in `setup.sh`: `ze` (launch), `za` (attach), `zl` (list sessions)
- SSH keepalive (`ServerAliveInterval 15`) in ssh config to reduce spurious disconnects

Keybinds: `Ctrl-q` as prefix (instead of tmux's `Ctrl-b`), Alt-based shortcuts for panes/tabs in normal mode.

## Done when

- [x] Multiplexer installed in sandbox
- [x] Config and keybinds applied
- [x] Sessions survive SSH disconnect and can reattach
