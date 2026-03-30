# When OpenShell's base image becomes publicly available, switch to:
#   FROM ghcr.io/nvidia/openshell-community/base:latest
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

# Create sandbox user (OpenShell base image provides this; ubuntu:24.04 does not)
# Shell set to /bin/bash initially; changed to zsh after package install below.
RUN useradd -m -s /bin/bash sandbox

# System packages
RUN apt-get update && apt-get install -y \
    iproute2 \
    iptables \
    tmux \
    git \
    curl \
    wget \
    unzip \
    build-essential \
    tree \
    bat \
    ripgrep \
    fd-find \
    ack \
    zsh \
    lua5.4 \
    liblua5.4-dev \
    luarocks \
    python3 \
    python3-pip \
    python3-venv \
    golang-go \
    ruby-full \
    bubblewrap \
    && rm -rf /var/lib/apt/lists/*

# Rust (installs to /home/sandbox/.cargo, needs to run as root then chown)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && mv /root/.cargo /home/sandbox/.cargo \
    && mv /root/.rustup /home/sandbox/.rustup \
    && chown -R sandbox:sandbox /home/sandbox/.cargo /home/sandbox/.rustup

# Neovim (latest stable from GitHub — apt has 0.9.5, we need 0.11+ for plugin compat)
RUN curl -fsSL https://github.com/neovim/neovim/releases/download/v0.11.6/nvim-linux-arm64.tar.gz \
    | tar xz -C /opt \
    && ln -s /opt/nvim-linux-arm64/bin/nvim /usr/local/bin/nvim

# fzf
RUN git clone --depth 1 https://github.com/junegunn/fzf.git /opt/fzf \
    && /opt/fzf/install --all --no-bash --no-fish --key-bindings --completion

# zoxide (install to /usr/local/bin so all users can access it)
RUN curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh -s -- --bin-dir /usr/local/bin

# GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Set default shell and fix ownership
RUN chsh -s /usr/bin/zsh sandbox

# Switch to sandbox user for user-level installs
USER sandbox

# Node.js via nvm
ENV NVM_DIR=/home/sandbox/.nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash \
    && . "$NVM_DIR/nvm.sh" && nvm install --lts && nvm alias default node

# Oh-My-Zsh + plugins (installs BEFORE dotfiles since it overwrites .zshrc)
ENV ZSH=/home/sandbox/.oh-my-zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
    && git clone --depth 1 https://github.com/Aloxaf/fzf-tab         ${ZSH}/custom/plugins/fzf-tab \
    && git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions ${ZSH}/custom/plugins/zsh-autosuggestions \
    && git clone --depth 1 https://github.com/zdharma-continuum/fast-syntax-highlighting ${ZSH}/custom/plugins/fast-syntax-highlighting

# AI coding agents (npm-based)
RUN . "$NVM_DIR/nvm.sh" \
    && npm install -g \
        @anthropic-ai/claude-code \
        @openai/codex \
        @google/gemini-cli

# Amazon Q Developer CLI
RUN curl --proto '=https' --tlsv1.2 -sSf \
        'https://desktop-release.q.us-east-1.amazonaws.com/latest/q-aarch64-linux.zip' -o /tmp/q.zip \
    && unzip /tmp/q.zip -d /tmp/q \
    && /tmp/q/q/install.sh --no-confirm \
    && rm -rf /tmp/q.zip /tmp/q

# Dotfiles (AFTER oh-my-zsh so our .zshrc isn't overwritten)
COPY --chown=sandbox:sandbox dotfiles/zshrc /home/sandbox/.zshrc
COPY --chown=sandbox:sandbox dotfiles/nvim/ /home/sandbox/.config/nvim/

# Neovim plugins (restore exact versions from lazy-lock.json, don't update)
RUN nvim --headless "+Lazy! restore" +qa 2>/dev/null || true

# Git: rewrite SSH URLs to HTTPS (credentials injected by OpenShell provider)
RUN git config --global url."https://github.com/".insteadOf "git@github.com:" \
    && git config --global url."https://github.com/".insteadOf "ssh://git@github.com/"

# Mutagen sync targets (host repo and worktree are synced here)
# Both live under /home/sandbox so filesystem_policy covers them.
RUN mkdir -p /home/sandbox/repo /home/sandbox/worktree

WORKDIR /home/sandbox/repo
