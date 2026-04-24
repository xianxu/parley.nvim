#!/bin/bash
# Sandbox lifecycle management for OpenShell + mutagen.
# Called by Makefile targets: sandbox, sandbox-build, sandbox-stop
set -euo pipefail

# Auto-detect Docker socket for Docker Desktop (macOS uses a non-standard path)
if [ -z "${DOCKER_HOST:-}" ] && [ ! -S /var/run/docker.sock ]; then
    for sock in "$HOME/.docker/run/docker.sock" "$HOME/.docker/desktop/docker.sock"; do
        if [ -S "$sock" ]; then
            export DOCKER_HOST="unix://$sock"
            break
        fi
    done
fi

ACTION="${1:-}"
SANDBOX_NAME="${2:-}"
SANDBOX_SSH_HOST="openshell-${SANDBOX_NAME}"

# Pre-flight checks: validate prerequisites before doing real work.
# Only runs for actions that need the full stack (build, connect, clean).
preflight() {
    local failed=0

    # 1. openshell CLI
    if ! command -v openshell >/dev/null 2>&1; then
        echo "ERROR: 'openshell' CLI not found in PATH."
        echo "  Install it per OpenShell docs, then retry."
        failed=1
    fi

    # 2. Docker daemon — auto-start on macOS
    if ! docker info >/dev/null 2>&1; then
        if [ "$(uname)" = "Darwin" ] && [ -d "/Applications/Docker.app" ]; then
            echo "  Docker not running — starting Docker Desktop..."
            open -a Docker
            local retries=0
            while ! docker info >/dev/null 2>&1; do
                retries=$((retries + 1))
                if [ "$retries" -ge 30 ]; then
                    echo "ERROR: Docker Desktop did not start within 60s."
                    failed=1
                    break
                fi
                sleep 2
            done
            if [ "$retries" -lt 30 ]; then
                echo "  Docker Desktop started."
            fi
        else
            echo "ERROR: Docker is not running or not accessible."
            echo "  Start Docker Desktop, then retry."
            failed=1
        fi
    fi

    # 3. mutagen CLI
    if ! command -v mutagen >/dev/null 2>&1; then
        echo "ERROR: 'mutagen' CLI not found in PATH."
        echo "  Install: brew install mutagen-io/mutagen/mutagen"
        failed=1
    fi

    # 4. OpenShell gateway — auto-restart if unreachable
    if command -v openshell >/dev/null 2>&1; then
        if ! openshell sandbox list >/dev/null 2>&1; then
            echo "  OpenShell gateway not reachable — restarting..."
            openshell gateway destroy --name openshell 2>/dev/null || true
            if openshell gateway start; then
                echo "  OpenShell gateway started."
            else
                echo "ERROR: Failed to start OpenShell gateway."
                failed=1
            fi
        fi
    fi

    if [ "$failed" -ne 0 ]; then
        echo ""
        echo "Pre-flight checks failed. Fix the above issues and retry."
        exit 1
    fi
}

PLENARY_HOST="${HOME}/.local/share/nvim/lazy/plenary.nvim"
# All paths derive from $0. .openshell/ is a real dir in every repo (even when
# its contents are symlinks), so dirname/$0/.. always gives the local repo.
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_NAME_LOCAL="$(basename "$REPO_DIR")"
WORKSPACE_DIR="$(cd "$REPO_DIR/.." && pwd)"
SCRIPT_DIR="$REPO_DIR/.openshell"

# Use Apple's system SSH/SCP throughout — Homebrew openssh lacks macOS-specific
# options (UseKeychain) and causes "Bad configuration option: usekeychain" errors.
# Write sandbox Host blocks to ~/.ssh/config so the mutagen daemon (a separate
# long-lived process) can reach all sandboxes without MUTAGEN_SSH_PATH.
SSH_CONFIG="$HOME/.ssh/config"
SSH="/usr/bin/ssh"
SCP="/usr/bin/scp"
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
    # Upsert this sandbox's Host block into ~/.ssh/config.
    # Each sandbox gets a BEGIN/END-delimited block; other sandboxes' blocks are preserved.
    local marker_begin="# BEGIN openshell-${SANDBOX_NAME}"
    local marker_end="# END openshell-${SANDBOX_NAME}"
    local new_block
    new_block=$(cat <<SSHEOF
${marker_begin}
$(openshell sandbox ssh-config "$SANDBOX_NAME")
    ServerAliveInterval 60
    ServerAliveCountMax 3
${marker_end}
SSHEOF
    )

    mkdir -p "$HOME/.ssh"
    touch "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"

    # Remove old block if present, then append new one
    if grep -qF "$marker_begin" "$SSH_CONFIG" 2>/dev/null; then
        sed -i.bak "/${marker_begin}/,/${marker_end}/d" "$SSH_CONFIG"
        rm -f "${SSH_CONFIG}.bak"
    fi
    echo "$new_block" >> "$SSH_CONFIG"
}

ensure_bootstrap_sync() {
    local bootstrap_dir="$SCRIPT_DIR/.bootstrap"
    ensure_sync bootstrap "$bootstrap_dir" /tmp/bootstrap one-way-replica --ignore-vcs
}

ensure_setup() {
    # Re-run post-install if any expected tool is missing
    if ! $SSH "$SANDBOX_SSH_HOST" "test -x \$HOME/.local/bin/nvim && test -x \$HOME/.local/bin/zellij" 2>/dev/null; then
        echo "==> Running post-install on sandbox..."
        mutagen sync flush "${SANDBOX_NAME}-bootstrap" 2>/dev/null || true
        $SCP -q "$SCRIPT_DIR/overlay/post-install.sh" "$SANDBOX_SSH_HOST:/tmp/post-install.sh"
        $SSH "$SANDBOX_SSH_HOST" "bash /tmp/post-install.sh"
    fi
    apply_config
}

# Gather host credentials into bootstrap cache so mutagen syncs them to sandbox.
gather_credentials() {
    local creds_dir="$SCRIPT_DIR/.bootstrap/credentials"
    mkdir -p "$creds_dir"
    if [ -f "$HOME/.codex/auth.json" ]; then
        cp "$HOME/.codex/auth.json" "$creds_dir/codex-auth.json"
    fi
}

# Apply setup.sh, dotfiles, and credentials to sandbox. Idempotent — safe to re-run.
apply_config() {
    echo "==> Applying config to sandbox..."
    gather_credentials
    mutagen sync flush "${SANDBOX_NAME}-bootstrap" 2>/dev/null || true
    local host_tz
    host_tz=$(readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||' || echo "UTC")
    $SCP -q "$SCRIPT_DIR/overlay/setup.sh" "$SANDBOX_SSH_HOST:/tmp/setup.sh"
    $SSH "$SANDBOX_SSH_HOST" "HOST_TZ='$host_tz' bash /tmp/setup.sh"

    local git_name git_email
    git_name=$(git config user.name 2>/dev/null || true)
    git_email=$(git config user.email 2>/dev/null || true)
    if [ -n "$git_name" ]; then
        $SSH "$SANDBOX_SSH_HOST" "git config --global user.name '$git_name'" 2>/dev/null || true
    fi
    if [ -n "$git_email" ]; then
        $SSH "$SANDBOX_SSH_HOST" "git config --global user.email '$git_email'" 2>/dev/null || true
    fi

    # Copy dotfiles to sandbox
    echo "  Copying dotfiles..."
    $SSH "$SANDBOX_SSH_HOST" "mkdir -p ~/.config/zellij/layouts"
    $SCP -q "$SCRIPT_DIR/dotfiles/zellij/config.kdl" "$SANDBOX_SSH_HOST:~/.config/zellij/config.kdl"
    $SCP -q "$SCRIPT_DIR/dotfiles/zellij/layouts/default.kdl" "$SANDBOX_SSH_HOST:~/.config/zellij/layouts/default.kdl"
    $SCP -q "$SCRIPT_DIR/dotfiles/zellij/clock.sh" "$SANDBOX_SSH_HOST:~/.config/zellij/clock.sh"
    $SSH "$SANDBOX_SSH_HOST" "chmod +x ~/.config/zellij/clock.sh"

    # Forward GitHub CLI auth from host to sandbox (write config directly — fast)
    local gh_token
    gh_token=$(gh auth token 2>/dev/null || true)
    if [ -n "$gh_token" ]; then
        echo "  Forwarding gh auth to sandbox..."
        $SSH "$SANDBOX_SSH_HOST" "mkdir -p ~/.config/gh && cat > ~/.config/gh/hosts.yml" <<EOF
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
    # Main repo: two-way sync (this is where you work)
    ensure_sync repo "$REPO_DIR" /sandbox/repo two-way-resolved \
        --ignore-vcs \
        --ignore node_modules \
        --ignore .test-home --ignore .test-xdg --ignore .test-tmp

    # Workspace peers: one-way read-only sync of the parent directory,
    # excluding the main repo (already synced above) and heavy dirs.
    ensure_sync workspace "$WORKSPACE_DIR" /sandbox/workspace one-way-replica \
        --ignore-vcs \
        --ignore "$REPO_NAME_LOCAL" \
        --ignore node_modules \
        --ignore .test-home --ignore .test-xdg --ignore .test-tmp

    # Create flat peer symlinks under /sandbox/ so repos are true peers:
    #   /sandbox/brain → /sandbox/repo (main)
    #   /sandbox/ariadne → /sandbox/workspace/ariadne (peer)
    # Also link inside /sandbox/workspace/ for consistency.
    $SSH "$SANDBOX_SSH_HOST" "ln -sfn /sandbox/repo /sandbox/$REPO_NAME_LOCAL" 2>/dev/null || true
    $SSH "$SANDBOX_SSH_HOST" "ln -sfn /sandbox/repo /sandbox/workspace/$REPO_NAME_LOCAL" 2>/dev/null || true
    for dir in "$WORKSPACE_DIR"/*/; do
        local name
        name=$(basename "$dir")
        [ "$name" = "$REPO_NAME_LOCAL" ] && continue
        $SSH "$SANDBOX_SSH_HOST" "ln -sfn /sandbox/workspace/$name /sandbox/$name" 2>/dev/null || true
    done

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

    # Claude Code sessions: bi-directional so sessions can be resumed across
    # host and sandbox (use `claude --resume <session-id>`).
    local claude_projects="${HOME}/.claude/projects"
    if [ -d "$claude_projects" ]; then
        $SSH "$SANDBOX_SSH_HOST" "mkdir -p /sandbox/.claude/projects" 2>/dev/null || true
        ensure_sync claude-sessions "$claude_projects" /sandbox/.claude/projects two-way-resolved \
            --ignore-vcs
    fi
}

# All mutagen sync names (add new syncs here)
SYNC_NAMES="repo git workspace worktree plenary nvim-state claude-sessions"

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
    $SSH "$SANDBOX_SSH_HOST" "rm -rf /sandbox/repo /sandbox/worktree && mkdir -p /sandbox/repo /sandbox/worktree" 2>/dev/null || true
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
    # Remove this sandbox's block from the shared SSH config
    local marker_begin="# BEGIN openshell-${SANDBOX_NAME}"
    local marker_end="# END openshell-${SANDBOX_NAME}"
    if [ -f "$SSH_CONFIG" ] && grep -qF "$marker_begin" "$SSH_CONFIG" 2>/dev/null; then
        sed -i.bak "/${marker_begin}/,/${marker_end}/d" "$SSH_CONFIG"
        rm -f "${SSH_CONFIG}.bak"
    fi
}

# Nuclear cleanup: full cleanup + wipe bootstrap cache so deps are re-downloaded.
cleanup_nuke() {
    cleanup
    local bootstrap_dir="$SCRIPT_DIR/.bootstrap"
    if [ -d "$bootstrap_dir" ]; then
        echo "==> Removing bootstrap cache..."
        rm -rf "$bootstrap_dir"
    fi
}

timer_start() { date +%s; }
timer_show() { echo "    (${1}: $(( $(date +%s) - $2 ))s)"; }

# Ensure sandbox exists and is fully set up. Idempotent.
cmd_build() {
    preflight
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
        BOOTSTRAP_DIR="$SCRIPT_DIR/.bootstrap" bash "$SCRIPT_DIR/overlay/bootstrap.sh" &
        local bootstrap_pid=$!
        wait "$sandbox_pid" || true
        wait "$bootstrap_pid"
        save_digest  # record the base image digest for future update checks
        timer_show "create+bootstrap" "$t0"
    else
        echo "==> Bootstrapping dependencies on host..."
        t0=$(timer_start)
        BOOTSTRAP_DIR="$SCRIPT_DIR/.bootstrap" bash "$SCRIPT_DIR/overlay/bootstrap.sh"
        timer_show "bootstrap" "$t0"
    fi

    # Wait for sandbox to be Running before proceeding to SSH/mutagen
    echo "==> Waiting for sandbox to be Running..."
    t0=$(timer_start)
    local retries=0
    while true; do
        phase=$(get_phase)
        if [ "$phase" = "Running" ] || [ "$phase" = "Ready" ]; then
            break
        fi
        retries=$((retries + 1))
        if [ "$retries" -ge 30 ]; then
            echo "ERROR: Sandbox did not reach Running state within 60s (current: ${phase:-unknown})."
            exit 1
        fi
        sleep 2
    done
    timer_show "sandbox ready" "$t0"

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

    caffeinate -i env PATH="/usr/bin:$PATH" openshell sandbox connect "$SANDBOX_NAME" || true
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

cmd_nuke() {
    echo "==> Nuking sandbox (including bootstrap cache)..."
    cleanup_nuke
    echo "Sandbox nuked."
}

case "$ACTION" in
    build)   cmd_build ;;
    connect) cmd_connect ;;
    clean)   cmd_clean ;;
    stop)    cmd_stop ;;
    nuke)    cmd_nuke ;;
    *)       echo "Usage: $0 {build|connect|stop|clean|nuke} <sandbox-name>"; exit 1 ;;
esac
