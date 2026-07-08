# Boundary Review — parley.nvim#176 (whole-issue close)

| field | value |
|-------|-------|
| issue | 176 — footnote diagnosis should display in centered float |
| repo | parley.nvim |
| issue file | workshop/issues/000176-footnote-diagnosis-centered-float.md |
| boundary | whole-issue close |
| milestone | — |
| window | 35fee214c0dcecaa44d4017e4d37ffa3d883571c..HEAD |
| command | sdlc close --issue 176 |
| reviewer | codex |
| timestamp | 2026-07-08T14:09:15-07:00 |
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
session id: 019f438e-e19f-7f53-ace9-bf24eabd0b0b
--------
user
# Code review — the one SDLC boundary review

You are conducting a fresh-context code review at a development boundary —
whole-issue close — in the **parley.nvim** repository.

- repository: parley.nvim   (root: /Users/xianxu/workspace/parley.nvim)
- issue:      parley.nvim#176   (file: workshop/issues/000176-footnote-diagnosis-centered-float.md)
- window:     Base: 35fee214c0dcecaa44d4017e4d37ffa3d883571c   Head: HEAD

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
index dbd3461..d40dec6 100644
--- a/atlas/chat/inline_define.md
+++ b/atlas/chat/inline_define.md
@@ -41,9 +41,9 @@ rehydrates persisted managed footnotes in all markdown buffers.
    inline `term[^id]` spans (`define.format_definition` →
    `skill_render.format_diagnostic_message`) on the `parley_skill` namespace;
    **(d)** records the undo/redo projection states.
-   `diag_display`'s Parley-owned text-column virtual-line display reveals the
-   diagnostic when the cursor is on the term/footnote anchor span. A
-   no-`emit_definition` response leaves no footnote reference/footer.
+   `diag_display` opens a centered, non-focusable diagnostic float when the
+   cursor is on the term/footnote anchor span. A no-`emit_definition` response
+   leaves no footnote reference/footer.
 
 ## Undo (`u`) — reuses review's projection
 
@@ -126,9 +126,8 @@ tool-call args (`result.calls[1].input`), read in `on_done`.
 - `skill_render.refresh_footnote_diagnostics` owns only diagnostics tagged
   `parley-footnote` and preserves other `parley_skill` diagnostics, so review
   diagnostics are not cleared by markdown footnote refresh.
-- A footnote diagnostic's Parley virtual-line block auto-hides when the cursor
-  leaves its term/footnote anchor span. The footnote persists in the file if
-  saved.
+- A footnote diagnostic's Parley float auto-hides when the cursor leaves its
+  term/footnote anchor span. The footnote persists in the file if saved.
 
 ## Key files
 
diff --git a/atlas/modes/review.md b/atlas/modes/review.md
index 23dce42..6cccd40 100644
--- a/atlas/modes/review.md
+++ b/atlas/modes/review.md
@@ -173,9 +173,9 @@ built-in `]d`/`[d` (jump) and `<C-W>d` (float, wraps) still work on these
 diagnostics because the underlying diagnostic spans remain unchanged. Composes
 with M5 — re-renders on undo/redo.
 
-The same controller also renders managed footnote diagnostics; those are tighter
-than review diagnostics and show only while the cursor is inside the
-term/`[^footnote]` diagnostic span.
+The same controller also renders managed footnote diagnostics; those use a
+centered non-focusable float instead of virtual lines, and show only while the
+cursor is inside the term/`[^footnote]` diagnostic span.
 
 ## Progress bar (#133 M7)
 
diff --git a/lua/parley/skills/review/diag_display.lua b/lua/parley/skills/review/diag_display.lua
index 004c087..9447db2 100644
--- a/lua/parley/skills/review/diag_display.lua
+++ b/lua/parley/skills/review/diag_display.lua
@@ -20,6 +20,8 @@ local DISPLAY_COL = 2
 
 local display_ns_id
 local display_augroup
+local float_win
+local float_buf
 
 -- Parley's review diagnostic namespace — single-sourced from skill_render (which
 -- owns the namespace) so the identity isn't a duplicated literal (#133 M6 review).
@@ -27,6 +29,17 @@ local function ns()
     return require("parley.skill_render").diag_namespace()
 end
 
+local function close_float()
+    if float_win and vim.api.nvim_win_is_valid(float_win) then
+        pcall(vim.api.nvim_win_close, float_win, true)
+    end
+    if float_buf and vim.api.nvim_buf_is_valid(float_buf) then
+        pcall(vim.api.nvim_buf_delete, float_buf, { force = true })
+    end
+    float_win = nil
+    float_buf = nil
+end
+
 local function ensure_display()
     if not display_ns_id then
         display_ns_id = vim.api.nvim_create_namespace(DISPLAY_NS)
@@ -40,6 +53,7 @@ end
 
 local function clear(buf)
     ensure_display()
+    close_float()
     if vim.api.nvim_buf_is_valid(buf) then
         vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
         pcall(vim.api.nvim_clear_autocmds, { group = display_augroup, buffer = buf })
@@ -65,6 +79,16 @@ local function diagnostic_message_lines(diagnostic)
     return lines
 end
 
+local function diagnostic_float_lines(diagnostics)
+    local lines = { "Diagnostics:" }
+    for _, diagnostic in ipairs(diagnostics or {}) do
+        for _, line in ipairs(vim.split(tostring(diagnostic.message or ""), "\n", { plain = true })) do
+            table.insert(lines, line ~= "" and line or " ")
+        end
+    end
+    return lines
+end
+
 local function diagnostic_contains_line(diagnostic, line)
     local start_line = diagnostic.lnum or 0
     local end_line = diagnostic.end_lnum or start_line
@@ -93,12 +117,51 @@ local function diagnostic_visible_at(diagnostic, line, col)
     return diagnostic_contains_line(diagnostic, line)
 end
 
+local function float_config(win, line_count)
+    local win_width = vim.api.nvim_win_get_width(win)
+    local win_height = vim.api.nvim_win_get_height(win)
+    local width = math.max(1, math.floor(win_width * 0.8))
+    local height = math.max(1, math.min(line_count, math.max(1, win_height - 2)))
+    return {
+        relative = "win",
+        win = win,
+        width = width,
+        height = height,
+        row = math.min(vim.fn.winline(), math.max(0, win_height - height)),
+        col = math.floor((win_width - width) / 2),
+        style = "minimal",
+        border = "rounded",
+        focusable = false,
+        title = { { "Diagnostics", HEADER_HL } },
+        title_pos = "left",
+    }
+end
+
+local function show_float(diagnostics)
+    close_float()
+    if #diagnostics == 0 then
+        return
+    end
+    local win = vim.api.nvim_get_current_win()
+    local lines = diagnostic_float_lines(diagnostics)
+    float_buf = vim.api.nvim_create_buf(false, true)
+    vim.api.nvim_buf_set_option(float_buf, "buftype", "nofile")
+    vim.api.nvim_buf_set_option(float_buf, "bufhidden", "wipe")
+    vim.api.nvim_buf_set_option(float_buf, "modifiable", true)
+    require("parley.buffer_edit").replace_all_lines(float_buf, lines)
+    vim.api.nvim_buf_set_option(float_buf, "modifiable", false)
+    float_win = vim.api.nvim_open_win(float_buf, false, float_config(win, #lines))
+    vim.api.nvim_win_set_option(float_win, "wrap", true)
+    vim.api.nvim_win_set_option(float_win, "winhl", "NormalFloat:NormalFloat,FloatBorder:FloatBorder")
+end
+
 local function render(buf, diagnostics, current_line_only)
     ensure_display()
     if not vim.api.nvim_buf_is_valid(buf) then
         return
     end
     vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
+    close_float()
 
     local line, col
     if current_line_only then
@@ -109,12 +172,21 @@ local function render(buf, diagnostics, current_line_only)
     end
 
     local by_line = {}
+    local footnote_diagnostics = {}
     for _, diagnostic in ipairs(diagnostics or {}) do
         if not current_line_only or diagnostic_visible_at(diagnostic, line, col) then
-            by_line[diagnostic.lnum] = by_line[diagnostic.lnum] or {}
-            table.insert(by_line[diagnostic.lnum], diagnostic)
+            if diagnostic.source == "parley-footnote" then
+                table.insert(footnote_diagnostics, diagnostic)
+            else
+                by_line[diagnostic.lnum] = by_line[diagnostic.lnum] or {}
+                table.insert(by_line[diagnostic.lnum], diagnostic)
+            end
         end
     end
+    table.sort(footnote_diagnostics, function(a, b)
+        return (a.col or 0) < (b.col or 0)
+    end)
+    show_float(footnote_diagnostics)
 
     for lnum, line_diagnostics in pairs(by_line) do
         table.sort(line_diagnostics, function(a, b)
diff --git a/tests/integration/review_diag_display_spec.lua b/tests/integration/review_diag_display_spec.lua
index 3614c1f..c7f14eb 100644
--- a/tests/integration/review_diag_display_spec.lua
+++ b/tests/integration/review_diag_display_spec.lua
@@ -11,6 +11,17 @@ local function display_marks(buf)
     return vim.api.nvim_buf_get_extmarks(buf, display_ns, 0, -1, { details = true })
 end
 
+local function diagnostic_floats()
+    local floats = {}
+    for _, win in ipairs(vim.api.nvim_list_wins()) do
+        local cfg = vim.api.nvim_win_get_config(win)
+        if cfg.relative ~= "" and cfg.focusable == false and cfg.title and cfg.title[1][1] == "Diagnostics" then
+            table.insert(floats, { win = win, config = cfg, buf = vim.api.nvim_win_get_buf(win) })
+        end
+    end
+    return floats
+end
+
 describe("review.diag_display", function()
     after_each(function()
         dd.set(true) -- restore default for other specs
@@ -40,11 +51,13 @@ describe("review.diag_display", function()
         assert.is_false(ns_cfg()["parley/virtual_lines"])
     end)
 
-    it("renders current-line diagnostics inset from the buffer text column without moving the diagnostic span", function()
+    it("renders footnote diagnostics in a centered non-focusable float without moving the diagnostic span", function()
         local skill_render = require("parley.skill_render")
         local diag_ns = skill_render.diag_namespace()
         local buf = vim.api.nvim_create_buf(false, true)
         vim.api.nvim_set_current_buf(buf)
+        vim.api.nvim_win_set_width(0, 100)
+        local parent_width = vim.api.nvim_win_get_width(0)
         vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
             string.rep("x", 120) .. " ACOS[^acos]",
         })
@@ -62,17 +75,19 @@ describe("review.diag_display", function()
         } })
 
         vim.wait(100, function()
-            return #display_marks(buf) == 1
+            return #diagnostic_floats() == 1
         end)
 
-        local marks = display_marks(buf)
-        assert.are.equal(1, #marks)
-        assert.are.equal(2, marks[1][3])
-        local details = marks[1][4]
-        assert.is_not_true(details.virt_lines_leftcol)
-        assert.are.equal("Diagnostics:", details.virt_lines[1][1][1])
-        assert.are_not.equal(string.rep(" ", 121), details.virt_lines[1][1][1])
-        assert.are.equal("ACOS — Advertising Cost of Sales.", details.virt_lines[2][1][1])
+        assert.are.equal(0, #display_marks(buf))
+        local floats = diagnostic_floats()
+        assert.are.equal(1, #floats)
+        local expected_width = math.max(1, math.floor(parent_width * 0.8))
+        assert.are.equal(expected_width, floats[1].config.width)
+        assert.are.equal(math.floor((parent_width - expected_width) / 2), floats[1].config.col)
+        assert.is_false(floats[1].config.focusable)
+        local lines = vim.api.nvim_buf_get_lines(floats[1].buf, 0, -1, false)
+        assert.are.equal("Diagnostics:", lines[1])
+        assert.are.equal("ACOS — Advertising Cost of Sales.", lines[2])
 
         local diagnostics = vim.diagnostic.get(buf, { namespace = diag_ns })
         assert.are.equal(1, #diagnostics)
@@ -83,6 +98,7 @@ describe("review.diag_display", function()
 
         dd.set(false)
         assert.are.equal(0, #display_marks(buf))
+        assert.are.equal(0, #diagnostic_floats())
         assert.are.equal(1, #vim.diagnostic.get(buf, { namespace = diag_ns }))
     end)
 
@@ -109,13 +125,11 @@ describe("review.diag_display", function()
 
         vim.api.nvim_win_set_cursor(0, { 1, 8 })
         vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
-        local marks = display_marks(buf)
-        assert.are.equal(1, #marks, "cursor inside the footnote anchor should show diagnosis")
-        assert.are.equal(2, marks[1][3])
+        assert.are.equal(1, #diagnostic_floats(), "cursor inside the footnote anchor should show diagnosis")
 
         vim.api.nvim_win_set_cursor(0, { 1, 25 })
         vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
-        assert.are.equal(0, #display_marks(buf), "same line outside the anchor should hide diagnosis")
+        assert.are.equal(0, #diagnostic_floats(), "same line outside the anchor should hide diagnosis")
     end)
 
     it("keeps a multi-line diagnostic visible anywhere inside its span", function()


codex
I’ll use `superpowers-using-superpowers` first because this session’s instructions require it before acting, then I’ll inspect the issue, diff, and relevant code/tests as a read-only boundary review.
exec
/bin/zsh -lc "sed -n '1,220p' /Users/xianxu/workspace/ariadne/construct/adapted/superpowers-using-superpowers/SKILL.md && sdlc --help" in /Users/xianxu/workspace/parley.nvim
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

codex
I’ve got the workflow contract. Next I’m checking the issue record and the actual changed files at `35fee214..HEAD`, then I’ll compare the implementation against the stated Spec/Plan rather than the patch summary.
exec
/bin/zsh -lc "sed -n '1,260p' workshop/issues/000176-footnote-diagnosis-centered-float.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
---
id: 000176
status: working
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 0.36
started: 2026-07-08T14:02:53-07:00
---

# footnote diagnosis should display in centered float

## Problem

Virtual-line diagnostics cannot render directly under a soft-wrapped screen row.
For footnote definitions, the desired effect is closer to an automatically
managed diagnostic float: while the cursor is on the term/`[^footnote]` anchor,
show the definition in a centered floating window like the built-in diagnostic
float, sized to most of the editing window.

## Spec

- `parley-footnote` diagnostics should render in an auto-managed floating window,
  not as Parley virtual lines.
- The float should open only while the cursor is inside the footnote diagnostic
  span, preserving #175's anchor-only trigger.
- The float should be 80% of the current editor window width, centered
  horizontally over that window, non-focusable, bordered, and visually similar to
  the current diagnostic presentation with a `Diagnostics:` header.
- The float should close when the cursor leaves the anchor span, when diagnostics
  are disabled, or when the handler hides/clears diagnostics.
- Non-footnote diagnostics, especially review diagnostics sourced from
  `parley-skill`, should keep the existing virtual-line behavior and multi-line
  region visibility.
- Keep this in `skills/review/diag_display.lua` so the display policy stays
  centralized (ARCH-DRY, ARCH-PURPOSE). Extract small deterministic helpers for
  width/column math where useful (ARCH-PURE).

## Done when

- A footnote diagnosis produces no Parley virtual-line extmark while the cursor
  is on its anchor.
- The same footnote diagnosis opens a centered, non-focusable float at 80% of the
  active window width.
- Moving off the anchor closes the float.
- Review diagnostics still render as virtual lines and keep their region
  behavior.

## Estimate

Derived via `estimate-logic-v3.1` against the repo-local calibration source from
`sdlc estimate-source` (stale but canonical for this repo).

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.04 impl=0.00
item: lua-neovim design=0.06 impl=0.18
item: milestone-review design=0.00 impl=0.08
total: 0.36
```

## Plan

- [x] Add failing integration coverage for footnote float display and review
  virtual-line preservation.
- [x] Implement a footnote-only centered float path in `diag_display`.
- [x] Update atlas, run focused display/define tests, scoped whitespace check,
  and full suite.

## Log

### 2026-07-08
- Design: footnotes move from virtual lines to an auto-managed float because
  virtual lines attach to logical buffer lines, not soft-wrapped screen rows.
  Review diagnostics remain virtual lines because their edit-region display is
  already working and less intrusive.
- Red: `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"`
  failed because footnote diagnostics still created a virtual-line extmark and
  no diagnostic float.
- Green: added a footnote-only float path in `diag_display`, sized to 80% of the
  active window and centered horizontally; review diagnostics still render as
  virtual lines.
- Full-suite fix: the first implementation wrote float buffer contents directly
  with `nvim_buf_set_lines`, and `tests/arch/buffer_mutation_spec.lua` rejected
  that. Routed the scratch float buffer write through
  `buffer_edit.replace_all_lines`, then re-ran the arch spec and full suite.
- Verification: `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"`;
  `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`;
  `nvim --headless -c "PlenaryBustedFile tests/arch/buffer_mutation_spec.lua"`;
  `git diff --check -- lua/parley/skills/review/diag_display.lua
  tests/integration/review_diag_display_spec.lua atlas/chat/inline_define.md
  atlas/modes/review.md workshop/issues/000176-footnote-diagnosis-centered-float.md`;
  `make test`.

exec
/bin/zsh -lc 'git diff --name-only 35fee214c0dcecaa44d4017e4d37ffa3d883571c..HEAD' in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc 'git diff --stat 35fee214c0dcecaa44d4017e4d37ffa3d883571c..HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
atlas/chat/inline_define.md
atlas/modes/review.md
lua/parley/skills/review/diag_display.lua
tests/integration/review_diag_display_spec.lua
workshop/issues/000176-footnote-diagnosis-centered-float.md

 succeeded in 0ms:
 atlas/chat/inline_define.md                        | 11 ++--
 atlas/modes/review.md                              |  6 +-
 lua/parley/skills/review/diag_display.lua          | 76 +++++++++++++++++++++-
 tests/integration/review_diag_display_spec.lua     | 42 ++++++++----
 .../000176-footnote-diagnosis-centered-float.md    | 73 ++++++++++++++++++++-
 5 files changed, 180 insertions(+), 28 deletions(-)

exec
/bin/zsh -lc "sed -n '1,260p' lua/parley/skills/review/diag_display.lua" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
-- diag_display.lua — inline display of Parley diagnostics (#133 M6, #173).
--
-- Controls how parley's review explanations render, scoped to parley's OWN
-- diagnostic namespace (never touches the user's LSP / global diagnostics).
-- Default ON: a custom diagnostic handler renders text-column virtual lines for
-- the cursor's current diagnostic region, so long wrapped prose doesn't hide
-- messages behind stock virtual-lines column indentation. `:ParleyShowDiagnostics`
-- toggles it.

local M = {}

M.enabled = true -- default on (cursor-region auto-show)

local HANDLER_NAME = "parley/virtual_lines"
local DISPLAY_NS = "parley_diagnostic_virtual_lines"
local DISPLAY_AUGROUP = "parley_diagnostic_virtual_lines"
local HEADER_HL = "ParleyDiagnosticVirtualLineHeader"
local MESSAGE_HL = "ParleyDiagnosticVirtualLine"
local DISPLAY_COL = 2

local display_ns_id
local display_augroup
local float_win
local float_buf

-- Parley's review diagnostic namespace — single-sourced from skill_render (which
-- owns the namespace) so the identity isn't a duplicated literal (#133 M6 review).
local function ns()
    return require("parley.skill_render").diag_namespace()
end

local function close_float()
    if float_win and vim.api.nvim_win_is_valid(float_win) then
        pcall(vim.api.nvim_win_close, float_win, true)
    end
    if float_buf and vim.api.nvim_buf_is_valid(float_buf) then
        pcall(vim.api.nvim_buf_delete, float_buf, { force = true })
    end
    float_win = nil
    float_buf = nil
end

local function ensure_display()
    if not display_ns_id then
        display_ns_id = vim.api.nvim_create_namespace(DISPLAY_NS)
    end
    if not display_augroup then
        display_augroup = vim.api.nvim_create_augroup(DISPLAY_AUGROUP, { clear = true })
    end
    vim.api.nvim_set_hl(0, HEADER_HL, { link = "DiagnosticInfo" })
    vim.api.nvim_set_hl(0, MESSAGE_HL, { link = "DiagnosticFloatingInfo" })
end

local function clear(buf)
    ensure_display()
    close_float()
    if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
        pcall(vim.api.nvim_clear_autocmds, { group = display_augroup, buffer = buf })
    end
end

local function current_pos_for(buf)
    if vim.api.nvim_get_current_buf() ~= buf then
        return nil
    end
    local pos = vim.api.nvim_win_get_cursor(0)
    return pos[1] - 1, pos[2]
end

local function diagnostic_message_lines(diagnostic)
    local lines = {}
    for _, line in ipairs(vim.split(tostring(diagnostic.message or ""), "\n", { plain = true })) do
        table.insert(lines, { { line ~= "" and line or " ", MESSAGE_HL } })
    end
    if #lines == 0 then
        table.insert(lines, { { " ", MESSAGE_HL } })
    end
    return lines
end

local function diagnostic_float_lines(diagnostics)
    local lines = { "Diagnostics:" }
    for _, diagnostic in ipairs(diagnostics or {}) do
        for _, line in ipairs(vim.split(tostring(diagnostic.message or ""), "\n", { plain = true })) do
            table.insert(lines, line ~= "" and line or " ")
        end
    end
    return lines
end

local function diagnostic_contains_line(diagnostic, line)
    local start_line = diagnostic.lnum or 0
    local end_line = diagnostic.end_lnum or start_line
    return line >= start_line and line <= end_line
end

local function diagnostic_contains_position(diagnostic, line, col)
    if not diagnostic_contains_line(diagnostic, line) then
        return false
    end
    local start_line = diagnostic.lnum or 0
    local end_line = diagnostic.end_lnum or start_line
    if line == start_line and col < (diagnostic.col or 0) then
        return false
    end
    if line == end_line and col >= (diagnostic.end_col or diagnostic.col or 0) then
        return false
    end
    return true
end

local function diagnostic_visible_at(diagnostic, line, col)
    if diagnostic.source == "parley-footnote" then
        return diagnostic_contains_position(diagnostic, line, col)
    end
    return diagnostic_contains_line(diagnostic, line)
end

local function float_config(win, line_count)
    local win_width = vim.api.nvim_win_get_width(win)
    local win_height = vim.api.nvim_win_get_height(win)
    local width = math.max(1, math.floor(win_width * 0.8))
    local height = math.max(1, math.min(line_count, math.max(1, win_height - 2)))
    return {
        relative = "win",
        win = win,
        width = width,
        height = height,
        row = math.min(vim.fn.winline(), math.max(0, win_height - height)),
        col = math.floor((win_width - width) / 2),
        style = "minimal",
        border = "rounded",
        focusable = false,
        title = { { "Diagnostics", HEADER_HL } },
        title_pos = "left",
    }
end

local function show_float(diagnostics)
    close_float()
    if #diagnostics == 0 then
        return
    end
    local win = vim.api.nvim_get_current_win()
    local lines = diagnostic_float_lines(diagnostics)
    float_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(float_buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(float_buf, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(float_buf, "modifiable", true)
    require("parley.buffer_edit").replace_all_lines(float_buf, lines)
    vim.api.nvim_buf_set_option(float_buf, "modifiable", false)
    float_win = vim.api.nvim_open_win(float_buf, false, float_config(win, #lines))
    vim.api.nvim_win_set_option(float_win, "wrap", true)
    vim.api.nvim_win_set_option(float_win, "winhl", "NormalFloat:NormalFloat,FloatBorder:FloatBorder")
end

local function render(buf, diagnostics, current_line_only)
    ensure_display()
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
    close_float()

    local line, col
    if current_line_only then
        line, col = current_pos_for(buf)
    end
    if current_line_only and not line then
        return
    end

    local by_line = {}
    local footnote_diagnostics = {}
    for _, diagnostic in ipairs(diagnostics or {}) do
        if not current_line_only or diagnostic_visible_at(diagnostic, line, col) then
            if diagnostic.source == "parley-footnote" then
                table.insert(footnote_diagnostics, diagnostic)
            else
                by_line[diagnostic.lnum] = by_line[diagnostic.lnum] or {}
                table.insert(by_line[diagnostic.lnum], diagnostic)
            end
        end
    end
    table.sort(footnote_diagnostics, function(a, b)
        return (a.col or 0) < (b.col or 0)
    end)
    show_float(footnote_diagnostics)

    for lnum, line_diagnostics in pairs(by_line) do
        table.sort(line_diagnostics, function(a, b)
            return (a.col or 0) < (b.col or 0)
        end)
        local virt_lines = { { { "Diagnostics:", HEADER_HL } } }
        for _, diagnostic in ipairs(line_diagnostics) do
            vim.list_extend(virt_lines, diagnostic_message_lines(diagnostic))
        end
        vim.api.nvim_buf_set_extmark(buf, display_ns_id, lnum, DISPLAY_COL, {
            virt_lines = virt_lines,
            virt_lines_above = false,
        })
    end
end

local function register_handler()
    ensure_display()
    vim.diagnostic.handlers[HANDLER_NAME] = {
        show = function(namespace, bufnr, diagnostics, opts)
            if namespace ~= ns() then
                return
            end
            bufnr = vim._resolve_bufnr(bufnr)
            local handler_opts = opts and opts[HANDLER_NAME] or {}
            local current_line_only = handler_opts.current_line == true
            clear(bufnr)
            if current_line_only then
                vim.api.nvim_create_autocmd("CursorMoved", {
                    buffer = bufnr,
                    group = display_augroup,
                    callback = function()
                        render(bufnr, diagnostics, true)
                    end,
                })
            end
            render(bufnr, diagnostics, current_line_only)
        end,
        hide = function(namespace, bufnr)
            if namespace ~= ns() then
                return
            end
            clear(vim._resolve_bufnr(bufnr))
        end,
    }
end

function M.refresh(buf)
    if not M.enabled then
        return
    end
    buf = buf or vim.api.nvim_get_current_buf()
    render(buf, vim.diagnostic.get(buf, { namespace = ns() }), true)
end

--- Apply the inline-display config for parley's review namespace.
--- @param on boolean
function M.set(on)
    M.enabled = on and true or false
    register_handler()
    vim.diagnostic.config({
        [HANDLER_NAME] = M.enabled and { current_line = true } or false,
        virtual_lines = false,
        virtual_text = false,
    }, ns())
    if M.enabled then
        M.refresh()
    else
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            clear(buf)
        end

exec
/bin/zsh -lc "sed -n '261,520p' lua/parley/skills/review/diag_display.lua && sed -n '1,260p' tests/integration/review_diag_display_spec.lua" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
    end
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
-- Integration tests for the review-diagnostic inline display toggle (#133 M6).

local dd = require("parley.skills.review.diag_display")

local function ns_cfg()
    return vim.diagnostic.config(nil, require("parley.skill_render").diag_namespace())
end

local function display_marks(buf)
    local display_ns = vim.api.nvim_create_namespace("parley_diagnostic_virtual_lines")
    return vim.api.nvim_buf_get_extmarks(buf, display_ns, 0, -1, { details = true })
end

local function diagnostic_floats()
    local floats = {}
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local cfg = vim.api.nvim_win_get_config(win)
        if cfg.relative ~= "" and cfg.focusable == false and cfg.title and cfg.title[1][1] == "Diagnostics" then
            table.insert(floats, { win = win, config = cfg, buf = vim.api.nvim_win_get_buf(win) })
        end
    end
    return floats
end

describe("review.diag_display", function()
    after_each(function()
        dd.set(true) -- restore default for other specs
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(buf) then
                pcall(vim.diagnostic.reset, require("parley.skill_render").diag_namespace(), buf)
            end
        end
    end)

    it("toggles the enabled state", function()
        dd.set(true)
        assert.is_true(dd.is_enabled())
        assert.is_false(dd.toggle())
        assert.is_false(dd.is_enabled())
        assert.is_true(dd.toggle())
        assert.is_true(dd.is_enabled())
    end)

    it("configures Parley's custom current-line display on its namespace when on; off when disabled", function()
        dd.set(true)
        local on = ns_cfg()
        assert.is_false(on.virtual_lines) -- Parley owns its virtual-lines renderer.
        assert.is_truthy(on["parley/virtual_lines"])
        assert.is_false(on.virtual_text) -- inline single-line is never used
        dd.set(false)
        assert.is_false(ns_cfg()["parley/virtual_lines"])
    end)

    it("renders footnote diagnostics in a centered non-focusable float without moving the diagnostic span", function()
        local skill_render = require("parley.skill_render")
        local diag_ns = skill_render.diag_namespace()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_win_set_width(0, 100)
        local parent_width = vim.api.nvim_win_get_width(0)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            string.rep("x", 120) .. " ACOS[^acos]",
        })
        vim.api.nvim_win_set_cursor(0, { 1, 122 })

        dd.set(true)
        vim.diagnostic.set(diag_ns, buf, { {
            lnum = 0,
            col = 121,
            end_lnum = 0,
            end_col = 132,
            message = "ACOS — Advertising Cost of Sales.",
            severity = vim.diagnostic.severity.INFO,
            source = "parley-footnote",
        } })

        vim.wait(100, function()
            return #diagnostic_floats() == 1
        end)

        assert.are.equal(0, #display_marks(buf))
        local floats = diagnostic_floats()
        assert.are.equal(1, #floats)
        local expected_width = math.max(1, math.floor(parent_width * 0.8))
        assert.are.equal(expected_width, floats[1].config.width)
        assert.are.equal(math.floor((parent_width - expected_width) / 2), floats[1].config.col)
        assert.is_false(floats[1].config.focusable)
        local lines = vim.api.nvim_buf_get_lines(floats[1].buf, 0, -1, false)
        assert.are.equal("Diagnostics:", lines[1])
        assert.are.equal("ACOS — Advertising Cost of Sales.", lines[2])

        local diagnostics = vim.diagnostic.get(buf, { namespace = diag_ns })
        assert.are.equal(1, #diagnostics)
        assert.are.equal(0, diagnostics[1].lnum)
        assert.are.equal(121, diagnostics[1].col)
        assert.are.equal(0, diagnostics[1].end_lnum)
        assert.are.equal(132, diagnostics[1].end_col)

        dd.set(false)
        assert.are.equal(0, #display_marks(buf))
        assert.are.equal(0, #diagnostic_floats())
        assert.are.equal(1, #vim.diagnostic.get(buf, { namespace = diag_ns }))
    end)

    it("shows footnote diagnostics only while the cursor is inside the anchor span", function()
        local skill_render = require("parley.skill_render")
        local diag_ns = skill_render.diag_namespace()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            'before ACOS[^acos] after the anchor on the same line',
        })

        dd.set(true)
        vim.diagnostic.set(diag_ns, buf, { {
            lnum = 0,
            col = 7,
            end_lnum = 0,
            end_col = 18,
            message = "ACOS — Advertising Cost of Sales.",
            severity = vim.diagnostic.severity.INFO,
            source = "parley-footnote",
        } })
        assert.are.equal(0, #display_marks(buf), "cursor starts before the footnote anchor")

        vim.api.nvim_win_set_cursor(0, { 1, 8 })
        vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
        assert.are.equal(1, #diagnostic_floats(), "cursor inside the footnote anchor should show diagnosis")

        vim.api.nvim_win_set_cursor(0, { 1, 25 })
        vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
        assert.are.equal(0, #diagnostic_floats(), "same line outside the anchor should hide diagnosis")
    end)

    it("keeps a multi-line diagnostic visible anywhere inside its span", function()
        local skill_render = require("parley.skill_render")
        local diag_ns = skill_render.diag_namespace()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "edited line one",
            "edited line two",
            "edited line three",
        })

        dd.set(true)
        vim.diagnostic.set(diag_ns, buf, { {
            lnum = 0,
            col = 0,
            end_lnum = 2,
            end_col = 17,
            message = "review explanation",
            severity = vim.diagnostic.severity.INFO,
            source = "parley-skill",
        } })
        assert.are.equal(1, #display_marks(buf))

        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
        assert.are.equal(1, #display_marks(buf), "span diagnostic should show on middle line")

        vim.api.nvim_win_set_cursor(0, { 3, 0 })
        vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
        assert.are.equal(1, #display_marks(buf), "span diagnostic should show on final line")
    end)
end)

codex
The main implementation is small and centralized. I’m checking lifecycle edge cases now: multiple windows/buffers, handler hide/disable paths, and whether review diagnostics still use only the extmark path.
exec
/bin/zsh -lc 'git diff 35fee214c0dcecaa44d4017e4d37ffa3d883571c..HEAD -- lua/parley/skills/review/diag_display.lua tests/integration/review_diag_display_spec.lua' in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc 'rg -n "nvim_open_win|winborder|DiagnosticFloating|open_float|Diagnostics:" lua tests' in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc "rg -n \"parley-footnote|refresh_footnote_diagnostics|diag_display|ParleyShowDiagnostics|parley/virtual_lines|diagnostic\\.handlers\" lua tests atlas README.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
lua/parley/float_picker.lua:660:    local results_win = vim.api.nvim_open_win(results_buf, false, results_cfg)
lua/parley/float_picker.lua:680:    local prompt_win = vim.api.nvim_open_win(prompt_buf, true, prompt_cfg)
lua/parley/float_picker.lua:706:        tag_bar_win = vim.api.nvim_open_win(tag_bar_buf, false, tag_bar_cfg)
lua/parley/init.lua:1395:	local win = vim.api.nvim_open_win(buf, true, {
lua/parley/review_menu.lua:70:    local list_win = vim.api.nvim_open_win(list_buf, true, {
lua/parley/review_menu.lua:84:    local instr_win = vim.api.nvim_open_win(instr_buf, false, {
tests/integration/review_diag_display_spec.lua:89:        assert.are.equal("Diagnostics:", lines[1])
lua/parley/progress.lua:53:    local ok, win = pcall(vim.api.nvim_open_win, buf, false, {
lua/parley/skills/review/diag_display.lua:51:    vim.api.nvim_set_hl(0, MESSAGE_HL, { link = "DiagnosticFloatingInfo" })
lua/parley/skills/review/diag_display.lua:83:    local lines = { "Diagnostics:" }
lua/parley/skills/review/diag_display.lua:153:    float_win = vim.api.nvim_open_win(float_buf, false, float_config(win, #lines))
lua/parley/skills/review/diag_display.lua:195:        local virt_lines = { { { "Diagnostics:", HEADER_HL } } }

 succeeded in 0ms:
atlas/modes/review.md:163:`parley_skill` namespace. `lua/parley/skills/review/diag_display.lua` controls how
atlas/modes/review.md:165:untouched. Default **on**: Parley's custom `parley/virtual_lines` diagnostic
atlas/modes/review.md:171:`lnum..end_lnum`) and hides otherwise. `:ParleyShowDiagnostics` toggles it. The
atlas/modes/review.md:213:- `lua/parley/skills/review/diag_display.lua` — inline "why" display toggle (`:ParleyShowDiagnostics`, cursor-region auto-show) (#133 M6)
atlas/chat/inline_define.md:39:   footnote diagnostics (`skill_render.refresh_footnote_diagnostics`), which
atlas/chat/inline_define.md:44:   `diag_display` opens a centered, non-focusable diagnostic float when the
atlas/chat/inline_define.md:126:- `skill_render.refresh_footnote_diagnostics` owns only diagnostics tagged
atlas/chat/inline_define.md:127:  `parley-footnote` and preserves other `parley_skill` diagnostics, so review
atlas/chat/inline_define.md:149:- [Document Review](../modes/review.md) — the skill/`skill_invoke`/`diag_display`
lua/parley/highlighter.lua:1076:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1089:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1111:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1116:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1127:            skill_render.refresh_footnote_diagnostics(buf)
tests/integration/review_diag_display_spec.lua:3:local dd = require("parley.skills.review.diag_display")
tests/integration/review_diag_display_spec.lua:25:describe("review.diag_display", function()
tests/integration/review_diag_display_spec.lua:48:        assert.is_truthy(on["parley/virtual_lines"])
tests/integration/review_diag_display_spec.lua:51:        assert.is_false(ns_cfg()["parley/virtual_lines"])
tests/integration/review_diag_display_spec.lua:74:            source = "parley-footnote",
tests/integration/review_diag_display_spec.lua:122:            source = "parley-footnote",
lua/parley/init.lua:770:	-- :ParleyShowDiagnostics — toggle inline display of review "why" diagnostics
lua/parley/init.lua:773:		local on = require("parley.skills.review.diag_display").toggle()
lua/parley/init.lua:776:	require("parley.skills.review.diag_display").set(true)
lua/parley/init.lua:1645:	skill_render.refresh_footnote_diagnostics(buf)
lua/parley/init.lua:1655:	-- Park the cursor on the term's line so diag_display's current-line
tests/integration/highlighting_spec.lua:512:        skill_render.refresh_footnote_diagnostics(buf)
tests/integration/highlighting_spec.lua:519:        assert.equals("parley-footnote", diagnostics[1].source)
tests/integration/highlighting_spec.lua:565:        assert.is_not_nil(by_source["parley-footnote"])
tests/integration/highlighting_spec.lua:566:        assert.equals(8, by_source["parley-footnote"].col)
lua/parley/skill_render.lua:12:local FOOTNOTE_SOURCE = "parley-footnote"
lua/parley/skill_render.lua:39:--- (diag_display) target, so the namespace identity isn't duplicated as a literal
lua/parley/skill_render.lua:114:function M.refresh_footnote_diagnostics(buf)
lua/parley/skills/review/diag_display.lua:1:-- diag_display.lua — inline display of Parley diagnostics (#133 M6, #173).
lua/parley/skills/review/diag_display.lua:7:-- messages behind stock virtual-lines column indentation. `:ParleyShowDiagnostics`
lua/parley/skills/review/diag_display.lua:14:local HANDLER_NAME = "parley/virtual_lines"
lua/parley/skills/review/diag_display.lua:114:    if diagnostic.source == "parley-footnote" then
lua/parley/skills/review/diag_display.lua:178:            if diagnostic.source == "parley-footnote" then
lua/parley/skills/review/diag_display.lua:208:    vim.diagnostic.handlers[HANDLER_NAME] = {

 succeeded in 0ms:
diff --git a/lua/parley/skills/review/diag_display.lua b/lua/parley/skills/review/diag_display.lua
index 004c087..9447db2 100644
--- a/lua/parley/skills/review/diag_display.lua
+++ b/lua/parley/skills/review/diag_display.lua
@@ -20,6 +20,8 @@ local DISPLAY_COL = 2
 
 local display_ns_id
 local display_augroup
+local float_win
+local float_buf
 
 -- Parley's review diagnostic namespace — single-sourced from skill_render (which
 -- owns the namespace) so the identity isn't a duplicated literal (#133 M6 review).
@@ -27,6 +29,17 @@ local function ns()
     return require("parley.skill_render").diag_namespace()
 end
 
+local function close_float()
+    if float_win and vim.api.nvim_win_is_valid(float_win) then
+        pcall(vim.api.nvim_win_close, float_win, true)
+    end
+    if float_buf and vim.api.nvim_buf_is_valid(float_buf) then
+        pcall(vim.api.nvim_buf_delete, float_buf, { force = true })
+    end
+    float_win = nil
+    float_buf = nil
+end
+
 local function ensure_display()
     if not display_ns_id then
         display_ns_id = vim.api.nvim_create_namespace(DISPLAY_NS)
@@ -40,6 +53,7 @@ end
 
 local function clear(buf)
     ensure_display()
+    close_float()
     if vim.api.nvim_buf_is_valid(buf) then
         vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
         pcall(vim.api.nvim_clear_autocmds, { group = display_augroup, buffer = buf })
@@ -65,6 +79,16 @@ local function diagnostic_message_lines(diagnostic)
     return lines
 end
 
+local function diagnostic_float_lines(diagnostics)
+    local lines = { "Diagnostics:" }
+    for _, diagnostic in ipairs(diagnostics or {}) do
+        for _, line in ipairs(vim.split(tostring(diagnostic.message or ""), "\n", { plain = true })) do
+            table.insert(lines, line ~= "" and line or " ")
+        end
+    end
+    return lines
+end
+
 local function diagnostic_contains_line(diagnostic, line)
     local start_line = diagnostic.lnum or 0
     local end_line = diagnostic.end_lnum or start_line
@@ -93,12 +117,51 @@ local function diagnostic_visible_at(diagnostic, line, col)
     return diagnostic_contains_line(diagnostic, line)
 end
 
+local function float_config(win, line_count)
+    local win_width = vim.api.nvim_win_get_width(win)
+    local win_height = vim.api.nvim_win_get_height(win)
+    local width = math.max(1, math.floor(win_width * 0.8))
+    local height = math.max(1, math.min(line_count, math.max(1, win_height - 2)))
+    return {
+        relative = "win",
+        win = win,
+        width = width,
+        height = height,
+        row = math.min(vim.fn.winline(), math.max(0, win_height - height)),
+        col = math.floor((win_width - width) / 2),
+        style = "minimal",
+        border = "rounded",
+        focusable = false,
+        title = { { "Diagnostics", HEADER_HL } },
+        title_pos = "left",
+    }
+end
+
+local function show_float(diagnostics)
+    close_float()
+    if #diagnostics == 0 then
+        return
+    end
+    local win = vim.api.nvim_get_current_win()
+    local lines = diagnostic_float_lines(diagnostics)
+    float_buf = vim.api.nvim_create_buf(false, true)
+    vim.api.nvim_buf_set_option(float_buf, "buftype", "nofile")
+    vim.api.nvim_buf_set_option(float_buf, "bufhidden", "wipe")
+    vim.api.nvim_buf_set_option(float_buf, "modifiable", true)
+    require("parley.buffer_edit").replace_all_lines(float_buf, lines)
+    vim.api.nvim_buf_set_option(float_buf, "modifiable", false)
+    float_win = vim.api.nvim_open_win(float_buf, false, float_config(win, #lines))
+    vim.api.nvim_win_set_option(float_win, "wrap", true)
+    vim.api.nvim_win_set_option(float_win, "winhl", "NormalFloat:NormalFloat,FloatBorder:FloatBorder")
+end
+
 local function render(buf, diagnostics, current_line_only)
     ensure_display()
     if not vim.api.nvim_buf_is_valid(buf) then
         return
     end
     vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
+    close_float()
 
     local line, col
     if current_line_only then
@@ -109,12 +172,21 @@ local function render(buf, diagnostics, current_line_only)
     end
 
     local by_line = {}
+    local footnote_diagnostics = {}
     for _, diagnostic in ipairs(diagnostics or {}) do
         if not current_line_only or diagnostic_visible_at(diagnostic, line, col) then
-            by_line[diagnostic.lnum] = by_line[diagnostic.lnum] or {}
-            table.insert(by_line[diagnostic.lnum], diagnostic)
+            if diagnostic.source == "parley-footnote" then
+                table.insert(footnote_diagnostics, diagnostic)
+            else
+                by_line[diagnostic.lnum] = by_line[diagnostic.lnum] or {}
+                table.insert(by_line[diagnostic.lnum], diagnostic)
+            end
         end
     end
+    table.sort(footnote_diagnostics, function(a, b)
+        return (a.col or 0) < (b.col or 0)
+    end)
+    show_float(footnote_diagnostics)
 
     for lnum, line_diagnostics in pairs(by_line) do
         table.sort(line_diagnostics, function(a, b)
diff --git a/tests/integration/review_diag_display_spec.lua b/tests/integration/review_diag_display_spec.lua
index 3614c1f..c7f14eb 100644
--- a/tests/integration/review_diag_display_spec.lua
+++ b/tests/integration/review_diag_display_spec.lua
@@ -11,6 +11,17 @@ local function display_marks(buf)
     return vim.api.nvim_buf_get_extmarks(buf, display_ns, 0, -1, { details = true })
 end
 
+local function diagnostic_floats()
+    local floats = {}
+    for _, win in ipairs(vim.api.nvim_list_wins()) do
+        local cfg = vim.api.nvim_win_get_config(win)
+        if cfg.relative ~= "" and cfg.focusable == false and cfg.title and cfg.title[1][1] == "Diagnostics" then
+            table.insert(floats, { win = win, config = cfg, buf = vim.api.nvim_win_get_buf(win) })
+        end
+    end
+    return floats
+end
+
 describe("review.diag_display", function()
     after_each(function()
         dd.set(true) -- restore default for other specs
@@ -40,11 +51,13 @@ describe("review.diag_display", function()
         assert.is_false(ns_cfg()["parley/virtual_lines"])
     end)
 
-    it("renders current-line diagnostics inset from the buffer text column without moving the diagnostic span", function()
+    it("renders footnote diagnostics in a centered non-focusable float without moving the diagnostic span", function()
         local skill_render = require("parley.skill_render")
         local diag_ns = skill_render.diag_namespace()
         local buf = vim.api.nvim_create_buf(false, true)
         vim.api.nvim_set_current_buf(buf)
+        vim.api.nvim_win_set_width(0, 100)
+        local parent_width = vim.api.nvim_win_get_width(0)
         vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
             string.rep("x", 120) .. " ACOS[^acos]",
         })
@@ -62,17 +75,19 @@ describe("review.diag_display", function()
         } })
 
         vim.wait(100, function()
-            return #display_marks(buf) == 1
+            return #diagnostic_floats() == 1
         end)
 
-        local marks = display_marks(buf)
-        assert.are.equal(1, #marks)
-        assert.are.equal(2, marks[1][3])
-        local details = marks[1][4]
-        assert.is_not_true(details.virt_lines_leftcol)
-        assert.are.equal("Diagnostics:", details.virt_lines[1][1][1])
-        assert.are_not.equal(string.rep(" ", 121), details.virt_lines[1][1][1])
-        assert.are.equal("ACOS — Advertising Cost of Sales.", details.virt_lines[2][1][1])
+        assert.are.equal(0, #display_marks(buf))
+        local floats = diagnostic_floats()
+        assert.are.equal(1, #floats)
+        local expected_width = math.max(1, math.floor(parent_width * 0.8))
+        assert.are.equal(expected_width, floats[1].config.width)
+        assert.are.equal(math.floor((parent_width - expected_width) / 2), floats[1].config.col)
+        assert.is_false(floats[1].config.focusable)
+        local lines = vim.api.nvim_buf_get_lines(floats[1].buf, 0, -1, false)
+        assert.are.equal("Diagnostics:", lines[1])
+        assert.are.equal("ACOS — Advertising Cost of Sales.", lines[2])
 
         local diagnostics = vim.diagnostic.get(buf, { namespace = diag_ns })
         assert.are.equal(1, #diagnostics)
@@ -83,6 +98,7 @@ describe("review.diag_display", function()
 
         dd.set(false)
         assert.are.equal(0, #display_marks(buf))
+        assert.are.equal(0, #diagnostic_floats())
         assert.are.equal(1, #vim.diagnostic.get(buf, { namespace = diag_ns }))
     end)
 
@@ -109,13 +125,11 @@ describe("review.diag_display", function()
 
         vim.api.nvim_win_set_cursor(0, { 1, 8 })
         vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
-        local marks = display_marks(buf)
-        assert.are.equal(1, #marks, "cursor inside the footnote anchor should show diagnosis")
-        assert.are.equal(2, marks[1][3])
+        assert.are.equal(1, #diagnostic_floats(), "cursor inside the footnote anchor should show diagnosis")
 
         vim.api.nvim_win_set_cursor(0, { 1, 25 })
         vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
-        assert.are.equal(0, #display_marks(buf), "same line outside the anchor should hide diagnosis")
+        assert.are.equal(0, #diagnostic_floats(), "same line outside the anchor should hide diagnosis")
     end)
 
     it("keeps a multi-line diagnostic visible anywhere inside its span", function()

exec
/bin/zsh -lc "sed -n '1,220p' lua/parley/buffer_edit.lua" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
-- Single mutation entry point for the chat buffer.
--
-- All nvim_buf_set_lines / nvim_buf_set_text calls in the chat buffer
-- rendering pipeline live here. The architectural fitness function in
-- tests/arch/buffer_mutation_spec.lua enforces this invariant.
--
-- See workshop/plans/000090-renderer-refactor.md section 3.

local M = {}

local NS_NAME = "ParleyBufferEdit"
local ns_id = vim.api.nvim_create_namespace(NS_NAME)

-- ============================================================================
-- PosHandle: opaque extmark-backed position. Caller never sees raw line
-- numbers. Internally a { buf, ns_id, ex_id, dead } table; the line is
-- resolved on demand via nvim_buf_get_extmark_by_id, so concurrent
-- inserts at or before the position are handled by the extmark gravity
-- mechanism (right_gravity = false means inserts AT the position push
-- the handle right, perfect for "anchor before this line, append text").
-- ============================================================================

--- Create a position handle anchored at a 0-indexed buffer line.
--- @param buf integer
--- @param line_0_indexed integer
--- @return PosHandle
function M.make_handle(buf, line_0_indexed)
    local ex_id = vim.api.nvim_buf_set_extmark(buf, ns_id, line_0_indexed, 0, {
        right_gravity = false,
        strict = false,
    })
    return { buf = buf, ns_id = ns_id, ex_id = ex_id, dead = false }
end

--- Resolve the current 0-indexed buffer line of a handle.
function M.handle_line(handle)
    if handle.dead then
        error("buffer_edit: handle is dead")
    end
    local pos = vim.api.nvim_buf_get_extmark_by_id(handle.buf, handle.ns_id, handle.ex_id, {})
    return pos[1]
end

--- Mark a handle dead and remove its extmark. Subsequent operations on
--- the handle raise.
function M.handle_invalidate(handle)
    if not handle.dead then
        pcall(vim.api.nvim_buf_del_extmark, handle.buf, handle.ns_id, handle.ex_id)
        handle.dead = true
    end
end

-- ============================================================================
-- Topic header ops
-- ============================================================================

--- Replace the line at line_0_indexed with `text`.
function M.set_topic_header_line(buf, line_0_indexed, text)
    vim.api.nvim_buf_set_lines(buf, line_0_indexed, line_0_indexed + 1, false, { text })
end

--- Insert `text` as a new line right after line_0_indexed.
function M.insert_topic_line(buf, after_line_0_indexed, text)
    vim.api.nvim_buf_set_lines(buf, after_line_0_indexed + 1, after_line_0_indexed + 1, false, { text })
end

-- ============================================================================
-- Answer region ops
-- ============================================================================

local render_buffer = require("parley.render_buffer")

--- Insert a single blank line after the given 0-indexed line. Used to
--- pad a question that doesn't already end with whitespace.
function M.pad_question_with_blank(buf, after_line_0_indexed)
    vim.api.nvim_buf_set_lines(buf, after_line_0_indexed + 1, after_line_0_indexed + 1, false, { "" })
end

--- Create a fresh answer region after the given 0-indexed line. Writes
--- a blank separator + agent header + trailing blank, returning a
--- PosHandle pointing at the trailing blank — the line where streaming
--- writes should append.
--- @param buf integer
--- @param after_line_0_indexed integer
--- @param agent_prefix string  e.g. "[Claude]"
--- @param agent_suffix string|nil  e.g. "[🔧]"
--- @return PosHandle
function M.create_answer_region(buf, after_line_0_indexed, agent_prefix, agent_suffix)
    local lines = render_buffer.agent_header_lines(agent_prefix, agent_suffix)
    local insert_at = after_line_0_indexed + 1
    vim.api.nvim_buf_set_lines(buf, insert_at, insert_at, false, lines)
    -- Trailing blank is at insert_at + #lines - 1.
    return M.make_handle(buf, insert_at + #lines - 1)
end

--- Delete an answer region by inclusive 0-indexed line range.
function M.delete_answer(buf, line_start_0_indexed, line_end_0_indexed)
    vim.api.nvim_buf_set_lines(buf, line_start_0_indexed, line_end_0_indexed + 1, false, {})
end

--- Replace an answer region with a single blank separator. Returns a
--- handle anchored at the blank — the next answer's create_answer_region
--- should be called using this handle's resolved line.
function M.replace_answer(buf, line_start_0_indexed, line_end_0_indexed)
    vim.api.nvim_buf_set_lines(buf, line_start_0_indexed, line_end_0_indexed + 1, false, { "" })
    return M.make_handle(buf, line_start_0_indexed)
end

--- Replace the entire chat buffer with the given lines. Used by full-buffer
--- rewrites driven by pure transforms — the drill-in pipeline gathers ready
--- markers, strips them, and appends a quote block, then writes the result
--- back here in one shot.
function M.replace_all_lines(buf, lines)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

--- Replace the entire chat buffer after a pure definition-footnote transform.
function M.replace_all_lines_for_definition(buf, lines)
    M.replace_all_lines(buf, lines)
end

--- Append a section to an answer. The section is rendered via
--- render_buffer.render_section. If the line at `after_line_0_indexed`
--- is non-empty, a blank separator is inserted first so blocks don't
--- concatenate. Returns a PosHandle anchored at the line right after
--- the last appended line — the next streaming or section append goes
--- there.
--- @param buf integer
--- @param after_line_0_indexed integer
--- @param section table
--- @return PosHandle
function M.append_section_to_answer(buf, after_line_0_indexed, section)
    local prev_line = vim.api.nvim_buf_get_lines(buf, after_line_0_indexed, after_line_0_indexed + 1, false)[1] or ""
    local rendered = render_buffer.render_section(section)
    local insert_lines = {}
    if prev_line:match("%S") then
        table.insert(insert_lines, "")
    end
    for _, l in ipairs(rendered) do
        table.insert(insert_lines, l)
    end
    local insert_at = after_line_0_indexed + 1
    vim.api.nvim_buf_set_lines(buf, insert_at, insert_at, false, insert_lines)
    return M.make_handle(buf, insert_at + #insert_lines - 1)
end

-- ============================================================================
-- Streaming
-- ============================================================================
--
-- The streaming protocol receives chunks of text that may not align on
-- newline boundaries. We accumulate any trailing partial line in
-- handle._stream.pending and write complete lines to the buffer as they
-- arrive. The pending partial line is also written to the buffer as a
-- "ghost" trailing line so the user sees streaming progress in real
-- time; subsequent chunks overwrite that line.
--
-- finished_lines counts complete (newline-terminated) lines we've
-- already written, so we know how far the handle has advanced from its
-- original anchor.
-- ============================================================================

local function ensure_stream_state(handle)
    handle._stream = handle._stream or { pending = "", finished_lines = 0 }
    return handle._stream
end

--- Write a chunk of text at the position indicated by `handle`.
function M.stream_into(handle, chunk)
    if handle.dead then
        return
    end
    local s = ensure_stream_state(handle)
    s.pending = s.pending .. chunk
    -- Split on \n, plain mode. The last entry is the new pending text.
    local parts = vim.split(s.pending, "\n", { plain = true })
    s.pending = parts[#parts]
    table.remove(parts)
    local first_line = M.handle_line(handle)
    local write_at = first_line + s.finished_lines
    table.insert(parts, s.pending)
    vim.api.nvim_buf_set_lines(handle.buf, write_at, write_at + 1, false, parts)
    s.finished_lines = s.finished_lines + (#parts - 1)
end

--- Finalize the stream — currently just invalidates the handle. The
--- pending partial line is already in the buffer as a ghost.
function M.stream_finalize(handle)
    M.handle_invalidate(handle)
end

-- ============================================================================
-- Progress indicator
-- ============================================================================

--- Replace the line at the handle's position with `text`.
function M.set_progress_line(handle, text)
    if handle.dead then
        return
    end
    local line = M.handle_line(handle)
    vim.api.nvim_buf_set_lines(handle.buf, line, line + 1, false, { text or "" })
end

--- Delete `count` lines starting at the handle's position.
function M.clear_progress_lines(handle, count)
    if handle.dead then
        return
    end
    local line = M.handle_line(handle)
    vim.api.nvim_buf_set_lines(handle.buf, line, line + count, false, {})
end

-- ============================================================================
-- Cancellation cleanup
-- ============================================================================

--- Delete `n` lines starting at the given 0-indexed line.
function M.delete_lines_after(buf, line_0_indexed, n)
    vim.api.nvim_buf_set_lines(buf, line_0_indexed, line_0_indexed + n, false, {})

codex
One risk area is event coverage: the controller only refreshes on its existing cursor movement hook, so I’m verifying whether that is inherited behavior or a regression relative to the issue’s “while cursor is inside span” contract.
exec
/bin/zsh -lc "git show 35fee214c0dcecaa44d4017e4d37ffa3d883571c:lua/parley/skills/review/diag_display.lua | sed -n '1,260p'" in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc 'rg -n "#175|anchor-only|CursorMovedI|CursorMoved" workshop/issues lua tests atlas' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
workshop/issues/000176-footnote-diagnosis-centered-float.md:27:  span, preserving #175's anchor-only trigger.
lua/parley/skills/review/diag_display.lua:218:                vim.api.nvim_create_autocmd("CursorMoved", {
tests/integration/review_diag_display_spec.lua:127:        vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
tests/integration/review_diag_display_spec.lua:131:        vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
tests/integration/review_diag_display_spec.lua:159:        vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
tests/integration/review_diag_display_spec.lua:163:        vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })

 succeeded in 0ms:
-- diag_display.lua — inline display of Parley diagnostics (#133 M6, #173).
--
-- Controls how parley's review explanations render, scoped to parley's OWN
-- diagnostic namespace (never touches the user's LSP / global diagnostics).
-- Default ON: a custom diagnostic handler renders text-column virtual lines for
-- the cursor's current diagnostic region, so long wrapped prose doesn't hide
-- messages behind stock virtual-lines column indentation. `:ParleyShowDiagnostics`
-- toggles it.

local M = {}

M.enabled = true -- default on (cursor-region auto-show)

local HANDLER_NAME = "parley/virtual_lines"
local DISPLAY_NS = "parley_diagnostic_virtual_lines"
local DISPLAY_AUGROUP = "parley_diagnostic_virtual_lines"
local HEADER_HL = "ParleyDiagnosticVirtualLineHeader"
local MESSAGE_HL = "ParleyDiagnosticVirtualLine"
local DISPLAY_COL = 2

local display_ns_id
local display_augroup

-- Parley's review diagnostic namespace — single-sourced from skill_render (which
-- owns the namespace) so the identity isn't a duplicated literal (#133 M6 review).
local function ns()
    return require("parley.skill_render").diag_namespace()
end

local function ensure_display()
    if not display_ns_id then
        display_ns_id = vim.api.nvim_create_namespace(DISPLAY_NS)
    end
    if not display_augroup then
        display_augroup = vim.api.nvim_create_augroup(DISPLAY_AUGROUP, { clear = true })
    end
    vim.api.nvim_set_hl(0, HEADER_HL, { link = "DiagnosticInfo" })
    vim.api.nvim_set_hl(0, MESSAGE_HL, { link = "DiagnosticFloatingInfo" })
end

local function clear(buf)
    ensure_display()
    if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
        pcall(vim.api.nvim_clear_autocmds, { group = display_augroup, buffer = buf })
    end
end

local function current_pos_for(buf)
    if vim.api.nvim_get_current_buf() ~= buf then
        return nil
    end
    local pos = vim.api.nvim_win_get_cursor(0)
    return pos[1] - 1, pos[2]
end

local function diagnostic_message_lines(diagnostic)
    local lines = {}
    for _, line in ipairs(vim.split(tostring(diagnostic.message or ""), "\n", { plain = true })) do
        table.insert(lines, { { line ~= "" and line or " ", MESSAGE_HL } })
    end
    if #lines == 0 then
        table.insert(lines, { { " ", MESSAGE_HL } })
    end
    return lines
end

local function diagnostic_contains_line(diagnostic, line)
    local start_line = diagnostic.lnum or 0
    local end_line = diagnostic.end_lnum or start_line
    return line >= start_line and line <= end_line
end

local function diagnostic_contains_position(diagnostic, line, col)
    if not diagnostic_contains_line(diagnostic, line) then
        return false
    end
    local start_line = diagnostic.lnum or 0
    local end_line = diagnostic.end_lnum or start_line
    if line == start_line and col < (diagnostic.col or 0) then
        return false
    end
    if line == end_line and col >= (diagnostic.end_col or diagnostic.col or 0) then
        return false
    end
    return true
end

local function diagnostic_visible_at(diagnostic, line, col)
    if diagnostic.source == "parley-footnote" then
        return diagnostic_contains_position(diagnostic, line, col)
    end
    return diagnostic_contains_line(diagnostic, line)
end

local function render(buf, diagnostics, current_line_only)
    ensure_display()
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)

    local line, col
    if current_line_only then
        line, col = current_pos_for(buf)
    end
    if current_line_only and not line then
        return
    end

    local by_line = {}
    for _, diagnostic in ipairs(diagnostics or {}) do
        if not current_line_only or diagnostic_visible_at(diagnostic, line, col) then
            by_line[diagnostic.lnum] = by_line[diagnostic.lnum] or {}
            table.insert(by_line[diagnostic.lnum], diagnostic)
        end
    end

    for lnum, line_diagnostics in pairs(by_line) do
        table.sort(line_diagnostics, function(a, b)
            return (a.col or 0) < (b.col or 0)
        end)
        local virt_lines = { { { "Diagnostics:", HEADER_HL } } }
        for _, diagnostic in ipairs(line_diagnostics) do
            vim.list_extend(virt_lines, diagnostic_message_lines(diagnostic))
        end
        vim.api.nvim_buf_set_extmark(buf, display_ns_id, lnum, DISPLAY_COL, {
            virt_lines = virt_lines,
            virt_lines_above = false,
        })
    end
end

local function register_handler()
    ensure_display()
    vim.diagnostic.handlers[HANDLER_NAME] = {
        show = function(namespace, bufnr, diagnostics, opts)
            if namespace ~= ns() then
                return
            end
            bufnr = vim._resolve_bufnr(bufnr)
            local handler_opts = opts and opts[HANDLER_NAME] or {}
            local current_line_only = handler_opts.current_line == true
            clear(bufnr)
            if current_line_only then
                vim.api.nvim_create_autocmd("CursorMoved", {
                    buffer = bufnr,
                    group = display_augroup,
                    callback = function()
                        render(bufnr, diagnostics, true)
                    end,
                })
            end
            render(bufnr, diagnostics, current_line_only)
        end,
        hide = function(namespace, bufnr)
            if namespace ~= ns() then
                return
            end
            clear(vim._resolve_bufnr(bufnr))
        end,
    }
end

function M.refresh(buf)
    if not M.enabled then
        return
    end
    buf = buf or vim.api.nvim_get_current_buf()
    render(buf, vim.diagnostic.get(buf, { namespace = ns() }), true)
end

--- Apply the inline-display config for parley's review namespace.
--- @param on boolean
function M.set(on)
    M.enabled = on and true or false
    register_handler()
    vim.diagnostic.config({
        [HANDLER_NAME] = M.enabled and { current_line = true } or false,
        virtual_lines = false,
        virtual_text = false,
    }, ns())
    if M.enabled then
        M.refresh()
    else
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            clear(buf)
        end
    end
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

exec
/bin/zsh -lc 'git log --oneline --decorate -n 12 -- workshop/issues lua/parley/skills/review/diag_display.lua tests/integration/review_diag_display_spec.lua' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
d9f4d64 (HEAD -> 000176-footnote-diagnosis-centered-float) #176: show footnote diagnoses in centered float
35fee21 (origin/main, origin/HEAD, main) issue-sync: update issues
ac9bde4 issue-sync: update issues
0764006 archive completed issues to history
c3d71ba (origin/000175-footnote-diagnosis-anchor-span) #175: close footnote diagnosis anchor scoping
8ad0b0e #175: scope footnote diagnoses to anchor span
cf515a4 issue-sync: update issues
276af01 issue-sync: update issues
430cd6d archive completed issues to history
bba9aa8 (origin/000174-diagnostic-virtual-lines-textcol) #174: close diagnostic virtual line alignment
af014f9 #174: align diagnostic virtual lines to text column
8c35ad2 issue-sync: update issues

exec
/bin/zsh -lc "nl -ba lua/parley/skills/review/diag_display.lua | sed -n '1,260p' && nl -ba tests/integration/review_diag_display_spec.lua | sed -n '1,220p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
     1	-- diag_display.lua — inline display of Parley diagnostics (#133 M6, #173).
     2	--
     3	-- Controls how parley's review explanations render, scoped to parley's OWN
     4	-- diagnostic namespace (never touches the user's LSP / global diagnostics).
     5	-- Default ON: a custom diagnostic handler renders text-column virtual lines for
     6	-- the cursor's current diagnostic region, so long wrapped prose doesn't hide
     7	-- messages behind stock virtual-lines column indentation. `:ParleyShowDiagnostics`
     8	-- toggles it.
     9	
    10	local M = {}
    11	
    12	M.enabled = true -- default on (cursor-region auto-show)
    13	
    14	local HANDLER_NAME = "parley/virtual_lines"
    15	local DISPLAY_NS = "parley_diagnostic_virtual_lines"
    16	local DISPLAY_AUGROUP = "parley_diagnostic_virtual_lines"
    17	local HEADER_HL = "ParleyDiagnosticVirtualLineHeader"
    18	local MESSAGE_HL = "ParleyDiagnosticVirtualLine"
    19	local DISPLAY_COL = 2
    20	
    21	local display_ns_id
    22	local display_augroup
    23	local float_win
    24	local float_buf
    25	
    26	-- Parley's review diagnostic namespace — single-sourced from skill_render (which
    27	-- owns the namespace) so the identity isn't a duplicated literal (#133 M6 review).
    28	local function ns()
    29	    return require("parley.skill_render").diag_namespace()
    30	end
    31	
    32	local function close_float()
    33	    if float_win and vim.api.nvim_win_is_valid(float_win) then
    34	        pcall(vim.api.nvim_win_close, float_win, true)
    35	    end
    36	    if float_buf and vim.api.nvim_buf_is_valid(float_buf) then
    37	        pcall(vim.api.nvim_buf_delete, float_buf, { force = true })
    38	    end
    39	    float_win = nil
    40	    float_buf = nil
    41	end
    42	
    43	local function ensure_display()
    44	    if not display_ns_id then
    45	        display_ns_id = vim.api.nvim_create_namespace(DISPLAY_NS)
    46	    end
    47	    if not display_augroup then
    48	        display_augroup = vim.api.nvim_create_augroup(DISPLAY_AUGROUP, { clear = true })
    49	    end
    50	    vim.api.nvim_set_hl(0, HEADER_HL, { link = "DiagnosticInfo" })
    51	    vim.api.nvim_set_hl(0, MESSAGE_HL, { link = "DiagnosticFloatingInfo" })
    52	end
    53	
    54	local function clear(buf)
    55	    ensure_display()
    56	    close_float()
    57	    if vim.api.nvim_buf_is_valid(buf) then
    58	        vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
    59	        pcall(vim.api.nvim_clear_autocmds, { group = display_augroup, buffer = buf })
    60	    end
    61	end
    62	
    63	local function current_pos_for(buf)
    64	    if vim.api.nvim_get_current_buf() ~= buf then
    65	        return nil
    66	    end
    67	    local pos = vim.api.nvim_win_get_cursor(0)
    68	    return pos[1] - 1, pos[2]
    69	end
    70	
    71	local function diagnostic_message_lines(diagnostic)
    72	    local lines = {}
    73	    for _, line in ipairs(vim.split(tostring(diagnostic.message or ""), "\n", { plain = true })) do
    74	        table.insert(lines, { { line ~= "" and line or " ", MESSAGE_HL } })
    75	    end
    76	    if #lines == 0 then
    77	        table.insert(lines, { { " ", MESSAGE_HL } })
    78	    end
    79	    return lines
    80	end
    81	
    82	local function diagnostic_float_lines(diagnostics)
    83	    local lines = { "Diagnostics:" }
    84	    for _, diagnostic in ipairs(diagnostics or {}) do
    85	        for _, line in ipairs(vim.split(tostring(diagnostic.message or ""), "\n", { plain = true })) do
    86	            table.insert(lines, line ~= "" and line or " ")
    87	        end
    88	    end
    89	    return lines
    90	end
    91	
    92	local function diagnostic_contains_line(diagnostic, line)
    93	    local start_line = diagnostic.lnum or 0
    94	    local end_line = diagnostic.end_lnum or start_line
    95	    return line >= start_line and line <= end_line
    96	end
    97	
    98	local function diagnostic_contains_position(diagnostic, line, col)
    99	    if not diagnostic_contains_line(diagnostic, line) then
   100	        return false
   101	    end
   102	    local start_line = diagnostic.lnum or 0
   103	    local end_line = diagnostic.end_lnum or start_line
   104	    if line == start_line and col < (diagnostic.col or 0) then
   105	        return false
   106	    end
   107	    if line == end_line and col >= (diagnostic.end_col or diagnostic.col or 0) then
   108	        return false
   109	    end
   110	    return true
   111	end
   112	
   113	local function diagnostic_visible_at(diagnostic, line, col)
   114	    if diagnostic.source == "parley-footnote" then
   115	        return diagnostic_contains_position(diagnostic, line, col)
   116	    end
   117	    return diagnostic_contains_line(diagnostic, line)
   118	end
   119	
   120	local function float_config(win, line_count)
   121	    local win_width = vim.api.nvim_win_get_width(win)
   122	    local win_height = vim.api.nvim_win_get_height(win)
   123	    local width = math.max(1, math.floor(win_width * 0.8))
   124	    local height = math.max(1, math.min(line_count, math.max(1, win_height - 2)))
   125	    return {
   126	        relative = "win",
   127	        win = win,
   128	        width = width,
   129	        height = height,
   130	        row = math.min(vim.fn.winline(), math.max(0, win_height - height)),
   131	        col = math.floor((win_width - width) / 2),
   132	        style = "minimal",
   133	        border = "rounded",
   134	        focusable = false,
   135	        title = { { "Diagnostics", HEADER_HL } },
   136	        title_pos = "left",
   137	    }
   138	end
   139	
   140	local function show_float(diagnostics)
   141	    close_float()
   142	    if #diagnostics == 0 then
   143	        return
   144	    end
   145	    local win = vim.api.nvim_get_current_win()
   146	    local lines = diagnostic_float_lines(diagnostics)
   147	    float_buf = vim.api.nvim_create_buf(false, true)
   148	    vim.api.nvim_buf_set_option(float_buf, "buftype", "nofile")
   149	    vim.api.nvim_buf_set_option(float_buf, "bufhidden", "wipe")
   150	    vim.api.nvim_buf_set_option(float_buf, "modifiable", true)
   151	    require("parley.buffer_edit").replace_all_lines(float_buf, lines)
   152	    vim.api.nvim_buf_set_option(float_buf, "modifiable", false)
   153	    float_win = vim.api.nvim_open_win(float_buf, false, float_config(win, #lines))
   154	    vim.api.nvim_win_set_option(float_win, "wrap", true)
   155	    vim.api.nvim_win_set_option(float_win, "winhl", "NormalFloat:NormalFloat,FloatBorder:FloatBorder")
   156	end
   157	
   158	local function render(buf, diagnostics, current_line_only)
   159	    ensure_display()
   160	    if not vim.api.nvim_buf_is_valid(buf) then
   161	        return
   162	    end
   163	    vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
   164	    close_float()
   165	
   166	    local line, col
   167	    if current_line_only then
   168	        line, col = current_pos_for(buf)
   169	    end
   170	    if current_line_only and not line then
   171	        return
   172	    end
   173	
   174	    local by_line = {}
   175	    local footnote_diagnostics = {}
   176	    for _, diagnostic in ipairs(diagnostics or {}) do
   177	        if not current_line_only or diagnostic_visible_at(diagnostic, line, col) then
   178	            if diagnostic.source == "parley-footnote" then
   179	                table.insert(footnote_diagnostics, diagnostic)
   180	            else
   181	                by_line[diagnostic.lnum] = by_line[diagnostic.lnum] or {}
   182	                table.insert(by_line[diagnostic.lnum], diagnostic)
   183	            end
   184	        end
   185	    end
   186	    table.sort(footnote_diagnostics, function(a, b)
   187	        return (a.col or 0) < (b.col or 0)
   188	    end)
   189	    show_float(footnote_diagnostics)
   190	
   191	    for lnum, line_diagnostics in pairs(by_line) do
   192	        table.sort(line_diagnostics, function(a, b)
   193	            return (a.col or 0) < (b.col or 0)
   194	        end)
   195	        local virt_lines = { { { "Diagnostics:", HEADER_HL } } }
   196	        for _, diagnostic in ipairs(line_diagnostics) do
   197	            vim.list_extend(virt_lines, diagnostic_message_lines(diagnostic))
   198	        end
   199	        vim.api.nvim_buf_set_extmark(buf, display_ns_id, lnum, DISPLAY_COL, {
   200	            virt_lines = virt_lines,
   201	            virt_lines_above = false,
   202	        })
   203	    end
   204	end
   205	
   206	local function register_handler()
   207	    ensure_display()
   208	    vim.diagnostic.handlers[HANDLER_NAME] = {
   209	        show = function(namespace, bufnr, diagnostics, opts)
   210	            if namespace ~= ns() then
   211	                return
   212	            end
   213	            bufnr = vim._resolve_bufnr(bufnr)
   214	            local handler_opts = opts and opts[HANDLER_NAME] or {}
   215	            local current_line_only = handler_opts.current_line == true
   216	            clear(bufnr)
   217	            if current_line_only then
   218	                vim.api.nvim_create_autocmd("CursorMoved", {
   219	                    buffer = bufnr,
   220	                    group = display_augroup,
   221	                    callback = function()
   222	                        render(bufnr, diagnostics, true)
   223	                    end,
   224	                })
   225	            end
   226	            render(bufnr, diagnostics, current_line_only)
   227	        end,
   228	        hide = function(namespace, bufnr)
   229	            if namespace ~= ns() then
   230	                return
   231	            end
   232	            clear(vim._resolve_bufnr(bufnr))
   233	        end,
   234	    }
   235	end
   236	
   237	function M.refresh(buf)
   238	    if not M.enabled then
   239	        return
   240	    end
   241	    buf = buf or vim.api.nvim_get_current_buf()
   242	    render(buf, vim.diagnostic.get(buf, { namespace = ns() }), true)
   243	end
   244	
   245	--- Apply the inline-display config for parley's review namespace.
   246	--- @param on boolean
   247	function M.set(on)
   248	    M.enabled = on and true or false
   249	    register_handler()
   250	    vim.diagnostic.config({
   251	        [HANDLER_NAME] = M.enabled and { current_line = true } or false,
   252	        virtual_lines = false,
   253	        virtual_text = false,
   254	    }, ns())
   255	    if M.enabled then
   256	        M.refresh()
   257	    else
   258	        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
   259	            clear(buf)
   260	        end
     1	-- Integration tests for the review-diagnostic inline display toggle (#133 M6).
     2	
     3	local dd = require("parley.skills.review.diag_display")
     4	
     5	local function ns_cfg()
     6	    return vim.diagnostic.config(nil, require("parley.skill_render").diag_namespace())
     7	end
     8	
     9	local function display_marks(buf)
    10	    local display_ns = vim.api.nvim_create_namespace("parley_diagnostic_virtual_lines")
    11	    return vim.api.nvim_buf_get_extmarks(buf, display_ns, 0, -1, { details = true })
    12	end
    13	
    14	local function diagnostic_floats()
    15	    local floats = {}
    16	    for _, win in ipairs(vim.api.nvim_list_wins()) do
    17	        local cfg = vim.api.nvim_win_get_config(win)
    18	        if cfg.relative ~= "" and cfg.focusable == false and cfg.title and cfg.title[1][1] == "Diagnostics" then
    19	            table.insert(floats, { win = win, config = cfg, buf = vim.api.nvim_win_get_buf(win) })
    20	        end
    21	    end
    22	    return floats
    23	end
    24	
    25	describe("review.diag_display", function()
    26	    after_each(function()
    27	        dd.set(true) -- restore default for other specs
    28	        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    29	            if vim.api.nvim_buf_is_valid(buf) then
    30	                pcall(vim.diagnostic.reset, require("parley.skill_render").diag_namespace(), buf)
    31	            end
    32	        end
    33	    end)
    34	
    35	    it("toggles the enabled state", function()
    36	        dd.set(true)
    37	        assert.is_true(dd.is_enabled())
    38	        assert.is_false(dd.toggle())
    39	        assert.is_false(dd.is_enabled())
    40	        assert.is_true(dd.toggle())
    41	        assert.is_true(dd.is_enabled())
    42	    end)
    43	
    44	    it("configures Parley's custom current-line display on its namespace when on; off when disabled", function()
    45	        dd.set(true)
    46	        local on = ns_cfg()
    47	        assert.is_false(on.virtual_lines) -- Parley owns its virtual-lines renderer.
    48	        assert.is_truthy(on["parley/virtual_lines"])
    49	        assert.is_false(on.virtual_text) -- inline single-line is never used
    50	        dd.set(false)
    51	        assert.is_false(ns_cfg()["parley/virtual_lines"])
    52	    end)
    53	
    54	    it("renders footnote diagnostics in a centered non-focusable float without moving the diagnostic span", function()
    55	        local skill_render = require("parley.skill_render")
    56	        local diag_ns = skill_render.diag_namespace()
    57	        local buf = vim.api.nvim_create_buf(false, true)
    58	        vim.api.nvim_set_current_buf(buf)
    59	        vim.api.nvim_win_set_width(0, 100)
    60	        local parent_width = vim.api.nvim_win_get_width(0)
    61	        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    62	            string.rep("x", 120) .. " ACOS[^acos]",
    63	        })
    64	        vim.api.nvim_win_set_cursor(0, { 1, 122 })
    65	
    66	        dd.set(true)
    67	        vim.diagnostic.set(diag_ns, buf, { {
    68	            lnum = 0,
    69	            col = 121,
    70	            end_lnum = 0,
    71	            end_col = 132,
    72	            message = "ACOS — Advertising Cost of Sales.",
    73	            severity = vim.diagnostic.severity.INFO,
    74	            source = "parley-footnote",
    75	        } })
    76	
    77	        vim.wait(100, function()
    78	            return #diagnostic_floats() == 1
    79	        end)
    80	
    81	        assert.are.equal(0, #display_marks(buf))
    82	        local floats = diagnostic_floats()
    83	        assert.are.equal(1, #floats)
    84	        local expected_width = math.max(1, math.floor(parent_width * 0.8))
    85	        assert.are.equal(expected_width, floats[1].config.width)
    86	        assert.are.equal(math.floor((parent_width - expected_width) / 2), floats[1].config.col)
    87	        assert.is_false(floats[1].config.focusable)
    88	        local lines = vim.api.nvim_buf_get_lines(floats[1].buf, 0, -1, false)
    89	        assert.are.equal("Diagnostics:", lines[1])
    90	        assert.are.equal("ACOS — Advertising Cost of Sales.", lines[2])
    91	
    92	        local diagnostics = vim.diagnostic.get(buf, { namespace = diag_ns })
    93	        assert.are.equal(1, #diagnostics)
    94	        assert.are.equal(0, diagnostics[1].lnum)
    95	        assert.are.equal(121, diagnostics[1].col)
    96	        assert.are.equal(0, diagnostics[1].end_lnum)
    97	        assert.are.equal(132, diagnostics[1].end_col)
    98	
    99	        dd.set(false)
   100	        assert.are.equal(0, #display_marks(buf))
   101	        assert.are.equal(0, #diagnostic_floats())
   102	        assert.are.equal(1, #vim.diagnostic.get(buf, { namespace = diag_ns }))
   103	    end)
   104	
   105	    it("shows footnote diagnostics only while the cursor is inside the anchor span", function()
   106	        local skill_render = require("parley.skill_render")
   107	        local diag_ns = skill_render.diag_namespace()
   108	        local buf = vim.api.nvim_create_buf(false, true)
   109	        vim.api.nvim_set_current_buf(buf)
   110	        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
   111	            'before ACOS[^acos] after the anchor on the same line',
   112	        })
   113	
   114	        dd.set(true)
   115	        vim.diagnostic.set(diag_ns, buf, { {
   116	            lnum = 0,
   117	            col = 7,
   118	            end_lnum = 0,
   119	            end_col = 18,
   120	            message = "ACOS — Advertising Cost of Sales.",
   121	            severity = vim.diagnostic.severity.INFO,
   122	            source = "parley-footnote",
   123	        } })
   124	        assert.are.equal(0, #display_marks(buf), "cursor starts before the footnote anchor")
   125	
   126	        vim.api.nvim_win_set_cursor(0, { 1, 8 })
   127	        vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
   128	        assert.are.equal(1, #diagnostic_floats(), "cursor inside the footnote anchor should show diagnosis")
   129	
   130	        vim.api.nvim_win_set_cursor(0, { 1, 25 })
   131	        vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
   132	        assert.are.equal(0, #diagnostic_floats(), "same line outside the anchor should hide diagnosis")
   133	    end)
   134	
   135	    it("keeps a multi-line diagnostic visible anywhere inside its span", function()
   136	        local skill_render = require("parley.skill_render")
   137	        local diag_ns = skill_render.diag_namespace()
   138	        local buf = vim.api.nvim_create_buf(false, true)
   139	        vim.api.nvim_set_current_buf(buf)
   140	        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
   141	            "edited line one",
   142	            "edited line two",
   143	            "edited line three",
   144	        })
   145	
   146	        dd.set(true)
   147	        vim.diagnostic.set(diag_ns, buf, { {
   148	            lnum = 0,
   149	            col = 0,
   150	            end_lnum = 2,
   151	            end_col = 17,
   152	            message = "review explanation",
   153	            severity = vim.diagnostic.severity.INFO,
   154	            source = "parley-skill",
   155	        } })
   156	        assert.are.equal(1, #display_marks(buf))
   157	
   158	        vim.api.nvim_win_set_cursor(0, { 2, 0 })
   159	        vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
   160	        assert.are.equal(1, #display_marks(buf), "span diagnostic should show on middle line")
   161	
   162	        vim.api.nvim_win_set_cursor(0, { 3, 0 })
   163	        vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
   164	        assert.are.equal(1, #display_marks(buf), "span diagnostic should show on final line")
   165	    end)
   166	end)

codex
I haven’t found a blocker yet. I’m running the focused display spec to validate the changed behavior in this checkout, then I’ll do a final pass for docs/atlas and architecture notes.
exec
/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"' in /Users/xianxu/workspace/parley.nvim
 succeeded in 1481ms:

Parley.nvim: Failed to open file for writing: /Users/xianxu/.local/share/nvim/parley/persisted/state.jsonScheduling: tests/integration/review_diag_display_spec.lua

========================================	
Testing: 	/Users/xianxu/workspace/parley.nvim/tests/integration/review_diag_display_spec.lua	
[32mSuccess[0m	||	review.diag_display toggles the enabled state	
[32mSuccess[0m	||	review.diag_display configures Parley's custom current-line display on its namespace when on; off when disabled	
[32mSuccess[0m	||	review.diag_display renders footnote diagnostics in a centered non-focusable float without moving the diagnostic span	
[32mSuccess[0m	||	review.diag_display shows footnote diagnostics only while the cursor is inside the anchor span	
[32mSuccess[0m	||	review.diag_display keeps a multi-line diagnostic visible anywhere inside its span	
	
[32mSuccess: [0m	5	
[31mFailed : [0m	0	
[31mErrors : [0m	0	
========================================	
]111
codex
The focused spec passes in this environment. There are startup warnings from the local Neovim config about external state paths, but the Plenary assertions completed with 5 successes and 0 failures/errors.
exec
/bin/zsh -lc 'git diff --check 35fee214c0dcecaa44d4017e4d37ffa3d883571c..HEAD' in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc 'git diff 35fee214c0dcecaa44d4017e4d37ffa3d883571c..HEAD -- atlas/chat/inline_define.md atlas/modes/review.md README.md' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
 succeeded in 0ms:
diff --git a/atlas/chat/inline_define.md b/atlas/chat/inline_define.md
index dbd3461..d40dec6 100644
--- a/atlas/chat/inline_define.md
+++ b/atlas/chat/inline_define.md
@@ -41,9 +41,9 @@ rehydrates persisted managed footnotes in all markdown buffers.
    inline `term[^id]` spans (`define.format_definition` →
    `skill_render.format_diagnostic_message`) on the `parley_skill` namespace;
    **(d)** records the undo/redo projection states.
-   `diag_display`'s Parley-owned text-column virtual-line display reveals the
-   diagnostic when the cursor is on the term/footnote anchor span. A
-   no-`emit_definition` response leaves no footnote reference/footer.
+   `diag_display` opens a centered, non-focusable diagnostic float when the
+   cursor is on the term/footnote anchor span. A no-`emit_definition` response
+   leaves no footnote reference/footer.
 
 ## Undo (`u`) — reuses review's projection
 
@@ -126,9 +126,8 @@ tool-call args (`result.calls[1].input`), read in `on_done`.
 - `skill_render.refresh_footnote_diagnostics` owns only diagnostics tagged
   `parley-footnote` and preserves other `parley_skill` diagnostics, so review
   diagnostics are not cleared by markdown footnote refresh.
-- A footnote diagnostic's Parley virtual-line block auto-hides when the cursor
-  leaves its term/footnote anchor span. The footnote persists in the file if
-  saved.
+- A footnote diagnostic's Parley float auto-hides when the cursor leaves its
+  term/footnote anchor span. The footnote persists in the file if saved.
 
 ## Key files
 
diff --git a/atlas/modes/review.md b/atlas/modes/review.md
index 23dce42..6cccd40 100644
--- a/atlas/modes/review.md
+++ b/atlas/modes/review.md
@@ -173,9 +173,9 @@ built-in `]d`/`[d` (jump) and `<C-W>d` (float, wraps) still work on these
 diagnostics because the underlying diagnostic spans remain unchanged. Composes
 with M5 — re-renders on undo/redo.
 
-The same controller also renders managed footnote diagnostics; those are tighter
-than review diagnostics and show only while the cursor is inside the
-term/`[^footnote]` diagnostic span.
+The same controller also renders managed footnote diagnostics; those use a
+centered non-focusable float instead of virtual lines, and show only while the
+cursor is inside the term/`[^footnote]` diagnostic span.
 
 ## Progress bar (#133 M7)
 

exec
/bin/zsh -lc "sed -n '1,220p' README.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
<!-- panvimdoc-ignore-start -->

<a href="https://github.com/xianxu/parley.nvim/blob/main/LICENSE"><img alt="GitHub" src="https://img.shields.io/github/license/xianxu/parley.nvim"></a>

# Parley.nvim

<!-- panvimdoc-ignore-end -->

Parley started as a Neovim chat notebook for LLM conversations. It's created to help me research on a topic with the help with many different agents. A side goal of Parley is really a test bed for me to play with agentic coding workflow. This leading me to see a future of **markdown as state, nvim/`coding agent` as human operator interface, the beginning of future operating system for startups**. 

There are just many different ways user can leverage it. With Parley, you have all the power of Neovim at your fingertips in your LLM chat, thus making comprehensive research easier. All your chat history also lives in plain markdown files, you can easily search through using local tools. You can even direct your coding agent to act according to the "brainstorming" chat thread you had with other agents, for example. The possibilities seem endless.

Compared to stock chatbot, Parley supports a "tree of chats", essentially allowing user to branch of some side topic, in a linked but different file. This way, information is always organized, matching how human research and learn a topic.

The philosophy behind Parley is Keep Things Simple, and Local, and a bit of Unix:
- Keep chats as plain Markdown files you can edit any place
- The chat transcript file has the full state of LLM chat
- Highly configurable but also have good default out-of-box
- Keep the workflow keyboard-first and fast
- Keep behavior predictable across different chat providers
- Leverage Neovim, and all its goodies
- Minimal dependencies, install and it works, all you need is your API keys

Despite of such simple interface, it's very powerful, sometimes more so than official app
- You can use "any" LLM providers, mix in the same conversation input from many different LLMs
- Your chat transcript can be as complex as a tree with branches, to allow you to explore into different directions, without being forced into a linear conversation
- You can jump easily between such tree branches
- You can access your private local file, and private Google Drive file through oauth
- You can edit anything in the transcript, including LLM responses, which presumably would influence the agent's future responses, a soft prompt engineering. You are constructing an understanding of a topic together with the help of LLMs
- All you chat history in one place locally, you can search and further refine with whatever tools you want
- Tweak system prompts to best suit your needs
- Have many different chat threads active in different vim buffers, terminals etc., no limits
- Easily switch between different chat threads, instant search experience with Chat Finder <C-g>f anywhere in Neovim
- Also a good learning tool for LLM interactions, e.g. in raw request/response modes, you see all request/response details
- New LLMs support web search and grounding, you can easily enable or disable if you want it to be faster
- Publish your chat as markdown or HTML, for blogging or sharing, e.g. [a chat about async programming](https://xianxu.github.io/2025/05/12/conversation_around_concurrent_programming_models.html)
- Share your brainstorming transcripts with your coding agents to start materializing it!

## Quick Install

Optional dependencies:
- [`lualine.nvim`](https://github.com/nvim-lualine/lualine.nvim) for status line integration. Not missing much if not available.
- `curl` for oauth and fetching web content.
- [`pandoc`](https://pandoc.org/) for exporting non-chat markdown files to HTML (`<C-g>eh`). Install with `brew install pandoc`.

Example with `lazy.nvim`

```lua
{
    "xianxu/parley.nvim",
    config = function()
        require("parley").setup({
            -- supply at least one
            api_keys = {
                -- openai = "sk-...", -- or set env vars and fetch with os.getenv
                openai = os.getenv("OPENAI_API_KEY"),
                -- anthropic = ...
                -- googleai = ...
                -- ollama = ...
            },
        })
    end,
}
```

A bit safer, macOS Keychain example:

1. First save API keys to Keychain (replace `your_username` and key values):

```bash
security add-generic-password -a "your_username" -s "OPENAI_API_KEY" -w "sk-..." -U
...
```

2. Then fetch keys from Keychain in `api_keys`:

```lua
{
    "xianxu/parley.nvim",
    config = function()
        require("parley").setup({
            -- supply at least one
            api_keys = {
                openai = { "security", "find-generic-password", "-a", "your_username", "-s", "OPENAI_API_KEY", "-w" },
                -- anthropic = ...
                -- googleai = ...
                -- ollama = ...
            },
        })
    end,
}
```

Notes:
- Configure at least one provider key.
- `api_keys` values can be strings or shell commands (for password managers/Keychain) resolve to a string.

## First 60 Seconds

1. Run `:ParleyChatNew` (default shortcut: `<C-g>c`) to create a new chat.
2. Type your question after `💬:`, no need for anything else. `Topic: ?` will be automatically filled with summary of your question.
3. Run `:ParleyChatRespond` (default shortcut: `<C-g><C-g>`) with mouse on the question line.
4. Get response from the agent after `🤖:`, streaming in real time.

A Parley chat is a normal markdown file with a header and alternating `💬:` / `🤖:` blocks.

## Basic Commands

Most-used defaults:

**Global**
- `<C-g>c` new chat - global hotkey
- `<C-g>f` find chat - global hotkey

**In Chat Buffer**
- `<C-g>?` show key bindings
- `<C-g><C-g>` respond
- `<M-CR>` respond (normal/insert); **visual-select a phrase + `<M-CR>`** → inline term definition — adds a markdown footnote reference/footer and shows a concise grey pop-under, honoring `:ToggleWebSearch` for unfamiliar terms
- `<C-g>G` respond all
- `<C-g>x` stop
- `<C-g>t` chat outline
- `<C-g>a` change agent
- `<C-g>P` next system prompt
- `<C-g>s` skill picker (review, voice-apply, etc.)
- `<C-g>l` toggle follow cursor
- `<C-g>i` to insert a fork in the chat tree, can be inline or standalone
- `gf` smart go-to-file: on an ariadne artifact ref (`ariadne#11`, `#15 M4`, `pair#84`) resolves it and jumps (family picker when it resolves to many); on a plain path, Vim's native `gf`

**Corresponding commands**
- `:ParleyChatNew` create a new chat
- `:ParleyChatFinder` chat finder
- `:ParleyChatRespond` answer current question
- `:ParleyChatRespondAll` regenerate from start to cursor
- `:ParleyStop` stop running generation
- `:ParleyOutline` display questions in this buffer for navigation
- `:ParleyKeyBindings` show active Parley keyboard shortcuts
- `:ParleyAgent` switch agent
- `:ParleySystemPrompt` switch system prompt
- `:ParleyToggleFollowCursor` toggle live cursor-follow during streaming

## What Parley Supports

- Providers: OpenAI, Anthropic, Google AI, Ollama, OpenAI-compatible endpoints, and CLIProxyAPI.
  - parley can **manage a local `cliproxyapi`** for you — it renders the config from Lua and lazily starts/reuses/health-checks the proxy. `:ParleyProxy status|start|stop|restart|models <provider>|providers|login <provider>|update` (bare `:ParleyProxy` prints per-subcommand help). **On by default but dormant** — only acts when a cliproxyapi-provider agent runs, and reuses an existing proxy if one is up; a fresh machine needs `brew install cliproxyapi` + a one-time `:ParleyProxy login`. Set `cliproxy = { manage = false }` to opt out. See [atlas/providers/cliproxy-managed.md](atlas/providers/cliproxy-managed.md).
- File context with `@@path/to/file` and directory patterns.
- Web search toggle for supported providers.
- Outline navigation, highlighting.
- Export chat to markdown or HTML, for blogging, e.g. [a chat about async programming](https://xianxu.github.io/2025/05/12/conversation_around_concurrent_programming_models.html).
- Misc: notes, interview mode, raw mode, and export.

## Configuration Entry Points

Common options live in `setup()`:
- `api_keys`
- `chat_dir`
- `notes_dir`

Merge behavior in `setup(opts)`:
- `agents`, `system_prompts`, and `hooks` are merged by key/name, so you can override only selected entries.
- Most other top-level keys are replaced when provided (for example `chat_dir`, `chat_dirs`, `notes_dir`, `chat_template`, `raw_mode`, `highlight`, `chat_memory`, `providers`, `api_keys`).
- Practical rule: for non-merged tables, provide the full table you want, not just one nested field.
- Reference [lua/parley/config.lua](https://github.com/xianxu/parley.nvim/blob/main/lua/parley/config.lua) for full defaults and examples.

Chat storage roots:
- `chat_dir` is the primary writable root used for new chats.
- `chat_dirs` is an optional list of additional roots that Chat Finder, chat validation, and chat-aware commands will scan alongside `chat_dir`.
- `:ParleyChatDirs` opens a picker to add or remove chat roots at runtime.
- `:ParleyChatDirAdd {dir}` adds a root directly, with directory completion.
- `:ParleyChatDirRemove {dir}` removes a configured root directly.
- `:ParleyChatMove {dir}` moves the current chat to another registered chat root.
- The primary `chat_dir` cannot be removed at runtime.
- The default shortcut for chat-root management is `<C-g>h`.

For full defaults and examples, see [`lua/parley/config.lua`](lua/parley/config.lua).

## Detailed Docs (Atlas)

Advanced behavior is intentionally kept out of this README and documented in the atlas:

- Overview index: [`atlas/index.md`](atlas/index.md)

## Acknowledgement

Parley was adapted from [gp.nvim](https://github.com/Robitx/gp.nvim), but has since been largely redesigned and rewritten.

exec
/bin/zsh -lc "nl -ba README.md | sed -n '95,125p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
    95	- Configure at least one provider key.
    96	- `api_keys` values can be strings or shell commands (for password managers/Keychain) resolve to a string.
    97	
    98	## First 60 Seconds
    99	
   100	1. Run `:ParleyChatNew` (default shortcut: `<C-g>c`) to create a new chat.
   101	2. Type your question after `💬:`, no need for anything else. `Topic: ?` will be automatically filled with summary of your question.
   102	3. Run `:ParleyChatRespond` (default shortcut: `<C-g><C-g>`) with mouse on the question line.
   103	4. Get response from the agent after `🤖:`, streaming in real time.
   104	
   105	A Parley chat is a normal markdown file with a header and alternating `💬:` / `🤖:` blocks.
   106	
   107	## Basic Commands
   108	
   109	Most-used defaults:
   110	
   111	**Global**
   112	- `<C-g>c` new chat - global hotkey
   113	- `<C-g>f` find chat - global hotkey
   114	
   115	**In Chat Buffer**
   116	- `<C-g>?` show key bindings
   117	- `<C-g><C-g>` respond
   118	- `<M-CR>` respond (normal/insert); **visual-select a phrase + `<M-CR>`** → inline term definition — adds a markdown footnote reference/footer and shows a concise grey pop-under, honoring `:ToggleWebSearch` for unfamiliar terms
   119	- `<C-g>G` respond all
   120	- `<C-g>x` stop
   121	- `<C-g>t` chat outline
   122	- `<C-g>a` change agent
   123	- `<C-g>P` next system prompt
   124	- `<C-g>s` skill picker (review, voice-apply, etc.)
   125	- `<C-g>l` toggle follow cursor

codex
```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

Implementation matches the issue behavior in code and focused tests: footnote diagnostics now use a centered non-focusable float, review diagnostics stay on virtual lines, and atlas docs were updated. The remaining ship fix is documentation drift in `README.md`, which still describes the old inline definition display.

1. Strengths:
- [diag_display.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/skills/review/diag_display.lua:176) cleanly branches only `parley-footnote` diagnostics into the float path, preserving review virtual-line behavior.
- [diag_display.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/skills/review/diag_display.lua:120) keeps the 80% width and centered column math local and simple.
- [review_diag_display_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/integration/review_diag_display_spec.lua:54) pins the important regression points: no virtual-line extmark, non-focusable float, 80% width, centered column, and unchanged diagnostic span.
- Atlas updates cover the changed architectural behavior in both inline define and review mode docs.

2. Critical findings:
- None.

3. Important findings:
- [README.md](/Users/xianxu/workspace/parley.nvim/README.md:118) still says inline definition “shows a concise grey pop-under,” which is now stale after moving footnote diagnostics to a centered float. Fix the README wording to match the new centered diagnostic float behavior. Docs gate / ARCH-PURPOSE: the user-facing surface changed and the user-facing restatement was not updated.

4. Minor findings:
- None.

5. Test coverage notes:
- I ran `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"`: 5 successes, 0 failures/errors. Local Neovim startup emitted unrelated filesystem warnings, but the spec passed.
- I also ran `git diff --check 35fee214c0dcecaa44d4017e4d37ffa3d883571c..HEAD`: no whitespace errors.
- I did not rerun the full suite during review.

6. Architectural notes for upcoming work:
- ARCH-DRY: Pass. Display policy remains centralized in `diag_display.lua`.
- ARCH-PURE: Pass for this scope. The positioning math is small and deterministic; IO/UI calls remain in the display controller.
- ARCH-PURPOSE: Mostly pass, with the README drift above as the remaining consumer/documentation gap.

7. Plan revision recommendations:
- None; the issue Plan and Log match the delivered code.
tokens used
46,686
```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

Implementation matches the issue behavior in code and focused tests: footnote diagnostics now use a centered non-focusable float, review diagnostics stay on virtual lines, and atlas docs were updated. The remaining ship fix is documentation drift in `README.md`, which still describes the old inline definition display.

1. Strengths:
- [diag_display.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/skills/review/diag_display.lua:176) cleanly branches only `parley-footnote` diagnostics into the float path, preserving review virtual-line behavior.
- [diag_display.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/skills/review/diag_display.lua:120) keeps the 80% width and centered column math local and simple.
- [review_diag_display_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/integration/review_diag_display_spec.lua:54) pins the important regression points: no virtual-line extmark, non-focusable float, 80% width, centered column, and unchanged diagnostic span.
- Atlas updates cover the changed architectural behavior in both inline define and review mode docs.

2. Critical findings:
- None.

3. Important findings:
- [README.md](/Users/xianxu/workspace/parley.nvim/README.md:118) still says inline definition “shows a concise grey pop-under,” which is now stale after moving footnote diagnostics to a centered float. Fix the README wording to match the new centered diagnostic float behavior. Docs gate / ARCH-PURPOSE: the user-facing surface changed and the user-facing restatement was not updated.

4. Minor findings:
- None.

5. Test coverage notes:
- I ran `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"`: 5 successes, 0 failures/errors. Local Neovim startup emitted unrelated filesystem warnings, but the spec passed.
- I also ran `git diff --check 35fee214c0dcecaa44d4017e4d37ffa3d883571c..HEAD`: no whitespace errors.
- I did not rerun the full suite during review.

6. Architectural notes for upcoming work:
- ARCH-DRY: Pass. Display policy remains centralized in `diag_display.lua`.
- ARCH-PURE: Pass for this scope. The positioning math is small and deterministic; IO/UI calls remain in the display controller.
- ARCH-PURPOSE: Mostly pass, with the README drift above as the remaining consumer/documentation gap.

7. Plan revision recommendations:
- None; the issue Plan and Log match the delivered code.
