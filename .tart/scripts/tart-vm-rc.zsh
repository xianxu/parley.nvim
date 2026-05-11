# tart-vm-rc.zsh — shell enrichments for the tart VM admin user.
#
# Mirrors the portable, daily-useful pieces of ariadne's
# .openshell/overlay/setup.sh, ported from bash → zsh (the macOS
# default). oh-my-zsh itself is installed by tart-vm-setup.sh on
# first VM boot (the zsh counterpart to openshell's oh-my-bash,
# which only existed because the Linux sandbox base image was bash).
#
# What's deliberately not ported:
#   - output capture via script(1) + DEBUG trap: would need a port
#     to zsh's preexec/precmd hooks; deferred
#   - Linux ARM64 nvim/zellij binaries: VM is macOS
#   - AI-agent aliases (claude/codex): VMs aren't where we run agents
#
# Pushed to ~/.tart-vm-rc.zsh on first `make tart`; sourced from
# the VM's ~/.zshrc AFTER oh-my-zsh's source line (so this rc gets
# the last word on aliases/keybindings). Edit on the host, re-push
# on next make tart.

# PATH: ~/.local/bin first for any operator-installed tools.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

# Editor preference. Fallback to vi (always present on macOS); the
# operator can override to nvim once they `brew install neovim` in
# the VM.
export EDITOR="${EDITOR:-vi}"
export VISUAL="${VISUAL:-vi}"

# Vi mode for command-line editing — matches host openshell setup.
bindkey -v
# Preserve incremental history search on Ctrl+R / Ctrl+S even in vi mode.
bindkey '^R' history-incremental-search-backward
bindkey '^S' history-incremental-search-forward

# Git workflow aliases — parity with .openshell/overlay/setup.sh.
alias s='git status'
alias ss='git diff --stat'
alias a='git add'
alias d='git diff'
alias p='git commit -a && git push'

# Editor shortcut. Single keystroke to open whatever $EDITOR is.
alias v='${EDITOR}'

# Repo shortcut: ~/repo is the symlink to the mounted host tree
# (created by the make tart-mount path); cd straight in.
if [ -L "$HOME/repo" ] || [ -d "$HOME/repo" ]; then
    alias repo='cd $HOME/repo'
fi
