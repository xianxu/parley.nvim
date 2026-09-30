# Tooling

## Development Commands
- Manual testing: Start Neovim and use `:lua require('parley').setup()` followed by `:Parley`
- Run tests: `make test` (runs all unit + integration tests via plenary.nvim in headless Neovim)
- Lint: `make lint` (requires `luacheck`; see install note below)
- Run tests for one spec: `make test-spec SPEC=chat/lifecycle` (uses `atlas/traceability.yaml` mapping)
- Run tests for changed specs: `make test-changed` (runs mapped tests for changed `atlas/*/*.md` files), this is faster than full test run
- Run the report-only real chat-typing benchmark: `make perf` (details below).
- Refresh SSE fixtures: `ANTHROPIC_API_KEY=... OPENAI_API_KEY=... make fixtures`
- Test files live in `tests/unit/` (focused module contracts) and `tests/integration/` (full Neovim runtime)

## Standalone Contributor Setup

A public checkout includes its runtime vocabulary and a real root Makefile.
Neovim, git, Python 3, ripgrep, luacheck, and Plenary are the test dependencies;
ariadne, Go, CUE, and sdlc are not required for ordinary plugin tests.
Point the harness at an existing Plenary checkout explicitly:

```sh
make test PLENARY=/absolute/path/to/plenary.nvim
```

The default remains `~/.local/share/nvim/lazy/plenary.nvim` for existing users.
A missing dependency fails early with setup advice. The override is also used
by the child Neovim processes, including from paths with spaces.

`make check-fresh-clone PLENARY=/absolute/path/to/plenary.nvim` snapshots only
tracked/staged files into an isolated archive, boots and creates a chat without
a `.git` directory, tests missing/damaged vocabulary, then runs the full suite
in a second indexed extraction. It leaves the actual git index and untracked
chat work alone. Stage new code/tests before this check; unstaged changes to
already tracked files are included. For a specific release tree use
`scripts/check-fresh-clone.sh --full --ref <commit>` with `PLENARY` exported.

Maintainers can run `./bootstrap.sh` to restore ignored infrastructure. The
upstream-owned root Makefile remains a real seeded file; product targets live
in Makefile.local/Makefile.parley. `make check-vocabulary` regenerates from the
CUE source and compares the complete JSON without modifying it. This requires
ariadne plus its vocabulary exporter and CUE. The generic CI workflow invokes
`scripts/ci-setup.sh` to provision those tools before the merge check.

Run `make check-sdlc-conformance` whenever the optional command runner changes
and before closing such work. It checks real command discovery/help without
creating issues. Missing sdlc makes this explicit maintainer check fail; normal
tests use the filesystem-backed `tests/fixtures/fake_sdlc` instead.

## Test Scratch Directories

The harness gives every run its own `HOME`, `XDG_*`, and `TMPDIR` so tests never
touch your real config. Those trees live **outside the repo**, under

```
$TMPDIR/parley-test-env/<checkout-name>-<cksum-of-path>/{home,xdg,tmp}
```

Print the resolved path with `make -n test-clean-env`, or override the whole
root with `make test TEST_ENV_ROOT=/some/where`.

They sit outside `$(CURDIR)` deliberately (#202). Eight parallel jobs create and
delete entries in the scratch tmp dir for the whole run, while the `find`/`grep`/
`ack` tool specs traverse the repo to exercise the real tree — and one of them,
`grep`'s "defaults missing path to cwd", cannot be written any other way. When
the scratch lived in `.test-tmp/`, those specs raced a directory vanishing
mid-traversal and `find` exited nonzero, which read as an unrelated flake.
Keeping the churn out of the tree the specs walk is what makes the suite
deterministic; no spec has to defend itself.

`make test` runs `make test-clean-env` first, so each full run starts from an
empty root. It removes the `home`, `xdg`, and `tmp` leaves under the root — never
the root itself — so pointing `TEST_ENV_ROOT` at a directory holding anything
else is safe. It also removes the pre-#202 in-repo `.test-home`, `.test-xdg`,
and `.test-tmp` directories if they are still around.

Run only one `make test` per checkout at a time: a second concurrent run deletes
the first's scratch, loudly. Use a separate worktree for concurrent suites;
a distinct `TEST_ENV_ROOT` isolates scratch but does not isolate the process census.

## Orphaned test processes

Test targets reap processes left by an interrupted earlier run before starting,
then report survivors and fail at the end. The census is scoped to this checkout.
Do not run test targets concurrently in the same checkout: the census cannot
distinguish another run's processes from leaks and can kill them.

To inspect and reap survivors manually, use the physical checkout path. Under a
symlinked working directory (including macOS `/tmp`), `$PWD` can differ from the
path the census matches. On macOS, `pgrep -f` failed to find these fixtures even
when `ps` found them; do not use it as a cleanup check.

```sh
ROOT=$(pwd -P)
ps -Ao pid=,ppid=,args= | grep "$ROOT/tests/" | grep -v grep
python3 scripts/reap-test-orphans.py --root "$ROOT" --phase after
```

The original leak held about 11 GB resident while nearly idle, leaving the
memory compressor busy; low CPU use did not mean it was harmless.

## Chat-Typing Performance Report

`make perf` opens normally attached Parley chat buffers at 100, 1,000, and
5,000 lines, performs 5 warmups and 20 measured samples, and reports the real
insert-event/redraw interval plus isolated timezone, footnote, decoration,
spell, structure-splice (an Enter and its join, through the real buffer
attachment), and structure-repair phases. Inclusive `edit_total` overlaps the
isolated measurements; do not add or subtract the isolated phase timings as if
they decomposed it.

The command prints median/p95 timings and scaling ratios, then overwrites
`$(TEST_TMP)/perf/parley-chat-typing.json` — see *Test Scratch Directories*
above for where that resolves. The default path is inside the `tmp` leaf that
`make test` wipes, so a report left there does not survive the next test run;
pass `PERF_OUTPUT` to keep one. Override the destination (including a new parent
directory) with:

```sh
make perf PERF_OUTPUT=/path/to/parley-chat-typing.json
```

The JSON envelope has `schema_version: 4`, `generated_at`,
`timing_unit: "milliseconds"`, `environment` (`os`, `nvim`, and the measured
git `commit`), and `scenarios`. Every scenario records `name`, `phase`,
`attribution` (`inclusive` or `isolated`), `line_count`, `iteration_count`,
`elapsed_ms` (`samples`, `median`, `p95`), and `work`
(`line_read_calls`, `lines_requested`, `full_buffer_reads`,
`structure_rows_processed`, and `structure_entries_copied` — the slots a
structure splice copies, which row counts cannot see; the list is single-sourced
as `tests/perf/harness.lua`'s `WORK_FIELDS`). Schema 2 adds `bytes_read`
(returned string bytes, excluding newline separators), `index_nodes_visited`,
`dependency_nodes_visited`, `anchors_resolved`, `fold_groups_visited` (outer
fold deletion targets), and `native_fold_ops` (`zj`, `zD`, and fold creation
commands). Schema 3 adds `index_entries_visited`, `metadata_values_copied`,
and `summary_values_copied`, so bounded leaf counts cannot hide nested metadata
work. Schema 4 adds `diagnostic_bytes_processed`, `diagnostic_matches_processed`,
`native_diagnostic_sets`, `native_diagnostic_entries`, and
`diagnostic_message_bytes`. Message bytes measure UTF-8 diagnostic message
assembly/publication, not total Lua object memory. The direct document-core benchmark populates these from actual index
statistics; zero on a legacy path does not mean its array copies are free.
Generated reports are ignored
artifacts; durable baseline/optimized summaries belong in the issue log.

The `fold_maintenance` and `stream_human_interleave` phases add many-exchange
ownership baselines. The latter interleaves real keyboard input with the production
response handler under controlled provider delivery, and verifies typed-ahead text
survives. Its inclusive timing/work includes scheduled editor convergence. These
phases record current scaling costs; they do not certify bounded ownership work
or concurrent tool execution.

Elapsed timings are report-only and never fail CI. Scenario validity and
structural bounds are correctness gates: measured insertion must not read the
whole buffer; decoration pages stay within 256 rows and 64 KiB; ordinary body
edits and Enter/join use bounded local index work instead of copying row arrays.
The inclusive `enter_join_total` phase drives real Insert-mode Enter and Backspace
plus redraw. `structure_splice` isolates their attachment work after setup and
confirmation. Initial document hydration is outside the measured interval.

The shared document coordinator repairs uncertain structure in scheduled slices.
Tests can use `Document.repair_step` or `Document.drain` with explicit budgets;
production scheduling retains its own small slice. Native fold operations and
diagnostic publication are counted separately from indexed queries because their
cost can scale with the affected output. The diagnostic parser consumes bounded
chunks, while publishing many diagnostics necessarily visits their output entries.

For an optional manual comparison, repeat ordinary typing with
`:MarkdownPreview` enabled. The automated report intentionally excludes that
external plugin so its measurements attribute only Parley-owned work.

## Installing `luacheck` (macOS)

`luacheck` 1.2.0 (current stable) is incompatible with Lua 5.5's stricter
`<const>` semantics — loading fails with `attempt to assign to const variable
'field_name'`. Brew's `lua` formula tracks latest, so a fresh
`brew install luarocks` pulls in 5.5 and breaks lint.

Install against Lua 5.4 instead:

```
brew install lua@5.4
luarocks --lua-version=5.4 install luacheck
ln -sf "$(brew --prefix lua@5.4)/bin/luacheck-5.4" "$(brew --prefix)/bin/luacheck"
```

Verify with `luacheck --version`. If `make test` still complains, ensure
`luacheck` is on `PATH` ahead of any 5.5 install.

## Local app experience

Run `./parley_app` from the checkout to use the real packaged starter with the
current local code. The helper launches outside repo mode and reuses a dedicated
demo profile; `PARLEY_DEMO_DIR=/path/outside/repo ./parley_app` selects another.
Python 3 prepares a checksummed editor bundle beneath that profile, verifies its
complete payload before every launch, and retains a shared reader lease until
Neovim exits. Initial provisioning needs network access; reuse of a verified
bundle does not. Normal Parley configuration is untouched.

- `./parley_app --tutorials`: use this checkout's `packaging/tutorials/` as the
  chat folder, so edits change the release's source documents directly.
- `./parley_app --nuke`: delete only the owned demo profile and exit. Launch
  again for first-run setup; this includes provisioning the editor bundle again.

Verify the launcher boundary with `python3 tests/packaging/test_local_app.py`.

`./parley_app --demo` runs the checkout with the separate configuration in
`demo/init.lua`, Screenkey and an empty chat. The Git-ignored `demo/workspace/`
has its own `.parley` marker and isolated profile. `--demo --reset` clears
recording content and editor state while retaining dependencies/login;
`--demo --nuke` clears the entire workspace. Both delete without a backup and
require the editor to be closed. [demo/README.md](demo/README.md) describes
configuration, exact reset paths and recording commands. Neither mode needs
Homebrew; both require Python 3. The recording profile adds the manifest's
Screenkey member to the same app dependency set. Relaunch after changing local
code. A mismatched or corrupt managed bundle refuses launch with a repair
command; old Lazy caches and unrelated plugin checkouts are not deleted.

Demo launch/reset operations serialize through a sibling `.launcher-lock`
directory. A competing operation fails with its lock path. After a crashed
launcher, close launchers and remove that empty lock directory before retrying.

## Editor dependency bundles

`lua/parley/editor_dependencies.lua` owns plugin repositories, full commits,
archive URLs/checksums and platform Preview binary checksums. Its `app` membership
is shipped by Homebrew; `recording` also includes Screenkey. Theme metadata,
starter specs, local provisioning and formula resources derive from this source.
CLI executable dependencies remain in the separate `parley.deps` registry.

The Python standard-library assembler requires Python 3 and Neovim. Run from the
checkout root; global options precede the subcommand:

```sh
bundle_root="${XDG_CACHE_HOME:-$HOME/.cache}/parley-editor-bundles"
bundle=$(python3 scripts/editor-dependencies.py --runtime "$PWD" --profile app prepare --root "$bundle_root")
python3 scripts/editor-dependencies.py --runtime "$PWD" --profile app verify --bundle "$bundle"
python3 scripts/editor-dependencies.py --runtime "$PWD" --profile app run --root "$bundle_root" -- \
  env NVIM_APPNAME=parley PARLEY_RUNTIME="$PWD" nvim -u "$PWD/packaging/starter-config/init.lua"
```

`prepare` prints the complete bundle path. `verify` prints its machine-readable
receipt after comparing the complete payload, including unexpected files.
`run` verifies/prepares, then execs the editor while retaining a shared lock;
use it for writable development bundles so repair cannot remove an active tree.
`--profile recording` includes recording dependencies. Platform detection is
automatic; `--platform macos-arm64`, `macos` or `linux` selects an explicit
artifact for build/projection checks. Linux ARM has no supported Preview binary.
Selecting another platform does not prove its executable runs on that platform.

To provision from local archives, add `--archives /path/to/archives` before
`prepare` or `run`. The directory must be complete: missing files fail instead
of falling back to the network. Plugin archive names can be
`<name>-<commit>.tar.gz` or the URL basename; Preview uses its URL basename.
All bytes are still checked against the manifest. Downloaded archives are bounded
to 100 MiB and 120 seconds each; no upstream install script is executed.

For a damaged managed bundle, close its editors and explicitly repair its owned
root, then prepare again:

```sh
python3 scripts/editor-dependencies.py --runtime "$PWD" --profile app repair --root "$bundle_root"
python3 scripts/editor-dependencies.py --runtime "$PWD" --profile app prepare --root "$bundle_root"
```

Repair removes only recognized bundle/staging children under the marked root;
it refuses unowned roots and takes the same exclusive lease as publication.
For `./parley_app`, use the printed demo profile's `editor-dependencies` directory
as `bundle_root`; for `--demo`, it is `demo/workspace/editor-dependencies`.
The normal local root is separate from the example root above. Old Lazy caches,
chats, credentials and personal plugin directories are not repair targets.
Homebrew bundles are immutable package payloads: repair those with Homebrew
reinstall/upgrade, not this development-root command.

To update a pin, change the authoritative manifest after obtaining the immutable
source archive and computing its SHA-256. Preview changes also require the
extracted binary's SHA-256 for every supported artifact. Retain licenses and
review the dependency closure. Do not copy commits into theme/starter/formula
consumers. Export the selected record set with:

```sh
nvim --headless -u NONE -i NONE -l "$PWD/scripts/export-editor-dependencies.lua" app macos-arm64
```

Verification commands:

```sh
python3 -m unittest discover -s tests/packaging -p 'test_editor_dependencies.py'
python3 tests/packaging/test_local_app.py
make test-spec SPEC=infra/packaging
make test-spec SPEC=infra/starter
scripts/check-editor-bundle.sh
```

Run mapped suites sequentially. The last command is a macOS release gate: it
assembles a fresh real bundle, checks external-network denial, permits loopback
Preview, and exercises installed cold/warm startup plus the local app and recording
launchers. The recording check uses a temporary checkout and verifies Screenkey;
it does not write into your checkout's demo workspace. The gate fails if enforcement is
unavailable. `PARLEY_EDITOR_ARCHIVES=/path/to/archives` supplies a complete local
archive set to that runner. Compare its before/after verification reports to
check package immutability; passing unit tests alone is not offline evidence.
`scripts/release-parley.sh` runs the gate from the extracted immutable tagged tree
before any tap write, including publication retries. Running the gate or these
tests does not create a tag, release or tap publication.
