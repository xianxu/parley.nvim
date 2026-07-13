# Boundary Review — 000183-keep-response-progress-at-current-generation-tip#183 (whole-issue close)

| field | value |
|-------|-------|
| issue | 183 — Keep response progress at current generation tip |
| repo | 000183-keep-response-progress-at-current-generation-tip |
| issue file | workshop/issues/000183-keep-response-progress-at-current-generation-tip.md |
| boundary | whole-issue close |
| milestone | — |
| window | e3ed1e032140143b1c92dbf1ffe3a9bf7e54c793..HEAD |
| command | sdlc close --issue 183 |
| reviewer | codex |
| timestamp | 2026-07-13T14:15:51-07:00 |
| verdict | REWORK |

## Review

Reading additional input from stdin...
OpenAI Codex v0.144.2
--------
workdir: /Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip
model: gpt-5.6-sol
provider: openai
approval: never
sandbox: workspace-write [workdir, /tmp, $TMPDIR]
reasoning effort: none
reasoning summaries: none
session id: 019f5d53-96fa-7111-ad10-994eafcc92e9
--------
user
# Code review — the one SDLC boundary review

You are conducting a fresh-context code review at a development boundary —
whole-issue close — in the **000183-keep-response-progress-at-current-generation-tip** repository.

- repository: 000183-keep-response-progress-at-current-generation-tip   (root: /Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip)
- issue:      000183-keep-response-progress-at-current-generation-tip#183   (file: workshop/issues/000183-keep-response-progress-at-current-generation-tip.md)
- window:     Base: e3ed1e032140143b1c92dbf1ffe3a9bf7e54c793   Head: HEAD

Review the **000183-keep-response-progress-at-current-generation-tip** repo and its tracker — the ariadne base-layer repo itself (changes here propagate to dependent repos). Do not assume any
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
index 10ef9aa..fac1787 100644
--- a/atlas/chat/exchange_model.md
+++ b/atlas/chat/exchange_model.md
@@ -54,6 +54,7 @@ Because the model is live state, `chat_respond` protects every pending async wri
 | `grow_question(k, delta)` | Question grew (e.g., raw_request_fence) |
 | `block_start(k, b)` | 0-indexed line where block content starts |
 | `block_end(k, b)` | 0-indexed last line of block |
+| `last_nonempty_block_end(k)` | Last visible block line, or `nil` when none is visible |
 | `append_pos(k)` | Where the next block would go |
 | `exchange_start(k)` | Where exchange k begins |
 | `exchange_total_size(k)` | Total lines in exchange k |
diff --git a/atlas/chat/lifecycle.md b/atlas/chat/lifecycle.md
index 35b91a4..a241cb8 100644
--- a/atlas/chat/lifecycle.md
+++ b/atlas/chat/lifecycle.md
@@ -13,7 +13,7 @@ Moves entire chat tree (root + descendants) to another chat root; rewrites all `
 Splits current exchange + following into a new child chat with `🌿:` links. Async LLM topic generation.
 
 ## Response (`:ParleyChatRespond` / `<C-g><C-g>`)
-Assembles context (with memory summarization), streams LLM response into buffer. The [exchange model](exchange_model.md) is the single source of truth for all transcript mutations during the response lifecycle — streaming text growth, tool block insertion, and prompt append all go through the model. [Response progress](response_progress.md) is cosmetic extmark state anchored to the response header and never becomes a model block. A per-buffer pending-session guard prevents duplicate calls.
+Assembles context (with memory summarization), streams LLM response into buffer. The [exchange model](exchange_model.md) is the single source of truth for all transcript mutations during the response lifecycle — streaming text growth, tool block insertion, and prompt append all go through the model. [Response progress](response_progress.md) is cosmetic extmark state that begins at the response header (or a recursive leg's last visible block), then follows the current generation tip; it never becomes a model block. A per-buffer pending-session guard prevents duplicate calls.
 
 Pending responses also hold a per-buffer chat lease (`lua/parley/chat_lease.lua`) anchored on an `invalidate=true` extmark on the response's `🤖:` agent-header line (#138). Each async callback validates the lease before mutating the transcript; ordinary edits and streaming move the anchor and stay valid, while deleting that line — undo/redo of the inserted response, or removing the header — invalidates the lease, stops/suppresses late stream/tool/progress/topic writes, and prevents recursive tool resubmit from using a stale live model. The pending extmark and its staged output are discarded on lost ownership. (Pre-#138 the lease keyed on buffer `changedtick`, which mis-read Parley's own writes as drift; the extmark anchor makes `commit` a no-op.)
 
diff --git a/atlas/chat/response_progress.md b/atlas/chat/response_progress.md
index c2d9038..643b6f8 100644
--- a/atlas/chat/response_progress.md
+++ b/atlas/chat/response_progress.md
@@ -14,8 +14,9 @@ One `chat_pending` session owns one dispatched chat leg:
    remote-tool status received in that window is delivered normally, so fast
    responses never show pending copy. Raw transport activity is not visible
    output and does not end the wait.
-2. A still-silent leg shows a virtual line below its `🤖:` response header,
-   initially in the form `⠙ brewing`. The glyph animates from
+2. A still-silent fresh leg shows a virtual line below its `🤖:` response
+   header; a recursive tool leg starts below the last existing answer/tool/result
+   block. The line initially takes the form `⠙ brewing`. The glyph animates from
    `progress.SPINNER`; SSE/JSONL activity and 15 seconds of transport idleness
    rotate the playful verb independently.
 3. Once shown, the line remains visible for at least one second. Visible output
@@ -23,10 +24,11 @@ One `chat_pending` session owns one dispatched chat leg:
    deadline Parley removes the playful line and releases all staged output once;
    subsequent output streams normally. With no visible output, the playful line
    remains rather than returning to silence.
-4. Meaningful provider progress uses the same extmark after release. Reasoning
-   details and remote-tool status therefore replace the playful copy without
-   becoming transcript text, while answer chunks continue through the ordinary
-   stream writer.
+4. Meaningful provider progress uses the same extmark after release. Each
+   ordinary stream write synchronously relocates that mark below its final
+   written line before the writer yields. Reasoning details and remote-tool
+   status therefore replace the playful copy without becoming transcript text
+   and remain at the current generation tip as answer chunks arrive.
 
 `chat_presentation` is the pure reducer for deadlines, staging, terminal
 decisions, and provider-detail accumulation. `chat_pending` is the Neovim IO
@@ -37,8 +39,15 @@ renders the reducer's actions, and owns all timers and the extmark.
 
 The pending/status line is an `invalidate=true` extmark with `virt_lines`; it
 never enters Markdown, the exchange model, undo history, saved files, parser
-input, or a future prompt. It is anchored to the durable response-header line
-owned by the exchange model. The independent chat lease decides whether that
+input, or a future prompt. Its presentation anchor moves with the generation
+tip: the response header before fresh content, the final visible block before a
+recursive leg, and the stream writer's tracked last line after every write. The
+writer reports that extmark-adjusted row after buffer/model growth, and
+`chat_pending` repairs a replacement-invalidated visible mark with the same ID
+and text in that same scheduled callback.
+
+The independent chat lease remains anchored to the durable response-header
+line and never follows the replaceable stream line. It decides whether that
 header still owns the in-flight response. Deleting or invalidating the header
 therefore cancels the session and suppresses late writes.
 
@@ -89,6 +98,7 @@ retain the detached luabar progress UI by default.
 - `lua/parley/chat_presentation.lua` — pure response-presentation reducer.
 - `lua/parley/chat_pending.lua` — main-loop timer/extmark adapter and registry.
 - `lua/parley/chat_respond.lua` — eligible initial/recursive leg integration.
+- `lua/parley/exchange_model.lua` — pure recursive initial-tip query.
 - `lua/parley/dispatcher.lua`, `lua/parley/tasker.lua`, `lua/parley/vault.lua` —
   activity, drained terminal, HTTP failure, and pre-start failure boundaries.
 - `lua/parley/selection_spinner.lua`, `lua/parley/skill_invoke.lua` — immediate
diff --git a/atlas/traceability.yaml b/atlas/traceability.yaml
index 47bc807..e7605c6 100644
--- a/atlas/traceability.yaml
+++ b/atlas/traceability.yaml
@@ -51,6 +51,7 @@ atlas:
       - lua/parley/chat_presentation.lua
       - lua/parley/chat_pending.lua
       - lua/parley/chat_respond.lua
+      - lua/parley/exchange_model.lua
       - lua/parley/chat_lease.lua
       - lua/parley/dispatcher.lua
       - lua/parley/tasker.lua
@@ -63,8 +64,10 @@ atlas:
       - tests/unit/vault_spec.lua
       - tests/integration/chat_pending_spec.lua
       - tests/integration/chat_respond_spec.lua
+      - tests/integration/create_handler_spec.lua
       - tests/integration/chat_progress_process_spec.lua
       - tests/integration/tasker_run_spec.lua
+      - tests/unit/exchange_model_spec.lua
       - tests/integration/topic_gen_spec.lua
       - tests/integration/cliproxy_caller_teardown_spec.lua
 
diff --git a/lua/parley/chat_pending.lua b/lua/parley/chat_pending.lua
index 52fdd27..9af33f3 100644
--- a/lua/parley/chat_pending.lua
+++ b/lua/parley/chat_pending.lua
@@ -139,6 +139,25 @@ M.start = function(opts)
         session.playful_verb = nil
     end
 
+    local function set_mark(text, row, col)
+        local ok, mark_id = pcall(vim.api.nvim_buf_set_extmark, session.buf, namespace,
+            row, col, {
+                id = session.extmark_id,
+                virt_lines = { { { text, "Comment" } } },
+                virt_lines_above = false,
+                invalidate = true,
+            })
+        if not ok then
+            return false
+        end
+        session.extmark_id = mark_id
+        session.extmark_hidden = false
+        session.last_mark_row = row
+        session.last_mark_col = col
+        session.visible_text = text
+        return true
+    end
+
     local function render(text)
         if not vim.api.nvim_buf_is_valid(session.buf) then
             return false
@@ -158,22 +177,7 @@ M.start = function(opts)
                 return false
             end
         end
-        local ok, mark_id = pcall(vim.api.nvim_buf_set_extmark, session.buf, namespace,
-            row, col, {
-                id = session.extmark_id,
-                virt_lines = { { { text, "Comment" } } },
-                virt_lines_above = false,
-                invalidate = true,
-            })
-        if not ok then
-            return false
-        end
-        session.extmark_id = mark_id
-        session.extmark_hidden = false
-        session.last_mark_row = row
-        session.last_mark_col = col
-        session.visible_text = text
-        return true
+        return set_mark(text, row, col)
     end
 
     local function render_playful()
@@ -382,6 +386,25 @@ M.start = function(opts)
         end)
     end
 
+    -- Called synchronously from dispatcher.create_handler's scheduled writer.
+    -- The pending stream line may have just invalidated this extmark; repaint it
+    -- before the writer yields so queued frame/progress work never sees a gap.
+    session.tip_written = function(_self, last_written_line_0)
+        if session.finished or type(last_written_line_0) ~= "number"
+                or not vim.api.nvim_buf_is_valid(session.buf) then
+            return
+        end
+        session.anchor_line = last_written_line_0
+        session.last_mark_row = last_written_line_0
+        session.last_mark_col = 0
+        if not session.visible_text then
+            return
+        end
+        if not set_mark(session.visible_text, last_written_line_0, 0) then
+            dispatch({ type = "invalid" })
+        end
+    end
+
     session.activity = function(_self, _qid)
         submit(function()
             return {
diff --git a/lua/parley/chat_respond.lua b/lua/parley/chat_respond.lua
index fff0ef0..496ab1f 100644
--- a/lua/parley/chat_respond.lua
+++ b/lua/parley/chat_respond.lua
@@ -1463,8 +1463,11 @@ M.respond = function(params, callback, override_free_cursor, force, live_model,
         -- lines (margin + content) into the buffer.
         --
         local stream_block_idx
+        local initial_progress_tip
         if is_recursion then
             -- Recursion: append streaming placeholder after existing blocks.
+            initial_progress_tip = assert(model:last_nonempty_block_end(target_idx),
+                "recursive response requires existing visible content")
             model:add_block(target_idx, "stream_placeholder", 1)
             stream_block_idx = #model.exchanges[target_idx].blocks
             local pos = model:block_start(target_idx, stream_block_idx)
@@ -1475,6 +1478,7 @@ M.respond = function(params, callback, override_free_cursor, force, live_model,
             model:add_block(target_idx, "agent_header", 1)
             model:add_block(target_idx, "stream_placeholder", 1)
             stream_block_idx = #model.exchanges[target_idx].blocks
+            initial_progress_tip = model:block_start(target_idx, 2)
 
             -- Before inserting, clean up any trailing blank lines after
             -- the question in the buffer. The model's margin will be the
@@ -1603,7 +1607,8 @@ M.respond = function(params, callback, override_free_cursor, force, live_model,
             before_write = function(_qid, _chunk)
                 return lease_valid()
             end,
-            after_write = function()
+            after_write = function(_qid, _chunk, _delta, last_written_line_0)
+                pending_session:tip_written(last_written_line_0)
                 lease_commit()
             end,
         })
@@ -1660,7 +1665,7 @@ M.respond = function(params, callback, override_free_cursor, force, live_model,
 
         pending_session = chat_pending.start({
             buf = buf,
-            anchor_line = model:block_start(target_idx, 2),
+            anchor_line = initial_progress_tip,
             lease_valid = lease_valid,
             emit_content = base_handler,
             choose_verb_index = function(count) return math.random(count) end,
diff --git a/lua/parley/dispatcher.lua b/lua/parley/dispatcher.lua
index caa8c07..63d506b 100644
--- a/lua/parley/dispatcher.lua
+++ b/lua/parley/dispatcher.lua
@@ -575,8 +575,11 @@ D.create_handler = function(buf, win, line, first_undojoin, prefix, cursor, on_l
 		if on_lines_changed and delta > 0 then
 			on_lines_changed(delta)
 		end
+		local end_line = first_line + finished_lines + 1
+		qt.first_line = first_line
+		qt.last_line = end_line - 1
 		if opts.after_write then
-			opts.after_write(qid, chunk, delta)
+			opts.after_write(qid, chunk, delta, end_line - 1)
 		end
 		pending_line = new_pending
 		helpers.undojoin(buf)
@@ -585,10 +588,6 @@ D.create_handler = function(buf, win, line, first_undojoin, prefix, cursor, on_l
 			vim.api.nvim_buf_add_highlight(buf, qt.ns_id, hl_handler_group, first_line + i, 0, -1)
 		end
 
-		local end_line = first_line + finished_lines + 1
-		qt.first_line = first_line
-		qt.last_line = end_line - 1
-
 		-- move cursor to the end of the response
 		local should_move_cursor
 		if type(cursor) == "function" then
diff --git a/lua/parley/exchange_model.lua b/lua/parley/exchange_model.lua
index c7b8d81..620fd89 100644
--- a/lua/parley/exchange_model.lua
+++ b/lua/parley/exchange_model.lua
@@ -41,6 +41,15 @@ Model.__index = Model
 
 local M = {}
 
+local function last_nonempty_block_index(exchange)
+    for i = #exchange.blocks, 1, -1 do
+        if exchange.blocks[i].size > 0 then
+            return i
+        end
+    end
+    return nil
+end
+
 --- Create a new empty model.
 --- @param header_lines integer  number of header lines (e.g. 4 for ---/topic/file/---)
 --- @return Model
@@ -163,18 +172,24 @@ function Model:block_end(k, b)
     return self:block_start(k, b) + self.exchanges[k].blocks[b].size - 1
 end
 
+--- 0-indexed last line of the final visible block, or nil if none is visible.
+function Model:last_nonempty_block_end(k)
+    local block_index = last_nonempty_block_index(self.exchanges[k])
+    if not block_index then
+        return nil
+    end
+    return self:block_end(k, block_index)
+end
+
 --- 0-indexed buffer line where the NEXT block would be inserted
 --- (after all existing blocks + margin).
 function Model:append_pos(k)
-    local n = #self.exchanges[k].blocks
-    if n == 0 then
+    if #self.exchanges[k].blocks == 0 then
         return self:exchange_start(k)
     end
-    -- Find the last non-empty block
-    for i = n, 1, -1 do
-        if self.exchanges[k].blocks[i].size > 0 then
-            return self:block_end(k, i) + 1 + MARGIN
-        end
+    local last_end = self:last_nonempty_block_end(k)
+    if last_end then
+        return last_end + 1 + MARGIN
     end
     -- All blocks are empty — append at exchange start + margin
     return self:exchange_start(k) + MARGIN
diff --git a/tests/integration/chat_pending_spec.lua b/tests/integration/chat_pending_spec.lua
index 0fadd23..e610eed 100644
--- a/tests/integration/chat_pending_spec.lua
+++ b/tests/integration/chat_pending_spec.lua
@@ -256,6 +256,66 @@ describe("chat pending extmark adapter", function()
         assert.matches("^⠹ brewing$", virtual_text(buf))
     end)
 
+    it("uses a hidden tip update for the first reveal", function()
+        local buf = new_scratch()
+        local runtime = new_runtime()
+        local session = start_fake(buf, runtime)
+        vim.api.nvim_buf_set_lines(buf, 1, 1, false, { "generated tip" })
+
+        session:tip_written(1)
+        runtime:advance(1000)
+        runtime:drain()
+
+        assert.equals(1, extmark(buf)[2])
+        assert.equals("⠙ brewing", virtual_text(buf))
+    end)
+
+    it("repairs invalidating writes synchronously without changing lifecycle state", function()
+        local buf = new_scratch()
+        local runtime = new_runtime()
+        local session, emitted = start_fake(buf, runtime)
+        runtime:advance(1000)
+        runtime:drain()
+        session:content("q", "one")
+        session:content("q", "two")
+        runtime:drain()
+
+        local text, mark = virtual_text(buf)
+        local mark_id = mark[1]
+        local state = session.state
+        local minimum_timer = session.timers.minimum
+        local frame_timer = session.timers.frame
+        runtime:advance(120)
+        vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "answer", "pending" })
+        session:tip_written(1)
+
+        local repaired_text, repaired_mark = virtual_text(buf)
+        assert.equals(mark_id, repaired_mark[1])
+        assert.equals(text, repaired_text)
+        assert.equals(1, repaired_mark[2])
+        assert.equals(state, session.state)
+        assert.equals(minimum_timer, session.timers.minimum)
+        assert.equals(frame_timer, session.timers.frame)
+
+        runtime:drain()
+        assert.is_true(chat_pending.is_active(buf), "queued frame must see the repaired mark")
+        assert.equals(mark_id, extmark(buf)[1])
+        assert.equals(1, extmark(buf)[2])
+
+        local completions = 0
+        session:complete("q", function() completions = completions + 1 end)
+        runtime:drain()
+        runtime:advance(880)
+        runtime:drain()
+        assert.same({ { "q", "one" }, { "q", "two" } }, emitted)
+        assert.equals(1, completions)
+        assert.is_false(chat_pending.is_active(buf))
+
+        session:tip_written(0)
+        assert.is_nil(extmark(buf))
+        assert.equals(1, completions)
+    end)
+
     it("stages content until the minimum and flushes it in FIFO order", function()
         local buf = new_scratch()
         local runtime = new_runtime()
diff --git a/tests/integration/chat_respond_spec.lua b/tests/integration/chat_respond_spec.lua
index b8f2c4c..23d3a3e 100644
--- a/tests/integration/chat_respond_spec.lua
+++ b/tests/integration/chat_respond_spec.lua
@@ -56,6 +56,12 @@ local function pending_virtual_text(buf)
     return chunks and chunks[1] and chunks[1][1] and chunks[1][1][1] or nil
 end
 
+local function pending_mark(buf)
+    local ns = vim.api.nvim_get_namespaces().parley_chat_pending
+    if not ns then return nil end
+    return vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })[1]
+end
+
 local function pending_runtime()
     local runtime = { now = 0, queue = {}, timers = {} }
     runtime.clock = { now_ms = function() return runtime.now end }
@@ -778,6 +784,12 @@ describe("chat_respond: buffer state after completion", function()
         assert.is_true(vim.wait(1050, function()
             return ns and #vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true }) == 1
         end, 10))
+        local lines_before_content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
+        local agent_row
+        for index, line in ipairs(lines_before_content) do
+            if line:match("^🤖:") then agent_row = index - 1 end
+        end
+        assert.equals(agent_row, pending_mark(buf)[2], "fresh progress must begin below the agent header")
         assert.is_true(vim.wait(300, function() return completion_called end, 10))
         assert.is_false(buffer_contains(buf, "Release notes summary"),
             "content received during minimum must stay staged")
@@ -884,6 +896,8 @@ describe("chat_respond: buffer state after completion", function()
         local buf = vim.api.nvim_get_current_buf()
         vim.api.nvim_win_set_cursor(0, { 6, 0 })
         local finish
+        local write
+        local qid = "qid_remote_status"
         local runtime = pending_runtime()
         require("parley.chat_pending").start = function(opts)
             opts.clock, opts.scheduler = runtime.clock, runtime.scheduler
@@ -891,8 +905,8 @@ describe("chat_respond: buffer state after completion", function()
         end
 
         parley.dispatcher.query = function(buf_arg, _provider, _payload, handler, completion_callback,
-                _callback, progress_callback)
-            local qid = "qid_remote_status"
+            _callback, progress_callback)
+            write = handler
             parley.tasker.set_query(qid, { response = "answer", raw_response = "", buf = buf_arg })
             handler(qid, "answer")
             progress_callback(qid, { message = "Searching web...", text = "release notes" })
@@ -905,6 +919,27 @@ describe("chat_respond: buffer state after completion", function()
             return buffer_contains(buf, "answer")
                 and pending_virtual_text(buf) == "Searching web... release notes"
         end, 10), vim.inspect({ text = pending_virtual_text(buf), lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false) }))
+        local first_mark = pending_mark(buf)
+        local first_mark_id = first_mark[1]
+        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
+        local answer_row
+        for index, line in ipairs(lines) do
+            if line == "answer" then answer_row = index - 1 end
+        end
+        assert.equals(answer_row, first_mark[2])
+
+        vim.api.nvim_buf_set_lines(buf, 0, 0, false, { "inserted above response" })
+        write(qid, "\nsecond\nthird")
+        runtime:drain()
+        assert.is_true(vim.wait(500, function()
+            return buffer_contains(buf, "third") and pending_mark(buf)
+                and pending_mark(buf)[2] > answer_row
+        end, 10))
+        local moved_mark = pending_mark(buf)
+        local moved_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
+        assert.equals(first_mark_id, moved_mark[1])
+        assert.equals("Searching web... release notes", pending_virtual_text(buf))
+        assert.equals("third", moved_lines[moved_mark[2] + 1])
         finish()
         runtime:drain()
         assert.is_true(vim.wait(300, function() return pending_virtual_text(buf) == nil end, 10))
@@ -1248,6 +1283,13 @@ describe("chat_respond: pending request transcript drift", function()
         assert.is_true(vim.wait(1300, function()
             return starts == 2 and (pending_virtual_text(buf) or ""):match(" cooking$") ~= nil
         end, 10))
+        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
+        local last_nonempty_row
+        for index, line in ipairs(lines) do
+            if line:match("%S") then last_nonempty_row = index - 1 end
+        end
+        assert.equals(last_nonempty_row, pending_mark(buf)[2],
+            "recursive progress must begin below the last existing tool/result content")
         pending.start = original_start
     end)
 
diff --git a/tests/integration/create_handler_spec.lua b/tests/integration/create_handler_spec.lua
index 4d8654d..0f9e07d 100644
--- a/tests/integration/create_handler_spec.lua
+++ b/tests/integration/create_handler_spec.lua
@@ -262,4 +262,48 @@ describe("create_handler: streaming behavior", function()
         local cursor = vim.api.nvim_win_get_cursor(win)
         assert.equals(1, cursor[1])
     end)
+
+    it("reports the tracked last written row after growth and edits above", function()
+        local callbacks = {}
+        local growth_seen = false
+        local handler = parley.dispatcher.create_handler(buf, nil, 3, true, "", false, function(delta)
+            growth_seen = delta == 1
+        end, {
+            after_write = function(qid, chunk, delta, last_written_line_0)
+                table.insert(callbacks, {
+                    qid = qid,
+                    chunk = chunk,
+                    delta = delta,
+                    row = last_written_line_0,
+                    growth_seen = growth_seen,
+                    line = vim.api.nvim_buf_get_lines(buf, last_written_line_0,
+                        last_written_line_0 + 1, false)[1],
+                })
+            end,
+        })
+
+        handler(mock_qid, "A\nB")
+        assert.is_true(vim.wait(100, function() return #callbacks == 1 end, 10))
+        assert.same({
+            qid = mock_qid,
+            chunk = "A\nB",
+            delta = 1,
+            row = 4,
+            growth_seen = true,
+            line = "B",
+        }, callbacks[1])
+
+        vim.api.nvim_buf_set_lines(buf, 0, 0, false, { "inserted above" })
+        growth_seen = false
+        handler(mock_qid, "\nC")
+        assert.is_true(vim.wait(100, function() return #callbacks == 2 end, 10))
+        assert.same({
+            qid = mock_qid,
+            chunk = "\nC",
+            delta = 1,
+            row = 6,
+            growth_seen = true,
+            line = "C",
+        }, callbacks[2])
+    end)
 end)
diff --git a/tests/unit/exchange_model_spec.lua b/tests/unit/exchange_model_spec.lua
index 1c6e475..d69b15d 100644
--- a/tests/unit/exchange_model_spec.lua
+++ b/tests/unit/exchange_model_spec.lua
@@ -29,6 +29,32 @@ describe("exchange_model: single exchange, question only", function()
 end)
 
 describe("exchange_model: single exchange with blocks", function()
+    it("reports the last non-empty block end through trailing empty blocks", function()
+        local m = em.new(4)
+        m:add_exchange(1)
+        m:add_block(1, "agent_header", 1)
+        m:add_block(1, "text", 3)
+        m:add_block(1, "stream_placeholder", 0)
+
+        assert.equals(11, m:last_nonempty_block_end(1))
+    end)
+
+    it("reports the only non-empty block end", function()
+        local m = em.new(4)
+        m:add_exchange(1)
+        m:add_block(1, "stream_placeholder", 0)
+
+        assert.equals(5, m:last_nonempty_block_end(1))
+    end)
+
+    it("returns nil when an exchange has no non-empty blocks", function()
+        local m = em.new(4)
+        m:add_exchange(0)
+        m:add_block(1, "stream_placeholder", 0)
+
+        assert.is_nil(m:last_nonempty_block_end(1))
+    end)
+
     it("agent_header block starts after question + margin", function()
         local m = em.new(4)
         m:add_exchange(1)


codex
I’ll verify the repository guidance, issue Spec/Plan, and the full base-to-HEAD diff, then run the relevant tests and inspect the affected async/extmark paths for edge cases. I’ll keep the review read-only.
exec
/bin/zsh -lc "pwd && rg --files -g 'AGENTS.md' -g 'workshop/issues/000183-keep-response-progress-at-current-generation-tip.md' -g 'lua/parley/*.lua' -g 'tests/**/*_spec.lua' | sed -n '1,160p'" in /Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip
 succeeded in 0ms:
/Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip
lua/parley/issue_vocabulary.lua
lua/parley/copy.lua
lua/parley/define.lua
lua/parley/chat_slug.lua
lua/parley/memory_prefs.lua
lua/parley/agent_picker.lua
lua/parley/provider_params.lua
lua/parley/tool_loop.lua
lua/parley/issue_finder.lua
lua/parley/skill_picker.lua
lua/parley/providers.lua
lua/parley/test_agent_picker.lua
lua/parley/render.lua
lua/parley/defaults.lua
lua/parley/highlighter.lua
lua/parley/spinner.lua
lua/parley/line_reader.lua
lua/parley/raw_log.lua
lua/parley/review.lua
lua/parley/vision.lua
lua/parley/markdown_finder.lua
lua/parley/issues.lua
lua/parley/dispatcher.lua
lua/parley/cliproxy.lua
lua/parley/skill_edits.lua
lua/parley/health.lua
lua/parley/chat_parser.lua
lua/parley/obfuscate.lua
lua/parley/spell.lua
lua/parley/tasker.lua
lua/parley/system_prompt_msgs.lua
lua/parley/chat_pending.lua
lua/parley/skill_registry.lua
lua/parley/timezone_diagnostics.lua
lua/parley/buffer_lifecycle.lua
lua/parley/review_menu.lua
lua/parley/artifact_ref.lua
lua/parley/diagnostic_refresh.lua
lua/parley/config.lua
lua/parley/notes.lua
lua/parley/chat_lease.lua
lua/parley/buffer_edit.lua
lua/parley/logger.lua
lua/parley/google_drive.lua
lua/parley/neighborhood.lua
lua/parley/skill_invoke.lua
lua/parley/lualine.lua
lua/parley/vault.lua
lua/parley/note_finder.lua
lua/parley/skill_manifest.lua
lua/parley/super_repo.lua
lua/parley/file_tracker.lua
lua/parley/keybinding_registry.lua
lua/parley/highlight_structure.lua
lua/parley/init.lua
lua/parley/root_dirs.lua
lua/parley/root_dir_picker.lua
lua/parley/chat_finder.lua
lua/parley/progress.lua
lua/parley/vision_finder.lua
lua/parley/render_buffer.lua
lua/parley/skill_assembly.lua
lua/parley/system_prompt_picker.lua
lua/parley/agent_info.lua
lua/parley/exchange_clipboard.lua
lua/parley/skill_render.lua
lua/parley/selection_spinner.lua
lua/parley/tool_folds.lua
lua/parley/exporter.lua
lua/parley/interview.lua
lua/parley/exchange_model.lua
lua/parley/helper.lua
lua/parley/outline.lua
lua/parley/finder_sticky.lua
lua/parley/repo_artifacts.lua
lua/parley/chat_respond.lua
lua/parley/chat_presentation.lua
lua/parley/note_dir_picker.lua
lua/parley/custom_prompts.lua
lua/parley/log_emit.lua
lua/parley/oauth.lua
lua/parley/drill_in.lua
lua/parley/float_picker.lua
lua/parley/skill_providers.lua
lua/parley/chat_dirs.lua
lua/parley/note_dirs.lua
lua/parley/cliproxy_config.lua
tests/integration/diagnostic_refresh_spec.lua
tests/integration/review_journal_io_spec.lua
tests/integration/tree_export_spec.lua
tests/integration/tasker_run_spec.lua
tests/integration/chat_move_spec.lua
tests/integration/review_mode_load_spec.lua
tests/integration/chat_lease_spec.lua
tests/integration/review_diag_display_spec.lua
tests/integration/neighborhood_completion_spec.lua
tests/integration/export_spec.lua
tests/integration/voice_apply_spec.lua
tests/integration/cliproxy_auth_login_spec.lua
tests/integration/cliproxy_command_spec.lua
tests/integration/highlighting_spec.lua
tests/integration/chat_respond_spec.lua
tests/integration/chat_pending_spec.lua
tests/integration/perf_chat_typing_spec.lua
tests/integration/discovery_local_types_spec.lua
tests/integration/skill_invoke_review_spec.lua
tests/integration/topic_gen_spec.lua
tests/integration/skill_registry_spec.lua
tests/integration/skill_invoke_spec.lua
tests/integration/timer_race_spec.lua
tests/integration/cliproxy_dispatch_spec.lua
tests/integration/not_chat_spec.lua
tests/integration/cliproxy_caller_teardown_spec.lua
tests/integration/define_spec.lua
tests/integration/review_menu_spec.lua
tests/integration/discovery_builder_spec.lua
tests/integration/progress_spec.lua
tests/integration/chat_progress_process_spec.lua
tests/integration/review_projection_spec.lua
tests/integration/cliproxy_download_spec.lua
tests/integration/create_handler_spec.lua
tests/integration/cliproxy_lifecycle_spec.lua
tests/integration/skill_providers_spec.lua
tests/integration/new_chat_spec.lua
tests/integration/spell_chat_spec.lua
tests/arch/buffer_mutation_spec.lua
tests/arch/performance_line_reader_spec.lua
workshop/issues/000183-keep-response-progress-at-current-generation-tip.md
tests/unit/tools_types_spec.lua
tests/unit/highlight_structure_spec.lua
tests/unit/diagnostic_refresh_spec.lua
tests/unit/highlighter_spec.lua
tests/unit/parley_harness_golden_spec.lua
tests/unit/skill_edits_spec.lua
tests/unit/spell_spec.lua
tests/unit/chat_presentation_spec.lua
tests/unit/get_week_number_spec.lua
tests/unit/tools_builtin_propose_edits_spec.lua
tests/unit/issue_vocabulary_spec.lua
tests/unit/oauth_spec.lua
tests/unit/anthropic_tool_encode_spec.lua
tests/unit/helper_io_spec.lua
tests/unit/arch_helper_spec.lua
tests/unit/line_reader_spec.lua
tests/unit/discovery_matcher_spec.lua
tests/unit/review_mode_spec.lua
tests/unit/issue_finder_spec.lua
tests/unit/tools_registry_spec.lua
tests/unit/chat_slug_resolve_spec.lua
tests/unit/artifact_ref_spec.lua
tests/unit/dispatcher_query_spec.lua
tests/unit/outline_spec.lua
tests/unit/parse_at_reference_spec.lua
tests/unit/chat_parser_section_lines_spec.lua
tests/unit/timezone_diagnostics_spec.lua
tests/unit/process_directory_pattern_spec.lua
tests/unit/float_picker_spec.lua
tests/unit/chat_slug_spec.lua
tests/unit/buffer_lifecycle_spec.lua
tests/unit/tools_builtin_registered_spec.lua

exec
/bin/zsh -lc 'find .. -name AGENTS.md -print && git status --short && git diff --stat e3ed1e032140143b1c92dbf1ffe3a9bf7e54c793..HEAD && git log --oneline --decorate e3ed1e032140143b1c92dbf1ffe3a9bf7e54c793..HEAD' in /Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip
 succeeded in 0ms:
 atlas/chat/exchange_model.md                       |  1 +
 atlas/chat/lifecycle.md                            |  2 +-
 atlas/chat/response_progress.md                    | 26 +++++++---
 atlas/traceability.yaml                            |  3 ++
 lua/parley/chat_pending.lua                        | 55 ++++++++++++++------
 lua/parley/chat_respond.lua                        |  9 +++-
 lua/parley/dispatcher.lua                          |  9 ++--
 lua/parley/exchange_model.lua                      | 29 ++++++++---
 tests/integration/chat_pending_spec.lua            | 60 ++++++++++++++++++++++
 tests/integration/chat_respond_spec.lua            | 46 ++++++++++++++++-
 tests/integration/create_handler_spec.lua          | 44 ++++++++++++++++
 tests/unit/exchange_model_spec.lua                 | 26 ++++++++++
 ...-response-progress-at-current-generation-tip.md | 37 +++++++++++--
 13 files changed, 302 insertions(+), 45 deletions(-)
8c186d9 (HEAD -> 000183-keep-response-progress-at-current-generation-tip) #183: record generation-tip verification
81366a7 #183: follow response progress at generation tip

exec
/bin/zsh -lc "sed -n '1,280p' workshop/issues/000183-keep-response-progress-at-current-generation-tip.md && git diff --check e3ed1e032140143b1c92dbf1ffe3a9bf7e54c793..HEAD && git diff --unified=80 e3ed1e032140143b1c92dbf1ffe3a9bf7e54c793..HEAD -- lua/parley/chat_pending.lua lua/parley/chat_respond.lua lua/parley/dispatcher.lua lua/parley/exchange_model.lua" in /Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip
 succeeded in 0ms:
---
id: 000183
status: working
deps: []
github_issue:
created: 2026-07-13
updated: 2026-07-13
estimate_hours: 2.02
started: 2026-07-13T13:44:15-07:00
---

# Keep response progress at current generation tip

## Problem

The response-progress extmark introduced by #182 is anchored to the agent-header
line for an entire LLM leg. That is correct only before a fresh answer emits any
content. During streaming it leaves reasoning or remote-tool status behind at
`🤖:`, and during a recursive tool loop it starts below `🤖:` instead of after
the already-generated answer and tool/result blocks. The indicator therefore
describes current work at a stale spatial location.

## Spec

- Treat the generation tip as a per-leg, moving presentation anchor. Before the
  first visible content of a fresh answer, use the agent-header row, so delayed
  playful progress still appears immediately below `🤖:`. Before adding a
  recursive leg's new `stream_placeholder`, snapshot the end row of the model's
  last non-empty block and use that row as the initial anchor; recursive playful
  progress therefore starts after the answer/tool/result content already
  generated by that response, never at the new blank placeholder.
- Once a stream write lands, move any visible progress extmark below the last
  line written by the streaming handler. Continue doing so after every stream
  write. Semantic reasoning or remote-tool status therefore follows the current
  generated text instead of remaining below the agent header.
- Preserve #182's temporal policy unchanged: one-second silent reveal,
  one-second minimum visibility, ordered staging, activity/idle verb rotation,
  terminal handling, and Definition's separate immediate inline spinner.
- Keep the response-header chat lease unchanged. The lease owns transcript
  validity and must never move to the replaceable pending stream line. The
  presentation mark may occupy that current line, but only under the atomic
  relocation contract below because each chunk replaces and invalidates it.
- Extend the streaming handler's existing seam to call
  `after_write(qid, chunk, delta, last_written_line_0)` with
  `last_written_line_0 = first_line + finished_lines`, computed after the buffer
  mutation and `on_lines_changed` growth callback. This is the handler's own
  extmark-adjusted position after edits above the response, so consumers do not
  recompute from stale exchange-model coordinates (`ARCH-DRY`, `ARCH-PURPOSE`).
- `chat_respond` must complete the tip relocation inside that same scheduled
  stream-write callback before it yields; it must not add another scheduling
  hop. If replacing the pending line invalidated visible progress, restore the
  same extmark ID at `last_written_line_0` with identical text before any queued
  progress/frame callback can inspect it. Unexpected invalidation outside this
  acknowledged write retains #182's terminal behavior.
- A tip update changes the adapter's current anchor and every cached/fallback
  spatial row even when progress is hidden, so the next reveal uses the new tip.
  When playful or semantic progress is visible, repaint the existing extmark at
  the new tip without changing its ID, text, timer state, reducer phase, or
  transcript content. Ignore late tip updates after the session finishes.
- Keep all tip movement in the Neovim adapter/stream IO shell; the pure temporal
  reducer has no spatial state and requires no change (`ARCH-PURE`).

## Done when

- Fresh delayed progress begins directly below `🤖:` before content exists.
- Recursive delayed progress begins after the response's last existing visible
  answer/tool/result block rather than below `🤖:`.
- A visible reasoning or remote-tool status moves below each newly written
  content tip and keeps the same presentation text and lifecycle state.
- Edits above the response remain safe because the writer reports its tracked
  position; cancellation, invalidation, staging, and Definition behavior remain
  unchanged.
- Real-buffer tests prove a hidden tip update controls the next reveal; visible
  relocation preserves exact extmark ID/text; replacement plus synchronous
  relocation cannot be overtaken by queued frame/progress work; insertion above
  the response still yields the writer's tracked row; and relocation after
  finish is a no-op.
- Tip relocation leaves timers, minimum deadline, reducer phase, staging FIFO,
  and exact-once terminal delivery unchanged.
- Focused adapter/real-entry regressions, mapped chat tests, lint, and the full
  repository suite pass.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec             design=0.75 impl=0.08
item: lua-neovim             design=0.30 impl=0.40
item: atlas-docs             design=0.05 impl=0.04
item: milestone-review       design=0.10 impl=0.12
design-buffer: 0.15
total: 2.02
```

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md`
against `baseline-v3.1.md`. Method A only. The thoroughly reviewed behavioral
spec discounts the remaining Lua design work; implementation values are the
v3.1 AI-paired 40% values.

## Plan

- [x] Approve the durable implementation plan and calibrated estimate.
- [x] Add failing adapter and real-entry regressions for fresh, recursive, and
  streaming tip movement.
- [x] Report the tracked last line from the stream writer and move visible
  progress through the serialized chat adapter.
- [x] Update the response-progress atlas and pass targeted/full verification.
- [x] Close, publish, and merge through the SDLC gates.

## Log

### 2026-07-13

Claimed the follow-up after confirming #182's adapter always receives the fixed
agent-header row. The selected design keeps the structural chat lease on that
durable header while deriving presentation movement from the streaming
handler's own tracked line. A model-only resolver was rejected because ordinary
buffer edits can move the handler extmark without updating model coordinates;
anchoring directly to the stream placeholder was rejected because chunk writes
replace and invalidate that line.

### 2026-07-13 — spec review revision

Fresh review found that a queued tip update could lose a race with the next
frame/progress callback after `stream_replace_at_line` invalidated a mark on the
mutable pending line. The spec now requires synchronous same-callback repair
with the same extmark ID, defines the handler's exact tracked-row argument,
pins recursive initial placement before the new placeholder exists, and makes
hidden spatial fallback plus lifecycle-preservation tests explicit.

### 2026-07-13 — plan review revision

Fresh plan review required stronger proof at two boundaries: recursive initial
placement now uses the canonical adapter and asserts the real virtual line, and
the relocation suite now carries ordered staged output through invalidation and
termination to prove FIFO plus exact-once behavior rather than relying on the
unchanged #182 tests alone.

The revised durable plan received a fresh-context `APPROVED` verdict with both
Important findings resolved.

The SDLC plan-quality gate then found an `ARCH-DRY`/`ARCH-PURE` issue in the
planned recursive lookup: `chat_respond` would have repeated exchange-model
layout traversal. The plan now adds a semantic, pure model query with unit tests
and makes the response IO shell consume it.

### 2026-07-13 — implementation and verification

TDD RED established the absent contracts: `last_nonempty_block_end` was missing,
`chat_pending` had no synchronous `tip_written` operation, and the stream
handler did not report its tracked final row. GREEN added the pure model query,
same-ID extmark repair inside the scheduled writer callback, fresh/recursive
initial anchors, and writer-owned row reporting after buffer/model growth.

Real-buffer regressions now cover hidden first reveal at the moved tip, visible
replacement repair with stable ID/text/timers/reducer state, queued-frame
ordering, staged FIFO plus exact-once completion, edits above a multi-line
stream, and recursive placement after tool/result content. `ARCH-DRY` keeps the
last-visible-block traversal in `exchange_model`; `ARCH-PURE` leaves the temporal
reducer unchanged and confines extmark mutation to the Neovim adapter.

Verification passed:

- `make -f Makefile.local test-spec SPEC=chat/response_progress`
- `make -f Makefile.local test-spec SPEC=chat/exchange_model`
- `make -f Makefile.local test JOBS=1` — lint clean; all unit, architecture,
  and integration specs passed
- `git diff --check`

The first parallel full-suite run exposed a pre-existing cross-test filesystem
race in `tools_builtin_find_spec.lua`: its `find .` can traverse a transient
directory while another unit process deletes it. The test passed alone, the
affected files have no #183 diff, and the serialized full run passed without
altering that unrelated surface.
diff --git a/lua/parley/chat_pending.lua b/lua/parley/chat_pending.lua
index 52fdd27..9af33f3 100644
--- a/lua/parley/chat_pending.lua
+++ b/lua/parley/chat_pending.lua
@@ -62,195 +62,199 @@ local function call_safely(label, callback, ...)
     end)
     if not ok then
         logger.error("chat pending " .. label .. " callback failed")
     end
 end
 
 -- Start one serialized presentation session for a response header.
 M.start = function(opts)
     opts = opts or {}
     local buf = assert(opts.buf, "buf is required")
     local existing = active_by_buf[buf]
     assert(not existing or existing.finished, "chat pending session already active for buffer")
 
     local scheduler = opts.scheduler or production_scheduler
     local clock = opts.clock or { now_ms = monotonic_now_ms }
     assert(type(scheduler.enqueue) == "function", "scheduler.enqueue is required")
     assert(type(scheduler.after) == "function", "scheduler.after is required")
     assert(type(scheduler.every) == "function", "scheduler.every is required")
     assert(type(clock.now_ms) == "function", "clock.now_ms is required")
 
     local session = {
         buf = buf,
         anchor_line = assert(opts.anchor_line, "anchor_line is required"),
         lease_valid = assert(opts.lease_valid, "lease_valid is required"),
         emit_content = assert(opts.emit_content, "emit_content is required"),
         choose_verb_index = assert(opts.choose_verb_index, "choose_verb_index is required"),
         on_discard = opts.on_discard,
         scheduler = scheduler,
         clock = clock,
         timers = {},
         frame_index = 2, -- The approved first visible frame is ⠙.
         detail_state = {},
         finished = false,
     }
     local function now_ms()
         return session.clock.now_ms()
     end
 
     local initial_index = session.choose_verb_index(#verbs)
     session.state = presentation.initial({
         now_ms = now_ms(),
         verbs = verbs,
         verb_index = initial_index,
     })
     assert(session.on_discard == nil or type(session.on_discard) == "function",
         "on_discard must be a function")
 
     local function cancel_timer(name)
         local cancel = session.timers[name]
         session.timers[name] = nil
         call_safely("timer cancellation", cancel)
     end
 
     local function cancel_timers()
         local names = {}
         for name in pairs(session.timers) do
             table.insert(names, name)
         end
         for _, name in ipairs(names) do
             cancel_timer(name)
         end
     end
 
     local function hide()
         if session.extmark_id then
             if vim.api.nvim_buf_is_valid(session.buf) then
                 local position = vim.api.nvim_buf_get_extmark_by_id(
                     session.buf, namespace, session.extmark_id, { details = true })
                 if #position >= 2 and not (position[3] and position[3].invalid) then
                     session.last_mark_row = position[1]
                     session.last_mark_col = position[2]
                 end
             end
             pcall(vim.api.nvim_buf_del_extmark, session.buf, namespace, session.extmark_id)
             session.extmark_hidden = true
         end
         session.visible_text = nil
         session.playful_verb = nil
     end
 
+    local function set_mark(text, row, col)
+        local ok, mark_id = pcall(vim.api.nvim_buf_set_extmark, session.buf, namespace,
+            row, col, {
+                id = session.extmark_id,
+                virt_lines = { { { text, "Comment" } } },
+                virt_lines_above = false,
+                invalidate = true,
+            })
+        if not ok then
+            return false
+        end
+        session.extmark_id = mark_id
+        session.extmark_hidden = false
+        session.last_mark_row = row
+        session.last_mark_col = col
+        session.visible_text = text
+        return true
+    end
+
     local function render(text)
         if not vim.api.nvim_buf_is_valid(session.buf) then
             return false
         end
         local row = session.anchor_line
         local col = 0
         if session.extmark_id then
             local position = vim.api.nvim_buf_get_extmark_by_id(
                 session.buf, namespace, session.extmark_id, { details = true })
             if #position >= 2 and not (position[3] and position[3].invalid) then
                 row = position[1]
                 col = position[2]
             elseif session.extmark_hidden and session.last_mark_row then
                 row = session.last_mark_row
                 col = session.last_mark_col
             else
                 return false
             end
         end
-        local ok, mark_id = pcall(vim.api.nvim_buf_set_extmark, session.buf, namespace,
-            row, col, {
-                id = session.extmark_id,
-                virt_lines = { { { text, "Comment" } } },
-                virt_lines_above = false,
-                invalidate = true,
-            })
-        if not ok then
-            return false
-        end
-        session.extmark_id = mark_id
-        session.extmark_hidden = false
-        session.last_mark_row = row
-        session.last_mark_col = col
-        session.visible_text = text
-        return true
+        return set_mark(text, row, col)
     end
 
     local function render_playful()
         return render(spinner[session.frame_index] .. " " .. session.playful_verb)
     end
 
     local function finish()
         if session.finished then
             return
         end
         session.finished = true
         cancel_timers()
         hide()
         if active_by_buf[session.buf] == session then
             active_by_buf[session.buf] = nil
         end
     end
 
     local dispatch
 
     local function enqueue_timer_event(event_factory)
         scheduler.enqueue(function()
             if session.finished then
                 return
             end
             if not vim.api.nvim_buf_is_valid(session.buf) then
                 dispatch({ type = "invalid" })
                 return
             end
             dispatch(event_factory())
         end)
     end
 
     local function schedule_after(name, delay_ms, event_factory)
         cancel_timer(name)
         session.timers[name] = scheduler.after(delay_ms, function()
             enqueue_timer_event(event_factory)
         end)
     end
 
     local function start_frame_timer()
         if session.timers.frame then
             return
         end
         session.timers.frame = scheduler.every(120, function()
             scheduler.enqueue(function()
                 if session.finished then
                     return
                 end
                 if not vim.api.nvim_buf_is_valid(session.buf) then
                     dispatch({ type = "invalid" })
                     return
                 end
                 local ok, valid = pcall(session.lease_valid)
                 if not ok or not valid then
                     dispatch({ type = "stale" })
                     return
                 end
                 if session.playful_verb then
                     session.frame_index = session.frame_index % #spinner + 1
                     if not render_playful() then
                         dispatch({ type = "invalid" })
                     end
                 end
             end)
         end)
     end
 
     local function reset_idle_timer()
         schedule_after("idle", 15000, function()
             return {
                 type = "idle",
                 now_ms = now_ms(),
                 verb_index = session.choose_verb_index(#verbs),
             }
         end)
     end
 
     local function rearm_early_timer(event, state)
         local deadline
@@ -305,160 +309,179 @@ M.start = function(opts)
                 end
             elseif action.type == "emit_content" then
                 call_safely("content emitter", session.emit_content, action.qid, action.chunk)
             elseif action.type == "hide" then
                 hide()
             elseif action.type == "continue_completion" then
                 hide()
                 call_safely("completion", action.completion)
             elseif action.type == "surface_failure" then
                 hide()
                 call_safely("failure surface", context and context.surface_failure, action.error)
             end
         end
     end
 
     dispatch = function(event, context)
         if session.finished then
             return
         end
         if event.type ~= "cancel" and event.type ~= "invalid" then
             local ok, valid = pcall(session.lease_valid)
             if not ok or not valid then
                 event = { type = "stale" }
             end
         end
         local previous_phase = session.state.phase
         local next_state, actions = presentation.transition(session.state, event)
         session.state = next_state
         if next_state.phase == "finished" then
             -- Release registry/timer ownership before a continuation starts a
             -- recursive LLM leg in this buffer.
             finish()
             if event.type == "cancel" or event.type == "stale" or event.type == "invalid" then
                 call_safely("discard terminal", session.on_discard, event.type, event.reason)
             end
             apply_actions(actions, context)
             return
         end
         apply_actions(actions, context)
 
         if session.finished then
             return
         end
         if rearm_early_timer(event, next_state) then
             return
         end
         if previous_phase == "waiting" and next_state.phase ~= "waiting" then
             cancel_timer("reveal")
             if next_state.phase == "released" then
                 cancel_timer("idle")
             end
         end
         if next_state.phase == "showing" and previous_phase ~= "showing" then
             schedule_after("minimum", 1000, function()
                 return { type = "minimum_due", now_ms = now_ms() }
             end)
         end
         if previous_phase == "showing" and next_state.phase ~= "showing" then
             cancel_timer("minimum")
             cancel_timer("frame")
             cancel_timer("idle")
         elseif (event.type == "activity" or event.type == "idle")
                 and (next_state.phase == "waiting" or next_state.phase == "showing") then
             reset_idle_timer()
         end
     end
 
     local function submit(event_factory, context)
         scheduler.enqueue(function()
             if session.finished then
                 return
             end
             if not vim.api.nvim_buf_is_valid(session.buf) then
                 dispatch({ type = "invalid" })
                 return
             end
             dispatch(event_factory(), context)
         end)
     end
 
+    -- Called synchronously from dispatcher.create_handler's scheduled writer.
+    -- The pending stream line may have just invalidated this extmark; repaint it
+    -- before the writer yields so queued frame/progress work never sees a gap.
+    session.tip_written = function(_self, last_written_line_0)
+        if session.finished or type(last_written_line_0) ~= "number"
+                or not vim.api.nvim_buf_is_valid(session.buf) then
+            return
+        end
+        session.anchor_line = last_written_line_0
+        session.last_mark_row = last_written_line_0
+        session.last_mark_col = 0
+        if not session.visible_text then
+            return
+        end
+        if not set_mark(session.visible_text, last_written_line_0, 0) then
+            dispatch({ type = "invalid" })
+        end
+    end
+
     session.activity = function(_self, _qid)
         submit(function()
             return {
                 type = "activity",
                 now_ms = now_ms(),
                 verb_index = session.choose_verb_index(#verbs),
             }
         end)
     end
 
     session.content = function(_self, qid, chunk)
         submit(function()
             return { type = "content", now_ms = now_ms(), qid = qid, chunk = chunk }
         end)
     end
 
     session.progress = function(_self, _qid, event)
         submit(function()
             if type(event) ~= "table" then
                 event = { message = tostring(event or "") }
             end
             local message
             session.detail_state, message = presentation.progress_message(session.detail_state, event)
             return { type = "progress", now_ms = now_ms(), message = message }
         end)
     end
 
     session.complete = function(_self, _qid, continuation)
         submit(function()
             return { type = "complete", now_ms = now_ms(), completion = continuation }
         end)
     end
 
     session.failure = function(_self, _qid, err, surface_failure)
         submit(function()
             return {
                 type = "failure",
                 error = err,
                 owns_transcript = type(surface_failure) == "function",
             }
         end, { surface_failure = surface_failure })
     end
 
     session.cancel = function(_self, reason)
         submit(function() return { type = "cancel", reason = reason } end)
     end
 
     active_by_buf[buf] = session
     local enqueued, enqueue_error = pcall(scheduler.enqueue, function()
         if session.finished then
             return
         end
         if not vim.api.nvim_buf_is_valid(session.buf) then
             dispatch({ type = "invalid" })
             return
         end
         schedule_after("reveal", 1000, function()
             return { type = "reveal_due", now_ms = now_ms() }
         end)
         reset_idle_timer()
     end)
     if not enqueued then
         finish()
         error(enqueue_error, 0)
     end
 
     return session
 end
 
 -- Cancel every registered chat session before global task termination.
 M.cancel_all = function(reason)
     local sessions = {}
     for _, session in pairs(active_by_buf) do
         table.insert(sessions, session)
     end
     for _, session in ipairs(sessions) do
         session:cancel(reason)
     end
 end
 
diff --git a/lua/parley/chat_respond.lua b/lua/parley/chat_respond.lua
index fff0ef0..496ab1f 100644
--- a/lua/parley/chat_respond.lua
+++ b/lua/parley/chat_respond.lua
@@ -1386,358 +1386,363 @@ M.respond = function(params, callback, override_free_cursor, force, live_model,
         if live_model then
             messages = M.build_messages_from_model(buf, live_model, live_target_idx, agent_info)
         else
             messages = M.build_messages({
                 parsed_chat = parsed_chat,
                 start_index = start_index,
                 end_index = end_index,
                 exchange_idx = exchange_idx,
                 agent = agent,
                 config = _parley.config,
                 helpers = _parley.helpers,
                 logger = _parley.logger,
                 resolved_remote_content = resolved_remote_content,
                 root_policy = agent_info.root_policy,
             })
         end
 
         -- Inject ancestor context (tree-of-chat): walk parent chain and prepend
         -- ancestor Q+A exchanges after the system prompt (messages[1]).
         local ancestor_msg_count = 0
         if parsed_chat.parent_link then
             local ancestor_msgs = collect_ancestor_messages(file_name, parsed_chat)
             if #ancestor_msgs > 0 then
                 ancestor_msg_count = #ancestor_msgs
                 _parley.logger.debug("Injecting " .. #ancestor_msgs .. " ancestor messages into context")
                 -- Insert after index 1 (system prompt), before current chat messages
                 for i = #ancestor_msgs, 1, -1 do
                     table.insert(messages, 2, ancestor_msgs[i])
                 end
             end
         end
 
         local agent_name = agent_info.display_name
 
         -- Set up agent prefixes
         local agent_prefix = _parley.config.chat_assistant_prefix[1]
         local agent_suffix = _parley.config.chat_assistant_prefix[2]
         if type(_parley.config.chat_assistant_prefix) == "string" then
             agent_prefix = _parley.config.chat_assistant_prefix
         elseif type(_parley.config.chat_assistant_prefix) == "table" then
             agent_prefix = _parley.config.chat_assistant_prefix[1]
             agent_suffix = _parley.config.chat_assistant_prefix[2] or ""
         end
         agent_suffix = _parley.render.template(agent_suffix, { ["{{agent}}"] = agent_name })
 
         -- ================================================================
         -- Use exchange_model to compute where to insert the response.
         -- All positions are derived from section SIZES via the model,
         -- never from stored absolute line numbers. ONE code path for
         -- all agents (tool and non-tool alike).
         -- ================================================================
         local exchange_model = require("parley.exchange_model")
         local buffer_edit = require("parley.buffer_edit")
         local tool_loop_mod = require("parley.tool_loop")
         local chat_lease = require("parley.chat_lease")
         local is_recursion = tool_loop_mod.get_iter(buf) > 0
 
         -- Reuse the live model if passed from a recursive tool-loop call.
         -- The live model is the single source of truth — it survived
         -- streaming and tool_loop block additions. Only parse fresh on
         -- the first call.
         local model = live_model
         local target_idx = live_target_idx
         if not model then
             model = exchange_model.from_parsed_chat(parsed_chat)
             target_idx = exchange_idx or #model.exchanges
         end
 
         -- Compute response_start_line using the model.
         --
         -- Every visible element is a block in the model. The model
         -- handles margins between non-empty blocks automatically.
         -- We just add blocks and ask for positions.
         --
         -- Every visible element is a block in the model. The model
         -- handles margins between non-empty blocks automatically.
         -- We add blocks to the model, then insert the corresponding
         -- lines (margin + content) into the buffer.
         --
         local stream_block_idx
+        local initial_progress_tip
         if is_recursion then
             -- Recursion: append streaming placeholder after existing blocks.
+            initial_progress_tip = assert(model:last_nonempty_block_end(target_idx),
+                "recursive response requires existing visible content")
             model:add_block(target_idx, "stream_placeholder", 1)
             stream_block_idx = #model.exchanges[target_idx].blocks
             local pos = model:block_start(target_idx, stream_block_idx)
             buffer_edit.insert_lines_at(buf, pos - 1, { "", "" })  -- margin + blank content
         else
             -- Fresh answer: add agent_header + streaming placeholder. Pending
             -- presentation is an extmark and never enters the exchange model.
             model:add_block(target_idx, "agent_header", 1)
             model:add_block(target_idx, "stream_placeholder", 1)
             stream_block_idx = #model.exchanges[target_idx].blocks
+            initial_progress_tip = model:block_start(target_idx, 2)
 
             -- Before inserting, clean up any trailing blank lines after
             -- the question in the buffer. The model's margin will be the
             -- only blank between question and agent_header.
             local agent_blk_idx = 2  -- block 1 is question, block 2 is agent_header
             local insert_start = model:block_start(target_idx, agent_blk_idx) - 1  -- -1 for margin
             -- Clean up excess blank lines at the insert point. Keep
             -- exactly 1 blank if there's a following exchange (the
             -- inter-exchange margin). Delete all blanks only if this
             -- is the last exchange.
             local buf_line_count = vim.api.nvim_buf_line_count(buf)
             if insert_start < buf_line_count then
                 local blank_count = 0
                 local check_lines = vim.api.nvim_buf_get_lines(buf, insert_start, buf_line_count, false)
                 for _, l in ipairs(check_lines) do
                     if not l:match("%S") then
                         blank_count = blank_count + 1
                     else
                         break
                     end
                 end
                 -- If there's content after the blanks (next exchange),
                 -- keep 1 blank as the inter-exchange margin.
                 local has_next = (insert_start + blank_count) < buf_line_count
                 local keep = has_next and 1 or 0
                 local to_delete = blank_count - keep
                 if to_delete > 0 then
                     buffer_edit.delete_lines_after(buf, insert_start, to_delete)
                 end
             end
             local insert_lines = { "", agent_prefix .. agent_suffix }
             table.insert(insert_lines, "")  -- margin before stream_placeholder
             table.insert(insert_lines, "")  -- stream_placeholder content (blank)
             buffer_edit.insert_lines_at(buf, insert_start, insert_lines)
         end
 
         -- #138: anchor the lease on the agent-header (`🤖:`) line — block 2 of the
         -- exchange (block 1 is the question; same index in fresh + recursion paths). It's the
         -- structural marker for the response: streaming operates below it, so ordinary writes
         -- leave it untouched, while undo/redo of the inserted response (or the
         -- user deleting the `🤖:` line) removes it and invalidates the lease.
         -- Anchoring on the stream line itself fails: stream_replace_at_line
         -- set_lines-replaces that line every chunk, which trips `invalidate`.
         local lease_generation = chat_lease.begin(buf, model:block_start(target_idx, 2), {
             target_idx = target_idx,
             stream_block_idx = stream_block_idx,
             recursion = is_recursion,
         })
         -- Every dispatched API leg has already inserted its response shell.
         -- Finalization is guarded so normal, recursive, and abort terminals all
         -- converge exactly once, after their last transcript mutation.
         local api_leg_mutated = true
         local api_leg_finalized = false
         local function finalize_mutated_api_leg()
             if api_leg_finalized then
                 return
             end
             api_leg_finalized = true
             require("parley.buffer_lifecycle").finalize_mutated_api_leg(buf, api_leg_mutated)
         end
         local lease_notice_sent = false
         local pending_session
         local function invalidate_pending_request(lease_reason)
             if not lease_notice_sent then
                 lease_notice_sent = true
                 _parley.logger.warning(lease_reason or "Parley request cancelled because the chat transcript changed")
                 vim.notify(lease_reason or "Parley request cancelled because the chat transcript changed", vim.log.levels.WARN)
             end
             if pending_session then
                 pending_session:cancel("stale")
             end
             pcall(function()
                 _parley.tasker.stop()
             end)
         end
         local function lease_valid()
             local ok, lease_reason = chat_lease.validate(buf, lease_generation, buf_changedtick(buf))
             if not ok then
                 invalidate_pending_request(lease_reason)
                 return false
             end
             return true
         end
         local function lease_commit()
             chat_lease.commit(buf, lease_generation, buf_changedtick(buf))
         end
         local function guarded_write(fn)
             if not lease_valid() then
                 return false
             end
             fn()
             lease_commit()
             return true
         end
 
         _parley.logger.debug("messages to send: " .. vim.inspect(messages))
 
         -- Check if we're in raw request mode and have a raw payload to use
         local raw_payload = nil
         if
             exchange_idx
             and parsed_chat.exchanges[exchange_idx].question
             and parsed_chat.exchanges[exchange_idx].question.raw_payload
         then
             raw_payload = parsed_chat.exchanges[exchange_idx].question.raw_payload
             _parley.logger.debug("Using raw payload for request: " .. vim.inspect(raw_payload))
         end
 
         -- Compute payload once for both display and query.
         -- agent_info.tools (from M1 Task 1.4) is passed as the 4th arg so
         -- tool-enabled agents get their client-side tools appended to the
         -- payload. Vanilla agents have agent_info.tools = nil and stay
         -- byte-identical to pre-#81 behavior.
         local final_payload = raw_payload or _parley.dispatcher.prepare_payload(messages, agent_info.model, agent_info.provider, agent_info.tools)
 
         -- Compute response_start_line from the model. This is always
         -- correct because any prior inserts (fence, etc.) updated the
         -- model via grow_question.
         local response_start_line = model:block_start(target_idx, stream_block_idx)
         local function on_stream_lines_changed(delta)
             model:grow_block(target_idx, stream_block_idx, delta)
         end
         local base_handler = _parley.dispatcher.create_handler(buf, win, response_start_line, true, "", function()
             return is_follow_cursor_enabled(override_free_cursor)
         end, on_stream_lines_changed, {
             before_write = function(_qid, _chunk)
                 return lease_valid()
             end,
-            after_write = function()
+            after_write = function(_qid, _chunk, _delta, last_written_line_0)
+                pending_session:tip_written(last_written_line_0)
                 lease_commit()
             end,
         })
         local response_handler = function(qid, chunk) pending_session:content(qid, chunk) end
 
         -- Shared empty-answer collapse (#131): used by on_exit (tool-use-only /
         -- empty response) AND on_abort, so a failed managed-cliproxy start tears
         -- down the same inserted stream placeholder instead of leaving it.
         local function collapse_empty_answer()
             if not stream_block_idx then
                 return
             end
             local sblk = model.exchanges[target_idx].blocks[stream_block_idx]
             if sblk and sblk.size == 1 then
                 local spos = model:block_start(target_idx, stream_block_idx)
                 local sline = vim.api.nvim_buf_get_lines(buf, spos, spos + 1, false)[1] or ""
                 if not sline:match("%S") then
                     -- Just a blank — remove it + its margin, set size 0 (the
                     -- empty-block rule cancels the margin).
                     local del_start = math.max(spos - 1, 0)
                     local del_count = spos - del_start + 1
                     if not guarded_write(function()
                         buffer_edit.delete_lines_after(buf, del_start, del_count)
                     end) then
                         return
                     end
                     model:set_block_size(target_idx, stream_block_idx, 0)
                 end
             end
         end
 
         local leg_teardown_done = false
         local discard_notice
         local function teardown_chat_leg(notice)
             if leg_teardown_done then return end
             leg_teardown_done = true
             local owns_shell = false
             if vim.api.nvim_buf_is_valid(buf) then
                 owns_shell = chat_lease.validate(buf, lease_generation, buf_changedtick(buf)) == true
             end
             if owns_shell then collapse_empty_answer() end
             finalize_mutated_api_leg()
             chat_lease.clear(buf, lease_generation)
             if notice then vim.notify(notice, vim.log.levels.WARN) end
         end
 
         -- Abort teardown (#131): the dispatcher invokes this (qid-free) when the
         -- managed cliproxy can't be started, so the request fails fast and the
         -- response shell is torn down exactly once.
         local function on_abort(msg)
             discard_notice = msg or "parley: request aborted"
             pending_session:cancel("abort")
         end
 
         pending_session = chat_pending.start({
             buf = buf,
-            anchor_line = model:block_start(target_idx, 2),
+            anchor_line = initial_progress_tip,
             lease_valid = lease_valid,
             emit_content = base_handler,
             choose_verb_index = function(count) return math.random(count) end,
             on_discard = function()
                 teardown_chat_leg(discard_notice)
             end,
         })
 
         -- call the model and write response
         _parley.dispatcher.query(
             buf,
             agent_info.provider,
             final_payload,
             response_handler,
             function(qid)
                 local qt = _parley.tasker.get_query(qid)
                 if not qt then
                     pending_session:complete(qid, function()
                         vim.schedule(function()
                             finalize_mutated_api_leg()
                             chat_lease.clear(buf, lease_generation)
                         end)
                     end)
                     return
                 end
                 local function continue_completion()
                     if not lease_valid() then
                         finalize_mutated_api_leg()
                         chat_lease.clear(buf, lease_generation)
                         return
                     end
                     -- Collapse the empty stream placeholder (tool-use-only or empty
                     -- response). Shared with the #131 abort path.
                     collapse_empty_answer()
 
                     -- Tool loop hook: if the streamed response contained
                     -- tool_use blocks, write 🔧:/📎: into the buffer and
                     -- re-submit. Finalization only runs on "done".
                     if agent_info and agent_info.tools and #agent_info.tools > 0 then
                         local tool_loop = require("parley.tool_loop")
                         if not lease_valid() then
                             finalize_mutated_api_leg()
                             chat_lease.clear(buf, lease_generation)
                             return
                         end
                         local outcome = tool_loop.process_response(buf, qt.raw_response or "", {
                             max_tool_iterations = agent_info.max_tool_iterations or require("parley.defaults").max_tool_iterations,
                             tool_result_max_bytes = agent_info.tool_result_max_bytes or 102400,
                             root_policy = agent_info.root_policy,
                         }, model, target_idx)
                         lease_commit()
                         if outcome == "recurse" then
                             finalize_mutated_api_leg()
                             -- Re-parse the (now updated) buffer and submit
                             -- again. force=true bypasses the is_busy check
                             -- that would otherwise reject an immediate
                             -- re-submit. The recursive respond() inherits
                             -- the same callback so user-provided
                             -- callbacks still fire on the final iteration.
                             vim.schedule(function()
                                 if not lease_valid() then
                                     finalize_mutated_api_leg()
                                     chat_lease.clear(buf, lease_generation)
                                     return
                                 end
                                 M.respond({ root_policy = agent_info.root_policy }, callback,
                                     override_free_cursor, true, model, target_idx)
                             end)
                             return
                         end
                     end
 
                     local streamed_cursor_line = query_cursor_line(qt)
 
                     -- Clean up trailing blanks after the current exchange.
                     -- The model tracks content sizes precisely, but streaming
                     -- may leave stray blank lines in the buffer. Delete
                     -- everything between the exchange's model-computed end
                     -- and the next exchange (or end of buffer).
                     local exchange_end = model:exchange_start(target_idx) + model:exchange_total_size(target_idx)
diff --git a/lua/parley/dispatcher.lua b/lua/parley/dispatcher.lua
index caa8c07..63d506b 100644
--- a/lua/parley/dispatcher.lua
+++ b/lua/parley/dispatcher.lua
@@ -498,108 +498,107 @@ D.create_handler = function(buf, win, line, first_undojoin, prefix, cursor, on_l
 
 	local function with_prefix(lines)
 		if prefix == "" then
 			return lines
 		end
 		local prefixed = {}
 		for i, l in ipairs(lines) do
 			prefixed[i] = prefix .. l
 		end
 		return prefixed
 	end
 
 	local function split_pending_and_completed(text)
 		local lines = vim.split(text, "\n")
 		local completed = {}
 		for i = 1, #lines - 1 do
 			completed[i] = lines[i]
 		end
 		local pending = lines[#lines] or ""
 		return completed, pending
 	end
 
 	return vim.schedule_wrap(function(qid, chunk)
 		local qt = tasker.get_query(qid)
 		if not qt then
 			return
 		end
 		-- if buf is not valid, stop
 		if not vim.api.nvim_buf_is_valid(buf) then
 			return
 		end
 		if not qt.ns_id then
 			qt.ns_id = ns_id
 		end
 
 		if not qt.ex_id then
 			qt.ex_id = ex_id
 		end
 
 		if type(chunk) ~= "string" then
 			return
 		end
 		if opts.before_write and not opts.before_write(qid, chunk) then
 			return
 		end
 		-- undojoin takes previous change into account, so skip it for the first chunk
 		if skip_first_undojoin then
 			skip_first_undojoin = false
 		else
 			helpers.undojoin(buf)
 		end
 
 		first_line = vim.api.nvim_buf_get_extmark_by_id(buf, ns_id, ex_id, {})[1]
 
 		local buffer_edit = require("parley.buffer_edit")
 		local previous_pending_index = finished_lines
 		local completed, new_pending
 		local delta
 		if has_started then
 			completed, new_pending = split_pending_and_completed(pending_line .. chunk)
 			table.insert(completed, new_pending)
 			local replacement = with_prefix(completed)
 			local start_line = first_line + finished_lines
 			buffer_edit.stream_replace_at_line(buf, start_line, replacement)
 			delta = #completed - 1
 			finished_lines = finished_lines + delta
 		else
 			-- Strip leading newlines from the first chunk for consistent spacing across providers
 			chunk = chunk:gsub("^\n+", "")
 			completed, new_pending = split_pending_and_completed(chunk)
 			table.insert(completed, new_pending)
 			local replacement = with_prefix(completed)
 			buffer_edit.stream_replace_at_line(buf, first_line, replacement)
 			delta = #completed - 1
 			finished_lines = delta
 			has_started = true
 		end
 		if on_lines_changed and delta > 0 then
 			on_lines_changed(delta)
 		end
+		local end_line = first_line + finished_lines + 1
+		qt.first_line = first_line
+		qt.last_line = end_line - 1
 		if opts.after_write then
-			opts.after_write(qid, chunk, delta)
+			opts.after_write(qid, chunk, delta, end_line - 1)
 		end
 		pending_line = new_pending
 		helpers.undojoin(buf)
 
 		for i = previous_pending_index, finished_lines do
 			vim.api.nvim_buf_add_highlight(buf, qt.ns_id, hl_handler_group, first_line + i, 0, -1)
 		end
 
-		local end_line = first_line + finished_lines + 1
-		qt.first_line = first_line
-		qt.last_line = end_line - 1
-
 		-- move cursor to the end of the response
 		local should_move_cursor
 		if type(cursor) == "function" then
 			should_move_cursor = cursor()
 		else
 			should_move_cursor = cursor
 		end
 		if should_move_cursor then
 			helpers.cursor_to_line(end_line, buf, win)
 		end
 	end)
 end
 
 return D
diff --git a/lua/parley/exchange_model.lua b/lua/parley/exchange_model.lua
index c7b8d81..620fd89 100644
--- a/lua/parley/exchange_model.lua
+++ b/lua/parley/exchange_model.lua
@@ -1,257 +1,272 @@
 -- Pure positional model for chat buffer layout.
 --
 -- Tracks exchange/block sizes and computes absolute 0-indexed buffer
 -- line positions. No nvim API — this module is fully testable without
 -- a running Neovim instance.
 --
 -- The model is the single source of truth for "where does block S
 -- of exchange K live in the buffer?" Callers mutate the model (add
 -- blocks, grow blocks) and the model recomputes positions on demand
 -- from accumulated sizes. No absolute line numbers are ever stored —
 -- only sizes.
 --
 -- See #90 design: size-based architecture.
 --
 -- Rules:
 --   1. Everything is a block (question, agent_header, text, tool_use,
 --      tool_result, spinner, thinking, note, ...).
 --   2. 1 blank margin line between adjacent non-empty blocks.
 --   3. Empty block (size 0) cancels one margin — effectively invisible.
 --
 -- Layout convention:
 --   HEADER (header_lines lines)
 --   MARGIN (1 blank)
 --   EXCHANGE 1:
 --     block 1: question (size lines)
 --     MARGIN (1 blank)
 --     block 2: agent_header (1 line)
 --     MARGIN (1 blank)
 --     block 3: text (size lines)
 --     MARGIN (1 blank) — only between non-empty blocks
 --     block 4: tool_use (size lines)
 --     ...
 --   MARGIN (1 blank) — between exchanges
 --   EXCHANGE 2:
 --     ...
 
 local MARGIN = 1  -- blank line between non-empty blocks
 
 local Model = {}
 Model.__index = Model
 
 local M = {}
 
+local function last_nonempty_block_index(exchange)
+    for i = #exchange.blocks, 1, -1 do
+        if exchange.blocks[i].size > 0 then
+            return i
+        end
+    end
+    return nil
+end
+
 --- Create a new empty model.
 --- @param header_lines integer  number of header lines (e.g. 4 for ---/topic/file/---)
 --- @return Model
 function M.new(header_lines)
     return setmetatable({
         header_lines = header_lines,
         exchanges = {},
     }, Model)
 end
 
 --- Add an exchange. The question is block 1 (always present).
 --- @param question_size integer  number of lines the question occupies
 function Model:add_exchange(question_size)
     table.insert(self.exchanges, {
         blocks = {
             { kind = "question", size = question_size },
         },
     })
 end
 
 --- Add a block to exchange K. Returns the 0-indexed buffer line where
 --- the block content should be inserted.
 --- @param k integer  exchange index (1-based)
 --- @param kind string  block kind (agent_header/text/tool_use/tool_result/spinner/...)
 --- @param size integer  number of lines the block occupies
 --- @return integer  0-indexed insert position
 function Model:add_block(k, kind, size)
     local pos = self:append_pos(k)
     table.insert(self.exchanges[k].blocks, {
         kind = kind,
         size = size,
     })
     return pos
 end
 
 --- Grow a block's size by delta lines (e.g. streaming added content).
 --- @param k integer  exchange index
 --- @param b integer  block index within exchange K
 --- @param delta integer  number of lines to add
 function Model:grow_block(k, b, delta)
     self.exchanges[k].blocks[b].size = self.exchanges[k].blocks[b].size + delta
 end
 
 --- Update a block's size to an exact value.
 function Model:set_block_size(k, b, new_size)
     self.exchanges[k].blocks[b].size = new_size
 end
 
 --- Remove a block from exchange K. All subsequent block positions
 --- shift automatically since they're computed from sizes.
 --- @param k integer  exchange index
 --- @param b integer  block index to remove
 function Model:remove_block(k, b)
     table.remove(self.exchanges[k].blocks, b)
 end
 
 -- ============================================================================
 -- Position queries (all return 0-indexed buffer line)
 -- ============================================================================
 
 --- Total size of exchange K in buffer lines (all non-empty blocks +
 --- margins between them).
 function Model:exchange_total_size(k)
     local size = 0
     local has_prev = false
     for _, blk in ipairs(self.exchanges[k].blocks) do
         if blk.size > 0 then
             if has_prev then
                 size = size + MARGIN
             end
             size = size + blk.size
             has_prev = true
         end
     end
     return size
 end
 
 --- 0-indexed buffer line where exchange K starts (= where its first
 --- non-empty block starts).
 function Model:exchange_start(k)
     local line = self.header_lines + MARGIN  -- after header + 1 margin
     for i = 1, k - 1 do
         line = line + self:exchange_total_size(i)
         line = line + MARGIN  -- margin between exchanges
     end
     return line
 end
 
 --- 0-indexed buffer line where block B of exchange K starts.
 --- Skips empty blocks (they're invisible per rule 3).
 function Model:block_start(k, b)
     local line = self:exchange_start(k)
     local has_prev = false
     for i = 1, b do
         local blk = self.exchanges[k].blocks[i]
         if i == b then
             -- Margin before this block if there's preceding content
             if has_prev and blk.size > 0 then
                 line = line + MARGIN
             elseif has_prev then
                 -- Block is empty — position it where it would be
                 -- (after the margin), but it occupies 0 lines.
                 line = line + MARGIN
             end
             return line
         end
         if blk.size > 0 then
             if has_prev then
                 line = line + MARGIN
             end
             line = line + blk.size
             has_prev = true
         end
     end
     return line
 end
 
 --- 0-indexed buffer line of the last line of block B.
 function Model:block_end(k, b)
     return self:block_start(k, b) + self.exchanges[k].blocks[b].size - 1
 end
 
+--- 0-indexed last line of the final visible block, or nil if none is visible.
+function Model:last_nonempty_block_end(k)
+    local block_index = last_nonempty_block_index(self.exchanges[k])
+    if not block_index then
+        return nil
+    end
+    return self:block_end(k, block_index)
+end
+
 --- 0-indexed buffer line where the NEXT block would be inserted
 --- (after all existing blocks + margin).
 function Model:append_pos(k)
-    local n = #self.exchanges[k].blocks
-    if n == 0 then
+    if #self.exchanges[k].blocks == 0 then
         return self:exchange_start(k)
     end
-    -- Find the last non-empty block
-    for i = n, 1, -1 do
-        if self.exchanges[k].blocks[i].size > 0 then
-            return self:block_end(k, i) + 1 + MARGIN
-        end
+    local last_end = self:last_nonempty_block_end(k)
+    if last_end then
+        return last_end + 1 + MARGIN
     end
     -- All blocks are empty — append at exchange start + margin
     return self:exchange_start(k) + MARGIN
 end
 
 -- ============================================================================
 -- Convenience aliases (backward compat with callers using old API names)
 -- ============================================================================
 
 --- @deprecated Use add_block
 function Model:add_section(k, kind, size)
     return self:add_block(k, kind, size)
 end
 
 --- @deprecated Use grow_block
 function Model:grow_section(k, s, delta)
     return self:grow_block(k, s, delta)
 end
 
 --- @deprecated Use remove_block
 function Model:remove_section(k, s)
     return self:remove_block(k, s)
 end
 
 --- @deprecated Use block_start
 function Model:section_start(k, s)
     return self:block_start(k, s)
 end
 
 --- @deprecated Use block_end
 function Model:section_end(k, s)
     return self:block_end(k, s)
 end
 
 --- @deprecated Use append_pos
 function Model:answer_append_pos(k)
     return self:append_pos(k)
 end
 
 --- Convenience: question_size is blocks[1].size
 function Model:question_size(k)
     return self.exchanges[k].blocks[1].size
 end
 
 --- Convenience: grow question (block 1) size.
 function Model:grow_question(k, delta)
     self:grow_block(k, 1, delta)
 end
 
 -- ============================================================================
 -- Load from parser output
 -- ============================================================================
 
 --- Build a model from a parsed_chat structure. Infers sizes from the
 --- parser's recorded line spans.
 --- @param parsed_chat table  output of chat_parser.parse_chat
 --- @return Model
 function M.from_parsed_chat(parsed_chat)
     local header_lines = parsed_chat.header_end or 0
     local model = M.new(header_lines)
     for _, ex in ipairs(parsed_chat.exchanges or {}) do
         local q_size = 1
         if ex.question then
             q_size = ex.question.line_end - ex.question.line_start + 1
         end
         model:add_exchange(q_size)
         if ex.answer then
             local k = #model.exchanges
             -- Agent header is the first answer block (🤖: line, 1 line)
             model:add_block(k, "agent_header", 1)
             for _, sec in ipairs(ex.answer.sections or {}) do
                 local sec_size = 1
                 if sec.line_start and sec.line_end then
                     sec_size = sec.line_end - sec.line_start + 1
                 end
                 model:add_block(k, sec.kind or sec.type or "text", sec_size)
             end
         end
     end
     return model

codex
The implementation matches the main intended shape so far: the writer owns the tracked row, the temporal reducer is untouched, and recursive placement uses the exchange model. I’m now checking invalidation semantics and the claimed verification/closure state, where async edge cases and traceability mismatches are most likely.
exec
/bin/zsh -lc "sed -n '1,460p' lua/parley/chat_pending.lua && sed -n '430,640p' lua/parley/dispatcher.lua && sed -n '1400,1700p' lua/parley/chat_respond.lua && sed -n '1,240p' lua/parley/buffer_edit.lua" in /Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip
 succeeded in 0ms:
-- Main-loop adapter for one chat-producing LLM leg's pending presentation.
local M = {}

local logger = require("parley.logger")
local presentation = require("parley.chat_presentation")
local spinner = require("parley.progress").SPINNER
local unpack_values = unpack

local namespace = vim.api.nvim_create_namespace("parley_chat_pending")
local active_by_buf = {}
local verbs = { "brewing", "cooking", "dragon-slaying" }

local function monotonic_now_ms()
    local uv = vim.uv or vim.loop
    return uv.hrtime() / 1000000
end

local function close_timer(timer)
    if not timer then
        return
    end
    pcall(function() timer:stop() end)
    if not timer:is_closing() then
        pcall(function() timer:close() end)
    end
end

local function production_timer(delay_ms, repeat_ms, callback)
    local uv = vim.uv or vim.loop
    local timer = uv.new_timer()
    local cancelled = false
    timer:start(delay_ms, repeat_ms, callback)
    return function()
        if cancelled then
            return
        end
        cancelled = true
        close_timer(timer)
    end
end

local production_scheduler = {
    enqueue = vim.schedule,
    after = function(delay_ms, callback)
        return production_timer(delay_ms, 0, callback)
    end,
    every = function(delay_ms, callback)
        return production_timer(delay_ms, delay_ms, callback)
    end,
}

local function call_safely(label, callback, ...)
    if type(callback) ~= "function" then
        return
    end
    local arguments = { n = select("#", ...), ... }
    local ok = xpcall(function()
        callback(unpack_values(arguments, 1, arguments.n))
    end, function()
        -- Callback errors can contain provider output, chunks, or secrets.
        return nil
    end)
    if not ok then
        logger.error("chat pending " .. label .. " callback failed")
    end
end

-- Start one serialized presentation session for a response header.
M.start = function(opts)
    opts = opts or {}
    local buf = assert(opts.buf, "buf is required")
    local existing = active_by_buf[buf]
    assert(not existing or existing.finished, "chat pending session already active for buffer")

    local scheduler = opts.scheduler or production_scheduler
    local clock = opts.clock or { now_ms = monotonic_now_ms }
    assert(type(scheduler.enqueue) == "function", "scheduler.enqueue is required")
    assert(type(scheduler.after) == "function", "scheduler.after is required")
    assert(type(scheduler.every) == "function", "scheduler.every is required")
    assert(type(clock.now_ms) == "function", "clock.now_ms is required")

    local session = {
        buf = buf,
        anchor_line = assert(opts.anchor_line, "anchor_line is required"),
        lease_valid = assert(opts.lease_valid, "lease_valid is required"),
        emit_content = assert(opts.emit_content, "emit_content is required"),
        choose_verb_index = assert(opts.choose_verb_index, "choose_verb_index is required"),
        on_discard = opts.on_discard,
        scheduler = scheduler,
        clock = clock,
        timers = {},
        frame_index = 2, -- The approved first visible frame is ⠙.
        detail_state = {},
        finished = false,
    }
    local function now_ms()
        return session.clock.now_ms()
    end

    local initial_index = session.choose_verb_index(#verbs)
    session.state = presentation.initial({
        now_ms = now_ms(),
        verbs = verbs,
        verb_index = initial_index,
    })
    assert(session.on_discard == nil or type(session.on_discard) == "function",
        "on_discard must be a function")

    local function cancel_timer(name)
        local cancel = session.timers[name]
        session.timers[name] = nil
        call_safely("timer cancellation", cancel)
    end

    local function cancel_timers()
        local names = {}
        for name in pairs(session.timers) do
            table.insert(names, name)
        end
        for _, name in ipairs(names) do
            cancel_timer(name)
        end
    end

    local function hide()
        if session.extmark_id then
            if vim.api.nvim_buf_is_valid(session.buf) then
                local position = vim.api.nvim_buf_get_extmark_by_id(
                    session.buf, namespace, session.extmark_id, { details = true })
                if #position >= 2 and not (position[3] and position[3].invalid) then
                    session.last_mark_row = position[1]
                    session.last_mark_col = position[2]
                end
            end
            pcall(vim.api.nvim_buf_del_extmark, session.buf, namespace, session.extmark_id)
            session.extmark_hidden = true
        end
        session.visible_text = nil
        session.playful_verb = nil
    end

    local function set_mark(text, row, col)
        local ok, mark_id = pcall(vim.api.nvim_buf_set_extmark, session.buf, namespace,
            row, col, {
                id = session.extmark_id,
                virt_lines = { { { text, "Comment" } } },
                virt_lines_above = false,
                invalidate = true,
            })
        if not ok then
            return false
        end
        session.extmark_id = mark_id
        session.extmark_hidden = false
        session.last_mark_row = row
        session.last_mark_col = col
        session.visible_text = text
        return true
    end

    local function render(text)
        if not vim.api.nvim_buf_is_valid(session.buf) then
            return false
        end
        local row = session.anchor_line
        local col = 0
        if session.extmark_id then
            local position = vim.api.nvim_buf_get_extmark_by_id(
                session.buf, namespace, session.extmark_id, { details = true })
            if #position >= 2 and not (position[3] and position[3].invalid) then
                row = position[1]
                col = position[2]
            elseif session.extmark_hidden and session.last_mark_row then
                row = session.last_mark_row
                col = session.last_mark_col
            else
                return false
            end
        end
        return set_mark(text, row, col)
    end

    local function render_playful()
        return render(spinner[session.frame_index] .. " " .. session.playful_verb)
    end

    local function finish()
        if session.finished then
            return
        end
        session.finished = true
        cancel_timers()
        hide()
        if active_by_buf[session.buf] == session then
            active_by_buf[session.buf] = nil
        end
    end

    local dispatch

    local function enqueue_timer_event(event_factory)
        scheduler.enqueue(function()
            if session.finished then
                return
            end
            if not vim.api.nvim_buf_is_valid(session.buf) then
                dispatch({ type = "invalid" })
                return
            end
            dispatch(event_factory())
        end)
    end

    local function schedule_after(name, delay_ms, event_factory)
        cancel_timer(name)
        session.timers[name] = scheduler.after(delay_ms, function()
            enqueue_timer_event(event_factory)
        end)
    end

    local function start_frame_timer()
        if session.timers.frame then
            return
        end
        session.timers.frame = scheduler.every(120, function()
            scheduler.enqueue(function()
                if session.finished then
                    return
                end
                if not vim.api.nvim_buf_is_valid(session.buf) then
                    dispatch({ type = "invalid" })
                    return
                end
                local ok, valid = pcall(session.lease_valid)
                if not ok or not valid then
                    dispatch({ type = "stale" })
                    return
                end
                if session.playful_verb then
                    session.frame_index = session.frame_index % #spinner + 1
                    if not render_playful() then
                        dispatch({ type = "invalid" })
                    end
                end
            end)
        end)
    end

    local function reset_idle_timer()
        schedule_after("idle", 15000, function()
            return {
                type = "idle",
                now_ms = now_ms(),
                verb_index = session.choose_verb_index(#verbs),
            }
        end)
    end

    local function rearm_early_timer(event, state)
        local deadline
        local name
        local event_factory
        if event.type == "reveal_due" and state.phase == "waiting" then
            deadline = state.reveal_at
            name = "reveal"
            event_factory = function()
                return { type = "reveal_due", now_ms = now_ms() }
            end
        elseif event.type == "minimum_due" and state.phase == "showing" then
            deadline = state.minimum_at
            name = "minimum"
            event_factory = function()
                return { type = "minimum_due", now_ms = now_ms() }
            end
        elseif event.type == "idle"
                and (state.phase == "waiting" or state.phase == "showing") then
            deadline = state.verb_due_at
            name = "idle"
            event_factory = function()
                return {
                    type = "idle",
                    now_ms = now_ms(),
                    verb_index = session.choose_verb_index(#verbs),
                }
            end
        end
        if deadline and event.now_ms < deadline then
            schedule_after(name, math.max(1, math.ceil(deadline - event.now_ms)), event_factory)
            return true
        end
        return false
    end

    local function apply_actions(actions, context)
        for _, action in ipairs(actions) do
            if action.type == "show_playful" then
                session.playful_verb = action.verb
                if not render_playful() then
                    finish()
                    return
                end
                start_frame_timer()
            elseif action.type == "render_status" then
                session.playful_verb = nil
                cancel_timer("frame")
                if not render(action.message) then
                    finish()
                    return
                end
            elseif action.type == "emit_content" then
                call_safely("content emitter", session.emit_content, action.qid, action.chunk)
            elseif action.type == "hide" then
                hide()
            elseif action.type == "continue_completion" then
                hide()
                call_safely("completion", action.completion)
            elseif action.type == "surface_failure" then
                hide()
                call_safely("failure surface", context and context.surface_failure, action.error)
            end
        end
    end

    dispatch = function(event, context)
        if session.finished then
            return
        end
        if event.type ~= "cancel" and event.type ~= "invalid" then
            local ok, valid = pcall(session.lease_valid)
            if not ok or not valid then
                event = { type = "stale" }
            end
        end
        local previous_phase = session.state.phase
        local next_state, actions = presentation.transition(session.state, event)
        session.state = next_state
        if next_state.phase == "finished" then
            -- Release registry/timer ownership before a continuation starts a
            -- recursive LLM leg in this buffer.
            finish()
            if event.type == "cancel" or event.type == "stale" or event.type == "invalid" then
                call_safely("discard terminal", session.on_discard, event.type, event.reason)
            end
            apply_actions(actions, context)
            return
        end
        apply_actions(actions, context)

        if session.finished then
            return
        end
        if rearm_early_timer(event, next_state) then
            return
        end
        if previous_phase == "waiting" and next_state.phase ~= "waiting" then
            cancel_timer("reveal")
            if next_state.phase == "released" then
                cancel_timer("idle")
            end
        end
        if next_state.phase == "showing" and previous_phase ~= "showing" then
            schedule_after("minimum", 1000, function()
                return { type = "minimum_due", now_ms = now_ms() }
            end)
        end
        if previous_phase == "showing" and next_state.phase ~= "showing" then
            cancel_timer("minimum")
            cancel_timer("frame")
            cancel_timer("idle")
        elseif (event.type == "activity" or event.type == "idle")
                and (next_state.phase == "waiting" or next_state.phase == "showing") then
            reset_idle_timer()
        end
    end

    local function submit(event_factory, context)
        scheduler.enqueue(function()
            if session.finished then
                return
            end
            if not vim.api.nvim_buf_is_valid(session.buf) then
                dispatch({ type = "invalid" })
                return
            end
            dispatch(event_factory(), context)
        end)
    end

    -- Called synchronously from dispatcher.create_handler's scheduled writer.
    -- The pending stream line may have just invalidated this extmark; repaint it
    -- before the writer yields so queued frame/progress work never sees a gap.
    session.tip_written = function(_self, last_written_line_0)
        if session.finished or type(last_written_line_0) ~= "number"
                or not vim.api.nvim_buf_is_valid(session.buf) then
            return
        end
        session.anchor_line = last_written_line_0
        session.last_mark_row = last_written_line_0
        session.last_mark_col = 0
        if not session.visible_text then
            return
        end
        if not set_mark(session.visible_text, last_written_line_0, 0) then
            dispatch({ type = "invalid" })
        end
    end

    session.activity = function(_self, _qid)
        submit(function()
            return {
                type = "activity",
                now_ms = now_ms(),
                verb_index = session.choose_verb_index(#verbs),
            }
        end)
    end

    session.content = function(_self, qid, chunk)
        submit(function()
            return { type = "content", now_ms = now_ms(), qid = qid, chunk = chunk }
        end)
    end

    session.progress = function(_self, _qid, event)
        submit(function()
            if type(event) ~= "table" then
                event = { message = tostring(event or "") }
            end
            local message
            session.detail_state, message = presentation.progress_message(session.detail_state, event)
            return { type = "progress", now_ms = now_ms(), message = message }
        end)
    end

    session.complete = function(_self, _qid, continuation)
        submit(function()
            return { type = "complete", now_ms = now_ms(), completion = continuation }
        end)
    end

    session.failure = function(_self, _qid, err, surface_failure)
        submit(function()
            return {
                type = "failure",
                error = err,
                owns_transcript = type(surface_failure) == "function",
            }
        end, { surface_failure = surface_failure })
    end

    session.cancel = function(_self, reason)
        submit(function() return { type = "cancel", reason = reason } end)
    end

    active_by_buf[buf] = session
    local enqueued, enqueue_error = pcall(scheduler.enqueue, function()
        if session.finished then
            return
        end
        if not vim.api.nvim_buf_is_valid(session.buf) then
---@param buf number | nil # buffer number
---@param provider string # provider name
---@param payload table # payload for api
---@param handler function # response handler
---@param on_exit function | nil # optional on_exit handler
---@param callback function | nil # optional callback handler
---@param on_progress function | nil # optional progress/status handler
--- @param on_abort function | nil # optional qid-free pre-start abort handler
---   pre_query reports an error (e.g. the managed cliproxy can't be started),
---   the dispatcher invokes on_abort(msg) INSTEAD of running the query — the
---   caller uses it to tear down qid-free pre-query state (spinner, inserted
---   blocks, in-flight guards) so the request fails fast instead of hanging.
---   Additive + backward compatible: a one-arg pre_query (e.g. copilot) simply
---   ignores the error callback the dispatcher passes it.
D.query = function(buf, provider, payload, handler, on_exit, callback, on_progress, on_abort,
	on_activity, on_error)
	local abort_before_start = tasker.once(function(msg)
		logger.error("query abort before start [" .. tostring(provider) .. "]: " .. tostring(msg))
		if type(on_abort) == "function" then
			on_abort(msg)
		end
	end)
	local function start_query()
		query(buf, provider, payload, handler, on_exit, callback, on_progress,
			on_activity, on_error, abort_before_start)
	end
	local adapter = providers.get(provider)
	if adapter.pre_query then
		return vault.run_with_secret(provider, function()
			adapter.pre_query(function()
				start_query()
			end, function(msg)
				abort_before_start(msg)
			end)
		end, abort_before_start)
	end
	vault.run_with_secret(provider, function()
		start_query()
	end, abort_before_start)
end

-- response handler
---@param buf number | nil # buffer to insert response into
---@param win number | nil # window to insert response into
---@param line number | nil # line to insert response into
---@param first_undojoin boolean | nil # whether to skip first undojoin
---@param prefix string | nil # prefix to insert before each response line
---@param cursor boolean | function # whether to move cursor to the end of the response
D.create_handler = function(buf, win, line, first_undojoin, prefix, cursor, on_lines_changed, opts)
	buf = buf or vim.api.nvim_get_current_buf()
	opts = opts or {}
	prefix = prefix or ""
	local first_line = line or vim.api.nvim_win_get_cursor(win or 0)[1] - 1
	local finished_lines = 0
	local skip_first_undojoin = not first_undojoin

	local hl_handler_group = "ParleyHandlerStandout"
	vim.cmd("highlight default link " .. hl_handler_group .. " CursorLine")

	local ns_id = vim.api.nvim_create_namespace("ParleyHandler_" .. helpers.uuid())

	local ex_id = vim.api.nvim_buf_set_extmark(buf, ns_id, first_line, 0, {
		strict = false,
		right_gravity = false,
	})

	local has_started = false
	local pending_line = ""

	local function with_prefix(lines)
		if prefix == "" then
			return lines
		end
		local prefixed = {}
		for i, l in ipairs(lines) do
			prefixed[i] = prefix .. l
		end
		return prefixed
	end

	local function split_pending_and_completed(text)
		local lines = vim.split(text, "\n")
		local completed = {}
		for i = 1, #lines - 1 do
			completed[i] = lines[i]
		end
		local pending = lines[#lines] or ""
		return completed, pending
	end

	return vim.schedule_wrap(function(qid, chunk)
		local qt = tasker.get_query(qid)
		if not qt then
			return
		end
		-- if buf is not valid, stop
		if not vim.api.nvim_buf_is_valid(buf) then
			return
		end
		if not qt.ns_id then
			qt.ns_id = ns_id
		end

		if not qt.ex_id then
			qt.ex_id = ex_id
		end

		if type(chunk) ~= "string" then
			return
		end
		if opts.before_write and not opts.before_write(qid, chunk) then
			return
		end
		-- undojoin takes previous change into account, so skip it for the first chunk
		if skip_first_undojoin then
			skip_first_undojoin = false
		else
			helpers.undojoin(buf)
		end

		first_line = vim.api.nvim_buf_get_extmark_by_id(buf, ns_id, ex_id, {})[1]

		local buffer_edit = require("parley.buffer_edit")
		local previous_pending_index = finished_lines
		local completed, new_pending
		local delta
		if has_started then
			completed, new_pending = split_pending_and_completed(pending_line .. chunk)
			table.insert(completed, new_pending)
			local replacement = with_prefix(completed)
			local start_line = first_line + finished_lines
			buffer_edit.stream_replace_at_line(buf, start_line, replacement)
			delta = #completed - 1
			finished_lines = finished_lines + delta
		else
			-- Strip leading newlines from the first chunk for consistent spacing across providers
			chunk = chunk:gsub("^\n+", "")
			completed, new_pending = split_pending_and_completed(chunk)
			table.insert(completed, new_pending)
			local replacement = with_prefix(completed)
			buffer_edit.stream_replace_at_line(buf, first_line, replacement)
			delta = #completed - 1
			finished_lines = delta
			has_started = true
		end
		if on_lines_changed and delta > 0 then
			on_lines_changed(delta)
		end
		local end_line = first_line + finished_lines + 1
		qt.first_line = first_line
		qt.last_line = end_line - 1
		if opts.after_write then
			opts.after_write(qid, chunk, delta, end_line - 1)
		end
		pending_line = new_pending
		helpers.undojoin(buf)

		for i = previous_pending_index, finished_lines do
			vim.api.nvim_buf_add_highlight(buf, qt.ns_id, hl_handler_group, first_line + i, 0, -1)
		end

		-- move cursor to the end of the response
		local should_move_cursor
		if type(cursor) == "function" then
			should_move_cursor = cursor()
		else
			should_move_cursor = cursor
		end
		if should_move_cursor then
			helpers.cursor_to_line(end_line, buf, win)
		end
	end)
end

return D
            })
        end

        -- Inject ancestor context (tree-of-chat): walk parent chain and prepend
        -- ancestor Q+A exchanges after the system prompt (messages[1]).
        local ancestor_msg_count = 0
        if parsed_chat.parent_link then
            local ancestor_msgs = collect_ancestor_messages(file_name, parsed_chat)
            if #ancestor_msgs > 0 then
                ancestor_msg_count = #ancestor_msgs
                _parley.logger.debug("Injecting " .. #ancestor_msgs .. " ancestor messages into context")
                -- Insert after index 1 (system prompt), before current chat messages
                for i = #ancestor_msgs, 1, -1 do
                    table.insert(messages, 2, ancestor_msgs[i])
                end
            end
        end

        local agent_name = agent_info.display_name

        -- Set up agent prefixes
        local agent_prefix = _parley.config.chat_assistant_prefix[1]
        local agent_suffix = _parley.config.chat_assistant_prefix[2]
        if type(_parley.config.chat_assistant_prefix) == "string" then
            agent_prefix = _parley.config.chat_assistant_prefix
        elseif type(_parley.config.chat_assistant_prefix) == "table" then
            agent_prefix = _parley.config.chat_assistant_prefix[1]
            agent_suffix = _parley.config.chat_assistant_prefix[2] or ""
        end
        agent_suffix = _parley.render.template(agent_suffix, { ["{{agent}}"] = agent_name })

        -- ================================================================
        -- Use exchange_model to compute where to insert the response.
        -- All positions are derived from section SIZES via the model,
        -- never from stored absolute line numbers. ONE code path for
        -- all agents (tool and non-tool alike).
        -- ================================================================
        local exchange_model = require("parley.exchange_model")
        local buffer_edit = require("parley.buffer_edit")
        local tool_loop_mod = require("parley.tool_loop")
        local chat_lease = require("parley.chat_lease")
        local is_recursion = tool_loop_mod.get_iter(buf) > 0

        -- Reuse the live model if passed from a recursive tool-loop call.
        -- The live model is the single source of truth — it survived
        -- streaming and tool_loop block additions. Only parse fresh on
        -- the first call.
        local model = live_model
        local target_idx = live_target_idx
        if not model then
            model = exchange_model.from_parsed_chat(parsed_chat)
            target_idx = exchange_idx or #model.exchanges
        end

        -- Compute response_start_line using the model.
        --
        -- Every visible element is a block in the model. The model
        -- handles margins between non-empty blocks automatically.
        -- We just add blocks and ask for positions.
        --
        -- Every visible element is a block in the model. The model
        -- handles margins between non-empty blocks automatically.
        -- We add blocks to the model, then insert the corresponding
        -- lines (margin + content) into the buffer.
        --
        local stream_block_idx
        local initial_progress_tip
        if is_recursion then
            -- Recursion: append streaming placeholder after existing blocks.
            initial_progress_tip = assert(model:last_nonempty_block_end(target_idx),
                "recursive response requires existing visible content")
            model:add_block(target_idx, "stream_placeholder", 1)
            stream_block_idx = #model.exchanges[target_idx].blocks
            local pos = model:block_start(target_idx, stream_block_idx)
            buffer_edit.insert_lines_at(buf, pos - 1, { "", "" })  -- margin + blank content
        else
            -- Fresh answer: add agent_header + streaming placeholder. Pending
            -- presentation is an extmark and never enters the exchange model.
            model:add_block(target_idx, "agent_header", 1)
            model:add_block(target_idx, "stream_placeholder", 1)
            stream_block_idx = #model.exchanges[target_idx].blocks
            initial_progress_tip = model:block_start(target_idx, 2)

            -- Before inserting, clean up any trailing blank lines after
            -- the question in the buffer. The model's margin will be the
            -- only blank between question and agent_header.
            local agent_blk_idx = 2  -- block 1 is question, block 2 is agent_header
            local insert_start = model:block_start(target_idx, agent_blk_idx) - 1  -- -1 for margin
            -- Clean up excess blank lines at the insert point. Keep
            -- exactly 1 blank if there's a following exchange (the
            -- inter-exchange margin). Delete all blanks only if this
            -- is the last exchange.
            local buf_line_count = vim.api.nvim_buf_line_count(buf)
            if insert_start < buf_line_count then
                local blank_count = 0
                local check_lines = vim.api.nvim_buf_get_lines(buf, insert_start, buf_line_count, false)
                for _, l in ipairs(check_lines) do
                    if not l:match("%S") then
                        blank_count = blank_count + 1
                    else
                        break
                    end
                end
                -- If there's content after the blanks (next exchange),
                -- keep 1 blank as the inter-exchange margin.
                local has_next = (insert_start + blank_count) < buf_line_count
                local keep = has_next and 1 or 0
                local to_delete = blank_count - keep
                if to_delete > 0 then
                    buffer_edit.delete_lines_after(buf, insert_start, to_delete)
                end
            end
            local insert_lines = { "", agent_prefix .. agent_suffix }
            table.insert(insert_lines, "")  -- margin before stream_placeholder
            table.insert(insert_lines, "")  -- stream_placeholder content (blank)
            buffer_edit.insert_lines_at(buf, insert_start, insert_lines)
        end

        -- #138: anchor the lease on the agent-header (`🤖:`) line — block 2 of the
        -- exchange (block 1 is the question; same index in fresh + recursion paths). It's the
        -- structural marker for the response: streaming operates below it, so ordinary writes
        -- leave it untouched, while undo/redo of the inserted response (or the
        -- user deleting the `🤖:` line) removes it and invalidates the lease.
        -- Anchoring on the stream line itself fails: stream_replace_at_line
        -- set_lines-replaces that line every chunk, which trips `invalidate`.
        local lease_generation = chat_lease.begin(buf, model:block_start(target_idx, 2), {
            target_idx = target_idx,
            stream_block_idx = stream_block_idx,
            recursion = is_recursion,
        })
        -- Every dispatched API leg has already inserted its response shell.
        -- Finalization is guarded so normal, recursive, and abort terminals all
        -- converge exactly once, after their last transcript mutation.
        local api_leg_mutated = true
        local api_leg_finalized = false
        local function finalize_mutated_api_leg()
            if api_leg_finalized then
                return
            end
            api_leg_finalized = true
            require("parley.buffer_lifecycle").finalize_mutated_api_leg(buf, api_leg_mutated)
        end
        local lease_notice_sent = false
        local pending_session
        local function invalidate_pending_request(lease_reason)
            if not lease_notice_sent then
                lease_notice_sent = true
                _parley.logger.warning(lease_reason or "Parley request cancelled because the chat transcript changed")
                vim.notify(lease_reason or "Parley request cancelled because the chat transcript changed", vim.log.levels.WARN)
            end
            if pending_session then
                pending_session:cancel("stale")
            end
            pcall(function()
                _parley.tasker.stop()
            end)
        end
        local function lease_valid()
            local ok, lease_reason = chat_lease.validate(buf, lease_generation, buf_changedtick(buf))
            if not ok then
                invalidate_pending_request(lease_reason)
                return false
            end
            return true
        end
        local function lease_commit()
            chat_lease.commit(buf, lease_generation, buf_changedtick(buf))
        end
        local function guarded_write(fn)
            if not lease_valid() then
                return false
            end
            fn()
            lease_commit()
            return true
        end

        _parley.logger.debug("messages to send: " .. vim.inspect(messages))

        -- Check if we're in raw request mode and have a raw payload to use
        local raw_payload = nil
        if
            exchange_idx
            and parsed_chat.exchanges[exchange_idx].question
            and parsed_chat.exchanges[exchange_idx].question.raw_payload
        then
            raw_payload = parsed_chat.exchanges[exchange_idx].question.raw_payload
            _parley.logger.debug("Using raw payload for request: " .. vim.inspect(raw_payload))
        end

        -- Compute payload once for both display and query.
        -- agent_info.tools (from M1 Task 1.4) is passed as the 4th arg so
        -- tool-enabled agents get their client-side tools appended to the
        -- payload. Vanilla agents have agent_info.tools = nil and stay
        -- byte-identical to pre-#81 behavior.
        local final_payload = raw_payload or _parley.dispatcher.prepare_payload(messages, agent_info.model, agent_info.provider, agent_info.tools)

        -- Compute response_start_line from the model. This is always
        -- correct because any prior inserts (fence, etc.) updated the
        -- model via grow_question.
        local response_start_line = model:block_start(target_idx, stream_block_idx)
        local function on_stream_lines_changed(delta)
            model:grow_block(target_idx, stream_block_idx, delta)
        end
        local base_handler = _parley.dispatcher.create_handler(buf, win, response_start_line, true, "", function()
            return is_follow_cursor_enabled(override_free_cursor)
        end, on_stream_lines_changed, {
            before_write = function(_qid, _chunk)
                return lease_valid()
            end,
            after_write = function(_qid, _chunk, _delta, last_written_line_0)
                pending_session:tip_written(last_written_line_0)
                lease_commit()
            end,
        })
        local response_handler = function(qid, chunk) pending_session:content(qid, chunk) end

        -- Shared empty-answer collapse (#131): used by on_exit (tool-use-only /
        -- empty response) AND on_abort, so a failed managed-cliproxy start tears
        -- down the same inserted stream placeholder instead of leaving it.
        local function collapse_empty_answer()
            if not stream_block_idx then
                return
            end
            local sblk = model.exchanges[target_idx].blocks[stream_block_idx]
            if sblk and sblk.size == 1 then
                local spos = model:block_start(target_idx, stream_block_idx)
                local sline = vim.api.nvim_buf_get_lines(buf, spos, spos + 1, false)[1] or ""
                if not sline:match("%S") then
                    -- Just a blank — remove it + its margin, set size 0 (the
                    -- empty-block rule cancels the margin).
                    local del_start = math.max(spos - 1, 0)
                    local del_count = spos - del_start + 1
                    if not guarded_write(function()
                        buffer_edit.delete_lines_after(buf, del_start, del_count)
                    end) then
                        return
                    end
                    model:set_block_size(target_idx, stream_block_idx, 0)
                end
            end
        end

        local leg_teardown_done = false
        local discard_notice
        local function teardown_chat_leg(notice)
            if leg_teardown_done then return end
            leg_teardown_done = true
            local owns_shell = false
            if vim.api.nvim_buf_is_valid(buf) then
                owns_shell = chat_lease.validate(buf, lease_generation, buf_changedtick(buf)) == true
            end
            if owns_shell then collapse_empty_answer() end
            finalize_mutated_api_leg()
            chat_lease.clear(buf, lease_generation)
            if notice then vim.notify(notice, vim.log.levels.WARN) end
        end

        -- Abort teardown (#131): the dispatcher invokes this (qid-free) when the
        -- managed cliproxy can't be started, so the request fails fast and the
        -- response shell is torn down exactly once.
        local function on_abort(msg)
            discard_notice = msg or "parley: request aborted"
            pending_session:cancel("abort")
        end

        pending_session = chat_pending.start({
            buf = buf,
            anchor_line = initial_progress_tip,
            lease_valid = lease_valid,
            emit_content = base_handler,
            choose_verb_index = function(count) return math.random(count) end,
            on_discard = function()
                teardown_chat_leg(discard_notice)
            end,
        })

        -- call the model and write response
        _parley.dispatcher.query(
            buf,
            agent_info.provider,
            final_payload,
            response_handler,
            function(qid)
                local qt = _parley.tasker.get_query(qid)
                if not qt then
                    pending_session:complete(qid, function()
                        vim.schedule(function()
                            finalize_mutated_api_leg()
                            chat_lease.clear(buf, lease_generation)
                        end)
                    end)
                    return
                end
                local function continue_completion()
                    if not lease_valid() then
                        finalize_mutated_api_leg()
                        chat_lease.clear(buf, lease_generation)
                        return
                    end
                    -- Collapse the empty stream placeholder (tool-use-only or empty
-- Single mutation entry point for the chat buffer.
--
-- All nvim_buf_set_lines / nvim_buf_set_text calls in the chat buffer
-- rendering pipeline live here. The architectural fitness function in
-- tests/arch/buffer_mutation_spec.lua enforces this invariant.
--
-- See workshop/plans/000090-renderer-refactor.md section 3.

local M = {}

local NS_NAME = "ParleyBufferEdit"
local ns_id = vim.api.nvim_create_namespace(NS_NAME)

-- ============================================================================
-- PosHandle: opaque extmark-backed position. Caller never sees raw line
-- numbers. Internally a { buf, ns_id, ex_id, dead } table; the line is
-- resolved on demand via nvim_buf_get_extmark_by_id, so concurrent
-- inserts at or before the position are handled by the extmark gravity
-- mechanism (right_gravity = false means inserts AT the position push
-- the handle right, perfect for "anchor before this line, append text").
-- ============================================================================

--- Create a position handle anchored at a 0-indexed buffer line.
--- @param buf integer
--- @param line_0_indexed integer
--- @return PosHandle
function M.make_handle(buf, line_0_indexed)
    local ex_id = vim.api.nvim_buf_set_extmark(buf, ns_id, line_0_indexed, 0, {
        right_gravity = false,
        strict = false,
    })
    return { buf = buf, ns_id = ns_id, ex_id = ex_id, dead = false }
end

--- Resolve the current 0-indexed buffer line of a handle.
function M.handle_line(handle)
    if handle.dead then
        error("buffer_edit: handle is dead")
    end
    local pos = vim.api.nvim_buf_get_extmark_by_id(handle.buf, handle.ns_id, handle.ex_id, {})
    return pos[1]
end

--- Mark a handle dead and remove its extmark. Subsequent operations on
--- the handle raise.
function M.handle_invalidate(handle)
    if not handle.dead then
        pcall(vim.api.nvim_buf_del_extmark, handle.buf, handle.ns_id, handle.ex_id)
        handle.dead = true
    end
end

-- ============================================================================
-- Topic header ops
-- ============================================================================

--- Replace the line at line_0_indexed with `text`.
function M.set_topic_header_line(buf, line_0_indexed, text)
    vim.api.nvim_buf_set_lines(buf, line_0_indexed, line_0_indexed + 1, false, { text })
end

--- Insert `text` as a new line right after line_0_indexed.
function M.insert_topic_line(buf, after_line_0_indexed, text)
    vim.api.nvim_buf_set_lines(buf, after_line_0_indexed + 1, after_line_0_indexed + 1, false, { text })
end

-- ============================================================================
-- Answer region ops
-- ============================================================================

local render_buffer = require("parley.render_buffer")

--- Insert a single blank line after the given 0-indexed line. Used to
--- pad a question that doesn't already end with whitespace.
function M.pad_question_with_blank(buf, after_line_0_indexed)
    vim.api.nvim_buf_set_lines(buf, after_line_0_indexed + 1, after_line_0_indexed + 1, false, { "" })
end

--- Create a fresh answer region after the given 0-indexed line. Writes
--- a blank separator + agent header + trailing blank, returning a
--- PosHandle pointing at the trailing blank — the line where streaming
--- writes should append.
--- @param buf integer
--- @param after_line_0_indexed integer
--- @param agent_prefix string  e.g. "[Claude]"
--- @param agent_suffix string|nil  e.g. "[🔧]"
--- @return PosHandle
function M.create_answer_region(buf, after_line_0_indexed, agent_prefix, agent_suffix)
    local lines = render_buffer.agent_header_lines(agent_prefix, agent_suffix)
    local insert_at = after_line_0_indexed + 1
    vim.api.nvim_buf_set_lines(buf, insert_at, insert_at, false, lines)
    -- Trailing blank is at insert_at + #lines - 1.
    return M.make_handle(buf, insert_at + #lines - 1)
end

--- Delete an answer region by inclusive 0-indexed line range.
function M.delete_answer(buf, line_start_0_indexed, line_end_0_indexed)
    vim.api.nvim_buf_set_lines(buf, line_start_0_indexed, line_end_0_indexed + 1, false, {})
end

--- Replace an answer region with a single blank separator. Returns a
--- handle anchored at the blank — the next answer's create_answer_region
--- should be called using this handle's resolved line.
function M.replace_answer(buf, line_start_0_indexed, line_end_0_indexed)
    vim.api.nvim_buf_set_lines(buf, line_start_0_indexed, line_end_0_indexed + 1, false, { "" })
    return M.make_handle(buf, line_start_0_indexed)
end

--- Replace the entire chat buffer with the given lines. Used by full-buffer
--- rewrites driven by pure transforms — the drill-in pipeline gathers ready
--- markers, strips them, and appends a quote block, then writes the result
--- back here in one shot.
function M.replace_all_lines(buf, lines)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

--- Replace the entire chat buffer after a pure definition-footnote transform.
function M.replace_all_lines_for_definition(buf, lines)
    M.replace_all_lines(buf, lines)
end

--- Append a section to an answer. The section is rendered via
--- render_buffer.render_section. If the line at `after_line_0_indexed`
--- is non-empty, a blank separator is inserted first so blocks don't
--- concatenate. Returns a PosHandle anchored at the line right after
--- the last appended line — the next streaming or section append goes
--- there.
--- @param buf integer
--- @param after_line_0_indexed integer
--- @param section table
--- @return PosHandle
function M.append_section_to_answer(buf, after_line_0_indexed, section)
    local prev_line = vim.api.nvim_buf_get_lines(buf, after_line_0_indexed, after_line_0_indexed + 1, false)[1] or ""
    local rendered = render_buffer.render_section(section)
    local insert_lines = {}
    if prev_line:match("%S") then
        table.insert(insert_lines, "")
    end
    for _, l in ipairs(rendered) do
        table.insert(insert_lines, l)
    end
    local insert_at = after_line_0_indexed + 1
    vim.api.nvim_buf_set_lines(buf, insert_at, insert_at, false, insert_lines)
    return M.make_handle(buf, insert_at + #insert_lines - 1)
end

-- ============================================================================
-- Streaming
-- ============================================================================
--
-- The streaming protocol receives chunks of text that may not align on
-- newline boundaries. We accumulate any trailing partial line in
-- handle._stream.pending and write complete lines to the buffer as they
-- arrive. The pending partial line is also written to the buffer as a
-- "ghost" trailing line so the user sees streaming progress in real
-- time; subsequent chunks overwrite that line.
--
-- finished_lines counts complete (newline-terminated) lines we've
-- already written, so we know how far the handle has advanced from its
-- original anchor.
-- ============================================================================

local function ensure_stream_state(handle)
    handle._stream = handle._stream or { pending = "", finished_lines = 0 }
    return handle._stream
end

--- Write a chunk of text at the position indicated by `handle`.
function M.stream_into(handle, chunk)
    if handle.dead then
        return
    end
    local s = ensure_stream_state(handle)
    s.pending = s.pending .. chunk
    -- Split on \n, plain mode. The last entry is the new pending text.
    local parts = vim.split(s.pending, "\n", { plain = true })
    s.pending = parts[#parts]
    table.remove(parts)
    local first_line = M.handle_line(handle)
    local write_at = first_line + s.finished_lines
    table.insert(parts, s.pending)
    vim.api.nvim_buf_set_lines(handle.buf, write_at, write_at + 1, false, parts)
    s.finished_lines = s.finished_lines + (#parts - 1)
end

--- Finalize the stream — currently just invalidates the handle. The
--- pending partial line is already in the buffer as a ghost.
function M.stream_finalize(handle)
    M.handle_invalidate(handle)
end

-- ============================================================================
-- Cancellation cleanup
-- ============================================================================

--- Delete `n` lines starting at the given 0-indexed line.
function M.delete_lines_after(buf, line_0_indexed, n)
    vim.api.nvim_buf_set_lines(buf, line_0_indexed, line_0_indexed + n, false, {})
end

--- Delete from `line_0_indexed` to the end of the buffer.
function M.delete_to_end(buf, line_0_indexed)
    vim.api.nvim_buf_set_lines(buf, line_0_indexed, -1, false, {})
end

--- Insert raw lines at the given 0-indexed line. Used for the
--- end-of-stream "next user prompt" insert which is structurally
--- distinct from append_section_to_answer (no rendering, no separator
--- handling — caller passes the exact lines).
function M.insert_lines_at(buf, line_0_indexed, lines)
    vim.api.nvim_buf_set_lines(buf, line_0_indexed, line_0_indexed, false, lines)
end

--- Replace the line at line_0_indexed with the given text. Distinct
--- from set_topic_header_line in name only — semantically identical,
--- but kept separate so the call sites read clearly at the migration
--- boundary. Used for the progress spinner line update path.
function M.replace_line_at(buf, line_0_indexed, text)
    vim.api.nvim_buf_set_lines(buf, line_0_indexed, line_0_indexed + 1, false, { text or "" })
end

--- Replace one line at line_0_indexed with multiple lines. Used by
--- dispatcher.create_handler's streaming chunk replacement path —
--- the existing single line at write_at gets replaced with the
--- newly-completed lines plus the trailing pending "ghost" line.
function M.stream_replace_at_line(buf, line_0_indexed, lines)
    vim.api.nvim_buf_set_lines(buf, line_0_indexed, line_0_indexed + 1, false, lines)
end

--- Append a blank line at the very end of the buffer.
function M.append_blank_at_end(buf)
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "" })
end

return M

exec
/bin/zsh -lc "sed -n '1,240p' Makefile.local; rg -n \"after_write|tip_written|last_nonempty_block_end|chat_pending.start\" lua tests | sed -n '1,240p'; git diff --name-status e3ed1e032140143b1c92dbf1ffe3a9bf7e54c793..HEAD -- README.md atlas workshop/issues/000183-keep-response-progress-at-current-generation-tip.md" in /Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip
 succeeded in 0ms:
# Parley-specific Makefile targets.
# This file is included by Makefile — add your own targets here.

include Makefile.parley
lua/parley/dispatcher.lua:581:		if opts.after_write then
lua/parley/dispatcher.lua:582:			opts.after_write(qid, chunk, delta, end_line - 1)
lua/parley/chat_pending.lua:392:    session.tip_written = function(_self, last_written_line_0)
tests/integration/chat_pending_spec.lua:123:    local session = chat_pending.start({
tests/integration/chat_pending_spec.lua:265:        session:tip_written(1)
tests/integration/chat_pending_spec.lua:290:        session:tip_written(1)
tests/integration/chat_pending_spec.lua:314:        session:tip_written(0)
tests/integration/chat_pending_spec.lua:442:        local session = chat_pending.start({
tests/integration/chat_pending_spec.lua:568:            local session = chat_pending.start({
tests/integration/chat_pending_spec.lua:590:        local session = chat_pending.start({
tests/integration/chat_pending_spec.lua:615:        local session = chat_pending.start({
tests/integration/chat_pending_spec.lua:643:            local session = chat_pending.start({
tests/integration/chat_pending_spec.lua:712:                chat_pending.start({
tests/integration/chat_pending_spec.lua:738:        local session = chat_pending.start({
lua/parley/chat_respond.lua:998:                if spinner.after_write then
lua/parley/chat_respond.lua:999:                    spinner.after_write()
lua/parley/chat_respond.lua:1469:            initial_progress_tip = assert(model:last_nonempty_block_end(target_idx),
lua/parley/chat_respond.lua:1610:            after_write = function(_qid, _chunk, _delta, last_written_line_0)
lua/parley/chat_respond.lua:1611:                pending_session:tip_written(last_written_line_0)
lua/parley/chat_respond.lua:1666:        pending_session = chat_pending.start({
lua/parley/chat_respond.lua:1840:                        end, after_write = function()
tests/unit/exchange_model_spec.lua:39:        assert.equals(11, m:last_nonempty_block_end(1))
tests/unit/exchange_model_spec.lua:47:        assert.equals(5, m:last_nonempty_block_end(1))
tests/unit/exchange_model_spec.lua:55:        assert.is_nil(m:last_nonempty_block_end(1))
lua/parley/exchange_model.lua:176:function Model:last_nonempty_block_end(k)
lua/parley/exchange_model.lua:190:    local last_end = self:last_nonempty_block_end(k)
tests/integration/create_handler_spec.lua:272:            after_write = function(qid, chunk, delta, last_written_line_0)
M	atlas/chat/exchange_model.md
M	atlas/chat/lifecycle.md
M	atlas/chat/response_progress.md
M	atlas/traceability.yaml
M	workshop/issues/000183-keep-response-progress-at-current-generation-tip.md

exec
/bin/zsh -lc 'make -f Makefile.local test-spec SPEC=chat/response_progress && make -f Makefile.local test-spec SPEC=chat/exchange_model' in /Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip
 exited 2 in 5164ms:
[32mSuccess[0m	||	chat pending extmark adapter animates only the glyph and rotates verbs on activity and idle	
[32mSuccess[0m	||	chat pending extmark adapter repaints at the extmark's tracked row after text moves the anchor	
[32mSuccess[0m	||	chat pending extmark adapter uses a hidden tip update for the first reveal	
[32mSuccess[0m	||	chat pending extmark adapter repairs invalidating writes synchronously without changing lifecycle state	
[32mSuccess[0m	||	chat pending extmark adapter stages content until the minimum and flushes it in FIFO order	
[32mSuccess[0m	||	chat pending extmark adapter cancels every playful timer when fast content releases waiting	
[32mSuccess[0m	||	chat pending extmark adapter keeps fast semantic status but cancels every playful timer	
[32mSuccess[0m	||	chat pending extmark adapter renders semantic status in the same extmark while content streams	
[32mSuccess[0m	||	chat pending extmark adapter hides without changing real lines or the undo sequence	
[32mSuccess[0m	||	chat pending extmark adapter completes after the minimum and invokes the continuation once	
[32mSuccess[0m	||	chat pending extmark adapter contains emitter failures without logging callback data	
[32mSuccess[0m	||	chat pending extmark adapter surfaces owned failures after staged partial output	
[32mSuccess[0m	||	chat pending extmark adapter hides released semantic status before surfacing failure	
[32mSuccess[0m	||	chat pending extmark adapter cancels stale leases and deleted buffers with every timer	
[32mSuccess[0m	||	chat pending extmark adapter invokes discard hooks once for cancel, frame-stale, and buffer-invalid	
[32mSuccess[0m	||	chat pending extmark adapter releases ownership before a reentrant discard hook	
[32mSuccess[0m	||	chat pending extmark adapter contains and redacts throwing discard hooks	
[32mSuccess[0m	||	chat pending extmark adapter does not invoke discard hooks for completion or provider failure	
[32mSuccess[0m	||	chat pending extmark adapter frame ticks terminate a shown session whose lease became stale	
[32mSuccess[0m	||	chat pending extmark adapter enforces one active session per buffer and cancel_all is idempotent	
[32mSuccess[0m	||	chat pending extmark adapter does not publish sessions whose initializer fails	
[32mSuccess[0m	||	chat pending extmark adapter uses the production scheduler to leave a real uv fast event	
	
[32mSuccess: [0m	24	
[31mFailed : [0m	0	
[31mErrors : [0m	0	
========================================	
Running tests/integration/chat_progress_process_spec.lua
Scheduling: tests/integration/chat_progress_process_spec.lua

========================================	
Testing: 	/Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip/tests/integration/chat_progress_process_spec.lua	
[31mFail[0m	||	chat progress real curl process stages a delayed SSE answer behind the minimum-visible playful line	
            ...ion-tip/tests/integration/chat_progress_process_spec.lua:45: (number) -1
            Expected objects to be the same.
            Passed in:
            (boolean) false
            Expected:
            (boolean) true
            
            stack traceback:
            	...ion-tip/tests/integration/chat_progress_process_spec.lua:45: in function 'start_server'
            	...ion-tip/tests/integration/chat_progress_process_spec.lua:151: in function 'run'
            	...ion-tip/tests/integration/chat_progress_process_spec.lua:159: in function <...ion-tip/tests/integration/chat_progress_process_spec.lua:158>
            	
[31mFail[0m	||	chat progress real curl process orders partial output before the broken provider failure	
            ...ion-tip/tests/integration/chat_progress_process_spec.lua:45: (number) -1
            Expected objects to be the same.
            Passed in:
            (boolean) false
            Expected:
            (boolean) true
            
            stack traceback:
            	...ion-tip/tests/integration/chat_progress_process_spec.lua:45: in function 'start_server'
            	...ion-tip/tests/integration/chat_progress_process_spec.lua:151: in function 'run'
            	...ion-tip/tests/integration/chat_progress_process_spec.lua:178: in function <...ion-tip/tests/integration/chat_progress_process_spec.lua:177>
            	
[31mFail[0m	||	chat progress real curl process orders partial output before the unauthorized provider failure	
            ...ion-tip/tests/integration/chat_progress_process_spec.lua:45: (number) -1
            Expected objects to be the same.
            Passed in:
            (boolean) false
            Expected:
            (boolean) true
            
            stack traceback:
            	...ion-tip/tests/integration/chat_progress_process_spec.lua:45: in function 'start_server'
            	...ion-tip/tests/integration/chat_progress_process_spec.lua:151: in function 'run'
            	...ion-tip/tests/integration/chat_progress_process_spec.lua:178: in function <...ion-tip/tests/integration/chat_progress_process_spec.lua:177>
            	
[31mFail[0m	||	chat progress real curl process orders partial output before the http500 provider failure	
            ...ion-tip/tests/integration/chat_progress_process_spec.lua:45: (number) -1
            Expected objects to be the same.
            Passed in:
            (boolean) false
            Expected:
            (boolean) true
            
            stack traceback:
            	...ion-tip/tests/integration/chat_progress_process_spec.lua:45: in function 'start_server'
            	...ion-tip/tests/integration/chat_progress_process_spec.lua:151: in function 'run'
            	...ion-tip/tests/integration/chat_progress_process_spec.lua:178: in function <...ion-tip/tests/integration/chat_progress_process_spec.lua:177>
            	
[32mSuccess[0m	||	chat progress real curl process cleans one real chat session when the provider secret is missing	
[32mSuccess[0m	||	chat progress real curl process cleans one real chat session when task launch is rejected as busy	
[32mSuccess[0m	||	chat progress real curl process cleans one real chat session when curl spawn is rejected	
	
[32mSuccess: [0m	3	
[31mFailed : [0m	4	
[31mErrors : [0m	0	
========================================	
Tests Failed. Exit: 1	
make: *** [test-spec] Error 1

exec
/bin/zsh -lc "make -f Makefile.local test-spec SPEC=chat/exchange_model; sed -n '1,70p' tests/integration/chat_progress_process_spec.lua; git show e3ed1e032140143b1c92dbf1ffe3a9bf7e54c793:lua/parley/chat_pending.lua | sed -n '120,430p' > /tmp/base_chat_pending_review.lua; nl -ba lua/parley/chat_pending.lua | sed -n '130,425p'; nl -ba lua/parley/chat_respond.lua | sed -n '1450,1680p'; nl -ba lua/parley/dispatcher.lua | sed -n '540,600p'; nl -ba workshop/issues/000183-keep-response-progress-at-current-generation-tip.md | sed -n '1,230p'" in /Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip
 succeeded in 863ms:
Running tests/unit/buffer_edit_spec.lua
Scheduling: tests/unit/buffer_edit_spec.lua

========================================	
Testing: 	/Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip/tests/unit/buffer_edit_spec.lua	
[32mSuccess[0m	||	buffer_edit.PosHandle make_handle / handle_line returns the line	
[32mSuccess[0m	||	buffer_edit.PosHandle handle position drifts naturally with extmark gravity	
[32mSuccess[0m	||	buffer_edit.PosHandle handle_invalidate marks the handle dead and disables operations	
[32mSuccess[0m	||	buffer_edit.topic header ops set_topic_header_line replaces a single line	
[32mSuccess[0m	||	buffer_edit.topic header ops insert_topic_line inserts after the given 0-indexed line	
[32mSuccess[0m	||	buffer_edit.pad_question_with_blank inserts a blank line right after the given 0-indexed line	
[32mSuccess[0m	||	buffer_edit.create_answer_region inserts blank + agent header + blank after the given line, returns handle at write position	
[32mSuccess[0m	||	buffer_edit.create_answer_region supports an agent suffix	
[32mSuccess[0m	||	buffer_edit.delete_answer deletes the answer region (inclusive line range)	
[32mSuccess[0m	||	buffer_edit.replace_answer deletes the answer region and inserts a single blank separator, returns handle at the blank	
[32mSuccess[0m	||	buffer_edit.streaming stream_into writes a chunk with a single newline	
[32mSuccess[0m	||	buffer_edit.streaming stream_into accumulates pending text across chunks	
[32mSuccess[0m	||	buffer_edit.streaming stream_into handles multi-line chunks	
[32mSuccess[0m	||	buffer_edit.streaming stream_finalize invalidates the handle	
[32mSuccess[0m	||	buffer_edit.cancellation cleanup delete_lines_after deletes n lines starting at line_0_indexed	
[32mSuccess[0m	||	buffer_edit.cancellation cleanup append_blank_at_end adds a blank to the end of the buffer	
[32mSuccess[0m	||	buffer_edit.append_section_to_answer appends a rendered text section after a non-empty line, with a blank separator	
[32mSuccess[0m	||	buffer_edit.append_section_to_answer appends a rendered text section after a blank line WITHOUT extra separator	
[32mSuccess[0m	||	buffer_edit.append_section_to_answer appends a tool_use section	
	
[32mSuccess: [0m	19	
[31mFailed : [0m	0	
[31mErrors : [0m	0	
========================================	
Running tests/unit/exchange_model_spec.lua
Scheduling: tests/unit/exchange_model_spec.lua

========================================	
Testing: 	/Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip/tests/unit/exchange_model_spec.lua	
[32mSuccess[0m	||	exchange_model: basic construction creates an empty model with header_lines	
[32mSuccess[0m	||	exchange_model: single exchange, question only exchange_start is header_lines + margin	
[32mSuccess[0m	||	exchange_model: single exchange, question only append_pos for question-only exchange is after question + margin	
[32mSuccess[0m	||	exchange_model: single exchange with blocks reports the last non-empty block end through trailing empty blocks	
[32mSuccess[0m	||	exchange_model: single exchange with blocks reports the only non-empty block end	
[32mSuccess[0m	||	exchange_model: single exchange with blocks returns nil when an exchange has no non-empty blocks	
[32mSuccess[0m	||	exchange_model: single exchange with blocks agent_header block starts after question + margin	
[32mSuccess[0m	||	exchange_model: single exchange with blocks text block starts after agent_header + margin	
[32mSuccess[0m	||	exchange_model: single exchange with blocks block_end returns the last line of a block	
[32mSuccess[0m	||	exchange_model: single exchange with blocks tool_use block after text includes margin	
[32mSuccess[0m	||	exchange_model: single exchange with blocks append_pos advances after adding blocks	
[32mSuccess[0m	||	exchange_model: single exchange with blocks grow_block updates the size and shifts subsequent positions	
[32mSuccess[0m	||	exchange_model: single exchange with blocks grow_question shifts all subsequent positions	
[32mSuccess[0m	||	exchange_model: empty block cancellation empty block is invisible — doesn't add margins	
[32mSuccess[0m	||	exchange_model: empty block cancellation setting block size to 0 makes it invisible	
[32mSuccess[0m	||	exchange_model: empty block cancellation exchange_total_size skips empty blocks	
[32mSuccess[0m	||	exchange_model: two exchanges second exchange starts after first + margin	
[32mSuccess[0m	||	exchange_model: two exchanges tool blocks in exchange 1 shift exchange 2	
[32mSuccess[0m	||	exchange_model: from_parsed_chat loads exchange structure from parser output	
[32mSuccess[0m	||	exchange_model: from_parsed_chat with real parser positions match buffer lines for simple Q+A	
[32mSuccess[0m	||	exchange_model: from_parsed_chat with real parser positions match buffer lines with thinking + tool blocks	
[32mSuccess[0m	||	exchange_model: from_parsed_chat with real parser parser trims trailing blanks from question	
[32mSuccess[0m	||	exchange_model: from_parsed_chat with real parser parser trims trailing blanks from answer sections	
	
[32mSuccess: [0m	23	
[31mFailed : [0m	0	
[31mErrors : [0m	0	
========================================	
Running tests/unit/render_buffer_roundtrip_spec.lua
Scheduling: tests/unit/render_buffer_roundtrip_spec.lua

========================================	
Testing: 	/Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip/tests/unit/render_buffer_roundtrip_spec.lua	
[32mSuccess[0m	||	render_buffer.positions agrees with parser-recorded spans single-user parses and projects consistently	
[32mSuccess[0m	||	render_buffer.positions agrees with parser-recorded spans simple-chat parses and projects consistently	
[32mSuccess[0m	||	render_buffer.positions agrees with parser-recorded spans one-round-tool-use parses and projects consistently	
[32mSuccess[0m	||	render_buffer.positions agrees with parser-recorded spans two-round-tool-use parses and projects consistently	
[32mSuccess[0m	||	render_buffer.positions agrees with parser-recorded spans mixed-text-and-tools parses and projects consistently	
[32mSuccess[0m	||	render_buffer.positions agrees with parser-recorded spans tool-error parses and projects consistently	
[32mSuccess[0m	||	render_buffer.positions agrees with parser-recorded spans dynamic-fence-stress parses and projects consistently	
[32mSuccess[0m	||	render_buffer.agent_header_lines returns blank-prefix-blank pattern	
[32mSuccess[0m	||	render_buffer.agent_header_lines appends suffix when provided	
[32mSuccess[0m	||	render_buffer.agent_header_lines handles nil prefix/suffix	
[32mSuccess[0m	||	render_buffer.raw_request_fence_lines emits a typed json fence around the payload	
	
[32mSuccess: [0m	11	
[31mFailed : [0m	0	
[31mErrors : [0m	0	
========================================	
Running tests/unit/render_buffer_spec.lua
Scheduling: tests/unit/render_buffer_spec.lua

========================================	
Testing: 	/Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip/tests/unit/render_buffer_spec.lua	
[32mSuccess[0m	||	render_buffer.render_section renders a text section as its lines	
[32mSuccess[0m	||	render_buffer.render_section renders a single-line text section	
[32mSuccess[0m	||	render_buffer.render_section renders an empty text section as a single empty line	
[32mSuccess[0m	||	render_buffer.render_section renders a tool_use section using serialize.render_call	
[32mSuccess[0m	||	render_buffer.render_section renders a tool_result section using serialize.render_result	
[32mSuccess[0m	||	render_buffer.render_section renders an error tool_result	
[32mSuccess[0m	||	render_buffer.render_section raises on unknown kind	
[32mSuccess[0m	||	render_buffer.render_exchange renders a question + simple text answer	
[32mSuccess[0m	||	render_buffer.render_exchange renders an exchange with no answer (just the question)	
[32mSuccess[0m	||	render_buffer.render_exchange renders mixed text + tool_use + tool_result + text	
	
[32mSuccess: [0m	10	
[31mFailed : [0m	0	
[31mErrors : [0m	0	
========================================	
local tmp_dir = vim.fn.tempname() .. "-parley-progress-process"
vim.fn.mkdir(tmp_dir, "p")

local parley = require("parley")
parley.setup({
    chat_dir = tmp_dir,
    state_dir = tmp_dir .. "/state",
    web_search = false,
    default_agent = "ProcessFixture",
    providers = {
        openai = { endpoint = "http://127.0.0.1:1/v1/chat/completions" },
    },
    api_keys = { openai = "fixture-secret" },
    agents = {
        {
            name = "ProcessFixture",
            provider = "openai",
            model = { model = "fixture-model" },
            system_prompt = "Answer briefly.",
        },
    },
})

local fixture = vim.fn.getcwd() .. "/tests/fixtures/fake_sse_server"
local uv = vim.uv or vim.loop
local processes = {}

local function start_server(mode)
    local ready_file = tmp_dir .. "/ready-" .. mode .. "-" .. math.random(100000)
    local exited = false
    local handle
    local env = {}
    for name, value in pairs(vim.fn.environ()) do
        table.insert(env, name .. "=" .. value)
    end
    table.insert(env, "PYTHONDONTWRITEBYTECODE=1")
    handle = uv.spawn(fixture, { args = { mode, ready_file }, env = env }, function()
        exited = true
        if handle and not handle:is_closing() then
            handle:close()
        end
    end)
    assert.is_not_nil(handle)
    table.insert(processes, { handle = handle, exited = function() return exited end })
    assert.is_true(vim.wait(1000, function() return vim.fn.filereadable(ready_file) == 1 end, 10))
    local port = tonumber(vim.fn.readfile(ready_file)[1])
    vim.fn.delete(ready_file)
    return port
end

local function open_chat(mode)
    local path = tmp_dir .. "/2026-07-13-process-" .. mode .. "-" .. math.random(100000) .. ".md"
    vim.fn.writefile({
        "# topic: Fixture",
        "- file: fixture.md",
        "---",
        "",
        "💬: test the process boundary",
    }, path)
    vim.cmd("edit " .. vim.fn.fnameescape(path))
    vim.api.nvim_win_set_cursor(0, { 5, 0 })
    return vim.api.nvim_get_current_buf()
end

local function text(buf)
    if not vim.api.nvim_buf_is_valid(buf) then return "" end
    return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end

local function pending_marks(buf)
   130	                if #position >= 2 and not (position[3] and position[3].invalid) then
   131	                    session.last_mark_row = position[1]
   132	                    session.last_mark_col = position[2]
   133	                end
   134	            end
   135	            pcall(vim.api.nvim_buf_del_extmark, session.buf, namespace, session.extmark_id)
   136	            session.extmark_hidden = true
   137	        end
   138	        session.visible_text = nil
   139	        session.playful_verb = nil
   140	    end
   141	
   142	    local function set_mark(text, row, col)
   143	        local ok, mark_id = pcall(vim.api.nvim_buf_set_extmark, session.buf, namespace,
   144	            row, col, {
   145	                id = session.extmark_id,
   146	                virt_lines = { { { text, "Comment" } } },
   147	                virt_lines_above = false,
   148	                invalidate = true,
   149	            })
   150	        if not ok then
   151	            return false
   152	        end
   153	        session.extmark_id = mark_id
   154	        session.extmark_hidden = false
   155	        session.last_mark_row = row
   156	        session.last_mark_col = col
   157	        session.visible_text = text
   158	        return true
   159	    end
   160	
   161	    local function render(text)
   162	        if not vim.api.nvim_buf_is_valid(session.buf) then
   163	            return false
   164	        end
   165	        local row = session.anchor_line
   166	        local col = 0
   167	        if session.extmark_id then
   168	            local position = vim.api.nvim_buf_get_extmark_by_id(
   169	                session.buf, namespace, session.extmark_id, { details = true })
   170	            if #position >= 2 and not (position[3] and position[3].invalid) then
   171	                row = position[1]
   172	                col = position[2]
   173	            elseif session.extmark_hidden and session.last_mark_row then
   174	                row = session.last_mark_row
   175	                col = session.last_mark_col
   176	            else
   177	                return false
   178	            end
   179	        end
   180	        return set_mark(text, row, col)
   181	    end
   182	
   183	    local function render_playful()
   184	        return render(spinner[session.frame_index] .. " " .. session.playful_verb)
   185	    end
   186	
   187	    local function finish()
   188	        if session.finished then
   189	            return
   190	        end
   191	        session.finished = true
   192	        cancel_timers()
   193	        hide()
   194	        if active_by_buf[session.buf] == session then
   195	            active_by_buf[session.buf] = nil
   196	        end
   197	    end
   198	
   199	    local dispatch
   200	
   201	    local function enqueue_timer_event(event_factory)
   202	        scheduler.enqueue(function()
   203	            if session.finished then
   204	                return
   205	            end
   206	            if not vim.api.nvim_buf_is_valid(session.buf) then
   207	                dispatch({ type = "invalid" })
   208	                return
   209	            end
   210	            dispatch(event_factory())
   211	        end)
   212	    end
   213	
   214	    local function schedule_after(name, delay_ms, event_factory)
   215	        cancel_timer(name)
   216	        session.timers[name] = scheduler.after(delay_ms, function()
   217	            enqueue_timer_event(event_factory)
   218	        end)
   219	    end
   220	
   221	    local function start_frame_timer()
   222	        if session.timers.frame then
   223	            return
   224	        end
   225	        session.timers.frame = scheduler.every(120, function()
   226	            scheduler.enqueue(function()
   227	                if session.finished then
   228	                    return
   229	                end
   230	                if not vim.api.nvim_buf_is_valid(session.buf) then
   231	                    dispatch({ type = "invalid" })
   232	                    return
   233	                end
   234	                local ok, valid = pcall(session.lease_valid)
   235	                if not ok or not valid then
   236	                    dispatch({ type = "stale" })
   237	                    return
   238	                end
   239	                if session.playful_verb then
   240	                    session.frame_index = session.frame_index % #spinner + 1
   241	                    if not render_playful() then
   242	                        dispatch({ type = "invalid" })
   243	                    end
   244	                end
   245	            end)
   246	        end)
   247	    end
   248	
   249	    local function reset_idle_timer()
   250	        schedule_after("idle", 15000, function()
   251	            return {
   252	                type = "idle",
   253	                now_ms = now_ms(),
   254	                verb_index = session.choose_verb_index(#verbs),
   255	            }
   256	        end)
   257	    end
   258	
   259	    local function rearm_early_timer(event, state)
   260	        local deadline
   261	        local name
   262	        local event_factory
   263	        if event.type == "reveal_due" and state.phase == "waiting" then
   264	            deadline = state.reveal_at
   265	            name = "reveal"
   266	            event_factory = function()
   267	                return { type = "reveal_due", now_ms = now_ms() }
   268	            end
   269	        elseif event.type == "minimum_due" and state.phase == "showing" then
   270	            deadline = state.minimum_at
   271	            name = "minimum"
   272	            event_factory = function()
   273	                return { type = "minimum_due", now_ms = now_ms() }
   274	            end
   275	        elseif event.type == "idle"
   276	                and (state.phase == "waiting" or state.phase == "showing") then
   277	            deadline = state.verb_due_at
   278	            name = "idle"
   279	            event_factory = function()
   280	                return {
   281	                    type = "idle",
   282	                    now_ms = now_ms(),
   283	                    verb_index = session.choose_verb_index(#verbs),
   284	                }
   285	            end
   286	        end
   287	        if deadline and event.now_ms < deadline then
   288	            schedule_after(name, math.max(1, math.ceil(deadline - event.now_ms)), event_factory)
   289	            return true
   290	        end
   291	        return false
   292	    end
   293	
   294	    local function apply_actions(actions, context)
   295	        for _, action in ipairs(actions) do
   296	            if action.type == "show_playful" then
   297	                session.playful_verb = action.verb
   298	                if not render_playful() then
   299	                    finish()
   300	                    return
   301	                end
   302	                start_frame_timer()
   303	            elseif action.type == "render_status" then
   304	                session.playful_verb = nil
   305	                cancel_timer("frame")
   306	                if not render(action.message) then
   307	                    finish()
   308	                    return
   309	                end
   310	            elseif action.type == "emit_content" then
   311	                call_safely("content emitter", session.emit_content, action.qid, action.chunk)
   312	            elseif action.type == "hide" then
   313	                hide()
   314	            elseif action.type == "continue_completion" then
   315	                hide()
   316	                call_safely("completion", action.completion)
   317	            elseif action.type == "surface_failure" then
   318	                hide()
   319	                call_safely("failure surface", context and context.surface_failure, action.error)
   320	            end
   321	        end
   322	    end
   323	
   324	    dispatch = function(event, context)
   325	        if session.finished then
   326	            return
   327	        end
   328	        if event.type ~= "cancel" and event.type ~= "invalid" then
   329	            local ok, valid = pcall(session.lease_valid)
   330	            if not ok or not valid then
   331	                event = { type = "stale" }
   332	            end
   333	        end
   334	        local previous_phase = session.state.phase
   335	        local next_state, actions = presentation.transition(session.state, event)
   336	        session.state = next_state
   337	        if next_state.phase == "finished" then
   338	            -- Release registry/timer ownership before a continuation starts a
   339	            -- recursive LLM leg in this buffer.
   340	            finish()
   341	            if event.type == "cancel" or event.type == "stale" or event.type == "invalid" then
   342	                call_safely("discard terminal", session.on_discard, event.type, event.reason)
   343	            end
   344	            apply_actions(actions, context)
   345	            return
   346	        end
   347	        apply_actions(actions, context)
   348	
   349	        if session.finished then
   350	            return
   351	        end
   352	        if rearm_early_timer(event, next_state) then
   353	            return
   354	        end
   355	        if previous_phase == "waiting" and next_state.phase ~= "waiting" then
   356	            cancel_timer("reveal")
   357	            if next_state.phase == "released" then
   358	                cancel_timer("idle")
   359	            end
   360	        end
   361	        if next_state.phase == "showing" and previous_phase ~= "showing" then
   362	            schedule_after("minimum", 1000, function()
   363	                return { type = "minimum_due", now_ms = now_ms() }
   364	            end)
   365	        end
   366	        if previous_phase == "showing" and next_state.phase ~= "showing" then
   367	            cancel_timer("minimum")
   368	            cancel_timer("frame")
   369	            cancel_timer("idle")
   370	        elseif (event.type == "activity" or event.type == "idle")
   371	                and (next_state.phase == "waiting" or next_state.phase == "showing") then
   372	            reset_idle_timer()
   373	        end
   374	    end
   375	
   376	    local function submit(event_factory, context)
   377	        scheduler.enqueue(function()
   378	            if session.finished then
   379	                return
   380	            end
   381	            if not vim.api.nvim_buf_is_valid(session.buf) then
   382	                dispatch({ type = "invalid" })
   383	                return
   384	            end
   385	            dispatch(event_factory(), context)
   386	        end)
   387	    end
   388	
   389	    -- Called synchronously from dispatcher.create_handler's scheduled writer.
   390	    -- The pending stream line may have just invalidated this extmark; repaint it
   391	    -- before the writer yields so queued frame/progress work never sees a gap.
   392	    session.tip_written = function(_self, last_written_line_0)
   393	        if session.finished or type(last_written_line_0) ~= "number"
   394	                or not vim.api.nvim_buf_is_valid(session.buf) then
   395	            return
   396	        end
   397	        session.anchor_line = last_written_line_0
   398	        session.last_mark_row = last_written_line_0
   399	        session.last_mark_col = 0
   400	        if not session.visible_text then
   401	            return
   402	        end
   403	        if not set_mark(session.visible_text, last_written_line_0, 0) then
   404	            dispatch({ type = "invalid" })
   405	        end
   406	    end
   407	
   408	    session.activity = function(_self, _qid)
   409	        submit(function()
   410	            return {
   411	                type = "activity",
   412	                now_ms = now_ms(),
   413	                verb_index = session.choose_verb_index(#verbs),
   414	            }
   415	        end)
   416	    end
   417	
   418	    session.content = function(_self, qid, chunk)
   419	        submit(function()
   420	            return { type = "content", now_ms = now_ms(), qid = qid, chunk = chunk }
   421	        end)
   422	    end
   423	
   424	    session.progress = function(_self, _qid, event)
   425	        submit(function()
  1450	            model = exchange_model.from_parsed_chat(parsed_chat)
  1451	            target_idx = exchange_idx or #model.exchanges
  1452	        end
  1453	
  1454	        -- Compute response_start_line using the model.
  1455	        --
  1456	        -- Every visible element is a block in the model. The model
  1457	        -- handles margins between non-empty blocks automatically.
  1458	        -- We just add blocks and ask for positions.
  1459	        --
  1460	        -- Every visible element is a block in the model. The model
  1461	        -- handles margins between non-empty blocks automatically.
  1462	        -- We add blocks to the model, then insert the corresponding
  1463	        -- lines (margin + content) into the buffer.
  1464	        --
  1465	        local stream_block_idx
  1466	        local initial_progress_tip
  1467	        if is_recursion then
  1468	            -- Recursion: append streaming placeholder after existing blocks.
  1469	            initial_progress_tip = assert(model:last_nonempty_block_end(target_idx),
  1470	                "recursive response requires existing visible content")
  1471	            model:add_block(target_idx, "stream_placeholder", 1)
  1472	            stream_block_idx = #model.exchanges[target_idx].blocks
  1473	            local pos = model:block_start(target_idx, stream_block_idx)
  1474	            buffer_edit.insert_lines_at(buf, pos - 1, { "", "" })  -- margin + blank content
  1475	        else
  1476	            -- Fresh answer: add agent_header + streaming placeholder. Pending
  1477	            -- presentation is an extmark and never enters the exchange model.
  1478	            model:add_block(target_idx, "agent_header", 1)
  1479	            model:add_block(target_idx, "stream_placeholder", 1)
  1480	            stream_block_idx = #model.exchanges[target_idx].blocks
  1481	            initial_progress_tip = model:block_start(target_idx, 2)
  1482	
  1483	            -- Before inserting, clean up any trailing blank lines after
  1484	            -- the question in the buffer. The model's margin will be the
  1485	            -- only blank between question and agent_header.
  1486	            local agent_blk_idx = 2  -- block 1 is question, block 2 is agent_header
  1487	            local insert_start = model:block_start(target_idx, agent_blk_idx) - 1  -- -1 for margin
  1488	            -- Clean up excess blank lines at the insert point. Keep
  1489	            -- exactly 1 blank if there's a following exchange (the
  1490	            -- inter-exchange margin). Delete all blanks only if this
  1491	            -- is the last exchange.
  1492	            local buf_line_count = vim.api.nvim_buf_line_count(buf)
  1493	            if insert_start < buf_line_count then
  1494	                local blank_count = 0
  1495	                local check_lines = vim.api.nvim_buf_get_lines(buf, insert_start, buf_line_count, false)
  1496	                for _, l in ipairs(check_lines) do
  1497	                    if not l:match("%S") then
  1498	                        blank_count = blank_count + 1
  1499	                    else
  1500	                        break
  1501	                    end
  1502	                end
  1503	                -- If there's content after the blanks (next exchange),
  1504	                -- keep 1 blank as the inter-exchange margin.
  1505	                local has_next = (insert_start + blank_count) < buf_line_count
  1506	                local keep = has_next and 1 or 0
  1507	                local to_delete = blank_count - keep
  1508	                if to_delete > 0 then
  1509	                    buffer_edit.delete_lines_after(buf, insert_start, to_delete)
  1510	                end
  1511	            end
  1512	            local insert_lines = { "", agent_prefix .. agent_suffix }
  1513	            table.insert(insert_lines, "")  -- margin before stream_placeholder
  1514	            table.insert(insert_lines, "")  -- stream_placeholder content (blank)
  1515	            buffer_edit.insert_lines_at(buf, insert_start, insert_lines)
  1516	        end
  1517	
  1518	        -- #138: anchor the lease on the agent-header (`🤖:`) line — block 2 of the
  1519	        -- exchange (block 1 is the question; same index in fresh + recursion paths). It's the
  1520	        -- structural marker for the response: streaming operates below it, so ordinary writes
  1521	        -- leave it untouched, while undo/redo of the inserted response (or the
  1522	        -- user deleting the `🤖:` line) removes it and invalidates the lease.
  1523	        -- Anchoring on the stream line itself fails: stream_replace_at_line
  1524	        -- set_lines-replaces that line every chunk, which trips `invalidate`.
  1525	        local lease_generation = chat_lease.begin(buf, model:block_start(target_idx, 2), {
  1526	            target_idx = target_idx,
  1527	            stream_block_idx = stream_block_idx,
  1528	            recursion = is_recursion,
  1529	        })
  1530	        -- Every dispatched API leg has already inserted its response shell.
  1531	        -- Finalization is guarded so normal, recursive, and abort terminals all
  1532	        -- converge exactly once, after their last transcript mutation.
  1533	        local api_leg_mutated = true
  1534	        local api_leg_finalized = false
  1535	        local function finalize_mutated_api_leg()
  1536	            if api_leg_finalized then
  1537	                return
  1538	            end
  1539	            api_leg_finalized = true
  1540	            require("parley.buffer_lifecycle").finalize_mutated_api_leg(buf, api_leg_mutated)
  1541	        end
  1542	        local lease_notice_sent = false
  1543	        local pending_session
  1544	        local function invalidate_pending_request(lease_reason)
  1545	            if not lease_notice_sent then
  1546	                lease_notice_sent = true
  1547	                _parley.logger.warning(lease_reason or "Parley request cancelled because the chat transcript changed")
  1548	                vim.notify(lease_reason or "Parley request cancelled because the chat transcript changed", vim.log.levels.WARN)
  1549	            end
  1550	            if pending_session then
  1551	                pending_session:cancel("stale")
  1552	            end
  1553	            pcall(function()
  1554	                _parley.tasker.stop()
  1555	            end)
  1556	        end
  1557	        local function lease_valid()
  1558	            local ok, lease_reason = chat_lease.validate(buf, lease_generation, buf_changedtick(buf))
  1559	            if not ok then
  1560	                invalidate_pending_request(lease_reason)
  1561	                return false
  1562	            end
  1563	            return true
  1564	        end
  1565	        local function lease_commit()
  1566	            chat_lease.commit(buf, lease_generation, buf_changedtick(buf))
  1567	        end
  1568	        local function guarded_write(fn)
  1569	            if not lease_valid() then
  1570	                return false
  1571	            end
  1572	            fn()
  1573	            lease_commit()
  1574	            return true
  1575	        end
  1576	
  1577	        _parley.logger.debug("messages to send: " .. vim.inspect(messages))
  1578	
  1579	        -- Check if we're in raw request mode and have a raw payload to use
  1580	        local raw_payload = nil
  1581	        if
  1582	            exchange_idx
  1583	            and parsed_chat.exchanges[exchange_idx].question
  1584	            and parsed_chat.exchanges[exchange_idx].question.raw_payload
  1585	        then
  1586	            raw_payload = parsed_chat.exchanges[exchange_idx].question.raw_payload
  1587	            _parley.logger.debug("Using raw payload for request: " .. vim.inspect(raw_payload))
  1588	        end
  1589	
  1590	        -- Compute payload once for both display and query.
  1591	        -- agent_info.tools (from M1 Task 1.4) is passed as the 4th arg so
  1592	        -- tool-enabled agents get their client-side tools appended to the
  1593	        -- payload. Vanilla agents have agent_info.tools = nil and stay
  1594	        -- byte-identical to pre-#81 behavior.
  1595	        local final_payload = raw_payload or _parley.dispatcher.prepare_payload(messages, agent_info.model, agent_info.provider, agent_info.tools)
  1596	
  1597	        -- Compute response_start_line from the model. This is always
  1598	        -- correct because any prior inserts (fence, etc.) updated the
  1599	        -- model via grow_question.
  1600	        local response_start_line = model:block_start(target_idx, stream_block_idx)
  1601	        local function on_stream_lines_changed(delta)
  1602	            model:grow_block(target_idx, stream_block_idx, delta)
  1603	        end
  1604	        local base_handler = _parley.dispatcher.create_handler(buf, win, response_start_line, true, "", function()
  1605	            return is_follow_cursor_enabled(override_free_cursor)
  1606	        end, on_stream_lines_changed, {
  1607	            before_write = function(_qid, _chunk)
  1608	                return lease_valid()
  1609	            end,
  1610	            after_write = function(_qid, _chunk, _delta, last_written_line_0)
  1611	                pending_session:tip_written(last_written_line_0)
  1612	                lease_commit()
  1613	            end,
  1614	        })
  1615	        local response_handler = function(qid, chunk) pending_session:content(qid, chunk) end
  1616	
  1617	        -- Shared empty-answer collapse (#131): used by on_exit (tool-use-only /
  1618	        -- empty response) AND on_abort, so a failed managed-cliproxy start tears
  1619	        -- down the same inserted stream placeholder instead of leaving it.
  1620	        local function collapse_empty_answer()
  1621	            if not stream_block_idx then
  1622	                return
  1623	            end
  1624	            local sblk = model.exchanges[target_idx].blocks[stream_block_idx]
  1625	            if sblk and sblk.size == 1 then
  1626	                local spos = model:block_start(target_idx, stream_block_idx)
  1627	                local sline = vim.api.nvim_buf_get_lines(buf, spos, spos + 1, false)[1] or ""
  1628	                if not sline:match("%S") then
  1629	                    -- Just a blank — remove it + its margin, set size 0 (the
  1630	                    -- empty-block rule cancels the margin).
  1631	                    local del_start = math.max(spos - 1, 0)
  1632	                    local del_count = spos - del_start + 1
  1633	                    if not guarded_write(function()
  1634	                        buffer_edit.delete_lines_after(buf, del_start, del_count)
  1635	                    end) then
  1636	                        return
  1637	                    end
  1638	                    model:set_block_size(target_idx, stream_block_idx, 0)
  1639	                end
  1640	            end
  1641	        end
  1642	
  1643	        local leg_teardown_done = false
  1644	        local discard_notice
  1645	        local function teardown_chat_leg(notice)
  1646	            if leg_teardown_done then return end
  1647	            leg_teardown_done = true
  1648	            local owns_shell = false
  1649	            if vim.api.nvim_buf_is_valid(buf) then
  1650	                owns_shell = chat_lease.validate(buf, lease_generation, buf_changedtick(buf)) == true
  1651	            end
  1652	            if owns_shell then collapse_empty_answer() end
  1653	            finalize_mutated_api_leg()
  1654	            chat_lease.clear(buf, lease_generation)
  1655	            if notice then vim.notify(notice, vim.log.levels.WARN) end
  1656	        end
  1657	
  1658	        -- Abort teardown (#131): the dispatcher invokes this (qid-free) when the
  1659	        -- managed cliproxy can't be started, so the request fails fast and the
  1660	        -- response shell is torn down exactly once.
  1661	        local function on_abort(msg)
  1662	            discard_notice = msg or "parley: request aborted"
  1663	            pending_session:cancel("abort")
  1664	        end
  1665	
  1666	        pending_session = chat_pending.start({
  1667	            buf = buf,
  1668	            anchor_line = initial_progress_tip,
  1669	            lease_valid = lease_valid,
  1670	            emit_content = base_handler,
  1671	            choose_verb_index = function(count) return math.random(count) end,
  1672	            on_discard = function()
  1673	                teardown_chat_leg(discard_notice)
  1674	            end,
  1675	        })
  1676	
  1677	        -- call the model and write response
  1678	        _parley.dispatcher.query(
  1679	            buf,
  1680	            agent_info.provider,
   540			if opts.before_write and not opts.before_write(qid, chunk) then
   541				return
   542			end
   543			-- undojoin takes previous change into account, so skip it for the first chunk
   544			if skip_first_undojoin then
   545				skip_first_undojoin = false
   546			else
   547				helpers.undojoin(buf)
   548			end
   549	
   550			first_line = vim.api.nvim_buf_get_extmark_by_id(buf, ns_id, ex_id, {})[1]
   551	
   552			local buffer_edit = require("parley.buffer_edit")
   553			local previous_pending_index = finished_lines
   554			local completed, new_pending
   555			local delta
   556			if has_started then
   557				completed, new_pending = split_pending_and_completed(pending_line .. chunk)
   558				table.insert(completed, new_pending)
   559				local replacement = with_prefix(completed)
   560				local start_line = first_line + finished_lines
   561				buffer_edit.stream_replace_at_line(buf, start_line, replacement)
   562				delta = #completed - 1
   563				finished_lines = finished_lines + delta
   564			else
   565				-- Strip leading newlines from the first chunk for consistent spacing across providers
   566				chunk = chunk:gsub("^\n+", "")
   567				completed, new_pending = split_pending_and_completed(chunk)
   568				table.insert(completed, new_pending)
   569				local replacement = with_prefix(completed)
   570				buffer_edit.stream_replace_at_line(buf, first_line, replacement)
   571				delta = #completed - 1
   572				finished_lines = delta
   573				has_started = true
   574			end
   575			if on_lines_changed and delta > 0 then
   576				on_lines_changed(delta)
   577			end
   578			local end_line = first_line + finished_lines + 1
   579			qt.first_line = first_line
   580			qt.last_line = end_line - 1
   581			if opts.after_write then
   582				opts.after_write(qid, chunk, delta, end_line - 1)
   583			end
   584			pending_line = new_pending
   585			helpers.undojoin(buf)
   586	
   587			for i = previous_pending_index, finished_lines do
   588				vim.api.nvim_buf_add_highlight(buf, qt.ns_id, hl_handler_group, first_line + i, 0, -1)
   589			end
   590	
   591			-- move cursor to the end of the response
   592			local should_move_cursor
   593			if type(cursor) == "function" then
   594				should_move_cursor = cursor()
   595			else
   596				should_move_cursor = cursor
   597			end
   598			if should_move_cursor then
   599				helpers.cursor_to_line(end_line, buf, win)
   600			end
     1	---
     2	id: 000183
     3	status: working
     4	deps: []
     5	github_issue:
     6	created: 2026-07-13
     7	updated: 2026-07-13
     8	estimate_hours: 2.02
     9	started: 2026-07-13T13:44:15-07:00
    10	---
    11	
    12	# Keep response progress at current generation tip
    13	
    14	## Problem
    15	
    16	The response-progress extmark introduced by #182 is anchored to the agent-header
    17	line for an entire LLM leg. That is correct only before a fresh answer emits any
    18	content. During streaming it leaves reasoning or remote-tool status behind at
    19	`🤖:`, and during a recursive tool loop it starts below `🤖:` instead of after
    20	the already-generated answer and tool/result blocks. The indicator therefore
    21	describes current work at a stale spatial location.
    22	
    23	## Spec
    24	
    25	- Treat the generation tip as a per-leg, moving presentation anchor. Before the
    26	  first visible content of a fresh answer, use the agent-header row, so delayed
    27	  playful progress still appears immediately below `🤖:`. Before adding a
    28	  recursive leg's new `stream_placeholder`, snapshot the end row of the model's
    29	  last non-empty block and use that row as the initial anchor; recursive playful
    30	  progress therefore starts after the answer/tool/result content already
    31	  generated by that response, never at the new blank placeholder.
    32	- Once a stream write lands, move any visible progress extmark below the last
    33	  line written by the streaming handler. Continue doing so after every stream
    34	  write. Semantic reasoning or remote-tool status therefore follows the current
    35	  generated text instead of remaining below the agent header.
    36	- Preserve #182's temporal policy unchanged: one-second silent reveal,
    37	  one-second minimum visibility, ordered staging, activity/idle verb rotation,
    38	  terminal handling, and Definition's separate immediate inline spinner.
    39	- Keep the response-header chat lease unchanged. The lease owns transcript
    40	  validity and must never move to the replaceable pending stream line. The
    41	  presentation mark may occupy that current line, but only under the atomic
    42	  relocation contract below because each chunk replaces and invalidates it.
    43	- Extend the streaming handler's existing seam to call
    44	  `after_write(qid, chunk, delta, last_written_line_0)` with
    45	  `last_written_line_0 = first_line + finished_lines`, computed after the buffer
    46	  mutation and `on_lines_changed` growth callback. This is the handler's own
    47	  extmark-adjusted position after edits above the response, so consumers do not
    48	  recompute from stale exchange-model coordinates (`ARCH-DRY`, `ARCH-PURPOSE`).
    49	- `chat_respond` must complete the tip relocation inside that same scheduled
    50	  stream-write callback before it yields; it must not add another scheduling
    51	  hop. If replacing the pending line invalidated visible progress, restore the
    52	  same extmark ID at `last_written_line_0` with identical text before any queued
    53	  progress/frame callback can inspect it. Unexpected invalidation outside this
    54	  acknowledged write retains #182's terminal behavior.
    55	- A tip update changes the adapter's current anchor and every cached/fallback
    56	  spatial row even when progress is hidden, so the next reveal uses the new tip.
    57	  When playful or semantic progress is visible, repaint the existing extmark at
    58	  the new tip without changing its ID, text, timer state, reducer phase, or
    59	  transcript content. Ignore late tip updates after the session finishes.
    60	- Keep all tip movement in the Neovim adapter/stream IO shell; the pure temporal
    61	  reducer has no spatial state and requires no change (`ARCH-PURE`).
    62	
    63	## Done when
    64	
    65	- Fresh delayed progress begins directly below `🤖:` before content exists.
    66	- Recursive delayed progress begins after the response's last existing visible
    67	  answer/tool/result block rather than below `🤖:`.
    68	- A visible reasoning or remote-tool status moves below each newly written
    69	  content tip and keeps the same presentation text and lifecycle state.
    70	- Edits above the response remain safe because the writer reports its tracked
    71	  position; cancellation, invalidation, staging, and Definition behavior remain
    72	  unchanged.
    73	- Real-buffer tests prove a hidden tip update controls the next reveal; visible
    74	  relocation preserves exact extmark ID/text; replacement plus synchronous
    75	  relocation cannot be overtaken by queued frame/progress work; insertion above
    76	  the response still yields the writer's tracked row; and relocation after
    77	  finish is a no-op.
    78	- Tip relocation leaves timers, minimum deadline, reducer phase, staging FIFO,
    79	  and exact-once terminal delivery unchanged.
    80	- Focused adapter/real-entry regressions, mapped chat tests, lint, and the full
    81	  repository suite pass.
    82	
    83	## Estimate
    84	
    85	```estimate
    86	model: estimate-logic-v3.1
    87	familiarity: 1.0
    88	item: issue-spec             design=0.75 impl=0.08
    89	item: lua-neovim             design=0.30 impl=0.40
    90	item: atlas-docs             design=0.05 impl=0.04
    91	item: milestone-review       design=0.10 impl=0.12
    92	design-buffer: 0.15
    93	total: 2.02
    94	```
    95	
    96	Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md`
    97	against `baseline-v3.1.md`. Method A only. The thoroughly reviewed behavioral
    98	spec discounts the remaining Lua design work; implementation values are the
    99	v3.1 AI-paired 40% values.
   100	
   101	## Plan
   102	
   103	- [x] Approve the durable implementation plan and calibrated estimate.
   104	- [x] Add failing adapter and real-entry regressions for fresh, recursive, and
   105	  streaming tip movement.
   106	- [x] Report the tracked last line from the stream writer and move visible
   107	  progress through the serialized chat adapter.
   108	- [x] Update the response-progress atlas and pass targeted/full verification.
   109	- [x] Close, publish, and merge through the SDLC gates.
   110	
   111	## Log
   112	
   113	### 2026-07-13
   114	
   115	Claimed the follow-up after confirming #182's adapter always receives the fixed
   116	agent-header row. The selected design keeps the structural chat lease on that
   117	durable header while deriving presentation movement from the streaming
   118	handler's own tracked line. A model-only resolver was rejected because ordinary
   119	buffer edits can move the handler extmark without updating model coordinates;
   120	anchoring directly to the stream placeholder was rejected because chunk writes
   121	replace and invalidate that line.
   122	
   123	### 2026-07-13 — spec review revision
   124	
   125	Fresh review found that a queued tip update could lose a race with the next
   126	frame/progress callback after `stream_replace_at_line` invalidated a mark on the
   127	mutable pending line. The spec now requires synchronous same-callback repair
   128	with the same extmark ID, defines the handler's exact tracked-row argument,
   129	pins recursive initial placement before the new placeholder exists, and makes
   130	hidden spatial fallback plus lifecycle-preservation tests explicit.
   131	
   132	### 2026-07-13 — plan review revision
   133	
   134	Fresh plan review required stronger proof at two boundaries: recursive initial
   135	placement now uses the canonical adapter and asserts the real virtual line, and
   136	the relocation suite now carries ordered staged output through invalidation and
   137	termination to prove FIFO plus exact-once behavior rather than relying on the
   138	unchanged #182 tests alone.
   139	
   140	The revised durable plan received a fresh-context `APPROVED` verdict with both
   141	Important findings resolved.
   142	
   143	The SDLC plan-quality gate then found an `ARCH-DRY`/`ARCH-PURE` issue in the
   144	planned recursive lookup: `chat_respond` would have repeated exchange-model
   145	layout traversal. The plan now adds a semantic, pure model query with unit tests
   146	and makes the response IO shell consume it.
   147	
   148	### 2026-07-13 — implementation and verification
   149	
   150	TDD RED established the absent contracts: `last_nonempty_block_end` was missing,
   151	`chat_pending` had no synchronous `tip_written` operation, and the stream
   152	handler did not report its tracked final row. GREEN added the pure model query,
   153	same-ID extmark repair inside the scheduled writer callback, fresh/recursive
   154	initial anchors, and writer-owned row reporting after buffer/model growth.
   155	
   156	Real-buffer regressions now cover hidden first reveal at the moved tip, visible
   157	replacement repair with stable ID/text/timers/reducer state, queued-frame
   158	ordering, staged FIFO plus exact-once completion, edits above a multi-line
   159	stream, and recursive placement after tool/result content. `ARCH-DRY` keeps the
   160	last-visible-block traversal in `exchange_model`; `ARCH-PURE` leaves the temporal
   161	reducer unchanged and confines extmark mutation to the Neovim adapter.
   162	
   163	Verification passed:
   164	
   165	- `make -f Makefile.local test-spec SPEC=chat/response_progress`
   166	- `make -f Makefile.local test-spec SPEC=chat/exchange_model`
   167	- `make -f Makefile.local test JOBS=1` — lint clean; all unit, architecture,
   168	  and integration specs passed
   169	- `git diff --check`
   170	
   171	The first parallel full-suite run exposed a pre-existing cross-test filesystem
   172	race in `tools_builtin_find_spec.lua`: its `find .` can traverse a transient
   173	directory while another unit process deletes it. The test passed alone, the
   174	affected files have no #183 diff, and the serialized full run passed without
   175	altering that unrelated surface.

exec
/bin/zsh -lc "rg -n \"test-spec|test-file|plenary|integration\" Makefile Makefile.parley | sed -n '1,220p'; git diff --unified=40 e3ed1e032140143b1c92dbf1ffe3a9bf7e54c793..HEAD -- workshop/issues/000183-keep-response-progress-at-current-generation-tip.md; git status --short" in /Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip
 succeeded in 0ms:
rg: Makefile: No such file or directory (os error 2)
Makefile.parley:4:.PHONY: help-parley test test-unit test-integration test-spec test-changed perf lint fixtures model-check model-checker test-clean-env
Makefile.parley:9:	"  make test             Run all tests (unit parallel + integration sequential)" \
Makefile.parley:11:	"  make test-integration Run integration tests sequentially" \
Makefile.parley:12:	"  make test-spec SPEC=  Run tests for a specific spec key" \
Makefile.parley:23:PLENARY = ~/.local/share/nvim/lazy/plenary.nvim
Makefile.parley:28:TEST_ENV = HOME="$(TEST_HOME)" XDG_DATA_HOME="$(TEST_XDG)/data" XDG_STATE_HOME="$(TEST_XDG)/state" XDG_CACHE_HOME="$(TEST_XDG)/cache" TMPDIR="$(TEST_TMP)" NVIM_TEST_PLENARY="$(REAL_HOME)/.local/share/nvim/lazy/plenary.nvim"
Makefile.parley:34:# Run all tests: unit in parallel, integration sequentially.
Makefile.parley:35:test: lint test-unit test-integration
Makefile.parley:65:# Run integration + arch tests in parallel — each file in its own Neovim process.
Makefile.parley:66:test-integration:
Makefile.parley:70:	find tests/integration tests/arch -name '*_spec.lua' | sort | \
Makefile.parley:74:	  printf '\n=== Failed integration test files ===\n'; \
Makefile.parley:82:# Example: make test-spec SPEC=chat/lifecycle
Makefile.parley:83:test-spec:
Makefile.parley:85:		echo "Usage: make test-spec SPEC=chat/lifecycle"; \
diff --git a/workshop/issues/000183-keep-response-progress-at-current-generation-tip.md b/workshop/issues/000183-keep-response-progress-at-current-generation-tip.md
index 43a20b3..fc04d7a 100644
--- a/workshop/issues/000183-keep-response-progress-at-current-generation-tip.md
+++ b/workshop/issues/000183-keep-response-progress-at-current-generation-tip.md
@@ -64,83 +64,112 @@ describes current work at a stale spatial location.
 
 - Fresh delayed progress begins directly below `🤖:` before content exists.
 - Recursive delayed progress begins after the response's last existing visible
   answer/tool/result block rather than below `🤖:`.
 - A visible reasoning or remote-tool status moves below each newly written
   content tip and keeps the same presentation text and lifecycle state.
 - Edits above the response remain safe because the writer reports its tracked
   position; cancellation, invalidation, staging, and Definition behavior remain
   unchanged.
 - Real-buffer tests prove a hidden tip update controls the next reveal; visible
   relocation preserves exact extmark ID/text; replacement plus synchronous
   relocation cannot be overtaken by queued frame/progress work; insertion above
   the response still yields the writer's tracked row; and relocation after
   finish is a no-op.
 - Tip relocation leaves timers, minimum deadline, reducer phase, staging FIFO,
   and exact-once terminal delivery unchanged.
 - Focused adapter/real-entry regressions, mapped chat tests, lint, and the full
   repository suite pass.
 
 ## Estimate
 
 ```estimate
 model: estimate-logic-v3.1
 familiarity: 1.0
 item: issue-spec             design=0.75 impl=0.08
 item: lua-neovim             design=0.30 impl=0.40
 item: atlas-docs             design=0.05 impl=0.04
 item: milestone-review       design=0.10 impl=0.12
 design-buffer: 0.15
 total: 2.02
 ```
 
 Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md`
 against `baseline-v3.1.md`. Method A only. The thoroughly reviewed behavioral
 spec discounts the remaining Lua design work; implementation values are the
 v3.1 AI-paired 40% values.
 
 ## Plan
 
 - [x] Approve the durable implementation plan and calibrated estimate.
-- [ ] Add failing adapter and real-entry regressions for fresh, recursive, and
+- [x] Add failing adapter and real-entry regressions for fresh, recursive, and
   streaming tip movement.
-- [ ] Report the tracked last line from the stream writer and move visible
+- [x] Report the tracked last line from the stream writer and move visible
   progress through the serialized chat adapter.
-- [ ] Update the response-progress atlas and pass targeted/full verification.
-- [ ] Close, publish, and merge through the SDLC gates.
+- [x] Update the response-progress atlas and pass targeted/full verification.
+- [x] Close, publish, and merge through the SDLC gates.
 
 ## Log
 
 ### 2026-07-13
 
 Claimed the follow-up after confirming #182's adapter always receives the fixed
 agent-header row. The selected design keeps the structural chat lease on that
 durable header while deriving presentation movement from the streaming
 handler's own tracked line. A model-only resolver was rejected because ordinary
 buffer edits can move the handler extmark without updating model coordinates;
 anchoring directly to the stream placeholder was rejected because chunk writes
 replace and invalidate that line.
 
 ### 2026-07-13 — spec review revision
 
 Fresh review found that a queued tip update could lose a race with the next
 frame/progress callback after `stream_replace_at_line` invalidated a mark on the
 mutable pending line. The spec now requires synchronous same-callback repair
 with the same extmark ID, defines the handler's exact tracked-row argument,
 pins recursive initial placement before the new placeholder exists, and makes
 hidden spatial fallback plus lifecycle-preservation tests explicit.
 
 ### 2026-07-13 — plan review revision
 
 Fresh plan review required stronger proof at two boundaries: recursive initial
 placement now uses the canonical adapter and asserts the real virtual line, and
 the relocation suite now carries ordered staged output through invalidation and
 termination to prove FIFO plus exact-once behavior rather than relying on the
 unchanged #182 tests alone.
 
 The revised durable plan received a fresh-context `APPROVED` verdict with both
 Important findings resolved.
 
 The SDLC plan-quality gate then found an `ARCH-DRY`/`ARCH-PURE` issue in the
 planned recursive lookup: `chat_respond` would have repeated exchange-model
 layout traversal. The plan now adds a semantic, pure model query with unit tests
 and makes the response IO shell consume it.
+
+### 2026-07-13 — implementation and verification
+
+TDD RED established the absent contracts: `last_nonempty_block_end` was missing,
+`chat_pending` had no synchronous `tip_written` operation, and the stream
+handler did not report its tracked final row. GREEN added the pure model query,
+same-ID extmark repair inside the scheduled writer callback, fresh/recursive
+initial anchors, and writer-owned row reporting after buffer/model growth.
+
+Real-buffer regressions now cover hidden first reveal at the moved tip, visible
+replacement repair with stable ID/text/timers/reducer state, queued-frame
+ordering, staged FIFO plus exact-once completion, edits above a multi-line
+stream, and recursive placement after tool/result content. `ARCH-DRY` keeps the
+last-visible-block traversal in `exchange_model`; `ARCH-PURE` leaves the temporal
+reducer unchanged and confines extmark mutation to the Neovim adapter.
+
+Verification passed:
+
+- `make -f Makefile.local test-spec SPEC=chat/response_progress`
+- `make -f Makefile.local test-spec SPEC=chat/exchange_model`
+- `make -f Makefile.local test JOBS=1` — lint clean; all unit, architecture,
+  and integration specs passed
+- `git diff --check`
+
+The first parallel full-suite run exposed a pre-existing cross-test filesystem
+race in `tools_builtin_find_spec.lua`: its `find .` can traverse a transient
+directory while another unit process deletes it. The test passed alone, the
+affected files have no #183 diff, and the serialized full run passed without
+altering that unrelated surface.

exec
/bin/zsh -lc "sed -n '20,115p' Makefile.parley; rg -n 'chat_pending|chat_respond|create_handler|exchange_model' specs atlas/traceability.yaml 2>/dev/null | sed -n '1,240p'; git diff --check e3ed1e032140143b1c92dbf1ffe3a9bf7e54c793..HEAD" in /Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip
 succeeded in 0ms:

# ── Test environment ─────────────────────────────────────────────────────────

PLENARY = ~/.local/share/nvim/lazy/plenary.nvim
REAL_HOME = $(HOME)
TEST_HOME = $(CURDIR)/.test-home
TEST_XDG = $(CURDIR)/.test-xdg
TEST_TMP = $(CURDIR)/.test-tmp
TEST_ENV = HOME="$(TEST_HOME)" XDG_DATA_HOME="$(TEST_XDG)/data" XDG_STATE_HOME="$(TEST_XDG)/state" XDG_CACHE_HOME="$(TEST_XDG)/cache" TMPDIR="$(TEST_TMP)" NVIM_TEST_PLENARY="$(REAL_HOME)/.local/share/nvim/lazy/plenary.nvim"

define PREP_TEST_ENV
mkdir -p "$(TEST_HOME)" "$(TEST_XDG)/data" "$(TEST_XDG)/state" "$(TEST_XDG)/cache" "$(TEST_TMP)"
endef

# Run all tests: unit in parallel, integration sequentially.
test: lint test-unit test-integration

# Number of parallel test processes (override with JOBS=N).
JOBS ?= 8

# Per-file test runner. Captures the file's output; prints `PASS: <path>` on
# success or a labelled `===FAIL: <path>===` block (with indented output) on
# failure; appends the failing path to $FAILED_LOG so the recipe can print a
# reliable summary after xargs finishes. Single-line PASS writes are atomic;
# the FAIL block is best-effort across parallel jobs but the end-of-run
# summary is authoritative either way.
RUN_SPEC = sh -c 'out=$$(mktemp "$$TMPDIR/parley-test.XXXXXX"); if nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile $$1" -c "qa!" >"$$out" 2>&1; then printf "PASS: %s\n" "$$1"; rm -f "$$out"; else { printf "===FAIL: %s===\n" "$$1"; sed "s/^/  /" "$$out"; }; echo "$$1" >> "$$FAILED_LOG"; rm -f "$$out"; exit 1; fi' _

# Run unit tests in parallel — each file in its own Neovim process.
# Safe because unit tests have no shared state.
test-unit:
	@$(PREP_TEST_ENV)
	@export $(TEST_ENV); \
	FAILED_LOG=$$(mktemp "$$TMPDIR/parley-failed.XXXXXX"); export FAILED_LOG; \
	find tests/unit -name '*_spec.lua' | sort | \
	  xargs -P $(JOBS) -I {} $(RUN_SPEC) {}; \
	rc=0; \
	if [ -s "$$FAILED_LOG" ]; then \
	  printf '\n=== Failed unit test files ===\n'; \
	  sort -u "$$FAILED_LOG"; \
	  rc=1; \
	fi; \
	rm -f "$$FAILED_LOG"; \
	exit $$rc

# Run integration + arch tests in parallel — each file in its own Neovim process.
test-integration:
	@$(PREP_TEST_ENV)
	@export $(TEST_ENV); \
	FAILED_LOG=$$(mktemp "$$TMPDIR/parley-failed.XXXXXX"); export FAILED_LOG; \
	find tests/integration tests/arch -name '*_spec.lua' | sort | \
	  xargs -P $(JOBS) -I {} $(RUN_SPEC) {}; \
	rc=0; \
	if [ -s "$$FAILED_LOG" ]; then \
	  printf '\n=== Failed integration test files ===\n'; \
	  sort -u "$$FAILED_LOG"; \
	  rc=1; \
	fi; \
	rm -f "$$FAILED_LOG"; \
	exit $$rc

# Run tests mapped to one spec key/path from atlas/traceability.yaml.
# Example: make test-spec SPEC=chat/lifecycle
test-spec:
	@if [ -z "$(SPEC)" ]; then \
		echo "Usage: make test-spec SPEC=chat/lifecycle"; \
		exit 1; \
	fi
	@$(PREP_TEST_ENV); \
	tests="$$(scripts/spec_test_map.sh list-tests "$(SPEC)")"; \
	if [ -z "$$tests" ]; then \
		echo "No tests mapped for spec: $(SPEC)"; \
		echo "Update atlas/traceability.yaml to add mappings."; \
		exit 1; \
	fi; \
	for test_file in $$tests; do \
		echo "Running $$test_file"; \
		$(TEST_ENV) nvim -n --headless --noplugin -u tests/minimal_init.vim \
		  -c "PlenaryBustedFile $$test_file" \
		  -c "qa!" || exit $$?; \
	done

# Run tests mapped to changed spec files under atlas/*/*.md.
# Uses tracked and untracked file changes since feature-branch base
# (default base ref: remote/main, fallback origin/main, then main).
test-changed:
	@$(PREP_TEST_ENV); \
	scripts/spec_test_map.sh base-info; \
	changed_specs="$$(scripts/spec_test_map.sh list-changed-specs)"; \
	if [ -z "$$changed_specs" ]; then \
		echo "No changed spec files under atlas/*/*.md"; \
		exit 0; \
	fi; \
	echo "Changed specs:"; \
	printf '%s\n' "$$changed_specs"; \
	missing=0; \
atlas/traceability.yaml:14:      - tests/integration/chat_respond_spec.lua
atlas/traceability.yaml:19:      - lua/parley/chat_respond.lua
atlas/traceability.yaml:35:      - tests/unit/chat_respond_footnote_spec.lua
atlas/traceability.yaml:43:      - tests/integration/create_handler_spec.lua
atlas/traceability.yaml:45:      - tests/integration/chat_respond_spec.lua
atlas/traceability.yaml:52:      - lua/parley/chat_pending.lua
atlas/traceability.yaml:53:      - lua/parley/chat_respond.lua
atlas/traceability.yaml:54:      - lua/parley/exchange_model.lua
atlas/traceability.yaml:65:      - tests/integration/chat_pending_spec.lua
atlas/traceability.yaml:66:      - tests/integration/chat_respond_spec.lua
atlas/traceability.yaml:67:      - tests/integration/create_handler_spec.lua
atlas/traceability.yaml:70:      - tests/unit/exchange_model_spec.lua
atlas/traceability.yaml:77:      - lua/parley/chat_respond.lua
atlas/traceability.yaml:81:      - tests/integration/chat_respond_spec.lua
atlas/traceability.yaml:93:  chat/exchange_model:
atlas/traceability.yaml:95:      - lua/parley/exchange_model.lua
atlas/traceability.yaml:100:      - tests/unit/exchange_model_spec.lua
atlas/traceability.yaml:120:      - lua/parley/chat_respond.lua
atlas/traceability.yaml:126:      - tests/integration/chat_respond_spec.lua
atlas/traceability.yaml:163:      - lua/parley/chat_respond.lua
atlas/traceability.yaml:175:      - lua/parley/chat_respond.lua
atlas/traceability.yaml:180:      - tests/integration/chat_respond_spec.lua
atlas/traceability.yaml:237:      - tests/integration/chat_respond_spec.lua
atlas/traceability.yaml:329:      - lua/parley/chat_respond.lua
atlas/traceability.yaml:367:      - lua/parley/chat_respond.lua
atlas/traceability.yaml:389:      - lua/parley/chat_respond.lua

exec
/bin/zsh -lc 'export HOME="$PWD/.test-home" XDG_DATA_HOME="$PWD/.test-xdg/data" XDG_STATE_HOME="$PWD/.test-xdg/state" XDG_CACHE_HOME="$PWD/.test-xdg/cache" TMPDIR="$PWD/.test-tmp" NVIM_TEST_PLENARY="$HOME/.local/share/nvim/lazy/plenary.nvim"; for f in tests/integration/chat_pending_spec.lua tests/integration/chat_respond_spec.lua tests/integration/create_handler_spec.lua tests/unit/exchange_model_spec.lua; do echo "RUN $f"; nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile $f" -c '"'qa"'!'"' || exit; done" in /Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip
 succeeded in 11748ms:
[32mSuccess[0m	||	chat pending extmark adapter repaints at the extmark's tracked row after text moves the anchor	
[32mSuccess[0m	||	chat pending extmark adapter uses a hidden tip update for the first reveal	
[32mSuccess[0m	||	chat pending extmark adapter repairs invalidating writes synchronously without changing lifecycle state	
[32mSuccess[0m	||	chat pending extmark adapter stages content until the minimum and flushes it in FIFO order	
[32mSuccess[0m	||	chat pending extmark adapter cancels every playful timer when fast content releases waiting	
[32mSuccess[0m	||	chat pending extmark adapter keeps fast semantic status but cancels every playful timer	
[32mSuccess[0m	||	chat pending extmark adapter renders semantic status in the same extmark while content streams	
[32mSuccess[0m	||	chat pending extmark adapter hides without changing real lines or the undo sequence	
[32mSuccess[0m	||	chat pending extmark adapter completes after the minimum and invokes the continuation once	
[32mSuccess[0m	||	chat pending extmark adapter contains emitter failures without logging callback data	
[32mSuccess[0m	||	chat pending extmark adapter surfaces owned failures after staged partial output	
[32mSuccess[0m	||	chat pending extmark adapter hides released semantic status before surfacing failure	
[32mSuccess[0m	||	chat pending extmark adapter cancels stale leases and deleted buffers with every timer	
[32mSuccess[0m	||	chat pending extmark adapter invokes discard hooks once for cancel, frame-stale, and buffer-invalid	
[32mSuccess[0m	||	chat pending extmark adapter releases ownership before a reentrant discard hook	
[32mSuccess[0m	||	chat pending extmark adapter contains and redacts throwing discard hooks	
[32mSuccess[0m	||	chat pending extmark adapter does not invoke discard hooks for completion or provider failure	
[32mSuccess[0m	||	chat pending extmark adapter frame ticks terminate a shown session whose lease became stale	
[32mSuccess[0m	||	chat pending extmark adapter enforces one active session per buffer and cancel_all is idempotent	
[32mSuccess[0m	||	chat pending extmark adapter does not publish sessions whose initializer fails	
[32mSuccess[0m	||	chat pending extmark adapter uses the production scheduler to leave a real uv fast event	
	
[32mSuccess: [0m	24	
[31mFailed : [0m	0	
[31mErrors : [0m	0	
========================================	
RUN tests/integration/chat_respond_spec.lua
Scheduling: tests/integration/chat_respond_spec.lua

========================================	
Testing: 	/Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip/tests/integration/chat_respond_spec.lua	
[32mSuccess[0m	||	chat_respond: completion callback does not error when headers.topic is accessed in completion callback	
[32mSuccess[0m	||	chat_respond: completion callback refreshes a normal completed API leg	
[32mSuccess[0m	||	chat_respond: completion callback completion callback can access parsed_chat from outer scope	
[32mSuccess[0m	||	chat_respond: completion callback refreshes abort after mutation	
[32mSuccess[0m	||	chat_respond: buffer state after completion finalizes once when topic generation aborts	
[32mSuccess[0m	||	chat_respond: buffer state after completion finalizes once when topic generation returns empty	
[32mSuccess[0m	||	chat_respond: buffer state after completion appends new user prompt after last exchange response	
[32mSuccess[0m	||	chat_respond: buffer state after completion preserves trailing footnotes when completing an answer inserted above them	
[32mSuccess[0m	||	chat_respond: buffer state after completion keeps follow cursor on the last streamed answer line after completion	
[32mSuccess[0m	||	chat_respond: buffer state after completion topic generation writes updated header to line 0	
[32mSuccess[0m	||	chat_respond: buffer state after completion middle-document resubmit replaces old answer without appending new prompt	
[32mSuccess[0m	||	chat_respond: buffer state after completion streams answer content arriving before reveal without playful UI	
expected abortexpected topic abortMemory prefs: scanning chat history...
[32mSuccess[0m	||	chat_respond: buffer state after completion shows a virtual playful line after one second and stages content for its minimum	
[32mSuccess[0m	||	chat_respond: buffer state after completion lets same-deadline content beat reveal exactly once through M.respond	
[32mSuccess[0m	||	chat_respond: buffer state after completion lets same-deadline reveal stage content and releases one continuation at minimum	
[32mSuccess[0m	||	chat_respond: buffer state after completion keeps meaningful remote status visible after release until completion	
Memory prefs: no summaries found in chat historychat transcript structure changed during pending request
[32mSuccess[0m	||	chat_respond: buffer state after completion keeps topic-generation fallback outside playful chat sessions	
[32mSuccess[0m	||	chat_respond: guard branches cancels pending presentation before stopping task processes	
[32mSuccess[0m	||	chat_respond: guard branches returns early without calling dispatcher when buffer is already busy	
[32mSuccess[0m	||	chat_respond: guard branches returns early without calling dispatcher for non-chat file	
[32mSuccess[0m	||	chat_respond: guard branches returns early without calling dispatcher when no header separator found	
Parley.nvim: chat transcript structure changed during pending requestParley.nvim: File "/Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip/.test-tmp/claude/not-a-chat-file.md" does not look like a chat file: "resolved file (/Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip/.test-tmp/claude/not-a-chat-file.md) not in configured chat roots (/Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip/.test-tmp/claude/parley-test-chat-respond-1783977287)"
[32mSuccess[0m	||	chat_respond: pending request transcript drift runs a tool-only completion immediately before playful reveal	
[32mSuccess[0m	||	chat_respond: pending request transcript drift rejects force resubmit before mutating a chat that already owns a pending session	
[32mSuccess[0m	||	chat_respond: pending request transcript drift hides a shown leg before its local tool and starts recursion with a fresh verb	
Parley.nvim: File "/Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip/.test-tmp/claude/parley-test-chat-respond-1783977287/2026-03-01-test-1783977290-72651.md" does not look like a chat file: "missing header separator"Parley.nvim: A Parley response is already pending in this chat. Stop it before resubmitting.chat transcript structure changed during pending request
[32mSuccess[0m	||	chat_respond: pending request transcript drift discards staged output and tears down the chat leg once when its lease goes stale	
[32mSuccess[0m	||	chat_respond: pending request transcript drift tears down a staged chat leg once when its buffer is deleted	
[32mSuccess[0m	||	chat_respond: pending request transcript drift cmd Stop discards staged output and tears down its owned chat leg once	
Parley.nvim: chat transcript structure changed during pending requestchat transcript structure changed during pending request
[32mSuccess[0m	||	chat_respond: pending request transcript drift does not insert a late stream chunk after undo invalidates the pending response	
Parley.nvim: chat transcript structure changed during pending requestchat transcript structure changed during pending request
[32mSuccess[0m	||	chat_respond: pending request transcript drift does not insert a late stream chunk after redo drift	
[32mSuccess[0m	||	chat_respond: pending request transcript drift does not insert a queued stream chunk after undo before the dispatcher write runs	
[32mSuccess[0m	||	chat_respond: pending request transcript drift allows multi-chunk streaming when the transcript does not drift	
Parley.nvim: chat transcript structure changed during pending requestchat transcript structure changed during pending request
[32mSuccess[0m	||	chat_respond: pending request transcript drift does not append tool blocks when undo invalidates before tool-loop processing	
Parley.nvim: chat transcript structure changed during pending requestchat transcript structure changed during pending request
[32mSuccess[0m	||	chat_respond: pending request transcript drift does not recursively resubmit from a stale live model after undo	
[32mSuccess[0m	||	chat_respond: pending request transcript drift refreshes each recursive API leg	
Parley.nvim: chat transcript structure changed during pending requestchat transcript structure changed during pending request
[32mSuccess[0m	||	chat_respond: pending request transcript drift does not write stale progress after undo invalidates the pending response	
Parley.nvim: chat transcript structure changed during pending requestchat transcript structure changed during pending request
[32mSuccess[0m	||	chat_respond: pending request transcript drift does not update the topic header from a stale topic callback after undo	
Parley.nvim: chat transcript structure changed during pending requestParley: Resubmitting all 2 questions...
Parley.nvim: Resubmitting all 2 questions...
Parley: Completed resubmitting all questions
[32mSuccess[0m	||	chat_respond_all calls dispatcher once per exchange sequentially	
Parley.nvim: Completed resubmitting all questionsParley: Resubmitting all 2 questions...
Parley.nvim: Resubmitting all 2 questions...
Parley: Completed resubmitting all questions
[32mSuccess[0m	||	chat_respond_all reuses remote content fetched in earlier batch steps instead of refetching it later	
[32mSuccess[0m	||	chat_respond_all returns early without calling dispatcher for non-chat file	
[32mSuccess[0m	||	chat_respond: drill-in pre-processing gathers ready drill-in markers and appends them to the next user turn	
[32mSuccess[0m	||	chat_respond: drill-in pre-processing does not add a quote block when there are no drill-in markers	
[32mSuccess[0m	||	chat_respond: drill-in pre-processing branches a new turn after the cursor exchange when it contains drill-ins	
[32mSuccess[0m	||	chat_respond: drill-in pre-processing does true resubmit when cursor exchange has an answer but no drill-ins	
	
[32mSuccess: [0m	43	
[31mFailed : [0m	0	
[31mErrors : [0m	0	
========================================	
Parley.nvim: Completed resubmitting all questionsParley.nvim: File "/Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip/.test-tmp/claude/not-a-chat-all.md" does not look like a chat file: "resolved file (/Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip/.test-tmp/claude/not-a-chat-all.md) not in configured chat roots (/Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip/.test-tmp/claude/parley-test-chat-respond-1783977287)"
Parley.nvim: Drill-in: gathered 1 marker(s) into next turn
Parley.nvim: Drill-in branch: 1 marker(s) → new turn after exchange #1
RUN tests/integration/create_handler_spec.lua
Scheduling: tests/integration/create_handler_spec.lua

========================================	
Testing: 	/Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip/tests/integration/create_handler_spec.lua	
[32mSuccess[0m	||	create_handler: streaming behavior first chunk is written to the correct line	
[32mSuccess[0m	||	create_handler: streaming behavior second chunk is accumulated and merged correctly	
[32mSuccess[0m	||	create_handler: streaming behavior multi-line response splits across lines correctly	
[32mSuccess[0m	||	create_handler: streaming behavior prefix is prepended to each written line	
[32mSuccess[0m	||	create_handler: streaming behavior multi-line with prefix prepends to each line	
[32mSuccess[0m	||	create_handler: streaming behavior invalid buffer returns early without error	
[32mSuccess[0m	||	create_handler: streaming behavior incremental write only updates the last incomplete line	
[32mSuccess[0m	||	create_handler: streaming behavior preserves trailing newline as an empty pending line	
[32mSuccess[0m	||	create_handler: streaming behavior handles many tiny chunks on a single line	
[32mSuccess[0m	||	create_handler: streaming behavior handles mixed newline boundaries across multiple chunks with prefix	
[32mSuccess[0m	||	create_handler: streaming behavior strips leading newlines from first chunk for consistent spacing	
[32mSuccess[0m	||	create_handler: streaming behavior does not move cursor when cursor callback returns false	
[32mSuccess[0m	||	create_handler: streaming behavior reports the tracked last written row after growth and edits above	
	
[32mSuccess: [0m	13	
[31mFailed : [0m	0	
[31mErrors : [0m	0	
========================================	
RUN tests/unit/exchange_model_spec.lua
Scheduling: tests/unit/exchange_model_spec.lua

========================================	
Testing: 	/Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip/tests/unit/exchange_model_spec.lua	
[32mSuccess[0m	||	exchange_model: basic construction creates an empty model with header_lines	
[32mSuccess[0m	||	exchange_model: single exchange, question only exchange_start is header_lines + margin	
[32mSuccess[0m	||	exchange_model: single exchange, question only append_pos for question-only exchange is after question + margin	
[32mSuccess[0m	||	exchange_model: single exchange with blocks reports the last non-empty block end through trailing empty blocks	
[32mSuccess[0m	||	exchange_model: single exchange with blocks reports the only non-empty block end	
[32mSuccess[0m	||	exchange_model: single exchange with blocks returns nil when an exchange has no non-empty blocks	
[32mSuccess[0m	||	exchange_model: single exchange with blocks agent_header block starts after question + margin	
[32mSuccess[0m	||	exchange_model: single exchange with blocks text block starts after agent_header + margin	
[32mSuccess[0m	||	exchange_model: single exchange with blocks block_end returns the last line of a block	
[32mSuccess[0m	||	exchange_model: single exchange with blocks tool_use block after text includes margin	
[32mSuccess[0m	||	exchange_model: single exchange with blocks append_pos advances after adding blocks	
[32mSuccess[0m	||	exchange_model: single exchange with blocks grow_block updates the size and shifts subsequent positions	
[32mSuccess[0m	||	exchange_model: single exchange with blocks grow_question shifts all subsequent positions	
[32mSuccess[0m	||	exchange_model: empty block cancellation empty block is invisible — doesn't add margins	
[32mSuccess[0m	||	exchange_model: empty block cancellation setting block size to 0 makes it invisible	
[32mSuccess[0m	||	exchange_model: empty block cancellation exchange_total_size skips empty blocks	
[32mSuccess[0m	||	exchange_model: two exchanges second exchange starts after first + margin	
[32mSuccess[0m	||	exchange_model: two exchanges tool blocks in exchange 1 shift exchange 2	
[32mSuccess[0m	||	exchange_model: from_parsed_chat loads exchange structure from parser output	
[32mSuccess[0m	||	exchange_model: from_parsed_chat with real parser positions match buffer lines for simple Q+A	
[32mSuccess[0m	||	exchange_model: from_parsed_chat with real parser positions match buffer lines with thinking + tool blocks	
[32mSuccess[0m	||	exchange_model: from_parsed_chat with real parser parser trims trailing blanks from question	
[32mSuccess[0m	||	exchange_model: from_parsed_chat with real parser parser trims trailing blanks from answer sections	
	
[32mSuccess: [0m	23	
[31mFailed : [0m	0	
[31mErrors : [0m	0	
========================================	

exec
/bin/zsh -lc 'make -f Makefile.local lint' in /Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip
 succeeded in 2310ms:
Checking lua/parley/agent_info.lua                OK
Checking lua/parley/agent_picker.lua              OK
Checking lua/parley/artifact_ref.lua              OK
Checking lua/parley/buffer_edit.lua               OK
Checking lua/parley/buffer_lifecycle.lua          OK
Checking lua/parley/chat_dirs.lua                 OK
Checking lua/parley/chat_finder.lua               OK
Checking lua/parley/chat_lease.lua                OK
Checking lua/parley/chat_parser.lua               OK
Checking lua/parley/chat_pending.lua              OK
Checking lua/parley/chat_presentation.lua         OK
Checking lua/parley/chat_respond.lua              OK
Checking lua/parley/chat_slug.lua                 OK
Checking lua/parley/cliproxy.lua                  OK
Checking lua/parley/cliproxy_config.lua           OK
Checking lua/parley/config.lua                    OK
Checking lua/parley/copy.lua                      OK
Checking lua/parley/custom_prompts.lua            OK
Checking lua/parley/defaults.lua                  OK
Checking lua/parley/define.lua                    OK
Checking lua/parley/diagnostic_refresh.lua        OK
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
Checking lua/parley/highlight_structure.lua       OK
Checking lua/parley/highlighter.lua               OK
Checking lua/parley/init.lua                      OK
Checking lua/parley/interview.lua                 OK
Checking lua/parley/issue_finder.lua              OK
Checking lua/parley/issue_vocabulary.lua          OK
Checking lua/parley/issues.lua                    OK
Checking lua/parley/keybinding_registry.lua       OK
Checking lua/parley/line_reader.lua               OK
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
Checking lua/parley/selection_spinner.lua         OK
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
Checking tests/arch/performance_line_reader_spec.lua OK
Checking tests/fixtures/pre_81_vanilla_claude_prompts.lua OK
Checking tests/integration/chat_lease_spec.lua    OK
Checking tests/integration/chat_move_spec.lua     OK
Checking tests/integration/chat_pending_spec.lua  OK
Checking tests/integration/chat_progress_process_spec.lua OK
Checking tests/integration/chat_respond_spec.lua  OK
Checking tests/integration/cliproxy_auth_login_spec.lua OK
Checking tests/integration/cliproxy_caller_teardown_spec.lua OK
Checking tests/integration/cliproxy_command_spec.lua OK
Checking tests/integration/cliproxy_dispatch_spec.lua OK
Checking tests/integration/cliproxy_download_spec.lua OK
Checking tests/integration/cliproxy_lifecycle_spec.lua OK
Checking tests/integration/create_handler_spec.lua OK
Checking tests/integration/define_spec.lua        OK
Checking tests/integration/diagnostic_refresh_spec.lua OK
Checking tests/integration/discovery_builder_spec.lua OK
Checking tests/integration/discovery_local_types_spec.lua OK
Checking tests/integration/export_spec.lua        OK
Checking tests/integration/highlighting_spec.lua  OK
Checking tests/integration/neighborhood_completion_spec.lua OK
Checking tests/integration/new_chat_spec.lua      OK
Checking tests/integration/not_chat_spec.lua      OK
Checking tests/integration/perf_chat_typing_spec.lua OK
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
Checking tests/perf/chat_typing.lua               OK
Checking tests/perf/harness.lua                   OK
Checking tests/perf_chat_finder.lua               OK
Checking tests/unit/ancestor_messages_spec.lua    OK
Checking tests/unit/anthropic_tool_decode_spec.lua OK
Checking tests/unit/anthropic_tool_encode_spec.lua OK
Checking tests/unit/arch_helper_spec.lua          OK
Checking tests/unit/artifact_ref_spec.lua         OK
Checking tests/unit/buffer_edit_spec.lua          OK
Checking tests/unit/buffer_lifecycle_spec.lua     OK
Checking tests/unit/build_messages_spec.lua       OK
Checking tests/unit/chat_dirs_spec.lua            OK
Checking tests/unit/chat_finder_logic_spec.lua    OK
Checking tests/unit/chat_parser_section_lines_spec.lua OK
Checking tests/unit/chat_parser_tools_spec.lua    OK
Checking tests/unit/chat_presentation_spec.lua    OK
Checking tests/unit/chat_respond_footnote_spec.lua OK
Checking tests/unit/chat_slug_resolve_spec.lua    OK
Checking tests/unit/chat_slug_spec.lua            OK
Checking tests/unit/cliproxy_config_spec.lua      OK
Checking tests/unit/config_tools_spec.lua         OK
Checking tests/unit/custom_prompts_spec.lua       OK
Checking tests/unit/define_spec.lua               OK
Checking tests/unit/diagnostic_refresh_spec.lua   OK
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
Checking tests/unit/highlight_structure_spec.lua  OK
Checking tests/unit/highlighter_spec.lua          OK
Checking tests/unit/inline_branch_spec.lua        OK
Checking tests/unit/issue_finder_spec.lua         OK
Checking tests/unit/issue_vocabulary_spec.lua     OK
Checking tests/unit/issues_spec.lua               OK
Checking tests/unit/keybindings_spec.lua          OK
Checking tests/unit/line_reader_spec.lua          OK
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
Checking tests/unit/perf_harness_spec.lua         OK
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

Total: 0 warnings / 0 errors in 265 files

codex
```verdict
verdict: REWORK
confidence: high
```

The moving-tip design is largely correct and well tested, but one explicit invalidation contract is not implemented: a stream callback can revive a progress extmark that was already invalidated by an unrelated edit. That correctness gap blocks shipment. The tracker also prematurely claims the issue is closed and merged.

## 1. Strengths

- [dispatcher.lua:575](/Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip/lua/parley/dispatcher.lua:575) reports the writer-owned, extmark-adjusted row after buffer mutation and model growth, avoiding stale coordinate recomputation.
- [exchange_model.lua:176](/Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip/lua/parley/exchange_model.lua:176) provides a pure semantic query and reuses it from `append_pos`, preserving one layout traversal.
- Fresh and recursive initial anchors are selected before adding the new placeholder as required in [chat_respond.lua:1467](/Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip/lua/parley/chat_respond.lua:1467).
- Tests cover hidden relocation, stable extmark ID/text, queued-frame ordering, FIFO delivery, edits above streaming output, recursive placement, and post-finish no-op behavior.
- Atlas and traceability mappings were updated. No README change is needed because the diff introduces no command, keybinding, flag, or configuration surface.

## 2. Critical findings

- [chat_pending.lua:392](/Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip/lua/parley/chat_pending.lua:392) — `tip_written` unconditionally recreates any visible mark through `set_mark`, without determining whether it was valid immediately before the acknowledged stream replacement. If a user deletes/replaces the current tip and invalidates the mark, then a queued stream write runs before a frame/progress callback notices, `tip_written` silently revives the externally invalidated mark. This contradicts the Spec’s requirement that only replacement caused by that stream write may be repaired; unrelated invalidation must retain terminal behavior. `ARCH-PURPOSE` is flagged because an explicit correctness boundary remains undelivered.

  Fix sketch: add a synchronous pre-write handshake from `create_handler`/`chat_respond` that records whether the visible mark is valid immediately before mutation. Reject or terminally dispatch `invalid` when it is already invalid; authorize same-ID repair only when the subsequent acknowledged replacement caused the invalidation. Add a regression for “external invalidation, then queued stream write before frame/progress.”

## 3. Important findings

- [issue tracker:103](/Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip/workshop/issues/000183-keep-response-progress-at-current-generation-tip.md:103) — the plan checks “Close, publish, and merge through the SDLC gates,” while frontmatter remains `status: working`, the branch is unmerged, and this close review has found a blocker. Uncheck the closure and verification items until the fix and rerun are complete.

## 4. Minor findings

None.

## 5. Test coverage notes

- Independently passed:
  - `chat_pending_spec.lua`: 24 tests
  - `chat_respond_spec.lua`: 43 tests
  - `create_handler_spec.lua`: 13 tests
  - `exchange_model_spec.lua`: 23 tests
  - `make -f Makefile.local lint`: 0 warnings/errors
  - `git diff --check`
- `SPEC=chat/exchange_model` passed.
- `SPEC=chat/response_progress` reached the real-process tests, but four cases could not start their localhost fixture under the review sandbox’s network restrictions; this was environmental rather than an observed assertion regression.
- Missing coverage: pre-existing/unrelated extmark invalidation immediately followed by a stream write.

## 6. Architectural notes for upcoming work

- `ARCH-DRY`: Pass. Last-visible-block traversal has one implementation in `exchange_model`, and the stream writer owns final-row calculation.
- `ARCH-PURE`: Pass. The model query is IO-free and directly unit tested; extmark mutation remains in the Neovim adapter.
- `ARCH-PURPOSE`: Flagged by the Critical finding. The moving-tip purpose is implemented, but its required distinction between acknowledged and unrelated invalidation is not.
- No Core concepts table is present, so the row-by-row PURE/INTEGRATION cross-check is not applicable.

## 7. Plan revision recommendations

Add a `## Revisions` entry recording:

- Boundary review found that `tip_written` can revive an extmark invalidated before the stream mutation.
- Add a pre-write validity/repair authorization handshake and a real-buffer regression for external invalidation racing a queued stream write.
- Reopen targeted/full verification and “Close, publish, and merge” until the fix passes the SDLC gates.
tokens used
73,204
```verdict
verdict: REWORK
confidence: high
```

The moving-tip design is largely correct and well tested, but one explicit invalidation contract is not implemented: a stream callback can revive a progress extmark that was already invalidated by an unrelated edit. That correctness gap blocks shipment. The tracker also prematurely claims the issue is closed and merged.

## 1. Strengths

- [dispatcher.lua:575](/Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip/lua/parley/dispatcher.lua:575) reports the writer-owned, extmark-adjusted row after buffer mutation and model growth, avoiding stale coordinate recomputation.
- [exchange_model.lua:176](/Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip/lua/parley/exchange_model.lua:176) provides a pure semantic query and reuses it from `append_pos`, preserving one layout traversal.
- Fresh and recursive initial anchors are selected before adding the new placeholder as required in [chat_respond.lua:1467](/Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip/lua/parley/chat_respond.lua:1467).
- Tests cover hidden relocation, stable extmark ID/text, queued-frame ordering, FIFO delivery, edits above streaming output, recursive placement, and post-finish no-op behavior.
- Atlas and traceability mappings were updated. No README change is needed because the diff introduces no command, keybinding, flag, or configuration surface.

## 2. Critical findings

- [chat_pending.lua:392](/Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip/lua/parley/chat_pending.lua:392) — `tip_written` unconditionally recreates any visible mark through `set_mark`, without determining whether it was valid immediately before the acknowledged stream replacement. If a user deletes/replaces the current tip and invalidates the mark, then a queued stream write runs before a frame/progress callback notices, `tip_written` silently revives the externally invalidated mark. This contradicts the Spec’s requirement that only replacement caused by that stream write may be repaired; unrelated invalidation must retain terminal behavior. `ARCH-PURPOSE` is flagged because an explicit correctness boundary remains undelivered.

  Fix sketch: add a synchronous pre-write handshake from `create_handler`/`chat_respond` that records whether the visible mark is valid immediately before mutation. Reject or terminally dispatch `invalid` when it is already invalid; authorize same-ID repair only when the subsequent acknowledged replacement caused the invalidation. Add a regression for “external invalidation, then queued stream write before frame/progress.”

## 3. Important findings

- [issue tracker:103](/Users/xianxu/workspace/worktree/parley.nvim/000183-keep-response-progress-at-current-generation-tip/workshop/issues/000183-keep-response-progress-at-current-generation-tip.md:103) — the plan checks “Close, publish, and merge through the SDLC gates,” while frontmatter remains `status: working`, the branch is unmerged, and this close review has found a blocker. Uncheck the closure and verification items until the fix and rerun are complete.

## 4. Minor findings

None.

## 5. Test coverage notes

- Independently passed:
  - `chat_pending_spec.lua`: 24 tests
  - `chat_respond_spec.lua`: 43 tests
  - `create_handler_spec.lua`: 13 tests
  - `exchange_model_spec.lua`: 23 tests
  - `make -f Makefile.local lint`: 0 warnings/errors
  - `git diff --check`
- `SPEC=chat/exchange_model` passed.
- `SPEC=chat/response_progress` reached the real-process tests, but four cases could not start their localhost fixture under the review sandbox’s network restrictions; this was environmental rather than an observed assertion regression.
- Missing coverage: pre-existing/unrelated extmark invalidation immediately followed by a stream write.

## 6. Architectural notes for upcoming work

- `ARCH-DRY`: Pass. Last-visible-block traversal has one implementation in `exchange_model`, and the stream writer owns final-row calculation.
- `ARCH-PURE`: Pass. The model query is IO-free and directly unit tested; extmark mutation remains in the Neovim adapter.
- `ARCH-PURPOSE`: Flagged by the Critical finding. The moving-tip purpose is implemented, but its required distinction between acknowledged and unrelated invalidation is not.
- No Core concepts table is present, so the row-by-row PURE/INTEGRATION cross-check is not applicable.

## 7. Plan revision recommendations

Add a `## Revisions` entry recording:

- Boundary review found that `tip_written` can revive an extmark invalidated before the stream mutation.
- Add a pre-write validity/repair authorization handshake and a real-buffer regression for external invalidation racing a queued stream write.
- Reopen targeted/full verification and “Close, publish, and merge” until the fix passes the SDLC gates.
