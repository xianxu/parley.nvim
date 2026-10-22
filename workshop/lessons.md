# Lessons

## 2026-10-22 (#409 — a census is not run ownership)

- Persistence and a recognizable command prove that a process exists, not that
  its owner has finished. Hold one checkout lease across scratch mutation,
  execution and both cleanup phases; reuse its descriptor through recursive make.
  Reentry alone does not order sibling goals: serialize them within the owner too.
- Test dry-run behavior through recursive make with long options too. Apple's
  make can put `-n` after `--no-print-directory` in MAKEFLAGS, so its first word
  alone cannot establish whether a nested command is print-only.

## 2026-10-16 (#353 — displayed ancestry and native history)

- A displayed trail and Back entries must commit together in the actual landing window, including reused splits. Reconstruct through one pure transition; changing only the label can send Back into an unrelated file.
- Repeated paths are visits with distinct cursor provenance. When a bounded trail drops interior entries, keep cursor positions by retained visit index rather than matching path text.
- Stripping date prefixes can erase the last distinguishing component of filenames in the same directory. Test that collision and fall back to original identity after parent suffixes are exhausted.

## 2026-10-16 (#332 — shared stage ownership)

- A stage can be replaced by another worker before the original item lands. Inspect the current staged commit before clearing it; clear only the stage owned by the completed item. A newer stage belongs to its worker even when the earlier task authorized cleanup.

## 2026-10-15 (#332 — document admission and lifetime)

- Window-local options have per-buffer cached values. Test A→B→A with distinct originals: restoring at BufWinLeave alone can be too late for Neovim’s cache. Keep the original/installed proof per live pair until entry/wipe/close, consume before recapturing a baseline, and never restore into a different buffer.

- Sharing labels does not share rendering. Winbar and StatusLine mapping must be installed and restored together, and equal strings cannot establish which owner may clear them. Compare real state snapshots across both file kinds and exercise older identical owners, live overlays and window-buffer handoff.

- Keep a resource’s plan, runtime and atlas lifetime identical: closing a descriptor does not delete its lease pathname. If permanent bounded allocation replaces planned GC, append the Revision and correct the active design claim.

- An unresolved read-only membership probe is not proof that a document is plain. Before migration, confirm OLD with a fresh bounded lookup; pending registration and owner resolution must block migration before filesystem effects.
- BufUnload includes both true buffer retirement and synchronous native rereads. Retire async operations and execution leases on true unload; explicitly mark managed reads, defer their raw completions until loaded, and preserve the attached identity and receipt. Exercise callbacks inside the native unload event, not only after reopening.
- Classify configured-root/live-buffer wrappers as INTEGRATION even when one branch takes supplied values. Keep the pure filename classifier separate rather than mislabeling the wrapper.
## 2026-10-16 (#234 — render walk on the shared row step)

- A parity property test earns its keep on the first run: #234's found a footer `🧠:` row whose lookahead verdict the render walk only computed inside a paint branch. When moving transitions onto a shared step, compute every transition INPUT before (and outside) the painting branches.
- "Sweep for other copies" means grep the RULE, not check the copy the issue names. #234 checked chat_parser and missed `document/grammar.lua`'s render_before copy, which is the production path (close BR-1). Grep every writer of the state the rule changes (`in_reasoning =`), and justify each survivor.
- Paste commit hashes from the `git rev-parse` output; never retype one. #234's plan message to the hub carried a typed, wrong hash, and needed a correction.

## 2026-10-16 (#236 — dead-code sweep)

- When deleting code, sweep the docs for the CONCEPTS it carried, not just its file paths. #236 grepped atlas/ for deleted module paths and missed a page describing the "virtual provider" and "generator seams" in prose (close BR-1). List each deleted entity's names and nouns, grep those, and delete or rewrite every hit. Include CODE COMMENTS in that sweep: round 2 found three lua/ comments still naming the removed seams, after atlas was clean.

## 2026-10-16 (#350 — a "dead" branch that was live)

- One trace never proves a branch unreachable. In #265 I traced a single move with a TIMESTAMPED child, saw the rewrite skipped, and filed it dead; it fires for non-timestamp children behind an explicit or sub/ path. To call code dead, enumerate what its condition depends on (here, resolve_chat_path's three return cases) and show each one fails, or write the reaching test.

## 2026-10-16 (#265 — one user-edit refusal policy)

- A fake must fail the way the real dependency fails. #265's ChatPrune test faked `writefile` returning -1, but the real one RAISES (E482), so the test passed while the production rollback never ran (close BR-5). Probe the real failure first, and treat a raise and an error return from fallible IO as one failure.
- Pin a passthrough with a real oracle, not a stub at the seam you are testing. A stubbed `_replace_user_lines` let the error-detail passthrough be deleted with every spec green (close BR-1); a non-modifiable buffer produces the real `error` status.
- An enforcement spec named after one function enforces only that function. The refusal policy banned the raw replace, but hand-capturing commands kept their own wording (close BR-2). Name the class (every direct caller, with reasons), not the one symbol.

## 2026-10-16 (#345 — async stop on the restart path)

- A new helper or forward declaration goes ABOVE an existing doc block, never between the block and its definition. #204 and #340/#345 hit this four times (ensure_running, restart_managed, M.stop, pids_on_port). After inserting near a `---` block, read the three lines above the definition you meant to document.
- When a design is revised mid-issue, sweep the issue's Plan, tables and Log for claims about the replaced mechanism in the same commit (a dated "superseded" note, not an overwrite). #345's option-B revision left four stale claims, which cost a close round (BR-6).

- Moving a caller to a new function silently disarms every spec that observes the OLD one by wrapping it. #345 moved restarts from `stop` to `stop_async`. One "stops == 1" spec failed, but a "stops == 0" spec and #340's stall window kept passing, both now checking nothing. Before switching a caller, grep `tests/` for `<module>.<old> =` wrappers and move them with it. Then rerun the mutation that each one guards.

## 2026-10-16 (#340 — credential_health restart timing)

- Measure under the load that fails, not a proxy for it. CPU burners never reproduced #340; 8 parallel copies of the spec (the suite's shape) did on the first run. The slow stage was a port probe that reached `down` only by curl `--max-time`, so wait on the process state you control (`kill(pid, 0)`), not on a probe of what it leaves behind.
- Background load generators: zsh does not word-split an unquoted `$pids`, so `kill $pids` failed and 24 `yes` processes outlived the run. A later sandboxed command may not signal them (EPERM); only stopping the owning background task killed them. Kill in the same command, with an array (`kill "${pids[@]}"`), and confirm each pid reports ESRCH.

## 2026-10-15 (#204 — vault reset on setup)

- Resetting a store also has to cover what is derived from it. #204 reset the vault's keys on setup, but the copilot bearer cache and any in-flight resolver still carried the old key (close-review advisory). List the derived state and the async writers before claiming "takes effect".
- An integration assertion has to tell the branches apart: a substring shared by two of three messages pins no wiring.

## 2026-10-15 (#337 — whole-file deadline flakes)

- Close BR-1: native conformance that asserts a specific deadline reason must control the load/CPU inputs; at the supported cap, idle and absolute coincide. Exercise ordinary and capped inputs through the same runner seam, preserving the model’s explicit precedence.

- A startup CPU-load sample cannot establish how much useful work a growing spec file contains. Keep hang detection tied to completed cases (including fixture teardown), with a separately tested absolute ceiling; arbitrary log output must never refresh it. Verify deadline state with a virtual clock and child ownership with actual process exits.

## 2026-10-14 (#329 — generated skill ignores)

- Isolated reviewers may lack a declared substrate. For generator-cleanliness claims, capture the code/substrate pins, compiler exit, before/after output checksums, and clean status as measured host evidence; a prose success claim alone is insufficient (BR-1).

## 2026-10-14 (#325 — Markdown sidecar links)

- Escaped URLs and disk paths are different values. Share one validated resolver across every disk consumer, including stat before read; round-trip tests must reach message-builder budget admission as well as the byte reader (close BR-1).
- A scope revision needs matching Done-when criteria. Small PNG preservation does not cover the separate large-image shrinking contract (close BR-2).

## 2026-10-14 (#326 — generated vocabulary CI)

- Keep close-time verification checkboxes separate from post-landing CI confirmation. Tick only observed results; a passed PR check cannot prove the future main run (close review BR-1).

Compact rules distilled from Parley.nvim's review and integration history.
Incident detail belongs in the issue or plan that owns it.

## 2026-10-11 (#314 — session-sync hardening)

- #314 close review BR-1: `vim.json.decode` turns JSON `null` into `vim.NIL`, a truthy userdata; `x and x.y or {}`
  then indexes or iterates it and the callback dies, leaving any in-flight flag set forever. Decode external JSON
  with `{ luanil = { object = true, array = true } }` and type-guard every list; test a payload of nulls.
- #314 close review BR-2: a "keep their copy, then overwrite" step must check the keep. Branch on the outcome
  (missing / copied / failed), never overwrite after a failed copy, and say only what actually happened.
- `:bdelete` unloads without BufWipeout. A per-buffer timer must check `nvim_buf_is_loaded`, not `_is_valid`.
- Mutation checks with BSD sed: `\t` in a pattern is a literal `t`, so the mutation silently never applies. Use
  `perl -pi`, and confirm `git diff --stat` shows the mutation before trusting a pass.

## 2026-10-10 (#313 — session-sync turn file)

- #313 close review BR-1: an async completion must check that the state it
  reports on is still its own. A couch exit from an earlier submit handed back
  a turn that had since been unlocked and resubmitted. Tag each request with a
  generation and re-read the shared state before acting; test a slow failing
  request overtaken by a newer one.
- #313 close review BR-2: a buffer shared with another writer is stale while
  nobody watches the disk; `autoread` alone reloads only on focus/checktime.
  Watch the file whenever the other side may write, record the mtime the buffer
  last read or wrote, and refuse to write over a newer file. Without that guard,
  Neovim's interactive write prompt blocks.
- A mutation check needs a sharp assertion: the refusal spec passed with its
  guard removed until it asserted the refusal message. Neovim's own check
  (and the hang it caused) masked the missing guard.

## 2026-09-30 (#309 — tracker-only card views)

- An async "settled" callback must mean the work it reports on is finished. A
  refresh that skipped because a fetch was in flight settled at once, and the
  view showed "refreshing…" forever when the tip did not move. Join the
  in-flight work, and test a second caller that arrives while the first is
  running.
- Put assertions outside scheduled callbacks. An assert inside one runs after
  the flag the test waits on is set, and its error never reaches busted, so the
  test passes vacuously.
- #309 close review BR-1, and #307's BR-1 the same day: a second derivation
  of a path the system already resolves drifts from it. When a feature needs
  "the dirs the finder scans", take them from the function that resolves
  them (`discovery_roots`), never from config again.
- Run a feature live outside the harness before close. The harness disables
  fetching; the concurrency bug and the W10 warning only showed with it on.

## 2026-09-30 (#307 — setup defaults that read cwd)

- Before widening a detection that reads cwd or env, run the full suite and
  `git status --untracked-files=all`. Specs run from this checkout, which carries
  `.parley`; removing the `chat_dir` guard made 79 chats land in `workshop/parley`.
  The opt-out belongs in the harness (`tests/minimal_init.vim`), not in each spec.
- Merging user values over defaults can re-enable things an empty table disabled.
  After changing a merge, test one opted-out entry (`openai = {}`).
- #307 close review BR-1 (two rounds): when you change how a mode is decided, grep
  every reader that re-derives it (`find_git_root(vim.fn.getcwd())`, marker checks)
  and make them read the decision (`config.repo_root`, `project_root()`). A reader
  that recomputes the mode from cwd ignores the opt-outs.

## 2026-09-28 (#299 — navigation with overlays)

- Neovim window lists include floating overlays. Split counting and existing-buffer
  destination lookup must share the same editing-window predicate. Test an overlay
  both with its scratch buffer and with the destination buffer already displayed.

## 2026-09-27 (#291 — writer and reader under one config)

- #291 close review BR-1: `require("parley.config")` is the defaults module, not the
  user's configuration. A writer that must agree with the parser has to read the same
  live config (`highlight_structure.live_patterns()`); test at least one custom prefix,
  since default-only tests cannot tell the two apart.

## 2026-09-27 (#290 — writer fold fast path)

- #290 close review BR-1: an append's first row may be one it only continued. A
  consumer that presents "the rows a write produced" must know whether the write
  began that row (its first byte's column), and its tests must include a write
  that starts mid-row: text before a round's first tool call, in more than one round.
- #290: check a spec's editor-behavior premise in headless Neovim before building on
  it. "Text appended inside a manual fold keeps it folded" was false; set_text
  deletes the fold.

## 2026-09-22 (#220 — fixture process lifecycle)

- #220 M2 review: an argument mentioning an owned path is not process ownership.
  Census selectors must establish executable/script identity before signaling;
  include editors, pagers, shell command text, and interpreter command/module
  modes as negative cases.
- #220 M2 re-review (same ownership finding): matching an option substring is
  not parsing argv. A leading command option defeated a whitespace-only boundary;
  filename/address arguments could contain the same text. Recognize known launch
  forms from the beginning, and enumerate every value-bearing option family in
  the negative corpus, including a real headless flag followed by a fake init path.
- #220 M2 review: validate every observation in a polling sequence. An invalid
  later sample is unknown, not an empty set; never convert it to success or use
  the earlier snapshot as authority to signal.
- #220 M2 review: cleanup must run in the execution context that calls it.
  A pcall around vim.fn.delete hid E5560 in the libuv timer. Test both process
  death and removal of its owned files, including symlink boundaries.
- #220 BR-2: a function that reads process state is not pure merely because a
  unit test patches that read. Pass the observation as data to the predicate.

- A watchdog comparing a current value to one sampled at startup must handle the
  condition already being true at startup. A fixture orphaned while booting
  samples parent pid 1; a change-only check never fires. Test that ordering.
- Put a class-wide safety rule at the class constructor. Parent-death exit was
  an opt-in flag at two of eight spawn sites; `LoopbackHTTPServer` now supplies
  it to every long-lived server fixture, while the two non-server blocking paths
  call the watchdog directly.
- A broad path match needs a process-kind clause before it sends SIGKILL. A
  process with this checkout's `tests/` path in argv might be the operator's
  editor or the recipe shell. Match harness Neovim or fixture executables and
  exclude the census caller's ancestry.

## Production-path proof

- Enter through the user trigger, not a helper behind it. A unit test of a pure
  function does not prove mappings, autocmds, async callbacks, or command wiring.
- A test is coverage only if it goes red when the named behavior is removed.
  Assert the effect and the absence of forbidden effects; a generic error or a
  later guard can otherwise keep the test green.
- Derive enumerations from the source tree or registry. Hand-maintained lists,
  prose tables, and counts copied into tests drift on the next feature.
- A mutation must apply, compile, and traverse the intended branch. A scripted
  replacement that matched nothing is not a successful experiment.
- Test both sides of classifications and provenance classes. Syntax, position,
  or one captured screen cannot stand in for semantic origin.
- Acceptance tests must cross the sandbox, filesystem, process, and UI boundary
  they claim to cover. `make` owns integration setup; do not run the spec bare.

## Neovim and UI state

- Neovim state is scoped: buffer, window, tab, mode, client, and screen can each
  change independently. Test the transition that moves ownership between them.
- An autocmd without a pattern reaches scratch and floating buffers too. Enumerate
  every buffer consumer before changing shared insert-mode mappings.
- A temporary mode must clear on every popup swap, cancel, dismissal, and error.
  Restore the prior visible state, focus, cursor, and draft when work is refused.
- Async requests use live anchors, not saved coordinates. Re-resolve the buffer,
  window, and text range when the callback lands, and honor caller deadlines.
- A periodic repaint test must assert the frame it leaves, not only that the timer
  stopped. Frame lines are not terminal rows and controls are not cells.
- A key belongs to the surface that receives its preceding input. Test raw,
  Kitty, legacy, and modifier encodings across every interceptor.

## Text, terminal, and protocols

- Treat escape sequences and marker formats as closed grammars: distinguish a
  prefix from an unknown complete control, preserve parity, and fuzz malformed
  input as well as valid input.
- Terminal glyphs are units across every column consumer. Width, wrapping,
  selection, and viewport math must share one ruler.
- A stream split is not an event boundary. One writer owns injected bytes and
  the scanner consumes only that framed stream.
- “Defer to the host” is an explicit disposition with escape hatches, not a
  missing handler. Preserve native selection and fallback behavior when adding
  an overlay.
- A displayed model has one production constructor. Do not let tests or a second
  renderer invent a parallel state shape.
- Styling, wrapping, and decoration survive the viewport boundary only when the
  shared core preserves provenance and optional capabilities.

## Data, provenance, and contracts

- A filename, syntax, or display label locates a value; it does not prove its
  semantic identity. Carry provenance and distinguish absent, empty, unsupported,
  and failed values.
- A contract's fields need one authority. Consumers must derive from the source,
  and public schemas must project from internal models explicitly.
- A portable projection shares the owner's acceptance contract. Compact and
  diagnostic renderers may differ in detail but must not invent claims.
- If a changed primitive has multiple writers or consumers, sweep all of them in
  the same change. The new source is not complete until every old path derives.
- A fan-out cannot share one-shot state. Give each consumer its own observation or
  a coordinated owner that records delivery and cancellation separately.
- A cap or retry bound counts what production actually does, including all error
  classes and the worst input that can reach it.

## Review and workflow

- Reconcile plan rows, concept tables, acceptance checkboxes, and logs before a
  boundary. An accepted smoke or a green baseline does not imply unreported
  observations.
- Review findings are claims: read the cited lines, verify the corrected contract,
  and record uncertainty instead of folding speculation into the design.
- A review agent shares the worktree. Keep its snapshot bounded and do not treat
  raw review transcripts as source artifacts.
- User-visible behavior changes require help, README, atlas, and pasted-name
  tests in the same window. Sweep retired vocabulary and retry descriptions.
- Stage explicit paths; `git add -A` can capture operator notes and unrelated WIP.
  Preserve source before renames and verify the target remains tracked.
- A default the user never types is still public surface. Test command paths,
  options, cancellation, and the no-op/unsupported result explicitly.

## Working rule

Before changing a shared Neovim or terminal surface, draw its state scopes and
owners. Then name the production trigger, the callback's live anchor, the exact
oracle, and the mutation that would make the test fail.

## 2026-09-25 (#275 — theme release)

- Reproduce startup with the exact copied profile before giving a launch command.
  Homebrew wrappers can override environment variables; starter updates preserve
  existing init.lua and publish init.lua.new, so fixing source does not repair
  an existing copied profile.
- A live picker effect follows selected identity across filtering, not row number.
  Capture startup separately from picker-open state; verify both cancellation
  and startup restore after a saved choice has loaded.
- Run regression tests before requesting another boundary review; unused helper
  functions and passing command-registration tests do not prove the correction.
- Theme compatibility must assert scheme identity and variant, not only the
  presence of highlights. Persistence acceptance must enter fresh production
  startup; calling load/apply directly cannot verify the startup wiring.
- Enumerate every preview exit: no-result confirmation and failed commits need
  the same restoration semantics as cancellation. Test failure after a successful
  preview, not only from the original appearance.

- Starter dependencies used before the plugin manager initializes must be available
  in both launcher-provided and documented standalone startup. Test both with
  fresh processes and isolated data homes; never inject the runtime into every fixture.

## 2026-09-25 (#276 — local app launch)

- Outside one checkout is not necessarily outside repo mode: parent markers
  elsewhere still count. Enforce the requested mode at production startup and
  test the real detector with marked default and alternate profile ancestry.

## 2026-09-26 (#279 — proxy readiness)

- Do not gate a service client on a locally installed server executable. Let the
  service lifecycle owner probe an existing server before checking spawn prerequisites.

## 2026-09-26 (#280 — review of local app changes)

- Serialize profile ownership checks with launch/reset effects; checking a PID
  without a shared lock does not protect a concurrently launched editor.
- Assemble app aliases inside the registry-derived options loop and run the
  single-source architecture suite when changing shortcut configuration.

## 2026-09-26 (#255/#285 — refresh admission)

- Reject duplicate submissions before deleting visible output or publishing a
  replacement snapshot. Test duplicates while waiting, before output, during
  streaming, and after the question moves; verify the existing writer survives.
- Snapshot ownership has both pending and admitted phases. Keep documentation
  and cleanup tests aligned with both phases when moving work before admission.
- Closing stacked issues repeats the entire branch review window. Establish one
  shipment boundary before invoking close; never let concurrent reviewers run
  test harnesses in the same checkout, where process cleanup kills peer tests.

## 2026-09-27 (#287 — app blink cmdline)

- In a lazy.nvim spec, adding `keys`/`cmd`/`event`/`ft` silently makes the plugin
  lazy. Giving an eagerly loaded plugin a key binding removed `:Telescope` at
  startup. Set `lazy = false` with the trigger; the starter test now requires it
  for every spec with a trigger except the deliberately lazy MarkdownPreview.
- A test that swaps a global (`package.loaded[...]`) must restore it through
  `pcall`, or a failing call leaks the fake into later assertions.

## 2026-09-27 (#281 — tool-call storage investigation)

- Reproduce a UI symptom before redesigning the data it's blamed on. #281
  assumed inline tool payloads caused fold flicker; stepping the deferred
  fold work one scheduler turn at a time (`tool_folds.step`, probing
  `foldclosed` after each step) showed the cause was clear-before-create in
  repair, which a storage change wouldn't have fixed.
- Settled-state fold tests can't see a flicker. When work is split across
  event-loop turns, assert the invariant after every step, not only after
  `flush`.
- #264 M2 review: a record read by one consumer gets one constructor beside it. Three
  builders of `after_splice`'s evidence drifted in which fields they set; the fix was
  `splice_evidence`, not patching the newest builder.
- #264 M2 review: when an implementation drops an option the plan specified, log the
  deviation and its reason as it happens; an unlogged deviation reads as an oversight in
  review.

## 2026-09-27 (#293 — repair-gated tool round latency)

- A fixed-timeout wait on state gated by bounded background work (repair, fold
  batches) hides a work-volume defect behind a "flaky test". Before touching the
  timeout, record where the work stands when it expires and count the work
  (`Document.stats`): #293 was 480k defensive summary copies per 300-row write,
  not a race. Budget the counters in a spec; counters don't flake, wall time does.
- On this arm64 macOS machine LuaJIT sometimes cannot place compiled code near
  its VM (`failed to allocate mcode memory`), flushes its trace cache ~1000x and
  runs 15x slower per step, at random per process (ASLR). `maxmcode` does not
  help. Profile VM states (`jit.profile` vm arg: J=compiler, N=compiled) before
  blaming GC; the only lever is less work per step.
- A contract a plan says is "documented on X" must be stated at X, the public
  entry callers read (M2 review: purity was only on a private helper).
- Mutation-check a guard before claiming it: #293's fold-key cache test stayed
  green without the key because each redraw recomputes spans anyway. Say what a
  test actually proves.


- Tutorial keyboard claims must name the mapping modes: test Normal, Insert and
  Visual separately before generalizing wrapped-line movement. When adding a
  lesson, sweep README discovery as well as runtime catalogs (#289 review).

## 2026-09-28 (#295 — private-note Return)

- Native option flags have buffer-wide effects: enabling `formatoptions=r`
  continues every configured comment leader. State that scope explicitly, and
  test actual keys, undo, and pre-existing mappings when reusing native editing.
- Custom text must cross a native option's grammar safely. `comments` accepts
  escaped commas but not every backslash/comma combination; validate through the
  option API and preserve chat setup when a leader cannot be represented.
- #295 BR-1: native comment matching is ordered. Put the private leader before
  shorter existing single-line, nested, block, and user-defined leaders; test
  resulting text still carries the entire private marker across that matrix.
- #295 BR-2/BR-3: sweep README entry points with atlas docs, parameterize stated
  default/custom boundary cases, and prove prompt submission through Return.

## 2026-09-28 (#297 — local recording demo)

- Reset contracts must enumerate persistence outside XDG_STATE_HOME: the app
  theme is under stdpath(data)/parley/persisted. Verify cleared and retained
  paths with stateful fixtures, including auth and installed dependencies.
- Seeded chats must pass production recognition (filename and headers), not
  merely open as Markdown. Test the launched buffer through `not_chat`.

## 2026-09-28 (#282 — one answer, one undo entry)

- Verify which native callback actually fires before building on it: the first fix
  adopted a new tick on the `on_changedtick` lifecycle event, and `:write` never
  delivers one. Instrument the path (who clears the state, with which values) before
  writing the fix; the second finding (a "stale" apply that had in fact landed) was
  the opposite of the first guess too.
- Text written outside the owning writer (the regeneration's raw `delete_answer`)
  sits outside that writer's undo grouping. When a flow spans a pre-writer edit and
  the writer, hand the undo state across explicitly (seed + adopt), and fall back
  to separate entries when anything intervenes.
- A regression test for rule X must fail when only X's code is removed; if another
  mechanism already guarantees the outcome, the branch is dead — delete it rather
  than keep an untestable guard (#282 close review).
- `git add -A <dir>` sweeps in the operator's untracked files (a parley chat was
  committed and had to be amended out). Stage explicit paths.


## 2026-09-29 (#300 — completion keyboard smoke)

- Feed remappable keys when testing plugin mappings; `nvim_feedkeys` with `n` bypasses the mappings and tests Neovim defaults instead.
- Parameterize caller-level tests across promised configuration variants, and test both directions of selection with distinct candidates; helper-only coverage cannot detect a caller passing the wrong configuration.

## 2026-09-29 (#301 — local outline context)

- Classify line-scoped syntax before trimming or removing speaker prefixes. Preserve a source-derived context projection when local rendering must retain the original text.
- A context filter must preserve provider validity when all text disappears, and must recognize code fences on the speaker line without treating prefix-inline tags as whole-line tags. Test each changed request-producing caller, including topic requests.
- When syntax determines both structural association and outgoing projection, share one row classification. Fence regressions must cross delimiter character, width, trailing content, speaker-line openers and turn-boundary termination; testing balanced examples alone misses reattachment loss.

## 2026-09-29 (#302 — pairing with typeahead)

- Insert expression mappings may inspect the line before preceding typeahead is inserted. Test contiguous mapped keys and ordinary text between them; use a command callback when the decision must observe completed insertion. Pairing cursor motions need `<C-g>U` to preserve a single undo step.

- Delimiter typing tests must include directly adjacent pairs, not only prose-separated pairs. Keep acceptance-path integration smoke checks in the repository so reviewers and future changes can rerun them; sweep generated help alongside README when changing a user-visible contract.

- Check whitespace across the reviewed commit range, including generated review sidecars; a clean working-tree diff can hide committed trailing whitespace.

- Async file-selection callbacks need a generation check after reading; test A→B selections with both completion orders. Browser draft storage needs a documented retention bound and a visible unsaved state when persistence fails.

## 2026-09-29 (#304 — spelling acceptance context)

- Buffer and cursor events do not observe every window transition: two windows can display the same buffer at the same cursor. Invalidate asynchronous editing authority on WinLeave as well; test an excursion and return before resolution, alongside staying in the other window.

## 2026-09-30 (#306 — bundled editor dependencies)

- A receipt alone does not verify a writable cache. Compare the complete payload inventory before reuse, including unexpected files and executable modes. Keep package-manager-owned payloads and writable development caches explicit in the trust model.
- Bind that inventory to a checked-in, archive-derived source identity as well: otherwise editing both payload and receipt bypasses parity. Test those edits together, and make sealing enforce the same independent identity as verification.
- Socket inactivity limits do not bound total download time. Test slow response headers and bodies against a wall-clock deadline and verify terminated workers are reaped before partial files are removed.
- Adding bootstrap imports changes the minimum runtime closure. Validate all newly required modules before publishing a fetched release and before selecting an older cache; recovery instructions must work before the missing loader starts.
- A reader lease must survive its launcher: pass the lock descriptor into the consuming process and test parent death. Recheck after an exclusive-to-shared conversion because a waiting writer can win the conversion gap.
- Exercise offline acceptance through the actual launchers with enforced network denial and read-only installed payloads. Use long temporary paths: Neovim 0.11's encoded bytecode-cache names can exceed filesystem filename limits.

## 2026-09-30 (#308 — tracker cards in issue views)

- When shared external state changes, notify every open view of it, not just the caller that triggered the read. Throttled or coalesced refreshes otherwise drop the news for everyone else. Design a per-resource subscription whose liveness derives from the view itself, and test a hidden view under the real throttle.
- Key a subscription by view identity and replace it on re-attach; never guard it with a sticky flag. Flags such as `b:` vars outlive unload and reload, so the subscription and its liveness drift apart.
- Async specs that change external state must first wait for the component to go idle (reads as well as fetches). A request that joins an in-flight read started before the change will legitimately return the old state.

## 2026-10-01 (#294 — heavy specs under parallel load)

- A weak-reference "was it collected?" probe measures the LuaJIT trace cache as
  well as our references: a trace keeps the closures it specialized on (and what
  they capture) until it is flushed. Probes about parley's references go through
  `tests/helpers/reachability.collect()`, which flushes first; a probe whose
  contract is reclamation under live traces says so and does not (#294). A
  probe that passes only because the JIT kept flushing is passing by accident.
- LuaJIT on arm64 macOS: count flushes and abort reasons (`jit.attach` "trace")
  before tuning `jit.opt`. "failed to allocate mcode memory" is the OS ignoring
  placement hints; whether a bigger `sizemcode` helps or is catastrophic depends
  on the LuaJIT build (68354f4447, 2025-11), so gate any tuning on it (#294).
- Check a regression test fails without its fix on every Neovim the suite
  supports, not just one: a case can pass by accident on one runtime (#294
  BR-1). A case that measures window layout starts from `silent! only`; an
  earlier case that failed before its `close` leaves a split behind, and a
  narrower leftover window can hide the very defect being tested.
- Each guard in a pure filter needs its own case where it is the only filter
  that applies. A fixture that an earlier guard already filters out (here, a
  blank card value that also had a local line) leaves the later guard
  untested: deleting it kept every test green (#310 BR-1). Mutation-check each
  `and not …` clause.
- A window-wide option set for one feature changes every feature that reads
  it. `concealcursor = "nvic"` was meant for 🤖 markers but also kept
  treesitter's link and emphasis conceals hidden on the cursor line while
  typing (#312 BR-3). Scope the change to where the feature lives (here, only
  while the cursor is on a marker line), keep the window's own value
  elsewhere, and test the "elsewhere" case.
- An insertion point is not a byte. A cursor snap that is right for normal
  mode (never rest ON a hidden byte) is wrong for insert mode, where the
  position just before a marker is outside it but the rule snapped it into the
  anchor (#312). Derive insert-mode legality from the gaps between bytes.
- Test concealment on a rendered screen, not only through decoration entries.
  #312's specs asserted parley's own conceal extmarks and passed, but
  treesitter's markdown_inline also conceals `[text]` as a shortcut link, so
  marker brackets vanished on screen. A real TUI nvim driven through a pty,
  dumping `screenstring()` cells, showed it at once. Check the other decoration
  providers on the same bytes (treesitter queries with `conceal`) whenever a
  feature hides or shows text.
- **An escape must be injective over its own delimiters** (#312 close review).
  `\<br>` escaped a literal `<br>` but not the backslash before it, and the
  float's `💬:` line prefix wasn't escaped inside a turn, so a save silently
  split or rewrote turns. Every encoding (codec, display layout) needs an
  escape for each of its delimiters, including the escape character itself.
  The round-trip property test must draw its input from those delimiters, not
  from friendly words.
- When a guard that re-read external state (a lock on disk) is ported to
  in-memory state, check who writes that state. If only the same callback
  writes it, and a busy flag blocks a second run, the guard is dead (#315
  close review: the ping's "the reply may have landed" check). Likewise, a
  "force a refresh now" call that returns early while a refresh is in
  flight is not a guarantee. Make it a flag that the in-flight run honours.
- A `:write` from inside a non-nested autocmd (a user's auto-save on
  `TextChanged`) fires no `BufWritePost`. A baseline that only autocmds
  update ("what this buffer last wrote") lags behind such writes, and the
  buffer's own save reads as a foreign one (#317: false session-sync
  violations). Ask Neovim instead (`:checktime` raises `FileChangedShell`
  only for someone else's write), and when it gives no verdict, leave the
  question open; never adopt the write (close review BR-1). Test with a
  spec that auto-saves from a non-nested autocmd.
- **A seam stubbed in the dispatcher's spec hides the consumer's new path**
  (#316 close review BR-1). `review_send`'s spec stubbed `run_via_invoke`, so
  the new `args.modes` handling in the review skill's `source()`, its
  `has_mode` gate and the journal's mode name were reached by no test. When a
  change widens an argument shape across a seam, test the far side with the
  new shape (and mutation-check it); the dispatcher's stub covers routing.

- Quick-flow issues still need a Core concepts table naming their modified
  owners: use the exact `## Core concepts` section with a following level-two
  heading. The architecture guard selects that section for new symbols, and
  rejects an empty selection even without new public API (#321).

- A timestamp pattern is not validation: reject impossible calendar dates,
  out-of-range clock/offset components, and malformed fractions in the shared
  parser used by every admission input (#321 BR-1).
- Default-boundary tests must load the shipped configuration as well as test
  the nil-config fallback. Mutation-check the actual default, not just the
  consumer fallback (#321 BR-3).
- Extract asynchronous admission decisions over explicit observations into
  pure helpers; keep clock, file and process reads in the caller (#321 BR-2).
- Sweep README for changed defaults and atlas for generated metadata changes;
  a generated refresh can expose new fields through generic consumers (#321 BR-4).

- A fake writer update must include both its status response and filesystem
  effect. Advancing a fake clock while only changing future subprocess env
  leaves in-flight snapshots valid in ways the real write would invalidate
  (#321 recent-write fixture race).

## 2026-10-14 (#324 — native edits and clean release)

- Test the real event order when a pre-existing auto-save participates: synthetic BufModifiedSet before TextChanged hid the Normal-mode acquisition defect. Install the operator's callback first and drive child-Neovim input.
- Every new ownership-release path must reconcile pending external effects through the existing preservation handler first, including overwrite, deletion, failed copy and undecided probes. Equality to a per-edit mtime does not establish equality to the loaded baseline.
- Cross-process file existence is not readiness: enumerate every positive wait and await each complete expected payload (lock, notification, preserved/restored file), rather than fixing only the first helper. A scheduler sentinel makes deferred-state assertions observe the transition rather than a lucky ordering.

## 2026-10-14 (#330 — undo baseline under auto-save)

- Disk equality and modified=false describe the latest save, not the operator turn's original content. Freeze the pre-edit content at lock acquisition, retain it through auto-save, and test partial undo, full undo, redo, reloads and explicit saves against that same baseline. Save restored baseline text before releasing the lock so an agent cannot observe free ownership with stale disk contents.

- #330 close review: a symbol-name search can miss adjacent user-facing behavioral claims. Read the entire README feature paragraph when its atlas contract changes; sweep both undo and redo clauses. Plan work bounds must count exceptional success paths too (here, post-write verification adds a third hash).

## 2026-10-14 (#331 — canonical owner compatibility)

- Normalize renamed protocol fields once at the existing parsing boundary so validation, routing and rendering share precedence. Test canonical-only, legacy-only and conflicting values through consumers; give the losing actor different activity/identity so ping and same-slot validation cannot pass by accident.

- A native buffer switch still runs plugin BufEnter hooks. For a cursor/mode
  restoration, include buffer preparation in the synchronous restore scope:
  prep_md's stopinsert plus feedkeys drained typeahead during FileBack (#333).
- WinNew can run in a new, inactive API split without WinLeave in its source.
  Snapshot the last focused source on creation; test inactive splits alongside
  ordinary split commands before inferring parentage from departure events (#333).
- Concurrent focused tests in one checkout still share the orphan census.
  Schedule all make-driven tests after a delegated direct Plenary run finishes
  so its live child is not mistaken for an orphan (#333).
- Resolve named buffers with helper.buffer_for(path, loaded_only), including
  availability checks. The architecture guard rejects pattern-based bufnr(path)
  lookups; reuse the exact-name helper before the full-suite boundary (#333).
- Correction to the split-source rule above: focus does not prove API ancestry.
  Equalalways can make distinct parents produce identical native creation state.
  Inherit only from an explicit native WinLeave→WinNew source; start API windows
  fresh, seeding after their temporary cloned buffer is replaced (#333 BR-1).
- Do not suppress all editor observations until a scheduled initialization:
  API callers can enter several real files before yielding. Start empty-window
  histories synchronously at BufEnter/Back, excluding a fresh WinEnter clone;
  test API creation followed immediately by multiple file entries (#333 BR-2).
- A multiline occurrence needs its full raw span and destination row, not just
  its opening row and columns. Reserve every row of that span before scanning
  subordinate references; otherwise wrapped labels leak artifact/@@ choices (#335).
## 2026-10-15 (#327 — enclosing-entity navigation)

- A selected occurrence is an identity, not a cursor hint. Dispatch its kind and exact span/target; replay through a legacy nearest-reference parser can open a sibling, and even an isolated Markdown span can reinterpret an embedded @@ label when its destination is unsupported (plan PQ-1).
- A picker-time origin check ends too early when opening resolves asynchronously. Carry source validity through scheduled resolver results and every secondary picker effect, consuming callbacks once; a guardless legacy resolver cannot supply that guarantee by implication (plan PQ-2).
- Native fallback errors are still completion paths. Restore temporary cursor placement in a protected call before propagating gf errors; test an absent non-Markdown target as well as recognized missing Markdown.
- Reusing structural parsing does not mean reusing an editing operation's walls. Navigation boundaries must follow their own contract; sweep every default/configured structural prefix as content, a transcript turn, and a fenced sample. Share the resulting fence mask with candidate collection so those decisions cannot diverge (close BR-1).
- A stateful subprocess fake needs a live contract check for the exact modeled command, not only executable/help discovery. Compare consumed fields and failure outcomes against isolated real fixtures, and document when maintainers rerun it (close BR-2).

## 2026-10-15 (#332 — verification)

- A filesystem preflight cannot establish no-clobber ownership: use an atomic no-replace operation for both the document and its side directory. Exercise a foreign destination appearing after the absence observation.
- Match the complete shared document classifier when selecting a filesystem route; timestamp spelling alone also matches ordinary dated notes.
- A subprocess output pathname can exist before its payload is written. Wait for exact bytes and lifecycle completion, and distinguish a per-request deadline from the budget for a multi-command editor interaction.
- Register new state-directory readers in the corruption registry as they are introduced; reuse the shared directory and checked-write seams before the full-suite boundary.
## 2026-10-15 (#336 — packaging VM guest confinement flake)

- An interactive flow's completion is its last UI effect, not the side file it writes. A probe that drives a login must wait for the flow's own settle signal (here, the reopened model picker) and dismiss it, or the scheduled UI lands over later steps. Assert properties of the object a step created (the captured chat buffer's file), never of current focus. Prove that with a deliberate focus change before the assertion.
- A recognized Markdown span owns its destination even when unsupported: use the same Markdown-only opener for direct and selected navigation, then fall back at the destination; never reinterpret @@ text in its label.
- Multiline scans must receive document context. Reuse the navigation fence memo and lexical structural kinds; test every configured transcript prefix and plain Markdown fenced examples containing chat-like text.

- A multiline inline scanner needs an explicit block-containment rule, not only blank/fence checks. Enumerate heading forms, thematic breaks, quotes, list/chat starts and range edges, with positive supported starts as well as negative joins.

- Enumerate the whole heading grammar in boundary tests: empty/nonempty text, end-of-line/space/tab terminators, levels 1–6 and indentation 0–3, with out-of-grammar positive continuations.

## 2026-10-15 (#319 — canonical review export consumer)

- A versioned export consumer must accept the producer's valid optional and defaulted fields. Test producer examples with unordered modes, tied ordering and omitted mode flags; never turn the current six stock records into schema constraints.
- A successful filesystem move plus nvim_buf_set_name does not make Neovim consider NEW read: its not-edited flag blocks ordinary writes and checktime skips it. Test the next submit/auto-save, acknowledge proven unchanged NEW with a non-bang native read, and reattach native edit observers detached by that read. Never bypass the guard with an unconditional forced write.
## 2026-10-15 (#338 — starter tutorials under project mode)

- When a finding names one spec that breaks under an environment, run the whole suite in that environment before fixing that spec: here it was 14 files, and the cause was a harness invariant (scratch outside any marked project), not each spec. Guard the invariant once at the writer (scratch_placement_spec), and keep per-spec opt-outs out of specs that test the opted-out behavior.
- Seeding shipped content follows the owner's root, not the current primary root: project mode re-primaries chat_dir, so anything the starter installs must use the profile directory captured before setup().

## 2026-10-15 (#230 — no hidden limit in live_models)

- A diagnostic over configuration must know who wrote each entry. Shipped defaults may name things a given environment lacks (a model line an account doesn't serve), so warn only on operator-written entries, and test the defaults against an environment where they would trigger (BR-1).
- Run the full suite on the FINAL code commit before `sdlc merge`, not on an earlier one. A review fix can trip a tree-wide guard (here superseded_comment_spec) that the focused specs never load (#230).

## #343: a fake that ignores a signal is a process you now own

- Replace a wall-clock race window with a state the case holds (a fake that ignores SIGTERM until released), not a longer delay.
- Whoever makes a process unkillable by the normal path must kill it. The fixture reap only sees fixture_process spawns, and a proxy the code under test spawned is outside it. Hold the pids, SIGKILL them in the case, wait for the port to go down, and kill them again in after_each for the failure path.
- Check for leaks while the owner is still alive. A check after nvim exits sees the watchdog's cleanup, not the spec's.

## #344: a report hash is copied from git's output, never retyped

- I sent the hub a typed hash twice in a row; the correction carried a second wrong one. Write any report that names a commit into the message file from `git rev-parse` / `git log --format=%H` with printf, and send that file.

## #226: a dedup no-op must agree with the staleness check

- If a duplicate press is swallowed because a result is outstanding, that result must still be allowed to land for the swallowed press. Key the in-flight record on everything the staleness check reads (here, the origin buffer and window), or a press from elsewhere is dropped by both and nothing happens.

## #243: an output-escaping fix sweeps every sink, not the one the issue names

- The issue named the branch div. The close review found the page `<title>` one level up. For an escaping bug, list every place chat text is written into the output format (title, body, attributes, records restored after the escape) before fixing, and route them all through one escape helper.

## #346: wait on the record you read, not on its file existing

- `vim.fn.writefile` creates the file before its bytes land. A wait that ends on `filereadable` and then reads a value can read an empty file. Make the wait predicate the parsed value itself, and return what the predicate read.

## #347: `mkdir -p` is not race-safe at intermediate levels

- Vim's `mkdir(path, "p")` raises E739 when another process creates an intermediate directory between its check and its create, and it leaves the leaf uncreated. Tolerating EEXIST only for the leaf is not enough. Create one level at a time and accept any level that is a directory afterwards.

## #348: a lock that waiters inspect must be published and retired atomically

- A lock directory made by mkdir and then an owner write, or removed by an rf delete, is visible half-made in both directions. Publish it by renaming a staging directory that already holds the record, and retire it by renaming it away before deleting it.
- A waiter that misses a read counts it as garbage only after re-checking that the same lock (inode and device) is still there.
- Each such re-check needs its own gate test that fails without it.

## #242: a reader that can throw must consume input before it processes it

- If a loop processes a line and only then drops it from its buffer, a throw leaves that line in place. A later flush, such as an EOF still delivered after the failure, then decodes it again. Take the input off the buffer first, and once the reader has thrown, its own flush decodes nothing.
- An intermittent spec failure is evidence, not noise. Loop the case (30–40 runs) and print what differs. Then make the trigger deterministic with a fake knob (here, one frame per read) before fixing, so the regression test fails every time on the old code.
- If the plan says the table is the product, build the table as data first: rows, which providers each applies to, and a pure judge. Hand-written cases that cover the same rows are not the table, and a Core-concepts row naming a pure table must point at a pure file.
- A test that something arrives "incrementally" depends on the timing of the IO it watches. Pace the writer (a per-write delay knob on the fake) so the reads are really separate. Loop the case before trusting it: an unpaced single-byte writer sometimes coalesced into one read.
## #233: when a single-file input becomes a sequence, every consumer of the old input must derive from the sequence

- The close review found four consumers still reading the one file after the tree walk became the request's context: remote resolution, the batch leg's filter, the memory window's count and the topic input. Before building, list everything that reads the old input (here `input_parsed` and `exchange_idx`), and move each to the sequence in the same change.
- A cache shared across files needs one key per file (its resolved path), and a reference is read and written under the key of the file that holds it. A lookup for another file must not create an entry.
- A main merge that deletes a module can break a branch test that requires it, with no textual conflict. After merging main, grep the branch's new code and tests for `require`s of modules main deleted, before running the suite.

## #352: a new rendering form for an existing message kind reuses its builder

- The close review found the off-path summary form restating the summarized branch's summary message and missing its blank-question guard. When a new path emits a message an existing branch already emits, call one shared helper, and carry over that branch's guards with it.

## #349: deleting a local removes its readers too

- Replacing `find_tree_root_file` deleted the local `root` that delete-tree's prompt still read, and the tests stubbed `confirm` without checking its text. Lint caught it in the suite. After deleting a local, run `make lint`, or grep the function for the name, before the suite; and a test that stubs a prompt asserts what the prompt says.

## #353: rendering ownership is per option and survives every repaint

- A renderer record can exist before anything was installed. Exercise plain/no-output views through the adapter, then clear, leave and re-render; pure composition tests cannot catch poisoned adapter cleanup.
- Resize and state refresh must check the same per-option ownership proof as detach. If a window option differs from the last installed value, relinquish that option for the record's lifetime; do not recapture the override as our own proof. Test independent winbar/winhighlight overrides across repaint and cleanup.
- When a width policy protects root and the final two segments, shorten those labels before dropping a protected segment. Include an oversized leaf: a leaf-only fast path must not bypass a combination that still fits.

- A Unicode shortening oracle must assert whole base-plus-combining units and exact production output. Valid UTF-8 and a display-width bound still admit an accent attached to an inserted ellipsis. Use the shared Neovim skipcc adapter in runtime consumers and test the narrow adapter boundary, not only a friendlier unit-test text splitter.
## #354: an ordering the code depends on gets its own test

- The M1 review found no test for recording a submit *before* the send callback's stale-state guard. Every spec kept the buffer alive, so moving the line below the guard stayed green. When a comment says "this must happen before X", write the test where X happens: here, the buffer is wiped while a slow send runs. Then mutate the order to see the test fail.
- Optional work added to a critical callback (here, the attention record in the send completion) goes in a `pcall` with a warning, and a test makes it throw.
- The M2 review found the same family again: the pure model pinned the stale-probe rule, but the glue's capture point (pending IDs read when the probe starts, not when it returns) had no test. An ordering rule needs a test at every layer that can break it. For each interleaving in the plan's ARCH-ORDER list, name the spec that drives production glue, not only the pure core, and mutate the glue to see it fail.
- A scope addition I built in the same session re-derived three facts the codebase already owns: the frontmatter parser, the side-folder path, and a bounded async queue. Before writing a parser, a path rule or a concurrency loop, grep `lua/parley/` for the noun (`frontmatter`, `side_path`, `queue`) and read the owner first. When replacing a slice of a file by index, diff the function list before and after (`grep -n "^function M\."`): mine silently swallowed two functions between the anchors.
## #357: intent that crosses an async callback belongs in the pure model

- A shell flag (`queued_submit`), set by a press and cleared in only one callback, outlived every other outcome: a pending rename, or a reconcile. A later unrelated lookup could then send a submit nobody pressed for. When an intent spans an asynchronous round trip, make it an event field on the pure model's transition (`retry{submit=true}` → `resubmit` effect), so every outcome decides it and unit tests cover each branch. Don't use a flag that each callback must remember to clear.
- Read the code path before accepting an issue's premise. "Alt+Return blocks in vim.wait" was wrong: the submit was already async, and the felt bug was a press that confirmed but never sent.
- When a change moves a deadline, every call site of the timed seam gets a slow-fake test whose delay is past the OLD default. A delay under the old value passes with the change reverted, so it pins nothing. #357 round 2 found the rename stage tested at 2 s against an old 2.5 s.
## #334: transient window values can be cloned

- Test native split creation during a temporary highlight, not only before it.
  Neovim copies window-local options; the shared renderer must restore newly
  copied transient frames using its exact installed-value proof.
- Put the basename in a bounded winbar label and the full path in its one-line
  notification; truncating a path prefix can erase the filename entirely.

## 2026-10-16 (#363 — model the effect, not the function return)

- A returned stop call does not prove anything was killed. A closed-port stall
  fixture must prove a PID was signalled and exited; an unidentified or still
  alive listener needs the real fallback observation. Inject the delay at the
  precise endpoint that crosses its deadline, then record the real effect.
- An await failure does not cancel the operation. Own every synthetic delayed
  callback with the case, cancel its timer at teardown and guard an already
  queued callback before it can resume production work in the next case.

## 2026-10-16 (#362 — check the consumer capabilities of imported prompts)

Before importing a shared protocol, trace every required IO operation through
the receiving adapter. Text composition and matching hashes do not prove that
an artifact-bound single-file edit tool can execute side-doc, cross-file or
previous-read flows. Resolve unsupported routing explicitly before shipping.

For synchronous parsers, test input scale as well as syntax. Per-character
prefix copies, per-token tail copies, repeated list concatenation and unanchored
whitespace patterns can all make an otherwise bounded grammar quadratic. Count
copied bytes where possible and include long whitespace runs in a stall check.

A parser-level benchmark does not cover its semantic resolver. Trace a finding's
family from the user action through every newly added stage, including name
normalization and heading extraction; pin scale through the production entry
point as well as internal helpers before calling the family complete.
## 2026-10-16 (#367 — a picker query that the temp path can match)

- A fuzzy picker spec's query must contain a character no temp path holds
  (such as `+`). Row search text often includes the absolute directory, and
  float_picker matches a query of three characters or fewer against the whole
  haystack. An "unusual" `qzx` matched `beta.md` through the random tempname
  about one run in nine. The failure looked like a repaint race until the spec
  printed the prompt and the rows on timeout. Print state on an intermittent
  await failure before theorising.
- When a rule moves into the pure model, keep the cost bound of the IO it
  replaces. Let the model pick candidates from cheap stat data, then read only
  those. The first draft read every side doc's head on every open.

## 2026-10-17 (#353 — retained navigation is not presentation evidence)

- A rejected observation must revoke presentation eligibility even when history is deliberately retained for Back. Bind cached paint to the observed eligible buffer/name; test every rejection category across resize and re-entry. Window creation can copy installed pixels without copying ownership, so retire proven copies in non-editing windows too.
## 2026-10-17 (#370 — a positive wait bounded by a load guess)

- Bound a wait for an outcome by the path's own deadline, not by a guess at
  load. A positive `vim.wait` returns the moment its condition holds, so a long
  bound costs a passing run nothing; a short one turns machine load into a
  flake. session_sync_spec waited 2 s for a fake `couch` send, and the product
  allows 15 s (`agentic_submit_timeout_ms`), so a loaded suite failed it once
  with the code right (the #355 class). Pin the fix with a fake slower than
  the old literal (`FAKE_COUCH_SLEEP=2.5`). Keep short fixed waits only for
  absence checks, where the bound is the test's cost.
- Trace before blaming ordering: wrapping `couch.run` to log each argv with a
  timestamp showed one process, started 15 ms after the key, with nothing
  queued ahead of it.

## 2026-10-17 (#374 — a sweep and its guard must see every form of the thing)

- Before sweeping a pattern, list every syntactic form it takes, then write the
  guard as an allowlist over all of them. #374's first sweep matched only
  `assert(vim.wait(N, …))`. It missed 185 bare and local-assigned waits, which
  were the most common form. Round 2's denylist of digit literals then missed
  `vim.wait(ms or 3000, …)`. Each gap cost a close-review round. "Allow what
  derives from the budget, or carries a reason" has no form left to escape.
- A mechanical rewrite also rewrites Lua that a spec writes out as a string for a
  child Neovim, where test helpers are out of scope. Pass the value in by
  argument or interpolation.
- Classifying 185 sites as positive, absence or drain parallelised cleanly
  across three subagents, each given disjoint files and the same rule. Fill in a
  prompt's placeholders before sending it: one went out with a literal
  LIST_PLACEHOLDER, and the agent rightly refused to guess.

## 2026-10-17 (#373 — complete-consumer preservation and preflight)

- When a scanner admits wrapped syntax, containment must cover the same span. Per-line code masks cannot protect multiline Markdown links; use exact-width backtick spans across soft breaks and test both new and existing rewrite consumers.
- Recursive output scans cannot distinguish missing files from empty directories at expected leaves. Validate expected file and ancestor types for the whole generated snapshot before the first write; make an earlier output stale so a failure test proves absence of partial mutation.
- Benchmark the complete consumer with every malformed delimiter family, not only its shared scanner. Removing one backtracking pattern left a fallback that copied and resolved each remaining suffix. Use disjoint token spans and exercise both callers.

- The #373 re-review found the sibling failure after paragraph-wide masks: pairing backticks across a heading or list boundary hid live links. Share the scanner’s existing block segmentation rather than introducing a second notion of paragraph; test live rewrites across every boundary as well as preservation within a block.

- A milestone that introduces pure effect vocabulary needs its atlas map at that boundary, even when its IO consumer is deferred. Document inputs, outputs, refusals and which effects do not execute yet; importing fixture documentation alone does not map the projection contract.

- Native rereads need an expected editor postimage as well as a modified flag. A real BufReadPost callback changed parent text during #373's rewrite read, but Neovim cleared modified afterward; the move falsely succeeded. Derive normalized expected lines through the same pure rewrite, compare their hash, and mark differing text unsaved before interrupting. Exercise actual autocmds rather than only wrapping buffer APIs.
- Checkpoint cleanup owns bytes, not names: a recorded future temp path can still point inside an undisplaced orphan or at a foreign file. Validate the publication stage and expected content/inode before deleting; reconstruct a complete unpublished journal checkpoint from fresh witnesses instead of accepting merely well-shaped JSON.

- Run live checks with the operator runtime, not just the preferred test runtime. #373 passed on suite-selected Neovim 0.12.5, then PATH 0.11.7 rejected the existing NUL lease namespace as a Blob. Keep raw identity digests byte-identical across versions: re-encoding them would split the kernel ownership key. Fixed-vector tests on both runtimes guard the boundary; #379 owns systematic version coverage. PARLEY_TEST_NVIM must be in make's environment to affect the shell-based runtime selection, not merely a make command-line assignment.

- Apply native-read postimage checks to recovery handoffs as well as fresh moves. A second read can destroy an autocmd edit even when the first read cleared modified; test both journal versions with real callbacks. Prove raw bytes before invoking an editor hook that reads them: detecting a mismatch afterward cannot restore the buffer the read already replaced.

- A compatibility fix that adds even a rare bounded synchronous utility must update the explicit process census and run its architecture guard. Check the call frequency: #373's SHA utility is once per fresh move's NUL budget lease, not per save or keypress.

- Finalization is part of the replay protocol. A successful editor handoff followed by failed journal deletion must not destroy the protection that retained recovery still needs. Write the intended lock after-state before release, recognize each owned before/after state on replay, and finish durable effects before retiring the journal. Fault-inject after successful effects, not only before them.

- Preflight effect geometry as one relation set: an earlier directory rename must never relocate a later source or create an uncaptured source. Check every declared side/orphan root against both documents and other roots, including absent roots, before saves or protection. A per-case guard for targets inside the source folder misses the reverse extraction case.
- A key remap (#377) has to sweep every spelling users read, not just `<M-x>`:
  `option+i`, `Option+i`, Alt+i and ⌥i in tutorials, READMEs and in-repo
  copies. `git grep -E` has no `\b`, so a pattern that relies on it quietly
  matches nothing; use `git grep -P`. Tutorial prose is now checked against the
  registry in `keybinding_agreement_spec`.
- State that belongs to one in-flight operation lives on that operation's record, not in a parallel field cleared "when its event arrives" (#380 REWORK). The parallel field drifted from the operation through `pending` and `retry`, and a non-terminal matching event cleared it under a live operation. On the record, it is copied, carried and dropped with the operation, with nothing to keep in sync.
- A new spec must pass `tests/arch/*` and `tests/unit/arch_helper_spec.lua` before the recorded suite runs. They police spec authoring: listing files through `arch_helper.worktree_files` (#381) and `vim.wait` taking `arrival.MS`, not a literal (#382). Twice in one session, a new spec cost a full recorded suite run because only its own file had been run.

## 2026-10-17 (#267 — compiler workarounds have a scope)

- Neovim's JIT engine belongs to the whole editor. Protect affected module chunks recursively before their functions compile; never use a plugin's allocator workaround to disable other plugins' JIT. Verify an unrelated function still compiles in the same VM, alongside the protected work.
- A safety policy can make an active-compiler regression pass without exercising its oracle. Count completed traces from the code that matters, then keep any intentional policy opt-out inside that regression's disposable child.
- A diagnostic copy loses path-specific harness settings. Preserve the original corpus budget when moving a spec for instrumentation, and distinguish diagnostic setup failures from the production failure being investigated.

## Probing a working tree against the installed plugin (#384)

- To test working-tree Lua inside a session that already loaded the installed plugin, prepend the checkout to `runtimepath`, not `package.path`. Neovim's runtimepath searcher runs before `package.path`, so a module present in both resolves to the installed copy. In #384 that happened silently: `collaboration.modes` came back nil and the probe looked like a product bug.
- Reload only the modules under test. Clearing every `parley.*` entry from `package.loaded` breaks the installed plugin's already-wired autocmds, and the result is noise.
- Checking an interaction with a completion plugin means measuring both menus at once, Vim's (`pumvisible()`) and the plugin's own view (`cmp.core.view:visible()`). `cmp.visible()` counts Vim's popup as cmp's.

## A random sweep must prove it reaches its adversarial class (#383)

A seeded fuzz loop in presentation_spec passed with its guard removed, because a hand-rolled LCG (`seed * 1103515245 + 12345 mod 2^31`, then `seed % n`) correlates its low bits and never produced the malformed inputs. Rule: a randomized spec counts how often it hits the class it exists for and asserts a floor, and a mutation that removes the guard must turn it red before the spec counts as evidence. Use `math.random` with a fixed `math.randomseed`, not a hand-rolled generator.

## A fix's claim is as wide as its enumeration (#386)

The first ColorScheme fix re-ran only `setup_highlights`, while the atlas said "every group". Five other modules define Parley groups on their own (session_sync, attention, issue_tracker, float_picker, diag_display), and an attached session-sync band lost its color. Rule: before writing "every X" in an atlas or Log, list the X with a grep (`nvim_set_hl(0,`), fix them all through one owner, and add a spec that walks the same grep. Here that is `highlight_groups.keep` plus a guard that fails on an unregistered module. A related trap: an autocmd callback that returns a truthy value deletes the autocmd, so a definer that returns its namespace id can't be passed bare.

## 2026-10-18 (#388 — extract process receipts once)

- When a consumer needs a second field from an external receipt, extend one
  pure parser to return the receipt's fields and keep compatibility wrappers.
  Independent full-format patterns for ID and sender can drift when the
  producer changes its grammar. #388's close review recorded this as a minor,
  non-blocking cleanup in attention.record / parse_message_id.

- New picker key knobs belong under a `<picker>_mappings` table, matching
  the architecture guard for resolver-installed `help_only` actions. Include
  single_source_sweeps_spec in targeted verification when adding one: key
  behavior/help tests alone do not enforce its installation declaration.

- A punctuation suffix alone does not make a short fuzzy fixture selective:
  q+ typo-matches an alphanumeric path token starting q (distance 1).
  Punctuation-only +++ uses exact subsequence matching and cannot typo-prefix
  any word token. Pin negative and positive scorer results on an adversarial
  path before asserting picker row counts; #388 reproduced the old failure
  deterministically without changing the timeout or production matcher.

- #390: Cycle recovery in a parent forest must start within the cycle, not at
  the first unvisited descendant. Test reverse-ordered tails entering self and
  multi-node cycles, including ancestor-search context and linear traversal.

## 2026-10-19 (#392 — preserve viewport before the first repaint effect)

Saving a picker view after refiltering saves the reset viewport. Capture it before reflow/refilter and use that same proof while resolving the selected identity. Test background success and failure before typing, with a selected row below the fold in each scope; a one-row filtered test cannot catch hidden selection.
- #391: When a scope change widens a rule ("every file shows a path"), sweep
  the old gates that encoded the narrower rule (the lone-root hide) and the
  repaint triggers keyed on the old inputs (path change only). Every read of a
  user file on an autocmd path is guarded: an unreadable file is data, not an
  error out of BufEnter.

- #397: A test added to a spec file proves nothing until you have watched that
  file run. Check that the spec you run maps the test file
  (`atlas/traceability.yaml`) before treating a green targeted run as evidence;
  map a model's spec under the atlas spec that owns the model.

- #399: A diagnostic capture that persists process listings records argv, and
  argv carries secrets (curl auth headers). Ask the OS for the executable alone
  (`ps -o comm=`) so the secret is never read, rather than redacting after the
  fact. Run the repo's arch guards (`prepare_dir_spec` and friends) before a
  close: a targeted spec run doesn't include them.

- #400: A hang fake made from a shell script and `sleep` doesn't die with its
  shell. vim.system reports an exit only after the stdio pipes close, and an
  orphaned `sleep` still holds them. Make the fake's sleep end on the script's
  SIGTERM. Then red-check every new regression test against the unfixed code:
  the first probe test passed without the fix, because duplicate attaches on
  open spawned a second, unhung probe. Key a test's wait on the mechanism's own
  evidence (a timed-out result), not on a count that something else can raise.

- #400 close review: a Revisions entry doesn't retire the claim it replaces.
  When a revision changes what the Spec or Plan says, strike the old sentence
  where it stands and write the current one beside it, citing the Revision.
  Readers and reviewers read the body first, so a body that still states the
  old design is a second, contradicting Spec.

- #394: Read a flake's recorded numbers before blaming the code under test.
  `queued_ms=0` with `ran_ms` equal to the deadline meant the request never
  queued, so the queue invariant held and only the test's real-time slack
  broke. Prove an ordering invariant with controlled scheduling, where a stub
  answers only when the test says. Keep the real-process test for the
  boundary, with a deadline load can only slow, and with lower bounds the
  fixture enforces, not guesses.

- #401: An inner deadline that exists to beat an outer one must derive from
  it, not from a number that happened to look big enough. The helper's 60 s
  bound assumed the 180 s run-alone budget, while every helper user ran on the
  default 50 s; the close review caught it. Pass the outer budget to where the
  inner one is computed, and pin the relation with a test that runs through
  the real outer mechanism.

- #398: Importing a generated CI workflow can still introduce authored consumer configuration. Document its ownership, update and failure recovery in repository-owned README and indexed atlas guidance; an ignored inherited workflow page does not satisfy that surface.

- #398 landing: shipped atlas prose must not link relatively into ignored weave overlays. Use a pinned upstream link for inherited contracts and run documentation_spec after adding atlas links; warm-checkout existence hides cold-checkout failures.

- #407: Navigation must separate a destination path from its fragment before file-type checks, and must not restore a source cursor over a successful same-file anchor jump. Test real mapping completion before asserting cursor state; waiting only for the desired cursor can hide an ordering defect behind a stalled fixture.

- #407 close: a GitHub-style anchor is based on heading content, not raw Markdown. Pin whitespace, formatting and duplicate-slug classes, with literal/code controls. A fence memo must retain opener character and width instead of toggling on any delimiter. Determine container boundaries at a fence opener before its contents are excluded; test outside-link negatives as well as successful links.

- #407 round2: navigation boundaries belong to the occurrence scanner's block vocabulary, not the narrower editing-heading dialect. Define ownership by an item's content indentation and enumerate outside-block negatives with indented positive controls. Keep renderer-dependent heading syntax outside the anchor contract unless explicitly required; unsupported syntax must fall back visibly rather than invent an anchor.

- #407 round3: repeated inline-normalization findings mean the hand-written grammar is the wrong owner. Use bundled markdown_inline structure for visible source spans (ordinary text is in gaps), and keep anchor matching tolerant through a documented shared key. Verify Unicode API semantics: Vim POSIX alnum is ASCII-only, and word classes are not general Unicode categories; take the actual capability boundary to the TL before adding data or approximations.

- #407 close4: after a scope revision, check acceptance criteria and atlas module classifications as well as Spec/Revisions and user instructions. A revised parser/key contract must retire exact-slug acceptance wording, and adding an editor parser changes the lookup's integration label even when its level helper remains pure.
- #404 close BR-1: Neovim skips InsertLeave on Ctrl-C. State representing an
  actual editor mode must follow ModeChanged too, through one departure
  handler, with native tests for every exit family rather than Escape alone.
  Enumerate every automatic release consumer (including move finalization)
  before claiming that an intent stays protected for its full lifetime.

- #404 close BR-2: A persisted cleanup intent authorizes an old turn, not the
  current one. Revalidate live release eligibility immediately before each
  destructive effect and before recovery attachment can acquire obsolete state.
  Test recovery before cleanup, between effects and after cleanup, with a new
  user intent as well as the ordinary idempotent replay controls.

- #408: A native buffer observer without on_reload is detached by reload. A
  first-edit ordering test must retain the observer through native rereads, or
  it only measures a missing callback. Serialize make/test-spec within one
  checkout: census cleanup from one run can interrupt another.

## 2026-10-21 (#408 — release ownership evidence)

- Two missing witnesses comparing equal prove nothing. A destructive operation
  that accepts an exact local witness must require that witness to exist before
  comparing bytes. Exercise an unreadable on-disk sidecar with no local witness,
  in addition to ordinary foreign replacement cases.

## 2026-10-22 (#408 — refusal is not history retirement)

- Keep an edit turn's original baseline through unavailable and refused retries,
  even after auto-save. Status observation cannot prove release; one private
  transition owner must arbitrate acquisition, freshness, release and move
  restoration. Test the complete failure/retry sequence, not each flag alone.
- A non-modifiable buffer refuses native i before InsertEnter. A recovery action
  attached only to InsertEnter is unreachable after refusal. Test recovery with
  actual input and preserve the native action for every supported retry key.

- #408 recorded suite: README command inventories must inspect real command
  scopes. A buffer-local recovery command should not become global merely to
  satisfy a global-only oracle. Assert absence from ordinary contexts and
  presence on an actual attached buffer, using the existing executable fake
  for attachment's status/round queries; even a declaration check can spawn IO.
