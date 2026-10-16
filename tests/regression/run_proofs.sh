#!/usr/bin/env bash
# #242 regression proofs: the provider fake reproduces #228 and #229 on their
# pre-fix trees and shows the fixed behaviour on this checkout. Exit 0 only when
# every case diverges as expected. Each pre-fix tree is a scratch worktree; the
# only file placed in it is the generated issue vocabulary that setup() reads
# (construct/generated, an untracked build output, not code under test).
set -euo pipefail
BR=$(cd "$(dirname "$0")/../.." && pwd)
W=$(mktemp -d "${TMPDIR:-/tmp}/proof242.XXXXXX") || exit 1
trap 'git -C "$BR" worktree remove --force "${W:?}/pre228" 2>/dev/null; git -C "$BR" worktree remove --force "${W:?}/pre229" 2>/dev/null; rm -rf "${W:?}"' EXIT
mkdir -p "$W/home" "$W/data" "$W/state" "$W/cache" "$W/config"
for t in pre228:dc548920^ pre229:634e33a9^; do
    git -C "$BR" worktree add -q --detach "$W/${t%%:*}" "${t#*:}"
    mkdir -p "$W/${t%%:*}/construct/generated/vocabulary"
    cp "$BR"/construct/generated/vocabulary/*.json "$W/${t%%:*}/construct/generated/vocabulary/"
done
run() { # tree case -> the proof's output lines
    (cd "$1" && env HOME="$W/home" XDG_DATA_HOME="$W/data" XDG_STATE_HOME="$W/state" XDG_CACHE_HOME="$W/cache" \
        XDG_CONFIG_HOME="$W/config" PARLEY_TEST_MODE=1 nvim --headless -u NONE \
        -l "$BR/tests/regression/proof_run.lua" "$BR/tests/fixtures/fake_provider" "$2" 2>&1)
}
fail=0
expect() { # label tree case needle
    local out; out=$(run "$2" "$3")
    if ! grep -q "PROOF-REACHED $3" <<<"$out"; then echo "INCONCLUSIVE $1"; fail=1
    elif grep -qF "$4" <<<"$out"; then echo "ok   $1"
    else echo "FAIL $1 (wanted: $4)"; echo "$out" | sed 's/^/    /' | cut -c1-200; fail=1; fi
}
expect "#228 pre-fix: an empty cap is misreported as empty" "$W/pre228" cap_empty "response is empty"
expect "#228 fixed:   an empty cap names the output-token cap" "$BR" cap_empty "output-token cap"
expect "#228 pre-fix: an empty in-band error is misreported as empty" "$W/pre228" inband_error_empty "response is empty"
expect "#228 fixed:   an empty in-band error names the error" "$BR" inband_error_empty "in-band — Overloaded"
expect "#229 pre-fix: a throwing reader completes as success" "$W/pre229" throwing_handler "LOG COMPLETE"
expect "#229 fixed:   a throwing reader fails the attempt" "$BR" throwing_handler "LOG FAILURE"
exit $fail
