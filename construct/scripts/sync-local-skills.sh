#!/bin/bash
# Ensure construct/local/ skills are symlinked into .claude/skills/ with the configured prefix.
# Runs as a SessionStart hook — silent on success, logs fixes to stderr.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CONFIG="$REPO_ROOT/construct/config.json"
LOCAL_DIR="$REPO_ROOT/construct/local"
SKILLS_DIR="$REPO_ROOT/.claude/skills"

if [[ ! -f "$CONFIG" ]] || [[ ! -d "$LOCAL_DIR" ]]; then
  exit 0
fi

PREFIX=$(grep -o '"localPrefix"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG" | sed 's/.*: *"//;s/"//')
PREFIX="${PREFIX:-xx-}"

for skill_dir in "$LOCAL_DIR"/*/; do
  [[ -d "$skill_dir" ]] || continue
  skill_name=$(basename "$skill_dir")
  link_name="${PREFIX}${skill_name}"
  link_path="$SKILLS_DIR/$link_name"
  target="../../construct/local/$skill_name"

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
