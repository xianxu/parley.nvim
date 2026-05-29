#!/usr/bin/env bash
# bootstrap.sh — first-run entrypoint for a fresh, standalone clone of an
# ariadne-style repo whose upstream peer(s) aren't checked out yet.
#
# WHY THIS FILE IS NOT A SYMLINK
# ------------------------------
# Almost every workflow entrypoint in an ariadne derivative (Makefile,
# Makefile.workflow — which defines `bootstrap:` — construct/setup.sh,
# construct/scripts/bootstrap-peers.sh, AGENTS.md, .tart/, .claude/skills/, …)
# is a sibling-relative SYMLINK into ../<upstream>. On a bare `git clone` with
# no upstream beside it those all dangle, and `make` can't even read its own
# Makefile:
#
#     $ make bootstrap
#     make: Makefile: No such file or directory
#     make: *** No rule to make target `Makefile'.  Stop.
#
# This script is a real committed file precisely so it runs with ZERO substrate
# present. It reads the one substrate file that survives a peerless clone — the
# real construct/go.mod — clones the direct upstream peer(s) as siblings, then
# hands off to `make bootstrap` (whose symlinks now resolve) for the full
# cascade: bootstrap-peers (transitive clones) → refresh → tools → sdlc-install.
#
# It is intentionally generic (no repo-specific knowledge) and idempotent:
# peers already present are skipped; re-running just re-hands-off to make.
# Delivered to derivatives via the manifest `seed` action (write-once copy).
set -euo pipefail

repo_root="$(cd "$(dirname "$0")" && pwd -P)"
cd "$repo_root"
this_repo="$(basename "$repo_root")"

gomod="construct/go.mod"
if [[ ! -f "$gomod" ]]; then
    echo "bootstrap: no $gomod (no substrate peers to clone) — handing off to make." >&2
    exec make bootstrap
fi

origin_url="$(git remote get-url origin 2>/dev/null || true)"

# Walk construct/go.mod for sibling replace directives: `replace <module> => ../<path>`.
# Clone each missing peer using the URL convention bootstrap-peers.sh uses
# (substitute this-repo-name → peer-name in origin). rhs is relative to
# construct/go.mod's own directory (construct/), per Go's replace semantics.
while IFS= read -r line; do
    line="${line%%//*}"
    [[ "$line" =~ ^[[:space:]]*replace[[:space:]]+[^[:space:]]+([[:space:]]+[^[:space:]]+)?[[:space:]]+=\>[[:space:]]+(\.\.[^[:space:]]+) ]] || continue
    rhs="${BASH_REMATCH[2]}"

    # Resolve target path syntactically (it may not exist yet): dirname is
    # guaranteed to exist (it's at or above repo_root), so cd+pwd canonicalizes.
    raw="$repo_root/construct/$rhs"
    parent="$(cd "$(dirname "$raw")" 2>/dev/null && pwd -P || true)"
    [[ -n "$parent" ]] || { echo "bootstrap: cannot resolve peer path for '$rhs'" >&2; exit 1; }
    peer="$parent/$(basename "$raw")"
    name="$(basename "$peer")"

    if [[ -d "$peer" ]]; then
        echo "bootstrap: peer '$name' already present ($peer)"
        continue
    fi
    if [[ -z "$origin_url" ]]; then
        echo "bootstrap: peer '$name' missing and this repo has no 'origin' remote." >&2
        echo "  Clone it manually beside '$this_repo' (as '$peer'), then re-run." >&2
        exit 1
    fi
    peer_url="${origin_url//$this_repo/$name}"
    echo "bootstrap: cloning peer '$name'"
    echo "    from $peer_url"
    echo "    into $peer"
    mkdir -p "$(dirname "$peer")"
    git clone "$peer_url" "$peer"
done < "$gomod"

echo "bootstrap: peers ready — handing off to 'make bootstrap'"
exec make bootstrap
