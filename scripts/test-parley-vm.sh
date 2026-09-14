#!/bin/sh
# Host dependencies: Python 3 and Tart. Never imports host credentials.
set -eu
exec python3 "$(dirname "$0")/test-parley-vm.py" "$@"
