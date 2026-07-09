# Boundary Review — parley.nvim#180 (whole-issue close)

| field | value |
|-------|-------|
| issue | 180 — recover footnote spans from slug ids |
| repo | parley.nvim |
| issue file | workshop/issues/000180-recover-footnote-spans-from-slug-ids.md |
| boundary | whole-issue close |
| milestone | — |
| window | 569798381221039ac656f3391c6ded8e5fe143e6..HEAD |
| command | sdlc close --issue 180 |
| reviewer | codex |
| timestamp | 2026-07-09T11:22:14-07:00 |
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
session id: 019f481c-4974-7bc0-b3e1-484280451527
--------
user
# Code review — the one SDLC boundary review

You are conducting a fresh-context code review at a development boundary —
whole-issue close — in the **parley.nvim** repository.

- repository: parley.nvim   (root: /Users/xianxu/workspace/parley.nvim)
- issue:      parley.nvim#180   (file: workshop/issues/000180-recover-footnote-spans-from-slug-ids.md)
- window:     Base: 569798381221039ac656f3391c6ded8e5fe143e6   Head: HEAD

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
index 9fc66f0..725c2f3 100644
--- a/atlas/chat/inline_define.md
+++ b/atlas/chat/inline_define.md
@@ -102,9 +102,10 @@ Advertising Cost of Sales[^acos]

 On reload, `define.footnote_diagnostics` uses that leading display term to find
 the nearest matching phrase before `[^acos]`; the resulting span drives both the
-floating definition trigger and the rehydrated inline highlight. If the phrase is
-not present before the reference, the diagnostic falls back to the historical
-single-token span immediately before `[^id]`.
+floating definition trigger and the rehydrated inline highlight. If the footer
+does not provide a display term, diagnostics try the slug-derived phrase from the
+footnote id (`serverless-functions` → `serverless functions`) before falling
+back to the historical single-token span immediately before `[^id]`.

 ## Keybinding

diff --git a/lua/parley/define.lua b/lua/parley/define.lua
index 97f3a83..861ba15 100644
--- a/lua/parley/define.lua
+++ b/lua/parley/define.lua
@@ -254,14 +254,16 @@ local function is_structured_anchor_suffix(text)
     return trim(text):match("^[\"'”’%]%)%}]*$") ~= nil
 end

-local function structured_term_start(line, ref_start, term)
+local function anchor_term_span(line, ref_start, term, ignore_case)
     if not term or term == "" then
-        return nil
+        return nil, nil, nil
     end
+    local haystack = ignore_case and line:lower() or line
+    local needle = ignore_case and term:lower() or term
     local best_start, best_end
     local search = 1
     while search < ref_start do
-        local start_pos, end_pos = line:find(term, search, true)
+        local start_pos, end_pos = haystack:find(needle, search, true)
         if not start_pos or start_pos >= ref_start then
             break
         end
@@ -275,9 +277,21 @@ local function structured_term_start(line, ref_start, term)
         search = start_pos + 1
     end
     if not best_start then
+        return nil, nil, nil
+    end
+    return best_start, best_end, line:sub(best_start, best_end)
+end
+
+local function slug_anchor_term(id)
+    if not id or not id:find("-", 1, true) then
+        return nil
+    end
+    local term = id:gsub("%-+", " ")
+    term = trim(term)
+    if term == "" then
         return nil
     end
-    return best_start, best_end
+    return term
 end

 --- Derive persisted definition diagnostics from inline footnote references and
@@ -314,9 +328,13 @@ function M.footnote_diagnostics(lines)
             end
             local footnote = definitions[id]
             if footnote then
-                local structured_start = structured_term_start(line, ref_start, footnote.structured_term)
-                local term_start = structured_start or expand_term_start(line, ref_start)
-                local term = footnote.structured_term or line:sub(term_start, ref_start - 1)
+                local structured_start = anchor_term_span(line, ref_start, footnote.structured_term, false)
+                local slug_start, _, slug_term = nil, nil, nil
+                if not structured_start then
+                    slug_start, _, slug_term = anchor_term_span(line, ref_start, slug_anchor_term(id), true)
+                end
+                local term_start = structured_start or slug_start or expand_term_start(line, ref_start)
+                local term = footnote.structured_term or slug_term or line:sub(term_start, ref_start - 1)
                 table.insert(diagnostics, {
                     id = id,
                     term = term ~= "" and term or nil,
diff --git a/tests/integration/highlighting_spec.lua b/tests/integration/highlighting_spec.lua
index b450a5d..1a51882 100644
--- a/tests/integration/highlighting_spec.lua
+++ b/tests/integration/highlighting_spec.lua
@@ -579,6 +579,27 @@ describe("markdown footnote diagnostics", function()
         assert.equals("DiffChange", marks[1][4].hl_group)
     end)

+    it("rehydrates an unstructured slug-derived multi-word footnote anchor highlight", function()
+        local skill_render = require("parley.skill_render")
+        local buf = vim.api.nvim_create_buf(false, true)
+        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
+            "Lambda runs serverless functions[^serverless-functions] without servers.",
+            "",
+            "[^serverless-functions]: Function-as-a-service compute without server management.",
+        })
+
+        skill_render.refresh_footnote_diagnostics(buf)
+
+        local hl_ns = vim.api.nvim_get_namespaces().parley_footnote_hl
+        local marks = vim.api.nvim_buf_get_extmarks(buf, hl_ns, 0, -1, { details = true })
+        assert.equals(1, #marks)
+        assert.equals(0, marks[1][2])
+        assert.equals(12, marks[1][3])
+        assert.equals(0, marks[1][4].end_row)
+        assert.equals(55, marks[1][4].end_col)
+        assert.equals("DiffChange", marks[1][4].hl_group)
+    end)
+
     it("refreshes footnote diagnostics on markdown text changes without clearing other Parley diagnostics", function()
         local skill_render = require("parley.skill_render")
         local ns = skill_render.diag_namespace()
diff --git a/tests/unit/define_spec.lua b/tests/unit/define_spec.lua
index 140068d..d223db5 100644
--- a/tests/unit/define_spec.lua
+++ b/tests/unit/define_spec.lua
@@ -418,6 +418,42 @@ describe("define durable footnotes", function()
         } }, diagnostics)
     end)

+    it("uses the footnote id slug to recover an unstructured multi-word anchor", function()
+        local diagnostics = define.footnote_diagnostics({
+            "Lambda runs serverless functions[^serverless-functions] without servers.",
+            "",
+            "[^serverless-functions]: Function-as-a-service compute without server management.",
+        })
+
+        assert.are.same({ {
+            id = "serverless-functions",
+            term = "serverless functions",
+            definition = "Function-as-a-service compute without server management.",
+            lnum = 0,
+            col = 12,
+            end_lnum = 0,
+            end_col = 55,
+        } }, diagnostics)
+    end)
+
+    it("matches slug-derived anchors case-insensitively while preserving typed body text", function()
+        local diagnostics = define.footnote_diagnostics({
+            "Lambda runs Serverless Functions[^serverless-functions] without servers.",
+            "",
+            "[^serverless-functions]: Function-as-a-service compute without server management.",
+        })
+
+        assert.are.same({ {
+            id = "serverless-functions",
+            term = "Serverless Functions",
+            definition = "Function-as-a-service compute without server management.",
+            lnum = 0,
+            col = 12,
+            end_lnum = 0,
+            end_col = 55,
+        } }, diagnostics)
+    end)
+
     it("extracts every inline reference to a managed footnote", function()
         local diagnostics = define.footnote_diagnostics({
             "ASIN[^asin] first, then SKU[^asin] second",


codex
I’ll do this as a fresh-context boundary review: first reading the required workflow/skill context, then checking the issue file and the actual diff against the stated scope.
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
Using `superpowers-using-superpowers` for the session contract; no implementation skills apply because this is a read-only review. I’ve also read `sdlc --help` and the repo lessons as required, and now I’m checking the issue artifact plus the code around the diff.
exec
/bin/zsh -lc "nl -ba lua/parley/define.lua | sed -n '230,360p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
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
   257    local function anchor_term_span(line, ref_start, term, ignore_case)
   258        if not term or term == "" then
   259            return nil, nil, nil
   260        end
   261        local haystack = ignore_case and line:lower() or line
   262        local needle = ignore_case and term:lower() or term
   263        local best_start, best_end
   264        local search = 1
   265        while search < ref_start do
   266            local start_pos, end_pos = haystack:find(needle, search, true)
   267            if not start_pos or start_pos >= ref_start then
   268                break
   269            end
   270            if end_pos < ref_start then
   271                local suffix = line:sub(end_pos + 1, ref_start - 1)
   272                if is_structured_anchor_suffix(suffix) then
   273                    best_start = start_pos
   274                    best_end = end_pos
   275                end
   276            end
   277            search = start_pos + 1
   278        end
   279        if not best_start then
   280            return nil, nil, nil
   281        end
   282        return best_start, best_end, line:sub(best_start, best_end)
   283    end
   284
   285    local function slug_anchor_term(id)
   286        if not id or not id:find("-", 1, true) then
   287            return nil
   288        end
   289        local term = id:gsub("%-+", " ")
   290        term = trim(term)
   291        if term == "" then
   292            return nil
   293        end
   294        return term
   295    end
   296
   297    --- Derive persisted definition diagnostics from inline footnote references and
   298    --- the final managed definition footer.
   299    --- @param lines string[]
   300    --- @return table[] diagnostics with 0-based columns
   301    function M.footnote_diagnostics(lines)
   302        lines = lines or {}
   303        local footer = managed_footer_start(lines)
   304        if not footer then
   305            return {}
   306        end
   307
   308        local definitions = {}
   309        for i = footer, #lines do
   310            local id, definition = parse_footnote_line(lines[i] or "")
   311            if id then
   312                local term, body = parse_structured_definition(definition)
   313                definitions[id] = {
   314                    definition = body,
   315                    structured_term = term,
   316                }
   317            end
   318        end
   319
   320        local diagnostics = {}
   321        for lnum = 1, footer - 1 do
   322            local line = lines[lnum] or ""
   323            local search = 1
   324            while true do
   325                local ref_start, ref_end, id = line:find("%[%^([^%]]+)%]", search)
   326                if not ref_start then
   327                    break
   328                end
   329                local footnote = definitions[id]
   330                if footnote then
   331                    local structured_start = anchor_term_span(line, ref_start, footnote.structured_term, false)
   332                    local slug_start, _, slug_term = nil, nil, nil
   333                    if not structured_start then
   334                        slug_start, _, slug_term = anchor_term_span(line, ref_start, slug_anchor_term(id), true)
   335                    end
   336                    local term_start = structured_start or slug_start or expand_term_start(line, ref_start)
   337                    local term = footnote.structured_term or slug_term or line:sub(term_start, ref_start - 1)
   338                    table.insert(diagnostics, {
   339                        id = id,
   340                        term = term ~= "" and term or nil,
   341                        definition = footnote.definition,
   342                        lnum = lnum - 1,
   343                        col = term_start - 1,
   344                        end_lnum = lnum - 1,
   345                        end_col = ref_end,
   346                    })
   347                end
   348                search = ref_end + 1
   349            end
   350        end
   351        return diagnostics
   352    end
   353
   354    local function split_text_lines(text)
   355        text = text or ""
   356        local lines = {}
   357        local start = 1
   358        while true do
   359            local nl = text:find("\n", start, true)
   360            if not nl then

exec
/bin/zsh -lc "sed -n '1,260p' workshop/issues/000180-recover-footnote-spans-from-slug-ids.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
---
id: 000180
status: working
deps: []
github_issue:
created: 2026-07-09
updated: 2026-07-09
estimate_hours: 0.20
started: 2026-07-09T11:16:32-07:00
---

# recover footnote spans from slug ids

## Problem

After reopening a chat, persisted definition footnotes only recover multi-word
highlight spans when the footer starts with a structured quoted/backquoted term.
Existing generated footnotes often do not have that structured prefix; for
`serverless functions[^serverless-functions]`, reload falls back to the last
token and highlights only `functions[^serverless-functions]`.

## Spec

`define.footnote_diagnostics` should use the footnote id slug as a secondary
anchor hint when no structured footer term is present. For id
`serverless-functions`, derive the phrase `serverless functions` and look for the
nearest matching phrase before `[^serverless-functions]`, allowing the same
closing quote/bracket suffix as structured terms. Matching should be
case-insensitive but the diagnostic term should preserve the body text as typed.

Precedence:

1. Structured leading quoted/backquoted footer term from #179.
2. Slug-derived phrase from the footnote id.
3. Existing contiguous-token fallback.

The reload highlight and floating-window trigger continue to derive from the
same diagnostic span (ARCH-DRY, ARCH-PURE, ARCH-PURPOSE).

## Done when

- `serverless functions[^serverless-functions]` reloads with a diagnostic and
  highlight spanning `serverless functions[^serverless-functions]`, even when
  the footer is unstructured.
- Case mismatches such as `Serverless Functions[^serverless-functions]` still
  recover the full typed phrase.
- If the slug phrase is absent before the reference, the existing last-token
  fallback remains unchanged.

## Plan

- [x] Add failing pure diagnostics coverage for slug-derived multi-word anchors
  and case-insensitive typed-span preservation.
- [x] Add a reload highlight regression for an unstructured slug-derived
  multi-word anchor.
- [x] Implement slug-derived phrase matching in `lua/parley/define.lua` after
  structured terms and before token fallback.
- [x] Update atlas docs for slug-derived reload span fallback.
- [x] Run focused tests plus lint/diff checks.

## Estimate

Derived via `estimate-logic-v3.1` against the repo-local calibration source from
`sdlc estimate-source` (stale but canonical for this repo).

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.02 impl=0.00
item: lua-neovim design=0.04 impl=0.12
item: milestone-review design=0.00 impl=0.02
total: 0.20
```

## Log

### 2026-07-09

- User showed reload highlight recovering only `functions[^serverless-functions]`
  for `serverless functions[^serverless-functions]`. Root cause: #179 only
  handles structured footer terms; generated unstructured footnotes still use the
  old contiguous-token fallback.
- TDD red: `define_spec` reproduced `functions[^serverless-functions]` starting
  at column 23, and `highlighting_spec` reproduced the same reload highlight
  start. Implemented slug-derived phrase matching between structured footer terms
  and the final token fallback.
- Verification: `make lint` passed; `nvim --headless -c "PlenaryBustedFile
  tests/unit/define_spec.lua"` passed; `nvim --headless -c "PlenaryBustedFile
  tests/integration/highlighting_spec.lua"` passed; scoped `git diff --check`
  passed; full `make test` passed.

exec
/bin/zsh -lc 'git diff --stat 569798381221039ac656f3391c6ded8e5fe143e6..HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
 atlas/chat/inline_define.md                        |  7 ++-
 lua/parley/define.lua                              | 32 +++++++---
 tests/integration/highlighting_spec.lua            | 21 +++++++
 tests/unit/define_spec.lua                         | 36 ++++++++++++
 .../000180-recover-footnote-spans-from-slug-ids.md | 68 +++++++++++++++++++++-
 5 files changed, 151 insertions(+), 13 deletions(-)

exec
/bin/zsh -lc 'git diff --name-only 569798381221039ac656f3391c6ded8e5fe143e6..HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
atlas/chat/inline_define.md
lua/parley/define.lua
tests/integration/highlighting_spec.lua
tests/unit/define_spec.lua
workshop/issues/000180-recover-footnote-spans-from-slug-ids.md

codex
The issue is narrow and the changed files line up with it: one pure helper path in `define.lua`, unit coverage, one integration highlight regression, and an atlas update. I’m now checking edge cases in the helper and running the focused tests rather than relying on the log.
exec
/bin/zsh -lc "nl -ba tests/unit/define_spec.lua | sed -n '380,470p'" in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc "nl -ba tests/integration/highlighting_spec.lua | sed -n '560,620p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
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
   582        it("rehydrates an unstructured slug-derived multi-word footnote anchor highlight", function()
   583            local skill_render = require("parley.skill_render")
   584            local buf = vim.api.nvim_create_buf(false, true)
   585            vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
   586                "Lambda runs serverless functions[^serverless-functions] without servers.",
   587                "",
   588                "[^serverless-functions]: Function-as-a-service compute without server management.",
   589            })
   590
   591            skill_render.refresh_footnote_diagnostics(buf)
   592
   593            local hl_ns = vim.api.nvim_get_namespaces().parley_footnote_hl
   594            local marks = vim.api.nvim_buf_get_extmarks(buf, hl_ns, 0, -1, { details = true })
   595            assert.equals(1, #marks)
   596            assert.equals(0, marks[1][2])
   597            assert.equals(12, marks[1][3])
   598            assert.equals(0, marks[1][4].end_row)
   599            assert.equals(55, marks[1][4].end_col)
   600            assert.equals("DiffChange", marks[1][4].hl_group)
   601        end)
   602
   603        it("refreshes footnote diagnostics on markdown text changes without clearing other Parley diagnostics", function()
   604            local skill_render = require("parley.skill_render")
   605            local ns = skill_render.diag_namespace()
   606            local buf = vim.api.nvim_create_buf(false, true)
   607            vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), buf)
   608            parley._parley_bufs[buf] = "markdown"
   609            vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
   610                "no footnote yet",
   611            })
   612            vim.diagnostic.set(ns, buf, { {
   613                lnum = 0,
   614                col = 0,
   615                message = "review diagnostic",
   616                severity = vim.diagnostic.severity.INFO,
   617                source = "parley-skill",
   618            } })
   619
   620            vim.cmd("doautocmd TextChanged")

 succeeded in 0ms:
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
   421        it("uses the footnote id slug to recover an unstructured multi-word anchor", function()
   422            local diagnostics = define.footnote_diagnostics({
   423                "Lambda runs serverless functions[^serverless-functions] without servers.",
   424                "",
   425                "[^serverless-functions]: Function-as-a-service compute without server management.",
   426            })
   427
   428            assert.are.same({ {
   429                id = "serverless-functions",
   430                term = "serverless functions",
   431                definition = "Function-as-a-service compute without server management.",
   432                lnum = 0,
   433                col = 12,
   434                end_lnum = 0,
   435                end_col = 55,
   436            } }, diagnostics)
   437        end)
   438
   439        it("matches slug-derived anchors case-insensitively while preserving typed body text", function()
   440            local diagnostics = define.footnote_diagnostics({
   441                "Lambda runs Serverless Functions[^serverless-functions] without servers.",
   442                "",
   443                "[^serverless-functions]: Function-as-a-service compute without server management.",
   444            })
   445
   446            assert.are.same({ {
   447                id = "serverless-functions",
   448                term = "Serverless Functions",
   449                definition = "Function-as-a-service compute without server management.",
   450                lnum = 0,
   451                col = 12,
   452                end_lnum = 0,
   453                end_col = 55,
   454            } }, diagnostics)
   455        end)
   456
   457        it("extracts every inline reference to a managed footnote", function()
   458            local diagnostics = define.footnote_diagnostics({
   459                "ASIN[^asin] first, then SKU[^asin] second",
   460                "",
   461                "---",
   462                "",
   463                "[^asin]: Amazon Standard Identification Number.",
   464            })
   465
   466            assert.are.equal(2, #diagnostics)
   467            assert.are.same({
   468                id = "asin",
   469                term = "ASIN",
   470                definition = "Amazon Standard Identification Number.",

exec
/bin/zsh -lc "nl -ba atlas/chat/inline_define.md | sed -n '90,115p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
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
   105    floating definition trigger and the rehydrated inline highlight. If the footer
   106    does not provide a display term, diagnostics try the slug-derived phrase from the
   107    footnote id (`serverless-functions` → `serverless functions`) before falling
   108    back to the historical single-token span immediately before `[^id]`.
   109
   110    ## Keybinding
   111
   112    `<M-CR>` was split out of `chat_shortcut_respond` into its own `chat_define`
   113    registry entry (a single registry entry maps every key×mode to one per-mode
   114    callback, so the split can't live inside `chat_respond`). The `chat_define`
   115    per-mode callback is `{ n=respond, i=respond, v=define_visual, x=define_visual }`

exec
/bin/zsh -lc 'git diff 569798381221039ac656f3391c6ded8e5fe143e6..HEAD -- lua/parley/define.lua tests/unit/define_spec.lua' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
diff --git a/lua/parley/define.lua b/lua/parley/define.lua
index 97f3a83..861ba15 100644
--- a/lua/parley/define.lua
+++ b/lua/parley/define.lua
@@ -254,14 +254,16 @@ local function is_structured_anchor_suffix(text)
     return trim(text):match("^[\"'”’%]%)%}]*$") ~= nil
 end

-local function structured_term_start(line, ref_start, term)
+local function anchor_term_span(line, ref_start, term, ignore_case)
     if not term or term == "" then
-        return nil
+        return nil, nil, nil
     end
+    local haystack = ignore_case and line:lower() or line
+    local needle = ignore_case and term:lower() or term
     local best_start, best_end
     local search = 1
     while search < ref_start do
-        local start_pos, end_pos = line:find(term, search, true)
+        local start_pos, end_pos = haystack:find(needle, search, true)
         if not start_pos or start_pos >= ref_start then
             break
         end
@@ -275,9 +277,21 @@ local function structured_term_start(line, ref_start, term)
         search = start_pos + 1
     end
     if not best_start then
+        return nil, nil, nil
+    end
+    return best_start, best_end, line:sub(best_start, best_end)
+end
+
+local function slug_anchor_term(id)
+    if not id or not id:find("-", 1, true) then
+        return nil
+    end
+    local term = id:gsub("%-+", " ")
+    term = trim(term)
+    if term == "" then
         return nil
     end
-    return best_start, best_end
+    return term
 end

 --- Derive persisted definition diagnostics from inline footnote references and
@@ -314,9 +328,13 @@ function M.footnote_diagnostics(lines)
             end
             local footnote = definitions[id]
             if footnote then
-                local structured_start = structured_term_start(line, ref_start, footnote.structured_term)
-                local term_start = structured_start or expand_term_start(line, ref_start)
-                local term = footnote.structured_term or line:sub(term_start, ref_start - 1)
+                local structured_start = anchor_term_span(line, ref_start, footnote.structured_term, false)
+                local slug_start, _, slug_term = nil, nil, nil
+                if not structured_start then
+                    slug_start, _, slug_term = anchor_term_span(line, ref_start, slug_anchor_term(id), true)
+                end
+                local term_start = structured_start or slug_start or expand_term_start(line, ref_start)
+                local term = footnote.structured_term or slug_term or line:sub(term_start, ref_start - 1)
                 table.insert(diagnostics, {
                     id = id,
                     term = term ~= "" and term or nil,
diff --git a/tests/unit/define_spec.lua b/tests/unit/define_spec.lua
index 140068d..d223db5 100644
--- a/tests/unit/define_spec.lua
+++ b/tests/unit/define_spec.lua
@@ -418,6 +418,42 @@ describe("define durable footnotes", function()
         } }, diagnostics)
     end)

+    it("uses the footnote id slug to recover an unstructured multi-word anchor", function()
+        local diagnostics = define.footnote_diagnostics({
+            "Lambda runs serverless functions[^serverless-functions] without servers.",
+            "",
+            "[^serverless-functions]: Function-as-a-service compute without server management.",
+        })
+
+        assert.are.same({ {
+            id = "serverless-functions",
+            term = "serverless functions",
+            definition = "Function-as-a-service compute without server management.",
+            lnum = 0,
+            col = 12,
+            end_lnum = 0,
+            end_col = 55,
+        } }, diagnostics)
+    end)
+
+    it("matches slug-derived anchors case-insensitively while preserving typed body text", function()
+        local diagnostics = define.footnote_diagnostics({
+            "Lambda runs Serverless Functions[^serverless-functions] without servers.",
+            "",
+            "[^serverless-functions]: Function-as-a-service compute without server management.",
+        })
+
+        assert.are.same({ {
+            id = "serverless-functions",
+            term = "Serverless Functions",
+            definition = "Function-as-a-service compute without server management.",
+            lnum = 0,
+            col = 12,
+            end_lnum = 0,
+            end_col = 55,
+        } }, diagnostics)
+    end)
+
     it("extracts every inline reference to a managed footnote", function()
         local diagnostics = define.footnote_diagnostics({
             "ASIN[^asin] first, then SKU[^asin] second",

exec
/bin/zsh -lc 'rg -n "slug|serverless|structured term is not before|contiguous-token|footnote_diagnostics" tests/unit/define_spec.lua tests/integration/highlighting_spec.lua lua/parley/define.lua' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
lua/parley/define.lua:285:local function slug_anchor_term(id)
lua/parley/define.lua:301:function M.footnote_diagnostics(lines)
lua/parley/define.lua:332:                local slug_start, _, slug_term = nil, nil, nil
lua/parley/define.lua:334:                    slug_start, _, slug_term = anchor_term_span(line, ref_start, slug_anchor_term(id), true)
lua/parley/define.lua:336:                local term_start = structured_start or slug_start or expand_term_start(line, ref_start)
lua/parley/define.lua:337:                local term = footnote.structured_term or slug_term or line:sub(term_start, ref_start - 1)
tests/unit/define_spec.lua:146:    it("slugifies a definition term into a markdown footnote id", function()
tests/unit/define_spec.lua:332:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:350:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:368:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:386:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:403:    it("falls back to contiguous-token anchors when the structured term is not before the reference", function()
tests/unit/define_spec.lua:404:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:421:    it("uses the footnote id slug to recover an unstructured multi-word anchor", function()
tests/unit/define_spec.lua:422:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:423:            "Lambda runs serverless functions[^serverless-functions] without servers.",
tests/unit/define_spec.lua:425:            "[^serverless-functions]: Function-as-a-service compute without server management.",
tests/unit/define_spec.lua:429:            id = "serverless-functions",
tests/unit/define_spec.lua:430:            term = "serverless functions",
tests/unit/define_spec.lua:439:    it("matches slug-derived anchors case-insensitively while preserving typed body text", function()
tests/unit/define_spec.lua:440:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:441:            "Lambda runs Serverless Functions[^serverless-functions] without servers.",
tests/unit/define_spec.lua:443:            "[^serverless-functions]: Function-as-a-service compute without server management.",
tests/unit/define_spec.lua:447:            id = "serverless-functions",
tests/unit/define_spec.lua:458:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:488:        local diagnostics = define.footnote_diagnostics({
tests/integration/highlighting_spec.lua:528:        skill_render.refresh_footnote_diagnostics(buf)
tests/integration/highlighting_spec.lua:549:        skill_render.refresh_footnote_diagnostics(buf)
tests/integration/highlighting_spec.lua:570:        skill_render.refresh_footnote_diagnostics(buf)
tests/integration/highlighting_spec.lua:582:    it("rehydrates an unstructured slug-derived multi-word footnote anchor highlight", function()
tests/integration/highlighting_spec.lua:586:            "Lambda runs serverless functions[^serverless-functions] without servers.",
tests/integration/highlighting_spec.lua:588:            "[^serverless-functions]: Function-as-a-service compute without server management.",
tests/integration/highlighting_spec.lua:591:        skill_render.refresh_footnote_diagnostics(buf)

exec
/bin/zsh -lc 'make lint' in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"' in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"' in /Users/xianxu/workspace/parley.nvim
 succeeded in 1518ms:

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
[32mSuccess[0m    ||    define durable footnotes uses the footnote id slug to recover an unstructured multi-word anchor
[32mSuccess[0m    ||    define durable footnotes matches slug-derived anchors case-insensitively while preserving typed body text
[32mSuccess[0m    ||    define durable footnotes extracts every inline reference to a managed footnote
[32mSuccess[0m    ||    define durable footnotes treats the first footnote definition as the footer even with trailing text

[32mSuccess: [0m    38
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
]111
 succeeded in 2059ms:
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

 succeeded in 2242ms:

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
[32mSuccess[0m    ||    markdown footnote diagnostics rehydrates an unstructured slug-derived multi-word footnote anchor highlight
[32mSuccess[0m    ||    markdown footnote diagnostics refreshes footnote diagnostics on markdown text changes without clearing other Parley diagnostics
[32mSuccess[0m    ||    markdown footnote diagnostics renders managed footnote footers with ParleyFootnote in markdown buffers
[32mSuccess[0m    ||    markdown chat reference rendering refreshes 🌿: branch lines with the chat topic in markdown buffers
[32mSuccess[0m    ||    markdown chat reference rendering does not rewrite 🌿: lines pointing to non-chat files in markdown buffers
[32mSuccess[0m    ||    markdown chat reference rendering refreshes from the updated topic in an open unsaved chat buffer

[32mSuccess: [0m    23
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
]111
codex
Focused verification matches the implementor’s log: lint, the pure `define_spec`, and the highlight integration spec all pass in this environment, with only pre-existing Neovim startup warnings about writable user-state locations. I’m doing one last requirements pass now, especially the “slug absent falls back unchanged” clause and docs gate.
exec
/bin/zsh -lc 'rg -n "footnote|definition|serverless|slug-derived|single-token|floating definition|grey pop|gray pop|pop-under" README.md atlas lua tests workshop/issues/000180-recover-footnote-spans-from-slug-ids.md' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
workshop/issues/000180-recover-footnote-spans-from-slug-ids.md:12:# recover footnote spans from slug ids
workshop/issues/000180-recover-footnote-spans-from-slug-ids.md:16:After reopening a chat, persisted definition footnotes only recover multi-word
workshop/issues/000180-recover-footnote-spans-from-slug-ids.md:18:Existing generated footnotes often do not have that structured prefix; for
workshop/issues/000180-recover-footnote-spans-from-slug-ids.md:19:`serverless functions[^serverless-functions]`, reload falls back to the last
workshop/issues/000180-recover-footnote-spans-from-slug-ids.md:20:token and highlights only `functions[^serverless-functions]`.
workshop/issues/000180-recover-footnote-spans-from-slug-ids.md:24:`define.footnote_diagnostics` should use the footnote id slug as a secondary
workshop/issues/000180-recover-footnote-spans-from-slug-ids.md:26:`serverless-functions`, derive the phrase `serverless functions` and look for the
workshop/issues/000180-recover-footnote-spans-from-slug-ids.md:27:nearest matching phrase before `[^serverless-functions]`, allowing the same
workshop/issues/000180-recover-footnote-spans-from-slug-ids.md:34:2. Slug-derived phrase from the footnote id.
workshop/issues/000180-recover-footnote-spans-from-slug-ids.md:42:- `serverless functions[^serverless-functions]` reloads with a diagnostic and
workshop/issues/000180-recover-footnote-spans-from-slug-ids.md:43:  highlight spanning `serverless functions[^serverless-functions]`, even when
workshop/issues/000180-recover-footnote-spans-from-slug-ids.md:45:- Case mismatches such as `Serverless Functions[^serverless-functions]` still
workshop/issues/000180-recover-footnote-spans-from-slug-ids.md:52:- [x] Add failing pure diagnostics coverage for slug-derived multi-word anchors
workshop/issues/000180-recover-footnote-spans-from-slug-ids.md:54:- [x] Add a reload highlight regression for an unstructured slug-derived
workshop/issues/000180-recover-footnote-spans-from-slug-ids.md:56:- [x] Implement slug-derived phrase matching in `lua/parley/define.lua` after
workshop/issues/000180-recover-footnote-spans-from-slug-ids.md:58:- [x] Update atlas docs for slug-derived reload span fallback.
workshop/issues/000180-recover-footnote-spans-from-slug-ids.md:79:- User showed reload highlight recovering only `functions[^serverless-functions]`
workshop/issues/000180-recover-footnote-spans-from-slug-ids.md:80:  for `serverless functions[^serverless-functions]`. Root cause: #179 only
workshop/issues/000180-recover-footnote-spans-from-slug-ids.md:81:  handles structured footer terms; generated unstructured footnotes still use the
workshop/issues/000180-recover-footnote-spans-from-slug-ids.md:83:- TDD red: `define_spec` reproduced `functions[^serverless-functions]` starting
workshop/issues/000180-recover-footnote-spans-from-slug-ids.md:85:  start. Implemented slug-derived phrase matching between structured footer terms
README.md:118:- `<M-CR>` respond (normal/insert); **visual-select a phrase + `<M-CR>`** → inline term definition — adds a markdown footnote reference/footer and shows a centered diagnostic float, honoring `:ToggleWebSearch` for unfamiliar terms
README.md:119:  - To preserve a multi-word definition highlight after reopening a chat, start the footnote with the display term, e.g. `[^acos]: "Advertising Cost of Sales". Ratio of ad spend to sales revenue.`
lua/parley/define.lua:1:-- Pure core for the inline term-definition feature (#161).
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
lua/parley/define.lua:297:--- Derive persisted definition diagnostics from inline footnote references and
lua/parley/define.lua:298:--- the final managed definition footer.
lua/parley/define.lua:301:function M.footnote_diagnostics(lines)
lua/parley/define.lua:308:    local definitions = {}
lua/parley/define.lua:310:        local id, definition = parse_footnote_line(lines[i] or "")
lua/parley/define.lua:312:            local term, body = parse_structured_definition(definition)
lua/parley/define.lua:313:            definitions[id] = {
lua/parley/define.lua:314:                definition = body,
lua/parley/define.lua:329:            local footnote = definitions[id]
lua/parley/define.lua:330:            if footnote then
lua/parley/define.lua:331:                local structured_start = anchor_term_span(line, ref_start, footnote.structured_term, false)
lua/parley/define.lua:337:                local term = footnote.structured_term or slug_term or line:sub(term_start, ref_start - 1)
lua/parley/define.lua:341:                    definition = footnote.definition,
lua/parley/define.lua:381:--- Strip a final managed definition-footnote footer from text.
lua/parley/define.lua:384:function M.strip_definition_footnote_footer(text)
lua/parley/define.lua:386:    local start = M.managed_footnote_content_start(lines)
lua/parley/define.lua:400:local function replace_or_append_footnote(lines, id, definition)
lua/parley/define.lua:403:    local footnote_line = M.format_footnote_line(id, definition)
lua/parley/define.lua:408:                out[i] = footnote_line
lua/parley/define.lua:412:        out[#out + 1] = footnote_line
lua/parley/define.lua:422:    out[#out + 1] = footnote_line
lua/parley/define.lua:426:--- Insert a markdown footnote reference after the selected text and store the
lua/parley/define.lua:427:--- definition in a managed footer.
lua/parley/define.lua:434:--- @param definition string|nil
lua/parley/define.lua:435:--- @return table { lines: string[], id: string, definition: string, diagnostic_span: table }
lua/parley/define.lua:436:function M.apply_definition_footnote(lines, l1, c1, l2, c2, term, definition)
lua/parley/define.lua:437:    local id = M.footnote_id(term)
lua/parley/define.lua:453:    out = replace_or_append_footnote(out, id, definition)
lua/parley/define.lua:454:    local normalized_definition = trim(definition)
lua/parley/define.lua:455:    if normalized_definition == "" then
lua/parley/define.lua:456:        normalized_definition = "(no definition)"
lua/parley/define.lua:461:        definition = normalized_definition,
tests/fixtures/anthropic_tool_use_request.json:15:      "content": "Please read the file at lua/parley/init.lua and tell me the first function definition you see."
lua/parley/provider_params.lua:16:-- Schema definitions
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
lua/parley/highlighter.lua:747:    -- Managed definition-footnote footer (from the first `[^id]: ...`). It must be
lua/parley/highlighter.lua:749:    if user_highlights.footnote then
lua/parley/highlighter.lua:750:        vim.api.nvim_set_hl(0, "ParleyFootnote", user_highlights.footnote)
lua/parley/highlighter.lua:1098:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1111:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1133:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1138:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1149:            skill_render.refresh_footnote_diagnostics(buf)
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
lua/parley/skill_providers.lua:31:-- Build a manifest from a loaded skill-definition table + its absolute dir.
lua/parley/log_emit.lua:101:-- tool definitions lead with `name`.
lua/parley/chat_parser.lua:301:    local footnote_content_start = require("parley.define").managed_footnote_content_start(lines)
lua/parley/chat_parser.lua:303:    local function final_footnote_boundary(end_line)
lua/parley/chat_parser.lua:304:        if not footnote_content_start or footnote_content_start > end_line then
lua/parley/chat_parser.lua:307:        return footnote_content_start
lua/parley/chat_parser.lua:314:                local boundary = final_footnote_boundary(end_line)
tests/integration/review_diag_display_spec.lua:54:    it("renders footnote diagnostics in a centered non-focusable float without moving the diagnostic span", function()
tests/integration/review_diag_display_spec.lua:74:            source = "parley-footnote",
tests/integration/review_diag_display_spec.lua:105:    it("shows footnote diagnostics only while the cursor is inside the anchor span", function()
tests/integration/review_diag_display_spec.lua:122:            source = "parley-footnote",
tests/integration/review_diag_display_spec.lua:124:        assert.are.equal(0, #display_marks(buf), "cursor starts before the footnote anchor")
tests/integration/review_diag_display_spec.lua:128:        assert.are.equal(1, #diagnostic_floats(), "cursor inside the footnote anchor should show diagnosis")
lua/parley/config.lua:450:    -- definition while n/i keep respond (one entry can't split key×mode). Visual
lua/parley/config.lua:649:        footnote = nil, -- highlight for managed definition-footnote footer lines (default: links to DiagnosticHint)
lua/parley/skills/review/diag_display.lua:114:    if diagnostic.source == "parley-footnote" then
lua/parley/skills/review/diag_display.lua:175:    local footnote_diagnostics = {}
lua/parley/skills/review/diag_display.lua:178:            if diagnostic.source == "parley-footnote" then
lua/parley/skills/review/diag_display.lua:179:                table.insert(footnote_diagnostics, diagnostic)
lua/parley/skills/review/diag_display.lua:186:    table.sort(footnote_diagnostics, function(a, b)
lua/parley/skills/review/diag_display.lua:189:    show_float(footnote_diagnostics)
atlas/index.md:15:- [Inline Term Definition](chat/inline_define.md): Visual-select a phrase + `<M-CR>` → concise context-aware definition as a managed footnote diagnostic rehydrated for markdown buffers (the `define` skill + `emit_definition` tool; honors `:ToggleWebSearch`).
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
lua/parley/buffer_edit.lua:117:--- Replace the entire chat buffer after a pure definition-footnote transform.
lua/parley/buffer_edit.lua:118:function M.replace_all_lines_for_definition(buf, lines)
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
tests/integration/highlighting_spec.lua:570:        skill_render.refresh_footnote_diagnostics(buf)
tests/integration/highlighting_spec.lua:572:        local hl_ns = vim.api.nvim_get_namespaces().parley_footnote_hl
tests/integration/highlighting_spec.lua:582:    it("rehydrates an unstructured slug-derived multi-word footnote anchor highlight", function()
tests/integration/highlighting_spec.lua:586:            "Lambda runs serverless functions[^serverless-functions] without servers.",
tests/integration/highlighting_spec.lua:588:            "[^serverless-functions]: Function-as-a-service compute without server management.",
tests/integration/highlighting_spec.lua:591:        skill_render.refresh_footnote_diagnostics(buf)
tests/integration/highlighting_spec.lua:593:        local hl_ns = vim.api.nvim_get_namespaces().parley_footnote_hl
tests/integration/highlighting_spec.lua:603:    it("refreshes footnote diagnostics on markdown text changes without clearing other Parley diagnostics", function()
tests/integration/highlighting_spec.lua:610:            "no footnote yet",
tests/integration/highlighting_spec.lua:642:        assert.is_not_nil(by_source["parley-footnote"])
tests/integration/highlighting_spec.lua:643:        assert.equals(8, by_source["parley-footnote"].col)
tests/integration/highlighting_spec.lua:645:        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "footnote removed" })
tests/integration/highlighting_spec.lua:653:    it("renders managed footnote footers with ParleyFootnote in markdown buffers", function()
tests/integration/highlighting_spec.lua:684:        assert.is_true(highlighted[2], "Expected markdown footnote definition to use ParleyFootnote")
lua/parley/exporter.lua:611:        /* Inline branch links (footnote-style) */
tests/integration/chat_respond_spec.lua:326:    it("preserves trailing footnotes when completing an answer inserted above them", function()
tests/integration/chat_respond_spec.lua:346:            local mock_qid = "qid_footnote_preserve"
tests/integration/chat_respond_spec.lua:390:        assert.is_not_nil(footer_divider_index, "Expected trailing footnote divider in buffer")
tests/integration/chat_respond_spec.lua:391:        assert.is_true(answer_index < footer_divider_index, "Expected answer above footnote footer")
atlas/chat/drill_in.md:22:- **Ready** = last section is a non-empty `[]` (matches the review-skill ready definition). Markers ending in `{}` are *pending* and stay inline as agent annotations. Strike markers are *never* ready (even with trailing `[]`, since they're proposals not questions).
atlas/chat/drill_in.md:135:skips markdown links `](`, checkboxes, footnote refs, and 1-char content — a
lua/parley/keybinding_registry.lua:489:        desc = "Parley inline term definition (visual) / respond (n/i)",
lua/parley/skills/define/init.lua:15:    tools = { "emit_definition" },
lua/parley/skills/define/init.lua:27:        "you may search first. Then ALWAYS call the emit_definition tool exactly",
lua/parley/skills/define/init.lua:28:        "once with {term, definition}. Do not reply in plain prose.",
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
atlas/chat/inline_define.md:31:   prompt and asks the model to call `emit_definition({term, definition})`.
atlas/chat/inline_define.md:32:4. **`render_definition`** (`on_done`), on a successful lookup: re-verifies the
atlas/chat/inline_define.md:35:   and inserts/updates a final managed footnote footer via one buffer rewrite
atlas/chat/inline_define.md:36:   (`define.apply_definition_footnote`) — a single undo entry that anchors
atlas/chat/inline_define.md:39:   footnote diagnostics (`skill_render.refresh_footnote_diagnostics`), which
atlas/chat/inline_define.md:41:   inline `term[^id]` spans (`define.format_definition` →
atlas/chat/inline_define.md:45:   cursor is on the term/footnote anchor span. A no-`emit_definition` response
atlas/chat/inline_define.md:46:   leaves no footnote reference/footer.
atlas/chat/inline_define.md:50:Native `u` reverts *text*, not decorations. The footnote reference/footer rewrite
atlas/chat/inline_define.md:53:reuses: `render_definition` calls `projection.record_empty_for(buf, original)`
atlas/chat/inline_define.md:54:(pre-footnote hash → empty snapshot), `record(buf)` (footnoted hash → the
atlas/chat/inline_define.md:55:highlight + diagnostic), `ensure_watch(buf)`. Undoing the footnote edit lands on
atlas/chat/inline_define.md:56:the pre-footnote content-hash → the empty snapshot renders → both decorations clear;
atlas/chat/inline_define.md:65:  `context_for_selection`, `format_definition`, `bracket_edit` (plans the `[term]`
atlas/chat/inline_define.md:67:  mapping), `apply_definition_footnote` (durable footer transform), and
atlas/chat/inline_define.md:68:  `strip_definition_footnote_footer` / `footnote_diagnostics` (treat the first
atlas/chat/inline_define.md:69:  markdown footnote definition line as the managed footer boundary).
atlas/chat/inline_define.md:70:- **IO shell** (`lua/parley/init.lua`): `define_visual`, `render_definition`;
atlas/chat/inline_define.md:71:  `lua/parley/buffer_edit.lua` owns the full-buffer footnote rewrite;
atlas/chat/inline_define.md:72:  `lua/parley/skill_render.lua` publishes footnote diagnostics; and
atlas/chat/inline_define.md:80:The footer begins at the first markdown footnote definition line:
atlas/chat/inline_define.md:87:that first footnote definition; the stripper removes that optional separator
atlas/chat/inline_define.md:90:before LLM submission, so durable definitions do not become prompt context.
atlas/chat/inline_define.md:91:`define.footnote_diagnostics` uses the same footer detector to scan inline
atlas/chat/inline_define.md:94:For persisted multi-word anchors, a footnote definition may start with a quoted
atlas/chat/inline_define.md:103:On reload, `define.footnote_diagnostics` uses that leading display term to find
atlas/chat/inline_define.md:105:floating definition trigger and the rehydrated inline highlight. If the footer
atlas/chat/inline_define.md:106:does not provide a display term, diagnostics try the slug-derived phrase from the
atlas/chat/inline_define.md:107:footnote id (`serverless-functions` → `serverless functions`) before falling
atlas/chat/inline_define.md:108:back to the historical single-token span immediately before `[^id]`.
atlas/chat/inline_define.md:130:`emit_definition` (`lua/parley/tools/builtin/emit_definition.lua`, in
atlas/chat/inline_define.md:131:`BUILTIN_NAMES`) is an **output-only** tool: `{term, definition}` schema,
atlas/chat/inline_define.md:139:- `skill_render.refresh_footnote_diagnostics` owns only diagnostics tagged
atlas/chat/inline_define.md:140:  `parley-footnote` and preserves other `parley_skill` diagnostics, so review
atlas/chat/inline_define.md:141:  diagnostics are not cleared by markdown footnote refresh.
atlas/chat/inline_define.md:142:- A footnote diagnostic's Parley float auto-hides when the cursor leaves its
atlas/chat/inline_define.md:143:  term/footnote anchor span. The footnote persists in the file if saved.
atlas/chat/inline_define.md:147:- `lua/parley/define.lua` — pure core (slice / context / format / footnote footer / diagnostics).
atlas/chat/inline_define.md:148:- `lua/parley/init.lua` — `define_visual`, `render_definition`, `chat_define` wiring.
atlas/chat/inline_define.md:150:- `lua/parley/skill_render.lua` — footnote diagnostic refresh in the shared namespace.
atlas/chat/inline_define.md:151:- `lua/parley/chat_respond.lua` — strips managed footnote footer from LLM messages.
atlas/chat/inline_define.md:153:- `lua/parley/tools/builtin/emit_definition.lua` — output-only structured tool.
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
atlas/ui/highlights.md:4:Custom groups (`ParleyQuestion`, `ParleyFileReference`, `ParleyChatReference`, `ParleyThinking`, `ParleyAnnotation`, `ParleyReference`, `ParleyFootnote`, `ParleyPickerApproximateMatch`, `InterviewTimestamp`, `InterviewThought`) linked to standard Neovim groups. `ParleyReference` (default underline) marks drill-in `[referenced span]` brackets — see [chat/drill_in](../chat/drill_in.md). `ParleyFootnote` (default `DiagnosticHint`) marks managed definition-footnote footer lines.
atlas/ui/highlights.md:9:- Managed definition-footnote footers (from the first `[^id]: ...` line) use
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
lua/parley/init.lua:1627:    -- rather than attach a footnote reference to shifted text.
lua/parley/init.lua:1635:    -- Store the definition as a markdown footnote in ONE full-buffer set_lines
lua/parley/init.lua:1640:    local e = define.apply_definition_footnote(lines, sr, sc - 1, er, ec - 1, input.term or phrase, input.definition)
lua/parley/init.lua:1641:    require("parley.buffer_edit").replace_all_lines_for_definition(buf, e.lines)
lua/parley/init.lua:1645:    skill_render.refresh_footnote_diagnostics(buf)
lua/parley/init.lua:1647:    -- Record projection states so undo/redo of the footnote edit clears/restores
lua/parley/init.lua:1649:    -- snapshot, footnoted hash → highlight+diagnostic; attach the watcher.
lua/parley/init.lua:1656:    -- virtual_lines reveals the definition immediately.
lua/parley/init.lua:1663:-- turn whose on_done stores + renders the definition inline. Pure logic lives
lua/parley/init.lua:1691:        on_done = function(result) render_definition(buf, span, phrase, result) end,
atlas/traceability.yaml:93:      - lua/parley/tools/builtin/emit_definition.lua
lua/parley/tools/builtin/emit_definition.lua:1:-- `emit_definition` — output-only structured tool for the inline term-definition
lua/parley/tools/builtin/emit_definition.lua:3:-- {term, definition}; there are NO side effects — define's on_done reads the
lua/parley/tools/builtin/emit_definition.lua:10:    name = "emit_definition",
lua/parley/tools/builtin/emit_definition.lua:12:    description = "Return a concise definition of the selected term as used in "
lua/parley/tools/builtin/emit_definition.lua:18:            definition = {
lua/parley/tools/builtin/emit_definition.lua:20:                description = "A concise 1–3 sentence definition of the term, in context.",
lua/parley/tools/builtin/emit_definition.lua:23:        required = { "term", "definition" },
lua/parley/tools/builtin/emit_definition.lua:28:        return { content = "", name = "emit_definition" }
tests/integration/define_spec.lua:1:-- Integration tests for the inline term-definition feature (#161).
tests/integration/define_spec.lua:2:-- See workshop/issues/000161-inline-term-definition.md and its plan.
tests/integration/define_spec.lua:11:-- SSE builder + an emit_definition tool-call response (mirrors skill_invoke_spec).
tests/integration/define_spec.lua:22:local function emit_definition_sse(term, definition)
tests/integration/define_spec.lua:25:          content_block = { type = "tool_use", id = "d1", name = "emit_definition", input = {} } },
tests/integration/define_spec.lua:27:          delta = { type = "input_json_delta", partial_json = vim.json.encode({ term = term, definition = definition }) } },
tests/integration/define_spec.lua:33:describe("emit_definition tool", function()
tests/integration/define_spec.lua:41:            return reg.select({ "emit_definition" })
tests/integration/define_spec.lua:48:        local def = require("parley.tools.builtin.emit_definition")
tests/integration/define_spec.lua:53:        assert.is_not_nil(props.definition)
tests/integration/define_spec.lua:73:        assert.same({ "emit_definition" }, skill.tools)
tests/integration/define_spec.lua:103:                raw_response = emit_definition_sse("ASIN", "Amazon Standard Identification Number."),
tests/integration/define_spec.lua:119:            activation = { manual = true }, tools = { "emit_definition" },
tests/integration/define_spec.lua:182:        local on = dispatcher.prepare_payload(msgs, MODEL, "anthropic", { "emit_definition" })
tests/integration/define_spec.lua:186:        local off = dispatcher.prepare_payload(msgs, MODEL, "anthropic", { "emit_definition" })
tests/integration/define_spec.lua:193:describe("define_visual + render_definition (#161)", function()
tests/integration/define_spec.lua:219:                raw_response = emit_definition_sse("ASIN", "Amazon Standard Identification Number."),
tests/integration/define_spec.lua:244:    it("stores the definition as a durable footnote, highlights the term/reference span, and shows the diagnostic", function()
tests/integration/define_spec.lua:285:                raw_response = emit_definition_sse("ASIN", table.concat({
tests/integration/define_spec.lua:310:    it("re-defining a footnoted term updates the footer without duplicating the inline reference", function()
tests/integration/define_spec.lua:320:                raw_response = emit_definition_sse("ASIN", "Updated definition."),
tests/integration/define_spec.lua:330:            return table.concat(lines, "\n"):find("%[%^asin%]: Updated definition%.") ~= nil
tests/integration/define_spec.lua:338:            "[^asin]: Updated definition.",
tests/integration/define_spec.lua:342:    it("u undoes the footnote edit + clears decorations; C-r restores them (R1)", function()
tests/integration/define_spec.lua:352:        -- undo: the footnote edit reverts; the projection watcher (TextChanged) clears
tests/integration/define_spec.lua:361:            :find("%[%^asin%]:", 1, false), "footnote not removed on undo")
tests/integration/define_spec.lua:366:        -- redo: footnote edit + decorations return
tests/integration/define_spec.lua:412:            "a no-tool response must not footnote the term")
lua/parley/chat_respond.lua:79:local function is_footnote_definition_line(line)
lua/parley/chat_respond.lua:83:local function trailing_footnote_boundary(lines, search_start_0)
lua/parley/chat_respond.lua:85:    local footnote_start = nil
lua/parley/chat_respond.lua:87:        if is_footnote_definition_line(lines[i]) then
lua/parley/chat_respond.lua:88:            footnote_start = i
lua/parley/chat_respond.lua:92:    if not footnote_start then
lua/parley/chat_respond.lua:96:    for i = footnote_start, #lines do
lua/parley/chat_respond.lua:98:        if line:match("%S") and not is_footnote_definition_line(line) then
lua/parley/chat_respond.lua:103:    local boundary = footnote_start
lua/parley/chat_respond.lua:417:                text = define.strip_definition_footnote_footer(text)
lua/parley/chat_respond.lua:429:                local text = define.strip_definition_footnote_footer(read_block_text(k, b))
lua/parley/chat_respond.lua:448:                    table.insert(answer_blocks, { type = "text", text = define.strip_definition_footnote_footer(text) })
lua/parley/chat_respond.lua:466:                    table.insert(messages, { role = "user", content = define.strip_definition_footnote_footer(text) })
lua/parley/chat_respond.lua:655:                copy.text = define.strip_definition_footnote_footer(copy.text)
lua/parley/chat_respond.lua:741:                    local question_content = define.strip_definition_footnote_footer(exchange.question.content)
lua/parley/chat_respond.lua:846:                        table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.answer.content) })
lua/parley/chat_respond.lua:851:                        table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.summary.content) })
lua/parley/chat_respond.lua:859:                            table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.answer.content) })
lua/parley/chat_respond.lua:1860:                local footnote_boundary = trailing_footnote_boundary(all_current_lines, exchange_end)
lua/parley/chat_respond.lua:1861:                if footnote_boundary then
lua/parley/chat_respond.lua:1862:                    next_content_start = footnote_boundary
lua/parley/tools/init.lua:26:--- Register a ToolDefinition. Validates via `types.validate_definition`;
lua/parley/tools/init.lua:60:    local ok, err = types.validate_definition(def)
lua/parley/tools/init.lua:167:    "emit_definition",
lua/parley/tools/init.lua:178:--- repeated `setup()` invocations do not accumulate stale definitions.
atlas/modes/review.md:176:The same controller also renders managed footnote diagnostics; those use a
atlas/modes/review.md:178:cursor is inside the term/`[^footnote]` diagnostic span.
atlas/modes/review.md:207:- `lua/parley/skills/review/init.lua` — skill definition (+ `source(ctx)` mode composition, `mode` arg), marker parsing, `run_via_invoke` (marker pre-check + resubmit), keybindings
lua/parley/skills/review/init.lua:441:-- Skill definition
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
tests/unit/highlighter_spec.lua:27:    it("rejects a footnote reference", function()
tests/unit/parse_chat_spec.lua:667:    it("stops a final open question before a managed footnote footer", function()
tests/unit/parse_chat_spec.lua:680:    it("stops a final open question before an optional legacy footnote divider", function()
tests/unit/parse_chat_spec.lua:695:    it("positions a final open-question answer above managed footnotes", function()
tests/unit/parse_chat_spec.lua:712:    it("stops a final open question before the first footnote definition even with trailing text", function()
tests/unit/build_messages_spec.lua:707:describe("_build_messages: durable definition footnotes", function()
tests/unit/build_messages_spec.lua:708:    it("strips managed definition footnote footers from user and assistant content", function()
tests/unit/build_messages_spec.lua:751:            "second half, not a footnote",
tests/unit/build_messages_spec.lua:1605:describe("build_messages_from_model: durable definition footnotes", function()
tests/unit/build_messages_spec.lua:1608:    it("strips managed footnote footers from live question and answer blocks", function()
tests/unit/define_spec.lua:2:-- See workshop/issues/000161-inline-term-definition.md and its plan.
tests/unit/define_spec.lua:67:describe("define.format_definition", function()
tests/unit/define_spec.lua:68:    it("composes 'TERM — definition'", function()
tests/unit/define_spec.lua:69:        local msg = define.format_definition("ASIN", "Amazon Standard Identification Number.", 200)
tests/unit/define_spec.lua:74:        local msg = define.format_definition("X", string.rep("word ", 30), 40)
tests/unit/define_spec.lua:89:            assert.equals("X — word", define.format_definition("X", "word"))
tests/unit/define_spec.lua:96:    it("trims a nil/blank definition to a safe string", function()
tests/unit/define_spec.lua:97:        assert.equals("X — (no definition)", define.format_definition("X", nil, 80))
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
tests/unit/define_spec.lua:359:            definition = "Ratio of ad spend to sales revenue.",
tests/unit/define_spec.lua:367:    it("uses a leading backquoted footnote term to span a multi-word persisted anchor", function()
tests/unit/define_spec.lua:368:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:377:            definition = "Ratio of ad spend to sales revenue.",
tests/unit/define_spec.lua:386:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:395:            definition = "Ratio of ad spend to sales revenue.",
tests/unit/define_spec.lua:404:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:413:            definition = "Ratio of ad spend to sales revenue.",
tests/unit/define_spec.lua:421:    it("uses the footnote id slug to recover an unstructured multi-word anchor", function()
tests/unit/define_spec.lua:422:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:423:            "Lambda runs serverless functions[^serverless-functions] without servers.",
tests/unit/define_spec.lua:425:            "[^serverless-functions]: Function-as-a-service compute without server management.",
tests/unit/define_spec.lua:429:            id = "serverless-functions",
tests/unit/define_spec.lua:430:            term = "serverless functions",
tests/unit/define_spec.lua:431:            definition = "Function-as-a-service compute without server management.",
tests/unit/define_spec.lua:439:    it("matches slug-derived anchors case-insensitively while preserving typed body text", function()
tests/unit/define_spec.lua:440:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:441:            "Lambda runs Serverless Functions[^serverless-functions] without servers.",
tests/unit/define_spec.lua:443:            "[^serverless-functions]: Function-as-a-service compute without server management.",
tests/unit/define_spec.lua:447:            id = "serverless-functions",
tests/unit/define_spec.lua:449:            definition = "Function-as-a-service compute without server management.",
tests/unit/define_spec.lua:457:    it("extracts every inline reference to a managed footnote", function()
tests/unit/define_spec.lua:458:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:470:            definition = "Amazon Standard Identification Number.",
tests/unit/define_spec.lua:479:            definition = "Amazon Standard Identification Number.",
tests/unit/define_spec.lua:487:    it("treats the first footnote definition as the footer even with trailing text", function()
tests/unit/define_spec.lua:488:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:499:            definition = "Amazon Standard Identification Number.",
tests/unit/tools_builtin_registered_spec.lua:14:--   2. Each builtin is a valid ToolDefinition per types.validate_definition.
tests/unit/tools_builtin_registered_spec.lua:50:    it("each builtin passes types.validate_definition", function()
tests/unit/tools_builtin_registered_spec.lua:55:            local ok, err = types.validate_definition(def)
tests/unit/anthropic_tool_encode_spec.lua:55:    it("converts multiple definitions preserving input order", function()
tests/unit/tools_builtin_propose_edits_spec.lua:22:describe("propose_edits tool definition", function()
tests/unit/tools_builtin_propose_edits_spec.lua:24:        local ok, err = types.validate_definition(propose_edits)
tests/unit/tools_registry_spec.lua:6:--   get(name)        — lookup by name, returns the definition or nil
tests/unit/tools_registry_spec.lua:8:--   select(names)    — returns a list of definitions matching the given
tests/unit/tools_registry_spec.lua:45:        it("accepts and stores a valid definition", function()
tests/unit/tools_registry_spec.lua:51:        it("raises on invalid definition (missing name)", function()
tests/unit/tools_registry_spec.lua:57:        it("raises on invalid definition (empty name)", function()
tests/unit/tools_registry_spec.lua:89:        it("returns the definition for a registered name", function()
tests/unit/tools_registry_spec.lua:112:        it("returns matching definitions in the order given", function()
tests/unit/oauth_spec.lua:264:    it("H6: migrates legacy single-token storage into a multi-account store", function()

exec
/bin/zsh -lc 'git diff --check 569798381221039ac656f3391c6ded8e5fe143e6..HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
exec
/bin/zsh -lc 'make test' in /Users/xianxu/workspace/parley.nvim
 succeeded in 17355ms:
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
PASS: tests/unit/discovery_matcher_spec.lua
PASS: tests/unit/discovery_descriptor_spec.lua
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
PASS: tests/unit/markdown_draft_block_spec.lua
PASS: tests/unit/issues_spec.lua
PASS: tests/unit/config_tools_spec.lua
PASS: tests/unit/neighborhood_spec.lua
PASS: tests/unit/obfuscate_spec.lua
PASS: tests/unit/oauth_spec.lua
PASS: tests/unit/outline_spec.lua
PASS: tests/unit/note_finder_logic_spec.lua
PASS: tests/unit/open_chat_reference_spec.lua
PASS: tests/unit/parley_harness_golden_spec.lua
PASS: tests/unit/parse_chat_spec.lua
PASS: tests/unit/picker_items_spec.lua
PASS: tests/unit/parley_harness_spec.lua
PASS: tests/unit/process_directory_pattern_spec.lua
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
PASS: tests/unit/spell_spec.lua
PASS: tests/unit/skill_render_spec.lua
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
PASS: tests/unit/tools_builtin_find_spec.lua
PASS: tests/unit/tools_serialize_spec.lua
PASS: tests/unit/tools_types_spec.lua
PASS: tests/unit/tools_dispatcher_spec.lua
PASS: tests/unit/vault_spec.lua
PASS: tests/unit/vision_spec.lua
PASS: tests/unit/tools_builtin_chat_history_search_spec.lua
PASS: tests/unit/super_repo_spec.lua
PASS: tests/unit/tools_builtin_ack_spec.lua
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
PASS: tests/integration/cliproxy_dispatch_spec.lua
PASS: tests/integration/export_spec.lua
PASS: tests/integration/progress_spec.lua
PASS: tests/integration/neighborhood_completion_spec.lua
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
PASS: tests/integration/voice_apply_spec.lua
PASS: tests/integration/tree_export_spec.lua
PASS: tests/integration/tasker_run_spec.lua
PASS: tests/integration/highlighting_spec.lua
PASS: tests/integration/chat_respond_spec.lua
PASS: tests/integration/cliproxy_lifecycle_spec.lua

codex
```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The code change satisfies the core behavior: slug-derived multi-word anchors are recovered after structured terms and before the old token fallback, with case-insensitive matching and typed text preservation. I found no correctness blocker, and `make test` plus `git diff --check` pass. Two cheap documentation/test gaps remain before I’d call the boundary clean.

1. Strengths:
- [lua/parley/define.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/define.lua:257) keeps the matching logic in the pure diagnostics path, so reload highlight and float trigger still derive from one span source.
- [tests/unit/define_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/unit/define_spec.lua:421) pins slug-derived recovery.
- [tests/unit/define_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/unit/define_spec.lua:439) pins case-insensitive matching while preserving typed body text.
- [tests/integration/highlighting_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/integration/highlighting_spec.lua:582) verifies the rehydrated highlight path, not only pure diagnostics.

2. Critical findings:
- None.

3. Important findings:
- [README.md](/Users/xianxu/workspace/parley.nvim/README.md:119): README still says preserving a multi-word definition highlight after reopening requires starting the footnote with the display term. This diff adds slug-derived recovery for generated unstructured footnotes, so the user-facing doc is now incomplete. Fix: update that line to mention structured display terms first, and slug-derived ids such as `serverless-functions` as the fallback.
- [tests/unit/define_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/unit/define_spec.lua:403): The issue’s Done-when explicitly says “If the slug phrase is absent before the reference, the existing last-token fallback remains unchanged,” but the tests only cover fallback for a non-hyphen id / structured-term miss. Add one pure test with a hyphenated id whose slug phrase is absent, asserting the old single-token span is used.

4. Minor findings:
- None.

5. Test coverage notes:
- Verified: `make lint`, focused `define_spec`, focused `highlighting_spec`, full `make test`, and `git diff --check 569798381221039ac656f3391c6ded8e5fe143e6..HEAD` all pass.
- Neovim printed startup warnings about user-state/parser paths during focused tests, but the tests completed green.

6. Architectural notes for upcoming work:
- ARCH-DRY: Pass. One helper path drives structured and slug matching; no duplicated span logic in the renderer.
- ARCH-PURE: Pass. The new behavior lives in `define.footnote_diagnostics`, a pure function with direct unit coverage; IO remains in render/highlight glue.
- ARCH-PURPOSE: Mostly pass. The feature purpose is delivered, but the README consumer and absent-slug regression test should be closed so the documented/user-facing surface matches the behavior.

7. Plan revision recommendations:
- None. The issue plan matches the implemented scope; no `## Revisions` entry needed.
tokens used
65,980
```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The code change satisfies the core behavior: slug-derived multi-word anchors are recovered after structured terms and before the old token fallback, with case-insensitive matching and typed text preservation. I found no correctness blocker, and `make test` plus `git diff --check` pass. Two cheap documentation/test gaps remain before I’d call the boundary clean.

1. Strengths:
- [lua/parley/define.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/define.lua:257) keeps the matching logic in the pure diagnostics path, so reload highlight and float trigger still derive from one span source.
- [tests/unit/define_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/unit/define_spec.lua:421) pins slug-derived recovery.
- [tests/unit/define_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/unit/define_spec.lua:439) pins case-insensitive matching while preserving typed body text.
- [tests/integration/highlighting_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/integration/highlighting_spec.lua:582) verifies the rehydrated highlight path, not only pure diagnostics.

2. Critical findings:
- None.

3. Important findings:
- [README.md](/Users/xianxu/workspace/parley.nvim/README.md:119): README still says preserving a multi-word definition highlight after reopening requires starting the footnote with the display term. This diff adds slug-derived recovery for generated unstructured footnotes, so the user-facing doc is now incomplete. Fix: update that line to mention structured display terms first, and slug-derived ids such as `serverless-functions` as the fallback.
- [tests/unit/define_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/unit/define_spec.lua:403): The issue’s Done-when explicitly says “If the slug phrase is absent before the reference, the existing last-token fallback remains unchanged,” but the tests only cover fallback for a non-hyphen id / structured-term miss. Add one pure test with a hyphenated id whose slug phrase is absent, asserting the old single-token span is used.

4. Minor findings:
- None.

5. Test coverage notes:
- Verified: `make lint`, focused `define_spec`, focused `highlighting_spec`, full `make test`, and `git diff --check 569798381221039ac656f3391c6ded8e5fe143e6..HEAD` all pass.
- Neovim printed startup warnings about user-state/parser paths during focused tests, but the tests completed green.

6. Architectural notes for upcoming work:
- ARCH-DRY: Pass. One helper path drives structured and slug matching; no duplicated span logic in the renderer.
- ARCH-PURE: Pass. The new behavior lives in `define.footnote_diagnostics`, a pure function with direct unit coverage; IO remains in render/highlight glue.
- ARCH-PURPOSE: Mostly pass. The feature purpose is delivered, but the README consumer and absent-slug regression test should be closed so the documented/user-facing surface matches the behavior.

7. Plan revision recommendations:
- None. The issue plan matches the implemented scope; no `## Revisions` entry needed.
