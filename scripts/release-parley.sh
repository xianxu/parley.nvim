#!/bin/sh
# Render using the selected release's own generator and registry. No tag mutation.
set -eu
fail() { printf 'parley release: %s\n' "$*" >&2; exit 1; }
[ "$#" -ge 2 ] && [ "$#" -le 3 ] || fail 'usage: release-parley.sh TAG TAP_DIR [--publish] (run from source checkout)'
tag=$1
tap=$(cd "$2" && pwd -P) || fail 'tap checkout does not exist'
mode=${3:-}
[ -z "$mode" ] || [ "$mode" = '--publish' ] || fail 'unknown option'
printf '%s\n' "$tag" | LC_ALL=C grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$' || fail 'tag must be vMAJOR.MINOR.PATCH'
[ "$(printf '%s' "$tag" | wc -l | tr -d ' ')" = 0 ] || fail 'invalid multiline tag'
source_remote=$(git config --get remote.origin.url) || fail 'run from source checkout'
case "$source_remote" in
    https://github.com/xianxu/parley.nvim.git|https://github.com/xianxu/parley.nvim|git@github.com:xianxu/parley.nvim.git) ;;
    *) fail 'source origin must be xianxu/parley.nvim' ;;
esac
[ "$(git -C "$tap" rev-parse --show-toplevel)" = "$tap" ] || fail 'tap must be repository root'
case "$(git -C "$tap" config --get remote.origin.url)" in
    https://github.com/xianxu/homebrew-parley.git|https://github.com/xianxu/homebrew-parley|git@github.com:xianxu/homebrew-parley.git) ;;
    *) fail 'tap origin must be xianxu/homebrew-parley' ;;
esac
# A generated-but-uncommitted formula is accepted only if its exact bytes match below.
[ -z "$(git -C "$tap" status --porcelain --untracked-files=all -- . ':!Formula/parley.rb')" ] || fail 'tap checkout is dirty'
[ ! -L "$tap/Formula" ] && [ ! -L "$tap/Formula/parley.rb" ] || fail 'formula destination must not be a symlink'
local_commit=$(git rev-parse --verify "refs/tags/$tag^{commit}") || fail 'local release tag is missing'
remote_commit() {
    refs=$(git ls-remote --exit-code "$source_remote" "refs/tags/$tag" "refs/tags/$tag^{}") || fail 'remote release tag is missing'
    printf '%s\n' "$refs" | awk 'NR==1 {sha=$1} /\^\{\}$/ {sha=$1} END {print sha}'
}
[ "$(remote_commit)" = "$local_commit" ] || fail 'immutable tag differs between local and remote'
scratch=$(mktemp -d "${TMPDIR:-/tmp}/parley-release.XXXXXX")
staged=
cleanup() {
    [ -z "$staged" ] || rm -f "$staged"
    rm -rf "$scratch"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
curl --fail --location --silent --show-error --output "$scratch/release.tar.gz" \
    "https://github.com/xianxu/parley.nvim/archive/refs/tags/$tag.tar.gz"
[ "$(remote_commit)" = "$local_commit" ] || fail 'remote tag changed during archive download'
sha256=$(shasum -a 256 "$scratch/release.tar.gz" | awk '{print $1}')
mkdir "$scratch/tree"
tar -xzf "$scratch/release.tar.gz" -C "$scratch/tree" --strip-components=1
for file in packaging/formula.lua packaging/parley packaging/launcher.lua packaging/starter-config/init.lua lua/parley/deps.lua; do
    [ -f "$scratch/tree/$file" ] || fail "tagged archive lacks $file; publish a release containing packaging"
done
PARLEY_RELEASE_TREE="$scratch/tree" PARLEY_RELEASE_TAG="$tag" PARLEY_RELEASE_SHA256="$sha256" \
    PARLEY_RELEASE_OUTPUT="$scratch/parley.rb" nvim -n --headless --noplugin -u NONE -i NONE \
    -c 'lua local ok,err=pcall(function() local f=dofile(vim.env.PARLEY_RELEASE_TREE.."/packaging/formula.lua"); local s=f.render_formula({tag=vim.env.PARLEY_RELEASE_TAG,sha256=vim.env.PARLEY_RELEASE_SHA256}); local out=assert(io.open(vim.env.PARLEY_RELEASE_OUTPUT,"wb")); assert(out:write(s)); assert(out:close()) end); if not ok then io.stderr:write(tostring(err).."\n"); vim.cmd("cquit 1") end' \
    -c 'qa!'
if [ -n "$(git -C "$tap" status --porcelain --untracked-files=all -- Formula/parley.rb)" ]; then
    cmp -s "$scratch/parley.rb" "$tap/Formula/parley.rb" || fail 'tap formula contains uncommitted changes'
fi
mkdir -p "$tap/Formula"
if ! cmp -s "$scratch/parley.rb" "$tap/Formula/parley.rb"; then
    # Stage on the destination filesystem so final publication is atomic.
    staged=$(mktemp "$tap/Formula/.parley.rb.XXXXXX")
    cat "$scratch/parley.rb" > "$staged"
    chmod 644 "$staged"
    mv "$staged" "$tap/Formula/parley.rb"
fi
if [ "$mode" = '--publish' ]; then
    git -C "$tap" add -- Formula/parley.rb
    if ! git -C "$tap" diff --cached --quiet -- Formula/parley.rb; then
        git -C "$tap" commit -m "parley: release $tag" -- Formula/parley.rb
    fi
    # Also retries a previously committed publication whose push was interrupted.
    git -C "$tap" push origin HEAD
fi
printf '%s\n' "$tap/Formula/parley.rb"
