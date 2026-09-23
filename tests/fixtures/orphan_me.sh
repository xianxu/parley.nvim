#!/bin/sh
# Start "$@" detached from any surviving parent; write its pid to $1 (#220).
#
# This script EXITS IMMEDIATELY, so the child reparents to init while it is still
# booting. That is the case the change-only watchdog rule misses: by the time the
# child samples its parent, the sample is already 1.
#
# stdio goes to /dev/null because the child would otherwise INHERIT the caller's
# pipes and hold them open after this script exits — a `vim.system(...):wait()` on
# this script then blocks until its timeout and returns code 124. It is also what
# an orphan actually looks like.
pidfile="$1"
shift
"$@" >/dev/null 2>&1 &
echo $! > "$pidfile"
exit 0
