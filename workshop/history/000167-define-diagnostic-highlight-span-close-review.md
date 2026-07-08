# Boundary Review — parley.nvim#167 (whole-issue close)

| field | value |
|-------|-------|
| issue | 167 — define diagnostic highlight should target footnote span |
| repo | parley.nvim |
| issue file | workshop/issues/000167-define-diagnostic-highlight-span.md |
| boundary | whole-issue close |
| milestone | — |
| window | 5640bcaa934b0b5bc4c6c2d18b042996afd74f83..HEAD |
| command | sdlc close --issue 167 |
| reviewer | codex |
| timestamp | 2026-07-08T10:22:16-07:00 |
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
session id: 019f42bf-00ea-72b0-a7ba-2c15c60f90f4
--------
user
# Code review — the one SDLC boundary review

You are conducting a fresh-context code review at a development boundary —
whole-issue close — in the **parley.nvim** repository.

- repository: parley.nvim   (root: /Users/xianxu/workspace/parley.nvim)
- issue:      parley.nvim#167   (file: workshop/issues/000167-define-diagnostic-highlight-span.md)
- window:     Base: 5640bcaa934b0b5bc4c6c2d18b042996afd74f83   Head: HEAD

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
diff --git a/lua/parley/init.lua b/lua/parley/init.lua
index 351ade5..a170178 100644
--- a/lua/parley/init.lua
+++ b/lua/parley/init.lua
@@ -1594,8 +1594,8 @@ end
 
 -- Inline term definition (#161 + R1, #166). render_definition is the on_done IO
 -- seam. On a successful lookup it stores the definition as a durable markdown
--- footnote (ONE undo entry — the anchor), highlights the line (whole-line
--- DiffChange, review's scheme), and shows the definition as an ephemeral INFO
+-- footnote (ONE undo entry — the anchor), highlights the selected term/reference
+-- span (DiffChange), and shows the definition as an ephemeral INFO
 -- diagnostic. Undo/redo coherence reuses review's projection watcher: undoing
 -- the footnote edit lands on the pre-edit content-hash → the empty snapshot
 -- renders → both decorations clear.
@@ -1640,13 +1640,10 @@ local function render_definition(buf, span, phrase, result)
 	local e = define.apply_definition_footnote(lines, sr, sc - 1, er, ec - 1, input.term or phrase, input.definition)
 	require("parley.buffer_edit").replace_all_lines_for_definition(buf, e.lines)
 
-	-- Highlight the term's line(s) + the ephemeral definition diagnostic.
-	for line0 = sr - 1, er - 1 do
-		skill_render.highlight_line(buf, line0)
-	end
 	local width = math.max(40, vim.api.nvim_win_get_width(0) - 8)
 	local msg = define.format_definition(input.term or phrase, e.definition, width)
 	local diag_span = e.diagnostic_span
+	skill_render.highlight_span(buf, diag_span.lnum, diag_span.col, diag_span.end_lnum, diag_span.end_col)
 	vim.diagnostic.set(skill_render.diag_namespace(), buf, { {
 		lnum = diag_span.lnum,
 		col = diag_span.col,
diff --git a/lua/parley/skill_render.lua b/lua/parley/skill_render.lua
index dcf6683..5d283a0 100644
--- a/lua/parley/skill_render.lua
+++ b/lua/parley/skill_render.lua
@@ -162,20 +162,62 @@ function M.highlight_line(buf, lnum0)
     vim.api.nvim_buf_add_highlight(buf, hl_ns_id, "DiffChange", lnum0, 0, -1)
 end
 
---- Capture the current decoration set as line-anchored data (for the undo/redo
---- projection record, #133 M5). Returns { hl_lines = {0-based line…}, diags =
---- {{lnum, message}…} } — enough to redraw at a content-identical state.
+--- Highlight a column span with DiffChange on the hl namespace. The four-arg
+--- form is same-line: (buf, lnum0, col_start, col_end). The five-arg form spans
+--- rows: (buf, lnum0, col_start, end_lnum0, col_end).
+--- @param buf number
+--- @param lnum0 number 0-based start line
+--- @param col_start number 0-based start column
+--- @param end_lnum0_or_col_end number 0-based end line, or end column
+--- @param col_end number|nil 0-based exclusive end column
+function M.highlight_span(buf, lnum0, col_start, end_lnum0_or_col_end, col_end)
+    ensure_namespaces()
+    local end_lnum0 = lnum0
+    if col_end == nil then
+        col_end = end_lnum0_or_col_end
+    else
+        end_lnum0 = end_lnum0_or_col_end
+    end
+    vim.api.nvim_buf_set_extmark(buf, hl_ns_id, lnum0, col_start, {
+        end_row = end_lnum0,
+        end_col = col_end,
+        hl_group = "DiffChange",
+        strict = false,
+    })
+end
+
+--- Capture the current decoration set as redrawable data (for the undo/redo
+--- projection record, #133 M5). Whole-line highlights stay in `hl_lines`; span
+--- highlights and diagnostics preserve columns so exact anchors can be restored.
 function M.snapshot(buf)
     ensure_namespaces()
     local hl_lines = {}
-    for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf, hl_ns_id, 0, -1, {})) do
-        table.insert(hl_lines, m[2]) -- m = {id, row, col}; row is the 0-based line
+    local hl_spans = {}
+    for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf, hl_ns_id, 0, -1, { details = true })) do
+        local details = m[4] or {}
+        local is_legacy_line = m[3] == 0 and details.end_row == m[2] + 1 and details.end_col == 0
+        if is_legacy_line or details.end_row == nil or details.end_col == nil then
+            table.insert(hl_lines, m[2]) -- m = {id, row, col}; row is the 0-based line
+        else
+            table.insert(hl_spans, {
+                lnum = m[2],
+                col = m[3],
+                end_lnum = details.end_row,
+                end_col = details.end_col,
+            })
+        end
     end
     local diags = {}
     for _, d in ipairs(vim.diagnostic.get(buf, { namespace = diag_ns_id })) do
-        table.insert(diags, { lnum = d.lnum, end_lnum = d.end_lnum, message = d.message })
+        table.insert(diags, {
+            lnum = d.lnum,
+            col = d.col or 0,
+            end_lnum = d.end_lnum,
+            end_col = d.end_col,
+            message = d.message,
+        })
     end
-    return { hl_lines = hl_lines, diags = diags }
+    return { hl_lines = hl_lines, hl_spans = hl_spans, diags = diags }
 end
 
 --- Redraw a snapshot's decorations (clearing first). Only valid when the buffer
@@ -188,13 +230,17 @@ function M.apply_snapshot(buf, snap)
     for _, line in ipairs(snap.hl_lines or {}) do
         vim.api.nvim_buf_add_highlight(buf, hl_ns_id, "DiffChange", line, 0, -1)
     end
+    for _, span in ipairs(snap.hl_spans or {}) do
+        M.highlight_span(buf, span.lnum, span.col or 0, span.end_lnum or span.lnum, span.end_col)
+    end
     if snap.diags and #snap.diags > 0 then
         local diagnostics = {}
         for _, d in ipairs(snap.diags) do
             table.insert(diagnostics, {
                 lnum = d.lnum,
                 end_lnum = d.end_lnum or d.lnum,
-                col = 0,
+                col = d.col or 0,
+                end_col = d.end_col,
                 message = d.message,
                 severity = vim.diagnostic.severity.INFO,
                 source = "parley-skill",
diff --git a/tests/integration/define_spec.lua b/tests/integration/define_spec.lua
index 36f7063..05e5af1 100644
--- a/tests/integration/define_spec.lua
+++ b/tests/integration/define_spec.lua
@@ -237,8 +237,11 @@ describe("define_visual + render_definition (#161)", function()
         end
         return false
     end
+    local function first_hl_mark(b)
+        return vim.api.nvim_buf_get_extmarks(b, hl_ns, 0, -1, { details = true })[1]
+    end
 
-    it("stores the definition as a durable footnote, highlights the line, and shows the diagnostic", function()
+    it("stores the definition as a durable footnote, highlights the term/reference span, and shows the diagnostic", function()
         -- select "ASIN" on line 3 (cols 9..12, 1-based)
         vim.fn.setpos("'<", { buf, 3, 9, 0 })
         vim.fn.setpos("'>", { buf, 3, 12, 0 })
@@ -261,8 +264,13 @@ describe("define_visual + render_definition (#161)", function()
         assert.are.equal(2, diags[1].end_lnum)
         assert.are.equal(19, diags[1].end_col) -- ASIN plus [^asin]
         assert.is_true(diags[1].message:find("ASIN", 1, true) ~= nil)
-        -- whole-line DiffChange highlight on the hl namespace, on line 3
-        assert.is_true(hl_on_line(buf, 2), "term line not highlighted")
+        -- DiffChange highlight covers only ASIN[^asin], not the whole paragraph.
+        local mark = first_hl_mark(buf)
+        assert.is_not_nil(mark, "term/reference span not highlighted")
+        assert.are.equal(2, mark[2])
+        assert.are.equal(8, mark[3])
+        assert.are.equal(2, mark[4].end_row)
+        assert.are.equal(19, mark[4].end_col)
     end)
 
     it("re-defining a footnoted term updates the footer without duplicating the inline reference", function()
@@ -326,6 +334,15 @@ describe("define_visual + render_definition (#161)", function()
         vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
         assert.are.equal("here is ASIN[^asin] in context",
             vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1])
+        local redone_mark = first_hl_mark(buf)
+        assert.is_not_nil(redone_mark, "highlight not restored on redo")
+        assert.are.equal(2, redone_mark[2])
+        assert.are.equal(8, redone_mark[3])
+        assert.are.equal(2, redone_mark[4].end_row)
+        assert.are.equal(19, redone_mark[4].end_col)
+        local redone_diags = vim.diagnostic.get(buf, { namespace = ns })
+        assert.are.equal(8, redone_diags[1].col)
+        assert.are.equal(19, redone_diags[1].end_col)
         assert.is_true(#vim.diagnostic.get(buf, { namespace = ns }) >= 1,
             "diagnostic not restored on redo")
         assert.is_true(hl_on_line(buf, 2), "highlight not restored on redo")
diff --git a/tests/unit/skill_render_spec.lua b/tests/unit/skill_render_spec.lua
index bb900c5..a0057b6 100644
--- a/tests/unit/skill_render_spec.lua
+++ b/tests/unit/skill_render_spec.lua
@@ -104,6 +104,39 @@ describe("skill_render", function()
         assert.is_true(#vim.api.nvim_buf_get_extmarks(buf, hl_ns, 0, -1, {}) >= 1)
     end)
 
+    it("snapshot captures and restores highlight and diagnostic column spans", function()
+        local buf = scratch({ "here is ASIN[^asin] in context" })
+        local hl_ns = vim.api.nvim_create_namespace("parley_skill_hl")
+        local diag_ns = skill_render.diag_namespace()
+
+        skill_render.highlight_span(buf, 0, 8, 19)
+        vim.diagnostic.set(diag_ns, buf, { {
+            lnum = 0,
+            col = 8,
+            end_lnum = 0,
+            end_col = 19,
+            message = "why",
+            severity = vim.diagnostic.severity.INFO,
+            source = "test",
+        } })
+
+        local snap = skill_render.snapshot(buf)
+        skill_render.clear_decorations(buf)
+        skill_render.apply_snapshot(buf, snap)
+
+        local marks = vim.api.nvim_buf_get_extmarks(buf, hl_ns, 0, -1, { details = true })
+        assert.are.equal(1, #marks)
+        assert.are.equal(0, marks[1][2])
+        assert.are.equal(8, marks[1][3])
+        assert.are.equal(0, marks[1][4].end_row)
+        assert.are.equal(19, marks[1][4].end_col)
+
+        local diags = vim.diagnostic.get(buf, { namespace = diag_ns })
+        assert.are.equal(1, #diags)
+        assert.are.equal(8, diags[1].col)
+        assert.are.equal(19, diags[1].end_col)
+    end)
+
     it("dismiss clears decorations (alias of clear_decorations)", function()
         local buf = scratch({ "x" })
         skill_render.attach_diagnostics(buf, { { pos = 1, explain = "e" } }, "x")
diff --git a/workshop/plans/000167-define-diagnostic-highlight-span-plan.md b/workshop/plans/000167-define-diagnostic-highlight-span-plan.md
new file mode 100644
index 0000000..6757ba9
--- /dev/null
+++ b/workshop/plans/000167-define-diagnostic-highlight-span-plan.md
@@ -0,0 +1,105 @@
+# Define Diagnostic Highlight Span Implementation Plan
+
+> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.
+
+**Goal:** Make visual definition decorations visibly target the selected text plus `[^footnote]` reference instead of highlighting the whole paragraph line.
+
+**Architecture:** Keep the span math in the existing pure `define.apply_definition_footnote` result (ARCH-PURE), and extend `skill_render`'s decoration snapshot to preserve column spans for undo/redo projection (ARCH-DRY). `render_definition` remains the thin IO shell that applies the span highlight and diagnostic.
+
+**Tech Stack:** Lua, Neovim diagnostics/extmarks, Plenary/Busted tests.
+
+---
+
+## Core Concepts
+
+### Pure Entities
+
+| Name | Kind | Lives in | Status |
+|------|------|----------|--------|
+| `DefinitionDiagnosticSpan` | PURE | `lua/parley/define.lua` | reused |
+
+- **DefinitionDiagnosticSpan** — the selected term plus immediate `[^id]` reference range returned by `apply_definition_footnote`.
+  - **Relationships:** 1:1 with a definition render; consumed by `render_definition` for both diagnostic and highlight boundaries.
+  - **DRY rationale:** The diagnostic and highlight should derive from the same span, not parallel column math.
+  - **Future extensions:** Multi-line selections can widen the same span shape without changing the render caller.
+
+### Integration Points
+
+| Name | Kind | Lives in | Status | Wraps |
+|------|------|----------|--------|-------|
+| `SkillRenderSpanHighlight` | INTEGRATION | `lua/parley/skill_render.lua` | modified | Neovim extmarks |
+| `DefineRenderDecorations` | INTEGRATION | `lua/parley/init.lua` | modified | Neovim diagnostics/projection |
+
+- **SkillRenderSpanHighlight** — adds a column-scoped DiffChange extmark and snapshots/restores its exact range.
+  - **Injected into:** `DefineRenderDecorations`.
+  - **Future extensions:** Review edits can later opt into exact spans without changing projection storage again.
+- **DefineRenderDecorations** — applies define highlights using the same span as the diagnostic.
+  - **Injected into:** `define_visual`'s `on_done`.
+  - **Future extensions:** If diagnostics get a dedicated namespace, this is the seam.
+
+## Chunk 1: Pin the Regression
+
+**Files:**
+- Modify: `tests/unit/skill_render_spec.lua`
+- Modify: `tests/integration/define_spec.lua`
+
+- [x] **Step 1: Write failing tests**
+
+Add tests showing:
+- `skill_render.snapshot` and `apply_snapshot` preserve highlight columns.
+- `skill_render.snapshot` and `apply_snapshot` preserve diagnostic `col` and
+  `end_col`.
+- visual define creates a highlight extmark spanning only `ASIN[^asin]`, not the full paragraph.
+- visual define undo/redo restores both the highlight and diagnostic to the
+  `ASIN[^asin]` span.
+
+Run:
+- `nvim --headless -c "PlenaryBustedFile tests/unit/skill_render_spec.lua"`
+- `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`
+
+Expected: FAIL because define currently uses `highlight_line` and snapshots restore highlights as full-line.
+
+## Chunk 2: Use Span Highlights for Define
+
+**Files:**
+- Modify: `lua/parley/skill_render.lua`
+- Modify: `lua/parley/init.lua`
+
+- [x] **Step 1: Add span highlight support**
+
+Add a `skill_render.highlight_span(buf, lnum0, col_start, col_end)` helper that writes a `DiffChange` extmark on the existing highlight namespace.
+
+- [x] **Step 2: Preserve highlight spans through projection**
+
+Extend `snapshot` to capture extmark end columns and diagnostic `col`/`end_col`,
+and `apply_snapshot` to restore them. Preserve backward compatibility for
+existing whole-line highlights and older line-only diagnostic snapshots.
+
+- [x] **Step 3: Wire define rendering to the diagnostic span**
+
+Replace `highlight_line` calls in `render_definition` with `highlight_span` using `e.diagnostic_span`.
+
+- [x] **Step 4: Verify focused tests**
+
+Run:
+- `nvim --headless -c "PlenaryBustedFile tests/unit/skill_render_spec.lua"`
+- `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`
+
+Expected: PASS.
+
+## Chunk 3: Final Verification
+
+**Files:**
+- Modify: `workshop/issues/000167-define-diagnostic-highlight-span.md`
+
+- [x] **Step 1: Update issue log**
+
+Record red/green evidence and mark the plan complete.
+
+- [x] **Step 2: Run final checks**
+
+Run:
+- `git diff --check -- lua/parley/skill_render.lua lua/parley/init.lua tests/unit/skill_render_spec.lua tests/integration/define_spec.lua workshop/issues/000167-define-diagnostic-highlight-span.md workshop/plans/000167-define-diagnostic-highlight-span-plan.md`
+- `make test`
+
+Expected: all pass.


codex
I’ll treat this as the SDLC boundary review only: read the repo instructions and issue/plan/diff, then verify the implementation against the stated contract without editing files.
exec
/bin/zsh -lc "sed -n '1,220p' /Users/xianxu/workspace/ariadne/construct/adapted/superpowers-using-superpowers/SKILL.md && sdlc --help && sed -n '1,220p' workshop/lessons.md && sed -n '1,220p' workshop/issues/000167-define-diagnostic-highlight-span.md" in /Users/xianxu/workspace/parley.nvim
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
- **To make a decoration-only action undoable, anchor it to a text edit + reuse `projection` — `u` reverts text, never extmarks/diagnostics.** The operator wanted the define highlight+diagnostic undoable; native `u` can't touch pure decorations (review's are undoable only because a round edits text). Resolution: a minimal `[term]` bracket (one `set_lines` = one undo entry) as the anchor + reuse `skills/review/projection.lua` (`record_empty_for(pre)` + `record(post)` + `ensure_watch`). Caveat that shaped the design: `skill_render.snapshot`/`apply_snapshot` are **line-granular**, so the highlight must be whole-line `DiffChange` to round-trip; a column-precise span would not survive undo/redo. In headless tests, `:undo` does NOT fire `TextChanged` — `nvim_exec_autocmds("TextChanged", {buffer=buf})` to drive the projection watcher deterministically.

## 2026-07-08 (#166)
- **Any action that can be repeated on its own output needs an idempotence test, not only an update test for the secondary data.** #166 tested that re-defining a term updated the managed footnote line, but the selected text transform still blindly appended `[^id]`, so selecting `ASIN` in `ASIN[^asin]` produced `ASIN[^asin][^asin]`. The close review caught the gap. Rule: when a feature creates both an inline reference and an external/durable record, add a repeat-on-rendered-output test that proves the inline reference is not duplicated while the external record updates.
---
id: 000167
status: working
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-08
started: 2026-07-08T10:12:09-07:00
estimate_hours: 0.91
---

# define diagnostic highlight should target footnote span

## Problem

After #166, visual definitions persist as `term[^id]` plus a managed footnote.
The diagnostic record spans that text, but the visible DiffChange decoration
still highlights the whole line. In a long paragraph that makes the annotation
appear paragraph-scoped instead of scoped to the selected text plus footnote
reference.

## Spec

- Visual definition diagnostics continue to cover the selected text plus the
  appended `[^id]` reference.
- The visible DiffChange highlight covers the same span, not the whole paragraph
  line.
- Undo/redo projection preserves that column span instead of restoring a
  full-line highlight or line-anchored diagnostic.

ARCH-PURE: keep span calculation in `define.apply_definition_footnote`.
ARCH-DRY: diagnostic and highlight ranges derive from the same span.
ARCH-PURPOSE: the fix is not complete if the visible decoration remains
paragraph-wide.

## Done when

- Defining `ASIN` inside `here is ASIN in context` highlights only
  `ASIN[^asin]`.
- Undo/redo still clears/restores the define diagnostic and exact highlight.
- After redo, both the diagnostic and highlight still span `ASIN[^asin]`, with
  diagnostic `col`/`end_col` preserved.
- Focused define/render tests and final verification pass.

## Estimate

Produced via `estimate-logic-v3.1` against the repo-local calibration source
reported by `sdlc estimate-source` (stale but canonical for this repo). Method A
only.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.10 impl=0.00
item: lua-neovim design=0.20 impl=0.37
item: milestone-review design=0.00 impl=0.15
total: 0.91
```

## Plan

- [x] Add failing tests for exact define highlight/diagnostic spans and projection restore.
- [x] Add span highlight support to `skill_render` and preserve highlight plus diagnostic spans in snapshots.
- [x] Render define highlight from `DefinitionDiagnosticSpan`.
- [x] Run focused and final verification.

## Log

### 2026-07-08
- Created after user reported that #166 definitions visibly annotate the whole
  paragraph instead of the selected term/reference span. Root cause: define still
  used `skill_render.highlight_line`, and projection snapshots only restored
  whole-line highlights.
- Added failing coverage:
  `tests/unit/skill_render_spec.lua` failed because `highlight_span` did not
  exist; `tests/integration/define_spec.lua` failed because the define
  highlight and redo-restored highlight started at column 0 instead of column 8.
- Implemented `skill_render.highlight_span`, preserved highlight and diagnostic
  column spans in `snapshot`/`apply_snapshot`, and switched define rendering to
  use `e.diagnostic_span` for the visible highlight.
- Focused verification passed:
  `nvim --headless -c "PlenaryBustedFile tests/unit/skill_render_spec.lua"` and
  `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`.
- Final verification passed: `git diff --check -- lua/parley/skill_render.lua
  lua/parley/init.lua tests/unit/skill_render_spec.lua
  tests/integration/define_spec.lua
  workshop/issues/000167-define-diagnostic-highlight-span.md
  workshop/plans/000167-define-diagnostic-highlight-span-plan.md` and
  `make test`.

codex
I’ve got the issue contract now. Next I’m reading the surrounding implementation, the span producer, and tests so I can check whether the diff really uses one source of span truth and whether undo/redo projection stays compatible.
exec
/bin/zsh -lc "sed -n '120,260p' lua/parley/skill_render.lua" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
        })
    end
    vim.diagnostic.set(diag_ns_id, buf, diagnostics)
end

--- Highlight edited regions with DiffChange.
--- @param buf number
--- @param edits table[]  applied edits with {new_string}
--- @param new_content string  file content after edits
function M.highlight_edits(buf, edits, new_content)
    ensure_namespaces()
    for _, edit in ipairs(edits) do
        -- Skip pure deletions: new_string is "" and `find("")` returns 1, which
        -- would spuriously highlight line 0. Deletions are oriented by their
        -- INFO gutter diagnostic (the "why") via attach_diagnostics, not a
        -- highlight (there's no new text to mark). #133.
        local new_pos = (edit.new_string and edit.new_string ~= "")
            and new_content:find(edit.new_string, 1, true)
            or nil
        if new_pos then
            local start_line = 0
            for _ in new_content:sub(1, new_pos):gmatch("\n") do
                start_line = start_line + 1
            end
            local end_line = start_line
            for _ in edit.new_string:gmatch("\n") do
                end_line = end_line + 1
            end
            for line = start_line, end_line do
                vim.api.nvim_buf_add_highlight(buf, hl_ns_id, "DiffChange", line, 0, -1)
            end
        end
    end
end

--- Highlight a whole line with DiffChange on the hl namespace (#161 R1). Same
--- shape `apply_snapshot` restores (whole-line, col 0..-1), so it round-trips
--- through projection's line-granular undo/redo snapshotting.
--- @param buf number
--- @param lnum0 number  0-based line
function M.highlight_line(buf, lnum0)
    ensure_namespaces()
    vim.api.nvim_buf_add_highlight(buf, hl_ns_id, "DiffChange", lnum0, 0, -1)
end

--- Highlight a column span with DiffChange on the hl namespace. The four-arg
--- form is same-line: (buf, lnum0, col_start, col_end). The five-arg form spans
--- rows: (buf, lnum0, col_start, end_lnum0, col_end).
--- @param buf number
--- @param lnum0 number 0-based start line
--- @param col_start number 0-based start column
--- @param end_lnum0_or_col_end number 0-based end line, or end column
--- @param col_end number|nil 0-based exclusive end column
function M.highlight_span(buf, lnum0, col_start, end_lnum0_or_col_end, col_end)
    ensure_namespaces()
    local end_lnum0 = lnum0
    if col_end == nil then
        col_end = end_lnum0_or_col_end
    else
        end_lnum0 = end_lnum0_or_col_end
    end
    vim.api.nvim_buf_set_extmark(buf, hl_ns_id, lnum0, col_start, {
        end_row = end_lnum0,
        end_col = col_end,
        hl_group = "DiffChange",
        strict = false,
    })
end

--- Capture the current decoration set as redrawable data (for the undo/redo
--- projection record, #133 M5). Whole-line highlights stay in `hl_lines`; span
--- highlights and diagnostics preserve columns so exact anchors can be restored.
function M.snapshot(buf)
    ensure_namespaces()
    local hl_lines = {}
    local hl_spans = {}
    for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf, hl_ns_id, 0, -1, { details = true })) do
        local details = m[4] or {}
        local is_legacy_line = m[3] == 0 and details.end_row == m[2] + 1 and details.end_col == 0
        if is_legacy_line or details.end_row == nil or details.end_col == nil then
            table.insert(hl_lines, m[2]) -- m = {id, row, col}; row is the 0-based line
        else
            table.insert(hl_spans, {
                lnum = m[2],
                col = m[3],
                end_lnum = details.end_row,
                end_col = details.end_col,
            })
        end
    end
    local diags = {}
    for _, d in ipairs(vim.diagnostic.get(buf, { namespace = diag_ns_id })) do
        table.insert(diags, {
            lnum = d.lnum,
            col = d.col or 0,
            end_lnum = d.end_lnum,
            end_col = d.end_col,
            message = d.message,
        })
    end
    return { hl_lines = hl_lines, hl_spans = hl_spans, diags = diags }
end

--- Redraw a snapshot's decorations (clearing first). Only valid when the buffer
--- content matches the state the snapshot was captured at (the projection caller
--- guarantees this via a content-hash match). #133 M5.
function M.apply_snapshot(buf, snap)
    ensure_namespaces()
    M.clear_decorations(buf)
    snap = snap or {}
    for _, line in ipairs(snap.hl_lines or {}) do
        vim.api.nvim_buf_add_highlight(buf, hl_ns_id, "DiffChange", line, 0, -1)
    end
    for _, span in ipairs(snap.hl_spans or {}) do
        M.highlight_span(buf, span.lnum, span.col or 0, span.end_lnum or span.lnum, span.end_col)
    end
    if snap.diags and #snap.diags > 0 then
        local diagnostics = {}
        for _, d in ipairs(snap.diags) do
            table.insert(diagnostics, {
                lnum = d.lnum,
                end_lnum = d.end_lnum or d.lnum,
                col = d.col or 0,
                end_col = d.end_col,
                message = d.message,
                severity = vim.diagnostic.severity.INFO,
                source = "parley-skill",
            })
        end
        vim.diagnostic.set(diag_ns_id, buf, diagnostics)
    end
end

return M

exec
/bin/zsh -lc "sed -n '1540,1685p' lua/parley/init.lua" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
	local sr, sc = sp[2], sp[3]
	local er, ec = ep[2], ep[3]
	if sr == 0 or er == 0 then return end

	local lines_in_range = vim.api.nvim_buf_get_lines(buf, sr - 1, er, false)
	if #lines_in_range == 0 then return end

	-- Clamp end col for V-line mode (col can be huge)
	local end_line_text = lines_in_range[#lines_in_range]
	if ec > #end_line_text then ec = #end_line_text end

	local prefix = lines_in_range[1]:sub(1, sc - 1)
	local suffix = end_line_text:sub(ec + 1)

	-- #161 ARCH-DRY: one shared visual-selection slice (define.slice_selection).
	-- lines_in_range is the [sr..er] slice, so line sr → index 1, er → er-sr+1;
	-- getpos cols are 1-based, slice_selection takes 0-based (sub(sc, ec)).
	local selected = require("parley.define").slice_selection(
		lines_in_range, 1, sc - 1, er - sr + 1, ec - 1)

	if selected == "" then
		M.logger.warning("Drill-in: empty selection")
		return
	end

	local wrapped_lines = vim.split(_drill_in_mod.wrap(selected), "\n", { plain = true })
	local new_lines = {}
	if #wrapped_lines == 1 then
		table.insert(new_lines, prefix .. wrapped_lines[1] .. suffix)
	else
		table.insert(new_lines, prefix .. wrapped_lines[1])
		for i = 2, #wrapped_lines - 1 do
			table.insert(new_lines, wrapped_lines[i])
		end
		table.insert(new_lines, wrapped_lines[#wrapped_lines] .. suffix)
	end

	vim.api.nvim_buf_set_lines(buf, sr - 1, er, false, new_lines)

	-- Cursor between [ and ] in the last line of wrapped text. Wrap always
	-- ends with `[]`, so placing the cursor at the index of `]` (0-based)
	-- puts it between `[` and `]`, ready for insert.
	local last_wrapped = wrapped_lines[#wrapped_lines]
	local target_row, target_col
	if #wrapped_lines == 1 then
		target_row = sr
		target_col = #prefix + #last_wrapped - 1
	else
		target_row = sr + #wrapped_lines - 1
		target_col = #last_wrapped - 1
	end
	vim.api.nvim_win_set_cursor(0, { target_row, target_col })
	vim.schedule(function() vim.cmd("startinsert") end)
end

-- Inline term definition (#161 + R1, #166). render_definition is the on_done IO
-- seam. On a successful lookup it stores the definition as a durable markdown
-- footnote (ONE undo entry — the anchor), highlights the selected term/reference
-- span (DiffChange), and shows the definition as an ephemeral INFO
-- diagnostic. Undo/redo coherence reuses review's projection watcher: undoing
-- the footnote edit lands on the pre-edit content-hash → the empty snapshot
-- renders → both decorations clear.
-- `span` = the visual selection {sr, sc, er, ec} (1-based getpos values).
local function render_definition(buf, span, phrase, result)
	-- Pick the emit_definition call (unforced → the model may answer in text or
	-- only call web_search; both mean "no definition"). Notify rather than
	-- silently doing nothing, and leave no footnote edit.
	local call
	if result and result.calls then
		for _, c in ipairs(result.calls) do
			if c.name == "emit_definition" then
				call = c
				break
			end
		end
	end
	if not call then
		M.logger.warning("Define: no definition returned")
		return
	end

	local sr, sc, er, ec = span[1], span[2], span[3], span[4]
	local define = require("parley.define")
	local skill_render = require("parley.skill_render")
	local projection = require("parley.skills.review.projection")

	-- The buffer may have changed under the in-flight call; skip the whole render
	-- rather than attach a footnote reference to shifted text.
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	if define.slice_selection(lines, sr, sc - 1, er, ec - 1) ~= phrase then
		M.logger.warning("Define: selection changed during lookup — re-select to define")
		return
	end
	local original = table.concat(lines, "\n") -- pre-edit content (undo base)

	-- Store the definition as a markdown footnote in ONE full-buffer set_lines
	-- edit (single undo entry = the anchor). set_applying suppresses any prior
	-- define's projection watcher during our own edit (mirrors review).
	projection.set_applying(buf, true)
	local input = call.input or {}
	local e = define.apply_definition_footnote(lines, sr, sc - 1, er, ec - 1, input.term or phrase, input.definition)
	require("parley.buffer_edit").replace_all_lines_for_definition(buf, e.lines)

	local width = math.max(40, vim.api.nvim_win_get_width(0) - 8)
	local msg = define.format_definition(input.term or phrase, e.definition, width)
	local diag_span = e.diagnostic_span
	skill_render.highlight_span(buf, diag_span.lnum, diag_span.col, diag_span.end_lnum, diag_span.end_col)
	vim.diagnostic.set(skill_render.diag_namespace(), buf, { {
		lnum = diag_span.lnum,
		col = diag_span.col,
		end_lnum = diag_span.end_lnum,
		end_col = diag_span.end_col,
		message = msg,
		severity = vim.diagnostic.severity.INFO,
		source = "parley-define",
	} })

	-- Record projection states so undo/redo of the footnote edit clears/restores
	-- the decorations (#133 M5 machinery, reused): pre-edit hash → empty
	-- snapshot, footnoted hash → highlight+diagnostic; attach the watcher.
	projection.record_empty_for(buf, original)
	projection.record(buf)
	projection.ensure_watch(buf)
	projection.set_applying(buf, false)

	-- Park the cursor on the term's line so diag_display's current-line
	-- virtual_lines reveals the definition immediately.
	pcall(vim.api.nvim_win_set_cursor, 0, { sr, math.max(0, sc - 1) })
	vim.cmd("redraw")
end

-- define_visual: the thin IO shell for visual-mode <M-CR>. Reads the selection,
-- computes the enclosing-exchange context, and fires a headless define skill
-- turn whose on_done stores + renders the definition inline. Pure logic lives
-- in lua/parley/define.lua. Exposed as M.define_visual for the keybinding.
function M.define_visual(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	local sp = vim.fn.getpos("'<")
	local ep = vim.fn.getpos("'>")
	local sr, sc = sp[2], sp[3]
	local er, ec = ep[2], ep[3]
	if sr == 0 or er == 0 then return end

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local define = require("parley.define")
	-- getpos cols are 1-based; slice_selection takes 0-based (sub(sc, ec)).

exec
/bin/zsh -lc "rg -n \"diagnostic_span|apply_definition_footnote|highlight_line|highlight_span|snapshot\\(|apply_snapshot\" lua tests atlas README.md workshop/issues/000167-define-diagnostic-highlight-span.md workshop/plans/000167-define-diagnostic-highlight-span-plan.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
workshop/issues/000167-define-diagnostic-highlight-span.md:31:ARCH-PURE: keep span calculation in `define.apply_definition_footnote`.
workshop/issues/000167-define-diagnostic-highlight-span.md:72:  used `skill_render.highlight_line`, and projection snapshots only restored
workshop/issues/000167-define-diagnostic-highlight-span.md:75:  `tests/unit/skill_render_spec.lua` failed because `highlight_span` did not
workshop/issues/000167-define-diagnostic-highlight-span.md:78:- Implemented `skill_render.highlight_span`, preserved highlight and diagnostic
workshop/issues/000167-define-diagnostic-highlight-span.md:79:  column spans in `snapshot`/`apply_snapshot`, and switched define rendering to
workshop/issues/000167-define-diagnostic-highlight-span.md:80:  use `e.diagnostic_span` for the visible highlight.
workshop/plans/000167-define-diagnostic-highlight-span-plan.md:7:**Architecture:** Keep the span math in the existing pure `define.apply_definition_footnote` result (ARCH-PURE), and extend `skill_render`'s decoration snapshot to preserve column spans for undo/redo projection (ARCH-DRY). `render_definition` remains the thin IO shell that applies the span highlight and diagnostic.
workshop/plans/000167-define-diagnostic-highlight-span-plan.md:21:- **DefinitionDiagnosticSpan** — the selected term plus immediate `[^id]` reference range returned by `apply_definition_footnote`.
workshop/plans/000167-define-diagnostic-highlight-span-plan.md:49:- `skill_render.snapshot` and `apply_snapshot` preserve highlight columns.
workshop/plans/000167-define-diagnostic-highlight-span-plan.md:50:- `skill_render.snapshot` and `apply_snapshot` preserve diagnostic `col` and
workshop/plans/000167-define-diagnostic-highlight-span-plan.md:60:Expected: FAIL because define currently uses `highlight_line` and snapshots restore highlights as full-line.
workshop/plans/000167-define-diagnostic-highlight-span-plan.md:70:Add a `skill_render.highlight_span(buf, lnum0, col_start, col_end)` helper that writes a `DiffChange` extmark on the existing highlight namespace.
workshop/plans/000167-define-diagnostic-highlight-span-plan.md:75:and `apply_snapshot` to restore them. Preserve backward compatibility for
workshop/plans/000167-define-diagnostic-highlight-span-plan.md:80:Replace `highlight_line` calls in `render_definition` with `highlight_span` using `e.diagnostic_span`.
lua/parley/define.lua:121:function M.diagnostic_span_after_bracket(l1, c1, l2, c2)
lua/parley/define.lua:275:--- @return table { lines: string[], id: string, definition: string, diagnostic_span: table }
lua/parley/define.lua:276:function M.apply_definition_footnote(lines, l1, c1, l2, c2, term, definition)
lua/parley/define.lua:302:        diagnostic_span = {
atlas/modes/review.md:148:  `skill_render.snapshot`/`apply_snapshot`);
lua/parley/highlighter.lua:24:    for _, span in ipairs(artifact_ref.highlight_spans(line)) do
atlas/chat/inline_define.md:32:   (`define.apply_definition_footnote`) — a single undo entry that anchors
atlas/chat/inline_define.md:34:   (`skill_render.highlight_line`); **(c)** sets one INFO `vim.diagnostic` on
atlas/chat/inline_define.md:52:`skill_render.snapshot`/`apply_snapshot` are line-granular. `set_applying`
atlas/chat/inline_define.md:59:  wrap as a legacy set_lines edit), `diagnostic_span_after_bracket` (legacy range
atlas/chat/inline_define.md:60:  mapping), `apply_definition_footnote` (durable footer transform), and
lua/parley/init.lua:1640:	local e = define.apply_definition_footnote(lines, sr, sc - 1, er, ec - 1, input.term or phrase, input.definition)
lua/parley/init.lua:1645:	local diag_span = e.diagnostic_span
lua/parley/init.lua:1646:	skill_render.highlight_span(buf, diag_span.lnum, diag_span.col, diag_span.end_lnum, diag_span.end_col)
lua/parley/artifact_ref.lua:10:-- iter_refs, parse_ref_at_cursor, parse_resolve_output, highlight_spans,
lua/parley/artifact_ref.lua:57:-- highlight_spans(line) -> { { col_start, col_end }, ... }: the 0-indexed extmark
lua/parley/artifact_ref.lua:62:function M.highlight_spans(line)
lua/parley/skill_render.lua:156:--- shape `apply_snapshot` restores (whole-line, col 0..-1), so it round-trips
lua/parley/skill_render.lua:160:function M.highlight_line(buf, lnum0)
lua/parley/skill_render.lua:173:function M.highlight_span(buf, lnum0, col_start, end_lnum0_or_col_end, col_end)
lua/parley/skill_render.lua:192:function M.snapshot(buf)
lua/parley/skill_render.lua:226:function M.apply_snapshot(buf, snap)
lua/parley/skill_render.lua:234:        M.highlight_span(buf, span.lnum, span.col or 0, span.end_lnum or span.lnum, span.end_col)
tests/unit/skill_render_spec.lua:87:    it("snapshot captures highlights + diagnostics; apply_snapshot restores them", function()
tests/unit/skill_render_spec.lua:92:        local snap = skill_render.snapshot(buf)
tests/unit/skill_render_spec.lua:98:        skill_render.apply_snapshot(buf, snap)
tests/unit/skill_render_spec.lua:112:        skill_render.highlight_span(buf, 0, 8, 19)
tests/unit/skill_render_spec.lua:123:        local snap = skill_render.snapshot(buf)
tests/unit/skill_render_spec.lua:125:        skill_render.apply_snapshot(buf, snap)
tests/unit/define_spec.lua:107:describe("define.diagnostic_span_after_bracket", function()
tests/unit/define_spec.lua:109:        local span = define.diagnostic_span_after_bracket(3, 9, 3, 12)
tests/unit/define_spec.lua:119:        local span = define.diagnostic_span_after_bracket(1, 7, 3, 3)
tests/unit/define_spec.lua:137:        local result = define.apply_definition_footnote(
tests/unit/define_spec.lua:151:        assert.are.same({ lnum = 0, col = 8, end_lnum = 0, end_col = 19 }, result.diagnostic_span)
tests/unit/define_spec.lua:157:        local result = define.apply_definition_footnote(
tests/unit/define_spec.lua:180:        local result = define.apply_definition_footnote(
tests/unit/define_spec.lua:200:        assert.are.same({ lnum = 0, col = 0, end_lnum = 0, end_col = 11 }, result.diagnostic_span)
tests/unit/artifact_ref_spec.lua:55:describe("highlight_spans", function()
tests/unit/artifact_ref_spec.lua:60:        local spans = ar.highlight_spans(line)
tests/unit/artifact_ref_spec.lua:70:        local spans = ar.highlight_spans(line)
lua/parley/skills/review/projection.lua:71:    put(bufstate(buf), hash(buf), skill_render.snapshot(buf))
lua/parley/skills/review/projection.lua:97:        skill_render.apply_snapshot(buf, s.records[h]) -- undo/redo → re-render the record
lua/parley/skills/review/projection.lua:99:        put(s, h, skill_render.snapshot(buf)) -- novel forward state (B) → snapshot riding decos

exec
/bin/zsh -lc "sed -n '1,260p' lua/parley/define.lua" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
-- Pure core for the inline term-definition feature (#161).
-- No Neovim APIs here — these functions operate on plain tables/strings so they
-- are unit-tested directly (tests/unit/define_spec.lua). The IO shell
-- (define_visual / render_definition) lives in lua/parley/init.lua.

local M = {}

--- Extract the charwise-visual selection [l1,c1]..[l2,c2] from `lines`.
--- l1/l2 are 1-based line numbers; c1/c2 are 0-based byte columns where c2 is
--- the *inclusive* end column (matches getpos("'>") after subtracting 1).
--- Multi-line spans join with "\n"; columns clamp to line length; a reversed
--- span returns "".
--- @param lines string[]
--- @param l1 integer
--- @param c1 integer
--- @param l2 integer
--- @param c2 integer
--- @return string
function M.slice_selection(lines, l1, c1, l2, c2)
    if l1 > l2 or (l1 == l2 and c1 > c2) then
        return ""
    end
    if l1 == l2 then
        local line = lines[l1] or ""
        return line:sub(c1 + 1, math.min(c2 + 1, #line))
    end
    local out = {}
    for l = l1, l2 do
        local line = lines[l] or ""
        if l == l1 then
            out[#out + 1] = line:sub(c1 + 1)
        elseif l == l2 then
            out[#out + 1] = line:sub(1, math.min(c2 + 1, #line))
        else
            out[#out + 1] = line
        end
    end
    return table.concat(out, "\n")
end

--- The bounded context sent to the model: the line range of the enclosing
--- exchange of `sel_line`, else the whole buffer. `find_exchange` is injected
--- (default = require("parley").find_exchange_at_line) so this stays pure and
--- unit-testable with a synthetic parsed_chat + finder.
--- @param parsed_chat table  -- { exchanges = { { question={line_start,line_end}, answer={...}|nil }, ... } }
--- @param sel_line integer   -- 1-based line of the selection
--- @param all_lines string[]
--- @param find_exchange fun(pc:table, line:integer):integer|nil
--- @return string
function M.context_for_selection(parsed_chat, sel_line, all_lines, find_exchange)
    find_exchange = find_exchange or require("parley").find_exchange_at_line
    local idx = find_exchange(parsed_chat, sel_line)
    local ex = idx and parsed_chat.exchanges and parsed_chat.exchanges[idx]
    if not ex then
        return table.concat(all_lines, "\n") -- whole-buffer fallback
    end
    local lo = ex.question.line_start
    local hi = (ex.answer and ex.answer.line_end) or ex.question.line_end
    local slice = {}
    for l = lo, hi do
        slice[#slice + 1] = all_lines[l]
    end
    return table.concat(slice, "\n")
end

--- Compose the diagnostic message ("TERM — definition"), hard-wrapped to width.
--- Delegates wrapping to skill_render.wrap (the same wrap the review path uses).
--- @param term string|nil
--- @param definition string|nil
--- @param width integer|nil
--- @return string
function M.format_definition(term, definition, width)
    definition = definition or ""
    definition = (definition:gsub("%s+$", "")) -- parens → keep only the string
    if definition == "" then
        definition = "(no definition)"
    end
    local head = tostring(term or "") .. " — " .. definition
    return require("parley.skill_render").wrap(head, width or 80)
end

--- Plan the reference-bracket wrap of the selection ([term]) as a set_lines edit
--- (#161 R1). Same arg convention as slice_selection (l1/l2 1-based, c1/c2
--- 0-based byte, c2 inclusive). Returns the affected 0-based line range + the
--- rewritten lines (selection wrapped in `[ ]`) for a single
--- `nvim_buf_set_lines(buf, first0, last, false, lines)` — one undo entry (the
--- anchor). `nvim_buf_set_text` is arch-forbidden outside buffer_edit; set_lines
--- is the same primitive `drill_in_visual` uses to wrap a selection. Pure.
--- @param lines string[]
--- @param l1 integer
--- @param c1 integer
--- @param l2 integer
--- @param c2 integer
--- @return table  { first0, last, lines }
function M.bracket_edit(lines, l1, c1, l2, c2)
    local selected = M.slice_selection(lines, l1, c1, l2, c2)
    local first = lines[l1] or ""
    local last = lines[l2] or ""
    local new_lines = {}
    if l1 == l2 then
        local ec = math.min(c2 + 1, #first)
        new_lines[1] = first:sub(1, c1) .. "[" .. selected .. "]" .. first:sub(ec + 1)
    else
        local ec = math.min(c2 + 1, #last)
        new_lines[1] = first:sub(1, c1) .. "[" .. first:sub(c1 + 1)
        for l = l1 + 1, l2 - 1 do
            new_lines[#new_lines + 1] = lines[l]
        end
        new_lines[#new_lines + 1] = last:sub(1, ec) .. "]" .. last:sub(ec + 1)
    end
    return { first0 = l1 - 1, last = l2, lines = new_lines }
end

--- Convert a visual span from getpos columns to the diagnostic range after
--- bracket_edit inserts "[" before the selection and "]" after it.
--- @param l1 integer 1-based start line
--- @param c1 integer 1-based start column from getpos("'<")
--- @param l2 integer 1-based end line
--- @param c2 integer 1-based inclusive end column from getpos("'>")
--- @return table { lnum: integer, col: integer, end_lnum: integer, end_col: integer }
function M.diagnostic_span_after_bracket(l1, c1, l2, c2)
    return {
        lnum = l1 - 1,
        col = c1,
        end_lnum = l2 - 1,
        end_col = (l1 == l2) and (c2 + 1) or c2,
    }
end

--- @param s string
--- @return string
local function trim(s)
    local out = (s or ""):gsub("^%s*(.-)%s*$", "%1")
    return out
end

--- Convert a term into a stable markdown footnote id.
--- @param term string|nil
--- @return string
function M.footnote_id(term)
    local id = tostring(term or ""):lower()
    id = id:gsub("[^%w]+", "-")
    id = id:gsub("^%-+", ""):gsub("%-+$", "")
    if id == "" then
        id = "definition"
    end
    return id
end

--- @param id string
--- @param definition string|nil
--- @return string
function M.format_footnote_line(id, definition)
    definition = trim(definition)
    if definition == "" then
        definition = "(no definition)"
    end
    return string.format("[^%s]: %s", id, definition)
end

local function is_divider(line)
    return trim(line) == "---"
end

local function is_footnote_line(line)
    return trim(line):match("^%[%^[^%]]+%]:") ~= nil
end

local function managed_footer_start(lines)
    for i = #lines, 1, -1 do
        if is_divider(lines[i]) then
            local has_footnote = false
            for j = i + 1, #lines do
                local line = lines[j] or ""
                if trim(line) ~= "" then
                    if not is_footnote_line(line) then
                        return nil
                    end
                    has_footnote = true
                end
            end
            if has_footnote then
                return i
            end
            return nil
        end
    end
    return nil
end

local function split_text_lines(text)
    text = text or ""
    local lines = {}
    local start = 1
    while true do
        local nl = text:find("\n", start, true)
        if not nl then
            lines[#lines + 1] = text:sub(start)
            break
        end
        lines[#lines + 1] = text:sub(start, nl - 1)
        start = nl + 1
    end
    if #lines > 1 and lines[#lines] == "" then
        table.remove(lines)
    end
    return lines
end

local function copy_lines(lines)
    local out = {}
    for i, line in ipairs(lines or {}) do
        out[i] = line
    end
    return out
end

--- Strip a final managed definition-footnote footer from text.
--- @param text string|nil
--- @return string
function M.strip_definition_footnote_footer(text)
    local lines = split_text_lines(text or "")
    local start = managed_footer_start(lines)
    if not start then
        return text or ""
    end
    while start > 1 and trim(lines[start - 1]) == "" do
        start = start - 1
    end
    local kept = {}
    for i = 1, start - 1 do
        kept[#kept + 1] = lines[i]
    end
    while #kept > 0 and trim(kept[#kept]) == "" do
        table.remove(kept)
    end
    return table.concat(kept, "\n")
end

local function replace_or_append_footnote(lines, id, definition)
    local out = copy_lines(lines)
    local footer = managed_footer_start(out)
    local footnote_line = M.format_footnote_line(id, definition)
    if footer then
        for i = footer + 1, #out do
            local escaped_id = id:gsub("([^%w])", "%%%1")
            if trim(out[i]):match("^%[%^" .. escaped_id .. "%]:") then
                out[i] = footnote_line
                return out
            end
        end
        out[#out + 1] = footnote_line
        return out
    end

    while #out > 0 and trim(out[#out]) == "" do
        table.remove(out)
    end
    out[#out + 1] = ""
    out[#out + 1] = "---"

exec
/bin/zsh -lc "sed -n '260,360p' lua/parley/define.lua && sed -n '80,150p' tests/unit/skill_render_spec.lua && sed -n '230,350p' tests/integration/define_spec.lua && git diff --name-only 5640bcaa934b0b5bc4c6c2d18b042996afd74f83...HEAD" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
    out[#out + 1] = "---"
    out[#out + 1] = ""
    out[#out + 1] = footnote_line
    return out
end

--- Insert a markdown footnote reference after the selected text and store the
--- definition in a managed footer.
--- @param lines string[]
--- @param l1 integer
--- @param c1 integer 0-based byte column
--- @param l2 integer
--- @param c2 integer 0-based inclusive byte column
--- @param term string
--- @param definition string|nil
--- @return table { lines: string[], id: string, definition: string, diagnostic_span: table }
function M.apply_definition_footnote(lines, l1, c1, l2, c2, term, definition)
    local id = M.footnote_id(term)
    local ref = "[^" .. id .. "]"
    local out = copy_lines(lines)
    if l1 == l2 then
        local line = out[l1] or ""
        local ec = math.min(c2 + 1, #line)
        if line:sub(ec + 1, ec + #ref) ~= ref then
            out[l1] = line:sub(1, ec) .. ref .. line:sub(ec + 1)
        end
    else
        local line = out[l2] or ""
        local ec = math.min(c2 + 1, #line)
        if line:sub(ec + 1, ec + #ref) ~= ref then
            out[l2] = line:sub(1, ec) .. ref .. line:sub(ec + 1)
        end
    end
    out = replace_or_append_footnote(out, id, definition)
    local normalized_definition = trim(definition)
    if normalized_definition == "" then
        normalized_definition = "(no definition)"
    end
    return {
        lines = out,
        id = id,
        definition = normalized_definition,
        diagnostic_span = {
            lnum = l1 - 1,
            col = c1,
            end_lnum = l2 - 1,
            end_col = c2 + 1 + #ref,
        },
    }
end

return M
        }, original)
        local d = vim.diagnostic.get(buf)[1]
        assert.are.equal(1, d.lnum) -- 0-based line of "b"
        assert.are.equal(2, d.end_lnum) -- spans the 2-line new_string
        assert.is_truthy(d.message:find("\n"), "long message is wrapped")
    end)

    it("snapshot captures highlights + diagnostics; apply_snapshot restores them", function()
        local buf = scratch({ "line one", "line two", "line three" })
        local content = "line one\nline two\nline three"
        skill_render.highlight_edits(buf, { { new_string = "line two" } }, content)
        skill_render.attach_diagnostics(buf, { { pos = content:find("two"), explain = "why two" } }, content)
        local snap = skill_render.snapshot(buf)
        assert.is_true(#snap.hl_lines >= 1)
        assert.is_true(#snap.diags >= 1)
        -- clear → empty, then restore from the snapshot
        skill_render.clear_decorations(buf)
        assert.are.equal(0, #vim.diagnostic.get(buf))
        skill_render.apply_snapshot(buf, snap)
        local diags = vim.diagnostic.get(buf)
        assert.is_true(#diags >= 1)
        assert.matches("why two", diags[1].message)
        assert.is_not_nil(diags[1].end_lnum, "end_lnum survives snapshot→apply (#133 M6)")
        local hl_ns = vim.api.nvim_create_namespace("parley_skill_hl")
        assert.is_true(#vim.api.nvim_buf_get_extmarks(buf, hl_ns, 0, -1, {}) >= 1)
    end)

    it("snapshot captures and restores highlight and diagnostic column spans", function()
        local buf = scratch({ "here is ASIN[^asin] in context" })
        local hl_ns = vim.api.nvim_create_namespace("parley_skill_hl")
        local diag_ns = skill_render.diag_namespace()

        skill_render.highlight_span(buf, 0, 8, 19)
        vim.diagnostic.set(diag_ns, buf, { {
            lnum = 0,
            col = 8,
            end_lnum = 0,
            end_col = 19,
            message = "why",
            severity = vim.diagnostic.severity.INFO,
            source = "test",
        } })

        local snap = skill_render.snapshot(buf)
        skill_render.clear_decorations(buf)
        skill_render.apply_snapshot(buf, snap)

        local marks = vim.api.nvim_buf_get_extmarks(buf, hl_ns, 0, -1, { details = true })
        assert.are.equal(1, #marks)
        assert.are.equal(0, marks[1][2])
        assert.are.equal(8, marks[1][3])
        assert.are.equal(0, marks[1][4].end_row)
        assert.are.equal(19, marks[1][4].end_col)

        local diags = vim.diagnostic.get(buf, { namespace = diag_ns })
        assert.are.equal(1, #diags)
        assert.are.equal(8, diags[1].col)
        assert.are.equal(19, diags[1].end_col)
    end)

    it("dismiss clears decorations (alias of clear_decorations)", function()
        local buf = scratch({ "x" })
        skill_render.attach_diagnostics(buf, { { pos = 1, explain = "e" } }, "x")
        assert.is_true(#vim.diagnostic.get(buf) > 0)
        skill_render.dismiss(buf)
        assert.are.equal(0, #vim.diagnostic.get(buf))
    end)
end)
        vim.fn.delete(tmpdir, "rf")
    end)

    local hl_ns = vim.api.nvim_create_namespace("parley_skill_hl")
    local function hl_on_line(b, line0)
        for _, m in ipairs(vim.api.nvim_buf_get_extmarks(b, hl_ns, 0, -1, {})) do
            if m[2] == line0 then return true end
        end
        return false
    end
    local function first_hl_mark(b)
        return vim.api.nvim_buf_get_extmarks(b, hl_ns, 0, -1, { details = true })[1]
    end

    it("stores the definition as a durable footnote, highlights the term/reference span, and shows the diagnostic", function()
        -- select "ASIN" on line 3 (cols 9..12, 1-based)
        vim.fn.setpos("'<", { buf, 3, 9, 0 })
        vim.fn.setpos("'>", { buf, 3, 12, 0 })
        require("parley").define_visual(buf)
        vim.wait(2000, function()
            return #vim.diagnostic.get(buf, { namespace = ns }) > 0
        end)
        -- Footnote reference written into the line (the undo anchor)
        assert.are.equal("here is ASIN[^asin] in context",
            vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1])
        assert.are.same({
            "---",
            "",
            "[^asin]: Amazon Standard Identification Number.",
        }, vim.api.nvim_buf_get_lines(buf, 5, 8, false))
        -- diagnostic on the term's line
        local diags = vim.diagnostic.get(buf, { namespace = ns })
        assert.are.equal(2, diags[1].lnum) -- 0-based line 3
        assert.are.equal(8, diags[1].col)
        assert.are.equal(2, diags[1].end_lnum)
        assert.are.equal(19, diags[1].end_col) -- ASIN plus [^asin]
        assert.is_true(diags[1].message:find("ASIN", 1, true) ~= nil)
        -- DiffChange highlight covers only ASIN[^asin], not the whole paragraph.
        local mark = first_hl_mark(buf)
        assert.is_not_nil(mark, "term/reference span not highlighted")
        assert.are.equal(2, mark[2])
        assert.are.equal(8, mark[3])
        assert.are.equal(2, mark[4].end_row)
        assert.are.equal(19, mark[4].end_col)
    end)

    it("re-defining a footnoted term updates the footer without duplicating the inline reference", function()
        vim.fn.setpos("'<", { buf, 3, 9, 0 })
        vim.fn.setpos("'>", { buf, 3, 12, 0 })
        require("parley").define_visual(buf)
        vim.wait(2000, function()
            return vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1] == "here is ASIN[^asin] in context"
        end)

        parley.dispatcher.query = function(_b, _p, _payload, _h, on_exit)
            tasker.set_query("qid_dv_updated", {
                raw_response = emit_definition_sse("ASIN", "Updated definition."),
            })
            vim.schedule(function() on_exit("qid_dv_updated") end)
        end

        vim.fn.setpos("'<", { buf, 3, 9, 0 })
        vim.fn.setpos("'>", { buf, 3, 12, 0 })
        require("parley").define_visual(buf)
        vim.wait(2000, function()
            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            return table.concat(lines, "\n"):find("%[%^asin%]: Updated definition%.") ~= nil
        end)

        assert.are.equal("here is ASIN[^asin] in context",
            vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1])
        assert.are.same({
            "---",
            "",
            "[^asin]: Updated definition.",
        }, vim.api.nvim_buf_get_lines(buf, 5, 8, false))
    end)

    it("u undoes the footnote edit + clears decorations; C-r restores them (R1)", function()
        vim.fn.setpos("'<", { buf, 3, 9, 0 })
        vim.fn.setpos("'>", { buf, 3, 12, 0 })
        require("parley").define_visual(buf)
        vim.wait(2000, function()
            return #vim.diagnostic.get(buf, { namespace = ns }) > 0
        end)
        assert.are.equal("here is ASIN[^asin] in context",
            vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1])

        -- undo: the footnote edit reverts; the projection watcher (TextChanged) clears
        -- both decorations. Fire the autocmd Vim fires interactively — headless
        -- :undo doesn't trigger TextChanged on its own (the watcher itself is
        -- covered by projection's own specs; here we verify define's records).
        vim.cmd("silent undo")
        vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
        assert.are.equal("here is ASIN in context",
            vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1])
        assert.is_nil(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
            :find("%[%^asin%]:", 1, false), "footnote not removed on undo")
        assert.are.equal(0, #vim.diagnostic.get(buf, { namespace = ns }),
            "diagnostic not cleared on undo")
        assert.is_false(hl_on_line(buf, 2), "highlight not cleared on undo")

        -- redo: footnote edit + decorations return
        vim.cmd("silent redo")
        vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
        assert.are.equal("here is ASIN[^asin] in context",
            vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1])
        local redone_mark = first_hl_mark(buf)
        assert.is_not_nil(redone_mark, "highlight not restored on redo")
        assert.are.equal(2, redone_mark[2])
        assert.are.equal(8, redone_mark[3])
        assert.are.equal(2, redone_mark[4].end_row)
        assert.are.equal(19, redone_mark[4].end_col)
        local redone_diags = vim.diagnostic.get(buf, { namespace = ns })
        assert.are.equal(8, redone_diags[1].col)
        assert.are.equal(19, redone_diags[1].end_col)
        assert.is_true(#vim.diagnostic.get(buf, { namespace = ns }) >= 1,
            "diagnostic not restored on redo")
        assert.is_true(hl_on_line(buf, 2), "highlight not restored on redo")
    end)

lua/parley/init.lua
lua/parley/skill_render.lua
tests/integration/define_spec.lua
tests/unit/skill_render_spec.lua
workshop/issues/000167-define-diagnostic-highlight-span.md
workshop/plans/000167-define-diagnostic-highlight-span-plan.md

codex
One concrete gap is emerging: the code appears to satisfy the runtime span behavior, but the atlas still describes the old whole-line/line-granular projection model. I’m doing one more pass over the changed range and docs gate before I give the verdict.
exec
/bin/zsh -lc "sed -n '130,170p' atlas/modes/review.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
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
untouched. Default **on**: `virtual_lines { current_line = true }`, so the
(hard-wrapped, via `skill_render.wrap`) why **auto-expands below an edit when the
cursor is in that edit's region** (`attach_diagnostics` spans `lnum..end_lnum`)
and hides otherwise. `:ParleyShowDiagnostics` toggles it. The built-in `]d`/`[d`
(jump) and `<C-W>d` (float, wraps) also work on these diagnostics. Composes with
M5 — re-renders on undo/redo.

exec
/bin/zsh -lc "sed -n '1,120p' atlas/chat/inline_define.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
# Inline Term Definition

Select a phrase in a chat transcript, press **`<M-CR>`** (visual mode), and a
concise, context-aware definition appears as an **ephemeral inline diagnostic**
(grey `virtual_lines`) under the phrase. The selected text stays in place and
gets a markdown footnote reference (`ASIN[^asin]`), while the definition is
stored in a managed footnote footer at the end of the chat transcript. The
whole annotation is **undoable** — `u` reverts the footnote edit and clears both
decorations (see Undo below). For jargon you don't know (e.g. `ASIN`), it's a
one-keystroke lookup. Added in
[#161](../../workshop/issues/000161-inline-term-definition.md) (R1 added the
highlight/undo); [#166](../../workshop/issues/000166-visual-selection-definition-system-manages-footnote.md)
made the definition durable as a managed footnote.

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
   everything; **(b)** highlights the line(s) whole-line `DiffChange`
   (`skill_render.highlight_line`); **(c)** sets one INFO `vim.diagnostic` on
   the selected term/reference span (`define.format_definition` →
   `skill_render.wrap`) on the `parley_skill` namespace; **(d)** records the
   undo/redo projection states.
   `diag_display`'s `virtual_lines{current_line=true}` reveals the diagnostic
   (cursor parked on the term's line). A no-`emit_definition` response leaves no
   footnote reference/footer.

## Undo (`u`) — reuses review's projection

Native `u` reverts *text*, not decorations. The footnote reference/footer rewrite
is the one text change, so `u` reverts it; the decorations are cleared/restored by review's
**projection watcher** (`skills/review/projection.lua`, #133 M5), which define
reuses: `render_definition` calls `projection.record_empty_for(buf, original)`
(pre-footnote hash → empty snapshot), `record(buf)` (footnoted hash → the
highlight + diagnostic), `ensure_watch(buf)`. Undoing the footnote edit lands on
the pre-footnote content-hash → the empty snapshot renders → both decorations clear;
`<C-r>` re-renders. The highlight must be **whole-line** because
`skill_render.snapshot`/`apply_snapshot` are line-granular. `set_applying`
guards the edit so a prior define's watcher doesn't mistake it for a user edit.

## Pure core vs IO shell (ARCH-PURE)

- **Pure** (`lua/parley/define.lua`, unit-tested with plain tables): `slice_selection`,
  `context_for_selection`, `format_definition`, `bracket_edit` (plans the `[term]`
  wrap as a legacy set_lines edit), `diagnostic_span_after_bracket` (legacy range
  mapping), `apply_definition_footnote` (durable footer transform), and
  `strip_definition_footnote_footer` (removes only a final `---` block followed
  solely by footnotes).
- **IO shell** (`lua/parley/init.lua`): `define_visual`, `render_definition`;
  `lua/parley/buffer_edit.lua` owns the full-buffer footnote rewrite.
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
prompt context.

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

## v1 limitations

- One diagnostic visible at a time (`invoke` resets the `parley_skill` namespace
  each turn); line-granular highlight (whole-line, required for the projection
  round-trip). Dismissal is via `u` — reverting the footnote reference/footer
  clears it; the diagnostic also auto-hides when the cursor leaves the line.
  The footnote persists in the file if saved. Shared `parley_skill`
  namespace/projection with review still applies (rare on chat buffers).

## Key files


exec
/bin/zsh -lc 'git diff --unified=80 5640bcaa934b0b5bc4c6c2d18b042996afd74f83...HEAD -- lua/parley/skill_render.lua lua/parley/init.lua tests/unit/skill_render_spec.lua tests/integration/define_spec.lua' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
diff --git a/lua/parley/init.lua b/lua/parley/init.lua
index 351ade5..a170178 100644
--- a/lua/parley/init.lua
+++ b/lua/parley/init.lua
@@ -1517,213 +1517,210 @@ end
 
 M.display_agent = function(buf, file_name)
 	highlighter.display_agent(buf, file_name)
 end
 
 --- Build display label for an agent, including web_search indicator suffix.
 ---@param agent_name string
 ---@param ag_conf table|nil
 ---@return string
 M.agent_display_name_with_web_search = function(agent_name, ag_conf)
 	return highlighter.agent_display_name_with_web_search(agent_name, ag_conf)
 end
 
 M._prepared_bufs = {}
 
 -- Drill-in handlers — shared between chat and markdown buffers (any buffer
 -- in `parley_buffer` scope). Take buf as an explicit param so they can be
 -- wired into both prep_chat and setup_markdown_keymaps.
 local _drill_in_mod = require("parley.drill_in")
 
 local function drill_in_visual(buf)
 	local sp = vim.fn.getpos("'<")
 	local ep = vim.fn.getpos("'>")
 	local sr, sc = sp[2], sp[3]
 	local er, ec = ep[2], ep[3]
 	if sr == 0 or er == 0 then return end
 
 	local lines_in_range = vim.api.nvim_buf_get_lines(buf, sr - 1, er, false)
 	if #lines_in_range == 0 then return end
 
 	-- Clamp end col for V-line mode (col can be huge)
 	local end_line_text = lines_in_range[#lines_in_range]
 	if ec > #end_line_text then ec = #end_line_text end
 
 	local prefix = lines_in_range[1]:sub(1, sc - 1)
 	local suffix = end_line_text:sub(ec + 1)
 
 	-- #161 ARCH-DRY: one shared visual-selection slice (define.slice_selection).
 	-- lines_in_range is the [sr..er] slice, so line sr → index 1, er → er-sr+1;
 	-- getpos cols are 1-based, slice_selection takes 0-based (sub(sc, ec)).
 	local selected = require("parley.define").slice_selection(
 		lines_in_range, 1, sc - 1, er - sr + 1, ec - 1)
 
 	if selected == "" then
 		M.logger.warning("Drill-in: empty selection")
 		return
 	end
 
 	local wrapped_lines = vim.split(_drill_in_mod.wrap(selected), "\n", { plain = true })
 	local new_lines = {}
 	if #wrapped_lines == 1 then
 		table.insert(new_lines, prefix .. wrapped_lines[1] .. suffix)
 	else
 		table.insert(new_lines, prefix .. wrapped_lines[1])
 		for i = 2, #wrapped_lines - 1 do
 			table.insert(new_lines, wrapped_lines[i])
 		end
 		table.insert(new_lines, wrapped_lines[#wrapped_lines] .. suffix)
 	end
 
 	vim.api.nvim_buf_set_lines(buf, sr - 1, er, false, new_lines)
 
 	-- Cursor between [ and ] in the last line of wrapped text. Wrap always
 	-- ends with `[]`, so placing the cursor at the index of `]` (0-based)
 	-- puts it between `[` and `]`, ready for insert.
 	local last_wrapped = wrapped_lines[#wrapped_lines]
 	local target_row, target_col
 	if #wrapped_lines == 1 then
 		target_row = sr
 		target_col = #prefix + #last_wrapped - 1
 	else
 		target_row = sr + #wrapped_lines - 1
 		target_col = #last_wrapped - 1
 	end
 	vim.api.nvim_win_set_cursor(0, { target_row, target_col })
 	vim.schedule(function() vim.cmd("startinsert") end)
 end
 
 -- Inline term definition (#161 + R1, #166). render_definition is the on_done IO
 -- seam. On a successful lookup it stores the definition as a durable markdown
--- footnote (ONE undo entry — the anchor), highlights the line (whole-line
--- DiffChange, review's scheme), and shows the definition as an ephemeral INFO
+-- footnote (ONE undo entry — the anchor), highlights the selected term/reference
+-- span (DiffChange), and shows the definition as an ephemeral INFO
 -- diagnostic. Undo/redo coherence reuses review's projection watcher: undoing
 -- the footnote edit lands on the pre-edit content-hash → the empty snapshot
 -- renders → both decorations clear.
 -- `span` = the visual selection {sr, sc, er, ec} (1-based getpos values).
 local function render_definition(buf, span, phrase, result)
 	-- Pick the emit_definition call (unforced → the model may answer in text or
 	-- only call web_search; both mean "no definition"). Notify rather than
 	-- silently doing nothing, and leave no footnote edit.
 	local call
 	if result and result.calls then
 		for _, c in ipairs(result.calls) do
 			if c.name == "emit_definition" then
 				call = c
 				break
 			end
 		end
 	end
 	if not call then
 		M.logger.warning("Define: no definition returned")
 		return
 	end
 
 	local sr, sc, er, ec = span[1], span[2], span[3], span[4]
 	local define = require("parley.define")
 	local skill_render = require("parley.skill_render")
 	local projection = require("parley.skills.review.projection")
 
 	-- The buffer may have changed under the in-flight call; skip the whole render
 	-- rather than attach a footnote reference to shifted text.
 	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
 	if define.slice_selection(lines, sr, sc - 1, er, ec - 1) ~= phrase then
 		M.logger.warning("Define: selection changed during lookup — re-select to define")
 		return
 	end
 	local original = table.concat(lines, "\n") -- pre-edit content (undo base)
 
 	-- Store the definition as a markdown footnote in ONE full-buffer set_lines
 	-- edit (single undo entry = the anchor). set_applying suppresses any prior
 	-- define's projection watcher during our own edit (mirrors review).
 	projection.set_applying(buf, true)
 	local input = call.input or {}
 	local e = define.apply_definition_footnote(lines, sr, sc - 1, er, ec - 1, input.term or phrase, input.definition)
 	require("parley.buffer_edit").replace_all_lines_for_definition(buf, e.lines)
 
-	-- Highlight the term's line(s) + the ephemeral definition diagnostic.
-	for line0 = sr - 1, er - 1 do
-		skill_render.highlight_line(buf, line0)
-	end
 	local width = math.max(40, vim.api.nvim_win_get_width(0) - 8)
 	local msg = define.format_definition(input.term or phrase, e.definition, width)
 	local diag_span = e.diagnostic_span
+	skill_render.highlight_span(buf, diag_span.lnum, diag_span.col, diag_span.end_lnum, diag_span.end_col)
 	vim.diagnostic.set(skill_render.diag_namespace(), buf, { {
 		lnum = diag_span.lnum,
 		col = diag_span.col,
 		end_lnum = diag_span.end_lnum,
 		end_col = diag_span.end_col,
 		message = msg,
 		severity = vim.diagnostic.severity.INFO,
 		source = "parley-define",
 	} })
 
 	-- Record projection states so undo/redo of the footnote edit clears/restores
 	-- the decorations (#133 M5 machinery, reused): pre-edit hash → empty
 	-- snapshot, footnoted hash → highlight+diagnostic; attach the watcher.
 	projection.record_empty_for(buf, original)
 	projection.record(buf)
 	projection.ensure_watch(buf)
 	projection.set_applying(buf, false)
 
 	-- Park the cursor on the term's line so diag_display's current-line
 	-- virtual_lines reveals the definition immediately.
 	pcall(vim.api.nvim_win_set_cursor, 0, { sr, math.max(0, sc - 1) })
 	vim.cmd("redraw")
 end
 
 -- define_visual: the thin IO shell for visual-mode <M-CR>. Reads the selection,
 -- computes the enclosing-exchange context, and fires a headless define skill
 -- turn whose on_done stores + renders the definition inline. Pure logic lives
 -- in lua/parley/define.lua. Exposed as M.define_visual for the keybinding.
 function M.define_visual(buf)
 	buf = buf or vim.api.nvim_get_current_buf()
 	local sp = vim.fn.getpos("'<")
 	local ep = vim.fn.getpos("'>")
 	local sr, sc = sp[2], sp[3]
 	local er, ec = ep[2], ep[3]
 	if sr == 0 or er == 0 then return end
 
 	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
 	local define = require("parley.define")
 	-- getpos cols are 1-based; slice_selection takes 0-based (sub(sc, ec)).
 	local phrase = define.slice_selection(lines, sr, sc - 1, er, ec - 1)
 	if phrase:gsub("%s", "") == "" then
 		M.logger.warning("Define: empty selection")
 		return
 	end
 
 	local header_end = M.chat_parser.find_header_end(lines) or 0
 	local parsed = M.parse_chat(lines, header_end)
 	local context = define.context_for_selection(parsed, sr, lines, M.find_exchange_at_line)
 
 	local span = { sr, sc, er, ec }
 	local manifest = require("parley.skills.define")
 	require("parley.skill_invoke").invoke(buf, manifest, { phrase = phrase }, {
 		document = context,
 		no_reload = true,
 		on_done = function(result) render_definition(buf, span, phrase, result) end,
 	})
 end
 
 -- Accept/reject flash animation (#124). The resolver flashes the removed
 -- marker red, then the inserted replacement green, so the user sees what left
 -- and what landed. Persistent extmarks in their own namespace (not the
 -- ephemeral decoration-provider one) so they survive redraws for the flash.
 local drill_in_flash_ns = vim.api.nvim_create_namespace("parley_review_flash")
 -- 500 ms per phase matches ../pair's draft-window flash effects (copy-on-select
 -- paste, shell-output insert), so the two harnesses feel consistent.
 local DRILL_IN_FLASH_DELETE_MS = 500
 local DRILL_IN_FLASH_INSERT_MS = 500
 
 -- Per-buffer pending mutation. The buffer change is deferred behind the red
 -- phase so the removed text is visible before it goes; this holds the closure
 -- that applies it so a second accept/reject during the red window can flush
 -- the first to the buffer before reading fresh text (otherwise the second
 -- resolve computes against stale text and clobbers the first).
 local drill_in_pending = {}
 
 -- Convert a 0-based byte offset into the joined ("\n") buffer text to a
 -- 0-based (row, col) extmark position.
 local function byte_offset_to_rowcol(lines, off)
 	local pos = 0
 	for i, line in ipairs(lines) do
diff --git a/lua/parley/skill_render.lua b/lua/parley/skill_render.lua
index dcf6683..5d283a0 100644
--- a/lua/parley/skill_render.lua
+++ b/lua/parley/skill_render.lua
@@ -85,123 +85,169 @@ local function diag_wrap_width()
     if not ok or type(info) ~= "table" then
         return 76
     end
     return math.max(30, (info.width or 80) - (info.textoff or 0) - 10)
 end
 
 --- Attach INFO diagnostics from edit explanations. Each diagnostic spans the
 --- edit's line range (lnum..end_lnum) so "cursor in the region" matches, and its
 --- message is hard-wrapped to the window's usable width for `virtual_lines`
 --- display (no right-edge truncation). (#133 M6)
 --- @param buf number
 --- @param edits table[]  applied edits with {pos, explain, new_string?}
 --- @param original_content string  file content before edits
 function M.attach_diagnostics(buf, edits, original_content)
     ensure_namespaces()
     local width = diag_wrap_width()
     local diagnostics = {}
     for _, edit in ipairs(edits) do
         local line_num = 0
         for _ in original_content:sub(1, edit.pos):gmatch("\n") do
             line_num = line_num + 1
         end
         -- end_lnum spans the edit's own lines (newlines in the new text); a pure
         -- deletion (no new_string) stays a single-line anchor.
         local span = 0
         for _ in (edit.new_string or ""):gmatch("\n") do
             span = span + 1
         end
         table.insert(diagnostics, {
             lnum = line_num,
             end_lnum = line_num + span,
             col = 0,
             message = M.wrap(edit.explain or "edit applied", width),
             severity = vim.diagnostic.severity.INFO,
             source = "parley-skill",
         })
     end
     vim.diagnostic.set(diag_ns_id, buf, diagnostics)
 end
 
 --- Highlight edited regions with DiffChange.
 --- @param buf number
 --- @param edits table[]  applied edits with {new_string}
 --- @param new_content string  file content after edits
 function M.highlight_edits(buf, edits, new_content)
     ensure_namespaces()
     for _, edit in ipairs(edits) do
         -- Skip pure deletions: new_string is "" and `find("")` returns 1, which
         -- would spuriously highlight line 0. Deletions are oriented by their
         -- INFO gutter diagnostic (the "why") via attach_diagnostics, not a
         -- highlight (there's no new text to mark). #133.
         local new_pos = (edit.new_string and edit.new_string ~= "")
             and new_content:find(edit.new_string, 1, true)
             or nil
         if new_pos then
             local start_line = 0
             for _ in new_content:sub(1, new_pos):gmatch("\n") do
                 start_line = start_line + 1
             end
             local end_line = start_line
             for _ in edit.new_string:gmatch("\n") do
                 end_line = end_line + 1
             end
             for line = start_line, end_line do
                 vim.api.nvim_buf_add_highlight(buf, hl_ns_id, "DiffChange", line, 0, -1)
             end
         end
     end
 end
 
 --- Highlight a whole line with DiffChange on the hl namespace (#161 R1). Same
 --- shape `apply_snapshot` restores (whole-line, col 0..-1), so it round-trips
 --- through projection's line-granular undo/redo snapshotting.
 --- @param buf number
 --- @param lnum0 number  0-based line
 function M.highlight_line(buf, lnum0)
     ensure_namespaces()
     vim.api.nvim_buf_add_highlight(buf, hl_ns_id, "DiffChange", lnum0, 0, -1)
 end
 
---- Capture the current decoration set as line-anchored data (for the undo/redo
---- projection record, #133 M5). Returns { hl_lines = {0-based line…}, diags =
---- {{lnum, message}…} } — enough to redraw at a content-identical state.
+--- Highlight a column span with DiffChange on the hl namespace. The four-arg
+--- form is same-line: (buf, lnum0, col_start, col_end). The five-arg form spans
+--- rows: (buf, lnum0, col_start, end_lnum0, col_end).
+--- @param buf number
+--- @param lnum0 number 0-based start line
+--- @param col_start number 0-based start column
+--- @param end_lnum0_or_col_end number 0-based end line, or end column
+--- @param col_end number|nil 0-based exclusive end column
+function M.highlight_span(buf, lnum0, col_start, end_lnum0_or_col_end, col_end)
+    ensure_namespaces()
+    local end_lnum0 = lnum0
+    if col_end == nil then
+        col_end = end_lnum0_or_col_end
+    else
+        end_lnum0 = end_lnum0_or_col_end
+    end
+    vim.api.nvim_buf_set_extmark(buf, hl_ns_id, lnum0, col_start, {
+        end_row = end_lnum0,
+        end_col = col_end,
+        hl_group = "DiffChange",
+        strict = false,
+    })
+end
+
+--- Capture the current decoration set as redrawable data (for the undo/redo
+--- projection record, #133 M5). Whole-line highlights stay in `hl_lines`; span
+--- highlights and diagnostics preserve columns so exact anchors can be restored.
 function M.snapshot(buf)
     ensure_namespaces()
     local hl_lines = {}
-    for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf, hl_ns_id, 0, -1, {})) do
-        table.insert(hl_lines, m[2]) -- m = {id, row, col}; row is the 0-based line
+    local hl_spans = {}
+    for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf, hl_ns_id, 0, -1, { details = true })) do
+        local details = m[4] or {}
+        local is_legacy_line = m[3] == 0 and details.end_row == m[2] + 1 and details.end_col == 0
+        if is_legacy_line or details.end_row == nil or details.end_col == nil then
+            table.insert(hl_lines, m[2]) -- m = {id, row, col}; row is the 0-based line
+        else
+            table.insert(hl_spans, {
+                lnum = m[2],
+                col = m[3],
+                end_lnum = details.end_row,
+                end_col = details.end_col,
+            })
+        end
     end
     local diags = {}
     for _, d in ipairs(vim.diagnostic.get(buf, { namespace = diag_ns_id })) do
-        table.insert(diags, { lnum = d.lnum, end_lnum = d.end_lnum, message = d.message })
+        table.insert(diags, {
+            lnum = d.lnum,
+            col = d.col or 0,
+            end_lnum = d.end_lnum,
+            end_col = d.end_col,
+            message = d.message,
+        })
     end
-    return { hl_lines = hl_lines, diags = diags }
+    return { hl_lines = hl_lines, hl_spans = hl_spans, diags = diags }
 end
 
 --- Redraw a snapshot's decorations (clearing first). Only valid when the buffer
 --- content matches the state the snapshot was captured at (the projection caller
 --- guarantees this via a content-hash match). #133 M5.
 function M.apply_snapshot(buf, snap)
     ensure_namespaces()
     M.clear_decorations(buf)
     snap = snap or {}
     for _, line in ipairs(snap.hl_lines or {}) do
         vim.api.nvim_buf_add_highlight(buf, hl_ns_id, "DiffChange", line, 0, -1)
     end
+    for _, span in ipairs(snap.hl_spans or {}) do
+        M.highlight_span(buf, span.lnum, span.col or 0, span.end_lnum or span.lnum, span.end_col)
+    end
     if snap.diags and #snap.diags > 0 then
         local diagnostics = {}
         for _, d in ipairs(snap.diags) do
             table.insert(diagnostics, {
                 lnum = d.lnum,
                 end_lnum = d.end_lnum or d.lnum,
-                col = 0,
+                col = d.col or 0,
+                end_col = d.end_col,
                 message = d.message,
                 severity = vim.diagnostic.severity.INFO,
                 source = "parley-skill",
             })
         end
         vim.diagnostic.set(diag_ns_id, buf, diagnostics)
     end
 end
 
 return M
diff --git a/tests/integration/define_spec.lua b/tests/integration/define_spec.lua
index 36f7063..05e5af1 100644
--- a/tests/integration/define_spec.lua
+++ b/tests/integration/define_spec.lua
@@ -160,249 +160,266 @@ end)
 
 describe("define: web-toggle payload (#161)", function()
     local parley = require("parley")
     local dispatcher = require("parley.dispatcher")
 
     before_each(function()
         require("parley.tools").register_builtins()
         parley._state = parley._state or {}
     end)
 
     local function tool_names(payload)
         local n = {}
         for _, t in ipairs(payload.tools or {}) do n[t.name] = true end
         return n
     end
 
     it("includes web_search in the anthropic payload iff the global toggle is on", function()
         local saved = parley._state.web_search
         local MODEL = { model = "claude-sonnet-4-5" }
         local msgs = { { role = "user", content = "x" } }
 
         parley._state.web_search = true
         local on = dispatcher.prepare_payload(msgs, MODEL, "anthropic", { "emit_definition" })
         assert.is_true(tool_names(on).web_search == true)
 
         parley._state.web_search = false
         local off = dispatcher.prepare_payload(msgs, MODEL, "anthropic", { "emit_definition" })
         assert.is_nil(tool_names(off).web_search)
 
         parley._state.web_search = saved
     end)
 end)
 
 describe("define_visual + render_definition (#161)", function()
     local parley = require("parley")
     local tasker = require("parley.tasker")
     local assembly = require("parley.skill_assembly")
     local ns = require("parley.skill_render").diag_namespace()
 
     local tmpdir, path, buf, orig_query, orig_resolve, query_called
 
     before_each(function()
         require("parley.tools").register_builtins()
         tmpdir = vim.fn.tempname() .. "-dv"
         vim.fn.mkdir(tmpdir, "p")
         path = tmpdir .. "/chat.md"
         vim.fn.writefile({ "line one", "line two", "here is ASIN in context", "line four", "       " }, path)
         vim.cmd("edit " .. vim.fn.fnameescape(path))
         buf = vim.api.nvim_get_current_buf()
         query_called = false
 
         orig_resolve = assembly.resolve_agent
         assembly.resolve_agent = function()
             return { model = "m", provider = "anthropic" }
         end
         orig_query = parley.dispatcher.query
         parley.dispatcher.query = function(_b, _p, _payload, _h, on_exit)
             query_called = true
             tasker.set_query("qid_dv", {
                 raw_response = emit_definition_sse("ASIN", "Amazon Standard Identification Number."),
             })
             vim.schedule(function() on_exit("qid_dv") end)
         end
         vim.diagnostic.reset(ns, buf)
     end)
 
     after_each(function()
         parley.dispatcher.query = orig_query
         assembly.resolve_agent = orig_resolve
         pcall(function() require("parley.progress").stop() end)
         vim.fn.delete(tmpdir, "rf")
     end)
 
     local hl_ns = vim.api.nvim_create_namespace("parley_skill_hl")
     local function hl_on_line(b, line0)
         for _, m in ipairs(vim.api.nvim_buf_get_extmarks(b, hl_ns, 0, -1, {})) do
             if m[2] == line0 then return true end
         end
         return false
     end
+    local function first_hl_mark(b)
+        return vim.api.nvim_buf_get_extmarks(b, hl_ns, 0, -1, { details = true })[1]
+    end
 
-    it("stores the definition as a durable footnote, highlights the line, and shows the diagnostic", function()
+    it("stores the definition as a durable footnote, highlights the term/reference span, and shows the diagnostic", function()
         -- select "ASIN" on line 3 (cols 9..12, 1-based)
         vim.fn.setpos("'<", { buf, 3, 9, 0 })
         vim.fn.setpos("'>", { buf, 3, 12, 0 })
         require("parley").define_visual(buf)
         vim.wait(2000, function()
             return #vim.diagnostic.get(buf, { namespace = ns }) > 0
         end)
         -- Footnote reference written into the line (the undo anchor)
         assert.are.equal("here is ASIN[^asin] in context",
             vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1])
         assert.are.same({
             "---",
             "",
             "[^asin]: Amazon Standard Identification Number.",
         }, vim.api.nvim_buf_get_lines(buf, 5, 8, false))
         -- diagnostic on the term's line
         local diags = vim.diagnostic.get(buf, { namespace = ns })
         assert.are.equal(2, diags[1].lnum) -- 0-based line 3
         assert.are.equal(8, diags[1].col)
         assert.are.equal(2, diags[1].end_lnum)
         assert.are.equal(19, diags[1].end_col) -- ASIN plus [^asin]
         assert.is_true(diags[1].message:find("ASIN", 1, true) ~= nil)
-        -- whole-line DiffChange highlight on the hl namespace, on line 3
-        assert.is_true(hl_on_line(buf, 2), "term line not highlighted")
+        -- DiffChange highlight covers only ASIN[^asin], not the whole paragraph.
+        local mark = first_hl_mark(buf)
+        assert.is_not_nil(mark, "term/reference span not highlighted")
+        assert.are.equal(2, mark[2])
+        assert.are.equal(8, mark[3])
+        assert.are.equal(2, mark[4].end_row)
+        assert.are.equal(19, mark[4].end_col)
     end)
 
     it("re-defining a footnoted term updates the footer without duplicating the inline reference", function()
         vim.fn.setpos("'<", { buf, 3, 9, 0 })
         vim.fn.setpos("'>", { buf, 3, 12, 0 })
         require("parley").define_visual(buf)
         vim.wait(2000, function()
             return vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1] == "here is ASIN[^asin] in context"
         end)
 
         parley.dispatcher.query = function(_b, _p, _payload, _h, on_exit)
             tasker.set_query("qid_dv_updated", {
                 raw_response = emit_definition_sse("ASIN", "Updated definition."),
             })
             vim.schedule(function() on_exit("qid_dv_updated") end)
         end
 
         vim.fn.setpos("'<", { buf, 3, 9, 0 })
         vim.fn.setpos("'>", { buf, 3, 12, 0 })
         require("parley").define_visual(buf)
         vim.wait(2000, function()
             local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
             return table.concat(lines, "\n"):find("%[%^asin%]: Updated definition%.") ~= nil
         end)
 
         assert.are.equal("here is ASIN[^asin] in context",
             vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1])
         assert.are.same({
             "---",
             "",
             "[^asin]: Updated definition.",
         }, vim.api.nvim_buf_get_lines(buf, 5, 8, false))
     end)
 
     it("u undoes the footnote edit + clears decorations; C-r restores them (R1)", function()
         vim.fn.setpos("'<", { buf, 3, 9, 0 })
         vim.fn.setpos("'>", { buf, 3, 12, 0 })
         require("parley").define_visual(buf)
         vim.wait(2000, function()
             return #vim.diagnostic.get(buf, { namespace = ns }) > 0
         end)
         assert.are.equal("here is ASIN[^asin] in context",
             vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1])
 
         -- undo: the footnote edit reverts; the projection watcher (TextChanged) clears
         -- both decorations. Fire the autocmd Vim fires interactively — headless
         -- :undo doesn't trigger TextChanged on its own (the watcher itself is
         -- covered by projection's own specs; here we verify define's records).
         vim.cmd("silent undo")
         vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
         assert.are.equal("here is ASIN in context",
             vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1])
         assert.is_nil(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
             :find("%[%^asin%]:", 1, false), "footnote not removed on undo")
         assert.are.equal(0, #vim.diagnostic.get(buf, { namespace = ns }),
             "diagnostic not cleared on undo")
         assert.is_false(hl_on_line(buf, 2), "highlight not cleared on undo")
 
         -- redo: footnote edit + decorations return
         vim.cmd("silent redo")
         vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
         assert.are.equal("here is ASIN[^asin] in context",
             vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1])
+        local redone_mark = first_hl_mark(buf)
+        assert.is_not_nil(redone_mark, "highlight not restored on redo")
+        assert.are.equal(2, redone_mark[2])
+        assert.are.equal(8, redone_mark[3])
+        assert.are.equal(2, redone_mark[4].end_row)
+        assert.are.equal(19, redone_mark[4].end_col)
+        local redone_diags = vim.diagnostic.get(buf, { namespace = ns })
+        assert.are.equal(8, redone_diags[1].col)
+        assert.are.equal(19, redone_diags[1].end_col)
         assert.is_true(#vim.diagnostic.get(buf, { namespace = ns }) >= 1,
             "diagnostic not restored on redo")
         assert.is_true(hl_on_line(buf, 2), "highlight not restored on redo")
     end)
 
     it("no-ops on a whitespace-only selection (no query, no diagnostic)", function()
         -- line 5 is all spaces; selecting it yields a whitespace-only phrase.
         vim.fn.setpos("'<", { buf, 5, 1, 0 })
         vim.fn.setpos("'>", { buf, 5, 5, 0 })
         require("parley").define_visual(buf)
         vim.wait(200)
         assert.is_false(query_called, "empty selection must not query")
         assert.are.equal(0, #vim.diagnostic.get(buf, { namespace = ns }))
     end)
 
     it("no-ops on a no-tool-call response", function()
         parley.dispatcher.query = function(_b, _p, _payload, _h, on_exit)
             query_called = true
             tasker.set_query("qid_none", {
                 raw_response = "event: message_stop\ndata: {\"type\":\"message_stop\"}\n",
             })
             vim.schedule(function() on_exit("qid_none") end)
         end
         vim.fn.setpos("'<", { buf, 3, 9, 0 })
         vim.fn.setpos("'>", { buf, 3, 12, 0 })
         require("parley").define_visual(buf)
         vim.wait(1000, function() return false end) -- let on_done run
         assert.is_true(query_called)
         assert.are.equal(0, #vim.diagnostic.get(buf, { namespace = ns }),
             "a no-tool response must not set a diagnostic")
         assert.are.equal("here is ASIN in context",
             vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1],
             "a no-tool response must not footnote the term")
     end)
 end)
 
 describe("define keybinding split (#161)", function()
     local kb = require("parley.keybinding_registry")
     local parley = require("parley")
 
     it("routes visual <M-CR> to define, keeps visual <C-g><C-g> as respond, n/i respond", function()
         local buf = vim.api.nvim_create_buf(false, true)
         local who
         -- Mirror the production chat_define callback: n/i = respond, v/x = define.
         local callbacks = {
             chat_respond = {
                 n = function() who = "respond" end,
                 i = function() who = "respond" end,
                 v = function() who = "respond" end,
                 x = function() who = "respond" end,
             },
             chat_define = {
                 n = function() who = "respond" end,
                 i = function() who = "respond" end,
                 v = function() who = "define" end,
                 x = function() who = "define" end,
             },
         }
 
         local records = {}
         local function set_keymap(_scopes, mode, key, cb, _desc)
             records[#records + 1] = { mode = mode, key = key, cb = cb }
         end
         kb.register_buffer({ "chat" }, buf, parley.config, callbacks, set_keymap)
 
         local function invoke(mode, key)
             for _, r in ipairs(records) do
                 if r.mode == mode and r.key == key then
                     who = nil
                     r.cb()
                     return who
                 end
             end
             return "<unbound>"
         end
 
         -- visual <M-CR> → define; visual <C-g><C-g> → respond (resubmit preserved)
         assert.are.equal("define", invoke("x", "<M-CR>"))
         assert.are.equal("respond", invoke("x", "<C-g><C-g>"))
         -- normal/insert <M-CR> → respond (unchanged)
diff --git a/tests/unit/skill_render_spec.lua b/tests/unit/skill_render_spec.lua
index bb900c5..a0057b6 100644
--- a/tests/unit/skill_render_spec.lua
+++ b/tests/unit/skill_render_spec.lua
@@ -27,88 +27,121 @@ describe("skill_render", function()
         local buf = scratch({ "x" })
         skill_render.attach_diagnostics(buf, { { pos = 1, explain = "e" } }, "x")
         assert.is_true(#vim.diagnostic.get(buf) > 0)
         skill_render.clear_decorations(buf)
         assert.are.equal(0, #vim.diagnostic.get(buf))
     end)
 
     it("highlight_edits runs without error on edited regions", function()
         local buf = scratch({ "alpha", "BETA", "gamma" })
         -- should not raise; highlights the line containing new_string
         skill_render.highlight_edits(buf, { { new_string = "BETA" } }, "alpha\nBETA\ngamma")
     end)
 
     it("a non-empty edit produces highlight extmarks", function()
         local buf = scratch({ "alpha", "BETA", "gamma" })
         skill_render.highlight_edits(buf, { { new_string = "BETA" } }, "alpha\nBETA\ngamma")
         local hl_ns = vim.api.nvim_create_namespace("parley_skill_hl")
         local marks = vim.api.nvim_buf_get_extmarks(buf, hl_ns, 0, -1, {})
         assert.is_true(#marks > 0)
     end)
 
     it("a deletion (empty new_string) gets a gutter diagnostic but no highlight", function()
         local buf = scratch({ "keep this", "delete me", "keep this too" })
         local original = "keep this\ndelete me\nkeep this too"
         local new_content = "keep this\nkeep this too"
         local pos = original:find("delete me", 1, true)
         local edits = { { pos = pos, explain = "removed redundant line", new_string = "" } }
         skill_render.attach_diagnostics(buf, edits, original)
         skill_render.highlight_edits(buf, edits, new_content)
         -- gutter "why" is present (deletion orientation)
         local diags = vim.diagnostic.get(buf)
         assert.are.equal(1, #diags)
         assert.matches("removed redundant line", diags[1].message)
         -- no highlight: empty new_string is skipped (would've spuriously hit line 0)
         local hl_ns = vim.api.nvim_create_namespace("parley_skill_hl")
         local marks = vim.api.nvim_buf_get_extmarks(buf, hl_ns, 0, -1, {})
         assert.are.equal(0, #marks)
     end)
 
     it("wrap hard-wraps at word boundaries to the given width", function()
         local w = skill_render.wrap("the quick brown fox jumps over the lazy dog", 12)
         assert.is_truthy(w:find("\n"), "wrapped into multiple lines")
         for line in (w .. "\n"):gmatch("(.-)\n") do
             assert.is_true(#line <= 12 or not line:find(" ", 1, true), "within width or single long word: " .. line)
         end
     end)
 
     it("attach_diagnostics wraps the message + spans the edit's lines (end_lnum)", function()
         local buf = scratch({ "a", "b", "c", "d" })
         local original = "a\nb\nc\nd"
         local pos = original:find("b")
         skill_render.attach_diagnostics(buf, {
             { pos = pos, explain = string.rep("word ", 30), new_string = "x\ny" },
         }, original)
         local d = vim.diagnostic.get(buf)[1]
         assert.are.equal(1, d.lnum) -- 0-based line of "b"
         assert.are.equal(2, d.end_lnum) -- spans the 2-line new_string
         assert.is_truthy(d.message:find("\n"), "long message is wrapped")
     end)
 
     it("snapshot captures highlights + diagnostics; apply_snapshot restores them", function()
         local buf = scratch({ "line one", "line two", "line three" })
         local content = "line one\nline two\nline three"
         skill_render.highlight_edits(buf, { { new_string = "line two" } }, content)
         skill_render.attach_diagnostics(buf, { { pos = content:find("two"), explain = "why two" } }, content)
         local snap = skill_render.snapshot(buf)
         assert.is_true(#snap.hl_lines >= 1)
         assert.is_true(#snap.diags >= 1)
         -- clear → empty, then restore from the snapshot
         skill_render.clear_decorations(buf)
         assert.are.equal(0, #vim.diagnostic.get(buf))
         skill_render.apply_snapshot(buf, snap)
         local diags = vim.diagnostic.get(buf)
         assert.is_true(#diags >= 1)
         assert.matches("why two", diags[1].message)
         assert.is_not_nil(diags[1].end_lnum, "end_lnum survives snapshot→apply (#133 M6)")
         local hl_ns = vim.api.nvim_create_namespace("parley_skill_hl")
         assert.is_true(#vim.api.nvim_buf_get_extmarks(buf, hl_ns, 0, -1, {}) >= 1)
     end)
 
+    it("snapshot captures and restores highlight and diagnostic column spans", function()
+        local buf = scratch({ "here is ASIN[^asin] in context" })
+        local hl_ns = vim.api.nvim_create_namespace("parley_skill_hl")
+        local diag_ns = skill_render.diag_namespace()
+
+        skill_render.highlight_span(buf, 0, 8, 19)
+        vim.diagnostic.set(diag_ns, buf, { {
+            lnum = 0,
+            col = 8,
+            end_lnum = 0,
+            end_col = 19,
+            message = "why",
+            severity = vim.diagnostic.severity.INFO,
+            source = "test",
+        } })
+
+        local snap = skill_render.snapshot(buf)
+        skill_render.clear_decorations(buf)
+        skill_render.apply_snapshot(buf, snap)
+
+        local marks = vim.api.nvim_buf_get_extmarks(buf, hl_ns, 0, -1, { details = true })
+        assert.are.equal(1, #marks)
+        assert.are.equal(0, marks[1][2])
+        assert.are.equal(8, marks[1][3])
+        assert.are.equal(0, marks[1][4].end_row)
+        assert.are.equal(19, marks[1][4].end_col)
+
+        local diags = vim.diagnostic.get(buf, { namespace = diag_ns })
+        assert.are.equal(1, #diags)
+        assert.are.equal(8, diags[1].col)
+        assert.are.equal(19, diags[1].end_col)
+    end)
+
     it("dismiss clears decorations (alias of clear_decorations)", function()
         local buf = scratch({ "x" })
         skill_render.attach_diagnostics(buf, { { pos = 1, explain = "e" } }, "x")
         assert.is_true(#vim.diagnostic.get(buf) > 0)
         skill_render.dismiss(buf)
         assert.are.equal(0, #vim.diagnostic.get(buf))
     end)
 end)

exec
/bin/zsh -lc 'git diff --stat 5640bcaa934b0b5bc4c6c2d18b042996afd74f83...HEAD && git diff --check 5640bcaa934b0b5bc4c6c2d18b042996afd74f83...HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
 lua/parley/init.lua                                |   9 +-
 lua/parley/skill_render.lua                        |  62 ++++++++++--
 tests/integration/define_spec.lua                  |  23 ++++-
 tests/unit/skill_render_spec.lua                   |  33 +++++++
 .../000167-define-diagnostic-highlight-span.md     |  67 ++++++++++++-
 ...000167-define-diagnostic-highlight-span-plan.md | 105 +++++++++++++++++++++
 6 files changed, 279 insertions(+), 20 deletions(-)

codex
The stale atlas text is specific, not just missing: it says define must use whole-line highlights because snapshots are line-granular, which this issue intentionally changes. I’m running focused verification now to make sure there isn’t a behavioral failure hiding behind the documentation gap.
exec
/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/unit/skill_render_spec.lua"' in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"' in /Users/xianxu/workspace/parley.nvim
 succeeded in 1548ms:
Error detected while processing /Users/xianxu/.config/nvim/init.lua:
Parser dir ' /Users/xianxu/.local/share/nvim/lazy/nvim-treesitter/parser ' should be read/write (see README on how to configure an alternative install location) /Users/xianxu/.local/share/nvim/lazy/nvim-treesitter/parser '
LuaSnip: could not open log at /Users/xianxu/.local/state/nvim/luasnip.log. Not logging for this session.
Parley.nvim: Failed to open file for writing: /Users/xianxu/.local/share/nvim/parley/persisted/state.jsonScheduling: tests/unit/skill_render_spec.lua

========================================	
Testing: 	/Users/xianxu/workspace/parley.nvim/tests/unit/skill_render_spec.lua	
[32mSuccess[0m	||	skill_render attach_diagnostics sets an INFO diagnostic per edit, on the edit's line	
[32mSuccess[0m	||	skill_render clear_decorations removes the diagnostics	
[32mSuccess[0m	||	skill_render highlight_edits runs without error on edited regions	
[32mSuccess[0m	||	skill_render a non-empty edit produces highlight extmarks	
[32mSuccess[0m	||	skill_render a deletion (empty new_string) gets a gutter diagnostic but no highlight	
[32mSuccess[0m	||	skill_render wrap hard-wraps at word boundaries to the given width	
[32mSuccess[0m	||	skill_render attach_diagnostics wraps the message + spans the edit's lines (end_lnum)	
[32mSuccess[0m	||	skill_render snapshot captures highlights + diagnostics; apply_snapshot restores them	
[32mSuccess[0m	||	skill_render snapshot captures and restores highlight and diagnostic column spans	
[32mSuccess[0m	||	skill_render dismiss clears decorations (alias of clear_decorations)	
	
[32mSuccess: [0m	10	
[31mFailed : [0m	0	
[31mErrors : [0m	0	
========================================	
]111
 exited 1 in 1514ms:
LuaSnip: could not open log at /Users/xianxu/.local/state/nvim/luasnip.log. Not logging for this session.
Error detected while processing /Users/xianxu/.config/nvim/init.lua:
Parser dir ' /Users/xianxu/.local/share/nvim/lazy/nvim-treesitter/parser ' should be read/write (see README on how to configure an alternative install location) /Users/xianxu/.local/share/nvim/lazy/nvim-treesitter/parser '
Parley.nvim: Failed to open file for writing: /Users/xianxu/.local/share/nvim/parley/persisted/state.jsonScheduling: tests/integration/define_spec.lua

========================================	
Testing: 	/Users/xianxu/workspace/parley.nvim/tests/integration/define_spec.lua	
[32mSuccess[0m	||	emit_definition tool is registered and selectable without raising	
[32mSuccess[0m	||	emit_definition tool does not advertise pager offset/limit params	
[32mSuccess[0m	||	define skill is auto-discovered by the registry	
[32mSuccess[0m	||	define skill folds the phrase into the system prompt and forces no tool	
[32mSuccess[0m	||	define: web-toggle payload (#161) includes web_search in the anthropic payload iff the global toggle is on	
[32mSuccess[0m	||	define keybinding split (#161) routes visual <M-CR> to define, keeps visual <C-g><C-g> as respond, n/i respond	
[31mFail[0m	||	define keybinding split (#161) real prep_chat wiring: <M-CR>/<C-g><C-g> buffer-mapped in visual mode	
            vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for "/private/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/8POccI/0-define-chat/2026-03-01-kbwire.md", recovery impossible
            
            stack traceback:
            	vim/_editor.lua: in function 'cmd'
            	.../workspace/parley.nvim/tests/integration/define_spec.lua:446: in function <.../workspace/parley.nvim/tests/integration/define_spec.lua:438>
            	
[32mSuccess[0m	||	define: context_for_selection vs real parse_chat (#161) slices the enclosing exchange from real parse_chat output (field contract)	
	
[32mSuccess: [0m	7	
[31mFailed : [0m	1	
[31mErrors : [0m	2	
========================================	
We had an unexpected error: 	{ {
    descriptions = { "define: skill_invoke read-only seams (#161)" },
    msg = "vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for \"/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/8POccI/1-def/chat.md\", recovery impossible\n\nstack traceback:\n\tvim/_editor.lua: in function 'cmd'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:91: in function 'w'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:167: in function 'run_each'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:174: in function 'it'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:124: in function <.../workspace/parley.nvim/tests/integration/define_spec.lua:77>\n"
  }, {
    descriptions = { "define_visual + render_definition (#161)" },
    msg = "vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for \"/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/8POccI/2-dv/chat.md\", recovery impossible\n\nstack traceback:\n\tvim/_editor.lua: in function 'cmd'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:207: in function 'w'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:167: in function 'run_each'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:174: in function 'it'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:244: in function <.../workspace/parley.nvim/tests/integration/define_spec.lua:193>\n"
  } }	{
  errs = { {
      descriptions = { "define: skill_invoke read-only seams (#161)" },
      msg = "vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for \"/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/8POccI/1-def/chat.md\", recovery impossible\n\nstack traceback:\n\tvim/_editor.lua: in function 'cmd'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:91: in function 'w'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:167: in function 'run_each'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:174: in function 'it'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:124: in function <.../workspace/parley.nvim/tests/integration/define_spec.lua:77>\n"
    }, {
      descriptions = { "define_visual + render_definition (#161)" },
      msg = "vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for \"/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/8POccI/2-dv/chat.md\", recovery impossible\n\nstack traceback:\n\tvim/_editor.lua: in function 'cmd'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:207: in function 'w'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:167: in function 'run_each'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:174: in function 'it'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:244: in function <.../workspace/parley.nvim/tests/integration/define_spec.lua:193>\n"
    } },
  fail = { {
      descriptions = { "define keybinding split (#161)", "real prep_chat wiring: <M-CR>/<C-g><C-g> buffer-mapped in visual mode" },
      msg = "vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for \"/private/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/8POccI/0-define-chat/2026-03-01-kbwire.md\", recovery impossible\n\nstack traceback:\n\tvim/_editor.lua: in function 'cmd'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:446: in function <.../workspace/parley.nvim/tests/integration/define_spec.lua:438>\n"
    } },
  pass = { {
      descriptions = { "emit_definition tool", "is registered and selectable without raising" }
    }, {
      descriptions = { "emit_definition tool", "does not advertise pager offset/limit params" }
    }, {
      descriptions = { "define skill", "is auto-discovered by the registry" }
    }, {
      descriptions = { "define skill", "folds the phrase into the system prompt and forces no tool" }
    }, {
      descriptions = { "define: web-toggle payload (#161)", "includes web_search in the anthropic payload iff the global toggle is on" }
    }, {
      descriptions = { "define keybinding split (#161)", "routes visual <M-CR> to define, keeps visual <C-g><C-g> as respond, n/i respond" }
    }, {
      descriptions = { "define: context_for_selection vs real parse_chat (#161)", "slices the enclosing exchange from real parse_chat output (field contract)" }
    } }
}	
Parley.nvim: Failed to open file for writing: /Users/xianxu/.local/share/nvim/parley/persisted/state.jsonParley.nvim: Failed to open file for writing: /Users/xianxu/.local/share/nvim/parley/persisted/state.json
]111
codex
The unit spec passed. The integration run failed before the changed assertions because I ran two headless Neovim processes in parallel and they collided on swap files in the test temp tree; I’m rerunning the integration spec alone with swap disabled to separate environment noise from the review result.
exec
/bin/zsh -lc 'nvim -n --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"' in /Users/xianxu/workspace/parley.nvim
 exited 1 in 1495ms:

Error detected while processing /Users/xianxu/.config/nvim/init.lua:
Parser dir ' /Users/xianxu/.local/share/nvim/lazy/nvim-treesitter/parser ' should be read/write (see README on how to configure an alternative install location) /Users/xianxu/.local/share/nvim/lazy/nvim-treesitter/parser '
Parley.nvim: Failed to open file for writing: /Users/xianxu/.local/share/nvim/parley/persisted/state.jsonScheduling: tests/integration/define_spec.lua

========================================	
Testing: 	/Users/xianxu/workspace/parley.nvim/tests/integration/define_spec.lua	
[32mSuccess[0m	||	emit_definition tool is registered and selectable without raising	
[32mSuccess[0m	||	emit_definition tool does not advertise pager offset/limit params	
[32mSuccess[0m	||	define skill is auto-discovered by the registry	
[32mSuccess[0m	||	define skill folds the phrase into the system prompt and forces no tool	
[32mSuccess[0m	||	define: web-toggle payload (#161) includes web_search in the anthropic payload iff the global toggle is on	
[32mSuccess[0m	||	define keybinding split (#161) routes visual <M-CR> to define, keeps visual <C-g><C-g> as respond, n/i respond	
[31mFail[0m	||	define keybinding split (#161) real prep_chat wiring: <M-CR>/<C-g><C-g> buffer-mapped in visual mode	
            vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for "/private/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/dfm6Zh/0-define-chat/2026-03-01-kbwire.md", recovery impossible
            
            stack traceback:
            	vim/_editor.lua: in function 'cmd'
            	.../workspace/parley.nvim/tests/integration/define_spec.lua:446: in function <.../workspace/parley.nvim/tests/integration/define_spec.lua:438>
            	
[32mSuccess[0m	||	define: context_for_selection vs real parse_chat (#161) slices the enclosing exchange from real parse_chat output (field contract)	
	
[32mSuccess: [0m	7	
[31mFailed : [0m	1	
[31mErrors : [0m	2	
========================================	
We had an unexpected error: 	{ {
    descriptions = { "define: skill_invoke read-only seams (#161)" },
    msg = "vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for \"/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/dfm6Zh/1-def/chat.md\", recovery impossible\n\nstack traceback:\n\tvim/_editor.lua: in function 'cmd'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:91: in function 'w'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:167: in function 'run_each'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:174: in function 'it'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:124: in function <.../workspace/parley.nvim/tests/integration/define_spec.lua:77>\n"
  }, {
    descriptions = { "define_visual + render_definition (#161)" },
    msg = "vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for \"/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/dfm6Zh/2-dv/chat.md\", recovery impossible\n\nstack traceback:\n\tvim/_editor.lua: in function 'cmd'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:207: in function 'w'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:167: in function 'run_each'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:174: in function 'it'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:244: in function <.../workspace/parley.nvim/tests/integration/define_spec.lua:193>\n"
  } }	{
  errs = { {
      descriptions = { "define: skill_invoke read-only seams (#161)" },
      msg = "vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for \"/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/dfm6Zh/1-def/chat.md\", recovery impossible\n\nstack traceback:\n\tvim/_editor.lua: in function 'cmd'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:91: in function 'w'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:167: in function 'run_each'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:174: in function 'it'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:124: in function <.../workspace/parley.nvim/tests/integration/define_spec.lua:77>\n"
    }, {
      descriptions = { "define_visual + render_definition (#161)" },
      msg = "vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for \"/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/dfm6Zh/2-dv/chat.md\", recovery impossible\n\nstack traceback:\n\tvim/_editor.lua: in function 'cmd'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:207: in function 'w'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:167: in function 'run_each'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:174: in function 'it'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:244: in function <.../workspace/parley.nvim/tests/integration/define_spec.lua:193>\n"
    } },
  fail = { {
      descriptions = { "define keybinding split (#161)", "real prep_chat wiring: <M-CR>/<C-g><C-g> buffer-mapped in visual mode" },
      msg = "vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for \"/private/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/dfm6Zh/0-define-chat/2026-03-01-kbwire.md\", recovery impossible\n\nstack traceback:\n\tvim/_editor.lua: in function 'cmd'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:446: in function <.../workspace/parley.nvim/tests/integration/define_spec.lua:438>\n"
    } },
  pass = { {
      descriptions = { "emit_definition tool", "is registered and selectable without raising" }
    }, {
      descriptions = { "emit_definition tool", "does not advertise pager offset/limit params" }
    }, {
      descriptions = { "define skill", "is auto-discovered by the registry" }
    }, {
      descriptions = { "define skill", "folds the phrase into the system prompt and forces no tool" }
    }, {
      descriptions = { "define: web-toggle payload (#161)", "includes web_search in the anthropic payload iff the global toggle is on" }
    }, {
      descriptions = { "define keybinding split (#161)", "routes visual <M-CR> to define, keeps visual <C-g><C-g> as respond, n/i respond" }
    }, {
      descriptions = { "define: context_for_selection vs real parse_chat (#161)", "slices the enclosing exchange from real parse_chat output (field contract)" }
    } }
}	
Parley.nvim: Failed to open file for writing: /Users/xianxu/.local/share/nvim/parley/persisted/state.jsonParley.nvim: Failed to open file for writing: /Users/xianxu/.local/share/nvim/parley/persisted/state.json
]111
codex
The swap-file error is still coming from the local Neovim environment, not from the span assertions. I’m not going to treat that as a product finding, but I’ll include it as verification caveat unless a cleaner command succeeds.
exec
/bin/zsh -lc 'nvim --headless -i NONE --cmd "set directory=/tmp//" --cmd "set updatecount=0" -c "PlenaryBustedFile tests/integration/define_spec.lua"' in /Users/xianxu/workspace/parley.nvim
 exited 1 in 1511ms:

Parley.nvim: Failed to open file for writing: /Users/xianxu/.local/share/nvim/parley/persisted/state.jsonScheduling: tests/integration/define_spec.lua

========================================	
Testing: 	/Users/xianxu/workspace/parley.nvim/tests/integration/define_spec.lua	
[32mSuccess[0m	||	emit_definition tool is registered and selectable without raising	
[32mSuccess[0m	||	emit_definition tool does not advertise pager offset/limit params	
[32mSuccess[0m	||	define skill is auto-discovered by the registry	
[32mSuccess[0m	||	define skill folds the phrase into the system prompt and forces no tool	
[32mSuccess[0m	||	define: web-toggle payload (#161) includes web_search in the anthropic payload iff the global toggle is on	
[32mSuccess[0m	||	define keybinding split (#161) routes visual <M-CR> to define, keeps visual <C-g><C-g> as respond, n/i respond	
[31mFail[0m	||	define keybinding split (#161) real prep_chat wiring: <M-CR>/<C-g><C-g> buffer-mapped in visual mode	
            vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for "/private/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/4wnlzS/0-define-chat/2026-03-01-kbwire.md", recovery impossible
            
            stack traceback:
            	vim/_editor.lua: in function 'cmd'
            	.../workspace/parley.nvim/tests/integration/define_spec.lua:446: in function <.../workspace/parley.nvim/tests/integration/define_spec.lua:438>
            	
[32mSuccess[0m	||	define: context_for_selection vs real parse_chat (#161) slices the enclosing exchange from real parse_chat output (field contract)	
	
[32mSuccess: [0m	7	
[31mFailed : [0m	1	
[31mErrors : [0m	2	
========================================	
We had an unexpected error: 	{ {
    descriptions = { "define: skill_invoke read-only seams (#161)" },
    msg = "vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for \"/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/4wnlzS/1-def/chat.md\", recovery impossible\n\nstack traceback:\n\tvim/_editor.lua: in function 'cmd'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:91: in function 'w'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:167: in function 'run_each'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:174: in function 'it'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:124: in function <.../workspace/parley.nvim/tests/integration/define_spec.lua:77>\n"
  }, {
    descriptions = { "define_visual + render_definition (#161)" },
    msg = "vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for \"/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/4wnlzS/2-dv/chat.md\", recovery impossible\n\nstack traceback:\n\tvim/_editor.lua: in function 'cmd'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:207: in function 'w'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:167: in function 'run_each'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:174: in function 'it'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:244: in function <.../workspace/parley.nvim/tests/integration/define_spec.lua:193>\n"
  } }	{
  errs = { {
      descriptions = { "define: skill_invoke read-only seams (#161)" },
      msg = "vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for \"/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/4wnlzS/1-def/chat.md\", recovery impossible\n\nstack traceback:\n\tvim/_editor.lua: in function 'cmd'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:91: in function 'w'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:167: in function 'run_each'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:174: in function 'it'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:124: in function <.../workspace/parley.nvim/tests/integration/define_spec.lua:77>\n"
    }, {
      descriptions = { "define_visual + render_definition (#161)" },
      msg = "vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for \"/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/4wnlzS/2-dv/chat.md\", recovery impossible\n\nstack traceback:\n\tvim/_editor.lua: in function 'cmd'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:207: in function 'w'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:167: in function 'run_each'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:174: in function 'it'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:244: in function <.../workspace/parley.nvim/tests/integration/define_spec.lua:193>\n"
    } },
  fail = { {
      descriptions = { "define keybinding split (#161)", "real prep_chat wiring: <M-CR>/<C-g><C-g> buffer-mapped in visual mode" },
      msg = "vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for \"/private/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/4wnlzS/0-define-chat/2026-03-01-kbwire.md\", recovery impossible\n\nstack traceback:\n\tvim/_editor.lua: in function 'cmd'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:446: in function <.../workspace/parley.nvim/tests/integration/define_spec.lua:438>\n"
    } },
  pass = { {
      descriptions = { "emit_definition tool", "is registered and selectable without raising" }
    }, {
      descriptions = { "emit_definition tool", "does not advertise pager offset/limit params" }
    }, {
      descriptions = { "define skill", "is auto-discovered by the registry" }
    }, {
      descriptions = { "define skill", "folds the phrase into the system prompt and forces no tool" }
    }, {
      descriptions = { "define: web-toggle payload (#161)", "includes web_search in the anthropic payload iff the global toggle is on" }
    }, {
      descriptions = { "define keybinding split (#161)", "routes visual <M-CR> to define, keeps visual <C-g><C-g> as respond, n/i respond" }
    }, {
      descriptions = { "define: context_for_selection vs real parse_chat (#161)", "slices the enclosing exchange from real parse_chat output (field contract)" }
    } }
}	
Parley.nvim: Failed to open file for writing: /Users/xianxu/.local/share/nvim/parley/persisted/state.jsonParley.nvim: Failed to open file for writing: /Users/xianxu/.local/share/nvim/parley/persisted/state.json
]111
codex
I have enough for the review: no correctness blocker in the changed code, but the docs gate finds a required atlas update. I’m grabbing exact line numbers for the handoff.
exec
/bin/zsh -lc "nl -ba lua/parley/skill_render.lua | sed -n '168,242p'" in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc "nl -ba atlas/chat/inline_define.md | sed -n '28,62p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   168	--- @param buf number
   169	--- @param lnum0 number 0-based start line
   170	--- @param col_start number 0-based start column
   171	--- @param end_lnum0_or_col_end number 0-based end line, or end column
   172	--- @param col_end number|nil 0-based exclusive end column
   173	function M.highlight_span(buf, lnum0, col_start, end_lnum0_or_col_end, col_end)
   174	    ensure_namespaces()
   175	    local end_lnum0 = lnum0
   176	    if col_end == nil then
   177	        col_end = end_lnum0_or_col_end
   178	    else
   179	        end_lnum0 = end_lnum0_or_col_end
   180	    end
   181	    vim.api.nvim_buf_set_extmark(buf, hl_ns_id, lnum0, col_start, {
   182	        end_row = end_lnum0,
   183	        end_col = col_end,
   184	        hl_group = "DiffChange",
   185	        strict = false,
   186	    })
   187	end
   188	
   189	--- Capture the current decoration set as redrawable data (for the undo/redo
   190	--- projection record, #133 M5). Whole-line highlights stay in `hl_lines`; span
   191	--- highlights and diagnostics preserve columns so exact anchors can be restored.
   192	function M.snapshot(buf)
   193	    ensure_namespaces()
   194	    local hl_lines = {}
   195	    local hl_spans = {}
   196	    for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf, hl_ns_id, 0, -1, { details = true })) do
   197	        local details = m[4] or {}
   198	        local is_legacy_line = m[3] == 0 and details.end_row == m[2] + 1 and details.end_col == 0
   199	        if is_legacy_line or details.end_row == nil or details.end_col == nil then
   200	            table.insert(hl_lines, m[2]) -- m = {id, row, col}; row is the 0-based line
   201	        else
   202	            table.insert(hl_spans, {
   203	                lnum = m[2],
   204	                col = m[3],
   205	                end_lnum = details.end_row,
   206	                end_col = details.end_col,
   207	            })
   208	        end
   209	    end
   210	    local diags = {}
   211	    for _, d in ipairs(vim.diagnostic.get(buf, { namespace = diag_ns_id })) do
   212	        table.insert(diags, {
   213	            lnum = d.lnum,
   214	            col = d.col or 0,
   215	            end_lnum = d.end_lnum,
   216	            end_col = d.end_col,
   217	            message = d.message,
   218	        })
   219	    end
   220	    return { hl_lines = hl_lines, hl_spans = hl_spans, diags = diags }
   221	end
   222	
   223	--- Redraw a snapshot's decorations (clearing first). Only valid when the buffer
   224	--- content matches the state the snapshot was captured at (the projection caller
   225	--- guarantees this via a content-hash match). #133 M5.
   226	function M.apply_snapshot(buf, snap)
   227	    ensure_namespaces()
   228	    M.clear_decorations(buf)
   229	    snap = snap or {}
   230	    for _, line in ipairs(snap.hl_lines or {}) do
   231	        vim.api.nvim_buf_add_highlight(buf, hl_ns_id, "DiffChange", line, 0, -1)
   232	    end
   233	    for _, span in ipairs(snap.hl_spans or {}) do
   234	        M.highlight_span(buf, span.lnum, span.col or 0, span.end_lnum or span.lnum, span.end_col)
   235	    end
   236	    if snap.diags and #snap.diags > 0 then
   237	        local diagnostics = {}
   238	        for _, d in ipairs(snap.diags) do
   239	            table.insert(diagnostics, {
   240	                lnum = d.lnum,
   241	                end_lnum = d.end_lnum or d.lnum,
   242	                col = d.col or 0,

 succeeded in 0ms:
    28	4. **`render_definition`** (`on_done`), on a successful lookup: re-verifies the
    29	   selection still holds the phrase (else skips — the buffer changed under the
    30	   in-flight call), then **(a)** adds a `[^id]` reference after the selected term
    31	   and inserts/updates a final managed footnote footer via one buffer rewrite
    32	   (`define.apply_definition_footnote`) — a single undo entry that anchors
    33	   everything; **(b)** highlights the line(s) whole-line `DiffChange`
    34	   (`skill_render.highlight_line`); **(c)** sets one INFO `vim.diagnostic` on
    35	   the selected term/reference span (`define.format_definition` →
    36	   `skill_render.wrap`) on the `parley_skill` namespace; **(d)** records the
    37	   undo/redo projection states.
    38	   `diag_display`'s `virtual_lines{current_line=true}` reveals the diagnostic
    39	   (cursor parked on the term's line). A no-`emit_definition` response leaves no
    40	   footnote reference/footer.
    41	
    42	## Undo (`u`) — reuses review's projection
    43	
    44	Native `u` reverts *text*, not decorations. The footnote reference/footer rewrite
    45	is the one text change, so `u` reverts it; the decorations are cleared/restored by review's
    46	**projection watcher** (`skills/review/projection.lua`, #133 M5), which define
    47	reuses: `render_definition` calls `projection.record_empty_for(buf, original)`
    48	(pre-footnote hash → empty snapshot), `record(buf)` (footnoted hash → the
    49	highlight + diagnostic), `ensure_watch(buf)`. Undoing the footnote edit lands on
    50	the pre-footnote content-hash → the empty snapshot renders → both decorations clear;
    51	`<C-r>` re-renders. The highlight must be **whole-line** because
    52	`skill_render.snapshot`/`apply_snapshot` are line-granular. `set_applying`
    53	guards the edit so a prior define's watcher doesn't mistake it for a user edit.
    54	
    55	## Pure core vs IO shell (ARCH-PURE)
    56	
    57	- **Pure** (`lua/parley/define.lua`, unit-tested with plain tables): `slice_selection`,
    58	  `context_for_selection`, `format_definition`, `bracket_edit` (plans the `[term]`
    59	  wrap as a legacy set_lines edit), `diagnostic_span_after_bracket` (legacy range
    60	  mapping), `apply_definition_footnote` (durable footer transform), and
    61	  `strip_definition_footnote_footer` (removes only a final `---` block followed
    62	  solely by footnotes).

exec
/bin/zsh -lc "nl -ba lua/parley/init.lua | sed -n '1638,1658p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
  1638		projection.set_applying(buf, true)
  1639		local input = call.input or {}
  1640		local e = define.apply_definition_footnote(lines, sr, sc - 1, er, ec - 1, input.term or phrase, input.definition)
  1641		require("parley.buffer_edit").replace_all_lines_for_definition(buf, e.lines)
  1642	
  1643		local width = math.max(40, vim.api.nvim_win_get_width(0) - 8)
  1644		local msg = define.format_definition(input.term or phrase, e.definition, width)
  1645		local diag_span = e.diagnostic_span
  1646		skill_render.highlight_span(buf, diag_span.lnum, diag_span.col, diag_span.end_lnum, diag_span.end_col)
  1647		vim.diagnostic.set(skill_render.diag_namespace(), buf, { {
  1648			lnum = diag_span.lnum,
  1649			col = diag_span.col,
  1650			end_lnum = diag_span.end_lnum,
  1651			end_col = diag_span.end_col,
  1652			message = msg,
  1653			severity = vim.diagnostic.severity.INFO,
  1654			source = "parley-define",
  1655		} })
  1656	
  1657		-- Record projection states so undo/redo of the footnote edit clears/restores
  1658		-- the decorations (#133 M5 machinery, reused): pre-edit hash → empty

exec
/bin/zsh -lc "nl -ba tests/integration/define_spec.lua | sed -n '260,346p' && nl -ba tests/unit/skill_render_spec.lua | sed -n '108,142p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   260	        -- diagnostic on the term's line
   261	        local diags = vim.diagnostic.get(buf, { namespace = ns })
   262	        assert.are.equal(2, diags[1].lnum) -- 0-based line 3
   263	        assert.are.equal(8, diags[1].col)
   264	        assert.are.equal(2, diags[1].end_lnum)
   265	        assert.are.equal(19, diags[1].end_col) -- ASIN plus [^asin]
   266	        assert.is_true(diags[1].message:find("ASIN", 1, true) ~= nil)
   267	        -- DiffChange highlight covers only ASIN[^asin], not the whole paragraph.
   268	        local mark = first_hl_mark(buf)
   269	        assert.is_not_nil(mark, "term/reference span not highlighted")
   270	        assert.are.equal(2, mark[2])
   271	        assert.are.equal(8, mark[3])
   272	        assert.are.equal(2, mark[4].end_row)
   273	        assert.are.equal(19, mark[4].end_col)
   274	    end)
   275	
   276	    it("re-defining a footnoted term updates the footer without duplicating the inline reference", function()
   277	        vim.fn.setpos("'<", { buf, 3, 9, 0 })
   278	        vim.fn.setpos("'>", { buf, 3, 12, 0 })
   279	        require("parley").define_visual(buf)
   280	        vim.wait(2000, function()
   281	            return vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1] == "here is ASIN[^asin] in context"
   282	        end)
   283	
   284	        parley.dispatcher.query = function(_b, _p, _payload, _h, on_exit)
   285	            tasker.set_query("qid_dv_updated", {
   286	                raw_response = emit_definition_sse("ASIN", "Updated definition."),
   287	            })
   288	            vim.schedule(function() on_exit("qid_dv_updated") end)
   289	        end
   290	
   291	        vim.fn.setpos("'<", { buf, 3, 9, 0 })
   292	        vim.fn.setpos("'>", { buf, 3, 12, 0 })
   293	        require("parley").define_visual(buf)
   294	        vim.wait(2000, function()
   295	            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
   296	            return table.concat(lines, "\n"):find("%[%^asin%]: Updated definition%.") ~= nil
   297	        end)
   298	
   299	        assert.are.equal("here is ASIN[^asin] in context",
   300	            vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1])
   301	        assert.are.same({
   302	            "---",
   303	            "",
   304	            "[^asin]: Updated definition.",
   305	        }, vim.api.nvim_buf_get_lines(buf, 5, 8, false))
   306	    end)
   307	
   308	    it("u undoes the footnote edit + clears decorations; C-r restores them (R1)", function()
   309	        vim.fn.setpos("'<", { buf, 3, 9, 0 })
   310	        vim.fn.setpos("'>", { buf, 3, 12, 0 })
   311	        require("parley").define_visual(buf)
   312	        vim.wait(2000, function()
   313	            return #vim.diagnostic.get(buf, { namespace = ns }) > 0
   314	        end)
   315	        assert.are.equal("here is ASIN[^asin] in context",
   316	            vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1])
   317	
   318	        -- undo: the footnote edit reverts; the projection watcher (TextChanged) clears
   319	        -- both decorations. Fire the autocmd Vim fires interactively — headless
   320	        -- :undo doesn't trigger TextChanged on its own (the watcher itself is
   321	        -- covered by projection's own specs; here we verify define's records).
   322	        vim.cmd("silent undo")
   323	        vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
   324	        assert.are.equal("here is ASIN in context",
   325	            vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1])
   326	        assert.is_nil(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
   327	            :find("%[%^asin%]:", 1, false), "footnote not removed on undo")
   328	        assert.are.equal(0, #vim.diagnostic.get(buf, { namespace = ns }),
   329	            "diagnostic not cleared on undo")
   330	        assert.is_false(hl_on_line(buf, 2), "highlight not cleared on undo")
   331	
   332	        -- redo: footnote edit + decorations return
   333	        vim.cmd("silent redo")
   334	        vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
   335	        assert.are.equal("here is ASIN[^asin] in context",
   336	            vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1])
   337	        local redone_mark = first_hl_mark(buf)
   338	        assert.is_not_nil(redone_mark, "highlight not restored on redo")
   339	        assert.are.equal(2, redone_mark[2])
   340	        assert.are.equal(8, redone_mark[3])
   341	        assert.are.equal(2, redone_mark[4].end_row)
   342	        assert.are.equal(19, redone_mark[4].end_col)
   343	        local redone_diags = vim.diagnostic.get(buf, { namespace = ns })
   344	        assert.are.equal(8, redone_diags[1].col)
   345	        assert.are.equal(19, redone_diags[1].end_col)
   346	        assert.is_true(#vim.diagnostic.get(buf, { namespace = ns }) >= 1,
   108	        local buf = scratch({ "here is ASIN[^asin] in context" })
   109	        local hl_ns = vim.api.nvim_create_namespace("parley_skill_hl")
   110	        local diag_ns = skill_render.diag_namespace()
   111	
   112	        skill_render.highlight_span(buf, 0, 8, 19)
   113	        vim.diagnostic.set(diag_ns, buf, { {
   114	            lnum = 0,
   115	            col = 8,
   116	            end_lnum = 0,
   117	            end_col = 19,
   118	            message = "why",
   119	            severity = vim.diagnostic.severity.INFO,
   120	            source = "test",
   121	        } })
   122	
   123	        local snap = skill_render.snapshot(buf)
   124	        skill_render.clear_decorations(buf)
   125	        skill_render.apply_snapshot(buf, snap)
   126	
   127	        local marks = vim.api.nvim_buf_get_extmarks(buf, hl_ns, 0, -1, { details = true })
   128	        assert.are.equal(1, #marks)
   129	        assert.are.equal(0, marks[1][2])
   130	        assert.are.equal(8, marks[1][3])
   131	        assert.are.equal(0, marks[1][4].end_row)
   132	        assert.are.equal(19, marks[1][4].end_col)
   133	
   134	        local diags = vim.diagnostic.get(buf, { namespace = diag_ns })
   135	        assert.are.equal(1, #diags)
   136	        assert.are.equal(8, diags[1].col)
   137	        assert.are.equal(19, diags[1].end_col)
   138	    end)
   139	
   140	    it("dismiss clears decorations (alias of clear_decorations)", function()
   141	        local buf = scratch({ "x" })
   142	        skill_render.attach_diagnostics(buf, { { pos = 1, explain = "e" } }, "x")

codex
```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The code change matches the issue purpose: define rendering now derives both the visible highlight and diagnostic from `e.diagnostic_span`, and snapshot projection preserves column spans. I found no correctness blocker in the changed code. The one gate issue is documentation: `atlas/chat/inline_define.md` still describes the old whole-line/line-granular model, so the atlas update is missing/stale for the changed surface.

1. Strengths

- `lua/parley/init.lua:1645`: highlight and diagnostic now share `e.diagnostic_span`, satisfying ARCH-DRY and the issue’s stated source-of-truth requirement.
- `lua/parley/skill_render.lua:192`: `snapshot` preserves both legacy whole-line highlights and new span extmarks, keeping backward compatibility.
- `lua/parley/skill_render.lua:211`: diagnostic `col`/`end_col` now round-trip through projection snapshots.
- `tests/integration/define_spec.lua:267` and `tests/integration/define_spec.lua:337`: integration coverage pins both initial render and redo-restored span behavior.
- `tests/unit/skill_render_spec.lua:108`: focused unit coverage pins span snapshot/apply behavior without IO-heavy mocking.

2. Critical findings

None.

3. Important findings

- `atlas/chat/inline_define.md:33` and `atlas/chat/inline_define.md:51`: atlas still says define highlights whole lines via `skill_render.highlight_line` and that projection requires whole-line highlights because snapshots are line-granular. That is now false. Docs update gate: atlas update appears missing for span-scoped define highlights and column-preserving projection snapshots. Fix by updating the Flow, Undo, and v1 limitations text to describe `skill_render.highlight_span` plus `snapshot`/`apply_snapshot` preserving `hl_spans` and diagnostic columns. ARCH-PURPOSE: the implementation delivers the purpose, but the architectural map still restates the old model.

4. Minor findings

None.

5. Test coverage notes

- Passed: `nvim --headless -c "PlenaryBustedFile tests/unit/skill_render_spec.lua"`: 10 passed.
- `git diff --check 5640bcaa934b0b5bc4c6c2d18b042996afd74f83...HEAD` produced no whitespace errors.
- I could not independently complete `tests/integration/define_spec.lua` in this sandbox: Neovim failed opening swap files under `/var/folders/...` before the changed span assertions ran. The added assertions themselves are well-targeted, and the failure shape is environment setup, not this diff.

6. Architectural notes for upcoming work

- ARCH-DRY: Pass. Diagnostic and highlight ranges derive from `DefinitionDiagnosticSpan`.
- ARCH-PURE: Pass. Span calculation remains in `define.apply_definition_footnote`; `render_definition` stays an IO shell.
- ARCH-PURPOSE: Code passes; atlas documentation is the only flagged drift.

7. Plan revision recommendations

None. The plan matches the delivered code.
tokens used
63,758
```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The code change matches the issue purpose: define rendering now derives both the visible highlight and diagnostic from `e.diagnostic_span`, and snapshot projection preserves column spans. I found no correctness blocker in the changed code. The one gate issue is documentation: `atlas/chat/inline_define.md` still describes the old whole-line/line-granular model, so the atlas update is missing/stale for the changed surface.

1. Strengths

- `lua/parley/init.lua:1645`: highlight and diagnostic now share `e.diagnostic_span`, satisfying ARCH-DRY and the issue’s stated source-of-truth requirement.
- `lua/parley/skill_render.lua:192`: `snapshot` preserves both legacy whole-line highlights and new span extmarks, keeping backward compatibility.
- `lua/parley/skill_render.lua:211`: diagnostic `col`/`end_col` now round-trip through projection snapshots.
- `tests/integration/define_spec.lua:267` and `tests/integration/define_spec.lua:337`: integration coverage pins both initial render and redo-restored span behavior.
- `tests/unit/skill_render_spec.lua:108`: focused unit coverage pins span snapshot/apply behavior without IO-heavy mocking.

2. Critical findings

None.

3. Important findings

- `atlas/chat/inline_define.md:33` and `atlas/chat/inline_define.md:51`: atlas still says define highlights whole lines via `skill_render.highlight_line` and that projection requires whole-line highlights because snapshots are line-granular. That is now false. Docs update gate: atlas update appears missing for span-scoped define highlights and column-preserving projection snapshots. Fix by updating the Flow, Undo, and v1 limitations text to describe `skill_render.highlight_span` plus `snapshot`/`apply_snapshot` preserving `hl_spans` and diagnostic columns. ARCH-PURPOSE: the implementation delivers the purpose, but the architectural map still restates the old model.

4. Minor findings

None.

5. Test coverage notes

- Passed: `nvim --headless -c "PlenaryBustedFile tests/unit/skill_render_spec.lua"`: 10 passed.
- `git diff --check 5640bcaa934b0b5bc4c6c2d18b042996afd74f83...HEAD` produced no whitespace errors.
- I could not independently complete `tests/integration/define_spec.lua` in this sandbox: Neovim failed opening swap files under `/var/folders/...` before the changed span assertions ran. The added assertions themselves are well-targeted, and the failure shape is environment setup, not this diff.

6. Architectural notes for upcoming work

- ARCH-DRY: Pass. Diagnostic and highlight ranges derive from `DefinitionDiagnosticSpan`.
- ARCH-PURE: Pass. Span calculation remains in `define.apply_definition_footnote`; `render_definition` stays an IO shell.
- ARCH-PURPOSE: Code passes; atlas documentation is the only flagged drift.

7. Plan revision recommendations

None. The plan matches the delivered code.
