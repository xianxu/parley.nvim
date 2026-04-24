#!/bin/bash
# One-shot setup for OpenShell sandbox — git config, shell config, workspace dirs.
# Dependency installation is handled by post-install.sh (from bootstrap cache).
# Idempotent: safe to re-run (e.g. via `make sandbox-clean`).
set -euo pipefail

mkdir -p "$HOME/.local/bin"

# ── Git config ───────────────────────────────────────────────────────────────
echo "==> Configuring git..."
git config --global url."https://github.com/".insteadOf "git@github.com:"
git config --global url."https://github.com/".insteadOf "ssh://git@github.com/"
# OpenShell proxy terminates TLS — sandbox doesn't have its CA cert
git config --global http.sslVerify false

# ── Shell config ─────────────────────────────────────────────────────────────
echo "==> Configuring shell..."
# Remove old block if present (idempotent)
sed -i '/^# BEGIN openshell-overlay/,/^# END openshell-overlay/d' "$HOME/.bashrc"
cat >> "$HOME/.bashrc" << 'BASHEOF'
# BEGIN openshell-overlay
export PATH="$HOME/.npm-global/bin:$HOME/.luarocks/bin:$HOME/.local/bin:$PATH"
export NPM_CONFIG_PREFIX="$HOME/.npm-global"
export EDITOR="nvim"
export VISUAL="nvim"
export TZ="__HOST_TZ__"
unset LC_ALL

# Vi mode
set -o vi
bind '"\C-r": reverse-search-history'
bind '"\C-s": forward-search-history'
# Disable bracketed paste — prevents escape sequence leakage through script(1) pty
bind 'set enable-bracketed-paste off'

# Aliases
alias v=nvim
alias s="git status"
alias ss="git diff --stat"
alias a="git add"
alias d="git diff"
alias p="git commit -a; git push"
alias todo="nvim tasks/todo.md"
alias issue="nvim tasks/issue.md"
alias lesson="nvim tasks/lessons.md"
alias zl="zellij list-sessions"
alias ze="zellij"
alias za="zellij a"

# AI agent sandbox permissions — agents get full auto-approve
alias claude="claude --permission-mode bypassPermissions"
alias codex='NPM_CONFIG_PREFIX="$HOME/.npm-global" codex --full-auto'
export GEMINI_CLI_AUTO_APPROVE=true

# ── Output capture (Ctrl+Y to copy last cmd+output) ─────────────────────────
# Strategy: session runs inside script(1) which provides a real pty.
# DEBUG trap (preexec) / PROMPT_COMMAND (precmd) record byte offsets in the
# script log to extract output. No re-running commands, no TUI exclusion list.
set +o noclobber
if [[ -z "$_BASH_SCRIPT_LOG" ]]; then
    export _BASH_SCRIPT_LOG=$(mktemp)
    exec script -q --flush "$_BASH_SCRIPT_LOG" -c /bin/bash
fi
shopt -s extglob
_bash_last_out=$(mktemp)
_bash_collect_out=$(mktemp)
_bash_collecting=false
_bash_last_cmd=""
_bash_cmd_offset=0
_bash_cmd_active=false
_bash_in_precmd=false

_bash_strip_escapes() {
    perl -pe '
        s/\x1b\[[0-9;]*[A-Za-z]//g;
        s/\x1b\].*?(\x07|\x1b\\)//gs;
        s/\x1b[^\[\]]//g;
        s/\r//g;
    '
}

# Clipboard via OSC 52 (works through SSH, zellij, tmux)
_bash_clip_copy() {
    local data
    data=$(base64 -w0 2>/dev/null || base64)
    printf '\033]52;c;%s\a' "$data" > /dev/tty
}

# DEBUG trap as preexec — record offset before command output starts
_bash_preexec_trap() {
    $_bash_in_precmd && return
    $_bash_cmd_active && return
    case "$BASH_COMMAND" in
        _bash_precmd*|clast*|clast_append*|ystart|yend) return ;;
    esac
    _bash_cmd_active=true
    local _hist
    _hist=$(HISTTIMEFORMAT='' history 1)
    _hist="${_hist##*([[:space:]])+([0-9])*([[:space:]])}"
    _bash_last_cmd="$_hist"
    [[ -f "$_BASH_SCRIPT_LOG" ]] || { _bash_cmd_offset=0; return; }
    _bash_cmd_offset=$(stat -c%s "$_BASH_SCRIPT_LOG")
}
trap '_bash_preexec_trap' DEBUG

# PROMPT_COMMAND as precmd — extract output between offsets
_bash_precmd() {
    _bash_in_precmd=true
    if $_bash_cmd_active; then
        _bash_cmd_active=false
        [[ -f "$_BASH_SCRIPT_LOG" ]] || { _bash_in_precmd=false; return; }
        local end_offset=$(stat -c%s "$_BASH_SCRIPT_LOG")
        local size=$(( end_offset - _bash_cmd_offset ))
        if (( size > 0 && _bash_cmd_offset > 0 )); then
            tail -c +"$((_bash_cmd_offset + 1))" "$_BASH_SCRIPT_LOG" | head -c "$size" > "$_bash_last_out"
        else
            : > "$_bash_last_out"
        fi
        if $_bash_collecting && [[ -n "$_bash_last_cmd" ]]; then
            { printf '$ %s\n' "$_bash_last_cmd"; cat "$_bash_last_out"; } >> "$_bash_collect_out"
        fi
    fi
    _bash_in_precmd=false
}
PROMPT_COMMAND="_bash_precmd${PROMPT_COMMAND:+;$PROMPT_COMMAND}"

clast() {
    local cmd="$_bash_last_cmd"
    [[ -z "$cmd" ]] && echo "[nothing to copy]" && return
    { printf '$ %s\n' "$cmd"; cat "$_bash_last_out" | _bash_strip_escapes; } \
        | _bash_clip_copy
    echo "[copied]"
}

clast_append() {
    local cmd="$_bash_last_cmd"
    [[ -z "$cmd" ]] && echo "[nothing to copy]" && return
    local prev
    prev=$({ printf '$ %s\n' "$cmd"; cat "$_bash_last_out" | _bash_strip_escapes; })
    if [[ -f /tmp/_bash_clip_buf ]]; then
        printf '%s\n%s' "$(cat /tmp/_bash_clip_buf)" "$prev" > /tmp/_bash_clip_buf
    else
        printf '%s' "$prev" > /tmp/_bash_clip_buf
    fi
    cat /tmp/_bash_clip_buf | _bash_clip_copy
    echo "[appended]"
}

ystart() {
    _bash_collecting=true
    : > "$_bash_collect_out"
    echo "[collecting...]"
}

yend() {
    _bash_collecting=false
    cat "$_bash_collect_out" | _bash_strip_escapes | _bash_clip_copy
    echo "[copied]"
}

# Bind Ctrl+Y / Alt+Y
bind -m vi-insert -x '"\C-y": clast'
bind -m vi-insert -x '"\ey": clast_append'
# END openshell-overlay
BASHEOF
# Inject host timezone (heredoc is single-quoted so can't expand inside)
sed -i "s|__HOST_TZ__|${HOST_TZ:-UTC}|" "$HOME/.bashrc"

# ── Python/Node proxy config ────────────────────────────────────────────────
# pip (Python) and npm (Node) don't auto-detect https_proxy env var.
# Without explicit config, they try direct connections, DNS fails in the
# sandbox, and each request hangs for 15s before retrying through the proxy.
if [ -n "${https_proxy:-}" ]; then
    echo "==> Configuring pip/npm proxy..."
    pip config set global.proxy "$https_proxy" 2>/dev/null || true
    npm config set proxy "$http_proxy" 2>/dev/null || true
    npm config set https-proxy "$https_proxy" 2>/dev/null || true
fi

# ── Workspace dirs ───────────────────────────────────────────────────────────
echo "==> Creating workspace dirs..."
mkdir -p "$HOME/repo" "$HOME/worktree"
mkdir -p "$HOME/.local/share/nvim/lazy"

# ── Credentials (from bootstrap cache) ──────────────────────────────────────
CREDS="/tmp/bootstrap/credentials"
if [ -d "$CREDS" ]; then
    echo "==> Distributing credentials..."
    if [ -f "$CREDS/codex-auth.json" ]; then
        mkdir -p "$HOME/.codex"
        cp "$CREDS/codex-auth.json" "$HOME/.codex/auth.json"
        echo "  [ok] codex auth"
    fi
fi

echo "==> Done."
