# Local development and recording demo

From the checkout root:

```sh
./parley_app --demo
```

This runs the checkout's current code with the packaged app defaults and the
additions in [init.lua](init.lua). No Homebrew installation or release is needed.
Edit the app code or demo configuration, quit Neovim, and launch again. The
first launch downloads pinned editor plugins; later launches reuse them.
Prerequisites are Neovim, Git and the packaged starter's usual download tools.

Screenkey is enabled for recordings, with text labels such as Enter, Esc and
Tab. Use `:Screenkey` to toggle it. It is not part of the packaged app's default
dependencies. Add demo plugin specs to the `plugins` table in `init.lua`; put
other demo-only editor settings after the shared starter call. The starter
accepts the optional plugin list through Lua `loadfile`, so this file does not
copy the app configuration or its bootstrap logic.

The launcher stages a Git-ignored `demo/workspace/` with an empty chat for the
current day. Its `.parley` marker is nearer than the checkout's marker, making
the workspace the project root. Chats live in `workspace/workshop/parley/`.
HOME and all XDG profile directories are inside the workspace. Normal launches
retain previous takes; a new day gets a new empty seed chat. Explicit Neovim
arguments pass through instead of selecting the seed chat.

## Start another take

Close the demo editor first, then choose a reset:

```sh
./parley_app --demo --reset  # Clear recording content/state; retain dependencies and login
./parley_app --demo         # Recreate the empty chat and launch
```

Reset deletes `workspace/workshop/`, `config/`, `state/`, `cache/`, and the
profile's `data/parley/{chats,notes,exports,parley/persisted}`. This clears
transcripts, notes, exports, command history and saved theme/model choices.
It retains downloaded plugins in `data/parley/lazy/`, managed proxy files and
the demo HOME, including login files. The tracked `demo/init.lua` is retained.

For a complete first-run reproduction:

```sh
./parley_app --demo --nuke
./parley_app --demo
```

Full nuke removes the entire owned workspace, including plugins and demo login
files. Both reset commands **delete content without a backup** and exit without
opening the editor. Keep anything you need outside `workspace/`.
The launcher refuses an unowned workspace, redirected workspace paths and an
active editor. An abandoned `workspace.launcher-lock` is handled like the
regular launcher's lock: close launchers before removing that empty directory.

## Record

Install asciinema separately, then save recordings outside the workspace:

```sh
mkdir -p demo/recordings
asciinema rec --command './parley_app --demo' demo/recordings/take-01.cast
```

`demo/recordings/` is ignored by Git and survives both resets. Choose a new
filename for each take. Provider requests use the usual localhost proxy on
port 8317: an already-running proxy can be shared with regular Neovim or the
installed app and uses its existing accounts. The launcher does not stop or
upgrade that external process. If the demo starts its own proxy, its login
files live under the isolated demo HOME; full nuke deletes those files.

The existing `./parley_app`, `--tutorials` and external `PARLEY_DEMO_DIR` profile
remain available for testing the ordinary app experience. `--demo` uses the
fixed checkout workspace and requires `PARLEY_DEMO_DIR` to be unset.
The older personal `~/parley-demo/` and `~/parley-demo-setup/` are not modified.

Verify the launcher with `python3 tests/packaging/test_local_app.py` and the
shared starter with `make test-spec SPEC=infra/starter`.

## Review a recording

`viewer.html` plays a `.cast` with a precise time readout and a notes pane for
drafting captions. Either open it directly and use **Open .cast**, or serve the
directory to load a cast by URL:

```sh
python3 -m http.server -d demo 8000   # then http://localhost:8000/viewer.html?cast=take1.cast
```

Alt+T pauses and inserts a `~m:ss.s` line into the notes; **Download notes**
saves them as `captions.txt`. Casts with caption markers show the label under
the player; tick "pause at captions" to stop at each one.

Notes are saved in this browser for up to 20 recently saved cast URLs; saving a
newer draft evicts the oldest when that limit is reached. Files opened on the
same page share its draft. A visible warning identifies storage failures; notes
remain editable and downloadable. Download notes you want to keep permanently.
The viewer loads its pinned player from a CDN, so opening it requires network
access. Verify its selection-order and draft-storage behavior with
`node tests/packaging/test_cast_viewer.js`.
