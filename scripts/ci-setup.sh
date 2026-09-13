#!/bin/sh
# Invoked by the upstream-owned CI shim after bootstrap, before merge checks.
set -eu
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
: "${RUNNER_TEMP:?CI setup requires RUNNER_TEMP}"
: "${GITHUB_PATH:?CI setup requires GITHUB_PATH}"
peer_root=${ARIADNE_ROOT:-"$repo_root/../ariadne"}
[ -f "$peer_root/go.mod" ] || { echo "bootstrap ariadne before CI setup: $peer_root/go.mod is missing" >&2; exit 1; }
command -v go >/dev/null 2>&1 || { echo "CI setup requires host Go (actions/setup-go)" >&2; exit 1; }
tools_dir="$RUNNER_TEMP/parley-vocabulary-tools"
mkdir -p "$tools_dir"
export GOTOOLCHAIN=auto
export GOBIN="$tools_dir"
# Running in the peer selects the version declared by its go.mod, including
# automatic toolchain download when the host Go version is older.
cd "$peer_root"
go version
go install cuelang.org/go/cmd/cue@v0.16.1
go build -o "$tools_dir/vocabulary" ./cmd/vocabulary
printf '%s\n' "$tools_dir" >> "$GITHUB_PATH"
