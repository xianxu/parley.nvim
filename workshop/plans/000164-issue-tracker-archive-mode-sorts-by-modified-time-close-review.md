# Boundary Review — parley.nvim#164 (whole-issue close)

| field | value |
|-------|-------|
| issue | 164 — issue tracker archive mode sorts by modified time |
| repo | parley.nvim |
| issue file | workshop/issues/000164-issue-tracker-archive-mode-sorts-by-modified-time.md |
| boundary | whole-issue close |
| milestone | — |
| window | 7cdeb5ae4644f6ef7296ea448fb64fb54eb5ae4c..HEAD |
| command | sdlc close --issue 164 |
| reviewer | codex |
| timestamp | 2026-07-08T08:10:19-07:00 |
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
session id: 019f4246-55f9-7762-b944-0db0e4238067
--------
user
# Code review — the one SDLC boundary review

You are conducting a fresh-context code review at a development boundary —
whole-issue close — in the **parley.nvim** repository.

- repository: parley.nvim   (root: /Users/xianxu/workspace/parley.nvim)
- issue:      parley.nvim#164   (file: workshop/issues/000164-issue-tracker-archive-mode-sorts-by-modified-time.md)
- window:     Base: 7cdeb5ae4644f6ef7296ea448fb64fb54eb5ae4c   Head: HEAD

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
diff --git a/atlas/issues/issue-management.md b/atlas/issues/issue-management.md
index 2570754..310d9a1 100644
--- a/atlas/issues/issue-management.md
+++ b/atlas/issues/issue-management.md
@@ -17,7 +17,7 @@ default), so every reader derives from the one cue source.
 
 ## Commands
 - `:ParleyIssueNew` (`<C-y>c`): **delegates to `sdlc issue new`** (M3 #116) — the canonical creator (id allocation + the cue/sdlc-owned template + broadcast to origin/main per ariadne#82) — then opens the created file. The title prompt is prefixed with the destination repo — `[<repo>] Issue title: ` — where `<repo>` is the basename of the git root `issues_dir` resolves against (the editor's cwd root), so issues aren't created in the wrong repo (#142)
-- `:ParleyIssueFinder` (`<C-y>f`): float picker with status badges and 2-state view cycling — `<Tab>` (natural key; `<C-a>` kept for back-compat) toggles between `issues` (all of `workshop/issues/`, done items visible — the default) and `history` (archived items in `workshop/history/`) (#158, superseding the tri-state all/active/all+history from #152)
+- `:ParleyIssueFinder` (`<C-y>f`): float picker with status badges and 2-state view cycling — `<Tab>` (natural key; `<C-a>` kept for back-compat) toggles between `issues` (all of `workshop/issues/`, done items visible — the default, sorted by the existing status/ID order) and `history` (archived items in `workshop/history/`, sorted by file modification time ascending so the newest archive row sits closest to the bottom-anchored prompt) (#158, superseding the tri-state all/active/all+history from #152)
 - `:ParleyIssueNext` (`<C-y>x`): open next runnable issue (oldest open with all deps done)
 - `:ParleyIssueStatus` (`<C-y>s`): cycle frontmatter status using the first lifecycle transition for the current status in generated vocabulary order
 - `:ParleyIssueDecompose` (`<C-y>i`): create child issue from plan line, add to parent deps, and write a markdown link `[issue NNNNNN](./NNNNNN-slug.md)` into the parent's plan line; the new child file gets a `Parent: [issue PPPPPP](./PPPPPP-...md)` backlink under its title. (M3 #116: decompose **retains** parley's `render_issue_template` — its semantics, parent.deps += child + the parent plan-line link + the backlink, are incompatible with `sdlc issue new`'s shape, so unlike `:ParleyIssueNew` it is not delegated.)
diff --git a/lua/parley/issue_finder.lua b/lua/parley/issue_finder.lua
index 627e5c6..b84ec4d 100644
--- a/lua/parley/issue_finder.lua
+++ b/lua/parley/issue_finder.lua
@@ -43,6 +43,26 @@ M.filter_for_view = function(view_mode, all_issues)
     return filtered
 end
 
+M.sort_for_view = function(view_mode, issues)
+    if view_mode ~= 1 then
+        return issues_mod.topo_sort(issues)
+    end
+
+    local sorted = {}
+    for _, issue in ipairs(issues) do
+        table.insert(sorted, issue)
+    end
+    table.sort(sorted, function(a, b)
+        local ma = a.mtime or 0
+        local mb = b.mtime or 0
+        if ma ~= mb then
+            return ma < mb
+        end
+        return a.id < b.id
+    end)
+    return sorted
+end
+
 --------------------------------------------------------------------------------
 -- Reopen helper
 --------------------------------------------------------------------------------
@@ -174,7 +194,7 @@ M.open = function(_options)
         end
     end
 
-    local sorted = issues_mod.topo_sort(M.filter_for_view(view_mode, all_issues))
+    local sorted = M.sort_for_view(view_mode, M.filter_for_view(view_mode, all_issues))
 
     -- Build picker items
     local items = {}
diff --git a/lua/parley/issues.lua b/lua/parley/issues.lua
index ab14948..7b66df7 100644
--- a/lua/parley/issues.lua
+++ b/lua/parley/issues.lua
@@ -558,6 +558,7 @@ local function scan_dir_issues(dir, issues, is_archived)
                 if cached and cached.mtime == stat.mtime.sec then
                     -- Use cached data, just update archived flag
                     local issue = vim.deepcopy(cached.issue_data)
+                    issue.mtime = stat.mtime.sec
                     issue.archived = is_archived or false
                     table.insert(issues, issue)
                 else
@@ -575,6 +576,7 @@ local function scan_dir_issues(dir, issues, is_archived)
                         updated = fm and fm.updated or "",
                         github_issue = fm and fm.github_issue or nil,
                         path = path,
+                        mtime = stat.mtime.sec,
                     }
                     _file_cache[path] = { mtime = stat.mtime.sec, issue_data = issue_data }
                     local issue = vim.deepcopy(issue_data)
diff --git a/tests/unit/issue_finder_spec.lua b/tests/unit/issue_finder_spec.lua
index 483df39..79a7111 100644
--- a/tests/unit/issue_finder_spec.lua
+++ b/tests/unit/issue_finder_spec.lua
@@ -68,6 +68,38 @@ describe("IssueFinder view-mode logic", function()
         end)
     end)
 
+    describe("sort_for_view", function()
+        it("keeps issues view on status/ID ordering", function()
+            local sorted = issue_finder.sort_for_view(0, {
+                { id = "0003", status = "done", mtime = 300 },
+                { id = "0002", status = "blocked", mtime = 200 },
+                { id = "0001", status = "open", mtime = 100 },
+            })
+
+            assert.same({ "0001", "0002", "0003" }, ids(sorted))
+        end)
+
+        it("sorts history view by mtime ascending so newest is last", function()
+            local sorted = issue_finder.sort_for_view(1, {
+                { id = "0003", status = "done", mtime = 300 },
+                { id = "0001", status = "done", mtime = 100 },
+                { id = "0002", status = "done", mtime = 200 },
+            })
+
+            assert.same({ "0001", "0002", "0003" }, ids(sorted))
+        end)
+
+        it("uses ID as the deterministic history tie-breaker", function()
+            local sorted = issue_finder.sort_for_view(1, {
+                { id = "0003", status = "done", mtime = 100 },
+                { id = "0001", status = "done", mtime = 100 },
+                { id = "0002", status = "done", mtime = 100 },
+            })
+
+            assert.same({ "0001", "0002", "0003" }, ids(sorted))
+        end)
+    end)
+
     describe("VIEW_LABELS", function()
         it("labels the 2-state cycle issues → history", function()
             assert.equals("issues", issue_finder.VIEW_LABELS[0])
diff --git a/tests/unit/issues_spec.lua b/tests/unit/issues_spec.lua
index 4896e0b..cfeb673 100644
--- a/tests/unit/issues_spec.lua
+++ b/tests/unit/issues_spec.lua
@@ -600,6 +600,67 @@ describe("topo_sort", function()
     end)
 end)
 
+--------------------------------------------------------------------------------
+-- scan_issues mtime
+--------------------------------------------------------------------------------
+
+describe("scan_issues mtime", function()
+    local base_dir
+    local issues_dir
+    local history_dir
+
+    local function write_issue(dir, id, title)
+        local path = string.format("%s/%s-%s.md", dir, id, issues.slugify(title))
+        vim.fn.writefile({
+            "---",
+            "id: " .. id,
+            "status: done",
+            "deps: []",
+            "created: 2026-07-08",
+            "updated: 2026-07-08",
+            "---",
+            "",
+            "# " .. title,
+        }, path)
+        return path
+    end
+
+    before_each(function()
+        base_dir = vim.fn.tempname() .. "-issue-scan-mtime"
+        issues_dir = base_dir .. "/issues"
+        history_dir = base_dir .. "/history"
+        vim.fn.mkdir(issues_dir, "p")
+        vim.fn.mkdir(history_dir, "p")
+        issues.clear_cache()
+    end)
+
+    after_each(function()
+        if base_dir then
+            vim.fn.delete(base_dir, "rf")
+        end
+        issues.clear_cache()
+    end)
+
+    it("includes filesystem mtime for archived history rows", function()
+        local old_path = write_issue(history_dir, "000001", "Old archived")
+        local new_path = write_issue(history_dir, "000002", "New archived")
+        vim.loop.fs_utime(old_path, 100, 100)
+        vim.loop.fs_utime(new_path, 200, 200)
+
+        local scanned = issues.scan_issues(issues_dir, {
+            include_history = true,
+            history_dir_override = history_dir,
+        })
+
+        local by_id = {}
+        for _, issue in ipairs(scanned) do
+            by_id[issue.id] = issue
+        end
+        assert.equals(100, by_id["000001"].mtime)
+        assert.equals(200, by_id["000002"].mtime)
+    end)
+end)
+
 --------------------------------------------------------------------------------
 -- format_deps
 --------------------------------------------------------------------------------


codex
I’ll use the repo workflow instructions plus the code-review stance here: first I’m reading the required SDLC/help context and the issue artifact, then I’ll verify the diff against the actual files rather than relying on the supplied patch.
exec
/bin/zsh -lc "sed -n '1,220p' /Users/xianxu/.codex/skills/.system/superpowers-using-superpowers/SKILL.md" in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc "sed -n '1,220p' /Users/xianxu/workspace/ariadne/construct/local/sdlc/SKILL.md" in /Users/xianxu/workspace/parley.nvim
 exited 1 in 0ms:
sed: /Users/xianxu/.codex/skills/.system/superpowers-using-superpowers/SKILL.md: No such file or directory

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
- **To make a decoration-only action undoable, anchor it to a text edit + reuse `projection` — `u` reverts text, never extmarks/diagnostics.** The operator wanted the define highlight+diagnostic undoable; native `u` can't touch pure decorations (review's are undoable only because a round edits text). Resolution: a minimal `[term]` bracket (one `set_lines` = one undo entry) as the anchor + reuse `skills/review/projection.lua` (`record_empty_for(pre)` + `record(post)` + `ensure_watch`). Caveat that shaped the design: `skill_render.snapshot`/`apply_snapshot` are **line-granular**, so the highlight must be whole-line `DiffChange` to round-trip; a column-precise span would not survive undo/redo. In headless tests, `:undo` does NOT fire `TextChanged` — `nvim_exec_autocmds("TextChanged", {buffer=buf})` to drive the projection watcher deterministically.

codex
The session-level skill path listed in the environment is stale, so I’m falling back to the repo-local adapted skill path for the required startup guidance. The SDLC contract and lessons are loaded; next I’m checking the issue spec/plan and the actual changed files at `HEAD`.
exec
/bin/zsh -lc "sed -n '1,260p' workshop/issues/000164-issue-tracker-archive-mode-sorts-by-modified-time.md" in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc "sed -n '1,220p' /Users/xianxu/workspace/ariadne/construct/adapted/superpowers-using-superpowers/SKILL.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
---
id: 000164
status: working
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 0.56
started: 2026-07-08T08:04:06-07:00
---

# issue tracker archive mode sorts by modified time

## Problem

The issue finder history/archive view is sorted with the same issue-number/status
ordering used for active issues. In the bottom-anchored picker, that puts recent
archive activity away from the prompt instead of closest to the text input.

## Spec

- Keep the normal `issues` view sorted exactly as it is today: active/open issue
  rows use the existing issue/status/ID ordering.
- Sort the `history` view by archive file modification time ascending, so the
  newest archived file is last in the item list and appears closest to the input
  in the bottom-anchored picker.
- Use deterministic tie-breakers for equal mtimes.

## Done when

- `:ParleyIssueFinder` history mode shows archived issues oldest-to-newest by
  file modification time.
- The default/open issues view remains sorted by issue number/status behavior.
- Focused unit tests cover both view-specific sort paths.

## Plan

- [x] Add scanned issue `mtime` data in `lua/parley/issues.lua` without changing
  the existing `scan_issues` default ID ordering.
- [x] Add `issue_finder.sort_for_view(view_mode, issues)` in
  `lua/parley/issue_finder.lua`: view `0` delegates to `issues.topo_sort`, view
  `1` sorts by `mtime` ascending with ID fallback (`ARCH-DRY`, `ARCH-PURE`).
- [x] Replace the inline `issues_mod.topo_sort(filter_for_view(...))` call in
  `issue_finder.open` with `sort_for_view`.
- [x] Extend `tests/unit/issue_finder_spec.lua` with failing tests proving
  issues view preserves ID/status ordering and history view orders by mtime
  oldest-to-newest (`ARCH-PURPOSE`).
- [x] Update `atlas/issues/issue-management.md` to document the history ordering.

## Estimate

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.15 impl=0.25
item: atlas-docs design=0.05 impl=0.05
design-buffer: 0.30
total: 0.56
```

## Log

### 2026-07-08

- Planning: keep active issue ordering on the existing `issues.topo_sort`
  pathway (`ARCH-DRY`), isolate the view-specific ordering in a pure helper
  (`ARCH-PURE`), and explicitly test the archive bottom-proximity requirement
  (`ARCH-PURPOSE`).
- `sdlc change-code` passed plan-quality CLEAN and estimate-quality INFO, then
  created branch `000164-issue-tracker-archive-mode-sorts-by-modified-time`.
- TDD red: `tests/unit/issue_finder_spec.lua` failed on missing
  `issue_finder.sort_for_view`; green after adding view-specific sorting.
- TDD red: `tests/unit/issues_spec.lua` failed because scanned archived rows had
  nil `mtime`; green after `scan_issues` exposed filesystem mtime on issue rows.
- Verification: scoped `git diff --check` passed for #164 files;
  `make test-spec SPEC=issues/issue-management` passed; full `make test` passed
  with lint at 0 warnings / 0 errors and all unit/integration specs green.

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
/bin/zsh -lc 'git diff --stat 7cdeb5ae4644f6ef7296ea448fb64fb54eb5ae4c..HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
 atlas/issues/issue-management.md                   |  2 +-
 lua/parley/issue_finder.lua                        | 22 +++++++-
 lua/parley/issues.lua                              |  2 +
 tests/unit/issue_finder_spec.lua                   | 32 ++++++++++++
 tests/unit/issues_spec.lua                         | 61 ++++++++++++++++++++++
 ...-tracker-archive-mode-sorts-by-modified-time.md | 58 ++++++++++++++++++--
 6 files changed, 172 insertions(+), 5 deletions(-)

exec
/bin/zsh -lc 'git diff --name-only 7cdeb5ae4644f6ef7296ea448fb64fb54eb5ae4c..HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
atlas/issues/issue-management.md
lua/parley/issue_finder.lua
lua/parley/issues.lua
tests/unit/issue_finder_spec.lua
tests/unit/issues_spec.lua
workshop/issues/000164-issue-tracker-archive-mode-sorts-by-modified-time.md

codex
The issue is narrow and has no separate durable plan, so the issue file’s Spec/Plan is the contract. I’m now checking the concrete implementation paths and tests for line-level findings, especially the mtime cache path and view sort helper.
exec
/bin/zsh -lc "nl -ba lua/parley/issue_finder.lua | sed -n '1,260p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
     1	-- Issue finder module for Parley
     2	-- Float picker UI for browsing, filtering, and managing issues
     3	
     4	local issues_mod = require("parley.issues")
     5	local finder_sticky = require("parley.finder_sticky")
     6	
     7	local M = {}
     8	local _parley
     9	
    10	M.setup = function(parley)
    11	    _parley = parley
    12	end
    13	
    14	--------------------------------------------------------------------------------
    15	-- View-mode logic (pure)
    16	--
    17	-- The IssueFinder cycles a TWO-state `view_mode` via (view_mode + 1) % 2, on
    18	-- both `<Tab>` (cycle_view — the natural key) and `<C-a>` (toggle_done, kept
    19	-- for back-compat). View 0 = `issues` (everything in `workshop/issues/`);
    20	-- view 1 = `history` (the archived items in `workshop/history/`). #158
    21	-- (superseding the tri-state all/active/all+history from #152).
    22	--------------------------------------------------------------------------------
    23	
    24	M.VIEW_LABELS = { [0] = "issues", [1] = "history" }
    25	
    26	-- Does this view mode scan archived files from the history dir? Only `history`.
    27	M.includes_history = function(view_mode)
    28	    return view_mode == 1
    29	end
    30	
    31	-- Which scanned issues survive the given view_mode, partitioned by the
    32	-- `archived` flag: view 0 (`issues`) keeps non-archived items, view 1
    33	-- (`history`) keeps archived items. A nil `archived` counts as non-archived.
    34	-- Returns a fresh list (no mutation).
    35	M.filter_for_view = function(view_mode, all_issues)
    36	    local want_archived = view_mode == 1
    37	    local filtered = {}
    38	    for _, issue in ipairs(all_issues) do
    39	        if (issue.archived == true) == want_archived then
    40	            table.insert(filtered, issue)
    41	        end
    42	    end
    43	    return filtered
    44	end
    45	
    46	M.sort_for_view = function(view_mode, issues)
    47	    if view_mode ~= 1 then
    48	        return issues_mod.topo_sort(issues)
    49	    end
    50	
    51	    local sorted = {}
    52	    for _, issue in ipairs(issues) do
    53	        table.insert(sorted, issue)
    54	    end
    55	    table.sort(sorted, function(a, b)
    56	        local ma = a.mtime or 0
    57	        local mb = b.mtime or 0
    58	        if ma ~= mb then
    59	            return ma < mb
    60	        end
    61	        return a.id < b.id
    62	    end)
    63	    return sorted
    64	end
    65	
    66	--------------------------------------------------------------------------------
    67	-- Reopen helper
    68	--------------------------------------------------------------------------------
    69	
    70	M.reopen = function(source_win, selection_index, selection_value)
    71	    vim.defer_fn(function()
    72	        _parley._issue_finder.opened = false
    73	        _parley._issue_finder.source_win = source_win
    74	        _parley._issue_finder.initial_index = selection_index
    75	        _parley._issue_finder.initial_value = selection_value
    76	        _parley.cmd.IssueFinder()
    77	    end, 100)
    78	end
    79	
    80	--------------------------------------------------------------------------------
    81	-- Delete confirmation
    82	--------------------------------------------------------------------------------
    83	
    84	M.handle_delete_response = function(input, item_value, selected_index, items_count, source_win, close_fn, context)
    85	    if input and input:lower() == "y" then
    86	        _parley.helpers.delete_file(item_value)
    87	        issues_mod.invalidate_path(item_value)
    88	        if close_fn then
    89	            close_fn()
    90	        end
    91	        local next_index = math.min(selected_index, math.max(1, items_count - 1))
    92	        local next_value = nil
    93	        local items = context and context.issue_finder_items or nil
    94	        if type(items) == "table" then
    95	            local next_item = items[selected_index + 1] or items[selected_index - 1]
    96	            next_value = next_item and next_item.value or nil
    97	        end
    98	        M.reopen(source_win, next_index, next_value)
    99	        return
   100	    end
   101	
   102	    if context then
   103	        context.resume_after_external_ui()
   104	        vim.schedule(function()
   105	            if context.focus_prompt then
   106	                context.focus_prompt()
   107	            end
   108	        end)
   109	        vim.defer_fn(function()
   110	            if context.focus_prompt then
   111	                context.focus_prompt()
   112	            end
   113	        end, 10)
   114	        return
   115	    end
   116	
   117	    M.reopen(source_win, selected_index, item_value)
   118	end
   119	
   120	M.prompt_delete_confirmation = function(item_value, selected_index, items_count, source_win, close_fn, context)
   121	    if source_win and vim.api.nvim_win_is_valid(source_win) then
   122	        vim.api.nvim_set_current_win(source_win)
   123	    end
   124	
   125	    vim.ui.input({ prompt = "Delete " .. item_value .. "? [y/N] " }, function(input)
   126	        M.handle_delete_response(
   127	            input,
   128	            item_value,
   129	            selected_index,
   130	            items_count,
   131	            source_win,
   132	            close_fn,
   133	            context
   134	        )
   135	    end)
   136	end
   137	
   138	--------------------------------------------------------------------------------
   139	-- Main IssueFinder open function
   140	--------------------------------------------------------------------------------
   141	
   142	M.open = function(_options)
   143	    if _parley._issue_finder.opened then
   144	        _parley.logger.warning("Issue finder is already open")
   145	        return
   146	    end
   147	    _parley._issue_finder.opened = true
   148	
   149	    local issue_finder_mappings = _parley.config.issue_finder_mappings or {}
   150	    local delete_shortcut = issue_finder_mappings.delete or { shortcut = "<C-d>" }
   151	    local cycle_status_shortcut = issue_finder_mappings.cycle_status or { shortcut = "<C-s>" }
   152	    local toggle_done_shortcut = issue_finder_mappings.toggle_done or { shortcut = "<C-a>" }
   153	    local cycle_view_shortcut = issue_finder_mappings.cycle_view or { shortcut = "<Tab>" }
   154	
   155	    -- Compute issue roots: in super-repo mode, one per member; otherwise just the single repo.
   156	    local sr_issues = _parley.super_repo and _parley.super_repo.expand_roots(_parley.config.issues_dir) or nil
   157	    local sr_history = _parley.super_repo and _parley.super_repo.expand_roots(_parley.config.history_dir) or nil
   158	    local roots
   159	    if sr_issues then
   160	        roots = {}
   161	        for i, r in ipairs(sr_issues) do
   162	            table.insert(roots, {
   163	                issues_dir = r.dir,
   164	                history_dir = sr_history and sr_history[i] and sr_history[i].dir or nil,
   165	                repo_name = r.repo_name,
   166	            })
   167	        end
   168	    else
   169	        roots = { {
   170	            issues_dir = issues_mod.get_issues_dir(),
   171	            history_dir = issues_mod.get_history_dir(),
   172	            repo_name = nil,
   173	        } }
   174	    end
   175	    if #roots == 0 or not roots[1].issues_dir then
   176	        _parley.logger.warning("issues_dir is not configured")
   177	        _parley._issue_finder.opened = false
   178	        return
   179	    end
   180	
   181	    -- View mode: 0=issues (default), 1=history. Clamp with % 2 so any stale
   182	    -- in-memory value (e.g. a `2` left by the pre-#158 tri-state) self-heals.
   183	    local view_mode = (_parley._issue_finder.view_mode or 0) % 2
   184	    local include_history = M.includes_history(view_mode)
   185	    local all_issues = {}
   186	    for _, root in ipairs(roots) do
   187	        if root.issues_dir then
   188	            local got = issues_mod.scan_issues(root.issues_dir, {
   189	                include_history = include_history,
   190	                history_dir_override = root.history_dir,
   191	                repo_name = root.repo_name,
   192	            })
   193	            vim.list_extend(all_issues, got)
   194	        end
   195	    end
   196	
   197	    local sorted = M.sort_for_view(view_mode, M.filter_for_view(view_mode, all_issues))
   198	
   199	    -- Build picker items
   200	    local items = {}
   201	    for _, issue in ipairs(sorted) do
   202	        local prefix = issue.archived and "[archived]" or string.format("[%s]", issue.status)
   203	        local label = issue.title ~= "" and issue.title or issue.slug
   204	        local repo_prefix = issue.repo_name and ("{" .. issue.repo_name .. "} ") or ""
   205	        local display = string.format("%s%s %s %s", repo_prefix, prefix, issue.id, label)
   206	        if issue.github_issue then
   207	            display = display .. " (#" .. issue.github_issue .. ")"
   208	        end
   209	        if issue.created ~= "" then
   210	            display = display .. " [" .. issue.created .. "]"
   211	        end
   212	        table.insert(items, {
   213	            display = display,
   214	            search_text = string.format("%s%s %s %s %s", repo_prefix, issue.status, issue.id, issue.title, issue.slug),
   215	            value = issue.path,
   216	            issue = issue,
   217	        })
   218	    end
   219	
   220	    local source_win = _parley._issue_finder.source_win
   221	    if not (source_win and vim.api.nvim_win_is_valid(source_win)) then
   222	        source_win = vim.api.nvim_get_current_win()
   223	        _parley._issue_finder.source_win = source_win
   224	    end
   225	
   226	    -- Cycle the 2-state view (issues ↔ history) and reopen. Shared by both the
   227	    -- `<Tab>` (cycle_view) and `<C-a>` (toggle_done) mappings — one handler,
   228	    -- two keys (#158, ARCH-DRY).
   229	    local function cycle_view_fn(_, close_fn)
   230	        _parley._issue_finder.view_mode = (view_mode + 1) % 2
   231	        close_fn()
   232	        vim.defer_fn(function()
   233	            _parley._issue_finder.opened = false
   234	            _parley._issue_finder.source_win = source_win
   235	            _parley.cmd.IssueFinder()
   236	        end, 100)
   237	    end
   238	
   239	    local chat_finder_mod = require("parley.chat_finder")
   240	
   241	    local prompt_title = string.format(
   242	        "Issues (%s  %s: cycle view)",
   243	        M.VIEW_LABELS[view_mode] or M.VIEW_LABELS[0],
   244	        cycle_view_shortcut.shortcut
   245	    )
   246	
   247	    _parley.float_picker.open({
   248	        title = prompt_title,
   249	        items = items,
   250	        recall_key = "parley.issue_finder",
   251	        initial_index = chat_finder_mod.resolve_finder_initial_index(_parley._issue_finder, items, "IssueFinder"),
   252	        initial_query = finder_sticky.format_initial_query(_parley._issue_finder.sticky_query),
   253	        anchor = "bottom",
   254	        on_query_change = function(query)
   255	            _parley._issue_finder.sticky_query = finder_sticky.extract(query, { "root" })
   256	        end,
   257	        on_select = function(item)
   258	            if source_win and vim.api.nvim_win_is_valid(source_win) then
   259	                vim.api.nvim_set_current_win(source_win)
   260	            end

exec
/bin/zsh -lc "nl -ba lua/parley/issues.lua | sed -n '520,610p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   520	    return max_id
   521	end
   522	
   523	-- Find the next issue ID by scanning both issues/ and history/ directories
   524	M.next_issue_id = function(issues_dir)
   525	    local max_id = scan_max_id(issues_dir)
   526	    -- Also check history/ to avoid ID collisions with archived issues
   527	    local history_dir = M.get_history_dir()
   528	    if history_dir then
   529	        local history_max = scan_max_id(history_dir)
   530	        if history_max > max_id then
   531	            max_id = history_max
   532	        end
   533	    end
   534	    return string.format("%06d", max_id + 1)
   535	end
   536	
   537	-- Scan a single directory for issue files, appending to the issues table.
   538	-- Uses _file_cache to skip re-reading unchanged files.
   539	local function scan_dir_issues(dir, issues, is_archived)
   540	    local handle = vim.loop.fs_scandir(dir)
   541	    if not handle then
   542	        return
   543	    end
   544	
   545	    local name, kind
   546	    repeat
   547	        name, kind = vim.loop.fs_scandir_next(handle)
   548	        if name and (kind == "file") and name:match("%.md$") then
   549	            local id_str = name:match("^(%d+)%-")
   550	            if id_str then
   551	                local path = dir .. "/" .. name
   552	                local stat = vim.loop.fs_stat(path)
   553	                if not stat then
   554	                    goto continue
   555	                end
   556	
   557	                local cached = _file_cache[path]
   558	                if cached and cached.mtime == stat.mtime.sec then
   559	                    -- Use cached data, just update archived flag
   560	                    local issue = vim.deepcopy(cached.issue_data)
   561	                    issue.mtime = stat.mtime.sec
   562	                    issue.archived = is_archived or false
   563	                    table.insert(issues, issue)
   564	                else
   565	                    local lines = vim.fn.readfile(path)
   566	                    local fm = M.parse_frontmatter(lines)
   567	                    local slug = name:match("^%d+%-(.+)%.md$") or ""
   568	                    local title = M.extract_title(lines, fm and fm.header_end or 0)
   569	                    local issue_data = {
   570	                        id = id_str,
   571	                        slug = slug,
   572	                        title = title,
   573	                        status = fm and fm.status or "open",
   574	                        deps = fm and fm.deps or {},
   575	                        created = fm and fm.created or "",
   576	                        updated = fm and fm.updated or "",
   577	                        github_issue = fm and fm.github_issue or nil,
   578	                        path = path,
   579	                        mtime = stat.mtime.sec,
   580	                    }
   581	                    _file_cache[path] = { mtime = stat.mtime.sec, issue_data = issue_data }
   582	                    local issue = vim.deepcopy(issue_data)
   583	                    issue.archived = is_archived or false
   584	                    table.insert(issues, issue)
   585	                end
   586	            end
   587	        end
   588	        ::continue::
   589	    until not name
   590	end
   591	
   592	-- Scan all issue files and return parsed list
   593	-- opts.include_history: if true, also scan history/ for archived issues
   594	-- opts.history_dir_override: explicit history dir (super-repo per-member); else M.get_history_dir()
   595	-- opts.repo_name: if set, every returned issue is tagged with .repo_name (super-repo display)
   596	M.scan_issues = function(issues_dir, opts)
   597	    if not issues_dir then
   598	        return {}
   599	    end
   600	
   601	    opts = opts or {}
   602	    local issues = {}
   603	    scan_dir_issues(issues_dir, issues, false)
   604	
   605	    if opts.include_history then
   606	        local history_dir = opts.history_dir_override or M.get_history_dir()
   607	        if history_dir then
   608	            scan_dir_issues(history_dir, issues, true)
   609	        end
   610	    end

exec
/bin/zsh -lc "nl -ba tests/unit/issue_finder_spec.lua | sed -n '1,140p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
     1	-- Unit tests for IssueFinder pure view-mode logic (#158, was #152).
     2	--
     3	-- IssueFinder is a float-picker UI feature; these specs cover the pure pieces
     4	-- extracted from `M.open` so the view-mode behaviour is verifiable headlessly:
     5	--   * includes_history  — which mode scans archived history
     6	--   * filter_for_view   — which scanned issues survive each mode
     7	--   * VIEW_LABELS       — the cycle labels / order
     8	-- The cycle is 2-state (`issues → history`, `% 2`), partitioned by the
     9	-- `archived` flag: view 0 shows workshop/issues/, view 1 shows the archive.
    10	
    11	local parley = require("parley")
    12	parley.setup({
    13	    chat_dir = vim.fn.tempname() .. "-issue-finder-spec",
    14	    providers = {},
    15	    api_keys = {},
    16	})
    17	
    18	local issue_finder = require("parley.issue_finder")
    19	
    20	describe("IssueFinder view-mode logic", function()
    21	    local function sample_issues()
    22	        return {
    23	            { id = "1", status = "open", archived = false },
    24	            { id = "2", status = "working", archived = false },
    25	            { id = "3", status = "done", archived = false },
    26	            { id = "4", status = "wontfix", archived = false },
    27	            { id = "5", status = "done", archived = true }, -- archived history file
    28	            { id = "6", status = "open" }, -- no archived flag → counts as non-archived
    29	        }
    30	    end
    31	
    32	    local function ids(list)
    33	        local out = {}
    34	        for _, issue in ipairs(list) do
    35	            table.insert(out, issue.id)
    36	        end
    37	        return out
    38	    end
    39	
    40	    describe("includes_history", function()
    41	        it("only view 1 (history) scans archived history", function()
    42	            assert.is_false(issue_finder.includes_history(0))
    43	            assert.is_true(issue_finder.includes_history(1))
    44	        end)
    45	    end)
    46	
    47	    describe("filter_for_view", function()
    48	        it("view 0 (issues) keeps non-archived items (incl. done-not-archived)", function()
    49	            local got = ids(issue_finder.filter_for_view(0, sample_issues()))
    50	            assert.same({ "1", "2", "3", "4", "6" }, got)
    51	        end)
    52	
    53	        it("view 1 (history) keeps only archived items", function()
    54	            local got = ids(issue_finder.filter_for_view(1, sample_issues()))
    55	            assert.same({ "5" }, got)
    56	        end)
    57	
    58	        it("treats a nil archived flag as non-archived (shows in issues, not history)", function()
    59	            local only_nil = { { id = "x", status = "open" } }
    60	            assert.same({ "x" }, ids(issue_finder.filter_for_view(0, only_nil)))
    61	            assert.same({}, ids(issue_finder.filter_for_view(1, only_nil)))
    62	        end)
    63	
    64	        it("does not mutate the input list", function()
    65	            local input = sample_issues()
    66	            issue_finder.filter_for_view(1, input)
    67	            assert.equals(6, #input)
    68	        end)
    69	    end)
    70	
    71	    describe("sort_for_view", function()
    72	        it("keeps issues view on status/ID ordering", function()
    73	            local sorted = issue_finder.sort_for_view(0, {
    74	                { id = "0003", status = "done", mtime = 300 },
    75	                { id = "0002", status = "blocked", mtime = 200 },
    76	                { id = "0001", status = "open", mtime = 100 },
    77	            })
    78	
    79	            assert.same({ "0001", "0002", "0003" }, ids(sorted))
    80	        end)
    81	
    82	        it("sorts history view by mtime ascending so newest is last", function()
    83	            local sorted = issue_finder.sort_for_view(1, {
    84	                { id = "0003", status = "done", mtime = 300 },
    85	                { id = "0001", status = "done", mtime = 100 },
    86	                { id = "0002", status = "done", mtime = 200 },
    87	            })
    88	
    89	            assert.same({ "0001", "0002", "0003" }, ids(sorted))
    90	        end)
    91	
    92	        it("uses ID as the deterministic history tie-breaker", function()
    93	            local sorted = issue_finder.sort_for_view(1, {
    94	                { id = "0003", status = "done", mtime = 100 },
    95	                { id = "0001", status = "done", mtime = 100 },
    96	                { id = "0002", status = "done", mtime = 100 },
    97	            })
    98	
    99	            assert.same({ "0001", "0002", "0003" }, ids(sorted))
   100	        end)
   101	    end)
   102	
   103	    describe("VIEW_LABELS", function()
   104	        it("labels the 2-state cycle issues → history", function()
   105	            assert.equals("issues", issue_finder.VIEW_LABELS[0])
   106	            assert.equals("history", issue_finder.VIEW_LABELS[1])
   107	            assert.is_nil(issue_finder.VIEW_LABELS[2])
   108	        end)
   109	    end)
   110	end)

exec
/bin/zsh -lc "nl -ba tests/unit/issues_spec.lua | sed -n '560,690p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   560	describe("topo_sort", function()
   561	    it("sorts open before blocked before done", function()
   562	        local sorted = issues.topo_sort({
   563	            { id = "0001", status = "done", deps = {} },
   564	            { id = "0002", status = "blocked", deps = {} },
   565	            { id = "0003", status = "open", deps = {} },
   566	        })
   567	        assert.equals("0003", sorted[1].id) -- open
   568	        assert.equals("0002", sorted[2].id) -- blocked
   569	        assert.equals("0001", sorted[3].id) -- done
   570	    end)
   571	
   572	    it("sorts modeled statuses in priority order", function()
   573	        local sorted = issues.topo_sort({
   574	            { id = "0001", status = "wontfix", deps = {} },
   575	            { id = "0002", status = "done", deps = {} },
   576	            { id = "0003", status = "blocked", deps = {} },
   577	            { id = "0004", status = "working", deps = {} },
   578	            { id = "0005", status = "open", deps = {} },
   579	        })
   580	        assert.equals("0005", sorted[1].id) -- open
   581	        assert.equals("0004", sorted[2].id) -- working
   582	        assert.equals("0003", sorted[3].id) -- blocked
   583	        assert.equals("0002", sorted[4].id) -- done
   584	        assert.equals("0001", sorted[5].id) -- wontfix
   585	    end)
   586	
   587	    it("sorts by ID within same status", function()
   588	        local sorted = issues.topo_sort({
   589	            { id = "0003", status = "open", deps = {} },
   590	            { id = "0001", status = "open", deps = {} },
   591	            { id = "0002", status = "open", deps = {} },
   592	        })
   593	        assert.equals("0001", sorted[1].id)
   594	        assert.equals("0002", sorted[2].id)
   595	        assert.equals("0003", sorted[3].id)
   596	    end)
   597	
   598	    it("handles empty list", function()
   599	        assert.same({}, issues.topo_sort({}))
   600	    end)
   601	end)
   602	
   603	--------------------------------------------------------------------------------
   604	-- scan_issues mtime
   605	--------------------------------------------------------------------------------
   606	
   607	describe("scan_issues mtime", function()
   608	    local base_dir
   609	    local issues_dir
   610	    local history_dir
   611	
   612	    local function write_issue(dir, id, title)
   613	        local path = string.format("%s/%s-%s.md", dir, id, issues.slugify(title))
   614	        vim.fn.writefile({
   615	            "---",
   616	            "id: " .. id,
   617	            "status: done",
   618	            "deps: []",
   619	            "created: 2026-07-08",
   620	            "updated: 2026-07-08",
   621	            "---",
   622	            "",
   623	            "# " .. title,
   624	        }, path)
   625	        return path
   626	    end
   627	
   628	    before_each(function()
   629	        base_dir = vim.fn.tempname() .. "-issue-scan-mtime"
   630	        issues_dir = base_dir .. "/issues"
   631	        history_dir = base_dir .. "/history"
   632	        vim.fn.mkdir(issues_dir, "p")
   633	        vim.fn.mkdir(history_dir, "p")
   634	        issues.clear_cache()
   635	    end)
   636	
   637	    after_each(function()
   638	        if base_dir then
   639	            vim.fn.delete(base_dir, "rf")
   640	        end
   641	        issues.clear_cache()
   642	    end)
   643	
   644	    it("includes filesystem mtime for archived history rows", function()
   645	        local old_path = write_issue(history_dir, "000001", "Old archived")
   646	        local new_path = write_issue(history_dir, "000002", "New archived")
   647	        vim.loop.fs_utime(old_path, 100, 100)
   648	        vim.loop.fs_utime(new_path, 200, 200)
   649	
   650	        local scanned = issues.scan_issues(issues_dir, {
   651	            include_history = true,
   652	            history_dir_override = history_dir,
   653	        })
   654	
   655	        local by_id = {}
   656	        for _, issue in ipairs(scanned) do
   657	            by_id[issue.id] = issue
   658	        end
   659	        assert.equals(100, by_id["000001"].mtime)
   660	        assert.equals(200, by_id["000002"].mtime)
   661	    end)
   662	end)
   663	
   664	--------------------------------------------------------------------------------
   665	-- format_deps
   666	--------------------------------------------------------------------------------
   667	
   668	describe("format_deps", function()
   669	    it("formats empty deps", function()
   670	        assert.equals("[]", issues.format_deps({}))
   671	    end)
   672	
   673	    it("formats single dep", function()
   674	        assert.equals("[0001]", issues.format_deps({ "0001" }))
   675	    end)
   676	
   677	    it("formats multiple deps", function()
   678	        assert.equals("[0001, 0003]", issues.format_deps({ "0001", "0003" }))
   679	    end)
   680	
   681	    it("handles nil", function()
   682	        assert.equals("[]", issues.format_deps(nil))
   683	    end)
   684	end)
   685	
   686	--------------------------------------------------------------------------------
   687	-- parse_md_link_at_cursor
   688	--------------------------------------------------------------------------------
   689	
   690	describe("parse_md_link_at_cursor", function()

codex
The core implementation is a pure view-specific sort plus scan-time metadata. I haven’t found a behavioral mismatch yet; I’m doing one pass over the underlying sort/cache helpers and then I’ll run the focused specs so the verdict is grounded in executable evidence.
exec
/bin/zsh -lc "rg -n \"function.*topo_sort|M\\.topo_sort|clear_cache|_file_cache|scan_issues\" lua/parley/issues.lua tests/unit/issues_spec.lua tests/unit/issue_finder_spec.lua" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
lua/parley/issues.lua:10:-- scan_issues, write_frontmatter, cmd_*
lua/parley/issues.lua:21:local _file_cache = {}
lua/parley/issues.lua:28:M.clear_cache = function()
lua/parley/issues.lua:29:    _file_cache = {}
lua/parley/issues.lua:33:    return _file_cache
lua/parley/issues.lua:37:    _file_cache[path] = nil
lua/parley/issues.lua:231:M.topo_sort = function(issues)
lua/parley/issues.lua:538:-- Uses _file_cache to skip re-reading unchanged files.
lua/parley/issues.lua:557:                local cached = _file_cache[path]
lua/parley/issues.lua:581:                    _file_cache[path] = { mtime = stat.mtime.sec, issue_data = issue_data }
lua/parley/issues.lua:596:M.scan_issues = function(issues_dir, opts)
lua/parley/issues.lua:810:    local issues = M.scan_issues(issues_dir)
lua/parley/issues.lua:927:    local issues = M.scan_issues(issues_dir, { include_history = true })
tests/unit/issues_spec.lua:604:-- scan_issues mtime
tests/unit/issues_spec.lua:607:describe("scan_issues mtime", function()
tests/unit/issues_spec.lua:634:        issues.clear_cache()
tests/unit/issues_spec.lua:641:        issues.clear_cache()
tests/unit/issues_spec.lua:650:        local scanned = issues.scan_issues(issues_dir, {

exec
/bin/zsh -lc "nl -ba lua/parley/issues.lua | sed -n '1,120p;420,520p;610,640p'" in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc "nl -ba atlas/issues/issue-management.md | sed -n '1,60p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
     1	# Issue Management
     2	
     3	Repo-local issue tracking with single-file-per-issue markdown format, designed for agentic coding workflows.
     4	
     5	## File Format
     6	Each issue is `{issues_dir}/NNNNNN-slug.md` with YAML frontmatter (`id`, `status`, `deps`, `github_issue`, `created`, `updated`) and markdown sections (title, done-when, plan checklist, log).
     7	
     8	IDs are sequential integers (e.g., `000066`, `000067`). Sub-ticket IDs must NOT use letter suffixes (e.g., `000065a` is wrong). Always allocate the next available integer ID.
     9	
    10	Status values, categories, and lifecycle transitions are loaded at runtime from
    11	`construct/generated/vocabulary/issue.json`, which is generated from ariadne's
    12	`construct/vocabulary/issue.cue`. Parley uses that model for status completion,
    13	picker active filtering, status sorting, and status cycling — and (M2 #116) for
    14	the issue **home**: `config.issues_dir` is seeded at setup from the cue
    15	`discovery.home` (precedence: explicit user override > cue home > built-in
    16	default), so every reader derives from the one cue source.
    17	
    18	## Commands
    19	- `:ParleyIssueNew` (`<C-y>c`): **delegates to `sdlc issue new`** (M3 #116) — the canonical creator (id allocation + the cue/sdlc-owned template + broadcast to origin/main per ariadne#82) — then opens the created file. The title prompt is prefixed with the destination repo — `[<repo>] Issue title: ` — where `<repo>` is the basename of the git root `issues_dir` resolves against (the editor's cwd root), so issues aren't created in the wrong repo (#142)
    20	- `:ParleyIssueFinder` (`<C-y>f`): float picker with status badges and 2-state view cycling — `<Tab>` (natural key; `<C-a>` kept for back-compat) toggles between `issues` (all of `workshop/issues/`, done items visible — the default, sorted by the existing status/ID order) and `history` (archived items in `workshop/history/`, sorted by file modification time ascending so the newest archive row sits closest to the bottom-anchored prompt) (#158, superseding the tri-state all/active/all+history from #152)
    21	- `:ParleyIssueNext` (`<C-y>x`): open next runnable issue (oldest open with all deps done)
    22	- `:ParleyIssueStatus` (`<C-y>s`): cycle frontmatter status using the first lifecycle transition for the current status in generated vocabulary order
    23	- `:ParleyIssueDecompose` (`<C-y>i`): create child issue from plan line, add to parent deps, and write a markdown link `[issue NNNNNN](./NNNNNN-slug.md)` into the parent's plan line; the new child file gets a `Parent: [issue PPPPPP](./PPPPPP-...md)` backlink under its title. (M3 #116: decompose **retains** parley's `render_issue_template` — its semantics, parent.deps += child + the parent plan-line link + the backlink, are incompatible with `sdlc issue new`'s shape, so unlike `:ParleyIssueNew` it is not delegated.)
    24	- `:ParleyIssueGoto` (`<C-y>g`): follow a markdown link `[...](./NNNNNN-*.md)` under the cursor to the linked issue; if there is no link under the cursor, jump to the current issue's parent (derived from `deps`). Use `<C-o>` to return.
    25	
    26	## Parent/Child Links
    27	- `deps` is the canonical machine-readable representation of parent→child (an issue's `deps` lists the IDs of its children).
    28	- Cross-issue references inserted by parley use **standard markdown links** (`[issue NNNNNN](./NNNNNN-slug.md)`, path relative to the file containing the link), so they render correctly in any markdown viewer and are followable by `:ParleyIssueGoto`.
    29	- Child→parent navigation is derived from `deps` at scan time, not from the body backlink, so issues decomposed before this feature was added still navigate correctly.
    30	
    31	## Archival
    32	Done issues moved to `workshop/history/` by `make push` or `make merge`. GitHub issues auto-closed. History is low-signal — agents should avoid reading it unless directed.
    33	
    34	## Makefile Integration
    35	- `make fetch N` / `make issue N`: create local issue from GitHub issue
    36	- `make push` / `make merge`: archive done issues, close GitHub issues
    37	- `make pull-request`: gathers issue references for PR body

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
   420	        local jid = vim.fn.jobstart(spawn, {
   421	            stdout_buffered = true,
   422	            stderr_buffered = true,
   423	            on_stdout = collect,
   424	            on_stderr = collect,
   425	            on_exit = function(_, code)
   426	                vim.schedule(function()
   427	                    on_complete(table.concat(out, "\n"), code)
   428	                end)
   429	            end,
   430	        })
   431	        if jid <= 0 then
   432	            vim.schedule(function()
   433	                on_complete("could not start sdlc (jobstart=" .. tostring(jid) .. ")", 127)
   434	            end)
   435	        end
   436	    end
   437	    runner(argv, function(output, code)
   438	        if code ~= 0 then
   439	            on_done(nil, "sdlc issue new failed (exit " .. tostring(code) .. "): " .. trim(output or ""))
   440	            return
   441	        end
   442	        local path = M.parse_issue_new_output(output)
   443	        if not path then
   444	            on_done(nil, "sdlc issue new succeeded but no created path in output: " .. trim(output or ""))
   445	            return
   446	        end
   447	        on_done(path, nil)
   448	    end)
   449	end
   450	
   451	--------------------------------------------------------------------------------
   452	-- IO functions (require vim/parley runtime)
   453	--------------------------------------------------------------------------------
   454	
   455	-- Resolve a repo-local dir (issues / history) against the git repo root:
   456	-- absolute as-is; relative → git_root .. "/" .. dir (cwd's git root, cwd fallback
   457	-- when not in a repo). ONE resolver so issues + history anchor identically
   458	-- (ARCH-DRY) and creation is cwd-independent (#116 M3 — see get_history_dir).
   459	local function resolve_against_git_root(dir)
   460	    if not dir or dir == "" then
   461	        return nil
   462	    end
   463	    if dir:sub(1, 1) == "/" then
   464	        return dir -- already absolute
   465	    end
   466	    local git_root = _parley.helpers.find_git_root(vim.fn.getcwd())
   467	    if git_root == "" then
   468	        git_root = vim.fn.getcwd() -- fallback if not in a git repo
   469	    end
   470	    return git_root .. "/" .. dir
   471	end
   472	
   473	-- Resolve issues_dir against the git repo root.
   474	M.get_issues_dir = function()
   475	    return resolve_against_git_root(_parley.config.issues_dir)
   476	end
   477	
   478	-- Resolve history_dir against the git repo root. #116 M3: forwarded to
   479	-- `sdlc issue new --history-dir` so its NextID scan covers the right archive and
   480	-- creation stays git-root-anchored regardless of nvim's cwd (#142 contract).
   481	M.get_history_dir = function()
   482	    return resolve_against_git_root(_parley.config.history_dir)
   483	end
   484	
   485	-- Resolve the git repo root issues are created in — the same root get_issues_dir
   486	-- resolves against — so the caller can label the destination (#142). Relative
   487	-- issues_dir → cwd's git root; absolute → the git root above the configured path.
   488	M.get_issues_repo_root = function()
   489	    local issues_dir = _parley.config.issues_dir
   490	    if not issues_dir or issues_dir == "" then
   491	        return nil
   492	    end
   493	    local base = (issues_dir:sub(1, 1) == "/") and issues_dir or vim.fn.getcwd()
   494	    local root = _parley.helpers.find_git_root(base)
   495	    if root == "" then
   496	        root = base
   497	    end
   498	    return root
   499	end
   500	
   501	-- Scan a directory for max issue ID (4-digit prefix pattern)
   502	local function scan_max_id(dir)
   503	    local max_id = 0
   504	    local handle = vim.loop.fs_scandir(dir)
   505	    if handle then
   506	        local name, kind
   507	        repeat
   508	            name, kind = vim.loop.fs_scandir_next(handle)
   509	            if name and (kind == "file") and name:match("%.md$") then
   510	                local id_str = name:match("^(%d+)%-")
   511	                if id_str then
   512	                    local id = tonumber(id_str)
   513	                    if id and id > max_id then
   514	                        max_id = id
   515	                    end
   516	                end
   517	            end
   518	        until not name
   519	    end
   520	    return max_id
   610	    end
   611	
   612	    if opts.repo_name then
   613	        for _, issue in ipairs(issues) do
   614	            issue.repo_name = opts.repo_name
   615	        end
   616	    end
   617	
   618	    -- Sort by ID ascending
   619	    table.sort(issues, function(a, b) return a.id < b.id end)
   620	    return issues
   621	end
   622	
   623	-- Issue template
   624	local ISSUE_TEMPLATE = [[---
   625	id: {{id}}
   626	status: {{status}}
   627	deps: []
   628	created: {{date}}
   629	updated: {{date}}
   630	---
   631	
   632	# {{title}}
   633	
   634	## Done when
   635	
   636	-
   637	
   638	## Spec
   639	
   640	

exec
/bin/zsh -lc 'git diff --check 7cdeb5ae4644f6ef7296ea448fb64fb54eb5ae4c..HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
codex
The implementation preserves `scan_issues`’ ID sort and leaves the new history order at the picker layer, which matches the issue’s stated split. I’m checking the existing topological/status sort contract now and then I’ll execute the relevant tests.
exec
/bin/zsh -lc "nl -ba lua/parley/issues.lua | sed -n '220,285p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   220	    -- Find the issue after current_id, cycling back to start
   221	    for _, issue in ipairs(runnable) do
   222	        if issue.id > current_id then
   223	            return issue
   224	        end
   225	    end
   226	    -- Cycle back to the first runnable
   227	    return runnable[1]
   228	end
   229	
   230	-- Sort issues for display by vocabulary category order (by ID within each group).
   231	M.topo_sort = function(issues)
   232	    local sorted = {}
   233	    for _, issue in ipairs(issues) do
   234	        table.insert(sorted, issue)
   235	    end
   236	    table.sort(sorted, function(a, b)
   237	        local pa = vocab():sort_rank(a.status)
   238	        local pb = vocab():sort_rank(b.status)
   239	        if pa ~= pb then
   240	            return pa < pb
   241	        end
   242	        return a.id < b.id
   243	    end)
   244	    return sorted
   245	end
   246	
   247	-- Find a markdown link [text](url) whose span contains the 1-indexed cursor column.
   248	-- Returns { text, url, start_col, end_col } or nil. Pure function (no vim deps).
   249	M.parse_md_link_at_cursor = function(line, col)
   250	    if not line or not col then
   251	        return nil
   252	    end
   253	    local init = 1
   254	    while true do
   255	        local s, e, text, url = line:find("%[([^%]]*)%]%(([^)]+)%)", init)
   256	        if not s then
   257	            return nil
   258	        end
   259	        if col >= s and col <= e then
   260	            return { text = text, url = url, start_col = s, end_col = e }
   261	        end
   262	        init = e + 1
   263	    end
   264	end
   265	
   266	-- Resolve a markdown link (as returned by parse_md_link_at_cursor) to an
   267	-- absolute path, given the directory of the file the link lives in. Returns
   268	-- the resolved path string, or nil if the link's url is not a .md file.
   269	-- Pure function (no vim deps); the caller is responsible for normalization
   270	-- (e.g. vim.fn.simplify) and existence checks (e.g. filereadable).
   271	M.resolve_link_target = function(link, cur_dir)
   272	    if not link or not link.url or not link.url:match("%.md$") then
   273	        return nil
   274	    end
   275	    local url = link.url
   276	    if url:sub(1, 1) == "/" then
   277	        return url
   278	    end
   279	    return (cur_dir or "") .. "/" .. url
   280	end
   281	
   282	-- Extract the path from a src: URL. Returns the path string after "src:/" or nil.
   283	-- Pure function (no vim deps).
   284	M.parse_src_url = function(url)
   285	    if not url then return nil end

exec
/bin/zsh -lc "rg -n \"make test-spec|PlenaryBustedFile|SPEC=\" Makefile TOOLING.md tests -g '"'!tests/helpers/minimal_init.lua'"'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
TOOLING.md:7:- Run tests for one spec: `make test-spec SPEC=chat/lifecycle` (uses `atlas/traceability.yaml` mapping)

exec
/bin/zsh -lc 'git diff 7cdeb5ae4644f6ef7296ea448fb64fb54eb5ae4c..HEAD -- workshop/issues/000164-issue-tracker-archive-mode-sorts-by-modified-time.md' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
diff --git a/workshop/issues/000164-issue-tracker-archive-mode-sorts-by-modified-time.md b/workshop/issues/000164-issue-tracker-archive-mode-sorts-by-modified-time.md
index c79f02d..cee1529 100644
--- a/workshop/issues/000164-issue-tracker-archive-mode-sorts-by-modified-time.md
+++ b/workshop/issues/000164-issue-tracker-archive-mode-sorts-by-modified-time.md
@@ -5,7 +5,7 @@ deps: []
 github_issue:
 created: 2026-07-08
 updated: 2026-07-08
-estimate_hours:
+estimate_hours: 0.56
 started: 2026-07-08T08:04:06-07:00
 ---
 
@@ -13,16 +13,68 @@ started: 2026-07-08T08:04:06-07:00
 
 ## Problem
 
+The issue finder history/archive view is sorted with the same issue-number/status
+ordering used for active issues. In the bottom-anchored picker, that puts recent
+archive activity away from the prompt instead of closest to the text input.
+
 ## Spec
 
+- Keep the normal `issues` view sorted exactly as it is today: active/open issue
+  rows use the existing issue/status/ID ordering.
+- Sort the `history` view by archive file modification time ascending, so the
+  newest archived file is last in the item list and appears closest to the input
+  in the bottom-anchored picker.
+- Use deterministic tie-breakers for equal mtimes.
+
 ## Done when
 
--
+- `:ParleyIssueFinder` history mode shows archived issues oldest-to-newest by
+  file modification time.
+- The default/open issues view remains sorted by issue number/status behavior.
+- Focused unit tests cover both view-specific sort paths.
 
 ## Plan
 
-- [ ]
+- [x] Add scanned issue `mtime` data in `lua/parley/issues.lua` without changing
+  the existing `scan_issues` default ID ordering.
+- [x] Add `issue_finder.sort_for_view(view_mode, issues)` in
+  `lua/parley/issue_finder.lua`: view `0` delegates to `issues.topo_sort`, view
+  `1` sorts by `mtime` ascending with ID fallback (`ARCH-DRY`, `ARCH-PURE`).
+- [x] Replace the inline `issues_mod.topo_sort(filter_for_view(...))` call in
+  `issue_finder.open` with `sort_for_view`.
+- [x] Extend `tests/unit/issue_finder_spec.lua` with failing tests proving
+  issues view preserves ID/status ordering and history view orders by mtime
+  oldest-to-newest (`ARCH-PURPOSE`).
+- [x] Update `atlas/issues/issue-management.md` to document the history ordering.
+
+## Estimate
+
+Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
+`baseline-v3.1.md`. Method A only.
+
+```estimate
+model: estimate-logic-v3.1
+familiarity: 1.0
+item: lua-neovim design=0.15 impl=0.25
+item: atlas-docs design=0.05 impl=0.05
+design-buffer: 0.30
+total: 0.56
+```
 
 ## Log
 
 ### 2026-07-08
+
+- Planning: keep active issue ordering on the existing `issues.topo_sort`
+  pathway (`ARCH-DRY`), isolate the view-specific ordering in a pure helper
+  (`ARCH-PURE`), and explicitly test the archive bottom-proximity requirement
+  (`ARCH-PURPOSE`).
+- `sdlc change-code` passed plan-quality CLEAN and estimate-quality INFO, then
+  created branch `000164-issue-tracker-archive-mode-sorts-by-modified-time`.
+- TDD red: `tests/unit/issue_finder_spec.lua` failed on missing
+  `issue_finder.sort_for_view`; green after adding view-specific sorting.
+- TDD red: `tests/unit/issues_spec.lua` failed because scanned archived rows had
+  nil `mtime`; green after `scan_issues` exposed filesystem mtime on issue rows.
+- Verification: scoped `git diff --check` passed for #164 files;
+  `make test-spec SPEC=issues/issue-management` passed; full `make test` passed
+  with lint at 0 warnings / 0 errors and all unit/integration specs green.

codex
The Plan checklist matches the files changed so far, including the atlas update. I’m running the mapped focused spec now; if that passes cleanly, this looks like a SHIP unless test execution exposes something unexpected.
exec
/bin/zsh -lc 'make test-spec SPEC=issues/issue-management' in /Users/xianxu/workspace/parley.nvim
 succeeded in 664ms:
[32mSuccess[0m	||	IssueFinder view-mode logic includes_history only view 1 (history) scans archived history	
[32mSuccess[0m	||	IssueFinder view-mode logic filter_for_view view 0 (issues) keeps non-archived items (incl. done-not-archived)	
[32mSuccess[0m	||	IssueFinder view-mode logic filter_for_view view 1 (history) keeps only archived items	
[32mSuccess[0m	||	IssueFinder view-mode logic filter_for_view treats a nil archived flag as non-archived (shows in issues, not history)	
[32mSuccess[0m	||	IssueFinder view-mode logic filter_for_view does not mutate the input list	
[32mSuccess[0m	||	IssueFinder view-mode logic sort_for_view keeps issues view on status/ID ordering	
[32mSuccess[0m	||	IssueFinder view-mode logic sort_for_view sorts history view by mtime ascending so newest is last	
[32mSuccess[0m	||	IssueFinder view-mode logic sort_for_view uses ID as the deterministic history tie-breaker	
[32mSuccess[0m	||	IssueFinder view-mode logic VIEW_LABELS labels the 2-state cycle issues → history	
	
[32mSuccess: [0m	9	
[31mFailed : [0m	0	
[31mErrors : [0m	0	
========================================	
Running tests/unit/issue_vocabulary_spec.lua
Scheduling: tests/unit/issue_vocabulary_spec.lua

========================================	
Testing: 	/Users/xianxu/workspace/parley.nvim/tests/unit/issue_vocabulary_spec.lua	
[32mSuccess[0m	||	issue_vocabulary derives status values from categories	
[32mSuccess[0m	||	issue_vocabulary cycles by first lifecycle transition in generated order	
[32mSuccess[0m	||	issue_vocabulary sorts statuses by category order	
[32mSuccess[0m	||	issue_vocabulary exposes status as an enumerable frontmatter field	
[32mSuccess[0m	||	issue_vocabulary loads the generated issue vocabulary from the repo	
[32mSuccess[0m	||	issue_vocabulary keeps parley issue helpers covering every generated status	
[32mSuccess[0m	||	issue_vocabulary home() returns the exact relative discovery.home from the cue model	
[32mSuccess[0m	||	issue_vocabulary home() returns nil when discovery is absent	
[32mSuccess[0m	||	issue_vocabulary home() returns nil for an empty discovery.home	
[32mSuccess[0m	||	issue_vocabulary home() returns nil (not raise) when the generated vocab can't load	
	
[32mSuccess: [0m	10	
[31mFailed : [0m	0	
[31mErrors : [0m	0	
========================================	
Running tests/unit/issues_spec.lua
Scheduling: tests/unit/issues_spec.lua

========================================	
Testing: 	/Users/xianxu/workspace/parley.nvim/tests/unit/issues_spec.lua	
[32mSuccess[0m	||	resolve_issues_dir uses the explicit user override when present (wins over cue)	
[32mSuccess[0m	||	resolve_issues_dir uses the cue home when the user did not override	
[32mSuccess[0m	||	resolve_issues_dir falls back to the built-in default when neither override nor cue	
[32mSuccess[0m	||	parse_issue_new_output returns the bare created path (sdlc writes it to stdout, last line)	
[32mSuccess[0m	||	parse_issue_new_output extracts the bare path from merged stdout+stderr (Created line + sync warning)	
[32mSuccess[0m	||	parse_issue_new_output extracts an absolute path under a directory containing spaces (#116 M3 I1 consequence)	
[32mSuccess[0m	||	parse_issue_new_output returns nil when only the spaced 'Created <path>' line is present	
[32mSuccess[0m	||	parse_issue_new_output returns nil for empty or pathless output	
[32mSuccess[0m	||	run_sdlc_issue_new calls back with the created path on success; argv = sdlc issue new <title>	
[32mSuccess[0m	||	run_sdlc_issue_new forwards absolute --issues-dir/--history-dir (git-root-anchored, #116 M3 I1)	
[32mSuccess[0m	||	run_sdlc_issue_new appends -- so a title starting with '-' is positional, not a flag	
[32mSuccess[0m	||	run_sdlc_issue_new calls back with an error on a non-zero exit	
[32mSuccess[0m	||	run_sdlc_issue_new errors when sdlc succeeds but prints no parseable path	
[32mSuccess[0m	||	run_sdlc_issue_new passes --deps (comma-joined) when opts.deps is set	
[32mSuccess[0m	||	build_spawn_argv (#116 M3 — sdlc as PATH binary vs shell function) spawns the argv directly when sdlc is a resolvable executable	
[32mSuccess[0m	||	build_spawn_argv (#116 M3 — sdlc as PATH binary vs shell function) wraps in an interactive shell when sdlc is a function/alias (the live E475 fix)	
[32mSuccess[0m	||	slugify converts title to lowercase slug	
[32mSuccess[0m	||	slugify handles special characters	
[32mSuccess[0m	||	slugify collapses multiple dashes	
[32mSuccess[0m	||	slugify strips leading/trailing dashes	
[32mSuccess[0m	||	slugify handles empty string	
[32mSuccess[0m	||	parse_deps_value parses empty brackets	
[32mSuccess[0m	||	parse_deps_value parses single dep	
[32mSuccess[0m	||	parse_deps_value parses multiple deps	
[32mSuccess[0m	||	parse_deps_value parses without brackets	
[32mSuccess[0m	||	parse_deps_value handles nil	
[32mSuccess[0m	||	parse_deps_value handles empty string	
[32mSuccess[0m	||	parse_deps_value trims whitespace	
[32mSuccess[0m	||	parse_frontmatter returns nil for empty lines	
[32mSuccess[0m	||	parse_frontmatter returns nil for no frontmatter	
[32mSuccess[0m	||	parse_frontmatter parses minimal frontmatter	
[32mSuccess[0m	||	parse_frontmatter parses full frontmatter	
[32mSuccess[0m	||	parse_frontmatter parses id without quotes	
[32mSuccess[0m	||	parse_frontmatter id is nil when absent	
[32mSuccess[0m	||	parse_frontmatter defaults status to open when missing	
[32mSuccess[0m	||	parse_frontmatter handles empty deps	
[32mSuccess[0m	||	parse_frontmatter parses github_issue field	
[32mSuccess[0m	||	parse_frontmatter github_issue is nil when absent	
[32mSuccess[0m	||	extract_title extracts title after frontmatter	
[32mSuccess[0m	||	extract_title returns empty for no heading	
[32mSuccess[0m	||	extract_title skips lines before header_end	
[32mSuccess[0m	||	cycle_status_value exposes status values from the generated vocabulary	
[32mSuccess[0m	||	cycle_status_value completes status frontmatter values from the vocabulary	
[32mSuccess[0m	||	cycle_status_value surfaces newly generated statuses without Lua enum edits	
[32mSuccess[0m	||	cycle_status_value cycles open to working	
[32mSuccess[0m	||	cycle_status_value cycles working to blocked	
[32mSuccess[0m	||	cycle_status_value cycles blocked by first lifecycle successor	
[32mSuccess[0m	||	cycle_status_value cycles done by lifecycle successor	
[32mSuccess[0m	||	cycle_status_value cycles wontfix by lifecycle successor	
[32mSuccess[0m	||	cycle_status_value cycles punt by lifecycle successor	
[32mSuccess[0m	||	cycle_status_value defaults unknown to open	
[32mSuccess[0m	||	render_issue_template uses the vocabulary default status for every issue template render	
[32mSuccess[0m	||	next_runnable returns nil for empty list	
[32mSuccess[0m	||	next_runnable returns single open issue with no deps	
[32mSuccess[0m	||	next_runnable skips done issues	
[32mSuccess[0m	||	next_runnable skips blocked issues	
[32mSuccess[0m	||	next_runnable skips working issues	
[32mSuccess[0m	||	next_runnable skips wontfix issues	
[32mSuccess[0m	||	next_runnable skips open issue with unmet dep	
[32mSuccess[0m	||	next_runnable returns open issue when deps are done	
[32mSuccess[0m	||	next_runnable handles diamond dependency	
[32mSuccess[0m	||	next_runnable returns nil when all deps unmet (circular)	
[32mSuccess[0m	||	next_runnable returns nil when all issues are done	
[32mSuccess[0m	||	next_runnable picks oldest open issue first	
[32mSuccess[0m	||	next_runnable advances past current_id	
[32mSuccess[0m	||	next_runnable cycles back to first when at end	
[32mSuccess[0m	||	next_runnable cycles back when current_id is past all runnable	
[32mSuccess[0m	||	next_runnable returns nil with current_id when no runnable	
[32mSuccess[0m	||	topo_sort sorts open before blocked before done	
[32mSuccess[0m	||	topo_sort sorts modeled statuses in priority order	
[32mSuccess[0m	||	topo_sort sorts by ID within same status	
[32mSuccess[0m	||	topo_sort handles empty list	
[32mSuccess[0m	||	scan_issues mtime includes filesystem mtime for archived history rows	
[32mSuccess[0m	||	format_deps formats empty deps	
[32mSuccess[0m	||	format_deps formats single dep	
[32mSuccess[0m	||	format_deps formats multiple deps	
[32mSuccess[0m	||	format_deps handles nil	
[32mSuccess[0m	||	parse_md_link_at_cursor returns the link when cursor is inside it	
[32mSuccess[0m	||	parse_md_link_at_cursor returns nil when cursor is outside any link	
[32mSuccess[0m	||	parse_md_link_at_cursor picks the link under the cursor when there are multiple	
[32mSuccess[0m	||	parse_md_link_at_cursor matches a link at the very start of the line	
[32mSuccess[0m	||	parse_md_link_at_cursor returns nil for nil inputs	
[32mSuccess[0m	||	resolve_link_target joins a relative .md link against cur_dir	
[32mSuccess[0m	||	resolve_link_target returns an absolute .md link unchanged	
[32mSuccess[0m	||	resolve_link_target joins a bare relative .md link (no ./ prefix)	
[32mSuccess[0m	||	resolve_link_target returns nil when link url is not a .md file	
[32mSuccess[0m	||	resolve_link_target returns nil when link is nil	
[32mSuccess[0m	||	resolve_link_target returns nil when link has no url field	
[32mSuccess[0m	||	parse_src_url extracts path from a src: URL	
[32mSuccess[0m	||	parse_src_url extracts a nested path	
[32mSuccess[0m	||	parse_src_url returns nil for non-src: URLs	
[32mSuccess[0m	||	parse_src_url returns nil for nil input	
[32mSuccess[0m	||	find_parent finds the issue whose deps contains child_id	
[32mSuccess[0m	||	find_parent returns nil when no parent exists	
[32mSuccess[0m	||	find_parent returns the first matching parent deterministically	
[32mSuccess[0m	||	find_parent handles nil inputs gracefully	
[32mSuccess[0m	||	find_parent tolerates issues with missing deps field	
[32mSuccess[0m	||	repo_label returns the basename of a git root	
[32mSuccess[0m	||	repo_label strips trailing slashes	
[32mSuccess[0m	||	repo_label falls back to '?' for nil or empty	
[32mSuccess[0m	||	repo_label handles a bare segment with no slashes	
	
[32mSuccess: [0m	101	
[31mFailed : [0m	0	
[31mErrors : [0m	0	
========================================	

codex
Focused traceability specs passed, including the new sort and scan-mtime coverage. I’m doing a final full-suite check because the issue log claims it and recent repo lessons call out missing lint/full-suite evidence as a recurring close risk.
exec
/bin/zsh -lc 'make test' in /Users/xianxu/workspace/parley.nvim
 succeeded in 17239ms:
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
PASS: tests/unit/custom_prompts_spec.lua
PASS: tests/unit/define_spec.lua
PASS: tests/unit/chat_dirs_spec.lua
PASS: tests/unit/discovery_base_spec.lua
PASS: tests/unit/discovery_descriptor_spec.lua
PASS: tests/unit/discovery_matcher_spec.lua
PASS: tests/unit/discovery_registry_spec.lua
PASS: tests/unit/discovery_merge_spec.lua
PASS: tests/unit/chat_slug_resolve_spec.lua
PASS: tests/unit/drill_in_spec.lua
PASS: tests/unit/exchange_clipboard_spec.lua
PASS: tests/unit/dispatcher_query_spec.lua
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
PASS: tests/unit/issues_spec.lua
PASS: tests/unit/memory_prefs_spec.lua
PASS: tests/unit/markdown_draft_block_spec.lua
PASS: tests/unit/logger_spec.lua
PASS: tests/unit/neighborhood_spec.lua
PASS: tests/unit/config_tools_spec.lua
PASS: tests/unit/note_finder_logic_spec.lua
PASS: tests/unit/obfuscate_spec.lua
PASS: tests/unit/oauth_spec.lua
PASS: tests/unit/outline_spec.lua
PASS: tests/unit/open_chat_reference_spec.lua
PASS: tests/unit/parley_harness_golden_spec.lua
PASS: tests/unit/parse_chat_spec.lua
PASS: tests/unit/picker_items_spec.lua
PASS: tests/unit/process_directory_pattern_spec.lua
PASS: tests/unit/progress_spec.lua
PASS: tests/unit/parley_harness_spec.lua
PASS: tests/unit/parse_at_reference_spec.lua
PASS: tests/unit/provider_params_spec.lua
PASS: tests/unit/providers_pre_query_spec.lua
PASS: tests/unit/keybindings_spec.lua
PASS: tests/unit/raw_log_spec.lua
PASS: tests/unit/render_buffer_spec.lua
PASS: tests/unit/pure_functions_spec.lua
PASS: tests/unit/render_buffer_roundtrip_spec.lua
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
PASS: tests/unit/tools_builtin_find_spec.lua
PASS: tests/unit/tools_builtin_ls_spec.lua
PASS: tests/unit/tools_builtin_propose_edits_spec.lua
PASS: tests/unit/tools_builtin_read_file_spec.lua
PASS: tests/unit/tools_builtin_ack_spec.lua
PASS: tests/unit/tools_builtin_registered_spec.lua
PASS: tests/unit/tools_registry_spec.lua
PASS: tests/unit/tools_serialize_spec.lua
PASS: tests/unit/tools_types_spec.lua
PASS: tests/unit/tools_dispatcher_spec.lua
PASS: tests/unit/vault_spec.lua
PASS: tests/unit/vision_spec.lua
PASS: tests/unit/tools_builtin_chat_history_search_spec.lua
PASS: tests/unit/super_repo_spec.lua
PASS: tests/integration/chat_lease_spec.lua
PASS: tests/arch/buffer_mutation_spec.lua
PASS: tests/integration/cliproxy_command_spec.lua
PASS: tests/integration/chat_move_spec.lua
PASS: tests/integration/cliproxy_auth_login_spec.lua
PASS: tests/integration/create_handler_spec.lua
PASS: tests/integration/cliproxy_caller_teardown_spec.lua
PASS: tests/integration/cliproxy_download_spec.lua
PASS: tests/integration/discovery_local_types_spec.lua
PASS: tests/integration/discovery_builder_spec.lua
PASS: tests/integration/export_spec.lua
PASS: tests/integration/cliproxy_dispatch_spec.lua
PASS: tests/integration/neighborhood_completion_spec.lua
PASS: tests/integration/new_chat_spec.lua
PASS: tests/integration/progress_spec.lua
PASS: tests/integration/not_chat_spec.lua
PASS: tests/integration/review_diag_display_spec.lua
PASS: tests/integration/review_journal_io_spec.lua
PASS: tests/integration/review_menu_spec.lua
PASS: tests/integration/review_mode_load_spec.lua
PASS: tests/integration/review_projection_spec.lua
PASS: tests/integration/skill_invoke_review_spec.lua
PASS: tests/integration/skill_registry_spec.lua
PASS: tests/integration/skill_providers_spec.lua
PASS: tests/integration/define_spec.lua
PASS: tests/integration/spell_chat_spec.lua
PASS: tests/integration/topic_gen_spec.lua
PASS: tests/integration/skill_invoke_spec.lua
PASS: tests/integration/timer_race_spec.lua
PASS: tests/integration/tree_export_spec.lua
PASS: tests/integration/voice_apply_spec.lua
PASS: tests/integration/highlighting_spec.lua
PASS: tests/integration/tasker_run_spec.lua
PASS: tests/integration/chat_respond_spec.lua
PASS: tests/integration/cliproxy_lifecycle_spec.lua

codex
```verdict
verdict: SHIP
confidence: high
```

The diff fulfills #164: history mode now sorts archived rows by filesystem `mtime` ascending with a deterministic ID fallback, while the default issues view stays on the existing status/ID ordering. I found no Critical, Important, or Minor findings.

1. Strengths:
- [issue_finder.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/issue_finder.lua:46): `sort_for_view` keeps the view-specific choice isolated and pure.
- [issues.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/issues.lua:557): cached scan results correctly refresh returned `mtime` from current `fs_stat`.
- [issue_finder_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/unit/issue_finder_spec.lua:71): tests cover both sort paths and the tie-breaker.
- [issue-management.md](/Users/xianxu/workspace/parley.nvim/atlas/issues/issue-management.md:20): atlas documents the changed history ordering.

2. Critical findings: none.

3. Important findings: none.

4. Minor findings: none.

5. Test coverage notes:
- Ran `make test-spec SPEC=issues/issue-management`: passed.
- Ran `make test`: passed, lint reported `0 warnings / 0 errors`.

6. Architectural notes:
- `ARCH-DRY`: Pass. Existing `issues.topo_sort` remains the single source for issues-view ordering.
- `ARCH-PURE`: Pass. The new sorting decision is testable without UI or filesystem IO; IO is limited to scan metadata collection.
- `ARCH-PURPOSE`: Pass. The implementation delivers the stated bottom-anchored history behavior without changing default issue ordering.

7. Plan revision recommendations: none.
tokens used
49,844
```verdict
verdict: SHIP
confidence: high
```

The diff fulfills #164: history mode now sorts archived rows by filesystem `mtime` ascending with a deterministic ID fallback, while the default issues view stays on the existing status/ID ordering. I found no Critical, Important, or Minor findings.

1. Strengths:
- [issue_finder.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/issue_finder.lua:46): `sort_for_view` keeps the view-specific choice isolated and pure.
- [issues.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/issues.lua:557): cached scan results correctly refresh returned `mtime` from current `fs_stat`.
- [issue_finder_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/unit/issue_finder_spec.lua:71): tests cover both sort paths and the tie-breaker.
- [issue-management.md](/Users/xianxu/workspace/parley.nvim/atlas/issues/issue-management.md:20): atlas documents the changed history ordering.

2. Critical findings: none.

3. Important findings: none.

4. Minor findings: none.

5. Test coverage notes:
- Ran `make test-spec SPEC=issues/issue-management`: passed.
- Ran `make test`: passed, lint reported `0 warnings / 0 errors`.

6. Architectural notes:
- `ARCH-DRY`: Pass. Existing `issues.topo_sort` remains the single source for issues-view ordering.
- `ARCH-PURE`: Pass. The new sorting decision is testable without UI or filesystem IO; IO is limited to scan metadata collection.
- `ARCH-PURPOSE`: Pass. The implementation delivers the stated bottom-anchored history behavior without changing default issue ordering.

7. Plan revision recommendations: none.
