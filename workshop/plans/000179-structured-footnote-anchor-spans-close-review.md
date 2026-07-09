# Boundary Review — parley.nvim#179 (whole-issue close)

| field | value |
|-------|-------|
| issue | 179 — structured footnote anchor spans |
| repo | parley.nvim |
| issue file | workshop/issues/000179-structured-footnote-anchor-spans.md |
| boundary | whole-issue close |
| milestone | — |
| window | 28225e3c6fe71d1b82e17b2b4f10d8aab0babaf5..HEAD |
| command | sdlc close --issue 179 |
| reviewer | codex |
| timestamp | 2026-07-09T11:05:04-07:00 |
| verdict | FIX-THEN-SHIP |

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
session id: 019f4807-b39f-7171-be6c-75d22a0139c5
--------
user
# Code review — the one SDLC boundary review

You are conducting a fresh-context code review at a development boundary —
whole-issue close — in the **parley.nvim** repository.

- repository: parley.nvim   (root: /Users/xianxu/workspace/parley.nvim)
- issue:      parley.nvim#179   (file: workshop/issues/000179-structured-footnote-anchor-spans.md)
- window:     Base: 28225e3c6fe71d1b82e17b2b4f10d8aab0babaf5   Head: HEAD

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
index 1a14c80..9fc66f0 100644
--- a/atlas/chat/inline_define.md
+++ b/atlas/chat/inline_define.md
@@ -91,6 +91,21 @@ before LLM submission, so durable definitions do not become prompt context.
 `define.footnote_diagnostics` uses the same footer detector to scan inline
 references before the footer and produce diagnostics for each matching `[^id]`.

+For persisted multi-word anchors, a footnote definition may start with a quoted
+or backquoted display term:
+
+```markdown
+Advertising Cost of Sales[^acos]
+
+[^acos]: "Advertising Cost of Sales". Ratio of ad spend to sales revenue.
+```
+
+On reload, `define.footnote_diagnostics` uses that leading display term to find
+the nearest matching phrase before `[^acos]`; the resulting span drives both the
+floating definition trigger and the rehydrated inline highlight. If the phrase is
+not present before the reference, the diagnostic falls back to the historical
+single-token span immediately before `[^id]`.
+
 ## Keybinding

 `<M-CR>` was split out of `chat_shortcut_respond` into its own `chat_define`
diff --git a/lua/parley/define.lua b/lua/parley/define.lua
index 733cbd0..97f3a83 100644
--- a/lua/parley/define.lua
+++ b/lua/parley/define.lua
@@ -223,6 +223,21 @@ local function parse_footnote_line(line)
     return id, definition
 end

+local function parse_structured_definition(definition)
+    local term, body = definition:match('^"([^"]+)"%s*%.?%s*(.*)$')
+    if not term then
+        term, body = definition:match("^`([^`]+)`%s*%.?%s*(.*)$")
+    end
+    if not term then
+        return nil, definition
+    end
+    body = trim(body)
+    if body == "" then
+        body = "(no definition)"
+    end
+    return term, body
+end
+
 local function is_term_byte(ch)
     return ch:match("[%w_-]") ~= nil
 end
@@ -235,6 +250,36 @@ local function expand_term_start(line, ref_start)
     return start
 end

+local function is_structured_anchor_suffix(text)
+    return trim(text):match("^[\"'”’%]%)%}]*$") ~= nil
+end
+
+local function structured_term_start(line, ref_start, term)
+    if not term or term == "" then
+        return nil
+    end
+    local best_start, best_end
+    local search = 1
+    while search < ref_start do
+        local start_pos, end_pos = line:find(term, search, true)
+        if not start_pos or start_pos >= ref_start then
+            break
+        end
+        if end_pos < ref_start then
+            local suffix = line:sub(end_pos + 1, ref_start - 1)
+            if is_structured_anchor_suffix(suffix) then
+                best_start = start_pos
+                best_end = end_pos
+            end
+        end
+        search = start_pos + 1
+    end
+    if not best_start then
+        return nil
+    end
+    return best_start, best_end
+end
+
 --- Derive persisted definition diagnostics from inline footnote references and
 --- the final managed definition footer.
 --- @param lines string[]
@@ -250,7 +295,11 @@ function M.footnote_diagnostics(lines)
     for i = footer, #lines do
         local id, definition = parse_footnote_line(lines[i] or "")
         if id then
-            definitions[id] = definition
+            local term, body = parse_structured_definition(definition)
+            definitions[id] = {
+                definition = body,
+                structured_term = term,
+            }
         end
     end

@@ -263,14 +312,15 @@ function M.footnote_diagnostics(lines)
             if not ref_start then
                 break
             end
-            local definition = definitions[id]
-            if definition then
-                local term_start = expand_term_start(line, ref_start)
-                local term = line:sub(term_start, ref_start - 1)
+            local footnote = definitions[id]
+            if footnote then
+                local structured_start = structured_term_start(line, ref_start, footnote.structured_term)
+                local term_start = structured_start or expand_term_start(line, ref_start)
+                local term = footnote.structured_term or line:sub(term_start, ref_start - 1)
                 table.insert(diagnostics, {
                     id = id,
                     term = term ~= "" and term or nil,
-                    definition = definition,
+                    definition = footnote.definition,
                     lnum = lnum - 1,
                     col = term_start - 1,
                     end_lnum = lnum - 1,
diff --git a/tests/integration/highlighting_spec.lua b/tests/integration/highlighting_spec.lua
index 32ce6b1..b450a5d 100644
--- a/tests/integration/highlighting_spec.lua
+++ b/tests/integration/highlighting_spec.lua
@@ -558,6 +558,27 @@ describe("markdown footnote diagnostics", function()
         assert.equals("DiffChange", marks[1][4].hl_group)
     end)

+    it("rehydrates a multi-word structured footnote anchor highlight", function()
+        local skill_render = require("parley.skill_render")
+        local buf = vim.api.nvim_create_buf(false, true)
+        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
+            "We optimize against Advertising Cost of Sales[^acos] in the policy.",
+            "",
+            [=[[^acos]: "Advertising Cost of Sales". Ratio of ad spend to sales revenue.]=],
+        })
+
+        skill_render.refresh_footnote_diagnostics(buf)
+
+        local hl_ns = vim.api.nvim_get_namespaces().parley_footnote_hl
+        local marks = vim.api.nvim_buf_get_extmarks(buf, hl_ns, 0, -1, { details = true })
+        assert.equals(1, #marks)
+        assert.equals(0, marks[1][2])
+        assert.equals(20, marks[1][3])
+        assert.equals(0, marks[1][4].end_row)
+        assert.equals(52, marks[1][4].end_col)
+        assert.equals("DiffChange", marks[1][4].hl_group)
+    end)
+
     it("refreshes footnote diagnostics on markdown text changes without clearing other Parley diagnostics", function()
         local skill_render = require("parley.skill_render")
         local ns = skill_render.diag_namespace()
diff --git a/tests/unit/define_spec.lua b/tests/unit/define_spec.lua
index 373f204..140068d 100644
--- a/tests/unit/define_spec.lua
+++ b/tests/unit/define_spec.lua
@@ -346,6 +346,78 @@ describe("define durable footnotes", function()
         } }, diagnostics)
     end)

+    it("uses a leading quoted footnote term to span a multi-word persisted anchor", function()
+        local diagnostics = define.footnote_diagnostics({
+            "We optimize against Advertising Cost of Sales[^acos] in the policy.",
+            "",
+            [=[[^acos]: "Advertising Cost of Sales". Ratio of ad spend to sales revenue.]=],
+        })
+
+        assert.are.same({ {
+            id = "acos",
+            term = "Advertising Cost of Sales",
+            definition = "Ratio of ad spend to sales revenue.",
+            lnum = 0,
+            col = 20,
+            end_lnum = 0,
+            end_col = 52,
+        } }, diagnostics)
+    end)
+
+    it("uses a leading backquoted footnote term to span a multi-word persisted anchor", function()
+        local diagnostics = define.footnote_diagnostics({
+            "We optimize against Advertising Cost of Sales[^acos] in the policy.",
+            "",
+            "[^acos]: `Advertising Cost of Sales`. Ratio of ad spend to sales revenue.",
+        })
+
+        assert.are.same({ {
+            id = "acos",
+            term = "Advertising Cost of Sales",
+            definition = "Ratio of ad spend to sales revenue.",
+            lnum = 0,
+            col = 20,
+            end_lnum = 0,
+            end_col = 52,
+        } }, diagnostics)
+    end)
+
+    it("matches a structured term already enclosed in body quotes", function()
+        local diagnostics = define.footnote_diagnostics({
+            [=[He called it "Advertising Cost of Sales"[^acos] in the transcript.]=],
+            "",
+            [=[[^acos]: "Advertising Cost of Sales". Ratio of ad spend to sales revenue.]=],
+        })
+
+        assert.are.same({ {
+            id = "acos",
+            term = "Advertising Cost of Sales",
+            definition = "Ratio of ad spend to sales revenue.",
+            lnum = 0,
+            col = 14,
+            end_lnum = 0,
+            end_col = 47,
+        } }, diagnostics)
+    end)
+
+    it("falls back to contiguous-token anchors when the structured term is not before the reference", function()
+        local diagnostics = define.footnote_diagnostics({
+            "We optimize against ACOS[^acos] in the policy.",
+            "",
+            [=[[^acos]: "Advertising Cost of Sales". Ratio of ad spend to sales revenue.]=],
+        })
+
+        assert.are.same({ {
+            id = "acos",
+            term = "Advertising Cost of Sales",
+            definition = "Ratio of ad spend to sales revenue.",
+            lnum = 0,
+            col = 20,
+            end_lnum = 0,
+            end_col = 31,
+        } }, diagnostics)
+    end)
+
     it("extracts every inline reference to a managed footnote", function()
         local diagnostics = define.footnote_diagnostics({
             "ASIN[^asin] first, then SKU[^asin] second",


codex
I’ll use the required session-start skill plus the SDLC/review context, then inspect the issue, diff, and relevant code/tests read-only before issuing the machine-readable verdict.
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

codex
I’ve loaded the SDLC pointer. Next I’m checking the repo’s current workflow contract, lessons, issue file, and changed files so the review is anchored in the actual tracker state and code.
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
/bin/zsh -lc "sed -n '1,260p' workshop/issues/000179-structured-footnote-anchor-spans.md" in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc "sed -n '1,220p' workshop/lessons.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
---
id: 000179
status: working
deps: []
github_issue:
created: 2026-07-09
updated: 2026-07-09
estimate_hours: 0.31
started: 2026-07-09T10:52:37-07:00
---

# structured footnote anchor spans

## Problem

Reloaded definition footnotes can show the floating definition window, but the
span highlight is only reliable for the current single-token inference before
`[^id]`. Multi-word terms such as `Advertising Cost of Sales[^acos]` collapse to
`Sales[^acos]`, and users need a markup-light way to persist the intended anchor
span across reloads.

## Spec

Definition footnotes may carry a structured display term at the start of the
footer definition:

```markdown
Advertising Cost of Sales[^acos]

[^acos]: "Advertising Cost of Sales". Ratio of ad spend to sales revenue.
```

or:

```markdown
Advertising Cost of Sales[^acos]

[^acos]: `Advertising Cost of Sales`. Ratio of ad spend to sales revenue.
```

When `define.footnote_diagnostics` sees a leading quoted or backquoted phrase in
the matching footnote definition, it uses that phrase to locate the nearest exact
body text before `[^id]`, allowing only whitespace or closing quote/bracket
characters between the phrase and the reference. The span covers that phrase
through the footnote reference. If the phrase is absent before the reference,
diagnostics fall back to the existing contiguous-token inference. The diagnostic
message should still use the human phrase as the term label and the remaining
definition body as the definition text.

The persisted reload path must continue to derive the floating-window trigger and
inline highlight from the diagnostic span (ARCH-DRY, ARCH-PURE, ARCH-PURPOSE).
No additional inline body markup is required.

## Done when

- A footnote whose definition starts with `"Advertising Cost of Sales". ...`
  produces a diagnostic/highlight span covering
  `Advertising Cost of Sales[^acos]` on reload.
- A footnote whose definition starts with `` `Advertising Cost of Sales`. ... ``
  behaves the same way.
- If the structured phrase is not immediately before the reference, the old
  single-token fallback remains unchanged.
- Persisted footnote highlights use the same span as the floating-window trigger.

## Plan

- [x] Add failing pure diagnostics tests for leading quoted/backquoted structured
  terms and fallback behavior.
- [x] Add a reload highlight regression that asserts the multi-word structured
  span is highlighted.
- [x] Implement structured term extraction and nearest-before-reference matching
  in `lua/parley/define.lua`.
- [x] Update atlas docs for the structured footnote convention.
- [x] Run focused tests plus lint/diff checks.

## Estimate

Derived via `estimate-logic-v3.1` against the repo-local calibration source from
`sdlc estimate-source` (stale but canonical for this repo).

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.03 impl=0.00
item: lua-neovim design=0.05 impl=0.18
item: atlas-docs design=0.01 impl=0.02
item: milestone-review design=0.00 impl=0.02
total: 0.31
```

## Log

### 2026-07-09

- User clarified that multi-word definition anchors should be persisted without
  adding extra body markup. Scope uses a leading quoted/backquoted phrase in the
  footnote definition as the source of truth for reload spans while preserving
  the current single-token fallback (ARCH-DRY, ARCH-PURE, ARCH-PURPOSE).
- TDD red: new pure diagnostics tests and reload highlight regression failed
  because persisted footnotes still expanded only the contiguous token before
  `[^id]` and kept the structured quote in the definition text.
- Implemented structured leading quote/backquote parsing in `define.lua`; the
  parsed term now provides the diagnostic label and nearest matching pre-ref
  span, which `skill_render.refresh_footnote_diagnostics` already uses for both
  float trigger and reload highlight.
- Verification: `make lint` passed; `nvim --headless -c "PlenaryBustedFile
  tests/unit/define_spec.lua"` passed; `nvim --headless -c "PlenaryBustedFile
  tests/integration/highlighting_spec.lua"` passed; scoped `git diff --check`
  passed. Full `make test` still fails only at the known parallel-run
  `tests/unit/tools_builtin_find_spec.lua` case; that spec passes directly.

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

exec
/bin/zsh -lc 'git diff --stat 28225e3c6fe71d1b82e17b2b4f10d8aab0babaf5..HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
 atlas/chat/inline_define.md                        | 15 ++++
 lua/parley/define.lua                              | 62 +++++++++++++--
 tests/integration/highlighting_spec.lua            | 21 ++++++
 tests/unit/define_spec.lua                         | 72 ++++++++++++++++++
 .../000179-structured-footnote-anchor-spans.md     | 88 +++++++++++++++++++++-
 5 files changed, 249 insertions(+), 9 deletions(-)

codex
The issue spec is narrow: structured quote/backquote terms should drive the diagnostic span, while fallback still uses the old contiguous-token anchor. I’m now checking the exact implementation line numbers and running the focused verification paths rather than trusting the log.
exec
/bin/zsh -lc "nl -ba lua/parley/define.lua | sed -n '200,345p'" in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc "nl -ba tests/unit/define_spec.lua | sed -n '320,445p'" in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc "nl -ba atlas/chat/inline_define.md | sed -n '80,120p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
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
    94    For persisted multi-word anchors, a footnote definition may start with a quoted
    95    or backquoted display term:
    96
    97    ```markdown
    98    Advertising Cost of Sales[^acos]
    99
   100    [^acos]: "Advertising Cost of Sales". Ratio of ad spend to sales revenue.
   101    ```
   102
   103    On reload, `define.footnote_diagnostics` uses that leading display term to find
   104    the nearest matching phrase before `[^acos]`; the resulting span drives both the
   105    floating definition trigger and the rehydrated inline highlight. If the phrase is
   106    not present before the reference, the diagnostic falls back to the historical
   107    single-token span immediately before `[^id]`.
   108
   109    ## Keybinding
   110
   111    `<M-CR>` was split out of `chat_shortcut_respond` into its own `chat_define`
   112    registry entry (a single registry entry maps every key×mode to one per-mode
   113    callback, so the split can't live inside `chat_respond`). The `chat_define`
   114    per-mode callback is `{ n=respond, i=respond, v=define_visual, x=define_visual }`
   115    — visual `<M-CR>` defines; normal/insert `<M-CR>` still responds; visual
   116    `<C-g><C-g>` keeps the line-scoped resubmit. The v/x callbacks `<Esc>`-commit
   117    the `'<`/`'>` marks before reading `getpos`.
   118
   119    ## Read-only invoke seam (`opts.no_reload`)
   120

 succeeded in 0ms:
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
   226    local function parse_structured_definition(definition)
   227        local term, body = definition:match('^"([^"]+)"%s*%.?%s*(.*)$')
   228        if not term then
   229            term, body = definition:match("^`([^`]+)`%s*%.?%s*(.*)$")
   230        end
   231        if not term then
   232            return nil, definition
   233        end
   234        body = trim(body)
   235        if body == "" then
   236            body = "(no definition)"
   237        end
   238        return term, body
   239    end
   240
   241    local function is_term_byte(ch)
   242        return ch:match("[%w_-]") ~= nil
   243    end
   244
   245    local function expand_term_start(line, ref_start)
   246        local start = ref_start
   247        while start > 1 and is_term_byte(line:sub(start - 1, start - 1)) do
   248            start = start - 1
   249        end
   250        return start
   251    end
   252
   253    local function is_structured_anchor_suffix(text)
   254        return trim(text):match("^[\"'”’%]%)%}]*$") ~= nil
   255    end
   256
   257    local function structured_term_start(line, ref_start, term)
   258        if not term or term == "" then
   259            return nil
   260        end
   261        local best_start, best_end
   262        local search = 1
   263        while search < ref_start do
   264            local start_pos, end_pos = line:find(term, search, true)
   265            if not start_pos or start_pos >= ref_start then
   266                break
   267            end
   268            if end_pos < ref_start then
   269                local suffix = line:sub(end_pos + 1, ref_start - 1)
   270                if is_structured_anchor_suffix(suffix) then
   271                    best_start = start_pos
   272                    best_end = end_pos
   273                end
   274            end
   275            search = start_pos + 1
   276        end
   277        if not best_start then
   278            return nil
   279        end
   280        return best_start, best_end
   281    end
   282
   283    --- Derive persisted definition diagnostics from inline footnote references and
   284    --- the final managed definition footer.
   285    --- @param lines string[]
   286    --- @return table[] diagnostics with 0-based columns
   287    function M.footnote_diagnostics(lines)
   288        lines = lines or {}
   289        local footer = managed_footer_start(lines)
   290        if not footer then
   291            return {}
   292        end
   293
   294        local definitions = {}
   295        for i = footer, #lines do
   296            local id, definition = parse_footnote_line(lines[i] or "")
   297            if id then
   298                local term, body = parse_structured_definition(definition)
   299                definitions[id] = {
   300                    definition = body,
   301                    structured_term = term,
   302                }
   303            end
   304        end
   305
   306        local diagnostics = {}
   307        for lnum = 1, footer - 1 do
   308            local line = lines[lnum] or ""
   309            local search = 1
   310            while true do
   311                local ref_start, ref_end, id = line:find("%[%^([^%]]+)%]", search)
   312                if not ref_start then
   313                    break
   314                end
   315                local footnote = definitions[id]
   316                if footnote then
   317                    local structured_start = structured_term_start(line, ref_start, footnote.structured_term)
   318                    local term_start = structured_start or expand_term_start(line, ref_start)
   319                    local term = footnote.structured_term or line:sub(term_start, ref_start - 1)
   320                    table.insert(diagnostics, {
   321                        id = id,
   322                        term = term ~= "" and term or nil,
   323                        definition = footnote.definition,
   324                        lnum = lnum - 1,
   325                        col = term_start - 1,
   326                        end_lnum = lnum - 1,
   327                        end_col = ref_end,
   328                    })
   329                end
   330                search = ref_end + 1
   331            end
   332        end
   333        return diagnostics
   334    end
   335
   336    local function split_text_lines(text)
   337        text = text or ""
   338        local lines = {}
   339        local start = 1
   340        while true do
   341            local nl = text:find("\n", start, true)
   342            if not nl then
   343                lines[#lines + 1] = text:sub(start)
   344                break
   345            end

 succeeded in 0ms:
   320
   321        it("strips a final dividerless managed footnote footer", function()
   322            local text = table.concat({
   323                "answer text",
   324                "",
   325                "[^asin]: Amazon Standard Identification Number.",
   326            }, "\n")
   327
   328            assert.equals("answer text", define.strip_definition_footnote_footer(text))
   329        end)
   330
   331        it("extracts persisted footnote diagnostics from the managed footer", function()
   332            local diagnostics = define.footnote_diagnostics({
   333                "here is ASIN[^asin] in context",
   334                "",
   335                "[^asin]: Amazon Standard Identification Number.",
   336            })
   337
   338            assert.are.same({ {
   339                id = "asin",
   340                term = "ASIN",
   341                definition = "Amazon Standard Identification Number.",
   342                lnum = 0,
   343                col = 8,
   344                end_lnum = 0,
   345                end_col = 19,
   346            } }, diagnostics)
   347        end)
   348
   349        it("uses a leading quoted footnote term to span a multi-word persisted anchor", function()
   350            local diagnostics = define.footnote_diagnostics({
   351                "We optimize against Advertising Cost of Sales[^acos] in the policy.",
   352                "",
   353                [=[[^acos]: "Advertising Cost of Sales". Ratio of ad spend to sales revenue.]=],
   354            })
   355
   356            assert.are.same({ {
   357                id = "acos",
   358                term = "Advertising Cost of Sales",
   359                definition = "Ratio of ad spend to sales revenue.",
   360                lnum = 0,
   361                col = 20,
   362                end_lnum = 0,
   363                end_col = 52,
   364            } }, diagnostics)
   365        end)
   366
   367        it("uses a leading backquoted footnote term to span a multi-word persisted anchor", function()
   368            local diagnostics = define.footnote_diagnostics({
   369                "We optimize against Advertising Cost of Sales[^acos] in the policy.",
   370                "",
   371                "[^acos]: `Advertising Cost of Sales`. Ratio of ad spend to sales revenue.",
   372            })
   373
   374            assert.are.same({ {
   375                id = "acos",
   376                term = "Advertising Cost of Sales",
   377                definition = "Ratio of ad spend to sales revenue.",
   378                lnum = 0,
   379                col = 20,
   380                end_lnum = 0,
   381                end_col = 52,
   382            } }, diagnostics)
   383        end)
   384
   385        it("matches a structured term already enclosed in body quotes", function()
   386            local diagnostics = define.footnote_diagnostics({
   387                [=[He called it "Advertising Cost of Sales"[^acos] in the transcript.]=],
   388                "",
   389                [=[[^acos]: "Advertising Cost of Sales". Ratio of ad spend to sales revenue.]=],
   390            })
   391
   392            assert.are.same({ {
   393                id = "acos",
   394                term = "Advertising Cost of Sales",
   395                definition = "Ratio of ad spend to sales revenue.",
   396                lnum = 0,
   397                col = 14,
   398                end_lnum = 0,
   399                end_col = 47,
   400            } }, diagnostics)
   401        end)
   402
   403        it("falls back to contiguous-token anchors when the structured term is not before the reference", function()
   404            local diagnostics = define.footnote_diagnostics({
   405                "We optimize against ACOS[^acos] in the policy.",
   406                "",
   407                [=[[^acos]: "Advertising Cost of Sales". Ratio of ad spend to sales revenue.]=],
   408            })
   409
   410            assert.are.same({ {
   411                id = "acos",
   412                term = "Advertising Cost of Sales",
   413                definition = "Ratio of ad spend to sales revenue.",
   414                lnum = 0,
   415                col = 20,
   416                end_lnum = 0,
   417                end_col = 31,
   418            } }, diagnostics)
   419        end)
   420
   421        it("extracts every inline reference to a managed footnote", function()
   422            local diagnostics = define.footnote_diagnostics({
   423                "ASIN[^asin] first, then SKU[^asin] second",
   424                "",
   425                "---",
   426                "",
   427                "[^asin]: Amazon Standard Identification Number.",
   428            })
   429
   430            assert.are.equal(2, #diagnostics)
   431            assert.are.same({
   432                id = "asin",
   433                term = "ASIN",
   434                definition = "Amazon Standard Identification Number.",
   435                lnum = 0,
   436                col = 0,
   437                end_lnum = 0,
   438                end_col = 11,
   439            }, diagnostics[1])
   440            assert.are.same({
   441                id = "asin",
   442                term = "SKU",
   443                definition = "Amazon Standard Identification Number.",
   444                lnum = 0,
   445                col = 24,

exec
/bin/zsh -lc "nl -ba tests/integration/highlighting_spec.lua | sed -n '540,590p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   540        it("rehydrates the inline term/reference highlight for persisted footnotes", function()
   541            local skill_render = require("parley.skill_render")
   542            local buf = vim.api.nvim_create_buf(false, true)
   543            vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
   544                "Use EC2[^ec2] for virtual machines.",
   545                "",
   546                "[^ec2]: EC2 is Elastic Compute Cloud.",
   547            })
   548
   549            skill_render.refresh_footnote_diagnostics(buf)
   550
   551            local hl_ns = vim.api.nvim_get_namespaces().parley_footnote_hl
   552            local marks = vim.api.nvim_buf_get_extmarks(buf, hl_ns, 0, -1, { details = true })
   553            assert.equals(1, #marks)
   554            assert.equals(0, marks[1][2])
   555            assert.equals(4, marks[1][3])
   556            assert.equals(0, marks[1][4].end_row)
   557            assert.equals(13, marks[1][4].end_col)
   558            assert.equals("DiffChange", marks[1][4].hl_group)
   559        end)
   560
   561        it("rehydrates a multi-word structured footnote anchor highlight", function()
   562            local skill_render = require("parley.skill_render")
   563            local buf = vim.api.nvim_create_buf(false, true)
   564            vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
   565                "We optimize against Advertising Cost of Sales[^acos] in the policy.",
   566                "",
   567                [=[[^acos]: "Advertising Cost of Sales". Ratio of ad spend to sales revenue.]=],
   568            })
   569
   570            skill_render.refresh_footnote_diagnostics(buf)
   571
   572            local hl_ns = vim.api.nvim_get_namespaces().parley_footnote_hl
   573            local marks = vim.api.nvim_buf_get_extmarks(buf, hl_ns, 0, -1, { details = true })
   574            assert.equals(1, #marks)
   575            assert.equals(0, marks[1][2])
   576            assert.equals(20, marks[1][3])
   577            assert.equals(0, marks[1][4].end_row)
   578            assert.equals(52, marks[1][4].end_col)
   579            assert.equals("DiffChange", marks[1][4].hl_group)
   580        end)
   581
   582        it("refreshes footnote diagnostics on markdown text changes without clearing other Parley diagnostics", function()
   583            local skill_render = require("parley.skill_render")
   584            local ns = skill_render.diag_namespace()
   585            local buf = vim.api.nvim_create_buf(false, true)
   586            vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), buf)
   587            parley._parley_bufs[buf] = "markdown"
   588            vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
   589                "no footnote yet",
   590            })

exec
/bin/zsh -lc 'git diff --check 28225e3c6fe71d1b82e17b2b4f10d8aab0babaf5..HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
exec
/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"' in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"' in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc 'make lint' in /Users/xianxu/workspace/parley.nvim
 succeeded in 1511ms:

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
[32mSuccess[0m    ||    define durable footnotes uses a leading quoted footnote term to span a multi-word persisted anchor
[32mSuccess[0m    ||    define durable footnotes uses a leading backquoted footnote term to span a multi-word persisted anchor
[32mSuccess[0m    ||    define durable footnotes matches a structured term already enclosed in body quotes
[32mSuccess[0m    ||    define durable footnotes falls back to contiguous-token anchors when the structured term is not before the reference
[32mSuccess[0m    ||    define durable footnotes extracts every inline reference to a managed footnote
[32mSuccess[0m    ||    define durable footnotes treats the first footnote definition as the footer even with trailing text

[32mSuccess: [0m    36
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
]111
 succeeded in 2000ms:
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

 succeeded in 2235ms:

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
[32mSuccess[0m    ||    markdown footnote diagnostics rehydrates the inline term/reference highlight for persisted footnotes
[32mSuccess[0m    ||    markdown footnote diagnostics rehydrates a multi-word structured footnote anchor highlight
[32mSuccess[0m    ||    markdown footnote diagnostics refreshes footnote diagnostics on markdown text changes without clearing other Parley diagnostics
[32mSuccess[0m    ||    markdown footnote diagnostics renders managed footnote footers with ParleyFootnote in markdown buffers
[32mSuccess[0m    ||    markdown chat reference rendering refreshes 🌿: branch lines with the chat topic in markdown buffers
[32mSuccess[0m    ||    markdown chat reference rendering does not rewrite 🌿: lines pointing to non-chat files in markdown buffers
[32mSuccess[0m    ||    markdown chat reference rendering refreshes from the updated topic in an open unsaved chat buffer

[32mSuccess: [0m    22
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
]111
codex
The focused unit/integration specs and lint pass in this checkout. I’m doing one wider suite check now because the issue log explicitly says full `make test` is red only for a known parallel-run case; that claim affects the close evidence.
exec
/bin/zsh -lc 'make test' in /Users/xianxu/workspace/parley.nvim
 exited 2 in 5260ms:
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
PASS: tests/unit/anthropic_tool_decode_spec.lua
PASS: tests/unit/ancestor_messages_spec.lua
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
PASS: tests/unit/custom_prompts_spec.lua
PASS: tests/unit/chat_dirs_spec.lua
PASS: tests/unit/define_spec.lua
PASS: tests/unit/discovery_base_spec.lua
PASS: tests/unit/discovery_descriptor_spec.lua
PASS: tests/unit/discovery_matcher_spec.lua
PASS: tests/unit/discovery_registry_spec.lua
PASS: tests/unit/discovery_merge_spec.lua
PASS: tests/unit/chat_slug_resolve_spec.lua
PASS: tests/unit/dispatcher_query_spec.lua
PASS: tests/unit/drill_in_spec.lua
PASS: tests/unit/exchange_clipboard_spec.lua
PASS: tests/unit/exchange_model_spec.lua
PASS: tests/unit/dispatcher_spec.lua
PASS: tests/unit/finder_sticky_spec.lua
PASS: tests/unit/exporter_tree_spec.lua
PASS: tests/unit/file_tracker_spec.lua
PASS: tests/unit/get_week_number_spec.lua
PASS: tests/unit/helper_io_spec.lua
PASS: tests/unit/float_picker_spec.lua
PASS: tests/unit/helper_spec.lua
PASS: tests/unit/highlighter_spec.lua
PASS: tests/unit/issue_vocabulary_spec.lua
PASS: tests/unit/inline_branch_spec.lua
PASS: tests/unit/issue_finder_spec.lua
PASS: tests/unit/log_emit_spec.lua
PASS: tests/unit/logger_spec.lua
PASS: tests/unit/memory_prefs_spec.lua
PASS: tests/unit/markdown_draft_block_spec.lua
PASS: tests/unit/issues_spec.lua
PASS: tests/unit/neighborhood_spec.lua
PASS: tests/unit/config_tools_spec.lua
PASS: tests/unit/oauth_spec.lua
PASS: tests/unit/obfuscate_spec.lua
PASS: tests/unit/note_finder_logic_spec.lua
PASS: tests/unit/outline_spec.lua
PASS: tests/unit/open_chat_reference_spec.lua
PASS: tests/unit/parse_chat_spec.lua
PASS: tests/unit/picker_items_spec.lua
PASS: tests/unit/parley_harness_spec.lua
PASS: tests/unit/parley_harness_golden_spec.lua
PASS: tests/unit/process_directory_pattern_spec.lua
PASS: tests/unit/progress_spec.lua
PASS: tests/unit/parse_at_reference_spec.lua
PASS: tests/unit/provider_params_spec.lua
PASS: tests/unit/raw_log_spec.lua
PASS: tests/unit/keybindings_spec.lua
PASS: tests/unit/providers_pre_query_spec.lua
PASS: tests/unit/render_buffer_spec.lua
PASS: tests/unit/pure_functions_spec.lua
PASS: tests/unit/render_buffer_roundtrip_spec.lua
PASS: tests/unit/remote_references_spec.lua
PASS: tests/unit/render_spec.lua
PASS: tests/unit/review_journal_spec.lua
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
PASS: tests/unit/tools_builtin_read_file_spec.lua
PASS: tests/unit/tools_builtin_registered_spec.lua
PASS: tests/unit/tools_registry_spec.lua
===FAIL: tests/unit/tools_builtin_find_spec.lua===
  Scheduling: tests/unit/tools_builtin_find_spec.lua

  ========================================
  Testing:     /Users/xianxu/workspace/parley.nvim/tests/unit/tools_builtin_find_spec.lua
  [32mSuccess[0m    ||    find tool finds files by structured name and type fields
  [32mSuccess[0m    ||    find tool does not accept a raw flags escape hatch
  [32mSuccess[0m    ||    find tool rejects action and write predicates as unknown structured fields
  [31mFail[0m    ||    find tool treats command substitution text in name as data
              ...space/parley.nvim/tests/unit/tools_builtin_find_spec.lua:30: Expected objects to be the same.
              Passed in:
              (boolean) true
              Expected:
              (boolean) false

              stack traceback:
                  ...space/parley.nvim/tests/unit/tools_builtin_find_spec.lua:30: in function <...space/parley.nvim/tests/unit/tools_builtin_find_spec.lua:28>


  [32mSuccess: [0m    3
  [31mFailed : [0m    1
  [31mErrors : [0m    0
  ========================================
  Tests Failed. Exit: 1
PASS: tests/unit/tools_serialize_spec.lua
PASS: tests/unit/tools_types_spec.lua
PASS: tests/unit/tools_dispatcher_spec.lua
PASS: tests/unit/vault_spec.lua
PASS: tests/unit/vision_spec.lua
PASS: tests/unit/tools_builtin_chat_history_search_spec.lua
PASS: tests/unit/super_repo_spec.lua
PASS: tests/unit/tools_builtin_ack_spec.lua

=== Failed unit test files ===
tests/unit/tools_builtin_find_spec.lua
make: *** [test-unit] Error 1

exec
/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/unit/tools_builtin_find_spec.lua"' in /Users/xianxu/workspace/parley.nvim
 succeeded in 1461ms:

LuaSnip: could not open log at /Users/xianxu/.local/state/nvim/luasnip.log. Not logging for this session.
Parley.nvim: Failed to open file for writing: /Users/xianxu/.local/share/nvim/parley/persisted/state.jsonScheduling: tests/unit/tools_builtin_find_spec.lua

========================================
Testing:     /Users/xianxu/workspace/parley.nvim/tests/unit/tools_builtin_find_spec.lua
[32mSuccess[0m    ||    find tool finds files by structured name and type fields
[32mSuccess[0m    ||    find tool does not accept a raw flags escape hatch
[32mSuccess[0m    ||    find tool rejects action and write predicates as unknown structured fields
[32mSuccess[0m    ||    find tool treats command substitution text in name as data

[32mSuccess: [0m    4
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
]111
exec
/bin/zsh -lc 'git diff --name-only 28225e3c6fe71d1b82e17b2b4f10d8aab0babaf5..HEAD' in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc 'git diff --unified=80 28225e3c6fe71d1b82e17b2b4f10d8aab0babaf5..HEAD -- workshop/issues/000179-structured-footnote-anchor-spans.md' in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc 'git diff --unified=80 28225e3c6fe71d1b82e17b2b4f10d8aab0babaf5..HEAD -- lua/parley/define.lua' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
atlas/chat/inline_define.md
lua/parley/define.lua
tests/integration/highlighting_spec.lua
tests/unit/define_spec.lua
workshop/issues/000179-structured-footnote-anchor-spans.md

 succeeded in 0ms:
diff --git a/workshop/issues/000179-structured-footnote-anchor-spans.md b/workshop/issues/000179-structured-footnote-anchor-spans.md
index 12d06ee..62756f5 100644
--- a/workshop/issues/000179-structured-footnote-anchor-spans.md
+++ b/workshop/issues/000179-structured-footnote-anchor-spans.md
@@ -1,28 +1,110 @@
 ---
 id: 000179
 status: working
 deps: []
 github_issue:
 created: 2026-07-09
 updated: 2026-07-09
-estimate_hours:
+estimate_hours: 0.31
 started: 2026-07-09T10:52:37-07:00
 ---

 # structured footnote anchor spans

 ## Problem

+Reloaded definition footnotes can show the floating definition window, but the
+span highlight is only reliable for the current single-token inference before
+`[^id]`. Multi-word terms such as `Advertising Cost of Sales[^acos]` collapse to
+`Sales[^acos]`, and users need a markup-light way to persist the intended anchor
+span across reloads.
+
 ## Spec

+Definition footnotes may carry a structured display term at the start of the
+footer definition:
+
+```markdown
+Advertising Cost of Sales[^acos]
+
+[^acos]: "Advertising Cost of Sales". Ratio of ad spend to sales revenue.
+```
+
+or:
+
+```markdown
+Advertising Cost of Sales[^acos]
+
+[^acos]: `Advertising Cost of Sales`. Ratio of ad spend to sales revenue.
+```
+
+When `define.footnote_diagnostics` sees a leading quoted or backquoted phrase in
+the matching footnote definition, it uses that phrase to locate the nearest exact
+body text before `[^id]`, allowing only whitespace or closing quote/bracket
+characters between the phrase and the reference. The span covers that phrase
+through the footnote reference. If the phrase is absent before the reference,
+diagnostics fall back to the existing contiguous-token inference. The diagnostic
+message should still use the human phrase as the term label and the remaining
+definition body as the definition text.
+
+The persisted reload path must continue to derive the floating-window trigger and
+inline highlight from the diagnostic span (ARCH-DRY, ARCH-PURE, ARCH-PURPOSE).
+No additional inline body markup is required.
+
 ## Done when

--
+- A footnote whose definition starts with `"Advertising Cost of Sales". ...`
+  produces a diagnostic/highlight span covering
+  `Advertising Cost of Sales[^acos]` on reload.
+- A footnote whose definition starts with `` `Advertising Cost of Sales`. ... ``
+  behaves the same way.
+- If the structured phrase is not immediately before the reference, the old
+  single-token fallback remains unchanged.
+- Persisted footnote highlights use the same span as the floating-window trigger.

 ## Plan

-- [ ]
+- [x] Add failing pure diagnostics tests for leading quoted/backquoted structured
+  terms and fallback behavior.
+- [x] Add a reload highlight regression that asserts the multi-word structured
+  span is highlighted.
+- [x] Implement structured term extraction and nearest-before-reference matching
+  in `lua/parley/define.lua`.
+- [x] Update atlas docs for the structured footnote convention.
+- [x] Run focused tests plus lint/diff checks.
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
+item: lua-neovim design=0.05 impl=0.18
+item: atlas-docs design=0.01 impl=0.02
+item: milestone-review design=0.00 impl=0.02
+total: 0.31
+```

 ## Log

 ### 2026-07-09
+
+- User clarified that multi-word definition anchors should be persisted without
+  adding extra body markup. Scope uses a leading quoted/backquoted phrase in the
+  footnote definition as the source of truth for reload spans while preserving
+  the current single-token fallback (ARCH-DRY, ARCH-PURE, ARCH-PURPOSE).
+- TDD red: new pure diagnostics tests and reload highlight regression failed
+  because persisted footnotes still expanded only the contiguous token before
+  `[^id]` and kept the structured quote in the definition text.
+- Implemented structured leading quote/backquote parsing in `define.lua`; the
+  parsed term now provides the diagnostic label and nearest matching pre-ref
+  span, which `skill_render.refresh_footnote_diagnostics` already uses for both
+  float trigger and reload highlight.
+- Verification: `make lint` passed; `nvim --headless -c "PlenaryBustedFile
+  tests/unit/define_spec.lua"` passed; `nvim --headless -c "PlenaryBustedFile
+  tests/integration/highlighting_spec.lua"` passed; scoped `git diff --check`
+  passed. Full `make test` still fails only at the known parallel-run
+  `tests/unit/tools_builtin_find_spec.lua` case; that spec passes directly.

 succeeded in 0ms:
diff --git a/lua/parley/define.lua b/lua/parley/define.lua
index 733cbd0..97f3a83 100644
--- a/lua/parley/define.lua
+++ b/lua/parley/define.lua
@@ -146,208 +146,258 @@ function M.footnote_id(term)
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

 --- Locate the line where user-authored content should stop before a managed
 --- definition-footnote footer. The public footer range starts at the first
 --- `[^id]:` line, but old buffers may still have a preceding `---` separator
 --- that should be stripped from prompts/messages too.
 --- @param lines string[]|nil
 --- @return integer|nil 1-based inclusive start line to trim from content
 function M.managed_footnote_content_start(lines)
     lines = lines or {}
     local range = M.managed_footnote_footer_range(lines)
     if not range then
         return nil
     end
     local start = range.start_line
     local before = start - 1
     while before > 0 and trim(lines[before]) == "" do
         before = before - 1
     end
     if before > 0 and is_divider(lines[before]) then
         start = before
     end
     return start
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

+local function parse_structured_definition(definition)
+    local term, body = definition:match('^"([^"]+)"%s*%.?%s*(.*)$')
+    if not term then
+        term, body = definition:match("^`([^`]+)`%s*%.?%s*(.*)$")
+    end
+    if not term then
+        return nil, definition
+    end
+    body = trim(body)
+    if body == "" then
+        body = "(no definition)"
+    end
+    return term, body
+end
+
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

+local function is_structured_anchor_suffix(text)
+    return trim(text):match("^[\"'”’%]%)%}]*$") ~= nil
+end
+
+local function structured_term_start(line, ref_start, term)
+    if not term or term == "" then
+        return nil
+    end
+    local best_start, best_end
+    local search = 1
+    while search < ref_start do
+        local start_pos, end_pos = line:find(term, search, true)
+        if not start_pos or start_pos >= ref_start then
+            break
+        end
+        if end_pos < ref_start then
+            local suffix = line:sub(end_pos + 1, ref_start - 1)
+            if is_structured_anchor_suffix(suffix) then
+                best_start = start_pos
+                best_end = end_pos
+            end
+        end
+        search = start_pos + 1
+    end
+    if not best_start then
+        return nil
+    end
+    return best_start, best_end
+end
+
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
-            definitions[id] = definition
+            local term, body = parse_structured_definition(definition)
+            definitions[id] = {
+                definition = body,
+                structured_term = term,
+            }
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
-            local definition = definitions[id]
-            if definition then
-                local term_start = expand_term_start(line, ref_start)
-                local term = line:sub(term_start, ref_start - 1)
+            local footnote = definitions[id]
+            if footnote then
+                local structured_start = structured_term_start(line, ref_start, footnote.structured_term)
+                local term_start = structured_start or expand_term_start(line, ref_start)
+                local term = footnote.structured_term or line:sub(term_start, ref_start - 1)
                 table.insert(diagnostics, {
                     id = id,
                     term = term ~= "" and term or nil,
-                    definition = definition,
+                    definition = footnote.definition,
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
     local start = M.managed_footnote_content_start(lines)
     if not start then
         return text or ""
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

codex
The full suite reproduces the tracker’s stated baseline: `make test` fails in the parallel run at `tests/unit/tools_builtin_find_spec.lua`, while that file passes directly. I don’t see that failure as caused by this diff, so I’m completing the review against the changed surface now.
exec
/bin/zsh -lc 'rg -n "footnote_diagnostics|refresh_footnote_diagnostics|diagnostic_span|parley_footnote_hl" lua/parley tests' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
tests/integration/highlighting_spec.lua:528:        skill_render.refresh_footnote_diagnostics(buf)
tests/integration/highlighting_spec.lua:549:        skill_render.refresh_footnote_diagnostics(buf)
tests/integration/highlighting_spec.lua:551:        local hl_ns = vim.api.nvim_get_namespaces().parley_footnote_hl
tests/integration/highlighting_spec.lua:570:        skill_render.refresh_footnote_diagnostics(buf)
tests/integration/highlighting_spec.lua:572:        local hl_ns = vim.api.nvim_get_namespaces().parley_footnote_hl
lua/parley/define.lua:122:function M.diagnostic_span_after_bracket(l1, c1, l2, c2)
lua/parley/define.lua:287:function M.footnote_diagnostics(lines)
lua/parley/define.lua:417:--- @return table { lines: string[], id: string, definition: string, diagnostic_span: table }
lua/parley/define.lua:444:        diagnostic_span = {
lua/parley/highlighter.lua:1098:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1111:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1133:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1138:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1149:            skill_render.refresh_footnote_diagnostics(buf)
tests/unit/define_spec.lua:123:describe("define.diagnostic_span_after_bracket", function()
tests/unit/define_spec.lua:125:        local span = define.diagnostic_span_after_bracket(3, 9, 3, 12)
tests/unit/define_spec.lua:135:        local span = define.diagnostic_span_after_bracket(1, 7, 3, 3)
tests/unit/define_spec.lua:167:        assert.are.same({ lnum = 0, col = 8, end_lnum = 0, end_col = 19 }, result.diagnostic_span)
tests/unit/define_spec.lua:216:        assert.are.same({ lnum = 0, col = 0, end_lnum = 0, end_col = 11 }, result.diagnostic_span)
tests/unit/define_spec.lua:332:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:350:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:368:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:386:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:404:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:422:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:452:        local diagnostics = define.footnote_diagnostics({
lua/parley/init.lua:1643:    local diag_span = e.diagnostic_span
lua/parley/init.lua:1645:    skill_render.refresh_footnote_diagnostics(buf)
lua/parley/skills/review/diag_display.lua:175:    local footnote_diagnostics = {}
lua/parley/skills/review/diag_display.lua:179:                table.insert(footnote_diagnostics, diagnostic)
lua/parley/skills/review/diag_display.lua:186:    table.sort(footnote_diagnostics, function(a, b)
lua/parley/skills/review/diag_display.lua:189:    show_float(footnote_diagnostics)
lua/parley/skill_render.lua:12:local FOOTNOTE_HL_NS = "parley_footnote_hl"
lua/parley/skill_render.lua:130:function M.refresh_footnote_diagnostics(buf)
lua/parley/skill_render.lua:149:    for _, footnote in ipairs(define.footnote_diagnostics(lines)) do

exec
/bin/zsh -lc 'rg -n "footnote|define|definition|<M-CR>|Advertising|gray|grey|pop|float" README.md atlas lua tests' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
README.md:118:- `<M-CR>` respond (normal/insert); **visual-select a phrase + `<M-CR>`** → inline term definition — adds a markdown footnote reference/footer and shows a centered diagnostic float, honoring `:ToggleWebSearch` for unfamiliar terms
atlas/issues/issue-management.md:20:- `:ParleyIssueFinder` (`<C-y>f`): float picker with status badges and 2-state view cycling — `<Tab>` (natural key; `<C-a>` kept for back-compat) toggles between `issues` (all of `workshop/issues/`, done items visible — the default, sorted by the existing status/ID order) and `history` (archived items in `workshop/history/`, sorted by file modification time ascending so the newest archive row sits closest to the bottom-anchored prompt) (#158, superseding the tri-state all/active/all+history from #152)
tests/fixtures/anthropic_tool_use_request.json:15:      "content": "Please read the file at lua/parley/init.lua and tell me the first function definition you see."
lua/parley/define.lua:1:-- Pure core for the inline term-definition feature (#161).
lua/parley/define.lua:3:-- are unit-tested directly (tests/unit/define_spec.lua). The IO shell
lua/parley/define.lua:4:-- (define_visual / render_definition) lives in lua/parley/init.lua.
lua/parley/define.lua:66:--- Compose the diagnostic message ("TERM — definition"), hard-wrapped to width.
lua/parley/define.lua:70:--- @param definition string|nil
lua/parley/define.lua:73:function M.format_definition(term, definition, width)
lua/parley/define.lua:74:    definition = definition or ""
lua/parley/define.lua:75:    definition = (definition:gsub("%s+$", "")) -- parens → keep only the string
lua/parley/define.lua:76:    if definition == "" then
lua/parley/define.lua:77:        definition = "(no definition)"
lua/parley/define.lua:79:    local head = tostring(term or "") .. " — " .. definition
lua/parley/define.lua:138:--- Convert a term into a stable markdown footnote id.
lua/parley/define.lua:141:function M.footnote_id(term)
lua/parley/define.lua:146:        id = "definition"
lua/parley/define.lua:152:--- @param definition string|nil
lua/parley/define.lua:154:function M.format_footnote_line(id, definition)
lua/parley/define.lua:155:    definition = trim(definition)
lua/parley/define.lua:156:    if definition == "" then
lua/parley/define.lua:157:        definition = "(no definition)"
lua/parley/define.lua:159:    return string.format("[^%s]: %s", id, definition)
lua/parley/define.lua:166:local function is_footnote_line(line)
lua/parley/define.lua:172:        if is_footnote_line(line) then
lua/parley/define.lua:179:--- Locate the final managed definition-footnote footer.
lua/parley/define.lua:182:function M.managed_footnote_footer_range(lines)
lua/parley/define.lua:192:--- definition-footnote footer. The public footer range starts at the first
lua/parley/define.lua:197:function M.managed_footnote_content_start(lines)
lua/parley/define.lua:199:    local range = M.managed_footnote_footer_range(lines)
lua/parley/define.lua:214:local function parse_footnote_line(line)
lua/parley/define.lua:215:    local id, definition = trim(line):match("^%[%^([^%]]+)%]:%s*(.-)%s*$")
lua/parley/define.lua:219:    definition = trim(definition)
lua/parley/define.lua:220:    if definition == "" then
lua/parley/define.lua:221:        definition = "(no definition)"
lua/parley/define.lua:223:    return id, definition
lua/parley/define.lua:226:local function parse_structured_definition(definition)
lua/parley/define.lua:227:    local term, body = definition:match('^"([^"]+)"%s*%.?%s*(.*)$')
lua/parley/define.lua:229:        term, body = definition:match("^`([^`]+)`%s*%.?%s*(.*)$")
lua/parley/define.lua:232:        return nil, definition
lua/parley/define.lua:236:        body = "(no definition)"
lua/parley/define.lua:283:--- Derive persisted definition diagnostics from inline footnote references and
lua/parley/define.lua:284:--- the final managed definition footer.
lua/parley/define.lua:287:function M.footnote_diagnostics(lines)
lua/parley/define.lua:294:    local definitions = {}
lua/parley/define.lua:296:        local id, definition = parse_footnote_line(lines[i] or "")
lua/parley/define.lua:298:            local term, body = parse_structured_definition(definition)
lua/parley/define.lua:299:            definitions[id] = {
lua/parley/define.lua:300:                definition = body,
lua/parley/define.lua:315:            local footnote = definitions[id]
lua/parley/define.lua:316:            if footnote then
lua/parley/define.lua:317:                local structured_start = structured_term_start(line, ref_start, footnote.structured_term)
lua/parley/define.lua:319:                local term = footnote.structured_term or line:sub(term_start, ref_start - 1)
lua/parley/define.lua:323:                    definition = footnote.definition,
lua/parley/define.lua:363:--- Strip a final managed definition-footnote footer from text.
lua/parley/define.lua:366:function M.strip_definition_footnote_footer(text)
lua/parley/define.lua:368:    local start = M.managed_footnote_content_start(lines)
lua/parley/define.lua:382:local function replace_or_append_footnote(lines, id, definition)
lua/parley/define.lua:385:    local footnote_line = M.format_footnote_line(id, definition)
lua/parley/define.lua:390:                out[i] = footnote_line
lua/parley/define.lua:394:        out[#out + 1] = footnote_line
lua/parley/define.lua:404:    out[#out + 1] = footnote_line
lua/parley/define.lua:408:--- Insert a markdown footnote reference after the selected text and store the
lua/parley/define.lua:409:--- definition in a managed footer.
lua/parley/define.lua:416:--- @param definition string|nil
lua/parley/define.lua:417:--- @return table { lines: string[], id: string, definition: string, diagnostic_span: table }
lua/parley/define.lua:418:function M.apply_definition_footnote(lines, l1, c1, l2, c2, term, definition)
lua/parley/define.lua:419:    local id = M.footnote_id(term)
lua/parley/define.lua:435:    out = replace_or_append_footnote(out, id, definition)
lua/parley/define.lua:436:    local normalized_definition = trim(definition)
lua/parley/define.lua:437:    if normalized_definition == "" then
lua/parley/define.lua:438:        normalized_definition = "(no definition)"
lua/parley/define.lua:443:        definition = normalized_definition,
lua/parley/agent_picker.lua:2:-- Provides a floating window UI for selecting LLM agents
lua/parley/agent_picker.lua:6:local float_picker = require("parley.float_picker")
lua/parley/agent_picker.lua:54:-- Create a floating picker to select an LLM agent
lua/parley/agent_picker.lua:58:    float_picker.open({
atlas/index.md:15:- [Inline Term Definition](chat/inline_define.md): Visual-select a phrase + `<M-CR>` → concise context-aware definition as a managed footnote diagnostic rehydrated for markdown buffers (the `define` skill + `emit_definition` tool; honors `:ToggleWebSearch`).
atlas/index.md:44:- [UI Pickers](ui/pickers.md): Custom floating-window pickers for agents, prompts, finder, and outline navigation.
lua/parley/provider_params.lua:16:-- Schema definitions
atlas/notes/finder.md:3:`:ParleyNoteFinder` (`<C-n>f`) — floating picker for notes across all configured note roots (excludes `templates/`).
lua/parley/issue_finder.lua:247:    _parley.float_picker.open({
lua/parley/skill_picker.lua:3:-- Opens a float picker for selecting a skill and its arguments.
lua/parley/skill_picker.lua:32:    local float_picker = _parley.float_picker
lua/parley/skill_picker.lua:58:    float_picker.open({
lua/parley/skill_picker.lua:76:    local float_picker = _parley.float_picker
lua/parley/skill_picker.lua:91:    float_picker.open({
atlas/traceability.yaml:88:  chat/inline_define:
atlas/traceability.yaml:90:      - lua/parley/define.lua
atlas/traceability.yaml:92:      - lua/parley/skills/define/init.lua
atlas/traceability.yaml:93:      - lua/parley/tools/builtin/emit_definition.lua
atlas/traceability.yaml:100:      - tests/unit/define_spec.lua
atlas/traceability.yaml:101:      - tests/integration/define_spec.lua
atlas/traceability.yaml:231:      - lua/parley/float_picker.lua
atlas/traceability.yaml:457:      - lua/parley/float_picker.lua
atlas/traceability.yaml:466:      - tests/unit/float_picker_spec.lua
lua/parley/providers.lua:1311:-- web_search / web_fetch already populated by existing code paths).
lua/parley/providers.lua:1321:---@param tool_definitions ToolDefinition[]|nil
lua/parley/providers.lua:1323:function M.anthropic_encode_tools(tool_definitions)
lua/parley/providers.lua:1325:    for _, def in ipairs(tool_definitions or {}) do
lua/parley/providers.lua:1337:function M.openai_encode_tools(_tool_definitions)
lua/parley/providers.lua:1343:function M.googleai_encode_tools(_tool_definitions)
lua/parley/providers.lua:1349:function M.ollama_encode_tools(_tool_definitions)
lua/parley/providers.lua:1357:---@param tool_definitions ToolDefinition[]
lua/parley/providers.lua:1359:function M.cliproxyapi_encode_tools(tool_definitions, model_name)
lua/parley/providers.lua:1364:    return M.anthropic_encode_tools(tool_definitions)
lua/parley/highlighter.lua:270:    local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
lua/parley/highlighter.lua:448:--   * footnote refs                 — `[^1]`
lua/parley/highlighter.lua:471:    local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
lua/parley/highlighter.lua:668:    -- Check for user-defined highlight settings
lua/parley/highlighter.lua:674:        -- Use user-defined highlighting if provided
lua/parley/highlighter.lua:747:    -- Managed definition-footnote footer (from the first `[^id]: ...`). It must be
lua/parley/highlighter.lua:749:    if user_highlights.footnote then
lua/parley/highlighter.lua:750:        vim.api.nvim_set_hl(0, "ParleyFootnote", user_highlights.footnote)
lua/parley/highlighter.lua:797:    -- Reverse + bold makes `🤖<…>` pop against any colorscheme so the user
lua/parley/highlighter.lua:807:    -- are too muted in many colorschemes — often a grey "filler" delete and a
lua/parley/highlighter.lua:1098:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1111:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1133:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1138:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1149:            skill_render.refresh_footnote_diagnostics(buf)
tests/perf_chat_finder.lua:198:    -- 2) Warm scan (cache populated, no changes)
lua/parley/system_prompt_picker.lua:2:-- Provides a floating window UI for selecting, editing, creating, renaming, and deleting system prompts
lua/parley/system_prompt_picker.lua:6:local float_picker = require("parley.float_picker")
lua/parley/system_prompt_picker.lua:118:-- Create a floating picker to select a system prompt
lua/parley/system_prompt_picker.lua:122:    float_picker.open({
lua/parley/skill_render.lua:12:local FOOTNOTE_HL_NS = "parley_footnote_hl"
lua/parley/skill_render.lua:13:local FOOTNOTE_SOURCE = "parley-footnote"
lua/parley/skill_render.lua:17:local footnote_hl_ns_id
lua/parley/skill_render.lua:26:    if not footnote_hl_ns_id then
lua/parley/skill_render.lua:27:        footnote_hl_ns_id = vim.api.nvim_create_namespace(FOOTNOTE_HL_NS)
lua/parley/skill_render.lua:36:    vim.api.nvim_buf_clear_namespace(buf, footnote_hl_ns_id, 0, -1)
lua/parley/skill_render.lua:112:local function is_footnote_diagnostic(diagnostic)
lua/parley/skill_render.lua:114:    return diagnostic.source == FOOTNOTE_SOURCE or user_data.parley_kind == "footnote"
lua/parley/skill_render.lua:117:local function highlight_footnote_span(buf, lnum0, col_start, end_lnum0, col_end)
lua/parley/skill_render.lua:119:    vim.api.nvim_buf_set_extmark(buf, footnote_hl_ns_id, lnum0, col_start, {
lua/parley/skill_render.lua:127:--- Rehydrate persisted managed markdown footnotes into Parley diagnostics.
lua/parley/skill_render.lua:128:--- Existing non-footnote diagnostics in the shared namespace are preserved.
lua/parley/skill_render.lua:130:function M.refresh_footnote_diagnostics(buf)
lua/parley/skill_render.lua:137:    local define = require("parley.define")
lua/parley/skill_render.lua:141:    vim.api.nvim_buf_clear_namespace(buf, footnote_hl_ns_id, 0, -1)
lua/parley/skill_render.lua:144:        if not is_footnote_diagnostic(existing) then
lua/parley/skill_render.lua:149:    for _, footnote in ipairs(define.footnote_diagnostics(lines)) do
lua/parley/skill_render.lua:150:        highlight_footnote_span(buf, footnote.lnum, footnote.col, footnote.end_lnum or footnote.lnum, footnote.end_col)
lua/parley/skill_render.lua:152:            lnum = footnote.lnum,
lua/parley/skill_render.lua:153:            col = footnote.col,
lua/parley/skill_render.lua:154:            end_lnum = footnote.end_lnum or footnote.lnum,
lua/parley/skill_render.lua:155:            end_col = footnote.end_col,
lua/parley/skill_render.lua:156:            message = define.format_definition(footnote.term or footnote.id, footnote.definition, width),
lua/parley/skill_render.lua:159:            user_data = { parley_kind = "footnote" },
tests/unit/tools_types_spec.lua:12:describe("types.validate_definition", function()
tests/unit/tools_types_spec.lua:22:    it("accepts a minimal valid definition", function()
tests/unit/tools_types_spec.lua:23:        local ok = types.validate_definition(valid())
tests/unit/tools_types_spec.lua:28:        local ok, err = types.validate_definition("nope")
tests/unit/tools_types_spec.lua:36:        local ok, err = types.validate_definition(def)
tests/unit/tools_types_spec.lua:44:        local ok, err = types.validate_definition(def)
tests/unit/tools_types_spec.lua:52:        local ok, err = types.validate_definition(def)
tests/unit/tools_types_spec.lua:60:        local ok, err = types.validate_definition(def)
tests/unit/tools_types_spec.lua:68:        local ok, err = types.validate_definition(def)
tests/unit/tools_types_spec.lua:76:        local ok, err = types.validate_definition(def)
tests/unit/tools_types_spec.lua:84:        local ok, err = types.validate_definition(def)
tests/unit/tools_types_spec.lua:92:        local ok, err = types.validate_definition(def)
tests/unit/tools_types_spec.lua:100:        local ok, err = types.validate_definition(def)
tests/arch/buffer_mutation_spec.lua:37:                "lua/parley/float_picker.lua",
lua/parley/oauth.lua:61:local provider_definitions
lua/parley/oauth.lua:231:    local definition = M._get_provider_definition(provider)
lua/parley/oauth.lua:232:    local default_scopes = definition and definition.default_scopes or {}
lua/parley/oauth.lua:233:    local required_scopes = definition and definition.required_scopes or {}
lua/parley/oauth.lua:926:    local provider_definition = M._get_provider_definition(provider)
lua/parley/oauth.lua:928:    if not provider_definition or not provider_config or not provider_definition.build_refresh_token_args then
lua/parley/oauth.lua:933:    local args = provider_definition.build_refresh_token_args(provider_config, account)
lua/parley/oauth.lua:1158:                provider_definitions[provider] and provider_definitions[provider].prompt_reason("no_credentials") or "OAuth: no saved credentials.",
lua/parley/oauth.lua:1466:    local provider_definition = M._get_provider_definition(provider)
lua/parley/oauth.lua:1467:    if not provider_definition then
lua/parley/oauth.lua:1477:            message = provider_definition.missing_url_message and provider_definition.missing_url_message(url) or public_err.message,
lua/parley/oauth.lua:1506:    for provider_name, definition in pairs(provider_definitions or {}) do
lua/parley/oauth.lua:1507:        for _, pattern in ipairs(definition.detect_patterns or {}) do
lua/parley/oauth.lua:2022:provider_definitions = {
lua/parley/oauth.lua:2159:M._get_provider_definition = function(provider)
lua/parley/oauth.lua:2163:    return provider_definitions[provider]
lua/parley/oauth.lua:2169:    local definition = M._get_provider_definition(provider)
lua/parley/oauth.lua:2170:    return definition and definition.display_name or tostring(provider or "OAuth")
lua/parley/oauth.lua:2178:        local definition = M._get_provider_definition(provider)
lua/parley/oauth.lua:2179:        if definition then
lua/parley/oauth.lua:2182:                name = definition.display_name,
lua/parley/oauth.lua:2188:    for provider_name, definition in pairs(provider_definitions) do
lua/parley/oauth.lua:2191:            name = definition.display_name,
lua/parley/oauth.lua:2204:    local definition = M._get_provider_definition(provider)
lua/parley/oauth.lua:2205:    if not definition or not definition.parse_url then
lua/parley/oauth.lua:2208:    return definition.parse_url(url)
lua/parley/oauth.lua:2253:    local definition = M._get_provider_definition(provider)
lua/parley/oauth.lua:2254:    return (definition and definition.missing_refresh_token_message) or "OAuth: no refresh token available for this account."
lua/parley/oauth.lua:2261:    local definition = M._get_provider_definition(provider)
lua/parley/oauth.lua:2262:    return (definition and definition.refresh_failure_message) or "OAuth: token refresh failed for this account."
lua/parley/oauth.lua:2274:    local provider_definition = M._get_provider_definition(provider)
lua/parley/oauth.lua:2275:    if not provider_definition or not provider_definition.fetch_with_access_token then
lua/parley/oauth.lua:2308:        provider_definition.fetch_with_access_token(url, info, current_account.access_token, function(result)
lua/parley/oauth.lua:2388:    local provider_definition = M._get_provider_definition(provider)
lua/parley/oauth.lua:2425:            local reason = provider_definition and provider_definition.prompt_reason("no_credentials")
lua/parley/oauth.lua:2428:                reason = provider_definition and provider_definition.prompt_reason("reauth", result.error)
lua/parley/oauth.lua:2434:                    callback(nil, provider_definition and provider_definition.prompt_reason("cancelled")
lua/parley/oauth.lua:2453:                                callback(nil, auth_result.error or (provider_definition and provider_definition.prompt_reason("cancelled")
tests/unit/highlighter_spec.lua:27:    it("rejects a footnote reference", function()
lua/parley/exporter.lua:611:        /* Inline branch links (footnote-style) */
atlas/chat/drill_in.md:22:- **Ready** = last section is a non-empty `[]` (matches the review-skill ready definition). Markers ending in `{}` are *pending* and stay inline as agent annotations. Strike markers are *never* ready (even with trailing `[]`, since they're proposals not questions).
atlas/chat/drill_in.md:36:   - **Branch path** (cursor on a past exchange that contains ready markers): treats them as follow-up questions for that exchange. Strips them in place inside the exchange and **inserts a new user turn after that exchange's answer**, populated with the gathered quote+question blocks. The original Q/A is preserved (no resubmit). Pipeline `end_index` is capped at the inserted new turn, so subsequent (now stale) exchanges below stay in the buffer but are out of context for this turn.
atlas/chat/drill_in.md:135:skips markdown links `](`, checkboxes, footnote refs, and 1-char content — a
lua/parley/skills/review/diag_display.lua:23:local float_win
lua/parley/skills/review/diag_display.lua:24:local float_buf
lua/parley/skills/review/diag_display.lua:32:local function close_float()
lua/parley/skills/review/diag_display.lua:33:    if float_win and vim.api.nvim_win_is_valid(float_win) then
lua/parley/skills/review/diag_display.lua:34:        pcall(vim.api.nvim_win_close, float_win, true)
lua/parley/skills/review/diag_display.lua:36:    if float_buf and vim.api.nvim_buf_is_valid(float_buf) then
lua/parley/skills/review/diag_display.lua:37:        pcall(vim.api.nvim_buf_delete, float_buf, { force = true })
lua/parley/skills/review/diag_display.lua:39:    float_win = nil
lua/parley/skills/review/diag_display.lua:40:    float_buf = nil
lua/parley/skills/review/diag_display.lua:56:    close_float()
lua/parley/skills/review/diag_display.lua:82:local function diagnostic_float_lines(diagnostics)
lua/parley/skills/review/diag_display.lua:114:    if diagnostic.source == "parley-footnote" then
lua/parley/skills/review/diag_display.lua:120:local function float_config(win, line_count)
lua/parley/skills/review/diag_display.lua:140:local function show_float(diagnostics)
lua/parley/skills/review/diag_display.lua:141:    close_float()
lua/parley/skills/review/diag_display.lua:146:    local lines = diagnostic_float_lines(diagnostics)
lua/parley/skills/review/diag_display.lua:147:    float_buf = vim.api.nvim_create_buf(false, true)
lua/parley/skills/review/diag_display.lua:148:    vim.api.nvim_buf_set_option(float_buf, "buftype", "nofile")
lua/parley/skills/review/diag_display.lua:149:    vim.api.nvim_buf_set_option(float_buf, "bufhidden", "wipe")
lua/parley/skills/review/diag_display.lua:150:    vim.api.nvim_buf_set_option(float_buf, "modifiable", true)
lua/parley/skills/review/diag_display.lua:151:    require("parley.buffer_edit").replace_all_lines(float_buf, lines)
lua/parley/skills/review/diag_display.lua:152:    vim.api.nvim_buf_set_option(float_buf, "modifiable", false)
lua/parley/skills/review/diag_display.lua:153:    float_win = vim.api.nvim_open_win(float_buf, false, float_config(win, #lines))
lua/parley/skills/review/diag_display.lua:154:    vim.api.nvim_win_set_option(float_win, "wrap", true)
lua/parley/skills/review/diag_display.lua:155:    vim.api.nvim_win_set_option(float_win, "winhl", "NormalFloat:NormalFloat,FloatBorder:FloatBorder")
lua/parley/skills/review/diag_display.lua:164:    close_float()
lua/parley/skills/review/diag_display.lua:175:    local footnote_diagnostics = {}
lua/parley/skills/review/diag_display.lua:178:            if diagnostic.source == "parley-footnote" then
lua/parley/skills/review/diag_display.lua:179:                table.insert(footnote_diagnostics, diagnostic)
lua/parley/skills/review/diag_display.lua:186:    table.sort(footnote_diagnostics, function(a, b)
lua/parley/skills/review/diag_display.lua:189:    show_float(footnote_diagnostics)
tests/arch/arch_helper.lua:33:--- within the file set defined by `scope`.
lua/parley/interview.lua:73:--- it threads this in as its no-popup base to preserve timestamp insertion (#134).
lua/parley/log_emit.lua:101:-- tool definitions lead with `name`.
atlas/chat/inline_define.md:3:Select a phrase in a chat transcript, press **`<M-CR>`** (visual mode), and a
atlas/chat/inline_define.md:4:concise, context-aware definition appears as an inline diagnostic under the
atlas/chat/inline_define.md:5:phrase. The selected text stays in place and gets a markdown footnote reference
atlas/chat/inline_define.md:6:(`ASIN[^asin]`), while the definition is stored in a managed footnote footer at
atlas/chat/inline_define.md:7:the end of the chat transcript. Persisted managed footnotes are rehydrated into
atlas/chat/inline_define.md:9:annotation is **undoable** — `u` reverts the footnote edit and clears both
atlas/chat/inline_define.md:12:[#161](../../workshop/issues/000161-inline-term-definition.md) (R1 added the
atlas/chat/inline_define.md:13:highlight/undo); [#166](../../workshop/issues/000166-visual-selection-definition-system-manages-footnote.md)
atlas/chat/inline_define.md:14:made the definition durable as a managed footnote; [#167](../../workshop/issues/000167-define-diagnostic-highlight-span.md)
atlas/chat/inline_define.md:15:narrowed the visible decoration to the selected term plus footnote reference;
atlas/chat/inline_define.md:16:[#172](../../workshop/issues/000172-markdown-footnote-diagnostics.md)
atlas/chat/inline_define.md:17:rehydrates persisted managed footnotes in all markdown buffers.
atlas/chat/inline_define.md:21:1. **`define_visual(buf)`** (`lua/parley/init.lua`) reads the visual selection
atlas/chat/inline_define.md:22:   (`getpos`), extracts the phrase (`define.slice_selection`), guards
atlas/chat/inline_define.md:24:   exchange* of the selection (`define.context_for_selection` over `parse_chat`
atlas/chat/inline_define.md:26:2. It fires a headless **`define` skill** turn via `skill_invoke.invoke` with
atlas/chat/inline_define.md:28:3. The `define` skill (`lua/parley/skills/define/init.lua`) is **unforced** (no
atlas/chat/inline_define.md:31:   prompt and asks the model to call `emit_definition({term, definition})`.
atlas/chat/inline_define.md:32:4. **`render_definition`** (`on_done`), on a successful lookup: re-verifies the
atlas/chat/inline_define.md:35:   and inserts/updates a final managed footnote footer via one buffer rewrite
atlas/chat/inline_define.md:36:   (`define.apply_definition_footnote`) — a single undo entry that anchors
atlas/chat/inline_define.md:39:   footnote diagnostics (`skill_render.refresh_footnote_diagnostics`), which
atlas/chat/inline_define.md:41:   inline `term[^id]` spans (`define.format_definition` →
atlas/chat/inline_define.md:44:   `diag_display` opens a centered, non-focusable diagnostic float when the
atlas/chat/inline_define.md:45:   cursor is on the term/footnote anchor span. A no-`emit_definition` response
atlas/chat/inline_define.md:46:   leaves no footnote reference/footer.
atlas/chat/inline_define.md:50:Native `u` reverts *text*, not decorations. The footnote reference/footer rewrite
atlas/chat/inline_define.md:52:**projection watcher** (`skills/review/projection.lua`, #133 M5), which define
atlas/chat/inline_define.md:53:reuses: `render_definition` calls `projection.record_empty_for(buf, original)`
atlas/chat/inline_define.md:54:(pre-footnote hash → empty snapshot), `record(buf)` (footnoted hash → the
atlas/chat/inline_define.md:55:highlight + diagnostic), `ensure_watch(buf)`. Undoing the footnote edit lands on
atlas/chat/inline_define.md:56:the pre-footnote content-hash → the empty snapshot renders → both decorations clear;
atlas/chat/inline_define.md:59:legacy whole-line `hl_lines`. `set_applying` guards the edit so a prior define's
atlas/chat/inline_define.md:64:- **Pure** (`lua/parley/define.lua`, unit-tested with plain tables): `slice_selection`,
atlas/chat/inline_define.md:65:  `context_for_selection`, `format_definition`, `bracket_edit` (plans the `[term]`
atlas/chat/inline_define.md:67:  mapping), `apply_definition_footnote` (durable footer transform), and
atlas/chat/inline_define.md:68:  `strip_definition_footnote_footer` / `footnote_diagnostics` (treat the first
atlas/chat/inline_define.md:69:  markdown footnote definition line as the managed footer boundary).
atlas/chat/inline_define.md:70:- **IO shell** (`lua/parley/init.lua`): `define_visual`, `render_definition`;
atlas/chat/inline_define.md:71:  `lua/parley/buffer_edit.lua` owns the full-buffer footnote rewrite;
atlas/chat/inline_define.md:72:  `lua/parley/skill_render.lua` publishes footnote diagnostics; and
atlas/chat/inline_define.md:80:The footer begins at the first markdown footnote definition line:
atlas/chat/inline_define.md:86:Older define edits may include a standalone `---` separator immediately before
atlas/chat/inline_define.md:87:that first footnote definition; the stripper removes that optional separator
atlas/chat/inline_define.md:90:before LLM submission, so durable definitions do not become prompt context.
atlas/chat/inline_define.md:91:`define.footnote_diagnostics` uses the same footer detector to scan inline
atlas/chat/inline_define.md:94:For persisted multi-word anchors, a footnote definition may start with a quoted
atlas/chat/inline_define.md:98:Advertising Cost of Sales[^acos]
atlas/chat/inline_define.md:100:[^acos]: "Advertising Cost of Sales". Ratio of ad spend to sales revenue.
atlas/chat/inline_define.md:103:On reload, `define.footnote_diagnostics` uses that leading display term to find
atlas/chat/inline_define.md:105:floating definition trigger and the rehydrated inline highlight. If the phrase is
atlas/chat/inline_define.md:111:`<M-CR>` was split out of `chat_shortcut_respond` into its own `chat_define`
atlas/chat/inline_define.md:113:callback, so the split can't live inside `chat_respond`). The `chat_define`
atlas/chat/inline_define.md:114:per-mode callback is `{ n=respond, i=respond, v=define_visual, x=define_visual }`
atlas/chat/inline_define.md:115:— visual `<M-CR>` defines; normal/insert `<M-CR>` still responds; visual
atlas/chat/inline_define.md:129:`emit_definition` (`lua/parley/tools/builtin/emit_definition.lua`, in
atlas/chat/inline_define.md:130:`BUILTIN_NAMES`) is an **output-only** tool: `{term, definition}` schema,
atlas/chat/inline_define.md:136:- The fresh define highlight spans the selected text plus immediate `[^id]`
atlas/chat/inline_define.md:138:- `skill_render.refresh_footnote_diagnostics` owns only diagnostics tagged
atlas/chat/inline_define.md:139:  `parley-footnote` and preserves other `parley_skill` diagnostics, so review
atlas/chat/inline_define.md:140:  diagnostics are not cleared by markdown footnote refresh.
atlas/chat/inline_define.md:141:- A footnote diagnostic's Parley float auto-hides when the cursor leaves its
atlas/chat/inline_define.md:142:  term/footnote anchor span. The footnote persists in the file if saved.
atlas/chat/inline_define.md:146:- `lua/parley/define.lua` — pure core (slice / context / format / footnote footer / diagnostics).
atlas/chat/inline_define.md:147:- `lua/parley/init.lua` — `define_visual`, `render_definition`, `chat_define` wiring.
atlas/chat/inline_define.md:149:- `lua/parley/skill_render.lua` — footnote diagnostic refresh in the shared namespace.
atlas/chat/inline_define.md:150:- `lua/parley/chat_respond.lua` — strips managed footnote footer from LLM messages.
atlas/chat/inline_define.md:151:- `lua/parley/skills/define/init.lua` — the unforced `define` skill.
atlas/chat/inline_define.md:152:- `lua/parley/tools/builtin/emit_definition.lua` — output-only structured tool.
atlas/chat/inline_define.md:154:- `lua/parley/config.lua`, `lua/parley/keybinding_registry.lua` — the `<M-CR>` split.
atlas/chat/inline_define.md:155:- `tests/unit/define_spec.lua`, `tests/integration/define_spec.lua` — coverage.
atlas/chat/inline_define.md:160:  sibling; shares `define.slice_selection` for the visual-selection extraction.
tests/unit/spell_spec.lua:50:        it("plain newline when no popup", function()
tests/unit/spell_spec.lua:63:        it("feeds the injected base when no popup (interview timestamp case)", function()
lua/parley/outline.lua:378:-- Create a floating picker to navigate questions and headings in the current buffer
lua/parley/outline.lua:380:  local float_picker = require("parley.float_picker")
lua/parley/outline.lua:407:    float_picker.open({
lua/parley/outline.lua:447:    float_picker.open({
lua/parley/float_picker.lua:1:-- float_picker.lua
lua/parley/float_picker.lua:2:-- A self-contained floating window picker for Parley.nvim.
lua/parley/float_picker.lua:4:-- Layout: two adjacent floating windows —
lua/parley/float_picker.lua:54:local MATCH_NS = vim.api.nvim_create_namespace("float_picker_match")
lua/parley/float_picker.lua:521:-- Exported so sibling composite floats (e.g. review_menu, #133) reuse the same
lua/parley/float_picker.lua:548:--- Open a floating picker.
lua/parley/float_picker.lua:632:    local on_key_ns = vim.api.nvim_create_namespace("float_picker_on_key")
lua/parley/float_picker.lua:690:    local TAG_BAR_NS = vim.api.nvim_create_namespace("float_picker_tag_bar")
lua/parley/float_picker.lua:1097:                    "float_picker chat trace: query=%q matched=%d items=[%s]",
lua/parley/float_picker.lua:1110:                    "float_picker chat trace: apply_filter keep sel_idx=%s selected_value=%s filtered_count=%s query=%q",
lua/parley/float_picker.lua:1122:                    "float_picker chat trace: apply_filter initial_index=%s resolved_sel_idx=%s selected_value=%s filtered_count=%s",
lua/parley/float_picker.lua:1136:                    "float_picker chat trace: apply_filter default target_index=%s sel_idx=%s selected_value=%s filtered_count=%s query=%q initial_index=%s",
lua/parley/float_picker.lua:1159:                "float_picker chat trace: extra_mapping sel_idx=%s selected_value=%s filtered_count=%s query=%q",
lua/parley/float_picker.lua:1205:    -- mouse is over a non-focusable float, so winid comparison is unreliable.
lua/parley/float_picker.lua:1340:                "float_picker mapping %s skipped because it conflicts with reserved key %s",
tests/integration/review_diag_display_spec.lua:14:local function diagnostic_floats()
tests/integration/review_diag_display_spec.lua:15:    local floats = {}
tests/integration/review_diag_display_spec.lua:19:            table.insert(floats, { win = win, config = cfg, buf = vim.api.nvim_win_get_buf(win) })
tests/integration/review_diag_display_spec.lua:22:    return floats
tests/integration/review_diag_display_spec.lua:54:    it("renders footnote diagnostics in a centered non-focusable float without moving the diagnostic span", function()
tests/integration/review_diag_display_spec.lua:72:            message = "ACOS — Advertising Cost of Sales.",
tests/integration/review_diag_display_spec.lua:74:            source = "parley-footnote",
tests/integration/review_diag_display_spec.lua:78:            return #diagnostic_floats() == 1
tests/integration/review_diag_display_spec.lua:82:        local floats = diagnostic_floats()
tests/integration/review_diag_display_spec.lua:83:        assert.are.equal(1, #floats)
tests/integration/review_diag_display_spec.lua:85:        assert.are.equal(expected_width, floats[1].config.width)
tests/integration/review_diag_display_spec.lua:86:        assert.are.equal(math.floor((parent_width - expected_width) / 2), floats[1].config.col)
tests/integration/review_diag_display_spec.lua:87:        assert.is_false(floats[1].config.focusable)
tests/integration/review_diag_display_spec.lua:88:        local lines = vim.api.nvim_buf_get_lines(floats[1].buf, 0, -1, false)
tests/integration/review_diag_display_spec.lua:90:        assert.are.equal("ACOS — Advertising Cost of Sales.", lines[2])
tests/integration/review_diag_display_spec.lua:101:        assert.are.equal(0, #diagnostic_floats())
tests/integration/review_diag_display_spec.lua:105:    it("shows footnote diagnostics only while the cursor is inside the anchor span", function()
tests/integration/review_diag_display_spec.lua:120:            message = "ACOS — Advertising Cost of Sales.",
tests/integration/review_diag_display_spec.lua:122:            source = "parley-footnote",
tests/integration/review_diag_display_spec.lua:124:        assert.are.equal(0, #display_marks(buf), "cursor starts before the footnote anchor")
tests/integration/review_diag_display_spec.lua:128:        assert.are.equal(1, #diagnostic_floats(), "cursor inside the footnote anchor should show diagnosis")
tests/integration/review_diag_display_spec.lua:132:        assert.are.equal(0, #diagnostic_floats(), "same line outside the anchor should hide diagnosis")
tests/unit/config_tools_spec.lua:332:    it("defines chat_tool_use_prefix and chat_tool_result_prefix", function()
tests/unit/config_tools_spec.lua:338:    it("defines chat_shortcut_toggle_tool_folds", function()
lua/parley/skill_providers.lua:31:-- Build a manifest from a loaded skill-definition table + its absolute dir.
tests/unit/tools_builtin_propose_edits_spec.lua:22:describe("propose_edits tool definition", function()
tests/unit/tools_builtin_propose_edits_spec.lua:24:        local ok, err = types.validate_definition(propose_edits)
lua/parley/tools/init.lua:26:--- Register a ToolDefinition. Validates via `types.validate_definition`;
lua/parley/tools/init.lua:60:    local ok, err = types.validate_definition(def)
lua/parley/tools/init.lua:167:    "emit_definition",
lua/parley/tools/init.lua:178:--- repeated `setup()` invocations do not accumulate stale definitions.
lua/parley/chat_respond.lua:79:local function is_footnote_definition_line(line)
lua/parley/chat_respond.lua:83:local function trailing_footnote_boundary(lines, search_start_0)
lua/parley/chat_respond.lua:85:    local footnote_start = nil
lua/parley/chat_respond.lua:87:        if is_footnote_definition_line(lines[i]) then
lua/parley/chat_respond.lua:88:            footnote_start = i
lua/parley/chat_respond.lua:92:    if not footnote_start then
lua/parley/chat_respond.lua:96:    for i = footnote_start, #lines do
lua/parley/chat_respond.lua:98:        if line:match("%S") and not is_footnote_definition_line(line) then
lua/parley/chat_respond.lua:103:    local boundary = footnote_start
lua/parley/chat_respond.lua:376:    local define = require("parley.define")
lua/parley/chat_respond.lua:417:                text = define.strip_definition_footnote_footer(text)
lua/parley/chat_respond.lua:429:                local text = define.strip_definition_footnote_footer(read_block_text(k, b))
lua/parley/chat_respond.lua:448:                    table.insert(answer_blocks, { type = "text", text = define.strip_definition_footnote_footer(text) })
lua/parley/chat_respond.lua:466:                    table.insert(messages, { role = "user", content = define.strip_definition_footnote_footer(text) })
lua/parley/chat_respond.lua:649:    local define = require("parley.define")
lua/parley/chat_respond.lua:655:                copy.text = define.strip_definition_footnote_footer(copy.text)
lua/parley/chat_respond.lua:668:    -- Use header-defined max_full_exchanges if available, otherwise use config value
lua/parley/chat_respond.lua:673:            logger.debug("Using header-defined max_full_exchanges: " .. tostring(max_exchanges))
lua/parley/chat_respond.lua:741:                    local question_content = define.strip_definition_footnote_footer(exchange.question.content)
lua/parley/chat_respond.lua:814:            -- content_blocks (populated by chat_parser when 🔧:/📎: appear in
lua/parley/chat_respond.lua:846:                        table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.answer.content) })
lua/parley/chat_respond.lua:851:                        table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.summary.content) })
lua/parley/chat_respond.lua:859:                            table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.answer.content) })
lua/parley/chat_respond.lua:1244:            -- response should populate (target_idx in the closure below derives
lua/parley/chat_respond.lua:1860:                local footnote_boundary = trailing_footnote_boundary(all_current_lines, exchange_end)
lua/parley/chat_respond.lua:1861:                if footnote_boundary then
lua/parley/chat_respond.lua:1862:                    next_content_start = footnote_boundary
lua/parley/review.lua:27:M.populate_quickfix = function(buf, markers, filter) return get_review().populate_quickfix(buf, markers, filter) end
lua/parley/vision_finder.lua:73:    _parley.float_picker.open({
tests/unit/anthropic_tool_encode_spec.lua:55:    it("converts multiple definitions preserving input order", function()
atlas/chat/spell_typeahead.md:4:completion menu of `spellsuggest()` results pops up (pick with Tab / `<CR>` /
atlas/chat/spell_typeahead.md:28:| popup | selection | keys feed   | effect                         |
atlas/chat/spell_typeahead.md:39:buffer-local beats global in Neovim. So `cr_keys` takes a `base` (the no-popup
atlas/chat/spell_typeahead.md:73:- `tests/integration/spell_chat_spec.lua` — live attach + popup specs.
tests/unit/vault_spec.lua:83:        it("B2: resolved string secret populates _obfuscated_secrets", function()
lua/parley/review_menu.lua:3:-- A two-window float: a mode SELECTOR on top + a multi-line instruction EDITOR
lua/parley/review_menu.lua:6:-- recall) and pre-selected. Reuses float_picker.compute_layout for geometry
lua/parley/review_menu.lua:32:    local float_picker = require("parley.float_picker")
lua/parley/review_menu.lua:56:    local win_w, win_h, row, col, _, instr_row = float_picker.compute_layout(70, #modes, ui, false)
lua/parley/review_menu.lua:151:    lmap("<M-CR>", submit)
lua/parley/review_menu.lua:167:    imap({ "n", "i" }, "<M-CR>", submit)
lua/parley/skills/review/init.lua:342:M.populate_quickfix = function(buf, markers, filter)
lua/parley/skills/review/init.lua:390:-- Open a float picker listing all pending review markers under cwd.
lua/parley/skills/review/init.lua:430:    require("parley.float_picker").open({
lua/parley/skills/review/init.lua:441:-- Skill definition
lua/parley/skills/review/init.lua:586:                M.populate_quickfix(buf, markers, "pending")
lua/parley/skills/review/init.lua:685:-- it doesn't mis-populate the quickfix or bind review keys. (#133 M3)
lua/parley/skills/review/init.lua:699:        M.populate_quickfix(buf, pending, "pending")
lua/parley/skills/review/init.lua:751:    -- <M-o> opens the general SKILL PICKER (review is one of the skills); <M-CR>
tests/unit/file_tracker_spec.lua:109:        it("B2: load_data reads JSON from file and populates _file_access", function()
lua/parley/chat_parser.lua:301:    local footnote_content_start = require("parley.define").managed_footnote_content_start(lines)
lua/parley/chat_parser.lua:303:    local function final_footnote_boundary(end_line)
lua/parley/chat_parser.lua:304:        if not footnote_content_start or footnote_content_start > end_line then
lua/parley/chat_parser.lua:307:        return footnote_content_start
lua/parley/chat_parser.lua:314:                local boundary = final_footnote_boundary(end_line)
tests/unit/define_spec.lua:1:-- Unit tests for lua/parley/define.lua (pure core).
tests/unit/define_spec.lua:2:-- See workshop/issues/000161-inline-term-definition.md and its plan.
tests/unit/define_spec.lua:4:local define = require("parley.define")
tests/unit/define_spec.lua:6:describe("define.slice_selection", function()
tests/unit/define_spec.lua:11:        assert.equals("quick", define.slice_selection(lines, 1, 4, 1, 8))
tests/unit/define_spec.lua:16:        assert.equals("brown\nfox", define.slice_selection(lines, 1, 10, 2, 2))
tests/unit/define_spec.lua:20:        assert.equals("dog", define.slice_selection(lines, 3, 9, 3, 999))
tests/unit/define_spec.lua:24:        assert.equals("", define.slice_selection(lines, 1, 5, 1, 4))
tests/unit/define_spec.lua:28:describe("define.context_for_selection", function()
tests/unit/define_spec.lua:52:        local ctx = define.context_for_selection(parsed, 6, all_lines, finder)
tests/unit/define_spec.lua:57:        local ctx = define.context_for_selection(parsed, 10, all_lines, finder)
tests/unit/define_spec.lua:62:        local ctx = define.context_for_selection(parsed, 1, all_lines, finder)
tests/unit/define_spec.lua:67:describe("define.format_definition", function()
tests/unit/define_spec.lua:68:    it("composes 'TERM — definition'", function()
tests/unit/define_spec.lua:69:        local msg = define.format_definition("ASIN", "Amazon Standard Identification Number.", 200)
tests/unit/define_spec.lua:74:        local msg = define.format_definition("X", string.rep("word ", 30), 40)
tests/unit/define_spec.lua:89:            assert.equals("X — word", define.format_definition("X", "word"))
tests/unit/define_spec.lua:96:    it("trims a nil/blank definition to a safe string", function()
tests/unit/define_spec.lua:97:        assert.equals("X — (no definition)", define.format_definition("X", nil, 80))
tests/unit/define_spec.lua:101:describe("define.bracket_edit", function()
tests/unit/define_spec.lua:104:        local e = define.bracket_edit({ "here is ASIN in context" }, 1, 8, 1, 11)
tests/unit/define_spec.lua:111:        local e = define.bracket_edit({ "the lazy dog" }, 1, 9, 1, 999)
tests/unit/define_spec.lua:116:        local e = define.bracket_edit({ "brown fox", "jumps over", "the dog" }, 1, 6, 3, 2)
tests/unit/define_spec.lua:123:describe("define.diagnostic_span_after_bracket", function()
tests/unit/define_spec.lua:125:        local span = define.diagnostic_span_after_bracket(3, 9, 3, 12)
tests/unit/define_spec.lua:135:        local span = define.diagnostic_span_after_bracket(1, 7, 3, 3)
tests/unit/define_spec.lua:145:describe("define durable footnotes", function()
tests/unit/define_spec.lua:146:    it("slugifies a definition term into a markdown footnote id", function()
tests/unit/define_spec.lua:148:            define.footnote_id("Amazon Standard Identification Number"))
tests/unit/define_spec.lua:149:        assert.equals("asin", define.footnote_id("ASIN"))
tests/unit/define_spec.lua:152:    it("adds an inline footnote reference and appends a managed footer", function()
tests/unit/define_spec.lua:153:        local result = define.apply_definition_footnote(
tests/unit/define_spec.lua:169:        assert.equals("Amazon Standard Identification Number.", result.definition)
tests/unit/define_spec.lua:172:    it("updates an existing managed footnote instead of duplicating it", function()
tests/unit/define_spec.lua:173:        local result = define.apply_definition_footnote(
tests/unit/define_spec.lua:179:                "[^asin]: old definition",
tests/unit/define_spec.lua:196:        local result = define.apply_definition_footnote(
tests/unit/define_spec.lua:202:                "[^asin]: old definition",
tests/unit/define_spec.lua:206:            "Updated definition."
tests/unit/define_spec.lua:214:            "[^asin]: Updated definition.",
tests/unit/define_spec.lua:219:    it("strips only a final managed footnote footer", function()
tests/unit/define_spec.lua:228:        assert.equals("answer text", define.strip_definition_footnote_footer(text))
tests/unit/define_spec.lua:231:    it("preserves ordinary horizontal rules that are not managed footnote footers", function()
tests/unit/define_spec.lua:237:            "not a footnote",
tests/unit/define_spec.lua:240:        assert.equals(text, define.strip_definition_footnote_footer(text))
tests/unit/define_spec.lua:243:    it("reports a dividerless managed footnote footer range from the first definition", function()
tests/unit/define_spec.lua:244:        local range = define.managed_footnote_footer_range({
tests/unit/define_spec.lua:253:    it("reports a divider-based managed footnote footer range from the first definition", function()
tests/unit/define_spec.lua:254:        local range = define.managed_footnote_footer_range({
tests/unit/define_spec.lua:266:        local start = define.managed_footnote_content_start({
tests/unit/define_spec.lua:277:    it("reports the content trim start at the first definition without a divider", function()
tests/unit/define_spec.lua:278:        local start = define.managed_footnote_content_start({
tests/unit/define_spec.lua:287:    it("does not report ordinary horizontal rules as managed footnote footers", function()
tests/unit/define_spec.lua:288:        local range = define.managed_footnote_footer_range({
tests/unit/define_spec.lua:293:            "not a footnote",
tests/unit/define_spec.lua:318:        }, "\n"), define.strip_definition_footnote_footer(text))
tests/unit/define_spec.lua:321:    it("strips a final dividerless managed footnote footer", function()
tests/unit/define_spec.lua:328:        assert.equals("answer text", define.strip_definition_footnote_footer(text))
tests/unit/define_spec.lua:331:    it("extracts persisted footnote diagnostics from the managed footer", function()
tests/unit/define_spec.lua:332:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:341:            definition = "Amazon Standard Identification Number.",
tests/unit/define_spec.lua:349:    it("uses a leading quoted footnote term to span a multi-word persisted anchor", function()
tests/unit/define_spec.lua:350:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:351:            "We optimize against Advertising Cost of Sales[^acos] in the policy.",
tests/unit/define_spec.lua:353:            [=[[^acos]: "Advertising Cost of Sales". Ratio of ad spend to sales revenue.]=],
tests/unit/define_spec.lua:358:            term = "Advertising Cost of Sales",
tests/unit/define_spec.lua:359:            definition = "Ratio of ad spend to sales revenue.",
tests/unit/define_spec.lua:367:    it("uses a leading backquoted footnote term to span a multi-word persisted anchor", function()
tests/unit/define_spec.lua:368:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:369:            "We optimize against Advertising Cost of Sales[^acos] in the policy.",
tests/unit/define_spec.lua:371:            "[^acos]: `Advertising Cost of Sales`. Ratio of ad spend to sales revenue.",
tests/unit/define_spec.lua:376:            term = "Advertising Cost of Sales",
tests/unit/define_spec.lua:377:            definition = "Ratio of ad spend to sales revenue.",
tests/unit/define_spec.lua:386:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:387:            [=[He called it "Advertising Cost of Sales"[^acos] in the transcript.]=],
tests/unit/define_spec.lua:389:            [=[[^acos]: "Advertising Cost of Sales". Ratio of ad spend to sales revenue.]=],
tests/unit/define_spec.lua:394:            term = "Advertising Cost of Sales",
tests/unit/define_spec.lua:395:            definition = "Ratio of ad spend to sales revenue.",
tests/unit/define_spec.lua:404:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:407:            [=[[^acos]: "Advertising Cost of Sales". Ratio of ad spend to sales revenue.]=],
tests/unit/define_spec.lua:412:            term = "Advertising Cost of Sales",
tests/unit/define_spec.lua:413:            definition = "Ratio of ad spend to sales revenue.",
tests/unit/define_spec.lua:421:    it("extracts every inline reference to a managed footnote", function()
tests/unit/define_spec.lua:422:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:434:            definition = "Amazon Standard Identification Number.",
tests/unit/define_spec.lua:443:            definition = "Amazon Standard Identification Number.",
tests/unit/define_spec.lua:451:    it("treats the first footnote definition as the footer even with trailing text", function()
tests/unit/define_spec.lua:452:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:463:            definition = "Amazon Standard Identification Number.",
lua/parley/chat_finder.lua:565:    -- Launch float picker for chat finder
lua/parley/chat_finder.lua:754:        local picker = _parley.float_picker.open({
lua/parley/skills/define/init.lua:1:-- The `define` skill (#161): define a user-selected term concisely, inline.
lua/parley/skills/define/init.lua:4:-- `define_visual` (lua/parley/init.lua) via skill_invoke with args.phrase and a
lua/parley/skills/define/init.lua:11:    name = "define",
lua/parley/skills/define/init.lua:15:    tools = { "emit_definition" },
lua/parley/skills/define/init.lua:22:        "You define a single term for a reader of a chat transcript.",
lua/parley/skills/define/init.lua:27:        "you may search first. Then ALWAYS call the emit_definition tool exactly",
lua/parley/skills/define/init.lua:28:        "once with {term, definition}. Do not reply in plain prose.",
lua/parley/progress.lua:4:-- review round takes ~30s and needs a visible running cue. A floating bar pinned
lua/parley/progress.lua:8:-- runs one such op at a time). Pure `frame`/`format`; the float + timer are the
lua/parley/spell.lua:4:-- user types a misspelled word, pop a completion menu of `spellsuggest()`
lua/parley/spell.lua:55:-- What <CR> should feed in insert mode given the completion-popup state. Pure
lua/parley/spell.lua:57:-- live popup. Under `completeopt=noselect` nothing is ever auto-highlighted, so
lua/parley/spell.lua:61:--   no popup            → base         the normal newline (see `base`)
lua/parley/spell.lua:62:--   popup + selection   → <C-y>        accept the highlighted item
lua/parley/spell.lua:63:--   popup, no selection → <C-e>base    dismiss the menu, THEN the normal newline
lua/parley/spell.lua:64:-- `base` is what <CR> would do absent any popup — `<CR>` by default, but the
lua/parley/spell.lua:67:---@param visible boolean # is the completion popup showing
lua/parley/spell.lua:69:---@param base string|nil # no-popup keys (default "<CR>")
lua/parley/spell.lua:125:--   base_cr         → function returning the no-popup <CR> keys (injected by the
lua/parley/spell.lua:159:    -- noselect). Route it through cr_keys. The no-popup base defers to the
lua/parley/markdown_finder.lua:207:    local picker = _parley.float_picker.open({
lua/parley/issues.lua:366:-- can't see — wrap it in the user's INTERACTIVE shell so the rc-defined function
atlas/ui/keybindings.md:4:`:ParleyKeyBindings` (`<C-g>?`): centered floating window showing context-scoped shortcuts.
tests/integration/highlighting_spec.lua:165:describe("highlight_question_block: managed footnote footer", function()
tests/integration/highlighting_spec.lua:168:    it("uses a dedicated footnote highlight instead of open-question coloring", function()
tests/integration/highlighting_spec.lua:177:            "Expected the managed footnote definition to use ParleyFootnote")
tests/integration/highlighting_spec.lua:179:            "Managed footnote definition should not inherit open-question color")
tests/integration/highlighting_spec.lua:506:describe("markdown footnote diagnostics", function()
tests/integration/highlighting_spec.lua:519:    it("publishes persisted managed footnotes as Parley diagnostics", function()
tests/integration/highlighting_spec.lua:528:        skill_render.refresh_footnote_diagnostics(buf)
tests/integration/highlighting_spec.lua:535:        assert.equals("parley-footnote", diagnostics[1].source)
tests/integration/highlighting_spec.lua:540:    it("rehydrates the inline term/reference highlight for persisted footnotes", function()
tests/integration/highlighting_spec.lua:549:        skill_render.refresh_footnote_diagnostics(buf)
tests/integration/highlighting_spec.lua:551:        local hl_ns = vim.api.nvim_get_namespaces().parley_footnote_hl
tests/integration/highlighting_spec.lua:561:    it("rehydrates a multi-word structured footnote anchor highlight", function()
tests/integration/highlighting_spec.lua:565:            "We optimize against Advertising Cost of Sales[^acos] in the policy.",
tests/integration/highlighting_spec.lua:567:            [=[[^acos]: "Advertising Cost of Sales". Ratio of ad spend to sales revenue.]=],
tests/integration/highlighting_spec.lua:570:        skill_render.refresh_footnote_diagnostics(buf)
tests/integration/highlighting_spec.lua:572:        local hl_ns = vim.api.nvim_get_namespaces().parley_footnote_hl
tests/integration/highlighting_spec.lua:582:    it("refreshes footnote diagnostics on markdown text changes without clearing other Parley diagnostics", function()
tests/integration/highlighting_spec.lua:589:            "no footnote yet",
tests/integration/highlighting_spec.lua:621:        assert.is_not_nil(by_source["parley-footnote"])
tests/integration/highlighting_spec.lua:622:        assert.equals(8, by_source["parley-footnote"].col)
tests/integration/highlighting_spec.lua:624:        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "footnote removed" })
tests/integration/highlighting_spec.lua:632:    it("renders managed footnote footers with ParleyFootnote in markdown buffers", function()
tests/integration/highlighting_spec.lua:663:        assert.is_true(highlighted[2], "Expected markdown footnote definition to use ParleyFootnote")
lua/parley/init.lua:22:    hooks = {}, -- user defined command functions
lua/parley/init.lua:36:    float_picker = require("parley.float_picker"), -- shared floating window picker
lua/parley/init.lua:205:-- Local helpers are defined as wrappers at the top of this file (near require).
lua/parley/init.lua:294:-- Forward declaration so setup() closure can reference it (defined after setup())
lua/parley/init.lua:1020:        -- For OpenAI, require search_model to be defined on the model config
lua/parley/init.lua:1023:                local msg = string.format("Agent %s has no search_model defined", agent)
lua/parley/init.lua:1034:                    local msg = string.format("Agent %s has no search_model defined", agent)
lua/parley/init.lua:1554:    -- #161 ARCH-DRY: one shared visual-selection slice (define.slice_selection).
lua/parley/init.lua:1557:    local selected = require("parley.define").slice_selection(
lua/parley/init.lua:1595:-- Inline term definition (#161 + R1, #166). render_definition is the on_done IO
lua/parley/init.lua:1596:-- seam. On a successful lookup it stores the definition as a durable markdown
lua/parley/init.lua:1597:-- footnote (ONE undo entry — the anchor), highlights the selected term/reference
lua/parley/init.lua:1598:-- span (DiffChange), and shows the definition as an ephemeral INFO
lua/parley/init.lua:1600:-- the footnote edit lands on the pre-edit content-hash → the empty snapshot
lua/parley/init.lua:1603:local function render_definition(buf, span, phrase, result)
lua/parley/init.lua:1604:    -- Pick the emit_definition call (unforced → the model may answer in text or
lua/parley/init.lua:1605:    -- only call web_search; both mean "no definition"). Notify rather than
lua/parley/init.lua:1606:    -- silently doing nothing, and leave no footnote edit.
lua/parley/init.lua:1610:            if c.name == "emit_definition" then
lua/parley/init.lua:1617:        M.logger.warning("Define: no definition returned")
lua/parley/init.lua:1622:    local define = require("parley.define")
lua/parley/init.lua:1627:    -- rather than attach a footnote reference to shifted text.
lua/parley/init.lua:1629:    if define.slice_selection(lines, sr, sc - 1, er, ec - 1) ~= phrase then
lua/parley/init.lua:1630:        M.logger.warning("Define: selection changed during lookup — re-select to define")
lua/parley/init.lua:1635:    -- Store the definition as a markdown footnote in ONE full-buffer set_lines
lua/parley/init.lua:1637:    -- define's projection watcher during our own edit (mirrors review).
lua/parley/init.lua:1640:    local e = define.apply_definition_footnote(lines, sr, sc - 1, er, ec - 1, input.term or phrase, input.definition)
lua/parley/init.lua:1641:    require("parley.buffer_edit").replace_all_lines_for_definition(buf, e.lines)
lua/parley/init.lua:1645:    skill_render.refresh_footnote_diagnostics(buf)
lua/parley/init.lua:1647:    -- Record projection states so undo/redo of the footnote edit clears/restores
lua/parley/init.lua:1649:    -- snapshot, footnoted hash → highlight+diagnostic; attach the watcher.
lua/parley/init.lua:1656:    -- virtual_lines reveals the definition immediately.
lua/parley/init.lua:1661:-- define_visual: the thin IO shell for visual-mode <M-CR>. Reads the selection,
lua/parley/init.lua:1662:-- computes the enclosing-exchange context, and fires a headless define skill
lua/parley/init.lua:1663:-- turn whose on_done stores + renders the definition inline. Pure logic lives
lua/parley/init.lua:1664:-- in lua/parley/define.lua. Exposed as M.define_visual for the keybinding.
lua/parley/init.lua:1665:function M.define_visual(buf)
lua/parley/init.lua:1674:    local define = require("parley.define")
lua/parley/init.lua:1676:    local phrase = define.slice_selection(lines, sr, sc - 1, er, ec - 1)
lua/parley/init.lua:1684:    local context = define.context_for_selection(parsed, sr, lines, M.find_exchange_at_line)
lua/parley/init.lua:1687:    local manifest = require("parley.skills.define")
lua/parley/init.lua:1691:        on_done = function(result) render_definition(buf, span, phrase, result) end,
lua/parley/init.lua:1935:    -- inject interview.cr_keys as the no-popup base to keep timestamp insertion (#134).
lua/parley/init.lua:2060:    -- #161: one respond-callback set, shared by chat_respond and chat_define.
lua/parley/init.lua:2062:    local function chat_define_v()
lua/parley/init.lua:2064:        M.define_visual()
lua/parley/init.lua:2090:            -- #161: <M-CR> — n/i reuse the respond closures; v/x <Esc>-commit the
lua/parley/init.lua:2091:            -- '<,'> marks then run define_visual (visual <C-g><C-g> keeps respond).
lua/parley/init.lua:2092:            chat_define = { n = respond_cb.n, i = respond_cb.i, v = chat_define_v, x = chat_define_v },
lua/parley/init.lua:2443:-- registered_chat_dir and chat_root_display are local wrappers defined at top of file.
lua/parley/init.lua:2936:    M.float_picker.open({
lua/parley/init.lua:3043:-- Create a new chat pre-populated with a review question for the current file
tests/integration/chat_respond_spec.lua:326:    it("preserves trailing footnotes when completing an answer inserted above them", function()
tests/integration/chat_respond_spec.lua:336:[^acos]: Advertising Cost of Sales.
tests/integration/chat_respond_spec.lua:346:            local mock_qid = "qid_footnote_preserve"
tests/integration/chat_respond_spec.lua:369:        assert.is_not_nil(text:find("[^acos]: Advertising Cost of Sales.", 1, true))
tests/integration/chat_respond_spec.lua:377:        assert.equals("[^acos]: Advertising Cost of Sales.", last_nonblank)
tests/integration/chat_respond_spec.lua:390:        assert.is_not_nil(footer_divider_index, "Expected trailing footnote divider in buffer")
tests/integration/chat_respond_spec.lua:391:        assert.is_true(answer_index < footer_divider_index, "Expected answer above footnote footer")
atlas/ui/highlights.md:4:Custom groups (`ParleyQuestion`, `ParleyFileReference`, `ParleyChatReference`, `ParleyThinking`, `ParleyAnnotation`, `ParleyReference`, `ParleyFootnote`, `ParleyPickerApproximateMatch`, `InterviewTimestamp`, `InterviewThought`) linked to standard Neovim groups. `ParleyReference` (default underline) marks drill-in `[referenced span]` brackets — see [chat/drill_in](../chat/drill_in.md). `ParleyFootnote` (default `DiagnosticHint`) marks managed definition-footnote footer lines.
atlas/ui/highlights.md:9:- Managed definition-footnote footers (from the first `[^id]: ...` line) use
lua/parley/note_finder.lua:425:    _parley.float_picker.open({
lua/parley/buffer_edit.lua:117:--- Replace the entire chat buffer after a pure definition-footnote transform.
lua/parley/buffer_edit.lua:118:function M.replace_all_lines_for_definition(buf, lines)
lua/parley/tools/builtin/emit_definition.lua:1:-- `emit_definition` — output-only structured tool for the inline term-definition
lua/parley/tools/builtin/emit_definition.lua:3:-- {term, definition}; there are NO side effects — define's on_done reads the
lua/parley/tools/builtin/emit_definition.lua:10:    name = "emit_definition",
lua/parley/tools/builtin/emit_definition.lua:12:    description = "Return a concise definition of the selected term as used in "
lua/parley/tools/builtin/emit_definition.lua:17:            term = { type = "string", description = "The term being defined." },
lua/parley/tools/builtin/emit_definition.lua:18:            definition = {
lua/parley/tools/builtin/emit_definition.lua:20:                description = "A concise 1–3 sentence definition of the term, in context.",
lua/parley/tools/builtin/emit_definition.lua:23:        required = { "term", "definition" },
lua/parley/tools/builtin/emit_definition.lua:26:        -- No-op: the value lives in the tool-call args, consumed by define's
lua/parley/tools/builtin/emit_definition.lua:28:        return { content = "", name = "emit_definition" }
atlas/ui/pickers.md:3:Custom `float_picker` for all selection UIs — no external dependencies. Two or three stacked floats: results + optional tag bar + prompt.
atlas/ui/pickers.md:17:Pickers that opt in via `recall_key` remember the id of the last `<CR>`-confirmed item (in-memory only) and place the cursor there on the next open. `recall_id_fn` lets callers point at the stable identity field (defaults to `item.value`; e.g. `item.name` for agent_picker, `item.dir` for root_dir_picker). Stale recall (id no longer present in items) silently falls through to whatever `initial_index` resolves — typically the first item. Cancel/`<Esc>` does not update recall; only confirmation does. Storage lives on `float_picker._last_selection` keyed by the picker's `recall_key`.
lua/parley/keybinding_registry.lua:12:-- Parent pointers define the hierarchy. Finders are standalone roots.
lua/parley/keybinding_registry.lua:481:        -- #161: <M-CR> owns its own entry so visual mode can route to define
lua/parley/keybinding_registry.lua:484:        id = "chat_define",
lua/parley/keybinding_registry.lua:485:        config_key = "chat_shortcut_define",
lua/parley/keybinding_registry.lua:486:        default_key = { "<M-CR>" },
lua/parley/keybinding_registry.lua:489:        desc = "Parley inline term definition (visual) / respond (n/i)",
lua/parley/keybinding_registry.lua:734:        default_key = "<M-CR>",
atlas/ui/outline.md:4:- `:ParleyOutline` (`<C-g>t`): floating picker with headings and conversation turns
atlas/ui/outline.md:24:- Standard `float_picker` (results + prompt), fuzzy filter with highlights
lua/parley/skill_invoke.lua:133:    -- A read-only skill (opts.no_reload — e.g. define, #161) makes no edits, so
lua/parley/skill_invoke.lua:154:    -- opts.document lets a caller send a bounded context (e.g. define's enclosing
atlas/infra/repo_mode.md:31:`apply_repo_local()` materializes this list at setup; super-repo toggling pushes/pops sibling entries at runtime. There are no `:ParleyChatDirs` / `:ParleyChatDirAdd` / `:ParleyChatDirRemove` commands and no `<C-g>h` keybinding — they were removed in issue #117 because the original use case (drop a folder in for deliberation) is fully covered by repo + super-repo modes. State.json no longer carries `chat_dirs` / `chat_roots`; old state files with these fields are silently ignored on load.
tests/integration/define_spec.lua:1:-- Integration tests for the inline term-definition feature (#161).
tests/integration/define_spec.lua:2:-- See workshop/issues/000161-inline-term-definition.md and its plan.
tests/integration/define_spec.lua:4:-- Bootstrap parley so M.config is populated (parse_chat reads it).
tests/integration/define_spec.lua:6:    chat_dir = vim.fn.tempname() .. "-define-chat",
tests/integration/define_spec.lua:11:-- SSE builder + an emit_definition tool-call response (mirrors skill_invoke_spec).
tests/integration/define_spec.lua:22:local function emit_definition_sse(term, definition)
tests/integration/define_spec.lua:25:          content_block = { type = "tool_use", id = "d1", name = "emit_definition", input = {} } },
tests/integration/define_spec.lua:27:          delta = { type = "input_json_delta", partial_json = vim.json.encode({ term = term, definition = definition }) } },
tests/integration/define_spec.lua:33:describe("emit_definition tool", function()
tests/integration/define_spec.lua:41:            return reg.select({ "emit_definition" })
tests/integration/define_spec.lua:48:        local def = require("parley.tools.builtin.emit_definition")
tests/integration/define_spec.lua:53:        assert.is_not_nil(props.definition)
tests/integration/define_spec.lua:57:describe("define skill", function()
tests/integration/define_spec.lua:65:        assert.is_true(names["define"] == true)
tests/integration/define_spec.lua:69:        local skill = require("parley.skills.define")
tests/integration/define_spec.lua:73:        assert.same({ "emit_definition" }, skill.tools)
tests/integration/define_spec.lua:77:describe("define: skill_invoke read-only seams (#161)", function()
tests/integration/define_spec.lua:103:                raw_response = emit_definition_sse("ASIN", "Amazon Standard Identification Number."),
tests/integration/define_spec.lua:116:    local function define_manifest()
tests/integration/define_spec.lua:118:            name = "define", description = "d", scope = "global",
tests/integration/define_spec.lua:119:            activation = { manual = true }, tools = { "emit_definition" },
tests/integration/define_spec.lua:129:        skill_invoke.invoke(buf, define_manifest(), { phrase = "ASIN" }, {
tests/integration/define_spec.lua:146:        skill_invoke.invoke(buf, define_manifest(), { phrase = "ASIN" }, {
tests/integration/define_spec.lua:161:describe("define: web-toggle payload (#161)", function()
tests/integration/define_spec.lua:182:        local on = dispatcher.prepare_payload(msgs, MODEL, "anthropic", { "emit_definition" })
tests/integration/define_spec.lua:186:        local off = dispatcher.prepare_payload(msgs, MODEL, "anthropic", { "emit_definition" })
tests/integration/define_spec.lua:193:describe("define_visual + render_definition (#161)", function()
tests/integration/define_spec.lua:219:                raw_response = emit_definition_sse("ASIN", "Amazon Standard Identification Number."),
tests/integration/define_spec.lua:244:    it("stores the definition as a durable footnote, highlights the term/reference span, and shows the diagnostic", function()
tests/integration/define_spec.lua:248:        require("parley").define_visual(buf)
tests/integration/define_spec.lua:276:    it("word-wraps long define diagnostics to the diagnostic display width", function()
tests/integration/define_spec.lua:285:                raw_response = emit_definition_sse("ASIN", table.concat({
tests/integration/define_spec.lua:295:        require("parley").define_visual(buf)
tests/integration/define_spec.lua:303:        assert.is_truthy(msg:find("\n", 1, true), "long define diagnostic did not wrap")
tests/integration/define_spec.lua:306:                "wrapped define diagnostic exceeds display width: " .. line)
tests/integration/define_spec.lua:310:    it("re-defining a footnoted term updates the footer without duplicating the inline reference", function()
tests/integration/define_spec.lua:313:        require("parley").define_visual(buf)
tests/integration/define_spec.lua:320:                raw_response = emit_definition_sse("ASIN", "Updated definition."),
tests/integration/define_spec.lua:327:        require("parley").define_visual(buf)
tests/integration/define_spec.lua:330:            return table.concat(lines, "\n"):find("%[%^asin%]: Updated definition%.") ~= nil
tests/integration/define_spec.lua:338:            "[^asin]: Updated definition.",
tests/integration/define_spec.lua:342:    it("u undoes the footnote edit + clears decorations; C-r restores them (R1)", function()
tests/integration/define_spec.lua:345:        require("parley").define_visual(buf)
tests/integration/define_spec.lua:352:        -- undo: the footnote edit reverts; the projection watcher (TextChanged) clears
tests/integration/define_spec.lua:355:        -- covered by projection's own specs; here we verify define's records).
tests/integration/define_spec.lua:361:            :find("%[%^asin%]:", 1, false), "footnote not removed on undo")
tests/integration/define_spec.lua:366:        -- redo: footnote edit + decorations return
tests/integration/define_spec.lua:389:        require("parley").define_visual(buf)
tests/integration/define_spec.lua:405:        require("parley").define_visual(buf)
tests/integration/define_spec.lua:412:            "a no-tool response must not footnote the term")
tests/integration/define_spec.lua:416:describe("define keybinding split (#161)", function()
tests/integration/define_spec.lua:420:    it("routes visual <M-CR> to define, keeps visual <C-g><C-g> as respond, n/i respond", function()
tests/integration/define_spec.lua:423:        -- Mirror the production chat_define callback: n/i = respond, v/x = define.
tests/integration/define_spec.lua:431:            chat_define = {
tests/integration/define_spec.lua:434:                v = function() who = "define" end,
tests/integration/define_spec.lua:435:                x = function() who = "define" end,
tests/integration/define_spec.lua:456:        -- visual <M-CR> → define; visual <C-g><C-g> → respond (resubmit preserved)
tests/integration/define_spec.lua:457:        assert.are.equal("define", invoke("x", "<M-CR>"))
tests/integration/define_spec.lua:459:        -- normal/insert <M-CR> → respond (unchanged)
tests/integration/define_spec.lua:460:        assert.are.equal("respond", invoke("n", "<M-CR>"))
tests/integration/define_spec.lua:461:        assert.are.equal("respond", invoke("i", "<M-CR>"))
tests/integration/define_spec.lua:462:        -- chat_respond no longer binds <M-CR> (no double-bind): exactly one per mode
tests/integration/define_spec.lua:465:            if r.mode == "x" and r.key == "<M-CR>" then
tests/integration/define_spec.lua:469:        assert.are.equal(1, mcr_x_count, "<M-CR> must be bound exactly once in visual mode")
tests/integration/define_spec.lua:472:    it("real prep_chat wiring: <M-CR>/<C-g><C-g> buffer-mapped in visual mode", function()
tests/integration/define_spec.lua:474:        -- catches a chat_define id/key mismatch that would silently no-op.
tests/integration/define_spec.lua:484:        local mcr = vim.fn.maparg("<M-CR>", "x", false, true)
tests/integration/define_spec.lua:486:            "<M-CR> not buffer-mapped in visual mode after prep_chat")
tests/integration/define_spec.lua:495:describe("define: context_for_selection vs real parse_chat (#161)", function()
tests/integration/define_spec.lua:498:        local define = require("parley.define")
tests/integration/define_spec.lua:510:            "💬: define ASIN",
tests/integration/define_spec.lua:516:        -- the "define ASIN" question is line 8 (1-based)
tests/integration/define_spec.lua:517:        local ctx = define.context_for_selection(parsed, 8, lines, parley.find_exchange_at_line)
tests/integration/review_menu_spec.lua:20:    it("exports float_picker.compute_layout (reused, not duplicated)", function()
tests/integration/review_menu_spec.lua:21:        assert.is_function(require("parley.float_picker").compute_layout)
tests/integration/review_menu_spec.lua:81:    it("review.setup_keymaps binds <M-o> (skill picker) + <M-CR> (review menu) on a markdown doc", function()
tests/integration/review_menu_spec.lua:86:        p.config.review_shortcut_next = { modes = { "n", "i" }, shortcut = "<M-CR>" }
tests/integration/review_menu_spec.lua:99:        assert.is_true(has_desc("n", "open mode menu"), "<M-CR> → review menu (normal)")
tests/integration/review_menu_spec.lua:100:        assert.is_true(has_desc("i", "open mode menu"), "<M-CR> → review menu (insert)")
tests/unit/issue_finder_spec.lua:3:-- IssueFinder is a float-picker UI feature; these specs cover the pure pieces
atlas/context/artifact_refs.md:44:- **Picker:** a family ref (issue + plan + reviews) opens the house `float_picker`;
lua/parley/root_dir_picker.lua:1:-- parley.root_dir_picker — generic floating picker for managing root directories
lua/parley/root_dir_picker.lua:6:local float_picker = require("parley.float_picker")
lua/parley/root_dir_picker.lua:64:    float_picker.open({
lua/parley/tools/types.lua:56:function M.validate_definition(def)
lua/parley/tools/types.lua:58:        return fail("definition must be a table")
lua/parley/tools/types.lua:61:        return fail("definition.name must be a non-empty string")
lua/parley/tools/types.lua:64:        return fail("definition.description must be a non-empty string")
lua/parley/tools/types.lua:67:        return fail("definition.input_schema must be a table")
lua/parley/tools/types.lua:70:        return fail("definition.handler must be a function")
lua/parley/tools/types.lua:75:        return fail("definition.kind must be 'read' or 'write' when present")
lua/parley/tools/types.lua:78:        return fail("definition.needs_backup must be boolean when present")
lua/parley/tools/types.lua:83:        return fail("definition.self_paginates must be boolean when present")
lua/parley/tools/types.lua:86:        return fail("definition.default_path must be a string when present")
tests/unit/tools_registry_spec.lua:6:--   get(name)        — lookup by name, returns the definition or nil
tests/unit/tools_registry_spec.lua:8:--   select(names)    — returns a list of definitions matching the given
tests/unit/tools_registry_spec.lua:45:        it("accepts and stores a valid definition", function()
tests/unit/tools_registry_spec.lua:51:        it("raises on invalid definition (missing name)", function()
tests/unit/tools_registry_spec.lua:57:        it("raises on invalid definition (empty name)", function()
tests/unit/tools_registry_spec.lua:89:        it("returns the definition for a registered name", function()
tests/unit/tools_registry_spec.lua:112:        it("returns matching definitions in the order given", function()
atlas/modes/review.md:56:| `<M-CR>`        | Open the **review-mode menu** (mode selector + instruction editor; sticky-preselected) (#133) |
atlas/modes/review.md:60:`lua/parley/review_menu.lua` — a composite two-window float: a mode **selector**
atlas/modes/review.md:67:non-empty instruction. Reuses `float_picker.compute_layout` for geometry (now
atlas/modes/review.md:69:attachment (`is_journal_sidecar`). `<M-CR>` is free here — chat-respond's `<M-CR>`
atlas/modes/review.md:172:built-in `]d`/`[d` (jump) and `<C-W>d` (float, wraps) still work on these
atlas/modes/review.md:176:The same controller also renders managed footnote diagnostics; those use a
atlas/modes/review.md:177:centered non-focusable float instead of virtual lines, and show only while the
atlas/modes/review.md:178:cursor is inside the term/`[^footnote]` diagnostic span.
atlas/modes/review.md:183:bar** — `lua/parley/progress.lua`, a floating bar pinned just above the
atlas/modes/review.md:186:time; pure `frame`/`format` + thin float/timer IO), not review-specific — review
atlas/modes/review.md:200:review_shortcut_next   = { modes = { "n", "i" }, shortcut = "<M-CR>" }, -- review-mode menu (#133)
atlas/modes/review.md:207:- `lua/parley/skills/review/init.lua` — skill definition (+ `source(ctx)` mode composition, `mode` arg), marker parsing, `run_via_invoke` (marker pre-check + resubmit), keybindings
atlas/modes/review.md:211:- `lua/parley/review_menu.lua` — composite review-mode menu (selector + instruction editor); `<M-CR>` (#133)
lua/parley/lualine.lua:300:        -- doesn't define it, the statusline falls back to default.
lua/parley/lualine.lua:311:        -- Format each metric - use "-" for nil/undefined values or zeros
lua/parley/notes.lua:470:    -- Use float picker to select template
lua/parley/notes.lua:476:    _parley.float_picker.open({
tests/integration/progress_spec.lua:1:-- Integration tests for the progress bar's float/timer lifecycle (#133 M7).
tests/unit/parse_chat_spec.lua:667:    it("stops a final open question before a managed footnote footer", function()
tests/unit/parse_chat_spec.lua:671:            "[^acos]: ACOS (Advertising Cost of Sales).",
tests/unit/parse_chat_spec.lua:680:    it("stops a final open question before an optional legacy footnote divider", function()
tests/unit/parse_chat_spec.lua:686:            "[^acos]: ACOS (Advertising Cost of Sales).",
tests/unit/parse_chat_spec.lua:695:    it("positions a final open-question answer above managed footnotes", function()
tests/unit/parse_chat_spec.lua:700:            "[^acos]: ACOS (Advertising Cost of Sales).",
tests/unit/parse_chat_spec.lua:709:        assert.equals("[^acos]: ACOS (Advertising Cost of Sales).", lines[agent_header_start + 1])
tests/unit/parse_chat_spec.lua:712:    it("stops a final open question before the first footnote definition even with trailing text", function()
tests/unit/parse_chat_spec.lua:716:            "[^acos]: ACOS (Advertising Cost of Sales).",
lua/parley/artifact_ref.lua:115:    -- Match issues.lua's shell resolution so an rc-defined `sdlc` function loads
lua/parley/artifact_ref.lua:157:-- family_picker_items maps resolved files to float_picker item shape. Pure.
lua/parley/artifact_ref.lua:194:    local float_picker = require("parley.float_picker")
lua/parley/artifact_ref.lua:207:                    float_picker.open({
lua/parley/config.lua:435:    -- `enable` turns on visible spell underlines (vim `spell`); `typeahead` pops a
lua/parley/config.lua:441:        typeahead = true, -- as-you-type spell-suggestion popup + <CR> handling
lua/parley/config.lua:449:    -- #161: <M-CR> owns its own binding so visual mode routes to inline term
lua/parley/config.lua:450:    -- definition while n/i keep respond (one entry can't split key×mode). Visual
lua/parley/config.lua:452:    chat_shortcut_define = { modes = { "n", "i", "v", "x" }, shortcut = "<M-CR>" },
lua/parley/config.lua:498:    -- of the skills); <M-CR> is the direct review trigger — it opens the review-mode
lua/parley/config.lua:499:    -- menu (sticky-preselected). (Free in markdown docs — chat-respond <M-CR> is
lua/parley/config.lua:502:    review_shortcut_next = { modes = { "n", "i" }, shortcut = "<M-CR>" },
lua/parley/config.lua:649:        footnote = nil, -- highlight for managed definition-footnote footer lines (default: links to DiagnosticHint)
lua/parley/discovery/init.lua:21:-- member-discovery source (populates config.super_repo_members).
lua/parley/discovery/init.lua:96:--- (repo_root + super_repo_members) populated by repo-mode detection and
tests/unit/dispatcher_spec.lua:9:-- Bootstrap parley so that require("parley") works and _state is populated.
tests/unit/skill_picker_spec.lua:3:-- The float-picker UI is untested glue; the load-bearing decision is run_skill's
tests/unit/chat_finder_logic_spec.lua:3:-- ChatFinder is a large UI feature (~300 lines) built on the custom float picker.
tests/unit/chat_finder_logic_spec.lua:6:-- Note: Full UI integration (floating picker, keymappings, buffer manipulation)
tests/unit/chat_finder_logic_spec.lua:16:    local original_float_picker_open
tests/unit/chat_finder_logic_spec.lua:26:    local function find_results_float_win()
tests/unit/chat_finder_logic_spec.lua:37:    local function find_float_wins()
tests/unit/chat_finder_logic_spec.lua:51:        original_float_picker_open = M.float_picker.open
tests/unit/chat_finder_logic_spec.lua:118:        M.float_picker.open = original_float_picker_open
tests/unit/chat_finder_logic_spec.lua:493:            M.float_picker.open = function(opts)
tests/unit/chat_finder_logic_spec.lua:516:            M.float_picker.open = function(opts)
tests/unit/chat_finder_logic_spec.lua:552:            M.float_picker.open = function(opts)
tests/unit/chat_finder_logic_spec.lua:580:            M.float_picker.open = function(opts)
tests/unit/chat_finder_logic_spec.lua:615:            M.float_picker.open = function(opts)
tests/unit/chat_finder_logic_spec.lua:662:            M.float_picker.open = function(opts)
tests/unit/chat_finder_logic_spec.lua:704:            M.float_picker.open = function(opts)
tests/unit/chat_finder_logic_spec.lua:730:            M.float_picker.open = function(opts)
tests/unit/chat_finder_logic_spec.lua:765:            M.float_picker.open = function(opts)
tests/unit/chat_finder_logic_spec.lua:783:            M.float_picker.open = function(opts)
tests/unit/chat_finder_logic_spec.lua:801:            M.float_picker.open = function(opts)
tests/unit/chat_finder_logic_spec.lua:821:            M.float_picker.open = function(opts)
tests/unit/chat_finder_logic_spec.lua:843:            M.float_picker.open = function(opts)
tests/unit/chat_finder_logic_spec.lua:867:            M.float_picker.open = function(opts)
tests/integration/spell_chat_spec.lua:3:-- TextChangedI/P autocmd + <CR> keymap, and a real spellsuggest() popup.
tests/integration/spell_chat_spec.lua:72:        -- still produce the injected base_cr (interview timestamp) when no popup
tests/integration/spell_chat_spec.lua:74:        it("CR map feeds the injected base_cr when no popup is up", function()
tests/integration/spell_chat_spec.lua:82:        it("CR map inserts a plain newline with no base_cr and no popup", function()
tests/integration/spell_chat_spec.lua:101:        -- The popup must be inspected INSIDE the callback — feedkeys' "x" flag
tests/integration/spell_chat_spec.lua:113:        it("pops a spellsuggest menu for a misspelled word", function()
tests/unit/build_messages_spec.lua:707:describe("_build_messages: durable definition footnotes", function()
tests/unit/build_messages_spec.lua:708:    it("strips managed definition footnote footers from user and assistant content", function()
tests/unit/build_messages_spec.lua:751:            "second half, not a footnote",
tests/unit/build_messages_spec.lua:1007:-- entries (populated by chat_parser Task 2.5 when 🔧: / 📎: appear in
tests/unit/build_messages_spec.lua:1021:-- The flat answer.content is also populated for backward compat
tests/unit/build_messages_spec.lua:1605:describe("build_messages_from_model: durable definition footnotes", function()
tests/unit/build_messages_spec.lua:1608:    it("strips managed footnote footers from live question and answer blocks", function()
tests/unit/note_finder_logic_spec.lua:6:    local original_float_picker_open
tests/unit/note_finder_logic_spec.lua:30:        original_float_picker_open = M.float_picker.open
tests/unit/note_finder_logic_spec.lua:81:        M.float_picker.open = original_float_picker_open
tests/unit/note_finder_logic_spec.lua:136:        M.float_picker.open = function(opts)
tests/unit/note_finder_logic_spec.lua:175:        M.float_picker.open = function(opts)
tests/unit/note_finder_logic_spec.lua:198:        M.float_picker.open = function(opts)
tests/unit/note_finder_logic_spec.lua:231:        M.float_picker.open = function(opts)
tests/unit/note_finder_logic_spec.lua:247:        M.float_picker.open = function(opts)
tests/unit/note_finder_logic_spec.lua:272:        M.float_picker.open = function(opts)
tests/unit/tools_builtin_registered_spec.lua:14:--   2. Each builtin is a valid ToolDefinition per types.validate_definition.
tests/unit/tools_builtin_registered_spec.lua:50:    it("each builtin passes types.validate_definition", function()
tests/unit/tools_builtin_registered_spec.lua:55:            local ok, err = types.validate_definition(def)
tests/unit/float_picker_spec.lua:1:local float_picker = require("parley.float_picker")
tests/unit/float_picker_spec.lua:4:-- Must match the constant in float_picker.lua.
tests/unit/float_picker_spec.lua:7:-- Helper: find the results window (the float that is NOT currently focused).
tests/unit/float_picker_spec.lua:8:-- After M.open(), the prompt window is focused, so results is the other float.
tests/unit/float_picker_spec.lua:9:local function find_float_win()
tests/unit/float_picker_spec.lua:20:-- Helper: find ANY floating window (used to verify all floats are closed).
tests/unit/float_picker_spec.lua:21:local function find_any_float_win()
tests/unit/float_picker_spec.lua:31:-- Helper: return {width, height, row, col} for the float window config.
tests/unit/float_picker_spec.lua:32:local function float_layout(win)
tests/unit/float_picker_spec.lua:37:-- Helper: close any open float windows between tests.
tests/unit/float_picker_spec.lua:38:local function close_floats()
tests/unit/float_picker_spec.lua:47:describe("float_picker", function()
tests/unit/float_picker_spec.lua:53:        close_floats()
tests/unit/float_picker_spec.lua:58:        close_floats()
tests/unit/float_picker_spec.lua:65:        it("opens a floating window", function()
tests/unit/float_picker_spec.lua:66:            float_picker.open({
tests/unit/float_picker_spec.lua:71:            assert.is_not_nil(find_float_win(), "expected a results floating window to be open")
tests/unit/float_picker_spec.lua:75:            float_picker.open({
tests/unit/float_picker_spec.lua:84:            local win = find_float_win()
tests/unit/float_picker_spec.lua:91:            float_picker.open({
tests/unit/float_picker_spec.lua:100:            local win = find_float_win()
tests/unit/float_picker_spec.lua:108:            float_picker.open({
tests/unit/float_picker_spec.lua:118:            local win = find_float_win()
tests/unit/float_picker_spec.lua:124:            float_picker.open({
tests/unit/float_picker_spec.lua:137:            local win = find_float_win()
tests/unit/float_picker_spec.lua:146:            float_picker.open({
tests/unit/float_picker_spec.lua:156:            local win = find_float_win()
tests/unit/float_picker_spec.lua:174:            float_picker.open({ title = "Test", items = {}, on_select = function() end })
tests/unit/float_picker_spec.lua:181:            float_picker.open({
tests/unit/float_picker_spec.lua:186:            local win = find_float_win()
tests/unit/float_picker_spec.lua:193:            float_picker.open({
tests/unit/float_picker_spec.lua:204:            local win = find_float_win()
tests/unit/float_picker_spec.lua:220:            float_picker.open({
tests/unit/float_picker_spec.lua:233:            assert.is_nil(find_any_float_win(), "window should be closed after confirm")
tests/unit/float_picker_spec.lua:238:            float_picker.open({
tests/unit/float_picker_spec.lua:251:            assert.is_nil(find_any_float_win(), "window should be closed after cancel")
tests/unit/float_picker_spec.lua:256:            float_picker.open({
tests/unit/float_picker_spec.lua:267:            assert.is_nil(find_any_float_win(), "window should be closed after cancel")
tests/unit/float_picker_spec.lua:272:            float_picker.open({
tests/unit/float_picker_spec.lua:291:            float_picker.open({
tests/unit/float_picker_spec.lua:308:            assert.is_nil(find_any_float_win(), "window should be closed after confirm")
tests/unit/float_picker_spec.lua:313:            float_picker.open({
tests/unit/float_picker_spec.lua:332:            assert.is_nil(find_any_float_win(), "window should be closed by mapping close_fn")
tests/unit/float_picker_spec.lua:338:            float_picker.open({
tests/unit/float_picker_spec.lua:362:            assert.is_nil(find_any_float_win(), "window should be closed by mapping close_fn")
tests/unit/float_picker_spec.lua:367:            float_picker.open({
tests/unit/float_picker_spec.lua:386:            assert.equals(5, float_picker._visual_row_for_index(1, 2, 5, "bottom"))
tests/unit/float_picker_spec.lua:387:            assert.equals(4, float_picker._visual_row_for_index(2, 2, 5, "bottom"))
tests/unit/float_picker_spec.lua:388:            assert.equals(1, float_picker._index_for_visual_row(5, 2, 5, "bottom"))
tests/unit/float_picker_spec.lua:389:            assert.equals(2, float_picker._index_for_visual_row(4, 2, 5, "bottom"))
tests/unit/float_picker_spec.lua:390:            assert.equals(2, float_picker._index_for_visual_row(3, 2, 5, "bottom"))
tests/unit/float_picker_spec.lua:394:            assert.equals(1, float_picker._visual_row_for_index(1, 2, 5, "top"))
tests/unit/float_picker_spec.lua:395:            assert.equals(2, float_picker._visual_row_for_index(2, 2, 5, "top"))
tests/unit/float_picker_spec.lua:396:            assert.equals(1, float_picker._index_for_visual_row(1, 2, 5, "top"))
tests/unit/float_picker_spec.lua:397:            assert.equals(2, float_picker._index_for_visual_row(2, 2, 5, "top"))
tests/unit/float_picker_spec.lua:399:            assert.equals(2, float_picker._index_for_visual_row(3, 2, 5, "top"))
tests/unit/float_picker_spec.lua:400:            assert.equals(2, float_picker._index_for_visual_row(5, 2, 5, "top"))
tests/unit/float_picker_spec.lua:410:            float_picker.open({
tests/unit/float_picker_spec.lua:420:            local win = find_float_win()
tests/unit/float_picker_spec.lua:428:            float_picker.open({
tests/unit/float_picker_spec.lua:438:            local win = find_float_win()
tests/unit/float_picker_spec.lua:444:            float_picker.open({
tests/unit/float_picker_spec.lua:454:            local win = find_float_win()
tests/unit/float_picker_spec.lua:479:            float_picker.open({
tests/unit/float_picker_spec.lua:488:            local win = find_float_win()
tests/unit/float_picker_spec.lua:490:            assert.equals(3, float_layout(win).height)
tests/unit/float_picker_spec.lua:494:            float_picker.open({
tests/unit/float_picker_spec.lua:505:            local win = find_float_win()
tests/unit/float_picker_spec.lua:507:            assert.equals(2, float_layout(win).height)
tests/unit/float_picker_spec.lua:511:            float_picker.open({
tests/unit/float_picker_spec.lua:517:            local win = find_float_win()
tests/unit/float_picker_spec.lua:519:            assert.equals(40, float_layout(win).width)
tests/unit/float_picker_spec.lua:524:            float_picker.open({
tests/unit/float_picker_spec.lua:530:            local win = find_float_win()
tests/unit/float_picker_spec.lua:533:            assert.is_true(float_layout(win).width <= ui.width - 8,
tests/unit/float_picker_spec.lua:543:            float_picker.open({
tests/unit/float_picker_spec.lua:548:            local win = find_float_win()
tests/unit/float_picker_spec.lua:551:            assert.is_true(float_layout(win).height <= ui.height - 6 - PROMPT_OVERHEAD,
tests/unit/float_picker_spec.lua:556:            float_picker.open({
tests/unit/float_picker_spec.lua:561:            local win = find_float_win()
tests/unit/float_picker_spec.lua:563:            local layout = float_layout(win)
tests/unit/float_picker_spec.lua:573:            float_picker.open({
tests/unit/float_picker_spec.lua:578:            local win = find_float_win()
tests/unit/float_picker_spec.lua:595:            assert.equals(0, float_picker._fuzzy_score("", "anything"))
tests/unit/float_picker_spec.lua:599:            local s = float_picker._fuzzy_score("gpt", "gpt-4")
tests/unit/float_picker_spec.lua:605:            assert.is_nil(float_picker._fuzzy_score("xyz", "abc"))
tests/unit/float_picker_spec.lua:609:            local s1 = float_picker._fuzzy_score("GPT", "gpt-4")
tests/unit/float_picker_spec.lua:610:            local s2 = float_picker._fuzzy_score("gpt", "GPT-4")
tests/unit/float_picker_spec.lua:617:            assert.is_nil(float_picker._fuzzy_score("gpt xyz", "gpt-4 openai"))
tests/unit/float_picker_spec.lua:621:            local s1 = float_picker._fuzzy_score("gpt open", "openai gpt-4")
tests/unit/float_picker_spec.lua:622:            local s2 = float_picker._fuzzy_score("open gpt", "openai gpt-4")
tests/unit/float_picker_spec.lua:628:            local s_prefix = float_picker._fuzzy_score("ag", "agent-a")
tests/unit/float_picker_spec.lua:629:            local s_mid = float_picker._fuzzy_score("ag", "tools agent")
tests/unit/float_picker_spec.lua:637:            local s_consec = float_picker._fuzzy_score("gpt", "gpt-4")
tests/unit/float_picker_spec.lua:638:            local s_spread = float_picker._fuzzy_score("gpt", "a-g-path-tool")
tests/unit/float_picker_spec.lua:646:            local score = float_picker._fuzzy_score("anthrpic", "anthropic claude")
tests/unit/float_picker_spec.lua:651:            assert.is_nil(float_picker._fuzzy_score("bnthrpic", "anthropic claude"))
tests/unit/float_picker_spec.lua:655:            assert.is_nil(float_picker._fuzzy_score("zzzz", "anthropic claude"))
tests/unit/float_picker_spec.lua:659:            assert.is_nil(float_picker._fuzzy_score("tech", "Family Chores App"))
tests/unit/float_picker_spec.lua:663:            local prefix_score = float_picker._fuzzy_score("cla", "claude sonnet")
tests/unit/float_picker_spec.lua:664:            local scattered_score = float_picker._fuzzy_score("cla", "specical layout")
tests/unit/float_picker_spec.lua:671:            assert.is_nil(float_picker._fuzzy_score("open", "only pen"))
tests/unit/float_picker_spec.lua:675:            local score = float_picker._fuzzy_score("[tech]", "release notes [tech] roadmap")
tests/unit/float_picker_spec.lua:677:            assert.is_nil(float_picker._fuzzy_score("[tech]", "release notes tech roadmap"))
tests/unit/float_picker_spec.lua:681:            local score = float_picker._fuzzy_score("{family}", "{family} release notes")
tests/unit/float_picker_spec.lua:683:            assert.is_nil(float_picker._fuzzy_score("{family}", "family release notes"))
tests/unit/float_picker_spec.lua:687:            local score = float_picker._fuzzy_score("{}", "{} release notes")
tests/unit/float_picker_spec.lua:689:            assert.is_nil(float_picker._fuzzy_score("{}", "{family} release notes"))
tests/unit/float_picker_spec.lua:690:            assert.is_nil(float_picker._fuzzy_score("{}", "release notes"))
tests/unit/float_picker_spec.lua:694:            assert.is_not_nil(float_picker._fuzzy_score("{char", "{charon} release notes"))
tests/unit/float_picker_spec.lua:695:            assert.is_not_nil(float_picker._fuzzy_score("{c", "{charon} release notes"))
tests/unit/float_picker_spec.lua:697:            assert.is_nil(float_picker._fuzzy_score("{char", "charon release notes"))
tests/unit/float_picker_spec.lua:701:            assert.is_not_nil(float_picker._fuzzy_score("[te", "release notes [tech] roadmap"))
tests/unit/float_picker_spec.lua:702:            assert.is_nil(float_picker._fuzzy_score("[te", "release notes tech roadmap"))
tests/unit/float_picker_spec.lua:708:            local tokens = float_picker._tokenize_query("{charon}")
tests/unit/float_picker_spec.lua:713:            local tokens = float_picker._tokenize_query("{char")
tests/unit/float_picker_spec.lua:718:            local tokens = float_picker._tokenize_query("[te")
tests/unit/float_picker_spec.lua:723:            assert.same({}, float_picker._tokenize_query("{"))
tests/unit/float_picker_spec.lua:724:            assert.same({}, float_picker._tokenize_query("["))
tests/unit/float_picker_spec.lua:730:            local details = float_picker._fuzzy_match_details("tehc", "tech stack")
tests/unit/float_picker_spec.lua:739:            local details = float_picker._fuzzy_match_details("behc", "tech stack")
tests/unit/float_picker_spec.lua:744:            local details = float_picker._fuzzy_match_details("tech", "tech stack")
tests/unit/float_picker_spec.lua:758:            float_picker._last_selection = {}
tests/unit/float_picker_spec.lua:769:            float_picker.open({
tests/unit/float_picker_spec.lua:781:            assert.equals("a", float_picker._last_selection["spec.basic"])
tests/unit/float_picker_spec.lua:785:            float_picker._last_selection["spec.restore"] = "b"
tests/unit/float_picker_spec.lua:786:            float_picker.open({
tests/unit/float_picker_spec.lua:800:            local win = find_float_win()
tests/unit/float_picker_spec.lua:810:            float_picker._last_selection["spec.stale"] = "deleted_value"
tests/unit/float_picker_spec.lua:811:            float_picker.open({
tests/unit/float_picker_spec.lua:820:            local win = find_float_win()
tests/unit/float_picker_spec.lua:830:            float_picker._last_selection["spec.precedence"] = "a"
tests/unit/float_picker_spec.lua:831:            float_picker.open({
tests/unit/float_picker_spec.lua:842:            local win = find_float_win()
tests/unit/float_picker_spec.lua:851:            float_picker.open({
tests/unit/float_picker_spec.lua:863:            assert.equals("agent-A", float_picker._last_selection["spec.agents"])
tests/unit/float_picker_spec.lua:867:            float_picker._last_selection["spec.cancel"] = "preserved"
tests/unit/float_picker_spec.lua:868:            float_picker.open({
tests/unit/float_picker_spec.lua:881:            vim.wait(200, function() return find_any_float_win() == nil end)
tests/unit/float_picker_spec.lua:882:            assert.equals("preserved", float_picker._last_selection["spec.cancel"])

exec
/bin/zsh -lc "nl -ba lua/parley/define.lua | sed -n '400,455p' && nl -ba tests/unit/define_spec.lua | sed -n '140,230p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   400        end
   401        out[#out + 1] = ""
   402        out[#out + 1] = "---"
   403        out[#out + 1] = ""
   404        out[#out + 1] = footnote_line
   405        return out
   406    end
   407
   408    --- Insert a markdown footnote reference after the selected text and store the
   409    --- definition in a managed footer.
   410    --- @param lines string[]
   411    --- @param l1 integer
   412    --- @param c1 integer 0-based byte column
   413    --- @param l2 integer
   414    --- @param c2 integer 0-based inclusive byte column
   415    --- @param term string
   416    --- @param definition string|nil
   417    --- @return table { lines: string[], id: string, definition: string, diagnostic_span: table }
   418    function M.apply_definition_footnote(lines, l1, c1, l2, c2, term, definition)
   419        local id = M.footnote_id(term)
   420        local ref = "[^" .. id .. "]"
   421        local out = copy_lines(lines)
   422        if l1 == l2 then
   423            local line = out[l1] or ""
   424            local ec = math.min(c2 + 1, #line)
   425            if line:sub(ec + 1, ec + #ref) ~= ref then
   426                out[l1] = line:sub(1, ec) .. ref .. line:sub(ec + 1)
   427            end
   428        else
   429            local line = out[l2] or ""
   430            local ec = math.min(c2 + 1, #line)
   431            if line:sub(ec + 1, ec + #ref) ~= ref then
   432                out[l2] = line:sub(1, ec) .. ref .. line:sub(ec + 1)
   433            end
   434        end
   435        out = replace_or_append_footnote(out, id, definition)
   436        local normalized_definition = trim(definition)
   437        if normalized_definition == "" then
   438            normalized_definition = "(no definition)"
   439        end
   440        return {
   441            lines = out,
   442            id = id,
   443            definition = normalized_definition,
   444            diagnostic_span = {
   445                lnum = l1 - 1,
   446                col = c1,
   447                end_lnum = l2 - 1,
   448                end_col = c2 + 1 + #ref,
   449            },
   450        }
   451    end
   452
   453    return M
   140                end_col = 3,
   141            }, span)
   142        end)
   143    end)
   144
   145    describe("define durable footnotes", function()
   146        it("slugifies a definition term into a markdown footnote id", function()
   147            assert.equals("amazon-standard-identification-number",
   148                define.footnote_id("Amazon Standard Identification Number"))
   149            assert.equals("asin", define.footnote_id("ASIN"))
   150        end)
   151
   152        it("adds an inline footnote reference and appends a managed footer", function()
   153            local result = define.apply_definition_footnote(
   154                { "here is ASIN in context" },
   155                1, 8, 1, 11,
   156                "ASIN",
   157                "Amazon Standard Identification Number."
   158            )
   159
   160            assert.are.same({
   161                "here is ASIN[^asin] in context",
   162                "",
   163                "---",
   164                "",
   165                "[^asin]: Amazon Standard Identification Number.",
   166            }, result.lines)
   167            assert.are.same({ lnum = 0, col = 8, end_lnum = 0, end_col = 19 }, result.diagnostic_span)
   168            assert.equals("asin", result.id)
   169            assert.equals("Amazon Standard Identification Number.", result.definition)
   170        end)
   171
   172        it("updates an existing managed footnote instead of duplicating it", function()
   173            local result = define.apply_definition_footnote(
   174                {
   175                    "ASIN is here",
   176                    "",
   177                    "---",
   178                    "",
   179                    "[^asin]: old definition",
   180                },
   181                1, 0, 1, 3,
   182                "ASIN",
   183                "Amazon Standard Identification Number."
   184            )
   185
   186            assert.are.same({
   187                "ASIN[^asin] is here",
   188                "",
   189                "---",
   190                "",
   191                "[^asin]: Amazon Standard Identification Number.",
   192            }, result.lines)
   193        end)
   194
   195        it("updates an existing inline reference without duplicating it", function()
   196            local result = define.apply_definition_footnote(
   197                {
   198                    "ASIN[^asin] is here",
   199                    "",
   200                    "---",
   201                    "",
   202                    "[^asin]: old definition",
   203                },
   204                1, 0, 1, 3,
   205                "ASIN",
   206                "Updated definition."
   207            )
   208
   209            assert.are.same({
   210                "ASIN[^asin] is here",
   211                "",
   212                "---",
   213                "",
   214                "[^asin]: Updated definition.",
   215            }, result.lines)
   216            assert.are.same({ lnum = 0, col = 0, end_lnum = 0, end_col = 11 }, result.diagnostic_span)
   217        end)
   218
   219        it("strips only a final managed footnote footer", function()
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

codex
```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The implementation matches the issue’s parser/span requirements: quoted and backquoted footer display terms are parsed, nearest valid pre-reference body text drives the diagnostic span, and `skill_render.refresh_footnote_diagnostics` continues to use that same diagnostic span for both float trigger and inline highlight. No correctness blockers found. The only gate issue I see is docs: the new typed footer convention is user-facing, and README still only describes the visual define shortcut, not the persisted multi-word reload convention.

1. Strengths:
- [lua/parley/define.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/define.lua:226): Structured definition parsing stays in the pure `define` core, keeping ARCH-PURE intact.
- [lua/parley/define.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/define.lua:257): Matching chooses the nearest valid exact term before the reference and rejects non-immediate prose via the suffix check.
- [tests/unit/define_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/unit/define_spec.lua:349): Unit coverage pins quoted, backquoted, body-quoted, and fallback cases.
- [tests/integration/highlighting_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/integration/highlighting_spec.lua:561): Reload highlight coverage proves the diagnostic span reaches the rendering path.

2. Critical findings:
- None.

3. Important findings:
- [README.md](/Users/xianxu/workspace/parley.nvim/README.md:118): README update appears missing for the new structured footnote footer convention. This is a user-facing markup convention a reader can type to persist multi-word reload spans, while README currently only says visual `<M-CR>` adds a markdown footnote reference/footer. Fix sketch: add a short note/example for `[^id]: "Display Term". Definition...` or backquoted display terms.

4. Minor findings:
- None.

5. Test coverage notes:
- Verified: `make lint` passed.
- Verified: `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"` passed.
- Verified: `nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"` passed.
- Verified: `git diff --check 28225e3c6fe71d1b82e17b2b4f10d8aab0babaf5..HEAD` passed.
- Full `make test` still fails in the existing parallel-run `tests/unit/tools_builtin_find_spec.lua` case; running that spec directly passes, matching the issue log.

6. Architectural notes for upcoming work:
- ARCH-DRY: Pass. Structured footer parsing feeds the existing diagnostic path; no second highlight/float span source was added.
- ARCH-PURE: Pass. The new matching logic is pure and covered directly; IO/UI remains in `skill_render`.
- ARCH-PURPOSE: Pass for the stated parser/reload purpose. If the desired product behavior later becomes “visual define always persists multi-word anchors without manual footer editing,” that should be a separate explicit issue or a plan revision.

7. Plan revision recommendations:
- None for code behavior. The plan still matches the delivered implementation; only README documentation needs the small gate fix.
tokens used
61,597
```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The implementation matches the issue’s parser/span requirements: quoted and backquoted footer display terms are parsed, nearest valid pre-reference body text drives the diagnostic span, and `skill_render.refresh_footnote_diagnostics` continues to use that same diagnostic span for both float trigger and inline highlight. No correctness blockers found. The only gate issue I see is docs: the new typed footer convention is user-facing, and README still only describes the visual define shortcut, not the persisted multi-word reload convention.

1. Strengths:
- [lua/parley/define.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/define.lua:226): Structured definition parsing stays in the pure `define` core, keeping ARCH-PURE intact.
- [lua/parley/define.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/define.lua:257): Matching chooses the nearest valid exact term before the reference and rejects non-immediate prose via the suffix check.
- [tests/unit/define_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/unit/define_spec.lua:349): Unit coverage pins quoted, backquoted, body-quoted, and fallback cases.
- [tests/integration/highlighting_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/integration/highlighting_spec.lua:561): Reload highlight coverage proves the diagnostic span reaches the rendering path.

2. Critical findings:
- None.

3. Important findings:
- [README.md](/Users/xianxu/workspace/parley.nvim/README.md:118): README update appears missing for the new structured footnote footer convention. This is a user-facing markup convention a reader can type to persist multi-word reload spans, while README currently only says visual `<M-CR>` adds a markdown footnote reference/footer. Fix sketch: add a short note/example for `[^id]: "Display Term". Definition...` or backquoted display terms.

4. Minor findings:
- None.

5. Test coverage notes:
- Verified: `make lint` passed.
- Verified: `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"` passed.
- Verified: `nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"` passed.
- Verified: `git diff --check 28225e3c6fe71d1b82e17b2b4f10d8aab0babaf5..HEAD` passed.
- Full `make test` still fails in the existing parallel-run `tests/unit/tools_builtin_find_spec.lua` case; running that spec directly passes, matching the issue log.

6. Architectural notes for upcoming work:
- ARCH-DRY: Pass. Structured footer parsing feeds the existing diagnostic path; no second highlight/float span source was added.
- ARCH-PURE: Pass. The new matching logic is pure and covered directly; IO/UI remains in `skill_render`.
- ARCH-PURPOSE: Pass for the stated parser/reload purpose. If the desired product behavior later becomes “visual define always persists multi-word anchors without manual footer editing,” that should be a separate explicit issue or a plan revision.

7. Plan revision recommendations:
- None for code behavior. The plan still matches the delivered implementation; only README documentation needs the small gate fix.
