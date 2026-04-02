#!/bin/bash
# Sandbox lifecycle management for OpenShell + mutagen.
# Called by Makefile targets: sandbox, sandbox-build, sandbox-stop
set -euo pipefail

ACTION="${1:-}"
SANDBOX_NAME="${2:-}"
SANDBOX_SSH_HOST="openshell-${SANDBOX_NAME}"
PLENARY_HOST="${HOME}/.local/share/nvim/lazy/plenary.nvim"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

get_phase() {
    openshell sandbox list 2>/dev/null \
        | sed 's/\x1b\[[0-9;]*m//g' \
        | grep "$SANDBOX_NAME" \
        | awk '{print $NF}' || true
}

ensure_ssh_config() {
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    touch "$HOME/.ssh/config" && chmod 600 "$HOME/.ssh/config"
    # Always regenerate to pick up keepalive settings
    sed "/^# BEGIN openshell-${SANDBOX_NAME}/,/^# END openshell-${SANDBOX_NAME}/d" \
        "$HOME/.ssh/config" > "$HOME/.ssh/config.tmp" || true
    {
        echo "# BEGIN openshell-${SANDBOX_NAME}"
        openshell sandbox ssh-config "$SANDBOX_NAME"
        # Keep connection alive through the proxy (every 15s, tolerate 3 misses)
        echo "    ServerAliveInterval 15"
        echo "    ServerAliveCountMax 3"
        echo "# END openshell-${SANDBOX_NAME}"
        echo ""
        cat "$HOME/.ssh/config.tmp"
    } > "$HOME/.ssh/config"
    rm -f "$HOME/.ssh/config.tmp"
}

ensure_bootstrap_sync() {
    local bootstrap_dir="$SCRIPT_DIR/overlay/../../.openshell/.bootstrap"
    if ! mutagen sync list "${SANDBOX_NAME}-bootstrap" >/dev/null 2>&1; then
        echo "  Starting bootstrap sync..."
        mutagen sync create \
            --name "${SANDBOX_NAME}-bootstrap" \
            --mode one-way-replica \
            --ignore-vcs \
            "$bootstrap_dir" "${SANDBOX_SSH_HOST}:/tmp/bootstrap" || true
        mutagen sync flush "${SANDBOX_NAME}-bootstrap" 2>/dev/null || true
    fi
}

ensure_setup() {
    if ! ssh "$SANDBOX_SSH_HOST" "test -x \$HOME/.local/bin/nvim" 2>/dev/null; then
        echo "==> Running post-install on sandbox..."
        scp -q "$SCRIPT_DIR/overlay/post-install.sh" "$SANDBOX_SSH_HOST:/tmp/post-install.sh"
        ssh "$SANDBOX_SSH_HOST" "bash /tmp/post-install.sh"
    fi
    apply_config
}

# Apply setup.sh, dotfiles, and credentials to sandbox. Idempotent — safe to re-run.
apply_config() {
    echo "==> Applying config to sandbox..."
    scp -q "$SCRIPT_DIR/overlay/setup.sh" "$SANDBOX_SSH_HOST:/tmp/setup.sh"
    ssh "$SANDBOX_SSH_HOST" "bash /tmp/setup.sh"

    local git_name git_email
    git_name=$(git config user.name 2>/dev/null || true)
    git_email=$(git config user.email 2>/dev/null || true)
    if [ -n "$git_name" ]; then
        ssh "$SANDBOX_SSH_HOST" "git config --global user.name '$git_name'" 2>/dev/null || true
    fi
    if [ -n "$git_email" ]; then
        ssh "$SANDBOX_SSH_HOST" "git config --global user.email '$git_email'" 2>/dev/null || true
    fi

    # Copy dotfiles to sandbox
    echo "  Copying dotfiles..."
    ssh "$SANDBOX_SSH_HOST" "mkdir -p ~/.config/zellij"
    scp -q "$SCRIPT_DIR/dotfiles/zellij/config.kdl" "$SANDBOX_SSH_HOST:~/.config/zellij/config.kdl"

    # Forward GitHub CLI auth from host to sandbox (write config directly — fast)
    local gh_token
    gh_token=$(gh auth token 2>/dev/null || true)
    if [ -n "$gh_token" ]; then
        echo "  Forwarding gh auth to sandbox..."
        ssh "$SANDBOX_SSH_HOST" "mkdir -p ~/.config/gh && cat > ~/.config/gh/hosts.yml" <<EOF
github.com:
    oauth_token: ${gh_token}
    user: $(gh api user --jq .login 2>/dev/null || echo "")
    git_protocol: https
EOF
    fi
}

ensure_mutagen_sync() {
    if ! mutagen sync list "${SANDBOX_NAME}-repo" >/dev/null 2>&1; then
        echo "  Starting repo sync..."
        mutagen sync create \
            --name "${SANDBOX_NAME}-repo" \
            --mode two-way-resolved \
            --ignore-vcs \
            --ignore node_modules \
            --ignore .test-home --ignore .test-xdg --ignore .test-tmp \
            "$REPO_DIR" "${SANDBOX_SSH_HOST}:/sandbox/repo" || true
        mutagen sync flush "${SANDBOX_NAME}-repo" 2>/dev/null || true
    fi

    if ! mutagen sync list "${SANDBOX_NAME}-worktree" >/dev/null 2>&1; then
        echo "  Starting worktree sync..."
        mkdir -p "$REPO_DIR/../worktree"
        mutagen sync create \
            --name "${SANDBOX_NAME}-worktree" \
            --mode two-way-resolved \
            --ignore-vcs \
            "$REPO_DIR/../worktree" "${SANDBOX_SSH_HOST}:/sandbox/worktree" || true
    fi

    # Sync .git/ one-way so sandbox has git history for diff/log/branch commands.
    # One-way-replica avoids conflicts on index, lock files, etc.
    if ! mutagen sync list "${SANDBOX_NAME}-git" >/dev/null 2>&1; then
        echo "  Starting git sync..."
        mutagen sync create \
            --name "${SANDBOX_NAME}-git" \
            --mode one-way-replica \
            --ignore "index.lock" \
            "$REPO_DIR/.git" "${SANDBOX_SSH_HOST}:/sandbox/repo/.git" || true
        mutagen sync flush "${SANDBOX_NAME}-git" 2>/dev/null || true
    fi

    if [ -d "$PLENARY_HOST" ] && ! mutagen sync list "${SANDBOX_NAME}-plenary" >/dev/null 2>&1; then
        echo "  Starting plenary sync..."
        mutagen sync create \
            --name "${SANDBOX_NAME}-plenary" \
            --mode one-way-replica \
            --ignore-vcs \
            "$PLENARY_HOST" \
            "${SANDBOX_SSH_HOST}:/sandbox/.local/share/nvim/lazy/plenary.nvim" || true
        mutagen sync flush "${SANDBOX_NAME}-plenary" 2>/dev/null || true
    fi
}

# Light cleanup: terminate syncs and wipe sandbox working dirs, but keep the
# sandbox container and installed tools. Fast way to get a fresh repo state.
soft_cleanup() {
    echo "==> Soft cleanup (keeping sandbox + tools)..."
    mutagen sync terminate "${SANDBOX_NAME}-repo" 2>/dev/null || true
    mutagen sync terminate "${SANDBOX_NAME}-git" 2>/dev/null || true
    mutagen sync terminate "${SANDBOX_NAME}-worktree" 2>/dev/null || true
    mutagen sync terminate "${SANDBOX_NAME}-plenary" 2>/dev/null || true
    ssh "$SANDBOX_SSH_HOST" "rm -rf /sandbox/repo /sandbox/worktree && mkdir -p /sandbox/repo /sandbox/worktree" 2>/dev/null || true
    echo "==> Re-syncing files..."
    ensure_mutagen_sync
    echo "==> Re-applying config..."
    apply_config
    echo "==> Clean done."
}

# Full cleanup: destroy everything including the sandbox container.
cleanup() {
    mutagen sync terminate "${SANDBOX_NAME}-bootstrap" 2>/dev/null || true
    mutagen sync terminate "${SANDBOX_NAME}-repo" 2>/dev/null || true
    mutagen sync terminate "${SANDBOX_NAME}-git" 2>/dev/null || true
    mutagen sync terminate "${SANDBOX_NAME}-worktree" 2>/dev/null || true
    mutagen sync terminate "${SANDBOX_NAME}-plenary" 2>/dev/null || true
    openshell sandbox delete "$SANDBOX_NAME" 2>/dev/null || true
    if [ -f "$HOME/.ssh/config" ]; then
        sed "/^# BEGIN openshell-${SANDBOX_NAME}/,/^# END openshell-${SANDBOX_NAME}/d" \
            "$HOME/.ssh/config" > "$HOME/.ssh/config.tmp" \
        && mv "$HOME/.ssh/config.tmp" "$HOME/.ssh/config"
    fi
}

timer_start() { date +%s; }
timer_show() { echo "    (${1}: $(( $(date +%s) - $2 ))s)"; }

# Ensure sandbox exists and is fully set up. Idempotent.
cmd_build() {
    local phase t0 t_total
    t_total=$(timer_start)
    phase=$(get_phase)

    # Clean up broken state
    if [ -n "$phase" ] && [ "$phase" != "Running" ] && [ "$phase" != "Ready" ]; then
        echo "==> Sandbox in bad state ($phase), cleaning up..."
        cleanup
        phase=""
    fi

    # Create sandbox and download deps in parallel
    if [ -z "$phase" ]; then
        echo "==> Creating sandbox + downloading deps (parallel)..."
        t0=$(timer_start)
        openshell sandbox create \
            --name "$SANDBOX_NAME" \
            --from base \
            --policy .openshell/policy.yaml \
            --auto-providers \
            -- true &
        local sandbox_pid=$!
        bash "$SCRIPT_DIR/overlay/bootstrap.sh" &
        local bootstrap_pid=$!
        wait "$sandbox_pid" || true
        wait "$bootstrap_pid"
        timer_show "create+bootstrap" "$t0"
    else
        echo "==> Bootstrapping dependencies on host..."
        t0=$(timer_start)
        bash "$SCRIPT_DIR/overlay/bootstrap.sh"
        timer_show "bootstrap" "$t0"
    fi

    echo "==> Ensuring SSH config..."
    t0=$(timer_start)
    ensure_ssh_config
    timer_show "ssh config" "$t0"

    echo "==> Ensuring bootstrap sync..."
    t0=$(timer_start)
    ensure_bootstrap_sync
    timer_show "bootstrap sync" "$t0"

    t0=$(timer_start)
    ensure_setup
    timer_show "setup+post-install" "$t0"

    echo "==> Ensuring file sync..."
    t0=$(timer_start)
    ensure_mutagen_sync
    timer_show "file sync" "$t0"

    echo "==> Sandbox ready. (total: $(( $(date +%s) - t_total ))s)"
}

# Connect to sandbox. Builds first if needed.
cmd_connect() {
    local phase
    phase=$(get_phase)

    if [ "$phase" != "Running" ] && [ "$phase" != "Ready" ]; then
        cmd_build
    fi

    openshell sandbox connect "$SANDBOX_NAME" || true
}

cmd_clean() {
    soft_cleanup
}

cmd_stop() {
    echo "==> Stopping sandbox..."
    cleanup
    echo "Sandbox stopped."
}

case "$ACTION" in
    build)   cmd_build ;;
    connect) cmd_connect ;;
    clean)   cmd_clean ;;
    stop)    cmd_stop ;;
    *)       echo "Usage: $0 {build|connect|stop|clean} <sandbox-name>"; exit 1 ;;
esac
