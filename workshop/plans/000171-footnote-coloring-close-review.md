# Boundary Review — parley.nvim#171 (whole-issue close)

| field | value |
|-------|-------|
| issue | 171 — footnote coloring |
| repo | parley.nvim |
| issue file | workshop/issues/000171-footnote-coloring.md |
| boundary | whole-issue close |
| milestone | — |
| window | 4005929621a91a6e1a9a02bd048a859bb59ffb77..HEAD |
| command | sdlc close --issue 171 |
| reviewer | codex |
| timestamp | 2026-07-08T17:22:35-07:00 |
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
session id: 019f443f-7828-7af1-8163-3e5bdc1b21fd
--------
user
# Code review — the one SDLC boundary review

You are conducting a fresh-context code review at a development boundary —
whole-issue close — in the **parley.nvim** repository.

- repository: parley.nvim   (root: /Users/xianxu/workspace/parley.nvim)
- issue:      parley.nvim#171   (file: workshop/issues/000171-footnote-coloring.md)
- window:     Base: 4005929621a91a6e1a9a02bd048a859bb59ffb77   Head: HEAD

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
diff --git a/atlas/ui/highlights.md b/atlas/ui/highlights.md
index 32ad147..27290df 100644
--- a/atlas/ui/highlights.md
+++ b/atlas/ui/highlights.md
@@ -1,11 +1,14 @@
 # Spec: Syntax Highlighting

 ## Highlight Groups
-Custom groups (`ParleyQuestion`, `ParleyFileReference`, `ParleyChatReference`, `ParleyThinking`, `ParleyAnnotation`, `ParleyReference`, `ParleyPickerApproximateMatch`, `InterviewTimestamp`, `InterviewThought`) linked to standard Neovim groups. `ParleyReference` (default underline) marks drill-in `[referenced span]` brackets — see [chat/drill_in](../chat/drill_in.md).
+Custom groups (`ParleyQuestion`, `ParleyFileReference`, `ParleyChatReference`, `ParleyThinking`, `ParleyAnnotation`, `ParleyReference`, `ParleyFootnote`, `ParleyPickerApproximateMatch`, `InterviewTimestamp`, `InterviewThought`) linked to standard Neovim groups. `ParleyReference` (default underline) marks drill-in `[referenced span]` brackets — see [chat/drill_in](../chat/drill_in.md). `ParleyFootnote` (default `DiagnosticHint`) marks managed definition-footnote footer lines.

 ## Key Behaviors
 - Applied via decoration providers with ephemeral extmarks per window viewport
 - Multi-window safe: independent redraw cache per window
+- Managed definition-footnote footers (`---` + `[^id]: ...`) use
+  `ParleyFootnote` in chat and markdown buffers instead of inheriting the active
+  chat exchange color.
 - `🌿:` lines auto-rendered with debounced topic lookup from referenced files
 - `chat_conceal_model_params`: optional header param concealment
 - UTC timestamps shaped like `YYYY-MM-DDTHH:MM:SSZ` get local-time INFO
diff --git a/lua/parley/define.lua b/lua/parley/define.lua
index e0e42e9..44817c1 100644
--- a/lua/parley/define.lua
+++ b/lua/parley/define.lua
@@ -189,6 +189,18 @@ local function managed_footer_start(lines)
     return nil
 end

+--- Locate the final managed definition-footnote footer.
+--- @param lines string[]|nil
+--- @return table|nil { start_line: integer, end_line: integer } 1-based inclusive
+function M.managed_footnote_footer_range(lines)
+    lines = lines or {}
+    local start = managed_footer_start(lines)
+    if not start then
+        return nil
+    end
+    return { start_line = start, end_line = #lines }
+end
+
 local function parse_footnote_line(line)
     local id, definition = trim(line):match("^%[%^([^%]]+)%]:%s*(.-)%s*$")
     if not id then
diff --git a/lua/parley/highlighter.lua b/lua/parley/highlighter.lua
index 50967cb..bb29507 100644
--- a/lua/parley/highlighter.lua
+++ b/lua/parley/highlighter.lua
@@ -266,6 +266,8 @@ local function compute_chat_highlights(buf, start_line, end_line)
     local result = {}
     local patterns = get_chat_highlight_prefix_patterns()
     local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)
+    local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
+    local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
     -- While a stream is in flight for this buffer, the model has not
     -- yet emitted 🧠:[END]. Assume explicit-end mode so blank-line
     -- paragraph breaks inside the in-progress thinking region keep
@@ -296,106 +298,112 @@ local function compute_chat_highlights(buf, start_line, end_line)

         push_artifact_refs(result, row, line) -- #160: navigable artifact refs

-        local pos = 1
-        while true do
-            local tag_start, content_start = line:find("@@", pos)
-            if not tag_start then break end
-            local content_end, tag_end = line:find("@@", content_start + 1)
-            if not content_end then break end
-            table.insert(highlighted_regions, { start = tag_start, finish = tag_end })
-            table.insert(result[row], { hl_group = "ParleyTag", col_start = tag_start - 1, col_end = tag_end })
-            pos = tag_end + 1
-        end
-
-        -- Any structural marker terminates an in-progress reasoning
-        -- block. This mirrors chat_parser's lenient termination so the
-        -- highlight tracks parse boundaries even when the model omits
-        -- the canonical blank-line terminator (or in pre-existing
-        -- chats authored under the old single-line 🧠: convention).
-        local is_user = line:match(patterns.user_pattern)
-        local is_assistant = line:match(patterns.assistant_pattern)
-        local is_branch = line:match(patterns.branch_pattern)
-        local is_local = line:match(patterns.local_pattern)
-        local is_summary = line:match(patterns.summary_pattern)
-        local is_tool_use = line:match("^🔧:")
-        local is_tool_result = line:match("^📎:")
-        if is_user or is_assistant or is_branch or is_local
-            or is_summary or is_tool_use or is_tool_result then
-            in_reasoning_block = false
-        end
+        local is_footer = footer_range and line_nr >= footer_range.start_line and line_nr <= footer_range.end_line
+        if is_footer then
+            table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
+            in_block = false
+        else
+            local pos = 1
+            while true do
+                local tag_start, content_start = line:find("@@", pos)
+                if not tag_start then break end
+                local content_end, tag_end = line:find("@@", content_start + 1)
+                if not content_end then break end
+                table.insert(highlighted_regions, { start = tag_start, finish = tag_end })
+                table.insert(result[row], { hl_group = "ParleyTag", col_start = tag_start - 1, col_end = tag_end })
+                pos = tag_end + 1
+            end

-        if line:match(patterns.reasoning_end_pattern) then
-            -- 🧠:[END] explicit terminator. Highlight the marker line
-            -- itself as ParleyThinking (it's the closing delimiter of
-            -- the thinking region), then close the block. Must be
-            -- checked before reasoning_pattern since the END marker
-            -- also starts with the reasoning prefix.
-            table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
-            in_reasoning_block = false
-        elseif line:match(patterns.reasoning_pattern) then
-            table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
-            in_reasoning_block = true
-            -- Buffer-aware lookahead: line_nr is the current 1-indexed
-            -- buffer line. Scanning the live buffer (rather than the
-            -- visible `lines` slice) catches [END] markers that fall
-            -- below the viewport bottom, which is the common case
-            -- after the cursor has moved up into the thinking region.
-            -- While streaming, force explicit-end mode (see comment at
-            -- the top of compute_chat_highlights).
-            if streaming then
-                in_reasoning_explicit_end = true
-            else
-                in_reasoning_explicit_end = reasoning_block_has_end_marker(buf, line_nr, patterns)
+            -- Any structural marker terminates an in-progress reasoning
+            -- block. This mirrors chat_parser's lenient termination so the
+            -- highlight tracks parse boundaries even when the model omits
+            -- the canonical blank-line terminator (or in pre-existing
+            -- chats authored under the old single-line 🧠: convention).
+            local is_user = line:match(patterns.user_pattern)
+            local is_assistant = line:match(patterns.assistant_pattern)
+            local is_branch = line:match(patterns.branch_pattern)
+            local is_local = line:match(patterns.local_pattern)
+            local is_summary = line:match(patterns.summary_pattern)
+            local is_tool_use = line:match("^🔧:")
+            local is_tool_result = line:match("^📎:")
+            if is_user or is_assistant or is_branch or is_local
+                or is_summary or is_tool_use or is_tool_result then
+                in_reasoning_block = false
             end
-        elseif is_summary or line:match("^👂:") then
-            table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
-        elseif is_tool_use or is_tool_result then
-            -- Tool block headers — dim (plumbing, not prose)
-            if line:match("error=true") then
-                table.insert(result[row], { hl_group = "ParleyToolError", col_start = 0, col_end = -1 })
-            else
+
+            if line:match(patterns.reasoning_end_pattern) then
+                -- 🧠:[END] explicit terminator. Highlight the marker line
+                -- itself as ParleyThinking (it's the closing delimiter of
+                -- the thinking region), then close the block. Must be
+                -- checked before reasoning_pattern since the END marker
+                -- also starts with the reasoning prefix.
                 table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
-            end
-            in_tool_block = true
-        elseif in_tool_block and not in_block then
-            -- Inside tool block fenced content — dim
-            table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
-        elseif in_reasoning_block then
-            -- Multi-line thinking continuation. In legacy mode (no
-            -- 🧠:[END] marker downstream) blank line terminates; in
-            -- explicit-end mode blank lines are preserved as part of
-            -- the reasoning region and stay dimmed. Non-blank lines
-            -- always stay dimmed as ParleyThinking.
-            if line:match("^%s*$") and not in_reasoning_explicit_end then
                 in_reasoning_block = false
-            else
+            elseif line:match(patterns.reasoning_pattern) then
                 table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
-            end
-        elseif is_user then
-            table.insert(result[row], { hl_group = "ParleyQuestion", col_start = 0, col_end = -1 })
-            in_block = true
-        elseif is_assistant then
-            in_block = false
-        elseif is_branch then
-            table.insert(result[row], { hl_group = "ParleyChatReference", col_start = 0, col_end = -1 })
-            in_block = false
-        elseif is_local then
-            in_block = false
-        elseif in_block and not in_code_block then
-            table.insert(result[row], { hl_group = "ParleyQuestion", col_start = 0, col_end = -1 })
-            if line:match("^@@") then
-                local is_tag_at_start = false
-                if #highlighted_regions > 0 and highlighted_regions[1].start == 1 then
-                    is_tag_at_start = true
+                in_reasoning_block = true
+                -- Buffer-aware lookahead: line_nr is the current 1-indexed
+                -- buffer line. Scanning the live buffer (rather than the
+                -- visible `lines` slice) catches [END] markers that fall
+                -- below the viewport bottom, which is the common case
+                -- after the cursor has moved up into the thinking region.
+                -- While streaming, force explicit-end mode (see comment at
+                -- the top of compute_chat_highlights).
+                if streaming then
+                    in_reasoning_explicit_end = true
+                else
+                    in_reasoning_explicit_end = reasoning_block_has_end_marker(buf, line_nr, patterns)
                 end
-                if not is_tag_at_start then
-                    table.insert(result[row], { hl_group = "ParleyFileReference", col_start = 0, col_end = -1 })
+            elseif is_summary or line:match("^👂:") then
+                table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
+            elseif is_tool_use or is_tool_result then
+                -- Tool block headers — dim (plumbing, not prose)
+                if line:match("error=true") then
+                    table.insert(result[row], { hl_group = "ParleyToolError", col_start = 0, col_end = -1 })
+                else
+                    table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
+                end
+                in_tool_block = true
+            elseif in_tool_block and not in_block then
+                -- Inside tool block fenced content — dim
+                table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
+            elseif in_reasoning_block then
+                -- Multi-line thinking continuation. In legacy mode (no
+                -- 🧠:[END] marker downstream) blank line terminates; in
+                -- explicit-end mode blank lines are preserved as part of
+                -- the reasoning region and stay dimmed. Non-blank lines
+                -- always stay dimmed as ParleyThinking.
+                if line:match("^%s*$") and not in_reasoning_explicit_end then
+                    in_reasoning_block = false
+                else
+                    table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
+                end
+            elseif is_user then
+                table.insert(result[row], { hl_group = "ParleyQuestion", col_start = 0, col_end = -1 })
+                in_block = true
+            elseif is_assistant then
+                in_block = false
+            elseif is_branch then
+                table.insert(result[row], { hl_group = "ParleyChatReference", col_start = 0, col_end = -1 })
+                in_block = false
+            elseif is_local then
+                in_block = false
+            elseif in_block and not in_code_block then
+                table.insert(result[row], { hl_group = "ParleyQuestion", col_start = 0, col_end = -1 })
+                if line:match("^@@") then
+                    local is_tag_at_start = false
+                    if #highlighted_regions > 0 and highlighted_regions[1].start == 1 then
+                        is_tag_at_start = true
+                    end
+                    if not is_tag_at_start then
+                        table.insert(result[row], { hl_group = "ParleyFileReference", col_start = 0, col_end = -1 })
+                    end
                 end
             end
-        end

-        for start_idx, _, end_idx in line:gmatch("()@(.-)@()") do
-            table.insert(result[row], { hl_group = "ParleyAnnotation", col_start = start_idx - 1, col_end = end_idx - 1 })
+            for start_idx, _, end_idx in line:gmatch("()@(.-)@()") do
+                table.insert(result[row], { hl_group = "ParleyAnnotation", col_start = start_idx - 1, col_end = end_idx - 1 })
+            end
         end
     end

@@ -459,9 +467,16 @@ local function compute_markdown_highlights(buf, start_line, end_line)
     local result = {}
     local branch_prefix = _parley.config.chat_branch_prefix or "🌿:"
     local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)
+    local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
+    local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
     for offset, line in ipairs(lines) do
         local row = start_line + offset - 2
+        local line_nr = row + 1
         push_artifact_refs(result, row, line) -- #160: navigable artifact refs
+        if footer_range and line_nr >= footer_range.start_line and line_nr <= footer_range.end_line then
+            result[row] = result[row] or {}
+            table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
+        end
         if line:sub(1, #branch_prefix) == branch_prefix then
             result[row] = result[row] or {}
             table.insert(result[row], { hl_group = "ParleyChatReference", col_start = 0, col_end = -1 })
@@ -525,7 +540,6 @@ local function compute_markdown_highlights(buf, start_line, end_line)
     -- Draft-block backgrounds (=== label === / === end ===). Full-buffer
     -- scan so a block opened far above the viewport still paints visible
     -- body lines. Bg-only highlight; markdown fg shows through.
-    local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
     local blocks = scan_draft_blocks(all_lines)
     local view_from = start_line - 1
     local view_to = end_line - 1
@@ -730,6 +744,14 @@ M.setup_highlights = function()
         vim.api.nvim_set_hl(0, "ParleyReference", { underline = true })
     end

+    -- Managed definition-footnote footer (`---` + `[^id]: ...`). It must be
+    -- independent of the surrounding chat exchange color.
+    if user_highlights.footnote then
+        vim.api.nvim_set_hl(0, "ParleyFootnote", user_highlights.footnote)
+    else
+        vim.api.nvim_set_hl(0, "ParleyFootnote", { link = "DiagnosticHint" })
+    end
+
     -- Artifact refs (ariadne#11, #15 M4, pair#84) left navigable by #160.
     -- Underline reads as "this is a jumpable ref" without a heavy background.
     -- Override via config.highlight.artifact_ref.
diff --git a/tests/integration/highlighting_spec.lua b/tests/integration/highlighting_spec.lua
index 781888b..43bf5f8 100644
--- a/tests/integration/highlighting_spec.lua
+++ b/tests/integration/highlighting_spec.lua
@@ -162,6 +162,30 @@ describe("highlight_question_block: file reference lines", function()
     end)
 end)

+describe("highlight_question_block: managed footnote footer", function()
+    after_each(cleanup_bufs)
+
+    it("uses a dedicated footnote highlight instead of open-question coloring", function()
+        local buf = highlighted_buf({
+            "💬: Define ASIN",
+            "This question is still open.",
+            "",
+            "---",
+            "",
+            "[^asin]: Amazon Standard Identification Number.",
+        })
+
+        assert.is_true(has_highlight(buf, 3, "ParleyFootnote"),
+            "Expected the managed footer divider to use ParleyFootnote")
+        assert.is_true(has_highlight(buf, 5, "ParleyFootnote"),
+            "Expected the managed footnote definition to use ParleyFootnote")
+        assert.is_false(has_highlight(buf, 3, "ParleyQuestion"),
+            "Managed footer divider should not inherit open-question color")
+        assert.is_false(has_highlight(buf, 5, "ParleyQuestion"),
+            "Managed footnote definition should not inherit open-question color")
+    end)
+end)
+
 describe("decoration provider cache", function()
     after_each(function()
         cleanup_extra_windows()
@@ -572,6 +596,44 @@ describe("markdown footnote diagnostics", function()
             return #diagnostics == 1 and diagnostics[1].source == "parley-skill"
         end)
     end)
+
+    it("renders managed footnote footers with ParleyFootnote in markdown buffers", function()
+        local provider = capture_decoration_provider()
+        local buf = vim.api.nvim_create_buf(false, true)
+        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
+            "here is ASIN[^asin] in context",
+            "",
+            "---",
+            "",
+            "[^asin]: Amazon Standard Identification Number.",
+        })
+        parley._parley_bufs[buf] = "markdown"
+
+        local win = vim.api.nvim_get_current_win()
+        vim.api.nvim_win_set_buf(win, buf)
+        provider.on_win(nil, win, buf, 0, 4)
+
+        local original_set_extmark = vim.api.nvim_buf_set_extmark
+        local extmarks = {}
+        vim.api.nvim_buf_set_extmark = function(_, _, row, _, opts)
+            table.insert(extmarks, { row = row, hl_group = opts.hl_group })
+            return #extmarks
+        end
+
+        provider.on_line(nil, win, buf, 2)
+        provider.on_line(nil, win, buf, 4)
+
+        vim.api.nvim_buf_set_extmark = original_set_extmark
+
+        local highlighted = {}
+        for _, mark in ipairs(extmarks) do
+            if mark.hl_group == "ParleyFootnote" then
+                highlighted[mark.row] = true
+            end
+        end
+        assert.is_true(highlighted[2], "Expected markdown footer divider to use ParleyFootnote")
+        assert.is_true(highlighted[4], "Expected markdown footnote definition to use ParleyFootnote")
+    end)
 end)

 describe("markdown chat reference rendering", function()
diff --git a/tests/unit/define_spec.lua b/tests/unit/define_spec.lua
index f9f2a6d..d7b21ec 100644
--- a/tests/unit/define_spec.lua
+++ b/tests/unit/define_spec.lua
@@ -240,6 +240,30 @@ describe("define durable footnotes", function()
         assert.equals(text, define.strip_definition_footnote_footer(text))
     end)

+    it("reports the final managed footnote footer range", function()
+        local range = define.managed_footnote_footer_range({
+            "answer text",
+            "",
+            "---",
+            "",
+            "[^asin]: Amazon Standard Identification Number.",
+        })
+
+        assert.are.same({ start_line = 3, end_line = 5 }, range)
+    end)
+
+    it("does not report ordinary horizontal rules as managed footnote footers", function()
+        local range = define.managed_footnote_footer_range({
+            "answer text",
+            "",
+            "---",
+            "",
+            "not a footnote",
+        })
+
+        assert.is_nil(range)
+    end)
+
     it("keeps earlier horizontal-rule content and strips only the final managed footer", function()
         local text = table.concat({
             "answer text",


codex
I’ll use the repo workflow instructions plus the review prompt as the contract, then inspect the issue, plan, and actual diff before giving the machine-readable verdict.
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

codex
I’ve loaded the mandatory workflow context and lessons. Next I’m checking the issue artifact and the actual base-to-HEAD diff so I can verify the prompt’s diff against the repository state, not just trust the pasted excerpt.
exec
/bin/zsh -lc "sed -n '1,260p' workshop/issues/000171-footnote-coloring.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
---
id: 000171
status: working
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 0.43
started: 2026-07-08T17:14:54-07:00
---

# footnote coloring

footnote should have dedicated color. right now it uses the color of last exchange. for example, if last exchange only has open question, footnote is displayed with question color.

## Problem

Managed definition footnotes are appended as a final markdown footer, but chat
highlighting treats an unanswered question as continuing to EOF. When the last
exchange is an open question, the footer inherits `ParleyQuestion`, so footnotes
take on the color of the last exchange instead of having a stable dedicated
appearance.

## Spec

Managed definition footnote footer lines render with a dedicated
`ParleyFootnote` highlight group in both chat and markdown buffers.

The managed-footer grammar remains single-sourced with the definition feature
(ARCH-DRY): highlighter code should consume a pure footer-range helper rather
than duplicate the `---` + `[^id]: ...` parser.

The dedicated footnote highlight must override chat block fallback coloring for
footer rows while leaving open issue/question highlighting unchanged for ordinary
question body lines.

## Done when

- A regression test covers an open question followed by a managed footnote footer.
- Footer divider and footnote definition rows receive `ParleyFootnote`.
- Footer rows no longer receive `ParleyQuestion` from an unanswered question block.
- Markdown buffers can use the same dedicated footnote group.

## Plan

- [x] Expose a pure managed-footnote footer range helper from `parley.define`.
- [x] Add unit coverage for the footer range helper.
- [x] Add highlighter regression coverage for an open question followed by a managed footer.
- [x] Apply `ParleyFootnote` in chat and markdown highlight computation.
- [x] Update atlas highlight docs and run focused plus repo verification.

## Estimate

Derived via `estimate-logic-v3.1` against the repo-local calibration source from
`sdlc estimate-source` (stale but canonical for this repo).

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.04 impl=0.00
item: lua-neovim design=0.09 impl=0.22
item: atlas-docs design=0.00 impl=0.02
item: milestone-review design=0.00 impl=0.02
total: 0.43
```

## Log

### 2026-07-08

- Claimed the issue and inspected the chat/markdown highlighter paths. Root
  cause: open-question chat highlighting continues to EOF, so the final managed
  footnote footer is colored as `ParleyQuestion`.
- Added `define.managed_footnote_footer_range` so the footer grammar remains
  single-sourced with the definition feature (ARCH-DRY).
- Implemented `ParleyFootnote` for managed footer rows in both chat and markdown
  highlight computation; chat footers now terminate open-question color fallback.
- Verification: `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`
  passed; `nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"`
  passed; scoped `git diff --check -- atlas/ui/highlights.md lua/parley/define.lua
  lua/parley/highlighter.lua tests/integration/highlighting_spec.lua
  tests/unit/define_spec.lua workshop/issues/000171-footnote-coloring.md`
  passed.
- Full `make test` linted `lua` and `tests` successfully but failed in unrelated
  `tests/unit/tools_builtin_find_spec.lua` under the parallel unit runner; that
  same spec passed when run directly with
  `nvim --headless -c "PlenaryBustedFile tests/unit/tools_builtin_find_spec.lua"`.

exec
/bin/zsh -lc 'git diff --name-only 4005929621a91a6e1a9a02bd048a859bb59ffb77..HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
atlas/ui/highlights.md
lua/parley/define.lua
lua/parley/highlighter.lua
tests/integration/highlighting_spec.lua
tests/unit/define_spec.lua
workshop/issues/000171-footnote-coloring.md

exec
/bin/zsh -lc 'git diff --stat 4005929621a91a6e1a9a02bd048a859bb59ffb77..HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
 atlas/ui/highlights.md                      |   5 +-
 lua/parley/define.lua                       |  12 ++
 lua/parley/highlighter.lua                  | 206 +++++++++++++++-------------
 tests/integration/highlighting_spec.lua     |  62 +++++++++
 tests/unit/define_spec.lua                  |  24 ++++
 workshop/issues/000171-footnote-coloring.md |  63 ++++++++-
 6 files changed, 276 insertions(+), 96 deletions(-)

exec
/bin/zsh -lc 'git status --short' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
 M workshop/issues/000162-split-parley-into-two-different-plugins.md
 M workshop/issues/000168-buffer-undo-operation-during-chat-generation-resulted-in-a-huge-error-message.md
 M workshop/issues/000170-parley-chat-performance-problem.md

codex
The issue is narrow and the documented plan has no Core concepts table, so the main traceability checks are Spec/Done-when plus docs gate. I’m reading the surrounding implementation now, especially the footer parser contract and decoration-provider state handling.
exec
/bin/zsh -lc "nl -ba lua/parley/define.lua | sed -n '150,250p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   150
   151    --- @param id string
   152    --- @param definition string|nil
   153    --- @return string
   154    function M.format_footnote_line(id, definition)
   155        definition = trim(definition)
   156        if definition == "" then
   157            definition = "(no definition)"
   158        end
   159        return string.format("[^%s]: %s", id, definition)
   160    end
   161
   162    local function is_divider(line)
   163        return trim(line) == "---"
   164    end
   165
   166    local function is_footnote_line(line)
   167        return trim(line):match("^%[%^[^%]]+%]:") ~= nil
   168    end
   169
   170    local function managed_footer_start(lines)
   171        for i = #lines, 1, -1 do
   172            if is_divider(lines[i]) then
   173                local has_footnote = false
   174                for j = i + 1, #lines do
   175                    local line = lines[j] or ""
   176                    if trim(line) ~= "" then
   177                        if not is_footnote_line(line) then
   178                            return nil
   179                        end
   180                        has_footnote = true
   181                    end
   182                end
   183                if has_footnote then
   184                    return i
   185                end
   186                return nil
   187            end
   188        end
   189        return nil
   190    end
   191
   192    --- Locate the final managed definition-footnote footer.
   193    --- @param lines string[]|nil
   194    --- @return table|nil { start_line: integer, end_line: integer } 1-based inclusive
   195    function M.managed_footnote_footer_range(lines)
   196        lines = lines or {}
   197        local start = managed_footer_start(lines)
   198        if not start then
   199            return nil
   200        end
   201        return { start_line = start, end_line = #lines }
   202    end
   203
   204    local function parse_footnote_line(line)
   205        local id, definition = trim(line):match("^%[%^([^%]]+)%]:%s*(.-)%s*$")
   206        if not id then
   207            return nil
   208        end
   209        definition = trim(definition)
   210        if definition == "" then
   211            definition = "(no definition)"
   212        end
   213        return id, definition
   214    end
   215
   216    local function is_term_byte(ch)
   217        return ch:match("[%w_-]") ~= nil
   218    end
   219
   220    local function expand_term_start(line, ref_start)
   221        local start = ref_start
   222        while start > 1 and is_term_byte(line:sub(start - 1, start - 1)) do
   223            start = start - 1
   224        end
   225        return start
   226    end
   227
   228    --- Derive persisted definition diagnostics from inline footnote references and
   229    --- the final managed definition footer.
   230    --- @param lines string[]
   231    --- @return table[] diagnostics with 0-based columns
   232    function M.footnote_diagnostics(lines)
   233        lines = lines or {}
   234        local footer = managed_footer_start(lines)
   235        if not footer then
   236            return {}
   237        end
   238
   239        local definitions = {}
   240        for i = footer + 1, #lines do
   241            local id, definition = parse_footnote_line(lines[i] or "")
   242            if id then
   243                definitions[id] = definition
   244            end
   245        end
   246
   247        local diagnostics = {}
   248        for lnum = 1, footer - 1 do
   249            local line = lines[lnum] or ""
   250            local search = 1

exec
/bin/zsh -lc "nl -ba lua/parley/highlighter.lua | sed -n '240,370p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   240        for _, win in ipairs(vim.api.nvim_list_wins()) do
   241            if vim.api.nvim_win_get_buf(win) == buf then
   242                local ok, bounds = pcall(vim.api.nvim_win_call, win, function()
   243                    return { top = vim.fn.line("w0"), bottom = vim.fn.line("w$") }
   244                end)
   245                if ok and bounds then
   246                    local start_line = math.max(1, (bounds.top or 1) - margin)
   247                    local end_line = math.min(line_count, (bounds.bottom or line_count) + margin)
   248                    if start_line <= end_line then
   249                        table.insert(ranges, { start_line = start_line, end_line = end_line })
   250                    end
   251                end
   252            end
   253        end
   254
   255        if #ranges == 0 and line_count > 0 then
   256            table.insert(ranges, { start_line = 1, end_line = line_count })
   257        end
   258
   259        return merge_line_ranges(ranges)
   260    end
   261
   262    -- Compute desired chat highlights for a 1-indexed line range.
   263    -- Returns a table keyed by 0-indexed row: { [row] = { {hl_group, col_start, col_end}, ... } }
   264    -- Scans HIGHLIGHT_CONTEXT_LINES above start_line for block state context.
   265    local function compute_chat_highlights(buf, start_line, end_line)
   266        local result = {}
   267        local patterns = get_chat_highlight_prefix_patterns()
   268        local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)
   269        local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
   270        local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
   271        -- While a stream is in flight for this buffer, the model has not
   272        -- yet emitted 🧠:[END]. Assume explicit-end mode so blank-line
   273        -- paragraph breaks inside the in-progress thinking region keep
   274        -- their dim highlight instead of prematurely terminating the
   275        -- block. After the stream completes (is_busy → false), the
   276        -- lookahead-decided mode takes over and a real [END] / structural
   277        -- marker controls termination.
   278        local streaming = require("parley.tasker").is_busy(buf, true)
   279        local in_block, in_code_block, in_reasoning_block, in_reasoning_explicit_end =
   280            bootstrap_chat_highlight_state(buf, start_line, patterns, streaming)
   281
   282        local in_tool_block = false  -- inside 🔧:/📎: fenced content
   283
   284        for offset, line in ipairs(lines) do
   285            local line_nr = start_line + offset - 1
   286            if line:match("^%s*```") then
   287                in_code_block = not in_code_block
   288                -- Exiting a code block while in a tool region ends the tool region
   289                if not in_code_block and in_tool_block then
   290                    in_tool_block = false
   291                end
   292            end
   293
   294            local highlighted_regions = {}
   295            local row = line_nr - 1
   296
   297            result[row] = result[row] or {}
   298
   299            push_artifact_refs(result, row, line) -- #160: navigable artifact refs
   300
   301            local is_footer = footer_range and line_nr >= footer_range.start_line and line_nr <= footer_range.end_line
   302            if is_footer then
   303                table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
   304                in_block = false
   305            else
   306                local pos = 1
   307                while true do
   308                    local tag_start, content_start = line:find("@@", pos)
   309                    if not tag_start then break end
   310                    local content_end, tag_end = line:find("@@", content_start + 1)
   311                    if not content_end then break end
   312                    table.insert(highlighted_regions, { start = tag_start, finish = tag_end })
   313                    table.insert(result[row], { hl_group = "ParleyTag", col_start = tag_start - 1, col_end = tag_end })
   314                    pos = tag_end + 1
   315                end
   316
   317                -- Any structural marker terminates an in-progress reasoning
   318                -- block. This mirrors chat_parser's lenient termination so the
   319                -- highlight tracks parse boundaries even when the model omits
   320                -- the canonical blank-line terminator (or in pre-existing
   321                -- chats authored under the old single-line 🧠: convention).
   322                local is_user = line:match(patterns.user_pattern)
   323                local is_assistant = line:match(patterns.assistant_pattern)
   324                local is_branch = line:match(patterns.branch_pattern)
   325                local is_local = line:match(patterns.local_pattern)
   326                local is_summary = line:match(patterns.summary_pattern)
   327                local is_tool_use = line:match("^🔧:")
   328                local is_tool_result = line:match("^📎:")
   329                if is_user or is_assistant or is_branch or is_local
   330                    or is_summary or is_tool_use or is_tool_result then
   331                    in_reasoning_block = false
   332                end
   333
   334                if line:match(patterns.reasoning_end_pattern) then
   335                    -- 🧠:[END] explicit terminator. Highlight the marker line
   336                    -- itself as ParleyThinking (it's the closing delimiter of
   337                    -- the thinking region), then close the block. Must be
   338                    -- checked before reasoning_pattern since the END marker
   339                    -- also starts with the reasoning prefix.
   340                    table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
   341                    in_reasoning_block = false
   342                elseif line:match(patterns.reasoning_pattern) then
   343                    table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
   344                    in_reasoning_block = true
   345                    -- Buffer-aware lookahead: line_nr is the current 1-indexed
   346                    -- buffer line. Scanning the live buffer (rather than the
   347                    -- visible `lines` slice) catches [END] markers that fall
   348                    -- below the viewport bottom, which is the common case
   349                    -- after the cursor has moved up into the thinking region.
   350                    -- While streaming, force explicit-end mode (see comment at
   351                    -- the top of compute_chat_highlights).
   352                    if streaming then
   353                        in_reasoning_explicit_end = true
   354                    else
   355                        in_reasoning_explicit_end = reasoning_block_has_end_marker(buf, line_nr, patterns)
   356                    end
   357                elseif is_summary or line:match("^👂:") then
   358                    table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
   359                elseif is_tool_use or is_tool_result then
   360                    -- Tool block headers — dim (plumbing, not prose)
   361                    if line:match("error=true") then
   362                        table.insert(result[row], { hl_group = "ParleyToolError", col_start = 0, col_end = -1 })
   363                    else
   364                        table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
   365                    end
   366                    in_tool_block = true
   367                elseif in_tool_block and not in_block then
   368                    -- Inside tool block fenced content — dim
   369                    table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
   370                elseif in_reasoning_block then

exec
/bin/zsh -lc "nl -ba lua/parley/highlighter.lua | sed -n '450,555p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   450    --   * a *live* 🤖 marker's section   — `[U]` chained after 🤖 / `>` / `~` / a
   451    --                                     prior `]`/`}` close (already highlighted
   452    --                                     ParleyReviewUser; don't double-mark it).
   453    -- A flattened reference span's `[` follows ordinary prose, so it passes.
   454    function M.is_reference_span(line, s, content, e)
   455        if line:sub(e, e) == "(" then return false end
   456        if content:sub(1, 1) == "^" then return false end
   457        if #content < 2 then return false end
   458        local prev = line:sub(s - 1, s - 1)
   459        if prev == "]" or prev == "}" or prev == ">" or prev == "~" then return false end
   460        if s > 4 and line:sub(s - 4, s - 1) == "🤖" then return false end
   461        return true
   462    end
   463
   464    -- Compute desired markdown highlights for a 1-indexed line range.
   465    -- Returns a table keyed by 0-indexed row: { [row] = { {hl_group, col_start, col_end}, ... } }
   466    local function compute_markdown_highlights(buf, start_line, end_line)
   467        local result = {}
   468        local branch_prefix = _parley.config.chat_branch_prefix or "🌿:"
   469        local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)
   470        local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
   471        local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
   472        for offset, line in ipairs(lines) do
   473            local row = start_line + offset - 2
   474            local line_nr = row + 1
   475            push_artifact_refs(result, row, line) -- #160: navigable artifact refs
   476            if footer_range and line_nr >= footer_range.start_line and line_nr <= footer_range.end_line then
   477                result[row] = result[row] or {}
   478                table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
   479            end
   480            if line:sub(1, #branch_prefix) == branch_prefix then
   481                result[row] = result[row] or {}
   482                table.insert(result[row], { hl_group = "ParleyChatReference", col_start = 0, col_end = -1 })
   483            end
   484            -- Highlight 🤖<...>[...]{...} review markers
   485            local review = require("parley.review")
   486            local search_start = 1
   487            while true do
   488                local pos = line:find("🤖", search_start, true)
   489                if not pos then break end
   490                local sections, end_pos, quoted, strike = review._parse_marker_sections(line, pos, 4)
   491                if quoted then
   492                    -- Highlight the 🤖 + `<…>` together so the whole "this marker
   493                    -- refers to a precise quote" prefix reads as one unit.
   494                    result[row] = result[row] or {}
   495                    table.insert(result[row], {
   496                        hl_group = "ParleyReviewQuoted",
   497                        col_start = pos - 1,             -- 0-indexed pos of 🤖
   498                        col_end = quoted.byte_end,       -- inclusive close `>`
   499                    })
   500                elseif strike then
   501                    -- Strikethrough for the `~X~` content (custom rendering — we
   502                    -- own this since markdown's strikethrough is disabled
   503                    -- buffer-wide to avoid false positives on `~/path` tildes).
   504                    result[row] = result[row] or {}
   505                    table.insert(result[row], {
   506                        hl_group = "ParleyReviewStrike",
   507                        col_start = pos - 1,             -- 0-indexed pos of 🤖
   508                        col_end = strike.byte_end,       -- inclusive close `~`
   509                    })
   510                end
   511                for _, section in ipairs(sections) do
   512                    local hl = section.type == "agent" and "ParleyReviewAgent" or "ParleyReviewUser"
   513                    result[row] = result[row] or {}
   514                    table.insert(result[row], {
   515                        hl_group = hl,
   516                        col_start = section.byte_start - 1,  -- 0-indexed
   517                        col_end = section.byte_end,           -- exclusive end
   518                    })
   519                end
   520                search_start = end_pos
   521            end
   522
   523            -- #127: highlight drill-in referenced-span markers `[…]` left in the
   524            -- reply (what each gathered comment points at) via the pure
   525            -- M.is_reference_span heuristic. Disable via mark_reference_span = false.
   526            if _parley.config.mark_reference_span ~= false then
   527                for s, content, e in line:gmatch("()%[([^%[%]]+)%]()") do
   528                    if M.is_reference_span(line, s, content, e) then
   529                        result[row] = result[row] or {}
   530                        table.insert(result[row], {
   531                            hl_group = "ParleyReference",
   532                            col_start = s - 1, -- 0-indexed `[`
   533                            col_end = e - 1,   -- exclusive end (through `]`)
   534                        })
   535                    end
   536                end
   537            end
   538        end
   539
   540        -- Draft-block backgrounds (=== label === / === end ===). Full-buffer
   541        -- scan so a block opened far above the viewport still paints visible
   542        -- body lines. Bg-only highlight; markdown fg shows through.
   543        local blocks = scan_draft_blocks(all_lines)
   544        local view_from = start_line - 1
   545        local view_to = end_line - 1
   546        for _, block in ipairs(blocks) do
   547            local from = math.max(block.open_row, view_from)
   548            local to = math.min(block.close_row, view_to)
   549            for row = from, to do
   550                result[row] = result[row] or {}
   551                -- Multi-line range (row,0 → row+1,0) + hl_eol paints bg past EOL
   552                -- so short and empty lines inside the block still get the shaded
   553                -- background. Same trick diff/cursorline use.
   554                table.insert(result[row], {
   555                    hl_group = "ParleyDraftBlock",

exec
/bin/zsh -lc "nl -ba tests/integration/highlighting_spec.lua | sed -n '130,210p'" in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc "nl -ba tests/integration/highlighting_spec.lua | sed -n '560,635p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   130
   131        it("applies ParleyThinking highlight to 🧠: reasoning line", function()
   132            local buf = highlighted_buf({
   133                "💬: Question",
   134                "🤖:[Agent] Answer.",
   135                "🧠: user wants to understand topic",
   136            })
   137            assert.is_true(has_highlight(buf, 2, "ParleyThinking"),
   138                "Expected 'ParleyThinking' highlight on 🧠: line")
   139        end)
   140    end)
   141
   142    describe("highlight_question_block: file reference lines", function()
   143        after_each(cleanup_bufs)
   144
   145        it("applies FileLoading highlight to @@ file reference lines in a question block", function()
   146            local buf = highlighted_buf({
   147                "💬: Check this file",
   148                "@@/path/to/some/file.lua",
   149                "🤖:[Agent] Done.",
   150            })
   151            assert.is_true(has_highlight(buf, 1, "ParleyFileReference"),
   152                "Expected 'ParleyFileReference' highlight on @@ file reference line")
   153        end)
   154
   155        it("does NOT apply ParleyFileReference highlight to @@ lines outside question blocks", function()
   156            local buf = highlighted_buf({
   157                "🤖:[Agent] See @@/some/file.lua here",
   158            })
   159            -- Row 0 is an answer line; ParleyFileReference should not be applied
   160            assert.is_false(has_highlight(buf, 0, "ParleyFileReference"),
   161                "ParleyFileReference should not appear on answer lines")
   162        end)
   163    end)
   164
   165    describe("highlight_question_block: managed footnote footer", function()
   166        after_each(cleanup_bufs)
   167
   168        it("uses a dedicated footnote highlight instead of open-question coloring", function()
   169            local buf = highlighted_buf({
   170                "💬: Define ASIN",
   171                "This question is still open.",
   172                "",
   173                "---",
   174                "",
   175                "[^asin]: Amazon Standard Identification Number.",
   176            })
   177
   178            assert.is_true(has_highlight(buf, 3, "ParleyFootnote"),
   179                "Expected the managed footer divider to use ParleyFootnote")
   180            assert.is_true(has_highlight(buf, 5, "ParleyFootnote"),
   181                "Expected the managed footnote definition to use ParleyFootnote")
   182            assert.is_false(has_highlight(buf, 3, "ParleyQuestion"),
   183                "Managed footer divider should not inherit open-question color")
   184            assert.is_false(has_highlight(buf, 5, "ParleyQuestion"),
   185                "Managed footnote definition should not inherit open-question color")
   186        end)
   187    end)
   188
   189    describe("decoration provider cache", function()
   190        after_each(function()
   191            cleanup_extra_windows()
   192            cleanup_bufs()
   193        end)
   194
   195        it("keeps highlight caches isolated per window for the same buffer", function()
   196            local provider = capture_decoration_provider()
   197            assert.is_table(provider)
   198            assert.is_function(provider.on_win)
   199            assert.is_function(provider.on_line)
   200
   201            local buf = vim.api.nvim_create_buf(false, true)
   202            local lines = {}
   203            for i = 1, 120 do
   204                lines[i] = ("filler line %03d"):format(i)
   205            end
   206            lines[1] = "💬: top question"
   207            lines[71] = "💬: lower question"
   208            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
   209
   210            vim.cmd("vsplit")

 succeeded in 0ms:
   560                message = "review diagnostic",
   561                severity = vim.diagnostic.severity.INFO,
   562                source = "parley-skill",
   563            } })
   564
   565            vim.cmd("doautocmd TextChanged")
   566            vim.wait(100, function()
   567                local diagnostics = vim.diagnostic.get(buf, { namespace = ns })
   568                return #diagnostics == 1 and diagnostics[1].source == "parley-skill"
   569            end)
   570
   571            vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
   572                "here is ASIN[^asin] in context",
   573                "",
   574                "---",
   575                "",
   576                "[^asin]: Amazon Standard Identification Number.",
   577            })
   578            vim.cmd("doautocmd TextChanged")
   579            vim.wait(100, function()
   580                local diagnostics = vim.diagnostic.get(buf, { namespace = ns })
   581                return #diagnostics == 2
   582            end)
   583
   584            local by_source = {}
   585            for _, diagnostic in ipairs(vim.diagnostic.get(buf, { namespace = ns })) do
   586                by_source[diagnostic.source] = diagnostic
   587            end
   588            assert.is_not_nil(by_source["parley-skill"])
   589            assert.is_not_nil(by_source["parley-footnote"])
   590            assert.equals(8, by_source["parley-footnote"].col)
   591
   592            vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "footnote removed" })
   593            vim.cmd("doautocmd TextChanged")
   594            vim.wait(100, function()
   595                local diagnostics = vim.diagnostic.get(buf, { namespace = ns })
   596                return #diagnostics == 1 and diagnostics[1].source == "parley-skill"
   597            end)
   598        end)
   599
   600        it("renders managed footnote footers with ParleyFootnote in markdown buffers", function()
   601            local provider = capture_decoration_provider()
   602            local buf = vim.api.nvim_create_buf(false, true)
   603            vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
   604                "here is ASIN[^asin] in context",
   605                "",
   606                "---",
   607                "",
   608                "[^asin]: Amazon Standard Identification Number.",
   609            })
   610            parley._parley_bufs[buf] = "markdown"
   611
   612            local win = vim.api.nvim_get_current_win()
   613            vim.api.nvim_win_set_buf(win, buf)
   614            provider.on_win(nil, win, buf, 0, 4)
   615
   616            local original_set_extmark = vim.api.nvim_buf_set_extmark
   617            local extmarks = {}
   618            vim.api.nvim_buf_set_extmark = function(_, _, row, _, opts)
   619                table.insert(extmarks, { row = row, hl_group = opts.hl_group })
   620                return #extmarks
   621            end
   622
   623            provider.on_line(nil, win, buf, 2)
   624            provider.on_line(nil, win, buf, 4)
   625
   626            vim.api.nvim_buf_set_extmark = original_set_extmark
   627
   628            local highlighted = {}
   629            for _, mark in ipairs(extmarks) do
   630                if mark.hl_group == "ParleyFootnote" then
   631                    highlighted[mark.row] = true
   632                end
   633            end
   634            assert.is_true(highlighted[2], "Expected markdown footer divider to use ParleyFootnote")
   635            assert.is_true(highlighted[4], "Expected markdown footnote definition to use ParleyFootnote")

exec
/bin/zsh -lc "nl -ba tests/unit/define_spec.lua | sed -n '220,280p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
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
   231        it("preserves ordinary horizontal rules that are not managed footnote footers", function()
   232            local text = table.concat({
   233                "answer text",
   234                "",
   235                "---",
   236                "",
   237                "not a footnote",
   238            }, "\n")
   239
   240            assert.equals(text, define.strip_definition_footnote_footer(text))
   241        end)
   242
   243        it("reports the final managed footnote footer range", function()
   244            local range = define.managed_footnote_footer_range({
   245                "answer text",
   246                "",
   247                "---",
   248                "",
   249                "[^asin]: Amazon Standard Identification Number.",
   250            })
   251
   252            assert.are.same({ start_line = 3, end_line = 5 }, range)
   253        end)
   254
   255        it("does not report ordinary horizontal rules as managed footnote footers", function()
   256            local range = define.managed_footnote_footer_range({
   257                "answer text",
   258                "",
   259                "---",
   260                "",
   261                "not a footnote",
   262            })
   263
   264            assert.is_nil(range)
   265        end)
   266
   267        it("keeps earlier horizontal-rule content and strips only the final managed footer", function()
   268            local text = table.concat({
   269                "answer text",
   270                "",
   271                "---",
   272                "",
   273                "ordinary body after a rule",
   274                "",
   275                "---",
   276                "",
   277                "[^asin]: Amazon Standard Identification Number.",
   278            }, "\n")
   279
   280            assert.equals(table.concat({

codex
So far the core shape matches the issue: a pure footer-range helper in `define`, reused by chat and markdown highlighting. I’m checking configuration/docs expectations now because the diff adds a new user-overridable highlight key, which may trigger the README/docs gate depending on existing config documentation.
exec
/bin/zsh -lc "rg -n \"user_highlights|highlight\\.|config.highlight|Parley[A-Za-z]+\" lua/parley/config.lua lua/parley/highlighter.lua README.md doc tests -g '"'!workshop/history/**'"'" in /Users/xianxu/workspace/parley.nvim
 exited 2 in 0ms:
rg: doc: No such file or directory (os error 2)
lua/parley/config.lua:8:---@class ParleyConfig
lua/parley/config.lua:40:        -- lives in the cliproxy auth-dir via :ParleyProxy login). In managed mode
lua/parley/config.lua:115:    -- `:ParleyProxy login <provider>` (OAuth). Set manage=false to opt out.
lua/parley/config.lua:124:        --   original opt-in default; see issue #131 spec). `:ParleyProxy update`
lua/parley/config.lua:511:    -- default search term when using :ParleyChatFinder
lua/parley/config.lua:634:    -- highlight those spans (ParleyReference). Set to false to strip markers
lua/parley/config.lua:685:        -- ParleyInspectPlugin provides a detailed inspection of the plugin state
lua/parley/config.lua:700:        -- ParleyInspectLog for checking the log file
README.md:100:1. Run `:ParleyChatNew` (default shortcut: `<C-g>c`) to create a new chat.
README.md:102:3. Run `:ParleyChatRespond` (default shortcut: `<C-g><C-g>`) with mouse on the question line.
README.md:130:- `:ParleyChatNew` create a new chat
README.md:131:- `:ParleyChatFinder` chat finder
README.md:132:- `:ParleyChatRespond` answer current question
README.md:133:- `:ParleyChatRespondAll` regenerate from start to cursor
README.md:134:- `:ParleyStop` stop running generation
README.md:135:- `:ParleyOutline` display questions in this buffer for navigation
README.md:136:- `:ParleyKeyBindings` show active Parley keyboard shortcuts
README.md:137:- `:ParleyAgent` switch agent
README.md:138:- `:ParleySystemPrompt` switch system prompt
README.md:139:- `:ParleyToggleFollowCursor` toggle live cursor-follow during streaming
README.md:144:  - parley can **manage a local `cliproxyapi`** for you — it renders the config from Lua and lazily starts/reuses/health-checks the proxy. `:ParleyProxy status|start|stop|restart|models <provider>|providers|login <provider>|update` (bare `:ParleyProxy` prints per-subcommand help). **On by default but dormant** — only acts when a cliproxyapi-provider agent runs, and reuses an existing proxy if one is up; a fresh machine needs `brew install cliproxyapi` + a one-time `:ParleyProxy login`. Set `cliproxy = { manage = false }` to opt out. See [atlas/providers/cliproxy-managed.md](atlas/providers/cliproxy-managed.md).
README.md:167:- `:ParleyChatDirs` opens a picker to add or remove chat roots at runtime.
README.md:168:- `:ParleyChatDirAdd {dir}` adds a root directly, with directory completion.
README.md:169:- `:ParleyChatDirRemove {dir}` removes a configured root directly.
README.md:170:- `:ParleyChatMove {dir}` moves the current chat to another registered chat root.
lua/parley/highlighter.lua:27:            hl_group = "ParleyArtifactRef",
lua/parley/highlighter.lua:105:-- (blank lines inside the block stay highlighted as ParleyThinking).
lua/parley/highlighter.lua:303:            table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
lua/parley/highlighter.lua:313:                table.insert(result[row], { hl_group = "ParleyTag", col_start = tag_start - 1, col_end = tag_end })
lua/parley/highlighter.lua:336:                -- itself as ParleyThinking (it's the closing delimiter of
lua/parley/highlighter.lua:340:                table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
lua/parley/highlighter.lua:343:                table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
lua/parley/highlighter.lua:358:                table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
lua/parley/highlighter.lua:362:                    table.insert(result[row], { hl_group = "ParleyToolError", col_start = 0, col_end = -1 })
lua/parley/highlighter.lua:364:                    table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
lua/parley/highlighter.lua:369:                table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
lua/parley/highlighter.lua:375:                -- always stay dimmed as ParleyThinking.
lua/parley/highlighter.lua:379:                    table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
lua/parley/highlighter.lua:382:                table.insert(result[row], { hl_group = "ParleyQuestion", col_start = 0, col_end = -1 })
lua/parley/highlighter.lua:387:                table.insert(result[row], { hl_group = "ParleyChatReference", col_start = 0, col_end = -1 })
lua/parley/highlighter.lua:392:                table.insert(result[row], { hl_group = "ParleyQuestion", col_start = 0, col_end = -1 })
lua/parley/highlighter.lua:399:                        table.insert(result[row], { hl_group = "ParleyFileReference", col_start = 0, col_end = -1 })
lua/parley/highlighter.lua:405:                table.insert(result[row], { hl_group = "ParleyAnnotation", col_start = start_idx - 1, col_end = end_idx - 1 })
lua/parley/highlighter.lua:452:--                                     ParleyReviewUser; don't double-mark it).
lua/parley/highlighter.lua:478:            table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
lua/parley/highlighter.lua:482:            table.insert(result[row], { hl_group = "ParleyChatReference", col_start = 0, col_end = -1 })
lua/parley/highlighter.lua:496:                    hl_group = "ParleyReviewQuoted",
lua/parley/highlighter.lua:506:                    hl_group = "ParleyReviewStrike",
lua/parley/highlighter.lua:512:                local hl = section.type == "agent" and "ParleyReviewAgent" or "ParleyReviewUser"
lua/parley/highlighter.lua:531:                        hl_group = "ParleyReference",
lua/parley/highlighter.lua:555:                hl_group = "ParleyDraftBlock",
lua/parley/highlighter.lua:645:    local ns_id = vim.api.nvim_create_namespace("ParleyChatExt")
lua/parley/highlighter.lua:669:    local user_highlights = _parley.config.highlight or {}
lua/parley/highlighter.lua:673:    if user_highlights.question then
lua/parley/highlighter.lua:675:        vim.api.nvim_set_hl(0, "ParleyQuestion", user_highlights.question)
lua/parley/highlighter.lua:677:        vim.api.nvim_set_hl(0, "ParleyQuestion", {
lua/parley/highlighter.lua:683:    if user_highlights.file_reference then
lua/parley/highlighter.lua:684:        vim.api.nvim_set_hl(0, "ParleyFileReference", user_highlights.file_reference)
lua/parley/highlighter.lua:686:        vim.api.nvim_set_hl(0, "ParleyFileReference", {
lua/parley/highlighter.lua:692:    if user_highlights.thinking then
lua/parley/highlighter.lua:693:        vim.api.nvim_set_hl(0, "ParleyThinking", user_highlights.thinking)
lua/parley/highlighter.lua:695:        vim.api.nvim_set_hl(0, "ParleyThinking", {
lua/parley/highlighter.lua:701:    if user_highlights.tool_error then
lua/parley/highlighter.lua:702:        vim.api.nvim_set_hl(0, "ParleyToolError", user_highlights.tool_error)
lua/parley/highlighter.lua:704:        vim.api.nvim_set_hl(0, "ParleyToolError", {
lua/parley/highlighter.lua:710:    if user_highlights.annotation then
lua/parley/highlighter.lua:711:        vim.api.nvim_set_hl(0, "ParleyAnnotation", user_highlights.annotation)
lua/parley/highlighter.lua:713:        vim.api.nvim_set_hl(0, "ParleyAnnotation", {
lua/parley/highlighter.lua:719:    if user_highlights.chat_reference then
lua/parley/highlighter.lua:720:        vim.api.nvim_set_hl(0, "ParleyChatReference", user_highlights.chat_reference)
lua/parley/highlighter.lua:722:        vim.api.nvim_set_hl(0, "ParleyChatReference", {
lua/parley/highlighter.lua:728:    if user_highlights.inline_branch then
lua/parley/highlighter.lua:729:        vim.api.nvim_set_hl(0, "ParleyInlineBranch", user_highlights.inline_branch)
lua/parley/highlighter.lua:731:        vim.api.nvim_set_hl(0, "ParleyInlineBranch", {
lua/parley/highlighter.lua:740:    -- config.highlight.reference.
lua/parley/highlighter.lua:741:    if user_highlights.reference then
lua/parley/highlighter.lua:742:        vim.api.nvim_set_hl(0, "ParleyReference", user_highlights.reference)
lua/parley/highlighter.lua:744:        vim.api.nvim_set_hl(0, "ParleyReference", { underline = true })
lua/parley/highlighter.lua:749:    if user_highlights.footnote then
lua/parley/highlighter.lua:750:        vim.api.nvim_set_hl(0, "ParleyFootnote", user_highlights.footnote)
lua/parley/highlighter.lua:752:        vim.api.nvim_set_hl(0, "ParleyFootnote", { link = "DiagnosticHint" })
lua/parley/highlighter.lua:757:    -- Override via config.highlight.artifact_ref.
lua/parley/highlighter.lua:758:    if user_highlights.artifact_ref then
lua/parley/highlighter.lua:759:        vim.api.nvim_set_hl(0, "ParleyArtifactRef", user_highlights.artifact_ref)
lua/parley/highlighter.lua:761:        vim.api.nvim_set_hl(0, "ParleyArtifactRef", { underline = true })
lua/parley/highlighter.lua:765:    if user_highlights.tag then
lua/parley/highlighter.lua:766:        vim.api.nvim_set_hl(0, "ParleyTag", user_highlights.tag)
lua/parley/highlighter.lua:768:        vim.api.nvim_set_hl(0, "ParleyTag", {
lua/parley/highlighter.lua:774:    if user_highlights.approximate_match then
lua/parley/highlighter.lua:775:        vim.api.nvim_set_hl(0, "ParleyPickerApproximateMatch", user_highlights.approximate_match)
lua/parley/highlighter.lua:777:        vim.api.nvim_set_hl(0, "ParleyPickerApproximateMatch", {
lua/parley/highlighter.lua:785:    -- via config.highlight.draft_block.
lua/parley/highlighter.lua:786:    if user_highlights.draft_block then
lua/parley/highlighter.lua:787:        vim.api.nvim_set_hl(0, "ParleyDraftBlock", user_highlights.draft_block)
lua/parley/highlighter.lua:789:        vim.api.nvim_set_hl(0, "ParleyDraftBlock", { link = "CursorLine" })
lua/parley/highlighter.lua:793:    vim.api.nvim_set_hl(0, "ParleyReviewUser", { link = "DiagnosticWarn" })
lua/parley/highlighter.lua:795:    vim.api.nvim_set_hl(0, "ParleyReviewAgent", { link = "DiagnosticInfo" })
lua/parley/highlighter.lua:799:    vim.api.nvim_set_hl(0, "ParleyReviewQuoted", { reverse = true, bold = true })
lua/parley/highlighter.lua:804:    vim.api.nvim_set_hl(0, "ParleyReviewStrike", { strikethrough = true })
lua/parley/highlighter.lua:811:    vim.api.nvim_set_hl(0, "ParleyReviewFlashDelete",
lua/parley/highlighter.lua:813:    vim.api.nvim_set_hl(0, "ParleyReviewFlashInsert",
lua/parley/highlighter.lua:865:-- Conceals [ and ](path), showing 🌿:text with ParleyInlineBranch style.
lua/parley/highlighter.lua:894:                    hl_group = "ParleyInlineBranch",
lua/parley/highlighter.lua:1006:    local gid = _parley.helpers.create_augroup("ParleyBufHandler", { clear = true })
tests/integration/new_chat_spec.lua:1:-- Integration tests for ParleyChatNew / M.cmd.ChatNew
tests/integration/cliproxy_dispatch_spec.lua:127:        -- :ParleyProxy stop is transient — the next dispatch revives it
tests/integration/cliproxy_command_spec.lua:1:-- Integration test for the :ParleyProxy command registration (issue #131).
tests/integration/cliproxy_command_spec.lua:28:describe(":ParleyProxy command", function()
tests/integration/cliproxy_command_spec.lua:30:        assert.equals(2, vim.fn.exists(":ParleyProxy"))
tests/integration/cliproxy_command_spec.lua:35:            vim.cmd("ParleyProxy bogus")
tests/integration/cliproxy_command_spec.lua:44:            vim.cmd("ParleyProxy")
tests/integration/cliproxy_command_spec.lua:57:            vim.cmd("ParleyProxy providers")
tests/integration/cliproxy_command_spec.lua:68:            vim.cmd("ParleyProxy models")
tests/integration/cliproxy_auth_login_spec.lua:2:-- :ParleyProxy login — resolved from parley's oauth-model-alias, not the name.
tests/integration/highlighting_spec.lua:92:        assert.is_true(has_highlight(buf, 0, "ParleyQuestion"),
tests/integration/highlighting_spec.lua:93:            "Expected 'ParleyQuestion' highlight on 💬: line")
tests/integration/highlighting_spec.lua:96:    it("applies ParleyQuestion highlight to continuation lines of a question block", function()
tests/integration/highlighting_spec.lua:103:        assert.is_true(has_highlight(buf, 0, "ParleyQuestion"))
tests/integration/highlighting_spec.lua:104:        assert.is_true(has_highlight(buf, 1, "ParleyQuestion"),
tests/integration/highlighting_spec.lua:105:            "Expected 'ParleyQuestion' highlight on continuation line")
tests/integration/highlighting_spec.lua:108:    it("does NOT apply ParleyQuestion highlight to 🤖: answer lines", function()
tests/integration/highlighting_spec.lua:113:        assert.is_false(has_highlight(buf, 1, "ParleyQuestion"),
tests/integration/highlighting_spec.lua:114:            "Answer line should NOT have ParleyQuestion highlight")
tests/integration/highlighting_spec.lua:127:        assert.is_true(has_highlight(buf, 2, "ParleyThinking"),
tests/integration/highlighting_spec.lua:128:            "Expected 'ParleyThinking' highlight on 📝: line")
tests/integration/highlighting_spec.lua:131:    it("applies ParleyThinking highlight to 🧠: reasoning line", function()
tests/integration/highlighting_spec.lua:137:        assert.is_true(has_highlight(buf, 2, "ParleyThinking"),
tests/integration/highlighting_spec.lua:138:            "Expected 'ParleyThinking' highlight on 🧠: line")
tests/integration/highlighting_spec.lua:151:        assert.is_true(has_highlight(buf, 1, "ParleyFileReference"),
tests/integration/highlighting_spec.lua:152:            "Expected 'ParleyFileReference' highlight on @@ file reference line")
tests/integration/highlighting_spec.lua:155:    it("does NOT apply ParleyFileReference highlight to @@ lines outside question blocks", function()
tests/integration/highlighting_spec.lua:159:        -- Row 0 is an answer line; ParleyFileReference should not be applied
tests/integration/highlighting_spec.lua:160:        assert.is_false(has_highlight(buf, 0, "ParleyFileReference"),
tests/integration/highlighting_spec.lua:161:            "ParleyFileReference should not appear on answer lines")
tests/integration/highlighting_spec.lua:178:        assert.is_true(has_highlight(buf, 3, "ParleyFootnote"),
tests/integration/highlighting_spec.lua:179:            "Expected the managed footer divider to use ParleyFootnote")
tests/integration/highlighting_spec.lua:180:        assert.is_true(has_highlight(buf, 5, "ParleyFootnote"),
tests/integration/highlighting_spec.lua:181:            "Expected the managed footnote definition to use ParleyFootnote")
tests/integration/highlighting_spec.lua:182:        assert.is_false(has_highlight(buf, 3, "ParleyQuestion"),
tests/integration/highlighting_spec.lua:184:        assert.is_false(has_highlight(buf, 5, "ParleyQuestion"),
tests/integration/highlighting_spec.lua:239:            if mark.row == 0 and mark.hl_group == "ParleyQuestion" then
tests/integration/highlighting_spec.lua:242:            if mark.row == 70 and mark.hl_group == "ParleyQuestion" then
tests/integration/highlighting_spec.lua:304:            if mark.hl_group == "ParleyThinking" then
tests/integration/highlighting_spec.lua:310:            "continuation paragraph one should be dimmed (ParleyThinking)")
tests/integration/highlighting_spec.lua:368:            if mark.hl_group == "ParleyThinking" then
tests/integration/highlighting_spec.lua:416:            if mark.hl_group == "ParleyQuestion" then
tests/integration/highlighting_spec.lua:600:    it("renders managed footnote footers with ParleyFootnote in markdown buffers", function()
tests/integration/highlighting_spec.lua:630:            if mark.hl_group == "ParleyFootnote" then
tests/integration/highlighting_spec.lua:634:        assert.is_true(highlighted[2], "Expected markdown footer divider to use ParleyFootnote")
tests/integration/highlighting_spec.lua:635:        assert.is_true(highlighted[4], "Expected markdown footnote definition to use ParleyFootnote")
tests/unit/super_repo_spec.lua:558:    it("fires User ParleySuperRepoChanged on toggle on and off", function()
tests/unit/super_repo_spec.lua:560:        local augroup = vim.api.nvim_create_augroup("ParleySuperRepoSpec", { clear = true })
tests/unit/super_repo_spec.lua:563:            pattern = "ParleySuperRepoChanged",

exec
/bin/zsh -lc "rg -n \"highlight|ParleyFootnote|ParleyReference|DiagnosticHint|footnote\" README.md doc lua/parley tests atlas -g '"'!workshop/history/**'"'" in /Users/xianxu/workspace/parley.nvim
 exited 2 in 0ms:
rg: doc: No such file or directory (os error 2)
README.md:118:- `<M-CR>` respond (normal/insert); **visual-select a phrase + `<M-CR>`** → inline term definition — adds a markdown footnote reference/footer and shows a centered diagnostic float, honoring `:ToggleWebSearch` for unfamiliar terms
README.md:147:- Outline navigation, highlighting.
README.md:160:- Most other top-level keys are replaced when provided (for example `chat_dir`, `chat_dirs`, `notes_dir`, `chat_template`, `raw_mode`, `highlight`, `chat_memory`, `providers`, `api_keys`).
atlas/skills/skill-system.md:44:- `lua/parley/skill_render.lua` — the single source of `clear_decorations`/`attach_diagnostics`/`highlight_edits` (salvaged from `skill_runner`).
atlas/skills/skill-system.md:118:- `lua/parley/skill_render.lua` — diagnostics/highlights (single source; was salvaged from skill_runner)
atlas/index.md:15:- [Inline Term Definition](chat/inline_define.md): Visual-select a phrase + `<M-CR>` → concise context-aware definition as a managed footnote diagnostic rehydrated for markdown buffers (the `define` skill + `emit_definition` tool; honors `:ToggleWebSearch`).
atlas/index.md:31:- [Artifact-Ref Navigation](context/artifact_refs.md): Jump from `ariadne#11` / `#15 M4` / `pair#84` under the cursor to its current file (shells to `sdlc resolve`; loose local detector, sdlc owns the grammar); smart `gf` + `ParleyArtifactRef` highlight.
atlas/index.md:48:- [Syntax Highlighting](ui/highlights.md): Highlighting groups and rules.
atlas/index.md:62:- [Interview Mode](modes/interview.md): Mechanics, automatic timestamps, and `{thought}` highlighting.
atlas/traceability.yaml:71:      - lua/parley/highlighter.lua
atlas/traceability.yaml:81:      - lua/parley/highlighter.lua
atlas/traceability.yaml:85:      - tests/unit/highlighter_spec.lua
atlas/traceability.yaml:106:      - lua/parley/highlighter.lua
atlas/traceability.yaml:422:  ui/highlights:
atlas/traceability.yaml:425:      - lua/parley/highlighter.lua
atlas/traceability.yaml:429:      - tests/integration/highlighting_spec.lua
lua/parley/define.lua:138:--- Convert a term into a stable markdown footnote id.
lua/parley/define.lua:141:function M.footnote_id(term)
lua/parley/define.lua:154:function M.format_footnote_line(id, definition)
lua/parley/define.lua:166:local function is_footnote_line(line)
lua/parley/define.lua:173:            local has_footnote = false
lua/parley/define.lua:177:                    if not is_footnote_line(line) then
lua/parley/define.lua:180:                    has_footnote = true
lua/parley/define.lua:183:            if has_footnote then
lua/parley/define.lua:192:--- Locate the final managed definition-footnote footer.
lua/parley/define.lua:195:function M.managed_footnote_footer_range(lines)
lua/parley/define.lua:204:local function parse_footnote_line(line)
lua/parley/define.lua:228:--- Derive persisted definition diagnostics from inline footnote references and
lua/parley/define.lua:232:function M.footnote_diagnostics(lines)
lua/parley/define.lua:241:        local id, definition = parse_footnote_line(lines[i] or "")
lua/parley/define.lua:303:--- Strip a final managed definition-footnote footer from text.
lua/parley/define.lua:306:function M.strip_definition_footnote_footer(text)
lua/parley/define.lua:325:local function replace_or_append_footnote(lines, id, definition)
lua/parley/define.lua:328:    local footnote_line = M.format_footnote_line(id, definition)
lua/parley/define.lua:333:                out[i] = footnote_line
lua/parley/define.lua:337:        out[#out + 1] = footnote_line
lua/parley/define.lua:347:    out[#out + 1] = footnote_line
lua/parley/define.lua:351:--- Insert a markdown footnote reference after the selected text and store the
lua/parley/define.lua:361:function M.apply_definition_footnote(lines, l1, c1, l2, c2, term, definition)
lua/parley/define.lua:362:    local id = M.footnote_id(term)
lua/parley/define.lua:378:    out = replace_or_append_footnote(out, id, definition)
atlas/providers/agents.md:9:- Virtual text on first chat line: `[AgentName]`. Indicator badges render as a single `[...]` group appended after the name: `🔧` when `tools` is non-empty, `🌎` when web_search is enabled and supported (`🌎?` when unsupported). Combined example: `ToolSonnet[🔧🌎]`. Helpers `highlighter.agent_tool_badge` / `agent_web_search_badge` are the single source, shared by picker, lualine, and the buffer-top extmark.
lua/parley/oauth.lua:42:-- Filetype hints for syntax highlighting in code fences
lua/parley/skill_render.lua:3:-- The diagnostics/highlights rendering salvaged out of skill_runner (#128 M3),
lua/parley/skill_render.lua:6:-- edit's `explain`, DiffChange highlights on edited regions.
lua/parley/skill_render.lua:12:local FOOTNOTE_SOURCE = "parley-footnote"
lua/parley/skill_render.lua:26:--- Clear previous skill diagnostics and highlights from a buffer.
lua/parley/skill_render.lua:106:local function is_footnote_diagnostic(diagnostic)
lua/parley/skill_render.lua:108:    return diagnostic.source == FOOTNOTE_SOURCE or user_data.parley_kind == "footnote"
lua/parley/skill_render.lua:111:--- Rehydrate persisted managed markdown footnotes into Parley diagnostics.
lua/parley/skill_render.lua:112:--- Existing non-footnote diagnostics in the shared namespace are preserved.
lua/parley/skill_render.lua:114:function M.refresh_footnote_diagnostics(buf)
lua/parley/skill_render.lua:127:        if not is_footnote_diagnostic(existing) then
lua/parley/skill_render.lua:132:    for _, footnote in ipairs(define.footnote_diagnostics(lines)) do
lua/parley/skill_render.lua:134:            lnum = footnote.lnum,
lua/parley/skill_render.lua:135:            col = footnote.col,
lua/parley/skill_render.lua:136:            end_lnum = footnote.end_lnum or footnote.lnum,
lua/parley/skill_render.lua:137:            end_col = footnote.end_col,
lua/parley/skill_render.lua:138:            message = define.format_definition(footnote.term or footnote.id, footnote.definition, width),
lua/parley/skill_render.lua:141:            user_data = { parley_kind = "footnote" },
lua/parley/skill_render.lua:186:function M.highlight_edits(buf, edits, new_content)
lua/parley/skill_render.lua:190:        -- would spuriously highlight line 0. Deletions are oriented by their
lua/parley/skill_render.lua:192:        -- highlight (there's no new text to mark). #133.
lua/parley/skill_render.lua:206:                vim.api.nvim_buf_add_highlight(buf, hl_ns_id, "DiffChange", line, 0, -1)
lua/parley/skill_render.lua:217:function M.highlight_line(buf, lnum0)
lua/parley/skill_render.lua:219:    vim.api.nvim_buf_add_highlight(buf, hl_ns_id, "DiffChange", lnum0, 0, -1)
lua/parley/skill_render.lua:230:function M.highlight_span(buf, lnum0, col_start, end_lnum0_or_col_end, col_end)
lua/parley/skill_render.lua:247:--- projection record, #133 M5). Whole-line highlights stay in `hl_lines`; span
lua/parley/skill_render.lua:248:--- highlights and diagnostics preserve columns so exact anchors can be restored.
lua/parley/skill_render.lua:290:        vim.api.nvim_buf_add_highlight(buf, hl_ns_id, "DiffChange", line, 0, -1)
lua/parley/skill_render.lua:293:        M.highlight_span(buf, span.lnum, span.col or 0, span.end_lnum or span.lnum, span.end_col)
atlas/providers/tool_use.md:77:- 🔧:/📎: blocks are dimmed (`ParleyThinking` highlight = `Comment`)
atlas/providers/tool_use.md:78:- Error results highlighted with `ParleyToolError` = `DiagnosticError`
atlas/ui/highlights.md:4:Custom groups (`ParleyQuestion`, `ParleyFileReference`, `ParleyChatReference`, `ParleyThinking`, `ParleyAnnotation`, `ParleyReference`, `ParleyFootnote`, `ParleyPickerApproximateMatch`, `InterviewTimestamp`, `InterviewThought`) linked to standard Neovim groups. `ParleyReference` (default underline) marks drill-in `[referenced span]` brackets — see [chat/drill_in](../chat/drill_in.md). `ParleyFootnote` (default `DiagnosticHint`) marks managed definition-footnote footer lines.
atlas/ui/highlights.md:9:- Managed definition-footnote footers (`---` + `[^id]: ...`) use
atlas/ui/highlights.md:10:  `ParleyFootnote` in chat and markdown buffers instead of inheriting the active
atlas/ui/highlights.md:16:  lives in `lua/parley/timezone_diagnostics.lua`; `highlighter.setup_buf_handler`
atlas/chat/drill_in.md:49:     enclosed spans are highlighted `ParleyReference` (see Anchor inference).
atlas/chat/drill_in.md:126:**Referenced-span brackets + highlight.** `generate_snippet` also returns the
atlas/chat/drill_in.md:133:delimit it). The highlighter colors these spans `ParleyReference` (default
atlas/chat/drill_in.md:134:underline; `config.highlight.reference` overrides) via a per-line matcher that
atlas/chat/drill_in.md:135:skips markdown links `](`, checkboxes, footnote refs, and 1-char content — a
lua/parley/float_picker.lua:662:    vim.wo[results_win].winhighlight = "CursorLine:PmenuSel"
lua/parley/float_picker.lua:712:        -- Define highlight groups (default=true makes each call idempotent)
lua/parley/float_picker.lua:770:        -- Apply highlights
lua/parley/float_picker.lua:779:            vim.api.nvim_buf_add_highlight(tag_bar_buf, TAG_BAR_NS, hl,
lua/parley/float_picker.lua:1019:    local function highlight_matches(query)
lua/parley/float_picker.lua:1032:                        vim.api.nvim_buf_add_highlight(
lua/parley/float_picker.lua:1042:                        vim.api.nvim_buf_add_highlight(
lua/parley/float_picker.lua:1146:        highlight_matches(query)
lua/parley/float_picker.lua:1470:            highlight_matches(query_text:gsub("^%s+", ""))
lua/parley/agent_picker.lua:18:        -- web search (M1 Task 1.7 of #81). Reuse the highlighter helpers
lua/parley/agent_picker.lua:21:        -- failure in parley.highlighter should surface loudly, not silently
lua/parley/agent_picker.lua:24:        local highlighter = require("parley.highlighter")
lua/parley/agent_picker.lua:25:        local tool_part = highlighter.agent_tool_badge(agent) or ""
lua/parley/agent_picker.lua:26:        local ok_ws, web_part = pcall(highlighter.agent_web_search_badge, agent)
atlas/chat/inline_define.md:5:phrase. The selected text stays in place and gets a markdown footnote reference
atlas/chat/inline_define.md:6:(`ASIN[^asin]`), while the definition is stored in a managed footnote footer at
atlas/chat/inline_define.md:7:the end of the chat transcript. Persisted managed footnotes are rehydrated into
atlas/chat/inline_define.md:9:annotation is **undoable** — `u` reverts the footnote edit and clears both
atlas/chat/inline_define.md:13:highlight/undo); [#166](../../workshop/issues/000166-visual-selection-definition-system-manages-footnote.md)
atlas/chat/inline_define.md:14:made the definition durable as a managed footnote; [#167](../../workshop/issues/000167-define-diagnostic-highlight-span.md)
atlas/chat/inline_define.md:15:narrowed the visible decoration to the selected term plus footnote reference;
atlas/chat/inline_define.md:16:[#172](../../workshop/issues/000172-markdown-footnote-diagnostics.md)
atlas/chat/inline_define.md:17:rehydrates persisted managed footnotes in all markdown buffers.
atlas/chat/inline_define.md:35:   and inserts/updates a final managed footnote footer via one buffer rewrite
atlas/chat/inline_define.md:36:   (`define.apply_definition_footnote`) — a single undo entry that anchors
atlas/chat/inline_define.md:37:   everything; **(b)** highlights the selected term/reference span with
atlas/chat/inline_define.md:38:   `DiffChange` (`skill_render.highlight_span`); **(c)** refreshes persisted
atlas/chat/inline_define.md:39:   footnote diagnostics (`skill_render.refresh_footnote_diagnostics`), which
atlas/chat/inline_define.md:45:   cursor is on the term/footnote anchor span. A no-`emit_definition` response
atlas/chat/inline_define.md:46:   leaves no footnote reference/footer.
atlas/chat/inline_define.md:50:Native `u` reverts *text*, not decorations. The footnote reference/footer rewrite
atlas/chat/inline_define.md:54:(pre-footnote hash → empty snapshot), `record(buf)` (footnoted hash → the
atlas/chat/inline_define.md:55:highlight + diagnostic), `ensure_watch(buf)`. Undoing the footnote edit lands on
atlas/chat/inline_define.md:56:the pre-footnote content-hash → the empty snapshot renders → both decorations clear;
atlas/chat/inline_define.md:58:highlights (`hl_spans`) and diagnostic `col`/`end_col`, while still accepting
atlas/chat/inline_define.md:67:  mapping), `apply_definition_footnote` (durable footer transform), and
atlas/chat/inline_define.md:68:  `strip_definition_footnote_footer` / `footnote_diagnostics` (read only a final
atlas/chat/inline_define.md:69:  `---` block followed solely by footnotes).
atlas/chat/inline_define.md:71:  `lua/parley/buffer_edit.lua` owns the full-buffer footnote rewrite;
atlas/chat/inline_define.md:72:  `lua/parley/skill_render.lua` publishes footnote diagnostics; and
atlas/chat/inline_define.md:73:  `lua/parley/highlighter.lua` refreshes them from chat and markdown lifecycle
atlas/chat/inline_define.md:89:`---` line followed by blank lines and footnote definitions counts as the
atlas/chat/inline_define.md:93:prompt context. `define.footnote_diagnostics` uses the same footer detector to
atlas/chat/inline_define.md:124:- The fresh define highlight spans the selected text plus immediate `[^id]`
atlas/chat/inline_define.md:125:  reference; rehydrated diagnostics do not recreate the DiffChange highlight.
atlas/chat/inline_define.md:126:- `skill_render.refresh_footnote_diagnostics` owns only diagnostics tagged
atlas/chat/inline_define.md:127:  `parley-footnote` and preserves other `parley_skill` diagnostics, so review
atlas/chat/inline_define.md:128:  diagnostics are not cleared by markdown footnote refresh.
atlas/chat/inline_define.md:129:- A footnote diagnostic's Parley float auto-hides when the cursor leaves its
atlas/chat/inline_define.md:130:  term/footnote anchor span. The footnote persists in the file if saved.
atlas/chat/inline_define.md:134:- `lua/parley/define.lua` — pure core (slice / context / format / footnote footer / diagnostics).
atlas/chat/inline_define.md:136:- `lua/parley/highlighter.lua` — chat/markdown buffer lifecycle refresh hooks.
atlas/chat/inline_define.md:137:- `lua/parley/skill_render.lua` — footnote diagnostic refresh in the shared namespace.
atlas/chat/inline_define.md:138:- `lua/parley/chat_respond.lua` — strips managed footnote footer from LLM messages.
lua/parley/review.lua:6:--   - Diagnostics / highlights: lua/parley/skill_render.lua
lua/parley/review.lua:10:-- (tests, highlighter.lua, init.lua) continue to work unchanged. (The v1
lua/parley/review.lua:39:-- Lazy property for _parse_marker_sections (used by highlighter.lua)
tests/unit/highlighter_spec.lua:1:-- Unit tests for lua/parley/highlighter.lua pure predicates.
tests/unit/highlighter_spec.lua:3:local highlighter = require("parley.highlighter")
tests/unit/highlighter_spec.lua:6:-- compute_markdown_highlights calls it. `match` returns the first run's
tests/unit/highlighter_spec.lua:13:    return highlighter.is_reference_span(line, s, content, e)
tests/unit/highlighter_spec.lua:16:describe("highlighter.is_reference_span (#127)", function()
tests/unit/highlighter_spec.lua:27:    it("rejects a footnote reference", function()
atlas/ui/outline.md:24:- Standard `float_picker` (results + prompt), fuzzy filter with highlights
atlas/ui/outline.md:25:- Single click selects; double-click/`<CR>` confirms with highlight flash
tests/integration/review_diag_display_spec.lua:54:    it("renders footnote diagnostics in a centered non-focusable float without moving the diagnostic span", function()
tests/integration/review_diag_display_spec.lua:74:            source = "parley-footnote",
tests/integration/review_diag_display_spec.lua:105:    it("shows footnote diagnostics only while the cursor is inside the anchor span", function()
tests/integration/review_diag_display_spec.lua:122:            source = "parley-footnote",
tests/integration/review_diag_display_spec.lua:124:        assert.are.equal(0, #display_marks(buf), "cursor starts before the footnote anchor")
tests/integration/review_diag_display_spec.lua:128:        assert.are.equal(1, #diagnostic_floats(), "cursor inside the footnote anchor should show diagnosis")
lua/parley/dispatcher.lua:433:    vim.cmd("highlight default link " .. hl_handler_group .. " CursorLine")
lua/parley/dispatcher.lua:531:            vim.api.nvim_buf_add_highlight(buf, qt.ns_id, hl_handler_group, first_line + i, 0, -1)
tests/unit/spell_spec.lua:55:        it("accepts the highlighted item when a selection exists", function()
tests/integration/define_spec.lua:244:    it("stores the definition as a durable footnote, highlights the term/reference span, and shows the diagnostic", function()
tests/integration/define_spec.lua:267:        -- DiffChange highlight covers only ASIN[^asin], not the whole paragraph.
tests/integration/define_spec.lua:269:        assert.is_not_nil(mark, "term/reference span not highlighted")
tests/integration/define_spec.lua:310:    it("re-defining a footnoted term updates the footer without duplicating the inline reference", function()
tests/integration/define_spec.lua:342:    it("u undoes the footnote edit + clears decorations; C-r restores them (R1)", function()
tests/integration/define_spec.lua:352:        -- undo: the footnote edit reverts; the projection watcher (TextChanged) clears
tests/integration/define_spec.lua:361:            :find("%[%^asin%]:", 1, false), "footnote not removed on undo")
tests/integration/define_spec.lua:364:        assert.is_false(hl_on_line(buf, 2), "highlight not cleared on undo")
tests/integration/define_spec.lua:366:        -- redo: footnote edit + decorations return
tests/integration/define_spec.lua:372:        assert.is_not_nil(redone_mark, "highlight not restored on redo")
tests/integration/define_spec.lua:382:        assert.is_true(hl_on_line(buf, 2), "highlight not restored on redo")
tests/integration/define_spec.lua:412:            "a no-tool response must not footnote the term")
tests/integration/highlighting_spec.lua:1:-- Integration tests for M.highlight_question_block
tests/integration/highlighting_spec.lua:3:-- Verifies that the correct highlight groups are applied to the correct lines
tests/integration/highlighting_spec.lua:4:-- in a chat buffer after calling highlight_question_block(buf).
tests/integration/highlighting_spec.lua:6:-- We query applied highlights via vim.api.nvim_buf_get_extmarks with the
tests/integration/highlighting_spec.lua:9:local tmp_dir = vim.fn.tempname() .. "-parley-highlight"
tests/integration/highlighting_spec.lua:20:-- Helper: create a scratch buffer with the given lines and apply highlighting.
tests/integration/highlighting_spec.lua:21:local function highlighted_buf(lines)
tests/integration/highlighting_spec.lua:24:    parley.highlight_question_block(buf)
tests/integration/highlighting_spec.lua:28:-- Helper: get the highlight group name applied at (0-indexed) row in buf,
tests/integration/highlighting_spec.lua:31:local function get_highlights_on_line(buf, row)
tests/integration/highlighting_spec.lua:46:local function has_highlight(buf, row, group)
tests/integration/highlighting_spec.lua:47:    local groups = get_highlights_on_line(buf, row)
tests/integration/highlighting_spec.lua:85:describe("highlight_question_block: question lines", function()
tests/integration/highlighting_spec.lua:87:    it("applies Question highlight to 💬: line (row 0)", function()
tests/integration/highlighting_spec.lua:88:        local buf = highlighted_buf({
tests/integration/highlighting_spec.lua:92:        assert.is_true(has_highlight(buf, 0, "ParleyQuestion"),
tests/integration/highlighting_spec.lua:93:            "Expected 'ParleyQuestion' highlight on 💬: line")
tests/integration/highlighting_spec.lua:96:    it("applies ParleyQuestion highlight to continuation lines of a question block", function()
tests/integration/highlighting_spec.lua:97:        local buf = highlighted_buf({
tests/integration/highlighting_spec.lua:103:        assert.is_true(has_highlight(buf, 0, "ParleyQuestion"))
tests/integration/highlighting_spec.lua:104:        assert.is_true(has_highlight(buf, 1, "ParleyQuestion"),
tests/integration/highlighting_spec.lua:105:            "Expected 'ParleyQuestion' highlight on continuation line")
tests/integration/highlighting_spec.lua:108:    it("does NOT apply ParleyQuestion highlight to 🤖: answer lines", function()
tests/integration/highlighting_spec.lua:109:        local buf = highlighted_buf({
tests/integration/highlighting_spec.lua:113:        assert.is_false(has_highlight(buf, 1, "ParleyQuestion"),
tests/integration/highlighting_spec.lua:114:            "Answer line should NOT have ParleyQuestion highlight")
tests/integration/highlighting_spec.lua:118:describe("highlight_question_block: thinking lines", function()
tests/integration/highlighting_spec.lua:121:    it("applies Think highlight to 📝: summary line", function()
tests/integration/highlighting_spec.lua:122:        local buf = highlighted_buf({
tests/integration/highlighting_spec.lua:127:        assert.is_true(has_highlight(buf, 2, "ParleyThinking"),
tests/integration/highlighting_spec.lua:128:            "Expected 'ParleyThinking' highlight on 📝: line")
tests/integration/highlighting_spec.lua:131:    it("applies ParleyThinking highlight to 🧠: reasoning line", function()
tests/integration/highlighting_spec.lua:132:        local buf = highlighted_buf({
tests/integration/highlighting_spec.lua:137:        assert.is_true(has_highlight(buf, 2, "ParleyThinking"),
tests/integration/highlighting_spec.lua:138:            "Expected 'ParleyThinking' highlight on 🧠: line")
tests/integration/highlighting_spec.lua:142:describe("highlight_question_block: file reference lines", function()
tests/integration/highlighting_spec.lua:145:    it("applies FileLoading highlight to @@ file reference lines in a question block", function()
tests/integration/highlighting_spec.lua:146:        local buf = highlighted_buf({
tests/integration/highlighting_spec.lua:151:        assert.is_true(has_highlight(buf, 1, "ParleyFileReference"),
tests/integration/highlighting_spec.lua:152:            "Expected 'ParleyFileReference' highlight on @@ file reference line")
tests/integration/highlighting_spec.lua:155:    it("does NOT apply ParleyFileReference highlight to @@ lines outside question blocks", function()
tests/integration/highlighting_spec.lua:156:        local buf = highlighted_buf({
tests/integration/highlighting_spec.lua:160:        assert.is_false(has_highlight(buf, 0, "ParleyFileReference"),
tests/integration/highlighting_spec.lua:165:describe("highlight_question_block: managed footnote footer", function()
tests/integration/highlighting_spec.lua:168:    it("uses a dedicated footnote highlight instead of open-question coloring", function()
tests/integration/highlighting_spec.lua:169:        local buf = highlighted_buf({
tests/integration/highlighting_spec.lua:178:        assert.is_true(has_highlight(buf, 3, "ParleyFootnote"),
tests/integration/highlighting_spec.lua:179:            "Expected the managed footer divider to use ParleyFootnote")
tests/integration/highlighting_spec.lua:180:        assert.is_true(has_highlight(buf, 5, "ParleyFootnote"),
tests/integration/highlighting_spec.lua:181:            "Expected the managed footnote definition to use ParleyFootnote")
tests/integration/highlighting_spec.lua:182:        assert.is_false(has_highlight(buf, 3, "ParleyQuestion"),
tests/integration/highlighting_spec.lua:184:        assert.is_false(has_highlight(buf, 5, "ParleyQuestion"),
tests/integration/highlighting_spec.lua:185:            "Managed footnote definition should not inherit open-question color")
tests/integration/highlighting_spec.lua:195:    it("keeps highlight caches isolated per window for the same buffer", function()
tests/integration/highlighting_spec.lua:247:        assert.is_true(saw_top, "expected first split to keep its own viewport highlight cache")
tests/integration/highlighting_spec.lua:248:        assert.is_true(saw_bottom, "expected second split to keep its own viewport highlight cache")
tests/integration/highlighting_spec.lua:321:        -- for this buffer, the highlighter assumes explicit-end mode
tests/integration/highlighting_spec.lua:380:    it("restores question highlights when redraw starts inside a long unanswered question", function()
tests/integration/highlighting_spec.lua:414:        local highlighted_rows = {}
tests/integration/highlighting_spec.lua:417:                highlighted_rows[mark.row] = true
tests/integration/highlighting_spec.lua:421:        assert.is_true(highlighted_rows[220] == true,
tests/integration/highlighting_spec.lua:422:            "expected question highlight when redraw begins inside a long unanswered question")
tests/integration/highlighting_spec.lua:423:        assert.is_true(highlighted_rows[235] == true,
tests/integration/highlighting_spec.lua:424:            "expected continuation lines in the viewport to keep question highlight state")
tests/integration/highlighting_spec.lua:512:describe("markdown footnote diagnostics", function()
tests/integration/highlighting_spec.lua:525:    it("publishes persisted managed footnotes as Parley diagnostics", function()
tests/integration/highlighting_spec.lua:536:        skill_render.refresh_footnote_diagnostics(buf)
tests/integration/highlighting_spec.lua:543:        assert.equals("parley-footnote", diagnostics[1].source)
tests/integration/highlighting_spec.lua:548:    it("refreshes footnote diagnostics on markdown text changes without clearing other Parley diagnostics", function()
tests/integration/highlighting_spec.lua:555:            "no footnote yet",
tests/integration/highlighting_spec.lua:589:        assert.is_not_nil(by_source["parley-footnote"])
tests/integration/highlighting_spec.lua:590:        assert.equals(8, by_source["parley-footnote"].col)
tests/integration/highlighting_spec.lua:592:        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "footnote removed" })
tests/integration/highlighting_spec.lua:600:    it("renders managed footnote footers with ParleyFootnote in markdown buffers", function()
tests/integration/highlighting_spec.lua:628:        local highlighted = {}
tests/integration/highlighting_spec.lua:630:            if mark.hl_group == "ParleyFootnote" then
tests/integration/highlighting_spec.lua:631:                highlighted[mark.row] = true
tests/integration/highlighting_spec.lua:634:        assert.is_true(highlighted[2], "Expected markdown footer divider to use ParleyFootnote")
tests/integration/highlighting_spec.lua:635:        assert.is_true(highlighted[4], "Expected markdown footnote definition to use ParleyFootnote")
tests/integration/highlighting_spec.lua:664:        parley.highlight_chat_branch_refs(buf)
tests/integration/highlighting_spec.lua:689:        parley.highlight_chat_branch_refs(buf)
tests/integration/highlighting_spec.lua:727:        parley.highlight_chat_branch_refs(buf)
lua/parley/exporter.lua:611:        /* Inline branch links (footnote-style) */
lua/parley/exporter.lua:642:        /* Syntax highlighting overrides */
lua/parley/exporter.lua:686:    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css">
lua/parley/exporter.lua:687:    <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
lua/parley/exporter.lua:688:    <script>hljs.highlightAll();</script>
tests/arch/buffer_mutation_spec.lua:40:                "lua/parley/highlighter.lua",
lua/parley/interview.lua:3:-- Interview mode: timestamp insertion, highlighting, and timer management
lua/parley/interview.lua:13:-- Track match IDs per buffer for interview timestamp highlighting
lua/parley/interview.lua:101:--- Add (or refresh) syntax highlighting for interview timestamp lines in a buffer.
lua/parley/interview.lua:103:M.highlight_timestamps = function(buf)
lua/parley/interview.lua:116:    -- Add highlighting for the entire timestamp line with very low priority (-1)
lua/parley/interview.lua:117:    -- to ensure all search highlights (incsearch, Search, CurSearch) can take precedence
lua/parley/interview.lua:121:    -- Add highlighting for {thought} blocks — interviewer's private thoughts
atlas/context/artifact_refs.md:4:`#15 M4`, `pair#84`, `gh#42` — to the current file it names, and highlight refs
atlas/context/artifact_refs.md:15:open/pick the result, highlight refs.
atlas/context/artifact_refs.md:19:    cursor extraction + highlighting). It is NOT the grammar; an over-match is
atlas/context/artifact_refs.md:21:    and the highlighter so the ref-shape lives once (ARCH-DRY).
atlas/context/artifact_refs.md:32:  provider (`highlighter.lua`, shared `push_artifact_refs` in both the chat and
atlas/context/artifact_refs.md:33:  markdown compute paths). Override via `config.highlight.artifact_ref`. Marks
tests/integration/timer_race_spec.lua:108:        parley.highlight_chat_branch_refs(buf)
tests/integration/timer_race_spec.lua:109:        parley.highlight_chat_branch_refs(buf)
atlas/chat/spell_typeahead.md:24:**`<CR>` handling.** Under `noselect` nothing is auto-highlighted, so a bare
atlas/chat/spell_typeahead.md:31:| yes   | yes       | `<C-y>`     | accept the highlighted item    |
lua/parley/root_dir_picker.lua:59:---   initial_dir   — dir to highlight initially; optional
lua/parley/spell.lua:57:-- live popup. Under `completeopt=noselect` nothing is ever auto-highlighted, so
lua/parley/spell.lua:62:--   popup + selection   → <C-y>        accept the highlighted item
lua/parley/spell.lua:68:---@param has_selection boolean # is an item highlighted
lua/parley/lualine.lua:273:      -- web search (M1 Task 1.7 of #81). Reuse the highlighter helpers so
lua/parley/lualine.lua:277:      local highlighter = require("parley.highlighter")
lua/parley/lualine.lua:279:      local indicators = highlighter.agent_tool_badge(agent_conf)
lua/parley/lualine.lua:280:        .. highlighter.agent_web_search_badge(agent_conf)
lua/parley/lualine.lua:299:        -- ErrorMsg is the conventional red highlight group; if the colorscheme
lua/parley/lualine.lua:340:    -- Use the hint highlight group for consistency with the in-buffer display
lua/parley/lualine.lua:346:      -- Use highlight group names without explicitly specifying fg
lua/parley/lualine.lua:351:        return "DiagnosticHint"
tests/integration/review_projection_spec.lua:36:        skill_render.highlight_edits(buf, { { new_string = "reviewed" } }, content)
lua/parley/buffer_edit.lua:117:--- Replace the entire chat buffer after a pure definition-footnote transform.
lua/parley/artifact_ref.lua:4:-- owns a *loose* ref-shape detector (for cursor extraction + highlighting) and
lua/parley/artifact_ref.lua:10:-- iter_refs, parse_ref_at_cursor, parse_resolve_output, highlight_spans,
lua/parley/artifact_ref.lua:12:-- behind an injected runner). The editor wiring (highlight/keymap/picker) lives in
lua/parley/artifact_ref.lua:13:-- highlighter.lua / keybinding_registry.lua / init.lua.
lua/parley/artifact_ref.lua:57:-- highlight_spans(line) -> { { col_start, col_end }, ... }: the 0-indexed extmark
lua/parley/artifact_ref.lua:59:-- nvim_buf_add_highlight/decoration convention). iter_refs' byte_end is one-past
lua/parley/artifact_ref.lua:61:-- the col math the highlighter's push_artifact_refs consumes (so it's tested).
lua/parley/artifact_ref.lua:62:function M.highlight_spans(line)
lua/parley/tools/builtin/propose_edits.lua:13:-- diagnostics/highlights rendering stays driver-side (M3), not here.
lua/parley/progress.lua:68:        vim.wo[win].winhighlight = "Normal:StatusLine" -- read as a bar
lua/parley/highlighter.lua:2:-- Buffer decoration provider, highlight group setup, and agent display logic.
lua/parley/highlighter.lua:19:-- so this highlights ref-*shaped* tokens (a jump on an unresolvable one just
lua/parley/highlighter.lua:24:    for _, span in ipairs(artifact_ref.highlight_spans(line)) do
lua/parley/highlighter.lua:70:local function get_chat_highlight_prefix_patterns()
lua/parley/highlighter.lua:105:-- (blank lines inside the block stay highlighted as ParleyThinking).
lua/parley/highlighter.lua:111:-- their dim highlight whenever the viewport top fell between 🧠: and
lua/parley/highlighter.lua:135:local function bootstrap_chat_highlight_state(buf, start_line, patterns, streaming)
lua/parley/highlighter.lua:262:-- Compute desired chat highlights for a 1-indexed line range.
lua/parley/highlighter.lua:265:local function compute_chat_highlights(buf, start_line, end_line)
lua/parley/highlighter.lua:267:    local patterns = get_chat_highlight_prefix_patterns()
lua/parley/highlighter.lua:270:    local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
lua/parley/highlighter.lua:274:    -- their dim highlight instead of prematurely terminating the
lua/parley/highlighter.lua:280:        bootstrap_chat_highlight_state(buf, start_line, patterns, streaming)
lua/parley/highlighter.lua:294:        local highlighted_regions = {}
lua/parley/highlighter.lua:303:            table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
lua/parley/highlighter.lua:312:                table.insert(highlighted_regions, { start = tag_start, finish = tag_end })
lua/parley/highlighter.lua:319:            -- highlight tracks parse boundaries even when the model omits
lua/parley/highlighter.lua:351:                -- the top of compute_chat_highlights).
lua/parley/highlighter.lua:395:                    if #highlighted_regions > 0 and highlighted_regions[1].start == 1 then
lua/parley/highlighter.lua:448:--   * footnote refs                 — `[^1]`
lua/parley/highlighter.lua:451:--                                     prior `]`/`}` close (already highlighted
lua/parley/highlighter.lua:464:-- Compute desired markdown highlights for a 1-indexed line range.
lua/parley/highlighter.lua:466:local function compute_markdown_highlights(buf, start_line, end_line)
lua/parley/highlighter.lua:471:    local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
lua/parley/highlighter.lua:478:            table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
lua/parley/highlighter.lua:523:        -- #127: highlight drill-in referenced-span markers `[…]` left in the
lua/parley/highlighter.lua:531:                        hl_group = "ParleyReference",
lua/parley/highlighter.lua:542:    -- body lines. Bg-only highlight; markdown fg shows through.
lua/parley/highlighter.lua:574:--- highlighter, and the agent picker.
lua/parley/highlighter.lua:656:            { "[" .. display_name .. "]", "DiagnosticHint" },
lua/parley/highlighter.lua:662:-- Define namespace and highlighting colors for questions, annotations, and thinking
lua/parley/highlighter.lua:663:M.setup_highlights = function()
lua/parley/highlighter.lua:667:    -- Create theme-agnostic highlight groups that work in both light and dark themes
lua/parley/highlighter.lua:668:    -- Check for user-defined highlight settings
lua/parley/highlighter.lua:669:    local user_highlights = _parley.config.highlight or {}
lua/parley/highlighter.lua:671:    -- Questions - Create a highlight that stands out but works in both themes
lua/parley/highlighter.lua:672:    -- Link to existing highlights when possible for theme compatibility
lua/parley/highlighter.lua:673:    if user_highlights.question then
lua/parley/highlighter.lua:674:        -- Use user-defined highlighting if provided
lua/parley/highlighter.lua:675:        vim.api.nvim_set_hl(0, "ParleyQuestion", user_highlights.question)
lua/parley/highlighter.lua:683:    if user_highlights.file_reference then
lua/parley/highlighter.lua:684:        vim.api.nvim_set_hl(0, "ParleyFileReference", user_highlights.file_reference)
lua/parley/highlighter.lua:692:    if user_highlights.thinking then
lua/parley/highlighter.lua:693:        vim.api.nvim_set_hl(0, "ParleyThinking", user_highlights.thinking)
lua/parley/highlighter.lua:701:    if user_highlights.tool_error then
lua/parley/highlighter.lua:702:        vim.api.nvim_set_hl(0, "ParleyToolError", user_highlights.tool_error)
lua/parley/highlighter.lua:709:    -- Annotations - Use existing highlight groups that work across themes
lua/parley/highlighter.lua:710:    if user_highlights.annotation then
lua/parley/highlighter.lua:711:        vim.api.nvim_set_hl(0, "ParleyAnnotation", user_highlights.annotation)
lua/parley/highlighter.lua:719:    if user_highlights.chat_reference then
lua/parley/highlighter.lua:720:        vim.api.nvim_set_hl(0, "ParleyChatReference", user_highlights.chat_reference)
lua/parley/highlighter.lua:728:    if user_highlights.inline_branch then
lua/parley/highlighter.lua:729:        vim.api.nvim_set_hl(0, "ParleyInlineBranch", user_highlights.inline_branch)
lua/parley/highlighter.lua:740:    -- config.highlight.reference.
lua/parley/highlighter.lua:741:    if user_highlights.reference then
lua/parley/highlighter.lua:742:        vim.api.nvim_set_hl(0, "ParleyReference", user_highlights.reference)
lua/parley/highlighter.lua:744:        vim.api.nvim_set_hl(0, "ParleyReference", { underline = true })
lua/parley/highlighter.lua:747:    -- Managed definition-footnote footer (`---` + `[^id]: ...`). It must be
lua/parley/highlighter.lua:749:    if user_highlights.footnote then
lua/parley/highlighter.lua:750:        vim.api.nvim_set_hl(0, "ParleyFootnote", user_highlights.footnote)
lua/parley/highlighter.lua:752:        vim.api.nvim_set_hl(0, "ParleyFootnote", { link = "DiagnosticHint" })
lua/parley/highlighter.lua:757:    -- Override via config.highlight.artifact_ref.
lua/parley/highlighter.lua:758:    if user_highlights.artifact_ref then
lua/parley/highlighter.lua:759:        vim.api.nvim_set_hl(0, "ParleyArtifactRef", user_highlights.artifact_ref)
lua/parley/highlighter.lua:765:    if user_highlights.tag then
lua/parley/highlighter.lua:766:        vim.api.nvim_set_hl(0, "ParleyTag", user_highlights.tag)
lua/parley/highlighter.lua:769:            link = "Todo", -- Link to Todo highlight group which is highly visible in most themes
lua/parley/highlighter.lua:773:    -- Picker typo-tolerance edits - distinct from exact Search highlights
lua/parley/highlighter.lua:774:    if user_highlights.approximate_match then
lua/parley/highlighter.lua:775:        vim.api.nvim_set_hl(0, "ParleyPickerApproximateMatch", user_highlights.approximate_match)
lua/parley/highlighter.lua:785:    -- via config.highlight.draft_block.
lua/parley/highlighter.lua:786:    if user_highlights.draft_block then
lua/parley/highlighter.lua:787:        vim.api.nvim_set_hl(0, "ParleyDraftBlock", user_highlights.draft_block)
lua/parley/highlighter.lua:817:    -- Use only background color to allow search highlights to show through
lua/parley/highlighter.lua:821:        -- Explicitly don't set fg to allow other highlights to show through
lua/parley/highlighter.lua:833:    -- Treesitter: clear strikethrough highlight groups
lua/parley/highlighter.lua:864:-- Apply extmark-based highlighting for inline branch links [🌿:text](file).
lua/parley/highlighter.lua:866:local function highlight_inline_branch_links(buf, ranges)
lua/parley/highlighter.lua:909:M.highlight_chat_branch_refs = function(buf)
lua/parley/highlighter.lua:930:    -- Always apply inline branch highlighting if present (no debounce needed)
lua/parley/highlighter.lua:932:        highlight_inline_branch_links(buf, ranges)
lua/parley/highlighter.lua:981:-- Apply highlighting to chat blocks in the current buffer.
lua/parley/highlighter.lua:983:-- Production highlighting is handled by the decoration provider.
lua/parley/highlighter.lua:984:M.highlight_question_block = function(buf)
lua/parley/highlighter.lua:985:    local ns = M.setup_highlights()
lua/parley/highlighter.lua:993:        local row_map = compute_chat_highlights(buf, range.start_line, range.end_line)
lua/parley/highlighter.lua:996:                vim.api.nvim_buf_add_highlight(buf, ns, hl.hl_group, row, hl.col_start, hl.col_end)
lua/parley/highlighter.lua:1008:    -- Register decoration provider: highlights are computed synchronously
lua/parley/highlighter.lua:1010:    -- built-in syntax highlighting. Zero flicker, always up-to-date.
lua/parley/highlighter.lua:1011:    local decor_ns = M.setup_highlights()
lua/parley/highlighter.lua:1031:                row_map = compute_chat_highlights(bufnr, start_line, end_line)
lua/parley/highlighter.lua:1033:                row_map = compute_markdown_highlights(bufnr, start_line, end_line)
lua/parley/highlighter.lua:1044:            local highlights = cache.rows[row]
lua/parley/highlighter.lua:1048:            if highlights then
lua/parley/highlighter.lua:1049:                for _, hl in ipairs(highlights) do
lua/parley/highlighter.lua:1071:                            -- highlights win over markdown syntax (which
lua/parley/highlighter.lua:1096:            interview.highlight_timestamps(buf)
lua/parley/highlighter.lua:1098:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1099:            _parley.highlight_chat_branch_refs(buf)
lua/parley/highlighter.lua:1108:            _parley.highlight_chat_branch_refs(buf)
lua/parley/highlighter.lua:1109:            interview.highlight_timestamps(buf)
lua/parley/highlighter.lua:1111:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1113:            -- review-deletion strike (🤖~X~, rendered in compute_markdown_highlights)
lua/parley/highlighter.lua:1131:            interview.highlight_timestamps(buf)
lua/parley/highlighter.lua:1133:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1136:            interview.highlight_timestamps(buf)
lua/parley/highlighter.lua:1138:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/highlighter.lua:1149:            skill_render.refresh_footnote_diagnostics(buf)
lua/parley/init.lua:3:-- A streamlined LLM chat interface for Neovim with highlighting and navigation
lua/parley/init.lua:126:local highlighter = require("parley.highlighter")
lua/parley/init.lua:127:highlighter.setup(M)
lua/parley/init.lua:1111:    -- Set up custom Search highlight for better visibility of all matches
lua/parley/init.lua:1519:    highlighter.display_agent(buf, file_name)
lua/parley/init.lua:1527:    return highlighter.agent_display_name_with_web_search(agent_name, ag_conf)
lua/parley/init.lua:1597:-- footnote (ONE undo entry — the anchor), highlights the selected term/reference
lua/parley/init.lua:1600:-- the footnote edit lands on the pre-edit content-hash → the empty snapshot
lua/parley/init.lua:1606:    -- silently doing nothing, and leave no footnote edit.
lua/parley/init.lua:1627:    -- rather than attach a footnote reference to shifted text.
lua/parley/init.lua:1635:    -- Store the definition as a markdown footnote in ONE full-buffer set_lines
lua/parley/init.lua:1640:    local e = define.apply_definition_footnote(lines, sr, sc - 1, er, ec - 1, input.term or phrase, input.definition)
lua/parley/init.lua:1644:    skill_render.highlight_span(buf, diag_span.lnum, diag_span.col, diag_span.end_lnum, diag_span.end_col)
lua/parley/init.lua:1645:    skill_render.refresh_footnote_diagnostics(buf)
lua/parley/init.lua:1647:    -- Record projection states so undo/redo of the footnote edit clears/restores
lua/parley/init.lua:1649:    -- snapshot, footnoted hash → highlight+diagnostic; attach the watcher.
lua/parley/init.lua:1990:        M.highlight_chat_branch_refs(buf)
lua/parley/init.lua:2018:        M.highlight_chat_branch_refs(buf)
lua/parley/init.lua:2039:        -- `hlsearch` setting govern highlight — don't force the global flag on
lua/parley/init.lua:2235:-- Define namespace and highlighting colors for questions, annotations, and thinking
lua/parley/init.lua:2236:M.setup_highlight = function()
lua/parley/init.lua:2237:    return highlighter.setup_highlights()
lua/parley/init.lua:2244:M.highlight_chat_branch_refs = function(buf)
lua/parley/init.lua:2245:    highlighter.highlight_chat_branch_refs(buf)
lua/parley/init.lua:2248:-- Apply highlighting to chat blocks in the current buffer.
lua/parley/init.lua:2250:-- Production highlighting is handled by the decoration provider.
lua/parley/init.lua:2251:M.highlight_question_block = function(buf)
lua/parley/init.lua:2252:    highlighter.highlight_question_block(buf)
lua/parley/init.lua:2281:        M.highlight_chat_branch_refs(buf)
lua/parley/init.lua:2310:        M.highlight_chat_branch_refs(buf)
lua/parley/init.lua:2385:    highlighter.setup_buf_handler()
lua/parley/chat_respond.lua:378:                text = define.strip_definition_footnote_footer(text)
lua/parley/chat_respond.lua:390:                local text = define.strip_definition_footnote_footer(read_block_text(k, b))
lua/parley/chat_respond.lua:409:                    table.insert(answer_blocks, { type = "text", text = define.strip_definition_footnote_footer(text) })
lua/parley/chat_respond.lua:427:                    table.insert(messages, { role = "user", content = define.strip_definition_footnote_footer(text) })
lua/parley/chat_respond.lua:616:                copy.text = define.strip_definition_footnote_footer(copy.text)
lua/parley/chat_respond.lua:702:                    local question_content = define.strip_definition_footnote_footer(exchange.question.content)
lua/parley/chat_respond.lua:807:                        table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.answer.content) })
lua/parley/chat_respond.lua:812:                        table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.summary.content) })
lua/parley/chat_respond.lua:820:                            table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.answer.content) })
lua/parley/chat_respond.lua:1170:    -- see what the gathered comment points at (highlighted via ParleyReference).
lua/parley/chat_respond.lua:1216:            -- (highlights, post-stream cursor moves) lands on the new turn.
lua/parley/chat_respond.lua:1274:            local highlight_start = parsed_chat.exchanges[exchange_idx].question.line_start
lua/parley/chat_respond.lua:1275:            vim.api.nvim_buf_add_highlight(buf, ns_id, "DiffAdd", highlight_start - 1, 0, -1)
lua/parley/chat_respond.lua:1277:            -- Always schedule the highlight to clear after a brief delay
lua/parley/chat_respond.lua:1930:                -- Refresh interview timestamps (decoration provider handles chat highlights)
lua/parley/chat_respond.lua:1932:                interview.highlight_timestamps(buf)
lua/parley/chat_respond.lua:2173:    local highlight_start = question.line_start
lua/parley/chat_respond.lua:2174:    vim.api.nvim_buf_add_highlight(buf, ns_id, "DiffAdd", highlight_start - 1, 0, -1)
lua/parley/chat_respond.lua:2177:    _parley.helpers.cursor_to_line(highlight_start, buf, win)
lua/parley/chat_respond.lua:2179:    -- Schedule highlight to clear after processing is complete
tests/unit/artifact_ref_spec.lua:55:describe("highlight_spans", function()
tests/unit/artifact_ref_spec.lua:57:    -- highlighter paints. Off-by-one here would mis-underline; pin it exactly.
tests/unit/artifact_ref_spec.lua:60:        local spans = ar.highlight_spans(line)
tests/unit/artifact_ref_spec.lua:70:        local spans = ar.highlight_spans(line)
lua/parley/config.lua:505:    -- how long review edit highlights persist (ms)
lua/parley/config.lua:506:    review_highlight_duration = 2000,
lua/parley/config.lua:634:    -- highlight those spans (ParleyReference). Set to false to strip markers
lua/parley/config.lua:638:    -- highlight styling (set to nil to use defaults that match your colorscheme)
lua/parley/config.lua:639:    -- these settings override the default highlight links if provided
lua/parley/config.lua:640:    highlight = {
lua/parley/config.lua:641:        -- Use existing highlight groups by default (nil values)
lua/parley/config.lua:642:        question = nil, -- highlight for user questions (default: links to Keyword)
lua/parley/config.lua:643:        file_reference = nil, -- highlight for file references (default: links to WarningMsg)
lua/parley/config.lua:644:        thinking = nil, -- highlight for reasoning lines (default: links to Comment)
lua/parley/config.lua:645:        annotation = nil, -- highlight for annotations (default: links to DiffAdd)
lua/parley/config.lua:646:        approximate_match = nil, -- highlight for typo-tolerance edit positions in picker matches (default: links to IncSearch)
lua/parley/config.lua:647:        chat_reference = nil, -- highlight for 🌿: chat branch/parent links (default: links to Special)
lua/parley/config.lua:648:        reference = nil, -- highlight for [referenced span] markers left by drill-in (#127) (default: underline)
tests/unit/float_picker_spec.lua:743:        it("keeps exact prefix matches on the exact highlight path only", function()
lua/parley/skill_invoke.lua:53:-- Build the diagnostics/highlight edit list for a propose_edits call from its
lua/parley/skill_invoke.lua:73:                -- "why" diagnostic, not a highlight (skill_render skips it). #133
lua/parley/skill_invoke.lua:79:    skill_render.highlight_edits(buf, edits, new_content)
lua/parley/skills/review/init.lua:79:-- highlighter and drill_in callers) yields the historical single-text behavior.
lua/parley/skills/review/init.lua:325:-- Expose for highlighter.lua backward compatibility
lua/parley/outline.lua:180:    vim.api.nvim_buf_add_highlight(hl_buf, ns_id, "DiffAdd", safe_lnum - 1, 0, -1)
lua/parley/skills/review/diag_display.lua:114:    if diagnostic.source == "parley-footnote" then
lua/parley/skills/review/diag_display.lua:175:    local footnote_diagnostics = {}
lua/parley/skills/review/diag_display.lua:178:            if diagnostic.source == "parley-footnote" then
lua/parley/skills/review/diag_display.lua:179:                table.insert(footnote_diagnostics, diagnostic)
lua/parley/skills/review/diag_display.lua:186:    table.sort(footnote_diagnostics, function(a, b)
lua/parley/skills/review/diag_display.lua:189:    show_float(footnote_diagnostics)
tests/unit/skill_render_spec.lua:2:-- helpers (INFO diagnostics + DiffChange highlights for applied skill edits).
tests/unit/skill_render_spec.lua:34:    it("highlight_edits runs without error on edited regions", function()
tests/unit/skill_render_spec.lua:36:        -- should not raise; highlights the line containing new_string
tests/unit/skill_render_spec.lua:37:        skill_render.highlight_edits(buf, { { new_string = "BETA" } }, "alpha\nBETA\ngamma")
tests/unit/skill_render_spec.lua:40:    it("a non-empty edit produces highlight extmarks", function()
tests/unit/skill_render_spec.lua:42:        skill_render.highlight_edits(buf, { { new_string = "BETA" } }, "alpha\nBETA\ngamma")
tests/unit/skill_render_spec.lua:48:    it("a deletion (empty new_string) gets a gutter diagnostic but no highlight", function()
tests/unit/skill_render_spec.lua:55:        skill_render.highlight_edits(buf, edits, new_content)
tests/unit/skill_render_spec.lua:60:        -- no highlight: empty new_string is skipped (would've spuriously hit line 0)
tests/unit/skill_render_spec.lua:96:    it("snapshot captures highlights + diagnostics; apply_snapshot restores them", function()
tests/unit/skill_render_spec.lua:99:        skill_render.highlight_edits(buf, { { new_string = "line two" } }, content)
tests/unit/skill_render_spec.lua:116:    it("snapshot captures and restores highlight and diagnostic column spans", function()
tests/unit/skill_render_spec.lua:121:        skill_render.highlight_span(buf, 0, 8, 19)
tests/unit/markdown_draft_block_spec.lua:1:-- Unit tests for the draft-block scanner in highlighter.lua.
tests/unit/markdown_draft_block_spec.lua:6:local highlighter = require("parley.highlighter")
tests/unit/markdown_draft_block_spec.lua:7:local scan = highlighter._scan_draft_blocks
tests/unit/picker_items_spec.lua:149:-- highlighter.agent_tool_badge — DRY helper shared by picker, highlighter
tests/unit/picker_items_spec.lua:153:describe("highlighter.agent_tool_badge", function()
tests/unit/picker_items_spec.lua:154:    local highlighter = require("parley.highlighter")
tests/unit/picker_items_spec.lua:160:        assert.equals("🔧", highlighter.agent_tool_badge({ tools = { "read_file" } }))
tests/unit/picker_items_spec.lua:164:        assert.equals("", highlighter.agent_tool_badge(nil))
tests/unit/picker_items_spec.lua:168:        assert.equals("", highlighter.agent_tool_badge({ provider = "anthropic" }))
tests/unit/picker_items_spec.lua:172:        assert.equals("", highlighter.agent_tool_badge({ tools = {} }))
tests/unit/picker_items_spec.lua:176:        assert.equals("", highlighter.agent_tool_badge({ tools = "read_file" }))
tests/unit/picker_items_spec.lua:180:describe("highlighter.agent_display_name_with_web_search includes tool badge", function()
tests/unit/picker_items_spec.lua:181:    local highlighter = require("parley.highlighter")
tests/unit/picker_items_spec.lua:190:        local name = highlighter.agent_display_name_with_web_search("TestAgent", {
tests/unit/picker_items_spec.lua:201:        local name = highlighter.agent_display_name_with_web_search("TestAgent", {
tests/unit/define_spec.lua:145:describe("define durable footnotes", function()
tests/unit/define_spec.lua:146:    it("slugifies a definition term into a markdown footnote id", function()
tests/unit/define_spec.lua:148:            define.footnote_id("Amazon Standard Identification Number"))
tests/unit/define_spec.lua:149:        assert.equals("asin", define.footnote_id("ASIN"))
tests/unit/define_spec.lua:152:    it("adds an inline footnote reference and appends a managed footer", function()
tests/unit/define_spec.lua:153:        local result = define.apply_definition_footnote(
tests/unit/define_spec.lua:172:    it("updates an existing managed footnote instead of duplicating it", function()
tests/unit/define_spec.lua:173:        local result = define.apply_definition_footnote(
tests/unit/define_spec.lua:196:        local result = define.apply_definition_footnote(
tests/unit/define_spec.lua:219:    it("strips only a final managed footnote footer", function()
tests/unit/define_spec.lua:228:        assert.equals("answer text", define.strip_definition_footnote_footer(text))
tests/unit/define_spec.lua:231:    it("preserves ordinary horizontal rules that are not managed footnote footers", function()
tests/unit/define_spec.lua:237:            "not a footnote",
tests/unit/define_spec.lua:240:        assert.equals(text, define.strip_definition_footnote_footer(text))
tests/unit/define_spec.lua:243:    it("reports the final managed footnote footer range", function()
tests/unit/define_spec.lua:244:        local range = define.managed_footnote_footer_range({
tests/unit/define_spec.lua:255:    it("does not report ordinary horizontal rules as managed footnote footers", function()
tests/unit/define_spec.lua:256:        local range = define.managed_footnote_footer_range({
tests/unit/define_spec.lua:261:            "not a footnote",
tests/unit/define_spec.lua:286:        }, "\n"), define.strip_definition_footnote_footer(text))
tests/unit/define_spec.lua:289:    it("extracts persisted footnote diagnostics from the managed footer", function()
tests/unit/define_spec.lua:290:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:309:    it("extracts every inline reference to a managed footnote", function()
tests/unit/define_spec.lua:310:        local diagnostics = define.footnote_diagnostics({
tests/unit/define_spec.lua:339:    it("ignores footnotes that are not in a final managed footer", function()
tests/unit/define_spec.lua:340:        local diagnostics = define.footnote_diagnostics({
lua/parley/tools/serialize.lua:62:    -- Opening fence carries the "json" info string for syntax-highlight
atlas/modes/interview.md:8:- `InterviewTimestamp` highlight group on timestamp lines
atlas/modes/interview.md:9:- `InterviewThought` highlight group on `{thought text}` blocks (linked to `DiagnosticInfo`)
tests/unit/build_messages_spec.lua:707:describe("_build_messages: durable definition footnotes", function()
tests/unit/build_messages_spec.lua:708:    it("strips managed definition footnote footers from user and assistant content", function()
tests/unit/build_messages_spec.lua:751:            "second half, not a footnote",
tests/unit/build_messages_spec.lua:1605:describe("build_messages_from_model: durable definition footnotes", function()
tests/unit/build_messages_spec.lua:1608:    it("strips managed footnote footers from live question and answer blocks", function()
atlas/modes/review.md:15:edits are oriented by `DiffChange` highlights + INFO gutter diagnostics that
atlas/modes/review.md:17:deletions show only the gutter "why" (no highlight).
atlas/modes/review.md:44:- `<>`/`[]`/`{}` sections may span **multiple lines**, each bounded to ~50 lines (per-section budget) so a stray opener can't swallow the document; `~D~` strike stays single-line (added in #125). `parse_markers` parses over the whole buffer joined (offset→line/col map) rather than line-by-line; `find_matching_bracket` takes an optional `{budget, is_excluded}` so the shared `_parse_marker_sections` (highlighter, drill_in) keeps its single-text behavior. Unterminated openers fall back to silent non-recognition.
atlas/modes/review.md:79:- **Rendering**: `lua/parley/skill_render.lua` — diagnostics + edit highlights
atlas/modes/review.md:176:The same controller also renders managed footnote diagnostics; those use a
atlas/modes/review.md:178:cursor is inside the term/`[^footnote]` diagnostic span.
atlas/modes/review.md:196:review_highlight_duration = 2000, -- highlight fade time in ms
atlas/modes/review.md:217:- `lua/parley/skill_render.lua` — diagnostics + edit highlights
atlas/modes/review.md:220:- `lua/parley/highlighter.lua` — `ParleyReviewUser`/`ParleyReviewAgent` groups

exec
/bin/zsh -lc "nl -ba lua/parley/highlighter.lua | sed -n '700,775p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   700        -- Tool error results — visually distinct from normal tool blocks
   701        if user_highlights.tool_error then
   702            vim.api.nvim_set_hl(0, "ParleyToolError", user_highlights.tool_error)
   703        else
   704            vim.api.nvim_set_hl(0, "ParleyToolError", {
   705                link = "DiagnosticError",
   706            })
   707        end
   708
   709        -- Annotations - Use existing highlight groups that work across themes
   710        if user_highlights.annotation then
   711            vim.api.nvim_set_hl(0, "ParleyAnnotation", user_highlights.annotation)
   712        else
   713            vim.api.nvim_set_hl(0, "ParleyAnnotation", {
   714                link = "DiffAdd", -- Usually a green background with appropriate text color
   715            })
   716        end
   717
   718        -- Chat branch/parent links (🌿: lines)
   719        if user_highlights.chat_reference then
   720            vim.api.nvim_set_hl(0, "ParleyChatReference", user_highlights.chat_reference)
   721        else
   722            vim.api.nvim_set_hl(0, "ParleyChatReference", {
   723                link = "Special",
   724            })
   725        end
   726
   727        -- Inline branch links [🌿:text](file) — display text as underlined link
   728        if user_highlights.inline_branch then
   729            vim.api.nvim_set_hl(0, "ParleyInlineBranch", user_highlights.inline_branch)
   730        else
   731            vim.api.nvim_set_hl(0, "ParleyInlineBranch", {
   732                underline = true,
   733                link = "Special",
   734            })
   735        end
   736
   737        -- Referenced-span markers `[…]` left in a reply by drill-in (#127): the
   738        -- text a gathered comment points at. Underline reads as "this span is
   739        -- marked" without the weight of a full background. Override via
   740        -- config.highlight.reference.
   741        if user_highlights.reference then
   742            vim.api.nvim_set_hl(0, "ParleyReference", user_highlights.reference)
   743        else
   744            vim.api.nvim_set_hl(0, "ParleyReference", { underline = true })
   745        end
   746
   747        -- Managed definition-footnote footer (`---` + `[^id]: ...`). It must be
   748        -- independent of the surrounding chat exchange color.
   749        if user_highlights.footnote then
   750            vim.api.nvim_set_hl(0, "ParleyFootnote", user_highlights.footnote)
   751        else
   752            vim.api.nvim_set_hl(0, "ParleyFootnote", { link = "DiagnosticHint" })
   753        end
   754
   755        -- Artifact refs (ariadne#11, #15 M4, pair#84) left navigable by #160.
   756        -- Underline reads as "this is a jumpable ref" without a heavy background.
   757        -- Override via config.highlight.artifact_ref.
   758        if user_highlights.artifact_ref then
   759            vim.api.nvim_set_hl(0, "ParleyArtifactRef", user_highlights.artifact_ref)
   760        else
   761            vim.api.nvim_set_hl(0, "ParleyArtifactRef", { underline = true })
   762        end
   763
   764        -- Tags - Highlighted tags in @@tag@@ format
   765        if user_highlights.tag then
   766            vim.api.nvim_set_hl(0, "ParleyTag", user_highlights.tag)
   767        else
   768            vim.api.nvim_set_hl(0, "ParleyTag", {
   769                link = "Todo", -- Link to Todo highlight group which is highly visible in most themes
   770            })
   771        end
   772
   773        -- Picker typo-tolerance edits - distinct from exact Search highlights
   774        if user_highlights.approximate_match then
   775            vim.api.nvim_set_hl(0, "ParleyPickerApproximateMatch", user_highlights.approximate_match)

exec
/bin/zsh -lc 'git diff --check 4005929621a91a6e1a9a02bd048a859bb59ffb77..HEAD -- atlas/ui/highlights.md lua/parley/define.lua lua/parley/highlighter.lua tests/integration/highlighting_spec.lua tests/unit/define_spec.lua workshop/issues/000171-footnote-coloring.md' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
codex
One possible gap is emerging: the implementation supports `config.highlight.footnote`, but the default config table appears not to list it. I’m checking whether that table is treated as user-facing documentation/schema or only loose defaults before deciding if that is a review finding.
exec
/bin/zsh -lc "nl -ba lua/parley/config.lua | sed -n '620,660p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   620
   621        -- styling for chatfinder
   622        ---@type "single" | "double" | "rounded" | "solid" | "shadow" | "none"
   623        style_chat_finder_border = "single",
   624        -- margins are number of characters or lines
   625        style_chat_finder_margin_bottom = 8,
   626        style_chat_finder_margin_left = 1,
   627        style_chat_finder_margin_right = 2,
   628        style_chat_finder_margin_top = 2,
   629        -- how wide should the preview be, number between 0.0 and 1.0
   630        style_chat_finder_preview_ratio = 0.5,
   631
   632        -- When drill-in gathers a 🤖 comment into the next turn (#127), enclose the
   633        -- referenced span in `[]` in place so you can see what it points at, and
   634        -- highlight those spans (ParleyReference). Set to false to strip markers
   635        -- without leaving the brackets.
   636        mark_reference_span = true,
   637
   638        -- highlight styling (set to nil to use defaults that match your colorscheme)
   639        -- these settings override the default highlight links if provided
   640        highlight = {
   641            -- Use existing highlight groups by default (nil values)
   642            question = nil, -- highlight for user questions (default: links to Keyword)
   643            file_reference = nil, -- highlight for file references (default: links to WarningMsg)
   644            thinking = nil, -- highlight for reasoning lines (default: links to Comment)
   645            annotation = nil, -- highlight for annotations (default: links to DiffAdd)
   646            approximate_match = nil, -- highlight for typo-tolerance edit positions in picker matches (default: links to IncSearch)
   647            chat_reference = nil, -- highlight for 🌿: chat branch/parent links (default: links to Special)
   648            reference = nil, -- highlight for [referenced span] markers left by drill-in (#127) (default: underline)
   649        },
   650
   651        -- lualine integration options
   652        lualine = {
   653            -- enable lualine integration
   654            enable = true,
   655            -- which section to add the component to
   656            section = "lualine_x",
   657            -- replace the user's filetype component with a parley mode glyph
   658            -- (○ global / ⊚ repo / ⦿ super-repo). Set to false to keep filetype.
   659            replace_filetype = true,
   660        },

exec
/bin/zsh -lc 'rg -n "function.*merge|deep_extend|default_config|config =" lua/parley/config.lua lua/parley/init.lua | head -80' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
lua/parley/config.lua:10:local config = {
lua/parley/config.lua:129:        config = {
lua/parley/init.lua:8:local config = require("parley.config")
lua/parley/init.lua:21:    config = {}, -- config variables
lua/parley/init.lua:190:    local parse_config = {
lua/parley/init.lua:464:    M.config = vim.deepcopy(config)

exec
/bin/zsh -lc "nl -ba lua/parley/config.lua | sed -n '1,80p' && nl -ba lua/parley/config.lua | sed -n '720,780p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
     1    -- Parley - A Neovim LLM Chat Plugin
     2    -- https://github.com/xianxu/parley.nvim/
     3
     4    --------------------------------------------------------------------------------
     5    -- Default config
     6    --------------------------------------------------------------------------------
     7
     8    ---@class ParleyConfig
     9    -- README_REFERENCE_MARKER_START
    10    local config = {
    11        -- Please start with minimal config possible.
    12        -- Just openai_api_key if you don't have OPENAI_API_KEY env set up.
    13        -- Defaults change over time to improve things, options might get deprecated.
    14        -- It's better to change only things where the default doesn't fit your needs.
    15
    16        -- required openai api key (string or table with command and arguments)
    17        -- openai_api_key = { "cat", "path_to/openai_api_key" },
    18        -- openai_api_key = { "bw", "get", "password", "OPENAI_API_KEY" },
    19        -- openai_api_key: "sk-...",
    20        -- openai_api_key = os.getenv("env_name.."),
    21        -- openai_api_key = os.getenv("OPENAI_API_KEY"),
    22
    23        -- API keys for each provider - easy to override just this section without copying entire config
    24        -- Set these in your local configuration - this is separate from providers section
    25        api_keys = {
    26            -- Different ways to provide API keys (from lowest to highest security):
    27            -- 1. Hardcode: api_key = "sk-..."
    28            -- 2. Environment variable: api_key = os.getenv("OPENAI_API_KEY")
    29            -- 3. File: api_key = { "cat", "/path/to/api_key_file" }
    30            -- 4. Password manager: api_key = { "pass", "show", "openai-key" }
    31            -- 5. macOS Keychain: api_key = { "security", "find-generic-password", "-a", "your_username", "-s", "OPENAI_API_KEY", "-w" }
    32
    33            openai = os.getenv("OPENAI_API_KEY"),
    34            anthropic = os.getenv("ANTHROPIC_API_KEY"),
    35
    36            googleai = os.getenv("GOOGLEAI_API_KEY"),
    37            ollama = "dummy_secret", -- ollama typically uses a dummy token for local instances
    38            copilot = os.getenv("GITHUB_TOKEN"), -- for GitHub Copilot
    39            -- Local client↔proxy handshake token (NOT your subscription auth — that
    40            -- lives in the cliproxy auth-dir via :ParleyProxy login). In managed mode
    41            -- parley renders this into the proxy's api-keys AND sends it as the bearer,
    42            -- so a fixed local default works out-of-the-box over loopback. Override
    43            -- via the env var if you point at a proxy that expects a specific key.
    44            cliproxyapi = os.getenv("CLIPROXYAPI_API_KEY") or "parley-local",
    45        },
    46
    47        -- Google Drive OAuth configuration for @@ URL references
    48        -- Users can override with plaintext values in their setup() call.
    49        google_drive = {
    50            client_id = "",
    51            client_secret = "",
    52            scopes = { "https://www.googleapis.com/auth/drive.readonly" },
    53        },
    54
    55        -- Provider-neutral OAuth configuration for remote @@ URL references.
    56        -- New provider integrations should be added here. The legacy
    57        -- `google_drive` config above remains supported for backward compatibility.
    58        oauth = {
    59            dropbox = {
    60                client_id = "",
    61                client_secret = "",
    62                redirect_port = nil,
    63                scopes = { "sharing.read" },
    64            },
    65            google = {
    66                client_id = "",
    67                client_secret = "",
    68                redirect_port = nil,
    69                scopes = { "https://www.googleapis.com/auth/drive.readonly" },
    70            },
    71        },
    72
    73        -- at least one working provider is required
    74        -- to disable a provider set it to empty table like openai = {}
    75        providers = {
    76            openai = {
    77                disable = false,
    78                endpoint = "https://api.openai.com/v1/chat/completions",
    79                -- secret will be loaded from api_keys.openai
    80            },

exec
/bin/zsh -lc "rg -n \"highlight = \\{|footnote = nil|artifact_ref = nil|tool_error|draft_block\" lua/parley/config.lua README.md atlas -g '"'!workshop/history/**'"'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
lua/parley/config.lua:640:    highlight = {

codex
The default config is marked as the README reference block and currently omits the new `highlight.footnote` key. I’m verifying whether README generation consumes that block; if so, that’s a docs/API-surface gap rather than just a style nit.
exec
/bin/zsh -lc "nl -ba lua/parley/init.lua | sed -n '440,490p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   440
   441    -- setup function
   442    M._setup_called = false
   443    ---@param opts the one returned from config.lua, it can come from several sources, either fully specified
   444    ---            in ~/.config/nvim/lua/parley/config.lua, or partially overrides from ~/.config/nvim/lua/plugins/parley.lua
   445    M.setup = function(opts)
   446        M._setup_called = true
   447
   448        math.randomseed(os.time())
   449
   450        -- Wire up interview module with shared state/logger references
   451        interview.setup(M, M.logger)
   452
   453        -- Initialize file tracker
   454        M.file_tracker = require("parley.file_tracker").init()
   455
   456        -- make sure opts is a table
   457        opts = opts or {}
   458        if type(opts) ~= "table" then
   459            M.logger.error(string.format("setup() expects table, but got %s:\n%s", type(opts), vim.inspect(opts)))
   460            opts = {}
   461        end
   462
   463        -- reset M.config
   464        M.config = vim.deepcopy(config)
   465
   466        -- Register builtin tool-use tools (M1 of #81). Runs before any
   467        -- agent validation so agents can reference tools by name. The
   468        -- registry module handles reset-idempotence internally.
   469        require("parley.tools").register_builtins()
   470
   471        local curl_params = opts.curl_params or M.config.curl_params
   472            local state_dir = opts.state_dir or M.config.state_dir
   473
   474        M.logger.setup(opts.log_file or M.config.log_file, opts.log_sensitive)
   475
   476        M.vault.setup({ state_dir = state_dir, curl_params = curl_params })
   477        custom_prompts.setup(M.helpers, state_dir)
   478
   479        -- Process API keys from api_keys table and load them into vault
   480        local api_keys = opts.api_keys or M.config.api_keys or {}
   481        for provider_name, api_key in pairs(api_keys) do
   482            if api_key then
   483                M.logger.debug("Loading " .. provider_name .. " API key into vault")
   484                M.vault.add_secret(provider_name, api_key)
   485            end
   486        end
   487
   488        -- Process providers and inject secrets from vault if needed
   489        local providers = opts.providers or M.config.providers or {}
   490        for provider_name, provider in pairs(providers) do

exec
/bin/zsh -lc "rg -n \"README_REFERENCE_MARKER|config.lua|README\" Makefile scripts tests lua .github atlas workshop -g '"'!workshop/history/**'"'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
atlas/modes/review.md:221:- `lua/parley/config.lua` — default keybindings and config
atlas/traceability.yaml:97:      - lua/parley/config.lua
atlas/traceability.yaml:157:      - lua/parley/config.lua
atlas/traceability.yaml:230:      - lua/parley/config.lua
atlas/traceability.yaml:273:      - lua/parley/config.lua
atlas/traceability.yaml:282:      - lua/parley/cliproxy_config.lua
atlas/traceability.yaml:407:      - lua/parley/config.lua
atlas/traceability.yaml:459:      - lua/parley/config.lua
atlas/traceability.yaml:475:      - lua/parley/config.lua
atlas/chat/inline_define.md:142:- `lua/parley/config.lua`, `lua/parley/keybinding_registry.lua` — the `<M-CR>` split.
atlas/infra/config.md:5:2. Global config (`lua/parley/config.lua`)
workshop/lessons.md:92:- New keybindings must use config-driven mechanism (`chat_shortcut_*` in config.lua + `M.cmd.*`) — don't copy hardcoded patterns
workshop/lessons.md:147:- **README snippets are consumers of user-facing UI behavior, not marketing fluff.** #176 updated atlas when footnote definitions moved from virtual lines to a centered float, but the close review caught README still saying "grey pop-under" for visual `<M-CR>`. Rule: when changing a visible command/keybinding behavior, grep README for the command, keybinding, and old UI nouns alongside atlas.
atlas/infra/workflow.md:45:| `specs` | Checks atlas/ and README.md match code changes | **read-write** (may update docs) |
atlas/providers/cliproxy-managed.md:8:**On by default** (`config.lua` ships `cliproxy = { manage = true, … }`), but
atlas/providers/cliproxy-managed.md:18:- **`cliproxy_config.lua`** (pure): `parse_endpoint` (host:port from the provider
lua/parley/config.lua:9:-- README_REFERENCE_MARKER_START
lua/parley/config.lua:683:    -- example hook functions (see Extend functionality section in the README)
lua/parley/config.lua:712:-- README_REFERENCE_MARKER_END
atlas/chat/memory_prefs.md:31:- `lua/parley/config.lua` — config defaults
lua/parley/init.lua:443:---@param opts the one returned from config.lua, it can come from several sources, either fully specified
lua/parley/init.lua:444:---            in ~/.config/nvim/lua/parley/config.lua, or partially overrides from ~/.config/nvim/lua/plugins/parley.lua
lua/parley/init.lua:1102:        if M.config.lualine and M.config.lualine.enable then
atlas/chat/spell_typeahead.md:71:- `lua/parley/config.lua` — `chat_spell` defaults.
lua/parley/health.lua:33:        if parley_ok and parley_module.config and parley_module.config.lualine and parley_module.config.lualine.enable then
lua/parley/lualine.lua:373:    if config.lualine and config.lualine.enable then
lua/parley/lualine.lua:384:          local section = config.lualine.section or "lualine_z"
lua/parley/lualine.lua:401:      local replace_filetype = config.lualine and config.lualine.replace_filetype ~= false
lua/parley/lualine.lua:455:        local section = config.lualine.section or "lualine_z"
lua/parley/cliproxy.lua:6:-- transforms live in parley/cliproxy_config.lua and are injected here.
tests/arch/buffer_mutation_spec.lua:35:                "lua/parley/config.lua",
tests/unit/tools_builtin_grep_spec.lua:61:        local r = handler({ pattern = "--files", path = "lua/parley/config.lua" })
tests/unit/tools_builtin_grep_spec.lua:67:        local r = handler({ pattern = "--pre=/bin/echo", path = "lua/parley/config.lua" })
tests/unit/cliproxy_config_spec.lua:1:-- Unit tests for lua/parley/cliproxy_config.lua (issue #131).
tests/unit/parse_chat_spec.lua:437:            "lua/  tests/  README.md",
tests/unit/parse_chat_spec.lua:442:            "Lua sources, tests, and a README.",
tests/unit/parse_chat_spec.lua:638:            "💬: Check @@~/config.lua@@",
tests/unit/parse_chat_spec.lua:643:        assert.equals("~/config.lua", refs[1].path)
tests/integration/skill_invoke_spec.lua:234:        vim.fn.writefile({ "repo root file" }, repo .. "/README.md")
tests/integration/skill_invoke_spec.lua:245:                raw_response = read_file_sse("README.md"),
tests/integration/skill_invoke_spec.lua:269:        vim.fn.writefile({ "sibling repo root file" }, sibling_repo .. "/README.md")
tests/integration/skill_invoke_spec.lua:284:                raw_response = read_file_sse("README.md"),
tests/unit/build_messages_spec.lua:120:        local pc = parsed_chat({ exchange("Read README") })
tests/unit/chat_parser_tools_spec.lua:23:-- Minimal config table the parser needs. Pulled from config.lua
tests/unit/super_repo_spec.lua:252:        vim.fn.writefile({ "# baz" }, sibling_b .. "/README.md")
tests/unit/super_repo_spec.lua:272:            if e.display:match("^{brain} README%.md") then
tests/unit/super_repo_spec.lua:279:        assert.is_true(found_b, "expected '{brain} README.md' entry")
tests/unit/tools_builtin_ack_spec.lua:36:        local r = handler({ pattern = "--files", path = "lua/parley/config.lua" })
tests/integration/review_menu_spec.lua:83:        -- the binding loop reads (the defaults themselves live in config.lua).
tests/unit/tool_loop_spec.lua:240:        vim.fn.writefile({ "from repo root" }, repo .. "/README.md")
tests/unit/tool_loop_spec.lua:250:        local raw = mk_read_file_sse_response("toolu_NEIGHBORHOOD", "README.md")
tests/integration/neighborhood_completion_spec.lua:9:vim.fn.writefile({ "readme" }, repo .. "/README.md")
tests/integration/neighborhood_completion_spec.lua:60:        assert.same({ "README.md" }, readme_items)

exec
/bin/zsh -lc "nl -ba README.md | sed -n '150,175p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   150
   151    ## Configuration Entry Points
   152
   153    Common options live in `setup()`:
   154    - `api_keys`
   155    - `chat_dir`
   156    - `notes_dir`
   157
   158    Merge behavior in `setup(opts)`:
   159    - `agents`, `system_prompts`, and `hooks` are merged by key/name, so you can override only selected entries.
   160    - Most other top-level keys are replaced when provided (for example `chat_dir`, `chat_dirs`, `notes_dir`, `chat_template`, `raw_mode`, `highlight`, `chat_memory`, `providers`, `api_keys`).
   161    - Practical rule: for non-merged tables, provide the full table you want, not just one nested field.
   162    - Reference [lua/parley/config.lua](https://github.com/xianxu/parley.nvim/blob/main/lua/parley/config.lua) for full defaults and examples.
   163
   164    Chat storage roots:
   165    - `chat_dir` is the primary writable root used for new chats.
   166    - `chat_dirs` is an optional list of additional roots that Chat Finder, chat validation, and chat-aware commands will scan alongside `chat_dir`.
   167    - `:ParleyChatDirs` opens a picker to add or remove chat roots at runtime.
   168    - `:ParleyChatDirAdd {dir}` adds a root directly, with directory completion.
   169    - `:ParleyChatDirRemove {dir}` removes a configured root directly.
   170    - `:ParleyChatMove {dir}` moves the current chat to another registered chat root.
   171    - The primary `chat_dir` cannot be removed at runtime.
   172    - The default shortcut for chat-root management is `<C-g>h`.
   173
   174    For full defaults and examples, see [`lua/parley/config.lua`](lua/parley/config.lua).
   175

exec
/bin/zsh -lc "find . -maxdepth 3 -type f | rg '(readme|README|config)'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
./workshop/history/000157-config-tools-spec-drift-default-toolsonnet-ships-all-but-spec-asserts-readonly-5-failing-tests.md
./workshop/history/000157-config-tools-spec-drift-default-toolsonnet-ships-all-but-spec-asserts-readonly-5-failing-tests-close-review.md
./workshop/history/000023-git-config-not-set-in-sandbox.md
./debug-slowness/README.md
./tests/unit/cliproxy_config_spec.lua
./tests/unit/config_tools_spec.lua
./.editorconfig
./lua/parley/cliproxy_config.lua
./lua/parley/config.lua
./README.md
./atlas/infra/config.md
./.git/config

exec
/bin/zsh -lc "nl -ba lua/parley/init.lua | sed -n '490,590p'" in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc "rg -n \"for key|opts\\[|M.config\\[|highlight\" lua/parley/init.lua | head -120" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
3:-- A streamlined LLM chat interface for Neovim with highlighting and navigation
126:local highlighter = require("parley.highlighter")
127:highlighter.setup(M)
510:        for k, v in pairs(M.config[tbl]) do
521:        M.config[tbl] = nil
523:        opts[tbl] = opts[tbl] or {}
524:        for k, v in pairs(opts[tbl]) do
533:        opts[tbl] = nil
538:        M.config[k] = v
663:            M.config[k] = M.helpers.prepare_dir(v, k)
1111:    -- Set up custom Search highlight for better visibility of all matches
1519:    highlighter.display_agent(buf, file_name)
1527:    return highlighter.agent_display_name_with_web_search(agent_name, ag_conf)
1597:-- footnote (ONE undo entry — the anchor), highlights the selected term/reference
1644:    skill_render.highlight_span(buf, diag_span.lnum, diag_span.col, diag_span.end_lnum, diag_span.end_col)
1649:    -- snapshot, footnoted hash → highlight+diagnostic; attach the watcher.
1990:        M.highlight_chat_branch_refs(buf)
2018:        M.highlight_chat_branch_refs(buf)
2039:        -- `hlsearch` setting govern highlight — don't force the global flag on
2235:-- Define namespace and highlighting colors for questions, annotations, and thinking
2236:M.setup_highlight = function()
2237:    return highlighter.setup_highlights()
2244:M.highlight_chat_branch_refs = function(buf)
2245:    highlighter.highlight_chat_branch_refs(buf)
2248:-- Apply highlighting to chat blocks in the current buffer.
2250:-- Production highlighting is handled by the decoration provider.
2251:M.highlight_question_block = function(buf)
2252:    highlighter.highlight_question_block(buf)
2281:        M.highlight_chat_branch_refs(buf)
2310:        M.highlight_chat_branch_refs(buf)
2385:    highlighter.setup_buf_handler()

 succeeded in 0ms:
   490        for provider_name, provider in pairs(providers) do
   491            if provider and type(provider) == "table" and not provider.secret and api_keys[provider_name] then
   492                M.logger.debug("Setting " .. provider_name .. " provider secret from api_keys")
   493                provider.secret = api_keys[provider_name]
   494            end
   495        end
   496
   497        M.dispatcher.setup({ providers = providers, curl_params = curl_params })
   498
   499        -- Clear sensitive data from config
   500        M.config.api_keys = nil
   501        opts.api_keys = nil
   502        M.config.providers = nil
   503        opts.providers = nil
   504
   505        -- selectively merge some keys. this allows configuration to partially override this keys.
   506        local mergeTables = { "hooks", "agents", "system_prompts" }
   507        for _, tbl in ipairs(mergeTables) do
   508            M[tbl] = M[tbl] or {}
   509            ---@diagnostic disable-next-line
   510            for k, v in pairs(M.config[tbl]) do
   511                if tbl == "hooks" then
   512                    M[tbl][k] = v
   513                elseif tbl == "agents" then
   514                    ---@diagnostic disable-next-line
   515                    M[tbl][v.name] = v
   516                elseif tbl == "system_prompts" then
   517                    ---@diagnostic disable-next-line
   518                    M[tbl][v.name] = v
   519                end
   520            end
   521            M.config[tbl] = nil
   522
   523            opts[tbl] = opts[tbl] or {}
   524            for k, v in pairs(opts[tbl]) do
   525                if tbl == "hooks" then
   526                    M[tbl][k] = v
   527                elseif tbl == "agents" then
   528                    M[tbl][v.name] = v
   529                elseif tbl == "system_prompts" then
   530                    M[tbl][v.name] = v
   531                end
   532            end
   533            opts[tbl] = nil
   534        end
   535
   536        -- now merge the rest of opts into M.config, this would be fully override.
   537        for k, v in pairs(opts) do
   538            M.config[k] = v
   539        end
   540
   541        -- #116 M2: seed issues_dir from the cue `discovery.home` (ariadne's issue.cue,
   542        -- exported to construct/generated/vocabulary/issue.json) when the user did NOT
   543        -- override it, so every config.issues_dir reader (get_issues_dir,
   544        -- get_issues_repo_root, the super-repo finder, the status autocmd, base.lua's
   545        -- issue descriptor) derives from the one cue source. Precedence: explicit user
   546        -- override > cue home > built-in default. home() returns nil in a fresh clone /
   547        -- pre-weave, so this is a no-op there (stays on the built-in default). Relative
   548        -- stays relative — issues_dir is in skip_prepare, never absolutized here.
   549        M.config.issues_dir = require("parley.issues").resolve_issues_dir(
   550            opts.issues_dir,
   551            require("parley.issue_vocabulary").home(),
   552            M.config.issues_dir
   553        )
   554
   555        -- Detect parley-enabled repo via marker file and set up repo-local directories
   556        -- Skip if user explicitly set chat_dir in opts (e.g. tests)
   557        local function apply_repo_local()
   558            if opts.chat_dir then return end
   559
   560            local marker = M.config.repo_marker
   561            if not marker then return end
   562
   563            local git_root = M.helpers.find_git_root(vim.fn.getcwd())
   564            if git_root == "" then return end
   565
   566            local marker_path = git_root .. "/" .. marker
   567            if vim.fn.filereadable(marker_path) ~= 1 then return end
   568
   569            M.config.repo_root = git_root
   570
   571            -- Ensure repo-local directories exist
   572            for _, dir in ipairs(repo_artifacts.relative_dirs(M.config)) do
   573                if dir and dir ~= "" and not dir:match("^/") then
   574                    M.helpers.prepare_dir(git_root .. "/" .. dir, "repo")
   575                end
   576            end
   577
   578            -- Prepend repo chat dir as primary, demoting global chat_dir to extra.
   579            -- Use the structured chat_roots list so labels are explicit:
   580            -- repo dir → "repo", original config.chat_dir → "global". Without
   581            -- explicit labels, the normalizer derives labels from the directory
   582            -- basename, which surfaces as e.g. {parley} in the finder when the
   583            -- global chat dir's basename is "parley".
   584            if M.config.repo_chat_dir and M.config.repo_chat_dir ~= "" then
   585                local repo_chat = git_root .. "/" .. M.config.repo_chat_dir
   586                local old_dir = M.config.chat_dir
   587                local old_dirs = M.config.chat_dirs
   588
   589                M.config.chat_dir = repo_chat
   590                local roots = { { dir = repo_chat, label = "repo" } }

exec
/bin/zsh -lc "nl -ba lua/parley/config.lua | sed -n '660,720p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   660        },
   661
   662        -- raw_mode configuration for debugging and learning. Writes per-turn
   663        -- logs to side files at <chat-dir>/.parley-logs/<basename>/{exchange,raw}.md.
   664        -- The lualine parley section turns red while either log toggle is on.
   665        raw_mode = {
   666            -- Master switch — when false, the toggle commands no-op.
   667            enable = true,
   668            -- Append per-turn exchange-level message lists (system/user/assistant).
   669            log_exchange = false,
   670            -- Append per-turn raw request payload (YAML), assembled response
   671            -- (YAML), and raw SSE stream lines.
   672            log_raw = false,
   673        },
   674
   675        -- TODO: what are the following are needed?
   676        -- command config and templates below are used by commands like GpRewrite, GpEnew, etc.
   677        -- command prompt prefix for asking user for input (supports {{agent}} template variable)
   678        command_prompt_prefix_template = "🤖 {{agent}} ~ ",
   679        -- auto select command response (easier chaining of commands)
   680        -- if false it also frees up the buffer cursor for further editing elsewhere
   681        command_auto_select_response = true,
   682
   683        -- example hook functions (see Extend functionality section in the README)
   684        hooks = {
   685            -- ParleyInspectPlugin provides a detailed inspection of the plugin state
   686            InspectPlugin = function(plugin, params)
   687                local bufnr = vim.api.nvim_create_buf(false, true)
   688                vim.bo[bufnr].bufhidden = "wipe"
   689                vim.bo[bufnr].buflisted = false
   690                local copy = vim.deepcopy(plugin)
   691                local key = copy.config.openai_api_key or ""
   692                copy.config.openai_api_key = key:sub(1, 3) .. string.rep("*", #key - 6) .. key:sub(-3)
   693                local plugin_info = string.format("Plugin structure:\n%s", vim.inspect(copy))
   694                local params_info = string.format("Command params:\n%s", vim.inspect(params))
   695                local lines = vim.split(plugin_info .. "\n" .. params_info, "\n")
   696                vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
   697                vim.api.nvim_win_set_buf(0, bufnr)
   698            end,
   699
   700            -- ParleyInspectLog for checking the log file
   701            InspectLog = function(plugin, _params)
   702                local log_file = plugin.config.log_file
   703                local buffer = plugin.helpers.get_buffer(log_file)
   704                if not buffer then
   705                    vim.cmd("e " .. log_file)
   706                else
   707                    vim.cmd("buffer " .. buffer)
   708                end
   709            end,
   710        },
   711    }
   712    -- README_REFERENCE_MARKER_END
   713
   714    return config

codex
The code path itself is still looking sound. I’m running the focused specs named by the issue now; the only review finding I’m leaning toward is the missing default-config documentation for the new override key.
exec
/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"' in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"' in /Users/xianxu/workspace/parley.nvim
 succeeded in 1495ms:

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
[32mSuccess[0m    ||    define durable footnotes reports the final managed footnote footer range
[32mSuccess[0m    ||    define durable footnotes does not report ordinary horizontal rules as managed footnote footers
[32mSuccess[0m    ||    define durable footnotes keeps earlier horizontal-rule content and strips only the final managed footer
[32mSuccess[0m    ||    define durable footnotes extracts persisted footnote diagnostics from the managed footer
[32mSuccess[0m    ||    define durable footnotes extracts every inline reference to a managed footnote
[32mSuccess[0m    ||    define durable footnotes ignores footnotes that are not in a final managed footer

[32mSuccess: [0m    28
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
]111
 succeeded in 2151ms:

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
[32mSuccess[0m    ||    markdown footnote diagnostics refreshes footnote diagnostics on markdown text changes without clearing other Parley diagnostics
[32mSuccess[0m    ||    markdown footnote diagnostics renders managed footnote footers with ParleyFootnote in markdown buffers
[32mSuccess[0m    ||    markdown chat reference rendering refreshes 🌿: branch lines with the chat topic in markdown buffers
[32mSuccess[0m    ||    markdown chat reference rendering does not rewrite 🌿: lines pointing to non-chat files in markdown buffers
[32mSuccess[0m    ||    markdown chat reference rendering refreshes from the updated topic in an open unsaved chat buffer

[32mSuccess: [0m    20
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
]111
codex
```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The implementation satisfies the core issue: managed footnote footers now derive from `parley.define`, get `ParleyFootnote` in chat and markdown buffers, and stop inheriting open-question coloring. I found no Critical correctness issues. The only blocking-before-ship item is a cheap docs/config-surface gap: the diff introduces `config.highlight.footnote` support but does not expose it in the default config/README-facing config reference.

1. Strengths:
- `lua/parley/define.lua:195` keeps footer detection single-sourced via `managed_footnote_footer_range` instead of duplicating grammar in the highlighter. Pass: ARCH-DRY.
- `lua/parley/highlighter.lua:270` and `lua/parley/highlighter.lua:471` consume the pure range helper from thin UI/highlight code. Pass: ARCH-PURE.
- `tests/integration/highlighting_spec.lua:168` directly covers the reported failure mode: open question followed by a managed footer.
- `atlas/ui/highlights.md:4` documents the new highlight group and behavior. Atlas gate looks satisfied.

2. Critical findings:
- None.

3. Important findings:
- `lua/parley/highlighter.lua:749` adds `user_highlights.footnote`, but `lua/parley/config.lua:640` does not list `footnote = nil` in the default `highlight` table, and README’s config section points readers to that file for full defaults. Fix sketch: add `footnote = nil -- highlight for managed definition-footnote footer lines (default: links to DiagnosticHint)` to the default config table. If README intentionally lists nested highlight keys elsewhere later, include it there too.

4. Minor findings:
- None.

5. Test coverage notes:
- Focused verification passed: `tests/unit/define_spec.lua` 28/28 and `tests/integration/highlighting_spec.lua` 20/20.
- Neovim startup emitted unrelated local write warnings for LuaSnip/parser/state paths, but the specs completed successfully.

6. Architectural notes for upcoming work:
- ARCH-DRY: Pass. Footer grammar remains in `define`.
- ARCH-PURE: Pass. New parser/range behavior is pure and unit-tested; highlighter remains IO/UI glue.
- ARCH-PURPOSE: Pass for the issue purpose. Chat and markdown consumers both derive from the shared footer detector and the reported coloring drift is covered.

7. Plan revision recommendations:
- None. The issue plan matches the delivered code; no Core concepts table was present to reconcile.
tokens used
65,252
```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The implementation satisfies the core issue: managed footnote footers now derive from `parley.define`, get `ParleyFootnote` in chat and markdown buffers, and stop inheriting open-question coloring. I found no Critical correctness issues. The only blocking-before-ship item is a cheap docs/config-surface gap: the diff introduces `config.highlight.footnote` support but does not expose it in the default config/README-facing config reference.

1. Strengths:
- `lua/parley/define.lua:195` keeps footer detection single-sourced via `managed_footnote_footer_range` instead of duplicating grammar in the highlighter. Pass: ARCH-DRY.
- `lua/parley/highlighter.lua:270` and `lua/parley/highlighter.lua:471` consume the pure range helper from thin UI/highlight code. Pass: ARCH-PURE.
- `tests/integration/highlighting_spec.lua:168` directly covers the reported failure mode: open question followed by a managed footer.
- `atlas/ui/highlights.md:4` documents the new highlight group and behavior. Atlas gate looks satisfied.

2. Critical findings:
- None.

3. Important findings:
- `lua/parley/highlighter.lua:749` adds `user_highlights.footnote`, but `lua/parley/config.lua:640` does not list `footnote = nil` in the default `highlight` table, and README’s config section points readers to that file for full defaults. Fix sketch: add `footnote = nil -- highlight for managed definition-footnote footer lines (default: links to DiagnosticHint)` to the default config table. If README intentionally lists nested highlight keys elsewhere later, include it there too.

4. Minor findings:
- None.

5. Test coverage notes:
- Focused verification passed: `tests/unit/define_spec.lua` 28/28 and `tests/integration/highlighting_spec.lua` 20/20.
- Neovim startup emitted unrelated local write warnings for LuaSnip/parser/state paths, but the specs completed successfully.

6. Architectural notes for upcoming work:
- ARCH-DRY: Pass. Footer grammar remains in `define`.
- ARCH-PURE: Pass. New parser/range behavior is pure and unit-tested; highlighter remains IO/UI glue.
- ARCH-PURPOSE: Pass for the issue purpose. Chat and markdown consumers both derive from the shared footer detector and the reported coloring drift is covered.

7. Plan revision recommendations:
- None. The issue plan matches the delivered code; no Core concepts table was present to reconcile.

---

## Re-review — 2026-07-08T17:25:03-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 171 — footnote coloring |
| repo | parley.nvim |
| issue file | workshop/issues/000171-footnote-coloring.md |
| boundary | whole-issue close |
| milestone | — |
| window | 4005929621a91a6e1a9a02bd048a859bb59ffb77..HEAD |
| command | sdlc close --issue 171 |
| reviewer | codex |
| timestamp | 2026-07-08T17:25:03-07:00 |
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
session id: 019f4442-7c85-7391-b652-2ad2156d5f05
--------
user
# Code review — the one SDLC boundary review

You are conducting a fresh-context code review at a development boundary —
whole-issue close — in the **parley.nvim** repository.

- repository: parley.nvim   (root: /Users/xianxu/workspace/parley.nvim)
- issue:      parley.nvim#171   (file: workshop/issues/000171-footnote-coloring.md)
- window:     Base: 4005929621a91a6e1a9a02bd048a859bb59ffb77   Head: HEAD

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
diff --git a/atlas/ui/highlights.md b/atlas/ui/highlights.md
index 32ad147..27290df 100644
--- a/atlas/ui/highlights.md
+++ b/atlas/ui/highlights.md
@@ -1,11 +1,14 @@
 # Spec: Syntax Highlighting

 ## Highlight Groups
-Custom groups (`ParleyQuestion`, `ParleyFileReference`, `ParleyChatReference`, `ParleyThinking`, `ParleyAnnotation`, `ParleyReference`, `ParleyPickerApproximateMatch`, `InterviewTimestamp`, `InterviewThought`) linked to standard Neovim groups. `ParleyReference` (default underline) marks drill-in `[referenced span]` brackets — see [chat/drill_in](../chat/drill_in.md).
+Custom groups (`ParleyQuestion`, `ParleyFileReference`, `ParleyChatReference`, `ParleyThinking`, `ParleyAnnotation`, `ParleyReference`, `ParleyFootnote`, `ParleyPickerApproximateMatch`, `InterviewTimestamp`, `InterviewThought`) linked to standard Neovim groups. `ParleyReference` (default underline) marks drill-in `[referenced span]` brackets — see [chat/drill_in](../chat/drill_in.md). `ParleyFootnote` (default `DiagnosticHint`) marks managed definition-footnote footer lines.

 ## Key Behaviors
 - Applied via decoration providers with ephemeral extmarks per window viewport
 - Multi-window safe: independent redraw cache per window
+- Managed definition-footnote footers (`---` + `[^id]: ...`) use
+  `ParleyFootnote` in chat and markdown buffers instead of inheriting the active
+  chat exchange color.
 - `🌿:` lines auto-rendered with debounced topic lookup from referenced files
 - `chat_conceal_model_params`: optional header param concealment
 - UTC timestamps shaped like `YYYY-MM-DDTHH:MM:SSZ` get local-time INFO
diff --git a/lua/parley/config.lua b/lua/parley/config.lua
index a67369e..6be9c04 100644
--- a/lua/parley/config.lua
+++ b/lua/parley/config.lua
@@ -646,6 +646,7 @@ local config = {
         approximate_match = nil, -- highlight for typo-tolerance edit positions in picker matches (default: links to IncSearch)
         chat_reference = nil, -- highlight for 🌿: chat branch/parent links (default: links to Special)
         reference = nil, -- highlight for [referenced span] markers left by drill-in (#127) (default: underline)
+        footnote = nil, -- highlight for managed definition-footnote footer lines (default: links to DiagnosticHint)
     },

     -- lualine integration options
diff --git a/lua/parley/define.lua b/lua/parley/define.lua
index e0e42e9..44817c1 100644
--- a/lua/parley/define.lua
+++ b/lua/parley/define.lua
@@ -189,6 +189,18 @@ local function managed_footer_start(lines)
     return nil
 end

+--- Locate the final managed definition-footnote footer.
+--- @param lines string[]|nil
+--- @return table|nil { start_line: integer, end_line: integer } 1-based inclusive
+function M.managed_footnote_footer_range(lines)
+    lines = lines or {}
+    local start = managed_footer_start(lines)
+    if not start then
+        return nil
+    end
+    return { start_line = start, end_line = #lines }
+end
+
 local function parse_footnote_line(line)
     local id, definition = trim(line):match("^%[%^([^%]]+)%]:%s*(.-)%s*$")
     if not id then
diff --git a/lua/parley/highlighter.lua b/lua/parley/highlighter.lua
index 50967cb..bb29507 100644
--- a/lua/parley/highlighter.lua
+++ b/lua/parley/highlighter.lua
@@ -266,6 +266,8 @@ local function compute_chat_highlights(buf, start_line, end_line)
     local result = {}
     local patterns = get_chat_highlight_prefix_patterns()
     local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)
+    local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
+    local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
     -- While a stream is in flight for this buffer, the model has not
     -- yet emitted 🧠:[END]. Assume explicit-end mode so blank-line
     -- paragraph breaks inside the in-progress thinking region keep
@@ -296,106 +298,112 @@ local function compute_chat_highlights(buf, start_line, end_line)

         push_artifact_refs(result, row, line) -- #160: navigable artifact refs

-        local pos = 1
-        while true do
-            local tag_start, content_start = line:find("@@", pos)
-            if not tag_start then break end
-            local content_end, tag_end = line:find("@@", content_start + 1)
-            if not content_end then break end
-            table.insert(highlighted_regions, { start = tag_start, finish = tag_end })
-            table.insert(result[row], { hl_group = "ParleyTag", col_start = tag_start - 1, col_end = tag_end })
-            pos = tag_end + 1
-        end
-
-        -- Any structural marker terminates an in-progress reasoning
-        -- block. This mirrors chat_parser's lenient termination so the
-        -- highlight tracks parse boundaries even when the model omits
-        -- the canonical blank-line terminator (or in pre-existing
-        -- chats authored under the old single-line 🧠: convention).
-        local is_user = line:match(patterns.user_pattern)
-        local is_assistant = line:match(patterns.assistant_pattern)
-        local is_branch = line:match(patterns.branch_pattern)
-        local is_local = line:match(patterns.local_pattern)
-        local is_summary = line:match(patterns.summary_pattern)
-        local is_tool_use = line:match("^🔧:")
-        local is_tool_result = line:match("^📎:")
-        if is_user or is_assistant or is_branch or is_local
-            or is_summary or is_tool_use or is_tool_result then
-            in_reasoning_block = false
-        end
+        local is_footer = footer_range and line_nr >= footer_range.start_line and line_nr <= footer_range.end_line
+        if is_footer then
+            table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
+            in_block = false
+        else
+            local pos = 1
+            while true do
+                local tag_start, content_start = line:find("@@", pos)
+                if not tag_start then break end
+                local content_end, tag_end = line:find("@@", content_start + 1)
+                if not content_end then break end
+                table.insert(highlighted_regions, { start = tag_start, finish = tag_end })
+                table.insert(result[row], { hl_group = "ParleyTag", col_start = tag_start - 1, col_end = tag_end })
+                pos = tag_end + 1
+            end

-        if line:match(patterns.reasoning_end_pattern) then
-            -- 🧠:[END] explicit terminator. Highlight the marker line
-            -- itself as ParleyThinking (it's the closing delimiter of
-            -- the thinking region), then close the block. Must be
-            -- checked before reasoning_pattern since the END marker
-            -- also starts with the reasoning prefix.
-            table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
-            in_reasoning_block = false
-        elseif line:match(patterns.reasoning_pattern) then
-            table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
-            in_reasoning_block = true
-            -- Buffer-aware lookahead: line_nr is the current 1-indexed
-            -- buffer line. Scanning the live buffer (rather than the
-            -- visible `lines` slice) catches [END] markers that fall
-            -- below the viewport bottom, which is the common case
-            -- after the cursor has moved up into the thinking region.
-            -- While streaming, force explicit-end mode (see comment at
-            -- the top of compute_chat_highlights).
-            if streaming then
-                in_reasoning_explicit_end = true
-            else
-                in_reasoning_explicit_end = reasoning_block_has_end_marker(buf, line_nr, patterns)
+            -- Any structural marker terminates an in-progress reasoning
+            -- block. This mirrors chat_parser's lenient termination so the
+            -- highlight tracks parse boundaries even when the model omits
+            -- the canonical blank-line terminator (or in pre-existing
+            -- chats authored under the old single-line 🧠: convention).
+            local is_user = line:match(patterns.user_pattern)
+            local is_assistant = line:match(patterns.assistant_pattern)
+            local is_branch = line:match(patterns.branch_pattern)
+            local is_local = line:match(patterns.local_pattern)
+            local is_summary = line:match(patterns.summary_pattern)
+            local is_tool_use = line:match("^🔧:")
+            local is_tool_result = line:match("^📎:")
+            if is_user or is_assistant or is_branch or is_local
+                or is_summary or is_tool_use or is_tool_result then
+                in_reasoning_block = false
             end
-        elseif is_summary or line:match("^👂:") then
-            table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
-        elseif is_tool_use or is_tool_result then
-            -- Tool block headers — dim (plumbing, not prose)
-            if line:match("error=true") then
-                table.insert(result[row], { hl_group = "ParleyToolError", col_start = 0, col_end = -1 })
-            else
+
+            if line:match(patterns.reasoning_end_pattern) then
+                -- 🧠:[END] explicit terminator. Highlight the marker line
+                -- itself as ParleyThinking (it's the closing delimiter of
+                -- the thinking region), then close the block. Must be
+                -- checked before reasoning_pattern since the END marker
+                -- also starts with the reasoning prefix.
                 table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
-            end
-            in_tool_block = true
-        elseif in_tool_block and not in_block then
-            -- Inside tool block fenced content — dim
-            table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
-        elseif in_reasoning_block then
-            -- Multi-line thinking continuation. In legacy mode (no
-            -- 🧠:[END] marker downstream) blank line terminates; in
-            -- explicit-end mode blank lines are preserved as part of
-            -- the reasoning region and stay dimmed. Non-blank lines
-            -- always stay dimmed as ParleyThinking.
-            if line:match("^%s*$") and not in_reasoning_explicit_end then
                 in_reasoning_block = false
-            else
+            elseif line:match(patterns.reasoning_pattern) then
                 table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
-            end
-        elseif is_user then
-            table.insert(result[row], { hl_group = "ParleyQuestion", col_start = 0, col_end = -1 })
-            in_block = true
-        elseif is_assistant then
-            in_block = false
-        elseif is_branch then
-            table.insert(result[row], { hl_group = "ParleyChatReference", col_start = 0, col_end = -1 })
-            in_block = false
-        elseif is_local then
-            in_block = false
-        elseif in_block and not in_code_block then
-            table.insert(result[row], { hl_group = "ParleyQuestion", col_start = 0, col_end = -1 })
-            if line:match("^@@") then
-                local is_tag_at_start = false
-                if #highlighted_regions > 0 and highlighted_regions[1].start == 1 then
-                    is_tag_at_start = true
+                in_reasoning_block = true
+                -- Buffer-aware lookahead: line_nr is the current 1-indexed
+                -- buffer line. Scanning the live buffer (rather than the
+                -- visible `lines` slice) catches [END] markers that fall
+                -- below the viewport bottom, which is the common case
+                -- after the cursor has moved up into the thinking region.
+                -- While streaming, force explicit-end mode (see comment at
+                -- the top of compute_chat_highlights).
+                if streaming then
+                    in_reasoning_explicit_end = true
+                else
+                    in_reasoning_explicit_end = reasoning_block_has_end_marker(buf, line_nr, patterns)
                 end
-                if not is_tag_at_start then
-                    table.insert(result[row], { hl_group = "ParleyFileReference", col_start = 0, col_end = -1 })
+            elseif is_summary or line:match("^👂:") then
+                table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
+            elseif is_tool_use or is_tool_result then
+                -- Tool block headers — dim (plumbing, not prose)
+                if line:match("error=true") then
+                    table.insert(result[row], { hl_group = "ParleyToolError", col_start = 0, col_end = -1 })
+                else
+                    table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
+                end
+                in_tool_block = true
+            elseif in_tool_block and not in_block then
+                -- Inside tool block fenced content — dim
+                table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
+            elseif in_reasoning_block then
+                -- Multi-line thinking continuation. In legacy mode (no
+                -- 🧠:[END] marker downstream) blank line terminates; in
+                -- explicit-end mode blank lines are preserved as part of
+                -- the reasoning region and stay dimmed. Non-blank lines
+                -- always stay dimmed as ParleyThinking.
+                if line:match("^%s*$") and not in_reasoning_explicit_end then
+                    in_reasoning_block = false
+                else
+                    table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
+                end
+            elseif is_user then
+                table.insert(result[row], { hl_group = "ParleyQuestion", col_start = 0, col_end = -1 })
+                in_block = true
+            elseif is_assistant then
+                in_block = false
+            elseif is_branch then
+                table.insert(result[row], { hl_group = "ParleyChatReference", col_start = 0, col_end = -1 })
+                in_block = false
+            elseif is_local then
+                in_block = false
+            elseif in_block and not in_code_block then
+                table.insert(result[row], { hl_group = "ParleyQuestion", col_start = 0, col_end = -1 })
+                if line:match("^@@") then
+                    local is_tag_at_start = false
+                    if #highlighted_regions > 0 and highlighted_regions[1].start == 1 then
+                        is_tag_at_start = true
+                    end
+                    if not is_tag_at_start then
+                        table.insert(result[row], { hl_group = "ParleyFileReference", col_start = 0, col_end = -1 })
+                    end
                 end
             end
-        end

-        for start_idx, _, end_idx in line:gmatch("()@(.-)@()") do
-            table.insert(result[row], { hl_group = "ParleyAnnotation", col_start = start_idx - 1, col_end = end_idx - 1 })
+            for start_idx, _, end_idx in line:gmatch("()@(.-)@()") do
+                table.insert(result[row], { hl_group = "ParleyAnnotation", col_start = start_idx - 1, col_end = end_idx - 1 })
+            end
         end
     end

@@ -459,9 +467,16 @@ local function compute_markdown_highlights(buf, start_line, end_line)
     local result = {}
     local branch_prefix = _parley.config.chat_branch_prefix or "🌿:"
     local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)
+    local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
+    local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
     for offset, line in ipairs(lines) do
         local row = start_line + offset - 2
+        local line_nr = row + 1
         push_artifact_refs(result, row, line) -- #160: navigable artifact refs
+        if footer_range and line_nr >= footer_range.start_line and line_nr <= footer_range.end_line then
+            result[row] = result[row] or {}
+            table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
+        end
         if line:sub(1, #branch_prefix) == branch_prefix then
             result[row] = result[row] or {}
             table.insert(result[row], { hl_group = "ParleyChatReference", col_start = 0, col_end = -1 })
@@ -525,7 +540,6 @@ local function compute_markdown_highlights(buf, start_line, end_line)
     -- Draft-block backgrounds (=== label === / === end ===). Full-buffer
     -- scan so a block opened far above the viewport still paints visible
     -- body lines. Bg-only highlight; markdown fg shows through.
-    local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
     local blocks = scan_draft_blocks(all_lines)
     local view_from = start_line - 1
     local view_to = end_line - 1
@@ -730,6 +744,14 @@ M.setup_highlights = function()
         vim.api.nvim_set_hl(0, "ParleyReference", { underline = true })
     end

+    -- Managed definition-footnote footer (`---` + `[^id]: ...`). It must be
+    -- independent of the surrounding chat exchange color.
+    if user_highlights.footnote then
+        vim.api.nvim_set_hl(0, "ParleyFootnote", user_highlights.footnote)
+    else
+        vim.api.nvim_set_hl(0, "ParleyFootnote", { link = "DiagnosticHint" })
+    end
+
     -- Artifact refs (ariadne#11, #15 M4, pair#84) left navigable by #160.
     -- Underline reads as "this is a jumpable ref" without a heavy background.
     -- Override via config.highlight.artifact_ref.
diff --git a/tests/integration/highlighting_spec.lua b/tests/integration/highlighting_spec.lua
index 781888b..43bf5f8 100644
--- a/tests/integration/highlighting_spec.lua
+++ b/tests/integration/highlighting_spec.lua
@@ -162,6 +162,30 @@ describe("highlight_question_block: file reference lines", function()
     end)
 end)

+describe("highlight_question_block: managed footnote footer", function()
+    after_each(cleanup_bufs)
+
+    it("uses a dedicated footnote highlight instead of open-question coloring", function()
+        local buf = highlighted_buf({
+            "💬: Define ASIN",
+            "This question is still open.",
+            "",
+            "---",
+            "",
+            "[^asin]: Amazon Standard Identification Number.",
+        })
+
+        assert.is_true(has_highlight(buf, 3, "ParleyFootnote"),
+            "Expected the managed footer divider to use ParleyFootnote")
+        assert.is_true(has_highlight(buf, 5, "ParleyFootnote"),
+            "Expected the managed footnote definition to use ParleyFootnote")
+        assert.is_false(has_highlight(buf, 3, "ParleyQuestion"),
+            "Managed footer divider should not inherit open-question color")
+        assert.is_false(has_highlight(buf, 5, "ParleyQuestion"),
+            "Managed footnote definition should not inherit open-question color")
+    end)
+end)
+
 describe("decoration provider cache", function()
     after_each(function()
         cleanup_extra_windows()
@@ -572,6 +596,44 @@ describe("markdown footnote diagnostics", function()
             return #diagnostics == 1 and diagnostics[1].source == "parley-skill"
         end)
     end)
+
+    it("renders managed footnote footers with ParleyFootnote in markdown buffers", function()
+        local provider = capture_decoration_provider()
+        local buf = vim.api.nvim_create_buf(false, true)
+        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
+            "here is ASIN[^asin] in context",
+            "",
+            "---",
+            "",
+            "[^asin]: Amazon Standard Identification Number.",
+        })
+        parley._parley_bufs[buf] = "markdown"
+
+        local win = vim.api.nvim_get_current_win()
+        vim.api.nvim_win_set_buf(win, buf)
+        provider.on_win(nil, win, buf, 0, 4)
+
+        local original_set_extmark = vim.api.nvim_buf_set_extmark
+        local extmarks = {}
+        vim.api.nvim_buf_set_extmark = function(_, _, row, _, opts)
+            table.insert(extmarks, { row = row, hl_group = opts.hl_group })
+            return #extmarks
+        end
+
+        provider.on_line(nil, win, buf, 2)
+        provider.on_line(nil, win, buf, 4)
+
+        vim.api.nvim_buf_set_extmark = original_set_extmark
+
+        local highlighted = {}
+        for _, mark in ipairs(extmarks) do
+            if mark.hl_group == "ParleyFootnote" then
+                highlighted[mark.row] = true
+            end
+        end
+        assert.is_true(highlighted[2], "Expected markdown footer divider to use ParleyFootnote")
+        assert.is_true(highlighted[4], "Expected markdown footnote definition to use ParleyFootnote")
+    end)
 end)

 describe("markdown chat reference rendering", function()
diff --git a/tests/unit/define_spec.lua b/tests/unit/define_spec.lua
index f9f2a6d..d7b21ec 100644
--- a/tests/unit/define_spec.lua
+++ b/tests/unit/define_spec.lua
@@ -240,6 +240,30 @@ describe("define durable footnotes", function()
         assert.equals(text, define.strip_definition_footnote_footer(text))
     end)

+    it("reports the final managed footnote footer range", function()
+        local range = define.managed_footnote_footer_range({
+            "answer text",
+            "",
+            "---",
+            "",
+            "[^asin]: Amazon Standard Identification Number.",
+        })
+
+        assert.are.same({ start_line = 3, end_line = 5 }, range)
+    end)
+
+    it("does not report ordinary horizontal rules as managed footnote footers", function()
+        local range = define.managed_footnote_footer_range({
+            "answer text",
+            "",
+            "---",
+            "",
+            "not a footnote",
+        })
+
+        assert.is_nil(range)
+    end)
+
     it("keeps earlier horizontal-rule content and strips only the final managed footer", function()
         local text = table.concat({
             "answer text",
diff --git a/workshop/lessons.md b/workshop/lessons.md
index 7d16d2f..3e5a64c 100644
--- a/workshop/lessons.md
+++ b/workshop/lessons.md
@@ -145,3 +145,6 @@

 ## 2026-07-08 (#176)
 - **README snippets are consumers of user-facing UI behavior, not marketing fluff.** #176 updated atlas when footnote definitions moved from virtual lines to a centered float, but the close review caught README still saying "grey pop-under" for visual `<M-CR>`. Rule: when changing a visible command/keybinding behavior, grep README for the command, keybinding, and old UI nouns alongside atlas.
+
+## 2026-07-08 (#171)
+- **A new `config.highlight.*` override is user-facing even when it is optional.** #171 added `config.highlight.footnote` support in the highlighter and documented the highlight group in atlas, but the close review caught that the default config/reference table still omitted the key. Rule: whenever code reads a new config override key, update `lua/parley/config.lua`'s defaults in the same commit and grep README/atlas for config snippets that mirror those defaults.
diff --git a/workshop/plans/000171-footnote-coloring-close-review.md b/workshop/plans/000171-footnote-coloring-close-review.md
new file mode 100644
index 0000000..5ee96c0
--- /dev/null
+++ b/workshop/plans/000171-footnote-coloring-close-review.md
@@ -0,0 +1,3186 @@
+# Boundary Review — parley.nvim#171 (whole-issue close)
+
+| field | value |
+|-------|-------|
+| issue | 171 — footnote coloring |
+| repo | parley.nvim |
+| issue file | workshop/issues/000171-footnote-coloring.md |
+| boundary | whole-issue close |
+| milestone | — |
+| window | 4005929621a91a6e1a9a02bd048a859bb59ffb77..HEAD |
+| command | sdlc close --issue 171 |
+| reviewer | codex |
+| timestamp | 2026-07-08T17:22:35-07:00 |
+| verdict | FIX-THEN-SHIP |
+
+## Review
+
+Reading additional input from stdin...
+OpenAI Codex v0.143.0
+--------
+workdir: /Users/xianxu/workspace/parley.nvim
+model: gpt-5.5
+provider: openai
+approval: never
+sandbox: workspace-write [workdir, /tmp, $TMPDIR, /tmp] (network access enabled)
+reasoning effort: none
+reasoning summaries: none
+session id: 019f443f-7828-7af1-8163-3e5bdc1b21fd
+--------
+user
+# Code review — the one SDLC boundary review
+
+You are conducting a fresh-context code review at a development boundary —
+whole-issue close — in the **parley.nvim** repository.
+
+- repository: parley.nvim   (root: /Users/xianxu/workspace/parley.nvim)
+- issue:      parley.nvim#171   (file: workshop/issues/000171-footnote-coloring.md)
+- window:     Base: 4005929621a91a6e1a9a02bd048a859bb59ffb77   Head: HEAD
+
+Review the **parley.nvim** repo and its tracker — the ariadne base-layer repo itself (changes here propagate to dependent repos). Do not assume any
+other repository or apply another repo's conventions.
+
+You have no prior session context — that is the anti-collusion property. Verify
+behavior against the issue's documented Spec/Plan and the code itself; do NOT
+take the implementor's word in commit messages or docs at face value. Tools are
+read-only: report findings precisely; the main agent (which has session context)
+applies the fixes, commits, and re-runs.
+
+Read the diff against the issue's Spec + Plan, then work the checklist below.
+Categorize every finding by severity — not everything is Critical; a nitpick
+marked Critical is noise.
+
+  Critical (must fix before crossing the boundary)
+    - correctness bugs; crashes / panics on unexpected input
+    - behavior drift from stated contracts (for ports of existing code where
+      byte-faithfulness was promised, diff against the source)
+    - silent error swallowing where the source raised
+  Important (fix before the boundary if cheap)
+    - API design of newly-introduced internal packages (downstream work will
+      consume them; is the surface stable?)
+    - missing test coverage that would catch the kind of bug shipped
+    - inconsistent error handling across the diff
+  Minor (note for future)
+    - style nits, naming, comment density; performance only if hot-path
+
+## Review checklist
+
+Code quality
+  - Clean separation of concerns; edge cases handled (empty / nil / unexpected).
+  - Proper error handling — no silent swallowing where the source raised.
+  - No duplicated logic / copy-paste that should be a shared helper.
+
+Testing
+  - Tests pin real logic, not mocks reasserting the implementation.
+  - The kind of bug this diff could ship is covered.
+  - PURE entities tested without IO; INTEGRATION via injected fakes (see below).
+
+Requirements traceability
+  - Every Plan checklist item this boundary claims is actually delivered.
+  - Implementation matches the Spec; no undeclared scope creep.
+  - Breaking changes documented.
+
+Production readiness
+  - Migration / backward-compatibility considered where state or formats change.
+  - Docs / atlas updated for new surface (see the Docs update gate).
+
+## Core concepts cross-check (if the plan has a Core concepts table)
+
+The plan should list entities in a greppable table — name, kind
+(PURE/INTEGRATION), file location, status (new/modified/deleted). For each row:
+  - Verify the entity exists at the stated path (grep the diff or filesystem).
+  - PURE: tests run without IO (no exec, net, mutable fs). If tests need mocks
+    to run, it isn't really PURE — flag Critical and recommend promoting it to
+    INTEGRATION.
+  - INTEGRATION: injected into pure callers, not invoked directly from business
+    logic.
+  - "modified" / "deleted": the diff shows the expected change/removal at the
+    stated location.
+Any contradiction between table and code = Critical finding, plus a plan-revision
+recommendation (a "## Revisions" entry so the plan stops claiming what the code
+doesn't deliver).
+
+## Docs update gate (atlas + README, per AGENTS.md §8)
+
+The boundary should update user-facing docs for any new surface introduced:
+
+  - **atlas/** — new architectural surface, flow, or terminology. Scan the diff
+    for new entity types, subcommands, conventions, file-tree locations. Any
+    present without corresponding atlas/ changes in the same range = Important
+    finding ("atlas update appears missing for <surface>").
+  - **README.md** — new user-facing surface a reader runs or types: subcommands,
+    flags, keybindings, config keys, install/usage steps. If the diff adds or
+    changes such surface and README.md is not updated in the same range =
+    Important finding ("README update appears missing for <surface>"). This is the
+    class of gap that used to surface only at the merge-time `specs` judge (#142);
+    catch it here, at the earliest gate, before the close verdict is recorded.
+
+## Architecture (the at-review backstop — these matter most long-term)
+
+Work through each of ARCH-DRY, ARCH-PURE, ARCH-PURPOSE explicitly, applying its at-review lens. The
+full principle definitions are delivered in the ARCHITECTURE PRINCIPLES block
+right after this prompt — for EACH marker, state pass or flag, and cite the
+marker (e.g. ARCH-DRY) in any finding. Architecture is where review has the
+least training signal and the longest-delayed payoff, so be deliberate here, not
+holistic.
+
+## Verdict + output
+
+Begin your response with this fenced verdict block — the machine-read handoff:
+
+```verdict
+verdict: <SHIP | FIX-THEN-SHIP | REWORK>
+confidence: <high | medium | low>
+```
+
+  SHIP           ready; ship it
+  FIX-THEN-SHIP  ship after addressing the findings (non-blocking at the gate)
+  REWORK         blocking; needs rework before shipping — fix + re-run
+
+The fenced ```` ```verdict ```` block above is the **authoritative machine-read
+handoff** — emit it as the first thing in your response. (A prose
+`VERDICT: <TOKEN>` first line still satisfies the legacy contract as a fallback,
+but the block is what the binary trusts.)
+
+After the verdict block: a 1-paragraph summary — what worked, what blocks SHIP if
+it isn't — followed by:
+  1. Strengths: 2-5 specific things done well (file:line where useful). Affirm
+     validated approaches so the operator knows what's confirmed-good ground.
+     Empty acceptable for trivial boundaries.
+  2. Critical findings (file:line + fix sketch); empty if none.
+  3. Important findings (same format).
+  4. Minor findings (terse one-liners).
+  5. Test coverage notes.
+  6. Architectural notes for upcoming work.
+  7. Plan revision recommendations: specific "## Revisions" entries the plan
+     needs (empty if the plan still matches the code).
+
+
+ARCHITECTURE PRINCIPLES — work through each of the 3 entries below explicitly, applying its `at-review` lens; cite the marker (e.g. ARCH-DRY) in any finding.
+
+# Architecture principles (ARCH-*)
+
+Injected architectural taste — the structural decisions whose payoff (or cost)
+shows up many turns, often months, down the road. Agents are strong at local
+tactics and weak here, so these are checked **at-plan** (when the design is being
+made — highest leverage) and **at-review** (backstop, on the diff). Cite the
+marker (e.g. `ARCH-DRY`) in plans, `## Log` entries, and review findings.
+
+This file is the single source; it is embedded into the planning, plan-quality,
+and code-review prompts. The human narrative lives in AGENTS.md "Core Design
+Principles"; this is its machine-delivered companion.
+
+## ARCH-DRY — Don't Repeat Yourself
+
+- **principle:** Reuse before adding. One source of truth per fact/behavior; no
+  duplicated logic, copy-pasted blocks, or parallel functions that should be one
+  shared helper.
+- **at-plan:** Flag a plan that re-implements something the codebase already has,
+  or that will obviously duplicate logic across the new files instead of
+  extracting a shared helper. Name the existing thing it should reuse.
+- **at-review:** Flag duplicated logic / copy-pasted blocks / near-identical
+  functions in the diff; point at the consolidation (file:line + the shared
+  helper they should become).
+
+## ARCH-PURE — Pure core, thin IO shell
+
+- **principle:** The majority of code is pure functions (deterministic, no side
+  effects); a thin "glue" layer at the boundary touches IO/UI/network/clock. Pure
+  functions are unit-tested directly; the glue is kept small and injected.
+- **at-plan:** Flag a design that buries business logic inside IO/handlers, or
+  that will only be testable with heavy mocks (a sign logic isn't separated from
+  IO). The plan should name what's pure vs the thin IO seam.
+- **at-review:** Flag business logic mixed with IO in the diff; logic that should
+  be a pure function injected into a thin caller. If a test needs mocks to run a
+  "pure" entity, it isn't pure — recommend extracting the IO to the boundary.
+
+## ARCH-PURPOSE — Serve the issue's actual purpose
+
+- **principle:** Deliver the issue's stated purpose, not the easy subset of it. A
+  single-source / "compiled to consumers" change is not done until **every
+  consumer derives** from the source — the source is *enforced*, not just
+  documentation a surface happens to restate; a hand-maintained restatement of the
+  model is a deferred consumer, not a finished one. "Follow-up" is for separable
+  extensions, never for the thing that is the point. This is the *opposite axis*
+  from Simplicity-First/YAGNI: not "build for an imagined future," but "don't
+  **under**-deliver the purpose you already committed to."
+- **at-plan:** Flag a plan whose scope is a strict subset of the issue's stated
+  goal / Done-when where the part deferred as "follow-up" *is* the purpose (e.g.
+  wires one consumer + enforcement but leaves the consumers that motivated the
+  issue as documentation that doesn't derive). Ask: does the plan fulfill the
+  purpose, or just the cheap win? Name the deferred purpose.
+- **at-review:** Does the diff *fulfill* the purpose or settle for the easy win?
+  For a single-source change, run the **shadow-sweep** — enumerate the consumers,
+  confirm each derives from the source, flag any remaining hand-maintained
+  restatement of the model. A "follow-up" that is actually the deferred point of
+  the issue is a finding, not a deferral.
+
+
+OUTPUT CONTRACT (machine-read — do not deviate). LEAD your response with the
+fenced ```verdict block shown above — that is the authoritative handoff the binary
+reads (its `verdict:` value is one of the listed tokens). Everything after the block
+is advisory: a non-blocking verdict WITH findings still PASSES the gate. A bare
+`VERDICT: <TOKEN>` line is accepted only as a FALLBACK when the block is absent.
+
+Diff:
+diff --git a/atlas/ui/highlights.md b/atlas/ui/highlights.md
+index 32ad147..27290df 100644
+--- a/atlas/ui/highlights.md
++++ b/atlas/ui/highlights.md
+@@ -1,11 +1,14 @@
+ # Spec: Syntax Highlighting
+
+ ## Highlight Groups
+-Custom groups (`ParleyQuestion`, `ParleyFileReference`, `ParleyChatReference`, `ParleyThinking`, `ParleyAnnotation`, `ParleyReference`, `ParleyPickerApproximateMatch`, `InterviewTimestamp`, `InterviewThought`) linked to standard Neovim groups. `ParleyReference` (default underline) marks drill-in `[referenced span]` brackets — see [chat/drill_in](../chat/drill_in.md).
++Custom groups (`ParleyQuestion`, `ParleyFileReference`, `ParleyChatReference`, `ParleyThinking`, `ParleyAnnotation`, `ParleyReference`, `ParleyFootnote`, `ParleyPickerApproximateMatch`, `InterviewTimestamp`, `InterviewThought`) linked to standard Neovim groups. `ParleyReference` (default underline) marks drill-in `[referenced span]` brackets — see [chat/drill_in](../chat/drill_in.md). `ParleyFootnote` (default `DiagnosticHint`) marks managed definition-footnote footer lines.
+
+ ## Key Behaviors
+ - Applied via decoration providers with ephemeral extmarks per window viewport
+ - Multi-window safe: independent redraw cache per window
++- Managed definition-footnote footers (`---` + `[^id]: ...`) use
++  `ParleyFootnote` in chat and markdown buffers instead of inheriting the active
++  chat exchange color.
+ - `🌿:` lines auto-rendered with debounced topic lookup from referenced files
+ - `chat_conceal_model_params`: optional header param concealment
+ - UTC timestamps shaped like `YYYY-MM-DDTHH:MM:SSZ` get local-time INFO
+diff --git a/lua/parley/define.lua b/lua/parley/define.lua
+index e0e42e9..44817c1 100644
+--- a/lua/parley/define.lua
++++ b/lua/parley/define.lua
+@@ -189,6 +189,18 @@ local function managed_footer_start(lines)
+     return nil
+ end
+
++--- Locate the final managed definition-footnote footer.
++--- @param lines string[]|nil
++--- @return table|nil { start_line: integer, end_line: integer } 1-based inclusive
++function M.managed_footnote_footer_range(lines)
++    lines = lines or {}
++    local start = managed_footer_start(lines)
++    if not start then
++        return nil
++    end
++    return { start_line = start, end_line = #lines }
++end
++
+ local function parse_footnote_line(line)
+     local id, definition = trim(line):match("^%[%^([^%]]+)%]:%s*(.-)%s*$")
+     if not id then
+diff --git a/lua/parley/highlighter.lua b/lua/parley/highlighter.lua
+index 50967cb..bb29507 100644
+--- a/lua/parley/highlighter.lua
++++ b/lua/parley/highlighter.lua
+@@ -266,6 +266,8 @@ local function compute_chat_highlights(buf, start_line, end_line)
+     local result = {}
+     local patterns = get_chat_highlight_prefix_patterns()
+     local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)
++    local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
++    local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
+     -- While a stream is in flight for this buffer, the model has not
+     -- yet emitted 🧠:[END]. Assume explicit-end mode so blank-line
+     -- paragraph breaks inside the in-progress thinking region keep
+@@ -296,106 +298,112 @@ local function compute_chat_highlights(buf, start_line, end_line)
+
+         push_artifact_refs(result, row, line) -- #160: navigable artifact refs
+
+-        local pos = 1
+-        while true do
+-            local tag_start, content_start = line:find("@@", pos)
+-            if not tag_start then break end
+-            local content_end, tag_end = line:find("@@", content_start + 1)
+-            if not content_end then break end
+-            table.insert(highlighted_regions, { start = tag_start, finish = tag_end })
+-            table.insert(result[row], { hl_group = "ParleyTag", col_start = tag_start - 1, col_end = tag_end })
+-            pos = tag_end + 1
+-        end
+-
+-        -- Any structural marker terminates an in-progress reasoning
+-        -- block. This mirrors chat_parser's lenient termination so the
+-        -- highlight tracks parse boundaries even when the model omits
+-        -- the canonical blank-line terminator (or in pre-existing
+-        -- chats authored under the old single-line 🧠: convention).
+-        local is_user = line:match(patterns.user_pattern)
+-        local is_assistant = line:match(patterns.assistant_pattern)
+-        local is_branch = line:match(patterns.branch_pattern)
+-        local is_local = line:match(patterns.local_pattern)
+-        local is_summary = line:match(patterns.summary_pattern)
+-        local is_tool_use = line:match("^🔧:")
+-        local is_tool_result = line:match("^📎:")
+-        if is_user or is_assistant or is_branch or is_local
+-            or is_summary or is_tool_use or is_tool_result then
+-            in_reasoning_block = false
+-        end
++        local is_footer = footer_range and line_nr >= footer_range.start_line and line_nr <= footer_range.end_line
++        if is_footer then
++            table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
++            in_block = false
++        else
++            local pos = 1
++            while true do
++                local tag_start, content_start = line:find("@@", pos)
++                if not tag_start then break end
++                local content_end, tag_end = line:find("@@", content_start + 1)
++                if not content_end then break end
++                table.insert(highlighted_regions, { start = tag_start, finish = tag_end })
++                table.insert(result[row], { hl_group = "ParleyTag", col_start = tag_start - 1, col_end = tag_end })
++                pos = tag_end + 1
++            end
+
+-        if line:match(patterns.reasoning_end_pattern) then
+-            -- 🧠:[END] explicit terminator. Highlight the marker line
+-            -- itself as ParleyThinking (it's the closing delimiter of
+-            -- the thinking region), then close the block. Must be
+-            -- checked before reasoning_pattern since the END marker
+-            -- also starts with the reasoning prefix.
+-            table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
+-            in_reasoning_block = false
+-        elseif line:match(patterns.reasoning_pattern) then
+-            table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
+-            in_reasoning_block = true
+-            -- Buffer-aware lookahead: line_nr is the current 1-indexed
+-            -- buffer line. Scanning the live buffer (rather than the
+-            -- visible `lines` slice) catches [END] markers that fall
+-            -- below the viewport bottom, which is the common case
+-            -- after the cursor has moved up into the thinking region.
+-            -- While streaming, force explicit-end mode (see comment at
+-            -- the top of compute_chat_highlights).
+-            if streaming then
+-                in_reasoning_explicit_end = true
+-            else
+-                in_reasoning_explicit_end = reasoning_block_has_end_marker(buf, line_nr, patterns)
++            -- Any structural marker terminates an in-progress reasoning
++            -- block. This mirrors chat_parser's lenient termination so the
++            -- highlight tracks parse boundaries even when the model omits
++            -- the canonical blank-line terminator (or in pre-existing
++            -- chats authored under the old single-line 🧠: convention).
++            local is_user = line:match(patterns.user_pattern)
++            local is_assistant = line:match(patterns.assistant_pattern)
++            local is_branch = line:match(patterns.branch_pattern)
++            local is_local = line:match(patterns.local_pattern)
++            local is_summary = line:match(patterns.summary_pattern)
++            local is_tool_use = line:match("^🔧:")
++            local is_tool_result = line:match("^📎:")
++            if is_user or is_assistant or is_branch or is_local
++                or is_summary or is_tool_use or is_tool_result then
++                in_reasoning_block = false
+             end
+-        elseif is_summary or line:match("^👂:") then
+-            table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
+-        elseif is_tool_use or is_tool_result then
+-            -- Tool block headers — dim (plumbing, not prose)
+-            if line:match("error=true") then
+-                table.insert(result[row], { hl_group = "ParleyToolError", col_start = 0, col_end = -1 })
+-            else
++
++            if line:match(patterns.reasoning_end_pattern) then
++                -- 🧠:[END] explicit terminator. Highlight the marker line
++                -- itself as ParleyThinking (it's the closing delimiter of
++                -- the thinking region), then close the block. Must be
++                -- checked before reasoning_pattern since the END marker
++                -- also starts with the reasoning prefix.
+                 table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
+-            end
+-            in_tool_block = true
+-        elseif in_tool_block and not in_block then
+-            -- Inside tool block fenced content — dim
+-            table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
+-        elseif in_reasoning_block then
+-            -- Multi-line thinking continuation. In legacy mode (no
+-            -- 🧠:[END] marker downstream) blank line terminates; in
+-            -- explicit-end mode blank lines are preserved as part of
+-            -- the reasoning region and stay dimmed. Non-blank lines
+-            -- always stay dimmed as ParleyThinking.
+-            if line:match("^%s*$") and not in_reasoning_explicit_end then
+                 in_reasoning_block = false
+-            else
++            elseif line:match(patterns.reasoning_pattern) then
+                 table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
+-            end
+-        elseif is_user then
+-            table.insert(result[row], { hl_group = "ParleyQuestion", col_start = 0, col_end = -1 })
+-            in_block = true
+-        elseif is_assistant then
+-            in_block = false
+-        elseif is_branch then
+-            table.insert(result[row], { hl_group = "ParleyChatReference", col_start = 0, col_end = -1 })
+-            in_block = false
+-        elseif is_local then
+-            in_block = false
+-        elseif in_block and not in_code_block then
+-            table.insert(result[row], { hl_group = "ParleyQuestion", col_start = 0, col_end = -1 })
+-            if line:match("^@@") then
+-                local is_tag_at_start = false
+-                if #highlighted_regions > 0 and highlighted_regions[1].start == 1 then
+-                    is_tag_at_start = true
++                in_reasoning_block = true
++                -- Buffer-aware lookahead: line_nr is the current 1-indexed
++                -- buffer line. Scanning the live buffer (rather than the
++                -- visible `lines` slice) catches [END] markers that fall
++                -- below the viewport bottom, which is the common case
++                -- after the cursor has moved up into the thinking region.
++                -- While streaming, force explicit-end mode (see comment at
++                -- the top of compute_chat_highlights).
++                if streaming then
++                    in_reasoning_explicit_end = true
++                else
++                    in_reasoning_explicit_end = reasoning_block_has_end_marker(buf, line_nr, patterns)
+                 end
+-                if not is_tag_at_start then
+-                    table.insert(result[row], { hl_group = "ParleyFileReference", col_start = 0, col_end = -1 })
++            elseif is_summary or line:match("^👂:") then
++                table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
++            elseif is_tool_use or is_tool_result then
++                -- Tool block headers — dim (plumbing, not prose)
++                if line:match("error=true") then
++                    table.insert(result[row], { hl_group = "ParleyToolError", col_start = 0, col_end = -1 })
++                else
++                    table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
++                end
++                in_tool_block = true
++            elseif in_tool_block and not in_block then
++                -- Inside tool block fenced content — dim
++                table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
++            elseif in_reasoning_block then
++                -- Multi-line thinking continuation. In legacy mode (no
++                -- 🧠:[END] marker downstream) blank line terminates; in
++                -- explicit-end mode blank lines are preserved as part of
++                -- the reasoning region and stay dimmed. Non-blank lines
++                -- always stay dimmed as ParleyThinking.
++                if line:match("^%s*$") and not in_reasoning_explicit_end then
++                    in_reasoning_block = false
++                else
++                    table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
++                end
++            elseif is_user then
++                table.insert(result[row], { hl_group = "ParleyQuestion", col_start = 0, col_end = -1 })
++                in_block = true
++            elseif is_assistant then
++                in_block = false
++            elseif is_branch then
++                table.insert(result[row], { hl_group = "ParleyChatReference", col_start = 0, col_end = -1 })
++                in_block = false
++            elseif is_local then
++                in_block = false
++            elseif in_block and not in_code_block then
++                table.insert(result[row], { hl_group = "ParleyQuestion", col_start = 0, col_end = -1 })
++                if line:match("^@@") then
++                    local is_tag_at_start = false
++                    if #highlighted_regions > 0 and highlighted_regions[1].start == 1 then
++                        is_tag_at_start = true
++                    end
++                    if not is_tag_at_start then
++                        table.insert(result[row], { hl_group = "ParleyFileReference", col_start = 0, col_end = -1 })
++                    end
+                 end
+             end
+-        end
+
+-        for start_idx, _, end_idx in line:gmatch("()@(.-)@()") do
+-            table.insert(result[row], { hl_group = "ParleyAnnotation", col_start = start_idx - 1, col_end = end_idx - 1 })
++            for start_idx, _, end_idx in line:gmatch("()@(.-)@()") do
++                table.insert(result[row], { hl_group = "ParleyAnnotation", col_start = start_idx - 1, col_end = end_idx - 1 })
++            end
+         end
+     end
+
+@@ -459,9 +467,16 @@ local function compute_markdown_highlights(buf, start_line, end_line)
+     local result = {}
+     local branch_prefix = _parley.config.chat_branch_prefix or "🌿:"
+     local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)
++    local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
++    local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
+     for offset, line in ipairs(lines) do
+         local row = start_line + offset - 2
++        local line_nr = row + 1
+         push_artifact_refs(result, row, line) -- #160: navigable artifact refs
++        if footer_range and line_nr >= footer_range.start_line and line_nr <= footer_range.end_line then
++            result[row] = result[row] or {}
++            table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
++        end
+         if line:sub(1, #branch_prefix) == branch_prefix then
+             result[row] = result[row] or {}
+             table.insert(result[row], { hl_group = "ParleyChatReference", col_start = 0, col_end = -1 })
+@@ -525,7 +540,6 @@ local function compute_markdown_highlights(buf, start_line, end_line)
+     -- Draft-block backgrounds (=== label === / === end ===). Full-buffer
+     -- scan so a block opened far above the viewport still paints visible
+     -- body lines. Bg-only highlight; markdown fg shows through.
+-    local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
+     local blocks = scan_draft_blocks(all_lines)
+     local view_from = start_line - 1
+     local view_to = end_line - 1
+@@ -730,6 +744,14 @@ M.setup_highlights = function()
+         vim.api.nvim_set_hl(0, "ParleyReference", { underline = true })
+     end
+
++    -- Managed definition-footnote footer (`---` + `[^id]: ...`). It must be
++    -- independent of the surrounding chat exchange color.
++    if user_highlights.footnote then
++        vim.api.nvim_set_hl(0, "ParleyFootnote", user_highlights.footnote)
++    else
++        vim.api.nvim_set_hl(0, "ParleyFootnote", { link = "DiagnosticHint" })
++    end
++
+     -- Artifact refs (ariadne#11, #15 M4, pair#84) left navigable by #160.
+     -- Underline reads as "this is a jumpable ref" without a heavy background.
+     -- Override via config.highlight.artifact_ref.
+diff --git a/tests/integration/highlighting_spec.lua b/tests/integration/highlighting_spec.lua
+index 781888b..43bf5f8 100644
+--- a/tests/integration/highlighting_spec.lua
++++ b/tests/integration/highlighting_spec.lua
+@@ -162,6 +162,30 @@ describe("highlight_question_block: file reference lines", function()
+     end)
+ end)
+
++describe("highlight_question_block: managed footnote footer", function()
++    after_each(cleanup_bufs)
++
++    it("uses a dedicated footnote highlight instead of open-question coloring", function()
++        local buf = highlighted_buf({
++            "💬: Define ASIN",
++            "This question is still open.",
++            "",
++            "---",
++            "",
++            "[^asin]: Amazon Standard Identification Number.",
++        })
++
++        assert.is_true(has_highlight(buf, 3, "ParleyFootnote"),
++            "Expected the managed footer divider to use ParleyFootnote")
++        assert.is_true(has_highlight(buf, 5, "ParleyFootnote"),
++            "Expected the managed footnote definition to use ParleyFootnote")
++        assert.is_false(has_highlight(buf, 3, "ParleyQuestion"),
++            "Managed footer divider should not inherit open-question color")
++        assert.is_false(has_highlight(buf, 5, "ParleyQuestion"),
++            "Managed footnote definition should not inherit open-question color")
++    end)
++end)
++
+ describe("decoration provider cache", function()
+     after_each(function()
+         cleanup_extra_windows()
+@@ -572,6 +596,44 @@ describe("markdown footnote diagnostics", function()
+             return #diagnostics == 1 and diagnostics[1].source == "parley-skill"
+         end)
+     end)
++
++    it("renders managed footnote footers with ParleyFootnote in markdown buffers", function()
++        local provider = capture_decoration_provider()
++        local buf = vim.api.nvim_create_buf(false, true)
++        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
++            "here is ASIN[^asin] in context",
++            "",
++            "---",
++            "",
++            "[^asin]: Amazon Standard Identification Number.",
++        })
++        parley._parley_bufs[buf] = "markdown"
++
++        local win = vim.api.nvim_get_current_win()
++        vim.api.nvim_win_set_buf(win, buf)
++        provider.on_win(nil, win, buf, 0, 4)
++
++        local original_set_extmark = vim.api.nvim_buf_set_extmark
++        local extmarks = {}
++        vim.api.nvim_buf_set_extmark = function(_, _, row, _, opts)
++            table.insert(extmarks, { row = row, hl_group = opts.hl_group })
++            return #extmarks
++        end
++
++        provider.on_line(nil, win, buf, 2)
++        provider.on_line(nil, win, buf, 4)
++
++        vim.api.nvim_buf_set_extmark = original_set_extmark
++
++        local highlighted = {}
++        for _, mark in ipairs(extmarks) do
++            if mark.hl_group == "ParleyFootnote" then
++                highlighted[mark.row] = true
++            end
++        end
++        assert.is_true(highlighted[2], "Expected markdown footer divider to use ParleyFootnote")
++        assert.is_true(highlighted[4], "Expected markdown footnote definition to use ParleyFootnote")
++    end)
+ end)
+
+ describe("markdown chat reference rendering", function()
+diff --git a/tests/unit/define_spec.lua b/tests/unit/define_spec.lua
+index f9f2a6d..d7b21ec 100644
+--- a/tests/unit/define_spec.lua
++++ b/tests/unit/define_spec.lua
+@@ -240,6 +240,30 @@ describe("define durable footnotes", function()
+         assert.equals(text, define.strip_definition_footnote_footer(text))
+     end)
+
++    it("reports the final managed footnote footer range", function()
++        local range = define.managed_footnote_footer_range({
++            "answer text",
++            "",
++            "---",
++            "",
++            "[^asin]: Amazon Standard Identification Number.",
++        })
++
++        assert.are.same({ start_line = 3, end_line = 5 }, range)
++    end)
++
++    it("does not report ordinary horizontal rules as managed footnote footers", function()
++        local range = define.managed_footnote_footer_range({
++            "answer text",
++            "",
++            "---",
++            "",
++            "not a footnote",
++        })
++
++        assert.is_nil(range)
++    end)
++
+     it("keeps earlier horizontal-rule content and strips only the final managed footer", function()
+         local text = table.concat({
+             "answer text",
+
+
+codex
+I’ll use the repo workflow instructions plus the review prompt as the contract, then inspect the issue, plan, and actual diff before giving the machine-readable verdict.
+exec
+/bin/zsh -lc "sed -n '1,220p' /Users/xianxu/workspace/ariadne/construct/adapted/superpowers-using-superpowers/SKILL.md" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+---
+name: superpowers-using-superpowers
+description: Use when starting any conversation - establishes how to find and use skills, requiring Skill tool invocation before ANY response including clarifying questions
+---
+
+<SUBAGENT-STOP>
+If you were dispatched as a subagent to execute a specific task, skip this skill.
+</SUBAGENT-STOP>
+
+<EXTREMELY-IMPORTANT>
+If you think there is even a 1% chance a skill might apply to what you are doing, you ABSOLUTELY MUST invoke the skill.
+
+IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.
+
+This is not negotiable. This is not optional. You cannot rationalize your way out of this.
+</EXTREMELY-IMPORTANT>
+
+## Instruction Priority
+
+> **Ariadne note:** AGENTS.md Section 3 governs subagent strategy and overrides skills that mandate subagent-driven-development as the default execution path.
+
+Superpowers skills override default system prompt behavior, but **user instructions always take precedence**:
+
+1. **User's explicit instructions** (CLAUDE.md, GEMINI.md, AGENTS.md, direct requests) — highest priority
+2. **Superpowers skills** — override default system behavior where they conflict
+3. **Default system prompt** — lowest priority
+
+If CLAUDE.md, GEMINI.md, or AGENTS.md says "don't use TDD" and a skill says "always use TDD," follow the user's instructions. The user is in control.
+
+## How to Access Skills
+
+**In Claude Code:** Use the `Skill` tool. When you invoke a skill, its content is loaded and presented to you—follow it directly. Never use the Read tool on skill files.
+
+**In Gemini CLI:** Skills activate via the `activate_skill` tool. Gemini loads skill metadata at session start and activates the full content on demand.
+
+**In other environments:** Check your platform's documentation for how skills are loaded.
+
+## Platform Adaptation
+
+Skills use Claude Code tool names. Non-CC platforms: see `references/codex-tools.md` (Codex) for tool equivalents. Gemini CLI users get the tool mapping loaded automatically via GEMINI.md.
+
+# Using Skills
+
+## The Rule
+
+**Invoke relevant or requested skills BEFORE any response or action.** Even a 1% chance a skill might apply means that you should invoke the skill to check. If an invoked skill turns out to be wrong for the situation, you don't need to use it.
+
+```dot
+digraph skill_flow {
+    "User message received" [shape=doublecircle];
+    "About to EnterPlanMode?" [shape=doublecircle];
+    "Already brainstormed?" [shape=diamond];
+    "Invoke brainstorming skill" [shape=box];
+    "Might any skill apply?" [shape=diamond];
+    "Invoke Skill tool" [shape=box];
+    "Announce: 'Using [skill] to [purpose]'" [shape=box];
+    "Has checklist?" [shape=diamond];
+    "Create TodoWrite todo per item" [shape=box];
+    "Follow skill exactly" [shape=box];
+    "Respond (including clarifications)" [shape=doublecircle];
+
+    "About to EnterPlanMode?" -> "Already brainstormed?";
+    "Already brainstormed?" -> "Invoke brainstorming skill" [label="no"];
+    "Already brainstormed?" -> "Might any skill apply?" [label="yes"];
+    "Invoke brainstorming skill" -> "Might any skill apply?";
+
+    "User message received" -> "Might any skill apply?";
+    "Might any skill apply?" -> "Invoke Skill tool" [label="yes, even 1%"];
+    "Might any skill apply?" -> "Respond (including clarifications)" [label="definitely not"];
+    "Invoke Skill tool" -> "Announce: 'Using [skill] to [purpose]'";
+    "Announce: 'Using [skill] to [purpose]'" -> "Has checklist?";
+    "Has checklist?" -> "Create TodoWrite todo per item" [label="yes"];
+    "Has checklist?" -> "Follow skill exactly" [label="no"];
+    "Create TodoWrite todo per item" -> "Follow skill exactly";
+}
+```
+
+## Red Flags
+
+These thoughts mean STOP—you're rationalizing:
+
+| Thought | Reality |
+|---------|---------|
+| "This is just a simple question" | Questions are tasks. Check for skills. |
+| "I need more context first" | Skill check comes BEFORE clarifying questions. |
+| "Let me explore the codebase first" | Skills tell you HOW to explore. Check first. |
+| "I can check git/files quickly" | Files lack conversation context. Check for skills. |
+| "Let me gather information first" | Skills tell you HOW to gather information. |
+| "This doesn't need a formal skill" | If a skill exists, use it. |
+| "I remember this skill" | Skills evolve. Read current version. |
+| "This doesn't count as a task" | Action = task. Check for skills. |
+| "The skill is overkill" | Simple things become complex. Use it. |
+| "I'll just do this one thing first" | Check BEFORE doing anything. |
+| "This feels productive" | Undisciplined action wastes time. Skills prevent this. |
+| "I know what that means" | Knowing the concept ≠ using the skill. Invoke it. |
+
+## Skill Priority
+
+When multiple skills could apply, use this order:
+
+1. **Process skills first** (brainstorming, debugging) - these determine HOW to approach the task
+2. **Implementation skills second** (frontend-design, mcp-builder) - these guide execution
+
+"Let's build X" → brainstorming first, then implementation skills.
+"Fix this bug" → debugging first, then domain-specific skills.
+
+## Skill Types
+
+**Rigid** (TDD, debugging): Follow exactly. Don't adapt away discipline.
+
+**Flexible** (patterns): Adapt principles to context.
+
+The skill itself tells you which.
+
+## User Instructions
+
+Instructions say WHAT, not HOW. "Add X" or "Fix Y" doesn't mean skip workflows.
+
+exec
+/bin/zsh -lc 'sdlc --help' in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+sdlc collects ariadne's SDLC checkpoint guards into one binary. Each subcommand
+owns one checkpoint: it requires evidence at the gate, mutates state, logs the
+transition, and refuses transitions that lack it. We don't model the SDLC as a
+state machine — stages stay prose; we codify the gates between them where drift
+recurs. `sdlc` manages the development life cycle; prefer it over `git`/`gh`.
+
+BEFORE WORK
+  - `sdlc claim --issue N` — the single start-of-work gesture, a CHEAP LOCK.
+    Flips an *open* issue to `working` and publishes the claim to origin/main so
+    peer agents see it. No estimate demanded (#113) — claim early, the moment an
+    idea crystallizes. `--no-start` suppresses the flip.
+  - Do NOT hand-edit an issue's `status:` — let `sdlc claim` or `sdlc issue
+    set-status` own that transition (it carries the reopen/`→ done` guards).
+
+ENTER IMPLEMENTATION
+  - After plan approval, before editing code, run `sdlc change-code`. It owns the
+    branching decision (in-place branch by default; `--worktree=yes` for an
+    isolated worktree), the plan-quality check, and the `estimate_hours` gate
+    (relocated here from claim, #113). Don't start coding without it.
+
+PUBLISH
+  - Publishing goes through a PR: `sdlc pr` → `sdlc merge`. Direct `sdlc push`
+    if working directly on main.
+  - Publish ONCE at issue close, not per milestone — and do NOT reuse a branch
+    name that already has a merged PR. `sdlc merge` refuses (#148) when a branch
+    has commits not in main despite a merged PR (a reused name would otherwise
+    silently strand the new commits); rename to a fresh branch, `sdlc pr`, retry.
+
+RECOVER
+  - After a compaction or session resume, run `sdlc state` to recover where you
+    are instead of re-inferring from issue files.
+
+LOCAL REPO TRANSACTION LOCK
+  - Mutating verbs take an SDLC-owned repo transaction lock at
+    `.git/sdlc.lock` before reading/writing issue state, committing, changing
+    branches, or pushing. The lock is local to the Git common dir, so linked
+    worktrees of the same repo serialize with each other.
+  - Wait messages identify the holder pid and command when metadata is
+    available. `close` and `milestone-close` release the lock while the external
+    boundary-review subprocess runs, then reacquire before finalization; if HEAD
+    or the issue/project file state they prepared changed meanwhile, they refuse
+    to finalize and tell you to rerun. `change-code`, `merge`, and `push` can still hold the lock during
+    long-running review/ship transactions; wait or retry rather than removing
+    the lock while that process is alive.
+  - A dead same-host holder is reclaimed automatically; initializing metadata
+    is waited through. Other stale/timeout errors tell you how to inspect
+    `.git/sdlc.lock`. Remote push/ref races are separate: the local lock
+    serializes this checkout, not another machine or clone.
+
+WHEN A VERB ERRORS
+  Do NOT route around it with hand-rolled `git`/`gh`. Its errors are next-action
+  specs. The fix is one of two things:
+    (a) satisfy the precondition it names and re-run the same verb (e.g. `sdlc
+        merge` saying "no upstream" → run `sdlc pr` first, then `sdlc merge`); or
+    (b) if the error is a genuine gap in `sdlc` itself, fix that edge case in the
+        source and re-run. We're still ironing out edge cases.
+  Only drop to manual when a verb genuinely cannot express the need — say so.
+
+These gates sit inside a wider prose arc the binary does NOT own: ideation
+(parley/pensive) → brainstorm → plan → build → milestone review (`sdlc judge`,
+auto-dispatched) → close/ship → postmortem.
+
+CONVENTIONS
+
+  --issue vs --github-issue — `--issue N` always means workshop/issues
+  (6-digit ID). `--github-issue N` means a GitHub issue number. Bare `--issue`
+  never means a GitHub issue.
+
+  Form vs essence — checkpoint guards (close, milestone-close, push, merge)
+  defend against *omission* via required-evidence flags; `sdlc judge` defends
+  against *theater* via fresh-context review. Form runs first; judge second.
+
+The verb list + per-verb help (`sdlc <verb> --help`) follow below.
+
+Usage:
+  sdlc [flags]
+  sdlc [command]
+
+Available Commands:
+  claim           Start work: flip an open issue to working + broadcast the claim
+  start-plan      Enter planning: deliver the architecture principles to design against (#75)
+  change-code     Enter implementation after the structural + plan-quality gates
+  issue           Create + manage issues (new / set-status / list / show)
+  actual          Compute an issue's focused dev-hours via active-time-v3 (#68)
+  active-time     Per-issue active-time attribution table (the v3 engine, standalone)
+  close           Close an issue or milestone (ACTUAL + VERIFIED + atlas/project sweep)
+  milestone-close Close one milestone + auto-dispatch its review
+  pr              Open a pull request from a feature branch
+  merge           Merge the PR, archive done issues, clean up
+  push            Ship from main (clean tree + pre-merge judges + archive)
+  state           Inspect workflow state (branch, working issues, drift)
+  resolve         Resolve a symbolic artifact ref (ariadne#11, #15 M4) to its current path(s) — read-only
+  open            Resolve a ref and open the primary artifact in $EDITOR
+  judge           Run an LLM-judge check against the diff (fresh-context)
+  arch-principles Print the ARCH-* architecture principles (single source; pull for non-gate work)
+  estimate-source Name the shared estimate method + the repo-local calibration source (pull)
+  process-manual  Unroll every injection source into a linked process manual (#153)
+  propagate-base  Re-weave every recursive dependent of this repo (foundation-first)
+  help            Help about any command
+
+Flags:
+  -h, --help   help for sdlc
+
+Use "sdlc [command] --help" for more information about a command.
+
+exec
+/bin/zsh -lc "sed -n '1,220p' workshop/lessons.md" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+# Lessons
+
+## 2026-06-10
+- A config→data mapping written as an inline IIFE/closure in glue code is invisible to tests — a dropped or typo'd key silently degrades behavior. Extract it to a small *pure* named helper (`f(cfg) -> data`) and unit-test the mapping. (#127: the `chat_boundaries` prefix list started as an inline closure in `chat_respond`; the boundary review flagged the untested surface.)
+- Pure-but-IO-adjacent helpers belong in the *pure* module taking the config table as a param, not requiring config — keeps the core testable while quarantining the field-name knowledge in one place.
+- A template placeholder added for one creation path must be rendered through a shared helper before touching call sites. #135 added `{{status}}` to `ISSUE_TEMPLATE` and updated `create_issue`, but `cmd_issue_decompose` still called the template directly; the boundary review caught child issues that would be written with literal `status: {{status}}`. Rule: when a template gains a placeholder, grep every direct template use, extract one renderer, and test the renderer with a non-default/fake value so every creation path proves it uses the same substitution.
+
+## 2026-06-26
+- Any tool that shells out with LLM-controlled inputs must use argv-list execution and typed validation for every field before process launch. Shell-quoting only some fields is not enough: unquoted numeric/count fields can reintroduce command injection even when pattern/path strings are quoted. After hardening one shell-out family, run a sibling-tool sweep for `vim.fn.system(<string>)` and either fold matching tools into scope or file a follow-up immediately.
+
+## 2026-05-30
+- **A "line-bounded" parser's line bound is often a load-bearing blast-radius cap, not just a limitation.** `parse_markers` was line-bounded only because it fed `parse_marker_sections` one line at a time — `find_matching_bracket` itself already scanned across `\n` (drill_in relied on that). So "make it multi-line" was really "stop slicing per-line + add a bound back in." Before removing a bound that looks accidental, ask what it was silently protecting: here, an unmatched `🤖{` could only ruin one line; unbounded it would swallow to EOF. The fix kept the protection as an explicit per-section newline budget (#125).
+- **Extend a shared parser via an optional opts arg that defaults to the historical behavior — then existing callers are provably untouched.** `find_matching_bracket(text, start, open, close, opts)` with `opts.budget`/`opts.is_excluded`; `opts or {}` → `budget == nil` → unbounded, exactly as before. Only the new caller (`parse_markers`) opts in. This sidesteps the lesson-#7 trap (2-arg call sites silently losing a new return) because there's no new *return* and no signature change at the call sites — highlighter and drill_in still pass 3 args. Grep-confirm the call sites anyway.
+- **When a per-iteration budget resets, the per-marker total ≠ the budget.** A reviewer caught that the 50-line ceiling resets at each opening bracket, so a well-formed `🤖<…>[…]{…}` can span ~150 lines even though each *section* is ≤50. The runaway guarantee (a single *stray* opener is bounded) still holds, but the comment/docs claiming "~50 lines per marker" were wrong. Name the unit precisely in comments ("per section") and pin it with a test so nobody "tightens" it into a per-marker cap later.
+
+## 2026-05-07
+- **A parser shared across two semantic layers can hide an ambiguity for months.** The `🤖` marker family was used by two features (review skill / drill-in) with overlapping syntax (`🤖{T}[Q]` vs `🤖{agent}[user]`). The parser couldn't distinguish them, so each caller patched its own "is this drill-in?" heuristic (drill_in: "first section is non-empty `{}`?"). When you spot a caller-side disambiguator like that, a *third syntactic slot* (here: `<>`) is usually cleaner than a smarter heuristic. #123 introduced `<T>` as the unambiguous quoted-body marker; the heuristic disappeared and the whole strip pipeline simplified. Rule: if two callers of the same parser need to read the same parsed shape differently, the grammar is wrong, not the callers.
+- **`find_matching_bracket` only depth-tracks one bracket pair.** When extending a bracket-based grammar with a new pair (`<>`), test cross-pair interactions: `🤖<a [b> c]` parses with quoted = "a [b" because the `>` inside `[]` still closes the `<>`. If that's acceptable, **pin the behavior with a test** so a future "fix" doesn't silently change it. If not, write a parser that maintains a stack across all bracket kinds.
+- **Normalize empty-vs-absent at one boundary.** Parser produced `quoted = { text = "" }` for `🤖<>[U]`. Every downstream consumer (gather/strip/format/resolve) had to choose: treat empty as a real quote or ignore it? Picking *one* normalization site (drill_in.M.parse → `quoted = nil` when empty) lets every caller stay simple. Doing it at the parser level would be wrong (review may want to see the empty `<>` as parser truth); doing it at each consumer is duplicated logic. Drill-in is the *interpretation* layer — that's where the normalization belongs.
+- **Adding a third return value to a shared API is silently lossy at 2-arg call sites.** `_parse_marker_sections` went from `(sections, end_pos)` to `(sections, end_pos, quoted)`. Lua truncates extra returns at assignment sites, so existing callers (`local sections, end_pos = parse(...)`) keep compiling and silently miss the new info. Grep every caller and decide explicitly whether to ignore or consume the new return. Caught the highlighter via grep; missing it would have meant `<T>` spans never highlighted.
+
+## 2026-05-04
+- **Vim ex-commands that take an implicit current-buffer arg (`:undojoin`, `:write`, `:edit`, etc.) silently target the wrong buffer when called from async/scheduled callbacks.** `helpers.undojoin(buf)` accepted a buf param but called `vim.cmd.undojoin` directly — `:undojoin` operates on the current buffer, ignoring the param. The streaming path looked like it worked because users stay focused on the chat buffer during streaming; the longer-cadence spinner timer was more likely to fire during transient focus changes (autocmds, window switches), and its joins silently went to the wrong buffer. Fix: wrap in `vim.api.nvim_buf_call(buf, function() vim.cmd.undojoin() end)`. Rule: any helper that takes a `buf` parameter and dispatches a Vim ex-command must use `nvim_buf_call` — passing the param to the helper without enforcing buffer context is a contract the helper isn't actually upholding. Spotted in #80 second-pass debugging.
+- **Sanitized snapshot in `M.get_agent` (init.lua:3570) is an allow-list, not a passthrough.** Every new field added to the agent config schema must also be appended to this snapshot, or it is silently dropped before `agent_info.resolve` ever sees it. This bit #81 (tools/max_tool_iterations/tool_result_max_bytes) and bit #118 again (synthetic_system_prompt/synthetic_system_prompt_ack) — same vector. Rule: when adding a new agent-config field, grep for `M.get_agent = function` and add it there too; ship a regression test that walks `agent record → get_agent → get_agent_info → final usage` (see `tests/unit/config_tools_spec.lua` "get_agent forwards synthetic_system_prompt config" for the pattern).
+
+## 2026-04-27
+- **`string.gsub` returns 2 values; `table.insert(t, str:gsub(...))` blows up.** Lua expands the last argument of a call to all its return values. So `table.insert(out, "abc":gsub("c","d"))` passes three args (`out`, `"abd"`, `1`) and triggers `bad argument #2 to 'insert' (number expected, got string)` because the 3-arg form expects `(table, pos, value)`. The bug is silent in single-value contexts (`local x = s:gsub(...)`, concat with `..`) but bites the moment you pass the result through a variadic-aware API. Fix: bind to a local first (`local out = s:gsub(...); return out`) or wrap in parens (`return (s:gsub(...))`). Same shape applies to any function returning multiple values that ends a call's argument list.
+
+## 2026-04-11
+- **AGENTS.md overrides skill boilerplate.** The `writing-plans` skill template includes "REQUIRED: Use superpowers:subagent-driven-development" in plan headers. AGENTS.md explicitly says "Do NOT default to skills like `superpowers:subagent-driven-development`." User instructions are highest priority per the skill priority chain. Always check AGENTS.md for conflicts before copying skill boilerplate into artifacts.
+- **In autocmd callbacks, use `nvim_buf_get_name(buf)` not `ev.file`.** `ev.file` can be a relative path when the user opened the file with a relative path (e.g. `nvim workshop/file.md`). `nvim_buf_get_name(buf)` always returns the absolute path. This caused `not_chat()` to fail silently because `find_chat_root` couldn't match the relative path against configured roots.
+- **After `nvim_buf_set_name` + rename, do `write!` then `edit!`.** `nvim_buf_set_name` marks the buffer as a "new file" at the new path. Without `edit!` to reload, the next manual `:w` warns "file already exists". The `write!` forces the initial write, and `edit!` clears the new-file flag.
+
+## 2026-04-10
+- **The exchange_model is the ONLY source of truth for buffer positions.** NEVER compute positions by scanning lines, using foldexpr with backward lookups, or querying `foldlevel()`. The model knows every block's kind, size, start, and end. Any feature that needs positional information (folding, highlighting, insertion, deletion) MUST use the model. This was violated 4 times in one session: foldexpr with backward scan, foldlevel() dependency, `last_content_line()` for prompt append, re-parsing buffer on recursive calls. Every time, the model-based approach was simpler and correct.
+- **Don't commit before user tests.** When fixing a bug that requires manual verification (especially buffer layout, margins, folding), wait for user confirmation before committing. Premature commits require reverts and pollute git history.
+- **Lua empty table `{}` encodes as JSON `[]` (array), not `{}` (object).** Use `vim.empty_dict()` when an empty dict is required (e.g., Anthropic tool_use.input). This bit us when `parse_call` returned empty input for condensed tool blocks.
+- **Parser's `line_start`/`line_end` must not include margins.** Trailing and leading blank lines are margins owned by the model, not block content. The parser must trim them so `from_parsed_chat` computes correct sizes. Also applies to `🧠:`/`📝:` lines — they must be fed to `cb_append_line` so the content_blocks state machine tracks them.
+
+## 2026-04-09
+- Parley test files hardcode `/tmp/parley-*` paths (`dispatcher_spec.lua:7`, `tree_export_spec.lua:22`, etc.). Under Claude Code sandbox, `/tmp` is narrowed to `/tmp/claude` regardless of user `allowWrite` config, so all these tests fail at setup with `Vim:E739: Cannot create directory`. Fix: use `vim.fn.tempname()` or `os.getenv("TMPDIR")` instead of hardcoded `/tmp/` — it's both sandbox-friendly AND more portable. Tracked for future cleanup (not in #81 scope).
+- When adding ONLY new files (no modifications to existing code), regression risk in untouched modules is zero. A full `make test` regression gate is belt-and-suspenders, not load-bearing — individual file verification suffices if you can't run the full suite.
+- **Never have two code paths (legacy + new) coexisting in the same function for the same operation.** #90 attempted to add a model-based insert path alongside the legacy absolute-line path in `chat_respond.M.respond`. The two paths shared closure variables (`response_line`, `progress_line`) and produced conflicting buffer states. THREE rounds of "targeted fix" attempts each made things worse. Rule: if you're replacing an algorithm, REPLACE it — don't add a parallel path gated by a condition. The old path must be deleted, not left as a fallback.
+- **Use SIZE not POSITION for tracking buffer layout.** Absolute line numbers are invalidated by any insert/delete. Size-based models (exchange_model.lua) compute positions on demand from accumulated sizes, so they're always correct regardless of concurrent edits. When building buffer-mutation infrastructure, make the model the single source of truth and have callers ask "where does section K go?" rather than computing offsets themselves.
+- **When adding a new state to code that already has fragile line-offset arithmetic, refactor first — don't stack another branch.** #81 M2 Task 2.7 needed to insert a tool-loop recursion branch into `chat_respond.M.respond`'s imperative line-position chain (`response_line / response_block_lines / progress_line / response_start_line / raw_request_offset`). Each new branch added an `if recursion then +1 else +3` magic-number offset. Three manual test rounds, three distinct offset bugs (progress_line mismatch, stuck-spinner cleanup failure, suspected buffer-state corruption causing an Anthropic "assistant message prefill" rejection on a payload that looked spec-correct). The third bug was the trigger to stop patching and refactor — filed #90 to extract a pure `exchange → lines` + `positions` layer with a single mutation entry point. Rule: when you notice you're adding the Nth `+K vs +M` branch to the same code path, stop and refactor. The cost of one refactor < the cost of N+1 offset patches + the debug sessions between them.
+- **Integration tests at the wiring layer catch bugs unit tests cannot.** During #81 M1 Task 1.8 manual verification, `M.get_agent()` was found to return a sanitized agent snapshot without the `tools`/`max_tool_iterations`/`tool_result_max_bytes` fields. Each hop was unit-tested in isolation (`get_agent_info` with a fake agent table that already had `tools`; `prepare_payload` with an explicit `agent_tools` arg) but no test exercised the full chain `M.agents → get_agent → get_agent_info → prepare_payload`. The bug was caught only by inspecting a real query cache JSON after a real user interaction. Rule: for any multi-hop data flow through module boundaries, write at least one test that exercises the FULL chain with the actual modules wired up, not just mocks at each hop. For any field added to an entity (here: `agent.tools`), grep all the read-sides (functions that build derived objects from the entity) and verify each forwards the field.
+
+## 2026-03-07
+- No escaped-quote init in Makefile recipes — use newline-producing helpers + `for` loops
+- Run new Make targets against real inputs before closing
+
+## 2026-03-08
+- Run `make test-changed` after spec doc changes
+- Verify provider capabilities against provider's own docs
+- Capability rules go in `provider_params.lua`, not transport code
+- Write plan in `tasks/todo.md` before non-trivial work
+- Run `make lint` after every change; warnings = failures
+
+## 2026-03-09
+- Fast-event callbacks: no direct `nvim_*` APIs — use `vim.schedule`
+- Progress UI must handle `reasoning_content` not just tool events
+- Normalize provider progress events to shared shape (`kind`/`phase`/`message`)
+- Propagate raw progress text for display, not just coarse labels
+- `git stash` changing behavior = strong causality signal — diff the stash
+- Prefer semantic header keys (`system_prompt`) over overloaded ones (`role`)
+- Global whitespace trim can eat required terminal newlines — handle post-trim
+- When one path is fixed, narrow focus to remaining failures
+- Bottom-anchored picker: verify `scrolloff` + buffer line count, not just window height
+- Separate initial placement logic from keyboard navigation scrolling
+
+## 2026-03-11
+- UI bugs in live-only: add runtime tracing, don't stop at unit tests
+- Bottom-anchored pickers: verify visual-row vs logical-index mapping
+
+## 2026-03-13
+- ChatFinder move bugs: instrument full lifecycle in live path, not just helpers
+
+## 2026-03-25
+- Read the full existing implementation before adding a variant
+- Always handle `~/` expansion in file path resolution
+- Strip empty-content messages before sending to LLM — Anthropic rejects them
+- Sanitize inputs when extracting reusable functions (strip `cache_control`, etc.)
+- Programmatic buffer inserts don't fire `BufEnter` — trigger renders manually
+- `x or {}` default eats `nil` — use sentinel if nil has meaning
+- Cross-file picker nav: use `edit` not `split`, clamp cursor to line count
+- After `edit`, use `nvim_get_current_buf()` not stale buffer variable
+
+## 2026-03-28
+- Float picker is insert-mode — only `<C-*>` and arrow keys work as actions
+- Don't nil-guard broken state — fix the caller instead
+- Chat file paths must be relative to containing file, not cwd — use `:t` not `:~:.`
+- New keybindings must use config-driven mechanism (`chat_shortcut_*` in config.lua + `M.cmd.*`) — don't copy hardcoded patterns
+
+## 2026-03-29
+- Picker tests: don't assert mappings by numeric index (`mappings[2]`) — indices shift when new mappings are added. Look up by key name instead
+- `GROUPS` is a bash built-in variable (user's group IDs) — never use it as a custom variable name. Same caution for `RANDOM`, `SECONDS`, `LINENO`, etc.
+- `flock` is Linux-only — use `mkdir` for cross-platform locking (atomic on macOS and Linux)
+- `claude -p` in background/piped processes needs `< /dev/null` to avoid stdin timeout warnings
+- `claude -p` without `--permission-mode bypassPermissions` may silently fail when tools need approval but no TTY is available
+- Parallel agents sharing a git working directory: don't use `git status` diff to detect changes from one agent — other concurrent agents may have modified files too
+- `timeout` is GNU coreutils — not on macOS. Use `perl -e 'alarm shift; exec @ARGV'` as portable fallback
+- `wait -n` requires bash 4.3+ — macOS ships bash 3.2. Use `kill -0` polling instead
+- When a subprocess fails silently and its empty stdout is treated as "success", the feature appears to work but does nothing — always check exit codes or validate output isn't vacuous
+
+## 2026-04-06
+- Don't use `git stash` mid-task to "verify lint baseline." Pre-existing stashes in the sandbox can collide with the pop and corrupt unrelated files (Makefile got merge markers, broke `make`). To check whether warnings/errors are pre-existing, run lint on a clean clone in /tmp or just compare the warning *count* against `git show HEAD:<file>` — never disturb the working tree.
+
+## 2026-06-17
+- **When deleting/renaming a module, the atlas-sync merge gate catches stale refs a name-grep misses — reconcile EVERY atlas page, including behavioral descriptors.** Across #128 M2/M3/M4 the `sdlc merge` atlas-sync judge blocked 4× on stale atlas text that survived a `grep <module-name> atlas/`. The misses were *behavior* lines, not the module name: `atlas/modes/review.md` still said "pre/post hooks" / "shared pipeline" / ":checktime reload" after those were deleted, and `traceability.yaml` listed phantom specs (`tools_builtin_glob_spec`) renamed long ago. Rule: when a change deletes/renames a surface, grep `atlas/` for BOTH the old name AND the behaviors/tools it owned (`hooks`, `pipeline`, the old tool name, the reload verb), and walk every mode-specific page + the `## Key Files` / traceability lists — not just the primary atlas doc. Cheaper to sweep up-front than to round-trip the merge gate.
+
+## 2026-06-30 (#116)
+- **A sandbox push/network failure is NOT "can't push" — retry with the sandbox DISABLED.** `git push`/`sdlc pr`/`sdlc merge` failing with `nc: authentication method negotiation failed` (or any SSH/network/auth error) is the Claude Code sandbox blocking the *transport*, not a hard limit. Per the Bash-tool rule, retry the network op with the sandbox off (`dangerouslyDisableSandbox`) — it uses the real network/auth. This session I treated repeated push failures as a hard block and tried to hand the whole merge back to the operator; the moment I retried `git push` unsandboxed it worked, and the full `sdlc pr → merge` flow completed. Don't conclude "can't" from a sandbox network error; the *filesystem* sandbox is narrow (see the `/tmp` lesson) but network is retryable unsandboxed.
+- **Read `sdlc --help` (the workflow contract) UP FRONT — CLAUDE.md says "Read it NOW," and most SDLC surprises come from skipping it.** It lays out the whole arc (claim → `change-code` → implement → `milestone-close` per Mx → `close` → `pr` → `merge`) and the exact gotchas: PUBLISH is **`sdlc pr` → `sdlc merge`** (merge is server-side `gh pr merge` of *origin's* tip, so it needs a pushed branch AND an existing PR), and "a verb's errors are next-action specs" (e.g. `merge` "no upstream" → run `sdlc pr` first). This session I tried `sdlc merge` before `sdlc pr` and was surprised the merge was server-side — all answered in the contract I hadn't read.
+- **`sdlc milestone-close` runs the boundary review; `sdlc close --milestone Mx` does NOT** (it's the documented no-auto-judge escape). For a *reviewed* milestone close, use `milestone-close`. This session I ran `close --milestone` first — it ticked the box + logged but silently skipped the mandatory fresh-context review. (Lives only in `sdlc close --help`, not the top-level contract.)
+- **Merge CODE at issue close, not per milestone — and never reuse a branch name that already has a merged PR.** The normal model (cf. #133's seven milestones on one branch) is one branch per issue, all milestones on it, a single `sdlc pr → merge` at the end; `milestone-close` is a *local* review boundary (+ issue-sync of the tracker to main), NOT a code merge. #116 deviated: M1 shipped early via PR #95 (a prior session, to unblock #128), so when M2/M3 reused the same issue-slug branch name months later, `sdlc merge` found the merged #95 and "resumed post-merge cleanup" (switched to main, deleted the branch) WITHOUT merging the 16 new commits — they were safe on `origin`, absent from main. Rule: don't merge per milestone; if a milestone genuinely must ship early (cross-issue unblock), the continuation needs a FRESH branch name. After any merge, `git rev-list --left-right --count main...origin/<branch>` to confirm main actually advanced.
+
+## 2026-07-01 (#155)
+- **When two code paths feed a shared, tested core, the per-path GLUE still needs its own coverage — a shared-core test does not cover the seam.** #155 consolidated two message emitters into one pure `_emit_content_blocks_as_messages` and I tested it thoroughly (6 direct cases) plus the parse path (1 integration). But `build_messages_from_model` (the live/recursion path) has its own *normalization seam* — buffer read + `serialize.parse_call`/`parse_result` + malformed→text degrade — that I left with **zero** coverage, reasoning "the invariant is tested in the emitter." The close review flagged it Important: a regression in that seam (a dropped/mis-ordered block never reaching the emitter) would ship silently. Rule: after extracting a shared tested core, enumerate every *caller's* normalization/glue seam and give each an end-to-end test through the real entry point (for the live path: build a real buffer + `exchange_model` with positions driven by the model's own `block_start`, call the entry fn, assert the payload). ARCH-PURPOSE covers the core; the seams are separate deliverables.
+- **De-duplicating two parallel implementations surfaces latent divergences — treat each difference as a suspected bug, not noise.** The two emitters diverged on empty tool input: the model path coerced `{}`→`vim.empty_dict()` (JSON `{}`) while the parse path emitted a bare `{}` (JSON `[]`, which Anthropic rejects for `input`). The divergence *was* a latent bug; consolidating to one source fixed it for free. When you unify copy-paste siblings, diff their behavior line-by-line and fix the discrepancy at the single source rather than picking one arbitrarily.
+- **Never `git add -A` / `git add .` in a shared working tree — stage explicit paths.** In #157 `git add -A` swept an unrelated *untracked* user-WIP issue stub (`000158-…`) into my refit commit; the `sdlc merge` instance-conformance gate then blocked on that stub's empty `## Plan`/`## Done when`. The user (and peer agents) leave untracked files in `workshop/issues/` mid-session, so a blanket add captures work that isn't yours. Recovery: `git rm --cached <file>` + a removal commit keeps the file locally (untracked, WIP preserved) while dropping it from the branch's net `base..HEAD` diff so the gate passes. Rule: stage the exact paths you changed (`git add lua/... tests/... workshop/issues/<your-issue>.md`), and before committing run `git status --short` to eyeball for `??` files you didn't create. (Same "commit only my files" care the #155 ariadne-side commit needed.)
+
+## 2026-07-05 (#160)
+- **Run the FULL `make test` (lint + unit + integration) before claiming "suite green" in `--verified` — running specs individually skips the lint gate.** This session I ran each `PlenaryBustedFile` spec directly (all green) and wrote "go test/full suite green" in the close evidence — but never ran `make test`, whose FIRST target is `lint` (luacheck). A new `while pos <= #line do` (every branch returns → luacheck 542 "loop executed at most once") failed luacheck, so `make test` was RED at the gate while my Log claimed green. The boundary review caught it (FIX-THEN-SHIP), but nothing *prevented* the premature claim. Rule: the evidence for "green" is a full `make test` exit 0, not a hand-picked set of specs; individual `PlenaryBustedFile` runs are for the red→green TDD loop, not the final gate. (Bonus: luacheck flags a `while` whose body always returns — use `if` and let the iterator's repeated closure-calls do the looping.)
+- **A decoration-provider highlight's column math deserves a pure, tested helper — don't bury `col_start=s-1, col_end=e-1` inline in an untestable local.** The `push_artifact_refs` extmark columns (off-`iter_refs`' one-past `e`) were an off-by-one-prone conversion inside a `local function` in `highlighter.lua` (ephemeral extmarks, awkward to assert). The review flagged it Important. Fix: extract `artifact_ref.highlight_spans(line)` (pure, returns the exact 0-indexed `{col_start,col_end}`) and unit-test the columns against the literal ref text (`line:sub(col_start+1, col_end) == "ariadne#11"`, incl. the interior-space `#15 M4`); the highlighter consumes it. Pure col math + a direct assertion beats trying to test the decoration provider's redraw output.
+
+## 2026-07-07 (#161)
+- **A pure helper that consumes another module's output must have ONE test against that module's REAL output, not only synthetic inputs.** `define.context_for_selection` reads `parse_chat` fields (`ex.question.line_start`, `ex.answer.line_end`). I unit-tested it thoroughly — but only with a *synthetic* `parsed_chat` table + an injected `finder`, and the one integration test that reached the real `parse_chat` used a buffer with no exchanges (so it hit the whole-buffer fallback, never the sliced-exchange branch). Net: the field-name contract with the live parser had zero coverage — a rename in `parse_chat` would silently degrade define to whole-buffer context with green tests. The boundary review flagged it Important. Rule: injecting a dependency (finder/parser) to keep a helper pure is right, but add exactly one end-to-end case that feeds the helper the REAL producer's output and asserts the field access still works. (Same shape as the #155 "shared core tested, caller's glue seam untested" lesson — the seam here is the field-name contract.)
+- **Raw `nvim_buf_set_text` is arch-forbidden (empty allow-list in `tests/arch/buffer_mutation_spec.lua`); `nvim_buf_set_lines` is allowed in `init.lua`.** #90's buffer-mutation boundary confines span edits to `buffer_edit.lua` (set_text allow-list is `{}` = zero uses). My first R1 cut used `nvim_buf_set_text` for the `[term]` wrap → `make test` red on the arch spec (lint was clean, so I only caught it at the full-suite run, not the unit loop). Fix: wrap via `nvim_buf_set_lines` (rewrite the affected whole line(s)) — the same primitive `drill_in_visual` already uses to wrap a selection, and it's on the set_lines allow-list for `init.lua`. Rule: before reaching for `nvim_buf_set_text`/`set_lines` in a non-`buffer_edit` file, check `tests/arch/buffer_mutation_spec.lua` — prefer the set_lines whole-line rewrite that existing wrappers use.
+- **To make a decoration-only action undoable, anchor it to a text edit + reuse `projection` — `u` reverts text, never extmarks/diagnostics.** The operator wanted the define highlight+diagnostic undoable; native `u` can't touch pure decorations (review's are undoable only because a round edits text). Resolution: a minimal text edit (now the durable `[^id]` footnote reference/footer) as the anchor + reuse `skills/review/projection.lua` (`record_empty_for(pre)` + `record(post)` + `ensure_watch`). `skill_render.snapshot`/`apply_snapshot` now preserve both whole-line highlights and column spans, so the projection can restore exact term/reference decorations. In headless tests, `:undo` does NOT fire `TextChanged` — `nvim_exec_autocmds("TextChanged", {buffer=buf})` to drive the projection watcher deterministically.
+
+## 2026-07-08 (#166)
+- **Any action that can be repeated on its own output needs an idempotence test, not only an update test for the secondary data.** #166 tested that re-defining a term updated the managed footnote line, but the selected text transform still blindly appended `[^id]`, so selecting `ASIN` in `ASIN[^asin]` produced `ASIN[^asin][^asin]`. The close review caught the gap. Rule: when a feature creates both an inline reference and an external/durable record, add a repeat-on-rendered-output test that proves the inline reference is not duplicated while the external record updates.
+
+## 2026-07-08 (#167)
+- **A behavior-only fix can still require atlas if an atlas page explicitly describes that behavior.** #167 changed define highlights from whole-line to span-scoped and taught projection snapshots to preserve columns; the code and tests were right, but `atlas/chat/inline_define.md` still said whole-line/line-granular. Rule: before using `--no-atlas`, grep atlas for the feature name and the old behavior terms (`whole-line`, `line-granular`, helper names, key data fields). If any atlas page states the old behavior, update it in the same commit even when no new module or command was added.
+
+## 2026-07-08 (#169)
+- **When centralizing a policy, delete caller-local defaults that can bypass it.** #169 routed review and define diagnostics through `skill_render.format_diagnostic_message`, but `define.format_definition` still passed `width or 80`, preserving an old fallback and weakening the shared width policy. Rule: after adding a shared formatter/config helper, grep every caller for old fallback constants and add a test for the nil/default path so future callers inherit the central behavior.
+
+## 2026-07-08 (#174)
+- **`virt_lines_leftcol = true` means gutter/window-left anchoring, not buffer text-column anchoring.** #173 used it to escape Neovim's stock diagnostic-column indentation on long wrapped prose, but the follow-up screenshot showed the block starting in the line-number/sign gutter. For diagnostic text that should align with paragraph content, place the extmark at column 0 and omit `virt_lines_leftcol`; test the extmark options directly so "visible" does not regress into "misaligned."
+
+## 2026-07-08 (#175)
+- **Shared diagnostic display needs source-specific visibility predicates when sources mean different things.** Review diagnostics span an edit region and should show anywhere inside `lnum..end_lnum`; footnote diagnostics point at a precise `term[^id]` anchor and should show only when the cursor is inside `col..end_col`. A single "current line" predicate was too broad for footnotes. Rule: when multiple diagnostic sources share one renderer, test each source's visibility contract explicitly.
+
+## 2026-07-08 (#176)
+- **README snippets are consumers of user-facing UI behavior, not marketing fluff.** #176 updated atlas when footnote definitions moved from virtual lines to a centered float, but the close review caught README still saying "grey pop-under" for visual `<M-CR>`. Rule: when changing a visible command/keybinding behavior, grep README for the command, keybinding, and old UI nouns alongside atlas.
+
+codex
+I’ve loaded the mandatory workflow context and lessons. Next I’m checking the issue artifact and the actual base-to-HEAD diff so I can verify the prompt’s diff against the repository state, not just trust the pasted excerpt.
+exec
+/bin/zsh -lc "sed -n '1,260p' workshop/issues/000171-footnote-coloring.md" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+---
+id: 000171
+status: working
+deps: []
+github_issue:
+created: 2026-07-08
+updated: 2026-07-08
+estimate_hours: 0.43
+started: 2026-07-08T17:14:54-07:00
+---
+
+# footnote coloring
+
+footnote should have dedicated color. right now it uses the color of last exchange. for example, if last exchange only has open question, footnote is displayed with question color.
+
+## Problem
+
+Managed definition footnotes are appended as a final markdown footer, but chat
+highlighting treats an unanswered question as continuing to EOF. When the last
+exchange is an open question, the footer inherits `ParleyQuestion`, so footnotes
+take on the color of the last exchange instead of having a stable dedicated
+appearance.
+
+## Spec
+
+Managed definition footnote footer lines render with a dedicated
+`ParleyFootnote` highlight group in both chat and markdown buffers.
+
+The managed-footer grammar remains single-sourced with the definition feature
+(ARCH-DRY): highlighter code should consume a pure footer-range helper rather
+than duplicate the `---` + `[^id]: ...` parser.
+
+The dedicated footnote highlight must override chat block fallback coloring for
+footer rows while leaving open issue/question highlighting unchanged for ordinary
+question body lines.
+
+## Done when
+
+- A regression test covers an open question followed by a managed footnote footer.
+- Footer divider and footnote definition rows receive `ParleyFootnote`.
+- Footer rows no longer receive `ParleyQuestion` from an unanswered question block.
+- Markdown buffers can use the same dedicated footnote group.
+
+## Plan
+
+- [x] Expose a pure managed-footnote footer range helper from `parley.define`.
+- [x] Add unit coverage for the footer range helper.
+- [x] Add highlighter regression coverage for an open question followed by a managed footer.
+- [x] Apply `ParleyFootnote` in chat and markdown highlight computation.
+- [x] Update atlas highlight docs and run focused plus repo verification.
+
+## Estimate
+
+Derived via `estimate-logic-v3.1` against the repo-local calibration source from
+`sdlc estimate-source` (stale but canonical for this repo).
+
+```estimate
+model: estimate-logic-v3.1
+familiarity: 1.0
+item: issue-spec design=0.04 impl=0.00
+item: lua-neovim design=0.09 impl=0.22
+item: atlas-docs design=0.00 impl=0.02
+item: milestone-review design=0.00 impl=0.02
+total: 0.43
+```
+
+## Log
+
+### 2026-07-08
+
+- Claimed the issue and inspected the chat/markdown highlighter paths. Root
+  cause: open-question chat highlighting continues to EOF, so the final managed
+  footnote footer is colored as `ParleyQuestion`.
+- Added `define.managed_footnote_footer_range` so the footer grammar remains
+  single-sourced with the definition feature (ARCH-DRY).
+- Implemented `ParleyFootnote` for managed footer rows in both chat and markdown
+  highlight computation; chat footers now terminate open-question color fallback.
+- Verification: `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`
+  passed; `nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"`
+  passed; scoped `git diff --check -- atlas/ui/highlights.md lua/parley/define.lua
+  lua/parley/highlighter.lua tests/integration/highlighting_spec.lua
+  tests/unit/define_spec.lua workshop/issues/000171-footnote-coloring.md`
+  passed.
+- Full `make test` linted `lua` and `tests` successfully but failed in unrelated
+  `tests/unit/tools_builtin_find_spec.lua` under the parallel unit runner; that
+  same spec passed when run directly with
+  `nvim --headless -c "PlenaryBustedFile tests/unit/tools_builtin_find_spec.lua"`.
+
+exec
+/bin/zsh -lc 'git diff --name-only 4005929621a91a6e1a9a02bd048a859bb59ffb77..HEAD' in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+atlas/ui/highlights.md
+lua/parley/define.lua
+lua/parley/highlighter.lua
+tests/integration/highlighting_spec.lua
+tests/unit/define_spec.lua
+workshop/issues/000171-footnote-coloring.md
+
+exec
+/bin/zsh -lc 'git diff --stat 4005929621a91a6e1a9a02bd048a859bb59ffb77..HEAD' in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+ atlas/ui/highlights.md                      |   5 +-
+ lua/parley/define.lua                       |  12 ++
+ lua/parley/highlighter.lua                  | 206 +++++++++++++++-------------
+ tests/integration/highlighting_spec.lua     |  62 +++++++++
+ tests/unit/define_spec.lua                  |  24 ++++
+ workshop/issues/000171-footnote-coloring.md |  63 ++++++++-
+ 6 files changed, 276 insertions(+), 96 deletions(-)
+
+exec
+/bin/zsh -lc 'git status --short' in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+ M workshop/issues/000162-split-parley-into-two-different-plugins.md
+ M workshop/issues/000168-buffer-undo-operation-during-chat-generation-resulted-in-a-huge-error-message.md
+ M workshop/issues/000170-parley-chat-performance-problem.md
+
+codex
+The issue is narrow and the documented plan has no Core concepts table, so the main traceability checks are Spec/Done-when plus docs gate. I’m reading the surrounding implementation now, especially the footer parser contract and decoration-provider state handling.
+exec
+/bin/zsh -lc "nl -ba lua/parley/define.lua | sed -n '150,250p'" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+   150
+   151    --- @param id string
+   152    --- @param definition string|nil
+   153    --- @return string
+   154    function M.format_footnote_line(id, definition)
+   155        definition = trim(definition)
+   156        if definition == "" then
+   157            definition = "(no definition)"
+   158        end
+   159        return string.format("[^%s]: %s", id, definition)
+   160    end
+   161
+   162    local function is_divider(line)
+   163        return trim(line) == "---"
+   164    end
+   165
+   166    local function is_footnote_line(line)
+   167        return trim(line):match("^%[%^[^%]]+%]:") ~= nil
+   168    end
+   169
+   170    local function managed_footer_start(lines)
+   171        for i = #lines, 1, -1 do
+   172            if is_divider(lines[i]) then
+   173                local has_footnote = false
+   174                for j = i + 1, #lines do
+   175                    local line = lines[j] or ""
+   176                    if trim(line) ~= "" then
+   177                        if not is_footnote_line(line) then
+   178                            return nil
+   179                        end
+   180                        has_footnote = true
+   181                    end
+   182                end
+   183                if has_footnote then
+   184                    return i
+   185                end
+   186                return nil
+   187            end
+   188        end
+   189        return nil
+   190    end
+   191
+   192    --- Locate the final managed definition-footnote footer.
+   193    --- @param lines string[]|nil
+   194    --- @return table|nil { start_line: integer, end_line: integer } 1-based inclusive
+   195    function M.managed_footnote_footer_range(lines)
+   196        lines = lines or {}
+   197        local start = managed_footer_start(lines)
+   198        if not start then
+   199            return nil
+   200        end
+   201        return { start_line = start, end_line = #lines }
+   202    end
+   203
+   204    local function parse_footnote_line(line)
+   205        local id, definition = trim(line):match("^%[%^([^%]]+)%]:%s*(.-)%s*$")
+   206        if not id then
+   207            return nil
+   208        end
+   209        definition = trim(definition)
+   210        if definition == "" then
+   211            definition = "(no definition)"
+   212        end
+   213        return id, definition
+   214    end
+   215
+   216    local function is_term_byte(ch)
+   217        return ch:match("[%w_-]") ~= nil
+   218    end
+   219
+   220    local function expand_term_start(line, ref_start)
+   221        local start = ref_start
+   222        while start > 1 and is_term_byte(line:sub(start - 1, start - 1)) do
+   223            start = start - 1
+   224        end
+   225        return start
+   226    end
+   227
+   228    --- Derive persisted definition diagnostics from inline footnote references and
+   229    --- the final managed definition footer.
+   230    --- @param lines string[]
+   231    --- @return table[] diagnostics with 0-based columns
+   232    function M.footnote_diagnostics(lines)
+   233        lines = lines or {}
+   234        local footer = managed_footer_start(lines)
+   235        if not footer then
+   236            return {}
+   237        end
+   238
+   239        local definitions = {}
+   240        for i = footer + 1, #lines do
+   241            local id, definition = parse_footnote_line(lines[i] or "")
+   242            if id then
+   243                definitions[id] = definition
+   244            end
+   245        end
+   246
+   247        local diagnostics = {}
+   248        for lnum = 1, footer - 1 do
+   249            local line = lines[lnum] or ""
+   250            local search = 1
+
+exec
+/bin/zsh -lc "nl -ba lua/parley/highlighter.lua | sed -n '240,370p'" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+   240        for _, win in ipairs(vim.api.nvim_list_wins()) do
+   241            if vim.api.nvim_win_get_buf(win) == buf then
+   242                local ok, bounds = pcall(vim.api.nvim_win_call, win, function()
+   243                    return { top = vim.fn.line("w0"), bottom = vim.fn.line("w$") }
+   244                end)
+   245                if ok and bounds then
+   246                    local start_line = math.max(1, (bounds.top or 1) - margin)
+   247                    local end_line = math.min(line_count, (bounds.bottom or line_count) + margin)
+   248                    if start_line <= end_line then
+   249                        table.insert(ranges, { start_line = start_line, end_line = end_line })
+   250                    end
+   251                end
+   252            end
+   253        end
+   254
+   255        if #ranges == 0 and line_count > 0 then
+   256            table.insert(ranges, { start_line = 1, end_line = line_count })
+   257        end
+   258
+   259        return merge_line_ranges(ranges)
+   260    end
+   261
+   262    -- Compute desired chat highlights for a 1-indexed line range.
+   263    -- Returns a table keyed by 0-indexed row: { [row] = { {hl_group, col_start, col_end}, ... } }
+   264    -- Scans HIGHLIGHT_CONTEXT_LINES above start_line for block state context.
+   265    local function compute_chat_highlights(buf, start_line, end_line)
+   266        local result = {}
+   267        local patterns = get_chat_highlight_prefix_patterns()
+   268        local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)
+   269        local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
+   270        local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
+   271        -- While a stream is in flight for this buffer, the model has not
+   272        -- yet emitted 🧠:[END]. Assume explicit-end mode so blank-line
+   273        -- paragraph breaks inside the in-progress thinking region keep
+   274        -- their dim highlight instead of prematurely terminating the
+   275        -- block. After the stream completes (is_busy → false), the
+   276        -- lookahead-decided mode takes over and a real [END] / structural
+   277        -- marker controls termination.
+   278        local streaming = require("parley.tasker").is_busy(buf, true)
+   279        local in_block, in_code_block, in_reasoning_block, in_reasoning_explicit_end =
+   280            bootstrap_chat_highlight_state(buf, start_line, patterns, streaming)
+   281
+   282        local in_tool_block = false  -- inside 🔧:/📎: fenced content
+   283
+   284        for offset, line in ipairs(lines) do
+   285            local line_nr = start_line + offset - 1
+   286            if line:match("^%s*```") then
+   287                in_code_block = not in_code_block
+   288                -- Exiting a code block while in a tool region ends the tool region
+   289                if not in_code_block and in_tool_block then
+   290                    in_tool_block = false
+   291                end
+   292            end
+   293
+   294            local highlighted_regions = {}
+   295            local row = line_nr - 1
+   296
+   297            result[row] = result[row] or {}
+   298
+   299            push_artifact_refs(result, row, line) -- #160: navigable artifact refs
+   300
+   301            local is_footer = footer_range and line_nr >= footer_range.start_line and line_nr <= footer_range.end_line
+   302            if is_footer then
+   303                table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
+   304                in_block = false
+   305            else
+   306                local pos = 1
+   307                while true do
+   308                    local tag_start, content_start = line:find("@@", pos)
+   309                    if not tag_start then break end
+   310                    local content_end, tag_end = line:find("@@", content_start + 1)
+   311                    if not content_end then break end
+   312                    table.insert(highlighted_regions, { start = tag_start, finish = tag_end })
+   313                    table.insert(result[row], { hl_group = "ParleyTag", col_start = tag_start - 1, col_end = tag_end })
+   314                    pos = tag_end + 1
+   315                end
+   316
+   317                -- Any structural marker terminates an in-progress reasoning
+   318                -- block. This mirrors chat_parser's lenient termination so the
+   319                -- highlight tracks parse boundaries even when the model omits
+   320                -- the canonical blank-line terminator (or in pre-existing
+   321                -- chats authored under the old single-line 🧠: convention).
+   322                local is_user = line:match(patterns.user_pattern)
+   323                local is_assistant = line:match(patterns.assistant_pattern)
+   324                local is_branch = line:match(patterns.branch_pattern)
+   325                local is_local = line:match(patterns.local_pattern)
+   326                local is_summary = line:match(patterns.summary_pattern)
+   327                local is_tool_use = line:match("^🔧:")
+   328                local is_tool_result = line:match("^📎:")
+   329                if is_user or is_assistant or is_branch or is_local
+   330                    or is_summary or is_tool_use or is_tool_result then
+   331                    in_reasoning_block = false
+   332                end
+   333
+   334                if line:match(patterns.reasoning_end_pattern) then
+   335                    -- 🧠:[END] explicit terminator. Highlight the marker line
+   336                    -- itself as ParleyThinking (it's the closing delimiter of
+   337                    -- the thinking region), then close the block. Must be
+   338                    -- checked before reasoning_pattern since the END marker
+   339                    -- also starts with the reasoning prefix.
+   340                    table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
+   341                    in_reasoning_block = false
+   342                elseif line:match(patterns.reasoning_pattern) then
+   343                    table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
+   344                    in_reasoning_block = true
+   345                    -- Buffer-aware lookahead: line_nr is the current 1-indexed
+   346                    -- buffer line. Scanning the live buffer (rather than the
+   347                    -- visible `lines` slice) catches [END] markers that fall
+   348                    -- below the viewport bottom, which is the common case
+   349                    -- after the cursor has moved up into the thinking region.
+   350                    -- While streaming, force explicit-end mode (see comment at
+   351                    -- the top of compute_chat_highlights).
+   352                    if streaming then
+   353                        in_reasoning_explicit_end = true
+   354                    else
+   355                        in_reasoning_explicit_end = reasoning_block_has_end_marker(buf, line_nr, patterns)
+   356                    end
+   357                elseif is_summary or line:match("^👂:") then
+   358                    table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
+   359                elseif is_tool_use or is_tool_result then
+   360                    -- Tool block headers — dim (plumbing, not prose)
+   361                    if line:match("error=true") then
+   362                        table.insert(result[row], { hl_group = "ParleyToolError", col_start = 0, col_end = -1 })
+   363                    else
+   364                        table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
+   365                    end
+   366                    in_tool_block = true
+   367                elseif in_tool_block and not in_block then
+   368                    -- Inside tool block fenced content — dim
+   369                    table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
+   370                elseif in_reasoning_block then
+
+exec
+/bin/zsh -lc "nl -ba lua/parley/highlighter.lua | sed -n '450,555p'" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+   450    --   * a *live* 🤖 marker's section   — `[U]` chained after 🤖 / `>` / `~` / a
+   451    --                                     prior `]`/`}` close (already highlighted
+   452    --                                     ParleyReviewUser; don't double-mark it).
+   453    -- A flattened reference span's `[` follows ordinary prose, so it passes.
+   454    function M.is_reference_span(line, s, content, e)
+   455        if line:sub(e, e) == "(" then return false end
+   456        if content:sub(1, 1) == "^" then return false end
+   457        if #content < 2 then return false end
+   458        local prev = line:sub(s - 1, s - 1)
+   459        if prev == "]" or prev == "}" or prev == ">" or prev == "~" then return false end
+   460        if s > 4 and line:sub(s - 4, s - 1) == "🤖" then return false end
+   461        return true
+   462    end
+   463
+   464    -- Compute desired markdown highlights for a 1-indexed line range.
+   465    -- Returns a table keyed by 0-indexed row: { [row] = { {hl_group, col_start, col_end}, ... } }
+   466    local function compute_markdown_highlights(buf, start_line, end_line)
+   467        local result = {}
+   468        local branch_prefix = _parley.config.chat_branch_prefix or "🌿:"
+   469        local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)
+   470        local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
+   471        local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
+   472        for offset, line in ipairs(lines) do
+   473            local row = start_line + offset - 2
+   474            local line_nr = row + 1
+   475            push_artifact_refs(result, row, line) -- #160: navigable artifact refs
+   476            if footer_range and line_nr >= footer_range.start_line and line_nr <= footer_range.end_line then
+   477                result[row] = result[row] or {}
+   478                table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
+   479            end
+   480            if line:sub(1, #branch_prefix) == branch_prefix then
+   481                result[row] = result[row] or {}
+   482                table.insert(result[row], { hl_group = "ParleyChatReference", col_start = 0, col_end = -1 })
+   483            end
+   484            -- Highlight 🤖<...>[...]{...} review markers
+   485            local review = require("parley.review")
+   486            local search_start = 1
+   487            while true do
+   488                local pos = line:find("🤖", search_start, true)
+   489                if not pos then break end
+   490                local sections, end_pos, quoted, strike = review._parse_marker_sections(line, pos, 4)
+   491                if quoted then
+   492                    -- Highlight the 🤖 + `<…>` together so the whole "this marker
+   493                    -- refers to a precise quote" prefix reads as one unit.
+   494                    result[row] = result[row] or {}
+   495                    table.insert(result[row], {
+   496                        hl_group = "ParleyReviewQuoted",
+   497                        col_start = pos - 1,             -- 0-indexed pos of 🤖
+   498                        col_end = quoted.byte_end,       -- inclusive close `>`
+   499                    })
+   500                elseif strike then
+   501                    -- Strikethrough for the `~X~` content (custom rendering — we
+   502                    -- own this since markdown's strikethrough is disabled
+   503                    -- buffer-wide to avoid false positives on `~/path` tildes).
+   504                    result[row] = result[row] or {}
+   505                    table.insert(result[row], {
+   506                        hl_group = "ParleyReviewStrike",
+   507                        col_start = pos - 1,             -- 0-indexed pos of 🤖
+   508                        col_end = strike.byte_end,       -- inclusive close `~`
+   509                    })
+   510                end
+   511                for _, section in ipairs(sections) do
+   512                    local hl = section.type == "agent" and "ParleyReviewAgent" or "ParleyReviewUser"
+   513                    result[row] = result[row] or {}
+   514                    table.insert(result[row], {
+   515                        hl_group = hl,
+   516                        col_start = section.byte_start - 1,  -- 0-indexed
+   517                        col_end = section.byte_end,           -- exclusive end
+   518                    })
+   519                end
+   520                search_start = end_pos
+   521            end
+   522
+   523            -- #127: highlight drill-in referenced-span markers `[…]` left in the
+   524            -- reply (what each gathered comment points at) via the pure
+   525            -- M.is_reference_span heuristic. Disable via mark_reference_span = false.
+   526            if _parley.config.mark_reference_span ~= false then
+   527                for s, content, e in line:gmatch("()%[([^%[%]]+)%]()") do
+   528                    if M.is_reference_span(line, s, content, e) then
+   529                        result[row] = result[row] or {}
+   530                        table.insert(result[row], {
+   531                            hl_group = "ParleyReference",
+   532                            col_start = s - 1, -- 0-indexed `[`
+   533                            col_end = e - 1,   -- exclusive end (through `]`)
+   534                        })
+   535                    end
+   536                end
+   537            end
+   538        end
+   539
+   540        -- Draft-block backgrounds (=== label === / === end ===). Full-buffer
+   541        -- scan so a block opened far above the viewport still paints visible
+   542        -- body lines. Bg-only highlight; markdown fg shows through.
+   543        local blocks = scan_draft_blocks(all_lines)
+   544        local view_from = start_line - 1
+   545        local view_to = end_line - 1
+   546        for _, block in ipairs(blocks) do
+   547            local from = math.max(block.open_row, view_from)
+   548            local to = math.min(block.close_row, view_to)
+   549            for row = from, to do
+   550                result[row] = result[row] or {}
+   551                -- Multi-line range (row,0 → row+1,0) + hl_eol paints bg past EOL
+   552                -- so short and empty lines inside the block still get the shaded
+   553                -- background. Same trick diff/cursorline use.
+   554                table.insert(result[row], {
+   555                    hl_group = "ParleyDraftBlock",
+
+exec
+/bin/zsh -lc "nl -ba tests/integration/highlighting_spec.lua | sed -n '130,210p'" in /Users/xianxu/workspace/parley.nvim
+exec
+/bin/zsh -lc "nl -ba tests/integration/highlighting_spec.lua | sed -n '560,635p'" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+   130
+   131        it("applies ParleyThinking highlight to 🧠: reasoning line", function()
+   132            local buf = highlighted_buf({
+   133                "💬: Question",
+   134                "🤖:[Agent] Answer.",
+   135                "🧠: user wants to understand topic",
+   136            })
+   137            assert.is_true(has_highlight(buf, 2, "ParleyThinking"),
+   138                "Expected 'ParleyThinking' highlight on 🧠: line")
+   139        end)
+   140    end)
+   141
+   142    describe("highlight_question_block: file reference lines", function()
+   143        after_each(cleanup_bufs)
+   144
+   145        it("applies FileLoading highlight to @@ file reference lines in a question block", function()
+   146            local buf = highlighted_buf({
+   147                "💬: Check this file",
+   148                "@@/path/to/some/file.lua",
+   149                "🤖:[Agent] Done.",
+   150            })
+   151            assert.is_true(has_highlight(buf, 1, "ParleyFileReference"),
+   152                "Expected 'ParleyFileReference' highlight on @@ file reference line")
+   153        end)
+   154
+   155        it("does NOT apply ParleyFileReference highlight to @@ lines outside question blocks", function()
+   156            local buf = highlighted_buf({
+   157                "🤖:[Agent] See @@/some/file.lua here",
+   158            })
+   159            -- Row 0 is an answer line; ParleyFileReference should not be applied
+   160            assert.is_false(has_highlight(buf, 0, "ParleyFileReference"),
+   161                "ParleyFileReference should not appear on answer lines")
+   162        end)
+   163    end)
+   164
+   165    describe("highlight_question_block: managed footnote footer", function()
+   166        after_each(cleanup_bufs)
+   167
+   168        it("uses a dedicated footnote highlight instead of open-question coloring", function()
+   169            local buf = highlighted_buf({
+   170                "💬: Define ASIN",
+   171                "This question is still open.",
+   172                "",
+   173                "---",
+   174                "",
+   175                "[^asin]: Amazon Standard Identification Number.",
+   176            })
+   177
+   178            assert.is_true(has_highlight(buf, 3, "ParleyFootnote"),
+   179                "Expected the managed footer divider to use ParleyFootnote")
+   180            assert.is_true(has_highlight(buf, 5, "ParleyFootnote"),
+   181                "Expected the managed footnote definition to use ParleyFootnote")
+   182            assert.is_false(has_highlight(buf, 3, "ParleyQuestion"),
+   183                "Managed footer divider should not inherit open-question color")
+   184            assert.is_false(has_highlight(buf, 5, "ParleyQuestion"),
+   185                "Managed footnote definition should not inherit open-question color")
+   186        end)
+   187    end)
+   188
+   189    describe("decoration provider cache", function()
+   190        after_each(function()
+   191            cleanup_extra_windows()
+   192            cleanup_bufs()
+   193        end)
+   194
+   195        it("keeps highlight caches isolated per window for the same buffer", function()
+   196            local provider = capture_decoration_provider()
+   197            assert.is_table(provider)
+   198            assert.is_function(provider.on_win)
+   199            assert.is_function(provider.on_line)
+   200
+   201            local buf = vim.api.nvim_create_buf(false, true)
+   202            local lines = {}
+   203            for i = 1, 120 do
+   204                lines[i] = ("filler line %03d"):format(i)
+   205            end
+   206            lines[1] = "💬: top question"
+   207            lines[71] = "💬: lower question"
+   208            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
+   209
+   210            vim.cmd("vsplit")
+
+ succeeded in 0ms:
+   560                message = "review diagnostic",
+   561                severity = vim.diagnostic.severity.INFO,
+   562                source = "parley-skill",
+   563            } })
+   564
+   565            vim.cmd("doautocmd TextChanged")
+   566            vim.wait(100, function()
+   567                local diagnostics = vim.diagnostic.get(buf, { namespace = ns })
+   568                return #diagnostics == 1 and diagnostics[1].source == "parley-skill"
+   569            end)
+   570
+   571            vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
+   572                "here is ASIN[^asin] in context",
+   573                "",
+   574                "---",
+   575                "",
+   576                "[^asin]: Amazon Standard Identification Number.",
+   577            })
+   578            vim.cmd("doautocmd TextChanged")
+   579            vim.wait(100, function()
+   580                local diagnostics = vim.diagnostic.get(buf, { namespace = ns })
+   581                return #diagnostics == 2
+   582            end)
+   583
+   584            local by_source = {}
+   585            for _, diagnostic in ipairs(vim.diagnostic.get(buf, { namespace = ns })) do
+   586                by_source[diagnostic.source] = diagnostic
+   587            end
+   588            assert.is_not_nil(by_source["parley-skill"])
+   589            assert.is_not_nil(by_source["parley-footnote"])
+   590            assert.equals(8, by_source["parley-footnote"].col)
+   591
+   592            vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "footnote removed" })
+   593            vim.cmd("doautocmd TextChanged")
+   594            vim.wait(100, function()
+   595                local diagnostics = vim.diagnostic.get(buf, { namespace = ns })
+   596                return #diagnostics == 1 and diagnostics[1].source == "parley-skill"
+   597            end)
+   598        end)
+   599
+   600        it("renders managed footnote footers with ParleyFootnote in markdown buffers", function()
+   601            local provider = capture_decoration_provider()
+   602            local buf = vim.api.nvim_create_buf(false, true)
+   603            vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
+   604                "here is ASIN[^asin] in context",
+   605                "",
+   606                "---",
+   607                "",
+   608                "[^asin]: Amazon Standard Identification Number.",
+   609            })
+   610            parley._parley_bufs[buf] = "markdown"
+   611
+   612            local win = vim.api.nvim_get_current_win()
+   613            vim.api.nvim_win_set_buf(win, buf)
+   614            provider.on_win(nil, win, buf, 0, 4)
+   615
+   616            local original_set_extmark = vim.api.nvim_buf_set_extmark
+   617            local extmarks = {}
+   618            vim.api.nvim_buf_set_extmark = function(_, _, row, _, opts)
+   619                table.insert(extmarks, { row = row, hl_group = opts.hl_group })
+   620                return #extmarks
+   621            end
+   622
+   623            provider.on_line(nil, win, buf, 2)
+   624            provider.on_line(nil, win, buf, 4)
+   625
+   626            vim.api.nvim_buf_set_extmark = original_set_extmark
+   627
+   628            local highlighted = {}
+   629            for _, mark in ipairs(extmarks) do
+   630                if mark.hl_group == "ParleyFootnote" then
+   631                    highlighted[mark.row] = true
+   632                end
+   633            end
+   634            assert.is_true(highlighted[2], "Expected markdown footer divider to use ParleyFootnote")
+   635            assert.is_true(highlighted[4], "Expected markdown footnote definition to use ParleyFootnote")
+
+exec
+/bin/zsh -lc "nl -ba tests/unit/define_spec.lua | sed -n '220,280p'" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+   220            local text = table.concat({
+   221                "answer text",
+   222                "",
+   223                "---",
+   224                "",
+   225                "[^asin]: Amazon Standard Identification Number.",
+   226            }, "\n")
+   227
+   228            assert.equals("answer text", define.strip_definition_footnote_footer(text))
+   229        end)
+   230
+   231        it("preserves ordinary horizontal rules that are not managed footnote footers", function()
+   232            local text = table.concat({
+   233                "answer text",
+   234                "",
+   235                "---",
+   236                "",
+   237                "not a footnote",
+   238            }, "\n")
+   239
+   240            assert.equals(text, define.strip_definition_footnote_footer(text))
+   241        end)
+   242
+   243        it("reports the final managed footnote footer range", function()
+   244            local range = define.managed_footnote_footer_range({
+   245                "answer text",
+   246                "",
+   247                "---",
+   248                "",
+   249                "[^asin]: Amazon Standard Identification Number.",
+   250            })
+   251
+   252            assert.are.same({ start_line = 3, end_line = 5 }, range)
+   253        end)
+   254
+   255        it("does not report ordinary horizontal rules as managed footnote footers", function()
+   256            local range = define.managed_footnote_footer_range({
+   257                "answer text",
+   258                "",
+   259                "---",
+   260                "",
+   261                "not a footnote",
+   262            })
+   263
+   264            assert.is_nil(range)
+   265        end)
+   266
+   267        it("keeps earlier horizontal-rule content and strips only the final managed footer", function()
+   268            local text = table.concat({
+   269                "answer text",
+   270                "",
+   271                "---",
+   272                "",
+   273                "ordinary body after a rule",
+   274                "",
+   275                "---",
+   276                "",
+   277                "[^asin]: Amazon Standard Identification Number.",
+   278            }, "\n")
+   279
+   280            assert.equals(table.concat({
+
+codex
+So far the core shape matches the issue: a pure footer-range helper in `define`, reused by chat and markdown highlighting. I’m checking configuration/docs expectations now because the diff adds a new user-overridable highlight key, which may trigger the README/docs gate depending on existing config documentation.
+exec
+/bin/zsh -lc "rg -n \"user_highlights|highlight\\.|config.highlight|Parley[A-Za-z]+\" lua/parley/config.lua lua/parley/highlighter.lua README.md doc tests -g '"'!workshop/history/**'"'" in /Users/xianxu/workspace/parley.nvim
+ exited 2 in 0ms:
+rg: doc: No such file or directory (os error 2)
+lua/parley/config.lua:8:---@class ParleyConfig
+lua/parley/config.lua:40:        -- lives in the cliproxy auth-dir via :ParleyProxy login). In managed mode
+lua/parley/config.lua:115:    -- `:ParleyProxy login <provider>` (OAuth). Set manage=false to opt out.
+lua/parley/config.lua:124:        --   original opt-in default; see issue #131 spec). `:ParleyProxy update`
+lua/parley/config.lua:511:    -- default search term when using :ParleyChatFinder
+lua/parley/config.lua:634:    -- highlight those spans (ParleyReference). Set to false to strip markers
+lua/parley/config.lua:685:        -- ParleyInspectPlugin provides a detailed inspection of the plugin state
+lua/parley/config.lua:700:        -- ParleyInspectLog for checking the log file
+README.md:100:1. Run `:ParleyChatNew` (default shortcut: `<C-g>c`) to create a new chat.
+README.md:102:3. Run `:ParleyChatRespond` (default shortcut: `<C-g><C-g>`) with mouse on the question line.
+README.md:130:- `:ParleyChatNew` create a new chat
+README.md:131:- `:ParleyChatFinder` chat finder
+README.md:132:- `:ParleyChatRespond` answer current question
+README.md:133:- `:ParleyChatRespondAll` regenerate from start to cursor
+README.md:134:- `:ParleyStop` stop running generation
+README.md:135:- `:ParleyOutline` display questions in this buffer for navigation
+README.md:136:- `:ParleyKeyBindings` show active Parley keyboard shortcuts
+README.md:137:- `:ParleyAgent` switch agent
+README.md:138:- `:ParleySystemPrompt` switch system prompt
+README.md:139:- `:ParleyToggleFollowCursor` toggle live cursor-follow during streaming
+README.md:144:  - parley can **manage a local `cliproxyapi`** for you — it renders the config from Lua and lazily starts/reuses/health-checks the proxy. `:ParleyProxy status|start|stop|restart|models <provider>|providers|login <provider>|update` (bare `:ParleyProxy` prints per-subcommand help). **On by default but dormant** — only acts when a cliproxyapi-provider agent runs, and reuses an existing proxy if one is up; a fresh machine needs `brew install cliproxyapi` + a one-time `:ParleyProxy login`. Set `cliproxy = { manage = false }` to opt out. See [atlas/providers/cliproxy-managed.md](atlas/providers/cliproxy-managed.md).
+README.md:167:- `:ParleyChatDirs` opens a picker to add or remove chat roots at runtime.
+README.md:168:- `:ParleyChatDirAdd {dir}` adds a root directly, with directory completion.
+README.md:169:- `:ParleyChatDirRemove {dir}` removes a configured root directly.
+README.md:170:- `:ParleyChatMove {dir}` moves the current chat to another registered chat root.
+lua/parley/highlighter.lua:27:            hl_group = "ParleyArtifactRef",
+lua/parley/highlighter.lua:105:-- (blank lines inside the block stay highlighted as ParleyThinking).
+lua/parley/highlighter.lua:303:            table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
+lua/parley/highlighter.lua:313:                table.insert(result[row], { hl_group = "ParleyTag", col_start = tag_start - 1, col_end = tag_end })
+lua/parley/highlighter.lua:336:                -- itself as ParleyThinking (it's the closing delimiter of
+lua/parley/highlighter.lua:340:                table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
+lua/parley/highlighter.lua:343:                table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
+lua/parley/highlighter.lua:358:                table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
+lua/parley/highlighter.lua:362:                    table.insert(result[row], { hl_group = "ParleyToolError", col_start = 0, col_end = -1 })
+lua/parley/highlighter.lua:364:                    table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
+lua/parley/highlighter.lua:369:                table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
+lua/parley/highlighter.lua:375:                -- always stay dimmed as ParleyThinking.
+lua/parley/highlighter.lua:379:                    table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
+lua/parley/highlighter.lua:382:                table.insert(result[row], { hl_group = "ParleyQuestion", col_start = 0, col_end = -1 })
+lua/parley/highlighter.lua:387:                table.insert(result[row], { hl_group = "ParleyChatReference", col_start = 0, col_end = -1 })
+lua/parley/highlighter.lua:392:                table.insert(result[row], { hl_group = "ParleyQuestion", col_start = 0, col_end = -1 })
+lua/parley/highlighter.lua:399:                        table.insert(result[row], { hl_group = "ParleyFileReference", col_start = 0, col_end = -1 })
+lua/parley/highlighter.lua:405:                table.insert(result[row], { hl_group = "ParleyAnnotation", col_start = start_idx - 1, col_end = end_idx - 1 })
+lua/parley/highlighter.lua:452:--                                     ParleyReviewUser; don't double-mark it).
+lua/parley/highlighter.lua:478:            table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
+lua/parley/highlighter.lua:482:            table.insert(result[row], { hl_group = "ParleyChatReference", col_start = 0, col_end = -1 })
+lua/parley/highlighter.lua:496:                    hl_group = "ParleyReviewQuoted",
+lua/parley/highlighter.lua:506:                    hl_group = "ParleyReviewStrike",
+lua/parley/highlighter.lua:512:                local hl = section.type == "agent" and "ParleyReviewAgent" or "ParleyReviewUser"
+lua/parley/highlighter.lua:531:                        hl_group = "ParleyReference",
+lua/parley/highlighter.lua:555:                hl_group = "ParleyDraftBlock",
+lua/parley/highlighter.lua:645:    local ns_id = vim.api.nvim_create_namespace("ParleyChatExt")
+lua/parley/highlighter.lua:669:    local user_highlights = _parley.config.highlight or {}
+lua/parley/highlighter.lua:673:    if user_highlights.question then
+lua/parley/highlighter.lua:675:        vim.api.nvim_set_hl(0, "ParleyQuestion", user_highlights.question)
+lua/parley/highlighter.lua:677:        vim.api.nvim_set_hl(0, "ParleyQuestion", {
+lua/parley/highlighter.lua:683:    if user_highlights.file_reference then
+lua/parley/highlighter.lua:684:        vim.api.nvim_set_hl(0, "ParleyFileReference", user_highlights.file_reference)
+lua/parley/highlighter.lua:686:        vim.api.nvim_set_hl(0, "ParleyFileReference", {
+lua/parley/highlighter.lua:692:    if user_highlights.thinking then
+lua/parley/highlighter.lua:693:        vim.api.nvim_set_hl(0, "ParleyThinking", user_highlights.thinking)
+lua/parley/highlighter.lua:695:        vim.api.nvim_set_hl(0, "ParleyThinking", {
+lua/parley/highlighter.lua:701:    if user_highlights.tool_error then
+lua/parley/highlighter.lua:702:        vim.api.nvim_set_hl(0, "ParleyToolError", user_highlights.tool_error)
+lua/parley/highlighter.lua:704:        vim.api.nvim_set_hl(0, "ParleyToolError", {
+lua/parley/highlighter.lua:710:    if user_highlights.annotation then
+lua/parley/highlighter.lua:711:        vim.api.nvim_set_hl(0, "ParleyAnnotation", user_highlights.annotation)
+lua/parley/highlighter.lua:713:        vim.api.nvim_set_hl(0, "ParleyAnnotation", {
+lua/parley/highlighter.lua:719:    if user_highlights.chat_reference then
+lua/parley/highlighter.lua:720:        vim.api.nvim_set_hl(0, "ParleyChatReference", user_highlights.chat_reference)
+lua/parley/highlighter.lua:722:        vim.api.nvim_set_hl(0, "ParleyChatReference", {
+lua/parley/highlighter.lua:728:    if user_highlights.inline_branch then
+lua/parley/highlighter.lua:729:        vim.api.nvim_set_hl(0, "ParleyInlineBranch", user_highlights.inline_branch)
+lua/parley/highlighter.lua:731:        vim.api.nvim_set_hl(0, "ParleyInlineBranch", {
+lua/parley/highlighter.lua:740:    -- config.highlight.reference.
+lua/parley/highlighter.lua:741:    if user_highlights.reference then
+lua/parley/highlighter.lua:742:        vim.api.nvim_set_hl(0, "ParleyReference", user_highlights.reference)
+lua/parley/highlighter.lua:744:        vim.api.nvim_set_hl(0, "ParleyReference", { underline = true })
+lua/parley/highlighter.lua:749:    if user_highlights.footnote then
+lua/parley/highlighter.lua:750:        vim.api.nvim_set_hl(0, "ParleyFootnote", user_highlights.footnote)
+lua/parley/highlighter.lua:752:        vim.api.nvim_set_hl(0, "ParleyFootnote", { link = "DiagnosticHint" })
+lua/parley/highlighter.lua:757:    -- Override via config.highlight.artifact_ref.
+lua/parley/highlighter.lua:758:    if user_highlights.artifact_ref then
+lua/parley/highlighter.lua:759:        vim.api.nvim_set_hl(0, "ParleyArtifactRef", user_highlights.artifact_ref)
+lua/parley/highlighter.lua:761:        vim.api.nvim_set_hl(0, "ParleyArtifactRef", { underline = true })
+lua/parley/highlighter.lua:765:    if user_highlights.tag then
+lua/parley/highlighter.lua:766:        vim.api.nvim_set_hl(0, "ParleyTag", user_highlights.tag)
+lua/parley/highlighter.lua:768:        vim.api.nvim_set_hl(0, "ParleyTag", {
+lua/parley/highlighter.lua:774:    if user_highlights.approximate_match then
+lua/parley/highlighter.lua:775:        vim.api.nvim_set_hl(0, "ParleyPickerApproximateMatch", user_highlights.approximate_match)
+lua/parley/highlighter.lua:777:        vim.api.nvim_set_hl(0, "ParleyPickerApproximateMatch", {
+lua/parley/highlighter.lua:785:    -- via config.highlight.draft_block.
+lua/parley/highlighter.lua:786:    if user_highlights.draft_block then
+lua/parley/highlighter.lua:787:        vim.api.nvim_set_hl(0, "ParleyDraftBlock", user_highlights.draft_block)
+lua/parley/highlighter.lua:789:        vim.api.nvim_set_hl(0, "ParleyDraftBlock", { link = "CursorLine" })
+lua/parley/highlighter.lua:793:    vim.api.nvim_set_hl(0, "ParleyReviewUser", { link = "DiagnosticWarn" })
+lua/parley/highlighter.lua:795:    vim.api.nvim_set_hl(0, "ParleyReviewAgent", { link = "DiagnosticInfo" })
+lua/parley/highlighter.lua:799:    vim.api.nvim_set_hl(0, "ParleyReviewQuoted", { reverse = true, bold = true })
+lua/parley/highlighter.lua:804:    vim.api.nvim_set_hl(0, "ParleyReviewStrike", { strikethrough = true })
+lua/parley/highlighter.lua:811:    vim.api.nvim_set_hl(0, "ParleyReviewFlashDelete",
+lua/parley/highlighter.lua:813:    vim.api.nvim_set_hl(0, "ParleyReviewFlashInsert",
+lua/parley/highlighter.lua:865:-- Conceals [ and ](path), showing 🌿:text with ParleyInlineBranch style.
+lua/parley/highlighter.lua:894:                    hl_group = "ParleyInlineBranch",
+lua/parley/highlighter.lua:1006:    local gid = _parley.helpers.create_augroup("ParleyBufHandler", { clear = true })
+tests/integration/new_chat_spec.lua:1:-- Integration tests for ParleyChatNew / M.cmd.ChatNew
+tests/integration/cliproxy_dispatch_spec.lua:127:        -- :ParleyProxy stop is transient — the next dispatch revives it
+tests/integration/cliproxy_command_spec.lua:1:-- Integration test for the :ParleyProxy command registration (issue #131).
+tests/integration/cliproxy_command_spec.lua:28:describe(":ParleyProxy command", function()
+tests/integration/cliproxy_command_spec.lua:30:        assert.equals(2, vim.fn.exists(":ParleyProxy"))
+tests/integration/cliproxy_command_spec.lua:35:            vim.cmd("ParleyProxy bogus")
+tests/integration/cliproxy_command_spec.lua:44:            vim.cmd("ParleyProxy")
+tests/integration/cliproxy_command_spec.lua:57:            vim.cmd("ParleyProxy providers")
+tests/integration/cliproxy_command_spec.lua:68:            vim.cmd("ParleyProxy models")
+tests/integration/cliproxy_auth_login_spec.lua:2:-- :ParleyProxy login — resolved from parley's oauth-model-alias, not the name.
+tests/integration/highlighting_spec.lua:92:        assert.is_true(has_highlight(buf, 0, "ParleyQuestion"),
+tests/integration/highlighting_spec.lua:93:            "Expected 'ParleyQuestion' highlight on 💬: line")
+tests/integration/highlighting_spec.lua:96:    it("applies ParleyQuestion highlight to continuation lines of a question block", function()
+tests/integration/highlighting_spec.lua:103:        assert.is_true(has_highlight(buf, 0, "ParleyQuestion"))
+tests/integration/highlighting_spec.lua:104:        assert.is_true(has_highlight(buf, 1, "ParleyQuestion"),
+tests/integration/highlighting_spec.lua:105:            "Expected 'ParleyQuestion' highlight on continuation line")
+tests/integration/highlighting_spec.lua:108:    it("does NOT apply ParleyQuestion highlight to 🤖: answer lines", function()
+tests/integration/highlighting_spec.lua:113:        assert.is_false(has_highlight(buf, 1, "ParleyQuestion"),
+tests/integration/highlighting_spec.lua:114:            "Answer line should NOT have ParleyQuestion highlight")
+tests/integration/highlighting_spec.lua:127:        assert.is_true(has_highlight(buf, 2, "ParleyThinking"),
+tests/integration/highlighting_spec.lua:128:            "Expected 'ParleyThinking' highlight on 📝: line")
+tests/integration/highlighting_spec.lua:131:    it("applies ParleyThinking highlight to 🧠: reasoning line", function()
+tests/integration/highlighting_spec.lua:137:        assert.is_true(has_highlight(buf, 2, "ParleyThinking"),
+tests/integration/highlighting_spec.lua:138:            "Expected 'ParleyThinking' highlight on 🧠: line")
+tests/integration/highlighting_spec.lua:151:        assert.is_true(has_highlight(buf, 1, "ParleyFileReference"),
+tests/integration/highlighting_spec.lua:152:            "Expected 'ParleyFileReference' highlight on @@ file reference line")
+tests/integration/highlighting_spec.lua:155:    it("does NOT apply ParleyFileReference highlight to @@ lines outside question blocks", function()
+tests/integration/highlighting_spec.lua:159:        -- Row 0 is an answer line; ParleyFileReference should not be applied
+tests/integration/highlighting_spec.lua:160:        assert.is_false(has_highlight(buf, 0, "ParleyFileReference"),
+tests/integration/highlighting_spec.lua:161:            "ParleyFileReference should not appear on answer lines")
+tests/integration/highlighting_spec.lua:178:        assert.is_true(has_highlight(buf, 3, "ParleyFootnote"),
+tests/integration/highlighting_spec.lua:179:            "Expected the managed footer divider to use ParleyFootnote")
+tests/integration/highlighting_spec.lua:180:        assert.is_true(has_highlight(buf, 5, "ParleyFootnote"),
+tests/integration/highlighting_spec.lua:181:            "Expected the managed footnote definition to use ParleyFootnote")
+tests/integration/highlighting_spec.lua:182:        assert.is_false(has_highlight(buf, 3, "ParleyQuestion"),
+tests/integration/highlighting_spec.lua:184:        assert.is_false(has_highlight(buf, 5, "ParleyQuestion"),
+tests/integration/highlighting_spec.lua:239:            if mark.row == 0 and mark.hl_group == "ParleyQuestion" then
+tests/integration/highlighting_spec.lua:242:            if mark.row == 70 and mark.hl_group == "ParleyQuestion" then
+tests/integration/highlighting_spec.lua:304:            if mark.hl_group == "ParleyThinking" then
+tests/integration/highlighting_spec.lua:310:            "continuation paragraph one should be dimmed (ParleyThinking)")
+tests/integration/highlighting_spec.lua:368:            if mark.hl_group == "ParleyThinking" then
+tests/integration/highlighting_spec.lua:416:            if mark.hl_group == "ParleyQuestion" then
+tests/integration/highlighting_spec.lua:600:    it("renders managed footnote footers with ParleyFootnote in markdown buffers", function()
+tests/integration/highlighting_spec.lua:630:            if mark.hl_group == "ParleyFootnote" then
+tests/integration/highlighting_spec.lua:634:        assert.is_true(highlighted[2], "Expected markdown footer divider to use ParleyFootnote")
+tests/integration/highlighting_spec.lua:635:        assert.is_true(highlighted[4], "Expected markdown footnote definition to use ParleyFootnote")
+tests/unit/super_repo_spec.lua:558:    it("fires User ParleySuperRepoChanged on toggle on and off", function()
+tests/unit/super_repo_spec.lua:560:        local augroup = vim.api.nvim_create_augroup("ParleySuperRepoSpec", { clear = true })
+tests/unit/super_repo_spec.lua:563:            pattern = "ParleySuperRepoChanged",
+
+exec
+/bin/zsh -lc "rg -n \"highlight|ParleyFootnote|ParleyReference|DiagnosticHint|footnote\" README.md doc lua/parley tests atlas -g '"'!workshop/history/**'"'" in /Users/xianxu/workspace/parley.nvim
+ exited 2 in 0ms:
+rg: doc: No such file or directory (os error 2)
+README.md:118:- `<M-CR>` respond (normal/insert); **visual-select a phrase + `<M-CR>`** → inline term definition — adds a markdown footnote reference/footer and shows a centered diagnostic float, honoring `:ToggleWebSearch` for unfamiliar terms
+README.md:147:- Outline navigation, highlighting.
+README.md:160:- Most other top-level keys are replaced when provided (for example `chat_dir`, `chat_dirs`, `notes_dir`, `chat_template`, `raw_mode`, `highlight`, `chat_memory`, `providers`, `api_keys`).
+atlas/skills/skill-system.md:44:- `lua/parley/skill_render.lua` — the single source of `clear_decorations`/`attach_diagnostics`/`highlight_edits` (salvaged from `skill_runner`).
+atlas/skills/skill-system.md:118:- `lua/parley/skill_render.lua` — diagnostics/highlights (single source; was salvaged from skill_runner)
+atlas/index.md:15:- [Inline Term Definition](chat/inline_define.md): Visual-select a phrase + `<M-CR>` → concise context-aware definition as a managed footnote diagnostic rehydrated for markdown buffers (the `define` skill + `emit_definition` tool; honors `:ToggleWebSearch`).
+atlas/index.md:31:- [Artifact-Ref Navigation](context/artifact_refs.md): Jump from `ariadne#11` / `#15 M4` / `pair#84` under the cursor to its current file (shells to `sdlc resolve`; loose local detector, sdlc owns the grammar); smart `gf` + `ParleyArtifactRef` highlight.
+atlas/index.md:48:- [Syntax Highlighting](ui/highlights.md): Highlighting groups and rules.
+atlas/index.md:62:- [Interview Mode](modes/interview.md): Mechanics, automatic timestamps, and `{thought}` highlighting.
+atlas/traceability.yaml:71:      - lua/parley/highlighter.lua
+atlas/traceability.yaml:81:      - lua/parley/highlighter.lua
+atlas/traceability.yaml:85:      - tests/unit/highlighter_spec.lua
+atlas/traceability.yaml:106:      - lua/parley/highlighter.lua
+atlas/traceability.yaml:422:  ui/highlights:
+atlas/traceability.yaml:425:      - lua/parley/highlighter.lua
+atlas/traceability.yaml:429:      - tests/integration/highlighting_spec.lua
+lua/parley/define.lua:138:--- Convert a term into a stable markdown footnote id.
+lua/parley/define.lua:141:function M.footnote_id(term)
+lua/parley/define.lua:154:function M.format_footnote_line(id, definition)
+lua/parley/define.lua:166:local function is_footnote_line(line)
+lua/parley/define.lua:173:            local has_footnote = false
+lua/parley/define.lua:177:                    if not is_footnote_line(line) then
+lua/parley/define.lua:180:                    has_footnote = true
+lua/parley/define.lua:183:            if has_footnote then
+lua/parley/define.lua:192:--- Locate the final managed definition-footnote footer.
+lua/parley/define.lua:195:function M.managed_footnote_footer_range(lines)
+lua/parley/define.lua:204:local function parse_footnote_line(line)
+lua/parley/define.lua:228:--- Derive persisted definition diagnostics from inline footnote references and
+lua/parley/define.lua:232:function M.footnote_diagnostics(lines)
+lua/parley/define.lua:241:        local id, definition = parse_footnote_line(lines[i] or "")
+lua/parley/define.lua:303:--- Strip a final managed definition-footnote footer from text.
+lua/parley/define.lua:306:function M.strip_definition_footnote_footer(text)
+lua/parley/define.lua:325:local function replace_or_append_footnote(lines, id, definition)
+lua/parley/define.lua:328:    local footnote_line = M.format_footnote_line(id, definition)
+lua/parley/define.lua:333:                out[i] = footnote_line
+lua/parley/define.lua:337:        out[#out + 1] = footnote_line
+lua/parley/define.lua:347:    out[#out + 1] = footnote_line
+lua/parley/define.lua:351:--- Insert a markdown footnote reference after the selected text and store the
+lua/parley/define.lua:361:function M.apply_definition_footnote(lines, l1, c1, l2, c2, term, definition)
+lua/parley/define.lua:362:    local id = M.footnote_id(term)
+lua/parley/define.lua:378:    out = replace_or_append_footnote(out, id, definition)
+atlas/providers/agents.md:9:- Virtual text on first chat line: `[AgentName]`. Indicator badges render as a single `[...]` group appended after the name: `🔧` when `tools` is non-empty, `🌎` when web_search is enabled and supported (`🌎?` when unsupported). Combined example: `ToolSonnet[🔧🌎]`. Helpers `highlighter.agent_tool_badge` / `agent_web_search_badge` are the single source, shared by picker, lualine, and the buffer-top extmark.
+lua/parley/oauth.lua:42:-- Filetype hints for syntax highlighting in code fences
+lua/parley/skill_render.lua:3:-- The diagnostics/highlights rendering salvaged out of skill_runner (#128 M3),
+lua/parley/skill_render.lua:6:-- edit's `explain`, DiffChange highlights on edited regions.
+lua/parley/skill_render.lua:12:local FOOTNOTE_SOURCE = "parley-footnote"
+lua/parley/skill_render.lua:26:--- Clear previous skill diagnostics and highlights from a buffer.
+lua/parley/skill_render.lua:106:local function is_footnote_diagnostic(diagnostic)
+lua/parley/skill_render.lua:108:    return diagnostic.source == FOOTNOTE_SOURCE or user_data.parley_kind == "footnote"
+lua/parley/skill_render.lua:111:--- Rehydrate persisted managed markdown footnotes into Parley diagnostics.
+lua/parley/skill_render.lua:112:--- Existing non-footnote diagnostics in the shared namespace are preserved.
+lua/parley/skill_render.lua:114:function M.refresh_footnote_diagnostics(buf)
+lua/parley/skill_render.lua:127:        if not is_footnote_diagnostic(existing) then
+lua/parley/skill_render.lua:132:    for _, footnote in ipairs(define.footnote_diagnostics(lines)) do
+lua/parley/skill_render.lua:134:            lnum = footnote.lnum,
+lua/parley/skill_render.lua:135:            col = footnote.col,
+lua/parley/skill_render.lua:136:            end_lnum = footnote.end_lnum or footnote.lnum,
+lua/parley/skill_render.lua:137:            end_col = footnote.end_col,
+lua/parley/skill_render.lua:138:            message = define.format_definition(footnote.term or footnote.id, footnote.definition, width),
+lua/parley/skill_render.lua:141:            user_data = { parley_kind = "footnote" },
+lua/parley/skill_render.lua:186:function M.highlight_edits(buf, edits, new_content)
+lua/parley/skill_render.lua:190:        -- would spuriously highlight line 0. Deletions are oriented by their
+lua/parley/skill_render.lua:192:        -- highlight (there's no new text to mark). #133.
+lua/parley/skill_render.lua:206:                vim.api.nvim_buf_add_highlight(buf, hl_ns_id, "DiffChange", line, 0, -1)
+lua/parley/skill_render.lua:217:function M.highlight_line(buf, lnum0)
+lua/parley/skill_render.lua:219:    vim.api.nvim_buf_add_highlight(buf, hl_ns_id, "DiffChange", lnum0, 0, -1)
+lua/parley/skill_render.lua:230:function M.highlight_span(buf, lnum0, col_start, end_lnum0_or_col_end, col_end)
+lua/parley/skill_render.lua:247:--- projection record, #133 M5). Whole-line highlights stay in `hl_lines`; span
+lua/parley/skill_render.lua:248:--- highlights and diagnostics preserve columns so exact anchors can be restored.
+lua/parley/skill_render.lua:290:        vim.api.nvim_buf_add_highlight(buf, hl_ns_id, "DiffChange", line, 0, -1)
+lua/parley/skill_render.lua:293:        M.highlight_span(buf, span.lnum, span.col or 0, span.end_lnum or span.lnum, span.end_col)
+atlas/providers/tool_use.md:77:- 🔧:/📎: blocks are dimmed (`ParleyThinking` highlight = `Comment`)
+atlas/providers/tool_use.md:78:- Error results highlighted with `ParleyToolError` = `DiagnosticError`
+atlas/ui/highlights.md:4:Custom groups (`ParleyQuestion`, `ParleyFileReference`, `ParleyChatReference`, `ParleyThinking`, `ParleyAnnotation`, `ParleyReference`, `ParleyFootnote`, `ParleyPickerApproximateMatch`, `InterviewTimestamp`, `InterviewThought`) linked to standard Neovim groups. `ParleyReference` (default underline) marks drill-in `[referenced span]` brackets — see [chat/drill_in](../chat/drill_in.md). `ParleyFootnote` (default `DiagnosticHint`) marks managed definition-footnote footer lines.
+atlas/ui/highlights.md:9:- Managed definition-footnote footers (`---` + `[^id]: ...`) use
+atlas/ui/highlights.md:10:  `ParleyFootnote` in chat and markdown buffers instead of inheriting the active
+atlas/ui/highlights.md:16:  lives in `lua/parley/timezone_diagnostics.lua`; `highlighter.setup_buf_handler`
+atlas/chat/drill_in.md:49:     enclosed spans are highlighted `ParleyReference` (see Anchor inference).
+atlas/chat/drill_in.md:126:**Referenced-span brackets + highlight.** `generate_snippet` also returns the
+atlas/chat/drill_in.md:133:delimit it). The highlighter colors these spans `ParleyReference` (default
+atlas/chat/drill_in.md:134:underline; `config.highlight.reference` overrides) via a per-line matcher that
+atlas/chat/drill_in.md:135:skips markdown links `](`, checkboxes, footnote refs, and 1-char content — a
+lua/parley/float_picker.lua:662:    vim.wo[results_win].winhighlight = "CursorLine:PmenuSel"
+lua/parley/float_picker.lua:712:        -- Define highlight groups (default=true makes each call idempotent)
+lua/parley/float_picker.lua:770:        -- Apply highlights
+lua/parley/float_picker.lua:779:            vim.api.nvim_buf_add_highlight(tag_bar_buf, TAG_BAR_NS, hl,
+lua/parley/float_picker.lua:1019:    local function highlight_matches(query)
+lua/parley/float_picker.lua:1032:                        vim.api.nvim_buf_add_highlight(
+lua/parley/float_picker.lua:1042:                        vim.api.nvim_buf_add_highlight(
+lua/parley/float_picker.lua:1146:        highlight_matches(query)
+lua/parley/float_picker.lua:1470:            highlight_matches(query_text:gsub("^%s+", ""))
+lua/parley/agent_picker.lua:18:        -- web search (M1 Task 1.7 of #81). Reuse the highlighter helpers
+lua/parley/agent_picker.lua:21:        -- failure in parley.highlighter should surface loudly, not silently
+lua/parley/agent_picker.lua:24:        local highlighter = require("parley.highlighter")
+lua/parley/agent_picker.lua:25:        local tool_part = highlighter.agent_tool_badge(agent) or ""
+lua/parley/agent_picker.lua:26:        local ok_ws, web_part = pcall(highlighter.agent_web_search_badge, agent)
+atlas/chat/inline_define.md:5:phrase. The selected text stays in place and gets a markdown footnote reference
+atlas/chat/inline_define.md:6:(`ASIN[^asin]`), while the definition is stored in a managed footnote footer at
+atlas/chat/inline_define.md:7:the end of the chat transcript. Persisted managed footnotes are rehydrated into
+atlas/chat/inline_define.md:9:annotation is **undoable** — `u` reverts the footnote edit and clears both
+atlas/chat/inline_define.md:13:highlight/undo); [#166](../../workshop/issues/000166-visual-selection-definition-system-manages-footnote.md)
+atlas/chat/inline_define.md:14:made the definition durable as a managed footnote; [#167](../../workshop/issues/000167-define-diagnostic-highlight-span.md)
+atlas/chat/inline_define.md:15:narrowed the visible decoration to the selected term plus footnote reference;
+atlas/chat/inline_define.md:16:[#172](../../workshop/issues/000172-markdown-footnote-diagnostics.md)
+atlas/chat/inline_define.md:17:rehydrates persisted managed footnotes in all markdown buffers.
+atlas/chat/inline_define.md:35:   and inserts/updates a final managed footnote footer via one buffer rewrite
+atlas/chat/inline_define.md:36:   (`define.apply_definition_footnote`) — a single undo entry that anchors
+atlas/chat/inline_define.md:37:   everything; **(b)** highlights the selected term/reference span with
+atlas/chat/inline_define.md:38:   `DiffChange` (`skill_render.highlight_span`); **(c)** refreshes persisted
+atlas/chat/inline_define.md:39:   footnote diagnostics (`skill_render.refresh_footnote_diagnostics`), which
+atlas/chat/inline_define.md:45:   cursor is on the term/footnote anchor span. A no-`emit_definition` response
+atlas/chat/inline_define.md:46:   leaves no footnote reference/footer.
+atlas/chat/inline_define.md:50:Native `u` reverts *text*, not decorations. The footnote reference/footer rewrite
+atlas/chat/inline_define.md:54:(pre-footnote hash → empty snapshot), `record(buf)` (footnoted hash → the
+atlas/chat/inline_define.md:55:highlight + diagnostic), `ensure_watch(buf)`. Undoing the footnote edit lands on
+atlas/chat/inline_define.md:56:the pre-footnote content-hash → the empty snapshot renders → both decorations clear;
+atlas/chat/inline_define.md:58:highlights (`hl_spans`) and diagnostic `col`/`end_col`, while still accepting
+atlas/chat/inline_define.md:67:  mapping), `apply_definition_footnote` (durable footer transform), and
+atlas/chat/inline_define.md:68:  `strip_definition_footnote_footer` / `footnote_diagnostics` (read only a final
+atlas/chat/inline_define.md:69:  `---` block followed solely by footnotes).
+atlas/chat/inline_define.md:71:  `lua/parley/buffer_edit.lua` owns the full-buffer footnote rewrite;
+atlas/chat/inline_define.md:72:  `lua/parley/skill_render.lua` publishes footnote diagnostics; and
+atlas/chat/inline_define.md:73:  `lua/parley/highlighter.lua` refreshes them from chat and markdown lifecycle
+atlas/chat/inline_define.md:89:`---` line followed by blank lines and footnote definitions counts as the
+atlas/chat/inline_define.md:93:prompt context. `define.footnote_diagnostics` uses the same footer detector to
+atlas/chat/inline_define.md:124:- The fresh define highlight spans the selected text plus immediate `[^id]`
+atlas/chat/inline_define.md:125:  reference; rehydrated diagnostics do not recreate the DiffChange highlight.
+atlas/chat/inline_define.md:126:- `skill_render.refresh_footnote_diagnostics` owns only diagnostics tagged
+atlas/chat/inline_define.md:127:  `parley-footnote` and preserves other `parley_skill` diagnostics, so review
+atlas/chat/inline_define.md:128:  diagnostics are not cleared by markdown footnote refresh.
+atlas/chat/inline_define.md:129:- A footnote diagnostic's Parley float auto-hides when the cursor leaves its
+atlas/chat/inline_define.md:130:  term/footnote anchor span. The footnote persists in the file if saved.
+atlas/chat/inline_define.md:134:- `lua/parley/define.lua` — pure core (slice / context / format / footnote footer / diagnostics).
+atlas/chat/inline_define.md:136:- `lua/parley/highlighter.lua` — chat/markdown buffer lifecycle refresh hooks.
+atlas/chat/inline_define.md:137:- `lua/parley/skill_render.lua` — footnote diagnostic refresh in the shared namespace.
+atlas/chat/inline_define.md:138:- `lua/parley/chat_respond.lua` — strips managed footnote footer from LLM messages.
+lua/parley/review.lua:6:--   - Diagnostics / highlights: lua/parley/skill_render.lua
+lua/parley/review.lua:10:-- (tests, highlighter.lua, init.lua) continue to work unchanged. (The v1
+lua/parley/review.lua:39:-- Lazy property for _parse_marker_sections (used by highlighter.lua)
+tests/unit/highlighter_spec.lua:1:-- Unit tests for lua/parley/highlighter.lua pure predicates.
+tests/unit/highlighter_spec.lua:3:local highlighter = require("parley.highlighter")
+tests/unit/highlighter_spec.lua:6:-- compute_markdown_highlights calls it. `match` returns the first run's
+tests/unit/highlighter_spec.lua:13:    return highlighter.is_reference_span(line, s, content, e)
+tests/unit/highlighter_spec.lua:16:describe("highlighter.is_reference_span (#127)", function()
+tests/unit/highlighter_spec.lua:27:    it("rejects a footnote reference", function()
+atlas/ui/outline.md:24:- Standard `float_picker` (results + prompt), fuzzy filter with highlights
+atlas/ui/outline.md:25:- Single click selects; double-click/`<CR>` confirms with highlight flash
+tests/integration/review_diag_display_spec.lua:54:    it("renders footnote diagnostics in a centered non-focusable float without moving the diagnostic span", function()
+tests/integration/review_diag_display_spec.lua:74:            source = "parley-footnote",
+tests/integration/review_diag_display_spec.lua:105:    it("shows footnote diagnostics only while the cursor is inside the anchor span", function()
+tests/integration/review_diag_display_spec.lua:122:            source = "parley-footnote",
+tests/integration/review_diag_display_spec.lua:124:        assert.are.equal(0, #display_marks(buf), "cursor starts before the footnote anchor")
+tests/integration/review_diag_display_spec.lua:128:        assert.are.equal(1, #diagnostic_floats(), "cursor inside the footnote anchor should show diagnosis")
+lua/parley/dispatcher.lua:433:    vim.cmd("highlight default link " .. hl_handler_group .. " CursorLine")
+lua/parley/dispatcher.lua:531:            vim.api.nvim_buf_add_highlight(buf, qt.ns_id, hl_handler_group, first_line + i, 0, -1)
+tests/unit/spell_spec.lua:55:        it("accepts the highlighted item when a selection exists", function()
+tests/integration/define_spec.lua:244:    it("stores the definition as a durable footnote, highlights the term/reference span, and shows the diagnostic", function()
+tests/integration/define_spec.lua:267:        -- DiffChange highlight covers only ASIN[^asin], not the whole paragraph.
+tests/integration/define_spec.lua:269:        assert.is_not_nil(mark, "term/reference span not highlighted")
+tests/integration/define_spec.lua:310:    it("re-defining a footnoted term updates the footer without duplicating the inline reference", function()
+tests/integration/define_spec.lua:342:    it("u undoes the footnote edit + clears decorations; C-r restores them (R1)", function()
+tests/integration/define_spec.lua:352:        -- undo: the footnote edit reverts; the projection watcher (TextChanged) clears
+tests/integration/define_spec.lua:361:            :find("%[%^asin%]:", 1, false), "footnote not removed on undo")
+tests/integration/define_spec.lua:364:        assert.is_false(hl_on_line(buf, 2), "highlight not cleared on undo")
+tests/integration/define_spec.lua:366:        -- redo: footnote edit + decorations return
+tests/integration/define_spec.lua:372:        assert.is_not_nil(redone_mark, "highlight not restored on redo")
+tests/integration/define_spec.lua:382:        assert.is_true(hl_on_line(buf, 2), "highlight not restored on redo")
+tests/integration/define_spec.lua:412:            "a no-tool response must not footnote the term")
+tests/integration/highlighting_spec.lua:1:-- Integration tests for M.highlight_question_block
+tests/integration/highlighting_spec.lua:3:-- Verifies that the correct highlight groups are applied to the correct lines
+tests/integration/highlighting_spec.lua:4:-- in a chat buffer after calling highlight_question_block(buf).
+tests/integration/highlighting_spec.lua:6:-- We query applied highlights via vim.api.nvim_buf_get_extmarks with the
+tests/integration/highlighting_spec.lua:9:local tmp_dir = vim.fn.tempname() .. "-parley-highlight"
+tests/integration/highlighting_spec.lua:20:-- Helper: create a scratch buffer with the given lines and apply highlighting.
+tests/integration/highlighting_spec.lua:21:local function highlighted_buf(lines)
+tests/integration/highlighting_spec.lua:24:    parley.highlight_question_block(buf)
+tests/integration/highlighting_spec.lua:28:-- Helper: get the highlight group name applied at (0-indexed) row in buf,
+tests/integration/highlighting_spec.lua:31:local function get_highlights_on_line(buf, row)
+tests/integration/highlighting_spec.lua:46:local function has_highlight(buf, row, group)
+tests/integration/highlighting_spec.lua:47:    local groups = get_highlights_on_line(buf, row)
+tests/integration/highlighting_spec.lua:85:describe("highlight_question_block: question lines", function()
+tests/integration/highlighting_spec.lua:87:    it("applies Question highlight to 💬: line (row 0)", function()
+tests/integration/highlighting_spec.lua:88:        local buf = highlighted_buf({
+tests/integration/highlighting_spec.lua:92:        assert.is_true(has_highlight(buf, 0, "ParleyQuestion"),
+tests/integration/highlighting_spec.lua:93:            "Expected 'ParleyQuestion' highlight on 💬: line")
+tests/integration/highlighting_spec.lua:96:    it("applies ParleyQuestion highlight to continuation lines of a question block", function()
+tests/integration/highlighting_spec.lua:97:        local buf = highlighted_buf({
+tests/integration/highlighting_spec.lua:103:        assert.is_true(has_highlight(buf, 0, "ParleyQuestion"))
+tests/integration/highlighting_spec.lua:104:        assert.is_true(has_highlight(buf, 1, "ParleyQuestion"),
+tests/integration/highlighting_spec.lua:105:            "Expected 'ParleyQuestion' highlight on continuation line")
+tests/integration/highlighting_spec.lua:108:    it("does NOT apply ParleyQuestion highlight to 🤖: answer lines", function()
+tests/integration/highlighting_spec.lua:109:        local buf = highlighted_buf({
+tests/integration/highlighting_spec.lua:113:        assert.is_false(has_highlight(buf, 1, "ParleyQuestion"),
+tests/integration/highlighting_spec.lua:114:            "Answer line should NOT have ParleyQuestion highlight")
+tests/integration/highlighting_spec.lua:118:describe("highlight_question_block: thinking lines", function()
+tests/integration/highlighting_spec.lua:121:    it("applies Think highlight to 📝: summary line", function()
+tests/integration/highlighting_spec.lua:122:        local buf = highlighted_buf({
+tests/integration/highlighting_spec.lua:127:        assert.is_true(has_highlight(buf, 2, "ParleyThinking"),
+tests/integration/highlighting_spec.lua:128:            "Expected 'ParleyThinking' highlight on 📝: line")
+tests/integration/highlighting_spec.lua:131:    it("applies ParleyThinking highlight to 🧠: reasoning line", function()
+tests/integration/highlighting_spec.lua:132:        local buf = highlighted_buf({
+tests/integration/highlighting_spec.lua:137:        assert.is_true(has_highlight(buf, 2, "ParleyThinking"),
+tests/integration/highlighting_spec.lua:138:            "Expected 'ParleyThinking' highlight on 🧠: line")
+tests/integration/highlighting_spec.lua:142:describe("highlight_question_block: file reference lines", function()
+tests/integration/highlighting_spec.lua:145:    it("applies FileLoading highlight to @@ file reference lines in a question block", function()
+tests/integration/highlighting_spec.lua:146:        local buf = highlighted_buf({
+tests/integration/highlighting_spec.lua:151:        assert.is_true(has_highlight(buf, 1, "ParleyFileReference"),
+tests/integration/highlighting_spec.lua:152:            "Expected 'ParleyFileReference' highlight on @@ file reference line")
+tests/integration/highlighting_spec.lua:155:    it("does NOT apply ParleyFileReference highlight to @@ lines outside question blocks", function()
+tests/integration/highlighting_spec.lua:156:        local buf = highlighted_buf({
+tests/integration/highlighting_spec.lua:160:        assert.is_false(has_highlight(buf, 0, "ParleyFileReference"),
+tests/integration/highlighting_spec.lua:165:describe("highlight_question_block: managed footnote footer", function()
+tests/integration/highlighting_spec.lua:168:    it("uses a dedicated footnote highlight instead of open-question coloring", function()
+tests/integration/highlighting_spec.lua:169:        local buf = highlighted_buf({
+tests/integration/highlighting_spec.lua:178:        assert.is_true(has_highlight(buf, 3, "ParleyFootnote"),
+tests/integration/highlighting_spec.lua:179:            "Expected the managed footer divider to use ParleyFootnote")
+tests/integration/highlighting_spec.lua:180:        assert.is_true(has_highlight(buf, 5, "ParleyFootnote"),
+tests/integration/highlighting_spec.lua:181:            "Expected the managed footnote definition to use ParleyFootnote")
+tests/integration/highlighting_spec.lua:182:        assert.is_false(has_highlight(buf, 3, "ParleyQuestion"),
+tests/integration/highlighting_spec.lua:184:        assert.is_false(has_highlight(buf, 5, "ParleyQuestion"),
+tests/integration/highlighting_spec.lua:185:            "Managed footnote definition should not inherit open-question color")
+tests/integration/highlighting_spec.lua:195:    it("keeps highlight caches isolated per window for the same buffer", function()
+tests/integration/highlighting_spec.lua:247:        assert.is_true(saw_top, "expected first split to keep its own viewport highlight cache")
+tests/integration/highlighting_spec.lua:248:        assert.is_true(saw_bottom, "expected second split to keep its own viewport highlight cache")
+tests/integration/highlighting_spec.lua:321:        -- for this buffer, the highlighter assumes explicit-end mode
+tests/integration/highlighting_spec.lua:380:    it("restores question highlights when redraw starts inside a long unanswered question", function()
+tests/integration/highlighting_spec.lua:414:        local highlighted_rows = {}
+tests/integration/highlighting_spec.lua:417:                highlighted_rows[mark.row] = true
+tests/integration/highlighting_spec.lua:421:        assert.is_true(highlighted_rows[220] == true,
+tests/integration/highlighting_spec.lua:422:            "expected question highlight when redraw begins inside a long unanswered question")
+tests/integration/highlighting_spec.lua:423:        assert.is_true(highlighted_rows[235] == true,
+tests/integration/highlighting_spec.lua:424:            "expected continuation lines in the viewport to keep question highlight state")
+tests/integration/highlighting_spec.lua:512:describe("markdown footnote diagnostics", function()
+tests/integration/highlighting_spec.lua:525:    it("publishes persisted managed footnotes as Parley diagnostics", function()
+tests/integration/highlighting_spec.lua:536:        skill_render.refresh_footnote_diagnostics(buf)
+tests/integration/highlighting_spec.lua:543:        assert.equals("parley-footnote", diagnostics[1].source)
+tests/integration/highlighting_spec.lua:548:    it("refreshes footnote diagnostics on markdown text changes without clearing other Parley diagnostics", function()
+tests/integration/highlighting_spec.lua:555:            "no footnote yet",
+tests/integration/highlighting_spec.lua:589:        assert.is_not_nil(by_source["parley-footnote"])
+tests/integration/highlighting_spec.lua:590:        assert.equals(8, by_source["parley-footnote"].col)
+tests/integration/highlighting_spec.lua:592:        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "footnote removed" })
+tests/integration/highlighting_spec.lua:600:    it("renders managed footnote footers with ParleyFootnote in markdown buffers", function()
+tests/integration/highlighting_spec.lua:628:        local highlighted = {}
+tests/integration/highlighting_spec.lua:630:            if mark.hl_group == "ParleyFootnote" then
+tests/integration/highlighting_spec.lua:631:                highlighted[mark.row] = true
+tests/integration/highlighting_spec.lua:634:        assert.is_true(highlighted[2], "Expected markdown footer divider to use ParleyFootnote")
+tests/integration/highlighting_spec.lua:635:        assert.is_true(highlighted[4], "Expected markdown footnote definition to use ParleyFootnote")
+tests/integration/highlighting_spec.lua:664:        parley.highlight_chat_branch_refs(buf)
+tests/integration/highlighting_spec.lua:689:        parley.highlight_chat_branch_refs(buf)
+tests/integration/highlighting_spec.lua:727:        parley.highlight_chat_branch_refs(buf)
+lua/parley/exporter.lua:611:        /* Inline branch links (footnote-style) */
+lua/parley/exporter.lua:642:        /* Syntax highlighting overrides */
+lua/parley/exporter.lua:686:    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css">
+lua/parley/exporter.lua:687:    <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
+lua/parley/exporter.lua:688:    <script>hljs.highlightAll();</script>
+tests/arch/buffer_mutation_spec.lua:40:                "lua/parley/highlighter.lua",
+lua/parley/interview.lua:3:-- Interview mode: timestamp insertion, highlighting, and timer management
+lua/parley/interview.lua:13:-- Track match IDs per buffer for interview timestamp highlighting
+lua/parley/interview.lua:101:--- Add (or refresh) syntax highlighting for interview timestamp lines in a buffer.
+lua/parley/interview.lua:103:M.highlight_timestamps = function(buf)
+lua/parley/interview.lua:116:    -- Add highlighting for the entire timestamp line with very low priority (-1)
+lua/parley/interview.lua:117:    -- to ensure all search highlights (incsearch, Search, CurSearch) can take precedence
+lua/parley/interview.lua:121:    -- Add highlighting for {thought} blocks — interviewer's private thoughts
+atlas/context/artifact_refs.md:4:`#15 M4`, `pair#84`, `gh#42` — to the current file it names, and highlight refs
+atlas/context/artifact_refs.md:15:open/pick the result, highlight refs.
+atlas/context/artifact_refs.md:19:    cursor extraction + highlighting). It is NOT the grammar; an over-match is
+atlas/context/artifact_refs.md:21:    and the highlighter so the ref-shape lives once (ARCH-DRY).
+atlas/context/artifact_refs.md:32:  provider (`highlighter.lua`, shared `push_artifact_refs` in both the chat and
+atlas/context/artifact_refs.md:33:  markdown compute paths). Override via `config.highlight.artifact_ref`. Marks
+tests/integration/timer_race_spec.lua:108:        parley.highlight_chat_branch_refs(buf)
+tests/integration/timer_race_spec.lua:109:        parley.highlight_chat_branch_refs(buf)
+atlas/chat/spell_typeahead.md:24:**`<CR>` handling.** Under `noselect` nothing is auto-highlighted, so a bare
+atlas/chat/spell_typeahead.md:31:| yes   | yes       | `<C-y>`     | accept the highlighted item    |
+lua/parley/root_dir_picker.lua:59:---   initial_dir   — dir to highlight initially; optional
+lua/parley/spell.lua:57:-- live popup. Under `completeopt=noselect` nothing is ever auto-highlighted, so
+lua/parley/spell.lua:62:--   popup + selection   → <C-y>        accept the highlighted item
+lua/parley/spell.lua:68:---@param has_selection boolean # is an item highlighted
+lua/parley/lualine.lua:273:      -- web search (M1 Task 1.7 of #81). Reuse the highlighter helpers so
+lua/parley/lualine.lua:277:      local highlighter = require("parley.highlighter")
+lua/parley/lualine.lua:279:      local indicators = highlighter.agent_tool_badge(agent_conf)
+lua/parley/lualine.lua:280:        .. highlighter.agent_web_search_badge(agent_conf)
+lua/parley/lualine.lua:299:        -- ErrorMsg is the conventional red highlight group; if the colorscheme
+lua/parley/lualine.lua:340:    -- Use the hint highlight group for consistency with the in-buffer display
+lua/parley/lualine.lua:346:      -- Use highlight group names without explicitly specifying fg
+lua/parley/lualine.lua:351:        return "DiagnosticHint"
+tests/integration/review_projection_spec.lua:36:        skill_render.highlight_edits(buf, { { new_string = "reviewed" } }, content)
+lua/parley/buffer_edit.lua:117:--- Replace the entire chat buffer after a pure definition-footnote transform.
+lua/parley/artifact_ref.lua:4:-- owns a *loose* ref-shape detector (for cursor extraction + highlighting) and
+lua/parley/artifact_ref.lua:10:-- iter_refs, parse_ref_at_cursor, parse_resolve_output, highlight_spans,
+lua/parley/artifact_ref.lua:12:-- behind an injected runner). The editor wiring (highlight/keymap/picker) lives in
+lua/parley/artifact_ref.lua:13:-- highlighter.lua / keybinding_registry.lua / init.lua.
+lua/parley/artifact_ref.lua:57:-- highlight_spans(line) -> { { col_start, col_end }, ... }: the 0-indexed extmark
+lua/parley/artifact_ref.lua:59:-- nvim_buf_add_highlight/decoration convention). iter_refs' byte_end is one-past
+lua/parley/artifact_ref.lua:61:-- the col math the highlighter's push_artifact_refs consumes (so it's tested).
+lua/parley/artifact_ref.lua:62:function M.highlight_spans(line)
+lua/parley/tools/builtin/propose_edits.lua:13:-- diagnostics/highlights rendering stays driver-side (M3), not here.
+lua/parley/progress.lua:68:        vim.wo[win].winhighlight = "Normal:StatusLine" -- read as a bar
+lua/parley/highlighter.lua:2:-- Buffer decoration provider, highlight group setup, and agent display logic.
+lua/parley/highlighter.lua:19:-- so this highlights ref-*shaped* tokens (a jump on an unresolvable one just
+lua/parley/highlighter.lua:24:    for _, span in ipairs(artifact_ref.highlight_spans(line)) do
+lua/parley/highlighter.lua:70:local function get_chat_highlight_prefix_patterns()
+lua/parley/highlighter.lua:105:-- (blank lines inside the block stay highlighted as ParleyThinking).
+lua/parley/highlighter.lua:111:-- their dim highlight whenever the viewport top fell between 🧠: and
+lua/parley/highlighter.lua:135:local function bootstrap_chat_highlight_state(buf, start_line, patterns, streaming)
+lua/parley/highlighter.lua:262:-- Compute desired chat highlights for a 1-indexed line range.
+lua/parley/highlighter.lua:265:local function compute_chat_highlights(buf, start_line, end_line)
+lua/parley/highlighter.lua:267:    local patterns = get_chat_highlight_prefix_patterns()
+lua/parley/highlighter.lua:270:    local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
+lua/parley/highlighter.lua:274:    -- their dim highlight instead of prematurely terminating the
+lua/parley/highlighter.lua:280:        bootstrap_chat_highlight_state(buf, start_line, patterns, streaming)
+lua/parley/highlighter.lua:294:        local highlighted_regions = {}
+lua/parley/highlighter.lua:303:            table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
+lua/parley/highlighter.lua:312:                table.insert(highlighted_regions, { start = tag_start, finish = tag_end })
+lua/parley/highlighter.lua:319:            -- highlight tracks parse boundaries even when the model omits
+lua/parley/highlighter.lua:351:                -- the top of compute_chat_highlights).
+lua/parley/highlighter.lua:395:                    if #highlighted_regions > 0 and highlighted_regions[1].start == 1 then
+lua/parley/highlighter.lua:448:--   * footnote refs                 — `[^1]`
+lua/parley/highlighter.lua:451:--                                     prior `]`/`}` close (already highlighted
+lua/parley/highlighter.lua:464:-- Compute desired markdown highlights for a 1-indexed line range.
+lua/parley/highlighter.lua:466:local function compute_markdown_highlights(buf, start_line, end_line)
+lua/parley/highlighter.lua:471:    local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
+lua/parley/highlighter.lua:478:            table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
+lua/parley/highlighter.lua:523:        -- #127: highlight drill-in referenced-span markers `[…]` left in the
+lua/parley/highlighter.lua:531:                        hl_group = "ParleyReference",
+lua/parley/highlighter.lua:542:    -- body lines. Bg-only highlight; markdown fg shows through.
+lua/parley/highlighter.lua:574:--- highlighter, and the agent picker.
+lua/parley/highlighter.lua:656:            { "[" .. display_name .. "]", "DiagnosticHint" },
+lua/parley/highlighter.lua:662:-- Define namespace and highlighting colors for questions, annotations, and thinking
+lua/parley/highlighter.lua:663:M.setup_highlights = function()
+lua/parley/highlighter.lua:667:    -- Create theme-agnostic highlight groups that work in both light and dark themes
+lua/parley/highlighter.lua:668:    -- Check for user-defined highlight settings
+lua/parley/highlighter.lua:669:    local user_highlights = _parley.config.highlight or {}
+lua/parley/highlighter.lua:671:    -- Questions - Create a highlight that stands out but works in both themes
+lua/parley/highlighter.lua:672:    -- Link to existing highlights when possible for theme compatibility
+lua/parley/highlighter.lua:673:    if user_highlights.question then
+lua/parley/highlighter.lua:674:        -- Use user-defined highlighting if provided
+lua/parley/highlighter.lua:675:        vim.api.nvim_set_hl(0, "ParleyQuestion", user_highlights.question)
+lua/parley/highlighter.lua:683:    if user_highlights.file_reference then
+lua/parley/highlighter.lua:684:        vim.api.nvim_set_hl(0, "ParleyFileReference", user_highlights.file_reference)
+lua/parley/highlighter.lua:692:    if user_highlights.thinking then
+lua/parley/highlighter.lua:693:        vim.api.nvim_set_hl(0, "ParleyThinking", user_highlights.thinking)
+lua/parley/highlighter.lua:701:    if user_highlights.tool_error then
+lua/parley/highlighter.lua:702:        vim.api.nvim_set_hl(0, "ParleyToolError", user_highlights.tool_error)
+lua/parley/highlighter.lua:709:    -- Annotations - Use existing highlight groups that work across themes
+lua/parley/highlighter.lua:710:    if user_highlights.annotation then
+lua/parley/highlighter.lua:711:        vim.api.nvim_set_hl(0, "ParleyAnnotation", user_highlights.annotation)
+lua/parley/highlighter.lua:719:    if user_highlights.chat_reference then
+lua/parley/highlighter.lua:720:        vim.api.nvim_set_hl(0, "ParleyChatReference", user_highlights.chat_reference)
+lua/parley/highlighter.lua:728:    if user_highlights.inline_branch then
+lua/parley/highlighter.lua:729:        vim.api.nvim_set_hl(0, "ParleyInlineBranch", user_highlights.inline_branch)
+lua/parley/highlighter.lua:740:    -- config.highlight.reference.
+lua/parley/highlighter.lua:741:    if user_highlights.reference then
+lua/parley/highlighter.lua:742:        vim.api.nvim_set_hl(0, "ParleyReference", user_highlights.reference)
+lua/parley/highlighter.lua:744:        vim.api.nvim_set_hl(0, "ParleyReference", { underline = true })
+lua/parley/highlighter.lua:747:    -- Managed definition-footnote footer (`---` + `[^id]: ...`). It must be
+lua/parley/highlighter.lua:749:    if user_highlights.footnote then
+lua/parley/highlighter.lua:750:        vim.api.nvim_set_hl(0, "ParleyFootnote", user_highlights.footnote)
+lua/parley/highlighter.lua:752:        vim.api.nvim_set_hl(0, "ParleyFootnote", { link = "DiagnosticHint" })
+lua/parley/highlighter.lua:757:    -- Override via config.highlight.artifact_ref.
+lua/parley/highlighter.lua:758:    if user_highlights.artifact_ref then
+lua/parley/highlighter.lua:759:        vim.api.nvim_set_hl(0, "ParleyArtifactRef", user_highlights.artifact_ref)
+lua/parley/highlighter.lua:765:    if user_highlights.tag then
+lua/parley/highlighter.lua:766:        vim.api.nvim_set_hl(0, "ParleyTag", user_highlights.tag)
+lua/parley/highlighter.lua:769:            link = "Todo", -- Link to Todo highlight group which is highly visible in most themes
+lua/parley/highlighter.lua:773:    -- Picker typo-tolerance edits - distinct from exact Search highlights
+lua/parley/highlighter.lua:774:    if user_highlights.approximate_match then
+lua/parley/highlighter.lua:775:        vim.api.nvim_set_hl(0, "ParleyPickerApproximateMatch", user_highlights.approximate_match)
+lua/parley/highlighter.lua:785:    -- via config.highlight.draft_block.
+lua/parley/highlighter.lua:786:    if user_highlights.draft_block then
+lua/parley/highlighter.lua:787:        vim.api.nvim_set_hl(0, "ParleyDraftBlock", user_highlights.draft_block)
+lua/parley/highlighter.lua:817:    -- Use only background color to allow search highlights to show through
+lua/parley/highlighter.lua:821:        -- Explicitly don't set fg to allow other highlights to show through
+lua/parley/highlighter.lua:833:    -- Treesitter: clear strikethrough highlight groups
+lua/parley/highlighter.lua:864:-- Apply extmark-based highlighting for inline branch links [🌿:text](file).
+lua/parley/highlighter.lua:866:local function highlight_inline_branch_links(buf, ranges)
+lua/parley/highlighter.lua:909:M.highlight_chat_branch_refs = function(buf)
+lua/parley/highlighter.lua:930:    -- Always apply inline branch highlighting if present (no debounce needed)
+lua/parley/highlighter.lua:932:        highlight_inline_branch_links(buf, ranges)
+lua/parley/highlighter.lua:981:-- Apply highlighting to chat blocks in the current buffer.
+lua/parley/highlighter.lua:983:-- Production highlighting is handled by the decoration provider.
+lua/parley/highlighter.lua:984:M.highlight_question_block = function(buf)
+lua/parley/highlighter.lua:985:    local ns = M.setup_highlights()
+lua/parley/highlighter.lua:993:        local row_map = compute_chat_highlights(buf, range.start_line, range.end_line)
+lua/parley/highlighter.lua:996:                vim.api.nvim_buf_add_highlight(buf, ns, hl.hl_group, row, hl.col_start, hl.col_end)
+lua/parley/highlighter.lua:1008:    -- Register decoration provider: highlights are computed synchronously
+lua/parley/highlighter.lua:1010:    -- built-in syntax highlighting. Zero flicker, always up-to-date.
+lua/parley/highlighter.lua:1011:    local decor_ns = M.setup_highlights()
+lua/parley/highlighter.lua:1031:                row_map = compute_chat_highlights(bufnr, start_line, end_line)
+lua/parley/highlighter.lua:1033:                row_map = compute_markdown_highlights(bufnr, start_line, end_line)
+lua/parley/highlighter.lua:1044:            local highlights = cache.rows[row]
+lua/parley/highlighter.lua:1048:            if highlights then
+lua/parley/highlighter.lua:1049:                for _, hl in ipairs(highlights) do
+lua/parley/highlighter.lua:1071:                            -- highlights win over markdown syntax (which
+lua/parley/highlighter.lua:1096:            interview.highlight_timestamps(buf)
+lua/parley/highlighter.lua:1098:            skill_render.refresh_footnote_diagnostics(buf)
+lua/parley/highlighter.lua:1099:            _parley.highlight_chat_branch_refs(buf)
+lua/parley/highlighter.lua:1108:            _parley.highlight_chat_branch_refs(buf)
+lua/parley/highlighter.lua:1109:            interview.highlight_timestamps(buf)
+lua/parley/highlighter.lua:1111:            skill_render.refresh_footnote_diagnostics(buf)
+lua/parley/highlighter.lua:1113:            -- review-deletion strike (🤖~X~, rendered in compute_markdown_highlights)
+lua/parley/highlighter.lua:1131:            interview.highlight_timestamps(buf)
+lua/parley/highlighter.lua:1133:            skill_render.refresh_footnote_diagnostics(buf)
+lua/parley/highlighter.lua:1136:            interview.highlight_timestamps(buf)
+lua/parley/highlighter.lua:1138:            skill_render.refresh_footnote_diagnostics(buf)
+lua/parley/highlighter.lua:1149:            skill_render.refresh_footnote_diagnostics(buf)
+lua/parley/init.lua:3:-- A streamlined LLM chat interface for Neovim with highlighting and navigation
+lua/parley/init.lua:126:local highlighter = require("parley.highlighter")
+lua/parley/init.lua:127:highlighter.setup(M)
+lua/parley/init.lua:1111:    -- Set up custom Search highlight for better visibility of all matches
+lua/parley/init.lua:1519:    highlighter.display_agent(buf, file_name)
+lua/parley/init.lua:1527:    return highlighter.agent_display_name_with_web_search(agent_name, ag_conf)
+lua/parley/init.lua:1597:-- footnote (ONE undo entry — the anchor), highlights the selected term/reference
+lua/parley/init.lua:1600:-- the footnote edit lands on the pre-edit content-hash → the empty snapshot
+lua/parley/init.lua:1606:    -- silently doing nothing, and leave no footnote edit.
+lua/parley/init.lua:1627:    -- rather than attach a footnote reference to shifted text.
+lua/parley/init.lua:1635:    -- Store the definition as a markdown footnote in ONE full-buffer set_lines
+lua/parley/init.lua:1640:    local e = define.apply_definition_footnote(lines, sr, sc - 1, er, ec - 1, input.term or phrase, input.definition)
+lua/parley/init.lua:1644:    skill_render.highlight_span(buf, diag_span.lnum, diag_span.col, diag_span.end_lnum, diag_span.end_col)
+lua/parley/init.lua:1645:    skill_render.refresh_footnote_diagnostics(buf)
+lua/parley/init.lua:1647:    -- Record projection states so undo/redo of the footnote edit clears/restores
+lua/parley/init.lua:1649:    -- snapshot, footnoted hash → highlight+diagnostic; attach the watcher.
+lua/parley/init.lua:1990:        M.highlight_chat_branch_refs(buf)
+lua/parley/init.lua:2018:        M.highlight_chat_branch_refs(buf)
+lua/parley/init.lua:2039:        -- `hlsearch` setting govern highlight — don't force the global flag on
+lua/parley/init.lua:2235:-- Define namespace and highlighting colors for questions, annotations, and thinking
+lua/parley/init.lua:2236:M.setup_highlight = function()
+lua/parley/init.lua:2237:    return highlighter.setup_highlights()
+lua/parley/init.lua:2244:M.highlight_chat_branch_refs = function(buf)
+lua/parley/init.lua:2245:    highlighter.highlight_chat_branch_refs(buf)
+lua/parley/init.lua:2248:-- Apply highlighting to chat blocks in the current buffer.
+lua/parley/init.lua:2250:-- Production highlighting is handled by the decoration provider.
+lua/parley/init.lua:2251:M.highlight_question_block = function(buf)
+lua/parley/init.lua:2252:    highlighter.highlight_question_block(buf)
+lua/parley/init.lua:2281:        M.highlight_chat_branch_refs(buf)
+lua/parley/init.lua:2310:        M.highlight_chat_branch_refs(buf)
+lua/parley/init.lua:2385:    highlighter.setup_buf_handler()
+lua/parley/chat_respond.lua:378:                text = define.strip_definition_footnote_footer(text)
+lua/parley/chat_respond.lua:390:                local text = define.strip_definition_footnote_footer(read_block_text(k, b))
+lua/parley/chat_respond.lua:409:                    table.insert(answer_blocks, { type = "text", text = define.strip_definition_footnote_footer(text) })
+lua/parley/chat_respond.lua:427:                    table.insert(messages, { role = "user", content = define.strip_definition_footnote_footer(text) })
+lua/parley/chat_respond.lua:616:                copy.text = define.strip_definition_footnote_footer(copy.text)
+lua/parley/chat_respond.lua:702:                    local question_content = define.strip_definition_footnote_footer(exchange.question.content)
+lua/parley/chat_respond.lua:807:                        table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.answer.content) })
+lua/parley/chat_respond.lua:812:                        table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.summary.content) })
+lua/parley/chat_respond.lua:820:                            table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.answer.content) })
+lua/parley/chat_respond.lua:1170:    -- see what the gathered comment points at (highlighted via ParleyReference).
+lua/parley/chat_respond.lua:1216:            -- (highlights, post-stream cursor moves) lands on the new turn.
+lua/parley/chat_respond.lua:1274:            local highlight_start = parsed_chat.exchanges[exchange_idx].question.line_start
+lua/parley/chat_respond.lua:1275:            vim.api.nvim_buf_add_highlight(buf, ns_id, "DiffAdd", highlight_start - 1, 0, -1)
+lua/parley/chat_respond.lua:1277:            -- Always schedule the highlight to clear after a brief delay
+lua/parley/chat_respond.lua:1930:                -- Refresh interview timestamps (decoration provider handles chat highlights)
+lua/parley/chat_respond.lua:1932:                interview.highlight_timestamps(buf)
+lua/parley/chat_respond.lua:2173:    local highlight_start = question.line_start
+lua/parley/chat_respond.lua:2174:    vim.api.nvim_buf_add_highlight(buf, ns_id, "DiffAdd", highlight_start - 1, 0, -1)
+lua/parley/chat_respond.lua:2177:    _parley.helpers.cursor_to_line(highlight_start, buf, win)
+lua/parley/chat_respond.lua:2179:    -- Schedule highlight to clear after processing is complete
+tests/unit/artifact_ref_spec.lua:55:describe("highlight_spans", function()
+tests/unit/artifact_ref_spec.lua:57:    -- highlighter paints. Off-by-one here would mis-underline; pin it exactly.
+tests/unit/artifact_ref_spec.lua:60:        local spans = ar.highlight_spans(line)
+tests/unit/artifact_ref_spec.lua:70:        local spans = ar.highlight_spans(line)
+lua/parley/config.lua:505:    -- how long review edit highlights persist (ms)
+lua/parley/config.lua:506:    review_highlight_duration = 2000,
+lua/parley/config.lua:634:    -- highlight those spans (ParleyReference). Set to false to strip markers
+lua/parley/config.lua:638:    -- highlight styling (set to nil to use defaults that match your colorscheme)
+lua/parley/config.lua:639:    -- these settings override the default highlight links if provided
+lua/parley/config.lua:640:    highlight = {
+lua/parley/config.lua:641:        -- Use existing highlight groups by default (nil values)
+lua/parley/config.lua:642:        question = nil, -- highlight for user questions (default: links to Keyword)
+lua/parley/config.lua:643:        file_reference = nil, -- highlight for file references (default: links to WarningMsg)
+lua/parley/config.lua:644:        thinking = nil, -- highlight for reasoning lines (default: links to Comment)
+lua/parley/config.lua:645:        annotation = nil, -- highlight for annotations (default: links to DiffAdd)
+lua/parley/config.lua:646:        approximate_match = nil, -- highlight for typo-tolerance edit positions in picker matches (default: links to IncSearch)
+lua/parley/config.lua:647:        chat_reference = nil, -- highlight for 🌿: chat branch/parent links (default: links to Special)
+lua/parley/config.lua:648:        reference = nil, -- highlight for [referenced span] markers left by drill-in (#127) (default: underline)
+tests/unit/float_picker_spec.lua:743:        it("keeps exact prefix matches on the exact highlight path only", function()
+lua/parley/skill_invoke.lua:53:-- Build the diagnostics/highlight edit list for a propose_edits call from its
+lua/parley/skill_invoke.lua:73:                -- "why" diagnostic, not a highlight (skill_render skips it). #133
+lua/parley/skill_invoke.lua:79:    skill_render.highlight_edits(buf, edits, new_content)
+lua/parley/skills/review/init.lua:79:-- highlighter and drill_in callers) yields the historical single-text behavior.
+lua/parley/skills/review/init.lua:325:-- Expose for highlighter.lua backward compatibility
+lua/parley/outline.lua:180:    vim.api.nvim_buf_add_highlight(hl_buf, ns_id, "DiffAdd", safe_lnum - 1, 0, -1)
+lua/parley/skills/review/diag_display.lua:114:    if diagnostic.source == "parley-footnote" then
+lua/parley/skills/review/diag_display.lua:175:    local footnote_diagnostics = {}
+lua/parley/skills/review/diag_display.lua:178:            if diagnostic.source == "parley-footnote" then
+lua/parley/skills/review/diag_display.lua:179:                table.insert(footnote_diagnostics, diagnostic)
+lua/parley/skills/review/diag_display.lua:186:    table.sort(footnote_diagnostics, function(a, b)
+lua/parley/skills/review/diag_display.lua:189:    show_float(footnote_diagnostics)
+tests/unit/skill_render_spec.lua:2:-- helpers (INFO diagnostics + DiffChange highlights for applied skill edits).
+tests/unit/skill_render_spec.lua:34:    it("highlight_edits runs without error on edited regions", function()
+tests/unit/skill_render_spec.lua:36:        -- should not raise; highlights the line containing new_string
+tests/unit/skill_render_spec.lua:37:        skill_render.highlight_edits(buf, { { new_string = "BETA" } }, "alpha\nBETA\ngamma")
+tests/unit/skill_render_spec.lua:40:    it("a non-empty edit produces highlight extmarks", function()
+tests/unit/skill_render_spec.lua:42:        skill_render.highlight_edits(buf, { { new_string = "BETA" } }, "alpha\nBETA\ngamma")
+tests/unit/skill_render_spec.lua:48:    it("a deletion (empty new_string) gets a gutter diagnostic but no highlight", function()
+tests/unit/skill_render_spec.lua:55:        skill_render.highlight_edits(buf, edits, new_content)
+tests/unit/skill_render_spec.lua:60:        -- no highlight: empty new_string is skipped (would've spuriously hit line 0)
+tests/unit/skill_render_spec.lua:96:    it("snapshot captures highlights + diagnostics; apply_snapshot restores them", function()
+tests/unit/skill_render_spec.lua:99:        skill_render.highlight_edits(buf, { { new_string = "line two" } }, content)
+tests/unit/skill_render_spec.lua:116:    it("snapshot captures and restores highlight and diagnostic column spans", function()
+tests/unit/skill_render_spec.lua:121:        skill_render.highlight_span(buf, 0, 8, 19)
+tests/unit/markdown_draft_block_spec.lua:1:-- Unit tests for the draft-block scanner in highlighter.lua.
+tests/unit/markdown_draft_block_spec.lua:6:local highlighter = require("parley.highlighter")
+tests/unit/markdown_draft_block_spec.lua:7:local scan = highlighter._scan_draft_blocks
+tests/unit/picker_items_spec.lua:149:-- highlighter.agent_tool_badge — DRY helper shared by picker, highlighter
+tests/unit/picker_items_spec.lua:153:describe("highlighter.agent_tool_badge", function()
+tests/unit/picker_items_spec.lua:154:    local highlighter = require("parley.highlighter")
+tests/unit/picker_items_spec.lua:160:        assert.equals("🔧", highlighter.agent_tool_badge({ tools = { "read_file" } }))
+tests/unit/picker_items_spec.lua:164:        assert.equals("", highlighter.agent_tool_badge(nil))
+tests/unit/picker_items_spec.lua:168:        assert.equals("", highlighter.agent_tool_badge({ provider = "anthropic" }))
+tests/unit/picker_items_spec.lua:172:        assert.equals("", highlighter.agent_tool_badge({ tools = {} }))
+tests/unit/picker_items_spec.lua:176:        assert.equals("", highlighter.agent_tool_badge({ tools = "read_file" }))
+tests/unit/picker_items_spec.lua:180:describe("highlighter.agent_display_name_with_web_search includes tool badge", function()
+tests/unit/picker_items_spec.lua:181:    local highlighter = require("parley.highlighter")
+tests/unit/picker_items_spec.lua:190:        local name = highlighter.agent_display_name_with_web_search("TestAgent", {
+tests/unit/picker_items_spec.lua:201:        local name = highlighter.agent_display_name_with_web_search("TestAgent", {
+tests/unit/define_spec.lua:145:describe("define durable footnotes", function()
+tests/unit/define_spec.lua:146:    it("slugifies a definition term into a markdown footnote id", function()
+tests/unit/define_spec.lua:148:            define.footnote_id("Amazon Standard Identification Number"))
+tests/unit/define_spec.lua:149:        assert.equals("asin", define.footnote_id("ASIN"))
+tests/unit/define_spec.lua:152:    it("adds an inline footnote reference and appends a managed footer", function()
+tests/unit/define_spec.lua:153:        local result = define.apply_definition_footnote(
+tests/unit/define_spec.lua:172:    it("updates an existing managed footnote instead of duplicating it", function()
+tests/unit/define_spec.lua:173:        local result = define.apply_definition_footnote(
+tests/unit/define_spec.lua:196:        local result = define.apply_definition_footnote(
+tests/unit/define_spec.lua:219:    it("strips only a final managed footnote footer", function()
+tests/unit/define_spec.lua:228:        assert.equals("answer text", define.strip_definition_footnote_footer(text))
+tests/unit/define_spec.lua:231:    it("preserves ordinary horizontal rules that are not managed footnote footers", function()
+tests/unit/define_spec.lua:237:            "not a footnote",
+tests/unit/define_spec.lua:240:        assert.equals(text, define.strip_definition_footnote_footer(text))
+tests/unit/define_spec.lua:243:    it("reports the final managed footnote footer range", function()
+tests/unit/define_spec.lua:244:        local range = define.managed_footnote_footer_range({
+tests/unit/define_spec.lua:255:    it("does not report ordinary horizontal rules as managed footnote footers", function()
+tests/unit/define_spec.lua:256:        local range = define.managed_footnote_footer_range({
+tests/unit/define_spec.lua:261:            "not a footnote",
+tests/unit/define_spec.lua:286:        }, "\n"), define.strip_definition_footnote_footer(text))
+tests/unit/define_spec.lua:289:    it("extracts persisted footnote diagnostics from the managed footer", function()
+tests/unit/define_spec.lua:290:        local diagnostics = define.footnote_diagnostics({
+tests/unit/define_spec.lua:309:    it("extracts every inline reference to a managed footnote", function()
+tests/unit/define_spec.lua:310:        local diagnostics = define.footnote_diagnostics({
+tests/unit/define_spec.lua:339:    it("ignores footnotes that are not in a final managed footer", function()
+tests/unit/define_spec.lua:340:        local diagnostics = define.footnote_diagnostics({
+lua/parley/tools/serialize.lua:62:    -- Opening fence carries the "json" info string for syntax-highlight
+atlas/modes/interview.md:8:- `InterviewTimestamp` highlight group on timestamp lines
+atlas/modes/interview.md:9:- `InterviewThought` highlight group on `{thought text}` blocks (linked to `DiagnosticInfo`)
+tests/unit/build_messages_spec.lua:707:describe("_build_messages: durable definition footnotes", function()
+tests/unit/build_messages_spec.lua:708:    it("strips managed definition footnote footers from user and assistant content", function()
+tests/unit/build_messages_spec.lua:751:            "second half, not a footnote",
+tests/unit/build_messages_spec.lua:1605:describe("build_messages_from_model: durable definition footnotes", function()
+tests/unit/build_messages_spec.lua:1608:    it("strips managed footnote footers from live question and answer blocks", function()
+atlas/modes/review.md:15:edits are oriented by `DiffChange` highlights + INFO gutter diagnostics that
+atlas/modes/review.md:17:deletions show only the gutter "why" (no highlight).
+atlas/modes/review.md:44:- `<>`/`[]`/`{}` sections may span **multiple lines**, each bounded to ~50 lines (per-section budget) so a stray opener can't swallow the document; `~D~` strike stays single-line (added in #125). `parse_markers` parses over the whole buffer joined (offset→line/col map) rather than line-by-line; `find_matching_bracket` takes an optional `{budget, is_excluded}` so the shared `_parse_marker_sections` (highlighter, drill_in) keeps its single-text behavior. Unterminated openers fall back to silent non-recognition.
+atlas/modes/review.md:79:- **Rendering**: `lua/parley/skill_render.lua` — diagnostics + edit highlights
+atlas/modes/review.md:176:The same controller also renders managed footnote diagnostics; those use a
+atlas/modes/review.md:178:cursor is inside the term/`[^footnote]` diagnostic span.
+atlas/modes/review.md:196:review_highlight_duration = 2000, -- highlight fade time in ms
+atlas/modes/review.md:217:- `lua/parley/skill_render.lua` — diagnostics + edit highlights
+atlas/modes/review.md:220:- `lua/parley/highlighter.lua` — `ParleyReviewUser`/`ParleyReviewAgent` groups
+
+exec
+/bin/zsh -lc "nl -ba lua/parley/highlighter.lua | sed -n '700,775p'" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+   700        -- Tool error results — visually distinct from normal tool blocks
+   701        if user_highlights.tool_error then
+   702            vim.api.nvim_set_hl(0, "ParleyToolError", user_highlights.tool_error)
+   703        else
+   704            vim.api.nvim_set_hl(0, "ParleyToolError", {
+   705                link = "DiagnosticError",
+   706            })
+   707        end
+   708
+   709        -- Annotations - Use existing highlight groups that work across themes
+   710        if user_highlights.annotation then
+   711            vim.api.nvim_set_hl(0, "ParleyAnnotation", user_highlights.annotation)
+   712        else
+   713            vim.api.nvim_set_hl(0, "ParleyAnnotation", {
+   714                link = "DiffAdd", -- Usually a green background with appropriate text color
+   715            })
+   716        end
+   717
+   718        -- Chat branch/parent links (🌿: lines)
+   719        if user_highlights.chat_reference then
+   720            vim.api.nvim_set_hl(0, "ParleyChatReference", user_highlights.chat_reference)
+   721        else
+   722            vim.api.nvim_set_hl(0, "ParleyChatReference", {
+   723                link = "Special",
+   724            })
+   725        end
+   726
+   727        -- Inline branch links [🌿:text](file) — display text as underlined link
+   728        if user_highlights.inline_branch then
+   729            vim.api.nvim_set_hl(0, "ParleyInlineBranch", user_highlights.inline_branch)
+   730        else
+   731            vim.api.nvim_set_hl(0, "ParleyInlineBranch", {
+   732                underline = true,
+   733                link = "Special",
+   734            })
+   735        end
+   736
+   737        -- Referenced-span markers `[…]` left in a reply by drill-in (#127): the
+   738        -- text a gathered comment points at. Underline reads as "this span is
+   739        -- marked" without the weight of a full background. Override via
+   740        -- config.highlight.reference.
+   741        if user_highlights.reference then
+   742            vim.api.nvim_set_hl(0, "ParleyReference", user_highlights.reference)
+   743        else
+   744            vim.api.nvim_set_hl(0, "ParleyReference", { underline = true })
+   745        end
+   746
+   747        -- Managed definition-footnote footer (`---` + `[^id]: ...`). It must be
+   748        -- independent of the surrounding chat exchange color.
+   749        if user_highlights.footnote then
+   750            vim.api.nvim_set_hl(0, "ParleyFootnote", user_highlights.footnote)
+   751        else
+   752            vim.api.nvim_set_hl(0, "ParleyFootnote", { link = "DiagnosticHint" })
+   753        end
+   754
+   755        -- Artifact refs (ariadne#11, #15 M4, pair#84) left navigable by #160.
+   756        -- Underline reads as "this is a jumpable ref" without a heavy background.
+   757        -- Override via config.highlight.artifact_ref.
+   758        if user_highlights.artifact_ref then
+   759            vim.api.nvim_set_hl(0, "ParleyArtifactRef", user_highlights.artifact_ref)
+   760        else
+   761            vim.api.nvim_set_hl(0, "ParleyArtifactRef", { underline = true })
+   762        end
+   763
+   764        -- Tags - Highlighted tags in @@tag@@ format
+   765        if user_highlights.tag then
+   766            vim.api.nvim_set_hl(0, "ParleyTag", user_highlights.tag)
+   767        else
+   768            vim.api.nvim_set_hl(0, "ParleyTag", {
+   769                link = "Todo", -- Link to Todo highlight group which is highly visible in most themes
+   770            })
+   771        end
+   772
+   773        -- Picker typo-tolerance edits - distinct from exact Search highlights
+   774        if user_highlights.approximate_match then
+   775            vim.api.nvim_set_hl(0, "ParleyPickerApproximateMatch", user_highlights.approximate_match)
+
+exec
+/bin/zsh -lc 'git diff --check 4005929621a91a6e1a9a02bd048a859bb59ffb77..HEAD -- atlas/ui/highlights.md lua/parley/define.lua lua/parley/highlighter.lua tests/integration/highlighting_spec.lua tests/unit/define_spec.lua workshop/issues/000171-footnote-coloring.md' in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+codex
+One possible gap is emerging: the implementation supports `config.highlight.footnote`, but the default config table appears not to list it. I’m checking whether that table is treated as user-facing documentation/schema or only loose defaults before deciding if that is a review finding.
+exec
+/bin/zsh -lc "nl -ba lua/parley/config.lua | sed -n '620,660p'" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+   620
+   621        -- styling for chatfinder
+   622        ---@type "single" | "double" | "rounded" | "solid" | "shadow" | "none"
+   623        style_chat_finder_border = "single",
+   624        -- margins are number of characters or lines
+   625        style_chat_finder_margin_bottom = 8,
+   626        style_chat_finder_margin_left = 1,
+   627        style_chat_finder_margin_right = 2,
+   628        style_chat_finder_margin_top = 2,
+   629        -- how wide should the preview be, number between 0.0 and 1.0
+   630        style_chat_finder_preview_ratio = 0.5,
+   631
+   632        -- When drill-in gathers a 🤖 comment into the next turn (#127), enclose the
+   633        -- referenced span in `[]` in place so you can see what it points at, and
+   634        -- highlight those spans (ParleyReference). Set to false to strip markers
+   635        -- without leaving the brackets.
+   636        mark_reference_span = true,
+   637
+   638        -- highlight styling (set to nil to use defaults that match your colorscheme)
+   639        -- these settings override the default highlight links if provided
+   640        highlight = {
+   641            -- Use existing highlight groups by default (nil values)
+   642            question = nil, -- highlight for user questions (default: links to Keyword)
+   643            file_reference = nil, -- highlight for file references (default: links to WarningMsg)
+   644            thinking = nil, -- highlight for reasoning lines (default: links to Comment)
+   645            annotation = nil, -- highlight for annotations (default: links to DiffAdd)
+   646            approximate_match = nil, -- highlight for typo-tolerance edit positions in picker matches (default: links to IncSearch)
+   647            chat_reference = nil, -- highlight for 🌿: chat branch/parent links (default: links to Special)
+   648            reference = nil, -- highlight for [referenced span] markers left by drill-in (#127) (default: underline)
+   649        },
+   650
+   651        -- lualine integration options
+   652        lualine = {
+   653            -- enable lualine integration
+   654            enable = true,
+   655            -- which section to add the component to
+   656            section = "lualine_x",
+   657            -- replace the user's filetype component with a parley mode glyph
+   658            -- (○ global / ⊚ repo / ⦿ super-repo). Set to false to keep filetype.
+   659            replace_filetype = true,
+   660        },
+
+exec
+/bin/zsh -lc 'rg -n "function.*merge|deep_extend|default_config|config =" lua/parley/config.lua lua/parley/init.lua | head -80' in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+lua/parley/config.lua:10:local config = {
+lua/parley/config.lua:129:        config = {
+lua/parley/init.lua:8:local config = require("parley.config")
+lua/parley/init.lua:21:    config = {}, -- config variables
+lua/parley/init.lua:190:    local parse_config = {
+lua/parley/init.lua:464:    M.config = vim.deepcopy(config)
+
+exec
+/bin/zsh -lc "nl -ba lua/parley/config.lua | sed -n '1,80p' && nl -ba lua/parley/config.lua | sed -n '720,780p'" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+     1    -- Parley - A Neovim LLM Chat Plugin
+     2    -- https://github.com/xianxu/parley.nvim/
+     3
+     4    --------------------------------------------------------------------------------
+     5    -- Default config
+     6    --------------------------------------------------------------------------------
+     7
+     8    ---@class ParleyConfig
+     9    -- README_REFERENCE_MARKER_START
+    10    local config = {
+    11        -- Please start with minimal config possible.
+    12        -- Just openai_api_key if you don't have OPENAI_API_KEY env set up.
+    13        -- Defaults change over time to improve things, options might get deprecated.
+    14        -- It's better to change only things where the default doesn't fit your needs.
+    15
+    16        -- required openai api key (string or table with command and arguments)
+    17        -- openai_api_key = { "cat", "path_to/openai_api_key" },
+    18        -- openai_api_key = { "bw", "get", "password", "OPENAI_API_KEY" },
+    19        -- openai_api_key: "sk-...",
+    20        -- openai_api_key = os.getenv("env_name.."),
+    21        -- openai_api_key = os.getenv("OPENAI_API_KEY"),
+    22
+    23        -- API keys for each provider - easy to override just this section without copying entire config
+    24        -- Set these in your local configuration - this is separate from providers section
+    25        api_keys = {
+    26            -- Different ways to provide API keys (from lowest to highest security):
+    27            -- 1. Hardcode: api_key = "sk-..."
+    28            -- 2. Environment variable: api_key = os.getenv("OPENAI_API_KEY")
+    29            -- 3. File: api_key = { "cat", "/path/to/api_key_file" }
+    30            -- 4. Password manager: api_key = { "pass", "show", "openai-key" }
+    31            -- 5. macOS Keychain: api_key = { "security", "find-generic-password", "-a", "your_username", "-s", "OPENAI_API_KEY", "-w" }
+    32
+    33            openai = os.getenv("OPENAI_API_KEY"),
+    34            anthropic = os.getenv("ANTHROPIC_API_KEY"),
+    35
+    36            googleai = os.getenv("GOOGLEAI_API_KEY"),
+    37            ollama = "dummy_secret", -- ollama typically uses a dummy token for local instances
+    38            copilot = os.getenv("GITHUB_TOKEN"), -- for GitHub Copilot
+    39            -- Local client↔proxy handshake token (NOT your subscription auth — that
+    40            -- lives in the cliproxy auth-dir via :ParleyProxy login). In managed mode
+    41            -- parley renders this into the proxy's api-keys AND sends it as the bearer,
+    42            -- so a fixed local default works out-of-the-box over loopback. Override
+    43            -- via the env var if you point at a proxy that expects a specific key.
+    44            cliproxyapi = os.getenv("CLIPROXYAPI_API_KEY") or "parley-local",
+    45        },
+    46
+    47        -- Google Drive OAuth configuration for @@ URL references
+    48        -- Users can override with plaintext values in their setup() call.
+    49        google_drive = {
+    50            client_id = "",
+    51            client_secret = "",
+    52            scopes = { "https://www.googleapis.com/auth/drive.readonly" },
+    53        },
+    54
+    55        -- Provider-neutral OAuth configuration for remote @@ URL references.
+    56        -- New provider integrations should be added here. The legacy
+    57        -- `google_drive` config above remains supported for backward compatibility.
+    58        oauth = {
+    59            dropbox = {
+    60                client_id = "",
+    61                client_secret = "",
+    62                redirect_port = nil,
+    63                scopes = { "sharing.read" },
+    64            },
+    65            google = {
+    66                client_id = "",
+    67                client_secret = "",
+    68                redirect_port = nil,
+    69                scopes = { "https://www.googleapis.com/auth/drive.readonly" },
+    70            },
+    71        },
+    72
+    73        -- at least one working provider is required
+    74        -- to disable a provider set it to empty table like openai = {}
+    75        providers = {
+    76            openai = {
+    77                disable = false,
+    78                endpoint = "https://api.openai.com/v1/chat/completions",
+    79                -- secret will be loaded from api_keys.openai
+    80            },
+
+exec
+/bin/zsh -lc "rg -n \"highlight = \\{|footnote = nil|artifact_ref = nil|tool_error|draft_block\" lua/parley/config.lua README.md atlas -g '"'!workshop/history/**'"'" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+lua/parley/config.lua:640:    highlight = {
+
+codex
+The default config is marked as the README reference block and currently omits the new `highlight.footnote` key. I’m verifying whether README generation consumes that block; if so, that’s a docs/API-surface gap rather than just a style nit.
+exec
+/bin/zsh -lc "nl -ba lua/parley/init.lua | sed -n '440,490p'" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+   440
+   441    -- setup function
+   442    M._setup_called = false
+   443    ---@param opts the one returned from config.lua, it can come from several sources, either fully specified
+   444    ---            in ~/.config/nvim/lua/parley/config.lua, or partially overrides from ~/.config/nvim/lua/plugins/parley.lua
+   445    M.setup = function(opts)
+   446        M._setup_called = true
+   447
+   448        math.randomseed(os.time())
+   449
+   450        -- Wire up interview module with shared state/logger references
+   451        interview.setup(M, M.logger)
+   452
+   453        -- Initialize file tracker
+   454        M.file_tracker = require("parley.file_tracker").init()
+   455
+   456        -- make sure opts is a table
+   457        opts = opts or {}
+   458        if type(opts) ~= "table" then
+   459            M.logger.error(string.format("setup() expects table, but got %s:\n%s", type(opts), vim.inspect(opts)))
+   460            opts = {}
+   461        end
+   462
+   463        -- reset M.config
+   464        M.config = vim.deepcopy(config)
+   465
+   466        -- Register builtin tool-use tools (M1 of #81). Runs before any
+   467        -- agent validation so agents can reference tools by name. The
+   468        -- registry module handles reset-idempotence internally.
+   469        require("parley.tools").register_builtins()
+   470
+   471        local curl_params = opts.curl_params or M.config.curl_params
+   472            local state_dir = opts.state_dir or M.config.state_dir
+   473
+   474        M.logger.setup(opts.log_file or M.config.log_file, opts.log_sensitive)
+   475
+   476        M.vault.setup({ state_dir = state_dir, curl_params = curl_params })
+   477        custom_prompts.setup(M.helpers, state_dir)
+   478
+   479        -- Process API keys from api_keys table and load them into vault
+   480        local api_keys = opts.api_keys or M.config.api_keys or {}
+   481        for provider_name, api_key in pairs(api_keys) do
+   482            if api_key then
+   483                M.logger.debug("Loading " .. provider_name .. " API key into vault")
+   484                M.vault.add_secret(provider_name, api_key)
+   485            end
+   486        end
+   487
+   488        -- Process providers and inject secrets from vault if needed
+   489        local providers = opts.providers or M.config.providers or {}
+   490        for provider_name, provider in pairs(providers) do
+
+exec
+/bin/zsh -lc "rg -n \"README_REFERENCE_MARKER|config.lua|README\" Makefile scripts tests lua .github atlas workshop -g '"'!workshop/history/**'"'" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+atlas/modes/review.md:221:- `lua/parley/config.lua` — default keybindings and config
+atlas/traceability.yaml:97:      - lua/parley/config.lua
+atlas/traceability.yaml:157:      - lua/parley/config.lua
+atlas/traceability.yaml:230:      - lua/parley/config.lua
+atlas/traceability.yaml:273:      - lua/parley/config.lua
+atlas/traceability.yaml:282:      - lua/parley/cliproxy_config.lua
+atlas/traceability.yaml:407:      - lua/parley/config.lua
+atlas/traceability.yaml:459:      - lua/parley/config.lua
+atlas/traceability.yaml:475:      - lua/parley/config.lua
+atlas/chat/inline_define.md:142:- `lua/parley/config.lua`, `lua/parley/keybinding_registry.lua` — the `<M-CR>` split.
+atlas/infra/config.md:5:2. Global config (`lua/parley/config.lua`)
+workshop/lessons.md:92:- New keybindings must use config-driven mechanism (`chat_shortcut_*` in config.lua + `M.cmd.*`) — don't copy hardcoded patterns
+workshop/lessons.md:147:- **README snippets are consumers of user-facing UI behavior, not marketing fluff.** #176 updated atlas when footnote definitions moved from virtual lines to a centered float, but the close review caught README still saying "grey pop-under" for visual `<M-CR>`. Rule: when changing a visible command/keybinding behavior, grep README for the command, keybinding, and old UI nouns alongside atlas.
+atlas/infra/workflow.md:45:| `specs` | Checks atlas/ and README.md match code changes | **read-write** (may update docs) |
+atlas/providers/cliproxy-managed.md:8:**On by default** (`config.lua` ships `cliproxy = { manage = true, … }`), but
+atlas/providers/cliproxy-managed.md:18:- **`cliproxy_config.lua`** (pure): `parse_endpoint` (host:port from the provider
+lua/parley/config.lua:9:-- README_REFERENCE_MARKER_START
+lua/parley/config.lua:683:    -- example hook functions (see Extend functionality section in the README)
+lua/parley/config.lua:712:-- README_REFERENCE_MARKER_END
+atlas/chat/memory_prefs.md:31:- `lua/parley/config.lua` — config defaults
+lua/parley/init.lua:443:---@param opts the one returned from config.lua, it can come from several sources, either fully specified
+lua/parley/init.lua:444:---            in ~/.config/nvim/lua/parley/config.lua, or partially overrides from ~/.config/nvim/lua/plugins/parley.lua
+lua/parley/init.lua:1102:        if M.config.lualine and M.config.lualine.enable then
+atlas/chat/spell_typeahead.md:71:- `lua/parley/config.lua` — `chat_spell` defaults.
+lua/parley/health.lua:33:        if parley_ok and parley_module.config and parley_module.config.lualine and parley_module.config.lualine.enable then
+lua/parley/lualine.lua:373:    if config.lualine and config.lualine.enable then
+lua/parley/lualine.lua:384:          local section = config.lualine.section or "lualine_z"
+lua/parley/lualine.lua:401:      local replace_filetype = config.lualine and config.lualine.replace_filetype ~= false
+lua/parley/lualine.lua:455:        local section = config.lualine.section or "lualine_z"
+lua/parley/cliproxy.lua:6:-- transforms live in parley/cliproxy_config.lua and are injected here.
+tests/arch/buffer_mutation_spec.lua:35:                "lua/parley/config.lua",
+tests/unit/tools_builtin_grep_spec.lua:61:        local r = handler({ pattern = "--files", path = "lua/parley/config.lua" })
+tests/unit/tools_builtin_grep_spec.lua:67:        local r = handler({ pattern = "--pre=/bin/echo", path = "lua/parley/config.lua" })
+tests/unit/cliproxy_config_spec.lua:1:-- Unit tests for lua/parley/cliproxy_config.lua (issue #131).
+tests/unit/parse_chat_spec.lua:437:            "lua/  tests/  README.md",
+tests/unit/parse_chat_spec.lua:442:            "Lua sources, tests, and a README.",
+tests/unit/parse_chat_spec.lua:638:            "💬: Check @@~/config.lua@@",
+tests/unit/parse_chat_spec.lua:643:        assert.equals("~/config.lua", refs[1].path)
+tests/integration/skill_invoke_spec.lua:234:        vim.fn.writefile({ "repo root file" }, repo .. "/README.md")
+tests/integration/skill_invoke_spec.lua:245:                raw_response = read_file_sse("README.md"),
+tests/integration/skill_invoke_spec.lua:269:        vim.fn.writefile({ "sibling repo root file" }, sibling_repo .. "/README.md")
+tests/integration/skill_invoke_spec.lua:284:                raw_response = read_file_sse("README.md"),
+tests/unit/build_messages_spec.lua:120:        local pc = parsed_chat({ exchange("Read README") })
+tests/unit/chat_parser_tools_spec.lua:23:-- Minimal config table the parser needs. Pulled from config.lua
+tests/unit/super_repo_spec.lua:252:        vim.fn.writefile({ "# baz" }, sibling_b .. "/README.md")
+tests/unit/super_repo_spec.lua:272:            if e.display:match("^{brain} README%.md") then
+tests/unit/super_repo_spec.lua:279:        assert.is_true(found_b, "expected '{brain} README.md' entry")
+tests/unit/tools_builtin_ack_spec.lua:36:        local r = handler({ pattern = "--files", path = "lua/parley/config.lua" })
+tests/integration/review_menu_spec.lua:83:        -- the binding loop reads (the defaults themselves live in config.lua).
+tests/unit/tool_loop_spec.lua:240:        vim.fn.writefile({ "from repo root" }, repo .. "/README.md")
+tests/unit/tool_loop_spec.lua:250:        local raw = mk_read_file_sse_response("toolu_NEIGHBORHOOD", "README.md")
+tests/integration/neighborhood_completion_spec.lua:9:vim.fn.writefile({ "readme" }, repo .. "/README.md")
+tests/integration/neighborhood_completion_spec.lua:60:        assert.same({ "README.md" }, readme_items)
+
+exec
+/bin/zsh -lc "nl -ba README.md | sed -n '150,175p'" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+   150
+   151    ## Configuration Entry Points
+   152
+   153    Common options live in `setup()`:
+   154    - `api_keys`
+   155    - `chat_dir`
+   156    - `notes_dir`
+   157
+   158    Merge behavior in `setup(opts)`:
+   159    - `agents`, `system_prompts`, and `hooks` are merged by key/name, so you can override only selected entries.
+   160    - Most other top-level keys are replaced when provided (for example `chat_dir`, `chat_dirs`, `notes_dir`, `chat_template`, `raw_mode`, `highlight`, `chat_memory`, `providers`, `api_keys`).
+   161    - Practical rule: for non-merged tables, provide the full table you want, not just one nested field.
+   162    - Reference [lua/parley/config.lua](https://github.com/xianxu/parley.nvim/blob/main/lua/parley/config.lua) for full defaults and examples.
+   163
+   164    Chat storage roots:
+   165    - `chat_dir` is the primary writable root used for new chats.
+   166    - `chat_dirs` is an optional list of additional roots that Chat Finder, chat validation, and chat-aware commands will scan alongside `chat_dir`.
+   167    - `:ParleyChatDirs` opens a picker to add or remove chat roots at runtime.
+   168    - `:ParleyChatDirAdd {dir}` adds a root directly, with directory completion.
+   169    - `:ParleyChatDirRemove {dir}` removes a configured root directly.
+   170    - `:ParleyChatMove {dir}` moves the current chat to another registered chat root.
+   171    - The primary `chat_dir` cannot be removed at runtime.
+   172    - The default shortcut for chat-root management is `<C-g>h`.
+   173
+   174    For full defaults and examples, see [`lua/parley/config.lua`](lua/parley/config.lua).
+   175
+
+exec
+/bin/zsh -lc "find . -maxdepth 3 -type f | rg '(readme|README|config)'" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+./workshop/history/000157-config-tools-spec-drift-default-toolsonnet-ships-all-but-spec-asserts-readonly-5-failing-tests.md
+./workshop/history/000157-config-tools-spec-drift-default-toolsonnet-ships-all-but-spec-asserts-readonly-5-failing-tests-close-review.md
+./workshop/history/000023-git-config-not-set-in-sandbox.md
+./debug-slowness/README.md
+./tests/unit/cliproxy_config_spec.lua
+./tests/unit/config_tools_spec.lua
+./.editorconfig
+./lua/parley/cliproxy_config.lua
+./lua/parley/config.lua
+./README.md
+./atlas/infra/config.md
+./.git/config
+
+exec
+/bin/zsh -lc "nl -ba lua/parley/init.lua | sed -n '490,590p'" in /Users/xianxu/workspace/parley.nvim
+exec
+/bin/zsh -lc "rg -n \"for key|opts\\[|M.config\\[|highlight\" lua/parley/init.lua | head -120" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+3:-- A streamlined LLM chat interface for Neovim with highlighting and navigation
+126:local highlighter = require("parley.highlighter")
+127:highlighter.setup(M)
+510:        for k, v in pairs(M.config[tbl]) do
+521:        M.config[tbl] = nil
+523:        opts[tbl] = opts[tbl] or {}
+524:        for k, v in pairs(opts[tbl]) do
+533:        opts[tbl] = nil
+538:        M.config[k] = v
+663:            M.config[k] = M.helpers.prepare_dir(v, k)
+1111:    -- Set up custom Search highlight for better visibility of all matches
+1519:    highlighter.display_agent(buf, file_name)
+1527:    return highlighter.agent_display_name_with_web_search(agent_name, ag_conf)
+1597:-- footnote (ONE undo entry — the anchor), highlights the selected term/reference
+1644:    skill_render.highlight_span(buf, diag_span.lnum, diag_span.col, diag_span.end_lnum, diag_span.end_col)
+1649:    -- snapshot, footnoted hash → highlight+diagnostic; attach the watcher.
+1990:        M.highlight_chat_branch_refs(buf)
+2018:        M.highlight_chat_branch_refs(buf)
+2039:        -- `hlsearch` setting govern highlight — don't force the global flag on
+2235:-- Define namespace and highlighting colors for questions, annotations, and thinking
+2236:M.setup_highlight = function()
+2237:    return highlighter.setup_highlights()
+2244:M.highlight_chat_branch_refs = function(buf)
+2245:    highlighter.highlight_chat_branch_refs(buf)
+2248:-- Apply highlighting to chat blocks in the current buffer.
+2250:-- Production highlighting is handled by the decoration provider.
+2251:M.highlight_question_block = function(buf)
+2252:    highlighter.highlight_question_block(buf)
+2281:        M.highlight_chat_branch_refs(buf)
+2310:        M.highlight_chat_branch_refs(buf)
+2385:    highlighter.setup_buf_handler()
+
+ succeeded in 0ms:
+   490        for provider_name, provider in pairs(providers) do
+   491            if provider and type(provider) == "table" and not provider.secret and api_keys[provider_name] then
+   492                M.logger.debug("Setting " .. provider_name .. " provider secret from api_keys")
+   493                provider.secret = api_keys[provider_name]
+   494            end
+   495        end
+   496
+   497        M.dispatcher.setup({ providers = providers, curl_params = curl_params })
+   498
+   499        -- Clear sensitive data from config
+   500        M.config.api_keys = nil
+   501        opts.api_keys = nil
+   502        M.config.providers = nil
+   503        opts.providers = nil
+   504
+   505        -- selectively merge some keys. this allows configuration to partially override this keys.
+   506        local mergeTables = { "hooks", "agents", "system_prompts" }
+   507        for _, tbl in ipairs(mergeTables) do
+   508            M[tbl] = M[tbl] or {}
+   509            ---@diagnostic disable-next-line
+   510            for k, v in pairs(M.config[tbl]) do
+   511                if tbl == "hooks" then
+   512                    M[tbl][k] = v
+   513                elseif tbl == "agents" then
+   514                    ---@diagnostic disable-next-line
+   515                    M[tbl][v.name] = v
+   516                elseif tbl == "system_prompts" then
+   517                    ---@diagnostic disable-next-line
+   518                    M[tbl][v.name] = v
+   519                end
+   520            end
+   521            M.config[tbl] = nil
+   522
+   523            opts[tbl] = opts[tbl] or {}
+   524            for k, v in pairs(opts[tbl]) do
+   525                if tbl == "hooks" then
+   526                    M[tbl][k] = v
+   527                elseif tbl == "agents" then
+   528                    M[tbl][v.name] = v
+   529                elseif tbl == "system_prompts" then
+   530                    M[tbl][v.name] = v
+   531                end
+   532            end
+   533            opts[tbl] = nil
+   534        end
+   535
+   536        -- now merge the rest of opts into M.config, this would be fully override.
+   537        for k, v in pairs(opts) do
+   538            M.config[k] = v
+   539        end
+   540
+   541        -- #116 M2: seed issues_dir from the cue `discovery.home` (ariadne's issue.cue,
+   542        -- exported to construct/generated/vocabulary/issue.json) when the user did NOT
+   543        -- override it, so every config.issues_dir reader (get_issues_dir,
+   544        -- get_issues_repo_root, the super-repo finder, the status autocmd, base.lua's
+   545        -- issue descriptor) derives from the one cue source. Precedence: explicit user
+   546        -- override > cue home > built-in default. home() returns nil in a fresh clone /
+   547        -- pre-weave, so this is a no-op there (stays on the built-in default). Relative
+   548        -- stays relative — issues_dir is in skip_prepare, never absolutized here.
+   549        M.config.issues_dir = require("parley.issues").resolve_issues_dir(
+   550            opts.issues_dir,
+   551            require("parley.issue_vocabulary").home(),
+   552            M.config.issues_dir
+   553        )
+   554
+   555        -- Detect parley-enabled repo via marker file and set up repo-local directories
+   556        -- Skip if user explicitly set chat_dir in opts (e.g. tests)
+   557        local function apply_repo_local()
+   558            if opts.chat_dir then return end
+   559
+   560            local marker = M.config.repo_marker
+   561            if not marker then return end
+   562
+   563            local git_root = M.helpers.find_git_root(vim.fn.getcwd())
+   564            if git_root == "" then return end
+   565
+   566            local marker_path = git_root .. "/" .. marker
+   567            if vim.fn.filereadable(marker_path) ~= 1 then return end
+   568
+   569            M.config.repo_root = git_root
+   570
+   571            -- Ensure repo-local directories exist
+   572            for _, dir in ipairs(repo_artifacts.relative_dirs(M.config)) do
+   573                if dir and dir ~= "" and not dir:match("^/") then
+   574                    M.helpers.prepare_dir(git_root .. "/" .. dir, "repo")
+   575                end
+   576            end
+   577
+   578            -- Prepend repo chat dir as primary, demoting global chat_dir to extra.
+   579            -- Use the structured chat_roots list so labels are explicit:
+   580            -- repo dir → "repo", original config.chat_dir → "global". Without
+   581            -- explicit labels, the normalizer derives labels from the directory
+   582            -- basename, which surfaces as e.g. {parley} in the finder when the
+   583            -- global chat dir's basename is "parley".
+   584            if M.config.repo_chat_dir and M.config.repo_chat_dir ~= "" then
+   585                local repo_chat = git_root .. "/" .. M.config.repo_chat_dir
+   586                local old_dir = M.config.chat_dir
+   587                local old_dirs = M.config.chat_dirs
+   588
+   589                M.config.chat_dir = repo_chat
+   590                local roots = { { dir = repo_chat, label = "repo" } }
+
+exec
+/bin/zsh -lc "nl -ba lua/parley/config.lua | sed -n '660,720p'" in /Users/xianxu/workspace/parley.nvim
+ succeeded in 0ms:
+   660        },
+   661
+   662        -- raw_mode configuration for debugging and learning. Writes per-turn
+   663        -- logs to side files at <chat-dir>/.parley-logs/<basename>/{exchange,raw}.md.
+   664        -- The lualine parley section turns red while either log toggle is on.
+   665        raw_mode = {
+   666            -- Master switch — when false, the toggle commands no-op.
+   667            enable = true,
+   668            -- Append per-turn exchange-level message lists (system/user/assistant).
+   669            log_exchange = false,
+   670            -- Append per-turn raw request payload (YAML), assembled response
+   671            -- (YAML), and raw SSE stream lines.
+   672            log_raw = false,
+   673        },
+   674
+   675        -- TODO: what are the following are needed?
+   676        -- command config and templates below are used by commands like GpRewrite, GpEnew, etc.
+   677        -- command prompt prefix for asking user for input (supports {{agent}} template variable)
+   678        command_prompt_prefix_template = "🤖 {{agent}} ~ ",
+   679        -- auto select command response (easier chaining of commands)
+   680        -- if false it also frees up the buffer cursor for further editing elsewhere
+   681        command_auto_select_response = true,
+   682
+   683        -- example hook functions (see Extend functionality section in the README)
+   684        hooks = {
+   685            -- ParleyInspectPlugin provides a detailed inspection of the plugin state
+   686            InspectPlugin = function(plugin, params)
+   687                local bufnr = vim.api.nvim_create_buf(false, true)
+   688                vim.bo[bufnr].bufhidden = "wipe"
+   689                vim.bo[bufnr].buflisted = false
+   690                local copy = vim.deepcopy(plugin)
+   691                local key = copy.config.openai_api_key or ""
+   692                copy.config.openai_api_key = key:sub(1, 3) .. string.rep("*", #key - 6) .. key:sub(-3)
+   693                local plugin_info = string.format("Plugin structure:\n%s", vim.inspect(copy))
+   694                local params_info = string.format("Command params:\n%s", vim.inspect(params))
+   695                local lines = vim.split(plugin_info .. "\n" .. params_info, "\n")
+   696                vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
+   697                vim.api.nvim_win_set_buf(0, bufnr)
+   698            end,
+   699
+   700            -- ParleyInspectLog for checking the log file
+   701            InspectLog = function(plugin, _params)
+   702                local log_file = plugin.config.log_file
+   703                local buffer = plugin.helpers.get_buffer(log_file)
+   704                if not buffer then
+   705                    vim.cmd("e " .. log_file)
+   706                else
+   707                    vim.cmd("buffer " .. buffer)
+   708                end
+   709            end,
+   710        },
+   711    }
+   712    -- README_REFERENCE_MARKER_END
+   713
+   714    return config
+
+codex
+The code path itself is still looking sound. I’m running the focused specs named by the issue now; the only review finding I’m leaning toward is the missing default-config documentation for the new override key.
+exec
+/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"' in /Users/xianxu/workspace/parley.nvim
+exec
+/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"' in /Users/xianxu/workspace/parley.nvim
+ succeeded in 1495ms:
+
+Parley.nvim: Failed to open file for writing: /Users/xianxu/.local/share/nvim/parley/persisted/state.jsonScheduling: tests/unit/define_spec.lua
+
+========================================
+Testing:     /Users/xianxu/workspace/parley.nvim/tests/unit/define_spec.lua
+[32mSuccess[0m    ||    define.slice_selection extracts a single-line span
+[32mSuccess[0m    ||    define.slice_selection extracts a multi-line span joined with newline
+[32mSuccess[0m    ||    define.slice_selection clamps an end column past line length
+[32mSuccess[0m    ||    define.slice_selection returns empty string for a reversed/empty span
+[32mSuccess[0m    ||    define.context_for_selection returns the enclosing exchange's lines (question..answer)
+[32mSuccess[0m    ||    define.context_for_selection handles an answerless exchange (question only)
+[32mSuccess[0m    ||    define.context_for_selection falls back to the whole buffer when outside any exchange
+[32mSuccess[0m    ||    define.format_definition composes 'TERM — definition'
+[32mSuccess[0m    ||    define.format_definition hard-wraps to width
+[32mSuccess[0m    ||    define.format_definition passes nil width through to the shared diagnostic formatter
+[32mSuccess[0m    ||    define.format_definition trims a nil/blank definition to a safe string
+[32mSuccess[0m    ||    define.bracket_edit wraps a single-line span into a set_lines edit
+[32mSuccess[0m    ||    define.bracket_edit clamps end col past line length
+[32mSuccess[0m    ||    define.bracket_edit wraps a multi-line span
+[32mSuccess[0m    ||    define.diagnostic_span_after_bracket anchors a single-line selection on the selected text after brackets
+[32mSuccess[0m    ||    define.diagnostic_span_after_bracket anchors a multi-line selection without shifting the final line
+[32mSuccess[0m    ||    define durable footnotes slugifies a definition term into a markdown footnote id
+[32mSuccess[0m    ||    define durable footnotes adds an inline footnote reference and appends a managed footer
+[32mSuccess[0m    ||    define durable footnotes updates an existing managed footnote instead of duplicating it
+[32mSuccess[0m    ||    define durable footnotes updates an existing inline reference without duplicating it
+[32mSuccess[0m    ||    define durable footnotes strips only a final managed footnote footer
+[32mSuccess[0m    ||    define durable footnotes preserves ordinary horizontal rules that are not managed footnote footers
+[32mSuccess[0m    ||    define durable footnotes reports the final managed footnote footer range
+[32mSuccess[0m    ||    define durable footnotes does not report ordinary horizontal rules as managed footnote footers
+[32mSuccess[0m    ||    define durable footnotes keeps earlier horizontal-rule content and strips only the final managed footer
+[32mSuccess[0m    ||    define durable footnotes extracts persisted footnote diagnostics from the managed footer
+[32mSuccess[0m    ||    define durable footnotes extracts every inline reference to a managed footnote
+[32mSuccess[0m    ||    define durable footnotes ignores footnotes that are not in a final managed footer
+
+[32mSuccess: [0m    28
+[31mFailed : [0m    0
+[31mErrors : [0m    0
+========================================
+]111
+ succeeded in 2151ms:
+
+LuaSnip: could not open log at /Users/xianxu/.local/state/nvim/luasnip.log. Not logging for this session.
+Parley.nvim: Failed to open file for writing: /Users/xianxu/.local/share/nvim/parley/persisted/state.jsonScheduling: tests/integration/highlighting_spec.lua
+
+========================================
+Testing:     /Users/xianxu/workspace/parley.nvim/tests/integration/highlighting_spec.lua
+[32mSuccess[0m    ||    highlight_question_block: question lines applies Question highlight to 💬: line (row 0)
+[32mSuccess[0m    ||    highlight_question_block: question lines applies ParleyQuestion highlight to continuation lines of a question block
+[32mSuccess[0m    ||    highlight_question_block: question lines does NOT apply ParleyQuestion highlight to 🤖: answer lines
+[32mSuccess[0m    ||    highlight_question_block: thinking lines applies Think highlight to 📝: summary line
+[32mSuccess[0m    ||    highlight_question_block: thinking lines applies ParleyThinking highlight to 🧠: reasoning line
+[32mSuccess[0m    ||    highlight_question_block: file reference lines applies FileLoading highlight to @@ file reference lines in a question block
+[32mSuccess[0m    ||    highlight_question_block: file reference lines does NOT apply ParleyFileReference highlight to @@ lines outside question blocks
+[32mSuccess[0m    ||    highlight_question_block: managed footnote footer uses a dedicated footnote highlight instead of open-question coloring
+[32mSuccess[0m    ||    decoration provider cache keeps highlight caches isolated per window for the same buffer
+[32mSuccess[0m    ||    decoration provider cache dims thinking-block continuation lines when viewport top falls between 🧠: and 🧠:[END]
+[32mSuccess[0m    ||    decoration provider cache dims streaming thinking-block continuation lines before 🧠:[END] is emitted
+[32mSuccess[0m    ||    decoration provider cache restores question highlights when redraw starts inside a long unanswered question
+[32mSuccess[0m    ||    timezone diagnostics publishes local-time diagnostics in its own namespace and clears stale diagnostics
+[32mSuccess[0m    ||    timezone diagnostics refreshes diagnostics for registered buffers on text changes
+[32mSuccess[0m    ||    markdown footnote diagnostics publishes persisted managed footnotes as Parley diagnostics
+[32mSuccess[0m    ||    markdown footnote diagnostics refreshes footnote diagnostics on markdown text changes without clearing other Parley diagnostics
+[32mSuccess[0m    ||    markdown footnote diagnostics renders managed footnote footers with ParleyFootnote in markdown buffers
+[32mSuccess[0m    ||    markdown chat reference rendering refreshes 🌿: branch lines with the chat topic in markdown buffers
+[32mSuccess[0m    ||    markdown chat reference rendering does not rewrite 🌿: lines pointing to non-chat files in markdown buffers
+[32mSuccess[0m    ||    markdown chat reference rendering refreshes from the updated topic in an open unsaved chat buffer
+
+[32mSuccess: [0m    20
+[31mFailed : [0m    0
+[31mErrors : [0m    0
+========================================
+]111
+codex
+```verdict
+verdict: FIX-THEN-SHIP
+confidence: high
+```
+
+The implementation satisfies the core issue: managed footnote footers now derive from `parley.define`, get `ParleyFootnote` in chat and markdown buffers, and stop inheriting open-question coloring. I found no Critical correctness issues. The only blocking-before-ship item is a cheap docs/config-surface gap: the diff introduces `config.highlight.footnote` support but does not expose it in the default config/README-facing config reference.
+
+1. Strengths:
+- `lua/parley/define.lua:195` keeps footer detection single-sourced via `managed_footnote_footer_range` instead of duplicating grammar in the highlighter. Pass: ARCH-DRY.
+- `lua/parley/highlighter.lua:270` and `lua/parley/highlighter.lua:471` consume the pure range helper from thin UI/highlight code. Pass: ARCH-PURE.
+- `tests/integration/highlighting_spec.lua:168` directly covers the reported failure mode: open question followed by a managed footer.
+- `atlas/ui/highlights.md:4` documents the new highlight group and behavior. Atlas gate looks satisfied.
+
+2. Critical findings:
+- None.
+
+3. Important findings:
+- `lua/parley/highlighter.lua:749` adds `user_highlights.footnote`, but `lua/parley/config.lua:640` does not list `footnote = nil` in the default `highlight` table, and README’s config section points readers to that file for full defaults. Fix sketch: add `footnote = nil -- highlight for managed definition-footnote footer lines (default: links to DiagnosticHint)` to the default config table. If README intentionally lists nested highlight keys elsewhere later, include it there too.
+
+4. Minor findings:
+- None.
+
+5. Test coverage notes:
+- Focused verification passed: `tests/unit/define_spec.lua` 28/28 and `tests/integration/highlighting_spec.lua` 20/20.
+- Neovim startup emitted unrelated local write warnings for LuaSnip/parser/state paths, but the specs completed successfully.
+
+6. Architectural notes for upcoming work:
+- ARCH-DRY: Pass. Footer grammar remains in `define`.
+- ARCH-PURE: Pass. New parser/range behavior is pure and unit-tested; highlighter remains IO/UI glue.
+- ARCH-PURPOSE: Pass for the issue purpose. Chat and markdown consumers both derive from the shared footer detector and the reported coloring drift is covered.
+
+7. Plan revision recommendations:
+- None. The issue plan matches the delivered code; no Core concepts table was present to reconcile.
+tokens used
+65,252
+```verdict
+verdict: FIX-THEN-SHIP
+confidence: high
+```
+
+The implementation satisfies the core issue: managed footnote footers now derive from `parley.define`, get `ParleyFootnote` in chat and markdown buffers, and stop inheriting open-question coloring. I found no Critical correctness issues. The only blocking-before-ship item is a cheap docs/config-surface gap: the diff introduces `config.highlight.footnote` support but does not expose it in the default config/README-facing config reference.
+
+1. Strengths:
+- `lua/parley/define.lua:195` keeps footer detection single-sourced via `managed_footnote_footer_range` instead of duplicating grammar in the highlighter. Pass: ARCH-DRY.
+- `lua/parley/highlighter.lua:270` and `lua/parley/highlighter.lua:471` consume the pure range helper from thin UI/highlight code. Pass: ARCH-PURE.
+- `tests/integration/highlighting_spec.lua:168` directly covers the reported failure mode: open question followed by a managed footer.
+- `atlas/ui/highlights.md:4` documents the new highlight group and behavior. Atlas gate looks satisfied.
+
+2. Critical findings:
+- None.
+
+3. Important findings:
+- `lua/parley/highlighter.lua:749` adds `user_highlights.footnote`, but `lua/parley/config.lua:640` does not list `footnote = nil` in the default `highlight` table, and README’s config section points readers to that file for full defaults. Fix sketch: add `footnote = nil -- highlight for managed definition-footnote footer lines (default: links to DiagnosticHint)` to the default config table. If README intentionally lists nested highlight keys elsewhere later, include it there too.
+
+4. Minor findings:
+- None.
+
+5. Test coverage notes:
+- Focused verification passed: `tests/unit/define_spec.lua` 28/28 and `tests/integration/highlighting_spec.lua` 20/20.
+- Neovim startup emitted unrelated local write warnings for LuaSnip/parser/state paths, but the specs completed successfully.
+
+6. Architectural notes for upcoming work:
+- ARCH-DRY: Pass. Footer grammar remains in `define`.
+- ARCH-PURE: Pass. New parser/range behavior is pure and unit-tested; highlighter remains IO/UI glue.
+- ARCH-PURPOSE: Pass for the issue purpose. Chat and markdown consumers both derive from the shared footer detector and the reported coloring drift is covered.
+
+7. Plan revision recommendations:
+- None. The issue plan matches the delivered code; no Core concepts table was present to reconcile.


codex
I’ll treat this as a fresh boundary review and verify the issue, diff, and current files directly. Since this is a review-only request, I’ll report findings without editing.
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

codex
I’ve got the workflow context. Now I’m comparing `4005929..HEAD` against the issue’s Spec/Plan and checking whether the previous config-surface gap was actually fixed in the current head.
exec
/bin/zsh -lc "sed -n '1,260p' workshop/issues/000171-footnote-coloring.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
---
id: 000171
status: codecomplete
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 0.43
started: 2026-07-08T17:14:54-07:00
actual_hours: 0.16
---

# footnote coloring

footnote should have dedicated color. right now it uses the color of last exchange. for example, if last exchange only has open question, footnote is displayed with question color.

## Problem

Managed definition footnotes are appended as a final markdown footer, but chat
highlighting treats an unanswered question as continuing to EOF. When the last
exchange is an open question, the footer inherits `ParleyQuestion`, so footnotes
take on the color of the last exchange instead of having a stable dedicated
appearance.

## Spec

Managed definition footnote footer lines render with a dedicated
`ParleyFootnote` highlight group in both chat and markdown buffers.

The managed-footer grammar remains single-sourced with the definition feature
(ARCH-DRY): highlighter code should consume a pure footer-range helper rather
than duplicate the `---` + `[^id]: ...` parser.

The dedicated footnote highlight must override chat block fallback coloring for
footer rows while leaving open issue/question highlighting unchanged for ordinary
question body lines.

## Done when

- A regression test covers an open question followed by a managed footnote footer.
- Footer divider and footnote definition rows receive `ParleyFootnote`.
- Footer rows no longer receive `ParleyQuestion` from an unanswered question block.
- Markdown buffers can use the same dedicated footnote group.

## Plan

- [x] Expose a pure managed-footnote footer range helper from `parley.define`.
- [x] Add unit coverage for the footer range helper.
- [x] Add highlighter regression coverage for an open question followed by a managed footer.
- [x] Apply `ParleyFootnote` in chat and markdown highlight computation.
- [x] Update atlas highlight docs and run focused plus repo verification.

## Estimate

Derived via `estimate-logic-v3.1` against the repo-local calibration source from
`sdlc estimate-source` (stale but canonical for this repo).

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.04 impl=0.00
item: lua-neovim design=0.09 impl=0.22
item: atlas-docs design=0.00 impl=0.02
item: milestone-review design=0.00 impl=0.02
total: 0.43
```

## Log

### 2026-07-08
- 2026-07-08: closed — Focused verification passed: nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"; nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"; scoped git diff --check over the #171 files. make test linted lua/tests successfully but fails in unrelated tests/unit/tools_builtin_find_spec.lua only under the parallel full-suite runner; that spec passes when run directly.; review verdict: FIX-THEN-SHIP

- Claimed the issue and inspected the chat/markdown highlighter paths. Root
  cause: open-question chat highlighting continues to EOF, so the final managed
  footnote footer is colored as `ParleyQuestion`.
- Added `define.managed_footnote_footer_range` so the footer grammar remains
  single-sourced with the definition feature (ARCH-DRY).
- Implemented `ParleyFootnote` for managed footer rows in both chat and markdown
  highlight computation; chat footers now terminate open-question color fallback.
- Verification: `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`
  passed; `nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"`
  passed; scoped `git diff --check -- atlas/ui/highlights.md lua/parley/define.lua
  lua/parley/highlighter.lua tests/integration/highlighting_spec.lua
  tests/unit/define_spec.lua workshop/issues/000171-footnote-coloring.md`
  passed.
- Full `make test` linted `lua` and `tests` successfully but failed in unrelated
  `tests/unit/tools_builtin_find_spec.lua` under the parallel unit runner; that
  same spec passed when run directly with
  `nvim --headless -c "PlenaryBustedFile tests/unit/tools_builtin_find_spec.lua"`.
- Close review returned `FIX-THEN-SHIP` for one docs/config-surface gap:
  `config.highlight.footnote` was supported by highlighter code but missing from
  the default config reference. Added the default key and captured a lesson.

exec
/bin/zsh -lc 'git diff --check 4005929621a91a6e1a9a02bd048a859bb59ffb77..HEAD' in /Users/xianxu/workspace/parley.nvim
 exited 2 in 0ms:
workshop/plans/000171-footnote-coloring-close-review.md:232: trailing whitespace.
+
workshop/plans/000171-footnote-coloring-close-review.md:236: trailing whitespace.
+
workshop/plans/000171-footnote-coloring-close-review.md:253: trailing whitespace.
+
workshop/plans/000171-footnote-coloring-close-review.md:283: trailing whitespace.
+
workshop/plans/000171-footnote-coloring-close-review.md:285: trailing whitespace.
+
workshop/plans/000171-footnote-coloring-close-review.md:328: trailing whitespace.
+
workshop/plans/000171-footnote-coloring-close-review.md:477: trailing whitespace.
+
workshop/plans/000171-footnote-coloring-close-review.md:485: trailing whitespace.
+
workshop/plans/000171-footnote-coloring-close-review.md:514: trailing whitespace.
+
workshop/plans/000171-footnote-coloring-close-review.md:533: trailing whitespace.
+
workshop/plans/000171-footnote-coloring-close-review.md:604: trailing whitespace.
+
workshop/plans/000171-footnote-coloring-close-review.md:613: trailing whitespace.
+
workshop/plans/000171-footnote-coloring-close-review.md:1151: trailing whitespace.
+   150
workshop/plans/000171-footnote-coloring-close-review.md:1162: trailing whitespace.
+   161
workshop/plans/000171-footnote-coloring-close-review.md:1166: trailing whitespace.
+   165
workshop/plans/000171-footnote-coloring-close-review.md:1170: trailing whitespace.
+   169
workshop/plans/000171-footnote-coloring-close-review.md:1192: trailing whitespace.
+   191
workshop/plans/000171-footnote-coloring-close-review.md:1204: trailing whitespace.
+   203
workshop/plans/000171-footnote-coloring-close-review.md:1216: trailing whitespace.
+   215
workshop/plans/000171-footnote-coloring-close-review.md:1220: trailing whitespace.
+   219
workshop/plans/000171-footnote-coloring-close-review.md:1228: trailing whitespace.
+   227
workshop/plans/000171-footnote-coloring-close-review.md:1239: trailing whitespace.
+   238
workshop/plans/000171-footnote-coloring-close-review.md:1247: trailing whitespace.
+   246
workshop/plans/000171-footnote-coloring-close-review.md:1270: trailing whitespace.
+   254
workshop/plans/000171-footnote-coloring-close-review.md:1274: trailing whitespace.
+   258
workshop/plans/000171-footnote-coloring-close-review.md:1277: trailing whitespace.
+   261
workshop/plans/000171-footnote-coloring-close-review.md:1297: trailing whitespace.
+   281
workshop/plans/000171-footnote-coloring-close-review.md:1299: trailing whitespace.
+   283
workshop/plans/000171-footnote-coloring-close-review.md:1309: trailing whitespace.
+   293
workshop/plans/000171-footnote-coloring-close-review.md:1312: trailing whitespace.
+   296
workshop/plans/000171-footnote-coloring-close-review.md:1314: trailing whitespace.
+   298
workshop/plans/000171-footnote-coloring-close-review.md:1316: trailing whitespace.
+   300
workshop/plans/000171-footnote-coloring-close-review.md:1332: trailing whitespace.
+   316
workshop/plans/000171-footnote-coloring-close-review.md:1349: trailing whitespace.
+   333
workshop/plans/000171-footnote-coloring-close-review.md:1404: trailing whitespace.
+   463
workshop/plans/000171-footnote-coloring-close-review.md:1463: trailing whitespace.
+   522
workshop/plans/000171-footnote-coloring-close-review.md:1480: trailing whitespace.
+   539
workshop/plans/000171-footnote-coloring-close-review.md:1503: trailing whitespace.
+   130
workshop/plans/000171-footnote-coloring-close-review.md:1514: trailing whitespace.
+   141
workshop/plans/000171-footnote-coloring-close-review.md:1517: trailing whitespace.
+   144
workshop/plans/000171-footnote-coloring-close-review.md:1527: trailing whitespace.
+   154
workshop/plans/000171-footnote-coloring-close-review.md:1537: trailing whitespace.
+   164
workshop/plans/000171-footnote-coloring-close-review.md:1540: trailing whitespace.
+   167
workshop/plans/000171-footnote-coloring-close-review.md:1550: trailing whitespace.
+   177
workshop/plans/000171-footnote-coloring-close-review.md:1561: trailing whitespace.
+   188
workshop/plans/000171-footnote-coloring-close-review.md:1567: trailing whitespace.
+   194
workshop/plans/000171-footnote-coloring-close-review.md:1573: trailing whitespace.
+   200
workshop/plans/000171-footnote-coloring-close-review.md:1582: trailing whitespace.
+   209
workshop/plans/000171-footnote-coloring-close-review.md:1590: trailing whitespace.
+   564
workshop/plans/000171-footnote-coloring-close-review.md:1596: trailing whitespace.
+   570
workshop/plans/000171-footnote-coloring-close-review.md:1609: trailing whitespace.
+   583
workshop/plans/000171-footnote-coloring-close-review.md:1617: trailing whitespace.
+   591
workshop/plans/000171-footnote-coloring-close-review.md:1625: trailing whitespace.
+   599
workshop/plans/000171-footnote-coloring-close-review.md:1637: trailing whitespace.
+   611
workshop/plans/000171-footnote-coloring-close-review.md:1641: trailing whitespace.
+   615
workshop/plans/000171-footnote-coloring-close-review.md:1648: trailing whitespace.
+   622
workshop/plans/000171-footnote-coloring-close-review.md:1651: trailing whitespace.
+   625
workshop/plans/000171-footnote-coloring-close-review.md:1653: trailing whitespace.
+   627
workshop/plans/000171-footnote-coloring-close-review.md:1673: trailing whitespace.
+   227
workshop/plans/000171-footnote-coloring-close-review.md:1676: trailing whitespace.
+   230
workshop/plans/000171-footnote-coloring-close-review.md:1685: trailing whitespace.
+   239
workshop/plans/000171-footnote-coloring-close-review.md:1688: trailing whitespace.
+   242
workshop/plans/000171-footnote-coloring-close-review.md:1697: trailing whitespace.
+   251
workshop/plans/000171-footnote-coloring-close-review.md:1700: trailing whitespace.
+   254
workshop/plans/000171-footnote-coloring-close-review.md:1709: trailing whitespace.
+   263
workshop/plans/000171-footnote-coloring-close-review.md:1712: trailing whitespace.
+   266
workshop/plans/000171-footnote-coloring-close-review.md:1725: trailing whitespace.
+   279
workshop/plans/000171-footnote-coloring-close-review.md:2462: trailing whitespace.
+   708
workshop/plans/000171-footnote-coloring-close-review.md:2471: trailing whitespace.
+   717
workshop/plans/000171-footnote-coloring-close-review.md:2480: trailing whitespace.
+   726
workshop/plans/000171-footnote-coloring-close-review.md:2490: trailing whitespace.
+   736
workshop/plans/000171-footnote-coloring-close-review.md:2500: trailing whitespace.
+   746
workshop/plans/000171-footnote-coloring-close-review.md:2508: trailing whitespace.
+   754
workshop/plans/000171-footnote-coloring-close-review.md:2517: trailing whitespace.
+   763
workshop/plans/000171-footnote-coloring-close-review.md:2526: trailing whitespace.
+   772
workshop/plans/000171-footnote-coloring-close-review.md:2539: trailing whitespace.
+   620
workshop/plans/000171-footnote-coloring-close-review.md:2550: trailing whitespace.
+   631
workshop/plans/000171-footnote-coloring-close-review.md:2556: trailing whitespace.
+   637
workshop/plans/000171-footnote-coloring-close-review.md:2569: trailing whitespace.
+   650
workshop/plans/000171-footnote-coloring-close-review.md:2596: trailing whitespace.
+     3
workshop/plans/000171-footnote-coloring-close-review.md:2600: trailing whitespace.
+     7
workshop/plans/000171-footnote-coloring-close-review.md:2608: trailing whitespace.
+    15
workshop/plans/000171-footnote-coloring-close-review.md:2615: trailing whitespace.
+    22
workshop/plans/000171-footnote-coloring-close-review.md:2625: trailing whitespace.
+    32
workshop/plans/000171-footnote-coloring-close-review.md:2628: trailing whitespace.
+    35
workshop/plans/000171-footnote-coloring-close-review.md:2639: trailing whitespace.
+    46
workshop/plans/000171-footnote-coloring-close-review.md:2647: trailing whitespace.
+    54
workshop/plans/000171-footnote-coloring-close-review.md:2665: trailing whitespace.
+    72
workshop/plans/000171-footnote-coloring-close-review.md:2685: trailing whitespace.
+   440
workshop/plans/000171-footnote-coloring-close-review.md:2692: trailing whitespace.
+   447
workshop/plans/000171-footnote-coloring-close-review.md:2694: trailing whitespace.
+   449
workshop/plans/000171-footnote-coloring-close-review.md:2697: trailing whitespace.
+   452
workshop/plans/000171-footnote-coloring-close-review.md:2700: trailing whitespace.
+   455
workshop/plans/000171-footnote-coloring-close-review.md:2707: trailing whitespace.
+   462
workshop/plans/000171-footnote-coloring-close-review.md:2710: trailing whitespace.
+   465
workshop/plans/000171-footnote-coloring-close-review.md:2715: trailing whitespace.
+   470
workshop/plans/000171-footnote-coloring-close-review.md:2718: trailing whitespace.
+   473
workshop/plans/000171-footnote-coloring-close-review.md:2720: trailing whitespace.
+   475
workshop/plans/000171-footnote-coloring-close-review.md:2723: trailing whitespace.
+   478
workshop/plans/000171-footnote-coloring-close-review.md:2732: trailing whitespace.
+   487
workshop/plans/000171-footnote-coloring-close-review.md:2797: trailing whitespace.
+   150
workshop/plans/000171-footnote-coloring-close-review.md:2799: trailing whitespace.
+   152
workshop/plans/000171-footnote-coloring-close-review.md:2804: trailing whitespace.
+   157
workshop/plans/000171-footnote-coloring-close-review.md:2810: trailing whitespace.
+   163
workshop/plans/000171-footnote-coloring-close-review.md:2820: trailing whitespace.
+   173
workshop/plans/000171-footnote-coloring-close-review.md:2822: trailing whitespace.
+   175
workshop/plans/000171-footnote-coloring-close-review.md:2884: trailing whitespace.
+   496
workshop/plans/000171-footnote-coloring-close-review.md:2886: trailing whitespace.
+   498
workshop/plans/000171-footnote-coloring-close-review.md:2892: trailing whitespace.
+   504
workshop/plans/000171-footnote-coloring-close-review.md:2910: trailing whitespace.
+   522
workshop/plans/000171-footnote-coloring-close-review.md:2923: trailing whitespace.
+   535
workshop/plans/000171-footnote-coloring-close-review.md:2928: trailing whitespace.
+   540
workshop/plans/000171-footnote-coloring-close-review.md:2942: trailing whitespace.
+   554
workshop/plans/000171-footnote-coloring-close-review.md:2947: trailing whitespace.
+   559
workshop/plans/000171-footnote-coloring-close-review.md:2950: trailing whitespace.
+   562
workshop/plans/000171-footnote-coloring-close-review.md:2953: trailing whitespace.
+   565
workshop/plans/000171-footnote-coloring-close-review.md:2956: trailing whitespace.
+   568
workshop/plans/000171-footnote-coloring-close-review.md:2958: trailing whitespace.
+   570
workshop/plans/000171-footnote-coloring-close-review.md:2965: trailing whitespace.
+   577
workshop/plans/000171-footnote-coloring-close-review.md:2976: trailing whitespace.
+   588
workshop/plans/000171-footnote-coloring-close-review.md:2984: trailing whitespace.
+   661
workshop/plans/000171-footnote-coloring-close-review.md:2997: trailing whitespace.
+   674
workshop/plans/000171-footnote-coloring-close-review.md:3005: trailing whitespace.
+   682
workshop/plans/000171-footnote-coloring-close-review.md:3022: trailing whitespace.
+   699
workshop/plans/000171-footnote-coloring-close-review.md:3036: trailing whitespace.
+   713
workshop/plans/000171-footnote-coloring-close-review.md:3046: trailing whitespace.
+
workshop/plans/000171-footnote-coloring-close-review.md:3049: trailing whitespace.
+========================================
workshop/plans/000171-footnote-coloring-close-review.md:3050: trailing whitespace.
+Testing:     /Users/xianxu/workspace/parley.nvim/tests/unit/define_spec.lua
workshop/plans/000171-footnote-coloring-close-review.md:3051: trailing whitespace.
+[32mSuccess[0m    ||    define.slice_selection extracts a single-line span
workshop/plans/000171-footnote-coloring-close-review.md:3052: trailing whitespace.
+[32mSuccess[0m    ||    define.slice_selection extracts a multi-line span joined with newline
workshop/plans/000171-footnote-coloring-close-review.md:3053: trailing whitespace.
+[32mSuccess[0m    ||    define.slice_selection clamps an end column past line length
workshop/plans/000171-footnote-coloring-close-review.md:3054: trailing whitespace.
+[32mSuccess[0m    ||    define.slice_selection returns empty string for a reversed/empty span
workshop/plans/000171-footnote-coloring-close-review.md:3055: trailing whitespace.
+[32mSuccess[0m    ||    define.context_for_selection returns the enclosing exchange's lines (question..answer)
workshop/plans/000171-footnote-coloring-close-review.md:3056: trailing whitespace.
+[32mSuccess[0m    ||    define.context_for_selection handles an answerless exchange (question only)
workshop/plans/000171-footnote-coloring-close-review.md:3057: trailing whitespace.
+[32mSuccess[0m    ||    define.context_for_selection falls back to the whole buffer when outside any exchange
workshop/plans/000171-footnote-coloring-close-review.md:3058: trailing whitespace.
+[32mSuccess[0m    ||    define.format_definition composes 'TERM — definition'
workshop/plans/000171-footnote-coloring-close-review.md:3059: trailing whitespace.
+[32mSuccess[0m    ||    define.format_definition hard-wraps to width
workshop/plans/000171-footnote-coloring-close-review.md:3060: trailing whitespace.
+[32mSuccess[0m    ||    define.format_definition passes nil width through to the shared diagnostic formatter
workshop/plans/000171-footnote-coloring-close-review.md:3061: trailing whitespace.
+[32mSuccess[0m    ||    define.format_definition trims a nil/blank definition to a safe string
workshop/plans/000171-footnote-coloring-close-review.md:3062: trailing whitespace.
+[32mSuccess[0m    ||    define.bracket_edit wraps a single-line span into a set_lines edit
workshop/plans/000171-footnote-coloring-close-review.md:3063: trailing whitespace.
+[32mSuccess[0m    ||    define.bracket_edit clamps end col past line length
workshop/plans/000171-footnote-coloring-close-review.md:3064: trailing whitespace.
+[32mSuccess[0m    ||    define.bracket_edit wraps a multi-line span
workshop/plans/000171-footnote-coloring-close-review.md:3065: trailing whitespace.
+[32mSuccess[0m    ||    define.diagnostic_span_after_bracket anchors a single-line selection on the selected text after brackets
workshop/plans/000171-footnote-coloring-close-review.md:3066: trailing whitespace.
+[32mSuccess[0m    ||    define.diagnostic_span_after_bracket anchors a multi-line selection without shifting the final line
workshop/plans/000171-footnote-coloring-close-review.md:3067: trailing whitespace.
+[32mSuccess[0m    ||    define durable footnotes slugifies a definition term into a markdown footnote id
workshop/plans/000171-footnote-coloring-close-review.md:3068: trailing whitespace.
+[32mSuccess[0m    ||    define durable footnotes adds an inline footnote reference and appends a managed footer
workshop/plans/000171-footnote-coloring-close-review.md:3069: trailing whitespace.
+[32mSuccess[0m    ||    define durable footnotes updates an existing managed footnote instead of duplicating it
workshop/plans/000171-footnote-coloring-close-review.md:3070: trailing whitespace.
+[32mSuccess[0m    ||    define durable footnotes updates an existing inline reference without duplicating it
workshop/plans/000171-footnote-coloring-close-review.md:3071: trailing whitespace.
+[32mSuccess[0m    ||    define durable footnotes strips only a final managed footnote footer
workshop/plans/000171-footnote-coloring-close-review.md:3072: trailing whitespace.
+[32mSuccess[0m    ||    define durable footnotes preserves ordinary horizontal rules that are not managed footnote footers
workshop/plans/000171-footnote-coloring-close-review.md:3073: trailing whitespace.
+[32mSuccess[0m    ||    define durable footnotes reports the final managed footnote footer range
workshop/plans/000171-footnote-coloring-close-review.md:3074: trailing whitespace.
+[32mSuccess[0m    ||    define durable footnotes does not report ordinary horizontal rules as managed footnote footers
workshop/plans/000171-footnote-coloring-close-review.md:3075: trailing whitespace.
+[32mSuccess[0m    ||    define durable footnotes keeps earlier horizontal-rule content and strips only the final managed footer
workshop/plans/000171-footnote-coloring-close-review.md:3076: trailing whitespace.
+[32mSuccess[0m    ||    define durable footnotes extracts persisted footnote diagnostics from the managed footer
workshop/plans/000171-footnote-coloring-close-review.md:3077: trailing whitespace.
+[32mSuccess[0m    ||    define durable footnotes extracts every inline reference to a managed footnote
workshop/plans/000171-footnote-coloring-close-review.md:3078: trailing whitespace.
+[32mSuccess[0m    ||    define durable footnotes ignores footnotes that are not in a final managed footer
workshop/plans/000171-footnote-coloring-close-review.md:3079: trailing whitespace.
+
workshop/plans/000171-footnote-coloring-close-review.md:3080: trailing whitespace.
+[32mSuccess: [0m    28
workshop/plans/000171-footnote-coloring-close-review.md:3081: trailing whitespace.
+[31mFailed : [0m    0
workshop/plans/000171-footnote-coloring-close-review.md:3082: trailing whitespace.
+[31mErrors : [0m    0
workshop/plans/000171-footnote-coloring-close-review.md:3083: trailing whitespace.
+========================================
workshop/plans/000171-footnote-coloring-close-review.md:3086: trailing whitespace.
+
workshop/plans/000171-footnote-coloring-close-review.md:3087: trailing whitespace.
+LuaSnip: could not open log at /Users/xianxu/.local/state/nvim/luasnip.log. Not logging for this session.
workshop/plans/000171-footnote-coloring-close-review.md:3090: trailing whitespace.
+========================================
workshop/plans/000171-footnote-coloring-close-review.md:3091: trailing whitespace.
+Testing:     /Users/xianxu/workspace/parley.nvim/tests/integration/highlighting_spec.lua
workshop/plans/000171-footnote-coloring-close-review.md:3092: trailing whitespace.
+[32mSuccess[0m    ||    highlight_question_block: question lines applies Question highlight to 💬: line (row 0)
workshop/plans/000171-footnote-coloring-close-review.md:3093: trailing whitespace.
+[32mSuccess[0m    ||    highlight_question_block: question lines applies ParleyQuestion highlight to continuation lines of a question block
workshop/plans/000171-footnote-coloring-close-review.md:3094: trailing whitespace.
+[32mSuccess[0m    ||    highlight_question_block: question lines does NOT apply ParleyQuestion highlight to 🤖: answer lines
workshop/plans/000171-footnote-coloring-close-review.md:3095: trailing whitespace.
+[32mSuccess[0m    ||    highlight_question_block: thinking lines applies Think highlight to 📝: summary line
workshop/plans/000171-footnote-coloring-close-review.md:3096: trailing whitespace.
+[32mSuccess[0m    ||    highlight_question_block: thinking lines applies ParleyThinking highlight to 🧠: reasoning line
workshop/plans/000171-footnote-coloring-close-review.md:3097: trailing whitespace.
+[32mSuccess[0m    ||    highlight_question_block: file reference lines applies FileLoading highlight to @@ file reference lines in a question block
workshop/plans/000171-footnote-coloring-close-review.md:3098: trailing whitespace.
+[32mSuccess[0m    ||    highlight_question_block: file reference lines does NOT apply ParleyFileReference highlight to @@ lines outside question blocks
workshop/plans/000171-footnote-coloring-close-review.md:3099: trailing whitespace.
+[32mSuccess[0m    ||    highlight_question_block: managed footnote footer uses a dedicated footnote highlight instead of open-question coloring
workshop/plans/000171-footnote-coloring-close-review.md:3100: trailing whitespace.
+[32mSuccess[0m    ||    decoration provider cache keeps highlight caches isolated per window for the same buffer
workshop/plans/000171-footnote-coloring-close-review.md:3101: trailing whitespace.
+[32mSuccess[0m    ||    decoration provider cache dims thinking-block continuation lines when viewport top falls between 🧠: and 🧠:[END]
workshop/plans/000171-footnote-coloring-close-review.md:3102: trailing whitespace.
+[32mSuccess[0m    ||    decoration provider cache dims streaming thinking-block continuation lines before 🧠:[END] is emitted
workshop/plans/000171-footnote-coloring-close-review.md:3103: trailing whitespace.
+[32mSuccess[0m    ||    decoration provider cache restores question highlights when redraw starts inside a long unanswered question
workshop/plans/000171-footnote-coloring-close-review.md:3104: trailing whitespace.
+[32mSuccess[0m    ||    timezone diagnostics publishes local-time diagnostics in its own namespace and clears stale diagnostics
workshop/plans/000171-footnote-coloring-close-review.md:3105: trailing whitespace.
+[32mSuccess[0m    ||    timezone diagnostics refreshes diagnostics for registered buffers on text changes
workshop/plans/000171-footnote-coloring-close-review.md:3106: trailing whitespace.
+[32mSuccess[0m    ||    markdown footnote diagnostics publishes persisted managed footnotes as Parley diagnostics
workshop/plans/000171-footnote-coloring-close-review.md:3107: trailing whitespace.
+[32mSuccess[0m    ||    markdown footnote diagnostics refreshes footnote diagnostics on markdown text changes without clearing other Parley diagnostics
workshop/plans/000171-footnote-coloring-close-review.md:3108: trailing whitespace.
+[32mSuccess[0m    ||    markdown footnote diagnostics renders managed footnote footers with ParleyFootnote in markdown buffers
workshop/plans/000171-footnote-coloring-close-review.md:3109: trailing whitespace.
+[32mSuccess[0m    ||    markdown chat reference rendering refreshes 🌿: branch lines with the chat topic in markdown buffers
workshop/plans/000171-footnote-coloring-close-review.md:3110: trailing whitespace.
+[32mSuccess[0m    ||    markdown chat reference rendering does not rewrite 🌿: lines pointing to non-chat files in markdown buffers
workshop/plans/000171-footnote-coloring-close-review.md:3111: trailing whitespace.
+[32mSuccess[0m    ||    markdown chat reference rendering refreshes from the updated topic in an open unsaved chat buffer
workshop/plans/000171-footnote-coloring-close-review.md:3112: trailing whitespace.
+
workshop/plans/000171-footnote-coloring-close-review.md:3113: trailing whitespace.
+[32mSuccess: [0m    20
workshop/plans/000171-footnote-coloring-close-review.md:3114: trailing whitespace.
+[31mFailed : [0m    0
workshop/plans/000171-footnote-coloring-close-review.md:3115: trailing whitespace.
+[31mErrors : [0m    0
workshop/plans/000171-footnote-coloring-close-review.md:3116: trailing whitespace.
+========================================

exec
/bin/zsh -lc 'git diff --name-only 4005929621a91a6e1a9a02bd048a859bb59ffb77..HEAD && git diff --stat 4005929621a91a6e1a9a02bd048a859bb59ffb77..HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
atlas/ui/highlights.md
lua/parley/config.lua
lua/parley/define.lua
lua/parley/highlighter.lua
tests/integration/highlighting_spec.lua
tests/unit/define_spec.lua
workshop/issues/000171-footnote-coloring.md
workshop/lessons.md
workshop/plans/000171-footnote-coloring-close-review.md
 atlas/ui/highlights.md                             |    5 +-
 lua/parley/config.lua                              |    1 +
 lua/parley/define.lua                              |   12 +
 lua/parley/highlighter.lua                         |  206 +-
 tests/integration/highlighting_spec.lua            |   62 +
 tests/unit/define_spec.lua                         |   24 +
 workshop/issues/000171-footnote-coloring.md        |   70 +-
 workshop/lessons.md                                |    3 +
 .../plans/000171-footnote-coloring-close-review.md | 3186 ++++++++++++++++++++
 9 files changed, 3472 insertions(+), 97 deletions(-)

exec
/bin/zsh -lc 'git status --short' in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
 M workshop/issues/000162-split-parley-into-two-different-plugins.md
 M workshop/issues/000168-buffer-undo-operation-during-chat-generation-resulted-in-a-huge-error-message.md
 M workshop/issues/000170-parley-chat-performance-problem.md

codex
The core fix and the earlier config finding are addressed in the current tree. A new problem is in the committed review artifact itself: whole-window `git diff --check` now fails on `workshop/plans/000171-footnote-coloring-close-review.md` due many trailing-whitespace lines, so I’m treating that as the remaining boundary finding.
exec
/bin/zsh -lc "nl -ba lua/parley/config.lua | sed -n '638,652p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   638        -- highlight styling (set to nil to use defaults that match your colorscheme)
   639        -- these settings override the default highlight links if provided
   640        highlight = {
   641            -- Use existing highlight groups by default (nil values)
   642            question = nil, -- highlight for user questions (default: links to Keyword)
   643            file_reference = nil, -- highlight for file references (default: links to WarningMsg)
   644            thinking = nil, -- highlight for reasoning lines (default: links to Comment)
   645            annotation = nil, -- highlight for annotations (default: links to DiffAdd)
   646            approximate_match = nil, -- highlight for typo-tolerance edit positions in picker matches (default: links to IncSearch)
   647            chat_reference = nil, -- highlight for 🌿: chat branch/parent links (default: links to Special)
   648            reference = nil, -- highlight for [referenced span] markers left by drill-in (#127) (default: underline)
   649            footnote = nil, -- highlight for managed definition-footnote footer lines (default: links to DiagnosticHint)
   650        },
   651
   652        -- lualine integration options

exec
/bin/zsh -lc "nl -ba tests/integration/highlighting_spec.lua | sed -n '165,187p' && nl -ba tests/integration/highlighting_spec.lua | sed -n '600,635p' && nl -ba tests/unit/define_spec.lua | sed -n '243,265p'" in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc "nl -ba lua/parley/define.lua | sed -n '162,205p' && nl -ba lua/parley/highlighter.lua | sed -n '266,308p' && nl -ba lua/parley/highlighter.lua | sed -n '466,482p'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   165    describe("highlight_question_block: managed footnote footer", function()
   166        after_each(cleanup_bufs)
   167
   168        it("uses a dedicated footnote highlight instead of open-question coloring", function()
   169            local buf = highlighted_buf({
   170                "💬: Define ASIN",
   171                "This question is still open.",
   172                "",
   173                "---",
   174                "",
   175                "[^asin]: Amazon Standard Identification Number.",
   176            })
   177
   178            assert.is_true(has_highlight(buf, 3, "ParleyFootnote"),
   179                "Expected the managed footer divider to use ParleyFootnote")
   180            assert.is_true(has_highlight(buf, 5, "ParleyFootnote"),
   181                "Expected the managed footnote definition to use ParleyFootnote")
   182            assert.is_false(has_highlight(buf, 3, "ParleyQuestion"),
   183                "Managed footer divider should not inherit open-question color")
   184            assert.is_false(has_highlight(buf, 5, "ParleyQuestion"),
   185                "Managed footnote definition should not inherit open-question color")
   186        end)
   187    end)
   600        it("renders managed footnote footers with ParleyFootnote in markdown buffers", function()
   601            local provider = capture_decoration_provider()
   602            local buf = vim.api.nvim_create_buf(false, true)
   603            vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
   604                "here is ASIN[^asin] in context",
   605                "",
   606                "---",
   607                "",
   608                "[^asin]: Amazon Standard Identification Number.",
   609            })
   610            parley._parley_bufs[buf] = "markdown"
   611
   612            local win = vim.api.nvim_get_current_win()
   613            vim.api.nvim_win_set_buf(win, buf)
   614            provider.on_win(nil, win, buf, 0, 4)
   615
   616            local original_set_extmark = vim.api.nvim_buf_set_extmark
   617            local extmarks = {}
   618            vim.api.nvim_buf_set_extmark = function(_, _, row, _, opts)
   619                table.insert(extmarks, { row = row, hl_group = opts.hl_group })
   620                return #extmarks
   621            end
   622
   623            provider.on_line(nil, win, buf, 2)
   624            provider.on_line(nil, win, buf, 4)
   625
   626            vim.api.nvim_buf_set_extmark = original_set_extmark
   627
   628            local highlighted = {}
   629            for _, mark in ipairs(extmarks) do
   630                if mark.hl_group == "ParleyFootnote" then
   631                    highlighted[mark.row] = true
   632                end
   633            end
   634            assert.is_true(highlighted[2], "Expected markdown footer divider to use ParleyFootnote")
   635            assert.is_true(highlighted[4], "Expected markdown footnote definition to use ParleyFootnote")
   243        it("reports the final managed footnote footer range", function()
   244            local range = define.managed_footnote_footer_range({
   245                "answer text",
   246                "",
   247                "---",
   248                "",
   249                "[^asin]: Amazon Standard Identification Number.",
   250            })
   251
   252            assert.are.same({ start_line = 3, end_line = 5 }, range)
   253        end)
   254
   255        it("does not report ordinary horizontal rules as managed footnote footers", function()
   256            local range = define.managed_footnote_footer_range({
   257                "answer text",
   258                "",
   259                "---",
   260                "",
   261                "not a footnote",
   262            })
   263
   264            assert.is_nil(range)
   265        end)

 succeeded in 0ms:
   162    local function is_divider(line)
   163        return trim(line) == "---"
   164    end
   165
   166    local function is_footnote_line(line)
   167        return trim(line):match("^%[%^[^%]]+%]:") ~= nil
   168    end
   169
   170    local function managed_footer_start(lines)
   171        for i = #lines, 1, -1 do
   172            if is_divider(lines[i]) then
   173                local has_footnote = false
   174                for j = i + 1, #lines do
   175                    local line = lines[j] or ""
   176                    if trim(line) ~= "" then
   177                        if not is_footnote_line(line) then
   178                            return nil
   179                        end
   180                        has_footnote = true
   181                    end
   182                end
   183                if has_footnote then
   184                    return i
   185                end
   186                return nil
   187            end
   188        end
   189        return nil
   190    end
   191
   192    --- Locate the final managed definition-footnote footer.
   193    --- @param lines string[]|nil
   194    --- @return table|nil { start_line: integer, end_line: integer } 1-based inclusive
   195    function M.managed_footnote_footer_range(lines)
   196        lines = lines or {}
   197        local start = managed_footer_start(lines)
   198        if not start then
   199            return nil
   200        end
   201        return { start_line = start, end_line = #lines }
   202    end
   203
   204    local function parse_footnote_line(line)
   205        local id, definition = trim(line):match("^%[%^([^%]]+)%]:%s*(.-)%s*$")
   266        local result = {}
   267        local patterns = get_chat_highlight_prefix_patterns()
   268        local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)
   269        local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
   270        local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
   271        -- While a stream is in flight for this buffer, the model has not
   272        -- yet emitted 🧠:[END]. Assume explicit-end mode so blank-line
   273        -- paragraph breaks inside the in-progress thinking region keep
   274        -- their dim highlight instead of prematurely terminating the
   275        -- block. After the stream completes (is_busy → false), the
   276        -- lookahead-decided mode takes over and a real [END] / structural
   277        -- marker controls termination.
   278        local streaming = require("parley.tasker").is_busy(buf, true)
   279        local in_block, in_code_block, in_reasoning_block, in_reasoning_explicit_end =
   280            bootstrap_chat_highlight_state(buf, start_line, patterns, streaming)
   281
   282        local in_tool_block = false  -- inside 🔧:/📎: fenced content
   283
   284        for offset, line in ipairs(lines) do
   285            local line_nr = start_line + offset - 1
   286            if line:match("^%s*```") then
   287                in_code_block = not in_code_block
   288                -- Exiting a code block while in a tool region ends the tool region
   289                if not in_code_block and in_tool_block then
   290                    in_tool_block = false
   291                end
   292            end
   293
   294            local highlighted_regions = {}
   295            local row = line_nr - 1
   296
   297            result[row] = result[row] or {}
   298
   299            push_artifact_refs(result, row, line) -- #160: navigable artifact refs
   300
   301            local is_footer = footer_range and line_nr >= footer_range.start_line and line_nr <= footer_range.end_line
   302            if is_footer then
   303                table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
   304                in_block = false
   305            else
   306                local pos = 1
   307                while true do
   308                    local tag_start, content_start = line:find("@@", pos)
   466    local function compute_markdown_highlights(buf, start_line, end_line)
   467        local result = {}
   468        local branch_prefix = _parley.config.chat_branch_prefix or "🌿:"
   469        local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)
   470        local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
   471        local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
   472        for offset, line in ipairs(lines) do
   473            local row = start_line + offset - 2
   474            local line_nr = row + 1
   475            push_artifact_refs(result, row, line) -- #160: navigable artifact refs
   476            if footer_range and line_nr >= footer_range.start_line and line_nr <= footer_range.end_line then
   477                result[row] = result[row] or {}
   478                table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
   479            end
   480            if line:sub(1, #branch_prefix) == branch_prefix then
   481                result[row] = result[row] or {}
   482                table.insert(result[row], { hl_group = "ParleyChatReference", col_start = 0, col_end = -1 })

exec
/bin/zsh -lc "rg -n \"ParleyFootnote|highlight\\.footnote|footnote = nil|managed footnote footer\" atlas README.md lua/parley/config.lua lua/parley/highlighter.lua workshop/issues/000171-footnote-coloring.md workshop/lessons.md" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
workshop/lessons.md:150:- **A new `config.highlight.*` override is user-facing even when it is optional.** #171 added `config.highlight.footnote` support in the highlighter and documented the highlight group in atlas, but the close review caught that the default config/reference table still omitted the key. Rule: whenever code reads a new config override key, update `lua/parley/config.lua`'s defaults in the same commit and grep README/atlas for config snippets that mirror those defaults.
lua/parley/highlighter.lua:303:            table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
lua/parley/highlighter.lua:478:            table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
lua/parley/highlighter.lua:750:        vim.api.nvim_set_hl(0, "ParleyFootnote", user_highlights.footnote)
lua/parley/highlighter.lua:752:        vim.api.nvim_set_hl(0, "ParleyFootnote", { link = "DiagnosticHint" })
workshop/issues/000171-footnote-coloring.md:28:`ParleyFootnote` highlight group in both chat and markdown buffers.
workshop/issues/000171-footnote-coloring.md:40:- A regression test covers an open question followed by a managed footnote footer.
workshop/issues/000171-footnote-coloring.md:41:- Footer divider and footnote definition rows receive `ParleyFootnote`.
workshop/issues/000171-footnote-coloring.md:50:- [x] Apply `ParleyFootnote` in chat and markdown highlight computation.
workshop/issues/000171-footnote-coloring.md:78:- Implemented `ParleyFootnote` for managed footer rows in both chat and markdown
workshop/issues/000171-footnote-coloring.md:91:  `config.highlight.footnote` was supported by highlighter code but missing from
lua/parley/config.lua:649:        footnote = nil, -- highlight for managed definition-footnote footer lines (default: links to DiagnosticHint)
atlas/chat/inline_define.md:6:(`ASIN[^asin]`), while the definition is stored in a managed footnote footer at
atlas/chat/inline_define.md:35:   and inserts/updates a final managed footnote footer via one buffer rewrite
atlas/chat/inline_define.md:138:- `lua/parley/chat_respond.lua` — strips managed footnote footer from LLM messages.
atlas/ui/highlights.md:4:Custom groups (`ParleyQuestion`, `ParleyFileReference`, `ParleyChatReference`, `ParleyThinking`, `ParleyAnnotation`, `ParleyReference`, `ParleyFootnote`, `ParleyPickerApproximateMatch`, `InterviewTimestamp`, `InterviewThought`) linked to standard Neovim groups. `ParleyReference` (default underline) marks drill-in `[referenced span]` brackets — see [chat/drill_in](../chat/drill_in.md). `ParleyFootnote` (default `DiagnosticHint`) marks managed definition-footnote footer lines.
atlas/ui/highlights.md:10:  `ParleyFootnote` in chat and markdown buffers instead of inheriting the active

codex
The Spec/Plan items line up with the implementation and tests. I’m running the focused test files now so the verdict has current verification evidence; the whole-window whitespace failure is already confirmed.
exec
/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"' in /Users/xianxu/workspace/parley.nvim
exec
/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"' in /Users/xianxu/workspace/parley.nvim
 succeeded in 1489ms:

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
[32mSuccess[0m    ||    define durable footnotes reports the final managed footnote footer range
[32mSuccess[0m    ||    define durable footnotes does not report ordinary horizontal rules as managed footnote footers
[32mSuccess[0m    ||    define durable footnotes keeps earlier horizontal-rule content and strips only the final managed footer
[32mSuccess[0m    ||    define durable footnotes extracts persisted footnote diagnostics from the managed footer
[32mSuccess[0m    ||    define durable footnotes extracts every inline reference to a managed footnote
[32mSuccess[0m    ||    define durable footnotes ignores footnotes that are not in a final managed footer

[32mSuccess: [0m    28
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
]111
 succeeded in 2138ms:

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
[32mSuccess[0m    ||    markdown footnote diagnostics refreshes footnote diagnostics on markdown text changes without clearing other Parley diagnostics
[32mSuccess[0m    ||    markdown footnote diagnostics renders managed footnote footers with ParleyFootnote in markdown buffers
[32mSuccess[0m    ||    markdown chat reference rendering refreshes 🌿: branch lines with the chat topic in markdown buffers
[32mSuccess[0m    ||    markdown chat reference rendering does not rewrite 🌿: lines pointing to non-chat files in markdown buffers
[32mSuccess[0m    ||    markdown chat reference rendering refreshes from the updated topic in an open unsaved chat buffer

[32mSuccess: [0m    20
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
]111
codex
```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The core footnote-coloring implementation is sound: the footer grammar is reused from `parley.define`, chat and markdown buffers apply `ParleyFootnote`, and the earlier missing `config.highlight.footnote` default is now fixed. I found no correctness blockers in the Lua changes, but the current whole-window diff fails `git diff --check` because the newly added close-review artifact contains many trailing-whitespace lines. Fix that before crossing the boundary.

1. Strengths:
- [lua/parley/define.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/define.lua:195) exposes a pure `managed_footnote_footer_range`, keeping footer detection single-sourced. ARCH-DRY pass.
- [lua/parley/highlighter.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/highlighter.lua:270) and [lua/parley/highlighter.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/highlighter.lua:471) consume that helper in thin UI code. ARCH-PURE pass.
- [tests/integration/highlighting_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/integration/highlighting_spec.lua:168) pins the open-question regression directly.
- [lua/parley/config.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/config.lua:649) now documents the `highlight.footnote` override in the default config reference.

2. Critical findings:
- None.

3. Important findings:
- [workshop/plans/000171-footnote-coloring-close-review.md](/Users/xianxu/workspace/parley.nvim/workshop/plans/000171-footnote-coloring-close-review.md:232) and many later lines contain trailing whitespace, causing `git diff --check 4005929621a91a6e1a9a02bd048a859bb59ffb77..HEAD` to fail. Fix sketch: strip trailing whitespace from the generated review artifact, or regenerate/sanitize it before committing.

4. Minor findings:
- None.

5. Test coverage notes:
- Passed: `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`: 28/28.
- Passed: `nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"`: 20/20.
- Startup emitted local parser/LuaSnip/parley state write warnings, but both focused test commands exited 0.

6. Architectural notes for upcoming work:
- ARCH-DRY: Pass. No duplicated footer grammar in highlighter.
- ARCH-PURE: Pass. Pure range helper is unit-tested; highlighter remains boundary glue.
- ARCH-PURPOSE: Pass. The issue’s chat and markdown consumers both derive from the shared footer detector.

7. Plan revision recommendations:
- None for the implementation plan. After cleaning the review artifact, update the issue Log evidence if the final verification includes whole-window `git diff --check`.
tokens used
103,118
```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The core footnote-coloring implementation is sound: the footer grammar is reused from `parley.define`, chat and markdown buffers apply `ParleyFootnote`, and the earlier missing `config.highlight.footnote` default is now fixed. I found no correctness blockers in the Lua changes, but the current whole-window diff fails `git diff --check` because the newly added close-review artifact contains many trailing-whitespace lines. Fix that before crossing the boundary.

1. Strengths:
- [lua/parley/define.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/define.lua:195) exposes a pure `managed_footnote_footer_range`, keeping footer detection single-sourced. ARCH-DRY pass.
- [lua/parley/highlighter.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/highlighter.lua:270) and [lua/parley/highlighter.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/highlighter.lua:471) consume that helper in thin UI code. ARCH-PURE pass.
- [tests/integration/highlighting_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/integration/highlighting_spec.lua:168) pins the open-question regression directly.
- [lua/parley/config.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/config.lua:649) now documents the `highlight.footnote` override in the default config reference.

2. Critical findings:
- None.

3. Important findings:
- [workshop/plans/000171-footnote-coloring-close-review.md](/Users/xianxu/workspace/parley.nvim/workshop/plans/000171-footnote-coloring-close-review.md:232) and many later lines contain trailing whitespace, causing `git diff --check 4005929621a91a6e1a9a02bd048a859bb59ffb77..HEAD` to fail. Fix sketch: strip trailing whitespace from the generated review artifact, or regenerate/sanitize it before committing.

4. Minor findings:
- None.

5. Test coverage notes:
- Passed: `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`: 28/28.
- Passed: `nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"`: 20/20.
- Startup emitted local parser/LuaSnip/parley state write warnings, but both focused test commands exited 0.

6. Architectural notes for upcoming work:
- ARCH-DRY: Pass. No duplicated footer grammar in highlighter.
- ARCH-PURE: Pass. Pure range helper is unit-tested; highlighter remains boundary glue.
- ARCH-PURPOSE: Pass. The issue’s chat and markdown consumers both derive from the shared footer detector.

7. Plan revision recommendations:
- None for the implementation plan. After cleaning the review artifact, update the issue Log evidence if the final verification includes whole-window `git diff --check`.
