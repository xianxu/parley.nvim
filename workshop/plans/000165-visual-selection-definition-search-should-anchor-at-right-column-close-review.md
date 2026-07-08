# Boundary Review — parley.nvim#165 (whole-issue close)

| field | value |
|-------|-------|
| issue | 165 — visual selection definition search should anchor at right column |
| repo | parley.nvim |
| issue file | workshop/issues/000165-visual-selection-definition-search-should-anchor-at-right-column.md |
| boundary | whole-issue close |
| milestone | — |
| window | f6a30c828203da4e048e9651c78345e2c50b65a1..HEAD |
| command | sdlc close --issue 165 |
| reviewer | codex |
| timestamp | 2026-07-08T08:31:46-07:00 |
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
session id: 019f425a-5148-7fb1-b496-87b5510041c4
--------
user
# Code review — the one SDLC boundary review

You are conducting a fresh-context code review at a development boundary —
whole-issue close — in the **parley.nvim** repository.

- repository: parley.nvim   (root: /Users/xianxu/workspace/parley.nvim)
- issue:      parley.nvim#165   (file: workshop/issues/000165-visual-selection-definition-search-should-anchor-at-right-column.md)
- window:     Base: f6a30c828203da4e048e9651c78345e2c50b65a1   Head: HEAD

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
index 4ad823a..e5e29d7 100644
--- a/atlas/chat/inline_define.md
+++ b/atlas/chat/inline_define.md
@@ -29,8 +29,10 @@ added the bracket/highlight/undo).
    `nvim_buf_set_lines` (`define.bracket_edit` plans it) — a single undo entry
    that anchors everything; **(b)** highlights the line(s) whole-line
    `DiffChange` (`skill_render.highlight_line`); **(c)** sets one INFO
-   `vim.diagnostic` (`define.format_definition` → `skill_render.wrap`) on the
-   `parley_skill` namespace; **(d)** records the undo/redo projection states.
+   `vim.diagnostic` on the selected term span after bracket insertion
+   (`define.diagnostic_span_after_bracket`, `define.format_definition` →
+   `skill_render.wrap`) on the `parley_skill` namespace; **(d)** records the
+   undo/redo projection states.
    `diag_display`'s `virtual_lines{current_line=true}` reveals the diagnostic
    (cursor parked on the term's line). A no-`emit_definition` response leaves no
    bracket.
@@ -52,7 +54,8 @@ brackets the edit so a prior define's watcher doesn't mistake it for a user edit
 
 - **Pure** (`lua/parley/define.lua`, unit-tested with plain tables): `slice_selection`,
   `context_for_selection`, `format_definition`, `bracket_edit` (plans the `[term]`
-  wrap as a set_lines edit).
+  wrap as a set_lines edit), `diagnostic_span_after_bracket` (maps the visual span
+  to the post-bracket diagnostic range).
 - **IO shell** (`lua/parley/init.lua`): `define_visual`, `render_definition`.
 - **External service** (Anthropic) exercised via the process-level fake reused
   from `skill_invoke_spec` (SSE tool-call injection).
diff --git a/lua/parley/define.lua b/lua/parley/define.lua
index 2dae423..5253cb6 100644
--- a/lua/parley/define.lua
+++ b/lua/parley/define.lua
@@ -111,4 +111,20 @@ function M.bracket_edit(lines, l1, c1, l2, c2)
     return { first0 = l1 - 1, last = l2, lines = new_lines }
 end
 
+--- Convert a visual span from getpos columns to the diagnostic range after
+--- bracket_edit inserts "[" before the selection and "]" after it.
+--- @param l1 integer 1-based start line
+--- @param c1 integer 1-based start column from getpos("'<")
+--- @param l2 integer 1-based end line
+--- @param c2 integer 1-based inclusive end column from getpos("'>")
+--- @return table { lnum: integer, col: integer, end_lnum: integer, end_col: integer }
+function M.diagnostic_span_after_bracket(l1, c1, l2, c2)
+    return {
+        lnum = l1 - 1,
+        col = c1,
+        end_lnum = l2 - 1,
+        end_col = (l1 == l2) and (c2 + 1) or c2,
+    }
+end
+
 return M
diff --git a/lua/parley/init.lua b/lua/parley/init.lua
index f467d93..67429aa 100644
--- a/lua/parley/init.lua
+++ b/lua/parley/init.lua
@@ -1648,11 +1648,12 @@ local function render_definition(buf, span, phrase, result)
 	local input = call.input or {}
 	local width = math.max(40, vim.api.nvim_win_get_width(0) - 8)
 	local msg = define.format_definition(input.term, input.definition, width)
+	local diag_span = define.diagnostic_span_after_bracket(sr, sc, er, ec)
 	vim.diagnostic.set(skill_render.diag_namespace(), buf, { {
-		lnum = e.first0,
-		col = 0,
-		end_lnum = e.first0,
-		end_col = 0,
+		lnum = diag_span.lnum,
+		col = diag_span.col,
+		end_lnum = diag_span.end_lnum,
+		end_col = diag_span.end_col,
 		message = msg,
 		severity = vim.diagnostic.severity.INFO,
 		source = "parley-define",
diff --git a/tests/integration/define_spec.lua b/tests/integration/define_spec.lua
index 3caecf9..9998aba 100644
--- a/tests/integration/define_spec.lua
+++ b/tests/integration/define_spec.lua
@@ -252,6 +252,9 @@ describe("define_visual + render_definition (#161)", function()
         -- diagnostic on the term's line
         local diags = vim.diagnostic.get(buf, { namespace = ns })
         assert.are.equal(2, diags[1].lnum) -- 0-based line 3
+        assert.are.equal(9, diags[1].col) -- selected ASIN after inserted "["
+        assert.are.equal(2, diags[1].end_lnum)
+        assert.are.equal(13, diags[1].end_col) -- exclusive, before inserted "]"
         assert.is_true(diags[1].message:find("ASIN", 1, true) ~= nil)
         -- whole-line DiffChange highlight on the hl namespace, on line 3
         assert.is_true(hl_on_line(buf, 2), "term line not highlighted")
diff --git a/tests/unit/define_spec.lua b/tests/unit/define_spec.lua
index 6fdb87f..0f49a24 100644
--- a/tests/unit/define_spec.lua
+++ b/tests/unit/define_spec.lua
@@ -103,3 +103,25 @@ describe("define.bracket_edit", function()
         assert.are.same({ "brown [fox", "jumps over", "the] dog" }, e.lines)
     end)
 end)
+
+describe("define.diagnostic_span_after_bracket", function()
+    it("anchors a single-line selection on the selected text after brackets", function()
+        local span = define.diagnostic_span_after_bracket(3, 9, 3, 12)
+        assert.are.same({
+            lnum = 2,
+            col = 9,
+            end_lnum = 2,
+            end_col = 13,
+        }, span)
+    end)
+
+    it("anchors a multi-line selection without shifting the final line", function()
+        local span = define.diagnostic_span_after_bracket(1, 7, 3, 3)
+        assert.are.same({
+            lnum = 0,
+            col = 7,
+            end_lnum = 2,
+            end_col = 3,
+        }, span)
+    end)
+end)


exec
/bin/zsh -lc "sed -n '1,240p' /Users/xianxu/workspace/ariadne/construct/adapted/superpowers-using-superpowers/SKILL.md" in /Users/xianxu/workspace/parley.nvim
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
Using `sdlc` for the boundary-review contract and the repo review instructions; I’ll keep this read-only and verify the diff against the issue/plan rather than the commit narrative.
exec
/bin/zsh -lc 'sdlc --help' in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc "sed -n '1,260p' workshop/issues/000165-visual-selection-definition-search-should-anchor-at-right-column.md" in /Users/xianxu/workspace/parley.nvim
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

 succeeded in 0ms:
---
id: 000165
status: working
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 1.00
started: 2026-07-08T08:23:50-07:00
---

# visual selection definition search should anchor at right column

right now, the diagnosis is anchored on the whole paragraph containing the visual selection, instead just the visually selected text span.

## Problem

`define_visual` preserves the selected phrase and wraps that exact span in
`[term]`, but `render_definition` attaches the resulting diagnostic at column
zero with no end column. For a selected term inside a paragraph, the definition
diagnostic is therefore anchored to the line/paragraph instead of the visual
selection that triggered the lookup.

## Spec

When a visual selection is defined, the inline definition diagnostic must carry
the post-render span of the selected text. For a single-line selection inside a
paragraph, that means the diagnostic starts at the selected text's left column
after the opening `[` is inserted and ends at the selected text's right column
before the closing `]`.

The existing exchange-context lookup, bracket edit, whole-line highlight, and
undo/redo projection behavior stay unchanged. ARCH-PURE: any new column math
should remain pure/testable or be a direct mapping from the already captured
visual span; `render_definition` remains the thin Neovim IO shell. ARCH-DRY: the
fix must reuse the existing `span`/`bracket_edit` data rather than re-scanning the
paragraph for the term. ARCH-PURPOSE: the diagnostic range, not just the bracket
text, is the acceptance surface.

## Done when

- A visual selection definition in paragraph text produces a diagnostic whose
  `col`/`end_col` match the selected term span in the bracketed buffer.
- Existing define behavior still brackets the term, highlights the affected
  lines, shows the definition message, and preserves undo/redo projection.
- Focused define tests and the full suite pass.

## Estimate

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.10 impl=0.00
item: lua-neovim design=0.25 impl=0.35
item: milestone-review design=0.00 impl=0.20
design-buffer: 0.30
total: 1.00
```

## Plan

- [x] Add a failing integration assertion for the diagnostic's selected-text
      `col`/`end_col` after `[term]` insertion.
- [x] Update the define render path so the diagnostic range is anchored to the
      selected span's post-bracket columns.
- [x] Run focused define tests, then `make test`.

## Log

### 2026-07-08
- Claimed the issue and entered planning. Root cause: `render_definition` writes
  `col = 0/end_col = 0` even though it already receives the visual span.
- TDD red: `tests/integration/define_spec.lua` failed with diagnostic `col = 0`
  where the selected term should start at `9`.
- Implemented `define.diagnostic_span_after_bracket` (ARCH-PURE) and wired
  `render_definition` to use it; focused unit/integration define specs pass.
- Full `make test` passed after one transient unrelated
  `tests/unit/tools_builtin_find_spec.lua` failure reproduced green in isolation
  and on rerun.

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
- **To make a decoration-only action undoable, anchor it to a text edit + reuse `projection` — `u` reverts text, never extmarks/diagnostics.** The operator wanted the define highlight+diagnostic undoable; native `u` can't touch pure decorations (review's are undoable only because a round edits text). Resolution: a minimal `[term]` bracket (one `set_lines` = one undo entry) as the anchor + reuse `skills/review/projection.lua` (`record_empty_for(pre)` + `record(post)` + `ensure_watch`). Caveat that shaped the design: `skill_render.snapshot`/`apply_snapshot` are **line-granular**, so the highlight must be whole-line `DiffChange` to round-trip; a column-precise span would not survive undo/redo. In headless tests, `:undo` does NOT fire `TextChanged` — `nvim_exec_autocmds("TextChanged", {buffer=buf})` to drive the projection watcher deterministically.

exec
/bin/zsh -lc 'git diff --stat f6a30c828203da4e048e9651c78345e2c50b65a1..HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
 atlas/chat/inline_define.md                        |  9 ++--
 lua/parley/define.lua                              | 16 ++++++
 lua/parley/init.lua                                |  9 ++--
 tests/integration/define_spec.lua                  |  3 ++
 tests/unit/define_spec.lua                         | 22 ++++++++
 ...inition-search-should-anchor-at-right-column.md | 58 ++++++++++++++++++++--
 6 files changed, 107 insertions(+), 10 deletions(-)

codex
I’ve confirmed the issue’s acceptance surface is narrow: the diagnostic range must match the post-bracket selected text span while preserving the existing bracket/highlight/undo path. Now I’m checking the column semantics in the surrounding implementation and tests, since off-by-one and Visual mode inclusivity are the main risk here.
exec
/bin/zsh -lc "nl -ba lua/parley/define.lua | sed -n '1,180p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
     1	-- Pure core for the inline term-definition feature (#161).
     2	-- No Neovim APIs here — these functions operate on plain tables/strings so they
     3	-- are unit-tested directly (tests/unit/define_spec.lua). The IO shell
     4	-- (define_visual / render_definition) lives in lua/parley/init.lua.
     5	
     6	local M = {}
     7	
     8	--- Extract the charwise-visual selection [l1,c1]..[l2,c2] from `lines`.
     9	--- l1/l2 are 1-based line numbers; c1/c2 are 0-based byte columns where c2 is
    10	--- the *inclusive* end column (matches getpos("'>") after subtracting 1).
    11	--- Multi-line spans join with "\n"; columns clamp to line length; a reversed
    12	--- span returns "".
    13	--- @param lines string[]
    14	--- @param l1 integer
    15	--- @param c1 integer
    16	--- @param l2 integer
    17	--- @param c2 integer
    18	--- @return string
    19	function M.slice_selection(lines, l1, c1, l2, c2)
    20	    if l1 > l2 or (l1 == l2 and c1 > c2) then
    21	        return ""
    22	    end
    23	    if l1 == l2 then
    24	        local line = lines[l1] or ""
    25	        return line:sub(c1 + 1, math.min(c2 + 1, #line))
    26	    end
    27	    local out = {}
    28	    for l = l1, l2 do
    29	        local line = lines[l] or ""
    30	        if l == l1 then
    31	            out[#out + 1] = line:sub(c1 + 1)
    32	        elseif l == l2 then
    33	            out[#out + 1] = line:sub(1, math.min(c2 + 1, #line))
    34	        else
    35	            out[#out + 1] = line
    36	        end
    37	    end
    38	    return table.concat(out, "\n")
    39	end
    40	
    41	--- The bounded context sent to the model: the line range of the enclosing
    42	--- exchange of `sel_line`, else the whole buffer. `find_exchange` is injected
    43	--- (default = require("parley").find_exchange_at_line) so this stays pure and
    44	--- unit-testable with a synthetic parsed_chat + finder.
    45	--- @param parsed_chat table  -- { exchanges = { { question={line_start,line_end}, answer={...}|nil }, ... } }
    46	--- @param sel_line integer   -- 1-based line of the selection
    47	--- @param all_lines string[]
    48	--- @param find_exchange fun(pc:table, line:integer):integer|nil
    49	--- @return string
    50	function M.context_for_selection(parsed_chat, sel_line, all_lines, find_exchange)
    51	    find_exchange = find_exchange or require("parley").find_exchange_at_line
    52	    local idx = find_exchange(parsed_chat, sel_line)
    53	    local ex = idx and parsed_chat.exchanges and parsed_chat.exchanges[idx]
    54	    if not ex then
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
    67	--- Delegates wrapping to skill_render.wrap (the same wrap the review path uses).
    68	--- @param term string|nil
    69	--- @param definition string|nil
    70	--- @param width integer|nil
    71	--- @return string
    72	function M.format_definition(term, definition, width)
    73	    definition = definition or ""
    74	    definition = (definition:gsub("%s+$", "")) -- parens → keep only the string
    75	    if definition == "" then
    76	        definition = "(no definition)"
    77	    end
    78	    local head = tostring(term or "") .. " — " .. definition
    79	    return require("parley.skill_render").wrap(head, width or 80)
    80	end
    81	
    82	--- Plan the reference-bracket wrap of the selection ([term]) as a set_lines edit
    83	--- (#161 R1). Same arg convention as slice_selection (l1/l2 1-based, c1/c2
    84	--- 0-based byte, c2 inclusive). Returns the affected 0-based line range + the
    85	--- rewritten lines (selection wrapped in `[ ]`) for a single
    86	--- `nvim_buf_set_lines(buf, first0, last, false, lines)` — one undo entry (the
    87	--- anchor). `nvim_buf_set_text` is arch-forbidden outside buffer_edit; set_lines
    88	--- is the same primitive `drill_in_visual` uses to wrap a selection. Pure.
    89	--- @param lines string[]
    90	--- @param l1 integer
    91	--- @param c1 integer
    92	--- @param l2 integer
    93	--- @param c2 integer
    94	--- @return table  { first0, last, lines }
    95	function M.bracket_edit(lines, l1, c1, l2, c2)
    96	    local selected = M.slice_selection(lines, l1, c1, l2, c2)
    97	    local first = lines[l1] or ""
    98	    local last = lines[l2] or ""
    99	    local new_lines = {}
   100	    if l1 == l2 then
   101	        local ec = math.min(c2 + 1, #first)
   102	        new_lines[1] = first:sub(1, c1) .. "[" .. selected .. "]" .. first:sub(ec + 1)
   103	    else
   104	        local ec = math.min(c2 + 1, #last)
   105	        new_lines[1] = first:sub(1, c1) .. "[" .. first:sub(c1 + 1)
   106	        for l = l1 + 1, l2 - 1 do
   107	            new_lines[#new_lines + 1] = lines[l]
   108	        end
   109	        new_lines[#new_lines + 1] = last:sub(1, ec) .. "]" .. last:sub(ec + 1)
   110	    end
   111	    return { first0 = l1 - 1, last = l2, lines = new_lines }
   112	end
   113	
   114	--- Convert a visual span from getpos columns to the diagnostic range after
   115	--- bracket_edit inserts "[" before the selection and "]" after it.
   116	--- @param l1 integer 1-based start line
   117	--- @param c1 integer 1-based start column from getpos("'<")
   118	--- @param l2 integer 1-based end line
   119	--- @param c2 integer 1-based inclusive end column from getpos("'>")
   120	--- @return table { lnum: integer, col: integer, end_lnum: integer, end_col: integer }
   121	function M.diagnostic_span_after_bracket(l1, c1, l2, c2)
   122	    return {
   123	        lnum = l1 - 1,
   124	        col = c1,
   125	        end_lnum = l2 - 1,
   126	        end_col = (l1 == l2) and (c2 + 1) or c2,
   127	    }
   128	end
   129	
   130	return M

exec
/bin/zsh -lc "nl -ba lua/parley/init.lua | sed -n '1600,1685p'" in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc 'git diff --unified=80 f6a30c828203da4e048e9651c78345e2c50b65a1..HEAD -- lua/parley/define.lua lua/parley/init.lua tests/unit/define_spec.lua tests/integration/define_spec.lua workshop/issues/000165-visual-selection-definition-search-should-anchor-at-right-column.md atlas/chat/inline_define.md' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
  1600	-- coherence reuses review's projection watcher: undoing the bracket lands on the
  1601	-- pre-bracket content-hash → the empty snapshot renders → both decorations clear.
  1602	-- `span` = the visual selection {sr, sc, er, ec} (1-based getpos values).
  1603	local function render_definition(buf, span, phrase, result)
  1604		-- Pick the emit_definition call (unforced → the model may answer in text or
  1605		-- only call web_search; both mean "no definition"). Notify rather than
  1606		-- silently doing nothing, and leave no bracket.
  1607		local call
  1608		if result and result.calls then
  1609			for _, c in ipairs(result.calls) do
  1610				if c.name == "emit_definition" then
  1611					call = c
  1612					break
  1613				end
  1614			end
  1615		end
  1616		if not call then
  1617			M.logger.warning("Define: no definition returned")
  1618			return
  1619		end
  1620	
  1621		local sr, sc, er, ec = span[1], span[2], span[3], span[4]
  1622		local define = require("parley.define")
  1623		local skill_render = require("parley.skill_render")
  1624		local projection = require("parley.skills.review.projection")
  1625	
  1626		-- The buffer may have changed under the in-flight call; skip bracketing (and
  1627		-- the whole render) rather than mis-place a bracket on shifted text.
  1628		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  1629		if define.slice_selection(lines, sr, sc - 1, er, ec - 1) ~= phrase then
  1630			M.logger.warning("Define: selection changed during lookup — re-select to define")
  1631			return
  1632		end
  1633		local original = table.concat(lines, "\n") -- pre-bracket content (undo base)
  1634	
  1635		-- Wrap the term in [term] as ONE set_lines edit (single undo entry = the
  1636		-- anchor; nvim_buf_set_text is arch-confined to buffer_edit, and set_lines is
  1637		-- how drill_in_visual wraps a selection too). set_applying suppresses any
  1638		-- prior define's projection watcher during our own edit (mirrors review).
  1639		projection.set_applying(buf, true)
  1640		local e = define.bracket_edit(lines, sr, sc - 1, er, ec - 1)
  1641		vim.api.nvim_buf_set_lines(buf, e.first0, e.last, false, e.lines)
  1642	
  1643		-- Highlight the term's line(s) + the ephemeral definition diagnostic.
  1644		local last0 = e.first0 + #e.lines - 1
  1645		for line0 = e.first0, last0 do
  1646			skill_render.highlight_line(buf, line0)
  1647		end
  1648		local input = call.input or {}
  1649		local width = math.max(40, vim.api.nvim_win_get_width(0) - 8)
  1650		local msg = define.format_definition(input.term, input.definition, width)
  1651		local diag_span = define.diagnostic_span_after_bracket(sr, sc, er, ec)
  1652		vim.diagnostic.set(skill_render.diag_namespace(), buf, { {
  1653			lnum = diag_span.lnum,
  1654			col = diag_span.col,
  1655			end_lnum = diag_span.end_lnum,
  1656			end_col = diag_span.end_col,
  1657			message = msg,
  1658			severity = vim.diagnostic.severity.INFO,
  1659			source = "parley-define",
  1660		} })
  1661	
  1662		-- Record projection states so undo/redo of the bracket clears/restores the
  1663		-- decorations (#133 M5 machinery, reused): pre-bracket hash → empty snapshot,
  1664		-- bracketed hash → highlight+diagnostic; attach the watcher for future undos.
  1665		projection.record_empty_for(buf, original)
  1666		projection.record(buf)
  1667		projection.ensure_watch(buf)
  1668		projection.set_applying(buf, false)
  1669	
  1670		-- Park the cursor on the term's line so diag_display's current-line
  1671		-- virtual_lines reveals the definition immediately.
  1672		pcall(vim.api.nvim_win_set_cursor, 0, { sr, math.max(0, sc - 1) })
  1673		vim.cmd("redraw")
  1674	end
  1675	
  1676	-- define_visual: the thin IO shell for visual-mode <M-CR>. Reads the selection,
  1677	-- computes the enclosing-exchange context, and fires a headless define skill
  1678	-- turn whose on_done brackets + renders the definition inline. Pure logic lives
  1679	-- in lua/parley/define.lua. Exposed as M.define_visual for the keybinding.
  1680	function M.define_visual(buf)
  1681		buf = buf or vim.api.nvim_get_current_buf()
  1682		local sp = vim.fn.getpos("'<")
  1683		local ep = vim.fn.getpos("'>")
  1684		local sr, sc = sp[2], sp[3]
  1685		local er, ec = ep[2], ep[3]

 succeeded in 0ms:
diff --git a/atlas/chat/inline_define.md b/atlas/chat/inline_define.md
index 4ad823a..e5e29d7 100644
--- a/atlas/chat/inline_define.md
+++ b/atlas/chat/inline_define.md
@@ -1,110 +1,113 @@
 # Inline Term Definition
 
 Select a phrase in a chat transcript, press **`<M-CR>`** (visual mode), and a
 concise, context-aware definition appears as an **ephemeral inline diagnostic**
 (grey `virtual_lines`) under the phrase. The term is wrapped in a `[term]`
 reference bracket + highlighted (review's `DiffChange`); the **definition text
 is never written to the file**, only the brackets. The whole annotation is
 **undoable** — `u` reverts the bracket and clears both decorations (see Undo
 below). For jargon you don't know (e.g. `ASIN`), it's a one-keystroke lookup.
 Added in [#161](../../workshop/issues/000161-inline-term-definition.md) (R1
 added the bracket/highlight/undo).
 
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
    in-flight call), then **(a)** wraps the term in `[term]` via one
    `nvim_buf_set_lines` (`define.bracket_edit` plans it) — a single undo entry
    that anchors everything; **(b)** highlights the line(s) whole-line
    `DiffChange` (`skill_render.highlight_line`); **(c)** sets one INFO
-   `vim.diagnostic` (`define.format_definition` → `skill_render.wrap`) on the
-   `parley_skill` namespace; **(d)** records the undo/redo projection states.
+   `vim.diagnostic` on the selected term span after bracket insertion
+   (`define.diagnostic_span_after_bracket`, `define.format_definition` →
+   `skill_render.wrap`) on the `parley_skill` namespace; **(d)** records the
+   undo/redo projection states.
    `diag_display`'s `virtual_lines{current_line=true}` reveals the diagnostic
    (cursor parked on the term's line). A no-`emit_definition` response leaves no
    bracket.
 
 ## Undo (`u`) — reuses review's projection
 
 Native `u` reverts *text*, not decorations. The `[term]` bracket is the one
 text change, so `u` reverts it; the decorations are cleared/restored by review's
 **projection watcher** (`skills/review/projection.lua`, #133 M5), which define
 reuses: `render_definition` calls `projection.record_empty_for(buf, original)`
 (pre-bracket hash → empty snapshot), `record(buf)` (bracketed hash → the
 highlight + diagnostic), `ensure_watch(buf)`. Undoing the bracket lands on the
 pre-bracket content-hash → the empty snapshot renders → both decorations clear;
 `<C-r>` re-renders. The highlight must be **whole-line** because
 `skill_render.snapshot`/`apply_snapshot` are line-granular. `set_applying`
 brackets the edit so a prior define's watcher doesn't mistake it for a user edit.
 
 ## Pure core vs IO shell (ARCH-PURE)
 
 - **Pure** (`lua/parley/define.lua`, unit-tested with plain tables): `slice_selection`,
   `context_for_selection`, `format_definition`, `bracket_edit` (plans the `[term]`
-  wrap as a set_lines edit).
+  wrap as a set_lines edit), `diagnostic_span_after_bracket` (maps the visual span
+  to the post-bracket diagnostic range).
 - **IO shell** (`lua/parley/init.lua`): `define_visual`, `render_definition`.
 - **External service** (Anthropic) exercised via the process-level fake reused
   from `skill_invoke_spec` (SSE tool-call injection).
 
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
 
 - One definition visible at a time (`invoke` resets the `parley_skill` namespace
   each turn); line-granular highlight (whole-line, required for the projection
   round-trip). Dismissal is via `u` (R1) — reverting the bracket clears it; the
   diagnostic also auto-hides when the cursor leaves the line. The `[term]`
   brackets persist in the file if saved (the minimal-footprint tradeoff; the
   definition text never is). Shared `parley_skill` namespace/projection with
   review still applies (rare on chat buffers).
 
 ## Key files
 
 - `lua/parley/define.lua` — pure core (slice / context / format).
 - `lua/parley/init.lua` — `define_visual`, `render_definition`, `chat_define` wiring.
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
diff --git a/lua/parley/define.lua b/lua/parley/define.lua
index 2dae423..5253cb6 100644
--- a/lua/parley/define.lua
+++ b/lua/parley/define.lua
@@ -34,81 +34,97 @@ function M.slice_selection(lines, l1, c1, l2, c2)
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
 
+--- Convert a visual span from getpos columns to the diagnostic range after
+--- bracket_edit inserts "[" before the selection and "]" after it.
+--- @param l1 integer 1-based start line
+--- @param c1 integer 1-based start column from getpos("'<")
+--- @param l2 integer 1-based end line
+--- @param c2 integer 1-based inclusive end column from getpos("'>")
+--- @return table { lnum: integer, col: integer, end_lnum: integer, end_col: integer }
+function M.diagnostic_span_after_bracket(l1, c1, l2, c2)
+    return {
+        lnum = l1 - 1,
+        col = c1,
+        end_lnum = l2 - 1,
+        end_col = (l1 == l2) and (c2 + 1) or c2,
+    }
+end
+
 return M
diff --git a/lua/parley/init.lua b/lua/parley/init.lua
index f467d93..67429aa 100644
--- a/lua/parley/init.lua
+++ b/lua/parley/init.lua
@@ -1571,165 +1571,166 @@ local function drill_in_visual(buf)
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
 
 -- Inline term definition (#161 + R1). render_definition is the on_done IO seam.
 -- On a successful lookup it wraps the term in a [term] reference bracket (ONE
 -- undo entry — the anchor), highlights the line (whole-line DiffChange, review's
 -- scheme), and shows the definition as an ephemeral INFO diagnostic. The
 -- definition text is never written to the file; only the brackets are. Undo/redo
 -- coherence reuses review's projection watcher: undoing the bracket lands on the
 -- pre-bracket content-hash → the empty snapshot renders → both decorations clear.
 -- `span` = the visual selection {sr, sc, er, ec} (1-based getpos values).
 local function render_definition(buf, span, phrase, result)
 	-- Pick the emit_definition call (unforced → the model may answer in text or
 	-- only call web_search; both mean "no definition"). Notify rather than
 	-- silently doing nothing, and leave no bracket.
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
 
 	-- The buffer may have changed under the in-flight call; skip bracketing (and
 	-- the whole render) rather than mis-place a bracket on shifted text.
 	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
 	if define.slice_selection(lines, sr, sc - 1, er, ec - 1) ~= phrase then
 		M.logger.warning("Define: selection changed during lookup — re-select to define")
 		return
 	end
 	local original = table.concat(lines, "\n") -- pre-bracket content (undo base)
 
 	-- Wrap the term in [term] as ONE set_lines edit (single undo entry = the
 	-- anchor; nvim_buf_set_text is arch-confined to buffer_edit, and set_lines is
 	-- how drill_in_visual wraps a selection too). set_applying suppresses any
 	-- prior define's projection watcher during our own edit (mirrors review).
 	projection.set_applying(buf, true)
 	local e = define.bracket_edit(lines, sr, sc - 1, er, ec - 1)
 	vim.api.nvim_buf_set_lines(buf, e.first0, e.last, false, e.lines)
 
 	-- Highlight the term's line(s) + the ephemeral definition diagnostic.
 	local last0 = e.first0 + #e.lines - 1
 	for line0 = e.first0, last0 do
 		skill_render.highlight_line(buf, line0)
 	end
 	local input = call.input or {}
 	local width = math.max(40, vim.api.nvim_win_get_width(0) - 8)
 	local msg = define.format_definition(input.term, input.definition, width)
+	local diag_span = define.diagnostic_span_after_bracket(sr, sc, er, ec)
 	vim.diagnostic.set(skill_render.diag_namespace(), buf, { {
-		lnum = e.first0,
-		col = 0,
-		end_lnum = e.first0,
-		end_col = 0,
+		lnum = diag_span.lnum,
+		col = diag_span.col,
+		end_lnum = diag_span.end_lnum,
+		end_col = diag_span.end_col,
 		message = msg,
 		severity = vim.diagnostic.severity.INFO,
 		source = "parley-define",
 	} })
 
 	-- Record projection states so undo/redo of the bracket clears/restores the
 	-- decorations (#133 M5 machinery, reused): pre-bracket hash → empty snapshot,
 	-- bracketed hash → highlight+diagnostic; attach the watcher for future undos.
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
 -- turn whose on_done brackets + renders the definition inline. Pure logic lives
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
 		if off <= pos + #line then
 			return i - 1, off - pos
 		end
 		pos = pos + #line + 1
 	end
diff --git a/tests/integration/define_spec.lua b/tests/integration/define_spec.lua
index 3caecf9..9998aba 100644
--- a/tests/integration/define_spec.lua
+++ b/tests/integration/define_spec.lua
@@ -175,160 +175,163 @@ describe("define: web-toggle payload (#161)", function()
 
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
 
     it("brackets the term, highlights the line, and shows the diagnostic (R1)", function()
         -- select "ASIN" on line 3 (cols 9..12, 1-based)
         vim.fn.setpos("'<", { buf, 3, 9, 0 })
         vim.fn.setpos("'>", { buf, 3, 12, 0 })
         require("parley").define_visual(buf)
         vim.wait(2000, function()
             return #vim.diagnostic.get(buf, { namespace = ns }) > 0
         end)
         -- [term] bracket written into the line (the undo anchor)
         assert.are.equal("here is [ASIN] in context",
             vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1])
         -- diagnostic on the term's line
         local diags = vim.diagnostic.get(buf, { namespace = ns })
         assert.are.equal(2, diags[1].lnum) -- 0-based line 3
+        assert.are.equal(9, diags[1].col) -- selected ASIN after inserted "["
+        assert.are.equal(2, diags[1].end_lnum)
+        assert.are.equal(13, diags[1].end_col) -- exclusive, before inserted "]"
         assert.is_true(diags[1].message:find("ASIN", 1, true) ~= nil)
         -- whole-line DiffChange highlight on the hl namespace, on line 3
         assert.is_true(hl_on_line(buf, 2), "term line not highlighted")
     end)
 
     it("u undoes the bracket + clears decorations; C-r restores them (R1)", function()
         vim.fn.setpos("'<", { buf, 3, 9, 0 })
         vim.fn.setpos("'>", { buf, 3, 12, 0 })
         require("parley").define_visual(buf)
         vim.wait(2000, function()
             return #vim.diagnostic.get(buf, { namespace = ns }) > 0
         end)
         assert.are.equal("here is [ASIN] in context",
             vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1])
 
         -- undo: the bracket reverts; the projection watcher (TextChanged) clears
         -- both decorations. Fire the autocmd Vim fires interactively — headless
         -- :undo doesn't trigger TextChanged on its own (the watcher itself is
         -- covered by projection's own specs; here we verify define's records).
         vim.cmd("silent undo")
         vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
         assert.are.equal("here is ASIN in context",
             vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1])
         assert.are.equal(0, #vim.diagnostic.get(buf, { namespace = ns }),
             "diagnostic not cleared on undo")
         assert.is_false(hl_on_line(buf, 2), "highlight not cleared on undo")
 
         -- redo: bracket + decorations return
         vim.cmd("silent redo")
         vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
         assert.are.equal("here is [ASIN] in context",
             vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1])
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
             "a no-tool response must not bracket the term")
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
diff --git a/tests/unit/define_spec.lua b/tests/unit/define_spec.lua
index 6fdb87f..0f49a24 100644
--- a/tests/unit/define_spec.lua
+++ b/tests/unit/define_spec.lua
@@ -26,80 +26,102 @@ describe("define.slice_selection", function()
 end)
 
 describe("define.context_for_selection", function()
     local all_lines = {}
     for i = 1, 20 do
         all_lines[i] = "line " .. i
     end
     local parsed = {
         exchanges = {
             { question = { line_start = 3, line_end = 4 }, answer = { line_start = 5, line_end = 8 } },
             { question = { line_start = 10, line_end = 10 }, answer = nil },
         },
     }
     -- injected finder: idx if sel_line within [q.start, (a and a.end or q.end)]
     local function finder(pc, line)
         for i, ex in ipairs(pc.exchanges) do
             local lo = ex.question.line_start
             local hi = (ex.answer and ex.answer.line_end) or ex.question.line_end
             if line >= lo and line <= hi then
                 return i, "question"
             end
         end
         return nil, nil
     end
 
     it("returns the enclosing exchange's lines (question..answer)", function()
         local ctx = define.context_for_selection(parsed, 6, all_lines, finder)
         assert.equals("line 3\nline 4\nline 5\nline 6\nline 7\nline 8", ctx)
     end)
 
     it("handles an answerless exchange (question only)", function()
         local ctx = define.context_for_selection(parsed, 10, all_lines, finder)
         assert.equals("line 10", ctx)
     end)
 
     it("falls back to the whole buffer when outside any exchange", function()
         local ctx = define.context_for_selection(parsed, 1, all_lines, finder)
         assert.equals(table.concat(all_lines, "\n"), ctx)
     end)
 end)
 
 describe("define.format_definition", function()
     it("composes 'TERM — definition'", function()
         local msg = define.format_definition("ASIN", "Amazon Standard Identification Number.", 200)
         assert.equals("ASIN — Amazon Standard Identification Number.", msg)
     end)
 
     it("hard-wraps to width", function()
         local msg = define.format_definition("X", string.rep("word ", 30), 40)
         for _, l in ipairs(vim.split(msg, "\n", { plain = true })) do
             assert.is_true(#l <= 40)
         end
     end)
 
     it("trims a nil/blank definition to a safe string", function()
         assert.equals("X — (no definition)", define.format_definition("X", nil, 80))
     end)
 end)
 
 describe("define.bracket_edit", function()
     it("wraps a single-line span into a set_lines edit", function()
         -- "here is ASIN in context": ASIN at 0-based cols 8..11 inclusive
         local e = define.bracket_edit({ "here is ASIN in context" }, 1, 8, 1, 11)
         assert.are.equal(0, e.first0)
         assert.are.equal(1, e.last)
         assert.are.same({ "here is [ASIN] in context" }, e.lines)
     end)
 
     it("clamps end col past line length", function()
         local e = define.bracket_edit({ "the lazy dog" }, 1, 9, 1, 999)
         assert.are.same({ "the lazy [dog]" }, e.lines)
     end)
 
     it("wraps a multi-line span", function()
         local e = define.bracket_edit({ "brown fox", "jumps over", "the dog" }, 1, 6, 3, 2)
         assert.are.equal(0, e.first0)
         assert.are.equal(3, e.last)
         assert.are.same({ "brown [fox", "jumps over", "the] dog" }, e.lines)
     end)
 end)
+
+describe("define.diagnostic_span_after_bracket", function()
+    it("anchors a single-line selection on the selected text after brackets", function()
+        local span = define.diagnostic_span_after_bracket(3, 9, 3, 12)
+        assert.are.same({
+            lnum = 2,
+            col = 9,
+            end_lnum = 2,
+            end_col = 13,
+        }, span)
+    end)
+
+    it("anchors a multi-line selection without shifting the final line", function()
+        local span = define.diagnostic_span_after_bracket(1, 7, 3, 3)
+        assert.are.same({
+            lnum = 0,
+            col = 7,
+            end_lnum = 2,
+            end_col = 3,
+        }, span)
+    end)
+end)
diff --git a/workshop/issues/000165-visual-selection-definition-search-should-anchor-at-right-column.md b/workshop/issues/000165-visual-selection-definition-search-should-anchor-at-right-column.md
index 5e04218..eecdb7e 100644
--- a/workshop/issues/000165-visual-selection-definition-search-should-anchor-at-right-column.md
+++ b/workshop/issues/000165-visual-selection-definition-search-should-anchor-at-right-column.md
@@ -1,30 +1,82 @@
 ---
 id: 000165
 status: working
 deps: []
 github_issue:
 created: 2026-07-08
 updated: 2026-07-08
-estimate_hours:
+estimate_hours: 1.00
 started: 2026-07-08T08:23:50-07:00
 ---
 
 # visual selection definition search should anchor at right column
 
 right now, the diagnosis is anchored on the whole paragraph containing the visual selection, instead just the visually selected text span.
 
 ## Problem
 
+`define_visual` preserves the selected phrase and wraps that exact span in
+`[term]`, but `render_definition` attaches the resulting diagnostic at column
+zero with no end column. For a selected term inside a paragraph, the definition
+diagnostic is therefore anchored to the line/paragraph instead of the visual
+selection that triggered the lookup.
+
 ## Spec
 
+When a visual selection is defined, the inline definition diagnostic must carry
+the post-render span of the selected text. For a single-line selection inside a
+paragraph, that means the diagnostic starts at the selected text's left column
+after the opening `[` is inserted and ends at the selected text's right column
+before the closing `]`.
+
+The existing exchange-context lookup, bracket edit, whole-line highlight, and
+undo/redo projection behavior stay unchanged. ARCH-PURE: any new column math
+should remain pure/testable or be a direct mapping from the already captured
+visual span; `render_definition` remains the thin Neovim IO shell. ARCH-DRY: the
+fix must reuse the existing `span`/`bracket_edit` data rather than re-scanning the
+paragraph for the term. ARCH-PURPOSE: the diagnostic range, not just the bracket
+text, is the acceptance surface.
+
 ## Done when
 
--
+- A visual selection definition in paragraph text produces a diagnostic whose
+  `col`/`end_col` match the selected term span in the bracketed buffer.
+- Existing define behavior still brackets the term, highlights the affected
+  lines, shows the definition message, and preserves undo/redo projection.
+- Focused define tests and the full suite pass.
+
+## Estimate
+
+Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
+`baseline-v3.1.md`. Method A only.
+
+```estimate
+model: estimate-logic-v3.1
+familiarity: 1.0
+item: issue-spec design=0.10 impl=0.00
+item: lua-neovim design=0.25 impl=0.35
+item: milestone-review design=0.00 impl=0.20
+design-buffer: 0.30
+total: 1.00
+```
 
 ## Plan
 
-- [ ]
+- [x] Add a failing integration assertion for the diagnostic's selected-text
+      `col`/`end_col` after `[term]` insertion.
+- [x] Update the define render path so the diagnostic range is anchored to the
+      selected span's post-bracket columns.
+- [x] Run focused define tests, then `make test`.
 
 ## Log
 
 ### 2026-07-08
+- Claimed the issue and entered planning. Root cause: `render_definition` writes
+  `col = 0/end_col = 0` even though it already receives the visual span.
+- TDD red: `tests/integration/define_spec.lua` failed with diagnostic `col = 0`
+  where the selected term should start at `9`.
+- Implemented `define.diagnostic_span_after_bracket` (ARCH-PURE) and wired
+  `render_definition` to use it; focused unit/integration define specs pass.
+- Full `make test` passed after one transient unrelated
+  `tests/unit/tools_builtin_find_spec.lua` failure reproduced green in isolation
+  and on rerun.

exec
/bin/zsh -lc "rg -n \"define_visual|render_definition|bracket_edit|diagnostic_span_after_bracket|getpos\\(\" lua tests atlas workshop/issues/000165-visual-selection-definition-search-should-anchor-at-right-column.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
workshop/issues/000165-visual-selection-definition-search-should-anchor-at-right-column.md:18:`define_visual` preserves the selected phrase and wraps that exact span in
workshop/issues/000165-visual-selection-definition-search-should-anchor-at-right-column.md:19:`[term]`, but `render_definition` attaches the resulting diagnostic at column
workshop/issues/000165-visual-selection-definition-search-should-anchor-at-right-column.md:35:visual span; `render_definition` remains the thin Neovim IO shell. ARCH-DRY: the
workshop/issues/000165-visual-selection-definition-search-should-anchor-at-right-column.md:36:fix must reuse the existing `span`/`bracket_edit` data rather than re-scanning the
workshop/issues/000165-visual-selection-definition-search-should-anchor-at-right-column.md:74:- Claimed the issue and entered planning. Root cause: `render_definition` writes
workshop/issues/000165-visual-selection-definition-search-should-anchor-at-right-column.md:78:- Implemented `define.diagnostic_span_after_bracket` (ARCH-PURE) and wired
workshop/issues/000165-visual-selection-definition-search-should-anchor-at-right-column.md:79:  `render_definition` to use it; focused unit/integration define specs pass.
lua/parley/define.lua:4:-- (define_visual / render_definition) lives in lua/parley/init.lua.
lua/parley/define.lua:10:--- the *inclusive* end column (matches getpos("'>") after subtracting 1).
lua/parley/define.lua:95:function M.bracket_edit(lines, l1, c1, l2, c2)
lua/parley/define.lua:115:--- bracket_edit inserts "[" before the selection and "]" after it.
lua/parley/define.lua:117:--- @param c1 integer 1-based start column from getpos("'<")
lua/parley/define.lua:119:--- @param c2 integer 1-based inclusive end column from getpos("'>")
lua/parley/define.lua:121:function M.diagnostic_span_after_bracket(l1, c1, l2, c2)
atlas/chat/inline_define.md:15:1. **`define_visual(buf)`** (`lua/parley/init.lua`) reads the visual selection
atlas/chat/inline_define.md:26:4. **`render_definition`** (`on_done`), on a successful lookup: re-verifies the
atlas/chat/inline_define.md:29:   `nvim_buf_set_lines` (`define.bracket_edit` plans it) — a single undo entry
atlas/chat/inline_define.md:33:   (`define.diagnostic_span_after_bracket`, `define.format_definition` →
atlas/chat/inline_define.md:45:reuses: `render_definition` calls `projection.record_empty_for(buf, original)`
atlas/chat/inline_define.md:56:  `context_for_selection`, `format_definition`, `bracket_edit` (plans the `[term]`
atlas/chat/inline_define.md:57:  wrap as a set_lines edit), `diagnostic_span_after_bracket` (maps the visual span
atlas/chat/inline_define.md:59:- **IO shell** (`lua/parley/init.lua`): `define_visual`, `render_definition`.
atlas/chat/inline_define.md:68:per-mode callback is `{ n=respond, i=respond, v=define_visual, x=define_visual }`
atlas/chat/inline_define.md:101:- `lua/parley/init.lua` — `define_visual`, `render_definition`, `chat_define` wiring.
tests/integration/define_spec.lua:193:describe("define_visual + render_definition (#161)", function()
tests/integration/define_spec.lua:245:        require("parley").define_visual(buf)
tests/integration/define_spec.lua:266:        require("parley").define_visual(buf)
tests/integration/define_spec.lua:299:        require("parley").define_visual(buf)
tests/integration/define_spec.lua:315:        require("parley").define_visual(buf)
lua/parley/skills/define/init.lua:4:-- `define_visual` (lua/parley/init.lua) via skill_invoke with args.phrase and a
lua/parley/init.lua:1538:	local sp = vim.fn.getpos("'<")
lua/parley/init.lua:1539:	local ep = vim.fn.getpos("'>")
lua/parley/init.lua:1595:-- Inline term definition (#161 + R1). render_definition is the on_done IO seam.
lua/parley/init.lua:1603:local function render_definition(buf, span, phrase, result)
lua/parley/init.lua:1640:	local e = define.bracket_edit(lines, sr, sc - 1, er, ec - 1)
lua/parley/init.lua:1651:	local diag_span = define.diagnostic_span_after_bracket(sr, sc, er, ec)
lua/parley/init.lua:1676:-- define_visual: the thin IO shell for visual-mode <M-CR>. Reads the selection,
lua/parley/init.lua:1679:-- in lua/parley/define.lua. Exposed as M.define_visual for the keybinding.
lua/parley/init.lua:1680:function M.define_visual(buf)
lua/parley/init.lua:1682:	local sp = vim.fn.getpos("'<")
lua/parley/init.lua:1683:	local ep = vim.fn.getpos("'>")
lua/parley/init.lua:1706:		on_done = function(result) render_definition(buf, span, phrase, result) end,
lua/parley/init.lua:2009:		local start_pos = vim.fn.getpos("'<")
lua/parley/init.lua:2010:		local end_pos = vim.fn.getpos("'>")
lua/parley/init.lua:2079:		M.define_visual()
lua/parley/init.lua:2106:			-- '<,'> marks then run define_visual (visual <C-g><C-g> keeps respond).
lua/parley/init.lua:2301:		local start_pos = vim.fn.getpos("'<")
lua/parley/init.lua:2302:		local end_pos = vim.fn.getpos("'>")
tests/unit/define_spec.lua:85:describe("define.bracket_edit", function()
tests/unit/define_spec.lua:88:        local e = define.bracket_edit({ "here is ASIN in context" }, 1, 8, 1, 11)
tests/unit/define_spec.lua:95:        local e = define.bracket_edit({ "the lazy dog" }, 1, 9, 1, 999)
tests/unit/define_spec.lua:100:        local e = define.bracket_edit({ "brown fox", "jumps over", "the dog" }, 1, 6, 3, 2)
tests/unit/define_spec.lua:107:describe("define.diagnostic_span_after_bracket", function()
tests/unit/define_spec.lua:109:        local span = define.diagnostic_span_after_bracket(3, 9, 3, 12)
tests/unit/define_spec.lua:119:        local span = define.diagnostic_span_after_bracket(1, 7, 3, 3)

codex
The implementation appears scoped to the existing define path: a pure helper maps captured Visual marks to the post-edit diagnostic range, and the IO shell only consumes that mapped range. I’m doing one last pass for documentation/plan traceability and architecture markers before writing the verdict.
exec
/bin/zsh -lc "nl -ba tests/integration/define_spec.lua | sed -n '235,260p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   235	        for _, m in ipairs(vim.api.nvim_buf_get_extmarks(b, hl_ns, 0, -1, {})) do
   236	            if m[2] == line0 then return true end
   237	        end
   238	        return false
   239	    end
   240	
   241	    it("brackets the term, highlights the line, and shows the diagnostic (R1)", function()
   242	        -- select "ASIN" on line 3 (cols 9..12, 1-based)
   243	        vim.fn.setpos("'<", { buf, 3, 9, 0 })
   244	        vim.fn.setpos("'>", { buf, 3, 12, 0 })
   245	        require("parley").define_visual(buf)
   246	        vim.wait(2000, function()
   247	            return #vim.diagnostic.get(buf, { namespace = ns }) > 0
   248	        end)
   249	        -- [term] bracket written into the line (the undo anchor)
   250	        assert.are.equal("here is [ASIN] in context",
   251	            vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1])
   252	        -- diagnostic on the term's line
   253	        local diags = vim.diagnostic.get(buf, { namespace = ns })
   254	        assert.are.equal(2, diags[1].lnum) -- 0-based line 3
   255	        assert.are.equal(9, diags[1].col) -- selected ASIN after inserted "["
   256	        assert.are.equal(2, diags[1].end_lnum)
   257	        assert.are.equal(13, diags[1].end_col) -- exclusive, before inserted "]"
   258	        assert.is_true(diags[1].message:find("ASIN", 1, true) ~= nil)
   259	        -- whole-line DiffChange highlight on the hl namespace, on line 3
   260	        assert.is_true(hl_on_line(buf, 2), "term line not highlighted")

exec
/bin/zsh -lc "nl -ba tests/unit/define_spec.lua | sed -n '100,135p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   100	        local e = define.bracket_edit({ "brown fox", "jumps over", "the dog" }, 1, 6, 3, 2)
   101	        assert.are.equal(0, e.first0)
   102	        assert.are.equal(3, e.last)
   103	        assert.are.same({ "brown [fox", "jumps over", "the] dog" }, e.lines)
   104	    end)
   105	end)
   106	
   107	describe("define.diagnostic_span_after_bracket", function()
   108	    it("anchors a single-line selection on the selected text after brackets", function()
   109	        local span = define.diagnostic_span_after_bracket(3, 9, 3, 12)
   110	        assert.are.same({
   111	            lnum = 2,
   112	            col = 9,
   113	            end_lnum = 2,
   114	            end_col = 13,
   115	        }, span)
   116	    end)
   117	
   118	    it("anchors a multi-line selection without shifting the final line", function()
   119	        local span = define.diagnostic_span_after_bracket(1, 7, 3, 3)
   120	        assert.are.same({
   121	            lnum = 0,
   122	            col = 7,
   123	            end_lnum = 2,
   124	            end_col = 3,
   125	        }, span)
   126	    end)
   127	end)

exec
/bin/zsh -lc 'git diff --name-only f6a30c828203da4e048e9651c78345e2c50b65a1..HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
atlas/chat/inline_define.md
lua/parley/define.lua
lua/parley/init.lua
tests/integration/define_spec.lua
tests/unit/define_spec.lua
workshop/issues/000165-visual-selection-definition-search-should-anchor-at-right-column.md

exec
/bin/zsh -lc "nl -ba atlas/chat/inline_define.md | sed -n '20,62p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
    20	2. It fires a headless **`define` skill** turn via `skill_invoke.invoke` with
    21	   `opts.document = context`, `opts.no_reload = true`, and an `on_done`.
    22	3. The `define` skill (`lua/parley/skills/define/init.lua`) is **unforced** (no
    23	   `force_tool`) so the server-side `web_search` tool can run when the global
    24	   `:ToggleWebSearch` is on; its `source(ctx)` folds the phrase into the system
    25	   prompt and asks the model to call `emit_definition({term, definition})`.
    26	4. **`render_definition`** (`on_done`), on a successful lookup: re-verifies the
    27	   selection still holds the phrase (else skips — the buffer changed under the
    28	   in-flight call), then **(a)** wraps the term in `[term]` via one
    29	   `nvim_buf_set_lines` (`define.bracket_edit` plans it) — a single undo entry
    30	   that anchors everything; **(b)** highlights the line(s) whole-line
    31	   `DiffChange` (`skill_render.highlight_line`); **(c)** sets one INFO
    32	   `vim.diagnostic` on the selected term span after bracket insertion
    33	   (`define.diagnostic_span_after_bracket`, `define.format_definition` →
    34	   `skill_render.wrap`) on the `parley_skill` namespace; **(d)** records the
    35	   undo/redo projection states.
    36	   `diag_display`'s `virtual_lines{current_line=true}` reveals the diagnostic
    37	   (cursor parked on the term's line). A no-`emit_definition` response leaves no
    38	   bracket.
    39	
    40	## Undo (`u`) — reuses review's projection
    41	
    42	Native `u` reverts *text*, not decorations. The `[term]` bracket is the one
    43	text change, so `u` reverts it; the decorations are cleared/restored by review's
    44	**projection watcher** (`skills/review/projection.lua`, #133 M5), which define
    45	reuses: `render_definition` calls `projection.record_empty_for(buf, original)`
    46	(pre-bracket hash → empty snapshot), `record(buf)` (bracketed hash → the
    47	highlight + diagnostic), `ensure_watch(buf)`. Undoing the bracket lands on the
    48	pre-bracket content-hash → the empty snapshot renders → both decorations clear;
    49	`<C-r>` re-renders. The highlight must be **whole-line** because
    50	`skill_render.snapshot`/`apply_snapshot` are line-granular. `set_applying`
    51	brackets the edit so a prior define's watcher doesn't mistake it for a user edit.
    52	
    53	## Pure core vs IO shell (ARCH-PURE)
    54	
    55	- **Pure** (`lua/parley/define.lua`, unit-tested with plain tables): `slice_selection`,
    56	  `context_for_selection`, `format_definition`, `bracket_edit` (plans the `[term]`
    57	  wrap as a set_lines edit), `diagnostic_span_after_bracket` (maps the visual span
    58	  to the post-bracket diagnostic range).
    59	- **IO shell** (`lua/parley/init.lua`): `define_visual`, `render_definition`.
    60	- **External service** (Anthropic) exercised via the process-level fake reused
    61	  from `skill_invoke_spec` (SSE tool-call injection).
    62	

codex
```verdict
verdict: SHIP
confidence: high
```

The diff fulfills #165’s stated purpose: the diagnostic now anchors to the selected text span after bracket insertion, without changing lookup, bracketing, highlighting, or undo/redo behavior. I found no blocking or non-blocking findings.

1. Strengths:
- [lua/parley/define.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/define.lua:121) keeps the column mapping pure and directly unit-tested.
- [lua/parley/init.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/init.lua:1651) preserves `render_definition` as a thin IO shell and reuses the captured visual span instead of rescanning text.
- [tests/integration/define_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/integration/define_spec.lua:253) pins the real define path’s `lnum/col/end_lnum/end_col` after `[term]` insertion.
- [atlas/chat/inline_define.md](/Users/xianxu/workspace/parley.nvim/atlas/chat/inline_define.md:32) documents the updated diagnostic anchoring behavior.

2. Critical findings: none.

3. Important findings: none.

4. Minor findings: none.

5. Test coverage notes:
- Coverage matches the bug class: unit tests cover the pure range mapping, and integration coverage verifies the live diagnostic range in the render path.
- I did not rerun the suite during this read-only boundary review.

6. Architectural notes:
- ARCH-DRY: pass. The change reuses the existing captured span and bracket-edit flow; no duplicate scanning or parallel lookup logic.
- ARCH-PURE: pass. The new range math lives in `define.lua` as a pure helper with plain-table tests; Neovim calls remain in `init.lua`.
- ARCH-PURPOSE: pass. The acceptance surface is the diagnostic range, and the diff updates that exact behavior plus a regression assertion.

7. Plan revision recommendations: none.
tokens used
43,153
```verdict
verdict: SHIP
confidence: high
```

The diff fulfills #165’s stated purpose: the diagnostic now anchors to the selected text span after bracket insertion, without changing lookup, bracketing, highlighting, or undo/redo behavior. I found no blocking or non-blocking findings.

1. Strengths:
- [lua/parley/define.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/define.lua:121) keeps the column mapping pure and directly unit-tested.
- [lua/parley/init.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/init.lua:1651) preserves `render_definition` as a thin IO shell and reuses the captured visual span instead of rescanning text.
- [tests/integration/define_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/integration/define_spec.lua:253) pins the real define path’s `lnum/col/end_lnum/end_col` after `[term]` insertion.
- [atlas/chat/inline_define.md](/Users/xianxu/workspace/parley.nvim/atlas/chat/inline_define.md:32) documents the updated diagnostic anchoring behavior.

2. Critical findings: none.

3. Important findings: none.

4. Minor findings: none.

5. Test coverage notes:
- Coverage matches the bug class: unit tests cover the pure range mapping, and integration coverage verifies the live diagnostic range in the render path.
- I did not rerun the suite during this read-only boundary review.

6. Architectural notes:
- ARCH-DRY: pass. The change reuses the existing captured span and bracket-edit flow; no duplicate scanning or parallel lookup logic.
- ARCH-PURE: pass. The new range math lives in `define.lua` as a pure helper with plain-table tests; Neovim calls remain in `init.lua`.
- ARCH-PURPOSE: pass. The acceptance surface is the diagnostic range, and the diff updates that exact behavior plus a regression assertion.

7. Plan revision recommendations: none.
