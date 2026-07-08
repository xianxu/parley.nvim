# Boundary Review — parley.nvim#173 (whole-issue close)

| field | value |
|-------|-------|
| issue | 173 — diagnostic virtual lines blank on long wrapped markdown |
| repo | parley.nvim |
| issue file | workshop/issues/000173-diagnostic-virtual-lines-leftcol.md |
| boundary | whole-issue close |
| milestone | — |
| window | b9094e9bfc89b0f27013c6fd41c38a83b8b61510..HEAD |
| command | sdlc close --issue 173 |
| reviewer | codex |
| timestamp | 2026-07-08T13:29:14-07:00 |
| verdict | REWORK |

## Review

Reading additional input from stdin...
OpenAI Codex v0.142.5
--------
workdir: /Users/xianxu/workspace/parley.nvim
model: gpt-5.5
provider: openai
approval: never
sandbox: workspace-write [workdir, /tmp, $TMPDIR, /tmp] (network access enabled)
reasoning effort: none
reasoning summaries: none
session id: 019f4369-b302-73e2-9157-1992fcc2eca0
--------
user
# Code review — the one SDLC boundary review

You are conducting a fresh-context code review at a development boundary —
whole-issue close — in the **parley.nvim** repository.

- repository: parley.nvim   (root: /Users/xianxu/workspace/parley.nvim)
- issue:      parley.nvim#173   (file: workshop/issues/000173-diagnostic-virtual-lines-leftcol.md)
- window:     Base: b9094e9bfc89b0f27013c6fd41c38a83b8b61510   Head: HEAD

Review the **parley.nvim** repo and its tracker — the ariadne base-layer repo itself (changes here propagate to dependent repos). Do not assume any
other repository or apply another repo's conventions.

You have no prior session context — that is the anti-collusion property. Verify
behavior against the issue's documented Spec/Plan and the code itself; do NOT
take the implementor's word in commit messages or docs at face value. Tools are
read-only: report findings precisely; the main agent (which has session context)
applies the fixes, commits, and re-runs.

Read the diff against the issue's Spec + Plan, then work the checklist below.
Categorize every finding by severity — not everything is Critical; a nitpick
marked Critical is noise.

  Critical (must fix before crossing the boundary)
    - correctness bugs; crashes / panics on unexpected input
    - behavior drift from stated contracts (for ports of existing code where
      byte-faithfulness was promised, diff against the source)
    - silent error swallowing where the source raised
  Important (fix before the boundary if cheap)
    - API design of newly-introduced internal packages (downstream work will
      consume them; is the surface stable?)
    - missing test coverage that would catch the kind of bug shipped
    - inconsistent error handling across the diff
  Minor (note for future)
    - style nits, naming, comment density; performance only if hot-path

## Review checklist

Code quality
  - Clean separation of concerns; edge cases handled (empty / nil / unexpected).
  - Proper error handling — no silent swallowing where the source raised.
  - No duplicated logic / copy-paste that should be a shared helper.

Testing
  - Tests pin real logic, not mocks reasserting the implementation.
  - The kind of bug this diff could ship is covered.
  - PURE entities tested without IO; INTEGRATION via injected fakes (see below).

Requirements traceability
  - Every Plan checklist item this boundary claims is actually delivered.
  - Implementation matches the Spec; no undeclared scope creep.
  - Breaking changes documented.

Production readiness
  - Migration / backward-compatibility considered where state or formats change.
  - Docs / atlas updated for new surface (see the Docs update gate).

## Core concepts cross-check (if the plan has a Core concepts table)

The plan should list entities in a greppable table — name, kind
(PURE/INTEGRATION), file location, status (new/modified/deleted). For each row:
  - Verify the entity exists at the stated path (grep the diff or filesystem).
  - PURE: tests run without IO (no exec, net, mutable fs). If tests need mocks
    to run, it isn't really PURE — flag Critical and recommend promoting it to
    INTEGRATION.
  - INTEGRATION: injected into pure callers, not invoked directly from business
    logic.
  - "modified" / "deleted": the diff shows the expected change/removal at the
    stated location.
Any contradiction between table and code = Critical finding, plus a plan-revision
recommendation (a "## Revisions" entry so the plan stops claiming what the code
doesn't deliver).

## Docs update gate (atlas + README, per AGENTS.md §8)

The boundary should update user-facing docs for any new surface introduced:

  - **atlas/** — new architectural surface, flow, or terminology. Scan the diff
    for new entity types, subcommands, conventions, file-tree locations. Any
    present without corresponding atlas/ changes in the same range = Important
    finding ("atlas update appears missing for <surface>").
  - **README.md** — new user-facing surface a reader runs or types: subcommands,
    flags, keybindings, config keys, install/usage steps. If the diff adds or
    changes such surface and README.md is not updated in the same range =
    Important finding ("README update appears missing for <surface>"). This is the
    class of gap that used to surface only at the merge-time `specs` judge (#142);
    catch it here, at the earliest gate, before the close verdict is recorded.

## Architecture (the at-review backstop — these matter most long-term)

Work through each of ARCH-DRY, ARCH-PURE, ARCH-PURPOSE explicitly, applying its at-review lens. The
full principle definitions are delivered in the ARCHITECTURE PRINCIPLES block
right after this prompt — for EACH marker, state pass or flag, and cite the
marker (e.g. ARCH-DRY) in any finding. Architecture is where review has the
least training signal and the longest-delayed payoff, so be deliberate here, not
holistic.

## Verdict + output

Begin your response with this fenced verdict block — the machine-read handoff:

```verdict
verdict: <SHIP | FIX-THEN-SHIP | REWORK>
confidence: <high | medium | low>
```

  SHIP           ready; ship it
  FIX-THEN-SHIP  ship after addressing the findings (non-blocking at the gate)
  REWORK         blocking; needs rework before shipping — fix + re-run

The fenced ```` ```verdict ```` block above is the **authoritative machine-read
handoff** — emit it as the first thing in your response. (A prose
`VERDICT: <TOKEN>` first line still satisfies the legacy contract as a fallback,
but the block is what the binary trusts.)

After the verdict block: a 1-paragraph summary — what worked, what blocks SHIP if
it isn't — followed by:
  1. Strengths: 2-5 specific things done well (file:line where useful). Affirm
     validated approaches so the operator knows what's confirmed-good ground.
     Empty acceptable for trivial boundaries.
  2. Critical findings (file:line + fix sketch); empty if none.
  3. Important findings (same format).
  4. Minor findings (terse one-liners).
  5. Test coverage notes.
  6. Architectural notes for upcoming work.
  7. Plan revision recommendations: specific "## Revisions" entries the plan
     needs (empty if the plan still matches the code).


ARCHITECTURE PRINCIPLES — work through each of the 3 entries below explicitly, applying its `at-review` lens; cite the marker (e.g. ARCH-DRY) in any finding.

# Architecture principles (ARCH-*)

Injected architectural taste — the structural decisions whose payoff (or cost)
shows up many turns, often months, down the road. Agents are strong at local
tactics and weak here, so these are checked **at-plan** (when the design is being
made — highest leverage) and **at-review** (backstop, on the diff). Cite the
marker (e.g. `ARCH-DRY`) in plans, `## Log` entries, and review findings.

This file is the single source; it is embedded into the planning, plan-quality,
and code-review prompts. The human narrative lives in AGENTS.md "Core Design
Principles"; this is its machine-delivered companion.

## ARCH-DRY — Don't Repeat Yourself

- **principle:** Reuse before adding. One source of truth per fact/behavior; no
  duplicated logic, copy-pasted blocks, or parallel functions that should be one
  shared helper.
- **at-plan:** Flag a plan that re-implements something the codebase already has,
  or that will obviously duplicate logic across the new files instead of
  extracting a shared helper. Name the existing thing it should reuse.
- **at-review:** Flag duplicated logic / copy-pasted blocks / near-identical
  functions in the diff; point at the consolidation (file:line + the shared
  helper they should become).

## ARCH-PURE — Pure core, thin IO shell

- **principle:** The majority of code is pure functions (deterministic, no side
  effects); a thin "glue" layer at the boundary touches IO/UI/network/clock. Pure
  functions are unit-tested directly; the glue is kept small and injected.
- **at-plan:** Flag a design that buries business logic inside IO/handlers, or
  that will only be testable with heavy mocks (a sign logic isn't separated from
  IO). The plan should name what's pure vs the thin IO seam.
- **at-review:** Flag business logic mixed with IO in the diff; logic that should
  be a pure function injected into a thin caller. If a test needs mocks to run a
  "pure" entity, it isn't pure — recommend extracting the IO to the boundary.

## ARCH-PURPOSE — Serve the issue's actual purpose

- **principle:** Deliver the issue's stated purpose, not the easy subset of it. A
  single-source / "compiled to consumers" change is not done until **every
  consumer derives** from the source — the source is *enforced*, not just
  documentation a surface happens to restate; a hand-maintained restatement of the
  model is a deferred consumer, not a finished one. "Follow-up" is for separable
  extensions, never for the thing that is the point. This is the *opposite axis*
  from Simplicity-First/YAGNI: not "build for an imagined future," but "don't
  **under**-deliver the purpose you already committed to."
- **at-plan:** Flag a plan whose scope is a strict subset of the issue's stated
  goal / Done-when where the part deferred as "follow-up" *is* the purpose (e.g.
  wires one consumer + enforcement but leaves the consumers that motivated the
  issue as documentation that doesn't derive). Ask: does the plan fulfill the
  purpose, or just the cheap win? Name the deferred purpose.
- **at-review:** Does the diff *fulfill* the purpose or settle for the easy win?
  For a single-source change, run the **shadow-sweep** — enumerate the consumers,
  confirm each derives from the source, flag any remaining hand-maintained
  restatement of the model. A "follow-up" that is actually the deferred point of
  the issue is a finding, not a deferral.


OUTPUT CONTRACT (machine-read — do not deviate). LEAD your response with the
fenced ```verdict block shown above — that is the authoritative handoff the binary
reads (its `verdict:` value is one of the listed tokens). Everything after the block
is advisory: a non-blocking verdict WITH findings still PASSES the gate. A bare
`VERDICT: <TOKEN>` line is accepted only as a FALLBACK when the block is absent.

Diff:
diff --git a/atlas/chat/inline_define.md b/atlas/chat/inline_define.md
index 270e924..6df2cf4 100644
--- a/atlas/chat/inline_define.md
+++ b/atlas/chat/inline_define.md
@@ -1,14 +1,14 @@
 # Inline Term Definition

 Select a phrase in a chat transcript, press **`<M-CR>`** (visual mode), and a
-concise, context-aware definition appears as an inline diagnostic (grey
-`virtual_lines`) under the phrase. The selected text stays in place and gets a
-markdown footnote reference (`ASIN[^asin]`), while the definition is stored in a
-managed footnote footer at the end of the chat transcript. Persisted managed
-footnotes are rehydrated into diagnostics when any markdown buffer is entered or
-refreshed. The whole new annotation is **undoable** — `u` reverts the footnote
-edit and clears both decorations (see Undo below). For jargon you don't know
-(e.g. `ASIN`), it's a one-keystroke lookup. Added in
+concise, context-aware definition appears as an inline diagnostic under the
+phrase. The selected text stays in place and gets a markdown footnote reference
+(`ASIN[^asin]`), while the definition is stored in a managed footnote footer at
+the end of the chat transcript. Persisted managed footnotes are rehydrated into
+diagnostics when any markdown buffer is entered or refreshed. The whole new
+annotation is **undoable** — `u` reverts the footnote edit and clears both
+decorations (see Undo below). For jargon you don't know (e.g. `ASIN`), it's a
+one-keystroke lookup. Added in
 [#161](../../workshop/issues/000161-inline-term-definition.md) (R1 added the
 highlight/undo); [#166](../../workshop/issues/000166-visual-selection-definition-system-manages-footnote.md)
 made the definition durable as a managed footnote; [#167](../../workshop/issues/000167-define-diagnostic-highlight-span.md)
@@ -41,9 +41,9 @@ rehydrates persisted managed footnotes in all markdown buffers.
    inline `term[^id]` spans (`define.format_definition` →
    `skill_render.format_diagnostic_message`) on the `parley_skill` namespace;
    **(d)** records the undo/redo projection states.
-   `diag_display`'s `virtual_lines{current_line=true}` reveals the diagnostic
-   (cursor parked on the term's line). A no-`emit_definition` response leaves no
-   footnote reference/footer.
+   `diag_display`'s Parley-owned left-column virtual-line display reveals the
+   diagnostic (cursor parked on the term's line). A no-`emit_definition` response
+   leaves no footnote reference/footer.

 ## Undo (`u`) — reuses review's projection

@@ -126,8 +126,8 @@ tool-call args (`result.calls[1].input`), read in `on_done`.
 - `skill_render.refresh_footnote_diagnostics` owns only diagnostics tagged
   `parley-footnote` and preserves other `parley_skill` diagnostics, so review
   diagnostics are not cleared by markdown footnote refresh.
-- A diagnostic's `virtual_lines` auto-hide when the cursor leaves its line. The
-  footnote persists in the file if saved.
+- A diagnostic's Parley virtual-line block auto-hides when the cursor leaves its
+  line. The footnote persists in the file if saved.

 ## Key files

diff --git a/atlas/modes/review.md b/atlas/modes/review.md
index b470783..ef656df 100644
--- a/atlas/modes/review.md
+++ b/atlas/modes/review.md
@@ -162,12 +162,16 @@ session-scoped undo); per-state snapshots aren't journaled.
 The edit "why" (the per-edit `explain`) is an INFO diagnostic on parley's
 `parley_skill` namespace. `lua/parley/skills/review/diag_display.lua` controls how
 it shows — scoped to that namespace, so the user's LSP/global diagnostics are
-untouched. Default **on**: `virtual_lines { current_line = true }`, so the
-(hard-wrapped, via `skill_render.format_diagnostic_message`) why **auto-expands
-below an edit when the cursor is in that edit's region** (`attach_diagnostics` spans `lnum..end_lnum`)
-and hides otherwise. `:ParleyShowDiagnostics` toggles it. The built-in `]d`/`[d`
-(jump) and `<C-W>d` (float, wraps) also work on these diagnostics. Composes with
-M5 — re-renders on undo/redo.
+untouched. Default **on**: Parley's custom `parley/virtual_lines` diagnostic
+handler renders a left-column virtual-line block headed `Diagnostics:` for the
+current line. It avoids Neovim's stock virtual-lines indentation-by-diagnostic
+column, which can hide messages on long wrapped prose. The hard-wrapped why
+(`skill_render.format_diagnostic_message`) **auto-expands below an edit when the
+cursor is in that edit's region** (`attach_diagnostics` spans
+`lnum..end_lnum`) and hides otherwise. `:ParleyShowDiagnostics` toggles it. The
+built-in `]d`/`[d` (jump) and `<C-W>d` (float, wraps) still work on these
+diagnostics because the underlying diagnostic spans remain unchanged. Composes
+with M5 — re-renders on undo/redo.

 ## Progress bar (#133 M7)

diff --git a/lua/parley/skills/review/diag_display.lua b/lua/parley/skills/review/diag_display.lua
index 4617a35..6fd4da6 100644
--- a/lua/parley/skills/review/diag_display.lua
+++ b/lua/parley/skills/review/diag_display.lua
@@ -10,20 +10,150 @@ local M = {}

 M.enabled = true -- default on (cursor-region auto-show)

+local HANDLER_NAME = "parley/virtual_lines"
+local DISPLAY_NS = "parley_diagnostic_virtual_lines"
+local DISPLAY_AUGROUP = "parley_diagnostic_virtual_lines"
+local HEADER_HL = "ParleyDiagnosticVirtualLineHeader"
+local MESSAGE_HL = "ParleyDiagnosticVirtualLine"
+
+local display_ns_id
+local display_augroup
+
 -- Parley's review diagnostic namespace — single-sourced from skill_render (which
 -- owns the namespace) so the identity isn't a duplicated literal (#133 M6 review).
 local function ns()
     return require("parley.skill_render").diag_namespace()
 end

+local function ensure_display()
+    if not display_ns_id then
+        display_ns_id = vim.api.nvim_create_namespace(DISPLAY_NS)
+    end
+    if not display_augroup then
+        display_augroup = vim.api.nvim_create_augroup(DISPLAY_AUGROUP, { clear = true })
+    end
+    vim.api.nvim_set_hl(0, HEADER_HL, { link = "DiagnosticInfo" })
+    vim.api.nvim_set_hl(0, MESSAGE_HL, { link = "DiagnosticFloatingInfo" })
+end
+
+local function clear(buf)
+    ensure_display()
+    if vim.api.nvim_buf_is_valid(buf) then
+        vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
+        pcall(vim.api.nvim_clear_autocmds, { group = display_augroup, buffer = buf })
+    end
+end
+
+local function current_line_for(buf)
+    if vim.api.nvim_get_current_buf() ~= buf then
+        return nil
+    end
+    return vim.api.nvim_win_get_cursor(0)[1] - 1
+end
+
+local function diagnostic_message_lines(diagnostic)
+    local lines = {}
+    for _, line in ipairs(vim.split(tostring(diagnostic.message or ""), "\n", { plain = true })) do
+        table.insert(lines, { { line ~= "" and line or " ", MESSAGE_HL } })
+    end
+    if #lines == 0 then
+        table.insert(lines, { { " ", MESSAGE_HL } })
+    end
+    return lines
+end
+
+local function render(buf, diagnostics, current_line_only)
+    ensure_display()
+    if not vim.api.nvim_buf_is_valid(buf) then
+        return
+    end
+    vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
+
+    local line = current_line_only and current_line_for(buf) or nil
+    if current_line_only and not line then
+        return
+    end
+
+    local by_line = {}
+    for _, diagnostic in ipairs(diagnostics or {}) do
+        if not current_line_only or diagnostic.lnum == line then
+            by_line[diagnostic.lnum] = by_line[diagnostic.lnum] or {}
+            table.insert(by_line[diagnostic.lnum], diagnostic)
+        end
+    end
+
+    for lnum, line_diagnostics in pairs(by_line) do
+        table.sort(line_diagnostics, function(a, b)
+            return (a.col or 0) < (b.col or 0)
+        end)
+        local virt_lines = { { { "Diagnostics:", HEADER_HL } } }
+        for _, diagnostic in ipairs(line_diagnostics) do
+            vim.list_extend(virt_lines, diagnostic_message_lines(diagnostic))
+        end
+        vim.api.nvim_buf_set_extmark(buf, display_ns_id, lnum, 0, {
+            virt_lines = virt_lines,
+            virt_lines_leftcol = true,
+            virt_lines_above = false,
+        })
+    end
+end
+
+local function register_handler()
+    ensure_display()
+    vim.diagnostic.handlers[HANDLER_NAME] = {
+        show = function(namespace, bufnr, diagnostics, opts)
+            if namespace ~= ns() then
+                return
+            end
+            bufnr = vim._resolve_bufnr(bufnr)
+            local handler_opts = opts and opts[HANDLER_NAME] or {}
+            local current_line_only = handler_opts.current_line == true
+            clear(bufnr)
+            if current_line_only then
+                vim.api.nvim_create_autocmd("CursorMoved", {
+                    buffer = bufnr,
+                    group = display_augroup,
+                    callback = function()
+                        render(bufnr, diagnostics, true)
+                    end,
+                })
+            end
+            render(bufnr, diagnostics, current_line_only)
+        end,
+        hide = function(namespace, bufnr)
+            if namespace ~= ns() then
+                return
+            end
+            clear(vim._resolve_bufnr(bufnr))
+        end,
+    }
+end
+
+function M.refresh(buf)
+    if not M.enabled then
+        return
+    end
+    buf = buf or vim.api.nvim_get_current_buf()
+    render(buf, vim.diagnostic.get(buf, { namespace = ns() }), true)
+end
+
 --- Apply the inline-display config for parley's review namespace.
 --- @param on boolean
 function M.set(on)
     M.enabled = on and true or false
+    register_handler()
     vim.diagnostic.config({
-        virtual_lines = M.enabled and { current_line = true } or false,
+        [HANDLER_NAME] = M.enabled and { current_line = true } or false,
+        virtual_lines = false,
         virtual_text = false,
     }, ns())
+    if M.enabled then
+        M.refresh()
+    else
+        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
+            clear(buf)
+        end
+    end
 end

 --- Toggle inline display; returns the new state.
diff --git a/tests/integration/review_diag_display_spec.lua b/tests/integration/review_diag_display_spec.lua
index 7950705..97fe2e8 100644
--- a/tests/integration/review_diag_display_spec.lua
+++ b/tests/integration/review_diag_display_spec.lua
@@ -6,9 +6,19 @@ local function ns_cfg()
     return vim.diagnostic.config(nil, require("parley.skill_render").diag_namespace())
 end

+local function display_marks(buf)
+    local display_ns = vim.api.nvim_create_namespace("parley_diagnostic_virtual_lines")
+    return vim.api.nvim_buf_get_extmarks(buf, display_ns, 0, -1, { details = true })
+end
+
 describe("review.diag_display", function()
     after_each(function()
         dd.set(true) -- restore default for other specs
+        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
+            if vim.api.nvim_buf_is_valid(buf) then
+                pcall(vim.diagnostic.reset, require("parley.skill_render").diag_namespace(), buf)
+            end
+        end
     end)

     it("toggles the enabled state", function()
@@ -20,12 +30,57 @@ describe("review.diag_display", function()
         assert.is_true(dd.is_enabled())
     end)

-    it("configures virtual_lines current_line on parley's namespace when on; off when disabled", function()
+    it("configures Parley's custom current-line display on its namespace when on; off when disabled", function()
         dd.set(true)
         local on = ns_cfg()
-        assert.is_truthy(on.virtual_lines) -- { current_line = true }
+        assert.is_false(on.virtual_lines) -- Parley owns its virtual-lines renderer.
+        assert.is_truthy(on["parley/virtual_lines"])
         assert.is_false(on.virtual_text) -- inline single-line is never used
         dd.set(false)
-        assert.is_false(ns_cfg().virtual_lines)
+        assert.is_false(ns_cfg()["parley/virtual_lines"])
+    end)
+
+    it("renders current-line diagnostics from the left column without moving the diagnostic span", function()
+        local skill_render = require("parley.skill_render")
+        local diag_ns = skill_render.diag_namespace()
+        local buf = vim.api.nvim_create_buf(false, true)
+        vim.api.nvim_set_current_buf(buf)
+        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
+            string.rep("x", 120) .. " ACOS[^acos]",
+        })
+
+        dd.set(true)
+        vim.diagnostic.set(diag_ns, buf, { {
+            lnum = 0,
+            col = 121,
+            end_lnum = 0,
+            end_col = 132,
+            message = "ACOS — Advertising Cost of Sales.",
+            severity = vim.diagnostic.severity.INFO,
+            source = "parley-footnote",
+        } })
+
+        vim.wait(100, function()
+            return #display_marks(buf) == 1
+        end)
+
+        local marks = display_marks(buf)
+        assert.are.equal(1, #marks)
+        local details = marks[1][4]
+        assert.is_true(details.virt_lines_leftcol)
+        assert.are.equal("Diagnostics:", details.virt_lines[1][1][1])
+        assert.are_not.equal(string.rep(" ", 121), details.virt_lines[1][1][1])
+        assert.are.equal("ACOS — Advertising Cost of Sales.", details.virt_lines[2][1][1])
+
+        local diagnostics = vim.diagnostic.get(buf, { namespace = diag_ns })
+        assert.are.equal(1, #diagnostics)
+        assert.are.equal(0, diagnostics[1].lnum)
+        assert.are.equal(121, diagnostics[1].col)
+        assert.are.equal(0, diagnostics[1].end_lnum)
+        assert.are.equal(132, diagnostics[1].end_col)
+
+        dd.set(false)
+        assert.are.equal(0, #display_marks(buf))
+        assert.are.equal(1, #vim.diagnostic.get(buf, { namespace = diag_ns }))
     end)
 end)
diff --git a/workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md b/workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md
new file mode 100644
index 0000000..12f0951
--- /dev/null
+++ b/workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md
@@ -0,0 +1,94 @@
+# Diagnostic Virtual Lines Left Column Implementation Plan
+
+> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.
+
+**Goal:** Make Parley's inline diagnostic display visible on long wrapped markdown lines by rendering diagnostic virtual lines from the left column.
+
+**Architecture:** Keep diagnostic data unchanged: spans stay anchored to selected text and footnote references. Replace only Parley's namespace display shell in `diag_display.lua`, so global/LSP diagnostics still use Neovim defaults. This follows ARCH-DRY by keeping one Parley display controller and ARCH-PURE by avoiding parser/data changes.
+
+**Tech Stack:** Lua, Neovim diagnostics, extmarks, Plenary/Busted tests.
+
+---
+
+## Core Concepts
+
+### Pure Entities
+
+| Name | Lives in | Status |
+|------|----------|--------|
+| `ParleyDiagnosticMessageLines` | `lua/parley/skills/review/diag_display.lua` | new |
+
+- **ParleyDiagnosticMessageLines** — deterministic conversion from a diagnostic message string into visible virtual-line rows with a `Diagnostics:` header.
+  - **Relationships:** 1:N from one diagnostic message to display rows.
+  - **DRY rationale:** Both review diagnostics and footnote diagnostics consume the same Parley namespace display.
+  - **Future extensions:** If Parley later adds source-specific labels, this formatter is the one place to widen.
+
+### Integration Points
+
+| Name | Lives in | Status | Wraps |
+|------|----------|--------|-------|
+| `ParleyDiagnosticVirtualLines` | `lua/parley/skills/review/diag_display.lua` | modified | Neovim extmarks |
+
+- **ParleyDiagnosticVirtualLines** — Parley-owned inline diagnostic renderer scoped to `skill_render.diag_namespace()`.
+  - **Injected into:** `diag_display.set(on)`; toggling still owns all inline display setup.
+  - **Future extensions:** Can add color overrides without changing diagnostic producers.
+
+## Chunk 1: Left-Column Renderer
+
+**Files:**
+- Modify: `lua/parley/skills/review/diag_display.lua`
+- Modify: `tests/integration/review_diag_display_spec.lua`
+- Modify: `atlas/modes/review.md`
+- Modify: `atlas/chat/inline_define.md`
+- Modify: `workshop/issues/000173-diagnostic-virtual-lines-leftcol.md`
+
+- [x] **Step 1: Write failing tests**
+
+Add integration coverage that:
+- Sets a Parley diagnostic at a high column on a long line.
+- Enables `diag_display`.
+- Asserts the generated display extmark has `virt_lines_leftcol = true`.
+- Asserts the first virtual-line chunk is `Diagnostics:` instead of leading spaces.
+- Asserts `dd.set(false)` clears the Parley display extmark while leaving the diagnostic data intact.
+
+Run:
+
+```bash
+nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"
+```
+
+Expected: FAIL because the stock diagnostic handler emits leading-space virtual lines and `diag_display` has no custom extmark namespace.
+
+- [x] **Step 2: Implement the renderer**
+
+In `lua/parley/skills/review/diag_display.lua`:
+- Add a private display namespace.
+- Add a private function that clears Parley diagnostic virtual-line extmarks.
+- Add a private render function that reads diagnostics from `skill_render.diag_namespace()`, filters to the current cursor line, and writes `virt_lines` with `virt_lines_leftcol = true`.
+- Configure Neovim diagnostics for the Parley namespace with `virtual_lines = false`, `virtual_text = false`, and existing signs/underline behavior.
+- Register a buffer-local `CursorMoved` autocmd for visible Parley buffers so current-line behavior keeps updating.
+
+- [x] **Step 3: Run green focused tests**
+
+Run:
+
+```bash
+nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"
+```
+
+Expected: PASS.
+
+- [x] **Step 4: Update docs and issue log**
+
+Update atlas text that says Parley uses built-in diagnostic `virtual_lines` so it instead describes the Parley-owned left-column inline renderer. Record red/green evidence in the issue log and tick plan items.
+
+- [x] **Step 5: Final verification**
+
+Run:
+
+```bash
+git diff --check -- lua/parley/skills/review/diag_display.lua tests/integration/review_diag_display_spec.lua atlas/modes/review.md atlas/chat/inline_define.md workshop/issues/000173-diagnostic-virtual-lines-leftcol.md workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md
+make test
+```
+
+Expected: all pass.


codex
I’ll use the required session-start skill, then read the issue, plan, and actual diff from the repository so the review is grounded in files rather than the pasted summary.
exec
/bin/zsh -lc "sed -n '1,220p' /Users/xianxu/workspace/ariadne/construct/adapted/superpowers-using-superpowers/SKILL.md && sdlc --help | sed -n '1,220p' && sed -n '1,220p' workshop/lessons.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
---
name: superpowers-using-superpowers
description: Use when starting any conversation - establishes how to find and use skills, requiring Skill tool invocation before ANY response including clarifying questions
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, skip this skill.
</SUBAGENT-STOP>

<EXTREMELY-IMPORTANT>
If you think there is even a 1% chance a skill might apply to what you are doing, you ABSOLUTELY MUST invoke the skill.

IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.

This is not negotiable. This is not optional. You cannot rationalize your way out of this.
</EXTREMELY-IMPORTANT>

## Instruction Priority

> **Ariadne note:** AGENTS.md Section 3 governs subagent strategy and overrides skills that mandate subagent-driven-development as the default execution path.

Superpowers skills override default system prompt behavior, but **user instructions always take precedence**:

1. **User's explicit instructions** (CLAUDE.md, GEMINI.md, AGENTS.md, direct requests) — highest priority
2. **Superpowers skills** — override default system behavior where they conflict
3. **Default system prompt** — lowest priority

If CLAUDE.md, GEMINI.md, or AGENTS.md says "don't use TDD" and a skill says "always use TDD," follow the user's instructions. The user is in control.

## How to Access Skills

**In Claude Code:** Use the `Skill` tool. When you invoke a skill, its content is loaded and presented to you—follow it directly. Never use the Read tool on skill files.

**In Gemini CLI:** Skills activate via the `activate_skill` tool. Gemini loads skill metadata at session start and activates the full content on demand.

**In other environments:** Check your platform's documentation for how skills are loaded.

## Platform Adaptation

Skills use Claude Code tool names. Non-CC platforms: see `references/codex-tools.md` (Codex) for tool equivalents. Gemini CLI users get the tool mapping loaded automatically via GEMINI.md.

# Using Skills

## The Rule

**Invoke relevant or requested skills BEFORE any response or action.** Even a 1% chance a skill might apply means that you should invoke the skill to check. If an invoked skill turns out to be wrong for the situation, you don't need to use it.

```dot
digraph skill_flow {
    "User message received" [shape=doublecircle];
    "About to EnterPlanMode?" [shape=doublecircle];
    "Already brainstormed?" [shape=diamond];
    "Invoke brainstorming skill" [shape=box];
    "Might any skill apply?" [shape=diamond];
    "Invoke Skill tool" [shape=box];
    "Announce: 'Using [skill] to [purpose]'" [shape=box];
    "Has checklist?" [shape=diamond];
    "Create TodoWrite todo per item" [shape=box];
    "Follow skill exactly" [shape=box];
    "Respond (including clarifications)" [shape=doublecircle];

    "About to EnterPlanMode?" -> "Already brainstormed?";
    "Already brainstormed?" -> "Invoke brainstorming skill" [label="no"];
    "Already brainstormed?" -> "Might any skill apply?" [label="yes"];
    "Invoke brainstorming skill" -> "Might any skill apply?";

    "User message received" -> "Might any skill apply?";
    "Might any skill apply?" -> "Invoke Skill tool" [label="yes, even 1%"];
    "Might any skill apply?" -> "Respond (including clarifications)" [label="definitely not"];
    "Invoke Skill tool" -> "Announce: 'Using [skill] to [purpose]'";
    "Announce: 'Using [skill] to [purpose]'" -> "Has checklist?";
    "Has checklist?" -> "Create TodoWrite todo per item" [label="yes"];
    "Has checklist?" -> "Follow skill exactly" [label="no"];
    "Create TodoWrite todo per item" -> "Follow skill exactly";
}
```

## Red Flags

These thoughts mean STOP—you're rationalizing:

| Thought | Reality |
|---------|---------|
| "This is just a simple question" | Questions are tasks. Check for skills. |
| "I need more context first" | Skill check comes BEFORE clarifying questions. |
| "Let me explore the codebase first" | Skills tell you HOW to explore. Check first. |
| "I can check git/files quickly" | Files lack conversation context. Check for skills. |
| "Let me gather information first" | Skills tell you HOW to gather information. |
| "This doesn't need a formal skill" | If a skill exists, use it. |
| "I remember this skill" | Skills evolve. Read current version. |
| "This doesn't count as a task" | Action = task. Check for skills. |
| "The skill is overkill" | Simple things become complex. Use it. |
| "I'll just do this one thing first" | Check BEFORE doing anything. |
| "This feels productive" | Undisciplined action wastes time. Skills prevent this. |
| "I know what that means" | Knowing the concept ≠ using the skill. Invoke it. |

## Skill Priority

When multiple skills could apply, use this order:

1. **Process skills first** (brainstorming, debugging) - these determine HOW to approach the task
2. **Implementation skills second** (frontend-design, mcp-builder) - these guide execution

"Let's build X" → brainstorming first, then implementation skills.
"Fix this bug" → debugging first, then domain-specific skills.

## Skill Types

**Rigid** (TDD, debugging): Follow exactly. Don't adapt away discipline.

**Flexible** (patterns): Adapt principles to context.

The skill itself tells you which.

## User Instructions

Instructions say WHAT, not HOW. "Add X" or "Fix Y" doesn't mean skip workflows.
sdlc collects ariadne's SDLC checkpoint guards into one binary. Each subcommand
owns one checkpoint: it requires evidence at the gate, mutates state, logs the
transition, and refuses transitions that lack it. We don't model the SDLC as a
state machine — stages stay prose; we codify the gates between them where drift
recurs. `sdlc` manages the development life cycle; prefer it over `git`/`gh`.

BEFORE WORK
  - `sdlc claim --issue N` — the single start-of-work gesture, a CHEAP LOCK.
    Flips an *open* issue to `working` and publishes the claim to origin/main so
    peer agents see it. No estimate demanded (#113) — claim early, the moment an
    idea crystallizes. `--no-start` suppresses the flip.
  - Do NOT hand-edit an issue's `status:` — let `sdlc claim` or `sdlc issue
    set-status` own that transition (it carries the reopen/`→ done` guards).

ENTER IMPLEMENTATION
  - After plan approval, before editing code, run `sdlc change-code`. It owns the
    branching decision (in-place branch by default; `--worktree=yes` for an
    isolated worktree), the plan-quality check, and the `estimate_hours` gate
    (relocated here from claim, #113). Don't start coding without it.

PUBLISH
  - Publishing goes through a PR: `sdlc pr` → `sdlc merge`. Direct `sdlc push`
    if working directly on main.
  - Publish ONCE at issue close, not per milestone — and do NOT reuse a branch
    name that already has a merged PR. `sdlc merge` refuses (#148) when a branch
    has commits not in main despite a merged PR (a reused name would otherwise
    silently strand the new commits); rename to a fresh branch, `sdlc pr`, retry.

RECOVER
  - After a compaction or session resume, run `sdlc state` to recover where you
    are instead of re-inferring from issue files.

LOCAL REPO TRANSACTION LOCK
  - Mutating verbs take an SDLC-owned repo transaction lock at
    `.git/sdlc.lock` before reading/writing issue state, committing, changing
    branches, or pushing. The lock is local to the Git common dir, so linked
    worktrees of the same repo serialize with each other.
  - Wait messages identify the holder pid and command when metadata is
    available. `close` and `milestone-close` release the lock while the external
    boundary-review subprocess runs, then reacquire before finalization; if HEAD
    or the issue/project file state they prepared changed meanwhile, they refuse
    to finalize and tell you to rerun. `change-code`, `merge`, and `push` can still hold the lock during
    long-running review/ship transactions; wait or retry rather than removing
    the lock while that process is alive.
  - A dead same-host holder is reclaimed automatically; initializing metadata
    is waited through. Other stale/timeout errors tell you how to inspect
    `.git/sdlc.lock`. Remote push/ref races are separate: the local lock
    serializes this checkout, not another machine or clone.

WHEN A VERB ERRORS
  Do NOT route around it with hand-rolled `git`/`gh`. Its errors are next-action
  specs. The fix is one of two things:
    (a) satisfy the precondition it names and re-run the same verb (e.g. `sdlc
        merge` saying "no upstream" → run `sdlc pr` first, then `sdlc merge`); or
    (b) if the error is a genuine gap in `sdlc` itself, fix that edge case in the
        source and re-run. We're still ironing out edge cases.
  Only drop to manual when a verb genuinely cannot express the need — say so.

These gates sit inside a wider prose arc the binary does NOT own: ideation
(parley/pensive) → brainstorm → plan → build → milestone review (`sdlc judge`,
auto-dispatched) → close/ship → postmortem.

CONVENTIONS

  --issue vs --github-issue — `--issue N` always means workshop/issues
  (6-digit ID). `--github-issue N` means a GitHub issue number. Bare `--issue`
  never means a GitHub issue.

  Form vs essence — checkpoint guards (close, milestone-close, push, merge)
  defend against *omission* via required-evidence flags; `sdlc judge` defends
  against *theater* via fresh-context review. Form runs first; judge second.

The verb list + per-verb help (`sdlc <verb> --help`) follow below.

Usage:
  sdlc [flags]
  sdlc [command]

Available Commands:
  claim           Start work: flip an open issue to working + broadcast the claim
  start-plan      Enter planning: deliver the architecture principles to design against (#75)
  change-code     Enter implementation after the structural + plan-quality gates
  issue           Create + manage issues (new / set-status / list / show)
  actual          Compute an issue's focused dev-hours via active-time-v3 (#68)
  active-time     Per-issue active-time attribution table (the v3 engine, standalone)
  close           Close an issue or milestone (ACTUAL + VERIFIED + atlas/project sweep)
  milestone-close Close one milestone + auto-dispatch its review
  pr              Open a pull request from a feature branch
  merge           Merge the PR, archive done issues, clean up
  push            Ship from main (clean tree + pre-merge judges + archive)
  state           Inspect workflow state (branch, working issues, drift)
  resolve         Resolve a symbolic artifact ref (ariadne#11, #15 M4) to its current path(s) — read-only
  open            Resolve a ref and open the primary artifact in $EDITOR
  judge           Run an LLM-judge check against the diff (fresh-context)
  arch-principles Print the ARCH-* architecture principles (single source; pull for non-gate work)
  estimate-source Name the shared estimate method + the repo-local calibration source (pull)
  process-manual  Unroll every injection source into a linked process manual (#153)
  propagate-base  Re-weave every recursive dependent of this repo (foundation-first)
  help            Help about any command

Flags:
  -h, --help   help for sdlc

Use "sdlc [command] --help" for more information about a command.
# Lessons

## 2026-06-10
- A config→data mapping written as an inline IIFE/closure in glue code is invisible to tests — a dropped or typo'd key silently degrades behavior. Extract it to a small *pure* named helper (`f(cfg) -> data`) and unit-test the mapping. (#127: the `chat_boundaries` prefix list started as an inline closure in `chat_respond`; the boundary review flagged the untested surface.)
- Pure-but-IO-adjacent helpers belong in the *pure* module taking the config table as a param, not requiring config — keeps the core testable while quarantining the field-name knowledge in one place.
- A template placeholder added for one creation path must be rendered through a shared helper before touching call sites. #135 added `{{status}}` to `ISSUE_TEMPLATE` and updated `create_issue`, but `cmd_issue_decompose` still called the template directly; the boundary review caught child issues that would be written with literal `status: {{status}}`. Rule: when a template gains a placeholder, grep every direct template use, extract one renderer, and test the renderer with a non-default/fake value so every creation path proves it uses the same substitution.

## 2026-06-26
- Any tool that shells out with LLM-controlled inputs must use argv-list execution and typed validation for every field before process launch. Shell-quoting only some fields is not enough: unquoted numeric/count fields can reintroduce command injection even when pattern/path strings are quoted. After hardening one shell-out family, run a sibling-tool sweep for `vim.fn.system(<string>)` and either fold matching tools into scope or file a follow-up immediately.

## 2026-05-30
- **A "line-bounded" parser's line bound is often a load-bearing blast-radius cap, not just a limitation.** `parse_markers` was line-bounded only because it fed `parse_marker_sections` one line at a time — `find_matching_bracket` itself already scanned across `\n` (drill_in relied on that). So "make it multi-line" was really "stop slicing per-line + add a bound back in." Before removing a bound that looks accidental, ask what it was silently protecting: here, an unmatched `🤖{` could only ruin one line; unbounded it would swallow to EOF. The fix kept the protection as an explicit per-section newline budget (#125).
- **Extend a shared parser via an optional opts arg that defaults to the historical behavior — then existing callers are provably untouched.** `find_matching_bracket(text, start, open, close, opts)` with `opts.budget`/`opts.is_excluded`; `opts or {}` → `budget == nil` → unbounded, exactly as before. Only the new caller (`parse_markers`) opts in. This sidesteps the lesson-#7 trap (2-arg call sites silently losing a new return) because there's no new *return* and no signature change at the call sites — highlighter and drill_in still pass 3 args. Grep-confirm the call sites anyway.
- **When a per-iteration budget resets, the per-marker total ≠ the budget.** A reviewer caught that the 50-line ceiling resets at each opening bracket, so a well-formed `🤖<…>[…]{…}` can span ~150 lines even though each *section* is ≤50. The runaway guarantee (a single *stray* opener is bounded) still holds, but the comment/docs claiming "~50 lines per marker" were wrong. Name the unit precisely in comments ("per section") and pin it with a test so nobody "tightens" it into a per-marker cap later.

## 2026-05-07
- **A parser shared across two semantic layers can hide an ambiguity for months.** The `🤖` marker family was used by two features (review skill / drill-in) with overlapping syntax (`🤖{T}[Q]` vs `🤖{agent}[user]`). The parser couldn't distinguish them, so each caller patched its own "is this drill-in?" heuristic (drill_in: "first section is non-empty `{}`?"). When you spot a caller-side disambiguator like that, a *third syntactic slot* (here: `<>`) is usually cleaner than a smarter heuristic. #123 introduced `<T>` as the unambiguous quoted-body marker; the heuristic disappeared and the whole strip pipeline simplified. Rule: if two callers of the same parser need to read the same parsed shape differently, the grammar is wrong, not the callers.
- **`find_matching_bracket` only depth-tracks one bracket pair.** When extending a bracket-based grammar with a new pair (`<>`), test cross-pair interactions: `🤖<a [b> c]` parses with quoted = "a [b" because the `>` inside `[]` still closes the `<>`. If that's acceptable, **pin the behavior with a test** so a future "fix" doesn't silently change it. If not, write a parser that maintains a stack across all bracket kinds.
- **Normalize empty-vs-absent at one boundary.** Parser produced `quoted = { text = "" }` for `🤖<>[U]`. Every downstream consumer (gather/strip/format/resolve) had to choose: treat empty as a real quote or ignore it? Picking *one* normalization site (drill_in.M.parse → `quoted = nil` when empty) lets every caller stay simple. Doing it at the parser level would be wrong (review may want to see the empty `<>` as parser truth); doing it at each consumer is duplicated logic. Drill-in is the *interpretation* layer — that's where the normalization belongs.
- **Adding a third return value to a shared API is silently lossy at 2-arg call sites.** `_parse_marker_sections` went from `(sections, end_pos)` to `(sections, end_pos, quoted)`. Lua truncates extra returns at assignment sites, so existing callers (`local sections, end_pos = parse(...)`) keep compiling and silently miss the new info. Grep every caller and decide explicitly whether to ignore or consume the new return. Caught the highlighter via grep; missing it would have meant `<T>` spans never highlighted.

## 2026-05-04
- **Vim ex-commands that take an implicit current-buffer arg (`:undojoin`, `:write`, `:edit`, etc.) silently target the wrong buffer when called from async/scheduled callbacks.** `helpers.undojoin(buf)` accepted a buf param but called `vim.cmd.undojoin` directly — `:undojoin` operates on the current buffer, ignoring the param. The streaming path looked like it worked because users stay focused on the chat buffer during streaming; the longer-cadence spinner timer was more likely to fire during transient focus changes (autocmds, window switches), and its joins silently went to the wrong buffer. Fix: wrap in `vim.api.nvim_buf_call(buf, function() vim.cmd.undojoin() end)`. Rule: any helper that takes a `buf` parameter and dispatches a Vim ex-command must use `nvim_buf_call` — passing the param to the helper without enforcing buffer context is a contract the helper isn't actually upholding. Spotted in #80 second-pass debugging.
- **Sanitized snapshot in `M.get_agent` (init.lua:3570) is an allow-list, not a passthrough.** Every new field added to the agent config schema must also be appended to this snapshot, or it is silently dropped before `agent_info.resolve` ever sees it. This bit #81 (tools/max_tool_iterations/tool_result_max_bytes) and bit #118 again (synthetic_system_prompt/synthetic_system_prompt_ack) — same vector. Rule: when adding a new agent-config field, grep for `M.get_agent = function` and add it there too; ship a regression test that walks `agent record → get_agent → get_agent_info → final usage` (see `tests/unit/config_tools_spec.lua` "get_agent forwards synthetic_system_prompt config" for the pattern).

## 2026-04-27
- **`string.gsub` returns 2 values; `table.insert(t, str:gsub(...))` blows up.** Lua expands the last argument of a call to all its return values. So `table.insert(out, "abc":gsub("c","d"))` passes three args (`out`, `"abd"`, `1`) and triggers `bad argument #2 to 'insert' (number expected, got string)` because the 3-arg form expects `(table, pos, value)`. The bug is silent in single-value contexts (`local x = s:gsub(...)`, concat with `..`) but bites the moment you pass the result through a variadic-aware API. Fix: bind to a local first (`local out = s:gsub(...); return out`) or wrap in parens (`return (s:gsub(...))`). Same shape applies to any function returning multiple values that ends a call's argument list.

## 2026-04-11
- **AGENTS.md overrides skill boilerplate.** The `writing-plans` skill template includes "REQUIRED: Use superpowers:subagent-driven-development" in plan headers. AGENTS.md explicitly says "Do NOT default to skills like `superpowers:subagent-driven-development`." User instructions are highest priority per the skill priority chain. Always check AGENTS.md for conflicts before copying skill boilerplate into artifacts.
- **In autocmd callbacks, use `nvim_buf_get_name(buf)` not `ev.file`.** `ev.file` can be a relative path when the user opened the file with a relative path (e.g. `nvim workshop/file.md`). `nvim_buf_get_name(buf)` always returns the absolute path. This caused `not_chat()` to fail silently because `find_chat_root` couldn't match the relative path against configured roots.
- **After `nvim_buf_set_name` + rename, do `write!` then `edit!`.** `nvim_buf_set_name` marks the buffer as a "new file" at the new path. Without `edit!` to reload, the next manual `:w` warns "file already exists". The `write!` forces the initial write, and `edit!` clears the new-file flag.

## 2026-04-10
- **The exchange_model is the ONLY source of truth for buffer positions.** NEVER compute positions by scanning lines, using foldexpr with backward lookups, or querying `foldlevel()`. The model knows every block's kind, size, start, and end. Any feature that needs positional information (folding, highlighting, insertion, deletion) MUST use the model. This was violated 4 times in one session: foldexpr with backward scan, foldlevel() dependency, `last_content_line()` for prompt append, re-parsing buffer on recursive calls. Every time, the model-based approach was simpler and correct.
- **Don't commit before user tests.** When fixing a bug that requires manual verification (especially buffer layout, margins, folding), wait for user confirmation before committing. Premature commits require reverts and pollute git history.
- **Lua empty table `{}` encodes as JSON `[]` (array), not `{}` (object).** Use `vim.empty_dict()` when an empty dict is required (e.g., Anthropic tool_use.input). This bit us when `parse_call` returned empty input for condensed tool blocks.
- **Parser's `line_start`/`line_end` must not include margins.** Trailing and leading blank lines are margins owned by the model, not block content. The parser must trim them so `from_parsed_chat` computes correct sizes. Also applies to `🧠:`/`📝:` lines — they must be fed to `cb_append_line` so the content_blocks state machine tracks them.

## 2026-04-09
- Parley test files hardcode `/tmp/parley-*` paths (`dispatcher_spec.lua:7`, `tree_export_spec.lua:22`, etc.). Under Claude Code sandbox, `/tmp` is narrowed to `/tmp/claude` regardless of user `allowWrite` config, so all these tests fail at setup with `Vim:E739: Cannot create directory`. Fix: use `vim.fn.tempname()` or `os.getenv("TMPDIR")` instead of hardcoded `/tmp/` — it's both sandbox-friendly AND more portable. Tracked for future cleanup (not in #81 scope).
- When adding ONLY new files (no modifications to existing code), regression risk in untouched modules is zero. A full `make test` regression gate is belt-and-suspenders, not load-bearing — individual file verification suffices if you can't run the full suite.
- **Never have two code paths (legacy + new) coexisting in the same function for the same operation.** #90 attempted to add a model-based insert path alongside the legacy absolute-line path in `chat_respond.M.respond`. The two paths shared closure variables (`response_line`, `progress_line`) and produced conflicting buffer states. THREE rounds of "targeted fix" attempts each made things worse. Rule: if you're replacing an algorithm, REPLACE it — don't add a parallel path gated by a condition. The old path must be deleted, not left as a fallback.
- **Use SIZE not POSITION for tracking buffer layout.** Absolute line numbers are invalidated by any insert/delete. Size-based models (exchange_model.lua) compute positions on demand from accumulated sizes, so they're always correct regardless of concurrent edits. When building buffer-mutation infrastructure, make the model the single source of truth and have callers ask "where does section K go?" rather than computing offsets themselves.
- **When adding a new state to code that already has fragile line-offset arithmetic, refactor first — don't stack another branch.** #81 M2 Task 2.7 needed to insert a tool-loop recursion branch into `chat_respond.M.respond`'s imperative line-position chain (`response_line / response_block_lines / progress_line / response_start_line / raw_request_offset`). Each new branch added an `if recursion then +1 else +3` magic-number offset. Three manual test rounds, three distinct offset bugs (progress_line mismatch, stuck-spinner cleanup failure, suspected buffer-state corruption causing an Anthropic "assistant message prefill" rejection on a payload that looked spec-correct). The third bug was the trigger to stop patching and refactor — filed #90 to extract a pure `exchange → lines` + `positions` layer with a single mutation entry point. Rule: when you notice you're adding the Nth `+K vs +M` branch to the same code path, stop and refactor. The cost of one refactor < the cost of N+1 offset patches + the debug sessions between them.
- **Integration tests at the wiring layer catch bugs unit tests cannot.** During #81 M1 Task 1.8 manual verification, `M.get_agent()` was found to return a sanitized agent snapshot without the `tools`/`max_tool_iterations`/`tool_result_max_bytes` fields. Each hop was unit-tested in isolation (`get_agent_info` with a fake agent table that already had `tools`; `prepare_payload` with an explicit `agent_tools` arg) but no test exercised the full chain `M.agents → get_agent → get_agent_info → prepare_payload`. The bug was caught only by inspecting a real query cache JSON after a real user interaction. Rule: for any multi-hop data flow through module boundaries, write at least one test that exercises the FULL chain with the actual modules wired up, not just mocks at each hop. For any field added to an entity (here: `agent.tools`), grep all the read-sides (functions that build derived objects from the entity) and verify each forwards the field.

## 2026-03-07
- No escaped-quote init in Makefile recipes — use newline-producing helpers + `for` loops
- Run new Make targets against real inputs before closing

## 2026-03-08
- Run `make test-changed` after spec doc changes
- Verify provider capabilities against provider's own docs
- Capability rules go in `provider_params.lua`, not transport code
- Write plan in `tasks/todo.md` before non-trivial work
- Run `make lint` after every change; warnings = failures

## 2026-03-09
- Fast-event callbacks: no direct `nvim_*` APIs — use `vim.schedule`
- Progress UI must handle `reasoning_content` not just tool events
- Normalize provider progress events to shared shape (`kind`/`phase`/`message`)
- Propagate raw progress text for display, not just coarse labels
- `git stash` changing behavior = strong causality signal — diff the stash
- Prefer semantic header keys (`system_prompt`) over overloaded ones (`role`)
- Global whitespace trim can eat required terminal newlines — handle post-trim
- When one path is fixed, narrow focus to remaining failures
- Bottom-anchored picker: verify `scrolloff` + buffer line count, not just window height
- Separate initial placement logic from keyboard navigation scrolling

## 2026-03-11
- UI bugs in live-only: add runtime tracing, don't stop at unit tests
- Bottom-anchored pickers: verify visual-row vs logical-index mapping

## 2026-03-13
- ChatFinder move bugs: instrument full lifecycle in live path, not just helpers

## 2026-03-25
- Read the full existing implementation before adding a variant
- Always handle `~/` expansion in file path resolution
- Strip empty-content messages before sending to LLM — Anthropic rejects them
- Sanitize inputs when extracting reusable functions (strip `cache_control`, etc.)
- Programmatic buffer inserts don't fire `BufEnter` — trigger renders manually
- `x or {}` default eats `nil` — use sentinel if nil has meaning
- Cross-file picker nav: use `edit` not `split`, clamp cursor to line count
- After `edit`, use `nvim_get_current_buf()` not stale buffer variable

## 2026-03-28
- Float picker is insert-mode — only `<C-*>` and arrow keys work as actions
- Don't nil-guard broken state — fix the caller instead
- Chat file paths must be relative to containing file, not cwd — use `:t` not `:~:.`
- New keybindings must use config-driven mechanism (`chat_shortcut_*` in config.lua + `M.cmd.*`) — don't copy hardcoded patterns

## 2026-03-29
- Picker tests: don't assert mappings by numeric index (`mappings[2]`) — indices shift when new mappings are added. Look up by key name instead
- `GROUPS` is a bash built-in variable (user's group IDs) — never use it as a custom variable name. Same caution for `RANDOM`, `SECONDS`, `LINENO`, etc.
- `flock` is Linux-only — use `mkdir` for cross-platform locking (atomic on macOS and Linux)
- `claude -p` in background/piped processes needs `< /dev/null` to avoid stdin timeout warnings
- `claude -p` without `--permission-mode bypassPermissions` may silently fail when tools need approval but no TTY is available
- Parallel agents sharing a git working directory: don't use `git status` diff to detect changes from one agent — other concurrent agents may have modified files too
- `timeout` is GNU coreutils — not on macOS. Use `perl -e 'alarm shift; exec @ARGV'` as portable fallback
- `wait -n` requires bash 4.3+ — macOS ships bash 3.2. Use `kill -0` polling instead
- When a subprocess fails silently and its empty stdout is treated as "success", the feature appears to work but does nothing — always check exit codes or validate output isn't vacuous

## 2026-04-06
- Don't use `git stash` mid-task to "verify lint baseline." Pre-existing stashes in the sandbox can collide with the pop and corrupt unrelated files (Makefile got merge markers, broke `make`). To check whether warnings/errors are pre-existing, run lint on a clean clone in /tmp or just compare the warning *count* against `git show HEAD:<file>` — never disturb the working tree.

## 2026-06-17
- **When deleting/renaming a module, the atlas-sync merge gate catches stale refs a name-grep misses — reconcile EVERY atlas page, including behavioral descriptors.** Across #128 M2/M3/M4 the `sdlc merge` atlas-sync judge blocked 4× on stale atlas text that survived a `grep <module-name> atlas/`. The misses were *behavior* lines, not the module name: `atlas/modes/review.md` still said "pre/post hooks" / "shared pipeline" / ":checktime reload" after those were deleted, and `traceability.yaml` listed phantom specs (`tools_builtin_glob_spec`) renamed long ago. Rule: when a change deletes/renames a surface, grep `atlas/` for BOTH the old name AND the behaviors/tools it owned (`hooks`, `pipeline`, the old tool name, the reload verb), and walk every mode-specific page + the `## Key Files` / traceability lists — not just the primary atlas doc. Cheaper to sweep up-front than to round-trip the merge gate.

## 2026-06-30 (#116)
- **A sandbox push/network failure is NOT "can't push" — retry with the sandbox DISABLED.** `git push`/`sdlc pr`/`sdlc merge` failing with `nc: authentication method negotiation failed` (or any SSH/network/auth error) is the Claude Code sandbox blocking the *transport*, not a hard limit. Per the Bash-tool rule, retry the network op with the sandbox off (`dangerouslyDisableSandbox`) — it uses the real network/auth. This session I treated repeated push failures as a hard block and tried to hand the whole merge back to the operator; the moment I retried `git push` unsandboxed it worked, and the full `sdlc pr → merge` flow completed. Don't conclude "can't" from a sandbox network error; the *filesystem* sandbox is narrow (see the `/tmp` lesson) but network is retryable unsandboxed.
- **Read `sdlc --help` (the workflow contract) UP FRONT — CLAUDE.md says "Read it NOW," and most SDLC surprises come from skipping it.** It lays out the whole arc (claim → `change-code` → implement → `milestone-close` per Mx → `close` → `pr` → `merge`) and the exact gotchas: PUBLISH is **`sdlc pr` → `sdlc merge`** (merge is server-side `gh pr merge` of *origin's* tip, so it needs a pushed branch AND an existing PR), and "a verb's errors are next-action specs" (e.g. `merge` "no upstream" → run `sdlc pr` first). This session I tried `sdlc merge` before `sdlc pr` and was surprised the merge was server-side — all answered in the contract I hadn't read.
- **`sdlc milestone-close` runs the boundary review; `sdlc close --milestone Mx` does NOT** (it's the documented no-auto-judge escape). For a *reviewed* milestone close, use `milestone-close`. This session I ran `close --milestone` first — it ticked the box + logged but silently skipped the mandatory fresh-context review. (Lives only in `sdlc close --help`, not the top-level contract.)
- **Merge CODE at issue close, not per milestone — and never reuse a branch name that already has a merged PR.** The normal model (cf. #133's seven milestones on one branch) is one branch per issue, all milestones on it, a single `sdlc pr → merge` at the end; `milestone-close` is a *local* review boundary (+ issue-sync of the tracker to main), NOT a code merge. #116 deviated: M1 shipped early via PR #95 (a prior session, to unblock #128), so when M2/M3 reused the same issue-slug branch name months later, `sdlc merge` found the merged #95 and "resumed post-merge cleanup" (switched to main, deleted the branch) WITHOUT merging the 16 new commits — they were safe on `origin`, absent from main. Rule: don't merge per milestone; if a milestone genuinely must ship early (cross-issue unblock), the continuation needs a FRESH branch name. After any merge, `git rev-list --left-right --count main...origin/<branch>` to confirm main actually advanced.

## 2026-07-01 (#155)
- **When two code paths feed a shared, tested core, the per-path GLUE still needs its own coverage — a shared-core test does not cover the seam.** #155 consolidated two message emitters into one pure `_emit_content_blocks_as_messages` and I tested it thoroughly (6 direct cases) plus the parse path (1 integration). But `build_messages_from_model` (the live/recursion path) has its own *normalization seam* — buffer read + `serialize.parse_call`/`parse_result` + malformed→text degrade — that I left with **zero** coverage, reasoning "the invariant is tested in the emitter." The close review flagged it Important: a regression in that seam (a dropped/mis-ordered block never reaching the emitter) would ship silently. Rule: after extracting a shared tested core, enumerate every *caller's* normalization/glue seam and give each an end-to-end test through the real entry point (for the live path: build a real buffer + `exchange_model` with positions driven by the model's own `block_start`, call the entry fn, assert the payload). ARCH-PURPOSE covers the core; the seams are separate deliverables.
- **De-duplicating two parallel implementations surfaces latent divergences — treat each difference as a suspected bug, not noise.** The two emitters diverged on empty tool input: the model path coerced `{}`→`vim.empty_dict()` (JSON `{}`) while the parse path emitted a bare `{}` (JSON `[]`, which Anthropic rejects for `input`). The divergence *was* a latent bug; consolidating to one source fixed it for free. When you unify copy-paste siblings, diff their behavior line-by-line and fix the discrepancy at the single source rather than picking one arbitrarily.
- **Never `git add -A` / `git add .` in a shared working tree — stage explicit paths.** In #157 `git add -A` swept an unrelated *untracked* user-WIP issue stub (`000158-…`) into my refit commit; the `sdlc merge` instance-conformance gate then blocked on that stub's empty `## Plan`/`## Done when`. The user (and peer agents) leave untracked files in `workshop/issues/` mid-session, so a blanket add captures work that isn't yours. Recovery: `git rm --cached <file>` + a removal commit keeps the file locally (untracked, WIP preserved) while dropping it from the branch's net `base..HEAD` diff so the gate passes. Rule: stage the exact paths you changed (`git add lua/... tests/... workshop/issues/<your-issue>.md`), and before committing run `git status --short` to eyeball for `??` files you didn't create. (Same "commit only my files" care the #155 ariadne-side commit needed.)

## 2026-07-05 (#160)
- **Run the FULL `make test` (lint + unit + integration) before claiming "suite green" in `--verified` — running specs individually skips the lint gate.** This session I ran each `PlenaryBustedFile` spec directly (all green) and wrote "go test/full suite green" in the close evidence — but never ran `make test`, whose FIRST target is `lint` (luacheck). A new `while pos <= #line do` (every branch returns → luacheck 542 "loop executed at most once") failed luacheck, so `make test` was RED at the gate while my Log claimed green. The boundary review caught it (FIX-THEN-SHIP), but nothing *prevented* the premature claim. Rule: the evidence for "green" is a full `make test` exit 0, not a hand-picked set of specs; individual `PlenaryBustedFile` runs are for the red→green TDD loop, not the final gate. (Bonus: luacheck flags a `while` whose body always returns — use `if` and let the iterator's repeated closure-calls do the looping.)
- **A decoration-provider highlight's column math deserves a pure, tested helper — don't bury `col_start=s-1, col_end=e-1` inline in an untestable local.** The `push_artifact_refs` extmark columns (off-`iter_refs`' one-past `e`) were an off-by-one-prone conversion inside a `local function` in `highlighter.lua` (ephemeral extmarks, awkward to assert). The review flagged it Important. Fix: extract `artifact_ref.highlight_spans(line)` (pure, returns the exact 0-indexed `{col_start,col_end}`) and unit-test the columns against the literal ref text (`line:sub(col_start+1, col_end) == "ariadne#11"`, incl. the interior-space `#15 M4`); the highlighter consumes it. Pure col math + a direct assertion beats trying to test the decoration provider's redraw output.

## 2026-07-07 (#161)
- **A pure helper that consumes another module's output must have ONE test against that module's REAL output, not only synthetic inputs.** `define.context_for_selection` reads `parse_chat` fields (`ex.question.line_start`, `ex.answer.line_end`). I unit-tested it thoroughly — but only with a *synthetic* `parsed_chat` table + an injected `finder`, and the one integration test that reached the real `parse_chat` used a buffer with no exchanges (so it hit the whole-buffer fallback, never the sliced-exchange branch). Net: the field-name contract with the live parser had zero coverage — a rename in `parse_chat` would silently degrade define to whole-buffer context with green tests. The boundary review flagged it Important. Rule: injecting a dependency (finder/parser) to keep a helper pure is right, but add exactly one end-to-end case that feeds the helper the REAL producer's output and asserts the field access still works. (Same shape as the #155 "shared core tested, caller's glue seam untested" lesson — the seam here is the field-name contract.)
- **Raw `nvim_buf_set_text` is arch-forbidden (empty allow-list in `tests/arch/buffer_mutation_spec.lua`); `nvim_buf_set_lines` is allowed in `init.lua`.** #90's buffer-mutation boundary confines span edits to `buffer_edit.lua` (set_text allow-list is `{}` = zero uses). My first R1 cut used `nvim_buf_set_text` for the `[term]` wrap → `make test` red on the arch spec (lint was clean, so I only caught it at the full-suite run, not the unit loop). Fix: wrap via `nvim_buf_set_lines` (rewrite the affected whole line(s)) — the same primitive `drill_in_visual` already uses to wrap a selection, and it's on the set_lines allow-list for `init.lua`. Rule: before reaching for `nvim_buf_set_text`/`set_lines` in a non-`buffer_edit` file, check `tests/arch/buffer_mutation_spec.lua` — prefer the set_lines whole-line rewrite that existing wrappers use.
- **To make a decoration-only action undoable, anchor it to a text edit + reuse `projection` — `u` reverts text, never extmarks/diagnostics.** The operator wanted the define highlight+diagnostic undoable; native `u` can't touch pure decorations (review's are undoable only because a round edits text). Resolution: a minimal text edit (now the durable `[^id]` footnote reference/footer) as the anchor + reuse `skills/review/projection.lua` (`record_empty_for(pre)` + `record(post)` + `ensure_watch`). `skill_render.snapshot`/`apply_snapshot` now preserve both whole-line highlights and column spans, so the projection can restore exact term/reference decorations. In headless tests, `:undo` does NOT fire `TextChanged` — `nvim_exec_autocmds("TextChanged", {buffer=buf})` to drive the projection watcher deterministically.

## 2026-07-08 (#166)
- **Any action that can be repeated on its own output needs an idempotence test, not only an update test for the secondary data.** #166 tested that re-defining a term updated the managed footnote line, but the selected text transform still blindly appended `[^id]`, so selecting `ASIN` in `ASIN[^asin]` produced `ASIN[^asin][^asin]`. The close review caught the gap. Rule: when a feature creates both an inline reference and an external/durable record, add a repeat-on-rendered-output test that proves the inline reference is not duplicated while the external record updates.

## 2026-07-08 (#167)
- **A behavior-only fix can still require atlas if an atlas page explicitly describes that behavior.** #167 changed define highlights from whole-line to span-scoped and taught projection snapshots to preserve columns; the code and tests were right, but `atlas/chat/inline_define.md` still said whole-line/line-granular. Rule: before using `--no-atlas`, grep atlas for the feature name and the old behavior terms (`whole-line`, `line-granular`, helper names, key data fields). If any atlas page states the old behavior, update it in the same commit even when no new module or command was added.

## 2026-07-08 (#169)
- **When centralizing a policy, delete caller-local defaults that can bypass it.** #169 routed review and define diagnostics through `skill_render.format_diagnostic_message`, but `define.format_definition` still passed `width or 80`, preserving an old fallback and weakening the shared width policy. Rule: after adding a shared formatter/config helper, grep every caller for old fallback constants and add a test for the nil/default path so future callers inherit the central behavior.

codex
Using `sdlc` for the boundary-review workflow and the code-review stance from the user prompt. I’ve read the workflow contract and am now checking the issue/plan against the live diff and tests.
exec
/bin/zsh -lc "sed -n '1,220p' /Users/xianxu/workspace/ariadne/construct/local/sdlc/SKILL.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
---
name: sdlc
description: Use when at an SDLC checkpoint — starting work, closing an issue or milestone, opening/merging a PR, or recovering workflow state after compaction. The `sdlc` binary owns the gates between workflow stages and refuses transitions that lack required evidence.
---

# sdlc — SDLC checkpoint binary

`sdlc` owns the gates between SDLC workflow stages (claim → change-code → pr →
merge, plus close, milestone-close, judge). It requires evidence at each gate,
mutates state, logs the transition, and refuses transitions that lack the
evidence — that is the shape of a "checkpoint guard."

The binary is the single source of truth. This skill is a static pointer and
intentionally carries no copy of the contract, so it can never drift:

- **`sdlc --help`** — the workflow contract: the start-of-work runbook,
  conventions, and the verb list.
- **`sdlc <verb> --help`** — one checkpoint's full contract, flags, and examples.

Read those instead of relying on memory; the binary's help is always current.

exec
/bin/zsh -lc "sed -n '1,240p' workshop/issues/000173-diagnostic-virtual-lines-leftcol.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
---
id: 000173
status: working
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 0.38
started: 2026-07-08T13:21:02-07:00
---

# diagnostic virtual lines blank on long wrapped markdown

## Problem

After #172, managed markdown footnotes are correctly restored as diagnostics,
but their inline virtual-line display can look blank on long wrapped markdown
paragraphs. The diagnostic payload is present and floats display it, but
Neovim's built-in `virtual_lines` handler prefixes the rendered message with
spaces equal to the diagnostic byte column. On a long prose line, the selected
text may be visible on a wrapped screen row while the virtual-line message starts
far to the right outside the viewport.

## Spec

- Parley diagnostics should remain anchored on the selected text / `[^footnote]`
  span so signs, underline, cursor-line filtering, jumps, and floats keep their
  existing behavior.
- The inline diagnostic display for Parley's namespace should render current-line
  messages from the left column, not from the diagnostic byte column.
- The display text should keep the existing wrapped diagnostic message and a
  clear `Diagnostics:` label.
- The fix should apply to the shared Parley diagnostic namespace, covering review
  diagnostics and footnote diagnostics without changing global/LSP diagnostics.

ARCH-DRY: keep one Parley diagnostic display controller in
`skills/review/diag_display.lua`; do not add a separate footnote-only renderer.
ARCH-PURE: no parser/data changes; keep the change in the thin Neovim display
shell and test its extmark output directly.
ARCH-PURPOSE: solve the actual blank-row symptom for long wrapped markdown, not
only color the hidden text.

## Done when

- A Parley diagnostic on a long line with a high column renders a visible
  left-column virtual line.
- The diagnostic itself remains at its original span for underline/float/jump
  behavior.
- Toggling `:ParleyShowDiagnostics` still disables/enables the inline display.
- Focused tests and full verification pass.

## Estimate

Produced via `estimate-logic-v3.1` against the repo-local calibration source
reported by `sdlc estimate-source` (stale but canonical for this repo).

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.04 impl=0.00
item: lua-neovim design=0.06 impl=0.18
item: milestone-review design=0.00 impl=0.10
total: 0.38
```

## Plan

- [x] Add failing tests proving Parley virtual lines render from the left column.
- [x] Implement the Parley-owned virtual-line display handler.
- [x] Update atlas/issue log and run verification.

## Log

### 2026-07-08
- Root cause: a headless reproduction of Neovim's stock diagnostic virtual-lines
  handler showed `virt_lines = { { { string.rep(" ", diagnostic.col), "" }, ... } }`
  with `virt_lines_overflow = "scroll"`, so long wrapped markdown can display a
  blank inserted row while the message starts outside the viewport.
- Red test: `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"`
  failed because `diag_display` still configured stock `virtual_lines` and no
  `parley_diagnostic_virtual_lines` extmark was rendered.
- Implemented `parley/virtual_lines`, a custom diagnostic handler scoped to the
  Parley namespace. It renders a left-column `Diagnostics:` virtual-line block,
  updates on `CursorMoved`, disables stock virtual lines for Parley, and leaves
  the underlying diagnostic span unchanged.
- Focused green: `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"`.
- Final green: `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`;
  `git diff --check -- lua/parley/skills/review/diag_display.lua
  tests/integration/review_diag_display_spec.lua atlas/modes/review.md
  atlas/chat/inline_define.md
  workshop/issues/000173-diagnostic-virtual-lines-leftcol.md
  workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md`; `make test`.

exec
/bin/zsh -lc "sed -n '1,220p' workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
# Diagnostic Virtual Lines Left Column Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Parley's inline diagnostic display visible on long wrapped markdown lines by rendering diagnostic virtual lines from the left column.

**Architecture:** Keep diagnostic data unchanged: spans stay anchored to selected text and footnote references. Replace only Parley's namespace display shell in `diag_display.lua`, so global/LSP diagnostics still use Neovim defaults. This follows ARCH-DRY by keeping one Parley display controller and ARCH-PURE by avoiding parser/data changes.

**Tech Stack:** Lua, Neovim diagnostics, extmarks, Plenary/Busted tests.

---

## Core Concepts

### Pure Entities

| Name | Lives in | Status |
|------|----------|--------|
| `ParleyDiagnosticMessageLines` | `lua/parley/skills/review/diag_display.lua` | new |

- **ParleyDiagnosticMessageLines** — deterministic conversion from a diagnostic message string into visible virtual-line rows with a `Diagnostics:` header.
  - **Relationships:** 1:N from one diagnostic message to display rows.
  - **DRY rationale:** Both review diagnostics and footnote diagnostics consume the same Parley namespace display.
  - **Future extensions:** If Parley later adds source-specific labels, this formatter is the one place to widen.

### Integration Points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `ParleyDiagnosticVirtualLines` | `lua/parley/skills/review/diag_display.lua` | modified | Neovim extmarks |

- **ParleyDiagnosticVirtualLines** — Parley-owned inline diagnostic renderer scoped to `skill_render.diag_namespace()`.
  - **Injected into:** `diag_display.set(on)`; toggling still owns all inline display setup.
  - **Future extensions:** Can add color overrides without changing diagnostic producers.

## Chunk 1: Left-Column Renderer

**Files:**
- Modify: `lua/parley/skills/review/diag_display.lua`
- Modify: `tests/integration/review_diag_display_spec.lua`
- Modify: `atlas/modes/review.md`
- Modify: `atlas/chat/inline_define.md`
- Modify: `workshop/issues/000173-diagnostic-virtual-lines-leftcol.md`

- [x] **Step 1: Write failing tests**

Add integration coverage that:
- Sets a Parley diagnostic at a high column on a long line.
- Enables `diag_display`.
- Asserts the generated display extmark has `virt_lines_leftcol = true`.
- Asserts the first virtual-line chunk is `Diagnostics:` instead of leading spaces.
- Asserts `dd.set(false)` clears the Parley display extmark while leaving the diagnostic data intact.

Run:

```bash
nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"
```

Expected: FAIL because the stock diagnostic handler emits leading-space virtual lines and `diag_display` has no custom extmark namespace.

- [x] **Step 2: Implement the renderer**

In `lua/parley/skills/review/diag_display.lua`:
- Add a private display namespace.
- Add a private function that clears Parley diagnostic virtual-line extmarks.
- Add a private render function that reads diagnostics from `skill_render.diag_namespace()`, filters to the current cursor line, and writes `virt_lines` with `virt_lines_leftcol = true`.
- Configure Neovim diagnostics for the Parley namespace with `virtual_lines = false`, `virtual_text = false`, and existing signs/underline behavior.
- Register a buffer-local `CursorMoved` autocmd for visible Parley buffers so current-line behavior keeps updating.

- [x] **Step 3: Run green focused tests**

Run:

```bash
nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"
```

Expected: PASS.

- [x] **Step 4: Update docs and issue log**

Update atlas text that says Parley uses built-in diagnostic `virtual_lines` so it instead describes the Parley-owned left-column inline renderer. Record red/green evidence in the issue log and tick plan items.

- [x] **Step 5: Final verification**

Run:

```bash
git diff --check -- lua/parley/skills/review/diag_display.lua tests/integration/review_diag_display_spec.lua atlas/modes/review.md atlas/chat/inline_define.md workshop/issues/000173-diagnostic-virtual-lines-leftcol.md workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md
make test
```

Expected: all pass.

exec
/bin/zsh -lc 'git diff --stat b9094e9bfc89b0f27013c6fd41c38a83b8b61510..HEAD && git diff --name-only b9094e9bfc89b0f27013c6fd41c38a83b8b61510..HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
 atlas/chat/inline_define.md                        |  26 ++--
 atlas/modes/review.md                              |  16 ++-
 lua/parley/skills/review/diag_display.lua          | 132 ++++++++++++++++++++-
 tests/integration/review_diag_display_spec.lua     |  61 +++++++++-
 .../000173-diagnostic-virtual-lines-leftcol.md     |  70 ++++++++++-
 ...000173-diagnostic-virtual-lines-leftcol-plan.md |  94 +++++++++++++++
 6 files changed, 373 insertions(+), 26 deletions(-)
atlas/chat/inline_define.md
atlas/modes/review.md
lua/parley/skills/review/diag_display.lua
tests/integration/review_diag_display_spec.lua
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md
workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md

exec
/bin/zsh -lc 'git diff --check b9094e9bfc89b0f27013c6fd41c38a83b8b61510..HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
codex
The tracker and plan align at a high level: one display-shell change, tests, and atlas updates. I’m reading the implementation now for Neovim handler semantics and edge cases like buffer focus, cursor movement, and config toggling.
exec
/bin/zsh -lc "nl -ba lua/parley/skills/review/diag_display.lua | sed -n '1,240p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
     1    -- diag_display.lua — inline display of review "why" diagnostics (#133 M6).
     2    --
     3    -- Controls how parley's review explanations render, scoped to parley's OWN
     4    -- diagnostic namespace (never touches the user's LSP / global diagnostics).
     5    -- Default ON: `virtual_lines { current_line = true }`, so the (hard-wrapped) why
     6    -- auto-expands below an edit when the cursor is in that edit's region, and hides
     7    -- otherwise. `:ParleyShowDiagnostics` toggles it.
     8
     9    local M = {}
    10
    11    M.enabled = true -- default on (cursor-region auto-show)
    12
    13    local HANDLER_NAME = "parley/virtual_lines"
    14    local DISPLAY_NS = "parley_diagnostic_virtual_lines"
    15    local DISPLAY_AUGROUP = "parley_diagnostic_virtual_lines"
    16    local HEADER_HL = "ParleyDiagnosticVirtualLineHeader"
    17    local MESSAGE_HL = "ParleyDiagnosticVirtualLine"
    18
    19    local display_ns_id
    20    local display_augroup
    21
    22    -- Parley's review diagnostic namespace — single-sourced from skill_render (which
    23    -- owns the namespace) so the identity isn't a duplicated literal (#133 M6 review).
    24    local function ns()
    25        return require("parley.skill_render").diag_namespace()
    26    end
    27
    28    local function ensure_display()
    29        if not display_ns_id then
    30            display_ns_id = vim.api.nvim_create_namespace(DISPLAY_NS)
    31        end
    32        if not display_augroup then
    33            display_augroup = vim.api.nvim_create_augroup(DISPLAY_AUGROUP, { clear = true })
    34        end
    35        vim.api.nvim_set_hl(0, HEADER_HL, { link = "DiagnosticInfo" })
    36        vim.api.nvim_set_hl(0, MESSAGE_HL, { link = "DiagnosticFloatingInfo" })
    37    end
    38
    39    local function clear(buf)
    40        ensure_display()
    41        if vim.api.nvim_buf_is_valid(buf) then
    42            vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
    43            pcall(vim.api.nvim_clear_autocmds, { group = display_augroup, buffer = buf })
    44        end
    45    end
    46
    47    local function current_line_for(buf)
    48        if vim.api.nvim_get_current_buf() ~= buf then
    49            return nil
    50        end
    51        return vim.api.nvim_win_get_cursor(0)[1] - 1
    52    end
    53
    54    local function diagnostic_message_lines(diagnostic)
    55        local lines = {}
    56        for _, line in ipairs(vim.split(tostring(diagnostic.message or ""), "\n", { plain = true })) do
    57            table.insert(lines, { { line ~= "" and line or " ", MESSAGE_HL } })
    58        end
    59        if #lines == 0 then
    60            table.insert(lines, { { " ", MESSAGE_HL } })
    61        end
    62        return lines
    63    end
    64
    65    local function render(buf, diagnostics, current_line_only)
    66        ensure_display()
    67        if not vim.api.nvim_buf_is_valid(buf) then
    68            return
    69        end
    70        vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
    71
    72        local line = current_line_only and current_line_for(buf) or nil
    73        if current_line_only and not line then
    74            return
    75        end
    76
    77        local by_line = {}
    78        for _, diagnostic in ipairs(diagnostics or {}) do
    79            if not current_line_only or diagnostic.lnum == line then
    80                by_line[diagnostic.lnum] = by_line[diagnostic.lnum] or {}
    81                table.insert(by_line[diagnostic.lnum], diagnostic)
    82            end
    83        end
    84
    85        for lnum, line_diagnostics in pairs(by_line) do
    86            table.sort(line_diagnostics, function(a, b)
    87                return (a.col or 0) < (b.col or 0)
    88            end)
    89            local virt_lines = { { { "Diagnostics:", HEADER_HL } } }
    90            for _, diagnostic in ipairs(line_diagnostics) do
    91                vim.list_extend(virt_lines, diagnostic_message_lines(diagnostic))
    92            end
    93            vim.api.nvim_buf_set_extmark(buf, display_ns_id, lnum, 0, {
    94                virt_lines = virt_lines,
    95                virt_lines_leftcol = true,
    96                virt_lines_above = false,
    97            })
    98        end
    99    end
   100
   101    local function register_handler()
   102        ensure_display()
   103        vim.diagnostic.handlers[HANDLER_NAME] = {
   104            show = function(namespace, bufnr, diagnostics, opts)
   105                if namespace ~= ns() then
   106                    return
   107                end
   108                bufnr = vim._resolve_bufnr(bufnr)
   109                local handler_opts = opts and opts[HANDLER_NAME] or {}
   110                local current_line_only = handler_opts.current_line == true
   111                clear(bufnr)
   112                if current_line_only then
   113                    vim.api.nvim_create_autocmd("CursorMoved", {
   114                        buffer = bufnr,
   115                        group = display_augroup,
   116                        callback = function()
   117                            render(bufnr, diagnostics, true)
   118                        end,
   119                    })
   120                end
   121                render(bufnr, diagnostics, current_line_only)
   122            end,
   123            hide = function(namespace, bufnr)
   124                if namespace ~= ns() then
   125                    return
   126                end
   127                clear(vim._resolve_bufnr(bufnr))
   128            end,
   129        }
   130    end
   131
   132    function M.refresh(buf)
   133        if not M.enabled then
   134            return
   135        end
   136        buf = buf or vim.api.nvim_get_current_buf()
   137        render(buf, vim.diagnostic.get(buf, { namespace = ns() }), true)
   138    end
   139
   140    --- Apply the inline-display config for parley's review namespace.
   141    --- @param on boolean
   142    function M.set(on)
   143        M.enabled = on and true or false
   144        register_handler()
   145        vim.diagnostic.config({
   146            [HANDLER_NAME] = M.enabled and { current_line = true } or false,
   147            virtual_lines = false,
   148            virtual_text = false,
   149        }, ns())
   150        if M.enabled then
   151            M.refresh()
   152        else
   153            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
   154                clear(buf)
   155            end
   156        end
   157    end
   158
   159    --- Toggle inline display; returns the new state.
   160    --- @return boolean
   161    function M.toggle()
   162        M.set(not M.enabled)
   163        return M.enabled
   164    end
   165
   166    --- Is inline display currently enabled?
   167    --- @return boolean
   168    function M.is_enabled()
   169        return M.enabled
   170    end
   171
   172    return M

exec
/bin/zsh -lc "nl -ba tests/integration/review_diag_display_spec.lua | sed -n '1,180p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
     1    -- Integration tests for the review-diagnostic inline display toggle (#133 M6).
     2
     3    local dd = require("parley.skills.review.diag_display")
     4
     5    local function ns_cfg()
     6        return vim.diagnostic.config(nil, require("parley.skill_render").diag_namespace())
     7    end
     8
     9    local function display_marks(buf)
    10        local display_ns = vim.api.nvim_create_namespace("parley_diagnostic_virtual_lines")
    11        return vim.api.nvim_buf_get_extmarks(buf, display_ns, 0, -1, { details = true })
    12    end
    13
    14    describe("review.diag_display", function()
    15        after_each(function()
    16            dd.set(true) -- restore default for other specs
    17            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    18                if vim.api.nvim_buf_is_valid(buf) then
    19                    pcall(vim.diagnostic.reset, require("parley.skill_render").diag_namespace(), buf)
    20                end
    21            end
    22        end)
    23
    24        it("toggles the enabled state", function()
    25            dd.set(true)
    26            assert.is_true(dd.is_enabled())
    27            assert.is_false(dd.toggle())
    28            assert.is_false(dd.is_enabled())
    29            assert.is_true(dd.toggle())
    30            assert.is_true(dd.is_enabled())
    31        end)
    32
    33        it("configures Parley's custom current-line display on its namespace when on; off when disabled", function()
    34            dd.set(true)
    35            local on = ns_cfg()
    36            assert.is_false(on.virtual_lines) -- Parley owns its virtual-lines renderer.
    37            assert.is_truthy(on["parley/virtual_lines"])
    38            assert.is_false(on.virtual_text) -- inline single-line is never used
    39            dd.set(false)
    40            assert.is_false(ns_cfg()["parley/virtual_lines"])
    41        end)
    42
    43        it("renders current-line diagnostics from the left column without moving the diagnostic span", function()
    44            local skill_render = require("parley.skill_render")
    45            local diag_ns = skill_render.diag_namespace()
    46            local buf = vim.api.nvim_create_buf(false, true)
    47            vim.api.nvim_set_current_buf(buf)
    48            vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    49                string.rep("x", 120) .. " ACOS[^acos]",
    50            })
    51
    52            dd.set(true)
    53            vim.diagnostic.set(diag_ns, buf, { {
    54                lnum = 0,
    55                col = 121,
    56                end_lnum = 0,
    57                end_col = 132,
    58                message = "ACOS — Advertising Cost of Sales.",
    59                severity = vim.diagnostic.severity.INFO,
    60                source = "parley-footnote",
    61            } })
    62
    63            vim.wait(100, function()
    64                return #display_marks(buf) == 1
    65            end)
    66
    67            local marks = display_marks(buf)
    68            assert.are.equal(1, #marks)
    69            local details = marks[1][4]
    70            assert.is_true(details.virt_lines_leftcol)
    71            assert.are.equal("Diagnostics:", details.virt_lines[1][1][1])
    72            assert.are_not.equal(string.rep(" ", 121), details.virt_lines[1][1][1])
    73            assert.are.equal("ACOS — Advertising Cost of Sales.", details.virt_lines[2][1][1])
    74
    75            local diagnostics = vim.diagnostic.get(buf, { namespace = diag_ns })
    76            assert.are.equal(1, #diagnostics)
    77            assert.are.equal(0, diagnostics[1].lnum)
    78            assert.are.equal(121, diagnostics[1].col)
    79            assert.are.equal(0, diagnostics[1].end_lnum)
    80            assert.are.equal(132, diagnostics[1].end_col)
    81
    82            dd.set(false)
    83            assert.are.equal(0, #display_marks(buf))
    84            assert.are.equal(1, #vim.diagnostic.get(buf, { namespace = diag_ns }))
    85        end)
    86    end)

exec
/bin/zsh -lc "rg -n \"diag_display|ParleyShowDiagnostics|virtual_lines|parley/virtual_lines|refresh\\(\" lua tests atlas README.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
atlas/chat/inline_define.md:44:   `diag_display`'s Parley-owned left-column virtual-line display reveals the
atlas/chat/inline_define.md:149:- [Document Review](../modes/review.md) — the skill/`skill_invoke`/`diag_display`
lua/parley/skills/review/diag_display.lua:1:-- diag_display.lua — inline display of review "why" diagnostics (#133 M6).
lua/parley/skills/review/diag_display.lua:5:-- Default ON: `virtual_lines { current_line = true }`, so the (hard-wrapped) why
lua/parley/skills/review/diag_display.lua:7:-- otherwise. `:ParleyShowDiagnostics` toggles it.
lua/parley/skills/review/diag_display.lua:13:local HANDLER_NAME = "parley/virtual_lines"
lua/parley/skills/review/diag_display.lua:14:local DISPLAY_NS = "parley_diagnostic_virtual_lines"
lua/parley/skills/review/diag_display.lua:15:local DISPLAY_AUGROUP = "parley_diagnostic_virtual_lines"
lua/parley/skills/review/diag_display.lua:132:function M.refresh(buf)
lua/parley/skills/review/diag_display.lua:147:        virtual_lines = false,
lua/parley/skills/review/diag_display.lua:151:        M.refresh()
atlas/modes/review.md:163:`parley_skill` namespace. `lua/parley/skills/review/diag_display.lua` controls how
atlas/modes/review.md:165:untouched. Default **on**: Parley's custom `parley/virtual_lines` diagnostic
atlas/modes/review.md:171:`lnum..end_lnum`) and hides otherwise. `:ParleyShowDiagnostics` toggles it. The
atlas/modes/review.md:209:- `lua/parley/skills/review/diag_display.lua` — inline "why" display toggle (`:ParleyShowDiagnostics`, cursor-region auto-show) (#133 M6)
tests/integration/highlighting_spec.lua:445:        assert.same({ current_line = true }, diag_config.virtual_lines)
tests/integration/review_diag_display_spec.lua:3:local dd = require("parley.skills.review.diag_display")
tests/integration/review_diag_display_spec.lua:10:    local display_ns = vim.api.nvim_create_namespace("parley_diagnostic_virtual_lines")
tests/integration/review_diag_display_spec.lua:14:describe("review.diag_display", function()
tests/integration/review_diag_display_spec.lua:36:        assert.is_false(on.virtual_lines) -- Parley owns its virtual-lines renderer.
tests/integration/review_diag_display_spec.lua:37:        assert.is_truthy(on["parley/virtual_lines"])
tests/integration/review_diag_display_spec.lua:40:        assert.is_false(ns_cfg()["parley/virtual_lines"])
lua/parley/init.lua:770:    -- :ParleyShowDiagnostics — toggle inline display of review "why" diagnostics
lua/parley/init.lua:773:        local on = require("parley.skills.review.diag_display").toggle()
lua/parley/init.lua:776:    require("parley.skills.review.diag_display").set(true)
lua/parley/init.lua:976:        pcall(function() require("lualine").refresh() end)
lua/parley/init.lua:991:        pcall(function() require("lualine").refresh() end)
lua/parley/init.lua:1655:    -- Park the cursor on the term's line so diag_display's current-line
lua/parley/init.lua:1656:    -- virtual_lines reveals the definition immediately.
lua/parley/lualine.lua:29:      require("lualine").refresh()
lua/parley/lualine.lua:477:            require("lualine").refresh()
lua/parley/lualine.lua:488:            require("lualine").refresh()
lua/parley/lualine.lua:499:            require("lualine").refresh()
lua/parley/timezone_diagnostics.lua:14:            virtual_lines = { current_line = true },
lua/parley/skill_render.lua:39:--- (diag_display) target, so the namespace identity isn't duplicated as a literal
lua/parley/skill_render.lua:47:--- existing newlines. PURE. Lets `virtual_lines` render a long "why" as multiple
lua/parley/skill_render.lua:77:-- Usable wrap width for the virtual_lines "why": the window's text columns
lua/parley/skill_render.lua:80:-- fixed 76 overflowed the indented virtual_lines and truncated the right edge
lua/parley/skill_render.lua:98:--- Format a diagnostic message for Neovim virtual_lines display.
lua/parley/skill_render.lua:150:--- message is hard-wrapped to the window's usable width for `virtual_lines`
lua/parley/interview.lua:158:                    require("lualine").refresh()
lua/parley/interview.lua:204:                require("lualine").refresh()
lua/parley/interview.lua:231:        require("lualine").refresh()
lua/parley/interview.lua:250:        require("lualine").refresh()

exec
/bin/zsh -lc 'git diff --unified=80 b9094e9bfc89b0f27013c6fd41c38a83b8b61510..HEAD -- lua/parley/skills/review/diag_display.lua tests/integration/review_diag_display_spec.lua' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
diff --git a/lua/parley/skills/review/diag_display.lua b/lua/parley/skills/review/diag_display.lua
index 4617a35..6fd4da6 100644
--- a/lua/parley/skills/review/diag_display.lua
+++ b/lua/parley/skills/review/diag_display.lua
@@ -1,42 +1,172 @@
 -- diag_display.lua — inline display of review "why" diagnostics (#133 M6).
 --
 -- Controls how parley's review explanations render, scoped to parley's OWN
 -- diagnostic namespace (never touches the user's LSP / global diagnostics).
 -- Default ON: `virtual_lines { current_line = true }`, so the (hard-wrapped) why
 -- auto-expands below an edit when the cursor is in that edit's region, and hides
 -- otherwise. `:ParleyShowDiagnostics` toggles it.

 local M = {}

 M.enabled = true -- default on (cursor-region auto-show)

+local HANDLER_NAME = "parley/virtual_lines"
+local DISPLAY_NS = "parley_diagnostic_virtual_lines"
+local DISPLAY_AUGROUP = "parley_diagnostic_virtual_lines"
+local HEADER_HL = "ParleyDiagnosticVirtualLineHeader"
+local MESSAGE_HL = "ParleyDiagnosticVirtualLine"
+
+local display_ns_id
+local display_augroup
+
 -- Parley's review diagnostic namespace — single-sourced from skill_render (which
 -- owns the namespace) so the identity isn't a duplicated literal (#133 M6 review).
 local function ns()
     return require("parley.skill_render").diag_namespace()
 end

+local function ensure_display()
+    if not display_ns_id then
+        display_ns_id = vim.api.nvim_create_namespace(DISPLAY_NS)
+    end
+    if not display_augroup then
+        display_augroup = vim.api.nvim_create_augroup(DISPLAY_AUGROUP, { clear = true })
+    end
+    vim.api.nvim_set_hl(0, HEADER_HL, { link = "DiagnosticInfo" })
+    vim.api.nvim_set_hl(0, MESSAGE_HL, { link = "DiagnosticFloatingInfo" })
+end
+
+local function clear(buf)
+    ensure_display()
+    if vim.api.nvim_buf_is_valid(buf) then
+        vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
+        pcall(vim.api.nvim_clear_autocmds, { group = display_augroup, buffer = buf })
+    end
+end
+
+local function current_line_for(buf)
+    if vim.api.nvim_get_current_buf() ~= buf then
+        return nil
+    end
+    return vim.api.nvim_win_get_cursor(0)[1] - 1
+end
+
+local function diagnostic_message_lines(diagnostic)
+    local lines = {}
+    for _, line in ipairs(vim.split(tostring(diagnostic.message or ""), "\n", { plain = true })) do
+        table.insert(lines, { { line ~= "" and line or " ", MESSAGE_HL } })
+    end
+    if #lines == 0 then
+        table.insert(lines, { { " ", MESSAGE_HL } })
+    end
+    return lines
+end
+
+local function render(buf, diagnostics, current_line_only)
+    ensure_display()
+    if not vim.api.nvim_buf_is_valid(buf) then
+        return
+    end
+    vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
+
+    local line = current_line_only and current_line_for(buf) or nil
+    if current_line_only and not line then
+        return
+    end
+
+    local by_line = {}
+    for _, diagnostic in ipairs(diagnostics or {}) do
+        if not current_line_only or diagnostic.lnum == line then
+            by_line[diagnostic.lnum] = by_line[diagnostic.lnum] or {}
+            table.insert(by_line[diagnostic.lnum], diagnostic)
+        end
+    end
+
+    for lnum, line_diagnostics in pairs(by_line) do
+        table.sort(line_diagnostics, function(a, b)
+            return (a.col or 0) < (b.col or 0)
+        end)
+        local virt_lines = { { { "Diagnostics:", HEADER_HL } } }
+        for _, diagnostic in ipairs(line_diagnostics) do
+            vim.list_extend(virt_lines, diagnostic_message_lines(diagnostic))
+        end
+        vim.api.nvim_buf_set_extmark(buf, display_ns_id, lnum, 0, {
+            virt_lines = virt_lines,
+            virt_lines_leftcol = true,
+            virt_lines_above = false,
+        })
+    end
+end
+
+local function register_handler()
+    ensure_display()
+    vim.diagnostic.handlers[HANDLER_NAME] = {
+        show = function(namespace, bufnr, diagnostics, opts)
+            if namespace ~= ns() then
+                return
+            end
+            bufnr = vim._resolve_bufnr(bufnr)
+            local handler_opts = opts and opts[HANDLER_NAME] or {}
+            local current_line_only = handler_opts.current_line == true
+            clear(bufnr)
+            if current_line_only then
+                vim.api.nvim_create_autocmd("CursorMoved", {
+                    buffer = bufnr,
+                    group = display_augroup,
+                    callback = function()
+                        render(bufnr, diagnostics, true)
+                    end,
+                })
+            end
+            render(bufnr, diagnostics, current_line_only)
+        end,
+        hide = function(namespace, bufnr)
+            if namespace ~= ns() then
+                return
+            end
+            clear(vim._resolve_bufnr(bufnr))
+        end,
+    }
+end
+
+function M.refresh(buf)
+    if not M.enabled then
+        return
+    end
+    buf = buf or vim.api.nvim_get_current_buf()
+    render(buf, vim.diagnostic.get(buf, { namespace = ns() }), true)
+end
+
 --- Apply the inline-display config for parley's review namespace.
 --- @param on boolean
 function M.set(on)
     M.enabled = on and true or false
+    register_handler()
     vim.diagnostic.config({
-        virtual_lines = M.enabled and { current_line = true } or false,
+        [HANDLER_NAME] = M.enabled and { current_line = true } or false,
+        virtual_lines = false,
         virtual_text = false,
     }, ns())
+    if M.enabled then
+        M.refresh()
+    else
+        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
+            clear(buf)
+        end
+    end
 end

 --- Toggle inline display; returns the new state.
 --- @return boolean
 function M.toggle()
     M.set(not M.enabled)
     return M.enabled
 end

 --- Is inline display currently enabled?
 --- @return boolean
 function M.is_enabled()
     return M.enabled
 end

 return M
diff --git a/tests/integration/review_diag_display_spec.lua b/tests/integration/review_diag_display_spec.lua
index 7950705..97fe2e8 100644
--- a/tests/integration/review_diag_display_spec.lua
+++ b/tests/integration/review_diag_display_spec.lua
@@ -1,31 +1,86 @@
 -- Integration tests for the review-diagnostic inline display toggle (#133 M6).

 local dd = require("parley.skills.review.diag_display")

 local function ns_cfg()
     return vim.diagnostic.config(nil, require("parley.skill_render").diag_namespace())
 end

+local function display_marks(buf)
+    local display_ns = vim.api.nvim_create_namespace("parley_diagnostic_virtual_lines")
+    return vim.api.nvim_buf_get_extmarks(buf, display_ns, 0, -1, { details = true })
+end
+
 describe("review.diag_display", function()
     after_each(function()
         dd.set(true) -- restore default for other specs
+        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
+            if vim.api.nvim_buf_is_valid(buf) then
+                pcall(vim.diagnostic.reset, require("parley.skill_render").diag_namespace(), buf)
+            end
+        end
     end)

     it("toggles the enabled state", function()
         dd.set(true)
         assert.is_true(dd.is_enabled())
         assert.is_false(dd.toggle())
         assert.is_false(dd.is_enabled())
         assert.is_true(dd.toggle())
         assert.is_true(dd.is_enabled())
     end)

-    it("configures virtual_lines current_line on parley's namespace when on; off when disabled", function()
+    it("configures Parley's custom current-line display on its namespace when on; off when disabled", function()
         dd.set(true)
         local on = ns_cfg()
-        assert.is_truthy(on.virtual_lines) -- { current_line = true }
+        assert.is_false(on.virtual_lines) -- Parley owns its virtual-lines renderer.
+        assert.is_truthy(on["parley/virtual_lines"])
         assert.is_false(on.virtual_text) -- inline single-line is never used
         dd.set(false)
-        assert.is_false(ns_cfg().virtual_lines)
+        assert.is_false(ns_cfg()["parley/virtual_lines"])
+    end)
+
+    it("renders current-line diagnostics from the left column without moving the diagnostic span", function()
+        local skill_render = require("parley.skill_render")
+        local diag_ns = skill_render.diag_namespace()
+        local buf = vim.api.nvim_create_buf(false, true)
+        vim.api.nvim_set_current_buf(buf)
+        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
+            string.rep("x", 120) .. " ACOS[^acos]",
+        })
+
+        dd.set(true)
+        vim.diagnostic.set(diag_ns, buf, { {
+            lnum = 0,
+            col = 121,
+            end_lnum = 0,
+            end_col = 132,
+            message = "ACOS — Advertising Cost of Sales.",
+            severity = vim.diagnostic.severity.INFO,
+            source = "parley-footnote",
+        } })
+
+        vim.wait(100, function()
+            return #display_marks(buf) == 1
+        end)
+
+        local marks = display_marks(buf)
+        assert.are.equal(1, #marks)
+        local details = marks[1][4]
+        assert.is_true(details.virt_lines_leftcol)
+        assert.are.equal("Diagnostics:", details.virt_lines[1][1][1])
+        assert.are_not.equal(string.rep(" ", 121), details.virt_lines[1][1][1])
+        assert.are.equal("ACOS — Advertising Cost of Sales.", details.virt_lines[2][1][1])
+
+        local diagnostics = vim.diagnostic.get(buf, { namespace = diag_ns })
+        assert.are.equal(1, #diagnostics)
+        assert.are.equal(0, diagnostics[1].lnum)
+        assert.are.equal(121, diagnostics[1].col)
+        assert.are.equal(0, diagnostics[1].end_lnum)
+        assert.are.equal(132, diagnostics[1].end_col)
+
+        dd.set(false)
+        assert.are.equal(0, #display_marks(buf))
+        assert.are.equal(1, #vim.diagnostic.get(buf, { namespace = diag_ns }))
     end)
 end)

exec
/bin/zsh -lc "nl -ba lua/parley/skill_render.lua | sed -n '1,230p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
     1    -- parley.skill_render — buffer decorations for applied skill edits.
     2    --
     3    -- The diagnostics/highlights rendering salvaged out of skill_runner (#128 M3),
     4    -- now the single source used by the skill_invoke driver (skill_runner was
     5    -- deleted in M4). Thin vim-API/UI wrapper (not pure): INFO diagnostics from each
     6    -- edit's `explain`, DiffChange highlights on edited regions.
     7
     8    local M = {}
     9
    10    local DIAG_NS = "parley_skill"
    11    local HL_NS = "parley_skill_hl"
    12    local FOOTNOTE_SOURCE = "parley-footnote"
    13
    14    local diag_ns_id
    15    local hl_ns_id
    16
    17    local function ensure_namespaces()
    18        if not diag_ns_id then
    19            diag_ns_id = vim.api.nvim_create_namespace(DIAG_NS)
    20        end
    21        if not hl_ns_id then
    22            hl_ns_id = vim.api.nvim_create_namespace(HL_NS)
    23        end
    24    end
    25
    26    --- Clear previous skill diagnostics and highlights from a buffer.
    27    function M.clear_decorations(buf)
    28        ensure_namespaces()
    29        vim.diagnostic.reset(diag_ns_id, buf)
    30        vim.api.nvim_buf_clear_namespace(buf, hl_ns_id, 0, -1)
    31    end
    32
    33    --- Dismiss the live round decorations (manual <dismiss> binding). Decorations
    34    --- otherwise RIDE subsequent edits (behavior B, #133) and are cleared only at
    35    --- the next round start; this lets the operator clear them on demand.
    36    M.dismiss = M.clear_decorations
    37
    38    --- The review diagnostic namespace id — the single source other modules
    39    --- (diag_display) target, so the namespace identity isn't duplicated as a literal
    40    --- string in two places (#133 M6 review).
    41    function M.diag_namespace()
    42        ensure_namespaces()
    43        return diag_ns_id
    44    end
    45
    46    --- Hard-wrap text to `width` columns at word boundaries (greedy), preserving any
    47    --- existing newlines. PURE. Lets `virtual_lines` render a long "why" as multiple
    48    --- wrapped rows (nvim doesn't soft-wrap virtual text). A word longer than width
    49    --- stays on its own (overflowing) line rather than being split. (#133 M6)
    50    --- @param text string
    51    --- @param width number|nil  default 76
    52    --- @return string
    53    function M.wrap(text, width)
    54        width = width or 76
    55        local out = {}
    56        for para in (tostring(text) .. "\n"):gmatch("(.-)\n") do
    57            if para == "" then
    58                table.insert(out, "")
    59            else
    60                local line = ""
    61                for word in para:gmatch("%S+") do
    62                    if line == "" then
    63                        line = word
    64                    elseif #line + 1 + #word <= width then
    65                        line = line .. " " .. word
    66                    else
    67                        table.insert(out, line)
    68                        line = word
    69                    end
    70                end
    71                table.insert(out, line)
    72            end
    73        end
    74        return table.concat(out, "\n")
    75    end
    76
    77    -- Usable wrap width for the virtual_lines "why": the window's text columns
    78    -- (total width minus the number/sign/fold gutter, via getwininfo.textoff) minus
    79    -- a margin for the indent + connector nvim renders under the line. Wrapping to a
    80    -- fixed 76 overflowed the indented virtual_lines and truncated the right edge
    81    -- (#133 review). Falls back to 76 with no window.
    82    local function diag_wrap_width()
    83        local ok, info = pcall(function()
    84            return vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
    85        end)
    86        if not ok or type(info) ~= "table" then
    87            return 76
    88        end
    89        return math.max(30, (info.width or 80) - (info.textoff or 0) - 10)
    90    end
    91
    92    --- Current usable wrap width for Parley diagnostic virtual lines.
    93    --- @return integer
    94    function M.diagnostic_wrap_width()
    95        return diag_wrap_width()
    96    end
    97
    98    --- Format a diagnostic message for Neovim virtual_lines display.
    99    --- @param text string
   100    --- @param width number|nil default current diagnostic display width
   101    --- @return string
   102    function M.format_diagnostic_message(text, width)
   103        return M.wrap(text, width or M.diagnostic_wrap_width())
   104    end
   105
   106    local function is_footnote_diagnostic(diagnostic)
   107        local user_data = diagnostic.user_data or {}
   108        return diagnostic.source == FOOTNOTE_SOURCE or user_data.parley_kind == "footnote"
   109    end
   110
   111    --- Rehydrate persisted managed markdown footnotes into Parley diagnostics.
   112    --- Existing non-footnote diagnostics in the shared namespace are preserved.
   113    --- @param buf number|nil
   114    function M.refresh_footnote_diagnostics(buf)
   115        ensure_namespaces()
   116        buf = buf or vim.api.nvim_get_current_buf()
   117        if not vim.api.nvim_buf_is_valid(buf) then
   118            return
   119        end
   120
   121        local define = require("parley.define")
   122        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
   123        local width = M.diagnostic_wrap_width()
   124        local diagnostics = {}
   125
   126        for _, existing in ipairs(vim.diagnostic.get(buf, { namespace = diag_ns_id })) do
   127            if not is_footnote_diagnostic(existing) then
   128                table.insert(diagnostics, existing)
   129            end
   130        end
   131
   132        for _, footnote in ipairs(define.footnote_diagnostics(lines)) do
   133            table.insert(diagnostics, {
   134                lnum = footnote.lnum,
   135                col = footnote.col,
   136                end_lnum = footnote.end_lnum or footnote.lnum,
   137                end_col = footnote.end_col,
   138                message = define.format_definition(footnote.term or footnote.id, footnote.definition, width),
   139                severity = vim.diagnostic.severity.INFO,
   140                source = FOOTNOTE_SOURCE,
   141                user_data = { parley_kind = "footnote" },
   142            })
   143        end
   144
   145        vim.diagnostic.set(diag_ns_id, buf, diagnostics)
   146    end
   147
   148    --- Attach INFO diagnostics from edit explanations. Each diagnostic spans the
   149    --- edit's line range (lnum..end_lnum) so "cursor in the region" matches, and its
   150    --- message is hard-wrapped to the window's usable width for `virtual_lines`
   151    --- display (no right-edge truncation). (#133 M6)
   152    --- @param buf number
   153    --- @param edits table[]  applied edits with {pos, explain, new_string?}
   154    --- @param original_content string  file content before edits
   155    function M.attach_diagnostics(buf, edits, original_content)
   156        ensure_namespaces()
   157        local width = M.diagnostic_wrap_width()
   158        local diagnostics = {}
   159        for _, edit in ipairs(edits) do
   160            local line_num = 0
   161            for _ in original_content:sub(1, edit.pos):gmatch("\n") do
   162                line_num = line_num + 1
   163            end
   164            -- end_lnum spans the edit's own lines (newlines in the new text); a pure
   165            -- deletion (no new_string) stays a single-line anchor.
   166            local span = 0
   167            for _ in (edit.new_string or ""):gmatch("\n") do
   168                span = span + 1
   169            end
   170            table.insert(diagnostics, {
   171                lnum = line_num,
   172                end_lnum = line_num + span,
   173                col = 0,
   174                message = M.format_diagnostic_message(edit.explain or "edit applied", width),
   175                severity = vim.diagnostic.severity.INFO,
   176                source = "parley-skill",
   177            })
   178        end
   179        vim.diagnostic.set(diag_ns_id, buf, diagnostics)
   180    end
   181
   182    --- Highlight edited regions with DiffChange.
   183    --- @param buf number
   184    --- @param edits table[]  applied edits with {new_string}
   185    --- @param new_content string  file content after edits
   186    function M.highlight_edits(buf, edits, new_content)
   187        ensure_namespaces()
   188        for _, edit in ipairs(edits) do
   189            -- Skip pure deletions: new_string is "" and `find("")` returns 1, which
   190            -- would spuriously highlight line 0. Deletions are oriented by their
   191            -- INFO gutter diagnostic (the "why") via attach_diagnostics, not a
   192            -- highlight (there's no new text to mark). #133.
   193            local new_pos = (edit.new_string and edit.new_string ~= "")
   194                and new_content:find(edit.new_string, 1, true)
   195                or nil
   196            if new_pos then
   197                local start_line = 0
   198                for _ in new_content:sub(1, new_pos):gmatch("\n") do
   199                    start_line = start_line + 1
   200                end
   201                local end_line = start_line
   202                for _ in edit.new_string:gmatch("\n") do
   203                    end_line = end_line + 1
   204                end
   205                for line = start_line, end_line do
   206                    vim.api.nvim_buf_add_highlight(buf, hl_ns_id, "DiffChange", line, 0, -1)
   207                end
   208            end
   209        end
   210    end
   211
   212    --- Highlight a whole line with DiffChange on the hl namespace (#161 R1). Same
   213    --- shape `apply_snapshot` restores (whole-line, col 0..-1), so it round-trips
   214    --- through projection's line-granular undo/redo snapshotting.
   215    --- @param buf number
   216    --- @param lnum0 number  0-based line
   217    function M.highlight_line(buf, lnum0)
   218        ensure_namespaces()
   219        vim.api.nvim_buf_add_highlight(buf, hl_ns_id, "DiffChange", lnum0, 0, -1)
   220    end
   221
   222    --- Highlight a column span with DiffChange on the hl namespace. The four-arg
   223    --- form is same-line: (buf, lnum0, col_start, col_end). The five-arg form spans
   224    --- rows: (buf, lnum0, col_start, end_lnum0, col_end).
   225    --- @param buf number
   226    --- @param lnum0 number 0-based start line
   227    --- @param col_start number 0-based start column
   228    --- @param end_lnum0_or_col_end number 0-based end line, or end column
   229    --- @param col_end number|nil 0-based exclusive end column
   230    function M.highlight_span(buf, lnum0, col_start, end_lnum0_or_col_end, col_end)

exec
/bin/zsh -lc "nl -ba lua/parley/init.lua | sed -n '740,790p;1628,1670p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   740        end
   741
   742        -- prepare system_prompts list
   743        M._system_prompts = {}
   744        for name, _ in pairs(M.system_prompts) do
   745            table.insert(M._system_prompts, name)
   746        end
   747        table.sort(M._system_prompts)
   748
   749        M.refresh_state()
   750
   751        if M.config.default_agent then
   752            M.refresh_state({ agent = M.config.default_agent })
   753        end
   754
   755        -- register user commands
   756        for hook, _ in pairs(M.hooks) do
   757            M.helpers.create_user_command(M.config.cmd_prefix .. hook, function(params)
   758                if M.hooks[hook] ~= nil then
   759                    M.refresh_state()
   760                    M.logger.debug("running hook: " .. hook)
   761                    return M.hooks[hook](M, params)
   762                end
   763                M.logger.error("The hook '" .. hook .. "' does not exist.")
   764            end)
   765        end
   766
   767        -- :ParleyProxy <subcommand> — manage the optional bundled cliproxyapi (#131)
   768        M.register_proxy_command(M.config.cmd_prefix)
   769
   770        -- :ParleyShowDiagnostics — toggle inline display of review "why" diagnostics
   771        -- (cursor-region auto-show, scoped to parley's namespace). Default on. (#133 M6)
   772        M.helpers.create_user_command(M.config.cmd_prefix .. "ShowDiagnostics", function()
   773            local on = require("parley.skills.review.diag_display").toggle()
   774            M.logger.info("Parley review diagnostics: inline display " .. (on and "ON" or "OFF"))
   775        end)
   776        require("parley.skills.review.diag_display").set(true)
   777
   778        -- Register all global keymaps from the keybinding registry
   779        kb_registry.register_global(
   780            { "global", "repo", "note", "issue", "vision", "chat" },
   781            M.config,
   782            {
   783                help = function() M.cmd.KeyBindings() end,
   784                chat_new = function() M.cmd.ChatNew({}) end,
   785                chat_finder = function() M.cmd.ChatFinder() end,
   786                chat_review = function() M.cmd.ChatReview({}) end,
   787                note_new = function() M.cmd.NoteNew() end,
   788                note_finder = function() M.cmd.NoteFinder({}) end,
   789                note_dirs = function() M.cmd.NoteDirs({}) end,
   790                year_root = function()
  1628        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  1629        if define.slice_selection(lines, sr, sc - 1, er, ec - 1) ~= phrase then
  1630            M.logger.warning("Define: selection changed during lookup — re-select to define")
  1631            return
  1632        end
  1633        local original = table.concat(lines, "\n") -- pre-edit content (undo base)
  1634
  1635        -- Store the definition as a markdown footnote in ONE full-buffer set_lines
  1636        -- edit (single undo entry = the anchor). set_applying suppresses any prior
  1637        -- define's projection watcher during our own edit (mirrors review).
  1638        projection.set_applying(buf, true)
  1639        local input = call.input or {}
  1640        local e = define.apply_definition_footnote(lines, sr, sc - 1, er, ec - 1, input.term or phrase, input.definition)
  1641        require("parley.buffer_edit").replace_all_lines_for_definition(buf, e.lines)
  1642
  1643        local diag_span = e.diagnostic_span
  1644        skill_render.highlight_span(buf, diag_span.lnum, diag_span.col, diag_span.end_lnum, diag_span.end_col)
  1645        skill_render.refresh_footnote_diagnostics(buf)
  1646
  1647        -- Record projection states so undo/redo of the footnote edit clears/restores
  1648        -- the decorations (#133 M5 machinery, reused): pre-edit hash → empty
  1649        -- snapshot, footnoted hash → highlight+diagnostic; attach the watcher.
  1650        projection.record_empty_for(buf, original)
  1651        projection.record(buf)
  1652        projection.ensure_watch(buf)
  1653        projection.set_applying(buf, false)
  1654
  1655        -- Park the cursor on the term's line so diag_display's current-line
  1656        -- virtual_lines reveals the definition immediately.
  1657        pcall(vim.api.nvim_win_set_cursor, 0, { sr, math.max(0, sc - 1) })
  1658        vim.cmd("redraw")
  1659    end
  1660
  1661    -- define_visual: the thin IO shell for visual-mode <M-CR>. Reads the selection,
  1662    -- computes the enclosing-exchange context, and fires a headless define skill
  1663    -- turn whose on_done stores + renders the definition inline. Pure logic lives
  1664    -- in lua/parley/define.lua. Exposed as M.define_visual for the keybinding.
  1665    function M.define_visual(buf)
  1666        buf = buf or vim.api.nvim_get_current_buf()
  1667        local sp = vim.fn.getpos("'<")
  1668        local ep = vim.fn.getpos("'>")
  1669        local sr, sc = sp[2], sp[3]
  1670        local er, ec = ep[2], ep[3]

exec
/bin/zsh -lc "rg -n \"attach_diagnostics|diag_namespace|diagnostic.set|end_lnum|format_diagnostic_message\" lua/parley tests -g '*.lua'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
lua/parley/define.lua:80:    return require("parley.skill_render").format_diagnostic_message(head, width)
lua/parley/define.lua:121:--- @return table { lnum: integer, col: integer, end_lnum: integer, end_col: integer }
lua/parley/define.lua:126:        end_lnum = l2 - 1,
lua/parley/define.lua:254:                    end_lnum = lnum - 1,
lua/parley/define.lua:378:            end_lnum = l2 - 1,
tests/integration/review_diag_display_spec.lua:6:    return vim.diagnostic.config(nil, require("parley.skill_render").diag_namespace())
tests/integration/review_diag_display_spec.lua:19:                pcall(vim.diagnostic.reset, require("parley.skill_render").diag_namespace(), buf)
tests/integration/review_diag_display_spec.lua:45:        local diag_ns = skill_render.diag_namespace()
tests/integration/review_diag_display_spec.lua:53:        vim.diagnostic.set(diag_ns, buf, { {
tests/integration/review_diag_display_spec.lua:56:            end_lnum = 0,
tests/integration/review_diag_display_spec.lua:79:        assert.are.equal(0, diagnostics[1].end_lnum)
tests/integration/highlighting_spec.lua:407:        if ok and tz.diag_namespace then
tests/integration/highlighting_spec.lua:410:                    pcall(vim.diagnostic.reset, tz.diag_namespace(), buf)
tests/integration/highlighting_spec.lua:437:        local diagnostics = vim.diagnostic.get(buf, { namespace = tz.diag_namespace() })
tests/integration/highlighting_spec.lua:444:        local diag_config = vim.diagnostic.config(nil, tz.diag_namespace())
tests/integration/highlighting_spec.lua:448:        local skill_ns = require("parley.skill_render").diag_namespace()
tests/integration/highlighting_spec.lua:449:        assert.are_not.equal(skill_ns, tz.diag_namespace())
tests/integration/highlighting_spec.lua:458:        assert.equals(0, #vim.diagnostic.get(buf, { namespace = tz.diag_namespace() }))
tests/integration/highlighting_spec.lua:470:            return #vim.diagnostic.get(buf, { namespace = tz.diag_namespace() }) == 0
tests/integration/highlighting_spec.lua:472:        assert.equals(0, #vim.diagnostic.get(buf, { namespace = tz.diag_namespace() }))
tests/integration/highlighting_spec.lua:479:            return #vim.diagnostic.get(buf, { namespace = tz.diag_namespace() }) == 1
tests/integration/highlighting_spec.lua:482:        local diagnostics = vim.diagnostic.get(buf, { namespace = tz.diag_namespace() })
tests/integration/highlighting_spec.lua:491:        if ok and skill_render.diag_namespace then
tests/integration/highlighting_spec.lua:494:                    pcall(vim.diagnostic.reset, skill_render.diag_namespace(), buf)
tests/integration/highlighting_spec.lua:514:        local diagnostics = vim.diagnostic.get(buf, { namespace = skill_render.diag_namespace() })
tests/integration/highlighting_spec.lua:526:        local ns = skill_render.diag_namespace()
tests/integration/highlighting_spec.lua:533:        vim.diagnostic.set(ns, buf, { {
lua/parley/skills/review/diag_display.lua:25:    return require("parley.skill_render").diag_namespace()
tests/integration/skill_invoke_review_spec.lua:130:        require("parley.skill_render").attach_diagnostics(b, { { pos = 1, explain = "why" } }, "edited line")
tests/integration/review_projection_spec.lua:37:        skill_render.attach_diagnostics(buf, { { pos = content:find("reviewed"), explain = "agent edit" } }, content)
tests/integration/review_projection_spec.lua:55:        skill_render.attach_diagnostics(buf, { { pos = 1, explain = "why" } }, "round output")
tests/integration/review_projection_spec.lua:74:        skill_render.attach_diagnostics(buf, { { pos = 1, explain = "edit A" } }, "state A")
tests/integration/review_projection_spec.lua:80:        skill_render.attach_diagnostics(buf, { { pos = 1, explain = "edit B" } }, "state B")
tests/integration/review_projection_spec.lua:97:        skill_render.attach_diagnostics(buf, { { pos = 1, explain = "why" } }, "round output")
tests/integration/define_spec.lua:197:    local ns = require("parley.skill_render").diag_namespace()
tests/integration/define_spec.lua:264:        assert.are.equal(2, diags[1].end_lnum)
lua/parley/timezone_diagnostics.lua:126:function M.diag_namespace()
lua/parley/timezone_diagnostics.lua:155:            end_lnum = diagnostic.lnum,
lua/parley/timezone_diagnostics.lua:168:    vim.diagnostic.set(diag_ns_id, buf, nvim_diagnostics)
lua/parley/skill_render.lua:41:function M.diag_namespace()
lua/parley/skill_render.lua:102:function M.format_diagnostic_message(text, width)
lua/parley/skill_render.lua:136:            end_lnum = footnote.end_lnum or footnote.lnum,
lua/parley/skill_render.lua:145:    vim.diagnostic.set(diag_ns_id, buf, diagnostics)
lua/parley/skill_render.lua:149:--- edit's line range (lnum..end_lnum) so "cursor in the region" matches, and its
lua/parley/skill_render.lua:155:function M.attach_diagnostics(buf, edits, original_content)
lua/parley/skill_render.lua:164:        -- end_lnum spans the edit's own lines (newlines in the new text); a pure
lua/parley/skill_render.lua:172:            end_lnum = line_num + span,
lua/parley/skill_render.lua:174:            message = M.format_diagnostic_message(edit.explain or "edit applied", width),
lua/parley/skill_render.lua:179:    vim.diagnostic.set(diag_ns_id, buf, diagnostics)
lua/parley/skill_render.lua:191:        -- INFO gutter diagnostic (the "why") via attach_diagnostics, not a
lua/parley/skill_render.lua:224:--- rows: (buf, lnum0, col_start, end_lnum0, col_end).
lua/parley/skill_render.lua:228:--- @param end_lnum0_or_col_end number 0-based end line, or end column
lua/parley/skill_render.lua:230:function M.highlight_span(buf, lnum0, col_start, end_lnum0_or_col_end, col_end)
lua/parley/skill_render.lua:232:    local end_lnum0 = lnum0
lua/parley/skill_render.lua:234:        col_end = end_lnum0_or_col_end
lua/parley/skill_render.lua:236:        end_lnum0 = end_lnum0_or_col_end
lua/parley/skill_render.lua:239:        end_row = end_lnum0,
lua/parley/skill_render.lua:262:                end_lnum = details.end_row,
lua/parley/skill_render.lua:272:            end_lnum = d.end_lnum,
lua/parley/skill_render.lua:293:        M.highlight_span(buf, span.lnum, span.col or 0, span.end_lnum or span.lnum, span.end_col)
lua/parley/skill_render.lua:300:                end_lnum = d.end_lnum or d.lnum,
lua/parley/skill_render.lua:309:        vim.diagnostic.set(diag_ns_id, buf, diagnostics)
lua/parley/init.lua:1644:    skill_render.highlight_span(buf, diag_span.lnum, diag_span.col, diag_span.end_lnum, diag_span.end_col)
tests/unit/skill_render_spec.lua:13:    it("attach_diagnostics sets an INFO diagnostic per edit, on the edit's line", function()
tests/unit/skill_render_spec.lua:18:        skill_render.attach_diagnostics(buf, { { pos = pos, explain = "changed two" } }, original)
tests/unit/skill_render_spec.lua:28:        skill_render.attach_diagnostics(buf, { { pos = 1, explain = "e" } }, "x")
tests/unit/skill_render_spec.lua:54:        skill_render.attach_diagnostics(buf, edits, original)
tests/unit/skill_render_spec.lua:74:    it("format_diagnostic_message word-wraps display text at the requested width", function()
tests/unit/skill_render_spec.lua:75:        local msg = skill_render.format_diagnostic_message("alpha beta gamma delta epsilon zeta", 16)
tests/unit/skill_render_spec.lua:83:    it("attach_diagnostics wraps the message + spans the edit's lines (end_lnum)", function()
tests/unit/skill_render_spec.lua:87:        skill_render.attach_diagnostics(buf, {
tests/unit/skill_render_spec.lua:92:        assert.are.equal(2, d.end_lnum) -- spans the 2-line new_string
tests/unit/skill_render_spec.lua:100:        skill_render.attach_diagnostics(buf, { { pos = content:find("two"), explain = "why two" } }, content)
tests/unit/skill_render_spec.lua:111:        assert.is_not_nil(diags[1].end_lnum, "end_lnum survives snapshot→apply (#133 M6)")
tests/unit/skill_render_spec.lua:119:        local diag_ns = skill_render.diag_namespace()
tests/unit/skill_render_spec.lua:122:        vim.diagnostic.set(diag_ns, buf, { {
tests/unit/skill_render_spec.lua:125:            end_lnum = 0,
tests/unit/skill_render_spec.lua:151:        skill_render.attach_diagnostics(buf, { { pos = 1, explain = "e" } }, "x")
lua/parley/skill_invoke.lua:78:    skill_render.attach_diagnostics(buf, edits, original)
tests/unit/define_spec.lua:82:        local orig = skill_render.format_diagnostic_message
tests/unit/define_spec.lua:84:        skill_render.format_diagnostic_message = function(text, width)
tests/unit/define_spec.lua:91:        skill_render.format_diagnostic_message = orig
tests/unit/define_spec.lua:129:            end_lnum = 2,
tests/unit/define_spec.lua:139:            end_lnum = 2,
tests/unit/define_spec.lua:167:        assert.are.same({ lnum = 0, col = 8, end_lnum = 0, end_col = 19 }, result.diagnostic_span)
tests/unit/define_spec.lua:216:        assert.are.same({ lnum = 0, col = 0, end_lnum = 0, end_col = 11 }, result.diagnostic_span)
tests/unit/define_spec.lua:280:            end_lnum = 0,
tests/unit/define_spec.lua:301:            end_lnum = 0,
tests/unit/define_spec.lua:310:            end_lnum = 0,

exec
/bin/zsh -lc "nl -ba tests/integration/highlighting_spec.lua | sed -n '420,470p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   420            vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
   421                "User: meet at 2026-04-18T00:00:00Z",
   422            })
   423
   424            tz.refresh_buffer(buf, {
   425                to_local = function()
   426                    return {
   427                        year = 2026,
   428                        month = 4,
   429                        day = 17,
   430                        hour = 17,
   431                        min = 0,
   432                        sec = 0,
   433                    }
   434                end,
   435            })
   436
   437            local diagnostics = vim.diagnostic.get(buf, { namespace = tz.diag_namespace() })
   438            assert.equals(1, #diagnostics)
   439            assert.equals(0, diagnostics[1].lnum)
   440            assert.equals(14, diagnostics[1].col)
   441            assert.equals(34, diagnostics[1].end_col)
   442            assert.equals("parley-timezone", diagnostics[1].source)
   443            assert.equals("local time: 2026-04-17 17:00:00", diagnostics[1].message)
   444            local diag_config = vim.diagnostic.config(nil, tz.diag_namespace())
   445            assert.same({ current_line = true }, diag_config.virtual_lines)
   446            assert.equals(false, diag_config.virtual_text)
   447
   448            local skill_ns = require("parley.skill_render").diag_namespace()
   449            assert.are_not.equal(skill_ns, tz.diag_namespace())
   450
   451            vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "💬: meet later" })
   452            tz.refresh_buffer(buf, {
   453                to_local = function()
   454                    error("no timestamps remain")
   455                end,
   456            })
   457
   458            assert.equals(0, #vim.diagnostic.get(buf, { namespace = tz.diag_namespace() }))
   459        end)
   460
   461        it("refreshes diagnostics for registered buffers on text changes", function()
   462            local tz = require("parley.timezone_diagnostics")
   463            local buf = vim.api.nvim_create_buf(false, true)
   464            vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), buf)
   465            parley._parley_bufs[buf] = "markdown"
   466            vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "no timestamp yet" })
   467
   468            vim.cmd("doautocmd TextChanged")
   469            vim.wait(100, function()
   470                return #vim.diagnostic.get(buf, { namespace = tz.diag_namespace() }) == 0

codex
One risk area stands out: review diagnostics deliberately span `lnum..end_lnum`, but the new renderer filters only on `diagnostic.lnum`. I’m verifying whether that regresses the documented “cursor in edit region” behavior before deciding severity.
exec
/bin/zsh -lc "rg -n \"vim\\._resolve_bufnr|current_line|end_lnum|cursor in.*region|diagnostic span\" lua tests atlas" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
lua/parley/define.lua:121:--- @return table { lnum: integer, col: integer, end_lnum: integer, end_col: integer }
lua/parley/define.lua:126:        end_lnum = l2 - 1,
lua/parley/define.lua:254:                    end_lnum = lnum - 1,
lua/parley/define.lua:378:            end_lnum = l2 - 1,
lua/parley/artifact_ref.lua:181:    local line = vim.api.nvim_get_current_line()
lua/parley/neighborhood.lua:138:        local line = vim.api.nvim_get_current_line()
lua/parley/spell.lua:96:    local line = vim.api.nvim_get_current_line()
lua/parley/skills/review/diag_display.lua:5:-- Default ON: `virtual_lines { current_line = true }`, so the (hard-wrapped) why
lua/parley/skills/review/diag_display.lua:47:local function current_line_for(buf)
lua/parley/skills/review/diag_display.lua:65:local function render(buf, diagnostics, current_line_only)
lua/parley/skills/review/diag_display.lua:72:    local line = current_line_only and current_line_for(buf) or nil
lua/parley/skills/review/diag_display.lua:73:    if current_line_only and not line then
lua/parley/skills/review/diag_display.lua:79:        if not current_line_only or diagnostic.lnum == line then
lua/parley/skills/review/diag_display.lua:108:            bufnr = vim._resolve_bufnr(bufnr)
lua/parley/skills/review/diag_display.lua:110:            local current_line_only = handler_opts.current_line == true
lua/parley/skills/review/diag_display.lua:112:            if current_line_only then
lua/parley/skills/review/diag_display.lua:121:            render(bufnr, diagnostics, current_line_only)
lua/parley/skills/review/diag_display.lua:127:            clear(vim._resolve_bufnr(bufnr))
lua/parley/skills/review/diag_display.lua:146:        [HANDLER_NAME] = M.enabled and { current_line = true } or false,
lua/parley/chat_parser.lua:342:        cb_state.current_lines = {}
lua/parley/chat_parser.lua:346:        cb_state.current_line_start = nil
lua/parley/chat_parser.lua:359:        local body = table.concat(cb_state.current_lines, "\n")
lua/parley/chat_parser.lua:393:            local trimmed_start = cb_state.current_line_start
lua/parley/chat_parser.lua:409:        cb_state.current_lines = {}
lua/parley/chat_parser.lua:410:        cb_state.current_line_start = nil
lua/parley/chat_parser.lua:433:        if cb_state.current_line_start == nil then
lua/parley/chat_parser.lua:434:            cb_state.current_line_start = line_no
lua/parley/chat_parser.lua:436:        table.insert(cb_state.current_lines, line)
lua/parley/chat_parser.lua:618:            cb_state = { blocks = {}, current_kind = nil, current_lines = {} }
lua/parley/init.lua:896:                        local line = vim.api.nvim_get_current_line()
lua/parley/init.lua:1644:    skill_render.highlight_span(buf, diag_span.lnum, diag_span.col, diag_span.end_lnum, diag_span.end_col)
lua/parley/init.lua:2032:        local line = vim.api.nvim_get_current_line()
lua/parley/init.lua:2721:local function try_open_inline_branch_link(current_line, cursor_col, parent_buf)
lua/parley/init.lua:2724:    local inline_links = chat_parser.extract_inline_branch_links(current_line, branch_prefix)
lua/parley/init.lua:3652:local function open_branch_ref(current_line, buf)
lua/parley/init.lua:3653:    local parsed = M._parse_branch_ref(current_line)
lua/parley/init.lua:3740:M.open_chat_reference = function(current_line, cursor_col, _in_insert_mode, full_line)
lua/parley/init.lua:3742:    if try_open_src_link(current_line, cursor_col, vim.api.nvim_get_current_buf()) then
lua/parley/init.lua:3747:    if try_open_inline_branch_link(current_line, cursor_col, vim.api.nvim_get_current_buf()) then
lua/parley/init.lua:3752:    if open_branch_ref(current_line, vim.api.nvim_get_current_buf()) then
lua/parley/init.lua:3760:    if current_line:match("^@@") then
lua/parley/init.lua:3762:        chat_path = current_line:match("^@@%s*([^@]+)@@")
lua/parley/init.lua:3763:            or current_line:match("^@@%s*([^:]+):")
lua/parley/init.lua:3764:            or current_line:match("^@@(.+)$")
lua/parley/init.lua:3770:        chat_path = M._parse_at_reference(current_line, cursor_col)
lua/parley/init.lua:3850:    local current_line = vim.api.nvim_buf_get_lines(buf, line_num - 1, line_num, false)[1]
lua/parley/init.lua:3865:        M.open_chat_reference(current_line, cursor_col, in_insert_mode, current_line)
lua/parley/init.lua:3876:    if open_branch_ref(current_line, buf) then
lua/parley/init.lua:3881:    if try_open_inline_branch_link(current_line, cursor_col, buf) then
lua/parley/init.lua:3889:    if current_line:match("^@@") then
lua/parley/init.lua:3890:        filepath = (current_line:match("^@@(.+)@@") or current_line:match("^@@(.+)$")):gsub("^%s*(.-)%s*$", "%1")
lua/parley/init.lua:3893:        filepath = M._parse_at_reference(current_line, cursor_col)
lua/parley/init.lua:3976:                if current_line:match("@@[^:]+:%s*(.+)") then
lua/parley/init.lua:3977:                    topic = current_line:match("@@[^:]+:%s*(.+)")
lua/parley/skill_render.lua:136:            end_lnum = footnote.end_lnum or footnote.lnum,
lua/parley/skill_render.lua:148:--- Attach INFO diagnostics from edit explanations. Each diagnostic spans the
lua/parley/skill_render.lua:149:--- edit's line range (lnum..end_lnum) so "cursor in the region" matches, and its
lua/parley/skill_render.lua:164:        -- end_lnum spans the edit's own lines (newlines in the new text); a pure
lua/parley/skill_render.lua:172:            end_lnum = line_num + span,
lua/parley/skill_render.lua:224:--- rows: (buf, lnum0, col_start, end_lnum0, col_end).
lua/parley/skill_render.lua:228:--- @param end_lnum0_or_col_end number 0-based end line, or end column
lua/parley/skill_render.lua:230:function M.highlight_span(buf, lnum0, col_start, end_lnum0_or_col_end, col_end)
lua/parley/skill_render.lua:232:    local end_lnum0 = lnum0
lua/parley/skill_render.lua:234:        col_end = end_lnum0_or_col_end
lua/parley/skill_render.lua:236:        end_lnum0 = end_lnum0_or_col_end
lua/parley/skill_render.lua:239:        end_row = end_lnum0,
lua/parley/skill_render.lua:262:                end_lnum = details.end_row,
lua/parley/skill_render.lua:272:            end_lnum = d.end_lnum,
lua/parley/skill_render.lua:293:        M.highlight_span(buf, span.lnum, span.col or 0, span.end_lnum or span.lnum, span.end_col)
lua/parley/skill_render.lua:300:                end_lnum = d.end_lnum or d.lnum,
lua/parley/issues.lua:897:    local line = vim.api.nvim_get_current_line()
lua/parley/issues.lua:942:        local line = vim.api.nvim_get_current_line()
lua/parley/chat_finder.lua:796:                            local current_line = vim.api.nvim_buf_get_lines(
lua/parley/chat_finder.lua:805:                            local new_line = current_line:sub(1, col) .. inline_link .. current_line:sub(col + 1)
atlas/modes/review.md:171:`lnum..end_lnum`) and hides otherwise. `:ParleyShowDiagnostics` toggles it. The
atlas/modes/review.md:173:diagnostics because the underlying diagnostic spans remain unchanged. Composes
lua/parley/interview.lua:189:    local cursor_line = vim.api.nvim_get_current_line()
lua/parley/vision.lua:1749:    local line = vim.api.nvim_get_current_line()
lua/parley/vision.lua:1827:    local line = vim.api.nvim_get_current_line()
tests/integration/review_diag_display_spec.lua:43:    it("renders current-line diagnostics from the left column without moving the diagnostic span", function()
tests/integration/review_diag_display_spec.lua:56:            end_lnum = 0,
tests/integration/review_diag_display_spec.lua:79:        assert.are.equal(0, diagnostics[1].end_lnum)
tests/integration/define_spec.lua:264:        assert.are.equal(2, diags[1].end_lnum)
tests/integration/highlighting_spec.lua:445:        assert.same({ current_line = true }, diag_config.virtual_lines)
tests/unit/define_spec.lua:129:            end_lnum = 2,
tests/unit/define_spec.lua:139:            end_lnum = 2,
tests/unit/define_spec.lua:167:        assert.are.same({ lnum = 0, col = 8, end_lnum = 0, end_col = 19 }, result.diagnostic_span)
tests/unit/define_spec.lua:216:        assert.are.same({ lnum = 0, col = 0, end_lnum = 0, end_col = 11 }, result.diagnostic_span)
tests/unit/define_spec.lua:280:            end_lnum = 0,
tests/unit/define_spec.lua:301:            end_lnum = 0,
tests/unit/define_spec.lua:310:            end_lnum = 0,
tests/unit/skill_render_spec.lua:83:    it("attach_diagnostics wraps the message + spans the edit's lines (end_lnum)", function()
tests/unit/skill_render_spec.lua:92:        assert.are.equal(2, d.end_lnum) -- spans the 2-line new_string
tests/unit/skill_render_spec.lua:111:        assert.is_not_nil(diags[1].end_lnum, "end_lnum survives snapshot→apply (#133 M6)")
tests/unit/skill_render_spec.lua:125:            end_lnum = 0,
lua/parley/timezone_diagnostics.lua:14:            virtual_lines = { current_line = true },
lua/parley/timezone_diagnostics.lua:155:            end_lnum = diagnostic.lnum,

exec
/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"' in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc "nvim --headless -c \"lua local dd=require('parley.skills.review.diag_display'); local sr=require('parley.skill_render'); local ns=sr.diag_namespace(); local b=vim.api.nvim_create_buf(false,true); vim.api.nvim_set_current_buf(b); vim.api.nvim_buf_set_lines(b,0,-1,false,{'one','two','three'}); dd.set(true); vim.diagnostic.set(ns,b,{{lnum=0,end_lnum=2,col=0,end_col=5,message='multi',severity=vim.diagnostic.severity.INFO}}); local dns=vim.api.nvim_create_namespace('parley_diagnostic_virtual_lines'); print('line1 marks', #vim.api.nvim_buf_get_extmarks(b,dns,0,-1,{details=true})); vim.api.nvim_win_set_cursor(0,{2,0}); vim.cmd('doautocmd CursorMoved'); print('line2 marks', #vim.api.nvim_buf_get_extmarks(b,dns,0,-1,{details=true})); vim.api.nvim_win_set_cursor(0,{3,0}); vim.cmd('doautocmd CursorMoved'); print('line3 marks', #vim.api.nvim_buf_get_extmarks(b,dns,0,-1,{details=true}));\" -c qa" in /Users/xianxu/workspace/parley.nvim
 succeeded in 341ms:

LuaSnip: could not open log at /Users/xianxu/.local/state/nvim/luasnip.log. Not logging for this session.
line1 marks 1
line2 marks 0
line3 marks 0
Error detected while processing command line:
E886: System error while opening temporary ShaDa file /Users/xianxu/.local/state/nvim/shada/main.shada.tmp.o for writing: operation not permitted
Parley.nvim: Failed to open file for writing: /Users/xianxu/.local/share/nvim/parley/persisted/state.json
 succeeded in 1458ms:

Parley.nvim: Failed to open file for writing: /Users/xianxu/.local/share/nvim/parley/persisted/state.jsonScheduling: tests/integration/review_diag_display_spec.lua

========================================
Testing:     /Users/xianxu/workspace/parley.nvim/tests/integration/review_diag_display_spec.lua
Success    ||    review.diag_display toggles the enabled state
Success    ||    review.diag_display configures Parley's custom current-line display on its namespace when on; off when disabled
Success    ||    review.diag_display renders current-line diagnostics from the left column without moving the diagnostic span

Success:     3
Failed :     0
Errors :     0
========================================

codex
Focused tests pass, but the multi-line diagnostic probe confirms the renderer disappears when the cursor moves within a diagnostic’s `end_lnum` range instead of staying visible for the region. I’m doing a final docs/README/atlas and full-test check now so the verdict includes verification context.
exec
/bin/zsh -lc 'git diff --unified=60 b9094e9bfc89b0f27013c6fd41c38a83b8b61510..HEAD -- atlas/chat/inline_define.md atlas/modes/review.md README.md workshop/issues/000173-diagnostic-virtual-lines-leftcol.md workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
diff --git a/atlas/chat/inline_define.md b/atlas/chat/inline_define.md
index 270e924..6df2cf4 100644
--- a/atlas/chat/inline_define.md
+++ b/atlas/chat/inline_define.md
@@ -1,150 +1,150 @@
 # Inline Term Definition

 Select a phrase in a chat transcript, press **`<M-CR>`** (visual mode), and a
-concise, context-aware definition appears as an inline diagnostic (grey
-`virtual_lines`) under the phrase. The selected text stays in place and gets a
-markdown footnote reference (`ASIN[^asin]`), while the definition is stored in a
-managed footnote footer at the end of the chat transcript. Persisted managed
-footnotes are rehydrated into diagnostics when any markdown buffer is entered or
-refreshed. The whole new annotation is **undoable** — `u` reverts the footnote
-edit and clears both decorations (see Undo below). For jargon you don't know
-(e.g. `ASIN`), it's a one-keystroke lookup. Added in
+concise, context-aware definition appears as an inline diagnostic under the
+phrase. The selected text stays in place and gets a markdown footnote reference
+(`ASIN[^asin]`), while the definition is stored in a managed footnote footer at
+the end of the chat transcript. Persisted managed footnotes are rehydrated into
+diagnostics when any markdown buffer is entered or refreshed. The whole new
+annotation is **undoable** — `u` reverts the footnote edit and clears both
+decorations (see Undo below). For jargon you don't know (e.g. `ASIN`), it's a
+one-keystroke lookup. Added in
 [#161](../../workshop/issues/000161-inline-term-definition.md) (R1 added the
 highlight/undo); [#166](../../workshop/issues/000166-visual-selection-definition-system-manages-footnote.md)
 made the definition durable as a managed footnote; [#167](../../workshop/issues/000167-define-diagnostic-highlight-span.md)
 narrowed the visible decoration to the selected term plus footnote reference;
 [#172](../../workshop/issues/000172-markdown-footnote-diagnostics.md)
 rehydrates persisted managed footnotes in all markdown buffers.

 ## Flow

 1. **`define_visual(buf)`** (`lua/parley/init.lua`) reads the visual selection
    (`getpos`), extracts the phrase (`define.slice_selection`), guards
    empty/whitespace, and computes a **bounded context** = the *enclosing
    exchange* of the selection (`define.context_for_selection` over `parse_chat`
    + `find_exchange_at_line`), falling back to the whole buffer.
 2. It fires a headless **`define` skill** turn via `skill_invoke.invoke` with
    `opts.document = context`, `opts.no_reload = true`, and an `on_done`.
 3. The `define` skill (`lua/parley/skills/define/init.lua`) is **unforced** (no
    `force_tool`) so the server-side `web_search` tool can run when the global
    `:ToggleWebSearch` is on; its `source(ctx)` folds the phrase into the system
    prompt and asks the model to call `emit_definition({term, definition})`.
 4. **`render_definition`** (`on_done`), on a successful lookup: re-verifies the
    selection still holds the phrase (else skips — the buffer changed under the
    in-flight call), then **(a)** adds a `[^id]` reference after the selected term
    and inserts/updates a final managed footnote footer via one buffer rewrite
    (`define.apply_definition_footnote`) — a single undo entry that anchors
    everything; **(b)** highlights the selected term/reference span with
    `DiffChange` (`skill_render.highlight_span`); **(c)** refreshes persisted
    footnote diagnostics (`skill_render.refresh_footnote_diagnostics`), which
    parses the managed footer and sets INFO `vim.diagnostic` entries on matching
    inline `term[^id]` spans (`define.format_definition` →
    `skill_render.format_diagnostic_message`) on the `parley_skill` namespace;
    **(d)** records the undo/redo projection states.
-   `diag_display`'s `virtual_lines{current_line=true}` reveals the diagnostic
-   (cursor parked on the term's line). A no-`emit_definition` response leaves no
-   footnote reference/footer.
+   `diag_display`'s Parley-owned left-column virtual-line display reveals the
+   diagnostic (cursor parked on the term's line). A no-`emit_definition` response
+   leaves no footnote reference/footer.

 ## Undo (`u`) — reuses review's projection

 Native `u` reverts *text*, not decorations. The footnote reference/footer rewrite
 is the one text change, so `u` reverts it; the decorations are cleared/restored by review's
 **projection watcher** (`skills/review/projection.lua`, #133 M5), which define
 reuses: `render_definition` calls `projection.record_empty_for(buf, original)`
 (pre-footnote hash → empty snapshot), `record(buf)` (footnoted hash → the
 highlight + diagnostic), `ensure_watch(buf)`. Undoing the footnote edit lands on
 the pre-footnote content-hash → the empty snapshot renders → both decorations clear;
 `<C-r>` re-renders. `skill_render.snapshot`/`apply_snapshot` preserve span
 highlights (`hl_spans`) and diagnostic `col`/`end_col`, while still accepting
 legacy whole-line `hl_lines`. `set_applying` guards the edit so a prior define's
 watcher doesn't mistake it for a user edit.

 ## Pure core vs IO shell (ARCH-PURE)

 - **Pure** (`lua/parley/define.lua`, unit-tested with plain tables): `slice_selection`,
   `context_for_selection`, `format_definition`, `bracket_edit` (plans the `[term]`
   wrap as a legacy set_lines edit), `diagnostic_span_after_bracket` (legacy range
   mapping), `apply_definition_footnote` (durable footer transform), and
   `strip_definition_footnote_footer` / `footnote_diagnostics` (read only a final
   `---` block followed solely by footnotes).
 - **IO shell** (`lua/parley/init.lua`): `define_visual`, `render_definition`;
   `lua/parley/buffer_edit.lua` owns the full-buffer footnote rewrite;
   `lua/parley/skill_render.lua` publishes footnote diagnostics; and
   `lua/parley/highlighter.lua` refreshes them from chat and markdown lifecycle
   hooks.
 - **External service** (Anthropic) exercised via the process-level fake reused
   from `skill_invoke_spec` (SSE tool-call injection).

 ## Managed Footnote Footer

 The footer is a final markdown block:

 ```markdown
 ---

 [^asin]: Amazon Standard Identification Number.
 ```

 The footer detector is deliberately conservative: only the last standalone
 `---` line followed by blank lines and footnote definitions counts as the
 managed footer. Ordinary horizontal rules and mixed prose after `---` remain
 chat content. `chat_respond.build_messages` strips this managed footer from
 message strings before LLM submission, so durable definitions do not become
 prompt context. `define.footnote_diagnostics` uses the same footer detector to
 scan inline references before the footer and produce diagnostics for each
 matching `[^id]`.

 ## Keybinding

 `<M-CR>` was split out of `chat_shortcut_respond` into its own `chat_define`
 registry entry (a single registry entry maps every key×mode to one per-mode
 callback, so the split can't live inside `chat_respond`). The `chat_define`
 per-mode callback is `{ n=respond, i=respond, v=define_visual, x=define_visual }`
 — visual `<M-CR>` defines; normal/insert `<M-CR>` still responds; visual
 `<C-g><C-g>` keeps the line-scoped resubmit. The v/x callbacks `<Esc>`-commit
 the `'<`/`'>` marks before reading `getpos`.

 ## Read-only invoke seam (`opts.no_reload`)

 `skill_invoke.invoke` normally writes the buffer before the turn and `:edit!`-
 reloads it after (for `propose_edits`). A read-only lookup passes
 `opts.no_reload = true` to skip both, so an in-progress prompt is never
 persisted. `opts.document` lets the caller send a bounded context instead of the
 whole buffer. Both default to prior behavior when absent.

 ## Structured output tool

 `emit_definition` (`lua/parley/tools/builtin/emit_definition.lua`, in
 `BUILTIN_NAMES`) is an **output-only** tool: `{term, definition}` schema,
 `self_paginates = true` (no pager params), no-op `handler`. The value rides the
 tool-call args (`result.calls[1].input`), read in `on_done`.

 ## Notes

 - The fresh define highlight spans the selected text plus immediate `[^id]`
   reference; rehydrated diagnostics do not recreate the DiffChange highlight.
 - `skill_render.refresh_footnote_diagnostics` owns only diagnostics tagged
   `parley-footnote` and preserves other `parley_skill` diagnostics, so review
   diagnostics are not cleared by markdown footnote refresh.
-- A diagnostic's `virtual_lines` auto-hide when the cursor leaves its line. The
-  footnote persists in the file if saved.
+- A diagnostic's Parley virtual-line block auto-hides when the cursor leaves its
+  line. The footnote persists in the file if saved.

 ## Key files

 - `lua/parley/define.lua` — pure core (slice / context / format / footnote footer / diagnostics).
 - `lua/parley/init.lua` — `define_visual`, `render_definition`, `chat_define` wiring.
 - `lua/parley/highlighter.lua` — chat/markdown buffer lifecycle refresh hooks.
 - `lua/parley/skill_render.lua` — footnote diagnostic refresh in the shared namespace.
 - `lua/parley/chat_respond.lua` — strips managed footnote footer from LLM messages.
 - `lua/parley/skills/define/init.lua` — the unforced `define` skill.
 - `lua/parley/tools/builtin/emit_definition.lua` — output-only structured tool.
 - `lua/parley/skill_invoke.lua` — `opts.no_reload` / `opts.document` seams.
 - `lua/parley/config.lua`, `lua/parley/keybinding_registry.lua` — the `<M-CR>` split.
 - `tests/unit/define_spec.lua`, `tests/integration/define_spec.lua` — coverage.

 ## Related

 - [Drill-In Markers](drill_in.md) — the heavier "gather into the next turn"
   sibling; shares `define.slice_selection` for the visual-selection extraction.
 - [Document Review](../modes/review.md) — the skill/`skill_invoke`/`diag_display`
   machinery this reuses.
diff --git a/atlas/modes/review.md b/atlas/modes/review.md
index b470783..ef656df 100644
--- a/atlas/modes/review.md
+++ b/atlas/modes/review.md
@@ -105,112 +105,116 @@ mode.directives(flags) ⊕ operator-instruction`. No mode selected → base SKIL
   editorial-sequence position that orders the menu (developmental=1 … free-form=6).
 - **Six shipped modes:** developmental, line-editing, copy-editing, proofreading,
   fact-check (inserts `🤖{}` findings only — no edits; resolution handed to the
   main agent), free-form (operator instruction governs).
 - **`ctx.skill_dir` injection** (`skill_providers.lua`): the disk provider injects
   the skill's own absolute dir into `source(ctx)` (alongside `ctx.skill_md`) so the
   review skill reads its `modes/` subdir without re-deriving the path.

 ## Journal (#133 M3)

 Each review round is recorded to a **self-contained markdown sidecar** beside the
 doc — `<doc>.parley-journal.md` — tracked in git WITH the document. This replaces
 docflow's git-branch journaling: docflow's *value* (attributed per-round diffs +
 rationale) without its branch *mechanism* (no working-tree churn, portable to a
 standalone plugin install). vim's native undo owns in-session text time-travel;
 the journal owns the durable, cross-session record.

 - **`lua/parley/skills/review/journal.lua`** — PURE `serialize_entry` /
   `serialize_base` / `parse` / `diff` (`vim.diff`, unified) / `is_drift`
   (`vim.fn.sha256` compare), plus the thin IO seam `sidecar_path` / `read` /
   `append`. 4-backtick fences wrap the journal's own blocks so a 3-backtick code
   fence inside the doc or diff can't break parsing.
 - **Per round** it stores: round number (derived), mode, side, ISO timestamp,
   content hash, rationale (the per-edit `explain`s), and the unified diff. Round 0
   is the base snapshot (written once, on the first round).
 - **Wiring**: `skill_invoke`'s `on_done` payload carries `original` /
   `new_content` / `decorations` (pure-fed); review's `on_done` builds the entry
   and calls `journal.append` (skips no-op rounds + path-less buffers).
 - **Drift**: `is_drift(recorded_hash, current)` detects an external edit (e.g.
   Claude Code resolving markers) since the last recorded round.
 - **Deferred (v2)**: durable "revert/show round N" (reconstruct via base +
   replayed diffs). The journal stores the **diff + rationale** per round (not a
   structured decoration set — see the plan's Revisions).

 ## Decoration projection — undo/redo coherence (#133 M5)

 nvim's undo reverts **text only**; review decorations are drawn once per round
 and otherwise ride, so without help they go stale after an undo (esp. across the
 round's `:edit!` reload). `lua/parley/skills/review/projection.lua` keeps style
 coherent: a per-buffer record `{ content-hash → decoration snapshot }`, and on
 each text change it **projects** the right style onto the current state —

 - **undo/redo** lands on a recorded content-hash → re-render that snapshot (via
   `skill_render.snapshot`/`apply_snapshot`);
 - a **novel forward edit** (manual tweak / `<M-a>` accept — behavior B) keeps the
   live decorations riding, and snapshots them under the new state so a later undo
   restores them.

 A round records its **pre** state (base → empty style, so undoing across the
 round clears it) and its **post** state (its decorations); records persist across
 rounds for multi-round undo. `set_applying` suppresses the watcher during the
 round's own reload; the watcher is attached lazily (only after the first round).
 The decide rule (`projection.decide`) is pure. Session-scoped (matches nvim's
 session-scoped undo); per-state snapshots aren't journaled.

 ## Diagnostic display (#133 M6)

 The edit "why" (the per-edit `explain`) is an INFO diagnostic on parley's
 `parley_skill` namespace. `lua/parley/skills/review/diag_display.lua` controls how
 it shows — scoped to that namespace, so the user's LSP/global diagnostics are
-untouched. Default **on**: `virtual_lines { current_line = true }`, so the
-(hard-wrapped, via `skill_render.format_diagnostic_message`) why **auto-expands
-below an edit when the cursor is in that edit's region** (`attach_diagnostics` spans `lnum..end_lnum`)
-and hides otherwise. `:ParleyShowDiagnostics` toggles it. The built-in `]d`/`[d`
-(jump) and `<C-W>d` (float, wraps) also work on these diagnostics. Composes with
-M5 — re-renders on undo/redo.
+untouched. Default **on**: Parley's custom `parley/virtual_lines` diagnostic
+handler renders a left-column virtual-line block headed `Diagnostics:` for the
+current line. It avoids Neovim's stock virtual-lines indentation-by-diagnostic
+column, which can hide messages on long wrapped prose. The hard-wrapped why
+(`skill_render.format_diagnostic_message`) **auto-expands below an edit when the
+cursor is in that edit's region** (`attach_diagnostics` spans
+`lnum..end_lnum`) and hides otherwise. `:ParleyShowDiagnostics` toggles it. The
+built-in `]d`/`[d` (jump) and `<C-W>d` (float, wraps) still work on these
+diagnostics because the underlying diagnostic spans remain unchanged. Composes
+with M5 — re-renders on undo/redo.

 ## Progress bar (#133 M7)

 A review round is headless and takes ~30s, so it shows a **detached progress
 bar** — `lua/parley/progress.lua`, a floating bar pinned just above the
 statusline with an animated spinner + message + elapsed seconds. It's a **general
 reusable mechanism** (`progress.start/update/stop/is_active`, one active at a
 time; pure `frame`/`format` + thin float/timer IO), not review-specific — review
 is just its first user. `skill_invoke` starts it when the LLM query launches and
 stops it on exit/abort/cancel (guarded by the same generation counter as the
 in-flight cancel). Concurrency: triggering a review while one runs gives the
 kill-or-cancel prompt (no two concurrent rounds).

 ## Config

 ```lua
 review_agent = "",              -- agent name (deprecated; use skills config)
 review_highlight_duration = 2000, -- highlight fade time in ms
 review_shortcut_edit   = { modes = { "n" }, shortcut = "<C-g>ve" },
 review_shortcut_finder = { modes = { "n", "i" }, shortcut = "<C-g>vf" },
 review_shortcut_menu   = { modes = { "n" }, shortcut = "<M-o>" },   -- skill picker (#133)
 review_shortcut_next   = { modes = { "n", "i" }, shortcut = "<M-CR>" }, -- review-mode menu (#133)
 -- Marker insertion: see drill_in_callbacks in lua/parley/init.lua
 -- (shared <M-q> / <C-g>q binding)
 ```

 ## Key Files

 - `lua/parley/skills/review/init.lua` — skill definition (+ `source(ctx)` mode composition, `mode` arg), marker parsing, `run_via_invoke` (marker pre-check + resubmit), keybindings
 - `lua/parley/skills/review/mode.lua` — Mode parse/directives (PURE) + load/list IO seam (#133)
 - `lua/parley/skills/review/modes/*.md` — the six review-mode prompt files (#133)
 - `lua/parley/skills/review/journal.lua` — per-round journal: PURE serialize/parse/diff/drift + sidecar IO seam (#133)
 - `lua/parley/review_menu.lua` — composite review-mode menu (selector + instruction editor); `<M-CR>` (#133)
 - `lua/parley/skills/review/projection.lua` — decoration projection: re-render style on undo/redo per content-state (#133 M5)
 - `lua/parley/skills/review/diag_display.lua` — inline "why" display toggle (`:ParleyShowDiagnostics`, cursor-region auto-show) (#133 M6)
 - `lua/parley/progress.lua` — detached progress bar (general reusable long-op feedback; review is the first user) (#133 M7)
 - `lua/parley/skills/review/SKILL.md` — system prompt (light edit + heavy revision sections)
 - `lua/parley/skill_invoke.lua` — the P2 driver (one tool-use exchange via the existing dispatcher)
 - `lua/parley/skill_render.lua` — diagnostics + edit highlights
 - `lua/parley/tools/builtin/propose_edits.lua` — batch edit-apply (inline `.parley-backup`)
 - `lua/parley/review.lua` — backward-compatible shim
 - `lua/parley/highlighter.lua` — `ParleyReviewUser`/`ParleyReviewAgent` groups
 - `lua/parley/config.lua` — default keybindings and config
 - `tests/unit/review_spec.lua` — unit tests for the marker parser
 - `tests/integration/skill_invoke_review_spec.lua` — review's marker pre-check + resubmit
 - `tests/unit/skill_edits_spec.lua` / `tests/unit/tools_builtin_propose_edits_spec.lua` — batch edit-apply
diff --git a/workshop/issues/000173-diagnostic-virtual-lines-leftcol.md b/workshop/issues/000173-diagnostic-virtual-lines-leftcol.md
index 5feffd6..0795f4a 100644
--- a/workshop/issues/000173-diagnostic-virtual-lines-leftcol.md
+++ b/workshop/issues/000173-diagnostic-virtual-lines-leftcol.md
@@ -1,28 +1,92 @@
 ---
 id: 000173
 status: working
 deps: []
 github_issue:
 created: 2026-07-08
 updated: 2026-07-08
-estimate_hours:
+estimate_hours: 0.38
 started: 2026-07-08T13:21:02-07:00
 ---

 # diagnostic virtual lines blank on long wrapped markdown

 ## Problem

+After #172, managed markdown footnotes are correctly restored as diagnostics,
+but their inline virtual-line display can look blank on long wrapped markdown
+paragraphs. The diagnostic payload is present and floats display it, but
+Neovim's built-in `virtual_lines` handler prefixes the rendered message with
+spaces equal to the diagnostic byte column. On a long prose line, the selected
+text may be visible on a wrapped screen row while the virtual-line message starts
+far to the right outside the viewport.
+
 ## Spec

+- Parley diagnostics should remain anchored on the selected text / `[^footnote]`
+  span so signs, underline, cursor-line filtering, jumps, and floats keep their
+  existing behavior.
+- The inline diagnostic display for Parley's namespace should render current-line
+  messages from the left column, not from the diagnostic byte column.
+- The display text should keep the existing wrapped diagnostic message and a
+  clear `Diagnostics:` label.
+- The fix should apply to the shared Parley diagnostic namespace, covering review
+  diagnostics and footnote diagnostics without changing global/LSP diagnostics.
+
+ARCH-DRY: keep one Parley diagnostic display controller in
+`skills/review/diag_display.lua`; do not add a separate footnote-only renderer.
+ARCH-PURE: no parser/data changes; keep the change in the thin Neovim display
+shell and test its extmark output directly.
+ARCH-PURPOSE: solve the actual blank-row symptom for long wrapped markdown, not
+only color the hidden text.
+
 ## Done when

--
+- A Parley diagnostic on a long line with a high column renders a visible
+  left-column virtual line.
+- The diagnostic itself remains at its original span for underline/float/jump
+  behavior.
+- Toggling `:ParleyShowDiagnostics` still disables/enables the inline display.
+- Focused tests and full verification pass.
+
+## Estimate
+
+Produced via `estimate-logic-v3.1` against the repo-local calibration source
+reported by `sdlc estimate-source` (stale but canonical for this repo).
+
+```estimate
+model: estimate-logic-v3.1
+familiarity: 1.0
+item: issue-spec design=0.04 impl=0.00
+item: lua-neovim design=0.06 impl=0.18
+item: milestone-review design=0.00 impl=0.10
+total: 0.38
+```

 ## Plan

-- [ ]
+- [x] Add failing tests proving Parley virtual lines render from the left column.
+- [x] Implement the Parley-owned virtual-line display handler.
+- [x] Update atlas/issue log and run verification.

 ## Log

 ### 2026-07-08
+- Root cause: a headless reproduction of Neovim's stock diagnostic virtual-lines
+  handler showed `virt_lines = { { { string.rep(" ", diagnostic.col), "" }, ... } }`
+  with `virt_lines_overflow = "scroll"`, so long wrapped markdown can display a
+  blank inserted row while the message starts outside the viewport.
+- Red test: `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"`
+  failed because `diag_display` still configured stock `virtual_lines` and no
+  `parley_diagnostic_virtual_lines` extmark was rendered.
+- Implemented `parley/virtual_lines`, a custom diagnostic handler scoped to the
+  Parley namespace. It renders a left-column `Diagnostics:` virtual-line block,
+  updates on `CursorMoved`, disables stock virtual lines for Parley, and leaves
+  the underlying diagnostic span unchanged.
+- Focused green: `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"`.
+- Final green: `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`;
+  `git diff --check -- lua/parley/skills/review/diag_display.lua
+  tests/integration/review_diag_display_spec.lua atlas/modes/review.md
+  atlas/chat/inline_define.md
+  workshop/issues/000173-diagnostic-virtual-lines-leftcol.md
+  workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md`; `make test`.
diff --git a/workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md b/workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md
new file mode 100644
index 0000000..12f0951
--- /dev/null
+++ b/workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md
@@ -0,0 +1,94 @@
+# Diagnostic Virtual Lines Left Column Implementation Plan
+
+> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.
+
+**Goal:** Make Parley's inline diagnostic display visible on long wrapped markdown lines by rendering diagnostic virtual lines from the left column.
+
+**Architecture:** Keep diagnostic data unchanged: spans stay anchored to selected text and footnote references. Replace only Parley's namespace display shell in `diag_display.lua`, so global/LSP diagnostics still use Neovim defaults. This follows ARCH-DRY by keeping one Parley display controller and ARCH-PURE by avoiding parser/data changes.
+
+**Tech Stack:** Lua, Neovim diagnostics, extmarks, Plenary/Busted tests.
+
+---
+
+## Core Concepts
+
+### Pure Entities
+
+| Name | Lives in | Status |
+|------|----------|--------|
+| `ParleyDiagnosticMessageLines` | `lua/parley/skills/review/diag_display.lua` | new |
+
+- **ParleyDiagnosticMessageLines** — deterministic conversion from a diagnostic message string into visible virtual-line rows with a `Diagnostics:` header.
+  - **Relationships:** 1:N from one diagnostic message to display rows.
+  - **DRY rationale:** Both review diagnostics and footnote diagnostics consume the same Parley namespace display.
+  - **Future extensions:** If Parley later adds source-specific labels, this formatter is the one place to widen.
+
+### Integration Points
+
+| Name | Lives in | Status | Wraps |
+|------|----------|--------|-------|
+| `ParleyDiagnosticVirtualLines` | `lua/parley/skills/review/diag_display.lua` | modified | Neovim extmarks |
+
+- **ParleyDiagnosticVirtualLines** — Parley-owned inline diagnostic renderer scoped to `skill_render.diag_namespace()`.
+  - **Injected into:** `diag_display.set(on)`; toggling still owns all inline display setup.
+  - **Future extensions:** Can add color overrides without changing diagnostic producers.
+
+## Chunk 1: Left-Column Renderer
+
+**Files:**
+- Modify: `lua/parley/skills/review/diag_display.lua`
+- Modify: `tests/integration/review_diag_display_spec.lua`
+- Modify: `atlas/modes/review.md`
+- Modify: `atlas/chat/inline_define.md`
+- Modify: `workshop/issues/000173-diagnostic-virtual-lines-leftcol.md`
+
+- [x] **Step 1: Write failing tests**
+
+Add integration coverage that:
+- Sets a Parley diagnostic at a high column on a long line.
+- Enables `diag_display`.
+- Asserts the generated display extmark has `virt_lines_leftcol = true`.
+- Asserts the first virtual-line chunk is `Diagnostics:` instead of leading spaces.
+- Asserts `dd.set(false)` clears the Parley display extmark while leaving the diagnostic data intact.
+
+Run:
+
+```bash
+nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"
+```
+
+Expected: FAIL because the stock diagnostic handler emits leading-space virtual lines and `diag_display` has no custom extmark namespace.
+
+- [x] **Step 2: Implement the renderer**
+
+In `lua/parley/skills/review/diag_display.lua`:
+- Add a private display namespace.
+- Add a private function that clears Parley diagnostic virtual-line extmarks.
+- Add a private render function that reads diagnostics from `skill_render.diag_namespace()`, filters to the current cursor line, and writes `virt_lines` with `virt_lines_leftcol = true`.
+- Configure Neovim diagnostics for the Parley namespace with `virtual_lines = false`, `virtual_text = false`, and existing signs/underline behavior.
+- Register a buffer-local `CursorMoved` autocmd for visible Parley buffers so current-line behavior keeps updating.
+
+- [x] **Step 3: Run green focused tests**
+
+Run:
+
+```bash
+nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"
+```
+
+Expected: PASS.
+
+- [x] **Step 4: Update docs and issue log**
+
+Update atlas text that says Parley uses built-in diagnostic `virtual_lines` so it instead describes the Parley-owned left-column inline renderer. Record red/green evidence in the issue log and tick plan items.
+
+- [x] **Step 5: Final verification**
+
+Run:
+
+```bash
+git diff --check -- lua/parley/skills/review/diag_display.lua tests/integration/review_diag_display_spec.lua atlas/modes/review.md atlas/chat/inline_define.md workshop/issues/000173-diagnostic-virtual-lines-leftcol.md workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md
+make test
+```
+
+Expected: all pass.

exec
/bin/zsh -lc 'rg -n "ShowDiagnostics|Diagnostics:|virtual[-_ ]lines|diagnostic" README.md atlas lua/parley/skills/review/diag_display.lua lua/parley/skill_render.lua workshop/issues/000173-diagnostic-virtual-lines-leftcol.md workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:12:# diagnostic virtual lines blank on long wrapped markdown
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:16:After #172, managed markdown footnotes are correctly restored as diagnostics,
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:18:paragraphs. The diagnostic payload is present and floats display it, but
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:19:Neovim's built-in `virtual_lines` handler prefixes the rendered message with
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:20:spaces equal to the diagnostic byte column. On a long prose line, the selected
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:26:- Parley diagnostics should remain anchored on the selected text / `[^footnote]`
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:29:- The inline diagnostic display for Parley's namespace should render current-line
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:30:  messages from the left column, not from the diagnostic byte column.
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:31:- The display text should keep the existing wrapped diagnostic message and a
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:32:  clear `Diagnostics:` label.
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:33:- The fix should apply to the shared Parley diagnostic namespace, covering review
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:34:  diagnostics and footnote diagnostics without changing global/LSP diagnostics.
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:36:ARCH-DRY: keep one Parley diagnostic display controller in
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:45:- A Parley diagnostic on a long line with a high column renders a visible
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:47:- The diagnostic itself remains at its original span for underline/float/jump
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:49:- Toggling `:ParleyShowDiagnostics` still disables/enables the inline display.
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:68:- [x] Add failing tests proving Parley virtual lines render from the left column.
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:75:- Root cause: a headless reproduction of Neovim's stock diagnostic virtual-lines
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:76:  handler showed `virt_lines = { { { string.rep(" ", diagnostic.col), "" }, ... } }`
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:80:  failed because `diag_display` still configured stock `virtual_lines` and no
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:81:  `parley_diagnostic_virtual_lines` extmark was rendered.
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:82:- Implemented `parley/virtual_lines`, a custom diagnostic handler scoped to the
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:83:  Parley namespace. It renders a left-column `Diagnostics:` virtual-line block,
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:84:  updates on `CursorMoved`, disables stock virtual lines for Parley, and leaves
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:85:  the underlying diagnostic span unchanged.
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:91:  workshop/issues/000173-diagnostic-virtual-lines-leftcol.md
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:92:  workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md`; `make test`.
workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:5:**Goal:** Make Parley's inline diagnostic display visible on long wrapped markdown lines by rendering diagnostic virtual lines from the left column.
workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:7:**Architecture:** Keep diagnostic data unchanged: spans stay anchored to selected text and footnote references. Replace only Parley's namespace display shell in `diag_display.lua`, so global/LSP diagnostics still use Neovim defaults. This follows ARCH-DRY by keeping one Parley display controller and ARCH-PURE by avoiding parser/data changes.
workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:9:**Tech Stack:** Lua, Neovim diagnostics, extmarks, Plenary/Busted tests.
workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:21:- **ParleyDiagnosticMessageLines** — deterministic conversion from a diagnostic message string into visible virtual-line rows with a `Diagnostics:` header.
workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:22:  - **Relationships:** 1:N from one diagnostic message to display rows.
workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:23:  - **DRY rationale:** Both review diagnostics and footnote diagnostics consume the same Parley namespace display.
workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:32:- **ParleyDiagnosticVirtualLines** — Parley-owned inline diagnostic renderer scoped to `skill_render.diag_namespace()`.
workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:34:  - **Future extensions:** Can add color overrides without changing diagnostic producers.
workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:43:- Modify: `workshop/issues/000173-diagnostic-virtual-lines-leftcol.md`
workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:48:- Sets a Parley diagnostic at a high column on a long line.
workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:51:- Asserts the first virtual-line chunk is `Diagnostics:` instead of leading spaces.
workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:52:- Asserts `dd.set(false)` clears the Parley display extmark while leaving the diagnostic data intact.
workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:60:Expected: FAIL because the stock diagnostic handler emits leading-space virtual lines and `diag_display` has no custom extmark namespace.
workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:66:- Add a private function that clears Parley diagnostic virtual-line extmarks.
workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:67:- Add a private render function that reads diagnostics from `skill_render.diag_namespace()`, filters to the current cursor line, and writes `virt_lines` with `virt_lines_leftcol = true`.
workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:68:- Configure Neovim diagnostics for the Parley namespace with `virtual_lines = false`, `virtual_text = false`, and existing signs/underline behavior.
workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:83:Update atlas text that says Parley uses built-in diagnostic `virtual_lines` so it instead describes the Parley-owned left-column inline renderer. Record red/green evidence in the issue log and tick plan items.
workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:90:git diff --check -- lua/parley/skills/review/diag_display.lua tests/integration/review_diag_display_spec.lua atlas/modes/review.md atlas/chat/inline_define.md workshop/issues/000173-diagnostic-virtual-lines-leftcol.md workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md
lua/parley/skills/review/diag_display.lua:1:-- diag_display.lua — inline display of review "why" diagnostics (#133 M6).
lua/parley/skills/review/diag_display.lua:4:-- diagnostic namespace (never touches the user's LSP / global diagnostics).
lua/parley/skills/review/diag_display.lua:5:-- Default ON: `virtual_lines { current_line = true }`, so the (hard-wrapped) why
lua/parley/skills/review/diag_display.lua:7:-- otherwise. `:ParleyShowDiagnostics` toggles it.
lua/parley/skills/review/diag_display.lua:13:local HANDLER_NAME = "parley/virtual_lines"
lua/parley/skills/review/diag_display.lua:14:local DISPLAY_NS = "parley_diagnostic_virtual_lines"
lua/parley/skills/review/diag_display.lua:15:local DISPLAY_AUGROUP = "parley_diagnostic_virtual_lines"
lua/parley/skills/review/diag_display.lua:22:-- Parley's review diagnostic namespace — single-sourced from skill_render (which
lua/parley/skills/review/diag_display.lua:54:local function diagnostic_message_lines(diagnostic)
lua/parley/skills/review/diag_display.lua:56:    for _, line in ipairs(vim.split(tostring(diagnostic.message or ""), "\n", { plain = true })) do
lua/parley/skills/review/diag_display.lua:65:local function render(buf, diagnostics, current_line_only)
lua/parley/skills/review/diag_display.lua:78:    for _, diagnostic in ipairs(diagnostics or {}) do
lua/parley/skills/review/diag_display.lua:79:        if not current_line_only or diagnostic.lnum == line then
lua/parley/skills/review/diag_display.lua:80:            by_line[diagnostic.lnum] = by_line[diagnostic.lnum] or {}
lua/parley/skills/review/diag_display.lua:81:            table.insert(by_line[diagnostic.lnum], diagnostic)
lua/parley/skills/review/diag_display.lua:85:    for lnum, line_diagnostics in pairs(by_line) do
lua/parley/skills/review/diag_display.lua:86:        table.sort(line_diagnostics, function(a, b)
lua/parley/skills/review/diag_display.lua:89:        local virt_lines = { { { "Diagnostics:", HEADER_HL } } }
lua/parley/skills/review/diag_display.lua:90:        for _, diagnostic in ipairs(line_diagnostics) do
lua/parley/skills/review/diag_display.lua:91:            vim.list_extend(virt_lines, diagnostic_message_lines(diagnostic))
lua/parley/skills/review/diag_display.lua:103:    vim.diagnostic.handlers[HANDLER_NAME] = {
lua/parley/skills/review/diag_display.lua:104:        show = function(namespace, bufnr, diagnostics, opts)
lua/parley/skills/review/diag_display.lua:117:                        render(bufnr, diagnostics, true)
lua/parley/skills/review/diag_display.lua:121:            render(bufnr, diagnostics, current_line_only)
lua/parley/skills/review/diag_display.lua:137:    render(buf, vim.diagnostic.get(buf, { namespace = ns() }), true)
lua/parley/skills/review/diag_display.lua:145:    vim.diagnostic.config({
lua/parley/skills/review/diag_display.lua:147:        virtual_lines = false,
lua/parley/skill_render.lua:3:-- The diagnostics/highlights rendering salvaged out of skill_runner (#128 M3),
lua/parley/skill_render.lua:5:-- deleted in M4). Thin vim-API/UI wrapper (not pure): INFO diagnostics from each
lua/parley/skill_render.lua:26:--- Clear previous skill diagnostics and highlights from a buffer.
lua/parley/skill_render.lua:29:    vim.diagnostic.reset(diag_ns_id, buf)
lua/parley/skill_render.lua:38:--- The review diagnostic namespace id — the single source other modules
lua/parley/skill_render.lua:47:--- existing newlines. PURE. Lets `virtual_lines` render a long "why" as multiple
lua/parley/skill_render.lua:77:-- Usable wrap width for the virtual_lines "why": the window's text columns
lua/parley/skill_render.lua:80:-- fixed 76 overflowed the indented virtual_lines and truncated the right edge
lua/parley/skill_render.lua:92:--- Current usable wrap width for Parley diagnostic virtual lines.
lua/parley/skill_render.lua:94:function M.diagnostic_wrap_width()
lua/parley/skill_render.lua:98:--- Format a diagnostic message for Neovim virtual_lines display.
lua/parley/skill_render.lua:100:--- @param width number|nil default current diagnostic display width
lua/parley/skill_render.lua:102:function M.format_diagnostic_message(text, width)
lua/parley/skill_render.lua:103:    return M.wrap(text, width or M.diagnostic_wrap_width())
lua/parley/skill_render.lua:106:local function is_footnote_diagnostic(diagnostic)
lua/parley/skill_render.lua:107:    local user_data = diagnostic.user_data or {}
lua/parley/skill_render.lua:108:    return diagnostic.source == FOOTNOTE_SOURCE or user_data.parley_kind == "footnote"
lua/parley/skill_render.lua:111:--- Rehydrate persisted managed markdown footnotes into Parley diagnostics.
lua/parley/skill_render.lua:112:--- Existing non-footnote diagnostics in the shared namespace are preserved.
lua/parley/skill_render.lua:114:function M.refresh_footnote_diagnostics(buf)
lua/parley/skill_render.lua:123:    local width = M.diagnostic_wrap_width()
lua/parley/skill_render.lua:124:    local diagnostics = {}
lua/parley/skill_render.lua:126:    for _, existing in ipairs(vim.diagnostic.get(buf, { namespace = diag_ns_id })) do
lua/parley/skill_render.lua:127:        if not is_footnote_diagnostic(existing) then
lua/parley/skill_render.lua:128:            table.insert(diagnostics, existing)
lua/parley/skill_render.lua:132:    for _, footnote in ipairs(define.footnote_diagnostics(lines)) do
lua/parley/skill_render.lua:133:        table.insert(diagnostics, {
lua/parley/skill_render.lua:139:            severity = vim.diagnostic.severity.INFO,
lua/parley/skill_render.lua:145:    vim.diagnostic.set(diag_ns_id, buf, diagnostics)
lua/parley/skill_render.lua:148:--- Attach INFO diagnostics from edit explanations. Each diagnostic spans the
lua/parley/skill_render.lua:150:--- message is hard-wrapped to the window's usable width for `virtual_lines`
lua/parley/skill_render.lua:155:function M.attach_diagnostics(buf, edits, original_content)
lua/parley/skill_render.lua:157:    local width = M.diagnostic_wrap_width()
lua/parley/skill_render.lua:158:    local diagnostics = {}
lua/parley/skill_render.lua:170:        table.insert(diagnostics, {
lua/parley/skill_render.lua:174:            message = M.format_diagnostic_message(edit.explain or "edit applied", width),
lua/parley/skill_render.lua:175:            severity = vim.diagnostic.severity.INFO,
lua/parley/skill_render.lua:179:    vim.diagnostic.set(diag_ns_id, buf, diagnostics)
lua/parley/skill_render.lua:191:        -- INFO gutter diagnostic (the "why") via attach_diagnostics, not a
lua/parley/skill_render.lua:248:--- highlights and diagnostics preserve columns so exact anchors can be restored.
lua/parley/skill_render.lua:268:    for _, d in ipairs(vim.diagnostic.get(buf, { namespace = diag_ns_id })) do
lua/parley/skill_render.lua:296:        local diagnostics = {}
lua/parley/skill_render.lua:298:            table.insert(diagnostics, {
lua/parley/skill_render.lua:304:                severity = vim.diagnostic.severity.INFO,
lua/parley/skill_render.lua:309:        vim.diagnostic.set(diag_ns_id, buf, diagnostics)
atlas/skills/skill-system.md:44:- `lua/parley/skill_render.lua` — the single source of `clear_decorations`/`attach_diagnostics`/`highlight_edits` (salvaged from `skill_runner`).
atlas/skills/skill-system.md:51:- `lua/parley/skill_runner.lua` **deleted**; `review.lua`'s v1 edit/diagnostic re-exports and `review/init.lua`'s dead `pre_submit`/`post_apply`/`system_prompt` removed.
atlas/skills/skill-system.md:118:- `lua/parley/skill_render.lua` — diagnostics/highlights (single source; was salvaged from skill_runner)
atlas/index.md:15:- [Inline Term Definition](chat/inline_define.md): Visual-select a phrase + `<M-CR>` → concise context-aware definition as a managed footnote diagnostic rehydrated for markdown buffers (the `define` skill + `emit_definition` tool; honors `:ToggleWebSearch`).
atlas/traceability.yaml:426:      - lua/parley/timezone_diagnostics.lua
atlas/traceability.yaml:430:      - tests/unit/timezone_diagnostics_spec.lua
atlas/providers/tool_use.md:72:- **Buffer diagnostic**: `:lua require('parley').check_buffer()` validates invariants
atlas/chat/inline_define.md:4:concise, context-aware definition appears as an inline diagnostic under the
atlas/chat/inline_define.md:8:diagnostics when any markdown buffer is entered or refreshed. The whole new
atlas/chat/inline_define.md:14:made the definition durable as a managed footnote; [#167](../../workshop/issues/000167-define-diagnostic-highlight-span.md)
atlas/chat/inline_define.md:16:[#172](../../workshop/issues/000172-markdown-footnote-diagnostics.md)
atlas/chat/inline_define.md:39:   footnote diagnostics (`skill_render.refresh_footnote_diagnostics`), which
atlas/chat/inline_define.md:40:   parses the managed footer and sets INFO `vim.diagnostic` entries on matching
atlas/chat/inline_define.md:42:   `skill_render.format_diagnostic_message`) on the `parley_skill` namespace;
atlas/chat/inline_define.md:45:   diagnostic (cursor parked on the term's line). A no-`emit_definition` response
atlas/chat/inline_define.md:55:highlight + diagnostic), `ensure_watch(buf)`. Undoing the footnote edit lands on
atlas/chat/inline_define.md:58:highlights (`hl_spans`) and diagnostic `col`/`end_col`, while still accepting
atlas/chat/inline_define.md:66:  wrap as a legacy set_lines edit), `diagnostic_span_after_bracket` (legacy range
atlas/chat/inline_define.md:68:  `strip_definition_footnote_footer` / `footnote_diagnostics` (read only a final
atlas/chat/inline_define.md:72:  `lua/parley/skill_render.lua` publishes footnote diagnostics; and
atlas/chat/inline_define.md:93:prompt context. `define.footnote_diagnostics` uses the same footer detector to
atlas/chat/inline_define.md:94:scan inline references before the footer and produce diagnostics for each
atlas/chat/inline_define.md:125:  reference; rehydrated diagnostics do not recreate the DiffChange highlight.
atlas/chat/inline_define.md:126:- `skill_render.refresh_footnote_diagnostics` owns only diagnostics tagged
atlas/chat/inline_define.md:127:  `parley-footnote` and preserves other `parley_skill` diagnostics, so review
atlas/chat/inline_define.md:128:  diagnostics are not cleared by markdown footnote refresh.
atlas/chat/inline_define.md:129:- A diagnostic's Parley virtual-line block auto-hides when the cursor leaves its
atlas/chat/inline_define.md:134:- `lua/parley/define.lua` — pure core (slice / context / format / footnote footer / diagnostics).
atlas/chat/inline_define.md:137:- `lua/parley/skill_render.lua` — footnote diagnostic refresh in the shared namespace.
atlas/modes/review.md:15:edits are oriented by `DiffChange` highlights + INFO gutter diagnostics that
atlas/modes/review.md:79:- **Rendering**: `lua/parley/skill_render.lua` — diagnostics + edit highlights
atlas/modes/review.md:85:- **Feedback**: Highlights on edits (DiffChange), diagnostics from explain fields (INFO), quickfix for pending agent questions
atlas/modes/review.md:162:The edit "why" (the per-edit `explain`) is an INFO diagnostic on parley's
atlas/modes/review.md:164:it shows — scoped to that namespace, so the user's LSP/global diagnostics are
atlas/modes/review.md:165:untouched. Default **on**: Parley's custom `parley/virtual_lines` diagnostic
atlas/modes/review.md:166:handler renders a left-column virtual-line block headed `Diagnostics:` for the
atlas/modes/review.md:167:current line. It avoids Neovim's stock virtual-lines indentation-by-diagnostic
atlas/modes/review.md:169:(`skill_render.format_diagnostic_message`) **auto-expands below an edit when the
atlas/modes/review.md:170:cursor is in that edit's region** (`attach_diagnostics` spans
atlas/modes/review.md:171:`lnum..end_lnum`) and hides otherwise. `:ParleyShowDiagnostics` toggles it. The
atlas/modes/review.md:173:diagnostics because the underlying diagnostic spans remain unchanged. Composes
atlas/modes/review.md:209:- `lua/parley/skills/review/diag_display.lua` — inline "why" display toggle (`:ParleyShowDiagnostics`, cursor-region auto-show) (#133 M6)
atlas/modes/review.md:213:- `lua/parley/skill_render.lua` — diagnostics + edit highlights
atlas/ui/highlights.md:12:  diagnostics in Parley chat and markdown buffers. The pure parser/formatter
atlas/ui/highlights.md:13:  lives in `lua/parley/timezone_diagnostics.lua`; `highlighter.setup_buf_handler`
atlas/ui/highlights.md:14:  refreshes its separate diagnostic namespace on buffer enter/window enter and
atlas/ui/highlights.md:15:  text changes. Its namespace renders review-style virtual lines for the current
atlas/modes/raw_mode.md:5:**For agents debugging parley:** this is the first-line diagnostic tool for any LLM-pipeline issue (wrong prompt, missing messages, cache misses, tool_use shape, token usage, SSE oddities). Toggle on, reproduce, inspect the side files, toggle off. See [`atlas/infra/raw_logging.md`](../infra/raw_logging.md#when-to-use-this-debugging-entry-point) for the decision tree (exchange-level vs raw-API-level) and the full spec — file layout, format, toggles, lualine indicator, and the typed-YAML input feature.

exec
/bin/zsh -lc 'make test' in /Users/xianxu/workspace/parley.nvim
 exited 2 in 5061ms:
Checking lua/parley/agent_info.lua                OK
Checking lua/parley/agent_picker.lua              OK
Checking lua/parley/artifact_ref.lua              OK
Checking lua/parley/buffer_edit.lua               OK
Checking lua/parley/chat_dirs.lua                 OK
Checking lua/parley/chat_finder.lua               OK
Checking lua/parley/chat_lease.lua                OK
Checking lua/parley/chat_parser.lua               OK
Checking lua/parley/chat_respond.lua              OK
Checking lua/parley/chat_slug.lua                 OK
Checking lua/parley/cliproxy.lua                  OK
Checking lua/parley/cliproxy_config.lua           OK
Checking lua/parley/config.lua                    OK
Checking lua/parley/copy.lua                      OK
Checking lua/parley/custom_prompts.lua            OK
Checking lua/parley/defaults.lua                  OK
Checking lua/parley/define.lua                    OK
Checking lua/parley/discovery/base.lua            OK
Checking lua/parley/discovery/descriptor.lua      OK
Checking lua/parley/discovery/init.lua            OK
Checking lua/parley/discovery/local_types.lua     OK
Checking lua/parley/discovery/matcher.lua         OK
Checking lua/parley/discovery/merge.lua           OK
Checking lua/parley/discovery/registry.lua        OK
Checking lua/parley/dispatcher.lua                OK
Checking lua/parley/drill_in.lua                  OK
Checking lua/parley/exchange_clipboard.lua        OK
Checking lua/parley/exchange_model.lua            OK
Checking lua/parley/exporter.lua                  OK
Checking lua/parley/file_tracker.lua              OK
Checking lua/parley/finder_sticky.lua             OK
Checking lua/parley/float_picker.lua              OK
Checking lua/parley/google_drive.lua              OK
Checking lua/parley/health.lua                    OK
Checking lua/parley/helper.lua                    OK
Checking lua/parley/highlighter.lua               OK
Checking lua/parley/init.lua                      OK
Checking lua/parley/interview.lua                 OK
Checking lua/parley/issue_finder.lua              OK
Checking lua/parley/issue_vocabulary.lua          OK
Checking lua/parley/issues.lua                    OK
Checking lua/parley/keybinding_registry.lua       OK
Checking lua/parley/log_emit.lua                  OK
Checking lua/parley/logger.lua                    OK
Checking lua/parley/lualine.lua                   OK
Checking lua/parley/markdown_finder.lua           OK
Checking lua/parley/memory_prefs.lua              OK
Checking lua/parley/neighborhood.lua              OK
Checking lua/parley/note_dir_picker.lua           OK
Checking lua/parley/note_dirs.lua                 OK
Checking lua/parley/note_finder.lua               OK
Checking lua/parley/notes.lua                     OK
Checking lua/parley/oauth.lua                     OK
Checking lua/parley/obfuscate.lua                 OK
Checking lua/parley/outline.lua                   OK
Checking lua/parley/progress.lua                  OK
Checking lua/parley/provider_params.lua           OK
Checking lua/parley/providers.lua                 OK
Checking lua/parley/raw_log.lua                   OK
Checking lua/parley/render.lua                    OK
Checking lua/parley/render_buffer.lua             OK
Checking lua/parley/repo_artifacts.lua            OK
Checking lua/parley/review.lua                    OK
Checking lua/parley/review_menu.lua               OK
Checking lua/parley/root_dir_picker.lua           OK
Checking lua/parley/root_dirs.lua                 OK
Checking lua/parley/skill_assembly.lua            OK
Checking lua/parley/skill_edits.lua               OK
Checking lua/parley/skill_invoke.lua              OK
Checking lua/parley/skill_manifest.lua            OK
Checking lua/parley/skill_picker.lua              OK
Checking lua/parley/skill_providers.lua           OK
Checking lua/parley/skill_registry.lua            OK
Checking lua/parley/skill_render.lua              OK
Checking lua/parley/skills/define/init.lua        OK
Checking lua/parley/skills/review/diag_display.lua OK
Checking lua/parley/skills/review/init.lua        OK
Checking lua/parley/skills/review/journal.lua     OK
Checking lua/parley/skills/review/mode.lua        OK
Checking lua/parley/skills/review/projection.lua  OK
Checking lua/parley/skills/voice_apply/init.lua   OK
Checking lua/parley/spell.lua                     OK
Checking lua/parley/spinner.lua                   OK
Checking lua/parley/super_repo.lua                OK
Checking lua/parley/system_prompt_msgs.lua        OK
Checking lua/parley/system_prompt_picker.lua      OK
Checking lua/parley/tasker.lua                    OK
Checking lua/parley/test_agent_picker.lua         OK
Checking lua/parley/timezone_diagnostics.lua      OK
Checking lua/parley/tool_folds.lua                OK
Checking lua/parley/tool_loop.lua                 OK
Checking lua/parley/tools/backup.lua              OK
Checking lua/parley/tools/builtin/ack.lua         OK
Checking lua/parley/tools/builtin/argv.lua        OK
Checking lua/parley/tools/builtin/chat_history_search.lua OK
Checking lua/parley/tools/builtin/edit_file.lua   OK
Checking lua/parley/tools/builtin/emit_definition.lua OK
Checking lua/parley/tools/builtin/find.lua        OK
Checking lua/parley/tools/builtin/grep.lua        OK
Checking lua/parley/tools/builtin/ls.lua          OK
Checking lua/parley/tools/builtin/propose_edits.lua OK
Checking lua/parley/tools/builtin/read_file.lua   OK
Checking lua/parley/tools/builtin/write_file.lua  OK
Checking lua/parley/tools/dispatcher.lua          OK
Checking lua/parley/tools/init.lua                OK
Checking lua/parley/tools/serialize.lua           OK
Checking lua/parley/tools/types.lua               OK
Checking lua/parley/tools/version.lua             OK
Checking lua/parley/vault.lua                     OK
Checking lua/parley/vision.lua                    OK
Checking lua/parley/vision_finder.lua             OK
Checking tests/arch/arch_helper.lua               OK
Checking tests/arch/buffer_mutation_spec.lua      OK
Checking tests/fixtures/pre_81_vanilla_claude_prompts.lua OK
Checking tests/integration/chat_lease_spec.lua    OK
Checking tests/integration/chat_move_spec.lua     OK
Checking tests/integration/chat_respond_spec.lua  OK
Checking tests/integration/cliproxy_auth_login_spec.lua OK
Checking tests/integration/cliproxy_caller_teardown_spec.lua OK
Checking tests/integration/cliproxy_command_spec.lua OK
Checking tests/integration/cliproxy_dispatch_spec.lua OK
Checking tests/integration/cliproxy_download_spec.lua OK
Checking tests/integration/cliproxy_lifecycle_spec.lua OK
Checking tests/integration/create_handler_spec.lua OK
Checking tests/integration/define_spec.lua        OK
Checking tests/integration/discovery_builder_spec.lua OK
Checking tests/integration/discovery_local_types_spec.lua OK
Checking tests/integration/export_spec.lua        OK
Checking tests/integration/highlighting_spec.lua  OK
Checking tests/integration/neighborhood_completion_spec.lua OK
Checking tests/integration/new_chat_spec.lua      OK
Checking tests/integration/not_chat_spec.lua      OK
Checking tests/integration/progress_spec.lua      OK
Checking tests/integration/review_diag_display_spec.lua OK
Checking tests/integration/review_journal_io_spec.lua OK
Checking tests/integration/review_menu_spec.lua   OK
Checking tests/integration/review_mode_load_spec.lua OK
Checking tests/integration/review_projection_spec.lua OK
Checking tests/integration/skill_invoke_review_spec.lua OK
Checking tests/integration/skill_invoke_spec.lua  OK
Checking tests/integration/skill_providers_spec.lua OK
Checking tests/integration/skill_registry_spec.lua OK
Checking tests/integration/spell_chat_spec.lua    OK
Checking tests/integration/tasker_run_spec.lua    OK
Checking tests/integration/timer_race_spec.lua    OK
Checking tests/integration/topic_gen_spec.lua     OK
Checking tests/integration/tree_export_spec.lua   OK
Checking tests/integration/voice_apply_spec.lua   OK
Checking tests/perf_chat_finder.lua               OK
Checking tests/unit/ancestor_messages_spec.lua    OK
Checking tests/unit/anthropic_tool_decode_spec.lua OK
Checking tests/unit/anthropic_tool_encode_spec.lua OK
Checking tests/unit/arch_helper_spec.lua          OK
Checking tests/unit/artifact_ref_spec.lua         OK
Checking tests/unit/buffer_edit_spec.lua          OK
Checking tests/unit/build_messages_spec.lua       OK
Checking tests/unit/chat_dirs_spec.lua            OK
Checking tests/unit/chat_finder_logic_spec.lua    OK
Checking tests/unit/chat_parser_section_lines_spec.lua OK
Checking tests/unit/chat_parser_tools_spec.lua    OK
Checking tests/unit/chat_slug_resolve_spec.lua    OK
Checking tests/unit/chat_slug_spec.lua            OK
Checking tests/unit/cliproxy_config_spec.lua      OK
Checking tests/unit/config_tools_spec.lua         OK
Checking tests/unit/custom_prompts_spec.lua       OK
Checking tests/unit/define_spec.lua               OK
Checking tests/unit/discovery_base_spec.lua       OK
Checking tests/unit/discovery_descriptor_spec.lua OK
Checking tests/unit/discovery_matcher_spec.lua    OK
Checking tests/unit/discovery_merge_spec.lua      OK
Checking tests/unit/discovery_registry_spec.lua   OK
Checking tests/unit/dispatcher_query_spec.lua     OK
Checking tests/unit/dispatcher_spec.lua           OK
Checking tests/unit/drill_in_spec.lua             OK
Checking tests/unit/exchange_clipboard_spec.lua   OK
Checking tests/unit/exchange_model_spec.lua       OK
Checking tests/unit/exporter_tree_spec.lua        OK
Checking tests/unit/file_tracker_spec.lua         OK
Checking tests/unit/finder_sticky_spec.lua        OK
Checking tests/unit/float_picker_spec.lua         OK
Checking tests/unit/get_week_number_spec.lua      OK
Checking tests/unit/helper_io_spec.lua            OK
Checking tests/unit/helper_spec.lua               OK
Checking tests/unit/highlighter_spec.lua          OK
Checking tests/unit/inline_branch_spec.lua        OK
Checking tests/unit/issue_finder_spec.lua         OK
Checking tests/unit/issue_vocabulary_spec.lua     OK
Checking tests/unit/issues_spec.lua               OK
Checking tests/unit/keybindings_spec.lua          OK
Checking tests/unit/log_emit_spec.lua             OK
Checking tests/unit/logger_spec.lua               OK
Checking tests/unit/markdown_draft_block_spec.lua OK
Checking tests/unit/memory_prefs_spec.lua         OK
Checking tests/unit/neighborhood_spec.lua         OK
Checking tests/unit/note_finder_logic_spec.lua    OK
Checking tests/unit/oauth_spec.lua                OK
Checking tests/unit/obfuscate_spec.lua            OK
Checking tests/unit/open_chat_reference_spec.lua  OK
Checking tests/unit/outline_spec.lua              OK
Checking tests/unit/parley_harness_golden_spec.lua OK
Checking tests/unit/parley_harness_spec.lua       OK
Checking tests/unit/parse_at_reference_spec.lua   OK
Checking tests/unit/parse_chat_spec.lua           OK
Checking tests/unit/picker_items_spec.lua         OK
Checking tests/unit/process_directory_pattern_spec.lua OK
Checking tests/unit/progress_spec.lua             OK
Checking tests/unit/provider_params_spec.lua      OK
Checking tests/unit/providers_pre_query_spec.lua  OK
Checking tests/unit/pure_functions_spec.lua       OK
Checking tests/unit/raw_log_spec.lua              OK
Checking tests/unit/remote_references_spec.lua    OK
Checking tests/unit/render_buffer_roundtrip_spec.lua OK
Checking tests/unit/render_buffer_spec.lua        OK
Checking tests/unit/render_spec.lua               OK
Checking tests/unit/review_journal_spec.lua       OK
Checking tests/unit/review_mode_spec.lua          OK
Checking tests/unit/review_spec.lua               OK
Checking tests/unit/skill_assembly_spec.lua       OK
Checking tests/unit/skill_edits_spec.lua          OK
Checking tests/unit/skill_manifest_spec.lua       OK
Checking tests/unit/skill_picker_spec.lua         OK
Checking tests/unit/skill_render_spec.lua         OK
Checking tests/unit/spell_spec.lua                OK
Checking tests/unit/sse_parsing_spec.lua          OK
Checking tests/unit/super_repo_spec.lua           OK
Checking tests/unit/system_prompt_msgs_spec.lua   OK
Checking tests/unit/tasker_unit_spec.lua          OK
Checking tests/unit/timezone_diagnostics_spec.lua OK
Checking tests/unit/tool_folds_spec.lua           OK
Checking tests/unit/tool_loop_spec.lua            OK
Checking tests/unit/tools_builtin_ack_spec.lua    OK
Checking tests/unit/tools_builtin_chat_history_search_spec.lua OK
Checking tests/unit/tools_builtin_find_spec.lua   OK
Checking tests/unit/tools_builtin_grep_spec.lua   OK
Checking tests/unit/tools_builtin_ls_spec.lua     OK
Checking tests/unit/tools_builtin_propose_edits_spec.lua OK
Checking tests/unit/tools_builtin_read_file_spec.lua OK
Checking tests/unit/tools_builtin_registered_spec.lua OK
Checking tests/unit/tools_dispatcher_spec.lua     OK
Checking tests/unit/tools_registry_spec.lua       OK
Checking tests/unit/tools_serialize_spec.lua      OK
Checking tests/unit/tools_types_spec.lua          OK
Checking tests/unit/vault_spec.lua                OK
Checking tests/unit/vision_spec.lua               OK

Total: 0 warnings / 0 errors in 244 files
PASS: tests/unit/ancestor_messages_spec.lua
PASS: tests/unit/anthropic_tool_decode_spec.lua
PASS: tests/unit/buffer_edit_spec.lua
PASS: tests/unit/anthropic_tool_encode_spec.lua
PASS: tests/unit/arch_helper_spec.lua
PASS: tests/unit/artifact_ref_spec.lua
PASS: tests/unit/build_messages_spec.lua
PASS: tests/unit/chat_parser_section_lines_spec.lua
PASS: tests/unit/chat_parser_tools_spec.lua
PASS: tests/unit/chat_slug_spec.lua
PASS: tests/unit/chat_finder_logic_spec.lua
PASS: tests/unit/cliproxy_config_spec.lua
PASS: tests/unit/chat_dirs_spec.lua
PASS: tests/unit/define_spec.lua
PASS: tests/unit/custom_prompts_spec.lua
PASS: tests/unit/discovery_base_spec.lua
PASS: tests/unit/discovery_descriptor_spec.lua
PASS: tests/unit/discovery_matcher_spec.lua
PASS: tests/unit/discovery_merge_spec.lua
PASS: tests/unit/discovery_registry_spec.lua
PASS: tests/unit/chat_slug_resolve_spec.lua
PASS: tests/unit/dispatcher_query_spec.lua
PASS: tests/unit/exchange_clipboard_spec.lua
PASS: tests/unit/drill_in_spec.lua
PASS: tests/unit/exchange_model_spec.lua
PASS: tests/unit/dispatcher_spec.lua
PASS: tests/unit/finder_sticky_spec.lua
PASS: tests/unit/exporter_tree_spec.lua
PASS: tests/unit/get_week_number_spec.lua
PASS: tests/unit/file_tracker_spec.lua
PASS: tests/unit/helper_io_spec.lua
PASS: tests/unit/float_picker_spec.lua
PASS: tests/unit/helper_spec.lua
PASS: tests/unit/highlighter_spec.lua
PASS: tests/unit/inline_branch_spec.lua
PASS: tests/unit/issue_vocabulary_spec.lua
PASS: tests/unit/issue_finder_spec.lua
PASS: tests/unit/log_emit_spec.lua
PASS: tests/unit/markdown_draft_block_spec.lua
PASS: tests/unit/logger_spec.lua
PASS: tests/unit/memory_prefs_spec.lua
PASS: tests/unit/issues_spec.lua
PASS: tests/unit/config_tools_spec.lua
PASS: tests/unit/neighborhood_spec.lua
PASS: tests/unit/oauth_spec.lua
PASS: tests/unit/obfuscate_spec.lua
PASS: tests/unit/note_finder_logic_spec.lua
PASS: tests/unit/outline_spec.lua
PASS: tests/unit/open_chat_reference_spec.lua
PASS: tests/unit/parse_chat_spec.lua
PASS: tests/unit/picker_items_spec.lua
PASS: tests/unit/parley_harness_golden_spec.lua
PASS: tests/unit/process_directory_pattern_spec.lua
PASS: tests/unit/parley_harness_spec.lua
PASS: tests/unit/parse_at_reference_spec.lua
PASS: tests/unit/progress_spec.lua
PASS: tests/unit/provider_params_spec.lua
PASS: tests/unit/providers_pre_query_spec.lua
PASS: tests/unit/raw_log_spec.lua
PASS: tests/unit/keybindings_spec.lua
PASS: tests/unit/render_buffer_spec.lua
PASS: tests/unit/pure_functions_spec.lua
PASS: tests/unit/render_buffer_roundtrip_spec.lua
PASS: tests/unit/remote_references_spec.lua
PASS: tests/unit/render_spec.lua
PASS: tests/unit/review_mode_spec.lua
PASS: tests/unit/review_journal_spec.lua
PASS: tests/unit/review_spec.lua
PASS: tests/unit/skill_assembly_spec.lua
PASS: tests/unit/skill_edits_spec.lua
PASS: tests/unit/skill_manifest_spec.lua
PASS: tests/unit/skill_picker_spec.lua
PASS: tests/unit/skill_render_spec.lua
PASS: tests/unit/spell_spec.lua
PASS: tests/unit/sse_parsing_spec.lua
PASS: tests/unit/system_prompt_msgs_spec.lua
PASS: tests/unit/tasker_unit_spec.lua
PASS: tests/unit/timezone_diagnostics_spec.lua
PASS: tests/unit/tool_folds_spec.lua
PASS: tests/unit/tool_loop_spec.lua
PASS: tests/unit/tools_builtin_grep_spec.lua
PASS: tests/unit/tools_builtin_propose_edits_spec.lua
PASS: tests/unit/tools_builtin_ls_spec.lua
PASS: tests/unit/tools_builtin_read_file_spec.lua
===FAIL: tests/unit/tools_builtin_find_spec.lua===
  Scheduling: tests/unit/tools_builtin_find_spec.lua

  ========================================
  Testing:     /Users/xianxu/workspace/parley.nvim/tests/unit/tools_builtin_find_spec.lua
  Success    ||    find tool finds files by structured name and type fields
  Success    ||    find tool does not accept a raw flags escape hatch
  Success    ||    find tool rejects action and write predicates as unknown structured fields
  Fail    ||    find tool treats command substitution text in name as data
              ...space/parley.nvim/tests/unit/tools_builtin_find_spec.lua:30: Expected objects to be the same.
              Passed in:
              (boolean) true
              Expected:
              (boolean) false

              stack traceback:
                  ...space/parley.nvim/tests/unit/tools_builtin_find_spec.lua:30: in function <...space/parley.nvim/tests/unit/tools_builtin_find_spec.lua:28>


  Success:     3
  Failed :     1
  Errors :     0
  ========================================
  Tests Failed. Exit: 1
PASS: tests/unit/tools_builtin_registered_spec.lua
PASS: tests/unit/tools_registry_spec.lua
PASS: tests/unit/tools_serialize_spec.lua
PASS: tests/unit/tools_types_spec.lua
PASS: tests/unit/tools_builtin_ack_spec.lua
PASS: tests/unit/tools_dispatcher_spec.lua
PASS: tests/unit/vault_spec.lua
PASS: tests/unit/vision_spec.lua
PASS: tests/unit/tools_builtin_chat_history_search_spec.lua
PASS: tests/unit/super_repo_spec.lua

=== Failed unit test files ===
tests/unit/tools_builtin_find_spec.lua
make: *** [test-unit] Error 1

codex
`make test` is not green in this checkout: lint and most tests pass, but `tests/unit/tools_builtin_find_spec.lua` fails on the command-substitution-as-data case. That file is outside this diff, so I’m treating it as verification evidence to report rather than attributing it to the diagnostic change.
exec
/bin/zsh -lc "nl -ba tests/unit/tools_builtin_find_spec.lua | sed -n '1,80p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
     1    -- Tests for lua/parley/tools/builtin/find.lua
     2
     3    local find_def = require("parley.tools.builtin.find")
     4    local handler = find_def.handler
     5
     6    describe("find tool", function()
     7        it("finds files by structured name and type fields", function()
     8            local r = handler({ path = "lua/parley", name = "*.lua", type = "f" })
     9            assert.is_false(r.is_error)
    10            assert.truthy(r.content:match("config%.lua"))
    11        end)
    12
    13        it("does not accept a raw flags escape hatch", function()
    14            local r = handler({ path = ".", flags = { "-exec", "echo", "PARLEY_SENTINEL_144", ";" } })
    15            assert.is_true(r.is_error)
    16            assert.not_matches("missing.*command", r.content)
    17            assert.not_matches("PARLEY_SENTINEL_144", r.content)
    18        end)
    19
    20        it("rejects action and write predicates as unknown structured fields", function()
    21            for _, field in ipairs({ "-exec", "-execdir", "-ok", "-okdir", "-delete", "-fprint", "-fprintf", "-fls" }) do
    22                local r = handler({ path = ".", [field] = "PARLEY_SENTINEL_144" })
    23                assert.is_true(r.is_error)
    24                assert.not_matches("PARLEY_SENTINEL_144", r.content)
    25            end
    26        end)
    27
    28        it("treats command substitution text in name as data", function()
    29            local r = handler({ path = ".", name = "$(echo PARLEY_SENTINEL_144)" })
    30            assert.is_false(r.is_error)
    31            assert.not_matches("PARLEY_SENTINEL_144", r.content)
    32        end)
    33    end)

exec
/bin/zsh -lc 'git diff --name-only b9094e9bfc89b0f27013c6fd41c38a83b8b61510..HEAD -- tests/unit/tools_builtin_find_spec.lua lua/parley/tools/builtin/find.lua lua/parley/tools/builtin/argv.lua' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
exec
/bin/zsh -lc 'git status --short' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
 M workshop/issues/000162-split-parley-into-two-different-plugins.md
 M workshop/issues/000168-buffer-undo-operation-during-chat-generation-resulted-in-a-huge-error-message.md
 M workshop/issues/000170-parley-chat-performance-problem.md
 M workshop/issues/000171-footnote-coloring.md

codex
```verdict
verdict: REWORK
confidence: high
```

The left-column rendering approach is mostly right and the focused test passes, but the new current-line filter regresses review diagnostics that span multiple lines. Review diagnostics intentionally use `lnum..end_lnum`; after this change, the virtual-line block only appears when the cursor is on `diagnostic.lnum`, not when it is elsewhere inside the edit region. That violates the documented/shared namespace behavior, so this should not cross the boundary yet.

1. Strengths

- `lua/parley/skills/review/diag_display.lua:103` scopes the custom handler to Parley’s diagnostic namespace, preserving global/LSP diagnostics. Good ARCH-DRY shape.
- `lua/parley/skills/review/diag_display.lua:145` disables stock `virtual_lines` only for the Parley namespace and keeps diagnostic data intact.
- `tests/integration/review_diag_display_spec.lua:43` pins the key symptom: high-column diagnostics now render with `virt_lines_leftcol = true`.
- Atlas updates cover both review and inline define behavior.

2. Critical Findings

- `lua/parley/skills/review/diag_display.lua:79` filters with `diagnostic.lnum == line`, ignoring `diagnostic.end_lnum`. `skill_render.attach_diagnostics` deliberately spans review edits across `lnum..end_lnum`, and `atlas/modes/review.md:169` still promises display when the cursor is in that edit region. I reproduced this with a diagnostic `{lnum=0,end_lnum=2}`: line 1 shows 1 display mark; moving to lines 2 or 3 shows 0. Fix by extracting a range predicate like `diagnostic_contains_line(d, line)` using `end_lnum or lnum`, render when the cursor is anywhere in the span, and add an integration test that moves the cursor to a middle/end line of a multi-line review diagnostic. This is ARCH-PURPOSE and ARCH-PURE: the shared display must serve both footnote and review diagnostics, and the span predicate should be direct/pinned.

3. Important Findings

- `workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:86` claims final `make test` green, but my `make test` run exits 2: `tests/unit/tools_builtin_find_spec.lua` fails at line 30 in “treats command substitution text in name as data”. That file is outside this diff, so I am not attributing causality to #173, but the boundary evidence is currently false/stale. Re-run after resolving or explicitly record the exception before close.

4. Minor Findings

- `lua/parley/skills/review/diag_display.lua:5` still says default is stock ``virtual_lines { current_line = true }``; update the header comment to describe the custom `parley/virtual_lines` handler.

5. Test Coverage Notes

Focused `review_diag_display_spec.lua` passes. Missing coverage is the multi-line `end_lnum` current-region behavior, which is exactly the regression above. Full `make test` is not green in this checkout due to the unrelated `tools_builtin_find_spec.lua` failure.

6. Architectural Notes

- ARCH-DRY: Pass. One Parley display controller is used for review and footnote diagnostics.
- ARCH-PURE: Mostly pass, but the current-line/range selection logic should be a small pure helper with a targeted test.
- ARCH-PURPOSE: Flagged. The diff solves the footnote long-line symptom but under-delivers the shared-namespace purpose by breaking multi-line review-region display.

7. Plan Revision Recommendations

- Add a `## Revisions` entry noting that current-line filtering must preserve `lnum..end_lnum` review-region behavior, not only same-line footnote diagnostics.
- Update the verification log after `make test` is actually green or after the unrelated failure is explicitly handled.
tokens used
71,668
```verdict
verdict: REWORK
confidence: high
```

The left-column rendering approach is mostly right and the focused test passes, but the new current-line filter regresses review diagnostics that span multiple lines. Review diagnostics intentionally use `lnum..end_lnum`; after this change, the virtual-line block only appears when the cursor is on `diagnostic.lnum`, not when it is elsewhere inside the edit region. That violates the documented/shared namespace behavior, so this should not cross the boundary yet.

1. Strengths

- `lua/parley/skills/review/diag_display.lua:103` scopes the custom handler to Parley’s diagnostic namespace, preserving global/LSP diagnostics. Good ARCH-DRY shape.
- `lua/parley/skills/review/diag_display.lua:145` disables stock `virtual_lines` only for the Parley namespace and keeps diagnostic data intact.
- `tests/integration/review_diag_display_spec.lua:43` pins the key symptom: high-column diagnostics now render with `virt_lines_leftcol = true`.
- Atlas updates cover both review and inline define behavior.

2. Critical Findings

- `lua/parley/skills/review/diag_display.lua:79` filters with `diagnostic.lnum == line`, ignoring `diagnostic.end_lnum`. `skill_render.attach_diagnostics` deliberately spans review edits across `lnum..end_lnum`, and `atlas/modes/review.md:169` still promises display when the cursor is in that edit region. I reproduced this with a diagnostic `{lnum=0,end_lnum=2}`: line 1 shows 1 display mark; moving to lines 2 or 3 shows 0. Fix by extracting a range predicate like `diagnostic_contains_line(d, line)` using `end_lnum or lnum`, render when the cursor is anywhere in the span, and add an integration test that moves the cursor to a middle/end line of a multi-line review diagnostic. This is ARCH-PURPOSE and ARCH-PURE: the shared display must serve both footnote and review diagnostics, and the span predicate should be direct/pinned.

3. Important Findings

- `workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:86` claims final `make test` green, but my `make test` run exits 2: `tests/unit/tools_builtin_find_spec.lua` fails at line 30 in “treats command substitution text in name as data”. That file is outside this diff, so I am not attributing causality to #173, but the boundary evidence is currently false/stale. Re-run after resolving or explicitly record the exception before close.

4. Minor Findings

- `lua/parley/skills/review/diag_display.lua:5` still says default is stock ``virtual_lines { current_line = true }``; update the header comment to describe the custom `parley/virtual_lines` handler.

5. Test Coverage Notes

Focused `review_diag_display_spec.lua` passes. Missing coverage is the multi-line `end_lnum` current-region behavior, which is exactly the regression above. Full `make test` is not green in this checkout due to the unrelated `tools_builtin_find_spec.lua` failure.

6. Architectural Notes

- ARCH-DRY: Pass. One Parley display controller is used for review and footnote diagnostics.
- ARCH-PURE: Mostly pass, but the current-line/range selection logic should be a small pure helper with a targeted test.
- ARCH-PURPOSE: Flagged. The diff solves the footnote long-line symptom but under-delivers the shared-namespace purpose by breaking multi-line review-region display.

7. Plan Revision Recommendations

- Add a `## Revisions` entry noting that current-line filtering must preserve `lnum..end_lnum` review-region behavior, not only same-line footnote diagnostics.
- Update the verification log after `make test` is actually green or after the unrelated failure is explicitly handled.

---

## Re-review — 2026-07-08T13:33:05-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 173 — diagnostic virtual lines blank on long wrapped markdown |
| repo | parley.nvim |
| issue file | workshop/issues/000173-diagnostic-virtual-lines-leftcol.md |
| boundary | whole-issue close |
| milestone | — |
| window | b9094e9bfc89b0f27013c6fd41c38a83b8b61510..HEAD |
| command | sdlc close --issue 173 |
| reviewer | codex |
| timestamp | 2026-07-08T13:33:05-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Reading additional input from stdin...
OpenAI Codex v0.142.5
--------
workdir: /Users/xianxu/workspace/parley.nvim
model: gpt-5.5
provider: openai
approval: never
sandbox: workspace-write [workdir, /tmp, $TMPDIR, /tmp] (network access enabled)
reasoning effort: none
reasoning summaries: none
session id: 019f436d-e040-7961-8c2e-2203b39ec597
--------
user
# Code review — the one SDLC boundary review

You are conducting a fresh-context code review at a development boundary —
whole-issue close — in the **parley.nvim** repository.

- repository: parley.nvim   (root: /Users/xianxu/workspace/parley.nvim)
- issue:      parley.nvim#173   (file: workshop/issues/000173-diagnostic-virtual-lines-leftcol.md)
- window:     Base: b9094e9bfc89b0f27013c6fd41c38a83b8b61510   Head: HEAD

Review the **parley.nvim** repo and its tracker — the ariadne base-layer repo itself (changes here propagate to dependent repos). Do not assume any
other repository or apply another repo's conventions.

You have no prior session context — that is the anti-collusion property. Verify
behavior against the issue's documented Spec/Plan and the code itself; do NOT
take the implementor's word in commit messages or docs at face value. Tools are
read-only: report findings precisely; the main agent (which has session context)
applies the fixes, commits, and re-runs.

Read the diff against the issue's Spec + Plan, then work the checklist below.
Categorize every finding by severity — not everything is Critical; a nitpick
marked Critical is noise.

  Critical (must fix before crossing the boundary)
    - correctness bugs; crashes / panics on unexpected input
    - behavior drift from stated contracts (for ports of existing code where
      byte-faithfulness was promised, diff against the source)
    - silent error swallowing where the source raised
  Important (fix before the boundary if cheap)
    - API design of newly-introduced internal packages (downstream work will
      consume them; is the surface stable?)
    - missing test coverage that would catch the kind of bug shipped
    - inconsistent error handling across the diff
  Minor (note for future)
    - style nits, naming, comment density; performance only if hot-path

## Review checklist

Code quality
  - Clean separation of concerns; edge cases handled (empty / nil / unexpected).
  - Proper error handling — no silent swallowing where the source raised.
  - No duplicated logic / copy-paste that should be a shared helper.

Testing
  - Tests pin real logic, not mocks reasserting the implementation.
  - The kind of bug this diff could ship is covered.
  - PURE entities tested without IO; INTEGRATION via injected fakes (see below).

Requirements traceability
  - Every Plan checklist item this boundary claims is actually delivered.
  - Implementation matches the Spec; no undeclared scope creep.
  - Breaking changes documented.

Production readiness
  - Migration / backward-compatibility considered where state or formats change.
  - Docs / atlas updated for new surface (see the Docs update gate).

## Core concepts cross-check (if the plan has a Core concepts table)

The plan should list entities in a greppable table — name, kind
(PURE/INTEGRATION), file location, status (new/modified/deleted). For each row:
  - Verify the entity exists at the stated path (grep the diff or filesystem).
  - PURE: tests run without IO (no exec, net, mutable fs). If tests need mocks
    to run, it isn't really PURE — flag Critical and recommend promoting it to
    INTEGRATION.
  - INTEGRATION: injected into pure callers, not invoked directly from business
    logic.
  - "modified" / "deleted": the diff shows the expected change/removal at the
    stated location.
Any contradiction between table and code = Critical finding, plus a plan-revision
recommendation (a "## Revisions" entry so the plan stops claiming what the code
doesn't deliver).

## Docs update gate (atlas + README, per AGENTS.md §8)

The boundary should update user-facing docs for any new surface introduced:

  - **atlas/** — new architectural surface, flow, or terminology. Scan the diff
    for new entity types, subcommands, conventions, file-tree locations. Any
    present without corresponding atlas/ changes in the same range = Important
    finding ("atlas update appears missing for <surface>").
  - **README.md** — new user-facing surface a reader runs or types: subcommands,
    flags, keybindings, config keys, install/usage steps. If the diff adds or
    changes such surface and README.md is not updated in the same range =
    Important finding ("README update appears missing for <surface>"). This is the
    class of gap that used to surface only at the merge-time `specs` judge (#142);
    catch it here, at the earliest gate, before the close verdict is recorded.

## Architecture (the at-review backstop — these matter most long-term)

Work through each of ARCH-DRY, ARCH-PURE, ARCH-PURPOSE explicitly, applying its at-review lens. The
full principle definitions are delivered in the ARCHITECTURE PRINCIPLES block
right after this prompt — for EACH marker, state pass or flag, and cite the
marker (e.g. ARCH-DRY) in any finding. Architecture is where review has the
least training signal and the longest-delayed payoff, so be deliberate here, not
holistic.

## Verdict + output

Begin your response with this fenced verdict block — the machine-read handoff:

```verdict
verdict: <SHIP | FIX-THEN-SHIP | REWORK>
confidence: <high | medium | low>
```

  SHIP           ready; ship it
  FIX-THEN-SHIP  ship after addressing the findings (non-blocking at the gate)
  REWORK         blocking; needs rework before shipping — fix + re-run

The fenced ```` ```verdict ```` block above is the **authoritative machine-read
handoff** — emit it as the first thing in your response. (A prose
`VERDICT: <TOKEN>` first line still satisfies the legacy contract as a fallback,
but the block is what the binary trusts.)

After the verdict block: a 1-paragraph summary — what worked, what blocks SHIP if
it isn't — followed by:
  1. Strengths: 2-5 specific things done well (file:line where useful). Affirm
     validated approaches so the operator knows what's confirmed-good ground.
     Empty acceptable for trivial boundaries.
  2. Critical findings (file:line + fix sketch); empty if none.
  3. Important findings (same format).
  4. Minor findings (terse one-liners).
  5. Test coverage notes.
  6. Architectural notes for upcoming work.
  7. Plan revision recommendations: specific "## Revisions" entries the plan
     needs (empty if the plan still matches the code).


ARCHITECTURE PRINCIPLES — work through each of the 3 entries below explicitly, applying its `at-review` lens; cite the marker (e.g. ARCH-DRY) in any finding.

# Architecture principles (ARCH-*)

Injected architectural taste — the structural decisions whose payoff (or cost)
shows up many turns, often months, down the road. Agents are strong at local
tactics and weak here, so these are checked **at-plan** (when the design is being
made — highest leverage) and **at-review** (backstop, on the diff). Cite the
marker (e.g. `ARCH-DRY`) in plans, `## Log` entries, and review findings.

This file is the single source; it is embedded into the planning, plan-quality,
and code-review prompts. The human narrative lives in AGENTS.md "Core Design
Principles"; this is its machine-delivered companion.

## ARCH-DRY — Don't Repeat Yourself

- **principle:** Reuse before adding. One source of truth per fact/behavior; no
  duplicated logic, copy-pasted blocks, or parallel functions that should be one
  shared helper.
- **at-plan:** Flag a plan that re-implements something the codebase already has,
  or that will obviously duplicate logic across the new files instead of
  extracting a shared helper. Name the existing thing it should reuse.
- **at-review:** Flag duplicated logic / copy-pasted blocks / near-identical
  functions in the diff; point at the consolidation (file:line + the shared
  helper they should become).

## ARCH-PURE — Pure core, thin IO shell

- **principle:** The majority of code is pure functions (deterministic, no side
  effects); a thin "glue" layer at the boundary touches IO/UI/network/clock. Pure
  functions are unit-tested directly; the glue is kept small and injected.
- **at-plan:** Flag a design that buries business logic inside IO/handlers, or
  that will only be testable with heavy mocks (a sign logic isn't separated from
  IO). The plan should name what's pure vs the thin IO seam.
- **at-review:** Flag business logic mixed with IO in the diff; logic that should
  be a pure function injected into a thin caller. If a test needs mocks to run a
  "pure" entity, it isn't pure — recommend extracting the IO to the boundary.

## ARCH-PURPOSE — Serve the issue's actual purpose

- **principle:** Deliver the issue's stated purpose, not the easy subset of it. A
  single-source / "compiled to consumers" change is not done until **every
  consumer derives** from the source — the source is *enforced*, not just
  documentation a surface happens to restate; a hand-maintained restatement of the
  model is a deferred consumer, not a finished one. "Follow-up" is for separable
  extensions, never for the thing that is the point. This is the *opposite axis*
  from Simplicity-First/YAGNI: not "build for an imagined future," but "don't
  **under**-deliver the purpose you already committed to."
- **at-plan:** Flag a plan whose scope is a strict subset of the issue's stated
  goal / Done-when where the part deferred as "follow-up" *is* the purpose (e.g.
  wires one consumer + enforcement but leaves the consumers that motivated the
  issue as documentation that doesn't derive). Ask: does the plan fulfill the
  purpose, or just the cheap win? Name the deferred purpose.
- **at-review:** Does the diff *fulfill* the purpose or settle for the easy win?
  For a single-source change, run the **shadow-sweep** — enumerate the consumers,
  confirm each derives from the source, flag any remaining hand-maintained
  restatement of the model. A "follow-up" that is actually the deferred point of
  the issue is a finding, not a deferral.


OUTPUT CONTRACT (machine-read — do not deviate). LEAD your response with the
fenced ```verdict block shown above — that is the authoritative handoff the binary
reads (its `verdict:` value is one of the listed tokens). Everything after the block
is advisory: a non-blocking verdict WITH findings still PASSES the gate. A bare
`VERDICT: <TOKEN>` line is accepted only as a FALLBACK when the block is absent.

Diff:
diff --git a/atlas/chat/inline_define.md b/atlas/chat/inline_define.md
index 270e924..6df2cf4 100644
--- a/atlas/chat/inline_define.md
+++ b/atlas/chat/inline_define.md
@@ -1,14 +1,14 @@
 # Inline Term Definition

 Select a phrase in a chat transcript, press **`<M-CR>`** (visual mode), and a
-concise, context-aware definition appears as an inline diagnostic (grey
-`virtual_lines`) under the phrase. The selected text stays in place and gets a
-markdown footnote reference (`ASIN[^asin]`), while the definition is stored in a
-managed footnote footer at the end of the chat transcript. Persisted managed
-footnotes are rehydrated into diagnostics when any markdown buffer is entered or
-refreshed. The whole new annotation is **undoable** — `u` reverts the footnote
-edit and clears both decorations (see Undo below). For jargon you don't know
-(e.g. `ASIN`), it's a one-keystroke lookup. Added in
+concise, context-aware definition appears as an inline diagnostic under the
+phrase. The selected text stays in place and gets a markdown footnote reference
+(`ASIN[^asin]`), while the definition is stored in a managed footnote footer at
+the end of the chat transcript. Persisted managed footnotes are rehydrated into
+diagnostics when any markdown buffer is entered or refreshed. The whole new
+annotation is **undoable** — `u` reverts the footnote edit and clears both
+decorations (see Undo below). For jargon you don't know (e.g. `ASIN`), it's a
+one-keystroke lookup. Added in
 [#161](../../workshop/issues/000161-inline-term-definition.md) (R1 added the
 highlight/undo); [#166](../../workshop/issues/000166-visual-selection-definition-system-manages-footnote.md)
 made the definition durable as a managed footnote; [#167](../../workshop/issues/000167-define-diagnostic-highlight-span.md)
@@ -41,9 +41,9 @@ rehydrates persisted managed footnotes in all markdown buffers.
    inline `term[^id]` spans (`define.format_definition` →
    `skill_render.format_diagnostic_message`) on the `parley_skill` namespace;
    **(d)** records the undo/redo projection states.
-   `diag_display`'s `virtual_lines{current_line=true}` reveals the diagnostic
-   (cursor parked on the term's line). A no-`emit_definition` response leaves no
-   footnote reference/footer.
+   `diag_display`'s Parley-owned left-column virtual-line display reveals the
+   diagnostic (cursor parked on the term's line). A no-`emit_definition` response
+   leaves no footnote reference/footer.

 ## Undo (`u`) — reuses review's projection

@@ -126,8 +126,8 @@ tool-call args (`result.calls[1].input`), read in `on_done`.
 - `skill_render.refresh_footnote_diagnostics` owns only diagnostics tagged
   `parley-footnote` and preserves other `parley_skill` diagnostics, so review
   diagnostics are not cleared by markdown footnote refresh.
-- A diagnostic's `virtual_lines` auto-hide when the cursor leaves its line. The
-  footnote persists in the file if saved.
+- A diagnostic's Parley virtual-line block auto-hides when the cursor leaves its
+  line. The footnote persists in the file if saved.

 ## Key files

diff --git a/atlas/modes/review.md b/atlas/modes/review.md
index b470783..ef656df 100644
--- a/atlas/modes/review.md
+++ b/atlas/modes/review.md
@@ -162,12 +162,16 @@ session-scoped undo); per-state snapshots aren't journaled.
 The edit "why" (the per-edit `explain`) is an INFO diagnostic on parley's
 `parley_skill` namespace. `lua/parley/skills/review/diag_display.lua` controls how
 it shows — scoped to that namespace, so the user's LSP/global diagnostics are
-untouched. Default **on**: `virtual_lines { current_line = true }`, so the
-(hard-wrapped, via `skill_render.format_diagnostic_message`) why **auto-expands
-below an edit when the cursor is in that edit's region** (`attach_diagnostics` spans `lnum..end_lnum`)
-and hides otherwise. `:ParleyShowDiagnostics` toggles it. The built-in `]d`/`[d`
-(jump) and `<C-W>d` (float, wraps) also work on these diagnostics. Composes with
-M5 — re-renders on undo/redo.
+untouched. Default **on**: Parley's custom `parley/virtual_lines` diagnostic
+handler renders a left-column virtual-line block headed `Diagnostics:` for the
+current line. It avoids Neovim's stock virtual-lines indentation-by-diagnostic
+column, which can hide messages on long wrapped prose. The hard-wrapped why
+(`skill_render.format_diagnostic_message`) **auto-expands below an edit when the
+cursor is in that edit's region** (`attach_diagnostics` spans
+`lnum..end_lnum`) and hides otherwise. `:ParleyShowDiagnostics` toggles it. The
+built-in `]d`/`[d` (jump) and `<C-W>d` (float, wraps) still work on these
+diagnostics because the underlying diagnostic spans remain unchanged. Composes
+with M5 — re-renders on undo/redo.

 ## Progress bar (#133 M7)

diff --git a/lua/parley/skills/review/diag_display.lua b/lua/parley/skills/review/diag_display.lua
index 4617a35..a63de85 100644
--- a/lua/parley/skills/review/diag_display.lua
+++ b/lua/parley/skills/review/diag_display.lua
@@ -1,29 +1,166 @@
--- diag_display.lua — inline display of review "why" diagnostics (#133 M6).
+-- diag_display.lua — inline display of Parley diagnostics (#133 M6, #173).
 --
 -- Controls how parley's review explanations render, scoped to parley's OWN
 -- diagnostic namespace (never touches the user's LSP / global diagnostics).
--- Default ON: `virtual_lines { current_line = true }`, so the (hard-wrapped) why
--- auto-expands below an edit when the cursor is in that edit's region, and hides
--- otherwise. `:ParleyShowDiagnostics` toggles it.
+-- Default ON: a custom diagnostic handler renders left-column virtual lines for
+-- the cursor's current diagnostic region, so long wrapped prose doesn't hide
+-- messages behind stock virtual-lines column indentation. `:ParleyShowDiagnostics`
+-- toggles it.

 local M = {}

 M.enabled = true -- default on (cursor-region auto-show)

+local HANDLER_NAME = "parley/virtual_lines"
+local DISPLAY_NS = "parley_diagnostic_virtual_lines"
+local DISPLAY_AUGROUP = "parley_diagnostic_virtual_lines"
+local HEADER_HL = "ParleyDiagnosticVirtualLineHeader"
+local MESSAGE_HL = "ParleyDiagnosticVirtualLine"
+
+local display_ns_id
+local display_augroup
+
 -- Parley's review diagnostic namespace — single-sourced from skill_render (which
 -- owns the namespace) so the identity isn't a duplicated literal (#133 M6 review).
 local function ns()
     return require("parley.skill_render").diag_namespace()
 end

+local function ensure_display()
+    if not display_ns_id then
+        display_ns_id = vim.api.nvim_create_namespace(DISPLAY_NS)
+    end
+    if not display_augroup then
+        display_augroup = vim.api.nvim_create_augroup(DISPLAY_AUGROUP, { clear = true })
+    end
+    vim.api.nvim_set_hl(0, HEADER_HL, { link = "DiagnosticInfo" })
+    vim.api.nvim_set_hl(0, MESSAGE_HL, { link = "DiagnosticFloatingInfo" })
+end
+
+local function clear(buf)
+    ensure_display()
+    if vim.api.nvim_buf_is_valid(buf) then
+        vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
+        pcall(vim.api.nvim_clear_autocmds, { group = display_augroup, buffer = buf })
+    end
+end
+
+local function current_line_for(buf)
+    if vim.api.nvim_get_current_buf() ~= buf then
+        return nil
+    end
+    return vim.api.nvim_win_get_cursor(0)[1] - 1
+end
+
+local function diagnostic_message_lines(diagnostic)
+    local lines = {}
+    for _, line in ipairs(vim.split(tostring(diagnostic.message or ""), "\n", { plain = true })) do
+        table.insert(lines, { { line ~= "" and line or " ", MESSAGE_HL } })
+    end
+    if #lines == 0 then
+        table.insert(lines, { { " ", MESSAGE_HL } })
+    end
+    return lines
+end
+
+local function diagnostic_contains_line(diagnostic, line)
+    local start_line = diagnostic.lnum or 0
+    local end_line = diagnostic.end_lnum or start_line
+    return line >= start_line and line <= end_line
+end
+
+local function render(buf, diagnostics, current_line_only)
+    ensure_display()
+    if not vim.api.nvim_buf_is_valid(buf) then
+        return
+    end
+    vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
+
+    local line = current_line_only and current_line_for(buf) or nil
+    if current_line_only and not line then
+        return
+    end
+
+    local by_line = {}
+    for _, diagnostic in ipairs(diagnostics or {}) do
+        if not current_line_only or diagnostic_contains_line(diagnostic, line) then
+            by_line[diagnostic.lnum] = by_line[diagnostic.lnum] or {}
+            table.insert(by_line[diagnostic.lnum], diagnostic)
+        end
+    end
+
+    for lnum, line_diagnostics in pairs(by_line) do
+        table.sort(line_diagnostics, function(a, b)
+            return (a.col or 0) < (b.col or 0)
+        end)
+        local virt_lines = { { { "Diagnostics:", HEADER_HL } } }
+        for _, diagnostic in ipairs(line_diagnostics) do
+            vim.list_extend(virt_lines, diagnostic_message_lines(diagnostic))
+        end
+        vim.api.nvim_buf_set_extmark(buf, display_ns_id, lnum, 0, {
+            virt_lines = virt_lines,
+            virt_lines_leftcol = true,
+            virt_lines_above = false,
+        })
+    end
+end
+
+local function register_handler()
+    ensure_display()
+    vim.diagnostic.handlers[HANDLER_NAME] = {
+        show = function(namespace, bufnr, diagnostics, opts)
+            if namespace ~= ns() then
+                return
+            end
+            bufnr = vim._resolve_bufnr(bufnr)
+            local handler_opts = opts and opts[HANDLER_NAME] or {}
+            local current_line_only = handler_opts.current_line == true
+            clear(bufnr)
+            if current_line_only then
+                vim.api.nvim_create_autocmd("CursorMoved", {
+                    buffer = bufnr,
+                    group = display_augroup,
+                    callback = function()
+                        render(bufnr, diagnostics, true)
+                    end,
+                })
+            end
+            render(bufnr, diagnostics, current_line_only)
+        end,
+        hide = function(namespace, bufnr)
+            if namespace ~= ns() then
+                return
+            end
+            clear(vim._resolve_bufnr(bufnr))
+        end,
+    }
+end
+
+function M.refresh(buf)
+    if not M.enabled then
+        return
+    end
+    buf = buf or vim.api.nvim_get_current_buf()
+    render(buf, vim.diagnostic.get(buf, { namespace = ns() }), true)
+end
+
 --- Apply the inline-display config for parley's review namespace.
 --- @param on boolean
 function M.set(on)
     M.enabled = on and true or false
+    register_handler()
     vim.diagnostic.config({
-        virtual_lines = M.enabled and { current_line = true } or false,
+        [HANDLER_NAME] = M.enabled and { current_line = true } or false,
+        virtual_lines = false,
         virtual_text = false,
     }, ns())
+    if M.enabled then
+        M.refresh()
+    else
+        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
+            clear(buf)
+        end
+    end
 end

 --- Toggle inline display; returns the new state.
diff --git a/tests/integration/review_diag_display_spec.lua b/tests/integration/review_diag_display_spec.lua
index 7950705..f33e06c 100644
--- a/tests/integration/review_diag_display_spec.lua
+++ b/tests/integration/review_diag_display_spec.lua
@@ -6,9 +6,19 @@ local function ns_cfg()
     return vim.diagnostic.config(nil, require("parley.skill_render").diag_namespace())
 end

+local function display_marks(buf)
+    local display_ns = vim.api.nvim_create_namespace("parley_diagnostic_virtual_lines")
+    return vim.api.nvim_buf_get_extmarks(buf, display_ns, 0, -1, { details = true })
+end
+
 describe("review.diag_display", function()
     after_each(function()
         dd.set(true) -- restore default for other specs
+        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
+            if vim.api.nvim_buf_is_valid(buf) then
+                pcall(vim.diagnostic.reset, require("parley.skill_render").diag_namespace(), buf)
+            end
+        end
     end)

     it("toggles the enabled state", function()
@@ -20,12 +30,89 @@ describe("review.diag_display", function()
         assert.is_true(dd.is_enabled())
     end)

-    it("configures virtual_lines current_line on parley's namespace when on; off when disabled", function()
+    it("configures Parley's custom current-line display on its namespace when on; off when disabled", function()
         dd.set(true)
         local on = ns_cfg()
-        assert.is_truthy(on.virtual_lines) -- { current_line = true }
+        assert.is_false(on.virtual_lines) -- Parley owns its virtual-lines renderer.
+        assert.is_truthy(on["parley/virtual_lines"])
         assert.is_false(on.virtual_text) -- inline single-line is never used
         dd.set(false)
-        assert.is_false(ns_cfg().virtual_lines)
+        assert.is_false(ns_cfg()["parley/virtual_lines"])
+    end)
+
+    it("renders current-line diagnostics from the left column without moving the diagnostic span", function()
+        local skill_render = require("parley.skill_render")
+        local diag_ns = skill_render.diag_namespace()
+        local buf = vim.api.nvim_create_buf(false, true)
+        vim.api.nvim_set_current_buf(buf)
+        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
+            string.rep("x", 120) .. " ACOS[^acos]",
+        })
+
+        dd.set(true)
+        vim.diagnostic.set(diag_ns, buf, { {
+            lnum = 0,
+            col = 121,
+            end_lnum = 0,
+            end_col = 132,
+            message = "ACOS — Advertising Cost of Sales.",
+            severity = vim.diagnostic.severity.INFO,
+            source = "parley-footnote",
+        } })
+
+        vim.wait(100, function()
+            return #display_marks(buf) == 1
+        end)
+
+        local marks = display_marks(buf)
+        assert.are.equal(1, #marks)
+        local details = marks[1][4]
+        assert.is_true(details.virt_lines_leftcol)
+        assert.are.equal("Diagnostics:", details.virt_lines[1][1][1])
+        assert.are_not.equal(string.rep(" ", 121), details.virt_lines[1][1][1])
+        assert.are.equal("ACOS — Advertising Cost of Sales.", details.virt_lines[2][1][1])
+
+        local diagnostics = vim.diagnostic.get(buf, { namespace = diag_ns })
+        assert.are.equal(1, #diagnostics)
+        assert.are.equal(0, diagnostics[1].lnum)
+        assert.are.equal(121, diagnostics[1].col)
+        assert.are.equal(0, diagnostics[1].end_lnum)
+        assert.are.equal(132, diagnostics[1].end_col)
+
+        dd.set(false)
+        assert.are.equal(0, #display_marks(buf))
+        assert.are.equal(1, #vim.diagnostic.get(buf, { namespace = diag_ns }))
+    end)
+
+    it("keeps a multi-line diagnostic visible anywhere inside its span", function()
+        local skill_render = require("parley.skill_render")
+        local diag_ns = skill_render.diag_namespace()
+        local buf = vim.api.nvim_create_buf(false, true)
+        vim.api.nvim_set_current_buf(buf)
+        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
+            "edited line one",
+            "edited line two",
+            "edited line three",
+        })
+
+        dd.set(true)
+        vim.diagnostic.set(diag_ns, buf, { {
+            lnum = 0,
+            col = 0,
+            end_lnum = 2,
+            end_col = 17,
+            message = "review explanation",
+            severity = vim.diagnostic.severity.INFO,
+            source = "parley-skill",
+        } })
+        assert.are.equal(1, #display_marks(buf))
+
+        vim.api.nvim_win_set_cursor(0, { 2, 0 })
+        vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
+        assert.are.equal(1, #display_marks(buf), "span diagnostic should show on middle line")
+
+        vim.api.nvim_win_set_cursor(0, { 3, 0 })
+        vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
+        assert.are.equal(1, #display_marks(buf), "span diagnostic should show on final line")
     end)
 end)
diff --git a/workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md b/workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md
new file mode 100644
index 0000000..da4d424
--- /dev/null
+++ b/workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md
@@ -0,0 +1,3629 @@
+# Boundary Review — parley.nvim#173 (whole-issue close)
+
+| field | value |
+|-------|-------|
+| issue | 173 — diagnostic virtual lines blank on long wrapped markdown |
+| repo | parley.nvim |
+| issue file | workshop/issues/000173-diagnostic-virtual-lines-leftcol.md |
+| boundary | whole-issue close |
+| milestone | — |
+| window | b9094e9bfc89b0f27013c6fd41c38a83b8b61510..HEAD |
+| command | sdlc close --issue 173 |
+| reviewer | codex |
+| timestamp | 2026-07-08T13:29:14-07:00 |
+| verdict | REWORK |
+
+## Review
+
+Reading additional input from stdin...
+OpenAI Codex v0.142.5
+--------
+workdir: /Users/xianxu/workspace/parley.nvim
+model: gpt-5.5
+provider: openai
+approval: never
+sandbox: workspace-write [workdir, /tmp, $TMPDIR, /tmp] (network access enabled)
+reasoning effort: none
+reasoning summaries: none
+session id: 019f4369-b302-73e2-9157-1992fcc2eca0
+--------
+user
+# Code review — the one SDLC boundary review
+
+You are conducting a fresh-context code review at a development boundary —
+whole-issue close — in the **parley.nvim** repository.
+
+- repository: parley.nvim   (root: /Users/xianxu/workspace/parley.nvim)
+- issue:      parley.nvim#173   (file: workshop/issues/000173-diagnostic-virtual-lines-leftcol.md)
+- window:     Base: b9094e9bfc89b0f27013c6fd41c38a83b8b61510   Head: HEAD
+
+Review the **parley.nvim** repo and its tracker — the ariadne base-layer repo itself (changes here propagate to dependent repos). Do not assume any
+other repository or apply another repo's conventions.
+
+You have no prior session context — that is the anti-collusion property. Verify
+behavior against the issue's documented Spec/Plan and the code itself; do NOT
+take the implementor's word in commit messages or docs at face value. Tools are
+read-only: report findings precisely; the main agent (which has session context)
+applies the fixes, commits, and re-runs.
+
+Read the diff against the issue's Spec + Plan, then work the checklist below.
+Categorize every finding by severity — not everything is Critical; a nitpick
+marked Critical is noise.
+
+  Critical (must fix before crossing the boundary)
+    - correctness bugs; crashes / panics on unexpected input
+    - behavior drift from stated contracts (for ports of existing code where
+      byte-faithfulness was promised, diff against the source)
+    - silent error swallowing where the source raised
+  Important (fix before the boundary if cheap)
+    - API design of newly-introduced internal packages (downstream work will
+      consume them; is the surface stable?)
+    - missing test coverage that would catch the kind of bug shipped
+    - inconsistent error handling across the diff
+  Minor (note for future)
+    - style nits, naming, comment density; performance only if hot-path
+
+## Review checklist
+
+Code quality
+  - Clean separation of concerns; edge cases handled (empty / nil / unexpected).
+  - Proper error handling — no silent swallowing where the source raised.
+  - No duplicated logic / copy-paste that should be a shared helper.
+
+Testing
+  - Tests pin real logic, not mocks reasserting the implementation.
+  - The kind of bug this diff could ship is covered.
+  - PURE entities tested without IO; INTEGRATION via injected fakes (see below).
+
+Requirements traceability
+  - Every Plan checklist item this boundary claims is actually delivered.
+  - Implementation matches the Spec; no undeclared scope creep.
+  - Breaking changes documented.
+
+Production readiness
+  - Migration / backward-compatibility considered where state or formats change.
+  - Docs / atlas updated for new surface (see the Docs update gate).
+
+## Core concepts cross-check (if the plan has a Core concepts table)
+
+The plan should list entities in a greppable table — name, kind
+(PURE/INTEGRATION), file location, status (new/modified/deleted). For each row:
+  - Verify the entity exists at the stated path (grep the diff or filesystem).
+  - PURE: tests run without IO (no exec, net, mutable fs). If tests need mocks
+    to run, it isn't really PURE — flag Critical and recommend promoting it to
+    INTEGRATION.
+  - INTEGRATION: injected into pure callers, not invoked directly from business
+    logic.
+  - "modified" / "deleted": the diff shows the expected change/removal at the
+    stated location.
+Any contradiction between table and code = Critical finding, plus a plan-revision
+recommendation (a "## Revisions" entry so the plan stops claiming what the code
+doesn't deliver).
+
+## Docs update gate (atlas + README, per AGENTS.md §8)
+
+The boundary should update user-facing docs for any new surface introduced:
+
+  - **atlas/** — new architectural surface, flow, or terminology. Scan the diff
+    for new entity types, subcommands, conventions, file-tree locations. Any
+    present without corresponding atlas/ changes in the same range = Important
+    finding ("atlas update appears missing for <surface>").
+  - **README.md** — new user-facing surface a reader runs or types: subcommands,
+    flags, keybindings, config keys, install/usage steps. If the diff adds or
+    changes such surface and README.md is not updated in the same range =
+    Important finding ("README update appears missing for <surface>"). This is the
+    class of gap that used to surface only at the merge-time `specs` judge (#142);
+    catch it here, at the earliest gate, before the close verdict is recorded.
+
+## Architecture (the at-review backstop — these matter most long-term)
+
+Work through each of ARCH-DRY, ARCH-PURE, ARCH-PURPOSE explicitly, applying its at-review lens. The
+full principle definitions are delivered in the ARCHITECTURE PRINCIPLES block
+right after this prompt — for EACH marker, state pass or flag, and cite the
+marker (e.g. ARCH-DRY) in any finding. Architecture is where review has the
+least training signal and the longest-delayed payoff, so be deliberate here, not
+holistic.
+
+## Verdict + output
+
+Begin your response with this fenced verdict block — the machine-read handoff:
+
+```verdict
+verdict: <SHIP | FIX-THEN-SHIP | REWORK>
+confidence: <high | medium | low>
+```
+
+  SHIP           ready; ship it
+  FIX-THEN-SHIP  ship after addressing the findings (non-blocking at the gate)
+  REWORK         blocking; needs rework before shipping — fix + re-run
+
+The fenced ```` ```verdict ```` block above is the **authoritative machine-read
+handoff** — emit it as the first thing in your response. (A prose
+`VERDICT: <TOKEN>` first line still satisfies the legacy contract as a fallback,
+but the block is what the binary trusts.)
+
+After the verdict block: a 1-paragraph summary — what worked, what blocks SHIP if
+it isn't — followed by:
+  1. Strengths: 2-5 specific things done well (file:line where useful). Affirm
+     validated approaches so the operator knows what's confirmed-good ground.
+     Empty acceptable for trivial boundaries.
+  2. Critical findings (file:line + fix sketch); empty if none.
+  3. Important findings (same format).
+  4. Minor findings (terse one-liners).
+  5. Test coverage notes.
+  6. Architectural notes for upcoming work.
+  7. Plan revision recommendations: specific "## Revisions" entries the plan
+     needs (empty if the plan still matches the code).
+
+
+ARCHITECTURE PRINCIPLES — work through each of the 3 entries below explicitly, applying its `at-review` lens; cite the marker (e.g. ARCH-DRY) in any finding.
+
+# Architecture principles (ARCH-*)
+
+Injected architectural taste — the structural decisions whose payoff (or cost)
+shows up many turns, often months, down the road. Agents are strong at local
+tactics and weak here, so these are checked **at-plan** (when the design is being
+made — highest leverage) and **at-review** (backstop, on the diff). Cite the
+marker (e.g. `ARCH-DRY`) in plans, `## Log` entries, and review findings.
+
+This file is the single source; it is embedded into the planning, plan-quality,
+and code-review prompts. The human narrative lives in AGENTS.md "Core Design
+Principles"; this is its machine-delivered companion.
+
+## ARCH-DRY — Don't Repeat Yourself
+
+- **principle:** Reuse before adding. One source of truth per fact/behavior; no
+  duplicated logic, copy-pasted blocks, or parallel functions that should be one
+  shared helper.
+- **at-plan:** Flag a plan that re-implements something the codebase already has,
+  or that will obviously duplicate logic across the new files instead of
+  extracting a shared helper. Name the existing thing it should reuse.
+- **at-review:** Flag duplicated logic / copy-pasted blocks / near-identical
+  functions in the diff; point at the consolidation (file:line + the shared
+  helper they should become).
+
+## ARCH-PURE — Pure core, thin IO shell
+
+- **principle:** The majority of code is pure functions (deterministic, no side
+  effects); a thin "glue" layer at the boundary touches IO/UI/network/clock. Pure
+  functions are unit-tested directly; the glue is kept small and injected.
+- **at-plan:** Flag a design that buries business logic inside IO/handlers, or
+  that will only be testable with heavy mocks (a sign logic isn't separated from
+  IO). The plan should name what's pure vs the thin IO seam.
+- **at-review:** Flag business logic mixed with IO in the diff; logic that should
+  be a pure function injected into a thin caller. If a test needs mocks to run a
+  "pure" entity, it isn't pure — recommend extracting the IO to the boundary.
+
+## ARCH-PURPOSE — Serve the issue's actual purpose
+
+- **principle:** Deliver the issue's stated purpose, not the easy subset of it. A
+  single-source / "compiled to consumers" change is not done until **every
+  consumer derives** from the source — the source is *enforced*, not just
+  documentation a surface happens to restate; a hand-maintained restatement of the
+  model is a deferred consumer, not a finished one. "Follow-up" is for separable
+  extensions, never for the thing that is the point. This is the *opposite axis*
+  from Simplicity-First/YAGNI: not "build for an imagined future," but "don't
+  **under**-deliver the purpose you already committed to."
+- **at-plan:** Flag a plan whose scope is a strict subset of the issue's stated
+  goal / Done-when where the part deferred as "follow-up" *is* the purpose (e.g.
+  wires one consumer + enforcement but leaves the consumers that motivated the
+  issue as documentation that doesn't derive). Ask: does the plan fulfill the
+  purpose, or just the cheap win? Name the deferred purpose.
+- **at-review:** Does the diff *fulfill* the purpose or settle for the easy win?
+  For a single-source change, run the **shadow-sweep** — enumerate the consumers,
+  confirm each derives from the source, flag any remaining hand-maintained
+  restatement of the model. A "follow-up" that is actually the deferred point of
+  the issue is a finding, not a deferral.
+
+
+OUTPUT CONTRACT (machine-read — do not deviate). LEAD your response with the
+fenced ```verdict block shown above — that is the authoritative handoff the binary
+reads (its `verdict:` value is one of the listed tokens). Everything after the block
+is advisory: a non-blocking verdict WITH findings still PASSES the gate. A bare
+`VERDICT: <TOKEN>` line is accepted only as a FALLBACK when the block is absent.
+
+Diff:
+diff --git a/atlas/chat/inline_define.md b/atlas/chat/inline_define.md
+index 270e924..6df2cf4 100644
+--- a/atlas/chat/inline_define.md
++++ b/atlas/chat/inline_define.md
+@@ -1,14 +1,14 @@
+ # Inline Term Definition
+
+ Select a phrase in a chat transcript, press **`<M-CR>`** (visual mode), and a
+-concise, context-aware definition appears as an inline diagnostic (grey
+-`virtual_lines`) under the phrase. The selected text stays in place and gets a
+-markdown footnote reference (`ASIN[^asin]`), while the definition is stored in a
+-managed footnote footer at the end of the chat transcript. Persisted managed
+-footnotes are rehydrated into diagnostics when any markdown buffer is entered or
+-refreshed. The whole new annotation is **undoable** — `u` reverts the footnote
+-edit and clears both decorations (see Undo below). For jargon you don't know
+-(e.g. `ASIN`), it's a one-keystroke lookup. Added in
++concise, context-aware definition appears as an inline diagnostic under the
++phrase. The selected text stays in place and gets a markdown footnote reference
++(`ASIN[^asin]`), while the definition is stored in a managed footnote footer at
++the end of the chat transcript. Persisted managed footnotes are rehydrated into
++diagnostics when any markdown buffer is entered or refreshed. The whole new
++annotation is **undoable** — `u` reverts the footnote edit and clears both
++decorations (see Undo below). For jargon you don't know (e.g. `ASIN`), it's a
++one-keystroke lookup. Added in
+ [#161](../../workshop/issues/000161-inline-term-definition.md) (R1 added the
+ highlight/undo); [#166](../../workshop/issues/000166-visual-selection-definition-system-manages-footnote.md)
+ made the definition durable as a managed footnote; [#167](../../workshop/issues/000167-define-diagnostic-highlight-span.md)
+@@ -41,9 +41,9 @@ rehydrates persisted managed footnotes in all markdown buffers.
+    inline `term[^id]` spans (`define.format_definition` →
+    `skill_render.format_diagnostic_message`) on the `parley_skill` namespace;
+    **(d)** records the undo/redo projection states.
+-   `diag_display`'s `virtual_lines{current_line=true}` reveals the diagnostic
+-   (cursor parked on the term's line). A no-`emit_definition` response leaves no
+-   footnote reference/footer.
++   `diag_display`'s Parley-owned left-column virtual-line display reveals the
++   diagnostic (cursor parked on the term's line). A no-`emit_definition` response
++   leaves no footnote reference/footer.
+
+ ## Undo (`u`) — reuses review's projection
+
+@@ -126,8 +126,8 @@ tool-call args (`result.calls[1].input`), read in `on_done`.
+ - `skill_render.refresh_footnote_diagnostics` owns only diagnostics tagged
+   `parley-footnote` and preserves other `parley_skill` diagnostics, so review
+   diagnostics are not cleared by markdown footnote refresh.
+-- A diagnostic's `virtual_lines` auto-hide when the cursor leaves its line. The
+-  footnote persists in the file if saved.
++- A diagnostic's Parley virtual-line block auto-hides when the cursor leaves its
++  line. The footnote persists in the file if saved.
+
+ ## Key files
+
+diff --git a/atlas/modes/review.md b/atlas/modes/review.md
+index b470783..ef656df 100644
+--- a/atlas/modes/review.md
++++ b/atlas/modes/review.md
+@@ -162,12 +162,16 @@ session-scoped undo); per-state snapshots aren't journaled.
+ The edit "why" (the per-edit `explain`) is an INFO diagnostic on parley's
+ `parley_skill` namespace. `lua/parley/skills/review/diag_display.lua` controls how
+ it shows — scoped to that namespace, so the user's LSP/global diagnostics are
+-untouched. Default **on**: `virtual_lines { current_line = true }`, so the
+-(hard-wrapped, via `skill_render.format_diagnostic_message`) why **auto-expands
+-below an edit when the cursor is in that edit's region** (`attach_diagnostics` spans `lnum..end_lnum`)
+-and hides otherwise. `:ParleyShowDiagnostics` toggles it. The built-in `]d`/`[d`
+-(jump) and `<C-W>d` (float, wraps) also work on these diagnostics. Composes with
+-M5 — re-renders on undo/redo.
++untouched. Default **on**: Parley's custom `parley/virtual_lines` diagnostic
++handler renders a left-column virtual-line block headed `Diagnostics:` for the
++current line. It avoids Neovim's stock virtual-lines indentation-by-diagnostic
++column, which can hide messages on long wrapped prose. The hard-wrapped why
++(`skill_render.format_diagnostic_message`) **auto-expands below an edit when the
++cursor is in that edit's region** (`attach_diagnostics` spans
++`lnum..end_lnum`) and hides otherwise. `:ParleyShowDiagnostics` toggles it. The
++built-in `]d`/`[d` (jump) and `<C-W>d` (float, wraps) still work on these
++diagnostics because the underlying diagnostic spans remain unchanged. Composes
++with M5 — re-renders on undo/redo.
+
+ ## Progress bar (#133 M7)
+
+diff --git a/lua/parley/skills/review/diag_display.lua b/lua/parley/skills/review/diag_display.lua
+index 4617a35..6fd4da6 100644
+--- a/lua/parley/skills/review/diag_display.lua
++++ b/lua/parley/skills/review/diag_display.lua
+@@ -10,20 +10,150 @@ local M = {}
+
+ M.enabled = true -- default on (cursor-region auto-show)
+
++local HANDLER_NAME = "parley/virtual_lines"
++local DISPLAY_NS = "parley_diagnostic_virtual_lines"
++local DISPLAY_AUGROUP = "parley_diagnostic_virtual_lines"
++local HEADER_HL = "ParleyDiagnosticVirtualLineHeader"
++local MESSAGE_HL = "ParleyDiagnosticVirtualLine"
++
++local display_ns_id
++local display_augroup
++
+ -- Parley's review diagnostic namespace — single-sourced from skill_render (which
+ -- owns the namespace) so the identity isn't a duplicated literal (#133 M6 review).
+ local function ns()
+     return require("parley.skill_render").diag_namespace()
+ end
+
++local function ensure_display()
++    if not display_ns_id then
++        display_ns_id = vim.api.nvim_create_namespace(DISPLAY_NS)
++    end
++    if not display_augroup then
++        display_augroup = vim.api.nvim_create_augroup(DISPLAY_AUGROUP, { clear = true })
++    end
++    vim.api.nvim_set_hl(0, HEADER_HL, { link = "DiagnosticInfo" })
++    vim.api.nvim_set_hl(0, MESSAGE_HL, { link = "DiagnosticFloatingInfo" })
++end
++
++local function clear(buf)
++    ensure_display()
++    if vim.api.nvim_buf_is_valid(buf) then
++        vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
++        pcall(vim.api.nvim_clear_autocmds, { group = display_augroup, buffer = buf })
++    end
++end
++
++local function current_line_for(buf)
++    if vim.api.nvim_get_current_buf() ~= buf then
++        return nil
++    end
++    return vim.api.nvim_win_get_cursor(0)[1] - 1
++end
++
++local function diagnostic_message_lines(diagnostic)
++    local lines = {}
++    for _, line in ipairs(vim.split(tostring(diagnostic.message or ""), "\n", { plain = true })) do
++        table.insert(lines, { { line ~= "" and line or " ", MESSAGE_HL } })
++    end
++    if #lines == 0 then
++        table.insert(lines, { { " ", MESSAGE_HL } })
++    end
++    return lines
++end
++
++local function render(buf, diagnostics, current_line_only)
++    ensure_display()
++    if not vim.api.nvim_buf_is_valid(buf) then
++        return
++    end
++    vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
++
++    local line = current_line_only and current_line_for(buf) or nil
++    if current_line_only and not line then
++        return
++    end
++
++    local by_line = {}
++    for _, diagnostic in ipairs(diagnostics or {}) do
++        if not current_line_only or diagnostic.lnum == line then
++            by_line[diagnostic.lnum] = by_line[diagnostic.lnum] or {}
++            table.insert(by_line[diagnostic.lnum], diagnostic)
++        end
++    end
++
++    for lnum, line_diagnostics in pairs(by_line) do
++        table.sort(line_diagnostics, function(a, b)
++            return (a.col or 0) < (b.col or 0)
++        end)
++        local virt_lines = { { { "Diagnostics:", HEADER_HL } } }
++        for _, diagnostic in ipairs(line_diagnostics) do
++            vim.list_extend(virt_lines, diagnostic_message_lines(diagnostic))
++        end
++        vim.api.nvim_buf_set_extmark(buf, display_ns_id, lnum, 0, {
++            virt_lines = virt_lines,
++            virt_lines_leftcol = true,
++            virt_lines_above = false,
++        })
++    end
++end
++
++local function register_handler()
++    ensure_display()
++    vim.diagnostic.handlers[HANDLER_NAME] = {
++        show = function(namespace, bufnr, diagnostics, opts)
++            if namespace ~= ns() then
++                return
++            end
++            bufnr = vim._resolve_bufnr(bufnr)
++            local handler_opts = opts and opts[HANDLER_NAME] or {}
++            local current_line_only = handler_opts.current_line == true
++            clear(bufnr)
++            if current_line_only then
++                vim.api.nvim_create_autocmd("CursorMoved", {
++                    buffer = bufnr,
++                    group = display_augroup,
++                    callback = function()
++                        render(bufnr, diagnostics, true)
++                    end,
++                })
++            end
++            render(bufnr, diagnostics, current_line_only)
++        end,
++        hide = function(namespace, bufnr)
++            if namespace ~= ns() then
++                return
++            end
++            clear(vim._resolve_bufnr(bufnr))
++        end,
++    }
++end
++
++function M.refresh(buf)
++    if not M.enabled then
++        return
++    end
++    buf = buf or vim.api.nvim_get_current_buf()
++    render(buf, vim.diagnostic.get(buf, { namespace = ns() }), true)
++end
++
+ --- Apply the inline-display config for parley's review namespace.
+ --- @param on boolean
+ function M.set(on)
+     M.enabled = on and true or false
++    register_handler()
+     vim.diagnostic.config({
+-        virtual_lines = M.enabled and { current_line = true } or false,
++        [HANDLER_NAME] = M.enabled and { current_line = true } or false,
++        virtual_lines = false,
+         virtual_text = false,
+     }, ns())
++    if M.enabled then
++        M.refresh()
++    else
++        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
++            clear(buf)
++        end
++    end
+ end
+
+ --- Toggle inline display; returns the new state.
+diff --git a/tests/integration/review_diag_display_spec.lua b/tests/integration/review_diag_display_spec.lua
+index 7950705..97fe2e8 100644
+--- a/tests/integration/review_diag_display_spec.lua
++++ b/tests/integration/review_diag_display_spec.lua
+@@ -6,9 +6,19 @@ local function ns_cfg()
+     return vim.diagnostic.config(nil, require("parley.skill_render").diag_namespace())
+ end
+
++local function display_marks(buf)
++    local display_ns = vim.api.nvim_create_namespace("parley_diagnostic_virtual_lines")
++    return vim.api.nvim_buf_get_extmarks(buf, display_ns, 0, -1, { details = true })
++end
++
+ describe("review.diag_display", function()
+     after_each(function()
+         dd.set(true) -- restore default for other specs
++        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
++            if vim.api.nvim_buf_is_valid(buf) then
++                pcall(vim.diagnostic.reset, require("parley.skill_render").diag_namespace(), buf)
++            end
++        end
+     end)
+
+     it("toggles the enabled state", function()
+@@ -20,12 +30,57 @@ describe("review.diag_display", function()
+         assert.is_true(dd.is_enabled())
+     end)
+
+-    it("configures virtual_lines current_line on parley's namespace when on; off when disabled", function()
++    it("configures Parley's custom current-line display on its namespace when on; off when disabled", function()
+         dd.set(true)
+         local on = ns_cfg()
+-        assert.is_truthy(on.virtual_lines) -- { current_line = true }
++        assert.is_false(on.virtual_lines) -- Parley owns its virtual-lines renderer.
++        assert.is_truthy(on["parley/virtual_lines"])
+         assert.is_false(on.virtual_text) -- inline single-line is never used
+         dd.set(false)
+-        assert.is_false(ns_cfg().virtual_lines)
++        assert.is_false(ns_cfg()["parley/virtual_lines"])
++    end)
++
++    it("renders current-line diagnostics from the left column without moving the diagnostic span", function()
++        local skill_render = require("parley.skill_render")
++        local diag_ns = skill_render.diag_namespace()
++        local buf = vim.api.nvim_create_buf(false, true)
++        vim.api.nvim_set_current_buf(buf)
++        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
++            string.rep("x", 120) .. " ACOS[^acos]",
++        })
++
++        dd.set(true)
++        vim.diagnostic.set(diag_ns, buf, { {
++            lnum = 0,
++            col = 121,
++            end_lnum = 0,
++            end_col = 132,
++            message = "ACOS — Advertising Cost of Sales.",
++            severity = vim.diagnostic.severity.INFO,
++            source = "parley-footnote",
++        } })
++
++        vim.wait(100, function()
++            return #display_marks(buf) == 1
++        end)
++
++        local marks = display_marks(buf)
++        assert.are.equal(1, #marks)
++        local details = marks[1][4]
++        assert.is_true(details.virt_lines_leftcol)
++        assert.are.equal("Diagnostics:", details.virt_lines[1][1][1])
++        assert.are_not.equal(string.rep(" ", 121), details.virt_lines[1][1][1])
++        assert.are.equal("ACOS — Advertising Cost of Sales.", details.virt_lines[2][1][1])
++
++        local diagnostics = vim.diagnostic.get(buf, { namespace = diag_ns })
++        assert.are.equal(1, #diagnostics)
++        assert.are.equal(0, diagnostics[1].lnum)
++        assert.are.equal(121, diagnostics[1].col)
++        assert.are.equal(0, diagnostics[1].end_lnum)
++        assert.are.equal(132, diagnostics[1].end_col)
++
++        dd.set(false)
++        assert.are.equal(0, #display_marks(buf))
++        assert.are.equal(1, #vim.diagnostic.get(buf, { namespace = diag_ns }))
+     end)
+ end)
+diff --git a/workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md b/workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md
+new file mode 100644
+index 0000000..12f0951
+--- /dev/null
++++ b/workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md
+@@ -0,0 +1,94 @@
++# Diagnostic Virtual Lines Left Column Implementation Plan
++
++> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.
++
++**Goal:** Make Parley's inline diagnostic display visible on long wrapped markdown lines by rendering diagnostic virtual lines from the left column.
++
++**Architecture:** Keep diagnostic data unchanged: spans stay anchored to selected text and footnote references. Replace only Parley's namespace display shell in `diag_display.lua`, so global/LSP diagnostics still use Neovim defaults. This follows ARCH-DRY by keeping one Parley display controller and ARCH-PURE by avoiding parser/data changes.
++
++**Tech Stack:** Lua, Neovim diagnostics, extmarks, Plenary/Busted tests.
++
++---
++
++## Core Concepts
++
++### Pure Entities
++
++| Name | Lives in | Status |
++|------|----------|--------|
++| `ParleyDiagnosticMessageLines` | `lua/parley/skills/review/diag_display.lua` | new |
++
++- **ParleyDiagnosticMessageLines** — deterministic conversion from a diagnostic message string into visible virtual-line rows with a `Diagnostics:` header.
++  - **Relationships:** 1:N from one diagnostic message to display rows.
++  - **DRY rationale:** Both review diagnostics and footnote diagnostics consume the same Parley namespace display.
++  - **Future extensions:** If Parley later adds source-specific labels, this formatter is the one place to widen.
++
++### Integration Points
++
++| Name | Lives in | Status | Wraps |
++|------|----------|--------|-------|
++| `ParleyDiagnosticVirtualLines` | `lua/parley/skills/review/diag_display.lua` | modified | Neovim extmarks |
++
++- **ParleyDiagnosticVirtualLines** — Parley-owned inline diagnostic renderer scoped to `skill_render.diag_namespace()`.
++  - **Injected into:** `diag_display.set(on)`; toggling still owns all inline display setup.
++  - **Future extensions:** Can add color overrides without changing diagnostic producers.
++
++## Chunk 1: Left-Column Renderer
++
++**Files:**
++- Modify: `lua/parley/skills/review/diag_display.lua`
++- Modify: `tests/integration/review_diag_display_spec.lua`
++- Modify: `atlas/modes/review.md`
++- Modify: `atlas/chat/inline_define.md`
++- Modify: `workshop/issues/000173-diagnostic-virtual-lines-leftcol.md`
++
++- [x] **Step 1: Write failing tests**
++
++Add integration coverage that:
++- Sets a Parley diagnostic at a high column on a long line.
++- Enables `diag_display`.
++- Asserts the generated display extmark has `virt_lines_leftcol = true`.
++- Asserts the first virtual-line chunk is `Diagnostics:` instead of leading spaces.
++- Asserts `dd.set(false)` clears the Parley display extmark while leaving the diagnostic data intact.
++
++Run:
++
++```bash
++nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"
++```
++
++Expected: FAIL because the stock diagnostic handler emits leading-space virtual lines and `diag_display` has no custom extmark namespace.
++
++- [x] **Step 2: Implement the renderer**
++
++In `lua/parley/skills/review/diag_display.lua`:
++- Add a private display namespace.
++- Add a private function that clears Parley diagnostic virtual-line extmarks.
++- Add a private render function that reads diagnostics from `skill_render.diag_namespace()`, filters to the current cursor line, and writes `virt_lines` with `virt_lines_leftcol = true`.
++- Configure Neovim diagnostics for the Parley namespace with `virtual_lines = false`, `virtual_text = false`, and existing signs/underline behavior.
++- Register a buffer-local `CursorMoved` autocmd for visible Parley buffers so current-line behavior keeps updating.
++
++- [x] **Step 3: Run green focused tests**
++
++Run:
++
++```bash
++nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"
++```
++
++Expected: PASS.
++
++- [x] **Step 4: Update docs and issue log**
++
++Update atlas text that says Parley uses built-in diagnostic `virtual_lines` so it instead describes the Parley-owned left-column inline renderer. Record red/green evidence in the issue log and tick plan items.
++
++- [x] **Step 5: Final verification**
++
++Run:
++
++```bash
++git diff --check -- lua/parley/skills/review/diag_display.lua tests/integration/review_diag_display_spec.lua atlas/modes/review.md atlas/chat/inline_define.md workshop/issues/000173-diagnostic-virtual-lines-leftcol.md workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md
++make test
++```
++
++Expected: all pass.
+
+
+codex
+I’ll use the required session-start skill, then read the issue, plan, and actual diff from the repository so the review is grounded in files rather than the pasted summary.
+exec
+/bin/zsh -lc "sed -n '1,220p' /Users/xianxu/workspace/ariadne/construct/adapted/superpowers-using-superpowers/SKILL.md && sdlc --help | sed -n '1,220p' && sed -n '1,220p' workshop/lessons.md" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+---
+name: superpowers-using-superpowers
+description: Use when starting any conversation - establishes how to find and use skills, requiring Skill tool invocation before ANY response including clarifying questions
+---
+
+<SUBAGENT-STOP>
+If you were dispatched as a subagent to execute a specific task, skip this skill.
+</SUBAGENT-STOP>
+
+<EXTREMELY-IMPORTANT>
+If you think there is even a 1% chance a skill might apply to what you are doing, you ABSOLUTELY MUST invoke the skill.
+
+IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.
+
+This is not negotiable. This is not optional. You cannot rationalize your way out of this.
+</EXTREMELY-IMPORTANT>
+
+## Instruction Priority
+
+> **Ariadne note:** AGENTS.md Section 3 governs subagent strategy and overrides skills that mandate subagent-driven-development as the default execution path.
+
+Superpowers skills override default system prompt behavior, but **user instructions always take precedence**:
+
+1. **User's explicit instructions** (CLAUDE.md, GEMINI.md, AGENTS.md, direct requests) — highest priority
+2. **Superpowers skills** — override default system behavior where they conflict
+3. **Default system prompt** — lowest priority
+
+If CLAUDE.md, GEMINI.md, or AGENTS.md says "don't use TDD" and a skill says "always use TDD," follow the user's instructions. The user is in control.
+
+## How to Access Skills
+
+**In Claude Code:** Use the `Skill` tool. When you invoke a skill, its content is loaded and presented to you—follow it directly. Never use the Read tool on skill files.
+
+**In Gemini CLI:** Skills activate via the `activate_skill` tool. Gemini loads skill metadata at session start and activates the full content on demand.
+
+**In other environments:** Check your platform's documentation for how skills are loaded.
+
+## Platform Adaptation
+
+Skills use Claude Code tool names. Non-CC platforms: see `references/codex-tools.md` (Codex) for tool equivalents. Gemini CLI users get the tool mapping loaded automatically via GEMINI.md.
+
+# Using Skills
+
+## The Rule
+
+**Invoke relevant or requested skills BEFORE any response or action.** Even a 1% chance a skill might apply means that you should invoke the skill to check. If an invoked skill turns out to be wrong for the situation, you don't need to use it.
+
+```dot
+digraph skill_flow {
+    "User message received" [shape=doublecircle];
+    "About to EnterPlanMode?" [shape=doublecircle];
+    "Already brainstormed?" [shape=diamond];
+    "Invoke brainstorming skill" [shape=box];
+    "Might any skill apply?" [shape=diamond];
+    "Invoke Skill tool" [shape=box];
+    "Announce: 'Using [skill] to [purpose]'" [shape=box];
+    "Has checklist?" [shape=diamond];
+    "Create TodoWrite todo per item" [shape=box];
+    "Follow skill exactly" [shape=box];
+    "Respond (including clarifications)" [shape=doublecircle];
+
+    "About to EnterPlanMode?" -> "Already brainstormed?";
+    "Already brainstormed?" -> "Invoke brainstorming skill" [label="no"];
+    "Already brainstormed?" -> "Might any skill apply?" [label="yes"];
+    "Invoke brainstorming skill" -> "Might any skill apply?";
+
+    "User message received" -> "Might any skill apply?";
+    "Might any skill apply?" -> "Invoke Skill tool" [label="yes, even 1%"];
+    "Might any skill apply?" -> "Respond (including clarifications)" [label="definitely not"];
+    "Invoke Skill tool" -> "Announce: 'Using [skill] to [purpose]'";
+    "Announce: 'Using [skill] to [purpose]'" -> "Has checklist?";
+    "Has checklist?" -> "Create TodoWrite todo per item" [label="yes"];
+    "Has checklist?" -> "Follow skill exactly" [label="no"];
+    "Create TodoWrite todo per item" -> "Follow skill exactly";
+}
+```
+
+## Red Flags
+
+These thoughts mean STOP—you're rationalizing:
+
+| Thought | Reality |
+|---------|---------|
+| "This is just a simple question" | Questions are tasks. Check for skills. |
+| "I need more context first" | Skill check comes BEFORE clarifying questions. |
+| "Let me explore the codebase first" | Skills tell you HOW to explore. Check first. |
+| "I can check git/files quickly" | Files lack conversation context. Check for skills. |
+| "Let me gather information first" | Skills tell you HOW to gather information. |
+| "This doesn't need a formal skill" | If a skill exists, use it. |
+| "I remember this skill" | Skills evolve. Read current version. |
+| "This doesn't count as a task" | Action = task. Check for skills. |
+| "The skill is overkill" | Simple things become complex. Use it. |
+| "I'll just do this one thing first" | Check BEFORE doing anything. |
+| "This feels productive" | Undisciplined action wastes time. Skills prevent this. |
+| "I know what that means" | Knowing the concept ≠ using the skill. Invoke it. |
+
+## Skill Priority
+
+When multiple skills could apply, use this order:
+
+1. **Process skills first** (brainstorming, debugging) - these determine HOW to approach the task
+2. **Implementation skills second** (frontend-design, mcp-builder) - these guide execution
+
+"Let's build X" → brainstorming first, then implementation skills.
+"Fix this bug" → debugging first, then domain-specific skills.
+
+## Skill Types
+
+**Rigid** (TDD, debugging): Follow exactly. Don't adapt away discipline.
+
+**Flexible** (patterns): Adapt principles to context.
+
+The skill itself tells you which.
+
+## User Instructions
+
+Instructions say WHAT, not HOW. "Add X" or "Fix Y" doesn't mean skip workflows.
+sdlc collects ariadne's SDLC checkpoint guards into one binary. Each subcommand
+owns one checkpoint: it requires evidence at the gate, mutates state, logs the
+transition, and refuses transitions that lack it. We don't model the SDLC as a
+state machine — stages stay prose; we codify the gates between them where drift
+recurs. `sdlc` manages the development life cycle; prefer it over `git`/`gh`.
+
+BEFORE WORK
+  - `sdlc claim --issue N` — the single start-of-work gesture, a CHEAP LOCK.
+    Flips an *open* issue to `working` and publishes the claim to origin/main so
+    peer agents see it. No estimate demanded (#113) — claim early, the moment an
+    idea crystallizes. `--no-start` suppresses the flip.
+  - Do NOT hand-edit an issue's `status:` — let `sdlc claim` or `sdlc issue
+    set-status` own that transition (it carries the reopen/`→ done` guards).
+
+ENTER IMPLEMENTATION
+  - After plan approval, before editing code, run `sdlc change-code`. It owns the
+    branching decision (in-place branch by default; `--worktree=yes` for an
+    isolated worktree), the plan-quality check, and the `estimate_hours` gate
+    (relocated here from claim, #113). Don't start coding without it.
+
+PUBLISH
+  - Publishing goes through a PR: `sdlc pr` → `sdlc merge`. Direct `sdlc push`
+    if working directly on main.
+  - Publish ONCE at issue close, not per milestone — and do NOT reuse a branch
+    name that already has a merged PR. `sdlc merge` refuses (#148) when a branch
+    has commits not in main despite a merged PR (a reused name would otherwise
+    silently strand the new commits); rename to a fresh branch, `sdlc pr`, retry.
+
+RECOVER
+  - After a compaction or session resume, run `sdlc state` to recover where you
+    are instead of re-inferring from issue files.
+
+LOCAL REPO TRANSACTION LOCK
+  - Mutating verbs take an SDLC-owned repo transaction lock at
+    `.git/sdlc.lock` before reading/writing issue state, committing, changing
+    branches, or pushing. The lock is local to the Git common dir, so linked
+    worktrees of the same repo serialize with each other.
+  - Wait messages identify the holder pid and command when metadata is
+    available. `close` and `milestone-close` release the lock while the external
+    boundary-review subprocess runs, then reacquire before finalization; if HEAD
+    or the issue/project file state they prepared changed meanwhile, they refuse
+    to finalize and tell you to rerun. `change-code`, `merge`, and `push` can still hold the lock during
+    long-running review/ship transactions; wait or retry rather than removing
+    the lock while that process is alive.
+  - A dead same-host holder is reclaimed automatically; initializing metadata
+    is waited through. Other stale/timeout errors tell you how to inspect
+    `.git/sdlc.lock`. Remote push/ref races are separate: the local lock
+    serializes this checkout, not another machine or clone.
+
+WHEN A VERB ERRORS
+  Do NOT route around it with hand-rolled `git`/`gh`. Its errors are next-action
+  specs. The fix is one of two things:
+    (a) satisfy the precondition it names and re-run the same verb (e.g. `sdlc
+        merge` saying "no upstream" → run `sdlc pr` first, then `sdlc merge`); or
+    (b) if the error is a genuine gap in `sdlc` itself, fix that edge case in the
+        source and re-run. We're still ironing out edge cases.
+  Only drop to manual when a verb genuinely cannot express the need — say so.
+
+These gates sit inside a wider prose arc the binary does NOT own: ideation
+(parley/pensive) → brainstorm → plan → build → milestone review (`sdlc judge`,
+auto-dispatched) → close/ship → postmortem.
+
+CONVENTIONS
+
+  --issue vs --github-issue — `--issue N` always means workshop/issues
+  (6-digit ID). `--github-issue N` means a GitHub issue number. Bare `--issue`
+  never means a GitHub issue.
+
+  Form vs essence — checkpoint guards (close, milestone-close, push, merge)
+  defend against *omission* via required-evidence flags; `sdlc judge` defends
+  against *theater* via fresh-context review. Form runs first; judge second.
+
+The verb list + per-verb help (`sdlc <verb> --help`) follow below.
+
+Usage:
+  sdlc [flags]
+  sdlc [command]
+
+Available Commands:
+  claim           Start work: flip an open issue to working + broadcast the claim
+  start-plan      Enter planning: deliver the architecture principles to design against (#75)
+  change-code     Enter implementation after the structural + plan-quality gates
+  issue           Create + manage issues (new / set-status / list / show)
+  actual          Compute an issue's focused dev-hours via active-time-v3 (#68)
+  active-time     Per-issue active-time attribution table (the v3 engine, standalone)
+  close           Close an issue or milestone (ACTUAL + VERIFIED + atlas/project sweep)
+  milestone-close Close one milestone + auto-dispatch its review
+  pr              Open a pull request from a feature branch
+  merge           Merge the PR, archive done issues, clean up
+  push            Ship from main (clean tree + pre-merge judges + archive)
+  state           Inspect workflow state (branch, working issues, drift)
+  resolve         Resolve a symbolic artifact ref (ariadne#11, #15 M4) to its current path(s) — read-only
+  open            Resolve a ref and open the primary artifact in $EDITOR
+  judge           Run an LLM-judge check against the diff (fresh-context)
+  arch-principles Print the ARCH-* architecture principles (single source; pull for non-gate work)
+  estimate-source Name the shared estimate method + the repo-local calibration source (pull)
+  process-manual  Unroll every injection source into a linked process manual (#153)
+  propagate-base  Re-weave every recursive dependent of this repo (foundation-first)
+  help            Help about any command
+
+Flags:
+  -h, --help   help for sdlc
+
+Use "sdlc [command] --help" for more information about a command.
+# Lessons
+
+## 2026-06-10
+- A config→data mapping written as an inline IIFE/closure in glue code is invisible to tests — a dropped or typo'd key silently degrades behavior. Extract it to a small *pure* named helper (`f(cfg) -> data`) and unit-test the mapping. (#127: the `chat_boundaries` prefix list started as an inline closure in `chat_respond`; the boundary review flagged the untested surface.)
+- Pure-but-IO-adjacent helpers belong in the *pure* module taking the config table as a param, not requiring config — keeps the core testable while quarantining the field-name knowledge in one place.
+- A template placeholder added for one creation path must be rendered through a shared helper before touching call sites. #135 added `{{status}}` to `ISSUE_TEMPLATE` and updated `create_issue`, but `cmd_issue_decompose` still called the template directly; the boundary review caught child issues that would be written with literal `status: {{status}}`. Rule: when a template gains a placeholder, grep every direct template use, extract one renderer, and test the renderer with a non-default/fake value so every creation path proves it uses the same substitution.
+
+## 2026-06-26
+- Any tool that shells out with LLM-controlled inputs must use argv-list execution and typed validation for every field before process launch. Shell-quoting only some fields is not enough: unquoted numeric/count fields can reintroduce command injection even when pattern/path strings are quoted. After hardening one shell-out family, run a sibling-tool sweep for `vim.fn.system(<string>)` and either fold matching tools into scope or file a follow-up immediately.
+
+## 2026-05-30
+- **A "line-bounded" parser's line bound is often a load-bearing blast-radius cap, not just a limitation.** `parse_markers` was line-bounded only because it fed `parse_marker_sections` one line at a time — `find_matching_bracket` itself already scanned across `\n` (drill_in relied on that). So "make it multi-line" was really "stop slicing per-line + add a bound back in." Before removing a bound that looks accidental, ask what it was silently protecting: here, an unmatched `🤖{` could only ruin one line; unbounded it would swallow to EOF. The fix kept the protection as an explicit per-section newline budget (#125).
+- **Extend a shared parser via an optional opts arg that defaults to the historical behavior — then existing callers are provably untouched.** `find_matching_bracket(text, start, open, close, opts)` with `opts.budget`/`opts.is_excluded`; `opts or {}` → `budget == nil` → unbounded, exactly as before. Only the new caller (`parse_markers`) opts in. This sidesteps the lesson-#7 trap (2-arg call sites silently losing a new return) because there's no new *return* and no signature change at the call sites — highlighter and drill_in still pass 3 args. Grep-confirm the call sites anyway.
+- **When a per-iteration budget resets, the per-marker total ≠ the budget.** A reviewer caught that the 50-line ceiling resets at each opening bracket, so a well-formed `🤖<…>[…]{…}` can span ~150 lines even though each *section* is ≤50. The runaway guarantee (a single *stray* opener is bounded) still holds, but the comment/docs claiming "~50 lines per marker" were wrong. Name the unit precisely in comments ("per section") and pin it with a test so nobody "tightens" it into a per-marker cap later.
+
+## 2026-05-07
+- **A parser shared across two semantic layers can hide an ambiguity for months.** The `🤖` marker family was used by two features (review skill / drill-in) with overlapping syntax (`🤖{T}[Q]` vs `🤖{agent}[user]`). The parser couldn't distinguish them, so each caller patched its own "is this drill-in?" heuristic (drill_in: "first section is non-empty `{}`?"). When you spot a caller-side disambiguator like that, a *third syntactic slot* (here: `<>`) is usually cleaner than a smarter heuristic. #123 introduced `<T>` as the unambiguous quoted-body marker; the heuristic disappeared and the whole strip pipeline simplified. Rule: if two callers of the same parser need to read the same parsed shape differently, the grammar is wrong, not the callers.
+- **`find_matching_bracket` only depth-tracks one bracket pair.** When extending a bracket-based grammar with a new pair (`<>`), test cross-pair interactions: `🤖<a [b> c]` parses with quoted = "a [b" because the `>` inside `[]` still closes the `<>`. If that's acceptable, **pin the behavior with a test** so a future "fix" doesn't silently change it. If not, write a parser that maintains a stack across all bracket kinds.
+- **Normalize empty-vs-absent at one boundary.** Parser produced `quoted = { text = "" }` for `🤖<>[U]`. Every downstream consumer (gather/strip/format/resolve) had to choose: treat empty as a real quote or ignore it? Picking *one* normalization site (drill_in.M.parse → `quoted = nil` when empty) lets every caller stay simple. Doing it at the parser level would be wrong (review may want to see the empty `<>` as parser truth); doing it at each consumer is duplicated logic. Drill-in is the *interpretation* layer — that's where the normalization belongs.
+- **Adding a third return value to a shared API is silently lossy at 2-arg call sites.** `_parse_marker_sections` went from `(sections, end_pos)` to `(sections, end_pos, quoted)`. Lua truncates extra returns at assignment sites, so existing callers (`local sections, end_pos = parse(...)`) keep compiling and silently miss the new info. Grep every caller and decide explicitly whether to ignore or consume the new return. Caught the highlighter via grep; missing it would have meant `<T>` spans never highlighted.
+
+## 2026-05-04
+- **Vim ex-commands that take an implicit current-buffer arg (`:undojoin`, `:write`, `:edit`, etc.) silently target the wrong buffer when called from async/scheduled callbacks.** `helpers.undojoin(buf)` accepted a buf param but called `vim.cmd.undojoin` directly — `:undojoin` operates on the current buffer, ignoring the param. The streaming path looked like it worked because users stay focused on the chat buffer during streaming; the longer-cadence spinner timer was more likely to fire during transient focus changes (autocmds, window switches), and its joins silently went to the wrong buffer. Fix: wrap in `vim.api.nvim_buf_call(buf, function() vim.cmd.undojoin() end)`. Rule: any helper that takes a `buf` parameter and dispatches a Vim ex-command must use `nvim_buf_call` — passing the param to the helper without enforcing buffer context is a contract the helper isn't actually upholding. Spotted in #80 second-pass debugging.
+- **Sanitized snapshot in `M.get_agent` (init.lua:3570) is an allow-list, not a passthrough.** Every new field added to the agent config schema must also be appended to this snapshot, or it is silently dropped before `agent_info.resolve` ever sees it. This bit #81 (tools/max_tool_iterations/tool_result_max_bytes) and bit #118 again (synthetic_system_prompt/synthetic_system_prompt_ack) — same vector. Rule: when adding a new agent-config field, grep for `M.get_agent = function` and add it there too; ship a regression test that walks `agent record → get_agent → get_agent_info → final usage` (see `tests/unit/config_tools_spec.lua` "get_agent forwards synthetic_system_prompt config" for the pattern).
+
+## 2026-04-27
+- **`string.gsub` returns 2 values; `table.insert(t, str:gsub(...))` blows up.** Lua expands the last argument of a call to all its return values. So `table.insert(out, "abc":gsub("c","d"))` passes three args (`out`, `"abd"`, `1`) and triggers `bad argument #2 to 'insert' (number expected, got string)` because the 3-arg form expects `(table, pos, value)`. The bug is silent in single-value contexts (`local x = s:gsub(...)`, concat with `..`) but bites the moment you pass the result through a variadic-aware API. Fix: bind to a local first (`local out = s:gsub(...); return out`) or wrap in parens (`return (s:gsub(...))`). Same shape applies to any function returning multiple values that ends a call's argument list.
+
+## 2026-04-11
+- **AGENTS.md overrides skill boilerplate.** The `writing-plans` skill template includes "REQUIRED: Use superpowers:subagent-driven-development" in plan headers. AGENTS.md explicitly says "Do NOT default to skills like `superpowers:subagent-driven-development`." User instructions are highest priority per the skill priority chain. Always check AGENTS.md for conflicts before copying skill boilerplate into artifacts.
+- **In autocmd callbacks, use `nvim_buf_get_name(buf)` not `ev.file`.** `ev.file` can be a relative path when the user opened the file with a relative path (e.g. `nvim workshop/file.md`). `nvim_buf_get_name(buf)` always returns the absolute path. This caused `not_chat()` to fail silently because `find_chat_root` couldn't match the relative path against configured roots.
+- **After `nvim_buf_set_name` + rename, do `write!` then `edit!`.** `nvim_buf_set_name` marks the buffer as a "new file" at the new path. Without `edit!` to reload, the next manual `:w` warns "file already exists". The `write!` forces the initial write, and `edit!` clears the new-file flag.
+
+## 2026-04-10
+- **The exchange_model is the ONLY source of truth for buffer positions.** NEVER compute positions by scanning lines, using foldexpr with backward lookups, or querying `foldlevel()`. The model knows every block's kind, size, start, and end. Any feature that needs positional information (folding, highlighting, insertion, deletion) MUST use the model. This was violated 4 times in one session: foldexpr with backward scan, foldlevel() dependency, `last_content_line()` for prompt append, re-parsing buffer on recursive calls. Every time, the model-based approach was simpler and correct.
+- **Don't commit before user tests.** When fixing a bug that requires manual verification (especially buffer layout, margins, folding), wait for user confirmation before committing. Premature commits require reverts and pollute git history.
+- **Lua empty table `{}` encodes as JSON `[]` (array), not `{}` (object).** Use `vim.empty_dict()` when an empty dict is required (e.g., Anthropic tool_use.input). This bit us when `parse_call` returned empty input for condensed tool blocks.
+- **Parser's `line_start`/`line_end` must not include margins.** Trailing and leading blank lines are margins owned by the model, not block content. The parser must trim them so `from_parsed_chat` computes correct sizes. Also applies to `🧠:`/`📝:` lines — they must be fed to `cb_append_line` so the content_blocks state machine tracks them.
+
+## 2026-04-09
+- Parley test files hardcode `/tmp/parley-*` paths (`dispatcher_spec.lua:7`, `tree_export_spec.lua:22`, etc.). Under Claude Code sandbox, `/tmp` is narrowed to `/tmp/claude` regardless of user `allowWrite` config, so all these tests fail at setup with `Vim:E739: Cannot create directory`. Fix: use `vim.fn.tempname()` or `os.getenv("TMPDIR")` instead of hardcoded `/tmp/` — it's both sandbox-friendly AND more portable. Tracked for future cleanup (not in #81 scope).
+- When adding ONLY new files (no modifications to existing code), regression risk in untouched modules is zero. A full `make test` regression gate is belt-and-suspenders, not load-bearing — individual file verification suffices if you can't run the full suite.
+- **Never have two code paths (legacy + new) coexisting in the same function for the same operation.** #90 attempted to add a model-based insert path alongside the legacy absolute-line path in `chat_respond.M.respond`. The two paths shared closure variables (`response_line`, `progress_line`) and produced conflicting buffer states. THREE rounds of "targeted fix" attempts each made things worse. Rule: if you're replacing an algorithm, REPLACE it — don't add a parallel path gated by a condition. The old path must be deleted, not left as a fallback.
+- **Use SIZE not POSITION for tracking buffer layout.** Absolute line numbers are invalidated by any insert/delete. Size-based models (exchange_model.lua) compute positions on demand from accumulated sizes, so they're always correct regardless of concurrent edits. When building buffer-mutation infrastructure, make the model the single source of truth and have callers ask "where does section K go?" rather than computing offsets themselves.
+- **When adding a new state to code that already has fragile line-offset arithmetic, refactor first — don't stack another branch.** #81 M2 Task 2.7 needed to insert a tool-loop recursion branch into `chat_respond.M.respond`'s imperative line-position chain (`response_line / response_block_lines / progress_line / response_start_line / raw_request_offset`). Each new branch added an `if recursion then +1 else +3` magic-number offset. Three manual test rounds, three distinct offset bugs (progress_line mismatch, stuck-spinner cleanup failure, suspected buffer-state corruption causing an Anthropic "assistant message prefill" rejection on a payload that looked spec-correct). The third bug was the trigger to stop patching and refactor — filed #90 to extract a pure `exchange → lines` + `positions` layer with a single mutation entry point. Rule: when you notice you're adding the Nth `+K vs +M` branch to the same code path, stop and refactor. The cost of one refactor < the cost of N+1 offset patches + the debug sessions between them.
+- **Integration tests at the wiring layer catch bugs unit tests cannot.** During #81 M1 Task 1.8 manual verification, `M.get_agent()` was found to return a sanitized agent snapshot without the `tools`/`max_tool_iterations`/`tool_result_max_bytes` fields. Each hop was unit-tested in isolation (`get_agent_info` with a fake agent table that already had `tools`; `prepare_payload` with an explicit `agent_tools` arg) but no test exercised the full chain `M.agents → get_agent → get_agent_info → prepare_payload`. The bug was caught only by inspecting a real query cache JSON after a real user interaction. Rule: for any multi-hop data flow through module boundaries, write at least one test that exercises the FULL chain with the actual modules wired up, not just mocks at each hop. For any field added to an entity (here: `agent.tools`), grep all the read-sides (functions that build derived objects from the entity) and verify each forwards the field.
+
+## 2026-03-07
+- No escaped-quote init in Makefile recipes — use newline-producing helpers + `for` loops
+- Run new Make targets against real inputs before closing
+
+## 2026-03-08
+- Run `make test-changed` after spec doc changes
+- Verify provider capabilities against provider's own docs
+- Capability rules go in `provider_params.lua`, not transport code
+- Write plan in `tasks/todo.md` before non-trivial work
+- Run `make lint` after every change; warnings = failures
+
+## 2026-03-09
+- Fast-event callbacks: no direct `nvim_*` APIs — use `vim.schedule`
+- Progress UI must handle `reasoning_content` not just tool events
+- Normalize provider progress events to shared shape (`kind`/`phase`/`message`)
+- Propagate raw progress text for display, not just coarse labels
+- `git stash` changing behavior = strong causality signal — diff the stash
+- Prefer semantic header keys (`system_prompt`) over overloaded ones (`role`)
+- Global whitespace trim can eat required terminal newlines — handle post-trim
+- When one path is fixed, narrow focus to remaining failures
+- Bottom-anchored picker: verify `scrolloff` + buffer line count, not just window height
+- Separate initial placement logic from keyboard navigation scrolling
+
+## 2026-03-11
+- UI bugs in live-only: add runtime tracing, don't stop at unit tests
+- Bottom-anchored pickers: verify visual-row vs logical-index mapping
+
+## 2026-03-13
+- ChatFinder move bugs: instrument full lifecycle in live path, not just helpers
+
+## 2026-03-25
+- Read the full existing implementation before adding a variant
+- Always handle `~/` expansion in file path resolution
+- Strip empty-content messages before sending to LLM — Anthropic rejects them
+- Sanitize inputs when extracting reusable functions (strip `cache_control`, etc.)
+- Programmatic buffer inserts don't fire `BufEnter` — trigger renders manually
+- `x or {}` default eats `nil` — use sentinel if nil has meaning
+- Cross-file picker nav: use `edit` not `split`, clamp cursor to line count
+- After `edit`, use `nvim_get_current_buf()` not stale buffer variable
+
+## 2026-03-28
+- Float picker is insert-mode — only `<C-*>` and arrow keys work as actions
+- Don't nil-guard broken state — fix the caller instead
+- Chat file paths must be relative to containing file, not cwd — use `:t` not `:~:.`
+- New keybindings must use config-driven mechanism (`chat_shortcut_*` in config.lua + `M.cmd.*`) — don't copy hardcoded patterns
+
+## 2026-03-29
+- Picker tests: don't assert mappings by numeric index (`mappings[2]`) — indices shift when new mappings are added. Look up by key name instead
+- `GROUPS` is a bash built-in variable (user's group IDs) — never use it as a custom variable name. Same caution for `RANDOM`, `SECONDS`, `LINENO`, etc.
+- `flock` is Linux-only — use `mkdir` for cross-platform locking (atomic on macOS and Linux)
+- `claude -p` in background/piped processes needs `< /dev/null` to avoid stdin timeout warnings
+- `claude -p` without `--permission-mode bypassPermissions` may silently fail when tools need approval but no TTY is available
+- Parallel agents sharing a git working directory: don't use `git status` diff to detect changes from one agent — other concurrent agents may have modified files too
+- `timeout` is GNU coreutils — not on macOS. Use `perl -e 'alarm shift; exec @ARGV'` as portable fallback
+- `wait -n` requires bash 4.3+ — macOS ships bash 3.2. Use `kill -0` polling instead
+- When a subprocess fails silently and its empty stdout is treated as "success", the feature appears to work but does nothing — always check exit codes or validate output isn't vacuous
+
+## 2026-04-06
+- Don't use `git stash` mid-task to "verify lint baseline." Pre-existing stashes in the sandbox can collide with the pop and corrupt unrelated files (Makefile got merge markers, broke `make`). To check whether warnings/errors are pre-existing, run lint on a clean clone in /tmp or just compare the warning *count* against `git show HEAD:<file>` — never disturb the working tree.
+
+## 2026-06-17
+- **When deleting/renaming a module, the atlas-sync merge gate catches stale refs a name-grep misses — reconcile EVERY atlas page, including behavioral descriptors.** Across #128 M2/M3/M4 the `sdlc merge` atlas-sync judge blocked 4× on stale atlas text that survived a `grep <module-name> atlas/`. The misses were *behavior* lines, not the module name: `atlas/modes/review.md` still said "pre/post hooks" / "shared pipeline" / ":checktime reload" after those were deleted, and `traceability.yaml` listed phantom specs (`tools_builtin_glob_spec`) renamed long ago. Rule: when a change deletes/renames a surface, grep `atlas/` for BOTH the old name AND the behaviors/tools it owned (`hooks`, `pipeline`, the old tool name, the reload verb), and walk every mode-specific page + the `## Key Files` / traceability lists — not just the primary atlas doc. Cheaper to sweep up-front than to round-trip the merge gate.
+
+## 2026-06-30 (#116)
+- **A sandbox push/network failure is NOT "can't push" — retry with the sandbox DISABLED.** `git push`/`sdlc pr`/`sdlc merge` failing with `nc: authentication method negotiation failed` (or any SSH/network/auth error) is the Claude Code sandbox blocking the *transport*, not a hard limit. Per the Bash-tool rule, retry the network op with the sandbox off (`dangerouslyDisableSandbox`) — it uses the real network/auth. This session I treated repeated push failures as a hard block and tried to hand the whole merge back to the operator; the moment I retried `git push` unsandboxed it worked, and the full `sdlc pr → merge` flow completed. Don't conclude "can't" from a sandbox network error; the *filesystem* sandbox is narrow (see the `/tmp` lesson) but network is retryable unsandboxed.
+- **Read `sdlc --help` (the workflow contract) UP FRONT — CLAUDE.md says "Read it NOW," and most SDLC surprises come from skipping it.** It lays out the whole arc (claim → `change-code` → implement → `milestone-close` per Mx → `close` → `pr` → `merge`) and the exact gotchas: PUBLISH is **`sdlc pr` → `sdlc merge`** (merge is server-side `gh pr merge` of *origin's* tip, so it needs a pushed branch AND an existing PR), and "a verb's errors are next-action specs" (e.g. `merge` "no upstream" → run `sdlc pr` first). This session I tried `sdlc merge` before `sdlc pr` and was surprised the merge was server-side — all answered in the contract I hadn't read.
+- **`sdlc milestone-close` runs the boundary review; `sdlc close --milestone Mx` does NOT** (it's the documented no-auto-judge escape). For a *reviewed* milestone close, use `milestone-close`. This session I ran `close --milestone` first — it ticked the box + logged but silently skipped the mandatory fresh-context review. (Lives only in `sdlc close --help`, not the top-level contract.)
+- **Merge CODE at issue close, not per milestone — and never reuse a branch name that already has a merged PR.** The normal model (cf. #133's seven milestones on one branch) is one branch per issue, all milestones on it, a single `sdlc pr → merge` at the end; `milestone-close` is a *local* review boundary (+ issue-sync of the tracker to main), NOT a code merge. #116 deviated: M1 shipped early via PR #95 (a prior session, to unblock #128), so when M2/M3 reused the same issue-slug branch name months later, `sdlc merge` found the merged #95 and "resumed post-merge cleanup" (switched to main, deleted the branch) WITHOUT merging the 16 new commits — they were safe on `origin`, absent from main. Rule: don't merge per milestone; if a milestone genuinely must ship early (cross-issue unblock), the continuation needs a FRESH branch name. After any merge, `git rev-list --left-right --count main...origin/<branch>` to confirm main actually advanced.
+
+## 2026-07-01 (#155)
+- **When two code paths feed a shared, tested core, the per-path GLUE still needs its own coverage — a shared-core test does not cover the seam.** #155 consolidated two message emitters into one pure `_emit_content_blocks_as_messages` and I tested it thoroughly (6 direct cases) plus the parse path (1 integration). But `build_messages_from_model` (the live/recursion path) has its own *normalization seam* — buffer read + `serialize.parse_call`/`parse_result` + malformed→text degrade — that I left with **zero** coverage, reasoning "the invariant is tested in the emitter." The close review flagged it Important: a regression in that seam (a dropped/mis-ordered block never reaching the emitter) would ship silently. Rule: after extracting a shared tested core, enumerate every *caller's* normalization/glue seam and give each an end-to-end test through the real entry point (for the live path: build a real buffer + `exchange_model` with positions driven by the model's own `block_start`, call the entry fn, assert the payload). ARCH-PURPOSE covers the core; the seams are separate deliverables.
+- **De-duplicating two parallel implementations surfaces latent divergences — treat each difference as a suspected bug, not noise.** The two emitters diverged on empty tool input: the model path coerced `{}`→`vim.empty_dict()` (JSON `{}`) while the parse path emitted a bare `{}` (JSON `[]`, which Anthropic rejects for `input`). The divergence *was* a latent bug; consolidating to one source fixed it for free. When you unify copy-paste siblings, diff their behavior line-by-line and fix the discrepancy at the single source rather than picking one arbitrarily.
+- **Never `git add -A` / `git add .` in a shared working tree — stage explicit paths.** In #157 `git add -A` swept an unrelated *untracked* user-WIP issue stub (`000158-…`) into my refit commit; the `sdlc merge` instance-conformance gate then blocked on that stub's empty `## Plan`/`## Done when`. The user (and peer agents) leave untracked files in `workshop/issues/` mid-session, so a blanket add captures work that isn't yours. Recovery: `git rm --cached <file>` + a removal commit keeps the file locally (untracked, WIP preserved) while dropping it from the branch's net `base..HEAD` diff so the gate passes. Rule: stage the exact paths you changed (`git add lua/... tests/... workshop/issues/<your-issue>.md`), and before committing run `git status --short` to eyeball for `??` files you didn't create. (Same "commit only my files" care the #155 ariadne-side commit needed.)
+
+## 2026-07-05 (#160)
+- **Run the FULL `make test` (lint + unit + integration) before claiming "suite green" in `--verified` — running specs individually skips the lint gate.** This session I ran each `PlenaryBustedFile` spec directly (all green) and wrote "go test/full suite green" in the close evidence — but never ran `make test`, whose FIRST target is `lint` (luacheck). A new `while pos <= #line do` (every branch returns → luacheck 542 "loop executed at most once") failed luacheck, so `make test` was RED at the gate while my Log claimed green. The boundary review caught it (FIX-THEN-SHIP), but nothing *prevented* the premature claim. Rule: the evidence for "green" is a full `make test` exit 0, not a hand-picked set of specs; individual `PlenaryBustedFile` runs are for the red→green TDD loop, not the final gate. (Bonus: luacheck flags a `while` whose body always returns — use `if` and let the iterator's repeated closure-calls do the looping.)
+- **A decoration-provider highlight's column math deserves a pure, tested helper — don't bury `col_start=s-1, col_end=e-1` inline in an untestable local.** The `push_artifact_refs` extmark columns (off-`iter_refs`' one-past `e`) were an off-by-one-prone conversion inside a `local function` in `highlighter.lua` (ephemeral extmarks, awkward to assert). The review flagged it Important. Fix: extract `artifact_ref.highlight_spans(line)` (pure, returns the exact 0-indexed `{col_start,col_end}`) and unit-test the columns against the literal ref text (`line:sub(col_start+1, col_end) == "ariadne#11"`, incl. the interior-space `#15 M4`); the highlighter consumes it. Pure col math + a direct assertion beats trying to test the decoration provider's redraw output.
+
+## 2026-07-07 (#161)
+- **A pure helper that consumes another module's output must have ONE test against that module's REAL output, not only synthetic inputs.** `define.context_for_selection` reads `parse_chat` fields (`ex.question.line_start`, `ex.answer.line_end`). I unit-tested it thoroughly — but only with a *synthetic* `parsed_chat` table + an injected `finder`, and the one integration test that reached the real `parse_chat` used a buffer with no exchanges (so it hit the whole-buffer fallback, never the sliced-exchange branch). Net: the field-name contract with the live parser had zero coverage — a rename in `parse_chat` would silently degrade define to whole-buffer context with green tests. The boundary review flagged it Important. Rule: injecting a dependency (finder/parser) to keep a helper pure is right, but add exactly one end-to-end case that feeds the helper the REAL producer's output and asserts the field access still works. (Same shape as the #155 "shared core tested, caller's glue seam untested" lesson — the seam here is the field-name contract.)
+- **Raw `nvim_buf_set_text` is arch-forbidden (empty allow-list in `tests/arch/buffer_mutation_spec.lua`); `nvim_buf_set_lines` is allowed in `init.lua`.** #90's buffer-mutation boundary confines span edits to `buffer_edit.lua` (set_text allow-list is `{}` = zero uses). My first R1 cut used `nvim_buf_set_text` for the `[term]` wrap → `make test` red on the arch spec (lint was clean, so I only caught it at the full-suite run, not the unit loop). Fix: wrap via `nvim_buf_set_lines` (rewrite the affected whole line(s)) — the same primitive `drill_in_visual` already uses to wrap a selection, and it's on the set_lines allow-list for `init.lua`. Rule: before reaching for `nvim_buf_set_text`/`set_lines` in a non-`buffer_edit` file, check `tests/arch/buffer_mutation_spec.lua` — prefer the set_lines whole-line rewrite that existing wrappers use.
+- **To make a decoration-only action undoable, anchor it to a text edit + reuse `projection` — `u` reverts text, never extmarks/diagnostics.** The operator wanted the define highlight+diagnostic undoable; native `u` can't touch pure decorations (review's are undoable only because a round edits text). Resolution: a minimal text edit (now the durable `[^id]` footnote reference/footer) as the anchor + reuse `skills/review/projection.lua` (`record_empty_for(pre)` + `record(post)` + `ensure_watch`). `skill_render.snapshot`/`apply_snapshot` now preserve both whole-line highlights and column spans, so the projection can restore exact term/reference decorations. In headless tests, `:undo` does NOT fire `TextChanged` — `nvim_exec_autocmds("TextChanged", {buffer=buf})` to drive the projection watcher deterministically.
+
+## 2026-07-08 (#166)
+- **Any action that can be repeated on its own output needs an idempotence test, not only an update test for the secondary data.** #166 tested that re-defining a term updated the managed footnote line, but the selected text transform still blindly appended `[^id]`, so selecting `ASIN` in `ASIN[^asin]` produced `ASIN[^asin][^asin]`. The close review caught the gap. Rule: when a feature creates both an inline reference and an external/durable record, add a repeat-on-rendered-output test that proves the inline reference is not duplicated while the external record updates.
+
+## 2026-07-08 (#167)
+- **A behavior-only fix can still require atlas if an atlas page explicitly describes that behavior.** #167 changed define highlights from whole-line to span-scoped and taught projection snapshots to preserve columns; the code and tests were right, but `atlas/chat/inline_define.md` still said whole-line/line-granular. Rule: before using `--no-atlas`, grep atlas for the feature name and the old behavior terms (`whole-line`, `line-granular`, helper names, key data fields). If any atlas page states the old behavior, update it in the same commit even when no new module or command was added.
+
+## 2026-07-08 (#169)
+- **When centralizing a policy, delete caller-local defaults that can bypass it.** #169 routed review and define diagnostics through `skill_render.format_diagnostic_message`, but `define.format_definition` still passed `width or 80`, preserving an old fallback and weakening the shared width policy. Rule: after adding a shared formatter/config helper, grep every caller for old fallback constants and add a test for the nil/default path so future callers inherit the central behavior.
+
+codex
+Using `sdlc` for the boundary-review workflow and the code-review stance from the user prompt. I’ve read the workflow contract and am now checking the issue/plan against the live diff and tests.
+exec
+/bin/zsh -lc "sed -n '1,220p' /Users/xianxu/workspace/ariadne/construct/local/sdlc/SKILL.md" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+---
+name: sdlc
+description: Use when at an SDLC checkpoint — starting work, closing an issue or milestone, opening/merging a PR, or recovering workflow state after compaction. The `sdlc` binary owns the gates between workflow stages and refuses transitions that lack required evidence.
+---
+
+# sdlc — SDLC checkpoint binary
+
+`sdlc` owns the gates between SDLC workflow stages (claim → change-code → pr →
+merge, plus close, milestone-close, judge). It requires evidence at each gate,
+mutates state, logs the transition, and refuses transitions that lack the
+evidence — that is the shape of a "checkpoint guard."
+
+The binary is the single source of truth. This skill is a static pointer and
+intentionally carries no copy of the contract, so it can never drift:
+
+- **`sdlc --help`** — the workflow contract: the start-of-work runbook,
+  conventions, and the verb list.
+- **`sdlc <verb> --help`** — one checkpoint's full contract, flags, and examples.
+
+Read those instead of relying on memory; the binary's help is always current.
+
+exec
+/bin/zsh -lc "sed -n '1,240p' workshop/issues/000173-diagnostic-virtual-lines-leftcol.md" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+---
+id: 000173
+status: working
+deps: []
+github_issue:
+created: 2026-07-08
+updated: 2026-07-08
+estimate_hours: 0.38
+started: 2026-07-08T13:21:02-07:00
+---
+
+# diagnostic virtual lines blank on long wrapped markdown
+
+## Problem
+
+After #172, managed markdown footnotes are correctly restored as diagnostics,
+but their inline virtual-line display can look blank on long wrapped markdown
+paragraphs. The diagnostic payload is present and floats display it, but
+Neovim's built-in `virtual_lines` handler prefixes the rendered message with
+spaces equal to the diagnostic byte column. On a long prose line, the selected
+text may be visible on a wrapped screen row while the virtual-line message starts
+far to the right outside the viewport.
+
+## Spec
+
+- Parley diagnostics should remain anchored on the selected text / `[^footnote]`
+  span so signs, underline, cursor-line filtering, jumps, and floats keep their
+  existing behavior.
+- The inline diagnostic display for Parley's namespace should render current-line
+  messages from the left column, not from the diagnostic byte column.
+- The display text should keep the existing wrapped diagnostic message and a
+  clear `Diagnostics:` label.
+- The fix should apply to the shared Parley diagnostic namespace, covering review
+  diagnostics and footnote diagnostics without changing global/LSP diagnostics.
+
+ARCH-DRY: keep one Parley diagnostic display controller in
+`skills/review/diag_display.lua`; do not add a separate footnote-only renderer.
+ARCH-PURE: no parser/data changes; keep the change in the thin Neovim display
+shell and test its extmark output directly.
+ARCH-PURPOSE: solve the actual blank-row symptom for long wrapped markdown, not
+only color the hidden text.
+
+## Done when
+
+- A Parley diagnostic on a long line with a high column renders a visible
+  left-column virtual line.
+- The diagnostic itself remains at its original span for underline/float/jump
+  behavior.
+- Toggling `:ParleyShowDiagnostics` still disables/enables the inline display.
+- Focused tests and full verification pass.
+
+## Estimate
+
+Produced via `estimate-logic-v3.1` against the repo-local calibration source
+reported by `sdlc estimate-source` (stale but canonical for this repo).
+
+```estimate
+model: estimate-logic-v3.1
+familiarity: 1.0
+item: issue-spec design=0.04 impl=0.00
+item: lua-neovim design=0.06 impl=0.18
+item: milestone-review design=0.00 impl=0.10
+total: 0.38
+```
+
+## Plan
+
+- [x] Add failing tests proving Parley virtual lines render from the left column.
+- [x] Implement the Parley-owned virtual-line display handler.
+- [x] Update atlas/issue log and run verification.
+
+## Log
+
+### 2026-07-08
+- Root cause: a headless reproduction of Neovim's stock diagnostic virtual-lines
+  handler showed `virt_lines = { { { string.rep(" ", diagnostic.col), "" }, ... } }`
+  with `virt_lines_overflow = "scroll"`, so long wrapped markdown can display a
+  blank inserted row while the message starts outside the viewport.
+- Red test: `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"`
+  failed because `diag_display` still configured stock `virtual_lines` and no
+  `parley_diagnostic_virtual_lines` extmark was rendered.
+- Implemented `parley/virtual_lines`, a custom diagnostic handler scoped to the
+  Parley namespace. It renders a left-column `Diagnostics:` virtual-line block,
+  updates on `CursorMoved`, disables stock virtual lines for Parley, and leaves
+  the underlying diagnostic span unchanged.
+- Focused green: `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"`.
+- Final green: `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`;
+  `git diff --check -- lua/parley/skills/review/diag_display.lua
+  tests/integration/review_diag_display_spec.lua atlas/modes/review.md
+  atlas/chat/inline_define.md
+  workshop/issues/000173-diagnostic-virtual-lines-leftcol.md
+  workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md`; `make test`.
+
+exec
+/bin/zsh -lc "sed -n '1,220p' workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+# Diagnostic Virtual Lines Left Column Implementation Plan
+
+> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.
+
+**Goal:** Make Parley's inline diagnostic display visible on long wrapped markdown lines by rendering diagnostic virtual lines from the left column.
+
+**Architecture:** Keep diagnostic data unchanged: spans stay anchored to selected text and footnote references. Replace only Parley's namespace display shell in `diag_display.lua`, so global/LSP diagnostics still use Neovim defaults. This follows ARCH-DRY by keeping one Parley display controller and ARCH-PURE by avoiding parser/data changes.
+
+**Tech Stack:** Lua, Neovim diagnostics, extmarks, Plenary/Busted tests.
+
+---
+
+## Core Concepts
+
+### Pure Entities
+
+| Name | Lives in | Status |
+|------|----------|--------|
+| `ParleyDiagnosticMessageLines` | `lua/parley/skills/review/diag_display.lua` | new |
+
+- **ParleyDiagnosticMessageLines** — deterministic conversion from a diagnostic message string into visible virtual-line rows with a `Diagnostics:` header.
+  - **Relationships:** 1:N from one diagnostic message to display rows.
+  - **DRY rationale:** Both review diagnostics and footnote diagnostics consume the same Parley namespace display.
+  - **Future extensions:** If Parley later adds source-specific labels, this formatter is the one place to widen.
+
+### Integration Points
+
+| Name | Lives in | Status | Wraps |
+|------|----------|--------|-------|
+| `ParleyDiagnosticVirtualLines` | `lua/parley/skills/review/diag_display.lua` | modified | Neovim extmarks |
+
+- **ParleyDiagnosticVirtualLines** — Parley-owned inline diagnostic renderer scoped to `skill_render.diag_namespace()`.
+  - **Injected into:** `diag_display.set(on)`; toggling still owns all inline display setup.
+  - **Future extensions:** Can add color overrides without changing diagnostic producers.
+
+## Chunk 1: Left-Column Renderer
+
+**Files:**
+- Modify: `lua/parley/skills/review/diag_display.lua`
+- Modify: `tests/integration/review_diag_display_spec.lua`
+- Modify: `atlas/modes/review.md`
+- Modify: `atlas/chat/inline_define.md`
+- Modify: `workshop/issues/000173-diagnostic-virtual-lines-leftcol.md`
+
+- [x] **Step 1: Write failing tests**
+
+Add integration coverage that:
+- Sets a Parley diagnostic at a high column on a long line.
+- Enables `diag_display`.
+- Asserts the generated display extmark has `virt_lines_leftcol = true`.
+- Asserts the first virtual-line chunk is `Diagnostics:` instead of leading spaces.
+- Asserts `dd.set(false)` clears the Parley display extmark while leaving the diagnostic data intact.
+
+Run:
+
+```bash
+nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"
+```
+
+Expected: FAIL because the stock diagnostic handler emits leading-space virtual lines and `diag_display` has no custom extmark namespace.
+
+- [x] **Step 2: Implement the renderer**
+
+In `lua/parley/skills/review/diag_display.lua`:
+- Add a private display namespace.
+- Add a private function that clears Parley diagnostic virtual-line extmarks.
+- Add a private render function that reads diagnostics from `skill_render.diag_namespace()`, filters to the current cursor line, and writes `virt_lines` with `virt_lines_leftcol = true`.
+- Configure Neovim diagnostics for the Parley namespace with `virtual_lines = false`, `virtual_text = false`, and existing signs/underline behavior.
+- Register a buffer-local `CursorMoved` autocmd for visible Parley buffers so current-line behavior keeps updating.
+
+- [x] **Step 3: Run green focused tests**
+
+Run:
+
+```bash
+nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"
+```
+
+Expected: PASS.
+
+- [x] **Step 4: Update docs and issue log**
+
+Update atlas text that says Parley uses built-in diagnostic `virtual_lines` so it instead describes the Parley-owned left-column inline renderer. Record red/green evidence in the issue log and tick plan items.
+
+- [x] **Step 5: Final verification**
+
+Run:
+
+```bash
+git diff --check -- lua/parley/skills/review/diag_display.lua tests/integration/review_diag_display_spec.lua atlas/modes/review.md atlas/chat/inline_define.md workshop/issues/000173-diagnostic-virtual-lines-leftcol.md workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md
+make test
+```
+
+Expected: all pass.
+
+exec
+/bin/zsh -lc 'git diff --stat b9094e9bfc89b0f27013c6fd41c38a83b8b61510..HEAD && git diff --name-only b9094e9bfc89b0f27013c6fd41c38a83b8b61510..HEAD' in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+ atlas/chat/inline_define.md                        |  26 ++--
+ atlas/modes/review.md                              |  16 ++-
+ lua/parley/skills/review/diag_display.lua          | 132 ++++++++++++++++++++-
+ tests/integration/review_diag_display_spec.lua     |  61 +++++++++-
+ .../000173-diagnostic-virtual-lines-leftcol.md     |  70 ++++++++++-
+ ...000173-diagnostic-virtual-lines-leftcol-plan.md |  94 +++++++++++++++
+ 6 files changed, 373 insertions(+), 26 deletions(-)
+atlas/chat/inline_define.md
+atlas/modes/review.md
+lua/parley/skills/review/diag_display.lua
+tests/integration/review_diag_display_spec.lua
+workshop/issues/000173-diagnostic-virtual-lines-leftcol.md
+workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md
+
+exec
+/bin/zsh -lc 'git diff --check b9094e9bfc89b0f27013c6fd41c38a83b8b61510..HEAD' in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+codex
+The tracker and plan align at a high level: one display-shell change, tests, and atlas updates. I’m reading the implementation now for Neovim handler semantics and edge cases like buffer focus, cursor movement, and config toggling.
+exec
+/bin/zsh -lc "nl -ba lua/parley/skills/review/diag_display.lua | sed -n '1,240p'" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+     1    -- diag_display.lua — inline display of review "why" diagnostics (#133 M6).
+     2    --
+     3    -- Controls how parley's review explanations render, scoped to parley's OWN
+     4    -- diagnostic namespace (never touches the user's LSP / global diagnostics).
+     5    -- Default ON: `virtual_lines { current_line = true }`, so the (hard-wrapped) why
+     6    -- auto-expands below an edit when the cursor is in that edit's region, and hides
+     7    -- otherwise. `:ParleyShowDiagnostics` toggles it.
+     8
+     9    local M = {}
+    10
+    11    M.enabled = true -- default on (cursor-region auto-show)
+    12
+    13    local HANDLER_NAME = "parley/virtual_lines"
+    14    local DISPLAY_NS = "parley_diagnostic_virtual_lines"
+    15    local DISPLAY_AUGROUP = "parley_diagnostic_virtual_lines"
+    16    local HEADER_HL = "ParleyDiagnosticVirtualLineHeader"
+    17    local MESSAGE_HL = "ParleyDiagnosticVirtualLine"
+    18
+    19    local display_ns_id
+    20    local display_augroup
+    21
+    22    -- Parley's review diagnostic namespace — single-sourced from skill_render (which
+    23    -- owns the namespace) so the identity isn't a duplicated literal (#133 M6 review).
+    24    local function ns()
+    25        return require("parley.skill_render").diag_namespace()
+    26    end
+    27
+    28    local function ensure_display()
+    29        if not display_ns_id then
+    30            display_ns_id = vim.api.nvim_create_namespace(DISPLAY_NS)
+    31        end
+    32        if not display_augroup then
+    33            display_augroup = vim.api.nvim_create_augroup(DISPLAY_AUGROUP, { clear = true })
+    34        end
+    35        vim.api.nvim_set_hl(0, HEADER_HL, { link = "DiagnosticInfo" })
+    36        vim.api.nvim_set_hl(0, MESSAGE_HL, { link = "DiagnosticFloatingInfo" })
+    37    end
+    38
+    39    local function clear(buf)
+    40        ensure_display()
+    41        if vim.api.nvim_buf_is_valid(buf) then
+    42            vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
+    43            pcall(vim.api.nvim_clear_autocmds, { group = display_augroup, buffer = buf })
+    44        end
+    45    end
+    46
+    47    local function current_line_for(buf)
+    48        if vim.api.nvim_get_current_buf() ~= buf then
+    49            return nil
+    50        end
+    51        return vim.api.nvim_win_get_cursor(0)[1] - 1
+    52    end
+    53
+    54    local function diagnostic_message_lines(diagnostic)
+    55        local lines = {}
+    56        for _, line in ipairs(vim.split(tostring(diagnostic.message or ""), "\n", { plain = true })) do
+    57            table.insert(lines, { { line ~= "" and line or " ", MESSAGE_HL } })
+    58        end
+    59        if #lines == 0 then
+    60            table.insert(lines, { { " ", MESSAGE_HL } })
+    61        end
+    62        return lines
+    63    end
+    64
+    65    local function render(buf, diagnostics, current_line_only)
+    66        ensure_display()
+    67        if not vim.api.nvim_buf_is_valid(buf) then
+    68            return
+    69        end
+    70        vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
+    71
+    72        local line = current_line_only and current_line_for(buf) or nil
+    73        if current_line_only and not line then
+    74            return
+    75        end
+    76
+    77        local by_line = {}
+    78        for _, diagnostic in ipairs(diagnostics or {}) do
+    79            if not current_line_only or diagnostic.lnum == line then
+    80                by_line[diagnostic.lnum] = by_line[diagnostic.lnum] or {}
+    81                table.insert(by_line[diagnostic.lnum], diagnostic)
+    82            end
+    83        end
+    84
+    85        for lnum, line_diagnostics in pairs(by_line) do
+    86            table.sort(line_diagnostics, function(a, b)
+    87                return (a.col or 0) < (b.col or 0)
+    88            end)
+    89            local virt_lines = { { { "Diagnostics:", HEADER_HL } } }
+    90            for _, diagnostic in ipairs(line_diagnostics) do
+    91                vim.list_extend(virt_lines, diagnostic_message_lines(diagnostic))
+    92            end
+    93            vim.api.nvim_buf_set_extmark(buf, display_ns_id, lnum, 0, {
+    94                virt_lines = virt_lines,
+    95                virt_lines_leftcol = true,
+    96                virt_lines_above = false,
+    97            })
+    98        end
+    99    end
+   100
+   101    local function register_handler()
+   102        ensure_display()
+   103        vim.diagnostic.handlers[HANDLER_NAME] = {
+   104            show = function(namespace, bufnr, diagnostics, opts)
+   105                if namespace ~= ns() then
+   106                    return
+   107                end
+   108                bufnr = vim._resolve_bufnr(bufnr)
+   109                local handler_opts = opts and opts[HANDLER_NAME] or {}
+   110                local current_line_only = handler_opts.current_line == true
+   111                clear(bufnr)
+   112                if current_line_only then
+   113                    vim.api.nvim_create_autocmd("CursorMoved", {
+   114                        buffer = bufnr,
+   115                        group = display_augroup,
+   116                        callback = function()
+   117                            render(bufnr, diagnostics, true)
+   118                        end,
+   119                    })
+   120                end
+   121                render(bufnr, diagnostics, current_line_only)
+   122            end,
+   123            hide = function(namespace, bufnr)
+   124                if namespace ~= ns() then
+   125                    return
+   126                end
+   127                clear(vim._resolve_bufnr(bufnr))
+   128            end,
+   129        }
+   130    end
+   131
+   132    function M.refresh(buf)
+   133        if not M.enabled then
+   134            return
+   135        end
+   136        buf = buf or vim.api.nvim_get_current_buf()
+   137        render(buf, vim.diagnostic.get(buf, { namespace = ns() }), true)
+   138    end
+   139
+   140    --- Apply the inline-display config for parley's review namespace.
+   141    --- @param on boolean
+   142    function M.set(on)
+   143        M.enabled = on and true or false
+   144        register_handler()
+   145        vim.diagnostic.config({
+   146            [HANDLER_NAME] = M.enabled and { current_line = true } or false,
+   147            virtual_lines = false,
+   148            virtual_text = false,
+   149        }, ns())
+   150        if M.enabled then
+   151            M.refresh()
+   152        else
+   153            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
+   154                clear(buf)
+   155            end
+   156        end
+   157    end
+   158
+   159    --- Toggle inline display; returns the new state.
+   160    --- @return boolean
+   161    function M.toggle()
+   162        M.set(not M.enabled)
+   163        return M.enabled
+   164    end
+   165
+   166    --- Is inline display currently enabled?
+   167    --- @return boolean
+   168    function M.is_enabled()
+   169        return M.enabled
+   170    end
+   171
+   172    return M
+
+exec
+/bin/zsh -lc "nl -ba tests/integration/review_diag_display_spec.lua | sed -n '1,180p'" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+     1    -- Integration tests for the review-diagnostic inline display toggle (#133 M6).
+     2
+     3    local dd = require("parley.skills.review.diag_display")
+     4
+     5    local function ns_cfg()
+     6        return vim.diagnostic.config(nil, require("parley.skill_render").diag_namespace())
+     7    end
+     8
+     9    local function display_marks(buf)
+    10        local display_ns = vim.api.nvim_create_namespace("parley_diagnostic_virtual_lines")
+    11        return vim.api.nvim_buf_get_extmarks(buf, display_ns, 0, -1, { details = true })
+    12    end
+    13
+    14    describe("review.diag_display", function()
+    15        after_each(function()
+    16            dd.set(true) -- restore default for other specs
+    17            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
+    18                if vim.api.nvim_buf_is_valid(buf) then
+    19                    pcall(vim.diagnostic.reset, require("parley.skill_render").diag_namespace(), buf)
+    20                end
+    21            end
+    22        end)
+    23
+    24        it("toggles the enabled state", function()
+    25            dd.set(true)
+    26            assert.is_true(dd.is_enabled())
+    27            assert.is_false(dd.toggle())
+    28            assert.is_false(dd.is_enabled())
+    29            assert.is_true(dd.toggle())
+    30            assert.is_true(dd.is_enabled())
+    31        end)
+    32
+    33        it("configures Parley's custom current-line display on its namespace when on; off when disabled", function()
+    34            dd.set(true)
+    35            local on = ns_cfg()
+    36            assert.is_false(on.virtual_lines) -- Parley owns its virtual-lines renderer.
+    37            assert.is_truthy(on["parley/virtual_lines"])
+    38            assert.is_false(on.virtual_text) -- inline single-line is never used
+    39            dd.set(false)
+    40            assert.is_false(ns_cfg()["parley/virtual_lines"])
+    41        end)
+    42
+    43        it("renders current-line diagnostics from the left column without moving the diagnostic span", function()
+    44            local skill_render = require("parley.skill_render")
+    45            local diag_ns = skill_render.diag_namespace()
+    46            local buf = vim.api.nvim_create_buf(false, true)
+    47            vim.api.nvim_set_current_buf(buf)
+    48            vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
+    49                string.rep("x", 120) .. " ACOS[^acos]",
+    50            })
+    51
+    52            dd.set(true)
+    53            vim.diagnostic.set(diag_ns, buf, { {
+    54                lnum = 0,
+    55                col = 121,
+    56                end_lnum = 0,
+    57                end_col = 132,
+    58                message = "ACOS — Advertising Cost of Sales.",
+    59                severity = vim.diagnostic.severity.INFO,
+    60                source = "parley-footnote",
+    61            } })
+    62
+    63            vim.wait(100, function()
+    64                return #display_marks(buf) == 1
+    65            end)
+    66
+    67            local marks = display_marks(buf)
+    68            assert.are.equal(1, #marks)
+    69            local details = marks[1][4]
+    70            assert.is_true(details.virt_lines_leftcol)
+    71            assert.are.equal("Diagnostics:", details.virt_lines[1][1][1])
+    72            assert.are_not.equal(string.rep(" ", 121), details.virt_lines[1][1][1])
+    73            assert.are.equal("ACOS — Advertising Cost of Sales.", details.virt_lines[2][1][1])
+    74
+    75            local diagnostics = vim.diagnostic.get(buf, { namespace = diag_ns })
+    76            assert.are.equal(1, #diagnostics)
+    77            assert.are.equal(0, diagnostics[1].lnum)
+    78            assert.are.equal(121, diagnostics[1].col)
+    79            assert.are.equal(0, diagnostics[1].end_lnum)
+    80            assert.are.equal(132, diagnostics[1].end_col)
+    81
+    82            dd.set(false)
+    83            assert.are.equal(0, #display_marks(buf))
+    84            assert.are.equal(1, #vim.diagnostic.get(buf, { namespace = diag_ns }))
+    85        end)
+    86    end)
+
+exec
+/bin/zsh -lc "rg -n \"diag_display|ParleyShowDiagnostics|virtual_lines|parley/virtual_lines|refresh\\(\" lua tests atlas README.md" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+atlas/chat/inline_define.md:44:   `diag_display`'s Parley-owned left-column virtual-line display reveals the
+atlas/chat/inline_define.md:149:- [Document Review](../modes/review.md) — the skill/`skill_invoke`/`diag_display`
+lua/parley/skills/review/diag_display.lua:1:-- diag_display.lua — inline display of review "why" diagnostics (#133 M6).
+lua/parley/skills/review/diag_display.lua:5:-- Default ON: `virtual_lines { current_line = true }`, so the (hard-wrapped) why
+lua/parley/skills/review/diag_display.lua:7:-- otherwise. `:ParleyShowDiagnostics` toggles it.
+lua/parley/skills/review/diag_display.lua:13:local HANDLER_NAME = "parley/virtual_lines"
+lua/parley/skills/review/diag_display.lua:14:local DISPLAY_NS = "parley_diagnostic_virtual_lines"
+lua/parley/skills/review/diag_display.lua:15:local DISPLAY_AUGROUP = "parley_diagnostic_virtual_lines"
+lua/parley/skills/review/diag_display.lua:132:function M.refresh(buf)
+lua/parley/skills/review/diag_display.lua:147:        virtual_lines = false,
+lua/parley/skills/review/diag_display.lua:151:        M.refresh()
+atlas/modes/review.md:163:`parley_skill` namespace. `lua/parley/skills/review/diag_display.lua` controls how
+atlas/modes/review.md:165:untouched. Default **on**: Parley's custom `parley/virtual_lines` diagnostic
+atlas/modes/review.md:171:`lnum..end_lnum`) and hides otherwise. `:ParleyShowDiagnostics` toggles it. The
+atlas/modes/review.md:209:- `lua/parley/skills/review/diag_display.lua` — inline "why" display toggle (`:ParleyShowDiagnostics`, cursor-region auto-show) (#133 M6)
+tests/integration/highlighting_spec.lua:445:        assert.same({ current_line = true }, diag_config.virtual_lines)
+tests/integration/review_diag_display_spec.lua:3:local dd = require("parley.skills.review.diag_display")
+tests/integration/review_diag_display_spec.lua:10:    local display_ns = vim.api.nvim_create_namespace("parley_diagnostic_virtual_lines")
+tests/integration/review_diag_display_spec.lua:14:describe("review.diag_display", function()
+tests/integration/review_diag_display_spec.lua:36:        assert.is_false(on.virtual_lines) -- Parley owns its virtual-lines renderer.
+tests/integration/review_diag_display_spec.lua:37:        assert.is_truthy(on["parley/virtual_lines"])
+tests/integration/review_diag_display_spec.lua:40:        assert.is_false(ns_cfg()["parley/virtual_lines"])
+lua/parley/init.lua:770:    -- :ParleyShowDiagnostics — toggle inline display of review "why" diagnostics
+lua/parley/init.lua:773:        local on = require("parley.skills.review.diag_display").toggle()
+lua/parley/init.lua:776:    require("parley.skills.review.diag_display").set(true)
+lua/parley/init.lua:976:        pcall(function() require("lualine").refresh() end)
+lua/parley/init.lua:991:        pcall(function() require("lualine").refresh() end)
+lua/parley/init.lua:1655:    -- Park the cursor on the term's line so diag_display's current-line
+lua/parley/init.lua:1656:    -- virtual_lines reveals the definition immediately.
+lua/parley/lualine.lua:29:      require("lualine").refresh()
+lua/parley/lualine.lua:477:            require("lualine").refresh()
+lua/parley/lualine.lua:488:            require("lualine").refresh()
+lua/parley/lualine.lua:499:            require("lualine").refresh()
+lua/parley/timezone_diagnostics.lua:14:            virtual_lines = { current_line = true },
+lua/parley/skill_render.lua:39:--- (diag_display) target, so the namespace identity isn't duplicated as a literal
+lua/parley/skill_render.lua:47:--- existing newlines. PURE. Lets `virtual_lines` render a long "why" as multiple
+lua/parley/skill_render.lua:77:-- Usable wrap width for the virtual_lines "why": the window's text columns
+lua/parley/skill_render.lua:80:-- fixed 76 overflowed the indented virtual_lines and truncated the right edge
+lua/parley/skill_render.lua:98:--- Format a diagnostic message for Neovim virtual_lines display.
+lua/parley/skill_render.lua:150:--- message is hard-wrapped to the window's usable width for `virtual_lines`
+lua/parley/interview.lua:158:                    require("lualine").refresh()
+lua/parley/interview.lua:204:                require("lualine").refresh()
+lua/parley/interview.lua:231:        require("lualine").refresh()
+lua/parley/interview.lua:250:        require("lualine").refresh()
+
+exec
+/bin/zsh -lc 'git diff --unified=80 b9094e9bfc89b0f27013c6fd41c38a83b8b61510..HEAD -- lua/parley/skills/review/diag_display.lua tests/integration/review_diag_display_spec.lua' in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+diff --git a/lua/parley/skills/review/diag_display.lua b/lua/parley/skills/review/diag_display.lua
+index 4617a35..6fd4da6 100644
+--- a/lua/parley/skills/review/diag_display.lua
++++ b/lua/parley/skills/review/diag_display.lua
+@@ -1,42 +1,172 @@
+ -- diag_display.lua — inline display of review "why" diagnostics (#133 M6).
+ --
+ -- Controls how parley's review explanations render, scoped to parley's OWN
+ -- diagnostic namespace (never touches the user's LSP / global diagnostics).
+ -- Default ON: `virtual_lines { current_line = true }`, so the (hard-wrapped) why
+ -- auto-expands below an edit when the cursor is in that edit's region, and hides
+ -- otherwise. `:ParleyShowDiagnostics` toggles it.
+
+ local M = {}
+
+ M.enabled = true -- default on (cursor-region auto-show)
+
++local HANDLER_NAME = "parley/virtual_lines"
++local DISPLAY_NS = "parley_diagnostic_virtual_lines"
++local DISPLAY_AUGROUP = "parley_diagnostic_virtual_lines"
++local HEADER_HL = "ParleyDiagnosticVirtualLineHeader"
++local MESSAGE_HL = "ParleyDiagnosticVirtualLine"
++
++local display_ns_id
++local display_augroup
++
+ -- Parley's review diagnostic namespace — single-sourced from skill_render (which
+ -- owns the namespace) so the identity isn't a duplicated literal (#133 M6 review).
+ local function ns()
+     return require("parley.skill_render").diag_namespace()
+ end
+
++local function ensure_display()
++    if not display_ns_id then
++        display_ns_id = vim.api.nvim_create_namespace(DISPLAY_NS)
++    end
++    if not display_augroup then
++        display_augroup = vim.api.nvim_create_augroup(DISPLAY_AUGROUP, { clear = true })
++    end
++    vim.api.nvim_set_hl(0, HEADER_HL, { link = "DiagnosticInfo" })
++    vim.api.nvim_set_hl(0, MESSAGE_HL, { link = "DiagnosticFloatingInfo" })
++end
++
++local function clear(buf)
++    ensure_display()
++    if vim.api.nvim_buf_is_valid(buf) then
++        vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
++        pcall(vim.api.nvim_clear_autocmds, { group = display_augroup, buffer = buf })
++    end
++end
++
++local function current_line_for(buf)
++    if vim.api.nvim_get_current_buf() ~= buf then
++        return nil
++    end
++    return vim.api.nvim_win_get_cursor(0)[1] - 1
++end
++
++local function diagnostic_message_lines(diagnostic)
++    local lines = {}
++    for _, line in ipairs(vim.split(tostring(diagnostic.message or ""), "\n", { plain = true })) do
++        table.insert(lines, { { line ~= "" and line or " ", MESSAGE_HL } })
++    end
++    if #lines == 0 then
++        table.insert(lines, { { " ", MESSAGE_HL } })
++    end
++    return lines
++end
++
++local function render(buf, diagnostics, current_line_only)
++    ensure_display()
++    if not vim.api.nvim_buf_is_valid(buf) then
++        return
++    end
++    vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
++
++    local line = current_line_only and current_line_for(buf) or nil
++    if current_line_only and not line then
++        return
++    end
++
++    local by_line = {}
++    for _, diagnostic in ipairs(diagnostics or {}) do
++        if not current_line_only or diagnostic.lnum == line then
++            by_line[diagnostic.lnum] = by_line[diagnostic.lnum] or {}
++            table.insert(by_line[diagnostic.lnum], diagnostic)
++        end
++    end
++
++    for lnum, line_diagnostics in pairs(by_line) do
++        table.sort(line_diagnostics, function(a, b)
++            return (a.col or 0) < (b.col or 0)
++        end)
++        local virt_lines = { { { "Diagnostics:", HEADER_HL } } }
++        for _, diagnostic in ipairs(line_diagnostics) do
++            vim.list_extend(virt_lines, diagnostic_message_lines(diagnostic))
++        end
++        vim.api.nvim_buf_set_extmark(buf, display_ns_id, lnum, 0, {
++            virt_lines = virt_lines,
++            virt_lines_leftcol = true,
++            virt_lines_above = false,
++        })
++    end
++end
++
++local function register_handler()
++    ensure_display()
++    vim.diagnostic.handlers[HANDLER_NAME] = {
++        show = function(namespace, bufnr, diagnostics, opts)
++            if namespace ~= ns() then
++                return
++            end
++            bufnr = vim._resolve_bufnr(bufnr)
++            local handler_opts = opts and opts[HANDLER_NAME] or {}
++            local current_line_only = handler_opts.current_line == true
++            clear(bufnr)
++            if current_line_only then
++                vim.api.nvim_create_autocmd("CursorMoved", {
++                    buffer = bufnr,
++                    group = display_augroup,
++                    callback = function()
++                        render(bufnr, diagnostics, true)
++                    end,
++                })
++            end
++            render(bufnr, diagnostics, current_line_only)
++        end,
++        hide = function(namespace, bufnr)
++            if namespace ~= ns() then
++                return
++            end
++            clear(vim._resolve_bufnr(bufnr))
++        end,
++    }
++end
++
++function M.refresh(buf)
++    if not M.enabled then
++        return
++    end
++    buf = buf or vim.api.nvim_get_current_buf()
++    render(buf, vim.diagnostic.get(buf, { namespace = ns() }), true)
++end
++
+ --- Apply the inline-display config for parley's review namespace.
+ --- @param on boolean
+ function M.set(on)
+     M.enabled = on and true or false
++    register_handler()
+     vim.diagnostic.config({
+-        virtual_lines = M.enabled and { current_line = true } or false,
++        [HANDLER_NAME] = M.enabled and { current_line = true } or false,
++        virtual_lines = false,
+         virtual_text = false,
+     }, ns())
++    if M.enabled then
++        M.refresh()
++    else
++        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
++            clear(buf)
++        end
++    end
+ end
+
+ --- Toggle inline display; returns the new state.
+ --- @return boolean
+ function M.toggle()
+     M.set(not M.enabled)
+     return M.enabled
+ end
+
+ --- Is inline display currently enabled?
+ --- @return boolean
+ function M.is_enabled()
+     return M.enabled
+ end
+
+ return M
+diff --git a/tests/integration/review_diag_display_spec.lua b/tests/integration/review_diag_display_spec.lua
+index 7950705..97fe2e8 100644
+--- a/tests/integration/review_diag_display_spec.lua
++++ b/tests/integration/review_diag_display_spec.lua
+@@ -1,31 +1,86 @@
+ -- Integration tests for the review-diagnostic inline display toggle (#133 M6).
+
+ local dd = require("parley.skills.review.diag_display")
+
+ local function ns_cfg()
+     return vim.diagnostic.config(nil, require("parley.skill_render").diag_namespace())
+ end
+
++local function display_marks(buf)
++    local display_ns = vim.api.nvim_create_namespace("parley_diagnostic_virtual_lines")
++    return vim.api.nvim_buf_get_extmarks(buf, display_ns, 0, -1, { details = true })
++end
++
+ describe("review.diag_display", function()
+     after_each(function()
+         dd.set(true) -- restore default for other specs
++        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
++            if vim.api.nvim_buf_is_valid(buf) then
++                pcall(vim.diagnostic.reset, require("parley.skill_render").diag_namespace(), buf)
++            end
++        end
+     end)
+
+     it("toggles the enabled state", function()
+         dd.set(true)
+         assert.is_true(dd.is_enabled())
+         assert.is_false(dd.toggle())
+         assert.is_false(dd.is_enabled())
+         assert.is_true(dd.toggle())
+         assert.is_true(dd.is_enabled())
+     end)
+
+-    it("configures virtual_lines current_line on parley's namespace when on; off when disabled", function()
++    it("configures Parley's custom current-line display on its namespace when on; off when disabled", function()
+         dd.set(true)
+         local on = ns_cfg()
+-        assert.is_truthy(on.virtual_lines) -- { current_line = true }
++        assert.is_false(on.virtual_lines) -- Parley owns its virtual-lines renderer.
++        assert.is_truthy(on["parley/virtual_lines"])
+         assert.is_false(on.virtual_text) -- inline single-line is never used
+         dd.set(false)
+-        assert.is_false(ns_cfg().virtual_lines)
++        assert.is_false(ns_cfg()["parley/virtual_lines"])
++    end)
++
++    it("renders current-line diagnostics from the left column without moving the diagnostic span", function()
++        local skill_render = require("parley.skill_render")
++        local diag_ns = skill_render.diag_namespace()
++        local buf = vim.api.nvim_create_buf(false, true)
++        vim.api.nvim_set_current_buf(buf)
++        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
++            string.rep("x", 120) .. " ACOS[^acos]",
++        })
++
++        dd.set(true)
++        vim.diagnostic.set(diag_ns, buf, { {
++            lnum = 0,
++            col = 121,
++            end_lnum = 0,
++            end_col = 132,
++            message = "ACOS — Advertising Cost of Sales.",
++            severity = vim.diagnostic.severity.INFO,
++            source = "parley-footnote",
++        } })
++
++        vim.wait(100, function()
++            return #display_marks(buf) == 1
++        end)
++
++        local marks = display_marks(buf)
++        assert.are.equal(1, #marks)
++        local details = marks[1][4]
++        assert.is_true(details.virt_lines_leftcol)
++        assert.are.equal("Diagnostics:", details.virt_lines[1][1][1])
++        assert.are_not.equal(string.rep(" ", 121), details.virt_lines[1][1][1])
++        assert.are.equal("ACOS — Advertising Cost of Sales.", details.virt_lines[2][1][1])
++
++        local diagnostics = vim.diagnostic.get(buf, { namespace = diag_ns })
++        assert.are.equal(1, #diagnostics)
++        assert.are.equal(0, diagnostics[1].lnum)
++        assert.are.equal(121, diagnostics[1].col)
++        assert.are.equal(0, diagnostics[1].end_lnum)
++        assert.are.equal(132, diagnostics[1].end_col)
++
++        dd.set(false)
++        assert.are.equal(0, #display_marks(buf))
++        assert.are.equal(1, #vim.diagnostic.get(buf, { namespace = diag_ns }))
+     end)
+ end)
+
+exec
+/bin/zsh -lc "nl -ba lua/parley/skill_render.lua | sed -n '1,230p'" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+     1    -- parley.skill_render — buffer decorations for applied skill edits.
+     2    --
+     3    -- The diagnostics/highlights rendering salvaged out of skill_runner (#128 M3),
+     4    -- now the single source used by the skill_invoke driver (skill_runner was
+     5    -- deleted in M4). Thin vim-API/UI wrapper (not pure): INFO diagnostics from each
+     6    -- edit's `explain`, DiffChange highlights on edited regions.
+     7
+     8    local M = {}
+     9
+    10    local DIAG_NS = "parley_skill"
+    11    local HL_NS = "parley_skill_hl"
+    12    local FOOTNOTE_SOURCE = "parley-footnote"
+    13
+    14    local diag_ns_id
+    15    local hl_ns_id
+    16
+    17    local function ensure_namespaces()
+    18        if not diag_ns_id then
+    19            diag_ns_id = vim.api.nvim_create_namespace(DIAG_NS)
+    20        end
+    21        if not hl_ns_id then
+    22            hl_ns_id = vim.api.nvim_create_namespace(HL_NS)
+    23        end
+    24    end
+    25
+    26    --- Clear previous skill diagnostics and highlights from a buffer.
+    27    function M.clear_decorations(buf)
+    28        ensure_namespaces()
+    29        vim.diagnostic.reset(diag_ns_id, buf)
+    30        vim.api.nvim_buf_clear_namespace(buf, hl_ns_id, 0, -1)
+    31    end
+    32
+    33    --- Dismiss the live round decorations (manual <dismiss> binding). Decorations
+    34    --- otherwise RIDE subsequent edits (behavior B, #133) and are cleared only at
+    35    --- the next round start; this lets the operator clear them on demand.
+    36    M.dismiss = M.clear_decorations
+    37
+    38    --- The review diagnostic namespace id — the single source other modules
+    39    --- (diag_display) target, so the namespace identity isn't duplicated as a literal
+    40    --- string in two places (#133 M6 review).
+    41    function M.diag_namespace()
+    42        ensure_namespaces()
+    43        return diag_ns_id
+    44    end
+    45
+    46    --- Hard-wrap text to `width` columns at word boundaries (greedy), preserving any
+    47    --- existing newlines. PURE. Lets `virtual_lines` render a long "why" as multiple
+    48    --- wrapped rows (nvim doesn't soft-wrap virtual text). A word longer than width
+    49    --- stays on its own (overflowing) line rather than being split. (#133 M6)
+    50    --- @param text string
+    51    --- @param width number|nil  default 76
+    52    --- @return string
+    53    function M.wrap(text, width)
+    54        width = width or 76
+    55        local out = {}
+    56        for para in (tostring(text) .. "\n"):gmatch("(.-)\n") do
+    57            if para == "" then
+    58                table.insert(out, "")
+    59            else
+    60                local line = ""
+    61                for word in para:gmatch("%S+") do
+    62                    if line == "" then
+    63                        line = word
+    64                    elseif #line + 1 + #word <= width then
+    65                        line = line .. " " .. word
+    66                    else
+    67                        table.insert(out, line)
+    68                        line = word
+    69                    end
+    70                end
+    71                table.insert(out, line)
+    72            end
+    73        end
+    74        return table.concat(out, "\n")
+    75    end
+    76
+    77    -- Usable wrap width for the virtual_lines "why": the window's text columns
+    78    -- (total width minus the number/sign/fold gutter, via getwininfo.textoff) minus
+    79    -- a margin for the indent + connector nvim renders under the line. Wrapping to a
+    80    -- fixed 76 overflowed the indented virtual_lines and truncated the right edge
+    81    -- (#133 review). Falls back to 76 with no window.
+    82    local function diag_wrap_width()
+    83        local ok, info = pcall(function()
+    84            return vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
+    85        end)
+    86        if not ok or type(info) ~= "table" then
+    87            return 76
+    88        end
+    89        return math.max(30, (info.width or 80) - (info.textoff or 0) - 10)
+    90    end
+    91
+    92    --- Current usable wrap width for Parley diagnostic virtual lines.
+    93    --- @return integer
+    94    function M.diagnostic_wrap_width()
+    95        return diag_wrap_width()
+    96    end
+    97
+    98    --- Format a diagnostic message for Neovim virtual_lines display.
+    99    --- @param text string
+   100    --- @param width number|nil default current diagnostic display width
+   101    --- @return string
+   102    function M.format_diagnostic_message(text, width)
+   103        return M.wrap(text, width or M.diagnostic_wrap_width())
+   104    end
+   105
+   106    local function is_footnote_diagnostic(diagnostic)
+   107        local user_data = diagnostic.user_data or {}
+   108        return diagnostic.source == FOOTNOTE_SOURCE or user_data.parley_kind == "footnote"
+   109    end
+   110
+   111    --- Rehydrate persisted managed markdown footnotes into Parley diagnostics.
+   112    --- Existing non-footnote diagnostics in the shared namespace are preserved.
+   113    --- @param buf number|nil
+   114    function M.refresh_footnote_diagnostics(buf)
+   115        ensure_namespaces()
+   116        buf = buf or vim.api.nvim_get_current_buf()
+   117        if not vim.api.nvim_buf_is_valid(buf) then
+   118            return
+   119        end
+   120
+   121        local define = require("parley.define")
+   122        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
+   123        local width = M.diagnostic_wrap_width()
+   124        local diagnostics = {}
+   125
+   126        for _, existing in ipairs(vim.diagnostic.get(buf, { namespace = diag_ns_id })) do
+   127            if not is_footnote_diagnostic(existing) then
+   128                table.insert(diagnostics, existing)
+   129            end
+   130        end
+   131
+   132        for _, footnote in ipairs(define.footnote_diagnostics(lines)) do
+   133            table.insert(diagnostics, {
+   134                lnum = footnote.lnum,
+   135                col = footnote.col,
+   136                end_lnum = footnote.end_lnum or footnote.lnum,
+   137                end_col = footnote.end_col,
+   138                message = define.format_definition(footnote.term or footnote.id, footnote.definition, width),
+   139                severity = vim.diagnostic.severity.INFO,
+   140                source = FOOTNOTE_SOURCE,
+   141                user_data = { parley_kind = "footnote" },
+   142            })
+   143        end
+   144
+   145        vim.diagnostic.set(diag_ns_id, buf, diagnostics)
+   146    end
+   147
+   148    --- Attach INFO diagnostics from edit explanations. Each diagnostic spans the
+   149    --- edit's line range (lnum..end_lnum) so "cursor in the region" matches, and its
+   150    --- message is hard-wrapped to the window's usable width for `virtual_lines`
+   151    --- display (no right-edge truncation). (#133 M6)
+   152    --- @param buf number
+   153    --- @param edits table[]  applied edits with {pos, explain, new_string?}
+   154    --- @param original_content string  file content before edits
+   155    function M.attach_diagnostics(buf, edits, original_content)
+   156        ensure_namespaces()
+   157        local width = M.diagnostic_wrap_width()
+   158        local diagnostics = {}
+   159        for _, edit in ipairs(edits) do
+   160            local line_num = 0
+   161            for _ in original_content:sub(1, edit.pos):gmatch("\n") do
+   162                line_num = line_num + 1
+   163            end
+   164            -- end_lnum spans the edit's own lines (newlines in the new text); a pure
+   165            -- deletion (no new_string) stays a single-line anchor.
+   166            local span = 0
+   167            for _ in (edit.new_string or ""):gmatch("\n") do
+   168                span = span + 1
+   169            end
+   170            table.insert(diagnostics, {
+   171                lnum = line_num,
+   172                end_lnum = line_num + span,
+   173                col = 0,
+   174                message = M.format_diagnostic_message(edit.explain or "edit applied", width),
+   175                severity = vim.diagnostic.severity.INFO,
+   176                source = "parley-skill",
+   177            })
+   178        end
+   179        vim.diagnostic.set(diag_ns_id, buf, diagnostics)
+   180    end
+   181
+   182    --- Highlight edited regions with DiffChange.
+   183    --- @param buf number
+   184    --- @param edits table[]  applied edits with {new_string}
+   185    --- @param new_content string  file content after edits
+   186    function M.highlight_edits(buf, edits, new_content)
+   187        ensure_namespaces()
+   188        for _, edit in ipairs(edits) do
+   189            -- Skip pure deletions: new_string is "" and `find("")` returns 1, which
+   190            -- would spuriously highlight line 0. Deletions are oriented by their
+   191            -- INFO gutter diagnostic (the "why") via attach_diagnostics, not a
+   192            -- highlight (there's no new text to mark). #133.
+   193            local new_pos = (edit.new_string and edit.new_string ~= "")
+   194                and new_content:find(edit.new_string, 1, true)
+   195                or nil
+   196            if new_pos then
+   197                local start_line = 0
+   198                for _ in new_content:sub(1, new_pos):gmatch("\n") do
+   199                    start_line = start_line + 1
+   200                end
+   201                local end_line = start_line
+   202                for _ in edit.new_string:gmatch("\n") do
+   203                    end_line = end_line + 1
+   204                end
+   205                for line = start_line, end_line do
+   206                    vim.api.nvim_buf_add_highlight(buf, hl_ns_id, "DiffChange", line, 0, -1)
+   207                end
+   208            end
+   209        end
+   210    end
+   211
+   212    --- Highlight a whole line with DiffChange on the hl namespace (#161 R1). Same
+   213    --- shape `apply_snapshot` restores (whole-line, col 0..-1), so it round-trips
+   214    --- through projection's line-granular undo/redo snapshotting.
+   215    --- @param buf number
+   216    --- @param lnum0 number  0-based line
+   217    function M.highlight_line(buf, lnum0)
+   218        ensure_namespaces()
+   219        vim.api.nvim_buf_add_highlight(buf, hl_ns_id, "DiffChange", lnum0, 0, -1)
+   220    end
+   221
+   222    --- Highlight a column span with DiffChange on the hl namespace. The four-arg
+   223    --- form is same-line: (buf, lnum0, col_start, col_end). The five-arg form spans
+   224    --- rows: (buf, lnum0, col_start, end_lnum0, col_end).
+   225    --- @param buf number
+   226    --- @param lnum0 number 0-based start line
+   227    --- @param col_start number 0-based start column
+   228    --- @param end_lnum0_or_col_end number 0-based end line, or end column
+   229    --- @param col_end number|nil 0-based exclusive end column
+   230    function M.highlight_span(buf, lnum0, col_start, end_lnum0_or_col_end, col_end)
+
+exec
+/bin/zsh -lc "nl -ba lua/parley/init.lua | sed -n '740,790p;1628,1670p'" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+   740        end
+   741
+   742        -- prepare system_prompts list
+   743        M._system_prompts = {}
+   744        for name, _ in pairs(M.system_prompts) do
+   745            table.insert(M._system_prompts, name)
+   746        end
+   747        table.sort(M._system_prompts)
+   748
+   749        M.refresh_state()
+   750
+   751        if M.config.default_agent then
+   752            M.refresh_state({ agent = M.config.default_agent })
+   753        end
+   754
+   755        -- register user commands
+   756        for hook, _ in pairs(M.hooks) do
+   757            M.helpers.create_user_command(M.config.cmd_prefix .. hook, function(params)
+   758                if M.hooks[hook] ~= nil then
+   759                    M.refresh_state()
+   760                    M.logger.debug("running hook: " .. hook)
+   761                    return M.hooks[hook](M, params)
+   762                end
+   763                M.logger.error("The hook '" .. hook .. "' does not exist.")
+   764            end)
+   765        end
+   766
+   767        -- :ParleyProxy <subcommand> — manage the optional bundled cliproxyapi (#131)
+   768        M.register_proxy_command(M.config.cmd_prefix)
+   769
+   770        -- :ParleyShowDiagnostics — toggle inline display of review "why" diagnostics
+   771        -- (cursor-region auto-show, scoped to parley's namespace). Default on. (#133 M6)
+   772        M.helpers.create_user_command(M.config.cmd_prefix .. "ShowDiagnostics", function()
+   773            local on = require("parley.skills.review.diag_display").toggle()
+   774            M.logger.info("Parley review diagnostics: inline display " .. (on and "ON" or "OFF"))
+   775        end)
+   776        require("parley.skills.review.diag_display").set(true)
+   777
+   778        -- Register all global keymaps from the keybinding registry
+   779        kb_registry.register_global(
+   780            { "global", "repo", "note", "issue", "vision", "chat" },
+   781            M.config,
+   782            {
+   783                help = function() M.cmd.KeyBindings() end,
+   784                chat_new = function() M.cmd.ChatNew({}) end,
+   785                chat_finder = function() M.cmd.ChatFinder() end,
+   786                chat_review = function() M.cmd.ChatReview({}) end,
+   787                note_new = function() M.cmd.NoteNew() end,
+   788                note_finder = function() M.cmd.NoteFinder({}) end,
+   789                note_dirs = function() M.cmd.NoteDirs({}) end,
+   790                year_root = function()
+  1628        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
+  1629        if define.slice_selection(lines, sr, sc - 1, er, ec - 1) ~= phrase then
+  1630            M.logger.warning("Define: selection changed during lookup — re-select to define")
+  1631            return
+  1632        end
+  1633        local original = table.concat(lines, "\n") -- pre-edit content (undo base)
+  1634
+  1635        -- Store the definition as a markdown footnote in ONE full-buffer set_lines
+  1636        -- edit (single undo entry = the anchor). set_applying suppresses any prior
+  1637        -- define's projection watcher during our own edit (mirrors review).
+  1638        projection.set_applying(buf, true)
+  1639        local input = call.input or {}
+  1640        local e = define.apply_definition_footnote(lines, sr, sc - 1, er, ec - 1, input.term or phrase, input.definition)
+  1641        require("parley.buffer_edit").replace_all_lines_for_definition(buf, e.lines)
+  1642
+  1643        local diag_span = e.diagnostic_span
+  1644        skill_render.highlight_span(buf, diag_span.lnum, diag_span.col, diag_span.end_lnum, diag_span.end_col)
+  1645        skill_render.refresh_footnote_diagnostics(buf)
+  1646
+  1647        -- Record projection states so undo/redo of the footnote edit clears/restores
+  1648        -- the decorations (#133 M5 machinery, reused): pre-edit hash → empty
+  1649        -- snapshot, footnoted hash → highlight+diagnostic; attach the watcher.
+  1650        projection.record_empty_for(buf, original)
+  1651        projection.record(buf)
+  1652        projection.ensure_watch(buf)
+  1653        projection.set_applying(buf, false)
+  1654
+  1655        -- Park the cursor on the term's line so diag_display's current-line
+  1656        -- virtual_lines reveals the definition immediately.
+  1657        pcall(vim.api.nvim_win_set_cursor, 0, { sr, math.max(0, sc - 1) })
+  1658        vim.cmd("redraw")
+  1659    end
+  1660
+  1661    -- define_visual: the thin IO shell for visual-mode <M-CR>. Reads the selection,
+  1662    -- computes the enclosing-exchange context, and fires a headless define skill
+  1663    -- turn whose on_done stores + renders the definition inline. Pure logic lives
+  1664    -- in lua/parley/define.lua. Exposed as M.define_visual for the keybinding.
+  1665    function M.define_visual(buf)
+  1666        buf = buf or vim.api.nvim_get_current_buf()
+  1667        local sp = vim.fn.getpos("'<")
+  1668        local ep = vim.fn.getpos("'>")
+  1669        local sr, sc = sp[2], sp[3]
+  1670        local er, ec = ep[2], ep[3]
+
+exec
+/bin/zsh -lc "rg -n \"attach_diagnostics|diag_namespace|diagnostic.set|end_lnum|format_diagnostic_message\" lua/parley tests -g '*.lua'" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+lua/parley/define.lua:80:    return require("parley.skill_render").format_diagnostic_message(head, width)
+lua/parley/define.lua:121:--- @return table { lnum: integer, col: integer, end_lnum: integer, end_col: integer }
+lua/parley/define.lua:126:        end_lnum = l2 - 1,
+lua/parley/define.lua:254:                    end_lnum = lnum - 1,
+lua/parley/define.lua:378:            end_lnum = l2 - 1,
+tests/integration/review_diag_display_spec.lua:6:    return vim.diagnostic.config(nil, require("parley.skill_render").diag_namespace())
+tests/integration/review_diag_display_spec.lua:19:                pcall(vim.diagnostic.reset, require("parley.skill_render").diag_namespace(), buf)
+tests/integration/review_diag_display_spec.lua:45:        local diag_ns = skill_render.diag_namespace()
+tests/integration/review_diag_display_spec.lua:53:        vim.diagnostic.set(diag_ns, buf, { {
+tests/integration/review_diag_display_spec.lua:56:            end_lnum = 0,
+tests/integration/review_diag_display_spec.lua:79:        assert.are.equal(0, diagnostics[1].end_lnum)
+tests/integration/highlighting_spec.lua:407:        if ok and tz.diag_namespace then
+tests/integration/highlighting_spec.lua:410:                    pcall(vim.diagnostic.reset, tz.diag_namespace(), buf)
+tests/integration/highlighting_spec.lua:437:        local diagnostics = vim.diagnostic.get(buf, { namespace = tz.diag_namespace() })
+tests/integration/highlighting_spec.lua:444:        local diag_config = vim.diagnostic.config(nil, tz.diag_namespace())
+tests/integration/highlighting_spec.lua:448:        local skill_ns = require("parley.skill_render").diag_namespace()
+tests/integration/highlighting_spec.lua:449:        assert.are_not.equal(skill_ns, tz.diag_namespace())
+tests/integration/highlighting_spec.lua:458:        assert.equals(0, #vim.diagnostic.get(buf, { namespace = tz.diag_namespace() }))
+tests/integration/highlighting_spec.lua:470:            return #vim.diagnostic.get(buf, { namespace = tz.diag_namespace() }) == 0
+tests/integration/highlighting_spec.lua:472:        assert.equals(0, #vim.diagnostic.get(buf, { namespace = tz.diag_namespace() }))
+tests/integration/highlighting_spec.lua:479:            return #vim.diagnostic.get(buf, { namespace = tz.diag_namespace() }) == 1
+tests/integration/highlighting_spec.lua:482:        local diagnostics = vim.diagnostic.get(buf, { namespace = tz.diag_namespace() })
+tests/integration/highlighting_spec.lua:491:        if ok and skill_render.diag_namespace then
+tests/integration/highlighting_spec.lua:494:                    pcall(vim.diagnostic.reset, skill_render.diag_namespace(), buf)
+tests/integration/highlighting_spec.lua:514:        local diagnostics = vim.diagnostic.get(buf, { namespace = skill_render.diag_namespace() })
+tests/integration/highlighting_spec.lua:526:        local ns = skill_render.diag_namespace()
+tests/integration/highlighting_spec.lua:533:        vim.diagnostic.set(ns, buf, { {
+lua/parley/skills/review/diag_display.lua:25:    return require("parley.skill_render").diag_namespace()
+tests/integration/skill_invoke_review_spec.lua:130:        require("parley.skill_render").attach_diagnostics(b, { { pos = 1, explain = "why" } }, "edited line")
+tests/integration/review_projection_spec.lua:37:        skill_render.attach_diagnostics(buf, { { pos = content:find("reviewed"), explain = "agent edit" } }, content)
+tests/integration/review_projection_spec.lua:55:        skill_render.attach_diagnostics(buf, { { pos = 1, explain = "why" } }, "round output")
+tests/integration/review_projection_spec.lua:74:        skill_render.attach_diagnostics(buf, { { pos = 1, explain = "edit A" } }, "state A")
+tests/integration/review_projection_spec.lua:80:        skill_render.attach_diagnostics(buf, { { pos = 1, explain = "edit B" } }, "state B")
+tests/integration/review_projection_spec.lua:97:        skill_render.attach_diagnostics(buf, { { pos = 1, explain = "why" } }, "round output")
+tests/integration/define_spec.lua:197:    local ns = require("parley.skill_render").diag_namespace()
+tests/integration/define_spec.lua:264:        assert.are.equal(2, diags[1].end_lnum)
+lua/parley/timezone_diagnostics.lua:126:function M.diag_namespace()
+lua/parley/timezone_diagnostics.lua:155:            end_lnum = diagnostic.lnum,
+lua/parley/timezone_diagnostics.lua:168:    vim.diagnostic.set(diag_ns_id, buf, nvim_diagnostics)
+lua/parley/skill_render.lua:41:function M.diag_namespace()
+lua/parley/skill_render.lua:102:function M.format_diagnostic_message(text, width)
+lua/parley/skill_render.lua:136:            end_lnum = footnote.end_lnum or footnote.lnum,
+lua/parley/skill_render.lua:145:    vim.diagnostic.set(diag_ns_id, buf, diagnostics)
+lua/parley/skill_render.lua:149:--- edit's line range (lnum..end_lnum) so "cursor in the region" matches, and its
+lua/parley/skill_render.lua:155:function M.attach_diagnostics(buf, edits, original_content)
+lua/parley/skill_render.lua:164:        -- end_lnum spans the edit's own lines (newlines in the new text); a pure
+lua/parley/skill_render.lua:172:            end_lnum = line_num + span,
+lua/parley/skill_render.lua:174:            message = M.format_diagnostic_message(edit.explain or "edit applied", width),
+lua/parley/skill_render.lua:179:    vim.diagnostic.set(diag_ns_id, buf, diagnostics)
+lua/parley/skill_render.lua:191:        -- INFO gutter diagnostic (the "why") via attach_diagnostics, not a
+lua/parley/skill_render.lua:224:--- rows: (buf, lnum0, col_start, end_lnum0, col_end).
+lua/parley/skill_render.lua:228:--- @param end_lnum0_or_col_end number 0-based end line, or end column
+lua/parley/skill_render.lua:230:function M.highlight_span(buf, lnum0, col_start, end_lnum0_or_col_end, col_end)
+lua/parley/skill_render.lua:232:    local end_lnum0 = lnum0
+lua/parley/skill_render.lua:234:        col_end = end_lnum0_or_col_end
+lua/parley/skill_render.lua:236:        end_lnum0 = end_lnum0_or_col_end
+lua/parley/skill_render.lua:239:        end_row = end_lnum0,
+lua/parley/skill_render.lua:262:                end_lnum = details.end_row,
+lua/parley/skill_render.lua:272:            end_lnum = d.end_lnum,
+lua/parley/skill_render.lua:293:        M.highlight_span(buf, span.lnum, span.col or 0, span.end_lnum or span.lnum, span.end_col)
+lua/parley/skill_render.lua:300:                end_lnum = d.end_lnum or d.lnum,
+lua/parley/skill_render.lua:309:        vim.diagnostic.set(diag_ns_id, buf, diagnostics)
+lua/parley/init.lua:1644:    skill_render.highlight_span(buf, diag_span.lnum, diag_span.col, diag_span.end_lnum, diag_span.end_col)
+tests/unit/skill_render_spec.lua:13:    it("attach_diagnostics sets an INFO diagnostic per edit, on the edit's line", function()
+tests/unit/skill_render_spec.lua:18:        skill_render.attach_diagnostics(buf, { { pos = pos, explain = "changed two" } }, original)
+tests/unit/skill_render_spec.lua:28:        skill_render.attach_diagnostics(buf, { { pos = 1, explain = "e" } }, "x")
+tests/unit/skill_render_spec.lua:54:        skill_render.attach_diagnostics(buf, edits, original)
+tests/unit/skill_render_spec.lua:74:    it("format_diagnostic_message word-wraps display text at the requested width", function()
+tests/unit/skill_render_spec.lua:75:        local msg = skill_render.format_diagnostic_message("alpha beta gamma delta epsilon zeta", 16)
+tests/unit/skill_render_spec.lua:83:    it("attach_diagnostics wraps the message + spans the edit's lines (end_lnum)", function()
+tests/unit/skill_render_spec.lua:87:        skill_render.attach_diagnostics(buf, {
+tests/unit/skill_render_spec.lua:92:        assert.are.equal(2, d.end_lnum) -- spans the 2-line new_string
+tests/unit/skill_render_spec.lua:100:        skill_render.attach_diagnostics(buf, { { pos = content:find("two"), explain = "why two" } }, content)
+tests/unit/skill_render_spec.lua:111:        assert.is_not_nil(diags[1].end_lnum, "end_lnum survives snapshot→apply (#133 M6)")
+tests/unit/skill_render_spec.lua:119:        local diag_ns = skill_render.diag_namespace()
+tests/unit/skill_render_spec.lua:122:        vim.diagnostic.set(diag_ns, buf, { {
+tests/unit/skill_render_spec.lua:125:            end_lnum = 0,
+tests/unit/skill_render_spec.lua:151:        skill_render.attach_diagnostics(buf, { { pos = 1, explain = "e" } }, "x")
+lua/parley/skill_invoke.lua:78:    skill_render.attach_diagnostics(buf, edits, original)
+tests/unit/define_spec.lua:82:        local orig = skill_render.format_diagnostic_message
+tests/unit/define_spec.lua:84:        skill_render.format_diagnostic_message = function(text, width)
+tests/unit/define_spec.lua:91:        skill_render.format_diagnostic_message = orig
+tests/unit/define_spec.lua:129:            end_lnum = 2,
+tests/unit/define_spec.lua:139:            end_lnum = 2,
+tests/unit/define_spec.lua:167:        assert.are.same({ lnum = 0, col = 8, end_lnum = 0, end_col = 19 }, result.diagnostic_span)
+tests/unit/define_spec.lua:216:        assert.are.same({ lnum = 0, col = 0, end_lnum = 0, end_col = 11 }, result.diagnostic_span)
+tests/unit/define_spec.lua:280:            end_lnum = 0,
+tests/unit/define_spec.lua:301:            end_lnum = 0,
+tests/unit/define_spec.lua:310:            end_lnum = 0,
+
+exec
+/bin/zsh -lc "nl -ba tests/integration/highlighting_spec.lua | sed -n '420,470p'" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+   420            vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
+   421                "User: meet at 2026-04-18T00:00:00Z",
+   422            })
+   423
+   424            tz.refresh_buffer(buf, {
+   425                to_local = function()
+   426                    return {
+   427                        year = 2026,
+   428                        month = 4,
+   429                        day = 17,
+   430                        hour = 17,
+   431                        min = 0,
+   432                        sec = 0,
+   433                    }
+   434                end,
+   435            })
+   436
+   437            local diagnostics = vim.diagnostic.get(buf, { namespace = tz.diag_namespace() })
+   438            assert.equals(1, #diagnostics)
+   439            assert.equals(0, diagnostics[1].lnum)
+   440            assert.equals(14, diagnostics[1].col)
+   441            assert.equals(34, diagnostics[1].end_col)
+   442            assert.equals("parley-timezone", diagnostics[1].source)
+   443            assert.equals("local time: 2026-04-17 17:00:00", diagnostics[1].message)
+   444            local diag_config = vim.diagnostic.config(nil, tz.diag_namespace())
+   445            assert.same({ current_line = true }, diag_config.virtual_lines)
+   446            assert.equals(false, diag_config.virtual_text)
+   447
+   448            local skill_ns = require("parley.skill_render").diag_namespace()
+   449            assert.are_not.equal(skill_ns, tz.diag_namespace())
+   450
+   451            vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "💬: meet later" })
+   452            tz.refresh_buffer(buf, {
+   453                to_local = function()
+   454                    error("no timestamps remain")
+   455                end,
+   456            })
+   457
+   458            assert.equals(0, #vim.diagnostic.get(buf, { namespace = tz.diag_namespace() }))
+   459        end)
+   460
+   461        it("refreshes diagnostics for registered buffers on text changes", function()
+   462            local tz = require("parley.timezone_diagnostics")
+   463            local buf = vim.api.nvim_create_buf(false, true)
+   464            vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), buf)
+   465            parley._parley_bufs[buf] = "markdown"
+   466            vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "no timestamp yet" })
+   467
+   468            vim.cmd("doautocmd TextChanged")
+   469            vim.wait(100, function()
+   470                return #vim.diagnostic.get(buf, { namespace = tz.diag_namespace() }) == 0
+
+codex
+One risk area stands out: review diagnostics deliberately span `lnum..end_lnum`, but the new renderer filters only on `diagnostic.lnum`. I’m verifying whether that regresses the documented “cursor in edit region” behavior before deciding severity.
+exec
+/bin/zsh -lc "rg -n \"vim\\._resolve_bufnr|current_line|end_lnum|cursor in.*region|diagnostic span\" lua tests atlas" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+lua/parley/define.lua:121:--- @return table { lnum: integer, col: integer, end_lnum: integer, end_col: integer }
+lua/parley/define.lua:126:        end_lnum = l2 - 1,
+lua/parley/define.lua:254:                    end_lnum = lnum - 1,
+lua/parley/define.lua:378:            end_lnum = l2 - 1,
+lua/parley/artifact_ref.lua:181:    local line = vim.api.nvim_get_current_line()
+lua/parley/neighborhood.lua:138:        local line = vim.api.nvim_get_current_line()
+lua/parley/spell.lua:96:    local line = vim.api.nvim_get_current_line()
+lua/parley/skills/review/diag_display.lua:5:-- Default ON: `virtual_lines { current_line = true }`, so the (hard-wrapped) why
+lua/parley/skills/review/diag_display.lua:47:local function current_line_for(buf)
+lua/parley/skills/review/diag_display.lua:65:local function render(buf, diagnostics, current_line_only)
+lua/parley/skills/review/diag_display.lua:72:    local line = current_line_only and current_line_for(buf) or nil
+lua/parley/skills/review/diag_display.lua:73:    if current_line_only and not line then
+lua/parley/skills/review/diag_display.lua:79:        if not current_line_only or diagnostic.lnum == line then
+lua/parley/skills/review/diag_display.lua:108:            bufnr = vim._resolve_bufnr(bufnr)
+lua/parley/skills/review/diag_display.lua:110:            local current_line_only = handler_opts.current_line == true
+lua/parley/skills/review/diag_display.lua:112:            if current_line_only then
+lua/parley/skills/review/diag_display.lua:121:            render(bufnr, diagnostics, current_line_only)
+lua/parley/skills/review/diag_display.lua:127:            clear(vim._resolve_bufnr(bufnr))
+lua/parley/skills/review/diag_display.lua:146:        [HANDLER_NAME] = M.enabled and { current_line = true } or false,
+lua/parley/chat_parser.lua:342:        cb_state.current_lines = {}
+lua/parley/chat_parser.lua:346:        cb_state.current_line_start = nil
+lua/parley/chat_parser.lua:359:        local body = table.concat(cb_state.current_lines, "\n")
+lua/parley/chat_parser.lua:393:            local trimmed_start = cb_state.current_line_start
+lua/parley/chat_parser.lua:409:        cb_state.current_lines = {}
+lua/parley/chat_parser.lua:410:        cb_state.current_line_start = nil
+lua/parley/chat_parser.lua:433:        if cb_state.current_line_start == nil then
+lua/parley/chat_parser.lua:434:            cb_state.current_line_start = line_no
+lua/parley/chat_parser.lua:436:        table.insert(cb_state.current_lines, line)
+lua/parley/chat_parser.lua:618:            cb_state = { blocks = {}, current_kind = nil, current_lines = {} }
+lua/parley/init.lua:896:                        local line = vim.api.nvim_get_current_line()
+lua/parley/init.lua:1644:    skill_render.highlight_span(buf, diag_span.lnum, diag_span.col, diag_span.end_lnum, diag_span.end_col)
+lua/parley/init.lua:2032:        local line = vim.api.nvim_get_current_line()
+lua/parley/init.lua:2721:local function try_open_inline_branch_link(current_line, cursor_col, parent_buf)
+lua/parley/init.lua:2724:    local inline_links = chat_parser.extract_inline_branch_links(current_line, branch_prefix)
+lua/parley/init.lua:3652:local function open_branch_ref(current_line, buf)
+lua/parley/init.lua:3653:    local parsed = M._parse_branch_ref(current_line)
+lua/parley/init.lua:3740:M.open_chat_reference = function(current_line, cursor_col, _in_insert_mode, full_line)
+lua/parley/init.lua:3742:    if try_open_src_link(current_line, cursor_col, vim.api.nvim_get_current_buf()) then
+lua/parley/init.lua:3747:    if try_open_inline_branch_link(current_line, cursor_col, vim.api.nvim_get_current_buf()) then
+lua/parley/init.lua:3752:    if open_branch_ref(current_line, vim.api.nvim_get_current_buf()) then
+lua/parley/init.lua:3760:    if current_line:match("^@@") then
+lua/parley/init.lua:3762:        chat_path = current_line:match("^@@%s*([^@]+)@@")
+lua/parley/init.lua:3763:            or current_line:match("^@@%s*([^:]+):")
+lua/parley/init.lua:3764:            or current_line:match("^@@(.+)$")
+lua/parley/init.lua:3770:        chat_path = M._parse_at_reference(current_line, cursor_col)
+lua/parley/init.lua:3850:    local current_line = vim.api.nvim_buf_get_lines(buf, line_num - 1, line_num, false)[1]
+lua/parley/init.lua:3865:        M.open_chat_reference(current_line, cursor_col, in_insert_mode, current_line)
+lua/parley/init.lua:3876:    if open_branch_ref(current_line, buf) then
+lua/parley/init.lua:3881:    if try_open_inline_branch_link(current_line, cursor_col, buf) then
+lua/parley/init.lua:3889:    if current_line:match("^@@") then
+lua/parley/init.lua:3890:        filepath = (current_line:match("^@@(.+)@@") or current_line:match("^@@(.+)$")):gsub("^%s*(.-)%s*$", "%1")
+lua/parley/init.lua:3893:        filepath = M._parse_at_reference(current_line, cursor_col)
+lua/parley/init.lua:3976:                if current_line:match("@@[^:]+:%s*(.+)") then
+lua/parley/init.lua:3977:                    topic = current_line:match("@@[^:]+:%s*(.+)")
+lua/parley/skill_render.lua:136:            end_lnum = footnote.end_lnum or footnote.lnum,
+lua/parley/skill_render.lua:148:--- Attach INFO diagnostics from edit explanations. Each diagnostic spans the
+lua/parley/skill_render.lua:149:--- edit's line range (lnum..end_lnum) so "cursor in the region" matches, and its
+lua/parley/skill_render.lua:164:        -- end_lnum spans the edit's own lines (newlines in the new text); a pure
+lua/parley/skill_render.lua:172:            end_lnum = line_num + span,
+lua/parley/skill_render.lua:224:--- rows: (buf, lnum0, col_start, end_lnum0, col_end).
+lua/parley/skill_render.lua:228:--- @param end_lnum0_or_col_end number 0-based end line, or end column
+lua/parley/skill_render.lua:230:function M.highlight_span(buf, lnum0, col_start, end_lnum0_or_col_end, col_end)
+lua/parley/skill_render.lua:232:    local end_lnum0 = lnum0
+lua/parley/skill_render.lua:234:        col_end = end_lnum0_or_col_end
+lua/parley/skill_render.lua:236:        end_lnum0 = end_lnum0_or_col_end
+lua/parley/skill_render.lua:239:        end_row = end_lnum0,
+lua/parley/skill_render.lua:262:                end_lnum = details.end_row,
+lua/parley/skill_render.lua:272:            end_lnum = d.end_lnum,
+lua/parley/skill_render.lua:293:        M.highlight_span(buf, span.lnum, span.col or 0, span.end_lnum or span.lnum, span.end_col)
+lua/parley/skill_render.lua:300:                end_lnum = d.end_lnum or d.lnum,
+lua/parley/issues.lua:897:    local line = vim.api.nvim_get_current_line()
+lua/parley/issues.lua:942:        local line = vim.api.nvim_get_current_line()
+lua/parley/chat_finder.lua:796:                            local current_line = vim.api.nvim_buf_get_lines(
+lua/parley/chat_finder.lua:805:                            local new_line = current_line:sub(1, col) .. inline_link .. current_line:sub(col + 1)
+atlas/modes/review.md:171:`lnum..end_lnum`) and hides otherwise. `:ParleyShowDiagnostics` toggles it. The
+atlas/modes/review.md:173:diagnostics because the underlying diagnostic spans remain unchanged. Composes
+lua/parley/interview.lua:189:    local cursor_line = vim.api.nvim_get_current_line()
+lua/parley/vision.lua:1749:    local line = vim.api.nvim_get_current_line()
+lua/parley/vision.lua:1827:    local line = vim.api.nvim_get_current_line()
+tests/integration/review_diag_display_spec.lua:43:    it("renders current-line diagnostics from the left column without moving the diagnostic span", function()
+tests/integration/review_diag_display_spec.lua:56:            end_lnum = 0,
+tests/integration/review_diag_display_spec.lua:79:        assert.are.equal(0, diagnostics[1].end_lnum)
+tests/integration/define_spec.lua:264:        assert.are.equal(2, diags[1].end_lnum)
+tests/integration/highlighting_spec.lua:445:        assert.same({ current_line = true }, diag_config.virtual_lines)
+tests/unit/define_spec.lua:129:            end_lnum = 2,
+tests/unit/define_spec.lua:139:            end_lnum = 2,
+tests/unit/define_spec.lua:167:        assert.are.same({ lnum = 0, col = 8, end_lnum = 0, end_col = 19 }, result.diagnostic_span)
+tests/unit/define_spec.lua:216:        assert.are.same({ lnum = 0, col = 0, end_lnum = 0, end_col = 11 }, result.diagnostic_span)
+tests/unit/define_spec.lua:280:            end_lnum = 0,
+tests/unit/define_spec.lua:301:            end_lnum = 0,
+tests/unit/define_spec.lua:310:            end_lnum = 0,
+tests/unit/skill_render_spec.lua:83:    it("attach_diagnostics wraps the message + spans the edit's lines (end_lnum)", function()
+tests/unit/skill_render_spec.lua:92:        assert.are.equal(2, d.end_lnum) -- spans the 2-line new_string
+tests/unit/skill_render_spec.lua:111:        assert.is_not_nil(diags[1].end_lnum, "end_lnum survives snapshot→apply (#133 M6)")
+tests/unit/skill_render_spec.lua:125:            end_lnum = 0,
+lua/parley/timezone_diagnostics.lua:14:            virtual_lines = { current_line = true },
+lua/parley/timezone_diagnostics.lua:155:            end_lnum = diagnostic.lnum,
+
+exec
+/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"' in /Users/xianxu/workspace/parley.nvim
+exec
+/bin/zsh -lc "nvim --headless -c \"lua local dd=require('parley.skills.review.diag_display'); local sr=require('parley.skill_render'); local ns=sr.diag_namespace(); local b=vim.api.nvim_create_buf(false,true); vim.api.nvim_set_current_buf(b); vim.api.nvim_buf_set_lines(b,0,-1,false,{'one','two','three'}); dd.set(true); vim.diagnostic.set(ns,b,{{lnum=0,end_lnum=2,col=0,end_col=5,message='multi',severity=vim.diagnostic.severity.INFO}}); local dns=vim.api.nvim_create_namespace('parley_diagnostic_virtual_lines'); print('line1 marks', #vim.api.nvim_buf_get_extmarks(b,dns,0,-1,{details=true})); vim.api.nvim_win_set_cursor(0,{2,0}); vim.cmd('doautocmd CursorMoved'); print('line2 marks', #vim.api.nvim_buf_get_extmarks(b,dns,0,-1,{details=true})); vim.api.nvim_win_set_cursor(0,{3,0}); vim.cmd('doautocmd CursorMoved'); print('line3 marks', #vim.api.nvim_buf_get_extmarks(b,dns,0,-1,{details=true}));\" -c qa" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 341ms:
+
+LuaSnip: could not open log at /Users/xianxu/.local/state/nvim/luasnip.log. Not logging for this session.
+line1 marks 1
+line2 marks 0
+line3 marks 0
+Error detected while processing command line:
+E886: System error while opening temporary ShaDa file /Users/xianxu/.local/state/nvim/shada/main.shada.tmp.o for writing: operation not permitted
+Parley.nvim: Failed to open file for writing: /Users/xianxu/.local/share/nvim/parley/persisted/state.json
+ succeeded in 1458ms:
+
+Parley.nvim: Failed to open file for writing: /Users/xianxu/.local/share/nvim/parley/persisted/state.jsonScheduling: tests/integration/review_diag_display_spec.lua
+
+========================================
+Testing:     /Users/xianxu/workspace/parley.nvim/tests/integration/review_diag_display_spec.lua
+Success    ||    review.diag_display toggles the enabled state
+Success    ||    review.diag_display configures Parley's custom current-line display on its namespace when on; off when disabled
+Success    ||    review.diag_display renders current-line diagnostics from the left column without moving the diagnostic span
+
+Success:     3
+Failed :     0
+Errors :     0
+========================================
+
+codex
+Focused tests pass, but the multi-line diagnostic probe confirms the renderer disappears when the cursor moves within a diagnostic’s `end_lnum` range instead of staying visible for the region. I’m doing a final docs/README/atlas and full-test check now so the verdict includes verification context.
+exec
+/bin/zsh -lc 'git diff --unified=60 b9094e9bfc89b0f27013c6fd41c38a83b8b61510..HEAD -- atlas/chat/inline_define.md atlas/modes/review.md README.md workshop/issues/000173-diagnostic-virtual-lines-leftcol.md workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md' in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+diff --git a/atlas/chat/inline_define.md b/atlas/chat/inline_define.md
+index 270e924..6df2cf4 100644
+--- a/atlas/chat/inline_define.md
++++ b/atlas/chat/inline_define.md
+@@ -1,150 +1,150 @@
+ # Inline Term Definition
+
+ Select a phrase in a chat transcript, press **`<M-CR>`** (visual mode), and a
+-concise, context-aware definition appears as an inline diagnostic (grey
+-`virtual_lines`) under the phrase. The selected text stays in place and gets a
+-markdown footnote reference (`ASIN[^asin]`), while the definition is stored in a
+-managed footnote footer at the end of the chat transcript. Persisted managed
+-footnotes are rehydrated into diagnostics when any markdown buffer is entered or
+-refreshed. The whole new annotation is **undoable** — `u` reverts the footnote
+-edit and clears both decorations (see Undo below). For jargon you don't know
+-(e.g. `ASIN`), it's a one-keystroke lookup. Added in
++concise, context-aware definition appears as an inline diagnostic under the
++phrase. The selected text stays in place and gets a markdown footnote reference
++(`ASIN[^asin]`), while the definition is stored in a managed footnote footer at
++the end of the chat transcript. Persisted managed footnotes are rehydrated into
++diagnostics when any markdown buffer is entered or refreshed. The whole new
++annotation is **undoable** — `u` reverts the footnote edit and clears both
++decorations (see Undo below). For jargon you don't know (e.g. `ASIN`), it's a
++one-keystroke lookup. Added in
+ [#161](../../workshop/issues/000161-inline-term-definition.md) (R1 added the
+ highlight/undo); [#166](../../workshop/issues/000166-visual-selection-definition-system-manages-footnote.md)
+ made the definition durable as a managed footnote; [#167](../../workshop/issues/000167-define-diagnostic-highlight-span.md)
+ narrowed the visible decoration to the selected term plus footnote reference;
+ [#172](../../workshop/issues/000172-markdown-footnote-diagnostics.md)
+ rehydrates persisted managed footnotes in all markdown buffers.
+
+ ## Flow
+
+ 1. **`define_visual(buf)`** (`lua/parley/init.lua`) reads the visual selection
+    (`getpos`), extracts the phrase (`define.slice_selection`), guards
+    empty/whitespace, and computes a **bounded context** = the *enclosing
+    exchange* of the selection (`define.context_for_selection` over `parse_chat`
+    + `find_exchange_at_line`), falling back to the whole buffer.
+ 2. It fires a headless **`define` skill** turn via `skill_invoke.invoke` with
+    `opts.document = context`, `opts.no_reload = true`, and an `on_done`.
+ 3. The `define` skill (`lua/parley/skills/define/init.lua`) is **unforced** (no
+    `force_tool`) so the server-side `web_search` tool can run when the global
+    `:ToggleWebSearch` is on; its `source(ctx)` folds the phrase into the system
+    prompt and asks the model to call `emit_definition({term, definition})`.
+ 4. **`render_definition`** (`on_done`), on a successful lookup: re-verifies the
+    selection still holds the phrase (else skips — the buffer changed under the
+    in-flight call), then **(a)** adds a `[^id]` reference after the selected term
+    and inserts/updates a final managed footnote footer via one buffer rewrite
+    (`define.apply_definition_footnote`) — a single undo entry that anchors
+    everything; **(b)** highlights the selected term/reference span with
+    `DiffChange` (`skill_render.highlight_span`); **(c)** refreshes persisted
+    footnote diagnostics (`skill_render.refresh_footnote_diagnostics`), which
+    parses the managed footer and sets INFO `vim.diagnostic` entries on matching
+    inline `term[^id]` spans (`define.format_definition` →
+    `skill_render.format_diagnostic_message`) on the `parley_skill` namespace;
+    **(d)** records the undo/redo projection states.
+-   `diag_display`'s `virtual_lines{current_line=true}` reveals the diagnostic
+-   (cursor parked on the term's line). A no-`emit_definition` response leaves no
+-   footnote reference/footer.
++   `diag_display`'s Parley-owned left-column virtual-line display reveals the
++   diagnostic (cursor parked on the term's line). A no-`emit_definition` response
++   leaves no footnote reference/footer.
+
+ ## Undo (`u`) — reuses review's projection
+
+ Native `u` reverts *text*, not decorations. The footnote reference/footer rewrite
+ is the one text change, so `u` reverts it; the decorations are cleared/restored by review's
+ **projection watcher** (`skills/review/projection.lua`, #133 M5), which define
+ reuses: `render_definition` calls `projection.record_empty_for(buf, original)`
+ (pre-footnote hash → empty snapshot), `record(buf)` (footnoted hash → the
+ highlight + diagnostic), `ensure_watch(buf)`. Undoing the footnote edit lands on
+ the pre-footnote content-hash → the empty snapshot renders → both decorations clear;
+ `<C-r>` re-renders. `skill_render.snapshot`/`apply_snapshot` preserve span
+ highlights (`hl_spans`) and diagnostic `col`/`end_col`, while still accepting
+ legacy whole-line `hl_lines`. `set_applying` guards the edit so a prior define's
+ watcher doesn't mistake it for a user edit.
+
+ ## Pure core vs IO shell (ARCH-PURE)
+
+ - **Pure** (`lua/parley/define.lua`, unit-tested with plain tables): `slice_selection`,
+   `context_for_selection`, `format_definition`, `bracket_edit` (plans the `[term]`
+   wrap as a legacy set_lines edit), `diagnostic_span_after_bracket` (legacy range
+   mapping), `apply_definition_footnote` (durable footer transform), and
+   `strip_definition_footnote_footer` / `footnote_diagnostics` (read only a final
+   `---` block followed solely by footnotes).
+ - **IO shell** (`lua/parley/init.lua`): `define_visual`, `render_definition`;
+   `lua/parley/buffer_edit.lua` owns the full-buffer footnote rewrite;
+   `lua/parley/skill_render.lua` publishes footnote diagnostics; and
+   `lua/parley/highlighter.lua` refreshes them from chat and markdown lifecycle
+   hooks.
+ - **External service** (Anthropic) exercised via the process-level fake reused
+   from `skill_invoke_spec` (SSE tool-call injection).
+
+ ## Managed Footnote Footer
+
+ The footer is a final markdown block:
+
+ ```markdown
+ ---
+
+ [^asin]: Amazon Standard Identification Number.
+ ```
+
+ The footer detector is deliberately conservative: only the last standalone
+ `---` line followed by blank lines and footnote definitions counts as the
+ managed footer. Ordinary horizontal rules and mixed prose after `---` remain
+ chat content. `chat_respond.build_messages` strips this managed footer from
+ message strings before LLM submission, so durable definitions do not become
+ prompt context. `define.footnote_diagnostics` uses the same footer detector to
+ scan inline references before the footer and produce diagnostics for each
+ matching `[^id]`.
+
+ ## Keybinding
+
+ `<M-CR>` was split out of `chat_shortcut_respond` into its own `chat_define`
+ registry entry (a single registry entry maps every key×mode to one per-mode
+ callback, so the split can't live inside `chat_respond`). The `chat_define`
+ per-mode callback is `{ n=respond, i=respond, v=define_visual, x=define_visual }`
+ — visual `<M-CR>` defines; normal/insert `<M-CR>` still responds; visual
+ `<C-g><C-g>` keeps the line-scoped resubmit. The v/x callbacks `<Esc>`-commit
+ the `'<`/`'>` marks before reading `getpos`.
+
+ ## Read-only invoke seam (`opts.no_reload`)
+
+ `skill_invoke.invoke` normally writes the buffer before the turn and `:edit!`-
+ reloads it after (for `propose_edits`). A read-only lookup passes
+ `opts.no_reload = true` to skip both, so an in-progress prompt is never
+ persisted. `opts.document` lets the caller send a bounded context instead of the
+ whole buffer. Both default to prior behavior when absent.
+
+ ## Structured output tool
+
+ `emit_definition` (`lua/parley/tools/builtin/emit_definition.lua`, in
+ `BUILTIN_NAMES`) is an **output-only** tool: `{term, definition}` schema,
+ `self_paginates = true` (no pager params), no-op `handler`. The value rides the
+ tool-call args (`result.calls[1].input`), read in `on_done`.
+
+ ## Notes
+
+ - The fresh define highlight spans the selected text plus immediate `[^id]`
+   reference; rehydrated diagnostics do not recreate the DiffChange highlight.
+ - `skill_render.refresh_footnote_diagnostics` owns only diagnostics tagged
+   `parley-footnote` and preserves other `parley_skill` diagnostics, so review
+   diagnostics are not cleared by markdown footnote refresh.
+-- A diagnostic's `virtual_lines` auto-hide when the cursor leaves its line. The
+-  footnote persists in the file if saved.
++- A diagnostic's Parley virtual-line block auto-hides when the cursor leaves its
++  line. The footnote persists in the file if saved.
+
+ ## Key files
+
+ - `lua/parley/define.lua` — pure core (slice / context / format / footnote footer / diagnostics).
+ - `lua/parley/init.lua` — `define_visual`, `render_definition`, `chat_define` wiring.
+ - `lua/parley/highlighter.lua` — chat/markdown buffer lifecycle refresh hooks.
+ - `lua/parley/skill_render.lua` — footnote diagnostic refresh in the shared namespace.
+ - `lua/parley/chat_respond.lua` — strips managed footnote footer from LLM messages.
+ - `lua/parley/skills/define/init.lua` — the unforced `define` skill.
+ - `lua/parley/tools/builtin/emit_definition.lua` — output-only structured tool.
+ - `lua/parley/skill_invoke.lua` — `opts.no_reload` / `opts.document` seams.
+ - `lua/parley/config.lua`, `lua/parley/keybinding_registry.lua` — the `<M-CR>` split.
+ - `tests/unit/define_spec.lua`, `tests/integration/define_spec.lua` — coverage.
+
+ ## Related
+
+ - [Drill-In Markers](drill_in.md) — the heavier "gather into the next turn"
+   sibling; shares `define.slice_selection` for the visual-selection extraction.
+ - [Document Review](../modes/review.md) — the skill/`skill_invoke`/`diag_display`
+   machinery this reuses.
+diff --git a/atlas/modes/review.md b/atlas/modes/review.md
+index b470783..ef656df 100644
+--- a/atlas/modes/review.md
++++ b/atlas/modes/review.md
+@@ -105,112 +105,116 @@ mode.directives(flags) ⊕ operator-instruction`. No mode selected → base SKIL
+   editorial-sequence position that orders the menu (developmental=1 … free-form=6).
+ - **Six shipped modes:** developmental, line-editing, copy-editing, proofreading,
+   fact-check (inserts `🤖{}` findings only — no edits; resolution handed to the
+   main agent), free-form (operator instruction governs).
+ - **`ctx.skill_dir` injection** (`skill_providers.lua`): the disk provider injects
+   the skill's own absolute dir into `source(ctx)` (alongside `ctx.skill_md`) so the
+   review skill reads its `modes/` subdir without re-deriving the path.
+
+ ## Journal (#133 M3)
+
+ Each review round is recorded to a **self-contained markdown sidecar** beside the
+ doc — `<doc>.parley-journal.md` — tracked in git WITH the document. This replaces
+ docflow's git-branch journaling: docflow's *value* (attributed per-round diffs +
+ rationale) without its branch *mechanism* (no working-tree churn, portable to a
+ standalone plugin install). vim's native undo owns in-session text time-travel;
+ the journal owns the durable, cross-session record.
+
+ - **`lua/parley/skills/review/journal.lua`** — PURE `serialize_entry` /
+   `serialize_base` / `parse` / `diff` (`vim.diff`, unified) / `is_drift`
+   (`vim.fn.sha256` compare), plus the thin IO seam `sidecar_path` / `read` /
+   `append`. 4-backtick fences wrap the journal's own blocks so a 3-backtick code
+   fence inside the doc or diff can't break parsing.
+ - **Per round** it stores: round number (derived), mode, side, ISO timestamp,
+   content hash, rationale (the per-edit `explain`s), and the unified diff. Round 0
+   is the base snapshot (written once, on the first round).
+ - **Wiring**: `skill_invoke`'s `on_done` payload carries `original` /
+   `new_content` / `decorations` (pure-fed); review's `on_done` builds the entry
+   and calls `journal.append` (skips no-op rounds + path-less buffers).
+ - **Drift**: `is_drift(recorded_hash, current)` detects an external edit (e.g.
+   Claude Code resolving markers) since the last recorded round.
+ - **Deferred (v2)**: durable "revert/show round N" (reconstruct via base +
+   replayed diffs). The journal stores the **diff + rationale** per round (not a
+   structured decoration set — see the plan's Revisions).
+
+ ## Decoration projection — undo/redo coherence (#133 M5)
+
+ nvim's undo reverts **text only**; review decorations are drawn once per round
+ and otherwise ride, so without help they go stale after an undo (esp. across the
+ round's `:edit!` reload). `lua/parley/skills/review/projection.lua` keeps style
+ coherent: a per-buffer record `{ content-hash → decoration snapshot }`, and on
+ each text change it **projects** the right style onto the current state —
+
+ - **undo/redo** lands on a recorded content-hash → re-render that snapshot (via
+   `skill_render.snapshot`/`apply_snapshot`);
+ - a **novel forward edit** (manual tweak / `<M-a>` accept — behavior B) keeps the
+   live decorations riding, and snapshots them under the new state so a later undo
+   restores them.
+
+ A round records its **pre** state (base → empty style, so undoing across the
+ round clears it) and its **post** state (its decorations); records persist across
+ rounds for multi-round undo. `set_applying` suppresses the watcher during the
+ round's own reload; the watcher is attached lazily (only after the first round).
+ The decide rule (`projection.decide`) is pure. Session-scoped (matches nvim's
+ session-scoped undo); per-state snapshots aren't journaled.
+
+ ## Diagnostic display (#133 M6)
+
+ The edit "why" (the per-edit `explain`) is an INFO diagnostic on parley's
+ `parley_skill` namespace. `lua/parley/skills/review/diag_display.lua` controls how
+ it shows — scoped to that namespace, so the user's LSP/global diagnostics are
+-untouched. Default **on**: `virtual_lines { current_line = true }`, so the
+-(hard-wrapped, via `skill_render.format_diagnostic_message`) why **auto-expands
+-below an edit when the cursor is in that edit's region** (`attach_diagnostics` spans `lnum..end_lnum`)
+-and hides otherwise. `:ParleyShowDiagnostics` toggles it. The built-in `]d`/`[d`
+-(jump) and `<C-W>d` (float, wraps) also work on these diagnostics. Composes with
+-M5 — re-renders on undo/redo.
++untouched. Default **on**: Parley's custom `parley/virtual_lines` diagnostic
++handler renders a left-column virtual-line block headed `Diagnostics:` for the
++current line. It avoids Neovim's stock virtual-lines indentation-by-diagnostic
++column, which can hide messages on long wrapped prose. The hard-wrapped why
++(`skill_render.format_diagnostic_message`) **auto-expands below an edit when the
++cursor is in that edit's region** (`attach_diagnostics` spans
++`lnum..end_lnum`) and hides otherwise. `:ParleyShowDiagnostics` toggles it. The
++built-in `]d`/`[d` (jump) and `<C-W>d` (float, wraps) still work on these
++diagnostics because the underlying diagnostic spans remain unchanged. Composes
++with M5 — re-renders on undo/redo.
+
+ ## Progress bar (#133 M7)
+
+ A review round is headless and takes ~30s, so it shows a **detached progress
+ bar** — `lua/parley/progress.lua`, a floating bar pinned just above the
+ statusline with an animated spinner + message + elapsed seconds. It's a **general
+ reusable mechanism** (`progress.start/update/stop/is_active`, one active at a
+ time; pure `frame`/`format` + thin float/timer IO), not review-specific — review
+ is just its first user. `skill_invoke` starts it when the LLM query launches and
+ stops it on exit/abort/cancel (guarded by the same generation counter as the
+ in-flight cancel). Concurrency: triggering a review while one runs gives the
+ kill-or-cancel prompt (no two concurrent rounds).
+
+ ## Config
+
+ ```lua
+ review_agent = "",              -- agent name (deprecated; use skills config)
+ review_highlight_duration = 2000, -- highlight fade time in ms
+ review_shortcut_edit   = { modes = { "n" }, shortcut = "<C-g>ve" },
+ review_shortcut_finder = { modes = { "n", "i" }, shortcut = "<C-g>vf" },
+ review_shortcut_menu   = { modes = { "n" }, shortcut = "<M-o>" },   -- skill picker (#133)
+ review_shortcut_next   = { modes = { "n", "i" }, shortcut = "<M-CR>" }, -- review-mode menu (#133)
+ -- Marker insertion: see drill_in_callbacks in lua/parley/init.lua
+ -- (shared <M-q> / <C-g>q binding)
+ ```
+
+ ## Key Files
+
+ - `lua/parley/skills/review/init.lua` — skill definition (+ `source(ctx)` mode composition, `mode` arg), marker parsing, `run_via_invoke` (marker pre-check + resubmit), keybindings
+ - `lua/parley/skills/review/mode.lua` — Mode parse/directives (PURE) + load/list IO seam (#133)
+ - `lua/parley/skills/review/modes/*.md` — the six review-mode prompt files (#133)
+ - `lua/parley/skills/review/journal.lua` — per-round journal: PURE serialize/parse/diff/drift + sidecar IO seam (#133)
+ - `lua/parley/review_menu.lua` — composite review-mode menu (selector + instruction editor); `<M-CR>` (#133)
+ - `lua/parley/skills/review/projection.lua` — decoration projection: re-render style on undo/redo per content-state (#133 M5)
+ - `lua/parley/skills/review/diag_display.lua` — inline "why" display toggle (`:ParleyShowDiagnostics`, cursor-region auto-show) (#133 M6)
+ - `lua/parley/progress.lua` — detached progress bar (general reusable long-op feedback; review is the first user) (#133 M7)
+ - `lua/parley/skills/review/SKILL.md` — system prompt (light edit + heavy revision sections)
+ - `lua/parley/skill_invoke.lua` — the P2 driver (one tool-use exchange via the existing dispatcher)
+ - `lua/parley/skill_render.lua` — diagnostics + edit highlights
+ - `lua/parley/tools/builtin/propose_edits.lua` — batch edit-apply (inline `.parley-backup`)
+ - `lua/parley/review.lua` — backward-compatible shim
+ - `lua/parley/highlighter.lua` — `ParleyReviewUser`/`ParleyReviewAgent` groups
+ - `lua/parley/config.lua` — default keybindings and config
+ - `tests/unit/review_spec.lua` — unit tests for the marker parser
+ - `tests/integration/skill_invoke_review_spec.lua` — review's marker pre-check + resubmit
+ - `tests/unit/skill_edits_spec.lua` / `tests/unit/tools_builtin_propose_edits_spec.lua` — batch edit-apply
+diff --git a/workshop/issues/000173-diagnostic-virtual-lines-leftcol.md b/workshop/issues/000173-diagnostic-virtual-lines-leftcol.md
+index 5feffd6..0795f4a 100644
+--- a/workshop/issues/000173-diagnostic-virtual-lines-leftcol.md
++++ b/workshop/issues/000173-diagnostic-virtual-lines-leftcol.md
+@@ -1,28 +1,92 @@
+ ---
+ id: 000173
+ status: working
+ deps: []
+ github_issue:
+ created: 2026-07-08
+ updated: 2026-07-08
+-estimate_hours:
++estimate_hours: 0.38
+ started: 2026-07-08T13:21:02-07:00
+ ---
+
+ # diagnostic virtual lines blank on long wrapped markdown
+
+ ## Problem
+
++After #172, managed markdown footnotes are correctly restored as diagnostics,
++but their inline virtual-line display can look blank on long wrapped markdown
++paragraphs. The diagnostic payload is present and floats display it, but
++Neovim's built-in `virtual_lines` handler prefixes the rendered message with
++spaces equal to the diagnostic byte column. On a long prose line, the selected
++text may be visible on a wrapped screen row while the virtual-line message starts
++far to the right outside the viewport.
++
+ ## Spec
+
++- Parley diagnostics should remain anchored on the selected text / `[^footnote]`
++  span so signs, underline, cursor-line filtering, jumps, and floats keep their
++  existing behavior.
++- The inline diagnostic display for Parley's namespace should render current-line
++  messages from the left column, not from the diagnostic byte column.
++- The display text should keep the existing wrapped diagnostic message and a
++  clear `Diagnostics:` label.
++- The fix should apply to the shared Parley diagnostic namespace, covering review
++  diagnostics and footnote diagnostics without changing global/LSP diagnostics.
++
++ARCH-DRY: keep one Parley diagnostic display controller in
++`skills/review/diag_display.lua`; do not add a separate footnote-only renderer.
++ARCH-PURE: no parser/data changes; keep the change in the thin Neovim display
++shell and test its extmark output directly.
++ARCH-PURPOSE: solve the actual blank-row symptom for long wrapped markdown, not
++only color the hidden text.
++
+ ## Done when
+
+--
++- A Parley diagnostic on a long line with a high column renders a visible
++  left-column virtual line.
++- The diagnostic itself remains at its original span for underline/float/jump
++  behavior.
++- Toggling `:ParleyShowDiagnostics` still disables/enables the inline display.
++- Focused tests and full verification pass.
++
++## Estimate
++
++Produced via `estimate-logic-v3.1` against the repo-local calibration source
++reported by `sdlc estimate-source` (stale but canonical for this repo).
++
++```estimate
++model: estimate-logic-v3.1
++familiarity: 1.0
++item: issue-spec design=0.04 impl=0.00
++item: lua-neovim design=0.06 impl=0.18
++item: milestone-review design=0.00 impl=0.10
++total: 0.38
++```
+
+ ## Plan
+
+-- [ ]
++- [x] Add failing tests proving Parley virtual lines render from the left column.
++- [x] Implement the Parley-owned virtual-line display handler.
++- [x] Update atlas/issue log and run verification.
+
+ ## Log
+
+ ### 2026-07-08
++- Root cause: a headless reproduction of Neovim's stock diagnostic virtual-lines
++  handler showed `virt_lines = { { { string.rep(" ", diagnostic.col), "" }, ... } }`
++  with `virt_lines_overflow = "scroll"`, so long wrapped markdown can display a
++  blank inserted row while the message starts outside the viewport.
++- Red test: `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"`
++  failed because `diag_display` still configured stock `virtual_lines` and no
++  `parley_diagnostic_virtual_lines` extmark was rendered.
++- Implemented `parley/virtual_lines`, a custom diagnostic handler scoped to the
++  Parley namespace. It renders a left-column `Diagnostics:` virtual-line block,
++  updates on `CursorMoved`, disables stock virtual lines for Parley, and leaves
++  the underlying diagnostic span unchanged.
++- Focused green: `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"`.
++- Final green: `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`;
++  `git diff --check -- lua/parley/skills/review/diag_display.lua
++  tests/integration/review_diag_display_spec.lua atlas/modes/review.md
++  atlas/chat/inline_define.md
++  workshop/issues/000173-diagnostic-virtual-lines-leftcol.md
++  workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md`; `make test`.
+diff --git a/workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md b/workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md
+new file mode 100644
+index 0000000..12f0951
+--- /dev/null
++++ b/workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md
+@@ -0,0 +1,94 @@
++# Diagnostic Virtual Lines Left Column Implementation Plan
++
++> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.
++
++**Goal:** Make Parley's inline diagnostic display visible on long wrapped markdown lines by rendering diagnostic virtual lines from the left column.
++
++**Architecture:** Keep diagnostic data unchanged: spans stay anchored to selected text and footnote references. Replace only Parley's namespace display shell in `diag_display.lua`, so global/LSP diagnostics still use Neovim defaults. This follows ARCH-DRY by keeping one Parley display controller and ARCH-PURE by avoiding parser/data changes.
++
++**Tech Stack:** Lua, Neovim diagnostics, extmarks, Plenary/Busted tests.
++
++---
++
++## Core Concepts
++
++### Pure Entities
++
++| Name | Lives in | Status |
++|------|----------|--------|
++| `ParleyDiagnosticMessageLines` | `lua/parley/skills/review/diag_display.lua` | new |
++
++- **ParleyDiagnosticMessageLines** — deterministic conversion from a diagnostic message string into visible virtual-line rows with a `Diagnostics:` header.
++  - **Relationships:** 1:N from one diagnostic message to display rows.
++  - **DRY rationale:** Both review diagnostics and footnote diagnostics consume the same Parley namespace display.
++  - **Future extensions:** If Parley later adds source-specific labels, this formatter is the one place to widen.
++
++### Integration Points
++
++| Name | Lives in | Status | Wraps |
++|------|----------|--------|-------|
++| `ParleyDiagnosticVirtualLines` | `lua/parley/skills/review/diag_display.lua` | modified | Neovim extmarks |
++
++- **ParleyDiagnosticVirtualLines** — Parley-owned inline diagnostic renderer scoped to `skill_render.diag_namespace()`.
++  - **Injected into:** `diag_display.set(on)`; toggling still owns all inline display setup.
++  - **Future extensions:** Can add color overrides without changing diagnostic producers.
++
++## Chunk 1: Left-Column Renderer
++
++**Files:**
++- Modify: `lua/parley/skills/review/diag_display.lua`
++- Modify: `tests/integration/review_diag_display_spec.lua`
++- Modify: `atlas/modes/review.md`
++- Modify: `atlas/chat/inline_define.md`
++- Modify: `workshop/issues/000173-diagnostic-virtual-lines-leftcol.md`
++
++- [x] **Step 1: Write failing tests**
++
++Add integration coverage that:
++- Sets a Parley diagnostic at a high column on a long line.
++- Enables `diag_display`.
++- Asserts the generated display extmark has `virt_lines_leftcol = true`.
++- Asserts the first virtual-line chunk is `Diagnostics:` instead of leading spaces.
++- Asserts `dd.set(false)` clears the Parley display extmark while leaving the diagnostic data intact.
++
++Run:
++
++```bash
++nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"
++```
++
++Expected: FAIL because the stock diagnostic handler emits leading-space virtual lines and `diag_display` has no custom extmark namespace.
++
++- [x] **Step 2: Implement the renderer**
++
++In `lua/parley/skills/review/diag_display.lua`:
++- Add a private display namespace.
++- Add a private function that clears Parley diagnostic virtual-line extmarks.
++- Add a private render function that reads diagnostics from `skill_render.diag_namespace()`, filters to the current cursor line, and writes `virt_lines` with `virt_lines_leftcol = true`.
++- Configure Neovim diagnostics for the Parley namespace with `virtual_lines = false`, `virtual_text = false`, and existing signs/underline behavior.
++- Register a buffer-local `CursorMoved` autocmd for visible Parley buffers so current-line behavior keeps updating.
++
++- [x] **Step 3: Run green focused tests**
++
++Run:
++
++```bash
++nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"
++```
++
++Expected: PASS.
++
++- [x] **Step 4: Update docs and issue log**
++
++Update atlas text that says Parley uses built-in diagnostic `virtual_lines` so it instead describes the Parley-owned left-column inline renderer. Record red/green evidence in the issue log and tick plan items.
++
++- [x] **Step 5: Final verification**
++
++Run:
++
++```bash
++git diff --check -- lua/parley/skills/review/diag_display.lua tests/integration/review_diag_display_spec.lua atlas/modes/review.md atlas/chat/inline_define.md workshop/issues/000173-diagnostic-virtual-lines-leftcol.md workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md
++make test
++```
++
++Expected: all pass.
+
+exec
+/bin/zsh -lc 'rg -n "ShowDiagnostics|Diagnostics:|virtual[-_ ]lines|diagnostic" README.md atlas lua/parley/skills/review/diag_display.lua lua/parley/skill_render.lua workshop/issues/000173-diagnostic-virtual-lines-leftcol.md workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md' in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:12:# diagnostic virtual lines blank on long wrapped markdown
+workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:16:After #172, managed markdown footnotes are correctly restored as diagnostics,
+workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:18:paragraphs. The diagnostic payload is present and floats display it, but
+workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:19:Neovim's built-in `virtual_lines` handler prefixes the rendered message with
+workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:20:spaces equal to the diagnostic byte column. On a long prose line, the selected
+workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:26:- Parley diagnostics should remain anchored on the selected text / `[^footnote]`
+workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:29:- The inline diagnostic display for Parley's namespace should render current-line
+workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:30:  messages from the left column, not from the diagnostic byte column.
+workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:31:- The display text should keep the existing wrapped diagnostic message and a
+workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:32:  clear `Diagnostics:` label.
+workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:33:- The fix should apply to the shared Parley diagnostic namespace, covering review
+workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:34:  diagnostics and footnote diagnostics without changing global/LSP diagnostics.
+workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:36:ARCH-DRY: keep one Parley diagnostic display controller in
+workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:45:- A Parley diagnostic on a long line with a high column renders a visible
+workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:47:- The diagnostic itself remains at its original span for underline/float/jump
+workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:49:- Toggling `:ParleyShowDiagnostics` still disables/enables the inline display.
+workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:68:- [x] Add failing tests proving Parley virtual lines render from the left column.
+workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:75:- Root cause: a headless reproduction of Neovim's stock diagnostic virtual-lines
+workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:76:  handler showed `virt_lines = { { { string.rep(" ", diagnostic.col), "" }, ... } }`
+workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:80:  failed because `diag_display` still configured stock `virtual_lines` and no
+workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:81:  `parley_diagnostic_virtual_lines` extmark was rendered.
+workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:82:- Implemented `parley/virtual_lines`, a custom diagnostic handler scoped to the
+workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:83:  Parley namespace. It renders a left-column `Diagnostics:` virtual-line block,
+workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:84:  updates on `CursorMoved`, disables stock virtual lines for Parley, and leaves
+workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:85:  the underlying diagnostic span unchanged.
+workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:91:  workshop/issues/000173-diagnostic-virtual-lines-leftcol.md
+workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:92:  workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md`; `make test`.
+workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:5:**Goal:** Make Parley's inline diagnostic display visible on long wrapped markdown lines by rendering diagnostic virtual lines from the left column.
+workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:7:**Architecture:** Keep diagnostic data unchanged: spans stay anchored to selected text and footnote references. Replace only Parley's namespace display shell in `diag_display.lua`, so global/LSP diagnostics still use Neovim defaults. This follows ARCH-DRY by keeping one Parley display controller and ARCH-PURE by avoiding parser/data changes.
+workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:9:**Tech Stack:** Lua, Neovim diagnostics, extmarks, Plenary/Busted tests.
+workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:21:- **ParleyDiagnosticMessageLines** — deterministic conversion from a diagnostic message string into visible virtual-line rows with a `Diagnostics:` header.
+workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:22:  - **Relationships:** 1:N from one diagnostic message to display rows.
+workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:23:  - **DRY rationale:** Both review diagnostics and footnote diagnostics consume the same Parley namespace display.
+workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:32:- **ParleyDiagnosticVirtualLines** — Parley-owned inline diagnostic renderer scoped to `skill_render.diag_namespace()`.
+workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:34:  - **Future extensions:** Can add color overrides without changing diagnostic producers.
+workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:43:- Modify: `workshop/issues/000173-diagnostic-virtual-lines-leftcol.md`
+workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:48:- Sets a Parley diagnostic at a high column on a long line.
+workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:51:- Asserts the first virtual-line chunk is `Diagnostics:` instead of leading spaces.
+workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:52:- Asserts `dd.set(false)` clears the Parley display extmark while leaving the diagnostic data intact.
+workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:60:Expected: FAIL because the stock diagnostic handler emits leading-space virtual lines and `diag_display` has no custom extmark namespace.
+workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:66:- Add a private function that clears Parley diagnostic virtual-line extmarks.
+workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:67:- Add a private render function that reads diagnostics from `skill_render.diag_namespace()`, filters to the current cursor line, and writes `virt_lines` with `virt_lines_leftcol = true`.
+workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:68:- Configure Neovim diagnostics for the Parley namespace with `virtual_lines = false`, `virtual_text = false`, and existing signs/underline behavior.
+workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:83:Update atlas text that says Parley uses built-in diagnostic `virtual_lines` so it instead describes the Parley-owned left-column inline renderer. Record red/green evidence in the issue log and tick plan items.
+workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:90:git diff --check -- lua/parley/skills/review/diag_display.lua tests/integration/review_diag_display_spec.lua atlas/modes/review.md atlas/chat/inline_define.md workshop/issues/000173-diagnostic-virtual-lines-leftcol.md workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md
+lua/parley/skills/review/diag_display.lua:1:-- diag_display.lua — inline display of review "why" diagnostics (#133 M6).
+lua/parley/skills/review/diag_display.lua:4:-- diagnostic namespace (never touches the user's LSP / global diagnostics).
+lua/parley/skills/review/diag_display.lua:5:-- Default ON: `virtual_lines { current_line = true }`, so the (hard-wrapped) why
+lua/parley/skills/review/diag_display.lua:7:-- otherwise. `:ParleyShowDiagnostics` toggles it.
+lua/parley/skills/review/diag_display.lua:13:local HANDLER_NAME = "parley/virtual_lines"
+lua/parley/skills/review/diag_display.lua:14:local DISPLAY_NS = "parley_diagnostic_virtual_lines"
+lua/parley/skills/review/diag_display.lua:15:local DISPLAY_AUGROUP = "parley_diagnostic_virtual_lines"
+lua/parley/skills/review/diag_display.lua:22:-- Parley's review diagnostic namespace — single-sourced from skill_render (which
+lua/parley/skills/review/diag_display.lua:54:local function diagnostic_message_lines(diagnostic)
+lua/parley/skills/review/diag_display.lua:56:    for _, line in ipairs(vim.split(tostring(diagnostic.message or ""), "\n", { plain = true })) do
+lua/parley/skills/review/diag_display.lua:65:local function render(buf, diagnostics, current_line_only)
+lua/parley/skills/review/diag_display.lua:78:    for _, diagnostic in ipairs(diagnostics or {}) do
+lua/parley/skills/review/diag_display.lua:79:        if not current_line_only or diagnostic.lnum == line then
+lua/parley/skills/review/diag_display.lua:80:            by_line[diagnostic.lnum] = by_line[diagnostic.lnum] or {}
+lua/parley/skills/review/diag_display.lua:81:            table.insert(by_line[diagnostic.lnum], diagnostic)
+lua/parley/skills/review/diag_display.lua:85:    for lnum, line_diagnostics in pairs(by_line) do
+lua/parley/skills/review/diag_display.lua:86:        table.sort(line_diagnostics, function(a, b)
+lua/parley/skills/review/diag_display.lua:89:        local virt_lines = { { { "Diagnostics:", HEADER_HL } } }
+lua/parley/skills/review/diag_display.lua:90:        for _, diagnostic in ipairs(line_diagnostics) do
+lua/parley/skills/review/diag_display.lua:91:            vim.list_extend(virt_lines, diagnostic_message_lines(diagnostic))
+lua/parley/skills/review/diag_display.lua:103:    vim.diagnostic.handlers[HANDLER_NAME] = {
+lua/parley/skills/review/diag_display.lua:104:        show = function(namespace, bufnr, diagnostics, opts)
+lua/parley/skills/review/diag_display.lua:117:                        render(bufnr, diagnostics, true)
+lua/parley/skills/review/diag_display.lua:121:            render(bufnr, diagnostics, current_line_only)
+lua/parley/skills/review/diag_display.lua:137:    render(buf, vim.diagnostic.get(buf, { namespace = ns() }), true)
+lua/parley/skills/review/diag_display.lua:145:    vim.diagnostic.config({
+lua/parley/skills/review/diag_display.lua:147:        virtual_lines = false,
+lua/parley/skill_render.lua:3:-- The diagnostics/highlights rendering salvaged out of skill_runner (#128 M3),
+lua/parley/skill_render.lua:5:-- deleted in M4). Thin vim-API/UI wrapper (not pure): INFO diagnostics from each
+lua/parley/skill_render.lua:26:--- Clear previous skill diagnostics and highlights from a buffer.
+lua/parley/skill_render.lua:29:    vim.diagnostic.reset(diag_ns_id, buf)
+lua/parley/skill_render.lua:38:--- The review diagnostic namespace id — the single source other modules
+lua/parley/skill_render.lua:47:--- existing newlines. PURE. Lets `virtual_lines` render a long "why" as multiple
+lua/parley/skill_render.lua:77:-- Usable wrap width for the virtual_lines "why": the window's text columns
+lua/parley/skill_render.lua:80:-- fixed 76 overflowed the indented virtual_lines and truncated the right edge
+lua/parley/skill_render.lua:92:--- Current usable wrap width for Parley diagnostic virtual lines.
+lua/parley/skill_render.lua:94:function M.diagnostic_wrap_width()
+lua/parley/skill_render.lua:98:--- Format a diagnostic message for Neovim virtual_lines display.
+lua/parley/skill_render.lua:100:--- @param width number|nil default current diagnostic display width
+lua/parley/skill_render.lua:102:function M.format_diagnostic_message(text, width)
+lua/parley/skill_render.lua:103:    return M.wrap(text, width or M.diagnostic_wrap_width())
+lua/parley/skill_render.lua:106:local function is_footnote_diagnostic(diagnostic)
+lua/parley/skill_render.lua:107:    local user_data = diagnostic.user_data or {}
+lua/parley/skill_render.lua:108:    return diagnostic.source == FOOTNOTE_SOURCE or user_data.parley_kind == "footnote"
+lua/parley/skill_render.lua:111:--- Rehydrate persisted managed markdown footnotes into Parley diagnostics.
+lua/parley/skill_render.lua:112:--- Existing non-footnote diagnostics in the shared namespace are preserved.
+lua/parley/skill_render.lua:114:function M.refresh_footnote_diagnostics(buf)
+lua/parley/skill_render.lua:123:    local width = M.diagnostic_wrap_width()
+lua/parley/skill_render.lua:124:    local diagnostics = {}
+lua/parley/skill_render.lua:126:    for _, existing in ipairs(vim.diagnostic.get(buf, { namespace = diag_ns_id })) do
+lua/parley/skill_render.lua:127:        if not is_footnote_diagnostic(existing) then
+lua/parley/skill_render.lua:128:            table.insert(diagnostics, existing)
+lua/parley/skill_render.lua:132:    for _, footnote in ipairs(define.footnote_diagnostics(lines)) do
+lua/parley/skill_render.lua:133:        table.insert(diagnostics, {
+lua/parley/skill_render.lua:139:            severity = vim.diagnostic.severity.INFO,
+lua/parley/skill_render.lua:145:    vim.diagnostic.set(diag_ns_id, buf, diagnostics)
+lua/parley/skill_render.lua:148:--- Attach INFO diagnostics from edit explanations. Each diagnostic spans the
+lua/parley/skill_render.lua:150:--- message is hard-wrapped to the window's usable width for `virtual_lines`
+lua/parley/skill_render.lua:155:function M.attach_diagnostics(buf, edits, original_content)
+lua/parley/skill_render.lua:157:    local width = M.diagnostic_wrap_width()
+lua/parley/skill_render.lua:158:    local diagnostics = {}
+lua/parley/skill_render.lua:170:        table.insert(diagnostics, {
+lua/parley/skill_render.lua:174:            message = M.format_diagnostic_message(edit.explain or "edit applied", width),
+lua/parley/skill_render.lua:175:            severity = vim.diagnostic.severity.INFO,
+lua/parley/skill_render.lua:179:    vim.diagnostic.set(diag_ns_id, buf, diagnostics)
+lua/parley/skill_render.lua:191:        -- INFO gutter diagnostic (the "why") via attach_diagnostics, not a
+lua/parley/skill_render.lua:248:--- highlights and diagnostics preserve columns so exact anchors can be restored.
+lua/parley/skill_render.lua:268:    for _, d in ipairs(vim.diagnostic.get(buf, { namespace = diag_ns_id })) do
+lua/parley/skill_render.lua:296:        local diagnostics = {}
+lua/parley/skill_render.lua:298:            table.insert(diagnostics, {
+lua/parley/skill_render.lua:304:                severity = vim.diagnostic.severity.INFO,
+lua/parley/skill_render.lua:309:        vim.diagnostic.set(diag_ns_id, buf, diagnostics)
+atlas/skills/skill-system.md:44:- `lua/parley/skill_render.lua` — the single source of `clear_decorations`/`attach_diagnostics`/`highlight_edits` (salvaged from `skill_runner`).
+atlas/skills/skill-system.md:51:- `lua/parley/skill_runner.lua` **deleted**; `review.lua`'s v1 edit/diagnostic re-exports and `review/init.lua`'s dead `pre_submit`/`post_apply`/`system_prompt` removed.
+atlas/skills/skill-system.md:118:- `lua/parley/skill_render.lua` — diagnostics/highlights (single source; was salvaged from skill_runner)
+atlas/index.md:15:- [Inline Term Definition](chat/inline_define.md): Visual-select a phrase + `<M-CR>` → concise context-aware definition as a managed footnote diagnostic rehydrated for markdown buffers (the `define` skill + `emit_definition` tool; honors `:ToggleWebSearch`).
+atlas/traceability.yaml:426:      - lua/parley/timezone_diagnostics.lua
+atlas/traceability.yaml:430:      - tests/unit/timezone_diagnostics_spec.lua
+atlas/providers/tool_use.md:72:- **Buffer diagnostic**: `:lua require('parley').check_buffer()` validates invariants
+atlas/chat/inline_define.md:4:concise, context-aware definition appears as an inline diagnostic under the
+atlas/chat/inline_define.md:8:diagnostics when any markdown buffer is entered or refreshed. The whole new
+atlas/chat/inline_define.md:14:made the definition durable as a managed footnote; [#167](../../workshop/issues/000167-define-diagnostic-highlight-span.md)
+atlas/chat/inline_define.md:16:[#172](../../workshop/issues/000172-markdown-footnote-diagnostics.md)
+atlas/chat/inline_define.md:39:   footnote diagnostics (`skill_render.refresh_footnote_diagnostics`), which
+atlas/chat/inline_define.md:40:   parses the managed footer and sets INFO `vim.diagnostic` entries on matching
+atlas/chat/inline_define.md:42:   `skill_render.format_diagnostic_message`) on the `parley_skill` namespace;
+atlas/chat/inline_define.md:45:   diagnostic (cursor parked on the term's line). A no-`emit_definition` response
+atlas/chat/inline_define.md:55:highlight + diagnostic), `ensure_watch(buf)`. Undoing the footnote edit lands on
+atlas/chat/inline_define.md:58:highlights (`hl_spans`) and diagnostic `col`/`end_col`, while still accepting
+atlas/chat/inline_define.md:66:  wrap as a legacy set_lines edit), `diagnostic_span_after_bracket` (legacy range
+atlas/chat/inline_define.md:68:  `strip_definition_footnote_footer` / `footnote_diagnostics` (read only a final
+atlas/chat/inline_define.md:72:  `lua/parley/skill_render.lua` publishes footnote diagnostics; and
+atlas/chat/inline_define.md:93:prompt context. `define.footnote_diagnostics` uses the same footer detector to
+atlas/chat/inline_define.md:94:scan inline references before the footer and produce diagnostics for each
+atlas/chat/inline_define.md:125:  reference; rehydrated diagnostics do not recreate the DiffChange highlight.
+atlas/chat/inline_define.md:126:- `skill_render.refresh_footnote_diagnostics` owns only diagnostics tagged
+atlas/chat/inline_define.md:127:  `parley-footnote` and preserves other `parley_skill` diagnostics, so review
+atlas/chat/inline_define.md:128:  diagnostics are not cleared by markdown footnote refresh.
+atlas/chat/inline_define.md:129:- A diagnostic's Parley virtual-line block auto-hides when the cursor leaves its
+atlas/chat/inline_define.md:134:- `lua/parley/define.lua` — pure core (slice / context / format / footnote footer / diagnostics).
+atlas/chat/inline_define.md:137:- `lua/parley/skill_render.lua` — footnote diagnostic refresh in the shared namespace.
+atlas/modes/review.md:15:edits are oriented by `DiffChange` highlights + INFO gutter diagnostics that
+atlas/modes/review.md:79:- **Rendering**: `lua/parley/skill_render.lua` — diagnostics + edit highlights
+atlas/modes/review.md:85:- **Feedback**: Highlights on edits (DiffChange), diagnostics from explain fields (INFO), quickfix for pending agent questions
+atlas/modes/review.md:162:The edit "why" (the per-edit `explain`) is an INFO diagnostic on parley's
+atlas/modes/review.md:164:it shows — scoped to that namespace, so the user's LSP/global diagnostics are
+atlas/modes/review.md:165:untouched. Default **on**: Parley's custom `parley/virtual_lines` diagnostic
+atlas/modes/review.md:166:handler renders a left-column virtual-line block headed `Diagnostics:` for the
+atlas/modes/review.md:167:current line. It avoids Neovim's stock virtual-lines indentation-by-diagnostic
+atlas/modes/review.md:169:(`skill_render.format_diagnostic_message`) **auto-expands below an edit when the
+atlas/modes/review.md:170:cursor is in that edit's region** (`attach_diagnostics` spans
+atlas/modes/review.md:171:`lnum..end_lnum`) and hides otherwise. `:ParleyShowDiagnostics` toggles it. The
+atlas/modes/review.md:173:diagnostics because the underlying diagnostic spans remain unchanged. Composes
+atlas/modes/review.md:209:- `lua/parley/skills/review/diag_display.lua` — inline "why" display toggle (`:ParleyShowDiagnostics`, cursor-region auto-show) (#133 M6)
+atlas/modes/review.md:213:- `lua/parley/skill_render.lua` — diagnostics + edit highlights
+atlas/ui/highlights.md:12:  diagnostics in Parley chat and markdown buffers. The pure parser/formatter
+atlas/ui/highlights.md:13:  lives in `lua/parley/timezone_diagnostics.lua`; `highlighter.setup_buf_handler`
+atlas/ui/highlights.md:14:  refreshes its separate diagnostic namespace on buffer enter/window enter and
+atlas/ui/highlights.md:15:  text changes. Its namespace renders review-style virtual lines for the current
+atlas/modes/raw_mode.md:5:**For agents debugging parley:** this is the first-line diagnostic tool for any LLM-pipeline issue (wrong prompt, missing messages, cache misses, tool_use shape, token usage, SSE oddities). Toggle on, reproduce, inspect the side files, toggle off. See [`atlas/infra/raw_logging.md`](../infra/raw_logging.md#when-to-use-this-debugging-entry-point) for the decision tree (exchange-level vs raw-API-level) and the full spec — file layout, format, toggles, lualine indicator, and the typed-YAML input feature.
+
+exec
+/bin/zsh -lc 'make test' in /Users/xianxu/workspace/parley.nvim
+ exited 2 in 5061ms:
+Checking lua/parley/agent_info.lua                OK
+Checking lua/parley/agent_picker.lua              OK
+Checking lua/parley/artifact_ref.lua              OK
+Checking lua/parley/buffer_edit.lua               OK
+Checking lua/parley/chat_dirs.lua                 OK
+Checking lua/parley/chat_finder.lua               OK
+Checking lua/parley/chat_lease.lua                OK
+Checking lua/parley/chat_parser.lua               OK
+Checking lua/parley/chat_respond.lua              OK
+Checking lua/parley/chat_slug.lua                 OK
+Checking lua/parley/cliproxy.lua                  OK
+Checking lua/parley/cliproxy_config.lua           OK
+Checking lua/parley/config.lua                    OK
+Checking lua/parley/copy.lua                      OK
+Checking lua/parley/custom_prompts.lua            OK
+Checking lua/parley/defaults.lua                  OK
+Checking lua/parley/define.lua                    OK
+Checking lua/parley/discovery/base.lua            OK
+Checking lua/parley/discovery/descriptor.lua      OK
+Checking lua/parley/discovery/init.lua            OK
+Checking lua/parley/discovery/local_types.lua     OK
+Checking lua/parley/discovery/matcher.lua         OK
+Checking lua/parley/discovery/merge.lua           OK
+Checking lua/parley/discovery/registry.lua        OK
+Checking lua/parley/dispatcher.lua                OK
+Checking lua/parley/drill_in.lua                  OK
+Checking lua/parley/exchange_clipboard.lua        OK
+Checking lua/parley/exchange_model.lua            OK
+Checking lua/parley/exporter.lua                  OK
+Checking lua/parley/file_tracker.lua              OK
+Checking lua/parley/finder_sticky.lua             OK
+Checking lua/parley/float_picker.lua              OK
+Checking lua/parley/google_drive.lua              OK
+Checking lua/parley/health.lua                    OK
+Checking lua/parley/helper.lua                    OK
+Checking lua/parley/highlighter.lua               OK
+Checking lua/parley/init.lua                      OK
+Checking lua/parley/interview.lua                 OK
+Checking lua/parley/issue_finder.lua              OK
+Checking lua/parley/issue_vocabulary.lua          OK
+Checking lua/parley/issues.lua                    OK
+Checking lua/parley/keybinding_registry.lua       OK
+Checking lua/parley/log_emit.lua                  OK
+Checking lua/parley/logger.lua                    OK
+Checking lua/parley/lualine.lua                   OK
+Checking lua/parley/markdown_finder.lua           OK
+Checking lua/parley/memory_prefs.lua              OK
+Checking lua/parley/neighborhood.lua              OK
+Checking lua/parley/note_dir_picker.lua           OK
+Checking lua/parley/note_dirs.lua                 OK
+Checking lua/parley/note_finder.lua               OK
+Checking lua/parley/notes.lua                     OK
+Checking lua/parley/oauth.lua                     OK
+Checking lua/parley/obfuscate.lua                 OK
+Checking lua/parley/outline.lua                   OK
+Checking lua/parley/progress.lua                  OK
+Checking lua/parley/provider_params.lua           OK
+Checking lua/parley/providers.lua                 OK
+Checking lua/parley/raw_log.lua                   OK
+Checking lua/parley/render.lua                    OK
+Checking lua/parley/render_buffer.lua             OK
+Checking lua/parley/repo_artifacts.lua            OK
+Checking lua/parley/review.lua                    OK
+Checking lua/parley/review_menu.lua               OK
+Checking lua/parley/root_dir_picker.lua           OK
+Checking lua/parley/root_dirs.lua                 OK
+Checking lua/parley/skill_assembly.lua            OK
+Checking lua/parley/skill_edits.lua               OK
+Checking lua/parley/skill_invoke.lua              OK
+Checking lua/parley/skill_manifest.lua            OK
+Checking lua/parley/skill_picker.lua              OK
+Checking lua/parley/skill_providers.lua           OK
+Checking lua/parley/skill_registry.lua            OK
+Checking lua/parley/skill_render.lua              OK
+Checking lua/parley/skills/define/init.lua        OK
+Checking lua/parley/skills/review/diag_display.lua OK
+Checking lua/parley/skills/review/init.lua        OK
+Checking lua/parley/skills/review/journal.lua     OK
+Checking lua/parley/skills/review/mode.lua        OK
+Checking lua/parley/skills/review/projection.lua  OK
+Checking lua/parley/skills/voice_apply/init.lua   OK
+Checking lua/parley/spell.lua                     OK
+Checking lua/parley/spinner.lua                   OK
+Checking lua/parley/super_repo.lua                OK
+Checking lua/parley/system_prompt_msgs.lua        OK
+Checking lua/parley/system_prompt_picker.lua      OK
+Checking lua/parley/tasker.lua                    OK
+Checking lua/parley/test_agent_picker.lua         OK
+Checking lua/parley/timezone_diagnostics.lua      OK
+Checking lua/parley/tool_folds.lua                OK
+Checking lua/parley/tool_loop.lua                 OK
+Checking lua/parley/tools/backup.lua              OK
+Checking lua/parley/tools/builtin/ack.lua         OK
+Checking lua/parley/tools/builtin/argv.lua        OK
+Checking lua/parley/tools/builtin/chat_history_search.lua OK
+Checking lua/parley/tools/builtin/edit_file.lua   OK
+Checking lua/parley/tools/builtin/emit_definition.lua OK
+Checking lua/parley/tools/builtin/find.lua        OK
+Checking lua/parley/tools/builtin/grep.lua        OK
+Checking lua/parley/tools/builtin/ls.lua          OK
+Checking lua/parley/tools/builtin/propose_edits.lua OK
+Checking lua/parley/tools/builtin/read_file.lua   OK
+Checking lua/parley/tools/builtin/write_file.lua  OK
+Checking lua/parley/tools/dispatcher.lua          OK
+Checking lua/parley/tools/init.lua                OK
+Checking lua/parley/tools/serialize.lua           OK
+Checking lua/parley/tools/types.lua               OK
+Checking lua/parley/tools/version.lua             OK
+Checking lua/parley/vault.lua                     OK
+Checking lua/parley/vision.lua                    OK
+Checking lua/parley/vision_finder.lua             OK
+Checking tests/arch/arch_helper.lua               OK
+Checking tests/arch/buffer_mutation_spec.lua      OK
+Checking tests/fixtures/pre_81_vanilla_claude_prompts.lua OK
+Checking tests/integration/chat_lease_spec.lua    OK
+Checking tests/integration/chat_move_spec.lua     OK
+Checking tests/integration/chat_respond_spec.lua  OK
+Checking tests/integration/cliproxy_auth_login_spec.lua OK
+Checking tests/integration/cliproxy_caller_teardown_spec.lua OK
+Checking tests/integration/cliproxy_command_spec.lua OK
+Checking tests/integration/cliproxy_dispatch_spec.lua OK
+Checking tests/integration/cliproxy_download_spec.lua OK
+Checking tests/integration/cliproxy_lifecycle_spec.lua OK
+Checking tests/integration/create_handler_spec.lua OK
+Checking tests/integration/define_spec.lua        OK
+Checking tests/integration/discovery_builder_spec.lua OK
+Checking tests/integration/discovery_local_types_spec.lua OK
+Checking tests/integration/export_spec.lua        OK
+Checking tests/integration/highlighting_spec.lua  OK
+Checking tests/integration/neighborhood_completion_spec.lua OK
+Checking tests/integration/new_chat_spec.lua      OK
+Checking tests/integration/not_chat_spec.lua      OK
+Checking tests/integration/progress_spec.lua      OK
+Checking tests/integration/review_diag_display_spec.lua OK
+Checking tests/integration/review_journal_io_spec.lua OK
+Checking tests/integration/review_menu_spec.lua   OK
+Checking tests/integration/review_mode_load_spec.lua OK
+Checking tests/integration/review_projection_spec.lua OK
+Checking tests/integration/skill_invoke_review_spec.lua OK
+Checking tests/integration/skill_invoke_spec.lua  OK
+Checking tests/integration/skill_providers_spec.lua OK
+Checking tests/integration/skill_registry_spec.lua OK
+Checking tests/integration/spell_chat_spec.lua    OK
+Checking tests/integration/tasker_run_spec.lua    OK
+Checking tests/integration/timer_race_spec.lua    OK
+Checking tests/integration/topic_gen_spec.lua     OK
+Checking tests/integration/tree_export_spec.lua   OK
+Checking tests/integration/voice_apply_spec.lua   OK
+Checking tests/perf_chat_finder.lua               OK
+Checking tests/unit/ancestor_messages_spec.lua    OK
+Checking tests/unit/anthropic_tool_decode_spec.lua OK
+Checking tests/unit/anthropic_tool_encode_spec.lua OK
+Checking tests/unit/arch_helper_spec.lua          OK
+Checking tests/unit/artifact_ref_spec.lua         OK
+Checking tests/unit/buffer_edit_spec.lua          OK
+Checking tests/unit/build_messages_spec.lua       OK
+Checking tests/unit/chat_dirs_spec.lua            OK
+Checking tests/unit/chat_finder_logic_spec.lua    OK
+Checking tests/unit/chat_parser_section_lines_spec.lua OK
+Checking tests/unit/chat_parser_tools_spec.lua    OK
+Checking tests/unit/chat_slug_resolve_spec.lua    OK
+Checking tests/unit/chat_slug_spec.lua            OK
+Checking tests/unit/cliproxy_config_spec.lua      OK
+Checking tests/unit/config_tools_spec.lua         OK
+Checking tests/unit/custom_prompts_spec.lua       OK
+Checking tests/unit/define_spec.lua               OK
+Checking tests/unit/discovery_base_spec.lua       OK
+Checking tests/unit/discovery_descriptor_spec.lua OK
+Checking tests/unit/discovery_matcher_spec.lua    OK
+Checking tests/unit/discovery_merge_spec.lua      OK
+Checking tests/unit/discovery_registry_spec.lua   OK
+Checking tests/unit/dispatcher_query_spec.lua     OK
+Checking tests/unit/dispatcher_spec.lua           OK
+Checking tests/unit/drill_in_spec.lua             OK
+Checking tests/unit/exchange_clipboard_spec.lua   OK
+Checking tests/unit/exchange_model_spec.lua       OK
+Checking tests/unit/exporter_tree_spec.lua        OK
+Checking tests/unit/file_tracker_spec.lua         OK
+Checking tests/unit/finder_sticky_spec.lua        OK
+Checking tests/unit/float_picker_spec.lua         OK
+Checking tests/unit/get_week_number_spec.lua      OK
+Checking tests/unit/helper_io_spec.lua            OK
+Checking tests/unit/helper_spec.lua               OK
+Checking tests/unit/highlighter_spec.lua          OK
+Checking tests/unit/inline_branch_spec.lua        OK
+Checking tests/unit/issue_finder_spec.lua         OK
+Checking tests/unit/issue_vocabulary_spec.lua     OK
+Checking tests/unit/issues_spec.lua               OK
+Checking tests/unit/keybindings_spec.lua          OK
+Checking tests/unit/log_emit_spec.lua             OK
+Checking tests/unit/logger_spec.lua               OK
+Checking tests/unit/markdown_draft_block_spec.lua OK
+Checking tests/unit/memory_prefs_spec.lua         OK
+Checking tests/unit/neighborhood_spec.lua         OK
+Checking tests/unit/note_finder_logic_spec.lua    OK
+Checking tests/unit/oauth_spec.lua                OK
+Checking tests/unit/obfuscate_spec.lua            OK
+Checking tests/unit/open_chat_reference_spec.lua  OK
+Checking tests/unit/outline_spec.lua              OK
+Checking tests/unit/parley_harness_golden_spec.lua OK
+Checking tests/unit/parley_harness_spec.lua       OK
+Checking tests/unit/parse_at_reference_spec.lua   OK
+Checking tests/unit/parse_chat_spec.lua           OK
+Checking tests/unit/picker_items_spec.lua         OK
+Checking tests/unit/process_directory_pattern_spec.lua OK
+Checking tests/unit/progress_spec.lua             OK
+Checking tests/unit/provider_params_spec.lua      OK
+Checking tests/unit/providers_pre_query_spec.lua  OK
+Checking tests/unit/pure_functions_spec.lua       OK
+Checking tests/unit/raw_log_spec.lua              OK
+Checking tests/unit/remote_references_spec.lua    OK
+Checking tests/unit/render_buffer_roundtrip_spec.lua OK
+Checking tests/unit/render_buffer_spec.lua        OK
+Checking tests/unit/render_spec.lua               OK
+Checking tests/unit/review_journal_spec.lua       OK
+Checking tests/unit/review_mode_spec.lua          OK
+Checking tests/unit/review_spec.lua               OK
+Checking tests/unit/skill_assembly_spec.lua       OK
+Checking tests/unit/skill_edits_spec.lua          OK
+Checking tests/unit/skill_manifest_spec.lua       OK
+Checking tests/unit/skill_picker_spec.lua         OK
+Checking tests/unit/skill_render_spec.lua         OK
+Checking tests/unit/spell_spec.lua                OK
+Checking tests/unit/sse_parsing_spec.lua          OK
+Checking tests/unit/super_repo_spec.lua           OK
+Checking tests/unit/system_prompt_msgs_spec.lua   OK
+Checking tests/unit/tasker_unit_spec.lua          OK
+Checking tests/unit/timezone_diagnostics_spec.lua OK
+Checking tests/unit/tool_folds_spec.lua           OK
+Checking tests/unit/tool_loop_spec.lua            OK
+Checking tests/unit/tools_builtin_ack_spec.lua    OK
+Checking tests/unit/tools_builtin_chat_history_search_spec.lua OK
+Checking tests/unit/tools_builtin_find_spec.lua   OK
+Checking tests/unit/tools_builtin_grep_spec.lua   OK
+Checking tests/unit/tools_builtin_ls_spec.lua     OK
+Checking tests/unit/tools_builtin_propose_edits_spec.lua OK
+Checking tests/unit/tools_builtin_read_file_spec.lua OK
+Checking tests/unit/tools_builtin_registered_spec.lua OK
+Checking tests/unit/tools_dispatcher_spec.lua     OK
+Checking tests/unit/tools_registry_spec.lua       OK
+Checking tests/unit/tools_serialize_spec.lua      OK
+Checking tests/unit/tools_types_spec.lua          OK
+Checking tests/unit/vault_spec.lua                OK
+Checking tests/unit/vision_spec.lua               OK
+
+Total: 0 warnings / 0 errors in 244 files
+PASS: tests/unit/ancestor_messages_spec.lua
+PASS: tests/unit/anthropic_tool_decode_spec.lua
+PASS: tests/unit/buffer_edit_spec.lua
+PASS: tests/unit/anthropic_tool_encode_spec.lua
+PASS: tests/unit/arch_helper_spec.lua
+PASS: tests/unit/artifact_ref_spec.lua
+PASS: tests/unit/build_messages_spec.lua
+PASS: tests/unit/chat_parser_section_lines_spec.lua
+PASS: tests/unit/chat_parser_tools_spec.lua
+PASS: tests/unit/chat_slug_spec.lua
+PASS: tests/unit/chat_finder_logic_spec.lua
+PASS: tests/unit/cliproxy_config_spec.lua
+PASS: tests/unit/chat_dirs_spec.lua
+PASS: tests/unit/define_spec.lua
+PASS: tests/unit/custom_prompts_spec.lua
+PASS: tests/unit/discovery_base_spec.lua
+PASS: tests/unit/discovery_descriptor_spec.lua
+PASS: tests/unit/discovery_matcher_spec.lua
+PASS: tests/unit/discovery_merge_spec.lua
+PASS: tests/unit/discovery_registry_spec.lua
+PASS: tests/unit/chat_slug_resolve_spec.lua
+PASS: tests/unit/dispatcher_query_spec.lua
+PASS: tests/unit/exchange_clipboard_spec.lua
+PASS: tests/unit/drill_in_spec.lua
+PASS: tests/unit/exchange_model_spec.lua
+PASS: tests/unit/dispatcher_spec.lua
+PASS: tests/unit/finder_sticky_spec.lua
+PASS: tests/unit/exporter_tree_spec.lua
+PASS: tests/unit/get_week_number_spec.lua
+PASS: tests/unit/file_tracker_spec.lua
+PASS: tests/unit/helper_io_spec.lua
+PASS: tests/unit/float_picker_spec.lua
+PASS: tests/unit/helper_spec.lua
+PASS: tests/unit/highlighter_spec.lua
+PASS: tests/unit/inline_branch_spec.lua
+PASS: tests/unit/issue_vocabulary_spec.lua
+PASS: tests/unit/issue_finder_spec.lua
+PASS: tests/unit/log_emit_spec.lua
+PASS: tests/unit/markdown_draft_block_spec.lua
+PASS: tests/unit/logger_spec.lua
+PASS: tests/unit/memory_prefs_spec.lua
+PASS: tests/unit/issues_spec.lua
+PASS: tests/unit/config_tools_spec.lua
+PASS: tests/unit/neighborhood_spec.lua
+PASS: tests/unit/oauth_spec.lua
+PASS: tests/unit/obfuscate_spec.lua
+PASS: tests/unit/note_finder_logic_spec.lua
+PASS: tests/unit/outline_spec.lua
+PASS: tests/unit/open_chat_reference_spec.lua
+PASS: tests/unit/parse_chat_spec.lua
+PASS: tests/unit/picker_items_spec.lua
+PASS: tests/unit/parley_harness_golden_spec.lua
+PASS: tests/unit/process_directory_pattern_spec.lua
+PASS: tests/unit/parley_harness_spec.lua
+PASS: tests/unit/parse_at_reference_spec.lua
+PASS: tests/unit/progress_spec.lua
+PASS: tests/unit/provider_params_spec.lua
+PASS: tests/unit/providers_pre_query_spec.lua
+PASS: tests/unit/raw_log_spec.lua
+PASS: tests/unit/keybindings_spec.lua
+PASS: tests/unit/render_buffer_spec.lua
+PASS: tests/unit/pure_functions_spec.lua
+PASS: tests/unit/render_buffer_roundtrip_spec.lua
+PASS: tests/unit/remote_references_spec.lua
+PASS: tests/unit/render_spec.lua
+PASS: tests/unit/review_mode_spec.lua
+PASS: tests/unit/review_journal_spec.lua
+PASS: tests/unit/review_spec.lua
+PASS: tests/unit/skill_assembly_spec.lua
+PASS: tests/unit/skill_edits_spec.lua
+PASS: tests/unit/skill_manifest_spec.lua
+PASS: tests/unit/skill_picker_spec.lua
+PASS: tests/unit/skill_render_spec.lua
+PASS: tests/unit/spell_spec.lua
+PASS: tests/unit/sse_parsing_spec.lua
+PASS: tests/unit/system_prompt_msgs_spec.lua
+PASS: tests/unit/tasker_unit_spec.lua
+PASS: tests/unit/timezone_diagnostics_spec.lua
+PASS: tests/unit/tool_folds_spec.lua
+PASS: tests/unit/tool_loop_spec.lua
+PASS: tests/unit/tools_builtin_grep_spec.lua
+PASS: tests/unit/tools_builtin_propose_edits_spec.lua
+PASS: tests/unit/tools_builtin_ls_spec.lua
+PASS: tests/unit/tools_builtin_read_file_spec.lua
+===FAIL: tests/unit/tools_builtin_find_spec.lua===
+  Scheduling: tests/unit/tools_builtin_find_spec.lua
+
+  ========================================
+  Testing:     /Users/xianxu/workspace/parley.nvim/tests/unit/tools_builtin_find_spec.lua
+  Success    ||    find tool finds files by structured name and type fields
+  Success    ||    find tool does not accept a raw flags escape hatch
+  Success    ||    find tool rejects action and write predicates as unknown structured fields
+  Fail    ||    find tool treats command substitution text in name as data
+              ...space/parley.nvim/tests/unit/tools_builtin_find_spec.lua:30: Expected objects to be the same.
+              Passed in:
+              (boolean) true
+              Expected:
+              (boolean) false
+
+              stack traceback:
+                  ...space/parley.nvim/tests/unit/tools_builtin_find_spec.lua:30: in function <...space/parley.nvim/tests/unit/tools_builtin_find_spec.lua:28>
+
+
+  Success:     3
+  Failed :     1
+  Errors :     0
+  ========================================
+  Tests Failed. Exit: 1
+PASS: tests/unit/tools_builtin_registered_spec.lua
+PASS: tests/unit/tools_registry_spec.lua
+PASS: tests/unit/tools_serialize_spec.lua
+PASS: tests/unit/tools_types_spec.lua
+PASS: tests/unit/tools_builtin_ack_spec.lua
+PASS: tests/unit/tools_dispatcher_spec.lua
+PASS: tests/unit/vault_spec.lua
+PASS: tests/unit/vision_spec.lua
+PASS: tests/unit/tools_builtin_chat_history_search_spec.lua
+PASS: tests/unit/super_repo_spec.lua
+
+=== Failed unit test files ===
+tests/unit/tools_builtin_find_spec.lua
+make: *** [test-unit] Error 1
+
+codex
+`make test` is not green in this checkout: lint and most tests pass, but `tests/unit/tools_builtin_find_spec.lua` fails on the command-substitution-as-data case. That file is outside this diff, so I’m treating it as verification evidence to report rather than attributing it to the diagnostic change.
+exec
+/bin/zsh -lc "nl -ba tests/unit/tools_builtin_find_spec.lua | sed -n '1,80p'" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+     1    -- Tests for lua/parley/tools/builtin/find.lua
+     2
+     3    local find_def = require("parley.tools.builtin.find")
+     4    local handler = find_def.handler
+     5
+     6    describe("find tool", function()
+     7        it("finds files by structured name and type fields", function()
+     8            local r = handler({ path = "lua/parley", name = "*.lua", type = "f" })
+     9            assert.is_false(r.is_error)
+    10            assert.truthy(r.content:match("config%.lua"))
+    11        end)
+    12
+    13        it("does not accept a raw flags escape hatch", function()
+    14            local r = handler({ path = ".", flags = { "-exec", "echo", "PARLEY_SENTINEL_144", ";" } })
+    15            assert.is_true(r.is_error)
+    16            assert.not_matches("missing.*command", r.content)
+    17            assert.not_matches("PARLEY_SENTINEL_144", r.content)
+    18        end)
+    19
+    20        it("rejects action and write predicates as unknown structured fields", function()
+    21            for _, field in ipairs({ "-exec", "-execdir", "-ok", "-okdir", "-delete", "-fprint", "-fprintf", "-fls" }) do
+    22                local r = handler({ path = ".", [field] = "PARLEY_SENTINEL_144" })
+    23                assert.is_true(r.is_error)
+    24                assert.not_matches("PARLEY_SENTINEL_144", r.content)
+    25            end
+    26        end)
+    27
+    28        it("treats command substitution text in name as data", function()
+    29            local r = handler({ path = ".", name = "$(echo PARLEY_SENTINEL_144)" })
+    30            assert.is_false(r.is_error)
+    31            assert.not_matches("PARLEY_SENTINEL_144", r.content)
+    32        end)
+    33    end)
+
+exec
+/bin/zsh -lc 'git diff --name-only b9094e9bfc89b0f27013c6fd41c38a83b8b61510..HEAD -- tests/unit/tools_builtin_find_spec.lua lua/parley/tools/builtin/find.lua lua/parley/tools/builtin/argv.lua' in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+exec
+/bin/zsh -lc 'git status --short' in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+ M workshop/issues/000162-split-parley-into-two-different-plugins.md
+ M workshop/issues/000168-buffer-undo-operation-during-chat-generation-resulted-in-a-huge-error-message.md
+ M workshop/issues/000170-parley-chat-performance-problem.md
+ M workshop/issues/000171-footnote-coloring.md
+
+codex
+```verdict
+verdict: REWORK
+confidence: high
+```
+
+The left-column rendering approach is mostly right and the focused test passes, but the new current-line filter regresses review diagnostics that span multiple lines. Review diagnostics intentionally use `lnum..end_lnum`; after this change, the virtual-line block only appears when the cursor is on `diagnostic.lnum`, not when it is elsewhere inside the edit region. That violates the documented/shared namespace behavior, so this should not cross the boundary yet.
+
+1. Strengths
+
+- `lua/parley/skills/review/diag_display.lua:103` scopes the custom handler to Parley’s diagnostic namespace, preserving global/LSP diagnostics. Good ARCH-DRY shape.
+- `lua/parley/skills/review/diag_display.lua:145` disables stock `virtual_lines` only for the Parley namespace and keeps diagnostic data intact.
+- `tests/integration/review_diag_display_spec.lua:43` pins the key symptom: high-column diagnostics now render with `virt_lines_leftcol = true`.
+- Atlas updates cover both review and inline define behavior.
+
+2. Critical Findings
+
+- `lua/parley/skills/review/diag_display.lua:79` filters with `diagnostic.lnum == line`, ignoring `diagnostic.end_lnum`. `skill_render.attach_diagnostics` deliberately spans review edits across `lnum..end_lnum`, and `atlas/modes/review.md:169` still promises display when the cursor is in that edit region. I reproduced this with a diagnostic `{lnum=0,end_lnum=2}`: line 1 shows 1 display mark; moving to lines 2 or 3 shows 0. Fix by extracting a range predicate like `diagnostic_contains_line(d, line)` using `end_lnum or lnum`, render when the cursor is anywhere in the span, and add an integration test that moves the cursor to a middle/end line of a multi-line review diagnostic. This is ARCH-PURPOSE and ARCH-PURE: the shared display must serve both footnote and review diagnostics, and the span predicate should be direct/pinned.
+
+3. Important Findings
+
+- `workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:86` claims final `make test` green, but my `make test` run exits 2: `tests/unit/tools_builtin_find_spec.lua` fails at line 30 in “treats command substitution text in name as data”. That file is outside this diff, so I am not attributing causality to #173, but the boundary evidence is currently false/stale. Re-run after resolving or explicitly record the exception before close.
+
+4. Minor Findings
+
+- `lua/parley/skills/review/diag_display.lua:5` still says default is stock ``virtual_lines { current_line = true }``; update the header comment to describe the custom `parley/virtual_lines` handler.
+
+5. Test Coverage Notes
+
+Focused `review_diag_display_spec.lua` passes. Missing coverage is the multi-line `end_lnum` current-region behavior, which is exactly the regression above. Full `make test` is not green in this checkout due to the unrelated `tools_builtin_find_spec.lua` failure.
+
+6. Architectural Notes
+
+- ARCH-DRY: Pass. One Parley display controller is used for review and footnote diagnostics.
+- ARCH-PURE: Mostly pass, but the current-line/range selection logic should be a small pure helper with a targeted test.
+- ARCH-PURPOSE: Flagged. The diff solves the footnote long-line symptom but under-delivers the shared-namespace purpose by breaking multi-line review-region display.
+
+7. Plan Revision Recommendations
+
+- Add a `## Revisions` entry noting that current-line filtering must preserve `lnum..end_lnum` review-region behavior, not only same-line footnote diagnostics.
+- Update the verification log after `make test` is actually green or after the unrelated failure is explicitly handled.
+tokens used
+71,668
+```verdict
+verdict: REWORK
+confidence: high
+```
+
+The left-column rendering approach is mostly right and the focused test passes, but the new current-line filter regresses review diagnostics that span multiple lines. Review diagnostics intentionally use `lnum..end_lnum`; after this change, the virtual-line block only appears when the cursor is on `diagnostic.lnum`, not when it is elsewhere inside the edit region. That violates the documented/shared namespace behavior, so this should not cross the boundary yet.
+
+1. Strengths
+
+- `lua/parley/skills/review/diag_display.lua:103` scopes the custom handler to Parley’s diagnostic namespace, preserving global/LSP diagnostics. Good ARCH-DRY shape.
+- `lua/parley/skills/review/diag_display.lua:145` disables stock `virtual_lines` only for the Parley namespace and keeps diagnostic data intact.
+- `tests/integration/review_diag_display_spec.lua:43` pins the key symptom: high-column diagnostics now render with `virt_lines_leftcol = true`.
+- Atlas updates cover both review and inline define behavior.
+
+2. Critical Findings
+
+- `lua/parley/skills/review/diag_display.lua:79` filters with `diagnostic.lnum == line`, ignoring `diagnostic.end_lnum`. `skill_render.attach_diagnostics` deliberately spans review edits across `lnum..end_lnum`, and `atlas/modes/review.md:169` still promises display when the cursor is in that edit region. I reproduced this with a diagnostic `{lnum=0,end_lnum=2}`: line 1 shows 1 display mark; moving to lines 2 or 3 shows 0. Fix by extracting a range predicate like `diagnostic_contains_line(d, line)` using `end_lnum or lnum`, render when the cursor is anywhere in the span, and add an integration test that moves the cursor to a middle/end line of a multi-line review diagnostic. This is ARCH-PURPOSE and ARCH-PURE: the shared display must serve both footnote and review diagnostics, and the span predicate should be direct/pinned.
+
+3. Important Findings
+
+- `workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:86` claims final `make test` green, but my `make test` run exits 2: `tests/unit/tools_builtin_find_spec.lua` fails at line 30 in “treats command substitution text in name as data”. That file is outside this diff, so I am not attributing causality to #173, but the boundary evidence is currently false/stale. Re-run after resolving or explicitly record the exception before close.
+
+4. Minor Findings
+
+- `lua/parley/skills/review/diag_display.lua:5` still says default is stock ``virtual_lines { current_line = true }``; update the header comment to describe the custom `parley/virtual_lines` handler.
+
+5. Test Coverage Notes
+
+Focused `review_diag_display_spec.lua` passes. Missing coverage is the multi-line `end_lnum` current-region behavior, which is exactly the regression above. Full `make test` is not green in this checkout due to the unrelated `tools_builtin_find_spec.lua` failure.
+
+6. Architectural Notes
+
+- ARCH-DRY: Pass. One Parley display controller is used for review and footnote diagnostics.
+- ARCH-PURE: Mostly pass, but the current-line/range selection logic should be a small pure helper with a targeted test.
+- ARCH-PURPOSE: Flagged. The diff solves the footnote long-line symptom but under-delivers the shared-namespace purpose by breaking multi-line review-region display.
+
+7. Plan Revision Recommendations
+
+- Add a `## Revisions` entry noting that current-line filtering must preserve `lnum..end_lnum` review-region behavior, not only same-line footnote diagnostics.
+- Update the verification log after `make test` is actually green or after the unrelated failure is explicitly handled.
diff --git a/workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md b/workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md
new file mode 100644
index 0000000..36a82d1
--- /dev/null
+++ b/workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md
@@ -0,0 +1,105 @@
+# Diagnostic Virtual Lines Left Column Implementation Plan
+
+> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.
+
+**Goal:** Make Parley's inline diagnostic display visible on long wrapped markdown lines by rendering diagnostic virtual lines from the left column.
+
+**Architecture:** Keep diagnostic data unchanged: spans stay anchored to selected text and footnote references. Replace only Parley's namespace display shell in `diag_display.lua`, so global/LSP diagnostics still use Neovim defaults. This follows ARCH-DRY by keeping one Parley display controller and ARCH-PURE by avoiding parser/data changes.
+
+**Tech Stack:** Lua, Neovim diagnostics, extmarks, Plenary/Busted tests.
+
+---
+
+## Core Concepts
+
+### Pure Entities
+
+| Name | Lives in | Status |
+|------|----------|--------|
+| `ParleyDiagnosticMessageLines` | `lua/parley/skills/review/diag_display.lua` | new |
+
+- **ParleyDiagnosticMessageLines** — deterministic conversion from a diagnostic message string into visible virtual-line rows with a `Diagnostics:` header.
+  - **Relationships:** 1:N from one diagnostic message to display rows.
+  - **DRY rationale:** Both review diagnostics and footnote diagnostics consume the same Parley namespace display.
+  - **Future extensions:** If Parley later adds source-specific labels, this formatter is the one place to widen.
+
+### Integration Points
+
+| Name | Lives in | Status | Wraps |
+|------|----------|--------|-------|
+| `ParleyDiagnosticVirtualLines` | `lua/parley/skills/review/diag_display.lua` | modified | Neovim extmarks |
+
+- **ParleyDiagnosticVirtualLines** — Parley-owned inline diagnostic renderer scoped to `skill_render.diag_namespace()`.
+  - **Injected into:** `diag_display.set(on)`; toggling still owns all inline display setup.
+  - **Future extensions:** Can add color overrides without changing diagnostic producers.
+
+## Chunk 1: Left-Column Renderer
+
+**Files:**
+- Modify: `lua/parley/skills/review/diag_display.lua`
+- Modify: `tests/integration/review_diag_display_spec.lua`
+- Modify: `atlas/modes/review.md`
+- Modify: `atlas/chat/inline_define.md`
+- Modify: `workshop/issues/000173-diagnostic-virtual-lines-leftcol.md`
+
+- [x] **Step 1: Write failing tests**
+
+Add integration coverage that:
+- Sets a Parley diagnostic at a high column on a long line.
+- Enables `diag_display`.
+- Asserts the generated display extmark has `virt_lines_leftcol = true`.
+- Asserts the first virtual-line chunk is `Diagnostics:` instead of leading spaces.
+- Asserts `dd.set(false)` clears the Parley display extmark while leaving the diagnostic data intact.
+
+Run:
+
+```bash
+nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"
+```
+
+Expected: FAIL because the stock diagnostic handler emits leading-space virtual lines and `diag_display` has no custom extmark namespace.
+
+- [x] **Step 2: Implement the renderer**
+
+In `lua/parley/skills/review/diag_display.lua`:
+- Add a private display namespace.
+- Add a private function that clears Parley diagnostic virtual-line extmarks.
+- Add a private render function that reads diagnostics from `skill_render.diag_namespace()`, filters to the current cursor line, and writes `virt_lines` with `virt_lines_leftcol = true`.
+- Configure Neovim diagnostics for the Parley namespace with `virtual_lines = false`, `virtual_text = false`, and existing signs/underline behavior.
+- Register a buffer-local `CursorMoved` autocmd for visible Parley buffers so current-line behavior keeps updating.
+
+- [x] **Step 3: Run green focused tests**
+
+Run:
+
+```bash
+nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"
+```
+
+Expected: PASS.
+
+- [x] **Step 4: Update docs and issue log**
+
+Update atlas text that says Parley uses built-in diagnostic `virtual_lines` so it instead describes the Parley-owned left-column inline renderer. Record red/green evidence in the issue log and tick plan items.
+
+- [x] **Step 5: Final verification**
+
+Run:
+
+```bash
+git diff --check -- lua/parley/skills/review/diag_display.lua tests/integration/review_diag_display_spec.lua atlas/modes/review.md atlas/chat/inline_define.md workshop/issues/000173-diagnostic-virtual-lines-leftcol.md workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md
+make test
+```
+
+Expected: all pass.
+
+## Revisions
+
+### 2026-07-08 — Boundary review REWORK
+
+- **Reason:** The first custom renderer filtered current-line diagnostics only by
+  `diagnostic.lnum`, which hid review diagnostics when the cursor was inside a
+  multi-line diagnostic span but not on the start line.
+- **Delta:** Preserve current-line behavior over the full diagnostic range
+  `lnum..end_lnum`; add integration coverage that moves the cursor to the middle
+  and final lines of a multi-line review diagnostic.


codex
I’ll re-run the fresh review against the current workspace state, focusing on whether the earlier span regression was fixed and whether the plan revision now matches the code.
exec
/bin/zsh -lc "sdlc --help | sed -n '1,180p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
sdlc collects ariadne's SDLC checkpoint guards into one binary. Each subcommand
owns one checkpoint: it requires evidence at the gate, mutates state, logs the
transition, and refuses transitions that lack it. We don't model the SDLC as a
state machine — stages stay prose; we codify the gates between them where drift
recurs. `sdlc` manages the development life cycle; prefer it over `git`/`gh`.

BEFORE WORK
  - `sdlc claim --issue N` — the single start-of-work gesture, a CHEAP LOCK.
    Flips an *open* issue to `working` and publishes the claim to origin/main so
    peer agents see it. No estimate demanded (#113) — claim early, the moment an
    idea crystallizes. `--no-start` suppresses the flip.
  - Do NOT hand-edit an issue's `status:` — let `sdlc claim` or `sdlc issue
    set-status` own that transition (it carries the reopen/`→ done` guards).

ENTER IMPLEMENTATION
  - After plan approval, before editing code, run `sdlc change-code`. It owns the
    branching decision (in-place branch by default; `--worktree=yes` for an
    isolated worktree), the plan-quality check, and the `estimate_hours` gate
    (relocated here from claim, #113). Don't start coding without it.

PUBLISH
  - Publishing goes through a PR: `sdlc pr` → `sdlc merge`. Direct `sdlc push`
    if working directly on main.
  - Publish ONCE at issue close, not per milestone — and do NOT reuse a branch
    name that already has a merged PR. `sdlc merge` refuses (#148) when a branch
    has commits not in main despite a merged PR (a reused name would otherwise
    silently strand the new commits); rename to a fresh branch, `sdlc pr`, retry.

RECOVER
  - After a compaction or session resume, run `sdlc state` to recover where you
    are instead of re-inferring from issue files.

LOCAL REPO TRANSACTION LOCK
  - Mutating verbs take an SDLC-owned repo transaction lock at
    `.git/sdlc.lock` before reading/writing issue state, committing, changing
    branches, or pushing. The lock is local to the Git common dir, so linked
    worktrees of the same repo serialize with each other.
  - Wait messages identify the holder pid and command when metadata is
    available. `close` and `milestone-close` release the lock while the external
    boundary-review subprocess runs, then reacquire before finalization; if HEAD
    or the issue/project file state they prepared changed meanwhile, they refuse
    to finalize and tell you to rerun. `change-code`, `merge`, and `push` can still hold the lock during
    long-running review/ship transactions; wait or retry rather than removing
    the lock while that process is alive.
  - A dead same-host holder is reclaimed automatically; initializing metadata
    is waited through. Other stale/timeout errors tell you how to inspect
    `.git/sdlc.lock`. Remote push/ref races are separate: the local lock
    serializes this checkout, not another machine or clone.

WHEN A VERB ERRORS
  Do NOT route around it with hand-rolled `git`/`gh`. Its errors are next-action
  specs. The fix is one of two things:
    (a) satisfy the precondition it names and re-run the same verb (e.g. `sdlc
        merge` saying "no upstream" → run `sdlc pr` first, then `sdlc merge`); or
    (b) if the error is a genuine gap in `sdlc` itself, fix that edge case in the
        source and re-run. We're still ironing out edge cases.
  Only drop to manual when a verb genuinely cannot express the need — say so.

These gates sit inside a wider prose arc the binary does NOT own: ideation
(parley/pensive) → brainstorm → plan → build → milestone review (`sdlc judge`,
auto-dispatched) → close/ship → postmortem.

CONVENTIONS

  --issue vs --github-issue — `--issue N` always means workshop/issues
  (6-digit ID). `--github-issue N` means a GitHub issue number. Bare `--issue`
  never means a GitHub issue.

  Form vs essence — checkpoint guards (close, milestone-close, push, merge)
  defend against *omission* via required-evidence flags; `sdlc judge` defends
  against *theater* via fresh-context review. Form runs first; judge second.

The verb list + per-verb help (`sdlc <verb> --help`) follow below.

Usage:
  sdlc [flags]
  sdlc [command]

Available Commands:
  claim           Start work: flip an open issue to working + broadcast the claim
  start-plan      Enter planning: deliver the architecture principles to design against (#75)
  change-code     Enter implementation after the structural + plan-quality gates
  issue           Create + manage issues (new / set-status / list / show)
  actual          Compute an issue's focused dev-hours via active-time-v3 (#68)
  active-time     Per-issue active-time attribution table (the v3 engine, standalone)
  close           Close an issue or milestone (ACTUAL + VERIFIED + atlas/project sweep)
  milestone-close Close one milestone + auto-dispatch its review
  pr              Open a pull request from a feature branch
  merge           Merge the PR, archive done issues, clean up
  push            Ship from main (clean tree + pre-merge judges + archive)
  state           Inspect workflow state (branch, working issues, drift)
  resolve         Resolve a symbolic artifact ref (ariadne#11, #15 M4) to its current path(s) — read-only
  open            Resolve a ref and open the primary artifact in $EDITOR
  judge           Run an LLM-judge check against the diff (fresh-context)
  arch-principles Print the ARCH-* architecture principles (single source; pull for non-gate work)
  estimate-source Name the shared estimate method + the repo-local calibration source (pull)
  process-manual  Unroll every injection source into a linked process manual (#153)
  propagate-base  Re-weave every recursive dependent of this repo (foundation-first)
  help            Help about any command

Flags:
  -h, --help   help for sdlc

Use "sdlc [command] --help" for more information about a command.

exec
/bin/zsh -lc "sed -n '1,180p' /Users/xianxu/workspace/ariadne/construct/local/sdlc/SKILL.md" in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc "sed -n '1,220p' /Users/xianxu/workspace/ariadne/construct/adapted/superpowers-using-superpowers/SKILL.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
---
name: sdlc
description: Use when at an SDLC checkpoint — starting work, closing an issue or milestone, opening/merging a PR, or recovering workflow state after compaction. The `sdlc` binary owns the gates between workflow stages and refuses transitions that lack required evidence.
---

# sdlc — SDLC checkpoint binary

`sdlc` owns the gates between SDLC workflow stages (claim → change-code → pr →
merge, plus close, milestone-close, judge). It requires evidence at each gate,
mutates state, logs the transition, and refuses transitions that lack the
evidence — that is the shape of a "checkpoint guard."

The binary is the single source of truth. This skill is a static pointer and
intentionally carries no copy of the contract, so it can never drift:

- **`sdlc --help`** — the workflow contract: the start-of-work runbook,
  conventions, and the verb list.
- **`sdlc <verb> --help`** — one checkpoint's full contract, flags, and examples.

Read those instead of relying on memory; the binary's help is always current.

 succeeded in 0ms:
---
name: superpowers-using-superpowers
description: Use when starting any conversation - establishes how to find and use skills, requiring Skill tool invocation before ANY response including clarifying questions
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, skip this skill.
</SUBAGENT-STOP>

<EXTREMELY-IMPORTANT>
If you think there is even a 1% chance a skill might apply to what you are doing, you ABSOLUTELY MUST invoke the skill.

IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.

This is not negotiable. This is not optional. You cannot rationalize your way out of this.
</EXTREMELY-IMPORTANT>

## Instruction Priority

> **Ariadne note:** AGENTS.md Section 3 governs subagent strategy and overrides skills that mandate subagent-driven-development as the default execution path.

Superpowers skills override default system prompt behavior, but **user instructions always take precedence**:

1. **User's explicit instructions** (CLAUDE.md, GEMINI.md, AGENTS.md, direct requests) — highest priority
2. **Superpowers skills** — override default system behavior where they conflict
3. **Default system prompt** — lowest priority

If CLAUDE.md, GEMINI.md, or AGENTS.md says "don't use TDD" and a skill says "always use TDD," follow the user's instructions. The user is in control.

## How to Access Skills

**In Claude Code:** Use the `Skill` tool. When you invoke a skill, its content is loaded and presented to you—follow it directly. Never use the Read tool on skill files.

**In Gemini CLI:** Skills activate via the `activate_skill` tool. Gemini loads skill metadata at session start and activates the full content on demand.

**In other environments:** Check your platform's documentation for how skills are loaded.

## Platform Adaptation

Skills use Claude Code tool names. Non-CC platforms: see `references/codex-tools.md` (Codex) for tool equivalents. Gemini CLI users get the tool mapping loaded automatically via GEMINI.md.

# Using Skills

## The Rule

**Invoke relevant or requested skills BEFORE any response or action.** Even a 1% chance a skill might apply means that you should invoke the skill to check. If an invoked skill turns out to be wrong for the situation, you don't need to use it.

```dot
digraph skill_flow {
    "User message received" [shape=doublecircle];
    "About to EnterPlanMode?" [shape=doublecircle];
    "Already brainstormed?" [shape=diamond];
    "Invoke brainstorming skill" [shape=box];
    "Might any skill apply?" [shape=diamond];
    "Invoke Skill tool" [shape=box];
    "Announce: 'Using [skill] to [purpose]'" [shape=box];
    "Has checklist?" [shape=diamond];
    "Create TodoWrite todo per item" [shape=box];
    "Follow skill exactly" [shape=box];
    "Respond (including clarifications)" [shape=doublecircle];

    "About to EnterPlanMode?" -> "Already brainstormed?";
    "Already brainstormed?" -> "Invoke brainstorming skill" [label="no"];
    "Already brainstormed?" -> "Might any skill apply?" [label="yes"];
    "Invoke brainstorming skill" -> "Might any skill apply?";

    "User message received" -> "Might any skill apply?";
    "Might any skill apply?" -> "Invoke Skill tool" [label="yes, even 1%"];
    "Might any skill apply?" -> "Respond (including clarifications)" [label="definitely not"];
    "Invoke Skill tool" -> "Announce: 'Using [skill] to [purpose]'";
    "Announce: 'Using [skill] to [purpose]'" -> "Has checklist?";
    "Has checklist?" -> "Create TodoWrite todo per item" [label="yes"];
    "Has checklist?" -> "Follow skill exactly" [label="no"];
    "Create TodoWrite todo per item" -> "Follow skill exactly";
}
```

## Red Flags

These thoughts mean STOP—you're rationalizing:

| Thought | Reality |
|---------|---------|
| "This is just a simple question" | Questions are tasks. Check for skills. |
| "I need more context first" | Skill check comes BEFORE clarifying questions. |
| "Let me explore the codebase first" | Skills tell you HOW to explore. Check first. |
| "I can check git/files quickly" | Files lack conversation context. Check for skills. |
| "Let me gather information first" | Skills tell you HOW to gather information. |
| "This doesn't need a formal skill" | If a skill exists, use it. |
| "I remember this skill" | Skills evolve. Read current version. |
| "This doesn't count as a task" | Action = task. Check for skills. |
| "The skill is overkill" | Simple things become complex. Use it. |
| "I'll just do this one thing first" | Check BEFORE doing anything. |
| "This feels productive" | Undisciplined action wastes time. Skills prevent this. |
| "I know what that means" | Knowing the concept ≠ using the skill. Invoke it. |

## Skill Priority

When multiple skills could apply, use this order:

1. **Process skills first** (brainstorming, debugging) - these determine HOW to approach the task
2. **Implementation skills second** (frontend-design, mcp-builder) - these guide execution

"Let's build X" → brainstorming first, then implementation skills.
"Fix this bug" → debugging first, then domain-specific skills.

## Skill Types

**Rigid** (TDD, debugging): Follow exactly. Don't adapt away discipline.

**Flexible** (patterns): Adapt principles to context.

The skill itself tells you which.

## User Instructions

Instructions say WHAT, not HOW. "Add X" or "Fix Y" doesn't mean skip workflows.

codex
Using `superpowers-using-superpowers` and `sdlc` for this SDLC boundary review. I’m checking the live diff now rather than relying on the pasted diff, because the review output indicates the branch may have changed after the first pass.
exec
/bin/zsh -lc "nl -ba tests/integration/review_diag_display_spec.lua | sed -n '1,180p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
     1    -- Integration tests for the review-diagnostic inline display toggle (#133 M6).
     2
     3    local dd = require("parley.skills.review.diag_display")
     4
     5    local function ns_cfg()
     6        return vim.diagnostic.config(nil, require("parley.skill_render").diag_namespace())
     7    end
     8
     9    local function display_marks(buf)
    10        local display_ns = vim.api.nvim_create_namespace("parley_diagnostic_virtual_lines")
    11        return vim.api.nvim_buf_get_extmarks(buf, display_ns, 0, -1, { details = true })
    12    end
    13
    14    describe("review.diag_display", function()
    15        after_each(function()
    16            dd.set(true) -- restore default for other specs
    17            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    18                if vim.api.nvim_buf_is_valid(buf) then
    19                    pcall(vim.diagnostic.reset, require("parley.skill_render").diag_namespace(), buf)
    20                end
    21            end
    22        end)
    23
    24        it("toggles the enabled state", function()
    25            dd.set(true)
    26            assert.is_true(dd.is_enabled())
    27            assert.is_false(dd.toggle())
    28            assert.is_false(dd.is_enabled())
    29            assert.is_true(dd.toggle())
    30            assert.is_true(dd.is_enabled())
    31        end)
    32
    33        it("configures Parley's custom current-line display on its namespace when on; off when disabled", function()
    34            dd.set(true)
    35            local on = ns_cfg()
    36            assert.is_false(on.virtual_lines) -- Parley owns its virtual-lines renderer.
    37            assert.is_truthy(on["parley/virtual_lines"])
    38            assert.is_false(on.virtual_text) -- inline single-line is never used
    39            dd.set(false)
    40            assert.is_false(ns_cfg()["parley/virtual_lines"])
    41        end)
    42
    43        it("renders current-line diagnostics from the left column without moving the diagnostic span", function()
    44            local skill_render = require("parley.skill_render")
    45            local diag_ns = skill_render.diag_namespace()
    46            local buf = vim.api.nvim_create_buf(false, true)
    47            vim.api.nvim_set_current_buf(buf)
    48            vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    49                string.rep("x", 120) .. " ACOS[^acos]",
    50            })
    51
    52            dd.set(true)
    53            vim.diagnostic.set(diag_ns, buf, { {
    54                lnum = 0,
    55                col = 121,
    56                end_lnum = 0,
    57                end_col = 132,
    58                message = "ACOS — Advertising Cost of Sales.",
    59                severity = vim.diagnostic.severity.INFO,
    60                source = "parley-footnote",
    61            } })
    62
    63            vim.wait(100, function()
    64                return #display_marks(buf) == 1
    65            end)
    66
    67            local marks = display_marks(buf)
    68            assert.are.equal(1, #marks)
    69            local details = marks[1][4]
    70            assert.is_true(details.virt_lines_leftcol)
    71            assert.are.equal("Diagnostics:", details.virt_lines[1][1][1])
    72            assert.are_not.equal(string.rep(" ", 121), details.virt_lines[1][1][1])
    73            assert.are.equal("ACOS — Advertising Cost of Sales.", details.virt_lines[2][1][1])
    74
    75            local diagnostics = vim.diagnostic.get(buf, { namespace = diag_ns })
    76            assert.are.equal(1, #diagnostics)
    77            assert.are.equal(0, diagnostics[1].lnum)
    78            assert.are.equal(121, diagnostics[1].col)
    79            assert.are.equal(0, diagnostics[1].end_lnum)
    80            assert.are.equal(132, diagnostics[1].end_col)
    81
    82            dd.set(false)
    83            assert.are.equal(0, #display_marks(buf))
    84            assert.are.equal(1, #vim.diagnostic.get(buf, { namespace = diag_ns }))
    85        end)
    86
    87        it("keeps a multi-line diagnostic visible anywhere inside its span", function()
    88            local skill_render = require("parley.skill_render")
    89            local diag_ns = skill_render.diag_namespace()
    90            local buf = vim.api.nvim_create_buf(false, true)
    91            vim.api.nvim_set_current_buf(buf)
    92            vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    93                "edited line one",
    94                "edited line two",
    95                "edited line three",
    96            })
    97
    98            dd.set(true)
    99            vim.diagnostic.set(diag_ns, buf, { {
   100                lnum = 0,
   101                col = 0,
   102                end_lnum = 2,
   103                end_col = 17,
   104                message = "review explanation",
   105                severity = vim.diagnostic.severity.INFO,
   106                source = "parley-skill",
   107            } })
   108            assert.are.equal(1, #display_marks(buf))
   109
   110            vim.api.nvim_win_set_cursor(0, { 2, 0 })
   111            vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
   112            assert.are.equal(1, #display_marks(buf), "span diagnostic should show on middle line")
   113
   114            vim.api.nvim_win_set_cursor(0, { 3, 0 })
   115            vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
   116            assert.are.equal(1, #display_marks(buf), "span diagnostic should show on final line")
   117        end)
   118    end)

exec
/bin/zsh -lc "nl -ba lua/parley/skills/review/diag_display.lua | sed -n '1,230p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
     1    -- diag_display.lua — inline display of Parley diagnostics (#133 M6, #173).
     2    --
     3    -- Controls how parley's review explanations render, scoped to parley's OWN
     4    -- diagnostic namespace (never touches the user's LSP / global diagnostics).
     5    -- Default ON: a custom diagnostic handler renders left-column virtual lines for
     6    -- the cursor's current diagnostic region, so long wrapped prose doesn't hide
     7    -- messages behind stock virtual-lines column indentation. `:ParleyShowDiagnostics`
     8    -- toggles it.
     9
    10    local M = {}
    11
    12    M.enabled = true -- default on (cursor-region auto-show)
    13
    14    local HANDLER_NAME = "parley/virtual_lines"
    15    local DISPLAY_NS = "parley_diagnostic_virtual_lines"
    16    local DISPLAY_AUGROUP = "parley_diagnostic_virtual_lines"
    17    local HEADER_HL = "ParleyDiagnosticVirtualLineHeader"
    18    local MESSAGE_HL = "ParleyDiagnosticVirtualLine"
    19
    20    local display_ns_id
    21    local display_augroup
    22
    23    -- Parley's review diagnostic namespace — single-sourced from skill_render (which
    24    -- owns the namespace) so the identity isn't a duplicated literal (#133 M6 review).
    25    local function ns()
    26        return require("parley.skill_render").diag_namespace()
    27    end
    28
    29    local function ensure_display()
    30        if not display_ns_id then
    31            display_ns_id = vim.api.nvim_create_namespace(DISPLAY_NS)
    32        end
    33        if not display_augroup then
    34            display_augroup = vim.api.nvim_create_augroup(DISPLAY_AUGROUP, { clear = true })
    35        end
    36        vim.api.nvim_set_hl(0, HEADER_HL, { link = "DiagnosticInfo" })
    37        vim.api.nvim_set_hl(0, MESSAGE_HL, { link = "DiagnosticFloatingInfo" })
    38    end
    39
    40    local function clear(buf)
    41        ensure_display()
    42        if vim.api.nvim_buf_is_valid(buf) then
    43            vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
    44            pcall(vim.api.nvim_clear_autocmds, { group = display_augroup, buffer = buf })
    45        end
    46    end
    47
    48    local function current_line_for(buf)
    49        if vim.api.nvim_get_current_buf() ~= buf then
    50            return nil
    51        end
    52        return vim.api.nvim_win_get_cursor(0)[1] - 1
    53    end
    54
    55    local function diagnostic_message_lines(diagnostic)
    56        local lines = {}
    57        for _, line in ipairs(vim.split(tostring(diagnostic.message or ""), "\n", { plain = true })) do
    58            table.insert(lines, { { line ~= "" and line or " ", MESSAGE_HL } })
    59        end
    60        if #lines == 0 then
    61            table.insert(lines, { { " ", MESSAGE_HL } })
    62        end
    63        return lines
    64    end
    65
    66    local function diagnostic_contains_line(diagnostic, line)
    67        local start_line = diagnostic.lnum or 0
    68        local end_line = diagnostic.end_lnum or start_line
    69        return line >= start_line and line <= end_line
    70    end
    71
    72    local function render(buf, diagnostics, current_line_only)
    73        ensure_display()
    74        if not vim.api.nvim_buf_is_valid(buf) then
    75            return
    76        end
    77        vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
    78
    79        local line = current_line_only and current_line_for(buf) or nil
    80        if current_line_only and not line then
    81            return
    82        end
    83
    84        local by_line = {}
    85        for _, diagnostic in ipairs(diagnostics or {}) do
    86            if not current_line_only or diagnostic_contains_line(diagnostic, line) then
    87                by_line[diagnostic.lnum] = by_line[diagnostic.lnum] or {}
    88                table.insert(by_line[diagnostic.lnum], diagnostic)
    89            end
    90        end
    91
    92        for lnum, line_diagnostics in pairs(by_line) do
    93            table.sort(line_diagnostics, function(a, b)
    94                return (a.col or 0) < (b.col or 0)
    95            end)
    96            local virt_lines = { { { "Diagnostics:", HEADER_HL } } }
    97            for _, diagnostic in ipairs(line_diagnostics) do
    98                vim.list_extend(virt_lines, diagnostic_message_lines(diagnostic))
    99            end
   100            vim.api.nvim_buf_set_extmark(buf, display_ns_id, lnum, 0, {
   101                virt_lines = virt_lines,
   102                virt_lines_leftcol = true,
   103                virt_lines_above = false,
   104            })
   105        end
   106    end
   107
   108    local function register_handler()
   109        ensure_display()
   110        vim.diagnostic.handlers[HANDLER_NAME] = {
   111            show = function(namespace, bufnr, diagnostics, opts)
   112                if namespace ~= ns() then
   113                    return
   114                end
   115                bufnr = vim._resolve_bufnr(bufnr)
   116                local handler_opts = opts and opts[HANDLER_NAME] or {}
   117                local current_line_only = handler_opts.current_line == true
   118                clear(bufnr)
   119                if current_line_only then
   120                    vim.api.nvim_create_autocmd("CursorMoved", {
   121                        buffer = bufnr,
   122                        group = display_augroup,
   123                        callback = function()
   124                            render(bufnr, diagnostics, true)
   125                        end,
   126                    })
   127                end
   128                render(bufnr, diagnostics, current_line_only)
   129            end,
   130            hide = function(namespace, bufnr)
   131                if namespace ~= ns() then
   132                    return
   133                end
   134                clear(vim._resolve_bufnr(bufnr))
   135            end,
   136        }
   137    end
   138
   139    function M.refresh(buf)
   140        if not M.enabled then
   141            return
   142        end
   143        buf = buf or vim.api.nvim_get_current_buf()
   144        render(buf, vim.diagnostic.get(buf, { namespace = ns() }), true)
   145    end
   146
   147    --- Apply the inline-display config for parley's review namespace.
   148    --- @param on boolean
   149    function M.set(on)
   150        M.enabled = on and true or false
   151        register_handler()
   152        vim.diagnostic.config({
   153            [HANDLER_NAME] = M.enabled and { current_line = true } or false,
   154            virtual_lines = false,
   155            virtual_text = false,
   156        }, ns())
   157        if M.enabled then
   158            M.refresh()
   159        else
   160            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
   161                clear(buf)
   162            end
   163        end
   164    end
   165
   166    --- Toggle inline display; returns the new state.
   167    --- @return boolean
   168    function M.toggle()
   169        M.set(not M.enabled)
   170        return M.enabled
   171    end
   172
   173    --- Is inline display currently enabled?
   174    --- @return boolean
   175    function M.is_enabled()
   176        return M.enabled
   177    end
   178
   179    return M

exec
/bin/zsh -lc 'git diff --stat b9094e9bfc89b0f27013c6fd41c38a83b8b61510..HEAD && git diff --name-only b9094e9bfc89b0f27013c6fd41c38a83b8b61510..HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
 atlas/chat/inline_define.md                        |   26 +-
 atlas/modes/review.md                              |   16 +-
 lua/parley/skills/review/diag_display.lua          |  147 +-
 tests/integration/review_diag_display_spec.lua     |   93 +-
 .../000173-diagnostic-virtual-lines-leftcol.md     |   83 +-
 ...iagnostic-virtual-lines-leftcol-close-review.md | 3629 ++++++++++++++++++++
 ...000173-diagnostic-virtual-lines-leftcol-plan.md |  105 +
 7 files changed, 4069 insertions(+), 30 deletions(-)
atlas/chat/inline_define.md
atlas/modes/review.md
lua/parley/skills/review/diag_display.lua
tests/integration/review_diag_display_spec.lua
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md
workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md
workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md

exec
/bin/zsh -lc "sed -n '1,180p' workshop/issues/000173-diagnostic-virtual-lines-leftcol.md && printf '\\n---PLAN---\\n' && sed -n '1,160p' workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
---
id: 000173
status: working
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 0.38
started: 2026-07-08T13:21:02-07:00
---

# diagnostic virtual lines blank on long wrapped markdown

## Problem

After #172, managed markdown footnotes are correctly restored as diagnostics,
but their inline virtual-line display can look blank on long wrapped markdown
paragraphs. The diagnostic payload is present and floats display it, but
Neovim's built-in `virtual_lines` handler prefixes the rendered message with
spaces equal to the diagnostic byte column. On a long prose line, the selected
text may be visible on a wrapped screen row while the virtual-line message starts
far to the right outside the viewport.

## Spec

- Parley diagnostics should remain anchored on the selected text / `[^footnote]`
  span so signs, underline, cursor-line filtering, jumps, and floats keep their
  existing behavior.
- The inline diagnostic display for Parley's namespace should render current-line
  messages from the left column, not from the diagnostic byte column.
- The display text should keep the existing wrapped diagnostic message and a
  clear `Diagnostics:` label.
- The fix should apply to the shared Parley diagnostic namespace, covering review
  diagnostics and footnote diagnostics without changing global/LSP diagnostics.

ARCH-DRY: keep one Parley diagnostic display controller in
`skills/review/diag_display.lua`; do not add a separate footnote-only renderer.
ARCH-PURE: no parser/data changes; keep the change in the thin Neovim display
shell and test its extmark output directly.
ARCH-PURPOSE: solve the actual blank-row symptom for long wrapped markdown, not
only color the hidden text.

## Done when

- A Parley diagnostic on a long line with a high column renders a visible
  left-column virtual line.
- The diagnostic itself remains at its original span for underline/float/jump
  behavior.
- Toggling `:ParleyShowDiagnostics` still disables/enables the inline display.
- Focused tests and full verification pass.

## Estimate

Produced via `estimate-logic-v3.1` against the repo-local calibration source
reported by `sdlc estimate-source` (stale but canonical for this repo).

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.04 impl=0.00
item: lua-neovim design=0.06 impl=0.18
item: milestone-review design=0.00 impl=0.10
total: 0.38
```

## Plan

- [x] Add failing tests proving Parley virtual lines render from the left column.
- [x] Implement the Parley-owned virtual-line display handler.
- [x] Update atlas/issue log and run verification.

## Log

### 2026-07-08
- Root cause: a headless reproduction of Neovim's stock diagnostic virtual-lines
  handler showed `virt_lines = { { { string.rep(" ", diagnostic.col), "" }, ... } }`
  with `virt_lines_overflow = "scroll"`, so long wrapped markdown can display a
  blank inserted row while the message starts outside the viewport.
- Red test: `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"`
  failed because `diag_display` still configured stock `virtual_lines` and no
  `parley_diagnostic_virtual_lines` extmark was rendered.
- Implemented `parley/virtual_lines`, a custom diagnostic handler scoped to the
  Parley namespace. It renders a left-column `Diagnostics:` virtual-line block,
  updates on `CursorMoved`, disables stock virtual lines for Parley, and leaves
  the underlying diagnostic span unchanged.
- Focused green: `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"`.
- Final green: `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`;
  `git diff --check -- lua/parley/skills/review/diag_display.lua
  tests/integration/review_diag_display_spec.lua atlas/modes/review.md
  atlas/chat/inline_define.md
  workshop/issues/000173-diagnostic-virtual-lines-leftcol.md
  workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md`; `make test`.
- Boundary review returned REWORK: the custom renderer used `diagnostic.lnum ==
  cursor_line`, which regressed review diagnostics spanning `lnum..end_lnum`.
- Added a regression test for a multi-line review diagnostic, changed the
  current-line predicate to include `end_lnum`, and updated the stale module
  header comment.
- Re-verified: `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"`;
  `nvim --headless -c "PlenaryBustedFile tests/unit/tools_builtin_find_spec.lua"`;
  `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`;
  `git diff --check -- lua/parley/skills/review/diag_display.lua
  tests/integration/review_diag_display_spec.lua atlas/modes/review.md
  atlas/chat/inline_define.md
  workshop/issues/000173-diagnostic-virtual-lines-leftcol.md
  workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md`; `make test`.

---PLAN---
# Diagnostic Virtual Lines Left Column Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Parley's inline diagnostic display visible on long wrapped markdown lines by rendering diagnostic virtual lines from the left column.

**Architecture:** Keep diagnostic data unchanged: spans stay anchored to selected text and footnote references. Replace only Parley's namespace display shell in `diag_display.lua`, so global/LSP diagnostics still use Neovim defaults. This follows ARCH-DRY by keeping one Parley display controller and ARCH-PURE by avoiding parser/data changes.

**Tech Stack:** Lua, Neovim diagnostics, extmarks, Plenary/Busted tests.

---

## Core Concepts

### Pure Entities

| Name | Lives in | Status |
|------|----------|--------|
| `ParleyDiagnosticMessageLines` | `lua/parley/skills/review/diag_display.lua` | new |

- **ParleyDiagnosticMessageLines** — deterministic conversion from a diagnostic message string into visible virtual-line rows with a `Diagnostics:` header.
  - **Relationships:** 1:N from one diagnostic message to display rows.
  - **DRY rationale:** Both review diagnostics and footnote diagnostics consume the same Parley namespace display.
  - **Future extensions:** If Parley later adds source-specific labels, this formatter is the one place to widen.

### Integration Points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `ParleyDiagnosticVirtualLines` | `lua/parley/skills/review/diag_display.lua` | modified | Neovim extmarks |

- **ParleyDiagnosticVirtualLines** — Parley-owned inline diagnostic renderer scoped to `skill_render.diag_namespace()`.
  - **Injected into:** `diag_display.set(on)`; toggling still owns all inline display setup.
  - **Future extensions:** Can add color overrides without changing diagnostic producers.

## Chunk 1: Left-Column Renderer

**Files:**
- Modify: `lua/parley/skills/review/diag_display.lua`
- Modify: `tests/integration/review_diag_display_spec.lua`
- Modify: `atlas/modes/review.md`
- Modify: `atlas/chat/inline_define.md`
- Modify: `workshop/issues/000173-diagnostic-virtual-lines-leftcol.md`

- [x] **Step 1: Write failing tests**

Add integration coverage that:
- Sets a Parley diagnostic at a high column on a long line.
- Enables `diag_display`.
- Asserts the generated display extmark has `virt_lines_leftcol = true`.
- Asserts the first virtual-line chunk is `Diagnostics:` instead of leading spaces.
- Asserts `dd.set(false)` clears the Parley display extmark while leaving the diagnostic data intact.

Run:

```bash
nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"
```

Expected: FAIL because the stock diagnostic handler emits leading-space virtual lines and `diag_display` has no custom extmark namespace.

- [x] **Step 2: Implement the renderer**

In `lua/parley/skills/review/diag_display.lua`:
- Add a private display namespace.
- Add a private function that clears Parley diagnostic virtual-line extmarks.
- Add a private render function that reads diagnostics from `skill_render.diag_namespace()`, filters to the current cursor line, and writes `virt_lines` with `virt_lines_leftcol = true`.
- Configure Neovim diagnostics for the Parley namespace with `virtual_lines = false`, `virtual_text = false`, and existing signs/underline behavior.
- Register a buffer-local `CursorMoved` autocmd for visible Parley buffers so current-line behavior keeps updating.

- [x] **Step 3: Run green focused tests**

Run:

```bash
nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"
```

Expected: PASS.

- [x] **Step 4: Update docs and issue log**

Update atlas text that says Parley uses built-in diagnostic `virtual_lines` so it instead describes the Parley-owned left-column inline renderer. Record red/green evidence in the issue log and tick plan items.

- [x] **Step 5: Final verification**

Run:

```bash
git diff --check -- lua/parley/skills/review/diag_display.lua tests/integration/review_diag_display_spec.lua atlas/modes/review.md atlas/chat/inline_define.md workshop/issues/000173-diagnostic-virtual-lines-leftcol.md workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md
make test
```

Expected: all pass.

## Revisions

### 2026-07-08 — Boundary review REWORK

- **Reason:** The first custom renderer filtered current-line diagnostics only by
  `diagnostic.lnum`, which hid review diagnostics when the cursor was inside a
  multi-line diagnostic span but not on the start line.
- **Delta:** Preserve current-line behavior over the full diagnostic range
  `lnum..end_lnum`; add integration coverage that moves the cursor to the middle
  and final lines of a multi-line review diagnostic.

codex
The earlier blocker appears addressed in code: `diagnostic_contains_line` now uses `lnum..end_lnum`, and the integration test moves through the middle and final lines. I’m checking verification and the newly added close-review artifact before issuing the verdict.
exec
/bin/zsh -lc "sed -n '1,80p' workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md && wc -l workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
# Boundary Review — parley.nvim#173 (whole-issue close)

| field | value |
|-------|-------|
| issue | 173 — diagnostic virtual lines blank on long wrapped markdown |
| repo | parley.nvim |
| issue file | workshop/issues/000173-diagnostic-virtual-lines-leftcol.md |
| boundary | whole-issue close |
| milestone | — |
| window | b9094e9bfc89b0f27013c6fd41c38a83b8b61510..HEAD |
| command | sdlc close --issue 173 |
| reviewer | codex |
| timestamp | 2026-07-08T13:29:14-07:00 |
| verdict | REWORK |

## Review

Reading additional input from stdin...
OpenAI Codex v0.142.5
--------
workdir: /Users/xianxu/workspace/parley.nvim
model: gpt-5.5
provider: openai
approval: never
sandbox: workspace-write [workdir, /tmp, $TMPDIR, /tmp] (network access enabled)
reasoning effort: none
reasoning summaries: none
session id: 019f4369-b302-73e2-9157-1992fcc2eca0
--------
user
# Code review — the one SDLC boundary review

You are conducting a fresh-context code review at a development boundary —
whole-issue close — in the **parley.nvim** repository.

- repository: parley.nvim   (root: /Users/xianxu/workspace/parley.nvim)
- issue:      parley.nvim#173   (file: workshop/issues/000173-diagnostic-virtual-lines-leftcol.md)
- window:     Base: b9094e9bfc89b0f27013c6fd41c38a83b8b61510   Head: HEAD

Review the **parley.nvim** repo and its tracker — the ariadne base-layer repo itself (changes here propagate to dependent repos). Do not assume any
other repository or apply another repo's conventions.

You have no prior session context — that is the anti-collusion property. Verify
behavior against the issue's documented Spec/Plan and the code itself; do NOT
take the implementor's word in commit messages or docs at face value. Tools are
read-only: report findings precisely; the main agent (which has session context)
applies the fixes, commits, and re-runs.

Read the diff against the issue's Spec + Plan, then work the checklist below.
Categorize every finding by severity — not everything is Critical; a nitpick
marked Critical is noise.

  Critical (must fix before crossing the boundary)
    - correctness bugs; crashes / panics on unexpected input
    - behavior drift from stated contracts (for ports of existing code where
      byte-faithfulness was promised, diff against the source)
    - silent error swallowing where the source raised
  Important (fix before the boundary if cheap)
    - API design of newly-introduced internal packages (downstream work will
      consume them; is the surface stable?)
    - missing test coverage that would catch the kind of bug shipped
    - inconsistent error handling across the diff
  Minor (note for future)
    - style nits, naming, comment density; performance only if hot-path

## Review checklist

Code quality
  - Clean separation of concerns; edge cases handled (empty / nil / unexpected).
  - Proper error handling — no silent swallowing where the source raised.
  - No duplicated logic / copy-paste that should be a shared helper.

Testing
  - Tests pin real logic, not mocks reasserting the implementation.
  - The kind of bug this diff could ship is covered.
  - PURE entities tested without IO; INTEGRATION via injected fakes (see below).

Requirements traceability
  - Every Plan checklist item this boundary claims is actually delivered.
  - Implementation matches the Spec; no undeclared scope creep.
    3629 workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md

exec
/bin/zsh -lc 'git diff --unified=80 b9094e9bfc89b0f27013c6fd41c38a83b8b61510..HEAD -- lua/parley/skills/review/diag_display.lua tests/integration/review_diag_display_spec.lua' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
diff --git a/lua/parley/skills/review/diag_display.lua b/lua/parley/skills/review/diag_display.lua
index 4617a35..a63de85 100644
--- a/lua/parley/skills/review/diag_display.lua
+++ b/lua/parley/skills/review/diag_display.lua
@@ -1,42 +1,179 @@
--- diag_display.lua — inline display of review "why" diagnostics (#133 M6).
+-- diag_display.lua — inline display of Parley diagnostics (#133 M6, #173).
 --
 -- Controls how parley's review explanations render, scoped to parley's OWN
 -- diagnostic namespace (never touches the user's LSP / global diagnostics).
--- Default ON: `virtual_lines { current_line = true }`, so the (hard-wrapped) why
--- auto-expands below an edit when the cursor is in that edit's region, and hides
--- otherwise. `:ParleyShowDiagnostics` toggles it.
+-- Default ON: a custom diagnostic handler renders left-column virtual lines for
+-- the cursor's current diagnostic region, so long wrapped prose doesn't hide
+-- messages behind stock virtual-lines column indentation. `:ParleyShowDiagnostics`
+-- toggles it.

 local M = {}

 M.enabled = true -- default on (cursor-region auto-show)

+local HANDLER_NAME = "parley/virtual_lines"
+local DISPLAY_NS = "parley_diagnostic_virtual_lines"
+local DISPLAY_AUGROUP = "parley_diagnostic_virtual_lines"
+local HEADER_HL = "ParleyDiagnosticVirtualLineHeader"
+local MESSAGE_HL = "ParleyDiagnosticVirtualLine"
+
+local display_ns_id
+local display_augroup
+
 -- Parley's review diagnostic namespace — single-sourced from skill_render (which
 -- owns the namespace) so the identity isn't a duplicated literal (#133 M6 review).
 local function ns()
     return require("parley.skill_render").diag_namespace()
 end

+local function ensure_display()
+    if not display_ns_id then
+        display_ns_id = vim.api.nvim_create_namespace(DISPLAY_NS)
+    end
+    if not display_augroup then
+        display_augroup = vim.api.nvim_create_augroup(DISPLAY_AUGROUP, { clear = true })
+    end
+    vim.api.nvim_set_hl(0, HEADER_HL, { link = "DiagnosticInfo" })
+    vim.api.nvim_set_hl(0, MESSAGE_HL, { link = "DiagnosticFloatingInfo" })
+end
+
+local function clear(buf)
+    ensure_display()
+    if vim.api.nvim_buf_is_valid(buf) then
+        vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
+        pcall(vim.api.nvim_clear_autocmds, { group = display_augroup, buffer = buf })
+    end
+end
+
+local function current_line_for(buf)
+    if vim.api.nvim_get_current_buf() ~= buf then
+        return nil
+    end
+    return vim.api.nvim_win_get_cursor(0)[1] - 1
+end
+
+local function diagnostic_message_lines(diagnostic)
+    local lines = {}
+    for _, line in ipairs(vim.split(tostring(diagnostic.message or ""), "\n", { plain = true })) do
+        table.insert(lines, { { line ~= "" and line or " ", MESSAGE_HL } })
+    end
+    if #lines == 0 then
+        table.insert(lines, { { " ", MESSAGE_HL } })
+    end
+    return lines
+end
+
+local function diagnostic_contains_line(diagnostic, line)
+    local start_line = diagnostic.lnum or 0
+    local end_line = diagnostic.end_lnum or start_line
+    return line >= start_line and line <= end_line
+end
+
+local function render(buf, diagnostics, current_line_only)
+    ensure_display()
+    if not vim.api.nvim_buf_is_valid(buf) then
+        return
+    end
+    vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
+
+    local line = current_line_only and current_line_for(buf) or nil
+    if current_line_only and not line then
+        return
+    end
+
+    local by_line = {}
+    for _, diagnostic in ipairs(diagnostics or {}) do
+        if not current_line_only or diagnostic_contains_line(diagnostic, line) then
+            by_line[diagnostic.lnum] = by_line[diagnostic.lnum] or {}
+            table.insert(by_line[diagnostic.lnum], diagnostic)
+        end
+    end
+
+    for lnum, line_diagnostics in pairs(by_line) do
+        table.sort(line_diagnostics, function(a, b)
+            return (a.col or 0) < (b.col or 0)
+        end)
+        local virt_lines = { { { "Diagnostics:", HEADER_HL } } }
+        for _, diagnostic in ipairs(line_diagnostics) do
+            vim.list_extend(virt_lines, diagnostic_message_lines(diagnostic))
+        end
+        vim.api.nvim_buf_set_extmark(buf, display_ns_id, lnum, 0, {
+            virt_lines = virt_lines,
+            virt_lines_leftcol = true,
+            virt_lines_above = false,
+        })
+    end
+end
+
+local function register_handler()
+    ensure_display()
+    vim.diagnostic.handlers[HANDLER_NAME] = {
+        show = function(namespace, bufnr, diagnostics, opts)
+            if namespace ~= ns() then
+                return
+            end
+            bufnr = vim._resolve_bufnr(bufnr)
+            local handler_opts = opts and opts[HANDLER_NAME] or {}
+            local current_line_only = handler_opts.current_line == true
+            clear(bufnr)
+            if current_line_only then
+                vim.api.nvim_create_autocmd("CursorMoved", {
+                    buffer = bufnr,
+                    group = display_augroup,
+                    callback = function()
+                        render(bufnr, diagnostics, true)
+                    end,
+                })
+            end
+            render(bufnr, diagnostics, current_line_only)
+        end,
+        hide = function(namespace, bufnr)
+            if namespace ~= ns() then
+                return
+            end
+            clear(vim._resolve_bufnr(bufnr))
+        end,
+    }
+end
+
+function M.refresh(buf)
+    if not M.enabled then
+        return
+    end
+    buf = buf or vim.api.nvim_get_current_buf()
+    render(buf, vim.diagnostic.get(buf, { namespace = ns() }), true)
+end
+
 --- Apply the inline-display config for parley's review namespace.
 --- @param on boolean
 function M.set(on)
     M.enabled = on and true or false
+    register_handler()
     vim.diagnostic.config({
-        virtual_lines = M.enabled and { current_line = true } or false,
+        [HANDLER_NAME] = M.enabled and { current_line = true } or false,
+        virtual_lines = false,
         virtual_text = false,
     }, ns())
+    if M.enabled then
+        M.refresh()
+    else
+        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
+            clear(buf)
+        end
+    end
 end

 --- Toggle inline display; returns the new state.
 --- @return boolean
 function M.toggle()
     M.set(not M.enabled)
     return M.enabled
 end

 --- Is inline display currently enabled?
 --- @return boolean
 function M.is_enabled()
     return M.enabled
 end

 return M
diff --git a/tests/integration/review_diag_display_spec.lua b/tests/integration/review_diag_display_spec.lua
index 7950705..f33e06c 100644
--- a/tests/integration/review_diag_display_spec.lua
+++ b/tests/integration/review_diag_display_spec.lua
@@ -1,31 +1,118 @@
 -- Integration tests for the review-diagnostic inline display toggle (#133 M6).

 local dd = require("parley.skills.review.diag_display")

 local function ns_cfg()
     return vim.diagnostic.config(nil, require("parley.skill_render").diag_namespace())
 end

+local function display_marks(buf)
+    local display_ns = vim.api.nvim_create_namespace("parley_diagnostic_virtual_lines")
+    return vim.api.nvim_buf_get_extmarks(buf, display_ns, 0, -1, { details = true })
+end
+
 describe("review.diag_display", function()
     after_each(function()
         dd.set(true) -- restore default for other specs
+        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
+            if vim.api.nvim_buf_is_valid(buf) then
+                pcall(vim.diagnostic.reset, require("parley.skill_render").diag_namespace(), buf)
+            end
+        end
     end)

     it("toggles the enabled state", function()
         dd.set(true)
         assert.is_true(dd.is_enabled())
         assert.is_false(dd.toggle())
         assert.is_false(dd.is_enabled())
         assert.is_true(dd.toggle())
         assert.is_true(dd.is_enabled())
     end)

-    it("configures virtual_lines current_line on parley's namespace when on; off when disabled", function()
+    it("configures Parley's custom current-line display on its namespace when on; off when disabled", function()
         dd.set(true)
         local on = ns_cfg()
-        assert.is_truthy(on.virtual_lines) -- { current_line = true }
+        assert.is_false(on.virtual_lines) -- Parley owns its virtual-lines renderer.
+        assert.is_truthy(on["parley/virtual_lines"])
         assert.is_false(on.virtual_text) -- inline single-line is never used
         dd.set(false)
-        assert.is_false(ns_cfg().virtual_lines)
+        assert.is_false(ns_cfg()["parley/virtual_lines"])
+    end)
+
+    it("renders current-line diagnostics from the left column without moving the diagnostic span", function()
+        local skill_render = require("parley.skill_render")
+        local diag_ns = skill_render.diag_namespace()
+        local buf = vim.api.nvim_create_buf(false, true)
+        vim.api.nvim_set_current_buf(buf)
+        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
+            string.rep("x", 120) .. " ACOS[^acos]",
+        })
+
+        dd.set(true)
+        vim.diagnostic.set(diag_ns, buf, { {
+            lnum = 0,
+            col = 121,
+            end_lnum = 0,
+            end_col = 132,
+            message = "ACOS — Advertising Cost of Sales.",
+            severity = vim.diagnostic.severity.INFO,
+            source = "parley-footnote",
+        } })
+
+        vim.wait(100, function()
+            return #display_marks(buf) == 1
+        end)
+
+        local marks = display_marks(buf)
+        assert.are.equal(1, #marks)
+        local details = marks[1][4]
+        assert.is_true(details.virt_lines_leftcol)
+        assert.are.equal("Diagnostics:", details.virt_lines[1][1][1])
+        assert.are_not.equal(string.rep(" ", 121), details.virt_lines[1][1][1])
+        assert.are.equal("ACOS — Advertising Cost of Sales.", details.virt_lines[2][1][1])
+
+        local diagnostics = vim.diagnostic.get(buf, { namespace = diag_ns })
+        assert.are.equal(1, #diagnostics)
+        assert.are.equal(0, diagnostics[1].lnum)
+        assert.are.equal(121, diagnostics[1].col)
+        assert.are.equal(0, diagnostics[1].end_lnum)
+        assert.are.equal(132, diagnostics[1].end_col)
+
+        dd.set(false)
+        assert.are.equal(0, #display_marks(buf))
+        assert.are.equal(1, #vim.diagnostic.get(buf, { namespace = diag_ns }))
+    end)
+
+    it("keeps a multi-line diagnostic visible anywhere inside its span", function()
+        local skill_render = require("parley.skill_render")
+        local diag_ns = skill_render.diag_namespace()
+        local buf = vim.api.nvim_create_buf(false, true)
+        vim.api.nvim_set_current_buf(buf)
+        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
+            "edited line one",
+            "edited line two",
+            "edited line three",
+        })
+
+        dd.set(true)
+        vim.diagnostic.set(diag_ns, buf, { {
+            lnum = 0,
+            col = 0,
+            end_lnum = 2,
+            end_col = 17,
+            message = "review explanation",
+            severity = vim.diagnostic.severity.INFO,
+            source = "parley-skill",
+        } })
+        assert.are.equal(1, #display_marks(buf))
+
+        vim.api.nvim_win_set_cursor(0, { 2, 0 })
+        vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
+        assert.are.equal(1, #display_marks(buf), "span diagnostic should show on middle line")
+
+        vim.api.nvim_win_set_cursor(0, { 3, 0 })
+        vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
+        assert.are.equal(1, #display_marks(buf), "span diagnostic should show on final line")
     end)
 end)

exec
/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"' in /Users/xianxu/workspace/parley.nvim
 succeeded in 1439ms:

LuaSnip: could not open log at /Users/xianxu/.local/state/nvim/luasnip.log. Not logging for this session.
Parley.nvim: Failed to open file for writing: /Users/xianxu/.local/share/nvim/parley/persisted/state.jsonScheduling: tests/integration/review_diag_display_spec.lua

========================================
Testing:     /Users/xianxu/workspace/parley.nvim/tests/integration/review_diag_display_spec.lua
Success    ||    review.diag_display toggles the enabled state
Success    ||    review.diag_display configures Parley's custom current-line display on its namespace when on; off when disabled
Success    ||    review.diag_display renders current-line diagnostics from the left column without moving the diagnostic span
Success    ||    review.diag_display keeps a multi-line diagnostic visible anywhere inside its span

Success:     4
Failed :     0
Errors :     0
========================================

codex
There’s now a separate verification blocker: `git diff --check` fails on the committed close-review transcript, mostly captured terminal whitespace/control output. I’m running the full test target as well so the verdict separates code behavior from repository hygiene.
exec
/bin/zsh -lc "rg -n \"Final green|Re-verified|make test|git diff --check|verdict \\| REWORK|Tests Failed|line2 marks 0\" workshop/issues/000173-diagnostic-virtual-lines-leftcol.md workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:87:- Final green: `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`;
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:88:  `git diff --check -- lua/parley/skills/review/diag_display.lua
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:92:  workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md`; `make test`.
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:98:- Re-verified: `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"`;
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:101:  `git diff --check -- lua/parley/skills/review/diag_display.lua
workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:105:  workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md`; `make test`.
workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md:14:| verdict | REWORK |
workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md:640:+git diff --check -- lua/parley/skills/review/diag_display.lua tests/integration/review_diag_display_spec.lua atlas/modes/review.md atlas/chat/inline_define.md workshop/issues/000173-diagnostic-virtual-lines-leftcol.md workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md
workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md:641:+make test
workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md:914:- When adding ONLY new files (no modifications to existing code), regression risk in untouched modules is zero. A full `make test` regression gate is belt-and-suspenders, not load-bearing — individual file verification suffices if you can't run the full suite.
workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md:925:- Run `make test-changed` after spec doc changes
workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md:995:- **Run the FULL `make test` (lint + unit + integration) before claiming "suite green" in `--verified` — running specs individually skips the lint gate.** This session I ran each `PlenaryBustedFile` spec directly (all green) and wrote "go test/full suite green" in the close evidence — but never ran `make test`, whose FIRST target is `lint` (luacheck). A new `while pos <= #line do` (every branch returns → luacheck 542 "loop executed at most once") failed luacheck, so `make test` was RED at the gate while my Log claimed green. The boundary review caught it (FIX-THEN-SHIP), but nothing *prevented* the premature claim. Rule: the evidence for "green" is a full `make test` exit 0, not a hand-picked set of specs; individual `PlenaryBustedFile` runs are for the red→green TDD loop, not the final gate. (Bonus: luacheck flags a `while` whose body always returns — use `if` and let the iterator's repeated closure-calls do the looping.)
workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md:1000:- **Raw `nvim_buf_set_text` is arch-forbidden (empty allow-list in `tests/arch/buffer_mutation_spec.lua`); `nvim_buf_set_lines` is allowed in `init.lua`.** #90's buffer-mutation boundary confines span edits to `buffer_edit.lua` (set_text allow-list is `{}` = zero uses). My first R1 cut used `nvim_buf_set_text` for the `[term]` wrap → `make test` red on the arch spec (lint was clean, so I only caught it at the full-suite run, not the unit loop). Fix: wrap via `nvim_buf_set_lines` (rewrite the affected whole line(s)) — the same primitive `drill_in_visual` already uses to wrap a selection, and it's on the set_lines allow-list for `init.lua`. Rule: before reaching for `nvim_buf_set_text`/`set_lines` in a non-`buffer_edit` file, check `tests/arch/buffer_mutation_spec.lua` — prefer the set_lines whole-line rewrite that existing wrappers use.
workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md:1127:- Final green: `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`;
workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md:1128:  `git diff --check -- lua/parley/skills/review/diag_display.lua
workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md:1132:  workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md`; `make test`.
workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md:1226:git diff --check -- lua/parley/skills/review/diag_display.lua tests/integration/review_diag_display_spec.lua atlas/modes/review.md atlas/chat/inline_define.md workshop/issues/000173-diagnostic-virtual-lines-leftcol.md workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md
workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md:1227:make test
workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md:1250:/bin/zsh -lc 'git diff --check b9094e9bfc89b0f27013c6fd41c38a83b8b61510..HEAD' in /Users/xianxu/workspace/parley.nvim
workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md:2435:line2 marks 0
workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md:2849:+- Final green: `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`;
workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md:2850:+  `git diff --check -- lua/parley/skills/review/diag_display.lua
workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md:2854:+  workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md`; `make test`.
workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md:2950:+git diff --check -- lua/parley/skills/review/diag_display.lua tests/integration/review_diag_display_spec.lua atlas/modes/review.md atlas/chat/inline_define.md workshop/issues/000173-diagnostic-virtual-lines-leftcol.md workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md
workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md:2951:+make test
workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md:2985:workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:92:  workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md`; `make test`.
workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md:3003:workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:90:git diff --check -- lua/parley/skills/review/diag_display.lua tests/integration/review_diag_display_spec.lua atlas/modes/review.md atlas/chat/inline_define.md workshop/issues/000173-diagnostic-virtual-lines-leftcol.md workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md
workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md:3126:/bin/zsh -lc 'make test' in /Users/xianxu/workspace/parley.nvim
workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md:3481:  Tests Failed. Exit: 1
workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md:3498:`make test` is not green in this checkout: lint and most tests pass, but `tests/unit/tools_builtin_find_spec.lua` fails on the command-substitution-as-data case. That file is outside this diff, so I’m treating it as verification evidence to report rather than attributing it to the diagnostic change.
workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md:3568:- `workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:86` claims final `make test` green, but my `make test` run exits 2: `tests/unit/tools_builtin_find_spec.lua` fails at line 30 in “treats command substitution text in name as data”. That file is outside this diff, so I am not attributing causality to #173, but the boundary evidence is currently false/stale. Re-run after resolving or explicitly record the exception before close.
workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md:3576:Focused `review_diag_display_spec.lua` passes. Missing coverage is the multi-line `end_lnum` current-region behavior, which is exactly the regression above. Full `make test` is not green in this checkout due to the unrelated `tools_builtin_find_spec.lua` failure.
workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md:3587:- Update the verification log after `make test` is actually green or after the unrelated failure is explicitly handled.
workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md:3610:- `workshop/issues/000173-diagnostic-virtual-lines-leftcol.md:86` claims final `make test` green, but my `make test` run exits 2: `tests/unit/tools_builtin_find_spec.lua` fails at line 30 in “treats command substitution text in name as data”. That file is outside this diff, so I am not attributing causality to #173, but the boundary evidence is currently false/stale. Re-run after resolving or explicitly record the exception before close.
workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md:3618:Focused `review_diag_display_spec.lua` passes. Missing coverage is the multi-line `end_lnum` current-region behavior, which is exactly the regression above. Full `make test` is not green in this checkout due to the unrelated `tools_builtin_find_spec.lua` failure.
workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md:3629:- Update the verification log after `make test` is actually green or after the unrelated failure is explicitly handled.
workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:90:git diff --check -- lua/parley/skills/review/diag_display.lua tests/integration/review_diag_display_spec.lua atlas/modes/review.md atlas/chat/inline_define.md workshop/issues/000173-diagnostic-virtual-lines-leftcol.md workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md
workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md:91:make test

exec
/bin/zsh -lc "git diff --unified=40 b9094e9bfc89b0f27013c6fd41c38a83b8b61510..HEAD -- atlas/chat/inline_define.md atlas/modes/review.md workshop/issues/000173-diagnostic-virtual-lines-leftcol.md workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md | sed -n '1,260p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
diff --git a/atlas/chat/inline_define.md b/atlas/chat/inline_define.md
index 270e924..6df2cf4 100644
--- a/atlas/chat/inline_define.md
+++ b/atlas/chat/inline_define.md
@@ -1,86 +1,86 @@
 # Inline Term Definition

 Select a phrase in a chat transcript, press **`<M-CR>`** (visual mode), and a
-concise, context-aware definition appears as an inline diagnostic (grey
-`virtual_lines`) under the phrase. The selected text stays in place and gets a
-markdown footnote reference (`ASIN[^asin]`), while the definition is stored in a
-managed footnote footer at the end of the chat transcript. Persisted managed
-footnotes are rehydrated into diagnostics when any markdown buffer is entered or
-refreshed. The whole new annotation is **undoable** — `u` reverts the footnote
-edit and clears both decorations (see Undo below). For jargon you don't know
-(e.g. `ASIN`), it's a one-keystroke lookup. Added in
+concise, context-aware definition appears as an inline diagnostic under the
+phrase. The selected text stays in place and gets a markdown footnote reference
+(`ASIN[^asin]`), while the definition is stored in a managed footnote footer at
+the end of the chat transcript. Persisted managed footnotes are rehydrated into
+diagnostics when any markdown buffer is entered or refreshed. The whole new
+annotation is **undoable** — `u` reverts the footnote edit and clears both
+decorations (see Undo below). For jargon you don't know (e.g. `ASIN`), it's a
+one-keystroke lookup. Added in
 [#161](../../workshop/issues/000161-inline-term-definition.md) (R1 added the
 highlight/undo); [#166](../../workshop/issues/000166-visual-selection-definition-system-manages-footnote.md)
 made the definition durable as a managed footnote; [#167](../../workshop/issues/000167-define-diagnostic-highlight-span.md)
 narrowed the visible decoration to the selected term plus footnote reference;
 [#172](../../workshop/issues/000172-markdown-footnote-diagnostics.md)
 rehydrates persisted managed footnotes in all markdown buffers.

 ## Flow

 1. **`define_visual(buf)`** (`lua/parley/init.lua`) reads the visual selection
    (`getpos`), extracts the phrase (`define.slice_selection`), guards
    empty/whitespace, and computes a **bounded context** = the *enclosing
    exchange* of the selection (`define.context_for_selection` over `parse_chat`
    + `find_exchange_at_line`), falling back to the whole buffer.
 2. It fires a headless **`define` skill** turn via `skill_invoke.invoke` with
    `opts.document = context`, `opts.no_reload = true`, and an `on_done`.
 3. The `define` skill (`lua/parley/skills/define/init.lua`) is **unforced** (no
    `force_tool`) so the server-side `web_search` tool can run when the global
    `:ToggleWebSearch` is on; its `source(ctx)` folds the phrase into the system
    prompt and asks the model to call `emit_definition({term, definition})`.
 4. **`render_definition`** (`on_done`), on a successful lookup: re-verifies the
    selection still holds the phrase (else skips — the buffer changed under the
    in-flight call), then **(a)** adds a `[^id]` reference after the selected term
    and inserts/updates a final managed footnote footer via one buffer rewrite
    (`define.apply_definition_footnote`) — a single undo entry that anchors
    everything; **(b)** highlights the selected term/reference span with
    `DiffChange` (`skill_render.highlight_span`); **(c)** refreshes persisted
    footnote diagnostics (`skill_render.refresh_footnote_diagnostics`), which
    parses the managed footer and sets INFO `vim.diagnostic` entries on matching
    inline `term[^id]` spans (`define.format_definition` →
    `skill_render.format_diagnostic_message`) on the `parley_skill` namespace;
    **(d)** records the undo/redo projection states.
-   `diag_display`'s `virtual_lines{current_line=true}` reveals the diagnostic
-   (cursor parked on the term's line). A no-`emit_definition` response leaves no
-   footnote reference/footer.
+   `diag_display`'s Parley-owned left-column virtual-line display reveals the
+   diagnostic (cursor parked on the term's line). A no-`emit_definition` response
+   leaves no footnote reference/footer.

 ## Undo (`u`) — reuses review's projection

 Native `u` reverts *text*, not decorations. The footnote reference/footer rewrite
 is the one text change, so `u` reverts it; the decorations are cleared/restored by review's
 **projection watcher** (`skills/review/projection.lua`, #133 M5), which define
 reuses: `render_definition` calls `projection.record_empty_for(buf, original)`
 (pre-footnote hash → empty snapshot), `record(buf)` (footnoted hash → the
 highlight + diagnostic), `ensure_watch(buf)`. Undoing the footnote edit lands on
 the pre-footnote content-hash → the empty snapshot renders → both decorations clear;
 `<C-r>` re-renders. `skill_render.snapshot`/`apply_snapshot` preserve span
 highlights (`hl_spans`) and diagnostic `col`/`end_col`, while still accepting
 legacy whole-line `hl_lines`. `set_applying` guards the edit so a prior define's
 watcher doesn't mistake it for a user edit.

 ## Pure core vs IO shell (ARCH-PURE)

 - **Pure** (`lua/parley/define.lua`, unit-tested with plain tables): `slice_selection`,
   `context_for_selection`, `format_definition`, `bracket_edit` (plans the `[term]`
   wrap as a legacy set_lines edit), `diagnostic_span_after_bracket` (legacy range
   mapping), `apply_definition_footnote` (durable footer transform), and
   `strip_definition_footnote_footer` / `footnote_diagnostics` (read only a final
   `---` block followed solely by footnotes).
 - **IO shell** (`lua/parley/init.lua`): `define_visual`, `render_definition`;
   `lua/parley/buffer_edit.lua` owns the full-buffer footnote rewrite;
   `lua/parley/skill_render.lua` publishes footnote diagnostics; and
   `lua/parley/highlighter.lua` refreshes them from chat and markdown lifecycle
   hooks.
 - **External service** (Anthropic) exercised via the process-level fake reused
   from `skill_invoke_spec` (SSE tool-call injection).

 ## Managed Footnote Footer

 The footer is a final markdown block:

 ```markdown
 ---

 [^asin]: Amazon Standard Identification Number.
 ```
@@ -89,62 +89,62 @@ The footer detector is deliberately conservative: only the last standalone
 `---` line followed by blank lines and footnote definitions counts as the
 managed footer. Ordinary horizontal rules and mixed prose after `---` remain
 chat content. `chat_respond.build_messages` strips this managed footer from
 message strings before LLM submission, so durable definitions do not become
 prompt context. `define.footnote_diagnostics` uses the same footer detector to
 scan inline references before the footer and produce diagnostics for each
 matching `[^id]`.

 ## Keybinding

 `<M-CR>` was split out of `chat_shortcut_respond` into its own `chat_define`
 registry entry (a single registry entry maps every key×mode to one per-mode
 callback, so the split can't live inside `chat_respond`). The `chat_define`
 per-mode callback is `{ n=respond, i=respond, v=define_visual, x=define_visual }`
 — visual `<M-CR>` defines; normal/insert `<M-CR>` still responds; visual
 `<C-g><C-g>` keeps the line-scoped resubmit. The v/x callbacks `<Esc>`-commit
 the `'<`/`'>` marks before reading `getpos`.

 ## Read-only invoke seam (`opts.no_reload`)

 `skill_invoke.invoke` normally writes the buffer before the turn and `:edit!`-
 reloads it after (for `propose_edits`). A read-only lookup passes
 `opts.no_reload = true` to skip both, so an in-progress prompt is never
 persisted. `opts.document` lets the caller send a bounded context instead of the
 whole buffer. Both default to prior behavior when absent.

 ## Structured output tool

 `emit_definition` (`lua/parley/tools/builtin/emit_definition.lua`, in
 `BUILTIN_NAMES`) is an **output-only** tool: `{term, definition}` schema,
 `self_paginates = true` (no pager params), no-op `handler`. The value rides the
 tool-call args (`result.calls[1].input`), read in `on_done`.

 ## Notes

 - The fresh define highlight spans the selected text plus immediate `[^id]`
   reference; rehydrated diagnostics do not recreate the DiffChange highlight.
 - `skill_render.refresh_footnote_diagnostics` owns only diagnostics tagged
   `parley-footnote` and preserves other `parley_skill` diagnostics, so review
   diagnostics are not cleared by markdown footnote refresh.
-- A diagnostic's `virtual_lines` auto-hide when the cursor leaves its line. The
-  footnote persists in the file if saved.
+- A diagnostic's Parley virtual-line block auto-hides when the cursor leaves its
+  line. The footnote persists in the file if saved.

 ## Key files

 - `lua/parley/define.lua` — pure core (slice / context / format / footnote footer / diagnostics).
 - `lua/parley/init.lua` — `define_visual`, `render_definition`, `chat_define` wiring.
 - `lua/parley/highlighter.lua` — chat/markdown buffer lifecycle refresh hooks.
 - `lua/parley/skill_render.lua` — footnote diagnostic refresh in the shared namespace.
 - `lua/parley/chat_respond.lua` — strips managed footnote footer from LLM messages.
 - `lua/parley/skills/define/init.lua` — the unforced `define` skill.
 - `lua/parley/tools/builtin/emit_definition.lua` — output-only structured tool.
 - `lua/parley/skill_invoke.lua` — `opts.no_reload` / `opts.document` seams.
 - `lua/parley/config.lua`, `lua/parley/keybinding_registry.lua` — the `<M-CR>` split.
 - `tests/unit/define_spec.lua`, `tests/integration/define_spec.lua` — coverage.

 ## Related

 - [Drill-In Markers](drill_in.md) — the heavier "gather into the next turn"
   sibling; shares `define.slice_selection` for the visual-selection extraction.
 - [Document Review](../modes/review.md) — the skill/`skill_invoke`/`diag_display`
   machinery this reuses.
diff --git a/atlas/modes/review.md b/atlas/modes/review.md
index b470783..ef656df 100644
--- a/atlas/modes/review.md
+++ b/atlas/modes/review.md
@@ -125,86 +125,90 @@ the journal owns the durable, cross-session record.
   `append`. 4-backtick fences wrap the journal's own blocks so a 3-backtick code
   fence inside the doc or diff can't break parsing.
 - **Per round** it stores: round number (derived), mode, side, ISO timestamp,
   content hash, rationale (the per-edit `explain`s), and the unified diff. Round 0
   is the base snapshot (written once, on the first round).
 - **Wiring**: `skill_invoke`'s `on_done` payload carries `original` /
   `new_content` / `decorations` (pure-fed); review's `on_done` builds the entry
   and calls `journal.append` (skips no-op rounds + path-less buffers).
 - **Drift**: `is_drift(recorded_hash, current)` detects an external edit (e.g.
   Claude Code resolving markers) since the last recorded round.
 - **Deferred (v2)**: durable "revert/show round N" (reconstruct via base +
   replayed diffs). The journal stores the **diff + rationale** per round (not a
   structured decoration set — see the plan's Revisions).

 ## Decoration projection — undo/redo coherence (#133 M5)

 nvim's undo reverts **text only**; review decorations are drawn once per round
 and otherwise ride, so without help they go stale after an undo (esp. across the
 round's `:edit!` reload). `lua/parley/skills/review/projection.lua` keeps style
 coherent: a per-buffer record `{ content-hash → decoration snapshot }`, and on
 each text change it **projects** the right style onto the current state —

 - **undo/redo** lands on a recorded content-hash → re-render that snapshot (via
   `skill_render.snapshot`/`apply_snapshot`);
 - a **novel forward edit** (manual tweak / `<M-a>` accept — behavior B) keeps the
   live decorations riding, and snapshots them under the new state so a later undo
   restores them.

 A round records its **pre** state (base → empty style, so undoing across the
 round clears it) and its **post** state (its decorations); records persist across
 rounds for multi-round undo. `set_applying` suppresses the watcher during the
 round's own reload; the watcher is attached lazily (only after the first round).
 The decide rule (`projection.decide`) is pure. Session-scoped (matches nvim's
 session-scoped undo); per-state snapshots aren't journaled.

 ## Diagnostic display (#133 M6)

 The edit "why" (the per-edit `explain`) is an INFO diagnostic on parley's
 `parley_skill` namespace. `lua/parley/skills/review/diag_display.lua` controls how
 it shows — scoped to that namespace, so the user's LSP/global diagnostics are
-untouched. Default **on**: `virtual_lines { current_line = true }`, so the
-(hard-wrapped, via `skill_render.format_diagnostic_message`) why **auto-expands
-below an edit when the cursor is in that edit's region** (`attach_diagnostics` spans `lnum..end_lnum`)
-and hides otherwise. `:ParleyShowDiagnostics` toggles it. The built-in `]d`/`[d`
-(jump) and `<C-W>d` (float, wraps) also work on these diagnostics. Composes with
-M5 — re-renders on undo/redo.
+untouched. Default **on**: Parley's custom `parley/virtual_lines` diagnostic
+handler renders a left-column virtual-line block headed `Diagnostics:` for the
+current line. It avoids Neovim's stock virtual-lines indentation-by-diagnostic
+column, which can hide messages on long wrapped prose. The hard-wrapped why
+(`skill_render.format_diagnostic_message`) **auto-expands below an edit when the
+cursor is in that edit's region** (`attach_diagnostics` spans
+`lnum..end_lnum`) and hides otherwise. `:ParleyShowDiagnostics` toggles it. The
+built-in `]d`/`[d` (jump) and `<C-W>d` (float, wraps) still work on these
+diagnostics because the underlying diagnostic spans remain unchanged. Composes
+with M5 — re-renders on undo/redo.

 ## Progress bar (#133 M7)

 A review round is headless and takes ~30s, so it shows a **detached progress
 bar** — `lua/parley/progress.lua`, a floating bar pinned just above the
 statusline with an animated spinner + message + elapsed seconds. It's a **general
 reusable mechanism** (`progress.start/update/stop/is_active`, one active at a
 time; pure `frame`/`format` + thin float/timer IO), not review-specific — review
 is just its first user. `skill_invoke` starts it when the LLM query launches and
 stops it on exit/abort/cancel (guarded by the same generation counter as the
 in-flight cancel). Concurrency: triggering a review while one runs gives the
 kill-or-cancel prompt (no two concurrent rounds).

 ## Config

 ```lua
 review_agent = "",              -- agent name (deprecated; use skills config)
 review_highlight_duration = 2000, -- highlight fade time in ms
 review_shortcut_edit   = { modes = { "n" }, shortcut = "<C-g>ve" },
 review_shortcut_finder = { modes = { "n", "i" }, shortcut = "<C-g>vf" },
 review_shortcut_menu   = { modes = { "n" }, shortcut = "<M-o>" },   -- skill picker (#133)
 review_shortcut_next   = { modes = { "n", "i" }, shortcut = "<M-CR>" }, -- review-mode menu (#133)
 -- Marker insertion: see drill_in_callbacks in lua/parley/init.lua
 -- (shared <M-q> / <C-g>q binding)
 ```

 ## Key Files

 - `lua/parley/skills/review/init.lua` — skill definition (+ `source(ctx)` mode composition, `mode` arg), marker parsing, `run_via_invoke` (marker pre-check + resubmit), keybindings
 - `lua/parley/skills/review/mode.lua` — Mode parse/directives (PURE) + load/list IO seam (#133)
 - `lua/parley/skills/review/modes/*.md` — the six review-mode prompt files (#133)
 - `lua/parley/skills/review/journal.lua` — per-round journal: PURE serialize/parse/diff/drift + sidecar IO seam (#133)

exec
/bin/zsh -lc 'make test' in /Users/xianxu/workspace/parley.nvim
 succeeded in 17047ms:
Checking lua/parley/agent_info.lua                OK
Checking lua/parley/agent_picker.lua              OK
Checking lua/parley/artifact_ref.lua              OK
Checking lua/parley/buffer_edit.lua               OK
Checking lua/parley/chat_dirs.lua                 OK
Checking lua/parley/chat_finder.lua               OK
Checking lua/parley/chat_lease.lua                OK
Checking lua/parley/chat_parser.lua               OK
Checking lua/parley/chat_respond.lua              OK
Checking lua/parley/chat_slug.lua                 OK
Checking lua/parley/cliproxy.lua                  OK
Checking lua/parley/cliproxy_config.lua           OK
Checking lua/parley/config.lua                    OK
Checking lua/parley/copy.lua                      OK
Checking lua/parley/custom_prompts.lua            OK
Checking lua/parley/defaults.lua                  OK
Checking lua/parley/define.lua                    OK
Checking lua/parley/discovery/base.lua            OK
Checking lua/parley/discovery/descriptor.lua      OK
Checking lua/parley/discovery/init.lua            OK
Checking lua/parley/discovery/local_types.lua     OK
Checking lua/parley/discovery/matcher.lua         OK
Checking lua/parley/discovery/merge.lua           OK
Checking lua/parley/discovery/registry.lua        OK
Checking lua/parley/dispatcher.lua                OK
Checking lua/parley/drill_in.lua                  OK
Checking lua/parley/exchange_clipboard.lua        OK
Checking lua/parley/exchange_model.lua            OK
Checking lua/parley/exporter.lua                  OK
Checking lua/parley/file_tracker.lua              OK
Checking lua/parley/finder_sticky.lua             OK
Checking lua/parley/float_picker.lua              OK
Checking lua/parley/google_drive.lua              OK
Checking lua/parley/health.lua                    OK
Checking lua/parley/helper.lua                    OK
Checking lua/parley/highlighter.lua               OK
Checking lua/parley/init.lua                      OK
Checking lua/parley/interview.lua                 OK
Checking lua/parley/issue_finder.lua              OK
Checking lua/parley/issue_vocabulary.lua          OK
Checking lua/parley/issues.lua                    OK
Checking lua/parley/keybinding_registry.lua       OK
Checking lua/parley/log_emit.lua                  OK
Checking lua/parley/logger.lua                    OK
Checking lua/parley/lualine.lua                   OK
Checking lua/parley/markdown_finder.lua           OK
Checking lua/parley/memory_prefs.lua              OK
Checking lua/parley/neighborhood.lua              OK
Checking lua/parley/note_dir_picker.lua           OK
Checking lua/parley/note_dirs.lua                 OK
Checking lua/parley/note_finder.lua               OK
Checking lua/parley/notes.lua                     OK
Checking lua/parley/oauth.lua                     OK
Checking lua/parley/obfuscate.lua                 OK
Checking lua/parley/outline.lua                   OK
Checking lua/parley/progress.lua                  OK
Checking lua/parley/provider_params.lua           OK
Checking lua/parley/providers.lua                 OK
Checking lua/parley/raw_log.lua                   OK
Checking lua/parley/render.lua                    OK
Checking lua/parley/render_buffer.lua             OK
Checking lua/parley/repo_artifacts.lua            OK
Checking lua/parley/review.lua                    OK
Checking lua/parley/review_menu.lua               OK
Checking lua/parley/root_dir_picker.lua           OK
Checking lua/parley/root_dirs.lua                 OK
Checking lua/parley/skill_assembly.lua            OK
Checking lua/parley/skill_edits.lua               OK
Checking lua/parley/skill_invoke.lua              OK
Checking lua/parley/skill_manifest.lua            OK
Checking lua/parley/skill_picker.lua              OK
Checking lua/parley/skill_providers.lua           OK
Checking lua/parley/skill_registry.lua            OK
Checking lua/parley/skill_render.lua              OK
Checking lua/parley/skills/define/init.lua        OK
Checking lua/parley/skills/review/diag_display.lua OK
Checking lua/parley/skills/review/init.lua        OK
Checking lua/parley/skills/review/journal.lua     OK
Checking lua/parley/skills/review/mode.lua        OK
Checking lua/parley/skills/review/projection.lua  OK
Checking lua/parley/skills/voice_apply/init.lua   OK
Checking lua/parley/spell.lua                     OK
Checking lua/parley/spinner.lua                   OK
Checking lua/parley/super_repo.lua                OK
Checking lua/parley/system_prompt_msgs.lua        OK
Checking lua/parley/system_prompt_picker.lua      OK
Checking lua/parley/tasker.lua                    OK
Checking lua/parley/test_agent_picker.lua         OK
Checking lua/parley/timezone_diagnostics.lua      OK
Checking lua/parley/tool_folds.lua                OK
Checking lua/parley/tool_loop.lua                 OK
Checking lua/parley/tools/backup.lua              OK
Checking lua/parley/tools/builtin/ack.lua         OK
Checking lua/parley/tools/builtin/argv.lua        OK
Checking lua/parley/tools/builtin/chat_history_search.lua OK
Checking lua/parley/tools/builtin/edit_file.lua   OK
Checking lua/parley/tools/builtin/emit_definition.lua OK
Checking lua/parley/tools/builtin/find.lua        OK
Checking lua/parley/tools/builtin/grep.lua        OK
Checking lua/parley/tools/builtin/ls.lua          OK
Checking lua/parley/tools/builtin/propose_edits.lua OK
Checking lua/parley/tools/builtin/read_file.lua   OK
Checking lua/parley/tools/builtin/write_file.lua  OK
Checking lua/parley/tools/dispatcher.lua          OK
Checking lua/parley/tools/init.lua                OK
Checking lua/parley/tools/serialize.lua           OK
Checking lua/parley/tools/types.lua               OK
Checking lua/parley/tools/version.lua             OK
Checking lua/parley/vault.lua                     OK
Checking lua/parley/vision.lua                    OK
Checking lua/parley/vision_finder.lua             OK
Checking tests/arch/arch_helper.lua               OK
Checking tests/arch/buffer_mutation_spec.lua      OK
Checking tests/fixtures/pre_81_vanilla_claude_prompts.lua OK
Checking tests/integration/chat_lease_spec.lua    OK
Checking tests/integration/chat_move_spec.lua     OK
Checking tests/integration/chat_respond_spec.lua  OK
Checking tests/integration/cliproxy_auth_login_spec.lua OK
Checking tests/integration/cliproxy_caller_teardown_spec.lua OK
Checking tests/integration/cliproxy_command_spec.lua OK
Checking tests/integration/cliproxy_dispatch_spec.lua OK
Checking tests/integration/cliproxy_download_spec.lua OK
Checking tests/integration/cliproxy_lifecycle_spec.lua OK
Checking tests/integration/create_handler_spec.lua OK
Checking tests/integration/define_spec.lua        OK
Checking tests/integration/discovery_builder_spec.lua OK
Checking tests/integration/discovery_local_types_spec.lua OK
Checking tests/integration/export_spec.lua        OK
Checking tests/integration/highlighting_spec.lua  OK
Checking tests/integration/neighborhood_completion_spec.lua OK
Checking tests/integration/new_chat_spec.lua      OK
Checking tests/integration/not_chat_spec.lua      OK
Checking tests/integration/progress_spec.lua      OK
Checking tests/integration/review_diag_display_spec.lua OK
Checking tests/integration/review_journal_io_spec.lua OK
Checking tests/integration/review_menu_spec.lua   OK
Checking tests/integration/review_mode_load_spec.lua OK
Checking tests/integration/review_projection_spec.lua OK
Checking tests/integration/skill_invoke_review_spec.lua OK
Checking tests/integration/skill_invoke_spec.lua  OK
Checking tests/integration/skill_providers_spec.lua OK
Checking tests/integration/skill_registry_spec.lua OK
Checking tests/integration/spell_chat_spec.lua    OK
Checking tests/integration/tasker_run_spec.lua    OK
Checking tests/integration/timer_race_spec.lua    OK
Checking tests/integration/topic_gen_spec.lua     OK
Checking tests/integration/tree_export_spec.lua   OK
Checking tests/integration/voice_apply_spec.lua   OK
Checking tests/perf_chat_finder.lua               OK
Checking tests/unit/ancestor_messages_spec.lua    OK
Checking tests/unit/anthropic_tool_decode_spec.lua OK
Checking tests/unit/anthropic_tool_encode_spec.lua OK
Checking tests/unit/arch_helper_spec.lua          OK
Checking tests/unit/artifact_ref_spec.lua         OK
Checking tests/unit/buffer_edit_spec.lua          OK
Checking tests/unit/build_messages_spec.lua       OK
Checking tests/unit/chat_dirs_spec.lua            OK
Checking tests/unit/chat_finder_logic_spec.lua    OK
Checking tests/unit/chat_parser_section_lines_spec.lua OK
Checking tests/unit/chat_parser_tools_spec.lua    OK
Checking tests/unit/chat_slug_resolve_spec.lua    OK
Checking tests/unit/chat_slug_spec.lua            OK
Checking tests/unit/cliproxy_config_spec.lua      OK
Checking tests/unit/config_tools_spec.lua         OK
Checking tests/unit/custom_prompts_spec.lua       OK
Checking tests/unit/define_spec.lua               OK
Checking tests/unit/discovery_base_spec.lua       OK
Checking tests/unit/discovery_descriptor_spec.lua OK
Checking tests/unit/discovery_matcher_spec.lua    OK
Checking tests/unit/discovery_merge_spec.lua      OK
Checking tests/unit/discovery_registry_spec.lua   OK
Checking tests/unit/dispatcher_query_spec.lua     OK
Checking tests/unit/dispatcher_spec.lua           OK
Checking tests/unit/drill_in_spec.lua             OK
Checking tests/unit/exchange_clipboard_spec.lua   OK
Checking tests/unit/exchange_model_spec.lua       OK
Checking tests/unit/exporter_tree_spec.lua        OK
Checking tests/unit/file_tracker_spec.lua         OK
Checking tests/unit/finder_sticky_spec.lua        OK
Checking tests/unit/float_picker_spec.lua         OK
Checking tests/unit/get_week_number_spec.lua      OK
Checking tests/unit/helper_io_spec.lua            OK
Checking tests/unit/helper_spec.lua               OK
Checking tests/unit/highlighter_spec.lua          OK
Checking tests/unit/inline_branch_spec.lua        OK
Checking tests/unit/issue_finder_spec.lua         OK
Checking tests/unit/issue_vocabulary_spec.lua     OK
Checking tests/unit/issues_spec.lua               OK
Checking tests/unit/keybindings_spec.lua          OK
Checking tests/unit/log_emit_spec.lua             OK
Checking tests/unit/logger_spec.lua               OK
Checking tests/unit/markdown_draft_block_spec.lua OK
Checking tests/unit/memory_prefs_spec.lua         OK
Checking tests/unit/neighborhood_spec.lua         OK
Checking tests/unit/note_finder_logic_spec.lua    OK
Checking tests/unit/oauth_spec.lua                OK
Checking tests/unit/obfuscate_spec.lua            OK
Checking tests/unit/open_chat_reference_spec.lua  OK
Checking tests/unit/outline_spec.lua              OK
Checking tests/unit/parley_harness_golden_spec.lua OK
Checking tests/unit/parley_harness_spec.lua       OK
Checking tests/unit/parse_at_reference_spec.lua   OK
Checking tests/unit/parse_chat_spec.lua           OK
Checking tests/unit/picker_items_spec.lua         OK
Checking tests/unit/process_directory_pattern_spec.lua OK
Checking tests/unit/progress_spec.lua             OK
Checking tests/unit/provider_params_spec.lua      OK
Checking tests/unit/providers_pre_query_spec.lua  OK
Checking tests/unit/pure_functions_spec.lua       OK
Checking tests/unit/raw_log_spec.lua              OK
Checking tests/unit/remote_references_spec.lua    OK
Checking tests/unit/render_buffer_roundtrip_spec.lua OK
Checking tests/unit/render_buffer_spec.lua        OK
Checking tests/unit/render_spec.lua               OK
Checking tests/unit/review_journal_spec.lua       OK
Checking tests/unit/review_mode_spec.lua          OK
Checking tests/unit/review_spec.lua               OK
Checking tests/unit/skill_assembly_spec.lua       OK
Checking tests/unit/skill_edits_spec.lua          OK
Checking tests/unit/skill_manifest_spec.lua       OK
Checking tests/unit/skill_picker_spec.lua         OK
Checking tests/unit/skill_render_spec.lua         OK
Checking tests/unit/spell_spec.lua                OK
Checking tests/unit/sse_parsing_spec.lua          OK
Checking tests/unit/super_repo_spec.lua           OK
Checking tests/unit/system_prompt_msgs_spec.lua   OK
Checking tests/unit/tasker_unit_spec.lua          OK
Checking tests/unit/timezone_diagnostics_spec.lua OK
Checking tests/unit/tool_folds_spec.lua           OK
Checking tests/unit/tool_loop_spec.lua            OK
Checking tests/unit/tools_builtin_ack_spec.lua    OK
Checking tests/unit/tools_builtin_chat_history_search_spec.lua OK
Checking tests/unit/tools_builtin_find_spec.lua   OK
Checking tests/unit/tools_builtin_grep_spec.lua   OK
Checking tests/unit/tools_builtin_ls_spec.lua     OK
Checking tests/unit/tools_builtin_propose_edits_spec.lua OK
Checking tests/unit/tools_builtin_read_file_spec.lua OK
Checking tests/unit/tools_builtin_registered_spec.lua OK
Checking tests/unit/tools_dispatcher_spec.lua     OK
Checking tests/unit/tools_registry_spec.lua       OK
Checking tests/unit/tools_serialize_spec.lua      OK
Checking tests/unit/tools_types_spec.lua          OK
Checking tests/unit/vault_spec.lua                OK
Checking tests/unit/vision_spec.lua               OK

Total: 0 warnings / 0 errors in 244 files
PASS: tests/unit/ancestor_messages_spec.lua
PASS: tests/unit/anthropic_tool_decode_spec.lua
PASS: tests/unit/buffer_edit_spec.lua
PASS: tests/unit/arch_helper_spec.lua
PASS: tests/unit/anthropic_tool_encode_spec.lua
PASS: tests/unit/artifact_ref_spec.lua
PASS: tests/unit/build_messages_spec.lua
PASS: tests/unit/chat_parser_section_lines_spec.lua
PASS: tests/unit/chat_parser_tools_spec.lua
PASS: tests/unit/chat_slug_spec.lua
PASS: tests/unit/chat_finder_logic_spec.lua
PASS: tests/unit/cliproxy_config_spec.lua
PASS: tests/unit/chat_dirs_spec.lua
PASS: tests/unit/define_spec.lua
PASS: tests/unit/custom_prompts_spec.lua
PASS: tests/unit/discovery_base_spec.lua
PASS: tests/unit/discovery_descriptor_spec.lua
PASS: tests/unit/discovery_matcher_spec.lua
PASS: tests/unit/discovery_merge_spec.lua
PASS: tests/unit/discovery_registry_spec.lua
PASS: tests/unit/chat_slug_resolve_spec.lua
PASS: tests/unit/dispatcher_query_spec.lua
PASS: tests/unit/drill_in_spec.lua
PASS: tests/unit/exchange_clipboard_spec.lua
PASS: tests/unit/exchange_model_spec.lua
PASS: tests/unit/dispatcher_spec.lua
PASS: tests/unit/exporter_tree_spec.lua
PASS: tests/unit/finder_sticky_spec.lua
PASS: tests/unit/file_tracker_spec.lua
PASS: tests/unit/get_week_number_spec.lua
PASS: tests/unit/helper_spec.lua
PASS: tests/unit/helper_io_spec.lua
PASS: tests/unit/float_picker_spec.lua
PASS: tests/unit/highlighter_spec.lua
PASS: tests/unit/inline_branch_spec.lua
PASS: tests/unit/issue_vocabulary_spec.lua
PASS: tests/unit/log_emit_spec.lua
PASS: tests/unit/issue_finder_spec.lua
PASS: tests/unit/markdown_draft_block_spec.lua
PASS: tests/unit/logger_spec.lua
PASS: tests/unit/memory_prefs_spec.lua
PASS: tests/unit/issues_spec.lua
PASS: tests/unit/neighborhood_spec.lua
PASS: tests/unit/config_tools_spec.lua
PASS: tests/unit/oauth_spec.lua
PASS: tests/unit/obfuscate_spec.lua
PASS: tests/unit/note_finder_logic_spec.lua
PASS: tests/unit/outline_spec.lua
PASS: tests/unit/open_chat_reference_spec.lua
PASS: tests/unit/parse_chat_spec.lua
PASS: tests/unit/parley_harness_golden_spec.lua
PASS: tests/unit/picker_items_spec.lua
PASS: tests/unit/process_directory_pattern_spec.lua
PASS: tests/unit/parley_harness_spec.lua
PASS: tests/unit/parse_at_reference_spec.lua
PASS: tests/unit/progress_spec.lua
PASS: tests/unit/provider_params_spec.lua
PASS: tests/unit/providers_pre_query_spec.lua
PASS: tests/unit/raw_log_spec.lua
PASS: tests/unit/keybindings_spec.lua
PASS: tests/unit/render_buffer_spec.lua
PASS: tests/unit/render_buffer_roundtrip_spec.lua
PASS: tests/unit/pure_functions_spec.lua
PASS: tests/unit/render_spec.lua
PASS: tests/unit/review_journal_spec.lua
PASS: tests/unit/remote_references_spec.lua
PASS: tests/unit/review_mode_spec.lua
PASS: tests/unit/review_spec.lua
PASS: tests/unit/skill_assembly_spec.lua
PASS: tests/unit/skill_edits_spec.lua
PASS: tests/unit/skill_manifest_spec.lua
PASS: tests/unit/skill_picker_spec.lua
PASS: tests/unit/skill_render_spec.lua
PASS: tests/unit/spell_spec.lua
PASS: tests/unit/sse_parsing_spec.lua
PASS: tests/unit/system_prompt_msgs_spec.lua
PASS: tests/unit/tasker_unit_spec.lua
PASS: tests/unit/timezone_diagnostics_spec.lua
PASS: tests/unit/tool_folds_spec.lua
PASS: tests/unit/tool_loop_spec.lua
PASS: tests/unit/tools_builtin_grep_spec.lua
PASS: tests/unit/tools_builtin_ls_spec.lua
PASS: tests/unit/tools_builtin_propose_edits_spec.lua
PASS: tests/unit/tools_builtin_find_spec.lua
PASS: tests/unit/tools_builtin_read_file_spec.lua
PASS: tests/unit/tools_builtin_registered_spec.lua
PASS: tests/unit/tools_registry_spec.lua
PASS: tests/unit/tools_serialize_spec.lua
PASS: tests/unit/tools_types_spec.lua
PASS: tests/unit/tools_builtin_ack_spec.lua
PASS: tests/unit/tools_dispatcher_spec.lua
PASS: tests/unit/vault_spec.lua
PASS: tests/unit/vision_spec.lua
PASS: tests/unit/tools_builtin_chat_history_search_spec.lua
PASS: tests/unit/super_repo_spec.lua
PASS: tests/integration/chat_lease_spec.lua
PASS: tests/arch/buffer_mutation_spec.lua
PASS: tests/integration/chat_move_spec.lua
PASS: tests/integration/cliproxy_command_spec.lua
PASS: tests/integration/cliproxy_auth_login_spec.lua
PASS: tests/integration/create_handler_spec.lua
PASS: tests/integration/cliproxy_caller_teardown_spec.lua
PASS: tests/integration/cliproxy_download_spec.lua
PASS: tests/integration/discovery_local_types_spec.lua
PASS: tests/integration/discovery_builder_spec.lua
PASS: tests/integration/export_spec.lua
PASS: tests/integration/cliproxy_dispatch_spec.lua
PASS: tests/integration/progress_spec.lua
PASS: tests/integration/new_chat_spec.lua
PASS: tests/integration/neighborhood_completion_spec.lua
PASS: tests/integration/not_chat_spec.lua
PASS: tests/integration/review_diag_display_spec.lua
PASS: tests/integration/review_journal_io_spec.lua
PASS: tests/integration/review_menu_spec.lua
PASS: tests/integration/review_mode_load_spec.lua
PASS: tests/integration/review_projection_spec.lua
PASS: tests/integration/skill_invoke_review_spec.lua
PASS: tests/integration/skill_registry_spec.lua
PASS: tests/integration/skill_providers_spec.lua
PASS: tests/integration/spell_chat_spec.lua
PASS: tests/integration/define_spec.lua
PASS: tests/integration/skill_invoke_spec.lua
PASS: tests/integration/topic_gen_spec.lua
PASS: tests/integration/timer_race_spec.lua
PASS: tests/integration/voice_apply_spec.lua
PASS: tests/integration/tree_export_spec.lua
PASS: tests/integration/highlighting_spec.lua
PASS: tests/integration/tasker_run_spec.lua
PASS: tests/integration/chat_respond_spec.lua
PASS: tests/integration/cliproxy_lifecycle_spec.lua

codex
```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The code-level REWORK finding from the prior review is fixed: `diagnostic_contains_line()` now respects `lnum..end_lnum`, and the new integration test proves multi-line review diagnostics stay visible when the cursor moves through the span. Focused `review_diag_display_spec.lua` passes, and full `make test` passes. The remaining issue is repository hygiene: the committed close-review transcript makes full `git diff --check b9094e9..HEAD` fail.

1. Strengths

- `lua/parley/skills/review/diag_display.lua:66` restores current-region behavior with an explicit range predicate.
- `tests/integration/review_diag_display_spec.lua:87` pins the multi-line span regression caught in the first review.
- `lua/parley/skills/review/diag_display.lua:152` keeps stock `virtual_lines` disabled only for Parley’s namespace.
- Atlas updates match the new left-column renderer behavior.

2. Critical Findings

- None.

3. Important Findings

- `workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md` should not cross the boundary as-is. It adds a 3,629-line captured review transcript with terminal output/control characters and many trailing-whitespace lines; full `git diff --check b9094e9..HEAD` fails on it. Remove it from the committed diff if it is just a transient judge artifact, or normalize it and include it in verification if it is intended to be durable.

4. Minor Findings

- None.

5. Test Coverage Notes

- Passed: `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"`.
- Passed: `make test`.
- Failed: full-window `git diff --check b9094e9..HEAD`, due only to the close-review transcript file.

6. Architectural Notes

- ARCH-DRY: Pass. One Parley diagnostic display controller covers review and footnote diagnostics.
- ARCH-PURE: Pass for this scope. The range predicate is deterministic and pinned through integration behavior.
- ARCH-PURPOSE: Pass after the fix. The shared namespace behavior now serves both the long-line footnote symptom and review-region diagnostics.

7. Plan Revision Recommendations

- None for the implementation plan; the `## Revisions` entry matches the fixed regression. The issue log should add one final note after the close-review transcript is removed or cleaned and full-window `git diff --check` passes.
tokens used
110,213
```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The code-level REWORK finding from the prior review is fixed: `diagnostic_contains_line()` now respects `lnum..end_lnum`, and the new integration test proves multi-line review diagnostics stay visible when the cursor moves through the span. Focused `review_diag_display_spec.lua` passes, and full `make test` passes. The remaining issue is repository hygiene: the committed close-review transcript makes full `git diff --check b9094e9..HEAD` fail.

1. Strengths

- `lua/parley/skills/review/diag_display.lua:66` restores current-region behavior with an explicit range predicate.
- `tests/integration/review_diag_display_spec.lua:87` pins the multi-line span regression caught in the first review.
- `lua/parley/skills/review/diag_display.lua:152` keeps stock `virtual_lines` disabled only for Parley’s namespace.
- Atlas updates match the new left-column renderer behavior.

2. Critical Findings

- None.

3. Important Findings

- `workshop/plans/000173-diagnostic-virtual-lines-leftcol-close-review.md` should not cross the boundary as-is. It adds a 3,629-line captured review transcript with terminal output/control characters and many trailing-whitespace lines; full `git diff --check b9094e9..HEAD` fails on it. Remove it from the committed diff if it is just a transient judge artifact, or normalize it and include it in verification if it is intended to be durable.

4. Minor Findings

- None.

5. Test Coverage Notes

- Passed: `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"`.
- Passed: `make test`.
- Failed: full-window `git diff --check b9094e9..HEAD`, due only to the close-review transcript file.

6. Architectural Notes

- ARCH-DRY: Pass. One Parley diagnostic display controller covers review and footnote diagnostics.
- ARCH-PURE: Pass for this scope. The range predicate is deterministic and pinned through integration behavior.
- ARCH-PURPOSE: Pass after the fix. The shared namespace behavior now serves both the long-line footnote symptom and review-region diagnostics.

7. Plan Revision Recommendations

- None for the implementation plan; the `## Revisions` entry matches the fixed regression. The issue log should add one final note after the close-review transcript is removed or cleaned and full-window `git diff --check` passes.
