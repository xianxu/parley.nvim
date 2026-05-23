#!/usr/bin/env bash
# tart-stop-others.sh — interactive multi-select to stop other running
# tart VMs before booting ours. Invoked by `make tart` / `make tart-gui`
# to (a) head off the silent boot failure when Apple's 2-macOS-VM cap
# is exceeded, and (b) nudge about forgotten VMs that hold 4-8 GB each.
#
# Args:
#   $1 — current TART_VM. Excluded from the candidate list since the
#        calling target either reuses it (plain tart) or auto-restarts
#        it via its own cold-boot logic (tart-gui).
#   $2 — TART_BASE (optional). Used to infer the target VM's OS on
#        first boot, before `tart clone` creates the config file.
#
# Behavior is split into two modes by Apple's macOS-VM cap:
#
#   Cap-enforce mode (target is darwin AND ≥ MAC_VM_CAP darwin VMs
#   already running): boot will fail with "exceeds the system limit"
#   if nothing is stopped. Prompt requires ticking enough macOS VMs
#   to free a slot. Linux VMs are filtered out (can't free a slot).
#   Non-fzf fallback defaults to Y. Non-tty exits 1 fail-fast.
#
#   Soft mode (target is linux, OR fewer than MAC_VM_CAP darwin VMs
#   running): current behavior — Enter with no ticks = stop nothing.
#
# Apple's cap: 2 concurrent macOS guests on all Apple-Silicon Macs
# (matches the macOS EULA; software-enforced inside
# Virtualization.framework). MAC_VM_CAP env var overrides if Apple
# ever bumps it.
#
# Never blocks the boot in soft mode: failure paths fall through to
# exit 0. Cap-enforce non-tty is the only exit-1 path.

set -euo pipefail

ME="${1:-}"
BASE="${2:-}"
MAC_VM_CAP="${MAC_VM_CAP:-2}"

# vm_os <name>: prints "darwin", "linux", or "unknown" based on the
# VM's tart config. Reads ~/.tart/vms/<name>/config.json directly to
# avoid a jq dependency; the file is either pretty-printed or one-
# liner JSON, both match the grep.
vm_os() {
    local cfg="$HOME/.tart/vms/$1/config.json"
    [ -f "$cfg" ] || { echo unknown; return; }
    if   grep -q '"os" *: *"darwin"' "$cfg" 2>/dev/null; then echo darwin
    elif grep -q '"os" *: *"linux"'  "$cfg" 2>/dev/null; then echo linux
    else echo unknown
    fi
}

# infer_target_os <base-image-name>: best-effort guess when the
# target VM doesn't have a config.json yet (first boot, before
# `tart clone`). Falls through to darwin — ariadne's primary use
# case is macOS dev VMs.
infer_target_os() {
    case "${1:-}" in
        *macos*|*darwin*) echo darwin ;;
        *linux*|*ubuntu*|*debian*|*fedora*) echo linux ;;
        *) echo darwin ;;
    esac
}

# tart list columns: Source Name Disk Size Accessed... State
# Accessed has spaces ("3 days ago") but State is always a single
# word at $NF. Source filter skips OCI image entries.
others=$(tart list 2>/dev/null | awk -v me="$ME" \
    'NR>1 && $1=="local" && $2!=me && $NF=="running" {print $2}') || true

if [ -z "$others" ]; then
    exit 0
fi

target_os=$(vm_os "$ME")
[ "$target_os" = "unknown" ] && target_os=$(infer_target_os "$BASE")

# Partition running-others by OS. Only macOS guests count toward
# Apple's cap.
mac_others=""
linux_others=""
while IFS= read -r vm; do
    [ -n "$vm" ] || continue
    case "$(vm_os "$vm")" in
        darwin) mac_others="${mac_others}${vm}"$'\n' ;;
        *)      linux_others="${linux_others}${vm}"$'\n' ;;
    esac
done <<< "$others"

mac_count=$(printf '%s' "$mac_others" | grep -c . || true)

required=0
if [ "$target_os" = "darwin" ] && [ "$mac_count" -ge "$MAC_VM_CAP" ]; then
    # Need (mac_count - (CAP - 1)) stops to leave room for ourselves.
    required=$(( mac_count - (MAC_VM_CAP - 1) ))
fi

# Skip the prompt entirely if we can't read from a tty (e.g., piped
# from CI). Soft mode falls through silently; cap-enforce mode must
# fail fast or the downstream SSH-poll burns 120 s and reports the
# wrong error.
if [ ! -t 0 ] || [ ! -t 1 ]; then
    if [ "$required" -gt 0 ]; then
        echo "==> Apple's $MAC_VM_CAP-macOS-VM cap reached and no tty for prompt." >&2
        echo "    Running macOS VMs: $(printf '%s' "$mac_others" | tr '\n' ' ')" >&2
        echo "    Stop $required of them and retry." >&2
        exit 1
    fi
    echo "==> Other tart VMs running but stdin isn't a tty; skipping prompt:"
    echo "$others" | sed 's/^/    /'
    exit 0
fi

# Candidate list and prompt copy diverge by mode.
if [ "$required" -gt 0 ]; then
    candidates="$mac_others"
    header="Apple's $MAC_VM_CAP-macOS-VM cap reached. Tick at least $required to free a slot."
    enter_min="$required"
    if [ -n "$linux_others" ]; then
        echo "==> (Also running, not subject to the cap: $(printf '%s' "$linux_others" | tr '\n' ' '))"
    fi
else
    candidates="$others"
    header="Other tart VMs running (4-8 GB each). Space: toggle ✓, Enter: stop ticked, Esc: skip."
    enter_min=1
fi

selected=""
if command -v fzf >/dev/null 2>&1; then
    # See the long comment in the prior revision for why we use
    # FZF_SELECT_COUNT in a transform binding rather than
    # accept-non-empty or `{+}` placeholder tricks. Short version:
    # those silently fall back to the focused row when no ticks are
    # set, so "is the result non-empty" downstream is always true.
    # FZF_SELECT_COUNT is the only reliable "ticks actually set"
    # signal exported to bound commands.
    selected=$(printf '%s' "$candidates" | grep -v '^$' | fzf --multi --no-sort --reverse \
        --height=40% \
        --border \
        --marker="✓ " --pointer="▶ " \
        --bind 'space:toggle' \
        --bind "enter:transform:[ \$FZF_SELECT_COUNT -ge $enter_min ] && echo accept || echo \"change-header:Tick at least $enter_min VM(s) with Space, then Enter.\"" \
        --header="$header" \
        --prompt="stop> " 2>/dev/null || true)
else
    echo "==> $header"
    printf '%s' "$candidates" | grep -v '^$' | sed 's/^/    /'
    if [ "$required" -gt 0 ]; then
        printf 'Stop all macOS others? [Y/n] (boot will fail otherwise) '
        read -r answer
        case "$answer" in
            [nN]|[nN][oO]) selected="" ;;
            *)             selected="$mac_others" ;;
        esac
    else
        printf 'Stop all? [y/N] (install fzf for per-VM selection) '
        read -r answer
        case "$answer" in
            [yY]|[yY][eE][sS]) selected="$others" ;;
        esac
    fi
fi

if [ -n "$selected" ]; then
    while IFS= read -r vm; do
        [ -n "$vm" ] || continue
        echo "    stopping $vm..."
        tart stop "$vm" 2>/dev/null || true
    done <<< "$selected"
fi

# If the operator declined the required stop (Esc / answered "n"),
# fail fast so the caller doesn't proceed into a known-failing boot.
if [ "$required" -gt 0 ] && [ -z "$selected" ]; then
    echo "==> Refusing to boot: $MAC_VM_CAP-macOS-VM cap still exceeded." >&2
    exit 1
fi
