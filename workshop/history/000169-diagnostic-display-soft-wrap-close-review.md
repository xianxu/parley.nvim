# Boundary Review — parley.nvim#169 (whole-issue close)

| field | value |
|-------|-------|
| issue | 169 — diagnostic display should soft-wrap words |
| repo | parley.nvim |
| issue file | workshop/issues/000169-diagnostic-display-soft-wrap.md |
| boundary | whole-issue close |
| milestone | — |
| window | 895bd1448552f969de91cd836cd5ed67a9cb7921..HEAD |
| command | sdlc close --issue 169 |
| reviewer | codex |
| timestamp | 2026-07-08T10:59:59-07:00 |
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
session id: 019f42e1-c63d-78d3-b048-6ebe35e4c538
--------
user
# Code review — the one SDLC boundary review

You are conducting a fresh-context code review at a development boundary —
whole-issue close — in the **parley.nvim** repository.

- repository: parley.nvim   (root: /Users/xianxu/workspace/parley.nvim)
- issue:      parley.nvim#169   (file: workshop/issues/000169-diagnostic-display-soft-wrap.md)
- window:     Base: 895bd1448552f969de91cd836cd5ed67a9cb7921   Head: HEAD

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
index 5186ccb..77cce06 100644
--- a/atlas/chat/inline_define.md
+++ b/atlas/chat/inline_define.md
@@ -34,8 +34,8 @@ narrowed the visible decoration to the selected term plus footnote reference.
    everything; **(b)** highlights the selected term/reference span with
    `DiffChange` (`skill_render.highlight_span`); **(c)** sets one INFO
    `vim.diagnostic` on that same span (`define.format_definition` →
-   `skill_render.wrap`) on the `parley_skill` namespace; **(d)** records the
-   undo/redo projection states.
+   `skill_render.format_diagnostic_message`) on the `parley_skill` namespace;
+   **(d)** records the undo/redo projection states.
    `diag_display`'s `virtual_lines{current_line=true}` reveals the diagnostic
    (cursor parked on the term's line). A no-`emit_definition` response leaves no
    footnote reference/footer.
diff --git a/atlas/modes/review.md b/atlas/modes/review.md
index 12d3e18..b470783 100644
--- a/atlas/modes/review.md
+++ b/atlas/modes/review.md
@@ -163,8 +163,8 @@ The edit "why" (the per-edit `explain`) is an INFO diagnostic on parley's
 `parley_skill` namespace. `lua/parley/skills/review/diag_display.lua` controls how
 it shows — scoped to that namespace, so the user's LSP/global diagnostics are
 untouched. Default **on**: `virtual_lines { current_line = true }`, so the
-(hard-wrapped, via `skill_render.wrap`) why **auto-expands below an edit when the
-cursor is in that edit's region** (`attach_diagnostics` spans `lnum..end_lnum`)
+(hard-wrapped, via `skill_render.format_diagnostic_message`) why **auto-expands
+below an edit when the cursor is in that edit's region** (`attach_diagnostics` spans `lnum..end_lnum`)
 and hides otherwise. `:ParleyShowDiagnostics` toggles it. The built-in `]d`/`[d`
 (jump) and `<C-W>d` (float, wraps) also work on these diagnostics. Composes with
 M5 — re-renders on undo/redo.
diff --git a/lua/parley/define.lua b/lua/parley/define.lua
index ce78f76..fd85f22 100644
--- a/lua/parley/define.lua
+++ b/lua/parley/define.lua
@@ -64,7 +64,8 @@ function M.context_for_selection(parsed_chat, sel_line, all_lines, find_exchange
 end
 
 --- Compose the diagnostic message ("TERM — definition"), hard-wrapped to width.
---- Delegates wrapping to skill_render.wrap (the same wrap the review path uses).
+--- Delegates wrapping to skill_render's diagnostic formatter (the same wrap the
+--- review path uses).
 --- @param term string|nil
 --- @param definition string|nil
 --- @param width integer|nil
@@ -76,7 +77,7 @@ function M.format_definition(term, definition, width)
         definition = "(no definition)"
     end
     local head = tostring(term or "") .. " — " .. definition
-    return require("parley.skill_render").wrap(head, width or 80)
+    return require("parley.skill_render").format_diagnostic_message(head, width or 80)
 end
 
 --- Plan the reference-bracket wrap of the selection ([term]) as a set_lines edit
diff --git a/lua/parley/init.lua b/lua/parley/init.lua
index a170178..3d06e97 100644
--- a/lua/parley/init.lua
+++ b/lua/parley/init.lua
@@ -1640,7 +1640,7 @@ local function render_definition(buf, span, phrase, result)
 	local e = define.apply_definition_footnote(lines, sr, sc - 1, er, ec - 1, input.term or phrase, input.definition)
 	require("parley.buffer_edit").replace_all_lines_for_definition(buf, e.lines)
 
-	local width = math.max(40, vim.api.nvim_win_get_width(0) - 8)
+	local width = skill_render.diagnostic_wrap_width()
 	local msg = define.format_definition(input.term or phrase, e.definition, width)
 	local diag_span = e.diagnostic_span
 	skill_render.highlight_span(buf, diag_span.lnum, diag_span.col, diag_span.end_lnum, diag_span.end_col)
diff --git a/lua/parley/skill_render.lua b/lua/parley/skill_render.lua
index 5d283a0..12d2719 100644
--- a/lua/parley/skill_render.lua
+++ b/lua/parley/skill_render.lua
@@ -88,6 +88,20 @@ local function diag_wrap_width()
     return math.max(30, (info.width or 80) - (info.textoff or 0) - 10)
 end
 
+--- Current usable wrap width for Parley diagnostic virtual lines.
+--- @return integer
+function M.diagnostic_wrap_width()
+    return diag_wrap_width()
+end
+
+--- Format a diagnostic message for Neovim virtual_lines display.
+--- @param text string
+--- @param width number|nil default current diagnostic display width
+--- @return string
+function M.format_diagnostic_message(text, width)
+    return M.wrap(text, width or M.diagnostic_wrap_width())
+end
+
 --- Attach INFO diagnostics from edit explanations. Each diagnostic spans the
 --- edit's line range (lnum..end_lnum) so "cursor in the region" matches, and its
 --- message is hard-wrapped to the window's usable width for `virtual_lines`
@@ -97,7 +111,7 @@ end
 --- @param original_content string  file content before edits
 function M.attach_diagnostics(buf, edits, original_content)
     ensure_namespaces()
-    local width = diag_wrap_width()
+    local width = M.diagnostic_wrap_width()
     local diagnostics = {}
     for _, edit in ipairs(edits) do
         local line_num = 0
@@ -114,7 +128,7 @@ function M.attach_diagnostics(buf, edits, original_content)
             lnum = line_num,
             end_lnum = line_num + span,
             col = 0,
-            message = M.wrap(edit.explain or "edit applied", width),
+            message = M.format_diagnostic_message(edit.explain or "edit applied", width),
             severity = vim.diagnostic.severity.INFO,
             source = "parley-skill",
         })
diff --git a/tests/integration/define_spec.lua b/tests/integration/define_spec.lua
index 05e5af1..2d575de 100644
--- a/tests/integration/define_spec.lua
+++ b/tests/integration/define_spec.lua
@@ -273,6 +273,40 @@ describe("define_visual + render_definition (#161)", function()
         assert.are.equal(19, mark[4].end_col)
     end)
 
+    it("word-wraps long define diagnostics to the diagnostic display width", function()
+        local prior_win = vim.api.nvim_get_current_win()
+        vim.cmd("vsplit")
+        local narrow_win = vim.api.nvim_get_current_win()
+        vim.cmd("vertical resize 45")
+        local expected_width = require("parley.skill_render").diagnostic_wrap_width()
+        parley.dispatcher.query = function(_b, _p, _payload, _h, on_exit)
+            query_called = true
+            tasker.set_query("qid_dv_long", {
+                raw_response = emit_definition_sse("ASIN", table.concat({
+                    "alpha", "beta", "gamma", "delta", "epsilon", "zeta",
+                    "eta", "theta", "iota", "kappa", "lambda", "mu",
+                }, " ")),
+            })
+            vim.schedule(function() on_exit("qid_dv_long") end)
+        end
+
+        vim.fn.setpos("'<", { buf, 3, 9, 0 })
+        vim.fn.setpos("'>", { buf, 3, 12, 0 })
+        require("parley").define_visual(buf)
+        vim.wait(2000, function()
+            return #vim.diagnostic.get(buf, { namespace = ns }) > 0
+        end)
+        vim.api.nvim_set_current_win(prior_win)
+        pcall(vim.api.nvim_win_close, narrow_win, true)
+
+        local msg = vim.diagnostic.get(buf, { namespace = ns })[1].message
+        assert.is_truthy(msg:find("\n", 1, true), "long define diagnostic did not wrap")
+        for _, line in ipairs(vim.split(msg, "\n", { plain = true })) do
+            assert.is_true(#line <= expected_width or not line:find(" ", 1, true),
+                "wrapped define diagnostic exceeds display width: " .. line)
+        end
+    end)
+
     it("re-defining a footnoted term updates the footer without duplicating the inline reference", function()
         vim.fn.setpos("'<", { buf, 3, 9, 0 })
         vim.fn.setpos("'>", { buf, 3, 12, 0 })
diff --git a/tests/unit/skill_render_spec.lua b/tests/unit/skill_render_spec.lua
index a0057b6..22fefc4 100644
--- a/tests/unit/skill_render_spec.lua
+++ b/tests/unit/skill_render_spec.lua
@@ -71,6 +71,15 @@ describe("skill_render", function()
         end
     end)
 
+    it("format_diagnostic_message word-wraps display text at the requested width", function()
+        local msg = skill_render.format_diagnostic_message("alpha beta gamma delta epsilon zeta", 16)
+        assert.is_truthy(msg:find("\n", 1, true), "diagnostic message did not wrap")
+        for _, line in ipairs(vim.split(msg, "\n", { plain = true })) do
+            assert.is_true(#line <= 16 or not line:find(" ", 1, true),
+                "wrapped line exceeds width: " .. line)
+        end
+    end)
+
     it("attach_diagnostics wraps the message + spans the edit's lines (end_lnum)", function()
         local buf = scratch({ "a", "b", "c", "d" })
         local original = "a\nb\nc\nd"
diff --git a/workshop/plans/000169-diagnostic-display-soft-wrap-plan.md b/workshop/plans/000169-diagnostic-display-soft-wrap-plan.md
new file mode 100644
index 0000000..05fe0fe
--- /dev/null
+++ b/workshop/plans/000169-diagnostic-display-soft-wrap-plan.md
@@ -0,0 +1,121 @@
+# Diagnostic Display Soft Wrap Implementation Plan
+
+> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.
+
+**Goal:** Make Parley diagnostic messages word-wrap consistently before display in Neovim virtual lines.
+
+**Architecture:** Keep `diag_display` focused on toggling visibility, and move message wrapping to the shared diagnostic render boundary in `skill_render` (ARCH-DRY). The wrapping function remains pure; the current-window width lookup stays a thin IO helper used only when formatting diagnostics for display (ARCH-PURE). Define diagnostics must derive from the same helper as review diagnostics so the stated purpose covers every `parley_skill` consumer (ARCH-PURPOSE).
+
+**Tech Stack:** Lua, Neovim diagnostics/virtual_lines, Plenary/Busted tests.
+
+---
+
+## Core Concepts
+
+### Pure Entities
+
+| Name | Lives in | Status |
+|------|----------|--------|
+| `DiagnosticMessageWrap` | `lua/parley/skill_render.lua` | modified |
+
+- **DiagnosticMessageWrap** — word-wraps diagnostic text using the existing `skill_render.wrap` behavior.
+  - **Relationships:** 1:N with Parley diagnostic producers; review and define diagnostics both use it before `vim.diagnostic.set`.
+  - **DRY rationale:** One wrapping policy for all `parley_skill` virtual-line diagnostics.
+  - **Future extensions:** Configurable width or indentation compensation can widen this helper without touching individual features.
+
+### Integration Points
+
+| Name | Lives in | Status | Wraps |
+|------|----------|--------|-------|
+| `ParleyDiagnosticFormatting` | `lua/parley/skill_render.lua` | modified | Neovim window width + diagnostics |
+| `DefineDiagnosticFormatter` | `lua/parley/define.lua` | modified | shared diagnostic formatter |
+| `DefineDiagnosticProducer` | `lua/parley/init.lua` | modified | `vim.diagnostic.set` |
+
+- **ParleyDiagnosticFormatting** — applies `DiagnosticMessageWrap` using the current window's usable diagnostic width.
+  - **Injected into:** `attach_diagnostics` and define rendering through a shared `skill_render` helper.
+  - **Future extensions:** Other Parley diagnostic producers can call the same helper.
+- **DefineDiagnosticFormatter** — composes the term/definition text and delegates display wrapping to `skill_render.format_diagnostic_message`.
+  - **Injected into:** `DefineDiagnosticProducer`.
+  - **Future extensions:** Alternate definition display formats still inherit the shared wrapping policy.
+- **DefineDiagnosticProducer** — creates the define diagnostic for the selected term/reference span.
+  - **Injected into:** The existing `render_definition` IO seam.
+  - **Future extensions:** Multi-diagnostic define output would still format every message through `skill_render`.
+
+## Chunk 1: Pin Wrapping Behavior
+
+**Files:**
+- Modify: `tests/unit/skill_render_spec.lua`
+- Modify: `tests/integration/define_spec.lua`
+
+- [x] **Step 1: Add failing unit coverage**
+
+Add a test proving a new shared diagnostic message helper word-wraps a long
+message at a supplied width. This should call real `skill_render` code and assert
+every wrapped line fits the width except single long words.
+
+- [x] **Step 2: Add failing define coverage**
+
+Extend the define integration test with a long definition and a narrow window.
+Assert the diagnostic message contains newline breaks and no wrapped line exceeds
+the expected width except single long words.
+
+- [x] **Step 3: Run red tests**
+
+Run:
+- `nvim --headless -c "PlenaryBustedFile tests/unit/skill_render_spec.lua"`
+- `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`
+
+Expected: FAIL because define diagnostics still format with their own width path
+and there is no shared diagnostic message helper.
+
+## Chunk 2: Shared Diagnostic Message Formatting
+
+**Files:**
+- Modify: `lua/parley/skill_render.lua`
+- Modify: `lua/parley/define.lua`
+- Modify: `lua/parley/init.lua`
+
+- [x] **Step 1: Add shared helper**
+
+Add `skill_render.format_diagnostic_message(text, width)` that delegates to
+`skill_render.wrap`. Add `skill_render.diagnostic_wrap_width()` or an equivalent
+public helper if callers need the current usable diagnostic width.
+
+- [x] **Step 2: Route review diagnostics through the helper**
+
+Update `skill_render.attach_diagnostics` to use the shared helper instead of
+calling `wrap` directly. Preserve existing behavior for fallback width and long
+single words.
+
+- [x] **Step 3: Route define diagnostics through the helper**
+
+Update `render_definition` to pass `skill_render.diagnostic_wrap_width()` into
+`define.format_definition`, and update `define.format_definition` to delegate
+wrapping to `skill_render.format_diagnostic_message`. Keep the diagnostic
+span/highlight behavior from #167 unchanged.
+
+- [x] **Step 4: Run focused green tests**
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
+- Modify: `workshop/issues/000169-diagnostic-display-soft-wrap.md`
+- Modify if docs change: `atlas/chat/inline_define.md`, `atlas/modes/review.md`, or related atlas pages
+
+- [x] **Step 1: Update issue log and checkboxes**
+
+Record red/green evidence and final verification commands.
+
+- [x] **Step 2: Run final checks**
+
+Run:
+- `git diff --check -- lua/parley/skill_render.lua lua/parley/define.lua lua/parley/init.lua tests/unit/skill_render_spec.lua tests/integration/define_spec.lua atlas/chat/inline_define.md atlas/modes/review.md workshop/issues/000169-diagnostic-display-soft-wrap.md workshop/plans/000169-diagnostic-display-soft-wrap-plan.md`
+- `make test`
+
+Expected: all pass.


2026-07-08T17:58:40.856916Z ERROR rmcp::transport::worker: worker quit with fatal: Transport channel closed, when UnexpectedServerResponse("HTTP 503: upstream connect error or disconnect/reset before headers. retried and the latest reset reason: remote connection failure, transport failure reason: delayed connect error: Connection refused")
codex
I’ll treat this as the boundary review only: read the workflow instructions that govern the repo, inspect the issue/plan and the diff against the stated window, then return the machine-readable verdict first.
exec
/bin/zsh -lc "sed -n '1,220p' /Users/xianxu/workspace/ariadne/construct/adapted/superpowers-using-superpowers/SKILL.md" in /Users/xianxu/workspace/parley.nvim
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

codex
Using `superpowers-using-superpowers` for skill discipline and `sdlc` because this is an SDLC boundary review. I’ll also read the repo’s current workflow help and review guidance artifacts before judging the diff.
exec
/bin/zsh -lc "sed -n '1,220p' workshop/issues/000169-diagnostic-display-soft-wrap.md" in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc "sed -n '1,220p' workshop/lessons.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
---
id: 000169
status: working
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 0.76
started: 2026-07-08T10:31:04-07:00
---

# diagnostic display should soft-wrap words

## Problem

Parley diagnostics display in `virtual_lines`, which does not soft-wrap long
messages reliably. Review diagnostics already hard-wrap their messages through
`skill_render.wrap`, but the width policy is private to `attach_diagnostics` and
define diagnostics compute their own fixed-ish width in `render_definition`.
Long definitions or explanations can still appear as over-wide diagnostic text
instead of word-wrapped rows.

## Spec

- Parley diagnostics shown through the shared `parley_skill` namespace are
  word-wrapped before they are passed to Neovim diagnostics.
- Review/edit diagnostics and define diagnostics use the same wrapping boundary
  so display behavior does not drift.
- Wrapping uses the current window's usable text width when available and keeps a
  conservative fallback for headless/tests.
- The display toggle remains responsible only for `virtual_lines` visibility,
  not message formatting.

ARCH-DRY: all Parley diagnostic messages derive from one wrap helper.
ARCH-PURE: word wrapping stays pure and unit-tested; the current-window width
lookup remains a thin IO helper.
ARCH-PURPOSE: the fix is not complete if define diagnostics can bypass the
shared wrapping path.

## Done when

- A long define diagnostic message is stored with word-wrapped newline breaks.
- Review diagnostics still wrap long explanations.
- Existing diagnostic toggling and undo/redo projection behavior continue to
  pass.
- Focused unit/integration tests and final verification pass.

## Estimate

Produced via `estimate-logic-v3.1` against the repo-local calibration source
reported by `sdlc start-plan` (stale but canonical for this repo). Method A
only.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.08 impl=0.00
item: lua-neovim design=0.12 impl=0.35
item: milestone-review design=0.00 impl=0.15
total: 0.76
```

## Plan

- [x] Add failing coverage for shared diagnostic message wrapping and define diagnostics.
- [x] Add a shared `skill_render` diagnostic-message helper using the existing wrap width logic.
- [x] Route review and define diagnostics through that helper.
- [x] Run focused and final verification.

## Log

### 2026-07-08
- Created after the operator clarified that diagnostic display should word
  soft-wrap. Design: keep Neovim `virtual_lines` configuration separate from
  message formatting; normalize messages before `vim.diagnostic.set`.
- Red tests confirmed the gap: `tests/unit/skill_render_spec.lua` failed because
  `format_diagnostic_message` did not exist, and
  `tests/integration/define_spec.lua` failed because a long define diagnostic
  exceeded the narrow diagnostic display width.
- Implemented `skill_render.format_diagnostic_message` and
  `diagnostic_wrap_width`, routed `attach_diagnostics` through the formatter,
  and routed define diagnostics through `define.format_definition` →
  `skill_render.format_diagnostic_message`.
- Focused verification passed:
  `nvim --headless -c "PlenaryBustedFile tests/unit/skill_render_spec.lua"` and
  `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`.
- Final `git diff --check` passed on touched code/test/docs/issue/plan files.
  First `make test` run failed in unrelated
  `tests/unit/tools_builtin_find_spec.lua`; isolated rerun of that spec passed.
  A second full `make test` run passed.

 succeeded in 0ms:
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

exec
/bin/zsh -lc 'sdlc --help' in /Users/xianxu/workspace/parley.nvim
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
/bin/zsh -lc 'git diff --stat 895bd1448552f969de91cd836cd5ed67a9cb7921..HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
 atlas/chat/inline_define.md                        |   4 +-
 atlas/modes/review.md                              |   4 +-
 lua/parley/define.lua                              |   5 +-
 lua/parley/init.lua                                |   2 +-
 lua/parley/skill_render.lua                        |  18 ++-
 tests/integration/define_spec.lua                  |  34 ++++++
 tests/unit/skill_render_spec.lua                   |   9 ++
 .../issues/000169-diagnostic-display-soft-wrap.md  |  68 +++++++++++-
 .../000169-diagnostic-display-soft-wrap-plan.md    | 121 +++++++++++++++++++++
 9 files changed, 253 insertions(+), 12 deletions(-)

codex
The issue and durable plan line up at a high level: the intended surface is narrow, centered on one shared formatter plus define/review consumers. I’m checking the actual call paths and tests now, especially width semantics and any plan/core-concept contradictions.
exec
/bin/zsh -lc "nl -ba lua/parley/define.lua | sed -n '55,90p'" in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc "nl -ba lua/parley/skill_render.lua | sed -n '1,170p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
    55	        return table.concat(all_lines, "\n") -- whole-buffer fallback
    56	    end
    57	    local lo = ex.question.line_start
    58	    local hi = (ex.answer and ex.answer.line_end) or ex.question.line_end
    59	    local slice = {}
    60	    for l = lo, hi do
    61	        slice[#slice + 1] = all_lines[l]
    62	    end
    63	    return table.concat(slice, "\n")
    64	end
    65	
    66	--- Compose the diagnostic message ("TERM — definition"), hard-wrapped to width.
    67	--- Delegates wrapping to skill_render's diagnostic formatter (the same wrap the
    68	--- review path uses).
    69	--- @param term string|nil
    70	--- @param definition string|nil
    71	--- @param width integer|nil
    72	--- @return string
    73	function M.format_definition(term, definition, width)
    74	    definition = definition or ""
    75	    definition = (definition:gsub("%s+$", "")) -- parens → keep only the string
    76	    if definition == "" then
    77	        definition = "(no definition)"
    78	    end
    79	    local head = tostring(term or "") .. " — " .. definition
    80	    return require("parley.skill_render").format_diagnostic_message(head, width or 80)
    81	end
    82	
    83	--- Plan the reference-bracket wrap of the selection ([term]) as a set_lines edit
    84	--- (#161 R1). Same arg convention as slice_selection (l1/l2 1-based, c1/c2
    85	--- 0-based byte, c2 inclusive). Returns the affected 0-based line range + the
    86	--- rewritten lines (selection wrapped in `[ ]`) for a single
    87	--- `nvim_buf_set_lines(buf, first0, last, false, lines)` — one undo entry (the
    88	--- anchor). `nvim_buf_set_text` is arch-forbidden outside buffer_edit; set_lines
    89	--- is the same primitive `drill_in_visual` uses to wrap a selection. Pure.
    90	--- @param lines string[]

 succeeded in 0ms:
     1	-- parley.skill_render — buffer decorations for applied skill edits.
     2	--
     3	-- The diagnostics/highlights rendering salvaged out of skill_runner (#128 M3),
     4	-- now the single source used by the skill_invoke driver (skill_runner was
     5	-- deleted in M4). Thin vim-API/UI wrapper (not pure): INFO diagnostics from each
     6	-- edit's `explain`, DiffChange highlights on edited regions.
     7	
     8	local M = {}
     9	
    10	local DIAG_NS = "parley_skill"
    11	local HL_NS = "parley_skill_hl"
    12	
    13	local diag_ns_id
    14	local hl_ns_id
    15	
    16	local function ensure_namespaces()
    17	    if not diag_ns_id then
    18	        diag_ns_id = vim.api.nvim_create_namespace(DIAG_NS)
    19	    end
    20	    if not hl_ns_id then
    21	        hl_ns_id = vim.api.nvim_create_namespace(HL_NS)
    22	    end
    23	end
    24	
    25	--- Clear previous skill diagnostics and highlights from a buffer.
    26	function M.clear_decorations(buf)
    27	    ensure_namespaces()
    28	    vim.diagnostic.reset(diag_ns_id, buf)
    29	    vim.api.nvim_buf_clear_namespace(buf, hl_ns_id, 0, -1)
    30	end
    31	
    32	--- Dismiss the live round decorations (manual <dismiss> binding). Decorations
    33	--- otherwise RIDE subsequent edits (behavior B, #133) and are cleared only at
    34	--- the next round start; this lets the operator clear them on demand.
    35	M.dismiss = M.clear_decorations
    36	
    37	--- The review diagnostic namespace id — the single source other modules
    38	--- (diag_display) target, so the namespace identity isn't duplicated as a literal
    39	--- string in two places (#133 M6 review).
    40	function M.diag_namespace()
    41	    ensure_namespaces()
    42	    return diag_ns_id
    43	end
    44	
    45	--- Hard-wrap text to `width` columns at word boundaries (greedy), preserving any
    46	--- existing newlines. PURE. Lets `virtual_lines` render a long "why" as multiple
    47	--- wrapped rows (nvim doesn't soft-wrap virtual text). A word longer than width
    48	--- stays on its own (overflowing) line rather than being split. (#133 M6)
    49	--- @param text string
    50	--- @param width number|nil  default 76
    51	--- @return string
    52	function M.wrap(text, width)
    53	    width = width or 76
    54	    local out = {}
    55	    for para in (tostring(text) .. "\n"):gmatch("(.-)\n") do
    56	        if para == "" then
    57	            table.insert(out, "")
    58	        else
    59	            local line = ""
    60	            for word in para:gmatch("%S+") do
    61	                if line == "" then
    62	                    line = word
    63	                elseif #line + 1 + #word <= width then
    64	                    line = line .. " " .. word
    65	                else
    66	                    table.insert(out, line)
    67	                    line = word
    68	                end
    69	            end
    70	            table.insert(out, line)
    71	        end
    72	    end
    73	    return table.concat(out, "\n")
    74	end
    75	
    76	-- Usable wrap width for the virtual_lines "why": the window's text columns
    77	-- (total width minus the number/sign/fold gutter, via getwininfo.textoff) minus
    78	-- a margin for the indent + connector nvim renders under the line. Wrapping to a
    79	-- fixed 76 overflowed the indented virtual_lines and truncated the right edge
    80	-- (#133 review). Falls back to 76 with no window.
    81	local function diag_wrap_width()
    82	    local ok, info = pcall(function()
    83	        return vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
    84	    end)
    85	    if not ok or type(info) ~= "table" then
    86	        return 76
    87	    end
    88	    return math.max(30, (info.width or 80) - (info.textoff or 0) - 10)
    89	end
    90	
    91	--- Current usable wrap width for Parley diagnostic virtual lines.
    92	--- @return integer
    93	function M.diagnostic_wrap_width()
    94	    return diag_wrap_width()
    95	end
    96	
    97	--- Format a diagnostic message for Neovim virtual_lines display.
    98	--- @param text string
    99	--- @param width number|nil default current diagnostic display width
   100	--- @return string
   101	function M.format_diagnostic_message(text, width)
   102	    return M.wrap(text, width or M.diagnostic_wrap_width())
   103	end
   104	
   105	--- Attach INFO diagnostics from edit explanations. Each diagnostic spans the
   106	--- edit's line range (lnum..end_lnum) so "cursor in the region" matches, and its
   107	--- message is hard-wrapped to the window's usable width for `virtual_lines`
   108	--- display (no right-edge truncation). (#133 M6)
   109	--- @param buf number
   110	--- @param edits table[]  applied edits with {pos, explain, new_string?}
   111	--- @param original_content string  file content before edits
   112	function M.attach_diagnostics(buf, edits, original_content)
   113	    ensure_namespaces()
   114	    local width = M.diagnostic_wrap_width()
   115	    local diagnostics = {}
   116	    for _, edit in ipairs(edits) do
   117	        local line_num = 0
   118	        for _ in original_content:sub(1, edit.pos):gmatch("\n") do
   119	            line_num = line_num + 1
   120	        end
   121	        -- end_lnum spans the edit's own lines (newlines in the new text); a pure
   122	        -- deletion (no new_string) stays a single-line anchor.
   123	        local span = 0
   124	        for _ in (edit.new_string or ""):gmatch("\n") do
   125	            span = span + 1
   126	        end
   127	        table.insert(diagnostics, {
   128	            lnum = line_num,
   129	            end_lnum = line_num + span,
   130	            col = 0,
   131	            message = M.format_diagnostic_message(edit.explain or "edit applied", width),
   132	            severity = vim.diagnostic.severity.INFO,
   133	            source = "parley-skill",
   134	        })
   135	    end
   136	    vim.diagnostic.set(diag_ns_id, buf, diagnostics)
   137	end
   138	
   139	--- Highlight edited regions with DiffChange.
   140	--- @param buf number
   141	--- @param edits table[]  applied edits with {new_string}
   142	--- @param new_content string  file content after edits
   143	function M.highlight_edits(buf, edits, new_content)
   144	    ensure_namespaces()
   145	    for _, edit in ipairs(edits) do
   146	        -- Skip pure deletions: new_string is "" and `find("")` returns 1, which
   147	        -- would spuriously highlight line 0. Deletions are oriented by their
   148	        -- INFO gutter diagnostic (the "why") via attach_diagnostics, not a
   149	        -- highlight (there's no new text to mark). #133.
   150	        local new_pos = (edit.new_string and edit.new_string ~= "")
   151	            and new_content:find(edit.new_string, 1, true)
   152	            or nil
   153	        if new_pos then
   154	            local start_line = 0
   155	            for _ in new_content:sub(1, new_pos):gmatch("\n") do
   156	                start_line = start_line + 1
   157	            end
   158	            local end_line = start_line
   159	            for _ in edit.new_string:gmatch("\n") do
   160	                end_line = end_line + 1
   161	            end
   162	            for line = start_line, end_line do
   163	                vim.api.nvim_buf_add_highlight(buf, hl_ns_id, "DiffChange", line, 0, -1)
   164	            end
   165	        end
   166	    end
   167	end
   168	
   169	--- Highlight a whole line with DiffChange on the hl namespace (#161 R1). Same
   170	--- shape `apply_snapshot` restores (whole-line, col 0..-1), so it round-trips

exec
/bin/zsh -lc "nl -ba tests/unit/skill_render_spec.lua | sed -n '1,115p'" in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc "nl -ba lua/parley/init.lua | sed -n '1625,1655p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
     1	-- Unit tests for lua/parley/skill_render.lua — the salvaged buffer-decoration
     2	-- helpers (INFO diagnostics + DiffChange highlights for applied skill edits).
     3	
     4	local skill_render = require("parley.skill_render")
     5	
     6	local function scratch(lines)
     7	    local buf = vim.api.nvim_create_buf(false, true)
     8	    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
     9	    return buf
    10	end
    11	
    12	describe("skill_render", function()
    13	    it("attach_diagnostics sets an INFO diagnostic per edit, on the edit's line", function()
    14	        local buf = scratch({ "line one", "line two", "line three" })
    15	        local original = "line one\nline two\nline three"
    16	        -- pos within "line two" (after the first newline)
    17	        local pos = original:find("two", 1, true)
    18	        skill_render.attach_diagnostics(buf, { { pos = pos, explain = "changed two" } }, original)
    19	        local diags = vim.diagnostic.get(buf)
    20	        assert.are.equal(1, #diags)
    21	        assert.are.equal(1, diags[1].lnum) -- 0-indexed line 1 = "line two"
    22	        assert.matches("changed two", diags[1].message)
    23	        assert.are.equal(vim.diagnostic.severity.INFO, diags[1].severity)
    24	    end)
    25	
    26	    it("clear_decorations removes the diagnostics", function()
    27	        local buf = scratch({ "x" })
    28	        skill_render.attach_diagnostics(buf, { { pos = 1, explain = "e" } }, "x")
    29	        assert.is_true(#vim.diagnostic.get(buf) > 0)
    30	        skill_render.clear_decorations(buf)
    31	        assert.are.equal(0, #vim.diagnostic.get(buf))
    32	    end)
    33	
    34	    it("highlight_edits runs without error on edited regions", function()
    35	        local buf = scratch({ "alpha", "BETA", "gamma" })
    36	        -- should not raise; highlights the line containing new_string
    37	        skill_render.highlight_edits(buf, { { new_string = "BETA" } }, "alpha\nBETA\ngamma")
    38	    end)
    39	
    40	    it("a non-empty edit produces highlight extmarks", function()
    41	        local buf = scratch({ "alpha", "BETA", "gamma" })
    42	        skill_render.highlight_edits(buf, { { new_string = "BETA" } }, "alpha\nBETA\ngamma")
    43	        local hl_ns = vim.api.nvim_create_namespace("parley_skill_hl")
    44	        local marks = vim.api.nvim_buf_get_extmarks(buf, hl_ns, 0, -1, {})
    45	        assert.is_true(#marks > 0)
    46	    end)
    47	
    48	    it("a deletion (empty new_string) gets a gutter diagnostic but no highlight", function()
    49	        local buf = scratch({ "keep this", "delete me", "keep this too" })
    50	        local original = "keep this\ndelete me\nkeep this too"
    51	        local new_content = "keep this\nkeep this too"
    52	        local pos = original:find("delete me", 1, true)
    53	        local edits = { { pos = pos, explain = "removed redundant line", new_string = "" } }
    54	        skill_render.attach_diagnostics(buf, edits, original)
    55	        skill_render.highlight_edits(buf, edits, new_content)
    56	        -- gutter "why" is present (deletion orientation)
    57	        local diags = vim.diagnostic.get(buf)
    58	        assert.are.equal(1, #diags)
    59	        assert.matches("removed redundant line", diags[1].message)
    60	        -- no highlight: empty new_string is skipped (would've spuriously hit line 0)
    61	        local hl_ns = vim.api.nvim_create_namespace("parley_skill_hl")
    62	        local marks = vim.api.nvim_buf_get_extmarks(buf, hl_ns, 0, -1, {})
    63	        assert.are.equal(0, #marks)
    64	    end)
    65	
    66	    it("wrap hard-wraps at word boundaries to the given width", function()
    67	        local w = skill_render.wrap("the quick brown fox jumps over the lazy dog", 12)
    68	        assert.is_truthy(w:find("\n"), "wrapped into multiple lines")
    69	        for line in (w .. "\n"):gmatch("(.-)\n") do
    70	            assert.is_true(#line <= 12 or not line:find(" ", 1, true), "within width or single long word: " .. line)
    71	        end
    72	    end)
    73	
    74	    it("format_diagnostic_message word-wraps display text at the requested width", function()
    75	        local msg = skill_render.format_diagnostic_message("alpha beta gamma delta epsilon zeta", 16)
    76	        assert.is_truthy(msg:find("\n", 1, true), "diagnostic message did not wrap")
    77	        for _, line in ipairs(vim.split(msg, "\n", { plain = true })) do
    78	            assert.is_true(#line <= 16 or not line:find(" ", 1, true),
    79	                "wrapped line exceeds width: " .. line)
    80	        end
    81	    end)
    82	
    83	    it("attach_diagnostics wraps the message + spans the edit's lines (end_lnum)", function()
    84	        local buf = scratch({ "a", "b", "c", "d" })
    85	        local original = "a\nb\nc\nd"
    86	        local pos = original:find("b")
    87	        skill_render.attach_diagnostics(buf, {
    88	            { pos = pos, explain = string.rep("word ", 30), new_string = "x\ny" },
    89	        }, original)
    90	        local d = vim.diagnostic.get(buf)[1]
    91	        assert.are.equal(1, d.lnum) -- 0-based line of "b"
    92	        assert.are.equal(2, d.end_lnum) -- spans the 2-line new_string
    93	        assert.is_truthy(d.message:find("\n"), "long message is wrapped")
    94	    end)
    95	
    96	    it("snapshot captures highlights + diagnostics; apply_snapshot restores them", function()
    97	        local buf = scratch({ "line one", "line two", "line three" })
    98	        local content = "line one\nline two\nline three"
    99	        skill_render.highlight_edits(buf, { { new_string = "line two" } }, content)
   100	        skill_render.attach_diagnostics(buf, { { pos = content:find("two"), explain = "why two" } }, content)
   101	        local snap = skill_render.snapshot(buf)
   102	        assert.is_true(#snap.hl_lines >= 1)
   103	        assert.is_true(#snap.diags >= 1)
   104	        -- clear → empty, then restore from the snapshot
   105	        skill_render.clear_decorations(buf)
   106	        assert.are.equal(0, #vim.diagnostic.get(buf))
   107	        skill_render.apply_snapshot(buf, snap)
   108	        local diags = vim.diagnostic.get(buf)
   109	        assert.is_true(#diags >= 1)
   110	        assert.matches("why two", diags[1].message)
   111	        assert.is_not_nil(diags[1].end_lnum, "end_lnum survives snapshot→apply (#133 M6)")
   112	        local hl_ns = vim.api.nvim_create_namespace("parley_skill_hl")
   113	        assert.is_true(#vim.api.nvim_buf_get_extmarks(buf, hl_ns, 0, -1, {}) >= 1)
   114	    end)
   115	

 succeeded in 0ms:
  1625	
  1626		-- The buffer may have changed under the in-flight call; skip the whole render
  1627		-- rather than attach a footnote reference to shifted text.
  1628		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  1629		if define.slice_selection(lines, sr, sc - 1, er, ec - 1) ~= phrase then
  1630			M.logger.warning("Define: selection changed during lookup — re-select to define")
  1631			return
  1632		end
  1633		local original = table.concat(lines, "\n") -- pre-edit content (undo base)
  1634	
  1635		-- Store the definition as a markdown footnote in ONE full-buffer set_lines
  1636		-- edit (single undo entry = the anchor). set_applying suppresses any prior
  1637		-- define's projection watcher during our own edit (mirrors review).
  1638		projection.set_applying(buf, true)
  1639		local input = call.input or {}
  1640		local e = define.apply_definition_footnote(lines, sr, sc - 1, er, ec - 1, input.term or phrase, input.definition)
  1641		require("parley.buffer_edit").replace_all_lines_for_definition(buf, e.lines)
  1642	
  1643		local width = skill_render.diagnostic_wrap_width()
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

exec
/bin/zsh -lc "nl -ba tests/integration/define_spec.lua | sed -n '245,325p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   245	        -- select "ASIN" on line 3 (cols 9..12, 1-based)
   246	        vim.fn.setpos("'<", { buf, 3, 9, 0 })
   247	        vim.fn.setpos("'>", { buf, 3, 12, 0 })
   248	        require("parley").define_visual(buf)
   249	        vim.wait(2000, function()
   250	            return #vim.diagnostic.get(buf, { namespace = ns }) > 0
   251	        end)
   252	        -- Footnote reference written into the line (the undo anchor)
   253	        assert.are.equal("here is ASIN[^asin] in context",
   254	            vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1])
   255	        assert.are.same({
   256	            "---",
   257	            "",
   258	            "[^asin]: Amazon Standard Identification Number.",
   259	        }, vim.api.nvim_buf_get_lines(buf, 5, 8, false))
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
   276	    it("word-wraps long define diagnostics to the diagnostic display width", function()
   277	        local prior_win = vim.api.nvim_get_current_win()
   278	        vim.cmd("vsplit")
   279	        local narrow_win = vim.api.nvim_get_current_win()
   280	        vim.cmd("vertical resize 45")
   281	        local expected_width = require("parley.skill_render").diagnostic_wrap_width()
   282	        parley.dispatcher.query = function(_b, _p, _payload, _h, on_exit)
   283	            query_called = true
   284	            tasker.set_query("qid_dv_long", {
   285	                raw_response = emit_definition_sse("ASIN", table.concat({
   286	                    "alpha", "beta", "gamma", "delta", "epsilon", "zeta",
   287	                    "eta", "theta", "iota", "kappa", "lambda", "mu",
   288	                }, " ")),
   289	            })
   290	            vim.schedule(function() on_exit("qid_dv_long") end)
   291	        end
   292	
   293	        vim.fn.setpos("'<", { buf, 3, 9, 0 })
   294	        vim.fn.setpos("'>", { buf, 3, 12, 0 })
   295	        require("parley").define_visual(buf)
   296	        vim.wait(2000, function()
   297	            return #vim.diagnostic.get(buf, { namespace = ns }) > 0
   298	        end)
   299	        vim.api.nvim_set_current_win(prior_win)
   300	        pcall(vim.api.nvim_win_close, narrow_win, true)
   301	
   302	        local msg = vim.diagnostic.get(buf, { namespace = ns })[1].message
   303	        assert.is_truthy(msg:find("\n", 1, true), "long define diagnostic did not wrap")
   304	        for _, line in ipairs(vim.split(msg, "\n", { plain = true })) do
   305	            assert.is_true(#line <= expected_width or not line:find(" ", 1, true),
   306	                "wrapped define diagnostic exceeds display width: " .. line)
   307	        end
   308	    end)
   309	
   310	    it("re-defining a footnoted term updates the footer without duplicating the inline reference", function()
   311	        vim.fn.setpos("'<", { buf, 3, 9, 0 })
   312	        vim.fn.setpos("'>", { buf, 3, 12, 0 })
   313	        require("parley").define_visual(buf)
   314	        vim.wait(2000, function()
   315	            return vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1] == "here is ASIN[^asin] in context"
   316	        end)
   317	
   318	        parley.dispatcher.query = function(_b, _p, _payload, _h, on_exit)
   319	            tasker.set_query("qid_dv_updated", {
   320	                raw_response = emit_definition_sse("ASIN", "Updated definition."),
   321	            })
   322	            vim.schedule(function() on_exit("qid_dv_updated") end)
   323	        end
   324	
   325	        vim.fn.setpos("'<", { buf, 3, 9, 0 })

codex
A possible edge I’m checking is whether the new shared formatter’s default width is actually used by all consumers, or whether an intermediate helper reintroduces its own fallback. That matters for the stated “one wrapping boundary” purpose.
exec
/bin/zsh -lc "rg \"format_definition|format_diagnostic_message|diagnostic_wrap_width|wrap\\(\" -n lua tests atlas workshop/issues/000169-diagnostic-display-soft-wrap.md workshop/plans/000169-diagnostic-display-soft-wrap-plan.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
workshop/issues/000169-diagnostic-display-soft-wrap.md:77:  `format_diagnostic_message` did not exist, and
workshop/issues/000169-diagnostic-display-soft-wrap.md:80:- Implemented `skill_render.format_diagnostic_message` and
workshop/issues/000169-diagnostic-display-soft-wrap.md:81:  `diagnostic_wrap_width`, routed `attach_diagnostics` through the formatter,
workshop/issues/000169-diagnostic-display-soft-wrap.md:82:  and routed define diagnostics through `define.format_definition` →
workshop/issues/000169-diagnostic-display-soft-wrap.md:83:  `skill_render.format_diagnostic_message`.
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:37:- **DefineDiagnosticFormatter** — composes the term/definition text and delegates display wrapping to `skill_render.format_diagnostic_message`.
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:80:Add `skill_render.format_diagnostic_message(text, width)` that delegates to
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:81:`skill_render.wrap`. Add `skill_render.diagnostic_wrap_width()` or an equivalent
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:92:Update `render_definition` to pass `skill_render.diagnostic_wrap_width()` into
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:93:`define.format_definition`, and update `define.format_definition` to delegate
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:94:wrapping to `skill_render.format_diagnostic_message`. Keep the diagnostic
lua/parley/define.lua:73:function M.format_definition(term, definition, width)
lua/parley/define.lua:80:    return require("parley.skill_render").format_diagnostic_message(head, width or 80)
atlas/chat/inline_define.md:36:   `vim.diagnostic` on that same span (`define.format_definition` →
atlas/chat/inline_define.md:37:   `skill_render.format_diagnostic_message`) on the `parley_skill` namespace;
atlas/chat/inline_define.md:60:  `context_for_selection`, `format_definition`, `bracket_edit` (plans the `[term]`
lua/parley/highlighter.lua:930:        vim.schedule_wrap(function()
lua/parley/drill_in.lua:637:function M.wrap(text)
lua/parley/init.lua:1456:				vim.schedule_wrap(function()
lua/parley/init.lua:1565:	local wrapped_lines = vim.split(_drill_in_mod.wrap(selected), "\n", { plain = true })
lua/parley/init.lua:1643:	local width = skill_render.diagnostic_wrap_width()
lua/parley/init.lua:1644:	local msg = define.format_definition(input.term or phrase, e.definition, width)
lua/parley/issues.lua:737:    timer:start(120, 120, vim.schedule_wrap(paint))
lua/parley/dispatcher.lua:466:	return vim.schedule_wrap(function(qid, chunk)
tests/integration/define_spec.lua:281:        local expected_width = require("parley.skill_render").diagnostic_wrap_width()
atlas/modes/review.md:166:(hard-wrapped, via `skill_render.format_diagnostic_message`) why **auto-expands
lua/parley/progress.lua:73:    _s.timer:start(120, 120, vim.schedule_wrap(function()
lua/parley/tasker.lua:304:	local on_exit = M.once(vim.schedule_wrap(function(code, signal)
lua/parley/lualine.lua:25:  flash_timer:start(0, 1000, vim.schedule_wrap(function()
lua/parley/lualine.lua:514:      check_timer:start(0, 500, vim.schedule_wrap(function()
lua/parley/interview.lua:154:		vim.schedule_wrap(function()
lua/parley/chat_respond.lua:940:        spinner_timer:start(0, 120, vim.schedule_wrap(function()
lua/parley/chat_respond.lua:985:        vim.schedule_wrap(function()
lua/parley/chat_respond.lua:1673:                vim.schedule_wrap(function()
lua/parley/chat_respond.lua:1761:            vim.schedule_wrap(function(qid)
lua/parley/chat_respond.lua:1981:            vim.schedule_wrap(function(_, progress_event)
lua/parley/skill_render.lua:52:function M.wrap(text, width)
lua/parley/skill_render.lua:93:function M.diagnostic_wrap_width()
lua/parley/skill_render.lua:101:function M.format_diagnostic_message(text, width)
lua/parley/skill_render.lua:102:    return M.wrap(text, width or M.diagnostic_wrap_width())
lua/parley/skill_render.lua:114:    local width = M.diagnostic_wrap_width()
lua/parley/skill_render.lua:131:            message = M.format_diagnostic_message(edit.explain or "edit applied", width),
lua/parley/helper.lua:72:				callback = vim.schedule_wrap(callback),
lua/parley/helper.lua:78:			callback = vim.schedule_wrap(callback),
tests/unit/skill_render_spec.lua:67:        local w = skill_render.wrap("the quick brown fox jumps over the lazy dog", 12)
tests/unit/skill_render_spec.lua:74:    it("format_diagnostic_message word-wraps display text at the requested width", function()
tests/unit/skill_render_spec.lua:75:        local msg = skill_render.format_diagnostic_message("alpha beta gamma delta epsilon zeta", 16)
tests/unit/define_spec.lua:67:describe("define.format_definition", function()
tests/unit/define_spec.lua:69:        local msg = define.format_definition("ASIN", "Amazon Standard Identification Number.", 200)
tests/unit/define_spec.lua:74:        local msg = define.format_definition("X", string.rep("word ", 30), 40)
tests/unit/define_spec.lua:81:        assert.equals("X — (no definition)", define.format_definition("X", nil, 80))
tests/unit/drill_in_spec.lua:881:        assert.equals("🤖<Term>[]", drill_in.wrap("Term"))
tests/unit/drill_in_spec.lua:885:        assert.equals("🤖<line one\nline two>[]", drill_in.wrap("line one\nline two"))

exec
/bin/zsh -lc 'git diff --find-renames --check 895bd1448552f969de91cd836cd5ed67a9cb7921..HEAD' in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc 'git diff 895bd1448552f969de91cd836cd5ed67a9cb7921..HEAD -- lua/parley/skill_render.lua lua/parley/define.lua lua/parley/init.lua tests/unit/skill_render_spec.lua tests/integration/define_spec.lua' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
 succeeded in 0ms:
diff --git a/lua/parley/define.lua b/lua/parley/define.lua
index ce78f76..fd85f22 100644
--- a/lua/parley/define.lua
+++ b/lua/parley/define.lua
@@ -64,7 +64,8 @@ function M.context_for_selection(parsed_chat, sel_line, all_lines, find_exchange
 end
 
 --- Compose the diagnostic message ("TERM — definition"), hard-wrapped to width.
---- Delegates wrapping to skill_render.wrap (the same wrap the review path uses).
+--- Delegates wrapping to skill_render's diagnostic formatter (the same wrap the
+--- review path uses).
 --- @param term string|nil
 --- @param definition string|nil
 --- @param width integer|nil
@@ -76,7 +77,7 @@ function M.format_definition(term, definition, width)
         definition = "(no definition)"
     end
     local head = tostring(term or "") .. " — " .. definition
-    return require("parley.skill_render").wrap(head, width or 80)
+    return require("parley.skill_render").format_diagnostic_message(head, width or 80)
 end
 
 --- Plan the reference-bracket wrap of the selection ([term]) as a set_lines edit
diff --git a/lua/parley/init.lua b/lua/parley/init.lua
index a170178..3d06e97 100644
--- a/lua/parley/init.lua
+++ b/lua/parley/init.lua
@@ -1640,7 +1640,7 @@ local function render_definition(buf, span, phrase, result)
 	local e = define.apply_definition_footnote(lines, sr, sc - 1, er, ec - 1, input.term or phrase, input.definition)
 	require("parley.buffer_edit").replace_all_lines_for_definition(buf, e.lines)
 
-	local width = math.max(40, vim.api.nvim_win_get_width(0) - 8)
+	local width = skill_render.diagnostic_wrap_width()
 	local msg = define.format_definition(input.term or phrase, e.definition, width)
 	local diag_span = e.diagnostic_span
 	skill_render.highlight_span(buf, diag_span.lnum, diag_span.col, diag_span.end_lnum, diag_span.end_col)
diff --git a/lua/parley/skill_render.lua b/lua/parley/skill_render.lua
index 5d283a0..12d2719 100644
--- a/lua/parley/skill_render.lua
+++ b/lua/parley/skill_render.lua
@@ -88,6 +88,20 @@ local function diag_wrap_width()
     return math.max(30, (info.width or 80) - (info.textoff or 0) - 10)
 end
 
+--- Current usable wrap width for Parley diagnostic virtual lines.
+--- @return integer
+function M.diagnostic_wrap_width()
+    return diag_wrap_width()
+end
+
+--- Format a diagnostic message for Neovim virtual_lines display.
+--- @param text string
+--- @param width number|nil default current diagnostic display width
+--- @return string
+function M.format_diagnostic_message(text, width)
+    return M.wrap(text, width or M.diagnostic_wrap_width())
+end
+
 --- Attach INFO diagnostics from edit explanations. Each diagnostic spans the
 --- edit's line range (lnum..end_lnum) so "cursor in the region" matches, and its
 --- message is hard-wrapped to the window's usable width for `virtual_lines`
@@ -97,7 +111,7 @@ end
 --- @param original_content string  file content before edits
 function M.attach_diagnostics(buf, edits, original_content)
     ensure_namespaces()
-    local width = diag_wrap_width()
+    local width = M.diagnostic_wrap_width()
     local diagnostics = {}
     for _, edit in ipairs(edits) do
         local line_num = 0
@@ -114,7 +128,7 @@ function M.attach_diagnostics(buf, edits, original_content)
             lnum = line_num,
             end_lnum = line_num + span,
             col = 0,
-            message = M.wrap(edit.explain or "edit applied", width),
+            message = M.format_diagnostic_message(edit.explain or "edit applied", width),
             severity = vim.diagnostic.severity.INFO,
             source = "parley-skill",
         })
diff --git a/tests/integration/define_spec.lua b/tests/integration/define_spec.lua
index 05e5af1..2d575de 100644
--- a/tests/integration/define_spec.lua
+++ b/tests/integration/define_spec.lua
@@ -273,6 +273,40 @@ describe("define_visual + render_definition (#161)", function()
         assert.are.equal(19, mark[4].end_col)
     end)
 
+    it("word-wraps long define diagnostics to the diagnostic display width", function()
+        local prior_win = vim.api.nvim_get_current_win()
+        vim.cmd("vsplit")
+        local narrow_win = vim.api.nvim_get_current_win()
+        vim.cmd("vertical resize 45")
+        local expected_width = require("parley.skill_render").diagnostic_wrap_width()
+        parley.dispatcher.query = function(_b, _p, _payload, _h, on_exit)
+            query_called = true
+            tasker.set_query("qid_dv_long", {
+                raw_response = emit_definition_sse("ASIN", table.concat({
+                    "alpha", "beta", "gamma", "delta", "epsilon", "zeta",
+                    "eta", "theta", "iota", "kappa", "lambda", "mu",
+                }, " ")),
+            })
+            vim.schedule(function() on_exit("qid_dv_long") end)
+        end
+
+        vim.fn.setpos("'<", { buf, 3, 9, 0 })
+        vim.fn.setpos("'>", { buf, 3, 12, 0 })
+        require("parley").define_visual(buf)
+        vim.wait(2000, function()
+            return #vim.diagnostic.get(buf, { namespace = ns }) > 0
+        end)
+        vim.api.nvim_set_current_win(prior_win)
+        pcall(vim.api.nvim_win_close, narrow_win, true)
+
+        local msg = vim.diagnostic.get(buf, { namespace = ns })[1].message
+        assert.is_truthy(msg:find("\n", 1, true), "long define diagnostic did not wrap")
+        for _, line in ipairs(vim.split(msg, "\n", { plain = true })) do
+            assert.is_true(#line <= expected_width or not line:find(" ", 1, true),
+                "wrapped define diagnostic exceeds display width: " .. line)
+        end
+    end)
+
     it("re-defining a footnoted term updates the footer without duplicating the inline reference", function()
         vim.fn.setpos("'<", { buf, 3, 9, 0 })
         vim.fn.setpos("'>", { buf, 3, 12, 0 })
diff --git a/tests/unit/skill_render_spec.lua b/tests/unit/skill_render_spec.lua
index a0057b6..22fefc4 100644
--- a/tests/unit/skill_render_spec.lua
+++ b/tests/unit/skill_render_spec.lua
@@ -71,6 +71,15 @@ describe("skill_render", function()
         end
     end)
 
+    it("format_diagnostic_message word-wraps display text at the requested width", function()
+        local msg = skill_render.format_diagnostic_message("alpha beta gamma delta epsilon zeta", 16)
+        assert.is_truthy(msg:find("\n", 1, true), "diagnostic message did not wrap")
+        for _, line in ipairs(vim.split(msg, "\n", { plain = true })) do
+            assert.is_true(#line <= 16 or not line:find(" ", 1, true),
+                "wrapped line exceeds width: " .. line)
+        end
+    end)
+
     it("attach_diagnostics wraps the message + spans the edit's lines (end_lnum)", function()
         local buf = scratch({ "a", "b", "c", "d" })
         local original = "a\nb\nc\nd"

exec
/bin/zsh -lc 'rg "parley_skill|diagnostic|virtual_lines|wrap|format_definition" -n atlas README.md lua tests workshop/issues/000169-diagnostic-display-soft-wrap.md workshop/plans/000169-diagnostic-display-soft-wrap-plan.md' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
workshop/issues/000169-diagnostic-display-soft-wrap.md:12:# diagnostic display should soft-wrap words
workshop/issues/000169-diagnostic-display-soft-wrap.md:16:Parley diagnostics display in `virtual_lines`, which does not soft-wrap long
workshop/issues/000169-diagnostic-display-soft-wrap.md:17:messages reliably. Review diagnostics already hard-wrap their messages through
workshop/issues/000169-diagnostic-display-soft-wrap.md:18:`skill_render.wrap`, but the width policy is private to `attach_diagnostics` and
workshop/issues/000169-diagnostic-display-soft-wrap.md:19:define diagnostics compute their own fixed-ish width in `render_definition`.
workshop/issues/000169-diagnostic-display-soft-wrap.md:20:Long definitions or explanations can still appear as over-wide diagnostic text
workshop/issues/000169-diagnostic-display-soft-wrap.md:21:instead of word-wrapped rows.
workshop/issues/000169-diagnostic-display-soft-wrap.md:25:- Parley diagnostics shown through the shared `parley_skill` namespace are
workshop/issues/000169-diagnostic-display-soft-wrap.md:26:  word-wrapped before they are passed to Neovim diagnostics.
workshop/issues/000169-diagnostic-display-soft-wrap.md:27:- Review/edit diagnostics and define diagnostics use the same wrapping boundary
workshop/issues/000169-diagnostic-display-soft-wrap.md:31:- The display toggle remains responsible only for `virtual_lines` visibility,
workshop/issues/000169-diagnostic-display-soft-wrap.md:34:ARCH-DRY: all Parley diagnostic messages derive from one wrap helper.
workshop/issues/000169-diagnostic-display-soft-wrap.md:35:ARCH-PURE: word wrapping stays pure and unit-tested; the current-window width
workshop/issues/000169-diagnostic-display-soft-wrap.md:37:ARCH-PURPOSE: the fix is not complete if define diagnostics can bypass the
workshop/issues/000169-diagnostic-display-soft-wrap.md:38:shared wrapping path.
workshop/issues/000169-diagnostic-display-soft-wrap.md:42:- A long define diagnostic message is stored with word-wrapped newline breaks.
workshop/issues/000169-diagnostic-display-soft-wrap.md:43:- Review diagnostics still wrap long explanations.
workshop/issues/000169-diagnostic-display-soft-wrap.md:44:- Existing diagnostic toggling and undo/redo projection behavior continue to
workshop/issues/000169-diagnostic-display-soft-wrap.md:65:- [x] Add failing coverage for shared diagnostic message wrapping and define diagnostics.
workshop/issues/000169-diagnostic-display-soft-wrap.md:66:- [x] Add a shared `skill_render` diagnostic-message helper using the existing wrap width logic.
workshop/issues/000169-diagnostic-display-soft-wrap.md:67:- [x] Route review and define diagnostics through that helper.
workshop/issues/000169-diagnostic-display-soft-wrap.md:73:- Created after the operator clarified that diagnostic display should word
workshop/issues/000169-diagnostic-display-soft-wrap.md:74:  soft-wrap. Design: keep Neovim `virtual_lines` configuration separate from
workshop/issues/000169-diagnostic-display-soft-wrap.md:75:  message formatting; normalize messages before `vim.diagnostic.set`.
workshop/issues/000169-diagnostic-display-soft-wrap.md:77:  `format_diagnostic_message` did not exist, and
workshop/issues/000169-diagnostic-display-soft-wrap.md:78:  `tests/integration/define_spec.lua` failed because a long define diagnostic
workshop/issues/000169-diagnostic-display-soft-wrap.md:79:  exceeded the narrow diagnostic display width.
workshop/issues/000169-diagnostic-display-soft-wrap.md:80:- Implemented `skill_render.format_diagnostic_message` and
workshop/issues/000169-diagnostic-display-soft-wrap.md:81:  `diagnostic_wrap_width`, routed `attach_diagnostics` through the formatter,
workshop/issues/000169-diagnostic-display-soft-wrap.md:82:  and routed define diagnostics through `define.format_definition` →
workshop/issues/000169-diagnostic-display-soft-wrap.md:83:  `skill_render.format_diagnostic_message`.
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:5:**Goal:** Make Parley diagnostic messages word-wrap consistently before display in Neovim virtual lines.
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:7:**Architecture:** Keep `diag_display` focused on toggling visibility, and move message wrapping to the shared diagnostic render boundary in `skill_render` (ARCH-DRY). The wrapping function remains pure; the current-window width lookup stays a thin IO helper used only when formatting diagnostics for display (ARCH-PURE). Define diagnostics must derive from the same helper as review diagnostics so the stated purpose covers every `parley_skill` consumer (ARCH-PURPOSE).
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:9:**Tech Stack:** Lua, Neovim diagnostics/virtual_lines, Plenary/Busted tests.
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:21:- **DiagnosticMessageWrap** — word-wraps diagnostic text using the existing `skill_render.wrap` behavior.
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:22:  - **Relationships:** 1:N with Parley diagnostic producers; review and define diagnostics both use it before `vim.diagnostic.set`.
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:23:  - **DRY rationale:** One wrapping policy for all `parley_skill` virtual-line diagnostics.
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:30:| `ParleyDiagnosticFormatting` | `lua/parley/skill_render.lua` | modified | Neovim window width + diagnostics |
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:31:| `DefineDiagnosticFormatter` | `lua/parley/define.lua` | modified | shared diagnostic formatter |
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:32:| `DefineDiagnosticProducer` | `lua/parley/init.lua` | modified | `vim.diagnostic.set` |
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:34:- **ParleyDiagnosticFormatting** — applies `DiagnosticMessageWrap` using the current window's usable diagnostic width.
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:35:  - **Injected into:** `attach_diagnostics` and define rendering through a shared `skill_render` helper.
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:36:  - **Future extensions:** Other Parley diagnostic producers can call the same helper.
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:37:- **DefineDiagnosticFormatter** — composes the term/definition text and delegates display wrapping to `skill_render.format_diagnostic_message`.
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:39:  - **Future extensions:** Alternate definition display formats still inherit the shared wrapping policy.
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:40:- **DefineDiagnosticProducer** — creates the define diagnostic for the selected term/reference span.
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:42:  - **Future extensions:** Multi-diagnostic define output would still format every message through `skill_render`.
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:52:Add a test proving a new shared diagnostic message helper word-wraps a long
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:54:every wrapped line fits the width except single long words.
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:59:Assert the diagnostic message contains newline breaks and no wrapped line exceeds
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:68:Expected: FAIL because define diagnostics still format with their own width path
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:69:and there is no shared diagnostic message helper.
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:80:Add `skill_render.format_diagnostic_message(text, width)` that delegates to
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:81:`skill_render.wrap`. Add `skill_render.diagnostic_wrap_width()` or an equivalent
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:82:public helper if callers need the current usable diagnostic width.
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:84:- [x] **Step 2: Route review diagnostics through the helper**
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:86:Update `skill_render.attach_diagnostics` to use the shared helper instead of
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:87:calling `wrap` directly. Preserve existing behavior for fallback width and long
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:90:- [x] **Step 3: Route define diagnostics through the helper**
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:92:Update `render_definition` to pass `skill_render.diagnostic_wrap_width()` into
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:93:`define.format_definition`, and update `define.format_definition` to delegate
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:94:wrapping to `skill_render.format_diagnostic_message`. Keep the diagnostic
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:108:- Modify: `workshop/issues/000169-diagnostic-display-soft-wrap.md`
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md:118:- `git diff --check -- lua/parley/skill_render.lua lua/parley/define.lua lua/parley/init.lua tests/unit/skill_render_spec.lua tests/integration/define_spec.lua atlas/chat/inline_define.md atlas/modes/review.md workshop/issues/000169-diagnostic-display-soft-wrap.md workshop/plans/000169-diagnostic-display-soft-wrap-plan.md`
lua/parley/define.lua:66:--- Compose the diagnostic message ("TERM — definition"), hard-wrapped to width.
lua/parley/define.lua:67:--- Delegates wrapping to skill_render's diagnostic formatter (the same wrap the
lua/parley/define.lua:73:function M.format_definition(term, definition, width)
lua/parley/define.lua:80:    return require("parley.skill_render").format_diagnostic_message(head, width or 80)
lua/parley/define.lua:83:--- Plan the reference-bracket wrap of the selection ([term]) as a set_lines edit
lua/parley/define.lua:86:--- rewritten lines (selection wrapped in `[ ]`) for a single
lua/parley/define.lua:89:--- is the same primitive `drill_in_visual` uses to wrap a selection. Pure.
lua/parley/define.lua:115:--- Convert a visual span from getpos columns to the diagnostic range after
lua/parley/define.lua:122:function M.diagnostic_span_after_bracket(l1, c1, l2, c2)
lua/parley/define.lua:276:--- @return table { lines: string[], id: string, definition: string, diagnostic_span: table }
lua/parley/define.lua:303:        diagnostic_span = {
atlas/skills/skill-system.md:44:- `lua/parley/skill_render.lua` — the single source of `clear_decorations`/`attach_diagnostics`/`highlight_edits` (salvaged from `skill_runner`).
atlas/skills/skill-system.md:51:- `lua/parley/skill_runner.lua` **deleted**; `review.lua`'s v1 edit/diagnostic re-exports and `review/init.lua`'s dead `pre_submit`/`post_apply`/`system_prompt` removed.
atlas/skills/skill-system.md:118:- `lua/parley/skill_render.lua` — diagnostics/highlights (single source; was salvaged from skill_runner)
atlas/index.md:15:- [Inline Term Definition](chat/inline_define.md): Visual-select a phrase + `<M-CR>` → concise context-aware definition as an ephemeral inline diagnostic (the `define` skill + `emit_definition` tool; honors `:ToggleWebSearch`).
lua/parley/agent_picker.lua:20:        -- string. The `require` itself is NOT pcall-wrapped: a real load
atlas/notes/structure.md:10:Shared infrastructure lives in `root_dirs.lua` (generic multi-root manager) with `note_dirs.lua` as a thin wrapper. See [Repo Mode](../infra/repo_mode.md) for details.
lua/parley/skill_picker.lua:9:-- run_via_invoke wrapper, every other skill as a single-shot exchange.
atlas/traceability.yaml:426:      - lua/parley/timezone_diagnostics.lua
atlas/traceability.yaml:430:      - tests/unit/timezone_diagnostics_spec.lua
lua/parley/providers.lua:1336:---@diagnostic disable-next-line: unused-local
lua/parley/providers.lua:1342:---@diagnostic disable-next-line: unused-local
lua/parley/providers.lua:1348:---@diagnostic disable-next-line: unused-local
lua/parley/highlighter.lua:558:--- and wrap the whole group with a single pair of square brackets.
lua/parley/highlighter.lua:605:--- group wrapping any enabled badges. Returns just the bare name when
lua/parley/highlighter.lua:930:        vim.schedule_wrap(function()
lua/parley/highlighter.lua:982:    local timezone_diagnostics = require("parley.timezone_diagnostics")
lua/parley/highlighter.lua:1074:            timezone_diagnostics.refresh_buffer(buf)
lua/parley/highlighter.lua:1086:            timezone_diagnostics.refresh_buffer(buf)
lua/parley/highlighter.lua:1107:            timezone_diagnostics.refresh_buffer(buf)
lua/parley/highlighter.lua:1111:            timezone_diagnostics.refresh_buffer(buf)
lua/parley/highlighter.lua:1121:            timezone_diagnostics.refresh_buffer(buf)
lua/parley/highlighter.lua:1135:        timezone_diagnostics.clear(buf)
atlas/providers/tool_use.md:72:- **Buffer diagnostic**: `:lua require('parley').check_buffer()` validates invariants
lua/parley/skills/review/diag_display.lua:1:-- diag_display.lua — inline display of review "why" diagnostics (#133 M6).
lua/parley/skills/review/diag_display.lua:4:-- diagnostic namespace (never touches the user's LSP / global diagnostics).
lua/parley/skills/review/diag_display.lua:5:-- Default ON: `virtual_lines { current_line = true }`, so the (hard-wrapped) why
lua/parley/skills/review/diag_display.lua:13:-- Parley's review diagnostic namespace — single-sourced from skill_render (which
lua/parley/skills/review/diag_display.lua:23:    vim.diagnostic.config({
lua/parley/skills/review/diag_display.lua:24:        virtual_lines = M.enabled and { current_line = true } or false,
atlas/chat/drill_in.md:3:Inline drill-in lets a user select text inside a chat transcript, wrap it as a marker `🤖<T>[Q]`, and have it resolved into a quote-and-question block prepended to the next user turn on the next chat-respond cycle.
atlas/chat/drill_in.md:32:1. **Create** — visual-mode `<C-g>q` (or `<M-q>`) wraps the selection as `🤖<T>[]` and drops the cursor inside the empty `[]` in insert mode.
atlas/chat/drill_in.md:61:The quoted body is wrapped in `[…]` (opening `[` on the first quoted line,
atlas/chat/drill_in.md:152:- `lua/parley/drill_in.lua` — pure-function module (`parse`, `gather_and_strip`, `generate_snippet`, `resolve`, `accept_at`, `reject_at`, `format_block`, `format_blocks`, `wrap`, `append_blocks`, `bracket_at`).
atlas/chat/inline_define.md:4:concise, context-aware definition appears as an **ephemeral inline diagnostic**
atlas/chat/inline_define.md:5:(grey `virtual_lines`) under the phrase. The selected text stays in place and
atlas/chat/inline_define.md:13:made the definition durable as a managed footnote; [#167](../../workshop/issues/000167-define-diagnostic-highlight-span.md)
atlas/chat/inline_define.md:36:   `vim.diagnostic` on that same span (`define.format_definition` →
atlas/chat/inline_define.md:37:   `skill_render.format_diagnostic_message`) on the `parley_skill` namespace;
atlas/chat/inline_define.md:39:   `diag_display`'s `virtual_lines{current_line=true}` reveals the diagnostic
atlas/chat/inline_define.md:50:highlight + diagnostic), `ensure_watch(buf)`. Undoing the footnote edit lands on
atlas/chat/inline_define.md:53:highlights (`hl_spans`) and diagnostic `col`/`end_col`, while still accepting
atlas/chat/inline_define.md:60:  `context_for_selection`, `format_definition`, `bracket_edit` (plans the `[term]`
atlas/chat/inline_define.md:61:  wrap as a legacy set_lines edit), `diagnostic_span_after_bracket` (legacy range
atlas/chat/inline_define.md:114:- One diagnostic visible at a time (`invoke` resets the `parley_skill` namespace
atlas/chat/inline_define.md:115:  each turn). The highlight and diagnostic span the selected text plus immediate
atlas/chat/inline_define.md:117:  reference/footer clears it; the diagnostic also auto-hides when the cursor
atlas/chat/inline_define.md:119:  `parley_skill` namespace/projection with review still applies (rare on chat
tests/integration/review_diag_display_spec.lua:1:-- Integration tests for the review-diagnostic inline display toggle (#133 M6).
tests/integration/review_diag_display_spec.lua:6:    return vim.diagnostic.config(nil, require("parley.skill_render").diag_namespace())
tests/integration/review_diag_display_spec.lua:23:    it("configures virtual_lines current_line on parley's namespace when on; off when disabled", function()
tests/integration/review_diag_display_spec.lua:26:        assert.is_truthy(on.virtual_lines) -- { current_line = true }
tests/integration/review_diag_display_spec.lua:29:        assert.is_false(ns_cfg().virtual_lines)
atlas/chat/inline_branch_links.md:7:- **Visual mode** (chat + markdown): wraps selection as `[🌿:selected text](new-file.md)`, creates child chat with topic `what is "selected text"`
lua/parley/note_dirs.lua:2:-- Thin wrapper around root_dirs for the note domain.
tests/integration/define_spec.lua:223:        vim.diagnostic.reset(ns, buf)
tests/integration/define_spec.lua:233:    local hl_ns = vim.api.nvim_create_namespace("parley_skill_hl")
tests/integration/define_spec.lua:244:    it("stores the definition as a durable footnote, highlights the term/reference span, and shows the diagnostic", function()
tests/integration/define_spec.lua:250:            return #vim.diagnostic.get(buf, { namespace = ns }) > 0
tests/integration/define_spec.lua:260:        -- diagnostic on the term's line
tests/integration/define_spec.lua:261:        local diags = vim.diagnostic.get(buf, { namespace = ns })
tests/integration/define_spec.lua:276:    it("word-wraps long define diagnostics to the diagnostic display width", function()
tests/integration/define_spec.lua:281:        local expected_width = require("parley.skill_render").diagnostic_wrap_width()
tests/integration/define_spec.lua:297:            return #vim.diagnostic.get(buf, { namespace = ns }) > 0
tests/integration/define_spec.lua:302:        local msg = vim.diagnostic.get(buf, { namespace = ns })[1].message
tests/integration/define_spec.lua:303:        assert.is_truthy(msg:find("\n", 1, true), "long define diagnostic did not wrap")
tests/integration/define_spec.lua:306:                "wrapped define diagnostic exceeds display width: " .. line)
tests/integration/define_spec.lua:347:            return #vim.diagnostic.get(buf, { namespace = ns }) > 0
tests/integration/define_spec.lua:362:        assert.are.equal(0, #vim.diagnostic.get(buf, { namespace = ns }),
tests/integration/define_spec.lua:363:            "diagnostic not cleared on undo")
tests/integration/define_spec.lua:377:        local redone_diags = vim.diagnostic.get(buf, { namespace = ns })
tests/integration/define_spec.lua:380:        assert.is_true(#vim.diagnostic.get(buf, { namespace = ns }) >= 1,
tests/integration/define_spec.lua:381:            "diagnostic not restored on redo")
tests/integration/define_spec.lua:385:    it("no-ops on a whitespace-only selection (no query, no diagnostic)", function()
tests/integration/define_spec.lua:392:        assert.are.equal(0, #vim.diagnostic.get(buf, { namespace = ns }))
tests/integration/define_spec.lua:408:        assert.are.equal(0, #vim.diagnostic.get(buf, { namespace = ns }),
tests/integration/define_spec.lua:409:            "a no-tool response must not set a diagnostic")
tests/integration/skill_providers_spec.lua:82:    it("unwraps the { skill = {...} } shape and honors an inline source", function()
atlas/modes/review.md:15:edits are oriented by `DiffChange` highlights + INFO gutter diagnostics that
atlas/modes/review.md:79:- **Rendering**: `lua/parley/skill_render.lua` — diagnostics + edit highlights
atlas/modes/review.md:85:- **Feedback**: Highlights on edits (DiffChange), diagnostics from explain fields (INFO), quickfix for pending agent questions
atlas/modes/review.md:125:  `append`. 4-backtick fences wrap the journal's own blocks so a 3-backtick code
atlas/modes/review.md:162:The edit "why" (the per-edit `explain`) is an INFO diagnostic on parley's
atlas/modes/review.md:163:`parley_skill` namespace. `lua/parley/skills/review/diag_display.lua` controls how
atlas/modes/review.md:164:it shows — scoped to that namespace, so the user's LSP/global diagnostics are
atlas/modes/review.md:165:untouched. Default **on**: `virtual_lines { current_line = true }`, so the
atlas/modes/review.md:166:(hard-wrapped, via `skill_render.format_diagnostic_message`) why **auto-expands
atlas/modes/review.md:167:below an edit when the cursor is in that edit's region** (`attach_diagnostics` spans `lnum..end_lnum`)
atlas/modes/review.md:169:(jump) and `<C-W>d` (float, wraps) also work on these diagnostics. Composes with
atlas/modes/review.md:209:- `lua/parley/skill_render.lua` — diagnostics + edit highlights
tests/integration/highlighting_spec.lua:404:describe("timezone diagnostics", function()
tests/integration/highlighting_spec.lua:406:        local ok, tz = pcall(require, "parley.timezone_diagnostics")
tests/integration/highlighting_spec.lua:410:                    pcall(vim.diagnostic.reset, tz.diag_namespace(), buf)
tests/integration/highlighting_spec.lua:417:    it("publishes local-time diagnostics in its own namespace and clears stale diagnostics", function()
tests/integration/highlighting_spec.lua:418:        local tz = require("parley.timezone_diagnostics")
tests/integration/highlighting_spec.lua:437:        local diagnostics = vim.diagnostic.get(buf, { namespace = tz.diag_namespace() })
tests/integration/highlighting_spec.lua:438:        assert.equals(1, #diagnostics)
tests/integration/highlighting_spec.lua:439:        assert.equals(0, diagnostics[1].lnum)
tests/integration/highlighting_spec.lua:440:        assert.equals(14, diagnostics[1].col)
tests/integration/highlighting_spec.lua:441:        assert.equals(34, diagnostics[1].end_col)
tests/integration/highlighting_spec.lua:442:        assert.equals("parley-timezone", diagnostics[1].source)
tests/integration/highlighting_spec.lua:443:        assert.equals("local time: 2026-04-17 17:00:00", diagnostics[1].message)
tests/integration/highlighting_spec.lua:444:        local diag_config = vim.diagnostic.config(nil, tz.diag_namespace())
tests/integration/highlighting_spec.lua:445:        assert.same({ current_line = true }, diag_config.virtual_lines)
tests/integration/highlighting_spec.lua:458:        assert.equals(0, #vim.diagnostic.get(buf, { namespace = tz.diag_namespace() }))
tests/integration/highlighting_spec.lua:461:    it("refreshes diagnostics for registered buffers on text changes", function()
tests/integration/highlighting_spec.lua:462:        local tz = require("parley.timezone_diagnostics")
tests/integration/highlighting_spec.lua:470:            return #vim.diagnostic.get(buf, { namespace = tz.diag_namespace() }) == 0
tests/integration/highlighting_spec.lua:472:        assert.equals(0, #vim.diagnostic.get(buf, { namespace = tz.diag_namespace() }))
tests/integration/highlighting_spec.lua:479:            return #vim.diagnostic.get(buf, { namespace = tz.diag_namespace() }) == 1
tests/integration/highlighting_spec.lua:482:        local diagnostics = vim.diagnostic.get(buf, { namespace = tz.diag_namespace() })
tests/integration/highlighting_spec.lua:483:        assert.equals(1, #diagnostics)
tests/integration/highlighting_spec.lua:484:        assert.equals(4, diagnostics[1].col)
lua/parley/oauth.lua:871:-- Backward-compatible token save wrapper.
lua/parley/oauth.lua:884:-- Backward-compatible token load wrapper.
lua/parley/oauth.lua:959:-- Backward-compatible wrapper around the account-store refresh path.
lua/parley/oauth.lua:1329:    tasker.run(nil, "pandoc", { "-t", "plain", "--wrap=none", tmp_path }, function(code, _, stdout)
lua/parley/note_dir_picker.lua:2:-- Thin wrapper around root_dir_picker for the note domain.
tests/integration/review_projection_spec.lua:37:        skill_render.attach_diagnostics(buf, { { pos = content:find("reviewed"), explain = "agent edit" } }, content)
tests/integration/review_projection_spec.lua:40:        assert.is_true(#vim.diagnostic.get(buf) >= 1)
tests/integration/review_projection_spec.lua:45:        assert.are.equal(0, #vim.diagnostic.get(buf))
tests/integration/review_projection_spec.lua:50:        assert.is_true(#vim.diagnostic.get(buf) >= 1, "style should re-render at the round state")
tests/integration/review_projection_spec.lua:55:        skill_render.attach_diagnostics(buf, { { pos = 1, explain = "why" } }, "round output")
tests/integration/review_projection_spec.lua:60:        assert.is_true(#vim.diagnostic.get(buf) >= 1, "decoration rides the manual edit")
tests/integration/review_projection_spec.lua:62:        assert.is_true(#vim.diagnostic.get(buf) >= 1, "capture must not clear the riding style")
tests/integration/review_projection_spec.lua:68:        assert.is_true(#vim.diagnostic.get(buf) >= 1, "novel state restores its captured style")
tests/integration/review_projection_spec.lua:74:        skill_render.attach_diagnostics(buf, { { pos = 1, explain = "edit A" } }, "state A")
tests/integration/review_projection_spec.lua:80:        skill_render.attach_diagnostics(buf, { { pos = 1, explain = "edit B" } }, "state B")
tests/integration/review_projection_spec.lua:86:        local diags = vim.diagnostic.get(buf)
tests/integration/review_projection_spec.lua:92:        assert.are.equal(0, #vim.diagnostic.get(buf))
tests/integration/review_projection_spec.lua:97:        skill_render.attach_diagnostics(buf, { { pos = 1, explain = "why" } }, "round output")
tests/integration/review_projection_spec.lua:103:        assert.is_true(#vim.diagnostic.get(buf) >= 1, "project is a no-op while applying")
lua/parley/drill_in.lua:551:        -- #141: wrap the whole quoted block in [...] so it reads as an anchor
lua/parley/drill_in.lua:637:function M.wrap(text)
atlas/modes/raw_mode.md:5:**For agents debugging parley:** this is the first-line diagnostic tool for any LLM-pipeline issue (wrong prompt, missing messages, cache misses, tool_use shape, token usage, SSE oddities). Toggle on, reproduce, inspect the side files, toggle off. See [`atlas/infra/raw_logging.md`](../infra/raw_logging.md#when-to-use-this-debugging-entry-point) for the decision tree (exchange-level vs raw-API-level) and the full spec — file layout, format, toggles, lualine indicator, and the typed-YAML input feature.
tests/integration/skill_invoke_review_spec.lua:130:        require("parley.skill_render").attach_diagnostics(b, { { pos = 1, explain = "why" } }, "edited line")
tests/integration/skill_invoke_review_spec.lua:138:        assert.are.equal(0, #vim.diagnostic.get(b))
tests/integration/skill_invoke_review_spec.lua:142:        assert.is_true(#vim.diagnostic.get(b) >= 1)
lua/parley/float_picker.lua:107:    local wrapped_search_from = 1
lua/parley/float_picker.lua:109:    while wrapped_search_from <= #text do
lua/parley/float_picker.lua:110:        local start_idx, end_idx = text:find("[%[%{][^%]%}]*[%]%}]", wrapped_search_from)
lua/parley/float_picker.lua:114:        local wrapped = text:sub(start_idx, end_idx)
lua/parley/float_picker.lua:115:        local kind = wrapped:sub(1, 1) == "[" and "tag" or "root"
lua/parley/float_picker.lua:118:            text = wrapped:sub(2, -2),
lua/parley/float_picker.lua:121:        wrapped_search_from = end_idx + 1
lua/parley/float_picker.lua:663:    vim.wo[results_win].wrap = false
lua/parley/float_picker.lua:681:    vim.wo[prompt_win].wrap = false
lua/parley/float_picker.lua:707:        vim.wo[tag_bar_win].wrap = false
lua/parley/review_menu.lua:108:    -- Programmatic move (used by tests + the optional C-j/C-k binding) — wraps.
lua/parley/timezone_diagnostics.lua:1:-- parley.timezone_diagnostics — local-time diagnostics for UTC timestamps.
lua/parley/timezone_diagnostics.lua:13:        vim.diagnostic.config({
lua/parley/timezone_diagnostics.lua:14:            virtual_lines = { current_line = true },
lua/parley/timezone_diagnostics.lua:82:--- Build pure diagnostic records for strict UTC timestamp tokens.
lua/parley/timezone_diagnostics.lua:86:function M.build_diagnostics(lines, opts)
lua/parley/timezone_diagnostics.lua:90:        error("timezone_diagnostics.build_diagnostics requires opts.to_local")
lua/parley/timezone_diagnostics.lua:93:    local diagnostics = {}
lua/parley/timezone_diagnostics.lua:106:                table.insert(diagnostics, {
lua/parley/timezone_diagnostics.lua:121:    return diagnostics
lua/parley/timezone_diagnostics.lua:124:--- The namespace for Parley timezone diagnostics.
lua/parley/timezone_diagnostics.lua:135:--- Refresh timezone diagnostics for a buffer.
lua/parley/timezone_diagnostics.lua:146:    local diagnostics = M.build_diagnostics(lines, {
lua/parley/timezone_diagnostics.lua:150:    local nvim_diagnostics = {}
lua/parley/timezone_diagnostics.lua:151:    for _, diagnostic in ipairs(diagnostics) do
lua/parley/timezone_diagnostics.lua:152:        table.insert(nvim_diagnostics, {
lua/parley/timezone_diagnostics.lua:153:            lnum = diagnostic.lnum,
lua/parley/timezone_diagnostics.lua:154:            col = diagnostic.col,
lua/parley/timezone_diagnostics.lua:155:            end_lnum = diagnostic.lnum,
lua/parley/timezone_diagnostics.lua:156:            end_col = diagnostic.end_col,
lua/parley/timezone_diagnostics.lua:157:            message = diagnostic.message,
lua/parley/timezone_diagnostics.lua:158:            severity = vim.diagnostic.severity.INFO,
lua/parley/timezone_diagnostics.lua:161:                utc = diagnostic.utc,
lua/parley/timezone_diagnostics.lua:162:                local_time = diagnostic.local_time,
lua/parley/timezone_diagnostics.lua:163:                epoch = diagnostic.epoch,
lua/parley/timezone_diagnostics.lua:168:    vim.diagnostic.set(diag_ns_id, buf, nvim_diagnostics)
lua/parley/timezone_diagnostics.lua:171:--- Clear timezone diagnostics for a buffer.
lua/parley/timezone_diagnostics.lua:178:    vim.diagnostic.reset(diag_ns_id, buf)
lua/parley/skill_render.lua:3:-- The diagnostics/highlights rendering salvaged out of skill_runner (#128 M3),
lua/parley/skill_render.lua:5:-- deleted in M4). Thin vim-API/UI wrapper (not pure): INFO diagnostics from each
lua/parley/skill_render.lua:10:local DIAG_NS = "parley_skill"
lua/parley/skill_render.lua:11:local HL_NS = "parley_skill_hl"
lua/parley/skill_render.lua:25:--- Clear previous skill diagnostics and highlights from a buffer.
lua/parley/skill_render.lua:28:    vim.diagnostic.reset(diag_ns_id, buf)
lua/parley/skill_render.lua:37:--- The review diagnostic namespace id — the single source other modules
lua/parley/skill_render.lua:45:--- Hard-wrap text to `width` columns at word boundaries (greedy), preserving any
lua/parley/skill_render.lua:46:--- existing newlines. PURE. Lets `virtual_lines` render a long "why" as multiple
lua/parley/skill_render.lua:47:--- wrapped rows (nvim doesn't soft-wrap virtual text). A word longer than width
lua/parley/skill_render.lua:52:function M.wrap(text, width)
lua/parley/skill_render.lua:76:-- Usable wrap width for the virtual_lines "why": the window's text columns
lua/parley/skill_render.lua:79:-- fixed 76 overflowed the indented virtual_lines and truncated the right edge
lua/parley/skill_render.lua:81:local function diag_wrap_width()
lua/parley/skill_render.lua:91:--- Current usable wrap width for Parley diagnostic virtual lines.
lua/parley/skill_render.lua:93:function M.diagnostic_wrap_width()
lua/parley/skill_render.lua:94:    return diag_wrap_width()
lua/parley/skill_render.lua:97:--- Format a diagnostic message for Neovim virtual_lines display.
lua/parley/skill_render.lua:99:--- @param width number|nil default current diagnostic display width
lua/parley/skill_render.lua:101:function M.format_diagnostic_message(text, width)
lua/parley/skill_render.lua:102:    return M.wrap(text, width or M.diagnostic_wrap_width())
lua/parley/skill_render.lua:105:--- Attach INFO diagnostics from edit explanations. Each diagnostic spans the
lua/parley/skill_render.lua:107:--- message is hard-wrapped to the window's usable width for `virtual_lines`
lua/parley/skill_render.lua:112:function M.attach_diagnostics(buf, edits, original_content)
lua/parley/skill_render.lua:114:    local width = M.diagnostic_wrap_width()
lua/parley/skill_render.lua:115:    local diagnostics = {}
lua/parley/skill_render.lua:127:        table.insert(diagnostics, {
lua/parley/skill_render.lua:131:            message = M.format_diagnostic_message(edit.explain or "edit applied", width),
lua/parley/skill_render.lua:132:            severity = vim.diagnostic.severity.INFO,
lua/parley/skill_render.lua:136:    vim.diagnostic.set(diag_ns_id, buf, diagnostics)
lua/parley/skill_render.lua:148:        -- INFO gutter diagnostic (the "why") via attach_diagnostics, not a
lua/parley/skill_render.lua:205:--- highlights and diagnostics preserve columns so exact anchors can be restored.
lua/parley/skill_render.lua:225:    for _, d in ipairs(vim.diagnostic.get(buf, { namespace = diag_ns_id })) do
lua/parley/skill_render.lua:251:        local diagnostics = {}
lua/parley/skill_render.lua:253:            table.insert(diagnostics, {
lua/parley/skill_render.lua:259:                severity = vim.diagnostic.severity.INFO,
lua/parley/skill_render.lua:263:        vim.diagnostic.set(diag_ns_id, buf, diagnostics)
lua/parley/skill_providers.lua:33:--   1. an explicit `source(ctx)` function (the new declarative field), wrapped so
tests/integration/create_handler_spec.lua:55:        -- Wait for vim.schedule_wrap to execute and buffer to be written
lua/parley/chat_respond.lua:461:--- message wrapping the text blocks, but in practice this helper is
lua/parley/chat_respond.lua:940:        spinner_timer:start(0, 120, vim.schedule_wrap(function()
lua/parley/chat_respond.lua:985:        vim.schedule_wrap(function()
lua/parley/chat_respond.lua:1673:                vim.schedule_wrap(function()
lua/parley/chat_respond.lua:1761:            vim.schedule_wrap(function(qid)
lua/parley/chat_respond.lua:1981:            vim.schedule_wrap(function(_, progress_event)
lua/parley/config.lua:127:		-- where parley drives cliproxyapi as a wrapped dependency — tinker here in
lua/parley/review.lua:11:-- compute_edits/apply_edits/diagnostics re-exports were removed in M4 with
lua/parley/vision.lua:1131:-- Escape a CSV field: wrap in quotes if it contains comma, quote, or newline.
lua/parley/vision.lua:1186:local CHARS_PER_INCH = 7  -- approx characters per inch for wrapping decisions
lua/parley/vision.lua:1191:local function wrap_text(text, max_chars)
lua/parley/vision.lua:1404:                local wrap_chars = math.floor(base_w * CHARS_PER_INCH)
lua/parley/vision.lua:1409:                local _, longest_name = wrap_text(name, wrap_chars)
lua/parley/vision.lua:1439:                -- Font grows with scaled width; compensate so wrap threshold stays accurate.
lua/parley/vision.lua:1446:                local wrapped, _ = wrap_text(name, max_chars)
lua/parley/vision.lua:1447:                local wrapped_name = table.concat(wrapped, "\\n")
lua/parley/vision.lua:1459:                            wrapped_name, size_label, comp, proj.achievable, proj.planned, str(item.need_by))
lua/parley/vision.lua:1462:                            wrapped_name, size_label, comp, proj.planned, str(item.need_by))
lua/parley/vision.lua:1466:                        wrapped_name, size_label, comp, str(item.need_by))
lua/parley/vision.lua:1469:                        wrapped_name, size_label, str(item.need_by))
lua/parley/vision.lua:1478:                local num_lines = #wrapped + 1
lua/parley/exporter.lua:115:--- IO wrapper: reads file, resolves path, then delegates to pure build_info.
lua/parley/exporter.lua:126:--- IO wrapper: resolves path, then delegates to pure build_info.
lua/parley/exporter.lua:392:	-- Clean up and fix paragraph wrapping around block elements
lua/parley/exporter.lua:673:	-- Replace branch placeholders (they may be wrapped in <p> tags)
lua/parley/exporter.lua:939:-- IO wrappers (need parley setup and filesystem)
lua/parley/interview.lua:154:		vim.schedule_wrap(function()
lua/parley/keybinding_registry.lua:646:		desc = "Parley insert 🤖 marker: wrap selection (v/x) / insert bare 🤖[] (i, n)",
lua/parley/keybinding_registry.lua:1048:							local wrapped
lua/parley/keybinding_registry.lua:1050:								wrapped = function()
lua/parley/keybinding_registry.lua:1055:								wrapped = cb
lua/parley/keybinding_registry.lua:1057:							vim.keymap.set(mode, key, wrapped, { silent = true, desc = entry.desc })
lua/parley/issues.lua:365:-- (commonly the build-in-owner wrapper) that nvim's non-interactive child shells
lua/parley/issues.lua:366:-- can't see — wrap it in the user's INTERACTIVE shell so the rc-defined function
lua/parley/issues.lua:737:    timer:start(120, 120, vim.schedule_wrap(paint))
lua/parley/outline.lua:23:-- Compatibility wrapper used by is_outline_item and exposed for testing.
lua/parley/helper.lua:72:				callback = vim.schedule_wrap(callback),
lua/parley/helper.lua:78:			callback = vim.schedule_wrap(callback),
lua/parley/lualine.lua:25:  flash_timer:start(0, 1000, vim.schedule_wrap(function()
lua/parley/lualine.lua:514:      check_timer:start(0, 500, vim.schedule_wrap(function()
tests/unit/open_chat_reference_spec.lua:13:    it("opens a wrapped @@chat-file@@ reference at the start of a markdown line", function()
tests/unit/issues_spec.lua:162:    it("wraps in an interactive shell when sdlc is a function/alias (the live E475 fix)", function()
lua/parley/skill_invoke.lua:53:-- Build the diagnostics/highlight edit list for a propose_edits call from its
lua/parley/skill_invoke.lua:54:-- input + the pre-edit content (positions for INFO diagnostics).
lua/parley/skill_invoke.lua:73:                -- "why" diagnostic, not a highlight (skill_render skips it). #133
lua/parley/skill_invoke.lua:78:    skill_render.attach_diagnostics(buf, edits, original)
lua/parley/chat_dirs.lua:2:-- Thin wrapper around root_dirs for the chat domain.
tests/unit/helper_io_spec.lua:85:        it("B3: wraps content in code fences", function()
atlas/ui/lualine.md:15:  but Parley wraps their `fmt` callback to shorten long display labels: first
tests/unit/progress_spec.lua:6:    it("frame cycles spinner glyphs and wraps", function()
tests/unit/progress_spec.lua:9:        assert.are.equal(progress.frame(0), progress.frame(10)) -- 10 glyphs → wraps
tests/unit/skill_render_spec.lua:2:-- helpers (INFO diagnostics + DiffChange highlights for applied skill edits).
tests/unit/skill_render_spec.lua:13:    it("attach_diagnostics sets an INFO diagnostic per edit, on the edit's line", function()
tests/unit/skill_render_spec.lua:18:        skill_render.attach_diagnostics(buf, { { pos = pos, explain = "changed two" } }, original)
tests/unit/skill_render_spec.lua:19:        local diags = vim.diagnostic.get(buf)
tests/unit/skill_render_spec.lua:23:        assert.are.equal(vim.diagnostic.severity.INFO, diags[1].severity)
tests/unit/skill_render_spec.lua:26:    it("clear_decorations removes the diagnostics", function()
tests/unit/skill_render_spec.lua:28:        skill_render.attach_diagnostics(buf, { { pos = 1, explain = "e" } }, "x")
tests/unit/skill_render_spec.lua:29:        assert.is_true(#vim.diagnostic.get(buf) > 0)
tests/unit/skill_render_spec.lua:31:        assert.are.equal(0, #vim.diagnostic.get(buf))
tests/unit/skill_render_spec.lua:43:        local hl_ns = vim.api.nvim_create_namespace("parley_skill_hl")
tests/unit/skill_render_spec.lua:48:    it("a deletion (empty new_string) gets a gutter diagnostic but no highlight", function()
tests/unit/skill_render_spec.lua:54:        skill_render.attach_diagnostics(buf, edits, original)
tests/unit/skill_render_spec.lua:57:        local diags = vim.diagnostic.get(buf)
tests/unit/skill_render_spec.lua:61:        local hl_ns = vim.api.nvim_create_namespace("parley_skill_hl")
tests/unit/skill_render_spec.lua:66:    it("wrap hard-wraps at word boundaries to the given width", function()
tests/unit/skill_render_spec.lua:67:        local w = skill_render.wrap("the quick brown fox jumps over the lazy dog", 12)
tests/unit/skill_render_spec.lua:68:        assert.is_truthy(w:find("\n"), "wrapped into multiple lines")
tests/unit/skill_render_spec.lua:74:    it("format_diagnostic_message word-wraps display text at the requested width", function()
tests/unit/skill_render_spec.lua:75:        local msg = skill_render.format_diagnostic_message("alpha beta gamma delta epsilon zeta", 16)
tests/unit/skill_render_spec.lua:76:        assert.is_truthy(msg:find("\n", 1, true), "diagnostic message did not wrap")
tests/unit/skill_render_spec.lua:79:                "wrapped line exceeds width: " .. line)
tests/unit/skill_render_spec.lua:83:    it("attach_diagnostics wraps the message + spans the edit's lines (end_lnum)", function()
tests/unit/skill_render_spec.lua:87:        skill_render.attach_diagnostics(buf, {
tests/unit/skill_render_spec.lua:90:        local d = vim.diagnostic.get(buf)[1]
tests/unit/skill_render_spec.lua:93:        assert.is_truthy(d.message:find("\n"), "long message is wrapped")
tests/unit/skill_render_spec.lua:96:    it("snapshot captures highlights + diagnostics; apply_snapshot restores them", function()
tests/unit/skill_render_spec.lua:100:        skill_render.attach_diagnostics(buf, { { pos = content:find("two"), explain = "why two" } }, content)
tests/unit/skill_render_spec.lua:106:        assert.are.equal(0, #vim.diagnostic.get(buf))
tests/unit/skill_render_spec.lua:108:        local diags = vim.diagnostic.get(buf)
tests/unit/skill_render_spec.lua:112:        local hl_ns = vim.api.nvim_create_namespace("parley_skill_hl")
tests/unit/skill_render_spec.lua:116:    it("snapshot captures and restores highlight and diagnostic column spans", function()
tests/unit/skill_render_spec.lua:118:        local hl_ns = vim.api.nvim_create_namespace("parley_skill_hl")
tests/unit/skill_render_spec.lua:122:        vim.diagnostic.set(diag_ns, buf, { {
tests/unit/skill_render_spec.lua:128:            severity = vim.diagnostic.severity.INFO,
tests/unit/skill_render_spec.lua:143:        local diags = vim.diagnostic.get(buf, { namespace = diag_ns })
tests/unit/skill_render_spec.lua:151:        skill_render.attach_diagnostics(buf, { { pos = 1, explain = "e" } }, "x")
tests/unit/skill_render_spec.lua:152:        assert.is_true(#vim.diagnostic.get(buf) > 0)
tests/unit/skill_render_spec.lua:154:        assert.are.equal(0, #vim.diagnostic.get(buf))
tests/unit/define_spec.lua:67:describe("define.format_definition", function()
tests/unit/define_spec.lua:69:        local msg = define.format_definition("ASIN", "Amazon Standard Identification Number.", 200)
tests/unit/define_spec.lua:73:    it("hard-wraps to width", function()
tests/unit/define_spec.lua:74:        local msg = define.format_definition("X", string.rep("word ", 30), 40)
tests/unit/define_spec.lua:81:        assert.equals("X — (no definition)", define.format_definition("X", nil, 80))
tests/unit/define_spec.lua:86:    it("wraps a single-line span into a set_lines edit", function()
tests/unit/define_spec.lua:99:    it("wraps a multi-line span", function()
tests/unit/define_spec.lua:107:describe("define.diagnostic_span_after_bracket", function()
tests/unit/define_spec.lua:109:        local span = define.diagnostic_span_after_bracket(3, 9, 3, 12)
tests/unit/define_spec.lua:119:        local span = define.diagnostic_span_after_bracket(1, 7, 3, 3)
tests/unit/define_spec.lua:151:        assert.are.same({ lnum = 0, col = 8, end_lnum = 0, end_col = 19 }, result.diagnostic_span)
tests/unit/define_spec.lua:200:        assert.are.same({ lnum = 0, col = 0, end_lnum = 0, end_col = 11 }, result.diagnostic_span)
tests/unit/vault_spec.lua:8:-- - run_with_secret: lazy resolution wrapper
lua/parley/dispatcher.lua:466:	return vim.schedule_wrap(function(qid, chunk)
tests/unit/drill_in_spec.lua:879:describe("drill_in.wrap", function()
tests/unit/drill_in_spec.lua:880:    it("wraps text as 🤖<T>[]", function()
tests/unit/drill_in_spec.lua:881:        assert.equals("🤖<Term>[]", drill_in.wrap("Term"))
tests/unit/drill_in_spec.lua:884:    it("wraps multi-line text", function()
tests/unit/drill_in_spec.lua:885:        assert.equals("🤖<line one\nline two>[]", drill_in.wrap("line one\nline two"))
tests/unit/artifact_ref_spec.lua:132:        -- argv may be shell-wrapped (sdlc-as-function); assert on the joined form.
lua/parley/tools/builtin/propose_edits.lua:8:-- The handler is the thin IO wrapper: read → compute → back up → write →
lua/parley/tools/builtin/propose_edits.lua:13:-- diagnostics/highlights rendering stays driver-side (M3), not here.
atlas/ui/pickers.md:6:Up/down arrow keys wrap around at list boundaries (top wraps to bottom, bottom wraps to top).
tests/unit/dispatcher_query_spec.lua:6:-- - Raw response mode (wraps in ```json fences)
tests/unit/dispatcher_query_spec.lua:194:        -- The legacy "raw response mode" (show_raw_response) that wrapped
tests/unit/dispatcher_query_spec.lua:198:        it("B1: handler receives parsed content, never fence wrappers", function()
tests/unit/dispatcher_query_spec.lua:249:                    -- Note: gsub returns (result, count), wrap in () to take only first value
tests/unit/tasker_unit_spec.lua:4:-- - M.once: wraps function to fire only once
tests/unit/tasker_unit_spec.lua:13:        it("A1: wrapped function called first time returns result", function()
tests/unit/tasker_unit_spec.lua:17:            -- Note: once wraps with no return, so we track via side effects
tests/unit/tasker_unit_spec.lua:26:        it("A2: wrapped function called second time does nothing", function()
lua/parley/tools/dispatcher.lua:6:-- error wrapping. Every safety concern lives HERE so there's
lua/parley/skill_edits.lua:5:-- propose_edits tool handler (IO wrapper) is its one caller (ARCH-DRY).
atlas/ui/highlights.md:12:  diagnostics in Parley chat and markdown buffers. The pure parser/formatter
atlas/ui/highlights.md:13:  lives in `lua/parley/timezone_diagnostics.lua`; `highlighter.setup_buf_handler`
atlas/ui/highlights.md:14:  refreshes its separate diagnostic namespace on buffer enter/window enter and
tests/unit/pure_functions_spec.lua:233:    it("wraps list items in <ul> with bullet-list class", function()
tests/unit/pure_functions_spec.lua:250:    it("wraps content in paragraph tags", function()
lua/parley/progress.lua:73:    _s.timer:start(120, 120, vim.schedule_wrap(function()
lua/parley/tools/builtin/emit_definition.lua:5:-- diagnostic. `self_paginates = true` marks it non-pageable (types.is_pageable),
tests/unit/process_directory_pattern_spec.lua:6:-- - Returns formatted content with line numbers wrapped in code fences
tests/unit/process_directory_pattern_spec.lua:161:        it("E2: content wrapped in code fences", function()
tests/unit/timezone_diagnostics_spec.lua:1:local timezone_diagnostics = require("parley.timezone_diagnostics")
tests/unit/timezone_diagnostics_spec.lua:3:describe("timezone_diagnostics.build_diagnostics", function()
tests/unit/timezone_diagnostics_spec.lua:4:    it("builds a deterministic local-time diagnostic for strict UTC timestamps", function()
tests/unit/timezone_diagnostics_spec.lua:6:        local diagnostics = timezone_diagnostics.build_diagnostics({
tests/unit/timezone_diagnostics_spec.lua:23:        assert.equals(1, #diagnostics)
tests/unit/timezone_diagnostics_spec.lua:24:        assert.equals(0, diagnostics[1].lnum)
tests/unit/timezone_diagnostics_spec.lua:25:        assert.equals(8, diagnostics[1].col)
tests/unit/timezone_diagnostics_spec.lua:26:        assert.equals(28, diagnostics[1].end_col)
tests/unit/timezone_diagnostics_spec.lua:27:        assert.equals("2026-04-18T00:00:00Z", diagnostics[1].utc)
tests/unit/timezone_diagnostics_spec.lua:28:        assert.equals("local time: 2026-04-17 17:00:00", diagnostics[1].message)
tests/unit/timezone_diagnostics_spec.lua:32:        local diagnostics = timezone_diagnostics.build_diagnostics({
tests/unit/timezone_diagnostics_spec.lua:40:        assert.equals(0, #diagnostics)
tests/unit/timezone_diagnostics_spec.lua:44:        local diagnostics = timezone_diagnostics.build_diagnostics({
tests/unit/timezone_diagnostics_spec.lua:52:        assert.equals(0, #diagnostics)
lua/parley/init.lua:55:-- Local wrappers so all existing callers in init.lua work unchanged
lua/parley/init.lua:205:-- Local helpers are defined as wrappers at the top of this file (near require).
lua/parley/init.lua:509:		---@diagnostic disable-next-line
lua/parley/init.lua:514:				---@diagnostic disable-next-line
lua/parley/init.lua:517:				---@diagnostic disable-next-line
lua/parley/init.lua:770:	-- :ParleyShowDiagnostics — toggle inline display of review "why" diagnostics
lua/parley/init.lua:774:		M.logger.info("Parley review diagnostics: inline display " .. (on and "ON" or "OFF"))
lua/parley/init.lua:1440:	-- better text wrapping
lua/parley/init.lua:1441:	vim.api.nvim_command("setlocal wrap linebreak")
lua/parley/init.lua:1456:				vim.schedule_wrap(function()
lua/parley/init.lua:1565:	local wrapped_lines = vim.split(_drill_in_mod.wrap(selected), "\n", { plain = true })
lua/parley/init.lua:1567:	if #wrapped_lines == 1 then
lua/parley/init.lua:1568:		table.insert(new_lines, prefix .. wrapped_lines[1] .. suffix)
lua/parley/init.lua:1570:		table.insert(new_lines, prefix .. wrapped_lines[1])
lua/parley/init.lua:1571:		for i = 2, #wrapped_lines - 1 do
lua/parley/init.lua:1572:			table.insert(new_lines, wrapped_lines[i])
lua/parley/init.lua:1574:		table.insert(new_lines, wrapped_lines[#wrapped_lines] .. suffix)
lua/parley/init.lua:1579:	-- Cursor between [ and ] in the last line of wrapped text. Wrap always
lua/parley/init.lua:1582:	local last_wrapped = wrapped_lines[#wrapped_lines]
lua/parley/init.lua:1584:	if #wrapped_lines == 1 then
lua/parley/init.lua:1586:		target_col = #prefix + #last_wrapped - 1
lua/parley/init.lua:1588:		target_row = sr + #wrapped_lines - 1
lua/parley/init.lua:1589:		target_col = #last_wrapped - 1
lua/parley/init.lua:1599:-- diagnostic. Undo/redo coherence reuses review's projection watcher: undoing
lua/parley/init.lua:1643:	local width = skill_render.diagnostic_wrap_width()
lua/parley/init.lua:1644:	local msg = define.format_definition(input.term or phrase, e.definition, width)
lua/parley/init.lua:1645:	local diag_span = e.diagnostic_span
lua/parley/init.lua:1647:	vim.diagnostic.set(skill_render.diag_namespace(), buf, { {
lua/parley/init.lua:1653:		severity = vim.diagnostic.severity.INFO,
lua/parley/init.lua:1659:	-- snapshot, footnoted hash → highlight+diagnostic; attach the watcher.
lua/parley/init.lua:1666:	-- virtual_lines reveals the definition immediately.
lua/parley/init.lua:1818:		-- manual edit. A full set_lines(0,-1) would wipe every extmark + diagnostic
lua/parley/init.lua:1872:-- wrap; here the marker refers to the surrounding text by position only.
lua/parley/init.lua:1889:--   <M-q> / <C-g>q  — insert a marker (wrap selection or insert bare)
lua/parley/init.lua:2031:	-- Drill-in handlers (visual wrap + resolve) live at module scope and are
lua/parley/init.lua:2323:	-- Drill-in handlers (visual wrap + resolve) — same in markdown and chat,
lua/parley/init.lua:2453:-- registered_chat_dir and chat_root_display are local wrappers defined at top of file.
tests/unit/picker_items_spec.lua:157:    -- this with other indicators and wrap the whole group in a single
tests/unit/dispatcher_spec.lua:405:    it("wraps content in parts array with text field", function()
lua/parley/tasker.lua:24:---@param fn function # function to wrap so it only gets called once
lua/parley/tasker.lua:304:	local on_exit = M.once(vim.schedule_wrap(function(code, signal)

codex
The code has a minor smell in `define.format_definition`: it still supplies `80` when its caller omits width, so that particular helper’s nil-width path does not use `skill_render`’s current-window default. The live define path does pass `diagnostic_wrap_width()`, so I’m treating that as a non-blocking design/API note unless a caller uses nil in production.
exec
/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/unit/skill_render_spec.lua"' in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"' in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"' in /Users/xianxu/workspace/parley.nvim
 succeeded in 1526ms:

Parley.nvim: Failed to open file for writing: /Users/xianxu/.local/share/nvim/parley/persisted/state.jsonScheduling: tests/unit/define_spec.lua

========================================	
Testing: 	/Users/xianxu/workspace/parley.nvim/tests/unit/define_spec.lua	
[32mSuccess[0m	||	define.slice_selection extracts a single-line span	
[32mSuccess[0m	||	define.slice_selection extracts a multi-line span joined with newline	
[32mSuccess[0m	||	define.slice_selection clamps an end column past line length	
[32mSuccess[0m	||	define.slice_selection returns empty string for a reversed/empty span	
[32mSuccess[0m	||	define.context_for_selection returns the enclosing exchange's lines (question..answer)	
[32mSuccess[0m	||	define.context_for_selection handles an answerless exchange (question only)	
[32mSuccess[0m	||	define.context_for_selection falls back to the whole buffer when outside any exchange	
[32mSuccess[0m	||	define.format_definition composes 'TERM — definition'	
[32mSuccess[0m	||	define.format_definition hard-wraps to width	
[32mSuccess[0m	||	define.format_definition trims a nil/blank definition to a safe string	
[32mSuccess[0m	||	define.bracket_edit wraps a single-line span into a set_lines edit	
[32mSuccess[0m	||	define.bracket_edit clamps end col past line length	
[32mSuccess[0m	||	define.bracket_edit wraps a multi-line span	
[32mSuccess[0m	||	define.diagnostic_span_after_bracket anchors a single-line selection on the selected text after brackets	
[32mSuccess[0m	||	define.diagnostic_span_after_bracket anchors a multi-line selection without shifting the final line	
[32mSuccess[0m	||	define durable footnotes slugifies a definition term into a markdown footnote id	
[32mSuccess[0m	||	define durable footnotes adds an inline footnote reference and appends a managed footer	
[32mSuccess[0m	||	define durable footnotes updates an existing managed footnote instead of duplicating it	
[32mSuccess[0m	||	define durable footnotes updates an existing inline reference without duplicating it	
[32mSuccess[0m	||	define durable footnotes strips only a final managed footnote footer	
[32mSuccess[0m	||	define durable footnotes preserves ordinary horizontal rules that are not managed footnote footers	
[32mSuccess[0m	||	define durable footnotes keeps earlier horizontal-rule content and strips only the final managed footer	
	
[32mSuccess: [0m	22	
[31mFailed : [0m	0	
[31mErrors : [0m	0	
========================================	
]111
 exited 1 in 1528ms:

LuaSnip: could not open log at /Users/xianxu/.local/state/nvim/luasnip.log. Not logging for this session.
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
            vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for "/private/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/XeYMut/0-define-chat/2026-03-01-kbwire.md", recovery impossible
            
            stack traceback:
            	vim/_editor.lua: in function 'cmd'
            	.../workspace/parley.nvim/tests/integration/define_spec.lua:480: in function <.../workspace/parley.nvim/tests/integration/define_spec.lua:472>
            	
[32mSuccess[0m	||	define: context_for_selection vs real parse_chat (#161) slices the enclosing exchange from real parse_chat output (field contract)	
	
[32mSuccess: [0m	7	
[31mFailed : [0m	1	
[31mErrors : [0m	2	
========================================	
We had an unexpected error: 	{ {
    descriptions = { "define: skill_invoke read-only seams (#161)" },
    msg = "vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for \"/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/XeYMut/1-def/chat.md\", recovery impossible\n\nstack traceback:\n\tvim/_editor.lua: in function 'cmd'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:91: in function 'w'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:167: in function 'run_each'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:174: in function 'it'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:124: in function <.../workspace/parley.nvim/tests/integration/define_spec.lua:77>\n"
  }, {
    descriptions = { "define_visual + render_definition (#161)" },
    msg = "vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for \"/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/XeYMut/2-dv/chat.md\", recovery impossible\n\nstack traceback:\n\tvim/_editor.lua: in function 'cmd'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:207: in function 'w'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:167: in function 'run_each'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:174: in function 'it'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:244: in function <.../workspace/parley.nvim/tests/integration/define_spec.lua:193>\n"
  } }	{
  errs = { {
      descriptions = { "define: skill_invoke read-only seams (#161)" },
      msg = "vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for \"/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/XeYMut/1-def/chat.md\", recovery impossible\n\nstack traceback:\n\tvim/_editor.lua: in function 'cmd'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:91: in function 'w'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:167: in function 'run_each'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:174: in function 'it'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:124: in function <.../workspace/parley.nvim/tests/integration/define_spec.lua:77>\n"
    }, {
      descriptions = { "define_visual + render_definition (#161)" },
      msg = "vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for \"/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/XeYMut/2-dv/chat.md\", recovery impossible\n\nstack traceback:\n\tvim/_editor.lua: in function 'cmd'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:207: in function 'w'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:167: in function 'run_each'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:174: in function 'it'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:244: in function <.../workspace/parley.nvim/tests/integration/define_spec.lua:193>\n"
    } },
  fail = { {
      descriptions = { "define keybinding split (#161)", "real prep_chat wiring: <M-CR>/<C-g><C-g> buffer-mapped in visual mode" },
      msg = "vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for \"/private/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/XeYMut/0-define-chat/2026-03-01-kbwire.md\", recovery impossible\n\nstack traceback:\n\tvim/_editor.lua: in function 'cmd'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:480: in function <.../workspace/parley.nvim/tests/integration/define_spec.lua:472>\n"
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
 succeeded in 1534ms:

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
[32mSuccess[0m	||	skill_render format_diagnostic_message word-wraps display text at the requested width	
[32mSuccess[0m	||	skill_render attach_diagnostics wraps the message + spans the edit's lines (end_lnum)	
[32mSuccess[0m	||	skill_render snapshot captures highlights + diagnostics; apply_snapshot restores them	
[32mSuccess[0m	||	skill_render snapshot captures and restores highlight and diagnostic column spans	
[32mSuccess[0m	||	skill_render dismiss clears decorations (alias of clear_decorations)	
	
[32mSuccess: [0m	11	
[31mFailed : [0m	0	
[31mErrors : [0m	0	
========================================	
]111
codex
My focused unit runs passed. The integration file failed in this sandbox on Neovim swap-file setup (`E303: Unable to open swap file` under the temp dir), before reaching the new diagnostic wrapping case; I’m going to avoid overstating that as a product regression unless the code/test change is the cause.
exec
/bin/zsh -lc "nl -ba tests/integration/define_spec.lua | sed -n '1,125p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
     1	-- Integration tests for the inline term-definition feature (#161).
     2	-- See workshop/issues/000161-inline-term-definition.md and its plan.
     3	
     4	-- Bootstrap parley so M.config is populated (parse_chat reads it).
     5	require("parley").setup({
     6	    chat_dir = vim.fn.tempname() .. "-define-chat",
     7	    providers = {},
     8	    api_keys = {},
     9	})
    10	
    11	-- SSE builder + an emit_definition tool-call response (mirrors skill_invoke_spec).
    12	local function sse(events)
    13	    local out = {}
    14	    for _, ev in ipairs(events) do
    15	        table.insert(out, "event: " .. (ev.type or "unknown"))
    16	        table.insert(out, "data: " .. vim.json.encode(ev))
    17	        table.insert(out, "")
    18	    end
    19	    return table.concat(out, "\n")
    20	end
    21	
    22	local function emit_definition_sse(term, definition)
    23	    return sse({
    24	        { type = "content_block_start", index = 0,
    25	          content_block = { type = "tool_use", id = "d1", name = "emit_definition", input = {} } },
    26	        { type = "content_block_delta", index = 0,
    27	          delta = { type = "input_json_delta", partial_json = vim.json.encode({ term = term, definition = definition }) } },
    28	        { type = "content_block_stop", index = 0 },
    29	        { type = "message_stop" },
    30	    })
    31	end
    32	
    33	describe("emit_definition tool", function()
    34	    before_each(function()
    35	        require("parley.tools").register_builtins()
    36	    end)
    37	
    38	    it("is registered and selectable without raising", function()
    39	        local reg = require("parley.tools")
    40	        local ok, sel = pcall(function()
    41	            return reg.select({ "emit_definition" })
    42	        end)
    43	        assert.is_true(ok)
    44	        assert.is_not_nil(sel)
    45	    end)
    46	
    47	    it("does not advertise pager offset/limit params", function()
    48	        local def = require("parley.tools.builtin.emit_definition")
    49	        local props = def.input_schema.properties
    50	        assert.is_nil(props.offset)
    51	        assert.is_nil(props.limit)
    52	        assert.is_not_nil(props.term)
    53	        assert.is_not_nil(props.definition)
    54	    end)
    55	end)
    56	
    57	describe("define skill", function()
    58	    it("is auto-discovered by the registry", function()
    59	        -- current() returns a registry object { get, names, all }, not a list.
    60	        local reg = require("parley.skill_registry").current()
    61	        local names = {}
    62	        for _, n in ipairs(reg.names()) do
    63	            names[n] = true
    64	        end
    65	        assert.is_true(names["define"] == true)
    66	    end)
    67	
    68	    it("folds the phrase into the system prompt and forces no tool", function()
    69	        local skill = require("parley.skills.define")
    70	        local body = skill.source({ args = { phrase = "ASIN" }, repo_root = "." })
    71	        assert.is_true(body:find("ASIN", 1, true) ~= nil)
    72	        assert.is_nil(skill.force_tool)
    73	        assert.same({ "emit_definition" }, skill.tools)
    74	    end)
    75	end)
    76	
    77	describe("define: skill_invoke read-only seams (#161)", function()
    78	    local skill_invoke = require("parley.skill_invoke")
    79	    local parley = require("parley")
    80	    local tasker = require("parley.tasker")
    81	    local assembly = require("parley.skill_assembly")
    82	
    83	    local tmpdir, path, buf, orig_query, orig_resolve, captured_payload, done_result
    84	
    85	    before_each(function()
    86	        require("parley.tools").register_builtins()
    87	        tmpdir = vim.fn.tempname() .. "-def"
    88	        vim.fn.mkdir(tmpdir, "p")
    89	        path = tmpdir .. "/chat.md"
    90	        vim.fn.writefile({ "on disk line 1", "on disk line 2" }, path)
    91	        vim.cmd("edit " .. vim.fn.fnameescape(path))
    92	        buf = vim.api.nvim_get_current_buf()
    93	        captured_payload, done_result = nil, nil
    94	
    95	        orig_resolve = assembly.resolve_agent
    96	        assembly.resolve_agent = function()
    97	            return { model = "m", provider = "anthropic" }
    98	        end
    99	        orig_query = parley.dispatcher.query
   100	        parley.dispatcher.query = function(_b, _p, payload, _h, on_exit)
   101	            captured_payload = payload
   102	            tasker.set_query("qid_def", {
   103	                raw_response = emit_definition_sse("ASIN", "Amazon Standard Identification Number."),
   104	            })
   105	            vim.schedule(function() on_exit("qid_def") end)
   106	        end
   107	    end)
   108	
   109	    after_each(function()
   110	        parley.dispatcher.query = orig_query
   111	        assembly.resolve_agent = orig_resolve
   112	        pcall(function() require("parley.progress").stop() end)
   113	        vim.fn.delete(tmpdir, "rf")
   114	    end)
   115	
   116	    local function define_manifest()
   117	        return {
   118	            name = "define", description = "d", scope = "global",
   119	            activation = { manual = true }, tools = { "emit_definition" },
   120	            source = function() return "SYSTEM BODY" end,
   121	        }
   122	    end
   123	
   124	    it("does not write or reload the buffer under opts.no_reload", function()
   125	        -- Make the buffer dirty (an in-progress prompt the user is typing).

exec
/bin/zsh -lc "nl -ba tests/integration/define_spec.lua | sed -n '450,500p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   450	                    return who
   451	                end
   452	            end
   453	            return "<unbound>"
   454	        end
   455	
   456	        -- visual <M-CR> → define; visual <C-g><C-g> → respond (resubmit preserved)
   457	        assert.are.equal("define", invoke("x", "<M-CR>"))
   458	        assert.are.equal("respond", invoke("x", "<C-g><C-g>"))
   459	        -- normal/insert <M-CR> → respond (unchanged)
   460	        assert.are.equal("respond", invoke("n", "<M-CR>"))
   461	        assert.are.equal("respond", invoke("i", "<M-CR>"))
   462	        -- chat_respond no longer binds <M-CR> (no double-bind): exactly one per mode
   463	        local mcr_x_count = 0
   464	        for _, r in ipairs(records) do
   465	            if r.mode == "x" and r.key == "<M-CR>" then
   466	                mcr_x_count = mcr_x_count + 1
   467	            end
   468	        end
   469	        assert.are.equal(1, mcr_x_count, "<M-CR> must be bound exactly once in visual mode")
   470	    end)
   471	
   472	    it("real prep_chat wiring: <M-CR>/<C-g><C-g> buffer-mapped in visual mode", function()
   473	        -- Exercises the production callback table + registry (not a hand-mirror):
   474	        -- catches a chat_define id/key mismatch that would silently no-op.
   475	        local dir = parley.config.chat_dir
   476	        vim.fn.mkdir(dir, "p")
   477	        local path = dir .. "/2026-03-01-kbwire.md"
   478	        -- must pass not_chat: >=5 lines + topic/file headers + separator
   479	        vim.fn.writefile({ "# topic: kbwire", "- file: kbwire.md", "---", "", "💬: hi" }, path)
   480	        vim.cmd("edit " .. vim.fn.fnameescape(path))
   481	        local buf = vim.api.nvim_get_current_buf()
   482	        parley.prep_chat(buf, path)
   483	
   484	        local mcr = vim.fn.maparg("<M-CR>", "x", false, true)
   485	        assert.is_true(mcr and mcr.buffer == 1 and next(mcr) ~= nil,
   486	            "<M-CR> not buffer-mapped in visual mode after prep_chat")
   487	        local cgg = vim.fn.maparg("<C-g><C-g>", "x", false, true)
   488	        assert.is_true(cgg and cgg.buffer == 1 and next(cgg) ~= nil,
   489	            "<C-g><C-g> not buffer-mapped in visual mode after prep_chat")
   490	
   491	        vim.fn.delete(path)
   492	    end)
   493	end)
   494	
   495	describe("define: context_for_selection vs real parse_chat (#161)", function()
   496	    it("slices the enclosing exchange from real parse_chat output (field contract)", function()
   497	        local parley = require("parley")
   498	        local define = require("parley.define")
   499	        -- A real 2-exchange chat; selecting inside exchange 2 must yield ONLY
   500	        -- exchange 2's lines (guards context_for_selection's field access against

exec
/bin/zsh -lc 'git diff --name-only 895bd1448552f969de91cd836cd5ed67a9cb7921..HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
atlas/chat/inline_define.md
atlas/modes/review.md
lua/parley/define.lua
lua/parley/init.lua
lua/parley/skill_render.lua
tests/integration/define_spec.lua
tests/unit/skill_render_spec.lua
workshop/issues/000169-diagnostic-display-soft-wrap.md
workshop/plans/000169-diagnostic-display-soft-wrap-plan.md

exec
/bin/zsh -lc 'nvim --headless -n -c "PlenaryBustedFile tests/integration/define_spec.lua"' in /Users/xianxu/workspace/parley.nvim
 exited 1 in 1464ms:

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
            vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for "/private/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/rmXv79/0-define-chat/2026-03-01-kbwire.md", recovery impossible
            
            stack traceback:
            	vim/_editor.lua: in function 'cmd'
            	.../workspace/parley.nvim/tests/integration/define_spec.lua:480: in function <.../workspace/parley.nvim/tests/integration/define_spec.lua:472>
            	
[32mSuccess[0m	||	define: context_for_selection vs real parse_chat (#161) slices the enclosing exchange from real parse_chat output (field contract)	
	
[32mSuccess: [0m	7	
[31mFailed : [0m	1	
[31mErrors : [0m	2	
========================================	
We had an unexpected error: 	{ {
    descriptions = { "define: skill_invoke read-only seams (#161)" },
    msg = "vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for \"/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/rmXv79/1-def/chat.md\", recovery impossible\n\nstack traceback:\n\tvim/_editor.lua: in function 'cmd'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:91: in function 'w'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:167: in function 'run_each'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:174: in function 'it'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:124: in function <.../workspace/parley.nvim/tests/integration/define_spec.lua:77>\n"
  }, {
    descriptions = { "define_visual + render_definition (#161)" },
    msg = "vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for \"/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/rmXv79/2-dv/chat.md\", recovery impossible\n\nstack traceback:\n\tvim/_editor.lua: in function 'cmd'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:207: in function 'w'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:167: in function 'run_each'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:174: in function 'it'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:244: in function <.../workspace/parley.nvim/tests/integration/define_spec.lua:193>\n"
  } }	{
  errs = { {
      descriptions = { "define: skill_invoke read-only seams (#161)" },
      msg = "vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for \"/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/rmXv79/1-def/chat.md\", recovery impossible\n\nstack traceback:\n\tvim/_editor.lua: in function 'cmd'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:91: in function 'w'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:167: in function 'run_each'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:174: in function 'it'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:124: in function <.../workspace/parley.nvim/tests/integration/define_spec.lua:77>\n"
    }, {
      descriptions = { "define_visual + render_definition (#161)" },
      msg = "vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for \"/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/rmXv79/2-dv/chat.md\", recovery impossible\n\nstack traceback:\n\tvim/_editor.lua: in function 'cmd'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:207: in function 'w'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:167: in function 'run_each'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:174: in function 'it'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:244: in function <.../workspace/parley.nvim/tests/integration/define_spec.lua:193>\n"
    } },
  fail = { {
      descriptions = { "define keybinding split (#161)", "real prep_chat wiring: <M-CR>/<C-g><C-g> buffer-mapped in visual mode" },
      msg = "vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for \"/private/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/rmXv79/0-define-chat/2026-03-01-kbwire.md\", recovery impossible\n\nstack traceback:\n\tvim/_editor.lua: in function 'cmd'\n\t.../workspace/parley.nvim/tests/integration/define_spec.lua:480: in function <.../workspace/parley.nvim/tests/integration/define_spec.lua:472>\n"
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
```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The change delivers the issue’s main behavior: review diagnostics and live define diagnostics now route through `skill_render.format_diagnostic_message`, and the atlas pages were updated for the renamed wrapping boundary. I found no Critical blockers. There is one cheap Important cleanup: `define.format_definition` still preserves its own `80` fallback on nil width, which weakens the “one diagnostic wrapping boundary” contract for future callers.

1. Strengths:
- `lua/parley/skill_render.lua:101` adds a small shared formatter over the existing pure `wrap`, keeping the new behavior narrow.
- `lua/parley/skill_render.lua:114` and `lua/parley/skill_render.lua:131` route review diagnostics through the public diagnostic width/format helpers without changing diagnostic span logic.
- `lua/parley/init.lua:1643` switches define rendering to `skill_render.diagnostic_wrap_width()`, so the live define path now uses the same current-window width policy as review diagnostics.
- `tests/integration/define_spec.lua:276` pins the original bug shape with a narrow-window define diagnostic.

2. Critical findings:
- None.

3. Important findings:
- `lua/parley/define.lua:80` still passes `width or 80` into `skill_render.format_diagnostic_message`, so any define caller that omits width bypasses the shared formatter’s current-window default and reintroduces a define-local fallback. This is a small ARCH-DRY / ARCH-PURPOSE leak in the new internal API surface. Fix sketch: pass `width` through unchanged, or make `width` required in `define.format_definition` and update the doc/tests to reflect that the caller owns width lookup.

4. Minor findings:
- None.

5. Test coverage notes:
- Verified `nvim --headless -c "PlenaryBustedFile tests/unit/skill_render_spec.lua"`: 11 passed.
- Verified `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`: 22 passed.
- I could not independently complete `tests/integration/define_spec.lua` in this sandbox; it failed before the new wrapping case on `Vim(edit):E303: Unable to open swap file` for temp chat files, including with `-n`. The issue log records a later full `make test` pass, but I did not reproduce that here.

6. Architectural notes for upcoming work:
- ARCH-DRY: mostly pass; one fallback-width duplication remains at `define.lua:80`.
- ARCH-PURE: pass for the wrapping core; width lookup stays isolated in `skill_render.diagnostic_wrap_width()`.
- ARCH-PURPOSE: live review and define consumers derive from the shared formatter, satisfying the issue purpose once the nil-width API leak is cleaned up.

7. Plan revision recommendations:
- None required; the plan still matches the implemented surface.
tokens used
59,312
```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The change delivers the issue’s main behavior: review diagnostics and live define diagnostics now route through `skill_render.format_diagnostic_message`, and the atlas pages were updated for the renamed wrapping boundary. I found no Critical blockers. There is one cheap Important cleanup: `define.format_definition` still preserves its own `80` fallback on nil width, which weakens the “one diagnostic wrapping boundary” contract for future callers.

1. Strengths:
- `lua/parley/skill_render.lua:101` adds a small shared formatter over the existing pure `wrap`, keeping the new behavior narrow.
- `lua/parley/skill_render.lua:114` and `lua/parley/skill_render.lua:131` route review diagnostics through the public diagnostic width/format helpers without changing diagnostic span logic.
- `lua/parley/init.lua:1643` switches define rendering to `skill_render.diagnostic_wrap_width()`, so the live define path now uses the same current-window width policy as review diagnostics.
- `tests/integration/define_spec.lua:276` pins the original bug shape with a narrow-window define diagnostic.

2. Critical findings:
- None.

3. Important findings:
- `lua/parley/define.lua:80` still passes `width or 80` into `skill_render.format_diagnostic_message`, so any define caller that omits width bypasses the shared formatter’s current-window default and reintroduces a define-local fallback. This is a small ARCH-DRY / ARCH-PURPOSE leak in the new internal API surface. Fix sketch: pass `width` through unchanged, or make `width` required in `define.format_definition` and update the doc/tests to reflect that the caller owns width lookup.

4. Minor findings:
- None.

5. Test coverage notes:
- Verified `nvim --headless -c "PlenaryBustedFile tests/unit/skill_render_spec.lua"`: 11 passed.
- Verified `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`: 22 passed.
- I could not independently complete `tests/integration/define_spec.lua` in this sandbox; it failed before the new wrapping case on `Vim(edit):E303: Unable to open swap file` for temp chat files, including with `-n`. The issue log records a later full `make test` pass, but I did not reproduce that here.

6. Architectural notes for upcoming work:
- ARCH-DRY: mostly pass; one fallback-width duplication remains at `define.lua:80`.
- ARCH-PURE: pass for the wrapping core; width lookup stays isolated in `skill_render.diagnostic_wrap_width()`.
- ARCH-PURPOSE: live review and define consumers derive from the shared formatter, satisfying the issue purpose once the nil-width API leak is cleaned up.

7. Plan revision recommendations:
- None required; the plan still matches the implemented surface.
