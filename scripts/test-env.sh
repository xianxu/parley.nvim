#!/bin/sh
# Run a test command from an ALLOWLIST environment (#365). Every name not on
# the list below is removed, so nothing ambient crosses: no COUCH_* or PAIR_*
# thread (a spec would ask the operator's real registry), no terminal owner,
# no credential. A spec that wants Couch installs a fake. This script is the one
# owner of the list; Makefile.parley starts every nvim through it.
#
# Usage: scripts/test-env.sh COMMAND [ARG ...]
#
# Names are removed with `env -u NAME`, so only NAMES reach an argument list.
# The values of kept credentials stay in the environment, out of `ps`.
#
# The sentinel bin goes first on PATH: a bare `couch` or `pair` that no fake
# shadows is recorded in $PARLEY_TEST_ENV_ROOT/sentinel.log and refused, and the
# Makefile fails a run whose log is not empty.
set -eu
[ "$#" -gt 0 ] || { echo 'test-env: missing command' >&2; exit 2; }
[ -n "${PARLEY_TEST_ENV_ROOT-}" ] || { echo 'test-env: PARLEY_TEST_ENV_ROOT is unset; run through make' >&2; exit 2; }
repo=$(cd "$(dirname "$0")/.." && pwd)

keep='PATH HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME TMPDIR
PARLEY_TEST_ENV_ROOT NVIM_TEST_PLENARY PARLEY_TEST_JITSTAT PARLEY_TEST_JITSTAT_LOG PERF_OUTPUT
PARLEY_TEST_SENTINEL_LOG
LANG LC_ALL LC_CTYPE'

# A live conformance check is opt-in by its flag (PARLEY_LIVE_*), and each flag
# carries exactly what that check needs: one place to read, per check.
live() { eval "[ -n \"\${$1-}\" ]"; }
live PARLEY_LIVE_CONFORMANCE && keep="$keep CLIPROXYAPI_API_KEY"
live PARLEY_LIVE_CLIPBOARD && keep="$keep DISPLAY WAYLAND_DISPLAY"
# The --actors check (make check-couch-actors-live) runs couch_spec ALONE with the
# real thread; RUN_SPEC strips this flag, so a suite never sees the thread.
live PARLEY_LIVE_COUCH && keep="$keep COUCH_THREAD_SCOPE COUCH_THREAD_TAG COUCH_STORE_DIR COUCH_ISOLATED_ROOT COUCH_TREE"
# A target that records from real services names its credentials explicitly
# (only `make fixtures` does).
for name in ${PARLEY_TEST_ENV_PASS-}; do
    case "$name" in *[!A-Za-z0-9_]* | [0-9]*) echo "test-env: bad name in PARLEY_TEST_ENV_PASS: $name" >&2; exit 2 ;; esac
    keep="$keep $name"
done

# Every name in the environment that is not kept becomes `-u NAME`.
set -- --end-of-unsets "$@"
newline='
'
old_ifs=$IFS
IFS=$newline
for name in $(env | sed -n 's/^\([^=][^=]*\)=.*/\1/p' | sort -u); do
    IFS=$old_ifs
    case "$name" in PARLEY_LIVE_*) continue ;; esac
    case " $(echo $keep) " in *" $name "*) continue ;; esac
    set -- -u "$name" "$@"
    IFS=$newline
done
IFS=$old_ifs

# Move the unsets ahead of the assignments and the command.
unsets=0
for arg do
    [ "$arg" = --end-of-unsets ] && break
    unsets=$((unsets + 1))
done
total=$#
i=0
for arg do
    i=$((i + 1))
    [ "$i" -le "$unsets" ] && set -- "$@" "$arg"
done
# The Makefile names a log per target; a direct run gets the root's default.
set -- "$@" "PATH=$repo/tests/fixtures/sentinel-bin:${PATH-/usr/bin:/bin}" "SHELL=/bin/sh" \
    "PARLEY_TEST_SENTINEL_LOG=${PARLEY_TEST_SENTINEL_LOG:-$PARLEY_TEST_ENV_ROOT/sentinel.log}"
j=0
for arg do
    j=$((j + 1))
    [ "$j" -gt $((unsets + 1)) ] && [ "$j" -le "$total" ] && set -- "$@" "$arg"
done
shift "$total"
exec /usr/bin/env "$@"
