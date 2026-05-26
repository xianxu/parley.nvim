#!/usr/bin/env bash
# tart-list-peers.sh — print the set of sibling repos to clone into
# the tart VM, derived from the current repo's go.mod (recursively).
#
# Usage:
#   tart-list-peers.sh [<repo-path>]
#
# Default <repo-path> is the current directory. Output is one absolute
# path per line, starting with the repo itself, followed by every
# transitive substrate upstream declared via `replace <module> => <local-path>`
# in any reached go.mod.
#
# Same parser shape as construct/setup.sh's discover_ancestors so peers
# tracked by the VM clone match peers walked by setup.sh's manifest
# resolution. If go.mod is absent, output is just the repo itself —
# matches the pre-Go-modules tart behavior of single-repo clone.
set -euo pipefail

repo="$(cd "${1:-.}" && pwd -P)"

seen=()
peers=()
queue=("$repo")

_is_seen() {
    local p="$1" s
    for s in "${seen[@]+"${seen[@]}"}"; do
        [[ "$s" == "$p" ]] && return 0
    done
    return 1
}

while [[ ${#queue[@]} -gt 0 ]]; do
    current="${queue[0]}"
    queue=("${queue[@]:1}")

    _is_seen "$current" && continue
    seen+=("$current")
    peers+=("$current")

    [[ -f "$current/go.mod" ]] || continue

    while IFS= read -r line; do
        line="${line%%//*}"
        if [[ "$line" =~ ^[[:space:]]*replace[[:space:]]+[^[:space:]]+([[:space:]]+[^[:space:]]+)?[[:space:]]+=\>[[:space:]]+([^[:space:]]+) ]]; then
            rhs="${BASH_REMATCH[2]}"
            if [[ "$rhs" == /* || "$rhs" == ./* || "$rhs" == ../* ]]; then
                if [[ "$rhs" == /* ]]; then
                    abs="$rhs"
                else
                    abs="$(cd "$current" && cd "$rhs" 2>/dev/null && pwd -P || true)"
                fi
                if [[ -n "$abs" && -d "$abs" ]]; then
                    queue+=("$abs")
                fi
            fi
        fi
    done < "$current/go.mod"
done

printf '%s\n' "${peers[@]}"
