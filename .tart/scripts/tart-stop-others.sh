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
    # Multi-select. Tab toggles, Enter confirms current selection,
    # Esc cancels (treated as empty selection via || true). Layout
    # tuned for a short list with a help-text header.
    selected=$(echo "$others" | fzf --multi --no-sort --reverse \
        --height=40% \
        --border \
        --header="Other tart VMs running (4-8 GB each). Tab: toggle, Enter: stop selected, Esc: stop nothing." \
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
