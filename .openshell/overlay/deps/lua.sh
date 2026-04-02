#!/bin/bash
# Install Lua 5.4 + LuaRocks + luacheck from source (no root needed)
echo "==> Installing Lua 5.4 + LuaRocks..."
LUA_VERSION=5.4.7
curl -fsSL "https://www.lua.org/ftp/lua-${LUA_VERSION}.tar.gz" | tar xz -C /tmp
make -C "/tmp/lua-${LUA_VERSION}" linux INSTALL_TOP="$HOME/.local" -j"$(nproc)" && \
    make -C "/tmp/lua-${LUA_VERSION}" install INSTALL_TOP="$HOME/.local"
rm -rf "/tmp/lua-${LUA_VERSION}"

LUAROCKS_VERSION=3.11.1
curl -fsSL "https://luarocks.org/releases/luarocks-${LUAROCKS_VERSION}.tar.gz" | tar xz -C /tmp
cd "/tmp/luarocks-${LUAROCKS_VERSION}" && \
    ./configure --prefix="$HOME/.local" --with-lua="$HOME/.local" && \
    make && make install
cd - >/dev/null
rm -rf "/tmp/luarocks-${LUAROCKS_VERSION}"

echo "==> Installing luacheck..."
"$HOME/.local/bin/luarocks" install --local luacheck
