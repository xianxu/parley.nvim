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
    #   --bind 'enter:transform:...' — the obvious-looking
    #     --bind 'enter:accept-non-empty' is a trap; it only
    #     accepts-when-the-LIST-of-matches-is-non-empty, NOT
    #     when ticks exist. fzf in --multi mode's default Enter
    #     behavior is "accept ticks if any, else fall back to the
    #     focused row" — so Enter on an empty selection still
    #     stops whatever row the cursor sat on. The transform
    #     action runs a shell snippet and uses its stdout as the
    #     action chain: `set -- {+}` puts the ticked items into
    #     $@ (fzf quotes them properly for the shell), then
    #     `[ $# -gt 0 ]` distinguishes "ticks exist" from "ticks
    #     are empty" robustly across multi-item ticks. On no
    #     ticks, we change-header to nudge the operator rather
    #     than silently accept.
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
        --bind 'enter:transform:set -- {+}; if [ $# -gt 0 ]; then echo accept; else echo "change-header(Tip: tick at least one VM with Space, then Enter; or Esc to skip.)"; fi' \
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
