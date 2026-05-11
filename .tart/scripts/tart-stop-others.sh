#!/usr/bin/env bash
# tart-stop-others.sh — interactive multi-select to stop other running
# tart VMs before booting ours. Invoked by `make tart` / `make tart-gui`
# / `make tart-mount` to nudge the operator about forgotten VMs (each
# running tart VM holds 4-8 GB resident).
#
# Args:
#   $1 — current TART_VM. Excluded from the candidate list since the
#        calling target either reuses it (plain tart) or auto-restarts
#        it via its own cold-boot logic (tart-gui, tart-mount).
#
# UX:
#   - Empty candidate list → no-op, exit 0.
#   - Non-interactive stdin (CI, piped) → no-op with a notice.
#   - fzf present → multi-select with Tab; default (no selection, Enter
#                   or Esc) is stop-nothing.
#   - fzf absent → fall back to a single y/N "stop all" prompt.
#
# Never blocks the boot: any failure path falls through to exit 0.

set -euo pipefail

ME="${1:-}"

# tart list columns: Source Name Disk Size Accessed... State
# Accessed has spaces ("3 days ago") but State is always a single
# word at $NF. Source filter skips OCI image entries.
others=$(tart list 2>/dev/null | awk -v me="$ME" \
    'NR>1 && $1=="local" && $2!=me && $NF=="running" {print $2}') || true

if [ -z "$others" ]; then
    exit 0
fi

# Skip the prompt entirely if we can't read from a tty (e.g., piped
# from CI, dropped into a script with redirected stdin). Always
# preferable to silently proceed than to hang waiting for input that
# will never arrive.
if [ ! -t 0 ] || [ ! -t 1 ]; then
    echo "==> Other tart VMs running but stdin isn't a tty; skipping prompt:"
    echo "$others" | sed 's/^/    /'
    exit 0
fi

selected=""
if command -v fzf >/dev/null 2>&1; then
    # Multi-select. Space (or Tab) toggles a row's checkbox; Enter
    # accepts the marked set; Esc cancels.
    #
    # Two non-default behaviors:
    #   --bind 'enter:transform:...' — fzf in --multi mode's default
    #     Enter behavior is "accept ticks if any, else fall back to
    #     the focused row." Two earlier attempts at fixing this
    #     (`accept-non-empty`, then `set -- {+}; [ $# -gt 0 ]`) both
    #     failed for the same reason: the `{+}` placeholder ITSELF
    #     falls back to the focused row when no ticks exist, so
    #     downstream "is the result non-empty" checks always pass.
    #
    #     The actual reliable signal is the FZF_SELECT_COUNT
    #     environment variable that fzf exports to bound commands.
    #     It's 0 when no ticks are set and the positive tick count
    #     otherwise — no fallback. transform runs a shell snippet
    #     and uses its stdout as the action chain: emit `accept`
    #     iff FZF_SELECT_COUNT > 0; otherwise emit a
    #     change-header to nudge the operator.
    #
    #     Verified empirically by inspecting fzf 0.72.0's env-var
    #     dump from a transform action (no docs example for this).
    #
    #   --bind 'space:toggle' — Tab works as the default fzf
    #     selector but feels keyboard-tax-y for a yes/no checkbox
    #     interaction. Space is the natural key for "tick this row";
    #     Tab stays bound by default for muscle memory.
    #
    # --pointer="▶ " and --marker="✓ " both 2 cells wide so the
    # rendered row is `▶ ✓ name` with a visible space between
    # focus indicator and checkbox.
    selected=$(echo "$others" | fzf --multi --no-sort --reverse \
        --height=40% \
        --border \
        --marker="✓ " --pointer="▶ " \
        --bind 'space:toggle' \
        --bind 'enter:transform:[ "$FZF_SELECT_COUNT" -gt 0 ] && echo accept || echo "change-header:Tick at least one VM with Space, then Enter; or Esc to skip."' \
        --header="Other tart VMs running (4-8 GB each). Space/Tab: toggle ✓, Enter: stop ticked, Esc: stop nothing." \
        --prompt="stop> " 2>/dev/null || true)
else
    echo "==> Other tart VMs running:"
    echo "$others" | sed 's/^/    /'
    printf "Stop all? [y/N] (install fzf for per-VM selection) "
    read -r answer
    case "$answer" in
        [yY]|[yY][eE][sS]) selected="$others" ;;
    esac
fi

if [ -n "$selected" ]; then
    while IFS= read -r vm; do
        [ -n "$vm" ] || continue
        echo "    stopping $vm..."
        tart stop "$vm" 2>/dev/null || true
    done <<< "$selected"
fi
