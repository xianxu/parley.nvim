#!/usr/bin/env bash
# scripts/sdlc-bootstrap.sh — install the sdlc binary on the developer's PATH.
#
# Idempotent: verifies Go toolchain, builds bin/sdlc via `make sdlc-build`,
# links into $SDLC_INSTALL_BIN (default ~/bin). Used by `make sdlc-bootstrap`.
#
# Spec: workshop/issues/000031-sdlc-checkpoint-binary.md M1.

set -euo pipefail

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; CYAN=$'\033[0;36m'; RESET=$'\033[0m'
info() { printf "%s==>%s %s\n" "$CYAN" "$RESET" "$*" >&2; }
ok()   { printf "%s  [ok]%s %s\n" "$GREEN" "$RESET" "$*" >&2; }
warn() { printf "%s  [!]%s %s\n" "$YELLOW" "$RESET" "$*" >&2; }
die()  { printf "%serror:%s %s\n" "$RED" "$RESET" "$*" >&2; exit 1; }

REPO_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO_DIR"

# ── 1. Toolchain check ──────────────────────────────────────────────────────
if ! command -v go >/dev/null 2>&1; then
    die "go not in PATH — install Go 1.26+ (https://go.dev/dl/) and retry"
fi
GO_VERSION=$(go version | awk '{print $3}')
ok "Go found: ${GO_VERSION}"

# ── 2. cmd/sdlc/ source check ───────────────────────────────────────────────
# When sdlc-bootstrap is invoked from a downstream repo that vendors
# Makefile.workflow but doesn't carry cmd/sdlc/ source (M1 baseline),
# pivot to building from ../ariadne (the upstream). Future milestone
# will harden this for non-sibling layouts.
if [ ! -f cmd/sdlc/main.go ]; then
    upstream="../ariadne"
    if [ -f "$upstream/cmd/sdlc/main.go" ]; then
        warn "cmd/sdlc/main.go missing here — building from $upstream"
        cd "$upstream"
    else
        die "cmd/sdlc/main.go not found here or in $upstream — clone ariadne as a sibling first"
    fi
fi

# ── 3. Build ────────────────────────────────────────────────────────────────
info "building bin/sdlc"
make --no-print-directory sdlc-build

# ── 4. Install onto PATH ────────────────────────────────────────────────────
INSTALL_BIN="${SDLC_INSTALL_BIN:-$HOME/bin}"
mkdir -p "$INSTALL_BIN"

TARGET="$INSTALL_BIN/sdlc"
SRC="$PWD/bin/sdlc"

if [ -L "$TARGET" ] && [ "$(readlink "$TARGET")" = "$SRC" ]; then
    ok "$TARGET already linked"
elif [ -e "$TARGET" ]; then
    warn "$TARGET exists and is not our symlink — leaving it alone"
    warn "rm $TARGET && rerun if you want sdlc on PATH"
else
    ln -s "$SRC" "$TARGET"
    ok "linked $TARGET -> $SRC"
fi

# ── 5. PATH check ───────────────────────────────────────────────────────────
case ":$PATH:" in
    *":$INSTALL_BIN:"*)
        ok "$INSTALL_BIN is on PATH"
        ;;
    *)
        warn "$INSTALL_BIN is NOT on PATH — add it to your shell rc:"
        warn "  export PATH=\"$INSTALL_BIN:\$PATH\""
        ;;
esac

info "done. run: sdlc --help"
