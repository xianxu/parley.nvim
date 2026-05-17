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

# ── Mirror the host repo into ~/repo (always fresh) ──────────────
# Two earlier layouts and why neither stuck:
#
#   1. ~/repo as a SYMLINK to the read-only host share. Broke
#      `make build` inside the VM with EPERM — host xattrs
#      (com.apple.provenance) and codesign state on bin/ outputs
#      blocked guest writes.
#
#   2. ~/repo as a GIT CLONE of the share, with fast-forward to
#      host HEAD on subsequent boots. Picked up *committed* host
#      changes but missed uncommitted-and-untracked edits — exactly
#      what the operator usually wants to test in the VM before
#      committing.
#
# Current layout: rsync --delete mirror. ~/repo is a writable byte-
# for-byte copy of the host worktree (including .git, uncommitted
# edits, and untracked files), refreshed on every `make tart`. The
# VM is purely a slave; any VM-local changes to ~/repo are wiped on
# next boot. Use ~/ outside ~/repo (e.g. ~/workspace/, ~/brain-*) for
# anything you want to persist across boots.
#
# Mount path: tart exposes the shared dir at "/Volumes/My Shared
# Files/<REPO_NAME>". Glob rather than depend on $REPO_NAME being in
# the VM env — one share per VM, so the first dir is unambiguous.
#
# Excludes: build outputs (host arch may match VM arch, but host
# binaries carry codesign state that blocks guest re-codesign on
# rebuild) and ariadne setup-state files. Override by editing this
# block — operators with extra paths to exclude per repo should add
# them here in a follow-up.
MOUNT=$(ls -d "/Volumes/My Shared Files"/*/ 2>/dev/null | head -1)
MOUNT=${MOUNT%/}
if [ -n "$MOUNT" ] && [ -d "$MOUNT/.git" ]; then
    # Migrate from older layouts: symlink → wipe; git clone → rsync
    # will reconcile via --delete.
    if [ -L "$HOME/repo" ]; then
        echo "==> Removing old ~/repo symlink (rsync-mirror convention now)..."
        rm "$HOME/repo"
    fi
    mkdir -p "$HOME/repo"
    echo "==> Mirroring host → ~/repo (always fresh; includes uncommitted edits)..."
    rsync -a --delete \
        --exclude='/bin/' \
        --exclude='cmd/*/bin/' \
        --exclude='/.nous-mode' \
        --exclude='/.nous-plugins' \
        "$MOUNT/" "$HOME/repo/"
elif [ -L "$HOME/repo" ]; then
    # No mount but a leftover symlink — clean up. Don't touch a real
    # directory the operator might have created; only nuke our own
    # symlink convention.
    echo "==> No shared mount found; removing stale ~/repo symlink."
    rm "$HOME/repo"
fi

echo "==> VM setup complete."
