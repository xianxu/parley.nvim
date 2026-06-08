#!/usr/bin/env bash
# bootstrap.sh — first-run entrypoint for a bare clone of an ariadne derivative
# whose upstream peers aren't checked out yet.
#
# A real committed file, not a symlink: every other entrypoint (Makefile,
# construct/, AGENTS.md, …) is a sibling-relative symlink into ../<upstream>, so
# on a peerless clone they all dangle and `make` can't even read its Makefile.
# This reads the files that survive — construct/deps (substrate, #60) + the root
# go.mod (Go app-dep siblings) — clones the upstream peers as siblings, then
# `exec make bootstrap` (symlinks now resolve) for the full cascade
# (ensure-go → bootstrap-peers → refresh → tools → sdlc-install → data-deps).
#
# The clone walk is TRANSITIVE (ariadne#45): each derivative declares only its
# direct upstream, but a 3-deep chain (foo→mid→ariadne) symlinks the Makefile
# through every level, so `make` can't start until the whole chain is on disk.
# In-process BFS (not recursing into each peer's bootstrap.sh, whose `exec make`
# would orphan the top repo); depends only on each peer's go.mod.
#
# Idempotent (present peers are just traversed). Delivered via the manifest
# `seed` action (write-once). The replace-line parser below is kept identical to
# construct/scripts/.../list-peers.sh, locked by the drift test in
# construct/scripts/test/.
#
# Env hooks: BOOTSTRAP_DRY_RUN=1 lists the peer set, clones nothing, no handoff;
# BOOTSTRAP_CLONE_ONLY=1 clones transitively but skips the handoff.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")" && pwd -P)"
cd "$repo_root"

DRY_RUN="${BOOTSTRAP_DRY_RUN:-}"
CLONE_ONLY="${BOOTSTRAP_CLONE_ONLY:-}"
MAX_DEPTH="${BOOTSTRAP_MAX_DEPTH:-5}"

# Hand off to make (or no-op under the test hooks).
handoff() {
    if [[ -n "$DRY_RUN" || -n "$CLONE_ONLY" ]]; then
        echo "bootstrap: (clone-only) skipping 'make bootstrap' handoff." >&2
        exit 0
    fi
    echo "bootstrap: peers ready — handing off to 'make bootstrap'"
    exec make bootstrap
}

# No substrate source → no peers to clone; hand off. Substrate lives in
# construct/deps (#60); root go.mod carries any real Go app-dep siblings. The
# legacy construct/go.mod substrate carrier is no longer read (#60 M4).
if [[ ! -f go.mod && ! -f construct/deps ]]; then
    echo "bootstrap: no go.mod / construct/deps (no substrate peers) — handing off to make." >&2
    handoff
fi

# Peer clone URL: substitute this-repo-name → peer-name in origin (global subst,
# so an org embedding the repo name rewrites too). Override per-peer with the env
# var PEER_URL_<name> (name sanitized: non-alphanumerics → '_').
peer_url() {
    local name="$1" origin="$2" this_name="$3" var val
    var="PEER_URL_$(printf '%s' "$name" | tr -c '[:alnum:]' '_')"
    val="${!var:-}"
    if [[ -n "$val" ]]; then printf '%s\n' "$val"; return 0; fi
    if [[ -z "$origin" ]]; then
        echo "bootstrap: peer '$name' missing and this repo has no 'origin' remote." >&2
        echo "  Clone it manually beside this repo, or set ${var}=<url>, then re-run." >&2
        return 1
    fi
    printf '%s\n' "${origin//$this_name/$name}"
}

# ── Transitive clone BFS ───────────────────────────────────────────────────────
# queue entries are "depth:abspath"; seen dedups, discovered is the peer set.
queue=("0:$repo_root")
seen=()
discovered=()

_is_seen() {
    local p="$1" s
    for s in "${seen[@]+"${seen[@]}"}"; do [[ "$s" == "$p" ]] && return 0; done
    return 1
}

# walk_gomod <gomod-file> <base-dir> <origin> <this-name> <depth>
# Clone each local-path replace target missing on disk (unless DRY_RUN) and
# enqueue it at depth+1. Relative targets resolve against base-dir (the go.mod's
# own dir, per Go's replace semantics).
walk_gomod() {
    local gm="$1" base="$2" origin="$3" this_name="$4" depth="$5"
    local line rhs raw parent peer name url real
    [[ -f "$gm" ]] || return 0
    while IFS= read -r line; do
        line="${line%%//*}"
        [[ "$line" =~ ^[[:space:]]*replace[[:space:]]+[^[:space:]]+([[:space:]]+[^[:space:]]+)?[[:space:]]+=\>[[:space:]]+([^[:space:]]+) ]] || continue
        rhs="${BASH_REMATCH[2]}"
        case "$rhs" in /*|./*|../*) ;; *) continue ;; esac  # local-path targets only
        if [[ "$rhs" == /* ]]; then raw="$rhs"; else raw="$base/$rhs"; fi
        # Resolve via the (always-present) parent dir, so absent peers resolve too.
        parent="$(cd "$(dirname "$raw")" 2>/dev/null && pwd -P || true)"
        [[ -n "$parent" ]] || { echo "bootstrap: cannot resolve peer path for '$rhs' (in $gm)" >&2; exit 1; }
        peer="$parent/$(basename "$raw")"
        name="$(basename "$peer")"

        if [[ ! -d "$peer" ]]; then
            if [[ -n "$DRY_RUN" ]]; then
                echo "bootstrap: (dry-run) would clone '$name' → $peer" >&2
            else
                url="$(peer_url "$name" "$origin" "$this_name")" || exit 1
                echo "bootstrap: cloning peer '$name'" >&2
                echo "    from $url" >&2
                echo "    into $peer" >&2
                mkdir -p "$(dirname "$peer")"
                git clone "$url" "$peer"
            fi
        else
            echo "bootstrap: peer '$name' already present ($peer)" >&2
        fi

        # Canonicalize if present (post-clone); else keep the syntactic path (dry-run).
        if [[ -d "$peer" ]]; then real="$(cd "$peer" && pwd -P)"; else real="$peer"; fi
        discovered+=("$real")
        queue+=("$((depth + 1)):$real")
    done < "$gm"
}

# walk_deps <repo-root> <origin> <this-name> <depth>
# INLINE copy of construct/scripts/lib-deps.sh:deps_substrate_targets + walk_gomod's
# clone/enqueue — bootstrap.sh can't source the symlinked lib on a bare clone.
# Locked to deps_substrate_targets() by construct/scripts/test/bootstrap-transitive.test.sh;
# keep the parse identical. construct/deps `substrate` rows carry sibling paths
# relative to the REPO ROOT (not construct/), already absolute after resolution.
walk_deps() {
    local root="$1" origin="$2" this_name="$3" depth="$4"
    local deps="$root/construct/deps" line kind target raw parent peer name url real
    [[ -f "$deps" ]] || return 0
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        # shellcheck disable=SC2086
        set -- $line
        [[ $# -ge 2 ]] || continue
        kind="$1"; target="$2"
        [[ "$kind" == "substrate" ]] || continue
        if [[ "$target" == /* ]]; then raw="$target"; else raw="$root/$target"; fi
        parent="$(cd "$(dirname "$raw")" 2>/dev/null && pwd -P || true)"
        # Clone-driver semantics: abort loudly on an unresolvable manifest path.
        # lib-deps.sh:deps_substrate_targets DELIBERATELY differs (skips silently)
        # — the drift test only locks the all-peers-present case, so keep these in sync.
        [[ -n "$parent" ]] || { echo "bootstrap: cannot resolve peer path for '$target' (in $deps)" >&2; exit 1; }
        peer="$parent/$(basename "$raw")"
        name="$(basename "$peer")"

        if [[ ! -d "$peer" ]]; then
            if [[ -n "$DRY_RUN" ]]; then
                echo "bootstrap: (dry-run) would clone '$name' → $peer" >&2
            else
                url="$(peer_url "$name" "$origin" "$this_name")" || exit 1
                echo "bootstrap: cloning peer '$name'" >&2
                echo "    from $url" >&2
                echo "    into $peer" >&2
                mkdir -p "$(dirname "$peer")"
                git clone "$url" "$peer"
            fi
        else
            echo "bootstrap: peer '$name' already present ($peer)" >&2
        fi

        if [[ -d "$peer" ]]; then real="$(cd "$peer" && pwd -P)"; else real="$peer"; fi
        discovered+=("$real")
        queue+=("$((depth + 1)):$real")
    done < "$deps"
}

while [[ ${#queue[@]} -gt 0 ]]; do
    entry="${queue[0]}"
    queue=("${queue[@]:1}")
    depth="${entry%%:*}"
    dir="${entry#*:}"

    _is_seen "$dir" && continue
    seen+=("$dir")

    if (( depth > MAX_DEPTH )); then
        echo "bootstrap: peer chain deeper than MAX_DEPTH ($MAX_DEPTH) at $dir" >&2
        echo "  Likely a replace cycle the visited-set didn't catch, or a genuinely" >&2
        echo "  deep chain — raise BOOTSTRAP_MAX_DEPTH if the latter." >&2
        exit 1
    fi

    # dir is on disk (root, or cloned before enqueue). Each child clones from
    # dir's own origin family (this_name → child-name substitution).
    origin="$(git -C "$dir" remote get-url origin 2>/dev/null || true)"
    this_name="$(basename "$dir")"

    # Substrate is in construct/deps (#60); the root go.mod carries any real Go
    # app-dep siblings (e.g. brain's `replace nous`). Both walked; the main
    # loop's seen-set dedups a peer named by more than one. The legacy
    # construct/go.mod substrate carrier is no longer read (#60 M4).
    walk_gomod "$dir/go.mod" "$dir" "$origin" "$this_name" "$depth"
    walk_deps "$dir" "$origin" "$this_name" "$depth"
done

if [[ -n "$DRY_RUN" ]]; then
    # Emit the peer set (deduped, sorted) for inspection / drift test.
    if [[ ${#discovered[@]} -gt 0 ]]; then
        printf '%s\n' "${discovered[@]}" | sort -u
    fi
    exit 0
fi

handoff
