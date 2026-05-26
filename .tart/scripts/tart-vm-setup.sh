#!/usr/bin/env bash
# tart-vm-setup.sh — VM-side bootstrap for the tart-vm-* targets.
# Pushed to the VM by the Makefile (alongside tart-vm-rc.zsh); runs
# after every `make tart`. Idempotent.
#
# Argument: $1 is the current repo name (the repo whose Makefile.workflow
# the operator invoked). Used to write the current-repo marker so the rc
# can cd into ~/workspace/<repo>/ on shell start.
set -euo pipefail

CURRENT_REPO="${1:-}"

# ── oh-my-zsh ────────────────────────────────────────────────────
# The macOS-native counterpart to openshell's oh-my-bash. Installer
# replaces ~/.zshrc with a template that activates the framework
# (default theme robbyrussell, default plugins=(git)).
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "==> Installing oh-my-zsh..."
    CHSH=no RUNZSH=no sh -c \
        "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
        "" --unattended
fi

# ── Source the extension rc from ~/.zshrc ────────────────────────
if ! grep -q tart-vm-rc.zsh "$HOME/.zshrc" 2>/dev/null; then
    cat >> "$HOME/.zshrc" <<'EOF'

# Extension rc managed by host Makefile (scripts/tart-vm-rc.zsh)
[ -f ~/.tart-vm-rc.zsh ] && source ~/.tart-vm-rc.zsh
EOF
fi

# ── Wire ~/workspace to the host's workspace mount ───────────────
# Post-ariadne#32 the host mounts a workspace-shaped APFS clone holding
# the current repo + its go.mod-declared peers (recursive replace walk)
# into the VM. The contents look like a sibling-checkout: each peer is
# a top-level dir, so Go's replace directives pointing at sibling paths
# resolve correctly inside the VM.
#
# Mount appears at /Volumes/My Shared Files/workspace; symlink
# ~/workspace there so paths like ~/workspace/parley.nvim feel
# natural to operators. The set of peers under ~/workspace is
# determined by the current repo's go.mod — not the host's full
# sibling directory.
MOUNT="/Volumes/My Shared Files/workspace"
if [ -d "$MOUNT" ]; then
    # Symlink ~/workspace → the writable share.
    if [ -d "$HOME/workspace" ] && [ ! -L "$HOME/workspace" ]; then
        echo "==> Removing old ~/workspace directory (pre-#32 artifact)..."
        rm -rf "$HOME/workspace"
    fi
    if [ ! -L "$HOME/workspace" ] || [ "$(readlink "$HOME/workspace")" != "$MOUNT" ]; then
        rm -f "$HOME/workspace"
        ln -s "$MOUNT" "$HOME/workspace"
        echo "==> Symlinked ~/workspace → $MOUNT"
    fi

    # Backward-compat: keep ~/repo pointing at the current repo inside
    # the workspace. Anything that hardcoded ~/repo (PATH entries,
    # legacy scripts) keeps working through the symlink chain.
    if [ -n "$CURRENT_REPO" ] && [ -d "$MOUNT/$CURRENT_REPO" ]; then
        if [ -d "$HOME/repo" ] && [ ! -L "$HOME/repo" ]; then
            echo "==> Removing old ~/repo directory (pre-#32 artifact)..."
            rm -rf "$HOME/repo"
        fi
        EXPECTED="$HOME/workspace/$CURRENT_REPO"
        if [ ! -L "$HOME/repo" ] || [ "$(readlink "$HOME/repo")" != "$EXPECTED" ]; then
            rm -f "$HOME/repo"
            ln -s "$EXPECTED" "$HOME/repo"
            echo "==> Symlinked ~/repo → $EXPECTED"
        fi
    fi

    # Marker file for the rc: which repo to cd into on shell start.
    if [ -n "$CURRENT_REPO" ]; then
        printf '%s\n' "$CURRENT_REPO" > "$HOME/.tart-current-repo"
    fi
elif [ -L "$HOME/workspace" ]; then
    # No mount but a leftover symlink — clean up.
    echo "==> No workspace mount found; removing stale ~/workspace symlink."
    rm "$HOME/workspace"
fi

echo "==> VM setup complete."
