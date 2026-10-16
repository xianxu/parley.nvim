# Breadcrumb Winbar Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the per-window Alt+o trail beside a fixed nine-display-cell lock indicator through the shared document renderer, with a reusable trail snapshot.

**Architecture:** File history remains the owner of file visits and cursor restoration. A pure breadcrumb value distinguishes followed links from ordinary visits; the shared renderer composes that value with lock state and persistent submission/error feedback. Native observation and explicit successful-follow commits feed the value; no global asynchronous navigation flag.

**Tech Stack:** Lua, Neovim window/buffer APIs, existing Plenary make harness and stateful resolver/Couch fixtures.

## Design and alternatives

Recommended: extend file-history visit records with a breadcrumb value and expose its current projection; render through document_band. A separate standalone navigation observer would duplicate visit/cursor ownership and could disagree on Back. Replacing file history with link-only navigation would remove native gf/edit/picker Back behavior already defended by tests. Both alternatives are rejected.

No click targets, finder UI, persisted trail database or extra winbar writer. The attention finder receives snapshot/restore APIs now, not its own implementation.

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| Breadcrumb value and transition | lua/parley/breadcrumb_model.lua | new |
| Breadcrumb segment/width projection | lua/parley/breadcrumb_model.lua | new |
| File visit/history with breadcrumb snapshots | lua/parley/file_history_model.lua | modified |

Breadcrumb value: `{version=1, paths={absolute_path,...}, omitted=0}`. Snapshot callers receive copies. Root is one path; it renders no trail. Follow appends a different target; same-file jumps do not grow it. Ordinary file opens reset to a one-path root. Back restores the saved target visit's value, so Alt+o descent pops naturally while native Back still traverses earlier roots. Root does not disable native Back; a native visit remains its own root. This interpretation preserves #333's contract and needs TL approval.

Pure transitions receive canonical paths/cursor values from integration. Sequence ownership is immutable; all authoritative changes pass through the model. No filesystem or window reads in pure units. Display projection accepts label text units and measured display widths from its adapter; it does not measure with IO or read editor configuration.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| File-history controller and snapshot/restore | lua/parley/file_history.lua | modified | native visits, cursors, windows |
| Successful follow boundary | lua/parley/init.lua; lua/parley/artifact_ref.lua | modified | sync local opens, native gf, async resolution/pickers |
| Shared window renderer | lua/parley/document_band.lua | modified | winbar/winhighlight ownership and width |
| Lock/feedback view selection | lua/parley/session_sync.lua; lua/parley/agentic_document.lua | modified | existing lock, baseline, membership and receipts |

Use real temporary files and windows for navigation. Artifact resolution keeps the existing production runner/stateful fake; Couch tests reuse tests/fixtures/fake_couch through production document_registry transport. No new binary/service dependency or production state store.

## Navigation protocol

- `file_history.snapshot(win)` returns a detached versioned breadcrumb value for the current observed file, including canonical absolute paths. No history table or window ID escapes.
- `file_history.restore(win, snapshot)` validates version, paths and bounds, requires the final path to match the window's actual current file, then commits the copied value and repaints. It does not open files or trust a stale buffer number; mismatch returns false without replacing the root. This is the attention-finder seam.
- Capture a follow origin before Alt+o opens anything: originating window/file, current breadcrumb, visit generation. Keep it in that invocation's closures; never install a lasting global marker for a future BufEnter.
- Route every successful file landing through one `follow(origin, open_fn)` boundary. It executes the actual open, observes the resulting editing window and file, then commits origin trail plus target only if the open succeeded. BufEnter's provisional ordinary-root observation is replaced by this confirmed follow value, without adding a second history visit.
- The helper must handle M.open_buf focusing another already-open editing window or the preferred other split. Commit into that actual destination, leaving the origin and unrelated windows' trails intact. Existing files' native cursors/history behavior stays unchanged.
- Pass an optional explicit opener into artifact_ref.goto_ref_at_cursor so accepted resolver/family choices use the same follow boundary. Default calls retain existing behavior. Existing generation/buffer/window/change guards execute BEFORE open; a cancellation, superseded response, failed open or error leaves no follow permit behind.
- Wrap direct markdown/src/branch/@@ opens and the native gf fallback as well as the chosen entity candidate. Only filesystem file landings affect breadcrumbs; directories, URLs, command references, unnamed buffers and floats cannot become breadcrumb nodes.
- Native observations continue recording ordinary named-file visits and cursor snapshots. Same-buffer edit!/agent reload/WinEnter do not reset a trail; a real non-follow file change does. A new native split copies the source value as a detached value, then diverges; an independently created API window starts its own root. Window close drops its history/trail. Buffer wipe alone cannot delete another window's historical path value.

State/event rules: no trail + valid visit -> root; root/trail + ordinary changed file -> new root; root/trail + confirmed follow -> appended trail; same-path observation -> unchanged trail; Back -> target visit snapshot after successful native switch; failed Back -> unchanged; restore mismatch/invalid -> unchanged; closed window + late callback -> ignored by existing validity checks. Real non-follow visits invalidate origin generation. A callback cannot reclassify a later unrelated open.

## Rendering contract

One renderer owns all writes to winbar and winhighlight. State owners supply structured state/feedback, never a preformatted lock cell. document_band composes each target WINDOW separately, using its width and breadcrumb. Navigation changes repaint that window even when the lock timer has not fired; lock updates cannot copy one window's trail into another window showing the same buffer.

The first cell is exactly nine display columns (padding included): `free`, `yours ●`, `agent…`, `stale`, and compact warning/unknown forms. `●` means unsubmitted content, derived from the existing acquisition baseline/current hash evidence, independent of &modified or auto-save. A pre-existing unknown-baseline lock shows `yours` without inventing evidence for the dot. Stale/violated state retains the existing warning priority. Lock state remains visible during success/error feedback; owners pass feedback alongside the underlying state instead of replacing it. Proven-plain files reserve an empty nine-cell cell only when a trail exists; plain root has no installed bar. Unknown/error root still shows its existing visible notice.

After the cell: `root › parent › current`, with basename labels dropping only a terminal `.md` and leading `YYYY-MM-DD-`. Disambiguate equal DISPLAY labels by adding parent components; if immediate parents are equal, add enough suffix components to distinguish, up to their full paths. Revisiting the exact same path is not a false disambiguation conflict. Percent signs and controls in path labels are escaped/sanitized at the renderer boundary; never interpret file text as statusline expressions or clickable commands.

If the full trail exceeds remaining display columns, collapse interior segments to `…`, retaining root and final two where they fit. If those still exceed the width, shorten individual labels by display columns; at extremely narrow widths, preserve the lock cell first, then the current leaf and ellipsis. Never emit invalid UTF-8 or exceed available width; wide/combining text and a literal percent are tested. Existing submit/error notices remain visible after the trail when space permits; feedback has priority over older trail segments, with a bounded truncated message. Keep the operator-needs-submit background from existing highlight groups. Do not recolor the whole bar on a success receipt if the underlying operator turn still needs submission.

Retain #332's owner layers, per-window/buffer original/installed proofs, user override checks, handoff restoration and cleanup. A breadcrumb-only view is another composition input, not an owner that can erase a newer lock/error layer. When no state/feedback/trail remains, restore the original surface through the existing ownership path.

## Operating envelope and lifecycle

ARCH-CONSTRAINTS: UI-only updates; no subprocess, disk scanning or network on repaint. Repaint only affected windows on navigation, state changes or WinResized. Reuse the existing history limit of 200 visits/window. Trail values have at most 200 paths and 1 MiB combined path bytes; reject invalid restore input. At a follow overflow, retain the root and newest suffix within these bounds and increment omitted, rendering an ellipsis for the gap. Back restores only a confirmed history snapshot, never fabricates an omitted path. Typical depth is a few files; tests cover bounds instead of assuming that.

ARCH-FUNERAL: histories and snapshot references die on WinClosed/editor shutdown; callers own exported copied values. No new durable artifact, timer, background process or session-persistent cache. Existing restoration proofs remain bounded by live window/buffer pairs and are consumed on entry/wipe/window close.

ARCH-SECURE: filesystem labels and caller-supplied snapshot values are untrusted display/input. Validate shape/version, absolute path strings, controls, item/byte bounds and final path identity at restore. Display escaping is separate from filesystem identity. No credentials touched and no shell interpolation introduced.

ARCH-DRY: existing file-history owns visits/cursors; document_band is the sole renderer; session_sync retains lock truth. ARCH-PURE/ORDER: pure immutable transition and projection own trail semantics; callback validity and actual landing are observed before committing. ARCH-PURPOSE: all synchronous, selected and asynchronous Alt+o routes plus Back/reset and a reusable snapshot are included. ARCH-MOCK: existing real/fake seams reused, with no additional service protocol to model.

## Implementation tasks — one atomic close boundary

### 1. Pure trail/history and display projection

Files: new lua/parley/breadcrumb_model.lua and tests/unit/breadcrumb_model_spec.lua; modify lua/parley/file_history_model.lua and tests/unit/file_history_model_spec.lua.

- [ ] Write failing transition tests: root/follow/follow/back, non-follow reset, same-file jump, forward-tail truncation, independent copies, invalid restore and capacity overflow.
- [ ] Write independent display oracles for prefix/suffix stripping, duplicate labels, equal parents, middle collapse, narrow widths, percent/control data, Unicode units/widths and nine-cell state labels.
- [ ] Run `make -k test-spec SPEC=ui/keybindings` after mapping the new units; confirm missing-model assertions fail, not harness setup.
- [ ] Implement immutable transitions/width projection and rerun the mapped tests green. Commit the pure model and tests.

### 2. Real navigation and snapshot seam

Files: lua/parley/file_history.lua, lua/parley/init.lua, lua/parley/artifact_ref.lua; tests/integration/file_history_spec.lua, tests/integration/entity_navigation_native_spec.lua, tests/integration/open_reference_spec.lua, tests/integration/entity_resolve_spec.lua.

- [ ] Add red real-key Alt+o descent/Back/reset tests and exercise actual selected candidates, src/branch/@@ and gf fallback.
- [ ] Add async cancel/stale/failure/duplicate scenarios through existing fake resolver, then an unrelated native open; assert no accidental push.
- [ ] Cover M.open_buf cross-split/reuse targeting, independent two-window trails, native split copy, failed switch, unload/reopen and snapshot restore mismatch/copy safety.
- [ ] Implement only the explicit follow/snapshot integration described above. Preserve all prior #333 native Back cursor/missing-file behavior. Run mapped navigation tests and commit.

### 3. Shared composition and ownership

Files: lua/parley/document_band.lua, lua/parley/session_sync.lua, lua/parley/agentic_document.lua; tests/integration/document_band_spec.lua; new tests/integration/breadcrumb_winbar_spec.lua.

- [ ] Add red actual session/ordinary-agentic pairs for each lock/feedback state with and without trails, including autosaved unsent-dot, clean undo, submitted/unchanged/resent/error, offline unknown and plain files.
- [ ] Add real two-window same-buffer different-trail/width cases, resize, overlays, custom originals, detach and A→B→A round trips. Assert rendered display width and both options, not only string fragments.
- [ ] Implement structured state+feedback composition through the shared renderer, repaint affected windows and retain ownership restoration. No independent winbar writer.
- [ ] Run `make -k test-spec SPEC=modes/session_sync` and `make -k test-spec SPEC=ui/keybindings`; confirm existing renderer parity/restoration and native history remain green. Commit.

### 4. Documentation and required gates

Files: atlas/ui/keybindings.md, atlas/modes/session_sync.md, atlas/traceability.yaml, README.md, issue and this plan.

- [ ] Document root/reset/Back semantics, nine-cell precedence, width fallback and snapshot/restore contract. Update traceability for all new tests; atlas index already links both pages.
- [ ] Push through sdlc pr, then run the declared full suite via `sdlc local-check run --name suite` on the final code head; retain exact head/log/hash and all failures.
- [ ] Close with measured evidence via sdlc close --issue 353; mandatory fresh review is binary-owned. Fix blocking findings across the full family and reverify changed surfaces.
- [ ] Ask the hub to coordinate :0 availability, stage with sdlc stage --build, report exact stage and live steps. Operator checks actual Alt+o/Alt+Shift+O trail, a split, narrow width and edit/submit lock cell. Land on SHIP after the required live decision. Inspect stage identity before any clear so another worker's replacement is preserved.

## Approval

Pending TL design approval. No code changes before approval and sdlc change-code's full-flow plan-quality gate.
