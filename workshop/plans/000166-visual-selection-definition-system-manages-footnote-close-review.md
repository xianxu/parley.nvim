# Boundary Review — parley.nvim#166 (whole-issue close)

| field | value |
|-------|-------|
| issue | 166 — move visual selection definition system to be based on durable footnote |
| repo | parley.nvim |
| issue file | workshop/issues/000166-visual-selection-definition-system-manages-footnote.md |
| boundary | whole-issue close |
| milestone | — |
| window | 7f591d9dad8444b180a84a82ad02a9c239cfc6e2..HEAD |
| command | sdlc close --issue 166 |
| reviewer | codex |
| timestamp | 2026-07-08T09:03:17-07:00 |
| verdict | REWORK |

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
session id: 019f4276-5249-72d2-9a95-0cfe625e27ac
--------
user
# Code review — the one SDLC boundary review

You are conducting a fresh-context code review at a development boundary —
whole-issue close — in the **parley.nvim** repository.

- repository: parley.nvim   (root: /Users/xianxu/workspace/parley.nvim)
- issue:      parley.nvim#166   (file: workshop/issues/000166-visual-selection-definition-system-manages-footnote.md)
- window:     Base: 7f591d9dad8444b180a84a82ad02a9c239cfc6e2   Head: HEAD

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
index e5e29d7..512fb24 100644
--- a/atlas/chat/inline_define.md
+++ b/atlas/chat/inline_define.md
@@ -2,13 +2,15 @@
 
 Select a phrase in a chat transcript, press **`<M-CR>`** (visual mode), and a
 concise, context-aware definition appears as an **ephemeral inline diagnostic**
-(grey `virtual_lines`) under the phrase. The term is wrapped in a `[term]`
-reference bracket + highlighted (review's `DiffChange`); the **definition text
-is never written to the file**, only the brackets. The whole annotation is
-**undoable** — `u` reverts the bracket and clears both decorations (see Undo
-below). For jargon you don't know (e.g. `ASIN`), it's a one-keystroke lookup.
-Added in [#161](../../workshop/issues/000161-inline-term-definition.md) (R1
-added the bracket/highlight/undo).
+(grey `virtual_lines`) under the phrase. The selected text stays in place and
+gets a markdown footnote reference (`ASIN[^asin]`), while the definition is
+stored in a managed footnote footer at the end of the chat transcript. The
+whole annotation is **undoable** — `u` reverts the footnote edit and clears both
+decorations (see Undo below). For jargon you don't know (e.g. `ASIN`), it's a
+one-keystroke lookup. Added in
+[#161](../../workshop/issues/000161-inline-term-definition.md) (R1 added the
+highlight/undo); [#166](../../workshop/issues/000166-visual-selection-definition-system-manages-footnote.md)
+made the definition durable as a managed footnote.
 
 ## Flow
 
@@ -25,41 +27,61 @@ added the bracket/highlight/undo).
    prompt and asks the model to call `emit_definition({term, definition})`.
 4. **`render_definition`** (`on_done`), on a successful lookup: re-verifies the
    selection still holds the phrase (else skips — the buffer changed under the
-   in-flight call), then **(a)** wraps the term in `[term]` via one
-   `nvim_buf_set_lines` (`define.bracket_edit` plans it) — a single undo entry
-   that anchors everything; **(b)** highlights the line(s) whole-line
-   `DiffChange` (`skill_render.highlight_line`); **(c)** sets one INFO
-   `vim.diagnostic` on the selected term span after bracket insertion
-   (`define.diagnostic_span_after_bracket`, `define.format_definition` →
+   in-flight call), then **(a)** adds a `[^id]` reference after the selected term
+   and inserts/updates a final managed footnote footer via one buffer rewrite
+   (`define.apply_definition_footnote`) — a single undo entry that anchors
+   everything; **(b)** highlights the line(s) whole-line `DiffChange`
+   (`skill_render.highlight_line`); **(c)** sets one INFO `vim.diagnostic` on
+   the selected term/reference span (`define.format_definition` →
    `skill_render.wrap`) on the `parley_skill` namespace; **(d)** records the
    undo/redo projection states.
    `diag_display`'s `virtual_lines{current_line=true}` reveals the diagnostic
    (cursor parked on the term's line). A no-`emit_definition` response leaves no
-   bracket.
+   footnote reference/footer.
 
 ## Undo (`u`) — reuses review's projection
 
-Native `u` reverts *text*, not decorations. The `[term]` bracket is the one
-text change, so `u` reverts it; the decorations are cleared/restored by review's
+Native `u` reverts *text*, not decorations. The footnote reference/footer rewrite
+is the one text change, so `u` reverts it; the decorations are cleared/restored by review's
 **projection watcher** (`skills/review/projection.lua`, #133 M5), which define
 reuses: `render_definition` calls `projection.record_empty_for(buf, original)`
-(pre-bracket hash → empty snapshot), `record(buf)` (bracketed hash → the
-highlight + diagnostic), `ensure_watch(buf)`. Undoing the bracket lands on the
-pre-bracket content-hash → the empty snapshot renders → both decorations clear;
+(pre-footnote hash → empty snapshot), `record(buf)` (footnoted hash → the
+highlight + diagnostic), `ensure_watch(buf)`. Undoing the footnote edit lands on
+the pre-footnote content-hash → the empty snapshot renders → both decorations clear;
 `<C-r>` re-renders. The highlight must be **whole-line** because
 `skill_render.snapshot`/`apply_snapshot` are line-granular. `set_applying`
-brackets the edit so a prior define's watcher doesn't mistake it for a user edit.
+guards the edit so a prior define's watcher doesn't mistake it for a user edit.
 
 ## Pure core vs IO shell (ARCH-PURE)
 
 - **Pure** (`lua/parley/define.lua`, unit-tested with plain tables): `slice_selection`,
   `context_for_selection`, `format_definition`, `bracket_edit` (plans the `[term]`
-  wrap as a set_lines edit), `diagnostic_span_after_bracket` (maps the visual span
-  to the post-bracket diagnostic range).
-- **IO shell** (`lua/parley/init.lua`): `define_visual`, `render_definition`.
+  wrap as a legacy set_lines edit), `diagnostic_span_after_bracket` (legacy range
+  mapping), `apply_definition_footnote` (durable footer transform), and
+  `strip_definition_footnote_footer` (removes only a final `---` block followed
+  solely by footnotes).
+- **IO shell** (`lua/parley/init.lua`): `define_visual`, `render_definition`;
+  `lua/parley/buffer_edit.lua` owns the full-buffer footnote rewrite.
 - **External service** (Anthropic) exercised via the process-level fake reused
   from `skill_invoke_spec` (SSE tool-call injection).
 
+## Managed Footnote Footer
+
+The footer is a final markdown block:
+
+```markdown
+---
+
+[^asin]: Amazon Standard Identification Number.
+```
+
+The footer detector is deliberately conservative: only the last standalone
+`---` line followed by blank lines and footnote definitions counts as the
+managed footer. Ordinary horizontal rules and mixed prose after `---` remain
+chat content. `chat_respond.build_messages` strips this managed footer from
+message strings before LLM submission, so durable definitions do not become
+prompt context.
+
 ## Keybinding
 
 `<M-CR>` was split out of `chat_shortcut_respond` into its own `chat_define`
@@ -87,18 +109,18 @@ tool-call args (`result.calls[1].input`), read in `on_done`.
 
 ## v1 limitations
 
-- One definition visible at a time (`invoke` resets the `parley_skill` namespace
+- One diagnostic visible at a time (`invoke` resets the `parley_skill` namespace
   each turn); line-granular highlight (whole-line, required for the projection
-  round-trip). Dismissal is via `u` (R1) — reverting the bracket clears it; the
-  diagnostic also auto-hides when the cursor leaves the line. The `[term]`
-  brackets persist in the file if saved (the minimal-footprint tradeoff; the
-  definition text never is). Shared `parley_skill` namespace/projection with
-  review still applies (rare on chat buffers).
+  round-trip). Dismissal is via `u` — reverting the footnote reference/footer
+  clears it; the diagnostic also auto-hides when the cursor leaves the line.
+  The footnote persists in the file if saved. Shared `parley_skill`
+  namespace/projection with review still applies (rare on chat buffers).
 
 ## Key files
 
-- `lua/parley/define.lua` — pure core (slice / context / format).
+- `lua/parley/define.lua` — pure core (slice / context / format / footnote footer).
 - `lua/parley/init.lua` — `define_visual`, `render_definition`, `chat_define` wiring.
+- `lua/parley/chat_respond.lua` — strips managed footnote footer from LLM messages.
 - `lua/parley/skills/define/init.lua` — the unforced `define` skill.
 - `lua/parley/tools/builtin/emit_definition.lua` — output-only structured tool.
 - `lua/parley/skill_invoke.lua` — `opts.no_reload` / `opts.document` seams.
diff --git a/lua/parley/buffer_edit.lua b/lua/parley/buffer_edit.lua
index fff6b16..5c780b1 100644
--- a/lua/parley/buffer_edit.lua
+++ b/lua/parley/buffer_edit.lua
@@ -114,6 +114,11 @@ function M.replace_all_lines(buf, lines)
     vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
 end
 
+--- Replace the entire chat buffer after a pure definition-footnote transform.
+function M.replace_all_lines_for_definition(buf, lines)
+    M.replace_all_lines(buf, lines)
+end
+
 --- Append a section to an answer. The section is rendered via
 --- render_buffer.render_section. If the line at `after_line_0_indexed`
 --- is non-empty, a blank separator is inserted first so blocks don't
diff --git a/lua/parley/chat_respond.lua b/lua/parley/chat_respond.lua
index 473512a..031b4d3 100644
--- a/lua/parley/chat_respond.lua
+++ b/lua/parley/chat_respond.lua
@@ -334,6 +334,7 @@ M.build_messages_from_model = function(buf, model, target_idx, agent_info)
     local serialize = require("parley.tools.serialize")
     local system_prompt_msgs = require("parley.system_prompt_msgs")
     local prov = require("parley.providers")
+    local define = require("parley.define")
     append_neighborhood_context(agent_info, agent_info and agent_info.neighborhood_root)
     local messages = system_prompt_msgs.build(agent_info, function(provider)
         return prov.has_feature(provider, "cache_control")
@@ -374,6 +375,7 @@ M.build_messages_from_model = function(buf, model, target_idx, agent_info)
                 local text = read_block_text(k, b)
                 -- Strip 💬: prefix and trim
                 text = text:gsub("^💬:%s*", ""):gsub("^%s*(.-)%s*$", "%1")
+                text = define.strip_definition_footnote_footer(text)
                 if text ~= "" then
                     -- Defensive: an answer never precedes its question, but
                     -- flush any accumulated answer blocks to keep ordering stable.
@@ -385,7 +387,7 @@ M.build_messages_from_model = function(buf, model, target_idx, agent_info)
                 goto continue  -- not part of messages
 
             elseif blk.kind == "text" or blk.kind == "stream_placeholder" then
-                local text = read_block_text(k, b)
+                local text = define.strip_definition_footnote_footer(read_block_text(k, b))
                 if text:match("%S") then
                     table.insert(answer_blocks, { type = "text", text = text })
                 end
@@ -404,7 +406,7 @@ M.build_messages_from_model = function(buf, model, target_idx, agent_info)
                 else
                     -- Malformed tool_use — degrade to text so it's not
                     -- silently dropped. Claude sees the raw block text.
-                    table.insert(answer_blocks, { type = "text", text = text })
+                    table.insert(answer_blocks, { type = "text", text = define.strip_definition_footnote_footer(text) })
                 end
 
             elseif blk.kind == "tool_result" then
@@ -422,7 +424,7 @@ M.build_messages_from_model = function(buf, model, target_idx, agent_info)
                     -- preserving user/assistant alternation. Flush accumulated
                     -- answer blocks first so ordering is stable.
                     flush_answer()
-                    table.insert(messages, { role = "user", content = text })
+                    table.insert(messages, { role = "user", content = define.strip_definition_footnote_footer(text) })
                 end
             end
 
@@ -605,6 +607,18 @@ M.build_messages = function(opts)
     local opts_config = opts.config
     local helpers = opts.helpers
     local logger = opts.logger or { debug = function() end, warning = function() end }
+    local define = require("parley.define")
+    local function scrub_content_blocks(blocks)
+        local out = {}
+        for _, block in ipairs(blocks or {}) do
+            local copy = vim.deepcopy(block)
+            if copy.type == "text" and type(copy.text) == "string" then
+                copy.text = define.strip_definition_footnote_footer(copy.text)
+            end
+            out[#out + 1] = copy
+        end
+        return out
+    end
 
     -- Process headers for agent information
     local headers = parsed_chat.headers
@@ -685,7 +699,7 @@ M.build_messages = function(opts)
                 -- Process the question
                 if should_preserve then
                     -- Get the question content and process any file loading directives
-                    local question_content = exchange.question.content
+                    local question_content = define.strip_definition_footnote_footer(exchange.question.content)
                     local file_content_parts = {}
 
                     -- Raw request input feature: detect a `yaml {"type":"request"}`
@@ -786,24 +800,24 @@ M.build_messages = function(opts)
                     --   B. No tool blocks → single flat-string assistant
                     --      message (byte-identical to pre-#81).
                     if answer_has_tool_blocks then
-                        for _, m in ipairs(M._emit_content_blocks_as_messages(exchange.answer.content_blocks)) do
+                        for _, m in ipairs(M._emit_content_blocks_as_messages(scrub_content_blocks(exchange.answer.content_blocks))) do
                             table.insert(messages, m)
                         end
                     else
-                        table.insert(messages, { role = "assistant", content = exchange.answer.content })
+                        table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.answer.content) })
                     end
                 else
                     -- Use the summary if available
                     if exchange.summary then
-                        table.insert(messages, { role = "assistant", content = exchange.summary.content })
+                        table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.summary.content) })
                     else
                         -- If no summary is available, use the full content (fallback)
                         if answer_has_tool_blocks then
-                            for _, m in ipairs(M._emit_content_blocks_as_messages(exchange.answer.content_blocks)) do
+                            for _, m in ipairs(M._emit_content_blocks_as_messages(scrub_content_blocks(exchange.answer.content_blocks))) do
                                 table.insert(messages, m)
                             end
                         else
-                            table.insert(messages, { role = "assistant", content = exchange.answer.content })
+                            table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.answer.content) })
                         end
                     end
                 end
diff --git a/lua/parley/define.lua b/lua/parley/define.lua
index 5253cb6..bb460e8 100644
--- a/lua/parley/define.lua
+++ b/lua/parley/define.lua
@@ -127,4 +127,181 @@ function M.diagnostic_span_after_bracket(l1, c1, l2, c2)
     }
 end
 
+--- @param s string
+--- @return string
+local function trim(s)
+    local out = (s or ""):gsub("^%s*(.-)%s*$", "%1")
+    return out
+end
+
+--- Convert a term into a stable markdown footnote id.
+--- @param term string|nil
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
+    for i = #lines, 1, -1 do
+        if is_divider(lines[i]) then
+            local has_footnote = false
+            for j = i + 1, #lines do
+                local line = lines[j] or ""
+                if trim(line) ~= "" then
+                    if not is_footnote_line(line) then
+                        return nil
+                    end
+                    has_footnote = true
+                end
+            end
+            if has_footnote then
+                return i
+            end
+            return nil
+        end
+    end
+    return nil
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
+        for i = footer + 1, #out do
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
+    return out
+end
+
+--- Insert a markdown footnote reference after the selected text and store the
+--- definition in a managed footer.
+--- @param lines string[]
+--- @param l1 integer
+--- @param c1 integer 0-based byte column
+--- @param l2 integer
+--- @param c2 integer 0-based inclusive byte column
+--- @param term string
+--- @param definition string|nil
+--- @return table { lines: string[], id: string, definition: string, diagnostic_span: table }
+function M.apply_definition_footnote(lines, l1, c1, l2, c2, term, definition)
+    local id = M.footnote_id(term)
+    local ref = "[^" .. id .. "]"
+    local out = copy_lines(lines)
+    if l1 == l2 then
+        local line = out[l1] or ""
+        local ec = math.min(c2 + 1, #line)
+        out[l1] = line:sub(1, ec) .. ref .. line:sub(ec + 1)
+    else
+        local line = out[l2] or ""
+        local ec = math.min(c2 + 1, #line)
+        out[l2] = line:sub(1, ec) .. ref .. line:sub(ec + 1)
+    end
+    out = replace_or_append_footnote(out, id, definition)
+    local normalized_definition = trim(definition)
+    if normalized_definition == "" then
+        normalized_definition = "(no definition)"
+    end
+    return {
+        lines = out,
+        id = id,
+        definition = normalized_definition,
+        diagnostic_span = {
+            lnum = l1 - 1,
+            col = c1,
+            end_lnum = l2 - 1,
+            end_col = c2 + 1 + #ref,
+        },
+    }
+end
+
 return M
diff --git a/lua/parley/init.lua b/lua/parley/init.lua
index 67429aa..351ade5 100644
--- a/lua/parley/init.lua
+++ b/lua/parley/init.lua
@@ -1592,18 +1592,18 @@ local function drill_in_visual(buf)
 	vim.schedule(function() vim.cmd("startinsert") end)
 end
 
--- Inline term definition (#161 + R1). render_definition is the on_done IO seam.
--- On a successful lookup it wraps the term in a [term] reference bracket (ONE
--- undo entry — the anchor), highlights the line (whole-line DiffChange, review's
--- scheme), and shows the definition as an ephemeral INFO diagnostic. The
--- definition text is never written to the file; only the brackets are. Undo/redo
--- coherence reuses review's projection watcher: undoing the bracket lands on the
--- pre-bracket content-hash → the empty snapshot renders → both decorations clear.
+-- Inline term definition (#161 + R1, #166). render_definition is the on_done IO
+-- seam. On a successful lookup it stores the definition as a durable markdown
+-- footnote (ONE undo entry — the anchor), highlights the line (whole-line
+-- DiffChange, review's scheme), and shows the definition as an ephemeral INFO
+-- diagnostic. Undo/redo coherence reuses review's projection watcher: undoing
+-- the footnote edit lands on the pre-edit content-hash → the empty snapshot
+-- renders → both decorations clear.
 -- `span` = the visual selection {sr, sc, er, ec} (1-based getpos values).
 local function render_definition(buf, span, phrase, result)
 	-- Pick the emit_definition call (unforced → the model may answer in text or
 	-- only call web_search; both mean "no definition"). Notify rather than
-	-- silently doing nothing, and leave no bracket.
+	-- silently doing nothing, and leave no footnote edit.
 	local call
 	if result and result.calls then
 		for _, c in ipairs(result.calls) do
@@ -1623,32 +1623,30 @@ local function render_definition(buf, span, phrase, result)
 	local skill_render = require("parley.skill_render")
 	local projection = require("parley.skills.review.projection")
 
-	-- The buffer may have changed under the in-flight call; skip bracketing (and
-	-- the whole render) rather than mis-place a bracket on shifted text.
+	-- The buffer may have changed under the in-flight call; skip the whole render
+	-- rather than attach a footnote reference to shifted text.
 	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
 	if define.slice_selection(lines, sr, sc - 1, er, ec - 1) ~= phrase then
 		M.logger.warning("Define: selection changed during lookup — re-select to define")
 		return
 	end
-	local original = table.concat(lines, "\n") -- pre-bracket content (undo base)
+	local original = table.concat(lines, "\n") -- pre-edit content (undo base)
 
-	-- Wrap the term in [term] as ONE set_lines edit (single undo entry = the
-	-- anchor; nvim_buf_set_text is arch-confined to buffer_edit, and set_lines is
-	-- how drill_in_visual wraps a selection too). set_applying suppresses any
-	-- prior define's projection watcher during our own edit (mirrors review).
+	-- Store the definition as a markdown footnote in ONE full-buffer set_lines
+	-- edit (single undo entry = the anchor). set_applying suppresses any prior
+	-- define's projection watcher during our own edit (mirrors review).
 	projection.set_applying(buf, true)
-	local e = define.bracket_edit(lines, sr, sc - 1, er, ec - 1)
-	vim.api.nvim_buf_set_lines(buf, e.first0, e.last, false, e.lines)
+	local input = call.input or {}
+	local e = define.apply_definition_footnote(lines, sr, sc - 1, er, ec - 1, input.term or phrase, input.definition)
+	require("parley.buffer_edit").replace_all_lines_for_definition(buf, e.lines)
 
 	-- Highlight the term's line(s) + the ephemeral definition diagnostic.
-	local last0 = e.first0 + #e.lines - 1
-	for line0 = e.first0, last0 do
+	for line0 = sr - 1, er - 1 do
 		skill_render.highlight_line(buf, line0)
 	end
-	local input = call.input or {}
 	local width = math.max(40, vim.api.nvim_win_get_width(0) - 8)
-	local msg = define.format_definition(input.term, input.definition, width)
-	local diag_span = define.diagnostic_span_after_bracket(sr, sc, er, ec)
+	local msg = define.format_definition(input.term or phrase, e.definition, width)
+	local diag_span = e.diagnostic_span
 	vim.diagnostic.set(skill_render.diag_namespace(), buf, { {
 		lnum = diag_span.lnum,
 		col = diag_span.col,
@@ -1659,9 +1657,9 @@ local function render_definition(buf, span, phrase, result)
 		source = "parley-define",
 	} })
 
-	-- Record projection states so undo/redo of the bracket clears/restores the
-	-- decorations (#133 M5 machinery, reused): pre-bracket hash → empty snapshot,
-	-- bracketed hash → highlight+diagnostic; attach the watcher for future undos.
+	-- Record projection states so undo/redo of the footnote edit clears/restores
+	-- the decorations (#133 M5 machinery, reused): pre-edit hash → empty
+	-- snapshot, footnoted hash → highlight+diagnostic; attach the watcher.
 	projection.record_empty_for(buf, original)
 	projection.record(buf)
 	projection.ensure_watch(buf)
@@ -1675,7 +1673,7 @@ end
 
 -- define_visual: the thin IO shell for visual-mode <M-CR>. Reads the selection,
 -- computes the enclosing-exchange context, and fires a headless define skill
--- turn whose on_done brackets + renders the definition inline. Pure logic lives
+-- turn whose on_done stores + renders the definition inline. Pure logic lives
 -- in lua/parley/define.lua. Exposed as M.define_visual for the keybinding.
 function M.define_visual(buf)
 	buf = buf or vim.api.nvim_get_current_buf()
diff --git a/tests/integration/define_spec.lua b/tests/integration/define_spec.lua
index 9998aba..ec7b8b0 100644
--- a/tests/integration/define_spec.lua
+++ b/tests/integration/define_spec.lua
@@ -238,7 +238,7 @@ describe("define_visual + render_definition (#161)", function()
         return false
     end
 
-    it("brackets the term, highlights the line, and shows the diagnostic (R1)", function()
+    it("stores the definition as a durable footnote, highlights the line, and shows the diagnostic", function()
         -- select "ASIN" on line 3 (cols 9..12, 1-based)
         vim.fn.setpos("'<", { buf, 3, 9, 0 })
         vim.fn.setpos("'>", { buf, 3, 12, 0 })
@@ -246,31 +246,36 @@ describe("define_visual + render_definition (#161)", function()
         vim.wait(2000, function()
             return #vim.diagnostic.get(buf, { namespace = ns }) > 0
         end)
-        -- [term] bracket written into the line (the undo anchor)
-        assert.are.equal("here is [ASIN] in context",
+        -- Footnote reference written into the line (the undo anchor)
+        assert.are.equal("here is ASIN[^asin] in context",
             vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1])
+        assert.are.same({
+            "---",
+            "",
+            "[^asin]: Amazon Standard Identification Number.",
+        }, vim.api.nvim_buf_get_lines(buf, 5, 8, false))
         -- diagnostic on the term's line
         local diags = vim.diagnostic.get(buf, { namespace = ns })
         assert.are.equal(2, diags[1].lnum) -- 0-based line 3
-        assert.are.equal(9, diags[1].col) -- selected ASIN after inserted "["
+        assert.are.equal(8, diags[1].col)
         assert.are.equal(2, diags[1].end_lnum)
-        assert.are.equal(13, diags[1].end_col) -- exclusive, before inserted "]"
+        assert.are.equal(19, diags[1].end_col) -- ASIN plus [^asin]
         assert.is_true(diags[1].message:find("ASIN", 1, true) ~= nil)
         -- whole-line DiffChange highlight on the hl namespace, on line 3
         assert.is_true(hl_on_line(buf, 2), "term line not highlighted")
     end)
 
-    it("u undoes the bracket + clears decorations; C-r restores them (R1)", function()
+    it("u undoes the footnote edit + clears decorations; C-r restores them (R1)", function()
         vim.fn.setpos("'<", { buf, 3, 9, 0 })
         vim.fn.setpos("'>", { buf, 3, 12, 0 })
         require("parley").define_visual(buf)
         vim.wait(2000, function()
             return #vim.diagnostic.get(buf, { namespace = ns }) > 0
         end)
-        assert.are.equal("here is [ASIN] in context",
+        assert.are.equal("here is ASIN[^asin] in context",
             vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1])
 
-        -- undo: the bracket reverts; the projection watcher (TextChanged) clears
+        -- undo: the footnote edit reverts; the projection watcher (TextChanged) clears
         -- both decorations. Fire the autocmd Vim fires interactively — headless
         -- :undo doesn't trigger TextChanged on its own (the watcher itself is
         -- covered by projection's own specs; here we verify define's records).
@@ -278,14 +283,16 @@ describe("define_visual + render_definition (#161)", function()
         vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
         assert.are.equal("here is ASIN in context",
             vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1])
+        assert.is_nil(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
+            :find("%[%^asin%]:", 1, false), "footnote not removed on undo")
         assert.are.equal(0, #vim.diagnostic.get(buf, { namespace = ns }),
             "diagnostic not cleared on undo")
         assert.is_false(hl_on_line(buf, 2), "highlight not cleared on undo")
 
-        -- redo: bracket + decorations return
+        -- redo: footnote edit + decorations return
         vim.cmd("silent redo")
         vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
-        assert.are.equal("here is [ASIN] in context",
+        assert.are.equal("here is ASIN[^asin] in context",
             vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1])
         assert.is_true(#vim.diagnostic.get(buf, { namespace = ns }) >= 1,
             "diagnostic not restored on redo")
@@ -319,7 +326,7 @@ describe("define_visual + render_definition (#161)", function()
             "a no-tool response must not set a diagnostic")
         assert.are.equal("here is ASIN in context",
             vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1],
-            "a no-tool response must not bracket the term")
+            "a no-tool response must not footnote the term")
     end)
 end)
 
diff --git a/tests/unit/build_messages_spec.lua b/tests/unit/build_messages_spec.lua
index bdd3eb0..429ef48 100644
--- a/tests/unit/build_messages_spec.lua
+++ b/tests/unit/build_messages_spec.lua
@@ -704,6 +704,109 @@ describe("_build_messages: range filtering", function()
     end)
 end)
 
+describe("_build_messages: durable definition footnotes", function()
+    it("strips managed definition footnote footers from user and assistant content", function()
+        local question = table.concat({
+            "What is ASIN?",
+            "",
+            "---",
+            "",
+            "[^asin]: Amazon Standard Identification Number.",
+        }, "\n")
+        local answer = table.concat({
+            "ASIN is an identifier.",
+            "",
+            "---",
+            "",
+            "[^asin]: Amazon Standard Identification Number.",
+        }, "\n")
+        local pc = parsed_chat({ exchange(question, answer), exchange("Next") })
+        pc.exchanges[1].question.line_start = 10
+        pc.exchanges[1].answer.line_start = 12
+        pc.exchanges[2].question.line_start = 20
+
+        local messages = parley._build_messages({
+            parsed_chat = pc,
+            start_index = 1,
+            end_index = 100,
+            exchange_idx = 2,
+            agent = agent(),
+            config = parley.config,
+            helpers = stub_helpers,
+            logger = stub_logger
+        })
+
+        assert.equals("What is ASIN?", messages[2].content)
+        assert.equals("ASIN is an identifier.", messages[3].content)
+        assert.is_nil(messages[2].content:find("%[%^asin%]:"))
+        assert.is_nil(messages[3].content:find("%[%^asin%]:"))
+    end)
+
+    it("preserves ordinary horizontal-rule content that is not a managed footer", function()
+        local answer = table.concat({
+            "first half",
+            "",
+            "---",
+            "",
+            "second half, not a footnote",
+        }, "\n")
+        local pc = parsed_chat({ exchange("Q", answer), exchange("Next") })
+        pc.exchanges[1].question.line_start = 10
+        pc.exchanges[1].answer.line_start = 12
+        pc.exchanges[2].question.line_start = 20
+
+        local messages = parley._build_messages({
+            parsed_chat = pc,
+            start_index = 1,
+            end_index = 100,
+            exchange_idx = 2,
+            agent = agent(),
+            config = parley.config,
+            helpers = stub_helpers,
+            logger = stub_logger
+        })
+
+        assert.equals(answer, messages[3].content)
+    end)
+
+    it("keeps earlier horizontal-rule content and strips only the final managed footer", function()
+        local answer = table.concat({
+            "first half",
+            "",
+            "---",
+            "",
+            "second half",
+            "",
+            "---",
+            "",
+            "[^asin]: Amazon Standard Identification Number.",
+        }, "\n")
+        local pc = parsed_chat({ exchange("Q", answer), exchange("Next") })
+        pc.exchanges[1].question.line_start = 10
+        pc.exchanges[1].answer.line_start = 12
+        pc.exchanges[2].question.line_start = 20
+
+        local messages = parley._build_messages({
+            parsed_chat = pc,
+            start_index = 1,
+            end_index = 100,
+            exchange_idx = 2,
+            agent = agent(),
+            config = parley.config,
+            helpers = stub_helpers,
+            logger = stub_logger
+        })
+
+        assert.equals(table.concat({
+            "first half",
+            "",
+            "---",
+            "",
+            "second half",
+        }, "\n"), messages[3].content)
+    end)
+end)
+
 describe("_build_messages: whitespace trimming", function()
     it("trims leading and trailing whitespace from all message content", function()
         local ex = exchange("  Question with spaces  ", "  Answer with spaces  ")
@@ -1499,6 +1602,58 @@ describe("build_messages_from_model: dangling tool_use synthesized on the live p
     end)
 end)
 
+describe("build_messages_from_model: durable definition footnotes", function()
+    local exchange_model = require("parley.exchange_model")
+
+    it("strips managed footnote footers from live question and answer blocks", function()
+        local question_lines = {
+            "💬: What is ASIN?",
+            "",
+            "---",
+            "",
+            "[^asin]: Amazon Standard Identification Number.",
+        }
+        local answer_lines = {
+            "ASIN is an identifier.",
+            "",
+            "---",
+            "",
+            "[^asin]: Amazon Standard Identification Number.",
+        }
+        local header = { "topic: t", "---" }
+        local header_lines = #header
+        local model = exchange_model.new(header_lines)
+        model:add_exchange(#question_lines)
+        model:add_block(1, "agent_header", 1)
+        model:add_block(1, "text", #answer_lines)
+
+        local q0 = model:block_start(1, 1)
+        local ah0 = model:block_start(1, 2)
+        local text0 = model:block_start(1, 3)
+        local total = text0 + #answer_lines
+        local lines = {}
+        for i = 1, total do lines[i] = "" end
+        for i = 1, header_lines do lines[i] = header[i] end
+        for i, line in ipairs(question_lines) do lines[q0 + i] = line end
+        lines[ah0 + 1] = "🤖: [assistant]"
+        for i, line in ipairs(answer_lines) do lines[text0 + i] = line end
+
+        local buf = vim.api.nvim_create_buf(false, true)
+        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
+
+        local agent_info = { system_prompt = "You are helpful.", model = "gpt-4o", provider = "openai" }
+        local msgs = require("parley.chat_respond").build_messages_from_model(buf, model, 1, agent_info)
+
+        assert.equals("What is ASIN?", msgs[2].content)
+        assert.equals("assistant", msgs[3].role)
+        assert.equals("ASIN is an identifier.", msgs[3].content[1].text)
+        assert.is_nil(msgs[2].content:find("%[%^asin%]:"))
+        assert.is_nil(msgs[3].content[1].text:find("%[%^asin%]:"))
+
+        vim.api.nvim_buf_delete(buf, { force = true })
+    end)
+end)
+
 --------------------------------------------------------------------------------
 -- #156: orphan / duplicate tool_result is dropped at message-emission — the
 -- symmetric half of #155. A tool_result whose id has no matching (still-pending)
diff --git a/tests/unit/define_spec.lua b/tests/unit/define_spec.lua
index 0f49a24..227bc76 100644
--- a/tests/unit/define_spec.lua
+++ b/tests/unit/define_spec.lua
@@ -125,3 +125,100 @@ describe("define.diagnostic_span_after_bracket", function()
         }, span)
     end)
 end)
+
+describe("define durable footnotes", function()
+    it("slugifies a definition term into a markdown footnote id", function()
+        assert.equals("amazon-standard-identification-number",
+            define.footnote_id("Amazon Standard Identification Number"))
+        assert.equals("asin", define.footnote_id("ASIN"))
+    end)
+
+    it("adds an inline footnote reference and appends a managed footer", function()
+        local result = define.apply_definition_footnote(
+            { "here is ASIN in context" },
+            1, 8, 1, 11,
+            "ASIN",
+            "Amazon Standard Identification Number."
+        )
+
+        assert.are.same({
+            "here is ASIN[^asin] in context",
+            "",
+            "---",
+            "",
+            "[^asin]: Amazon Standard Identification Number.",
+        }, result.lines)
+        assert.are.same({ lnum = 0, col = 8, end_lnum = 0, end_col = 19 }, result.diagnostic_span)
+        assert.equals("asin", result.id)
+        assert.equals("Amazon Standard Identification Number.", result.definition)
+    end)
+
+    it("updates an existing managed footnote instead of duplicating it", function()
+        local result = define.apply_definition_footnote(
+            {
+                "ASIN is here",
+                "",
+                "---",
+                "",
+                "[^asin]: old definition",
+            },
+            1, 0, 1, 3,
+            "ASIN",
+            "Amazon Standard Identification Number."
+        )
+
+        assert.are.same({
+            "ASIN[^asin] is here",
+            "",
+            "---",
+            "",
+            "[^asin]: Amazon Standard Identification Number.",
+        }, result.lines)
+    end)
+
+    it("strips only a final managed footnote footer", function()
+        local text = table.concat({
+            "answer text",
+            "",
+            "---",
+            "",
+            "[^asin]: Amazon Standard Identification Number.",
+        }, "\n")
+
+        assert.equals("answer text", define.strip_definition_footnote_footer(text))
+    end)
+
+    it("preserves ordinary horizontal rules that are not managed footnote footers", function()
+        local text = table.concat({
+            "answer text",
+            "",
+            "---",
+            "",
+            "not a footnote",
+        }, "\n")
+
+        assert.equals(text, define.strip_definition_footnote_footer(text))
+    end)
+
+    it("keeps earlier horizontal-rule content and strips only the final managed footer", function()
+        local text = table.concat({
+            "answer text",
+            "",
+            "---",
+            "",
+            "ordinary body after a rule",
+            "",
+            "---",
+            "",
+            "[^asin]: Amazon Standard Identification Number.",
+        }, "\n")
+
+        assert.equals(table.concat({
+            "answer text",
+            "",
+            "---",
+            "",
+            "ordinary body after a rule",
+        }, "\n"), define.strip_definition_footnote_footer(text))
+    end)
+end)
diff --git a/workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md b/workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md
new file mode 100644
index 0000000..9b9a18c
--- /dev/null
+++ b/workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md
@@ -0,0 +1,224 @@
+# Durable Definition Footnotes Implementation Plan
+
+> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.
+
+**Goal:** Persist visual-selection definitions as managed markdown footnotes while keeping the durable footnote section out of LLM submissions.
+
+**Architecture:** Keep document transforms in `lua/parley/define.lua` as pure helpers (ARCH-PURE), put buffer writes behind `lua/parley/buffer_edit.lua`, and keep `render_definition` as the thin IO shell that stitches lookup results to the pure transform. `chat_respond.build_messages` receives already-parsed exchanges, so it will scrub only the managed final footnote footer from question/answer strings before adding messages (ARCH-PURPOSE).
+
+**Tech Stack:** Lua, Neovim buffer APIs via `buffer_edit`, Plenary/Busted tests, existing Parley skill invocation and diagnostic rendering.
+
+---
+
+## Core Concepts
+
+### Pure Entities
+
+| Name | Lives in | Status |
+|------|----------|--------|
+| `DefinitionFootnote` | `lua/parley/define.lua` | new |
+| `DefinitionFootnoteFooter` | `lua/parley/define.lua` | new |
+| `DefinitionSubmissionScrubber` | `lua/parley/define.lua` | new |
+
+- **DefinitionFootnote** — a durable markdown footnote pair: inline reference `[^definition]` plus footer line `[^definition]: ...`.
+  - **Relationships:** N:1 with a chat file; many selected terms may create footnotes in one managed footer.
+  - **DRY rationale:** One source handles slugging, reference text, and footer line formatting instead of duplicating string construction in render and tests.
+  - **Future extensions:** Conflict handling can widen from numeric suffixes to stable IDs or renames without changing render callers.
+
+- **DefinitionFootnoteFooter** — pure transform that inserts or updates a managed footnote section after the transcript separator.
+  - **Relationships:** Owns the footer section lines; consumed by `buffer_edit.replace_all_lines`.
+  - **DRY rationale:** Keeps footer location, divider insertion, replacement policy, and footer-boundary recognition together.
+  - **Future extensions:** Can support multiple footer groups or metadata comments if the managed section needs migration.
+
+- **DefinitionSubmissionScrubber** — pure helper that removes the managed footnote footer from strings before they are sent to the LLM.
+  - **Relationships:** Consumed by `chat_respond.build_messages`; separate from parser so parse positions remain truthful to the buffer.
+  - **DRY rationale:** The same footer boundary rule protects user and assistant content.
+  - **Future extensions:** If other local-only transcript sections appear, this helper can become a generic local-footer scrubber.
+
+### Integration Points
+
+| Name | Lives in | Status | Wraps |
+|------|----------|--------|-------|
+| `render_definition` | `lua/parley/init.lua` | modified | Neovim diagnostics/projection |
+| `DefinitionBufferEdit` | `lua/parley/buffer_edit.lua` | modified | `nvim_buf_set_lines` |
+| `chat_respond.build_messages` | `lua/parley/chat_respond.lua` | modified | LLM payload construction |
+
+- **render_definition** — after `emit_definition`, verifies the selection, rewrites the selected text to include a footnote reference, stores/updates the managed footer, and attaches the current-line diagnostic from the durable footnote text.
+  - **Injected into:** Existing `skill_invoke.invoke` `on_done` callback.
+  - **Future extensions:** On-cursor rehydration can later read existing footnotes without a new LLM call.
+
+- **DefinitionBufferEdit** — chat-buffer mutation entry point for full-buffer definition-footnote rewrites.
+  - **Injected into:** `render_definition`.
+  - **Future extensions:** Can narrow to range edits if the footer transform later returns minimal edit hunks.
+
+- **chat_respond.build_messages** — strips managed definition footnotes from preserved and summarized exchange content.
+  - **Injected into:** Existing chat response pipeline.
+  - **Future extensions:** Live-model recursion path can consume the same scrubber if footnotes ever appear during tool-loop recursion.
+
+---
+
+## Chunk 1: Pure Footnote Transforms
+
+**Files:**
+- Modify: `lua/parley/define.lua`
+- Test: `tests/unit/define_spec.lua`
+
+- [x] **Step 1: Write failing tests for slug/reference/footer transform**
+
+Add tests showing:
+- `footnote_id("Amazon Standard Identification Number")` returns `amazon-standard-identification-number`.
+- `apply_definition_footnote` changes `here is ASIN in context` to `here is ASIN[^asin] in context`.
+- It appends a managed footer:
+
+```markdown
+---
+
+[^asin]: Amazon Standard Identification Number.
+```
+
+- Reapplying the same id updates/replaces the footer line rather than duplicating it.
+
+Run: `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`
+
+Expected: FAIL because the helpers do not exist yet.
+
+- [x] **Step 2: Implement pure helpers minimally**
+
+In `lua/parley/define.lua`, add:
+- `footnote_id(term)`
+- `format_footnote_line(id, definition)`
+- `apply_definition_footnote(lines, l1, c1, l2, c2, term, definition)`
+- `strip_definition_footnote_footer(text)`
+
+Keep all helpers deterministic and free of Neovim API calls. Preserve the existing selection text; only append `[^id]` after the selected span. For this issue, single-line selections are the required path; multi-line can return a conservative full-line transform using the existing selection slice if straightforward, but do not add a broad markdown engine.
+
+The managed footer predicate is exact and shared by insertion/update and stripping:
+- scan for the last standalone line whose trimmed text is exactly `---`;
+- treat it as the managed footer only if every following nonblank line matches `^%[%^[^%]]+%]:`;
+- otherwise no managed footer exists and the content must remain untouched.
+
+Add negative tests that prove ordinary horizontal rules are preserved when the trailing block contains non-footnote prose.
+
+- [x] **Step 3: Verify pure tests pass**
+
+Run: `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`
+
+Expected: PASS.
+
+---
+
+## Chunk 2: Render Visual Definitions as Durable Footnotes
+
+**Files:**
+- Modify: `lua/parley/init.lua`
+- Modify: `lua/parley/buffer_edit.lua`
+- Test: `tests/integration/define_spec.lua`
+
+- [x] **Step 1: Update the integration test to expect footnotes**
+
+Replace the bracket assertion in `define_visual + render_definition`:
+- selected line becomes `here is ASIN[^asin] in context`
+- footer exists at end of file with `[^asin]: Amazon Standard Identification Number.`
+- diagnostic message still includes `ASIN`
+- diagnostic range anchors to selected text plus footnote reference as appropriate for the current render.
+
+Run: `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`
+
+Expected: FAIL because render still writes `[ASIN]`.
+
+- [x] **Step 2: Add buffer edit wrapper**
+
+In `lua/parley/buffer_edit.lua`, add a named wrapper such as `replace_all_lines_for_definition(buf, lines)` delegating to `replace_all_lines`. This keeps call sites semantically clear and avoids adding new direct `nvim_buf_set_lines` callers.
+
+- [x] **Step 3: Wire `render_definition` to the pure transform**
+
+In `lua/parley/init.lua`:
+- Replace `define.bracket_edit` with `define.apply_definition_footnote`.
+- Use `buffer_edit.replace_all_lines_for_definition` for the rewrite.
+- Keep `projection.record_empty_for`, `projection.record`, and `ensure_watch` so undo/redo remains coherent.
+- Set the diagnostic text from the durable footnote definition. The diagnostic itself remains ephemeral, but its source text is now persisted.
+
+- [x] **Step 4: Verify focused integration**
+
+Run:
+- `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`
+- `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`
+
+Expected: PASS.
+
+---
+
+## Chunk 3: Exclude Managed Footnotes from LLM Submission
+
+**Files:**
+- Modify: `lua/parley/chat_respond.lua`
+- Test: `tests/unit/build_messages_spec.lua`
+
+- [x] **Step 1: Write failing build-message test**
+
+Add a test where preserved question/answer content contains:
+
+```markdown
+answer text
+
+---
+
+[^asin]: Amazon Standard Identification Number.
+```
+
+Assert built messages contain `answer text` but not `[^asin]:`.
+
+Also add tests proving:
+- `answer\n\n---\n\nnot a footnote` is not stripped.
+- A message with an earlier horizontal rule and a final managed footnote block keeps the earlier horizontal rule content and strips only the final managed block.
+- Both user and assistant content pass through the same `strip_definition_footnote_footer` helper.
+
+Run: `nvim --headless -c "PlenaryBustedFile tests/unit/build_messages_spec.lua"`
+
+Expected: FAIL because footer text is currently submitted as content.
+
+- [x] **Step 2: Apply the scrubber at message construction boundaries**
+
+In `chat_respond.build_messages`, call `define.strip_definition_footnote_footer` before inserting string question/answer/summary content into `messages`. Keep content-block arrays unchanged unless they contain text blocks created from parsed answer strings; for the parse path, scrub flat string content first.
+
+- [x] **Step 3: Verify build-message test**
+
+Run: `nvim --headless -c "PlenaryBustedFile tests/unit/build_messages_spec.lua"`
+
+Expected: PASS.
+
+- [x] **Step 4: Cover the live model path**
+
+Add a `build_messages_from_model` regression using a real exchange model and
+buffer lines, proving the recursive/live path strips the same managed footer
+from question and answer text.
+
+---
+
+## Chunk 4: Docs and Final Verification
+
+**Files:**
+- Modify: `atlas/chat/inline_define.md`
+- Modify: `workshop/issues/000166-visual-selection-definition-system-manages-footnote.md`
+
+- [x] **Step 1: Update atlas**
+
+Update `atlas/chat/inline_define.md` to describe durable footnotes, managed footer, and LLM-submission exclusion.
+
+- [x] **Step 2: Mark issue checklist and log**
+
+Tick issue plan items and log red/green evidence.
+
+- [x] **Step 3: Full verification**
+
+Run:
+- `git diff --check -- lua/parley/define.lua lua/parley/init.lua lua/parley/buffer_edit.lua lua/parley/chat_respond.lua tests/unit/define_spec.lua tests/integration/define_spec.lua tests/unit/build_messages_spec.lua atlas/chat/inline_define.md workshop/issues/000166-visual-selection-definition-system-manages-footnote.md`
+- `make test`
+
+Expected: all pass.
+
+Actual: focused define, integration define, and build-message specs passed;
+`git diff --check` passed; final `make test` passed on rerun with 0 lint
+warnings/errors and all unit, integration, and arch tests green. The repeated
+rerun was needed because `tests/unit/tools_builtin_find_spec.lua` flaked in the
+parallel full-suite run but passed each time it was run in isolation.


codex
I’ll use the required startup/workflow instructions first, then review the issue, plan, and diff against the requested boundary window.
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

codex
I’ve loaded the workflow contract and repo lessons. Now I’m checking the actual issue/plan files and the changed code at `HEAD` so the review is against repository state, not just the pasted diff.
exec
/bin/zsh -lc "sed -n '1,260p' workshop/issues/000166-visual-selection-definition-system-manages-footnote.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
---
id: 000166
status: working
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 2.29
started: 2026-07-08T08:45:50-07:00
---

# move visual selection definition system to be based on durable footnote

Right now, the definition is inserted as diagnosis, and convert the text to [anchor text]. Persisting the definition is useful, and let's do that. It works roughly like the following:

1. when a `definition` is selected and queried, we do the same LLM call, get back definition. 
2. then we insert a footnote for that definition: [^definition]: .... 
3. at end of chat transcript, we manage a section of footnote. footnote is separated from main chat with a divider line ---. 
4. then we stop converting definition to anchor text [definition] as we have definition [^definition]. 
5. diagnosis should pull definition stored in footnote directly. 
6. footnote is not submitted to LLM.

## Problem

Inline visual definitions currently write only an ephemeral diagnostic and a
minimal `[term]` text anchor. The definition itself disappears from the chat
file, so the lookup cannot be preserved or reloaded as durable transcript state.
Persisting the definition in ordinary markdown footnotes solves that, but the
managed footnote block must not become part of the next LLM prompt.

## Spec

Visual-selecting a term and invoking definition keeps the existing LLM lookup
and diagnostic behavior, but the durable text edit changes:

- The selected text remains readable in place and gains a markdown footnote
  reference: `term[^term]`.
- The definition is stored in a managed footnote footer at the end of the chat
  transcript, separated from the main chat by `---`.
- The managed footer is recognized only as a final block: the last standalone
  `---` line in the content, followed only by blank lines and markdown footnote
  definitions (`[^id]: text`). Any ordinary horizontal rule, or any trailing
  block that mixes non-footnote prose after `---`, stays part of chat content.
- Re-defining an existing term updates the corresponding managed footnote line
  instead of duplicating it.
- The diagnostic text is still shown inline, but it is derived from the stored
  footnote definition rather than being the only copy of the definition.
- The managed footnote footer is stripped from message content before payload
  construction so it is not submitted to the LLM.

ARCH-PURE: footnote slugging, footer insertion/update, and footer stripping live
in `lua/parley/define.lua` as pure helpers with unit coverage. ARCH-DRY: the same
footer boundary helper protects both user and assistant message content.
ARCH-PURPOSE: this is not complete unless both persistence and LLM-exclusion are
implemented.

## Done when

- Defining `ASIN` rewrites the line to include `ASIN[^asin]` and appends or
  updates `[^asin]: ...` in a footer after a `---` divider.
- Existing no-definition and empty-selection safeguards remain intact.
- Built LLM messages exclude only the managed final footnote footer; ordinary
  `---` content remains submitted.
- Focused define/build-message tests and the full suite pass.

## Estimate

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.20 impl=0.00
item: lua-neovim design=0.60 impl=1.00
item: atlas-docs design=0.00 impl=0.05
item: milestone-review design=0.00 impl=0.20
design-buffer: 0.30
total: 2.29
```

## Plan

- [x] Implement pure definition-footnote helpers in `lua/parley/define.lua`.
- [x] Render visual definitions as durable markdown footnotes while preserving
      diagnostics and undo/redo projection.
- [x] Strip managed definition footnotes from LLM message content.
- [x] Update inline-define atlas docs and run focused/full verification.

## Log

### 2026-07-08
- Claimed issue, wrote durable plan, and passed `sdlc change-code` after refining
  the managed-footer predicate to avoid naive `---` stripping.
- TDD red/green:
  `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"` first
  failed on missing footnote helpers, then passed after adding pure helpers.
- TDD red/green:
  `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`
  first failed on `[ASIN]` output, then passed after rendering durable footnotes.
- TDD red/green:
  `nvim --headless -c "PlenaryBustedFile tests/unit/build_messages_spec.lua"`
  first failed with `[^asin]:` leaking into messages, then passed after wiring
  `define.strip_definition_footnote_footer` through message construction.
- Added live-model coverage for `build_messages_from_model` so recursive
  tool-loop payload construction also strips managed definition footers.
- Verification:
  `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"` passed
  (21 tests);
  `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`
  passed (14 tests);
  `nvim --headless -c "PlenaryBustedFile tests/unit/build_messages_spec.lua"`
  passed (56 tests);
  `git diff --check -- lua/parley/define.lua lua/parley/init.lua lua/parley/buffer_edit.lua lua/parley/chat_respond.lua tests/unit/define_spec.lua tests/integration/define_spec.lua tests/unit/build_messages_spec.lua atlas/chat/inline_define.md workshop/issues/000166-visual-selection-definition-system-manages-footnote.md workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md`
  passed.
- Full verification: first `make test` run hit an unrelated transient failure
  in `tests/unit/tools_builtin_find_spec.lua`; the spec passed in isolation, and
  a second `make test` passed with 0 lint warnings/errors and all unit,
  integration, and arch tests green. After replacing `define.lua`'s remaining
  Neovim table helpers with Lua-only helpers, the focused specs still passed;
  `make test` hit the same transient `tools_builtin_find_spec.lua` flake once,
  passed in isolation again, then the final `make test` passed with 0 lint
  warnings/errors and all unit, integration, and arch tests green.

exec
/bin/zsh -lc 'git diff --stat 7f591d9dad8444b180a84a82ad02a9c239cfc6e2..HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
 atlas/chat/inline_define.md                        |  82 +++++---
 lua/parley/buffer_edit.lua                         |   5 +
 lua/parley/chat_respond.lua                        |  32 ++-
 lua/parley/define.lua                              | 177 ++++++++++++++++
 lua/parley/init.lua                                |  50 +++--
 tests/integration/define_spec.lua                  |  29 ++-
 tests/unit/build_messages_spec.lua                 | 155 ++++++++++++++
 tests/unit/define_spec.lua                         |  97 +++++++++
 ...selection-definition-system-manages-footnote.md |  92 ++++++++-
 ...tion-definition-system-manages-footnote-plan.md | 224 +++++++++++++++++++++
 10 files changed, 864 insertions(+), 79 deletions(-)

exec
/bin/zsh -lc 'git diff --name-only 7f591d9dad8444b180a84a82ad02a9c239cfc6e2..HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
atlas/chat/inline_define.md
lua/parley/buffer_edit.lua
lua/parley/chat_respond.lua
lua/parley/define.lua
lua/parley/init.lua
tests/integration/define_spec.lua
tests/unit/build_messages_spec.lua
tests/unit/define_spec.lua
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md

exec
/bin/zsh -lc "nl -ba lua/parley/define.lua | sed -n '120,330p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
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
   130	--- @param s string
   131	--- @return string
   132	local function trim(s)
   133	    local out = (s or ""):gsub("^%s*(.-)%s*$", "%1")
   134	    return out
   135	end
   136	
   137	--- Convert a term into a stable markdown footnote id.
   138	--- @param term string|nil
   139	--- @return string
   140	function M.footnote_id(term)
   141	    local id = tostring(term or ""):lower()
   142	    id = id:gsub("[^%w]+", "-")
   143	    id = id:gsub("^%-+", ""):gsub("%-+$", "")
   144	    if id == "" then
   145	        id = "definition"
   146	    end
   147	    return id
   148	end
   149	
   150	--- @param id string
   151	--- @param definition string|nil
   152	--- @return string
   153	function M.format_footnote_line(id, definition)
   154	    definition = trim(definition)
   155	    if definition == "" then
   156	        definition = "(no definition)"
   157	    end
   158	    return string.format("[^%s]: %s", id, definition)
   159	end
   160	
   161	local function is_divider(line)
   162	    return trim(line) == "---"
   163	end
   164	
   165	local function is_footnote_line(line)
   166	    return trim(line):match("^%[%^[^%]]+%]:") ~= nil
   167	end
   168	
   169	local function managed_footer_start(lines)
   170	    for i = #lines, 1, -1 do
   171	        if is_divider(lines[i]) then
   172	            local has_footnote = false
   173	            for j = i + 1, #lines do
   174	                local line = lines[j] or ""
   175	                if trim(line) ~= "" then
   176	                    if not is_footnote_line(line) then
   177	                        return nil
   178	                    end
   179	                    has_footnote = true
   180	                end
   181	            end
   182	            if has_footnote then
   183	                return i
   184	            end
   185	            return nil
   186	        end
   187	    end
   188	    return nil
   189	end
   190	
   191	local function split_text_lines(text)
   192	    text = text or ""
   193	    local lines = {}
   194	    local start = 1
   195	    while true do
   196	        local nl = text:find("\n", start, true)
   197	        if not nl then
   198	            lines[#lines + 1] = text:sub(start)
   199	            break
   200	        end
   201	        lines[#lines + 1] = text:sub(start, nl - 1)
   202	        start = nl + 1
   203	    end
   204	    if #lines > 1 and lines[#lines] == "" then
   205	        table.remove(lines)
   206	    end
   207	    return lines
   208	end
   209	
   210	local function copy_lines(lines)
   211	    local out = {}
   212	    for i, line in ipairs(lines or {}) do
   213	        out[i] = line
   214	    end
   215	    return out
   216	end
   217	
   218	--- Strip a final managed definition-footnote footer from text.
   219	--- @param text string|nil
   220	--- @return string
   221	function M.strip_definition_footnote_footer(text)
   222	    local lines = split_text_lines(text or "")
   223	    local start = managed_footer_start(lines)
   224	    if not start then
   225	        return text or ""
   226	    end
   227	    while start > 1 and trim(lines[start - 1]) == "" do
   228	        start = start - 1
   229	    end
   230	    local kept = {}
   231	    for i = 1, start - 1 do
   232	        kept[#kept + 1] = lines[i]
   233	    end
   234	    while #kept > 0 and trim(kept[#kept]) == "" do
   235	        table.remove(kept)
   236	    end
   237	    return table.concat(kept, "\n")
   238	end
   239	
   240	local function replace_or_append_footnote(lines, id, definition)
   241	    local out = copy_lines(lines)
   242	    local footer = managed_footer_start(out)
   243	    local footnote_line = M.format_footnote_line(id, definition)
   244	    if footer then
   245	        for i = footer + 1, #out do
   246	            local escaped_id = id:gsub("([^%w])", "%%%1")
   247	            if trim(out[i]):match("^%[%^" .. escaped_id .. "%]:") then
   248	                out[i] = footnote_line
   249	                return out
   250	            end
   251	        end
   252	        out[#out + 1] = footnote_line
   253	        return out
   254	    end
   255	
   256	    while #out > 0 and trim(out[#out]) == "" do
   257	        table.remove(out)
   258	    end
   259	    out[#out + 1] = ""
   260	    out[#out + 1] = "---"
   261	    out[#out + 1] = ""
   262	    out[#out + 1] = footnote_line
   263	    return out
   264	end
   265	
   266	--- Insert a markdown footnote reference after the selected text and store the
   267	--- definition in a managed footer.
   268	--- @param lines string[]
   269	--- @param l1 integer
   270	--- @param c1 integer 0-based byte column
   271	--- @param l2 integer
   272	--- @param c2 integer 0-based inclusive byte column
   273	--- @param term string
   274	--- @param definition string|nil
   275	--- @return table { lines: string[], id: string, definition: string, diagnostic_span: table }
   276	function M.apply_definition_footnote(lines, l1, c1, l2, c2, term, definition)
   277	    local id = M.footnote_id(term)
   278	    local ref = "[^" .. id .. "]"
   279	    local out = copy_lines(lines)
   280	    if l1 == l2 then
   281	        local line = out[l1] or ""
   282	        local ec = math.min(c2 + 1, #line)
   283	        out[l1] = line:sub(1, ec) .. ref .. line:sub(ec + 1)
   284	    else
   285	        local line = out[l2] or ""
   286	        local ec = math.min(c2 + 1, #line)
   287	        out[l2] = line:sub(1, ec) .. ref .. line:sub(ec + 1)
   288	    end
   289	    out = replace_or_append_footnote(out, id, definition)
   290	    local normalized_definition = trim(definition)
   291	    if normalized_definition == "" then
   292	        normalized_definition = "(no definition)"
   293	    end
   294	    return {
   295	        lines = out,
   296	        id = id,
   297	        definition = normalized_definition,
   298	        diagnostic_span = {
   299	            lnum = l1 - 1,
   300	            col = c1,
   301	            end_lnum = l2 - 1,
   302	            end_col = c2 + 1 + #ref,
   303	        },
   304	    }
   305	end
   306	
   307	return M

codex
The issue’s stated contract is narrow: persist the selected definition as `term[^id]`, manage/update the final footer, and scrub that managed footer from both normal and live message construction. I’m now checking edge behavior around re-definition, footer detection, and the live message path because those are the places a green happy-path test can miss contract drift.
exec
/bin/zsh -lc "nl -ba lua/parley/chat_respond.lua | sed -n '330,430p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   330	--- @param target_idx integer  exchange to include up to (inclusive)
   331	--- @param agent_info table  { system_prompt, ... }
   332	--- @return table[] messages
   333	M.build_messages_from_model = function(buf, model, target_idx, agent_info)
   334	    local serialize = require("parley.tools.serialize")
   335	    local system_prompt_msgs = require("parley.system_prompt_msgs")
   336	    local prov = require("parley.providers")
   337	    local define = require("parley.define")
   338	    append_neighborhood_context(agent_info, agent_info and agent_info.neighborhood_root)
   339	    local messages = system_prompt_msgs.build(agent_info, function(provider)
   340	        return prov.has_feature(provider, "cache_control")
   341	    end)
   342	
   343	    local function read_block_text(k, b)
   344	        local start_line = model:block_start(k, b)
   345	        local end_line = model:block_end(k, b)
   346	        if end_line < start_line then return "" end
   347	        local buf_lines = vim.api.nvim_buf_get_lines(buf, start_line, end_line + 1, false)
   348	        return table.concat(buf_lines, "\n")
   349	    end
   350	
   351	    for k = 1, target_idx do
   352	        local blocks = model.exchanges[k].blocks
   353	        -- Normalize this exchange's answer blocks into the content_blocks shape
   354	        -- consumed by _emit_content_blocks_as_messages — the single emitter that
   355	        -- also enforces the tool_use→tool_result invariant (#155). This replaces
   356	        -- an inline copy of the interleaving that had diverged from the parse
   357	        -- path (it lacked the dangling-call synthesis; input coercion now lives
   358	        -- in the emitter, one source). IO (buffer reads + serialize.parse_*)
   359	        -- stays here in the thin normalization seam; the emitter stays pure.
   360	        local answer_blocks = {}
   361	        local function flush_answer()
   362	            if #answer_blocks > 0 then
   363	                for _, m in ipairs(M._emit_content_blocks_as_messages(answer_blocks)) do
   364	                    table.insert(messages, m)
   365	                end
   366	                answer_blocks = {}
   367	            end
   368	        end
   369	
   370	        for b = 1, #blocks do
   371	            local blk = blocks[b]
   372	            if blk.size <= 0 then goto continue end
   373	
   374	            if blk.kind == "question" then
   375	                local text = read_block_text(k, b)
   376	                -- Strip 💬: prefix and trim
   377	                text = text:gsub("^💬:%s*", ""):gsub("^%s*(.-)%s*$", "%1")
   378	                text = define.strip_definition_footnote_footer(text)
   379	                if text ~= "" then
   380	                    -- Defensive: an answer never precedes its question, but
   381	                    -- flush any accumulated answer blocks to keep ordering stable.
   382	                    flush_answer()
   383	                    table.insert(messages, { role = "user", content = text })
   384	                end
   385	
   386	            elseif blk.kind == "agent_header" or blk.kind == "spinner" then
   387	                goto continue  -- not part of messages
   388	
   389	            elseif blk.kind == "text" or blk.kind == "stream_placeholder" then
   390	                local text = define.strip_definition_footnote_footer(read_block_text(k, b))
   391	                if text:match("%S") then
   392	                    table.insert(answer_blocks, { type = "text", text = text })
   393	                end
   394	
   395	            elseif blk.kind == "tool_use" then
   396	                local text = read_block_text(k, b)
   397	                local parsed = serialize.parse_call(text)
   398	                if parsed then
   399	                    -- Empty-input dict coercion happens in the emitter now.
   400	                    table.insert(answer_blocks, {
   401	                        type = "tool_use",
   402	                        id = parsed.id,
   403	                        name = parsed.name,
   404	                        input = parsed.input,
   405	                    })
   406	                else
   407	                    -- Malformed tool_use — degrade to text so it's not
   408	                    -- silently dropped. Claude sees the raw block text.
   409	                    table.insert(answer_blocks, { type = "text", text = define.strip_definition_footnote_footer(text) })
   410	                end
   411	
   412	            elseif blk.kind == "tool_result" then
   413	                local text = read_block_text(k, b)
   414	                local parsed = serialize.parse_result(text)
   415	                if parsed then
   416	                    table.insert(answer_blocks, {
   417	                        type = "tool_result",
   418	                        id = parsed.id,
   419	                        content = parsed.content or "",
   420	                        is_error = parsed.is_error == true,
   421	                    })
   422	                else
   423	                    -- Malformed tool_result — degrade to a user text message,
   424	                    -- preserving user/assistant alternation. Flush accumulated
   425	                    -- answer blocks first so ordering is stable.
   426	                    flush_answer()
   427	                    table.insert(messages, { role = "user", content = define.strip_definition_footnote_footer(text) })
   428	                end
   429	            end
   430	

exec
/bin/zsh -lc "nl -ba lua/parley/init.lua | sed -n '1600,1685p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
  1600	-- the footnote edit lands on the pre-edit content-hash → the empty snapshot
  1601	-- renders → both decorations clear.
  1602	-- `span` = the visual selection {sr, sc, er, ec} (1-based getpos values).
  1603	local function render_definition(buf, span, phrase, result)
  1604		-- Pick the emit_definition call (unforced → the model may answer in text or
  1605		-- only call web_search; both mean "no definition"). Notify rather than
  1606		-- silently doing nothing, and leave no footnote edit.
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
  1626		-- The buffer may have changed under the in-flight call; skip the whole render
  1627		-- rather than attach a footnote reference to shifted text.
  1628		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  1629		if define.slice_selection(lines, sr, sc - 1, er, ec - 1) ~= phrase then
  1630			M.logger.warning("Define: selection changed during lookup — re-select to define")
  1631			return
  1632		end
  1633		local original = table.concat(lines, "\n") -- pre-edit content (undo base)
  1634	
  1635		-- Store the definition as a markdown footnote in ONE full-buffer set_lines
  1636		-- edit (single undo entry = the anchor). set_applying suppresses any prior
  1637		-- define's projection watcher during our own edit (mirrors review).
  1638		projection.set_applying(buf, true)
  1639		local input = call.input or {}
  1640		local e = define.apply_definition_footnote(lines, sr, sc - 1, er, ec - 1, input.term or phrase, input.definition)
  1641		require("parley.buffer_edit").replace_all_lines_for_definition(buf, e.lines)
  1642	
  1643		-- Highlight the term's line(s) + the ephemeral definition diagnostic.
  1644		for line0 = sr - 1, er - 1 do
  1645			skill_render.highlight_line(buf, line0)
  1646		end
  1647		local width = math.max(40, vim.api.nvim_win_get_width(0) - 8)
  1648		local msg = define.format_definition(input.term or phrase, e.definition, width)
  1649		local diag_span = e.diagnostic_span
  1650		vim.diagnostic.set(skill_render.diag_namespace(), buf, { {
  1651			lnum = diag_span.lnum,
  1652			col = diag_span.col,
  1653			end_lnum = diag_span.end_lnum,
  1654			end_col = diag_span.end_col,
  1655			message = msg,
  1656			severity = vim.diagnostic.severity.INFO,
  1657			source = "parley-define",
  1658		} })
  1659	
  1660		-- Record projection states so undo/redo of the footnote edit clears/restores
  1661		-- the decorations (#133 M5 machinery, reused): pre-edit hash → empty
  1662		-- snapshot, footnoted hash → highlight+diagnostic; attach the watcher.
  1663		projection.record_empty_for(buf, original)
  1664		projection.record(buf)
  1665		projection.ensure_watch(buf)
  1666		projection.set_applying(buf, false)
  1667	
  1668		-- Park the cursor on the term's line so diag_display's current-line
  1669		-- virtual_lines reveals the definition immediately.
  1670		pcall(vim.api.nvim_win_set_cursor, 0, { sr, math.max(0, sc - 1) })
  1671		vim.cmd("redraw")
  1672	end
  1673	
  1674	-- define_visual: the thin IO shell for visual-mode <M-CR>. Reads the selection,
  1675	-- computes the enclosing-exchange context, and fires a headless define skill
  1676	-- turn whose on_done stores + renders the definition inline. Pure logic lives
  1677	-- in lua/parley/define.lua. Exposed as M.define_visual for the keybinding.
  1678	function M.define_visual(buf)
  1679		buf = buf or vim.api.nvim_get_current_buf()
  1680		local sp = vim.fn.getpos("'<")
  1681		local ep = vim.fn.getpos("'>")
  1682		local sr, sc = sp[2], sp[3]
  1683		local er, ec = ep[2], ep[3]
  1684		if sr == 0 or er == 0 then return end
  1685	

exec
/bin/zsh -lc "nl -ba lua/parley/chat_respond.lua | sed -n '605,830p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   605	    local exchange_idx = opts.exchange_idx
   606	    local agent = opts.agent
   607	    local opts_config = opts.config
   608	    local helpers = opts.helpers
   609	    local logger = opts.logger or { debug = function() end, warning = function() end }
   610	    local define = require("parley.define")
   611	    local function scrub_content_blocks(blocks)
   612	        local out = {}
   613	        for _, block in ipairs(blocks or {}) do
   614	            local copy = vim.deepcopy(block)
   615	            if copy.type == "text" and type(copy.text) == "string" then
   616	                copy.text = define.strip_definition_footnote_footer(copy.text)
   617	            end
   618	            out[#out + 1] = copy
   619	        end
   620	        return out
   621	    end
   622	
   623	    -- Process headers for agent information
   624	    local headers = parsed_chat.headers
   625	
   626	    -- Prepare for summary extraction
   627	    local memory_enabled = opts_config.chat_memory and opts_config.chat_memory.enable
   628	
   629	    -- Use header-defined max_full_exchanges if available, otherwise use config value
   630	    local max_exchanges = 999999
   631	    if memory_enabled then
   632	        if headers.config_max_full_exchanges then
   633	            max_exchanges = headers.config_max_full_exchanges
   634	            logger.debug("Using header-defined max_full_exchanges: " .. tostring(max_exchanges))
   635	        else
   636	            max_exchanges = opts_config.chat_memory.max_full_exchanges
   637	        end
   638	    end
   639	
   640	    local omit_user_text = memory_enabled and opts_config.chat_memory.omit_user_text or "[Previous messages omitted]"
   641	
   642	    -- Get combined agent information using the helper function
   643	    local agent_info = _parley.get_agent_info(headers, agent)
   644	
   645	    -- Normalize the system prompt: trim outer whitespace, then re-add a
   646	    -- trailing newline when system_prompt+ header appends were applied.
   647	    -- Done on agent_info.system_prompt directly (not on messages[1]) so
   648	    -- the normalization is independent of how the leading messages are
   649	    -- shaped (real system message vs. synthetic user/assistant pair).
   650	    if type(agent_info.system_prompt) == "string" then
   651	        agent_info.system_prompt = agent_info.system_prompt:gsub("^%s*(.-)%s*$", "%1")
   652	    end
   653	    local has_system_prompt_append = false
   654	    if type(headers) == "table" and type(headers._append) == "table" then
   655	        local canonical = headers._append.system_prompt
   656	        local legacy = headers._append.role
   657	        has_system_prompt_append = (type(canonical) == "table" and #canonical > 0) or (type(legacy) == "table" and #legacy > 0)
   658	    end
   659	    if has_system_prompt_append
   660	        and type(agent_info.system_prompt) == "string"
   661	        and agent_info.system_prompt ~= ""
   662	        and agent_info.system_prompt:sub(-1) ~= "\n"
   663	    then
   664	        agent_info.system_prompt = agent_info.system_prompt .. "\n"
   665	    end
   666	    append_neighborhood_context(agent_info, opts.neighborhood_root)
   667	
   668	    -- Convert parsed_chat to messages for the model using a single-pass approach.
   669	    -- Leading messages (system prompt or synthetic pair) are prepended after the
   670	    -- exchange loop, not seeded as a placeholder.
   671	    local messages = {}
   672	
   673	    -- Process each exchange, determining whether to preserve or summarize
   674	    local total_exchanges = #parsed_chat.exchanges
   675	
   676	    -- Single pass through all exchanges
   677	    for idx, exchange in ipairs(parsed_chat.exchanges) do
   678	        if exchange.question and exchange.question.line_start >= start_index and idx <= exchange_idx then
   679	            -- Determine if this exchange should be preserved in full
   680	            local should_preserve = false
   681	
   682	            -- Preserve if this is the current question
   683	            if idx == exchange_idx then
   684	                should_preserve = true
   685	                logger.debug("Exchange #" .. idx .. " preserved as current question")
   686	            end
   687	            -- Preserve if it's a recent exchange (within max_full_exchanges from the end)
   688	            if idx > total_exchanges - max_exchanges then
   689	                should_preserve = true
   690	                logger.debug("Exchange #" .. idx .. " preserved as recent exchange")
   691	            end
   692	
   693	            -- Preserve if it contains file references
   694	            if #exchange.question.file_references > 0 then
   695	                should_preserve = true
   696	                logger.debug("Exchange #" .. idx .. " preserved due to file references")
   697	            end
   698	
   699	                -- Process the question
   700	                if should_preserve then
   701	                    -- Get the question content and process any file loading directives
   702	                    local question_content = define.strip_definition_footnote_footer(exchange.question.content)
   703	                    local file_content_parts = {}
   704	
   705	                    -- Raw request input feature: detect a `yaml {"type":"request"}`
   706	                    -- fence at the bottom of the question and use it verbatim as
   707	                    -- the API payload. The YAML form lets the user copy a turn
   708	                    -- from the raw log, paste, edit, and re-send.
   709	                    do
   710	                        local yaml_content = question_content:match('```yaml%s+{"type":%s*"request"}%s*\n(.-)\n```')
   711	                        if yaml_content then
   712	                            logger.debug("Found typed YAML request block in question, using raw request mode")
   713	                            local payload, err = require("parley.log_emit").parse_yaml(yaml_content)
   714	                            if payload and type(payload) == "table" then
   715	                                exchange.question.raw_payload = payload
   716	                                logger.debug("Successfully parsed YAML payload: " .. vim.inspect(payload))
   717	                            else
   718	                                logger.warning("Failed to parse YAML in raw request mode: " .. tostring(err))
   719	                            end
   720	                        end
   721	                    end
   722	
   723	                    -- Use the precomputed file references instead of scanning for them again
   724	                    for _, file_ref in ipairs(exchange.question.file_references) do
   725	                        local path = file_ref.path
   726	
   727	                        logger.debug("Processing file reference: " .. path)
   728	
   729	                        -- Check if this is a pre-resolved remote reference
   730	                        if opts.resolved_remote_content and opts.resolved_remote_content[path] then
   731	                            table.insert(
   732	                                file_content_parts,
   733	                                "[The following content was already fetched from "
   734	                                    .. path
   735	                                    .. ". Do NOT use web_fetch or web_search to access this URL.]\n"
   736	                                    .. opts.resolved_remote_content[path]
   737	                            )
   738	                        elseif helpers.is_remote_url and helpers.is_remote_url(path) then
   739	                            table.insert(file_content_parts, M.format_missing_remote_reference_cache_content(path))
   740	                        -- Check if this is a directory or has directory pattern markers (* or **/)
   741	                        elseif
   742	                            helpers.is_directory(path)
   743	                            or path:match("/%*%*?/?") -- Contains /** or /**/
   744	                            or path:match("/%*%.%w+$")
   745	                        then -- Contains /*.ext pattern
   746	                            table.insert(file_content_parts, helpers.process_directory_pattern(path))
   747	                        else
   748	                            table.insert(file_content_parts, helpers.format_file_content(path))
   749	                        end
   750	                    end
   751	
   752	                    -- Handle provider-specific file reference processing for questions with file references
   753	                    if exchange.question.file_references and #exchange.question.file_references > 0 then
   754	                        -- split user question with file inclusion (@@ pattern) into two messages.
   755	                        -- a system message that contains file content. and a user message containing the question.
   756	                        -- the cache-control key is only needed for Anthropic, but since it doesn't cause problem
   757	                        -- with Google or OpenAI, I'll leave it here.
   758	                        table.insert(messages, {
   759	                            role = "system",
   760	                            content = table.concat(file_content_parts, "\n") .. "\n",
   761	                            cache_control = { type = "ephemeral" },
   762	                        })
   763	                        table.insert(messages, { role = "user", content = question_content })
   764	                    else
   765	                        -- No file references, just add the question as user message
   766	                        table.insert(messages, { role = "user", content = question_content })
   767	                    end
   768	                else
   769	                    -- Use the placeholder text for summarized questions
   770	                    table.insert(messages, { role = "user", content = omit_user_text })
   771	                end
   772	
   773	            -- Process the answer if it exists and is within our range.
   774	            -- M2 Task 2.6 of #81: if the answer carries tool_use / tool_result
   775	            -- content_blocks (populated by chat_parser when 🔧:/📎: appear in
   776	            -- the buffer), the CURRENT exchange's partial answer ALSO needs
   777	            -- to be emitted so the tool loop recursion can continue the
   778	            -- conversation with Anthropic. Vanilla resubmit still skips the
   779	            -- current exchange's answer (idx < exchange_idx preserved).
   780	            local answer_has_tool_blocks = false
   781	            if exchange.answer and exchange.answer.content_blocks then
   782	                for _, b in ipairs(exchange.answer.content_blocks) do
   783	                    if b.type == "tool_use" or b.type == "tool_result" then
   784	                        answer_has_tool_blocks = true
   785	                        break
   786	                    end
   787	                end
   788	            end
   789	            local include_answer = exchange.answer
   790	                and exchange.answer.line_start <= end_index
   791	                and (idx < exchange_idx or answer_has_tool_blocks)
   792	
   793	            if include_answer then
   794	                -- when we preserve due to have file inclusion in question, we still summarize the answer
   795	                if should_preserve and not (exchange.question.file_references and #exchange.question.file_references > 0) then
   796	                    -- Emit the answer. Two paths:
   797	                    --   A. Tool blocks present → split into Anthropic
   798	                    --      content-block messages (assistant[text,tool_use],
   799	                    --      user[tool_result], ...).
   800	                    --   B. No tool blocks → single flat-string assistant
   801	                    --      message (byte-identical to pre-#81).
   802	                    if answer_has_tool_blocks then
   803	                        for _, m in ipairs(M._emit_content_blocks_as_messages(scrub_content_blocks(exchange.answer.content_blocks))) do
   804	                            table.insert(messages, m)
   805	                        end
   806	                    else
   807	                        table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.answer.content) })
   808	                    end
   809	                else
   810	                    -- Use the summary if available
   811	                    if exchange.summary then
   812	                        table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.summary.content) })
   813	                    else
   814	                        -- If no summary is available, use the full content (fallback)
   815	                        if answer_has_tool_blocks then
   816	                            for _, m in ipairs(M._emit_content_blocks_as_messages(scrub_content_blocks(exchange.answer.content_blocks))) do
   817	                                table.insert(messages, m)
   818	                            end
   819	                        else
   820	                            table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.answer.content) })
   821	                        end
   822	                    end
   823	                end
   824	            end
   825	        end
   826	    end
   827	
   828	    -- strip whitespace from ends of content. Messages built from
   829	    -- content_blocks carry a table in .content (Anthropic's content-
   830	    -- block shape); those have already been trimmed at the block

exec
/bin/zsh -lc 'rg -n "bracket_edit|diagnostic_span_after_bracket|apply_definition_footnote|strip_definition_footnote_footer|replace_all_lines_for_definition" -S .' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
./atlas/chat/inline_define.md:32:   (`define.apply_definition_footnote`) — a single undo entry that anchors
./atlas/chat/inline_define.md:58:  `context_for_selection`, `format_definition`, `bracket_edit` (plans the `[term]`
./atlas/chat/inline_define.md:59:  wrap as a legacy set_lines edit), `diagnostic_span_after_bracket` (legacy range
./atlas/chat/inline_define.md:60:  mapping), `apply_definition_footnote` (durable footer transform), and
./atlas/chat/inline_define.md:61:  `strip_definition_footnote_footer` (removes only a final `---` block followed
./workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:104:  `define.strip_definition_footnote_footer` through message construction.
./workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:70:- `apply_definition_footnote` changes `here is ASIN in context` to `here is ASIN[^asin] in context`.
./workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:90:- `apply_definition_footnote(lines, l1, c1, l2, c2, term, definition)`
./workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:91:- `strip_definition_footnote_footer(text)`
./workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:131:In `lua/parley/buffer_edit.lua`, add a named wrapper such as `replace_all_lines_for_definition(buf, lines)` delegating to `replace_all_lines`. This keeps call sites semantically clear and avoids adding new direct `nvim_buf_set_lines` callers.
./workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:136:- Replace `define.bracket_edit` with `define.apply_definition_footnote`.
./workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:137:- Use `buffer_edit.replace_all_lines_for_definition` for the rewrite.
./workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:174:- Both user and assistant content pass through the same `strip_definition_footnote_footer` helper.
./workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:182:In `chat_respond.build_messages`, call `define.strip_definition_footnote_footer` before inserting string question/answer/summary content into `messages`. Keep content-block arrays unchanged unless they contain text blocks created from parsed answer strings; for the parse path, scrub flat string content first.
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column.md:37:fix must reuse the existing `span`/`bracket_edit` data rather than re-scanning the
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column.md:80:- Implemented `define.diagnostic_span_after_bracket` (ARCH-PURE) and wired
./workshop/history/000161-inline-term-definition-close-review.md:98:- **ARCH-PURE textbook.** `slice_selection` / `context_for_selection` / `format_definition` / `bracket_edit` (`define.lua`) are deterministic table/string functions, unit-tested with plain tables (13/0/0). The Anthropic seam is exercised via the process-level SSE fake, not function mocks.
./workshop/history/000161-inline-term-definition-close-review.md:164:- **ARCH-PURE textbook.** `slice_selection` / `context_for_selection` / `format_definition` / `bracket_edit` (`define.lua`) are deterministic table/string functions, unit-tested with plain tables — no buffer, no exec. I re-traced the `bracket_edit` single- and multi-line arithmetic against the unit-test literals: correct. The Anthropic seam is exercised via the process-level SSE fake, not function mocks.
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:231:    `nvim_buf_set_lines` (`define.bracket_edit` plans it) — a single undo entry
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:237:+   (`define.diagnostic_span_after_bracket`, `define.format_definition` →
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:246:   `context_for_selection`, `format_definition`, `bracket_edit` (plans the `[term]`
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:248:+  wrap as a set_lines edit), `diagnostic_span_after_bracket` (maps the visual span
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:257:@@ -111,4 +111,20 @@ function M.bracket_edit(lines, l1, c1, l2, c2)
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:262:+--- bracket_edit inserts "[" before the selection and "]" after it.
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:268:+function M.diagnostic_span_after_bracket(l1, c1, l2, c2)
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:286:+	local diag_span = define.diagnostic_span_after_bracket(sr, sc, er, ec)
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:317:@@ -103,3 +103,25 @@ describe("define.bracket_edit", function()
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:322:+describe("define.diagnostic_span_after_bracket", function()
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:324:+        local span = define.diagnostic_span_after_bracket(3, 9, 3, 12)
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:334:+        local span = define.diagnostic_span_after_bracket(1, 7, 3, 3)
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:638:fix must reuse the existing `span`/`bracket_edit` data rather than re-scanning the
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:680:- Implemented `define.diagnostic_span_after_bracket` (ARCH-PURE) and wired
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:929:    95	function M.bracket_edit(lines, l1, c1, l2, c2)
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:949:   115	--- bracket_edit inserts "[" before the selection and "]" after it.
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:955:   121	function M.diagnostic_span_after_bracket(l1, c1, l2, c2)
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1011:  1640		local e = define.bracket_edit(lines, sr, sc - 1, er, ec - 1)
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1022:  1651		local diag_span = define.diagnostic_span_after_bracket(sr, sc, er, ec)
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1092:    `nvim_buf_set_lines` (`define.bracket_edit` plans it) — a single undo entry
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1098:+   (`define.diagnostic_span_after_bracket`, `define.format_definition` →
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1121:   `context_for_selection`, `format_definition`, `bracket_edit` (plans the `[term]`
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1123:+  wrap as a set_lines edit), `diagnostic_span_after_bracket` (maps the visual span
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1246: function M.bracket_edit(lines, l1, c1, l2, c2)
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1266:+--- bracket_edit inserts "[" before the selection and "]" after it.
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1272:+function M.diagnostic_span_after_bracket(l1, c1, l2, c2)
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1356: 	local e = define.bracket_edit(lines, sr, sc - 1, er, ec - 1)
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1367:+	local diag_span = define.diagnostic_span_after_bracket(sr, sc, er, ec)
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1689: describe("define.bracket_edit", function()
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1692:         local e = define.bracket_edit({ "here is ASIN in context" }, 1, 8, 1, 11)
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1699:         local e = define.bracket_edit({ "the lazy dog" }, 1, 9, 1, 999)
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1704:         local e = define.bracket_edit({ "brown fox", "jumps over", "the dog" }, 1, 6, 3, 2)
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1711:+describe("define.diagnostic_span_after_bracket", function()
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1713:+        local span = define.diagnostic_span_after_bracket(3, 9, 3, 12)
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1723:+        local span = define.diagnostic_span_after_bracket(1, 7, 3, 3)
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1773:+fix must reuse the existing `span`/`bracket_edit` data rather than re-scanning the
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1817:+- Implemented `define.diagnostic_span_after_bracket` (ARCH-PURE) and wired
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1824:/bin/zsh -lc "rg -n \"define_visual|render_definition|bracket_edit|diagnostic_span_after_bracket|getpos\\(\" lua tests atlas workshop/issues/000165-visual-selection-definition-search-should-anchor-at-right-column.md" in /Users/xianxu/workspace/parley.nvim
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1829:workshop/issues/000165-visual-selection-definition-search-should-anchor-at-right-column.md:36:fix must reuse the existing `span`/`bracket_edit` data rather than re-scanning the
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1831:workshop/issues/000165-visual-selection-definition-search-should-anchor-at-right-column.md:78:- Implemented `define.diagnostic_span_after_bracket` (ARCH-PURE) and wired
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1835:lua/parley/define.lua:95:function M.bracket_edit(lines, l1, c1, l2, c2)
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1836:lua/parley/define.lua:115:--- bracket_edit inserts "[" before the selection and "]" after it.
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1839:lua/parley/define.lua:121:function M.diagnostic_span_after_bracket(l1, c1, l2, c2)
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1842:atlas/chat/inline_define.md:29:   `nvim_buf_set_lines` (`define.bracket_edit` plans it) — a single undo entry
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1843:atlas/chat/inline_define.md:33:   (`define.diagnostic_span_after_bracket`, `define.format_definition` →
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1845:atlas/chat/inline_define.md:56:  `context_for_selection`, `format_definition`, `bracket_edit` (plans the `[term]`
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1846:atlas/chat/inline_define.md:57:  wrap as a set_lines edit), `diagnostic_span_after_bracket` (maps the visual span
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1860:lua/parley/init.lua:1640:	local e = define.bracket_edit(lines, sr, sc - 1, er, ec - 1)
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1861:lua/parley/init.lua:1651:	local diag_span = define.diagnostic_span_after_bracket(sr, sc, er, ec)
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1874:tests/unit/define_spec.lua:85:describe("define.bracket_edit", function()
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1875:tests/unit/define_spec.lua:88:        local e = define.bracket_edit({ "here is ASIN in context" }, 1, 8, 1, 11)
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1876:tests/unit/define_spec.lua:95:        local e = define.bracket_edit({ "the lazy dog" }, 1, 9, 1, 999)
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1877:tests/unit/define_spec.lua:100:        local e = define.bracket_edit({ "brown fox", "jumps over", "the dog" }, 1, 6, 3, 2)
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1878:tests/unit/define_spec.lua:107:describe("define.diagnostic_span_after_bracket", function()
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1879:tests/unit/define_spec.lua:109:        local span = define.diagnostic_span_after_bracket(3, 9, 3, 12)
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1880:tests/unit/define_spec.lua:119:        local span = define.diagnostic_span_after_bracket(1, 7, 3, 3)
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1917:   100	        local e = define.bracket_edit({ "brown fox", "jumps over", "the dog" }, 1, 6, 3, 2)
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1924:   107	describe("define.diagnostic_span_after_bracket", function()
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1926:   109	        local span = define.diagnostic_span_after_bracket(3, 9, 3, 12)
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1936:   119	        local span = define.diagnostic_span_after_bracket(1, 7, 3, 3)
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1968:    29	   `nvim_buf_set_lines` (`define.bracket_edit` plans it) — a single undo entry
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1972:    33	   (`define.diagnostic_span_after_bracket`, `define.format_definition` →
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1995:    56	  `context_for_selection`, `format_definition`, `bracket_edit` (plans the `[term]`
./workshop/history/000165-visual-selection-definition-search-should-anchor-at-right-column-close-review.md:1996:    57	  wrap as a set_lines edit), `diagnostic_span_after_bracket` (maps the visual span
./workshop/history/000161-inline-term-definition.md:252:- 2026-07-07: closed — R1 (highlight + bracket-anchored undo): make test green — lint 0/0 (244 files), all unit+integration+ARCH pass. define_spec unit: bracket_edit (single/multi-line/clamp). define_spec integration: brackets the term ([ASIN]) + whole-line DiffChange highlight + diagnostic on the line; u reverts the bracket and clears both decorations (projection), C-r restores them; a no-emit_definition response leaves no bracket; plus the prior 12 (registration, discovery, no_reload, document, web-toggle, keybinding real prep_chat wiring). ARCH buffer_mutation green (bracket via nvim_buf_set_lines, not set_text). Undo/redo reuses review projection (record_empty_for + record + ensure_watch). Live-LLM/web manual check still deferred (no API key); wiring covered by faked-exchange + payload tests.; review verdict: FIX-THEN-SHIP
./workshop/history/000161-inline-term-definition.md:350:**New pure helper (ARCH-PURE):** `define.bracket_edit(lines, l1, c1, l2, c2) →
./workshop/history/000161-inline-term-definition.md:355:**Tests (delta):** unit for `bracket_edit`; integration — after a faked
./workshop/history/000161-inline-term-definition.md:364:**Estimate delta:** +0.6h (one `lua-neovim` extension: pure `bracket_edit` +
./lua/parley/define.lua:95:function M.bracket_edit(lines, l1, c1, l2, c2)
./lua/parley/define.lua:115:--- bracket_edit inserts "[" before the selection and "]" after it.
./lua/parley/define.lua:121:function M.diagnostic_span_after_bracket(l1, c1, l2, c2)
./lua/parley/define.lua:221:function M.strip_definition_footnote_footer(text)
./lua/parley/define.lua:276:function M.apply_definition_footnote(lines, l1, c1, l2, c2, term, definition)
./lua/parley/init.lua:1640:	local e = define.apply_definition_footnote(lines, sr, sc - 1, er, ec - 1, input.term or phrase, input.definition)
./lua/parley/init.lua:1641:	require("parley.buffer_edit").replace_all_lines_for_definition(buf, e.lines)
./lua/parley/buffer_edit.lua:118:function M.replace_all_lines_for_definition(buf, lines)
./lua/parley/chat_respond.lua:378:                text = define.strip_definition_footnote_footer(text)
./lua/parley/chat_respond.lua:390:                local text = define.strip_definition_footnote_footer(read_block_text(k, b))
./lua/parley/chat_respond.lua:409:                    table.insert(answer_blocks, { type = "text", text = define.strip_definition_footnote_footer(text) })
./lua/parley/chat_respond.lua:427:                    table.insert(messages, { role = "user", content = define.strip_definition_footnote_footer(text) })
./lua/parley/chat_respond.lua:616:                copy.text = define.strip_definition_footnote_footer(copy.text)
./lua/parley/chat_respond.lua:702:                    local question_content = define.strip_definition_footnote_footer(exchange.question.content)
./lua/parley/chat_respond.lua:807:                        table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.answer.content) })
./lua/parley/chat_respond.lua:812:                        table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.summary.content) })
./lua/parley/chat_respond.lua:820:                            table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.answer.content) })
./tests/unit/define_spec.lua:85:describe("define.bracket_edit", function()
./tests/unit/define_spec.lua:88:        local e = define.bracket_edit({ "here is ASIN in context" }, 1, 8, 1, 11)
./tests/unit/define_spec.lua:95:        local e = define.bracket_edit({ "the lazy dog" }, 1, 9, 1, 999)
./tests/unit/define_spec.lua:100:        local e = define.bracket_edit({ "brown fox", "jumps over", "the dog" }, 1, 6, 3, 2)
./tests/unit/define_spec.lua:107:describe("define.diagnostic_span_after_bracket", function()
./tests/unit/define_spec.lua:109:        local span = define.diagnostic_span_after_bracket(3, 9, 3, 12)
./tests/unit/define_spec.lua:119:        local span = define.diagnostic_span_after_bracket(1, 7, 3, 3)
./tests/unit/define_spec.lua:137:        local result = define.apply_definition_footnote(
./tests/unit/define_spec.lua:157:        local result = define.apply_definition_footnote(
./tests/unit/define_spec.lua:188:        assert.equals("answer text", define.strip_definition_footnote_footer(text))
./tests/unit/define_spec.lua:200:        assert.equals(text, define.strip_definition_footnote_footer(text))
./tests/unit/define_spec.lua:222:        }, "\n"), define.strip_definition_footnote_footer(text))

codex
One likely contract edge is reapplying a definition when the line already has `[^id]`; I’m going to verify that behavior directly through the pure helper, then run the focused unit specs if the environment cooperates.
exec
/bin/zsh -lc "nl -ba tests/unit/define_spec.lua | sed -n '130,230p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   130	    it("slugifies a definition term into a markdown footnote id", function()
   131	        assert.equals("amazon-standard-identification-number",
   132	            define.footnote_id("Amazon Standard Identification Number"))
   133	        assert.equals("asin", define.footnote_id("ASIN"))
   134	    end)
   135	
   136	    it("adds an inline footnote reference and appends a managed footer", function()
   137	        local result = define.apply_definition_footnote(
   138	            { "here is ASIN in context" },
   139	            1, 8, 1, 11,
   140	            "ASIN",
   141	            "Amazon Standard Identification Number."
   142	        )
   143	
   144	        assert.are.same({
   145	            "here is ASIN[^asin] in context",
   146	            "",
   147	            "---",
   148	            "",
   149	            "[^asin]: Amazon Standard Identification Number.",
   150	        }, result.lines)
   151	        assert.are.same({ lnum = 0, col = 8, end_lnum = 0, end_col = 19 }, result.diagnostic_span)
   152	        assert.equals("asin", result.id)
   153	        assert.equals("Amazon Standard Identification Number.", result.definition)
   154	    end)
   155	
   156	    it("updates an existing managed footnote instead of duplicating it", function()
   157	        local result = define.apply_definition_footnote(
   158	            {
   159	                "ASIN is here",
   160	                "",
   161	                "---",
   162	                "",
   163	                "[^asin]: old definition",
   164	            },
   165	            1, 0, 1, 3,
   166	            "ASIN",
   167	            "Amazon Standard Identification Number."
   168	        )
   169	
   170	        assert.are.same({
   171	            "ASIN[^asin] is here",
   172	            "",
   173	            "---",
   174	            "",
   175	            "[^asin]: Amazon Standard Identification Number.",
   176	        }, result.lines)
   177	    end)
   178	
   179	    it("strips only a final managed footnote footer", function()
   180	        local text = table.concat({
   181	            "answer text",
   182	            "",
   183	            "---",
   184	            "",
   185	            "[^asin]: Amazon Standard Identification Number.",
   186	        }, "\n")
   187	
   188	        assert.equals("answer text", define.strip_definition_footnote_footer(text))
   189	    end)
   190	
   191	    it("preserves ordinary horizontal rules that are not managed footnote footers", function()
   192	        local text = table.concat({
   193	            "answer text",
   194	            "",
   195	            "---",
   196	            "",
   197	            "not a footnote",
   198	        }, "\n")
   199	
   200	        assert.equals(text, define.strip_definition_footnote_footer(text))
   201	    end)
   202	
   203	    it("keeps earlier horizontal-rule content and strips only the final managed footer", function()
   204	        local text = table.concat({
   205	            "answer text",
   206	            "",
   207	            "---",
   208	            "",
   209	            "ordinary body after a rule",
   210	            "",
   211	            "---",
   212	            "",
   213	            "[^asin]: Amazon Standard Identification Number.",
   214	        }, "\n")
   215	
   216	        assert.equals(table.concat({
   217	            "answer text",
   218	            "",
   219	            "---",
   220	            "",
   221	            "ordinary body after a rule",
   222	        }, "\n"), define.strip_definition_footnote_footer(text))
   223	    end)
   224	end)

exec
/bin/zsh -lc "nvim --headless -u NONE -c 'set rtp+=.' -c 'lua local d=require(\"parley.define\"); local r=d.apply_definition_footnote({\"ASIN["'^asin] is here", "", "---", "", "[''^asin]: old"}, 1, 0, 1, 3, "ASIN", "new"); print(table.concat(r.lines, "'"\\\\n\")); vim.cmd(\"qa\")'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
ASIN[^asin][^asin] is here\n\n---\n\n[^asin]: new
exec
/bin/zsh -lc "nl -ba tests/unit/build_messages_spec.lua | sed -n '704,815p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   704	    end)
   705	end)
   706	
   707	describe("_build_messages: durable definition footnotes", function()
   708	    it("strips managed definition footnote footers from user and assistant content", function()
   709	        local question = table.concat({
   710	            "What is ASIN?",
   711	            "",
   712	            "---",
   713	            "",
   714	            "[^asin]: Amazon Standard Identification Number.",
   715	        }, "\n")
   716	        local answer = table.concat({
   717	            "ASIN is an identifier.",
   718	            "",
   719	            "---",
   720	            "",
   721	            "[^asin]: Amazon Standard Identification Number.",
   722	        }, "\n")
   723	        local pc = parsed_chat({ exchange(question, answer), exchange("Next") })
   724	        pc.exchanges[1].question.line_start = 10
   725	        pc.exchanges[1].answer.line_start = 12
   726	        pc.exchanges[2].question.line_start = 20
   727	
   728	        local messages = parley._build_messages({
   729	            parsed_chat = pc,
   730	            start_index = 1,
   731	            end_index = 100,
   732	            exchange_idx = 2,
   733	            agent = agent(),
   734	            config = parley.config,
   735	            helpers = stub_helpers,
   736	            logger = stub_logger
   737	        })
   738	
   739	        assert.equals("What is ASIN?", messages[2].content)
   740	        assert.equals("ASIN is an identifier.", messages[3].content)
   741	        assert.is_nil(messages[2].content:find("%[%^asin%]:"))
   742	        assert.is_nil(messages[3].content:find("%[%^asin%]:"))
   743	    end)
   744	
   745	    it("preserves ordinary horizontal-rule content that is not a managed footer", function()
   746	        local answer = table.concat({
   747	            "first half",
   748	            "",
   749	            "---",
   750	            "",
   751	            "second half, not a footnote",
   752	        }, "\n")
   753	        local pc = parsed_chat({ exchange("Q", answer), exchange("Next") })
   754	        pc.exchanges[1].question.line_start = 10
   755	        pc.exchanges[1].answer.line_start = 12
   756	        pc.exchanges[2].question.line_start = 20
   757	
   758	        local messages = parley._build_messages({
   759	            parsed_chat = pc,
   760	            start_index = 1,
   761	            end_index = 100,
   762	            exchange_idx = 2,
   763	            agent = agent(),
   764	            config = parley.config,
   765	            helpers = stub_helpers,
   766	            logger = stub_logger
   767	        })
   768	
   769	        assert.equals(answer, messages[3].content)
   770	    end)
   771	
   772	    it("keeps earlier horizontal-rule content and strips only the final managed footer", function()
   773	        local answer = table.concat({
   774	            "first half",
   775	            "",
   776	            "---",
   777	            "",
   778	            "second half",
   779	            "",
   780	            "---",
   781	            "",
   782	            "[^asin]: Amazon Standard Identification Number.",
   783	        }, "\n")
   784	        local pc = parsed_chat({ exchange("Q", answer), exchange("Next") })
   785	        pc.exchanges[1].question.line_start = 10
   786	        pc.exchanges[1].answer.line_start = 12
   787	        pc.exchanges[2].question.line_start = 20
   788	
   789	        local messages = parley._build_messages({
   790	            parsed_chat = pc,
   791	            start_index = 1,
   792	            end_index = 100,
   793	            exchange_idx = 2,
   794	            agent = agent(),
   795	            config = parley.config,
   796	            helpers = stub_helpers,
   797	            logger = stub_logger
   798	        })
   799	
   800	        assert.equals(table.concat({
   801	            "first half",
   802	            "",
   803	            "---",
   804	            "",
   805	            "second half",
   806	        }, "\n"), messages[3].content)
   807	    end)
   808	end)
   809	
   810	describe("_build_messages: whitespace trimming", function()
   811	    it("trims leading and trailing whitespace from all message content", function()
   812	        local ex = exchange("  Question with spaces  ", "  Answer with spaces  ")
   813	        ex.question.line_start = 10
   814	        ex.answer.line_start = 12
   815	

exec
/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"' in /Users/xianxu/workspace/parley.nvim
 succeeded in 1449ms:

Parley.nvim: Failed to open file for writing: /Users/xianxu/.local/share/nvim/parley/persisted/state.jsonScheduling: tests/unit/define_spec.lua

========================================	
Testing: 	/Users/xianxu/workspace/parley.nvim/tests/unit/define_spec.lua	
[32mSuccess[0m	||	define.slice_selection extracts a single-line span	
[32mSuccess[0m	||	define.slice_selection extracts a multi-line span joined with newline	
[32mSuccess[0m	||	define.slice_selection clamps an end column past line length	
[32mSuccess[0m	||	define.slice_selection returns empty string for a reversed/empty span	
[32mSuccess[0m	||	define.context_for_selection returns the enclosing exchange's lines (question..answer)	
[32mSuccess[0m	||	define.context_for_selection handles an answerless exchange (question only)	
[32mSuccess[0m	||	define.context_for_selection falls back to the whole buffer when outside any exchange	
[32mSuccess[0m	||	define.format_definition composes 'TERM — definition'	
[32mSuccess[0m	||	define.format_definition hard-wraps to width	
[32mSuccess[0m	||	define.format_definition trims a nil/blank definition to a safe string	
[32mSuccess[0m	||	define.bracket_edit wraps a single-line span into a set_lines edit	
[32mSuccess[0m	||	define.bracket_edit clamps end col past line length	
[32mSuccess[0m	||	define.bracket_edit wraps a multi-line span	
[32mSuccess[0m	||	define.diagnostic_span_after_bracket anchors a single-line selection on the selected text after brackets	
[32mSuccess[0m	||	define.diagnostic_span_after_bracket anchors a multi-line selection without shifting the final line	
[32mSuccess[0m	||	define durable footnotes slugifies a definition term into a markdown footnote id	
[32mSuccess[0m	||	define durable footnotes adds an inline footnote reference and appends a managed footer	
[32mSuccess[0m	||	define durable footnotes updates an existing managed footnote instead of duplicating it	
[32mSuccess[0m	||	define durable footnotes strips only a final managed footnote footer	
[32mSuccess[0m	||	define durable footnotes preserves ordinary horizontal rules that are not managed footnote footers	
[32mSuccess[0m	||	define durable footnotes keeps earlier horizontal-rule content and strips only the final managed footer	
	
[32mSuccess: [0m	21	
[31mFailed : [0m	0	
[31mErrors : [0m	0	
========================================	
]111
codex
The focused pure spec passes, but the direct helper probe confirms one uncovered edge: selecting `ASIN` again in `ASIN[^asin]` creates `ASIN[^asin][^asin]` while updating the footer. I’m checking docs exposure now to decide whether that is the only gate-relevant issue.
exec
/bin/zsh -lc 'git diff --check -- lua/parley/define.lua lua/parley/init.lua lua/parley/buffer_edit.lua lua/parley/chat_respond.lua tests/unit/define_spec.lua tests/integration/define_spec.lua tests/unit/build_messages_spec.lua atlas/chat/inline_define.md workshop/issues/000166-visual-selection-definition-system-manages-footnote.md workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md' in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc 'rg -n "define|definition|M-CR|<M-CR>|footnote|ASIN|inline" README.md atlas lua tests workshop/issues/000166-visual-selection-definition-system-manages-footnote.md workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
 succeeded in 0ms:
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:12:# move visual selection definition system to be based on durable footnote
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:14:Right now, the definition is inserted as diagnosis, and convert the text to [anchor text]. Persisting the definition is useful, and let's do that. It works roughly like the following:
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:16:1. when a `definition` is selected and queried, we do the same LLM call, get back definition. 
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:17:2. then we insert a footnote for that definition: [^definition]: .... 
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:18:3. at end of chat transcript, we manage a section of footnote. footnote is separated from main chat with a divider line ---. 
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:19:4. then we stop converting definition to anchor text [definition] as we have definition [^definition]. 
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:20:5. diagnosis should pull definition stored in footnote directly. 
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:21:6. footnote is not submitted to LLM.
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:25:Inline visual definitions currently write only an ephemeral diagnostic and a
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:26:minimal `[term]` text anchor. The definition itself disappears from the chat
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:28:Persisting the definition in ordinary markdown footnotes solves that, but the
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:29:managed footnote block must not become part of the next LLM prompt.
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:33:Visual-selecting a term and invoking definition keeps the existing LLM lookup
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:36:- The selected text remains readable in place and gains a markdown footnote
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:38:- The definition is stored in a managed footnote footer at the end of the chat
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:41:  `---` line in the content, followed only by blank lines and markdown footnote
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:42:  definitions (`[^id]: text`). Any ordinary horizontal rule, or any trailing
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:43:  block that mixes non-footnote prose after `---`, stays part of chat content.
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:44:- Re-defining an existing term updates the corresponding managed footnote line
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:46:- The diagnostic text is still shown inline, but it is derived from the stored
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:47:  footnote definition rather than being the only copy of the definition.
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:48:- The managed footnote footer is stripped from message content before payload
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:51:ARCH-PURE: footnote slugging, footer insertion/update, and footer stripping live
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:52:in `lua/parley/define.lua` as pure helpers with unit coverage. ARCH-DRY: the same
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:59:- Defining `ASIN` rewrites the line to include `ASIN[^asin]` and appends or
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:61:- Existing no-definition and empty-selection safeguards remain intact.
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:62:- Built LLM messages exclude only the managed final footnote footer; ordinary
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:64:- Focused define/build-message tests and the full suite pass.
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:84:- [x] Implement pure definition-footnote helpers in `lua/parley/define.lua`.
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:85:- [x] Render visual definitions as durable markdown footnotes while preserving
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:87:- [x] Strip managed definition footnotes from LLM message content.
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:88:- [x] Update inline-define atlas docs and run focused/full verification.
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:96:  `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"` first
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:97:  failed on missing footnote helpers, then passed after adding pure helpers.
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:99:  `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:100:  first failed on `[ASIN]` output, then passed after rendering durable footnotes.
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:104:  `define.strip_definition_footnote_footer` through message construction.
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:106:  tool-loop payload construction also strips managed definition footers.
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:108:  `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"` passed
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:110:  `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:114:  `git diff --check -- lua/parley/define.lua lua/parley/init.lua lua/parley/buffer_edit.lua lua/parley/chat_respond.lua tests/unit/define_spec.lua tests/integration/define_spec.lua tests/unit/build_messages_spec.lua atlas/chat/inline_define.md workshop/issues/000166-visual-selection-definition-system-manages-footnote.md workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md`
workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:119:  integration, and arch tests green. After replacing `define.lua`'s remaining
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:5:**Goal:** Persist visual-selection definitions as managed markdown footnotes while keeping the durable footnote section out of LLM submissions.
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:7:**Architecture:** Keep document transforms in `lua/parley/define.lua` as pure helpers (ARCH-PURE), put buffer writes behind `lua/parley/buffer_edit.lua`, and keep `render_definition` as the thin IO shell that stitches lookup results to the pure transform. `chat_respond.build_messages` receives already-parsed exchanges, so it will scrub only the managed final footnote footer from question/answer strings before adding messages (ARCH-PURPOSE).
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:19:| `DefinitionFootnote` | `lua/parley/define.lua` | new |
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:20:| `DefinitionFootnoteFooter` | `lua/parley/define.lua` | new |
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:21:| `DefinitionSubmissionScrubber` | `lua/parley/define.lua` | new |
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:23:- **DefinitionFootnote** — a durable markdown footnote pair: inline reference `[^definition]` plus footer line `[^definition]: ...`.
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:24:  - **Relationships:** N:1 with a chat file; many selected terms may create footnotes in one managed footer.
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:28:- **DefinitionFootnoteFooter** — pure transform that inserts or updates a managed footnote section after the transcript separator.
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:33:- **DefinitionSubmissionScrubber** — pure helper that removes the managed footnote footer from strings before they are sent to the LLM.
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:42:| `render_definition` | `lua/parley/init.lua` | modified | Neovim diagnostics/projection |
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:46:- **render_definition** — after `emit_definition`, verifies the selection, rewrites the selected text to include a footnote reference, stores/updates the managed footer, and attaches the current-line diagnostic from the durable footnote text.
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:48:  - **Future extensions:** On-cursor rehydration can later read existing footnotes without a new LLM call.
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:50:- **DefinitionBufferEdit** — chat-buffer mutation entry point for full-buffer definition-footnote rewrites.
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:51:  - **Injected into:** `render_definition`.
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:54:- **chat_respond.build_messages** — strips managed definition footnotes from preserved and summarized exchange content.
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:56:  - **Future extensions:** Live-model recursion path can consume the same scrubber if footnotes ever appear during tool-loop recursion.
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:63:- Modify: `lua/parley/define.lua`
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:64:- Test: `tests/unit/define_spec.lua`
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:69:- `footnote_id("Amazon Standard Identification Number")` returns `amazon-standard-identification-number`.
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:70:- `apply_definition_footnote` changes `here is ASIN in context` to `here is ASIN[^asin] in context`.
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:81:Run: `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:87:In `lua/parley/define.lua`, add:
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:88:- `footnote_id(term)`
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:89:- `format_footnote_line(id, definition)`
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:90:- `apply_definition_footnote(lines, l1, c1, l2, c2, term, definition)`
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:91:- `strip_definition_footnote_footer(text)`
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:100:Add negative tests that prove ordinary horizontal rules are preserved when the trailing block contains non-footnote prose.
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:104:Run: `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:115:- Test: `tests/integration/define_spec.lua`
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:117:- [x] **Step 1: Update the integration test to expect footnotes**
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:119:Replace the bracket assertion in `define_visual + render_definition`:
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:120:- selected line becomes `here is ASIN[^asin] in context`
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:122:- diagnostic message still includes `ASIN`
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:123:- diagnostic range anchors to selected text plus footnote reference as appropriate for the current render.
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:125:Run: `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:127:Expected: FAIL because render still writes `[ASIN]`.
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:131:In `lua/parley/buffer_edit.lua`, add a named wrapper such as `replace_all_lines_for_definition(buf, lines)` delegating to `replace_all_lines`. This keeps call sites semantically clear and avoids adding new direct `nvim_buf_set_lines` callers.
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:133:- [x] **Step 3: Wire `render_definition` to the pure transform**
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:136:- Replace `define.bracket_edit` with `define.apply_definition_footnote`.
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:137:- Use `buffer_edit.replace_all_lines_for_definition` for the rewrite.
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:139:- Set the diagnostic text from the durable footnote definition. The diagnostic itself remains ephemeral, but its source text is now persisted.
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:144:- `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:145:- `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:172:- `answer\n\n---\n\nnot a footnote` is not stripped.
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:173:- A message with an earlier horizontal rule and a final managed footnote block keeps the earlier horizontal rule content and strips only the final managed block.
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:174:- Both user and assistant content pass through the same `strip_definition_footnote_footer` helper.
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:182:In `chat_respond.build_messages`, call `define.strip_definition_footnote_footer` before inserting string question/answer/summary content into `messages`. Keep content-block arrays unchanged unless they contain text blocks created from parsed answer strings; for the parse path, scrub flat string content first.
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:201:- Modify: `atlas/chat/inline_define.md`
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:202:- Modify: `workshop/issues/000166-visual-selection-definition-system-manages-footnote.md`
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:206:Update `atlas/chat/inline_define.md` to describe durable footnotes, managed footer, and LLM-submission exclusion.
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:215:- `git diff --check -- lua/parley/define.lua lua/parley/init.lua lua/parley/buffer_edit.lua lua/parley/chat_respond.lua tests/unit/define_spec.lua tests/integration/define_spec.lua tests/unit/build_messages_spec.lua atlas/chat/inline_define.md workshop/issues/000166-visual-selection-definition-system-manages-footnote.md`
workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:220:Actual: focused define, integration define, and build-message specs passed;
README.md:118:- `<M-CR>` respond (normal/insert); **visual-select a phrase + `<M-CR>`** → inline term definition — a concise grey pop-under at the phrase (nothing written to the transcript), honoring `:ToggleWebSearch` for unfamiliar terms
README.md:126:- `<C-g>i` to insert a fork in the chat tree, can be inline or standalone
tests/fixtures/anthropic_tool_use_request.json:15:      "content": "Please read the file at lua/parley/init.lua and tell me the first function definition you see."
atlas/export/tree_export.md:7:- Children: `-> Branch: <topic>` inline
atlas/export/formats.md:4:Self-contained HTML with inline CSS. Title from `# topic:` line; path copied to `+` register.
lua/parley/define.lua:1:-- Pure core for the inline term-definition feature (#161).
lua/parley/define.lua:3:-- are unit-tested directly (tests/unit/define_spec.lua). The IO shell
lua/parley/define.lua:4:-- (define_visual / render_definition) lives in lua/parley/init.lua.
lua/parley/define.lua:66:--- Compose the diagnostic message ("TERM — definition"), hard-wrapped to width.
lua/parley/define.lua:69:--- @param definition string|nil
lua/parley/define.lua:72:function M.format_definition(term, definition, width)
lua/parley/define.lua:73:    definition = definition or ""
lua/parley/define.lua:74:    definition = (definition:gsub("%s+$", "")) -- parens → keep only the string
lua/parley/define.lua:75:    if definition == "" then
lua/parley/define.lua:76:        definition = "(no definition)"
lua/parley/define.lua:78:    local head = tostring(term or "") .. " — " .. definition
lua/parley/define.lua:137:--- Convert a term into a stable markdown footnote id.
lua/parley/define.lua:140:function M.footnote_id(term)
lua/parley/define.lua:145:        id = "definition"
lua/parley/define.lua:151:--- @param definition string|nil
lua/parley/define.lua:153:function M.format_footnote_line(id, definition)
lua/parley/define.lua:154:    definition = trim(definition)
lua/parley/define.lua:155:    if definition == "" then
lua/parley/define.lua:156:        definition = "(no definition)"
lua/parley/define.lua:158:    return string.format("[^%s]: %s", id, definition)
lua/parley/define.lua:165:local function is_footnote_line(line)
lua/parley/define.lua:172:            local has_footnote = false
lua/parley/define.lua:176:                    if not is_footnote_line(line) then
lua/parley/define.lua:179:                    has_footnote = true
lua/parley/define.lua:182:            if has_footnote then
lua/parley/define.lua:218:--- Strip a final managed definition-footnote footer from text.
lua/parley/define.lua:221:function M.strip_definition_footnote_footer(text)
lua/parley/define.lua:240:local function replace_or_append_footnote(lines, id, definition)
lua/parley/define.lua:243:    local footnote_line = M.format_footnote_line(id, definition)
lua/parley/define.lua:248:                out[i] = footnote_line
lua/parley/define.lua:252:        out[#out + 1] = footnote_line
lua/parley/define.lua:262:    out[#out + 1] = footnote_line
lua/parley/define.lua:266:--- Insert a markdown footnote reference after the selected text and store the
lua/parley/define.lua:267:--- definition in a managed footer.
lua/parley/define.lua:274:--- @param definition string|nil
lua/parley/define.lua:275:--- @return table { lines: string[], id: string, definition: string, diagnostic_span: table }
lua/parley/define.lua:276:function M.apply_definition_footnote(lines, l1, c1, l2, c2, term, definition)
lua/parley/define.lua:277:    local id = M.footnote_id(term)
lua/parley/define.lua:289:    out = replace_or_append_footnote(out, id, definition)
lua/parley/define.lua:290:    local normalized_definition = trim(definition)
lua/parley/define.lua:291:    if normalized_definition == "" then
lua/parley/define.lua:292:        normalized_definition = "(no definition)"
lua/parley/define.lua:297:        definition = normalized_definition,
atlas/skills/skill-system.md:22:`execute_call` path as every chat tool — cwd-scope active, with an **inline
atlas/skills/skill-system.md:45:- `propose_edits` gains an inline numbered `.parley-backup` before each write.
atlas/index.md:13:- [Inline Branch Links](chat/inline_branch_links.md): Footnote-style `[🌿:text](file)` links within chat text.
atlas/index.md:15:- [Inline Term Definition](chat/inline_define.md): Visual-select a phrase + `<M-CR>` → concise context-aware definition as an ephemeral inline diagnostic (the `define` skill + `emit_definition` tool; honors `:ToggleWebSearch`).
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
atlas/traceability.yaml:66:  chat/inline_branch_links:
atlas/traceability.yaml:73:      - tests/unit/inline_branch_spec.lua
atlas/traceability.yaml:88:  chat/inline_define:
atlas/traceability.yaml:90:      - lua/parley/define.lua
atlas/traceability.yaml:92:      - lua/parley/skills/define/init.lua
atlas/traceability.yaml:93:      - lua/parley/tools/builtin/emit_definition.lua
atlas/traceability.yaml:100:      - tests/unit/define_spec.lua
atlas/traceability.yaml:101:      - tests/integration/define_spec.lua
lua/parley/highlighter.lua:440:--   * footnote refs                 — `[^1]`
lua/parley/highlighter.lua:654:    -- Check for user-defined highlight settings
lua/parley/highlighter.lua:660:        -- Use user-defined highlighting if provided
lua/parley/highlighter.lua:714:    if user_highlights.inline_branch then
lua/parley/highlighter.lua:715:        vim.api.nvim_set_hl(0, "ParleyInlineBranch", user_highlights.inline_branch)
lua/parley/highlighter.lua:813:	vim.api.nvim_set_hl(0, "@markup.strikethrough.markdown_inline", {})
lua/parley/highlighter.lua:842:-- Apply extmark-based highlighting for inline branch links [🌿:text](file).
lua/parley/highlighter.lua:844:local function highlight_inline_branch_links(buf, ranges)
lua/parley/highlighter.lua:847:    local ns = vim.api.nvim_create_namespace("parley_inline_branch")
lua/parley/highlighter.lua:855:            local links = chat_parser.extract_inline_branch_links(line, branch_prefix)
lua/parley/highlighter.lua:886:-- Debounced topic refresh for 🌿: branch references and inline [🌿:text](file) links.
lua/parley/highlighter.lua:892:    local has_inline_branches = false
lua/parley/highlighter.lua:900:            if #chat_parser.extract_inline_branch_links(line, branch_prefix) > 0 then
lua/parley/highlighter.lua:901:                has_inline_branches = true
lua/parley/highlighter.lua:903:            if has_branch_refs and has_inline_branches then break end
lua/parley/highlighter.lua:905:        if has_branch_refs and has_inline_branches then break end
lua/parley/highlighter.lua:908:    -- Always apply inline branch highlighting if present (no debounce needed)
lua/parley/highlighter.lua:909:    if has_inline_branches then
lua/parley/highlighter.lua:910:        highlight_inline_branch_links(buf, ranges)
lua/parley/skills/review/SKILL.md:1:You are a collaborative document editor. The document contains inline 🤖 review markers per the [review-convention](../../../../ariadne/workshop/targets/review-convention.md). Process all ready markers using the propose_edits tool.
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
atlas/chat/drill_in.md:22:- **Ready** = last section is a non-empty `[]` (matches the review-skill ready definition). Markers ending in `{}` are *pending* and stay inline as agent annotations. Strike markers are *never* ready (even with trailing `[]`, since they're proposals not questions).
atlas/chat/drill_in.md:24:The chat-respond pipeline gathers every ready marker (with or without `<T>`) — the difference is in how the marker collapses inline (see Lifecycle step 3). Strike markers are skipped entirely.
atlas/chat/drill_in.md:40:   - Marker with `<T>` body → inline replaced by plain `T`.
atlas/chat/drill_in.md:108:- **inline** (prose precedes the marker, or a bare marker sits mid-paragraph
atlas/chat/drill_in.md:114:- **degrades to empty** (→ no `>` line) when nothing is recoverable: inline with
atlas/chat/drill_in.md:129:encloses that span in `[]` in place — inline spans absorb the trailing gap +
atlas/chat/drill_in.md:135:skips markdown links `](`, checkboxes, footnote refs, and 1-char content — a
lua/parley/skills/review/diag_display.lua:1:-- diag_display.lua — inline display of review "why" diagnostics (#133 M6).
lua/parley/skills/review/diag_display.lua:19:--- Apply the inline-display config for parley's review namespace.
lua/parley/skills/review/diag_display.lua:29:--- Toggle inline display; returns the new state.
lua/parley/skills/review/diag_display.lua:36:--- Is inline display currently enabled?
lua/parley/drill_in.lua:12:--      stripped from the inline text into a quoted block prepended to the
lua/parley/drill_in.lua:15:--        * `🤖<Q>[U]`          → block `> Q` / `U`            ; inline → `Q`
lua/parley/drill_in.lua:16:--        * `🤖[U]`             → block `> Q̂` / `U`            ; inline removed
lua/parley/drill_in.lua:18:--                                `> Agent: A1` / `U2`        ; inline → `Q`
lua/parley/drill_in.lua:20:--                                `> Agent: A1` / `U2`         ; inline removed
lua/parley/drill_in.lua:27:--      (proposals, not questions) stay inline.
lua/parley/drill_in.lua:164:-- inline and previous-block scans.
lua/parley/drill_in.lua:255:--- (`🤖[a\nb]`) whose `byte_end` lands on a later line may mis-pick inline vs
lua/parley/drill_in.lua:287:    local function inline_region()
lua/parley/drill_in.lua:304:    local function from_inline()
lua/parley/drill_in.lua:305:        local lo, hi = inline_region()
lua/parley/drill_in.lua:330:        -- Bare marker mid-paragraph → inline from preceding lines.
lua/parley/drill_in.lua:335:    local t, s, e = from_inline()
lua/parley/drill_in.lua:342:--- knowledge has a single tested home instead of an inline closure in the
lua/parley/drill_in.lua:363:--- Gather ready markers and strip each from the inline text.
lua/parley/drill_in.lua:364:--- - Marker with `<Q>` body → inline replaced by Q.
lua/parley/drill_in.lua:365:--- - Marker without `<Q>` body → inline removed entirely; its block quote is
lua/parley/drill_in.lua:389:                -- Explicit <Q>: restore Q inline (optionally bracketed) — the
lua/parley/drill_in.lua:423:--- Resolve a marker to its final inline text per the review-convention §5
tests/arch/arch_helper.lua:33:--- within the file set defined by `scope`.
lua/parley/init.lua:22:	hooks = {}, -- user defined command functions
lua/parley/init.lua:205:-- Local helpers are defined as wrappers at the top of this file (near require).
lua/parley/init.lua:294:-- Forward declaration so setup() closure can reference it (defined after setup())
lua/parley/init.lua:770:	-- :ParleyShowDiagnostics — toggle inline display of review "why" diagnostics
lua/parley/init.lua:774:		M.logger.info("Parley review diagnostics: inline display " .. (on and "ON" or "OFF"))
lua/parley/init.lua:1020:		-- For OpenAI, require search_model to be defined on the model config
lua/parley/init.lua:1023:				local msg = string.format("Agent %s has no search_model defined", agent)
lua/parley/init.lua:1034:					local msg = string.format("Agent %s has no search_model defined", agent)
lua/parley/init.lua:1554:	-- #161 ARCH-DRY: one shared visual-selection slice (define.slice_selection).
lua/parley/init.lua:1557:	local selected = require("parley.define").slice_selection(
lua/parley/init.lua:1595:-- Inline term definition (#161 + R1, #166). render_definition is the on_done IO
lua/parley/init.lua:1596:-- seam. On a successful lookup it stores the definition as a durable markdown
lua/parley/init.lua:1597:-- footnote (ONE undo entry — the anchor), highlights the line (whole-line
lua/parley/init.lua:1598:-- DiffChange, review's scheme), and shows the definition as an ephemeral INFO
lua/parley/init.lua:1600:-- the footnote edit lands on the pre-edit content-hash → the empty snapshot
lua/parley/init.lua:1603:local function render_definition(buf, span, phrase, result)
lua/parley/init.lua:1604:	-- Pick the emit_definition call (unforced → the model may answer in text or
lua/parley/init.lua:1605:	-- only call web_search; both mean "no definition"). Notify rather than
lua/parley/init.lua:1606:	-- silently doing nothing, and leave no footnote edit.
lua/parley/init.lua:1610:			if c.name == "emit_definition" then
lua/parley/init.lua:1617:		M.logger.warning("Define: no definition returned")
lua/parley/init.lua:1622:	local define = require("parley.define")
lua/parley/init.lua:1627:	-- rather than attach a footnote reference to shifted text.
lua/parley/init.lua:1629:	if define.slice_selection(lines, sr, sc - 1, er, ec - 1) ~= phrase then
lua/parley/init.lua:1630:		M.logger.warning("Define: selection changed during lookup — re-select to define")
lua/parley/init.lua:1635:	-- Store the definition as a markdown footnote in ONE full-buffer set_lines
lua/parley/init.lua:1637:	-- define's projection watcher during our own edit (mirrors review).
lua/parley/init.lua:1640:	local e = define.apply_definition_footnote(lines, sr, sc - 1, er, ec - 1, input.term or phrase, input.definition)
lua/parley/init.lua:1641:	require("parley.buffer_edit").replace_all_lines_for_definition(buf, e.lines)
lua/parley/init.lua:1643:	-- Highlight the term's line(s) + the ephemeral definition diagnostic.
lua/parley/init.lua:1648:	local msg = define.format_definition(input.term or phrase, e.definition, width)
lua/parley/init.lua:1657:		source = "parley-define",
lua/parley/init.lua:1660:	-- Record projection states so undo/redo of the footnote edit clears/restores
lua/parley/init.lua:1662:	-- snapshot, footnoted hash → highlight+diagnostic; attach the watcher.
lua/parley/init.lua:1669:	-- virtual_lines reveals the definition immediately.
lua/parley/init.lua:1674:-- define_visual: the thin IO shell for visual-mode <M-CR>. Reads the selection,
lua/parley/init.lua:1675:-- computes the enclosing-exchange context, and fires a headless define skill
lua/parley/init.lua:1676:-- turn whose on_done stores + renders the definition inline. Pure logic lives
lua/parley/init.lua:1677:-- in lua/parley/define.lua. Exposed as M.define_visual for the keybinding.
lua/parley/init.lua:1678:function M.define_visual(buf)
lua/parley/init.lua:1687:	local define = require("parley.define")
lua/parley/init.lua:1689:	local phrase = define.slice_selection(lines, sr, sc - 1, er, ec - 1)
lua/parley/init.lua:1697:	local context = define.context_for_selection(parsed, sr, lines, M.find_exchange_at_line)
lua/parley/init.lua:1700:	local manifest = require("parley.skills.define")
lua/parley/init.lua:1704:		on_done = function(result) render_definition(buf, span, phrase, result) end,
lua/parley/init.lua:2006:	local function chat_insert_inline_branch_ref()
lua/parley/init.lua:2027:		local inline_link = "[" .. branch_prefix .. selected_text .. "](" .. rel_path .. ")"
lua/parley/init.lua:2028:		vim.api.nvim_buf_set_lines(buf, start_line - 1, start_line, false, { before .. inline_link .. after })
lua/parley/init.lua:2030:		M.logger.debug("Created inline branch to new chat: " .. rel_path .. " (" .. topic .. ")")
lua/parley/init.lua:2073:	-- #161: one respond-callback set, shared by chat_respond and chat_define.
lua/parley/init.lua:2075:	local function chat_define_v()
lua/parley/init.lua:2077:		M.define_visual()
lua/parley/init.lua:2098:					chat_insert_inline_branch_ref()
lua/parley/init.lua:2103:			-- #161: <M-CR> — n/i reuse the respond closures; v/x <Esc>-commit the
lua/parley/init.lua:2104:			-- '<,'> marks then run define_visual (visual <C-g><C-g> keeps respond).
lua/parley/init.lua:2105:			chat_define = { n = respond_cb.n, i = respond_cb.i, v = chat_define_v, x = chat_define_v },
lua/parley/init.lua:2143:	-- conceallevel=2 for inline branch link concealing and model header params
lua/parley/init.lua:2297:	local function md_insert_inline_branch_ref()
lua/parley/init.lua:2319:		local inline_link = "[" .. branch_prefix .. selected_text .. "](" .. chat_path .. ")"
lua/parley/init.lua:2320:		vim.api.nvim_buf_set_lines(buf, start_line - 1, start_line, false, { before .. inline_link .. after })
lua/parley/init.lua:2322:		M.logger.debug("Created inline branch to new chat: " .. chat_path .. " (" .. topic .. ")")
lua/parley/init.lua:2347:				v = md_insert_inline_branch_ref,
lua/parley/init.lua:2456:-- registered_chat_dir and chat_root_display are local wrappers defined at top of file.
lua/parley/init.lua:2732:-- Try to open an inline branch link [🌿:text](file) under the cursor.
lua/parley/init.lua:2734:local function try_open_inline_branch_link(current_line, cursor_col, parent_buf)
lua/parley/init.lua:2737:	local inline_links = chat_parser.extract_inline_branch_links(current_line, branch_prefix)
lua/parley/init.lua:2738:	for _, link in ipairs(inline_links) do
lua/parley/init.lua:3759:	-- Check for inline branch links [🌿:text](file) first
lua/parley/init.lua:3760:	if try_open_inline_branch_link(current_line, cursor_col, vim.api.nvim_get_current_buf()) then
lua/parley/init.lua:3893:	-- Handle inline branch links [🌿:text](file) — check if cursor is within one
lua/parley/init.lua:3894:	if try_open_inline_branch_link(current_line, cursor_col, buf) then
atlas/chat/inline_define.md:3:Select a phrase in a chat transcript, press **`<M-CR>`** (visual mode), and a
atlas/chat/inline_define.md:4:concise, context-aware definition appears as an **ephemeral inline diagnostic**
atlas/chat/inline_define.md:6:gets a markdown footnote reference (`ASIN[^asin]`), while the definition is
atlas/chat/inline_define.md:7:stored in a managed footnote footer at the end of the chat transcript. The
atlas/chat/inline_define.md:8:whole annotation is **undoable** — `u` reverts the footnote edit and clears both
atlas/chat/inline_define.md:9:decorations (see Undo below). For jargon you don't know (e.g. `ASIN`), it's a
atlas/chat/inline_define.md:11:[#161](../../workshop/issues/000161-inline-term-definition.md) (R1 added the
atlas/chat/inline_define.md:12:highlight/undo); [#166](../../workshop/issues/000166-visual-selection-definition-system-manages-footnote.md)
atlas/chat/inline_define.md:13:made the definition durable as a managed footnote.
atlas/chat/inline_define.md:17:1. **`define_visual(buf)`** (`lua/parley/init.lua`) reads the visual selection
atlas/chat/inline_define.md:18:   (`getpos`), extracts the phrase (`define.slice_selection`), guards
atlas/chat/inline_define.md:20:   exchange* of the selection (`define.context_for_selection` over `parse_chat`
atlas/chat/inline_define.md:22:2. It fires a headless **`define` skill** turn via `skill_invoke.invoke` with
atlas/chat/inline_define.md:24:3. The `define` skill (`lua/parley/skills/define/init.lua`) is **unforced** (no
atlas/chat/inline_define.md:27:   prompt and asks the model to call `emit_definition({term, definition})`.
atlas/chat/inline_define.md:28:4. **`render_definition`** (`on_done`), on a successful lookup: re-verifies the
atlas/chat/inline_define.md:31:   and inserts/updates a final managed footnote footer via one buffer rewrite
atlas/chat/inline_define.md:32:   (`define.apply_definition_footnote`) — a single undo entry that anchors
atlas/chat/inline_define.md:35:   the selected term/reference span (`define.format_definition` →
atlas/chat/inline_define.md:39:   (cursor parked on the term's line). A no-`emit_definition` response leaves no
atlas/chat/inline_define.md:40:   footnote reference/footer.
atlas/chat/inline_define.md:44:Native `u` reverts *text*, not decorations. The footnote reference/footer rewrite
atlas/chat/inline_define.md:46:**projection watcher** (`skills/review/projection.lua`, #133 M5), which define
atlas/chat/inline_define.md:47:reuses: `render_definition` calls `projection.record_empty_for(buf, original)`
atlas/chat/inline_define.md:48:(pre-footnote hash → empty snapshot), `record(buf)` (footnoted hash → the
atlas/chat/inline_define.md:49:highlight + diagnostic), `ensure_watch(buf)`. Undoing the footnote edit lands on
atlas/chat/inline_define.md:50:the pre-footnote content-hash → the empty snapshot renders → both decorations clear;
atlas/chat/inline_define.md:53:guards the edit so a prior define's watcher doesn't mistake it for a user edit.
atlas/chat/inline_define.md:57:- **Pure** (`lua/parley/define.lua`, unit-tested with plain tables): `slice_selection`,
atlas/chat/inline_define.md:58:  `context_for_selection`, `format_definition`, `bracket_edit` (plans the `[term]`
atlas/chat/inline_define.md:60:  mapping), `apply_definition_footnote` (durable footer transform), and
atlas/chat/inline_define.md:61:  `strip_definition_footnote_footer` (removes only a final `---` block followed
atlas/chat/inline_define.md:62:  solely by footnotes).
atlas/chat/inline_define.md:63:- **IO shell** (`lua/parley/init.lua`): `define_visual`, `render_definition`;
atlas/chat/inline_define.md:64:  `lua/parley/buffer_edit.lua` owns the full-buffer footnote rewrite.
atlas/chat/inline_define.md:79:`---` line followed by blank lines and footnote definitions counts as the
atlas/chat/inline_define.md:82:message strings before LLM submission, so durable definitions do not become
atlas/chat/inline_define.md:87:`<M-CR>` was split out of `chat_shortcut_respond` into its own `chat_define`
atlas/chat/inline_define.md:89:callback, so the split can't live inside `chat_respond`). The `chat_define`
atlas/chat/inline_define.md:90:per-mode callback is `{ n=respond, i=respond, v=define_visual, x=define_visual }`
atlas/chat/inline_define.md:91:— visual `<M-CR>` defines; normal/insert `<M-CR>` still responds; visual
atlas/chat/inline_define.md:105:`emit_definition` (`lua/parley/tools/builtin/emit_definition.lua`, in
atlas/chat/inline_define.md:106:`BUILTIN_NAMES`) is an **output-only** tool: `{term, definition}` schema,
atlas/chat/inline_define.md:114:  round-trip). Dismissal is via `u` — reverting the footnote reference/footer
atlas/chat/inline_define.md:116:  The footnote persists in the file if saved. Shared `parley_skill`
atlas/chat/inline_define.md:121:- `lua/parley/define.lua` — pure core (slice / context / format / footnote footer).
atlas/chat/inline_define.md:122:- `lua/parley/init.lua` — `define_visual`, `render_definition`, `chat_define` wiring.
atlas/chat/inline_define.md:123:- `lua/parley/chat_respond.lua` — strips managed footnote footer from LLM messages.
atlas/chat/inline_define.md:124:- `lua/parley/skills/define/init.lua` — the unforced `define` skill.
atlas/chat/inline_define.md:125:- `lua/parley/tools/builtin/emit_definition.lua` — output-only structured tool.
atlas/chat/inline_define.md:127:- `lua/parley/config.lua`, `lua/parley/keybinding_registry.lua` — the `<M-CR>` split.
atlas/chat/inline_define.md:128:- `tests/unit/define_spec.lua`, `tests/integration/define_spec.lua` — coverage.
atlas/chat/inline_define.md:133:  sibling; shares `define.slice_selection` for the visual-selection extraction.
tests/integration/review_diag_display_spec.lua:1:-- Integration tests for the review-diagnostic inline display toggle (#133 M6).
tests/integration/review_diag_display_spec.lua:27:        assert.is_false(on.virtual_text) -- inline single-line is never used
lua/parley/vision.lua:53:-- Parse an inline YAML list: "[a, b, c]" → {"a", "b", "c"}, "[]" → {}
lua/parley/vision.lua:54:local function parse_inline_list(value)
lua/parley/vision.lua:76:-- Parse a vision YAML file (list of maps with string values and inline lists).
lua/parley/vision.lua:92:        local list = parse_inline_list(val)
lua/parley/vision.lua:95:            -- All inline list items share the same line
lua/parley/vision.lua:1759:        -- Try inline list: find the item at cursor position within [...]
lua/parley/vision.lua:1823:-- For inline fields like "  type: te", key is "type" and partial is "te".
lua/parley/vision.lua:1850:    -- Case 2: inline field "  key: partial" (continuation key within an item)
lua/parley/vision.lua:1851:    -- Skip depends_on — it uses list items (case 1), not inline values
lua/parley/chat_finder.lua:795:							-- Handle insert mode insertion (inline branch link)
lua/parley/chat_finder.lua:804:							local inline_link = "[" .. branch_prefix .. topic .. "](" .. rel_path .. ")"
lua/parley/chat_finder.lua:805:							local new_line = current_line:sub(1, col) .. inline_link .. current_line:sub(col + 1)
lua/parley/chat_finder.lua:818:								col + #inline_link,
atlas/chat/format.md:17:- Inline variant: `[🌿:text](file.md)` — see `inline_branch_links.md`
lua/parley/skill_providers.lua:31:-- Build a manifest from a loaded skill-definition table + its absolute dir.
lua/parley/system_prompt_msgs.lua:15:--      payload.system; OpenAI/Google leave them inline. Existing
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
lua/parley/tools/backup.lua:6:-- write-path prelude generalizes this, the tools call it inline — ARCH-DRY: one
lua/parley/chat_parser.lua:98:--     { path = "...", topic = "...", line = N, after_exchange = N, inline = bool|nil },
lua/parley/chat_parser.lua:104:--- Pure function: extracts all inline branch links from a line.
lua/parley/chat_parser.lua:108:M.extract_inline_branch_links = function(line, branch_prefix)
lua/parley/chat_parser.lua:127:--- Unpack inline branch links from a line, replacing [🌿:text](file) with just text.
lua/parley/chat_parser.lua:131:--- @return string the line with inline links replaced by their display text
lua/parley/chat_parser.lua:132:M.unpack_inline_branch_links = function(line, branch_prefix)
lua/parley/chat_parser.lua:532:			-- Detect inline branch links on the question prefix line
lua/parley/chat_parser.lua:533:			local q_inline = M.extract_inline_branch_links(question_content, branch_prefix)
lua/parley/chat_parser.lua:534:			if #q_inline > 0 then
lua/parley/chat_parser.lua:535:				question_content = M.unpack_inline_branch_links(question_content, branch_prefix)
lua/parley/chat_parser.lua:553:			-- Add inline branch links from the question prefix line
lua/parley/chat_parser.lua:554:			for _, ib in ipairs(q_inline) do
lua/parley/chat_parser.lua:560:					inline = true,
lua/parley/chat_parser.lua:564:			-- Check for inline @@ file references on the user prefix line itself
lua/parley/chat_parser.lua:565:			local inline_refs = extract_file_refs(question_content)
lua/parley/chat_parser.lua:566:			for _, ref_path in ipairs(inline_refs) do
lua/parley/chat_parser.lua:572:				logger.debug("Found inline file reference on user line: " .. ref_path)
lua/parley/chat_parser.lua:748:			-- Detect inline branch links [🌿:text](file) and add to branches
lua/parley/chat_parser.lua:749:			local inline_branches = M.extract_inline_branch_links(line, branch_prefix)
lua/parley/chat_parser.lua:750:			for _, ib in ipairs(inline_branches) do
lua/parley/chat_parser.lua:756:					inline = true,
lua/parley/chat_parser.lua:759:			-- Unpack inline links to plain text for LLM context
lua/parley/chat_parser.lua:760:			local content_line = #inline_branches > 0
lua/parley/chat_parser.lua:761:				and M.unpack_inline_branch_links(line, branch_prefix)
lua/parley/tools/builtin/propose_edits.lua:12:-- inline here today (the dispatcher's write-path prelude is deferred). The
lua/parley/issues.lua:366:-- can't see — wrap it in the user's INTERACTIVE shell so the rc-defined function
lua/parley/tools/builtin/emit_definition.lua:1:-- `emit_definition` — output-only structured tool for the inline term-definition
lua/parley/tools/builtin/emit_definition.lua:3:-- {term, definition}; there are NO side effects — define's on_done reads the
lua/parley/tools/builtin/emit_definition.lua:4:-- tool-call args (result.calls[1].input) and renders them as an inline
lua/parley/tools/builtin/emit_definition.lua:10:    name = "emit_definition",
lua/parley/tools/builtin/emit_definition.lua:12:    description = "Return a concise definition of the selected term as used in "
lua/parley/tools/builtin/emit_definition.lua:17:            term = { type = "string", description = "The term being defined." },
lua/parley/tools/builtin/emit_definition.lua:18:            definition = {
lua/parley/tools/builtin/emit_definition.lua:20:                description = "A concise 1–3 sentence definition of the term, in context.",
lua/parley/tools/builtin/emit_definition.lua:23:        required = { "term", "definition" },
lua/parley/tools/builtin/emit_definition.lua:26:        -- No-op: the value lives in the tool-call args, consumed by define's
lua/parley/tools/builtin/emit_definition.lua:28:        return { content = "", name = "emit_definition" }
atlas/chat/inline_branch_links.md:4:- `[🌿:display text](file.md)` — inline within any line (vs full-line `🌿:` on its own line)
atlas/chat/inline_branch_links.md:16:- Multiple inline links per line supported
atlas/chat/inline_branch_links.md:19:- `<C-g>o` on inline link opens referenced file
atlas/chat/inline_branch_links.md:24:- HTML: `<a href="child.html" class="branch-inline">display text</a>`
atlas/chat/inline_branch_links.md:25:- Jekyll: `<a href="{% post_url slug %}" class="branch-inline">display text</a>`
tests/integration/skill_providers_spec.lua:41:        -- beta: { skill = {...} } shape, inline source closure, no SKILL.md
tests/integration/skill_providers_spec.lua:82:    it("unwraps the { skill = {...} } shape and honors an inline source", function()
tests/integration/define_spec.lua:1:-- Integration tests for the inline term-definition feature (#161).
tests/integration/define_spec.lua:2:-- See workshop/issues/000161-inline-term-definition.md and its plan.
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
tests/integration/define_spec.lua:70:        local body = skill.source({ args = { phrase = "ASIN" }, repo_root = "." })
tests/integration/define_spec.lua:71:        assert.is_true(body:find("ASIN", 1, true) ~= nil)
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
tests/integration/define_spec.lua:206:        vim.fn.writefile({ "line one", "line two", "here is ASIN in context", "line four", "       " }, path)
tests/integration/define_spec.lua:219:                raw_response = emit_definition_sse("ASIN", "Amazon Standard Identification Number."),
tests/integration/define_spec.lua:241:    it("stores the definition as a durable footnote, highlights the line, and shows the diagnostic", function()
tests/integration/define_spec.lua:242:        -- select "ASIN" on line 3 (cols 9..12, 1-based)
tests/integration/define_spec.lua:245:        require("parley").define_visual(buf)
tests/integration/define_spec.lua:250:        assert.are.equal("here is ASIN[^asin] in context",
tests/integration/define_spec.lua:262:        assert.are.equal(19, diags[1].end_col) -- ASIN plus [^asin]
tests/integration/define_spec.lua:263:        assert.is_true(diags[1].message:find("ASIN", 1, true) ~= nil)
tests/integration/define_spec.lua:268:    it("u undoes the footnote edit + clears decorations; C-r restores them (R1)", function()
tests/integration/define_spec.lua:271:        require("parley").define_visual(buf)
tests/integration/define_spec.lua:275:        assert.are.equal("here is ASIN[^asin] in context",
tests/integration/define_spec.lua:278:        -- undo: the footnote edit reverts; the projection watcher (TextChanged) clears
tests/integration/define_spec.lua:281:        -- covered by projection's own specs; here we verify define's records).
tests/integration/define_spec.lua:284:        assert.are.equal("here is ASIN in context",
tests/integration/define_spec.lua:287:            :find("%[%^asin%]:", 1, false), "footnote not removed on undo")
tests/integration/define_spec.lua:292:        -- redo: footnote edit + decorations return
tests/integration/define_spec.lua:295:        assert.are.equal("here is ASIN[^asin] in context",
tests/integration/define_spec.lua:306:        require("parley").define_visual(buf)
tests/integration/define_spec.lua:322:        require("parley").define_visual(buf)
tests/integration/define_spec.lua:327:        assert.are.equal("here is ASIN in context",
tests/integration/define_spec.lua:329:            "a no-tool response must not footnote the term")
tests/integration/define_spec.lua:333:describe("define keybinding split (#161)", function()
tests/integration/define_spec.lua:337:    it("routes visual <M-CR> to define, keeps visual <C-g><C-g> as respond, n/i respond", function()
tests/integration/define_spec.lua:340:        -- Mirror the production chat_define callback: n/i = respond, v/x = define.
tests/integration/define_spec.lua:348:            chat_define = {
tests/integration/define_spec.lua:351:                v = function() who = "define" end,
tests/integration/define_spec.lua:352:                x = function() who = "define" end,
tests/integration/define_spec.lua:373:        -- visual <M-CR> → define; visual <C-g><C-g> → respond (resubmit preserved)
tests/integration/define_spec.lua:374:        assert.are.equal("define", invoke("x", "<M-CR>"))
tests/integration/define_spec.lua:376:        -- normal/insert <M-CR> → respond (unchanged)
tests/integration/define_spec.lua:377:        assert.are.equal("respond", invoke("n", "<M-CR>"))
tests/integration/define_spec.lua:378:        assert.are.equal("respond", invoke("i", "<M-CR>"))
tests/integration/define_spec.lua:379:        -- chat_respond no longer binds <M-CR> (no double-bind): exactly one per mode
tests/integration/define_spec.lua:382:            if r.mode == "x" and r.key == "<M-CR>" then
tests/integration/define_spec.lua:386:        assert.are.equal(1, mcr_x_count, "<M-CR> must be bound exactly once in visual mode")
tests/integration/define_spec.lua:389:    it("real prep_chat wiring: <M-CR>/<C-g><C-g> buffer-mapped in visual mode", function()
tests/integration/define_spec.lua:391:        -- catches a chat_define id/key mismatch that would silently no-op.
tests/integration/define_spec.lua:401:        local mcr = vim.fn.maparg("<M-CR>", "x", false, true)
tests/integration/define_spec.lua:403:            "<M-CR> not buffer-mapped in visual mode after prep_chat")
tests/integration/define_spec.lua:412:describe("define: context_for_selection vs real parse_chat (#161)", function()
tests/integration/define_spec.lua:415:        local define = require("parley.define")
tests/integration/define_spec.lua:427:            "💬: define ASIN",
tests/integration/define_spec.lua:428:            "🤖: ASIN is a product id",
tests/integration/define_spec.lua:433:        -- the "define ASIN" question is line 8 (1-based)
tests/integration/define_spec.lua:434:        local ctx = define.context_for_selection(parsed, 8, lines, parley.find_exchange_at_line)
tests/integration/define_spec.lua:435:        assert.is_true(ctx:find("ASIN", 1, true) ~= nil, "enclosing exchange must be present")
tests/integration/review_menu_spec.lua:81:    it("review.setup_keymaps binds <M-o> (skill picker) + <M-CR> (review menu) on a markdown doc", function()
tests/integration/review_menu_spec.lua:86:        p.config.review_shortcut_next = { modes = { "n", "i" }, shortcut = "<M-CR>" }
tests/integration/review_menu_spec.lua:99:        assert.is_true(has_desc("n", "open mode menu"), "<M-CR> → review menu (normal)")
tests/integration/review_menu_spec.lua:100:        assert.is_true(has_desc("i", "open mode menu"), "<M-CR> → review menu (insert)")
lua/parley/skills/define/init.lua:1:-- The `define` skill (#161): define a user-selected term concisely, inline.
lua/parley/skills/define/init.lua:4:-- `define_visual` (lua/parley/init.lua) via skill_invoke with args.phrase and a
lua/parley/skills/define/init.lua:11:    name = "define",
lua/parley/skills/define/init.lua:12:    description = "Define a selected term concisely, inline.",
lua/parley/skills/define/init.lua:15:    tools = { "emit_definition" },
lua/parley/skills/define/init.lua:22:        "You define a single term for a reader of a chat transcript.",
lua/parley/skills/define/init.lua:27:        "you may search first. Then ALWAYS call the emit_definition tool exactly",
lua/parley/skills/define/init.lua:28:        "once with {term, definition}. Do not reply in plain prose.",
tests/perf_chat_finder.lua:127:	-- Fallback scan for old code (no cache, inline reimplementation of the scan loop)
lua/parley/chat_respond.lua:337:    local define = require("parley.define")
lua/parley/chat_respond.lua:356:        -- an inline copy of the interleaving that had diverged from the parse
lua/parley/chat_respond.lua:378:                text = define.strip_definition_footnote_footer(text)
lua/parley/chat_respond.lua:390:                local text = define.strip_definition_footnote_footer(read_block_text(k, b))
lua/parley/chat_respond.lua:409:                    table.insert(answer_blocks, { type = "text", text = define.strip_definition_footnote_footer(text) })
lua/parley/chat_respond.lua:427:                    table.insert(messages, { role = "user", content = define.strip_definition_footnote_footer(text) })
lua/parley/chat_respond.lua:610:    local define = require("parley.define")
lua/parley/chat_respond.lua:616:                copy.text = define.strip_definition_footnote_footer(copy.text)
lua/parley/chat_respond.lua:629:    -- Use header-defined max_full_exchanges if available, otherwise use config value
lua/parley/chat_respond.lua:634:            logger.debug("Using header-defined max_full_exchanges: " .. tostring(max_exchanges))
lua/parley/chat_respond.lua:702:                    local question_content = define.strip_definition_footnote_footer(exchange.question.content)
lua/parley/chat_respond.lua:807:                        table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.answer.content) })
lua/parley/chat_respond.lua:812:                        table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.summary.content) })
lua/parley/chat_respond.lua:820:                            table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.answer.content) })
lua/parley/chat_respond.lua:1146:    -- place. Markers with `<T>` collapse to plain T inline; markers without
lua/parley/log_emit.lua:101:-- tool definitions lead with `name`.
lua/parley/log_emit.lua:138:-- For inline scalars: " value". For block scalars / nested structures:
lua/parley/log_emit.lua:305:--- subsection. Assistant content (incl. 🧠:/📝:/🔧:/📎: lines) is inlined
lua/parley/lualine.lua:300:        -- doesn't define it, the statusline falls back to default.
lua/parley/lualine.lua:311:        -- Format each metric - use "-" for nil/undefined values or zeros
lua/parley/skills/review/init.lua:34:--                  blocks / inline-code spans so a `}` in a code sample can't
lua/parley/skills/review/init.lua:195:-- Returns list of {start, finish} byte ranges for inline code spans on a line.
lua/parley/skills/review/init.lua:197:local function inline_code_ranges(line)
lua/parley/skills/review/init.lua:226:-- code blocks / inline-code spans are excluded so they can't open or close a
lua/parley/skills/review/init.lua:258:    -- plus inline-code spans on non-fenced lines. Sorted by start for early-out.
lua/parley/skills/review/init.lua:265:            for _, r in ipairs(inline_code_ranges(line)) do
lua/parley/skills/review/init.lua:441:-- Skill definition
lua/parley/skills/review/init.lua:751:    -- <M-o> opens the general SKILL PICKER (review is one of the skills); <M-CR>
lua/parley/review_menu.lua:86:        style = "minimal", border = "rounded", title = " Instruction — optional (M-CR/C-s submit · Tab/Esc→list) ",
lua/parley/review_menu.lua:145:    -- natively — no mapping needed. Enter/M-CR/C-s run; Tab/i go to the
lua/parley/review_menu.lua:151:    lmap("<M-CR>", submit)
lua/parley/review_menu.lua:167:    imap({ "n", "i" }, "<M-CR>", submit)
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
atlas/modes/review.md:56:| `<M-CR>`        | Open the **review-mode menu** (mode selector + instruction editor; sticky-preselected) (#133) |
atlas/modes/review.md:64:newline, `M-CR`/`C-s` submit, `Tab`/`Esc` return to the list; `Esc`/`C-c` cancel.
atlas/modes/review.md:69:attachment (`is_journal_sidecar`). `<M-CR>` is free here — chat-respond's `<M-CR>`
atlas/modes/review.md:192:review_shortcut_next   = { modes = { "n", "i" }, shortcut = "<M-CR>" }, -- review-mode menu (#133)
atlas/modes/review.md:199:- `lua/parley/skills/review/init.lua` — skill definition (+ `source(ctx)` mode composition, `mode` arg), marker parsing, `run_via_invoke` (marker pre-check + resubmit), keybindings
atlas/modes/review.md:203:- `lua/parley/review_menu.lua` — composite review-mode menu (selector + instruction editor); `<M-CR>` (#133)
atlas/modes/review.md:205:- `lua/parley/skills/review/diag_display.lua` — inline "why" display toggle (`:ParleyShowDiagnostics`, cursor-region auto-show) (#133 M6)
atlas/modes/review.md:210:- `lua/parley/tools/builtin/propose_edits.lua` — batch edit-apply (inline `.parley-backup`)
lua/parley/keybinding_registry.lua:12:-- Parent pointers define the hierarchy. Finders are standalone roots.
lua/parley/keybinding_registry.lua:481:		-- #161: <M-CR> owns its own entry so visual mode can route to define
lua/parley/keybinding_registry.lua:484:		id = "chat_define",
lua/parley/keybinding_registry.lua:485:		config_key = "chat_shortcut_define",
lua/parley/keybinding_registry.lua:486:		default_key = { "<M-CR>" },
lua/parley/keybinding_registry.lua:489:		desc = "Parley inline term definition (visual) / respond (n/i)",
lua/parley/keybinding_registry.lua:734:		default_key = "<M-CR>",
tests/unit/highlighter_spec.lua:27:    it("rejects a footnote reference", function()
lua/parley/outline.lua:304:      local branch_indent = branch.inline and (indent .. "    ") or (indent .. "  ")
lua/parley/outline.lua:307:        value = { lnum = branch.line, file = abs_path, child_path = child_abs, inline = branch.inline },
lua/parley/outline.lua:365:      local child_depth = item.value.inline and (depth + 2) or (depth + 1)
tests/integration/chat_respond_spec.lua:1470:        -- Marker stripped; quoted term remains inline, enclosed in [] so the
tests/integration/chat_respond_spec.lua:1474:            "stripped term should remain inline, bracketed; got:\n" .. joined)
tests/integration/chat_respond_spec.lua:1543:        -- Marker stripped; quoted term remains inline, enclosed in [] (#127)
tests/integration/chat_respond_spec.lua:1547:            "stripped term should remain inline, bracketed; got:\n" .. after)
lua/parley/skill_invoke.lua:133:    -- A read-only skill (opts.no_reload — e.g. define, #161) makes no edits, so
lua/parley/skill_invoke.lua:154:    -- opts.document lets a caller send a bounded context (e.g. define's enclosing
lua/parley/tools/init.lua:26:--- Register a ToolDefinition. Validates via `types.validate_definition`;
lua/parley/tools/init.lua:60:    local ok, err = types.validate_definition(def)
lua/parley/tools/init.lua:167:    "emit_definition",
lua/parley/tools/init.lua:178:--- repeated `setup()` invocations do not accumulate stale definitions.
lua/parley/exporter.lua:245:--- For markdown format, returns the final styled HTML divs (Jekyll renders inline HTML).
lua/parley/exporter.lua:302:			-- Replace inline branch links [🌿:text](file) with <a> tags
lua/parley/exporter.lua:304:			local inline_links = chat_parser.extract_inline_branch_links(line, branch_prefix)
lua/parley/exporter.lua:305:			if #inline_links > 0 then
lua/parley/exporter.lua:308:				for idx = #inline_links, 1, -1 do
lua/parley/exporter.lua:309:					local link = inline_links[idx]
lua/parley/exporter.lua:318:						placeholders[key] = '<a href="' .. target_filename .. '" class="branch-inline">' .. link.topic .. "</a>"
lua/parley/exporter.lua:322:						replacement = '<a href="{% post_url ' .. slug .. ' %}" class="branch-inline">' .. link.topic .. "</a>"
lua/parley/exporter.lua:364:	-- Convert inline code
lua/parley/exporter.lua:365:	html = html:gsub("`([^`\n]+)`", '<code class="inline-code">%1</code>')
lua/parley/exporter.lua:495:        .inline-code {
lua/parley/exporter.lua:611:        /* Inline branch links (footnote-style) */
lua/parley/exporter.lua:612:        .branch-inline {
lua/parley/exporter.lua:619:        .branch-inline:hover {
lua/parley/exporter.lua:750:.branch-inline { color: #2b6cb0; text-decoration: none; border-bottom: 1px dashed #90cdf4; font-weight: 500; }
lua/parley/exporter.lua:751:.branch-inline:hover { color: #1a365d; border-bottom-style: solid; }
atlas/infra/raw_logging.md:69:One `## Turn N — <iso ts>` per dispatch (including each tool-loop iteration). String message content is inlined verbatim; structured (Anthropic content-blocks list) is rendered as YAML.
atlas/infra/raw_logging.md:156:- **Not a general YAML emitter.** The Lua emitter handles only the shapes parley produces. Out-of-shape values fall back to inline-quoted vim.inspect strings.
tests/unit/drill_in_spec.lua:213:    it("converts 🤖<Q>[U] to a block and strips inline to Q", function()
tests/unit/drill_in_spec.lua:321:    -- ── inline: prose precedes the marker on its line ──────────────────
tests/unit/drill_in_spec.lua:322:    it("inline: grabs the preceding sentence when ≥10 words are present", function()
tests/unit/drill_in_spec.lua:330:    it("inline: a <10-word current sentence extends back across the boundary", function()
tests/unit/drill_in_spec.lua:339:    it("inline: caps at 20 words, keeping the words nearest the marker with a … prefix", function()
tests/unit/drill_in_spec.lua:349:    it("inline: strips a neighboring marker's raw bytes out of the window", function()
tests/unit/drill_in_spec.lua:373:    it("inline at reply start (prose only after the marker) degrades to empty", function()
tests/unit/drill_in_spec.lua:378:    it("bare marker mid-paragraph (no blank separation) is treated as inline", function()
tests/unit/drill_in_spec.lua:463:    it("returns the inline span's absolute byte range", function()
tests/unit/drill_in_spec.lua:493:    it("brackets an explicit <Q> inline as [Q]", function()
tests/unit/drill_in_spec.lua:500:    it("brackets an inferred inline span, absorbing the marker into the close", function()
tests/unit/drill_in_spec.lua:516:    it("default (no bracket) leaves the inline replacement bare", function()
lua/parley/buffer_edit.lua:117:--- Replace the entire chat buffer after a pure definition-footnote transform.
lua/parley/buffer_edit.lua:118:function M.replace_all_lines_for_definition(buf, lines)
atlas/context/file_references.md:12:- Chat-to-chat references now use `🌿:` branch links (see `chat/inline_branch_links.md`)
lua/parley/config.lua:449:	-- #161: <M-CR> owns its own binding so visual mode routes to inline term
lua/parley/config.lua:450:	-- definition while n/i keep respond (one entry can't split key×mode). Visual
lua/parley/config.lua:452:	chat_shortcut_define = { modes = { "n", "i", "v", "x" }, shortcut = "<M-CR>" },
lua/parley/config.lua:498:	-- of the skills); <M-CR> is the direct review trigger — it opens the review-mode
lua/parley/config.lua:499:	-- menu (sticky-preselected). (Free in markdown docs — chat-respond <M-CR> is
lua/parley/config.lua:502:	review_shortcut_next = { modes = { "n", "i" }, shortcut = "<M-CR>" },
tests/unit/tools_builtin_propose_edits_spec.lua:22:describe("propose_edits tool definition", function()
tests/unit/tools_builtin_propose_edits_spec.lua:24:        local ok, err = types.validate_definition(propose_edits)
tests/unit/tools_builtin_propose_edits_spec.lua:81:describe("propose_edits inline backup", function()
tests/unit/issues_spec.lua:101:    -- drive the async call (the fake calls back inline → stays synchronous) + capture
tests/unit/pure_functions_spec.lua:178:    it("converts inline code to <code> with inline-code class", function()
tests/unit/pure_functions_spec.lua:181:        assert.is_true(html:find('<code class="inline%-code">print%(%)') ~= nil)
tests/unit/inline_branch_spec.lua:1:-- Unit tests for inline branch links [🌿:text](file)
tests/unit/inline_branch_spec.lua:14:		tmpdir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-inline-" .. random_suffix
tests/unit/inline_branch_spec.lua:25:	describe("Group A: extract_inline_branch_links", function()
tests/unit/inline_branch_spec.lua:26:		it("A1: extracts single inline link", function()
tests/unit/inline_branch_spec.lua:27:			local result = chat_parser.extract_inline_branch_links(
tests/unit/inline_branch_spec.lua:38:		it("A2: extracts multiple inline links on one line", function()
tests/unit/inline_branch_spec.lua:39:			local result = chat_parser.extract_inline_branch_links(
tests/unit/inline_branch_spec.lua:50:		it("A3: returns empty for line with no inline links", function()
tests/unit/inline_branch_spec.lua:51:			local result = chat_parser.extract_inline_branch_links("Just a normal line", "🌿:")
tests/unit/inline_branch_spec.lua:56:			local result = chat_parser.extract_inline_branch_links("🌿: child.md: Topic", "🌿:")
tests/unit/inline_branch_spec.lua:61:			local result = chat_parser.extract_inline_branch_links("[🌿:](child.md)", "🌿:")
tests/unit/inline_branch_spec.lua:68:	describe("Group B: unpack_inline_branch_links", function()
tests/unit/inline_branch_spec.lua:69:		it("B1: replaces inline link with display text", function()
tests/unit/inline_branch_spec.lua:70:			local result = chat_parser.unpack_inline_branch_links(
tests/unit/inline_branch_spec.lua:78:			local result = chat_parser.unpack_inline_branch_links(
tests/unit/inline_branch_spec.lua:86:			local result = chat_parser.unpack_inline_branch_links("No links here", "🌿:")
tests/unit/inline_branch_spec.lua:91:	describe("Group C: parse_chat with inline links", function()
tests/unit/inline_branch_spec.lua:92:		it("C1: adds inline links to branches", function()
tests/unit/inline_branch_spec.lua:114:			assert.is_true(parsed.branches[1].inline)
tests/unit/inline_branch_spec.lua:117:		it("C2: unpacks inline links from content", function()
tests/unit/inline_branch_spec.lua:142:		it("C3: inline links coexist with full-line links", function()
tests/unit/inline_branch_spec.lua:151:				"Answer with [🌿:term](term.md) inline",
tests/unit/inline_branch_spec.lua:165:			assert.is_true(parsed.branches[1].inline)
tests/unit/inline_branch_spec.lua:166:			assert.is_nil(parsed.branches[2].inline)
tests/unit/inline_branch_spec.lua:169:		it("C4: inline links in answer are unpacked in content", function()
tests/unit/inline_branch_spec.lua:195:	describe("Group D: export inline links", function()
tests/unit/inline_branch_spec.lua:204:		it("D1: HTML export replaces inline links with <a> tags", function()
tests/unit/inline_branch_spec.lua:216:			local parsed = { parent_link = nil, branches = { { path = "child.md", topic = "shader", inline = true } } }
tests/unit/inline_branch_spec.lua:223:			-- The line should contain a placeholder for the inline link
tests/unit/inline_branch_spec.lua:226:			-- The placeholder should resolve to an <a> with branch-inline class
tests/unit/inline_branch_spec.lua:229:					assert.is_truthy(html:find("branch%-inline"))
tests/unit/inline_branch_spec.lua:236:		it("D2: markdown export replaces inline links with <a> tags", function()
tests/unit/inline_branch_spec.lua:248:			local parsed = { parent_link = nil, branches = { { path = "child.md", topic = "shader", inline = true } } }
tests/unit/inline_branch_spec.lua:256:			assert.is_truthy(line:find("branch%-inline"))
tests/unit/inline_branch_spec.lua:261:		it("D3: inline link with missing target falls back to plain text", function()
tests/unit/parse_chat_spec.lua:553:    it("collects inline @@ref@@ with local path", function()
tests/unit/parse_chat_spec.lua:555:            "💬: See @@/inline/path.lua@@ here",
tests/unit/parse_chat_spec.lua:560:        assert.equals("/inline/path.lua", refs[1].path)
tests/unit/parse_chat_spec.lua:584:    it("collects inline @@url@@ on the same line as user prefix", function()
tests/unit/parse_chat_spec.lua:594:    it("collects inline @@url@@ on a continuation line", function()
tests/unit/parse_chat_spec.lua:605:    it("collects inline @@ref@@ with local path on continuation line", function()
tests/unit/parse_chat_spec.lua:608:            "see @@/inline/path.lua@@ for context",
tests/unit/parse_chat_spec.lua:613:        assert.equals("/inline/path.lua", refs[1].path)
tests/unit/parse_chat_spec.lua:616:    it("collects inline @@ref@@ with relative path", function()
tests/unit/parse_chat_spec.lua:626:    it("collects inline @@ref@@ with parent-relative path", function()
tests/unit/parse_chat_spec.lua:636:    it("collects inline @@ref@@ with home-relative path", function()
tests/unit/parse_chat_spec.lua:655:    it("collects two inline @@ref@@ on same line", function()
tests/unit/log_emit_spec.lua:157:    it("renders one ### section per message with string content inlined", function()
tests/unit/build_messages_spec.lua:707:describe("_build_messages: durable definition footnotes", function()
tests/unit/build_messages_spec.lua:708:    it("strips managed definition footnote footers from user and assistant content", function()
tests/unit/build_messages_spec.lua:710:            "What is ASIN?",
tests/unit/build_messages_spec.lua:717:            "ASIN is an identifier.",
tests/unit/build_messages_spec.lua:739:        assert.equals("What is ASIN?", messages[2].content)
tests/unit/build_messages_spec.lua:740:        assert.equals("ASIN is an identifier.", messages[3].content)
tests/unit/build_messages_spec.lua:751:            "second half, not a footnote",
tests/unit/build_messages_spec.lua:1605:describe("build_messages_from_model: durable definition footnotes", function()
tests/unit/build_messages_spec.lua:1608:    it("strips managed footnote footers from live question and answer blocks", function()
tests/unit/build_messages_spec.lua:1610:            "💬: What is ASIN?",
tests/unit/build_messages_spec.lua:1617:            "ASIN is an identifier.",
tests/unit/build_messages_spec.lua:1647:        assert.equals("What is ASIN?", msgs[2].content)
tests/unit/build_messages_spec.lua:1649:        assert.equals("ASIN is an identifier.", msgs[3].content[1].text)
tests/unit/tools_registry_spec.lua:6:--   get(name)        — lookup by name, returns the definition or nil
tests/unit/tools_registry_spec.lua:8:--   select(names)    — returns a list of definitions matching the given
tests/unit/tools_registry_spec.lua:45:        it("accepts and stores a valid definition", function()
tests/unit/tools_registry_spec.lua:51:        it("raises on invalid definition (missing name)", function()
tests/unit/tools_registry_spec.lua:57:        it("raises on invalid definition (empty name)", function()
tests/unit/tools_registry_spec.lua:89:        it("returns the definition for a registered name", function()
tests/unit/tools_registry_spec.lua:112:        it("returns matching definitions in the order given", function()
tests/unit/vision_spec.lua:59:    it("parses inline list with multiple items", function()
tests/unit/vision_spec.lua:95:  # inline comment
tests/unit/tools_builtin_registered_spec.lua:14:--   2. Each builtin is a valid ToolDefinition per types.validate_definition.
tests/unit/tools_builtin_registered_spec.lua:50:    it("each builtin passes types.validate_definition", function()
tests/unit/tools_builtin_registered_spec.lua:55:            local ok, err = types.validate_definition(def)
tests/unit/anthropic_tool_encode_spec.lua:55:    it("converts multiple definitions preserving input order", function()
lua/parley/artifact_ref.lua:115:    -- Match issues.lua's shell resolution so an rc-defined `sdlc` function loads
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
tests/unit/define_spec.lua:70:        assert.equals("ASIN — Amazon Standard Identification Number.", msg)
tests/unit/define_spec.lua:74:        local msg = define.format_definition("X", string.rep("word ", 30), 40)
tests/unit/define_spec.lua:80:    it("trims a nil/blank definition to a safe string", function()
tests/unit/define_spec.lua:81:        assert.equals("X — (no definition)", define.format_definition("X", nil, 80))
tests/unit/define_spec.lua:85:describe("define.bracket_edit", function()
tests/unit/define_spec.lua:87:        -- "here is ASIN in context": ASIN at 0-based cols 8..11 inclusive
tests/unit/define_spec.lua:88:        local e = define.bracket_edit({ "here is ASIN in context" }, 1, 8, 1, 11)
tests/unit/define_spec.lua:91:        assert.are.same({ "here is [ASIN] in context" }, e.lines)
tests/unit/define_spec.lua:95:        local e = define.bracket_edit({ "the lazy dog" }, 1, 9, 1, 999)
tests/unit/define_spec.lua:100:        local e = define.bracket_edit({ "brown fox", "jumps over", "the dog" }, 1, 6, 3, 2)
tests/unit/define_spec.lua:107:describe("define.diagnostic_span_after_bracket", function()
tests/unit/define_spec.lua:109:        local span = define.diagnostic_span_after_bracket(3, 9, 3, 12)
tests/unit/define_spec.lua:119:        local span = define.diagnostic_span_after_bracket(1, 7, 3, 3)
tests/unit/define_spec.lua:129:describe("define durable footnotes", function()
tests/unit/define_spec.lua:130:    it("slugifies a definition term into a markdown footnote id", function()
tests/unit/define_spec.lua:132:            define.footnote_id("Amazon Standard Identification Number"))
tests/unit/define_spec.lua:133:        assert.equals("asin", define.footnote_id("ASIN"))
tests/unit/define_spec.lua:136:    it("adds an inline footnote reference and appends a managed footer", function()
tests/unit/define_spec.lua:137:        local result = define.apply_definition_footnote(
tests/unit/define_spec.lua:138:            { "here is ASIN in context" },
tests/unit/define_spec.lua:140:            "ASIN",
tests/unit/define_spec.lua:145:            "here is ASIN[^asin] in context",
tests/unit/define_spec.lua:153:        assert.equals("Amazon Standard Identification Number.", result.definition)
tests/unit/define_spec.lua:156:    it("updates an existing managed footnote instead of duplicating it", function()
tests/unit/define_spec.lua:157:        local result = define.apply_definition_footnote(
tests/unit/define_spec.lua:159:                "ASIN is here",
tests/unit/define_spec.lua:163:                "[^asin]: old definition",
tests/unit/define_spec.lua:166:            "ASIN",
tests/unit/define_spec.lua:171:            "ASIN[^asin] is here",
tests/unit/define_spec.lua:179:    it("strips only a final managed footnote footer", function()
tests/unit/define_spec.lua:188:        assert.equals("answer text", define.strip_definition_footnote_footer(text))
tests/unit/define_spec.lua:191:    it("preserves ordinary horizontal rules that are not managed footnote footers", function()
tests/unit/define_spec.lua:197:            "not a footnote",
tests/unit/define_spec.lua:200:        assert.equals(text, define.strip_definition_footnote_footer(text))
tests/unit/define_spec.lua:222:        }, "\n"), define.strip_definition_footnote_footer(text))
tests/unit/chat_parser_tools_spec.lua:24:-- defaults but inlined so this test doesn't depend on parley.setup().
tests/unit/config_tools_spec.lua:332:    it("defines chat_tool_use_prefix and chat_tool_result_prefix", function()
tests/unit/config_tools_spec.lua:338:    it("defines chat_shortcut_toggle_tool_folds", function()
tests/unit/review_spec.lua:115:    it("skips markers inside inline code spans", function()
tests/unit/review_spec.lua:120:    it("skips markers inside double-backtick inline code", function()
tests/unit/review_spec.lua:125:    it("parses markers outside inline code on same line", function()
tests/unit/review_spec.lua:353:    it("a } inside an inline-code span does not close a prose marker", function()

exec
/bin/zsh -lc "nl -ba atlas/chat/inline_define.md | sed -n '1,130p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
     1	# Inline Term Definition
     2	
     3	Select a phrase in a chat transcript, press **`<M-CR>`** (visual mode), and a
     4	concise, context-aware definition appears as an **ephemeral inline diagnostic**
     5	(grey `virtual_lines`) under the phrase. The selected text stays in place and
     6	gets a markdown footnote reference (`ASIN[^asin]`), while the definition is
     7	stored in a managed footnote footer at the end of the chat transcript. The
     8	whole annotation is **undoable** — `u` reverts the footnote edit and clears both
     9	decorations (see Undo below). For jargon you don't know (e.g. `ASIN`), it's a
    10	one-keystroke lookup. Added in
    11	[#161](../../workshop/issues/000161-inline-term-definition.md) (R1 added the
    12	highlight/undo); [#166](../../workshop/issues/000166-visual-selection-definition-system-manages-footnote.md)
    13	made the definition durable as a managed footnote.
    14	
    15	## Flow
    16	
    17	1. **`define_visual(buf)`** (`lua/parley/init.lua`) reads the visual selection
    18	   (`getpos`), extracts the phrase (`define.slice_selection`), guards
    19	   empty/whitespace, and computes a **bounded context** = the *enclosing
    20	   exchange* of the selection (`define.context_for_selection` over `parse_chat`
    21	   + `find_exchange_at_line`), falling back to the whole buffer.
    22	2. It fires a headless **`define` skill** turn via `skill_invoke.invoke` with
    23	   `opts.document = context`, `opts.no_reload = true`, and an `on_done`.
    24	3. The `define` skill (`lua/parley/skills/define/init.lua`) is **unforced** (no
    25	   `force_tool`) so the server-side `web_search` tool can run when the global
    26	   `:ToggleWebSearch` is on; its `source(ctx)` folds the phrase into the system
    27	   prompt and asks the model to call `emit_definition({term, definition})`.
    28	4. **`render_definition`** (`on_done`), on a successful lookup: re-verifies the
    29	   selection still holds the phrase (else skips — the buffer changed under the
    30	   in-flight call), then **(a)** adds a `[^id]` reference after the selected term
    31	   and inserts/updates a final managed footnote footer via one buffer rewrite
    32	   (`define.apply_definition_footnote`) — a single undo entry that anchors
    33	   everything; **(b)** highlights the line(s) whole-line `DiffChange`
    34	   (`skill_render.highlight_line`); **(c)** sets one INFO `vim.diagnostic` on
    35	   the selected term/reference span (`define.format_definition` →
    36	   `skill_render.wrap`) on the `parley_skill` namespace; **(d)** records the
    37	   undo/redo projection states.
    38	   `diag_display`'s `virtual_lines{current_line=true}` reveals the diagnostic
    39	   (cursor parked on the term's line). A no-`emit_definition` response leaves no
    40	   footnote reference/footer.
    41	
    42	## Undo (`u`) — reuses review's projection
    43	
    44	Native `u` reverts *text*, not decorations. The footnote reference/footer rewrite
    45	is the one text change, so `u` reverts it; the decorations are cleared/restored by review's
    46	**projection watcher** (`skills/review/projection.lua`, #133 M5), which define
    47	reuses: `render_definition` calls `projection.record_empty_for(buf, original)`
    48	(pre-footnote hash → empty snapshot), `record(buf)` (footnoted hash → the
    49	highlight + diagnostic), `ensure_watch(buf)`. Undoing the footnote edit lands on
    50	the pre-footnote content-hash → the empty snapshot renders → both decorations clear;
    51	`<C-r>` re-renders. The highlight must be **whole-line** because
    52	`skill_render.snapshot`/`apply_snapshot` are line-granular. `set_applying`
    53	guards the edit so a prior define's watcher doesn't mistake it for a user edit.
    54	
    55	## Pure core vs IO shell (ARCH-PURE)
    56	
    57	- **Pure** (`lua/parley/define.lua`, unit-tested with plain tables): `slice_selection`,
    58	  `context_for_selection`, `format_definition`, `bracket_edit` (plans the `[term]`
    59	  wrap as a legacy set_lines edit), `diagnostic_span_after_bracket` (legacy range
    60	  mapping), `apply_definition_footnote` (durable footer transform), and
    61	  `strip_definition_footnote_footer` (removes only a final `---` block followed
    62	  solely by footnotes).
    63	- **IO shell** (`lua/parley/init.lua`): `define_visual`, `render_definition`;
    64	  `lua/parley/buffer_edit.lua` owns the full-buffer footnote rewrite.
    65	- **External service** (Anthropic) exercised via the process-level fake reused
    66	  from `skill_invoke_spec` (SSE tool-call injection).
    67	
    68	## Managed Footnote Footer
    69	
    70	The footer is a final markdown block:
    71	
    72	```markdown
    73	---
    74	
    75	[^asin]: Amazon Standard Identification Number.
    76	```
    77	
    78	The footer detector is deliberately conservative: only the last standalone
    79	`---` line followed by blank lines and footnote definitions counts as the
    80	managed footer. Ordinary horizontal rules and mixed prose after `---` remain
    81	chat content. `chat_respond.build_messages` strips this managed footer from
    82	message strings before LLM submission, so durable definitions do not become
    83	prompt context.
    84	
    85	## Keybinding
    86	
    87	`<M-CR>` was split out of `chat_shortcut_respond` into its own `chat_define`
    88	registry entry (a single registry entry maps every key×mode to one per-mode
    89	callback, so the split can't live inside `chat_respond`). The `chat_define`
    90	per-mode callback is `{ n=respond, i=respond, v=define_visual, x=define_visual }`
    91	— visual `<M-CR>` defines; normal/insert `<M-CR>` still responds; visual
    92	`<C-g><C-g>` keeps the line-scoped resubmit. The v/x callbacks `<Esc>`-commit
    93	the `'<`/`'>` marks before reading `getpos`.
    94	
    95	## Read-only invoke seam (`opts.no_reload`)
    96	
    97	`skill_invoke.invoke` normally writes the buffer before the turn and `:edit!`-
    98	reloads it after (for `propose_edits`). A read-only lookup passes
    99	`opts.no_reload = true` to skip both, so an in-progress prompt is never
   100	persisted. `opts.document` lets the caller send a bounded context instead of the
   101	whole buffer. Both default to prior behavior when absent.
   102	
   103	## Structured output tool
   104	
   105	`emit_definition` (`lua/parley/tools/builtin/emit_definition.lua`, in
   106	`BUILTIN_NAMES`) is an **output-only** tool: `{term, definition}` schema,
   107	`self_paginates = true` (no pager params), no-op `handler`. The value rides the
   108	tool-call args (`result.calls[1].input`), read in `on_done`.
   109	
   110	## v1 limitations
   111	
   112	- One diagnostic visible at a time (`invoke` resets the `parley_skill` namespace
   113	  each turn); line-granular highlight (whole-line, required for the projection
   114	  round-trip). Dismissal is via `u` — reverting the footnote reference/footer
   115	  clears it; the diagnostic also auto-hides when the cursor leaves the line.
   116	  The footnote persists in the file if saved. Shared `parley_skill`
   117	  namespace/projection with review still applies (rare on chat buffers).
   118	
   119	## Key files
   120	
   121	- `lua/parley/define.lua` — pure core (slice / context / format / footnote footer).
   122	- `lua/parley/init.lua` — `define_visual`, `render_definition`, `chat_define` wiring.
   123	- `lua/parley/chat_respond.lua` — strips managed footnote footer from LLM messages.
   124	- `lua/parley/skills/define/init.lua` — the unforced `define` skill.
   125	- `lua/parley/tools/builtin/emit_definition.lua` — output-only structured tool.
   126	- `lua/parley/skill_invoke.lua` — `opts.no_reload` / `opts.document` seams.
   127	- `lua/parley/config.lua`, `lua/parley/keybinding_registry.lua` — the `<M-CR>` split.
   128	- `tests/unit/define_spec.lua`, `tests/integration/define_spec.lua` — coverage.
   129	
   130	## Related

exec
/bin/zsh -lc 'git diff 7f591d9dad8444b180a84a82ad02a9c239cfc6e2..HEAD -- README.md' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
codex
The docs gate found a separate user-facing gap: `README.md` still says the visual definition writes nothing to the transcript, while this issue intentionally makes it durable. I have enough for the verdict now.
exec
/bin/zsh -lc "nl -ba workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md | sed -n '14,58p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
    14	
    15	### Pure Entities
    16	
    17	| Name | Lives in | Status |
    18	|------|----------|--------|
    19	| `DefinitionFootnote` | `lua/parley/define.lua` | new |
    20	| `DefinitionFootnoteFooter` | `lua/parley/define.lua` | new |
    21	| `DefinitionSubmissionScrubber` | `lua/parley/define.lua` | new |
    22	
    23	- **DefinitionFootnote** — a durable markdown footnote pair: inline reference `[^definition]` plus footer line `[^definition]: ...`.
    24	  - **Relationships:** N:1 with a chat file; many selected terms may create footnotes in one managed footer.
    25	  - **DRY rationale:** One source handles slugging, reference text, and footer line formatting instead of duplicating string construction in render and tests.
    26	  - **Future extensions:** Conflict handling can widen from numeric suffixes to stable IDs or renames without changing render callers.
    27	
    28	- **DefinitionFootnoteFooter** — pure transform that inserts or updates a managed footnote section after the transcript separator.
    29	  - **Relationships:** Owns the footer section lines; consumed by `buffer_edit.replace_all_lines`.
    30	  - **DRY rationale:** Keeps footer location, divider insertion, replacement policy, and footer-boundary recognition together.
    31	  - **Future extensions:** Can support multiple footer groups or metadata comments if the managed section needs migration.
    32	
    33	- **DefinitionSubmissionScrubber** — pure helper that removes the managed footnote footer from strings before they are sent to the LLM.
    34	  - **Relationships:** Consumed by `chat_respond.build_messages`; separate from parser so parse positions remain truthful to the buffer.
    35	  - **DRY rationale:** The same footer boundary rule protects user and assistant content.
    36	  - **Future extensions:** If other local-only transcript sections appear, this helper can become a generic local-footer scrubber.
    37	
    38	### Integration Points
    39	
    40	| Name | Lives in | Status | Wraps |
    41	|------|----------|--------|-------|
    42	| `render_definition` | `lua/parley/init.lua` | modified | Neovim diagnostics/projection |
    43	| `DefinitionBufferEdit` | `lua/parley/buffer_edit.lua` | modified | `nvim_buf_set_lines` |
    44	| `chat_respond.build_messages` | `lua/parley/chat_respond.lua` | modified | LLM payload construction |
    45	
    46	- **render_definition** — after `emit_definition`, verifies the selection, rewrites the selected text to include a footnote reference, stores/updates the managed footer, and attaches the current-line diagnostic from the durable footnote text.
    47	  - **Injected into:** Existing `skill_invoke.invoke` `on_done` callback.
    48	  - **Future extensions:** On-cursor rehydration can later read existing footnotes without a new LLM call.
    49	
    50	- **DefinitionBufferEdit** — chat-buffer mutation entry point for full-buffer definition-footnote rewrites.
    51	  - **Injected into:** `render_definition`.
    52	  - **Future extensions:** Can narrow to range edits if the footer transform later returns minimal edit hunks.
    53	
    54	- **chat_respond.build_messages** — strips managed definition footnotes from preserved and summarized exchange content.
    55	  - **Injected into:** Existing chat response pipeline.
    56	  - **Future extensions:** Live-model recursion path can consume the same scrubber if footnotes ever appear during tool-loop recursion.
    57	
    58	---

exec
/bin/zsh -lc "nl -ba README.md | sed -n '110,122p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   110	
   111	**Global**
   112	- `<C-g>c` new chat - global hotkey
   113	- `<C-g>f` find chat - global hotkey
   114	
   115	**In Chat Buffer**
   116	- `<C-g>?` show key bindings
   117	- `<C-g><C-g>` respond
   118	- `<M-CR>` respond (normal/insert); **visual-select a phrase + `<M-CR>`** → inline term definition — a concise grey pop-under at the phrase (nothing written to the transcript), honoring `:ToggleWebSearch` for unfamiliar terms
   119	- `<C-g>G` respond all
   120	- `<C-g>x` stop
   121	- `<C-g>t` chat outline
   122	- `<C-g>a` change agent

exec
/bin/zsh -lc "nl -ba lua/parley/define.lua | sed -n '240,305p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   240	local function replace_or_append_footnote(lines, id, definition)
   241	    local out = copy_lines(lines)
   242	    local footer = managed_footer_start(out)
   243	    local footnote_line = M.format_footnote_line(id, definition)
   244	    if footer then
   245	        for i = footer + 1, #out do
   246	            local escaped_id = id:gsub("([^%w])", "%%%1")
   247	            if trim(out[i]):match("^%[%^" .. escaped_id .. "%]:") then
   248	                out[i] = footnote_line
   249	                return out
   250	            end
   251	        end
   252	        out[#out + 1] = footnote_line
   253	        return out
   254	    end
   255	
   256	    while #out > 0 and trim(out[#out]) == "" do
   257	        table.remove(out)
   258	    end
   259	    out[#out + 1] = ""
   260	    out[#out + 1] = "---"
   261	    out[#out + 1] = ""
   262	    out[#out + 1] = footnote_line
   263	    return out
   264	end
   265	
   266	--- Insert a markdown footnote reference after the selected text and store the
   267	--- definition in a managed footer.
   268	--- @param lines string[]
   269	--- @param l1 integer
   270	--- @param c1 integer 0-based byte column
   271	--- @param l2 integer
   272	--- @param c2 integer 0-based inclusive byte column
   273	--- @param term string
   274	--- @param definition string|nil
   275	--- @return table { lines: string[], id: string, definition: string, diagnostic_span: table }
   276	function M.apply_definition_footnote(lines, l1, c1, l2, c2, term, definition)
   277	    local id = M.footnote_id(term)
   278	    local ref = "[^" .. id .. "]"
   279	    local out = copy_lines(lines)
   280	    if l1 == l2 then
   281	        local line = out[l1] or ""
   282	        local ec = math.min(c2 + 1, #line)
   283	        out[l1] = line:sub(1, ec) .. ref .. line:sub(ec + 1)
   284	    else
   285	        local line = out[l2] or ""
   286	        local ec = math.min(c2 + 1, #line)
   287	        out[l2] = line:sub(1, ec) .. ref .. line:sub(ec + 1)
   288	    end
   289	    out = replace_or_append_footnote(out, id, definition)
   290	    local normalized_definition = trim(definition)
   291	    if normalized_definition == "" then
   292	        normalized_definition = "(no definition)"
   293	    end
   294	    return {
   295	        lines = out,
   296	        id = id,
   297	        definition = normalized_definition,
   298	        diagnostic_span = {
   299	            lnum = l1 - 1,
   300	            col = c1,
   301	            end_lnum = l2 - 1,
   302	            end_col = c2 + 1 + #ref,
   303	        },
   304	    }
   305	end

exec
/bin/zsh -lc "nl -ba workshop/issues/000166-visual-selection-definition-system-manages-footnote.md | sed -n '33,49p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
    33	Visual-selecting a term and invoking definition keeps the existing LLM lookup
    34	and diagnostic behavior, but the durable text edit changes:
    35	
    36	- The selected text remains readable in place and gains a markdown footnote
    37	  reference: `term[^term]`.
    38	- The definition is stored in a managed footnote footer at the end of the chat
    39	  transcript, separated from the main chat by `---`.
    40	- The managed footer is recognized only as a final block: the last standalone
    41	  `---` line in the content, followed only by blank lines and markdown footnote
    42	  definitions (`[^id]: text`). Any ordinary horizontal rule, or any trailing
    43	  block that mixes non-footnote prose after `---`, stays part of chat content.
    44	- Re-defining an existing term updates the corresponding managed footnote line
    45	  instead of duplicating it.
    46	- The diagnostic text is still shown inline, but it is derived from the stored
    47	  footnote definition rather than being the only copy of the definition.
    48	- The managed footnote footer is stripped from message content before payload
    49	  construction so it is not submitted to the LLM.

codex
```verdict
verdict: REWORK
confidence: high
```

The implementation covers the main happy path well: durable footnotes are pure-transformed, rendered through the buffer edit boundary, and scrubbed from both parsed and live message construction. The close boundary should not pass yet because re-defining an already-footnoted term can duplicate the inline reference, which drifts from the issue contract, and README still documents the old “nothing written” behavior.

1. Strengths:
- [lua/parley/define.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/define.lua:221) keeps footer stripping pure and shares it across message construction, satisfying ARCH-DRY.
- [lua/parley/init.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/init.lua:1640) leaves Neovim IO in `render_definition` while the document transform lives in `define.lua`, satisfying ARCH-PURE.
- [tests/unit/build_messages_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/unit/build_messages_spec.lua:707) covers user/assistant stripping and ordinary `---` preservation.
- [tests/unit/build_messages_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/unit/build_messages_spec.lua:1605) adds live `build_messages_from_model` coverage, avoiding the #155 seam gap.

2. Critical findings:
- [lua/parley/define.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/define.lua:276): `apply_definition_footnote` always inserts `[^id]` after the selected span. If the line is already `ASIN[^asin] is here` and the user re-defines `ASIN`, it produces `ASIN[^asin][^asin] is here`. That violates the spec’s redefinition behavior in [workshop/issues/000166-visual-selection-definition-system-manages-footnote.md](/Users/xianxu/workspace/parley.nvim/workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:44) and under-delivers ARCH-PURPOSE. Fix sketch: detect an existing immediate `ref` after the selected span and skip reinserting it while still updating the footer; adjust `diagnostic_span.end_col` accordingly; add pure and integration regression tests for this exact flow.

3. Important findings:
- [README.md](/Users/xianxu/workspace/parley.nvim/README.md:118): README still says visual `<M-CR>` inline definitions write “nothing” to the transcript. This issue changes user-facing behavior to durable `term[^id]` plus managed footer, so the README docs gate is missing an update for that surface.

4. Minor findings:
- [workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md](/Users/xianxu/workspace/parley.nvim/workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:17): Core concept tables omit an explicit `Kind` column, though the headings separate pure and integration entities.

5. Test coverage notes:
- I ran `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`: 21 passed, 0 failed.
- I ran `git diff --check -- ...`: passed.
- Missing coverage: redefinition when the inline reference already exists.

6. Architectural notes for upcoming work:
- ARCH-DRY: pass; footer boundary logic is centralized in `define.lua`.
- ARCH-PURE: pass; transform logic is pure and buffer writes stay in the IO shell.
- ARCH-PURPOSE: flagged; the duplicate inline reference means the redefinition purpose is not fully enforced.

7. Plan revision recommendations:
- Add a `## Revisions` entry noting the redefinition edge: existing `term[^id]` should update the footer without adding another inline reference.
- Add explicit `Kind` columns to the Core Concepts tables, or note that the Pure/Integration headings are intentionally standing in for the kind field.
tokens used
75,741
```verdict
verdict: REWORK
confidence: high
```

The implementation covers the main happy path well: durable footnotes are pure-transformed, rendered through the buffer edit boundary, and scrubbed from both parsed and live message construction. The close boundary should not pass yet because re-defining an already-footnoted term can duplicate the inline reference, which drifts from the issue contract, and README still documents the old “nothing written” behavior.

1. Strengths:
- [lua/parley/define.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/define.lua:221) keeps footer stripping pure and shares it across message construction, satisfying ARCH-DRY.
- [lua/parley/init.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/init.lua:1640) leaves Neovim IO in `render_definition` while the document transform lives in `define.lua`, satisfying ARCH-PURE.
- [tests/unit/build_messages_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/unit/build_messages_spec.lua:707) covers user/assistant stripping and ordinary `---` preservation.
- [tests/unit/build_messages_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/unit/build_messages_spec.lua:1605) adds live `build_messages_from_model` coverage, avoiding the #155 seam gap.

2. Critical findings:
- [lua/parley/define.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/define.lua:276): `apply_definition_footnote` always inserts `[^id]` after the selected span. If the line is already `ASIN[^asin] is here` and the user re-defines `ASIN`, it produces `ASIN[^asin][^asin] is here`. That violates the spec’s redefinition behavior in [workshop/issues/000166-visual-selection-definition-system-manages-footnote.md](/Users/xianxu/workspace/parley.nvim/workshop/issues/000166-visual-selection-definition-system-manages-footnote.md:44) and under-delivers ARCH-PURPOSE. Fix sketch: detect an existing immediate `ref` after the selected span and skip reinserting it while still updating the footer; adjust `diagnostic_span.end_col` accordingly; add pure and integration regression tests for this exact flow.

3. Important findings:
- [README.md](/Users/xianxu/workspace/parley.nvim/README.md:118): README still says visual `<M-CR>` inline definitions write “nothing” to the transcript. This issue changes user-facing behavior to durable `term[^id]` plus managed footer, so the README docs gate is missing an update for that surface.

4. Minor findings:
- [workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md](/Users/xianxu/workspace/parley.nvim/workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md:17): Core concept tables omit an explicit `Kind` column, though the headings separate pure and integration entities.

5. Test coverage notes:
- I ran `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`: 21 passed, 0 failed.
- I ran `git diff --check -- ...`: passed.
- Missing coverage: redefinition when the inline reference already exists.

6. Architectural notes for upcoming work:
- ARCH-DRY: pass; footer boundary logic is centralized in `define.lua`.
- ARCH-PURE: pass; transform logic is pure and buffer writes stay in the IO shell.
- ARCH-PURPOSE: flagged; the duplicate inline reference means the redefinition purpose is not fully enforced.

7. Plan revision recommendations:
- Add a `## Revisions` entry noting the redefinition edge: existing `term[^id]` should update the footer without adding another inline reference.
- Add explicit `Kind` columns to the Core Concepts tables, or note that the Pure/Integration headings are intentionally standing in for the kind field.
