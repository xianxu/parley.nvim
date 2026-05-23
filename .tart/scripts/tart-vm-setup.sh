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

# ── Wire ~/repo to the host's APFS clone (ariadne#29) ────────────
# Evolution of this layout:
#
#   1. ~/repo as a SYMLINK to the read-only host share. Broke
#      `make build` inside the VM with EPERM — host xattrs
#      (com.apple.provenance) and codesign state on bin/ outputs
#      blocked guest writes.
#
#   2. ~/repo as a GIT CLONE of the share. Picked up committed host
#      changes but missed uncommitted edits — the dev-iteration
#      workflow needs uncommitted-too.
#
#   3. ~/repo as an rsync-delete copy of the share. Worked, but
#      ~5–10s at boot, linear in repo size.
#
# Current (ariadne#29): the host prepares an APFS clone (cp -cR)
# of $(CURDIR) at /tmp/<vm>-clone, strips the xattr-cursed bin/
# dirs, and mounts THAT as the VM's writable share. APFS clonefile
# is O(1) at boot regardless of repo size; writes from the VM
# diverge into the clone via COW without touching the host source.
#
# VM side: ~/repo is now a symlink straight to the writable share.
# No rsync — the share IS the writable area.
MOUNT=$(ls -d "/Volumes/My Shared Files"/*/ 2>/dev/null | head -1)
MOUNT=${MOUNT%/}
if [ -n "$MOUNT" ] && [ -d "$MOUNT/.git" ]; then
    # Symlink ~/repo → the writable share.
    # If ~/repo exists as a real dir (left over from rsync-era
    # bootstrap), wipe it first — its content is stale anyway, and
    # the symlink convention is now the single source of truth.
    if [ -d "$HOME/repo" ] && [ ! -L "$HOME/repo" ]; then
        echo "==> Removing old ~/repo directory (rsync-era artifact; symlink convention now)..."
        rm -rf "$HOME/repo"
    fi
    if [ ! -L "$HOME/repo" ] || [ "$(readlink "$HOME/repo")" != "$MOUNT" ]; then
        rm -f "$HOME/repo"
        ln -s "$MOUNT" "$HOME/repo"
        echo "==> Symlinked ~/repo → $MOUNT (APFS-cloned writable share)"
    fi
elif [ -L "$HOME/repo" ]; then
    # No mount but a leftover symlink — clean up. Don't touch a real
    # directory the operator might have created; only nuke our own
    # symlink convention.
    echo "==> No shared mount found; removing stale ~/repo symlink."
    rm "$HOME/repo"
fi

echo "==> VM setup complete."
