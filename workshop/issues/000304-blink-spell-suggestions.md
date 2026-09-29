---
id: 000304
status: working
deps: []
github_issue:
created: 2026-09-29
updated: 2026-09-29
estimate_hours: 3.4
card_mirror: '92f58e3fdda90c74f91524aa2c40bd848c99e2aa' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-09-29T14:30:37-07:00
flow: {kind: full, provenance: operator}
---

# Unify automatic spell suggestions in Blink

## Problem

The native `z=` spelling interface feels awkward in parley_app. Buffer-word completion already uses Blink in the app, while the main plugin has a separate optional spell typeahead popup. Users need one consistent correction interface in both distributions, including when revisiting an existing misspelling.

## Spec

- Provide Blink-based spell typeahead in the main Parley plugin, not only in the packaged app. The app consumes the same spelling integration and must work out of the box.
- Automatically show the Blink spelling menu when the cursor is on a misspelled word in either Normal or Insert mode. This includes moving onto an existing word, entering either mode on it, and creating a misspelling while typing; it must not require `z=` first.
- Offer corrections for the whole word under the cursor, including a cursor in the middle of a word. Accepting a suggestion replaces that word without stranding its suffix or changing surrounding text; do not silently autocorrect.
- Use the established menu controls: Tab/Down select next, Up selects previous, Enter accepts, Esc dismisses. With no menu, keys retain native behavior. Showing or dismissing corrections must not unexpectedly switch editing modes.
- Coexist with buffer-word completion and Parley shortcuts through one menu owner. Integrate or retire the old spell popup/mapping path rather than running two competing menus.
- Avoid a menu that immediately reopens after Esc on the same unchanged word. Moving to another word, changing the word or explicitly requesting suggestions may re-enable it. Correct words, whitespace and punctuation should not open a correction menu.
- Keep spell language and existing spell settings meaningful. Popup behavior should be configurable independently of visible spell underlines; plugin users need documented Blink setup and graceful behavior if Blink is unavailable.

Related work: #259 covers compact spell/buffer completion and historical typing thresholds; #288 covers plugin Blink sources, including neighborhood paths and spelling. This ticket records the explicit plugin-plus-app and automatic Normal/Insert cursor-trigger requirements. Coordinate overlapping spelling work when implementing; neighborhood-path completion remains #288's scope. A typing threshold must not prevent correcting a short existing misspelling merely by placing the cursor on it.

Implementation questions to resolve during design: verify the pinned Blink version's Normal-mode capabilities and required adapter; define event/debounce and dismissal state so cursor movement remains responsive. ARCH-DRY: shared plugin spelling integration and a single completion UI owner. Do not assume enabling the legacy `chat_spell.typeahead` alone meets this contract.

## Done when

- In both the main plugin and parley_app, misspelling a word while typing produces Blink spelling suggestions.
- In both Normal and Insert modes, moving onto an existing misspelled word automatically opens the correction menu, including short words and mid-word cursor positions.
- Keyboard selection, acceptance and dismissal work consistently; correction replaces exactly one whole word, supports undo, and preserves the surrounding text and appropriate editing mode.
- Correct words and non-word positions do not trigger corrections; Esc dismisses without an immediate reopen loop or unintended mode switch.
- Existing buffer-word completion, app pairing, send shortcuts and no-menu native keys continue to work; no competing legacy popup or Enter mapping remains active.
- Tests exercise actual Blink in plugin and app configurations, typing and cursor-motion triggers in both modes, whole-word edits, stale results after cursor changes, dismissal/retrigger behavior and graceful absence of Blink. README and atlas document setup and controls.

## Plan

- [x] Reconcile overlapping spelling scope with #259/#288 and design shared Blink sources, Normal-mode presentation, triggers and dismissal lifecycle.
- [x] Implement the shared plugin integration and app wiring with regression coverage.
- [x] Verify real keyboard behavior in both distributions and document the resulting interface.

## Log

### 2026-09-29

User requested a ticket only, not implementation. Explicit priorities: use Blink for spell typeahead in main Parley, ensure it works in parley_app, and automatically pop the Blink spelling menu over a misspelled word in Normal or Insert mode. Current spell underlines are enabled; legacy spell typeahead is disabled and owns a separate popup/Enter mapping when enabled. The app already has Blink buffer completion and the requested selection/acceptance/dismissal keys.


### 2026-09-29 — Implementation authorized; restart checkpoint

User subsequently said “ok, go work on it” and “continue?”; implementation is authorized. Claimed #304 and ran `sdlc start-plan --issue 304` in `/private/tmp/parley-304-worktree`, branch `000304-blink-spell-suggestions`, based on origin/main `63390569`. No production code or tests have been changed; no durable implementation plan has been written and `sdlc change-code` has NOT run. Next: write `workshop/plans/000304-blink-spell-suggestions-plan.md` with the writing-plans skill, checkpoint it, pass change-code, then implement/test. Do not reclaim an already-working issue. Latest SDLC state was refreshed successfully with escalation after sandbox blocked FETCH_HEAD.

**Baseline:** `make test-spec SPEC=ui/keybindings` in this worktree finished exit 2. Runtime tests passed; sole failure was `tests/arch/single_source_sweeps_spec.lua:356`: no Core-concepts row selected. This is missing planning metadata, not a runtime regression. A durable plan must list actual module/export names in its Core concepts tables (Status column). Log: `/tmp/parley-304-baseline.log`. No test process remains. Never run concurrent make-test invocations in one checkout: orphan census can kill peers.

**Real Blink feasibility:** installed app dependency at `/Users/xianxu/workspace/parley.nvim/demo/workspace/data/parley/lazy/blink.cmp`, pinned commit `78336bc89ee5365633bcf754d93df01678b5c08f` (1.10.2). Lua fuzzy implementation needs no native download. Public `cmp.show({providers={id}})` opens the actual menu in Normal mode. Default acceptance fails E785 because its dot-repeat implementation calls native complete(), which requires Insert mode. Do NOT globally disable dot_repeat in the user's Blink config. A custom provider `execute(ctx,item,callback,default_implementation)` solves this: in Normal establish an undo boundary, apply the explicit full-word text edit directly, leave cursor on last replacement character; in Insert call default_implementation; call callback exactly once on either path, including stale rejection. Probe demonstrated replacement of “before teh after” with “before the after”, Normal/Insert mode preservation and single undo restoring the typo. Probe source is embedded below for reproducibility; temporary original `/tmp/blink-spell-probe-execute.lua` is not durable.

**API findings and critical acceptance race:** non-LSP items use UTF-8 byte textEdit offsets by default; no offsetEncoding property needed (`lib/text_edits.lua:189`). Set filterText to the misspelled query so fuzzy matching does not discard valid corrections. Blink changes textEdit.end BEFORE calling custom execute by the cursor movement since the item was generated (`text_edits.lua:160–166`). Keep the original range, cursor, buffer identity, word, changedtick and generation in item data; reject stale acceptance or reconstruct intended range. Menu/list close occurs BEFORE asynchronous resolve/execute; acceptance evidence cannot live only in visible-menu state. Public User BlinkCmpShow/Hide events include event.data.context; Hide retains previous context even when cmp.get_context() is nil. BlinkCmpMenuOpen/Close carry no items/context; use get_items to identify source ownership. add_source_provider asserts duplicate IDs; add_filetype_source appends without clearing existing config. Register once, preserve user source configuration.

**Readiness:** no public ready API and no BlinkCmpReady event. Merely requiring Blink or inspecting fuzzy.implementation_type does not prove setup (it defaults to lua on require). Candidate narrow internal compatibility probe: inspect package.loaded['blink.cmp.completion.trigger'] and its buffer_events field without requiring internals; this field is assigned in trigger.activate during setup. Check from scheduled callbacks after setup's synchronous tail; retry existing BufEnter/InsertEnter/CursorMoved events. Isolate/document this version-dependent seam and cover delayed setup. Never invoke setup implicitly in plugin users' config.

**Integration map:**
- `lua/parley/spell.lua`: existing pure word_at_cursor returns only a word ending before insertion and rejects mid-word edits; preserve legacy semantics and add a separate full-word target abstraction. Existing attach only enables legacy native popup when typeahead=true; it does not clean up prior maps/autocmds on disabling. Fix backend reattachment lifecycle. spelllang must work with underlines off.
- `lua/parley/init.lua` prep_chat around 2688 gates attach on enable/typeahead. Update for new Blink option. spell.attach runs before final registry maps, so capture effective original maps when a menu opens, not during early attach. Interview CR callback and prompt-buffer behavior must survive.
- `lua/parley/config.lua` chat_spell currently enable=true, typeahead=false, min_word=4, max_suggest=9. Leaning: new blink=true default when dependency is ready, keep typeahead=false legacy opt-in, independently configurable popup/underlines. Short existing typo “teh” must trigger. Defaults, debounce and typing threshold remain design decisions, not accepted implementation.
- `lua/parley/neighborhood.lua` attach_cmp_completion owns nvim-cmp path source, retries scheduled BufEnter/InsertEnter. Avoid competing native/nvim-cmp UI while Blink owns chat completion; neighborhood-path migration itself remains #288 scope. Both-enabled configurations require an explicit ownership choice and tests.
- App starter already eagerly configures real Blink, Lua matcher, buffer source current-buffer only, no preselect/auto-insert; Tab/Down next, Up previous, Enter select-and-accept, Esc hide/fallback. Main plugin must consume same spelling controller, no app-only implementation.
- `lua/parley/keybinding_registry.lua` feature_gated currently lists only CR. Add transient spelling menu keys with gate metadata. Normal app Up/Down globally map gj/gk. Lease buffer-local maps only while owned menu is visible; restore original buffer mapping (including callback/string/expr properties), or remove local map to expose global map. Never overwrite a user replacement made while menu was active.
- Tests: existing `tests/unit/spell_spec.lua`, `tests/integration/spell_chat_spec.lua`, keybinding agreement/unit specs; actual dependency harness `tests/packaging/completion_compatibility.lua`. Add shared plugin + app real Blink scenarios, not just fake assertions. Packaging harness uses fake dependency installer, real pinned Blink. Launch with `nvim --headless -u NONE -i NONE -c 'luafile ...'` rather than -l. Update spec traceability YAML and atlas/index links.

**Design still needed (ARCH-ORDER/PURE/DRY):** explicit pure state transition owner (idle/pending/open/dismissed, events for target/mode changes, timer completion, dismissal, menu close, detach). One cancellable debounce timer per buffer; reject old generations/results, bounded suggestion count, no full-buffer scanning per keystroke. Restore leased maps and cancel timers on BufLeave/Wipeout, unsupported modes, reattach and disable. Esc suppresses same unchanged target until moving/changing/manual request; no silent autocorrect. Preserve buffer completion in same Blink menu; avoid suppressing user's providers. Unicode letters/apostrophes, byte offsets after multibyte prefixes, punctuation/no-word positions need deliberate target extraction and tests. Test full-word replacement mid-word, undo, short typo, typing and motion triggers in both modes, delayed Blink setup/absence, stale accept, dismissal/retrigger, custom maps, buffer switches, user-remapped keys, correct words and no-menu native behavior. Establish operating budget (e.g. debounce 150–200ms) as a design choice, not a measured claim.

**Other session state:** #300–303 were already merged (PR #215), archived, and their branches removed. Ariadne #272 captures stacked-development friction; no further peer work is needed for #304. User's separately staged demo changes (REHEARSAL, cut.py, viewer.html) were committed on main at `8f0e7a48` on explicit request, no push performed. Do not mix that work into #304. Root main was clean after commit; recheck on resume. User now requested saving work before restarting; stop after checkpoint.

#### Reproducible feasibility probe (not production code)

Run the following Lua with the installed pinned Blink on runtimepath, once normally and once with PROBE_INSERT=1. It prints SHOWN / ACCEPTED / SETTLED / UNDONE. This deliberately uses a fixed range and does not solve stale-target validation; production must do so.

```lua
vim.opt.rtp:prepend('/Users/xianxu/workspace/parley.nvim/demo/workspace/data/parley/lazy/blink.cmp')
local cmp = require('blink.cmp')
local nofilter = vim.env.PROBE_NOFILTER == '1'
package.preload.probe_source = function()
  return { new = function() return {execute = function(_, ctx, item, callback, default_implementation)
    if vim.api.nvim_get_mode().mode == 'n' then
      vim.o.undolevels = vim.o.undolevels
      vim.lsp.util.apply_text_edits({item.textEdit}, ctx.bufnr, 'utf-8')
      vim.api.nvim_win_set_cursor(0, {1, item.textEdit.range.start.character + #item.textEdit.newText - 1})
    else default_implementation() end
    callback()
  end, get_completions = function(_, ctx, cb)
    local items = {}
    for _, label in ipairs({'the', 'ten', 'tea'}) do
      items[#items+1] = {label = label, filterText = not nofilter and 'teh' or nil, kind = 1, textEdit = {newText = label, range = {start = {line = 0, character = 7}, ['end'] = {line = 0, character = 10}}}}
    end
    cb({items = items, is_incomplete_forward = false, is_incomplete_backward = false})
  end} end }
end
cmp.setup({fuzzy = {implementation = 'lua'}, sources = {default = {}}, keymap = {preset = 'none'}, completion = {list = {selection = {preselect = true, auto_insert = false}}}})
cmp.add_source_provider('probe', {name = 'Spelling', module = 'probe_source'})
vim.api.nvim_buf_set_lines(0, 0, -1, false, {'before teh after'})
vim.api.nvim_win_set_cursor(0, {1, tonumber(vim.env.PROBE_COL or '8')})
vim.o.undolevels = vim.o.undolevels
local function out(label) print(label .. ' ' .. vim.inspect({mode = vim.api.nvim_get_mode().mode, visible = cmp.is_menu_visible(), text = vim.api.nvim_get_current_line(), cursor = vim.api.nvim_win_get_cursor(0), items = vim.tbl_map(function(v) return v.label end, require('blink.cmp.completion.list').items)})) end
if vim.env.PROBE_INSERT == '1' then vim.cmd('startinsert') end
vim.defer_fn(function()
 cmp.show({providers = {'probe'}})
 vim.defer_fn(function()
  out('SHOWN')
  cmp.accept({index = 1, callback = function()
   out('ACCEPTED')
   vim.defer_fn(function()
    out('SETTLED')
    if vim.api.nvim_get_mode().mode == 'i' then vim.cmd('stopinsert') end
    vim.cmd('undo')
    out('UNDONE')
    vim.cmd('qa!')
   end, 100)
  end})
 end, 150)
end, 100)
vim.defer_fn(function() out('TIMEOUT'); vim.cmd('qa!') end, 2000)
```


### 2026-09-29 — Continuation resumed; durable plan reviewed

Read workshop/continuation/20260929T150434-parley-blink-spell.md and recovered sdlc state in the existing issue worktree; did not reclaim or repeat feasibility work. Durable plan: [Blink spell suggestions](../plans/000304-blink-spell-suggestions-plan.md). Defaults proposed: Blink enabled when ready, 180 ms debounce, bounded suggestions, no Blink minimum word length, legacy opt-in retained as fallback. Shared reducer/controller/source own both distributions. ARCH-ORDER review corrected synchronous acceptance invalidation before deferred observations, native Blink source admission through reducer tickets, and Normal TextChanged handling. A second fresh-context plan review approved with no remaining blocking findings. Pinned public select_next/select_prev supports auto_insert=false; global Blink options remain untouched.

The plan is ready for operator approval under AGENTS.md §2. Existing implementation authorization is recorded above, but this new non-trivial durable design has not yet been presented/approved. No production edits, change-code gate, estimate or runtime tests in this resumed turn. After design approval, run sdlc change-code --issue 304, satisfy its plan-quality/estimate requirements, then execute the plan with red/green tests. Unrelated root-main commit and untracked continuation remain untouched.


### 2026-09-29 — Full-flow plan gate cleared

User approved execution with “continue”. Full-flow plan-quality passed round 2 after PQ-1 (refresh-time preview policy) and PQ-2 (function-level testing strategies) were addressed. The selection-mode compatibility adapter delegates foreign contexts and preserves Blink configuration. Next: complete estimate gate, then TDD implementation.

## Estimate

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against `baseline-v3.1.md`. Method A only. Shared grammar/vocabulary: sdlc's `cmd/sdlc/helptext/estimate.md`; calibration discovered through `sdlc estimate-source` (marked stale, so provisional). Read v3.1 and its v2.1/v2 procedure chain.

Decomposition: one TUI state machine (state/target), two focused Lua/Neovim integrations (Blink controller/source with stateful fake; backend/keymap/app wiring and keyboard conformance), documentation, one boundary review, and one pinned-library API discovery allowance. Pick primitive-table midpoints; design ×0.2 for the settled plan, implementation ×0.4 per v3.1. Familiarity ×1.5 reflects novel-but-bounded Blink Normal-mode integration. Native spell APIs and the existing Blink library supply dictionary lookup, fuzzy UI and Insert acceptance; no greenfield stack primitive or replacement UI is budgeted. The design buffer is 15% for this concrete plan.

```estimate
model: estimate-logic-v3.1
familiarity: 1.5
item: tui-screen design=0.25 impl=0.26
item: lua-neovim design=0.4 impl=0.4
item: lua-neovim design=0.4 impl=0.4
item: atlas-docs design=0.025 impl=0.05
item: milestone-review design=0.02 impl=0.14
item: real-api-discovery design=0 impl=0.18
design-buffer: 0.15
total: 3.4
```

Design subtotal 1.095 × 1.15 = 1.25925; implementation 1.43 × 1.5 = 2.145; total 3.40425, rounded 3.4 focused ship-hours. This is an estimate, not a replacement for measured close actuals.


### 2026-09-29 — Shared Blink implementation and verification

Implemented pure spell_state targets/admission/acceptance, shared spell_blink controller and spell_source provider, backend teardown, independent defaults, scoped key leases and Parley cmp ownership. Plugin and app use the same path. Native spelling uses buffer spelllang even without underlines. Late filetype setup now registers on FileType; automatic mixed-provider requests only run for actual misspellings, preventing a correctly spelled accepted word from reopening a menu and stealing Return. Source evidence survives hide-before-resolve and rejects stale/duplicate acceptance.

TDD evidence: pure state RED missing module → green; source RED absent/denied/correct-word cases → 11 green; legacy reattach RED stale mapping/options → 25 green; controller/default and cmp ownership RED → green. Final mapped spell suite passed, as did ui/keybindings and infra/starter. Real pinned Blink script passed both plugin/app scenarios and the pre-existing 35-step completion/pairing harness. English native suggestion sample n=30 per profile: plugin median25.58ms/p9528.30ms; app median25.96ms/p9527.91ms. Results are measured samples, not universal latency guarantees. make lint passes after removing an unused generated-test loop variable; git diff --check clean. Logs /tmp/parley-304-{spell-final,keybindings-final,starter,real,lint-final}.log are supplementary; this paragraph is durable evidence.

ARCH-ORDER: synchronous invalidation, reducer-issued source tickets and menu-independent acceptance evidence guard deferred work. ARCH-DRY: one provider/controller serves both distributions; is_misspelled is shared by automatic-show and provider admission. ARCH-FUNERAL: debounce timers, map leases and compatibility wrappers are collected on detach/wipeout. The key guard now distinguishes chat-scoped transient Tab from unrelated picker defaults. README and atlas document setup, controls, fallback, byte/line bounds and pinned compatibility seams.

Estimate-quality INFO was advisory: the v3.1 figure is idle-excluded ship wall-clock including subagent execution; integration primitives include fake and real keyboard verification, while the API-discovery line is solely residual compatibility investigation. No hand-entered actuals. All implementation stays on #304's worktree; root-main demo changes and the untracked continuation are untouched. Next: mandatory close review, then publish through SDLC.


### 2026-09-29 — BR-1 fixed, ready for re-review

Boundary review REWORK identified acceptance-context-invalidation: same-buffer/same-position window excursions bypassed buffer/cursor events. Reproduced twice: controller tests failed with the old menu still visible on WinLeave; real pinned Blink applied a delayed correction after leaving and returning. Added WinLeave synchronous reducer invalidation and WinEnter deferred observation. Departure, staying in another window, and return-before-resolution are covered; the controller checks menu/map release and fresh target ownership, and the real provider checks stale edit rejection in both distributions.

Verification: mapped spelling suite passes 77 tests; real plugin/app spelling and existing 35-step completion/pairing harness pass; touched-file lint and git diff --check pass. New logs /tmp/parley-304-window-{red,green,real-red,real-green}.log. Lesson and plan revision record the event-family fix (ARCH-ORDER). No other review findings.

Publication safety: the legacy ordinary-worktree merge implementation pulls/pushes the main checkout, which would risk publishing unrelated local demo commit 8f0e7a48. Use sdlc pr here, then the supported durable primary-workspace landing path from an independent clean clone of the remote. Leave the original primary checkout and continuation/worktree intact.
