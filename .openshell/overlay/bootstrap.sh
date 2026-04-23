#!/bin/bash
# Host-side download of sandbox dependencies.
# Downloads everything locally (fast, no proxy), then mutagen syncs to sandbox.
# Run from host before sandbox post-install.
set -euo pipefail

# BOOTSTRAP_DIR passed by sandbox.sh (avoids symlink resolution issues).
# Fallback: derive from script location (works when overlay/ is not a symlink).
BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/.openshell/.bootstrap}"

mkdir -p "$BOOTSTRAP_DIR"

# Skip if already bootstrapped
if [ -f "$BOOTSTRAP_DIR/.done" ]; then
    echo "==> Bootstrap cache exists, skipping downloads."
    exit 0
fi

echo "==> Downloading sandbox dependencies to host..."

# ── Neovim ────────────────────────────────────────────────────────────────────
download_neovim() {
    if [ ! -d "$BOOTSTRAP_DIR/nvim-linux-arm64" ]; then
        echo "  [dl] Neovim 0.11.6..."
        curl -fsSL https://github.com/neovim/neovim/releases/download/v0.11.6/nvim-linux-arm64.tar.gz \
            | tar xz -C "$BOOTSTRAP_DIR"
    else
        echo "  [ok] Neovim"
    fi
}

# ── Zellij ────────────────────────────────────────────────────────────────────
download_zellij() {
    if [ ! -f "$BOOTSTRAP_DIR/zellij" ]; then
        echo "  [dl] Zellij..."
        curl -fsSL https://github.com/zellij-org/zellij/releases/latest/download/zellij-aarch64-unknown-linux-musl.tar.gz \
            | tar xz -C "$BOOTSTRAP_DIR"
    else
        echo "  [ok] Zellij"
    fi
}

# ── Oh My Bash ────────────────────────────────────────────────────────────────
download_ohmybash() {
    if [ ! -d "$BOOTSTRAP_DIR/oh-my-bash" ]; then
        echo "  [dl] Oh My Bash..."
        mkdir -p "$BOOTSTRAP_DIR/oh-my-bash"
        curl -fsSL https://github.com/ohmybash/oh-my-bash/archive/refs/heads/master.tar.gz \
            | tar xz --strip-components=1 -C "$BOOTSTRAP_DIR/oh-my-bash"
    else
        echo "  [ok] Oh My Bash"
    fi
}

# ── Lua source ────────────────────────────────────────────────────────────────
download_lua() {
    local LUA_VERSION=5.4.7
    if [ ! -d "$BOOTSTRAP_DIR/lua-${LUA_VERSION}" ]; then
        echo "  [dl] Lua ${LUA_VERSION} source..."
        curl -fsSL "https://www.lua.org/ftp/lua-${LUA_VERSION}.tar.gz" \
            | tar xz -C "$BOOTSTRAP_DIR"
    else
        echo "  [ok] Lua source"
    fi
}

# ── Luacheck + deps ──────────────────────────────────────────────────────────
download_luacheck() {
    if [ ! -d "$BOOTSTRAP_DIR/luacheck" ]; then
        echo "  [dl] Luacheck..."
        mkdir -p "$BOOTSTRAP_DIR/luacheck"
        curl -fsSL https://github.com/lunarmodules/luacheck/archive/refs/heads/master.tar.gz \
            | tar xz --strip-components=1 -C "$BOOTSTRAP_DIR/luacheck"
    else
        echo "  [ok] Luacheck"
    fi
}

download_argparse() {
    if [ ! -d "$BOOTSTRAP_DIR/argparse" ]; then
        echo "  [dl] argparse..."
        mkdir -p "$BOOTSTRAP_DIR/argparse"
        curl -fsSL https://github.com/luarocks/argparse/archive/refs/heads/master.tar.gz \
            | tar xz --strip-components=1 -C "$BOOTSTRAP_DIR/argparse"
    else
        echo "  [ok] argparse"
    fi
}

download_luafilesystem() {
    if [ ! -d "$BOOTSTRAP_DIR/luafilesystem" ]; then
        echo "  [dl] luafilesystem..."
        mkdir -p "$BOOTSTRAP_DIR/luafilesystem"
        curl -fsSL https://github.com/lunarmodules/luafilesystem/archive/refs/heads/master.tar.gz \
            | tar xz --strip-components=1 -C "$BOOTSTRAP_DIR/luafilesystem"
    else
        echo "  [ok] luafilesystem"
    fi
}

# Download all in parallel, collecting PIDs to check exit codes
pids=()
download_neovim & pids+=($!)
download_zellij & pids+=($!)
download_ohmybash & pids+=($!)
download_lua & pids+=($!)
download_luacheck & pids+=($!)
download_argparse & pids+=($!)
download_luafilesystem & pids+=($!)

failed=0
for pid in "${pids[@]}"; do
    wait "$pid" || failed=1
done
if [ "$failed" -ne 0 ]; then
    echo "ERROR: Some downloads failed. Not marking bootstrap as done."
    exit 1
fi

touch "$BOOTSTRAP_DIR/.done"
echo "==> Downloads complete."

# ── Credentials (always refresh, not gated by .done) ────────────────────────
echo "==> Gathering credentials..."
CREDS_DIR="$BOOTSTRAP_DIR/credentials"
mkdir -p "$CREDS_DIR"
if [ -f "$HOME/.codex/auth.json" ]; then
    cp "$HOME/.codex/auth.json" "$CREDS_DIR/codex-auth.json"
    echo "  [ok] codex auth"
fi

