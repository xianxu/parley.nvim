# Streaming scroll stability (#253)

## Core concepts

| Entity | Lives in | Kind | Status |
|---|---|---|---|
| Stream endpoint | lua/parley/dispatcher.lua create_handler | PURE derived data | modified |
| `cursor_to_line` | lua/parley/helper.lua | INTEGRATION | modified: optional byte column |
| `from_query` | lua/parley/stream_position.lua | PURE | new: shared query position |

## Integration points

| Entity | Lives in | Kind | Status | Wraps |
|---|---|---|---|---|
| Fold-maintenance view | lua/parley/tool_folds.lua clear_folds_in_span | INTEGRATION | modified | actual Neovim per-window view |
| Cursor placement | lua/parley/helper.lua cursor_to_line | INTEGRATION | modified | Neovim cursor API |
| Completion placement | lua/parley/chat_respond.lua completion callback | INTEGRATION | modified | stream tip position |
| Attached UI regression | tests/integration/stream_view_spec.lua | INTEGRATION | new | isolated child Neovim RPC/UI |

Root causes have attached-UI evidence. No new exported function is needed: extend existing cursor_to_line with optional column argument (default0 preserves nonstream callers); it still honors current-buffer/window guards and clamps through Neovim. Per-chunk endpoint is last-written row plus final pending line’s byte length including prefix. Completion uses the final recorded pending line endpoint, not a different generic line-start rule. Exact approach will reuse qt.last_line and add/derive last_col where needed so no repeated full-buffer scan (ARCH-DRY/CONSTRAINTS).

Fold clear saves winsaveview and restores complete state after its internal cursor excursion. Scope is the maintenance operation, never the entire with_exchange_update callback: restoring an older snapshot around mutate would undo intentional follow or edits. Use xpcall/finally restoration for exceptions, restore original foldenable in VimL try/finally, preserve errors. Maintain existing clear-iteration bound and linear-in-fold-count behavior. No new per-session state/timers/autocmds (ARCH-ORDER/FUNERAL); no blanket wheel remap or change to follow preference.

## Execution and tests

1. Add attached UI tests with vim.fn.jobstart({vim.v.progpath,'--embed','--headless','-u','NONE','-i','NONE'}, {rpc=true}) then nvim_ui_attach. Child inherits hermetic test HOME/XDG/TMPDIR and PARLEY_TEST_MODE; no provider credentials/network, stop child on success/failure. Use actual fold module/model, dispatcher, helper, and native nvim_input_mouse. Separate real UI state from assertions returned by RPC. New test routes under chat/exchange_model; no reusable production helper introduced solely for tests.
2. RED cases: zero-fold long exchange and thinking-fold exchange with distinct views in two splits; maintenance preserves all saved view fields where unchanged line geometry allows it. Stream mutation deliberately moves target cursor to tip while other split stays stable. An exception in mutate must still preserve view through reconcile. Test wrapped long line with smoothscroll true: wheel down, then real handler chunk with follow enabled targets last generated character, not col0; follow false preserves manual cursor/skipcol. Include prefix, multibyte last character and newline/empty pending line in endpoint cases.
3. Patch clear_folds_in_span narrowly and helper optional column; dispatcher records final byte endpoint and passes it to helper. Align completion placement for actual streamed line while preserving existing fallback behavior for no streamed output. Locate completion data owner before modifying it; test actual completion path via existing chat_respond integration seam, avoiding a parallel endpoint computation.
4. Update atlas/chat/exchange_model.md view contract and atlas/chat/lifecycle.md follow-tip behavior; map changed code and new spec. Run make test-spec SPEC=chat/exchange_model and new UI spec; make lint, then full make test once. Exercise real starter configuration in isolated profile with UI and synthetic stream callback, no post-startup setup reset and no live provider request.
5. Record reproductions/evidence and user mode clarification if received. Commit, fresh sdlc close review, address findings and publish PR; no release or merge unless requested.

ARCH-PURE: endpoint derives from existing pending text; window mutation stays in integration owners. ARCH-MOCK: the real local Neovim process supplies redraw behavior; no service added and no function-call mock substitutes for the reported interaction. ARCH-SECURE: child environment uses isolated test roots and no real authentication. ARCH-PURPOSE: regression tests assert visible viewport coordinates and tip, not just cursor row.


## Revisions

### 2026-09-14 — Named contracts and UI observation barriers

Reason: plan review requested function-level strategy and deterministic redraw synchronization. Delta:

| Function | Verification strategy |
|---|---|
| `clear_folds_in_span` (tool_folds.lua, INTEGRATION) | Actual attached UI via public with_exchange_update exercises clear twice. Assert complete per-split winsaveview equality for text/thinking/wrapped skipcol, preserved explicit movement inside mutate, restored view and propagated error after mutate failure. Existing iteration-bound tests remain. |
| `cursor_to_line` (helper.lua, INTEGRATION) | Existing default column0 retained; explicit byte column targets prefix/multibyte endpoint and empty line, respects current-buffer/invalid-window guard; assert actual cursor with native clamping, not mocked calls. |
| `D.create_handler` (dispatcher.lua, INTEGRATION) | Real scheduled handler with actual tasker query records qt.last_col from pending bytes; wheel-scroll a wrapped pending line then append, assert visible cursor at final character when follow true, unchanged view when false; newline/prefix/multibyte endpoints and toggle callback covered. |
| `query_cursor_line` (chat_respond.lua, PURE existing) / completion callback (INTEGRATION) | Keep row projection unchanged; completion consumes qt.last_col only when using a streamed row. Existing fake transport invokes real handler then completion; assert post-completion cursor remains at long-line tip, fallback without endpoint retains previous row behavior. |

Attached UI helper is local to stream_view_spec.lua: reuse one child per case, attach100x30 with `{rgb=true}`, redraw before snapshots, stop and reap in after_each. Direct maintenance calls are synchronous RPC; execute `vim.cmd('redraw')` before returning winsaveview, so assertions observe processed UI layout (confirmed stock fails5cases and temporary patch passes5). For queued input/stream calls, parent polls an RPC snapshot up to1000ms at10ms intervals: wheel barrier requires skipcol/cursor to differ in expected direction; chunk barrier requires exact expected pending buffer text and qt endpoint. After observable completion, a separate synchronous redraw RPC precedes view snapshot. Timeout includes last observed text/endpoint/view and fails; no fixed sleep is success evidence. Chat completion waits on recorded callback completion then actual post-callback redraw. These barriers prevent assertions racing queued input or scheduled handlers.

Completion's established owner is query_cursor_line(qt) near chat_respond.lua:269 and callback near2028/2150. Capture qt.last_col beside streamed_cursor_line before final cleanup and pass it only for the streamed-row case; existing helper guards/clamping remain. No second endpoint scan or production module added. Test-only local helpers/child globals are contained by process lifetime.


### 2026-09-14 — One pure query-position projection

Reason: PQ-1 requires a directly unit-tested pure endpoint owner; runtime and completion currently project the query separately. Delta supersedes the earlier no-new-exported-function constraint and the Execution step2 RED-case enumeration as the test strategy (individual cases live in specs). Add `stream_position.from_query(qt)` in `lua/parley/stream_position.lua` (PURE, new), with `tests/unit/stream_position_spec.lua`: normalize tasker’s zero-based last_line/byte last_col into a Neovim one-based row/zero-based column pair, prefer last_line, retain first_line fallback and0column for older queries, return nil when no valid row exists. Direct unit strategy covers last-row precedence, absent/legacy query fallback and byte-column preservation without IO. This replaces local query_cursor_line and is reused by create_handler and completion, so the extra module removes duplicate projection instead of wrapping string length for its own sake (ARCH-DRY/PURE).

`D.create_handler` records last_col from already-known pending bytes and prefix, then calls the shared projection; completion captures its pair before cleanup and passes that same position to cursor_to_line. Tests for helper/handler/maintenance/completion use the named integration strategies above. Add projection source/unit spec to chat/exchange_model traceability.

Operator observation: scrolling consistently stops when generation passes the visible bottom. The attached-UI handler strategy must begin with output fitting within the viewport, append until the visible-bottom threshold is crossed, then exercise native wheel down and next chunk. Also retain split/wrapped/error-path maintenance strategies; no extra global scroll policy is inferred from this observation.

### 2026-09-14 — Exception cleanup implementation

Reason: use one cleanup owner for the fold walk. Delta: Lua pcall around nvim_exec2 followed by foldenable and winrestview restoration replaces the proposed VimL try/finally; an injected walk error proves both states restore before rethrow. No view restoration surrounds the stream mutation itself.

### 2026-09-14 — Concrete symbol inventory

Reason: branch architecture check matches symbol names rather than descriptive labels. Delta: name the modified/new public functions explicitly.

## Core concepts (implementation symbols)

| Entity | Lives in | Kind | Status |
|---|---|---|---|
| `cursor_to_line` | lua/parley/helper.lua | INTEGRATION | modified: optional byte column |
| `from_query` | lua/parley/stream_position.lua | PURE | new: shared query position |
