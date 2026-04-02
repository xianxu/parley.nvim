#!/bin/bash
# Install Neovim 0.11 (arm64 binary release)
echo "==> Installing Neovim 0.11..."
curl -fsSL https://github.com/neovim/neovim/releases/download/v0.11.6/nvim-linux-arm64.tar.gz \
    | tar xz -C "$HOME/.local"
ln -sf "$HOME/.local/nvim-linux-arm64/bin/nvim" "$HOME/.local/bin/nvim"
