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
BASE_IMAGE="ghcr.io/nvidia/openshell-community/sandboxes/base"
DIGEST_FILE="$SCRIPT_DIR/.base-image-digest"

# Fetch the latest digest of the base image from GHCR.
# Returns empty string on any failure (network, auth, etc).
fetch_remote_digest() {
    local token digest
    token=$(curl -sf --max-time 5 \
        "https://ghcr.io/token?service=ghcr.io&scope=repository:nvidia/openshell-community/sandboxes/base:pull" \
        | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))" 2>/dev/null) || true
    if [ -z "$token" ]; then return; fi
    digest=$(curl -sf --max-time 5 \
        -H "Authorization: Bearer $token" \
        -H "Accept: application/vnd.oci.image.index.v1+json,application/vnd.docker.distribution.manifest.v2+json" \
        -o /dev/null -w '' \
        --dump-header /dev/stdout \
        "https://ghcr.io/v2/nvidia/openshell-community/sandboxes/base/manifests/latest" \
        | grep -i 'docker-content-digest' | awk '{print $2}' | tr -d '\r') || true
    echo "$digest"
}

save_digest() {
    local digest
    digest=$(fetch_remote_digest)
    if [ -n "$digest" ]; then
        echo "$digest" > "$DIGEST_FILE"
    fi
}

# Check if the base image has been updated since the sandbox was created.
# Prints a warning and prompts user if an update is available.
# Returns 0 to continue, 1 if user wants to rebuild.
check_base_image_update() {
    local saved_digest remote_digest
    remote_digest=$(fetch_remote_digest)
    if [ -z "$remote_digest" ]; then return 0; fi  # can't reach registry, continue
    if [ ! -f "$DIGEST_FILE" ]; then
        echo "  Seeding base image digest for future update checks."
        echo "$remote_digest" > "$DIGEST_FILE"
        return 0
    fi
    saved_digest=$(cat "$DIGEST_FILE")
    if [ "$saved_digest" = "$remote_digest" ]; then
        echo "  Base image is up to date."
        return 0
    fi
    echo ""
    echo "  ** Base image update available **"
    echo "  Current: ${saved_digest:0:19}..."
    echo "  Latest:  ${remote_digest:0:19}..."
    echo ""
    printf "  Recreate sandbox with new base image? [y/N] "
    read -r answer </dev/tty
    if [[ "$answer" =~ ^[Yy] ]]; then
        echo "==> Rebuilding sandbox with updated base image..."
        cleanup
        return 1
    fi
    echo "  Continuing with current sandbox."
    return 0
}

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
        echo "    ServerAliveCountMax 480"
        echo "# END openshell-${SANDBOX_NAME}"
        echo ""
        cat "$HOME/.ssh/config.tmp"
    } > "$HOME/.ssh/config"
    rm -f "$HOME/.ssh/config.tmp"
}

ensure_bootstrap_sync() {
    local bootstrap_dir="$SCRIPT_DIR/overlay/../../.openshell/.bootstrap"
    ensure_sync bootstrap "$bootstrap_dir" /tmp/bootstrap one-way-replica --ignore-vcs
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

# Create a mutagen sync if it doesn't already exist.
# Usage: ensure_sync <label> <local_path> <remote_path> <mode> [extra_args...]
# Flushes after creation for one-way-replica and two-way-resolved modes.
ensure_sync() {
    local label="$1" local_path="$2" remote_path="$3" mode="$4"
    shift 4
    local sync_name="${SANDBOX_NAME}-${label}"

    if mutagen sync list "$sync_name" >/dev/null 2>&1; then
        return
    fi
    echo "  Starting ${label} sync..."
    mutagen sync create \
        --name "$sync_name" \
        --mode "$mode" \
        "$@" \
        "$local_path" "${SANDBOX_SSH_HOST}:${remote_path}" || true
    mutagen sync flush "$sync_name" 2>/dev/null || true
}

ensure_mutagen_sync() {
    ensure_sync repo "$REPO_DIR" /sandbox/repo two-way-resolved \
        --ignore-vcs \
        --ignore node_modules \
        --ignore .test-home --ignore .test-xdg --ignore .test-tmp

    mkdir -p "$REPO_DIR/../worktree"
    ensure_sync worktree "$REPO_DIR/../worktree" /sandbox/worktree two-way-resolved \
        --ignore-vcs

    ensure_sync git "$REPO_DIR/.git" /sandbox/repo/.git one-way-replica \
        --ignore "index.lock"

    local nvim_state="${HOME}/.local/state/nvim"
    if [ -d "$nvim_state" ]; then
        ensure_sync nvim-state "$nvim_state" /sandbox/.local/state/nvim one-way-replica \
            --ignore-vcs
    fi

    if [ -d "$PLENARY_HOST" ]; then
        ensure_sync plenary "$PLENARY_HOST" /sandbox/.local/share/nvim/lazy/plenary.nvim one-way-replica \
            --ignore-vcs
    fi
}

# All mutagen sync names (add new syncs here)
SYNC_NAMES="repo git worktree plenary nvim-state"

terminate_all_syncs() {
    for name in $SYNC_NAMES; do
        mutagen sync terminate "${SANDBOX_NAME}-${name}" 2>/dev/null || true
    done
}

# Light cleanup: terminate syncs and wipe sandbox working dirs, but keep the
# sandbox container and installed tools. Fast way to get a fresh repo state.
soft_cleanup() {
    echo "==> Soft cleanup (keeping sandbox + tools)..."
    terminate_all_syncs
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
    terminate_all_syncs
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

    # Check for base image updates on existing sandbox
    if [ -n "$phase" ]; then
        if ! check_base_image_update; then
            phase=""  # user chose to rebuild
        fi
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
        save_digest  # record the base image digest for future update checks
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
    stty sane 2>/dev/null  # restore terminal after abnormal disconnect (e.g. sleep/wake)
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
