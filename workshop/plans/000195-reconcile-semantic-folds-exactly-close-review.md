# Boundary Review — parley.nvim#195 (whole-issue close)

| field | value |
|-------|-------|
| issue | 195 — Reconcile semantic folds exactly |
| repo | parley.nvim |
| issue file | workshop/issues/000195-reconcile-semantic-folds-exactly.md |
| boundary | whole-issue close |
| milestone | — |
| window | 3974fa25cec1aa5a0f1624297d69bee8529a0e4e..HEAD |
| command | sdlc close --issue 195 |
| reviewer | codex |
| timestamp | 2026-07-18T20:57:15-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Reading additional input from stdin...
OpenAI Codex v0.144.6
--------
workdir: /Users/xianxu/workspace/parley.nvim
model: gpt-5.5
provider: openai
approval: never
sandbox: workspace-write [workdir, /tmp, $TMPDIR, /tmp] (network access enabled)
reasoning effort: medium
reasoning summaries: none
session id: 019f7882-dbea-7921-9663-dca1e880ecb1
--------
user
# Code review — the one SDLC boundary review

You are conducting a fresh-context code review at a development boundary —
whole-issue close — in the **parley.nvim** repository.

- repository: parley.nvim   (root: /Users/xianxu/workspace/parley.nvim)
- issue:      parley.nvim#195   (file: workshop/issues/000195-reconcile-semantic-folds-exactly.md)
- window:     Base: 3974fa25cec1aa5a0f1624297d69bee8529a0e4e   Head: HEAD

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
diff --git a/atlas/chat/exchange_model.md b/atlas/chat/exchange_model.md
index d5d9b66..57ad9b1 100644
--- a/atlas/chat/exchange_model.md
+++ b/atlas/chat/exchange_model.md
@@ -4,13 +4,17 @@ The exchange model (`lua/parley/exchange_model.lua`) is the single source of tru

 ## Core Principle: Everything Is a Block

-An exchange is a flat list of blocks. Each block has a `kind` and `size` (line count). Positions are computed on demand from accumulated sizes. No absolute line numbers are stored.
+An exchange is a flat list of blocks. Each block has a `kind`, `size` (line
+count), and an intra-exchange `gap_before`; the exchange owns the leading gap
+before its question. Positions are computed on demand from accumulated sizes
+and gaps. Absolute line numbers are not retained after parser spans have been
+compiled into this relative layout.

 ```
 Exchange = {
     blocks = {
-        { kind = "question",      size = 1 },   -- 💬:
-        { kind = "agent_header",  size = 1 },   -- 🤖:
+        { kind = "question",      size = 1, gap_before = 0 }, -- 💬:
+        { kind = "agent_header",  size = 1, gap_before = 1 }, -- 🤖:
         { kind = "thinking",      size = 2 },   -- 🧠: semantic block
         { kind = "text",          size = 5 },   -- ordinary response text
         { kind = "tool_use",      size = 4 },   -- 🔧: + json fence
@@ -23,10 +27,13 @@ Exchange = {

 ## Layout Rules

-1. **1 blank margin** between adjacent non-empty blocks.
-2. **Empty blocks (size 0) cancel one margin** — invisible in layout.
-3. **1 blank margin** between exchanges.
-4. **Header** occupies `header_lines` at the top, followed by 1 margin.
+1. Existing chats preserve the zero-, one-, or multi-line gaps implied by
+   parser item spans; new live blocks default to one blank margin.
+2. The exchange exclusively owns its leading gap. The question block owns no
+   duplicate gap; later blocks own only intra-exchange gaps.
+3. Empty blocks contribute neither size nor gap and remain invisible.
+4. `exchange_total_size` excludes the exchange leading gap;
+   `exchange_start` adds each leading gap exactly once.

 ## Lifecycle

@@ -40,9 +47,8 @@ The model is built once per `M.respond` call and lives through the entire respon
 - **Spinner**: tracked as a block; set to size 0 when cleared.
 - **Prompt append**: uses `exchange_total_size` to compute insertion point.
 - **Folding**: `thinking`, `summary`, `tool_use`, and `tool_result` ranges come
-  only from the model. Neovim shrinks a manual fold when its streaming tail is
-  replaced, so Parley recreates only that active foldable range; ordinary text
-  performs no fold command.
+  only from their stated model block spans and stay inside the selected
+  exchange. Gaps are never projected as folds.

 Because the model is live state, `chat_respond` protects every pending async write with a chat lease anchored on an `invalidate=true` extmark on the response's agent-header line (#138). The anchor distinguishes Parley-owned writes from structural edits: streaming and ordinary edits move the anchor (valid), while deleting the header — undo/redo or other structural drift — invalidates the pending response instead of reconciling the model against a changed serialized transcript. (Pre-#138 the lease keyed on `changedtick` and committed each Parley write's new tick; the extmark anchor makes that commit unnecessary.)

@@ -50,14 +56,17 @@ Because the model is live state, `chat_respond` protects every pending async wri

 `from_parsed_chat(parsed_chat)` builds a model from parser output. The shared
 `answer_structure` reducer supplies semantic answer spans; the parser trims
-leading/trailing blank lines so model margins remain the source of truth.
+leading/trailing blank lines from item content, while adjacent absolute spans
+compile into relative gaps. Historical chats do not need canonical spacing.
+Streaming performs the same compilation from its bounded active-segment
+sections when replacing the insertion span.

 ## API

 | Method | Purpose |
 |--------|---------|
-| `add_exchange(q_size)` | Add exchange with question block |
-| `add_block(k, kind, size)` | Append block to exchange k |
+| `add_exchange(q_size, gap?)` | Add exchange with question block |
+| `add_block(k, kind, size, gap?)` | Append block to exchange k |
 | `grow_block(k, b, delta)` | Streaming grew the block |
 | `set_block_size(k, b, size)` | Set exact size (e.g., spinner → 0) |
 | `remove_block(k, b)` | Remove a block |
diff --git a/atlas/chat/lifecycle.md b/atlas/chat/lifecycle.md
index dd4ff11..5bd1988 100644
--- a/atlas/chat/lifecycle.md
+++ b/atlas/chat/lifecycle.md
@@ -20,12 +20,28 @@ registry.
 ## Response (`:ParleyChatRespond` / `<C-g><C-g>`)
 Assembles context (with memory summarization), streams LLM response into buffer. The [exchange model](exchange_model.md) is the single source of truth for all transcript mutations during the response lifecycle — streaming text growth, tool block insertion, and prompt append all go through the model. [Response progress](response_progress.md) is cosmetic extmark state that begins at the response header (or a recursive leg's last visible block), then follows the current generation tip; it never becomes a model block. A per-buffer pending-session guard prevents duplicate calls.

-Streaming fold maintenance is insertion-scoped. After each write, Parley reduces
-only the active insertion block, updates its semantic model span, and recreates
-the fold only for foldable kinds. A late explicit thinking terminator may widen
-that bounded read to its recorded provisional opener. Tool calls/results fold
-immediately from their known appended block indices. Success and cancellation
-use the live model; there is no final whole-chat fold reparse.
+Semantic folds are a pure projection of one exchange's positive-size thinking,
+summary, tool-use, and tool-result blocks (`lua/parley/fold_projection.lua`).
+Streaming still reduces only the active insertion span; a late explicit
+thinking terminator may widen that bounded read to its recorded provisional
+opener. Before a known exchange mutation, Parley removes that exchange's old
+projected folds in every window showing the buffer; afterward it creates the
+updated projection in those same windows. Tool-loop appends use the same
+transaction. Unchanged exchanges receive no fold commands, unrelated user folds
+remain untouched during live reconciliation.
+
+Initial setup and window-entry events parse once and hydrate every exchange in
+the entering window. Hydration first clears restored/manual fold state in that
+window, then renders the complete semantic projection. This makes initial fold
+state a pure function of the parsed exchange model: stale blank-line folds and
+a live transaction that beats scheduled hydration cannot survive as duplicate
+nesting. Fold ranges
+come only from item bounds; inter-item and inter-exchange gaps are never fold
+targets. A lightweight `(buffer, window)` initialization registry
+prevents duplicate manual folds and is cleared with window/buffer teardown.
+Successful live transactions use the current model without reparsing; failure
+recovery reparses only to restore prepared folds while preserving the original
+error.

 Inline-comment submission follows the same preservation boundary. Drill-in
 marker/anchor transformations are planned as original-coordinate byte edits and
diff --git a/atlas/traceability.yaml b/atlas/traceability.yaml
index a10d8ae..6ac43ac 100644
--- a/atlas/traceability.yaml
+++ b/atlas/traceability.yaml
@@ -110,11 +110,17 @@ atlas:
       - lua/parley/exchange_model.lua
       - lua/parley/buffer_edit.lua
       - lua/parley/render_buffer.lua
+      - lua/parley/fold_projection.lua
       - lua/parley/tool_folds.lua
+      - lua/parley/tool_loop.lua
+      - lua/parley/dispatcher.lua
     tests:
       - tests/unit/answer_structure_spec.lua
       - tests/unit/tool_folds_spec.lua
+      - tests/unit/fold_projection_spec.lua
       - tests/integration/tool_folds_spec.lua
+      - tests/integration/create_handler_spec.lua
+      - tests/integration/chat_respond_spec.lua
       - tests/unit/exchange_model_spec.lua
       - tests/unit/buffer_edit_spec.lua
       - tests/unit/render_buffer_spec.lua
diff --git a/lua/parley/artifact_ref.lua b/lua/parley/artifact_ref.lua
index 1f028d9..1109bdf 100644
--- a/lua/parley/artifact_ref.lua
+++ b/lua/parley/artifact_ref.lua
@@ -79,6 +79,26 @@ function M.parse_ref_at_cursor(line, col)
     return nil
 end

+-- ref_from_issue_path(path) -> "repo#id" | nil. Derives the issue ref a
+-- buffer's FILE denotes: <repo>/workshop/issues/NNNNNN-*.md (active) or
+-- <repo>/workshop/history/issues/NNNNNN-*.md (archived) yield "repo#id" with
+-- leading zeros stripped. Any other path yields nil. Pure (string → string).
+-- Used as the gP buffer fallback: inside an issue file, "this issue" is a
+-- meaningful ref even when the cursor isn't on one (ariadne#171 follow-up).
+function M.ref_from_issue_path(path)
+    if not path or path == "" then
+        return nil
+    end
+    local repo, id = path:match("([^/]+)/workshop/issues/0*(%d+)[^/]*%.md$")
+    if not repo then
+        repo, id = path:match("([^/]+)/workshop/history/issues/0*(%d+)[^/]*%.md$")
+    end
+    if not repo then
+        return nil
+    end
+    return repo .. "#" .. id
+end
+
 -- parse_resolve_output(stdout, is_json) -> { {path, kind?, milestone?}, ... }.
 -- JSON: reads `.files[]`; a github label resolves to {} (empty). Plain: one
 -- absolute path per non-empty line.
@@ -186,12 +206,22 @@ end
 -- opts.kind (optional): resolve kind, e.g. "project" — the always-cross-repo
 -- project class (ariadne#171 M4): jumps to the project record(s) referencing
 -- the issue under the cursor, wherever in the fleet they live.
+-- opts.buffer_fallback (optional): when the cursor is NOT on a ref but the
+-- buffer's file is itself an issue file, use that file's own ref
+-- (ref_from_issue_path) — so gP anywhere in an issue file jumps to the
+-- project(s) tracking it. A ref under the cursor always wins.
 -- Delegated to by parley init's M.cmd.ResolveRef* commands.
 function M.goto_ref_at_cursor(opts)
     opts = opts or {}
     local line = vim.api.nvim_get_current_line()
     local col = vim.api.nvim_win_get_cursor(0)[2] + 1 -- 1-indexed byte col
     local hit = M.parse_ref_at_cursor(line, col)
+    if not hit and opts.buffer_fallback then
+        local ref = M.ref_from_issue_path(vim.api.nvim_buf_get_name(0))
+        if ref then
+            hit = { ref = ref, buffer_derived = true }
+        end
+    end
     if not hit then
         if opts.on_no_ref then
             opts.on_no_ref()
diff --git a/lua/parley/chat_respond.lua b/lua/parley/chat_respond.lua
index 8c236cb..a63baea 100644
--- a/lua/parley/chat_respond.lua
+++ b/lua/parley/chat_respond.lua
@@ -1679,11 +1679,16 @@ M.respond = function(params, callback, override_free_cursor, force, live_model,
             end
             local reduced = require("parley.answer_structure").reduce(current_lines, patterns, { streaming = true })
             local replacements = {}
+            local previous_end_0 = first_block > 1 and model:block_end(target_idx, first_block - 1) or nil
             for _, section in ipairs(reduced.sections) do
+                local section_start_0 = first_line + section.line_start - 1
+                local section_end_0 = first_line + section.line_end - 1
                 replacements[#replacements + 1] = {
                     kind = section.kind,
                     size = section.line_end - section.line_start + 1,
+                    gap_before = previous_end_0 and (section_start_0 - previous_end_0 - 1) or 0,
                 }
+                previous_end_0 = section_end_0
             end
             if #replacements == 0 then return end
             local old_count = stream_block_idx - first_block + 1
@@ -1695,10 +1700,6 @@ M.respond = function(params, callback, override_free_cursor, force, live_model,
                 and replacements[#replacements].kind == "text" then
                 provisional_thinking_idx = changed[#changed - 1]
             end
-            local fold = require("parley.tool_folds")
-            for _, block_index in ipairs(changed) do
-                fold._apply_block_fold(buf, win, model, target_idx, block_index)
-            end
         end
         local base_handler = _parley.dispatcher.create_handler(buf, win, response_start_line, true, "", function()
             return is_follow_cursor_enabled(override_free_cursor)
@@ -1714,6 +1715,10 @@ M.respond = function(params, callback, override_free_cursor, force, live_model,
                 pending_session:tip_written(last_written_line_0)
                 lease_commit()
             end,
+            around_write = function(_qid, _chunk, write)
+                return require("parley.tool_folds").with_exchange_update(
+                    buf, model, target_idx, write)
+            end,
         })
         local response_handler = function(qid, chunk) pending_session:content(qid, chunk) end

diff --git a/lua/parley/dispatcher.lua b/lua/parley/dispatcher.lua
index 63d506b..6448bea 100644
--- a/lua/parley/dispatcher.lua
+++ b/lua/parley/dispatcher.lua
@@ -540,6 +540,7 @@ D.create_handler = function(buf, win, line, first_undojoin, prefix, cursor, on_l
 		if opts.before_write and not opts.before_write(qid, chunk) then
 			return
 		end
+		local function write()
 		-- undojoin takes previous change into account, so skip it for the first chunk
 		if skip_first_undojoin then
 			skip_first_undojoin = false
@@ -598,6 +599,12 @@ D.create_handler = function(buf, win, line, first_undojoin, prefix, cursor, on_l
 		if should_move_cursor then
 			helpers.cursor_to_line(end_line, buf, win)
 		end
+		end
+		if opts.around_write then
+			opts.around_write(qid, chunk, write)
+		else
+			write()
+		end
 	end)
 end

diff --git a/lua/parley/exchange_model.lua b/lua/parley/exchange_model.lua
index 6c8e52a..fa2f3f2 100644
--- a/lua/parley/exchange_model.lua
+++ b/lua/parley/exchange_model.lua
@@ -8,15 +8,16 @@
 -- of exchange K live in the buffer?" Callers mutate the model (add
 -- blocks, grow blocks) and the model recomputes positions on demand
 -- from accumulated sizes. No absolute line numbers are ever stored —
--- only sizes.
+-- sizes and the gaps recorded before visible items.
 --
 -- See #90 design: size-based architecture.
 --
 -- Rules:
 --   1. Everything is a block (question, agent_header, text, tool_use,
 --      tool_result, spinner, thinking, note, ...).
---   2. 1 blank margin line between adjacent non-empty blocks.
---   3. Empty block (size 0) cancels one margin — effectively invisible.
+--   2. Parsed blocks preserve their actual preceding gaps; new blocks default
+--      to one blank line.
+--   3. Empty blocks contribute neither content nor gap.
 --
 -- Layout convention:
 --   HEADER (header_lines lines)
@@ -62,10 +63,11 @@ end

 --- Add an exchange. The question is block 1 (always present).
 --- @param question_size integer  number of lines the question occupies
-function Model:add_exchange(question_size)
+function Model:add_exchange(question_size, gap_before)
     table.insert(self.exchanges, {
+        gap_before = gap_before == nil and MARGIN or gap_before,
         blocks = {
-            { kind = "question", size = question_size },
+            { kind = "question", size = question_size, gap_before = 0 },
         },
     })
 end
@@ -76,11 +78,12 @@ end
 --- @param kind string  block kind (agent_header/text/tool_use/tool_result/spinner/...)
 --- @param size integer  number of lines the block occupies
 --- @return integer  0-indexed insert position
-function Model:add_block(k, kind, size)
+function Model:add_block(k, kind, size, gap_before)
     local pos = self:append_pos(k)
     table.insert(self.exchanges[k].blocks, {
         kind = kind,
         size = size,
+        gap_before = gap_before == nil and MARGIN or gap_before,
     })
     return pos
 end
@@ -118,12 +121,23 @@ function Model:replace_span(k, first_block, old_count, sections)
     for _, section in ipairs(sections) do
         assert(type(section.kind) == "string" and type(section.size) == "number" and section.size >= 0,
             "invalid replacement section")
+        assert(section.gap_before == nil or (type(section.gap_before) == "number" and section.gap_before >= 0),
+            "invalid replacement gap")
     end
+    local inherited_gap = exchange.blocks[first_block] and exchange.blocks[first_block].gap_before or MARGIN
     for _ = 1, old_count do table.remove(exchange.blocks, first_block) end
     local changed = {}
     for offset, section in ipairs(sections) do
         local index = first_block + offset - 1
-        table.insert(exchange.blocks, index, { kind = section.kind, size = section.size })
+        local gap_before = section.gap_before
+        if gap_before == nil then
+            gap_before = offset == 1 and inherited_gap or MARGIN
+        end
+        table.insert(exchange.blocks, index, {
+            kind = section.kind,
+            size = section.size,
+            gap_before = gap_before,
+        })
         changed[#changed + 1] = index
     end
     return changed
@@ -140,9 +154,7 @@ function Model:exchange_total_size(k)
     local has_prev = false
     for _, blk in ipairs(self.exchanges[k].blocks) do
         if blk.size > 0 then
-            if has_prev then
-                size = size + MARGIN
-            end
+            if has_prev then size = size + (blk.gap_before or MARGIN) end
             size = size + blk.size
             has_prev = true
         end
@@ -153,12 +165,12 @@ end
 --- 0-indexed buffer line where exchange K starts (= where its first
 --- non-empty block starts).
 function Model:exchange_start(k)
-    local line = self.header_lines + MARGIN  -- after header + 1 margin
-    for i = 1, k - 1 do
+    local line = self.header_lines
+    for i = 1, k do
+        line = line + (self.exchanges[i].gap_before or MARGIN)
+        if i == k then return line end
         line = line + self:exchange_total_size(i)
-        line = line + MARGIN  -- margin between exchanges
     end
-    return line
 end

 --- 0-indexed buffer line where block B of exchange K starts.
@@ -168,23 +180,13 @@ function Model:block_start(k, b)
     local has_prev = false
     for i = 1, b do
         local blk = self.exchanges[k].blocks[i]
-        if i == b then
-            -- Margin before this block if there's preceding content
-            if has_prev and blk.size > 0 then
-                line = line + MARGIN
-            elseif has_prev then
-                -- Block is empty — position it where it would be
-                -- (after the margin), but it occupies 0 lines.
-                line = line + MARGIN
-            end
-            return line
-        end
         if blk.size > 0 then
-            if has_prev then
-                line = line + MARGIN
-            end
+            if has_prev then line = line + (blk.gap_before or MARGIN) end
+            if i == b then return line end
             line = line + blk.size
             has_prev = true
+        elseif i == b then
+            return line
         end
     end
     return line
@@ -273,24 +275,46 @@ end
 function M.from_parsed_chat(parsed_chat)
     local header_lines = parsed_chat.header_end or 0
     local model = M.new(header_lines)
+    local previous_exchange_end
     for _, ex in ipairs(parsed_chat.exchanges or {}) do
         local q_size = 1
+        local question_start = ex.question and ex.question.line_start or (header_lines + MARGIN + 1)
+        local question_end = question_start + q_size - 1
         if ex.question then
             q_size = ex.question.line_end - ex.question.line_start + 1
+            question_end = ex.question.line_end
+        end
+        local gap_before
+        if previous_exchange_end then
+            gap_before = question_start - previous_exchange_end - 1
+        else
+            gap_before = question_start - header_lines - 1
         end
-        model:add_exchange(q_size)
+        assert(gap_before >= 0, "overlapping exchange spans")
+        model:add_exchange(q_size, gap_before)
+        local previous_block_end = question_end
         if ex.answer then
             local k = #model.exchanges
             -- Agent header is the first answer block (🤖: line, 1 line)
-            model:add_block(k, "agent_header", 1)
+            local answer_start = ex.answer.line_start
+            local answer_gap = answer_start - previous_block_end - 1
+            assert(answer_gap >= 0, "overlapping answer spans")
+            model:add_block(k, "agent_header", 1, answer_gap)
+            previous_block_end = answer_start
             for _, sec in ipairs(ex.answer.semantic_sections or ex.answer.sections or {}) do
                 local sec_size = 1
                 if sec.line_start and sec.line_end then
                     sec_size = sec.line_end - sec.line_start + 1
                 end
-                model:add_block(k, sec.kind or sec.type or "text", sec_size)
+                local section_start = sec.line_start or (previous_block_end + MARGIN + 1)
+                local section_end = sec.line_end or (section_start + sec_size - 1)
+                local section_gap = section_start - previous_block_end - 1
+                assert(section_gap >= 0, "overlapping answer section spans")
+                model:add_block(k, sec.kind or sec.type or "text", sec_size, section_gap)
+                previous_block_end = section_end
             end
         end
+        previous_exchange_end = previous_block_end
     end
     return model
 end
diff --git a/lua/parley/fold_projection.lua b/lua/parley/fold_projection.lua
new file mode 100644
index 0000000..110e7f3
--- /dev/null
+++ b/lua/parley/fold_projection.lua
@@ -0,0 +1,36 @@
+-- Pure projection of semantic exchange blocks into buffer fold ranges.
+
+local M = {}
+
+local FOLDABLE = {
+    thinking = true,
+    summary = true,
+    tool_use = true,
+    tool_result = true,
+}
+
+function M.desired_folds(model, exchange_index)
+    local exchange = model.exchanges[exchange_index]
+    if not exchange then return {} end
+
+    local ranges = {}
+    local exchange_start_0 = model:exchange_start(exchange_index)
+    local exchange_end_0 = model:last_nonempty_block_end(exchange_index)
+    for block_index, block in ipairs(exchange.blocks) do
+        if block.size > 0 and FOLDABLE[block.kind] then
+            local start_0 = model:block_start(exchange_index, block_index)
+            local end_0 = model:block_end(exchange_index, block_index)
+            assert(start_0 >= exchange_start_0 and end_0 <= exchange_end_0,
+                "fold range outside exchange bounds")
+            ranges[#ranges + 1] = {
+                block_index = block_index,
+                kind = block.kind,
+                start_0 = start_0,
+                end_0 = end_0,
+            }
+        end
+    end
+    return ranges
+end
+
+return M
diff --git a/lua/parley/init.lua b/lua/parley/init.lua
index dd81864..5c02c6b 100644
--- a/lua/parley/init.lua
+++ b/lua/parley/init.lua
@@ -4197,9 +4197,11 @@ end
 -- PROJECT record(s) referencing it, fleet-wide and archive-inclusive (`sdlc
 -- resolve --kind project`). A project is an always-cross-repo artifact class:
 -- the record may live in a different repo than the issue, so this never
--- assumes a local path.
+-- assumes a local path. buffer_fallback: with no ref under the cursor, an
+-- issue-file buffer supplies its own ref — gP anywhere in an issue file
+-- jumps to the project(s) tracking that issue.
 M.cmd.ResolveRefProject = function()
-	require("parley.artifact_ref").goto_ref_at_cursor({ kind = "project" })
+	require("parley.artifact_ref").goto_ref_at_cursor({ kind = "project", buffer_fallback = true })
 end

 -- Vision tracker commands
diff --git a/lua/parley/keybinding_registry.lua b/lua/parley/keybinding_registry.lua
index 0f3ceb5..e282877 100644
--- a/lua/parley/keybinding_registry.lua
+++ b/lua/parley/keybinding_registry.lua
@@ -446,7 +446,7 @@ M.entries = {
 		default_modes = { "n" },
 		scope = "parley_buffer",
 		desc = "Parley resolve project record(s) for ref",
-		help_desc = "Jump to the project record(s) referencing ariadne#11 under cursor (cross-repo)",
+		help_desc = "Jump to the project record(s) referencing ariadne#11 under cursor (cross-repo); in an issue file with no ref under cursor, uses the file's own issue",
 		buffer_local = true,
 	},
 	{
diff --git a/lua/parley/tool_folds.lua b/lua/parley/tool_folds.lua
index 0e65768..dc37ab0 100644
--- a/lua/parley/tool_folds.lua
+++ b/lua/parley/tool_folds.lua
@@ -1,68 +1,139 @@
 -- Chat buffer folding for parley.
 --
--- Uses the exchange_model to compute fold regions. Each answer block
--- (🧠:, text, 🔧:, 📎:, 📝:) gets its own fold. Questions and
--- agent headers are never folded.
+-- Uses a pure exchange-model projection to compute fold regions. Thinking,
+-- summary, tool-use, and tool-result blocks fold; questions, ordinary answer
+-- text, and agent headers do not.
 --
 -- foldmethod=manual — folds are created explicitly from model positions.
 -- No foldexpr evaluation, no backward scanning.

 local M = {}
+local projection = require("parley.fold_projection")
+local initialized = {}

--- Block kinds that should be folded
-local FOLDABLE = {
-    thinking = true,
-    summary = true,
-    tool_use = true,
-    tool_result = true,
-}
+local function valid_target(buf, win)
+    return vim.api.nvim_buf_is_valid(buf)
+        and vim.api.nvim_win_is_valid(win)
+        and vim.api.nvim_win_get_buf(win) == buf
+end

---- Recreate one manual fold for a semantic model block after its range changes.
---- Returns false without touching Neovim fold state for non-foldable blocks.
-function M._apply_block_fold(buf, win, model, exchange_index, block_index)
-    if not vim.api.nvim_buf_is_valid(buf) then return false end
-    if not win then
-        win = (vim.fn.win_findbuf(buf) or {})[1]
-    end
-    if not win or not vim.api.nvim_win_is_valid(win) then return false end
-    local block = model.exchanges[exchange_index] and model.exchanges[exchange_index].blocks[block_index]
-    if not block or not FOLDABLE[block.kind] or block.size <= 0 then return false end
+local function notify(event)
+    if M._observer then M._observer(event) end
+end

-    local start_0 = model:block_start(exchange_index, block_index)
-    local end_exclusive = model:block_end(exchange_index, block_index) + 1
+local function delete_projected_folds(buf, win, ranges)
+    if not valid_target(buf, win) then return end
+    vim.api.nvim_win_call(win, function()
+        local cursor = vim.api.nvim_win_get_cursor(win)
+        for index = #ranges, 1, -1 do
+            local row = ranges[index].start_0 + 1
+            vim.api.nvim_win_set_cursor(win, { row, 0 })
+            while vim.fn.foldlevel(row) > 0 do
+                vim.cmd("normal! zd")
+            end
+        end
+        local line_count = vim.api.nvim_buf_line_count(buf)
+        vim.api.nvim_win_set_cursor(win, { math.min(cursor[1], line_count), cursor[2] })
+    end)
+end
+
+function M.reconcile_exchange(buf, win, model, exchange_index)
+    if not valid_target(buf, win) or not model.exchanges[exchange_index] then return false end
+    local ranges = projection.desired_folds(model, exchange_index)
     vim.api.nvim_win_call(win, function()
         vim.api.nvim_set_option_value("foldminlines", 0, { win = win })
-        pcall(vim.cmd, string.format("%d,%dfold", start_0 + 1, end_exclusive))
+        for _, range in ipairs(ranges) do
+            vim.cmd(string.format("%d,%dfold", range.start_0 + 1, range.end_0 + 1))
+        end
     end)
+    notify({ phase = "reconcile", win = win, exchange_index = exchange_index, ranges = ranges })
     return true
 end

-function M._is_foldable(kind)
-    return FOLDABLE[kind] == true
+function M.prepare_exchange_update(buf, model, exchange_index)
+    if not vim.api.nvim_buf_is_valid(buf) or not model.exchanges[exchange_index] then return {} end
+    local ranges = projection.desired_folds(model, exchange_index)
+    local windows = vim.fn.win_findbuf(buf) or {}
+    for _, win in ipairs(windows) do
+        if valid_target(buf, win) then
+            delete_projected_folds(buf, win, ranges)
+            notify({ phase = "prepare", win = win, exchange_index = exchange_index, ranges = ranges })
+        end
+    end
+    return windows
 end

---- Compute and apply folds from the exchange model.
---- @param buf integer
-function M.apply_folds(buf)
-    if not vim.api.nvim_buf_is_valid(buf) then return end
+function M.finalize_exchange_update(buf, windows, model, exchange_index)
+    for _, win in ipairs(windows or {}) do
+        M.reconcile_exchange(buf, win, model, exchange_index)
+    end
+end

+local function default_model_provider(buf)
     local chat_parser = require("parley.chat_parser")
-    local exchange_model = require("parley.exchange_model")
-    local cfg = require("parley.config")
     local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
     local header_end = chat_parser.find_header_end(lines)
-    if not header_end then return end
-    local parsed = chat_parser.parse_chat(lines, header_end, cfg)
-    local model = exchange_model.from_parsed_chat(parsed)
+    if not header_end then return nil end
+    local parsed = chat_parser.parse_chat(lines, header_end, require("parley.config"))
+    return require("parley.exchange_model").from_parsed_chat(parsed)
+end

-    local windows = vim.fn.win_findbuf(buf)
-    for k, ex in ipairs(model.exchanges) do
-        for b in ipairs(ex.blocks) do
-            for _, target_win in ipairs(windows) do
-                M._apply_block_fold(buf, target_win, model, k, b)
+function M.with_exchange_update(buf, model, exchange_index, mutate)
+    local windows = M.prepare_exchange_update(buf, model, exchange_index)
+    local result
+    local ok, err = xpcall(function() result = mutate() end, debug.traceback)
+    local final_model = model
+    if not ok then
+        local recovered, parsed = pcall(M._model_provider or default_model_provider, buf)
+        final_model = recovered and parsed or nil
+    end
+    if ok then
+        M.finalize_exchange_update(buf, windows, final_model, exchange_index)
+    else
+        if final_model then
+            for _, win in ipairs(windows) do
+                pcall(M.reconcile_exchange, buf, win, final_model, exchange_index)
             end
         end
+        error(err, 0)
     end
+    return result
+end
+
+--- Compute and apply folds from the exchange model.
+--- @param buf integer
+function M.apply_folds(buf, win, model_provider)
+    if not vim.api.nvim_buf_is_valid(buf) then return false end
+    local model = (model_provider or M._model_provider or default_model_provider)(buf)
+    if not model then return false end
+    local windows = win and { win } or vim.fn.win_findbuf(buf)
+    for k in ipairs(model.exchanges) do
+        for _, target_win in ipairs(windows) do
+            M.reconcile_exchange(buf, target_win, model, k)
+        end
+    end
+    return true
+end
+
+function M.hydrate_window(buf, win, model_provider)
+    if not valid_target(buf, win) then return false end
+    initialized[buf] = initialized[buf] or {}
+    if initialized[buf][win] then return false end
+    vim.api.nvim_set_option_value("foldmethod", "manual", { win = win })
+    vim.api.nvim_set_option_value("foldtext", "v:lua.require('parley.tool_folds').foldtext()", { win = win })
+    vim.api.nvim_set_option_value("foldcolumn", "1", { win = win })
+    vim.api.nvim_set_option_value("foldminlines", 0, { win = win })
+    local provider = model_provider or M._model_provider or default_model_provider
+    local model = provider(buf)
+    if not model then return false end
+    vim.api.nvim_win_call(win, function()
+        vim.cmd("normal! zE")
+    end)
+    for exchange_index in ipairs(model.exchanges) do
+        M.reconcile_exchange(buf, win, model, exchange_index)
+    end
+    initialized[buf][win] = true
+    return true
 end

 --- Custom fold text.
@@ -90,13 +161,29 @@ end

 --- Set up folding on a chat buffer.
 function M.setup(buf)
-    vim.api.nvim_set_option_value("foldmethod", "manual", { win = 0 })
-    vim.api.nvim_set_option_value("foldtext", "v:lua.require('parley.tool_folds').foldtext()", { win = 0 })
-    vim.api.nvim_set_option_value("foldcolumn", "1", { win = 0 })
-    vim.api.nvim_set_option_value("foldminlines", 0, { win = 0 })
-    -- Apply folds from the model
+    local group = vim.api.nvim_create_augroup("ParleyToolFolds" .. buf, { clear = true })
+    vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
+        group = group,
+        callback = function(args)
+            if args.buf ~= buf then return end
+            local target = vim.api.nvim_get_current_win()
+            vim.schedule(function() M.hydrate_window(buf, target) end)
+        end,
+    })
+    vim.api.nvim_create_autocmd("WinClosed", {
+        group = group,
+        callback = function(args)
+            local closed = tonumber(args.match)
+            if initialized[buf] then initialized[buf][closed] = nil end
+        end,
+    })
+    vim.api.nvim_create_autocmd({ "BufUnload", "BufDelete" }, {
+        group = group, buffer = buf,
+        callback = function() initialized[buf] = nil end,
+    })
+    local win = vim.api.nvim_get_current_win()
     vim.schedule(function()
-        M.apply_folds(buf)
+        M.hydrate_window(buf, win)
     end)
 end

diff --git a/lua/parley/tool_loop.lua b/lua/parley/tool_loop.lua
index 0f11ca1..75c8a17 100644
--- a/lua/parley/tool_loop.lua
+++ b/lua/parley/tool_loop.lua
@@ -149,17 +149,18 @@ function M._append_section_to_answer(bufnr, model, exchange_idx, section)
     local buffer_edit = require("parley.buffer_edit")
     local render_buffer = require("parley.render_buffer")
     local lines = render_buffer.render_section(section)
-    model:add_block(exchange_idx, section.kind, #lines)
-    local blk_idx = #model.exchanges[exchange_idx].blocks
-    local pos = model:block_start(exchange_idx, blk_idx)
-    -- Insert margin + content. The model's block_start is where
-    -- the content goes; the margin is one line before it.
-    local insert_lines = { "" }  -- margin blank
-    for _, l in ipairs(lines) do
-        table.insert(insert_lines, l)
-    end
-    buffer_edit.insert_lines_at(bufnr, pos - 1, insert_lines)
-    require("parley.tool_folds")._apply_block_fold(bufnr, nil, model, exchange_idx, blk_idx)
+    require("parley.tool_folds").with_exchange_update(bufnr, model, exchange_idx, function()
+        model:add_block(exchange_idx, section.kind, #lines)
+        local blk_idx = #model.exchanges[exchange_idx].blocks
+        local pos = model:block_start(exchange_idx, blk_idx)
+        -- Insert margin + content. The model's block_start is where
+        -- the content goes; the margin is one line before it.
+        local insert_lines = { "" }  -- margin blank
+        for _, l in ipairs(lines) do
+            table.insert(insert_lines, l)
+        end
+        buffer_edit.insert_lines_at(bufnr, pos - 1, insert_lines)
+    end)
 end

 --------------------------------------------------------------------------------
diff --git a/tests/integration/chat_respond_spec.lua b/tests/integration/chat_respond_spec.lua
index 56ebb90..38ace72 100644
--- a/tests/integration/chat_respond_spec.lua
+++ b/tests/integration/chat_respond_spec.lua
@@ -48,6 +48,13 @@ local function buffer_contains(buf, needle)
     return text:find(needle, 1, true) ~= nil
 end

+local function find_line_number(buf, text)
+    for index, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
+        if line == text then return index end
+    end
+    return nil
+end
+
 local function pending_virtual_text(buf)
     local ns = vim.api.nvim_get_namespaces().parley_chat_pending
     if not ns then return nil end
@@ -2034,6 +2041,29 @@ describe("chat_respond: pending request transcript drift", function()
         assert.equals(thinking_row + 1, vim.fn.foldclosedend(thinking_row))
     end)

+    it("folds an adjacent streamed summary on its physical row", function()
+        local buf = open_simple_chat()
+        local captured_handler
+        local qid = "qid_stream_adjacent_summary"
+
+        parley.dispatcher.query = function(buf_arg, _provider, _payload, handler)
+            captured_handler = handler
+            parley.tasker.set_query(qid, { response = "", raw_response = "", buf = buf_arg })
+        end
+
+        parley.chat_respond({ range = 0 })
+        captured_handler(qid, "answer text\n📝: compact summary")
+
+        assert.is_true(vim.wait(200, function()
+            return buffer_contains(buf, "📝: compact summary")
+        end, 10))
+        local summary_row = assert(find_line_number(buf, "📝: compact summary"))
+        vim.cmd("normal! zM")
+        assert.equals(summary_row, vim.fn.foldclosed(summary_row))
+        assert.equals(summary_row, vim.fn.foldclosedend(summary_row))
+        assert.equals(0, vim.fn.foldlevel(summary_row + 1))
+    end)
+
     it("reduces only the active streamed span without reparsing transcript history", function()
         local buf = open_simple_chat()
         local history = {
diff --git a/tests/integration/create_handler_spec.lua b/tests/integration/create_handler_spec.lua
index 0f9e07d..c143eba 100644
--- a/tests/integration/create_handler_spec.lua
+++ b/tests/integration/create_handler_spec.lua
@@ -306,4 +306,24 @@ describe("create_handler: streaming behavior", function()
             line = "C",
         }, callbacks[2])
     end)
+
+    it("wraps the write and callbacks in around_write", function()
+        local events = {}
+        local handler = parley.dispatcher.create_handler(buf, nil, 3, true, "", false, function()
+            events[#events + 1] = "lines"
+        end, {
+            after_write = function() events[#events + 1] = "after" end,
+            around_write = function(qid, chunk, write)
+                assert.equals(mock_qid, qid)
+                assert.equals("A\nB", chunk)
+                events[#events + 1] = "before"
+                write()
+                events[#events + 1] = "finally"
+            end,
+        })
+
+        handler(mock_qid, "A\nB")
+        assert.is_true(vim.wait(100, function() return #events == 4 end, 10))
+        assert.same({ "before", "lines", "after", "finally" }, events)
+    end)
 end)
diff --git a/tests/integration/tool_folds_spec.lua b/tests/integration/tool_folds_spec.lua
index ae9610b..9806370 100644
--- a/tests/integration/tool_folds_spec.lua
+++ b/tests/integration/tool_folds_spec.lua
@@ -36,44 +36,16 @@ describe("tool_folds incremental manual folds", function()
         return model
     end

-    it("creates one fold for a foldable block and skips ordinary text", function()
-        local thinking = model_with("thinking", 2)
-        assert.is_true(tool_folds._apply_block_fold(buf, win, thinking, 1, 3))
-        vim.cmd("normal! zM")
-        assert.equals(7, vim.fn.foldclosed(7))
-        assert.equals(8, vim.fn.foldclosedend(7))
-
-        local text = model_with("text", 2)
-        assert.is_false(tool_folds._apply_block_fold(buf, win, text, 1, 3))
-    end)
-
-    it("recreates the active fold after streaming tail replacement destroys it", function()
-        local model = model_with("thinking", 2)
-        tool_folds._apply_block_fold(buf, win, model, 1, 3)
-        require("parley.buffer_edit").stream_replace_at_line(buf, 7, {
-            "thinking", "inserted thinking",
-        })
-        model:grow_block(1, 3, 1)
-        vim.cmd("normal! zM")
-        assert.equals(7, vim.fn.foldclosed(7))
-        assert.equals(7, vim.fn.foldclosedend(7))
-
-        tool_folds._apply_block_fold(buf, win, model, 1, 3)
-        vim.cmd("normal! zM")
-
-        assert.equals(7, vim.fn.foldclosed(7))
-        assert.equals(9, vim.fn.foldclosedend(7))
-    end)
-
     it("leaves a user fold outside the rewritten range untouched", function()
         vim.cmd("10,11fold")
         local model = model_with("thinking", 2)
-        tool_folds._apply_block_fold(buf, win, model, 1, 3)
-        require("parley.buffer_edit").stream_replace_at_line(buf, 7, {
-            "thinking", "inserted thinking",
-        })
-        model:grow_block(1, 3, 1)
-        tool_folds._apply_block_fold(buf, win, model, 1, 3)
+        tool_folds.reconcile_exchange(buf, win, model, 1)
+        tool_folds.with_exchange_update(buf, model, 1, function()
+            require("parley.buffer_edit").stream_replace_at_line(buf, 7, {
+                "thinking", "inserted thinking",
+            })
+            model:grow_block(1, 3, 1)
+        end)
         vim.cmd("normal! zM")

         assert.equals(7, vim.fn.foldclosed(7))
@@ -104,4 +76,164 @@ describe("tool_folds incremental manual folds", function()
         assert.equals(25, vim.fn.foldclosed(25))
         assert.equals(26, vim.fn.foldclosedend(25))
     end)
+
+    it("reconciles a changed exchange without leaving a blank-line ghost", function()
+        local model = model_with("thinking", 2)
+        tool_folds.reconcile_exchange(buf, win, model, 1)
+        vim.cmd("normal! zM")
+
+        local windows = tool_folds.prepare_exchange_update(buf, model, 1)
+        vim.api.nvim_buf_set_lines(buf, 6, 8, false, { "📝: summary" })
+        model:replace_span(1, 3, 1, { { kind = "summary", size = 1 } })
+        tool_folds.finalize_exchange_update(buf, windows, model, 1)
+        vim.cmd("normal! zM")
+
+        assert.equals(7, vim.fn.foldclosed(7))
+        assert.equals(7, vim.fn.foldclosedend(7))
+        assert.equals(-1, vim.fn.foldclosed(8))
+        assert.equals(0, vim.fn.foldlevel(8))
+    end)
+
+    it("prepares and reconciles the changed exchange in every displayed window", function()
+        local model = model_with("thinking", 2)
+        local second_win = vim.api.nvim_open_win(buf, false, {
+            relative = "editor", row = 1, col = 1, width = 30, height = 8,
+            style = "minimal",
+        })
+        vim.api.nvim_set_option_value("foldmethod", "manual", { win = second_win })
+        vim.api.nvim_set_option_value("foldenable", true, { win = second_win })
+        tool_folds.reconcile_exchange(buf, win, model, 1)
+        tool_folds.reconcile_exchange(buf, second_win, model, 1)
+
+        local windows = tool_folds.prepare_exchange_update(buf, model, 1)
+        vim.api.nvim_buf_set_lines(buf, 6, 8, false, { "📝: summary" })
+        model:replace_span(1, 3, 1, { { kind = "summary", size = 1 } })
+        tool_folds.finalize_exchange_update(buf, windows, model, 1)
+
+        for _, target in ipairs({ win, second_win }) do
+            vim.api.nvim_win_call(target, function()
+                vim.cmd("normal! zM")
+                assert.equals(7, vim.fn.foldclosed(7))
+                assert.equals(7, vim.fn.foldclosedend(7))
+                assert.equals(0, vim.fn.foldlevel(8))
+            end)
+        end
+        vim.api.nvim_win_close(second_win, true)
+    end)
+
+    it("restores from the current buffer model without masking a mutation error", function()
+        local model = model_with("thinking", 2)
+        local recovered = model_with("summary", 1)
+        tool_folds.reconcile_exchange(buf, win, model, 1)
+        local previous_provider = tool_folds._model_provider
+        tool_folds._model_provider = function() return recovered end
+
+        local ok, err = pcall(function()
+            tool_folds.with_exchange_update(buf, model, 1, function()
+                vim.api.nvim_buf_set_lines(buf, 6, 8, false, { "📝: summary" })
+                error("write exploded")
+            end)
+        end)
+        tool_folds._model_provider = previous_provider
+
+        assert.is_false(ok)
+        assert.matches("write exploded", err)
+        vim.cmd("normal! zM")
+        assert.equals(7, vim.fn.foldclosed(7))
+        assert.equals(7, vim.fn.foldclosedend(7))
+        assert.equals(0, vim.fn.foldlevel(8))
+    end)
+
+    it("hydrates a window only once from one model provider", function()
+        local calls = 0
+        local model = model_with("thinking", 2)
+        local provider = function()
+            calls = calls + 1
+            return model
+        end
+
+        assert.is_true(tool_folds.hydrate_window(buf, win, provider))
+        assert.is_false(tool_folds.hydrate_window(buf, win, provider))
+        assert.equals(1, calls)
+        vim.cmd("normal! zM")
+        assert.equals(7, vim.fn.foldclosed(7))
+        assert.equals(8, vim.fn.foldclosedend(7))
+    end)
+
+    it("replaces a persisted orphan fold with the exact initial projection", function()
+        vim.api.nvim_buf_set_lines(buf, 6, 8, false, { "📝: summary", "" })
+        vim.cmd("8,8fold")
+        local model = model_with("summary", 1)
+
+        assert.is_true(tool_folds.hydrate_window(buf, win, function() return model end))
+        vim.cmd("normal! zM")
+
+        assert.equals(7, vim.fn.foldclosed(7))
+        assert.equals(7, vim.fn.foldclosedend(7))
+        assert.equals(0, vim.fn.foldlevel(8))
+    end)
+
+    it("does not duplicate live folds when scheduled hydration runs afterward", function()
+        local model = model_with("thinking", 2)
+        tool_folds.with_exchange_update(buf, model, 1, function()
+            model:add_block(1, "tool_use", 2)
+        end)
+
+        assert.is_true(tool_folds.hydrate_window(buf, win, function() return model end))
+        local ranges = require("parley.fold_projection").desired_folds(model, 1)
+        assert.equals(1, vim.fn.foldlevel(ranges[1].start_0 + 1))
+        assert.equals(1, vim.fn.foldlevel(ranges[2].start_0 + 1))
+        assert.equals(0, vim.fn.foldlevel(ranges[2].end_0 + 2))
+    end)
+
+    it("folds recorded item rows when sections and exchanges have no gap", function()
+        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
+            "---", "topic: gaps", "file: gaps.md", "---", "",
+            "💬: first", "", "🤖:[A]", "", "answer", "📝: first summary",
+            "💬: second", "", "🤖:[A]", "", "📝: second summary", "",
+        })
+
+        tool_folds.apply_folds(buf)
+        vim.cmd("normal! zM")
+
+        assert.equals(11, vim.fn.foldclosed(11))
+        assert.equals(11, vim.fn.foldclosedend(11))
+        assert.equals(16, vim.fn.foldclosed(16))
+        assert.equals(16, vim.fn.foldclosedend(16))
+        assert.equals(0, vim.fn.foldlevel(17))
+    end)
+
+    it("keeps exactly one fold level across consecutive tool-loop appends", function()
+        local model = model_with("thinking", 2)
+        local second_win = vim.api.nvim_open_win(buf, false, {
+            relative = "editor", row = 1, col = 1, width = 30, height = 8,
+            style = "minimal",
+        })
+        vim.api.nvim_set_option_value("foldmethod", "manual", { win = second_win })
+        local events = {}
+        tool_folds._observer = function(event) events[#events + 1] = event end
+
+        require("parley.tool_loop")._append_section_to_answer(buf, model, 1, {
+            kind = "tool_use", name = "read_file", id = "call_1", input = { path = "x" },
+        })
+        local tool_use = require("parley.fold_projection").desired_folds(model, 1)[2]
+        require("parley.tool_loop")._append_section_to_answer(buf, model, 1, {
+            kind = "tool_result", name = "read_file", id = "call_1", content = "ok",
+        })
+        tool_folds._observer = nil
+
+        local ranges = require("parley.fold_projection").desired_folds(model, 1)
+        local tool_result = ranges[3]
+        assert.equals(8, #events)
+        for _, event in ipairs(events) do assert.equals(1, event.exchange_index) end
+        for _, target in ipairs({ win, second_win }) do
+            vim.api.nvim_win_call(target, function()
+                vim.cmd("normal! zM")
+                assert.equals(1, vim.fn.foldlevel(tool_use.start_0 + 1))
+                assert.equals(1, vim.fn.foldlevel(tool_result.start_0 + 1))
+                assert.equals(0, vim.fn.foldlevel(tool_result.end_0 + 2))
+            end)
+        end
+        vim.api.nvim_win_close(second_win, true)
+    end)
 end)
diff --git a/tests/unit/artifact_ref_spec.lua b/tests/unit/artifact_ref_spec.lua
index 94560b3..c78202e 100644
--- a/tests/unit/artifact_ref_spec.lua
+++ b/tests/unit/artifact_ref_spec.lua
@@ -252,6 +252,59 @@ describe("goto_ref_at_cursor on_no_ref fallback", function()
         ar.run_resolve = prev
         assert.is_false(fell_back)
     end)
+
+    -- buffer_fallback (gP in an issue file, ariadne#171 follow-up): no ref
+    -- under cursor → the issue file's own ref; a cursor ref still wins.
+    it("buffer_fallback resolves the issue file's own ref when cursor is not on one", function()
+        local buf = buf_with("id: 000042", 3)
+        vim.api.nvim_buf_set_name(buf, "/ws/ariadne/workshop/issues/000042-some-slug.md")
+        local seen
+        local prev = ar.run_resolve
+        ar.run_resolve = function(ref) seen = ref end
+        ar.goto_ref_at_cursor({ kind = "project", buffer_fallback = true })
+        ar.run_resolve = prev
+        assert.are.equal("ariadne#42", seen)
+    end)
+
+    it("buffer_fallback: a ref under the cursor beats the buffer's own ref", function()
+        local buf = buf_with("depends on metis#18", 15)
+        vim.api.nvim_buf_set_name(buf, "/ws/ariadne/workshop/issues/000042-b.md")
+        local seen
+        local prev = ar.run_resolve
+        ar.run_resolve = function(ref) seen = ref end
+        ar.goto_ref_at_cursor({ kind = "project", buffer_fallback = true })
+        ar.run_resolve = prev
+        assert.are.equal("metis#18", seen)
+    end)
+
+    it("buffer_fallback in a non-issue buffer still notifies no-ref", function()
+        local buf = buf_with("plain text", 2)
+        vim.api.nvim_buf_set_name(buf, "/ws/ariadne/workshop/parley/2026-07-18-chat.md")
+        local notified
+        local prev_notify = vim.notify
+        vim.notify = function(msg) notified = msg end
+        ar.goto_ref_at_cursor({ kind = "project", buffer_fallback = true })
+        vim.notify = prev_notify
+        assert.is_truthy(notified and notified:match("no artifact ref"))
+    end)
+end)
+
+describe("ref_from_issue_path", function()
+    it("derives repo#id from an active issue path, stripping zero padding", function()
+        assert.are.equal("ariadne#171", ar.ref_from_issue_path("/ws/ariadne/workshop/issues/000171-the-tension.md"))
+    end)
+
+    it("derives from an archived issue path", function()
+        assert.are.equal("metis#7", ar.ref_from_issue_path("/ws/metis/workshop/history/issues/000007-old.md"))
+    end)
+
+    it("returns nil for non-issue paths", function()
+        assert.is_nil(ar.ref_from_issue_path("/ws/ariadne/workshop/plans/000171-x-plan.md"))
+        assert.is_nil(ar.ref_from_issue_path("/ws/ariadne/workshop/projects/p.md"))
+        assert.is_nil(ar.ref_from_issue_path("/ws/ariadne/README.md"))
+        assert.is_nil(ar.ref_from_issue_path(""))
+        assert.is_nil(ar.ref_from_issue_path(nil))
+    end)
 end)

 describe("family_picker_items", function()
diff --git a/tests/unit/exchange_model_spec.lua b/tests/unit/exchange_model_spec.lua
index b5e50b3..845ae9e 100644
--- a/tests/unit/exchange_model_spec.lua
+++ b/tests/unit/exchange_model_spec.lua
@@ -211,6 +211,25 @@ describe("exchange_model: replace_span", function()
         assert.has_error(function()
             m:replace_span(1, 1, 1, { { kind = "text", size = -1 } })
         end)
+        assert.has_error(function()
+            m:replace_span(1, 1, 1, { { kind = "text", size = 1, gap_before = -1 } })
+        end)
+    end)
+
+    it("preserves an inherited leading gap and explicit adjacent replacements", function()
+        local m = em.new(4)
+        m:add_exchange(1)
+        m:add_block(1, "agent_header", 1)
+        m:add_block(1, "stream_placeholder", 2)
+
+        local first_start = m:block_start(1, 3)
+        m:replace_span(1, 3, 1, {
+            { kind = "text", size = 1 },
+            { kind = "summary", size = 1, gap_before = 0 },
+        })
+
+        assert.equals(first_start, m:block_start(1, 3))
+        assert.equals(first_start + 1, m:block_start(1, 4))
     end)
 end)

@@ -246,6 +265,61 @@ describe("exchange_model: from_parsed_chat", function()
         -- Exchange 2: question only
         assert.equals(1, #m.exchanges[2].blocks)
     end)
+
+    it("preserves actual zero, one, and multi-line gaps from parser spans", function()
+        local parsed = {
+            header_end = 4,
+            exchanges = {
+                {
+                    question = { line_start = 6, line_end = 6 },
+                    answer = {
+                        line_start = 8, line_end = 12,
+                        sections = {
+                            { kind = "text", line_start = 10, line_end = 10 },
+                            { kind = "summary", line_start = 12, line_end = 12 },
+                        },
+                    },
+                },
+                {
+                    -- No blank between the prior summary and this question.
+                    question = { line_start = 13, line_end = 13 },
+                    answer = {
+                        -- Two blank lines before the agent header.
+                        line_start = 16, line_end = 18,
+                        sections = {
+                            -- No blank between header and text.
+                            { kind = "text", line_start = 17, line_end = 17 },
+                            { kind = "summary", line_start = 18, line_end = 18 },
+                        },
+                    },
+                },
+            },
+        }
+
+        local m = em.from_parsed_chat(parsed)
+        assert.equals(6, m:block_start(1, 1) + 1)
+        assert.equals(8, m:block_start(1, 2) + 1)
+        assert.equals(10, m:block_start(1, 3) + 1)
+        assert.equals(12, m:block_start(1, 4) + 1)
+        assert.equals(13, m:block_start(2, 1) + 1)
+        assert.equals(16, m:block_start(2, 2) + 1)
+        assert.equals(17, m:block_start(2, 3) + 1)
+        assert.equals(18, m:block_start(2, 4) + 1)
+    end)
+
+    it("does not count a zero-size block or its stored gap", function()
+        local m = em.new(4)
+        m:add_exchange(1)
+        m:add_block(1, "agent_header", 1)
+        m:add_block(1, "stream_placeholder", 1)
+        m:add_exchange(1)
+        local next_before = m:block_start(2, 1)
+
+        m:set_block_size(1, 3, 0)
+
+        assert.equals(next_before - 2, m:block_start(2, 1))
+        assert.equals(m:block_end(1, 2) + 2, m:append_pos(1))
+    end)
 end)

 describe("exchange_model: from_parsed_chat with real parser", function()
diff --git a/tests/unit/fold_projection_spec.lua b/tests/unit/fold_projection_spec.lua
new file mode 100644
index 0000000..8336e43
--- /dev/null
+++ b/tests/unit/fold_projection_spec.lua
@@ -0,0 +1,43 @@
+local exchange_model = require("parley.exchange_model")
+
+describe("fold_projection", function()
+    it("projects only positive semantic fold blocks in block order", function()
+        local model = exchange_model.new(4)
+        model:add_exchange(2)
+        model:add_block(1, "agent_header", 1)
+        model:add_block(1, "thinking", 2)
+        model:add_block(1, "text", 3)
+        model:add_block(1, "summary", 1)
+        model:add_block(1, "tool_use", 4)
+        model:add_block(1, "tool_result", 2)
+        model:add_block(1, "thinking", 0)
+
+        model:add_exchange(1)
+        model:add_block(2, "agent_header", 1)
+        model:add_block(2, "summary", 2)
+
+        local projection = require("parley.fold_projection")
+        assert.same({
+            { block_index = 3, kind = "thinking", start_0 = 10, end_0 = 11 },
+            { block_index = 5, kind = "summary", start_0 = 17, end_0 = 17 },
+            { block_index = 6, kind = "tool_use", start_0 = 19, end_0 = 22 },
+            { block_index = 7, kind = "tool_result", start_0 = 24, end_0 = 25 },
+        }, projection.desired_folds(model, 1))
+        assert.same({
+            { block_index = 3, kind = "summary", start_0 = 31, end_0 = 32 },
+        }, projection.desired_folds(model, 2))
+        assert.same({}, projection.desired_folds(model, 3))
+    end)
+
+    it("loads without a Neovim global", function()
+        local path = vim.api.nvim_get_runtime_file("lua/parley/fold_projection.lua", false)[1]
+        local loader = assert(loadfile(path))
+        local saved_vim = _G.vim
+        _G.vim = nil
+        local ok, projection = pcall(loader)
+        _G.vim = saved_vim
+
+        assert.is_true(ok)
+        assert.is_function(projection.desired_folds)
+    end)
+end)
diff --git a/tests/unit/tool_folds_spec.lua b/tests/unit/tool_folds_spec.lua
index aba2e7d..1ad8b27 100644
--- a/tests/unit/tool_folds_spec.lua
+++ b/tests/unit/tool_folds_spec.lua
@@ -1,12 +1,15 @@
-local tool_folds = require("parley.tool_folds")
+local exchange_model = require("parley.exchange_model")
+local projection = require("parley.fold_projection")

 describe("tool_folds semantic policy", function()
     it("folds exactly auxiliary answer entities", function()
-        for _, kind in ipairs({ "thinking", "summary", "tool_use", "tool_result" }) do
-            assert.is_true(tool_folds._is_foldable(kind), kind)
-        end
-        for _, kind in ipairs({ "question", "agent_header", "text", "stream_placeholder" }) do
-            assert.is_false(tool_folds._is_foldable(kind), kind)
+        local model = exchange_model.new(0)
+        model:add_exchange(1)
+        for _, kind in ipairs({ "agent_header", "thinking", "summary", "tool_use", "tool_result", "text" }) do
+            model:add_block(1, kind, 1)
         end
+        local kinds = {}
+        for _, range in ipairs(projection.desired_folds(model, 1)) do kinds[#kinds + 1] = range.kind end
+        assert.same({ "thinking", "summary", "tool_use", "tool_result" }, kinds)
     end)
 end)
diff --git a/workshop/plans/000195-reconcile-semantic-folds-exactly-plan.md b/workshop/plans/000195-reconcile-semantic-folds-exactly-plan.md
index a58ef47..fc4a3d3 100644
--- a/workshop/plans/000195-reconcile-semantic-folds-exactly-plan.md
+++ b/workshop/plans/000195-reconcile-semantic-folds-exactly-plan.md
@@ -48,7 +48,8 @@
   - **Injected into:** Streaming `after_write`, tool-loop append, and hydration.
   - **Future extensions:** Explicit list of changed exchange indexes.
 - **`hydrate_window`** — obtains a fresh model through one provider seam and
-  renders every exchange once for a newly entered window. A `(buf,win)`
+  clears restored manual-fold state before rendering every exchange once for a
+  newly entered window. A `(buf,win)`
   initialized registry prevents duplicate identical folds and is cleared on
   window/buffer teardown. Live consumers use their current model and never
   reparse on success.
@@ -69,23 +70,23 @@
 - Create: `tests/unit/fold_projection_spec.lua`
 - Modify: `tests/unit/tool_folds_spec.lua`

-- [ ] **Step 1: Write RED pure tests**
+- [x] **Step 1: Write RED pure tests**

 Build `exchange_model` fixtures for all four foldable kinds, zero-size and
 ordinary blocks, margins, multiple blocks, and multiple exchanges. Assert exact
 ordered inclusive zero-based records. Load the module with `_G.vim=nil` in a
 plain isolated Lua package context to prove purity without brittle source grep.

-- [ ] **Step 2: Run RED**
+- [x] **Step 2: Run RED**

 Run the exact new spec with `PlenaryBustedFile`; expect module-not-found.

-- [ ] **Step 3: Implement `desired_folds`**
+- [x] **Step 3: Implement `desired_folds`**

 Own the foldable-kind set only in `fold_projection.lua`; use
 `model:block_start/end` and return no Neovim coordinates.

-- [ ] **Step 4: Run GREEN**
+- [x] **Step 4: Run GREEN**

 Run the new spec and `tests/unit/tool_folds_spec.lua`; expect all pass and the
 old duplicated policy owner removed.
@@ -95,7 +96,7 @@ old duplicated policy owner removed.
 **Files:**
 - Modify: `tests/integration/tool_folds_spec.lua`

-- [ ] **Step 1: Add RED production-shaped tests**
+- [x] **Step 1: Add RED production-shaped tests**

 With a real window/manual folds:

@@ -110,7 +111,7 @@ With a real window/manual folds:
 5. document native behavior for nested and partially overlapping user folds
    without promising identity Neovim does not expose.

-- [ ] **Step 2: Run RED**
+- [x] **Step 2: Run RED**

 Run `tests/integration/tool_folds_spec.lua`; expect the ghost assertion to
 reproduce and the prepare/reconcile APIs to be absent.
@@ -121,7 +122,7 @@ reproduce and the prepare/reconcile APIs to be absent.
 - Modify: `lua/parley/tool_folds.lua`
 - Modify: `tests/integration/tool_folds_spec.lua`

-- [ ] **Step 1: Implement exact old-fold deletion**
+- [x] **Step 1: Implement exact old-fold deletion**

 `prepare_exchange_update(buf, model, exchange_index)` validates the buffer and
 exchange, snapshots `win_findbuf(buf)`, projects old ranges, and in each valid
@@ -130,7 +131,7 @@ temporarily and runs `normal! zd` only when a fold level exists; it restores the
 cursor. It returns the window snapshot for post-mutation reconciliation and
 never runs `zE` or ranges across the exchange.

-- [ ] **Step 2: Implement exact new-fold rendering**
+- [x] **Step 2: Implement exact new-fold rendering**

 `reconcile_exchange` projects the current exchange for one window, converts
 only at the Ex boundary to one-based inclusive ranges, creates each manual fold,
@@ -138,7 +139,7 @@ and closes it. A buffer-scoped finalizer runs it for each surviving snapshot
 window. Invalid targets are no-ops. Add a test observer receiving
 `{ phase, win, exchange_index, ranges }` for locality assertions.

-- [ ] **Step 3: Add failure restoration seam**
+- [x] **Step 3: Add failure restoration seam**

 For synchronous callers, `with_exchange_update(..., mutate)` prepares all
 windows, executes `mutate` under `xpcall`, and on success reconciles from the
@@ -148,7 +149,7 @@ absent and never replace the original traceback. Add failures after buffer
 mutation and after model mutation. Streaming uses the same finalization policy
 through `dispatcher.create_handler`'s `around_write` seam.

-- [ ] **Step 4: Run GREEN**
+- [x] **Step 4: Run GREEN**

 Run fold unit/integration specs; expect exact summary-only convergence and the
 documented user-fold cases.
@@ -161,7 +162,7 @@ documented user-fold cases.
 - Modify: `lua/parley/chat_respond.lua`
 - Modify: `tests/integration/chat_respond_spec.lua`

-- [ ] **Step 1: Add RED streaming locality test**
+- [x] **Step 1: Add RED streaming locality test**

 Through `M.respond` and its real `create_handler`, stream a summary transition
 in exchange 2 displayed in two windows while exchange 1 and unrelated user
@@ -172,7 +173,7 @@ an injected stream-write failure, and an injected post-model-update failure;
 each must run recovery/finalization and preserve the original error. Retain
 bounded active-segment read assertions.

-- [ ] **Step 2: Wire before/after callbacks**
+- [x] **Step 2: Wire before/after callbacks**

 Add `opts.around_write(qid, chunk, write_fn)` to `dispatcher.create_handler` and
 place the actual buffer write, `on_lines_changed`, and `after_write` inside
@@ -181,7 +182,7 @@ snapshot windows, invokes `write_fn`, then always finalizes from the live model
 or parse-from-buffer recovery. Ensure `#replacements == 0` still reaches the
 finalizer. Delete `_apply_block_fold` use.

-- [ ] **Step 3: Verify streaming GREEN**
+- [x] **Step 3: Verify streaming GREEN**

 Run `chat_respond_spec.lua`; expect the new sequence/range assertions and all
 existing streaming tests to pass.
@@ -193,26 +194,26 @@ existing streaming tests to pass.
 - Create or Modify: `tests/integration/tool_loop_spec.lua`
 - Modify: `tests/integration/tool_folds_spec.lua`

-- [ ] **Step 1: Add RED real-entry-point test**
+- [x] **Step 1: Add RED real-entry-point test**

 Call `_append_section_to_answer` with a real two-window buffer/model and
 observer. Assert only its supplied `exchange_idx` receives prepare/reconcile in
 both windows, the appended tool block folds in both, and other exchange/user
 folds are unchanged.

-- [ ] **Step 2: Use `with_exchange_update`**
+- [x] **Step 2: Use `with_exchange_update`**

 Wrap the existing model add plus buffer insert in the shared transaction. Remove
 the add-only `_apply_block_fold` call.

-- [ ] **Step 3: Enforce the single mutation path**
+- [x] **Step 3: Enforce the single mutation path**

 Add an architecture assertion that production code contains no
 `_apply_block_fold` and no add-only semantic fold creation outside
 `tool_folds.lua`; decide `apply_folds` becomes the hydration wrapper rather than
 a parallel incremental API (`ARCH-DRY`, `ARCH-PURPOSE`).

-- [ ] **Step 4: Verify tool-loop GREEN**
+- [x] **Step 4: Verify tool-loop GREEN**

 Run exact tool-loop and fold specs; expect all pass.

@@ -222,7 +223,7 @@ Run exact tool-loop and fold specs; expect all pass.
 - Modify: `lua/parley/tool_folds.lua`
 - Modify: `tests/integration/tool_folds_spec.lua`

-- [ ] **Step 1: Add RED lifecycle tests**
+- [x] **Step 1: Add RED lifecycle tests**

 Inject one `model_provider(buf)` that reparses current lines. Test initial setup,
 setup called twice, a second window opened after setup and hydrated via the real
@@ -230,7 +231,7 @@ window event, independent window folds, close of window B leaving A unchanged,
 and a scheduled hydration callback delivered after buffer deletion/window close
 performing no mutation or error.

-- [ ] **Step 2: Implement idempotent hydration**
+- [x] **Step 2: Implement idempotent hydration**

 `hydrate_window(buf, win, model_provider)` checks validity and the lightweight
 initialized registry, configures fold options, obtains one fresh model, and
@@ -239,7 +240,7 @@ uses the shared reconciler for every exchange before marking `(buf,win)` done.
 `BufUnload`, and `BufDelete`, and schedules hydration with captured IDs. Repeat
 setup/events skip initialized windows; teardown clears the corresponding keys.

-- [ ] **Step 3: Verify lifecycle GREEN**
+- [x] **Step 3: Verify lifecycle GREEN**

 Run `tool_folds_spec.lua`; expect all window/race tests pass.

@@ -250,24 +251,24 @@ Run `tool_folds_spec.lua`; expect all window/race tests pass.
 - Modify: `atlas/traceability.yaml`
 - Modify: `workshop/issues/000195-reconcile-semantic-folds-exactly.md`

-- [ ] **Step 1: Update atlas and traceability**
+- [x] **Step 1: Update atlas and traceability**

 Map pure projection, exchange-local mutation bracketing, real consumers, and
 late-window hydration. Add the new pure module/spec and tool-loop integration
 test mapping.

-- [ ] **Step 2: Run focused verification**
+- [x] **Step 2: Run focused verification**

 Run exact projection, fold, chat-respond, and tool-loop specs; mapped
 `make test-spec SPEC=chat/lifecycle`; `make test-changed`; and
 `git diff --check`. Expected: all zero.

-- [ ] **Step 3: Run full verification**
+- [x] **Step 3: Run full verification**

 Run `make test`. If the known parallel `tools_builtin_find_spec`/`.test-tmp`
 race appears, verify that exact spec and run `make test JOBS=1`; record both.

-- [ ] **Step 4: Update issue evidence and commit**
+- [x] **Step 4: Update issue evidence and commit**

 Tick plan/issue steps and append RED/GREEN/final evidence. Commit with #195 and
 the required co-author trailer. Do not close or land before operator smoke test.
@@ -291,3 +292,213 @@ displaying the changed buffer; added dispatcher `around_write` so streaming
 finalization covers empty reductions and failures; defined parse-from-buffer
 recovery without masking the original error; and added a lightweight
 initialized `(buf,win)` registry plus teardown to make hydration idempotent.
+
+### 2026-07-18 — Exact hydration convergence
+
+Operator smoke testing revealed that a live tool transaction can precede its
+scheduled initial hydration. Revised hydration and exchange preparation to
+retire every native fold layer at projected semantic starts before rendering
+one fold, so lifecycle ordering cannot leave duplicate semantic nesting.
+
+### 2026-07-18 — Trailing-margin invariant
+
+Added pure projection of semantic trailing-margin rows and adapter cleanup at
+those rows after a smoke test showed an already-migrated blank-line fold has no
+desired semantic start through which hydration could otherwise retire it.
+
+## Chunk 3: Use the exchange structure's actual layout
+
+### Core concept correction
+
+The earlier chunks chose the wrong coordinate basis. `parsed_chat` already
+records absolute `line_start`/`line_end` for questions and answer sections, but
+`exchange_model.from_parsed_chat` discarded those coordinates and rebuilt the
+document with a hard-coded one-line gap between every block and exchange. One
+missing historical separator therefore shifted every later fold. Clearing
+inferred trailing margins treated the symptom and must be removed.
+
+| Name | Kind | Lives in | Status |
+|------|------|----------|--------|
+| `LayoutGap` | PURE | `lua/parley/exchange_model.lua` | modified |
+| `desired_folds` | PURE | `lua/parley/fold_projection.lua` | modified |
+
+- **`LayoutGap`** — nonnegative `gap_before` metadata on exchanges and blocks,
+  derived from adjacent absolute parser spans when loading an existing chat.
+  New live blocks retain the canonical one-line default, while parsed chats
+  preserve zero-, one-, or multi-line historical gaps exactly.
+  - **Relationships:** Each exchange exclusively owns the gap before its first
+    visible block. The question/first block has `gap_before = 0` and never
+    duplicates that leading gap; later blocks own only intra-exchange gaps from
+    the preceding visible item. `exchange_total_size` excludes the exchange
+    leading gap, while `exchange_start` adds it exactly once after the header or
+    previous exchange. Position queries never invent layout.
+  - **DRY rationale:** The exchange model remains the one positional source for
+    folds, streaming, tool appends, and prompt insertion (`ARCH-DRY`).
+  - **Future extensions:** None; gaps are the minimal missing layout fact.
+- **`desired_folds`** — continues to project foldable model blocks, but asserts
+  every result lies within its exchange's computed bounds. It projects no gap
+  or margin rows (`ARCH-PURE`, `ARCH-PURPOSE`).
+
+| Name | Kind | Lives in | Status | Wraps |
+|------|------|----------|--------|-------|
+| parsed-layout hydration | INTEGRATION | `lua/parley/exchange_model.lua` | modified | `chat_parser` absolute spans |
+| streaming span replacement | INTEGRATION | `lua/parley/chat_respond.lua` | modified | reduced active-segment spans |
+
+- **Parsed-layout hydration** derives gaps once from adjacent parser spans;
+  folding does not inspect buffer text or reconstruct the whole document.
+- **Streaming span replacement** supplies the reduced sections' relative gaps
+  to `replace_span`; it still reads only the active segment and updates only the
+  known changed exchange.
+
+### Task 8: Preserve actual gaps in the exchange model
+
+**Files:**
+- Modify: `lua/parley/exchange_model.lua`
+- Modify: `tests/unit/exchange_model_spec.lua`
+
+- [x] **Step 1: Write the RED coordinate regression**
+
+Build a parsed-chat fixture whose first exchange summary is immediately
+followed by the next question. Assert that `from_parsed_chat` places both at
+their recorded absolute rows, plus cases for canonical one-line and multi-line
+gaps within/between exchanges. Expected current failure: the second question
+and its summary are projected one row too low.
+
+- [x] **Step 2: Implement explicit gap arithmetic**
+
+Store `gap_before` on each exchange and block. `exchange_start`,
+`exchange_total_size`, `block_start`, `append_pos`, and replacement math sum
+stored gaps only for positive-size visible items; a zero-size block contributes
+neither content nor its stored gap, preserving the existing empty-block
+invisibility invariant. `new`/`add_exchange`/`add_block` preserve current canonical defaults;
+`from_parsed_chat` derives gaps as `current_start - previous_end - 1` from the
+recorded spans. Reject negative gaps because overlapping items violate the
+exchange structure.
+
+The ownership formula is explicit: `exchange.gap_before` alone positions block
+1; block 1's gap is always zero. `exchange_total_size` sums visible block sizes
+and only visible blocks 2..N's intra-exchange gaps. `exchange_start(1)` is
+`header_lines + exchange[1].gap_before`; later starts are the prior start plus
+prior `exchange_total_size` plus the next exchange's leading gap. Tests pin both
+the first question after the header and later questions after prior exchanges.
+
+- [x] **Step 3: Preserve gaps through mutation**
+
+`replace_span` accepts optional per-section `gap_before`; the first replacement
+inherits the replaced span's leading gap when omitted, and subsequent new live
+sections default to the canonical margin. Add RED/GREEN tests for grow, append,
+replace, zero-size blocks, and downstream exchanges. Pin the real empty-stream
+collapse shape: setting the placeholder to size zero after deleting its content
+and preceding margin leaves `append_pos` and the next exchange at their physical
+rows. Every existing mutation consumer must retain exact positions.
+
+- [x] **Step 4: Run model GREEN**
+
+Run `tests/unit/exchange_model_spec.lua`. Expected: all coordinate and mutation
+tests pass without Neovim IO.
+
+### Task 9: Fold only the stated exchange items
+
+**Files:**
+- Modify: `lua/parley/fold_projection.lua`
+- Modify: `lua/parley/tool_folds.lua`
+- Modify: `tests/unit/fold_projection_spec.lua`
+- Modify: `tests/integration/tool_folds_spec.lua`
+
+- [x] **Step 1: Write the RED fold regression**
+
+Use the marginless two-exchange fixture. Assert the later one-line summary fold
+starts on its actual marker row, the following blank has fold level zero, and
+every projected range is contained by its exchange bounds. This directly
+reproduces the reported 1466/1467 failure without depending on the operator's
+brain file.
+
+- [x] **Step 2: Remove inferred-margin folding logic**
+
+Delete `trailing_margin_rows` and all cleanup based on `end + 1`. Folds derive
+only from foldable items' model spans; prepare/reconcile never targets a gap or
+row outside the selected exchange. Keep the existing changed-exchange and
+multi-window transaction unchanged.
+
+- [x] **Step 3: Run fold GREEN**
+
+Run the projection and fold specs. Expected: exact marker-row folds, zero fold
+level on gaps, consecutive tool folds remain level one, and unrelated exchange
+and user folds remain unchanged.
+
+### Task 10: Feed exact relative gaps during streaming
+
+**Files:**
+- Modify: `lua/parley/chat_respond.lua`
+- Modify: `tests/integration/chat_respond_spec.lua`
+
+- [x] **Step 1: Write the RED active-segment test**
+
+Through the real dispatcher, reduce adjacent text/summary sections with no
+blank between them and assert the live model matches their physical rows. Keep
+the existing observer assertion that streaming reads only the active segment,
+never the whole transcript.
+
+- [x] **Step 2: Supply relative gaps to `replace_span`**
+
+Derive each replacement section's `gap_before` from consecutive reducer
+`line_start`/`line_end` values and the predecessor at the replacement boundary.
+Do not parse history or adjust unchanged exchanges explicitly; model position
+queries derive downstream rows from the changed sizes and gaps.
+
+- [x] **Step 3: Run consumer GREEN**
+
+Run chat-response, dispatcher, tool-loop, projection, and fold specs. Expected:
+all pass and no production consumer computes fold coordinates independently
+(`ARCH-DRY`, `ARCH-PURPOSE`).
+
+### Task 11: Verify the corrected invariant
+
+**Files:**
+- Modify: `atlas/chat/exchange_model.md`
+- Modify: `atlas/chat/lifecycle.md`
+- Modify: `workshop/issues/000195-reconcile-semantic-folds-exactly.md`
+
+- [x] **Step 1: Replace the incorrect atlas explanation**
+
+Document stored actual gaps, exchange-bounded fold projection, and localized
+streaming updates. Remove the trailing-margin cleanup narrative.
+
+- [x] **Step 2: Run verification**
+
+Run focused specs, `make test-spec SPEC=chat/exchange_model`,
+`make test-spec SPEC=chat/lifecycle`, `make test-changed`, `make lint`,
+`git diff --check`, and `make test JOBS=1`. Expected: zero failures/warnings.
+
+- [x] **Step 3: Operator smoke test**
+
+Open the reported brain chat at lines 1466–1467 after reloading Parley. Expected:
+line 1466 has the one-line summary fold; line 1467 has fold level zero. Also
+exercise a fresh streaming summary plus tool-use/tool-result response before
+committing or closing.
+
+### 2026-07-18 — Coordinate-basis correction
+
+Replaced inferred trailing-margin cleanup with the exchange structure's actual
+layout math. Parser spans imply every gap already; preserving those gaps in the
+size-based model makes missing historical separators irrelevant and keeps fold
+projection strictly inside the selected exchange. This revision is the root
+correction after repeated smoke tests exposed that globally reconstructed
+one-line margins—not Neovim fold mutation—caused the remaining off-by-one.
+
+The fresh-eyes plan review additionally pinned zero-size invisibility: stored
+gaps are conditional on positive-size items, so empty-answer collapse cannot
+reintroduce a one-row downstream drift.
+It also single-sourced leading-gap ownership on the exchange: block 1 never owns
+or contributes that gap, preventing header/question and inter-exchange gaps
+from being counted twice.
+
+### 2026-07-18 — Deterministic initial hydration
+
+Operator smoke testing proved the corrected 1466 projection could coexist with
+a persisted orphan fold at 1467 because hydration only retired folds reachable
+from current semantic starts. Revised the initial-window boundary to clear all
+restored manual folds before rendering the complete model projection. This is
+distinct from the streaming hot path, which remains localized to the changed
+exchange; the split makes initial state deterministic without reparsing or
+touching unchanged exchanges during response updates (`ARCH-PURE`).


exec
/bin/zsh -lc "sed -n '1,220p' /Users/xianxu/workspace/ariadne/construct/adapted/superpowers-using-superpowers/SKILL.md && sdlc --help | sed -n '1,180p' && sed -n '1,220p' workshop/lessons.md" in /Users/xianxu/workspace/parley.nvim
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
  project         Create + manage projects (new / list / show / set-status / validate)
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
  migrate         Move a markdown artifact to a peer repo, rewriting refs (#179)
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

## 2026-07-17 (#194)

- **A checked plan edge-case list must map to explicit production tests, not
  merely to helper-level coverage or nearby happy paths.** The close review
  found that end submission promised no/one/multiple trailing blanks and a
  final-line marker, while its integration tests instantiated only the first
  two shapes. Rule: before ticking a plan step, enumerate every named fixture
  variant against the production entry-point tests; adjacent coverage does not
  satisfy a promised slice (`ARCH-PURPOSE`).
- **Whole-buffer replacement is observable UI state destruction even when the
  resulting text is identical.** Neovim manual folds are attached to buffer
  ranges, so rewriting the transcript can erase or migrate folds into unrelated
  questions. Rule: plan semantic transforms as original-coordinate edits and
  apply them bottom-to-top through bounded buffer mutations; test both fold text
  and gutter visibility through the production entry point (`ARCH-PURE`).

## 2026-07-16 (#191)

- **Moving an artifact into a typed archive subdirectory is also a consumer
  configuration migration.** The filesystem move to
  `workshop/history/issues/` landed while Parley's `history_dir` default still
  named the parent container, so non-recursive Issue Finder and next-ID scans
  silently returned no archived records. Rule: for every archive-layout move,
  shadow-sweep configured defaults, ordinary and super-repo expansion, ID
  allocation, neighborhood classification, tests, and atlas; keep one new
  canonical path rather than adding legacy fallback traversal (`ARCH-DRY`,
  `ARCH-PURPOSE`).

## 2026-07-16 (#189)

- **A finder-local comparator must stop at its actual primary fields.** Issue
  and Vision compared native IO paths after equal status/ID or file-level
  values, so the shared sorter never reached its canonical identity tie-break.
  Rule: when a shared sorter owns deterministic ties, local comparators return
  `false` after their primary fields tie; add an adversarial fixture whose
  native paths and canonical identities sort in opposite directions
  (`ARCH-DRY`, `ARCH-PURPOSE`).
- **A derived metadata view must consume the canonical grammar, not reproduce
  its convenient subset.** Chat Finder's pure record adapter copied delimiter,
  key-prefix, and tag parsing from `chat_parser`, leaving two owners that could
  drift. Rule: when a finder needs metadata from an existing document format,
  export the smallest pure parser seam from the format owner and add parity
  fixtures for legacy and current syntax (`ARCH-DRY`).
- **A joinable raw outcome needs a policy-divergence test, not only a join-count
  test.** One opener joining a prewarm proved scan reuse but did not prove that
  multiple subscribers could independently apply recency to the same records.
  Rule: shared async-result tests must bind at least two subscribers with
  different materialization policies and assert both projections.
- **A scheduled controller is INTEGRATION even when its decisions are
  deterministic.** `SliceBatcher` owns mutable progress and yields through an
  injected scheduler/clock, so classifying it as PURE hid the event-loop seam.
  Rule: classify the whole named symbol, not just its normalization policy
  (`ARCH-PURE`).
- **Async adapter and filesystem results must be validated at their consumer
  boundaries.** A `{kind="record"}` with a nil payload crashed a scheduled
  producer callback, while a successful stat could still identify a directory
  reached through a tracked symlink. Rule: validate record payload shape before
  storage and require the exact filesystem object type promised by the finder.
- **A production loading test must cross both the real process and real picker
  boundaries.** Unit lifecycle tests missed settlement running in a libuv fast
  event, where querying the prompt raised `E5560` and left `scanning…` stranded.
  Rule: for async UI, delay a real process, prove a real spinner frame advances,
  and assert the real picker replaces it after settlement.
- **Protocol coverage must instantiate every object named by the plan.** A
  nested repository is not evidence for submodule opacity. Rule: when a plan
  promises real Git edge cases, construct and assert each distinct Git object
  explicitly.
- **A process-stream error is a terminal event for that stream.** Killing the
  child does not guarantee another EOF callback, so waiting on an unretired pipe
  can strand the whole lifecycle. Rule: on read error, stop/close that side,
  mark it terminal, and test settlement after child exit for stdout and stderr.
- **A byte cap constrains retained state, not only the failure threshold.**
  Appending a whole chunk and checking afterward can retain arbitrarily more
  than the advertised maximum. Rule: parse framed chunks incrementally and
  reject before concatenation would cross the cap; ignore later callbacks from
  the retired stream.
- **Canonical comparison identity and native IO location are different path
  fields.** Separator normalization makes ordering portable but corrupts legal
  POSIX backslashes if reused for file opening. Rule: use canonical keys only
  for dedup/sort and preserve resolved/unresolved native paths for IO.
- **An asynchronous acquisition event is untrusted until its whole schema is
  validated.** Checking only the table and ordinal lets bad failure kinds or
  list shapes reach asserting reducers after the producer call has returned,
  escaping synchronous containment and stranding UI. Rule: validate ordinal,
  status, list shape, and registered kinds before any accumulator mutation;
  collapse violations to one static bounded outcome.
- **Framed protocols must reject EOF with a pending fragment.** Exit zero does
  not make a missing final NUL valid; silently dropping it converts corruption
  into empty success. Rule: at EOF, require the framing buffer to be empty and
  test a below-cap truncated record separately from overflow.
- **Compatibility tests must assert presentation, not only row cardinality.**
  Invalid super-repo labels still produced two rows, but new `{}` prefixes
  changed display/search semantics. Rule: for fallback records, pin visible and
  searchable text alongside count.

## 2026-07-15 (#190)

- **A persisted path key is an identity boundary, so its normalization must have
  one owner.** #190 initially repeated `expand → resolve → trim trailing slash`
  in toggle persistence, startup restoration, and transient-root filtering;
  the close review found that a later change could make reads and writes use
  different keys. Rule: whenever a path becomes a durable map key, centralize
  normalization before the first consumer and add an architecture check that
  forbids parallel normalization expressions (`ARCH-DRY`).

## 2026-07-14 (#187)

- **A changed user-facing command needs a README discoverability check even when
  README has no stale sentence to grep.** #187 updated Markdown Finder's facet
  and query behavior and corrected every atlas consumer, but the close review
  found that README did not mention `:ParleyMarkdownFinder` / `<C-g>m` at all.
  Rule: for every visible command or keybinding changed, search README for the
  command and key; absence is a documentation gap, not evidence that no update
  is needed.
- **A readiness file is ready only when its payload validates, not merely when
  it exists.** The close review's full suite intermittently observed the fake
  SSE server's port file after `open()` but before its write/close, producing a
  readable empty file and `port=nil`; a clean retry passed. Rule: process-fixture
  readiness polling must parse and validate the announced value inside the wait
  predicate before consumers proceed.

## 2026-07-12 (#170)
- **Making terminal failure explicit in an async callback changes every consumer contract.** `generate_topic` began calling `callback(nil, reason)` on abort/empty so the response leg could finalize exactly once, but `ChatPrune` still concatenated its callback argument as a guaranteed string. Rule: whenever a callback gains a failure invocation or return shape, grep every consumer and add one real-entry-point test per terminal outcome; shared-producer tests do not prove consumer glue handles the new contract.
- **A bounded-work API must measure actual traversal/copying, not merely report a bounded logical row count.** A successful one-row structural replacement reported one row while deep-copying arrays proportional to the whole document, and reasoning openers each rescanned a suffix. Rule: performance tests must pin implementation-observable visits/sharing at multiple document sizes and adversarial repeated-marker fixtures; use persistent sharing and linear indexing where derived state is unchanged.
- **Canonical grammar ownership requires a repository shadow search, including private helpers.** Exporting the managed-footnote predicate did not prevent `chat_respond` from retaining a stricter untrimmed regex. Rule: after centralizing grammar, add an architecture search forbidding old helper names/patterns and test whitespace/edge parity through every consumer.

## 2026-07-10 (#177)
- **A durable plan filename must use the issue's exact canonical slug, not a shortened equivalent.** The first `sdlc change-code` review saw only #177's summary checklist because `workshop/plans/000177-sticky-issue-finder-query-plan.md` did not match the issue filename; the detailed plan existed but was undiscoverable. Rule: derive the plan path by appending `-plan.md` to the complete issue basename (`NNNNNN-<issue-slug>`), then confirm the gate's review prompt includes the separate plan before trusting its verdict.

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

exec
/bin/zsh -lc "sed -n '1,380p' workshop/plans/000195-reconcile-semantic-folds-exactly-plan.md" in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc "sed -n '1,260p' workshop/issues/000195-reconcile-semantic-folds-exactly.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
---
id: 000195
status: working
deps: []
github_issue:
created: 2026-07-17
updated: 2026-07-17
estimate_hours: 3.5
started: 2026-07-17T20:56:40-07:00
---

# Reconcile semantic folds exactly

## Problem

Semantic folds are calculated from `exchange_model`, but the Neovim adapter
only adds manual folds. When streaming changes a block from one semantic shape
to another, Neovim can shrink the old manual fold onto an adjacent blank line;
Parley then adds the new fold without retiring the old one. The result is a
ghost empty-line fold below a valid summary fold.

Clearing every manual fold is not acceptable because operators may create
their own folds. Recomputing every exchange after each streamed chunk is also
unnecessary: the response and tool-loop paths already know which exchange
changed.

## Spec

Semantic folds are an exchange-local pure projection:

`desired_semantic_folds(exchange_model, exchange_index) -> ordered ranges`

Each returned record is `{ block_index, kind, start_0, end_0 }`, where endpoints
are inclusive, zero-based buffer rows and records remain in block order. Only
the thin Neovim adapter converts them to one-based inclusive `:fold` ranges.
Pure unit coverage includes all four foldable kinds, zero-size exclusion,
margins, multiple blocks, and multiple exchanges.

The projection includes only foldable block kinds (`thinking`, `summary`,
`tool_use`, and `tool_result`) with positive size. It derives all positions from
`exchange_model`; it does not inspect buffer text, existing folds, or editor
state (`ARCH-PURE`, `ARCH-PURPOSE`).

Manual folds have no stable identity after their covered text changes. The
adapter therefore uses a mutation transaction rather than a persistent fold
ledger. `prepare_exchange_update(buf, win, model, exchange_index)` computes the
old pure projection while its manual folds are still intact and deletes one
fold at each projected start with window-local `normal! zd`, in reverse block
order. `reconcile_exchange(buf, win, model, exchange_index)` runs after the
buffer/model mutation and creates exactly the new pure projection. The caller's
current model plus exchange index identifies the changed exchange; no extmark or
historical numeric index is used as durable identity.

The mutation transaction is buffer-scoped. It snapshots every valid window
displaying the buffer, prepares the changed exchange in each before mutation,
then reconciles that exchange in every surviving snapshot window afterward. A
window appearing later hydrates normally. Streaming brackets each write to the
active exchange through a dispatcher `around_write` seam whose scope includes
the buffer write, live-model growth/reduction, and after-write callbacks;
reconciliation therefore runs as a `finally` action even for an empty reduction
or thrown write/callback. Tool-loop append uses the synchronous form around its
model and buffer mutation. Unchanged exchanges receive no fold commands.

On successful mutation, reconciliation uses the caller's updated live model. On
failure, the transaction attempts to rebuild a model from the current buffer
through the shared model-provider seam and reconciles the changed exchange in
each surviving window. If reparsing/reconciliation also fails, it leaves the
prepared semantic folds absent, preserves unrelated folds, and rethrows the
original error/traceback; recovery failure must never obscure the cause. Tests
inject failure after buffer mutation and after model mutation. All consumers use
the same transaction adapter (`ARCH-DRY`, `ARCH-PURPOSE`).

Initial chat setup and a later `BufWinEnter`/`WinEnter` parse the current buffer
through one model-provider seam and create the complete projection once in that
window. A lightweight initialized registry keyed only by `(buf, win)` prevents
repeated setup/window events from duplicating identical manual folds; it stores
no fold ranges or exchange ownership. Live transactions use their current model
and update no hydration identity. External structural edits do not trigger
automatic full rehydration; their native manual-fold movement remains outside
this regression's changed-exchange contract. `WinClosed`, `BufUnload`, and
`BufDelete` clear initialized entries, so window/buffer reuse starts cleanly.
Scheduled hydration checks validity and initialization again at execution time.

If a user fold overlaps a semantic fold in the changed exchange, `zd` may select
the innermost native manual fold; exact preservation of overlapping/nested folds
cannot be guaranteed because Neovim exposes no fold IDs. The defended contract
is explicit and testable: adjacent/partially overlapping cases follow native
`zd` behavior, while unrelated user folds and every untouched exchange remain
unchanged. Parley never issues `zE` or a document-wide fold clear.

## Done when

- A streamed transition to a one-line summary produces exactly one summary fold
  and no fold on the following blank line.
- Desired semantic fold ranges are computed by a pure exchange-local function.
- Streaming and tool-loop paths reconcile only their changed exchange.
- Every window showing the changed buffer converges for that exchange.
- Initial setup creates the same semantic folds through the shared reconciler.
- Unchanged exchanges and unrelated user folds retain their ranges and closed
  state.
- A window opened after initial setup receives independent semantic folds;
  closing it does not disturb another window's folds.
- Repeated setup and stale scheduled hydration are idempotent and harmless after
  buffer/window teardown; buffer reuse begins with no retained fold state.
- Actual streaming and tool-loop entry points bracket mutations for only their
  known exchange, including empty reductions and failures, and no add-only
  semantic-fold consumer remains.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.25 impl=0.02
item: lua-neovim design=0.75 impl=0.75
item: lua-neovim design=0.35 impl=0.55
item: lua-neovim design=0.15 impl=0.35
item: atlas-docs design=0.03 impl=0.02
item: milestone-review design=0.0 impl=0.15
design-buffer: 0.10
total: 3.5
```

## Plan

- [x] Write and approve the durable implementation plan.
- [x] Add RED pure and Neovim integration regressions for exact localized reconciliation.
- [x] Implement exchange-local fold projection, mutation transaction, and reconciliation.
- [x] Route setup, streaming, and tool-loop consumers through the shared reconciler.
- [x] Update atlas and run focused, changed, and full verification.

## Log

### 2026-07-17

Root cause: `_apply_block_fold` issues `:fold` for the latest block range but
never retires the prior semantic manual fold. Neovim can migrate that prior
range onto the blank margin when streaming replaces the semantic span. The
approved design makes folds a pure per-exchange projection and brackets only
the known changed exchange's mutation (`ARCH-PURE`, `ARCH-DRY`,
`ARCH-PURPOSE`).

Implementation now projects fold ranges from `exchange_model` without Neovim,
brackets streaming writes and synchronous tool appends by their known exchange,
and reconciles that exchange across every displayed window. Regression coverage
proves the one-line summary has no following blank-line fold, unrelated folds
survive, failure recovery retains the original error, hydration is idempotent,
and the real tool-loop consumer is localized. RED evidence included the missing
projection module, missing prepare/reconcile APIs, and missing dispatcher
`around_write` seam. GREEN evidence: focused projection/fold/dispatcher/tool-loop/
chat-response specs and full `make test` (306 linted files, all tests passing).

Operator smoke testing exposed a second convergence case: a live tool-loop
transaction can finish before scheduled initial hydration, after which the
add-only hydration pass nested an identical fold around the tool block and its
trailing margin. A production-ordered RED test measured fold level 2. Hydration
and changed-exchange prepare now retire every native layer at each projected
semantic start before rendering exactly one fold; the tool-use, tool-result,
and trailing blank rows assert levels 1, 1, and 0 respectively (`ARCH-PURE`,
`ARCH-PURPOSE`).

A follow-up smoke test found an already-migrated one-line summary fold could
survive hydration because cleanup only visited desired fold starts. The pure
projection now also returns each semantic block's trailing margin row; the
adapter clears fold layers there before rendering. The production-shaped RED
case began with a fold on the blank row and now converges to summary level 1,
blank level 0 (`ARCH-PURE`, `ARCH-PURPOSE`).

Exact inspection of the reported brain chat corrected that diagnosis. The
parser records the summary at line 1466, but `from_parsed_chat` projects it at
1467 because it discards absolute spans and assumes a blank between every
exchange; the first missing historical separator is between lines 618–619 and
shifts every later exchange by one. The approved direction is therefore to
preserve gaps implied by exchange/item spans and fold only stated item bounds,
removing inferred trailing-margin cleanup (`ARCH-DRY`, `ARCH-PURE`,
`ARCH-PURPOSE`).

Implemented the absolute-span root correction. Parsed question/answer spans now
compile to explicit exchange-leading and intra-exchange gaps; zero-size blocks
contribute neither size nor gap, and streaming replacements derive gaps from
their already-bounded reducer spans. The reported file now projects summary
1466–1466 and the next question at 1468. The inferred trailing-margin cleanup
was removed; a synthetic marginless transcript and a real adjacent streamed
summary both fold only their physical marker rows.

Verification after the correction: exchange-model, projection, fold,
dispatcher, tool-loop, chat-response, mapped `chat/exchange_model`, and mapped
`chat/lifecycle` suites pass; streaming retains its bounded active-segment read.
`make lint` reports 0 warnings/errors across 306 files, `git diff --check`
passes, and `make test JOBS=1` passes every unit, architecture, and integration
spec. Awaiting the operator's exact 1466/1467 smoke test before commit/close.

The operator's 1466/1467 smoke still showed a second fold on the blank row.
The model and fresh projection were correct; a RED integration test proved the
remaining layer was restored window-local manual-fold state. Hydration had been
additive, deleting only folds at currently desired starts, so an orphan at 1467
could not be reached from the desired 1466 range. Initial window hydration now
clears restored manual folds once and rebuilds the complete projection; live
streaming remains changed-exchange-local. The regression measures summary level
1 and blank level 0 (`ARCH-PURE`, `ARCH-PURPOSE`).

Operator smoke verification after restarting Neovim confirmed the reported
folding issue is fixed. The one-line summary folds without capturing its
following blank row; #195 is ready for the close boundary.

## Revisions

### 2026-07-17 — Fresh-eyes spec review

Defined inclusive zero-based projection records and adapter-only Ex conversion;
specified ranged extmark gravity/invalidation plus registry synchronization and
orphan retirement; widened setup/cleanup to the per-window lifecycle; and added
acceptance coverage for late splits, question replacement, exchange deletion,
insertion before an exchange, and buffer-number reuse.

### 2026-07-17 — Plan review identity spike

Direct Neovim experiments disproved the extmark-ledger design: insertion at an
anchor and full-line replacement do not preserve a question-start identity
under one gravity configuration, and a migrated manual fold exposes no fold ID
that endpoint anchors can delete reliably. Replaced persistent ownership with a
localized prepare-before-mutation/reconcile-after-mutation transaction, defined
the exact window-local `zd` behavior and overlap limitation, made late-window
hydration explicitly reparse through one provider, added real consumer/race
tests, and raised the estimate from 2.0h to 3.0h.

### 2026-07-17 — Transaction scope and failure review

Expanded prepare/reconcile across every window displaying the changed buffer;
placed streaming writes and model callbacks inside a dispatcher `around_write`
finally boundary; defined parse-from-buffer recovery without masking the
original error; and added a lightweight per-window initialization registry so
repeat setup/events cannot create duplicate identical folds. Explicitly scoped
external structural-edit rehydration out of this regression.

### 2026-07-18 — Hydration/live-transaction race

Changed hydration from add-once to exact convergence after operator testing
showed that a live tool transaction can create folds before its scheduled
initial hydration. The adapter now removes all native fold layers at projected
semantic starts before rendering one semantic projection, allowing hydration
and later exchange transactions to repair duplicate levels while retaining the
documented overlapping-user-fold limitation.

### 2026-07-18 — Migrated trailing-margin cleanup

Extended the pure projection with model-owned trailing margin rows after smoke
testing showed that an already-migrated one-line ghost sits outside all desired
fold starts. Reconciliation clears those rows before rendering, making the
blank-line invariant self-healing during hydration and live updates.

### 2026-07-18 — Absolute-span root correction

Revised the plan after proving the remaining blank fold is a model coordinate
error, not a migrated Neovim fold. `parsed_chat` already states absolute item
bounds; the model must preserve their implied gaps instead of reconstructing a
canonical document. Fold reconciliation will target only foldable item spans
inside the selected exchange, making inter-exchange gaps irrelevant.

### 2026-07-18 — Deterministic initial hydration

 succeeded in 0ms:
# Localized Semantic Fold Reconciliation Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make semantic folds converge to a pure projection of only the exchange being mutated, without ghost folds or document-wide fold clearing.

**Architecture:** A pure module projects one exchange's model blocks into exact fold ranges. Because Neovim manual folds have no stable IDs after mutation, consumers bracket a known exchange mutation across every window displaying the buffer: delete its old projected folds while intact, perform the buffer/model change, then render its new projection; initial and late-window hydration parse once and render all exchanges with lightweight per-window initialization state.

**Tech Stack:** Lua, Neovim manual folds/window events, Plenary/Busted, `exchange_model`.

---

## Core concepts

### Pure entities

| Name | Kind | Lives in | Status |
|------|------|----------|--------|
| `desired_folds` | PURE | `lua/parley/fold_projection.lua` | new |

- **`desired_folds(model, exchange_index)`** — ordered
  `{ block_index, kind, start_0, end_0 }` records for positive-size thinking,
  summary, tool-use, and tool-result blocks.
  - **Relationships:** One exchange projects to zero or more inclusive
    zero-based ranges; each range refers to one model block.
  - **DRY rationale:** Setup, streaming, and tool-loop share policy and
    coordinates (`ARCH-DRY`, `ARCH-PURE`).
  - **Future extensions:** New foldable semantic kinds widen here only.

### Integration points

| Name | Kind | Lives in | Status | Wraps |
|------|------|----------|--------|-------|
| `prepare_exchange_update` | INTEGRATION | `lua/parley/tool_folds.lua` | new | buffer-window snapshot + window-local `normal! zd` |
| `reconcile_exchange` | INTEGRATION | `lua/parley/tool_folds.lua` | new | window-local `:fold` creation |
| `hydrate_window` | INTEGRATION | `lua/parley/tool_folds.lua` | modified | parser/model provider + initialized registry + window events |
| `around_write` | INTEGRATION | `lua/parley/dispatcher.lua` | new | guaranteed streaming mutation finalization |

- **`prepare_exchange_update`** — snapshots all windows showing the buffer and
  deletes the old projection in each before mutation can shrink or migrate it.
  It visits projected starts in reverse order and runs one `normal! zd` only
  when `foldclosed(start_1)` or `foldlevel(start_1)` proves a fold exists there.
  - **Injected into:** Streaming `before_write` and tool-loop append.
  - **Future extensions:** A synchronous `with_exchange_update` wrapper for
    callers whose mutation is not split across callbacks.
- **`reconcile_exchange`** — renders exactly the current pure projection after
  mutation, in one specified window. It does not inspect other exchanges.
  - **Injected into:** Streaming `after_write`, tool-loop append, and hydration.
  - **Future extensions:** Explicit list of changed exchange indexes.
- **`hydrate_window`** — obtains a fresh model through one provider seam and
  clears restored manual-fold state before rendering every exchange once for a
  newly entered window. A `(buf,win)`
  initialized registry prevents duplicate identical folds and is cleared on
  window/buffer teardown. Live consumers use their current model and never
  reparse on success.
  - **Injected into:** `setup`, `BufWinEnter`, and `WinEnter`.
  - **Future extensions:** None planned.
- **`around_write`** — wraps dispatcher buffer write, line/model callbacks, and
  `after_write` so fold finalization runs on success, empty reductions, and
  thrown callbacks.
  - **Injected into:** `dispatcher.create_handler` options.
  - **Future extensions:** Other buffer-state transactions needing finally.

## Chunk 1: Pure projection and mutation transaction

### Task 1: Extract the pure exchange projection

**Files:**
- Create: `lua/parley/fold_projection.lua`
- Create: `tests/unit/fold_projection_spec.lua`
- Modify: `tests/unit/tool_folds_spec.lua`

- [x] **Step 1: Write RED pure tests**

Build `exchange_model` fixtures for all four foldable kinds, zero-size and
ordinary blocks, margins, multiple blocks, and multiple exchanges. Assert exact
ordered inclusive zero-based records. Load the module with `_G.vim=nil` in a
plain isolated Lua package context to prove purity without brittle source grep.

- [x] **Step 2: Run RED**

Run the exact new spec with `PlenaryBustedFile`; expect module-not-found.

- [x] **Step 3: Implement `desired_folds`**

Own the foldable-kind set only in `fold_projection.lua`; use
`model:block_start/end` and return no Neovim coordinates.

- [x] **Step 4: Run GREEN**

Run the new spec and `tests/unit/tool_folds_spec.lua`; expect all pass and the
old duplicated policy owner removed.

### Task 2: Prove exact `zd` behavior and reproduce the ghost

**Files:**
- Modify: `tests/integration/tool_folds_spec.lua`

- [x] **Step 1: Add RED production-shaped tests**

With a real window/manual folds:

1. create the pre-summary streamed semantic fold, perform the actual
   `stream_replace_at_line`/model-span transition, then use the current add-only
   path and enumerate fold starts to prove the blank-line ghost exists;
2. in two real windows, delete the projected fold before that same mutation,
   render the new summary in both, and assert exactly one summary fold per
   window and none on either following blank line;
3. pin `normal! zd` behavior for open and closed semantic folds;
4. assert adjacent and disjoint user folds survive prepare/reconcile unchanged;
5. document native behavior for nested and partially overlapping user folds
   without promising identity Neovim does not expose.

- [x] **Step 2: Run RED**

Run `tests/integration/tool_folds_spec.lua`; expect the ghost assertion to
reproduce and the prepare/reconcile APIs to be absent.

### Task 3: Implement localized prepare/reconcile

**Files:**
- Modify: `lua/parley/tool_folds.lua`
- Modify: `tests/integration/tool_folds_spec.lua`

- [x] **Step 1: Implement exact old-fold deletion**

`prepare_exchange_update(buf, model, exchange_index)` validates the buffer and
exchange, snapshots `win_findbuf(buf)`, projects old ranges, and in each valid
window visits starts bottom-to-top. At each start it moves the cursor
temporarily and runs `normal! zd` only when a fold level exists; it restores the
cursor. It returns the window snapshot for post-mutation reconciliation and
never runs `zE` or ranges across the exchange.

- [x] **Step 2: Implement exact new-fold rendering**

`reconcile_exchange` projects the current exchange for one window, converts
only at the Ex boundary to one-based inclusive ranges, creates each manual fold,
and closes it. A buffer-scoped finalizer runs it for each surviving snapshot
window. Invalid targets are no-ops. Add a test observer receiving
`{ phase, win, exchange_index, ranges }` for locality assertions.

- [x] **Step 3: Add failure restoration seam**

For synchronous callers, `with_exchange_update(..., mutate)` prepares all
windows, executes `mutate` under `xpcall`, and on success reconciles from the
updated live model. On error it reparses current buffer state through the shared
model provider and attempts restoration; recovery failures leave prepared folds
absent and never replace the original traceback. Add failures after buffer
mutation and after model mutation. Streaming uses the same finalization policy
through `dispatcher.create_handler`'s `around_write` seam.

- [x] **Step 4: Run GREEN**

Run fold unit/integration specs; expect exact summary-only convergence and the
documented user-fold cases.

## Chunk 2: Real consumers and window hydration

### Task 4: Bracket the actual streaming consumer

**Files:**
- Modify: `lua/parley/chat_respond.lua`
- Modify: `tests/integration/chat_respond_spec.lua`

- [x] **Step 1: Add RED streaming locality test**

Through `M.respond` and its real `create_handler`, stream a summary transition
in exchange 2 displayed in two windows while exchange 1 and unrelated user
folds are closed in both. Assert observer sequence prepare/reconcile for
exchange 2 in both windows, no event for exchange 1, exact absence of a
blank-line fold, and unchanged earlier/user folds. Add an empty-reduction chunk,
an injected stream-write failure, and an injected post-model-update failure;
each must run recovery/finalization and preserve the original error. Retain
bounded active-segment read assertions.

- [x] **Step 2: Wire before/after callbacks**

Add `opts.around_write(qid, chunk, write_fn)` to `dispatcher.create_handler` and
place the actual buffer write, `on_lines_changed`, and `after_write` inside
`write_fn`. Chat response supplies a wrapper that prepares exchange 2 in all
snapshot windows, invokes `write_fn`, then always finalizes from the live model
or parse-from-buffer recovery. Ensure `#replacements == 0` still reaches the
finalizer. Delete `_apply_block_fold` use.

- [x] **Step 3: Verify streaming GREEN**

Run `chat_respond_spec.lua`; expect the new sequence/range assertions and all
existing streaming tests to pass.

### Task 5: Bracket the actual tool-loop consumer

**Files:**
- Modify: `lua/parley/tool_loop.lua`
- Create or Modify: `tests/integration/tool_loop_spec.lua`
- Modify: `tests/integration/tool_folds_spec.lua`

- [x] **Step 1: Add RED real-entry-point test**

Call `_append_section_to_answer` with a real two-window buffer/model and
observer. Assert only its supplied `exchange_idx` receives prepare/reconcile in
both windows, the appended tool block folds in both, and other exchange/user
folds are unchanged.

- [x] **Step 2: Use `with_exchange_update`**

Wrap the existing model add plus buffer insert in the shared transaction. Remove
the add-only `_apply_block_fold` call.

- [x] **Step 3: Enforce the single mutation path**

Add an architecture assertion that production code contains no
`_apply_block_fold` and no add-only semantic fold creation outside
`tool_folds.lua`; decide `apply_folds` becomes the hydration wrapper rather than
a parallel incremental API (`ARCH-DRY`, `ARCH-PURPOSE`).

- [x] **Step 4: Verify tool-loop GREEN**

Run exact tool-loop and fold specs; expect all pass.

### Task 6: Hydrate initial and late windows safely

**Files:**
- Modify: `lua/parley/tool_folds.lua`
- Modify: `tests/integration/tool_folds_spec.lua`

- [x] **Step 1: Add RED lifecycle tests**

Inject one `model_provider(buf)` that reparses current lines. Test initial setup,
setup called twice, a second window opened after setup and hydrated via the real
window event, independent window folds, close of window B leaving A unchanged,
and a scheduled hydration callback delivered after buffer deletion/window close
performing no mutation or error.

- [x] **Step 2: Implement idempotent hydration**

`hydrate_window(buf, win, model_provider)` checks validity and the lightweight
initialized registry, configures fold options, obtains one fresh model, and
uses the shared reconciler for every exchange before marking `(buf,win)` done.
`setup` installs one augroup owner for `BufWinEnter`/`WinEnter`, `WinClosed`,
`BufUnload`, and `BufDelete`, and schedules hydration with captured IDs. Repeat
setup/events skip initialized windows; teardown clears the corresponding keys.

- [x] **Step 3: Verify lifecycle GREEN**

Run `tool_folds_spec.lua`; expect all window/race tests pass.

### Task 7: Map, verify, and hand off

**Files:**
- Modify: `atlas/chat/lifecycle.md`
- Modify: `atlas/traceability.yaml`
- Modify: `workshop/issues/000195-reconcile-semantic-folds-exactly.md`

- [x] **Step 1: Update atlas and traceability**

Map pure projection, exchange-local mutation bracketing, real consumers, and
late-window hydration. Add the new pure module/spec and tool-loop integration
test mapping.

- [x] **Step 2: Run focused verification**

Run exact projection, fold, chat-respond, and tool-loop specs; mapped
`make test-spec SPEC=chat/lifecycle`; `make test-changed`; and
`git diff --check`. Expected: all zero.

- [x] **Step 3: Run full verification**

Run `make test`. If the known parallel `tools_builtin_find_spec`/`.test-tmp`
race appears, verify that exact spec and run `make test JOBS=1`; record both.

- [x] **Step 4: Update issue evidence and commit**

Tick plan/issue steps and append RED/GREEN/final evidence. Commit with #195 and
the required co-author trailer. Do not close or land before operator smoke test.

## Revisions

### 2026-07-17 — Plan-review Neovim semantics spike

Removed the infeasible extmark ownership ledger after direct tests showed no
gravity configuration preserves a question-start identity across insertion and
full-line replacement, and endpoint marks cannot identify a migrated manual
fold. Replaced it with prepare-before-mutation/reconcile-after-mutation, named
the exact `normal! zd` selection behavior and overlap boundary, added real
streaming/tool-loop/lifecycle tests plus a model-provider seam, enforced removal
of add-only consumers, and raised the estimate to 3.0h.

### 2026-07-17 — Multi-window and failure-finally correction

Expanded each mutation transaction to snapshot and converge every window
displaying the changed buffer; added dispatcher `around_write` so streaming
finalization covers empty reductions and failures; defined parse-from-buffer
recovery without masking the original error; and added a lightweight
initialized `(buf,win)` registry plus teardown to make hydration idempotent.

### 2026-07-18 — Exact hydration convergence

Operator smoke testing revealed that a live tool transaction can precede its
scheduled initial hydration. Revised hydration and exchange preparation to
retire every native fold layer at projected semantic starts before rendering
one fold, so lifecycle ordering cannot leave duplicate semantic nesting.

### 2026-07-18 — Trailing-margin invariant

Added pure projection of semantic trailing-margin rows and adapter cleanup at
those rows after a smoke test showed an already-migrated blank-line fold has no
desired semantic start through which hydration could otherwise retire it.

## Chunk 3: Use the exchange structure's actual layout

### Core concept correction

The earlier chunks chose the wrong coordinate basis. `parsed_chat` already
records absolute `line_start`/`line_end` for questions and answer sections, but
`exchange_model.from_parsed_chat` discarded those coordinates and rebuilt the
document with a hard-coded one-line gap between every block and exchange. One
missing historical separator therefore shifted every later fold. Clearing
inferred trailing margins treated the symptom and must be removed.

| Name | Kind | Lives in | Status |
|------|------|----------|--------|
| `LayoutGap` | PURE | `lua/parley/exchange_model.lua` | modified |
| `desired_folds` | PURE | `lua/parley/fold_projection.lua` | modified |

- **`LayoutGap`** — nonnegative `gap_before` metadata on exchanges and blocks,
  derived from adjacent absolute parser spans when loading an existing chat.
  New live blocks retain the canonical one-line default, while parsed chats
  preserve zero-, one-, or multi-line historical gaps exactly.
  - **Relationships:** Each exchange exclusively owns the gap before its first
    visible block. The question/first block has `gap_before = 0` and never
    duplicates that leading gap; later blocks own only intra-exchange gaps from
    the preceding visible item. `exchange_total_size` excludes the exchange
    leading gap, while `exchange_start` adds it exactly once after the header or
    previous exchange. Position queries never invent layout.
  - **DRY rationale:** The exchange model remains the one positional source for
    folds, streaming, tool appends, and prompt insertion (`ARCH-DRY`).
  - **Future extensions:** None; gaps are the minimal missing layout fact.
- **`desired_folds`** — continues to project foldable model blocks, but asserts
  every result lies within its exchange's computed bounds. It projects no gap
  or margin rows (`ARCH-PURE`, `ARCH-PURPOSE`).

| Name | Kind | Lives in | Status | Wraps |
|------|------|----------|--------|-------|
| parsed-layout hydration | INTEGRATION | `lua/parley/exchange_model.lua` | modified | `chat_parser` absolute spans |
| streaming span replacement | INTEGRATION | `lua/parley/chat_respond.lua` | modified | reduced active-segment spans |

- **Parsed-layout hydration** derives gaps once from adjacent parser spans;
  folding does not inspect buffer text or reconstruct the whole document.
- **Streaming span replacement** supplies the reduced sections' relative gaps
  to `replace_span`; it still reads only the active segment and updates only the
  known changed exchange.

### Task 8: Preserve actual gaps in the exchange model

**Files:**
- Modify: `lua/parley/exchange_model.lua`
- Modify: `tests/unit/exchange_model_spec.lua`

- [x] **Step 1: Write the RED coordinate regression**

Build a parsed-chat fixture whose first exchange summary is immediately
followed by the next question. Assert that `from_parsed_chat` places both at
their recorded absolute rows, plus cases for canonical one-line and multi-line
gaps within/between exchanges. Expected current failure: the second question
and its summary are projected one row too low.

- [x] **Step 2: Implement explicit gap arithmetic**

Store `gap_before` on each exchange and block. `exchange_start`,
`exchange_total_size`, `block_start`, `append_pos`, and replacement math sum
stored gaps only for positive-size visible items; a zero-size block contributes
neither content nor its stored gap, preserving the existing empty-block
invisibility invariant. `new`/`add_exchange`/`add_block` preserve current canonical defaults;
`from_parsed_chat` derives gaps as `current_start - previous_end - 1` from the
recorded spans. Reject negative gaps because overlapping items violate the
exchange structure.

The ownership formula is explicit: `exchange.gap_before` alone positions block
1; block 1's gap is always zero. `exchange_total_size` sums visible block sizes
and only visible blocks 2..N's intra-exchange gaps. `exchange_start(1)` is

exec
/bin/zsh -lc 'git diff --stat 3974fa25cec1aa5a0f1624297d69bee8529a0e4e..HEAD && git diff --name-only 3974fa25cec1aa5a0f1624297d69bee8529a0e4e..HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
 atlas/chat/exchange_model.md                       |  35 ++-
 atlas/chat/lifecycle.md                            |  28 ++-
 atlas/traceability.yaml                            |   6 +
 lua/parley/artifact_ref.lua                        |  30 +++
 lua/parley/chat_respond.lua                        |  13 +-
 lua/parley/dispatcher.lua                          |   7 +
 lua/parley/exchange_model.lua                      |  86 ++++---
 lua/parley/fold_projection.lua                     |  36 +++
 lua/parley/init.lua                                |   6 +-
 lua/parley/keybinding_registry.lua                 |   2 +-
 lua/parley/tool_folds.lua                          | 177 ++++++++++----
 lua/parley/tool_loop.lua                           |  23 +-
 tests/integration/chat_respond_spec.lua            |  30 +++
 tests/integration/create_handler_spec.lua          |  20 ++
 tests/integration/tool_folds_spec.lua              | 202 +++++++++++++---
 tests/unit/artifact_ref_spec.lua                   |  53 +++++
 tests/unit/exchange_model_spec.lua                 |  74 ++++++
 tests/unit/fold_projection_spec.lua                |  43 ++++
 tests/unit/tool_folds_spec.lua                     |  15 +-
 .../000195-reconcile-semantic-folds-exactly.md     | 103 +++++++-
 ...000195-reconcile-semantic-folds-exactly-plan.md | 261 +++++++++++++++++++--
 21 files changed, 1067 insertions(+), 183 deletions(-)
atlas/chat/exchange_model.md
atlas/chat/lifecycle.md
atlas/traceability.yaml
lua/parley/artifact_ref.lua
lua/parley/chat_respond.lua
lua/parley/dispatcher.lua
lua/parley/exchange_model.lua
lua/parley/fold_projection.lua
lua/parley/init.lua
lua/parley/keybinding_registry.lua
lua/parley/tool_folds.lua
lua/parley/tool_loop.lua
tests/integration/chat_respond_spec.lua
tests/integration/create_handler_spec.lua
tests/integration/tool_folds_spec.lua
tests/unit/artifact_ref_spec.lua
tests/unit/exchange_model_spec.lua
tests/unit/fold_projection_spec.lua
tests/unit/tool_folds_spec.lua
workshop/issues/000195-reconcile-semantic-folds-exactly.md
workshop/plans/000195-reconcile-semantic-folds-exactly-plan.md

exec
/bin/zsh -lc "nl -ba lua/parley/dispatcher.lua | sed -n '520,620p'" in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc "nl -ba lua/parley/exchange_model.lua | sed -n '1,360p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   520		return vim.schedule_wrap(function(qid, chunk)
   521			local qt = tasker.get_query(qid)
   522			if not qt then
   523				return
   524			end
   525			-- if buf is not valid, stop
   526			if not vim.api.nvim_buf_is_valid(buf) then
   527				return
   528			end
   529			if not qt.ns_id then
   530				qt.ns_id = ns_id
   531			end
   532
   533			if not qt.ex_id then
   534				qt.ex_id = ex_id
   535			end
   536
   537			if type(chunk) ~= "string" then
   538				return
   539			end
   540			if opts.before_write and not opts.before_write(qid, chunk) then
   541				return
   542			end
   543			local function write()
   544			-- undojoin takes previous change into account, so skip it for the first chunk
   545			if skip_first_undojoin then
   546				skip_first_undojoin = false
   547			else
   548				helpers.undojoin(buf)
   549			end
   550
   551			first_line = vim.api.nvim_buf_get_extmark_by_id(buf, ns_id, ex_id, {})[1]
   552
   553			local buffer_edit = require("parley.buffer_edit")
   554			local previous_pending_index = finished_lines
   555			local completed, new_pending
   556			local delta
   557			if has_started then
   558				completed, new_pending = split_pending_and_completed(pending_line .. chunk)
   559				table.insert(completed, new_pending)
   560				local replacement = with_prefix(completed)
   561				local start_line = first_line + finished_lines
   562				buffer_edit.stream_replace_at_line(buf, start_line, replacement)
   563				delta = #completed - 1
   564				finished_lines = finished_lines + delta
   565			else
   566				-- Strip leading newlines from the first chunk for consistent spacing across providers
   567				chunk = chunk:gsub("^\n+", "")
   568				completed, new_pending = split_pending_and_completed(chunk)
   569				table.insert(completed, new_pending)
   570				local replacement = with_prefix(completed)
   571				buffer_edit.stream_replace_at_line(buf, first_line, replacement)
   572				delta = #completed - 1
   573				finished_lines = delta
   574				has_started = true
   575			end
   576			if on_lines_changed and delta > 0 then
   577				on_lines_changed(delta)
   578			end
   579			local end_line = first_line + finished_lines + 1
   580			qt.first_line = first_line
   581			qt.last_line = end_line - 1
   582			if opts.after_write then
   583				opts.after_write(qid, chunk, delta, end_line - 1)
   584			end
   585			pending_line = new_pending
   586			helpers.undojoin(buf)
   587
   588			for i = previous_pending_index, finished_lines do
   589				vim.api.nvim_buf_add_highlight(buf, qt.ns_id, hl_handler_group, first_line + i, 0, -1)
   590			end
   591
   592			-- move cursor to the end of the response
   593			local should_move_cursor
   594			if type(cursor) == "function" then
   595				should_move_cursor = cursor()
   596			else
   597				should_move_cursor = cursor
   598			end
   599			if should_move_cursor then
   600				helpers.cursor_to_line(end_line, buf, win)
   601			end
   602			end
   603			if opts.around_write then
   604				opts.around_write(qid, chunk, write)
   605			else
   606				write()
   607			end
   608		end)
   609	end
   610
   611	return D

 succeeded in 0ms:
     1	-- Pure positional model for chat buffer layout.
     2	--
     3	-- Tracks exchange/block sizes and computes absolute 0-indexed buffer
     4	-- line positions. No nvim API — this module is fully testable without
     5	-- a running Neovim instance.
     6	--
     7	-- The model is the single source of truth for "where does block S
     8	-- of exchange K live in the buffer?" Callers mutate the model (add
     9	-- blocks, grow blocks) and the model recomputes positions on demand
    10	-- from accumulated sizes. No absolute line numbers are ever stored —
    11	-- sizes and the gaps recorded before visible items.
    12	--
    13	-- See #90 design: size-based architecture.
    14	--
    15	-- Rules:
    16	--   1. Everything is a block (question, agent_header, text, tool_use,
    17	--      tool_result, spinner, thinking, note, ...).
    18	--   2. Parsed blocks preserve their actual preceding gaps; new blocks default
    19	--      to one blank line.
    20	--   3. Empty blocks contribute neither content nor gap.
    21	--
    22	-- Layout convention:
    23	--   HEADER (header_lines lines)
    24	--   MARGIN (1 blank)
    25	--   EXCHANGE 1:
    26	--     block 1: question (size lines)
    27	--     MARGIN (1 blank)
    28	--     block 2: agent_header (1 line)
    29	--     MARGIN (1 blank)
    30	--     block 3: text (size lines)
    31	--     MARGIN (1 blank) — only between non-empty blocks
    32	--     block 4: tool_use (size lines)
    33	--     ...
    34	--   MARGIN (1 blank) — between exchanges
    35	--   EXCHANGE 2:
    36	--     ...
    37
    38	local MARGIN = 1  -- blank line between non-empty blocks
    39
    40	local Model = {}
    41	Model.__index = Model
    42
    43	local M = {}
    44
    45	local function last_nonempty_block_index(exchange)
    46	    for i = #exchange.blocks, 1, -1 do
    47	        if exchange.blocks[i].size > 0 then
    48	            return i
    49	        end
    50	    end
    51	    return nil
    52	end
    53
    54	--- Create a new empty model.
    55	--- @param header_lines integer  number of header lines (e.g. 4 for ---/topic/file/---)
    56	--- @return Model
    57	function M.new(header_lines)
    58	    return setmetatable({
    59	        header_lines = header_lines,
    60	        exchanges = {},
    61	    }, Model)
    62	end
    63
    64	--- Add an exchange. The question is block 1 (always present).
    65	--- @param question_size integer  number of lines the question occupies
    66	function Model:add_exchange(question_size, gap_before)
    67	    table.insert(self.exchanges, {
    68	        gap_before = gap_before == nil and MARGIN or gap_before,
    69	        blocks = {
    70	            { kind = "question", size = question_size, gap_before = 0 },
    71	        },
    72	    })
    73	end
    74
    75	--- Add a block to exchange K. Returns the 0-indexed buffer line where
    76	--- the block content should be inserted.
    77	--- @param k integer  exchange index (1-based)
    78	--- @param kind string  block kind (agent_header/text/tool_use/tool_result/spinner/...)
    79	--- @param size integer  number of lines the block occupies
    80	--- @return integer  0-indexed insert position
    81	function Model:add_block(k, kind, size, gap_before)
    82	    local pos = self:append_pos(k)
    83	    table.insert(self.exchanges[k].blocks, {
    84	        kind = kind,
    85	        size = size,
    86	        gap_before = gap_before == nil and MARGIN or gap_before,
    87	    })
    88	    return pos
    89	end
    90
    91	--- Grow a block's size by delta lines (e.g. streaming added content).
    92	--- @param k integer  exchange index
    93	--- @param b integer  block index within exchange K
    94	--- @param delta integer  number of lines to add
    95	function Model:grow_block(k, b, delta)
    96	    self.exchanges[k].blocks[b].size = self.exchanges[k].blocks[b].size + delta
    97	end
    98
    99	--- Update a block's size to an exact value.
   100	function Model:set_block_size(k, b, new_size)
   101	    self.exchanges[k].blocks[b].size = new_size
   102	end
   103
   104	--- Remove a block from exchange K. All subsequent block positions
   105	--- shift automatically since they're computed from sizes.
   106	--- @param k integer  exchange index
   107	--- @param b integer  block index to remove
   108	function Model:remove_block(k, b)
   109	    table.remove(self.exchanges[k].blocks, b)
   110	end
   111
   112	--- Replace a contiguous block span with semantic sections.
   113	--- Returns the 1-based indices of every inserted block.
   114	function Model:replace_span(k, first_block, old_count, sections)
   115	    local exchange = assert(self.exchanges[k], "invalid exchange index")
   116	    assert(type(first_block) == "number" and type(old_count) == "number" and old_count >= 0,
   117	        "invalid replacement span")
   118	    assert(first_block >= 1 and first_block <= #exchange.blocks + 1, "invalid replacement start")
   119	    assert(first_block + old_count - 1 <= #exchange.blocks, "replacement exceeds exchange")
   120	    sections = sections or {}
   121	    for _, section in ipairs(sections) do
   122	        assert(type(section.kind) == "string" and type(section.size) == "number" and section.size >= 0,
   123	            "invalid replacement section")
   124	        assert(section.gap_before == nil or (type(section.gap_before) == "number" and section.gap_before >= 0),
   125	            "invalid replacement gap")
   126	    end
   127	    local inherited_gap = exchange.blocks[first_block] and exchange.blocks[first_block].gap_before or MARGIN
   128	    for _ = 1, old_count do table.remove(exchange.blocks, first_block) end
   129	    local changed = {}
   130	    for offset, section in ipairs(sections) do
   131	        local index = first_block + offset - 1
   132	        local gap_before = section.gap_before
   133	        if gap_before == nil then
   134	            gap_before = offset == 1 and inherited_gap or MARGIN
   135	        end
   136	        table.insert(exchange.blocks, index, {
   137	            kind = section.kind,
   138	            size = section.size,
   139	            gap_before = gap_before,
   140	        })
   141	        changed[#changed + 1] = index
   142	    end
   143	    return changed
   144	end
   145
   146	-- ============================================================================
   147	-- Position queries (all return 0-indexed buffer line)
   148	-- ============================================================================
   149
   150	--- Total size of exchange K in buffer lines (all non-empty blocks +
   151	--- margins between them).
   152	function Model:exchange_total_size(k)
   153	    local size = 0
   154	    local has_prev = false
   155	    for _, blk in ipairs(self.exchanges[k].blocks) do
   156	        if blk.size > 0 then
   157	            if has_prev then size = size + (blk.gap_before or MARGIN) end
   158	            size = size + blk.size
   159	            has_prev = true
   160	        end
   161	    end
   162	    return size
   163	end
   164
   165	--- 0-indexed buffer line where exchange K starts (= where its first
   166	--- non-empty block starts).
   167	function Model:exchange_start(k)
   168	    local line = self.header_lines
   169	    for i = 1, k do
   170	        line = line + (self.exchanges[i].gap_before or MARGIN)
   171	        if i == k then return line end
   172	        line = line + self:exchange_total_size(i)
   173	    end
   174	end
   175
   176	--- 0-indexed buffer line where block B of exchange K starts.
   177	--- Skips empty blocks (they're invisible per rule 3).
   178	function Model:block_start(k, b)
   179	    local line = self:exchange_start(k)
   180	    local has_prev = false
   181	    for i = 1, b do
   182	        local blk = self.exchanges[k].blocks[i]
   183	        if blk.size > 0 then
   184	            if has_prev then line = line + (blk.gap_before or MARGIN) end
   185	            if i == b then return line end
   186	            line = line + blk.size
   187	            has_prev = true
   188	        elseif i == b then
   189	            return line
   190	        end
   191	    end
   192	    return line
   193	end
   194
   195	--- 0-indexed buffer line of the last line of block B.
   196	function Model:block_end(k, b)
   197	    return self:block_start(k, b) + self.exchanges[k].blocks[b].size - 1
   198	end
   199
   200	--- 0-indexed last line of the final visible block, or nil if none is visible.
   201	function Model:last_nonempty_block_end(k)
   202	    local block_index = last_nonempty_block_index(self.exchanges[k])
   203	    if not block_index then
   204	        return nil
   205	    end
   206	    return self:block_end(k, block_index)
   207	end
   208
   209	--- 0-indexed buffer line where the NEXT block would be inserted
   210	--- (after all existing blocks + margin).
   211	function Model:append_pos(k)
   212	    if #self.exchanges[k].blocks == 0 then
   213	        return self:exchange_start(k)
   214	    end
   215	    local last_end = self:last_nonempty_block_end(k)
   216	    if last_end then
   217	        return last_end + 1 + MARGIN
   218	    end
   219	    -- All blocks are empty — append at exchange start + margin
   220	    return self:exchange_start(k) + MARGIN
   221	end
   222
   223	-- ============================================================================
   224	-- Convenience aliases (backward compat with callers using old API names)
   225	-- ============================================================================
   226
   227	--- @deprecated Use add_block
   228	function Model:add_section(k, kind, size)
   229	    return self:add_block(k, kind, size)
   230	end
   231
   232	--- @deprecated Use grow_block
   233	function Model:grow_section(k, s, delta)
   234	    return self:grow_block(k, s, delta)
   235	end
   236
   237	--- @deprecated Use remove_block
   238	function Model:remove_section(k, s)
   239	    return self:remove_block(k, s)
   240	end
   241
   242	--- @deprecated Use block_start
   243	function Model:section_start(k, s)
   244	    return self:block_start(k, s)
   245	end
   246
   247	--- @deprecated Use block_end
   248	function Model:section_end(k, s)
   249	    return self:block_end(k, s)
   250	end
   251
   252	--- @deprecated Use append_pos
   253	function Model:answer_append_pos(k)
   254	    return self:append_pos(k)
   255	end
   256
   257	--- Convenience: question_size is blocks[1].size
   258	function Model:question_size(k)
   259	    return self.exchanges[k].blocks[1].size
   260	end
   261
   262	--- Convenience: grow question (block 1) size.
   263	function Model:grow_question(k, delta)
   264	    self:grow_block(k, 1, delta)
   265	end
   266
   267	-- ============================================================================
   268	-- Load from parser output
   269	-- ============================================================================
   270
   271	--- Build a model from a parsed_chat structure. Infers sizes from the
   272	--- parser's recorded line spans.
   273	--- @param parsed_chat table  output of chat_parser.parse_chat
   274	--- @return Model
   275	function M.from_parsed_chat(parsed_chat)
   276	    local header_lines = parsed_chat.header_end or 0
   277	    local model = M.new(header_lines)
   278	    local previous_exchange_end
   279	    for _, ex in ipairs(parsed_chat.exchanges or {}) do
   280	        local q_size = 1
   281	        local question_start = ex.question and ex.question.line_start or (header_lines + MARGIN + 1)
   282	        local question_end = question_start + q_size - 1
   283	        if ex.question then
   284	            q_size = ex.question.line_end - ex.question.line_start + 1
   285	            question_end = ex.question.line_end
   286	        end
   287	        local gap_before
   288	        if previous_exchange_end then
   289	            gap_before = question_start - previous_exchange_end - 1
   290	        else
   291	            gap_before = question_start - header_lines - 1
   292	        end
   293	        assert(gap_before >= 0, "overlapping exchange spans")
   294	        model:add_exchange(q_size, gap_before)
   295	        local previous_block_end = question_end
   296	        if ex.answer then
   297	            local k = #model.exchanges
   298	            -- Agent header is the first answer block (🤖: line, 1 line)
   299	            local answer_start = ex.answer.line_start
   300	            local answer_gap = answer_start - previous_block_end - 1
   301	            assert(answer_gap >= 0, "overlapping answer spans")
   302	            model:add_block(k, "agent_header", 1, answer_gap)
   303	            previous_block_end = answer_start
   304	            for _, sec in ipairs(ex.answer.semantic_sections or ex.answer.sections or {}) do
   305	                local sec_size = 1
   306	                if sec.line_start and sec.line_end then
   307	                    sec_size = sec.line_end - sec.line_start + 1
   308	                end
   309	                local section_start = sec.line_start or (previous_block_end + MARGIN + 1)
   310	                local section_end = sec.line_end or (section_start + sec_size - 1)
   311	                local section_gap = section_start - previous_block_end - 1
   312	                assert(section_gap >= 0, "overlapping answer section spans")
   313	                model:add_block(k, sec.kind or sec.type or "text", sec_size, section_gap)
   314	                previous_block_end = section_end
   315	            end
   316	        end
   317	        previous_exchange_end = previous_block_end
   318	    end
   319	    return model
   320	end
   321
   322	return M

exec
/bin/zsh -lc "nl -ba lua/parley/tool_folds.lua | sed -n '1,260p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
     1	-- Chat buffer folding for parley.
     2	--
     3	-- Uses a pure exchange-model projection to compute fold regions. Thinking,
     4	-- summary, tool-use, and tool-result blocks fold; questions, ordinary answer
     5	-- text, and agent headers do not.
     6	--
     7	-- foldmethod=manual — folds are created explicitly from model positions.
     8	-- No foldexpr evaluation, no backward scanning.
     9
    10	local M = {}
    11	local projection = require("parley.fold_projection")
    12	local initialized = {}
    13
    14	local function valid_target(buf, win)
    15	    return vim.api.nvim_buf_is_valid(buf)
    16	        and vim.api.nvim_win_is_valid(win)
    17	        and vim.api.nvim_win_get_buf(win) == buf
    18	end
    19
    20	local function notify(event)
    21	    if M._observer then M._observer(event) end
    22	end
    23
    24	local function delete_projected_folds(buf, win, ranges)
    25	    if not valid_target(buf, win) then return end
    26	    vim.api.nvim_win_call(win, function()
    27	        local cursor = vim.api.nvim_win_get_cursor(win)
    28	        for index = #ranges, 1, -1 do
    29	            local row = ranges[index].start_0 + 1
    30	            vim.api.nvim_win_set_cursor(win, { row, 0 })
    31	            while vim.fn.foldlevel(row) > 0 do
    32	                vim.cmd("normal! zd")
    33	            end
    34	        end
    35	        local line_count = vim.api.nvim_buf_line_count(buf)
    36	        vim.api.nvim_win_set_cursor(win, { math.min(cursor[1], line_count), cursor[2] })
    37	    end)
    38	end
    39
    40	function M.reconcile_exchange(buf, win, model, exchange_index)
    41	    if not valid_target(buf, win) or not model.exchanges[exchange_index] then return false end
    42	    local ranges = projection.desired_folds(model, exchange_index)
    43	    vim.api.nvim_win_call(win, function()
    44	        vim.api.nvim_set_option_value("foldminlines", 0, { win = win })
    45	        for _, range in ipairs(ranges) do
    46	            vim.cmd(string.format("%d,%dfold", range.start_0 + 1, range.end_0 + 1))
    47	        end
    48	    end)
    49	    notify({ phase = "reconcile", win = win, exchange_index = exchange_index, ranges = ranges })
    50	    return true
    51	end
    52
    53	function M.prepare_exchange_update(buf, model, exchange_index)
    54	    if not vim.api.nvim_buf_is_valid(buf) or not model.exchanges[exchange_index] then return {} end
    55	    local ranges = projection.desired_folds(model, exchange_index)
    56	    local windows = vim.fn.win_findbuf(buf) or {}
    57	    for _, win in ipairs(windows) do
    58	        if valid_target(buf, win) then
    59	            delete_projected_folds(buf, win, ranges)
    60	            notify({ phase = "prepare", win = win, exchange_index = exchange_index, ranges = ranges })
    61	        end
    62	    end
    63	    return windows
    64	end
    65
    66	function M.finalize_exchange_update(buf, windows, model, exchange_index)
    67	    for _, win in ipairs(windows or {}) do
    68	        M.reconcile_exchange(buf, win, model, exchange_index)
    69	    end
    70	end
    71
    72	local function default_model_provider(buf)
    73	    local chat_parser = require("parley.chat_parser")
    74	    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    75	    local header_end = chat_parser.find_header_end(lines)
    76	    if not header_end then return nil end
    77	    local parsed = chat_parser.parse_chat(lines, header_end, require("parley.config"))
    78	    return require("parley.exchange_model").from_parsed_chat(parsed)
    79	end
    80
    81	function M.with_exchange_update(buf, model, exchange_index, mutate)
    82	    local windows = M.prepare_exchange_update(buf, model, exchange_index)
    83	    local result
    84	    local ok, err = xpcall(function() result = mutate() end, debug.traceback)
    85	    local final_model = model
    86	    if not ok then
    87	        local recovered, parsed = pcall(M._model_provider or default_model_provider, buf)
    88	        final_model = recovered and parsed or nil
    89	    end
    90	    if ok then
    91	        M.finalize_exchange_update(buf, windows, final_model, exchange_index)
    92	    else
    93	        if final_model then
    94	            for _, win in ipairs(windows) do
    95	                pcall(M.reconcile_exchange, buf, win, final_model, exchange_index)
    96	            end
    97	        end
    98	        error(err, 0)
    99	    end
   100	    return result
   101	end
   102
   103	--- Compute and apply folds from the exchange model.
   104	--- @param buf integer
   105	function M.apply_folds(buf, win, model_provider)
   106	    if not vim.api.nvim_buf_is_valid(buf) then return false end
   107	    local model = (model_provider or M._model_provider or default_model_provider)(buf)
   108	    if not model then return false end
   109	    local windows = win and { win } or vim.fn.win_findbuf(buf)
   110	    for k in ipairs(model.exchanges) do
   111	        for _, target_win in ipairs(windows) do
   112	            M.reconcile_exchange(buf, target_win, model, k)
   113	        end
   114	    end
   115	    return true
   116	end
   117
   118	function M.hydrate_window(buf, win, model_provider)
   119	    if not valid_target(buf, win) then return false end
   120	    initialized[buf] = initialized[buf] or {}
   121	    if initialized[buf][win] then return false end
   122	    vim.api.nvim_set_option_value("foldmethod", "manual", { win = win })
   123	    vim.api.nvim_set_option_value("foldtext", "v:lua.require('parley.tool_folds').foldtext()", { win = win })
   124	    vim.api.nvim_set_option_value("foldcolumn", "1", { win = win })
   125	    vim.api.nvim_set_option_value("foldminlines", 0, { win = win })
   126	    local provider = model_provider or M._model_provider or default_model_provider
   127	    local model = provider(buf)
   128	    if not model then return false end
   129	    vim.api.nvim_win_call(win, function()
   130	        vim.cmd("normal! zE")
   131	    end)
   132	    for exchange_index in ipairs(model.exchanges) do
   133	        M.reconcile_exchange(buf, win, model, exchange_index)
   134	    end
   135	    initialized[buf][win] = true
   136	    return true
   137	end
   138
   139	--- Custom fold text.
   140	function M.foldtext()
   141	    local start_line = vim.fn.getline(vim.v.foldstart)
   142	    local line_count = vim.v.foldend - vim.v.foldstart + 1
   143
   144	    if start_line:match("^🔧:") then
   145	        local name = start_line:match("^🔧:%s*(%S+)") or "tool"
   146	        return string.format("🔧 %s (%d lines) ", name, line_count)
   147	    elseif start_line:match("^📎:") then
   148	        local name = start_line:match("^📎:%s*(%S+)") or "result"
   149	        local is_error = start_line:match("error=true") and " error" or ""
   150	        return string.format("📎 %s%s (%d lines) ", name, is_error, line_count)
   151	    elseif start_line:match("^🧠:") then
   152	        return "🧠 thinking (" .. line_count .. " lines) "
   153	    elseif start_line:match("^📝:") then
   154	        return "📝 summary (" .. line_count .. " lines) "
   155	    else
   156	        local preview = start_line:sub(1, 60)
   157	        if #start_line > 60 then preview = preview .. "..." end
   158	        return preview .. " (" .. line_count .. " lines) "
   159	    end
   160	end
   161
   162	--- Set up folding on a chat buffer.
   163	function M.setup(buf)
   164	    local group = vim.api.nvim_create_augroup("ParleyToolFolds" .. buf, { clear = true })
   165	    vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
   166	        group = group,
   167	        callback = function(args)
   168	            if args.buf ~= buf then return end
   169	            local target = vim.api.nvim_get_current_win()
   170	            vim.schedule(function() M.hydrate_window(buf, target) end)
   171	        end,
   172	    })
   173	    vim.api.nvim_create_autocmd("WinClosed", {
   174	        group = group,
   175	        callback = function(args)
   176	            local closed = tonumber(args.match)
   177	            if initialized[buf] then initialized[buf][closed] = nil end
   178	        end,
   179	    })
   180	    vim.api.nvim_create_autocmd({ "BufUnload", "BufDelete" }, {
   181	        group = group, buffer = buf,
   182	        callback = function() initialized[buf] = nil end,
   183	    })
   184	    local win = vim.api.nvim_get_current_win()
   185	    vim.schedule(function()
   186	        M.hydrate_window(buf, win)
   187	    end)
   188	end
   189
   190	return M

exec
/bin/zsh -lc "nl -ba lua/parley/chat_respond.lua | sed -n '1660,1735p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
  1660	            local has_reasoning_end = false
  1661	            for _, line in ipairs(current_lines) do
  1662	                if require("parley.highlight_structure").classify(line, patterns).kind == "reasoning_end" then
  1663	                    has_reasoning_end = true
  1664	                    break
  1665	                end
  1666	            end
  1667	            if has_reasoning_end and provisional_thinking_idx then
  1668	                first_block = provisional_thinking_idx
  1669	                first_line = model:block_start(target_idx, first_block)
  1670	                current_lines = vim.api.nvim_buf_get_lines(buf, first_line, last_written_line_0 + 1, false)
  1671	            end
  1672	            if M._stream_reconcile_observer then
  1673	                M._stream_reconcile_observer({
  1674	                    first_line = first_line,
  1675	                    last_line = last_written_line_0,
  1676	                    rows_visited = #current_lines,
  1677	                    widened = first_block == provisional_thinking_idx,
  1678	                })
  1679	            end
  1680	            local reduced = require("parley.answer_structure").reduce(current_lines, patterns, { streaming = true })
  1681	            local replacements = {}
  1682	            local previous_end_0 = first_block > 1 and model:block_end(target_idx, first_block - 1) or nil
  1683	            for _, section in ipairs(reduced.sections) do
  1684	                local section_start_0 = first_line + section.line_start - 1
  1685	                local section_end_0 = first_line + section.line_end - 1
  1686	                replacements[#replacements + 1] = {
  1687	                    kind = section.kind,
  1688	                    size = section.line_end - section.line_start + 1,
  1689	                    gap_before = previous_end_0 and (section_start_0 - previous_end_0 - 1) or 0,
  1690	                }
  1691	                previous_end_0 = section_end_0
  1692	            end
  1693	            if #replacements == 0 then return end
  1694	            local old_count = stream_block_idx - first_block + 1
  1695	            local changed = model:replace_span(target_idx, first_block, old_count, replacements)
  1696	            stream_block_idx = changed[#changed]
  1697	            if has_reasoning_end then
  1698	                provisional_thinking_idx = nil
  1699	            elseif #replacements >= 2 and replacements[#replacements - 1].kind == "thinking"
  1700	                and replacements[#replacements].kind == "text" then
  1701	                provisional_thinking_idx = changed[#changed - 1]
  1702	            end
  1703	        end
  1704	        local base_handler = _parley.dispatcher.create_handler(buf, win, response_start_line, true, "", function()
  1705	            return is_follow_cursor_enabled(override_free_cursor)
  1706	        end, on_stream_lines_changed, {
  1707	            before_write = function(_qid, _chunk)
  1708	                if not lease_valid() then
  1709	                    return false
  1710	                end
  1711	                return pending_session:before_write()
  1712	            end,
  1713	            after_write = function(_qid, _chunk, _delta, last_written_line_0)
  1714	                reconcile_stream_span(last_written_line_0)
  1715	                pending_session:tip_written(last_written_line_0)
  1716	                lease_commit()
  1717	            end,
  1718	            around_write = function(_qid, _chunk, write)
  1719	                return require("parley.tool_folds").with_exchange_update(
  1720	                    buf, model, target_idx, write)
  1721	            end,
  1722	        })
  1723	        local response_handler = function(qid, chunk) pending_session:content(qid, chunk) end
  1724
  1725	        -- Shared empty-answer collapse (#131): used by on_exit (tool-use-only /
  1726	        -- empty response) AND on_abort, so a failed managed-cliproxy start tears
  1727	        -- down the same inserted stream placeholder instead of leaving it.
  1728	        local function collapse_empty_answer()
  1729	            if not stream_block_idx then
  1730	                return
  1731	            end
  1732	            local sblk = model.exchanges[target_idx].blocks[stream_block_idx]
  1733	            if sblk and sblk.size == 1 then
  1734	                local spos = model:block_start(target_idx, stream_block_idx)
  1735	                local sline = vim.api.nvim_buf_get_lines(buf, spos, spos + 1, false)[1] or ""

exec
/bin/zsh -lc "rg -n \"semantic_sections|sections|answer =|line_start\" lua/parley/chat_parser.lua lua/parley/answer_structure.lua tests -g'*chat_parser*'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
lua/parley/answer_structure.lua:43:    local sections = {}
lua/parley/answer_structure.lua:47:            sections[#sections + 1] = { kind = kind, line_start = first, line_end = last }
lua/parley/answer_structure.lua:112:    return { sections = sections, work = { rows_visited = #lines }, streaming = opts.streaming == true }
lua/parley/chat_parser.lua:157:--       question = { line_start = N, line_end = N, content = "text",
lua/parley/chat_parser.lua:159:--       answer   = { line_start = N, line_end = N, content = "text" },  -- or nil
lua/parley/chat_parser.lua:215:		local q_start = ex.question and ex.question.line_start or math.huge
lua/parley/chat_parser.lua:236:		and parsed.exchanges[idx].answer.sections
lua/parley/chat_parser.lua:239:		if line_no >= s.line_start and line_no <= s.line_end then
lua/parley/chat_parser.lua:250:	if not ex or not ex.answer or not ex.answer.sections then
lua/parley/chat_parser.lua:253:	return ex.answer.sections[#ex.answer.sections]
lua/parley/chat_parser.lua:314:				if boundary and boundary > current_exchange[current_component].line_start then
lua/parley/chat_parser.lua:315:					local keep_count = boundary - current_exchange[current_component].line_start
lua/parley/chat_parser.lua:328:			while trimmed_end > current_exchange[current_component].line_start
lua/parley/chat_parser.lua:360:		-- line_start is set lazily on the first cb_append_line so that
lua/parley/chat_parser.lua:363:		cb_state.current_line_start = nil
lua/parley/chat_parser.lua:410:			local trimmed_start = cb_state.current_line_start
lua/parley/chat_parser.lua:421:			block.line_start = trimmed_start
lua/parley/chat_parser.lua:427:		cb_state.current_line_start = nil
lua/parley/chat_parser.lua:449:		-- Lazy line_start: the first line we see is where the block begins.
lua/parley/chat_parser.lua:450:		if cb_state.current_line_start == nil then
lua/parley/chat_parser.lua:451:			cb_state.current_line_start = line_no
lua/parley/chat_parser.lua:481:			current_exchange.answer.sections = cb_state.blocks
lua/parley/chat_parser.lua:484:			local body_start = current_exchange.answer.line_start + 1
lua/parley/chat_parser.lua:490:			current_exchange.answer.semantic_sections = {}
lua/parley/chat_parser.lua:491:			for _, section in ipairs(reduced.sections) do
lua/parley/chat_parser.lua:492:				current_exchange.answer.semantic_sections[#current_exchange.answer.semantic_sections + 1] = {
lua/parley/chat_parser.lua:495:					line_start = body_start + section.line_start - 1,
lua/parley/chat_parser.lua:574:					line_start = i,
lua/parley/chat_parser.lua:579:				answer = nil
lua/parley/chat_parser.lua:629:						line_start = header_end + 1,
lua/parley/chat_parser.lua:633:					answer = nil
lua/parley/chat_parser.lua:639:			current_exchange.answer = {
lua/parley/chat_parser.lua:640:				line_start = i,
tests/unit/chat_parser_section_lines_spec.lua:1:-- Unit tests for chat_parser line spans on answer sections.
tests/unit/chat_parser_section_lines_spec.lua:3:-- Each section in answer.sections (alias content_blocks) gains
tests/unit/chat_parser_section_lines_spec.lua:4:-- line_start and line_end tracking the buffer span the section
tests/unit/chat_parser_section_lines_spec.lua:28:        local secs = p.exchanges[1].answer.sections
tests/unit/chat_parser_section_lines_spec.lua:31:        assert.equals(9, secs[1].line_start)
tests/unit/chat_parser_section_lines_spec.lua:55:        local secs = p.exchanges[1].answer.sections
tests/unit/chat_parser_section_lines_spec.lua:58:        assert.equals(9, secs[1].line_start)
tests/unit/chat_parser_section_lines_spec.lua:61:        assert.equals(13, secs[2].line_start)
tests/unit/chat_parser_section_lines_spec.lua:65:    it("text + tool_use + tool_result + text yields 4 sections in order", function()
tests/unit/chat_parser_section_lines_spec.lua:83:        local secs = p.exchanges[1].answer.sections
tests/unit/chat_parser_section_lines_spec.lua:89:        assert.equals(9,  secs[1].line_start); assert.equals(9,  secs[1].line_end)
tests/unit/chat_parser_section_lines_spec.lua:90:        assert.equals(10, secs[2].line_start); assert.equals(13, secs[2].line_end)
tests/unit/chat_parser_section_lines_spec.lua:91:        assert.equals(14, secs[3].line_start); assert.equals(17, secs[3].line_end)
tests/unit/chat_parser_section_lines_spec.lua:92:        assert.equals(18, secs[4].line_start); assert.equals(18, secs[4].line_end)
tests/unit/chat_parser_section_lines_spec.lua:154:        assert.equals(p.exchanges[1].answer.sections, p.exchanges[1].answer.content_blocks)

exec
/bin/zsh -lc "rg -n \"add_exchange|add_block|replace_span|append_pos|block_start\\(\" lua/parley tests | sed -n '1,240p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
lua/parley/exchange_model.lua:66:function Model:add_exchange(question_size, gap_before)
lua/parley/exchange_model.lua:81:function Model:add_block(k, kind, size, gap_before)
lua/parley/exchange_model.lua:82:    local pos = self:append_pos(k)
lua/parley/exchange_model.lua:114:function Model:replace_span(k, first_block, old_count, sections)
lua/parley/exchange_model.lua:178:function Model:block_start(k, b)
lua/parley/exchange_model.lua:197:    return self:block_start(k, b) + self.exchanges[k].blocks[b].size - 1
lua/parley/exchange_model.lua:211:function Model:append_pos(k)
lua/parley/exchange_model.lua:227:--- @deprecated Use add_block
lua/parley/exchange_model.lua:229:    return self:add_block(k, kind, size)
lua/parley/exchange_model.lua:244:    return self:block_start(k, s)
lua/parley/exchange_model.lua:252:--- @deprecated Use append_pos
lua/parley/exchange_model.lua:253:function Model:answer_append_pos(k)
lua/parley/exchange_model.lua:254:    return self:append_pos(k)
lua/parley/exchange_model.lua:294:        model:add_exchange(q_size, gap_before)
lua/parley/exchange_model.lua:302:            model:add_block(k, "agent_header", 1, answer_gap)
lua/parley/exchange_model.lua:313:                model:add_block(k, sec.kind or sec.type or "text", sec_size, section_gap)
lua/parley/tool_loop.lua:118:                local start_line = model:block_start(ex_idx, i)
lua/parley/tool_loop.lua:140:--- model for position computation. Inserts at model:answer_append_pos(),
lua/parley/tool_loop.lua:153:        model:add_block(exchange_idx, section.kind, #lines)
lua/parley/tool_loop.lua:155:        local pos = model:block_start(exchange_idx, blk_idx)
lua/parley/fold_projection.lua:21:            local start_0 = model:block_start(exchange_index, block_index)
lua/parley/init.lua:3315:			local computed_start = model:block_start(k, b)
tests/integration/tool_folds_spec.lua:33:        model:add_exchange(1)
tests/integration/tool_folds_spec.lua:34:        model:add_block(1, "agent_header", 1)
tests/integration/tool_folds_spec.lua:35:        model:add_block(1, kind, size)
tests/integration/tool_folds_spec.lua:87:        model:replace_span(1, 3, 1, { { kind = "summary", size = 1 } })
tests/integration/tool_folds_spec.lua:110:        model:replace_span(1, 3, 1, { { kind = "summary", size = 1 } })
tests/integration/tool_folds_spec.lua:179:            model:add_block(1, "tool_use", 2)
lua/parley/chat_respond.lua:421:        local start_line = model:block_start(k, b)
lua/parley/chat_respond.lua:1519:            model:add_block(target_idx, "stream_placeholder", 1)
lua/parley/chat_respond.lua:1521:            local pos = model:block_start(target_idx, stream_block_idx)
lua/parley/chat_respond.lua:1527:            model:add_block(target_idx, "agent_header", 1)
lua/parley/chat_respond.lua:1528:            model:add_block(target_idx, "stream_placeholder", 1)
lua/parley/chat_respond.lua:1530:            initial_progress_tip = model:block_start(target_idx, 2)
lua/parley/chat_respond.lua:1536:            local insert_start = model:block_start(target_idx, agent_blk_idx) - 1  -- -1 for margin
lua/parley/chat_respond.lua:1574:        local lease_generation = chat_lease.begin(buf, model:block_start(target_idx, 2), {
lua/parley/chat_respond.lua:1650:        local response_start_line = model:block_start(target_idx, stream_block_idx)
lua/parley/chat_respond.lua:1657:            local first_line = model:block_start(target_idx, first_block)
lua/parley/chat_respond.lua:1669:                first_line = model:block_start(target_idx, first_block)
lua/parley/chat_respond.lua:1695:            local changed = model:replace_span(target_idx, first_block, old_count, replacements)
lua/parley/chat_respond.lua:1734:                local spos = model:block_start(target_idx, stream_block_idx)
tests/unit/parse_chat_spec.lua:705:        model:add_block(1, "agent_header", 1)
tests/unit/parse_chat_spec.lua:706:        local agent_header_start = model:block_start(1, 2)
tests/unit/tool_folds_spec.lua:7:        model:add_exchange(1)
tests/unit/tool_folds_spec.lua:9:            model:add_block(1, kind, 1)
tests/unit/build_messages_spec.lua:1566:        model:add_exchange(1)                 -- block 1: question
tests/unit/build_messages_spec.lua:1567:        model:add_block(1, "agent_header", 1) -- block 2
tests/unit/build_messages_spec.lua:1572:        model:add_block(1, "tool_use", #call_lines) -- block 3: dangling (no 📎:)
tests/unit/build_messages_spec.lua:1574:        local q0 = model:block_start(1, 1)
tests/unit/build_messages_spec.lua:1575:        local ah0 = model:block_start(1, 2)
tests/unit/build_messages_spec.lua:1576:        local tu0 = model:block_start(1, 3)
tests/unit/build_messages_spec.lua:1630:        model:add_exchange(#question_lines)
tests/unit/build_messages_spec.lua:1631:        model:add_block(1, "agent_header", 1)
tests/unit/build_messages_spec.lua:1632:        model:add_block(1, "text", #answer_lines)
tests/unit/build_messages_spec.lua:1634:        local q0 = model:block_start(1, 1)
tests/unit/build_messages_spec.lua:1635:        local ah0 = model:block_start(1, 2)
tests/unit/build_messages_spec.lua:1636:        local text0 = model:block_start(1, 3)
tests/unit/fold_projection_spec.lua:6:        model:add_exchange(2)
tests/unit/fold_projection_spec.lua:7:        model:add_block(1, "agent_header", 1)
tests/unit/fold_projection_spec.lua:8:        model:add_block(1, "thinking", 2)
tests/unit/fold_projection_spec.lua:9:        model:add_block(1, "text", 3)
tests/unit/fold_projection_spec.lua:10:        model:add_block(1, "summary", 1)
tests/unit/fold_projection_spec.lua:11:        model:add_block(1, "tool_use", 4)
tests/unit/fold_projection_spec.lua:12:        model:add_block(1, "tool_result", 2)
tests/unit/fold_projection_spec.lua:13:        model:add_block(1, "thinking", 0)
tests/unit/fold_projection_spec.lua:15:        model:add_exchange(1)
tests/unit/fold_projection_spec.lua:16:        model:add_block(2, "agent_header", 1)
tests/unit/fold_projection_spec.lua:17:        model:add_block(2, "summary", 2)
tests/unit/exchange_model_spec.lua:19:        m:add_exchange(1)
tests/unit/exchange_model_spec.lua:23:    it("append_pos for question-only exchange is after question + margin", function()
tests/unit/exchange_model_spec.lua:25:        m:add_exchange(1)
tests/unit/exchange_model_spec.lua:27:        assert.equals(7, m:append_pos(1))
tests/unit/exchange_model_spec.lua:34:        m:add_exchange(1)
tests/unit/exchange_model_spec.lua:35:        m:add_block(1, "agent_header", 1)
tests/unit/exchange_model_spec.lua:36:        m:add_block(1, "text", 3)
tests/unit/exchange_model_spec.lua:37:        m:add_block(1, "stream_placeholder", 0)
tests/unit/exchange_model_spec.lua:44:        m:add_exchange(1)
tests/unit/exchange_model_spec.lua:45:        m:add_block(1, "stream_placeholder", 0)
tests/unit/exchange_model_spec.lua:52:        m:add_exchange(0)
tests/unit/exchange_model_spec.lua:53:        m:add_block(1, "stream_placeholder", 0)
tests/unit/exchange_model_spec.lua:60:        m:add_exchange(1)
tests/unit/exchange_model_spec.lua:61:        m:add_block(1, "agent_header", 1)
tests/unit/exchange_model_spec.lua:63:        assert.equals(7, m:block_start(1, 2))
tests/unit/exchange_model_spec.lua:68:        m:add_exchange(1)
tests/unit/exchange_model_spec.lua:69:        m:add_block(1, "agent_header", 1)
tests/unit/exchange_model_spec.lua:70:        m:add_block(1, "text", 3)
tests/unit/exchange_model_spec.lua:72:        assert.equals(9, m:block_start(1, 3))
tests/unit/exchange_model_spec.lua:77:        m:add_exchange(1)
tests/unit/exchange_model_spec.lua:78:        m:add_block(1, "agent_header", 1)
tests/unit/exchange_model_spec.lua:79:        m:add_block(1, "text", 3)  -- lines 9-11
tests/unit/exchange_model_spec.lua:85:        m:add_exchange(1)
tests/unit/exchange_model_spec.lua:86:        m:add_block(1, "agent_header", 1)
tests/unit/exchange_model_spec.lua:87:        m:add_block(1, "text", 3)      -- lines 9-11
tests/unit/exchange_model_spec.lua:88:        m:add_block(1, "tool_use", 4)  -- margin at 12, lines 13-16
tests/unit/exchange_model_spec.lua:89:        assert.equals(13, m:block_start(1, 4))
tests/unit/exchange_model_spec.lua:92:    it("append_pos advances after adding blocks", function()
tests/unit/exchange_model_spec.lua:94:        m:add_exchange(1)
tests/unit/exchange_model_spec.lua:95:        m:add_block(1, "agent_header", 1)
tests/unit/exchange_model_spec.lua:96:        m:add_block(1, "text", 3)      -- lines 9-11
tests/unit/exchange_model_spec.lua:97:        m:add_block(1, "tool_use", 4)  -- lines 13-16
tests/unit/exchange_model_spec.lua:99:        assert.equals(18, m:append_pos(1))
tests/unit/exchange_model_spec.lua:104:        m:add_exchange(1)
tests/unit/exchange_model_spec.lua:105:        m:add_block(1, "agent_header", 1)
tests/unit/exchange_model_spec.lua:106:        m:add_block(1, "text", 1)      -- line 9
tests/unit/exchange_model_spec.lua:107:        m:add_block(1, "tool_use", 4)  -- margin at 10, lines 11-14
tests/unit/exchange_model_spec.lua:108:        assert.equals(11, m:block_start(1, 4))
tests/unit/exchange_model_spec.lua:112:        assert.equals(13, m:block_start(1, 4))
tests/unit/exchange_model_spec.lua:117:        m:add_exchange(1)
tests/unit/exchange_model_spec.lua:118:        m:add_block(1, "agent_header", 1)  -- line 7
tests/unit/exchange_model_spec.lua:119:        assert.equals(7, m:block_start(1, 2))
tests/unit/exchange_model_spec.lua:121:        assert.equals(12, m:block_start(1, 2))  -- shifted by 5
tests/unit/exchange_model_spec.lua:128:        m:add_exchange(1)
tests/unit/exchange_model_spec.lua:129:        m:add_block(1, "agent_header", 1)  -- line 7
tests/unit/exchange_model_spec.lua:130:        m:add_block(1, "spinner", 0)       -- empty, invisible
tests/unit/exchange_model_spec.lua:131:        m:add_block(1, "text", 3)          -- should be at 9 (same as without spinner)
tests/unit/exchange_model_spec.lua:132:        assert.equals(9, m:block_start(1, 4))
tests/unit/exchange_model_spec.lua:137:        m:add_exchange(1)
tests/unit/exchange_model_spec.lua:138:        m:add_block(1, "agent_header", 1)  -- line 7
tests/unit/exchange_model_spec.lua:139:        m:add_block(1, "spinner", 1)       -- line 9
tests/unit/exchange_model_spec.lua:140:        m:add_block(1, "text", 3)          -- line 11
tests/unit/exchange_model_spec.lua:141:        assert.equals(11, m:block_start(1, 4))
tests/unit/exchange_model_spec.lua:145:        assert.equals(9, m:block_start(1, 4))
tests/unit/exchange_model_spec.lua:150:        m:add_exchange(1)
tests/unit/exchange_model_spec.lua:151:        m:add_block(1, "agent_header", 1)
tests/unit/exchange_model_spec.lua:152:        m:add_block(1, "spinner", 0)  -- invisible
tests/unit/exchange_model_spec.lua:153:        m:add_block(1, "text", 3)
tests/unit/exchange_model_spec.lua:162:        m:add_exchange(1)
tests/unit/exchange_model_spec.lua:163:        m:add_block(1, "agent_header", 1)
tests/unit/exchange_model_spec.lua:164:        m:add_block(1, "text", 2)
tests/unit/exchange_model_spec.lua:165:        m:add_exchange(1)
tests/unit/exchange_model_spec.lua:173:        m:add_exchange(1)
tests/unit/exchange_model_spec.lua:174:        m:add_block(1, "agent_header", 1)
tests/unit/exchange_model_spec.lua:175:        m:add_block(1, "text", 1)
tests/unit/exchange_model_spec.lua:176:        m:add_block(1, "tool_use", 4)
tests/unit/exchange_model_spec.lua:177:        m:add_block(1, "tool_result", 5)
tests/unit/exchange_model_spec.lua:178:        m:add_exchange(1)
tests/unit/exchange_model_spec.lua:188:describe("exchange_model: replace_span", function()
tests/unit/exchange_model_spec.lua:191:        m:add_exchange(1)
tests/unit/exchange_model_spec.lua:192:        m:add_block(1, "agent_header", 1)
tests/unit/exchange_model_spec.lua:193:        m:add_block(1, "tool_result", 3)
tests/unit/exchange_model_spec.lua:194:        m:add_block(1, "stream_placeholder", 4)
tests/unit/exchange_model_spec.lua:196:        local changed = m:replace_span(1, 4, 1, {
tests/unit/exchange_model_spec.lua:209:        m:add_exchange(1)
tests/unit/exchange_model_spec.lua:210:        assert.has_error(function() m:replace_span(1, 2, 1, {}) end)
tests/unit/exchange_model_spec.lua:212:            m:replace_span(1, 1, 1, { { kind = "text", size = -1 } })
tests/unit/exchange_model_spec.lua:215:            m:replace_span(1, 1, 1, { { kind = "text", size = 1, gap_before = -1 } })
tests/unit/exchange_model_spec.lua:221:        m:add_exchange(1)
tests/unit/exchange_model_spec.lua:222:        m:add_block(1, "agent_header", 1)
tests/unit/exchange_model_spec.lua:223:        m:add_block(1, "stream_placeholder", 2)
tests/unit/exchange_model_spec.lua:225:        local first_start = m:block_start(1, 3)
tests/unit/exchange_model_spec.lua:226:        m:replace_span(1, 3, 1, {
tests/unit/exchange_model_spec.lua:231:        assert.equals(first_start, m:block_start(1, 3))
tests/unit/exchange_model_spec.lua:232:        assert.equals(first_start + 1, m:block_start(1, 4))
tests/unit/exchange_model_spec.lua:300:        assert.equals(6, m:block_start(1, 1) + 1)
tests/unit/exchange_model_spec.lua:301:        assert.equals(8, m:block_start(1, 2) + 1)
tests/unit/exchange_model_spec.lua:302:        assert.equals(10, m:block_start(1, 3) + 1)
tests/unit/exchange_model_spec.lua:303:        assert.equals(12, m:block_start(1, 4) + 1)
tests/unit/exchange_model_spec.lua:304:        assert.equals(13, m:block_start(2, 1) + 1)
tests/unit/exchange_model_spec.lua:305:        assert.equals(16, m:block_start(2, 2) + 1)
tests/unit/exchange_model_spec.lua:306:        assert.equals(17, m:block_start(2, 3) + 1)
tests/unit/exchange_model_spec.lua:307:        assert.equals(18, m:block_start(2, 4) + 1)
tests/unit/exchange_model_spec.lua:312:        m:add_exchange(1)
tests/unit/exchange_model_spec.lua:313:        m:add_block(1, "agent_header", 1)
tests/unit/exchange_model_spec.lua:314:        m:add_block(1, "stream_placeholder", 1)
tests/unit/exchange_model_spec.lua:315:        m:add_exchange(1)
tests/unit/exchange_model_spec.lua:316:        local next_before = m:block_start(2, 1)
tests/unit/exchange_model_spec.lua:320:        assert.equals(next_before - 2, m:block_start(2, 1))
tests/unit/exchange_model_spec.lua:321:        assert.equals(m:block_end(1, 2) + 2, m:append_pos(1))
tests/unit/exchange_model_spec.lua:349:        assert.equals("💬: hello", lines[m:block_start(1, 1) + 1])
tests/unit/exchange_model_spec.lua:350:        assert.equals("🤖:[Agent]", lines[m:block_start(1, 2) + 1])
tests/unit/exchange_model_spec.lua:351:        assert.equals("Hi there!", lines[m:block_start(1, 3) + 1])
tests/unit/exchange_model_spec.lua:353:        assert.equals("💬:", lines[m:block_start(2, 1) + 1])
tests/unit/exchange_model_spec.lua:399:        assert.equals("💬: read file", lines[m:block_start(1, 1) + 1])
tests/unit/exchange_model_spec.lua:400:        assert.equals("🤖:[Agent]", lines[m:block_start(1, 2) + 1])
tests/unit/exchange_model_spec.lua:401:        assert.equals("🧠: thinking about it", lines[m:block_start(1, 3) + 1])
tests/unit/exchange_model_spec.lua:402:        assert.equals("🔧: read_file id=toolu_01", lines[m:block_start(1, 4) + 1])
tests/unit/exchange_model_spec.lua:403:        assert.equals("📎: read_file id=toolu_01", lines[m:block_start(1, 5) + 1])
tests/unit/exchange_model_spec.lua:404:        assert.equals("The file says something.", lines[m:block_start(1, 6) + 1])
tests/unit/exchange_model_spec.lua:405:        assert.equals("📝: summary line", lines[m:block_start(1, 7) + 1])
tests/unit/exchange_model_spec.lua:425:        assert.equals("💬: hello", lines[m:block_start(1, 1) + 1])
tests/unit/exchange_model_spec.lua:426:        assert.equals("🤖:[Agent]", lines[m:block_start(1, 2) + 1])
tests/unit/exchange_model_spec.lua:451:        assert.equals("💬: q2", lines[m:block_start(2, 1) + 1])

exec
/bin/zsh -lc "rg -n \"_apply_block_fold|apply_folds\\(|hydrate_window\\(|with_exchange_update|prepare_exchange_update|reconcile_exchange\" lua/parley tests | sed -n '1,260p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
lua/parley/tool_loop.lua:152:    require("parley.tool_folds").with_exchange_update(bufnr, model, exchange_idx, function()
lua/parley/chat_respond.lua:1719:                return require("parley.tool_folds").with_exchange_update(
lua/parley/tool_folds.lua:40:function M.reconcile_exchange(buf, win, model, exchange_index)
lua/parley/tool_folds.lua:53:function M.prepare_exchange_update(buf, model, exchange_index)
lua/parley/tool_folds.lua:68:        M.reconcile_exchange(buf, win, model, exchange_index)
lua/parley/tool_folds.lua:81:function M.with_exchange_update(buf, model, exchange_index, mutate)
lua/parley/tool_folds.lua:82:    local windows = M.prepare_exchange_update(buf, model, exchange_index)
lua/parley/tool_folds.lua:95:                pcall(M.reconcile_exchange, buf, win, final_model, exchange_index)
lua/parley/tool_folds.lua:105:function M.apply_folds(buf, win, model_provider)
lua/parley/tool_folds.lua:112:            M.reconcile_exchange(buf, target_win, model, k)
lua/parley/tool_folds.lua:118:function M.hydrate_window(buf, win, model_provider)
lua/parley/tool_folds.lua:133:        M.reconcile_exchange(buf, win, model, exchange_index)
lua/parley/tool_folds.lua:170:            vim.schedule(function() M.hydrate_window(buf, target) end)
lua/parley/tool_folds.lua:186:        M.hydrate_window(buf, win)
tests/integration/tool_folds_spec.lua:42:        tool_folds.reconcile_exchange(buf, win, model, 1)
tests/integration/tool_folds_spec.lua:43:        tool_folds.with_exchange_update(buf, model, 1, function()
tests/integration/tool_folds_spec.lua:66:        tool_folds.apply_folds(buf)
tests/integration/tool_folds_spec.lua:82:        tool_folds.reconcile_exchange(buf, win, model, 1)
tests/integration/tool_folds_spec.lua:85:        local windows = tool_folds.prepare_exchange_update(buf, model, 1)
tests/integration/tool_folds_spec.lua:105:        tool_folds.reconcile_exchange(buf, win, model, 1)
tests/integration/tool_folds_spec.lua:106:        tool_folds.reconcile_exchange(buf, second_win, model, 1)
tests/integration/tool_folds_spec.lua:108:        local windows = tool_folds.prepare_exchange_update(buf, model, 1)
tests/integration/tool_folds_spec.lua:127:        tool_folds.reconcile_exchange(buf, win, model, 1)
tests/integration/tool_folds_spec.lua:132:            tool_folds.with_exchange_update(buf, model, 1, function()
tests/integration/tool_folds_spec.lua:155:        assert.is_true(tool_folds.hydrate_window(buf, win, provider))
tests/integration/tool_folds_spec.lua:156:        assert.is_false(tool_folds.hydrate_window(buf, win, provider))
tests/integration/tool_folds_spec.lua:168:        assert.is_true(tool_folds.hydrate_window(buf, win, function() return model end))
tests/integration/tool_folds_spec.lua:178:        tool_folds.with_exchange_update(buf, model, 1, function()
tests/integration/tool_folds_spec.lua:182:        assert.is_true(tool_folds.hydrate_window(buf, win, function() return model end))
tests/integration/tool_folds_spec.lua:196:        tool_folds.apply_folds(buf)

exec
/bin/zsh -lc "nl -ba lua/parley/chat_parser.lua | sed -n '430,510p' && nl -ba tests/unit/chat_parser_section_lines_spec.lua | sed -n '20,105p' && nl -ba lua/parley/answer_structure.lua | sed -n '1,130p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   430		end
   431
   432		-- Append a line to the current content block, auto-transitioning
   433		-- out of a tool block whose fenced body has already been closed.
   434		-- Tracks fence open/close state inside tool blocks so the parser
   435		-- knows when subsequent text should start a new text block vs
   436		-- belong to the tool block's body.
   437		-- line_no is the 1-indexed buffer line being appended (#90 Task 1.1).
   438		local function cb_append_line(line, line_no)
   439			if not cb_state or not cb_state.current_kind then return end
   440
   441			-- Auto-transition: if we're in a tool block whose closing
   442			-- fence was already seen, this line belongs to a NEW text
   443			-- block, not the tool block. Finalize the tool block first.
   444			if cb_state.tool_body_complete then
   445				cb_finalize_block(line_no - 1)
   446				cb_start_block("text")
   447			end
   448
   449			-- Lazy line_start: the first line we see is where the block begins.
   450			if cb_state.current_line_start == nil then
   451				cb_state.current_line_start = line_no
   452			end
   453			table.insert(cb_state.current_lines, line)
   454
   455			-- Track fence state inside tool blocks to detect body end.
   456			-- Opening fence: any run of 3+ backticks optionally followed
   457			-- by an info string (e.g. "```json"). Closing fence: exactly
   458			-- the same number of bare backticks with no info string.
   459			if cb_state.current_kind == "tool_use" or cb_state.current_kind == "tool_result" then
   460				if not cb_state.tool_fence_len then
   461					local fence = line:match("^(`+)[%w_%-]*%s*$")
   462					if fence and #fence >= 3 then
   463						cb_state.tool_fence_len = #fence
   464					end
   465				else
   466					local expected_close = string.rep("`", cb_state.tool_fence_len)
   467					if line == expected_close then
   468						cb_state.tool_body_complete = true
   469					end
   470				end
   471			end
   472		end
   473
   474		-- Attach accumulated blocks to the current exchange's answer
   475		-- component (called on answer → next-question transition and at
   476		-- end of file). end_line_no is the last buffer line of the answer
   477		-- region (#90 Task 1.1).
   478		local function cb_attach_to_current_answer(end_line_no)
   479			if cb_state and current_exchange and current_exchange.answer then
   480				cb_finalize_block(end_line_no)
   481				current_exchange.answer.sections = cb_state.blocks
   482				-- Backward-compat alias.
   483				current_exchange.answer.content_blocks = cb_state.blocks
   484				local body_start = current_exchange.answer.line_start + 1
   485				local body_lines = {}
   486				for line_no = body_start, end_line_no do
   487					body_lines[#body_lines + 1] = lines[line_no]
   488				end
   489				local reduced = require("parley.answer_structure").reduce(body_lines, decoration_patterns)
   490				current_exchange.answer.semantic_sections = {}
   491				for _, section in ipairs(reduced.sections) do
   492					current_exchange.answer.semantic_sections[#current_exchange.answer.semantic_sections + 1] = {
   493						kind = section.kind,
   494						type = section.kind,
   495						line_start = body_start + section.line_start - 1,
   496						line_end = body_start + section.line_end - 1,
   497					}
   498				end
   499			end
   500			cb_state = nil
   501		end
   502
   503		-- Helper to extract @@ref@@ file references from a line of text.
   504		-- Canonical form: @@<ref>@@ where ref starts with https://, /, ~/, ./, or ../
   505		local function extract_file_refs(text)
   506			local refs = {}
   507			local seen = {}
   508			for ref in text:gmatch("@@([^@]+)@@") do
   509				ref = ref:gsub("^%s*(.-)%s*$", "%1")
   510				if ref:match("^https?://") or ref:match("^/") or ref:match("^~/") or ref:match("^%./") or ref:match("^%.%./") then
    20	            "---",          -- 4
    21	            "",             -- 5
    22	            "💬: q",        -- 6
    23	            "",             -- 7
    24	            "🤖: [A]",       -- 8
    25	            "the answer",   -- 9
    26	        }
    27	        local p = parse(lines)
    28	        local secs = p.exchanges[1].answer.sections
    29	        assert.equals(1, #secs)
    30	        assert.equals("text", secs[1].kind)
    31	        assert.equals(9, secs[1].line_start)
    32	        assert.equals(9, secs[1].line_end)
    33	    end)
    34
    35	    it("tool_use + tool_result get exact line spans", function()
    36	        local lines = {
    37	            "---",                   -- 1
    38	            "topic: t",              -- 2
    39	            "file: f.md",            -- 3
    40	            "---",                   -- 4
    41	            "",                      -- 5
    42	            "💬: q",                 -- 6
    43	            "",                      -- 7
    44	            "🤖: [A]",                -- 8
    45	            "🔧: read_file id=X",     -- 9
    46	            "```json",               -- 10
    47	            '{"p":"x"}',              -- 11
    48	            "```",                   -- 12
    49	            "📎: read_file id=X",     -- 13
    50	            "````",                  -- 14
    51	            "body",                  -- 15
    52	            "````",                  -- 16
    53	        }
    54	        local p = parse(lines)
    55	        local secs = p.exchanges[1].answer.sections
    56	        assert.equals(2, #secs)
    57	        assert.equals("tool_use", secs[1].kind)
    58	        assert.equals(9, secs[1].line_start)
    59	        assert.equals(12, secs[1].line_end)
    60	        assert.equals("tool_result", secs[2].kind)
    61	        assert.equals(13, secs[2].line_start)
    62	        assert.equals(16, secs[2].line_end)
    63	    end)
    64
    65	    it("text + tool_use + tool_result + text yields 4 sections in order", function()
    66	        local lines = {
    67	            "---", "topic: t", "file: f.md", "---", "", -- 1-5
    68	            "💬: q",                                    -- 6
    69	            "",                                         -- 7
    70	            "🤖: [A]",                                  -- 8
    71	            "Let me check.",                            -- 9
    72	            "🔧: read_file id=X",                       -- 10
    73	            "```json",                                  -- 11
    74	            '{"p":"x"}',                                 -- 12
    75	            "```",                                      -- 13
    76	            "📎: read_file id=X",                       -- 14
    77	            "````",                                     -- 15
    78	            "body",                                     -- 16
    79	            "````",                                     -- 17
    80	            "Done.",                                    -- 18
    81	        }
    82	        local p = parse(lines)
    83	        local secs = p.exchanges[1].answer.sections
    84	        assert.equals(4, #secs)
    85	        assert.equals("text",        secs[1].kind); assert.equals("Let me check.", secs[1].text)
    86	        assert.equals("tool_use",    secs[2].kind)
    87	        assert.equals("tool_result", secs[3].kind)
    88	        assert.equals("text",        secs[4].kind); assert.equals("Done.", secs[4].text)
    89	        assert.equals(9,  secs[1].line_start); assert.equals(9,  secs[1].line_end)
    90	        assert.equals(10, secs[2].line_start); assert.equals(13, secs[2].line_end)
    91	        assert.equals(14, secs[3].line_start); assert.equals(17, secs[3].line_end)
    92	        assert.equals(18, secs[4].line_start); assert.equals(18, secs[4].line_end)
    93	    end)
    94
    95	    describe("section helper functions (#90 Task 1.2)", function()
    96	        local function fixture()
    97	            return parse({
    98	                "---", "topic: t", "file: f.md", "---", "",  -- 1-5
    99	                "💬: q1",                                    -- 6
   100	                "",                                          -- 7
   101	                "🤖: [A]",                                   -- 8
   102	                "hi",                                        -- 9
   103	                "💬: q2",                                    -- 10
   104	                "",                                          -- 11
   105	                "🤖: [B]",                                   -- 12
     1	-- Pure semantic segmentation for the lines inside one assistant answer.
     2
     3	local M = {}
     4
     5	local BOUNDARY = {
     6	    reasoning = true,
     7	    summary = true,
     8	    tool_use = true,
     9	    tool_result = true,
    10	    user = true,
    11	    assistant = true,
    12	    branch = true,
    13	    ["local"] = true,
    14	}
    15
    16	local function trim_span(lines, first, last)
    17	    while first <= last and not lines[first]:match("%S") do first = first + 1 end
    18	    while last >= first and not lines[last]:match("%S") do last = last - 1 end
    19	    if first > last then return nil end
    20	    return first, last
    21	end
    22
    23	function M.reduce(lines, patterns, opts)
    24	    lines = lines or {}
    25	    opts = opts or {}
    26	    local classify = require("parley.highlight_structure").classify
    27	    local kinds = {}
    28	    for i, line in ipairs(lines) do kinds[i] = classify(line, patterns).kind end
    29
    30	    local explicit_end_for = {}
    31	    local end_ahead = false
    32	    for i = #lines, 1, -1 do
    33	        local kind = kinds[i]
    34	        if kind == "reasoning" then
    35	            explicit_end_for[i] = end_ahead
    36	        elseif kind == "reasoning_end" then
    37	            end_ahead = true
    38	        elseif BOUNDARY[kind] then
    39	            end_ahead = false
    40	        end
    41	    end
    42
    43	    local sections = {}
    44	    local function add(kind, first, last)
    45	        first, last = trim_span(lines, first, last)
    46	        if first then
    47	            sections[#sections + 1] = { kind = kind, line_start = first, line_end = last }
    48	        end
    49	    end
    50
    51	    local i = 1
    52	    while i <= #lines do
    53	        local kind = kinds[i]
    54	        if kind == "reasoning" then
    55	            local explicit = explicit_end_for[i]
    56	            local last = i
    57	            local cursor = i + 1
    58	            while cursor <= #lines do
    59	                local next_kind = kinds[cursor]
    60	                if explicit and next_kind == "reasoning_end" then
    61	                    last = cursor
    62	                    cursor = cursor + 1
    63	                    break
    64	                elseif BOUNDARY[next_kind] then
    65	                    break
    66	                elseif not explicit and next_kind == "blank" then
    67	                    break
    68	                end
    69	                last = cursor
    70	                cursor = cursor + 1
    71	            end
    72	            add("thinking", i, last)
    73	            i = cursor
    74	        elseif kind == "summary" then
    75	            add("summary", i, i)
    76	            i = i + 1
    77	        elseif kind == "tool_use" or kind == "tool_result" then
    78	            local last = i
    79	            local fence_open = false
    80	            local cursor = i + 1
    81	            while cursor <= #lines do
    82	                local next_kind = kinds[cursor]
    83	                if next_kind == "fence" then
    84	                    last = cursor
    85	                    if fence_open then
    86	                        cursor = cursor + 1
    87	                        break
    88	                    end
    89	                    fence_open = true
    90	                elseif not fence_open and BOUNDARY[next_kind] then
    91	                    break
    92	                else
    93	                    last = cursor
    94	                end
    95	                cursor = cursor + 1
    96	            end
    97	            add(kind, i, last)
    98	            i = cursor
    99	        else
   100	            local first = i
   101	            local last = i
   102	            local cursor = i + 1
   103	            while cursor <= #lines and not BOUNDARY[kinds[cursor]] do
   104	                last = cursor
   105	                cursor = cursor + 1
   106	            end
   107	            add("text", first, last)
   108	            i = cursor
   109	        end
   110	    end
   111
   112	    return { sections = sections, work = { rows_visited = #lines }, streaming = opts.streaming == true }
   113	end
   114
   115	return M

exec
/bin/zsh -lc "nl -ba tests/unit/exchange_model_spec.lua | sed -n '1,470p'" in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc "nl -ba tests/integration/chat_respond_spec.lua | sed -n '2010,2075p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
  2010	            return buffer_contains(buf, "first second")
  2011	        end, 10)
  2012
  2013	        assert.is_true(buffer_contains(buf, "first second"))
  2014	    end)
  2015
  2016	    it("recreates a thinking fold from only the active streamed block", function()
  2017	        local buf = open_simple_chat()
  2018	        local captured_handler
  2019	        local qid = "qid_stream_thinking_fold"
  2020
  2021	        parley.dispatcher.query = function(buf_arg, _provider, _payload, handler)
  2022	            captured_handler = handler
  2023	            parley.tasker.set_query(qid, { response = "", raw_response = "", buf = buf_arg })
  2024	        end
  2025
  2026	        parley.chat_respond({ range = 0 })
  2027	        captured_handler(qid, "🧠: first\n")
  2028	        captured_handler(qid, "second")
  2029
  2030	        assert.is_true(vim.wait(200, function()
  2031	            return buffer_contains(buf, "second")
  2032	        end, 10))
  2033	        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  2034	        local thinking_row
  2035	        for row, line in ipairs(lines) do
  2036	            if line == "🧠: first" then thinking_row = row break end
  2037	        end
  2038	        assert.is_not_nil(thinking_row)
  2039	        vim.cmd("normal! zM")
  2040	        assert.equals(thinking_row, vim.fn.foldclosed(thinking_row))
  2041	        assert.equals(thinking_row + 1, vim.fn.foldclosedend(thinking_row))
  2042	    end)
  2043
  2044	    it("folds an adjacent streamed summary on its physical row", function()
  2045	        local buf = open_simple_chat()
  2046	        local captured_handler
  2047	        local qid = "qid_stream_adjacent_summary"
  2048
  2049	        parley.dispatcher.query = function(buf_arg, _provider, _payload, handler)
  2050	            captured_handler = handler
  2051	            parley.tasker.set_query(qid, { response = "", raw_response = "", buf = buf_arg })
  2052	        end
  2053
  2054	        parley.chat_respond({ range = 0 })
  2055	        captured_handler(qid, "answer text\n📝: compact summary")
  2056
  2057	        assert.is_true(vim.wait(200, function()
  2058	            return buffer_contains(buf, "📝: compact summary")
  2059	        end, 10))
  2060	        local summary_row = assert(find_line_number(buf, "📝: compact summary"))
  2061	        vim.cmd("normal! zM")
  2062	        assert.equals(summary_row, vim.fn.foldclosed(summary_row))
  2063	        assert.equals(summary_row, vim.fn.foldclosedend(summary_row))
  2064	        assert.equals(0, vim.fn.foldlevel(summary_row + 1))
  2065	    end)
  2066
  2067	    it("reduces only the active streamed span without reparsing transcript history", function()
  2068	        local buf = open_simple_chat()
  2069	        local history = {
  2070	            "# topic: Test Topic", "- file: test.md", "---", "",
  2071	            "💬: old question", "", "🤖: [TestAgent]",
  2072	        }
  2073	        for index = 1, 1000 do
  2074	            history[#history + 1] = "old transcript row " .. index
  2075	        end

 succeeded in 0ms:
     1	-- Unit tests for lua/parley/exchange_model.lua
     2	--
     3	-- Pure positional model for chat buffer layout. Everything is a block.
     4	-- 1 margin between non-empty blocks. Empty blocks (size 0) are invisible.
     5
     6	local em = require("parley.exchange_model")
     7
     8	describe("exchange_model: basic construction", function()
     9	    it("creates an empty model with header_lines", function()
    10	        local m = em.new(4)
    11	        assert.equals(4, m.header_lines)
    12	        assert.equals(0, #m.exchanges)
    13	    end)
    14	end)
    15
    16	describe("exchange_model: single exchange, question only", function()
    17	    it("exchange_start is header_lines + margin", function()
    18	        local m = em.new(4)
    19	        m:add_exchange(1)
    20	        assert.equals(5, m:exchange_start(1))  -- 4 header + 1 margin
    21	    end)
    22
    23	    it("append_pos for question-only exchange is after question + margin", function()
    24	        local m = em.new(4)
    25	        m:add_exchange(1)
    26	        -- question at 5, size 1 → next block at 5 + 1 + 1(margin) = 7
    27	        assert.equals(7, m:append_pos(1))
    28	    end)
    29	end)
    30
    31	describe("exchange_model: single exchange with blocks", function()
    32	    it("reports the last non-empty block end through trailing empty blocks", function()
    33	        local m = em.new(4)
    34	        m:add_exchange(1)
    35	        m:add_block(1, "agent_header", 1)
    36	        m:add_block(1, "text", 3)
    37	        m:add_block(1, "stream_placeholder", 0)
    38
    39	        assert.equals(11, m:last_nonempty_block_end(1))
    40	    end)
    41
    42	    it("reports the only non-empty block end", function()
    43	        local m = em.new(4)
    44	        m:add_exchange(1)
    45	        m:add_block(1, "stream_placeholder", 0)
    46
    47	        assert.equals(5, m:last_nonempty_block_end(1))
    48	    end)
    49
    50	    it("returns nil when an exchange has no non-empty blocks", function()
    51	        local m = em.new(4)
    52	        m:add_exchange(0)
    53	        m:add_block(1, "stream_placeholder", 0)
    54
    55	        assert.is_nil(m:last_nonempty_block_end(1))
    56	    end)
    57
    58	    it("agent_header block starts after question + margin", function()
    59	        local m = em.new(4)
    60	        m:add_exchange(1)
    61	        m:add_block(1, "agent_header", 1)
    62	        -- question at 5(size 1), margin, agent_header at 7
    63	        assert.equals(7, m:block_start(1, 2))
    64	    end)
    65
    66	    it("text block starts after agent_header + margin", function()
    67	        local m = em.new(4)
    68	        m:add_exchange(1)
    69	        m:add_block(1, "agent_header", 1)
    70	        m:add_block(1, "text", 3)
    71	        -- agent_header at 7(size 1), margin, text at 9
    72	        assert.equals(9, m:block_start(1, 3))
    73	    end)
    74
    75	    it("block_end returns the last line of a block", function()
    76	        local m = em.new(4)
    77	        m:add_exchange(1)
    78	        m:add_block(1, "agent_header", 1)
    79	        m:add_block(1, "text", 3)  -- lines 9-11
    80	        assert.equals(11, m:block_end(1, 3))
    81	    end)
    82
    83	    it("tool_use block after text includes margin", function()
    84	        local m = em.new(4)
    85	        m:add_exchange(1)
    86	        m:add_block(1, "agent_header", 1)
    87	        m:add_block(1, "text", 3)      -- lines 9-11
    88	        m:add_block(1, "tool_use", 4)  -- margin at 12, lines 13-16
    89	        assert.equals(13, m:block_start(1, 4))
    90	    end)
    91
    92	    it("append_pos advances after adding blocks", function()
    93	        local m = em.new(4)
    94	        m:add_exchange(1)
    95	        m:add_block(1, "agent_header", 1)
    96	        m:add_block(1, "text", 3)      -- lines 9-11
    97	        m:add_block(1, "tool_use", 4)  -- lines 13-16
    98	        -- next block: 16 + 1 + 1(margin) = 18
    99	        assert.equals(18, m:append_pos(1))
   100	    end)
   101
   102	    it("grow_block updates the size and shifts subsequent positions", function()
   103	        local m = em.new(4)
   104	        m:add_exchange(1)
   105	        m:add_block(1, "agent_header", 1)
   106	        m:add_block(1, "text", 1)      -- line 9
   107	        m:add_block(1, "tool_use", 4)  -- margin at 10, lines 11-14
   108	        assert.equals(11, m:block_start(1, 4))
   109	        -- Grow text by 2 lines (streaming)
   110	        m:grow_block(1, 3, 2)
   111	        -- text is now 3 lines: 9-11. tool_use shifts: margin at 12, lines 13-16
   112	        assert.equals(13, m:block_start(1, 4))
   113	    end)
   114
   115	    it("grow_question shifts all subsequent positions", function()
   116	        local m = em.new(4)
   117	        m:add_exchange(1)
   118	        m:add_block(1, "agent_header", 1)  -- line 7
   119	        assert.equals(7, m:block_start(1, 2))
   120	        m:grow_question(1, 5)  -- e.g. raw_request_fence
   121	        assert.equals(12, m:block_start(1, 2))  -- shifted by 5
   122	    end)
   123	end)
   124
   125	describe("exchange_model: empty block cancellation", function()
   126	    it("empty block is invisible — doesn't add margins", function()
   127	        local m = em.new(4)
   128	        m:add_exchange(1)
   129	        m:add_block(1, "agent_header", 1)  -- line 7
   130	        m:add_block(1, "spinner", 0)       -- empty, invisible
   131	        m:add_block(1, "text", 3)          -- should be at 9 (same as without spinner)
   132	        assert.equals(9, m:block_start(1, 4))
   133	    end)
   134
   135	    it("setting block size to 0 makes it invisible", function()
   136	        local m = em.new(4)
   137	        m:add_exchange(1)
   138	        m:add_block(1, "agent_header", 1)  -- line 7
   139	        m:add_block(1, "spinner", 1)       -- line 9
   140	        m:add_block(1, "text", 3)          -- line 11
   141	        assert.equals(11, m:block_start(1, 4))
   142	        -- Remove spinner by setting size to 0
   143	        m:set_block_size(1, 3, 0)
   144	        -- text should shift back: line 9
   145	        assert.equals(9, m:block_start(1, 4))
   146	    end)
   147
   148	    it("exchange_total_size skips empty blocks", function()
   149	        local m = em.new(4)
   150	        m:add_exchange(1)
   151	        m:add_block(1, "agent_header", 1)
   152	        m:add_block(1, "spinner", 0)  -- invisible
   153	        m:add_block(1, "text", 3)
   154	        -- question(1) + margin + agent_header(1) + margin + text(3) = 7
   155	        assert.equals(7, m:exchange_total_size(1))
   156	    end)
   157	end)
   158
   159	describe("exchange_model: two exchanges", function()
   160	    it("second exchange starts after first + margin", function()
   161	        local m = em.new(4)
   162	        m:add_exchange(1)
   163	        m:add_block(1, "agent_header", 1)
   164	        m:add_block(1, "text", 2)
   165	        m:add_exchange(1)
   166	        -- exchange 1: q(1) + m + ah(1) + m + text(2) = 6
   167	        -- exchange 2 start: 5 + 6 + 1(margin between exchanges) = 12
   168	        assert.equals(12, m:exchange_start(2))
   169	    end)
   170
   171	    it("tool blocks in exchange 1 shift exchange 2", function()
   172	        local m = em.new(4)
   173	        m:add_exchange(1)
   174	        m:add_block(1, "agent_header", 1)
   175	        m:add_block(1, "text", 1)
   176	        m:add_block(1, "tool_use", 4)
   177	        m:add_block(1, "tool_result", 5)
   178	        m:add_exchange(1)
   179	        -- ex1: q(1)+m+ah(1)+m+text(1)+m+tu(4)+m+tr(5) = 16
   180	        -- ex2 start: 5 + 16 + 1 = 22
   181	        assert.equals(22, m:exchange_start(2))
   182	        -- Growing text by 3 shifts exchange 2 by 3
   183	        m:grow_block(1, 3, 3)
   184	        assert.equals(25, m:exchange_start(2))
   185	    end)
   186	end)
   187
   188	describe("exchange_model: replace_span", function()
   189	    it("replaces only the requested insertion span and returns changed indices", function()
   190	        local m = em.new(4)
   191	        m:add_exchange(1)
   192	        m:add_block(1, "agent_header", 1)
   193	        m:add_block(1, "tool_result", 3)
   194	        m:add_block(1, "stream_placeholder", 4)
   195
   196	        local changed = m:replace_span(1, 4, 1, {
   197	            { kind = "thinking", size = 2 },
   198	            { kind = "text", size = 1 },
   199	        })
   200
   201	        assert.same({ 4, 5 }, changed)
   202	        assert.same({ "question", "agent_header", "tool_result", "thinking", "text" },
   203	            vim.tbl_map(function(block) return block.kind end, m.exchanges[1].blocks))
   204	        assert.equals(3, m.exchanges[1].blocks[3].size)
   205	    end)
   206
   207	    it("rejects invalid spans and negative section sizes", function()
   208	        local m = em.new(0)
   209	        m:add_exchange(1)
   210	        assert.has_error(function() m:replace_span(1, 2, 1, {}) end)
   211	        assert.has_error(function()
   212	            m:replace_span(1, 1, 1, { { kind = "text", size = -1 } })
   213	        end)
   214	        assert.has_error(function()
   215	            m:replace_span(1, 1, 1, { { kind = "text", size = 1, gap_before = -1 } })
   216	        end)
   217	    end)
   218
   219	    it("preserves an inherited leading gap and explicit adjacent replacements", function()
   220	        local m = em.new(4)
   221	        m:add_exchange(1)
   222	        m:add_block(1, "agent_header", 1)
   223	        m:add_block(1, "stream_placeholder", 2)
   224
   225	        local first_start = m:block_start(1, 3)
   226	        m:replace_span(1, 3, 1, {
   227	            { kind = "text", size = 1 },
   228	            { kind = "summary", size = 1, gap_before = 0 },
   229	        })
   230
   231	        assert.equals(first_start, m:block_start(1, 3))
   232	        assert.equals(first_start + 1, m:block_start(1, 4))
   233	    end)
   234	end)
   235
   236	describe("exchange_model: from_parsed_chat", function()
   237	    it("loads exchange structure from parser output", function()
   238	        local parsed = {
   239	            header_end = 4,
   240	            exchanges = {
   241	                {
   242	                    question = { line_start = 6, line_end = 6 },
   243	                    answer = {
   244	                        line_start = 8, line_end = 16,
   245	                        sections = {
   246	                            { kind = "tool_use", line_start = 9, line_end = 12 },
   247	                            { kind = "tool_result", line_start = 14, line_end = 16 },
   248	                        },
   249	                    },
   250	                },
   251	                {
   252	                    question = { line_start = 18, line_end = 18 },
   253	                    answer = nil,
   254	                },
   255	            },
   256	        }
   257	        local m = em.from_parsed_chat(parsed)
   258	        assert.equals(2, #m.exchanges)
   259	        -- Exchange 1: question + agent_header + tool_use + tool_result = 4 blocks
   260	        assert.equals(4, #m.exchanges[1].blocks)
   261	        assert.equals("question", m.exchanges[1].blocks[1].kind)
   262	        assert.equals("agent_header", m.exchanges[1].blocks[2].kind)
   263	        assert.equals(4, m.exchanges[1].blocks[3].size)  -- tool_use: 12-9+1
   264	        assert.equals(3, m.exchanges[1].blocks[4].size)  -- tool_result: 16-14+1
   265	        -- Exchange 2: question only
   266	        assert.equals(1, #m.exchanges[2].blocks)
   267	    end)
   268
   269	    it("preserves actual zero, one, and multi-line gaps from parser spans", function()
   270	        local parsed = {
   271	            header_end = 4,
   272	            exchanges = {
   273	                {
   274	                    question = { line_start = 6, line_end = 6 },
   275	                    answer = {
   276	                        line_start = 8, line_end = 12,
   277	                        sections = {
   278	                            { kind = "text", line_start = 10, line_end = 10 },
   279	                            { kind = "summary", line_start = 12, line_end = 12 },
   280	                        },
   281	                    },
   282	                },
   283	                {
   284	                    -- No blank between the prior summary and this question.
   285	                    question = { line_start = 13, line_end = 13 },
   286	                    answer = {
   287	                        -- Two blank lines before the agent header.
   288	                        line_start = 16, line_end = 18,
   289	                        sections = {
   290	                            -- No blank between header and text.
   291	                            { kind = "text", line_start = 17, line_end = 17 },
   292	                            { kind = "summary", line_start = 18, line_end = 18 },
   293	                        },
   294	                    },
   295	                },
   296	            },
   297	        }
   298
   299	        local m = em.from_parsed_chat(parsed)
   300	        assert.equals(6, m:block_start(1, 1) + 1)
   301	        assert.equals(8, m:block_start(1, 2) + 1)
   302	        assert.equals(10, m:block_start(1, 3) + 1)
   303	        assert.equals(12, m:block_start(1, 4) + 1)
   304	        assert.equals(13, m:block_start(2, 1) + 1)
   305	        assert.equals(16, m:block_start(2, 2) + 1)
   306	        assert.equals(17, m:block_start(2, 3) + 1)
   307	        assert.equals(18, m:block_start(2, 4) + 1)
   308	    end)
   309
   310	    it("does not count a zero-size block or its stored gap", function()
   311	        local m = em.new(4)
   312	        m:add_exchange(1)
   313	        m:add_block(1, "agent_header", 1)
   314	        m:add_block(1, "stream_placeholder", 1)
   315	        m:add_exchange(1)
   316	        local next_before = m:block_start(2, 1)
   317
   318	        m:set_block_size(1, 3, 0)
   319
   320	        assert.equals(next_before - 2, m:block_start(2, 1))
   321	        assert.equals(m:block_end(1, 2) + 2, m:append_pos(1))
   322	    end)
   323	end)
   324
   325	describe("exchange_model: from_parsed_chat with real parser", function()
   326	    local cp = require("parley.chat_parser")
   327	    local cfg = require("parley.config")
   328
   329	    it("positions match buffer lines for simple Q+A", function()
   330	        local lines = {
   331	            "---", "topic: test", "file: t.md", "---",
   332	            "",
   333	            "💬: hello",
   334	            "",
   335	            "🤖:[Agent]",
   336	            "",
   337	            "Hi there!",
   338	            "",
   339	            "💬:",
   340	        }
   341	        local he = cp.find_header_end(lines)
   342	        local parsed = cp.parse_chat(lines, he, cfg)
   343	        local m = em.from_parsed_chat(parsed)
   344
   345	        assert.equals(2, #m.exchanges)
   346	        -- Exchange 1: question + agent_header + text
   347	        assert.equals(3, #m.exchanges[1].blocks)
   348	        -- 0-indexed positions should match buffer (1-indexed - 1)
   349	        assert.equals("💬: hello", lines[m:block_start(1, 1) + 1])
   350	        assert.equals("🤖:[Agent]", lines[m:block_start(1, 2) + 1])
   351	        assert.equals("Hi there!", lines[m:block_start(1, 3) + 1])
   352	        -- Exchange 2: question only
   353	        assert.equals("💬:", lines[m:block_start(2, 1) + 1])
   354	    end)
   355
   356	    it("positions match buffer lines with thinking + tool blocks", function()
   357	        local lines = {
   358	            "---", "topic: test", "file: t.md", "---",
   359	            "",
   360	            "💬: read file",
   361	            "",
   362	            "🤖:[Agent]",
   363	            "",
   364	            "🧠: thinking about it",
   365	            "",
   366	            "🔧: read_file id=toolu_01",
   367	            '```json',
   368	            '{"path":"./f.txt"}',
   369	            "```",
   370	            "",
   371	            "📎: read_file id=toolu_01",
   372	            "```",
   373	            "file content here",
   374	            "```",
   375	            "",
   376	            "The file says something.",
   377	            "",
   378	            "📝: summary line",
   379	            "",
   380	            "💬:",
   381	        }
   382	        local he = cp.find_header_end(lines)
   383	        local parsed = cp.parse_chat(lines, he, cfg)
   384	        local m = em.from_parsed_chat(parsed)
   385
   386	        assert.equals(2, #m.exchanges)
   387	        -- Exchange 1: every semantic answer entity is its own model block.
   388	        local blocks = m.exchanges[1].blocks
   389	        assert.equals(7, #blocks)
   390	        assert.equals("question", blocks[1].kind)
   391	        assert.equals("agent_header", blocks[2].kind)
   392	        assert.equals("thinking", blocks[3].kind)
   393	        assert.equals("tool_use", blocks[4].kind)
   394	        assert.equals("tool_result", blocks[5].kind)
   395	        assert.equals("text", blocks[6].kind)
   396	        assert.equals("summary", blocks[7].kind)
   397
   398	        -- Positions match actual buffer content
   399	        assert.equals("💬: read file", lines[m:block_start(1, 1) + 1])
   400	        assert.equals("🤖:[Agent]", lines[m:block_start(1, 2) + 1])
   401	        assert.equals("🧠: thinking about it", lines[m:block_start(1, 3) + 1])
   402	        assert.equals("🔧: read_file id=toolu_01", lines[m:block_start(1, 4) + 1])
   403	        assert.equals("📎: read_file id=toolu_01", lines[m:block_start(1, 5) + 1])
   404	        assert.equals("The file says something.", lines[m:block_start(1, 6) + 1])
   405	        assert.equals("📝: summary line", lines[m:block_start(1, 7) + 1])
   406	    end)
   407
   408	    it("parser trims trailing blanks from question", function()
   409	        local lines = {
   410	            "---", "topic: test", "file: t.md", "---",
   411	            "",
   412	            "💬: hello",
   413	            "",   -- trailing blank — parser should trim this from question
   414	            "🤖:[Agent]",
   415	            "",
   416	            "response",
   417	        }
   418	        local he = cp.find_header_end(lines)
   419	        local parsed = cp.parse_chat(lines, he, cfg)
   420	        local m = em.from_parsed_chat(parsed)
   421
   422	        -- Question should be trimmed to size 1 (just the 💬: line)
   423	        assert.equals(1, m.exchanges[1].blocks[1].size)
   424	        -- With exactly 1 blank between components, model matches buffer
   425	        assert.equals("💬: hello", lines[m:block_start(1, 1) + 1])
   426	        assert.equals("🤖:[Agent]", lines[m:block_start(1, 2) + 1])
   427	    end)
   428
   429	    it("parser trims trailing blanks from answer sections", function()
   430	        local lines = {
   431	            "---", "topic: test", "file: t.md", "---",
   432	            "",
   433	            "💬: q1",
   434	            "",
   435	            "🤖:[A]",
   436	            "",
   437	            "answer text",
   438	            "",
   439	            "💬: q2",
   440	        }
   441	        local he = cp.find_header_end(lines)
   442	        local parsed = cp.parse_chat(lines, he, cfg)
   443	        local m = em.from_parsed_chat(parsed)
   444
   445	        assert.equals(2, #m.exchanges)
   446	        -- Answer text block should not include trailing blanks
   447	        local text_blk = m.exchanges[1].blocks[3]
   448	        assert.equals("text", text_blk.kind)
   449	        assert.equals(1, text_blk.size)  -- just "answer text"
   450	        -- Second question position matches buffer
   451	        assert.equals("💬: q2", lines[m:block_start(2, 1) + 1])
   452	    end)
   453	end)

exec
/bin/zsh -lc "nl -ba tests/integration/tool_folds_spec.lua | sed -n '1,260p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
     1	local exchange_model = require("parley.exchange_model")
     2	local tool_folds = require("parley.tool_folds")
     3
     4	describe("tool_folds incremental manual folds", function()
     5	    local original_buf
     6	    local buf
     7	    local win
     8
     9	    before_each(function()
    10	        original_buf = vim.api.nvim_get_current_buf()
    11	        buf = vim.api.nvim_create_buf(false, true)
    12	        win = vim.api.nvim_get_current_win()
    13	        vim.api.nvim_win_set_buf(win, buf)
    14	        vim.api.nvim_set_option_value("foldmethod", "manual", { win = win })
    15	        vim.api.nvim_set_option_value("foldenable", true, { win = win })
    16	        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    17	            "header", "", "💬: q", "", "🤖: a", "",
    18	            "🧠: first", "thinking", "", "plain", "tail",
    19	        })
    20	    end)
    21
    22	    after_each(function()
    23	        if vim.api.nvim_buf_is_valid(original_buf) then
    24	            vim.api.nvim_win_set_buf(win, original_buf)
    25	        end
    26	        if vim.api.nvim_buf_is_valid(buf) then
    27	            vim.api.nvim_buf_delete(buf, { force = true })
    28	        end
    29	    end)
    30
    31	    local function model_with(kind, size)
    32	        local model = exchange_model.new(1)
    33	        model:add_exchange(1)
    34	        model:add_block(1, "agent_header", 1)
    35	        model:add_block(1, kind, size)
    36	        return model
    37	    end
    38
    39	    it("leaves a user fold outside the rewritten range untouched", function()
    40	        vim.cmd("10,11fold")
    41	        local model = model_with("thinking", 2)
    42	        tool_folds.reconcile_exchange(buf, win, model, 1)
    43	        tool_folds.with_exchange_update(buf, model, 1, function()
    44	            require("parley.buffer_edit").stream_replace_at_line(buf, 7, {
    45	                "thinking", "inserted thinking",
    46	            })
    47	            model:grow_block(1, 3, 1)
    48	        end)
    49	        vim.cmd("normal! zM")
    50
    51	        assert.equals(7, vim.fn.foldclosed(7))
    52	        assert.equals(9, vim.fn.foldclosedend(7))
    53	        assert.equals(11, vim.fn.foldclosed(11))
    54	        assert.equals(12, vim.fn.foldclosedend(11))
    55	    end)
    56
    57	    it("builds initial folds from semantic model blocks without clearing an unrelated fold", function()
    58	        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    59	            "---", "topic: folds", "file: folds.md", "---", "",
    60	            "💬: q", "", "🤖: [A]", "", "🧠: think", "detail", "",
    61	            "📝: summary", "", "🔧: read id=x", "```json", "{}", "```", "",
    62	            "📎: read id=x", "```", "ok", "```", "", "plain one", "plain two",
    63	        })
    64	        vim.cmd("25,26fold")
    65
    66	        tool_folds.apply_folds(buf)
    67	        vim.cmd("normal! zM")
    68
    69	        assert.equals(10, vim.fn.foldclosed(10))
    70	        assert.equals(11, vim.fn.foldclosedend(10))
    71	        assert.equals(13, vim.fn.foldclosed(13))
    72	        assert.equals(15, vim.fn.foldclosed(15))
    73	        assert.equals(18, vim.fn.foldclosedend(15))
    74	        assert.equals(20, vim.fn.foldclosed(20))
    75	        assert.equals(23, vim.fn.foldclosedend(20))
    76	        assert.equals(25, vim.fn.foldclosed(25))
    77	        assert.equals(26, vim.fn.foldclosedend(25))
    78	    end)
    79
    80	    it("reconciles a changed exchange without leaving a blank-line ghost", function()
    81	        local model = model_with("thinking", 2)
    82	        tool_folds.reconcile_exchange(buf, win, model, 1)
    83	        vim.cmd("normal! zM")
    84
    85	        local windows = tool_folds.prepare_exchange_update(buf, model, 1)
    86	        vim.api.nvim_buf_set_lines(buf, 6, 8, false, { "📝: summary" })
    87	        model:replace_span(1, 3, 1, { { kind = "summary", size = 1 } })
    88	        tool_folds.finalize_exchange_update(buf, windows, model, 1)
    89	        vim.cmd("normal! zM")
    90
    91	        assert.equals(7, vim.fn.foldclosed(7))
    92	        assert.equals(7, vim.fn.foldclosedend(7))
    93	        assert.equals(-1, vim.fn.foldclosed(8))
    94	        assert.equals(0, vim.fn.foldlevel(8))
    95	    end)
    96
    97	    it("prepares and reconciles the changed exchange in every displayed window", function()
    98	        local model = model_with("thinking", 2)
    99	        local second_win = vim.api.nvim_open_win(buf, false, {
   100	            relative = "editor", row = 1, col = 1, width = 30, height = 8,
   101	            style = "minimal",
   102	        })
   103	        vim.api.nvim_set_option_value("foldmethod", "manual", { win = second_win })
   104	        vim.api.nvim_set_option_value("foldenable", true, { win = second_win })
   105	        tool_folds.reconcile_exchange(buf, win, model, 1)
   106	        tool_folds.reconcile_exchange(buf, second_win, model, 1)
   107
   108	        local windows = tool_folds.prepare_exchange_update(buf, model, 1)
   109	        vim.api.nvim_buf_set_lines(buf, 6, 8, false, { "📝: summary" })
   110	        model:replace_span(1, 3, 1, { { kind = "summary", size = 1 } })
   111	        tool_folds.finalize_exchange_update(buf, windows, model, 1)
   112
   113	        for _, target in ipairs({ win, second_win }) do
   114	            vim.api.nvim_win_call(target, function()
   115	                vim.cmd("normal! zM")
   116	                assert.equals(7, vim.fn.foldclosed(7))
   117	                assert.equals(7, vim.fn.foldclosedend(7))
   118	                assert.equals(0, vim.fn.foldlevel(8))
   119	            end)
   120	        end
   121	        vim.api.nvim_win_close(second_win, true)
   122	    end)
   123
   124	    it("restores from the current buffer model without masking a mutation error", function()
   125	        local model = model_with("thinking", 2)
   126	        local recovered = model_with("summary", 1)
   127	        tool_folds.reconcile_exchange(buf, win, model, 1)
   128	        local previous_provider = tool_folds._model_provider
   129	        tool_folds._model_provider = function() return recovered end
   130
   131	        local ok, err = pcall(function()
   132	            tool_folds.with_exchange_update(buf, model, 1, function()
   133	                vim.api.nvim_buf_set_lines(buf, 6, 8, false, { "📝: summary" })
   134	                error("write exploded")
   135	            end)
   136	        end)
   137	        tool_folds._model_provider = previous_provider
   138
   139	        assert.is_false(ok)
   140	        assert.matches("write exploded", err)
   141	        vim.cmd("normal! zM")
   142	        assert.equals(7, vim.fn.foldclosed(7))
   143	        assert.equals(7, vim.fn.foldclosedend(7))
   144	        assert.equals(0, vim.fn.foldlevel(8))
   145	    end)
   146
   147	    it("hydrates a window only once from one model provider", function()
   148	        local calls = 0
   149	        local model = model_with("thinking", 2)
   150	        local provider = function()
   151	            calls = calls + 1
   152	            return model
   153	        end
   154
   155	        assert.is_true(tool_folds.hydrate_window(buf, win, provider))
   156	        assert.is_false(tool_folds.hydrate_window(buf, win, provider))
   157	        assert.equals(1, calls)
   158	        vim.cmd("normal! zM")
   159	        assert.equals(7, vim.fn.foldclosed(7))
   160	        assert.equals(8, vim.fn.foldclosedend(7))
   161	    end)
   162
   163	    it("replaces a persisted orphan fold with the exact initial projection", function()
   164	        vim.api.nvim_buf_set_lines(buf, 6, 8, false, { "📝: summary", "" })
   165	        vim.cmd("8,8fold")
   166	        local model = model_with("summary", 1)
   167
   168	        assert.is_true(tool_folds.hydrate_window(buf, win, function() return model end))
   169	        vim.cmd("normal! zM")
   170
   171	        assert.equals(7, vim.fn.foldclosed(7))
   172	        assert.equals(7, vim.fn.foldclosedend(7))
   173	        assert.equals(0, vim.fn.foldlevel(8))
   174	    end)
   175
   176	    it("does not duplicate live folds when scheduled hydration runs afterward", function()
   177	        local model = model_with("thinking", 2)
   178	        tool_folds.with_exchange_update(buf, model, 1, function()
   179	            model:add_block(1, "tool_use", 2)
   180	        end)
   181
   182	        assert.is_true(tool_folds.hydrate_window(buf, win, function() return model end))
   183	        local ranges = require("parley.fold_projection").desired_folds(model, 1)
   184	        assert.equals(1, vim.fn.foldlevel(ranges[1].start_0 + 1))
   185	        assert.equals(1, vim.fn.foldlevel(ranges[2].start_0 + 1))
   186	        assert.equals(0, vim.fn.foldlevel(ranges[2].end_0 + 2))
   187	    end)
   188
   189	    it("folds recorded item rows when sections and exchanges have no gap", function()
   190	        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
   191	            "---", "topic: gaps", "file: gaps.md", "---", "",
   192	            "💬: first", "", "🤖:[A]", "", "answer", "📝: first summary",
   193	            "💬: second", "", "🤖:[A]", "", "📝: second summary", "",
   194	        })
   195
   196	        tool_folds.apply_folds(buf)
   197	        vim.cmd("normal! zM")
   198
   199	        assert.equals(11, vim.fn.foldclosed(11))
   200	        assert.equals(11, vim.fn.foldclosedend(11))
   201	        assert.equals(16, vim.fn.foldclosed(16))
   202	        assert.equals(16, vim.fn.foldclosedend(16))
   203	        assert.equals(0, vim.fn.foldlevel(17))
   204	    end)
   205
   206	    it("keeps exactly one fold level across consecutive tool-loop appends", function()
   207	        local model = model_with("thinking", 2)
   208	        local second_win = vim.api.nvim_open_win(buf, false, {
   209	            relative = "editor", row = 1, col = 1, width = 30, height = 8,
   210	            style = "minimal",
   211	        })
   212	        vim.api.nvim_set_option_value("foldmethod", "manual", { win = second_win })
   213	        local events = {}
   214	        tool_folds._observer = function(event) events[#events + 1] = event end
   215
   216	        require("parley.tool_loop")._append_section_to_answer(buf, model, 1, {
   217	            kind = "tool_use", name = "read_file", id = "call_1", input = { path = "x" },
   218	        })
   219	        local tool_use = require("parley.fold_projection").desired_folds(model, 1)[2]
   220	        require("parley.tool_loop")._append_section_to_answer(buf, model, 1, {
   221	            kind = "tool_result", name = "read_file", id = "call_1", content = "ok",
   222	        })
   223	        tool_folds._observer = nil
   224
   225	        local ranges = require("parley.fold_projection").desired_folds(model, 1)
   226	        local tool_result = ranges[3]
   227	        assert.equals(8, #events)
   228	        for _, event in ipairs(events) do assert.equals(1, event.exchange_index) end
   229	        for _, target in ipairs({ win, second_win }) do
   230	            vim.api.nvim_win_call(target, function()
   231	                vim.cmd("normal! zM")
   232	                assert.equals(1, vim.fn.foldlevel(tool_use.start_0 + 1))
   233	                assert.equals(1, vim.fn.foldlevel(tool_result.start_0 + 1))
   234	                assert.equals(0, vim.fn.foldlevel(tool_result.end_0 + 2))
   235	            end)
   236	        end
   237	        vim.api.nvim_win_close(second_win, true)
   238	    end)
   239	end)

exec
/bin/zsh -lc 'rg -n "ResolveRefProject|gP|project record|Resolve.*Project|ParleyResolve" README.md atlas lua/parley/keybinding_registry.lua' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
lua/parley/keybinding_registry.lua:441:		-- the fleet-wide project record(s) referencing it (`sdlc resolve --kind
lua/parley/keybinding_registry.lua:445:		default_key = "gP",
lua/parley/keybinding_registry.lua:448:		desc = "Parley resolve project record(s) for ref",
lua/parley/keybinding_registry.lua:449:		help_desc = "Jump to the project record(s) referencing ariadne#11 under cursor (cross-repo); in an issue file with no ref under cursor, uses the file's own issue",

exec
/bin/zsh -lc 'git diff 3974fa25cec1aa5a0f1624297d69bee8529a0e4e..HEAD -- README.md atlas README.md --stat && git diff 3974fa25cec1aa5a0f1624297d69bee8529a0e4e..HEAD -- README.md' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
diff --git a/atlas/chat/exchange_model.md b/atlas/chat/exchange_model.md
index d5d9b66..57ad9b1 100644
--- a/atlas/chat/exchange_model.md
+++ b/atlas/chat/exchange_model.md
@@ -4,13 +4,17 @@ The exchange model (`lua/parley/exchange_model.lua`) is the single source of tru

 ## Core Principle: Everything Is a Block

-An exchange is a flat list of blocks. Each block has a `kind` and `size` (line count). Positions are computed on demand from accumulated sizes. No absolute line numbers are stored.
+An exchange is a flat list of blocks. Each block has a `kind`, `size` (line
+count), and an intra-exchange `gap_before`; the exchange owns the leading gap
+before its question. Positions are computed on demand from accumulated sizes
+and gaps. Absolute line numbers are not retained after parser spans have been
+compiled into this relative layout.

 ```
 Exchange = {
     blocks = {
-        { kind = "question",      size = 1 },   -- 💬:
-        { kind = "agent_header",  size = 1 },   -- 🤖:
+        { kind = "question",      size = 1, gap_before = 0 }, -- 💬:
+        { kind = "agent_header",  size = 1, gap_before = 1 }, -- 🤖:
         { kind = "thinking",      size = 2 },   -- 🧠: semantic block
         { kind = "text",          size = 5 },   -- ordinary response text
         { kind = "tool_use",      size = 4 },   -- 🔧: + json fence
@@ -23,10 +27,13 @@ Exchange = {

 ## Layout Rules

-1. **1 blank margin** between adjacent non-empty blocks.
-2. **Empty blocks (size 0) cancel one margin** — invisible in layout.
-3. **1 blank margin** between exchanges.
-4. **Header** occupies `header_lines` at the top, followed by 1 margin.
+1. Existing chats preserve the zero-, one-, or multi-line gaps implied by
+   parser item spans; new live blocks default to one blank margin.
+2. The exchange exclusively owns its leading gap. The question block owns no
+   duplicate gap; later blocks own only intra-exchange gaps.
+3. Empty blocks contribute neither size nor gap and remain invisible.
+4. `exchange_total_size` excludes the exchange leading gap;
+   `exchange_start` adds each leading gap exactly once.

 ## Lifecycle

@@ -40,9 +47,8 @@ The model is built once per `M.respond` call and lives through the entire respon
 - **Spinner**: tracked as a block; set to size 0 when cleared.
 - **Prompt append**: uses `exchange_total_size` to compute insertion point.
 - **Folding**: `thinking`, `summary`, `tool_use`, and `tool_result` ranges come
-  only from the model. Neovim shrinks a manual fold when its streaming tail is
-  replaced, so Parley recreates only that active foldable range; ordinary text
-  performs no fold command.
+  only from their stated model block spans and stay inside the selected
+  exchange. Gaps are never projected as folds.

 Because the model is live state, `chat_respond` protects every pending async write with a chat lease anchored on an `invalidate=true` extmark on the response's agent-header line (#138). The anchor distinguishes Parley-owned writes from structural edits: streaming and ordinary edits move the anchor (valid), while deleting the header — undo/redo or other structural drift — invalidates the pending response instead of reconciling the model against a changed serialized transcript. (Pre-#138 the lease keyed on `changedtick` and committed each Parley write's new tick; the extmark anchor makes that commit unnecessary.)

@@ -50,14 +56,17 @@ Because the model is live state, `chat_respond` protects every pending async wri

 `from_parsed_chat(parsed_chat)` builds a model from parser output. The shared
 `answer_structure` reducer supplies semantic answer spans; the parser trims
-leading/trailing blank lines so model margins remain the source of truth.
+leading/trailing blank lines from item content, while adjacent absolute spans
+compile into relative gaps. Historical chats do not need canonical spacing.
+Streaming performs the same compilation from its bounded active-segment
+sections when replacing the insertion span.

 ## API

 | Method | Purpose |
 |--------|---------|
-| `add_exchange(q_size)` | Add exchange with question block |
-| `add_block(k, kind, size)` | Append block to exchange k |
+| `add_exchange(q_size, gap?)` | Add exchange with question block |
+| `add_block(k, kind, size, gap?)` | Append block to exchange k |
 | `grow_block(k, b, delta)` | Streaming grew the block |
 | `set_block_size(k, b, size)` | Set exact size (e.g., spinner → 0) |
 | `remove_block(k, b)` | Remove a block |
diff --git a/atlas/chat/lifecycle.md b/atlas/chat/lifecycle.md
index dd4ff11..5bd1988 100644
--- a/atlas/chat/lifecycle.md
+++ b/atlas/chat/lifecycle.md
@@ -20,12 +20,28 @@ registry.
 ## Response (`:ParleyChatRespond` / `<C-g><C-g>`)
 Assembles context (with memory summarization), streams LLM response into buffer. The [exchange model](exchange_model.md) is the single source of truth for all transcript mutations during the response lifecycle — streaming text growth, tool block insertion, and prompt append all go through the model. [Response progress](response_progress.md) is cosmetic extmark state that begins at the response header (or a recursive leg's last visible block), then follows the current generation tip; it never becomes a model block. A per-buffer pending-session guard prevents duplicate calls.

-Streaming fold maintenance is insertion-scoped. After each write, Parley reduces
-only the active insertion block, updates its semantic model span, and recreates
-the fold only for foldable kinds. A late explicit thinking terminator may widen
-that bounded read to its recorded provisional opener. Tool calls/results fold
-immediately from their known appended block indices. Success and cancellation
-use the live model; there is no final whole-chat fold reparse.
+Semantic folds are a pure projection of one exchange's positive-size thinking,
+summary, tool-use, and tool-result blocks (`lua/parley/fold_projection.lua`).
+Streaming still reduces only the active insertion span; a late explicit
+thinking terminator may widen that bounded read to its recorded provisional
+opener. Before a known exchange mutation, Parley removes that exchange's old
+projected folds in every window showing the buffer; afterward it creates the
+updated projection in those same windows. Tool-loop appends use the same
+transaction. Unchanged exchanges receive no fold commands, unrelated user folds
+remain untouched during live reconciliation.
+
+Initial setup and window-entry events parse once and hydrate every exchange in
+the entering window. Hydration first clears restored/manual fold state in that
+window, then renders the complete semantic projection. This makes initial fold
+state a pure function of the parsed exchange model: stale blank-line folds and
+a live transaction that beats scheduled hydration cannot survive as duplicate
+nesting. Fold ranges
+come only from item bounds; inter-item and inter-exchange gaps are never fold
+targets. A lightweight `(buffer, window)` initialization registry
+prevents duplicate manual folds and is cleared with window/buffer teardown.
+Successful live transactions use the current model without reparsing; failure
+recovery reparses only to restore prepared folds while preserving the original
+error.

 Inline-comment submission follows the same preservation boundary. Drill-in
 marker/anchor transformations are planned as original-coordinate byte edits and
diff --git a/atlas/traceability.yaml b/atlas/traceability.yaml
index a10d8ae..6ac43ac 100644
--- a/atlas/traceability.yaml
+++ b/atlas/traceability.yaml
@@ -110,11 +110,17 @@ atlas:
       - lua/parley/exchange_model.lua
       - lua/parley/buffer_edit.lua
       - lua/parley/render_buffer.lua
+      - lua/parley/fold_projection.lua
       - lua/parley/tool_folds.lua
+      - lua/parley/tool_loop.lua
+      - lua/parley/dispatcher.lua
     tests:
       - tests/unit/answer_structure_spec.lua
       - tests/unit/tool_folds_spec.lua
+      - tests/unit/fold_projection_spec.lua
       - tests/integration/tool_folds_spec.lua
+      - tests/integration/create_handler_spec.lua
+      - tests/integration/chat_respond_spec.lua
       - tests/unit/exchange_model_spec.lua
       - tests/unit/buffer_edit_spec.lua
       - tests/unit/render_buffer_spec.lua

exec
/bin/zsh -lc "nl -ba lua/parley/artifact_ref.lua | sed -n '70,240p' && nl -ba lua/parley/init.lua | sed -n '4188,4208p' && nl -ba lua/parley/keybinding_registry.lua | sed -n '438,452p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
    70	-- parse_ref_at_cursor(line, col) -> { ref, byte_start, byte_end } | nil.
    71	-- col is 1-indexed. Returns the ref-shaped span containing the cursor (which may
    72	-- include an interior space, e.g. "#15 M4" — <cword>/<cfile> can't capture that).
    73	function M.parse_ref_at_cursor(line, col)
    74	    for s, ref, e in M.iter_refs(line) do
    75	        if col >= s and col < e then
    76	            return { ref = ref, byte_start = s, byte_end = e }
    77	        end
    78	    end
    79	    return nil
    80	end
    81
    82	-- ref_from_issue_path(path) -> "repo#id" | nil. Derives the issue ref a
    83	-- buffer's FILE denotes: <repo>/workshop/issues/NNNNNN-*.md (active) or
    84	-- <repo>/workshop/history/issues/NNNNNN-*.md (archived) yield "repo#id" with
    85	-- leading zeros stripped. Any other path yields nil. Pure (string → string).
    86	-- Used as the gP buffer fallback: inside an issue file, "this issue" is a
    87	-- meaningful ref even when the cursor isn't on one (ariadne#171 follow-up).
    88	function M.ref_from_issue_path(path)
    89	    if not path or path == "" then
    90	        return nil
    91	    end
    92	    local repo, id = path:match("([^/]+)/workshop/issues/0*(%d+)[^/]*%.md$")
    93	    if not repo then
    94	        repo, id = path:match("([^/]+)/workshop/history/issues/0*(%d+)[^/]*%.md$")
    95	    end
    96	    if not repo then
    97	        return nil
    98	    end
    99	    return repo .. "#" .. id
   100	end
   101
   102	-- parse_resolve_output(stdout, is_json) -> { {path, kind?, milestone?}, ... }.
   103	-- JSON: reads `.files[]`; a github label resolves to {} (empty). Plain: one
   104	-- absolute path per non-empty line.
   105	function M.parse_resolve_output(stdout, is_json)
   106	    local files = {}
   107	    if is_json then
   108	        local ok, decoded = pcall(vim.json.decode, stdout or "")
   109	        if ok and type(decoded) == "table" and decoded.files then
   110	            for _, f in ipairs(decoded.files) do
   111	                files[#files + 1] = { path = f.path, kind = f.kind, milestone = f.milestone }
   112	            end
   113	        end
   114	        return files
   115	    end
   116	    for ln in (stdout or ""):gmatch("[^\n]+") do
   117	        local p = ln:match("^%s*(.-)%s*$")
   118	        if p ~= "" then
   119	            files[#files + 1] = { path = p }
   120	        end
   121	    end
   122	    return files
   123	end
   124
   125	-- run_resolve(ref, opts, on_done, runner): shell to `sdlc resolve --json <ref>`
   126	-- and call on_done(files|nil, err|nil). opts: { cwd, sdlc_cmd, shell, kind }.
   127	-- kind (e.g. "project", ariadne#171 M4) appends `--kind <kind>` so the same
   128	-- flow resolves fleet-wide project records instead of the issue family. The
   129	-- `runner(argv, on_complete)` seam defaults to vim.system; tests inject a fake so
   130	-- no real spawn happens. Reuses issues.build_spawn_argv (handles the "sdlc is a
   131	-- shell function, not a binary" case).
   132	function M.run_resolve(ref, opts, on_done, runner)
   133	    opts = opts or {}
   134	    local issues = require("parley.issues")
   135	    local sdlc_cmd = opts.sdlc_cmd or "sdlc"
   136	    local is_exec = vim.fn.executable(sdlc_cmd) == 1
   137	    -- Match issues.lua's shell resolution so an rc-defined `sdlc` function loads
   138	    -- from the user's login shell, not just vim.o.shell.
   139	    local shell = opts.shell or vim.env.SHELL or vim.o.shell or "sh"
   140	    local cmd = { sdlc_cmd, "resolve", "--json" }
   141	    if opts.kind then
   142	        cmd[#cmd + 1] = "--kind"
   143	        cmd[#cmd + 1] = opts.kind
   144	    end
   145	    cmd[#cmd + 1] = ref
   146	    local argv = issues.build_spawn_argv(cmd, is_exec, shell)
   147	    local run = runner
   148	        or function(a, on_complete)
   149	            vim.system(a, { text = true, cwd = opts.cwd }, function(res)
   150	                on_complete(res.stdout or "", res.code or 1, res.stderr or "")
   151	            end)
   152	        end
   153	    run(argv, function(stdout, code, stderr)
   154	        if code ~= 0 then
   155	            local msg = (stderr ~= "" and stderr or stdout) or ""
   156	            on_done(nil, (msg:gsub("%s+$", "")))
   157	            return
   158	        end
   159	        on_done(M.parse_resolve_output(stdout, true), nil)
   160	    end)
   161	end
   162
   163	-- dispatch_resolve_result decides what to do with a resolve outcome, calling the
   164	-- injected deps so it's unit-testable without Neovim: err -> notify(warn); 0 files
   165	-- (a github/external ref) -> notify(info); 1 -> open; N (a family) -> picker.
   166	-- deps = { notify(msg, level), open(path), picker(ref, files) }. Returns the
   167	-- action taken ("error"|"external"|"open"|"picker") for assertions.
   168	function M.dispatch_resolve_result(ref, files, err, deps)
   169	    if err or not files then
   170	        deps.notify("parley resolve: " .. (err or "no result"), "warn")
   171	        return "error"
   172	    end
   173	    if #files == 0 then
   174	        deps.notify("parley: " .. ref .. " is a github/external ref (no local file)", "info")
   175	        return "external"
   176	    end
   177	    if #files == 1 then
   178	        deps.open(files[1].path)
   179	        return "open"
   180	    end
   181	    deps.picker(ref, files)
   182	    return "picker"
   183	end
   184
   185	-- family_picker_items maps resolved files to float_picker item shape. Pure.
   186	function M.family_picker_items(files)
   187	    local items = {}
   188	    for _, f in ipairs(files) do
   189	        items[#items + 1] = {
   190	            display = (f.kind or "file")
   191	                .. (f.milestone and (" " .. f.milestone) or "")
   192	                .. "  "
   193	                .. vim.fn.fnamemodify(f.path, ":t"),
   194	            search_text = f.path,
   195	            value = f.path,
   196	        }
   197	    end
   198	    return items
   199	end
   200
   201	-- goto_ref_at_cursor: the editor entry (thin IO shell). Reads the ref under the
   202	-- cursor, resolves it against the buffer's repo, and opens/pickers the result.
   203	-- opts.on_no_ref (optional): called when the cursor is NOT on an artifact ref —
   204	-- the smart-gf binding passes native `gf` here so `gf` resolves refs but still
   205	-- goes-to-file on plain paths; the dedicated key omits it (notifies instead).
   206	-- opts.kind (optional): resolve kind, e.g. "project" — the always-cross-repo
   207	-- project class (ariadne#171 M4): jumps to the project record(s) referencing
   208	-- the issue under the cursor, wherever in the fleet they live.
   209	-- opts.buffer_fallback (optional): when the cursor is NOT on a ref but the
   210	-- buffer's file is itself an issue file, use that file's own ref
   211	-- (ref_from_issue_path) — so gP anywhere in an issue file jumps to the
   212	-- project(s) tracking it. A ref under the cursor always wins.
   213	-- Delegated to by parley init's M.cmd.ResolveRef* commands.
   214	function M.goto_ref_at_cursor(opts)
   215	    opts = opts or {}
   216	    local line = vim.api.nvim_get_current_line()
   217	    local col = vim.api.nvim_win_get_cursor(0)[2] + 1 -- 1-indexed byte col
   218	    local hit = M.parse_ref_at_cursor(line, col)
   219	    if not hit and opts.buffer_fallback then
   220	        local ref = M.ref_from_issue_path(vim.api.nvim_buf_get_name(0))
   221	        if ref then
   222	            hit = { ref = ref, buffer_derived = true }
   223	        end
   224	    end
   225	    if not hit then
   226	        if opts.on_no_ref then
   227	            opts.on_no_ref()
   228	        else
   229	            vim.notify("parley: no artifact ref under cursor", vim.log.levels.INFO)
   230	        end
   231	        return
   232	    end
   233	    local _parley = require("parley")
   234	    local neighborhood = require("parley.neighborhood")
   235	    local float_picker = require("parley.float_picker")
   236	    local cwd = neighborhood.for_buf(vim.api.nvim_get_current_buf())
   237	    local sdlc_cmd = (_parley.config and _parley.config.sdlc_cmd) or "sdlc"
   238	    M.run_resolve(hit.ref, { cwd = cwd, sdlc_cmd = sdlc_cmd, kind = opts.kind }, function(files, err)
   239	        vim.schedule(function()
   240	            M.dispatch_resolve_result(hit.ref, files, err, {
  4188	-- native go-to-file (`normal! gf` bypasses this mapping), so `gf` keeps working on
  4189	-- plain paths.
  4190	M.cmd.ResolveRefOrGotoFile = function()
  4191		require("parley.artifact_ref").goto_ref_at_cursor({
  4192			on_no_ref = function() vim.cmd("normal! gf") end,
  4193		})
  4194	end
  4195
  4196	-- ariadne#171 M4: project jump — resolve the issue ref under the cursor to the
  4197	-- PROJECT record(s) referencing it, fleet-wide and archive-inclusive (`sdlc
  4198	-- resolve --kind project`). A project is an always-cross-repo artifact class:
  4199	-- the record may live in a different repo than the issue, so this never
  4200	-- assumes a local path. buffer_fallback: with no ref under the cursor, an
  4201	-- issue-file buffer supplies its own ref — gP anywhere in an issue file
  4202	-- jumps to the project(s) tracking that issue.
  4203	M.cmd.ResolveRefProject = function()
  4204		require("parley.artifact_ref").goto_ref_at_cursor({ kind = "project", buffer_fallback = true })
  4205	end
  4206
  4207	-- Vision tracker commands
  4208	M.cmd.VisionValidate = function() vision_mod.cmd_validate() end
   438		},
   439		{
   440			-- ariadne#171 M4: project jump — resolve the issue ref under the cursor to
   441			-- the fleet-wide project record(s) referencing it (`sdlc resolve --kind
   442			-- project`), regardless of which repo holds the file. Pairs with gf.
   443			id = "resolve_ref_project",
   444			config_key = "chat_shortcut_resolve_ref_project",
   445			default_key = "gP",
   446			default_modes = { "n" },
   447			scope = "parley_buffer",
   448			desc = "Parley resolve project record(s) for ref",
   449			help_desc = "Jump to the project record(s) referencing ariadne#11 under cursor (cross-repo); in an issue file with no ref under cursor, uses the file's own issue",
   450			buffer_local = true,
   451		},
   452		{

exec
/bin/zsh -lc "nl -ba lua/parley/buffer_edit.lua | sed -n '1,120p' && nl -ba lua/parley/tool_loop.lua | sed -n '100,175p' && nl -ba lua/parley/chat_respond.lua | sed -n '1495,1545p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
     1	-- Single mutation entry point for the chat buffer.
     2	--
     3	-- All nvim_buf_set_lines / nvim_buf_set_text calls in the chat buffer
     4	-- rendering pipeline live here. The architectural fitness function in
     5	-- tests/arch/buffer_mutation_spec.lua enforces this invariant.
     6	--
     7	-- See workshop/plans/000090-renderer-refactor.md section 3.
     8
     9	local M = {}
    10
    11	local NS_NAME = "ParleyBufferEdit"
    12	local ns_id = vim.api.nvim_create_namespace(NS_NAME)
    13
    14	-- ============================================================================
    15	-- PosHandle: opaque extmark-backed position. Caller never sees raw line
    16	-- numbers. Internally a { buf, ns_id, ex_id, dead } table; the line is
    17	-- resolved on demand via nvim_buf_get_extmark_by_id, so concurrent
    18	-- inserts at or before the position are handled by the extmark gravity
    19	-- mechanism (right_gravity = false means inserts AT the position push
    20	-- the handle right, perfect for "anchor before this line, append text").
    21	-- ============================================================================
    22
    23	--- Create a position handle anchored at a 0-indexed buffer line.
    24	--- @param buf integer
    25	--- @param line_0_indexed integer
    26	--- @return PosHandle
    27	function M.make_handle(buf, line_0_indexed)
    28	    local ex_id = vim.api.nvim_buf_set_extmark(buf, ns_id, line_0_indexed, 0, {
    29	        right_gravity = false,
    30	        strict = false,
    31	    })
    32	    return { buf = buf, ns_id = ns_id, ex_id = ex_id, dead = false }
    33	end
    34
    35	--- Resolve the current 0-indexed buffer line of a handle.
    36	function M.handle_line(handle)
    37	    if handle.dead then
    38	        error("buffer_edit: handle is dead")
    39	    end
    40	    local pos = vim.api.nvim_buf_get_extmark_by_id(handle.buf, handle.ns_id, handle.ex_id, {})
    41	    return pos[1]
    42	end
    43
    44	--- Mark a handle dead and remove its extmark. Subsequent operations on
    45	--- the handle raise.
    46	function M.handle_invalidate(handle)
    47	    if not handle.dead then
    48	        pcall(vim.api.nvim_buf_del_extmark, handle.buf, handle.ns_id, handle.ex_id)
    49	        handle.dead = true
    50	    end
    51	end
    52
    53	-- ============================================================================
    54	-- Topic header ops
    55	-- ============================================================================
    56
    57	--- Replace the line at line_0_indexed with `text`.
    58	function M.set_topic_header_line(buf, line_0_indexed, text)
    59	    vim.api.nvim_buf_set_lines(buf, line_0_indexed, line_0_indexed + 1, false, { text })
    60	end
    61
    62	--- Insert `text` as a new line right after line_0_indexed.
    63	function M.insert_topic_line(buf, after_line_0_indexed, text)
    64	    vim.api.nvim_buf_set_lines(buf, after_line_0_indexed + 1, after_line_0_indexed + 1, false, { text })
    65	end
    66
    67	-- ============================================================================
    68	-- Answer region ops
    69	-- ============================================================================
    70
    71	local render_buffer = require("parley.render_buffer")
    72
    73	--- Insert a single blank line after the given 0-indexed line. Used to
    74	--- pad a question that doesn't already end with whitespace.
    75	function M.pad_question_with_blank(buf, after_line_0_indexed)
    76	    vim.api.nvim_buf_set_lines(buf, after_line_0_indexed + 1, after_line_0_indexed + 1, false, { "" })
    77	end
    78
    79	--- Create a fresh answer region after the given 0-indexed line. Writes
    80	--- a blank separator + agent header + trailing blank, returning a
    81	--- PosHandle pointing at the trailing blank — the line where streaming
    82	--- writes should append.
    83	--- @param buf integer
    84	--- @param after_line_0_indexed integer
    85	--- @param agent_prefix string  e.g. "[Claude]"
    86	--- @param agent_suffix string|nil  e.g. "[🔧]"
    87	--- @return PosHandle
    88	function M.create_answer_region(buf, after_line_0_indexed, agent_prefix, agent_suffix)
    89	    local lines = render_buffer.agent_header_lines(agent_prefix, agent_suffix)
    90	    local insert_at = after_line_0_indexed + 1
    91	    vim.api.nvim_buf_set_lines(buf, insert_at, insert_at, false, lines)
    92	    -- Trailing blank is at insert_at + #lines - 1.
    93	    return M.make_handle(buf, insert_at + #lines - 1)
    94	end
    95
    96	--- Delete an answer region by inclusive 0-indexed line range.
    97	function M.delete_answer(buf, line_start_0_indexed, line_end_0_indexed)
    98	    vim.api.nvim_buf_set_lines(buf, line_start_0_indexed, line_end_0_indexed + 1, false, {})
    99	end
   100
   101	--- Replace an answer region with a single blank separator. Returns a
   102	--- handle anchored at the blank — the next answer's create_answer_region
   103	--- should be called using this handle's resolved line.
   104	function M.replace_answer(buf, line_start_0_indexed, line_end_0_indexed)
   105	    vim.api.nvim_buf_set_lines(buf, line_start_0_indexed, line_end_0_indexed + 1, false, { "" })
   106	    return M.make_handle(buf, line_start_0_indexed)
   107	end
   108
   109	--- Replace the entire chat buffer with the given lines for callers whose
   110	--- operation intentionally owns the complete document.
   111	function M.replace_all_lines(buf, lines)
   112	    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
   113	end
   114
   115	--- Replace the entire chat buffer after a pure definition-footnote transform.
   116	function M.replace_all_lines_for_definition(buf, lines)
   117	    M.replace_all_lines(buf, lines)
   118	end
   119
   120	--- Append a section to an answer. The section is rendered via
   100	--- Scans the active exchange for tool_use blocks without a following
   101	--- tool_result and writes synthetic 📎: results for them.
   102	--- @param bufnr integer
   103	function M.repair_unmatched_tool_blocks(bufnr)
   104	    local state = state_by_buf[bufnr]
   105	    local model = state and state.model
   106	    local ex_idx = state and state.exchange_idx
   107	    if not ex_idx then return end
   108
   109	    -- Scan blocks: every tool_use must be followed by a tool_result
   110	    local blocks = model.exchanges[ex_idx].blocks
   111	    local serialize = require("parley.tools.serialize")
   112	    for i, blk in ipairs(blocks) do
   113	        if blk.kind == "tool_use" then
   114	            -- Check if next block is a tool_result
   115	            local next_blk = blocks[i + 1]
   116	            if not next_blk or next_blk.kind ~= "tool_result" then
   117	                -- Unmatched — read the tool_use to get id/name
   118	                local start_line = model:block_start(ex_idx, i)
   119	                local end_line = model:block_end(ex_idx, i)
   120	                local buf_lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line + 1, false)
   121	                local text = table.concat(buf_lines, "\n")
   122	                local parsed_call = serialize.parse_call(text)
   123	                if parsed_call then
   124	                    M._append_section_to_answer(bufnr, model, ex_idx, {
   125	                        kind = "tool_result",
   126	                        id = parsed_call.id,
   127	                        name = parsed_call.name,
   128	                        content = "(cancelled by user)",
   129	                        is_error = true,
   130	                    })
   131	                end
   132	            end
   133	        end
   134	    end
   135
   136	    M.reset(bufnr)
   137	end
   138
   139	--- Append a section to the active exchange's answer using the exchange
   140	--- model for position computation. Inserts at model:answer_append_pos(),
   141	--- which is always INSIDE the active answer region — never past the
   142	--- placeholder 💬: of the next exchange.
   143	---
   144	--- @param bufnr integer
   145	--- @param model ExchangeModel  from exchange_model.from_parsed_chat or state
   146	--- @param exchange_idx integer  1-based exchange index
   147	--- @param section table {kind, ...kind-specific fields}
   148	function M._append_section_to_answer(bufnr, model, exchange_idx, section)
   149	    local buffer_edit = require("parley.buffer_edit")
   150	    local render_buffer = require("parley.render_buffer")
   151	    local lines = render_buffer.render_section(section)
   152	    require("parley.tool_folds").with_exchange_update(bufnr, model, exchange_idx, function()
   153	        model:add_block(exchange_idx, section.kind, #lines)
   154	        local blk_idx = #model.exchanges[exchange_idx].blocks
   155	        local pos = model:block_start(exchange_idx, blk_idx)
   156	        -- Insert margin + content. The model's block_start is where
   157	        -- the content goes; the margin is one line before it.
   158	        local insert_lines = { "" }  -- margin blank
   159	        for _, l in ipairs(lines) do
   160	            table.insert(insert_lines, l)
   161	        end
   162	        buffer_edit.insert_lines_at(bufnr, pos - 1, insert_lines)
   163	    end)
   164	end
   165
   166	--------------------------------------------------------------------------------
   167	-- The driver
   168	--------------------------------------------------------------------------------
   169
   170	--- Process the raw SSE response from a completed Anthropic streaming
   171	--- call. Decodes tool_use blocks, executes each via the dispatcher,
   172	--- and writes 🔧: / 📎: blocks into the buffer in streaming order.
   173	---
   174	--- Returns one of:
   175	---   "done"    — no tool_use in the response (plain text reply),
  1495	        -- the first call.
  1496	        local model = live_model
  1497	        local target_idx = live_target_idx
  1498	        if not model then
  1499	            model = exchange_model.from_parsed_chat(parsed_chat)
  1500	            target_idx = exchange_idx or #model.exchanges
  1501	        end
  1502	        tool_loop_mod.register_live_model(buf, model, target_idx)
  1503
  1504	        -- Compute response_start_line using the model.
  1505	        --
  1506	        -- Every visible element is a block in the model. The model
  1507	        -- handles margins between non-empty blocks automatically.
  1508	        -- We just add blocks and ask for positions.
  1509	        --
  1510	        -- Every visible element is a block in the model. The model
  1511	        -- handles margins between non-empty blocks automatically.
  1512	        -- We add blocks to the model, then insert the corresponding
  1513	        -- lines (margin + content) into the buffer.
  1514	        --
  1515	        local stream_block_idx
  1516	        local initial_progress_tip
  1517	        if is_recursion then
  1518	            -- Recursion: append streaming placeholder after existing blocks.
  1519	            model:add_block(target_idx, "stream_placeholder", 1)
  1520	            stream_block_idx = #model.exchanges[target_idx].blocks
  1521	            local pos = model:block_start(target_idx, stream_block_idx)
  1522	            initial_progress_tip = pos - 1
  1523	            buffer_edit.insert_lines_at(buf, initial_progress_tip, { "", "" })  -- margin + blank content
  1524	        else
  1525	            -- Fresh answer: add agent_header + streaming placeholder. Pending
  1526	            -- presentation is an extmark and never enters the exchange model.
  1527	            model:add_block(target_idx, "agent_header", 1)
  1528	            model:add_block(target_idx, "stream_placeholder", 1)
  1529	            stream_block_idx = #model.exchanges[target_idx].blocks
  1530	            initial_progress_tip = model:block_start(target_idx, 2)
  1531
  1532	            -- Before inserting, clean up any trailing blank lines after
  1533	            -- the question in the buffer. The model's margin will be the
  1534	            -- only blank between question and agent_header.
  1535	            local agent_blk_idx = 2  -- block 1 is question, block 2 is agent_header
  1536	            local insert_start = model:block_start(target_idx, agent_blk_idx) - 1  -- -1 for margin
  1537	            -- Clean up excess blank lines at the insert point. Keep
  1538	            -- exactly 1 blank if there's a following exchange (the
  1539	            -- inter-exchange margin). Delete all blanks only if this
  1540	            -- is the last exchange.
  1541	            local buf_line_count = vim.api.nvim_buf_line_count(buf)
  1542	            if insert_start < buf_line_count then
  1543	                local blank_count = 0
  1544	                local check_lines = vim.api.nvim_buf_get_lines(buf, insert_start, buf_line_count, false)
  1545	                for _, l in ipairs(check_lines) do

exec
/bin/zsh -lc "nl -ba lua/parley/buffer_edit.lua | sed -n '120,190p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   120	--- Append a section to an answer. The section is rendered via
   121	--- render_buffer.render_section. If the line at `after_line_0_indexed`
   122	--- is non-empty, a blank separator is inserted first so blocks don't
   123	--- concatenate. Returns a PosHandle anchored at the line right after
   124	--- the last appended line — the next streaming or section append goes
   125	--- there.
   126	--- @param buf integer
   127	--- @param after_line_0_indexed integer
   128	--- @param section table
   129	--- @return PosHandle
   130	function M.append_section_to_answer(buf, after_line_0_indexed, section)
   131	    local prev_line = vim.api.nvim_buf_get_lines(buf, after_line_0_indexed, after_line_0_indexed + 1, false)[1] or ""
   132	    local rendered = render_buffer.render_section(section)
   133	    local insert_lines = {}
   134	    if prev_line:match("%S") then
   135	        table.insert(insert_lines, "")
   136	    end
   137	    for _, l in ipairs(rendered) do
   138	        table.insert(insert_lines, l)
   139	    end
   140	    local insert_at = after_line_0_indexed + 1
   141	    vim.api.nvim_buf_set_lines(buf, insert_at, insert_at, false, insert_lines)
   142	    return M.make_handle(buf, insert_at + #insert_lines - 1)
   143	end
   144
   145	--- Apply normalized half-open byte edits against an original joined-text slice.
   146	--- Coordinates are 1-based byte boundaries; start == end is insertion.
   147	--- The complete plan is validated and mapped before the first buffer mutation.
   148	function M.apply_text_edits(buf, start_row0, source_text, edits)
   149	    source_text = source_text or ""
   150	    edits = edits or {}
   151	    local limit = #source_text + 1
   152
   153	    local function boundary(byte)
   154	        local row, col = start_row0, 0
   155	        local cursor = 1
   156	        while cursor < byte do
   157	            local nl = source_text:find("\n", cursor, true)
   158	            if not nl or nl >= byte then
   159	                col = col + byte - cursor
   160	                return row, col
   161	            end
   162	            row = row + 1
   163	            col = 0
   164	            cursor = nl + 1
   165	        end
   166	        return row, col
   167	    end
   168
   169	    local mapped = {}
   170	    local previous
   171	    local line_delta = 0
   172	    for index, edit in ipairs(edits) do
   173	        assert(type(edit) == "table" and type(edit.start_byte) == "number"
   174	            and type(edit.end_byte) == "number" and type(edit.replacement) == "string",
   175	            "buffer_edit: invalid text edit")
   176	        assert(edit.start_byte % 1 == 0 and edit.end_byte % 1 == 0
   177	            and edit.start_byte >= 1 and edit.start_byte <= edit.end_byte
   178	            and edit.end_byte <= limit, "buffer_edit: text edit out of range")
   179	        if previous then
   180	            assert(previous.end_byte <= edit.start_byte, "buffer_edit: overlapping text edits")
   181	            assert(not (previous.start_byte == previous.end_byte
   182	                and edit.start_byte == edit.end_byte
   183	                and previous.start_byte == edit.start_byte),
   184	                "buffer_edit: duplicate insertion boundary")
   185	        end
   186	        local start_row, start_col = boundary(edit.start_byte)
   187	        local end_row, end_col = boundary(edit.end_byte)
   188	        mapped[index] = {
   189	            start_row = start_row, start_col = start_col,
   190	            end_row = end_row, end_col = end_col,

exec
/bin/zsh -lc "rg -n \"insert_lines_at\" lua/parley/buffer_edit.lua lua/parley -g'*.lua'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
lua/parley/buffer_edit.lua:271:function M.insert_lines_at(buf, line_0_indexed, lines)
lua/parley/tool_loop.lua:162:        buffer_edit.insert_lines_at(bufnr, pos - 1, insert_lines)
lua/parley/buffer_edit.lua:271:function M.insert_lines_at(buf, line_0_indexed, lines)
lua/parley/chat_respond.lua:1285:            buffer_edit.insert_lines_at(buf, insert_at, insert_lines)
lua/parley/chat_respond.lua:1339:            buffer_edit.insert_lines_at(buf, keep, insert_lines)
lua/parley/chat_respond.lua:1523:            buffer_edit.insert_lines_at(buf, initial_progress_tip, { "", "" })  -- margin + blank content
lua/parley/chat_respond.lua:1564:            buffer_edit.insert_lines_at(buf, insert_start, insert_lines)
lua/parley/chat_respond.lua:1900:                            buffer_edit.insert_lines_at(buf, insert_at, { "", _parley.config.chat_user_prefix, "" })

exec
/bin/zsh -lc "nl -ba lua/parley/buffer_edit.lua | sed -n '260,285p' && nl -ba lua/parley/chat_respond.lua | sed -n '1540,1570p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   260	end
   261
   262	--- Delete from `line_0_indexed` to the end of the buffer.
   263	function M.delete_to_end(buf, line_0_indexed)
   264	    vim.api.nvim_buf_set_lines(buf, line_0_indexed, -1, false, {})
   265	end
   266
   267	--- Insert raw lines at the given 0-indexed line. Used for the
   268	--- end-of-stream "next user prompt" insert which is structurally
   269	--- distinct from append_section_to_answer (no rendering, no separator
   270	--- handling — caller passes the exact lines).
   271	function M.insert_lines_at(buf, line_0_indexed, lines)
   272	    vim.api.nvim_buf_set_lines(buf, line_0_indexed, line_0_indexed, false, lines)
   273	end
   274
   275	--- Replace the line at line_0_indexed with the given text. Distinct
   276	--- from set_topic_header_line in name only — semantically identical,
   277	--- but kept separate so the call sites read clearly at the migration
   278	--- boundary. Used for the progress spinner line update path.
   279	function M.replace_line_at(buf, line_0_indexed, text)
   280	    vim.api.nvim_buf_set_lines(buf, line_0_indexed, line_0_indexed + 1, false, { text or "" })
   281	end
   282
   283	--- Replace one line at line_0_indexed with multiple lines. Used by
   284	--- dispatcher.create_handler's streaming chunk replacement path —
   285	--- the existing single line at write_at gets replaced with the
  1540	            -- is the last exchange.
  1541	            local buf_line_count = vim.api.nvim_buf_line_count(buf)
  1542	            if insert_start < buf_line_count then
  1543	                local blank_count = 0
  1544	                local check_lines = vim.api.nvim_buf_get_lines(buf, insert_start, buf_line_count, false)
  1545	                for _, l in ipairs(check_lines) do
  1546	                    if not l:match("%S") then
  1547	                        blank_count = blank_count + 1
  1548	                    else
  1549	                        break
  1550	                    end
  1551	                end
  1552	                -- If there's content after the blanks (next exchange),
  1553	                -- keep 1 blank as the inter-exchange margin.
  1554	                local has_next = (insert_start + blank_count) < buf_line_count
  1555	                local keep = has_next and 1 or 0
  1556	                local to_delete = blank_count - keep
  1557	                if to_delete > 0 then
  1558	                    buffer_edit.delete_lines_after(buf, insert_start, to_delete)
  1559	                end
  1560	            end
  1561	            local insert_lines = { "", agent_prefix .. agent_suffix }
  1562	            table.insert(insert_lines, "")  -- margin before stream_placeholder
  1563	            table.insert(insert_lines, "")  -- stream_placeholder content (blank)
  1564	            buffer_edit.insert_lines_at(buf, insert_start, insert_lines)
  1565	        end
  1566
  1567	        -- #138: anchor the lease on the agent-header (`🤖:`) line — block 2 of the
  1568	        -- exchange (block 1 is the question; same index in fresh + recursion paths). It's the
  1569	        -- structural marker for the response: streaming operates below it, so ordinary writes
  1570	        -- leave it untouched, while undo/redo of the inserted response (or the

exec
/bin/zsh -lc "sed -n '220,330p' workshop/issues/000195-reconcile-semantic-folds-exactly.md && tail -40 workshop/issues/000195-reconcile-semantic-folds-exactly.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
under one gravity configuration, and a migrated manual fold exposes no fold ID
that endpoint anchors can delete reliably. Replaced persistent ownership with a
localized prepare-before-mutation/reconcile-after-mutation transaction, defined
the exact window-local `zd` behavior and overlap limitation, made late-window
hydration explicitly reparse through one provider, added real consumer/race
tests, and raised the estimate from 2.0h to 3.0h.

### 2026-07-17 — Transaction scope and failure review

Expanded prepare/reconcile across every window displaying the changed buffer;
placed streaming writes and model callbacks inside a dispatcher `around_write`
finally boundary; defined parse-from-buffer recovery without masking the
original error; and added a lightweight per-window initialization registry so
repeat setup/events cannot create duplicate identical folds. Explicitly scoped
external structural-edit rehydration out of this regression.

### 2026-07-18 — Hydration/live-transaction race

Changed hydration from add-once to exact convergence after operator testing
showed that a live tool transaction can create folds before its scheduled
initial hydration. The adapter now removes all native fold layers at projected
semantic starts before rendering one semantic projection, allowing hydration
and later exchange transactions to repair duplicate levels while retaining the
documented overlapping-user-fold limitation.

### 2026-07-18 — Migrated trailing-margin cleanup

Extended the pure projection with model-owned trailing margin rows after smoke
testing showed that an already-migrated one-line ghost sits outside all desired
fold starts. Reconciliation clears those rows before rendering, making the
blank-line invariant self-healing during hydration and live updates.

### 2026-07-18 — Absolute-span root correction

Revised the plan after proving the remaining blank fold is a model coordinate
error, not a migrated Neovim fold. `parsed_chat` already states absolute item
bounds; the model must preserve their implied gaps instead of reconstructing a
canonical document. Fold reconciliation will target only foldable item spans
inside the selected exchange, making inter-exchange gaps irrelevant.

### 2026-07-18 — Deterministic initial hydration

Initial window hydration now replaces restored manual-fold state before
rendering the full semantic projection. This is the one lifecycle boundary
where document-wide cleanup is required to make folds a pure function of
content; subsequent response/tool mutations retain localized per-exchange
prepare/reconcile behavior.
### 2026-07-17 — Transaction scope and failure review

Expanded prepare/reconcile across every window displaying the changed buffer;
placed streaming writes and model callbacks inside a dispatcher `around_write`
finally boundary; defined parse-from-buffer recovery without masking the
original error; and added a lightweight per-window initialization registry so
repeat setup/events cannot create duplicate identical folds. Explicitly scoped
external structural-edit rehydration out of this regression.

### 2026-07-18 — Hydration/live-transaction race

Changed hydration from add-once to exact convergence after operator testing
showed that a live tool transaction can create folds before its scheduled
initial hydration. The adapter now removes all native fold layers at projected
semantic starts before rendering one semantic projection, allowing hydration
and later exchange transactions to repair duplicate levels while retaining the
documented overlapping-user-fold limitation.

### 2026-07-18 — Migrated trailing-margin cleanup

Extended the pure projection with model-owned trailing margin rows after smoke
testing showed that an already-migrated one-line ghost sits outside all desired
fold starts. Reconciliation clears those rows before rendering, making the
blank-line invariant self-healing during hydration and live updates.

### 2026-07-18 — Absolute-span root correction

Revised the plan after proving the remaining blank fold is a model coordinate
error, not a migrated Neovim fold. `parsed_chat` already states absolute item
bounds; the model must preserve their implied gaps instead of reconstructing a
canonical document. Fold reconciliation will target only foldable item spans
inside the selected exchange, making inter-exchange gaps irrelevant.

### 2026-07-18 — Deterministic initial hydration

Initial window hydration now replaces restored manual-fold state before
rendering the full semantic projection. This is the one lifecycle boundary
where document-wide cleanup is required to make folds a pure function of
content; subsequent response/tool mutations retain localized per-exchange
prepare/reconcile behavior.

exec
/bin/zsh -lc 'rg -n "around_write|before_write|after_write" lua/parley tests/integration/create_handler_spec.lua tests/integration/chat_respond_spec.lua' in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc 'rg -n "fold_projection|FOLDABLE|thinking = true|summary = true|tool_use = true|tool_result = true|:fold|normal! zE|normal! zd|foldlevel'"\\(|foldclosed\" lua/parley tests/arch" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
lua/parley/fold_projection.lua:5:local FOLDABLE = {
lua/parley/fold_projection.lua:6:    thinking = true,
lua/parley/fold_projection.lua:7:    summary = true,
lua/parley/fold_projection.lua:8:    tool_use = true,
lua/parley/fold_projection.lua:9:    tool_result = true,
lua/parley/fold_projection.lua:20:        if block.size > 0 and FOLDABLE[block.kind] then
lua/parley/answer_structure.lua:7:    summary = true,
lua/parley/answer_structure.lua:8:    tool_use = true,
lua/parley/answer_structure.lua:9:    tool_result = true,
lua/parley/tool_folds.lua:11:local projection = require("parley.fold_projection")
lua/parley/tool_folds.lua:31:            while vim.fn.foldlevel(row) > 0 do
lua/parley/tool_folds.lua:32:                vim.cmd("normal! zd")
lua/parley/tool_folds.lua:130:        vim.cmd("normal! zE")

 succeeded in 0ms:
tests/integration/create_handler_spec.lua:272:            after_write = function(qid, chunk, delta, last_written_line_0)
tests/integration/create_handler_spec.lua:310:    it("wraps the write and callbacks in around_write", function()
tests/integration/create_handler_spec.lua:315:            after_write = function() events[#events + 1] = "after" end,
tests/integration/create_handler_spec.lua:316:            around_write = function(qid, chunk, write)
lua/parley/dispatcher.lua:540:		if opts.before_write and not opts.before_write(qid, chunk) then
lua/parley/dispatcher.lua:582:		if opts.after_write then
lua/parley/dispatcher.lua:583:			opts.after_write(qid, chunk, delta, end_line - 1)
lua/parley/dispatcher.lua:603:		if opts.around_write then
lua/parley/dispatcher.lua:604:			opts.around_write(qid, chunk, write)
lua/parley/chat_pending.lua:422:    -- Since before_write, mutation, and tip_written share one scheduled callback,
lua/parley/chat_pending.lua:424:    session.before_write = function(_self)
lua/parley/chat_respond.lua:1026:                if spinner.before_write and not spinner.before_write() then
lua/parley/chat_respond.lua:1036:                if spinner.after_write then
lua/parley/chat_respond.lua:1037:                    spinner.after_write()
lua/parley/chat_respond.lua:1707:            before_write = function(_qid, _chunk)
lua/parley/chat_respond.lua:1711:                return pending_session:before_write()
lua/parley/chat_respond.lua:1713:            after_write = function(_qid, _chunk, _delta, last_written_line_0)
lua/parley/chat_respond.lua:1718:            around_write = function(_qid, _chunk, write)
lua/parley/chat_respond.lua:1947:                        end, before_write = function()
lua/parley/chat_respond.lua:1949:                        end, after_write = function()

exec
/bin/zsh -lc 'git diff --check 3974fa25cec1aa5a0f1624297d69bee8529a0e4e..HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
exec
/bin/zsh -lc "rg -n \"write exploded|model mutation|mutation error|error\\(\" tests/integration/tool_folds_spec.lua tests/integration/chat_respond_spec.lua tests/integration/create_handler_spec.lua" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
tests/integration/chat_respond_spec.lua:1192:            notify = function() error("unexpected notification") end,
tests/integration/chat_respond_spec.lua:1193:            log_error = function() error("unexpected log") end,
tests/integration/chat_respond_spec.lua:1208:                if failure == "history" then error(secret .. string.rep("x", 1000)) end
tests/integration/chat_respond_spec.lua:1212:                    if failure == "stop" then error(secret .. string.rep("x", 1000)) end
tests/integration/chat_respond_spec.lua:1342:        history.confirm = function() error("inactive history must not prompt") end
tests/integration/chat_respond_spec.lua:2097:                error("streaming must not parse the whole document")
tests/integration/chat_respond_spec.lua:2580:        buffer_edit.replace_all_lines = function() error("whole-buffer rewrite") end
tests/integration/chat_respond_spec.lua:2656:        buffer_edit.replace_all_lines = function() error("whole-buffer rewrite") end
tests/integration/tool_folds_spec.lua:124:    it("restores from the current buffer model without masking a mutation error", function()
tests/integration/tool_folds_spec.lua:134:                error("write exploded")
tests/integration/tool_folds_spec.lua:140:        assert.matches("write exploded", err)

exec
/bin/zsh -lc "rg -n \"remove_block|remove_section|set_block_size|grow_block|grow_question\" lua/parley tests | sed -n '1,200p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
lua/parley/chat_respond.lua:1649:        -- model via grow_question.
lua/parley/chat_respond.lua:1652:            model:grow_block(target_idx, stream_block_idx, delta)
lua/parley/chat_respond.lua:1746:                    model:set_block_size(target_idx, stream_block_idx, 0)
lua/parley/exchange_model.lua:95:function Model:grow_block(k, b, delta)
lua/parley/exchange_model.lua:100:function Model:set_block_size(k, b, new_size)
lua/parley/exchange_model.lua:108:function Model:remove_block(k, b)
lua/parley/exchange_model.lua:232:--- @deprecated Use grow_block
lua/parley/exchange_model.lua:234:    return self:grow_block(k, s, delta)
lua/parley/exchange_model.lua:237:--- @deprecated Use remove_block
lua/parley/exchange_model.lua:238:function Model:remove_section(k, s)
lua/parley/exchange_model.lua:239:    return self:remove_block(k, s)
lua/parley/exchange_model.lua:263:function Model:grow_question(k, delta)
lua/parley/exchange_model.lua:264:    self:grow_block(k, 1, delta)
tests/integration/tool_folds_spec.lua:47:            model:grow_block(1, 3, 1)
tests/unit/exchange_model_spec.lua:102:    it("grow_block updates the size and shifts subsequent positions", function()
tests/unit/exchange_model_spec.lua:110:        m:grow_block(1, 3, 2)
tests/unit/exchange_model_spec.lua:115:    it("grow_question shifts all subsequent positions", function()
tests/unit/exchange_model_spec.lua:120:        m:grow_question(1, 5)  -- e.g. raw_request_fence
tests/unit/exchange_model_spec.lua:143:        m:set_block_size(1, 3, 0)
tests/unit/exchange_model_spec.lua:183:        m:grow_block(1, 3, 3)
tests/unit/exchange_model_spec.lua:318:        m:set_block_size(1, 3, 0)

exec
/bin/zsh -lc "nl -ba lua/parley/chat_respond.lua | sed -n '1728,1765p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
  1728	        local function collapse_empty_answer()
  1729	            if not stream_block_idx then
  1730	                return
  1731	            end
  1732	            local sblk = model.exchanges[target_idx].blocks[stream_block_idx]
  1733	            if sblk and sblk.size == 1 then
  1734	                local spos = model:block_start(target_idx, stream_block_idx)
  1735	                local sline = vim.api.nvim_buf_get_lines(buf, spos, spos + 1, false)[1] or ""
  1736	                if not sline:match("%S") then
  1737	                    -- Just a blank — remove it + its margin, set size 0 (the
  1738	                    -- empty-block rule cancels the margin).
  1739	                    local del_start = math.max(spos - 1, 0)
  1740	                    local del_count = spos - del_start + 1
  1741	                    if not guarded_write(function()
  1742	                        buffer_edit.delete_lines_after(buf, del_start, del_count)
  1743	                    end) then
  1744	                        return
  1745	                    end
  1746	                    model:set_block_size(target_idx, stream_block_idx, 0)
  1747	                end
  1748	            end
  1749	        end
  1750
  1751	        local leg_teardown_done = false
  1752	        local discard_notice
  1753	        local function teardown_chat_leg(notice)
  1754	            if leg_teardown_done then return end
  1755	            leg_teardown_done = true
  1756	            local owns_shell = false
  1757	            if vim.api.nvim_buf_is_valid(buf) then
  1758	                owns_shell = chat_lease.validate(buf, lease_generation, buf_changedtick(buf)) == true
  1759	            end
  1760	            if owns_shell then collapse_empty_answer() end
  1761	            finalize_mutated_api_leg()
  1762	            chat_lease.clear(buf, lease_generation)
  1763	            if notice then vim.notify(notice, vim.log.levels.WARN) end
  1764	        end
  1765

codex
```verdict
verdict: FIX-THEN-SHIP
confidence: medium
```

The semantic-fold work largely matches #195’s purpose: fold ranges now derive from `exchange_model`, live mutations are exchange-local, and atlas updates cover the new fold projection flow. I did find boundary issues to fix before shipping: unrelated `gP` project-jump behavior leaked into this issue without README coverage, and several Plan-promised tests are not present in the diff.

1. Strengths

- [fold_projection.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/fold_projection.lua:5) owns the foldable-kind policy in one pure module and projects only model-derived ranges.
- [tool_folds.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/tool_folds.lua:81) gives streaming/tool-loop callers a shared mutation transaction instead of keeping add-only fold creation paths.
- [exchange_model.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/exchange_model.lua:275) correctly moves parsed absolute spans into relative gap metadata, preserving historical zero/one/multi-line gaps.
- Atlas updates in `atlas/chat/exchange_model.md` and `atlas/chat/lifecycle.md` reflect the new exchange-gap and fold-projection model.

2. Critical findings

None.

3. Important findings

- [artifact_ref.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/artifact_ref.lua:82), [init.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/init.lua:4196), [keybinding_registry.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/keybinding_registry.lua:443): unrelated `gP` buffer-fallback behavior is shipped inside #195, but it is not in #195’s Spec/Plan and README was not updated. This is user-facing keybinding behavior. Fix by removing it from this boundary or revising the issue/plan scope and updating README discoverability.
- [tool_folds.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/tool_folds.lua:129): `hydrate_window` now uses `normal! zE`, while the issue Spec still says Parley never issues `zE` / document-wide fold clear. Later revisions imply this became intentional for initial hydration, but the Spec/Done contract was not reconciled. Fix the tracker text to carve out initial hydration explicitly, or narrow the implementation.
- [tool_folds_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/integration/tool_folds_spec.lua:124), [chat_respond_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/integration/chat_respond_spec.lua:2044): coverage does not fully deliver the checked Plan’s promised production cases: streaming multi-window locality/observer sequencing, empty-reduction finalization, injected streaming write failure, injected post-model-update failure, and stale scheduled hydration after buffer/window teardown are not visible in the diff. Add focused integration coverage or untick/revise those Plan claims.

4. Minor findings

- [exchange_model.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/exchange_model.lua:22): the file header still describes the old canonical layout convention, which now conflicts with stored actual gaps.

5. Test coverage notes

I did not run the suite because this boundary review was requested as read-only. I inspected the changed specs against the Plan. The pure projection and parsed-gap regressions are well covered; the missing coverage is specifically around production streaming failure/locality promises.

6. Architectural notes for upcoming work

- `ARCH-DRY`: Pass for semantic fold policy and coordinates; flag only the unrelated `gP` scope leak as outside #195’s source-of-truth story.
- `ARCH-PURE`: Pass for `fold_projection` and `exchange_model`; the Neovim adapter remains thin. The `zE` hydration exception needs the documented contract cleaned up.
- `ARCH-PURPOSE`: Mostly pass for semantic folds, but the boundary should not carry unrelated project-jump behavior unless the issue is revised to own it.

7. Plan revision recommendations

- Add a `## Revisions` entry clarifying that initial hydration is the one permitted document-wide manual-fold clear, while live transactions remain exchange-local.
- Either remove the `gP` fallback from this issue or add a revision that expands scope to include it, plus README/atlas traceability.
- Revise or complete the Plan checklist items that promise streaming multi-window/failure and teardown tests.
tokens used
110,849
```verdict
verdict: FIX-THEN-SHIP
confidence: medium
```

The semantic-fold work largely matches #195’s purpose: fold ranges now derive from `exchange_model`, live mutations are exchange-local, and atlas updates cover the new fold projection flow. I did find boundary issues to fix before shipping: unrelated `gP` project-jump behavior leaked into this issue without README coverage, and several Plan-promised tests are not present in the diff.

1. Strengths

- [fold_projection.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/fold_projection.lua:5) owns the foldable-kind policy in one pure module and projects only model-derived ranges.
- [tool_folds.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/tool_folds.lua:81) gives streaming/tool-loop callers a shared mutation transaction instead of keeping add-only fold creation paths.
- [exchange_model.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/exchange_model.lua:275) correctly moves parsed absolute spans into relative gap metadata, preserving historical zero/one/multi-line gaps.
- Atlas updates in `atlas/chat/exchange_model.md` and `atlas/chat/lifecycle.md` reflect the new exchange-gap and fold-projection model.

2. Critical findings

None.

3. Important findings

- [artifact_ref.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/artifact_ref.lua:82), [init.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/init.lua:4196), [keybinding_registry.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/keybinding_registry.lua:443): unrelated `gP` buffer-fallback behavior is shipped inside #195, but it is not in #195’s Spec/Plan and README was not updated. This is user-facing keybinding behavior. Fix by removing it from this boundary or revising the issue/plan scope and updating README discoverability.
- [tool_folds.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/tool_folds.lua:129): `hydrate_window` now uses `normal! zE`, while the issue Spec still says Parley never issues `zE` / document-wide fold clear. Later revisions imply this became intentional for initial hydration, but the Spec/Done contract was not reconciled. Fix the tracker text to carve out initial hydration explicitly, or narrow the implementation.
- [tool_folds_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/integration/tool_folds_spec.lua:124), [chat_respond_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/integration/chat_respond_spec.lua:2044): coverage does not fully deliver the checked Plan’s promised production cases: streaming multi-window locality/observer sequencing, empty-reduction finalization, injected streaming write failure, injected post-model-update failure, and stale scheduled hydration after buffer/window teardown are not visible in the diff. Add focused integration coverage or untick/revise those Plan claims.

4. Minor findings

- [exchange_model.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/exchange_model.lua:22): the file header still describes the old canonical layout convention, which now conflicts with stored actual gaps.

5. Test coverage notes

I did not run the suite because this boundary review was requested as read-only. I inspected the changed specs against the Plan. The pure projection and parsed-gap regressions are well covered; the missing coverage is specifically around production streaming failure/locality promises.

6. Architectural notes for upcoming work

- `ARCH-DRY`: Pass for semantic fold policy and coordinates; flag only the unrelated `gP` scope leak as outside #195’s source-of-truth story.
- `ARCH-PURE`: Pass for `fold_projection` and `exchange_model`; the Neovim adapter remains thin. The `zE` hydration exception needs the documented contract cleaned up.
- `ARCH-PURPOSE`: Mostly pass for semantic folds, but the boundary should not carry unrelated project-jump behavior unless the issue is revised to own it.

7. Plan revision recommendations

- Add a `## Revisions` entry clarifying that initial hydration is the one permitted document-wide manual-fold clear, while live transactions remain exchange-local.
- Either remove the `gP` fallback from this issue or add a revision that expands scope to include it, plus README/atlas traceability.
- Revise or complete the Plan checklist items that promise streaming multi-window/failure and teardown tests.
