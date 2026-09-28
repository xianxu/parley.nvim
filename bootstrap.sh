#!/usr/bin/env bash
# First-run gateway. weave owns dependency preparation and compilation.
set -euo pipefail
cd "$(cd "$(dirname "$0")" && pwd -P)"

if command -v weave >/dev/null 2>&1 && weave dependencies --help >/dev/null 2>&1; then
    exec weave compile
fi
if ! command -v brew >/dev/null 2>&1; then
    echo 'bootstrap: Homebrew is required to install weave. Install it from https://brew.sh, then rerun ./bootstrap.sh.' >&2
    exit 1
fi
brew install xianxu/ariadne/weave
# A source-built legacy weave may shadow Homebrew on PATH.
weave_prefix="$(brew --prefix xianxu/ariadne/weave)"
exec "$weave_prefix/bin/weave" compile
