# Lessons

Compact rules distilled from Parley.nvim's review and integration history.
Incident detail belongs in the issue or plan that owns it.

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
