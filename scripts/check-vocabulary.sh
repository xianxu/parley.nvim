#!/bin/sh
# Maintainer gate: compare derived content without modifying the shipped artifact.
set -eu
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
artifact="$repo_root/construct/generated/vocabulary/issue.json"
exporter=${PARLEY_VOCABULARY_EXPORTER:-vocabulary}
while [ "$#" -gt 0 ]; do
    case "$1" in
        --artifact|--exporter)
            [ "$#" -ge 2 ] || { echo "missing value for $1" >&2; exit 2; }
            if [ "$1" = --artifact ]; then artifact=$2; else exporter=$2; fi
            shift 2 ;;
        *) echo "usage: $0 [--artifact FILE] [--exporter EXECUTABLE]" >&2; exit 2 ;;
    esac
done
# Resolve relative inputs before moving to the canonical exporter working tree.
case "$artifact" in /*) ;; *) artifact="$PWD/$artifact" ;; esac
case "$exporter" in */*) case "$exporter" in /*) ;; *) exporter="$PWD/$exporter" ;; esac ;; esac
if ! command -v "$exporter" >/dev/null 2>&1; then
    echo "vocabulary exporter unavailable; install ariadne's vocabulary and CUE tools (CI: scripts/ci-setup.sh)." >&2
    exit 1
fi
command -v python3 >/dev/null 2>&1 || { echo "install Python 3 to compare vocabulary JSON" >&2; exit 1; }
scratch=$(mktemp -d "${TMPDIR:-/tmp}/parley-vocabulary.XXXXXX")
cleanup() {
    result=$?
    trap - EXIT HUP INT TERM
    if ! rm -rf "$scratch"; then
        echo "failed to remove vocabulary scratch: $scratch" >&2
        result=1
    fi
    exit "$result"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
cd "$repo_root"
if ! "$exporter" export --noun issue > "$scratch/issue.json"; then
    echo "vocabulary export failed; check ariadne source and CUE installation" >&2
    exit 1
fi
python3 - "$artifact" "$scratch/issue.json" <<'PY'
import json
import sys

def reject_constant(value):
    raise ValueError("invalid JSON constant: " + value)

try:
    with open(sys.argv[1], encoding="utf-8") as source:
        committed = json.load(source, parse_constant=reject_constant)
    with open(sys.argv[2], encoding="utf-8") as source:
        generated = json.load(source, parse_constant=reject_constant)
except (OSError, ValueError) as error:
    sys.exit("cannot compare vocabulary JSON: " + str(error))
# Canonical JSON preserves boolean/number distinctions Python equality loses,
# while ignoring object key order and whitespace throughout nested structures.
if json.dumps(committed, sort_keys=True) != json.dumps(generated, sort_keys=True):
    sys.exit("issue vocabulary content drift: regenerate and review construct/generated/vocabulary/issue.json")
print("issue vocabulary content matches upstream export")
PY
