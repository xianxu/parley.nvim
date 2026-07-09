# Boundary Review — parley.nvim#178 (whole-issue close)

| field | value |
|-------|-------|
| issue | 178 — recognize footnote footer without divider |
| repo | parley.nvim |
| issue file | workshop/issues/000178-recognize-footnote-footer-without-divider.md |
| boundary | whole-issue close |
| milestone | — |
| window | c481296d642c30cfbddbe1b5fd62c6265b397fe3..HEAD |
| command | sdlc close --issue 178 |
| reviewer | codex |
| timestamp | 2026-07-08T23:41:30-07:00 |
| verdict | REWORK |

## Review

Reading additional input from stdin...
OpenAI Codex v0.143.0
--------
workdir: /Users/xianxu/workspace/parley.nvim
model: gpt-5.5
provider: openai
approval: never
sandbox: workspace-write [workdir, /tmp, $TMPDIR, /tmp] (network access enabled)
reasoning effort: none
reasoning summaries: none
session id: 019f459a-729e-7003-b01b-15c41ebca177
--------
user
# Code review — the one SDLC boundary review

You are conducting a fresh-context code review at a development boundary —
whole-issue close — in the **parley.nvim** repository.

- repository: parley.nvim   (root: /Users/xianxu/workspace/parley.nvim)
- issue:      parley.nvim#178   (file: workshop/issues/000178-recognize-footnote-footer-without-divider.md)
- window:     Base: c481296d642c30cfbddbe1b5fd62c6265b397fe3   Head: HEAD

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
index d40dec6..1a14c80 100644
--- a/atlas/chat/inline_define.md
+++ b/atlas/chat/inline_define.md
@@ -65,8 +65,8 @@ watcher doesn't mistake it for a user edit.
   `context_for_selection`, `format_definition`, `bracket_edit` (plans the `[term]`
   wrap as a legacy set_lines edit), `diagnostic_span_after_bracket` (legacy range
   mapping), `apply_definition_footnote` (durable footer transform), and
-  `strip_definition_footnote_footer` / `footnote_diagnostics` (read only a final
-  `---` block followed solely by footnotes).
+  `strip_definition_footnote_footer` / `footnote_diagnostics` (treat the first
+  markdown footnote definition line as the managed footer boundary).
 - **IO shell** (`lua/parley/init.lua`): `define_visual`, `render_definition`;
   `lua/parley/buffer_edit.lua` owns the full-buffer footnote rewrite;
   `lua/parley/skill_render.lua` publishes footnote diagnostics; and
@@ -77,22 +77,19 @@ watcher doesn't mistake it for a user edit.

 ## Managed Footnote Footer

-The footer is a final markdown block:
+The footer begins at the first markdown footnote definition line:

 ```markdown
----
-
 [^asin]: Amazon Standard Identification Number.
 ```

-The footer detector is deliberately conservative: only the last standalone
-`---` line followed by blank lines and footnote definitions counts as the
-managed footer. Ordinary horizontal rules and mixed prose after `---` remain
-chat content. `chat_respond.build_messages` strips this managed footer from
-message strings before LLM submission, so durable definitions do not become
-prompt context. `define.footnote_diagnostics` uses the same footer detector to
-scan inline references before the footer and produce diagnostics for each
-matching `[^id]`.
+Older define edits may include a standalone `---` separator immediately before
+that first footnote definition; the stripper removes that optional separator
+along with the footer, but the canonical boundary is the `[^id]: ...` line.
+`chat_respond.build_messages` strips this managed footer from message strings
+before LLM submission, so durable definitions do not become prompt context.
+`define.footnote_diagnostics` uses the same footer detector to scan inline
+references before the footer and produce diagnostics for each matching `[^id]`.

 ## Keybinding

diff --git a/atlas/ui/highlights.md b/atlas/ui/highlights.md
index 27290df..e50fa51 100644
--- a/atlas/ui/highlights.md
+++ b/atlas/ui/highlights.md
@@ -6,7 +6,7 @@ Custom groups (`ParleyQuestion`, `ParleyFileReference`, `ParleyChatReference`, `
 ## Key Behaviors
 - Applied via decoration providers with ephemeral extmarks per window viewport
 - Multi-window safe: independent redraw cache per window
-- Managed definition-footnote footers (`---` + `[^id]: ...`) use
+- Managed definition-footnote footers (from the first `[^id]: ...` line) use
   `ParleyFootnote` in chat and markdown buffers instead of inheriting the active
   chat exchange color.
 - `🌿:` lines auto-rendered with debounced topic lookup from referenced files
diff --git a/lua/parley/define.lua b/lua/parley/define.lua
index 44817c1..1d43845 100644
--- a/lua/parley/define.lua
+++ b/lua/parley/define.lua
@@ -168,22 +168,9 @@ local function is_footnote_line(line)
 end

 local function managed_footer_start(lines)
-    for i = #lines, 1, -1 do
-        if is_divider(lines[i]) then
-            local has_footnote = false
-            for j = i + 1, #lines do
-                local line = lines[j] or ""
-                if trim(line) ~= "" then
-                    if not is_footnote_line(line) then
-                        return nil
-                    end
-                    has_footnote = true
-                end
-            end
-            if has_footnote then
-                return i
-            end
-            return nil
+    for i, line in ipairs(lines or {}) do
+        if is_footnote_line(line) then
+            return i
         end
     end
     return nil
@@ -237,7 +224,7 @@ function M.footnote_diagnostics(lines)
     end

     local definitions = {}
-    for i = footer + 1, #lines do
+    for i = footer, #lines do
         local id, definition = parse_footnote_line(lines[i] or "")
         if id then
             definitions[id] = definition
@@ -312,6 +299,12 @@ function M.strip_definition_footnote_footer(text)
     while start > 1 and trim(lines[start - 1]) == "" do
         start = start - 1
     end
+    if start > 1 and is_divider(lines[start - 1]) then
+        start = start - 1
+        while start > 1 and trim(lines[start - 1]) == "" do
+            start = start - 1
+        end
+    end
     local kept = {}
     for i = 1, start - 1 do
         kept[#kept + 1] = lines[i]
@@ -327,7 +320,7 @@ local function replace_or_append_footnote(lines, id, definition)
     local footer = managed_footer_start(out)
     local footnote_line = M.format_footnote_line(id, definition)
     if footer then
-        for i = footer + 1, #out do
+        for i = footer, #out do
             local escaped_id = id:gsub("([^%w])", "%%%1")
             if trim(out[i]):match("^%[%^" .. escaped_id .. "%]:") then
                 out[i] = footnote_line
diff --git a/tests/integration/highlighting_spec.lua b/tests/integration/highlighting_spec.lua
index 43bf5f8..ee6748b 100644
--- a/tests/integration/highlighting_spec.lua
+++ b/tests/integration/highlighting_spec.lua
@@ -170,18 +170,12 @@ describe("highlight_question_block: managed footnote footer", function()
             "💬: Define ASIN",
             "This question is still open.",
             "",
-            "---",
-            "",
             "[^asin]: Amazon Standard Identification Number.",
         })

         assert.is_true(has_highlight(buf, 3, "ParleyFootnote"),
-            "Expected the managed footer divider to use ParleyFootnote")
-        assert.is_true(has_highlight(buf, 5, "ParleyFootnote"),
             "Expected the managed footnote definition to use ParleyFootnote")
         assert.is_false(has_highlight(buf, 3, "ParleyQuestion"),
-            "Managed footer divider should not inherit open-question color")
-        assert.is_false(has_highlight(buf, 5, "ParleyQuestion"),
             "Managed footnote definition should not inherit open-question color")
     end)
 end)
@@ -528,8 +522,6 @@ describe("markdown footnote diagnostics", function()
         vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
             "here is ASIN[^asin] in context",
             "",
-            "---",
-            "",
             "[^asin]: Amazon Standard Identification Number.",
         })

@@ -571,8 +563,6 @@ describe("markdown footnote diagnostics", function()
         vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
             "here is ASIN[^asin] in context",
             "",
-            "---",
-            "",
             "[^asin]: Amazon Standard Identification Number.",
         })
         vim.cmd("doautocmd TextChanged")
@@ -603,15 +593,13 @@ describe("markdown footnote diagnostics", function()
         vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
             "here is ASIN[^asin] in context",
             "",
-            "---",
-            "",
             "[^asin]: Amazon Standard Identification Number.",
         })
         parley._parley_bufs[buf] = "markdown"

         local win = vim.api.nvim_get_current_win()
         vim.api.nvim_win_set_buf(win, buf)
-        provider.on_win(nil, win, buf, 0, 4)
+        provider.on_win(nil, win, buf, 0, 2)

         local original_set_extmark = vim.api.nvim_buf_set_extmark
         local extmarks = {}
@@ -621,7 +609,6 @@ describe("markdown footnote diagnostics", function()
         end

         provider.on_line(nil, win, buf, 2)
-        provider.on_line(nil, win, buf, 4)

         vim.api.nvim_buf_set_extmark = original_set_extmark

@@ -631,8 +618,7 @@ describe("markdown footnote diagnostics", function()
                 highlighted[mark.row] = true
             end
         end
-        assert.is_true(highlighted[2], "Expected markdown footer divider to use ParleyFootnote")
-        assert.is_true(highlighted[4], "Expected markdown footnote definition to use ParleyFootnote")
+        assert.is_true(highlighted[2], "Expected markdown footnote definition to use ParleyFootnote")
     end)
 end)

diff --git a/tests/unit/define_spec.lua b/tests/unit/define_spec.lua
index d7b21ec..f7e6b5b 100644
--- a/tests/unit/define_spec.lua
+++ b/tests/unit/define_spec.lua
@@ -240,7 +240,17 @@ describe("define durable footnotes", function()
         assert.equals(text, define.strip_definition_footnote_footer(text))
     end)

-    it("reports the final managed footnote footer range", function()
+    it("reports a dividerless managed footnote footer range from the first definition", function()
+        local range = define.managed_footnote_footer_range({
+            "answer text",
+            "",
+            "[^asin]: Amazon Standard Identification Number.",
+        })
+
+        assert.are.same({ start_line = 3, end_line = 3 }, range)
+    end)
+
+    it("reports a divider-based managed footnote footer range from the first definition", function()
         local range = define.managed_footnote_footer_range({
             "answer text",
             "",
@@ -249,7 +259,7 @@ describe("define durable footnotes", function()
             "[^asin]: Amazon Standard Identification Number.",
         })

-        assert.are.same({ start_line = 3, end_line = 5 }, range)
+        assert.are.same({ start_line = 5, end_line = 5 }, range)
     end)

     it("does not report ordinary horizontal rules as managed footnote footers", function()
@@ -286,12 +296,20 @@ describe("define durable footnotes", function()
         }, "\n"), define.strip_definition_footnote_footer(text))
     end)

+    it("strips a final dividerless managed footnote footer", function()
+        local text = table.concat({
+            "answer text",
+            "",
+            "[^asin]: Amazon Standard Identification Number.",
+        }, "\n")
+
+        assert.equals("answer text", define.strip_definition_footnote_footer(text))
+    end)
+
     it("extracts persisted footnote diagnostics from the managed footer", function()
         local diagnostics = define.footnote_diagnostics({
             "here is ASIN[^asin] in context",
             "",
-            "---",
-            "",
             "[^asin]: Amazon Standard Identification Number.",
         })

@@ -336,17 +354,23 @@ describe("define durable footnotes", function()
         }, diagnostics[2])
     end)

-    it("ignores footnotes that are not in a final managed footer", function()
+    it("treats the first footnote definition as the footer even with trailing text", function()
         local diagnostics = define.footnote_diagnostics({
             "ASIN[^asin] in body",
             "",
-            "---",
-            "",
             "[^asin]: Amazon Standard Identification Number.",
             "",
             "trailing body text",
         })

-        assert.are.same({}, diagnostics)
+        assert.are.same({ {
+            id = "asin",
+            term = "ASIN",
+            definition = "Amazon Standard Identification Number.",
+            lnum = 0,
+            col = 0,
+            end_lnum = 0,
+            end_col = 11,
+        } }, diagnostics)
     end)
 end)


codex
I’ll use `superpowers-using-superpowers` first as required, then inspect the issue/plan and the changed code against the provided diff before giving the boundary verdict.
exec
/bin/zsh -lc "sed -n '1,220p' /Users/xianxu/workspace/ariadne/construct/adapted/superpowers-using-superpowers/SKILL.md && sdlc --help && sed -n '1,220p' workshop/lessons.md && sed -n '1,240p' workshop/issues/000178-recognize-footnote-footer-without-divider.md && sed -n '140,340p' lua/parley/define.lua" in /Users/xianxu/workspace/parley.nvim
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

## 2026-07-08 (#174)
- **`virt_lines_leftcol = true` means gutter/window-left anchoring, not buffer text-column anchoring.** #173 used it to escape Neovim's stock diagnostic-column indentation on long wrapped prose, but the follow-up screenshot showed the block starting in the line-number/sign gutter. For diagnostic text that should align with paragraph content, place the extmark at column 0 and omit `virt_lines_leftcol`; test the extmark options directly so "visible" does not regress into "misaligned."

## 2026-07-08 (#175)
- **Shared diagnostic display needs source-specific visibility predicates when sources mean different things.** Review diagnostics span an edit region and should show anywhere inside `lnum..end_lnum`; footnote diagnostics point at a precise `term[^id]` anchor and should show only when the cursor is inside `col..end_col`. A single "current line" predicate was too broad for footnotes. Rule: when multiple diagnostic sources share one renderer, test each source's visibility contract explicitly.

## 2026-07-08 (#176)
- **README snippets are consumers of user-facing UI behavior, not marketing fluff.** #176 updated atlas when footnote definitions moved from virtual lines to a centered float, but the close review caught README still saying "grey pop-under" for visual `<M-CR>`. Rule: when changing a visible command/keybinding behavior, grep README for the command, keybinding, and old UI nouns alongside atlas.

## 2026-07-08 (#171)
- **A new `config.highlight.*` override is user-facing even when it is optional.** #171 added `config.highlight.footnote` support in the highlighter and documented the highlight group in atlas, but the close review caught that the default config/reference table still omitted the key. Rule: whenever code reads a new config override key, update `lua/parley/config.lua`'s defaults in the same commit and grep README/atlas for config snippets that mirror those defaults.
- **Generated SDLC review sidecars are still committed artifacts.** The #171 close sidecar captured trailing whitespace from the review transcript and made `git diff --check base..HEAD` fail even though source files were clean. Rule: after any `sdlc close`/review sidecar generation, run `git diff --check <base>..HEAD -- workshop/plans/<issue>-*-review.md` (or strip trailing whitespace on the sidecar) before committing the close artifact.
---
id: 000178
status: working
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 0.27
started: 2026-07-08T23:33:32-07:00
---

# recognize footnote footer without divider

## Problem

The #171 footnote-coloring fix still defines a managed footnote footer as a final
`---` divider followed by `[^id]: ...` lines. The desired footer boundary is
simpler: the first markdown footnote definition line (`[^id]: ...`) starts the
footer, even when no divider is present.

## Spec

`parley.define.managed_footnote_footer_range(lines)` returns the range from the
first line that starts with a markdown footnote definition pattern (`[^id]:`) to
EOF. It no longer requires a preceding `---` divider.

All current consumers keep deriving from that helper (ARCH-DRY, ARCH-PURE):
footnote diagnostics, footer stripping, and chat/markdown highlighting should
adopt the new boundary without duplicating parser logic.

## Done when

- A buffer with `[^asin]: ...` and no preceding `---` is recognized as having a
  managed footnote footer starting at that line.
- Footnote diagnostics and `ParleyFootnote` highlighting work for dividerless
  footers.
- Existing divider-based footers remain supported, but the footer range starts at
  the first `[^id]:` line, not at `---`.

## Plan

- [x] Add failing pure tests for dividerless footer range and stripping.
- [x] Add/update integration coverage for diagnostics/highlighting with a
  dividerless footer.
- [x] Change the pure footer helper to scan for the first footnote definition
  line and let consumers derive from it.
- [x] Run focused unit/integration verification plus lint/diff checks.

## Estimate

Derived via `estimate-logic-v3.1` against the repo-local calibration source from
`sdlc estimate-source` (stale but canonical for this repo).

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.03 impl=0.00
item: lua-neovim design=0.05 impl=0.15
item: milestone-review design=0.00 impl=0.02
total: 0.27
```

## Log

### 2026-07-08

- User clarified the #171 footer check should be based on the first `[^id]:`
  footnote definition line instead of a `---` + footnote block. Design keeps the
  grammar in `parley.define.managed_footnote_footer_range` so diagnostics and
  highlighters remain derived consumers.
- TDD red: dividerless footer unit/integration tests failed because the detector
  still required a final divider block and consumers skipped the first footnote
  definition line.
- Implemented the pure detector as "first footnote definition line to EOF" and
  updated diagnostics/update/strip loops to consume from that returned boundary.
- Verification: `make lint` passed; `nvim --headless -c "PlenaryBustedFile
  tests/unit/define_spec.lua"` passed; `nvim --headless -c "PlenaryBustedFile
  tests/integration/highlighting_spec.lua"` passed; scoped `git diff --check`
  passed. Full `make test` still fails in unrelated
  `tests/unit/tools_builtin_find_spec.lua` only under the parallel full-suite
  runner; that spec passes directly.
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
    for i, line in ipairs(lines or {}) do
        if is_footnote_line(line) then
            return i
        end
    end
    return nil
end

--- Locate the final managed definition-footnote footer.
--- @param lines string[]|nil
--- @return table|nil { start_line: integer, end_line: integer } 1-based inclusive
function M.managed_footnote_footer_range(lines)
    lines = lines or {}
    local start = managed_footer_start(lines)
    if not start then
        return nil
    end
    return { start_line = start, end_line = #lines }
end

local function parse_footnote_line(line)
    local id, definition = trim(line):match("^%[%^([^%]]+)%]:%s*(.-)%s*$")
    if not id then
        return nil
    end
    definition = trim(definition)
    if definition == "" then
        definition = "(no definition)"
    end
    return id, definition
end

local function is_term_byte(ch)
    return ch:match("[%w_-]") ~= nil
end

local function expand_term_start(line, ref_start)
    local start = ref_start
    while start > 1 and is_term_byte(line:sub(start - 1, start - 1)) do
        start = start - 1
    end
    return start
end

--- Derive persisted definition diagnostics from inline footnote references and
--- the final managed definition footer.
--- @param lines string[]
--- @return table[] diagnostics with 0-based columns
function M.footnote_diagnostics(lines)
    lines = lines or {}
    local footer = managed_footer_start(lines)
    if not footer then
        return {}
    end

    local definitions = {}
    for i = footer, #lines do
        local id, definition = parse_footnote_line(lines[i] or "")
        if id then
            definitions[id] = definition
        end
    end

    local diagnostics = {}
    for lnum = 1, footer - 1 do
        local line = lines[lnum] or ""
        local search = 1
        while true do
            local ref_start, ref_end, id = line:find("%[%^([^%]]+)%]", search)
            if not ref_start then
                break
            end
            local definition = definitions[id]
            if definition then
                local term_start = expand_term_start(line, ref_start)
                local term = line:sub(term_start, ref_start - 1)
                table.insert(diagnostics, {
                    id = id,
                    term = term ~= "" and term or nil,
                    definition = definition,
                    lnum = lnum - 1,
                    col = term_start - 1,
                    end_lnum = lnum - 1,
                    end_col = ref_end,
                })
            end
            search = ref_end + 1
        end
    end
    return diagnostics
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
    if start > 1 and is_divider(lines[start - 1]) then
        start = start - 1
        while start > 1 and trim(lines[start - 1]) == "" do
            start = start - 1
        end
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
        for i = footer, #out do
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
    out[#out + 1] = ""
    out[#out + 1] = footnote_line

codex
I’ve got the issue contract and the main pure helper in view. The key question is whether “first footnote definition line starts the footer” was applied consistently without leaving old divider assumptions or widening behavior beyond the spec.
exec
/bin/zsh -lc "nl -ba lua/parley/define.lua | sed -n '150,340p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   150
   151    --- @param id string
   152    --- @param definition string|nil
   153    --- @return string
   154    function M.format_footnote_line(id, definition)
   155        definition = trim(definition)
   156        if definition == "" then
   157            definition = "(no definition)"
   158        end
   159        return string.format("[^%s]: %s", id, definition)
   160    end
   161
   162    local function is_divider(line)
   163        return trim(line) == "---"
   164    end
   165
   166    local function is_footnote_line(line)
   167        return trim(line):match("^%[%^[^%]]+%]:") ~= nil
   168    end
   169
   170    local function managed_footer_start(lines)
   171        for i, line in ipairs(lines or {}) do
   172            if is_footnote_line(line) then
   173                return i
   174            end
   175        end
   176        return nil
   177    end
   178
   179    --- Locate the final managed definition-footnote footer.
   180    --- @param lines string[]|nil
   181    --- @return table|nil { start_line: integer, end_line: integer } 1-based inclusive
   182    function M.managed_footnote_footer_range(lines)
   183        lines = lines or {}
   184        local start = managed_footer_start(lines)
   185        if not start then
   186            return nil
   187        end
   188        return { start_line = start, end_line = #lines }
   189    end
   190
   191    local function parse_footnote_line(line)
   192        local id, definition = trim(line):match("^%[%^([^%]]+)%]:%s*(.-)%s*$")
   193        if not id then
   194            return nil
   195        end
   196        definition = trim(definition)
   197        if definition == "" then
   198            definition = "(no definition)"
   199        end
   200        return id, definition
   201    end
   202
   203    local function is_term_byte(ch)
   204        return ch:match("[%w_-]") ~= nil
   205    end
   206
   207    local function expand_term_start(line, ref_start)
   208        local start = ref_start
   209        while start > 1 and is_term_byte(line:sub(start - 1, start - 1)) do
   210            start = start - 1
   211        end
   212        return start
   213    end
   214
   215    --- Derive persisted definition diagnostics from inline footnote references and
   216    --- the final managed definition footer.
   217    --- @param lines string[]
   218    --- @return table[] diagnostics with 0-based columns
   219    function M.footnote_diagnostics(lines)
   220        lines = lines or {}
   221        local footer = managed_footer_start(lines)
   222        if not footer then
   223            return {}
   224        end
   225
   226        local definitions = {}
   227        for i = footer, #lines do
   228            local id, definition = parse_footnote_line(lines[i] or "")
   229            if id then
   230                definitions[id] = definition
   231            end
   232        end
   233
   234        local diagnostics = {}
   235        for lnum = 1, footer - 1 do
   236            local line = lines[lnum] or ""
   237            local search = 1
   238            while true do
   239                local ref_start, ref_end, id = line:find("%[%^([^%]]+)%]", search)
   240                if not ref_start then
   241                    break
   242                end
   243                local definition = definitions[id]
   244                if definition then
   245                    local term_start = expand_term_start(line, ref_start)
   246                    local term = line:sub(term_start, ref_start - 1)
   247                    table.insert(diagnostics, {
   248                        id = id,
   249                        term = term ~= "" and term or nil,
   250                        definition = definition,
   251                        lnum = lnum - 1,
   252                        col = term_start - 1,
   253                        end_lnum = lnum - 1,
   254                        end_col = ref_end,
   255                    })
   256                end
   257                search = ref_end + 1
   258            end
   259        end
   260        return diagnostics
   261    end
   262
   263    local function split_text_lines(text)
   264        text = text or ""
   265        local lines = {}
   266        local start = 1
   267        while true do
   268            local nl = text:find("\n", start, true)
   269            if not nl then
   270                lines[#lines + 1] = text:sub(start)
   271                break
   272            end
   273            lines[#lines + 1] = text:sub(start, nl - 1)
   274            start = nl + 1
   275        end
   276        if #lines > 1 and lines[#lines] == "" then
   277            table.remove(lines)
   278        end
   279        return lines
   280    end
   281
   282    local function copy_lines(lines)
   283        local out = {}
   284        for i, line in ipairs(lines or {}) do
   285            out[i] = line
   286        end
   287        return out
   288    end
   289
   290    --- Strip a final managed definition-footnote footer from text.
   291    --- @param text string|nil
   292    --- @return string
   293    function M.strip_definition_footnote_footer(text)
   294        local lines = split_text_lines(text or "")
   295        local start = managed_footer_start(lines)
   296        if not start then
   297            return text or ""
   298        end
   299        while start > 1 and trim(lines[start - 1]) == "" do
   300            start = start - 1
   301        end
   302        if start > 1 and is_divider(lines[start - 1]) then
   303            start = start - 1
   304            while start > 1 and trim(lines[start - 1]) == "" do
   305                start = start - 1
   306            end
   307        end
   308        local kept = {}
   309        for i = 1, start - 1 do
   310            kept[#kept + 1] = lines[i]
   311        end
   312        while #kept > 0 and trim(kept[#kept]) == "" do
   313            table.remove(kept)
   314        end
   315        return table.concat(kept, "\n")
   316    end
   317
   318    local function replace_or_append_footnote(lines, id, definition)
   319        local out = copy_lines(lines)
   320        local footer = managed_footer_start(out)
   321        local footnote_line = M.format_footnote_line(id, definition)
   322        if footer then
   323            for i = footer, #out do
   324                local escaped_id = id:gsub("([^%w])", "%%%1")
   325                if trim(out[i]):match("^%[%^" .. escaped_id .. "%]:") then
   326                    out[i] = footnote_line
   327                    return out
   328                end
   329            end
   330            out[#out + 1] = footnote_line
   331            return out
   332        end
   333
   334        while #out > 0 and trim(out[#out]) == "" do
   335            table.remove(out)
   336        end
   337        out[#out + 1] = ""
   338        out[#out + 1] = "---"
   339        out[#out + 1] = ""
   340        out[#out + 1] = footnote_line

exec
/bin/zsh -lc "nl -ba tests/integration/highlighting_spec.lua | sed -n '150,210p;510,635p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   150            })
   151            assert.is_true(has_highlight(buf, 1, "ParleyFileReference"),
   152                "Expected 'ParleyFileReference' highlight on @@ file reference line")
   153        end)
   154
   155        it("does NOT apply ParleyFileReference highlight to @@ lines outside question blocks", function()
   156            local buf = highlighted_buf({
   157                "🤖:[Agent] See @@/some/file.lua here",
   158            })
   159            -- Row 0 is an answer line; ParleyFileReference should not be applied
   160            assert.is_false(has_highlight(buf, 0, "ParleyFileReference"),
   161                "ParleyFileReference should not appear on answer lines")
   162        end)
   163    end)
   164
   165    describe("highlight_question_block: managed footnote footer", function()
   166        after_each(cleanup_bufs)
   167
   168        it("uses a dedicated footnote highlight instead of open-question coloring", function()
   169            local buf = highlighted_buf({
   170                "💬: Define ASIN",
   171                "This question is still open.",
   172                "",
   173                "[^asin]: Amazon Standard Identification Number.",
   174            })
   175
   176            assert.is_true(has_highlight(buf, 3, "ParleyFootnote"),
   177                "Expected the managed footnote definition to use ParleyFootnote")
   178            assert.is_false(has_highlight(buf, 3, "ParleyQuestion"),
   179                "Managed footnote definition should not inherit open-question color")
   180        end)
   181    end)
   182
   183    describe("decoration provider cache", function()
   184        after_each(function()
   185            cleanup_extra_windows()
   186            cleanup_bufs()
   187        end)
   188
   189        it("keeps highlight caches isolated per window for the same buffer", function()
   190            local provider = capture_decoration_provider()
   191            assert.is_table(provider)
   192            assert.is_function(provider.on_win)
   193            assert.is_function(provider.on_line)
   194
   195            local buf = vim.api.nvim_create_buf(false, true)
   196            local lines = {}
   197            for i = 1, 120 do
   198                lines[i] = ("filler line %03d"):format(i)
   199            end
   200            lines[1] = "💬: top question"
   201            lines[71] = "💬: lower question"
   202            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
   203
   204            vim.cmd("vsplit")
   205            local wins = vim.api.nvim_tabpage_list_wins(0)
   206            assert.are.same(2, #wins)
   207            vim.api.nvim_win_set_buf(wins[1], buf)
   208            vim.api.nvim_win_set_buf(wins[2], buf)
   209
   210            parley._parley_bufs[buf] = "chat"
   510                for _, buf in ipairs(vim.api.nvim_list_bufs()) do
   511                    if vim.api.nvim_buf_is_valid(buf) then
   512                        pcall(vim.diagnostic.reset, skill_render.diag_namespace(), buf)
   513                    end
   514                end
   515            end
   516            cleanup_bufs()
   517        end)
   518
   519        it("publishes persisted managed footnotes as Parley diagnostics", function()
   520            local skill_render = require("parley.skill_render")
   521            local buf = vim.api.nvim_create_buf(false, true)
   522            vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
   523                "here is ASIN[^asin] in context",
   524                "",
   525                "[^asin]: Amazon Standard Identification Number.",
   526            })
   527
   528            skill_render.refresh_footnote_diagnostics(buf)
   529
   530            local diagnostics = vim.diagnostic.get(buf, { namespace = skill_render.diag_namespace() })
   531            assert.equals(1, #diagnostics)
   532            assert.equals(0, diagnostics[1].lnum)
   533            assert.equals(8, diagnostics[1].col)
   534            assert.equals(19, diagnostics[1].end_col)
   535            assert.equals("parley-footnote", diagnostics[1].source)
   536            assert.is_true(diagnostics[1].message:find("ASIN", 1, true) ~= nil)
   537            assert.is_true(diagnostics[1].message:find("Amazon Standard Identification Number.", 1, true) ~= nil)
   538        end)
   539
   540        it("refreshes footnote diagnostics on markdown text changes without clearing other Parley diagnostics", function()
   541            local skill_render = require("parley.skill_render")
   542            local ns = skill_render.diag_namespace()
   543            local buf = vim.api.nvim_create_buf(false, true)
   544            vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), buf)
   545            parley._parley_bufs[buf] = "markdown"
   546            vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
   547                "no footnote yet",
   548            })
   549            vim.diagnostic.set(ns, buf, { {
   550                lnum = 0,
   551                col = 0,
   552                message = "review diagnostic",
   553                severity = vim.diagnostic.severity.INFO,
   554                source = "parley-skill",
   555            } })
   556
   557            vim.cmd("doautocmd TextChanged")
   558            vim.wait(100, function()
   559                local diagnostics = vim.diagnostic.get(buf, { namespace = ns })
   560                return #diagnostics == 1 and diagnostics[1].source == "parley-skill"
   561            end)
   562
   563            vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
   564                "here is ASIN[^asin] in context",
   565                "",
   566                "[^asin]: Amazon Standard Identification Number.",
   567            })
   568            vim.cmd("doautocmd TextChanged")
   569            vim.wait(100, function()
   570                local diagnostics = vim.diagnostic.get(buf, { namespace = ns })
   571                return #diagnostics == 2
   572            end)
   573
   574            local by_source = {}
   575            for _, diagnostic in ipairs(vim.diagnostic.get(buf, { namespace = ns })) do
   576                by_source[diagnostic.source] = diagnostic
   577            end
   578            assert.is_not_nil(by_source["parley-skill"])
   579            assert.is_not_nil(by_source["parley-footnote"])
   580            assert.equals(8, by_source["parley-footnote"].col)
   581
   582            vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "footnote removed" })
   583            vim.cmd("doautocmd TextChanged")
   584            vim.wait(100, function()
   585                local diagnostics = vim.diagnostic.get(buf, { namespace = ns })
   586                return #diagnostics == 1 and diagnostics[1].source == "parley-skill"
   587            end)
   588        end)
   589
   590        it("renders managed footnote footers with ParleyFootnote in markdown buffers", function()
   591            local provider = capture_decoration_provider()
   592            local buf = vim.api.nvim_create_buf(false, true)
   593            vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
   594                "here is ASIN[^asin] in context",
   595                "",
   596                "[^asin]: Amazon Standard Identification Number.",
   597            })
   598            parley._parley_bufs[buf] = "markdown"
   599
   600            local win = vim.api.nvim_get_current_win()
   601            vim.api.nvim_win_set_buf(win, buf)
   602            provider.on_win(nil, win, buf, 0, 2)
   603
   604            local original_set_extmark = vim.api.nvim_buf_set_extmark
   605            local extmarks = {}
   606            vim.api.nvim_buf_set_extmark = function(_, _, row, _, opts)
   607                table.insert(extmarks, { row = row, hl_group = opts.hl_group })
   608                return #extmarks
   609            end
   610
   611            provider.on_line(nil, win, buf, 2)
   612
   613            vim.api.nvim_buf_set_extmark = original_set_extmark
   614
   615            local highlighted = {}
   616            for _, mark in ipairs(extmarks) do
   617                if mark.hl_group == "ParleyFootnote" then
   618                    highlighted[mark.row] = true
   619                end
   620            end
   621            assert.is_true(highlighted[2], "Expected markdown footnote definition to use ParleyFootnote")
   622        end)
   623    end)
   624
   625    describe("markdown chat reference rendering", function()
   626        after_each(function()
   627            cleanup_extra_windows()
   628            cleanup_bufs()
   629        end)
   630
   631        it("refreshes 🌿: branch lines with the chat topic in markdown buffers", function()
   632            local chat_path = tmp_dir .. "/2026-03-24.12-34-56.123.md"
   633            vim.fn.writefile({
   634                "---",
   635                "topic: Rendered Topic",

exec
/bin/zsh -lc "nl -ba tests/unit/define_spec.lua | sed -n '220,380p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   220            local text = table.concat({
   221                "answer text",
   222                "",
   223                "---",
   224                "",
   225                "[^asin]: Amazon Standard Identification Number.",
   226            }, "\n")
   227
   228            assert.equals("answer text", define.strip_definition_footnote_footer(text))
   229        end)
   230
   231        it("preserves ordinary horizontal rules that are not managed footnote footers", function()
   232            local text = table.concat({
   233                "answer text",
   234                "",
   235                "---",
   236                "",
   237                "not a footnote",
   238            }, "\n")
   239
   240            assert.equals(text, define.strip_definition_footnote_footer(text))
   241        end)
   242
   243        it("reports a dividerless managed footnote footer range from the first definition", function()
   244            local range = define.managed_footnote_footer_range({
   245                "answer text",
   246                "",
   247                "[^asin]: Amazon Standard Identification Number.",
   248            })
   249
   250            assert.are.same({ start_line = 3, end_line = 3 }, range)
   251        end)
   252
   253        it("reports a divider-based managed footnote footer range from the first definition", function()
   254            local range = define.managed_footnote_footer_range({
   255                "answer text",
   256                "",
   257                "---",
   258                "",
   259                "[^asin]: Amazon Standard Identification Number.",
   260            })
   261
   262            assert.are.same({ start_line = 5, end_line = 5 }, range)
   263        end)
   264
   265        it("does not report ordinary horizontal rules as managed footnote footers", function()
   266            local range = define.managed_footnote_footer_range({
   267                "answer text",
   268                "",
   269                "---",
   270                "",
   271                "not a footnote",
   272            })
   273
   274            assert.is_nil(range)
   275        end)
   276
   277        it("keeps earlier horizontal-rule content and strips only the final managed footer", function()
   278            local text = table.concat({
   279                "answer text",
   280                "",
   281                "---",
   282                "",
   283                "ordinary body after a rule",
   284                "",
   285                "---",
   286                "",
   287                "[^asin]: Amazon Standard Identification Number.",
   288            }, "\n")
   289
   290            assert.equals(table.concat({
   291                "answer text",
   292                "",
   293                "---",
   294                "",
   295                "ordinary body after a rule",
   296            }, "\n"), define.strip_definition_footnote_footer(text))
   297        end)
   298
   299        it("strips a final dividerless managed footnote footer", function()
   300            local text = table.concat({
   301                "answer text",
   302                "",
   303                "[^asin]: Amazon Standard Identification Number.",
   304            }, "\n")
   305
   306            assert.equals("answer text", define.strip_definition_footnote_footer(text))
   307        end)
   308
   309        it("extracts persisted footnote diagnostics from the managed footer", function()
   310            local diagnostics = define.footnote_diagnostics({
   311                "here is ASIN[^asin] in context",
   312                "",
   313                "[^asin]: Amazon Standard Identification Number.",
   314            })
   315
   316            assert.are.same({ {
   317                id = "asin",
   318                term = "ASIN",
   319                definition = "Amazon Standard Identification Number.",
   320                lnum = 0,
   321                col = 8,
   322                end_lnum = 0,
   323                end_col = 19,
   324            } }, diagnostics)
   325        end)
   326
   327        it("extracts every inline reference to a managed footnote", function()
   328            local diagnostics = define.footnote_diagnostics({
   329                "ASIN[^asin] first, then SKU[^asin] second",
   330                "",
   331                "---",
   332                "",
   333                "[^asin]: Amazon Standard Identification Number.",
   334            })
   335
   336            assert.are.equal(2, #diagnostics)
   337            assert.are.same({
   338                id = "asin",
   339                term = "ASIN",
   340                definition = "Amazon Standard Identification Number.",
   341                lnum = 0,
   342                col = 0,
   343                end_lnum = 0,
   344                end_col = 11,
   345            }, diagnostics[1])
   346            assert.are.same({
   347                id = "asin",
   348                term = "SKU",
   349                definition = "Amazon Standard Identification Number.",
   350                lnum = 0,
   351                col = 24,
   352                end_lnum = 0,
   353                end_col = 34,
   354            }, diagnostics[2])
   355        end)
   356
   357        it("treats the first footnote definition as the footer even with trailing text", function()
   358            local diagnostics = define.footnote_diagnostics({
   359                "ASIN[^asin] in body",
   360                "",
   361                "[^asin]: Amazon Standard Identification Number.",
   362                "",
   363                "trailing body text",
   364            })
   365
   366            assert.are.same({ {
   367                id = "asin",
   368                term = "ASIN",
   369                definition = "Amazon Standard Identification Number.",
   370                lnum = 0,
   371                col = 0,
   372                end_lnum = 0,
   373                end_col = 11,
   374            } }, diagnostics)
   375        end)
   376    end)

exec
/bin/zsh -lc 'git diff --stat c481296d642c30cfbddbe1b5fd62c6265b397fe3..HEAD && git diff --name-only c481296d642c30cfbddbe1b5fd62c6265b397fe3..HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
 atlas/chat/inline_define.md                        | 23 ++++-----
 atlas/ui/highlights.md                             |  2 +-
 lua/parley/define.lua                              | 29 ++++-------
 tests/integration/highlighting_spec.lua            | 18 +------
 tests/unit/define_spec.lua                         | 40 ++++++++++++---
 ...78-recognize-footnote-footer-without-divider.md | 59 ++++++++++++++++++++--
 6 files changed, 112 insertions(+), 59 deletions(-)
atlas/chat/inline_define.md
atlas/ui/highlights.md
lua/parley/define.lua
tests/integration/highlighting_spec.lua
tests/unit/define_spec.lua
workshop/issues/000178-recognize-footnote-footer-without-divider.md

codex
The diff has no new user-facing command/config surface, so the README gate looks likely not applicable. Atlas was updated in the two places that explicitly described the footer boundary.
exec
/bin/zsh -lc 'rg -n "managed_footnote_footer_range|footnote_diagnostics|strip_definition_footnote_footer|ParleyFootnote|managed footer|footnote footer|%[%''^" lua tests atlas README.md' in /Users/xianxu/workspace/parley.nvim
 exited 2 in 0ms:
rg: regex parse error:
    (?:managed_footnote_footer_range|footnote_diagnostics|strip_definition_footnote_footer|ParleyFootnote|managed footer|footnote footer|%[%^)
                                                                                                                                          ^
error: unclosed character class

exec
/bin/zsh -lc 'git diff --check c481296d642c30cfbddbe1b5fd62c6265b397fe3..HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
exec
/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"' in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"' in /Users/xianxu/workspace/parley.nvim
 succeeded in 1502ms:

Error detected while processing /Users/xianxu/.config/nvim/init.lua:
Parser dir ' /Users/xianxu/.local/share/nvim/lazy/nvim-treesitter/parser ' should be read/write (see README on how to configure an alternative install location) /Users/xianxu/.local/share/nvim/lazy/nvim-treesitter/parser '
Parley.nvim: Failed to open file for writing: /Users/xianxu/.local/share/nvim/parley/persisted/state.jsonScheduling: tests/unit/define_spec.lua

========================================
Testing:     /Users/xianxu/workspace/parley.nvim/tests/unit/define_spec.lua
[32mSuccess[0m    ||    define.slice_selection extracts a single-line span
[32mSuccess[0m    ||    define.slice_selection extracts a multi-line span joined with newline
[32mSuccess[0m    ||    define.slice_selection clamps an end column past line length
[32mSuccess[0m    ||    define.slice_selection returns empty string for a reversed/empty span
[32mSuccess[0m    ||    define.context_for_selection returns the enclosing exchange's lines (question..answer)
[32mSuccess[0m    ||    define.context_for_selection handles an answerless exchange (question only)
[32mSuccess[0m    ||    define.context_for_selection falls back to the whole buffer when outside any exchange
[32mSuccess[0m    ||    define.format_definition composes 'TERM — definition'
[32mSuccess[0m    ||    define.format_definition hard-wraps to width
[32mSuccess[0m    ||    define.format_definition passes nil width through to the shared diagnostic formatter
[32mSuccess[0m    ||    define.format_definition trims a nil/blank definition to a safe string
[32mSuccess[0m    ||    define.bracket_edit wraps a single-line span into a set_lines edit
[32mSuccess[0m    ||    define.bracket_edit clamps end col past line length
[32mSuccess[0m    ||    define.bracket_edit wraps a multi-line span
[32mSuccess[0m    ||    define.diagnostic_span_after_bracket anchors a single-line selection on the selected text after brackets
[32mSuccess[0m    ||    define.diagnostic_span_after_bracket anchors a multi-line selection without shifting the final line
[32mSuccess[0m    ||    define durable footnotes slugifies a definition term into a markdown footnote id
[32mSuccess[0m    ||    define durable footnotes adds an inline footnote reference and appends a managed footer
[32mSuccess[0m    ||    define durable footnotes updates an existing managed footnote instead of duplicating it
[32mSuccess[0m    ||    define durable footnotes updates an existing inline reference without duplicating it
[32mSuccess[0m    ||    define durable footnotes strips only a final managed footnote footer
[32mSuccess[0m    ||    define durable footnotes preserves ordinary horizontal rules that are not managed footnote footers
[32mSuccess[0m    ||    define durable footnotes reports a dividerless managed footnote footer range from the first definition
[32mSuccess[0m    ||    define durable footnotes reports a divider-based managed footnote footer range from the first definition
[32mSuccess[0m    ||    define durable footnotes does not report ordinary horizontal rules as managed footnote footers
[32mSuccess[0m    ||    define durable footnotes keeps earlier horizontal-rule content and strips only the final managed footer
[32mSuccess[0m    ||    define durable footnotes strips a final dividerless managed footnote footer
[32mSuccess[0m    ||    define durable footnotes extracts persisted footnote diagnostics from the managed footer
[32mSuccess[0m    ||    define durable footnotes extracts every inline reference to a managed footnote
[32mSuccess[0m    ||    define durable footnotes treats the first footnote definition as the footer even with trailing text

[32mSuccess: [0m    30
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
]111
 succeeded in 2169ms:

Parley.nvim: Failed to open file for writing: /Users/xianxu/.local/share/nvim/parley/persisted/state.jsonScheduling: tests/integration/highlighting_spec.lua

========================================
Testing:     /Users/xianxu/workspace/parley.nvim/tests/integration/highlighting_spec.lua
[32mSuccess[0m    ||    highlight_question_block: question lines applies Question highlight to 💬: line (row 0)
[32mSuccess[0m    ||    highlight_question_block: question lines applies ParleyQuestion highlight to continuation lines of a question block
[32mSuccess[0m    ||    highlight_question_block: question lines does NOT apply ParleyQuestion highlight to 🤖: answer lines
[32mSuccess[0m    ||    highlight_question_block: thinking lines applies Think highlight to 📝: summary line
[32mSuccess[0m    ||    highlight_question_block: thinking lines applies ParleyThinking highlight to 🧠: reasoning line
[32mSuccess[0m    ||    highlight_question_block: file reference lines applies FileLoading highlight to @@ file reference lines in a question block
[32mSuccess[0m    ||    highlight_question_block: file reference lines does NOT apply ParleyFileReference highlight to @@ lines outside question blocks
[32mSuccess[0m    ||    highlight_question_block: managed footnote footer uses a dedicated footnote highlight instead of open-question coloring
[32mSuccess[0m    ||    decoration provider cache keeps highlight caches isolated per window for the same buffer
[32mSuccess[0m    ||    decoration provider cache dims thinking-block continuation lines when viewport top falls between 🧠: and 🧠:[END]
[32mSuccess[0m    ||    decoration provider cache dims streaming thinking-block continuation lines before 🧠:[END] is emitted
[32mSuccess[0m    ||    decoration provider cache restores question highlights when redraw starts inside a long unanswered question
[32mSuccess[0m    ||    timezone diagnostics publishes local-time diagnostics in its own namespace and clears stale diagnostics
[32mSuccess[0m    ||    timezone diagnostics refreshes diagnostics for registered buffers on text changes
[32mSuccess[0m    ||    markdown footnote diagnostics publishes persisted managed footnotes as Parley diagnostics
[32mSuccess[0m    ||    markdown footnote diagnostics refreshes footnote diagnostics on markdown text changes without clearing other Parley diagnostics
[32mSuccess[0m    ||    markdown footnote diagnostics renders managed footnote footers with ParleyFootnote in markdown buffers
[32mSuccess[0m    ||    markdown chat reference rendering refreshes 🌿: branch lines with the chat topic in markdown buffers
[32mSuccess[0m    ||    markdown chat reference rendering does not rewrite 🌿: lines pointing to non-chat files in markdown buffers
[32mSuccess[0m    ||    markdown chat reference rendering refreshes from the updated topic in an open unsaved chat buffer

[32mSuccess: [0m    20
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
]111
exec
/bin/zsh -lc 'rg -n -F "[''^" lua tests atlas README.md' in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc 'rg -n "managed_footnote_footer_range|footnote_diagnostics|strip_definition_footnote_footer|ParleyFootnote|managed footer|footnote footer" lua tests atlas README.md' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
lua/parley/define.lua:179:--- Locate the final managed definition-footnote footer.
lua/parley/define.lua:182:function M.managed_footnote_footer_range(lines)
lua/parley/define.lua:219:function M.footnote_diagnostics(lines)
lua/parley/define.lua:290:--- Strip a final managed definition-footnote footer from text.
lua/parley/define.lua:293:function M.strip_definition_footnote_footer(text)
lua/parley/define.lua:345:--- definition in a managed footer.
lua/parley/highlighter.lua:270:    local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
lua/parley/highlighter.lua:303:            table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
lua/parley/highlighter.lua:471:    local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
lua/parley/highlighter.lua:478:            table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
lua/parley/highlighter.lua:747:    -- Managed definition-footnote footer (`---` + `[^id]: ...`). It must be
lua/parley/highlighter.lua:750:        vim.api.nvim_set_hl(0, "ParleyFootnote", user_highlights.footnote)
lua/parley/highlighter.lua:752:        vim.api.nvim_set_hl(0, "ParleyFootnote", { link = "DiagnosticHint" })
lua/parley/highlighter.lua:1098:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1111:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1133:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1138:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1149:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/chat_respond.lua:378:                text = define.strip_definition_footnote_footer(text)
lua/parley/chat_respond.lua:390:                local text = define.strip_definition_footnote_footer(read_block_text(k, b))
lua/parley/chat_respond.lua:409:                    table.insert(answer_blocks, { type = "text", text = define.strip_definition_footnote_footer(text) })
lua/parley/chat_respond.lua:427:                    table.insert(messages, { role = "user", content = define.strip_definition_footnote_footer(text) })
lua/parley/chat_respond.lua:616:                copy.text = define.strip_definition_footnote_footer(copy.text)
lua/parley/chat_respond.lua:702:                    local question_content = define.strip_definition_footnote_footer(exchange.question.content)
lua/parley/chat_respond.lua:807:                        table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.answer.content) })
lua/parley/chat_respond.lua:812:                        table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.summary.content) })
lua/parley/chat_respond.lua:820:                            table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.answer.content) })
lua/parley/config.lua:649:        footnote = nil, -- highlight for managed definition-footnote footer lines (default: links to DiagnosticHint)
atlas/chat/inline_define.md:6:(`ASIN[^asin]`), while the definition is stored in a managed footnote footer at
atlas/chat/inline_define.md:35:   and inserts/updates a final managed footnote footer via one buffer rewrite
atlas/chat/inline_define.md:39:   footnote diagnostics (`skill_render.refresh_footnote_diagnostics`), which
atlas/chat/inline_define.md:40:   parses the managed footer and sets INFO `vim.diagnostic` entries on matching
atlas/chat/inline_define.md:68:  `strip_definition_footnote_footer` / `footnote_diagnostics` (treat the first
atlas/chat/inline_define.md:69:  markdown footnote definition line as the managed footer boundary).
atlas/chat/inline_define.md:89:`chat_respond.build_messages` strips this managed footer from message strings
atlas/chat/inline_define.md:91:`define.footnote_diagnostics` uses the same footer detector to scan inline
atlas/chat/inline_define.md:123:- `skill_render.refresh_footnote_diagnostics` owns only diagnostics tagged
atlas/chat/inline_define.md:131:- `lua/parley/define.lua` — pure core (slice / context / format / footnote footer / diagnostics).
atlas/chat/inline_define.md:135:- `lua/parley/chat_respond.lua` — strips managed footnote footer from LLM messages.
lua/parley/skill_render.lua:114:function M.refresh_footnote_diagnostics(buf)
lua/parley/skill_render.lua:132:    for _, footnote in ipairs(define.footnote_diagnostics(lines)) do
lua/parley/skills/review/diag_display.lua:175:    local footnote_diagnostics = {}
lua/parley/skills/review/diag_display.lua:179:                table.insert(footnote_diagnostics, diagnostic)
lua/parley/skills/review/diag_display.lua:186:    table.sort(footnote_diagnostics, function(a, b)
lua/parley/skills/review/diag_display.lua:189:    show_float(footnote_diagnostics)
lua/parley/init.lua:1645:    skill_render.refresh_footnote_diagnostics(buf)
tests/unit/parse_chat_spec.lua:667:    it("stops a final open question before a managed footnote footer", function()
tests/unit/define_spec.lua:152:    it("adds an inline footnote reference and appends a managed footer", function()
tests/unit/define_spec.lua:219:    it("strips only a final managed footnote footer", function()
tests/unit/define_spec.lua:228:        assert.equals("answer text", define.strip_definition_footnote_footer(text))
tests/unit/define_spec.lua:231:    it("preserves ordinary horizontal rules that are not managed footnote footers", function()
tests/unit/define_spec.lua:240:        assert.equals(text, define.strip_definition_footnote_footer(text))
tests/unit/define_spec.lua:243:    it("reports a dividerless managed footnote footer range from the first definition", function()
tests/unit/define_spec.lua:244:        local range = define.managed_footnote_footer_range({
tests/unit/define_spec.lua:253:    it("reports a divider-based managed footnote footer range from the first definition", function()
tests/unit/define_spec.lua:254:        local range = define.managed_footnote_footer_range({
tests/unit/define_spec.lua:265:    it("does not report ordinary horizontal rules as managed footnote footers", function()
tests/unit/define_spec.lua:266:        local range = define.managed_footnote_footer_range({
tests/unit/define_spec.lua:277:    it("keeps earlier horizontal-rule content and strips only the final managed footer", function()
tests/unit/define_spec.lua:296:        }, "\n"), define.strip_definition_footnote_footer(text))
tests/unit/define_spec.lua:299:    it("strips a final dividerless managed footnote footer", function()
tests/unit/define_spec.lua:306:        assert.equals("answer text", define.strip_definition_footnote_footer(text))
tests/unit/define_spec.lua:309:    it("extracts persisted footnote diagnostics from the managed footer", function()
tests/unit/define_spec.lua:310:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:328:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:358:        local diagnostics = define.footnote_diagnostics({
atlas/ui/highlights.md:4:Custom groups (`ParleyQuestion`, `ParleyFileReference`, `ParleyChatReference`, `ParleyThinking`, `ParleyAnnotation`, `ParleyReference`, `ParleyFootnote`, `ParleyPickerApproximateMatch`, `InterviewTimestamp`, `InterviewThought`) linked to standard Neovim groups. `ParleyReference` (default underline) marks drill-in `[referenced span]` brackets — see [chat/drill_in](../chat/drill_in.md). `ParleyFootnote` (default `DiagnosticHint`) marks managed definition-footnote footer lines.
atlas/ui/highlights.md:9:- Managed definition-footnote footers (from the first `[^id]: ...` line) use
atlas/ui/highlights.md:10:  `ParleyFootnote` in chat and markdown buffers instead of inheriting the active
tests/unit/build_messages_spec.lua:708:    it("strips managed definition footnote footers from user and assistant content", function()
tests/unit/build_messages_spec.lua:745:    it("preserves ordinary horizontal-rule content that is not a managed footer", function()
tests/unit/build_messages_spec.lua:772:    it("keeps earlier horizontal-rule content and strips only the final managed footer", function()
tests/unit/build_messages_spec.lua:1608:    it("strips managed footnote footers from live question and answer blocks", function()
tests/integration/highlighting_spec.lua:165:describe("highlight_question_block: managed footnote footer", function()
tests/integration/highlighting_spec.lua:176:        assert.is_true(has_highlight(buf, 3, "ParleyFootnote"),
tests/integration/highlighting_spec.lua:177:            "Expected the managed footnote definition to use ParleyFootnote")
tests/integration/highlighting_spec.lua:528:        skill_render.refresh_footnote_diagnostics(buf)
tests/integration/highlighting_spec.lua:590:    it("renders managed footnote footers with ParleyFootnote in markdown buffers", function()
tests/integration/highlighting_spec.lua:617:            if mark.hl_group == "ParleyFootnote" then
tests/integration/highlighting_spec.lua:621:        assert.is_true(highlighted[2], "Expected markdown footnote definition to use ParleyFootnote")

 succeeded in 0ms:
lua/parley/define.lua:143:    id = id:gsub("[^%w]+", "-")
lua/parley/define.lua:159:    return string.format("[^%s]: %s", id, definition)
lua/parley/define.lua:167:    return trim(line):match("^%[%^[^%]]+%]:") ~= nil
lua/parley/define.lua:192:    local id, definition = trim(line):match("^%[%^([^%]]+)%]:%s*(.-)%s*$")
lua/parley/define.lua:239:            local ref_start, ref_end, id = line:find("%[%^([^%]]+)%]", search)
lua/parley/define.lua:324:            local escaped_id = id:gsub("([^%w])", "%%%1")
lua/parley/define.lua:356:    local ref = "[^" .. id .. "]"
lua/parley/chat_slug.lua:30:    s = s:gsub("[^%a%d%s%-]", "")
lua/parley/chat_slug.lua:42:    for word in s:gmatch("[^%-]+") do
lua/parley/memory_prefs.lua:106:                for tag in tag_str:gmatch("[^,%s]+") do
lua/parley/highlighter.lua:448:--   * footnote refs                 — `[^1]`
lua/parley/highlighter.lua:527:            for s, content, e in line:gmatch("()%[([^%[%]]+)%]()") do
lua/parley/highlighter.lua:747:    -- Managed definition-footnote footer (`---` + `[^id]: ...`). It must be
atlas/modes/review.md:178:cursor is inside the term/`[^footnote]` diagnostic span.
lua/parley/providers.lua:338:    for line in raw_response:gmatch("([^\n]+)") do
lua/parley/providers.lua:356:        usage_json = raw_response:match('{"id":"[^"]*","object":"chat%.completion%.chunk"[^}]*"choices":%[%][^}]*"usage":{[^}]*}}')
lua/parley/providers.lua:361:        for line in raw_response:gmatch("([^\n]+)") do
lua/parley/providers.lua:607:    for line in raw_response:gmatch("[^\n]+") do
lua/parley/providers.lua:631:        local usage_json = raw_response:match('("usage":%s*{[^{}]*})')
lua/parley/providers.lua:691:    for line in raw_response:gmatch("[^\n]+") do
lua/parley/providers.lua:895:    local uri = line:match('"uri"%s*:%s*"([^"]+)"') or line:match('\\"uri\\"%s*:%s*\\"([^"]+)\\"')
lua/parley/providers.lua:926:    local usage_pattern = '"usageMetadata":%s*{[^}]*"promptTokenCount":%s*(%d+)[^}]*"candidatesTokenCount":%s*(%d+)[^}]*"totalTokenCount":%s*(%d+)[^}]*'
lua/parley/providers.lua:936:        local escaped_pattern = '\\\"usageMetadata\\\":%s*{[^}]*\\\"promptTokenCount\\\":%s*(%d+)[^}]*\\\"candidatesTokenCount\\\":%s*(%d+)[^}]*\\\"totalTokenCount\\\":%s*(%d+)[^}]*'
lua/parley/providers.lua:1186:    for line in raw_response:gmatch("([^\n]+)") do
lua/parley/exporter.lua:13:    local slug = title:gsub("[^%w%s%-_]", ""):gsub("%s+", "_"):lower()
lua/parley/exporter.lua:49:    return path:match("[^/]+$") or path
lua/parley/exporter.lua:55:    return base:match("^(.+)%.[^%.]+$") or base
lua/parley/exporter.lua:265:            local path, topic = rest:match("^%s*([^:]+)%s*:%s*(.-)%s*$")
lua/parley/exporter.lua:352:    html = html:gsub("```([^\n]*)\n(.-)\n```", function(lang, code)
lua/parley/exporter.lua:365:    html = html:gsub("`([^`\n]+)`", '<code class="inline-code">%1</code>')
lua/parley/exporter.lua:368:    html = html:gsub("^# ([^\n]+)", '<h1 class="main-header">%1</h1>')
lua/parley/exporter.lua:369:    html = html:gsub("\n# ([^\n]+)", '\n<h1 class="main-header">%1</h1>')
lua/parley/exporter.lua:370:    html = html:gsub("^## ([^\n]+)", '<h2 class="section-header">%1</h2>')
lua/parley/exporter.lua:371:    html = html:gsub("\n## ([^\n]+)", '\n<h2 class="section-header">%1</h2>')
lua/parley/exporter.lua:372:    html = html:gsub("^### ([^\n]+)", '<h3 class="sub-header">%1</h3>')
lua/parley/exporter.lua:373:    html = html:gsub("\n### ([^\n]+)", '\n<h3 class="sub-header">%1</h3>')
lua/parley/exporter.lua:376:    html = html:gsub("%*%*([^%*\n]+)%*%*", '<strong class="bold-text">%1</strong>')
lua/parley/exporter.lua:377:    html = html:gsub("__([^_\n]+)__", '<strong class="bold-text">%1</strong>')
lua/parley/exporter.lua:378:    html = html:gsub("%*([^%*\n]+)%*", '<em class="italic-text">%1</em>')
lua/parley/exporter.lua:379:    html = html:gsub("_([^_\n]+)_", '<em class="italic-text">%1</em>')
lua/parley/exporter.lua:382:    html = html:gsub("\n%- ([^\n]+)", '\n<li class="list-item">%1</li>')
lua/parley/exporter.lua:383:    html = html:gsub("(<li[^>]*>.-</li>)", '<ul class="bullet-list">%1</ul>')
lua/parley/exporter.lua:386:    html = html:gsub("\n> ([^\n]+)", '\n<blockquote class="quote">%1</blockquote>')
lua/parley/exporter.lua:393:    html = html:gsub("<p[^>]*>%s*<h", "<h")
lua/parley/exporter.lua:395:    html = html:gsub("<p[^>]*>%s*<div", "<div")
lua/parley/exporter.lua:397:    html = html:gsub("<p[^>]*>%s*<ul", "<ul")
lua/parley/exporter.lua:399:    html = html:gsub("<p[^>]*>%s*<blockquote", "<blockquote")
lua/parley/exporter.lua:401:    html = html:gsub("<p[^>]*>%s*</p>", "")
lua/parley/exporter.lua:675:        body_html = body_html:gsub("<p[^>]*>%s*" .. key .. "%s*</p>", replacement)
lua/parley/interview.lua:127:    local thought_id = vim.fn.matchadd("InterviewThought", "{[^}]\\+}", -1)
lua/parley/render_buffer.lua:105:    for line in pretty:gmatch("[^\n]+") do
lua/parley/log_emit.lua:68:    for line in (body .. "\n"):gmatch("([^\n]*)\n") do
lua/parley/log_emit.lua:285:    return source:gsub("/[^/]+$", "") .. "/../../scripts/yaml_to_json.py"
atlas/chat/inline_define.md:6:(`ASIN[^asin]`), while the definition is stored in a managed footnote footer at
atlas/chat/inline_define.md:34:   in-flight call), then **(a)** adds a `[^id]` reference after the selected term
atlas/chat/inline_define.md:41:   inline `term[^id]` spans (`define.format_definition` →
atlas/chat/inline_define.md:83:[^asin]: Amazon Standard Identification Number.
atlas/chat/inline_define.md:88:along with the footer, but the canonical boundary is the `[^id]: ...` line.
atlas/chat/inline_define.md:92:references before the footer and produce diagnostics for each matching `[^id]`.
atlas/chat/inline_define.md:121:- The fresh define highlight spans the selected text plus immediate `[^id]`
lua/parley/artifact_ref.lua:96:    for ln in (stdout or ""):gmatch("[^\n]+") do
lua/parley/oauth.lua:9:    { pattern = "docs%.google%.com/document/d/([^/&#]+)", file_type = "document" },
lua/parley/oauth.lua:10:    { pattern = "docs%.google%.com/spreadsheets/d/([^/&#]+)", file_type = "spreadsheet" },
lua/parley/oauth.lua:11:    { pattern = "docs%.google%.com/presentation/d/([^/&#]+)", file_type = "presentation" },
lua/parley/oauth.lua:12:    { pattern = "drive%.google%.com/file/d/([^/&#]+)", file_type = "drive_file" },
lua/parley/oauth.lua:16:    { pattern = "dropbox%.com/s/[^/?#]+/([^?#]+)", link_type = "file" },
lua/parley/oauth.lua:17:    { pattern = "dropbox%.com/scl/fi/[^/?#]+/([^?#]+)", link_type = "file" },
lua/parley/oauth.lua:18:    { pattern = "dropbox%.com/sh/[^/?#]+/([^?#]+)", link_type = "folder" },
lua/parley/oauth.lua:19:    { pattern = "dropbox%.com/scl/fo/[^/?#]+/([^?#]+)", link_type = "folder" },
lua/parley/oauth.lua:68:    local base, query = url:match("^([^?#]+)%??([^#]*)")
lua/parley/oauth.lua:74:    for pair in query:gmatch("[^&]+") do
lua/parley/oauth.lua:75:        local key = pair:match("^([^=]+)")
lua/parley/oauth.lua:208:    str = str:gsub("([^%w%-%.%_%~])", function(c)
lua/parley/oauth.lua:283:        local uri_port = explicit_uri:match("^https?://[^:/]+:(%d+)")
lua/parley/oauth.lua:586:    local value = request_data:match("[?&]" .. key .. "=([^&%s]+)")
lua/parley/oauth.lua:647:    source = tostring(source):gsub("[^%w]", "")
lua/parley/oauth.lua:1201:    local name = without_fragment:match("/([^/?]+)[^/]*$") or without_fragment
lua/parley/oauth.lua:1242:    sanitized = sanitized:gsub('("content_access_token"%s*:%s*)"[^"]+"', '%1"[REDACTED]"')
lua/parley/oauth.lua:1243:    sanitized = sanitized:gsub('("access_token"%s*:%s*)"[^"]+"', '%1"[REDACTED]"')
lua/parley/oauth.lua:1244:    sanitized = sanitized:gsub('("refresh_token"%s*:%s*)"[^"]+"', '%1"[REDACTED]"')
lua/parley/notes.lua:63:    slug = slug:gsub("[^%w%-]", "-")
lua/parley/notes.lua:136:    local folder, rest = subject:match("^%{([^{}%s/]+)%}%s+(.+)$")
lua/parley/float_picker.lua:110:        local start_idx, end_idx = text:find("[%[%{][^%]%}]*[%]%}]", wrapped_search_from)
lua/parley/vision.lua:63:    for item in inner:gmatch("[^,]+") do
lua/parley/vision.lua:615:    id = id:gsub("[^%w%s%-]", "")  -- strip non-alphanumeric (except spaces and hyphens)
lua/parley/vision.lua:708:            local ns, name_part = fid:match("^([^:]+):(.+)$")
lua/parley/vision.lua:716:                local name_part = fid:match("^[^:]+:(.+)$")
lua/parley/vision.lua:738:        local ns, name = ref:match("^([^:]+):%s*(.+)$")
lua/parley/vision.lua:765:                local name_part = fid:match("^[^:]+:(.+)$")
lua/parley/vision.lua:1045:        local name = f:match("([^/]+)$")
lua/parley/vision.lua:1052:        local name = f:match("([^/]+)$")
lua/parley/vision.lua:1074:            local name = entry:match("([^/]+)$")
lua/parley/vision.lua:1314:            local color = #segments == 1 and segments[1]:match("^([^;]+)") or scheme.base
lua/parley/vision.lua:1766:            for item in bracket_content:gmatch("[^,]+") do
lua/parley/vision.lua:1977:    local partial_ns, partial_rest = partial:match("^([^:]+):%s*(.*)$")
lua/parley/vision.lua:1979:        local word_ns = word:match("^([^:]+):")
lua/parley/vision.lua:1981:        local word_name = word:match("^[^:]+:%s*(.+)$")
lua/parley/keybinding_registry.lua:931:        for part in entry.config_key:gmatch("[^.]+") do
lua/parley/tools/builtin/write_file.lua:50:        local dir = path:match("(.+)/[^/]+$")
lua/parley/init.lua:2136:        vim.fn.matchadd("Conceal", [[^- model: .*model.:.[^"]*\zs".*\ze]], 10, -1, { conceal = "…" })
lua/parley/init.lua:2137:        vim.fn.matchadd("Conceal", [[^- model: \zs.*model.:.\ze.*]], 10, -1, { conceal = "…" })
lua/parley/init.lua:2138:        vim.fn.matchadd("Conceal", [[^- system_prompt: .\{64,64\}\zs.*\ze]], 10, -1, { conceal = "…" })
lua/parley/init.lua:2139:        vim.fn.matchadd("Conceal", [[^- system_prompt: .[^\\]*\zs\\.*\ze]], 10, -1, { conceal = "…" })
lua/parley/init.lua:2141:        vim.fn.matchadd("Conceal", [[^- role: .\{64,64\}\zs.*\ze]], 10, -1, { conceal = "…" })
lua/parley/init.lua:2142:        vim.fn.matchadd("Conceal", [[^- role: .[^\\]*\zs\\.*\ze]], 10, -1, { conceal = "…" })
lua/parley/init.lua:2708:    local path = rest:match("^([^:]+)") or rest
lua/parley/init.lua:2713:    local topic = rest:match("^[^:]+:%s*(.+)$") or ""
lua/parley/init.lua:2873:                    local ref_path, topic = rest:match("^%s*([^:]+)%s*:%s*(.-)%s*$")
lua/parley/init.lua:3001:        ["{{filename}}"] = string.match(filename, "([^/]+)$"),
lua/parley/init.lua:3762:        chat_path = current_line:match("^@@%s*([^@]+)@@")
lua/parley/init.lua:3763:            or current_line:match("^@@%s*([^:]+):")
lua/parley/init.lua:3814:            if full_line and full_line:match("@@[^:]+:%s*(.+)") then
lua/parley/init.lua:3815:                topic = full_line:match("@@[^:]+:%s*(.+)")
lua/parley/init.lua:3976:                if current_line:match("@@[^:]+:%s*(.+)") then
lua/parley/init.lua:3977:                    topic = current_line:match("@@[^:]+:%s*(.+)")
lua/parley/logger.lua:78:        raw = raw:gsub("([^\n]+)", "[SENSITIVE DATA] %1")
lua/parley/tools/serialize.lua:132:    local header = text:match("^([^\n]*)") or ""
lua/parley/tools/builtin/chat_history_search.lua:19:        local stable = version.stable_command_version(vim.fn.system("rg --version"):match("[^\n]+"), "ripgrep")
lua/parley/tools/builtin/chat_history_search.lua:22:        local stable = version.stable_command_version(vim.fn.system("grep --version 2>&1"):match("[^\n]+"), "grep")
lua/parley/tools/builtin/chat_history_search.lua:69:    for line in (output .. "\n"):gmatch("([^\n]*)\n") do
tests/integration/define_spec.lua:253:        assert.are.equal("here is ASIN[^asin] in context",
tests/integration/define_spec.lua:258:            "[^asin]: Amazon Standard Identification Number.",
tests/integration/define_spec.lua:265:        assert.are.equal(19, diags[1].end_col) -- ASIN plus [^asin]
tests/integration/define_spec.lua:267:        -- DiffChange highlight covers only ASIN[^asin], not the whole paragraph.
tests/integration/define_spec.lua:315:            return vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1] == "here is ASIN[^asin] in context"
tests/integration/define_spec.lua:333:        assert.are.equal("here is ASIN[^asin] in context",
tests/integration/define_spec.lua:338:            "[^asin]: Updated definition.",
tests/integration/define_spec.lua:349:        assert.are.equal("here is ASIN[^asin] in context",
tests/integration/define_spec.lua:369:        assert.are.equal("here is ASIN[^asin] in context",
lua/parley/tools/builtin/ls.lua:12:            local version = vim.fn.system("ls --version 2>&1"):match("[^\n]+") or "ls"
lua/parley/tools/builtin/edit_file.lua:85:            for line in (content .. "\n"):gmatch("([^\n]*)\n") do
lua/parley/tools/builtin/edit_file.lua:99:            for line in (text .. "\n"):gmatch("([^\n]*)\n") do
tests/integration/review_diag_display_spec.lua:62:            string.rep("x", 120) .. " ACOS[^acos]",
tests/integration/review_diag_display_spec.lua:111:            'before ACOS[^acos] after the anchor on the same line',
lua/parley/tools/builtin/grep.lua:12:        local stable = version.stable_command_version(vim.fn.system("rg --version"):match("[^\n]+"), "ripgrep")
lua/parley/tools/builtin/grep.lua:15:        local stable = version.stable_command_version(vim.fn.system("grep --version 2>&1"):match("[^\n]+"), "grep")
lua/parley/tools/builtin/find.lua:13:            local version = vim.fn.system("find --version 2>&1"):match("[^\n]+") or "find"
lua/parley/tools/builtin/ack.lua:21:        local version = vim.fn.system({ "ack", "--version" }):match("[^\n]+") or "ack"
lua/parley/discovery/matcher.lua:40:        local basename = path:match("([^/]+)$") or path
lua/parley/chat_parser.lua:33:    return (line or ""):match("^%[%^[^%]]+%]:") ~= nil
lua/parley/chat_parser.lua:226:                    for tag in value:gmatch("[^,%s]+") do
lua/parley/chat_parser.lua:238:                for tag in value:gmatch("[^,%s]+") do
lua/parley/chat_parser.lua:526:        for ref in text:gmatch("@@([^@]+)@@") do
lua/parley/chat_parser.lua:548:            local path, topic = rest:match("^%s*([^:]+)%s*:%s*(.-)%s*$")
lua/parley/dispatcher.lua:241:                local last_newline_pos = buffer:find("\n[^\n]*$")
lua/parley/dispatcher.lua:267:                qt.stop_reason = raw_response:match('"stop_reason"%s*:%s*"([^"]+)"')
lua/parley/dispatcher.lua:268:                    or raw_response:match('"finish_reason"%s*:%s*"([^"]+)"')
lua/parley/discovery/registry.lua:134:    local boundary = glob:sub(1, wc - 1):find("/[^/]*$")
lua/parley/discovery/local_types.lua:60:    for line in (out or ""):gmatch("[^\n]+") do
lua/parley/skills/review/mode.lua:45:    for line in fm:gmatch("[^\n]+") do
lua/parley/issues.lua:56:    slug = slug:gsub("[^%w%-]", "-")
lua/parley/issues.lua:76:    for dep in value:gmatch("[^,]+") do
lua/parley/issues.lua:255:        local s, e, text, url = line:find("%[([^%]]*)%]%(([^)]+)%)", init)
lua/parley/issues.lua:321:    return stripped:match("([^/]+)$") or stripped
lua/parley/issues.lua:340:    for line in (output or ""):gmatch("[^\r\n]+") do
tests/integration/highlighting_spec.lua:173:            "[^asin]: Amazon Standard Identification Number.",
tests/integration/highlighting_spec.lua:523:            "here is ASIN[^asin] in context",
tests/integration/highlighting_spec.lua:525:            "[^asin]: Amazon Standard Identification Number.",
tests/integration/highlighting_spec.lua:564:            "here is ASIN[^asin] in context",
tests/integration/highlighting_spec.lua:566:            "[^asin]: Amazon Standard Identification Number.",
tests/integration/highlighting_spec.lua:594:            "here is ASIN[^asin] in context",
tests/integration/highlighting_spec.lua:596:            "[^asin]: Amazon Standard Identification Number.",
lua/parley/cliproxy_config.lua:24:    local host, port = endpoint:match("^https?://([^:/]+):(%d+)")
lua/parley/cliproxy_config.lua:28:    local scheme, h = endpoint:match("^(https?)://([^:/]+)")
lua/parley/cliproxy_config.lua:232:    for line in (text or ""):gmatch("[^\n]+") do
atlas/ui/highlights.md:9:- Managed definition-footnote footers (from the first `[^id]: ...` line) use
tests/unit/highlighter_spec.lua:9:    local s, content, e = line:match("()%[([^%[%]]+)%]()")
tests/unit/highlighter_spec.lua:28:        assert.is_false(first_span_is_reference("a claim [^1] needs backing"))
tests/unit/parse_chat_spec.lua:673:            "[^acos]: ACOS (Advertising Cost of Sales).",
tests/unit/parse_chat_spec.lua:689:            "[^acos]: ACOS (Advertising Cost of Sales).",
tests/unit/skill_render_spec.lua:117:        local buf = scratch({ "here is ASIN[^asin] in context" })
tests/unit/chat_parser_tools_spec.lua:111:        for l in tool_use_block:gmatch("[^\n]+") do
tests/unit/chat_parser_tools_spec.lua:146:        for l in tool_use_block:gmatch("[^\n]+") do table.insert(lines, l) end
tests/unit/chat_parser_tools_spec.lua:147:        for l in tool_result_block:gmatch("[^\n]+") do table.insert(lines, l) end
tests/unit/chat_parser_tools_spec.lua:182:            for l in tu:gmatch("[^\n]+") do table.insert(lines, l) end
tests/unit/chat_parser_tools_spec.lua:183:            for l in tr:gmatch("[^\n]+") do table.insert(lines, l) end
tests/unit/chat_parser_tools_spec.lua:215:        for l in tool_use_block:gmatch("[^\n]+") do table.insert(lines, l) end
tests/unit/chat_parser_tools_spec.lua:216:        for l in tool_result_block:gmatch("[^\n]+") do table.insert(lines, l) end
tests/unit/chat_parser_tools_spec.lua:237:        for l in tu1:gmatch("[^\n]+") do table.insert(lines, l) end
tests/unit/chat_parser_tools_spec.lua:238:        for l in tr1:gmatch("[^\n]+") do table.insert(lines, l) end
tests/unit/define_spec.lua:161:            "here is ASIN[^asin] in context",
tests/unit/define_spec.lua:165:            "[^asin]: Amazon Standard Identification Number.",
tests/unit/define_spec.lua:179:                "[^asin]: old definition",
tests/unit/define_spec.lua:187:            "ASIN[^asin] is here",
tests/unit/define_spec.lua:191:            "[^asin]: Amazon Standard Identification Number.",
tests/unit/define_spec.lua:198:                "ASIN[^asin] is here",
tests/unit/define_spec.lua:202:                "[^asin]: old definition",
tests/unit/define_spec.lua:210:            "ASIN[^asin] is here",
tests/unit/define_spec.lua:214:            "[^asin]: Updated definition.",
tests/unit/define_spec.lua:225:            "[^asin]: Amazon Standard Identification Number.",
tests/unit/define_spec.lua:247:            "[^asin]: Amazon Standard Identification Number.",
tests/unit/define_spec.lua:259:            "[^asin]: Amazon Standard Identification Number.",
tests/unit/define_spec.lua:287:            "[^asin]: Amazon Standard Identification Number.",
tests/unit/define_spec.lua:303:            "[^asin]: Amazon Standard Identification Number.",
tests/unit/define_spec.lua:311:            "here is ASIN[^asin] in context",
tests/unit/define_spec.lua:313:            "[^asin]: Amazon Standard Identification Number.",
tests/unit/define_spec.lua:329:            "ASIN[^asin] first, then SKU[^asin] second",
tests/unit/define_spec.lua:333:            "[^asin]: Amazon Standard Identification Number.",
tests/unit/define_spec.lua:359:            "ASIN[^asin] in body",
tests/unit/define_spec.lua:361:            "[^asin]: Amazon Standard Identification Number.",
tests/unit/build_messages_spec.lua:714:            "[^asin]: Amazon Standard Identification Number.",
tests/unit/build_messages_spec.lua:721:            "[^asin]: Amazon Standard Identification Number.",
tests/unit/build_messages_spec.lua:782:            "[^asin]: Amazon Standard Identification Number.",
tests/unit/build_messages_spec.lua:1614:            "[^asin]: Amazon Standard Identification Number.",
tests/unit/build_messages_spec.lua:1621:            "[^asin]: Amazon Standard Identification Number.",
tests/unit/dispatcher_query_spec.lua:246:            for line in fixture_content:gmatch("[^\n]+") do

exec
/bin/zsh -lc "rg -n \"managed_footnote_footer_range|footnote_diagnostics|ParleyFootnote\" lua/parley tests -g '*.lua'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
lua/parley/define.lua:182:function M.managed_footnote_footer_range(lines)
lua/parley/define.lua:219:function M.footnote_diagnostics(lines)
lua/parley/highlighter.lua:270:    local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
lua/parley/highlighter.lua:303:            table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
lua/parley/highlighter.lua:471:    local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
lua/parley/highlighter.lua:478:            table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
lua/parley/highlighter.lua:750:        vim.api.nvim_set_hl(0, "ParleyFootnote", user_highlights.footnote)
lua/parley/highlighter.lua:752:        vim.api.nvim_set_hl(0, "ParleyFootnote", { link = "DiagnosticHint" })
lua/parley/highlighter.lua:1098:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1111:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1133:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1138:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1149:            skill_render.refresh_footnote_diagnostics(buf)
tests/integration/highlighting_spec.lua:176:        assert.is_true(has_highlight(buf, 3, "ParleyFootnote"),
tests/integration/highlighting_spec.lua:177:            "Expected the managed footnote definition to use ParleyFootnote")
tests/integration/highlighting_spec.lua:528:        skill_render.refresh_footnote_diagnostics(buf)
tests/integration/highlighting_spec.lua:590:    it("renders managed footnote footers with ParleyFootnote in markdown buffers", function()
tests/integration/highlighting_spec.lua:617:            if mark.hl_group == "ParleyFootnote" then
tests/integration/highlighting_spec.lua:621:        assert.is_true(highlighted[2], "Expected markdown footnote definition to use ParleyFootnote")
lua/parley/skills/review/diag_display.lua:175:    local footnote_diagnostics = {}
lua/parley/skills/review/diag_display.lua:179:                table.insert(footnote_diagnostics, diagnostic)
lua/parley/skills/review/diag_display.lua:186:    table.sort(footnote_diagnostics, function(a, b)
lua/parley/skills/review/diag_display.lua:189:    show_float(footnote_diagnostics)
lua/parley/skill_render.lua:114:function M.refresh_footnote_diagnostics(buf)
lua/parley/skill_render.lua:132:    for _, footnote in ipairs(define.footnote_diagnostics(lines)) do
tests/unit/define_spec.lua:244:        local range = define.managed_footnote_footer_range({
tests/unit/define_spec.lua:254:        local range = define.managed_footnote_footer_range({
tests/unit/define_spec.lua:266:        local range = define.managed_footnote_footer_range({
tests/unit/define_spec.lua:310:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:328:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:358:        local diagnostics = define.footnote_diagnostics({
lua/parley/init.lua:1645:    skill_render.refresh_footnote_diagnostics(buf)

codex
One additional consumer surfaced during grep: `chat_parser.lua` has its own footnote-line predicate for exchange parsing. I’m checking whether that creates a shadow implementation problem or remains outside this issue’s consumer set.
exec
/bin/zsh -lc "nl -ba lua/parley/chat_parser.lua | sed -n '1,80p;460,620p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
     1    --------------------------------------------------------------------------------
     2    -- chat_parser.lua: parses a chat file's lines into a structured representation.
     3    --
     4    -- Extracted from init.lua so it can be required and tested independently,
     5    -- without loading the full parley plugin or calling setup().
     6    --
     7    -- Public API:
     8    --   M.parse_chat(lines, header_end, config) -> parsed_chat
     9    --
    10    -- `config` must contain:
    11    --   config.chat_user_prefix        (string)
    12    --   config.chat_local_prefix       (string)
    13    --   config.chat_assistant_prefix   (string | {string, ...})
    14    --   config.chat_memory             (table | nil)
    15    --     .enable                      (boolean)
    16    --     .summary_prefix              (string)
    17    --     .reasoning_prefix            (string)
    18    --------------------------------------------------------------------------------
    19
    20    local logger = require("parley.logger")
    21
    22    local M = {}
    23
    24    local function trim(str)
    25        return (str:gsub("^%s*(.-)%s*$", "%1"))
    26    end
    27
    28    local function is_divider(line)
    29        return trim(line or "") == "---"
    30    end
    31
    32    local function is_footnote_definition(line)
    33        return (line or ""):match("^%[%^[^%]]+%]:") ~= nil
    34    end
    35
    36    ---Find the header/trancript separator index.
    37    ---Supports:
    38    ---1) Legacy format: metadata lines followed by a single `---`.
    39    ---2) Front matter format: opening `---`, metadata, closing `---`.
    40    ---@param lines table
    41    ---@return number|nil
    42    M.find_header_end = function(lines)
    43        if not lines or #lines == 0 then
    44            return nil
    45        end
    46
    47        if trim(lines[1]) == "---" then
    48            for i = 2, #lines do
    49                if trim(lines[i]) == "---" then
    50                    return i
    51                end
    52            end
    53            return nil
    54        end
    55
    56        for i, line in ipairs(lines) do
    57            if trim(line) == "---" then
    58                return i
    59            end
    60        end
    61
    62        return nil
    63    end
    64
    65    local function parse_header_key_value(line)
    66        local content = trim(line)
    67        if content == "" or content == "---" then
    68            return nil, nil
    69        end
    70
    71        local key, value = content:match("^[-#]%s*([%w_%.%+]+):%s*(.*)$")
    72        if key then
    73            return key, value
    74        end
    75
    76        return content:match("^([%w_%.%+]+):%s*(.*)$")
    77    end
    78
    79    local function parse_header_config_value(value)
    80        if tonumber(value) ~= nil then
   460            cb_state.current_line_start = nil
   461            cb_state.tool_fence_len = nil
   462            cb_state.tool_body_complete = false
   463        end
   464
   465        -- Append a line to the current content block, auto-transitioning
   466        -- out of a tool block whose fenced body has already been closed.
   467        -- Tracks fence open/close state inside tool blocks so the parser
   468        -- knows when subsequent text should start a new text block vs
   469        -- belong to the tool block's body.
   470        -- line_no is the 1-indexed buffer line being appended (#90 Task 1.1).
   471        local function cb_append_line(line, line_no)
   472            if not cb_state or not cb_state.current_kind then return end
   473
   474            -- Auto-transition: if we're in a tool block whose closing
   475            -- fence was already seen, this line belongs to a NEW text
   476            -- block, not the tool block. Finalize the tool block first.
   477            if cb_state.tool_body_complete then
   478                cb_finalize_block(line_no - 1)
   479                cb_start_block("text")
   480            end
   481
   482            -- Lazy line_start: the first line we see is where the block begins.
   483            if cb_state.current_line_start == nil then
   484                cb_state.current_line_start = line_no
   485            end
   486            table.insert(cb_state.current_lines, line)
   487
   488            -- Track fence state inside tool blocks to detect body end.
   489            -- Opening fence: any run of 3+ backticks optionally followed
   490            -- by an info string (e.g. "```json"). Closing fence: exactly
   491            -- the same number of bare backticks with no info string.
   492            if cb_state.current_kind == "tool_use" or cb_state.current_kind == "tool_result" then
   493                if not cb_state.tool_fence_len then
   494                    local fence = line:match("^(`+)[%w_%-]*%s*$")
   495                    if fence and #fence >= 3 then
   496                        cb_state.tool_fence_len = #fence
   497                    end
   498                else
   499                    local expected_close = string.rep("`", cb_state.tool_fence_len)
   500                    if line == expected_close then
   501                        cb_state.tool_body_complete = true
   502                    end
   503                end
   504            end
   505        end
   506
   507        -- Attach accumulated blocks to the current exchange's answer
   508        -- component (called on answer → next-question transition and at
   509        -- end of file). end_line_no is the last buffer line of the answer
   510        -- region (#90 Task 1.1).
   511        local function cb_attach_to_current_answer(end_line_no)
   512            if cb_state and current_exchange and current_exchange.answer then
   513                cb_finalize_block(end_line_no)
   514                current_exchange.answer.sections = cb_state.blocks
   515                -- Backward-compat alias.
   516                current_exchange.answer.content_blocks = cb_state.blocks
   517            end
   518            cb_state = nil
   519        end
   520
   521        -- Helper to extract @@ref@@ file references from a line of text.
   522        -- Canonical form: @@<ref>@@ where ref starts with https://, /, ~/, ./, or ../
   523        local function extract_file_refs(text)
   524            local refs = {}
   525            local seen = {}
   526            for ref in text:gmatch("@@([^@]+)@@") do
   527                ref = ref:gsub("^%s*(.-)%s*$", "%1")
   528                if ref:match("^https?://") or ref:match("^/") or ref:match("^~/") or ref:match("^%./") or ref:match("^%.%./") then
   529                    if not seen[ref] then
   530                        seen[ref] = true
   531                        table.insert(refs, ref)
   532                    end
   533                end
   534            end
   535            return refs
   536        end
   537
   538        -- Loop through content lines
   539        for i = header_end + 1, #lines do
   540            local line = lines[i]
   541
   542            -- Check for branch reference (🌿:) — always detected, even between consecutive links.
   543            -- Before the first question: first 🌿: is parent_link, subsequent ones are children.
   544            -- After the first question: all 🌿: are child branches.
   545            if line:sub(1, #branch_prefix) == branch_prefix then
   546                in_reasoning_block = false
   547                local rest = line:sub(#branch_prefix + 1):gsub("^%s*(.-)%s*$", "%1")
   548                local path, topic = rest:match("^%s*([^:]+)%s*:%s*(.-)%s*$")
   549                if not path then
   550                    path = rest
   551                    topic = ""
   552                end
   553                path = path:gsub("^%s*(.-)%s*$", "%1")
   554                topic = (topic or ""):gsub("^%s*(.-)%s*$", "%1")
   555                local branch_info = { path = path, topic = topic, line = i, after_exchange = #result.exchanges }
   556                if not first_question_seen and not result.parent_link then
   557                    result.parent_link = branch_info
   558                else
   559                    table.insert(result.branches, branch_info)
   560                end
   561                line_before_local = i
   562
   563            -- Check for local section (excluded from LLM context)
   564            elseif (not line_before_local) and line:sub(1, #local_prefix) == local_prefix then
   565                in_reasoning_block = false
   566                line_before_local = i
   567
   568            -- Check for user message start
   569            elseif line:sub(1, #user_prefix) == user_prefix then
   570                in_reasoning_block = false
   571                first_question_seen = true
   572                -- Content_blocks for the closing answer (if any) get attached
   573                -- before we finalize the old component and start a new exchange.
   574                local current_component_start = line_before_local or i
   575                cb_attach_to_current_answer(current_component_start - 1)
   576                -- If we were building a previous exchange, finalize it
   577                finalize_component(current_component_start - 1)
   578
   579                -- Extract question content
   580                local question_content = line:sub(#user_prefix + 1)
   581
   582                -- Detect inline branch links on the question prefix line
   583                local q_inline = M.extract_inline_branch_links(question_content, branch_prefix)
   584                if #q_inline > 0 then
   585                    question_content = M.unpack_inline_branch_links(question_content, branch_prefix)
   586                end
   587
   588                -- Start a new exchange
   589                current_exchange = {
   590                    question = {
   591                        line_start = i,
   592                        line_end = nil,
   593                        content = "",
   594                        file_references = {} -- Will store file references we find (length > 0 means has references)
   595                    },
   596                    answer = nil
   597                }
   598                content_parts = { question_content }
   599                table.insert(result.exchanges, current_exchange)
   600                current_component = "question"
   601                line_before_local = nil
   602
   603                -- Add inline branch links from the question prefix line
   604                for _, ib in ipairs(q_inline) do
   605                    table.insert(result.branches, {
   606                        path = ib.path,
   607                        topic = ib.topic,
   608                        line = i,
   609                        after_exchange = #result.exchanges,
   610                        inline = true,
   611                    })
   612                end
   613
   614                -- Check for inline @@ file references on the user prefix line itself
   615                local inline_refs = extract_file_refs(question_content)
   616                for _, ref_path in ipairs(inline_refs) do
   617                    table.insert(current_exchange.question.file_references, {
   618                        line = line,
   619                        path = ref_path,
   620                        original_line_index = i,

exec
/bin/zsh -lc "nl -ba tests/unit/parse_chat_spec.lua | sed -n '640,705p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   640            local result = parse_chat(lines, header_end)
   641            local refs = result.exchanges[1].question.file_references
   642            assert.equals(1, #refs)
   643            assert.equals("~/config.lua", refs[1].path)
   644        end)
   645
   646        it("does not collect unclosed @@ reference (no closing @@)", function()
   647            local lines, header_end = make_chat(std_header, {
   648                "💬: Review @@/path/to/file.lua please",
   649            })
   650            local result = parse_chat(lines, header_end)
   651            local refs = result.exchanges[1].question.file_references
   652            assert.equals(0, #refs)
   653        end)
   654
   655        it("collects two inline @@ref@@ on same line", function()
   656            local lines, header_end = make_chat(std_header, {
   657                "💬: Compare @@/file/a.lua@@ and @@/file/b.lua@@",
   658            })
   659            local result = parse_chat(lines, header_end)
   660            local refs = result.exchanges[1].question.file_references
   661            assert.equals(2, #refs)
   662        end)
   663    end)
   664
   665
   666    describe("parse_chat: edge cases", function()
   667        it("stops a final open question before a managed footnote footer", function()
   668            local lines, header_end = make_chat(std_header, {
   669                "💬: tell me about the EVAL framework",
   670                "",
   671                "---",
   672                "",
   673                "[^acos]: ACOS (Advertising Cost of Sales).",
   674            })
   675            local result = parse_chat(lines, header_end)
   676
   677            assert.equals("tell me about the EVAL framework", result.exchanges[1].question.content)
   678            assert.equals(7, result.exchanges[1].question.line_start)
   679            assert.equals(7, result.exchanges[1].question.line_end)
   680        end)
   681
   682        it("positions a final open-question answer above managed footnotes", function()
   683            local exchange_model = require("parley.exchange_model")
   684            local lines, header_end = make_chat(std_header, {
   685                "💬: tell me about the EVAL framework",
   686                "",
   687                "---",
   688                "",
   689                "[^acos]: ACOS (Advertising Cost of Sales).",
   690            })
   691            local parsed = parse_chat(lines, header_end)
   692            local model = exchange_model.from_parsed_chat(parsed)
   693
   694            model:add_block(1, "agent_header", 1)
   695            local agent_header_start = model:block_start(1, 2)
   696
   697            assert.equals(8, agent_header_start)
   698            assert.equals("---", lines[agent_header_start + 1])
   699        end)
   700
   701        it("handles assistant message with no preceding user message", function()
   702            local lines, header_end = make_chat(std_header, {
   703                "🤖:[Claude] Unprompted response",
   704            })
   705            -- Should not crash; an exchange is created with empty question

exec
/bin/zsh -lc "nl -ba lua/parley/highlighter.lua | sed -n '245,315p;450,485p;738,755p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   245                if ok and bounds then
   246                    local start_line = math.max(1, (bounds.top or 1) - margin)
   247                    local end_line = math.min(line_count, (bounds.bottom or line_count) + margin)
   248                    if start_line <= end_line then
   249                        table.insert(ranges, { start_line = start_line, end_line = end_line })
   250                    end
   251                end
   252            end
   253        end
   254
   255        if #ranges == 0 and line_count > 0 then
   256            table.insert(ranges, { start_line = 1, end_line = line_count })
   257        end
   258
   259        return merge_line_ranges(ranges)
   260    end
   261
   262    -- Compute desired chat highlights for a 1-indexed line range.
   263    -- Returns a table keyed by 0-indexed row: { [row] = { {hl_group, col_start, col_end}, ... } }
   264    -- Scans HIGHLIGHT_CONTEXT_LINES above start_line for block state context.
   265    local function compute_chat_highlights(buf, start_line, end_line)
   266        local result = {}
   267        local patterns = get_chat_highlight_prefix_patterns()
   268        local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)
   269        local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
   270        local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
   271        -- While a stream is in flight for this buffer, the model has not
   272        -- yet emitted 🧠:[END]. Assume explicit-end mode so blank-line
   273        -- paragraph breaks inside the in-progress thinking region keep
   274        -- their dim highlight instead of prematurely terminating the
   275        -- block. After the stream completes (is_busy → false), the
   276        -- lookahead-decided mode takes over and a real [END] / structural
   277        -- marker controls termination.
   278        local streaming = require("parley.tasker").is_busy(buf, true)
   279        local in_block, in_code_block, in_reasoning_block, in_reasoning_explicit_end =
   280            bootstrap_chat_highlight_state(buf, start_line, patterns, streaming)
   281
   282        local in_tool_block = false  -- inside 🔧:/📎: fenced content
   283
   284        for offset, line in ipairs(lines) do
   285            local line_nr = start_line + offset - 1
   286            if line:match("^%s*```") then
   287                in_code_block = not in_code_block
   288                -- Exiting a code block while in a tool region ends the tool region
   289                if not in_code_block and in_tool_block then
   290                    in_tool_block = false
   291                end
   292            end
   293
   294            local highlighted_regions = {}
   295            local row = line_nr - 1
   296
   297            result[row] = result[row] or {}
   298
   299            push_artifact_refs(result, row, line) -- #160: navigable artifact refs
   300
   301            local is_footer = footer_range and line_nr >= footer_range.start_line and line_nr <= footer_range.end_line
   302            if is_footer then
   303                table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
   304                in_block = false
   305            else
   306                local pos = 1
   307                while true do
   308                    local tag_start, content_start = line:find("@@", pos)
   309                    if not tag_start then break end
   310                    local content_end, tag_end = line:find("@@", content_start + 1)
   311                    if not content_end then break end
   312                    table.insert(highlighted_regions, { start = tag_start, finish = tag_end })
   313                    table.insert(result[row], { hl_group = "ParleyTag", col_start = tag_start - 1, col_end = tag_end })
   314                    pos = tag_end + 1
   315                end
   450    --   * a *live* 🤖 marker's section   — `[U]` chained after 🤖 / `>` / `~` / a
   451    --                                     prior `]`/`}` close (already highlighted
   452    --                                     ParleyReviewUser; don't double-mark it).
   453    -- A flattened reference span's `[` follows ordinary prose, so it passes.
   454    function M.is_reference_span(line, s, content, e)
   455        if line:sub(e, e) == "(" then return false end
   456        if content:sub(1, 1) == "^" then return false end
   457        if #content < 2 then return false end
   458        local prev = line:sub(s - 1, s - 1)
   459        if prev == "]" or prev == "}" or prev == ">" or prev == "~" then return false end
   460        if s > 4 and line:sub(s - 4, s - 1) == "🤖" then return false end
   461        return true
   462    end
   463
   464    -- Compute desired markdown highlights for a 1-indexed line range.
   465    -- Returns a table keyed by 0-indexed row: { [row] = { {hl_group, col_start, col_end}, ... } }
   466    local function compute_markdown_highlights(buf, start_line, end_line)
   467        local result = {}
   468        local branch_prefix = _parley.config.chat_branch_prefix or "🌿:"
   469        local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)
   470        local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
   471        local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
   472        for offset, line in ipairs(lines) do
   473            local row = start_line + offset - 2
   474            local line_nr = row + 1
   475            push_artifact_refs(result, row, line) -- #160: navigable artifact refs
   476            if footer_range and line_nr >= footer_range.start_line and line_nr <= footer_range.end_line then
   477                result[row] = result[row] or {}
   478                table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
   479            end
   480            if line:sub(1, #branch_prefix) == branch_prefix then
   481                result[row] = result[row] or {}
   482                table.insert(result[row], { hl_group = "ParleyChatReference", col_start = 0, col_end = -1 })
   483            end
   484            -- Highlight 🤖<...>[...]{...} review markers
   485            local review = require("parley.review")
   738        -- text a gathered comment points at. Underline reads as "this span is
   739        -- marked" without the weight of a full background. Override via
   740        -- config.highlight.reference.
   741        if user_highlights.reference then
   742            vim.api.nvim_set_hl(0, "ParleyReference", user_highlights.reference)
   743        else
   744            vim.api.nvim_set_hl(0, "ParleyReference", { underline = true })
   745        end
   746
   747        -- Managed definition-footnote footer (`---` + `[^id]: ...`). It must be
   748        -- independent of the surrounding chat exchange color.
   749        if user_highlights.footnote then
   750            vim.api.nvim_set_hl(0, "ParleyFootnote", user_highlights.footnote)
   751        else
   752            vim.api.nvim_set_hl(0, "ParleyFootnote", { link = "DiagnosticHint" })
   753        end
   754
   755        -- Artifact refs (ariadne#11, #15 M4, pair#84) left navigable by #160.

exec
/bin/zsh -lc "nl -ba tests/unit/build_messages_spec.lua | sed -n '700,790p;1595,1630p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   700            assert.equals(5, #messages)
   701            assert.equals("Answer 1", messages[3].content)
   702            assert.equals("Question 2", messages[4].content)
   703            assert.equals("Question 3", messages[5].content)
   704        end)
   705    end)
   706
   707    describe("_build_messages: durable definition footnotes", function()
   708        it("strips managed definition footnote footers from user and assistant content", function()
   709            local question = table.concat({
   710                "What is ASIN?",
   711                "",
   712                "---",
   713                "",
   714                "[^asin]: Amazon Standard Identification Number.",
   715            }, "\n")
   716            local answer = table.concat({
   717                "ASIN is an identifier.",
   718                "",
   719                "---",
   720                "",
   721                "[^asin]: Amazon Standard Identification Number.",
   722            }, "\n")
   723            local pc = parsed_chat({ exchange(question, answer), exchange("Next") })
   724            pc.exchanges[1].question.line_start = 10
   725            pc.exchanges[1].answer.line_start = 12
   726            pc.exchanges[2].question.line_start = 20
   727
   728            local messages = parley._build_messages({
   729                parsed_chat = pc,
   730                start_index = 1,
   731                end_index = 100,
   732                exchange_idx = 2,
   733                agent = agent(),
   734                config = parley.config,
   735                helpers = stub_helpers,
   736                logger = stub_logger
   737            })
   738
   739            assert.equals("What is ASIN?", messages[2].content)
   740            assert.equals("ASIN is an identifier.", messages[3].content)
   741            assert.is_nil(messages[2].content:find("%[%^asin%]:"))
   742            assert.is_nil(messages[3].content:find("%[%^asin%]:"))
   743        end)
   744
   745        it("preserves ordinary horizontal-rule content that is not a managed footer", function()
   746            local answer = table.concat({
   747                "first half",
   748                "",
   749                "---",
   750                "",
   751                "second half, not a footnote",
   752            }, "\n")
   753            local pc = parsed_chat({ exchange("Q", answer), exchange("Next") })
   754            pc.exchanges[1].question.line_start = 10
   755            pc.exchanges[1].answer.line_start = 12
   756            pc.exchanges[2].question.line_start = 20
   757
   758            local messages = parley._build_messages({
   759                parsed_chat = pc,
   760                start_index = 1,
   761                end_index = 100,
   762                exchange_idx = 2,
   763                agent = agent(),
   764                config = parley.config,
   765                helpers = stub_helpers,
   766                logger = stub_logger
   767            })
   768
   769            assert.equals(answer, messages[3].content)
   770        end)
   771
   772        it("keeps earlier horizontal-rule content and strips only the final managed footer", function()
   773            local answer = table.concat({
   774                "first half",
   775                "",
   776                "---",
   777                "",
   778                "second half",
   779                "",
   780                "---",
   781                "",
   782                "[^asin]: Amazon Standard Identification Number.",
   783            }, "\n")
   784            local pc = parsed_chat({ exchange("Q", answer), exchange("Next") })
   785            pc.exchanges[1].question.line_start = 10
   786            pc.exchanges[1].answer.line_start = 12
   787            pc.exchanges[2].question.line_start = 20
   788
   789            local messages = parley._build_messages({
   790                parsed_chat = pc,
  1595            assert.is_true(found_tu, "assistant message must carry the tool_use")
  1596            assert.equals("user", last.role)
  1597            assert.equals("tool_result", last.content[1].type)
  1598            assert.equals("toolu_z", last.content[1].tool_use_id)
  1599            assert.is_true(last.content[1].is_error)
  1600
  1601            vim.api.nvim_buf_delete(buf, { force = true })
  1602        end)
  1603    end)
  1604
  1605    describe("build_messages_from_model: durable definition footnotes", function()
  1606        local exchange_model = require("parley.exchange_model")
  1607
  1608        it("strips managed footnote footers from live question and answer blocks", function()
  1609            local question_lines = {
  1610                "💬: What is ASIN?",
  1611                "",
  1612                "---",
  1613                "",
  1614                "[^asin]: Amazon Standard Identification Number.",
  1615            }
  1616            local answer_lines = {
  1617                "ASIN is an identifier.",
  1618                "",
  1619                "---",
  1620                "",
  1621                "[^asin]: Amazon Standard Identification Number.",
  1622            }
  1623            local header = { "topic: t", "---" }
  1624            local header_lines = #header
  1625            local model = exchange_model.new(header_lines)
  1626            model:add_exchange(#question_lines)
  1627            model:add_block(1, "agent_header", 1)
  1628            model:add_block(1, "text", #answer_lines)
  1629
  1630            local q0 = model:block_start(1, 1)

exec
/bin/zsh -lc 'rg -n "is_footnote_definition|footnote" lua/parley/chat_parser.lua tests/unit/parse_chat_spec.lua' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
tests/unit/parse_chat_spec.lua:667:    it("stops a final open question before a managed footnote footer", function()
tests/unit/parse_chat_spec.lua:682:    it("positions a final open-question answer above managed footnotes", function()
lua/parley/chat_parser.lua:32:local function is_footnote_definition(line)
lua/parley/chat_parser.lua:310:    local function final_footnote_boundary(end_line)
lua/parley/chat_parser.lua:315:        if i <= 0 or not is_footnote_definition(lines[i]) then
lua/parley/chat_parser.lua:319:        local footnote_start = i
lua/parley/chat_parser.lua:323:            if is_footnote_definition(line) then
lua/parley/chat_parser.lua:324:                footnote_start = i
lua/parley/chat_parser.lua:331:        local boundary = footnote_start
lua/parley/chat_parser.lua:346:                local boundary = final_footnote_boundary(end_line)

codex
This uncovered a real stale duplicate: `chat_parser.lua` still has its own final-footer scanner. I’m reading that block closely because it affects whether the new “first footnote line” rule is truly single-sourced across parser/model behavior.
exec
/bin/zsh -lc "nl -ba lua/parley/chat_parser.lua | sed -n '285,360p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   285
   286        -- Track the current exchange and component being built
   287        local current_exchange = nil
   288        local current_component = nil
   289        local line_before_local = nil
   290        local first_question_seen = false
   291        -- Multi-line reasoning state: opened by a 🧠: line inside an answer.
   292        -- Two termination modes, decided per-block at open time:
   293        --   - explicit-end mode (in_reasoning_explicit_end = true): a
   294        --     🧠:[END] line was found before the next structural marker.
   295        --     Blank lines inside the block are content; only 🧠:[END] or a
   296        --     structural marker (📝/🔧/📎/💬/🤖/🌿/🔒) terminates. This
   297        --     lets the model emit blank-line paragraphs inside reasoning.
   298        --   - legacy mode (in_reasoning_explicit_end = false): no 🧠:[END]
   299        --     follows. The first blank line terminates. Preserves backward
   300        --     compat with chats authored under the previous convention.
   301        -- Continuation lines are appended to current_exchange.reasoning.content
   302        -- (joined by \n) and also fed into the answer's content_parts /
   303        -- content_blocks like normal answer text, so subsequent turns replay
   304        -- the model's prior reasoning verbatim.
   305        local in_reasoning_block = false
   306        local in_reasoning_explicit_end = false
   307        -- Use table accumulation instead of string concat for content (avoids O(n²))
   308        local content_parts = {}
   309
   310        local function final_footnote_boundary(end_line)
   311            local i = end_line
   312            while i > 0 and trim(lines[i] or "") == "" do
   313                i = i - 1
   314            end
   315            if i <= 0 or not is_footnote_definition(lines[i]) then
   316                return nil
   317            end
   318
   319            local footnote_start = i
   320            i = i - 1
   321            while i > 0 do
   322                local line = lines[i] or ""
   323                if is_footnote_definition(line) then
   324                    footnote_start = i
   325                elseif trim(line) ~= "" then
   326                    break
   327                end
   328                i = i - 1
   329            end
   330
   331            local boundary = footnote_start
   332            local before = boundary - 1
   333            while before > 0 and trim(lines[before] or "") == "" do
   334                before = before - 1
   335            end
   336            if before > 0 and is_divider(lines[before]) then
   337                boundary = before
   338            end
   339            return boundary
   340        end
   341
   342        -- Helper to finalize the current component's content from accumulated parts
   343        local function finalize_component(end_line)
   344            if current_exchange and current_component then
   345                if current_component == "question" then
   346                    local boundary = final_footnote_boundary(end_line)
   347                    if boundary and boundary > current_exchange[current_component].line_start then
   348                        local keep_count = boundary - current_exchange[current_component].line_start
   349                        while #content_parts > keep_count do
   350                            table.remove(content_parts)
   351                        end
   352                        end_line = boundary - 1
   353                    end
   354                end
   355                -- Trim trailing blank lines from all components so the
   356                -- model's margins are the single source of truth for gaps
   357                -- between blocks/exchanges. Without this, trailing blanks
   358                -- in the parser's line_end would double-count with the
   359                -- model's MARGIN constant.
   360                local trimmed_end = end_line

codex
```verdict
verdict: REWORK
confidence: high
```

The core `define.lua` change implements the requested dividerless boundary and the main diagnostics/highlighting paths follow it, but the repo still has a separate managed-footer parser in `chat_parser.lua`. That shadow implementation still applies different boundary rules, so the single-source footer contract is not actually fulfilled.

1. Strengths:
- [lua/parley/define.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/define.lua:170) keeps the new core detector pure and small.
- [tests/unit/define_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/unit/define_spec.lua:243) pins dividerless and legacy divider-based footer ranges.
- [tests/integration/highlighting_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/integration/highlighting_spec.lua:519) covers dividerless diagnostics and footer highlighting.
- Atlas updates correctly describe the new boundary in `atlas/chat/inline_define.md` and `atlas/ui/highlights.md`.

2. Critical findings:
- [lua/parley/chat_parser.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/chat_parser.lua:310) still contains a hand-maintained `final_footnote_boundary` scanner plus its own footnote predicate at line 32. This violates the issue’s “all current consumers keep deriving from that helper” contract and fails ARCH-DRY / ARCH-PURPOSE. It also keeps older semantics: it only recognizes a footer when the last nonblank line is a footnote and treats a preceding `---` as the boundary, while `define.managed_footnote_footer_range` now defines the first `[^id]:` line to EOF as the boundary. Fix sketch: make chat parsing derive from `parley.define.managed_footnote_footer_range` or extract one shared pure helper for “content trim start including optional legacy divider”, then add parse-chat tests for dividerless footers and footnote-plus-trailing-text.

3. Important findings:
- None beyond the blocking shadow-consumer issue.

4. Minor findings:
- [lua/parley/highlighter.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/highlighter.lua:747) has a stale comment saying the managed footer is ``---` + `[^id]: ...``; update it to match the new boundary.

5. Test coverage notes:
- I ran `git diff --check c481296d..HEAD`, `PlenaryBustedFile tests/unit/define_spec.lua`, and `PlenaryBustedFile tests/integration/highlighting_spec.lua`; all passed, with existing local Neovim startup warnings.
- Missing coverage: `parse_chat` should have dividerless managed-footer tests, including the trailing-text-to-EOF case.

6. Architectural notes for upcoming work:
- ARCH-DRY: flagged. Footer boundary logic must have one source.
- ARCH-PURE: pass for the new `define.lua` core; keep the parser fix pure as well.
- ARCH-PURPOSE: flagged. The purpose is not only recognizing dividerless footers in the obvious consumers, but eliminating stale restatements of the managed-footer model.

7. Plan revision recommendations:
- Add a `## Revisions` entry noting that review found `chat_parser.lua` as an additional managed-footer consumer and that the plan now includes deriving it from the shared footer boundary helper plus parse-chat regression coverage.
tokens used
56,296
```verdict
verdict: REWORK
confidence: high
```

The core `define.lua` change implements the requested dividerless boundary and the main diagnostics/highlighting paths follow it, but the repo still has a separate managed-footer parser in `chat_parser.lua`. That shadow implementation still applies different boundary rules, so the single-source footer contract is not actually fulfilled.

1. Strengths:
- [lua/parley/define.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/define.lua:170) keeps the new core detector pure and small.
- [tests/unit/define_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/unit/define_spec.lua:243) pins dividerless and legacy divider-based footer ranges.
- [tests/integration/highlighting_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/integration/highlighting_spec.lua:519) covers dividerless diagnostics and footer highlighting.
- Atlas updates correctly describe the new boundary in `atlas/chat/inline_define.md` and `atlas/ui/highlights.md`.

2. Critical findings:
- [lua/parley/chat_parser.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/chat_parser.lua:310) still contains a hand-maintained `final_footnote_boundary` scanner plus its own footnote predicate at line 32. This violates the issue’s “all current consumers keep deriving from that helper” contract and fails ARCH-DRY / ARCH-PURPOSE. It also keeps older semantics: it only recognizes a footer when the last nonblank line is a footnote and treats a preceding `---` as the boundary, while `define.managed_footnote_footer_range` now defines the first `[^id]:` line to EOF as the boundary. Fix sketch: make chat parsing derive from `parley.define.managed_footnote_footer_range` or extract one shared pure helper for “content trim start including optional legacy divider”, then add parse-chat tests for dividerless footers and footnote-plus-trailing-text.

3. Important findings:
- None beyond the blocking shadow-consumer issue.

4. Minor findings:
- [lua/parley/highlighter.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/highlighter.lua:747) has a stale comment saying the managed footer is ``---` + `[^id]: ...``; update it to match the new boundary.

5. Test coverage notes:
- I ran `git diff --check c481296d..HEAD`, `PlenaryBustedFile tests/unit/define_spec.lua`, and `PlenaryBustedFile tests/integration/highlighting_spec.lua`; all passed, with existing local Neovim startup warnings.
- Missing coverage: `parse_chat` should have dividerless managed-footer tests, including the trailing-text-to-EOF case.

6. Architectural notes for upcoming work:
- ARCH-DRY: flagged. Footer boundary logic must have one source.
- ARCH-PURE: pass for the new `define.lua` core; keep the parser fix pure as well.
- ARCH-PURPOSE: flagged. The purpose is not only recognizing dividerless footers in the obvious consumers, but eliminating stale restatements of the managed-footer model.

7. Plan revision recommendations:
- Add a `## Revisions` entry noting that review found `chat_parser.lua` as an additional managed-footer consumer and that the plan now includes deriving it from the shared footer boundary helper plus parse-chat regression coverage.

---

## Re-review — 2026-07-08T23:51:56-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 178 — recognize footnote footer without divider |
| repo | parley.nvim |
| issue file | workshop/issues/000178-recognize-footnote-footer-without-divider.md |
| boundary | whole-issue close |
| milestone | — |
| window | c481296d642c30cfbddbe1b5fd62c6265b397fe3..HEAD |
| command | sdlc close --issue 178 |
| reviewer | codex |
| timestamp | 2026-07-08T23:51:56-07:00 |
| verdict | SHIP |

## Review

Reading additional input from stdin...
OpenAI Codex v0.143.0
--------
workdir: /Users/xianxu/workspace/parley.nvim
model: gpt-5.5
provider: openai
approval: never
sandbox: workspace-write [workdir, /tmp, $TMPDIR, /tmp] (network access enabled)
reasoning effort: none
reasoning summaries: none
session id: 019f45a4-22f5-7bb1-b788-f614e2380c20
--------
user
# Code review — the one SDLC boundary review

You are conducting a fresh-context code review at a development boundary —
whole-issue close — in the **parley.nvim** repository.

- repository: parley.nvim   (root: /Users/xianxu/workspace/parley.nvim)
- issue:      parley.nvim#178   (file: workshop/issues/000178-recognize-footnote-footer-without-divider.md)
- window:     Base: c481296d642c30cfbddbe1b5fd62c6265b397fe3   Head: HEAD

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
index d40dec6..1a14c80 100644
--- a/atlas/chat/inline_define.md
+++ b/atlas/chat/inline_define.md
@@ -65,8 +65,8 @@ watcher doesn't mistake it for a user edit.
   `context_for_selection`, `format_definition`, `bracket_edit` (plans the `[term]`
   wrap as a legacy set_lines edit), `diagnostic_span_after_bracket` (legacy range
   mapping), `apply_definition_footnote` (durable footer transform), and
-  `strip_definition_footnote_footer` / `footnote_diagnostics` (read only a final
-  `---` block followed solely by footnotes).
+  `strip_definition_footnote_footer` / `footnote_diagnostics` (treat the first
+  markdown footnote definition line as the managed footer boundary).
 - **IO shell** (`lua/parley/init.lua`): `define_visual`, `render_definition`;
   `lua/parley/buffer_edit.lua` owns the full-buffer footnote rewrite;
   `lua/parley/skill_render.lua` publishes footnote diagnostics; and
@@ -77,22 +77,19 @@ watcher doesn't mistake it for a user edit.

 ## Managed Footnote Footer

-The footer is a final markdown block:
+The footer begins at the first markdown footnote definition line:

 ```markdown
----
-
 [^asin]: Amazon Standard Identification Number.
 ```

-The footer detector is deliberately conservative: only the last standalone
-`---` line followed by blank lines and footnote definitions counts as the
-managed footer. Ordinary horizontal rules and mixed prose after `---` remain
-chat content. `chat_respond.build_messages` strips this managed footer from
-message strings before LLM submission, so durable definitions do not become
-prompt context. `define.footnote_diagnostics` uses the same footer detector to
-scan inline references before the footer and produce diagnostics for each
-matching `[^id]`.
+Older define edits may include a standalone `---` separator immediately before
+that first footnote definition; the stripper removes that optional separator
+along with the footer, but the canonical boundary is the `[^id]: ...` line.
+`chat_respond.build_messages` strips this managed footer from message strings
+before LLM submission, so durable definitions do not become prompt context.
+`define.footnote_diagnostics` uses the same footer detector to scan inline
+references before the footer and produce diagnostics for each matching `[^id]`.

 ## Keybinding

diff --git a/atlas/ui/highlights.md b/atlas/ui/highlights.md
index 27290df..e50fa51 100644
--- a/atlas/ui/highlights.md
+++ b/atlas/ui/highlights.md
@@ -6,7 +6,7 @@ Custom groups (`ParleyQuestion`, `ParleyFileReference`, `ParleyChatReference`, `
 ## Key Behaviors
 - Applied via decoration providers with ephemeral extmarks per window viewport
 - Multi-window safe: independent redraw cache per window
-- Managed definition-footnote footers (`---` + `[^id]: ...`) use
+- Managed definition-footnote footers (from the first `[^id]: ...` line) use
   `ParleyFootnote` in chat and markdown buffers instead of inheriting the active
   chat exchange color.
 - `🌿:` lines auto-rendered with debounced topic lookup from referenced files
diff --git a/lua/parley/chat_parser.lua b/lua/parley/chat_parser.lua
index 6e6845a..6b7b388 100644
--- a/lua/parley/chat_parser.lua
+++ b/lua/parley/chat_parser.lua
@@ -25,14 +25,6 @@ local function trim(str)
     return (str:gsub("^%s*(.-)%s*$", "%1"))
 end

-local function is_divider(line)
-    return trim(line or "") == "---"
-end
-
-local function is_footnote_definition(line)
-    return (line or ""):match("^%[%^[^%]]+%]:") ~= nil
-end
-
 ---Find the header/trancript separator index.
 ---Supports:
 ---1) Legacy format: metadata lines followed by a single `---`.
@@ -306,37 +298,13 @@ M.parse_chat = function(lines, header_end, config)
     local in_reasoning_explicit_end = false
     -- Use table accumulation instead of string concat for content (avoids O(n²))
     local content_parts = {}
+    local footnote_content_start = require("parley.define").managed_footnote_content_start(lines)

     local function final_footnote_boundary(end_line)
-        local i = end_line
-        while i > 0 and trim(lines[i] or "") == "" do
-            i = i - 1
-        end
-        if i <= 0 or not is_footnote_definition(lines[i]) then
+        if not footnote_content_start or footnote_content_start > end_line then
             return nil
         end
-
-        local footnote_start = i
-        i = i - 1
-        while i > 0 do
-            local line = lines[i] or ""
-            if is_footnote_definition(line) then
-                footnote_start = i
-            elseif trim(line) ~= "" then
-                break
-            end
-            i = i - 1
-        end
-
-        local boundary = footnote_start
-        local before = boundary - 1
-        while before > 0 and trim(lines[before] or "") == "" do
-            before = before - 1
-        end
-        if before > 0 and is_divider(lines[before]) then
-            boundary = before
-        end
-        return boundary
+        return footnote_content_start
     end

     -- Helper to finalize the current component's content from accumulated parts
diff --git a/lua/parley/define.lua b/lua/parley/define.lua
index 44817c1..733cbd0 100644
--- a/lua/parley/define.lua
+++ b/lua/parley/define.lua
@@ -168,22 +168,9 @@ local function is_footnote_line(line)
 end

 local function managed_footer_start(lines)
-    for i = #lines, 1, -1 do
-        if is_divider(lines[i]) then
-            local has_footnote = false
-            for j = i + 1, #lines do
-                local line = lines[j] or ""
-                if trim(line) ~= "" then
-                    if not is_footnote_line(line) then
-                        return nil
-                    end
-                    has_footnote = true
-                end
-            end
-            if has_footnote then
-                return i
-            end
-            return nil
+    for i, line in ipairs(lines or {}) do
+        if is_footnote_line(line) then
+            return i
         end
     end
     return nil
@@ -201,6 +188,29 @@ function M.managed_footnote_footer_range(lines)
     return { start_line = start, end_line = #lines }
 end

+--- Locate the line where user-authored content should stop before a managed
+--- definition-footnote footer. The public footer range starts at the first
+--- `[^id]:` line, but old buffers may still have a preceding `---` separator
+--- that should be stripped from prompts/messages too.
+--- @param lines string[]|nil
+--- @return integer|nil 1-based inclusive start line to trim from content
+function M.managed_footnote_content_start(lines)
+    lines = lines or {}
+    local range = M.managed_footnote_footer_range(lines)
+    if not range then
+        return nil
+    end
+    local start = range.start_line
+    local before = start - 1
+    while before > 0 and trim(lines[before]) == "" do
+        before = before - 1
+    end
+    if before > 0 and is_divider(lines[before]) then
+        start = before
+    end
+    return start
+end
+
 local function parse_footnote_line(line)
     local id, definition = trim(line):match("^%[%^([^%]]+)%]:%s*(.-)%s*$")
     if not id then
@@ -237,7 +247,7 @@ function M.footnote_diagnostics(lines)
     end

     local definitions = {}
-    for i = footer + 1, #lines do
+    for i = footer, #lines do
         local id, definition = parse_footnote_line(lines[i] or "")
         if id then
             definitions[id] = definition
@@ -305,13 +315,10 @@ end
 --- @return string
 function M.strip_definition_footnote_footer(text)
     local lines = split_text_lines(text or "")
-    local start = managed_footer_start(lines)
+    local start = M.managed_footnote_content_start(lines)
     if not start then
         return text or ""
     end
-    while start > 1 and trim(lines[start - 1]) == "" do
-        start = start - 1
-    end
     local kept = {}
     for i = 1, start - 1 do
         kept[#kept + 1] = lines[i]
@@ -327,7 +334,7 @@ local function replace_or_append_footnote(lines, id, definition)
     local footer = managed_footer_start(out)
     local footnote_line = M.format_footnote_line(id, definition)
     if footer then
-        for i = footer + 1, #out do
+        for i = footer, #out do
             local escaped_id = id:gsub("([^%w])", "%%%1")
             if trim(out[i]):match("^%[%^" .. escaped_id .. "%]:") then
                 out[i] = footnote_line
diff --git a/lua/parley/highlighter.lua b/lua/parley/highlighter.lua
index bb29507..4b1ef33 100644
--- a/lua/parley/highlighter.lua
+++ b/lua/parley/highlighter.lua
@@ -744,7 +744,7 @@ M.setup_highlights = function()
         vim.api.nvim_set_hl(0, "ParleyReference", { underline = true })
     end

-    -- Managed definition-footnote footer (`---` + `[^id]: ...`). It must be
+    -- Managed definition-footnote footer (from the first `[^id]: ...`). It must be
     -- independent of the surrounding chat exchange color.
     if user_highlights.footnote then
         vim.api.nvim_set_hl(0, "ParleyFootnote", user_highlights.footnote)
diff --git a/tests/integration/highlighting_spec.lua b/tests/integration/highlighting_spec.lua
index 43bf5f8..ee6748b 100644
--- a/tests/integration/highlighting_spec.lua
+++ b/tests/integration/highlighting_spec.lua
@@ -170,18 +170,12 @@ describe("highlight_question_block: managed footnote footer", function()
             "💬: Define ASIN",
             "This question is still open.",
             "",
-            "---",
-            "",
             "[^asin]: Amazon Standard Identification Number.",
         })

         assert.is_true(has_highlight(buf, 3, "ParleyFootnote"),
-            "Expected the managed footer divider to use ParleyFootnote")
-        assert.is_true(has_highlight(buf, 5, "ParleyFootnote"),
             "Expected the managed footnote definition to use ParleyFootnote")
         assert.is_false(has_highlight(buf, 3, "ParleyQuestion"),
-            "Managed footer divider should not inherit open-question color")
-        assert.is_false(has_highlight(buf, 5, "ParleyQuestion"),
             "Managed footnote definition should not inherit open-question color")
     end)
 end)
@@ -528,8 +522,6 @@ describe("markdown footnote diagnostics", function()
         vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
             "here is ASIN[^asin] in context",
             "",
-            "---",
-            "",
             "[^asin]: Amazon Standard Identification Number.",
         })

@@ -571,8 +563,6 @@ describe("markdown footnote diagnostics", function()
         vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
             "here is ASIN[^asin] in context",
             "",
-            "---",
-            "",
             "[^asin]: Amazon Standard Identification Number.",
         })
         vim.cmd("doautocmd TextChanged")
@@ -603,15 +593,13 @@ describe("markdown footnote diagnostics", function()
         vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
             "here is ASIN[^asin] in context",
             "",
-            "---",
-            "",
             "[^asin]: Amazon Standard Identification Number.",
         })
         parley._parley_bufs[buf] = "markdown"

         local win = vim.api.nvim_get_current_win()
         vim.api.nvim_win_set_buf(win, buf)
-        provider.on_win(nil, win, buf, 0, 4)
+        provider.on_win(nil, win, buf, 0, 2)

         local original_set_extmark = vim.api.nvim_buf_set_extmark
         local extmarks = {}
@@ -621,7 +609,6 @@ describe("markdown footnote diagnostics", function()
         end

         provider.on_line(nil, win, buf, 2)
-        provider.on_line(nil, win, buf, 4)

         vim.api.nvim_buf_set_extmark = original_set_extmark

@@ -631,8 +618,7 @@ describe("markdown footnote diagnostics", function()
                 highlighted[mark.row] = true
             end
         end
-        assert.is_true(highlighted[2], "Expected markdown footer divider to use ParleyFootnote")
-        assert.is_true(highlighted[4], "Expected markdown footnote definition to use ParleyFootnote")
+        assert.is_true(highlighted[2], "Expected markdown footnote definition to use ParleyFootnote")
     end)
 end)

diff --git a/tests/unit/define_spec.lua b/tests/unit/define_spec.lua
index d7b21ec..373f204 100644
--- a/tests/unit/define_spec.lua
+++ b/tests/unit/define_spec.lua
@@ -240,7 +240,17 @@ describe("define durable footnotes", function()
         assert.equals(text, define.strip_definition_footnote_footer(text))
     end)

-    it("reports the final managed footnote footer range", function()
+    it("reports a dividerless managed footnote footer range from the first definition", function()
+        local range = define.managed_footnote_footer_range({
+            "answer text",
+            "",
+            "[^asin]: Amazon Standard Identification Number.",
+        })
+
+        assert.are.same({ start_line = 3, end_line = 3 }, range)
+    end)
+
+    it("reports a divider-based managed footnote footer range from the first definition", function()
         local range = define.managed_footnote_footer_range({
             "answer text",
             "",
@@ -249,7 +259,29 @@ describe("define durable footnotes", function()
             "[^asin]: Amazon Standard Identification Number.",
         })

-        assert.are.same({ start_line = 3, end_line = 5 }, range)
+        assert.are.same({ start_line = 5, end_line = 5 }, range)
+    end)
+
+    it("reports the content trim start at an optional legacy divider", function()
+        local start = define.managed_footnote_content_start({
+            "answer text",
+            "",
+            "---",
+            "",
+            "[^asin]: Amazon Standard Identification Number.",
+        })
+
+        assert.equals(3, start)
+    end)
+
+    it("reports the content trim start at the first definition without a divider", function()
+        local start = define.managed_footnote_content_start({
+            "answer text",
+            "",
+            "[^asin]: Amazon Standard Identification Number.",
+        })
+
+        assert.equals(3, start)
     end)

     it("does not report ordinary horizontal rules as managed footnote footers", function()
@@ -286,12 +318,20 @@ describe("define durable footnotes", function()
         }, "\n"), define.strip_definition_footnote_footer(text))
     end)

+    it("strips a final dividerless managed footnote footer", function()
+        local text = table.concat({
+            "answer text",
+            "",
+            "[^asin]: Amazon Standard Identification Number.",
+        }, "\n")
+
+        assert.equals("answer text", define.strip_definition_footnote_footer(text))
+    end)
+
     it("extracts persisted footnote diagnostics from the managed footer", function()
         local diagnostics = define.footnote_diagnostics({
             "here is ASIN[^asin] in context",
             "",
-            "---",
-            "",
             "[^asin]: Amazon Standard Identification Number.",
         })

@@ -336,17 +376,23 @@ describe("define durable footnotes", function()
         }, diagnostics[2])
     end)

-    it("ignores footnotes that are not in a final managed footer", function()
+    it("treats the first footnote definition as the footer even with trailing text", function()
         local diagnostics = define.footnote_diagnostics({
             "ASIN[^asin] in body",
             "",
-            "---",
-            "",
             "[^asin]: Amazon Standard Identification Number.",
             "",
             "trailing body text",
         })

-        assert.are.same({}, diagnostics)
+        assert.are.same({ {
+            id = "asin",
+            term = "ASIN",
+            definition = "Amazon Standard Identification Number.",
+            lnum = 0,
+            col = 0,
+            end_lnum = 0,
+            end_col = 11,
+        } }, diagnostics)
     end)
 end)
diff --git a/tests/unit/parse_chat_spec.lua b/tests/unit/parse_chat_spec.lua
index dffa59c..4bc6beb 100644
--- a/tests/unit/parse_chat_spec.lua
+++ b/tests/unit/parse_chat_spec.lua
@@ -665,6 +665,19 @@ end)

 describe("parse_chat: edge cases", function()
     it("stops a final open question before a managed footnote footer", function()
+        local lines, header_end = make_chat(std_header, {
+            "💬: tell me about the EVAL framework",
+            "",
+            "[^acos]: ACOS (Advertising Cost of Sales).",
+        })
+        local result = parse_chat(lines, header_end)
+
+        assert.equals("tell me about the EVAL framework", result.exchanges[1].question.content)
+        assert.equals(7, result.exchanges[1].question.line_start)
+        assert.equals(7, result.exchanges[1].question.line_end)
+    end)
+
+    it("stops a final open question before an optional legacy footnote divider", function()
         local lines, header_end = make_chat(std_header, {
             "💬: tell me about the EVAL framework",
             "",
@@ -684,8 +697,6 @@ describe("parse_chat: edge cases", function()
         local lines, header_end = make_chat(std_header, {
             "💬: tell me about the EVAL framework",
             "",
-            "---",
-            "",
             "[^acos]: ACOS (Advertising Cost of Sales).",
         })
         local parsed = parse_chat(lines, header_end)
@@ -695,7 +706,22 @@ describe("parse_chat: edge cases", function()
         local agent_header_start = model:block_start(1, 2)

         assert.equals(8, agent_header_start)
-        assert.equals("---", lines[agent_header_start + 1])
+        assert.equals("[^acos]: ACOS (Advertising Cost of Sales).", lines[agent_header_start + 1])
+    end)
+
+    it("stops a final open question before the first footnote definition even with trailing text", function()
+        local lines, header_end = make_chat(std_header, {
+            "💬: tell me about the EVAL framework",
+            "",
+            "[^acos]: ACOS (Advertising Cost of Sales).",
+            "",
+            "trailing footer text",
+        })
+        local result = parse_chat(lines, header_end)
+
+        assert.equals("tell me about the EVAL framework", result.exchanges[1].question.content)
+        assert.equals(7, result.exchanges[1].question.line_start)
+        assert.equals(7, result.exchanges[1].question.line_end)
     end)

     it("handles assistant message with no preceding user message", function()
diff --git a/workshop/lessons.md b/workshop/lessons.md
index 481b48a..3c5b63b 100644
--- a/workshop/lessons.md
+++ b/workshop/lessons.md
@@ -149,3 +149,6 @@
 ## 2026-07-08 (#171)
 - **A new `config.highlight.*` override is user-facing even when it is optional.** #171 added `config.highlight.footnote` support in the highlighter and documented the highlight group in atlas, but the close review caught that the default config/reference table still omitted the key. Rule: whenever code reads a new config override key, update `lua/parley/config.lua`'s defaults in the same commit and grep README/atlas for config snippets that mirror those defaults.
 - **Generated SDLC review sidecars are still committed artifacts.** The #171 close sidecar captured trailing whitespace from the review transcript and made `git diff --check base..HEAD` fail even though source files were clean. Rule: after any `sdlc close`/review sidecar generation, run `git diff --check <base>..HEAD -- workshop/plans/<issue>-*-review.md` (or strip trailing whitespace on the sidecar) before committing the close artifact.
+
+## 2026-07-08 (#178)
+- **After changing a shared parser rule, grep for every shadow parser before close.** #178 changed `define.managed_footnote_footer_range`, but `chat_parser.lua` still had a local footer scanner at close review. Rule: for grammar or boundary-policy changes, grep the old predicates/terms and route all consumers through shared helpers before boundary review.
diff --git a/workshop/plans/000178-recognize-footnote-footer-without-divider-close-review.md b/workshop/plans/000178-recognize-footnote-footer-without-divider-close-review.md
new file mode 100644
index 0000000..175ebf3
--- /dev/null
+++ b/workshop/plans/000178-recognize-footnote-footer-without-divider-close-review.md
@@ -0,0 +1,2897 @@
+# Boundary Review — parley.nvim#178 (whole-issue close)
+
+| field | value |
+|-------|-------|
+| issue | 178 — recognize footnote footer without divider |
+| repo | parley.nvim |
+| issue file | workshop/issues/000178-recognize-footnote-footer-without-divider.md |
+| boundary | whole-issue close |
+| milestone | — |
+| window | c481296d642c30cfbddbe1b5fd62c6265b397fe3..HEAD |
+| command | sdlc close --issue 178 |
+| reviewer | codex |
+| timestamp | 2026-07-08T23:41:30-07:00 |
+| verdict | REWORK |
+
+## Review
+
+Reading additional input from stdin...
+OpenAI Codex v0.143.0
+--------
+workdir: /Users/xianxu/workspace/parley.nvim
+model: gpt-5.5
+provider: openai
+approval: never
+sandbox: workspace-write [workdir, /tmp, $TMPDIR, /tmp] (network access enabled)
+reasoning effort: none
+reasoning summaries: none
+session id: 019f459a-729e-7003-b01b-15c41ebca177
+--------
+user
+# Code review — the one SDLC boundary review
+
+You are conducting a fresh-context code review at a development boundary —
+whole-issue close — in the **parley.nvim** repository.
+
+- repository: parley.nvim   (root: /Users/xianxu/workspace/parley.nvim)
+- issue:      parley.nvim#178   (file: workshop/issues/000178-recognize-footnote-footer-without-divider.md)
+- window:     Base: c481296d642c30cfbddbe1b5fd62c6265b397fe3   Head: HEAD
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
+index d40dec6..1a14c80 100644
+--- a/atlas/chat/inline_define.md
++++ b/atlas/chat/inline_define.md
+@@ -65,8 +65,8 @@ watcher doesn't mistake it for a user edit.
+   `context_for_selection`, `format_definition`, `bracket_edit` (plans the `[term]`
+   wrap as a legacy set_lines edit), `diagnostic_span_after_bracket` (legacy range
+   mapping), `apply_definition_footnote` (durable footer transform), and
+-  `strip_definition_footnote_footer` / `footnote_diagnostics` (read only a final
+-  `---` block followed solely by footnotes).
++  `strip_definition_footnote_footer` / `footnote_diagnostics` (treat the first
++  markdown footnote definition line as the managed footer boundary).
+ - **IO shell** (`lua/parley/init.lua`): `define_visual`, `render_definition`;
+   `lua/parley/buffer_edit.lua` owns the full-buffer footnote rewrite;
+   `lua/parley/skill_render.lua` publishes footnote diagnostics; and
+@@ -77,22 +77,19 @@ watcher doesn't mistake it for a user edit.
+
+ ## Managed Footnote Footer
+
+-The footer is a final markdown block:
++The footer begins at the first markdown footnote definition line:
+
+ ```markdown
+----
+-
+ [^asin]: Amazon Standard Identification Number.
+ ```
+
+-The footer detector is deliberately conservative: only the last standalone
+-`---` line followed by blank lines and footnote definitions counts as the
+-managed footer. Ordinary horizontal rules and mixed prose after `---` remain
+-chat content. `chat_respond.build_messages` strips this managed footer from
+-message strings before LLM submission, so durable definitions do not become
+-prompt context. `define.footnote_diagnostics` uses the same footer detector to
+-scan inline references before the footer and produce diagnostics for each
+-matching `[^id]`.
++Older define edits may include a standalone `---` separator immediately before
++that first footnote definition; the stripper removes that optional separator
++along with the footer, but the canonical boundary is the `[^id]: ...` line.
++`chat_respond.build_messages` strips this managed footer from message strings
++before LLM submission, so durable definitions do not become prompt context.
++`define.footnote_diagnostics` uses the same footer detector to scan inline
++references before the footer and produce diagnostics for each matching `[^id]`.
+
+ ## Keybinding
+
+diff --git a/atlas/ui/highlights.md b/atlas/ui/highlights.md
+index 27290df..e50fa51 100644
+--- a/atlas/ui/highlights.md
++++ b/atlas/ui/highlights.md
+@@ -6,7 +6,7 @@ Custom groups (`ParleyQuestion`, `ParleyFileReference`, `ParleyChatReference`, `
+ ## Key Behaviors
+ - Applied via decoration providers with ephemeral extmarks per window viewport
+ - Multi-window safe: independent redraw cache per window
+-- Managed definition-footnote footers (`---` + `[^id]: ...`) use
++- Managed definition-footnote footers (from the first `[^id]: ...` line) use
+   `ParleyFootnote` in chat and markdown buffers instead of inheriting the active
+   chat exchange color.
+ - `🌿:` lines auto-rendered with debounced topic lookup from referenced files
+diff --git a/lua/parley/define.lua b/lua/parley/define.lua
+index 44817c1..1d43845 100644
+--- a/lua/parley/define.lua
++++ b/lua/parley/define.lua
+@@ -168,22 +168,9 @@ local function is_footnote_line(line)
+ end
+
+ local function managed_footer_start(lines)
+-    for i = #lines, 1, -1 do
+-        if is_divider(lines[i]) then
+-            local has_footnote = false
+-            for j = i + 1, #lines do
+-                local line = lines[j] or ""
+-                if trim(line) ~= "" then
+-                    if not is_footnote_line(line) then
+-                        return nil
+-                    end
+-                    has_footnote = true
+-                end
+-            end
+-            if has_footnote then
+-                return i
+-            end
+-            return nil
++    for i, line in ipairs(lines or {}) do
++        if is_footnote_line(line) then
++            return i
+         end
+     end
+     return nil
+@@ -237,7 +224,7 @@ function M.footnote_diagnostics(lines)
+     end
+
+     local definitions = {}
+-    for i = footer + 1, #lines do
++    for i = footer, #lines do
+         local id, definition = parse_footnote_line(lines[i] or "")
+         if id then
+             definitions[id] = definition
+@@ -312,6 +299,12 @@ function M.strip_definition_footnote_footer(text)
+     while start > 1 and trim(lines[start - 1]) == "" do
+         start = start - 1
+     end
++    if start > 1 and is_divider(lines[start - 1]) then
++        start = start - 1
++        while start > 1 and trim(lines[start - 1]) == "" do
++            start = start - 1
++        end
++    end
+     local kept = {}
+     for i = 1, start - 1 do
+         kept[#kept + 1] = lines[i]
+@@ -327,7 +320,7 @@ local function replace_or_append_footnote(lines, id, definition)
+     local footer = managed_footer_start(out)
+     local footnote_line = M.format_footnote_line(id, definition)
+     if footer then
+-        for i = footer + 1, #out do
++        for i = footer, #out do
+             local escaped_id = id:gsub("([^%w])", "%%%1")
+             if trim(out[i]):match("^%[%^" .. escaped_id .. "%]:") then
+                 out[i] = footnote_line
+diff --git a/tests/integration/highlighting_spec.lua b/tests/integration/highlighting_spec.lua
+index 43bf5f8..ee6748b 100644
+--- a/tests/integration/highlighting_spec.lua
++++ b/tests/integration/highlighting_spec.lua
+@@ -170,18 +170,12 @@ describe("highlight_question_block: managed footnote footer", function()
+             "💬: Define ASIN",
+             "This question is still open.",
+             "",
+-            "---",
+-            "",
+             "[^asin]: Amazon Standard Identification Number.",
+         })
+
+         assert.is_true(has_highlight(buf, 3, "ParleyFootnote"),
+-            "Expected the managed footer divider to use ParleyFootnote")
+-        assert.is_true(has_highlight(buf, 5, "ParleyFootnote"),
+             "Expected the managed footnote definition to use ParleyFootnote")
+         assert.is_false(has_highlight(buf, 3, "ParleyQuestion"),
+-            "Managed footer divider should not inherit open-question color")
+-        assert.is_false(has_highlight(buf, 5, "ParleyQuestion"),
+             "Managed footnote definition should not inherit open-question color")
+     end)
+ end)
+@@ -528,8 +522,6 @@ describe("markdown footnote diagnostics", function()
+         vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
+             "here is ASIN[^asin] in context",
+             "",
+-            "---",
+-            "",
+             "[^asin]: Amazon Standard Identification Number.",
+         })
+
+@@ -571,8 +563,6 @@ describe("markdown footnote diagnostics", function()
+         vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
+             "here is ASIN[^asin] in context",
+             "",
+-            "---",
+-            "",
+             "[^asin]: Amazon Standard Identification Number.",
+         })
+         vim.cmd("doautocmd TextChanged")
+@@ -603,15 +593,13 @@ describe("markdown footnote diagnostics", function()
+         vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
+             "here is ASIN[^asin] in context",
+             "",
+-            "---",
+-            "",
+             "[^asin]: Amazon Standard Identification Number.",
+         })
+         parley._parley_bufs[buf] = "markdown"
+
+         local win = vim.api.nvim_get_current_win()
+         vim.api.nvim_win_set_buf(win, buf)
+-        provider.on_win(nil, win, buf, 0, 4)
++        provider.on_win(nil, win, buf, 0, 2)
+
+         local original_set_extmark = vim.api.nvim_buf_set_extmark
+         local extmarks = {}
+@@ -621,7 +609,6 @@ describe("markdown footnote diagnostics", function()
+         end
+
+         provider.on_line(nil, win, buf, 2)
+-        provider.on_line(nil, win, buf, 4)
+
+         vim.api.nvim_buf_set_extmark = original_set_extmark
+
+@@ -631,8 +618,7 @@ describe("markdown footnote diagnostics", function()
+                 highlighted[mark.row] = true
+             end
+         end
+-        assert.is_true(highlighted[2], "Expected markdown footer divider to use ParleyFootnote")
+-        assert.is_true(highlighted[4], "Expected markdown footnote definition to use ParleyFootnote")
++        assert.is_true(highlighted[2], "Expected markdown footnote definition to use ParleyFootnote")
+     end)
+ end)
+
+diff --git a/tests/unit/define_spec.lua b/tests/unit/define_spec.lua
+index d7b21ec..f7e6b5b 100644
+--- a/tests/unit/define_spec.lua
++++ b/tests/unit/define_spec.lua
+@@ -240,7 +240,17 @@ describe("define durable footnotes", function()
+         assert.equals(text, define.strip_definition_footnote_footer(text))
+     end)
+
+-    it("reports the final managed footnote footer range", function()
++    it("reports a dividerless managed footnote footer range from the first definition", function()
++        local range = define.managed_footnote_footer_range({
++            "answer text",
++            "",
++            "[^asin]: Amazon Standard Identification Number.",
++        })
++
++        assert.are.same({ start_line = 3, end_line = 3 }, range)
++    end)
++
++    it("reports a divider-based managed footnote footer range from the first definition", function()
+         local range = define.managed_footnote_footer_range({
+             "answer text",
+             "",
+@@ -249,7 +259,7 @@ describe("define durable footnotes", function()
+             "[^asin]: Amazon Standard Identification Number.",
+         })
+
+-        assert.are.same({ start_line = 3, end_line = 5 }, range)
++        assert.are.same({ start_line = 5, end_line = 5 }, range)
+     end)
+
+     it("does not report ordinary horizontal rules as managed footnote footers", function()
+@@ -286,12 +296,20 @@ describe("define durable footnotes", function()
+         }, "\n"), define.strip_definition_footnote_footer(text))
+     end)
+
++    it("strips a final dividerless managed footnote footer", function()
++        local text = table.concat({
++            "answer text",
++            "",
++            "[^asin]: Amazon Standard Identification Number.",
++        }, "\n")
++
++        assert.equals("answer text", define.strip_definition_footnote_footer(text))
++    end)
++
+     it("extracts persisted footnote diagnostics from the managed footer", function()
+         local diagnostics = define.footnote_diagnostics({
+             "here is ASIN[^asin] in context",
+             "",
+-            "---",
+-            "",
+             "[^asin]: Amazon Standard Identification Number.",
+         })
+
+@@ -336,17 +354,23 @@ describe("define durable footnotes", function()
+         }, diagnostics[2])
+     end)
+
+-    it("ignores footnotes that are not in a final managed footer", function()
++    it("treats the first footnote definition as the footer even with trailing text", function()
+         local diagnostics = define.footnote_diagnostics({
+             "ASIN[^asin] in body",
+             "",
+-            "---",
+-            "",
+             "[^asin]: Amazon Standard Identification Number.",
+             "",
+             "trailing body text",
+         })
+
+-        assert.are.same({}, diagnostics)
++        assert.are.same({ {
++            id = "asin",
++            term = "ASIN",
++            definition = "Amazon Standard Identification Number.",
++            lnum = 0,
++            col = 0,
++            end_lnum = 0,
++            end_col = 11,
++        } }, diagnostics)
+     end)
+ end)
+
+
+codex
+I’ll use `superpowers-using-superpowers` first as required, then inspect the issue/plan and the changed code against the provided diff before giving the boundary verdict.
+exec
+/bin/zsh -lc "sed -n '1,220p' /Users/xianxu/workspace/ariadne/construct/adapted/superpowers-using-superpowers/SKILL.md && sdlc --help && sed -n '1,220p' workshop/lessons.md && sed -n '1,240p' workshop/issues/000178-recognize-footnote-footer-without-divider.md && sed -n '140,340p' lua/parley/define.lua" in /Users/xianxu/workspace/parley.nvim
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
+## 2026-07-08 (#174)
+- **`virt_lines_leftcol = true` means gutter/window-left anchoring, not buffer text-column anchoring.** #173 used it to escape Neovim's stock diagnostic-column indentation on long wrapped prose, but the follow-up screenshot showed the block starting in the line-number/sign gutter. For diagnostic text that should align with paragraph content, place the extmark at column 0 and omit `virt_lines_leftcol`; test the extmark options directly so "visible" does not regress into "misaligned."
+
+## 2026-07-08 (#175)
+- **Shared diagnostic display needs source-specific visibility predicates when sources mean different things.** Review diagnostics span an edit region and should show anywhere inside `lnum..end_lnum`; footnote diagnostics point at a precise `term[^id]` anchor and should show only when the cursor is inside `col..end_col`. A single "current line" predicate was too broad for footnotes. Rule: when multiple diagnostic sources share one renderer, test each source's visibility contract explicitly.
+
+## 2026-07-08 (#176)
+- **README snippets are consumers of user-facing UI behavior, not marketing fluff.** #176 updated atlas when footnote definitions moved from virtual lines to a centered float, but the close review caught README still saying "grey pop-under" for visual `<M-CR>`. Rule: when changing a visible command/keybinding behavior, grep README for the command, keybinding, and old UI nouns alongside atlas.
+
+## 2026-07-08 (#171)
+- **A new `config.highlight.*` override is user-facing even when it is optional.** #171 added `config.highlight.footnote` support in the highlighter and documented the highlight group in atlas, but the close review caught that the default config/reference table still omitted the key. Rule: whenever code reads a new config override key, update `lua/parley/config.lua`'s defaults in the same commit and grep README/atlas for config snippets that mirror those defaults.
+- **Generated SDLC review sidecars are still committed artifacts.** The #171 close sidecar captured trailing whitespace from the review transcript and made `git diff --check base..HEAD` fail even though source files were clean. Rule: after any `sdlc close`/review sidecar generation, run `git diff --check <base>..HEAD -- workshop/plans/<issue>-*-review.md` (or strip trailing whitespace on the sidecar) before committing the close artifact.
+---
+id: 000178
+status: working
+deps: []
+github_issue:
+created: 2026-07-08
+updated: 2026-07-08
+estimate_hours: 0.27
+started: 2026-07-08T23:33:32-07:00
+---
+
+# recognize footnote footer without divider
+
+## Problem
+
+The #171 footnote-coloring fix still defines a managed footnote footer as a final
+`---` divider followed by `[^id]: ...` lines. The desired footer boundary is
+simpler: the first markdown footnote definition line (`[^id]: ...`) starts the
+footer, even when no divider is present.
+
+## Spec
+
+`parley.define.managed_footnote_footer_range(lines)` returns the range from the
+first line that starts with a markdown footnote definition pattern (`[^id]:`) to
+EOF. It no longer requires a preceding `---` divider.
+
+All current consumers keep deriving from that helper (ARCH-DRY, ARCH-PURE):
+footnote diagnostics, footer stripping, and chat/markdown highlighting should
+adopt the new boundary without duplicating parser logic.
+
+## Done when
+
+- A buffer with `[^asin]: ...` and no preceding `---` is recognized as having a
+  managed footnote footer starting at that line.
+- Footnote diagnostics and `ParleyFootnote` highlighting work for dividerless
+  footers.
+- Existing divider-based footers remain supported, but the footer range starts at
+  the first `[^id]:` line, not at `---`.
+
+## Plan
+
+- [x] Add failing pure tests for dividerless footer range and stripping.
+- [x] Add/update integration coverage for diagnostics/highlighting with a
+  dividerless footer.
+- [x] Change the pure footer helper to scan for the first footnote definition
+  line and let consumers derive from it.
+- [x] Run focused unit/integration verification plus lint/diff checks.
+
+## Estimate
+
+Derived via `estimate-logic-v3.1` against the repo-local calibration source from
+`sdlc estimate-source` (stale but canonical for this repo).
+
+```estimate
+model: estimate-logic-v3.1
+familiarity: 1.0
+item: issue-spec design=0.03 impl=0.00
+item: lua-neovim design=0.05 impl=0.15
+item: milestone-review design=0.00 impl=0.02
+total: 0.27
+```
+
+## Log
+
+### 2026-07-08
+
+- User clarified the #171 footer check should be based on the first `[^id]:`
+  footnote definition line instead of a `---` + footnote block. Design keeps the
+  grammar in `parley.define.managed_footnote_footer_range` so diagnostics and
+  highlighters remain derived consumers.
+- TDD red: dividerless footer unit/integration tests failed because the detector
+  still required a final divider block and consumers skipped the first footnote
+  definition line.
+- Implemented the pure detector as "first footnote definition line to EOF" and
+  updated diagnostics/update/strip loops to consume from that returned boundary.
+- Verification: `make lint` passed; `nvim --headless -c "PlenaryBustedFile
+  tests/unit/define_spec.lua"` passed; `nvim --headless -c "PlenaryBustedFile
+  tests/integration/highlighting_spec.lua"` passed; scoped `git diff --check`
+  passed. Full `make test` still fails in unrelated
+  `tests/unit/tools_builtin_find_spec.lua` only under the parallel full-suite
+  runner; that spec passes directly.
+--- @return string
+function M.footnote_id(term)
+    local id = tostring(term or ""):lower()
+    id = id:gsub("[^%w]+", "-")
+    id = id:gsub("^%-+", ""):gsub("%-+$", "")
+    if id == "" then
+        id = "definition"
+    end
+    return id
+end
+
+--- @param id string
+--- @param definition string|nil
+--- @return string
+function M.format_footnote_line(id, definition)
+    definition = trim(definition)
+    if definition == "" then
+        definition = "(no definition)"
+    end
+    return string.format("[^%s]: %s", id, definition)
+end
+
+local function is_divider(line)
+    return trim(line) == "---"
+end
+
+local function is_footnote_line(line)
+    return trim(line):match("^%[%^[^%]]+%]:") ~= nil
+end
+
+local function managed_footer_start(lines)
+    for i, line in ipairs(lines or {}) do
+        if is_footnote_line(line) then
+            return i
+        end
+    end
+    return nil
+end
+
+--- Locate the final managed definition-footnote footer.
+--- @param lines string[]|nil
+--- @return table|nil { start_line: integer, end_line: integer } 1-based inclusive
+function M.managed_footnote_footer_range(lines)
+    lines = lines or {}
+    local start = managed_footer_start(lines)
+    if not start then
+        return nil
+    end
+    return { start_line = start, end_line = #lines }
+end
+
+local function parse_footnote_line(line)
+    local id, definition = trim(line):match("^%[%^([^%]]+)%]:%s*(.-)%s*$")
+    if not id then
+        return nil
+    end
+    definition = trim(definition)
+    if definition == "" then
+        definition = "(no definition)"
+    end
+    return id, definition
+end
+
+local function is_term_byte(ch)
+    return ch:match("[%w_-]") ~= nil
+end
+
+local function expand_term_start(line, ref_start)
+    local start = ref_start
+    while start > 1 and is_term_byte(line:sub(start - 1, start - 1)) do
+        start = start - 1
+    end
+    return start
+end
+
+--- Derive persisted definition diagnostics from inline footnote references and
+--- the final managed definition footer.
+--- @param lines string[]
+--- @return table[] diagnostics with 0-based columns
+function M.footnote_diagnostics(lines)
+    lines = lines or {}
+    local footer = managed_footer_start(lines)
+    if not footer then
+        return {}
+    end
+
+    local definitions = {}
+    for i = footer, #lines do
+        local id, definition = parse_footnote_line(lines[i] or "")
+        if id then
+            definitions[id] = definition
+        end
+    end
+
+    local diagnostics = {}
+    for lnum = 1, footer - 1 do
+        local line = lines[lnum] or ""
+        local search = 1
+        while true do
+            local ref_start, ref_end, id = line:find("%[%^([^%]]+)%]", search)
+            if not ref_start then
+                break
+            end
+            local definition = definitions[id]
+            if definition then
+                local term_start = expand_term_start(line, ref_start)
+                local term = line:sub(term_start, ref_start - 1)
+                table.insert(diagnostics, {
+                    id = id,
+                    term = term ~= "" and term or nil,
+                    definition = definition,
+                    lnum = lnum - 1,
+                    col = term_start - 1,
+                    end_lnum = lnum - 1,
+                    end_col = ref_end,
+                })
+            end
+            search = ref_end + 1
+        end
+    end
+    return diagnostics
+end
+
+local function split_text_lines(text)
+    text = text or ""
+    local lines = {}
+    local start = 1
+    while true do
+        local nl = text:find("\n", start, true)
+        if not nl then
+            lines[#lines + 1] = text:sub(start)
+            break
+        end
+        lines[#lines + 1] = text:sub(start, nl - 1)
+        start = nl + 1
+    end
+    if #lines > 1 and lines[#lines] == "" then
+        table.remove(lines)
+    end
+    return lines
+end
+
+local function copy_lines(lines)
+    local out = {}
+    for i, line in ipairs(lines or {}) do
+        out[i] = line
+    end
+    return out
+end
+
+--- Strip a final managed definition-footnote footer from text.
+--- @param text string|nil
+--- @return string
+function M.strip_definition_footnote_footer(text)
+    local lines = split_text_lines(text or "")
+    local start = managed_footer_start(lines)
+    if not start then
+        return text or ""
+    end
+    while start > 1 and trim(lines[start - 1]) == "" do
+        start = start - 1
+    end
+    if start > 1 and is_divider(lines[start - 1]) then
+        start = start - 1
+        while start > 1 and trim(lines[start - 1]) == "" do
+            start = start - 1
+        end
+    end
+    local kept = {}
+    for i = 1, start - 1 do
+        kept[#kept + 1] = lines[i]
+    end
+    while #kept > 0 and trim(kept[#kept]) == "" do
+        table.remove(kept)
+    end
+    return table.concat(kept, "\n")
+end
+
+local function replace_or_append_footnote(lines, id, definition)
+    local out = copy_lines(lines)
+    local footer = managed_footer_start(out)
+    local footnote_line = M.format_footnote_line(id, definition)
+    if footer then
+        for i = footer, #out do
+            local escaped_id = id:gsub("([^%w])", "%%%1")
+            if trim(out[i]):match("^%[%^" .. escaped_id .. "%]:") then
+                out[i] = footnote_line
+                return out
+            end
+        end
+        out[#out + 1] = footnote_line
+        return out
+    end
+
+    while #out > 0 and trim(out[#out]) == "" do
+        table.remove(out)
+    end
+    out[#out + 1] = ""
+    out[#out + 1] = "---"
+    out[#out + 1] = ""
+    out[#out + 1] = footnote_line
+
+codex
+I’ve got the issue contract and the main pure helper in view. The key question is whether “first footnote definition line starts the footer” was applied consistently without leaving old divider assumptions or widening behavior beyond the spec.
+exec
+/bin/zsh -lc "nl -ba lua/parley/define.lua | sed -n '150,340p'" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+   150
+   151    --- @param id string
+   152    --- @param definition string|nil
+   153    --- @return string
+   154    function M.format_footnote_line(id, definition)
+   155        definition = trim(definition)
+   156        if definition == "" then
+   157            definition = "(no definition)"
+   158        end
+   159        return string.format("[^%s]: %s", id, definition)
+   160    end
+   161
+   162    local function is_divider(line)
+   163        return trim(line) == "---"
+   164    end
+   165
+   166    local function is_footnote_line(line)
+   167        return trim(line):match("^%[%^[^%]]+%]:") ~= nil
+   168    end
+   169
+   170    local function managed_footer_start(lines)
+   171        for i, line in ipairs(lines or {}) do
+   172            if is_footnote_line(line) then
+   173                return i
+   174            end
+   175        end
+   176        return nil
+   177    end
+   178
+   179    --- Locate the final managed definition-footnote footer.
+   180    --- @param lines string[]|nil
+   181    --- @return table|nil { start_line: integer, end_line: integer } 1-based inclusive
+   182    function M.managed_footnote_footer_range(lines)
+   183        lines = lines or {}
+   184        local start = managed_footer_start(lines)
+   185        if not start then
+   186            return nil
+   187        end
+   188        return { start_line = start, end_line = #lines }
+   189    end
+   190
+   191    local function parse_footnote_line(line)
+   192        local id, definition = trim(line):match("^%[%^([^%]]+)%]:%s*(.-)%s*$")
+   193        if not id then
+   194            return nil
+   195        end
+   196        definition = trim(definition)
+   197        if definition == "" then
+   198            definition = "(no definition)"
+   199        end
+   200        return id, definition
+   201    end
+   202
+   203    local function is_term_byte(ch)
+   204        return ch:match("[%w_-]") ~= nil
+   205    end
+   206
+   207    local function expand_term_start(line, ref_start)
+   208        local start = ref_start
+   209        while start > 1 and is_term_byte(line:sub(start - 1, start - 1)) do
+   210            start = start - 1
+   211        end
+   212        return start
+   213    end
+   214
+   215    --- Derive persisted definition diagnostics from inline footnote references and
+   216    --- the final managed definition footer.
+   217    --- @param lines string[]
+   218    --- @return table[] diagnostics with 0-based columns
+   219    function M.footnote_diagnostics(lines)
+   220        lines = lines or {}
+   221        local footer = managed_footer_start(lines)
+   222        if not footer then
+   223            return {}
+   224        end
+   225
+   226        local definitions = {}
+   227        for i = footer, #lines do
+   228            local id, definition = parse_footnote_line(lines[i] or "")
+   229            if id then
+   230                definitions[id] = definition
+   231            end
+   232        end
+   233
+   234        local diagnostics = {}
+   235        for lnum = 1, footer - 1 do
+   236            local line = lines[lnum] or ""
+   237            local search = 1
+   238            while true do
+   239                local ref_start, ref_end, id = line:find("%[%^([^%]]+)%]", search)
+   240                if not ref_start then
+   241                    break
+   242                end
+   243                local definition = definitions[id]
+   244                if definition then
+   245                    local term_start = expand_term_start(line, ref_start)
+   246                    local term = line:sub(term_start, ref_start - 1)
+   247                    table.insert(diagnostics, {
+   248                        id = id,
+   249                        term = term ~= "" and term or nil,
+   250                        definition = definition,
+   251                        lnum = lnum - 1,
+   252                        col = term_start - 1,
+   253                        end_lnum = lnum - 1,
+   254                        end_col = ref_end,
+   255                    })
+   256                end
+   257                search = ref_end + 1
+   258            end
+   259        end
+   260        return diagnostics
+   261    end
+   262
+   263    local function split_text_lines(text)
+   264        text = text or ""
+   265        local lines = {}
+   266        local start = 1
+   267        while true do
+   268            local nl = text:find("\n", start, true)
+   269            if not nl then
+   270                lines[#lines + 1] = text:sub(start)
+   271                break
+   272            end
+   273            lines[#lines + 1] = text:sub(start, nl - 1)
+   274            start = nl + 1
+   275        end
+   276        if #lines > 1 and lines[#lines] == "" then
+   277            table.remove(lines)
+   278        end
+   279        return lines
+   280    end
+   281
+   282    local function copy_lines(lines)
+   283        local out = {}
+   284        for i, line in ipairs(lines or {}) do
+   285            out[i] = line
+   286        end
+   287        return out
+   288    end
+   289
+   290    --- Strip a final managed definition-footnote footer from text.
+   291    --- @param text string|nil
+   292    --- @return string
+   293    function M.strip_definition_footnote_footer(text)
+   294        local lines = split_text_lines(text or "")
+   295        local start = managed_footer_start(lines)
+   296        if not start then
+   297            return text or ""
+   298        end
+   299        while start > 1 and trim(lines[start - 1]) == "" do
+   300            start = start - 1
+   301        end
+   302        if start > 1 and is_divider(lines[start - 1]) then
+   303            start = start - 1
+   304            while start > 1 and trim(lines[start - 1]) == "" do
+   305                start = start - 1
+   306            end
+   307        end
+   308        local kept = {}
+   309        for i = 1, start - 1 do
+   310            kept[#kept + 1] = lines[i]
+   311        end
+   312        while #kept > 0 and trim(kept[#kept]) == "" do
+   313            table.remove(kept)
+   314        end
+   315        return table.concat(kept, "\n")
+   316    end
+   317
+   318    local function replace_or_append_footnote(lines, id, definition)
+   319        local out = copy_lines(lines)
+   320        local footer = managed_footer_start(out)
+   321        local footnote_line = M.format_footnote_line(id, definition)
+   322        if footer then
+   323            for i = footer, #out do
+   324                local escaped_id = id:gsub("([^%w])", "%%%1")
+   325                if trim(out[i]):match("^%[%^" .. escaped_id .. "%]:") then
+   326                    out[i] = footnote_line
+   327                    return out
+   328                end
+   329            end
+   330            out[#out + 1] = footnote_line
+   331            return out
+   332        end
+   333
+   334        while #out > 0 and trim(out[#out]) == "" do
+   335            table.remove(out)
+   336        end
+   337        out[#out + 1] = ""
+   338        out[#out + 1] = "---"
+   339        out[#out + 1] = ""
+   340        out[#out + 1] = footnote_line
+
+exec
+/bin/zsh -lc "nl -ba tests/integration/highlighting_spec.lua | sed -n '150,210p;510,635p'" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+   150            })
+   151            assert.is_true(has_highlight(buf, 1, "ParleyFileReference"),
+   152                "Expected 'ParleyFileReference' highlight on @@ file reference line")
+   153        end)
+   154
+   155        it("does NOT apply ParleyFileReference highlight to @@ lines outside question blocks", function()
+   156            local buf = highlighted_buf({
+   157                "🤖:[Agent] See @@/some/file.lua here",
+   158            })
+   159            -- Row 0 is an answer line; ParleyFileReference should not be applied
+   160            assert.is_false(has_highlight(buf, 0, "ParleyFileReference"),
+   161                "ParleyFileReference should not appear on answer lines")
+   162        end)
+   163    end)
+   164
+   165    describe("highlight_question_block: managed footnote footer", function()
+   166        after_each(cleanup_bufs)
+   167
+   168        it("uses a dedicated footnote highlight instead of open-question coloring", function()
+   169            local buf = highlighted_buf({
+   170                "💬: Define ASIN",
+   171                "This question is still open.",
+   172                "",
+   173                "[^asin]: Amazon Standard Identification Number.",
+   174            })
+   175
+   176            assert.is_true(has_highlight(buf, 3, "ParleyFootnote"),
+   177                "Expected the managed footnote definition to use ParleyFootnote")
+   178            assert.is_false(has_highlight(buf, 3, "ParleyQuestion"),
+   179                "Managed footnote definition should not inherit open-question color")
+   180        end)
+   181    end)
+   182
+   183    describe("decoration provider cache", function()
+   184        after_each(function()
+   185            cleanup_extra_windows()
+   186            cleanup_bufs()
+   187        end)
+   188
+   189        it("keeps highlight caches isolated per window for the same buffer", function()
+   190            local provider = capture_decoration_provider()
+   191            assert.is_table(provider)
+   192            assert.is_function(provider.on_win)
+   193            assert.is_function(provider.on_line)
+   194
+   195            local buf = vim.api.nvim_create_buf(false, true)
+   196            local lines = {}
+   197            for i = 1, 120 do
+   198                lines[i] = ("filler line %03d"):format(i)
+   199            end
+   200            lines[1] = "💬: top question"
+   201            lines[71] = "💬: lower question"
+   202            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
+   203
+   204            vim.cmd("vsplit")
+   205            local wins = vim.api.nvim_tabpage_list_wins(0)
+   206            assert.are.same(2, #wins)
+   207            vim.api.nvim_win_set_buf(wins[1], buf)
+   208            vim.api.nvim_win_set_buf(wins[2], buf)
+   209
+   210            parley._parley_bufs[buf] = "chat"
+   510                for _, buf in ipairs(vim.api.nvim_list_bufs()) do
+   511                    if vim.api.nvim_buf_is_valid(buf) then
+   512                        pcall(vim.diagnostic.reset, skill_render.diag_namespace(), buf)
+   513                    end
+   514                end
+   515            end
+   516            cleanup_bufs()
+   517        end)
+   518
+   519        it("publishes persisted managed footnotes as Parley diagnostics", function()
+   520            local skill_render = require("parley.skill_render")
+   521            local buf = vim.api.nvim_create_buf(false, true)
+   522            vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
+   523                "here is ASIN[^asin] in context",
+   524                "",
+   525                "[^asin]: Amazon Standard Identification Number.",
+   526            })
+   527
+   528            skill_render.refresh_footnote_diagnostics(buf)
+   529
+   530            local diagnostics = vim.diagnostic.get(buf, { namespace = skill_render.diag_namespace() })
+   531            assert.equals(1, #diagnostics)
+   532            assert.equals(0, diagnostics[1].lnum)
+   533            assert.equals(8, diagnostics[1].col)
+   534            assert.equals(19, diagnostics[1].end_col)
+   535            assert.equals("parley-footnote", diagnostics[1].source)
+   536            assert.is_true(diagnostics[1].message:find("ASIN", 1, true) ~= nil)
+   537            assert.is_true(diagnostics[1].message:find("Amazon Standard Identification Number.", 1, true) ~= nil)
+   538        end)
+   539
+   540        it("refreshes footnote diagnostics on markdown text changes without clearing other Parley diagnostics", function()
+   541            local skill_render = require("parley.skill_render")
+   542            local ns = skill_render.diag_namespace()
+   543            local buf = vim.api.nvim_create_buf(false, true)
+   544            vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), buf)
+   545            parley._parley_bufs[buf] = "markdown"
+   546            vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
+   547                "no footnote yet",
+   548            })
+   549            vim.diagnostic.set(ns, buf, { {
+   550                lnum = 0,
+   551                col = 0,
+   552                message = "review diagnostic",
+   553                severity = vim.diagnostic.severity.INFO,
+   554                source = "parley-skill",
+   555            } })
+   556
+   557            vim.cmd("doautocmd TextChanged")
+   558            vim.wait(100, function()
+   559                local diagnostics = vim.diagnostic.get(buf, { namespace = ns })
+   560                return #diagnostics == 1 and diagnostics[1].source == "parley-skill"
+   561            end)
+   562
+   563            vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
+   564                "here is ASIN[^asin] in context",
+   565                "",
+   566                "[^asin]: Amazon Standard Identification Number.",
+   567            })
+   568            vim.cmd("doautocmd TextChanged")
+   569            vim.wait(100, function()
+   570                local diagnostics = vim.diagnostic.get(buf, { namespace = ns })
+   571                return #diagnostics == 2
+   572            end)
+   573
+   574            local by_source = {}
+   575            for _, diagnostic in ipairs(vim.diagnostic.get(buf, { namespace = ns })) do
+   576                by_source[diagnostic.source] = diagnostic
+   577            end
+   578            assert.is_not_nil(by_source["parley-skill"])
+   579            assert.is_not_nil(by_source["parley-footnote"])
+   580            assert.equals(8, by_source["parley-footnote"].col)
+   581
+   582            vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "footnote removed" })
+   583            vim.cmd("doautocmd TextChanged")
+   584            vim.wait(100, function()
+   585                local diagnostics = vim.diagnostic.get(buf, { namespace = ns })
+   586                return #diagnostics == 1 and diagnostics[1].source == "parley-skill"
+   587            end)
+   588        end)
+   589
+   590        it("renders managed footnote footers with ParleyFootnote in markdown buffers", function()
+   591            local provider = capture_decoration_provider()
+   592            local buf = vim.api.nvim_create_buf(false, true)
+   593            vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
+   594                "here is ASIN[^asin] in context",
+   595                "",
+   596                "[^asin]: Amazon Standard Identification Number.",
+   597            })
+   598            parley._parley_bufs[buf] = "markdown"
+   599
+   600            local win = vim.api.nvim_get_current_win()
+   601            vim.api.nvim_win_set_buf(win, buf)
+   602            provider.on_win(nil, win, buf, 0, 2)
+   603
+   604            local original_set_extmark = vim.api.nvim_buf_set_extmark
+   605            local extmarks = {}
+   606            vim.api.nvim_buf_set_extmark = function(_, _, row, _, opts)
+   607                table.insert(extmarks, { row = row, hl_group = opts.hl_group })
+   608                return #extmarks
+   609            end
+   610
+   611            provider.on_line(nil, win, buf, 2)
+   612
+   613            vim.api.nvim_buf_set_extmark = original_set_extmark
+   614
+   615            local highlighted = {}
+   616            for _, mark in ipairs(extmarks) do
+   617                if mark.hl_group == "ParleyFootnote" then
+   618                    highlighted[mark.row] = true
+   619                end
+   620            end
+   621            assert.is_true(highlighted[2], "Expected markdown footnote definition to use ParleyFootnote")
+   622        end)
+   623    end)
+   624
+   625    describe("markdown chat reference rendering", function()
+   626        after_each(function()
+   627            cleanup_extra_windows()
+   628            cleanup_bufs()
+   629        end)
+   630
+   631        it("refreshes 🌿: branch lines with the chat topic in markdown buffers", function()
+   632            local chat_path = tmp_dir .. "/2026-03-24.12-34-56.123.md"
+   633            vim.fn.writefile({
+   634                "---",
+   635                "topic: Rendered Topic",
+
+exec
+/bin/zsh -lc "nl -ba tests/unit/define_spec.lua | sed -n '220,380p'" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+   220            local text = table.concat({
+   221                "answer text",
+   222                "",
+   223                "---",
+   224                "",
+   225                "[^asin]: Amazon Standard Identification Number.",
+   226            }, "\n")
+   227
+   228            assert.equals("answer text", define.strip_definition_footnote_footer(text))
+   229        end)
+   230
+   231        it("preserves ordinary horizontal rules that are not managed footnote footers", function()
+   232            local text = table.concat({
+   233                "answer text",
+   234                "",
+   235                "---",
+   236                "",
+   237                "not a footnote",
+   238            }, "\n")
+   239
+   240            assert.equals(text, define.strip_definition_footnote_footer(text))
+   241        end)
+   242
+   243        it("reports a dividerless managed footnote footer range from the first definition", function()
+   244            local range = define.managed_footnote_footer_range({
+   245                "answer text",
+   246                "",
+   247                "[^asin]: Amazon Standard Identification Number.",
+   248            })
+   249
+   250            assert.are.same({ start_line = 3, end_line = 3 }, range)
+   251        end)
+   252
+   253        it("reports a divider-based managed footnote footer range from the first definition", function()
+   254            local range = define.managed_footnote_footer_range({
+   255                "answer text",
+   256                "",
+   257                "---",
+   258                "",
+   259                "[^asin]: Amazon Standard Identification Number.",
+   260            })
+   261
+   262            assert.are.same({ start_line = 5, end_line = 5 }, range)
+   263        end)
+   264
+   265        it("does not report ordinary horizontal rules as managed footnote footers", function()
+   266            local range = define.managed_footnote_footer_range({
+   267                "answer text",
+   268                "",
+   269                "---",
+   270                "",
+   271                "not a footnote",
+   272            })
+   273
+   274            assert.is_nil(range)
+   275        end)
+   276
+   277        it("keeps earlier horizontal-rule content and strips only the final managed footer", function()
+   278            local text = table.concat({
+   279                "answer text",
+   280                "",
+   281                "---",
+   282                "",
+   283                "ordinary body after a rule",
+   284                "",
+   285                "---",
+   286                "",
+   287                "[^asin]: Amazon Standard Identification Number.",
+   288            }, "\n")
+   289
+   290            assert.equals(table.concat({
+   291                "answer text",
+   292                "",
+   293                "---",
+   294                "",
+   295                "ordinary body after a rule",
+   296            }, "\n"), define.strip_definition_footnote_footer(text))
+   297        end)
+   298
+   299        it("strips a final dividerless managed footnote footer", function()
+   300            local text = table.concat({
+   301                "answer text",
+   302                "",
+   303                "[^asin]: Amazon Standard Identification Number.",
+   304            }, "\n")
+   305
+   306            assert.equals("answer text", define.strip_definition_footnote_footer(text))
+   307        end)
+   308
+   309        it("extracts persisted footnote diagnostics from the managed footer", function()
+   310            local diagnostics = define.footnote_diagnostics({
+   311                "here is ASIN[^asin] in context",
+   312                "",
+   313                "[^asin]: Amazon Standard Identification Number.",
+   314            })
+   315
+   316            assert.are.same({ {
+   317                id = "asin",
+   318                term = "ASIN",
+   319                definition = "Amazon Standard Identification Number.",
+   320                lnum = 0,
+   321                col = 8,
+   322                end_lnum = 0,
+   323                end_col = 19,
+   324            } }, diagnostics)
+   325        end)
+   326
+   327        it("extracts every inline reference to a managed footnote", function()
+   328            local diagnostics = define.footnote_diagnostics({
+   329                "ASIN[^asin] first, then SKU[^asin] second",
+   330                "",
+   331                "---",
+   332                "",
+   333                "[^asin]: Amazon Standard Identification Number.",
+   334            })
+   335
+   336            assert.are.equal(2, #diagnostics)
+   337            assert.are.same({
+   338                id = "asin",
+   339                term = "ASIN",
+   340                definition = "Amazon Standard Identification Number.",
+   341                lnum = 0,
+   342                col = 0,
+   343                end_lnum = 0,
+   344                end_col = 11,
+   345            }, diagnostics[1])
+   346            assert.are.same({
+   347                id = "asin",
+   348                term = "SKU",
+   349                definition = "Amazon Standard Identification Number.",
+   350                lnum = 0,
+   351                col = 24,
+   352                end_lnum = 0,
+   353                end_col = 34,
+   354            }, diagnostics[2])
+   355        end)
+   356
+   357        it("treats the first footnote definition as the footer even with trailing text", function()
+   358            local diagnostics = define.footnote_diagnostics({
+   359                "ASIN[^asin] in body",
+   360                "",
+   361                "[^asin]: Amazon Standard Identification Number.",
+   362                "",
+   363                "trailing body text",
+   364            })
+   365
+   366            assert.are.same({ {
+   367                id = "asin",
+   368                term = "ASIN",
+   369                definition = "Amazon Standard Identification Number.",
+   370                lnum = 0,
+   371                col = 0,
+   372                end_lnum = 0,
+   373                end_col = 11,
+   374            } }, diagnostics)
+   375        end)
+   376    end)
+
+exec
+/bin/zsh -lc 'git diff --stat c481296d642c30cfbddbe1b5fd62c6265b397fe3..HEAD && git diff --name-only c481296d642c30cfbddbe1b5fd62c6265b397fe3..HEAD' in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+ atlas/chat/inline_define.md                        | 23 ++++-----
+ atlas/ui/highlights.md                             |  2 +-
+ lua/parley/define.lua                              | 29 ++++-------
+ tests/integration/highlighting_spec.lua            | 18 +------
+ tests/unit/define_spec.lua                         | 40 ++++++++++++---
+ ...78-recognize-footnote-footer-without-divider.md | 59 ++++++++++++++++++++--
+ 6 files changed, 112 insertions(+), 59 deletions(-)
+atlas/chat/inline_define.md
+atlas/ui/highlights.md
+lua/parley/define.lua
+tests/integration/highlighting_spec.lua
+tests/unit/define_spec.lua
+workshop/issues/000178-recognize-footnote-footer-without-divider.md
+
+codex
+The diff has no new user-facing command/config surface, so the README gate looks likely not applicable. Atlas was updated in the two places that explicitly described the footer boundary.
+exec
+/bin/zsh -lc 'rg -n "managed_footnote_footer_range|footnote_diagnostics|strip_definition_footnote_footer|ParleyFootnote|managed footer|footnote footer|%[%''^" lua tests atlas README.md' in /Users/xianxu/workspace/parley.nvim
+ exited 2 in 0ms:
+rg: regex parse error:
+    (?:managed_footnote_footer_range|footnote_diagnostics|strip_definition_footnote_footer|ParleyFootnote|managed footer|footnote footer|%[%^)
+                                                                                                                                          ^
+error: unclosed character class
+
+exec
+/bin/zsh -lc 'git diff --check c481296d642c30cfbddbe1b5fd62c6265b397fe3..HEAD' in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+exec
+/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"' in /Users/xianxu/workspace/parley.nvim
+exec
+/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"' in /Users/xianxu/workspace/parley.nvim
+ succeeded in 1502ms:
+
+Error detected while processing /Users/xianxu/.config/nvim/init.lua:
+Parser dir ' /Users/xianxu/.local/share/nvim/lazy/nvim-treesitter/parser ' should be read/write (see README on how to configure an alternative install location) /Users/xianxu/.local/share/nvim/lazy/nvim-treesitter/parser '
+Parley.nvim: Failed to open file for writing: /Users/xianxu/.local/share/nvim/parley/persisted/state.jsonScheduling: tests/unit/define_spec.lua
+
+========================================
+Testing:     /Users/xianxu/workspace/parley.nvim/tests/unit/define_spec.lua
+[32mSuccess[0m    ||    define.slice_selection extracts a single-line span
+[32mSuccess[0m    ||    define.slice_selection extracts a multi-line span joined with newline
+[32mSuccess[0m    ||    define.slice_selection clamps an end column past line length
+[32mSuccess[0m    ||    define.slice_selection returns empty string for a reversed/empty span
+[32mSuccess[0m    ||    define.context_for_selection returns the enclosing exchange's lines (question..answer)
+[32mSuccess[0m    ||    define.context_for_selection handles an answerless exchange (question only)
+[32mSuccess[0m    ||    define.context_for_selection falls back to the whole buffer when outside any exchange
+[32mSuccess[0m    ||    define.format_definition composes 'TERM — definition'
+[32mSuccess[0m    ||    define.format_definition hard-wraps to width
+[32mSuccess[0m    ||    define.format_definition passes nil width through to the shared diagnostic formatter
+[32mSuccess[0m    ||    define.format_definition trims a nil/blank definition to a safe string
+[32mSuccess[0m    ||    define.bracket_edit wraps a single-line span into a set_lines edit
+[32mSuccess[0m    ||    define.bracket_edit clamps end col past line length
+[32mSuccess[0m    ||    define.bracket_edit wraps a multi-line span
+[32mSuccess[0m    ||    define.diagnostic_span_after_bracket anchors a single-line selection on the selected text after brackets
+[32mSuccess[0m    ||    define.diagnostic_span_after_bracket anchors a multi-line selection without shifting the final line
+[32mSuccess[0m    ||    define durable footnotes slugifies a definition term into a markdown footnote id
+[32mSuccess[0m    ||    define durable footnotes adds an inline footnote reference and appends a managed footer
+[32mSuccess[0m    ||    define durable footnotes updates an existing managed footnote instead of duplicating it
+[32mSuccess[0m    ||    define durable footnotes updates an existing inline reference without duplicating it
+[32mSuccess[0m    ||    define durable footnotes strips only a final managed footnote footer
+[32mSuccess[0m    ||    define durable footnotes preserves ordinary horizontal rules that are not managed footnote footers
+[32mSuccess[0m    ||    define durable footnotes reports a dividerless managed footnote footer range from the first definition
+[32mSuccess[0m    ||    define durable footnotes reports a divider-based managed footnote footer range from the first definition
+[32mSuccess[0m    ||    define durable footnotes does not report ordinary horizontal rules as managed footnote footers
+[32mSuccess[0m    ||    define durable footnotes keeps earlier horizontal-rule content and strips only the final managed footer
+[32mSuccess[0m    ||    define durable footnotes strips a final dividerless managed footnote footer
+[32mSuccess[0m    ||    define durable footnotes extracts persisted footnote diagnostics from the managed footer
+[32mSuccess[0m    ||    define durable footnotes extracts every inline reference to a managed footnote
+[32mSuccess[0m    ||    define durable footnotes treats the first footnote definition as the footer even with trailing text
+
+[32mSuccess: [0m    30
+[31mFailed : [0m    0
+[31mErrors : [0m    0
+========================================
+]111
+ succeeded in 2169ms:
+
+Parley.nvim: Failed to open file for writing: /Users/xianxu/.local/share/nvim/parley/persisted/state.jsonScheduling: tests/integration/highlighting_spec.lua
+
+========================================
+Testing:     /Users/xianxu/workspace/parley.nvim/tests/integration/highlighting_spec.lua
+[32mSuccess[0m    ||    highlight_question_block: question lines applies Question highlight to 💬: line (row 0)
+[32mSuccess[0m    ||    highlight_question_block: question lines applies ParleyQuestion highlight to continuation lines of a question block
+[32mSuccess[0m    ||    highlight_question_block: question lines does NOT apply ParleyQuestion highlight to 🤖: answer lines
+[32mSuccess[0m    ||    highlight_question_block: thinking lines applies Think highlight to 📝: summary line
+[32mSuccess[0m    ||    highlight_question_block: thinking lines applies ParleyThinking highlight to 🧠: reasoning line
+[32mSuccess[0m    ||    highlight_question_block: file reference lines applies FileLoading highlight to @@ file reference lines in a question block
+[32mSuccess[0m    ||    highlight_question_block: file reference lines does NOT apply ParleyFileReference highlight to @@ lines outside question blocks
+[32mSuccess[0m    ||    highlight_question_block: managed footnote footer uses a dedicated footnote highlight instead of open-question coloring
+[32mSuccess[0m    ||    decoration provider cache keeps highlight caches isolated per window for the same buffer
+[32mSuccess[0m    ||    decoration provider cache dims thinking-block continuation lines when viewport top falls between 🧠: and 🧠:[END]
+[32mSuccess[0m    ||    decoration provider cache dims streaming thinking-block continuation lines before 🧠:[END] is emitted
+[32mSuccess[0m    ||    decoration provider cache restores question highlights when redraw starts inside a long unanswered question
+[32mSuccess[0m    ||    timezone diagnostics publishes local-time diagnostics in its own namespace and clears stale diagnostics
+[32mSuccess[0m    ||    timezone diagnostics refreshes diagnostics for registered buffers on text changes
+[32mSuccess[0m    ||    markdown footnote diagnostics publishes persisted managed footnotes as Parley diagnostics
+[32mSuccess[0m    ||    markdown footnote diagnostics refreshes footnote diagnostics on markdown text changes without clearing other Parley diagnostics
+[32mSuccess[0m    ||    markdown footnote diagnostics renders managed footnote footers with ParleyFootnote in markdown buffers
+[32mSuccess[0m    ||    markdown chat reference rendering refreshes 🌿: branch lines with the chat topic in markdown buffers
+[32mSuccess[0m    ||    markdown chat reference rendering does not rewrite 🌿: lines pointing to non-chat files in markdown buffers
+[32mSuccess[0m    ||    markdown chat reference rendering refreshes from the updated topic in an open unsaved chat buffer
+
+[32mSuccess: [0m    20
+[31mFailed : [0m    0
+[31mErrors : [0m    0
+========================================
+]111
+exec
+/bin/zsh -lc 'rg -n -F "[''^" lua tests atlas README.md' in /Users/xianxu/workspace/parley.nvim
+exec
+/bin/zsh -lc 'rg -n "managed_footnote_footer_range|footnote_diagnostics|strip_definition_footnote_footer|ParleyFootnote|managed footer|footnote footer" lua tests atlas README.md' in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+lua/parley/define.lua:179:--- Locate the final managed definition-footnote footer.
+lua/parley/define.lua:182:function M.managed_footnote_footer_range(lines)
+lua/parley/define.lua:219:function M.footnote_diagnostics(lines)
+lua/parley/define.lua:290:--- Strip a final managed definition-footnote footer from text.
+lua/parley/define.lua:293:function M.strip_definition_footnote_footer(text)
+lua/parley/define.lua:345:--- definition in a managed footer.
+lua/parley/highlighter.lua:270:    local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
+lua/parley/highlighter.lua:303:            table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
+lua/parley/highlighter.lua:471:    local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
+lua/parley/highlighter.lua:478:            table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
+lua/parley/highlighter.lua:747:    -- Managed definition-footnote footer (`---` + `[^id]: ...`). It must be
+lua/parley/highlighter.lua:750:        vim.api.nvim_set_hl(0, "ParleyFootnote", user_highlights.footnote)
+lua/parley/highlighter.lua:752:        vim.api.nvim_set_hl(0, "ParleyFootnote", { link = "DiagnosticHint" })
+lua/parley/highlighter.lua:1098:            skill_render.refresh_footnote_diagnostics(buf)
+lua/parley/highlighter.lua:1111:            skill_render.refresh_footnote_diagnostics(buf)
+lua/parley/highlighter.lua:1133:            skill_render.refresh_footnote_diagnostics(buf)
+lua/parley/highlighter.lua:1138:            skill_render.refresh_footnote_diagnostics(buf)
+lua/parley/highlighter.lua:1149:            skill_render.refresh_footnote_diagnostics(buf)
+lua/parley/chat_respond.lua:378:                text = define.strip_definition_footnote_footer(text)
+lua/parley/chat_respond.lua:390:                local text = define.strip_definition_footnote_footer(read_block_text(k, b))
+lua/parley/chat_respond.lua:409:                    table.insert(answer_blocks, { type = "text", text = define.strip_definition_footnote_footer(text) })
+lua/parley/chat_respond.lua:427:                    table.insert(messages, { role = "user", content = define.strip_definition_footnote_footer(text) })
+lua/parley/chat_respond.lua:616:                copy.text = define.strip_definition_footnote_footer(copy.text)
+lua/parley/chat_respond.lua:702:                    local question_content = define.strip_definition_footnote_footer(exchange.question.content)
+lua/parley/chat_respond.lua:807:                        table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.answer.content) })
+lua/parley/chat_respond.lua:812:                        table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.summary.content) })
+lua/parley/chat_respond.lua:820:                            table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.answer.content) })
+lua/parley/config.lua:649:        footnote = nil, -- highlight for managed definition-footnote footer lines (default: links to DiagnosticHint)
+atlas/chat/inline_define.md:6:(`ASIN[^asin]`), while the definition is stored in a managed footnote footer at
+atlas/chat/inline_define.md:35:   and inserts/updates a final managed footnote footer via one buffer rewrite
+atlas/chat/inline_define.md:39:   footnote diagnostics (`skill_render.refresh_footnote_diagnostics`), which
+atlas/chat/inline_define.md:40:   parses the managed footer and sets INFO `vim.diagnostic` entries on matching
+atlas/chat/inline_define.md:68:  `strip_definition_footnote_footer` / `footnote_diagnostics` (treat the first
+atlas/chat/inline_define.md:69:  markdown footnote definition line as the managed footer boundary).
+atlas/chat/inline_define.md:89:`chat_respond.build_messages` strips this managed footer from message strings
+atlas/chat/inline_define.md:91:`define.footnote_diagnostics` uses the same footer detector to scan inline
+atlas/chat/inline_define.md:123:- `skill_render.refresh_footnote_diagnostics` owns only diagnostics tagged
+atlas/chat/inline_define.md:131:- `lua/parley/define.lua` — pure core (slice / context / format / footnote footer / diagnostics).
+atlas/chat/inline_define.md:135:- `lua/parley/chat_respond.lua` — strips managed footnote footer from LLM messages.
+lua/parley/skill_render.lua:114:function M.refresh_footnote_diagnostics(buf)
+lua/parley/skill_render.lua:132:    for _, footnote in ipairs(define.footnote_diagnostics(lines)) do
+lua/parley/skills/review/diag_display.lua:175:    local footnote_diagnostics = {}
+lua/parley/skills/review/diag_display.lua:179:                table.insert(footnote_diagnostics, diagnostic)
+lua/parley/skills/review/diag_display.lua:186:    table.sort(footnote_diagnostics, function(a, b)
+lua/parley/skills/review/diag_display.lua:189:    show_float(footnote_diagnostics)
+lua/parley/init.lua:1645:    skill_render.refresh_footnote_diagnostics(buf)
+tests/unit/parse_chat_spec.lua:667:    it("stops a final open question before a managed footnote footer", function()
+tests/unit/define_spec.lua:152:    it("adds an inline footnote reference and appends a managed footer", function()
+tests/unit/define_spec.lua:219:    it("strips only a final managed footnote footer", function()
+tests/unit/define_spec.lua:228:        assert.equals("answer text", define.strip_definition_footnote_footer(text))
+tests/unit/define_spec.lua:231:    it("preserves ordinary horizontal rules that are not managed footnote footers", function()
+tests/unit/define_spec.lua:240:        assert.equals(text, define.strip_definition_footnote_footer(text))
+tests/unit/define_spec.lua:243:    it("reports a dividerless managed footnote footer range from the first definition", function()
+tests/unit/define_spec.lua:244:        local range = define.managed_footnote_footer_range({
+tests/unit/define_spec.lua:253:    it("reports a divider-based managed footnote footer range from the first definition", function()
+tests/unit/define_spec.lua:254:        local range = define.managed_footnote_footer_range({
+tests/unit/define_spec.lua:265:    it("does not report ordinary horizontal rules as managed footnote footers", function()
+tests/unit/define_spec.lua:266:        local range = define.managed_footnote_footer_range({
+tests/unit/define_spec.lua:277:    it("keeps earlier horizontal-rule content and strips only the final managed footer", function()
+tests/unit/define_spec.lua:296:        }, "\n"), define.strip_definition_footnote_footer(text))
+tests/unit/define_spec.lua:299:    it("strips a final dividerless managed footnote footer", function()
+tests/unit/define_spec.lua:306:        assert.equals("answer text", define.strip_definition_footnote_footer(text))
+tests/unit/define_spec.lua:309:    it("extracts persisted footnote diagnostics from the managed footer", function()
+tests/unit/define_spec.lua:310:        local diagnostics = define.footnote_diagnostics({
+tests/unit/define_spec.lua:328:        local diagnostics = define.footnote_diagnostics({
+tests/unit/define_spec.lua:358:        local diagnostics = define.footnote_diagnostics({
+atlas/ui/highlights.md:4:Custom groups (`ParleyQuestion`, `ParleyFileReference`, `ParleyChatReference`, `ParleyThinking`, `ParleyAnnotation`, `ParleyReference`, `ParleyFootnote`, `ParleyPickerApproximateMatch`, `InterviewTimestamp`, `InterviewThought`) linked to standard Neovim groups. `ParleyReference` (default underline) marks drill-in `[referenced span]` brackets — see [chat/drill_in](../chat/drill_in.md). `ParleyFootnote` (default `DiagnosticHint`) marks managed definition-footnote footer lines.
+atlas/ui/highlights.md:9:- Managed definition-footnote footers (from the first `[^id]: ...` line) use
+atlas/ui/highlights.md:10:  `ParleyFootnote` in chat and markdown buffers instead of inheriting the active
+tests/unit/build_messages_spec.lua:708:    it("strips managed definition footnote footers from user and assistant content", function()
+tests/unit/build_messages_spec.lua:745:    it("preserves ordinary horizontal-rule content that is not a managed footer", function()
+tests/unit/build_messages_spec.lua:772:    it("keeps earlier horizontal-rule content and strips only the final managed footer", function()
+tests/unit/build_messages_spec.lua:1608:    it("strips managed footnote footers from live question and answer blocks", function()
+tests/integration/highlighting_spec.lua:165:describe("highlight_question_block: managed footnote footer", function()
+tests/integration/highlighting_spec.lua:176:        assert.is_true(has_highlight(buf, 3, "ParleyFootnote"),
+tests/integration/highlighting_spec.lua:177:            "Expected the managed footnote definition to use ParleyFootnote")
+tests/integration/highlighting_spec.lua:528:        skill_render.refresh_footnote_diagnostics(buf)
+tests/integration/highlighting_spec.lua:590:    it("renders managed footnote footers with ParleyFootnote in markdown buffers", function()
+tests/integration/highlighting_spec.lua:617:            if mark.hl_group == "ParleyFootnote" then
+tests/integration/highlighting_spec.lua:621:        assert.is_true(highlighted[2], "Expected markdown footnote definition to use ParleyFootnote")
+
+ succeeded in 0ms:
+lua/parley/define.lua:143:    id = id:gsub("[^%w]+", "-")
+lua/parley/define.lua:159:    return string.format("[^%s]: %s", id, definition)
+lua/parley/define.lua:167:    return trim(line):match("^%[%^[^%]]+%]:") ~= nil
+lua/parley/define.lua:192:    local id, definition = trim(line):match("^%[%^([^%]]+)%]:%s*(.-)%s*$")
+lua/parley/define.lua:239:            local ref_start, ref_end, id = line:find("%[%^([^%]]+)%]", search)
+lua/parley/define.lua:324:            local escaped_id = id:gsub("([^%w])", "%%%1")
+lua/parley/define.lua:356:    local ref = "[^" .. id .. "]"
+lua/parley/chat_slug.lua:30:    s = s:gsub("[^%a%d%s%-]", "")
+lua/parley/chat_slug.lua:42:    for word in s:gmatch("[^%-]+") do
+lua/parley/memory_prefs.lua:106:                for tag in tag_str:gmatch("[^,%s]+") do
+lua/parley/highlighter.lua:448:--   * footnote refs                 — `[^1]`
+lua/parley/highlighter.lua:527:            for s, content, e in line:gmatch("()%[([^%[%]]+)%]()") do
+lua/parley/highlighter.lua:747:    -- Managed definition-footnote footer (`---` + `[^id]: ...`). It must be
+atlas/modes/review.md:178:cursor is inside the term/`[^footnote]` diagnostic span.
+lua/parley/providers.lua:338:    for line in raw_response:gmatch("([^\n]+)") do
+lua/parley/providers.lua:356:        usage_json = raw_response:match('{"id":"[^"]*","object":"chat%.completion%.chunk"[^}]*"choices":%[%][^}]*"usage":{[^}]*}}')
+lua/parley/providers.lua:361:        for line in raw_response:gmatch("([^\n]+)") do
+lua/parley/providers.lua:607:    for line in raw_response:gmatch("[^\n]+") do
+lua/parley/providers.lua:631:        local usage_json = raw_response:match('("usage":%s*{[^{}]*})')
+lua/parley/providers.lua:691:    for line in raw_response:gmatch("[^\n]+") do
+lua/parley/providers.lua:895:    local uri = line:match('"uri"%s*:%s*"([^"]+)"') or line:match('\\"uri\\"%s*:%s*\\"([^"]+)\\"')
+lua/parley/providers.lua:926:    local usage_pattern = '"usageMetadata":%s*{[^}]*"promptTokenCount":%s*(%d+)[^}]*"candidatesTokenCount":%s*(%d+)[^}]*"totalTokenCount":%s*(%d+)[^}]*'
+lua/parley/providers.lua:936:        local escaped_pattern = '\\\"usageMetadata\\\":%s*{[^}]*\\\"promptTokenCount\\\":%s*(%d+)[^}]*\\\"candidatesTokenCount\\\":%s*(%d+)[^}]*\\\"totalTokenCount\\\":%s*(%d+)[^}]*'
+lua/parley/providers.lua:1186:    for line in raw_response:gmatch("([^\n]+)") do
+lua/parley/exporter.lua:13:    local slug = title:gsub("[^%w%s%-_]", ""):gsub("%s+", "_"):lower()
+lua/parley/exporter.lua:49:    return path:match("[^/]+$") or path
+lua/parley/exporter.lua:55:    return base:match("^(.+)%.[^%.]+$") or base
+lua/parley/exporter.lua:265:            local path, topic = rest:match("^%s*([^:]+)%s*:%s*(.-)%s*$")
+lua/parley/exporter.lua:352:    html = html:gsub("```([^\n]*)\n(.-)\n```", function(lang, code)
+lua/parley/exporter.lua:365:    html = html:gsub("`([^`\n]+)`", '<code class="inline-code">%1</code>')
+lua/parley/exporter.lua:368:    html = html:gsub("^# ([^\n]+)", '<h1 class="main-header">%1</h1>')
+lua/parley/exporter.lua:369:    html = html:gsub("\n# ([^\n]+)", '\n<h1 class="main-header">%1</h1>')
+lua/parley/exporter.lua:370:    html = html:gsub("^## ([^\n]+)", '<h2 class="section-header">%1</h2>')
+lua/parley/exporter.lua:371:    html = html:gsub("\n## ([^\n]+)", '\n<h2 class="section-header">%1</h2>')
+lua/parley/exporter.lua:372:    html = html:gsub("^### ([^\n]+)", '<h3 class="sub-header">%1</h3>')
+lua/parley/exporter.lua:373:    html = html:gsub("\n### ([^\n]+)", '\n<h3 class="sub-header">%1</h3>')
+lua/parley/exporter.lua:376:    html = html:gsub("%*%*([^%*\n]+)%*%*", '<strong class="bold-text">%1</strong>')
+lua/parley/exporter.lua:377:    html = html:gsub("__([^_\n]+)__", '<strong class="bold-text">%1</strong>')
+lua/parley/exporter.lua:378:    html = html:gsub("%*([^%*\n]+)%*", '<em class="italic-text">%1</em>')
+lua/parley/exporter.lua:379:    html = html:gsub("_([^_\n]+)_", '<em class="italic-text">%1</em>')
+lua/parley/exporter.lua:382:    html = html:gsub("\n%- ([^\n]+)", '\n<li class="list-item">%1</li>')
+lua/parley/exporter.lua:383:    html = html:gsub("(<li[^>]*>.-</li>)", '<ul class="bullet-list">%1</ul>')
+lua/parley/exporter.lua:386:    html = html:gsub("\n> ([^\n]+)", '\n<blockquote class="quote">%1</blockquote>')
+lua/parley/exporter.lua:393:    html = html:gsub("<p[^>]*>%s*<h", "<h")
+lua/parley/exporter.lua:395:    html = html:gsub("<p[^>]*>%s*<div", "<div")
+lua/parley/exporter.lua:397:    html = html:gsub("<p[^>]*>%s*<ul", "<ul")
+lua/parley/exporter.lua:399:    html = html:gsub("<p[^>]*>%s*<blockquote", "<blockquote")
+lua/parley/exporter.lua:401:    html = html:gsub("<p[^>]*>%s*</p>", "")
+lua/parley/exporter.lua:675:        body_html = body_html:gsub("<p[^>]*>%s*" .. key .. "%s*</p>", replacement)
+lua/parley/interview.lua:127:    local thought_id = vim.fn.matchadd("InterviewThought", "{[^}]\\+}", -1)
+lua/parley/render_buffer.lua:105:    for line in pretty:gmatch("[^\n]+") do
+lua/parley/log_emit.lua:68:    for line in (body .. "\n"):gmatch("([^\n]*)\n") do
+lua/parley/log_emit.lua:285:    return source:gsub("/[^/]+$", "") .. "/../../scripts/yaml_to_json.py"
+atlas/chat/inline_define.md:6:(`ASIN[^asin]`), while the definition is stored in a managed footnote footer at
+atlas/chat/inline_define.md:34:   in-flight call), then **(a)** adds a `[^id]` reference after the selected term
+atlas/chat/inline_define.md:41:   inline `term[^id]` spans (`define.format_definition` →
+atlas/chat/inline_define.md:83:[^asin]: Amazon Standard Identification Number.
+atlas/chat/inline_define.md:88:along with the footer, but the canonical boundary is the `[^id]: ...` line.
+atlas/chat/inline_define.md:92:references before the footer and produce diagnostics for each matching `[^id]`.
+atlas/chat/inline_define.md:121:- The fresh define highlight spans the selected text plus immediate `[^id]`
+lua/parley/artifact_ref.lua:96:    for ln in (stdout or ""):gmatch("[^\n]+") do
+lua/parley/oauth.lua:9:    { pattern = "docs%.google%.com/document/d/([^/&#]+)", file_type = "document" },
+lua/parley/oauth.lua:10:    { pattern = "docs%.google%.com/spreadsheets/d/([^/&#]+)", file_type = "spreadsheet" },
+lua/parley/oauth.lua:11:    { pattern = "docs%.google%.com/presentation/d/([^/&#]+)", file_type = "presentation" },
+lua/parley/oauth.lua:12:    { pattern = "drive%.google%.com/file/d/([^/&#]+)", file_type = "drive_file" },
+lua/parley/oauth.lua:16:    { pattern = "dropbox%.com/s/[^/?#]+/([^?#]+)", link_type = "file" },
+lua/parley/oauth.lua:17:    { pattern = "dropbox%.com/scl/fi/[^/?#]+/([^?#]+)", link_type = "file" },
+lua/parley/oauth.lua:18:    { pattern = "dropbox%.com/sh/[^/?#]+/([^?#]+)", link_type = "folder" },
+lua/parley/oauth.lua:19:    { pattern = "dropbox%.com/scl/fo/[^/?#]+/([^?#]+)", link_type = "folder" },
+lua/parley/oauth.lua:68:    local base, query = url:match("^([^?#]+)%??([^#]*)")
+lua/parley/oauth.lua:74:    for pair in query:gmatch("[^&]+") do
+lua/parley/oauth.lua:75:        local key = pair:match("^([^=]+)")
+lua/parley/oauth.lua:208:    str = str:gsub("([^%w%-%.%_%~])", function(c)
+lua/parley/oauth.lua:283:        local uri_port = explicit_uri:match("^https?://[^:/]+:(%d+)")
+lua/parley/oauth.lua:586:    local value = request_data:match("[?&]" .. key .. "=([^&%s]+)")
+lua/parley/oauth.lua:647:    source = tostring(source):gsub("[^%w]", "")
+lua/parley/oauth.lua:1201:    local name = without_fragment:match("/([^/?]+)[^/]*$") or without_fragment
+lua/parley/oauth.lua:1242:    sanitized = sanitized:gsub('("content_access_token"%s*:%s*)"[^"]+"', '%1"[REDACTED]"')
+lua/parley/oauth.lua:1243:    sanitized = sanitized:gsub('("access_token"%s*:%s*)"[^"]+"', '%1"[REDACTED]"')
+lua/parley/oauth.lua:1244:    sanitized = sanitized:gsub('("refresh_token"%s*:%s*)"[^"]+"', '%1"[REDACTED]"')
+lua/parley/notes.lua:63:    slug = slug:gsub("[^%w%-]", "-")
+lua/parley/notes.lua:136:    local folder, rest = subject:match("^%{([^{}%s/]+)%}%s+(.+)$")
+lua/parley/float_picker.lua:110:        local start_idx, end_idx = text:find("[%[%{][^%]%}]*[%]%}]", wrapped_search_from)
+lua/parley/vision.lua:63:    for item in inner:gmatch("[^,]+") do
+lua/parley/vision.lua:615:    id = id:gsub("[^%w%s%-]", "")  -- strip non-alphanumeric (except spaces and hyphens)
+lua/parley/vision.lua:708:            local ns, name_part = fid:match("^([^:]+):(.+)$")
+lua/parley/vision.lua:716:                local name_part = fid:match("^[^:]+:(.+)$")
+lua/parley/vision.lua:738:        local ns, name = ref:match("^([^:]+):%s*(.+)$")
+lua/parley/vision.lua:765:                local name_part = fid:match("^[^:]+:(.+)$")
+lua/parley/vision.lua:1045:        local name = f:match("([^/]+)$")
+lua/parley/vision.lua:1052:        local name = f:match("([^/]+)$")
+lua/parley/vision.lua:1074:            local name = entry:match("([^/]+)$")
+lua/parley/vision.lua:1314:            local color = #segments == 1 and segments[1]:match("^([^;]+)") or scheme.base
+lua/parley/vision.lua:1766:            for item in bracket_content:gmatch("[^,]+") do
+lua/parley/vision.lua:1977:    local partial_ns, partial_rest = partial:match("^([^:]+):%s*(.*)$")
+lua/parley/vision.lua:1979:        local word_ns = word:match("^([^:]+):")
+lua/parley/vision.lua:1981:        local word_name = word:match("^[^:]+:%s*(.+)$")
+lua/parley/keybinding_registry.lua:931:        for part in entry.config_key:gmatch("[^.]+") do
+lua/parley/tools/builtin/write_file.lua:50:        local dir = path:match("(.+)/[^/]+$")
+lua/parley/init.lua:2136:        vim.fn.matchadd("Conceal", [[^- model: .*model.:.[^"]*\zs".*\ze]], 10, -1, { conceal = "…" })
+lua/parley/init.lua:2137:        vim.fn.matchadd("Conceal", [[^- model: \zs.*model.:.\ze.*]], 10, -1, { conceal = "…" })
+lua/parley/init.lua:2138:        vim.fn.matchadd("Conceal", [[^- system_prompt: .\{64,64\}\zs.*\ze]], 10, -1, { conceal = "…" })
+lua/parley/init.lua:2139:        vim.fn.matchadd("Conceal", [[^- system_prompt: .[^\\]*\zs\\.*\ze]], 10, -1, { conceal = "…" })
+lua/parley/init.lua:2141:        vim.fn.matchadd("Conceal", [[^- role: .\{64,64\}\zs.*\ze]], 10, -1, { conceal = "…" })
+lua/parley/init.lua:2142:        vim.fn.matchadd("Conceal", [[^- role: .[^\\]*\zs\\.*\ze]], 10, -1, { conceal = "…" })
+lua/parley/init.lua:2708:    local path = rest:match("^([^:]+)") or rest
+lua/parley/init.lua:2713:    local topic = rest:match("^[^:]+:%s*(.+)$") or ""
+lua/parley/init.lua:2873:                    local ref_path, topic = rest:match("^%s*([^:]+)%s*:%s*(.-)%s*$")
+lua/parley/init.lua:3001:        ["{{filename}}"] = string.match(filename, "([^/]+)$"),
+lua/parley/init.lua:3762:        chat_path = current_line:match("^@@%s*([^@]+)@@")
+lua/parley/init.lua:3763:            or current_line:match("^@@%s*([^:]+):")
+lua/parley/init.lua:3814:            if full_line and full_line:match("@@[^:]+:%s*(.+)") then
+lua/parley/init.lua:3815:                topic = full_line:match("@@[^:]+:%s*(.+)")
+lua/parley/init.lua:3976:                if current_line:match("@@[^:]+:%s*(.+)") then
+lua/parley/init.lua:3977:                    topic = current_line:match("@@[^:]+:%s*(.+)")
+lua/parley/logger.lua:78:        raw = raw:gsub("([^\n]+)", "[SENSITIVE DATA] %1")
+lua/parley/tools/serialize.lua:132:    local header = text:match("^([^\n]*)") or ""
+lua/parley/tools/builtin/chat_history_search.lua:19:        local stable = version.stable_command_version(vim.fn.system("rg --version"):match("[^\n]+"), "ripgrep")
+lua/parley/tools/builtin/chat_history_search.lua:22:        local stable = version.stable_command_version(vim.fn.system("grep --version 2>&1"):match("[^\n]+"), "grep")
+lua/parley/tools/builtin/chat_history_search.lua:69:    for line in (output .. "\n"):gmatch("([^\n]*)\n") do
+tests/integration/define_spec.lua:253:        assert.are.equal("here is ASIN[^asin] in context",
+tests/integration/define_spec.lua:258:            "[^asin]: Amazon Standard Identification Number.",
+tests/integration/define_spec.lua:265:        assert.are.equal(19, diags[1].end_col) -- ASIN plus [^asin]
+tests/integration/define_spec.lua:267:        -- DiffChange highlight covers only ASIN[^asin], not the whole paragraph.
+tests/integration/define_spec.lua:315:            return vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1] == "here is ASIN[^asin] in context"
+tests/integration/define_spec.lua:333:        assert.are.equal("here is ASIN[^asin] in context",
+tests/integration/define_spec.lua:338:            "[^asin]: Updated definition.",
+tests/integration/define_spec.lua:349:        assert.are.equal("here is ASIN[^asin] in context",
+tests/integration/define_spec.lua:369:        assert.are.equal("here is ASIN[^asin] in context",
+lua/parley/tools/builtin/ls.lua:12:            local version = vim.fn.system("ls --version 2>&1"):match("[^\n]+") or "ls"
+lua/parley/tools/builtin/edit_file.lua:85:            for line in (content .. "\n"):gmatch("([^\n]*)\n") do
+lua/parley/tools/builtin/edit_file.lua:99:            for line in (text .. "\n"):gmatch("([^\n]*)\n") do
+tests/integration/review_diag_display_spec.lua:62:            string.rep("x", 120) .. " ACOS[^acos]",
+tests/integration/review_diag_display_spec.lua:111:            'before ACOS[^acos] after the anchor on the same line',
+lua/parley/tools/builtin/grep.lua:12:        local stable = version.stable_command_version(vim.fn.system("rg --version"):match("[^\n]+"), "ripgrep")
+lua/parley/tools/builtin/grep.lua:15:        local stable = version.stable_command_version(vim.fn.system("grep --version 2>&1"):match("[^\n]+"), "grep")
+lua/parley/tools/builtin/find.lua:13:            local version = vim.fn.system("find --version 2>&1"):match("[^\n]+") or "find"
+lua/parley/tools/builtin/ack.lua:21:        local version = vim.fn.system({ "ack", "--version" }):match("[^\n]+") or "ack"
+lua/parley/discovery/matcher.lua:40:        local basename = path:match("([^/]+)$") or path
+lua/parley/chat_parser.lua:33:    return (line or ""):match("^%[%^[^%]]+%]:") ~= nil
+lua/parley/chat_parser.lua:226:                    for tag in value:gmatch("[^,%s]+") do
+lua/parley/chat_parser.lua:238:                for tag in value:gmatch("[^,%s]+") do
+lua/parley/chat_parser.lua:526:        for ref in text:gmatch("@@([^@]+)@@") do
+lua/parley/chat_parser.lua:548:            local path, topic = rest:match("^%s*([^:]+)%s*:%s*(.-)%s*$")
+lua/parley/dispatcher.lua:241:                local last_newline_pos = buffer:find("\n[^\n]*$")
+lua/parley/dispatcher.lua:267:                qt.stop_reason = raw_response:match('"stop_reason"%s*:%s*"([^"]+)"')
+lua/parley/dispatcher.lua:268:                    or raw_response:match('"finish_reason"%s*:%s*"([^"]+)"')
+lua/parley/discovery/registry.lua:134:    local boundary = glob:sub(1, wc - 1):find("/[^/]*$")
+lua/parley/discovery/local_types.lua:60:    for line in (out or ""):gmatch("[^\n]+") do
+lua/parley/skills/review/mode.lua:45:    for line in fm:gmatch("[^\n]+") do
+lua/parley/issues.lua:56:    slug = slug:gsub("[^%w%-]", "-")
+lua/parley/issues.lua:76:    for dep in value:gmatch("[^,]+") do
+lua/parley/issues.lua:255:        local s, e, text, url = line:find("%[([^%]]*)%]%(([^)]+)%)", init)
+lua/parley/issues.lua:321:    return stripped:match("([^/]+)$") or stripped
+lua/parley/issues.lua:340:    for line in (output or ""):gmatch("[^\r\n]+") do
+tests/integration/highlighting_spec.lua:173:            "[^asin]: Amazon Standard Identification Number.",
+tests/integration/highlighting_spec.lua:523:            "here is ASIN[^asin] in context",
+tests/integration/highlighting_spec.lua:525:            "[^asin]: Amazon Standard Identification Number.",
+tests/integration/highlighting_spec.lua:564:            "here is ASIN[^asin] in context",
+tests/integration/highlighting_spec.lua:566:            "[^asin]: Amazon Standard Identification Number.",
+tests/integration/highlighting_spec.lua:594:            "here is ASIN[^asin] in context",
+tests/integration/highlighting_spec.lua:596:            "[^asin]: Amazon Standard Identification Number.",
+lua/parley/cliproxy_config.lua:24:    local host, port = endpoint:match("^https?://([^:/]+):(%d+)")
+lua/parley/cliproxy_config.lua:28:    local scheme, h = endpoint:match("^(https?)://([^:/]+)")
+lua/parley/cliproxy_config.lua:232:    for line in (text or ""):gmatch("[^\n]+") do
+atlas/ui/highlights.md:9:- Managed definition-footnote footers (from the first `[^id]: ...` line) use
+tests/unit/highlighter_spec.lua:9:    local s, content, e = line:match("()%[([^%[%]]+)%]()")
+tests/unit/highlighter_spec.lua:28:        assert.is_false(first_span_is_reference("a claim [^1] needs backing"))
+tests/unit/parse_chat_spec.lua:673:            "[^acos]: ACOS (Advertising Cost of Sales).",
+tests/unit/parse_chat_spec.lua:689:            "[^acos]: ACOS (Advertising Cost of Sales).",
+tests/unit/skill_render_spec.lua:117:        local buf = scratch({ "here is ASIN[^asin] in context" })
+tests/unit/chat_parser_tools_spec.lua:111:        for l in tool_use_block:gmatch("[^\n]+") do
+tests/unit/chat_parser_tools_spec.lua:146:        for l in tool_use_block:gmatch("[^\n]+") do table.insert(lines, l) end
+tests/unit/chat_parser_tools_spec.lua:147:        for l in tool_result_block:gmatch("[^\n]+") do table.insert(lines, l) end
+tests/unit/chat_parser_tools_spec.lua:182:            for l in tu:gmatch("[^\n]+") do table.insert(lines, l) end
+tests/unit/chat_parser_tools_spec.lua:183:            for l in tr:gmatch("[^\n]+") do table.insert(lines, l) end
+tests/unit/chat_parser_tools_spec.lua:215:        for l in tool_use_block:gmatch("[^\n]+") do table.insert(lines, l) end
+tests/unit/chat_parser_tools_spec.lua:216:        for l in tool_result_block:gmatch("[^\n]+") do table.insert(lines, l) end
+tests/unit/chat_parser_tools_spec.lua:237:        for l in tu1:gmatch("[^\n]+") do table.insert(lines, l) end
+tests/unit/chat_parser_tools_spec.lua:238:        for l in tr1:gmatch("[^\n]+") do table.insert(lines, l) end
+tests/unit/define_spec.lua:161:            "here is ASIN[^asin] in context",
+tests/unit/define_spec.lua:165:            "[^asin]: Amazon Standard Identification Number.",
+tests/unit/define_spec.lua:179:                "[^asin]: old definition",
+tests/unit/define_spec.lua:187:            "ASIN[^asin] is here",
+tests/unit/define_spec.lua:191:            "[^asin]: Amazon Standard Identification Number.",
+tests/unit/define_spec.lua:198:                "ASIN[^asin] is here",
+tests/unit/define_spec.lua:202:                "[^asin]: old definition",
+tests/unit/define_spec.lua:210:            "ASIN[^asin] is here",
+tests/unit/define_spec.lua:214:            "[^asin]: Updated definition.",
+tests/unit/define_spec.lua:225:            "[^asin]: Amazon Standard Identification Number.",
+tests/unit/define_spec.lua:247:            "[^asin]: Amazon Standard Identification Number.",
+tests/unit/define_spec.lua:259:            "[^asin]: Amazon Standard Identification Number.",
+tests/unit/define_spec.lua:287:            "[^asin]: Amazon Standard Identification Number.",
+tests/unit/define_spec.lua:303:            "[^asin]: Amazon Standard Identification Number.",
+tests/unit/define_spec.lua:311:            "here is ASIN[^asin] in context",
+tests/unit/define_spec.lua:313:            "[^asin]: Amazon Standard Identification Number.",
+tests/unit/define_spec.lua:329:            "ASIN[^asin] first, then SKU[^asin] second",
+tests/unit/define_spec.lua:333:            "[^asin]: Amazon Standard Identification Number.",
+tests/unit/define_spec.lua:359:            "ASIN[^asin] in body",
+tests/unit/define_spec.lua:361:            "[^asin]: Amazon Standard Identification Number.",
+tests/unit/build_messages_spec.lua:714:            "[^asin]: Amazon Standard Identification Number.",
+tests/unit/build_messages_spec.lua:721:            "[^asin]: Amazon Standard Identification Number.",
+tests/unit/build_messages_spec.lua:782:            "[^asin]: Amazon Standard Identification Number.",
+tests/unit/build_messages_spec.lua:1614:            "[^asin]: Amazon Standard Identification Number.",
+tests/unit/build_messages_spec.lua:1621:            "[^asin]: Amazon Standard Identification Number.",
+tests/unit/dispatcher_query_spec.lua:246:            for line in fixture_content:gmatch("[^\n]+") do
+
+exec
+/bin/zsh -lc "rg -n \"managed_footnote_footer_range|footnote_diagnostics|ParleyFootnote\" lua/parley tests -g '*.lua'" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+lua/parley/define.lua:182:function M.managed_footnote_footer_range(lines)
+lua/parley/define.lua:219:function M.footnote_diagnostics(lines)
+lua/parley/highlighter.lua:270:    local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
+lua/parley/highlighter.lua:303:            table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
+lua/parley/highlighter.lua:471:    local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
+lua/parley/highlighter.lua:478:            table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
+lua/parley/highlighter.lua:750:        vim.api.nvim_set_hl(0, "ParleyFootnote", user_highlights.footnote)
+lua/parley/highlighter.lua:752:        vim.api.nvim_set_hl(0, "ParleyFootnote", { link = "DiagnosticHint" })
+lua/parley/highlighter.lua:1098:            skill_render.refresh_footnote_diagnostics(buf)
+lua/parley/highlighter.lua:1111:            skill_render.refresh_footnote_diagnostics(buf)
+lua/parley/highlighter.lua:1133:            skill_render.refresh_footnote_diagnostics(buf)
+lua/parley/highlighter.lua:1138:            skill_render.refresh_footnote_diagnostics(buf)
+lua/parley/highlighter.lua:1149:            skill_render.refresh_footnote_diagnostics(buf)
+tests/integration/highlighting_spec.lua:176:        assert.is_true(has_highlight(buf, 3, "ParleyFootnote"),
+tests/integration/highlighting_spec.lua:177:            "Expected the managed footnote definition to use ParleyFootnote")
+tests/integration/highlighting_spec.lua:528:        skill_render.refresh_footnote_diagnostics(buf)
+tests/integration/highlighting_spec.lua:590:    it("renders managed footnote footers with ParleyFootnote in markdown buffers", function()
+tests/integration/highlighting_spec.lua:617:            if mark.hl_group == "ParleyFootnote" then
+tests/integration/highlighting_spec.lua:621:        assert.is_true(highlighted[2], "Expected markdown footnote definition to use ParleyFootnote")
+lua/parley/skills/review/diag_display.lua:175:    local footnote_diagnostics = {}
+lua/parley/skills/review/diag_display.lua:179:                table.insert(footnote_diagnostics, diagnostic)
+lua/parley/skills/review/diag_display.lua:186:    table.sort(footnote_diagnostics, function(a, b)
+lua/parley/skills/review/diag_display.lua:189:    show_float(footnote_diagnostics)
+lua/parley/skill_render.lua:114:function M.refresh_footnote_diagnostics(buf)
+lua/parley/skill_render.lua:132:    for _, footnote in ipairs(define.footnote_diagnostics(lines)) do
+tests/unit/define_spec.lua:244:        local range = define.managed_footnote_footer_range({
+tests/unit/define_spec.lua:254:        local range = define.managed_footnote_footer_range({
+tests/unit/define_spec.lua:266:        local range = define.managed_footnote_footer_range({
+tests/unit/define_spec.lua:310:        local diagnostics = define.footnote_diagnostics({
+tests/unit/define_spec.lua:328:        local diagnostics = define.footnote_diagnostics({
+tests/unit/define_spec.lua:358:        local diagnostics = define.footnote_diagnostics({
+lua/parley/init.lua:1645:    skill_render.refresh_footnote_diagnostics(buf)
+
+codex
+One additional consumer surfaced during grep: `chat_parser.lua` has its own footnote-line predicate for exchange parsing. I’m checking whether that creates a shadow implementation problem or remains outside this issue’s consumer set.
+exec
+/bin/zsh -lc "nl -ba lua/parley/chat_parser.lua | sed -n '1,80p;460,620p'" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+     1    --------------------------------------------------------------------------------
+     2    -- chat_parser.lua: parses a chat file's lines into a structured representation.
+     3    --
+     4    -- Extracted from init.lua so it can be required and tested independently,
+     5    -- without loading the full parley plugin or calling setup().
+     6    --
+     7    -- Public API:
+     8    --   M.parse_chat(lines, header_end, config) -> parsed_chat
+     9    --
+    10    -- `config` must contain:
+    11    --   config.chat_user_prefix        (string)
+    12    --   config.chat_local_prefix       (string)
+    13    --   config.chat_assistant_prefix   (string | {string, ...})
+    14    --   config.chat_memory             (table | nil)
+    15    --     .enable                      (boolean)
+    16    --     .summary_prefix              (string)
+    17    --     .reasoning_prefix            (string)
+    18    --------------------------------------------------------------------------------
+    19
+    20    local logger = require("parley.logger")
+    21
+    22    local M = {}
+    23
+    24    local function trim(str)
+    25        return (str:gsub("^%s*(.-)%s*$", "%1"))
+    26    end
+    27
+    28    local function is_divider(line)
+    29        return trim(line or "") == "---"
+    30    end
+    31
+    32    local function is_footnote_definition(line)
+    33        return (line or ""):match("^%[%^[^%]]+%]:") ~= nil
+    34    end
+    35
+    36    ---Find the header/trancript separator index.
+    37    ---Supports:
+    38    ---1) Legacy format: metadata lines followed by a single `---`.
+    39    ---2) Front matter format: opening `---`, metadata, closing `---`.
+    40    ---@param lines table
+    41    ---@return number|nil
+    42    M.find_header_end = function(lines)
+    43        if not lines or #lines == 0 then
+    44            return nil
+    45        end
+    46
+    47        if trim(lines[1]) == "---" then
+    48            for i = 2, #lines do
+    49                if trim(lines[i]) == "---" then
+    50                    return i
+    51                end
+    52            end
+    53            return nil
+    54        end
+    55
+    56        for i, line in ipairs(lines) do
+    57            if trim(line) == "---" then
+    58                return i
+    59            end
+    60        end
+    61
+    62        return nil
+    63    end
+    64
+    65    local function parse_header_key_value(line)
+    66        local content = trim(line)
+    67        if content == "" or content == "---" then
+    68            return nil, nil
+    69        end
+    70
+    71        local key, value = content:match("^[-#]%s*([%w_%.%+]+):%s*(.*)$")
+    72        if key then
+    73            return key, value
+    74        end
+    75
+    76        return content:match("^([%w_%.%+]+):%s*(.*)$")
+    77    end
+    78
+    79    local function parse_header_config_value(value)
+    80        if tonumber(value) ~= nil then
+   460            cb_state.current_line_start = nil
+   461            cb_state.tool_fence_len = nil
+   462            cb_state.tool_body_complete = false
+   463        end
+   464
+   465        -- Append a line to the current content block, auto-transitioning
+   466        -- out of a tool block whose fenced body has already been closed.
+   467        -- Tracks fence open/close state inside tool blocks so the parser
+   468        -- knows when subsequent text should start a new text block vs
+   469        -- belong to the tool block's body.
+   470        -- line_no is the 1-indexed buffer line being appended (#90 Task 1.1).
+   471        local function cb_append_line(line, line_no)
+   472            if not cb_state or not cb_state.current_kind then return end
+   473
+   474            -- Auto-transition: if we're in a tool block whose closing
+   475            -- fence was already seen, this line belongs to a NEW text
+   476            -- block, not the tool block. Finalize the tool block first.
+   477            if cb_state.tool_body_complete then
+   478                cb_finalize_block(line_no - 1)
+   479                cb_start_block("text")
+   480            end
+   481
+   482            -- Lazy line_start: the first line we see is where the block begins.
+   483            if cb_state.current_line_start == nil then
+   484                cb_state.current_line_start = line_no
+   485            end
+   486            table.insert(cb_state.current_lines, line)
+   487
+   488            -- Track fence state inside tool blocks to detect body end.
+   489            -- Opening fence: any run of 3+ backticks optionally followed
+   490            -- by an info string (e.g. "```json"). Closing fence: exactly
+   491            -- the same number of bare backticks with no info string.
+   492            if cb_state.current_kind == "tool_use" or cb_state.current_kind == "tool_result" then
+   493                if not cb_state.tool_fence_len then
+   494                    local fence = line:match("^(`+)[%w_%-]*%s*$")
+   495                    if fence and #fence >= 3 then
+   496                        cb_state.tool_fence_len = #fence
+   497                    end
+   498                else
+   499                    local expected_close = string.rep("`", cb_state.tool_fence_len)
+   500                    if line == expected_close then
+   501                        cb_state.tool_body_complete = true
+   502                    end
+   503                end
+   504            end
+   505        end
+   506
+   507        -- Attach accumulated blocks to the current exchange's answer
+   508        -- component (called on answer → next-question transition and at
+   509        -- end of file). end_line_no is the last buffer line of the answer
+   510        -- region (#90 Task 1.1).
+   511        local function cb_attach_to_current_answer(end_line_no)
+   512            if cb_state and current_exchange and current_exchange.answer then
+   513                cb_finalize_block(end_line_no)
+   514                current_exchange.answer.sections = cb_state.blocks
+   515                -- Backward-compat alias.
+   516                current_exchange.answer.content_blocks = cb_state.blocks
+   517            end
+   518            cb_state = nil
+   519        end
+   520
+   521        -- Helper to extract @@ref@@ file references from a line of text.
+   522        -- Canonical form: @@<ref>@@ where ref starts with https://, /, ~/, ./, or ../
+   523        local function extract_file_refs(text)
+   524            local refs = {}
+   525            local seen = {}
+   526            for ref in text:gmatch("@@([^@]+)@@") do
+   527                ref = ref:gsub("^%s*(.-)%s*$", "%1")
+   528                if ref:match("^https?://") or ref:match("^/") or ref:match("^~/") or ref:match("^%./") or ref:match("^%.%./") then
+   529                    if not seen[ref] then
+   530                        seen[ref] = true
+   531                        table.insert(refs, ref)
+   532                    end
+   533                end
+   534            end
+   535            return refs
+   536        end
+   537
+   538        -- Loop through content lines
+   539        for i = header_end + 1, #lines do
+   540            local line = lines[i]
+   541
+   542            -- Check for branch reference (🌿:) — always detected, even between consecutive links.
+   543            -- Before the first question: first 🌿: is parent_link, subsequent ones are children.
+   544            -- After the first question: all 🌿: are child branches.
+   545            if line:sub(1, #branch_prefix) == branch_prefix then
+   546                in_reasoning_block = false
+   547                local rest = line:sub(#branch_prefix + 1):gsub("^%s*(.-)%s*$", "%1")
+   548                local path, topic = rest:match("^%s*([^:]+)%s*:%s*(.-)%s*$")
+   549                if not path then
+   550                    path = rest
+   551                    topic = ""
+   552                end
+   553                path = path:gsub("^%s*(.-)%s*$", "%1")
+   554                topic = (topic or ""):gsub("^%s*(.-)%s*$", "%1")
+   555                local branch_info = { path = path, topic = topic, line = i, after_exchange = #result.exchanges }
+   556                if not first_question_seen and not result.parent_link then
+   557                    result.parent_link = branch_info
+   558                else
+   559                    table.insert(result.branches, branch_info)
+   560                end
+   561                line_before_local = i
+   562
+   563            -- Check for local section (excluded from LLM context)
+   564            elseif (not line_before_local) and line:sub(1, #local_prefix) == local_prefix then
+   565                in_reasoning_block = false
+   566                line_before_local = i
+   567
+   568            -- Check for user message start
+   569            elseif line:sub(1, #user_prefix) == user_prefix then
+   570                in_reasoning_block = false
+   571                first_question_seen = true
+   572                -- Content_blocks for the closing answer (if any) get attached
+   573                -- before we finalize the old component and start a new exchange.
+   574                local current_component_start = line_before_local or i
+   575                cb_attach_to_current_answer(current_component_start - 1)
+   576                -- If we were building a previous exchange, finalize it
+   577                finalize_component(current_component_start - 1)
+   578
+   579                -- Extract question content
+   580                local question_content = line:sub(#user_prefix + 1)
+   581
+   582                -- Detect inline branch links on the question prefix line
+   583                local q_inline = M.extract_inline_branch_links(question_content, branch_prefix)
+   584                if #q_inline > 0 then
+   585                    question_content = M.unpack_inline_branch_links(question_content, branch_prefix)
+   586                end
+   587
+   588                -- Start a new exchange
+   589                current_exchange = {
+   590                    question = {
+   591                        line_start = i,
+   592                        line_end = nil,
+   593                        content = "",
+   594                        file_references = {} -- Will store file references we find (length > 0 means has references)
+   595                    },
+   596                    answer = nil
+   597                }
+   598                content_parts = { question_content }
+   599                table.insert(result.exchanges, current_exchange)
+   600                current_component = "question"
+   601                line_before_local = nil
+   602
+   603                -- Add inline branch links from the question prefix line
+   604                for _, ib in ipairs(q_inline) do
+   605                    table.insert(result.branches, {
+   606                        path = ib.path,
+   607                        topic = ib.topic,
+   608                        line = i,
+   609                        after_exchange = #result.exchanges,
+   610                        inline = true,
+   611                    })
+   612                end
+   613
+   614                -- Check for inline @@ file references on the user prefix line itself
+   615                local inline_refs = extract_file_refs(question_content)
+   616                for _, ref_path in ipairs(inline_refs) do
+   617                    table.insert(current_exchange.question.file_references, {
+   618                        line = line,
+   619                        path = ref_path,
+   620                        original_line_index = i,
+
+exec
+/bin/zsh -lc "nl -ba tests/unit/parse_chat_spec.lua | sed -n '640,705p'" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+   640            local result = parse_chat(lines, header_end)
+   641            local refs = result.exchanges[1].question.file_references
+   642            assert.equals(1, #refs)
+   643            assert.equals("~/config.lua", refs[1].path)
+   644        end)
+   645
+   646        it("does not collect unclosed @@ reference (no closing @@)", function()
+   647            local lines, header_end = make_chat(std_header, {
+   648                "💬: Review @@/path/to/file.lua please",
+   649            })
+   650            local result = parse_chat(lines, header_end)
+   651            local refs = result.exchanges[1].question.file_references
+   652            assert.equals(0, #refs)
+   653        end)
+   654
+   655        it("collects two inline @@ref@@ on same line", function()
+   656            local lines, header_end = make_chat(std_header, {
+   657                "💬: Compare @@/file/a.lua@@ and @@/file/b.lua@@",
+   658            })
+   659            local result = parse_chat(lines, header_end)
+   660            local refs = result.exchanges[1].question.file_references
+   661            assert.equals(2, #refs)
+   662        end)
+   663    end)
+   664
+   665
+   666    describe("parse_chat: edge cases", function()
+   667        it("stops a final open question before a managed footnote footer", function()
+   668            local lines, header_end = make_chat(std_header, {
+   669                "💬: tell me about the EVAL framework",
+   670                "",
+   671                "---",
+   672                "",
+   673                "[^acos]: ACOS (Advertising Cost of Sales).",
+   674            })
+   675            local result = parse_chat(lines, header_end)
+   676
+   677            assert.equals("tell me about the EVAL framework", result.exchanges[1].question.content)
+   678            assert.equals(7, result.exchanges[1].question.line_start)
+   679            assert.equals(7, result.exchanges[1].question.line_end)
+   680        end)
+   681
+   682        it("positions a final open-question answer above managed footnotes", function()
+   683            local exchange_model = require("parley.exchange_model")
+   684            local lines, header_end = make_chat(std_header, {
+   685                "💬: tell me about the EVAL framework",
+   686                "",
+   687                "---",
+   688                "",
+   689                "[^acos]: ACOS (Advertising Cost of Sales).",
+   690            })
+   691            local parsed = parse_chat(lines, header_end)
+   692            local model = exchange_model.from_parsed_chat(parsed)
+   693
+   694            model:add_block(1, "agent_header", 1)
+   695            local agent_header_start = model:block_start(1, 2)
+   696
+   697            assert.equals(8, agent_header_start)
+   698            assert.equals("---", lines[agent_header_start + 1])
+   699        end)
+   700
+   701        it("handles assistant message with no preceding user message", function()
+   702            local lines, header_end = make_chat(std_header, {
+   703                "🤖:[Claude] Unprompted response",
+   704            })
+   705            -- Should not crash; an exchange is created with empty question
+
+exec
+/bin/zsh -lc "nl -ba lua/parley/highlighter.lua | sed -n '245,315p;450,485p;738,755p'" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+   245                if ok and bounds then
+   246                    local start_line = math.max(1, (bounds.top or 1) - margin)
+   247                    local end_line = math.min(line_count, (bounds.bottom or line_count) + margin)
+   248                    if start_line <= end_line then
+   249                        table.insert(ranges, { start_line = start_line, end_line = end_line })
+   250                    end
+   251                end
+   252            end
+   253        end
+   254
+   255        if #ranges == 0 and line_count > 0 then
+   256            table.insert(ranges, { start_line = 1, end_line = line_count })
+   257        end
+   258
+   259        return merge_line_ranges(ranges)
+   260    end
+   261
+   262    -- Compute desired chat highlights for a 1-indexed line range.
+   263    -- Returns a table keyed by 0-indexed row: { [row] = { {hl_group, col_start, col_end}, ... } }
+   264    -- Scans HIGHLIGHT_CONTEXT_LINES above start_line for block state context.
+   265    local function compute_chat_highlights(buf, start_line, end_line)
+   266        local result = {}
+   267        local patterns = get_chat_highlight_prefix_patterns()
+   268        local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)
+   269        local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
+   270        local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
+   271        -- While a stream is in flight for this buffer, the model has not
+   272        -- yet emitted 🧠:[END]. Assume explicit-end mode so blank-line
+   273        -- paragraph breaks inside the in-progress thinking region keep
+   274        -- their dim highlight instead of prematurely terminating the
+   275        -- block. After the stream completes (is_busy → false), the
+   276        -- lookahead-decided mode takes over and a real [END] / structural
+   277        -- marker controls termination.
+   278        local streaming = require("parley.tasker").is_busy(buf, true)
+   279        local in_block, in_code_block, in_reasoning_block, in_reasoning_explicit_end =
+   280            bootstrap_chat_highlight_state(buf, start_line, patterns, streaming)
+   281
+   282        local in_tool_block = false  -- inside 🔧:/📎: fenced content
+   283
+   284        for offset, line in ipairs(lines) do
+   285            local line_nr = start_line + offset - 1
+   286            if line:match("^%s*```") then
+   287                in_code_block = not in_code_block
+   288                -- Exiting a code block while in a tool region ends the tool region
+   289                if not in_code_block and in_tool_block then
+   290                    in_tool_block = false
+   291                end
+   292            end
+   293
+   294            local highlighted_regions = {}
+   295            local row = line_nr - 1
+   296
+   297            result[row] = result[row] or {}
+   298
+   299            push_artifact_refs(result, row, line) -- #160: navigable artifact refs
+   300
+   301            local is_footer = footer_range and line_nr >= footer_range.start_line and line_nr <= footer_range.end_line
+   302            if is_footer then
+   303                table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
+   304                in_block = false
+   305            else
+   306                local pos = 1
+   307                while true do
+   308                    local tag_start, content_start = line:find("@@", pos)
+   309                    if not tag_start then break end
+   310                    local content_end, tag_end = line:find("@@", content_start + 1)
+   311                    if not content_end then break end
+   312                    table.insert(highlighted_regions, { start = tag_start, finish = tag_end })
+   313                    table.insert(result[row], { hl_group = "ParleyTag", col_start = tag_start - 1, col_end = tag_end })
+   314                    pos = tag_end + 1
+   315                end
+   450    --   * a *live* 🤖 marker's section   — `[U]` chained after 🤖 / `>` / `~` / a
+   451    --                                     prior `]`/`}` close (already highlighted
+   452    --                                     ParleyReviewUser; don't double-mark it).
+   453    -- A flattened reference span's `[` follows ordinary prose, so it passes.
+   454    function M.is_reference_span(line, s, content, e)
+   455        if line:sub(e, e) == "(" then return false end
+   456        if content:sub(1, 1) == "^" then return false end
+   457        if #content < 2 then return false end
+   458        local prev = line:sub(s - 1, s - 1)
+   459        if prev == "]" or prev == "}" or prev == ">" or prev == "~" then return false end
+   460        if s > 4 and line:sub(s - 4, s - 1) == "🤖" then return false end
+   461        return true
+   462    end
+   463
+   464    -- Compute desired markdown highlights for a 1-indexed line range.
+   465    -- Returns a table keyed by 0-indexed row: { [row] = { {hl_group, col_start, col_end}, ... } }
+   466    local function compute_markdown_highlights(buf, start_line, end_line)
+   467        local result = {}
+   468        local branch_prefix = _parley.config.chat_branch_prefix or "🌿:"
+   469        local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)
+   470        local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
+   471        local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
+   472        for offset, line in ipairs(lines) do
+   473            local row = start_line + offset - 2
+   474            local line_nr = row + 1
+   475            push_artifact_refs(result, row, line) -- #160: navigable artifact refs
+   476            if footer_range and line_nr >= footer_range.start_line and line_nr <= footer_range.end_line then
+   477                result[row] = result[row] or {}
+   478                table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
+   479            end
+   480            if line:sub(1, #branch_prefix) == branch_prefix then
+   481                result[row] = result[row] or {}
+   482                table.insert(result[row], { hl_group = "ParleyChatReference", col_start = 0, col_end = -1 })
+   483            end
+   484            -- Highlight 🤖<...>[...]{...} review markers
+   485            local review = require("parley.review")
+   738        -- text a gathered comment points at. Underline reads as "this span is
+   739        -- marked" without the weight of a full background. Override via
+   740        -- config.highlight.reference.
+   741        if user_highlights.reference then
+   742            vim.api.nvim_set_hl(0, "ParleyReference", user_highlights.reference)
+   743        else
+   744            vim.api.nvim_set_hl(0, "ParleyReference", { underline = true })
+   745        end
+   746
+   747        -- Managed definition-footnote footer (`---` + `[^id]: ...`). It must be
+   748        -- independent of the surrounding chat exchange color.
+   749        if user_highlights.footnote then
+   750            vim.api.nvim_set_hl(0, "ParleyFootnote", user_highlights.footnote)
+   751        else
+   752            vim.api.nvim_set_hl(0, "ParleyFootnote", { link = "DiagnosticHint" })
+   753        end
+   754
+   755        -- Artifact refs (ariadne#11, #15 M4, pair#84) left navigable by #160.
+
+exec
+/bin/zsh -lc "nl -ba tests/unit/build_messages_spec.lua | sed -n '700,790p;1595,1630p'" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+   700            assert.equals(5, #messages)
+   701            assert.equals("Answer 1", messages[3].content)
+   702            assert.equals("Question 2", messages[4].content)
+   703            assert.equals("Question 3", messages[5].content)
+   704        end)
+   705    end)
+   706
+   707    describe("_build_messages: durable definition footnotes", function()
+   708        it("strips managed definition footnote footers from user and assistant content", function()
+   709            local question = table.concat({
+   710                "What is ASIN?",
+   711                "",
+   712                "---",
+   713                "",
+   714                "[^asin]: Amazon Standard Identification Number.",
+   715            }, "\n")
+   716            local answer = table.concat({
+   717                "ASIN is an identifier.",
+   718                "",
+   719                "---",
+   720                "",
+   721                "[^asin]: Amazon Standard Identification Number.",
+   722            }, "\n")
+   723            local pc = parsed_chat({ exchange(question, answer), exchange("Next") })
+   724            pc.exchanges[1].question.line_start = 10
+   725            pc.exchanges[1].answer.line_start = 12
+   726            pc.exchanges[2].question.line_start = 20
+   727
+   728            local messages = parley._build_messages({
+   729                parsed_chat = pc,
+   730                start_index = 1,
+   731                end_index = 100,
+   732                exchange_idx = 2,
+   733                agent = agent(),
+   734                config = parley.config,
+   735                helpers = stub_helpers,
+   736                logger = stub_logger
+   737            })
+   738
+   739            assert.equals("What is ASIN?", messages[2].content)
+   740            assert.equals("ASIN is an identifier.", messages[3].content)
+   741            assert.is_nil(messages[2].content:find("%[%^asin%]:"))
+   742            assert.is_nil(messages[3].content:find("%[%^asin%]:"))
+   743        end)
+   744
+   745        it("preserves ordinary horizontal-rule content that is not a managed footer", function()
+   746            local answer = table.concat({
+   747                "first half",
+   748                "",
+   749                "---",
+   750                "",
+   751                "second half, not a footnote",
+   752            }, "\n")
+   753            local pc = parsed_chat({ exchange("Q", answer), exchange("Next") })
+   754            pc.exchanges[1].question.line_start = 10
+   755            pc.exchanges[1].answer.line_start = 12
+   756            pc.exchanges[2].question.line_start = 20
+   757
+   758            local messages = parley._build_messages({
+   759                parsed_chat = pc,
+   760                start_index = 1,
+   761                end_index = 100,
+   762                exchange_idx = 2,
+   763                agent = agent(),
+   764                config = parley.config,
+   765                helpers = stub_helpers,
+   766                logger = stub_logger
+   767            })
+   768
+   769            assert.equals(answer, messages[3].content)
+   770        end)
+   771
+   772        it("keeps earlier horizontal-rule content and strips only the final managed footer", function()
+   773            local answer = table.concat({
+   774                "first half",
+   775                "",
+   776                "---",
+   777                "",
+   778                "second half",
+   779                "",
+   780                "---",
+   781                "",
+   782                "[^asin]: Amazon Standard Identification Number.",
+   783            }, "\n")
+   784            local pc = parsed_chat({ exchange("Q", answer), exchange("Next") })
+   785            pc.exchanges[1].question.line_start = 10
+   786            pc.exchanges[1].answer.line_start = 12
+   787            pc.exchanges[2].question.line_start = 20
+   788
+   789            local messages = parley._build_messages({
+   790                parsed_chat = pc,
+  1595            assert.is_true(found_tu, "assistant message must carry the tool_use")
+  1596            assert.equals("user", last.role)
+  1597            assert.equals("tool_result", last.content[1].type)
+  1598            assert.equals("toolu_z", last.content[1].tool_use_id)
+  1599            assert.is_true(last.content[1].is_error)
+  1600
+  1601            vim.api.nvim_buf_delete(buf, { force = true })
+  1602        end)
+  1603    end)
+  1604
+  1605    describe("build_messages_from_model: durable definition footnotes", function()
+  1606        local exchange_model = require("parley.exchange_model")
+  1607
+  1608        it("strips managed footnote footers from live question and answer blocks", function()
+  1609            local question_lines = {
+  1610                "💬: What is ASIN?",
+  1611                "",
+  1612                "---",
+  1613                "",
+  1614                "[^asin]: Amazon Standard Identification Number.",
+  1615            }
+  1616            local answer_lines = {
+  1617                "ASIN is an identifier.",
+  1618                "",
+  1619                "---",
+  1620                "",
+  1621                "[^asin]: Amazon Standard Identification Number.",
+  1622            }
+  1623            local header = { "topic: t", "---" }
+  1624            local header_lines = #header
+  1625            local model = exchange_model.new(header_lines)
+  1626            model:add_exchange(#question_lines)
+  1627            model:add_block(1, "agent_header", 1)
+  1628            model:add_block(1, "text", #answer_lines)
+  1629
+  1630            local q0 = model:block_start(1, 1)
+
+exec
+/bin/zsh -lc 'rg -n "is_footnote_definition|footnote" lua/parley/chat_parser.lua tests/unit/parse_chat_spec.lua' in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+tests/unit/parse_chat_spec.lua:667:    it("stops a final open question before a managed footnote footer", function()
+tests/unit/parse_chat_spec.lua:682:    it("positions a final open-question answer above managed footnotes", function()
+lua/parley/chat_parser.lua:32:local function is_footnote_definition(line)
+lua/parley/chat_parser.lua:310:    local function final_footnote_boundary(end_line)
+lua/parley/chat_parser.lua:315:        if i <= 0 or not is_footnote_definition(lines[i]) then
+lua/parley/chat_parser.lua:319:        local footnote_start = i
+lua/parley/chat_parser.lua:323:            if is_footnote_definition(line) then
+lua/parley/chat_parser.lua:324:                footnote_start = i
+lua/parley/chat_parser.lua:331:        local boundary = footnote_start
+lua/parley/chat_parser.lua:346:                local boundary = final_footnote_boundary(end_line)
+
+codex
+This uncovered a real stale duplicate: `chat_parser.lua` still has its own final-footer scanner. I’m reading that block closely because it affects whether the new “first footnote line” rule is truly single-sourced across parser/model behavior.
+exec
+/bin/zsh -lc "nl -ba lua/parley/chat_parser.lua | sed -n '285,360p'" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+   285
+   286        -- Track the current exchange and component being built
+   287        local current_exchange = nil
+   288        local current_component = nil
+   289        local line_before_local = nil
+   290        local first_question_seen = false
+   291        -- Multi-line reasoning state: opened by a 🧠: line inside an answer.
+   292        -- Two termination modes, decided per-block at open time:
+   293        --   - explicit-end mode (in_reasoning_explicit_end = true): a
+   294        --     🧠:[END] line was found before the next structural marker.
+   295        --     Blank lines inside the block are content; only 🧠:[END] or a
+   296        --     structural marker (📝/🔧/📎/💬/🤖/🌿/🔒) terminates. This
+   297        --     lets the model emit blank-line paragraphs inside reasoning.
+   298        --   - legacy mode (in_reasoning_explicit_end = false): no 🧠:[END]
+   299        --     follows. The first blank line terminates. Preserves backward
+   300        --     compat with chats authored under the previous convention.
+   301        -- Continuation lines are appended to current_exchange.reasoning.content
+   302        -- (joined by \n) and also fed into the answer's content_parts /
+   303        -- content_blocks like normal answer text, so subsequent turns replay
+   304        -- the model's prior reasoning verbatim.
+   305        local in_reasoning_block = false
+   306        local in_reasoning_explicit_end = false
+   307        -- Use table accumulation instead of string concat for content (avoids O(n²))
+   308        local content_parts = {}
+   309
+   310        local function final_footnote_boundary(end_line)
+   311            local i = end_line
+   312            while i > 0 and trim(lines[i] or "") == "" do
+   313                i = i - 1
+   314            end
+   315            if i <= 0 or not is_footnote_definition(lines[i]) then
+   316                return nil
+   317            end
+   318
+   319            local footnote_start = i
+   320            i = i - 1
+   321            while i > 0 do
+   322                local line = lines[i] or ""
+   323                if is_footnote_definition(line) then
+   324                    footnote_start = i
+   325                elseif trim(line) ~= "" then
+   326                    break
+   327                end
+   328                i = i - 1
+   329            end
+   330
+   331            local boundary = footnote_start
+   332            local before = boundary - 1
+   333            while before > 0 and trim(lines[before] or "") == "" do
+   334                before = before - 1
+   335            end
+   336            if before > 0 and is_divider(lines[before]) then
+   337                boundary = before
+   338            end
+   339            return boundary
+   340        end
+   341
+   342        -- Helper to finalize the current component's content from accumulated parts
+   343        local function finalize_component(end_line)
+   344            if current_exchange and current_component then
+   345                if current_component == "question" then
+   346                    local boundary = final_footnote_boundary(end_line)
+   347                    if boundary and boundary > current_exchange[current_component].line_start then
+   348                        local keep_count = boundary - current_exchange[current_component].line_start
+   349                        while #content_parts > keep_count do
+   350                            table.remove(content_parts)
+   351                        end
+   352                        end_line = boundary - 1
+   353                    end
+   354                end
+   355                -- Trim trailing blank lines from all components so the
+   356                -- model's margins are the single source of truth for gaps
+   357                -- between blocks/exchanges. Without this, trailing blanks
+   358                -- in the parser's line_end would double-count with the
+   359                -- model's MARGIN constant.
+   360                local trimmed_end = end_line
+
+codex
+```verdict
+verdict: REWORK
+confidence: high
+```
+
+The core `define.lua` change implements the requested dividerless boundary and the main diagnostics/highlighting paths follow it, but the repo still has a separate managed-footer parser in `chat_parser.lua`. That shadow implementation still applies different boundary rules, so the single-source footer contract is not actually fulfilled.
+
+1. Strengths:
+- [lua/parley/define.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/define.lua:170) keeps the new core detector pure and small.
+- [tests/unit/define_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/unit/define_spec.lua:243) pins dividerless and legacy divider-based footer ranges.
+- [tests/integration/highlighting_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/integration/highlighting_spec.lua:519) covers dividerless diagnostics and footer highlighting.
+- Atlas updates correctly describe the new boundary in `atlas/chat/inline_define.md` and `atlas/ui/highlights.md`.
+
+2. Critical findings:
+- [lua/parley/chat_parser.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/chat_parser.lua:310) still contains a hand-maintained `final_footnote_boundary` scanner plus its own footnote predicate at line 32. This violates the issue’s “all current consumers keep deriving from that helper” contract and fails ARCH-DRY / ARCH-PURPOSE. It also keeps older semantics: it only recognizes a footer when the last nonblank line is a footnote and treats a preceding `---` as the boundary, while `define.managed_footnote_footer_range` now defines the first `[^id]:` line to EOF as the boundary. Fix sketch: make chat parsing derive from `parley.define.managed_footnote_footer_range` or extract one shared pure helper for “content trim start including optional legacy divider”, then add parse-chat tests for dividerless footers and footnote-plus-trailing-text.
+
+3. Important findings:
+- None beyond the blocking shadow-consumer issue.
+
+4. Minor findings:
+- [lua/parley/highlighter.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/highlighter.lua:747) has a stale comment saying the managed footer is ``---` + `[^id]: ...``; update it to match the new boundary.
+
+5. Test coverage notes:
+- I ran `git diff --check c481296d..HEAD`, `PlenaryBustedFile tests/unit/define_spec.lua`, and `PlenaryBustedFile tests/integration/highlighting_spec.lua`; all passed, with existing local Neovim startup warnings.
+- Missing coverage: `parse_chat` should have dividerless managed-footer tests, including the trailing-text-to-EOF case.
+
+6. Architectural notes for upcoming work:
+- ARCH-DRY: flagged. Footer boundary logic must have one source.
+- ARCH-PURE: pass for the new `define.lua` core; keep the parser fix pure as well.
+- ARCH-PURPOSE: flagged. The purpose is not only recognizing dividerless footers in the obvious consumers, but eliminating stale restatements of the managed-footer model.
+
+7. Plan revision recommendations:
+- Add a `## Revisions` entry noting that review found `chat_parser.lua` as an additional managed-footer consumer and that the plan now includes deriving it from the shared footer boundary helper plus parse-chat regression coverage.
+tokens used
+56,296
+```verdict
+verdict: REWORK
+confidence: high
+```
+
+The core `define.lua` change implements the requested dividerless boundary and the main diagnostics/highlighting paths follow it, but the repo still has a separate managed-footer parser in `chat_parser.lua`. That shadow implementation still applies different boundary rules, so the single-source footer contract is not actually fulfilled.
+
+1. Strengths:
+- [lua/parley/define.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/define.lua:170) keeps the new core detector pure and small.
+- [tests/unit/define_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/unit/define_spec.lua:243) pins dividerless and legacy divider-based footer ranges.
+- [tests/integration/highlighting_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/integration/highlighting_spec.lua:519) covers dividerless diagnostics and footer highlighting.
+- Atlas updates correctly describe the new boundary in `atlas/chat/inline_define.md` and `atlas/ui/highlights.md`.
+
+2. Critical findings:
+- [lua/parley/chat_parser.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/chat_parser.lua:310) still contains a hand-maintained `final_footnote_boundary` scanner plus its own footnote predicate at line 32. This violates the issue’s “all current consumers keep deriving from that helper” contract and fails ARCH-DRY / ARCH-PURPOSE. It also keeps older semantics: it only recognizes a footer when the last nonblank line is a footnote and treats a preceding `---` as the boundary, while `define.managed_footnote_footer_range` now defines the first `[^id]:` line to EOF as the boundary. Fix sketch: make chat parsing derive from `parley.define.managed_footnote_footer_range` or extract one shared pure helper for “content trim start including optional legacy divider”, then add parse-chat tests for dividerless footers and footnote-plus-trailing-text.
+
+3. Important findings:
+- None beyond the blocking shadow-consumer issue.
+
+4. Minor findings:
+- [lua/parley/highlighter.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/highlighter.lua:747) has a stale comment saying the managed footer is ``---` + `[^id]: ...``; update it to match the new boundary.
+
+5. Test coverage notes:
+- I ran `git diff --check c481296d..HEAD`, `PlenaryBustedFile tests/unit/define_spec.lua`, and `PlenaryBustedFile tests/integration/highlighting_spec.lua`; all passed, with existing local Neovim startup warnings.
+- Missing coverage: `parse_chat` should have dividerless managed-footer tests, including the trailing-text-to-EOF case.
+
+6. Architectural notes for upcoming work:
+- ARCH-DRY: flagged. Footer boundary logic must have one source.
+- ARCH-PURE: pass for the new `define.lua` core; keep the parser fix pure as well.
+- ARCH-PURPOSE: flagged. The purpose is not only recognizing dividerless footers in the obvious consumers, but eliminating stale restatements of the managed-footer model.
+
+7. Plan revision recommendations:
+- Add a `## Revisions` entry noting that review found `chat_parser.lua` as an additional managed-footer consumer and that the plan now includes deriving it from the shared footer boundary helper plus parse-chat regression coverage.


codex
I’ll use `superpowers-using-superpowers` for the session-start requirement, then verify the current HEAD against the issue/spec and the provided base window.
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
/bin/zsh -lc "sed -n '1,220p' workshop/lessons.md" in /Users/xianxu/workspace/parley.nvim
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

## 2026-07-08 (#169)
- **When centralizing a policy, delete caller-local defaults that can bypass it.** #169 routed review and define diagnostics through `skill_render.format_diagnostic_message`, but `define.format_definition` still passed `width or 80`, preserving an old fallback and weakening the shared width policy. Rule: after adding a shared formatter/config helper, grep every caller for old fallback constants and add a test for the nil/default path so future callers inherit the central behavior.

## 2026-07-08 (#174)
- **`virt_lines_leftcol = true` means gutter/window-left anchoring, not buffer text-column anchoring.** #173 used it to escape Neovim's stock diagnostic-column indentation on long wrapped prose, but the follow-up screenshot showed the block starting in the line-number/sign gutter. For diagnostic text that should align with paragraph content, place the extmark at column 0 and omit `virt_lines_leftcol`; test the extmark options directly so "visible" does not regress into "misaligned."

## 2026-07-08 (#175)
- **Shared diagnostic display needs source-specific visibility predicates when sources mean different things.** Review diagnostics span an edit region and should show anywhere inside `lnum..end_lnum`; footnote diagnostics point at a precise `term[^id]` anchor and should show only when the cursor is inside `col..end_col`. A single "current line" predicate was too broad for footnotes. Rule: when multiple diagnostic sources share one renderer, test each source's visibility contract explicitly.

## 2026-07-08 (#176)
- **README snippets are consumers of user-facing UI behavior, not marketing fluff.** #176 updated atlas when footnote definitions moved from virtual lines to a centered float, but the close review caught README still saying "grey pop-under" for visual `<M-CR>`. Rule: when changing a visible command/keybinding behavior, grep README for the command, keybinding, and old UI nouns alongside atlas.

## 2026-07-08 (#171)
- **A new `config.highlight.*` override is user-facing even when it is optional.** #171 added `config.highlight.footnote` support in the highlighter and documented the highlight group in atlas, but the close review caught that the default config/reference table still omitted the key. Rule: whenever code reads a new config override key, update `lua/parley/config.lua`'s defaults in the same commit and grep README/atlas for config snippets that mirror those defaults.
- **Generated SDLC review sidecars are still committed artifacts.** The #171 close sidecar captured trailing whitespace from the review transcript and made `git diff --check base..HEAD` fail even though source files were clean. Rule: after any `sdlc close`/review sidecar generation, run `git diff --check <base>..HEAD -- workshop/plans/<issue>-*-review.md` (or strip trailing whitespace on the sidecar) before committing the close artifact.

## 2026-07-08 (#178)
- **After changing a shared parser rule, grep for every shadow parser before close.** #178 changed `define.managed_footnote_footer_range`, but `chat_parser.lua` still had a local footer scanner at close review. Rule: for grammar or boundary-policy changes, grep the old predicates/terms and route all consumers through shared helpers before boundary review.

codex
I’ve loaded the workflow contract and lessons. Now I’m checking the actual diff, issue state, and the footer consumers rather than relying on the embedded review transcript.
exec
/bin/zsh -lc "sed -n '1,260p' workshop/issues/000178-recognize-footnote-footer-without-divider.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
---
id: 000178
status: working
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 0.27
started: 2026-07-08T23:33:32-07:00
---

# recognize footnote footer without divider

## Problem

The #171 footnote-coloring fix still defines a managed footnote footer as a final
`---` divider followed by `[^id]: ...` lines. The desired footer boundary is
simpler: the first markdown footnote definition line (`[^id]: ...`) starts the
footer, even when no divider is present.

## Spec

`parley.define.managed_footnote_footer_range(lines)` returns the range from the
first line that starts with a markdown footnote definition pattern (`[^id]:`) to
EOF. It no longer requires a preceding `---` divider.

All current consumers keep deriving from that helper (ARCH-DRY, ARCH-PURE):
footnote diagnostics, footer stripping, and chat/markdown highlighting should
adopt the new boundary without duplicating parser logic.

## Done when

- A buffer with `[^asin]: ...` and no preceding `---` is recognized as having a
  managed footnote footer starting at that line.
- Footnote diagnostics and `ParleyFootnote` highlighting work for dividerless
  footers.
- Existing divider-based footers remain supported, but the footer range starts at
  the first `[^id]:` line, not at `---`.

## Plan

- [x] Add failing pure tests for dividerless footer range and stripping.
- [x] Add/update integration coverage for diagnostics/highlighting with a
  dividerless footer.
- [x] Change the pure footer helper to scan for the first footnote definition
  line and let consumers derive from it.
- [x] Route chat parser footer trimming through the shared helper and cover
  dividerless/trailing-text parser behavior.
- [x] Run focused unit/integration verification plus lint/diff checks.

## Estimate

Derived via `estimate-logic-v3.1` against the repo-local calibration source from
`sdlc estimate-source` (stale but canonical for this repo).

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.03 impl=0.00
item: lua-neovim design=0.05 impl=0.15
item: milestone-review design=0.00 impl=0.02
total: 0.27
```

## Log

### 2026-07-08

- User clarified the #171 footer check should be based on the first `[^id]:`
  footnote definition line instead of a `---` + footnote block. Design keeps the
  grammar in `parley.define.managed_footnote_footer_range` so diagnostics and
  highlighters remain derived consumers.
- TDD red: dividerless footer unit/integration tests failed because the detector
  still required a final divider block and consumers skipped the first footnote
  definition line.
- Implemented the pure detector as "first footnote definition line to EOF" and
  updated diagnostics/update/strip loops to consume from that returned boundary.
- Verification: `make lint` passed; `nvim --headless -c "PlenaryBustedFile
  tests/unit/define_spec.lua"` passed; `nvim --headless -c "PlenaryBustedFile
  tests/integration/highlighting_spec.lua"` passed; scoped `git diff --check`
  passed. Full `make test` still fails in unrelated
  `tests/unit/tools_builtin_find_spec.lua` only under the parallel full-suite
  runner; that spec passes directly.
- Close review returned REWORK because `lua/parley/chat_parser.lua` still had a
  shadow footnote-footer scanner. Routed chat parsing through
  `define.managed_footnote_content_start`, which derives from the first-footnote
  footer range while preserving the optional legacy divider as content trim.
- Rework verification: `nvim --headless -c "PlenaryBustedFile
  tests/unit/parse_chat_spec.lua"` passed; `nvim --headless -c "PlenaryBustedFile
  tests/unit/define_spec.lua"` passed; `nvim --headless -c "PlenaryBustedFile
  tests/integration/highlighting_spec.lua"` passed; `nvim --headless -c
  "PlenaryBustedFile tests/unit/build_messages_spec.lua"` passed; `make lint`
  passed; scoped `git diff --check` passed. Full `make test` still fails only at
  the known parallel-run `tests/unit/tools_builtin_find_spec.lua`; the same spec
  passes directly.

## Revisions

### 2026-07-08 — close review parser consumer

The close review found `lua/parley/chat_parser.lua` still had a local managed
footer scanner. Scope expands to route parser trimming through
`define.managed_footnote_content_start` (derived from the footer range) and add
parser regression coverage for dividerless, trailing-text, and legacy-divider
footers, preserving the single-source boundary (ARCH-DRY, ARCH-PURPOSE).

exec
/bin/zsh -lc "nl -ba lua/parley/define.lua | sed -n '150,360p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   150
   151    --- @param id string
   152    --- @param definition string|nil
   153    --- @return string
   154    function M.format_footnote_line(id, definition)
   155        definition = trim(definition)
   156        if definition == "" then
   157            definition = "(no definition)"
   158        end
   159        return string.format("[^%s]: %s", id, definition)
   160    end
   161
   162    local function is_divider(line)
   163        return trim(line) == "---"
   164    end
   165
   166    local function is_footnote_line(line)
   167        return trim(line):match("^%[%^[^%]]+%]:") ~= nil
   168    end
   169
   170    local function managed_footer_start(lines)
   171        for i, line in ipairs(lines or {}) do
   172            if is_footnote_line(line) then
   173                return i
   174            end
   175        end
   176        return nil
   177    end
   178
   179    --- Locate the final managed definition-footnote footer.
   180    --- @param lines string[]|nil
   181    --- @return table|nil { start_line: integer, end_line: integer } 1-based inclusive
   182    function M.managed_footnote_footer_range(lines)
   183        lines = lines or {}
   184        local start = managed_footer_start(lines)
   185        if not start then
   186            return nil
   187        end
   188        return { start_line = start, end_line = #lines }
   189    end
   190
   191    --- Locate the line where user-authored content should stop before a managed
   192    --- definition-footnote footer. The public footer range starts at the first
   193    --- `[^id]:` line, but old buffers may still have a preceding `---` separator
   194    --- that should be stripped from prompts/messages too.
   195    --- @param lines string[]|nil
   196    --- @return integer|nil 1-based inclusive start line to trim from content
   197    function M.managed_footnote_content_start(lines)
   198        lines = lines or {}
   199        local range = M.managed_footnote_footer_range(lines)
   200        if not range then
   201            return nil
   202        end
   203        local start = range.start_line
   204        local before = start - 1
   205        while before > 0 and trim(lines[before]) == "" do
   206            before = before - 1
   207        end
   208        if before > 0 and is_divider(lines[before]) then
   209            start = before
   210        end
   211        return start
   212    end
   213
   214    local function parse_footnote_line(line)
   215        local id, definition = trim(line):match("^%[%^([^%]]+)%]:%s*(.-)%s*$")
   216        if not id then
   217            return nil
   218        end
   219        definition = trim(definition)
   220        if definition == "" then
   221            definition = "(no definition)"
   222        end
   223        return id, definition
   224    end
   225
   226    local function is_term_byte(ch)
   227        return ch:match("[%w_-]") ~= nil
   228    end
   229
   230    local function expand_term_start(line, ref_start)
   231        local start = ref_start
   232        while start > 1 and is_term_byte(line:sub(start - 1, start - 1)) do
   233            start = start - 1
   234        end
   235        return start
   236    end
   237
   238    --- Derive persisted definition diagnostics from inline footnote references and
   239    --- the final managed definition footer.
   240    --- @param lines string[]
   241    --- @return table[] diagnostics with 0-based columns
   242    function M.footnote_diagnostics(lines)
   243        lines = lines or {}
   244        local footer = managed_footer_start(lines)
   245        if not footer then
   246            return {}
   247        end
   248
   249        local definitions = {}
   250        for i = footer, #lines do
   251            local id, definition = parse_footnote_line(lines[i] or "")
   252            if id then
   253                definitions[id] = definition
   254            end
   255        end
   256
   257        local diagnostics = {}
   258        for lnum = 1, footer - 1 do
   259            local line = lines[lnum] or ""
   260            local search = 1
   261            while true do
   262                local ref_start, ref_end, id = line:find("%[%^([^%]]+)%]", search)
   263                if not ref_start then
   264                    break
   265                end
   266                local definition = definitions[id]
   267                if definition then
   268                    local term_start = expand_term_start(line, ref_start)
   269                    local term = line:sub(term_start, ref_start - 1)
   270                    table.insert(diagnostics, {
   271                        id = id,
   272                        term = term ~= "" and term or nil,
   273                        definition = definition,
   274                        lnum = lnum - 1,
   275                        col = term_start - 1,
   276                        end_lnum = lnum - 1,
   277                        end_col = ref_end,
   278                    })
   279                end
   280                search = ref_end + 1
   281            end
   282        end
   283        return diagnostics
   284    end
   285
   286    local function split_text_lines(text)
   287        text = text or ""
   288        local lines = {}
   289        local start = 1
   290        while true do
   291            local nl = text:find("\n", start, true)
   292            if not nl then
   293                lines[#lines + 1] = text:sub(start)
   294                break
   295            end
   296            lines[#lines + 1] = text:sub(start, nl - 1)
   297            start = nl + 1
   298        end
   299        if #lines > 1 and lines[#lines] == "" then
   300            table.remove(lines)
   301        end
   302        return lines
   303    end
   304
   305    local function copy_lines(lines)
   306        local out = {}
   307        for i, line in ipairs(lines or {}) do
   308            out[i] = line
   309        end
   310        return out
   311    end
   312
   313    --- Strip a final managed definition-footnote footer from text.
   314    --- @param text string|nil
   315    --- @return string
   316    function M.strip_definition_footnote_footer(text)
   317        local lines = split_text_lines(text or "")
   318        local start = M.managed_footnote_content_start(lines)
   319        if not start then
   320            return text or ""
   321        end
   322        local kept = {}
   323        for i = 1, start - 1 do
   324            kept[#kept + 1] = lines[i]
   325        end
   326        while #kept > 0 and trim(kept[#kept]) == "" do
   327            table.remove(kept)
   328        end
   329        return table.concat(kept, "\n")
   330    end
   331
   332    local function replace_or_append_footnote(lines, id, definition)
   333        local out = copy_lines(lines)
   334        local footer = managed_footer_start(out)
   335        local footnote_line = M.format_footnote_line(id, definition)
   336        if footer then
   337            for i = footer, #out do
   338                local escaped_id = id:gsub("([^%w])", "%%%1")
   339                if trim(out[i]):match("^%[%^" .. escaped_id .. "%]:") then
   340                    out[i] = footnote_line
   341                    return out
   342                end
   343            end
   344            out[#out + 1] = footnote_line
   345            return out
   346        end
   347
   348        while #out > 0 and trim(out[#out]) == "" do
   349            table.remove(out)
   350        end
   351        out[#out + 1] = ""
   352        out[#out + 1] = "---"
   353        out[#out + 1] = ""
   354        out[#out + 1] = footnote_line
   355        return out
   356    end
   357
   358    --- Insert a markdown footnote reference after the selected text and store the
   359    --- definition in a managed footer.
   360    --- @param lines string[]

exec
/bin/zsh -lc 'git diff --stat c481296d642c30cfbddbe1b5fd62c6265b397fe3..HEAD && git diff --name-only c481296d642c30cfbddbe1b5fd62c6265b397fe3..HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
 atlas/chat/inline_define.md                        |   23 +-
 atlas/ui/highlights.md                             |    2 +-
 lua/parley/chat_parser.lua                         |   38 +-
 lua/parley/define.lua                              |   51 +-
 lua/parley/highlighter.lua                         |    2 +-
 tests/integration/highlighting_spec.lua            |   18 +-
 tests/unit/define_spec.lua                         |   62 +-
 tests/unit/parse_chat_spec.lua                     |   32 +-
 ...78-recognize-footnote-footer-without-divider.md |   83 +-
 workshop/lessons.md                                |    3 +
 ...footnote-footer-without-divider-close-review.md | 2897 ++++++++++++++++++++
 11 files changed, 3109 insertions(+), 102 deletions(-)
atlas/chat/inline_define.md
atlas/ui/highlights.md
lua/parley/chat_parser.lua
lua/parley/define.lua
lua/parley/highlighter.lua
tests/integration/highlighting_spec.lua
tests/unit/define_spec.lua
tests/unit/parse_chat_spec.lua
workshop/issues/000178-recognize-footnote-footer-without-divider.md
workshop/lessons.md
workshop/plans/000178-recognize-footnote-footer-without-divider-close-review.md

exec
/bin/zsh -lc "nl -ba lua/parley/chat_parser.lua | sed -n '20,55p;295,360p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
    20    local logger = require("parley.logger")
    21
    22    local M = {}
    23
    24    local function trim(str)
    25        return (str:gsub("^%s*(.-)%s*$", "%1"))
    26    end
    27
    28    ---Find the header/trancript separator index.
    29    ---Supports:
    30    ---1) Legacy format: metadata lines followed by a single `---`.
    31    ---2) Front matter format: opening `---`, metadata, closing `---`.
    32    ---@param lines table
    33    ---@return number|nil
    34    M.find_header_end = function(lines)
    35        if not lines or #lines == 0 then
    36            return nil
    37        end
    38
    39        if trim(lines[1]) == "---" then
    40            for i = 2, #lines do
    41                if trim(lines[i]) == "---" then
    42                    return i
    43                end
    44            end
    45            return nil
    46        end
    47
    48        for i, line in ipairs(lines) do
    49            if trim(line) == "---" then
    50                return i
    51            end
    52        end
    53
    54        return nil
    55    end
   295        -- content_blocks like normal answer text, so subsequent turns replay
   296        -- the model's prior reasoning verbatim.
   297        local in_reasoning_block = false
   298        local in_reasoning_explicit_end = false
   299        -- Use table accumulation instead of string concat for content (avoids O(n²))
   300        local content_parts = {}
   301        local footnote_content_start = require("parley.define").managed_footnote_content_start(lines)
   302
   303        local function final_footnote_boundary(end_line)
   304            if not footnote_content_start or footnote_content_start > end_line then
   305                return nil
   306            end
   307            return footnote_content_start
   308        end
   309
   310        -- Helper to finalize the current component's content from accumulated parts
   311        local function finalize_component(end_line)
   312            if current_exchange and current_component then
   313                if current_component == "question" then
   314                    local boundary = final_footnote_boundary(end_line)
   315                    if boundary and boundary > current_exchange[current_component].line_start then
   316                        local keep_count = boundary - current_exchange[current_component].line_start
   317                        while #content_parts > keep_count do
   318                            table.remove(content_parts)
   319                        end
   320                        end_line = boundary - 1
   321                    end
   322                end
   323                -- Trim trailing blank lines from all components so the
   324                -- model's margins are the single source of truth for gaps
   325                -- between blocks/exchanges. Without this, trailing blanks
   326                -- in the parser's line_end would double-count with the
   327                -- model's MARGIN constant.
   328                local trimmed_end = end_line
   329                while trimmed_end > current_exchange[current_component].line_start
   330                    and (not lines[trimmed_end] or not lines[trimmed_end]:match("%S")) do
   331                    trimmed_end = trimmed_end - 1
   332                end
   333                current_exchange[current_component].line_end = trimmed_end
   334                current_exchange[current_component].content = table.concat(content_parts, "\n"):gsub("^%s*(.-)%s*$", "%1")
   335                content_parts = {}
   336            end
   337        end
   338
   339        --------------------------------------------------------------------------
   340        -- M2 Task 2.5 of #81: content_blocks state machine
   341        --
   342        -- Parallel to the existing content_parts flow (which builds the flat
   343        -- answer.content for backward compat), this state machine builds a
   344        -- structured `answer.content_blocks` list preserving the buffer order
   345        -- of text / tool_use / tool_result sub-components inside a `🤖:`
   346        -- answer region. Tool block body decoding is delegated to
   347        -- lua/parley/tools/serialize.lua so any schema change there
   348        -- automatically propagates here without re-writing regex.
   349        --
   350        -- The machine is only "alive" inside an answer region. It's (re-)
   351        -- initialized by the `🤖:` branch and finalized + attached to the
   352        -- answer object by the next `💬:` branch (or at end of file).
   353        --------------------------------------------------------------------------
   354        local cb_state = nil -- nil when not inside an answer
   355        local serialize_ok, serialize = pcall(require, "parley.tools.serialize")
   356
   357        local function cb_start_block(kind)
   358            if not cb_state then return end
   359            cb_state.current_kind = kind
   360            cb_state.current_lines = {}

codex
The rework is present in HEAD: `chat_parser.lua` now calls `define.managed_footnote_content_start`, and the issue has a revision entry for that review finding. I’m doing a shadow-sweep for remaining footer predicates/comments and checking the targeted tests.
exec
/bin/zsh -lc "nl -ba tests/unit/parse_chat_spec.lua | sed -n '660,725p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   660            local refs = result.exchanges[1].question.file_references
   661            assert.equals(2, #refs)
   662        end)
   663    end)
   664
   665
   666    describe("parse_chat: edge cases", function()
   667        it("stops a final open question before a managed footnote footer", function()
   668            local lines, header_end = make_chat(std_header, {
   669                "💬: tell me about the EVAL framework",
   670                "",
   671                "[^acos]: ACOS (Advertising Cost of Sales).",
   672            })
   673            local result = parse_chat(lines, header_end)
   674
   675            assert.equals("tell me about the EVAL framework", result.exchanges[1].question.content)
   676            assert.equals(7, result.exchanges[1].question.line_start)
   677            assert.equals(7, result.exchanges[1].question.line_end)
   678        end)
   679
   680        it("stops a final open question before an optional legacy footnote divider", function()
   681            local lines, header_end = make_chat(std_header, {
   682                "💬: tell me about the EVAL framework",
   683                "",
   684                "---",
   685                "",
   686                "[^acos]: ACOS (Advertising Cost of Sales).",
   687            })
   688            local result = parse_chat(lines, header_end)
   689
   690            assert.equals("tell me about the EVAL framework", result.exchanges[1].question.content)
   691            assert.equals(7, result.exchanges[1].question.line_start)
   692            assert.equals(7, result.exchanges[1].question.line_end)
   693        end)
   694
   695        it("positions a final open-question answer above managed footnotes", function()
   696            local exchange_model = require("parley.exchange_model")
   697            local lines, header_end = make_chat(std_header, {
   698                "💬: tell me about the EVAL framework",
   699                "",
   700                "[^acos]: ACOS (Advertising Cost of Sales).",
   701            })
   702            local parsed = parse_chat(lines, header_end)
   703            local model = exchange_model.from_parsed_chat(parsed)
   704
   705            model:add_block(1, "agent_header", 1)
   706            local agent_header_start = model:block_start(1, 2)
   707
   708            assert.equals(8, agent_header_start)
   709            assert.equals("[^acos]: ACOS (Advertising Cost of Sales).", lines[agent_header_start + 1])
   710        end)
   711
   712        it("stops a final open question before the first footnote definition even with trailing text", function()
   713            local lines, header_end = make_chat(std_header, {
   714                "💬: tell me about the EVAL framework",
   715                "",
   716                "[^acos]: ACOS (Advertising Cost of Sales).",
   717                "",
   718                "trailing footer text",
   719            })
   720            local result = parse_chat(lines, header_end)
   721
   722            assert.equals("tell me about the EVAL framework", result.exchanges[1].question.content)
   723            assert.equals(7, result.exchanges[1].question.line_start)
   724            assert.equals(7, result.exchanges[1].question.line_end)
   725        end)

exec
/bin/zsh -lc "nl -ba lua/parley/highlighter.lua | sed -n '260,306p;466,482p;742,752p'" in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc 'rg -n "managed_footnote_footer_range|managed_footnote_content_start|footnote_diagnostics|strip_definition_footnote_footer|is_footnote_definition|is_footnote_line|ParleyFootnote|---` '"\\+ "'`'"\\[\\"'^id'"\\]|footnote footer|managed footer\" lua tests atlas README.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   260    end
   261
   262    -- Compute desired chat highlights for a 1-indexed line range.
   263    -- Returns a table keyed by 0-indexed row: { [row] = { {hl_group, col_start, col_end}, ... } }
   264    -- Scans HIGHLIGHT_CONTEXT_LINES above start_line for block state context.
   265    local function compute_chat_highlights(buf, start_line, end_line)
   266        local result = {}
   267        local patterns = get_chat_highlight_prefix_patterns()
   268        local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)
   269        local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
   270        local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
   271        -- While a stream is in flight for this buffer, the model has not
   272        -- yet emitted 🧠:[END]. Assume explicit-end mode so blank-line
   273        -- paragraph breaks inside the in-progress thinking region keep
   274        -- their dim highlight instead of prematurely terminating the
   275        -- block. After the stream completes (is_busy → false), the
   276        -- lookahead-decided mode takes over and a real [END] / structural
   277        -- marker controls termination.
   278        local streaming = require("parley.tasker").is_busy(buf, true)
   279        local in_block, in_code_block, in_reasoning_block, in_reasoning_explicit_end =
   280            bootstrap_chat_highlight_state(buf, start_line, patterns, streaming)
   281
   282        local in_tool_block = false  -- inside 🔧:/📎: fenced content
   283
   284        for offset, line in ipairs(lines) do
   285            local line_nr = start_line + offset - 1
   286            if line:match("^%s*```") then
   287                in_code_block = not in_code_block
   288                -- Exiting a code block while in a tool region ends the tool region
   289                if not in_code_block and in_tool_block then
   290                    in_tool_block = false
   291                end
   292            end
   293
   294            local highlighted_regions = {}
   295            local row = line_nr - 1
   296
   297            result[row] = result[row] or {}
   298
   299            push_artifact_refs(result, row, line) -- #160: navigable artifact refs
   300
   301            local is_footer = footer_range and line_nr >= footer_range.start_line and line_nr <= footer_range.end_line
   302            if is_footer then
   303                table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
   304                in_block = false
   305            else
   306                local pos = 1
   466    local function compute_markdown_highlights(buf, start_line, end_line)
   467        local result = {}
   468        local branch_prefix = _parley.config.chat_branch_prefix or "🌿:"
   469        local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)
   470        local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
   471        local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
   472        for offset, line in ipairs(lines) do
   473            local row = start_line + offset - 2
   474            local line_nr = row + 1
   475            push_artifact_refs(result, row, line) -- #160: navigable artifact refs
   476            if footer_range and line_nr >= footer_range.start_line and line_nr <= footer_range.end_line then
   477                result[row] = result[row] or {}
   478                table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
   479            end
   480            if line:sub(1, #branch_prefix) == branch_prefix then
   481                result[row] = result[row] or {}
   482                table.insert(result[row], { hl_group = "ParleyChatReference", col_start = 0, col_end = -1 })
   742            vim.api.nvim_set_hl(0, "ParleyReference", user_highlights.reference)
   743        else
   744            vim.api.nvim_set_hl(0, "ParleyReference", { underline = true })
   745        end
   746
   747        -- Managed definition-footnote footer (from the first `[^id]: ...`). It must be
   748        -- independent of the surrounding chat exchange color.
   749        if user_highlights.footnote then
   750            vim.api.nvim_set_hl(0, "ParleyFootnote", user_highlights.footnote)
   751        else
   752            vim.api.nvim_set_hl(0, "ParleyFootnote", { link = "DiagnosticHint" })

 succeeded in 0ms:
zsh:1: command not found: +
lua/parley/define.lua:166:local function is_footnote_line(line)
lua/parley/define.lua:172:        if is_footnote_line(line) then
lua/parley/define.lua:179:--- Locate the final managed definition-footnote footer.
lua/parley/define.lua:182:function M.managed_footnote_footer_range(lines)
lua/parley/define.lua:192:--- definition-footnote footer. The public footer range starts at the first
lua/parley/define.lua:197:function M.managed_footnote_content_start(lines)
lua/parley/define.lua:199:    local range = M.managed_footnote_footer_range(lines)
lua/parley/define.lua:242:function M.footnote_diagnostics(lines)
lua/parley/define.lua:313:--- Strip a final managed definition-footnote footer from text.
lua/parley/define.lua:316:function M.strip_definition_footnote_footer(text)
lua/parley/define.lua:318:    local start = M.managed_footnote_content_start(lines)
lua/parley/define.lua:359:--- definition in a managed footer.
lua/parley/highlighter.lua:270:    local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
lua/parley/highlighter.lua:303:            table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
lua/parley/highlighter.lua:471:    local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
lua/parley/highlighter.lua:478:            table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
lua/parley/highlighter.lua:747:    -- Managed definition-footnote footer (from the first `[^id]: ...`). It must be
lua/parley/highlighter.lua:750:        vim.api.nvim_set_hl(0, "ParleyFootnote", user_highlights.footnote)
lua/parley/highlighter.lua:752:        vim.api.nvim_set_hl(0, "ParleyFootnote", { link = "DiagnosticHint" })
lua/parley/highlighter.lua:1098:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1111:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1133:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1138:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1149:            skill_render.refresh_footnote_diagnostics(buf)
atlas/ui/highlights.md:4:Custom groups (`ParleyQuestion`, `ParleyFileReference`, `ParleyChatReference`, `ParleyThinking`, `ParleyAnnotation`, `ParleyReference`, `ParleyFootnote`, `ParleyPickerApproximateMatch`, `InterviewTimestamp`, `InterviewThought`) linked to standard Neovim groups. `ParleyReference` (default underline) marks drill-in `[referenced span]` brackets — see [chat/drill_in](../chat/drill_in.md). `ParleyFootnote` (default `DiagnosticHint`) marks managed definition-footnote footer lines.
atlas/ui/highlights.md:9:- Managed definition-footnote footers (from the first `[^id]: ...` line) use
atlas/ui/highlights.md:10:  `ParleyFootnote` in chat and markdown buffers instead of inheriting the active
atlas/chat/inline_define.md:6:(`ASIN[^asin]`), while the definition is stored in a managed footnote footer at
atlas/chat/inline_define.md:35:   and inserts/updates a final managed footnote footer via one buffer rewrite
atlas/chat/inline_define.md:39:   footnote diagnostics (`skill_render.refresh_footnote_diagnostics`), which
atlas/chat/inline_define.md:40:   parses the managed footer and sets INFO `vim.diagnostic` entries on matching
atlas/chat/inline_define.md:68:  `strip_definition_footnote_footer` / `footnote_diagnostics` (treat the first
atlas/chat/inline_define.md:69:  markdown footnote definition line as the managed footer boundary).
atlas/chat/inline_define.md:89:`chat_respond.build_messages` strips this managed footer from message strings
atlas/chat/inline_define.md:91:`define.footnote_diagnostics` uses the same footer detector to scan inline
atlas/chat/inline_define.md:123:- `skill_render.refresh_footnote_diagnostics` owns only diagnostics tagged
atlas/chat/inline_define.md:131:- `lua/parley/define.lua` — pure core (slice / context / format / footnote footer / diagnostics).
atlas/chat/inline_define.md:135:- `lua/parley/chat_respond.lua` — strips managed footnote footer from LLM messages.
lua/parley/chat_parser.lua:301:    local footnote_content_start = require("parley.define").managed_footnote_content_start(lines)
lua/parley/skills/review/diag_display.lua:175:    local footnote_diagnostics = {}
lua/parley/skills/review/diag_display.lua:179:                table.insert(footnote_diagnostics, diagnostic)
lua/parley/skills/review/diag_display.lua:186:    table.sort(footnote_diagnostics, function(a, b)
lua/parley/skills/review/diag_display.lua:189:    show_float(footnote_diagnostics)
lua/parley/config.lua:649:        footnote = nil, -- highlight for managed definition-footnote footer lines (default: links to DiagnosticHint)
tests/unit/define_spec.lua:152:    it("adds an inline footnote reference and appends a managed footer", function()
tests/unit/define_spec.lua:219:    it("strips only a final managed footnote footer", function()
tests/unit/define_spec.lua:228:        assert.equals("answer text", define.strip_definition_footnote_footer(text))
tests/unit/define_spec.lua:231:    it("preserves ordinary horizontal rules that are not managed footnote footers", function()
tests/unit/define_spec.lua:240:        assert.equals(text, define.strip_definition_footnote_footer(text))
tests/unit/define_spec.lua:243:    it("reports a dividerless managed footnote footer range from the first definition", function()
tests/unit/define_spec.lua:244:        local range = define.managed_footnote_footer_range({
tests/unit/define_spec.lua:253:    it("reports a divider-based managed footnote footer range from the first definition", function()
tests/unit/define_spec.lua:254:        local range = define.managed_footnote_footer_range({
tests/unit/define_spec.lua:266:        local start = define.managed_footnote_content_start({
tests/unit/define_spec.lua:278:        local start = define.managed_footnote_content_start({
tests/unit/define_spec.lua:287:    it("does not report ordinary horizontal rules as managed footnote footers", function()
tests/unit/define_spec.lua:288:        local range = define.managed_footnote_footer_range({
tests/unit/define_spec.lua:299:    it("keeps earlier horizontal-rule content and strips only the final managed footer", function()
tests/unit/define_spec.lua:318:        }, "\n"), define.strip_definition_footnote_footer(text))
tests/unit/define_spec.lua:321:    it("strips a final dividerless managed footnote footer", function()
tests/unit/define_spec.lua:328:        assert.equals("answer text", define.strip_definition_footnote_footer(text))
tests/unit/define_spec.lua:331:    it("extracts persisted footnote diagnostics from the managed footer", function()
tests/unit/define_spec.lua:332:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:350:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:380:        local diagnostics = define.footnote_diagnostics({
lua/parley/init.lua:1645:    skill_render.refresh_footnote_diagnostics(buf)
tests/integration/highlighting_spec.lua:165:describe("highlight_question_block: managed footnote footer", function()
tests/integration/highlighting_spec.lua:176:        assert.is_true(has_highlight(buf, 3, "ParleyFootnote"),
tests/integration/highlighting_spec.lua:177:            "Expected the managed footnote definition to use ParleyFootnote")
tests/integration/highlighting_spec.lua:528:        skill_render.refresh_footnote_diagnostics(buf)
tests/integration/highlighting_spec.lua:590:    it("renders managed footnote footers with ParleyFootnote in markdown buffers", function()
tests/integration/highlighting_spec.lua:617:            if mark.hl_group == "ParleyFootnote" then
tests/integration/highlighting_spec.lua:621:        assert.is_true(highlighted[2], "Expected markdown footnote definition to use ParleyFootnote")
lua/parley/skill_render.lua:114:function M.refresh_footnote_diagnostics(buf)
lua/parley/skill_render.lua:132:    for _, footnote in ipairs(define.footnote_diagnostics(lines)) do
lua/parley/chat_respond.lua:378:                text = define.strip_definition_footnote_footer(text)
lua/parley/chat_respond.lua:390:                local text = define.strip_definition_footnote_footer(read_block_text(k, b))
lua/parley/chat_respond.lua:409:                    table.insert(answer_blocks, { type = "text", text = define.strip_definition_footnote_footer(text) })
lua/parley/chat_respond.lua:427:                    table.insert(messages, { role = "user", content = define.strip_definition_footnote_footer(text) })
lua/parley/chat_respond.lua:616:                copy.text = define.strip_definition_footnote_footer(copy.text)
lua/parley/chat_respond.lua:702:                    local question_content = define.strip_definition_footnote_footer(exchange.question.content)
lua/parley/chat_respond.lua:807:                        table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.answer.content) })
lua/parley/chat_respond.lua:812:                        table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.summary.content) })
lua/parley/chat_respond.lua:820:                            table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.answer.content) })
tests/unit/parse_chat_spec.lua:667:    it("stops a final open question before a managed footnote footer", function()
tests/unit/build_messages_spec.lua:708:    it("strips managed definition footnote footers from user and assistant content", function()
tests/unit/build_messages_spec.lua:745:    it("preserves ordinary horizontal-rule content that is not a managed footer", function()
tests/unit/build_messages_spec.lua:772:    it("keeps earlier horizontal-rule content and strips only the final managed footer", function()
tests/unit/build_messages_spec.lua:1608:    it("strips managed footnote footers from live question and answer blocks", function()

exec
/bin/zsh -lc "nl -ba atlas/chat/inline_define.md | sed -n '60,100p' && nl -ba atlas/ui/highlights.md | sed -n '1,16p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
    60    watcher doesn't mistake it for a user edit.
    61
    62    ## Pure core vs IO shell (ARCH-PURE)
    63
    64    - **Pure** (`lua/parley/define.lua`, unit-tested with plain tables): `slice_selection`,
    65      `context_for_selection`, `format_definition`, `bracket_edit` (plans the `[term]`
    66      wrap as a legacy set_lines edit), `diagnostic_span_after_bracket` (legacy range
    67      mapping), `apply_definition_footnote` (durable footer transform), and
    68      `strip_definition_footnote_footer` / `footnote_diagnostics` (treat the first
    69      markdown footnote definition line as the managed footer boundary).
    70    - **IO shell** (`lua/parley/init.lua`): `define_visual`, `render_definition`;
    71      `lua/parley/buffer_edit.lua` owns the full-buffer footnote rewrite;
    72      `lua/parley/skill_render.lua` publishes footnote diagnostics; and
    73      `lua/parley/highlighter.lua` refreshes them from chat and markdown lifecycle
    74      hooks.
    75    - **External service** (Anthropic) exercised via the process-level fake reused
    76      from `skill_invoke_spec` (SSE tool-call injection).
    77
    78    ## Managed Footnote Footer
    79
    80    The footer begins at the first markdown footnote definition line:
    81
    82    ```markdown
    83    [^asin]: Amazon Standard Identification Number.
    84    ```
    85
    86    Older define edits may include a standalone `---` separator immediately before
    87    that first footnote definition; the stripper removes that optional separator
    88    along with the footer, but the canonical boundary is the `[^id]: ...` line.
    89    `chat_respond.build_messages` strips this managed footer from message strings
    90    before LLM submission, so durable definitions do not become prompt context.
    91    `define.footnote_diagnostics` uses the same footer detector to scan inline
    92    references before the footer and produce diagnostics for each matching `[^id]`.
    93
    94    ## Keybinding
    95
    96    `<M-CR>` was split out of `chat_shortcut_respond` into its own `chat_define`
    97    registry entry (a single registry entry maps every key×mode to one per-mode
    98    callback, so the split can't live inside `chat_respond`). The `chat_define`
    99    per-mode callback is `{ n=respond, i=respond, v=define_visual, x=define_visual }`
   100    — visual `<M-CR>` defines; normal/insert `<M-CR>` still responds; visual
     1    # Spec: Syntax Highlighting
     2
     3    ## Highlight Groups
     4    Custom groups (`ParleyQuestion`, `ParleyFileReference`, `ParleyChatReference`, `ParleyThinking`, `ParleyAnnotation`, `ParleyReference`, `ParleyFootnote`, `ParleyPickerApproximateMatch`, `InterviewTimestamp`, `InterviewThought`) linked to standard Neovim groups. `ParleyReference` (default underline) marks drill-in `[referenced span]` brackets — see [chat/drill_in](../chat/drill_in.md). `ParleyFootnote` (default `DiagnosticHint`) marks managed definition-footnote footer lines.
     5
     6    ## Key Behaviors
     7    - Applied via decoration providers with ephemeral extmarks per window viewport
     8    - Multi-window safe: independent redraw cache per window
     9    - Managed definition-footnote footers (from the first `[^id]: ...` line) use
    10      `ParleyFootnote` in chat and markdown buffers instead of inheriting the active
    11      chat exchange color.
    12    - `🌿:` lines auto-rendered with debounced topic lookup from referenced files
    13    - `chat_conceal_model_params`: optional header param concealment
    14    - UTC timestamps shaped like `YYYY-MM-DDTHH:MM:SSZ` get local-time INFO
    15      diagnostics in Parley chat and markdown buffers. The pure parser/formatter
    16      lives in `lua/parley/timezone_diagnostics.lua`; `highlighter.setup_buf_handler`

codex
The consumer sweep now shows the parser, highlighters, and prompt-stripping paths routed through `define`; no remaining `chat_parser` footnote predicate is present. I’m running the same focused verification and a diff whitespace check to confirm the evidence holds.
exec
/bin/zsh -lc 'git diff --check c481296d642c30cfbddbe1b5fd62c6265b397fe3..HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
exec
/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"' in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/unit/parse_chat_spec.lua"' in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"' in /Users/xianxu/workspace/parley.nvim
 succeeded in 1547ms:

LuaSnip: could not open log at /Users/xianxu/.local/state/nvim/luasnip.log. Not logging for this session.
Parley.nvim: Failed to open file for writing: /Users/xianxu/.local/share/nvim/parley/persisted/state.jsonScheduling: tests/unit/define_spec.lua

========================================
Testing:     /Users/xianxu/workspace/parley.nvim/tests/unit/define_spec.lua
[32mSuccess[0m    ||    define.slice_selection extracts a single-line span
[32mSuccess[0m    ||    define.slice_selection extracts a multi-line span joined with newline
[32mSuccess[0m    ||    define.slice_selection clamps an end column past line length
[32mSuccess[0m    ||    define.slice_selection returns empty string for a reversed/empty span
[32mSuccess[0m    ||    define.context_for_selection returns the enclosing exchange's lines (question..answer)
[32mSuccess[0m    ||    define.context_for_selection handles an answerless exchange (question only)
[32mSuccess[0m    ||    define.context_for_selection falls back to the whole buffer when outside any exchange
[32mSuccess[0m    ||    define.format_definition composes 'TERM — definition'
[32mSuccess[0m    ||    define.format_definition hard-wraps to width
[32mSuccess[0m    ||    define.format_definition passes nil width through to the shared diagnostic formatter
[32mSuccess[0m    ||    define.format_definition trims a nil/blank definition to a safe string
[32mSuccess[0m    ||    define.bracket_edit wraps a single-line span into a set_lines edit
[32mSuccess[0m    ||    define.bracket_edit clamps end col past line length
[32mSuccess[0m    ||    define.bracket_edit wraps a multi-line span
[32mSuccess[0m    ||    define.diagnostic_span_after_bracket anchors a single-line selection on the selected text after brackets
[32mSuccess[0m    ||    define.diagnostic_span_after_bracket anchors a multi-line selection without shifting the final line
[32mSuccess[0m    ||    define durable footnotes slugifies a definition term into a markdown footnote id
[32mSuccess[0m    ||    define durable footnotes adds an inline footnote reference and appends a managed footer
[32mSuccess[0m    ||    define durable footnotes updates an existing managed footnote instead of duplicating it
[32mSuccess[0m    ||    define durable footnotes updates an existing inline reference without duplicating it
[32mSuccess[0m    ||    define durable footnotes strips only a final managed footnote footer
[32mSuccess[0m    ||    define durable footnotes preserves ordinary horizontal rules that are not managed footnote footers
[32mSuccess[0m    ||    define durable footnotes reports a dividerless managed footnote footer range from the first definition
[32mSuccess[0m    ||    define durable footnotes reports a divider-based managed footnote footer range from the first definition
[32mSuccess[0m    ||    define durable footnotes reports the content trim start at an optional legacy divider
[32mSuccess[0m    ||    define durable footnotes reports the content trim start at the first definition without a divider
[32mSuccess[0m    ||    define durable footnotes does not report ordinary horizontal rules as managed footnote footers
[32mSuccess[0m    ||    define durable footnotes keeps earlier horizontal-rule content and strips only the final managed footer
[32mSuccess[0m    ||    define durable footnotes strips a final dividerless managed footnote footer
[32mSuccess[0m    ||    define durable footnotes extracts persisted footnote diagnostics from the managed footer
[32mSuccess[0m    ||    define durable footnotes extracts every inline reference to a managed footnote
[32mSuccess[0m    ||    define durable footnotes treats the first footnote definition as the footer even with trailing text

[32mSuccess: [0m    32
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
]111
 succeeded in 1536ms:

Parley.nvim: Failed to open file for writing: /Users/xianxu/.local/share/nvim/parley/persisted/state.jsonScheduling: tests/unit/parse_chat_spec.lua

========================================
Testing:     /Users/xianxu/workspace/parley.nvim/tests/unit/parse_chat_spec.lua
[32mSuccess[0m    ||    parse_chat: headers parses topic from header
[32mSuccess[0m    ||    parse_chat: headers parses file from header
[32mSuccess[0m    ||    parse_chat: headers parses provider from header
[32mSuccess[0m    ||    parse_chat: headers parses tags header as an array
[32mSuccess[0m    ||    parse_chat: headers returns empty exchanges for header-only chat
[32mSuccess[0m    ||    parse_chat: headers parses front matter style headers
[32mSuccess[0m    ||    parse_chat: headers captures repeated system_prompt+ values in order
[32mSuccess[0m    ||    parse_chat: headers keeps system_prompt override and system_prompt+ additions separately
[32mSuccess[0m    ||    parse_chat: headers maps legacy role/role+ headers to system_prompt keys
[32mSuccess[0m    ||    parse_chat: single exchange parses a question with no answer
[32mSuccess[0m    ||    parse_chat: single exchange parses multi-line question content
[32mSuccess[0m    ||    parse_chat: single exchange parses a question + answer exchange
[32mSuccess[0m    ||    parse_chat: single exchange records correct line_start for question (1-indexed)
[32mSuccess[0m    ||    parse_chat: multiple exchanges parses two exchanges in order
[32mSuccess[0m    ||    parse_chat: multiple exchanges parses three exchanges
[32mSuccess[0m    ||    parse_chat: summary and reasoning lines extracts 📝: summary from answer block
[32mSuccess[0m    ||    parse_chat: summary and reasoning lines extracts 🧠: reasoning from answer block
[32mSuccess[0m    ||    parse_chat: summary and reasoning lines extracts multi-line 🧠: reasoning terminated by blank line
[32mSuccess[0m    ||    parse_chat: summary and reasoning lines 📝: terminates reasoning even without blank-line separator
[32mSuccess[0m    ||    parse_chat: summary and reasoning lines 🔧: terminates reasoning and is parsed as tool_use
[32mSuccess[0m    ||    parse_chat: summary and reasoning lines singletons: one-line 🧠: still parses identically
[32mSuccess[0m    ||    parse_chat: summary and reasoning lines 🧠:[END] explicit terminator closes reasoning block
[32mSuccess[0m    ||    parse_chat: summary and reasoning lines 🧠:[END] block followed by tool_use parses correctly
[32mSuccess[0m    ||    parse_chat: summary and reasoning lines multiple 🧠: blocks within one answer accumulate into reasoning.content
[32mSuccess[0m    ||    parse_chat: summary and reasoning lines 🧠:[END] outside an active block is plain text, never opens one
[32mSuccess[0m    ||    parse_chat: summary and reasoning lines preserves indentation in continuation lines
[32mSuccess[0m    ||    parse_chat: summary and reasoning lines does not attach 📝: to question block
[32mSuccess[0m    ||    parse_chat: 🔒: local prefix excludes content after local_prefix from question content
[32mSuccess[0m    ||    parse_chat: 🔒: local prefix local prefix resets at next 💬: block
[32mSuccess[0m    ||    parse_chat: @@ file references collects @@ref@@ file reference on its own line
[32mSuccess[0m    ||    parse_chat: @@ file references collects multiple @@ref@@ references in same question
[32mSuccess[0m    ||    parse_chat: @@ file references collects inline @@ref@@ with local path
[32mSuccess[0m    ||    parse_chat: @@ file references collects @@url@@ URL reference with full URL including colons
[32mSuccess[0m    ||    parse_chat: @@ file references does not collect references from answer blocks
[32mSuccess[0m    ||    parse_chat: @@ file references collects inline @@url@@ on the same line as user prefix
[32mSuccess[0m    ||    parse_chat: @@ file references collects inline @@url@@ on a continuation line
[32mSuccess[0m    ||    parse_chat: @@ file references collects inline @@ref@@ with local path on continuation line
[32mSuccess[0m    ||    parse_chat: @@ file references collects inline @@ref@@ with relative path
[32mSuccess[0m    ||    parse_chat: @@ file references collects inline @@ref@@ with parent-relative path
[32mSuccess[0m    ||    parse_chat: @@ file references collects inline @@ref@@ with home-relative path
[32mSuccess[0m    ||    parse_chat: @@ file references does not collect unclosed @@ reference (no closing @@)
[32mSuccess[0m    ||    parse_chat: @@ file references collects two inline @@ref@@ on same line
[32mSuccess[0m    ||    parse_chat: edge cases stops a final open question before a managed footnote footer
[32mSuccess[0m    ||    parse_chat: edge cases stops a final open question before an optional legacy footnote divider
[32mSuccess[0m    ||    parse_chat: edge cases positions a final open-question answer above managed footnotes
[32mSuccess[0m    ||    parse_chat: edge cases stops a final open question before the first footnote definition even with trailing text
[32mSuccess[0m    ||    parse_chat: edge cases handles assistant message with no preceding user message
[32mSuccess[0m    ||    parse_chat: edge cases returns empty exchanges when body has only blank lines
[32mSuccess[0m    ||    parse_chat: 🌿: branch links first 🌿: line becomes parent_link
[32mSuccess[0m    ||    parse_chat: 🌿: branch links second 🌿: before first question becomes a child branch, not parent
[32mSuccess[0m    ||    parse_chat: 🌿: branch links 🌿: after an exchange is a child branch with correct after_exchange index
[32mSuccess[0m    ||    parse_chat: 🌿: branch links 🌿: lines are excluded from exchange content
[32mSuccess[0m    ||    parse_chat: 🌿: branch links no parent_link when no 🌿: lines present
[32mSuccess[0m    ||    parse_chat: 🌿: branch links handles 🌿: line with no topic

[32mSuccess: [0m    54
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
]111
 succeeded in 2159ms:

LuaSnip: could not open log at /Users/xianxu/.local/state/nvim/luasnip.log. Not logging for this session.
Parley.nvim: Failed to open file for writing: /Users/xianxu/.local/share/nvim/parley/persisted/state.jsonScheduling: tests/integration/highlighting_spec.lua

========================================
Testing:     /Users/xianxu/workspace/parley.nvim/tests/integration/highlighting_spec.lua
[32mSuccess[0m    ||    highlight_question_block: question lines applies Question highlight to 💬: line (row 0)
[32mSuccess[0m    ||    highlight_question_block: question lines applies ParleyQuestion highlight to continuation lines of a question block
[32mSuccess[0m    ||    highlight_question_block: question lines does NOT apply ParleyQuestion highlight to 🤖: answer lines
[32mSuccess[0m    ||    highlight_question_block: thinking lines applies Think highlight to 📝: summary line
[32mSuccess[0m    ||    highlight_question_block: thinking lines applies ParleyThinking highlight to 🧠: reasoning line
[32mSuccess[0m    ||    highlight_question_block: file reference lines applies FileLoading highlight to @@ file reference lines in a question block
[32mSuccess[0m    ||    highlight_question_block: file reference lines does NOT apply ParleyFileReference highlight to @@ lines outside question blocks
[32mSuccess[0m    ||    highlight_question_block: managed footnote footer uses a dedicated footnote highlight instead of open-question coloring
[32mSuccess[0m    ||    decoration provider cache keeps highlight caches isolated per window for the same buffer
[32mSuccess[0m    ||    decoration provider cache dims thinking-block continuation lines when viewport top falls between 🧠: and 🧠:[END]
[32mSuccess[0m    ||    decoration provider cache dims streaming thinking-block continuation lines before 🧠:[END] is emitted
[32mSuccess[0m    ||    decoration provider cache restores question highlights when redraw starts inside a long unanswered question
[32mSuccess[0m    ||    timezone diagnostics publishes local-time diagnostics in its own namespace and clears stale diagnostics
[32mSuccess[0m    ||    timezone diagnostics refreshes diagnostics for registered buffers on text changes
[32mSuccess[0m    ||    markdown footnote diagnostics publishes persisted managed footnotes as Parley diagnostics
[32mSuccess[0m    ||    markdown footnote diagnostics refreshes footnote diagnostics on markdown text changes without clearing other Parley diagnostics
[32mSuccess[0m    ||    markdown footnote diagnostics renders managed footnote footers with ParleyFootnote in markdown buffers
[32mSuccess[0m    ||    markdown chat reference rendering refreshes 🌿: branch lines with the chat topic in markdown buffers
[32mSuccess[0m    ||    markdown chat reference rendering does not rewrite 🌿: lines pointing to non-chat files in markdown buffers
[32mSuccess[0m    ||    markdown chat reference rendering refreshes from the updated topic in an open unsaved chat buffer

[32mSuccess: [0m    20
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
]111
codex
Focused unit and integration tests pass with the expected local Neovim startup warnings. I’m checking `build_messages` and lint as the issue log names those as part of the close evidence.
exec
/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/unit/build_messages_spec.lua"' in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc 'make lint' in /Users/xianxu/workspace/parley.nvim
 succeeded in 1502ms:
Error detected while processing /Users/xianxu/.config/nvim/init.lua:
Parser dir ' /Users/xianxu/.local/share/nvim/lazy/nvim-treesitter/parser ' should be read/write (see README on how to configure an alternative install location) /Users/xianxu/.local/share/nvim/lazy/nvim-treesitter/parser '
LuaSnip: could not open log at /Users/xianxu/.local/state/nvim/luasnip.log. Not logging for this session.
Parley.nvim: Failed to open file for writing: /Users/xianxu/.local/share/nvim/parley/persisted/state.jsonScheduling: tests/unit/build_messages_spec.lua

========================================
Testing:     /Users/xianxu/workspace/parley.nvim/tests/unit/build_messages_spec.lua
[32mSuccess[0m    ||    _build_messages: basic structure single exchange with no answer produces system + user message
[32mSuccess[0m    ||    _build_messages: basic structure adds neighborhood root context for tool-enabled agents
[32mSuccess[0m    ||    _build_messages: basic structure single exchange with answer produces system + user + assistant
[32mSuccess[0m    ||    _build_messages: memory truncation old exchanges beyond max_full_exchanges become placeholder text
[32mSuccess[0m    ||    _build_messages: summary usage when exchange has summary, uses summary instead of full answer
[32mSuccess[0m    ||    _build_messages: file references file reference injects system message with file content before user message
[32mSuccess[0m    ||    _build_messages: file references multiple file references accumulate file_content
[32mSuccess[0m    ||    _build_messages: file references file reference with directory pattern calls process_directory_pattern
[32mSuccess[0m    ||    _build_messages: Anthropic cache_control system prompt gets cache_control for anthropic provider
[32mSuccess[0m    ||    _build_messages: Anthropic cache_control system prompt does NOT get cache_control for openai provider
[32mSuccess[0m    ||    _build_messages: header config overrides config_max_full_exchanges header overrides config value
[32mSuccess[0m    ||    _build_messages: raw request mode when question contains typed YAML request fence, stores raw_payload
[32mSuccess[0m    ||    _build_messages: raw request mode ignores plain YAML fences without type:request metadata
[32mSuccess[0m    ||    _build_messages: raw request mode parses typed request fence regardless of raw_mode log toggles
[32mSuccess[0m    ||    _build_messages: raw request mode stores complete payload structure from typed request fence
[32mSuccess[0m    ||    _build_messages: raw request mode handles invalid YAML in typed request fence gracefully
[32mSuccess[0m    ||    _build_messages: raw request mode ignores response type fences and only matches request type
[32mSuccess[0m    ||    _build_messages: raw request mode builds normal messages when question has no typed fence
[32mSuccess[0m    ||    _build_messages: range filtering only includes exchanges where question.line_start >= start_index
[32mSuccess[0m    ||    _build_messages: range filtering only includes answers where answer.line_start <= end_index
[32mSuccess[0m    ||    _build_messages: durable definition footnotes strips managed definition footnote footers from user and assistant content
[32mSuccess[0m    ||    _build_messages: durable definition footnotes preserves ordinary horizontal-rule content that is not a managed footer
[32mSuccess[0m    ||    _build_messages: durable definition footnotes keeps earlier horizontal-rule content and strips only the final managed footer
[32mSuccess[0m    ||    _build_messages: whitespace trimming trims leading and trailing whitespace from all message content
[32mSuccess[0m    ||    _build_messages: system_prompt+ header appends appends system_prompt+ to selected/default system prompt
[32mSuccess[0m    ||    _build_messages: system_prompt+ header appends uses system_prompt override then appends system_prompt+ values
[32mSuccess[0m    ||    _build_messages: system_prompt+ header appends supports legacy role and role+ aliases
[32mSuccess[0m    ||    _build_messages: file references with preserved answer when exchange has file references, answer is summarized even if should_preserve
[32mSuccess[0m    ||    _build_messages: remote file references uses resolved_remote_content for URL references
[32mSuccess[0m    ||    _build_messages: remote file references uses cached-miss placeholder for unresolved remote URL references
[32mSuccess[0m    ||    _build_messages: content_blocks with tool round-trips emits a single flat assistant message when content_blocks has only text
[32mSuccess[0m    ||    _build_messages: content_blocks with tool round-trips emits assistant-with-content-blocks + user-with-tool_result for a single round
[32mSuccess[0m    ||    _build_messages: content_blocks with tool round-trips emits multiple rounds of tool_use → tool_result correctly
[32mSuccess[0m    ||    _build_messages: content_blocks with tool round-trips emits is_error=true tool_results correctly
[32mSuccess[0m    ||    _build_messages: content_blocks with tool round-trips includes the CURRENT exchange's partial answer when it has tool blocks (tool-loop recursion)
[32mSuccess[0m    ||    _build_messages: content_blocks with tool round-trips does NOT include the current exchange's answer when it has NO tool blocks (vanilla resubmit)
[32mSuccess[0m    ||    _build_messages: synthetic_system_prompt anthropic: emits user-with-content-blocks + assistant ack instead of system
[32mSuccess[0m    ||    _build_messages: synthetic_system_prompt openai (no cache_control): plain string user content + assistant ack
[32mSuccess[0m    ||    _build_messages: synthetic_system_prompt custom ack overrides the default
[32mSuccess[0m    ||    _build_messages: synthetic_system_prompt flag = false produces the default single system message
[32mSuccess[0m    ||    _emit_content_blocks_as_messages: dangling tool_use invariant (#155) synthesizes an error result for a single dangling tool_use
[32mSuccess[0m    ||    _emit_content_blocks_as_messages: dangling tool_use invariant (#155) keeps trailing text in the assistant run and still synthesizes (dangling-then-text)
[32mSuccess[0m    ||    _emit_content_blocks_as_messages: dangling tool_use invariant (#155) synthesizes only for the dangling call in a partial parallel resolution
[32mSuccess[0m    ||    _emit_content_blocks_as_messages: dangling tool_use invariant (#155) leaves a matched single round unchanged (no synthetic added)
[32mSuccess[0m    ||    _emit_content_blocks_as_messages: dangling tool_use invariant (#155) emits a single assistant message for text-only blocks
[32mSuccess[0m    ||    _emit_content_blocks_as_messages: dangling tool_use invariant (#155) coerces empty tool input to a JSON object, not an array
[32mSuccess[0m    ||    _build_messages: dangling tool_use synthesized on the parse path (#155) emits a synthetic error tool_result for an unmatched tool_use in a past exchange
[32mSuccess[0m    ||    build_messages_from_model: dangling tool_use synthesized on the live path (#155) emits a synthetic error tool_result for a dangling tool_use read from the buffer
[32mSuccess[0m    ||    build_messages_from_model: durable definition footnotes strips managed footnote footers from live question and answer blocks
[32mSuccess[0m    ||    _emit_content_blocks_as_messages: orphan tool_result dropped (#156) drops an orphan-only tool_result (no preceding tool_use)
[32mSuccess[0m    ||    _emit_content_blocks_as_messages: orphan tool_result dropped (#156) drops an orphan tool_result after an unrelated matched round
[32mSuccess[0m    ||    _emit_content_blocks_as_messages: orphan tool_result dropped (#156) drops an orphan interleaved before a real result, keeps the real one
[32mSuccess[0m    ||    _emit_content_blocks_as_messages: orphan tool_result dropped (#156) keeps a matched result when text sits between the call and the result
[32mSuccess[0m    ||    _emit_content_blocks_as_messages: orphan tool_result dropped (#156) drops a duplicate tool_result (second result for the same id)
[32mSuccess[0m    ||    _emit_content_blocks_as_messages: orphan tool_result dropped (#156) dangling tool_use + orphan result: synthetic for the dangling, drop the orphan
[32mSuccess[0m    ||    _emit_content_blocks_as_messages: orphan tool_result dropped (#156) does not split surrounding text into consecutive assistant turns [text, orphan, text]

[32mSuccess: [0m    56
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
]111
 succeeded in 2042ms:
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

codex
```verdict
verdict: SHIP
confidence: high
```

The rework addresses the prior blocker: `chat_parser.lua` now derives footer trimming from `define.managed_footnote_content_start`, which itself derives from `managed_footnote_footer_range`. The issue’s dividerless footer behavior is covered across the pure helper, parser/model placement, diagnostics, highlighting, and prompt stripping paths.

1. Strengths:
- [lua/parley/define.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/define.lua:182) defines the canonical footer range as first footnote definition through EOF.
- [lua/parley/chat_parser.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/chat_parser.lua:301) removes the shadow scanner and uses the shared define helper.
- [tests/unit/parse_chat_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/unit/parse_chat_spec.lua:667) covers dividerless, legacy divider, placement, and trailing-text parser behavior.
- Atlas docs were updated in `atlas/chat/inline_define.md` and `atlas/ui/highlights.md`.

2. Critical findings:
- None.

3. Important findings:
- None.

4. Minor findings:
- None.

5. Test coverage notes:
- Passed: `git diff --check c481296d642c30cfbddbe1b5fd62c6265b397fe3..HEAD`
- Passed: `PlenaryBustedFile tests/unit/define_spec.lua`
- Passed: `PlenaryBustedFile tests/unit/parse_chat_spec.lua`
- Passed: `PlenaryBustedFile tests/integration/highlighting_spec.lua`
- Passed: `PlenaryBustedFile tests/unit/build_messages_spec.lua`
- Passed: `make lint`
- Neovim emitted existing local startup/write warnings, but all targeted specs passed.

6. Architectural notes for upcoming work:
- ARCH-DRY: pass. The previous duplicated parser logic is gone.
- ARCH-PURE: pass. Boundary detection remains pure in `define.lua`; IO/UI callers consume it.
- ARCH-PURPOSE: pass. The issue’s purpose is delivered across the consumers that motivated the change.

7. Plan revision recommendations:
- None.
tokens used
99,500
```verdict
verdict: SHIP
confidence: high
```

The rework addresses the prior blocker: `chat_parser.lua` now derives footer trimming from `define.managed_footnote_content_start`, which itself derives from `managed_footnote_footer_range`. The issue’s dividerless footer behavior is covered across the pure helper, parser/model placement, diagnostics, highlighting, and prompt stripping paths.

1. Strengths:
- [lua/parley/define.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/define.lua:182) defines the canonical footer range as first footnote definition through EOF.
- [lua/parley/chat_parser.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/chat_parser.lua:301) removes the shadow scanner and uses the shared define helper.
- [tests/unit/parse_chat_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/unit/parse_chat_spec.lua:667) covers dividerless, legacy divider, placement, and trailing-text parser behavior.
- Atlas docs were updated in `atlas/chat/inline_define.md` and `atlas/ui/highlights.md`.

2. Critical findings:
- None.

3. Important findings:
- None.

4. Minor findings:
- None.

5. Test coverage notes:
- Passed: `git diff --check c481296d642c30cfbddbe1b5fd62c6265b397fe3..HEAD`
- Passed: `PlenaryBustedFile tests/unit/define_spec.lua`
- Passed: `PlenaryBustedFile tests/unit/parse_chat_spec.lua`
- Passed: `PlenaryBustedFile tests/integration/highlighting_spec.lua`
- Passed: `PlenaryBustedFile tests/unit/build_messages_spec.lua`
- Passed: `make lint`
- Neovim emitted existing local startup/write warnings, but all targeted specs passed.

6. Architectural notes for upcoming work:
- ARCH-DRY: pass. The previous duplicated parser logic is gone.
- ARCH-PURE: pass. Boundary detection remains pure in `define.lua`; IO/UI callers consume it.
- ARCH-PURPOSE: pass. The issue’s purpose is delivered across the consumers that motivated the change.

7. Plan revision recommendations:
- None.
