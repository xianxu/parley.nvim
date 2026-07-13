# Tooling

## Development Commands
- Manual testing: Start Neovim and use `:lua require('parley').setup()` followed by `:Parley`
- Run tests: `make test` (runs all unit + integration tests via plenary.nvim in headless Neovim)
- Lint: `make lint` (requires `luacheck`; see install note below)
- Run tests for one spec: `make test-spec SPEC=chat/lifecycle` (uses `atlas/traceability.yaml` mapping)
- Run tests for changed specs: `make test-changed` (runs mapped tests for changed `atlas/*/*.md` files), this is faster than full test run
- Run the report-only real chat-typing benchmark: `make perf` (details below).
- Refresh SSE fixtures: `ANTHROPIC_API_KEY=... OPENAI_API_KEY=... make fixtures`
- Test files live in `tests/unit/` (pure logic, no Neovim APIs) and `tests/integration/` (full Neovim runtime)

## Chat-Typing Performance Report

`make perf` opens normally attached Parley chat buffers at 100, 1,000, and
5,000 lines, performs 5 warmups and 20 measured samples, and reports the real
insert-event/redraw interval plus isolated timezone, footnote, decoration, and
spell phases. Inclusive `edit_total` overlaps the isolated measurements; do not
add or subtract the isolated phase timings as if they decomposed it.

The command prints median/p95 timings and scaling ratios, then overwrites
`.test-tmp/perf/parley-chat-typing.json`. Override the destination (including a
new parent directory) with:

```sh
make perf PERF_OUTPUT=/path/to/parley-chat-typing.json
```

The JSON envelope has `schema_version`, `generated_at`, `timing_unit`,
`environment`, and `scenarios`. Every scenario records `name`, `phase`,
`attribution` (`inclusive` or `isolated`), `line_count`, `iteration_count`,
`elapsed_ms` (`samples`, `median`, `p95`), and `work`
(`line_read_calls`, `lines_requested`, `full_buffer_reads`, and
`structure_rows_processed`). Generated reports are ignored artifacts; durable
baseline/optimized summaries belong in the issue log.

Elapsed timings are report-only and never fail CI. Scenario validity and
structural bounds are correctness gates: the measured insert event must not
perform a full-buffer read; decoration reads stay within the viewport/context
allowances; matched 1,000/5,000-line viewports request identical work; and
ordinary prose edits process the same bounded structure rows. Timezone and
managed-footnote diagnostics deliberately remain stale during `TextChangedI`,
then converge synchronously on `InsertLeave`, normal `TextChanged`,
`BufWritePost`, `BufEnter`, `WinEnter`, and stream-leg finalization. Structural
marker edits may suppress decorations during insertion; the same convergence
events rebuild structure before returning. Redraw itself consumes only the
buffer-owned bounded structure snapshot and visible/context rows.

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
