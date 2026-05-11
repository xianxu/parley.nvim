#!/usr/bin/env bash
# tart-vm-setup.sh — VM-side bootstrap for the tart-vm-* targets.
# Pushed to the VM by the Makefile (alongside tart-vm-rc.zsh); runs
# after every `make tart` / `make tart-mount`. Idempotent: skips
# work that's already done.
set -euo pipefail

# ── oh-my-zsh ────────────────────────────────────────────────────
# The macOS-native counterpart to openshell's oh-my-bash. Installer
# replaces ~/.zshrc with a template that activates the framework
# (default theme robbyrussell, default plugins=(git)).
#
# Flags:
#   --unattended  skip interactive prompts
#   CHSH=no       don't try to change login shell; admin user on
#                 cirruslabs' tahoe base image already uses zsh
#   RUNZSH=no     don't spawn an interactive zsh at install end;
#                 we'd lose control of the ssh session if it did
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "==> Installing oh-my-zsh..."
    CHSH=no RUNZSH=no sh -c \
        "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
        "" --unattended
fi

# ── Source the extension rc from ~/.zshrc ────────────────────────
# oh-my-zsh's installer replaces ~/.zshrc on first run, so this line
# gets re-appended; on subsequent runs grep finds it and the append
# is a no-op.
if ! grep -q tart-vm-rc.zsh "$HOME/.zshrc" 2>/dev/null; then
    cat >> "$HOME/.zshrc" <<'EOF'

# Extension rc managed by host Makefile (scripts/tart-vm-rc.zsh)
[ -f ~/.tart-vm-rc.zsh ] && source ~/.tart-vm-rc.zsh
EOF
fi

echo "==> VM setup complete."
