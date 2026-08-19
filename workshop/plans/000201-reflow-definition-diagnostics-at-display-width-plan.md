# Display-Width Diagnostic Reflow Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep Parley diagnostic payloads width-independent and reflow definition floats and review virtual lines to the width of their actual display surface.

**Architecture:** `define.lua` canonicalizes generated definitions into one persisted paragraph, while a focused `diagnostic_text.lua` pure module converts semantic messages into display-cell-bounded rows. `skill_render.lua` publishes canonical diagnostic messages without presentation newlines. `diag_display.lua` is the thin UI shell: it measures visible windows/float geometry, injects Neovim's display-width function into the pure wrapper, and rerenders through one global lifecycle after width-changing window events. No external-service behavior changes.

**Tech Stack:** Lua, Neovim diagnostic/extmark/float APIs, Plenary/Busted tests, luacheck.

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| Definition canonicalizer | `lua/parley/define.lua` | modified |
| Diagnostic row wrapper | `lua/parley/diagnostic_text.lua` | new |

- **Definition canonicalizer** — converts model output into one stable Markdown-footnote paragraph by trimming and collapsing every whitespace run to one ASCII space.
  - **Relationships:** N:1 from fresh tool output and rehydrated footer text to the canonical definition string used by both storage and diagnostics.
  - **DRY rationale:** `format_footnote_line`, `format_definition`, and `apply_definition_footnote` currently normalize independently; one function prevents stored and displayed definitions from diverging (`ARCH-DRY`).
  - **Future extensions:** Definition-specific escaping or length policy belongs at this boundary, not in renderers.
- **Diagnostic row wrapper** — transforms semantic text plus an effective display-cell width and injected measurement function into width-bounded rows, preserving explicit newline rows while normalizing horizontal display whitespace.
  - **Relationships:** 1:N from one diagnostic payload to rendered rows; both inline virtual lines and definition floats consume it.
  - **DRY rationale:** It is the sole wrapping algorithm for both display surfaces (`ARCH-DRY`, `ARCH-PURE`).
  - **Future extensions:** Hyphenation or alternative break policy widens this pure API without changing diagnostic storage.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| Diagnostic publication | `lua/parley/skill_render.lua` | modified | Neovim diagnostic state |
| Diagnostic display controller | `lua/parley/skills/review/diag_display.lua` | modified | Neovim windows, extmarks, floats, and autocmds |

- **Diagnostic publication** — publishes canonical definition/review messages without width-dependent newlines.
  - **Injected into:** The diagnostic row wrapper is not called here; renderers consume published messages later.
  - **Future extensions:** Other diagnostic consumers automatically receive semantic payloads.
- **Diagnostic display controller** — measures the narrowest usable text width for buffer-scoped virtual lines and the actual float content width, renders rows, and refreshes on cursor/window events.
  - **Injected into:** It supplies `vim.fn.strdisplaywidth` to the pure wrapper and owns all UI side effects (`ARCH-PURE`).
  - **Future extensions:** A per-window decoration provider could replace narrowest-window sharing if Neovim gains a simpler window-local virtual-line seam.

`ARCH-PURPOSE`: the plan covers the custom inline renderer, centered definition float, persisted footnote, and Neovim built-in diagnostic float. `ARCH-MOCK`: there is no new external dependency; the existing definition provider fake is unchanged.

## Chunk 1: Canonical payloads and shared wrapping

### Task 1: Canonicalize fresh and rehydrated definitions once

**Files:**
- Modify: `lua/parley/define.lua`
- Test: `tests/unit/define_spec.lua`
- Test: `tests/integration/define_spec.lua`

- [ ] **Step 1: Write the failing direct canonicalizer test**

Add:

```lua
it("canonicalizes definition whitespace into one paragraph", function()
    assert.equals("alpha beta gamma", define.normalize_definition("  alpha\n\n beta\t gamma  "))
    assert.equals("(no definition)", define.normalize_definition(" \n\t "))
end)
```

- [ ] **Step 2: Run the unit spec and verify RED**

Run:

```bash
nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/define_spec.lua" -c "qa!"
```

Expected: FAIL with `attempt to call field 'normalize_definition' (a nil value)`.

- [ ] **Step 3: Implement the canonicalizer and verify the direct test GREEN**

Add the public pure helper:

```lua
function M.normalize_definition(definition)
    local normalized = tostring(definition or ""):gsub("%s+", " ")
    normalized = normalized:gsub("^%s+", ""):gsub("%s+$", "")
    return normalized ~= "" and normalized or "(no definition)"
end
```

Run the Step 2 command. Expected: the new direct case PASS (older width-based cases may still fail until Step 6).

- [ ] **Step 4: Replace stale formatter tests and write failing fresh/rehydrated tests**

Replace the existing `format_definition` hard-wrap/delegation cases with assertions that the returned message is canonical unwrapped semantic text regardless of an obsolete extra width argument. Add one `apply_definition_footnote` case whose definition is `" alpha\n beta\t gamma "`; assert `result.definition == "alpha beta gamma"`, every returned array item contains no `\n`, and the footer is exactly `[^term]: alpha beta gamma`. Add one `footnote_diagnostics` case with `[^term]: alpha   beta\t gamma` and assert its extracted `definition == "alpha beta gamma"`.

In the real define integration, return `" alpha\n beta\t gamma "` from `emit_definition`, create it in a narrow split, and assert the footer is one physical line and `diagnostic.message` is canonical unwrapped text.

- [ ] **Step 5: Run the unit spec and verify the second RED**

Run the Step 2 command and the equivalent `PlenaryBustedFile tests/integration/define_spec.lua` command independently. Expected: both FAIL because fresh storage/rehydration remain trim-only and the real path retains multiline definition whitespace.

- [ ] **Step 6: Route every definition boundary through the canonicalizer**

Make `format_footnote_line`, `format_definition`, `apply_definition_footnote`'s returned `definition`, and `parse_footnote_line` call `M.normalize_definition`. Let `parse_structured_definition` normalize the parsed body through the same helper. Change `format_definition(term, definition)` to compose only semantic text and remove its width argument/display formatter call.

- [ ] **Step 7: Run the unit spec and verify GREEN**

Run both commands from Step 5. Expected: all unit and integration define cases PASS.

- [ ] **Step 8: Commit the canonical payload change**

```bash
git add lua/parley/define.lua tests/unit/define_spec.lua tests/integration/define_spec.lua
git commit -m "diagnostics: #201 canonicalize definition payloads"
```

### Task 2: Add a focused display-cell row wrapper

**Files:**
- Create: `lua/parley/diagnostic_text.lua`
- Create: `tests/unit/diagnostic_text_spec.lua`

- [ ] **Step 1: Write the failing row/whitespace tests**

Create the spec requiring `parley.diagnostic_text` and assert:

```lua
assert.same({ "alpha beta", "gamma" }, text.wrap_rows("alpha beta gamma", 10, string.len))
assert.same({ "", "alpha beta", "", "" }, text.wrap_rows("\t\nalpha\tbeta\n\n", 20, string.len))
```

Also retain the input in a local and assert it is unchanged after the call.

- [ ] **Step 2: Run the new spec and verify RED**

Run:

```bash
nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/diagnostic_text_spec.lua" -c "qa!"
```

Expected: FAIL because module `parley.diagnostic_text` does not exist.

- [ ] **Step 3: Implement semantic-row preservation and ordinary greedy wrapping**

Create `diagnostic_text.wrap_rows(text, width, display_width)`. Require the measurement function, coerce width with `math.max(2, tonumber(width) or 76)`, split `(tostring(text) .. "\n")` using `(.-)\n` so empty edge rows survive, tokenize nonempty rows with `%S+`, normalize separators to one space, and greedily build rows using `display_width(candidate)`.

- [ ] **Step 4: Run the new spec and verify the first GREEN**

Run the Step 2 command. Expected: row/whitespace cases PASS.

- [ ] **Step 5: Write failing Unicode token-splitting tests**

Use production `vim.fn.strdisplaywidth`, not a width table. Assert width `1` is treated as `2`; `"界界ab"` becomes `{ "界", "界", "ab" }`; `"abcdef"` becomes `{ "ab", "cd", "ef" }`; and `"a\u{0301}bc"` becomes `{ "a\u{0301}b", "c" }`. Assert concatenating the rows recreates each source token byte-for-byte and every nonempty row has `vim.fn.strdisplaywidth(row) <= 2`.

- [ ] **Step 6: Run the new spec and verify the Unicode RED**

Run the Step 2 command. Expected: FAIL because an overlong token is still emitted whole.

- [ ] **Step 7: Implement accumulation-based UTF-8 splitting**

Add this focused helper and feed its fragments through the ordinary greedy row builder:

```lua
local UTF8_CHAR = "[%z\1-\127\194-\244][\128-\191]*"

local function split_word(word, width, display_width)
    local fragments = {}
    local fragment = ""
    for char in word:gmatch(UTF8_CHAR) do
        local candidate = fragment .. char
        if fragment ~= "" and display_width(candidate) > width then
            fragments[#fragments + 1] = fragment
            fragment = char
        else
            fragment = candidate
        end
    end
    if fragment ~= "" then
        fragments[#fragments + 1] = fragment
    end
    return fragments
end
```

Measuring `fragment .. char`, never an isolated combining character, keeps `a\u{0301}` together under production `strdisplaywidth`. `wrap_rows` passes through words that already fit, otherwise inserts each returned fragment using the same row append/flush path, and returns rows rather than a joined string.

- [ ] **Step 8: Run the new spec and verify GREEN**

Run the Step 2 command. Expected: all `tests/unit/diagnostic_text_spec.lua` cases PASS.

- [ ] **Step 9: Commit the wrapper change**

```bash
git add lua/parley/diagnostic_text.lua tests/unit/diagnostic_text_spec.lua
git commit -m "diagnostics: #201 wrap semantic text by display cells"
```

## Chunk 2: Render-time reflow and lifecycle

### Task 3: Publish width-independent diagnostics

**Files:**
- Modify: `lua/parley/skill_render.lua`
- Modify: `tests/unit/skill_render_spec.lua`
- Modify: `tests/integration/define_spec.lua`

- [ ] **Step 1: Write the failing publication regression**

In a 30-column window, assert `attach_diagnostics` preserves `"alpha beta gamma delta epsilon zeta\nparagraph two"` exactly in `diagnostic.message`: the long first semantic row must receive no additional creation-time newline, while the explicit paragraph newline remains.

- [ ] **Step 2: Run the unit spec and verify its RED**

```bash
nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/skill_render_spec.lua" -c "qa!"
```

Expected: FAIL because `attach_diagnostics` stores creation-time wrapping.

- [ ] **Step 3: Remove creation-time presentation logic**

In `refresh_footnote_diagnostics`, remove width measurement and publish `define.format_definition(term, definition)` directly. In `attach_diagnostics`, publish `tostring(edit.explain or "edit applied")` directly. Remove `diagnostic_wrap_width` and `format_diagnostic_message` once repository search confirms no remaining consumer; wrapping now belongs exclusively to display.

- [ ] **Step 4: Run the focused spec and verify GREEN**

Run the Step 2 command. Expected: PASS. Then run `rg -n "diagnostic_wrap_width|format_diagnostic_message" lua tests`; expected: no production consumer or stale test remains. The real definition integration coverage already went RED/GREEN in Task 1.

- [ ] **Step 5: Commit width-independent publication**

```bash
git add lua/parley/skill_render.lua tests/unit/skill_render_spec.lua tests/integration/define_spec.lua
git commit -m "diagnostics: #201 publish semantic messages"
```

### Task 4: Reflow each custom display at its measured width

**Files:**
- Modify: `lua/parley/skills/review/diag_display.lua`
- Test: `tests/integration/review_diag_display_spec.lua`

- [ ] **Step 1: Write failing renderer and geometry tests**

Add real Neovim-window tests proving:

1. One canonical long footnote message produces different balanced row sets in narrow and wide floats.
2. Float buffer rows are `Diagnostics:` plus rows wrapped to the configured float content width; height equals row count when it fits.
3. Horizontal geometry uses `col = max(0, floor((parent_width - content_width - 2) / 2))`; when the parent can contain borders, assert `col + content_width + 2 <= parent_width`.
4. The unclamped vertical anchor is `winline() - 1`; bottom placement clamps so `row + height + 2 <= parent_height` when borders fit.
5. For parents smaller than three columns/rows, content width/height remain at least one and row/column remain nonnegative; border containment is explicitly impossible and is not asserted.
6. Two windows showing one buffer make review virtual lines use the narrowest usable text width. Resize the non-current window across the minimum-width boundary, fire `WinResized`, and assert rows reflow while the underlying diagnostic is unchanged.
7. A non-current resized window showing a different buffer causes that buffer's visible virtual-line diagnostic to reflow as well; no current-buffer shortcut may satisfy this case.
8. Enter the other window with `WinEnter` and assert width is remeasured without diagnostic recreation.
9. Review leading/interior/trailing empty rows remain distinct and tabs render as a single separator.
10. Calling `dd.set(true)` repeatedly and repeatedly publishing with `vim.diagnostic.set` keeps the lifecycle augroup count exactly three; `dd.set(false)` reduces it to zero and closes display floats/marks.

In `before_each`, record the original window id/width/height. Track every created split, float, and scratch buffer. In `after_each`, call `dd.set(false)`, close tracked windows/buffers if valid, restore the original window and dimensions, then call `dd.set(true)`. This cleanup is part of each real-window test, not optional test hygiene.

- [ ] **Step 2: Run the display integration spec and verify RED**

Run:

```bash
nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua" -c "qa!"
```

Expected: FAIL because the controller splits stored newlines, measures no target width, computes height before soft wrapping, and has no resize rerender.

- [ ] **Step 3: Implement render-time measurement and wrapping**

In `diag_display.lua`:

- Add `VIRTUAL_LINE_MARGIN = DISPLAY_COL + 2` (two cells for the diagnostic connector) and `usable_width_for_win(win)` using `getwininfo(win)[1].width - textoff - VIRTUAL_LINE_MARGIN`, clamped to at least two. Pin this exact derivation in a test.
- Add `shared_virtual_width(buf)` over `vim.fn.win_findbuf(buf)`, choosing the minimum valid usable width.
- Change `diagnostic_message_lines(diagnostic, width)` to call `diagnostic_text.wrap_rows(message, width, vim.fn.strdisplaywidth)` before constructing highlighted virtual rows.
- Compute float geometry first: `available_width = math.max(1, parent_width - 2)`, `content_width = math.min(math.max(2, floor(parent_width * 0.8)), available_width)`, and `col = math.max(0, floor((parent_width - content_width - 2) / 2))`. Use that exact content width for `wrap_rows`.
- Count `Diagnostics:` plus all wrapped/blank rows; set `height = math.min(row_count, math.max(1, parent_height - 2))`; set `row = math.max(0, math.min(vim.fn.winline() - 1, parent_height - height - 2))`. Recompute width, rows, height, row, and column on every render.
- Populate the float buffer with the explicit wrapped rows and set window `wrap=false`; those rows, rather than implicit soft wrap, own geometry.
- Replace per-buffer lifecycle registration with one global augroup owned by `diag_display`. `set(true)` clears and installs exactly one callback for each of `CursorMoved`, `WinEnter`, and `WinResized`; handler `show` never creates autocmds. Cursor/enter callbacks rerender their current buffer. The resize callback reads window ids from `vim.v.event.windows` (falling back to the current window when absent), maps valid resized windows to their buffers, deduplicates those buffers, and rerenders each with a representative visible window/cursor. `render` accepts that anchor window for position/width measurement, but opens a footnote float only for the actual current window; non-current buffers update only their buffer-scoped virtual lines. `set(false)` clears the whole lifecycle augroup and all display artifacts.

- [ ] **Step 4: Run the display integration spec and verify GREEN**

Run the Step 2 command. Expected: all display integration cases PASS.

- [ ] **Step 5: Commit renderer reflow**

```bash
git add lua/parley/skills/review/diag_display.lua tests/integration/review_diag_display_spec.lua
git commit -m "diagnostics: #201 reflow at render width"
```

### Task 5: Verify Neovim's built-in float consumes canonical text

**Files:**
- Modify: `tests/integration/review_diag_display_spec.lua`

- [ ] **Step 1: Add a built-in-float integration regression**

Make the parent at least 100 columns wide. Publish a long canonical footnote diagnostic, disable Parley's custom display temporarily, and capture the `(float_bufnr, winid)` returned by `vim.diagnostic.open_float(buf, { scope = "cursor", width = 30 })`. Inspect those exact objects: assert configured width equals 30, the diagnostic prose remains one logical buffer line, the float's window-local `wrap` option is true, and the underlying `diagnostic.message` is unchanged. Close the returned window/buffer explicitly, reopen at width 70, assert configured width equals 70 and the same canonical message remains unchanged, then close it and restore `dd.set(true)`.

- [ ] **Step 2: Run the display integration spec**

Run the Task 4 Step 2 command. Expected: PASS; if it fails, adjust only Parley's canonical publication/display configuration, not Neovim internals.

- [ ] **Step 3: Commit built-in consumer coverage**

```bash
git add tests/integration/review_diag_display_spec.lua
git commit -m "test: #201 cover built-in diagnostic reflow"
```

## Chunk 3: Documentation and verification

### Task 6: Update the codebase map and issue evidence

**Files:**
- Modify: `atlas/chat/inline_define.md`
- Modify: `workshop/issues/000201-reflow-definition-diagnostics-at-display-width.md`

- [ ] **Step 1: Update the inline-definition flow map**

Document that the managed footnote and diagnostic payload are canonical single-paragraph text, while `diag_display` performs display-cell wrapping at actual float/virtual-line width and refreshes on window resize. Remove the stale statement that `define.format_definition` calls creation-time `skill_render.format_diagnostic_message`.

- [ ] **Step 2: Run atlas traceability verification**

Run `make test-changed`. Expected: the inline-definition traceability mapping and mapped specs PASS.

- [ ] **Step 3: Run focused tests and lint**

```bash
for spec in tests/unit/define_spec.lua tests/unit/diagnostic_text_spec.lua tests/unit/skill_render_spec.lua tests/integration/define_spec.lua tests/integration/review_diag_display_spec.lua; do
  nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile $spec" -c "qa!" || exit 1
done
make lint
git diff --check
```

Expected: all focused specs PASS, lint reports zero warnings/errors, and `git diff --check` is silent.

- [ ] **Step 4: Run the full suite in the repository's pinned ripgrep environment**

```bash
env PATH=/opt/homebrew/Cellar/ripgrep/15.1.0/bin:/Users/xianxu/.luarocks/bin:/opt/homebrew/bin:/usr/bin:/bin make test
```

Expected: all lint, unit, architecture, and integration checks PASS.

- [ ] **Step 5: Record verified implementation evidence**

Only after Steps 2–4 succeed, tick each existing issue-plan summary checkbox without changing its wording. Append a dated `## Log` entry with the exact RED/GREEN commands, focused/full verification, root-cause confirmation, all display consumers covered, and `ARCH-DRY`/`ARCH-PURE`/`ARCH-PURPOSE` outcomes. Preserve all prior log and revision text.

Run `git diff --check` again after these issue/atlas edits. Expected: silent, so the final committed state—not only the pre-log code state—is whitespace-clean.

- [ ] **Step 6: Commit docs and verified issue evidence**

```bash
git add atlas/chat/inline_define.md workshop/issues/000201-reflow-definition-diagnostics-at-display-width.md
git commit -m "docs: #201 map display-time diagnostic reflow"
```

- [ ] **Step 7: Close through the SDLC gate**

Run `sdlc actual --issue 201`, inspect its attribution, then run:

```bash
sdlc close --issue 201 --verified 'Focused define/diagnostic-text/skill-render/diagnostic-display specs pass; real narrow/wide/two-window/WinEnter/WinResized/built-in-float regressions pass; make test-changed, make lint, pinned-ripgrep full make test, and git diff --check pass.'
```

Do not hand-enter actual hours or bypass the atlas gate: the explicit atlas update must satisfy it. The close command owns the fresh-context boundary review and does not commit. On SHIP, run `git diff --check` over its generated mutations, then commit those #201 issue/review artifacts. On FIX-THEN-SHIP, implement every Critical/Important finding before committing (add a failing regression first for behavior changes), rerun affected focused/full verification, update `## Log`, run `git diff --check`, and bundle fixes plus close-generated issue/bookkeeping mutations into one commit; do **not** rerun close. Only if fixes must land after that close commit should `sdlc close` be rerun to review the new delta and advance the anchor. Preserve unrelated user-owned working-tree files in every commit.

## Revisions

### 2026-08-18 — resolve chunk plan reviews

- Moved wrapping into focused pure `diagnostic_text.lua`, added exact fresh and
  rehydrated normalization tests, and changed combining-mark handling to
  context-sensitive accumulated display-width measurement.
- Defined one deduplicated global display lifecycle, non-current resize and
  `WinEnter` coverage, exact border-aware geometry, tiny-parent behavior, and
  complete window/buffer cleanup.
- Moved issue checkbox/log finalization after verification, added
  `make test-changed`, made close evidence concrete, and specified post-verdict
  fix/commit handling without atlas bypass.
