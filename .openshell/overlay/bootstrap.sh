#!/bin/bash
# Host-side download of sandbox dependencies.
# Downloads everything locally (fast, no proxy), then mutagen syncs to sandbox.
# Run from host before sandbox post-install.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="$SCRIPT_DIR/../../.openshell/.bootstrap"

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
        git clone --depth 1 https://github.com/ohmybash/oh-my-bash.git "$BOOTSTRAP_DIR/oh-my-bash"
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
        git clone --depth 1 https://github.com/lunarmodules/luacheck.git "$BOOTSTRAP_DIR/luacheck"
    else
        echo "  [ok] Luacheck"
    fi
}

download_argparse() {
    if [ ! -d "$BOOTSTRAP_DIR/argparse" ]; then
        echo "  [dl] argparse..."
        git clone --depth 1 https://github.com/luarocks/argparse.git "$BOOTSTRAP_DIR/argparse"
    else
        echo "  [ok] argparse"
    fi
}

download_luafilesystem() {
    if [ ! -d "$BOOTSTRAP_DIR/luafilesystem" ]; then
        echo "  [dl] luafilesystem..."
        git clone --depth 1 https://github.com/lunarmodules/luafilesystem.git "$BOOTSTRAP_DIR/luafilesystem"
    else
        echo "  [ok] luafilesystem"
    fi
}

# Download all in parallel
download_neovim &
download_zellij &
download_ohmybash &
download_lua &
download_luacheck &
download_argparse &
download_luafilesystem &
wait

touch "$BOOTSTRAP_DIR/.done"
echo "==> Downloads complete."
