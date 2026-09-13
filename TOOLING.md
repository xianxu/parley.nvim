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
the first's scratch, loudly. Use a separate worktree (the root is keyed by
checkout) or a distinct `TEST_ENV_ROOT` for concurrent suites.

## Chat-Typing Performance Report

`make perf` opens normally attached Parley chat buffers at 100, 1,000, and
5,000 lines, performs 5 warmups and 20 measured samples, and reports the real
insert-event/redraw interval plus isolated timezone, footnote, decoration,
spell, structure-splice (an Enter and its join, through the real buffer
attachment), and structure-rebuild phases. Inclusive `edit_total` overlaps the
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

The JSON envelope has `schema_version: 1`, `generated_at`,
`timing_unit: "milliseconds"`, `environment` (`os`, `nvim`, and the measured
git `commit`), and `scenarios`. Every scenario records `name`, `phase`,
`attribution` (`inclusive` or `isolated`), `line_count`, `iteration_count`,
`elapsed_ms` (`samples`, `median`, `p95`), and `work`
(`line_read_calls`, `lines_requested`, `full_buffer_reads`,
`structure_rows_processed`, and `structure_entries_copied` — the slots a
structure splice copies, which row counts cannot see; the list is single-sourced
as `tests/perf/harness.lua`'s `WORK_FIELDS`). Generated reports are ignored
artifacts; durable baseline/optimized summaries belong in the issue log.

Elapsed timings are report-only and never fail CI. Scenario validity and
structural bounds are correctness gates: the measured insert event must not
perform a full-buffer read; decoration reads stay within the viewport/context
allowances; matched 1,000/5,000-line viewports request identical work;
ordinary prose edits process the same bounded structure rows and copy nothing;
and an Enter-and-join splice reads no full buffer, does the same row work at
both sizes, and reports exactly its two-array copy (`4n + 2` slots). Timezone and
managed-footnote diagnostics deliberately remain stale during `TextChangedI`,
then converge synchronously on `InsertLeave`, normal `TextChanged`,
`BufWritePost`, `BufEnter`, `WinEnter`, and stream-leg finalization. Structural
marker edits never suppress decorations: they leave the structure approximate
and still rendering, and it is rebuilt 250 ms after the burst or at the next
convergence event. Redraw itself consumes only the buffer-owned bounded
structure snapshot and visible/context rows.

Under the test harness that scheduled rebuild never fires on its own:
`tests/minimal_init.vim` exports `$PARLEY_TEST_MODE`, and a spec that wants the
real clock opts in with `highlighter._set_repair_deferral(nil, ms)` or fires a
repair by hand (`tests/helpers/decoration.lua` `manual_deferrals`). It is an
environment variable, not `g:parley_test_mode`, because `PlenaryBustedFile`
runs each spec in a child nvim that inherits the environment but not this
init's `g:` variables.

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
