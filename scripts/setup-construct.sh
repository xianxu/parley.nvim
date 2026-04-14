#!/bin/bash
# Setup the Construct — symlinks private AI substrate from ariadne into this repo.
#
# Prerequisites:
#   - ariadne repo cloned at ../ariadne (relative to this repo root)
#
# What it creates:
#   - construct/ → ../ariadne/construct       (the workspace: sources, intents, versions)
#   - .claude/skills/construct → ../../../ariadne/construct/skill  (the skill file for Claude Code)
#
# Both symlinks are gitignored so nothing private leaks into the public repo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARIADNE_DIR="$(cd "$REPO_ROOT/../ariadne" 2>/dev/null && pwd)" || true

if [ -z "$ARIADNE_DIR" ] || [ ! -d "$ARIADNE_DIR/construct" ]; then
    echo "Error: ariadne repo not found at ../ariadne or missing construct/ directory."
    echo ""
    echo "Expected: $(cd "$REPO_ROOT/.." && pwd)/ariadne/construct/"
    echo ""
    echo "Clone ariadne first:"
    echo "  cd $(cd "$REPO_ROOT/.." && pwd)"
    echo "  git clone <ariadne-repo-url> ariadne"
    exit 1
fi

# Symlink construct/ at repo root
if [ -L "$REPO_ROOT/construct" ]; then
    echo "construct/ symlink already exists, updating..."
    rm "$REPO_ROOT/construct"
elif [ -d "$REPO_ROOT/construct" ]; then
    echo "Error: construct/ exists as a real directory. Remove it first."
    exit 1
fi
ln -s ../ariadne/construct "$REPO_ROOT/construct"
echo "Created: construct/ → ../ariadne/construct"

# Symlink .claude/skills/construct
if [ -L "$REPO_ROOT/.claude/skills/construct" ]; then
    echo ".claude/skills/construct symlink already exists, updating..."
    rm "$REPO_ROOT/.claude/skills/construct"
elif [ -d "$REPO_ROOT/.claude/skills/construct" ]; then
    echo "Error: .claude/skills/construct exists as a real directory. Remove it first."
    exit 1
fi
ln -s ../../../ariadne/construct/skill "$REPO_ROOT/.claude/skills/construct"
echo "Created: .claude/skills/construct → ../../../ariadne/construct/skill"

echo ""
echo "Construct setup complete. Verify:"
echo "  ls -la $REPO_ROOT/construct/"
echo "  ls -la $REPO_ROOT/.claude/skills/construct/"
