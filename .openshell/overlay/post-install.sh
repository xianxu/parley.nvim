#!/bin/bash
# Sandbox-side install from pre-downloaded bootstrap files.
# Expects bootstrap files at /tmp/bootstrap/ (synced via mutagen from host).
set -euo pipefail

BOOTSTRAP="/tmp/bootstrap"
mkdir -p "$HOME/.local/bin"

# ── Neovim ────────────────────────────────────────────────────────────────────
if [ ! -x "$HOME/.local/bin/nvim" ]; then
    echo "==> Installing Neovim..."
    cp -r "$BOOTSTRAP/nvim-linux-arm64" "$HOME/.local/"
    ln -sf "$HOME/.local/nvim-linux-arm64/bin/nvim" "$HOME/.local/bin/nvim"
else
    echo "  [ok] Neovim"
fi

# ── Zellij ────────────────────────────────────────────────────────────────────
if [ ! -x "$HOME/.local/bin/zellij" ]; then
    echo "==> Installing Zellij..."
    cp "$BOOTSTRAP/zellij" "$HOME/.local/bin/zellij"
    chmod +x "$HOME/.local/bin/zellij"
else
    echo "  [ok] Zellij"
fi

# ── Oh My Bash ────────────────────────────────────────────────────────────────
if [ ! -d "$HOME/.oh-my-bash" ]; then
    echo "==> Installing Oh My Bash..."
    cp -r "$BOOTSTRAP/oh-my-bash" "$HOME/.oh-my-bash"
    # Install bashrc from template (the install.sh script bails if $OSH dir exists)
    if [ -f "$HOME/.bashrc" ]; then
        cp "$HOME/.bashrc" "$HOME/.bashrc.pre-omb"
    fi
    sed "s|^export OSH=.*|export OSH=$HOME/.oh-my-bash|" \
        "$HOME/.oh-my-bash/templates/bashrc.osh-template" > "$HOME/.bashrc"
else
    echo "  [ok] Oh My Bash"
fi

# ── Lua ───────────────────────────────────────────────────────────────────────
if [ ! -x "$HOME/.local/bin/lua" ]; then
    echo "==> Building Lua..."
    LUA_VERSION=5.4.7
    cp -r "$BOOTSTRAP/lua-${LUA_VERSION}" /tmp/lua-build
    make -C /tmp/lua-build linux INSTALL_TOP="$HOME/.local" -j"$(nproc)"
    make -C /tmp/lua-build install INSTALL_TOP="$HOME/.local"
    rm -rf /tmp/lua-build
else
    echo "  [ok] Lua"
fi

# ── Luafilesystem (C module, build on sandbox) ───────────────────────────────
if [ ! -f "$HOME/.local/lib/lua/5.4/lfs.so" ]; then
    echo "==> Building luafilesystem..."
    mkdir -p "$HOME/.local/lib/lua/5.4"
    gcc -shared -fPIC -o "$HOME/.local/lib/lua/5.4/lfs.so" \
        -I"$HOME/.local/include" \
        "$BOOTSTRAP/luafilesystem/src/lfs.c"
else
    echo "  [ok] luafilesystem"
fi

# ── Luacheck + argparse ─────────────────────────────────────────────────────
if [ ! -x "$HOME/.local/bin/luacheck" ]; then
    echo "==> Installing Luacheck..."
    cp -r "$BOOTSTRAP/luacheck" "$HOME/.local/lib/luacheck"
    cp -r "$BOOTSTRAP/argparse" "$HOME/.local/lib/argparse"
    # Create wrapper script that sets LUA_PATH/LUA_CPATH and runs luacheck
    cat > "$HOME/.local/bin/luacheck" << 'WRAPPER'
#!/bin/bash
export LUA_PATH="$HOME/.local/lib/luacheck/src/?.lua;$HOME/.local/lib/luacheck/src/?/init.lua;$HOME/.local/lib/argparse/src/?.lua;;"
export LUA_CPATH="$HOME/.local/lib/lua/5.4/?.so;;"
exec "$HOME/.local/bin/lua" "$HOME/.local/lib/luacheck/bin/luacheck.lua" "$@"
WRAPPER
    chmod +x "$HOME/.local/bin/luacheck"
else
    echo "  [ok] Luacheck"
fi

echo "==> Post-install complete."
