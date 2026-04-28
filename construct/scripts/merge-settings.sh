#!/usr/bin/env bash
# Merge settings.ariadne.json + settings.local.json → settings.json
#
# Usage: merge-settings.sh <base-file> <target-dir>
#   base-file:  path to settings.ariadne.json
#   target-dir: directory containing settings.local.json and where settings.json is written
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

if [[ ! -f "$LOCAL_FILE" ]]; then
    # No local overrides — strip meta keys from base
    python3 -c "
import json, sys
base = json.load(open('$BASE_FILE'))
base.pop('\$comment', None)
base.pop('\$merge_keys', None)
json.dump(base, sys.stdout, indent=2)
print()
" > "$TARGET_FILE"
else
    # Merge base + local
    python3 -c "
import json, sys

base = json.load(open('$BASE_FILE'))
local = json.load(open('$LOCAL_FILE'))
merge_keys = base.get('\$merge_keys', [])

def get_nested(obj, path):
    parts = path.split('.')
    for p in parts:
        if isinstance(obj, dict):
            obj = obj.get(p)
        else:
            return None
    return obj

def set_nested(obj, path, value):
    parts = path.split('.')
    for p in parts[:-1]:
        obj = obj.setdefault(p, {})
    obj[parts[-1]] = value

result = dict(base)
result.pop('\$comment', None)
result.pop('\$merge_keys', None)

# Apply local on top (scalars replace)
for key in local:
    if key.startswith('\$'):
        continue
    result[key] = local[key]

# For merge keys, combine base + local arrays
for mk in merge_keys:
    base_val = get_nested(base, mk)
    local_val = get_nested(local, mk)
    if isinstance(base_val, list) and isinstance(local_val, list):
        combined = list(base_val)
        for item in local_val:
            if item not in combined:
                combined.append(item)
        set_nested(result, mk, combined)
    elif isinstance(base_val, list) and local_val is None:
        set_nested(result, mk, base_val)

json.dump(result, sys.stdout, indent=2)
print()
" > "$TARGET_FILE"
fi
