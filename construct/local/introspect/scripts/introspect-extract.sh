#!/usr/bin/env bash
# introspect-extract.sh — full extract+cluster pipeline against a chosen LLM.
#
# Usage:
#   introspect-extract.sh <run-dir> [--activity NAME ...] [--limit N] [--force]
#
# Flags:
#   --activity NAME   Filter to segments whose activity matches NAME. Repeat for OR.
#                     If omitted, all in-taxonomy activities are processed
#                     (skip / out-of-scope / ambiguous are always excluded).
#   --limit N         Stop after N segments. Useful for cheap dogfood passes.
#   --force           Re-extract even if a per-segment pattern file already exists.
#
# Model selection — override either of these env vars to run against a different
# model. Each is a full shell command that takes the system prompt as $1 and
# reads the user content from stdin, writing the model response to stdout.
#
#   EXTRACT_LLM   default: claude --print --system "$1"
#   CLUSTER_LLM   default: claude --print --system "$1"
#
# Examples (override at invocation):
#   EXTRACT_LLM='codex --json --system "$1"' introspect-extract.sh ~/.claude/introspect/cache/<run>
#   EXTRACT_LLM='gemini --system-instruction "$1"' introspect-extract.sh ...
#   EXTRACT_LLM='ollama_oneshot.sh gemma4:e4b "$1"' introspect-extract.sh ...
#
# Outputs (in <run-dir>):
#   patterns/<seg-id>.json   raw per-segment extraction JSON (cached for re-runs)
#   patterns.json            aggregated array with stable ids
#   patterns.summary.json    per-run aggregation stats
#   clusters.json            final cluster JSON from CLUSTER_LLM, then unioned
#                            with human hints loaded from ~/.claude/introspect/hints/
#                            (issue#19; each hint becomes a singleton cluster
#                            tagged with `source: "hint"`)
#
# Cancel-safe: per-segment files are written individually. On Ctrl-C, partial
# progress is preserved; re-run resumes from where it left off (unless --force).

set -euo pipefail

# ── Resolve paths ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || realpath "${BASH_SOURCE[0]}")")" && pwd)"
PROMPTS_DIR="$SCRIPT_DIR/../prompts"
EXTRACT_PROMPT="$PROMPTS_DIR/extract.md"
CLUSTER_PROMPT="$PROMPTS_DIR/cluster.md"

[[ -f "$EXTRACT_PROMPT" ]] || { echo "error: $EXTRACT_PROMPT missing" >&2; exit 2; }
[[ -f "$CLUSTER_PROMPT" ]] || { echo "error: $CLUSTER_PROMPT missing" >&2; exit 2; }

# ── Args ─────────────────────────────────────────────────────────────────────
[[ $# -ge 1 ]] || { sed -n '2,40p' "$0"; exit 2; }
CACHE_DIR="$1"; shift
[[ -d "$CACHE_DIR" ]] || { echo "error: $CACHE_DIR is not a directory" >&2; exit 2; }
[[ -f "$CACHE_DIR/sessions.json" ]] || { echo "error: $CACHE_DIR/sessions.json missing — run normalize.py first" >&2; exit 2; }
[[ -f "$CACHE_DIR/classified.json" ]] || { echo "error: $CACHE_DIR/classified.json missing — run classification first" >&2; exit 2; }

ACTIVITIES=()
LIMIT=""
FORCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --activity) ACTIVITIES+=("$2"); shift 2 ;;
    --limit)    LIMIT="$2"; shift 2 ;;
    --force)    FORCE=1; shift ;;
    -h|--help)  sed -n '2,40p' "$0"; exit 0 ;;
    *)          echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# ── Default model invocation: claude headless with --system-prompt ───────────
# --tools "" disables all tools — this stage is pure text-in / JSON-out, so
# tool wandering would just waste tokens and risk weird outputs.
DEFAULT_LLM='claude --print --system-prompt "$1" --tools ""'
EXTRACT_LLM="${EXTRACT_LLM:-$DEFAULT_LLM}"
CLUSTER_LLM="${CLUSTER_LLM:-$DEFAULT_LLM}"

# ── Pick target segments ─────────────────────────────────────────────────────
list_args=(--cache-dir "$CACHE_DIR" --list)
if [[ ${#ACTIVITIES[@]} -eq 0 ]]; then
  # Default: all in-taxonomy activities
  for a in code-review brainstorming planning debugging implementation exploration; do
    list_args+=(--activity "$a")
  done
else
  for a in "${ACTIVITIES[@]}"; do
    list_args+=(--activity "$a")
  done
fi

# Portable read-loop (mapfile is bash 4+; macOS default is 3.2).
SEGMENTS=()
while IFS= read -r line; do
  [[ -n "$line" ]] && SEGMENTS+=("$line")
done < <(python3 "$SCRIPT_DIR/segment_text.py" "${list_args[@]}" | cut -f1)

if [[ -n "$LIMIT" && ${#SEGMENTS[@]} -gt $LIMIT ]]; then
  TRIMMED=()
  i=0
  for s in "${SEGMENTS[@]}"; do
    [[ $i -ge $LIMIT ]] && break
    TRIMMED+=("$s"); i=$((i+1))
  done
  SEGMENTS=("${TRIMMED[@]}")
fi
TOTAL=${#SEGMENTS[@]}

# ── Per-segment extraction ───────────────────────────────────────────────────
PATTERNS_DIR="$CACHE_DIR/patterns"
mkdir -p "$PATTERNS_DIR"

EXTRACT_SYSTEM="$(cat "$EXTRACT_PROMPT")"

echo "[introspect-extract] $TOTAL segment(s) to process. cache=$PATTERNS_DIR" >&2

i=0
for sid in "${SEGMENTS[@]}"; do
  i=$((i+1))
  # Filename-safe form of segment id: replace # and / with _
  safe="${sid//#/_}"; safe="${safe//\//_}"
  out="$PATTERNS_DIR/$safe.json"

  if [[ -s "$out" && $FORCE -eq 0 ]]; then
    echo "[$i/$TOTAL] $sid: cached" >&2
    continue
  fi

  echo "[$i/$TOTAL] $sid: extracting..." >&2
  if ! python3 "$SCRIPT_DIR/segment_text.py" --cache-dir "$CACHE_DIR" --segment "$sid" \
      | bash -c "$EXTRACT_LLM" _ "$EXTRACT_SYSTEM" \
      > "$out.tmp"
  then
    echo "[$i/$TOTAL] $sid: extract command failed" >&2
    rm -f "$out.tmp"
    continue
  fi
  if [[ ! -s "$out.tmp" ]]; then
    echo "[$i/$TOTAL] $sid: extract returned empty output" >&2
    rm -f "$out.tmp"
    continue
  fi
  mv "$out.tmp" "$out"
done

# ── Aggregate ────────────────────────────────────────────────────────────────
echo "[introspect-extract] aggregating patterns..." >&2
python3 "$SCRIPT_DIR/aggregate_patterns.py" \
  --cache-dir "$CACHE_DIR" \
  --patterns-dir "$PATTERNS_DIR" \
  --out "$CACHE_DIR/patterns.json"

PCOUNT=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(len(d))" "$CACHE_DIR/patterns.json")
if [[ "$PCOUNT" -eq 0 ]]; then
  echo "[introspect-extract] 0 patterns aggregated. Stopping before clustering." >&2
  exit 0
fi
echo "[introspect-extract] aggregated $PCOUNT pattern(s)" >&2

# ── Cluster ──────────────────────────────────────────────────────────────────
echo "[introspect-extract] clustering..." >&2
CLUSTER_SYSTEM="$(cat "$CLUSTER_PROMPT")"
if ! cat "$CACHE_DIR/patterns.json" \
   | bash -c "$CLUSTER_LLM" _ "$CLUSTER_SYSTEM" \
   > "$CACHE_DIR/clusters.json.tmp"
then
  echo "[introspect-extract] cluster command failed" >&2
  rm -f "$CACHE_DIR/clusters.json.tmp"
  exit 3
fi
mv "$CACHE_DIR/clusters.json.tmp" "$CACHE_DIR/clusters.json"

# ── Union human hints (issue#19) ─────────────────────────────────────────────
# Each hint at ~/.claude/introspect/hints/<activity>/<slug>.md becomes its own
# singleton cluster appended to clusters.json, tagged with `source: "hint"`.
# read_hints.py is idempotent — re-running won't double-append.
echo "[introspect-extract] merging human hints..." >&2
python3 "$SCRIPT_DIR/read_hints.py" --merge-into "$CACHE_DIR/clusters.json"

# ── Retirement-candidate probe (issue#19) ────────────────────────────────────
# For each hint cluster, ask the probe LLM whether this run's same-activity
# patterns contradict the hint. Flagged hints get `retirement_candidate: true`
# + `contradicting_evidence`, surfaced first in user review at write-back.
# Override PROBE_LLM to point at a cheaper model — Haiku/local is fine here.
PROBE_LLM="${PROBE_LLM:-$DEFAULT_LLM}"
echo "[introspect-extract] checking hints for retirement candidates..." >&2
PROBE_LLM="$PROBE_LLM" python3 "$SCRIPT_DIR/hint_retire_check.py" --cache-dir "$CACHE_DIR" || \
  echo "[introspect-extract] retirement check failed (non-fatal); hints unflagged" >&2

echo "[introspect-extract] done." >&2
echo "  per-segment: $PATTERNS_DIR/" >&2
echo "  patterns:    $CACHE_DIR/patterns.json" >&2
echo "  clusters:    $CACHE_DIR/clusters.json (extracted ∪ hints, retirement-checked)" >&2
