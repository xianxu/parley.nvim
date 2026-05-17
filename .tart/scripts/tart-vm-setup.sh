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

# ── Clone (or refresh) the host repo into ~/repo ─────────────────
# Earlier versions of this setup symlinked ~/repo to the read-only
# shared mount. That made `make build` fail inside the VM with EPERM:
# the host's bin/ outputs carried host-side xattrs (com.apple.provenance)
# and codesign state that prevented the guest from overwriting them.
# Cloning gives the VM a writable local working copy; the host mount
# stays available read-only as the clone's origin for round-trip
# refreshes.
#
# Mount path: tart exposes the shared dir at "/Volumes/My Shared
# Files/<REPO_NAME>". We glob rather than depend on $REPO_NAME being
# present in the VM env — one share per VM, so the first dir is
# unambiguous.
MOUNT=$(ls -d "/Volumes/My Shared Files"/*/ 2>/dev/null | head -1)
MOUNT=${MOUNT%/}
if [ -n "$MOUNT" ] && [ -d "$MOUNT/.git" ]; then
    # Migrate from the older symlink layout, if still in place.
    if [ -L "$HOME/repo" ]; then
        echo "==> Removing old ~/repo symlink (clone-into-VM convention now)..."
        rm "$HOME/repo"
    fi
    if [ ! -d "$HOME/repo/.git" ]; then
        echo "==> Cloning $MOUNT into ~/repo (writable local copy)..."
        rm -rf "$HOME/repo" 2>/dev/null || true
        git clone "$MOUNT" "$HOME/repo"
    elif [ -z "$(git -C "$HOME/repo" status --porcelain 2>/dev/null)" ]; then
        # Worktree clean — safe to fast-forward to match host HEAD.
        host_branch=$(git -C "$MOUNT" symbolic-ref --short HEAD 2>/dev/null || echo main)
        echo "==> ~/repo clean; refreshing to host's $host_branch..."
        git -C "$HOME/repo" fetch origin >/dev/null 2>&1 || true
        git -C "$HOME/repo" reset --hard "origin/$host_branch" >/dev/null 2>&1 \
            || echo "    (couldn't fast-update; leaving as-is)"
    else
        echo "==> ~/repo has uncommitted changes — leaving as-is."
        echo "    (commit or stash inside the VM, then re-run \`make tart\` to refresh,"
        echo "     or \`rm -rf ~/repo && exit\` to force a fresh clone on next boot.)"
    fi
elif [ -L "$HOME/repo" ]; then
    # No mount but a leftover symlink — clean up. Don't touch a real
    # directory the operator might have created; only nuke our own
    # symlink convention.
    echo "==> No shared mount found; removing stale ~/repo symlink."
    rm "$HOME/repo"
fi

echo "==> VM setup complete."
