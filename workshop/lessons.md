# Lessons

Compact rules distilled from Parley.nvim's review and integration history.
Incident detail belongs in the issue or plan that owns it.

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
