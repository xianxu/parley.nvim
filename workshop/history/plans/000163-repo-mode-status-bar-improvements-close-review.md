# Boundary Review — parley.nvim#163 (whole-issue close)

| field | value |
|-------|-------|
| issue | 163 — repo mode status bar improvements |
| repo | parley.nvim |
| issue file | workshop/issues/000163-repo-mode-status-bar-improvements.md |
| boundary | whole-issue close |
| milestone | — |
| window | 64ecdec9d1a127a0b7ad929286e50c2877fffd22..HEAD |
| command | sdlc close --issue 163 |
| reviewer | codex |
| timestamp | 2026-07-07T23:47:41-07:00 |
| verdict | SHIP |

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
session id: 019f4079-d28e-7ff3-ae31-237906301853
--------
user
# Code review — the one SDLC boundary review

You are conducting a fresh-context code review at a development boundary —
whole-issue close — in the **parley.nvim** repository.

- repository: parley.nvim   (root: /Users/xianxu/workspace/parley.nvim)
- issue:      parley.nvim#163   (file: workshop/issues/000163-repo-mode-status-bar-improvements.md)
- window:     Base: 64ecdec9d1a127a0b7ad929286e50c2877fffd22   Head: HEAD

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
diff --git a/atlas/modes/super_repo.md b/atlas/modes/super_repo.md
index 6fd28fb..18a5ee3 100644
--- a/atlas/modes/super_repo.md
+++ b/atlas/modes/super_repo.md
@@ -17,13 +17,16 @@ Writes are unchanged: still go to the current repo.
 ## Mode glyphs (lualine)
 
 `lualine.replace_filetype = true` (default) swaps the user's filetype
-component with a single-character mode indicator:
+component with a compact mode indicator:
 
-| Glyph | Mode       | Meaning                                     |
-|-------|------------|---------------------------------------------|
-| `○`   | global     | No parley repo context                      |
-| `⊚`   | repo       | cwd is inside a `.parley` repo              |
-| `⦿`   | super-repo | super-repo toggle is on                     |
+| Glyph          | Mode       | Meaning                                     |
+|----------------|------------|---------------------------------------------|
+| `○`            | global     | No parley repo context                      |
+| `⊚-<repo>`     | repo       | cwd is inside a `.parley` repo              |
+| `⦿-<repo>`     | super-repo | super-repo toggle is on                     |
+
+`<repo>` is the basename of `config.repo_root`, so a brain repo cwd displays
+`⊚-brain` in plain repo mode and `⦿-brain` when super-repo is active.
 
 Refresh fires on `User ParleySuperRepoChanged`.
 
diff --git a/atlas/ui/lualine.md b/atlas/ui/lualine.md
index 65fd690..66bb5a3 100644
--- a/atlas/ui/lualine.md
+++ b/atlas/ui/lualine.md
@@ -3,14 +3,14 @@
 ## Config
 - `lualine.enable`: boolean on/off
 - `lualine.section`: target section (e.g. `lualine_x`)
-- `lualine.replace_filetype`: when true (default), auto-replaces the user's filetype component with a parley mode glyph (`○` global / `⊚` repo / `⦿` super-repo). See [Super-Repo Mode](../modes/super_repo.md).
+- `lualine.replace_filetype`: when true (default), auto-replaces the user's filetype component with a parley mode glyph (`○` global / `⊚-<repo>` repo / `⦿-<repo>` super-repo). See [Super-Repo Mode](../modes/super_repo.md).
 
 ## Component Content
 - `[AgentName]`: current agent
 - `[w]` / `[w?]`: web search active / enabled but unsupported
 - `05min`: interview elapsed timer
 - Optional cache/token metrics
-- Mode glyph (`○` / `⊚` / `⦿`) when filetype auto-replace is on; refreshes on `User ParleySuperRepoChanged`
+- Mode glyph (`○` / `⊚-<repo>` / `⦿-<repo>`) when filetype auto-replace is on; repo labels are derived from `config.repo_root` and refresh on `User ParleySuperRepoChanged`
 - Existing lualine `branch` components are kept as lualine branch components,
   but Parley wraps their `fmt` callback to shorten long display labels: first
   word plus its space/`-`/`_` separator when present, capped at 10 characters,
diff --git a/lua/parley/lualine.lua b/lua/parley/lualine.lua
index 327dc17..bc7f8d4 100644
--- a/lua/parley/lualine.lua
+++ b/lua/parley/lualine.lua
@@ -3,6 +3,7 @@
 -- Lualine integration
 
 local M = {}
+local issues = require("parley.issues")
 
 -- State for flashing timer
 local timer_visible = true
@@ -41,10 +42,10 @@ local function stop_flash_timer()
 end
 
 -- Parley mode glyph for lualine. Replaces the much-wider "markdown" filetype
--- string with a single-character mode indicator.
+-- string with a compact mode indicator.
 --   ○  global     — no parley repo context (global writes)
---   ⊚  repo       — cwd is inside a .parley repo
---   ⦿  super-repo — super-repo toggle is on (read-aggregation across siblings)
+--   ⊚-name  repo       — cwd is inside a .parley repo
+--   ⦿-name  super-repo — super-repo toggle is on (read-aggregation across siblings)
 M.format_mode = function(parley_instance)
   local parley = parley_instance or _parley
   if not parley then
@@ -53,12 +54,16 @@ M.format_mode = function(parley_instance)
   end
   if not parley then return "○" end
 
+  if parley.config and parley.config.repo_root and parley.config.repo_root ~= "" then
+    local repo_label = issues.repo_label(parley.config.repo_root)
+    if parley.is_super_repo_active and parley.is_super_repo_active() then
+      return "⦿-" .. repo_label
+    end
+    return "⊚-" .. repo_label
+  end
   if parley.is_super_repo_active and parley.is_super_repo_active() then
     return "⦿"
   end
-  if parley.config and parley.config.repo_root and parley.config.repo_root ~= "" then
-    return "⊚"
-  end
   return "○"
 end
 
diff --git a/tests/unit/super_repo_spec.lua b/tests/unit/super_repo_spec.lua
index 77af70d..0b127b8 100644
--- a/tests/unit/super_repo_spec.lua
+++ b/tests/unit/super_repo_spec.lua
@@ -385,7 +385,7 @@ describe("super_repo.toggle", function()
 		assert.is_nil(persisted_note_set[resolve(sibling_b .. "/workshop/notes")])
 	end)
 
-	it("lualine.format_mode returns ○ / ⊚ / ⦿ for global / repo / super-repo", function()
+	it("lualine.format_mode returns glyph plus repo label for repo-backed modes", function()
 		local lualine = require("parley.lualine")
 
 		-- Synthesize a fake parley instance for each state to keep the
@@ -397,16 +397,28 @@ describe("super_repo.toggle", function()
 		assert.equal("○", lualine.format_mode(global_parley))
 
 		local repo_parley = {
-			config = { repo_root = "/tmp/some/repo" },
+			config = { repo_root = "/tmp/some/parley.nvim" },
+			is_super_repo_active = function() return false end,
+		}
+		assert.equal("⊚-parley.nvim", lualine.format_mode(repo_parley))
+
+		local brain_parley = {
+			config = { repo_root = "/tmp/some/brain" },
 			is_super_repo_active = function() return false end,
 		}
-		assert.equal("⊚", lualine.format_mode(repo_parley))
+		assert.equal("⊚-brain", lualine.format_mode(brain_parley))
 
 		local super_parley = {
-			config = { repo_root = "/tmp/some/repo" },
+			config = { repo_root = "/tmp/some/parley.nvim" },
+			is_super_repo_active = function() return true end,
+		}
+		assert.equal("⦿-parley.nvim", lualine.format_mode(super_parley))
+
+		local super_brain_parley = {
+			config = { repo_root = "/tmp/some/brain" },
 			is_super_repo_active = function() return true end,
 		}
-		assert.equal("⦿", lualine.format_mode(super_parley))
+		assert.equal("⦿-brain", lualine.format_mode(super_brain_parley))
 	end)
 
 	it("lualine.format_branch_label shortens long SDLC branch names for display", function()


codex
I’m using the repo’s required workflow guidance plus a fresh review stance: first I’ll read the SDLC contract and local review context, then compare the issue/plan against the diff and code.
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
/bin/zsh -lc "sed -n '1,200p' workshop/lessons.md" in /Users/xianxu/workspace/parley.nvim
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
- **To make a decoration-only action undoable, anchor it to a text edit + reuse `projection` — `u` reverts text, never extmarks/diagnostics.** The operator wanted the define highlight+diagnostic undoable; native `u` can't touch pure decorations (review's are undoable only because a round edits text). Resolution: a minimal `[term]` bracket (one `set_lines` = one undo entry) as the anchor + reuse `skills/review/projection.lua` (`record_empty_for(pre)` + `record(post)` + `ensure_watch`). Caveat that shaped the design: `skill_render.snapshot`/`apply_snapshot` are **line-granular**, so the highlight must be whole-line `DiffChange` to round-trip; a column-precise span would not survive undo/redo. In headless tests, `:undo` does NOT fire `TextChanged` — `nvim_exec_autocmds("TextChanged", {buffer=buf})` to drive the projection watcher deterministically.

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

codex
I’ve got the workflow contract and recent lessons. Next I’m reading the issue artifact and the actual touched code so the verdict is based on the stated Spec/Plan, not just the supplied patch.
exec
/bin/zsh -lc "sed -n '1,240p' workshop/issues/000163-repo-mode-status-bar-improvements.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
---
id: 000163
status: working
deps: []
github_issue:
created: 2026-07-07
updated: 2026-07-07
estimate_hours: 0.45
started: 2026-07-07T23:39:02-07:00
---

# repo mode status bar improvements

Previously we simplified status bar when we are in repo mode. Though, it's
currently not very clear which repo we are in (the cwd). Let's display that
right beside the repo/super-repo symbol. I can't find the exact symbol, but
looks like ◉, and then we should display ◉-brain, for brain repo-ed cwd.

## Problem

In repo mode, the status bar indicates the mode but does not make the current
repo identity obvious enough. When working across repos, the user needs a compact
cwd/repo cue in the status bar itself.

## Spec

- Display the current repo name next to the repo/super-repo symbol in repo mode.
- Use the existing repo-mode symbol treatment and append the repo name compactly,
  e.g. `◉-brain` for the brain repo cwd.
- Keep the simplified status bar shape; this is a clarity tweak, not a new
  status area.

## Done when

- Repo mode status bar shows the current repo name beside the repo/super-repo
  symbol.
- The display is stable across at least the brain repo and a normal repo cwd.

## Plan

- [x] Update `lua/parley/lualine.lua` `format_mode(parley_instance)` so repo and
  super-repo states render the existing glyph plus `-<repo_label>`, using
  `require("parley.issues").repo_label(parley.config.repo_root)` as the only
  repo-name formatter (`ARCH-DRY`, `ARCH-PURE`).
- [x] Preserve global mode as the bare existing glyph (`○`) and preserve the
  existing repo/super-repo glyphs themselves (`⊚`, `⦿`); only append the compact
  repo label in repo-backed modes.
- [x] Update `tests/unit/super_repo_spec.lua` lualine coverage to assert exact
  outputs for global (`○`), normal repo (`⊚-parley.nvim`), brain repo
  (`⊚-brain`), and super-repo (`⦿-parley.nvim`) (`ARCH-PURPOSE`).
- [x] Update `atlas/ui/lualine.md` and `atlas/modes/super_repo.md` so the
  documented mode glyph output matches the new repo-label suffix behavior.

## Estimate

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.10 impl=0.20
item: atlas-docs design=0.05 impl=0.05
design-buffer: 0.30
total: 0.45
```

## Log

### 2026-07-07

- Moved from `pair#102` to `parley.nvim#163`; this belongs with the parley repo
  mode/status bar implementation.
- Planning: reuse `issues.repo_label(repo_root)` for repo names (`ARCH-DRY`),
  keep the lualine change inside the existing formatter boundary (`ARCH-PURE`),
  and cover both brain and normal repo examples from the issue (`ARCH-PURPOSE`).
- Plan-quality gate first returned FAILURE for vague checklist items; refined
  the plan with exact files/functions/assertions, then `sdlc change-code` passed
  with INFO. Estimate-quality passed with INFO.
- TDD red: direct Plenary run of `tests/unit/super_repo_spec.lua` failed on
  `lualine.format_mode` returning bare `⊚` instead of `⊚-parley.nvim`.
- TDD green: `tests/unit/super_repo_spec.lua` passed after `format_mode` started
  suffixing repo-backed glyphs via `issues.repo_label(repo_root)`.
- Verification: `make test` initially hit the known parallel
  `tests/unit/tools_builtin_find_spec.lua` flake; that file passed in isolation,
  and a full `make test` retry passed with lint at 0 warnings / 0 errors and all
  unit/integration specs green.

exec
/bin/zsh -lc "nl -ba lua/parley/lualine.lua | sed -n '1,120p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
     1	-- Parley - A Neovim LLM Chat Plugin
     2	-- https://github.com/xianxu/parley.nvim/
     3	-- Lualine integration
     4	
     5	local M = {}
     6	local issues = require("parley.issues")
     7	
     8	-- State for flashing timer
     9	local timer_visible = true
    10	local flash_timer = nil
    11	-- Store the parley reference for external component access
    12	local _parley = nil
    13	
    14	-- Function to start the flashing timer
    15	local function start_flash_timer()
    16	  -- Stop existing timer if any
    17	  if flash_timer then
    18	    flash_timer:stop()
    19	    flash_timer:close()
    20	    flash_timer = nil
    21	  end
    22	
    23	  -- Create a new timer that toggles visibility every second
    24	  flash_timer = vim.loop.new_timer()
    25	  flash_timer:start(0, 1000, vim.schedule_wrap(function()
    26	    timer_visible = not timer_visible
    27	    -- Refresh lualine to show the change
    28	    pcall(function()
    29	      require("lualine").refresh()
    30	    end)
    31	  end))
    32	end
    33	
    34	-- Function to stop the flashing timer
    35	local function stop_flash_timer()
    36	  if flash_timer then
    37	    flash_timer:stop()
    38	    flash_timer:close()
    39	    flash_timer = nil
    40	  end
    41	  timer_visible = true  -- Reset to visible state
    42	end
    43	
    44	-- Parley mode glyph for lualine. Replaces the much-wider "markdown" filetype
    45	-- string with a compact mode indicator.
    46	--   ○  global     — no parley repo context (global writes)
    47	--   ⊚-name  repo       — cwd is inside a .parley repo
    48	--   ⦿-name  super-repo — super-repo toggle is on (read-aggregation across siblings)
    49	M.format_mode = function(parley_instance)
    50	  local parley = parley_instance or _parley
    51	  if not parley then
    52	    local ok, parley_module = pcall(require, "parley")
    53	    if ok then parley = parley_module end
    54	  end
    55	  if not parley then return "○" end
    56	
    57	  if parley.config and parley.config.repo_root and parley.config.repo_root ~= "" then
    58	    local repo_label = issues.repo_label(parley.config.repo_root)
    59	    if parley.is_super_repo_active and parley.is_super_repo_active() then
    60	      return "⦿-" .. repo_label
    61	    end
    62	    return "⊚-" .. repo_label
    63	  end
    64	  if parley.is_super_repo_active and parley.is_super_repo_active() then
    65	    return "⦿"
    66	  end
    67	  return "○"
    68	end
    69	
    70	M.format_branch_label = function(branch)
    71	  if not branch or branch == "" then return "" end
    72	
    73	  local label = branch
    74	  local separator = branch:find("[%s%-%_]")
    75	  if separator and separator > 1 then
    76	    label = branch:sub(1, separator)
    77	  end
    78	  if #label > 10 then
    79	    label = label:sub(1, 10)
    80	  end
    81	  if #label < #branch then
    82	    return label .. "..."
    83	  end
    84	  return label
    85	end
    86	
    87	M.create_branch_component = function(component)
    88	  local next_component
    89	  if component == "branch" then
    90	    next_component = { "branch" }
    91	  else
    92	    next_component = {}
    93	    for k, v in pairs(component) do
    94	      next_component[k] = v
    95	    end
    96	  end
    97	
    98	  local existing_fmt = next_component.fmt
    99	  next_component.fmt = function(branch, ...)
   100	    if type(existing_fmt) == "function" then
   101	      branch = existing_fmt(branch, ...)
   102	    end
   103	    return M.format_branch_label(branch)
   104	  end
   105	  return next_component
   106	end
   107	
   108	M.is_repo_mode = function(parley_instance)
   109	  return parley_instance
   110	    and parley_instance.config
   111	    and parley_instance.config.repo_root
   112	    and parley_instance.config.repo_root ~= ""
   113	end
   114	
   115	M.create_filename_component = function(parley_instance, component)
   116	  if not M.is_repo_mode(parley_instance) then
   117	    return component
   118	  end
   119	
   120	  return { function() return "" end }

exec
/bin/zsh -lc "nl -ba tests/unit/super_repo_spec.lua | sed -n '360,430p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   360	
   361		it("super-repo siblings are stripped from persisted state.json", function()
   362			parley.toggle_super_repo()
   363	
   364			-- Force a state writeback.
   365			parley.refresh_state({})
   366	
   367			local state_file = state_dir .. "/state.json"
   368			assert.equal(1, vim.fn.filereadable(state_file))
   369			local state = parley.helpers.file_to_table(state_file) or {}
   370			local persisted_chat_dirs = state.chat_dirs or {}
   371			local persisted_note_dirs = state.note_dirs or {}
   372	
   373			-- Resolve everything before comparing
   374			local function resolved_set(list)
   375				local s = {}
   376				for _, d in ipairs(list) do s[resolve(d)] = true end
   377				return s
   378			end
   379			local persisted_chat_set = resolved_set(persisted_chat_dirs)
   380			local persisted_note_set = resolved_set(persisted_note_dirs)
   381	
   382			assert.is_nil(persisted_chat_set[resolve(sibling_a .. "/workshop/parley")])
   383			assert.is_nil(persisted_chat_set[resolve(sibling_b .. "/workshop/parley")])
   384			assert.is_nil(persisted_note_set[resolve(sibling_a .. "/workshop/notes")])
   385			assert.is_nil(persisted_note_set[resolve(sibling_b .. "/workshop/notes")])
   386		end)
   387	
   388		it("lualine.format_mode returns glyph plus repo label for repo-backed modes", function()
   389			local lualine = require("parley.lualine")
   390	
   391			-- Synthesize a fake parley instance for each state to keep the
   392			-- assertion local (no leakage from the test's parley.setup()).
   393			local global_parley = {
   394				config = { repo_root = nil },
   395				is_super_repo_active = function() return false end,
   396			}
   397			assert.equal("○", lualine.format_mode(global_parley))
   398	
   399			local repo_parley = {
   400				config = { repo_root = "/tmp/some/parley.nvim" },
   401				is_super_repo_active = function() return false end,
   402			}
   403			assert.equal("⊚-parley.nvim", lualine.format_mode(repo_parley))
   404	
   405			local brain_parley = {
   406				config = { repo_root = "/tmp/some/brain" },
   407				is_super_repo_active = function() return false end,
   408			}
   409			assert.equal("⊚-brain", lualine.format_mode(brain_parley))
   410	
   411			local super_parley = {
   412				config = { repo_root = "/tmp/some/parley.nvim" },
   413				is_super_repo_active = function() return true end,
   414			}
   415			assert.equal("⦿-parley.nvim", lualine.format_mode(super_parley))
   416	
   417			local super_brain_parley = {
   418				config = { repo_root = "/tmp/some/brain" },
   419				is_super_repo_active = function() return true end,
   420			}
   421			assert.equal("⦿-brain", lualine.format_mode(super_brain_parley))
   422		end)
   423	
   424		it("lualine.format_branch_label shortens long SDLC branch names for display", function()
   425			local lualine = require("parley.lualine")
   426	
   427			assert.equal("000149-...", lualine.format_branch_label("000149-harden-chat-history-search-shell-out-inputs"))
   428			assert.equal("000132-...", lualine.format_branch_label("000132-sdlc-repo-lock"))
   429			assert.equal("main", lualine.format_branch_label("main"))
   430			assert.equal("abcdefghij...", lualine.format_branch_label("abcdefghijklmno"))

exec
/bin/zsh -lc 'git diff --stat 64ecdec9d1a127a0b7ad929286e50c2877fffd22..HEAD && git diff --name-only 64ecdec9d1a127a0b7ad929286e50c2877fffd22..HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
 atlas/modes/super_repo.md                          | 15 ++++---
 atlas/ui/lualine.md                                |  4 +-
 lua/parley/lualine.lua                             | 17 +++++---
 tests/unit/super_repo_spec.lua                     | 22 ++++++++---
 .../000163-repo-mode-status-bar-improvements.md    | 46 +++++++++++++++++++---
 5 files changed, 80 insertions(+), 24 deletions(-)
atlas/modes/super_repo.md
atlas/ui/lualine.md
lua/parley/lualine.lua
tests/unit/super_repo_spec.lua
workshop/issues/000163-repo-mode-status-bar-improvements.md

codex
The issue and implementation line up at a high level: the change is confined to the lualine formatter, targeted tests, and atlas docs. I’m checking the reused repo-label helper and nearby lualine integration now for edge cases around module loading and UI wiring.
exec
/bin/zsh -lc "nl -ba lua/parley/issues.lua | sed -n '1,140p'" in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc 'rg "repo_label" -n lua tests atlas README.md' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
lua/parley/issues.lua:316:M.repo_label = function(git_root)
lua/parley/issues.lua:753:    local label = M.repo_label(M.get_issues_repo_root())
lua/parley/lualine.lua:58:    local repo_label = issues.repo_label(parley.config.repo_root)
lua/parley/lualine.lua:60:      return "⦿-" .. repo_label
lua/parley/lualine.lua:62:    return "⊚-" .. repo_label
tests/unit/issues_spec.lua:768:-- repo_label (#142)
tests/unit/issues_spec.lua:771:describe("repo_label", function()
tests/unit/issues_spec.lua:773:        assert.equals("parley.nvim", issues.repo_label("/Users/x/workspace/parley.nvim"))
tests/unit/issues_spec.lua:774:        assert.equals("brain", issues.repo_label("/Users/x/workspace/brain"))
tests/unit/issues_spec.lua:778:        assert.equals("pair", issues.repo_label("/Users/x/workspace/pair/"))
tests/unit/issues_spec.lua:779:        assert.equals("pair", issues.repo_label("/Users/x/workspace/pair///"))
tests/unit/issues_spec.lua:783:        assert.equals("?", issues.repo_label(nil))
tests/unit/issues_spec.lua:784:        assert.equals("?", issues.repo_label(""))
tests/unit/issues_spec.lua:788:        assert.equals("repo", issues.repo_label("repo"))

 succeeded in 0ms:
     1	-- parley/issues.lua — issue management subsystem
     2	--
     3	-- Repo-local issue tracking with single-file-per-issue markdown format.
     4	-- Each issue has YAML frontmatter (status, deps, created, updated) and
     5	-- markdown sections (Done when, Plan, Log).
     6	--
     7	-- Pure functions (no vim deps): parse_frontmatter, next_runnable,
     8	-- cycle_status_value, topo_sort, parse_deps_value, slugify
     9	-- IO functions (require vim): setup, get_issues_dir, run_sdlc_issue_new,
    10	-- scan_issues, write_frontmatter, cmd_*
    11	
    12	local chat_parser = require("parley.chat_parser")
    13	local issue_vocabulary = require("parley.issue_vocabulary")
    14	
    15	local M = {}
    16	
    17	local _parley = nil
    18	
    19	-- Mtime-based cache: avoids re-reading unchanged issue files.
    20	-- Key: file path, Value: { mtime, issue_data }
    21	local _file_cache = {}
    22	
    23	M.setup = function(parley)
    24	    _parley = parley
    25	    issue_vocabulary.default()
    26	end
    27	
    28	M.clear_cache = function()
    29	    _file_cache = {}
    30	end
    31	
    32	M.get_cache = function()
    33	    return _file_cache
    34	end
    35	
    36	M.invalidate_path = function(path)
    37	    _file_cache[path] = nil
    38	end
    39	
    40	--------------------------------------------------------------------------------
    41	-- Pure functions (testable without vim runtime in most cases)
    42	--------------------------------------------------------------------------------
    43	
    44	local function trim(str)
    45	    return (str:gsub("^%s*(.-)%s*$", "%1"))
    46	end
    47	
    48	local function vocab()
    49	    return issue_vocabulary.default()
    50	end
    51	
    52	-- Slugify a title into a filename-safe string
    53	M.slugify = function(text)
    54	    local slug = (text or ""):lower()
    55	    slug = slug:gsub("[_%s]+", "-")
    56	    slug = slug:gsub("[^%w%-]", "-")
    57	    slug = slug:gsub("%-+", "-")
    58	    slug = slug:gsub("^%-+", "")
    59	    slug = slug:gsub("%-+$", "")
    60	    return slug
    61	end
    62	
    63	-- Parse a YAML-style deps value: "[]", "[0001, 0002]", or "0001, 0002"
    64	M.parse_deps_value = function(value)
    65	    if not value or value == "" then
    66	        return {}
    67	    end
    68	    local inner = value:match("^%[(.*)%]$")
    69	    if inner then
    70	        value = inner
    71	    end
    72	    if trim(value) == "" then
    73	        return {}
    74	    end
    75	    local deps = {}
    76	    for dep in value:gmatch("[^,]+") do
    77	        local d = trim(dep)
    78	        if d ~= "" then
    79	            table.insert(deps, d)
    80	        end
    81	    end
    82	    return deps
    83	end
    84	
    85	-- Parse YAML frontmatter from issue file lines.
    86	-- Returns {status, deps, created, updated, header_end} or nil if no frontmatter.
    87	M.parse_frontmatter = function(lines)
    88	    local header_end = chat_parser.find_header_end(lines)
    89	    if not header_end then
    90	        return nil
    91	    end
    92	
    93	    local result = {
    94	        id = nil,
    95	        status = vocab():category("open")[1] or "open",
    96	        deps = {},
    97	        created = "",
    98	        updated = "",
    99	        github_issue = nil,
   100	        header_end = header_end,
   101	    }
   102	
   103	    -- Parse lines between opening --- (line 1) and closing --- (header_end)
   104	    for i = 2, header_end - 1 do
   105	        local line = lines[i]
   106	        if line then
   107	            local key, val = line:match("^([%w_]+):%s*(.*)$")
   108	            if key then
   109	                key = key:lower()
   110	                val = trim(val)
   111	                if key == "id" then
   112	                    result.id = val:match('^"(.*)"$') or val
   113	                elseif key == "status" then
   114	                    result.status = val
   115	                elseif key == "deps" then
   116	                    result.deps = M.parse_deps_value(val)
   117	                elseif key == "created" then
   118	                    result.created = val
   119	                elseif key == "updated" then
   120	                    result.updated = val
   121	                elseif key == "github_issue" then
   122	                    result.github_issue = val
   123	                end
   124	            end
   125	        end
   126	    end
   127	
   128	    return result
   129	end
   130	
   131	-- Extract the issue title from lines (first # heading after frontmatter)
   132	M.extract_title = function(lines, header_end)
   133	    local start = (header_end or 0) + 1
   134	    for i = start, #lines do
   135	        local title = lines[i]:match("^#%s+(.+)$")
   136	        if title then
   137	            return trim(title)
   138	        end
   139	    end
   140	    return ""

exec
/bin/zsh -lc "nl -ba lua/parley/lualine.lua | sed -n '115,260p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   115	M.create_filename_component = function(parley_instance, component)
   116	  if not M.is_repo_mode(parley_instance) then
   117	    return component
   118	  end
   119	
   120	  return { function() return "" end }
   121	end
   122	
   123	-- Lualine component returning the mode glyph. Designed as a drop-in replacement
   124	-- for the user's `filetype` component.
   125	M.create_mode_component = function(parley_instance)
   126	  local parley = parley_instance or _parley
   127	  return {
   128	    function()
   129	      return M.format_mode(parley)
   130	    end,
   131	  }
   132	end
   133	
   134	-- Notes folder detection and formatting
   135	M.format_directory = function(parley_instance)
   136	  local cwd = vim.fn.getcwd()
   137	  local home = vim.env.HOME
   138	  local notes_path = home .. "/Library/Mobile Documents/com~apple~CloudDocs/notes"
   139	
   140	  -- Try to get parley instance from multiple sources
   141	  local parley = parley_instance or _parley
   142	  if not parley then
   143	    local ok, parley_module = pcall(require, "parley")
   144	    if ok then
   145	      parley = parley_module
   146	    end
   147	  end
   148	
   149	  -- Priority 1: If interview mode is active, always show INTERVIEW with timer
   150	  if parley and parley._state and parley._state.interview_mode and parley._state.interview_start_time then
   151	    local elapsed = os.time() - parley._state.interview_start_time
   152	    local minutes = math.floor(elapsed / 60)
   153	    local timer_text = string.format(":%02dMIN", minutes)
   154	
   155	    -- Flash the timer by toggling visibility
   156	    if timer_visible then
   157	      return " INTERVIEW " .. timer_text
   158	    else
   159	      return " INTERVIEW        "  -- Same length with spaces for stable width
   160	    end
   161	  end
   162	
   163	  -- Priority 2: Repo mode already has repo/branch orientation in lualine.
   164	  if M.is_repo_mode(parley) then
   165	    return ""
   166	  end
   167	
   168	  -- Priority 3: If in notes folder, show NOTE
   169	  if cwd:sub(1, #notes_path) == notes_path then
   170	    return " NOTE"
   171	  end
   172	
   173	  -- Priority 4: Default behavior - show current directory
   174	  if cwd:sub(1, #home) == home then
   175	    cwd = "~" .. cwd:sub(#home + 1)
   176	  end
   177	  return " " .. cwd
   178	end
   179	
   180	-- Directory color function
   181	M.get_directory_color = function(parley_instance)
   182	  local cwd = vim.fn.getcwd()
   183	  local home = vim.env.HOME
   184	  local notes_path = home .. "/Library/Mobile Documents/com~apple~CloudDocs/notes"
   185	
   186	  -- Try to get parley instance from multiple sources
   187	  local parley = parley_instance or _parley
   188	  if not parley then
   189	    local ok, parley_module = pcall(require, "parley")
   190	    if ok then
   191	      parley = parley_module
   192	    end
   193	  end
   194	
   195	  -- Priority 1: Interview mode gets red color regardless of location
   196	  if parley and parley._state and parley._state.interview_mode then
   197	    return { fg = '#ff6b6b', gui = 'bold' }  -- Red color for interview mode
   198	  end
   199	
   200	  -- Priority 2: Notes folder gets cyan color
   201	  if cwd:sub(1, #notes_path) == notes_path then
   202	    return { fg = '#61dafb', gui = 'bold' }  -- Cyan color for note mode
   203	  end
   204	
   205	  -- Priority 3: Default color for other folders
   206	  return nil
   207	end
   208	
   209	-- Create a component generator that can be used externally or internally
   210	M.create_component = function(parley_instance)
   211	  local parley = parley_instance or _parley
   212	
   213	  -- If no parley instance is available, return a placeholder
   214	  if not parley then
   215	    return {
   216	      function() return "Parley not initialized" end,
   217	      cond = function() return false end
   218	    }
   219	  end
   220	
   221	  local not_chat = parley.not_chat
   222	
   223	  -- Define the parley component
   224	  -- Cache the busy state and only check it when events fire
   225	  local cached_busy_state = false
   226	  local last_check_time = 0
   227	  local check_interval = 1  -- seconds
   228	
   229	  -- Function to check busy state with caching
   230	  local function check_is_busy(buf)
   231	    local current_time = os.time()
   232	
   233	    -- Only check actual busy state periodically or when forced by events
   234	    if (current_time - last_check_time) >= check_interval then
   235	      -- Pass skip_warning=true to avoid log spam from UI components
   236	      cached_busy_state = parley.tasker.is_busy(buf, true)
   237	      last_check_time = current_time
   238	    end
   239	
   240	    return cached_busy_state
   241	  end
   242	
   243	  -- Create an augroup for our events
   244	  local augroup = vim.api.nvim_create_augroup("ParleyLualineComponent", { clear = true })
   245	
   246	  -- Force refresh when specific events occur - using direct API call to avoid buffer issues
   247	  vim.api.nvim_create_autocmd({"User"}, {
   248	    pattern = {"ParleyQueryStarted", "ParleyQueryFinished", "ParleyDone"},
   249	    group = augroup,
   250	    callback = function()
   251	      -- Reset cache immediately on these events
   252	      last_check_time = 0
   253	    end
   254	  })
   255	
   256	  return {
   257	    function()
   258	      -- Check if current buffer is a chat
   259	      local buf = vim.api.nvim_get_current_buf()
   260	      local file_name = vim.api.nvim_buf_get_name(buf)

exec
/bin/zsh -lc 'git diff --check 64ecdec9d1a127a0b7ad929286e50c2877fffd22..HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
codex
The helper is already pure and covered elsewhere, and the formatter uses it as the issue required. I’m doing one more pass against docs/readme expectations and the exact changed range before I write the machine-readable verdict.
exec
/bin/zsh -lc 'git diff --unified=80 64ecdec9d1a127a0b7ad929286e50c2877fffd22..HEAD -- lua/parley/lualine.lua tests/unit/super_repo_spec.lua atlas/modes/super_repo.md atlas/ui/lualine.md README.md' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
diff --git a/atlas/modes/super_repo.md b/atlas/modes/super_repo.md
index 6fd28fb..18a5ee3 100644
--- a/atlas/modes/super_repo.md
+++ b/atlas/modes/super_repo.md
@@ -1,93 +1,96 @@
 # Super-Repo Mode
 
 Read-aggregation overlay on top of plain repo mode. When active, parley's
 finders surface chats / notes / issues / vision / markdown across **all**
 sibling `.parley` repos under the workspace root, not just the current one.
 Writes are unchanged: still go to the current repo.
 
 ## Activation
 
 - **Toggle**: `<C-g>S` (`global_shortcut_super_repo_toggle`).
 - **Pre-condition**: cwd must be inside a `.parley` repo (i.e. `repo_root`
   is set by `apply_repo_local`). If not, the toggle fails with a notice.
 - **Workspace root**: parent of `repo_root`. Members are direct children of
   the workspace root whose own direct child is `.parley`.
 - **Transient** — never persisted to `state.json`.
 
 ## Mode glyphs (lualine)
 
 `lualine.replace_filetype = true` (default) swaps the user's filetype
-component with a single-character mode indicator:
+component with a compact mode indicator:
 
-| Glyph | Mode       | Meaning                                     |
-|-------|------------|---------------------------------------------|
-| `○`   | global     | No parley repo context                      |
-| `⊚`   | repo       | cwd is inside a `.parley` repo              |
-| `⦿`   | super-repo | super-repo toggle is on                     |
+| Glyph          | Mode       | Meaning                                     |
+|----------------|------------|---------------------------------------------|
+| `○`            | global     | No parley repo context                      |
+| `⊚-<repo>`     | repo       | cwd is inside a `.parley` repo              |
+| `⦿-<repo>`     | super-repo | super-repo toggle is on                     |
+
+`<repo>` is the basename of `config.repo_root`, so a brain repo cwd displays
+`⊚-brain` in plain repo mode and `⦿-brain` when super-repo is active.
 
 Refresh fires on `User ParleySuperRepoChanged`.
 
 ## Reads — multi-root aggregation
 
 | Finder           | Per-member path           | Display prefix  |
 |------------------|---------------------------|-----------------|
 | Chat (`<C-g>f`)  | `<member>/workshop/parley`| `{<repo_name>} `|
 | Note (`<C-n>f`)  | `<member>/workshop/notes` | `{<repo_name>} `|
 | Issue (`<C-y>f`) | `<member>/workshop/issues`| `{<repo_name>} `|
 | Vision (`<C-j>f`)| `<member>/workshop/vision`| `{<repo_name>} `|
 | Markdown (`<C-g>m`) | `<member>` at `markdown_finder_max_depth` | `{<repo_name>} <relative>` |
 
 Chat & note finders inherit multi-root behaviour from `root_dirs.lua` —
 super-repo simply pushes each member's chat/note dir into `chat_roots` /
 `note_roots` with `label = <repo_name>`. Issue / vision / markdown finders
 were extended explicitly during M3-M5.
 
 ## Sticky `{repo}` filter
 
 Every super-repo-aware finder (chat, note, issue, vision, markdown) preserves
 `{repo}` filter fragments across reopens via `lua/parley/finder_sticky.lua`.
 Both completed (`{charon}`) and in-progress (`{char`) prompt fragments are
 extracted on every keystroke, normalised to the completed form, and re-seeded
 as `initial_query` next time. Chat finder additionally preserves `[tag]`
 fragments.
 
 Matching is also forgiving of in-progress brackets: `{char` matches the same
 items as `{charon}` would (prefix match against the haystack `{repo}` token),
 fixing the case where typing was abandoned before the closing brace.
 
 ## Writes — unchanged
 
 `chat_dir`, `notes_dir`, `issues_dir`, `history_dir`, `vision_dir`,
 `repo_root` are exactly what plain repo mode set them to. Super-repo
 does not redirect writes to a "brain" repo — that idea was dropped during
 design (see `workshop/issues/000113-create-a-super-repo-mode.md`).
 
 ## Persistence safety
 
 For **chat** roots: trivially safe. Issue #117 stopped persisting
 `chat_roots` / `chat_dirs` to `state.json` entirely — the chat root list
 is derived on every read from `config.chat_dir + repo + super-repo`.
 Super-repo's `get_pushed_chat_dirs()` is still called by the (now
 chat-less) persistence gate sibling note path indirectly, but on the
 chat side there is nothing to filter.
 
 For **note** roots: the persistence gate still runs. Super-repo-pushed
 sibling note dirs are excluded from `state.json` via
 `super_repo.get_pushed_note_dirs()`, in addition to the `label = "repo"`
 filter for plain repo mode's primary note root.
 
 ## Code
 
 - `lua/parley/super_repo.lua` — module: `compute_members`, `is_active`,
   `toggle`, `get_pushed_chat_dirs` / `get_pushed_note_dirs`.
 - `lua/parley/init.lua` — wires `parley.toggle_super_repo()` /
   `parley.is_super_repo_active()`; persistence gate consults pushed-dirs.
 - `lua/parley/issues.lua` — `scan_issues` accepts `repo_name` +
   `history_dir_override` opts.
 - `lua/parley/issue_finder.lua`, `vision_finder.lua`, `markdown_finder.lua`
   — multi-root aggregation when `super_repo_members` is non-empty.
 - `lua/parley/finder_sticky.lua` — shared `{root}` / `[tag]` extraction and
   initial-query formatter used by every finder for sticky filters.
 - `lua/parley/lualine.lua` — `format_mode`, `create_mode_component`, and
   the filetype-component auto-replace at setup time.
 - `lua/parley/keybinding_registry.lua` — `super_repo_toggle` entry.
diff --git a/atlas/ui/lualine.md b/atlas/ui/lualine.md
index 65fd690..66bb5a3 100644
--- a/atlas/ui/lualine.md
+++ b/atlas/ui/lualine.md
@@ -1,25 +1,25 @@
 # Spec: Lualine Integration
 
 ## Config
 - `lualine.enable`: boolean on/off
 - `lualine.section`: target section (e.g. `lualine_x`)
-- `lualine.replace_filetype`: when true (default), auto-replaces the user's filetype component with a parley mode glyph (`○` global / `⊚` repo / `⦿` super-repo). See [Super-Repo Mode](../modes/super_repo.md).
+- `lualine.replace_filetype`: when true (default), auto-replaces the user's filetype component with a parley mode glyph (`○` global / `⊚-<repo>` repo / `⦿-<repo>` super-repo). See [Super-Repo Mode](../modes/super_repo.md).
 
 ## Component Content
 - `[AgentName]`: current agent
 - `[w]` / `[w?]`: web search active / enabled but unsupported
 - `05min`: interview elapsed timer
 - Optional cache/token metrics
-- Mode glyph (`○` / `⊚` / `⦿`) when filetype auto-replace is on; refreshes on `User ParleySuperRepoChanged`
+- Mode glyph (`○` / `⊚-<repo>` / `⦿-<repo>`) when filetype auto-replace is on; repo labels are derived from `config.repo_root` and refresh on `User ParleySuperRepoChanged`
 - Existing lualine `branch` components are kept as lualine branch components,
   but Parley wraps their `fmt` callback to shorten long display labels: first
   word plus its space/`-`/`_` separator when present, capped at 10 characters,
   plus `...` when shortened. The underlying git branch name is not changed.
 - In repo mode, Parley suppresses cwd/directory display and lualine `filename`
   components to save statusline width; interview mode remains visible because it
   carries active timer state rather than location context.
 
 ## Manual Integration
 - `require('parley.lualine').create_component()` for custom positioning
 - `require('parley.lualine').create_mode_component()` for the mode glyph (use with `replace_filetype = false`)
 - `require('parley.lualine').format_branch_label()` for the branch display rule
diff --git a/lua/parley/lualine.lua b/lua/parley/lualine.lua
index 327dc17..bc7f8d4 100644
--- a/lua/parley/lualine.lua
+++ b/lua/parley/lualine.lua
@@ -1,141 +1,146 @@
 -- Parley - A Neovim LLM Chat Plugin
 -- https://github.com/xianxu/parley.nvim/
 -- Lualine integration
 
 local M = {}
+local issues = require("parley.issues")
 
 -- State for flashing timer
 local timer_visible = true
 local flash_timer = nil
 -- Store the parley reference for external component access
 local _parley = nil
 
 -- Function to start the flashing timer
 local function start_flash_timer()
   -- Stop existing timer if any
   if flash_timer then
     flash_timer:stop()
     flash_timer:close()
     flash_timer = nil
   end
 
   -- Create a new timer that toggles visibility every second
   flash_timer = vim.loop.new_timer()
   flash_timer:start(0, 1000, vim.schedule_wrap(function()
     timer_visible = not timer_visible
     -- Refresh lualine to show the change
     pcall(function()
       require("lualine").refresh()
     end)
   end))
 end
 
 -- Function to stop the flashing timer
 local function stop_flash_timer()
   if flash_timer then
     flash_timer:stop()
     flash_timer:close()
     flash_timer = nil
   end
   timer_visible = true  -- Reset to visible state
 end
 
 -- Parley mode glyph for lualine. Replaces the much-wider "markdown" filetype
--- string with a single-character mode indicator.
+-- string with a compact mode indicator.
 --   ○  global     — no parley repo context (global writes)
---   ⊚  repo       — cwd is inside a .parley repo
---   ⦿  super-repo — super-repo toggle is on (read-aggregation across siblings)
+--   ⊚-name  repo       — cwd is inside a .parley repo
+--   ⦿-name  super-repo — super-repo toggle is on (read-aggregation across siblings)
 M.format_mode = function(parley_instance)
   local parley = parley_instance or _parley
   if not parley then
     local ok, parley_module = pcall(require, "parley")
     if ok then parley = parley_module end
   end
   if not parley then return "○" end
 
+  if parley.config and parley.config.repo_root and parley.config.repo_root ~= "" then
+    local repo_label = issues.repo_label(parley.config.repo_root)
+    if parley.is_super_repo_active and parley.is_super_repo_active() then
+      return "⦿-" .. repo_label
+    end
+    return "⊚-" .. repo_label
+  end
   if parley.is_super_repo_active and parley.is_super_repo_active() then
     return "⦿"
   end
-  if parley.config and parley.config.repo_root and parley.config.repo_root ~= "" then
-    return "⊚"
-  end
   return "○"
 end
 
 M.format_branch_label = function(branch)
   if not branch or branch == "" then return "" end
 
   local label = branch
   local separator = branch:find("[%s%-%_]")
   if separator and separator > 1 then
     label = branch:sub(1, separator)
   end
   if #label > 10 then
     label = label:sub(1, 10)
   end
   if #label < #branch then
     return label .. "..."
   end
   return label
 end
 
 M.create_branch_component = function(component)
   local next_component
   if component == "branch" then
     next_component = { "branch" }
   else
     next_component = {}
     for k, v in pairs(component) do
       next_component[k] = v
     end
   end
 
   local existing_fmt = next_component.fmt
   next_component.fmt = function(branch, ...)
     if type(existing_fmt) == "function" then
       branch = existing_fmt(branch, ...)
     end
     return M.format_branch_label(branch)
   end
   return next_component
 end
 
 M.is_repo_mode = function(parley_instance)
   return parley_instance
     and parley_instance.config
     and parley_instance.config.repo_root
     and parley_instance.config.repo_root ~= ""
 end
 
 M.create_filename_component = function(parley_instance, component)
   if not M.is_repo_mode(parley_instance) then
     return component
   end
 
   return { function() return "" end }
 end
 
 -- Lualine component returning the mode glyph. Designed as a drop-in replacement
 -- for the user's `filetype` component.
 M.create_mode_component = function(parley_instance)
   local parley = parley_instance or _parley
   return {
     function()
       return M.format_mode(parley)
     end,
   }
 end
 
 -- Notes folder detection and formatting
 M.format_directory = function(parley_instance)
   local cwd = vim.fn.getcwd()
   local home = vim.env.HOME
   local notes_path = home .. "/Library/Mobile Documents/com~apple~CloudDocs/notes"
 
   -- Try to get parley instance from multiple sources
   local parley = parley_instance or _parley
   if not parley then
     local ok, parley_module = pcall(require, "parley")
     if ok then
       parley = parley_module
     end
diff --git a/tests/unit/super_repo_spec.lua b/tests/unit/super_repo_spec.lua
index 77af70d..0b127b8 100644
--- a/tests/unit/super_repo_spec.lua
+++ b/tests/unit/super_repo_spec.lua
@@ -308,182 +308,194 @@ describe("super_repo.toggle", function()
 			"---",
 			"",
 			"# bar",
 		}, archived_b)
 
 		local from_a = issues_mod.scan_issues(issues_a, { repo_name = "ariadne" })
 		assert.equal(1, #from_a)
 		assert.equal("ariadne", from_a[1].repo_name)
 		assert.equal("000007", from_a[1].id)
 		assert.is_false(from_a[1].archived)
 
 		-- include_history with override picks up the archived issue.
 		local from_b = issues_mod.scan_issues(sibling_b .. "/workshop/issues", {
 			include_history = true,
 			history_dir_override = history_b,
 			repo_name = "brain",
 		})
 		assert.equal(1, #from_b)
 		assert.equal("brain", from_b[1].repo_name)
 		assert.equal("000003", from_b[1].id)
 		assert.is_true(from_b[1].archived)
 
 		-- Single-root, no repo_name: backwards-compat (no .repo_name field set).
 		local from_a_plain = issues_mod.scan_issues(issues_a, {})
 		assert.equal(1, #from_a_plain)
 		assert.is_nil(from_a_plain[1].repo_name)
 	end)
 
 	it("expand_roots returns per-member abs paths when super-repo is active, nil otherwise", function()
 		assert.is_nil(parley.super_repo.expand_roots("workshop/issues"))
 
 		parley.toggle_super_repo()
 
 		local roots = parley.super_repo.expand_roots("workshop/issues")
 		assert.is_not_nil(roots)
 		assert.equal(3, #roots) -- ariadne + brain + parley.nvim
 		local by_name = {}
 		for _, r in ipairs(roots) do by_name[r.repo_name] = resolve(r.dir) end
 		assert.equal(resolve(sibling_a .. "/workshop/issues"), by_name["ariadne"])
 		assert.equal(resolve(sibling_b .. "/workshop/issues"), by_name["brain"])
 		assert.equal(resolve(current_repo .. "/workshop/issues"), by_name["parley.nvim"])
 
 		-- Absolute subdir is left as-is for every member (uncommon, but supported).
 		local abs = parley.super_repo.expand_roots("/abs/path")
 		for _, r in ipairs(abs) do
 			assert.equal("/abs/path", r.dir)
 		end
 
 		-- Empty / non-string subdir returns nil.
 		assert.is_nil(parley.super_repo.expand_roots(""))
 		assert.is_nil(parley.super_repo.expand_roots(nil))
 	end)
 
 	it("super-repo siblings are stripped from persisted state.json", function()
 		parley.toggle_super_repo()
 
 		-- Force a state writeback.
 		parley.refresh_state({})
 
 		local state_file = state_dir .. "/state.json"
 		assert.equal(1, vim.fn.filereadable(state_file))
 		local state = parley.helpers.file_to_table(state_file) or {}
 		local persisted_chat_dirs = state.chat_dirs or {}
 		local persisted_note_dirs = state.note_dirs or {}
 
 		-- Resolve everything before comparing
 		local function resolved_set(list)
 			local s = {}
 			for _, d in ipairs(list) do s[resolve(d)] = true end
 			return s
 		end
 		local persisted_chat_set = resolved_set(persisted_chat_dirs)
 		local persisted_note_set = resolved_set(persisted_note_dirs)
 
 		assert.is_nil(persisted_chat_set[resolve(sibling_a .. "/workshop/parley")])
 		assert.is_nil(persisted_chat_set[resolve(sibling_b .. "/workshop/parley")])
 		assert.is_nil(persisted_note_set[resolve(sibling_a .. "/workshop/notes")])
 		assert.is_nil(persisted_note_set[resolve(sibling_b .. "/workshop/notes")])
 	end)
 
-	it("lualine.format_mode returns ○ / ⊚ / ⦿ for global / repo / super-repo", function()
+	it("lualine.format_mode returns glyph plus repo label for repo-backed modes", function()
 		local lualine = require("parley.lualine")
 
 		-- Synthesize a fake parley instance for each state to keep the
 		-- assertion local (no leakage from the test's parley.setup()).
 		local global_parley = {
 			config = { repo_root = nil },
 			is_super_repo_active = function() return false end,
 		}
 		assert.equal("○", lualine.format_mode(global_parley))
 
 		local repo_parley = {
-			config = { repo_root = "/tmp/some/repo" },
+			config = { repo_root = "/tmp/some/parley.nvim" },
+			is_super_repo_active = function() return false end,
+		}
+		assert.equal("⊚-parley.nvim", lualine.format_mode(repo_parley))
+
+		local brain_parley = {
+			config = { repo_root = "/tmp/some/brain" },
 			is_super_repo_active = function() return false end,
 		}
-		assert.equal("⊚", lualine.format_mode(repo_parley))
+		assert.equal("⊚-brain", lualine.format_mode(brain_parley))
 
 		local super_parley = {
-			config = { repo_root = "/tmp/some/repo" },
+			config = { repo_root = "/tmp/some/parley.nvim" },
+			is_super_repo_active = function() return true end,
+		}
+		assert.equal("⦿-parley.nvim", lualine.format_mode(super_parley))
+
+		local super_brain_parley = {
+			config = { repo_root = "/tmp/some/brain" },
 			is_super_repo_active = function() return true end,
 		}
-		assert.equal("⦿", lualine.format_mode(super_parley))
+		assert.equal("⦿-brain", lualine.format_mode(super_brain_parley))
 	end)
 
 	it("lualine.format_branch_label shortens long SDLC branch names for display", function()
 		local lualine = require("parley.lualine")
 
 		assert.equal("000149-...", lualine.format_branch_label("000149-harden-chat-history-search-shell-out-inputs"))
 		assert.equal("000132-...", lualine.format_branch_label("000132-sdlc-repo-lock"))
 		assert.equal("main", lualine.format_branch_label("main"))
 		assert.equal("abcdefghij...", lualine.format_branch_label("abcdefghijklmno"))
 		assert.equal("release_...", lualine.format_branch_label("release_candidate"))
 		assert.equal("", lualine.format_branch_label(nil))
 		assert.equal("", lualine.format_branch_label(""))
 	end)
 
 	it("lualine.create_branch_component preserves lualine branch detection and shortens display text", function()
 		local lualine = require("parley.lualine")
 
 		local string_component = lualine.create_branch_component("branch")
 		assert.equal("branch", string_component[1])
 		assert.equal("000149-...", string_component.fmt("000149-harden-chat-history-search-shell-out-inputs"))
 
 		local table_component = lualine.create_branch_component({
 			"branch",
 			icon = "git",
 			fmt = function(branch)
 				return branch .. "_dirty"
 			end,
 		})
 		assert.equal("branch", table_component[1])
 		assert.equal("git", table_component.icon)
 		assert.equal("000149-...", table_component.fmt("000149-harden-chat-history-search-shell-out-inputs"))
 	end)
 
 	it("lualine.format_directory hides cwd labels in repo mode but keeps interview visible", function()
 		local lualine = require("parley.lualine")
 
 		local repo_parley = {
 			config = { repo_root = "/tmp/some/repo" },
 			_state = {},
 		}
 		assert.equal("", lualine.format_directory(repo_parley))
 
 		local interview_parley = {
 			config = { repo_root = "/tmp/some/repo" },
 			_state = { interview_mode = true, interview_start_time = os.time() },
 		}
 		assert.is_truthy(lualine.format_directory(interview_parley):find("INTERVIEW", 1, true))
 	end)
 
 	it("lualine.create_filename_component hides filename only in repo mode", function()
 		local lualine = require("parley.lualine")
 		local repo_parley = { config = { repo_root = "/tmp/some/repo" } }
 		local global_parley = { config = { repo_root = nil } }
 
 		local hidden = lualine.create_filename_component(repo_parley, "filename")
 		assert.is_function(hidden[1])
 		assert.equal("", hidden[1]())
 
 		local preserved = lualine.create_filename_component(global_parley, "filename")
 		assert.equal("filename", preserved)
 
 		local table_component = lualine.create_filename_component(repo_parley, {
 			"filename",
 			path = 1,
 			fmt = function() return "VISIBLE" end,
 			icon = "file",
 			draw_empty = true,
 		})
 		assert.is_function(table_component[1])
 		assert.equal("", table_component[1]())
 		assert.is_nil(table_component.path)
 		assert.is_nil(table_component.fmt)
 		assert.is_nil(table_component.icon)
 		assert.is_nil(table_component.draw_empty)
 	end)
 
 	it("lualine.setup hides configured filename components in repo mode", function()
 		local lualine = require("parley.lualine")
 		local old_lualine = package.loaded["lualine"]
 		local captured_config

exec
/bin/zsh -lc 'rg "lualine|replace_filetype|filetype|⊚|⦿|○|super-repo|repo mode" -n README.md atlas lua/parley tests/unit | head -n 200' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
README.md:42:- [`lualine.nvim`](https://github.com/nvim-lualine/lualine.nvim) for status line integration. Not missing much if not available.
lua/parley/agent_picker.lua:19:        -- so picker, buffer-top extmark, and lualine agree on the badge
atlas/index.md:47:- [Lualine Integration](ui/lualine.md): Statusline component and indicators.
atlas/index.md:55:- [Raw-Mode Logging](infra/raw_logging.md): **First-line debug tool for LLM-pipeline bugs.** Per-chat side-file logs (exchange + raw API), YAML format, lualine red flag. `:ParleyToggleExchangeLog` / `:ParleyToggleRawLog`.
lua/parley/tool_loop.lua:41:-- State accessors (used by chat_respond and M4 lualine indicator)
lua/parley/issue_finder.lua:135:    -- Compute issue roots: in super-repo mode, one per member; otherwise just the single repo.
atlas/notes/structure.md:8:Notes support multiple roots via `note_roots` config (same pattern as chat roots). The primary root receives new notes; extra roots are searchable in the finder. In repo mode, `workshop/notes/` becomes primary and the global `notes_dir` becomes extra.
atlas/traceability.yaml:212:      - lua/parley/lualine.lua
atlas/traceability.yaml:433:  ui/lualine:
atlas/traceability.yaml:435:      - lua/parley/lualine.lua
atlas/discovery/registry.md:80:- **super-repo** → base ∪ union(local over members), deduped by name (base
atlas/discovery/registry.md:110:`get_issues_repo_root`, the super-repo finder `issue_finder.lua:133`, the status
lua/parley/highlighter.lua:559:--- Pure; no _parley state dependency so it can be reused from lualine,
tests/unit/chat_finder_logic_spec.lua:917:        it("returns {} in plain repo mode", function()
tests/unit/chat_finder_logic_spec.lua:924:        it("returns nil when not in repo mode", function()
tests/unit/chat_finder_logic_spec.lua:930:        it("returns nil in super-repo mode (don't override aggregation intent)", function()
atlas/providers/agents.md:9:- Virtual text on first chat line: `[AgentName]`. Indicator badges render as a single `[...]` group appended after the name: `🔧` when `tools` is non-empty, `🌎` when web_search is enabled and supported (`🌎?` when unsupported). Combined example: `ToolSonnet[🔧🌎]`. Helpers `highlighter.agent_tool_badge` / `agent_web_search_badge` are the single source, shared by picker, lualine, and the buffer-top extmark.
tests/unit/process_directory_pattern_spec.lua:164:            -- Should contain opening fence with filetype
atlas/providers/tool_use.md:15:| `chat_history_search` | read | Search past chats across ALL chat roots (global + repo + super-repo siblings). Output is `{<repo>}/...`-prefixed. Default context `-B1 -A2`, `*.md` glob, case-insensitive. Params: `pattern`, `before`, `after`, `glob`, `case_insensitive`, `max_count` |
atlas/providers/tool_use.md:63:- **cwd-scope**: dispatcher (`resolve_path_in_cwd`) checks `path`, `file_path`, and every element of `paths` against the working directory, symlink-resolved (`fs_realpath`), so a symlink whose real path escapes is rejected. Chat tool calls and `skill_invoke` derive that working directory from `parley.neighborhood`: repo-backed Parley artifacts use the repo root; global chats/content artifacts use their own folder. Tool-enabled chat payloads also tell the agent `Relative tool paths resolve from: <root>`, so model guidance and dispatcher enforcement share the same root (#147). Read tools (`kind ~= "write"`, so an absent `kind` counts as read — same predicate as `@readonly`) may additionally reach any root in the global `tool_read_roots` config — entries are absolute (`/x`), home (`~/workspace`, `~` expanded), or relative-to-cwd (`../`); write tools (`edit_file`/`write_file`) stay cwd-confined regardless (#140). Default `tool_read_roots = {'../'}` → cwd plus its parent directory, so repo-mode peer/sibling repos are reachable by read tools; set it to `{}` for cwd-only. A rejection names the knob. `chat_history_search` deliberately accepts no path fields, so it can search chat roots that live outside cwd (global iCloud dir, super-repo siblings).
lua/parley/oauth.lua:43:local type_filetypes = {
lua/parley/oauth.lua:1176:    local filetype = type_filetypes[file_type] or ""
lua/parley/oauth.lua:1190:    return header .. "\n```" .. filetype .. "\n" .. numbered_content .. "\n```\n\n"
lua/parley/oauth.lua:1211:M._guess_remote_filetype = function(content_type, fallback_name)
lua/parley/oauth.lua:1229:        return vim.filetype.match({ filename = fallback_name }) or ""
lua/parley/oauth.lua:1287:    local filetype = M._guess_remote_filetype(content_type, name)
lua/parley/oauth.lua:1303:    return header .. "\n```" .. filetype .. "\n" .. table.concat(numbered_lines, "\n") .. "\n```\n\n"
tests/unit/super_repo_spec.lua:40:		base_dir = vim.fn.tempname() .. "-parley-super-repo-compute"
tests/unit/super_repo_spec.lua:101:		base_dir = vim.fn.tempname() .. "-parley-super-repo-toggle"
tests/unit/super_repo_spec.lua:119:		-- repo_root manually to simulate plain repo mode being active.
tests/unit/super_repo_spec.lua:336:	it("expand_roots returns per-member abs paths when super-repo is active, nil otherwise", function()
tests/unit/super_repo_spec.lua:361:	it("super-repo siblings are stripped from persisted state.json", function()
tests/unit/super_repo_spec.lua:388:	it("lualine.format_mode returns glyph plus repo label for repo-backed modes", function()
tests/unit/super_repo_spec.lua:389:		local lualine = require("parley.lualine")
tests/unit/super_repo_spec.lua:397:		assert.equal("○", lualine.format_mode(global_parley))
tests/unit/super_repo_spec.lua:403:		assert.equal("⊚-parley.nvim", lualine.format_mode(repo_parley))
tests/unit/super_repo_spec.lua:409:		assert.equal("⊚-brain", lualine.format_mode(brain_parley))
tests/unit/super_repo_spec.lua:415:		assert.equal("⦿-parley.nvim", lualine.format_mode(super_parley))
tests/unit/super_repo_spec.lua:421:		assert.equal("⦿-brain", lualine.format_mode(super_brain_parley))
tests/unit/super_repo_spec.lua:424:	it("lualine.format_branch_label shortens long SDLC branch names for display", function()
tests/unit/super_repo_spec.lua:425:		local lualine = require("parley.lualine")
tests/unit/super_repo_spec.lua:427:		assert.equal("000149-...", lualine.format_branch_label("000149-harden-chat-history-search-shell-out-inputs"))
tests/unit/super_repo_spec.lua:428:		assert.equal("000132-...", lualine.format_branch_label("000132-sdlc-repo-lock"))
tests/unit/super_repo_spec.lua:429:		assert.equal("main", lualine.format_branch_label("main"))
tests/unit/super_repo_spec.lua:430:		assert.equal("abcdefghij...", lualine.format_branch_label("abcdefghijklmno"))
tests/unit/super_repo_spec.lua:431:		assert.equal("release_...", lualine.format_branch_label("release_candidate"))
tests/unit/super_repo_spec.lua:432:		assert.equal("", lualine.format_branch_label(nil))
tests/unit/super_repo_spec.lua:433:		assert.equal("", lualine.format_branch_label(""))
tests/unit/super_repo_spec.lua:436:	it("lualine.create_branch_component preserves lualine branch detection and shortens display text", function()
tests/unit/super_repo_spec.lua:437:		local lualine = require("parley.lualine")
tests/unit/super_repo_spec.lua:439:		local string_component = lualine.create_branch_component("branch")
tests/unit/super_repo_spec.lua:443:		local table_component = lualine.create_branch_component({
tests/unit/super_repo_spec.lua:455:	it("lualine.format_directory hides cwd labels in repo mode but keeps interview visible", function()
tests/unit/super_repo_spec.lua:456:		local lualine = require("parley.lualine")
tests/unit/super_repo_spec.lua:462:		assert.equal("", lualine.format_directory(repo_parley))
tests/unit/super_repo_spec.lua:468:		assert.is_truthy(lualine.format_directory(interview_parley):find("INTERVIEW", 1, true))
tests/unit/super_repo_spec.lua:471:	it("lualine.create_filename_component hides filename only in repo mode", function()
tests/unit/super_repo_spec.lua:472:		local lualine = require("parley.lualine")
tests/unit/super_repo_spec.lua:476:		local hidden = lualine.create_filename_component(repo_parley, "filename")
tests/unit/super_repo_spec.lua:480:		local preserved = lualine.create_filename_component(global_parley, "filename")
tests/unit/super_repo_spec.lua:483:		local table_component = lualine.create_filename_component(repo_parley, {
tests/unit/super_repo_spec.lua:498:	it("lualine.setup hides configured filename components in repo mode", function()
tests/unit/super_repo_spec.lua:499:		local lualine = require("parley.lualine")
tests/unit/super_repo_spec.lua:500:		local old_lualine = package.loaded["lualine"]
tests/unit/super_repo_spec.lua:503:		package.loaded["lualine"] = {
tests/unit/super_repo_spec.lua:507:						lualine_c = {
tests/unit/super_repo_spec.lua:520:						lualine_c = {
tests/unit/super_repo_spec.lua:532:		lualine.setup({
tests/unit/super_repo_spec.lua:535:				lualine = { enable = false },
tests/unit/super_repo_spec.lua:541:		local components = captured_config.sections.lualine_c
tests/unit/super_repo_spec.lua:551:		local inactive_components = captured_config.inactive_sections.lualine_c
tests/unit/super_repo_spec.lua:555:		package.loaded["lualine"] = old_lualine
tests/unit/neighborhood_spec.lua:45:    it("returns sibling repo root for super-repo chat roots", function()
lua/parley/health.lua:30:	local has_lualine, _ = pcall(require, "lualine")
lua/parley/health.lua:31:	if has_lualine then
lua/parley/health.lua:33:		if parley_ok and parley_module.config and parley_module.config.lualine and parley_module.config.lualine.enable then
lua/parley/health.lua:34:			vim.health.ok("lualine is installed and integration is enabled")
lua/parley/health.lua:36:			vim.health.info("lualine is installed but integration is disabled (enable in config)")
lua/parley/health.lua:39:		vim.health.info("lualine is not installed (statusline integration unavailable)")
lua/parley/markdown_finder.lua:129:--- Aggregate markdown entries across super-repo members.
lua/parley/markdown_finder.lua:154:	-- Compute scan roots: super-repo members or single repo_root.
lua/parley/issues.lua:327:-- result, so every reader (get_issues_dir, get_issues_repo_root, the super-repo
lua/parley/issues.lua:592:-- opts.history_dir_override: explicit history dir (super-repo per-member); else M.get_history_dir()
lua/parley/issues.lua:593:-- opts.repo_name: if set, every returned issue is tagged with .repo_name (super-repo display)
tests/unit/picker_items_spec.lua:150:-- extmark (buffer top line), and lualine status. Ensures all three sites
atlas/chat/memory.md:20:- The `chat_history_search` tool lets agents search across ALL configured chat roots (global + repo + super-repo siblings). Use this when the user asks "do you remember when we talked about X?". Output paths are prefixed with `{<repo>}/...` so the agent can identify which repo each hit belongs to. See [Tool Use](../providers/tool_use.md).
tests/unit/chat_dirs_spec.lua:4:-- mode + super-repo, never freeform-mutated and never persisted to
lua/parley/init.lua:32:	lualine = require("parley.lualine"), -- lualine integration
lua/parley/init.lua:544:	-- get_issues_repo_root, the super-repo finder, the status autocmd, base.lua's
lua/parley/init.lua:640:	-- Brain repos auto-enter super-repo mode. A repo is a brain iff it has a
lua/parley/init.lua:806:							"super-repo: ON, but no sibling .parley repos found under " ..
lua/parley/init.lua:811:						vim.notify("super-repo: ON (" .. count .. " members)", vim.log.levels.INFO)
lua/parley/init.lua:814:					vim.notify("super-repo: OFF", vim.log.levels.INFO)
lua/parley/init.lua:976:		pcall(function() require("lualine").refresh() end)
lua/parley/init.lua:991:		pcall(function() require("lualine").refresh() end)
lua/parley/init.lua:1100:	-- Setup lualine integration if lualine is enabled
lua/parley/init.lua:1102:		if M.config.lualine and M.config.lualine.enable then
lua/parley/init.lua:1103:			M.lualine.setup(M)
lua/parley/init.lua:1182:	-- mode + super-repo, never restored from state.json. Old state files
lua/parley/init.lua:1200:	-- In repo mode, ensure repo note dir is the primary root (overrides persisted state)
lua/parley/init.lua:1247:	-- Note-mode roots are transient (super-repo toggle, or plain repo
lua/parley/init.lua:1251:	-- persisted at all (derived from config + repo + super-repo); only
lua/parley/init.lua:1438:	-- disable swapping for this buffer and set filetype to markdown
lua/parley/init.lua:2177:	-- Check if the filetype is markdown
lua/parley/init.lua:2178:	local filetype = vim.api.nvim_buf_get_option(buf, "filetype")
lua/parley/init.lua:2179:	if filetype == "markdown" then
lua/parley/init.lua:3136:	sticky_query = nil, -- Preserved {repo} filter across invocations (super-repo mode)
lua/parley/init.lua:4068:	sticky_query_initialized = false, -- One-shot guard: chat_finder.M.open seeds the default {repo} filter on first open in repo mode
lua/parley/super_repo.lua:1:-- parley.super_repo — super-repo mode (read-aggregation overlay)
lua/parley/super_repo.lua:3:-- Toggle activates a runtime overlay on top of plain repo mode:
lua/parley/super_repo.lua:9:--     repo mode does today.
lua/parley/super_repo.lua:58:--- When super-repo is active and has members, returns a list of
lua/parley/super_repo.lua:115:		_parley.logger.warning("super-repo: cwd is not inside a .parley repo")
lua/parley/super_repo.lua:121:		_parley.logger.warning("super-repo: " .. (err or "discovery failed"))
lua/parley/progress.lua:5:-- just above the statusline (detached — not lualine, not the native 'winbar' —
lua/parley/vision_finder.lua:21:    -- Compute vision roots: in super-repo mode, one per member; else just the single repo.
lua/parley/chat_finder.lua:37:-- In plain repo mode, default the chat finder's sticky filter to `{}` so chats
lua/parley/chat_finder.lua:39:-- indexes the primary chat root with `{}`; repo mode makes the repo chat root
lua/parley/chat_finder.lua:41:-- Skipped in super-repo mode: that mode's whole point is aggregating siblings,
lua/parley/chat_finder.lua:531:	-- One-shot: on the first open of a parley session, in plain repo mode,
lua/parley/lualine.lua:27:    -- Refresh lualine to show the change
lua/parley/lualine.lua:29:      require("lualine").refresh()
lua/parley/lualine.lua:44:-- Parley mode glyph for lualine. Replaces the much-wider "markdown" filetype
lua/parley/lualine.lua:46:--   ○  global     — no parley repo context (global writes)
lua/parley/lualine.lua:47:--   ⊚-name  repo       — cwd is inside a .parley repo
lua/parley/lualine.lua:48:--   ⦿-name  super-repo — super-repo toggle is on (read-aggregation across siblings)
lua/parley/lualine.lua:55:  if not parley then return "○" end
lua/parley/lualine.lua:60:      return "⦿-" .. repo_label
lua/parley/lualine.lua:62:    return "⊚-" .. repo_label
lua/parley/lualine.lua:65:    return "⦿"
lua/parley/lualine.lua:67:  return "○"
lua/parley/lualine.lua:124:-- for the user's `filetype` component.
lua/parley/lualine.lua:163:  -- Priority 2: Repo mode already has repo/branch orientation in lualine.
lua/parley/lualine.lua:274:      -- the lualine, buffer-top extmark, and agent picker all compute the
lua/parley/lualine.lua:347:      -- This lets lualine handle the color extraction properly
lua/parley/lualine.lua:361:  -- Defer the lualine setup to ensure Neovim is fully initialized
lua/parley/lualine.lua:365:    -- Check if lualine is available
lua/parley/lualine.lua:366:    local has_lualine, lualine = pcall(require, "lualine")
lua/parley/lualine.lua:367:    if not has_lualine then
lua/parley/lualine.lua:371:    -- Create the parley component if lualine integration is enabled
lua/parley/lualine.lua:373:    if config.lualine and config.lualine.enable then
lua/parley/lualine.lua:378:      -- Get existing lualine config
lua/parley/lualine.lua:379:      local has_config, existing_config = pcall(function() return lualine.get_config() end)
lua/parley/lualine.lua:384:          local section = config.lualine.section or "lualine_z"
lua/parley/lualine.lua:385:          local lualine_config = {
lua/parley/lualine.lua:390:          lualine.setup(lualine_config)
lua/parley/lualine.lua:400:      -- and (when enabled) replace filetype components with the parley mode glyph.
lua/parley/lualine.lua:401:      local replace_filetype = config.lualine and config.lualine.replace_filetype ~= false
lua/parley/lualine.lua:406:              -- "filetype" as a string component → swap directly
lua/parley/lualine.lua:407:              if replace_filetype and component == "filetype" then
lua/parley/lualine.lua:415:                -- {"filetype", ...opts}
lua/parley/lualine.lua:416:                if replace_filetype and first == "filetype" then
lua/parley/lualine.lua:434:                  -- Filetype-display function: must explicitly read bo.filetype.
lua/parley/lualine.lua:435:                  -- A bare "filetype" substring match would false-positive on any
lua/parley/lualine.lua:436:                  -- function that branches on filetype for unrelated reasons.
lua/parley/lualine.lua:437:                  elseif replace_filetype and (
lua/parley/lualine.lua:438:                    func_str:find("bo%.filetype")
lua/parley/lualine.lua:439:                    or func_str:find("bo%[\"filetype\"%]")
lua/parley/lualine.lua:440:                    or func_str:find("bo%['filetype'%]")
lua/parley/lualine.lua:455:        local section = config.lualine.section or "lualine_z"
lua/parley/lualine.lua:463:      -- Refresh lualine with the updated config
lua/parley/lualine.lua:464:      lualine.setup(existing_config)
lua/parley/lualine.lua:467:    -- Set up autocommands to refresh lualine when agent changes or a query starts/stops
lua/parley/lualine.lua:471:      -- Refresh lualine when the user switches agents
lua/parley/lualine.lua:477:            require("lualine").refresh()
lua/parley/lualine.lua:482:      -- Refresh lualine when a query starts/finishes
lua/parley/lualine.lua:488:            require("lualine").refresh()
lua/parley/lualine.lua:493:      -- Refresh lualine when super-repo toggles (mode glyph changes)
lua/parley/lualine.lua:499:            require("lualine").refresh()
lua/parley/tasker.lua:93:	-- Trigger event for lualine update
lua/parley/tasker.lua:276:	-- Trigger event for lualine update when stopping queries
lua/parley/tasker.lua:317:		-- Trigger event for lualine update
lua/parley/vision.lua:1703:    vim.bo[buf].filetype = "markdown"
atlas/modes/super_repo.md:3:Read-aggregation overlay on top of plain repo mode. When active, parley's
atlas/modes/super_repo.md:17:## Mode glyphs (lualine)
atlas/modes/super_repo.md:19:`lualine.replace_filetype = true` (default) swaps the user's filetype
atlas/modes/super_repo.md:24:| `○`            | global     | No parley repo context                      |
atlas/modes/super_repo.md:25:| `⊚-<repo>`     | repo       | cwd is inside a `.parley` repo              |
atlas/modes/super_repo.md:26:| `⦿-<repo>`     | super-repo | super-repo toggle is on                     |
atlas/modes/super_repo.md:29:`⊚-brain` in plain repo mode and `⦿-brain` when super-repo is active.
atlas/modes/super_repo.md:44:super-repo simply pushes each member's chat/note dir into `chat_roots` /
atlas/modes/super_repo.md:50:Every super-repo-aware finder (chat, note, issue, vision, markdown) preserves
atlas/modes/super_repo.md:64:`repo_root` are exactly what plain repo mode set them to. Super-repo
atlas/modes/super_repo.md:66:design (see `workshop/issues/000113-create-a-super-repo-mode.md`).
atlas/modes/super_repo.md:72:is derived on every read from `config.chat_dir + repo + super-repo`.
atlas/modes/super_repo.md:80:filter for plain repo mode's primary note root.
atlas/modes/super_repo.md:94:- `lua/parley/lualine.lua` — `format_mode`, `create_mode_component`, and
atlas/modes/super_repo.md:95:  the filetype-component auto-replace at setup time.
lua/parley/interview.lua:144:--- Start a repeating 15-second timer that refreshes lualine while interview mode is active.
lua/parley/interview.lua:156:				-- Refresh lualine to update the timer display
lua/parley/interview.lua:158:					require("lualine").refresh()
lua/parley/interview.lua:204:				require("lualine").refresh()
lua/parley/interview.lua:231:		require("lualine").refresh()
lua/parley/interview.lua:250:		require("lualine").refresh()
lua/parley/keybinding_registry.lua:199:		desc = "Toggle super-repo mode (aggregate reads across sibling .parley repos)",
lua/parley/keybinding_registry.lua:200:		help_desc = "Toggle super-repo mode",
lua/parley/system_prompt_picker.lua:89:    vim.bo[buf].filetype = "markdown"
lua/parley/helper.lua:177:---@return string # returns filetype of specified buffer
lua/parley/helper.lua:178:_H.get_filetype = function(buf)
lua/parley/helper.lua:179:	return vim.api.nvim_get_option_value("filetype", { buf = buf })

exec
/bin/zsh -lc "nl -ba tests/unit/issues_spec.lua | sed -n '760,792p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   760	    it("tolerates issues with missing deps field", function()
   761	        local list = { { id = "000010" }, { id = "000011", deps = { "000020" } } }
   762	        local parent = issues.find_parent(list, "000020")
   763	        assert.equals("000011", parent.id)
   764	    end)
   765	end)
   766	
   767	--------------------------------------------------------------------------------
   768	-- repo_label (#142)
   769	--------------------------------------------------------------------------------
   770	
   771	describe("repo_label", function()
   772	    it("returns the basename of a git root", function()
   773	        assert.equals("parley.nvim", issues.repo_label("/Users/x/workspace/parley.nvim"))
   774	        assert.equals("brain", issues.repo_label("/Users/x/workspace/brain"))
   775	    end)
   776	
   777	    it("strips trailing slashes", function()
   778	        assert.equals("pair", issues.repo_label("/Users/x/workspace/pair/"))
   779	        assert.equals("pair", issues.repo_label("/Users/x/workspace/pair///"))
   780	    end)
   781	
   782	    it("falls back to '?' for nil or empty", function()
   783	        assert.equals("?", issues.repo_label(nil))
   784	        assert.equals("?", issues.repo_label(""))
   785	    end)
   786	
   787	    it("handles a bare segment with no slashes", function()
   788	        assert.equals("repo", issues.repo_label("repo"))
   789	    end)
   790	end)

exec
/bin/zsh -lc "nl -ba lua/parley/lualine.lua | sed -n '390,510p'" in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc "nl -ba lua/parley/issues.lua | sed -n '300,340p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   300	        end
   301	    end
   302	    return nil
   303	end
   304	
   305	-- Format deps list back to YAML string
   306	M.format_deps = function(deps)
   307	    if not deps or #deps == 0 then
   308	        return "[]"
   309	    end
   310	    return "[" .. table.concat(deps, ", ") .. "]"
   311	end
   312	
   313	-- Short repo label (basename) from a git-root path, for the issue-create prompt
   314	-- (#142). Pure: trailing slashes stripped, last path segment returned; nil/empty
   315	-- → "?" so the prompt always renders.
   316	M.repo_label = function(git_root)
   317	    if not git_root or git_root == "" then
   318	        return "?"
   319	    end
   320	    local stripped = git_root:gsub("/+$", "")
   321	    return stripped:match("([^/]+)$") or stripped
   322	end
   323	
   324	-- #116 M2: resolve the effective issues_dir at setup time. Precedence:
   325	-- explicit user override > cue `discovery.home` > built-in default. PURE — the
   326	-- setup site supplies the three inputs and seeds config.issues_dir with the
   327	-- result, so every reader (get_issues_dir, get_issues_repo_root, the super-repo
   328	-- finder, the status autocmd, base.lua's issue descriptor) derives from one value.
   329	M.resolve_issues_dir = function(user_override, cue_home, builtin_default)
   330	    return user_override or cue_home or builtin_default
   331	end
   332	
   333	-- #116 M3: extract the created issue path from `sdlc issue new` output. sdlc
   334	-- writes the bare dest path to stdout (cmd/sdlc/issue.go:319); "Created <path>"
   335	-- + sync warnings go to stderr — those all carry spaces, so the path is the one
   336	-- line that is ENTIRELY a non-whitespace `*.md` token. Robust to stdout/stderr
   337	-- interleaving (we match the token, not a position). PURE. nil if no such line.
   338	M.parse_issue_new_output = function(output)
   339	    local found = nil
   340	    for line in (output or ""):gmatch("[^\r\n]+") do

 succeeded in 0ms:
   390	          lualine.setup(lualine_config)
   391	        end
   392	        return
   393	      end
   394	
   395	      -- Make sure we have a valid config object
   396	      existing_config = existing_config or {}
   397	      existing_config.sections = existing_config.sections or {}
   398	
   399	      -- Enhance existing directory components with notes detection,
   400	      -- and (when enabled) replace filetype components with the parley mode glyph.
   401	      local replace_filetype = config.lualine and config.lualine.replace_filetype ~= false
   402	      local function enhance_sections(sections)
   403	        for section_name, section_components in pairs(sections or {}) do
   404	          if type(section_components) == "table" then
   405	            for i, component in ipairs(section_components) do
   406	              -- "filetype" as a string component → swap directly
   407	              if replace_filetype and component == "filetype" then
   408	                sections[section_name][i] = M.create_mode_component(parley)
   409	              elseif component == "branch" then
   410	                sections[section_name][i] = M.create_branch_component(component)
   411	              elseif component == "filename" then
   412	                sections[section_name][i] = M.create_filename_component(parley, component)
   413	              elseif type(component) == "table" then
   414	                local first = component[1]
   415	                -- {"filetype", ...opts}
   416	                if replace_filetype and first == "filetype" then
   417	                  sections[section_name][i] = M.create_mode_component(parley)
   418	                elseif first == "branch" then
   419	                  sections[section_name][i] = M.create_branch_component(component)
   420	                elseif first == "filename" then
   421	                  sections[section_name][i] = M.create_filename_component(parley, component)
   422	                elseif type(first) == "function" then
   423	                  local func_str = string.dump(first)
   424	                  -- Directory display function (existing behaviour)
   425	                  if func_str:find("getcwd") and func_str:find("HOME") then
   426	                    sections[section_name][i] = {
   427	                      function()
   428	                        return M.format_directory(parley)
   429	                      end,
   430	                      color = function()
   431	                        return M.get_directory_color(parley)
   432	                      end
   433	                    }
   434	                  -- Filetype-display function: must explicitly read bo.filetype.
   435	                  -- A bare "filetype" substring match would false-positive on any
   436	                  -- function that branches on filetype for unrelated reasons.
   437	                  elseif replace_filetype and (
   438	                    func_str:find("bo%.filetype")
   439	                    or func_str:find("bo%[\"filetype\"%]")
   440	                    or func_str:find("bo%['filetype'%]")
   441	                  ) then
   442	                    sections[section_name][i] = M.create_mode_component(parley)
   443	                  end
   444	                end
   445	              end
   446	            end
   447	          end
   448	        end
   449	      end
   450	      enhance_sections(existing_config.sections)
   451	      enhance_sections(existing_config.inactive_sections)
   452	
   453	      -- Add parley component if enabled
   454	      if parley_component then
   455	        local section = config.lualine.section or "lualine_z"
   456	        -- Create section if it doesn't exist
   457	        if not existing_config.sections[section] then
   458	          existing_config.sections[section] = {}
   459	        end
   460	        table.insert(existing_config.sections[section], parley_component)
   461	      end
   462	
   463	      -- Refresh lualine with the updated config
   464	      lualine.setup(existing_config)
   465	    end)
   466	
   467	    -- Set up autocommands to refresh lualine when agent changes or a query starts/stops
   468	    pcall(function()
   469	      local augroup = vim.api.nvim_create_augroup("ParleyLualine", { clear = true })
   470	
   471	      -- Refresh lualine when the user switches agents
   472	      vim.api.nvim_create_autocmd("User", {
   473	        pattern = "ParleyAgentChanged",
   474	        group = augroup,
   475	        callback = function()
   476	          pcall(function()
   477	            require("lualine").refresh()
   478	          end)
   479	        end
   480	      })
   481	
   482	      -- Refresh lualine when a query starts/finishes
   483	      vim.api.nvim_create_autocmd({"User"}, {
   484	        pattern = {"ParleyQueryStarted", "ParleyQueryFinished", "ParleyDone"},
   485	        group = augroup,
   486	        callback = function()
   487	          pcall(function()
   488	            require("lualine").refresh()
   489	          end)
   490	        end
   491	      })
   492	
   493	      -- Refresh lualine when super-repo toggles (mode glyph changes)
   494	      vim.api.nvim_create_autocmd("User", {
   495	        pattern = "ParleySuperRepoChanged",
   496	        group = augroup,
   497	        callback = function()
   498	          pcall(function()
   499	            require("lualine").refresh()
   500	          end)
   501	        end
   502	      })
   503	
   504	      -- Start flashing timer when interview mode is active
   505	      -- Check initially and then monitor for changes
   506	      if parley._state and parley._state.interview_mode then
   507	        start_flash_timer()
   508	      end
   509	
   510	      -- Monitor for interview mode changes

exec
/bin/zsh -lc 'rg "ParleySuperRepoChanged|repo_root" -n lua/parley/init.lua lua/parley/lualine.lua tests/unit/super_repo_spec.lua | head -n 80' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
lua/parley/lualine.lua:57:  if parley.config and parley.config.repo_root and parley.config.repo_root ~= "" then
lua/parley/lualine.lua:58:    local repo_label = issues.repo_label(parley.config.repo_root)
lua/parley/lualine.lua:111:    and parley_instance.config.repo_root
lua/parley/lualine.lua:112:    and parley_instance.config.repo_root ~= ""
lua/parley/lualine.lua:495:        pattern = "ParleySuperRepoChanged",
tests/unit/super_repo_spec.lua:119:		-- repo_root manually to simulate plain repo mode being active.
tests/unit/super_repo_spec.lua:127:		parley.config.repo_root = current_repo
tests/unit/super_repo_spec.lua:197:	it("sets super_repo_root and super_repo_members on config", function()
tests/unit/super_repo_spec.lua:199:		assert.equal(resolve(workspace), parley.config.super_repo_root)
tests/unit/super_repo_spec.lua:214:		assert.is_nil(parley.config.super_repo_root)
tests/unit/super_repo_spec.lua:218:	it("does not modify write paths (chat_dir / notes_dir / repo_root unchanged)", function()
tests/unit/super_repo_spec.lua:221:		local repo_root_before = parley.config.repo_root
tests/unit/super_repo_spec.lua:226:		assert.equal(repo_root_before, parley.config.repo_root)
tests/unit/super_repo_spec.lua:231:		assert.equal(repo_root_before, parley.config.repo_root)
tests/unit/super_repo_spec.lua:234:	it("fails to activate when repo_root is unset", function()
tests/unit/super_repo_spec.lua:235:		parley.config.repo_root = nil
tests/unit/super_repo_spec.lua:394:			config = { repo_root = nil },
tests/unit/super_repo_spec.lua:400:			config = { repo_root = "/tmp/some/parley.nvim" },
tests/unit/super_repo_spec.lua:406:			config = { repo_root = "/tmp/some/brain" },
tests/unit/super_repo_spec.lua:412:			config = { repo_root = "/tmp/some/parley.nvim" },
tests/unit/super_repo_spec.lua:418:			config = { repo_root = "/tmp/some/brain" },
tests/unit/super_repo_spec.lua:459:			config = { repo_root = "/tmp/some/repo" },
tests/unit/super_repo_spec.lua:465:			config = { repo_root = "/tmp/some/repo" },
tests/unit/super_repo_spec.lua:473:		local repo_parley = { config = { repo_root = "/tmp/some/repo" } }
tests/unit/super_repo_spec.lua:474:		local global_parley = { config = { repo_root = nil } }
tests/unit/super_repo_spec.lua:534:				repo_root = "/tmp/some/repo",
tests/unit/super_repo_spec.lua:558:	it("fires User ParleySuperRepoChanged on toggle on and off", function()
tests/unit/super_repo_spec.lua:563:			pattern = "ParleySuperRepoChanged",
lua/parley/init.lua:74:-- from live config (repo_root + super_repo_members) via the injected M ref.
lua/parley/init.lua:544:	-- get_issues_repo_root, the super-repo finder, the status autocmd, base.lua's
lua/parley/init.lua:569:		M.config.repo_root = git_root
lua/parley/init.lua:644:	if M.config.repo_root and vim.fn.isdirectory(M.config.repo_root .. "/.brain") == 1 then
lua/parley/init.lua:807:								(M.config.super_repo_root or "?"),
lua/parley/init.lua:1201:	if M.config.repo_root and M.config.repo_note_dir then
lua/parley/init.lua:1202:		local repo_note = M.config.repo_root .. "/" .. M.config.repo_note_dir

codex
No blocking mismatch has surfaced. The only open question was whether README needed a change, but the new surface is a status display value, and the repo’s atlas pages that own lualine/super-repo behavior were updated in the window.
exec
/bin/zsh -lc "nl -ba lua/parley/init.lua | sed -n '520,590p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   520			end
   521			M.config[tbl] = nil
   522	
   523			opts[tbl] = opts[tbl] or {}
   524			for k, v in pairs(opts[tbl]) do
   525				if tbl == "hooks" then
   526					M[tbl][k] = v
   527				elseif tbl == "agents" then
   528					M[tbl][v.name] = v
   529				elseif tbl == "system_prompts" then
   530					M[tbl][v.name] = v
   531				end
   532			end
   533			opts[tbl] = nil
   534		end
   535	
   536		-- now merge the rest of opts into M.config, this would be fully override.
   537		for k, v in pairs(opts) do
   538			M.config[k] = v
   539		end
   540	
   541		-- #116 M2: seed issues_dir from the cue `discovery.home` (ariadne's issue.cue,
   542		-- exported to construct/generated/vocabulary/issue.json) when the user did NOT
   543		-- override it, so every config.issues_dir reader (get_issues_dir,
   544		-- get_issues_repo_root, the super-repo finder, the status autocmd, base.lua's
   545		-- issue descriptor) derives from the one cue source. Precedence: explicit user
   546		-- override > cue home > built-in default. home() returns nil in a fresh clone /
   547		-- pre-weave, so this is a no-op there (stays on the built-in default). Relative
   548		-- stays relative — issues_dir is in skip_prepare, never absolutized here.
   549		M.config.issues_dir = require("parley.issues").resolve_issues_dir(
   550			opts.issues_dir,
   551			require("parley.issue_vocabulary").home(),
   552			M.config.issues_dir
   553		)
   554	
   555		-- Detect parley-enabled repo via marker file and set up repo-local directories
   556		-- Skip if user explicitly set chat_dir in opts (e.g. tests)
   557		local function apply_repo_local()
   558			if opts.chat_dir then return end
   559	
   560			local marker = M.config.repo_marker
   561			if not marker then return end
   562	
   563			local git_root = M.helpers.find_git_root(vim.fn.getcwd())
   564			if git_root == "" then return end
   565	
   566			local marker_path = git_root .. "/" .. marker
   567			if vim.fn.filereadable(marker_path) ~= 1 then return end
   568	
   569			M.config.repo_root = git_root
   570	
   571			-- Ensure repo-local directories exist
   572			for _, dir in ipairs(repo_artifacts.relative_dirs(M.config)) do
   573				if dir and dir ~= "" and not dir:match("^/") then
   574					M.helpers.prepare_dir(git_root .. "/" .. dir, "repo")
   575				end
   576			end
   577	
   578			-- Prepend repo chat dir as primary, demoting global chat_dir to extra.
   579			-- Use the structured chat_roots list so labels are explicit:
   580			-- repo dir → "repo", original config.chat_dir → "global". Without
   581			-- explicit labels, the normalizer derives labels from the directory
   582			-- basename, which surfaces as e.g. {parley} in the finder when the
   583			-- global chat dir's basename is "parley".
   584			if M.config.repo_chat_dir and M.config.repo_chat_dir ~= "" then
   585				local repo_chat = git_root .. "/" .. M.config.repo_chat_dir
   586				local old_dir = M.config.chat_dir
   587				local old_dirs = M.config.chat_dirs
   588	
   589				M.config.chat_dir = repo_chat
   590				local roots = { { dir = repo_chat, label = "repo" } }

exec
/bin/zsh -lc 'rg "apply_repo_local|DirChanged|Parley.*Changed|lualine.refresh|refresh_state" -n lua/parley/init.lua lua/parley/*.lua tests/unit | head -n 160' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
lua/parley/agent_picker.lua:65:            plugin.refresh_state({ agent = item.name })
lua/parley/agent_picker.lua:67:            vim.cmd("doautocmd User ParleyAgentChanged")
lua/parley/init.lua:557:	local function apply_repo_local()
lua/parley/init.lua:635:	apply_repo_local()
lua/parley/init.lua:655:	-- repo-local dirs (issues, history, vision, notes) are resolved in apply_repo_local
lua/parley/init.lua:749:	M.refresh_state()
lua/parley/init.lua:752:		M.refresh_state({ agent = M.config.default_agent })
lua/parley/init.lua:759:				M.refresh_state()
lua/parley/init.lua:1042:		M.refresh_state({ web_search = enable })
lua/parley/init.lua:1054:		M.refresh_state({ follow_cursor = enable })
lua/parley/init.lua:1090:				M.refresh_state()
lua/parley/init.lua:1133:M.refresh_state = function(update)
lua/parley/init.lua:1195:	-- roots, apply_repo_local at setup is the single source of truth
lua/parley/init.lua:1938:	M.refresh_state({ last_chat = file_name })
lua/parley/init.lua:2630:		M.refresh_state({ last_chat = target_file })
lua/parley/init.lua:2873:			M.refresh_state({ last_chat = path_map[src] })
lua/parley/init.lua:4190:	M.refresh_state({ agent = agent_name })
lua/parley/init.lua:4192:	vim.cmd("doautocmd User ParleyAgentChanged")
lua/parley/init.lua:4215:	M.refresh_state({ system_prompt = prompt_name })
lua/parley/init.lua:4217:	vim.cmd("doautocmd User ParleySystemPromptChanged")
lua/parley/interview.lua:9:-- (refresh_state() replaces the entire M._state table, so we can't cache a direct reference)
lua/parley/init.lua:557:	local function apply_repo_local()
lua/parley/init.lua:635:	apply_repo_local()
lua/parley/init.lua:655:	-- repo-local dirs (issues, history, vision, notes) are resolved in apply_repo_local
lua/parley/init.lua:749:	M.refresh_state()
lua/parley/init.lua:752:		M.refresh_state({ agent = M.config.default_agent })
lua/parley/init.lua:759:				M.refresh_state()
lua/parley/init.lua:1042:		M.refresh_state({ web_search = enable })
lua/parley/init.lua:1054:		M.refresh_state({ follow_cursor = enable })
lua/parley/init.lua:1090:				M.refresh_state()
lua/parley/init.lua:1133:M.refresh_state = function(update)
lua/parley/init.lua:1195:	-- roots, apply_repo_local at setup is the single source of truth
lua/parley/init.lua:1938:	M.refresh_state({ last_chat = file_name })
lua/parley/init.lua:2630:		M.refresh_state({ last_chat = target_file })
lua/parley/init.lua:2873:			M.refresh_state({ last_chat = path_map[src] })
lua/parley/init.lua:4190:	M.refresh_state({ agent = agent_name })
lua/parley/init.lua:4192:	vim.cmd("doautocmd User ParleyAgentChanged")
lua/parley/init.lua:4215:	M.refresh_state({ system_prompt = prompt_name })
lua/parley/init.lua:4217:	vim.cmd("doautocmd User ParleySystemPromptChanged")
lua/parley/lualine.lua:473:        pattern = "ParleyAgentChanged",
lua/parley/lualine.lua:495:        pattern = "ParleySuperRepoChanged",
lua/parley/root_dirs.lua:241:            _parley.refresh_state({
lua/parley/root_dirs.lua:257:            _parley.refresh_state({
lua/parley/system_prompt_picker.lua:129:            plugin.refresh_state({ system_prompt = item.name })
lua/parley/system_prompt_picker.lua:131:            vim.cmd("doautocmd User ParleySystemPromptChanged")
lua/parley/system_prompt_picker.lua:201:                            plugin.refresh_state({ system_prompt = "default" })
lua/parley/system_prompt_picker.lua:241:                                plugin.refresh_state({ system_prompt = new_name })
lua/parley/super_repo.lua:106:		vim.api.nvim_exec_autocmds("User", { pattern = "ParleySuperRepoChanged", modeline = false })
tests/unit/super_repo_spec.lua:117:		-- Pass chat_dir explicitly to bypass apply_repo_local's marker auto-detection
tests/unit/super_repo_spec.lua:365:		parley.refresh_state({})
tests/unit/super_repo_spec.lua:558:	it("fires User ParleySuperRepoChanged on toggle on and off", function()
tests/unit/super_repo_spec.lua:563:			pattern = "ParleySuperRepoChanged",
tests/unit/chat_dirs_spec.lua:51:        parley.refresh_state()
tests/unit/chat_dirs_spec.lua:90:        -- refresh_state cycle they are gone.
tests/unit/chat_dirs_spec.lua:108:        parley.refresh_state()

exec
/bin/zsh -lc "nl -ba lua/parley/init.lua | sed -n '590,650p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   590				local roots = { { dir = repo_chat, label = "repo" } }
   591				if old_dir and old_dir ~= repo_chat then
   592					table.insert(roots, { dir = old_dir, label = "global" })
   593				end
   594				-- Preserve any pre-existing extras (legacy multi-root from setup
   595				-- config). They keep their default basename labels — the only
   596				-- relabels here are repo_chat → "repo" and config.chat_dir →
   597				-- "global". Issue #117 M2 will drop this preservation entirely.
   598				if type(old_dirs) == "table" then
   599					for _, d in ipairs(old_dirs) do
   600						if d ~= repo_chat and d ~= old_dir then
   601							table.insert(roots, { dir = d })
   602						end
   603					end
   604				end
   605				M.config.chat_roots = roots
   606				M.config.chat_dirs = vim.tbl_map(function(r) return r.dir end, roots)
   607			end
   608	
   609			-- Prepend repo note dir as primary, demoting global notes_dir to extra
   610			if M.config.repo_note_dir and M.config.repo_note_dir ~= "" then
   611				local repo_note = git_root .. "/" .. M.config.repo_note_dir
   612				local old_dir = M.config.notes_dir
   613				local old_dirs = M.config.note_dirs
   614	
   615				M.config.notes_dir = repo_note
   616				local extras = {}
   617				if type(old_dirs) == "table" and #old_dirs > 0 then
   618					extras = vim.deepcopy(old_dirs)
   619				end
   620				if old_dir and old_dir ~= repo_note then
   621					table.insert(extras, 1, old_dir)
   622				end
   623				M.config.note_dirs = extras
   624				M.config.note_roots = {}
   625			end
   626	
   627			-- Disable chat memory and memory prefs for repo-local chats
   628			if type(M.config.chat_memory) == "table" then
   629				M.config.chat_memory.enable = false
   630			end
   631			if type(M.config.memory_prefs) == "table" then
   632				M.config.memory_prefs.enable = false
   633			end
   634		end
   635		apply_repo_local()
   636	
   637		apply_chat_roots(normalize_chat_roots(M.config.chat_dir, M.config.chat_dirs, M.config.chat_roots))
   638		apply_note_roots(normalize_note_roots(M.config.notes_dir, M.config.note_dirs, M.config.note_roots))
   639	
   640		-- Brain repos auto-enter super-repo mode. A repo is a brain iff it has a
   641		-- `.brain/` directory at root (constitution convention). Deferred to
   642		-- VimEnter so chat_roots/note_roots have settled before super_repo mutates
   643		-- them, and to avoid racing other plugins' setup().
   644		if M.config.repo_root and vim.fn.isdirectory(M.config.repo_root .. "/.brain") == 1 then
   645			vim.api.nvim_create_autocmd("VimEnter", {
   646				once = true,
   647				callback = function()
   648					if not super_repo.is_active() then
   649						super_repo.toggle()
   650					end

codex
I’m going to run the focused unit spec for the touched behavior so the coverage note is based on fresh output, not the implementor’s log. This should only use test temp files, not modify the repo.
exec
/bin/zsh -lc 'make test-file FILE=tests/unit/super_repo_spec.lua' in /Users/xianxu/workspace/parley.nvim
 exited 2 in 0ms:
make: *** No rule to make target `test-file'.  Stop.

codex
The expected focused Make target doesn’t exist here, so I’m checking the repo’s test commands and will either run the documented equivalent or call out the attempted command explicitly.
exec
/bin/zsh -lc "sed -n '1,220p' TOOLING.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
# Tooling

## Development Commands
- Manual testing: Start Neovim and use `:lua require('parley').setup()` followed by `:Parley`
- Run tests: `make test` (runs all unit + integration tests via plenary.nvim in headless Neovim)
- Lint: `make lint` (requires `luacheck`; see install note below)
- Run tests for one spec: `make test-spec SPEC=chat/lifecycle` (uses `atlas/traceability.yaml` mapping)
- Run tests for changed specs: `make test-changed` (runs mapped tests for changed `atlas/*/*.md` files), this is faster than full test run
- Refresh SSE fixtures: `ANTHROPIC_API_KEY=... OPENAI_API_KEY=... make fixtures`
- Test files live in `tests/unit/` (pure logic, no Neovim APIs) and `tests/integration/` (full Neovim runtime)

## Installing `luacheck` (macOS)

`luacheck` 1.2.0 (current stable) is incompatible with Lua 5.5's stricter
`<const>` semantics — loading fails with `attempt to assign to const variable
'field_name'`. Brew's `lua` formula tracks latest, so a fresh
`brew install luarocks` pulls in 5.5 and breaks lint.

Install against Lua 5.4 instead:

```
brew install lua@5.4
luarocks --lua-version=5.4 install luacheck
ln -sf "$(brew --prefix lua@5.4)/bin/luacheck-5.4" "$(brew --prefix)/bin/luacheck"
```

Verify with `luacheck --version`. If `make test` still complains, ensure
`luacheck` is on `PATH` ahead of any 5.5 install.

exec
/bin/zsh -lc "sed -n '1,200p' Makefile" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
# Canonical repo name from git remote (portable across worktrees and containers)
REPO_NAME := $(shell git remote get-url origin 2>/dev/null | sed 's|.*/||; s|\.git$$||')

# This project nests issues and history under workshop/
WF_ISSUES_DIR = workshop/issues
WF_HISTORY_DIR = workshop/history

# Assemble sub-Makefiles (Makefile.workflow already includes .openshell/Makefile)
include Makefile.workflow
-include Makefile.local

.PHONY: help

# help-sandbox, help-tart, and help-colima are defined by .openshell/Makefile,
# .tart/Makefile, and .colima/Makefile respectively, all included via
# Makefile.workflow's -include lines. Every consumer that vendors the ariadne
# base layer ships all three fragments (see construct/base.manifest), so these
# targets always resolve. If a consumer ever drops .openshell, .tart, or
# .colima from its manifest, the corresponding help-X line would need to come
# out. Transient window: a consumer that pulls this updated Makefile before
# running setup.sh to materialize the new .colima/Makefile symlink will get a
# "No rule to make target 'help-colima'" until setup runs — same accepted
# fragility the other two already carry.
help: help-workflow help-sandbox help-tart help-colima
	@true

codex
The documented focused path is `make test-spec SPEC=...`; I’m looking up the traceability key for this spec rather than guessing another target.
exec
/bin/zsh -lc 'rg "super_repo|super-repo|tests/unit/super_repo_spec.lua" -n atlas/traceability.yaml' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
204:  modes/super_repo:
206:      - lua/parley/super_repo.lua
215:      - tests/unit/super_repo_spec.lua
437:      - tests/unit/super_repo_spec.lua

exec
/bin/zsh -lc "rg \"test-spec\" -n Makefile.workflow . -g 'Makefile*'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
./Makefile.parley:4:.PHONY: help-parley test test-unit test-integration test-spec test-changed lint fixtures model-check model-checker test-clean-env
./Makefile.parley:12:	"  make test-spec SPEC=  Run tests for a specific spec key" \
./Makefile.parley:81:# Example: make test-spec SPEC=chat/lifecycle
./Makefile.parley:82:test-spec:
./Makefile.parley:84:		echo "Usage: make test-spec SPEC=chat/lifecycle"; \

codex
I found the mapped key under `modes/super_repo`; I’ll run that focused test now.
exec
/bin/zsh -lc 'make test-spec SPEC=modes/super_repo' in /Users/xianxu/workspace/parley.nvim
 succeeded in 740ms:
[32mSuccess[0m	||	super_repo.toggle activates and adds sibling chat & note roots	
[32mSuccess[0m	||	super_repo.toggle labels pushed roots with the sibling repo name (so finder shows {ariadne} etc.)	
[32mSuccess[0m	||	super_repo.toggle exposes pushed dirs via get_pushed_*_dirs for the persistence gate	
[32mSuccess[0m	||	super_repo.toggle sets super_repo_root and super_repo_members on config	
[32mSuccess[0m	||	super_repo.toggle toggle off restores prior chat & note roots	
[32mSuccess[0m	||	super_repo.toggle does not modify write paths (chat_dir / notes_dir / repo_root unchanged)	
[32mSuccess[0m	||	super_repo.toggle fails to activate when repo_root is unset	
[32mSuccess[0m	||	super_repo.toggle markdown_finder._scan_members aggregates with {repo} prefix and repo_name tag	
[32mSuccess[0m	||	super_repo.toggle scan_issues honours repo_name and history_dir_override (multi-root)	
[32mSuccess[0m	||	super_repo.toggle expand_roots returns per-member abs paths when super-repo is active, nil otherwise	
[32mSuccess[0m	||	super_repo.toggle super-repo siblings are stripped from persisted state.json	
[32mSuccess[0m	||	super_repo.toggle lualine.format_mode returns glyph plus repo label for repo-backed modes	
[32mSuccess[0m	||	super_repo.toggle lualine.format_branch_label shortens long SDLC branch names for display	
[32mSuccess[0m	||	super_repo.toggle lualine.create_branch_component preserves lualine branch detection and shortens display text	
[32mSuccess[0m	||	super_repo.toggle lualine.format_directory hides cwd labels in repo mode but keeps interview visible	
[32mSuccess[0m	||	super_repo.toggle lualine.create_filename_component hides filename only in repo mode	
[32mSuccess[0m	||	super_repo.toggle lualine.setup hides configured filename components in repo mode	
[32mSuccess[0m	||	super_repo.toggle fires User ParleySuperRepoChanged on toggle on and off	
	
[32mSuccess: [0m	23	
[31mFailed : [0m	0	
[31mErrors : [0m	0	
========================================	
Parley.nvim: super-repo: cwd is not inside a .parley repo
Parley.nvim: Directory not found: /Users/xianxu/workspace/parley.nvim/.test-tmp/nvim.xianxu/rJW0mq/22-parley-super-repo-toggle/global-note

codex
```verdict
verdict: SHIP
confidence: high
```

The diff delivers the issue purpose: repo-backed lualine mode indicators now append the shared repo label formatter, global mode remains unchanged, and atlas docs plus focused coverage were updated. I found no blocking or non-blocking findings.

1. Strengths:
- [lua/parley/lualine.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/lualine.lua:57) reuses `issues.repo_label`, keeping repo-name formatting single-sourced.
- [tests/unit/super_repo_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/unit/super_repo_spec.lua:388) pins global, normal repo, brain repo, super-repo, and super-brain outputs.
- [atlas/modes/super_repo.md](/Users/xianxu/workspace/parley.nvim/atlas/modes/super_repo.md:17) and [atlas/ui/lualine.md](/Users/xianxu/workspace/parley.nvim/atlas/ui/lualine.md:3) document the changed lualine display.

2. Critical findings: None.

3. Important findings: None.

4. Minor findings: None.

5. Test coverage notes:
- Ran `make test-spec SPEC=modes/super_repo`: passed, 23 successes, 0 failures/errors.
- Ran `git diff --check 64ecdec9d1a127a0b7ad929286e50c2877fffd22..HEAD`: passed.

6. Architectural notes:
- `ARCH-DRY`: Pass. Repo label logic derives from existing `issues.repo_label`.
- `ARCH-PURE`: Pass. The changed formatter remains deterministic over the injected parley instance.
- `ARCH-PURPOSE`: Pass. The status bar now identifies normal and brain repo cwd in repo and super-repo modes.

7. Plan revision recommendations: None.
tokens used
56,085
```verdict
verdict: SHIP
confidence: high
```

The diff delivers the issue purpose: repo-backed lualine mode indicators now append the shared repo label formatter, global mode remains unchanged, and atlas docs plus focused coverage were updated. I found no blocking or non-blocking findings.

1. Strengths:
- [lua/parley/lualine.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/lualine.lua:57) reuses `issues.repo_label`, keeping repo-name formatting single-sourced.
- [tests/unit/super_repo_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/unit/super_repo_spec.lua:388) pins global, normal repo, brain repo, super-repo, and super-brain outputs.
- [atlas/modes/super_repo.md](/Users/xianxu/workspace/parley.nvim/atlas/modes/super_repo.md:17) and [atlas/ui/lualine.md](/Users/xianxu/workspace/parley.nvim/atlas/ui/lualine.md:3) document the changed lualine display.

2. Critical findings: None.

3. Important findings: None.

4. Minor findings: None.

5. Test coverage notes:
- Ran `make test-spec SPEC=modes/super_repo`: passed, 23 successes, 0 failures/errors.
- Ran `git diff --check 64ecdec9d1a127a0b7ad929286e50c2877fffd22..HEAD`: passed.

6. Architectural notes:
- `ARCH-DRY`: Pass. Repo label logic derives from existing `issues.repo_label`.
- `ARCH-PURE`: Pass. The changed formatter remains deterministic over the injected parley instance.
- `ARCH-PURPOSE`: Pass. The status bar now identifies normal and brain repo cwd in repo and super-repo modes.

7. Plan revision recommendations: None.
