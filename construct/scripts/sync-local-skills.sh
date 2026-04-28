#!/bin/bash
# Ensure construct/local/ and construct/adapted/ skills are symlinked into .claude/skills/.
# Local skills get the configured prefix; adapted skills keep their directory name as-is.
# Runs as a SessionStart hook — silent on success, logs fixes to stderr.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CONFIG="$REPO_ROOT/construct/config.json"
LOCAL_DIR="$REPO_ROOT/construct/local"
ADAPTED_DIR="$REPO_ROOT/construct/adapted"
SKILLS_DIR="$REPO_ROOT/.claude/skills"

mkdir -p "$SKILLS_DIR"

PREFIX=""
if [[ -f "$CONFIG" ]]; then
  PREFIX=$(grep -o '"localPrefix"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG" | sed 's/.*: *"//;s/"//')
  PREFIX="${PREFIX:-xx-}"
fi

# ── Helper: sync one source directory into .claude/skills/ ──────────────────
# Usage: sync_skills <source_dir> <prefix> <rel_path>
sync_skills() {
  local source_dir="$1"
  local prefix="$2"
  local rel_path="$3"  # e.g. "construct/local" or "construct/adapted"

  [[ -d "$source_dir" ]] || return 0

  # Clean up stale symlinks pointing into this source dir
  for link in "$SKILLS_DIR"/*/; do
    [[ -L "${link%/}" ]] || continue
    actual=$(readlink "${link%/}")
    if [[ "$actual" == ../../${rel_path}/* ]]; then
      skill_name="${actual##*/}"
      expected_name="${prefix}${skill_name}"
      if [[ "$(basename "${link%/}")" != "$expected_name" ]]; then
        rm "${link%/}"
        echo "Removed stale symlink: $(basename "${link%/}")" >&2
      fi
    fi
  done

  # Create/fix symlinks
  for skill_dir in "$source_dir"/*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_name=$(basename "$skill_dir")
    link_name="${prefix}${skill_name}"
    link_path="$SKILLS_DIR/$link_name"
    target="../../${rel_path}/$skill_name"

    if [[ -L "$link_path" ]]; then
      actual=$(readlink "$link_path")
      if [[ "$actual" == "$target" ]]; then
        continue
      fi
      rm "$link_path"
      ln -s "$target" "$link_path"
      echo "Fixed symlink: $link_name -> $target" >&2
    elif [[ ! -e "$link_path" ]]; then
      ln -s "$target" "$link_path"
      echo "Created symlink: $link_name -> $target" >&2
    fi
  done
}

# ── Sync both categories ────────────────────────────────────────────────────
sync_skills "$LOCAL_DIR"   "$PREFIX" "construct/local"
sync_skills "$ADAPTED_DIR" ""        "construct/adapted"
