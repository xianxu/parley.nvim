#!/usr/bin/env bash
# Ariadne Base Layer Setup
# Bootstraps a target repo with ariadne's portable fragments.
#
# Usage:
#   cd /path/to/your-repo && ../ariadne/construct/setup.sh [--vendor] [--yes]
#
#   --vendor   Copy files instead of symlinking (for public repos that can't
#              depend on ariadne as a sibling clone). Re-running refreshes.
#   --yes      Skip confirmation prompt when switching modes.
#
# Mode is recorded in .ariadne-mode (content: "symlink" or "vendor").
# Idempotent — safe to re-run for updates.
set -euo pipefail

# ── Parse flags ───────────────────────────────────────────────────────────────
MODE="symlink"
ASSUME_YES=false
for arg in "$@"; do
    case "$arg" in
        --vendor) MODE="vendor" ;;
        --symlink) MODE="symlink" ;;
        --yes|-y) ASSUME_YES=true ;;
        *) echo "Error: unknown flag: $arg" >&2; exit 2 ;;
    esac
done

# ── Resolve paths ───────────────────────────���───────────────────────────────��─
# Follow symlinks to find real ariadne location (construct/ dir)
SCRIPT_REAL="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || realpath "${BASH_SOURCE[0]}")")" && pwd)"
ARIADNE_DIR="$(dirname "$SCRIPT_REAL")"
TARGET_DIR="$(pwd)"
MANIFEST="$SCRIPT_REAL/base.manifest"

if [[ "$ARIADNE_DIR" == "$TARGET_DIR" ]]; then
    # Running inside ariadne itself — just sync skill symlinks
    SYNC_SCRIPT="$ARIADNE_DIR/construct/scripts/sync-local-skills.sh"
    if [[ -f "$SYNC_SCRIPT" ]]; then
        bash "$SYNC_SCRIPT" 2>&1
    fi
    exit 0
fi

if [[ ! -f "$MANIFEST" ]]; then
    echo "Error: base.manifest not found at $MANIFEST"
    exit 1
fi

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
RESET='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
rel_path() {
    # Compute relative path from target to ariadne for symlinks
    python3 -c "import os.path; print(os.path.relpath('$1', '$2'))"
}

ensure_parent() {
    local path="$1"
    local parent
    parent=$(dirname "$path")
    [[ -d "$parent" ]] || mkdir -p "$parent"
}

create_symlink() {
    local src="$1"  # absolute path in ariadne
    local dst="$2"  # absolute path in target

    ensure_parent "$dst"

    local rel
    rel=$(rel_path "$src" "$(dirname "$dst")")

    if [[ -L "$dst" ]]; then
        local existing
        existing=$(readlink "$dst")
        if [[ "$existing" == "$rel" ]]; then
            return 0  # already correct
        fi
        rm "$dst"
        printf "  ${YELLOW}updated${RESET} %s\n" "${dst#$TARGET_DIR/}"
    elif [[ -e "$dst" ]]; then
        # Switching from vendor → symlink: replace the vendored copy.
        rm -rf "$dst"
        printf "  ${YELLOW}relinked${RESET} %s (was vendored)\n" "${dst#$TARGET_DIR/}"
    else
        printf "  ${GREEN}linked${RESET}  %s\n" "${dst#$TARGET_DIR/}"
    fi

    ln -s "$rel" "$dst"
}

create_vendored() {
    local src="$1"  # absolute path in ariadne (may itself be a symlink)
    local dst="$2"  # absolute path in target

    ensure_parent "$dst"

    if [[ ! -e "$src" ]]; then
        printf "  ${YELLOW}missing${RESET} %s (source %s not found)\n" "${dst#$TARGET_DIR/}" "$src"
        return 0
    fi

    if [[ -L "$dst" ]]; then
        # Switching from symlink → vendor: replace the symlink with a copy.
        rm "$dst"
        cp -RL "$src" "$dst"
        printf "  ${YELLOW}vendored${RESET} %s (was symlinked)\n" "${dst#$TARGET_DIR/}"
        return 0
    fi

    if [[ -e "$dst" ]]; then
        # Already vendored — refresh from source.
        rm -rf "$dst"
        cp -RL "$src" "$dst"
        printf "  ${YELLOW}refreshed${RESET} %s\n" "${dst#$TARGET_DIR/}"
        return 0
    fi

    cp -RL "$src" "$dst"
    printf "  ${GREEN}vendored${RESET} %s\n" "${dst#$TARGET_DIR/}"
}

create_scaffold() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        return 0
    fi
    mkdir -p "$dir"
    # Add .gitkeep so empty dirs are tracked
    touch "$dir/.gitkeep"
    printf "  ${GREEN}created${RESET} %s/\n" "${dir#$TARGET_DIR/}"
}

merge_settings() {
    local base_file="$1"   # ariadne's settings.ariadne.json
    local target_file="$2" # target's settings.json (generated, gitignored)

    ensure_parent "$target_file"

    # Remove old symlink if present (from previous setup.sh versions)
    [[ -L "$target_file" ]] && rm "$target_file"

    local target_dir
    target_dir=$(dirname "$target_file")
    local had_local=false
    [[ -f "$target_dir/settings.local.json" ]] && had_local=true

    "$SCRIPT_REAL/scripts/merge-settings.sh" "$base_file" "$target_dir"

    if "$had_local"; then
        printf "  ${YELLOW}merged${RESET}  %s (base + local)\n" "${target_file#$TARGET_DIR/}"
    else
        printf "  ${GREEN}created${RESET} %s (from base, no local overrides)\n" "${target_file#$TARGET_DIR/}"
    fi
}

# ── Mode detection & confirmation ─────────────────────────────────────────────
MODE_MARKER="$TARGET_DIR/.ariadne-mode"
PREVIOUS_MODE=""
if [[ -f "$MODE_MARKER" ]]; then
    PREVIOUS_MODE="$(tr -d '[:space:]' < "$MODE_MARKER")"
fi

if [[ -n "$PREVIOUS_MODE" && "$PREVIOUS_MODE" != "$MODE" ]]; then
    printf "${YELLOW}Mode change:${RESET} %s → %s\n" "$PREVIOUS_MODE" "$MODE"
    if [[ "$MODE" == "vendor" ]]; then
        echo "  Existing symlinks will be replaced with copies of the source files."
        echo "  Re-running --vendor in the future will refresh those copies."
    else
        echo "  Existing vendored files will be replaced with symlinks into ariadne."
        echo "  The target repo will require ../ariadne to exist to use those files."
    fi
    if ! $ASSUME_YES; then
        if [[ ! -t 0 ]]; then
            echo "Error: mode change requires --yes in non-interactive runs." >&2
            exit 1
        fi
        read -r -p "Continue? [y/N] " reply
        case "$reply" in
            y|Y|yes|YES) ;;
            *) echo "Aborted."; exit 1 ;;
        esac
    fi
    printf "\n"
fi

# ── Process manifest ──────────────────────────────────────────────────────────
printf "${CYAN}Ariadne setup: %s → %s (mode: %s)${RESET}\n" "$ARIADNE_DIR" "$TARGET_DIR" "$MODE"
printf "\n"

while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// /}" ]] && continue

    # Parse: action source [target]
    read -r action source target <<< "$line"
    target="${target:-$source}"

    case "$action" in
        symlink)
            if [[ "$MODE" == "vendor" ]]; then
                create_vendored "$ARIADNE_DIR/$source" "$TARGET_DIR/$target"
            else
                create_symlink "$ARIADNE_DIR/$source" "$TARGET_DIR/$target"
            fi
            ;;
        scaffold)
            create_scaffold "$TARGET_DIR/$target"
            ;;
        copy)
            ensure_parent "$TARGET_DIR/$target"
            if [[ ! -f "$TARGET_DIR/$target" ]]; then
                cp "$ARIADNE_DIR/$source" "$TARGET_DIR/$target"
                printf "  ${GREEN}copied${RESET}  %s\n" "$target"
            else
                printf "  ${YELLOW}skipped${RESET} %s (already exists)\n" "$target"
            fi
            ;;
        merge)
            merge_settings "$ARIADNE_DIR/$source" "$TARGET_DIR/$target"
            ;;
        touch)
            ensure_parent "$TARGET_DIR/$source"
            if [[ ! -f "$TARGET_DIR/$source" ]]; then
                touch "$TARGET_DIR/$source"
                printf "  ${GREEN}created${RESET} %s\n" "$source"
            fi
            ;;
        *)
            printf "  ${YELLOW}unknown action: %s${RESET}\n" "$action"
            ;;
    esac
done < "$MANIFEST"

# ── Vendor setup infrastructure (makes --vendor replayable) ─────────────────
# In vendor mode, also copy the setup machinery itself so the target repo
# can replay the setup for its own downstream consumers.
if [[ "$MODE" == "vendor" ]]; then
    REPLAY_FILES=(
        "construct/setup.sh"
        "construct/base.manifest"
        "construct/scripts/merge-settings.sh"
    )
    # Also vendor source files referenced by merge actions in the manifest
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue
        read -r act src _tgt <<< "$line"
        if [[ "$act" == "merge" && -f "$ARIADNE_DIR/$src" ]]; then
            REPLAY_FILES+=("$src")
        fi
    done < "$MANIFEST"
    for rf in "${REPLAY_FILES[@]}"; do
        create_vendored "$ARIADNE_DIR/$rf" "$TARGET_DIR/$rf"
    done
fi

# ── Create Makefile if missing ────────────────────────────────────────────────
if [[ ! -f "$TARGET_DIR/Makefile" ]]; then
    cat > "$TARGET_DIR/Makefile" << 'MAKEFILE'
# Canonical repo name from git remote
REPO_NAME := $(shell git remote get-url origin 2>/dev/null | sed 's|.*/||; s|\.git$$||')

# Issue/history paths (override before include if non-standard)
WF_ISSUES_DIR = workshop/issues
WF_HISTORY_DIR = workshop/history

# Include ariadne workflow targets
include Makefile.workflow

# Include local targets (repo-specific)
-include Makefile.local

.PHONY: help

help: help-workflow
	@true
MAKEFILE
    printf "  ${GREEN}created${RESET} Makefile\n"
fi

# Create .parley marker (enables parley.nvim repo mode)
if [[ ! -f "$TARGET_DIR/.parley" ]]; then
    touch "$TARGET_DIR/.parley"
    printf "  ${GREEN}created${RESET} .parley\n"
fi

# Create Makefile.local if missing
if [[ ! -f "$TARGET_DIR/Makefile.local" ]]; then
    cat > "$TARGET_DIR/Makefile.local" << 'MAKEFILE'
# Repo-specific Makefile targets.
# This file is included by Makefile — add your own targets here.
MAKEFILE
    printf "  ${GREEN}created${RESET} Makefile.local\n"
fi

# ── Create AGENTS.local.md if missing ─────────────────────────────────────────
if [[ ! -f "$TARGET_DIR/AGENTS.local.md" ]]; then
    cat > "$TARGET_DIR/AGENTS.local.md" << 'EOF'
# Local Extensions

## Repo-specific rules

<!-- Add repo-specific workflow rules, conventions, or overrides here. -->
<!-- This file is referenced by AGENTS.md via @AGENTS.local.md -->
EOF
    printf "  ${GREEN}created${RESET} AGENTS.local.md\n"
fi

# ── Ensure .gitignore entries ─────────────────────────────────────────────────
GITIGNORE="$TARGET_DIR/.gitignore"
GITIGNORE_ENTRIES=(
    ".constitution-check-state"
    ".goto"
    ".openshell/.bootstrap/"
    ".openshell/.base-image-digest"
)

touch "$GITIGNORE"
gitignore_changed=false
for entry in "${GITIGNORE_ENTRIES[@]}"; do
    if ! grep -qxF "$entry" "$GITIGNORE"; then
        echo "$entry" >> "$GITIGNORE"
        gitignore_changed=true
    fi
done

if "$gitignore_changed"; then
    printf "  ${GREEN}updated${RESET} .gitignore\n"
else
    printf "  .gitignore already up to date\n"
fi

# ── Record mode ───────────────────────────────────────────────────────────────
if [[ ! -f "$MODE_MARKER" ]] || [[ "$(tr -d '[:space:]' < "$MODE_MARKER")" != "$MODE" ]]; then
    echo "$MODE" > "$MODE_MARKER"
    printf "  ${GREEN}wrote${RESET}   .ariadne-mode (%s)\n" "$MODE"
fi

# ── Sync skill symlinks ──────────────────────────────────────────────────────
SYNC_SCRIPT="$TARGET_DIR/construct/scripts/sync-local-skills.sh"
if [[ -f "$SYNC_SCRIPT" ]]; then
    printf "\n"
    bash "$SYNC_SCRIPT" 2>&1 | while read -r line; do printf "  %s\n" "$line"; done
fi

printf "\n${GREEN}Done.${RESET} Review changes, then commit.\n"
