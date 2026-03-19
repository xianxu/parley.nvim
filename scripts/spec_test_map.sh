#!/usr/bin/env bash
set -euo pipefail

MAP_FILE="${MAP_FILE:-specs/traceability.yaml}"

resolve_base_ref() {
    if [ -n "${BASE_REF:-}" ]; then
        printf '%s\n' "$BASE_REF"
        return
    fi

    if git rev-parse --verify remote/main >/dev/null 2>&1; then
        printf '%s\n' "remote/main"
        return
    fi

    if git rev-parse --verify origin/main >/dev/null 2>&1; then
        printf '%s\n' "origin/main"
        return
    fi

    if git rev-parse --verify main >/dev/null 2>&1; then
        printf '%s\n' "main"
        return
    fi

    echo "Unable to resolve base ref. Set BASE_REF=<ref> (e.g. remote/main)." >&2
    exit 1
}

normalize_spec_key() {
    local input="$1"
    local key="${input#./}"
    key="${key#specs/}"
    key="${key%.md}"
    printf '%s\n' "$key"
}

list_tests_for_spec() {
    local key
    key="$(normalize_spec_key "$1")"

    awk -v key="$key" '
        BEGIN {
            in_specs = 0
            in_target = 0
            in_tests = 0
        }

        /^specs:[[:space:]]*$/ {
            in_specs = 1
            next
        }

        !in_specs {
            next
        }

        /^  [^[:space:]][^:]*:[[:space:]]*$/ {
            current = $0
            sub(/^  /, "", current)
            sub(/:[[:space:]]*$/, "", current)
            in_target = (current == key)
            in_tests = 0
            next
        }

        {
            if (!in_target) {
                next
            }

            if ($0 ~ /^    tests:[[:space:]]*$/) {
                in_tests = 1
                next
            }

            if ($0 ~ /^    [^[:space:]][^:]*:[[:space:]]*$/) {
                in_tests = 0
                next
            }

            if (in_tests && $0 ~ /^      - [^[:space:]].*$/) {
                line = $0
                sub(/^      - /, "", line)
                print line
            }
        }
    ' "$MAP_FILE"
}

list_changed_specs() {
    local base_ref
    local current_branch
    base_ref="$(resolve_base_ref)"
    current_branch="$(git branch --show-current)"

    {
        if [ "$current_branch" = "main" ]; then
            git diff --name-only --diff-filter=ACMR "$base_ref..HEAD" -- specs
        else
            git diff --name-only --diff-filter=ACMR "$(git merge-base HEAD "$base_ref")" -- specs
        fi
        git ls-files --others --exclude-standard -- specs
    } | awk '/^specs\/.+\/.+\.md$/ { print }' | sort -u
}

cmd="${1:-}"
shift || true

case "$cmd" in
    list-tests)
        if [ "$#" -eq 0 ]; then
            echo "list-tests requires at least one spec key/path" >&2
            exit 1
        fi

        for spec in "$@"; do
            list_tests_for_spec "$spec"
        done | awk 'NF' | sort -u
        ;;

    list-changed-specs)
        list_changed_specs
        ;;

    list-tests-from-changed-specs)
        changed_specs="$(list_changed_specs)"
        if [ -z "$changed_specs" ]; then
            exit 0
        fi

        while IFS= read -r spec; do
            [ -n "$spec" ] || continue
            list_tests_for_spec "$spec"
        done <<< "$changed_specs" | awk 'NF' | sort -u
        ;;

    *)
        cat >&2 <<USAGE
Usage:
  scripts/spec_test_map.sh list-tests <spec-key-or-path> [more...]
  scripts/spec_test_map.sh list-changed-specs
  scripts/spec_test_map.sh list-tests-from-changed-specs
Env:
  BASE_REF=<git ref>    Override base branch ref (default: remote/main, fallback origin/main, then main)
USAGE
        exit 1
        ;;
esac
