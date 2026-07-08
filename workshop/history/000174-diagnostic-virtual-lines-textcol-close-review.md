# Boundary Review — parley.nvim#174 (whole-issue close)

| field | value |
|-------|-------|
| issue | 174 — diagnostic virtual lines should align with buffer text |
| repo | parley.nvim |
| issue file | workshop/issues/000174-diagnostic-virtual-lines-textcol.md |
| boundary | whole-issue close |
| milestone | — |
| window | 8c35ad2ab117aa166c46042f00d0b2cbc1c8aa6b..HEAD |
| command | sdlc close --issue 174 |
| reviewer | codex |
| timestamp | 2026-07-08T13:40:57-07:00 |
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
session id: 019f4375-610d-76a3-b3d8-35f5acca4478
--------
user
# Code review — the one SDLC boundary review

You are conducting a fresh-context code review at a development boundary —
whole-issue close — in the **parley.nvim** repository.

- repository: parley.nvim   (root: /Users/xianxu/workspace/parley.nvim)
- issue:      parley.nvim#174   (file: workshop/issues/000174-diagnostic-virtual-lines-textcol.md)
- window:     Base: 8c35ad2ab117aa166c46042f00d0b2cbc1c8aa6b   Head: HEAD

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
index 6df2cf4..04a9d34 100644
--- a/atlas/chat/inline_define.md
+++ b/atlas/chat/inline_define.md
@@ -41,7 +41,7 @@ rehydrates persisted managed footnotes in all markdown buffers.
    inline `term[^id]` spans (`define.format_definition` →
    `skill_render.format_diagnostic_message`) on the `parley_skill` namespace;
    **(d)** records the undo/redo projection states.
-   `diag_display`'s Parley-owned left-column virtual-line display reveals the
+   `diag_display`'s Parley-owned text-column virtual-line display reveals the
    diagnostic (cursor parked on the term's line). A no-`emit_definition` response
    leaves no footnote reference/footer.
 
diff --git a/atlas/modes/review.md b/atlas/modes/review.md
index ef656df..677a948 100644
--- a/atlas/modes/review.md
+++ b/atlas/modes/review.md
@@ -163,9 +163,9 @@ The edit "why" (the per-edit `explain`) is an INFO diagnostic on parley's
 `parley_skill` namespace. `lua/parley/skills/review/diag_display.lua` controls how
 it shows — scoped to that namespace, so the user's LSP/global diagnostics are
 untouched. Default **on**: Parley's custom `parley/virtual_lines` diagnostic
-handler renders a left-column virtual-line block headed `Diagnostics:` for the
-current line. It avoids Neovim's stock virtual-lines indentation-by-diagnostic
-column, which can hide messages on long wrapped prose. The hard-wrapped why
+handler renders a text-column virtual-line block headed `Diagnostics:` for the
+current line. It avoids both gutter anchoring and Neovim's stock virtual-lines
+indentation-by-diagnostic column, which can hide messages on long wrapped prose. The hard-wrapped why
 (`skill_render.format_diagnostic_message`) **auto-expands below an edit when the
 cursor is in that edit's region** (`attach_diagnostics` spans
 `lnum..end_lnum`) and hides otherwise. `:ParleyShowDiagnostics` toggles it. The
diff --git a/lua/parley/skills/review/diag_display.lua b/lua/parley/skills/review/diag_display.lua
index a63de85..fa443d3 100644
--- a/lua/parley/skills/review/diag_display.lua
+++ b/lua/parley/skills/review/diag_display.lua
@@ -2,7 +2,7 @@
 --
 -- Controls how parley's review explanations render, scoped to parley's OWN
 -- diagnostic namespace (never touches the user's LSP / global diagnostics).
--- Default ON: a custom diagnostic handler renders left-column virtual lines for
+-- Default ON: a custom diagnostic handler renders text-column virtual lines for
 -- the cursor's current diagnostic region, so long wrapped prose doesn't hide
 -- messages behind stock virtual-lines column indentation. `:ParleyShowDiagnostics`
 -- toggles it.
@@ -99,7 +99,6 @@ local function render(buf, diagnostics, current_line_only)
         end
         vim.api.nvim_buf_set_extmark(buf, display_ns_id, lnum, 0, {
             virt_lines = virt_lines,
-            virt_lines_leftcol = true,
             virt_lines_above = false,
         })
     end
diff --git a/tests/integration/review_diag_display_spec.lua b/tests/integration/review_diag_display_spec.lua
index f33e06c..c65f2f7 100644
--- a/tests/integration/review_diag_display_spec.lua
+++ b/tests/integration/review_diag_display_spec.lua
@@ -40,7 +40,7 @@ describe("review.diag_display", function()
         assert.is_false(ns_cfg()["parley/virtual_lines"])
     end)
 
-    it("renders current-line diagnostics from the left column without moving the diagnostic span", function()
+    it("renders current-line diagnostics at the buffer text column without moving the diagnostic span", function()
         local skill_render = require("parley.skill_render")
         local diag_ns = skill_render.diag_namespace()
         local buf = vim.api.nvim_create_buf(false, true)
@@ -67,7 +67,7 @@ describe("review.diag_display", function()
         local marks = display_marks(buf)
         assert.are.equal(1, #marks)
         local details = marks[1][4]
-        assert.is_true(details.virt_lines_leftcol)
+        assert.is_not_true(details.virt_lines_leftcol)
         assert.are.equal("Diagnostics:", details.virt_lines[1][1][1])
         assert.are_not.equal(string.rep(" ", 121), details.virt_lines[1][1][1])
         assert.are.equal("ACOS — Advertising Cost of Sales.", details.virt_lines[2][1][1])


codex
I’ll use the required skills for session startup and boundary-review posture, then inspect the issue/plan and the actual diff in the repo before giving the verdict.
exec
/bin/zsh -lc "sed -n '1,220p' /Users/xianxu/workspace/ariadne/construct/adapted/superpowers-requesting-code-review/SKILL.md" in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc "sed -n '1,220p' /Users/xianxu/workspace/ariadne/construct/adapted/superpowers-using-superpowers/SKILL.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
---
name: superpowers-requesting-code-review
description: Use when completing tasks, implementing major features, or before merging to verify work meets requirements
---

# Requesting Code Review

Dispatch superpowers-code-reviewer subagent to catch issues before they cascade. The reviewer gets precisely crafted context for evaluation — never your session's history. This keeps the reviewer focused on the work product, not your thought process, and preserves your own context for continued work.

**Core principle:** Review early, review often.

> **Ariadne note (#69):** SDLC *boundary* reviews — every `sdlc milestone-close`
> and `sdlc close` — are **binary-owned**: the binary dispatches the one
> fresh-context review itself (its reviewer is `cmd/sdlc/internal/judge/code-review.md`,
> which folds this checklist together with ariadne's atlas/core-concepts/VERDICT
> tweaks). **Do NOT run this skill as a second pass at an SDLC boundary** — that
> was the redundant double-review #69 removed. This skill remains for *ad-hoc* and
> *in-session* reviews outside the SDLC gates (e.g. the per-task reviews in
> superpowers-subagent-driven-development, or a quick fresh-eyes pass when stuck).

## When to Request Review

**Mandatory:**
- After each task in subagent-driven development
- After completing major feature
- Before merge to main

**Optional but valuable:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing complex bug

## How to Request

**1. Get git SHAs:**
```bash
BASE_SHA=$(git rev-parse HEAD~1)  # or origin/main
HEAD_SHA=$(git rev-parse HEAD)
```

**2. Dispatch code-reviewer subagent:**

Use Task tool with superpowers-code-reviewer type, fill template at `code-reviewer.md`

**Placeholders:**
- `{WHAT_WAS_IMPLEMENTED}` - What you just built
- `{PLAN_OR_REQUIREMENTS}` - What it should do
- `{BASE_SHA}` - Starting commit
- `{HEAD_SHA}` - Ending commit
- `{DESCRIPTION}` - Brief summary

**3. Act on feedback:**
- Fix Critical issues immediately
- Fix Important issues before proceeding
- Note Minor issues for later
- Push back if reviewer is wrong (with reasoning)

## Example

```
[Just completed Task 2: Add verification function]

You: Let me request code review before proceeding.

BASE_SHA=$(git log --oneline | grep "Task 1" | head -1 | awk '{print $1}')
HEAD_SHA=$(git rev-parse HEAD)

[Dispatch superpowers-code-reviewer subagent]
  WHAT_WAS_IMPLEMENTED: Verification and repair functions for conversation index
  PLAN_OR_REQUIREMENTS: Task 2 from workshop/plans/deployment-plan.md
  BASE_SHA: a7981ec
  HEAD_SHA: 3df7661
  DESCRIPTION: Added verifyIndex() and repairIndex() with 4 issue types

[Subagent returns]:
  Strengths: Clean architecture, real tests
  Issues:
    Important: Missing progress indicators
    Minor: Magic number (100) for reporting interval
  Assessment: Ready to proceed

You: [Fix progress indicators]
[Continue to Task 3]
```

## Integration with Workflows

**Subagent-Driven Development:**
- Review after EACH task
- Catch issues before they compound
- Fix before moving to next task

**Executing Plans:**
- Review after each batch (3 tasks)
- Get feedback, apply, continue

**Ad-Hoc Development:**
- Review before merge
- Review when stuck

## Red Flags

**Never:**
- Skip review because "it's simple"
- Ignore Critical issues
- Proceed with unfixed Important issues
- Argue with valid technical feedback

**If reviewer wrong:**
- Push back with technical reasoning
- Show code/tests that prove it works
- Request clarification

See template at: requesting-code-review/code-reviewer.md

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

codex
The SDLC boundary owns this review, so I’m not dispatching a second reviewer. I’m reading the tracker and validating the submitted diff directly against the issue’s stated contract.
exec
/bin/zsh -lc "sed -n '1,240p' workshop/issues/000174-diagnostic-virtual-lines-textcol.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
---
id: 000174
status: working
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 0.20
started: 2026-07-08T13:37:10-07:00
---

# diagnostic virtual lines should align with buffer text

## Problem

The #173 diagnostic display fix made long-line footnote diagnostics visible by
rendering Parley-owned virtual lines from the left edge of the window. In
practice that starts the block in the gutter/line-number area, so the
`Diagnostics:` label and wrapped text are visibly misaligned with the paragraph
text.

## Spec

- Parley's diagnostic virtual-line block should start at the buffer text column,
  not in the sign/number gutter.
- The block must still avoid Neovim's stock diagnostic-column indentation, so a
  high-column footnote diagnostic stays visible on long wrapped paragraphs.
- The underlying diagnostic span must remain unchanged for underline, jumps, and
  floats.
- Keep the behavior in the existing `skills/review/diag_display.lua` controller
  so review diagnostics and markdown footnote diagnostics stay unified
  (ARCH-DRY, ARCH-PURPOSE).
- This is a display-shell change only; no parser or diagnostic payload changes
  (ARCH-PURE).

## Done when

- A Parley diagnostic on a long line renders at text-column alignment.
- It no longer sets the gutter-anchored virtual-line option.
- Existing current-line and multi-line span behavior stays covered.

## Estimate

Derived via `estimate-logic-v3.1` against the repo-local calibration source from
`sdlc estimate-source` (stale but canonical for this repo).

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.02 impl=0.00
item: lua-neovim design=0.00 impl=0.10
item: milestone-review design=0.00 impl=0.08
total: 0.20
```

## Plan

- [x] Add a failing integration assertion for text-column virtual-line anchoring.
- [x] Update the custom renderer to stop using gutter anchoring.
- [x] Run focused diagnostics tests and whitespace checks.

## Log

### 2026-07-08
- Root cause: #173 set `virt_lines_leftcol = true`, which solved off-screen
  diagnostic-column indentation but anchors the block at the absolute window left
  edge, including the gutter. The desired anchor is buffer column 0 with normal
  virtual-line placement.
- Red: `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"`
  failed because the display extmark still set `virt_lines_leftcol = true`.
- Green: removed `virt_lines_leftcol` from the custom renderer, kept the extmark
  at column 0, updated atlas wording, and re-ran the focused spec successfully.
- Verification: `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"`;
  `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`;
  `git diff --check -- lua/parley/skills/review/diag_display.lua
  tests/integration/review_diag_display_spec.lua atlas/chat/inline_define.md
  atlas/modes/review.md workshop/issues/000174-diagnostic-virtual-lines-textcol.md`;
  `make test`.

exec
/bin/zsh -lc 'git diff --check 8c35ad2ab117aa166c46042f00d0b2cbc1c8aa6b..HEAD' in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc 'git diff --name-only 8c35ad2ab117aa166c46042f00d0b2cbc1c8aa6b..HEAD' in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc 'git diff --stat 8c35ad2ab117aa166c46042f00d0b2cbc1c8aa6b..HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
 succeeded in 0ms:
atlas/chat/inline_define.md
atlas/modes/review.md
lua/parley/skills/review/diag_display.lua
tests/integration/review_diag_display_spec.lua
workshop/issues/000174-diagnostic-virtual-lines-textcol.md

 succeeded in 0ms:
 atlas/chat/inline_define.md                        |  2 +-
 atlas/modes/review.md                              |  6 +--
 lua/parley/skills/review/diag_display.lua          |  3 +-
 tests/integration/review_diag_display_spec.lua     |  4 +-
 .../000174-diagnostic-virtual-lines-textcol.md     | 56 ++++++++++++++++++++--
 5 files changed, 60 insertions(+), 11 deletions(-)

codex
The issue is narrow: remove gutter anchoring while preserving the custom handler’s current-line filtering and diagnostic span. I’m checking whether the test actually pins those three pieces, not just the option flip.
exec
/bin/zsh -lc "nl -ba lua/parley/skills/review/diag_display.lua | sed -n '1,190p'" in /Users/xianxu/workspace/parley.nvim
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
    19	
    20	local display_ns_id
    21	local display_augroup
    22	
    23	-- Parley's review diagnostic namespace — single-sourced from skill_render (which
    24	-- owns the namespace) so the identity isn't a duplicated literal (#133 M6 review).
    25	local function ns()
    26	    return require("parley.skill_render").diag_namespace()
    27	end
    28	
    29	local function ensure_display()
    30	    if not display_ns_id then
    31	        display_ns_id = vim.api.nvim_create_namespace(DISPLAY_NS)
    32	    end
    33	    if not display_augroup then
    34	        display_augroup = vim.api.nvim_create_augroup(DISPLAY_AUGROUP, { clear = true })
    35	    end
    36	    vim.api.nvim_set_hl(0, HEADER_HL, { link = "DiagnosticInfo" })
    37	    vim.api.nvim_set_hl(0, MESSAGE_HL, { link = "DiagnosticFloatingInfo" })
    38	end
    39	
    40	local function clear(buf)
    41	    ensure_display()
    42	    if vim.api.nvim_buf_is_valid(buf) then
    43	        vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
    44	        pcall(vim.api.nvim_clear_autocmds, { group = display_augroup, buffer = buf })
    45	    end
    46	end
    47	
    48	local function current_line_for(buf)
    49	    if vim.api.nvim_get_current_buf() ~= buf then
    50	        return nil
    51	    end
    52	    return vim.api.nvim_win_get_cursor(0)[1] - 1
    53	end
    54	
    55	local function diagnostic_message_lines(diagnostic)
    56	    local lines = {}
    57	    for _, line in ipairs(vim.split(tostring(diagnostic.message or ""), "\n", { plain = true })) do
    58	        table.insert(lines, { { line ~= "" and line or " ", MESSAGE_HL } })
    59	    end
    60	    if #lines == 0 then
    61	        table.insert(lines, { { " ", MESSAGE_HL } })
    62	    end
    63	    return lines
    64	end
    65	
    66	local function diagnostic_contains_line(diagnostic, line)
    67	    local start_line = diagnostic.lnum or 0
    68	    local end_line = diagnostic.end_lnum or start_line
    69	    return line >= start_line and line <= end_line
    70	end
    71	
    72	local function render(buf, diagnostics, current_line_only)
    73	    ensure_display()
    74	    if not vim.api.nvim_buf_is_valid(buf) then
    75	        return
    76	    end
    77	    vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
    78	
    79	    local line = current_line_only and current_line_for(buf) or nil
    80	    if current_line_only and not line then
    81	        return
    82	    end
    83	
    84	    local by_line = {}
    85	    for _, diagnostic in ipairs(diagnostics or {}) do
    86	        if not current_line_only or diagnostic_contains_line(diagnostic, line) then
    87	            by_line[diagnostic.lnum] = by_line[diagnostic.lnum] or {}
    88	            table.insert(by_line[diagnostic.lnum], diagnostic)
    89	        end
    90	    end
    91	
    92	    for lnum, line_diagnostics in pairs(by_line) do
    93	        table.sort(line_diagnostics, function(a, b)
    94	            return (a.col or 0) < (b.col or 0)
    95	        end)
    96	        local virt_lines = { { { "Diagnostics:", HEADER_HL } } }
    97	        for _, diagnostic in ipairs(line_diagnostics) do
    98	            vim.list_extend(virt_lines, diagnostic_message_lines(diagnostic))
    99	        end
   100	        vim.api.nvim_buf_set_extmark(buf, display_ns_id, lnum, 0, {
   101	            virt_lines = virt_lines,
   102	            virt_lines_above = false,
   103	        })
   104	    end
   105	end
   106	
   107	local function register_handler()
   108	    ensure_display()
   109	    vim.diagnostic.handlers[HANDLER_NAME] = {
   110	        show = function(namespace, bufnr, diagnostics, opts)
   111	            if namespace ~= ns() then
   112	                return
   113	            end
   114	            bufnr = vim._resolve_bufnr(bufnr)
   115	            local handler_opts = opts and opts[HANDLER_NAME] or {}
   116	            local current_line_only = handler_opts.current_line == true
   117	            clear(bufnr)
   118	            if current_line_only then
   119	                vim.api.nvim_create_autocmd("CursorMoved", {
   120	                    buffer = bufnr,
   121	                    group = display_augroup,
   122	                    callback = function()
   123	                        render(bufnr, diagnostics, true)
   124	                    end,
   125	                })
   126	            end
   127	            render(bufnr, diagnostics, current_line_only)
   128	        end,
   129	        hide = function(namespace, bufnr)
   130	            if namespace ~= ns() then
   131	                return
   132	            end
   133	            clear(vim._resolve_bufnr(bufnr))
   134	        end,
   135	    }
   136	end
   137	
   138	function M.refresh(buf)
   139	    if not M.enabled then
   140	        return
   141	    end
   142	    buf = buf or vim.api.nvim_get_current_buf()
   143	    render(buf, vim.diagnostic.get(buf, { namespace = ns() }), true)
   144	end
   145	
   146	--- Apply the inline-display config for parley's review namespace.
   147	--- @param on boolean
   148	function M.set(on)
   149	    M.enabled = on and true or false
   150	    register_handler()
   151	    vim.diagnostic.config({
   152	        [HANDLER_NAME] = M.enabled and { current_line = true } or false,
   153	        virtual_lines = false,
   154	        virtual_text = false,
   155	    }, ns())
   156	    if M.enabled then
   157	        M.refresh()
   158	    else
   159	        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
   160	            clear(buf)
   161	        end
   162	    end
   163	end
   164	
   165	--- Toggle inline display; returns the new state.
   166	--- @return boolean
   167	function M.toggle()
   168	    M.set(not M.enabled)
   169	    return M.enabled
   170	end
   171	
   172	--- Is inline display currently enabled?
   173	--- @return boolean
   174	function M.is_enabled()
   175	    return M.enabled
   176	end
   177	
   178	return M

exec
/bin/zsh -lc "nl -ba tests/integration/review_diag_display_spec.lua | sed -n '1,180p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
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
    14	describe("review.diag_display", function()
    15	    after_each(function()
    16	        dd.set(true) -- restore default for other specs
    17	        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    18	            if vim.api.nvim_buf_is_valid(buf) then
    19	                pcall(vim.diagnostic.reset, require("parley.skill_render").diag_namespace(), buf)
    20	            end
    21	        end
    22	    end)
    23	
    24	    it("toggles the enabled state", function()
    25	        dd.set(true)
    26	        assert.is_true(dd.is_enabled())
    27	        assert.is_false(dd.toggle())
    28	        assert.is_false(dd.is_enabled())
    29	        assert.is_true(dd.toggle())
    30	        assert.is_true(dd.is_enabled())
    31	    end)
    32	
    33	    it("configures Parley's custom current-line display on its namespace when on; off when disabled", function()
    34	        dd.set(true)
    35	        local on = ns_cfg()
    36	        assert.is_false(on.virtual_lines) -- Parley owns its virtual-lines renderer.
    37	        assert.is_truthy(on["parley/virtual_lines"])
    38	        assert.is_false(on.virtual_text) -- inline single-line is never used
    39	        dd.set(false)
    40	        assert.is_false(ns_cfg()["parley/virtual_lines"])
    41	    end)
    42	
    43	    it("renders current-line diagnostics at the buffer text column without moving the diagnostic span", function()
    44	        local skill_render = require("parley.skill_render")
    45	        local diag_ns = skill_render.diag_namespace()
    46	        local buf = vim.api.nvim_create_buf(false, true)
    47	        vim.api.nvim_set_current_buf(buf)
    48	        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    49	            string.rep("x", 120) .. " ACOS[^acos]",
    50	        })
    51	
    52	        dd.set(true)
    53	        vim.diagnostic.set(diag_ns, buf, { {
    54	            lnum = 0,
    55	            col = 121,
    56	            end_lnum = 0,
    57	            end_col = 132,
    58	            message = "ACOS — Advertising Cost of Sales.",
    59	            severity = vim.diagnostic.severity.INFO,
    60	            source = "parley-footnote",
    61	        } })
    62	
    63	        vim.wait(100, function()
    64	            return #display_marks(buf) == 1
    65	        end)
    66	
    67	        local marks = display_marks(buf)
    68	        assert.are.equal(1, #marks)
    69	        local details = marks[1][4]
    70	        assert.is_not_true(details.virt_lines_leftcol)
    71	        assert.are.equal("Diagnostics:", details.virt_lines[1][1][1])
    72	        assert.are_not.equal(string.rep(" ", 121), details.virt_lines[1][1][1])
    73	        assert.are.equal("ACOS — Advertising Cost of Sales.", details.virt_lines[2][1][1])
    74	
    75	        local diagnostics = vim.diagnostic.get(buf, { namespace = diag_ns })
    76	        assert.are.equal(1, #diagnostics)
    77	        assert.are.equal(0, diagnostics[1].lnum)
    78	        assert.are.equal(121, diagnostics[1].col)
    79	        assert.are.equal(0, diagnostics[1].end_lnum)
    80	        assert.are.equal(132, diagnostics[1].end_col)
    81	
    82	        dd.set(false)
    83	        assert.are.equal(0, #display_marks(buf))
    84	        assert.are.equal(1, #vim.diagnostic.get(buf, { namespace = diag_ns }))
    85	    end)
    86	
    87	    it("keeps a multi-line diagnostic visible anywhere inside its span", function()
    88	        local skill_render = require("parley.skill_render")
    89	        local diag_ns = skill_render.diag_namespace()
    90	        local buf = vim.api.nvim_create_buf(false, true)
    91	        vim.api.nvim_set_current_buf(buf)
    92	        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    93	            "edited line one",
    94	            "edited line two",
    95	            "edited line three",
    96	        })
    97	
    98	        dd.set(true)
    99	        vim.diagnostic.set(diag_ns, buf, { {
   100	            lnum = 0,
   101	            col = 0,
   102	            end_lnum = 2,
   103	            end_col = 17,
   104	            message = "review explanation",
   105	            severity = vim.diagnostic.severity.INFO,
   106	            source = "parley-skill",
   107	        } })
   108	        assert.are.equal(1, #display_marks(buf))
   109	
   110	        vim.api.nvim_win_set_cursor(0, { 2, 0 })
   111	        vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
   112	        assert.are.equal(1, #display_marks(buf), "span diagnostic should show on middle line")
   113	
   114	        vim.api.nvim_win_set_cursor(0, { 3, 0 })
   115	        vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
   116	        assert.are.equal(1, #display_marks(buf), "span diagnostic should show on final line")
   117	    end)
   118	end)

exec
/bin/zsh -lc 'git diff --unified=80 8c35ad2ab117aa166c46042f00d0b2cbc1c8aa6b..HEAD -- lua/parley/skills/review/diag_display.lua tests/integration/review_diag_display_spec.lua' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
diff --git a/lua/parley/skills/review/diag_display.lua b/lua/parley/skills/review/diag_display.lua
index a63de85..fa443d3 100644
--- a/lua/parley/skills/review/diag_display.lua
+++ b/lua/parley/skills/review/diag_display.lua
@@ -1,179 +1,178 @@
 -- diag_display.lua — inline display of Parley diagnostics (#133 M6, #173).
 --
 -- Controls how parley's review explanations render, scoped to parley's OWN
 -- diagnostic namespace (never touches the user's LSP / global diagnostics).
--- Default ON: a custom diagnostic handler renders left-column virtual lines for
+-- Default ON: a custom diagnostic handler renders text-column virtual lines for
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
 
 local function current_line_for(buf)
     if vim.api.nvim_get_current_buf() ~= buf then
         return nil
     end
     return vim.api.nvim_win_get_cursor(0)[1] - 1
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
 
 local function render(buf, diagnostics, current_line_only)
     ensure_display()
     if not vim.api.nvim_buf_is_valid(buf) then
         return
     end
     vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
 
     local line = current_line_only and current_line_for(buf) or nil
     if current_line_only and not line then
         return
     end
 
     local by_line = {}
     for _, diagnostic in ipairs(diagnostics or {}) do
         if not current_line_only or diagnostic_contains_line(diagnostic, line) then
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
         vim.api.nvim_buf_set_extmark(buf, display_ns_id, lnum, 0, {
             virt_lines = virt_lines,
-            virt_lines_leftcol = true,
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
diff --git a/tests/integration/review_diag_display_spec.lua b/tests/integration/review_diag_display_spec.lua
index f33e06c..c65f2f7 100644
--- a/tests/integration/review_diag_display_spec.lua
+++ b/tests/integration/review_diag_display_spec.lua
@@ -1,118 +1,118 @@
 -- Integration tests for the review-diagnostic inline display toggle (#133 M6).
 
 local dd = require("parley.skills.review.diag_display")
 
 local function ns_cfg()
     return vim.diagnostic.config(nil, require("parley.skill_render").diag_namespace())
 end
 
 local function display_marks(buf)
     local display_ns = vim.api.nvim_create_namespace("parley_diagnostic_virtual_lines")
     return vim.api.nvim_buf_get_extmarks(buf, display_ns, 0, -1, { details = true })
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
 
-    it("renders current-line diagnostics from the left column without moving the diagnostic span", function()
+    it("renders current-line diagnostics at the buffer text column without moving the diagnostic span", function()
         local skill_render = require("parley.skill_render")
         local diag_ns = skill_render.diag_namespace()
         local buf = vim.api.nvim_create_buf(false, true)
         vim.api.nvim_set_current_buf(buf)
         vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
             string.rep("x", 120) .. " ACOS[^acos]",
         })
 
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
             return #display_marks(buf) == 1
         end)
 
         local marks = display_marks(buf)
         assert.are.equal(1, #marks)
         local details = marks[1][4]
-        assert.is_true(details.virt_lines_leftcol)
+        assert.is_not_true(details.virt_lines_leftcol)
         assert.are.equal("Diagnostics:", details.virt_lines[1][1][1])
         assert.are_not.equal(string.rep(" ", 121), details.virt_lines[1][1][1])
         assert.are.equal("ACOS — Advertising Cost of Sales.", details.virt_lines[2][1][1])
 
         local diagnostics = vim.diagnostic.get(buf, { namespace = diag_ns })
         assert.are.equal(1, #diagnostics)
         assert.are.equal(0, diagnostics[1].lnum)
         assert.are.equal(121, diagnostics[1].col)
         assert.are.equal(0, diagnostics[1].end_lnum)
         assert.are.equal(132, diagnostics[1].end_col)
 
         dd.set(false)
         assert.are.equal(0, #display_marks(buf))
         assert.are.equal(1, #vim.diagnostic.get(buf, { namespace = diag_ns }))
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

exec
/bin/zsh -lc "rg -n \"virt_lines_leftcol|parley/virtual_lines|diag_display|text-column|left-column|leftcol\" . --glob '"'!workshop/history/**'"'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
./atlas/modes/review.md:163:`parley_skill` namespace. `lua/parley/skills/review/diag_display.lua` controls how
./atlas/modes/review.md:165:untouched. Default **on**: Parley's custom `parley/virtual_lines` diagnostic
./atlas/modes/review.md:166:handler renders a text-column virtual-line block headed `Diagnostics:` for the
./atlas/modes/review.md:209:- `lua/parley/skills/review/diag_display.lua` — inline "why" display toggle (`:ParleyShowDiagnostics`, cursor-region auto-show) (#133 M6)
./atlas/chat/inline_define.md:44:   `diag_display`'s Parley-owned text-column virtual-line display reveals the
./atlas/chat/inline_define.md:149:- [Document Review](../modes/review.md) — the skill/`skill_invoke`/`diag_display`
./tests/integration/review_diag_display_spec.lua:3:local dd = require("parley.skills.review.diag_display")
./tests/integration/review_diag_display_spec.lua:14:describe("review.diag_display", function()
./tests/integration/review_diag_display_spec.lua:37:        assert.is_truthy(on["parley/virtual_lines"])
./tests/integration/review_diag_display_spec.lua:40:        assert.is_false(ns_cfg()["parley/virtual_lines"])
./tests/integration/review_diag_display_spec.lua:70:        assert.is_not_true(details.virt_lines_leftcol)
./lua/parley/skill_render.lua:39:--- (diag_display) target, so the namespace identity isn't duplicated as a literal
./lua/parley/init.lua:773:		local on = require("parley.skills.review.diag_display").toggle()
./lua/parley/init.lua:776:	require("parley.skills.review.diag_display").set(true)
./lua/parley/init.lua:1655:	-- Park the cursor on the term's line so diag_display's current-line
./lua/parley/float_picker.lua:959:                    vim.fn.winrestview({ topline = topline, leftcol = view.leftcol or 0 })
./lua/parley/float_picker.lua:974:                    vim.fn.winrestview({ topline = topline, leftcol = 0 })
./workshop/issues/000174-diagnostic-virtual-lines-textcol.md:30:- Keep the behavior in the existing `skills/review/diag_display.lua` controller
./workshop/issues/000174-diagnostic-virtual-lines-textcol.md:38:- A Parley diagnostic on a long line renders at text-column alignment.
./workshop/issues/000174-diagnostic-virtual-lines-textcol.md:58:- [x] Add a failing integration assertion for text-column virtual-line anchoring.
./workshop/issues/000174-diagnostic-virtual-lines-textcol.md:65:- Root cause: #173 set `virt_lines_leftcol = true`, which solved off-screen
./workshop/issues/000174-diagnostic-virtual-lines-textcol.md:69:- Red: `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"`
./workshop/issues/000174-diagnostic-virtual-lines-textcol.md:70:  failed because the display extmark still set `virt_lines_leftcol = true`.
./workshop/issues/000174-diagnostic-virtual-lines-textcol.md:71:- Green: removed `virt_lines_leftcol` from the custom renderer, kept the extmark
./workshop/issues/000174-diagnostic-virtual-lines-textcol.md:73:- Verification: `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"`;
./workshop/issues/000174-diagnostic-virtual-lines-textcol.md:75:  `git diff --check -- lua/parley/skills/review/diag_display.lua
./workshop/issues/000174-diagnostic-virtual-lines-textcol.md:76:  tests/integration/review_diag_display_spec.lua atlas/chat/inline_define.md
./lua/parley/skills/review/diag_display.lua:1:-- diag_display.lua — inline display of Parley diagnostics (#133 M6, #173).
./lua/parley/skills/review/diag_display.lua:5:-- Default ON: a custom diagnostic handler renders text-column virtual lines for
./lua/parley/skills/review/diag_display.lua:14:local HANDLER_NAME = "parley/virtual_lines"

codex
The atlas sweep only found the updated references plus code/tests, so the docs gate looks covered for this behavior change. I’m running the focused spec and a quick full-suite check if it completes in time, because the issue’s Log claims both.
exec
/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"' in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc 'make test' in /Users/xianxu/workspace/parley.nvim
 succeeded in 1465ms:

LuaSnip: could not open log at /Users/xianxu/.local/state/nvim/luasnip.log. Not logging for this session.
Parley.nvim: Failed to open file for writing: /Users/xianxu/.local/share/nvim/parley/persisted/state.jsonScheduling: tests/integration/review_diag_display_spec.lua

========================================	
Testing: 	/Users/xianxu/workspace/parley.nvim/tests/integration/review_diag_display_spec.lua	
[32mSuccess[0m	||	review.diag_display toggles the enabled state	
[32mSuccess[0m	||	review.diag_display configures Parley's custom current-line display on its namespace when on; off when disabled	
[32mSuccess[0m	||	review.diag_display renders current-line diagnostics at the buffer text column without moving the diagnostic span	
[32mSuccess[0m	||	review.diag_display keeps a multi-line diagnostic visible anywhere inside its span	
	
[32mSuccess: [0m	4	
[31mFailed : [0m	0	
[31mErrors : [0m	0	
========================================	
]111
 succeeded in 17161ms:
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
PASS: tests/unit/custom_prompts_spec.lua
PASS: tests/unit/chat_dirs_spec.lua
PASS: tests/unit/define_spec.lua
PASS: tests/unit/discovery_base_spec.lua
PASS: tests/unit/discovery_descriptor_spec.lua
PASS: tests/unit/discovery_matcher_spec.lua
PASS: tests/unit/discovery_merge_spec.lua
PASS: tests/unit/discovery_registry_spec.lua
PASS: tests/unit/chat_slug_resolve_spec.lua
PASS: tests/unit/drill_in_spec.lua
PASS: tests/unit/dispatcher_query_spec.lua
PASS: tests/unit/exchange_clipboard_spec.lua
PASS: tests/unit/exchange_model_spec.lua
PASS: tests/unit/dispatcher_spec.lua
PASS: tests/unit/finder_sticky_spec.lua
PASS: tests/unit/exporter_tree_spec.lua
PASS: tests/unit/file_tracker_spec.lua
PASS: tests/unit/get_week_number_spec.lua
PASS: tests/unit/float_picker_spec.lua
PASS: tests/unit/helper_io_spec.lua
PASS: tests/unit/helper_spec.lua
PASS: tests/unit/highlighter_spec.lua
PASS: tests/unit/issue_vocabulary_spec.lua
PASS: tests/unit/inline_branch_spec.lua
PASS: tests/unit/issue_finder_spec.lua
PASS: tests/unit/log_emit_spec.lua
PASS: tests/unit/logger_spec.lua
PASS: tests/unit/memory_prefs_spec.lua
PASS: tests/unit/issues_spec.lua
PASS: tests/unit/markdown_draft_block_spec.lua
PASS: tests/unit/neighborhood_spec.lua
PASS: tests/unit/config_tools_spec.lua
PASS: tests/unit/note_finder_logic_spec.lua
PASS: tests/unit/oauth_spec.lua
PASS: tests/unit/obfuscate_spec.lua
PASS: tests/unit/outline_spec.lua
PASS: tests/unit/open_chat_reference_spec.lua
PASS: tests/unit/parse_chat_spec.lua
PASS: tests/unit/picker_items_spec.lua
PASS: tests/unit/parley_harness_golden_spec.lua
PASS: tests/unit/parley_harness_spec.lua
PASS: tests/unit/process_directory_pattern_spec.lua
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
PASS: tests/unit/remote_references_spec.lua
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
PASS: tests/unit/tools_builtin_propose_edits_spec.lua
PASS: tests/unit/tools_builtin_ls_spec.lua
PASS: tests/unit/tools_builtin_read_file_spec.lua
PASS: tests/unit/tools_builtin_find_spec.lua
PASS: tests/unit/tools_registry_spec.lua
PASS: tests/unit/tools_builtin_registered_spec.lua
PASS: tests/unit/tools_serialize_spec.lua
PASS: tests/unit/tools_types_spec.lua
PASS: tests/unit/tools_dispatcher_spec.lua
PASS: tests/unit/tools_builtin_ack_spec.lua
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
PASS: tests/integration/neighborhood_completion_spec.lua
PASS: tests/integration/progress_spec.lua
PASS: tests/integration/new_chat_spec.lua
PASS: tests/integration/not_chat_spec.lua
PASS: tests/integration/review_diag_display_spec.lua
PASS: tests/integration/review_journal_io_spec.lua
PASS: tests/integration/review_menu_spec.lua
PASS: tests/integration/review_mode_load_spec.lua
PASS: tests/integration/review_projection_spec.lua
PASS: tests/integration/skill_registry_spec.lua
PASS: tests/integration/skill_invoke_review_spec.lua
PASS: tests/integration/skill_providers_spec.lua
PASS: tests/integration/spell_chat_spec.lua
PASS: tests/integration/define_spec.lua
PASS: tests/integration/skill_invoke_spec.lua
PASS: tests/integration/topic_gen_spec.lua
PASS: tests/integration/timer_race_spec.lua
PASS: tests/integration/tree_export_spec.lua
PASS: tests/integration/voice_apply_spec.lua
PASS: tests/integration/tasker_run_spec.lua
PASS: tests/integration/highlighting_spec.lua
PASS: tests/integration/chat_respond_spec.lua
PASS: tests/integration/cliproxy_lifecycle_spec.lua

codex
```verdict
verdict: SHIP
confidence: high
```

This diff fulfills #174’s narrow purpose: Parley’s custom diagnostic virtual lines no longer request gutter anchoring, the diagnostic span remains unchanged, and the behavior stays in the shared `diag_display` controller. I found no blocking or non-blocking findings.

1. Strengths:
- [diag_display.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/skills/review/diag_display.lua:100) removes only `virt_lines_leftcol`, keeping the extmark at column 0 and leaving diagnostic payload/span logic untouched.
- [review_diag_display_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/integration/review_diag_display_spec.lua:43) covers the long-line diagnostic case and asserts both display anchoring option removal and unchanged diagnostic coordinates.
- [review_diag_display_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/integration/review_diag_display_spec.lua:87) retains multi-line span coverage.
- Atlas wording was updated in both relevant surfaces: `atlas/chat/inline_define.md` and `atlas/modes/review.md`.

2. Critical findings: None.

3. Important findings: None.

4. Minor findings: None.

5. Test coverage notes:
- Verified `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"` passes: 4 passed, 0 failed.
- Verified `make test` passes, including lint and the full unit/integration suite.
- `git diff --check 8c35ad2ab117aa166c46042f00d0b2cbc1c8aa6b..HEAD` produced no whitespace errors.

6. Architectural notes for upcoming work:
- ARCH-DRY: Pass. The change preserves the single shared diagnostic display controller instead of creating review/define-specific display paths.
- ARCH-PURE: Pass. This remains a thin UI/display-shell change; no parser or diagnostic payload logic was mixed into the renderer.
- ARCH-PURPOSE: Pass. The diff addresses the actual issue purpose by removing gutter anchoring while keeping the custom handler that avoids stock diagnostic-column indentation.

7. Plan revision recommendations: None.
tokens used
38,560
```verdict
verdict: SHIP
confidence: high
```

This diff fulfills #174’s narrow purpose: Parley’s custom diagnostic virtual lines no longer request gutter anchoring, the diagnostic span remains unchanged, and the behavior stays in the shared `diag_display` controller. I found no blocking or non-blocking findings.

1. Strengths:
- [diag_display.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/skills/review/diag_display.lua:100) removes only `virt_lines_leftcol`, keeping the extmark at column 0 and leaving diagnostic payload/span logic untouched.
- [review_diag_display_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/integration/review_diag_display_spec.lua:43) covers the long-line diagnostic case and asserts both display anchoring option removal and unchanged diagnostic coordinates.
- [review_diag_display_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/integration/review_diag_display_spec.lua:87) retains multi-line span coverage.
- Atlas wording was updated in both relevant surfaces: `atlas/chat/inline_define.md` and `atlas/modes/review.md`.

2. Critical findings: None.

3. Important findings: None.

4. Minor findings: None.

5. Test coverage notes:
- Verified `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"` passes: 4 passed, 0 failed.
- Verified `make test` passes, including lint and the full unit/integration suite.
- `git diff --check 8c35ad2ab117aa166c46042f00d0b2cbc1c8aa6b..HEAD` produced no whitespace errors.

6. Architectural notes for upcoming work:
- ARCH-DRY: Pass. The change preserves the single shared diagnostic display controller instead of creating review/define-specific display paths.
- ARCH-PURE: Pass. This remains a thin UI/display-shell change; no parser or diagnostic payload logic was mixed into the renderer.
- ARCH-PURPOSE: Pass. The diff addresses the actual issue purpose by removing gutter anchoring while keeping the custom handler that avoids stock diagnostic-column indentation.

7. Plan revision recommendations: None.
