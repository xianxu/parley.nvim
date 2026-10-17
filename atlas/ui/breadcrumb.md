# Breadcrumb winbar

Alt+o records a trail after a successful file landing. The trail belongs to the destination window; another window showing the same file can have a different trail. Failed, cancelled and stale resolver completions cannot turn a later file open into a followed link.

The shared [document band](../modes/session_sync.md) starts with a nine-column lock cell: `free`, `yours ●`, `stale`, `agent…` or `unknown`. The dot is evidence of unsubmitted content relative to the acquisition baseline, including after auto-save. A lock whose baseline is unknown shows `yours` without a dot. Receipt/error text follows the cell and trail; it never hides the lock or changes its background highlight. Coordinator notices are overlays on an attached state owner; without one, proven-plain and unknown membership supply a blank or unknown cell. State refreshes preserve the notice until its owner clears it.

The trail uses basename labels without `.md` or a `YYYY-MM-DD-` prefix. Duplicate labels gain enough parent components to distinguish them. When stripping a date prefix makes two files in the same directory indistinguishable, their original paths provide the final disambiguation. Long trails collapse their middle to `…`, keeping the root and last two where space permits. Narrow windows preserve the lock cell before shortening the leaf; feedback takes space ahead of older trail segments. Literal path text cannot execute statusline expressions.

An ordinary file change (`:edit`, native `gf`, a finder) starts a new root; roots display no breadcrumb. Alt+Shift+O still traverses the existing native file history and restores each visit's cursor and trail. It can reach an older unrelated root after the followed chain is exhausted. Same-file reloads preserve the trail. Native splits inherit an independent value, and closed windows release their history.

## Snapshot contract

`require("parley.file_history").snapshot(win)` returns a detached, opaque, JSON-safe value, or `nil, reason` when no valid named-file trail can be captured. Consumers store it verbatim. Window 0 means the current window.

`restore(win, value)` installs the trail and matching Back entries AFTER the caller opens the selected file. It returns `true`, or `false, reason`. It opens no files. Its last canonical path must match the actual opened file; malformed/unsupported/oversized values refuse before mutation. Genuinely missing ancestors are removed; uncertain filesystem failures refuse rather than claim absence. The surviving leaf alone becomes a root. The current cursor stays; unknown ancestor cursors start at row 1/column 0. On refusal a finder can keep the file it just opened as its ordinary root.

Values and histories are bounded to 200 paths/visits and 1 MiB per exported trail. Overflow retains the root and newest suffix with an omitted-count marker. There is no persistent trail store or background process. `peek(win)` is an internal cached detached read for paint; it does no filesystem observation.

## Code and tests

- `breadcrumb_model.lua`: pure transitions, validation and display projection.
- `file_history_model.lua` / `file_history.lua`: visit/cursor ownership, atomic ancestry installation and native navigation.
- `document_band_model.lua` / `document_band.lua`: pure composition and shared window option ownership/restoration.
- `display_text.lua`: Neovim display-unit adapter shared with the float picker; truncation retains each base character with its composing marks.
- `make -k test-spec SPEC=ui/breadcrumb`, `ui/keybindings`, `context/file_references` and `modes/session_sync` cover the model and native/fake-backed integration.
