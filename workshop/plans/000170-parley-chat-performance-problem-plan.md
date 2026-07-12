# Parley Chat Performance Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a reusable report-only Neovim performance suite, then make Parley's synchronous typing and redraw work independent of total chat length without changing visible semantics.

**Architecture:** A shared `LineReader` is the only buffer-text seam for measured diagnostic/highlight paths, so production reads and work counters derive from one source (`ARCH-DRY`). Pure statistics and highlight-structure transforms stay separate from Neovim adapters (`ARCH-PURE`); diagnostics use explicit lifecycle events while decoration consumes a buffer-owned structural cache instead of a speculative incremental exchange model (`ARCH-PURPOSE`).

**Tech Stack:** LuaJIT, Neovim Lua API, Plenary busted, Make, `vim.json`.

---

## Core concepts

### Pure entities

| Name | Kind | Lives in | Status |
|---|---|---|---|
| `PerfSampleSet` | PURE | `tests/perf/harness.lua` | new |
| `PerfReport` | PURE | `tests/perf/harness.lua` | new |
| `HighlightStructure` | PURE | `lua/parley/highlight_structure.lua` | new |

`PerfSampleSet` copies and sorts elapsed samples to compute median/p95. One
scenario owns one sample set; all reporters consume the same summary.

`PerfReport` validates and serializes the versioned envelope. It keeps phase,
attribution, units, environment, and work counters explicit so inclusive and
isolated timings cannot be treated as additive.

`HighlightStructure` is the canonical decoration-state grammar after extraction:
highlighter-local prefix/draft/reasoning/tool/code classification moves here;
`define.lua` remains the canonical managed-footnote predicate and is injected;
`chat_parser.lua` consumes the shared structural classifier while retaining
semantic content assembly. The structure indexes fingerprints, footer start,
draft ranges, and state checkpoints. One buffer cache owns one structure.

### Integration points

| Name | Kind | Lives in | Status | Wraps |
|---|---|---|---|---|
| `LineReader` | INTEGRATION | `lua/parley/line_reader.lua` | new | Neovim text reads + work observer |
| `DiagnosticRefresh` | INTEGRATION | `lua/parley/diagnostic_refresh.lua` | new | diagnostic lifecycle autocmds |
| `HighlightStructureCache` | INTEGRATION | `lua/parley/highlighter.lua` | modified | buffer attachment/generation/redraw |
| `ChatTypingScenario` | INTEGRATION | `tests/perf/chat_typing.lua` | new | real Neovim input/autocmd/redraw |
| `make perf` | INTEGRATION | `Makefile.parley` | modified | isolated environment + report output |

`LineReader` owns a buffer-scoped observer registry. `set_observer(buf, fn)`
returns an opaque token; `clear_observer(buf, token)` prevents one scenario from
clearing another; `with_phase(buf, phase, fn)` labels nested reads and restores
the prior phase even on error. Every `for_buffer(buf)` instance consults that
registry, so normally attached production consumers are observable without test
configuration leaking into their constructors. `lines`, `text`, and `line`
preserve native results while emitting `{phase,api,start,end,lines_requested,
full_buffer}`. Teardown clears registry state.

All row indices are 0-based and ranges half-open. `reader:lines(start0,end0,
strict)` reports requested and returned counts separately; `-1` means the native
end-of-buffer sentinel and is a full-buffer attempt only when `start0==0`.
`reader:text(sr,sc,er,ec,opts)` reports touched rows (`max(0,er-sr+1)` when a
partial end row is included); `reader:line(row0)` requests exactly one row.
Invalid-buffer errors match native behavior and still emit the attempted event.
Observer records are `{buf,phase,operation,requested={...},returned_lines,
lines_requested,full_buffer,structure_rows_processed}`. `record_work(buf,event)`
uses the same registry for CPU-side structure work without a text read.

`DiagnosticRefresh.refresh(buf)` synchronously invokes timezone then footnote
refresh. Its setup owns `InsertLeave`, `TextChanged`, `BufWritePost`, `BufEnter`,
and `WinEnter`, explicitly not `TextChangedI`; stream finalization calls the same
entry point. Buffer-validity checks and idempotent teardown make later event
delivery harmless; this synchronous adapter has no generation machinery.

`HighlightStructureCache` attaches once per Parley buffer and is valid before the
buffer is renderable. `on_lines` reads/classifies only changed rows. Body-only
edits and locally safe body-line splices update in bounded work; structural
fingerprint changes mark the cache dirty without scanning a suffix. Dirty redraw
returns false. Named non-keystroke convergence events synchronously rebuild
before returning. It clears on detach/unload/delete; re-entry builds once.

`ChatTypingScenario` calls normal setup, opens a real chat window, edits via
Neovim insert input, observes `TextChangedI`, forces redraw, and records inclusive
and isolated samples after warmup/counter reset. Timing never gates; validity and
structural bounds do.

---

## Chunk 1: Measurement foundation and baseline

### Task 1: Pure performance statistics and report schema

**Files:**
- Create: `tests/perf/harness.lua`
- Create: `tests/unit/perf_harness_spec.lua`
- Modify: `tests/minimal_init.vim` only if `tests.perf.*` is not already loadable

- [ ] Write failing tests for odd/even median, nearest-rank p95, input
      non-mutation, empty-sample rejection, scenario validation, exact JSON
      envelope keys, and terminal rendering.
- [ ] Run
      `nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/unit/perf_harness_spec.lua' -c 'qa!'`;
      expect module-not-found RED.
- [ ] Implement `summarize(samples)`, `measure(fn, iterations, now)`,
      `new_report(environment)`, `add_scenario(report, scenario)`,
      `encode(report)`, and `render_table(report)`. Inject `now`; default to
      `vim.uv.hrtime`. Validate the exact spec schema.
- [ ] Rerun the spec and `luacheck tests/perf/harness.lua
      tests/unit/perf_harness_spec.lua`; expect green and zero lint findings.
- [ ] Commit exact changed files as `#170: add reusable performance report core`.

### Task 2: Instrumented LineReader seam

**Files:**
- Create: `lua/parley/line_reader.lua`
- Create: `tests/unit/line_reader_spec.lua`
- Create: `tests/arch/performance_line_reader_spec.lua`
- Modify: `lua/parley/timezone_diagnostics.lua`
- Modify: `lua/parley/skill_render.lua`
- Modify: `lua/parley/highlighter.lua`
- Modify: `lua/parley/spell.lua`

- [ ] Write failing fake-delegate tests proving `lines`, `text`, and `line`
      preserve results and record exact call count, requested line count, and
      `full_buffer=true` for `0,-1`.
- [ ] Write a failing architecture test using
      `tests.arch.arch_helper.assert_pattern_scoping` that forbids direct
      `nvim_buf_get_lines`, `nvim_buf_get_text`, and `vim.fn.getline` in the
      exact scope `{line_reader.lua, highlighter.lua,
      timezone_diagnostics.lua, skill_render.lua, spell.lua}` with
      `allow_only_in={"lua/parley/line_reader.lua"}` for each pattern. Also grep
      `nvim_buf_get_text`, `nvim_buf_get_lines`, `vim.fn.getline`, and
      `nvim_get_current_line`; classify future equivalents explicitly.
- [ ] Run both new specs; expect missing module plus existing direct-read
      violations.
- [ ] Implement `set_observer`, token-checked `clear_observer`, `with_phase`,
      `clear_buffer`, `record_work`, and `for_buffer(buf, opts)` with `reader:lines`,
      `reader:text`, and `reader:line`. Tests inject `opts.delegate`; production
      instances use native Neovim and the buffer registry.
- [ ] Make observer storage strictly buffer-scoped with a phase stack.
      `with_phase` restores the prior phase after success or error and rethrows;
      tokens become invalid after `clear_buffer`. Inclusive `edit_total` uses one
      observer and counts each physical LineReader event once across nested phase
      labels; isolated runs install fresh observers after the inclusive token is
      cleared, so state cannot leak.
- [ ] Change `timezone_diagnostics.refresh_buffer(buf, opts)` and
      `skill_render.refresh_footnote_diagnostics(buf, opts)` to read through
      `opts.reader or line_reader.for_buffer(buf)`. Change
      `compute_chat_highlights`/`compute_markdown_highlights` to receive one
      reader created in decoration `on_win`. Do not narrow reads yet.
- [ ] Change `spell.suggest(opts)` to use
      `opts.reader or line_reader.for_buffer(current_buf)` and
      `reader:line(cursor_row0)` instead of `nvim_get_current_line`, so both real
      `TextChangedI` and isolated spell phases account for the one-line read.
- [ ] Rerun
      `nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/unit/line_reader_spec.lua' -c 'qa!'`,
      `nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/arch/performance_line_reader_spec.lua' -c 'qa!'`,
      `nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/integration/highlighting_spec.lua' -c 'qa!'`,
      and `make -f Makefile.parley test-spec SPEC=providers/tool_use`; expect
      all pass and behavior unchanged.
- [ ] Commit exact files as `#170: route performance-sensitive reads through LineReader`.

### Task 3: Real chat-typing scenario and baseline

**Files:**
- Create: `tests/perf/chat_typing.lua`
- Create: `tests/integration/perf_chat_typing_spec.lua`
- Modify: `Makefile.parley`
- Modify: `TOOLING.md`
- Modify: `lua/parley/highlighter.lua` (test-exposed provider driver only)
- Modify: `.gitignore` only if `.test-tmp/` is not ignored
- Modify: `workshop/issues/000170-parley-chat-performance-problem.md` (`## Log`)

- [ ] Write fixture tests for `build_chat_lines(n)`: exactly `n` lines, canonical
      header, one user marker followed by a long assistant answer spanning the
      80% cursor row, and identical 60-line local viewport shape at every size.
- [ ] Write attachment tests using a temp configured `chat_dir`,
      `parley.setup({chat_dir=tmp, chat_spell={typeahead=true}})`, `:edit` of a
      named timestamp chat, `filetype=markdown`, and `_parley_bufs[buf]=="chat"`.
- [ ] Write observer-registry tests proving phase restoration, token isolation,
      per-sample reset, and buffer teardown.
- [ ] Write failing real-input validity tests: changedtick advances, the
      harness's later-registered `TextChangedI` autocmd fires exactly once, and
      a `decoration_redraw`-phased LineReader observation proves provider work.
- [ ] Extract production `compute_window_decorations(winid,bufnr,toprow,botrow,
      reader)` in `highlighter.lua`. Installed `on_win` delegates to it inside
      `line_reader.with_phase(buf,"decoration_redraw",...)`; isolated runner
      calls the same function. Route `on_line` through the row-map's stored line
      length so it performs no parallel direct buffer read.
- [ ] Run the integration spec; expect missing scenario/observer RED.
- [ ] Pin fixture grammar exactly: lines 1–4 are `# topic: perf`,
      `- model: test`, `---`, blank; line 5 is `💬: benchmark`; line 7 is
      `🤖: [Perf]`; line 6 is blank and prose begins at line 8. Remaining rows
      are deterministic assistant prose. Generate
      prose by local offset so the same 60-row prose shape is centered on
      `floor(n*0.8)` and that row is assistant prose at every size.
- [ ] Implement fixture open/cleanup and `run_one_edit`. Drain input; set cursor;
      feed replaced termcodes for `i`; wait for insert mode; start timing; feed
      only `X` with mode `xt`; wait up to 1000ms for changedtick plus exactly one
      buffer-local later-registered `TextChangedI` while still in insert mode;
      force redraw while still in insert mode; wait for a `decoration_redraw`
      observation; then stop timing and clear the measured observer. Only during
      untimed cleanup feed `<Esc>`, wait for normal mode and synchronous
      `InsertLeave` diagnostic convergence, then reset the line. Timeout errors
      name the missing condition. Remove the observer autocmd during cleanup.
- [ ] Implement five warmups and twenty independent samples. Reset the line,
      autocmd count, and LineReader observer/counters before every sample.
      Scenario `work` is the component-wise maximum across samples; assert every
      structural count is internally consistent before summarizing.
- [ ] Implement isolated phase runners: call
      `timezone_diagnostics.refresh_buffer`,
      `skill_render.refresh_footnote_diagnostics`, a test-exposed provider
      redraw driver, and `spell.suggest` under distinct `with_phase` labels.
- [ ] Add `.PHONY`/help/target for `make perf`, reusing `PREP_TEST_ENV` and
      `TEST_ENV`; default output is `.test-tmp/perf/parley-chat-typing.json`,
      overridden by `PERF_OUTPUT`.
- [ ] Document report-only semantics, JSON path/schema, and optional manual
      MarkdownPreview comparison in `TOOLING.md`.
- [ ] Run validity tests then `make -f Makefile.parley perf`. Stop if baseline
      does not expose document-proportional reads; repair the scenario before
      production optimization.
- [ ] The exact validity command is
      `nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/integration/perf_chat_typing_spec.lua' -c 'qa!'`;
      expect PASS before running `make perf`.
- [ ] Append command, commit, OS/Neovim, medians/p95s, ratios, and work counters
      to `## Log`. Do not commit JSON.
- [ ] Compute displayed ratios in `render_table` by grouping same-phase scenarios
      by `(phase,attribution)`, ordering 100/1,000/5,000, and dividing each
      median/p95 by the 100-line value to two decimals. If the baseline statistic
      is zero, render `n/a` rather than divide. Unit-test grouping/order/precision/
      zero. JSON remains per-scenario; the durable Log copies rendered ratios.
- [ ] Commit exact files as `#170: benchmark real chat typing path`.

---

## Chunk 2: Remove synchronous document-wide work

### Task 4: Explicit diagnostic refresh lifecycle

**Files:**
- Create: `lua/parley/diagnostic_refresh.lua`
- Create: `tests/unit/diagnostic_refresh_spec.lua`
- Create: `tests/integration/diagnostic_refresh_spec.lua`
- Modify: `lua/parley/highlighter.lua`
- Modify: `lua/parley/chat_respond.lua`
- Modify: `lua/parley/skill_render.lua`
- Modify: `tests/integration/chat_respond_spec.lua`

- [ ] Write failing injected routing tests for ordered timezone/footnote refresh,
      invalid-buffer no-op, setup idempotence, and teardown. Keep this adapter
      synchronous; do not add speculative generations or timers.
- [ ] Write failing real-buffer integration cases with UTC and footnote content:
      diagnostics may be stale during `TextChangedI`, then synchronously current
      after each `InsertLeave`, `TextChanged`, `BufWritePost`, `BufEnter`, and
      `WinEnter`; unload/delete calls timezone clear plus a new source-specific
      `skill_render.clear_footnote_diagnostics(buf)` that removes only footnote
      diagnostics/highlights while preserving other shared-namespace entries.
- [ ] Add failing chat-response cases for normal completion and tool-recursive
      completion where final content contains a UTC token and diagnostics
      converge without manually firing `TextChanged`. Assert one refresh per API
      leg after that leg's last mutation. An abort/error after a buffer mutation
      refreshes before exit; an empty/error path with no mutation does not.
- [ ] Centralize terminal paths behind `finalize_mutated_api_leg(buf, mutated)`:
      normal and each recursive/tool API leg call it once after their last
      mutation; abort/error calls it iff that leg mutated; no-mutation paths call
      it zero times. Tests assert call counts and real final diagnostics.
- [ ] Run the three specs; verify the failures describe current eager insert
      refresh and absent finalization hook.
- [ ] Implement `setup(parley, group)`, synchronous `refresh(buf)`, and
      `clear(buf)`, plus source-specific footnote clear. Remove
      diagnostics from the `TextChangedI` highlighter handler; keep highlight
      redraw separate. Call `refresh(buf)` after the last successful stream
      mutation and before final control returns.
- [ ] Rerun focused specs and `make perf`; require zero diagnostic full-buffer
      reads inside `edit_total` at all sizes. Isolated convergence may scale and
      remains report-only.
- [ ] Commit exact files as `#170: move diagnostics off the insert keystroke path`.

### Task 5: Pure bounded highlight structure

**Files:**
- Create: `lua/parley/highlight_structure.lua`
- Create: `tests/unit/highlight_structure_spec.lua`
- Modify: `lua/parley/chat_parser.lua`
- Modify: `lua/parley/define.lua` (export canonical footnote predicate)
- Modify: `tests/arch/buffer_mutation_spec.lua` pure-file list or create a
  focused pure-architecture spec

- [ ] Move decoration structural classification (prefix, draft delimiter, code
      fence, tool, reasoning) from `highlighter.lua` into
      `highlight_structure.lua`; make it the canonical classifier consumed by
      both highlighter and `chat_parser.lua`. Export/inject `define`'s existing
      footnote predicate as the sole footer grammar. Delete local shadows
      (`ARCH-DRY`).
- [ ] Write failing pure tests with 0-based half-open change ranges. Require
      `fingerprint(line, patterns)` to return a compact token;
      `build(lines, patterns)` to return `{fingerprints,state_before,
      footer_start0,draft_ranges}`; `replace(s, first0, old_last0, new_lines,
      patterns)` to return `(new_structure,rows_processed)` only for a same-line-
      count, fingerprint-identical body edit, otherwise `(nil,rows_processed,
      "structural")`; and queries to return copied
      state/ranges. Cover user/assistant/local/tool/reasoning/code state,
      managed footer, multiple drafts, insert/delete shifts, body fast path,
      and structural edits whose downstream state changes to EOF.
- [ ] Pin query shapes: `state_before(s,row0)` returns
      `{in_question,in_code,in_reasoning,reasoning_explicit_end,in_tool}`;
      `footer_range(s,line_count)` returns `{start_row,end_row_exclusive}` or
      nil; `draft_blocks_in(s,first0,last0)` returns copied intersecting
      `{start_row,end_row_exclusive}` ranges. All rows are 0-based and ranges
      half-open.
- [ ] Add query-time streaming input:
      `state_before(s,row0,{streaming=true})` returns the stored state except an
      active reasoning region is overlaid with `reasoning_explicit_end=true`.
      The structure stays text-derived; provider passes
      `tasker.is_busy(buf,true)` on every query, so busy start/finalization needs
      no cache invalidation and post-stream semantics converge immediately.
- [ ] Run the new spec; expect module-not-found RED.
- [ ] Implement the named API with 0-based rows/half-open ranges. `replace`
      fingerprints only `new_lines` and reports exactly `#new_lines` processed.
      It updates in place/copy only when old/new span lengths match and every
      aligned fingerprint is identical; otherwise it returns `"structural"`
      without scanning/copying a suffix. Newline insertion/deletion, footer/
      draft/marker edits, and code/reasoning changes are structural and defer to
      a full convergence rebuild outside `TextChangedI`. No per-keystroke path
      walks to EOF.
- [ ] Test ordinary character edits process one row at 100/1,000/5,000 lines;
      structural edit at row 1, newline, footer removal, and draft-boundary edits
      each process only changed rows then return `"structural"`. Separately test
      full `build` produces correct shifted footer/drafts after convergence.
- [ ] Feed canonical cases from `tests/unit/parse_chat_spec.lua` and
      `tests/integration/highlighting_spec.lua` through the new structure and
      assert the historical state/footer/draft oracles match.
- [ ] Add pure-architecture enforcement and run unit + arch specs; expect green.
- [ ] Commit exact files as `#170: model bounded highlight structure`.

### Task 6: Buffer-owned structure cache and bounded redraw

**Files:**
- Modify: `lua/parley/highlighter.lua`
- Modify: `lua/parley/diagnostic_refresh.lua`
- Modify: `tests/integration/highlighting_spec.lua`
- Modify: `tests/arch/performance_line_reader_spec.lua`
- Modify: `tests/integration/perf_chat_typing_spec.lua`

- [ ] Write failing cases comparing matched local viewports (same row content,
      window height, structural opener count, and reasoning lookahead shape) in 1,000 and
      5,000-line buffers; assert equal `lines_requested` and zero full-buffer
      reads. Cover footer, draft, reasoning, scrolling, two windows, body edit,
      marker edit + InsertLeave, streaming growth, undo/redo, external edit +
      BufWritePost, and unload/delete late-callback no-op. Add a real-producer
      seam case through actual buffer attach → `on_lines` → provider query.
- [ ] Add real-provider reasoning cases: while `tasker.is_busy` is true, a blank
      line after an unfinished `🧠:` remains `ParleyThinking`; toggling busy false
      without a text edit immediately restores historical lookahead/terminator
      semantics on the next redraw.
- [ ] Invoke real setup/BufEnter twice and assert one full build and one effective
      `nvim_buf_attach`; two windows share it. Test `BufUnload` and `BufDelete`
      separately, then legitimate re-entry performs one new attach/build.
- [ ] Run focused specs; expect current footer/draft `all_lines` reads and
      backward bootstrap to violate counters.
- [ ] On first buffer attach only, build structure via `LineReader` before
      marking the buffer renderable; attach `on_lines`; read only
      `[firstline,new_lastline)` and call pure `replace`. Record
      `structure_rows_processed`. On `"structural"`, mark dirty in O(changed
      rows); do not recompute. Share one cache across windows and clear it plus
      LineReader registry state in unload/delete.
- [ ] Expose synchronous `highlighter.rebuild_structure(buf)` and call it from
      DiagnosticRefresh's named convergence events and stream-leg finalization
      before their callbacks return. While dirty the provider returns false;
      after rebuild it renders current structure.
- [ ] Feed chat/Markdown compute functions `structure` and `reader`. Replace
      footer/draft full scans with structure queries and bootstrap with
      `state_before`. `HighlightStructure` owns reasoning state, so provider
      lookahead performs no reads. Cache absence means not renderable and the
      provider returns false; no dirty fallback/rebuild generation exists.
- [ ] Resolve end columns while constructing the row map so `on_line` performs
      no reads. For `toprow=T`, `botrow=B`, line count `N`, assert the exact
      ordered read sequence is one call
      `lines(T,min(B+1+20,N),false)` and nothing else, totaling
      `min(B+1+20,N)-T`; require the identical sequence at both sizes.
- [ ] Run highlighting/arch/perf specs and `make perf`. Required non-timing
      assertions: `edit_total.full_buffer_reads == 0`,
      `decoration_redraw.full_buffer_reads == 0`, and 1,000-line
      `lines_requested ==` 5,000-line `lines_requested`, plus identical
      `structure_rows_processed` (one for the prose edit). Do not widen zero.
- [ ] Commit exact files as `#170: bound chat decoration work to viewport state`.

---

## Chunk 3: Evidence, documentation, and close readiness

### Task 7: Lifecycle shadow sweep and optimized report

**Files:**
- Modify: `tests/integration/diagnostic_refresh_spec.lua`
- Modify: `tests/integration/highlighting_spec.lua`
- Modify: `tests/integration/perf_chat_typing_spec.lua`
- Modify: `workshop/issues/000170-parley-chat-performance-problem.md`

- [ ] Map every oracle to its own named test—separate tests for `InsertLeave`,
      `TextChanged`, `BufWritePost`, `BufEnter`, `WinEnter`, scroll, second
      window, normal stream completion, recursive completion, abort-after-write,
      undo, redo, external edit, `BufUnload`, and `BufDelete`. Each synchronous
      event test asserts diagnostics are current before `nvim_exec_autocmds`
      returns; teardown tests assert invalid-buffer and obsolete callbacks no-op.
- [ ] Use exact test names: `keeps diagnostics stale during TextChangedI`,
      `refreshes synchronously on InsertLeave`, `... on TextChanged`, `... on
      BufWritePost`, `hydrates on BufEnter`, `hydrates on WinEnter`, `recomputes
      after scroll`, `shares structure across a second window`, `refreshes a
      normal completed API leg`, `refreshes each recursive API leg`, `refreshes
      abort after mutation`, `converges after undo`, `... after redo`, `... after
      external edit`, `clears on BufUnload`, and `clears on BufDelete`.
- [ ] Run `make perf` on the identical baseline OS/Neovim environment and append
      command, commit, OS, Neovim version, medians, p95s, scaling ratios, and
      every phase's work counters plus exact before/after comparison to `## Log`.
- [ ] Assert the immutable structural gates verbatim: diagnostic
      `full_buffer_reads==0` during `edit_total`; redraw
      `full_buffer_reads==0`; and 1,000-line `lines_requested` equals 5,000-line
      `lines_requested` separately for `edit_total` and `decoration_redraw`.
- [ ] Also assert range bounds directly: `TextChangedI` LineReader events touch
      only the current row; decoration has the exact one-call sequence
      `[T,min(B+1+20,N))`; preceding-context reads are zero (therefore ≤200);
      reasoning lookahead reads are zero (therefore ≤500/opener); managed-footer
      discovery never issues `0,-1` or an equivalent full-span call.
- [ ] Run every new spec explicitly:
      `tests/unit/perf_harness_spec.lua`, `tests/unit/line_reader_spec.lua`,
      `tests/unit/diagnostic_refresh_spec.lua`,
      `tests/unit/highlight_structure_spec.lua`,
      `tests/integration/perf_chat_typing_spec.lua`,
      `tests/integration/diagnostic_refresh_spec.lua`,
      `tests/integration/highlighting_spec.lua`,
      `tests/integration/chat_respond_spec.lua`, and
      `tests/arch/performance_line_reader_spec.lua`, each via
      `nvim -n --headless --noplugin -u tests/minimal_init.vim -c
      'PlenaryBustedFile <path>' -c 'qa!'`; expect all pass.
- [ ] Execute the command once per listed path (no wildcard/template-only
      evidence) using:

```bash
nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/unit/perf_harness_spec.lua' -c 'qa!'
nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/unit/line_reader_spec.lua' -c 'qa!'
nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/unit/diagnostic_refresh_spec.lua' -c 'qa!'
nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/unit/highlight_structure_spec.lua' -c 'qa!'
nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/integration/perf_chat_typing_spec.lua' -c 'qa!'
nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/integration/diagnostic_refresh_spec.lua' -c 'qa!'
nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/integration/highlighting_spec.lua' -c 'qa!'
nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/integration/chat_respond_spec.lua' -c 'qa!'
nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/arch/performance_line_reader_spec.lua' -c 'qa!'
```

      Paste the nine PASS results into the issue Log.
- [ ] Commit exact tests/issue as `#170: prove chat performance lifecycle bounds`.

### Task 8: Tooling, atlas, traceability, and verification

**Files:**
- Modify: `TOOLING.md`
- Modify: the relevant existing `atlas/chat/*.md` page selected by `rg`
- Modify: `atlas/index.md` only if a new page is necessary
- Modify: `atlas/traceability.yaml`
- Modify: `workshop/issues/000170-parley-chat-performance-problem.md`
- Modify: this plan

- [ ] Document `make perf`, schema/path/override, report-only timing, structural
      gates, optional MarkdownPreview comparison, diagnostic convergence, and
      bounded highlight structure. Map all new specs in traceability.
- [ ] In `atlas/traceability.yaml`, map each Done-when and every lifecycle oracle
      to the named tests from Task 7. Reverse-sweep every new #170 test and
      confirm it appears under the schema's relevant feature entry.
- [ ] Run `make -f Makefile.parley perf`, then
      `make -f Makefile.parley test JOBS=1`, then `git diff --check`. If
      user-owned dirty issue drafts make the last command red, record them and
      check `main..HEAD` plus #170 paths without editing those drafts.
- [ ] Run from repo root:
      `rg -n 'nvim_buf_get_lines|nvim_buf_get_text|vim\.fn\.getline|nvim_get_current_line' . -g '!workshop/history/**' -g '!construct/generated/**' -g '!.git/**' -g '!.test-*/**'`;
      classify every match as LineReader adapter-owned, explicitly out of scope,
      or defect. Defects must be fixed; no unexplained matches remain.
- [ ] Run from repo root:
      `rg -n 'refresh_buffer|refresh_footnote_diagnostics|diagnostic_refresh|TextChangedI|nvim_create_autocmd' . -g '!workshop/history/**' -g '!construct/generated/**' -g '!.git/**' -g '!.test-*/**'`
      and
      `rg -n 'parse_chat|exchange_model' . -g '!workshop/history/**' -g '!construct/generated/**' -g '!.git/**' -g '!.test-*/**'`.
      Classify every result; lifecycle consumers derive from
      `DiagnosticRefresh`, and no new exchange parse/model call exists
      (`ARCH-DRY`, `ARCH-PURPOSE`).
- [ ] Tick issue/plan boxes only after evidence exists. Commit docs/artifacts as
      `#170: document bounded chat performance pipeline`.
- [ ] Run `sdlc actual --issue 170`; inspect measured hours. Attempt close with
      `sdlc close --issue 170 --verified '<perf counters + focused/full suite +
      lint + diff evidence>'`, never a remembered actual. If review refuses,
      fix findings test-first, rerun focused/perf/full verification, commit the
      fixes, and rerun `sdlc close`. Only after successful finalization commit
      issue/status/sidecar changes with required `Review-Verdict:` and
      `Review-Window:` trailers.
- [ ] After successful close, stage only
      `workshop/issues/000170-parley-chat-performance-problem.md`,
      `workshop/plans/000170-parley-chat-performance-problem-plan.md`, and
      `workshop/plans/000170-parley-chat-performance-problem-close-review.md`
      (only files that exist/changed). Commit `#170: close bounded chat
      performance work` with the exact `Review-Verdict: <token>` and
      `Review-Window: <window>` printed by `sdlc close`, plus Co-Authored-By.
      Never use `git add .` or `git add -A`.
- [ ] Finish via `sdlc pr` then `sdlc merge --yes`. Verify the PR is merged,
      main contains the implementation, #170 changed `codecomplete → done`, its
      issue and durable plan/review sidecars moved to `workshop/history/`, the
      feature worktree/branch is removed, and the feature branch diff contains
      no unrelated paths.
- [ ] Resolve the main worktree with `git worktree list --porcelain` before
      merge cleanup. Before publication run `git diff --name-only
      $(git merge-base main HEAD)..HEAD`; classify every path against #170's
      plan/spec and remove any accidentally staged unrelated path. Record the
      primary checkout's current dirty paths for awareness, but do not require
      peer/user work to remain frozen while #170 proceeds.
      From main after merge run: `gh pr view <N> --json
      state,mergedAt,url`; `git merge-base --is-ancestor <implementation-head>
      main`; `rg -n '^status: done$' workshop/history/000170-*.md`; `test ! -e
      workshop/issues/000170-parley-chat-performance-problem.md`; `test -e
      workshop/history/000170-parley-chat-performance-problem.md`; `test -e
      workshop/history/000170-parley-chat-performance-problem-plan.md`; and
      `test -e workshop/history/000170-parley-chat-performance-problem-close-review.md`.
- [ ] Assert cleanup with
      `! git worktree list --porcelain | rg -q '000170-parley-chat-performance-problem'`
      and `test -z "$(git branch --list '*000170*')"`. Run `git status --short`
      from main and confirm any dirty paths are outside the merged #170 diff;
      do not edit or stage them.

## Revisions

### 2026-07-12 — initial reviewed-spec implementation plan

Reason: translate the approved #170 performance contract into executable TDD
steps with observable structural bounds and complete lifecycle oracles.

Delta: decomposed measurement, LineReader observability, diagnostic routing,
pure highlight structure, bounded provider cache, lifecycle evidence, and docs.
The issue remains single-pass atomic—no `Mx` tags—so close owns one review.

### 2026-07-12 — chunk-review execution contracts

Reason: three independent plan reviews found the observer registry, real-input
protocol, diagnostic teardown/terminal paths, incremental structure validity,
counter fixtures, lifecycle evidence, and close/publish sequence underspecified.

Delta: defined buffer-scoped tokenized observers and phase labels; exact fixture,
input, timeout, reset, aggregation, and ratio behavior; source-specific footnote
teardown; synchronous diagnostic routing without speculative generations;
fingerprint-splice/downstream recomputation semantics; always-valid cache rules
with no guessed redraw fallback; matched structural read sequences; exhaustive
named tests/searches; immutable counter assertions; and resumable SDLC gates.

### 2026-07-12 — second chunk-review precision pass

Reason: revised reviews found remaining scheduler ambiguity, adapter counting
semantics, cache-absence complexity, suffix convergence/read-call oracles, and
post-close verification insufficiently literal.

Delta: split insert entry/character/event/escape/redraw waits; fixed LineReader
index/count/event contracts and observer stack semantics; extracted the single
production provider compute seam; pinned fixture grammar and ratio edge cases;
removed absent-cache rebuilds; specified structural query shapes and aligned
suffix equation; reduced redraw to one exact read; named every lifecycle test
and bound; expanded whole-tree shadow searches; and made close staging and
post-merge/archive/worktree commands explicit.

### 2026-07-12 — final edge-contract pass

Reason: final reviews found spell reads, fixture line six, streaming reasoning,
metadata splice locality, whole-repo shadows, and cleanup assertions omitted.

Delta: routed spell through LineReader; pinned canonical blank/prose placement
and literal commands; made streaming a query-time pure state overlay; specified
preserve/intersect/shift metadata rules; expanded searches to the repo root with
deliberate exclusions; and added exact archive, branch/worktree absence, and
dirty-draft snapshot comparisons.

### 2026-07-12 — edit interval correction

Reason: approval audit caught `InsertLeave` diagnostic convergence inside the
measured keystroke interval, contradicting the zero diagnostic-read gate.

Delta: `edit_total` now ends after `TextChangedI` and forced in-insert redraw;
escape, synchronous convergence, and fixture reset occur after counters/timing
stop.

### 2026-07-12 — code-entry judge correction

Reason: `sdlc change-code` found suffix-to-EOF recomputation could hide
document-proportional CPU work behind clean line-read counters, and judged the
4.13h estimate too small for the full eight-task surface.

Delta: added `structure_rows_processed`; prose edits remain locally valid while
structural edits only mark dirty during insertion and rebuild on named
non-keystroke events. `highlight_structure` now owns canonical decoration
classification consumed by highlighter/chat parser, with `define` owning the
footnote predicate. Estimate re-derived to 7.94h. Cleanup checks now scope the
feature diff generically instead of freezing unrelated drafts.
