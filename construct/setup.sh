#!/usr/bin/env bash
# Ariadne / multi-layer Base Layer Setup
# Bootstraps a target repo by walking each transitive upstream's
# construct/base.manifest in topological order, then applies post-
# processing (creates Makefile, AGENTS.local.md, .gitignore entries,
# mode marker, skill symlink sync).
#
# Upstream discovery
# ------------------
# Two modes:
#   1. Go-managed (target has go.mod) — `go list -m all` returns every
#      transitive module in dependency-resolution order; filter to those
#      shipping a construct/base.manifest. Each becomes an "ancestor"
#      whose manifest is walked into the target. Order matches the
#      layering: depth-1 ancestors first, then descendants.
#   2. Fallback (no go.mod, or no Go) — single ancestor = the script's
#      own resolved upstream. Preserves backward compat with today's
#      `../ariadne/construct/setup.sh` sibling invocation pattern.
#
# Usage:
#   cd /path/to/your-repo && ../ariadne/construct/setup.sh [--vendor] [--yes]
#
#   --vendor   Copy files instead of symlinking (for public repos that
#              can't depend on the upstream as a sibling clone).
#   --symlink  Force symlink mode (default for new adoptions).
#   --yes      Skip confirmation prompts when first-time-setup or
#              switching modes.
#
# Mode is recorded in .ariadne-mode (content: "symlink" or "vendor").
# Idempotent — safe to re-run for updates.
set -euo pipefail

# ── Parse flags ───────────────────────────────────────────────────────────────
MODE=""
ASSUME_YES=false
for arg in "$@"; do
    case "$arg" in
        --vendor) MODE="vendor" ;;
        --symlink) MODE="symlink" ;;
        --yes|-y) ASSUME_YES=true ;;
        *) echo "Error: unknown flag: $arg" >&2; exit 2 ;;
    esac
done

# ── Resolve paths ─────────────────────────────────────────────────────────────
# SCRIPT_REAL = where the script actually lives (followed through symlinks).
# When invoked via `../nous/construct/setup.sh` and that file is a symlink to
# ariadne's setup.sh, SCRIPT_REAL resolves to ariadne's path.
SCRIPT_REAL="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || realpath "${BASH_SOURCE[0]}")")" && pwd)"
# ARIADNE_DIR (legacy name) = the script's resolved upstream root. Used only
# as the fallback ancestor when go.mod-based discovery returns nothing —
# i.e., for first-time bootstrap and pre-Go consumers.
ARIADNE_DIR="$(dirname "$SCRIPT_REAL")"
# pwd -P canonicalizes to the physical path. Without this, on macOS where
# /tmp → /private/tmp, TARGET_DIR comes back as /tmp/... (logical) while
# SCRIPT_REAL resolves to /Users/... (physical). Python's relpath then
# computes a 3-level-up path that resolves wrong when the OS follows the
# symlink from its physical location (which is 4 levels deep). Forcing
# physical here makes both paths consistent so relpath math matches OS
# symlink resolution.
TARGET_DIR="$(pwd -P)"

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BOLD_RED='\033[1;31m'
RESET='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
rel_path() {
    python3 -c "import os.path; print(os.path.relpath('$1', '$2'))"
}

ensure_parent() {
    local path="$1"
    local parent
    parent=$(dirname "$path")
    [[ -d "$parent" ]] || mkdir -p "$parent"
}

create_symlink() {
    local src="$1"  # absolute path in upstream
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
        rm -rf "$dst"
        printf "  ${YELLOW}relinked${RESET} %s (was vendored)\n" "${dst#$TARGET_DIR/}"
    else
        printf "  ${GREEN}linked${RESET}  %s\n" "${dst#$TARGET_DIR/}"
    fi

    ln -s "$rel" "$dst"
}

create_vendored() {
    local src="$1"  # absolute path in upstream
    local dst="$2"  # absolute path in target

    ensure_parent "$dst"

    if [[ ! -e "$src" ]]; then
        printf "  ${YELLOW}missing${RESET} %s (source %s not found)\n" "${dst#$TARGET_DIR/}" "$src"
        return 0
    fi

    if [[ -L "$dst" ]]; then
        rm "$dst"
        cp -RL "$src" "$dst"
        printf "  ${YELLOW}vendored${RESET} %s (was symlinked)\n" "${dst#$TARGET_DIR/}"
        return 0
    fi

    if [[ -e "$dst" ]]; then
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
    touch "$dir/.gitkeep"
    printf "  ${GREEN}created${RESET} %s/\n" "${dir#$TARGET_DIR/}"
}

merge_settings() {
    local base_file="$1"   # upstream's settings.<layer>.json
    local target_file="$2" # target's settings.json (generated, gitignored)

    ensure_parent "$target_file"

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

if [[ -z "$MODE" ]]; then
    MODE="${PREVIOUS_MODE:-symlink}"
fi

if [[ -z "$PREVIOUS_MODE" && "$ARIADNE_DIR" != "$TARGET_DIR" ]]; then
    # First-time-setup prompt only applies when ariadne is setting up a
    # DIFFERENT target. Ariadne itself is the upstream — it has no .ariadne-
    # mode marker by design (the marker records "this layer was set up from
    # an upstream"), so absence of the marker for the ariadne-self case is
    # normal, not first-time. Skip the prompt; the rest of the script runs.
    REPO_NAME=$(basename "$TARGET_DIR")
    printf "${YELLOW}First-time setup in:${RESET} ${BOLD_RED}%s${RESET}\n" "$REPO_NAME"
    printf "  Path: %s\n" "$TARGET_DIR"
    printf "  Mode: %s\n" "$MODE"
    if ! $ASSUME_YES; then
        if [[ ! -t 0 ]]; then
            echo "Error: first-time setup requires --yes in non-interactive runs." >&2
            exit 1
        fi
        read -r -p "Set up base layer in this repo? [y/N] " reply
        case "$reply" in
            y|Y|yes|YES) ;;
            *) echo "Aborted."; exit 1 ;;
        esac
    fi
    printf "\n"
fi

if [[ -n "$PREVIOUS_MODE" && "$PREVIOUS_MODE" != "$MODE" ]]; then
    printf "${YELLOW}Mode change:${RESET} %s → %s\n" "$PREVIOUS_MODE" "$MODE"
    if [[ "$MODE" == "vendor" ]]; then
        echo "  Existing symlinks will be replaced with copies of the source files."
        echo "  Re-running --vendor in the future will refresh those copies."
    else
        echo "  Existing vendored files will be replaced with symlinks into the upstream."
        echo "  The target repo will require the upstream to exist as a sibling to use those files."
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

# ── Ancestor discovery ────────────────────────────────────────────────────────
# Returns one ancestor path per line, in topological order (ancestors of
# transitive depth N appear before depth N-1, so manifests apply foundation-
# first). Empty output if no ancestors found.
#
# Three sources of ancestor candidates, accumulated then ordered:
#
#   1. Recursive `replace <module> => <local-path>` walk starting at
#      target's go.mod. When a replaced path itself has a go.mod with
#      further replace directives, recurse into it. This lets a baby
#      brain declare just `replace nous => ../nous` and have ariadne
#      get picked up transitively via nous's own go.mod. Discovery is
#      BFS; the resulting list is reversed at the end so deeper layers
#      (foundation) come first.
#
#   2. `go list -m -f '{{.Dir}}' all` for Go-imported transitive deps —
#      catches modules that are actually imported in Go code (which
#      require lines survive `go mod tidy`). Adds dirs that the replace
#      walk didn't already find.
#
#   3. Script's own resolved upstream — last-resort fallback for pre-Go
#      consumers or first-time-bootstrap cases where go.mod is absent.
#
# Candidates are filtered to dirs shipping construct/base.manifest; the
# target itself is never an ancestor of itself (its own manifest is
# walked separately AFTER ancestors).
discover_ancestors() {
    local ancestors=()
    local seen=()

    _seen_or_add() {
        # Adds to seen + ancestors. Returns 0 if added, 1 if already seen
        # or filtered out. Args: <abs-dir>
        local dir="$1"
        [[ -z "$dir" ]] && return 1
        [[ "$dir" == "$TARGET_DIR" ]] && return 1
        [[ ! -f "$dir/construct/base.manifest" ]] && return 1
        local s
        for s in "${seen[@]+"${seen[@]}"}"; do
            [[ "$s" == "$dir" ]] && return 1
        done
        seen+=("$dir")
        ancestors+=("$dir")
        return 0
    }

    _parse_replace_paths() {
        # Reads a go.mod from $1, prints each replace's local-path target.
        # Resolves relative paths against $1's dir (canonicalized to
        # physical via pwd -P so subsequent comparisons are consistent).
        local gomod_dir="$1"
        [[ -f "$gomod_dir/go.mod" ]] || return 0
        while IFS= read -r line; do
            line="${line%%//*}"
            if [[ "$line" =~ ^[[:space:]]*replace[[:space:]]+[^[:space:]]+([[:space:]]+[^[:space:]]+)?[[:space:]]+=\>[[:space:]]+([^[:space:]]+) ]]; then
                local rhs="${BASH_REMATCH[2]}"
                if [[ "$rhs" == /* || "$rhs" == ./* || "$rhs" == ../* ]]; then
                    local abs
                    if [[ "$rhs" == /* ]]; then
                        abs="$rhs"
                    else
                        abs="$(cd "$gomod_dir" && cd "$rhs" 2>/dev/null && pwd -P || true)"
                    fi
                    [[ -n "$abs" ]] && printf '%s\n' "$abs"
                fi
            fi
        done < "$gomod_dir/go.mod"
    }

    # Source 1: recursive replace walk (BFS). Each ancestor's own go.mod is
    # then probed for further replace directives, building the chain
    # without requiring the user to redeclare transitive replaces at the
    # leaf.
    if [[ -f "$TARGET_DIR/go.mod" ]]; then
        local queue=("$TARGET_DIR")
        while [[ ${#queue[@]} -gt 0 ]]; do
            local current="${queue[0]}"
            queue=("${queue[@]:1}")
            while IFS= read -r candidate; do
                if _seen_or_add "$candidate"; then
                    queue+=("$candidate")
                fi
            done < <(_parse_replace_paths "$current")
        done

        # Source 2: go list -m all (for code-imported deps that aren't in
        # the replace chain). Order from go list is Go's MVS resolution,
        # which doesn't necessarily match topological-by-replace; we add
        # these after the replace walk so the latter wins for ordering.
        if command -v go >/dev/null 2>&1; then
            while IFS= read -r dir; do
                _seen_or_add "$dir" || true
            done < <(cd "$TARGET_DIR" && go list -m -f '{{.Dir}}' all 2>/dev/null)
        fi
    fi

    # Source 3: script's own upstream (last-resort fallback)
    if [[ ${#ancestors[@]} -eq 0 ]] && [[ "$ARIADNE_DIR" != "$TARGET_DIR" ]]; then
        _seen_or_add "$ARIADNE_DIR" || true
    fi

    # Topological ordering: BFS discovery visits depth-1 first, depth-2
    # second, etc. We want foundation-first (deepest first), so reverse.
    local i
    for ((i=${#ancestors[@]}-1; i>=0; i--)); do
        printf '%s\n' "${ancestors[$i]}"
    done
}

# ── Walk one upstream's manifest into the target ──────────────────────────────
walk_manifest() {
    local upstream="$1"
    local manifest="$upstream/construct/base.manifest"

    if [[ ! -f "$manifest" ]]; then
        printf "  ${YELLOW}skip${RESET}    no construct/base.manifest at %s\n" "$upstream"
        return 0
    fi

    printf "\n  ${CYAN}[%s]${RESET}\n" "$(basename "$upstream")"

    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue

        read -r action source target <<< "$line"
        target="${target:-$source}"

        # Self-reference filter: when walking target's own manifest (upstream
        # == target), entries whose source path equals target path would
        # destroy the canonical file by trying to symlink/copy it onto
        # itself. Skip them — the file is already where it belongs. This
        # lets a layer's manifest contain entries that ARE meaningful when
        # applied to that layer itself (e.g., `symlink construct/skills/X
        # .claude/skills/X` exposes a skill via the Claude-Code-expected
        # path) while protecting entries like `symlink Makefile.nous`
        # (declared for downstream consumers; tautological in nous itself).
        #
        # Exceptions: these actions are not file-shape operations and the
        # self-reference filter doesn't apply to them.
        #   merge — implicit source-rename (reads .X.<layer>.json, writes
        #           .X.json; different files). On self-walk, regenerates
        #           the layer's own settings.json from committed + local.
        #   tool  — modifies the target's go.mod via `go mod edit`. On
        #           self-walk, adds the tool directive to the upstream's
        #           own go.mod (so `go tool sdlc` works locally there too).
        if [[ "$action" != "merge" && "$action" != "tool" && "$upstream/$source" == "$TARGET_DIR/$target" ]]; then
            printf "  ${YELLOW}skipped${RESET} %s (self-reference at canonical location)\n" "$target"
            continue
        fi

        case "$action" in
            symlink)
                # Intra-repo symlinks (self-walk) are immune to vendor mode:
                # the relative link stays valid wherever the repo is cloned,
                # so there's nothing to harden. Vendoring an intra-repo entry
                # would just duplicate content and break the live edit-and-
                # see-it-everywhere ergonomic that motivated declaring it as
                # a symlink in the first place (e.g., nous exposing
                # construct/skills/X at .claude/skills/X for Claude Code's
                # skill loader). Vendor mode exists for cross-repo content,
                # where the upstream may not be present on the consumer's
                # machine — that doesn't apply when source and target are
                # both inside the layer being set up.
                if [[ "$MODE" == "vendor" && "$upstream" != "$TARGET_DIR" ]]; then
                    create_vendored "$upstream/$source" "$TARGET_DIR/$target"
                else
                    create_symlink "$upstream/$source" "$TARGET_DIR/$target"
                fi
                ;;
            scaffold)
                create_scaffold "$TARGET_DIR/$target"
                ;;
            copy)
                ensure_parent "$TARGET_DIR/$target"
                if [[ ! -f "$TARGET_DIR/$target" ]]; then
                    cp "$upstream/$source" "$TARGET_DIR/$target"
                    printf "  ${GREEN}copied${RESET}  %s\n" "$target"
                else
                    printf "  ${YELLOW}skipped${RESET} %s (already exists)\n" "$target"
                fi
                ;;
            merge)
                merge_settings "$upstream/$source" "$TARGET_DIR/$target"
                ;;
            touch)
                ensure_parent "$TARGET_DIR/$source"
                if [[ ! -f "$TARGET_DIR/$source" ]]; then
                    touch "$TARGET_DIR/$source"
                    printf "  ${GREEN}created${RESET} %s\n" "$source"
                fi
                ;;
            tool)
                # Declare a Go tool dependency from this upstream in the
                # target's go.mod. Adds (idempotently) the require + replace
                # + tool directives so `go mod vendor` can populate the
                # source for `make sdlc-build` etc.
                #
                # The single-arg form (`tool cmd/sdlc`) names the path
                # within the upstream module. Self-walk for the upstream's
                # own go.mod skips require+replace (would be circular) but
                # still adds the tool directive (so `go tool sdlc` works
                # locally in the upstream too).
                ensure_go_tool_dependency "$upstream" "$source"
                ;;
            *)
                printf "  ${YELLOW}unknown action: %s${RESET}\n" "$action"
                ;;
        esac
    done < "$manifest"
}

# ── ensure_go_tool_dependency — wire an upstream Go tool into target's go.mod
ensure_go_tool_dependency() {
    local upstream="$1"      # absolute upstream path
    local tool_path="$2"     # relative path within upstream module (e.g. cmd/sdlc)

    if ! command -v go >/dev/null 2>&1; then
        printf "  ${YELLOW}skipped${RESET} tool %s (go toolchain not on PATH)\n" "$tool_path"
        return 0
    fi
    if [[ ! -f "$upstream/go.mod" ]]; then
        printf "  ${YELLOW}skipped${RESET} tool %s (no go.mod in upstream)\n" "$tool_path"
        return 0
    fi

    local upstream_module
    upstream_module=$(awk '/^module / {print $2; exit}' "$upstream/go.mod")

    # Self-walk (target IS the upstream — ariadne adding its own tool
    # directive): operates on target's root go.mod. require + replace
    # would be circular, so only the tool directive is added.
    if [[ "$upstream" == "$TARGET_DIR" ]]; then
        if [[ ! -f "$TARGET_DIR/go.mod" ]]; then
            printf "  ${YELLOW}skipped${RESET} tool %s (self-walk; no go.mod in target)\n" "$tool_path"
            return 0
        fi
        ensure_go_directive_24 "$TARGET_DIR/go.mod"
        ( cd "$TARGET_DIR" && go mod edit -tool "${upstream_module}/${tool_path}" ) \
            && printf "  ${GREEN}declared${RESET} tool %s/%s in go.mod (self; tool only)\n" "$upstream_module" "$tool_path"
        return 0
    fi

    # Cross-target: write to $TARGET_DIR/construct/go.mod. Substrate-tool
    # deps live in a separate Go module from the derivative's app code.
    # `go mod vendor` in construct/ then produces a vendor/ tree
    # containing only the substrate-tool closure — not the derivative's
    # app deps. See workshop/issues/000037 for the rationale.
    local construct_dir="$TARGET_DIR/construct"
    local construct_gomod="$construct_dir/go.mod"

    mkdir -p "$construct_dir"

    if [[ ! -f "$construct_gomod" ]]; then
        # Stub the construct/go.mod. Module path: append "-construct" to
        # the target's root module path (if any), else fall back to a
        # local pseudo-path. Either is valid — the module is local-only
        # (replace directives always resolve to sibling paths; never
        # published to a registry).
        local construct_module
        if [[ -f "$TARGET_DIR/go.mod" ]]; then
            local root_module
            root_module=$(awk '/^module / {print $2; exit}' "$TARGET_DIR/go.mod")
            construct_module="${root_module}-construct"
        else
            local repo_base
            repo_base=$(basename "$TARGET_DIR")
            construct_module="local.construct/${repo_base}"
        fi
        cat > "$construct_gomod" <<EOF
module ${construct_module}

go 1.24
EOF
        printf "  ${GREEN}created${RESET} construct/go.mod (module %s)\n" "$construct_module"
    fi

    ensure_go_directive_24 "$construct_gomod"

    local rel_path
    rel_path=$(python3 -c "import os; print(os.path.relpath('$upstream', '$construct_dir'))" 2>/dev/null || echo "$upstream")

    ( cd "$construct_dir" && {
        go mod edit -require "${upstream_module}@v0.0.0-00010101000000-000000000000"
        go mod edit -replace "${upstream_module}=${rel_path}"
        go mod edit -tool "${upstream_module}/${tool_path}"
    } ) && printf "  ${GREEN}declared${RESET} tool %s/%s in construct/go.mod (require + replace + tool)\n" "$upstream_module" "$tool_path"
}

# Bump the go directive in <gomod> to at least 1.24 (needed for the
# `tool` directive). No-op if already >= 1.24 or if directive absent.
ensure_go_directive_24() {
    local gomod="$1"
    local current_go
    current_go=$(awk '/^go / {print $2; exit}' "$gomod")
    [[ -z "$current_go" ]] && return 0

    local cur_major cur_minor
    cur_major="${current_go%%.*}"
    cur_minor="${current_go#*.}"; cur_minor="${cur_minor%%.*}"
    if (( cur_major < 1 )) || { (( cur_major == 1 )) && (( cur_minor < 24 )); }; then
        ( cd "$(dirname "$gomod")" && go mod edit -go=1.24 ) || true
        printf "  ${YELLOW}bumped${RESET}  go directive in %s to 1.24 (required for tool directive)\n" "$(basename "$(dirname "$gomod")")/go.mod"
    fi
}

# ── Process manifest(s) ───────────────────────────────────────────────────────
ANCESTORS=()
while IFS= read -r dir; do
    [[ -n "$dir" ]] && ANCESTORS+=("$dir")
done < <(discover_ancestors)

if [[ ${#ANCESTORS[@]} -eq 0 ]]; then
    # No upstreams — this is ariadne (the top of the chain). Skip the
    # ancestor walk, but still run self-walk + post-processing below
    # (settings merge, gitignore, skills sync, mode marker, go mod vendor).
    printf "${YELLOW}No upstream layers found${RESET} — running self-walk + post-processing only.\n"
elif [[ ${#ANCESTORS[@]} -eq 1 ]]; then
    printf "${CYAN}Setup:${RESET} %s → %s (mode: %s)\n" "${ANCESTORS[0]}" "$TARGET_DIR" "$MODE"
else
    printf "${CYAN}Setup:${RESET} %d upstream layer(s) → %s (mode: %s)\n" "${#ANCESTORS[@]}" "$TARGET_DIR" "$MODE"
    for upstream in "${ANCESTORS[@]}"; do
        printf "  • %s\n" "$upstream"
    done
fi

if [[ ${#ANCESTORS[@]} -gt 0 ]]; then
    for upstream in "${ANCESTORS[@]}"; do
        walk_manifest "$upstream"
    done
fi

# After ancestors: walk target's own manifest if it has one. This lets a
# layer's manifest contain entries that ARE meaningful when applied to that
# layer itself (e.g., `symlink construct/skills/X .claude/skills/X` exposes
# a skill at the path Claude Code expects). The walk_manifest function's
# self-reference filter protects entries that would be tautological.
if [[ -f "$TARGET_DIR/construct/base.manifest" ]]; then
    walk_manifest "$TARGET_DIR"
fi
printf "\n"

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
APPLY_GITIGNORE="$TARGET_DIR/construct/scripts/apply-gitignore-entries.sh"
if [[ ! -f "$APPLY_GITIGNORE" ]]; then
    APPLY_GITIGNORE="$SCRIPT_REAL/scripts/apply-gitignore-entries.sh"
fi
if [[ -f "$APPLY_GITIGNORE" ]]; then
    bash "$APPLY_GITIGNORE" "$TARGET_DIR" || true
fi

# ── Record mode ───────────────────────────────────────────────────────────────
# Skip mode marker for ariadne-self — the marker records "this target was
# set up from an ariadne upstream," which is meaningless when target IS
# ariadne. Writing `symlink` or `vendor` in ariadne/.ariadne-mode would
# be misleading (ariadne has no upstream to be in symlink/vendor against).
if [[ "$ARIADNE_DIR" != "$TARGET_DIR" ]] && { [[ ! -f "$MODE_MARKER" ]] || [[ "$(tr -d '[:space:]' < "$MODE_MARKER")" != "$MODE" ]]; }; then
    echo "$MODE" > "$MODE_MARKER"
    printf "  ${GREEN}wrote${RESET}   .ariadne-mode (%s)\n" "$MODE"
fi

# ── Vendor Go source (vendor mode + go.mod present + cross-target) ───────────
# In vendor mode, the substrate isn't just text — Go binaries that ship
# from ariadne (like cmd/sdlc) need their source available in the target
# repo too. `go mod vendor` populates vendor/ with the source for every
# require / tool declaration in go.mod, so the binary can be built
# locally without needing the ancestor checked out next door.
#
# Symlink mode skips this — sibling-checkout development resolves Go
# imports via the replace directive's local path, no vendor/ needed.
#
# Self-walk (ARIADNE_DIR == TARGET_DIR) also skips — substrate vendoring
# is for the cross-repo case where the consumer doesn't have ariadne
# next door. Ariadne IS the source; vendoring its own deps into itself
# via the substrate path would pollute the source tree with a vendor/
# directory the substrate doesn't actually need. (If ariadne wants
# vendor/ for its own Go-side reasons, the operator runs `go mod vendor`
# directly — independent of substrate refresh.)
if [[ "$MODE" == "vendor" && -f "$TARGET_DIR/construct/go.mod" && "$ARIADNE_DIR" != "$TARGET_DIR" ]]; then
    if command -v go >/dev/null 2>&1; then
        printf "\n  ${CYAN}vendoring Go source into construct/vendor/${RESET}\n"
        if ( cd "$TARGET_DIR/construct" && go mod tidy && go mod vendor ) 2>&1 | sed 's/^/    /'; then
            printf "  ${GREEN}vendored${RESET} Go source into construct/vendor/\n"
        else
            printf "  ${YELLOW}skipped${RESET} go mod vendor (errors above; non-fatal)\n"
        fi
    else
        printf "  ${YELLOW}skipped${RESET} go mod vendor (go toolchain not on PATH)\n"
    fi
fi

# ── Sync skill symlinks ───────────────────────────────────────────────────────
SYNC_SCRIPT="$TARGET_DIR/construct/scripts/sync-local-skills.sh"
if [[ -f "$SYNC_SCRIPT" ]]; then
    printf "\n"
    bash "$SYNC_SCRIPT" 2>&1 | while read -r line; do printf "  %s\n" "$line"; done
fi

printf "\n${GREEN}Done.${RESET} Review changes, then commit.\n"
