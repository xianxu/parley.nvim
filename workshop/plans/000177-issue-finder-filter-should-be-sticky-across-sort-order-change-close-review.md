# Boundary Review — parley.nvim#177 (whole-issue close)

| field | value |
|-------|-------|
| issue | 177 — issue finder filter should be sticky across sort order change |
| repo | parley.nvim |
| issue file | workshop/issues/000177-issue-finder-filter-should-be-sticky-across-sort-order-change.md |
| boundary | whole-issue close |
| milestone | — |
| window | 7bcf135321a665313860f81dd263ec086e4130bb..HEAD |
| command | sdlc close --issue 177 |
| reviewer | codex |
| timestamp | 2026-07-10T08:06:56-07:00 |
| verdict | SHIP |

## Review

Reading additional input from stdin...
OpenAI Codex v0.144.1
--------
workdir: /Users/xianxu/workspace/parley.nvim
model: gpt-5.6-sol
provider: openai
approval: never
sandbox: workspace-write [workdir, /tmp, $TMPDIR, /tmp] (network access enabled)
reasoning effort: none
reasoning summaries: none
session id: 019f4c90-3b86-7b72-bbe5-beaf1ee0c910
--------
user
# Code review — the one SDLC boundary review

You are conducting a fresh-context code review at a development boundary —
whole-issue close — in the **parley.nvim** repository.

- repository: parley.nvim   (root: /Users/xianxu/workspace/parley.nvim)
- issue:      parley.nvim#177   (file: workshop/issues/000177-issue-finder-filter-should-be-sticky-across-sort-order-change.md)
- window:     Base: 7bcf135321a665313860f81dd263ec086e4130bb   Head: HEAD

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
index 310d9a1..1789362 100644
--- a/atlas/issues/issue-management.md
+++ b/atlas/issues/issue-management.md
@@ -17,7 +17,7 @@ default), so every reader derives from the one cue source.
 
 ## Commands
 - `:ParleyIssueNew` (`<C-y>c`): **delegates to `sdlc issue new`** (M3 #116) — the canonical creator (id allocation + the cue/sdlc-owned template + broadcast to origin/main per ariadne#82) — then opens the created file. The title prompt is prefixed with the destination repo — `[<repo>] Issue title: ` — where `<repo>` is the basename of the git root `issues_dir` resolves against (the editor's cwd root), so issues aren't created in the wrong repo (#142)
-- `:ParleyIssueFinder` (`<C-y>f`): float picker with status badges and 2-state view cycling — `<Tab>` (natural key; `<C-a>` kept for back-compat) toggles between `issues` (all of `workshop/issues/`, done items visible — the default, sorted by the existing status/ID order) and `history` (archived items in `workshop/history/`, sorted by file modification time ascending so the newest archive row sits closest to the bottom-anchored prompt) (#158, superseding the tri-state all/active/all+history from #152)
+- `:ParleyIssueFinder` (`<C-y>f`): float picker with status badges and 2-state view cycling — `<Tab>` (natural key; `<C-a>` kept for back-compat) toggles between `issues` (all of `workshop/issues/`, done items visible — the default, sorted by the existing status/ID order) and `history` (archived items in `workshop/history/`, sorted by file modification time ascending so the newest archive row sits closest to the bottom-anchored prompt) (#158, superseding the tri-state all/active/all+history from #152). The complete prompt query is kept verbatim across that repaint and later Issue Finder invocations; clearing the prompt persists the empty query (#177).
 - `:ParleyIssueNext` (`<C-y>x`): open next runnable issue (oldest open with all deps done)
 - `:ParleyIssueStatus` (`<C-y>s`): cycle frontmatter status using the first lifecycle transition for the current status in generated vocabulary order
 - `:ParleyIssueDecompose` (`<C-y>i`): create child issue from plan line, add to parent deps, and write a markdown link `[issue NNNNNN](./NNNNNN-slug.md)` into the parent's plan line; the new child file gets a `Parent: [issue PPPPPP](./PPPPPP-...md)` backlink under its title. (M3 #116: decompose **retains** parley's `render_issue_template` — its semantics, parent.deps += child + the parent plan-line link + the backlink, are incompatible with `sdlc issue new`'s shape, so unlike `:ParleyIssueNew` it is not delegated.)
diff --git a/atlas/modes/super_repo.md b/atlas/modes/super_repo.md
index 18a5ee3..3af8f72 100644
--- a/atlas/modes/super_repo.md
+++ b/atlas/modes/super_repo.md
@@ -47,12 +47,14 @@ were extended explicitly during M3-M5.
 
 ## Sticky `{repo}` filter
 
-Every super-repo-aware finder (chat, note, issue, vision, markdown) preserves
-`{repo}` filter fragments across reopens via `lua/parley/finder_sticky.lua`.
-Both completed (`{charon}`) and in-progress (`{char`) prompt fragments are
-extracted on every keystroke, normalised to the completed form, and re-seeded
-as `initial_query` next time. Chat finder additionally preserves `[tag]`
-fragments.
+Chat, note, vision, and markdown finders preserve `{repo}` filter fragments
+across reopens via `lua/parley/finder_sticky.lua`. Both completed (`{charon}`)
+and in-progress (`{char`) prompt fragments are extracted on every keystroke,
+normalised to the completed form, and re-seeded as `initial_query` next time.
+Chat finder additionally preserves `[tag]` fragments. Issue Finder is the
+intentional exception: it preserves the complete opaque query, including plain
+text, so the same filter survives view-cycle repaint and later invocations
+(#177).
 
 Matching is also forgiving of in-progress brackets: `{char` matches the same
 items as `{charon}` would (prefix match against the haystack `{repo}` token),
@@ -90,7 +92,8 @@ filter for plain repo mode's primary note root.
 - `lua/parley/issue_finder.lua`, `vision_finder.lua`, `markdown_finder.lua`
   — multi-root aggregation when `super_repo_members` is non-empty.
 - `lua/parley/finder_sticky.lua` — shared `{root}` / `[tag]` extraction and
-  initial-query formatter used by every finder for sticky filters.
+  initial-query formatter used by chat, note, vision, and markdown finders;
+  Issue Finder owns its distinct full-query persistence policy.
 - `lua/parley/lualine.lua` — `format_mode`, `create_mode_component`, and
   the filetype-component auto-replace at setup time.
 - `lua/parley/keybinding_registry.lua` — `super_repo_toggle` entry.
diff --git a/atlas/ui/pickers.md b/atlas/ui/pickers.md
index dd57870..05a422d 100644
--- a/atlas/ui/pickers.md
+++ b/atlas/ui/pickers.md
@@ -9,7 +9,7 @@ Up/down arrow keys wrap around at list boundaries (top wraps to bottom, bottom w
 AND-matching across whitespace-split tokens. Token-prefix scoring, bounded edit-distance typo tolerance, subsequence fallback. `{root}` / `[tag]` query tokens scope to bracketed haystack labels of the same kind; in-progress forms (`{char`, `[bu`) work the same way as their completed counterparts.
 
 ## Sticky Query
-`lua/parley/finder_sticky.lua` extracts `{root}` (and `[tag]` for chat finder) fragments from the prompt on every keystroke and re-seeds them on the next reopen. Plain text is intentionally not preserved. Wired into chat, note, issue, vision, and markdown finders.
+`lua/parley/finder_sticky.lua` extracts `{root}` (and `[tag]` for chat finder) fragments from the prompt on every keystroke and re-seeds them on the next reopen. Plain text is intentionally not preserved in chat, note, vision, and markdown finders. Issue Finder is the deliberate exception: it stores the complete opaque prompt query so plain text and structured filters survive both view-cycle repaint and later invocations (#177).
 
 The chat finder additionally pre-seeds `{}` (the primary chat root, which in repo mode is the repo chat root) on the first open of a parley session in plain repo mode, so the default view is scoped to repo chats and global chats are filtered out. The pre-seed is a one-shot — once the user clears or modifies the filter, sticky-query takes over and the default is never re-applied. Skipped in super-repo mode (whose whole point is aggregating siblings, which a `{}` narrowing would defeat).
 
diff --git a/lua/parley/init.lua b/lua/parley/init.lua
index c1aced4..89de32b 100644
--- a/lua/parley/init.lua
+++ b/lua/parley/init.lua
@@ -3108,7 +3108,7 @@ M._issue_finder = {
 	view_mode = 0, -- 0=issues (default, done visible), 1=history (#158)
 	initial_index = nil,
 	initial_value = nil,
-	sticky_query = nil, -- Preserved {repo} filter across invocations
+	query = nil, -- Complete prompt query preserved across invocations
 }
 
 M._vision_finder = {
diff --git a/lua/parley/issue_finder.lua b/lua/parley/issue_finder.lua
index b84ec4d..e4b1b47 100644
--- a/lua/parley/issue_finder.lua
+++ b/lua/parley/issue_finder.lua
@@ -2,7 +2,6 @@
 -- Float picker UI for browsing, filtering, and managing issues
 
 local issues_mod = require("parley.issues")
-local finder_sticky = require("parley.finder_sticky")
 
 local M = {}
 local _parley
@@ -249,10 +248,10 @@ M.open = function(_options)
         items = items,
         recall_key = "parley.issue_finder",
         initial_index = chat_finder_mod.resolve_finder_initial_index(_parley._issue_finder, items, "IssueFinder"),
-        initial_query = finder_sticky.format_initial_query(_parley._issue_finder.sticky_query),
+        initial_query = _parley._issue_finder.query,
         anchor = "bottom",
         on_query_change = function(query)
-            _parley._issue_finder.sticky_query = finder_sticky.extract(query, { "root" })
+            _parley._issue_finder.query = query
         end,
         on_select = function(item)
             if source_win and vim.api.nvim_win_is_valid(source_win) then
diff --git a/tests/unit/issue_finder_spec.lua b/tests/unit/issue_finder_spec.lua
index 79a7111..a1e075c 100644
--- a/tests/unit/issue_finder_spec.lua
+++ b/tests/unit/issue_finder_spec.lua
@@ -16,6 +16,7 @@ parley.setup({
 })
 
 local issue_finder = require("parley.issue_finder")
+local issues = require("parley.issues")
 
 describe("IssueFinder view-mode logic", function()
     local function sample_issues()
@@ -108,3 +109,133 @@ describe("IssueFinder view-mode logic", function()
         end)
     end)
 end)
+
+describe("IssueFinder query persistence", function()
+    local original_defer_fn
+    local original_scan_issues
+    local deferred
+    local fake
+    local picker_calls
+
+    local function cycle_view_mapping(opts)
+        for _, mapping in ipairs(opts.mappings) do
+            if mapping.key == "<Tab>" then
+                return mapping
+            end
+        end
+        error("missing <Tab> cycle-view mapping")
+    end
+
+    before_each(function()
+        deferred = {}
+        picker_calls = {}
+        fake = {
+            _issue_finder = { opened = false, view_mode = 0 },
+            config = {
+                issues_dir = "/unused/issues",
+                history_dir = "/unused/history",
+                issue_finder_mappings = {},
+            },
+            float_picker = {
+                open = function(opts)
+                    table.insert(picker_calls, opts)
+                end,
+            },
+            helpers = {},
+            logger = { warning = function() end },
+            cmd = {},
+            open_buf = function() end,
+        }
+
+        original_scan_issues = issues.scan_issues
+        issues.scan_issues = function(_, opts)
+            if opts.include_history then
+                return { {
+                    id = "000002",
+                    status = "done",
+                    title = "Archived",
+                    slug = "archived",
+                    path = "/tmp/archived.md",
+                    archived = true,
+                    mtime = 2,
+                    created = "",
+                } }
+            end
+            return { {
+                id = "000001",
+                status = "open",
+                title = "Active",
+                slug = "active",
+                path = "/tmp/active.md",
+                archived = false,
+                created = "",
+            } }
+        end
+
+        original_defer_fn = vim.defer_fn
+        vim.defer_fn = function(fn)
+            table.insert(deferred, fn)
+        end
+        fake.cmd.IssueFinder = function()
+            issue_finder.open()
+        end
+        issue_finder.setup(fake)
+    end)
+
+    after_each(function()
+        issues.scan_issues = original_scan_issues
+        vim.defer_fn = original_defer_fn
+        issue_finder.setup(parley)
+    end)
+
+    it("preserves the raw query after cancel and later invocation", function()
+        issue_finder.open()
+        picker_calls[1].on_query_change("  sticky {repo} query  ")
+        picker_calls[1].on_cancel()
+
+        issue_finder.open()
+
+        assert.equals("  sticky {repo} query  ", fake._issue_finder.query)
+        assert.equals("  sticky {repo} query  ", picker_calls[2].initial_query)
+    end)
+
+    it("preserves the query after selection and later invocation", function()
+        issue_finder.open()
+        picker_calls[1].on_query_change("needle")
+        picker_calls[1].on_select(picker_calls[1].items[1])
+
+        issue_finder.open()
+
+        assert.equals("needle", picker_calls[2].initial_query)
+    end)
+
+    it("persists a cleared query", function()
+        fake._issue_finder.query = "old query"
+        issue_finder.open()
+        picker_calls[1].on_query_change("")
+        picker_calls[1].on_cancel()
+
+        issue_finder.open()
+
+        assert.equals("", fake._issue_finder.query)
+        assert.equals("", picker_calls[2].initial_query)
+    end)
+
+    it("preserves the query through the view-cycle repaint", function()
+        issue_finder.open()
+        picker_calls[1].on_query_change("needle {repo}")
+        local closed = false
+
+        cycle_view_mapping(picker_calls[1]).fn(nil, function()
+            closed = true
+        end)
+
+        assert.is_true(closed)
+        assert.equals(1, #deferred)
+        deferred[1]()
+        assert.equals(2, #picker_calls)
+        assert.matches("history", picker_calls[2].title)
+        assert.equals("/tmp/archived.md", picker_calls[2].items[1].value)
+        assert.equals("needle {repo}", picker_calls[2].initial_query)
+    end)
+end)
diff --git a/workshop/plans/000177-issue-finder-filter-should-be-sticky-across-sort-order-change-plan.md b/workshop/plans/000177-issue-finder-filter-should-be-sticky-across-sort-order-change-plan.md
index febabb4..9283682 100644
--- a/workshop/plans/000177-issue-finder-filter-should-be-sticky-across-sort-order-change-plan.md
+++ b/workshop/plans/000177-issue-finder-filter-should-be-sticky-across-sort-order-change-plan.md
@@ -33,7 +33,7 @@ No pure entity changes. The feature preserves an opaque user-input string withou
 **Files:**
 - Modify: `tests/unit/issue_finder_spec.lua`
 
-- [ ] **Step 1: Add an isolated real-`open` test harness**
+- [x] **Step 1: Add an isolated real-`open` test harness**
 
   In a new `describe`, require `parley.issues` as `issues`, save/restore `vim.defer_fn`, and call `issue_finder.setup(fake_parley)` in each `before_each`. Give the fake a fresh `_issue_finder` table, one scanned issue, the current valid source window, an ordered `picker_calls` list, and a `deferred` queue:
 
@@ -68,7 +68,7 @@ No pure entity changes. The feature preserves an opaque user-input string withou
 
   Restore `issues.scan_issues` and `vim.defer_fn` in `after_each`. This runs the real Issue Finder orchestration while faking only scanning, picker IO, and time.
 
-- [ ] **Step 2: Write the raw-query and cancel/reinvoke failing test**
+- [x] **Step 2: Write the raw-query and cancel/reinvoke failing test**
 
   Open once, feed the exact mixed query through the first picker call, cancel, then open again through the real entry point:
 
@@ -82,21 +82,21 @@ No pure entity changes. The feature preserves an opaque user-input string withou
 
   Assert the saved raw query remains on `fake._issue_finder.query`. Expected RED: the current structured extractor stores only `{repo}` and the formatter appends a space.
 
-- [ ] **Step 3: Run the focused spec and verify the raw-query case is RED**
+- [x] **Step 3: Run the focused spec and verify the raw-query case is RED**
 
   Run: `make test-spec SPEC=issues/issue-management`
 
   Expected: FAIL in `preserves the raw query after cancel and later invocation`, with actual `{repo} ` instead of the exact mixed string.
 
-- [ ] **Step 4: Write the clearing and selection/reinvoke failing cases**
+- [x] **Step 4: Write the clearing and selection/reinvoke failing cases**
 
   In separate tests with fresh state, feed `"needle"`, call `on_select` with the first item, invoke again, and assert the second `initial_query == "needle"`. Then feed `""`, cancel, invoke again, and assert the second `initial_query == ""` and state contains the empty string. These cases pin both picker-close paths and prevent an old value from being resurrected.
 
-- [ ] **Step 5: Write the controlled view-cycle failing case**
+- [x] **Step 5: Write the controlled view-cycle failing case**
 
   Feed `"needle {repo}"`, locate the cycle mapping by its configured/default key `<Tab>`, and call its `fn(item, close_fn)` with a close spy. Assert it queued one deferred callback; execute `deferred[1]()` so the real `fake.cmd.IssueFinder → issue_finder.open` path collects `picker_calls[2]`. Assert the close spy ran, the second title contains `history`, its item is the archived fixture, and `picker_calls[2].initial_query == "needle {repo}"`.
 
-- [ ] **Step 6: Run the focused spec and verify all new cases are RED for query restoration**
+- [x] **Step 6: Run the focused spec and verify all new cases are RED for query restoration**
 
   Run: `make test-spec SPEC=issues/issue-management`
 
@@ -112,7 +112,7 @@ No pure entity changes. The feature preserves an opaque user-input string withou
 - Modify: `atlas/modes/super_repo.md`
 - Modify: `atlas/issues/issue-management.md`
 
-- [ ] **Step 1: Implement the minimal state wiring**
+- [x] **Step 1: Implement the minimal state wiring**
 
   Rename the initialized Issue Finder state field from structured-only `sticky_query` to opaque `query`, update its comment, and replace Issue Finder's use of `finder_sticky` with direct state:
 
@@ -125,13 +125,13 @@ No pure entity changes. The feature preserves an opaque user-input string withou
 
   Remove the now-unused `finder_sticky` import. Do not trim, parse, append whitespace, or clear the state from selection/cancel/view-cycle handlers (`ARCH-PURE`).
 
-- [ ] **Step 2: Run the focused spec and verify GREEN**
+- [x] **Step 2: Run the focused spec and verify GREEN**
 
   Run: `make test-spec SPEC=issues/issue-management`
 
   Expected: all issue-management specs pass, including the named raw whitespace, mixed query, clearing, selection/cancel reinvocation, and view-cycle repaint cases. Existing `finder_sticky` specs remain unchanged, proving other finders retain their structured-only policy.
 
-- [ ] **Step 3: Run lint and the full suite**
+- [x] **Step 3: Run lint and the full suite**
 
   Run: `make lint`
 
@@ -141,10 +141,10 @@ No pure entity changes. The feature preserves an opaque user-input string withou
 
   Expected: exit 0 for lint, unit, integration, and architecture checks.
 
-- [ ] **Step 4: Reconcile the documented finder-persistence policy**
+- [x] **Step 4: Reconcile the documented finder-persistence policy**
 
   Update `atlas/ui/pickers.md` and `atlas/modes/super_repo.md`, whose current statements say plain text is never preserved and every finder uses `finder_sticky`, to document Issue Finder as the intentional full-query exception. Update `atlas/issues/issue-management.md` to describe the complete query surviving view repaint and later invocation. Search `README.md` and the rest of `atlas/` for additional Issue Finder persistence claims, then run `git diff --check` on #177 paths and inspect `git status --short` so unrelated issue edits remain unstaged (`ARCH-PURPOSE`).
 
-- [ ] **Step 5: Commit the implementation**
+- [x] **Step 5: Commit the implementation**
 
   Stage only `lua/parley/init.lua`, `lua/parley/issue_finder.lua`, `tests/unit/issue_finder_spec.lua`, `atlas/ui/pickers.md`, `atlas/modes/super_repo.md`, `atlas/issues/issue-management.md`, and the #177 issue/plan. Commit using the repository convention and a `Co-Authored-By:` trailer.


codex
I’m applying the repository’s SDLC review workflow and fresh-context review rules. I’ll inspect the governing skills, issue/plan, exact diff, and relevant picker behavior, then run only non-editing verification appropriate to this boundary.
exec
/bin/zsh -lc "sed -n '1,240p' /Users/xianxu/workspace/ariadne/construct/adapted/superpowers-using-superpowers/SKILL.md && sed -n '1,280p' /Users/xianxu/workspace/ariadne/construct/local/sdlc/SKILL.md && sdlc --help && sed -n '1,240p' workshop/lessons.md" in /Users/xianxu/workspace/parley.nvim
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

## 2026-07-08 (#178)
- **After changing a shared parser rule, grep for every shadow parser before close.** #178 changed `define.managed_footnote_footer_range`, but `chat_parser.lua` still had a local footer scanner at close review. Rule: for grammar or boundary-policy changes, grep the old predicates/terms and route all consumers through shared helpers before boundary review.

exec
/bin/zsh -lc "sed -n '1,260p' workshop/issues/000177-issue-finder-filter-should-be-sticky-across-sort-order-change.md && sed -n '1,240p' workshop/plans/000177-issue-finder-filter-should-be-sticky-across-sort-order-change-plan.md && git status --short && git log --oneline --decorate 7bcf135321a665313860f81dd263ec086e4130bb..HEAD && git diff --stat 7bcf135321a665313860f81dd263ec086e4130bb..HEAD && git diff --check 7bcf135321a665313860f81dd263ec086e4130bb..HEAD && git diff 7bcf135321a665313860f81dd263ec086e4130bb..HEAD -- lua/parley/init.lua lua/parley/issue_finder.lua tests/unit/issue_finder_spec.lua" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
---
id: 000177
status: working
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-10
estimate_hours: 0.98
started: 2026-07-10T01:19:44-07:00
---

# issue finder filter should be sticky across sort order change

## Problem

Issue Finder loses the user's prompt query whenever it closes and opens again. This
includes the repaint triggered by changing between the `issues` and `history` views,
so the visible result set unexpectedly becomes unfiltered after a sort/view change.

## Spec

- Preserve Issue Finder's complete prompt query in its existing finder state whenever
  the query changes. Plain search text, structured `{repo}` filters, and mixtures of
  both must survive unchanged.
- Seed every later Issue Finder invocation from that saved query, including the
  invocation used to repaint after cycling between `issues` and `history`.
- Clearing the prompt must clear the saved query; a later invocation must open with
  an empty prompt rather than resurrecting an older query.
- Keep this full-query policy local to Issue Finder. Other finders retain their
  existing structured-filter-only persistence semantics (`ARCH-DRY`, `ARCH-PURPOSE`).
- Keep filtering in `float_picker`; Issue Finder only captures and restores the query
  at the UI boundary (`ARCH-PURE`).

## Done when

- Plain text remains in the prompt after cycling the Issue Finder view and after
  closing and invoking Issue Finder again.
- `{repo}` filters and mixed plain/structured queries are restored exactly.
- Clearing the prompt persists as an empty query.
- Automated tests cover capture and restoration without changing other finders'
  persistence policy.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.10 impl=0.04
item: lua-neovim design=0.30 impl=0.30
item: milestone-review design=0.05 impl=0.12
design-buffer: 0.15
total: 0.98
```

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only.*

## Plan

- [x] Add failing coverage for raw full-query capture/restoration, clearing,
  later invocation, and view-cycle repaint.
- [x] Replace Issue Finder's structured-only query extraction with direct opaque
  query state; keep other finders unchanged.
- [x] Run focused and full verification, reconcile documentation, and close #177.

Durable implementation plan:
`workshop/plans/000177-issue-finder-filter-should-be-sticky-across-sort-order-change-plan.md`.

## Log

### 2026-07-08

### 2026-07-10 — complete query persistence implemented

Issue Finder now owns one opaque full-query state value and passes it unchanged
through `float_picker`'s existing capture/restore seam. TDD covered cancel,
selection, clearing, and view-cycle repaint; the mapped issue suite and full
`make test` passed. Updated all known atlas persistence-policy consumers
(`ARCH-DRY`, `ARCH-PURE`, `ARCH-PURPOSE`).
# Sticky Issue Finder Query Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve the complete Issue Finder prompt query across view repaints and later invocations.

**Architecture:** Keep the query on the existing `_parley._issue_finder` state object. `issue_finder.open` passes that raw value directly to `float_picker.initial_query` and replaces it from `on_query_change`; no query parsing or formatting is added, so `float_picker` remains the filtering owner and other finders keep their structured-only policy.

**Tech Stack:** Lua, Neovim, Plenary/Busted, existing `float_picker` and Issue Finder state.

---

## Core concepts

### Pure entities

No pure entity changes. The feature preserves an opaque user-input string without transforming it; introducing a query abstraction would add behavior the issue does not need.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `IssueFinderQueryState` | `lua/parley/init.lua`, `lua/parley/issue_finder.lua` | modified | `float_picker` prompt input and `_parley._issue_finder` session state |

- **IssueFinderQueryState** — captures every prompt value and supplies the last value verbatim to each Issue Finder invocation.
  - **Injected into:** `float_picker.open` through its existing `initial_query` and `on_query_change` options; no new dependency is introduced.
  - **Future extensions:** None planned. Full-query persistence remains Issue Finder-specific because shared `finder_sticky` intentionally implements a different structured-filter policy (`ARCH-DRY`, `ARCH-PURPOSE`).

## Chunk 1: Persist and verify the complete query

### Task 1: Pin the Issue Finder query-state contract

**Files:**
- Modify: `tests/unit/issue_finder_spec.lua`

- [x] **Step 1: Add an isolated real-`open` test harness**

  In a new `describe`, require `parley.issues` as `issues`, save/restore `vim.defer_fn`, and call `issue_finder.setup(fake_parley)` in each `before_each`. Give the fake a fresh `_issue_finder` table, one scanned issue, the current valid source window, an ordered `picker_calls` list, and a `deferred` queue:

  ```lua
  local picker_calls = {}
  local deferred = {}
  local fake = {
      _issue_finder = { opened = false, view_mode = 0 },
      config = {
          issues_dir = "/unused/issues",
          history_dir = "/unused/history",
          issue_finder_mappings = {},
      },
      float_picker = {
          open = function(opts) table.insert(picker_calls, opts) end,
      },
      helpers = {},
      logger = { warning = function() end },
      cmd = {},
      open_buf = function() end,
  }

  local original_scan = issues.scan_issues
  issues.scan_issues = function(_, opts)
      return opts.include_history
          and { { id = "000002", status = "done", title = "Archived", slug = "archived", path = "/tmp/archived.md", archived = true, mtime = 2 } }
          or { { id = "000001", status = "open", title = "Active", slug = "active", path = "/tmp/active.md", archived = false } }
  end
  vim.defer_fn = function(fn) table.insert(deferred, fn) end
  fake.cmd.IssueFinder = function() issue_finder.open() end
  ```

  Restore `issues.scan_issues` and `vim.defer_fn` in `after_each`. This runs the real Issue Finder orchestration while faking only scanning, picker IO, and time.

- [x] **Step 2: Write the raw-query and cancel/reinvoke failing test**

  Open once, feed the exact mixed query through the first picker call, cancel, then open again through the real entry point:

  ```lua
  issue_finder.open()
  picker_calls[1].on_query_change("  sticky {repo} query  ")
  picker_calls[1].on_cancel()
  issue_finder.open()
  assert.equals("  sticky {repo} query  ", picker_calls[2].initial_query)
  ```

  Assert the saved raw query remains on `fake._issue_finder.query`. Expected RED: the current structured extractor stores only `{repo}` and the formatter appends a space.

- [x] **Step 3: Run the focused spec and verify the raw-query case is RED**

  Run: `make test-spec SPEC=issues/issue-management`

  Expected: FAIL in `preserves the raw query after cancel and later invocation`, with actual `{repo} ` instead of the exact mixed string.

- [x] **Step 4: Write the clearing and selection/reinvoke failing cases**

  In separate tests with fresh state, feed `"needle"`, call `on_select` with the first item, invoke again, and assert the second `initial_query == "needle"`. Then feed `""`, cancel, invoke again, and assert the second `initial_query == ""` and state contains the empty string. These cases pin both picker-close paths and prevent an old value from being resurrected.

- [x] **Step 5: Write the controlled view-cycle failing case**

  Feed `"needle {repo}"`, locate the cycle mapping by its configured/default key `<Tab>`, and call its `fn(item, close_fn)` with a close spy. Assert it queued one deferred callback; execute `deferred[1]()` so the real `fake.cmd.IssueFinder → issue_finder.open` path collects `picker_calls[2]`. Assert the close spy ran, the second title contains `history`, its item is the archived fixture, and `picker_calls[2].initial_query == "needle {repo}"`.

- [x] **Step 6: Run the focused spec and verify all new cases are RED for query restoration**

  Run: `make test-spec SPEC=issues/issue-management`

  Expected: the new named raw-query, selection, clearing, and view-cycle cases fail on the old structured-only query behavior; all pre-existing cases pass.

### Task 2: Store and restore the raw Issue Finder query

**Files:**
- Modify: `lua/parley/init.lua`
- Modify: `lua/parley/issue_finder.lua`
- Modify: `tests/unit/issue_finder_spec.lua`
- Modify: `atlas/ui/pickers.md`
- Modify: `atlas/modes/super_repo.md`
- Modify: `atlas/issues/issue-management.md`

- [x] **Step 1: Implement the minimal state wiring**

  Rename the initialized Issue Finder state field from structured-only `sticky_query` to opaque `query`, update its comment, and replace Issue Finder's use of `finder_sticky` with direct state:

  ```lua
  initial_query = _parley._issue_finder.query,
  on_query_change = function(query)
      _parley._issue_finder.query = query
  end,
  ```

  Remove the now-unused `finder_sticky` import. Do not trim, parse, append whitespace, or clear the state from selection/cancel/view-cycle handlers (`ARCH-PURE`).

- [x] **Step 2: Run the focused spec and verify GREEN**

  Run: `make test-spec SPEC=issues/issue-management`

  Expected: all issue-management specs pass, including the named raw whitespace, mixed query, clearing, selection/cancel reinvocation, and view-cycle repaint cases. Existing `finder_sticky` specs remain unchanged, proving other finders retain their structured-only policy.

- [x] **Step 3: Run lint and the full suite**

  Run: `make lint`

  Expected: exit 0 with no warnings.

  Run: `make test`

  Expected: exit 0 for lint, unit, integration, and architecture checks.

- [x] **Step 4: Reconcile the documented finder-persistence policy**

  Update `atlas/ui/pickers.md` and `atlas/modes/super_repo.md`, whose current statements say plain text is never preserved and every finder uses `finder_sticky`, to document Issue Finder as the intentional full-query exception. Update `atlas/issues/issue-management.md` to describe the complete query surviving view repaint and later invocation. Search `README.md` and the rest of `atlas/` for additional Issue Finder persistence claims, then run `git diff --check` on #177 paths and inspect `git status --short` so unrelated issue edits remain unstaged (`ARCH-PURPOSE`).

- [x] **Step 5: Commit the implementation**

  Stage only `lua/parley/init.lua`, `lua/parley/issue_finder.lua`, `tests/unit/issue_finder_spec.lua`, `atlas/ui/pickers.md`, `atlas/modes/super_repo.md`, `atlas/issues/issue-management.md`, and the #177 issue/plan. Commit using the repository convention and a `Co-Authored-By:` trailer.
 M workshop/issues/000162-split-parley-into-two-different-plugins.md
 M workshop/issues/000168-buffer-undo-operation-during-chat-generation-resulted-in-a-huge-error-message.md
 M workshop/issues/000170-parley-chat-performance-problem.md
0c6adba (HEAD -> 000177-issue-finder-filter-should-be-sticky-across-sort-order-change) issue: #177 complete implementation plan
3c42d84 issue: #177 preserve full finder query
 atlas/issues/issue-management.md                   |   2 +-
 atlas/modes/super_repo.md                          |  17 +--
 atlas/ui/pickers.md                                |   2 +-
 lua/parley/init.lua                                |   2 +-
 lua/parley/issue_finder.lua                        |   5 +-
 tests/unit/issue_finder_spec.lua                   | 131 +++++++++++++++++++++
 ...er-should-be-sticky-across-sort-order-change.md |  14 ++-
 ...ould-be-sticky-across-sort-order-change-plan.md |  22 ++--
 8 files changed, 168 insertions(+), 27 deletions(-)
diff --git a/lua/parley/init.lua b/lua/parley/init.lua
index c1aced4..89de32b 100644
--- a/lua/parley/init.lua
+++ b/lua/parley/init.lua
@@ -3108,7 +3108,7 @@ M._issue_finder = {
 	view_mode = 0, -- 0=issues (default, done visible), 1=history (#158)
 	initial_index = nil,
 	initial_value = nil,
-	sticky_query = nil, -- Preserved {repo} filter across invocations
+	query = nil, -- Complete prompt query preserved across invocations
 }
 
 M._vision_finder = {
diff --git a/lua/parley/issue_finder.lua b/lua/parley/issue_finder.lua
index b84ec4d..e4b1b47 100644
--- a/lua/parley/issue_finder.lua
+++ b/lua/parley/issue_finder.lua
@@ -2,7 +2,6 @@
 -- Float picker UI for browsing, filtering, and managing issues
 
 local issues_mod = require("parley.issues")
-local finder_sticky = require("parley.finder_sticky")
 
 local M = {}
 local _parley
@@ -249,10 +248,10 @@ M.open = function(_options)
         items = items,
         recall_key = "parley.issue_finder",
         initial_index = chat_finder_mod.resolve_finder_initial_index(_parley._issue_finder, items, "IssueFinder"),
-        initial_query = finder_sticky.format_initial_query(_parley._issue_finder.sticky_query),
+        initial_query = _parley._issue_finder.query,
         anchor = "bottom",
         on_query_change = function(query)
-            _parley._issue_finder.sticky_query = finder_sticky.extract(query, { "root" })
+            _parley._issue_finder.query = query
         end,
         on_select = function(item)
             if source_win and vim.api.nvim_win_is_valid(source_win) then
diff --git a/tests/unit/issue_finder_spec.lua b/tests/unit/issue_finder_spec.lua
index 79a7111..a1e075c 100644
--- a/tests/unit/issue_finder_spec.lua
+++ b/tests/unit/issue_finder_spec.lua
@@ -16,6 +16,7 @@ parley.setup({
 })
 
 local issue_finder = require("parley.issue_finder")
+local issues = require("parley.issues")
 
 describe("IssueFinder view-mode logic", function()
     local function sample_issues()
@@ -108,3 +109,133 @@ describe("IssueFinder view-mode logic", function()
         end)
     end)
 end)
+
+describe("IssueFinder query persistence", function()
+    local original_defer_fn
+    local original_scan_issues
+    local deferred
+    local fake
+    local picker_calls
+
+    local function cycle_view_mapping(opts)
+        for _, mapping in ipairs(opts.mappings) do
+            if mapping.key == "<Tab>" then
+                return mapping
+            end
+        end
+        error("missing <Tab> cycle-view mapping")
+    end
+
+    before_each(function()
+        deferred = {}
+        picker_calls = {}
+        fake = {
+            _issue_finder = { opened = false, view_mode = 0 },
+            config = {
+                issues_dir = "/unused/issues",
+                history_dir = "/unused/history",
+                issue_finder_mappings = {},
+            },
+            float_picker = {
+                open = function(opts)
+                    table.insert(picker_calls, opts)
+                end,
+            },
+            helpers = {},
+            logger = { warning = function() end },
+            cmd = {},
+            open_buf = function() end,
+        }
+
+        original_scan_issues = issues.scan_issues
+        issues.scan_issues = function(_, opts)
+            if opts.include_history then
+                return { {
+                    id = "000002",
+                    status = "done",
+                    title = "Archived",
+                    slug = "archived",
+                    path = "/tmp/archived.md",
+                    archived = true,
+                    mtime = 2,
+                    created = "",
+                } }
+            end
+            return { {
+                id = "000001",
+                status = "open",
+                title = "Active",
+                slug = "active",
+                path = "/tmp/active.md",
+                archived = false,
+                created = "",
+            } }
+        end
+
+        original_defer_fn = vim.defer_fn
+        vim.defer_fn = function(fn)
+            table.insert(deferred, fn)
+        end
+        fake.cmd.IssueFinder = function()
+            issue_finder.open()
+        end
+        issue_finder.setup(fake)
+    end)
+
+    after_each(function()
+        issues.scan_issues = original_scan_issues
+        vim.defer_fn = original_defer_fn
+        issue_finder.setup(parley)
+    end)
+
+    it("preserves the raw query after cancel and later invocation", function()
+        issue_finder.open()
+        picker_calls[1].on_query_change("  sticky {repo} query  ")
+        picker_calls[1].on_cancel()
+
+        issue_finder.open()
+
+        assert.equals("  sticky {repo} query  ", fake._issue_finder.query)
+        assert.equals("  sticky {repo} query  ", picker_calls[2].initial_query)
+    end)
+
+    it("preserves the query after selection and later invocation", function()
+        issue_finder.open()
+        picker_calls[1].on_query_change("needle")
+        picker_calls[1].on_select(picker_calls[1].items[1])
+
+        issue_finder.open()
+
+        assert.equals("needle", picker_calls[2].initial_query)
+    end)
+
+    it("persists a cleared query", function()
+        fake._issue_finder.query = "old query"
+        issue_finder.open()
+        picker_calls[1].on_query_change("")
+        picker_calls[1].on_cancel()
+
+        issue_finder.open()
+
+        assert.equals("", fake._issue_finder.query)
+        assert.equals("", picker_calls[2].initial_query)
+    end)
+
+    it("preserves the query through the view-cycle repaint", function()
+        issue_finder.open()
+        picker_calls[1].on_query_change("needle {repo}")
+        local closed = false
+
+        cycle_view_mapping(picker_calls[1]).fn(nil, function()
+            closed = true
+        end)
+
+        assert.is_true(closed)
+        assert.equals(1, #deferred)
+        deferred[1]()
+        assert.equals(2, #picker_calls)
+        assert.matches("history", picker_calls[2].title)
+        assert.equals("/tmp/archived.md", picker_calls[2].items[1].value)
+        assert.equals("needle {repo}", picker_calls[2].initial_query)
+    end)
+end)

codex
The implementation is tightly scoped and the tracker’s core-concepts table matches the touched integration seam so far. I’m now checking the real picker callback timing and all shadow references, since persistence bugs here would most likely hide between prompt edits and the deferred view repaint rather than in the two-line state assignment itself.
exec
/bin/zsh -lc "rg -n \"on_query_change|initial_query|sticky_query|_issue_finder\\.query|IssueFinder\" lua tests README.md atlas --glob '"'!workshop/history/**'"' && nl -ba lua/parley/issue_finder.lua | sed -n '180,310p' && rg -n \"function.*open|M\\.open|on_query_change\" lua/parley/float_picker.lua lua/parley -g '*picker*.lua' && nl -ba lua/parley/float_picker.lua | sed -n '1,280p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
atlas/issues/issue-management.md:20:- `:ParleyIssueFinder` (`<C-y>f`): float picker with status badges and 2-state view cycling — `<Tab>` (natural key; `<C-a>` kept for back-compat) toggles between `issues` (all of `workshop/issues/`, done items visible — the default, sorted by the existing status/ID order) and `history` (archived items in `workshop/history/`, sorted by file modification time ascending so the newest archive row sits closest to the bottom-anchored prompt) (#158, superseding the tri-state all/active/all+history from #152). The complete prompt query is kept verbatim across that repaint and later Issue Finder invocations; clearing the prompt persists the empty query (#177).
lua/parley/issue_finder.lua:16:-- The IssueFinder cycles a TWO-state `view_mode` via (view_mode + 1) % 2, on
lua/parley/issue_finder.lua:75:        _parley.cmd.IssueFinder()
lua/parley/issue_finder.lua:138:-- Main IssueFinder open function
lua/parley/issue_finder.lua:234:            _parley.cmd.IssueFinder()
lua/parley/issue_finder.lua:250:        initial_index = chat_finder_mod.resolve_finder_initial_index(_parley._issue_finder, items, "IssueFinder"),
lua/parley/issue_finder.lua:251:        initial_query = _parley._issue_finder.query,
lua/parley/issue_finder.lua:253:        on_query_change = function(query)
lua/parley/issue_finder.lua:254:            _parley._issue_finder.query = query
lua/parley/init.lua:833:			issue_finder = function() M.cmd.IssueFinder({}) end,
lua/parley/init.lua:3102:	sticky_query = nil,
lua/parley/init.lua:3118:	sticky_query = nil, -- Preserved {repo} filter across invocations
lua/parley/init.lua:3122:	sticky_query = nil, -- Preserved {repo} filter across invocations (super-repo mode)
lua/parley/init.lua:4053:	sticky_query = nil, -- Preserved [tag] / {root-label} filter fragments carried across invocations
lua/parley/init.lua:4054:	sticky_query_initialized = false, -- One-shot guard: chat_finder.M.open seeds the default {repo} filter on first open in repo mode
lua/parley/init.lua:4117:M.cmd.IssueFinder = function(opts) issue_finder_mod.open(opts) end
lua/parley/float_picker.lua:552:---   initial_query string – initial prompt text used to pre-filter items (optional)
lua/parley/float_picker.lua:557:---   on_query_change function(query) – called when prompt text changes (optional)
lua/parley/float_picker.lua:572:    local on_query_change = opts.on_query_change or function() end
lua/parley/float_picker.lua:627:    local query_text = type(opts.initial_query) == "string" and opts.initial_query or ""
lua/parley/float_picker.lua:824:        on_query_change(query_text)
lua/parley/float_picker.lua:1173:    on_query_change(query_text)
atlas/modes/super_repo.md:53:normalised to the completed form, and re-seeded as `initial_query` next time.
lua/parley/chat_finder.lua:43:-- or nil to leave sticky_query alone.
lua/parley/chat_finder.lua:44:function M.default_sticky_query_for_repo_mode(config)
lua/parley/chat_finder.lua:532:	-- pre-seed sticky_query to "{}" so the finder defaults to repo chats.
lua/parley/chat_finder.lua:533:	-- After the user clears or modifies the filter, sticky_query takes over and
lua/parley/chat_finder.lua:535:	if not _parley._chat_finder.sticky_query_initialized then
lua/parley/chat_finder.lua:536:		_parley._chat_finder.sticky_query_initialized = true
lua/parley/chat_finder.lua:537:		if _parley._chat_finder.sticky_query == nil then
lua/parley/chat_finder.lua:538:			_parley._chat_finder.sticky_query = M.default_sticky_query_for_repo_mode(_parley.config)
lua/parley/chat_finder.lua:759:			initial_query = finder_sticky.format_initial_query(_parley._chat_finder.sticky_query),
lua/parley/chat_finder.lua:761:			on_query_change = function(query)
lua/parley/chat_finder.lua:762:				_parley._chat_finder.sticky_query = finder_sticky.extract(query, { "root", "tag" })
lua/parley/vision_finder.lua:78:        initial_query = finder_sticky.format_initial_query(_parley._vision_finder.sticky_query),
lua/parley/vision_finder.lua:80:        on_query_change = function(query)
lua/parley/vision_finder.lua:81:            _parley._vision_finder.sticky_query = finder_sticky.extract(query, { "root" })
lua/parley/markdown_finder.lua:212:		initial_query = finder_sticky.format_initial_query(_parley._markdown_finder.sticky_query),
lua/parley/markdown_finder.lua:213:		on_query_change = function(query)
lua/parley/markdown_finder.lua:214:			_parley._markdown_finder.sticky_query = finder_sticky.extract(query, { "root" })
lua/parley/finder_sticky.lua:63:-- Format a sticky query for use as `initial_query` when reopening a picker.
lua/parley/finder_sticky.lua:65:function M.format_initial_query(sticky_query)
lua/parley/finder_sticky.lua:66:    if type(sticky_query) ~= "string" or sticky_query == "" then
lua/parley/finder_sticky.lua:69:    return sticky_query .. " "
lua/parley/note_finder.lua:430:		initial_query = finder_sticky.format_initial_query(_parley._note_finder.sticky_query),
lua/parley/note_finder.lua:432:		on_query_change = function(query)
lua/parley/note_finder.lua:433:			_parley._note_finder.sticky_query = finder_sticky.extract(query, { "root" })
tests/unit/issue_finder_spec.lua:1:-- Unit tests for IssueFinder pure view-mode logic (#158, was #152).
tests/unit/issue_finder_spec.lua:3:-- IssueFinder is a float-picker UI feature; these specs cover the pure pieces
tests/unit/issue_finder_spec.lua:21:describe("IssueFinder view-mode logic", function()
tests/unit/issue_finder_spec.lua:113:describe("IssueFinder query persistence", function()
tests/unit/issue_finder_spec.lua:179:        fake.cmd.IssueFinder = function()
tests/unit/issue_finder_spec.lua:193:        picker_calls[1].on_query_change("  sticky {repo} query  ")
tests/unit/issue_finder_spec.lua:198:        assert.equals("  sticky {repo} query  ", fake._issue_finder.query)
tests/unit/issue_finder_spec.lua:199:        assert.equals("  sticky {repo} query  ", picker_calls[2].initial_query)
tests/unit/issue_finder_spec.lua:204:        picker_calls[1].on_query_change("needle")
tests/unit/issue_finder_spec.lua:209:        assert.equals("needle", picker_calls[2].initial_query)
tests/unit/issue_finder_spec.lua:213:        fake._issue_finder.query = "old query"
tests/unit/issue_finder_spec.lua:215:        picker_calls[1].on_query_change("")
tests/unit/issue_finder_spec.lua:220:        assert.equals("", fake._issue_finder.query)
tests/unit/issue_finder_spec.lua:221:        assert.equals("", picker_calls[2].initial_query)
tests/unit/issue_finder_spec.lua:226:        picker_calls[1].on_query_change("needle {repo}")
tests/unit/issue_finder_spec.lua:239:        assert.equals("needle {repo}", picker_calls[2].initial_query)
tests/unit/chat_finder_logic_spec.lua:99:            sticky_query = nil,
tests/unit/chat_finder_logic_spec.lua:100:            sticky_query_initialized = false,
tests/unit/chat_finder_logic_spec.lua:805:            M._chat_finder.sticky_query = "[workspace] {secondary} [client-a]"
tests/unit/chat_finder_logic_spec.lua:815:            assert.equals("[workspace] {secondary} [client-a] ", captured.initial_query)
tests/unit/chat_finder_logic_spec.lua:816:            assert.is_function(captured.on_query_change)
tests/unit/chat_finder_logic_spec.lua:834:            captured.on_query_change("[workspace] {secondary} shipping [client-a]")
tests/unit/chat_finder_logic_spec.lua:835:            assert.equals("[workspace] {secondary} [client-a]", M._chat_finder.sticky_query)
tests/unit/chat_finder_logic_spec.lua:837:            captured.on_query_change("shipping")
tests/unit/chat_finder_logic_spec.lua:838:            assert.is_nil(M._chat_finder.sticky_query)
tests/unit/chat_finder_logic_spec.lua:861:            captured.on_query_change("{secondary}")
tests/unit/chat_finder_logic_spec.lua:862:            assert.equals("{secondary}", M._chat_finder.sticky_query)
tests/unit/chat_finder_logic_spec.lua:879:            captured.on_query_change("{} primary")
tests/unit/chat_finder_logic_spec.lua:880:            assert.equals("{}", M._chat_finder.sticky_query)
tests/unit/chat_finder_logic_spec.lua:914:    describe("default_sticky_query_for_repo_mode", function()
tests/unit/chat_finder_logic_spec.lua:918:            local got = chat_finder.default_sticky_query_for_repo_mode({
tests/unit/chat_finder_logic_spec.lua:925:            assert.is_nil(chat_finder.default_sticky_query_for_repo_mode({}))
tests/unit/chat_finder_logic_spec.lua:926:            assert.is_nil(chat_finder.default_sticky_query_for_repo_mode({ repo_root = "" }))
tests/unit/chat_finder_logic_spec.lua:927:            assert.is_nil(chat_finder.default_sticky_query_for_repo_mode(nil))
tests/unit/chat_finder_logic_spec.lua:931:            local got = chat_finder.default_sticky_query_for_repo_mode({
tests/unit/note_finder_logic_spec.lua:71:            sticky_query = nil,
tests/unit/note_finder_logic_spec.lua:254:        assert.is_function(captured.on_query_change)
tests/unit/note_finder_logic_spec.lua:256:        captured.on_query_change("{K} evergreen")
tests/unit/note_finder_logic_spec.lua:257:        assert.equals("{K}", M._note_finder.sticky_query)
tests/unit/note_finder_logic_spec.lua:260:        assert.equals("{K} ", captured.initial_query)
tests/unit/note_finder_logic_spec.lua:262:        captured.on_query_change("evergreen")
tests/unit/note_finder_logic_spec.lua:263:        assert.is_nil(M._note_finder.sticky_query)
tests/unit/note_finder_logic_spec.lua:279:        captured.on_query_change("{} dated")
tests/unit/note_finder_logic_spec.lua:280:        assert.equals("{}", M._note_finder.sticky_query)
tests/unit/note_finder_logic_spec.lua:283:        assert.equals("{} ", captured.initial_query)
tests/unit/float_picker_spec.lua:192:        it("seeds the prompt and filtered results from initial_query", function()
tests/unit/float_picker_spec.lua:195:                initial_query = "beta",
tests/unit/finder_sticky_spec.lua:53:describe("finder_sticky.format_initial_query", function()
tests/unit/finder_sticky_spec.lua:55:        assert.is_nil(sticky.format_initial_query(nil))
tests/unit/finder_sticky_spec.lua:56:        assert.is_nil(sticky.format_initial_query(""))
tests/unit/finder_sticky_spec.lua:60:        assert.equals("{charon} ", sticky.format_initial_query("{charon}"))
   180	    -- View mode: 0=issues (default), 1=history. Clamp with % 2 so any stale
   181	    -- in-memory value (e.g. a `2` left by the pre-#158 tri-state) self-heals.
   182	    local view_mode = (_parley._issue_finder.view_mode or 0) % 2
   183	    local include_history = M.includes_history(view_mode)
   184	    local all_issues = {}
   185	    for _, root in ipairs(roots) do
   186	        if root.issues_dir then
   187	            local got = issues_mod.scan_issues(root.issues_dir, {
   188	                include_history = include_history,
   189	                history_dir_override = root.history_dir,
   190	                repo_name = root.repo_name,
   191	            })
   192	            vim.list_extend(all_issues, got)
   193	        end
   194	    end
   195	
   196	    local sorted = M.sort_for_view(view_mode, M.filter_for_view(view_mode, all_issues))
   197	
   198	    -- Build picker items
   199	    local items = {}
   200	    for _, issue in ipairs(sorted) do
   201	        local prefix = issue.archived and "[archived]" or string.format("[%s]", issue.status)
   202	        local label = issue.title ~= "" and issue.title or issue.slug
   203	        local repo_prefix = issue.repo_name and ("{" .. issue.repo_name .. "} ") or ""
   204	        local display = string.format("%s%s %s %s", repo_prefix, prefix, issue.id, label)
   205	        if issue.github_issue then
   206	            display = display .. " (#" .. issue.github_issue .. ")"
   207	        end
   208	        if issue.created ~= "" then
   209	            display = display .. " [" .. issue.created .. "]"
   210	        end
   211	        table.insert(items, {
   212	            display = display,
   213	            search_text = string.format("%s%s %s %s %s", repo_prefix, issue.status, issue.id, issue.title, issue.slug),
   214	            value = issue.path,
   215	            issue = issue,
   216	        })
   217	    end
   218	
   219	    local source_win = _parley._issue_finder.source_win
   220	    if not (source_win and vim.api.nvim_win_is_valid(source_win)) then
   221	        source_win = vim.api.nvim_get_current_win()
   222	        _parley._issue_finder.source_win = source_win
   223	    end
   224	
   225	    -- Cycle the 2-state view (issues ↔ history) and reopen. Shared by both the
   226	    -- `<Tab>` (cycle_view) and `<C-a>` (toggle_done) mappings — one handler,
   227	    -- two keys (#158, ARCH-DRY).
   228	    local function cycle_view_fn(_, close_fn)
   229	        _parley._issue_finder.view_mode = (view_mode + 1) % 2
   230	        close_fn()
   231	        vim.defer_fn(function()
   232	            _parley._issue_finder.opened = false
   233	            _parley._issue_finder.source_win = source_win
   234	            _parley.cmd.IssueFinder()
   235	        end, 100)
   236	    end
   237	
   238	    local chat_finder_mod = require("parley.chat_finder")
   239	
   240	    local prompt_title = string.format(
   241	        "Issues (%s  %s: cycle view)",
   242	        M.VIEW_LABELS[view_mode] or M.VIEW_LABELS[0],
   243	        cycle_view_shortcut.shortcut
   244	    )
   245	
   246	    _parley.float_picker.open({
   247	        title = prompt_title,
   248	        items = items,
   249	        recall_key = "parley.issue_finder",
   250	        initial_index = chat_finder_mod.resolve_finder_initial_index(_parley._issue_finder, items, "IssueFinder"),
   251	        initial_query = _parley._issue_finder.query,
   252	        anchor = "bottom",
   253	        on_query_change = function(query)
   254	            _parley._issue_finder.query = query
   255	        end,
   256	        on_select = function(item)
   257	            if source_win and vim.api.nvim_win_is_valid(source_win) then
   258	                vim.api.nvim_set_current_win(source_win)
   259	            end
   260	            _parley.open_buf(item.value, true)
   261	        end,
   262	        on_cancel = function()
   263	            _parley._issue_finder.opened = false
   264	            _parley._issue_finder.initial_index = nil
   265	            _parley._issue_finder.initial_value = nil
   266	        end,
   267	        mappings = {
   268	            {
   269	                key = delete_shortcut.shortcut,
   270	                fn = function(item, close_fn, context)
   271	                    if not item then
   272	                        return
   273	                    end
   274	                    local selected_index = 1
   275	                    for idx, picker_item in ipairs(items) do
   276	                        if picker_item.value == item.value then
   277	                            selected_index = idx
   278	                            break
   279	                        end
   280	                    end
   281	
   282	                    context.skip_focus_restore = true
   283	                    context.issue_finder_items = items
   284	                    context.suspend_for_external_ui()
   285	                    vim.defer_fn(function()
   286	                        M.prompt_delete_confirmation(
   287	                            item.value,
   288	                            selected_index,
   289	                            #items,
   290	                            source_win,
   291	                            close_fn,
   292	                            context
   293	                        )
   294	                    end, 20)
   295	                end,
   296	            },
   297	            {
   298	                key = cycle_status_shortcut.shortcut,
   299	                fn = function(item, close_fn)
   300	                    if not item or not item.issue then
   301	                        return
   302	                    end
   303	                    -- Read the file, cycle status, write back
   304	                    local lines = vim.fn.readfile(item.value)
   305	                    local fm = issues_mod.parse_frontmatter(lines)
   306	                    if fm then
   307	                        local new_status = issues_mod.cycle_status_value(fm.status)
   308	                        for i = 2, fm.header_end - 1 do
   309	                            if lines[i]:match("^status:") then
   310	                                lines[i] = "status: " .. new_status
lua/parley/float_picker.lua:557:---   on_query_change function(query) – called when prompt text changes (optional)
lua/parley/float_picker.lua:567:function M.open(opts)
lua/parley/float_picker.lua:572:    local on_query_change = opts.on_query_change or function() end
lua/parley/float_picker.lua:824:        on_query_change(query_text)
lua/parley/float_picker.lua:1173:    on_query_change(query_text)
lua/parley/skill_picker.lua:30:local function open_arg_picker(buf, skill, args, arg_index)
lua/parley/skill_picker.lua:74:M.open = function()
lua/parley/float_picker.lua:557:---   on_query_change function(query) – called when prompt text changes (optional)
lua/parley/float_picker.lua:567:function M.open(opts)
lua/parley/float_picker.lua:572:    local on_query_change = opts.on_query_change or function() end
lua/parley/float_picker.lua:824:        on_query_change(query_text)
lua/parley/float_picker.lua:1173:    on_query_change(query_text)
lua/parley/root_dir_picker.lua:58:---   reopen        — function(initial_dir) to reopen this picker
lua/parley/root_dir_picker.lua:60:function M.open(opts)
     1	-- float_picker.lua
     2	-- A self-contained floating window picker for Parley.nvim.
     3	--
     4	-- Layout: two adjacent floating windows —
     5	--   Results window (top, focusable): items with cursorline showing selection.
     6	--   Prompt window  (bottom, focused):  user types query here; results filter live.
     7	--
     8	-- Mouse:
     9	--   <LeftMouse> in results  – move selection, return focus to prompt
    10	--   <2-LeftMouse> in results – confirm selected item and close
    11	--
    12	-- Keyboard (from prompt, insert mode):
    13	--   <CR>          – confirm selected item
    14	--   <Esc>/<C-c>   – cancel
    15	--   <C-j>/<Down>  – move selection down
    16	--   <C-k>/<Up>    – move selection up
    17	--
    18	-- Fuzzy matching (multi-word):
    19	--   Query is split on whitespace into words.
    20	--   ALL words must match for an item to appear.
    21	--   Word order in the query does NOT matter ("gpt open" matches "openai gpt-4").
    22	--   Within each word, characters must appear IN ORDER in the haystack (subsequence).
    23	--   Items are ranked by total score (higher = better match).
    24	--
    25	-- Sizing:
    26	--   desired_w = max(title+4, longest item+2) or opts.width.
    27	--   desired_h = #items or opts.height (results rows only).
    28	--   Actual size clamped to screen minus MARGIN_H / MARGIN_V on each side.
    29	--   Total vertical space = results_h + 5 (borders for both windows + prompt row).
    30	--   VimResized repositions both windows (global autocmd, cleaned up on close).
    31	
    32	local M = {}
    33	
    34	-- In-memory map of recall_key → last confirmed item.value, used to restore
    35	-- cursor position across reopens of the same picker within a session.
    36	M._last_selection = {}
    37	
    38	local logger = require("parley.logger")
    39	local MIN_W    = 20  -- minimum picker width  (chars)
    40	local MIN_H    = 1   -- minimum results height (lines)
    41	local MARGIN_H = 4   -- cols kept clear on each horizontal edge
    42	local MARGIN_V = 3   -- rows kept clear on each vertical edge
    43	local PROMPT_PREFIX = "> "
    44	local APPROXIMATE_MATCH_HL = "ParleyPickerApproximateMatch"
    45	-- Rows consumed by borders of both windows + 1 prompt content row:
    46	--   results top-border(1) + results bottom-border(1) +
    47	--   prompt  top-border(1) + prompt  content(1) + prompt bottom-border(1) = 5
    48	local PROMPT_OVERHEAD = 5
    49	-- Rows consumed by the optional tag bar window:
    50	--   top-border(1) + content(1) + bottom-border(1) = 3
    51	local TAG_BAR_OVERHEAD = 3
    52	
    53	-- Highlight namespace for fuzzy match characters in results.
    54	local MATCH_NS = vim.api.nvim_create_namespace("float_picker_match")
    55	
    56	-- ---------------------------------------------------------------------------
    57	-- Fuzzy scoring
    58	-- ---------------------------------------------------------------------------
    59	
    60	local MAX_PREFIX_TYPO_DISTANCE = 2
    61	
    62	local function is_word_char(char)
    63	    return char ~= "" and char:match("[%w]") ~= nil
    64	end
    65	
    66	local function is_boundary(text, index)
    67	    if index <= 1 then
    68	        return true
    69	    end
    70	    local preceding = text:sub(index - 1, index - 1)
    71	    return not is_word_char(preceding)
    72	end
    73	
    74	local function tokenize_query(query)
    75	    local tokens = {}
    76	    for token in (query or ""):lower():gmatch("%S+") do
    77	        local normalized = token
    78	        local kind = "plain"
    79	        if token:match("^%b[]$") then
    80	            normalized = token:sub(2, -2)
    81	            kind = "tag"
    82	        elseif token:match("^%b{}$") then
    83	            normalized = token:sub(2, -2)
    84	            kind = "root"
    85	        elseif token:sub(1, 1) == "[" and not token:find("]", 2, true) then
    86	            -- in-progress tag: user typed `[xxx` without closing `]`
    87	            normalized = token:sub(2)
    88	            kind = "tag"
    89	        elseif token:sub(1, 1) == "{" and not token:find("}", 2, true) then
    90	            -- in-progress root: user typed `{xxx` without closing `}`
    91	            normalized = token:sub(2)
    92	            kind = "root"
    93	        end
    94	        if normalized ~= "" or (kind == "root" and token == "{}") then
    95	            table.insert(tokens, {
    96	                kind = kind,
    97	                text = normalized,
    98	            })
    99	        end
   100	    end
   101	    return tokens
   102	end
   103	
   104	local function tokenize_haystack(haystack)
   105	    local text = (haystack or ""):lower()
   106	    local tokens = {}
   107	    local wrapped_search_from = 1
   108	
   109	    while wrapped_search_from <= #text do
   110	        local start_idx, end_idx = text:find("[%[%{][^%]%}]*[%]%}]", wrapped_search_from)
   111	        if not start_idx then
   112	            break
   113	        end
   114	        local wrapped = text:sub(start_idx, end_idx)
   115	        local kind = wrapped:sub(1, 1) == "[" and "tag" or "root"
   116	        table.insert(tokens, {
   117	            kind = kind,
   118	            text = wrapped:sub(2, -2),
   119	            start_idx = start_idx + 1,
   120	        })
   121	        wrapped_search_from = end_idx + 1
   122	    end
   123	
   124	    local search_from = 1
   125	
   126	    while search_from <= #text do
   127	        local start_idx, end_idx = text:find("[%w]+", search_from)
   128	        if not start_idx then
   129	            break
   130	        end
   131	        table.insert(tokens, {
   132	            kind = "plain",
   133	            text = text:sub(start_idx, end_idx),
   134	            start_idx = start_idx,
   135	        })
   136	        search_from = end_idx + 1
   137	    end
   138	
   139	    if #tokens == 0 and text ~= "" then
   140	        table.insert(tokens, { kind = "plain", text = text, start_idx = 1 })
   141	    end
   142	
   143	    return tokens
   144	end
   145	
   146	local function reverse_list(list)
   147	    local reversed = {}
   148	    for idx = #list, 1, -1 do
   149	        table.insert(reversed, list[idx])
   150	    end
   151	    return reversed
   152	end
   153	
   154	local function levenshtein_alignment(a, b, max_distance)
   155	    local a_len = #a
   156	    local b_len = #b
   157	
   158	    if math.abs(a_len - b_len) > max_distance then
   159	        return nil
   160	    end
   161	
   162	    local dp = {}
   163	    for i = 0, a_len do
   164	        dp[i] = {}
   165	    end
   166	    for i = 0, a_len do
   167	        dp[i][0] = i
   168	    end
   169	    for j = 0, b_len do
   170	        dp[0][j] = j
   171	    end
   172	
   173	    for i = 1, a_len do
   174	        local row_min = dp[i][0]
   175	        local a_char = a:sub(i, i)
   176	        for j = 1, b_len do
   177	            local cost = (a_char == b:sub(j, j)) and 0 or 1
   178	            dp[i][j] = math.min(
   179	                dp[i - 1][j] + 1,
   180	                dp[i][j - 1] + 1,
   181	                dp[i - 1][j - 1] + cost
   182	            )
   183	            if dp[i][j] < row_min then
   184	                row_min = dp[i][j]
   185	            end
   186	        end
   187	
   188	        if row_min > max_distance then
   189	            return nil
   190	        end
   191	    end
   192	
   193	    if dp[a_len][b_len] > max_distance then
   194	        return nil
   195	    end
   196	
   197	    local matched_positions = {}
   198	    local edit_positions = {}
   199	    local i = a_len
   200	    local j = b_len
   201	
   202	    while i > 0 or j > 0 do
   203	        local moved = false
   204	
   205	        if i > 0 and j > 0 then
   206	            local cost = (a:sub(i, i) == b:sub(j, j)) and 0 or 1
   207	            if dp[i][j] == dp[i - 1][j - 1] + cost then
   208	                if cost == 0 then
   209	                    table.insert(matched_positions, j)
   210	                else
   211	                    table.insert(edit_positions, j)
   212	                end
   213	                i = i - 1
   214	                j = j - 1
   215	                moved = true
   216	            end
   217	        end
   218	
   219	        if not moved and j > 0 and dp[i][j] == dp[i][j - 1] + 1 then
   220	            table.insert(edit_positions, j)
   221	            j = j - 1
   222	            moved = true
   223	        end
   224	
   225	        if not moved and i > 0 and dp[i][j] == dp[i - 1][j] + 1 then
   226	            i = i - 1
   227	            moved = true
   228	        end
   229	
   230	        if not moved then
   231	            break
   232	        end
   233	    end
   234	
   235	    return {
   236	        distance = dp[a_len][b_len],
   237	        edit_positions = reverse_list(edit_positions),
   238	        matched_positions = reverse_list(matched_positions),
   239	    }
   240	end
   241	
   242	local function bounded_prefix_distance(query_token, candidate_token, max_distance)
   243	    if query_token == "" or candidate_token == "" then
   244	        return nil, nil
   245	    end
   246	
   247	    if query_token:sub(1, 1) ~= candidate_token:sub(1, 1) then
   248	        return nil, nil
   249	    end
   250	
   251	    local min_prefix_len = #query_token
   252	    local max_prefix_len = math.min(#candidate_token, #query_token + max_distance)
   253	    local best_distance = nil
   254	    local best_prefix_len = nil
   255	    local best_alignment = nil
   256	
   257	    for prefix_len = min_prefix_len, max_prefix_len do
   258	        local prefix = candidate_token:sub(1, prefix_len)
   259	        local alignment = levenshtein_alignment(query_token, prefix, max_distance)
   260	        local distance = alignment and alignment.distance or nil
   261	        if distance ~= nil and (best_distance == nil or distance < best_distance) then
   262	            best_distance = distance
   263	            best_prefix_len = prefix_len
   264	            best_alignment = alignment
   265	            if distance == 0 and prefix_len == #query_token then
   266	                break
   267	            end
   268	        end
   269	    end
   270	
   271	    return best_distance, best_prefix_len, best_alignment
   272	end
   273	
   274	-- Return a subsequence score and positions for `word` inside `haystack`.
   275	-- The score rewards early, boundary, and consecutive matches while penalizing gaps.
   276	local function score_subsequence(word, haystack)
   277	    local hw = (haystack or ""):lower()
   278	    local ww = (word or ""):lower()
   279	    if ww == "" then
   280	        return 0, {}

exec
/bin/zsh -lc "nl -ba lua/parley/float_picker.lua | sed -n '550,850p'; nl -ba lua/parley/float_picker.lua | sed -n '1125,1190p'; nl -ba tests/unit/issue_finder_spec.lua | sed -n '105,250p'; git show --stat --oneline 3c42d84; git show --stat --oneline 0c6adba; git diff 7bcf135321a665313860f81dd263ec086e4130bb..HEAD -- workshop/issues/000177-issue-finder-filter-should-be-sticky-across-sort-order-change.md README.md atlas" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   550	---   title      string   – window title (shown on results window)
   551	---   items      table    – list of { display: string, value: any, search_text?: string }
   552	---   initial_query string – initial prompt text used to pre-filter items (optional)
   553	---   width      number   – desired window width  (optional, content-driven by default)
   554	---   height     number   – desired results height (optional, #items by default)
   555	---   on_select  function(item) – called on confirmation
   556	---   on_cancel  function()    – called on cancel/dismiss (optional)
   557	---   on_query_change function(query) – called when prompt text changes (optional)
   558	---   mappings   table    – list of { key: string, fn: function(item, close_fn) }
   559	---                         keys are mapped in the prompt (insert mode)
   560	---   recall_key string   – optional. When set, the last confirmed item's id
   561	---                         is remembered and used as the initial cursor position
   562	---                         on the next open (falling back to initial_index when
   563	---                         the recalled id is no longer present).
   564	---   recall_id_fn function(item) – optional id extractor; defaults to item.value.
   565	---                         Used when item identity lives on a different field
   566	---                         (e.g. item.name for agents, item.dir for root dirs).
   567	function M.open(opts)
   568	    local items          = opts.items or {}
   569	    local title          = opts.title or "Select"
   570	    local on_select      = opts.on_select or function() end
   571	    local on_cancel      = opts.on_cancel or function() end
   572	    local on_query_change = opts.on_query_change or function() end
   573	    local extra_mappings = opts.mappings or {}
   574	
   575	    if #items == 0 then
   576	        vim.notify("No items to pick from", vim.log.levels.WARN)
   577	        return
   578	    end
   579	
   580	    local desired_w = opts.width or (function()
   581	        local w = vim.fn.strdisplaywidth(title) + 4
   582	        for _, item in ipairs(items) do
   583	            local iw = vim.fn.strdisplaywidth(item.display) + 2
   584	            if iw > w then w = iw end
   585	        end
   586	        return w
   587	    end)()
   588	    local desired_h = opts.height or #items
   589	
   590	    local tag_bar_opts = opts.tag_bar  -- optional: { tags = [{label, enabled}], on_toggle = fn(label) }
   591	    local has_tag_bar = tag_bar_opts ~= nil and type(tag_bar_opts.tags) == "table" and #tag_bar_opts.tags > 0
   592	
   593	    local ui = vim.api.nvim_list_uis()[1] or { width = 80, height = 24 }
   594	    local win_w, win_h, row, col, tag_bar_row, prompt_row = compute_layout(desired_w, desired_h, ui, has_tag_bar)
   595	
   596	    local results_buf = vim.api.nvim_create_buf(false, true)
   597	    vim.bo[results_buf].bufhidden = "wipe"
   598	    vim.bo[results_buf].buftype = "nofile"
   599	
   600	    local prompt_buf = vim.api.nvim_create_buf(false, true)
   601	    vim.bo[prompt_buf].bufhidden = "wipe"
   602	    vim.bo[prompt_buf].buftype = "prompt"
   603	    vim.fn.prompt_setprompt(prompt_buf, PROMPT_PREFIX)
   604	
   605	    local anchor = opts.anchor or "bottom"
   606	    local filtered = vim.deepcopy(items)
   607	
   608	    -- Recall: optionally remember the last confirmed selection for this picker
   609	    -- across reopens within the session, falling back to initial_index when the
   610	    -- recalled value is no longer present. recall_id_fn lets callers whose item
   611	    -- identity isn't on item.value (e.g. agent_picker uses item.name) pick the
   612	    -- stable field; defaults to item.value.
   613	    local recall_key = opts.recall_key
   614	    local recall_id_fn = opts.recall_id_fn or function(item) return item.value end
   615	    local resolved_initial = tonumber(opts.initial_index)
   616	    if not resolved_initial and recall_key and M._last_selection[recall_key] ~= nil then
   617	        local target = M._last_selection[recall_key]
   618	        for idx, item in ipairs(items) do
   619	            if recall_id_fn(item) == target then
   620	                resolved_initial = idx
   621	                break
   622	            end
   623	        end
   624	    end
   625	    local initial_index = math.max(1, resolved_initial or 1)
   626	    local sel_idx = initial_index
   627	    local query_text = type(opts.initial_query) == "string" and opts.initial_query or ""
   628	    local query_cursor = #query_text
   629	    local closed = false
   630	    local external_ui_active = false
   631	    local resize_autocmd_id = nil
   632	    local on_key_ns = vim.api.nvim_create_namespace("float_picker_on_key")
   633	
   634	    local function keycode(key)
   635	        return vim.api.nvim_replace_termcodes(key, true, false, true)
   636	    end
   637	    local function key_name(key)
   638	        return vim.fn.keytrans(key)
   639	    end
   640	    local reserved_keys = {
   641	        [key_name(keycode("<CR>"))] = "<CR>",
   642	        [key_name(keycode("<Esc>"))] = "<Esc>",
   643	    }
   644	
   645	    local results_cfg = {
   646	        relative = "editor",
   647	        row = row,
   648	        col = col,
   649	        width = win_w,
   650	        height = win_h,
   651	        style = "minimal",
   652	        border = "rounded",
   653	        focusable = true,
   654	    }
   655	    if vim.fn.has("nvim-0.9") == 1 then
   656	        results_cfg.title = " " .. title .. " "
   657	        results_cfg.title_pos = "center"
   658	    end
   659	
   660	    local results_win = vim.api.nvim_open_win(results_buf, false, results_cfg)
   661	    vim.wo[results_win].cursorline = true
   662	    vim.wo[results_win].winhighlight = "CursorLine:PmenuSel"
   663	    vim.wo[results_win].wrap = false
   664	    vim.wo[results_win].scrolloff = 0
   665	    vim.wo[results_win].number = false
   666	    vim.wo[results_win].relativenumber = false
   667	    vim.wo[results_win].signcolumn = "no"
   668	    vim.wo[results_win].spell = false
   669	
   670	    local prompt_cfg = {
   671	        relative = "editor",
   672	        row = prompt_row,
   673	        col = col,
   674	        width = win_w,
   675	        height = 1,
   676	        style = "minimal",
   677	        border = "rounded",
   678	        focusable = true,
   679	    }
   680	    local prompt_win = vim.api.nvim_open_win(prompt_buf, true, prompt_cfg)
   681	    vim.wo[prompt_win].wrap = false
   682	    vim.wo[prompt_win].number = false
   683	    vim.wo[prompt_win].relativenumber = false
   684	    vim.wo[prompt_win].signcolumn = "no"
   685	
   686	    -- Tag bar window (optional, between results and prompt)
   687	    local tag_bar_buf = nil
   688	    local tag_bar_win = nil
   689	    local tag_col_ranges = {}  -- { {start_col, end_col, label}, ... } for click detection
   690	    local TAG_BAR_NS = vim.api.nvim_create_namespace("float_picker_tag_bar")
   691	
   692	    if has_tag_bar then
   693	        tag_bar_buf = vim.api.nvim_create_buf(false, true)
   694	        vim.bo[tag_bar_buf].bufhidden = "wipe"
   695	        vim.bo[tag_bar_buf].buftype = "nofile"
   696	        local tag_bar_cfg = {
   697	            relative = "editor",
   698	            row = tag_bar_row,
   699	            col = col,
   700	            width = win_w,
   701	            height = 1,
   702	            style = "minimal",
   703	            border = "rounded",
   704	            focusable = false,
   705	        }
   706	        tag_bar_win = vim.api.nvim_open_win(tag_bar_buf, false, tag_bar_cfg)
   707	        vim.wo[tag_bar_win].wrap = false
   708	        vim.wo[tag_bar_win].number = false
   709	        vim.wo[tag_bar_win].relativenumber = false
   710	        vim.wo[tag_bar_win].signcolumn = "no"
   711	
   712	        -- Define highlight groups (default=true makes each call idempotent)
   713	        vim.api.nvim_set_hl(0, "ParleyTagOn",     { bold = true,    default = true })
   714	        vim.api.nvim_set_hl(0, "ParleyTagOff",    { link = "Comment", default = true })
   715	        vim.api.nvim_set_hl(0, "ParleyTagAction", { reverse = true, default = true })
   716	    end
   717	
   718	    -- Sentinel labels for the fixed ALL/NONE action buttons (can't appear in real tag names)
   719	    local TAG_ACTION_ALL  = "\0all"
   720	    local TAG_ACTION_NONE = "\0none"
   721	
   722	    local function render_tag_bar()
   723	        if not has_tag_bar or not tag_bar_buf or not vim.api.nvim_buf_is_valid(tag_bar_buf) then
   724	            return
   725	        end
   726	        local parts = {}
   727	        local ranges = {}
   728	        local col_pos = 2  -- 1-indexed, starts after leading space
   729	        local line = " "
   730	
   731	        -- Determine ALL/NONE active state from current tag enabled flags
   732	        local all_on, all_off = true, true
   733	        for _, tag in ipairs(tag_bar_opts.tags) do
   734	            if not tag.enabled then all_on = false end
   735	            if tag.enabled then all_off = false end
   736	        end
   737	        -- all_active: ALL is the current state; none_active: NONE is the current state; mixed: neither
   738	        local all_active  = all_on
   739	        local none_active = all_off
   740	
   741	        local function add_button(btn, label, part_extra)
   742	            local start_col = col_pos
   743	            local end_col = col_pos + #btn - 1
   744	            local part = { text = btn, label = label, start_col = start_col, end_col = end_col }
   745	            for k, v in pairs(part_extra) do part[k] = v end
   746	            table.insert(parts, part)
   747	            table.insert(ranges, { start_col, end_col, label })
   748	            col_pos = end_col + 2
   749	            line = line .. btn .. " "
   750	        end
   751	
   752	        -- Fixed action buttons first
   753	        add_button("ALL",  TAG_ACTION_ALL,  { is_action = true, active = all_active })
   754	        add_button("NONE", TAG_ACTION_NONE, { is_action = true, active = none_active })
   755	
   756	        -- Separator
   757	        line = line .. " "
   758	        col_pos = col_pos + 1
   759	
   760	        -- Tag toggle buttons
   761	        for _, tag in ipairs(tag_bar_opts.tags) do
   762	            local btn = "[" .. (tag.label == "" and "" or tag.label) .. "]"
   763	            add_button(btn, tag.label, { enabled = tag.enabled })
   764	        end
   765	
   766	        tag_col_ranges = ranges
   767	        vim.bo[tag_bar_buf].modifiable = true
   768	        vim.api.nvim_buf_set_lines(tag_bar_buf, 0, -1, false, { line })
   769	        vim.bo[tag_bar_buf].modifiable = false
   770	        -- Apply highlights
   771	        vim.api.nvim_buf_clear_namespace(tag_bar_buf, TAG_BAR_NS, 0, -1)
   772	        for _, part in ipairs(parts) do
   773	            local hl
   774	            if part.is_action then
   775	                hl = part.active and "ParleyTagAction" or "ParleyTagOff"
   776	            else
   777	                hl = part.enabled and "ParleyTagOn" or "ParleyTagOff"
   778	            end
   779	            vim.api.nvim_buf_add_highlight(tag_bar_buf, TAG_BAR_NS, hl,
   780	                0, part.start_col - 1, part.end_col)
   781	        end
   782	    end
   783	
   784	    local function prompt_line()
   785	        if not vim.api.nvim_buf_is_valid(prompt_buf) then
   786	            return PROMPT_PREFIX
   787	        end
   788	        return vim.api.nvim_buf_get_lines(prompt_buf, 0, 1, false)[1] or PROMPT_PREFIX
   789	    end
   790	
   791	    local function current_query_from_buffer()
   792	        local line = prompt_line()
   793	        if line:sub(1, #PROMPT_PREFIX) == PROMPT_PREFIX then
   794	            return line:sub(#PROMPT_PREFIX + 1)
   795	        end
   796	        return line
   797	    end
   798	
   799	    local function render_prompt()
   800	        if closed then return end
   801	        if not vim.api.nvim_buf_is_valid(prompt_buf) then
   802	            return
   803	        end
   804	        vim.api.nvim_buf_set_lines(prompt_buf, 0, -1, false, { PROMPT_PREFIX .. query_text })
   805	        if vim.api.nvim_win_is_valid(prompt_win) then
   806	            vim.api.nvim_win_set_cursor(prompt_win, { 1, #PROMPT_PREFIX + query_cursor })
   807	        end
   808	    end
   809	
   810	    local function focus_prompt()
   811	        if closed or not vim.api.nvim_win_is_valid(prompt_win) then
   812	            return
   813	        end
   814	        vim.api.nvim_set_current_win(prompt_win)
   815	        vim.api.nvim_win_set_cursor(prompt_win, { 1, #PROMPT_PREFIX + query_cursor })
   816	        local mode = vim.api.nvim_get_mode().mode
   817	        if mode ~= "i" and mode ~= "ic" then
   818	            vim.cmd("startinsert!")
   819	        end
   820	    end
   821	
   822	    local function sync_query_from_prompt()
   823	        query_text = current_query_from_buffer()
   824	        on_query_change(query_text)
   825	        if vim.api.nvim_win_is_valid(prompt_win) then
   826	            local prompt_col = vim.api.nvim_win_get_cursor(prompt_win)[2] - #PROMPT_PREFIX
   827	            query_cursor = math.max(0, math.min(prompt_col, #query_text))
   828	        else
   829	            query_cursor = math.min(query_cursor, #query_text)
   830	        end
   831	    end
   832	
   833	    local function refresh_results()
   834	        vim.bo[results_buf].modifiable = true
   835	        local lines = {}
   836	        local total_rows = vim.api.nvim_win_is_valid(results_win) and vim.api.nvim_win_get_height(results_win) or win_h
   837	        if anchor == "top" then
   838	            for i = 1, #filtered do
   839	                table.insert(lines, truncate(" " .. filtered[i].display, win_w - 1))
   840	            end
   841	        else
   842	            for i = #filtered, 1, -1 do
   843	                table.insert(lines, truncate(" " .. filtered[i].display, win_w - 1))
   844	            end
   845	        end
   846	        if #lines == 0 then
   847	            lines = { "  (no matches)" }
   848	        end
   849	        while #lines < total_rows do
   850	            if anchor == "top" then
  1125	                    selected and selected.value or "nil",
  1126	                    tostring(#filtered)
  1127	                ))
  1128	            end
  1129	            initial_index = nil
  1130	        else
  1131	            local target_index = query == "" and math.max(1, math.min(sel_idx, #filtered)) or 1
  1132	            set_selection(target_index)
  1133	            if title:match("^Chat Files") then
  1134	                local selected = get_selected_item()
  1135	                logger.debug(string.format(
  1136	                    "float_picker chat trace: apply_filter default target_index=%s sel_idx=%s selected_value=%s filtered_count=%s query=%q initial_index=%s",
  1137	                    tostring(target_index),
  1138	                    tostring(sel_idx),
  1139	                    selected and selected.value or "nil",
  1140	                    tostring(#filtered),
  1141	                    query,
  1142	                    tostring(initial_index)
  1143	                ))
  1144	            end
  1145	        end
  1146	        highlight_matches(query)
  1147	    end
  1148	
  1149	    local function invoke_extra_mapping(fn)
  1150	        local context = {
  1151	            suspend_for_external_ui = suspend_for_external_ui,
  1152	            resume_after_external_ui = resume_after_external_ui,
  1153	            focus_prompt = focus_prompt,
  1154	            skip_focus_restore = false,
  1155	        }
  1156	        local selected = get_selected_item()
  1157	        if title:match("^Chat Files") then
  1158	            logger.debug(string.format(
  1159	                "float_picker chat trace: extra_mapping sel_idx=%s selected_value=%s filtered_count=%s query=%q",
  1160	                tostring(sel_idx),
  1161	                selected and selected.value or "nil",
  1162	                tostring(#filtered),
  1163	                query_text
  1164	            ))
  1165	        end
  1166	        fn(selected, close_all, context)
  1167	        return context
  1168	    end
  1169	
  1170	    render_prompt()
  1171	    render_tag_bar()
  1172	    apply_filter(true)
  1173	    on_query_change(query_text)
  1174	
  1175	    local function nmap_r(key, fn)
  1176	        vim.keymap.set("n", key, fn, {
  1177	            buffer = results_buf,
  1178	            noremap = true,
  1179	            silent = true,
  1180	            nowait = true,
  1181	        })
  1182	    end
  1183	
  1184	    local function nmap_p(key, fn)
  1185	        vim.keymap.set("n", key, fn, {
  1186	            buffer = prompt_buf,
  1187	            noremap = true,
  1188	            silent = true,
  1189	            nowait = true,
  1190	        })
   105	        it("labels the 2-state cycle issues → history", function()
   106	            assert.equals("issues", issue_finder.VIEW_LABELS[0])
   107	            assert.equals("history", issue_finder.VIEW_LABELS[1])
   108	            assert.is_nil(issue_finder.VIEW_LABELS[2])
   109	        end)
   110	    end)
   111	end)
   112	
   113	describe("IssueFinder query persistence", function()
   114	    local original_defer_fn
   115	    local original_scan_issues
   116	    local deferred
   117	    local fake
   118	    local picker_calls
   119	
   120	    local function cycle_view_mapping(opts)
   121	        for _, mapping in ipairs(opts.mappings) do
   122	            if mapping.key == "<Tab>" then
   123	                return mapping
   124	            end
   125	        end
   126	        error("missing <Tab> cycle-view mapping")
   127	    end
   128	
   129	    before_each(function()
   130	        deferred = {}
   131	        picker_calls = {}
   132	        fake = {
   133	            _issue_finder = { opened = false, view_mode = 0 },
   134	            config = {
   135	                issues_dir = "/unused/issues",
   136	                history_dir = "/unused/history",
   137	                issue_finder_mappings = {},
   138	            },
   139	            float_picker = {
   140	                open = function(opts)
   141	                    table.insert(picker_calls, opts)
   142	                end,
   143	            },
   144	            helpers = {},
   145	            logger = { warning = function() end },
   146	            cmd = {},
   147	            open_buf = function() end,
   148	        }
   149	
   150	        original_scan_issues = issues.scan_issues
   151	        issues.scan_issues = function(_, opts)
   152	            if opts.include_history then
   153	                return { {
   154	                    id = "000002",
   155	                    status = "done",
   156	                    title = "Archived",
   157	                    slug = "archived",
   158	                    path = "/tmp/archived.md",
   159	                    archived = true,
   160	                    mtime = 2,
   161	                    created = "",
   162	                } }
   163	            end
   164	            return { {
   165	                id = "000001",
   166	                status = "open",
   167	                title = "Active",
   168	                slug = "active",
   169	                path = "/tmp/active.md",
   170	                archived = false,
   171	                created = "",
   172	            } }
   173	        end
   174	
   175	        original_defer_fn = vim.defer_fn
   176	        vim.defer_fn = function(fn)
   177	            table.insert(deferred, fn)
   178	        end
   179	        fake.cmd.IssueFinder = function()
   180	            issue_finder.open()
   181	        end
   182	        issue_finder.setup(fake)
   183	    end)
   184	
   185	    after_each(function()
   186	        issues.scan_issues = original_scan_issues
   187	        vim.defer_fn = original_defer_fn
   188	        issue_finder.setup(parley)
   189	    end)
   190	
   191	    it("preserves the raw query after cancel and later invocation", function()
   192	        issue_finder.open()
   193	        picker_calls[1].on_query_change("  sticky {repo} query  ")
   194	        picker_calls[1].on_cancel()
   195	
   196	        issue_finder.open()
   197	
   198	        assert.equals("  sticky {repo} query  ", fake._issue_finder.query)
   199	        assert.equals("  sticky {repo} query  ", picker_calls[2].initial_query)
   200	    end)
   201	
   202	    it("preserves the query after selection and later invocation", function()
   203	        issue_finder.open()
   204	        picker_calls[1].on_query_change("needle")
   205	        picker_calls[1].on_select(picker_calls[1].items[1])
   206	
   207	        issue_finder.open()
   208	
   209	        assert.equals("needle", picker_calls[2].initial_query)
   210	    end)
   211	
   212	    it("persists a cleared query", function()
   213	        fake._issue_finder.query = "old query"
   214	        issue_finder.open()
   215	        picker_calls[1].on_query_change("")
   216	        picker_calls[1].on_cancel()
   217	
   218	        issue_finder.open()
   219	
   220	        assert.equals("", fake._issue_finder.query)
   221	        assert.equals("", picker_calls[2].initial_query)
   222	    end)
   223	
   224	    it("preserves the query through the view-cycle repaint", function()
   225	        issue_finder.open()
   226	        picker_calls[1].on_query_change("needle {repo}")
   227	        local closed = false
   228	
   229	        cycle_view_mapping(picker_calls[1]).fn(nil, function()
   230	            closed = true
   231	        end)
   232	
   233	        assert.is_true(closed)
   234	        assert.equals(1, #deferred)
   235	        deferred[1]()
   236	        assert.equals(2, #picker_calls)
   237	        assert.matches("history", picker_calls[2].title)
   238	        assert.equals("/tmp/archived.md", picker_calls[2].items[1].value)
   239	        assert.equals("needle {repo}", picker_calls[2].initial_query)
   240	    end)
   241	end)
3c42d84 issue: #177 preserve full finder query
 atlas/issues/issue-management.md                   |   2 +-
 atlas/modes/super_repo.md                          |  17 +--
 atlas/ui/pickers.md                                |   2 +-
 lua/parley/init.lua                                |   2 +-
 lua/parley/issue_finder.lua                        |   5 +-
 tests/unit/issue_finder_spec.lua                   | 131 +++++++++++++++++++++
 ...er-should-be-sticky-across-sort-order-change.md |  14 ++-
 ...ould-be-sticky-across-sort-order-change-plan.md |  20 ++--
 8 files changed, 167 insertions(+), 26 deletions(-)
0c6adba issue: #177 complete implementation plan
 ...ssue-finder-filter-should-be-sticky-across-sort-order-change-plan.md | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)
diff --git a/atlas/issues/issue-management.md b/atlas/issues/issue-management.md
index 310d9a1..1789362 100644
--- a/atlas/issues/issue-management.md
+++ b/atlas/issues/issue-management.md
@@ -17,7 +17,7 @@ default), so every reader derives from the one cue source.
 
 ## Commands
 - `:ParleyIssueNew` (`<C-y>c`): **delegates to `sdlc issue new`** (M3 #116) — the canonical creator (id allocation + the cue/sdlc-owned template + broadcast to origin/main per ariadne#82) — then opens the created file. The title prompt is prefixed with the destination repo — `[<repo>] Issue title: ` — where `<repo>` is the basename of the git root `issues_dir` resolves against (the editor's cwd root), so issues aren't created in the wrong repo (#142)
-- `:ParleyIssueFinder` (`<C-y>f`): float picker with status badges and 2-state view cycling — `<Tab>` (natural key; `<C-a>` kept for back-compat) toggles between `issues` (all of `workshop/issues/`, done items visible — the default, sorted by the existing status/ID order) and `history` (archived items in `workshop/history/`, sorted by file modification time ascending so the newest archive row sits closest to the bottom-anchored prompt) (#158, superseding the tri-state all/active/all+history from #152)
+- `:ParleyIssueFinder` (`<C-y>f`): float picker with status badges and 2-state view cycling — `<Tab>` (natural key; `<C-a>` kept for back-compat) toggles between `issues` (all of `workshop/issues/`, done items visible — the default, sorted by the existing status/ID order) and `history` (archived items in `workshop/history/`, sorted by file modification time ascending so the newest archive row sits closest to the bottom-anchored prompt) (#158, superseding the tri-state all/active/all+history from #152). The complete prompt query is kept verbatim across that repaint and later Issue Finder invocations; clearing the prompt persists the empty query (#177).
 - `:ParleyIssueNext` (`<C-y>x`): open next runnable issue (oldest open with all deps done)
 - `:ParleyIssueStatus` (`<C-y>s`): cycle frontmatter status using the first lifecycle transition for the current status in generated vocabulary order
 - `:ParleyIssueDecompose` (`<C-y>i`): create child issue from plan line, add to parent deps, and write a markdown link `[issue NNNNNN](./NNNNNN-slug.md)` into the parent's plan line; the new child file gets a `Parent: [issue PPPPPP](./PPPPPP-...md)` backlink under its title. (M3 #116: decompose **retains** parley's `render_issue_template` — its semantics, parent.deps += child + the parent plan-line link + the backlink, are incompatible with `sdlc issue new`'s shape, so unlike `:ParleyIssueNew` it is not delegated.)
diff --git a/atlas/modes/super_repo.md b/atlas/modes/super_repo.md
index 18a5ee3..3af8f72 100644
--- a/atlas/modes/super_repo.md
+++ b/atlas/modes/super_repo.md
@@ -47,12 +47,14 @@ were extended explicitly during M3-M5.
 
 ## Sticky `{repo}` filter
 
-Every super-repo-aware finder (chat, note, issue, vision, markdown) preserves
-`{repo}` filter fragments across reopens via `lua/parley/finder_sticky.lua`.
-Both completed (`{charon}`) and in-progress (`{char`) prompt fragments are
-extracted on every keystroke, normalised to the completed form, and re-seeded
-as `initial_query` next time. Chat finder additionally preserves `[tag]`
-fragments.
+Chat, note, vision, and markdown finders preserve `{repo}` filter fragments
+across reopens via `lua/parley/finder_sticky.lua`. Both completed (`{charon}`)
+and in-progress (`{char`) prompt fragments are extracted on every keystroke,
+normalised to the completed form, and re-seeded as `initial_query` next time.
+Chat finder additionally preserves `[tag]` fragments. Issue Finder is the
+intentional exception: it preserves the complete opaque query, including plain
+text, so the same filter survives view-cycle repaint and later invocations
+(#177).
 
 Matching is also forgiving of in-progress brackets: `{char` matches the same
 items as `{charon}` would (prefix match against the haystack `{repo}` token),
@@ -90,7 +92,8 @@ filter for plain repo mode's primary note root.
 - `lua/parley/issue_finder.lua`, `vision_finder.lua`, `markdown_finder.lua`
   — multi-root aggregation when `super_repo_members` is non-empty.
 - `lua/parley/finder_sticky.lua` — shared `{root}` / `[tag]` extraction and
-  initial-query formatter used by every finder for sticky filters.
+  initial-query formatter used by chat, note, vision, and markdown finders;
+  Issue Finder owns its distinct full-query persistence policy.
 - `lua/parley/lualine.lua` — `format_mode`, `create_mode_component`, and
   the filetype-component auto-replace at setup time.
 - `lua/parley/keybinding_registry.lua` — `super_repo_toggle` entry.
diff --git a/atlas/ui/pickers.md b/atlas/ui/pickers.md
index dd57870..05a422d 100644
--- a/atlas/ui/pickers.md
+++ b/atlas/ui/pickers.md
@@ -9,7 +9,7 @@ Up/down arrow keys wrap around at list boundaries (top wraps to bottom, bottom w
 AND-matching across whitespace-split tokens. Token-prefix scoring, bounded edit-distance typo tolerance, subsequence fallback. `{root}` / `[tag]` query tokens scope to bracketed haystack labels of the same kind; in-progress forms (`{char`, `[bu`) work the same way as their completed counterparts.
 
 ## Sticky Query
-`lua/parley/finder_sticky.lua` extracts `{root}` (and `[tag]` for chat finder) fragments from the prompt on every keystroke and re-seeds them on the next reopen. Plain text is intentionally not preserved. Wired into chat, note, issue, vision, and markdown finders.
+`lua/parley/finder_sticky.lua` extracts `{root}` (and `[tag]` for chat finder) fragments from the prompt on every keystroke and re-seeds them on the next reopen. Plain text is intentionally not preserved in chat, note, vision, and markdown finders. Issue Finder is the deliberate exception: it stores the complete opaque prompt query so plain text and structured filters survive both view-cycle repaint and later invocations (#177).
 
 The chat finder additionally pre-seeds `{}` (the primary chat root, which in repo mode is the repo chat root) on the first open of a parley session in plain repo mode, so the default view is scoped to repo chats and global chats are filtered out. The pre-seed is a one-shot — once the user clears or modifies the filter, sticky-query takes over and the default is never re-applied. Skipped in super-repo mode (whose whole point is aggregating siblings, which a `{}` narrowing would defeat).
 
diff --git a/workshop/issues/000177-issue-finder-filter-should-be-sticky-across-sort-order-change.md b/workshop/issues/000177-issue-finder-filter-should-be-sticky-across-sort-order-change.md
index 485fafd..6cf0c0a 100644
--- a/workshop/issues/000177-issue-finder-filter-should-be-sticky-across-sort-order-change.md
+++ b/workshop/issues/000177-issue-finder-filter-should-be-sticky-across-sort-order-change.md
@@ -57,11 +57,11 @@ total: 0.98
 
 ## Plan
 
-- [ ] Add failing coverage for raw full-query capture/restoration, clearing,
+- [x] Add failing coverage for raw full-query capture/restoration, clearing,
   later invocation, and view-cycle repaint.
-- [ ] Replace Issue Finder's structured-only query extraction with direct opaque
+- [x] Replace Issue Finder's structured-only query extraction with direct opaque
   query state; keep other finders unchanged.
-- [ ] Run focused and full verification, reconcile documentation, and close #177.
+- [x] Run focused and full verification, reconcile documentation, and close #177.
 
 Durable implementation plan:
 `workshop/plans/000177-issue-finder-filter-should-be-sticky-across-sort-order-change-plan.md`.
@@ -69,3 +69,11 @@ Durable implementation plan:
 ## Log
 
 ### 2026-07-08
+
+### 2026-07-10 — complete query persistence implemented
+
+Issue Finder now owns one opaque full-query state value and passes it unchanged
+through `float_picker`'s existing capture/restore seam. TDD covered cancel,
+selection, clearing, and view-cycle repaint; the mapped issue suite and full
+`make test` passed. Updated all known atlas persistence-policy consumers
+(`ARCH-DRY`, `ARCH-PURE`, `ARCH-PURPOSE`).

exec
/bin/zsh -lc "sed -n '1,240p' TOOLING.md && make test-spec SPEC=issues/issue-management" in /Users/xianxu/workspace/parley.nvim
 succeeded in 674ms:
[32mSuccess[0m	||	IssueFinder view-mode logic includes_history only view 1 (history) scans archived history	
[32mSuccess[0m	||	IssueFinder view-mode logic filter_for_view view 0 (issues) keeps non-archived items (incl. done-not-archived)	
[32mSuccess[0m	||	IssueFinder view-mode logic filter_for_view view 1 (history) keeps only archived items	
[32mSuccess[0m	||	IssueFinder view-mode logic filter_for_view treats a nil archived flag as non-archived (shows in issues, not history)	
[32mSuccess[0m	||	IssueFinder view-mode logic filter_for_view does not mutate the input list	
[32mSuccess[0m	||	IssueFinder view-mode logic sort_for_view keeps issues view on status/ID ordering	
[32mSuccess[0m	||	IssueFinder view-mode logic sort_for_view sorts history view by mtime ascending so newest is last	
[32mSuccess[0m	||	IssueFinder view-mode logic sort_for_view uses ID as the deterministic history tie-breaker	
[32mSuccess[0m	||	IssueFinder view-mode logic VIEW_LABELS labels the 2-state cycle issues → history	
[32mSuccess[0m	||	IssueFinder query persistence preserves the raw query after cancel and later invocation	
[32mSuccess[0m	||	IssueFinder query persistence preserves the query after selection and later invocation	
[32mSuccess[0m	||	IssueFinder query persistence persists a cleared query	
[32mSuccess[0m	||	IssueFinder query persistence preserves the query through the view-cycle repaint	
	
[32mSuccess: [0m	13	
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

exec
/bin/zsh -lc 'make test' in /Users/xianxu/workspace/parley.nvim
codex
The mapped issue-management suite is green (124 assertions across the mapped specs, including all four new persistence cases). The real picker synchronizes its prompt into `on_query_change` on edits and also on initial render, so the direct state seam is consistent with runtime behavior; I’m finishing the full lint/unit/integration/architecture run now.
 succeeded in 17722ms:
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
PASS: tests/unit/discovery_merge_spec.lua
PASS: tests/unit/discovery_registry_spec.lua
PASS: tests/unit/chat_slug_resolve_spec.lua
PASS: tests/unit/dispatcher_query_spec.lua
PASS: tests/unit/drill_in_spec.lua
PASS: tests/unit/exchange_clipboard_spec.lua
PASS: tests/unit/exchange_model_spec.lua
PASS: tests/unit/dispatcher_spec.lua
PASS: tests/unit/exporter_tree_spec.lua
PASS: tests/unit/finder_sticky_spec.lua
PASS: tests/unit/file_tracker_spec.lua
PASS: tests/unit/get_week_number_spec.lua
PASS: tests/unit/helper_spec.lua
PASS: tests/unit/float_picker_spec.lua
PASS: tests/unit/helper_io_spec.lua
PASS: tests/unit/highlighter_spec.lua
PASS: tests/unit/inline_branch_spec.lua
PASS: tests/unit/issue_vocabulary_spec.lua
PASS: tests/unit/log_emit_spec.lua
PASS: tests/unit/issue_finder_spec.lua
PASS: tests/unit/logger_spec.lua
PASS: tests/unit/markdown_draft_block_spec.lua
PASS: tests/unit/memory_prefs_spec.lua
PASS: tests/unit/issues_spec.lua
PASS: tests/unit/neighborhood_spec.lua
PASS: tests/unit/config_tools_spec.lua
PASS: tests/unit/obfuscate_spec.lua
PASS: tests/unit/oauth_spec.lua
PASS: tests/unit/outline_spec.lua
PASS: tests/unit/note_finder_logic_spec.lua
PASS: tests/unit/open_chat_reference_spec.lua
PASS: tests/unit/parse_chat_spec.lua
PASS: tests/unit/parley_harness_golden_spec.lua
PASS: tests/unit/picker_items_spec.lua
PASS: tests/unit/process_directory_pattern_spec.lua
PASS: tests/unit/parley_harness_spec.lua
PASS: tests/unit/parse_at_reference_spec.lua
PASS: tests/unit/progress_spec.lua
PASS: tests/unit/provider_params_spec.lua
PASS: tests/unit/providers_pre_query_spec.lua
PASS: tests/unit/raw_log_spec.lua
PASS: tests/unit/keybindings_spec.lua
PASS: tests/unit/render_buffer_spec.lua
PASS: tests/unit/render_spec.lua
PASS: tests/unit/pure_functions_spec.lua
PASS: tests/unit/render_buffer_roundtrip_spec.lua
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
PASS: tests/integration/export_spec.lua
PASS: tests/integration/cliproxy_dispatch_spec.lua
PASS: tests/integration/progress_spec.lua
PASS: tests/integration/neighborhood_completion_spec.lua
PASS: tests/integration/new_chat_spec.lua
PASS: tests/integration/not_chat_spec.lua
PASS: tests/integration/review_diag_display_spec.lua
PASS: tests/integration/review_journal_io_spec.lua
PASS: tests/integration/review_menu_spec.lua
PASS: tests/integration/review_mode_load_spec.lua
PASS: tests/integration/review_projection_spec.lua
PASS: tests/integration/skill_invoke_review_spec.lua
PASS: tests/integration/skill_registry_spec.lua
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
verdict: SHIP
confidence: high
```

The change fulfills #177’s Spec and Plan with a minimal, well-tested integration change. Complete Issue Finder queries—including whitespace, plain text, structured filters, and empty strings—are preserved across view repaint and later invocation. No blocking or non-blocking findings.

1. Strengths

- [issue_finder.lua:251](/Users/xianxu/workspace/parley.nvim/lua/parley/issue_finder.lua:251) passes the opaque query directly through the existing picker boundary without parsing or normalization.
- [issue_finder.lua:253](/Users/xianxu/workspace/parley.nvim/lua/parley/issue_finder.lua:253) captures every picker query update, including clearing to `""`.
- [issue_finder_spec.lua:191](/Users/xianxu/workspace/parley.nvim/tests/unit/issue_finder_spec.lua:191) covers exact raw restoration, cancel, selection, clearing, and deferred view cycling through the real `issue_finder.open` orchestration.
- Atlas documentation accurately records Issue Finder’s deliberate exception to the shared structured-filter policy.
- The Core concepts integration entity exists at both stated paths and matches its documented modified status.

2. Critical findings

None.

3. Important findings

None.

4. Minor findings

None.

5. Test coverage notes

- `make test-spec SPEC=issues/issue-management`: passed, including all 13 Issue Finder tests and 124 total mapped assertions.
- `make test`: passed with exit code 0.
- Lint: 244 files, 0 warnings and 0 errors.
- Full unit, integration, and architecture suites passed.
- `git diff --check 7bcf135..HEAD`: clean.
- Tests appropriately fake scanning, picker IO, and deferred timing while exercising the real orchestration. No PURE entity was claimed, so the Core concepts PURE constraint is not applicable.

6. Architectural notes for upcoming work

- `ARCH-DRY`: Pass. Issue Finder retains its distinct full-query policy without duplicating `finder_sticky`’s structured extraction behavior.
- `ARCH-PURE`: Pass. State capture/restore remains thin UI glue; filtering stays within `float_picker`.
- `ARCH-PURPOSE`: Pass. The entire committed purpose is delivered across every relevant consumer: initialization, capture, later invocation, view-cycle repaint, tests, and atlas documentation.
- No new user command, flag, keybinding, configuration key, or usage step was introduced, so no README update is required.

7. Plan revision recommendations

None. The plan and Core concepts table remain consistent with the implementation.
tokens used
60,749
```verdict
verdict: SHIP
confidence: high
```

The change fulfills #177’s Spec and Plan with a minimal, well-tested integration change. Complete Issue Finder queries—including whitespace, plain text, structured filters, and empty strings—are preserved across view repaint and later invocation. No blocking or non-blocking findings.

1. Strengths

- [issue_finder.lua:251](/Users/xianxu/workspace/parley.nvim/lua/parley/issue_finder.lua:251) passes the opaque query directly through the existing picker boundary without parsing or normalization.
- [issue_finder.lua:253](/Users/xianxu/workspace/parley.nvim/lua/parley/issue_finder.lua:253) captures every picker query update, including clearing to `""`.
- [issue_finder_spec.lua:191](/Users/xianxu/workspace/parley.nvim/tests/unit/issue_finder_spec.lua:191) covers exact raw restoration, cancel, selection, clearing, and deferred view cycling through the real `issue_finder.open` orchestration.
- Atlas documentation accurately records Issue Finder’s deliberate exception to the shared structured-filter policy.
- The Core concepts integration entity exists at both stated paths and matches its documented modified status.

2. Critical findings

None.

3. Important findings

None.

4. Minor findings

None.

5. Test coverage notes

- `make test-spec SPEC=issues/issue-management`: passed, including all 13 Issue Finder tests and 124 total mapped assertions.
- `make test`: passed with exit code 0.
- Lint: 244 files, 0 warnings and 0 errors.
- Full unit, integration, and architecture suites passed.
- `git diff --check 7bcf135..HEAD`: clean.
- Tests appropriately fake scanning, picker IO, and deferred timing while exercising the real orchestration. No PURE entity was claimed, so the Core concepts PURE constraint is not applicable.

6. Architectural notes for upcoming work

- `ARCH-DRY`: Pass. Issue Finder retains its distinct full-query policy without duplicating `finder_sticky`’s structured extraction behavior.
- `ARCH-PURE`: Pass. State capture/restore remains thin UI glue; filtering stays within `float_picker`.
- `ARCH-PURPOSE`: Pass. The entire committed purpose is delivered across every relevant consumer: initialization, capture, later invocation, view-cycle repaint, tests, and atlas documentation.
- No new user command, flag, keybinding, configuration key, or usage step was introduced, so no README update is required.

7. Plan revision recommendations

None. The plan and Core concepts table remain consistent with the implementation.
