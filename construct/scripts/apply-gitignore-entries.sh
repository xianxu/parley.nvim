#!/usr/bin/env bash
# Apply the ariadne base-layer .gitignore entries to a target repo.
#
# Idempotent: appends each entry only if not already present (case-
# sensitive, exact-line match via `grep -qxF`).
#
# Extracted from construct/setup.sh so nous/setup.sh's self-mode (which
# bypasses the rest of construct/setup.sh) can call it too — that's
# what closes the gap where ariadne base-layer .gitignore additions
# weren't propagating to nous itself.
#
# Usage:
#   bash construct/scripts/apply-gitignore-entries.sh [TARGET_DIR]
#
# TARGET_DIR defaults to $(pwd). Prints "updated .gitignore" only when
# at least one entry was appended; silent on no-op.

set -euo pipefail

TARGET_DIR="${1:-$(pwd)}"
GITIGNORE="$TARGET_DIR/.gitignore"

GITIGNORE_ENTRIES=(
    ".goto"
    ".openshell/.bootstrap/"
    ".openshell/.base-image-digest"
    ".DS_Store"
)

touch "$GITIGNORE"
changed=false
for entry in "${GITIGNORE_ENTRIES[@]}"; do
    if ! grep -qxF "$entry" "$GITIGNORE"; then
        echo "$entry" >> "$GITIGNORE"
        changed=true
    fi
done

if "$changed"; then
    echo "  updated .gitignore"
fi
