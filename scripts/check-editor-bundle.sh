#!/bin/sh
# Build the release's own manifest and prove a cold production boot without outbound network.
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/parley-editor-check.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
cd "$repo"
case "$(uname -s)" in
    Darwin) command -v sandbox-exec >/dev/null || { echo 'Offline check requires sandbox-exec' >&2; exit 1; } ;;
    *) echo 'External-network enforcement for this release check requires macOS' >&2; exit 1 ;;
esac
cat > "$scratch/offline.sb" <<'POLICY'
(version 1)
(allow default)
(deny network*)
(allow network-inbound (local ip "localhost:*"))
(allow network-outbound (remote ip "localhost:*"))
POLICY
set -- python3 "$repo/scripts/editor-dependencies.py" --runtime "$repo"
if [ -n "${PARLEY_EDITOR_ARCHIVES:-}" ]; then set -- "$@" --archives "$PARLEY_EDITOR_ARCHIVES"; fi
bundle=$("$@" prepare --root "$scratch/dependencies")
"$@" verify --bundle "$bundle" > "$scratch/before.json"
python3 - "$bundle" >> "$scratch/offline.sb" <<'PY'
import json, sys
print('(deny file-write* (subpath ' + json.dumps(sys.argv[1]) + '))')
PY
sandbox-exec -f "$scratch/offline.sb" python3 -c '
import socket
s = socket.socket()
s.settimeout(2)
try:
    s.connect(("1.1.1.1", 443))
except PermissionError:
    pass
else:
    raise SystemExit("outbound denial was not enforced")
finally:
    s.close()
'
for launch in cold warm; do
    mkdir -p "$scratch/profile/home"
    env HOME="$scratch/profile/home" XDG_CONFIG_HOME="$scratch/profile/config" \
        XDG_DATA_HOME="$scratch/profile/data" XDG_STATE_HOME="$scratch/profile/state" \
        XDG_CACHE_HOME="$scratch/profile/cache" NVIM_APPNAME=parley PARLEY_RUNTIME="$repo" \
        PARLEY_REPO_MODE=0 PARLEY_EDITOR_BUNDLE="$bundle" PARLEY_EDITOR_PROFILE=app \
        PARLEY_NVIM="$(command -v nvim)" PARLEY_STARTER="$repo/packaging/starter-config/init.lua" \
        /usr/bin/time -p sandbox-exec -f "$scratch/offline.sb" sh "$repo/packaging/parley" \
        --headless -i NONE -c "luafile $repo/tests/packaging/editor_bundle.lua"
    echo "PASS $launch offline startup"
done
"$@" verify --bundle "$bundle" > "$scratch/after.json"
cmp "$scratch/before.json" "$scratch/after.json"
# The actual checkout launcher must consume the identical manifest too.
mkdir -p "$scratch/local"
printf 'parley_app v1\n' > "$scratch/local/.parley-app-demo"
local_bundle=$("$@" prepare --root "$scratch/local/editor-dependencies")
"$@" verify --bundle "$local_bundle" > "$scratch/local-before.json"
cmp "$scratch/before.json" "$scratch/local-before.json"
env PARLEY_DEMO_DIR="$scratch/local" /usr/bin/time -p \
    sandbox-exec -f "$scratch/offline.sb" "$repo/parley_app" \
    --headless -i NONE -c "luafile $repo/tests/packaging/editor_bundle.lua"
"$@" verify --bundle "$local_bundle" > "$scratch/local-after.json"
cmp "$scratch/local-before.json" "$scratch/local-after.json"
echo 'PASS local launcher dependency parity and offline startup'
# Exercise --demo itself without writing demo/workspace in the source checkout.
# Runtime folders can point at the source, but the demo and launcher are local
# files so profile ownership, seeding and recording additions take the real path.
recording="$scratch/recording-checkout"
mkdir -p "$recording/demo"
cp "$repo/parley_app" "$recording/parley_app"
cp "$repo/demo/init.lua" "$recording/demo/init.lua"
for directory in lua construct packaging scripts tests; do
    ln -s "$repo/$directory" "$recording/$directory"
done
workspace="$recording/demo/workspace"
mkdir -p "$workspace"
printf 'parley_app v1\n' > "$workspace/.parley-app-demo"
recording_bundle=$("$@" --profile recording prepare --root "$workspace/editor-dependencies")
"$@" --profile recording verify --bundle "$recording_bundle" > "$scratch/recording-before.json"
python3 - "$recording_bundle" >> "$scratch/offline.sb" <<'PY'
import json, sys
print('(deny file-write* (subpath ' + json.dumps(sys.argv[1]) + '))')
PY
env PARLEY_DEMO_DIR= /usr/bin/time -p \
    sandbox-exec -f "$scratch/offline.sb" "$recording/parley_app" --demo \
    --headless -i NONE -c "luafile $repo/tests/packaging/editor_bundle.lua"
"$@" --profile recording verify --bundle "$recording_bundle" > "$scratch/recording-after.json"
cmp "$scratch/recording-before.json" "$scratch/recording-after.json"
echo 'PASS recording launcher, bundled Screenkey, and offline startup'
