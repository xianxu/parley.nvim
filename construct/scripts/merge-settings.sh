#!/usr/bin/env bash
# Merge settings.ariadne.json + settings.local.json → settings.json
#
# Usage: merge-settings.sh <base-file> <target-dir>
#   base-file:  path to settings.ariadne.json
#   target-dir: directory containing settings.local.json and where settings.json is written
#
# Semantics:
#   - Dicts are deep-merged (local keys override base keys at matching paths).
#   - Arrays at paths listed in base's $merge_keys are unioned (base order, then new local items).
#   - Arrays at other paths are replaced by local.
#   - Scalars: local replaces base.
#   - $comment / $merge_keys / $remove keys are stripped from output.
#
# $remove (in settings.local.json):
#   - Shape: {"$remove": {"<dotted.path>": ["item1", "item2", ...]}}
#   - Filters base's array at <dotted.path> to drop matching items BEFORE the union step.
#   - Use to tighten base — e.g. drop "Bash(rm:*)" from permissions.allow then add it to permissions.deny.
#   - Items not present in base are silently ignored.
#
# If settings.local.json doesn't exist, output is base with meta keys stripped.
set -euo pipefail

BASE_FILE="$1"
TARGET_DIR="$2"
TARGET_FILE="$TARGET_DIR/settings.json"
LOCAL_FILE="$TARGET_DIR/settings.local.json"

if [[ ! -f "$BASE_FILE" ]]; then
    echo "Error: base file not found: $BASE_FILE" >&2
    exit 1
fi

LOCAL_ARG="$LOCAL_FILE"
[[ -f "$LOCAL_FILE" ]] || LOCAL_ARG=""

python3 - "$BASE_FILE" "$LOCAL_ARG" > "$TARGET_FILE" <<'PY'
import json, sys

base_path, local_path = sys.argv[1], sys.argv[2]
base = json.load(open(base_path))
merge_keys = set(base.get('$merge_keys', []))

def strip_meta(obj):
    if isinstance(obj, dict):
        return {k: strip_meta(v) for k, v in obj.items() if not k.startswith('$')}
    return obj

def get_nested(obj, path):
    for p in path.split('.'):
        if not isinstance(obj, dict) or p not in obj:
            return None
        obj = obj[p]
    return obj

def set_nested(obj, path, value):
    parts = path.split('.')
    for p in parts[:-1]:
        obj = obj.setdefault(p, {})
    obj[parts[-1]] = value

def deep_merge(b, l, path=""):
    if isinstance(b, dict) and isinstance(l, dict):
        out = {}
        for k in b:
            if k.startswith('$'):
                continue
            sub = f"{path}.{k}" if path else k
            out[k] = deep_merge(b[k], l[k], sub) if k in l else b[k]
        for k in l:
            if k.startswith('$') or k in b:
                continue
            out[k] = l[k]
        return out
    if isinstance(b, list) and isinstance(l, list):
        if path in merge_keys:
            combined = list(b)
            for item in l:
                if item not in combined:
                    combined.append(item)
            return combined
        return l
    return l

if local_path:
    local = json.load(open(local_path))
    # Apply $remove against base BEFORE merging.
    removals = local.get('$remove', {}) or {}
    if removals:
        base_filtered = json.loads(json.dumps(base))  # deep copy
        for path, items in removals.items():
            current = get_nested(base_filtered, path)
            if isinstance(current, list):
                drop = set(items) if all(isinstance(i, (str, int, float, bool)) for i in items) else None
                if drop is not None:
                    filtered = [x for x in current if x not in drop]
                else:
                    filtered = [x for x in current if x not in items]
                set_nested(base_filtered, path, filtered)
        result = deep_merge(strip_meta(base_filtered), local)
    else:
        result = deep_merge(strip_meta(base), local)
else:
    result = strip_meta(base)

json.dump(result, sys.stdout, indent=2)
print()
PY
