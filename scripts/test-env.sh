#!/bin/sh
# Run a test command from an ALLOWLIST environment (#365): `env -i`, then only
# the names below, copied from this script's own environment. Nothing ambient
# crosses: no COUCH_* or PAIR_* thread (a spec would ask the operator's real
# registry), no terminal owner, no credential. A spec that wants Couch installs
# a fake. This script is the one owner of the list; Makefile.parley starts every
# nvim through it.
#
# Usage: scripts/test-env.sh COMMAND [ARG ...]
#
# The sentinel bin goes first on PATH: a bare `couch` or `pair` that no fake
# shadows is recorded in $PARLEY_TEST_ENV_ROOT/sentinel.log and refused, and the
# Makefile fails a run whose log is not empty.
set -eu
[ "$#" -gt 0 ] || { echo 'test-env: missing command' >&2; exit 2; }
[ -n "${PARLEY_TEST_ENV_ROOT-}" ] || { echo 'test-env: PARLEY_TEST_ENV_ROOT is unset; run through make' >&2; exit 2; }
repo=$(cd "$(dirname "$0")/.." && pwd)

ALLOW='PATH HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME TMPDIR
PARLEY_TEST_ENV_ROOT NVIM_TEST_PLENARY PARLEY_TEST_JITSTAT PARLEY_TEST_JITSTAT_LOG PERF_OUTPUT
LANG LC_ALL LC_CTYPE'

# Build the assignments as positional parameters, so values keep their spaces.
set -- --end-of-command "$@"
for name in $ALLOW; do
    eval "set=\${$name+x}"
    if [ "$set" = x ]; then
        eval "value=\$$name"
        [ "$name" = PATH ] && value="$repo/tests/fixtures/sentinel-bin:$value"
        set -- "$name=$value" "$@"
    fi
done
# Live conformance checks are opt-in by name (PARLEY_LIVE_*); pass those flags.
# A target that records from real services names its credentials explicitly in
# PARLEY_TEST_ENV_PASS (only `make fixtures` does); nothing else crosses.
for name in $(env | sed -n 's/^\(PARLEY_LIVE_[A-Z0-9_]*\)=.*/\1/p') ${PARLEY_TEST_ENV_PASS-}; do
    case "$name" in *[!A-Za-z0-9_]* | '' | [0-9]*) echo "test-env: bad name in PARLEY_TEST_ENV_PASS: $name" >&2; exit 2 ;; esac
    eval "set=\${$name+x}"
    [ "$set" = x ] || continue
    eval "value=\$$name"
    set -- "$name=$value" "$@"
done
set -- "SHELL=/bin/sh" "PARLEY_TEST_SENTINEL_LOG=$PARLEY_TEST_ENV_ROOT/sentinel.log" "$@"

# Split the assignments from the command at the marker.
assignments=0
for arg do
    [ "$arg" = --end-of-command ] && break
    assignments=$((assignments + 1))
done
total=$#
i=0
for arg do
    i=$((i + 1))
    if [ "$i" -le "$assignments" ]; then set -- "$@" "$arg"
    elif [ "$i" -gt $((assignments + 1)) ]; then set -- "$@" "$arg"
    fi
done
shift "$total"
exec /usr/bin/env -i "$@"
