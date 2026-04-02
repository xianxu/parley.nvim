#!/bin/bash
# Install Zellij terminal multiplexer (arm64 binary release)
echo "==> Installing Zellij..."
curl -fsSL https://github.com/zellij-org/zellij/releases/latest/download/zellij-aarch64-unknown-linux-musl.tar.gz \
    | tar xz -C "$HOME/.local/bin"
chmod +x "$HOME/.local/bin/zellij"
