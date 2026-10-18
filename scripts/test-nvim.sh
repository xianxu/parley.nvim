#!/bin/sh
# Print the directory of the nvim `make test` runs (#294): the first candidate
# whose LuaJIT has the arm64 mcode placement fix, as decided by
# tests/helpers/jit_tuning.lua (one owner for the version rule and why it
# matters). Without the fix a spec process can flush its compiled code
# millions of times: one 25s probe ran 173s.
#
# PARLEY_TEST_NVIM=/path/to/nvim overrides the search. Warnings go to stderr;
# stdout is only the directory, or nothing when no nvim is found.
#
# #379, for make test's compat pass:
#   --installed      print the directory of the nvim the operator launches (the
#                    first on PATH), ignoring PARLEY_TEST_NVIM; nothing if none.
#   --supported DIR  exit 0 when DIR/nvim meets parley.version_support.MINIMUM,
#                    else print its refusal to stderr and exit 1.
ROOT=$(cd "$(dirname "$0")/.." && pwd)

has_mcode_fix() {
    PARLEY_ROOT="$ROOT" "$1" --clean --headless \
        -c 'lua package.path = vim.env.PARLEY_ROOT .. "/?.lua;" .. package.path' \
        -c 'lua io.stdout:write(require("tests.helpers.jit_tuning").has_mcode_fix(jit.version) and "yes" or "no")' \
        -c 'qa!' 2>/dev/null | grep -q '^yes$'
}

case "$1" in
    --installed)
        installed=$(command -v nvim) && dirname "$installed"
        exit 0 ;;
    --supported)
        # Fail closed: nvim exits 0 after a -c Lua error, so only an explicit
        # "yes" passes (like has_mcode_fix); anything else is a refusal.
        verdict=$(PARLEY_ROOT="$ROOT" "$2/nvim" --clean --headless \
            -c 'lua package.path = vim.env.PARLEY_ROOT .. "/lua/?.lua;" .. package.path' \
            -c 'lua local ok, s = pcall(require, "parley.version_support"); io.stdout:write(not ok and "could not load parley.version_support" or s.supported(vim.version()) and "yes" or s.refusal(vim.version()))' \
            -c 'qa!' 2>/dev/null)
        [ "$verdict" = yes ] && exit 0
        echo "${verdict:-$2/nvim did not answer the version check}" >&2
        exit 1 ;;
esac

if [ -n "$PARLEY_TEST_NVIM" ]; then
    dirname "$PARLEY_TEST_NVIM"
    exit 0
fi

first=""
for candidate in "$(command -v nvim)" /opt/homebrew/opt/neovim/bin/nvim /usr/local/bin/nvim; do
    [ -x "$candidate" ] || continue
    [ -n "$first" ] || first=$candidate
    if has_mcode_fix "$candidate"; then
        dirname "$candidate"
        exit 0
    fi
done

if [ -n "$first" ]; then
    echo "warning: no nvim with a LuaJIT from 2025-11-05 or later; testing with $first." >&2
    echo "warning: on arm64 macOS its JIT can thrash and specs can miss their deadlines (#294)." >&2
    dirname "$first"
fi
