#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
PARLEY_RUNTIME=$(pwd)
export PARLEY_RUNTIME
: "${PARLEY_BLINK_RUNTIME:?Set PARLEY_BLINK_RUNTIME to the pinned Blink checkout}"
export PARLEY_BLINK_RUNTIME
pin=$(git -C "$PARLEY_BLINK_RUNTIME" rev-parse HEAD)
[ "$pin" = 78336bc89ee5365633bcf754d93df01678b5c08f ] || { echo 'Blink pin mismatch' >&2; exit 1; }
spell_tmp=$(mktemp -d /tmp/parley-spell-compat.XXXXXX)
trap 'rm -rf "$spell_tmp"' EXIT HUP INT TERM
for profile in plugin app; do
    mkdir -p "$spell_tmp/$profile/home"
    env HOME="$spell_tmp/$profile/home" XDG_CONFIG_HOME="$spell_tmp/$profile/config" \
        XDG_DATA_HOME="$spell_tmp/$profile/data" XDG_STATE_HOME="$spell_tmp/$profile/state" \
        XDG_CACHE_HOME="$spell_tmp/$profile/cache" NVIM_APPNAME=parley PARLEY_TEST_MODE=1 \
        PARLEY_SPELL_PROFILE="$profile" nvim --headless -u NONE -i NONE \
        -c 'luafile tests/packaging/spell_compatibility.lua'
done
mkdir -p "$spell_tmp/completion/home"
env HOME="$spell_tmp/completion/home" XDG_CONFIG_HOME="$spell_tmp/completion/config" \
    XDG_DATA_HOME="$spell_tmp/completion/data" XDG_STATE_HOME="$spell_tmp/completion/state" \
    XDG_CACHE_HOME="$spell_tmp/completion/cache" NVIM_APPNAME=parley PARLEY_TEST_MODE=1 \
    nvim --headless -u NONE -i NONE -c 'luafile tests/packaging/completion_compatibility.lua'
