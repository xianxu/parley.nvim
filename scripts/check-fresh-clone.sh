#!/bin/sh
# Standalone acceptance. Normal tests call --runtime; --full adds a separate
# indexed archive for architecture tests, and never re-enters --full recursively.
set -eu
script_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mode=runtime
candidate=HEAD
worktree=no
while [ "$#" -gt 0 ]; do
    case "$1" in
        --runtime) mode=runtime ;;
        --full) mode=full ;;
        --worktree) worktree=yes ;;
        --ref) shift; candidate=${1:?--ref needs a git tree/ref} ;;
        --guard) mode=guard; shift; candidate=${1:?--guard needs a directory} ;;
        *) echo "usage: $0 [--runtime|--full] [--ref TREE|--worktree] | --guard DIRECTORY" >&2; exit 2 ;;
    esac
    shift
done
nvim_bin=$(command -v nvim) || { echo 'Neovim is required' >&2; exit 1; }
scratch=$(mktemp -d "${TMPDIR:-/tmp}/parley-fresh-clone.XXXXXX")
cleanup() {
    if ! rm -rf "$scratch"; then
        echo "fresh-clone cleanup failed: $scratch" >&2
        exit 1
    fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir -p "$scratch/home" "$scratch/data" "$scratch/state" "$scratch/cache" "$scratch/tmp" "$scratch/config"
probe() {
    env -i PATH="$PATH" HOME="$scratch/home" XDG_CONFIG_HOME="$scratch/config" \
        XDG_DATA_HOME="$scratch/data" XDG_STATE_HOME="$scratch/state" \
        XDG_CACHE_HOME="$scratch/cache" TMPDIR="$scratch/tmp" \
        NVIM_APPNAME=parley-acceptance PARLEY_PROBE_MODE="$1" \
        PARLEY_PROBE_ROOT="$2" PARLEY_PROBE_VARIANT="${3:-}" \
        PARLEY_PROBE_FILE="$script_root/tests/helpers/fresh_clone_probe.lua" \
        "$nvim_bin" --headless -n --noplugin -i NONE -u NONE \
        -c 'lua dofile(vim.env.PARLEY_PROBE_FILE)'
}
if [ "$mode" = guard ]; then
    probe guard "$candidate"
    exit
fi
if [ "$worktree" = yes ]; then
    # A private index captures modifications/deletions to tracked paths, including
    # staged additions. It never stages untracked operator files or changes the
    # real index. New harness files can run externally until they are committed.
    index_path=$(git -C "$script_root" rev-parse --git-path index)
    case "$index_path" in /*) ;; *) index_path="$script_root/$index_path" ;; esac
    cp "$index_path" "$scratch/index"
    GIT_INDEX_FILE="$scratch/index" git -C "$script_root" add -u
    candidate=$(GIT_INDEX_FILE="$scratch/index" git -C "$script_root" write-tree)
fi
git -C "$script_root" archive --format=tar "$candidate" > "$scratch/candidate.tar"
mkdir "$scratch/runtime"
tar -xf "$scratch/candidate.tar" -C "$scratch/runtime"
(cd "$scratch/runtime" && probe guard "$scratch/runtime")
vocabulary="$scratch/runtime/construct/generated/vocabulary/issue.json"
cp "$vocabulary" "$scratch/issue.json"
for variant in intact missing corrupt malformed; do
    case "$variant" in
        intact) cp "$scratch/issue.json" "$vocabulary" ;;
        missing) rm "$vocabulary" ;;
        corrupt) printf '{broken\n' > "$vocabulary" ;;
        malformed) printf '{"categories":{"open":"invented"}}\n' > "$vocabulary" ;;
    esac
    (cd "$scratch/runtime" && probe runtime "$scratch/runtime" "$variant")
    echo "PASS $variant"
done
if [ "$mode" = full ]; then
    plenary=${PLENARY:-${NVIM_TEST_PLENARY:-}}
    if [ -z "$plenary" ] || [ ! -f "$plenary/lua/plenary/init.lua" ]; then
        echo 'Full acceptance requires PLENARY=/absolute/path/to/plenary.nvim' >&2
        exit 1
    fi
    plenary=$(CDPATH= cd -- "$plenary" && pwd)
    mkdir "$scratch/full"
    tar -xf "$scratch/candidate.tar" -C "$scratch/full"
    git -C "$scratch/full" init -q
    git -C "$scratch/full" add .
    (cd "$scratch/full" && env -i PATH="$PATH" HOME="$scratch/home" \
        XDG_CONFIG_HOME="$scratch/config" XDG_DATA_HOME="$scratch/data" \
        XDG_STATE_HOME="$scratch/state" XDG_CACHE_HOME="$scratch/cache" \
        TMPDIR="$scratch/tmp" NVIM_APPNAME=parley-acceptance \
        PLENARY="$plenary" NVIM_TEST_PLENARY="$plenary" make test)
fi
