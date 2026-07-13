# Boundary Review — 000182-claude-code-style-progression-text-in-parley-chat#182 (whole-issue close)

| field | value |
|-------|-------|
| issue | 182 — claude code style progression text in parley chat |
| repo | 000182-claude-code-style-progression-text-in-parley-chat |
| issue file | workshop/issues/000182-claude-code-style-progression-text-in-parley-chat.md |
| boundary | whole-issue close |
| milestone | — |
| window | 27a778b7876adfdf3816b8c701e2b355252c357b..HEAD |
| command | sdlc close --issue 182 |
| reviewer | codex |
| timestamp | 2026-07-13T03:34:31-07:00 |
| verdict | REWORK |

## Review

Reading additional input from stdin...
OpenAI Codex v0.144.2
--------
workdir: /Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat
model: gpt-5.6-sol
provider: openai
approval: never
sandbox: workspace-write [workdir, /tmp, $TMPDIR]
reasoning effort: none
reasoning summaries: none
session id: 019f5b05-f527-7f40-91c5-e470554c7311
--------
user
# Code review — the one SDLC boundary review

You are conducting a fresh-context code review at a development boundary —
whole-issue close — in the **000182-claude-code-style-progression-text-in-parley-chat** repository.

- repository: 000182-claude-code-style-progression-text-in-parley-chat   (root: /Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat)
- issue:      000182-claude-code-style-progression-text-in-parley-chat#182   (file: workshop/issues/000182-claude-code-style-progression-text-in-parley-chat.md)
- window:     Base: 27a778b7876adfdf3816b8c701e2b355252c357b   Head: HEAD

Review the **000182-claude-code-style-progression-text-in-parley-chat** repo and its tracker — the ariadne base-layer repo itself (changes here propagate to dependent repos). Do not assume any
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
diff --git a/README.md b/README.md
index 59f2207..0565a45 100644
--- a/README.md
+++ b/README.md
@@ -106,7 +106,9 @@ Notes:
 1. Run `:ParleyChatNew` (default shortcut: `<C-g>c`) to create a new chat.
 2. Type your question after `💬:`, no need for anything else. `Topic: ?` will be automatically filled with summary of your question.
 3. Run `:ParleyChatRespond` (default shortcut: `<C-g><C-g>`) with mouse on the question line.
-4. Get response from the agent after `🤖:`, streaming in real time.
+4. Get a response from the agent after `🤖:`, streaming in real time. A slow
+   start shows a playful virtual progress line after one second; it never enters
+   the Markdown transcript.

 A Parley chat is a normal markdown file with a header and alternating `💬:` / `🤖:` blocks.

@@ -121,7 +123,7 @@ Most-used defaults:
 **In Chat Buffer**
 - `<C-g>?` show key bindings
 - `<C-g><C-g>` respond
-- `<M-CR>` respond (normal/insert); **visual-select a phrase + `<M-CR>`** → inline term definition — adds a markdown footnote reference/footer and shows a centered diagnostic float, honoring `:ToggleWebSearch` for unfamiliar terms
+- `<M-CR>` respond (normal/insert); **visual-select a phrase + `<M-CR>`** → inline term definition — immediately shows a spinner after the selection, then on success replaces it with a markdown footnote reference/footer and centered diagnostic float, honoring `:ToggleWebSearch` for unfamiliar terms
   - Reopened chats recover multi-word highlights from structured footnotes such as `[^acos]: "Advertising Cost of Sales". Ratio...`; generated ids such as `[^serverless-functions]` also recover `serverless functions` from the slug when that phrase appears before the reference.
 - `<C-g>G` respond all
 - `<C-g>x` stop
@@ -150,7 +152,7 @@ Most-used defaults:
 - Providers: OpenAI, Anthropic, Google AI, Ollama, OpenAI-compatible endpoints, and CLIProxyAPI.
   - parley can **manage a local `cliproxyapi`** for you — it renders the config from Lua and lazily starts/reuses/health-checks the proxy. `:ParleyProxy status|start|stop|restart|models <provider>|providers|login <provider>|update` (bare `:ParleyProxy` prints per-subcommand help). **On by default but dormant** — only acts when a cliproxyapi-provider agent runs, and reuses an existing proxy if one is up; a fresh machine needs `brew install cliproxyapi` + a one-time `:ParleyProxy login`. Set `cliproxy = { manage = false }` to opt out. See [atlas/providers/cliproxy-managed.md](atlas/providers/cliproxy-managed.md).
 - File context with `@@path/to/file` and directory patterns.
-- Web search toggle for supported providers.
+- Web search toggle for supported providers, with semantic search/reasoning status shown in the response's transient virtual progress line.
 - Outline navigation, highlighting.
 - Export chat to markdown or HTML, for blogging, e.g. [a chat about async programming](https://xianxu.github.io/2025/05/12/conversation_around_concurrent_programming_models.html).
 - Misc: notes, interview mode, raw mode, and export.
diff --git a/atlas/chat/inline_define.md b/atlas/chat/inline_define.md
index 725c2f3..499ffc6 100644
--- a/atlas/chat/inline_define.md
+++ b/atlas/chat/inline_define.md
@@ -23,13 +23,22 @@ rehydrates persisted managed footnotes in all markdown buffers.
    empty/whitespace, and computes a **bounded context** = the *enclosing
    exchange* of the selection (`define.context_for_selection` over `parse_chat`
    + `find_exchange_at_line`), falling back to the whole buffer.
-2. It fires a headless **`define` skill** turn via `skill_invoke.invoke` with
-   `opts.document = context`, `opts.no_reload = true`, and an `on_done`.
-3. The `define` skill (`lua/parley/skills/define/init.lua`) is **unforced** (no
+2. It immediately starts `selection_spinner` at the exclusive end of the
+   selected phrase. The inline virtual text begins as ` ⠙`, animates from the
+   canonical spinner frames, and never changes the buffer or waits for a reveal
+   threshold.
+3. It fires a headless **`define` skill** turn via `skill_invoke.invoke` with
+   `opts.document = context`, `opts.no_reload = true`,
+   `opts.detached_progress = false`, and the spinner's idempotent stop function
+   as `opts.on_terminal`. Definition therefore does not open the detached
+   luabar; Document Review and generic skills retain that default progress UI.
+4. The `define` skill (`lua/parley/skills/define/init.lua`) is **unforced** (no
    `force_tool`) so the server-side `web_search` tool can run when the global
    `:ToggleWebSearch` is on; its `source(ctx)` folds the phrase into the system
    prompt and asks the model to call `emit_definition({term, definition})`.
-4. **`render_definition`** (`on_done`), on a successful lookup: re-verifies the
+5. `skill_invoke` runs terminal cleanup before `on_done` on success, failure,
+   cancellation, process abort, or an invalid buffer. **`render_definition`**
+   (`on_done`), on a successful lookup: re-verifies the
    selection still holds the phrase (else skips — the buffer changed under the
    in-flight call), then **(a)** adds a `[^id]` reference after the selected term
    and inserts/updates a final managed footnote footer via one buffer rewrite
@@ -42,8 +51,9 @@ rehydrates persisted managed footnotes in all markdown buffers.
    `skill_render.format_diagnostic_message`) on the `parley_skill` namespace;
    **(d)** records the undo/redo projection states.
    `diag_display` opens a centered, non-focusable diagnostic float when the
-   cursor is on the term/footnote anchor span. A no-`emit_definition` response
-   leaves no footnote reference/footer.
+   cursor is on the term/footnote anchor span. A no-`emit_definition` response,
+   stale selection, cancellation, provider failure, or deleted buffer leaves no
+   footnote reference/footer and no pending spinner.

 ## Undo (`u`) — reuses review's projection

@@ -68,6 +78,7 @@ watcher doesn't mistake it for a user edit.
   `strip_definition_footnote_footer` / `footnote_diagnostics` (treat the first
   markdown footnote definition line as the managed footer boundary).
 - **IO shell** (`lua/parley/init.lua`): `define_visual`, `render_definition`;
+  `lua/parley/selection_spinner.lua` owns immediate selection-anchored progress;
   `lua/parley/buffer_edit.lua` owns the full-buffer footnote rewrite;
   `lua/parley/skill_render.lua` publishes footnote diagnostics; and
   `lua/parley/highlighter.lua` refreshes them from chat and markdown lifecycle
@@ -151,9 +162,12 @@ tool-call args (`result.calls[1].input`), read in `on_done`.
 - `lua/parley/chat_respond.lua` — strips managed footnote footer from LLM messages.
 - `lua/parley/skills/define/init.lua` — the unforced `define` skill.
 - `lua/parley/tools/builtin/emit_definition.lua` — output-only structured tool.
-- `lua/parley/skill_invoke.lua` — `opts.no_reload` / `opts.document` seams.
+- `lua/parley/selection_spinner.lua` — immediate inline canonical spinner and idempotent teardown.
+- `lua/parley/skill_invoke.lua` — `opts.no_reload` / `opts.document`, optional detached progress, and terminal cleanup seams.
 - `lua/parley/config.lua`, `lua/parley/keybinding_registry.lua` — the `<M-CR>` split.
-- `tests/unit/define_spec.lua`, `tests/integration/define_spec.lua` — coverage.
+- `tests/unit/define_spec.lua`, `tests/integration/define_spec.lua`, and
+  `tests/integration/skill_invoke_spec.lua` — pure, inline lifecycle, and shared
+  terminal coverage.

 ## Related

diff --git a/atlas/chat/lifecycle.md b/atlas/chat/lifecycle.md
index ca49d2f..35b91a4 100644
--- a/atlas/chat/lifecycle.md
+++ b/atlas/chat/lifecycle.md
@@ -13,9 +13,9 @@ Moves entire chat tree (root + descendants) to another chat root; rewrites all `
 Splits current exchange + following into a new child chat with `🌿:` links. Async LLM topic generation.

 ## Response (`:ParleyChatRespond` / `<C-g><C-g>`)
-Assembles context (with memory summarization), streams LLM response into buffer. The [exchange model](exchange_model.md) is the single source of truth for all buffer mutations during the response lifecycle — streaming text growth, tool block insertion, spinner management, and prompt append all go through the model. Concurrent guard prevents duplicate calls.
+Assembles context (with memory summarization), streams LLM response into buffer. The [exchange model](exchange_model.md) is the single source of truth for all transcript mutations during the response lifecycle — streaming text growth, tool block insertion, and prompt append all go through the model. [Response progress](response_progress.md) is cosmetic extmark state anchored to the response header and never becomes a model block. A per-buffer pending-session guard prevents duplicate calls.

-Pending responses also hold a per-buffer chat lease (`lua/parley/chat_lease.lua`) anchored on an `invalidate=true` extmark on the response's `🤖:` agent-header line (#138). Each async callback validates the lease before mutating the transcript; ordinary edits and streaming move the anchor and stay valid, while deleting that line — undo/redo of the inserted response, or removing the header — invalidates the lease, stops/suppresses late stream/tool/progress/topic writes, and prevents recursive tool resubmit from using a stale live model. (Pre-#138 the lease keyed on buffer `changedtick`, which mis-read Parley's own writes/spinner frames as drift; the extmark anchor makes `commit` a no-op.)
+Pending responses also hold a per-buffer chat lease (`lua/parley/chat_lease.lua`) anchored on an `invalidate=true` extmark on the response's `🤖:` agent-header line (#138). Each async callback validates the lease before mutating the transcript; ordinary edits and streaming move the anchor and stay valid, while deleting that line — undo/redo of the inserted response, or removing the header — invalidates the lease, stops/suppresses late stream/tool/progress/topic writes, and prevents recursive tool resubmit from using a stale live model. The pending extmark and its staged output are discarded on lost ownership. (Pre-#138 the lease keyed on buffer `changedtick`, which mis-read Parley's own writes as drift; the extmark anchor makes `commit` a no-op.)

 ## Editing, Diagnostics, and Decoration Convergence

diff --git a/atlas/chat/response_progress.md b/atlas/chat/response_progress.md
new file mode 100644
index 0000000..c2d9038
--- /dev/null
+++ b/atlas/chat/response_progress.md
@@ -0,0 +1,99 @@
+# Chat Response Progress
+
+Parley gives each LLM leg that can become chat content a short, transient
+pending presentation. This covers the initial `chat_respond.respond` request
+and every recursive request around client-side tool calls. Topic generation,
+memory preferences, skills, and other background LLM work are not eligible.
+Definition has a separate immediate renderer described below.
+
+## Timing and State
+
+One `chat_pending` session owns one dispatched chat leg:
+
+1. The leg waits silently for one second. Answer text, reasoning status, or
+   remote-tool status received in that window is delivered normally, so fast
+   responses never show pending copy. Raw transport activity is not visible
+   output and does not end the wait.
+2. A still-silent leg shows a virtual line below its `🤖:` response header,
+   initially in the form `⠙ brewing`. The glyph animates from
+   `progress.SPINNER`; SSE/JSONL activity and 15 seconds of transport idleness
+   rotate the playful verb independently.
+3. Once shown, the line remains visible for at least one second. Visible output
+   arriving during that interval is staged in callback order. At the minimum
+   deadline Parley removes the playful line and releases all staged output once;
+   subsequent output streams normally. With no visible output, the playful line
+   remains rather than returning to silence.
+4. Meaningful provider progress uses the same extmark after release. Reasoning
+   details and remote-tool status therefore replace the playful copy without
+   becoming transcript text, while answer chunks continue through the ordinary
+   stream writer.
+
+`chat_presentation` is the pure reducer for deadlines, staging, terminal
+decisions, and provider-detail accumulation. `chat_pending` is the Neovim IO
+shell: it serializes public callbacks and timer events through the main loop,
+renders the reducer's actions, and owns all timers and the extmark.
+
+## Decoration and Transcript Ownership
+
+The pending/status line is an `invalidate=true` extmark with `virt_lines`; it
+never enters Markdown, the exchange model, undo history, saved files, parser
+input, or a future prompt. It is anchored to the durable response-header line
+owned by the exchange model. The independent chat lease decides whether that
+header still owns the in-flight response. Deleting or invalidating the header
+therefore cancels the session and suppresses late writes.
+
+Only one active pending session may own a buffer. `:ParleyStop` cancels all
+registered sessions before stopping subprocesses. Every terminal path removes
+the extmark, closes timers, and releases registry ownership; callbacks that
+arrive afterward are no-ops.
+
+## Tool Continuation and Terminal Paths
+
+A tool-use-only LLM leg that completes during the silent first second proceeds
+directly to its local tool. If its playful line is already visible, completion
+waits only for the one-second visible minimum; the line is removed before tool
+execution begins. Local tool execution itself has no playful spinner. A
+recursive LLM leg starts a fresh pending session after the tool result is added
+to the transcript.
+
+Successful empty completions follow the same minimum-visible rule. Provider
+failures are different: while the lease is valid, Parley immediately removes
+the decoration, releases any staged partial output in order, and then reports
+the transport or non-2xx HTTP error. Cancellation, a stale lease, or an invalid
+buffer removes the decoration immediately and discards staged output because
+the request no longer owns a writable transcript. Pre-start failures (secret
+resolution, busy process slot, or spawn rejection) converge on the same cleanup
+without waiting for a timer.
+
+Dispatcher transport activity is additive to semantic progress: one SSE record
+or complete structural JSONL line reports one activity event without delaying
+content/status parsing. HTTP status is captured in a stderr trailer after the
+process and both pipes drain, leaving response stdout byte-for-byte available
+for partial-output handling.
+
+## Definition and Other Skills
+
+Visual `<M-CR>` Definition deliberately does not use the delayed chat policy.
+`selection_spinner` immediately anchors inline virtual text after the selected
+term (`CVR ⠙`), with no reveal delay or minimum duration. `skill_invoke` runs
+its idempotent `on_terminal` cleanup before `on_done`; a valid result then adds
+the durable footnote (`CVR[^cvr]`). Every failure, cancellation, stale selection,
+or deleted-buffer path removes the spinner without adding a footnote.
+
+Definition sets `detached_progress=false` because the selection is its natural
+progress anchor. Document Review, Voice Apply, and generic skill invocations
+retain the detached luabar progress UI by default.
+
+## Key Files
+
+- `lua/parley/chat_presentation.lua` — pure response-presentation reducer.
+- `lua/parley/chat_pending.lua` — main-loop timer/extmark adapter and registry.
+- `lua/parley/chat_respond.lua` — eligible initial/recursive leg integration.
+- `lua/parley/dispatcher.lua`, `lua/parley/tasker.lua`, `lua/parley/vault.lua` —
+  activity, drained terminal, HTTP failure, and pre-start failure boundaries.
+- `lua/parley/selection_spinner.lua`, `lua/parley/skill_invoke.lua` — immediate
+  Definition renderer and generalized skill terminal cleanup.
+- `tests/unit/chat_presentation_spec.lua`,
+  `tests/integration/chat_pending_spec.lua`, and
+  `tests/integration/chat_progress_process_spec.lua` — state, Neovim adapter,
+  and real curl/SSE process coverage.
diff --git a/atlas/context/web_search.md b/atlas/context/web_search.md
index 412cf70..d507de1 100644
--- a/atlas/context/web_search.md
+++ b/atlas/context/web_search.md
@@ -9,5 +9,6 @@ Anthropic (tool-based), Google AI (`google_search` tool), OpenAI (search-model s

 ## UI
 - Lualine: `[w]` when active, `[w?]` if unsupported by agent
-- In-buffer animated spinner and progress line during search/reasoning, cleared on completion
-- All providers normalize progress events to a shared shape (`kind`, `phase`, `message`)
+- Chat-producing LLM legs use the shared [response-progress](../chat/response_progress.md) extmark: a delayed playful line covers initial silence, then meaningful search/reasoning status replaces it without changing transcript text
+- Web search does not own a buffer-backed initial spinner; non-chat web-enabled calls keep the progress surface of their caller (for example Definition's selection spinner or Document Review's detached luabar)
+- All providers normalize semantic progress events to a shared shape (`kind`, `phase`, `message`); raw transport activity is a separate callback used only for playful verb timing
diff --git a/atlas/index.md b/atlas/index.md
index 3fa0f8e..e26b22e 100644
--- a/atlas/index.md
+++ b/atlas/index.md
@@ -6,6 +6,7 @@ This index provides a central directory for all atlas entries of the `parley.nvi
 ## 1. Core Chat System
 - [Chat Format](chat/format.md): Transcript prefixes and front matter header metadata.
 - [Chat Lifecycle](chat/lifecycle.md): Creation, slug rename (auto from topic), response, resubmission, and deletion.
+- [Chat Response Progress](chat/response_progress.md): Delayed playful pending presentation, semantic status handoff, tool continuation, and terminal cleanup for chat-producing LLM legs.
 - [Chat Memory](chat/memory.md): History management, summarization, and preservation.
 - [Memory Preferences](chat/memory_prefs.md): Per-tag user preference profiles from chat history summaries.
 - [Chat Parsing](chat/parsing.md): Buffer segmentation, turn identification, and branch link parsing.
diff --git a/atlas/providers/tool_use.md b/atlas/providers/tool_use.md
index f3ae791..7be654a 100644
--- a/atlas/providers/tool_use.md
+++ b/atlas/providers/tool_use.md
@@ -85,4 +85,6 @@ Tool blocks in the transcript:
 - 🔧:/📎: blocks are dimmed (`ParleyThinking` highlight = `Comment`)
 - Error results highlighted with `ParleyToolError` = `DiagnosticError`
 - Completed tool blocks auto-folded via model-based manual folds
-- Spinner shows during every API call (including recursive rounds)
+- Each initial or recursive LLM round uses the delayed virtual
+  [response-progress](../chat/response_progress.md) presentation; fast visible
+  output bypasses it, and local tool execution itself shows no spinner
diff --git a/atlas/traceability.yaml b/atlas/traceability.yaml
index d18e5e5..47bc807 100644
--- a/atlas/traceability.yaml
+++ b/atlas/traceability.yaml
@@ -46,6 +46,28 @@ atlas:
       - tests/integration/not_chat_spec.lua
       - tests/integration/timer_race_spec.lua

+  chat/response_progress:
+    code:
+      - lua/parley/chat_presentation.lua
+      - lua/parley/chat_pending.lua
+      - lua/parley/chat_respond.lua
+      - lua/parley/chat_lease.lua
+      - lua/parley/dispatcher.lua
+      - lua/parley/tasker.lua
+      - lua/parley/vault.lua
+      - lua/parley/progress.lua
+      - tests/fixtures/fake_sse_server
+    tests:
+      - tests/unit/chat_presentation_spec.lua
+      - tests/unit/dispatcher_query_spec.lua
+      - tests/unit/vault_spec.lua
+      - tests/integration/chat_pending_spec.lua
+      - tests/integration/chat_respond_spec.lua
+      - tests/integration/chat_progress_process_spec.lua
+      - tests/integration/tasker_run_spec.lua
+      - tests/integration/topic_gen_spec.lua
+      - tests/integration/cliproxy_caller_teardown_spec.lua
+
   chat/memory:
     code:
       - lua/parley/init.lua
@@ -108,12 +130,15 @@ atlas:
       - lua/parley/tools/builtin/emit_definition.lua
       - lua/parley/tools/init.lua
       - lua/parley/skill_invoke.lua
+      - lua/parley/selection_spinner.lua
       - lua/parley/skill_render.lua
       - lua/parley/config.lua
       - lua/parley/keybinding_registry.lua
     tests:
       - tests/unit/define_spec.lua
       - tests/integration/define_spec.lua
+      - tests/integration/skill_invoke_spec.lua
+      - tests/integration/cliproxy_caller_teardown_spec.lua

   context/file_references:
     code:
diff --git a/lua/parley/buffer_edit.lua b/lua/parley/buffer_edit.lua
index 5c780b1..3f7c57f 100644
--- a/lua/parley/buffer_edit.lua
+++ b/lua/parley/buffer_edit.lua
@@ -189,28 +189,6 @@ function M.stream_finalize(handle)
     M.handle_invalidate(handle)
 end

--- ============================================================================
--- Progress indicator
--- ============================================================================
-
---- Replace the line at the handle's position with `text`.
-function M.set_progress_line(handle, text)
-    if handle.dead then
-        return
-    end
-    local line = M.handle_line(handle)
-    vim.api.nvim_buf_set_lines(handle.buf, line, line + 1, false, { text or "" })
-end
-
---- Delete `count` lines starting at the handle's position.
-function M.clear_progress_lines(handle, count)
-    if handle.dead then
-        return
-    end
-    local line = M.handle_line(handle)
-    vim.api.nvim_buf_set_lines(handle.buf, line, line + count, false, {})
-end
-
 -- ============================================================================
 -- Cancellation cleanup
 -- ============================================================================
diff --git a/lua/parley/chat_pending.lua b/lua/parley/chat_pending.lua
new file mode 100644
index 0000000..d63a4fb
--- /dev/null
+++ b/lua/parley/chat_pending.lua
@@ -0,0 +1,442 @@
+-- Main-loop adapter for one chat-producing LLM leg's pending presentation.
+local M = {}
+
+local logger = require("parley.logger")
+local presentation = require("parley.chat_presentation")
+local spinner = require("parley.progress").SPINNER
+local unpack_values = unpack
+
+local namespace = vim.api.nvim_create_namespace("parley_chat_pending")
+local active_by_buf = {}
+local verbs = { "brewing", "cooking", "dragon-slaying" }
+
+local function monotonic_now_ms()
+    local uv = vim.uv or vim.loop
+    return uv.hrtime() / 1000000
+end
+
+local function close_timer(timer)
+    if not timer then
+        return
+    end
+    pcall(function() timer:stop() end)
+    if not timer:is_closing() then
+        pcall(function() timer:close() end)
+    end
+end
+
+local function production_timer(delay_ms, repeat_ms, callback)
+    local uv = vim.uv or vim.loop
+    local timer = uv.new_timer()
+    local cancelled = false
+    timer:start(delay_ms, repeat_ms, callback)
+    return function()
+        if cancelled then
+            return
+        end
+        cancelled = true
+        close_timer(timer)
+    end
+end
+
+local production_scheduler = {
+    enqueue = vim.schedule,
+    after = function(delay_ms, callback)
+        return production_timer(delay_ms, 0, callback)
+    end,
+    every = function(delay_ms, callback)
+        return production_timer(delay_ms, delay_ms, callback)
+    end,
+}
+
+local function call_safely(label, callback, ...)
+    if type(callback) ~= "function" then
+        return
+    end
+    local arguments = { n = select("#", ...), ... }
+    local ok = xpcall(function()
+        callback(unpack_values(arguments, 1, arguments.n))
+    end, function()
+        -- Callback errors can contain provider output, chunks, or secrets.
+        return nil
+    end)
+    if not ok then
+        logger.error("chat pending " .. label .. " callback failed")
+    end
+end
+
+-- Start one serialized presentation session for a response header.
+M.start = function(opts)
+    opts = opts or {}
+    local buf = assert(opts.buf, "buf is required")
+    local existing = active_by_buf[buf]
+    assert(not existing or existing.finished, "chat pending session already active for buffer")
+
+    local scheduler = opts.scheduler or production_scheduler
+    local clock = opts.clock or { now_ms = monotonic_now_ms }
+    assert(type(scheduler.enqueue) == "function", "scheduler.enqueue is required")
+    assert(type(scheduler.after) == "function", "scheduler.after is required")
+    assert(type(scheduler.every) == "function", "scheduler.every is required")
+    assert(type(clock.now_ms) == "function", "clock.now_ms is required")
+
+    local session = {
+        buf = buf,
+        anchor_line = assert(opts.anchor_line, "anchor_line is required"),
+        lease_valid = assert(opts.lease_valid, "lease_valid is required"),
+        emit_content = assert(opts.emit_content, "emit_content is required"),
+        choose_verb_index = assert(opts.choose_verb_index, "choose_verb_index is required"),
+        on_discard = opts.on_discard,
+        scheduler = scheduler,
+        clock = clock,
+        timers = {},
+        frame_index = 2, -- The approved first visible frame is ⠙.
+        detail_state = {},
+        finished = false,
+    }
+    local function now_ms()
+        return session.clock.now_ms()
+    end
+
+    local initial_index = session.choose_verb_index(#verbs)
+    session.state = presentation.initial({
+        now_ms = now_ms(),
+        verbs = verbs,
+        verb_index = initial_index,
+    })
+    assert(session.on_discard == nil or type(session.on_discard) == "function",
+        "on_discard must be a function")
+
+    local function cancel_timer(name)
+        local cancel = session.timers[name]
+        session.timers[name] = nil
+        call_safely("timer cancellation", cancel)
+    end
+
+    local function cancel_timers()
+        local names = {}
+        for name in pairs(session.timers) do
+            table.insert(names, name)
+        end
+        for _, name in ipairs(names) do
+            cancel_timer(name)
+        end
+    end
+
+    local function hide()
+        if session.extmark_id then
+            pcall(vim.api.nvim_buf_del_extmark, session.buf, namespace, session.extmark_id)
+        end
+        session.visible_text = nil
+        session.playful_verb = nil
+    end
+
+    local function render(text)
+        if not vim.api.nvim_buf_is_valid(session.buf) then
+            return false
+        end
+        local ok, mark_id = pcall(vim.api.nvim_buf_set_extmark, session.buf, namespace,
+            session.anchor_line, 0, {
+                id = session.extmark_id,
+                virt_lines = { { { text, "Comment" } } },
+                virt_lines_above = false,
+                invalidate = true,
+            })
+        if not ok then
+            return false
+        end
+        session.extmark_id = mark_id
+        session.visible_text = text
+        return true
+    end
+
+    local function render_playful()
+        return render(spinner[session.frame_index] .. " " .. session.playful_verb)
+    end
+
+    local function finish()
+        if session.finished then
+            return
+        end
+        session.finished = true
+        cancel_timers()
+        hide()
+        if active_by_buf[session.buf] == session then
+            active_by_buf[session.buf] = nil
+        end
+    end
+
+    local dispatch
+
+    local function enqueue_timer_event(event_factory)
+        scheduler.enqueue(function()
+            if session.finished then
+                return
+            end
+            if not vim.api.nvim_buf_is_valid(session.buf) then
+                dispatch({ type = "invalid" })
+                return
+            end
+            dispatch(event_factory())
+        end)
+    end
+
+    local function schedule_after(name, delay_ms, event_factory)
+        cancel_timer(name)
+        session.timers[name] = scheduler.after(delay_ms, function()
+            enqueue_timer_event(event_factory)
+        end)
+    end
+
+    local function start_frame_timer()
+        if session.timers.frame then
+            return
+        end
+        session.timers.frame = scheduler.every(120, function()
+            scheduler.enqueue(function()
+                if session.finished then
+                    return
+                end
+                if not vim.api.nvim_buf_is_valid(session.buf) then
+                    dispatch({ type = "invalid" })
+                    return
+                end
+                local ok, valid = pcall(session.lease_valid)
+                if not ok or not valid then
+                    dispatch({ type = "stale" })
+                    return
+                end
+                if session.playful_verb then
+                    session.frame_index = session.frame_index % #spinner + 1
+                    render_playful()
+                end
+            end)
+        end)
+    end
+
+    local function reset_idle_timer()
+        schedule_after("idle", 15000, function()
+            return {
+                type = "idle",
+                now_ms = now_ms(),
+                verb_index = session.choose_verb_index(#verbs),
+            }
+        end)
+    end
+
+    local function rearm_early_timer(event, state)
+        local deadline
+        local name
+        local event_factory
+        if event.type == "reveal_due" and state.phase == "waiting" then
+            deadline = state.reveal_at
+            name = "reveal"
+            event_factory = function()
+                return { type = "reveal_due", now_ms = now_ms() }
+            end
+        elseif event.type == "minimum_due" and state.phase == "showing" then
+            deadline = state.minimum_at
+            name = "minimum"
+            event_factory = function()
+                return { type = "minimum_due", now_ms = now_ms() }
+            end
+        elseif event.type == "idle"
+                and (state.phase == "waiting" or state.phase == "showing") then
+            deadline = state.verb_due_at
+            name = "idle"
+            event_factory = function()
+                return {
+                    type = "idle",
+                    now_ms = now_ms(),
+                    verb_index = session.choose_verb_index(#verbs),
+                }
+            end
+        end
+        if deadline and event.now_ms < deadline then
+            schedule_after(name, math.max(1, math.ceil(deadline - event.now_ms)), event_factory)
+            return true
+        end
+        return false
+    end
+
+    local function apply_actions(actions, context)
+        for _, action in ipairs(actions) do
+            if action.type == "show_playful" then
+                session.playful_verb = action.verb
+                if not render_playful() then
+                    finish()
+                    return
+                end
+                start_frame_timer()
+            elseif action.type == "render_status" then
+                session.playful_verb = nil
+                cancel_timer("frame")
+                if not render(action.message) then
+                    finish()
+                    return
+                end
+            elseif action.type == "emit_content" then
+                call_safely("content emitter", session.emit_content, action.qid, action.chunk)
+            elseif action.type == "hide" then
+                hide()
+            elseif action.type == "continue_completion" then
+                hide()
+                call_safely("completion", action.completion)
+            elseif action.type == "surface_failure" then
+                hide()
+                call_safely("failure surface", context and context.surface_failure, action.error)
+            end
+        end
+    end
+
+    dispatch = function(event, context)
+        if session.finished then
+            return
+        end
+        if event.type ~= "cancel" and event.type ~= "invalid" then
+            local ok, valid = pcall(session.lease_valid)
+            if not ok or not valid then
+                event = { type = "stale" }
+            end
+        end
+        local previous_phase = session.state.phase
+        local next_state, actions = presentation.transition(session.state, event)
+        session.state = next_state
+        if next_state.phase == "finished" then
+            -- Release registry/timer ownership before a continuation starts a
+            -- recursive LLM leg in this buffer.
+            finish()
+            if event.type == "cancel" or event.type == "stale" or event.type == "invalid" then
+                call_safely("discard terminal", session.on_discard, event.type, event.reason)
+            end
+            apply_actions(actions, context)
+            return
+        end
+        apply_actions(actions, context)
+
+        if session.finished then
+            return
+        end
+        if rearm_early_timer(event, next_state) then
+            return
+        end
+        if previous_phase == "waiting" and next_state.phase ~= "waiting" then
+            cancel_timer("reveal")
+            if next_state.phase == "released" then
+                cancel_timer("idle")
+            end
+        end
+        if next_state.phase == "showing" and previous_phase ~= "showing" then
+            schedule_after("minimum", 1000, function()
+                return { type = "minimum_due", now_ms = now_ms() }
+            end)
+        end
+        if previous_phase == "showing" and next_state.phase ~= "showing" then
+            cancel_timer("minimum")
+            cancel_timer("frame")
+            cancel_timer("idle")
+        elseif (event.type == "activity" or event.type == "idle")
+                and (next_state.phase == "waiting" or next_state.phase == "showing") then
+            reset_idle_timer()
+        end
+    end
+
+    local function submit(event_factory, context)
+        scheduler.enqueue(function()
+            if session.finished then
+                return
+            end
+            if not vim.api.nvim_buf_is_valid(session.buf) then
+                dispatch({ type = "invalid" })
+                return
+            end
+            dispatch(event_factory(), context)
+        end)
+    end
+
+    session.activity = function(_self, _qid)
+        submit(function()
+            return {
+                type = "activity",
+                now_ms = now_ms(),
+                verb_index = session.choose_verb_index(#verbs),
+            }
+        end)
+    end
+
+    session.content = function(_self, qid, chunk)
+        submit(function()
+            return { type = "content", now_ms = now_ms(), qid = qid, chunk = chunk }
+        end)
+    end
+
+    session.progress = function(_self, _qid, event)
+        submit(function()
+            if type(event) ~= "table" then
+                event = { message = tostring(event or "") }
+            end
+            local message
+            session.detail_state, message = presentation.progress_message(session.detail_state, event)
+            return { type = "progress", now_ms = now_ms(), message = message }
+        end)
+    end
+
+    session.complete = function(_self, _qid, continuation)
+        submit(function()
+            return { type = "complete", now_ms = now_ms(), completion = continuation }
+        end)
+    end
+
+    session.failure = function(_self, _qid, err, surface_failure)
+        submit(function()
+            return {
+                type = "failure",
+                error = err,
+                owns_transcript = type(surface_failure) == "function",
+            }
+        end, { surface_failure = surface_failure })
+    end
+
+    session.cancel = function(_self, reason)
+        submit(function() return { type = "cancel", reason = reason } end)
+    end
+
+    active_by_buf[buf] = session
+    local enqueued, enqueue_error = pcall(scheduler.enqueue, function()
+        if session.finished then
+            return
+        end
+        if not vim.api.nvim_buf_is_valid(session.buf) then
+            dispatch({ type = "invalid" })
+            return
+        end
+        schedule_after("reveal", 1000, function()
+            return { type = "reveal_due", now_ms = now_ms() }
+        end)
+        reset_idle_timer()
+    end)
+    if not enqueued then
+        finish()
+        error(enqueue_error, 0)
+    end
+
+    return session
+end
+
+-- Cancel every registered chat session before global task termination.
+M.cancel_all = function(reason)
+    local sessions = {}
+    for _, session in pairs(active_by_buf) do
+        table.insert(sessions, session)
+    end
+    for _, session in ipairs(sessions) do
+        session:cancel(reason)
+    end
+end
+
+-- Report only a fully constructed session that still owns this buffer.
+M.is_active = function(buf)
+    local session = active_by_buf[buf]
+    return session ~= nil and not session.finished
+end
+
+return M
diff --git a/lua/parley/chat_presentation.lua b/lua/parley/chat_presentation.lua
new file mode 100644
index 0000000..1556ea4
--- /dev/null
+++ b/lua/parley/chat_presentation.lua
@@ -0,0 +1,286 @@
+-- Pure presentation state for one chat-producing LLM leg.
+local M = {}
+
+local REVEAL_DELAY_MS = 1000
+local MINIMUM_VISIBLE_MS = 1000
+local VERB_IDLE_MS = 15000
+local TIMED_EVENTS = {
+    reveal_due = true,
+    minimum_due = true,
+    activity = true,
+    idle = true,
+    content = true,
+    progress = true,
+    complete = true,
+}
+
+local function copy_array(values)
+    local copied = {}
+    for index, value in ipairs(values or {}) do
+        copied[index] = value
+    end
+    return copied
+end
+
+local function copy_state(state)
+    local copied = {}
+    for key, value in pairs(state) do
+        copied[key] = value
+    end
+    return copied
+end
+
+local function content_action(event)
+    return {
+        type = "emit_content",
+        qid = event.qid,
+        chunk = event.chunk,
+    }
+end
+
+local function progress_action(event)
+    return {
+        type = "render_status",
+        message = event.message,
+    }
+end
+
+local function visible_action(event)
+    if event.type == "content" then
+        return content_action(event)
+    end
+    return progress_action(event)
+end
+
+local function staged_event(event)
+    if event.type == "content" then
+        return {
+            type = "content",
+            qid = event.qid,
+            chunk = event.chunk,
+        }
+    end
+    return {
+        type = "progress",
+        message = event.message,
+    }
+end
+
+local function append_staged_actions(actions, staged_tail, staged_count)
+    local first_action = #actions
+    local node = staged_tail
+    for index = staged_count, 1, -1 do
+        actions[first_action + index] = visible_action(node.event)
+        node = node.previous
+    end
+end
+
+local function continuation_action(completion)
+    return {
+        type = "continue_completion",
+        completion = completion,
+    }
+end
+
+local function finish(state)
+    local finished = copy_state(state)
+    finished.phase = "finished"
+    finished.staged_tail = nil
+    finished.staged_count = 0
+    finished.completion_pending = nil
+    finished.pending_completion = nil
+    return finished
+end
+
+local function release_visible(state, event)
+    local released = copy_state(state)
+    released.phase = "released"
+    released.staged_tail = nil
+    released.staged_count = 0
+    local actions = { { type = "hide" } }
+    append_staged_actions(actions, state.staged_tail, state.staged_count)
+    actions[#actions + 1] = visible_action(event)
+    return released, actions
+end
+
+local function rotate_verb(state, event, now_ms)
+    local rotated = copy_state(state)
+    local verb_count = #rotated.verbs
+    local requested = tonumber(event.verb_index) or (rotated.verb_index + 1)
+    requested = ((requested - 1) % verb_count) + 1
+    if verb_count > 1 and requested == rotated.verb_index then
+        requested = (requested % verb_count) + 1
+    end
+    rotated.verb_index = requested
+    rotated.verb = rotated.verbs[requested]
+    rotated.last_activity_at = now_ms
+    rotated.verb_due_at = now_ms + VERB_IDLE_MS
+    return rotated, { { type = "show_playful", verb = rotated.verb } }
+end
+
+local function flush_showing(state, completion, completion_pending)
+    local actions = { { type = "hide" } }
+    append_staged_actions(actions, state.staged_tail, state.staged_count)
+    if completion_pending then
+        actions[#actions + 1] = continuation_action(completion)
+        return finish(state), actions
+    end
+    local released = copy_state(state)
+    released.phase = "released"
+    released.staged_tail = nil
+    released.staged_count = 0
+    return released, actions
+end
+
+-- Construct deterministic presentation state without reading a clock or RNG.
+M.initial = function(opts)
+    opts = opts or {}
+    local now_ms = assert(opts.now_ms, "now_ms is required")
+    local verbs = copy_array(assert(opts.verbs, "verbs are required"))
+    assert(#verbs > 0, "at least one verb is required")
+    local verb_index = assert(opts.verb_index, "verb_index is required")
+    assert(verbs[verb_index], "verb_index must identify an injected verb")
+
+    return {
+        phase = "waiting",
+        verbs = verbs,
+        verb_index = verb_index,
+        verb = verbs[verb_index],
+        reveal_at = now_ms + REVEAL_DELAY_MS,
+        minimum_at = now_ms + REVEAL_DELAY_MS + MINIMUM_VISIBLE_MS,
+        verb_due_at = now_ms + VERB_IDLE_MS,
+        last_activity_at = now_ms,
+        staged_count = 0,
+    }
+end
+
+-- Reduce one serialized callback into immutable state and ordered UI actions.
+M.transition = function(state, event)
+    if state.phase == "finished" then
+        return state, {}
+    end
+
+    local event_type = event.type
+    if TIMED_EVENTS[event_type] then
+        assert(type(event.now_ms) == "number", event_type .. " event requires now_ms")
+    end
+    local now_ms = event.now_ms
+
+    if event_type == "cancel" or event_type == "stale" or event_type == "invalid" then
+        local actions = state.phase == "showing" and { { type = "hide" } } or {}
+        return finish(state), actions
+    end
+
+    if event_type == "failure" then
+        local actions = state.phase == "showing" and { { type = "hide" } } or {}
+        if event.owns_transcript then
+            append_staged_actions(actions, state.staged_tail, state.staged_count)
+            actions[#actions + 1] = { type = "surface_failure", error = event.error }
+        end
+        return finish(state), actions
+    end
+
+    if state.phase == "waiting" then
+        if event_type == "content" or event_type == "progress" then
+            local released = copy_state(state)
+            released.phase = "released"
+            return released, { visible_action(event) }
+        end
+        if event_type == "reveal_due" and now_ms >= state.reveal_at then
+            local showing = copy_state(state)
+            showing.phase = "showing"
+            showing.minimum_at = now_ms + MINIMUM_VISIBLE_MS
+            return showing, { { type = "show_playful", verb = showing.verb } }
+        end
+        if event_type == "activity" then
+            local active = copy_state(state)
+            active.last_activity_at = now_ms
+            active.verb_due_at = now_ms + VERB_IDLE_MS
+            return active, {}
+        end
+        if event_type == "complete" then
+            return finish(state), { continuation_action(event.completion) }
+        end
+        return state, {}
+    end
+
+    if state.phase == "released" then
+        if event_type == "content" or event_type == "progress" then
+            return state, { visible_action(event) }
+        end
+        if event_type == "complete" then
+            return finish(state), { continuation_action(event.completion) }
+        end
+        return state, {}
+    end
+
+    if event_type == "activity" then
+        return rotate_verb(state, event, now_ms)
+    end
+    if event_type == "idle" and now_ms >= state.verb_due_at then
+        return rotate_verb(state, event, now_ms)
+    end
+    if event_type == "content" or event_type == "progress" then
+        if now_ms >= state.minimum_at then
+            return release_visible(state, event)
+        end
+        local staged = copy_state(state)
+        staged.staged_tail = {
+            event = staged_event(event),
+            previous = state.staged_tail,
+        }
+        staged.staged_count = state.staged_count + 1
+        return staged, {}
+    end
+    if event_type == "complete" then
+        if now_ms >= state.minimum_at then
+            return flush_showing(state, event.completion, true)
+        end
+        local deferred = copy_state(state)
+        deferred.completion_pending = true
+        deferred.pending_completion = event.completion
+        return deferred, {}
+    end
+    if event_type == "minimum_due" and now_ms >= state.minimum_at then
+        if state.completion_pending then
+            return flush_showing(state, state.pending_completion, true)
+        end
+        if state.staged_count > 0 then
+            return flush_showing(state)
+        end
+    end
+
+    return state, {}
+end
+
+-- Accumulate one provider detail stream and derive its meaningful status text.
+M.progress_message = function(detail_state, event)
+    local detail = event.text
+    if type(detail) ~= "string" or detail == "" then
+        return {}, event.message
+    end
+
+    local detail_key = table.concat({
+        tostring(event.phase or ""),
+        tostring(event.kind or ""),
+        tostring(event.tool or ""),
+        tostring(event.block_type or ""),
+    }, ":")
+    local accumulated = detail
+    if detail_state.key == detail_key then
+        accumulated = (detail_state.text or "") .. detail
+    end
+
+    local next_state = { key = detail_key, text = accumulated }
+    local compact = accumulated:gsub("%s+", " "):gsub("^%s+", "")
+    if compact == "" then
+        return next_state, event.message
+    end
+    if event.kind == "reasoning" then
+        return next_state, "Reasoning: " .. compact
+    end
+    local base = type(event.message) == "string" and event.message ~= "" and event.message or "Working..."
+    return next_state, base .. " " .. compact
+end
+
+return M
diff --git a/lua/parley/chat_respond.lua b/lua/parley/chat_respond.lua
index 4fd27cb..fff0ef0 100644
--- a/lua/parley/chat_respond.lua
+++ b/lua/parley/chat_respond.lua
@@ -340,6 +340,7 @@ M.cmd_stop = function(signal)
         original_free_cursor_value = nil
     end

+    require("parley.chat_pending").cancel_all("user")
     _parley.tasker.stop(signal)

     -- After stopping, repair any unmatched 🔧: blocks in the buffer.
@@ -1147,7 +1148,12 @@ M.respond = function(params, callback, override_free_cursor, force, live_model,

     -- Check if there's already an active process for this buffer
     if not force and _parley.tasker.is_busy(buf, false) then
-        _parley.logger.warning("A Parley process is already running. Use stop to cancel or force to override.")
+        _parley.logger.warning("A Parley process is already running. Stop it before resubmitting.")
+        return
+    end
+    local chat_pending = require("parley.chat_pending")
+    if type(chat_pending.is_active) == "function" and chat_pending.is_active(buf) then
+        _parley.logger.warning("A Parley response is already pending in this chat. Stop it before resubmitting.")
         return
     end

@@ -1445,39 +1451,17 @@ M.respond = function(params, callback, override_free_cursor, force, live_model,
             target_idx = exchange_idx or #model.exchanges
         end

-        local spinner_frames = require("parley.progress").SPINNER -- single source (#133)
-        local spinner_message = "Submitting..."
-        local progress_detail_text = ""
-        local progress_detail_key = nil
-        local spinner_frame_index = 1
-        local spinner_timer = nil
-        local stop_spinner
-        -- Spinner shows on every API call to Claude (initial and recursive).
-        local spinner_active = _parley._state.web_search and true or false
-        local spinner_running = false
-        local initial_progress_text = ""
-        if spinner_active then
-            initial_progress_text = "🔎 " .. spinner_frames[spinner_frame_index] .. " " .. spinner_message
-        end
-
         -- Compute response_start_line using the model.
         --
         -- Every visible element is a block in the model. The model
         -- handles margins between non-empty blocks automatically.
         -- We just add blocks and ask for positions.
         --
-        -- spinner_block_idx / stream_block_idx: indices into
-        -- model.exchanges[target_idx].blocks for the spinner and
-        -- streaming blocks. Used by clear_progress_indicator and
-        -- on_lines_changed respectively.
         -- Every visible element is a block in the model. The model
         -- handles margins between non-empty blocks automatically.
         -- We add blocks to the model, then insert the corresponding
         -- lines (margin + content) into the buffer.
         --
-        -- spinner_block_idx / stream_block_idx: block indices used by
-        -- clear_progress_indicator and on_lines_changed.
-        local spinner_block_idx
         local stream_block_idx
         if is_recursion then
             -- Recursion: append streaming placeholder after existing blocks.
@@ -1486,19 +1470,10 @@ M.respond = function(params, callback, override_free_cursor, force, live_model,
             local pos = model:block_start(target_idx, stream_block_idx)
             buffer_edit.insert_lines_at(buf, pos - 1, { "", "" })  -- margin + blank content
         else
-            -- Fresh answer: add agent_header + optional spinner + streaming placeholder.
+            -- Fresh answer: add agent_header + streaming placeholder. Pending
+            -- presentation is an extmark and never enters the exchange model.
             model:add_block(target_idx, "agent_header", 1)
             model:add_block(target_idx, "stream_placeholder", 1)
-            if spinner_active then
-                -- Insert spinner between agent_header and stream_placeholder.
-                -- We added stream_placeholder already, so spinner goes before it.
-                -- Actually, let's just add blocks in order. Remove stream_placeholder,
-                -- add spinner, then re-add stream_placeholder.
-                model:remove_block(target_idx, #model.exchanges[target_idx].blocks)
-                model:add_block(target_idx, "spinner", 1)
-                spinner_block_idx = #model.exchanges[target_idx].blocks
-                model:add_block(target_idx, "stream_placeholder", 1)
-            end
             stream_block_idx = #model.exchanges[target_idx].blocks

             -- Before inserting, clean up any trailing blank lines after
@@ -1531,10 +1506,6 @@ M.respond = function(params, callback, override_free_cursor, force, live_model,
                 end
             end
             local insert_lines = { "", agent_prefix .. agent_suffix }
-            if spinner_active then
-                table.insert(insert_lines, "")  -- margin before spinner
-                table.insert(insert_lines, initial_progress_text)
-            end
             table.insert(insert_lines, "")  -- margin before stream_placeholder
             table.insert(insert_lines, "")  -- stream_placeholder content (blank)
             buffer_edit.insert_lines_at(buf, insert_start, insert_lines)
@@ -1542,8 +1513,7 @@ M.respond = function(params, callback, override_free_cursor, force, live_model,

         -- #138: anchor the lease on the agent-header (`🤖:`) line — block 2 of the
         -- exchange (block 1 is the question; same index in fresh + recursion paths). It's the
-        -- structural marker for the response: streaming, the spinner, and
-        -- progress-clear all operate on the blocks *below* it, so ordinary writes
+        -- structural marker for the response: streaming operates below it, so ordinary writes
         -- leave it untouched, while undo/redo of the inserted response (or the
         -- user deleting the `🤖:` line) removes it and invalidates the lease.
         -- Anchoring on the stream line itself fails: stream_replace_at_line
@@ -1566,14 +1536,15 @@ M.respond = function(params, callback, override_free_cursor, force, live_model,
             require("parley.buffer_lifecycle").finalize_mutated_api_leg(buf, api_leg_mutated)
         end
         local lease_notice_sent = false
+        local pending_session
         local function invalidate_pending_request(lease_reason)
             if not lease_notice_sent then
                 lease_notice_sent = true
                 _parley.logger.warning(lease_reason or "Parley request cancelled because the chat transcript changed")
                 vim.notify(lease_reason or "Parley request cancelled because the chat transcript changed", vim.log.levels.WARN)
             end
-            if stop_spinner then
-                stop_spinner()
+            if pending_session then
+                pending_session:cancel("stale")
             end
             pcall(function()
                 _parley.tasker.stop()
@@ -1623,155 +1594,20 @@ M.respond = function(params, callback, override_free_cursor, force, live_model,
         -- correct because any prior inserts (fence, etc.) updated the
         -- model via grow_question.
         local response_start_line = model:block_start(target_idx, stream_block_idx)
-        local function set_progress_indicator_line(text)
-            if not spinner_active or not spinner_block_idx then
-                return
-            end
-            if vim.in_fast_event() then
-                vim.schedule(function()
-                    set_progress_indicator_line(text)
-                end)
-                return
-            end
-            if not vim.api.nvim_buf_is_valid(buf) then
-                return
-            end
-            if not lease_valid() then
-                return
-            end
-            -- Recompute position from the model (streaming may have
-            -- shifted it via grow_block).
-            local pos = model:block_start(target_idx, spinner_block_idx)
-            local existing = vim.api.nvim_buf_get_lines(buf, pos, pos + 1, false)[1]
-            if existing == nil then
-                return
-            end
-            -- Issue #80: join each spinner frame to the previous undo
-            -- block so 90ms-cadence updates don't pile up as separate
-            -- entries. Same pattern dispatcher.create_handler uses for
-            -- streaming chunks. helpers.undojoin swallows E790.
-            require("parley.helper").undojoin(buf)
-            require("parley.buffer_edit").replace_line_at(buf, pos, text)
-            lease_commit()
-        end
-
-        local function render_spinner_line()
-            if not spinner_active then
-                return
-            end
-            if vim.in_fast_event() then
-                vim.schedule(render_spinner_line)
-                return
-            end
-            local text = "🔎 " .. spinner_frames[spinner_frame_index] .. " " .. spinner_message
-            set_progress_indicator_line(text)
-        end
-
-        stop_spinner = function()
-            if not spinner_running then
-                return
-            end
-            spinner_running = false
-            stop_and_close_timer(spinner_timer)
-            spinner_timer = nil
-        end
-
-        local function clear_progress_indicator(qt)
-            if not spinner_active then
-                return
-            end
-            if vim.in_fast_event() then
-                vim.schedule(function()
-                    clear_progress_indicator(qt)
-                end)
-                return
-            end
-            stop_spinner()
-            spinner_active = false
-            if vim.api.nvim_buf_is_valid(buf) and spinner_block_idx then
-                if not lease_valid() then
-                    return
-                end
-                -- Delete the spinner block + its margin from the buffer.
-                local spin_start = model:block_start(target_idx, spinner_block_idx)
-                local spin_size = model.exchanges[target_idx].blocks[spinner_block_idx].size
-                -- Delete: margin (1 line before content) + content lines.
-                local delete_start = spin_start - 1
-                local delete_count = 1 + spin_size
-                -- Issue #80: join the cleanup delete to the prior undo
-                -- block so the entire response cycle (spinner frames +
-                -- streaming + cleanup) collapses to one undoable unit.
-                require("parley.helper").undojoin(buf)
-                buffer_edit.delete_lines_after(buf, delete_start, delete_count)
-                -- Set size to 0 — model treats it as invisible (rule 3).
-                model:set_block_size(target_idx, spinner_block_idx, 0)
-                spinner_block_idx = nil
-                -- Update qt line tracking.
-                if qt then
-                    if type(qt.first_line) == "number" and qt.first_line >= delete_start then
-                        qt.first_line = qt.first_line - delete_count
-                    end
-                    if type(qt.last_line) == "number" and qt.last_line >= delete_start then
-                        qt.last_line = qt.last_line - delete_count
-                    end
-                end
-            end
-            lease_commit()
-        end
-
-        local function start_spinner()
-            if not spinner_active then
-                return
-            end
-            spinner_running = true
-            render_spinner_line()
-            spinner_timer = vim.loop.new_timer()
-            spinner_timer:start(
-                90,
-                90,
-                vim.schedule_wrap(function()
-                    if not spinner_running then
-                        return
-                    end
-                    spinner_frame_index = spinner_frame_index + 1
-                    if spinner_frame_index > #spinner_frames then
-                        spinner_frame_index = 1
-                    end
-                    render_spinner_line()
-                end)
-            )
-        end
-
-        start_spinner()
-
         local function on_stream_lines_changed(delta)
             model:grow_block(target_idx, stream_block_idx, delta)
         end
         local base_handler = _parley.dispatcher.create_handler(buf, win, response_start_line, true, "", function()
             return is_follow_cursor_enabled(override_free_cursor)
         end, on_stream_lines_changed, {
-            before_write = function(_qid, chunk)
-                if type(chunk) == "string" and chunk ~= "" then
-                    stop_spinner()
-                end
+            before_write = function(_qid, _chunk)
                 return lease_valid()
             end,
             after_write = function()
                 lease_commit()
             end,
         })
-        local function request_clear_progress_indicator(qt)
-            if vim.in_fast_event() then
-                vim.schedule(function()
-                    clear_progress_indicator(qt)
-                end)
-                return
-            end
-            clear_progress_indicator(qt)
-        end
-        local response_handler = function(qid, chunk)
-            base_handler(qid, chunk)
-        end
+        local response_handler = function(qid, chunk) pending_session:content(qid, chunk) end

         -- Shared empty-answer collapse (#131): used by on_exit (tool-use-only /
         -- empty response) AND on_abort, so a failed managed-cliproxy start tears
@@ -1799,312 +1635,327 @@ M.respond = function(params, callback, override_free_cursor, force, live_model,
             end
         end

+        local leg_teardown_done = false
+        local discard_notice
+        local function teardown_chat_leg(notice)
+            if leg_teardown_done then return end
+            leg_teardown_done = true
+            local owns_shell = false
+            if vim.api.nvim_buf_is_valid(buf) then
+                owns_shell = chat_lease.validate(buf, lease_generation, buf_changedtick(buf)) == true
+            end
+            if owns_shell then collapse_empty_answer() end
+            finalize_mutated_api_leg()
+            chat_lease.clear(buf, lease_generation)
+            if notice then vim.notify(notice, vim.log.levels.WARN) end
+        end
+
         -- Abort teardown (#131): the dispatcher invokes this (qid-free) when the
-        -- managed cliproxy can't be started, so the request fails fast — spinner
-        -- stopped, empty answer block collapsed, error surfaced — never hangs.
+        -- managed cliproxy can't be started, so the request fails fast and the
+        -- response shell is torn down exactly once.
         local function on_abort(msg)
-            vim.schedule(function()
-                clear_progress_indicator(nil)
-                collapse_empty_answer()
-                finalize_mutated_api_leg()
-                chat_lease.clear(buf, lease_generation)
-                vim.notify(msg or "parley: request aborted", vim.log.levels.WARN)
-            end)
+            discard_notice = msg or "parley: request aborted"
+            pending_session:cancel("abort")
         end

+        pending_session = chat_pending.start({
+            buf = buf,
+            anchor_line = model:block_start(target_idx, 2),
+            lease_valid = lease_valid,
+            emit_content = base_handler,
+            choose_verb_index = function(count) return math.random(count) end,
+            on_discard = function()
+                teardown_chat_leg(discard_notice)
+            end,
+        })
+
         -- call the model and write response
         _parley.dispatcher.query(
             buf,
             agent_info.provider,
             final_payload,
             response_handler,
-            vim.schedule_wrap(function(qid)
+            function(qid)
                 local qt = _parley.tasker.get_query(qid)
                 if not qt then
-                    finalize_mutated_api_leg()
-                    return
-                end
-                if not lease_valid() then
-                    finalize_mutated_api_leg()
-                    chat_lease.clear(buf, lease_generation)
+                    pending_session:complete(qid, function()
+                        vim.schedule(function()
+                            finalize_mutated_api_leg()
+                            chat_lease.clear(buf, lease_generation)
+                        end)
+                    end)
                     return
                 end
-                request_clear_progress_indicator(qt)
-
-                -- Collapse the empty stream placeholder (tool-use-only or empty
-                -- response). Shared with the #131 abort path.
-                collapse_empty_answer()
-
-                -- Tool loop hook: if the streamed response contained
-                -- tool_use blocks, write 🔧:/📎: into the buffer and
-                -- re-submit. Finalization only runs on "done".
-                if agent_info and agent_info.tools and #agent_info.tools > 0 then
-                    local tool_loop = require("parley.tool_loop")
+                local function continue_completion()
                     if not lease_valid() then
                         finalize_mutated_api_leg()
                         chat_lease.clear(buf, lease_generation)
                         return
                     end
-                    local outcome = tool_loop.process_response(buf, qt.raw_response or "", {
-                        max_tool_iterations = agent_info.max_tool_iterations or require("parley.defaults").max_tool_iterations,
-                        tool_result_max_bytes = agent_info.tool_result_max_bytes or 102400,
-                        root_policy = agent_info.root_policy,
-                    }, model, target_idx)
-                    lease_commit()
-                    if outcome == "recurse" then
-                        finalize_mutated_api_leg()
-                        -- Re-parse the (now updated) buffer and submit
-                        -- again. force=true bypasses the is_busy check
-                        -- that would otherwise reject an immediate
-                        -- re-submit. The recursive respond() inherits
-                        -- the same callback so user-provided
-                        -- callbacks still fire on the final iteration.
-                        vim.schedule(function()
-                            if not lease_valid() then
-                                finalize_mutated_api_leg()
-                                chat_lease.clear(buf, lease_generation)
-                                return
-                            end
-                            M.respond({ root_policy = agent_info.root_policy }, callback,
-                                override_free_cursor, true, model, target_idx)
-                        end)
-                        return
+                    -- Collapse the empty stream placeholder (tool-use-only or empty
+                    -- response). Shared with the #131 abort path.
+                    collapse_empty_answer()
+
+                    -- Tool loop hook: if the streamed response contained
+                    -- tool_use blocks, write 🔧:/📎: into the buffer and
+                    -- re-submit. Finalization only runs on "done".
+                    if agent_info and agent_info.tools and #agent_info.tools > 0 then
+                        local tool_loop = require("parley.tool_loop")
+                        if not lease_valid() then
+                            finalize_mutated_api_leg()
+                            chat_lease.clear(buf, lease_generation)
+                            return
+                        end
+                        local outcome = tool_loop.process_response(buf, qt.raw_response or "", {
+                            max_tool_iterations = agent_info.max_tool_iterations or require("parley.defaults").max_tool_iterations,
+                            tool_result_max_bytes = agent_info.tool_result_max_bytes or 102400,
+                            root_policy = agent_info.root_policy,
+                        }, model, target_idx)
+                        lease_commit()
+                        if outcome == "recurse" then
+                            finalize_mutated_api_leg()
+                            -- Re-parse the (now updated) buffer and submit
+                            -- again. force=true bypasses the is_busy check
+                            -- that would otherwise reject an immediate
+                            -- re-submit. The recursive respond() inherits
+                            -- the same callback so user-provided
+                            -- callbacks still fire on the final iteration.
+                            vim.schedule(function()
+                                if not lease_valid() then
+                                    finalize_mutated_api_leg()
+                                    chat_lease.clear(buf, lease_generation)
+                                    return
+                                end
+                                M.respond({ root_policy = agent_info.root_policy }, callback,
+                                    override_free_cursor, true, model, target_idx)
+                            end)
+                            return
+                        end
                     end
-                end

-                local streamed_cursor_line = query_cursor_line(qt)
-
-                -- Clean up trailing blanks after the current exchange.
-                -- The model tracks content sizes precisely, but streaming
-                -- may leave stray blank lines in the buffer. Delete
-                -- everything between the exchange's model-computed end
-                -- and the next exchange (or end of buffer).
-                local exchange_end = model:exchange_start(target_idx) + model:exchange_total_size(target_idx)
-                local line_count = vim.api.nvim_buf_line_count(buf)
-                -- Find where the next content starts (next 💬: or end of buffer).
-                local next_content_start = line_count  -- default: end of buffer
-                local all_current_lines = vim.api.nvim_buf_get_lines(buf, 0, line_count, false)
-                local footnote_boundary = trailing_footnote_boundary(all_current_lines, exchange_end)
-                if footnote_boundary then
-                    next_content_start = footnote_boundary
-                elseif exchange_idx and exchange_idx < #parsed_chat.exchanges then
-                    -- There's a next exchange — find where it starts in the
-                    -- current buffer. Re-read to account for streaming mutations.
-                    local cur_lines = vim.api.nvim_buf_get_lines(buf, exchange_end, line_count, false)
-                    for i, l in ipairs(cur_lines) do
-                        if l:match("%S") then
-                            next_content_start = exchange_end + i - 1
-                            break
+                    local streamed_cursor_line = query_cursor_line(qt)
+
+                    -- Clean up trailing blanks after the current exchange.
+                    -- The model tracks content sizes precisely, but streaming
+                    -- may leave stray blank lines in the buffer. Delete
+                    -- everything between the exchange's model-computed end
+                    -- and the next exchange (or end of buffer).
+                    local exchange_end = model:exchange_start(target_idx) + model:exchange_total_size(target_idx)
+                    local line_count = vim.api.nvim_buf_line_count(buf)
+                    -- Find where the next content starts (next 💬: or end of buffer).
+                    local next_content_start = line_count  -- default: end of buffer
+                    local all_current_lines = vim.api.nvim_buf_get_lines(buf, 0, line_count, false)
+                    local footnote_boundary = trailing_footnote_boundary(all_current_lines, exchange_end)
+                    if footnote_boundary then
+                        next_content_start = footnote_boundary
+                    elseif exchange_idx and exchange_idx < #parsed_chat.exchanges then
+                        -- There's a next exchange — find where it starts in the
+                        -- current buffer. Re-read to account for streaming mutations.
+                        local cur_lines = vim.api.nvim_buf_get_lines(buf, exchange_end, line_count, false)
+                        for i, l in ipairs(cur_lines) do
+                            if l:match("%S") then
+                                next_content_start = exchange_end + i - 1
+                                break
+                            end
                         end
                     end
-                end
-                -- Delete excess blanks: keep exactly 1 margin line between
-                -- current exchange end and next content.
-                local excess = next_content_start - exchange_end - 1  -- -1 for the 1 margin we keep
-                if excess > 0 then
-                    if not guarded_write(function()
-                        _parley.helpers.undojoin(buf)
-                        buffer_edit.delete_lines_after(buf, exchange_end + 1, excess)
-                    end) then
-                        finalize_mutated_api_leg()
-                        chat_lease.clear(buf, lease_generation)
-                        return
+                    -- Delete excess blanks: keep exactly 1 margin line between
+                    -- current exchange end and next content.
+                    local excess = next_content_start - exchange_end - 1  -- -1 for the 1 margin we keep
+                    if excess > 0 then
+                        if not guarded_write(function()
+                            _parley.helpers.undojoin(buf)
+                            buffer_edit.delete_lines_after(buf, exchange_end + 1, excess)
+                        end) then
+                            finalize_mutated_api_leg()
+                            chat_lease.clear(buf, lease_generation)
+                            return
+                        end
                     end
-                end

-                -- Only add a new user prompt at the end if we're not in the middle of the document
-                _parley.logger.debug("exchange_idx: " .. tostring(exchange_idx) .. " and #parsed_chat: " .. tostring(#parsed_chat))
+                    -- Only add a new user prompt at the end if we're not in the middle of the document
+                    _parley.logger.debug("exchange_idx: " .. tostring(exchange_idx) .. " and #parsed_chat: " .. tostring(#parsed_chat))

-                if exchange_idx == #parsed_chat.exchanges then
-                    -- Insert position is right after the cleaned-up exchange.
-                    local insert_at = exchange_end
-
-                    if not guarded_write(function()
-                        _parley.helpers.undojoin(buf)
-                        -- Insert: margin + user_prefix + trailing blank
-                        buffer_edit.insert_lines_at(buf, insert_at, { "", _parley.config.chat_user_prefix, "" })
-                        _parley.helpers.undojoin(buf)
-                        buffer_edit.append_blank_at_end(buf)
-                    end) then
-                        finalize_mutated_api_leg()
-                        chat_lease.clear(buf, lease_generation)
-                        return
-                    end
-                end
+                    if exchange_idx == #parsed_chat.exchanges then
+                        -- Insert position is right after the cleaned-up exchange.
+                        local insert_at = exchange_end

-                -- if topic is ?, then generate it
-                local topic_generation_started = false
-                if headers.topic == "?" then
-                    if not lease_valid() then
-                        finalize_mutated_api_leg()
-                        chat_lease.clear(buf, lease_generation)
-                        return
-                    end
-                    topic_generation_started = true
-                    -- Topic gen: drop the leading system-prompt messages (1, or 2
-                    -- for a synthetic system prompt) AND ancestors — keep only the
-                    -- current-file conversation. Carrying the system prompt makes
-                    -- the model obey its 🧠:/persona mandate and open with a
-                    -- thinking block, which would otherwise become the "topic".
-                    local sys_lead = #require("parley.system_prompt_msgs").build(agent_info)
-                    local topic_msgs = M._conversation_after_lead(messages, sys_lead + ancestor_msg_count)
-                    table.insert(topic_msgs, { role = "assistant", content = qt.response })
-
-                    M.generate_topic(topic_msgs, agent_info.provider, agent_info.model, function(topic, _reason)
-                        if not topic then
+                        if not guarded_write(function()
+                            _parley.helpers.undojoin(buf)
+                            -- Insert: margin + user_prefix + trailing blank
+                            buffer_edit.insert_lines_at(buf, insert_at, { "", _parley.config.chat_user_prefix, "" })
+                            _parley.helpers.undojoin(buf)
+                            buffer_edit.append_blank_at_end(buf)
+                        end) then
                             finalize_mutated_api_leg()
                             chat_lease.clear(buf, lease_generation)
                             return
                         end
+                    end
+
+                    -- if topic is ?, then generate it
+                    local topic_generation_started = false
+                    if headers.topic == "?" then
                         if not lease_valid() then
                             finalize_mutated_api_leg()
                             chat_lease.clear(buf, lease_generation)
                             return
                         end
-                        _parley.helpers.undojoin(buf)
-                        local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
-                        set_chat_topic_line(buf, all_lines, topic)
-                        lease_commit()
-                        finalize_mutated_api_leg()
-                        chat_lease.clear(buf, lease_generation)
-                    end, { buf = buf, find_line = function()
-                        return M.find_topic_line(buf)
-                    end, before_write = function()
-                        return lease_valid()
-                    end, after_write = function()
-                        lease_commit()
-                    end })
-                end
-
-                -- Place cursor appropriately
-                _parley.logger.debug(
-                    "Cursor movement check - use_free_cursor: "
-                        .. tostring(use_free_cursor)
-                        .. ", config.chat_free_cursor: "
-                        .. tostring(_parley.config.chat_free_cursor)
-                )
+                        topic_generation_started = true
+                        -- Topic gen: drop the leading system-prompt messages (1, or 2
+                        -- for a synthetic system prompt) AND ancestors — keep only the
+                        -- current-file conversation. Carrying the system prompt makes
+                        -- the model obey its 🧠:/persona mandate and open with a
+                        -- thinking block, which would otherwise become the "topic".
+                        local sys_lead = #require("parley.system_prompt_msgs").build(agent_info)
+                        local topic_msgs = M._conversation_after_lead(messages, sys_lead + ancestor_msg_count)
+                        table.insert(topic_msgs, { role = "assistant", content = qt.response })
+
+                        M.generate_topic(topic_msgs, agent_info.provider, agent_info.model, function(topic, _reason)
+                            if not topic then
+                                finalize_mutated_api_leg()
+                                chat_lease.clear(buf, lease_generation)
+                                return
+                            end
+                            if not lease_valid() then
+                                finalize_mutated_api_leg()
+                                chat_lease.clear(buf, lease_generation)
+                                return
+                            end
+                            _parley.helpers.undojoin(buf)
+                            local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
+                            set_chat_topic_line(buf, all_lines, topic)
+                            lease_commit()
+                            finalize_mutated_api_leg()
+                            chat_lease.clear(buf, lease_generation)
+                        end, { buf = buf, find_line = function()
+                            return M.find_topic_line(buf)
+                        end, before_write = function()
+                            return lease_valid()
+                        end, after_write = function()
+                            lease_commit()
+                        end })
+                    end

-                if is_follow_cursor_enabled(override_free_cursor) then
+                    -- Place cursor appropriately
                     _parley.logger.debug(
-                        "Moving cursor - exchange_idx: "
-                            .. tostring(exchange_idx)
-                            .. ", component: "
-                            .. tostring(component)
-                            .. ", streamed_cursor_line: "
-                            .. tostring(streamed_cursor_line)
+                        "Cursor movement check - use_free_cursor: "
+                            .. tostring(use_free_cursor)
+                            .. ", config.chat_free_cursor: "
+                            .. tostring(_parley.config.chat_free_cursor)
                     )

-                    local line = streamed_cursor_line
-                    if not line then
-                        if exchange_idx and component == "question" then
-                            line = response_start_line + 2
-                        else
-                            line = vim.api.nvim_buf_line_count(buf)
+                    if is_follow_cursor_enabled(override_free_cursor) then
+                        _parley.logger.debug(
+                            "Moving cursor - exchange_idx: "
+                                .. tostring(exchange_idx)
+                                .. ", component: "
+                                .. tostring(component)
+                                .. ", streamed_cursor_line: "
+                                .. tostring(streamed_cursor_line)
+                        )
+
+                        local line = streamed_cursor_line
+                        if not line then
+                            if exchange_idx and component == "question" then
+                                line = response_start_line + 2
+                            else
+                                line = vim.api.nvim_buf_line_count(buf)
+                            end
                         end
+                        _parley.logger.debug("Moving cursor to completion position: " .. tostring(line))
+                        _parley.helpers.cursor_to_line(line, buf, win)
+                    else
+                        _parley.logger.debug("Not moving cursor due to free_cursor setting")
                     end
-                    _parley.logger.debug("Moving cursor to completion position: " .. tostring(line))
-                    _parley.helpers.cursor_to_line(line, buf, win)
-                else
-                    _parley.logger.debug("Not moving cursor due to free_cursor setting")
-                end
-                -- Refresh interview timestamps (decoration provider handles chat highlights)
-                local interview = require("parley.interview")
-                interview.highlight_timestamps(buf)
-
-                if not topic_generation_started then
-                    finalize_mutated_api_leg()
-                end
+                    -- Refresh interview timestamps (decoration provider handles chat highlights)
+                    local interview = require("parley.interview")
+                    interview.highlight_timestamps(buf)

-                vim.cmd("doautocmd User ParleyDone")
+                    if not topic_generation_started then
+                        finalize_mutated_api_leg()
+                    end

-                -- Re-apply folds so freshly streamed 🧠:/🔧:/📎: blocks
-                -- collapse the same way they do on file open. apply_folds
-                -- is idempotent and reads the current buffer state.
-                pcall(function()
-                    require("parley.tool_folds").apply_folds(buf)
-                end)
+                    vim.cmd("doautocmd User ParleyDone")
+
+                    -- Re-apply folds so freshly streamed 🧠:/🔧:/📎: blocks
+                    -- collapse the same way they do on file open. apply_folds
+                    -- is idempotent and reads the current buffer state.
+                    pcall(function()
+                        require("parley.tool_folds").apply_folds(buf)
+                    end)
+
+                    -- Raw-mode logging (debug/learning aid). Writes per-turn
+                    -- markdown logs to <chat-dir>/.parley-logs/<basename>/.
+                    pcall(function()
+                        local rm = _parley.config.raw_mode or {}
+                        if not (rm.enable and (rm.log_exchange or rm.log_raw)) then return end
+                        local chat_path = vim.api.nvim_buf_get_name(buf)
+                        if chat_path == "" then return end
+                        local raw_log = require("parley.raw_log")
+                        if rm.log_exchange then
+                            raw_log.write_exchange_turn(chat_path, messages)
+                        end
+                        if rm.log_raw then
+                            local sse_lines
+                            if qt.raw_response and qt.raw_response ~= "" then
+                                sse_lines = vim.split(qt.raw_response, "\n", { plain = true })
+                            end
+                            local assembled = {
+                                stop_reason = qt.stop_reason,
+                                content = qt.response and { { type = "text", text = qt.response } } or nil,
+                                usage = qt.usage,
+                            }
+                            raw_log.write_raw_turn(chat_path, {
+                                request = final_payload,
+                                assembled = assembled,
+                                sse_lines = sse_lines,
+                            })
+                        end
+                    end)

-                -- Raw-mode logging (debug/learning aid). Writes per-turn
-                -- markdown logs to <chat-dir>/.parley-logs/<basename>/.
-                pcall(function()
-                    local rm = _parley.config.raw_mode or {}
-                    if not (rm.enable and (rm.log_exchange or rm.log_raw)) then return end
-                    local chat_path = vim.api.nvim_buf_get_name(buf)
-                    if chat_path == "" then return end
-                    local raw_log = require("parley.raw_log")
-                    if rm.log_exchange then
-                        raw_log.write_exchange_turn(chat_path, messages)
+                    -- Call the callback if provided
+                    if callback then
+                        callback()
                     end
-                    if rm.log_raw then
-                        local sse_lines
-                        if qt.raw_response and qt.raw_response ~= "" then
-                            sse_lines = vim.split(qt.raw_response, "\n", { plain = true })
-                        end
-                        local assembled = {
-                            stop_reason = qt.stop_reason,
-                            content = qt.response and { { type = "text", text = qt.response } } or nil,
-                            usage = qt.usage,
-                        }
-                        raw_log.write_raw_turn(chat_path, {
-                            request = final_payload,
-                            assembled = assembled,
-                            sse_lines = sse_lines,
-                        })
+                    if not topic_generation_started then
+                        chat_lease.clear(buf, lease_generation)
                     end
-                end)
-
-                -- Call the callback if provided
-                if callback then
-                    callback()
                 end
-                if not topic_generation_started then
-                    chat_lease.clear(buf, lease_generation)
-                end
-            end),
+                -- create_handler intentionally schedules buffer writes. Queue
+                -- completion behind all content actions flushed by chat_pending
+                -- so lease teardown cannot overtake the last staged write.
+                pending_session:complete(qid, function() vim.schedule(continue_completion) end)
+            end,
             nil,
-            vim.schedule_wrap(function(_, progress_event)
+            function(qid, progress_event)
                 if not progress_event or type(progress_event) ~= "table" then
                     return
                 end
-                if not spinner_active then
-                    return
-                end
-                local message = progress_event.message
-                local detail = progress_event.text
-                if type(detail) == "string" and detail ~= "" then
-                    local detail_key = table.concat({
-                        tostring(progress_event.phase or ""),
-                        tostring(progress_event.kind or ""),
-                        tostring(progress_event.tool or ""),
-                        tostring(progress_event.block_type or ""),
-                    }, ":")
-                    if progress_detail_key ~= detail_key then
-                        progress_detail_key = detail_key
-                        progress_detail_text = ""
-                    end
-                    progress_detail_text = progress_detail_text .. detail
-                    local compact = progress_detail_text:gsub("%s+", " "):gsub("^%s+", "")
-                    if compact ~= "" then
-                        if progress_event.kind == "reasoning" then
-                            message = "Reasoning: " .. compact
-                        else
-                            local base = (type(progress_event.message) == "string" and progress_event.message ~= "")
-                                and progress_event.message
-                                or "Working..."
-                            message = base .. " " .. compact
+                pending_session:progress(qid, progress_event)
+            end,
+            on_abort,
+            function(qid) pending_session:activity(qid) end,
+            function(qid, err)
+                pending_session:failure(qid, err, function(failure)
+                    -- As above, staged content schedules its concrete buffer
+                    -- write; surface the terminal only after that write runs.
+                    vim.schedule(function()
+                        local status = failure and failure.http_status
+                        local body = failure and failure.body
+                        local message = "parley: provider request failed"
+                        if status and (status < 200 or status > 299) then
+                            message = message .. " (HTTP " .. tostring(status) .. ")"
+                        elseif failure and failure.code then
+                            message = message .. " (exit " .. tostring(failure.code) .. ")"
                         end
-                    end
-                else
-                    progress_detail_text = ""
-                    progress_detail_key = nil
-                end
-
-                if type(message) == "string" and message ~= "" and message ~= spinner_message then
-                    spinner_message = message
-                    render_spinner_line()
-                end
-            end),
-            on_abort
+                        if type(body) == "string" and body:match("%S") then
+                            message = message .. ": " .. body:sub(1, 500)
+                        end
+                        teardown_chat_leg(message)
+                    end)
+                end)
+            end
         )
     end)
 end
diff --git a/lua/parley/dispatcher.lua b/lua/parley/dispatcher.lua
index fa87ea4..caa8c07 100644
--- a/lua/parley/dispatcher.lua
+++ b/lua/parley/dispatcher.lua
@@ -160,7 +160,8 @@ end
 ---@param on_exit function | nil # optional on_exit handler
 ---@param callback function | nil # optional callback handler
 ---@param on_progress function | nil # optional progress/status handler
-local query = function(buf, provider, payload, handler, on_exit, callback, on_progress)
+local query = function(buf, provider, payload, handler, on_exit, callback, on_progress,
+	on_activity, on_error, abort_before_start)
	-- make sure handler is a function
	if type(handler) ~= "function" then
		logger.error(
@@ -187,43 +188,129 @@ local query = function(buf, provider, payload, handler, on_exit, callback, on_pr
		ex_id = nil,
	})

+	local function legacy_complete(query_id, qt)
+		local function invoke_surface(label, fn, ...)
+			if type(fn) ~= "function" then return end
+			local args = { ... }
+			local arg_count = select("#", ...)
+			local ok = xpcall(function()
+				fn(unpack(args, 1, arg_count))
+			end, function() return nil end)
+			if not ok then logger.error(provider .. " " .. label .. " failed") end
+		end
+
+		local function schedule_surface(label, fn)
+			local ok = pcall(vim.schedule, function()
+				invoke_surface(label, fn)
+			end)
+			if not ok then logger.error(provider .. " " .. label .. " scheduling failed") end
+		end
+
+		if type(on_exit) == "function" then
+			invoke_surface("on_exit", on_exit, query_id)
+			if qt.ns_id and qt.buf then
+				schedule_surface("namespace cleanup", function()
+					vim.api.nvim_buf_clear_namespace(qt.buf, qt.ns_id, 0, -1)
+				end)
+			end
+		end
+		if type(callback) == "function" then
+			schedule_surface("assembled response callback", function()
+				callback(qt.response)
+			end)
+		end
+	end
+
	local out_reader = function()
		local buffer = ""
+		local sse_record_active = false
+		local stdout_finished = false

-		---@param lines_chunk string
-		local function process_lines(lines_chunk)
+		local function emit_activity(query_id)
+			if type(on_activity) == "function" then
+				on_activity(query_id)
+			end
+		end
+
+		---@param line string
+		local function process_line(line)
			local qt = tasker.get_query(qid)
			if not qt then
				return
			end
+			if line == "" then
+				sse_record_active = false
+				return
+			end

-			local lines = vim.split(lines_chunk, "\n")
+			local first = line:match("^%s*(.)")
+			if first == "{" or first == "[" then
+				emit_activity(qid)
+			elseif not sse_record_active then
+				emit_activity(qid)
+				sse_record_active = true
+			end

-			for _, line in ipairs(lines) do
-				if line ~= "" and line ~= nil then
-					qt.raw_response = qt.raw_response .. line .. "\n"
-				end
+			local progress_event = D._extract_sse_progress_event(line, qt.provider)
+			if progress_event and type(on_progress) == "function" then
+				on_progress(qid, progress_event)
+			end

-				-- Skip empty lines
-				if line == "" or line == nil then
-					goto continue
-				end
+			local content = D._extract_sse_content(line, qt.provider)
+			if content and type(content) == "string" and content ~= "" then
+				qt.response = qt.response .. content
+				handler(qid, content)
+			end
+		end

-				local progress_event = D._extract_sse_progress_event(line, qt.provider)
-				if progress_event and type(on_progress) == "function" then
-					on_progress(qid, progress_event)
+		local function finish_stdout(qt)
+			if stdout_finished then
+				return
+			end
+			stdout_finished = true
+			logger.debug(qt.provider .. " response received: body_bytes=" .. #qt.raw_response)
+
+			local adapter = providers.get(qt.provider)
+			local metrics = adapter.parse_usage(qt.raw_response)
+			tasker.set_cache_metrics(metrics)
+			qt.usage = metrics
+			qt.stop_reason = qt.raw_response:match('"stop_reason"%s*:%s*"([^"]+)"')
+				or qt.raw_response:match('"finish_reason"%s*:%s*"([^"]+)"')
+
+			local content = qt.response
+			if content == "" and qt.raw_response:match("choices") and qt.raw_response:match("content") then
+				local response
+				local ok, decoded = pcall(vim.json.decode, qt.raw_response)
+				if ok then
+					response = decoded
+				else
+					local json_str = qt.raw_response:match("{.-choices.-}")
+					if json_str then
+						local fallback_ok
+						fallback_ok, response = pcall(vim.json.decode, json_str)
+						if not fallback_ok then response = nil end
+					end
				end
-
-				-- Extract content using the provider adapter
-				local content = D._extract_sse_content(line, qt.provider)
-
-				if content and type(content) == "string" and content ~= "" then
+				if response and response.choices and response.choices[1]
+					and response.choices[1].message and response.choices[1].message.content then
+					content = response.choices[1].message.content
+				end
+				if content and type(content) == "string" then
					qt.response = qt.response .. content
					handler(qid, content)
				end
+			end

-				::continue::
+			if qt.response == "" then
+				local has_tool_use = qt.raw_response:find('"type":"tool_use"', 1, true) ~= nil
+				if not has_tool_use then
+					logger.error(qt.provider .. " response is empty: body_bytes=" .. #qt.raw_response)
+				end
			end
+
+			pcall(function()
+				require("parley.cliproxy").check_auth_failure(qt.provider, qt.raw_response)
+			end)
		end

		-- closure for uv.read_start(stdout, fn)
@@ -236,106 +323,20 @@ local query = function(buf, provider, payload, handler, on_exit, callback, on_pr
			if err then
				logger.error(qt.provider .. " query stdout error: " .. vim.inspect(err))
			elseif chunk then
-				-- add the incoming chunk to the buffer
+				qt.raw_response = qt.raw_response .. chunk
				buffer = buffer .. chunk
-				local last_newline_pos = buffer:find("\n[^\n]*$")
-				if last_newline_pos then
-					local complete_lines = buffer:sub(1, last_newline_pos - 1)
-					-- save the rest of the buffer for the next chunk
-					buffer = buffer:sub(last_newline_pos + 1)
-
-					process_lines(complete_lines)
+				while true do
+					local newline = buffer:find("\n", 1, true)
+					if not newline then break end
+					process_line(buffer:sub(1, newline - 1):gsub("\r$", ""))
+					buffer = buffer:sub(newline + 1)
				end
-				-- chunk is nil when EOF is reached
			else
-				-- if there's remaining data in the buffer, process it
				if #buffer > 0 then
-					process_lines(buffer)
-				end
-
-				local raw_response = qt.raw_response
-				logger.debug(qt.provider .. " response: \n" .. vim.inspect(qt.raw_response))
-
-				-- Extract usage metrics via the provider adapter
-				local adapter = providers.get(qt.provider)
-				local metrics = adapter.parse_usage(raw_response)
-				tasker.set_cache_metrics(metrics)
-				-- Stash usage on the query object so raw-mode logging can
-				-- include it in the assembled-response YAML.
-				qt.usage = metrics
-				-- Best-effort stop_reason extraction for the log entry.
-				qt.stop_reason = raw_response:match('"stop_reason"%s*:%s*"([^"]+)"')
-					or raw_response:match('"finish_reason"%s*:%s*"([^"]+)"')
-
-				local content = qt.response
-
-				-- Handle content extraction for empty OpenAI-compatible responses
-				if content == "" and raw_response:match('choices') and raw_response:match("content") then
-						local response
-						local ok, decoded = pcall(vim.json.decode, raw_response)
-						if ok then
-							response = decoded
-						else
-							local json_str = raw_response:match("{.-choices.-}")
-							if json_str then
-								local fallback_ok
-								fallback_ok, response = pcall(vim.json.decode, json_str)
-								if not fallback_ok then
-									response = nil
-								end
-							end
-						end
-
-					if response and response.choices and
-					   response.choices[1] and response.choices[1].message and
-					   response.choices[1].message.content then
-						content = response.choices[1].message.content
-					end
-
-					if content and type(content) == "string" then
-						qt.response = qt.response .. content
-						handler(qid, content)
-					end
-				end
-
-				if qt.response == "" then
-					-- Tool-use-only responses (#81 M2): Anthropic streams
-					-- content_block_start with type=tool_use plus
-					-- input_json_delta chunks, but none of those carry
-					-- a `delta.text` field, so qt.response stays empty.
-					-- The response is perfectly valid — the tool_loop
-					-- driver will extract the tool_use blocks from
-					-- qt.raw_response and handle them. Only warn if
-					-- raw_response also has no tool_use events.
-					local has_tool_use = type(qt.raw_response) == "string"
-						and qt.raw_response:find('"type":"tool_use"', 1, true) ~= nil
-					if not has_tool_use then
-						logger.error(qt.provider .. " response is empty: \n" .. vim.inspect(qt.raw_response))
-					end
-				end
-
-				-- M3 (#131): detect a managed-cliproxy missing/invalid-credential
-				-- failure and offer the right :ParleyProxy login.
-				pcall(function()
-					require("parley.cliproxy").check_auth_failure(qt.provider, qt.raw_response)
-				end)
-
-				-- optional on_exit handler
-				if type(on_exit) == "function" then
-					on_exit(qid)
-					if qt.ns_id and qt.buf then
-						vim.schedule(function()
-							vim.api.nvim_buf_clear_namespace(qt.buf, qt.ns_id, 0, -1)
-						end)
-					end
-				end
-
-				-- optional callback handler
-				if type(callback) == "function" then
-					vim.schedule(function()
-						callback(qt.response)
-					end)
+					process_line(buffer:gsub("\r$", ""))
+					buffer = ""
				end
+				finish_stdout(qt)
			end
		end
	end
@@ -347,7 +348,7 @@ local query = function(buf, provider, payload, handler, on_exit, callback, on_pr
	local secret_name = providers.get_secret_name(provider)
	local bearer = vault.get_secret(secret_name)
	if not bearer then
-		logger.warning(provider .. " bearer token is missing")
+		abort_before_start(provider .. " bearer token is missing")
		return
	end

@@ -362,6 +363,8 @@ local query = function(buf, provider, payload, handler, on_exit, callback, on_pr
	local args = {
		"--no-buffer",
		"-s",
+		"--write-out",
+		"%{stderr}__PARLEY_HTTP_" .. qid .. "__%{http_code}\n",
		endpoint,
		"-H",
		"Content-Type: application/json",
@@ -377,7 +380,50 @@ local query = function(buf, provider, payload, handler, on_exit, callback, on_pr
		table.insert(curl_params, header)
	end

-	tasker.run(buf, "curl", curl_params, nil, out_reader(), nil)
+	local terminal = tasker.once(function(code, signal, _stdout_data, stderr_data, io_error)
+		local qt = tasker.get_query(qid)
+		if not qt then return end
+		stderr_data = stderr_data or ""
+		local sentinel = "__PARLEY_HTTP_" .. qid .. "__"
+		local trailer_size = #sentinel + 4
+		local trailer = stderr_data:sub(-trailer_size)
+		local status = trailer:sub(#sentinel + 1, #sentinel + 3)
+		local trailer_valid = trailer:sub(1, #sentinel) == sentinel
+			and status:match("^%d%d%d$") ~= nil and trailer:sub(-1) == "\n"
+		local clean_stderr = stderr_data
+		if trailer_valid then
+			clean_stderr = stderr_data:sub(1, #stderr_data - trailer_size)
+		else
+			io_error = io_error or "missing or malformed curl HTTP status trailer"
+		end
+		local http_status = trailer_valid and tonumber(status) or nil
+		local failed = io_error ~= nil or code ~= 0
+			or (http_status ~= 0 and (http_status < 200 or http_status > 299))
+		if failed then
+			local failure = {
+				code = code,
+				signal = signal,
+				http_status = http_status,
+				body = qt.raw_response,
+				stderr = clean_stderr,
+				io_error = io_error,
+			}
+			if type(on_error) == "function" then
+				on_error(qid, failure)
+			else
+				local safe_io_error = tostring(io_error or "none"):gsub("%s+", " "):sub(1, 160)
+				logger.error(string.format(
+					"%s query failed: code=%s signal=%s http_status=%s io_error=%s body_bytes=%d stderr_bytes=%d",
+					provider, tostring(code), tostring(signal), tostring(http_status), safe_io_error,
+					#qt.raw_response, #clean_stderr
+				))
+				legacy_complete(qid, qt)
+			end
+		else
+			legacy_complete(qid, qt)
+		end
+	end)
+	tasker.run(buf, "curl", curl_params, terminal, out_reader(), nil, abort_before_start)
 end

 -- LLM query
@@ -388,30 +434,38 @@ end
 ---@param on_exit function | nil # optional on_exit handler
 ---@param callback function | nil # optional callback handler
 ---@param on_progress function | nil # optional progress/status handler
---- @param on_abort function | nil # optional abort handler. When an adapter's
+--- @param on_abort function | nil # optional qid-free pre-start abort handler
 ---   pre_query reports an error (e.g. the managed cliproxy can't be started),
 ---   the dispatcher invokes on_abort(msg) INSTEAD of running the query — the
 ---   caller uses it to tear down qid-free pre-query state (spinner, inserted
 ---   blocks, in-flight guards) so the request fails fast instead of hanging.
 ---   Additive + backward compatible: a one-arg pre_query (e.g. copilot) simply
 ---   ignores the error callback the dispatcher passes it.
-D.query = function(buf, provider, payload, handler, on_exit, callback, on_progress, on_abort)
+D.query = function(buf, provider, payload, handler, on_exit, callback, on_progress, on_abort,
+	on_activity, on_error)
+	local abort_before_start = tasker.once(function(msg)
+		logger.error("query abort before start [" .. tostring(provider) .. "]: " .. tostring(msg))
+		if type(on_abort) == "function" then
+			on_abort(msg)
+		end
+	end)
+	local function start_query()
+		query(buf, provider, payload, handler, on_exit, callback, on_progress,
+			on_activity, on_error, abort_before_start)
+	end
	local adapter = providers.get(provider)
	if adapter.pre_query then
		return vault.run_with_secret(provider, function()
			adapter.pre_query(function()
-				query(buf, provider, payload, handler, on_exit, callback, on_progress)
+				start_query()
			end, function(msg)
-				logger.error("pre_query abort [" .. tostring(provider) .. "]: " .. tostring(msg))
-				if type(on_abort) == "function" then
-					on_abort(msg)
-				end
+				abort_before_start(msg)
			end)
-		end)
+		end, abort_before_start)
	end
	vault.run_with_secret(provider, function()
-		query(buf, provider, payload, handler, on_exit, callback, on_progress)
-	end)
+		start_query()
+	end, abort_before_start)
 end

 -- response handler
diff --git a/lua/parley/init.lua b/lua/parley/init.lua
index b292d63..9504ab6 100644
--- a/lua/parley/init.lua
+++ b/lua/parley/init.lua
@@ -1604,6 +1604,9 @@ end
 -- renders → both decorations clear.
 -- `span` = the visual selection {sr, sc, er, ec} (1-based getpos values).
 local function render_definition(buf, span, phrase, result)
+	if not vim.api.nvim_buf_is_valid(buf) then
+		return
+	end
	-- Pick the emit_definition call (unforced → the model may answer in text or
	-- only call web_search; both mean "no definition"). Notify rather than
	-- silently doing nothing, and leave no footnote edit.
@@ -1688,9 +1691,12 @@ function M.define_visual(buf)

	local span = { sr, sc, er, ec }
	local manifest = require("parley.skills.define")
+	local stop_selection_spinner = require("parley.selection_spinner").start(buf, er - 1, ec)
	require("parley.skill_invoke").invoke(buf, manifest, { phrase = phrase }, {
		document = context,
		no_reload = true,
+		detached_progress = false,
+		on_terminal = stop_selection_spinner,
		on_done = function(result) render_definition(buf, span, phrase, result) end,
	})
 end
diff --git a/lua/parley/selection_spinner.lua b/lua/parley/selection_spinner.lua
new file mode 100644
index 0000000..51cc8c4
--- /dev/null
+++ b/lua/parley/selection_spinner.lua
@@ -0,0 +1,76 @@
+-- parley.selection_spinner — immediate read-only progress at a selection edge.
+
+local M = {}
+
+local uv = vim.uv or vim.loop
+local namespace = vim.api.nvim_create_namespace("parley_selection_spinner")
+
+--- Start a canonical inline spinner at the exclusive end of a selection.
+--- @param buf number
+--- @param row number 0-based row
+--- @param col number 0-based byte column
+--- @return function stop idempotent teardown
+function M.start(buf, row, col)
+    local stopped = false
+    local timer
+    local extmark
+    local tick = 1 -- progress.frame(1) is the approved initial frame: ⠙.
+
+    local function stop()
+        if stopped then return end
+        stopped = true
+        if timer then
+            pcall(function() timer:stop() end)
+            pcall(function() timer:close() end)
+            timer = nil
+        end
+        if extmark and vim.api.nvim_buf_is_valid(buf) then
+            pcall(vim.api.nvim_buf_del_extmark, buf, namespace, extmark)
+        end
+        extmark = nil
+    end
+
+    local function render()
+        if stopped then return end
+        if not vim.api.nvim_buf_is_valid(buf) then
+            stop()
+            return
+        end
+        local ok, mark = pcall(vim.api.nvim_buf_set_extmark, buf, namespace, row, col, {
+            id = extmark,
+            virt_text = { { " " .. require("parley.progress").frame(tick) } },
+            virt_text_pos = "inline",
+            invalidate = true,
+        })
+        if not ok then
+            stop()
+            return
+        end
+        extmark = mark
+    end
+
+    if not vim.api.nvim_buf_is_valid(buf) then
+        stopped = true
+        return stop
+    end
+    render()
+    if stopped then return stop end
+
+    timer = uv.new_timer()
+    if not timer then
+        stop()
+        return stop
+    end
+    timer:start(90, 90, vim.schedule_wrap(function()
+        if stopped then return end
+        if not vim.api.nvim_buf_is_valid(buf) then
+            stop()
+            return
+        end
+        tick = tick + 1
+        render()
+    end))
+    return stop
+end
+
+return M
diff --git a/lua/parley/skill_invoke.lua b/lua/parley/skill_invoke.lua
index 67fc071..bc8624f 100644
--- a/lua/parley/skill_invoke.lua
+++ b/lua/parley/skill_invoke.lua
@@ -25,6 +25,8 @@ local _in_flight = {}
 -- their gen and no-op if a newer exchange superseded them — so a cancelled
 -- (killed) query's late callback can't clobber the new one's state. (#133)
 local _gen = {}
+-- The exact-once terminal owned by the active generation for each buffer.
+local _terminals = {}

 --- Is a skill exchange in flight for `buf`? Cleared on on_exit/on_abort, so an
 --- abort that can't start the query doesn't block the buffer forever (#131).
@@ -40,9 +42,12 @@ end
 --- review job). Lets a new round supersede a stuck/slow one (#133).
 --- @param buf number
 function M.cancel(buf)
+    local finish = _terminals[buf]
+    if finish then
+        finish({ ok = false, msg = "cancelled" }, false)
+    end
     _gen[buf] = (_gen[buf] or 0) + 1
     _in_flight[buf] = nil
-    pcall(function() require("parley.progress").stop() end)
     pcall(function() require("parley.tasker").stop() end)
 end

@@ -95,7 +100,8 @@ end
 --- @param buf number the artifact buffer
 --- @param manifest table SkillManifest
 --- @param args table|nil completable-arg values
---- @param opts table|nil { manual = boolean? (default true), on_done = fun(result)? }
+--- @param opts table|nil { manual=boolean?, no_reload=boolean?, document=string?,
+---   detached_progress=boolean?, on_terminal=fun(result)?, on_done=fun(result)? }
 function M.invoke(buf, manifest, args, opts)
     opts = opts or {}
     local manual = opts.manual
@@ -112,22 +118,55 @@ function M.invoke(buf, manifest, args, opts)
     local assembly = require("parley.skill_assembly")
     local skill_render = require("parley.skill_render")

-    local artifact_path = vim.api.nvim_buf_get_name(buf)
-    if artifact_path == "" then
-        p.logger.warning("skill " .. tostring(manifest.name) .. ": buffer has no file — open the artifact first")
-        if opts.on_done then
-            opts.on_done({ ok = false, msg = "buffer has no file" })
+    local function deliver_attempt(result, deliver_done)
+        if opts.on_terminal then
+            local ok = pcall(opts.on_terminal, result)
+            if not ok then p.logger.error("skill terminal callback failed") end
+        end
+        if deliver_done and opts.on_done then
+            local ok = pcall(opts.on_done, result)
+            if not ok then p.logger.error("skill completion callback failed") end
         end
-        return
     end
+
     if _in_flight[buf] then
         p.logger.warning("skill " .. tostring(manifest.name) .. ": already running on this buffer")
+        deliver_attempt({ ok = false, msg = "already running" }, true)
         return
     end

     -- This exchange's generation; on_exit/on_abort no-op if superseded (#133).
     local gen = (_gen[buf] or 0) + 1
     _gen[buf] = gen
+    local finished = false
+    local detached_progress = opts.detached_progress ~= false
+    local progress_started = false
+    local function finish(result, deliver_done)
+        if finished then return false end
+        finished = true
+        if progress_started then
+            pcall(function() require("parley.progress").stop() end)
+            progress_started = false
+        end
+        if _terminals[buf] == finish then
+            _terminals[buf] = nil
+            _in_flight[buf] = nil
+        end
+        deliver_attempt(result, deliver_done)
+        return true
+    end
+    _terminals[buf] = finish
+
+    if not vim.api.nvim_buf_is_valid(buf) then
+        finish({ ok = false, msg = "buffer invalid" }, false)
+        return
+    end
+    local ok_path, artifact_path = pcall(vim.api.nvim_buf_get_name, buf)
+    if not ok_path or artifact_path == "" then
+        p.logger.warning("skill " .. tostring(manifest.name) .. ": buffer has no file — open the artifact first")
+        finish({ ok = false, msg = "buffer has no file" }, true)
+        return
+    end

     -- Sync file == buffer so edits compute + apply against the same content.
     -- A read-only skill (opts.no_reload — e.g. define, #161) makes no edits, so
@@ -146,9 +185,7 @@ function M.invoke(buf, manifest, args, opts)
     local ok_src, body = pcall(manifest.source, { args = args or {}, repo_root = p.config.repo_root })
     if not ok_src then
         p.logger.error("skill " .. tostring(manifest.name) .. ": source failed: " .. tostring(body))
-        if opts.on_done then
-            opts.on_done({ ok = false, msg = "source failed: " .. tostring(body) })
-        end
+        finish({ ok = false, msg = "source failed: " .. tostring(body) }, true)
         return
     end
     -- opts.document lets a caller send a bounded context (e.g. define's enclosing
@@ -163,9 +200,7 @@ function M.invoke(buf, manifest, args, opts)
     })
     if not agent then
         p.logger.warning("skill " .. tostring(manifest.name) .. ": no tool-capable agent resolved")
-        if opts.on_done then
-            opts.on_done({ ok = false, msg = "no agent" })
-        end
+        finish({ ok = false, msg = "no agent" }, true)
         return
     end

@@ -188,8 +223,11 @@ function M.invoke(buf, manifest, args, opts)
     _in_flight[buf] = true
     -- Detached progress bar: this is a ~30s headless op, so show a running cue
     -- (the first substantive-progress surface, #133 M7). Stopped on exit/abort.
-    require("parley.progress").start("Parley " .. tostring(manifest.name) .. " running…")
-    llm.query(
+    if detached_progress then
+        progress_started = require("parley.progress").start(
+            "Parley " .. tostring(manifest.name) .. " running…")
+    end
+    local ok_query = pcall(llm.query,
         nil, -- headless: no streaming buffer insertion
         agent.provider,
         payload,
@@ -198,68 +236,82 @@ function M.invoke(buf, manifest, args, opts)
             vim.schedule(function()
                 -- Superseded by a newer exchange (the old one was cancelled) →
                 -- no-op so we don't reload/re-render or clobber the new state.
-                if _gen[buf] ~= gen then
+                if finished or _gen[buf] ~= gen then
+                    return
+                end
+                if not vim.api.nvim_buf_is_valid(buf) then
+                    finish({ ok = false, msg = "buffer invalid" }, false)
                     return
                 end
-                require("parley.progress").stop()
-                _in_flight[buf] = nil
-                local qt = tasker.get_query(qid) or {}
-                local calls = providers.decode_anthropic_tool_calls_from_stream(qt.raw_response or "")
-                local results = {}
-                local applied = 0
-                local errors = {}
-                for i, call in ipairs(calls) do
-                    if call.name == "propose_edits" then
-                        call.input = call.input or {}
-                        call.input.file_path = artifact_path -- artifact-bound
-                        -- Some models emit `edits` as a JSON STRING rather than an
-                        -- array; coerce it once here so the batch actually applies
-                        -- (and render_propose_edits below gets a table). #133
-                        if type(call.input.edits) == "string" then
-                            local ok, decoded = pcall(vim.json.decode, call.input.edits)
-                            if ok and type(decoded) == "table" then
-                                call.input.edits = decoded
+                local function complete()
+                    local qt = tasker.get_query(qid) or {}
+                    local calls = providers.decode_anthropic_tool_calls_from_stream(qt.raw_response or "")
+                    local results = {}
+                    local applied = 0
+                    local errors = {}
+                    for i, call in ipairs(calls) do
+                        if call.name == "propose_edits" then
+                            call.input = call.input or {}
+                            call.input.file_path = artifact_path -- artifact-bound
+                            -- Some models emit `edits` as a JSON STRING rather than an
+                            -- array; coerce it once here so the batch actually applies
+                            -- (and render_propose_edits below gets a table). #133
+                            if type(call.input.edits) == "string" then
+                                local ok, decoded = pcall(vim.json.decode, call.input.edits)
+                                if ok and type(decoded) == "table" then
+                                    call.input.edits = decoded
+                                end
                             end
                         end
-                    end
-                    results[i] = tools_dispatcher.execute_call(call, tools_registry,
-                        { cwd = cwd, root_policy = root_policy,
-                          page_limit = require("parley.config").tool_result_page_lines }) -- #140 #139
-                    if call.name == "propose_edits" then
-                        if results[i].is_error then
-                            table.insert(errors, results[i].content)
-                        else
-                            applied = applied + 1
+                        results[i] = tools_dispatcher.execute_call(call, tools_registry,
+                            { cwd = cwd, root_policy = root_policy,
+                              page_limit = require("parley.config").tool_result_page_lines }) -- #140 #139
+                        if call.name == "propose_edits" then
+                            if results[i].is_error then
+                                table.insert(errors, results[i].content)
+                            else
+                                applied = applied + 1
+                            end
                         end
                     end
-                end
-                if not opts.no_reload then
-                    reload_buffer(buf)
-                end
-                local new_content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
-                local decorations = {}
-                for _, call in ipairs(calls) do
-                    if call.name == "propose_edits" then
-                        for _, d in ipairs(render_propose_edits(buf, call, original, new_content)) do
-                            table.insert(decorations, d)
+                    if not vim.api.nvim_buf_is_valid(buf) then
+                        finish({ ok = false, msg = "buffer invalid" }, false)
+                        return
+                    end
+                    if not opts.no_reload then
+                        reload_buffer(buf)
+                    end
+                    if not vim.api.nvim_buf_is_valid(buf) then
+                        finish({ ok = false, msg = "buffer invalid" }, false)
+                        return
+                    end
+                    local new_content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
+                    local decorations = {}
+                    for _, call in ipairs(calls) do
+                        if not vim.api.nvim_buf_is_valid(buf) then
+                            finish({ ok = false, msg = "buffer invalid" }, false)
+                            return
+                        end
+                        if call.name == "propose_edits" then
+                            for _, d in ipairs(render_propose_edits(buf, call, original, new_content)) do
+                                table.insert(decorations, d)
+                            end
                         end
                     end
-                end
-                -- Surface failure rather than swallowing it: a tool error, or no
-                -- tool call at all (a truncated/empty response), is logged so the
-                -- caller (review) can STOP rather than resubmit blindly.
-                if #calls == 0 then
-                    p.logger.warning("skill " .. tostring(manifest.name)
-                        .. ": model returned no tool call (response may be truncated)")
-                end
-                for _, e in ipairs(errors) do
-                    p.logger.error("skill " .. tostring(manifest.name) .. ": " .. tostring(e))
-                end
-                if opts.on_done then
+                    -- Surface failure rather than swallowing it: a tool error, or no
+                    -- tool call at all (a truncated/empty response), is logged so the
+                    -- caller (review) can STOP rather than resubmit blindly.
+                    if #calls == 0 then
+                        p.logger.warning("skill " .. tostring(manifest.name)
+                            .. ": model returned no tool call (response may be truncated)")
+                    end
+                    for _, e in ipairs(errors) do
+                        p.logger.error("skill " .. tostring(manifest.name) .. ": " .. tostring(e))
+                    end
                     -- Pure-fed payload: original/new_content/decorations let a
                     -- caller (review) journal the round without re-reading the
                     -- buffer (#133 M3).
-                    opts.on_done({
+                    finish({
                         ok = (#errors == 0),
                         applied = applied,
                         calls = calls,
@@ -267,24 +319,35 @@ function M.invoke(buf, manifest, args, opts)
                         original = original,
                         new_content = new_content,
                         decorations = decorations,
-                    })
+                    }, true)
+                end
+                local ok_completion = xpcall(complete, function() return nil end)
+                if not ok_completion then
+                    p.logger.error("skill " .. tostring(manifest.name) .. " completion failed")
+                    finish({ ok = false, msg = "completion failed" }, true)
                 end
             end)
         end,
         nil,
         nil,
         function(msg) -- on_abort
-            if _gen[buf] ~= gen then
+            if finished or _gen[buf] ~= gen then
                 return -- superseded by a newer exchange (cancelled) → no-op
             end
-            require("parley.progress").stop()
-            _in_flight[buf] = nil
             p.logger.error("skill " .. tostring(manifest.name) .. " abort: " .. tostring(msg))
-            if opts.on_done then
-                opts.on_done({ ok = false, msg = tostring(msg) })
-            end
+            finish({ ok = false, msg = tostring(msg) }, true)
+        end,
+        nil,
+        function(_qid, transport_error) -- on_error (dispatcher argument 10)
+            if finished or _gen[buf] ~= gen then return end
+            p.logger.error("skill " .. tostring(manifest.name) .. " transport error")
+            finish({ ok = false, msg = "transport error", error = transport_error }, true)
         end
     )
+    if not ok_query then
+        p.logger.error("skill " .. tostring(manifest.name) .. " query failed")
+        finish({ ok = false, msg = "query failed" }, true)
+    end
 end

 return M
diff --git a/lua/parley/tasker.lua b/lua/parley/tasker.lua
index a0bee62..e0a5c19 100644
--- a/lua/parley/tasker.lua
+++ b/lua/parley/tasker.lua
@@ -8,6 +8,7 @@ local uv = vim.uv or vim.loop

 local M = {}
 M._handles = {}
+M._uv = nil -- injectable transport seam for deterministic drain-order tests
 M._queries = {} -- table of latest queries
 M._debug = {
     is_busy_calls = 0,
@@ -282,75 +283,163 @@ end
 ---@param buf number | nil # buffer number
 ---@param cmd string # command to execute
 ---@param args table # arguments for command
----@param callback function | nil # exit callback function(code, signal, stdout_data, stderr_data)
+---@param callback function | nil # exit callback function(code, signal, stdout_data, stderr_data, io_error)
 ---@param out_reader function | nil # stdout reader function(err, data)
 ---@param err_reader function | nil # stderr reader function(err, data)
-M.run = function(buf, cmd, args, callback, out_reader, err_reader)
+---@param on_start_error function | nil # scheduled launch rejection callback(message)
+M.run = function(buf, cmd, args, callback, out_reader, err_reader, on_start_error)
	logger.debug("run command: " .. cmd .. " " .. table.concat(args, " "), true)
-
-	local handle, pid
-	local stdout = uv.new_pipe(false)
-	local stderr = uv.new_pipe(false)
-	local stdout_data = ""
-	local stderr_data = ""
+	local run_uv = M._uv or uv

	-- Run cleanup routine to remove stale processes
	M.cleanup_stale_handles()

	if M.is_busy(buf, false) then
+		if on_start_error then
+			vim.schedule(function()
+				on_start_error("task start rejected: buffer is busy")
+			end)
+		end
		return
	end

-	local on_exit = M.once(vim.schedule_wrap(function(code, signal)
-		stdout:read_stop()
-		stderr:read_stop()
-		stdout:close()
-		stderr:close()
-		if handle and not handle:is_closing() then
-			handle:close()
+	local handle, pid
+	local stdout = run_uv.new_pipe(false)
+	local stderr = run_uv.new_pipe(false)
+	local stdout_data = ""
+	local stderr_data = ""
+	local exit_code
+	local exit_signal
+	local process_done = false
+	local stdout_done = false
+	local stderr_done = false
+	local io_error
+
+	local function call_safely(label, fn, ...)
+		if not fn then return end
+		local call_args = { ... }
+		local arg_count = select("#", ...)
+		local ok = xpcall(function()
+			fn(unpack(call_args, 1, arg_count))
+		end, function() return nil end)
+		if not ok then
+			logger.error(label .. " callback failed")
		end
-		if callback then
-			callback(code, signal, stdout_data, stderr_data)
+	end
+
+	local finish = M.once(function()
+		vim.schedule(function()
+			call_safely("task terminal", callback,
+				exit_code, exit_signal, stdout_data, stderr_data, io_error)
+			M.remove_handle(pid)
+			local ok, message = pcall(vim.cmd, "doautocmd User ParleyQueryFinished")
+			if not ok then logger.error("ParleyQueryFinished failed: " .. tostring(message)) end
+		end)
+	end)
+
+	local function maybe_finish()
+		if process_done and stdout_done and stderr_done then
+			finish()
		end
-		M.remove_handle(pid)
+	end

-		-- Trigger event for lualine update
-		vim.cmd("doautocmd User ParleyQueryFinished")
-	end))
+	local function close_pipe(pipe)
+		pcall(function() pipe:read_stop() end)
+		if not pipe:is_closing() then
+			pipe:close()
+		end
+	end

-	handle, pid = uv.spawn(cmd, {
+	local function on_exit(code, signal)
+		exit_code = code
+		exit_signal = signal
+		process_done = true
+		if handle and not handle:is_closing() then
+			handle:close()
+		end
+		maybe_finish()
+	end
+
+	local spawn_error
+	handle, pid = run_uv.spawn(cmd, {
		args = args,
		stdio = { nil, stdout, stderr },
		hide = true,
		detach = true,
	}, on_exit)
+	if not handle then
+		spawn_error = pid
+		close_pipe(stdout)
+		close_pipe(stderr)
+		if on_start_error then
+			local report_start_error = M.once(on_start_error)
+			vim.schedule(function()
+				report_start_error("task start failed: " .. tostring(spawn_error))
+			end)
+		end
+		return
+	end

	logger.debug(cmd .. " command started with pid: " .. pid, true)

	M.add_handle(handle, pid, buf)

-	uv.read_start(stdout, function(err, data)
+	local function stdout_callback(err, data)
+		if stdout_done then return end
		if err then
			logger.error("Error reading stdout: " .. vim.inspect(err))
+			io_error = io_error or ("stdout: " .. tostring(err))
		end
		if data then
			stdout_data = stdout_data .. data
		end
-		if out_reader then
-			out_reader(err, data)
+		call_safely("stdout reader", out_reader, err, data)
+		if err then
+			call_safely("stdout reader EOF", out_reader, nil, nil)
		end
-	end)
+		if err or data == nil then
+			stdout_done = true
+			close_pipe(stdout)
+			maybe_finish()
+		end
+	end

-	uv.read_start(stderr, function(err, data)
+	local function stderr_callback(err, data)
+		if stderr_done then return end
		if err then
			logger.error("Error reading stderr: " .. vim.inspect(err))
+			io_error = io_error or ("stderr: " .. tostring(err))
		end
		if data then
			stderr_data = stderr_data .. data
		end
-		if err_reader then
-			err_reader(err, data)
+		call_safely("stderr reader", err_reader, err, data)
+		if err then
+			call_safely("stderr reader EOF", err_reader, nil, nil)
+		end
+		if err or data == nil then
+			stderr_done = true
+			close_pipe(stderr)
+			maybe_finish()
+		end
+	end
+
+	local function start_read(stream, pipe, reader, reject)
+		local ok, result, detail = pcall(run_uv.read_start, pipe, reader)
+		local failed = not ok or result == false
+			or (type(result) == "number" and result ~= 0)
+			or (result == nil and detail ~= nil)
+		if failed then
+			local reason = ok and (detail or result) or result
+			reject(stream .. " read_start failed: " .. tostring(reason))
		end
+	end
+
+	start_read("stdout", stdout, stdout_callback, function(message)
+		stdout_callback(message, nil)
+	end)
+	start_read("stderr", stderr, stderr_callback, function(message)
+		stderr_callback(message, nil)
	end)
 end

diff --git a/lua/parley/vault.lua b/lua/parley/vault.lua
index b76a035..84ebefc 100644
--- a/lua/parley/vault.lua
+++ b/lua/parley/vault.lua
@@ -72,20 +72,40 @@ end
 ---@param name string # provider name
 ---@param secret string | table | nil # secret or command to retrieve it
 ---@param callback function | nil # callback to run after secret is resolved
-V.resolve_secret = function(name, secret, callback)
+---@param on_error function | nil # optional resolver failure callback(message)
+V.resolve_secret = function(name, secret, callback, on_error)
	name = resolve_secret_name(name)
	logger.debug("vault resolver started for " .. name .. ": " .. vim.inspect(secret), true)
	callback = callback or function() end
-	if secrets[name] and type(secrets[name]) ~= "table" then
+	local fail = tasker.once(function(message)
+		logger.warning(message, true)
+		if on_error then
+			on_error(message)
+		end
+	end)
+	local stored = secrets[name]
+	if type(stored) == "string" and stored:match("%S") then
		logger.debug("vault resolver secret " .. name .. " already resolved", true)
		callback()
		return
	end
+	if not secret or (type(secret) == "string" and not secret:match("%S"))
+		or (type(secret) == "table" and (#secret == 0
+			or type(secret[1]) ~= "string" or not secret[1]:match("%S"))) then
+		fail("vault resolver for " .. name .. " got empty secret")
+		return
+	end

	local post_process = function()
		local s = secrets[name]
		if s and type(s) == "string" then
			secrets[name] = s:gsub("^%s*(.-)%s*$", "%1")
+			s = secrets[name]
+		end
+		if type(s) ~= "string" or not s:match("%S") then
+			secrets[name] = nil
+			fail("vault resolver got empty response for " .. name)
+			return
		end
		logger.debug("vault resolver finished for " .. name .. ": " .. vim.inspect(secrets[name]), true)

@@ -94,26 +114,25 @@ V.resolve_secret = function(name, secret, callback)
		callback()
	end

-	if not secret then
-		logger.warning("vault resolver for " .. name .. " got empty secret", true)
-		return
-	end
-
	if type(secret) == "table" then
		local copy = vim.deepcopy(secret)
		local cmd = table.remove(copy, 1)
		local args = copy
-		tasker.run(nil, cmd, args, function(code, signal, stdout_data, stderr_data)
+		tasker.run(nil, cmd, args, function(code, signal, stdout_data, stderr_data, io_error)
+			if io_error then
+				fail("vault resolver for " .. name .. " failed: " .. tostring(io_error))
+				return
+			end
			if code == 0 then
				local content = stdout_data:match("^%s*(.-)%s*$")
				if not string.match(content, "%S") then
-					logger.warning("vault resolver got empty response for " .. name .. " secret command " .. vim.inspect(secret))
+					fail("vault resolver got empty response for " .. name .. " secret command " .. vim.inspect(secret))
					return
				end
				secrets[name] = content
				post_process()
			else
-				logger.warning(
+				fail(
					"vault resolver for "
						.. name
						.. "secret command "
@@ -128,6 +147,8 @@ V.resolve_secret = function(name, secret, callback)
						.. stderr_data
				)
			end
+		end, nil, nil, function(message)
+			fail("vault resolver for " .. name .. " launch failed: " .. tostring(message))
		end)
	else
		secrets[name] = secret
@@ -199,20 +220,30 @@ end

 ---@param name string # secret name
 ---@param callback function # function to run after secret is resolved
-V.run_with_secret = function(name, callback)
+---@param on_error function | nil # optional missing/resolution failure callback(message)
+V.run_with_secret = function(name, callback, on_error)
	name = resolve_secret_name(name)
-	if not secrets[name] then
-		logger.warning("vault secret " .. name .. " not found", true)
+	local secret = secrets[name]
+	if not secret then
+		local message = "vault secret " .. name .. " not found"
+		logger.warning(message, true)
+		if on_error then
+			on_error(message)
+		end
		return
	end
-	if type(secrets[name]) == "table" then
-		V.resolve_secret(name, secrets[name], function()
+	if type(secret) == "table" then
+		V.resolve_secret(name, secret, function()
			logger.debug("vault run_with_secret: " .. name .. " resolved, running callback", true)
			callback()
-		end)
-	else
+		end, on_error)
+	elseif type(secret) == "string" and secret:match("%S") then
		logger.debug("vault run_with_secret: " .. name .. " already resolved, running callback", true)
		callback()
+	else
+		local message = "vault secret " .. name .. " is empty"
+		logger.warning(message, true)
+		if on_error then on_error(message) end
	end
 end

diff --git a/tests/fixtures/fake_sse_server b/tests/fixtures/fake_sse_server
new file mode 100755
index 0000000..b39f291
--- /dev/null
+++ b/tests/fixtures/fake_sse_server
@@ -0,0 +1,60 @@
+#!/usr/bin/env python3
+import http.server
+import os
+import socketserver
+import sys
+import time
+
+
+MODE = sys.argv[1]
+READY_FILE = sys.argv[2]
+PARTIAL = b'data: {"choices":[{"delta":{"content":"partial answer"}}]}\n\n'
+DONE = b'data: [DONE]\n\n'
+
+
+class Handler(http.server.BaseHTTPRequestHandler):
+    def log_message(self, _format, *_args):
+        pass
+
+    def do_POST(self):
+        length = int(self.headers.get("Content-Length", "0"))
+        self.rfile.read(length)
+        if MODE == "unauthorized":
+            body = b'{"error":"fixture unauthorized"}'
+            self.send_response(401)
+            self.send_header("Content-Type", "application/json")
+            self.send_header("Content-Length", str(len(body)))
+            self.end_headers()
+            self.wfile.write(body)
+            return
+        if MODE == "http500":
+            self.send_response(500)
+            self.send_header("Content-Type", "text/event-stream")
+            self.send_header("Content-Length", str(len(PARTIAL)))
+            self.end_headers()
+            self.wfile.write(PARTIAL)
+            return
+
+        self.send_response(200)
+        self.send_header("Content-Type", "text/event-stream")
+        if MODE == "broken":
+            self.send_header("Content-Length", str(len(PARTIAL) + 100))
+        self.end_headers()
+        if MODE == "delayed":
+            time.sleep(1.1)
+        self.wfile.write(PARTIAL)
+        self.wfile.flush()
+        if MODE == "broken":
+            self.close_connection = True
+            return
+        self.wfile.write(DONE)
+
+
+class Server(socketserver.TCPServer):
+    allow_reuse_address = True
+
+
+with Server(("127.0.0.1", 0), Handler) as server:
+    with open(READY_FILE, "w", encoding="utf-8") as ready:
+        ready.write(str(server.server_address[1]))
+    server.handle_request()
diff --git a/tests/integration/chat_pending_spec.lua b/tests/integration/chat_pending_spec.lua
new file mode 100644
index 0000000..fc0db1a
--- /dev/null
+++ b/tests/integration/chat_pending_spec.lua
@@ -0,0 +1,686 @@
+local chat_pending = require("parley.chat_pending")
+local logger = require("parley.logger")
+
+local uv = vim.uv or vim.loop
+
+local function fake_runtime()
+    local now = 0
+    local queue = {}
+    local timers = {}
+    local next_timer = 0
+
+    local scheduler = {}
+    scheduler.enqueue = function(callback)
+        table.insert(queue, callback)
+    end
+    local function register(delay, repeating, callback)
+        next_timer = next_timer + 1
+        local timer = {
+            due = now + delay,
+            interval = repeating and delay or nil,
+            callback = callback,
+            closed = false,
+        }
+        timers[next_timer] = timer
+        return function()
+            if timer.closed then
+                return
+            end
+            timer.closed = true
+        end
+    end
+    scheduler.after = function(delay, callback)
+        return register(delay, false, callback)
+    end
+    scheduler.every = function(delay, callback)
+        return register(delay, true, callback)
+    end
+
+    local runtime = {
+        clock = { now_ms = function() return now end },
+        scheduler = scheduler,
+    }
+    function runtime:drain()
+        while #queue > 0 do
+            local callback = table.remove(queue, 1)
+            callback()
+        end
+    end
+    function runtime:advance(milliseconds)
+        now = now + milliseconds
+        local again = true
+        while again do
+            again = false
+            for _, timer in pairs(timers) do
+                if not timer.closed and timer.due <= now then
+                    if timer.interval then
+                        timer.due = timer.due + timer.interval
+                    else
+                        timer.closed = true
+                    end
+                    timer.callback()
+                    again = true
+                end
+            end
+        end
+    end
+    function runtime:fire_earliest_timer_early()
+        local earliest
+        for _, timer in pairs(timers) do
+            if not timer.closed and (not earliest or timer.due < earliest.due) then
+                earliest = timer
+            end
+        end
+        assert(earliest, "expected an open timer")
+        if earliest.interval then
+            earliest.due = earliest.due + earliest.interval
+        else
+            earliest.closed = true
+        end
+        earliest.callback()
+    end
+    function runtime:open_timer_count()
+        local count = 0
+        for _, timer in pairs(timers) do
+            if not timer.closed then
+                count = count + 1
+            end
+        end
+        return count
+    end
+    return runtime
+end
+
+local function scratch()
+    local buf = vim.api.nvim_create_buf(false, true)
+    vim.api.nvim_set_current_buf(buf)
+    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "assistant:" })
+    return buf
+end
+
+local function extmark(buf)
+    local namespace = vim.api.nvim_get_namespaces().parley_chat_pending
+    assert.is_truthy(namespace)
+    local marks = vim.api.nvim_buf_get_extmarks(buf, namespace, 0, -1, { details = true })
+    if #marks == 0 then
+        return nil
+    end
+    assert.equals(1, #marks)
+    return marks[1]
+end
+
+local function virtual_text(buf)
+    local mark = extmark(buf)
+    if not mark then
+        return nil
+    end
+    return mark[4].virt_lines[1][1][1], mark
+end
+
+local function start_fake(buf, runtime, opts)
+    opts = opts or {}
+    local emitted = opts.emitted or {}
+    local session = chat_pending.start({
+        buf = buf,
+        anchor_line = 0,
+        lease_valid = opts.lease_valid or function() return true end,
+        emit_content = function(qid, chunk)
+            table.insert(emitted, { qid, chunk })
+        end,
+        choose_verb_index = opts.choose_verb_index or function() return 1 end,
+        clock = runtime.clock,
+        scheduler = runtime.scheduler,
+    })
+    runtime:drain()
+    return session, emitted
+end
+
+describe("chat pending extmark adapter", function()
+    local buffers = {}
+    local runtimes = {}
+
+    local function new_runtime()
+        local runtime = fake_runtime()
+        table.insert(runtimes, runtime)
+        return runtime
+    end
+
+    after_each(function()
+        chat_pending.cancel_all("test teardown")
+        for _, runtime in ipairs(runtimes) do
+            runtime:drain()
+        end
+        vim.wait(20, function() return false end, 1)
+        for _, buf in ipairs(buffers) do
+            if vim.api.nvim_buf_is_valid(buf) then
+                vim.api.nvim_buf_delete(buf, { force = true })
+            end
+        end
+        buffers = {}
+        runtimes = {}
+    end)
+
+    local function new_scratch()
+        local buf = scratch()
+        table.insert(buffers, buf)
+        return buf
+    end
+
+    it("reveals a virtual playful line only after one second", function()
+        local buf = new_scratch()
+        local runtime = new_runtime()
+        start_fake(buf, runtime)
+
+        assert.is_nil(extmark(buf))
+        runtime:advance(999)
+        runtime:drain()
+        assert.is_nil(extmark(buf))
+        runtime:advance(1)
+        assert.is_nil(extmark(buf), "timer callbacks must not touch UI before enqueue drains")
+        runtime:drain()
+
+        local text, mark = virtual_text(buf)
+        assert.equals("⠙ brewing", text)
+        assert.equals(0, mark[2])
+        assert.is_false(mark[4].virt_lines_above)
+        assert.is_true(mark[4].invalidate)
+        assert.same({ "assistant:" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
+    end)
+
+    it("rearms a one-shot timer delivered before its reducer deadline", function()
+        local buf = new_scratch()
+        local runtime = new_runtime()
+        start_fake(buf, runtime)
+
+        runtime:fire_earliest_timer_early()
+        runtime:drain()
+        assert.is_nil(extmark(buf))
+        assert.is_truthy(runtime:open_timer_count() > 0)
+        runtime:advance(999)
+        runtime:drain()
+        assert.is_nil(extmark(buf))
+        runtime:advance(1)
+        runtime:drain()
+        assert.equals("⠙ brewing", virtual_text(buf))
+    end)
+
+    it("animates only the glyph and rotates verbs on activity and idle", function()
+        local buf = new_scratch()
+        local runtime = new_runtime()
+        local choices = { 1, 2, 3 }
+        local choice = 0
+        local session = start_fake(buf, runtime, {
+            choose_verb_index = function()
+                choice = choice + 1
+                return choices[choice] or 1
+            end,
+        })
+        runtime:advance(1000)
+        runtime:drain()
+        local first = virtual_text(buf)
+        assert.equals("⠙ brewing", first)
+
+        runtime:advance(120)
+        runtime:drain()
+        local framed = virtual_text(buf)
+        assert.matches("^⠹ brewing$", framed)
+
+        session:activity("q")
+        assert.equals(framed, virtual_text(buf))
+        runtime:drain()
+        local active = virtual_text(buf)
+        assert.matches("^⠹ cooking$", active)
+
+        runtime:advance(14999)
+        runtime:drain()
+        assert.matches(" cooking$", virtual_text(buf))
+        runtime:advance(1)
+        runtime:drain()
+        assert.matches(" dragon%-slaying$", virtual_text(buf))
+    end)
+
+    it("stages content until the minimum and flushes it in FIFO order", function()
+        local buf = new_scratch()
+        local runtime = new_runtime()
+        local session, emitted = start_fake(buf, runtime)
+        runtime:advance(1000)
+        runtime:drain()
+
+        session:content("q", "one")
+        session:content("q", "two")
+        runtime:drain()
+        assert.same({}, emitted)
+        assert.is_truthy(extmark(buf))
+
+        runtime:advance(1000)
+        runtime:drain()
+        assert.same({ { "q", "one" }, { "q", "two" } }, emitted)
+        assert.is_nil(extmark(buf))
+    end)
+
+    it("cancels every playful timer when fast content releases waiting", function()
+        local buf = new_scratch()
+        local runtime = new_runtime()
+        local session, emitted = start_fake(buf, runtime)
+
+        runtime:advance(500)
+        session:content("q", "fast")
+        runtime:drain()
+        assert.same({ { "q", "fast" } }, emitted)
+        assert.is_nil(extmark(buf))
+        assert.equals(0, runtime:open_timer_count())
+
+        runtime:advance(15000)
+        runtime:drain()
+        assert.is_nil(extmark(buf))
+        assert.equals(0, runtime:open_timer_count())
+    end)
+
+    it("keeps fast semantic status but cancels every playful timer", function()
+        local buf = new_scratch()
+        local runtime = new_runtime()
+        local session = start_fake(buf, runtime)
+
+        runtime:advance(500)
+        session:progress("q", { message = "Reasoning" })
+        runtime:drain()
+        assert.equals("Reasoning", virtual_text(buf))
+        assert.equals(0, runtime:open_timer_count())
+
+        runtime:advance(15000)
+        runtime:drain()
+        assert.equals("Reasoning", virtual_text(buf))
+        assert.equals(0, runtime:open_timer_count())
+    end)
+
+    it("renders semantic status in the same extmark while content streams", function()
+        local buf = new_scratch()
+        local runtime = new_runtime()
+        local session, emitted = start_fake(buf, runtime)
+        runtime:advance(1000)
+        runtime:drain()
+        local playful_mark = extmark(buf)[1]
+
+        session:progress("q", { message = "Searching files" })
+        runtime:drain()
+        runtime:advance(1000)
+        runtime:drain()
+        local status, mark = virtual_text(buf)
+        assert.equals("Searching files", status)
+        assert.equals(playful_mark, mark[1])
+
+        session:content("q", "answer")
+        runtime:drain()
+        assert.same({ { "q", "answer" } }, emitted)
+        assert.equals("Searching files", virtual_text(buf))
+        session:activity("q")
+        runtime:drain()
+        assert.equals(0, runtime:open_timer_count(), "released sessions do not restart playful timers")
+        local mark_at_completion = true
+        session:complete("q", function() mark_at_completion = extmark(buf) end)
+        runtime:drain()
+        assert.is_nil(mark_at_completion, "status is hidden before the completion continuation")
+    end)
+
+    it("hides without changing real lines or the undo sequence", function()
+        local buf = new_scratch()
+        local runtime = new_runtime()
+        local session = start_fake(buf, runtime)
+        local before_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
+        local before_undo = vim.fn.undotree().seq_cur
+        runtime:advance(1000)
+        runtime:drain()
+        session:cancel("user")
+        runtime:drain()
+
+        assert.is_nil(extmark(buf))
+        assert.same(before_lines, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
+        assert.equals(before_undo, vim.fn.undotree().seq_cur)
+        assert.equals(0, runtime:open_timer_count())
+    end)
+
+    it("completes after the minimum and invokes the continuation once", function()
+        local buf = new_scratch()
+        local runtime = new_runtime()
+        local session = start_fake(buf, runtime)
+        runtime:advance(1000)
+        runtime:drain()
+        local completions = 0
+        local continuation = function() completions = completions + 1 end
+
+        session:complete("q", continuation)
+        session:complete("q", continuation)
+        runtime:drain()
+        assert.equals(0, completions)
+        runtime:advance(1000)
+        runtime:drain()
+        assert.equals(1, completions)
+        assert.equals(0, runtime:open_timer_count())
+    end)
+
+    it("contains emitter failures without logging callback data", function()
+        local buf = new_scratch()
+        local runtime = new_runtime()
+        local emitted = {}
+        local session = chat_pending.start({
+            buf = buf,
+            anchor_line = 0,
+            lease_valid = function() return true end,
+            emit_content = function(_qid, chunk)
+                if chunk == "private chunk" then
+                    error("private thrown secret")
+                end
+                table.insert(emitted, chunk)
+            end,
+            choose_verb_index = function() return 1 end,
+            clock = runtime.clock,
+            scheduler = runtime.scheduler,
+        })
+        runtime:drain()
+        runtime:advance(1000)
+        runtime:drain()
+        session:content("q", "private chunk")
+        session:content("q", "public tail")
+        local completed = 0
+        session:complete("q", function() completed = completed + 1 end)
+        runtime:drain()
+
+        local logs = {}
+        local original_error = logger.error
+        logger.error = function(message) table.insert(logs, message) end
+        runtime:advance(1000)
+        runtime:drain()
+        logger.error = original_error
+
+        assert.same({ "public tail" }, emitted)
+        assert.equals(1, completed)
+        assert.is_nil(extmark(buf))
+        assert.equals(0, runtime:open_timer_count())
+        local combined = table.concat(logs, "\n")
+        assert.is_truthy(combined:find("chat pending content emitter callback failed", 1, true))
+        assert.is_nil(combined:find("private chunk", 1, true))
+        assert.is_nil(combined:find("private thrown secret", 1, true))
+    end)
+
+    it("surfaces owned failures after staged partial output", function()
+        local buf = new_scratch()
+        local runtime = new_runtime()
+        local session, emitted = start_fake(buf, runtime)
+        runtime:advance(1000)
+        runtime:drain()
+        session:content("q", "partial")
+        runtime:drain()
+        local surfaced = {}
+        session:failure("q", "broken", function(err) table.insert(surfaced, err) end)
+        runtime:drain()
+
+        assert.same({ { "q", "partial" } }, emitted)
+        assert.same({ "broken" }, surfaced)
+        assert.is_nil(extmark(buf))
+    end)
+
+    it("hides released semantic status before surfacing failure", function()
+        local buf = new_scratch()
+        local runtime = new_runtime()
+        local session = start_fake(buf, runtime)
+        session:progress("q", { message = "Remote tool running" })
+        runtime:drain()
+        assert.equals("Remote tool running", virtual_text(buf))
+        local mark_at_failure = true
+        session:failure("q", "broken", function() mark_at_failure = extmark(buf) end)
+        runtime:drain()
+        assert.is_nil(mark_at_failure)
+    end)
+
+    it("cancels stale leases and deleted buffers with every timer", function()
+        local buf = new_scratch()
+        local runtime = new_runtime()
+        local valid = true
+        local session, emitted = start_fake(buf, runtime, {
+            lease_valid = function() return valid end,
+        })
+        valid = false
+        session:content("q", "discard")
+        runtime:drain()
+        assert.same({}, emitted)
+        assert.equals(0, runtime:open_timer_count())
+
+        local second_buf = new_scratch()
+        local second_runtime = new_runtime()
+        start_fake(second_buf, second_runtime)
+        vim.api.nvim_buf_delete(second_buf, { force = true })
+        second_runtime:advance(1000)
+        second_runtime:drain()
+        assert.equals(0, second_runtime:open_timer_count())
+    end)
+
+    it("invokes discard hooks once for cancel, frame-stale, and buffer-invalid", function()
+        local cases = {
+            {
+                drive = function(session, _buf, runtime)
+                    session:cancel("user")
+                    session:cancel("again")
+                    runtime:drain()
+                end,
+                expected = "cancel",
+            },
+            {
+                drive = function(_session, _buf, runtime, set_valid)
+                    runtime:advance(1000)
+                    runtime:drain()
+                    set_valid(false)
+                    runtime:advance(120)
+                    runtime:drain()
+                end,
+                expected = "stale",
+            },
+            {
+                drive = function(_session, buf, runtime)
+                    vim.api.nvim_buf_delete(buf, { force = true })
+                    runtime:advance(1000)
+                    runtime:drain()
+                end,
+                expected = "invalid",
+            },
+        }
+        for _, case in ipairs(cases) do
+            local buf = new_scratch()
+            local runtime = new_runtime()
+            local valid = true
+            local calls = {}
+            local session = chat_pending.start({
+                buf = buf,
+                anchor_line = 0,
+                lease_valid = function() return valid end,
+                emit_content = function() end,
+                choose_verb_index = function() return 1 end,
+                on_discard = function(kind) table.insert(calls, kind) end,
+                clock = runtime.clock,
+                scheduler = runtime.scheduler,
+            })
+            runtime:drain()
+            assert.is_true(chat_pending.is_active(buf))
+            case.drive(session, buf, runtime, function(value) valid = value end)
+            assert.same({ case.expected }, calls)
+            assert.is_false(chat_pending.is_active(buf))
+        end
+    end)
+
+    it("releases ownership before a reentrant discard hook", function()
+        local buf = new_scratch()
+        local runtime = new_runtime()
+        local replacement
+        local session = chat_pending.start({
+            buf = buf,
+            anchor_line = 0,
+            lease_valid = function() return true end,
+            emit_content = function() end,
+            choose_verb_index = function() return 1 end,
+            on_discard = function()
+                replacement = start_fake(buf, runtime)
+            end,
+            clock = runtime.clock,
+            scheduler = runtime.scheduler,
+        })
+        runtime:drain()
+        session:cancel("replace")
+        runtime:drain()
+        assert.is_truthy(replacement)
+        assert.is_true(chat_pending.is_active(buf))
+    end)
+
+    it("contains and redacts throwing discard hooks", function()
+        local buf = new_scratch()
+        local runtime = new_runtime()
+        local logs = {}
+        local original_error = logger.error
+        logger.error = function(message) table.insert(logs, message) end
+        local session = chat_pending.start({
+            buf = buf,
+            anchor_line = 0,
+            lease_valid = function() return true end,
+            emit_content = function() end,
+            choose_verb_index = function() return 1 end,
+            on_discard = function() error("discarded private secret") end,
+            clock = runtime.clock,
+            scheduler = runtime.scheduler,
+        })
+        runtime:drain()
+        session:cancel("private cancel reason")
+        runtime:drain()
+        logger.error = original_error
+
+        assert.is_false(chat_pending.is_active(buf))
+        local combined = table.concat(logs, "\n")
+        assert.is_truthy(combined:find("chat pending discard terminal callback failed", 1, true))
+        assert.is_nil(combined:find("discarded private secret", 1, true))
+        assert.is_nil(combined:find("private cancel reason", 1, true))
+        assert.is_truthy(start_fake(buf, runtime))
+    end)
+
+    it("does not invoke discard hooks for completion or provider failure", function()
+        for _, terminal in ipairs({ "complete", "failure" }) do
+            local buf = new_scratch()
+            local runtime = new_runtime()
+            local discarded = 0
+            local session = chat_pending.start({
+                buf = buf,
+                anchor_line = 0,
+                lease_valid = function() return true end,
+                emit_content = function() end,
+                choose_verb_index = function() return 1 end,
+                on_discard = function() discarded = discarded + 1 end,
+                clock = runtime.clock,
+                scheduler = runtime.scheduler,
+            })
+            runtime:drain()
+            if terminal == "complete" then
+                session:complete("q", function() end)
+            else
+                session:failure("q", "provider", function() end)
+            end
+            runtime:drain()
+            assert.equals(0, discarded)
+            assert.is_false(chat_pending.is_active(buf))
+        end
+    end)
+
+    it("frame ticks terminate a shown session whose lease became stale", function()
+        local buf = new_scratch()
+        local runtime = new_runtime()
+        local valid = true
+        start_fake(buf, runtime, {
+            lease_valid = function() return valid end,
+        })
+        runtime:advance(1000)
+        runtime:drain()
+        runtime:advance(1000)
+        runtime:drain()
+        assert.is_truthy(extmark(buf))
+        assert.is_truthy(runtime:open_timer_count() > 0)
+
+        valid = false
+        runtime:advance(120)
+        runtime:drain()
+        assert.is_nil(extmark(buf))
+        assert.equals(0, runtime:open_timer_count())
+    end)
+
+    it("enforces one active session per buffer and cancel_all is idempotent", function()
+        local buf = new_scratch()
+        local runtime = new_runtime()
+        local session = start_fake(buf, runtime)
+        assert.has_error(function() start_fake(buf, runtime) end)
+        local recursive
+        session:complete("q", function() recursive = start_fake(buf, runtime) end)
+        runtime:drain()
+        assert.is_truthy(recursive, "a completion may install the recursive leg")
+        chat_pending.cancel_all("user")
+        chat_pending.cancel_all("user")
+        runtime:drain()
+        assert.equals(0, runtime:open_timer_count())
+
+        local replacement = start_fake(buf, runtime)
+        assert.is_truthy(replacement)
+    end)
+
+    it("does not publish sessions whose initializer fails", function()
+        for _, chooser in ipairs({
+            function() error("chooser failed") end,
+            function() return 99 end,
+        }) do
+            local buf = new_scratch()
+            local runtime = new_runtime()
+            assert.has_error(function()
+                chat_pending.start({
+                    buf = buf,
+                    anchor_line = 0,
+                    lease_valid = function() return true end,
+                    emit_content = function() end,
+                    choose_verb_index = chooser,
+                    clock = runtime.clock,
+                    scheduler = runtime.scheduler,
+                })
+            end)
+            local cancelled = pcall(chat_pending.cancel_all, "after failed initializer")
+            assert.is_true(cancelled)
+            assert.is_false(chat_pending.is_active(buf))
+            runtime:drain()
+
+            local retry = start_fake(buf, runtime)
+            assert.is_truthy(retry)
+            assert.is_true(chat_pending.is_active(buf))
+            retry:cancel("done")
+            runtime:drain()
+            assert.is_false(chat_pending.is_active(buf))
+        end
+    end)
+
+    it("uses the production scheduler to leave a real uv fast event", function()
+        local buf = new_scratch()
+        local session = chat_pending.start({
+            buf = buf,
+            anchor_line = 0,
+            lease_valid = function() return true end,
+            emit_content = function() end,
+            choose_verb_index = function() return 1 end,
+        })
+        local timer = uv.new_timer()
+        local source_was_fast = false
+        local callback_returned = false
+        timer:start(1, 0, function()
+            source_was_fast = vim.in_fast_event()
+            session:progress("q", { message = "Remote tool running" })
+            callback_returned = true
+            timer:stop()
+            timer:close()
+        end)
+        assert.is_true(vim.wait(1000, function() return callback_returned end, 5))
+        assert.is_true(source_was_fast)
+        assert.is_true(vim.wait(1000, function()
+            return virtual_text(buf) == "Remote tool running"
+        end, 5))
+        assert.is_false(vim.in_fast_event())
+        session:cancel("done")
+    end)
+end)
diff --git a/tests/integration/chat_progress_process_spec.lua b/tests/integration/chat_progress_process_spec.lua
new file mode 100644
index 0000000..d8219e9
--- /dev/null
+++ b/tests/integration/chat_progress_process_spec.lua
@@ -0,0 +1,233 @@
+local tmp_dir = vim.fn.tempname() .. "-parley-progress-process"
+vim.fn.mkdir(tmp_dir, "p")
+
+local parley = require("parley")
+parley.setup({
+    chat_dir = tmp_dir,
+    state_dir = tmp_dir .. "/state",
+    web_search = false,
+    default_agent = "ProcessFixture",
+    providers = {
+        openai = { endpoint = "http://127.0.0.1:1/v1/chat/completions" },
+    },
+    api_keys = { openai = "fixture-secret" },
+    agents = {
+        {
+            name = "ProcessFixture",
+            provider = "openai",
+            model = { model = "fixture-model" },
+            system_prompt = "Answer briefly.",
+        },
+    },
+})
+
+local fixture = vim.fn.getcwd() .. "/tests/fixtures/fake_sse_server"
+local uv = vim.uv or vim.loop
+local processes = {}
+
+local function start_server(mode)
+    local ready_file = tmp_dir .. "/ready-" .. mode .. "-" .. math.random(100000)
+    local exited = false
+    local handle
+    local env = {}
+    for name, value in pairs(vim.fn.environ()) do
+        table.insert(env, name .. "=" .. value)
+    end
+    table.insert(env, "PYTHONDONTWRITEBYTECODE=1")
+    handle = uv.spawn(fixture, { args = { mode, ready_file }, env = env }, function()
+        exited = true
+        if handle and not handle:is_closing() then
+            handle:close()
+        end
+    end)
+    assert.is_not_nil(handle)
+    table.insert(processes, { handle = handle, exited = function() return exited end })
+    assert.is_true(vim.wait(1000, function() return vim.fn.filereadable(ready_file) == 1 end, 10))
+    local port = tonumber(vim.fn.readfile(ready_file)[1])
+    vim.fn.delete(ready_file)
+    return port
+end
+
+local function open_chat(mode)
+    local path = tmp_dir .. "/2026-07-13-process-" .. mode .. "-" .. math.random(100000) .. ".md"
+    vim.fn.writefile({
+        "# topic: Fixture",
+        "- file: fixture.md",
+        "---",
+        "",
+        "💬: test the process boundary",
+    }, path)
+    vim.cmd("edit " .. vim.fn.fnameescape(path))
+    vim.api.nvim_win_set_cursor(0, { 5, 0 })
+    return vim.api.nvim_get_current_buf()
+end
+
+local function text(buf)
+    if not vim.api.nvim_buf_is_valid(buf) then return "" end
+    return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
+end
+
+local function pending_marks(buf)
+    local ns = vim.api.nvim_get_namespaces().parley_chat_pending
+    if not ns or not vim.api.nvim_buf_is_valid(buf) then return {} end
+    return vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
+end
+
+describe("chat progress real curl process", function()
+    local original_notify
+    local original_pending_start
+    local original_get_secret
+    local original_is_busy
+    local original_spawn
+    local notices
+    local activity_count
+
+    before_each(function()
+        notices = {}
+        activity_count = 0
+        original_notify = vim.notify
+        original_pending_start = require("parley.chat_pending").start
+        original_get_secret = parley.vault.get_secret
+        original_is_busy = parley.tasker.is_busy
+        original_spawn = (vim.uv or vim.loop).spawn
+        require("parley.chat_pending").start = function(opts)
+            local session = original_pending_start(opts)
+            local activity = session.activity
+            session.activity = function(self, ...)
+                activity_count = activity_count + 1
+                return activity(self, ...)
+            end
+            return session
+        end
+        vim.notify = function(message, level)
+            table.insert(notices, { message = tostring(message), level = level,
+                buffer_text = text(vim.api.nvim_get_current_buf()),
+                pending_count = #pending_marks(vim.api.nvim_get_current_buf()) })
+        end
+    end)
+
+    after_each(function()
+        vim.notify = original_notify
+        require("parley.chat_pending").start = original_pending_start
+        parley.vault.get_secret = original_get_secret
+        parley.tasker.is_busy = original_is_busy
+        uv.spawn = original_spawn
+        require("parley.chat_pending").cancel_all("test teardown")
+        parley.tasker.stop()
+        for _, process in ipairs(processes) do
+            if not process.exited() and process.handle and not process.handle:is_closing() then
+                pcall(process.handle.kill, process.handle, "sigterm")
+            end
+        end
+        local reaped = vim.wait(500, function()
+            for _, process in ipairs(processes) do
+                if not process.exited() then return false end
+            end
+            return true
+        end, 10)
+        if not reaped then
+            for _, process in ipairs(processes) do
+                if not process.exited() and process.handle and not process.handle:is_closing() then
+                    pcall(process.handle.kill, process.handle, "sigkill")
+                end
+            end
+            reaped = vim.wait(500, function()
+                for _, process in ipairs(processes) do
+                    if not process.exited() then return false end
+                end
+                return true
+            end, 10)
+        end
+        assert.is_true(reaped, "fake SSE server must be reaped")
+        processes = {}
+        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
+            if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "" then
+                pcall(vim.api.nvim_buf_delete, buf, { force = true })
+            end
+        end
+    end)
+
+    local function run(mode)
+        local port = start_server(mode)
+        parley.dispatcher.providers.openai.endpoint = "http://127.0.0.1:" .. port .. "/v1/chat/completions"
+        local buf = open_chat(mode)
+        parley.chat_respond({ range = 0 })
+        return buf
+    end
+
+    it("stages a delayed SSE answer behind the minimum-visible playful line", function()
+        local buf = run("delayed")
+        assert.is_true(vim.wait(1050, function() return #pending_marks(buf) == 1 end, 10))
+        assert.is_false(text(buf):find("partial answer", 1, true) ~= nil)
+        assert.is_true(vim.wait(3000, function()
+            return text(buf):find("partial answer", 1, true) ~= nil and #pending_marks(buf) == 0
+        end, 10), vim.inspect({ text = text(buf), notices = notices, marks = pending_marks(buf),
+            query = parley.tasker.get_active_query_by_buf(buf) }))
+        for _, notice in ipairs(notices) do
+            assert.is_true(notice.message:find("provider request failed", 1, true) == nil)
+        end
+        assert.equals(2, activity_count, "only the two stdout SSE records count as activity")
+    end)
+
+    for _, case in ipairs({
+        { mode = "broken", expected = "exit" },
+        { mode = "unauthorized", expected = "HTTP 401" },
+        { mode = "http500", expected = "HTTP 500" },
+    }) do
+        it("orders partial output before the " .. case.mode .. " provider failure", function()
+            local buf = run(case.mode)
+            local notice
+            assert.is_true(vim.wait(2000, function()
+                for _, candidate in ipairs(notices) do
+                    if candidate.message:find("provider request failed", 1, true) then
+                        notice = candidate
+                        return true
+                    end
+                end
+                return false
+            end, 10), vim.inspect(notices))
+            assert.is_true(notice.message:find(case.expected, 1, true) ~= nil, notice.message)
+            assert.equals(0, notice.pending_count, "failure notification must observe the extmark already hidden")
+            assert.equals(0, #pending_marks(buf))
+            if case.mode ~= "unauthorized" then
+                assert.is_true(notice.buffer_text:find("partial answer", 1, true) ~= nil,
+                    "partial output must be visible before failure notification")
+            end
+            assert.is_true(notice.buffer_text:find("__PARLEY_HTTP_", 1, true) == nil)
+        end)
+    end
+
+    local function assert_prestart_cleanup(expected_message)
+        local buf = open_chat("prestart")
+        parley.chat_respond({ range = 0 }, nil, nil, true)
+        local matching = 0
+        assert.is_true(vim.wait(1000, function()
+            matching = 0
+            for _, notice in ipairs(notices) do
+                if notice.level == vim.log.levels.WARN
+                        and notice.message:find(expected_message, 1, true) then
+                    matching = matching + 1
+                end
+            end
+            return matching > 0 and #pending_marks(buf) == 0
+        end, 10), vim.inspect(notices))
+        assert.equals(1, matching)
+        assert.equals(0, #pending_marks(buf))
+        assert.is_true(text(buf):find("brewing", 1, true) == nil)
+    end
+
+    it("cleans one real chat session when the provider secret is missing", function()
+        parley.vault.get_secret = function() return nil end
+        assert_prestart_cleanup("bearer token is missing")
+    end)
+
+    it("cleans one real chat session when task launch is rejected as busy", function()
+        parley.tasker.is_busy = function() return true end
+        assert_prestart_cleanup("buffer is busy")
+    end)
+
+    it("cleans one real chat session when curl spawn is rejected", function()
+        uv.spawn = function() return nil, "fixture spawn rejection" end
+        assert_prestart_cleanup("fixture spawn rejection")
+    end)
+end)
diff --git a/tests/integration/chat_respond_spec.lua b/tests/integration/chat_respond_spec.lua
index 190fc28..b8f2c4c 100644
--- a/tests/integration/chat_respond_spec.lua
+++ b/tests/integration/chat_respond_spec.lua
@@ -7,6 +7,7 @@ local tmp_dir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-chat-res

 -- Bootstrap parley
 local parley = require("parley")
+local canonical_pending_start = require("parley.chat_pending").start
 parley.setup({
     chat_dir = tmp_dir,
     state_dir = tmp_dir .. "/state",
@@ -47,9 +48,50 @@ local function buffer_contains(buf, needle)
     return text:find(needle, 1, true) ~= nil
 end

+local function pending_virtual_text(buf)
+    local ns = vim.api.nvim_get_namespaces().parley_chat_pending
+    if not ns then return nil end
+    local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
+    local chunks = marks[1] and marks[1][4] and marks[1][4].virt_lines
+    return chunks and chunks[1] and chunks[1][1] and chunks[1][1][1] or nil
+end
+
+local function pending_runtime()
+    local runtime = { now = 0, queue = {}, timers = {} }
+    runtime.clock = { now_ms = function() return runtime.now end }
+    runtime.scheduler = {
+        enqueue = function(callback) table.insert(runtime.queue, callback) end,
+    }
+    local function timer(delay, repeating, callback)
+        local item = { due = runtime.now + delay, repeating = repeating, delay = delay,
+            callback = callback, closed = false }
+        table.insert(runtime.timers, item)
+        return function() item.closed = true end
+    end
+    runtime.scheduler.after = function(delay, callback) return timer(delay, false, callback) end
+    runtime.scheduler.every = function(delay, callback) return timer(delay, true, callback) end
+    function runtime:fire_due()
+        for _, item in ipairs(self.timers) do
+            if not item.closed and item.due <= self.now then
+                if item.repeating then item.due = item.due + item.delay else item.closed = true end
+                item.callback()
+            end
+        end
+    end
+    function runtime:advance(milliseconds)
+        self.now = self.now + milliseconds
+        self:fire_due()
+    end
+    function runtime:drain()
+        while #self.queue > 0 do table.remove(self.queue, 1)() end
+    end
+    return runtime
+end
+
 describe("chat_respond: completion callback", function()
     local test_file
     local original_query
+    local original_pending_start

     before_each(function()
         -- Create a unique test file with valid timestamp format
@@ -57,6 +99,7 @@ describe("chat_respond: completion callback", function()

         -- Save original dispatcher.query
         original_query = parley.dispatcher.query
+        original_pending_start = canonical_pending_start
     end)

     after_each(function()
@@ -64,6 +107,7 @@ describe("chat_respond: completion callback", function()
         if original_query then
             parley.dispatcher.query = original_query
         end
+        require("parley.chat_pending").start = original_pending_start

         -- Clean up test file
         if test_file and vim.fn.filereadable(test_file) == 1 then
@@ -122,7 +166,7 @@ describe("chat_respond: completion callback", function()
         end)

         -- Wait a bit for scheduled callback to execute
-        vim.wait(100, function() return completion_called end, 10)
+        vim.wait(200, function() return completion_called end, 10)

         -- Assert no error during the call or in the callback
         assert.is_true(success, "chat_respond should not error: " .. tostring(err))
@@ -177,7 +221,7 @@ describe("chat_respond: completion callback", function()
         end)

         -- Wait for callback
-        vim.wait(100, function() return completion_called end, 10)
+        vim.wait(200, function() return completion_called and finalize_count == 1 end, 10)
         lifecycle.finalize_mutated_api_leg = original_finalize

         -- Assert no error
@@ -377,7 +421,9 @@ describe("chat_respond: buffer state after completion", function()
         end

         parley.chat_respond({range = 0})
-        vim.wait(200, function() return completion_called end, 10)
+        vim.wait(300, function()
+            return completion_called and buffer_contains(buf, "Release notes summary")
+        end, 10)

         local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
         local has_new_prompt = false
@@ -652,7 +698,7 @@ describe("chat_respond: buffer state after completion", function()
         assert.equals(2, user_prompt_count, "Should not append new user prompt in middle of document")
     end)

-    it("keeps web-search progress visible while response streams and clears it on completion", function()
+    it("streams answer content arriving before reveal without playful UI", function()
         local chat_content = [[
 # topic: Test Topic
 - file: test.md
@@ -666,95 +712,40 @@ describe("chat_respond: buffer state after completion", function()
         local buf = vim.api.nvim_get_current_buf()
         vim.api.nvim_win_set_cursor(0, {6, 0})

-        local original_web_search = parley._state.web_search
-        parley._state.web_search = true
-
         local completion_called = false
-        local saw_initial_indicator = false
-        parley.dispatcher.query = function(buf_arg, provider, payload, handler, completion_callback, _callback, progress_callback)
-            local mock_qid = "qid_web_progress"
+        parley.dispatcher.query = function(buf_arg, provider, payload, handler, completion_callback)
+            local mock_qid = "qid_fast_answer"
             parley.tasker.set_query(mock_qid, {
                 response = "Release notes summary",
                 buf = buf_arg
             })
-
-            local before_lines = vim.api.nvim_buf_get_lines(buf_arg, 0, -1, false)
-            for _, line in ipairs(before_lines) do
-                if line:match("^🔎 %S+ Submitting%.%.%.$") then
-                    saw_initial_indicator = true
-                    break
-                end
-            end
-
-            if progress_callback then
-                progress_callback(mock_qid, { message = "Searching web..." })
-            end
             if handler then
                 handler(mock_qid, "Release notes summary")
             end
-
-            vim.defer_fn(function()
-                vim.schedule(function()
-                    completion_callback(mock_qid)
-                    completion_called = true
-                end)
-            end, 500)
+            completion_callback(mock_qid)
+            completion_called = true
         end

         parley.chat_respond({ range = 0 })
-
         vim.wait(300, function()
-            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
-            local has_progress_line = false
-            local has_answer_text = false
-            for _, line in ipairs(lines) do
-                if line:match("^🔎 %S+ ") then
-                    has_progress_line = true
-                end
-                if line:find("Release notes summary", 1, true) then
-                    has_answer_text = true
-                end
-            end
-            return has_progress_line and has_answer_text
+            return completion_called and buffer_contains(buf, "Release notes summary")
         end, 10)

-        local active_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
-        local has_active_progress_line = false
-        local has_active_answer_text = false
-        for _, line in ipairs(active_lines) do
-            if line:match("^🔎 %S+ ") then
-                has_active_progress_line = true
-            end
-            if line:find("Release notes summary", 1, true) then
-                has_active_answer_text = true
-            end
-        end
-
-        vim.wait(700, function()
-            return completion_called
-        end, 10)
-
-        parley._state.web_search = original_web_search
-
-        assert.is_true(saw_initial_indicator, "Expected initial submitting progress indicator to be present")
-        assert.is_true(has_active_progress_line, "Progress indicator should remain visible while response text streams")
-        assert.is_true(has_active_answer_text, "Expected streamed answer text to be present before completion")
+        local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
+        local ns = vim.api.nvim_get_namespaces().parley_chat_pending
+        local marks = ns and vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true }) or {}
+        assert.is_true(text:find("Release notes summary", 1, true) ~= nil)
+        assert.is_true(text:find("Submitting...", 1, true) == nil)
+        assert.equals(0, #marks)
         local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
-        local has_progress_line = false
-        local has_answer_text = false
-        for _, line in ipairs(lines) do
-            if line:match("^🔎 %S+ ") then
-                has_progress_line = true
-            end
-            if line:find("Release notes summary", 1, true) then
-                has_answer_text = true
-            end
+        local parsed = parley.parse_chat(lines, 3)
+        local model = require("parley.exchange_model").from_parsed_chat(parsed)
+        for _, block in ipairs(model.exchanges[1].blocks) do
+            assert.is_not.equals("spinner", block.kind)
         end
-        assert.is_false(has_progress_line, "Progress indicator should be cleared after response completes")
-        assert.is_true(has_answer_text, "Expected streamed answer text to be present")
     end)

-    it("keeps late tool progress visible when it arrives after answer text", function()
+    it("shows a virtual playful line after one second and stages content for its minimum", function()
         local chat_content = [[
 # topic: Test Topic
 - file: test.md
@@ -768,166 +759,199 @@ describe("chat_respond: buffer state after completion", function()
         local buf = vim.api.nvim_get_current_buf()
         vim.api.nvim_win_set_cursor(0, {6, 0})

-        local original_web_search = parley._state.web_search
-        parley._state.web_search = true
-
         local completion_called = false
-        parley.dispatcher.query = function(buf_arg, provider, payload, handler, completion_callback, _callback, progress_callback)
-            local mock_qid = "qid_web_progress_late_tool"
+        parley.dispatcher.query = function(buf_arg, provider, payload, handler, completion_callback)
+            local mock_qid = "qid_slow_answer"
             parley.tasker.set_query(mock_qid, {
                 response = "Release notes summary",
                 buf = buf_arg
             })
-
-            if handler then
-                handler(mock_qid, "Release notes summary")
-            end
-
-            vim.defer_fn(function()
-                vim.schedule(function()
-                    if progress_callback then
-                        progress_callback(mock_qid, {
-                            message = "Searching web...",
-                            text = "latest neovim release notes",
-                        })
-                    end
-                end)
-            end, 30)
-
             vim.defer_fn(function()
-                vim.schedule(function()
-                    completion_callback(mock_qid)
-                    completion_called = true
-                end)
-            end, 500)
+                handler(mock_qid, "Release notes summary")
+                completion_callback(mock_qid)
+                completion_called = true
+            end, 1100)
         end

         parley.chat_respond({ range = 0 })
+        local ns = vim.api.nvim_get_namespaces().parley_chat_pending
+        assert.is_true(vim.wait(1050, function()
+            return ns and #vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true }) == 1
+        end, 10))
+        assert.is_true(vim.wait(300, function() return completion_called end, 10))
+        assert.is_false(buffer_contains(buf, "Release notes summary"),
+            "content received during minimum must stay staged")
+        assert.is_true(vim.wait(1300, function()
+            return buffer_contains(buf, "Release notes summary")
+        end, 10))
+        assert.equals(0, #vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true }))
+    end)

-        local saw_late_progress_with_answer = vim.wait(300, function()
-            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
-            local has_progress_line = false
-            local has_answer_text = false
-            for _, line in ipairs(lines) do
-                if line:find("Searching web... latest neovim release notes", 1, true) then
-                    has_progress_line = true
-                end
-                if line:find("Release notes summary", 1, true) then
-                    has_answer_text = true
-                end
-            end
-            return has_progress_line and has_answer_text
-        end, 10)
-
-        vim.wait(700, function()
-            return completion_called
-        end, 10)
-
-        parley._state.web_search = original_web_search
-
-        assert.is_true(saw_late_progress_with_answer, "Late tool progress should remain visible even after answer text starts")
+    it("lets same-deadline content beat reveal exactly once through M.respond", function()
+        local chat_content = [[
+# topic: Boundary
+- file: test.md
+---

-        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
-        local has_progress_line = false
-        local has_answer_text = false
-        for _, line in ipairs(lines) do
-            if line:find("Searching web...", 1, true) then
-                has_progress_line = true
-            end
-            if line:find("Release notes summary", 1, true) then
-                has_answer_text = true
-            end
+💬: boundary
+]]
+        vim.fn.writefile(vim.split(chat_content, "\n"), test_file)
+        vim.cmd("edit " .. test_file)
+        local buf = vim.api.nvim_get_current_buf()
+        vim.api.nvim_win_set_cursor(0, { 6, 0 })
+        local runtime = pending_runtime()
+        require("parley.chat_pending").start = function(opts)
+            opts.clock, opts.scheduler = runtime.clock, runtime.scheduler
+            return canonical_pending_start(opts)
+        end
+        local handler, complete
+        local callback_count = 0
+        parley.dispatcher.query = function(buf_arg, _provider, _payload, content, on_exit)
+            handler, complete = content, on_exit
+            parley.tasker.set_query("qid_boundary_content", {
+                response = "boundary answer", raw_response = "", buf = buf_arg,
+            })
         end
-        assert.is_false(has_progress_line, "Late tool progress indicator should clear on completion")
-        assert.is_true(has_answer_text, "Expected streamed answer text to remain after completion")
+        parley.chat_respond({ range = 0 }, function() callback_count = callback_count + 1 end)
+        runtime:drain()
+        runtime.now = 1000
+        handler("qid_boundary_content", "boundary answer")
+        runtime:fire_due()
+        complete("qid_boundary_content")
+        runtime:drain()
+
+        assert.is_nil(pending_virtual_text(buf))
+        assert.is_true(vim.wait(300, function()
+            return buffer_contains(buf, "boundary answer") and callback_count == 1
+        end, 10))
+        assert.equals(1, callback_count)
     end)

-    it("animates spinner locally while waiting without SSE events", function()
+    it("lets same-deadline reveal stage content and releases one continuation at minimum", function()
         local chat_content = [[
-# topic: Test Topic
+# topic: Boundary
 - file: test.md
 ---

-💬: Search for docs.
+💬: boundary
 ]]
-
         vim.fn.writefile(vim.split(chat_content, "\n"), test_file)
         vim.cmd("edit " .. test_file)
         local buf = vim.api.nvim_get_current_buf()
-        vim.api.nvim_win_set_cursor(0, {6, 0})
-
-        local original_web_search = parley._state.web_search
-        parley._state.web_search = true
-
-        local completion_called = false
-        parley.dispatcher.query = function(buf_arg, provider, payload, handler, completion_callback)
-            local mock_qid = "qid_spinner_wait"
-            parley.tasker.set_query(mock_qid, {
-                response = "",
-                buf = buf_arg
+        vim.api.nvim_win_set_cursor(0, { 6, 0 })
+        local runtime = pending_runtime()
+        require("parley.chat_pending").start = function(opts)
+            opts.clock, opts.scheduler = runtime.clock, runtime.scheduler
+            return canonical_pending_start(opts)
+        end
+        local handler, complete
+        local callback_count = 0
+        parley.dispatcher.query = function(buf_arg, _provider, _payload, content, on_exit)
+            handler, complete = content, on_exit
+            parley.tasker.set_query("qid_boundary_reveal", {
+                response = "staged boundary", raw_response = "", buf = buf_arg,
             })
-            vim.defer_fn(function()
-                vim.schedule(function()
-                    completion_callback(mock_qid)
-                    completion_called = true
-                end)
-            end, 260)
         end
+        parley.chat_respond({ range = 0 }, function() callback_count = callback_count + 1 end)
+        runtime:drain()
+        runtime:advance(1000)
+        handler("qid_boundary_reveal", "staged boundary")
+        complete("qid_boundary_reveal")
+        runtime:drain()
+        assert.is_not_nil(pending_virtual_text(buf))
+        assert.is_false(buffer_contains(buf, "staged boundary"))
+        assert.equals(0, callback_count)
+
+        runtime:advance(1000)
+        runtime:drain()
+        assert.is_true(vim.wait(300, function()
+            return buffer_contains(buf, "staged boundary") and callback_count == 1
+        end, 10))
+        assert.is_nil(pending_virtual_text(buf))
+        assert.equals(1, callback_count)
+    end)

-        parley.chat_respond({ range = 0 })
-
-        vim.wait(120, function()
-            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
-            for _, line in ipairs(lines) do
-                if line:match("^🔎 %S+ Submitting%.%.%.$") then
-                    return true
-                end
-            end
-            return false
-        end, 10)
+    it("keeps meaningful remote status visible after release until completion", function()
+        local chat_content = [[
+# topic: Test Topic
+- file: test.md
+---

-        local first_spinner_line = nil
-        for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
-            if line:match("^🔎 %S+ Submitting%.%.%.$") then
-                first_spinner_line = line
-                break
-            end
+💬: Find latest release notes.
+]]
+        vim.fn.writefile(vim.split(chat_content, "\n"), test_file)
+        vim.cmd("edit " .. test_file)
+        local buf = vim.api.nvim_get_current_buf()
+        vim.api.nvim_win_set_cursor(0, { 6, 0 })
+        local finish
+        local runtime = pending_runtime()
+        require("parley.chat_pending").start = function(opts)
+            opts.clock, opts.scheduler = runtime.clock, runtime.scheduler
+            return canonical_pending_start(opts)
         end
-        assert.is_not_nil(first_spinner_line, "Expected spinner line while waiting")

-        vim.wait(140, function()
-            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
-            for _, line in ipairs(lines) do
-                if line:match("^🔎 %S+ Submitting%.%.%.$") and line ~= first_spinner_line then
-                    return true
-                end
-            end
-            return false
-        end, 10)
-
-        local spinner_changed = false
-        for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
-            if line:match("^🔎 %S+ Submitting%.%.%.$") and line ~= first_spinner_line then
-                spinner_changed = true
-                break
-            end
+        parley.dispatcher.query = function(buf_arg, _provider, _payload, handler, completion_callback,
+                _callback, progress_callback)
+            local qid = "qid_remote_status"
+            parley.tasker.set_query(qid, { response = "answer", raw_response = "", buf = buf_arg })
+            handler(qid, "answer")
+            progress_callback(qid, { message = "Searching web...", text = "release notes" })
+            finish = function() completion_callback(qid) end
         end
-        assert.is_true(spinner_changed, "Expected spinner frame to advance locally")

-        vim.wait(500, function()
-            return completion_called
-        end, 10)
+        parley.chat_respond({ range = 0 })
+        runtime:drain()
+        assert.is_true(vim.wait(1000, function()
+            return buffer_contains(buf, "answer")
+                and pending_virtual_text(buf) == "Searching web... release notes"
+        end, 10), vim.inspect({ text = pending_virtual_text(buf), lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false) }))
+        finish()
+        runtime:drain()
+        assert.is_true(vim.wait(300, function() return pending_virtual_text(buf) == nil end, 10))
+    end)

-        parley._state.web_search = original_web_search
+    it("keeps topic-generation fallback outside playful chat sessions", function()
+        local chat_content = [[
+# topic: ?
+- file: test.md
+---

-        local has_spinner = false
-        for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
-            if line:find("Submitting...", 1, true) then
-                has_spinner = true
-                break
+💬: Name this chat.
+]]
+        vim.fn.writefile(vim.split(chat_content, "\n"), test_file)
+        vim.cmd("edit " .. test_file)
+        local buf = vim.api.nvim_get_current_buf()
+        vim.api.nvim_win_set_cursor(0, { 6, 0 })
+        local pending = require("parley.chat_pending")
+        local starts = 0
+        pending.start = function(opts)
+            starts = starts + 1
+            return canonical_pending_start(opts)
+        end
+        local query_count = 0
+        parley.dispatcher.query = function(buf_arg, _provider, _payload, handler, on_exit)
+            query_count = query_count + 1
+            local qid = "qid_topic_" .. query_count
+            if query_count == 1 then
+                parley.tasker.set_query(qid, { response = "answer", raw_response = "", buf = buf_arg })
+                handler(qid, "answer")
+                on_exit(qid)
+            else
+                parley.tasker.set_query(qid, { response = "Fixture Topic", raw_response = "", buf = buf_arg })
+                handler(qid, "Fixture Topic")
+                -- This is the legacy completion surface dispatcher uses after
+                -- an unopted topic transport failure as well as normal exit.
+                on_exit(qid)
             end
         end
-        assert.is_false(has_spinner, "Spinner line should clear on completion")
+
+        parley.chat_respond({ range = 0 })
+        assert.is_true(vim.wait(500, function()
+            return query_count == 2 and (vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or "")
+                :find("Fixture Topic", 1, true) ~= nil
+        end, 10))
+        assert.equals(1, starts, "topic generation must not create a playful session")
+        assert.is_nil(pending_virtual_text(buf))
     end)
 end)

@@ -940,6 +964,21 @@ describe("chat_respond: guard branches", function()
         original_query = parley.dispatcher.query
     end)

+    it("cancels pending presentation before stopping task processes", function()
+        local pending = require("parley.chat_pending")
+        local original_cancel_all = pending.cancel_all
+        local original_stop = parley.tasker.stop
+        local observed = {}
+        pending.cancel_all = function(reason) table.insert(observed, "cancel:" .. reason) end
+        parley.tasker.stop = function() table.insert(observed, "stop") end
+
+        parley.cmd.Stop()
+
+        pending.cancel_all = original_cancel_all
+        parley.tasker.stop = original_stop
+        assert.same({ "cancel:user", "stop" }, observed)
+    end)
+
     after_each(function()
         if original_query then
             parley.dispatcher.query = original_query
@@ -979,6 +1018,9 @@ describe("chat_respond: guard branches", function()
         parley.tasker.is_busy = function() return true end

         local dispatcher_called = false
+        local warning
+        local original_warning = parley.logger.warning
+        parley.logger.warning = function(message) warning = message end
         parley.dispatcher.query = function(...)
             dispatcher_called = true
         end
@@ -992,7 +1034,9 @@ describe("chat_respond: guard branches", function()

         -- Restore
         parley.tasker.is_busy = original_is_busy
+        parley.logger.warning = original_warning
         lifecycle.finalize_mutated_api_leg = original_finalize
+        assert.equals("A Parley process is already running. Stop it before resubmitting.", warning)
     end)

     it("returns early without calling dispatcher for non-chat file", function()
@@ -1048,6 +1092,7 @@ describe("chat_respond: pending request transcript drift", function()
     local original_web_search
     local original_schedule
     local original_new_timer
+    local original_pending_start
     local scratch_file

     before_each(function()
@@ -1059,6 +1104,7 @@ describe("chat_respond: pending request transcript drift", function()
         original_web_search = parley._state.web_search
         original_schedule = vim.schedule
         original_new_timer = vim.uv.new_timer
+        original_pending_start = canonical_pending_start
     end)

     after_each(function()
@@ -1071,6 +1117,7 @@ describe("chat_respond: pending request transcript drift", function()
         if original_new_timer then
             vim.uv.new_timer = original_new_timer
         end
+        require("parley.chat_pending").start = original_pending_start
         parley._state.agent = original_agent
         parley._state.web_search = original_web_search
         if test_file and vim.fn.filereadable(test_file) == 1 then
@@ -1114,6 +1161,189 @@ describe("chat_respond: pending request transcript drift", function()
         return cursor
     end

+    it("runs a tool-only completion immediately before playful reveal", function()
+        local buf = open_simple_chat()
+        parley._state.agent = "ToolSonnet"
+        local completion
+        local qid = "qid_tool_before_reveal"
+        parley.dispatcher.query = function(buf_arg, _provider, _payload, _handler, on_exit)
+            completion = on_exit
+            parley.tasker.set_query(qid, {
+                response = "",
+                raw_response = mk_read_file_sse_response("toolu_FAST", scratch_file),
+                buf = buf_arg,
+            })
+        end
+
+        parley.chat_respond({ range = 0 })
+        completion(qid)
+        assert.is_true(vim.wait(500, function()
+            return buffer_contains(buf, "🔧: read_file id=toolu_FAST")
+        end, 10))
+        assert.is_nil(pending_virtual_text(buf))
+    end)
+
+    it("rejects force resubmit before mutating a chat that already owns a pending session", function()
+        local buf = open_simple_chat()
+        local call_count = 0
+        parley.dispatcher.query = function(buf_arg)
+            call_count = call_count + 1
+            parley.tasker.set_query("qid_force_owned", {
+                response = "", raw_response = "", buf = buf_arg,
+            })
+        end
+        parley.chat_respond({ range = 0 })
+        local before = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
+        local lease = require("parley.chat_lease").current(buf)
+
+        local ok = pcall(parley.chat_respond, { range = 0 }, nil, nil, true)
+
+        assert.is_true(ok)
+        assert.equals(1, call_count)
+        assert.same(before, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
+        assert.equals(lease.generation, require("parley.chat_lease").current(buf).generation)
+    end)
+
+    it("hides a shown leg before its local tool and starts recursion with a fresh verb", function()
+        local buf = open_simple_chat()
+        parley._state.agent = "ToolSonnet"
+        local pending = require("parley.chat_pending")
+        local original_start = pending.start
+        local starts = 0
+        pending.start = function(opts)
+            starts = starts + 1
+            local choice = starts
+            opts.choose_verb_index = function() return choice end
+            return original_start(opts)
+        end
+        local first_completion
+        local call_count = 0
+        local qid = "qid_tool_after_reveal"
+        parley.dispatcher.query = function(buf_arg, _provider, _payload, _handler, on_exit)
+            call_count = call_count + 1
+            if call_count == 1 then
+                first_completion = on_exit
+                parley.tasker.set_query(qid, {
+                    response = "",
+                    raw_response = mk_read_file_sse_response("toolu_SLOW", scratch_file),
+                    buf = buf_arg,
+                })
+            else
+                parley.tasker.set_query("qid_recursive_wait", {
+                    response = "", raw_response = "", buf = buf_arg,
+                })
+            end
+        end
+
+        parley.chat_respond({ range = 0 })
+        assert.is_true(vim.wait(1300, function()
+            return (pending_virtual_text(buf) or ""):match(" brewing$") ~= nil
+        end, 10))
+        first_completion(qid)
+        vim.wait(300, function() return false end, 10)
+        assert.is_false(buffer_contains(buf, "toolu_SLOW"), "tool must not run behind the visible indicator")
+        assert.is_true(vim.wait(1200, function()
+            return buffer_contains(buf, "🔧: read_file id=toolu_SLOW") and call_count == 2
+        end, 10))
+        assert.is_true(vim.wait(1300, function()
+            return starts == 2 and (pending_virtual_text(buf) or ""):match(" cooking$") ~= nil
+        end, 10))
+        pending.start = original_start
+    end)
+
+    it("discards staged output and tears down the chat leg once when its lease goes stale", function()
+        local lifecycle = require("parley.buffer_lifecycle")
+        local original_finalize = lifecycle.finalize_mutated_api_leg
+        local finalize_count = 0
+        lifecycle.finalize_mutated_api_leg = function(...)
+            finalize_count = finalize_count + 1
+            return original_finalize(...)
+        end
+        local buf = open_simple_chat()
+        local handler
+        parley.dispatcher.query = function(buf_arg, _provider, _payload, response_handler)
+            handler = response_handler
+            parley.tasker.set_query("qid_staged_stale", {
+                response = "staged secret", raw_response = "", buf = buf_arg,
+            })
+        end
+        parley.chat_respond({ range = 0 })
+        assert.is_true(vim.wait(1300, function() return pending_virtual_text(buf) ~= nil end, 10))
+        handler("qid_staged_stale", "staged secret")
+        vim.cmd("silent! undo")
+        local before_discard = finalize_count
+        handler("qid_staged_stale", "later")
+
+        assert.is_true(vim.wait(500, function()
+            return pending_virtual_text(buf) == nil and finalize_count == before_discard + 1
+                and require("parley.chat_lease").current(buf) == nil
+        end, 10), vim.inspect({ pending = pending_virtual_text(buf), finalize_count = finalize_count,
+            lease = require("parley.chat_lease").current(buf) }))
+        lifecycle.finalize_mutated_api_leg = original_finalize
+        assert.is_false(buffer_contains(buf, "staged secret"))
+        assert.equals(before_discard + 1, finalize_count)
+    end)
+
+    it("tears down a staged chat leg once when its buffer is deleted", function()
+        local lifecycle = require("parley.buffer_lifecycle")
+        local original_finalize = lifecycle.finalize_mutated_api_leg
+        local finalize_count = 0
+        lifecycle.finalize_mutated_api_leg = function(...)
+            finalize_count = finalize_count + 1
+            return original_finalize(...)
+        end
+        local buf = open_simple_chat()
+        local handler
+        parley.dispatcher.query = function(buf_arg, _provider, _payload, response_handler)
+            handler = response_handler
+            parley.tasker.set_query("qid_staged_deleted", {
+                response = "deleted staged", raw_response = "", buf = buf_arg,
+            })
+        end
+        parley.chat_respond({ range = 0 })
+        assert.is_true(vim.wait(1300, function() return pending_virtual_text(buf) ~= nil end, 10))
+        handler("qid_staged_deleted", "deleted staged")
+        vim.api.nvim_buf_delete(buf, { force = true })
+        handler("qid_staged_deleted", "later")
+
+        assert.is_true(vim.wait(500, function()
+            return finalize_count == 1 and require("parley.chat_lease").current(buf) == nil
+                and not require("parley.chat_pending").is_active(buf)
+        end, 10))
+        lifecycle.finalize_mutated_api_leg = original_finalize
+        assert.equals(1, finalize_count)
+    end)
+
+    it("cmd Stop discards staged output and tears down its owned chat leg once", function()
+        local lifecycle = require("parley.buffer_lifecycle")
+        local original_finalize = lifecycle.finalize_mutated_api_leg
+        local finalize_count = 0
+        lifecycle.finalize_mutated_api_leg = function(...)
+            finalize_count = finalize_count + 1
+            return original_finalize(...)
+        end
+        local buf = open_simple_chat()
+        local handler
+        parley.dispatcher.query = function(buf_arg, _provider, _payload, response_handler)
+            handler = response_handler
+            parley.tasker.set_query("qid_staged_stop", {
+                response = "cancelled staged", raw_response = "", buf = buf_arg,
+            })
+        end
+        parley.chat_respond({ range = 0 })
+        assert.is_true(vim.wait(1300, function() return pending_virtual_text(buf) ~= nil end, 10))
+        handler("qid_staged_stop", "cancelled staged")
+        parley.cmd.Stop()
+
+        assert.is_true(vim.wait(500, function()
+            return pending_virtual_text(buf) == nil and finalize_count == 1
+                and require("parley.chat_lease").current(buf) == nil
+        end, 10))
+        lifecycle.finalize_mutated_api_leg = original_finalize
+        assert.is_false(buffer_contains(buf, "cancelled staged"))
+        assert.equals(1, finalize_count)
+    end)
+
     it("does not insert a late stream chunk after undo invalidates the pending response", function()
         local buf = open_simple_chat()
         local captured_handler
@@ -1279,7 +1509,9 @@ describe("chat_respond: pending request transcript drift", function()
         assert.is_not_nil(captured_completion, "expected completion callback to be captured")

         captured_completion(qid)
-        local cursor = run_scheduled_until(scheduled, 1, function()
+        local cursor = run_scheduled_until(scheduled, 1)
+        assert.is_true(vim.wait(200, function() return cursor <= #scheduled end, 10))
+        cursor = run_scheduled_until(scheduled, cursor, function()
             return buffer_contains(buf, "🔧: read_file id=toolu_RECURSE_UNDO")
         end)
         assert.is_true(buffer_contains(buf, "🔧: read_file id=toolu_RECURSE_UNDO"))
@@ -1336,10 +1568,13 @@ describe("chat_respond: pending request transcript drift", function()
         parley.chat_respond({ range = 0 })
         captured_completion(qid)
         local cursor = run_scheduled_until(scheduled, 1)
+        assert.is_true(vim.wait(200, function() return cursor <= #scheduled end, 10))
+        cursor = run_scheduled_until(scheduled, cursor, function() return call_count == 2 end)
         assert.equals(2, call_count, "valid recursive respond should call dispatcher again")
         captured_handler("qid_recursive_second", "final at 2026-07-12T12:00:00Z")
         cursor = run_scheduled_until(scheduled, cursor)
         captured_completion("qid_recursive_second")
+        vim.wait(200, function() return cursor <= #scheduled end, 10)
         run_scheduled_until(scheduled, cursor)
         lifecycle.finalize_mutated_api_leg = original_finalize

diff --git a/tests/integration/cliproxy_caller_teardown_spec.lua b/tests/integration/cliproxy_caller_teardown_spec.lua
index 650eb72..ef72a9d 100644
--- a/tests/integration/cliproxy_caller_teardown_spec.lua
+++ b/tests/integration/cliproxy_caller_teardown_spec.lua
@@ -88,6 +88,37 @@ describe("cliproxy on_abort teardown per caller", function()
         assert.is_truthy(done) -- callback fired → on_abort → process_next past BOTH tags
     end)

+    it("memory_prefs advances every tag after drained transport failures", function()
+        local tasker = require("parley.tasker")
+        local agent = parley.get_agent()
+        vault.resolve_secret(agent.provider, "test-secret", function() end)
+        parley.dispatcher.providers[agent.provider] = parley.dispatcher.providers[agent.provider] or {}
+        parley.dispatcher.providers[agent.provider].endpoint = "http://unused.test"
+
+        local original_run = tasker.run
+        local runs = 0
+        tasker.run = function(_buf, _cmd, args, terminal, out_reader)
+            runs = runs + 1
+            local write_out
+            for i, arg in ipairs(args) do
+                if arg == "--write-out" then write_out = args[i + 1] end
+            end
+            local sentinel = write_out:match("%%{stderr}(.-)%%{http_code}")
+            out_reader(nil, nil)
+            terminal(7, 0, "", sentinel .. "000\n", nil)
+        end
+
+        local done
+        require("parley.memory_prefs").generate_preferences(
+            { topicA = { "s1" }, topicB = { "s2" } },
+            function(prefs) done = prefs end)
+        assert.is_true(vim.wait(1000, function() return done ~= nil end, 10))
+        tasker.run = original_run
+
+        assert.equals(2, runs)
+        assert.same({}, done)
+    end)
+
     -- chat_respond main path: mock D.query to invoke the real on_abort (arg 8);
     -- assert it's wired at the right position AND collapses the inserted answer
     -- block (default, non-web-search path — the round-2 gate's demanded test).
@@ -167,4 +198,40 @@ describe("cliproxy on_abort teardown per caller", function()
         assert.is_true(saw_fn) -- on_abort wired at arg position 8
         assert.is_false(skill_invoke.is_in_flight(buf)) -- guard cleared, buffer not blocked
     end)
+
+    it("skill_invoke transport terminal uses argument 10 exactly once", function()
+        local skill_invoke = require("parley.skill_invoke")
+        local doc = tmp_dir .. "/transport-doc.md"
+        vim.fn.writefile({ "hello world" }, doc)
+        vim.cmd("edit " .. doc)
+        local buf = vim.api.nvim_get_current_buf()
+        local manifest = {
+            name = "testskill",
+            source = function() return "System prompt." end,
+            agent = "agentX",
+        }
+        local saved_get_agent = parley.get_agent
+        parley.get_agent = function()
+            return { provider = "cliproxyapi", model = { model = "claude-x" }, name = "agentX" }
+        end
+        local saved_query = parley.dispatcher.query
+        local on_exit, on_error
+        parley.dispatcher.query = function(_b, _p, _pl, _h, exit, _cb, _op, _abort, _activity, err)
+            on_exit, on_error = exit, err
+        end
+        local events = {}
+        skill_invoke.invoke(buf, manifest, {}, {
+            detached_progress = false,
+            on_terminal = function() table.insert(events, "terminal") end,
+            on_done = function() table.insert(events, "done") end,
+        })
+        on_error("q", { code = 7 })
+        on_exit("q")
+        vim.wait(100, function() return false end)
+        parley.get_agent = saved_get_agent
+        parley.dispatcher.query = saved_query
+
+        assert.are.same({ "terminal", "done" }, events)
+        assert.is_false(skill_invoke.is_in_flight(buf))
+    end)
 end)
diff --git a/tests/integration/define_spec.lua b/tests/integration/define_spec.lua
index 2d575de..f58d3cc 100644
--- a/tests/integration/define_spec.lua
+++ b/tests/integration/define_spec.lua
@@ -231,6 +231,11 @@ describe("define_visual + render_definition (#161)", function()
     end)

     local hl_ns = vim.api.nvim_create_namespace("parley_skill_hl")
+    local spinner_ns = vim.api.nvim_create_namespace("parley_selection_spinner")
+    local function spinner_marks(b)
+        if not vim.api.nvim_buf_is_valid(b) then return {} end
+        return vim.api.nvim_buf_get_extmarks(b, spinner_ns, 0, -1, { details = true })
+    end
     local function hl_on_line(b, line0)
         for _, m in ipairs(vim.api.nvim_buf_get_extmarks(b, hl_ns, 0, -1, {})) do
             if m[2] == line0 then return true end
@@ -271,6 +276,187 @@ describe("define_visual + render_definition (#161)", function()
         assert.are.equal(8, mark[3])
         assert.are.equal(2, mark[4].end_row)
         assert.are.equal(19, mark[4].end_col)
+        assert.are.equal(0, #spinner_marks(buf), "spinner must be removed before durable render")
+    end)
+
+    it("shows immediate inline canonical progress without mutating chat text or opening detached progress", function()
+        local held_exit
+        parley.dispatcher.query = function(_b, _p, _payload, _h, on_exit)
+            query_called = true
+            held_exit = on_exit
+        end
+        vim.fn.setpos("'<", { buf, 3, 9, 0 })
+        vim.fn.setpos("'>", { buf, 3, 12, 0 })
+        local before = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
+        require("parley").define_visual(buf)
+
+        assert.are.same(before, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
+        assert.is_false(require("parley.progress").is_active())
+        local mark = spinner_marks(buf)[1]
+        assert.is_not_nil(mark)
+        assert.are.equal(2, mark[2])
+        assert.are.equal(12, mark[3])
+        assert.are.same({ { " ⠙" } }, mark[4].virt_text)
+        assert.are.equal("inline", mark[4].virt_text_pos)
+
+        assert.is_true(vim.wait(500, function()
+            local current = spinner_marks(buf)[1]
+            return current and current[4].virt_text[1][1] ~= " ⠙"
+        end, 10), "spinner frame did not advance")
+        require("parley.skill_invoke").cancel(buf)
+        assert.are.equal(0, #spinner_marks(buf))
+        held_exit("late")
+    end)
+
+    it("removes inline progress on pre-query abort, transport failure, and explicit cancel", function()
+        local modes = { "abort", "transport", "cancel" }
+        for _, mode in ipairs(modes) do
+            local callbacks = {}
+            parley.dispatcher.query = function(_b, _p, _payload, _h, on_exit, _cb, _prog, on_abort, _activity, on_error)
+                callbacks = { on_exit = on_exit, on_abort = on_abort, on_error = on_error }
+            end
+            vim.fn.setpos("'<", { buf, 3, 9, 0 })
+            vim.fn.setpos("'>", { buf, 3, 12, 0 })
+            require("parley").define_visual(buf)
+            assert.are.equal(1, #spinner_marks(buf), mode)
+            if mode == "abort" then
+                callbacks.on_abort("missing secret")
+            elseif mode == "transport" then
+                callbacks.on_error("q", { code = 7 })
+            else
+                require("parley.skill_invoke").cancel(buf)
+            end
+            assert.are.equal(0, #spinner_marks(buf), mode)
+            assert.are.equal("here is ASIN in context",
+                vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1], mode)
+            if callbacks.on_exit then callbacks.on_exit("late") end
+        end
+    end)
+
+    it("cleans inline progress through real dispatcher prestart failures", function()
+        local vault = require("parley.vault")
+        local runner = require("parley.tasker")
+        local original_run = runner.run
+        parley.dispatcher.query = orig_query
+
+        local function invoke_and_assert_clean(label)
+            vim.fn.setpos("'<", { buf, 3, 9, 0 })
+            vim.fn.setpos("'>", { buf, 3, 12, 0 })
+            require("parley").define_visual(buf)
+            assert.is_true(vim.wait(1000, function()
+                return not require("parley.skill_invoke").is_in_flight(buf)
+            end, 10), label)
+            assert.are.equal(0, #spinner_marks(buf), label)
+            assert.is_false(require("parley.progress").is_active(), label)
+            assert.are.equal("here is ASIN in context",
+                vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1], label)
+        end
+
+        -- Real dispatcher + vault missing-secret path.
+        invoke_and_assert_clean("missing secret")
+
+        -- Real dispatcher/vault with only the task-launch boundary rejected.
+        vault.add_secret("anthropic", "test-secret")
+        for _, label in ipairs({ "busy", "spawn rejected" }) do
+            runner.run = function(_buf, _cmd, _args, _terminal, _out, _err, on_start_error)
+                on_start_error(label)
+            end
+            invoke_and_assert_clean(label)
+        end
+        runner.run = original_run
+    end)
+
+    it("removes progress and writes no footnote when the selection becomes stale", function()
+        local held_exit
+        parley.dispatcher.query = function(_b, _p, _payload, _h, on_exit)
+            held_exit = on_exit
+        end
+        vim.fn.setpos("'<", { buf, 3, 9, 0 })
+        vim.fn.setpos("'>", { buf, 3, 12, 0 })
+        require("parley").define_visual(buf)
+        assert.are.equal(1, #spinner_marks(buf))
+        vim.api.nvim_buf_set_lines(buf, 2, 3, false, { "here is CHANGED in context" })
+        tasker.set_query("stale-definition", {
+            raw_response = emit_definition_sse("ASIN", "Should not land."),
+        })
+        held_exit("stale-definition")
+        assert.is_true(vim.wait(1000, function()
+            return #spinner_marks(buf) == 0
+        end, 10))
+        local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
+        assert.is_nil(text:find("Should not land", 1, true))
+        assert.is_nil(text:find("[^asin]", 1, true))
+    end)
+
+    it("cleans immediate progress on real Definition source and agent failures", function()
+        local define_manifest = require("parley.skills.define")
+        local original_source = define_manifest.source
+        local function invoke_and_assert_clean(label)
+            vim.fn.setpos("'<", { buf, 3, 9, 0 })
+            vim.fn.setpos("'>", { buf, 3, 12, 0 })
+            require("parley").define_visual(buf)
+            assert.are.equal(0, #spinner_marks(buf), label)
+            assert.is_false(require("parley.progress").is_active(), label)
+            assert.are.equal("here is ASIN in context",
+                vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1], label)
+        end
+
+        define_manifest.source = function() error("source unavailable") end
+        invoke_and_assert_clean("source failure")
+        define_manifest.source = original_source
+
+        assembly.resolve_agent = function() return nil end
+        invoke_and_assert_clean("no agent")
+    end)
+
+    it("stops and closes the inline timer when the Definition buffer is deleted", function()
+        local held_exit
+        parley.dispatcher.query = function(_b, _p, _payload, _h, on_exit)
+            held_exit = on_exit
+        end
+        local original_new_timer = vim.uv.new_timer
+        local timer = { stopped = false, closed = false }
+        function timer:start(_delay, _repeat_ms, callback) self.callback = callback end
+        function timer:stop() self.stopped = true end
+        function timer:close() self.closed = true end
+        vim.uv.new_timer = function() return timer end
+
+        vim.fn.setpos("'<", { buf, 3, 9, 0 })
+        vim.fn.setpos("'>", { buf, 3, 12, 0 })
+        require("parley").define_visual(buf)
+        assert.are.equal(1, #spinner_marks(buf))
+        vim.api.nvim_buf_delete(buf, { force = true })
+        tasker.set_query("deleted-definition", { raw_response = "" })
+        held_exit("deleted-definition")
+        assert.is_true(vim.wait(1000, function() return timer.closed end, 10))
+        vim.uv.new_timer = original_new_timer
+
+        assert.is_true(timer.stopped)
+        assert.is_true(timer.closed)
+        assert.is_false(require("parley.progress").is_active())
+    end)
+
+    it("cleans Definition progress when malformed tool output breaks completion", function()
+        parley.dispatcher.query = function(_b, _p, _payload, _handler, on_exit)
+            tasker.set_query("malformed-definition", {
+                raw_response = sse({
+                    { type = "content_block_start", index = 0,
+                      content_block = { type = "tool_use", id = "bad", input = {} } },
+                    { type = "content_block_stop", index = 0 },
+                    { type = "message_stop" },
+                }),
+            })
+            vim.schedule(function() on_exit("malformed-definition") end)
+        end
+        vim.fn.setpos("'<", { buf, 3, 9, 0 })
+        vim.fn.setpos("'>", { buf, 3, 12, 0 })
+        require("parley").define_visual(buf)
+        assert.is_true(vim.wait(1000, function()
+            return #spinner_marks(buf) == 0
+        end, 10), "malformed completion leaked the Definition spinner")
+        assert.is_false(require("parley.progress").is_active())
+        assert.are.equal("here is ASIN in context",
+            vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1])
     end)

     it("word-wraps long define diagnostics to the diagnostic display width", function()
@@ -410,6 +596,8 @@ describe("define_visual + render_definition (#161)", function()
         assert.are.equal("here is ASIN in context",
             vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1],
             "a no-tool response must not footnote the term")
+        assert.are.equal(0, #spinner_marks(buf), "no-tool completion leaked spinner")
+        assert.is_false(require("parley.progress").is_active())
     end)
 end)

diff --git a/tests/integration/skill_invoke_spec.lua b/tests/integration/skill_invoke_spec.lua
index 07c4dd7..f67c947 100644
--- a/tests/integration/skill_invoke_spec.lua
+++ b/tests/integration/skill_invoke_spec.lua
@@ -297,3 +297,212 @@ describe("skill_invoke.invoke", function()
         assert.equals("sibling repo root file", done_result.results[1].content:match("sibling repo root file"))
     end)
 end)
+
+describe("skill_invoke terminal ownership (#182)", function()
+    local parley = require("parley")
+    local skill_invoke = require("parley.skill_invoke")
+    local assembly = require("parley.skill_assembly")
+    local tasker = require("parley.tasker")
+    local tmpdir, path, buf, original_query, original_resolve
+
+    local function terminal_manifest(overrides)
+        return vim.tbl_extend("force", {
+            name = "terminal-test",
+            description = "d",
+            scope = "global",
+            activation = { manual = true },
+            source = function() return "SYSTEM" end,
+            tools = {},
+        }, overrides or {})
+    end
+
+    before_each(function()
+        tmpdir = vim.fn.tempname() .. "-skill-terminal"
+        vim.fn.mkdir(tmpdir, "p")
+        path = tmpdir .. "/doc.md"
+        vim.fn.writefile({ "alpha" }, path)
+        vim.cmd("edit! " .. vim.fn.fnameescape(path))
+        buf = vim.api.nvim_get_current_buf()
+        original_query = parley.dispatcher.query
+        original_resolve = assembly.resolve_agent
+        assembly.resolve_agent = function()
+            return { model = "m", provider = "anthropic" }
+        end
+        require("parley.progress").stop()
+    end)
+
+    after_each(function()
+        parley.dispatcher.query = original_query
+        assembly.resolve_agent = original_resolve
+        pcall(skill_invoke.cancel, buf)
+        pcall(function() require("parley.progress").stop() end)
+        pcall(vim.cmd, "enew!")
+        vim.fn.delete(tmpdir, "rf")
+    end)
+
+    it("suppresses detached progress only when explicitly requested", function()
+        local held_exit
+        parley.dispatcher.query = function(_b, _p, _pl, _h, on_exit)
+            held_exit = on_exit
+        end
+        skill_invoke.invoke(buf, terminal_manifest(), {}, { detached_progress = false })
+        assert.is_false(require("parley.progress").is_active())
+        skill_invoke.cancel(buf)
+
+        skill_invoke.invoke(buf, terminal_manifest(), {}, {})
+        assert.is_true(require("parley.progress").is_active())
+        skill_invoke.cancel(buf)
+        tasker.set_query("late", { raw_response = "" })
+        held_exit("late")
+    end)
+
+    it("owns each async terminal once and orders terminal before done", function()
+        local terminals = {
+            {
+                name = "success",
+                fire = function(c) tasker.set_query("q", { raw_response = "" }); c.on_exit("q") end,
+            },
+            { name = "pre-query abort", fire = function(c) c.on_abort("abort") end },
+            { name = "transport error", fire = function(c) c.on_error("q", { code = 7 }) end },
+        }
+        for _, case in ipairs(terminals) do
+            local callbacks, events = {}, {}
+            parley.dispatcher.query = function(_b, _p, _pl, _h, on_exit, _cb, _prog, on_abort, _activity, on_error)
+                callbacks = { on_exit = on_exit, on_abort = on_abort, on_error = on_error }
+            end
+            skill_invoke.invoke(buf, terminal_manifest(), {}, {
+                detached_progress = false,
+                on_terminal = function() table.insert(events, "terminal") end,
+                on_done = function() table.insert(events, "done") end,
+            })
+            case.fire(callbacks)
+            assert.is_true(vim.wait(1000, function() return #events == 2 end, 10), case.name)
+            callbacks.on_abort("late")
+            callbacks.on_error("q", { code = 8 })
+            assert.are.same({ "terminal", "done" }, events, case.name)
+            assert.is_false(skill_invoke.is_in_flight(buf), case.name)
+        end
+    end)
+
+    it("cancel delivers terminal cleanup once, skips done, and ignores late callbacks", function()
+        local held_exit, held_error, events = nil, nil, {}
+        parley.dispatcher.query = function(_b, _p, _pl, _h, on_exit, _cb, _prog, _abort, _activity, on_error)
+            held_exit, held_error = on_exit, on_error
+        end
+        skill_invoke.invoke(buf, terminal_manifest(), {}, {
+            detached_progress = false,
+            on_terminal = function() table.insert(events, "terminal") end,
+            on_done = function() table.insert(events, "done") end,
+        })
+        skill_invoke.cancel(buf)
+        skill_invoke.cancel(buf)
+        tasker.set_query("late", { raw_response = "" })
+        held_exit("late")
+        held_error("late", { code = 7 })
+        vim.wait(100, function() return false end)
+        assert.are.same({ "terminal" }, events)
+    end)
+
+    it("finishes invalid scheduled completion without reading or delivering done", function()
+        local held_exit, events = nil, {}
+        parley.dispatcher.query = function(_b, _p, _pl, _h, on_exit)
+            held_exit = on_exit
+        end
+        skill_invoke.invoke(buf, terminal_manifest(), {}, {
+            detached_progress = false,
+            on_terminal = function(result) table.insert(events, result.msg) end,
+            on_done = function() table.insert(events, "done") end,
+        })
+        vim.api.nvim_buf_delete(buf, { force = true })
+        tasker.set_query("deleted", { raw_response = "" })
+        held_exit("deleted")
+        assert.is_true(vim.wait(1000, function() return #events > 0 end, 10))
+        assert.are.same({ "buffer invalid" }, events)
+    end)
+
+    it("delivers synchronous terminal failures once before done", function()
+        local cases = {
+            {
+                name = "no file",
+                setup = function()
+                    vim.cmd("enew!")
+                    buf = vim.api.nvim_get_current_buf()
+                end,
+                manifest = terminal_manifest(),
+                message = "buffer has no file",
+            },
+            {
+                name = "source failure",
+                setup = function() end,
+                manifest = terminal_manifest({ source = function() error("boom") end }),
+                message = "source failed",
+            },
+            {
+                name = "no agent",
+                setup = function() assembly.resolve_agent = function() return nil end end,
+                manifest = terminal_manifest(),
+                message = "no agent",
+            },
+        }
+        for _, case in ipairs(cases) do
+            if case.name ~= "no file" then
+                vim.cmd("edit! " .. vim.fn.fnameescape(path))
+                buf = vim.api.nvim_get_current_buf()
+            end
+            case.setup()
+            local events = {}
+            skill_invoke.invoke(buf, case.manifest, {}, {
+                detached_progress = false,
+                on_terminal = function(result) table.insert(events, "terminal:" .. result.msg) end,
+                on_done = function() table.insert(events, "done") end,
+            })
+            assert.are.equal(2, #events, case.name)
+            assert.is_truthy(events[1]:find(case.message, 1, true), case.name)
+            assert.are.equal("done", events[2], case.name)
+            assert.is_false(skill_invoke.is_in_flight(buf), case.name)
+        end
+    end)
+
+    it("rejects a second invocation through its own ordered terminal", function()
+        parley.dispatcher.query = function() end
+        skill_invoke.invoke(buf, terminal_manifest(), {}, { detached_progress = false })
+        local events = {}
+        skill_invoke.invoke(buf, terminal_manifest(), {}, {
+            detached_progress = false,
+            on_terminal = function(result) table.insert(events, "terminal:" .. result.msg) end,
+            on_done = function() table.insert(events, "done") end,
+        })
+        assert.are.same({ "terminal:already running", "done" }, events)
+        assert.is_true(skill_invoke.is_in_flight(buf), "the first invocation must remain owned")
+        skill_invoke.cancel(buf)
+    end)
+
+    it("finishes a malformed scheduled completion and contains terminal callback failure", function()
+        parley.dispatcher.query = function(_b, _p, _payload, _handler, on_exit)
+            tasker.set_query("malformed", {
+                raw_response = sse({
+                    { type = "content_block_start", index = 0,
+                      content_block = { type = "tool_use", id = "bad", input = {} } },
+                    { type = "content_block_stop", index = 0 },
+                    { type = "message_stop" },
+                }),
+            })
+            vim.schedule(function() on_exit("malformed") end)
+        end
+        local done, terminal_calls = nil, 0
+        skill_invoke.invoke(buf, terminal_manifest(), {}, {
+            on_terminal = function()
+                terminal_calls = terminal_calls + 1
+                error("caller failure must be contained")
+            end,
+            on_done = function(result) done = result end,
+        })
+        assert.is_true(vim.wait(1000, function() return done ~= nil end, 10),
+            "malformed completion leaked its terminal")
+        assert.are.equal(1, terminal_calls)
+        assert.is_false(done.ok)
+        assert.are.equal("completion failed", done.msg)
+        assert.is_false(skill_invoke.is_in_flight(buf))
+        assert.is_false(require("parley.progress").is_active())
+    end)
+end)
diff --git a/tests/integration/tasker_run_spec.lua b/tests/integration/tasker_run_spec.lua
index 13b3586..b0c279f 100644
--- a/tests/integration/tasker_run_spec.lua
+++ b/tests/integration/tasker_run_spec.lua
@@ -7,6 +7,7 @@
 -- without mocking uv.spawn. This verifies the actual libuv integration.

 local tasker = require("parley.tasker")
+local logger = require("parley.logger")

 describe("tasker.run integration", function()
     before_each(function()
@@ -19,6 +20,7 @@ describe("tasker.run integration", function()
         -- Stop any running processes
         tasker.stop()
         tasker._handles = {}
+        tasker._uv = nil
     end)

     describe("Group A: Basic subprocess execution", function()
@@ -500,4 +502,321 @@ describe("tasker.run integration", function()
             assert.is_true(exit_called, "Should complete without out_reader/err_reader")
         end)
     end)
+
+    describe("Group G: drain-safe terminal", function()
+        local function fake_uv(opts)
+            opts = opts or {}
+            local state = { pipes = {}, spawn_calls = 0 }
+            local runtime = {}
+            runtime.new_pipe = function()
+                local pipe = { closing = false, close_calls = 0 }
+                pipe.read_stop = function() end
+                pipe.is_closing = function(self) return self.closing end
+                pipe.close = function(self)
+                    self.closing = true
+                    self.close_calls = self.close_calls + 1
+                end
+                table.insert(state.pipes, pipe)
+                return pipe
+            end
+            runtime.spawn = function(_cmd, _spawn_opts, on_exit)
+                state.spawn_calls = state.spawn_calls + 1
+                state.on_exit = on_exit
+                if opts.spawn_error then return nil, opts.spawn_error end
+                local handle = { closing = false }
+                handle.is_closing = function(self) return self.closing end
+                handle.close = function(self) self.closing = true end
+                state.handle = handle
+                return handle, 4242
+            end
+            runtime.read_start = function(pipe, reader)
+                local stream = pipe == state.pipes[1] and "stdout" or "stderr"
+                if opts[stream .. "_start_throw"] then error(stream .. " start exploded") end
+                if opts[stream .. "_start_reject"] then return false, stream .. " start rejected" end
+                pipe.reader = reader
+                return 0
+            end
+            return runtime, state
+        end
+
+        for _, case in ipairs({
+            { name = "exit before both EOFs", exit_first = true },
+            { name = "both EOFs before exit", exit_first = false },
+        }) do
+            it("coordinates " .. case.name .. " and schedules terminal once", function()
+                local runtime, state = fake_uv()
+                tasker._uv = runtime
+                local events = {}
+                local terminal
+                tasker.run(nil, "fake", {}, function(code, signal, stdout, stderr, io_error)
+                    table.insert(events, "terminal")
+                    terminal = { code, signal, stdout, stderr, io_error }
+                end, function(err, data)
+                    table.insert(events, { stream = "stdout", err = err, data = data })
+                end, function(err, data)
+                    table.insert(events, { stream = "stderr", err = err, data = data })
+                end)
+
+                if case.exit_first then state.on_exit(0, 0) end
+                state.pipes[1].reader(nil, "out")
+                state.pipes[1].reader(nil, nil)
+                assert.is_nil(terminal)
+                state.pipes[2].reader(nil, "err")
+                state.pipes[2].reader(nil, nil)
+                if not case.exit_first then
+                    assert.is_nil(terminal)
+                    state.on_exit(0, 0)
+                end
+                assert.is_nil(terminal, "terminal must remain scheduled off the fast callback")
+                assert.is_true(vim.wait(100, function() return terminal ~= nil end, 5))
+                assert.same({ 0, 0, "out", "err" }, { terminal[1], terminal[2], terminal[3], terminal[4] })
+                assert.is_nil(terminal[5])
+                assert.equals("terminal", events[#events])
+                assert.equals(1, vim.tbl_count(vim.tbl_filter(function(value)
+                    return value == "terminal"
+                end, events)))
+                local final_by_stream = {}
+                for _, event in ipairs(events) do
+                    if type(event) == "table" then final_by_stream[event.stream] = event end
+                end
+                assert.is_nil(final_by_stream.stdout.err)
+                assert.is_nil(final_by_stream.stdout.data)
+                assert.is_nil(final_by_stream.stderr.err)
+                assert.is_nil(final_by_stream.stderr.data)
+            end)
+        end
+
+        it("forwards a read error then one final nil before the terminal", function()
+            local runtime, state = fake_uv()
+            tasker._uv = runtime
+            local stdout_events = {}
+            local terminal
+            tasker.run(nil, "fake", {}, function(_code, _signal, stdout, _stderr, io_error)
+                terminal = { stdout = stdout, io_error = io_error }
+            end, function(err, data)
+                table.insert(stdout_events, { err = err, data = data })
+            end)
+
+            state.pipes[1].reader(nil, "unterminated")
+            state.pipes[1].reader("read boom", nil)
+            state.pipes[1].reader(nil, nil) -- defensive late libuv delivery is ignored
+            state.pipes[2].reader(nil, nil)
+            state.on_exit(9, 0)
+            assert.is_true(vim.wait(100, function() return terminal ~= nil end, 5))
+            assert.equals(3, #stdout_events)
+            assert.equals("read boom", stdout_events[2].err)
+            assert.is_nil(stdout_events[2].data)
+            assert.is_nil(stdout_events[3].err)
+            assert.is_nil(stdout_events[3].data)
+            assert.equals("unterminated", terminal.stdout)
+            assert.is_truthy(terminal.io_error)
+        end)
+
+        it("contains throwing readers and still drains both streams once", function()
+            local runtime, state = fake_uv()
+            tasker._uv = runtime
+            local stdout_calls = 0
+            local stderr_calls = 0
+            local terminals = 0
+            tasker.run(nil, "fake", {}, function()
+                terminals = terminals + 1
+            end, function()
+                stdout_calls = stdout_calls + 1
+                error("stdout reader exploded")
+            end, function()
+                stderr_calls = stderr_calls + 1
+                error("stderr reader exploded")
+            end)
+
+            assert.has_no.errors(function()
+                state.pipes[1].reader(nil, "out")
+                state.pipes[1].reader(nil, nil)
+                state.pipes[2].reader(nil, "err")
+                state.pipes[2].reader(nil, nil)
+                state.on_exit(0, 0)
+            end)
+            assert.is_true(vim.wait(100, function() return terminals == 1 end, 5))
+            assert.equals(2, stdout_calls)
+            assert.equals(2, stderr_calls)
+            assert.equals(0, #tasker._handles)
+        end)
+
+        it("cleans up and emits finished when the public terminal throws", function()
+            local runtime, state = fake_uv()
+            tasker._uv = runtime
+            local terminals = 0
+            local finished = 0
+            local autocmd = vim.api.nvim_create_autocmd("User", {
+                pattern = "ParleyQueryFinished",
+                callback = function() finished = finished + 1 end,
+            })
+            tasker.run(nil, "fake", {}, function()
+                terminals = terminals + 1
+                error("terminal exploded")
+            end)
+            state.pipes[1].reader(nil, nil)
+            state.pipes[2].reader(nil, nil)
+            state.on_exit(0, 0)
+
+            assert.is_true(vim.wait(100, function()
+                return terminals == 1 and finished == 1 and #tasker._handles == 0
+            end, 5))
+            pcall(vim.api.nvim_del_autocmd, autocmd)
+            assert.equals(1, terminals)
+            assert.equals(1, finished)
+            assert.equals(0, #tasker._handles)
+        end)
+
+        it("logs bounded generic diagnostics for exceptional public callbacks", function()
+            local runtime, state = fake_uv()
+            tasker._uv = runtime
+            local marker = "CALLBACK_SECRET_MARKER"
+            local logs = {}
+            local original_error = logger.error
+            logger.error = function(message) table.insert(logs, tostring(message)) end
+            tasker.run(nil, "fake", {}, function()
+                error(marker .. string.rep("x", 2000))
+            end, function()
+                error(marker .. string.rep("y", 2000))
+            end)
+            state.pipes[1].reader(nil, "out")
+            state.pipes[1].reader(nil, nil)
+            state.pipes[2].reader(nil, nil)
+            state.on_exit(0, 0)
+            local completed = vim.wait(100, function() return #tasker._handles == 0 end, 5)
+            logger.error = original_error
+
+            assert.is_true(completed)
+            local combined = table.concat(logs, "\n")
+            assert.is_falsy(combined:find(marker, 1, true))
+            assert.is_truthy(combined:find("stdout reader callback failed", 1, true))
+            assert.is_truthy(combined:find("task terminal callback failed", 1, true))
+            for _, message in ipairs(logs) do
+                assert.is_true(#message < 256, "callback diagnostic must remain bounded")
+            end
+        end)
+
+        for _, case in ipairs({
+            { stream = "stdout", opts = { stdout_start_throw = true }, live_pipe = 2 },
+            { stream = "stderr", opts = { stderr_start_reject = true }, live_pipe = 1 },
+        }) do
+            it("turns " .. case.stream .. " read_start rejection into a drained IO terminal", function()
+                local runtime, state = fake_uv(case.opts)
+                tasker._uv = runtime
+                local terminals = 0
+                local terminal_error
+                tasker.run(nil, "fake", {}, function(_code, _signal, _stdout, _stderr, io_error)
+                    terminals = terminals + 1
+                    terminal_error = io_error
+                end)
+
+                state.pipes[case.live_pipe].reader(nil, nil)
+                state.on_exit(0, 0)
+                assert.is_true(vim.wait(100, function() return terminals == 1 end, 5))
+                assert.is_truthy(terminal_error)
+                local rejected_pipe = case.stream == "stdout" and state.pipes[1] or state.pipes[2]
+                assert.equals(1, rejected_pipe.close_calls)
+                assert.equals(0, #tasker._handles)
+            end)
+        end
+
+        it("rejects busy work before allocating pipes", function()
+            local runtime, state = fake_uv()
+            tasker._uv = runtime
+            local original_is_busy = tasker.is_busy
+            tasker.is_busy = function() return true end
+            local starts = 0
+            local terminals = 0
+            tasker.run(9, "fake", {}, function() terminals = terminals + 1 end,
+                nil, nil, function() starts = starts + 1 end)
+            tasker.is_busy = original_is_busy
+            assert.is_true(vim.wait(100, function() return starts == 1 end, 5))
+            assert.equals(0, #state.pipes)
+            assert.equals(0, state.spawn_calls)
+            assert.equals(0, #tasker._handles)
+            assert.equals(0, terminals)
+        end)
+
+        it("closes both pipes and reports one spawn rejection without a terminal", function()
+            local runtime, state = fake_uv({ spawn_error = "ENOENT" })
+            tasker._uv = runtime
+            local starts = 0
+            local terminals = 0
+            tasker.run(nil, "fake", {}, function() terminals = terminals + 1 end,
+                nil, nil, function() starts = starts + 1 end)
+            assert.is_true(vim.wait(100, function() return starts == 1 end, 5))
+            assert.equals(2, #state.pipes)
+            assert.equals(1, state.pipes[1].close_calls)
+            assert.equals(1, state.pipes[2].close_calls)
+            assert.equals(0, #tasker._handles)
+            assert.equals(0, terminals)
+        end)
+
+        it("G1: waits for both readers and preserves their final nil before terminal", function()
+            local events = {}
+            local stdout
+            local stderr
+
+            tasker.run(nil, "sh", { "-c", "printf out; printf err >&2" },
+                function(code, signal, stdout_data, stderr_data, io_error)
+                    table.insert(events, "terminal")
+                    stdout = stdout_data
+                    stderr = stderr_data
+                    assert.equals(0, code)
+                    assert.equals(0, signal)
+                    assert.is_nil(io_error)
+                end,
+                function(err, data)
+                    assert.is_nil(err)
+                    table.insert(events, data and "stdout" or "stdout_eof")
+                end,
+                function(err, data)
+                    assert.is_nil(err)
+                    table.insert(events, data and "stderr" or "stderr_eof")
+                end)
+
+            assert.is_true(vim.wait(1000, function()
+                return events[#events] == "terminal"
+            end, 10))
+            assert.equals("out", stdout)
+            assert.equals("err", stderr)
+            local before_terminal = { events[#events - 2], events[#events - 1] }
+            table.sort(before_terminal)
+            assert.same({ "stderr_eof", "stdout_eof" }, before_terminal)
+        end)
+
+        it("G2: schedules spawn rejection once and never calls terminal", function()
+            local start_errors = 0
+            local terminals = 0
+            tasker.run(nil, "parley-command-that-does-not-exist", {}, function()
+                terminals = terminals + 1
+            end, nil, nil, function(message)
+                start_errors = start_errors + 1
+                assert.is_truthy(tostring(message):find("start", 1, true))
+            end)
+
+            assert.is_true(vim.wait(1000, function() return start_errors == 1 end, 10))
+            assert.equals(0, terminals)
+            assert.equals(0, #tasker._handles)
+        end)
+
+        it("G3: reconstructs a stderr trailer split at every byte", function()
+            local marker = "__PARLEY_HTTP_split__503\n"
+            for split = 0, #marker do
+                local runtime, state = fake_uv()
+                tasker._uv = runtime
+                local captured
+                tasker.run(nil, "fake", {}, function(_code, _signal, _stdout, stderr)
+                    captured = stderr
+                end)
+                state.pipes[1].reader(nil, nil)
+                if split > 0 then state.pipes[2].reader(nil, marker:sub(1, split)) end
+                if split < #marker then state.pipes[2].reader(nil, marker:sub(split + 1)) end
+                state.pipes[2].reader(nil, nil)
+                state.on_exit(0, 0)
+                assert.is_true(vim.wait(100, function() return captured ~= nil end, 5))
+                assert.equals(marker, captured, "split boundary " .. split)
+            end
+        end)
+    end)
 end)
diff --git a/tests/integration/topic_gen_spec.lua b/tests/integration/topic_gen_spec.lua
index 93ef67a..23f7a2c 100644
--- a/tests/integration/topic_gen_spec.lua
+++ b/tests/integration/topic_gen_spec.lua
@@ -68,6 +68,36 @@ describe("generate_topic", function()
         -- and it carries no 🧠: thinking mandate
         assert.is_nil(last.content:find("🧠"))
     end)
+
+    it("falls back through real dispatcher teardown on drained transport failure", function()
+        local tasker = require("parley.tasker")
+        local vault = require("parley.vault")
+        vault.resolve_secret("openai", "test-secret", function() end)
+        parley.dispatcher.providers.openai = parley.dispatcher.providers.openai or {}
+        parley.dispatcher.providers.openai.endpoint = "http://unused.test"
+
+        local original_run = tasker.run
+        tasker.run = function(_buf, _cmd, args, terminal, out_reader)
+            local write_out
+            for i, arg in ipairs(args) do
+                if arg == "--write-out" then write_out = args[i + 1] end
+            end
+            local sentinel = write_out:match("%%{stderr}(.-)%%{http_code}")
+            out_reader(nil, nil)
+            terminal(7, 0, "", sentinel .. "000\n", nil)
+        end
+
+        local result
+        chat_respond.generate_topic({ { role = "user", content = "hello" } },
+            "openai", { model = "gpt-x" }, function(topic, reason)
+                result = { topic = topic, reason = reason }
+            end)
+        assert.is_true(vim.wait(500, function() return result ~= nil end, 10))
+        tasker.run = original_run
+
+        assert.is_nil(result.topic)
+        assert.equals("empty", result.reason)
+    end)
 end)

 describe("ChatPrune topic generation failure", function()
diff --git a/tests/unit/buffer_edit_spec.lua b/tests/unit/buffer_edit_spec.lua
index 0db4ebd..9a08c12 100644
--- a/tests/unit/buffer_edit_spec.lua
+++ b/tests/unit/buffer_edit_spec.lua
@@ -143,22 +143,6 @@ describe("buffer_edit.streaming", function()
     end)
 end)

-describe("buffer_edit.progress indicator", function()
-    it("set_progress_line writes the text at the handle's line", function()
-        local b = mk_buf({ "💬: q", "🤖: [A]", "" })
-        local h = be.make_handle(b, 2)
-        be.set_progress_line(h, "🔎 working...")
-        assert.equals("🔎 working...", buf_lines(b)[3])
-    end)
-
-    it("clear_progress_lines deletes count lines starting at the handle", function()
-        local b = mk_buf({ "before", "p1", "p2", "after" })
-        local h = be.make_handle(b, 1)
-        be.clear_progress_lines(h, 2)
-        assert.same({ "before", "after" }, buf_lines(b))
-    end)
-end)
-
 describe("buffer_edit.cancellation cleanup", function()
     it("delete_lines_after deletes n lines starting at line_0_indexed", function()
         local b = mk_buf({ "a", "b", "c", "d" })
diff --git a/tests/unit/chat_presentation_spec.lua b/tests/unit/chat_presentation_spec.lua
new file mode 100644
index 0000000..b29ac8b
--- /dev/null
+++ b/tests/unit/chat_presentation_spec.lua
@@ -0,0 +1,506 @@
+local presentation = require("parley.chat_presentation")
+
+local function initial(opts)
+    opts = opts or {}
+    opts.now_ms = opts.now_ms or 0
+    opts.verbs = opts.verbs or { "brewing", "cooking", "dragon-slaying" }
+    opts.verb_index = opts.verb_index or 1
+    return presentation.initial(opts)
+end
+
+local function transition(state, event)
+    local next_state, actions = presentation.transition(state, event)
+    return next_state, actions
+end
+
+local function reveal(state, now_ms)
+    return transition(state, { type = "reveal_due", now_ms = now_ms or 1000 })
+end
+
+describe("chat presentation controller", function()
+    it("initializes one silent leg with deterministic deadlines and verb", function()
+        local state = initial({ now_ms = 25, verbs = { "brewing", "cooking" }, verb_index = 2 })
+
+        assert.are.same({
+            phase = "waiting",
+            verbs = { "brewing", "cooking" },
+            verb_index = 2,
+            verb = "cooking",
+            reveal_at = 1025,
+            minimum_at = 2025,
+            verb_due_at = 15025,
+            last_activity_at = 25,
+            staged_count = 0,
+        }, state)
+    end)
+
+    it("releases visible content before reveal without ever showing", function()
+        local state = initial()
+        local released, actions = transition(state, {
+            type = "content",
+            now_ms = 999,
+            qid = "q",
+            chunk = "hello",
+        })
+
+        assert.are.equal("released", released.phase)
+        assert.are.same({ { type = "emit_content", qid = "q", chunk = "hello" } }, actions)
+        assert.are.equal("waiting", state.phase)
+        assert.are.equal(0, state.staged_count)
+    end)
+
+    it("releases meaningful progress before reveal without showing", function()
+        local released, actions = transition(initial(), {
+            type = "progress",
+            now_ms = 500,
+            message = "Reasoning: checking",
+        })
+
+        assert.are.equal("released", released.phase)
+        assert.are.same({ { type = "render_status", message = "Reasoning: checking" } }, actions)
+    end)
+
+    it("reveals playful status and stages visible events in callback order", function()
+        local waiting = initial()
+        local showing, reveal_actions = reveal(waiting)
+        local with_content, content_actions = transition(showing, {
+            type = "content",
+            now_ms = 1200,
+            qid = "q",
+            chunk = "hello",
+        })
+        local staged, progress_actions = transition(with_content, {
+            type = "progress",
+            now_ms = 1300,
+            message = "Searching web... query",
+        })
+
+        assert.are.equal("showing", showing.phase)
+        assert.are.same({ { type = "show_playful", verb = "brewing" } }, reveal_actions)
+        assert.are.same({}, content_actions)
+        assert.are.same({}, progress_actions)
+        assert.are.equal(2, staged.staged_count)
+        assert.are.equal("progress", staged.staged_tail.event.type)
+        assert.are.equal("content", staged.staged_tail.previous.event.type)
+        assert.are.equal(0, showing.staged_count)
+        assert.is_nil(showing.staged_tail)
+    end)
+
+    it("starts the minimum-visible window when a delayed reveal is delivered", function()
+        local showing = select(1, reveal(initial(), 1900))
+        local staged, actions = transition(showing, {
+            type = "content", now_ms = 2000, qid = "q", chunk = "wait",
+        })
+
+        assert.are.equal(2900, showing.minimum_at)
+        assert.are.equal("showing", staged.phase)
+        assert.are.same({}, actions)
+    end)
+
+    it("flushes staged output once at the minimum deadline", function()
+        local showing = select(1, reveal(initial()))
+        local staged = select(1, transition(showing, {
+            type = "content", now_ms = 1200, qid = "q", chunk = "one",
+        }))
+        staged = select(1, transition(staged, {
+            type = "progress", now_ms = 1300, message = "Reasoning: two",
+        }))
+        local released, actions = transition(staged, { type = "minimum_due", now_ms = 2000 })
+
+        assert.are.equal("released", released.phase)
+        assert.are.equal(0, released.staged_count)
+        assert.is_nil(released.staged_tail)
+        assert.are.same({
+            { type = "hide" },
+            { type = "emit_content", qid = "q", chunk = "one" },
+            { type = "render_status", message = "Reasoning: two" },
+        }, actions)
+
+        local still_released, later = transition(released, { type = "minimum_due", now_ms = 2000 })
+        assert.are.equal("released", still_released.phase)
+        assert.are.same({}, later)
+    end)
+
+    it("visible output arriving at or after minimum hides then flushes", function()
+        local showing = select(1, reveal(initial()))
+        local released, actions = transition(showing, {
+            type = "content", now_ms = 2000, qid = "q", chunk = "now",
+        })
+
+        assert.are.equal("released", released.phase)
+        assert.are.same({
+            { type = "hide" },
+            { type = "emit_content", qid = "q", chunk = "now" },
+        }, actions)
+    end)
+
+    it("shares a persistent staged chain on O(1) append and visits each node once on flush", function()
+        local showing = select(1, reveal(initial()))
+        local previous = showing
+        for index = 1, 64 do
+            local appended = select(1, transition(previous, {
+                type = "content", now_ms = 1200, qid = "q", chunk = tostring(index),
+            }))
+            assert.are.equal(index, appended.staged_count)
+            assert.are.equal(previous.staged_tail, appended.staged_tail.previous)
+            assert.are.equal(index - 1, previous.staged_count)
+            previous = appended
+        end
+
+        local visits = {}
+        local tail = nil
+        for index = 1, 8 do
+            visits[index] = 0
+            local backing = {
+                event = { type = "content", qid = "q", chunk = tostring(index) },
+                previous = tail,
+            }
+            tail = setmetatable({}, {
+                __index = function(_, key)
+                    if key == "event" then
+                        visits[index] = visits[index] + 1
+                    end
+                    return backing[key]
+                end,
+            })
+        end
+        local instrumented = {}
+        for key, value in pairs(showing) do
+            instrumented[key] = value
+        end
+        instrumented.staged_tail = tail
+        instrumented.staged_count = 8
+
+        local released, actions = transition(instrumented, { type = "minimum_due", now_ms = 2000 })
+        assert.are.equal("released", released.phase)
+        assert.are.equal(9, #actions)
+        for index = 1, 8 do
+            assert.are.equal(tostring(index), actions[index + 1].chunk)
+            assert.are.equal(1, visits[index])
+        end
+    end)
+
+    it("keeps showing after minimum when no visible event or completion exists", function()
+        local showing = select(1, reveal(initial()))
+        local unchanged, actions = transition(showing, { type = "minimum_due", now_ms = 2000 })
+
+        assert.are.equal("showing", unchanged.phase)
+        assert.are.same({}, actions)
+    end)
+
+    it("rotates to a non-current requested verb on activity and resets idle deadline", function()
+        local showing = select(1, reveal(initial()))
+        local rotated, actions = transition(showing, {
+            type = "activity", now_ms = 1400, verb_index = 1,
+        })
+
+        assert.are.equal(2, rotated.verb_index)
+        assert.are.equal("cooking", rotated.verb)
+        assert.are.equal(1400, rotated.last_activity_at)
+        assert.are.equal(16400, rotated.verb_due_at)
+        assert.are.same({ { type = "show_playful", verb = "cooking" } }, actions)
+    end)
+
+    it("rotates on idle but spinner ticks never rotate the verb", function()
+        local showing = select(1, reveal(initial()))
+        local ticked, tick_actions = transition(showing, { type = "spinner_tick", now_ms = 1500 })
+        local idled, idle_actions = transition(ticked, {
+            type = "idle", now_ms = 15000, verb_index = 3,
+        })
+
+        assert.are.equal(showing.verb_index, ticked.verb_index)
+        assert.are.equal(showing.verb_due_at, ticked.verb_due_at)
+        assert.are.same({}, tick_actions)
+        assert.are.equal(3, idled.verb_index)
+        assert.are.equal("dragon-slaying", idled.verb)
+        assert.are.equal(30000, idled.verb_due_at)
+        assert.are.same({ { type = "show_playful", verb = "dragon-slaying" } }, idle_actions)
+    end)
+
+    it("ignores an idle callback made stale by later activity", function()
+        local showing = select(1, reveal(initial()))
+        local active = select(1, transition(showing, {
+            type = "activity", now_ms = 14000, verb_index = 2,
+        }))
+        local unchanged, actions = transition(active, {
+            type = "idle", now_ms = 15000, verb_index = 3,
+        })
+
+        assert.are.equal(2, unchanged.verb_index)
+        assert.are.equal(29000, unchanged.verb_due_at)
+        assert.are.same({}, actions)
+    end)
+
+    it("requires timestamps on timing-sensitive events", function()
+        assert.has_error(function()
+            transition(select(1, reveal(initial())), { type = "activity", verb_index = 2 })
+        end, "activity event requires now_ms")
+    end)
+
+    it("continues a tool-only completion immediately before reveal", function()
+        local finished, actions = transition(initial(), {
+            type = "complete", now_ms = 500, completion = "run-tool", tool_only = true,
+        })
+
+        assert.are.equal("finished", finished.phase)
+        assert.are.same({ { type = "continue_completion", completion = "run-tool" } }, actions)
+    end)
+
+    it("defers a shown tool-only completion until minimum and hides first", function()
+        local showing = select(1, reveal(initial()))
+        local deferred, immediate = transition(showing, {
+            type = "complete", now_ms = 1500, completion = "run-tool", tool_only = true,
+        })
+        local finished, actions = transition(deferred, { type = "minimum_due", now_ms = 2000 })
+
+        assert.are.equal("showing", deferred.phase)
+        assert.are.same({}, immediate)
+        assert.are.equal("finished", finished.phase)
+        assert.are.same({
+            { type = "hide" },
+            { type = "continue_completion", completion = "run-tool" },
+        }, actions)
+    end)
+
+    it("flushes staged visible output before a deferred completion", function()
+        local showing = select(1, reveal(initial()))
+        local staged = select(1, transition(showing, {
+            type = "content", now_ms = 1200, qid = "q", chunk = "partial",
+        }))
+        local deferred = select(1, transition(staged, {
+            type = "complete", now_ms = 1300, completion = "finish",
+        }))
+        local finished, actions = transition(deferred, { type = "minimum_due", now_ms = 2000 })
+
+        assert.are.equal("finished", finished.phase)
+        assert.are.same({
+            { type = "hide" },
+            { type = "emit_content", qid = "q", chunk = "partial" },
+            { type = "continue_completion", completion = "finish" },
+        }, actions)
+    end)
+
+    it("honors minimum duration for an empty shown success", function()
+        local showing = select(1, reveal(initial()))
+        local deferred = select(1, transition(showing, {
+            type = "complete", now_ms = 1100, completion = "empty",
+        }))
+        local finished, actions = transition(deferred, { type = "minimum_due", now_ms = 2000 })
+
+        assert.are.equal("finished", finished.phase)
+        assert.are.same({
+            { type = "hide" },
+            { type = "continue_completion", completion = "empty" },
+        }, actions)
+    end)
+
+    it("remembers a nil-payload completion until the minimum deadline", function()
+        local showing = select(1, reveal(initial()))
+        local deferred, immediate = transition(showing, {
+            type = "complete", now_ms = 1100, completion = nil,
+        })
+        local finished, actions = transition(deferred, { type = "minimum_due", now_ms = 2000 })
+
+        assert.are.equal("showing", deferred.phase)
+        assert.is_true(deferred.completion_pending)
+        assert.are.same({}, immediate)
+        assert.are.equal("finished", finished.phase)
+        assert.are.same({
+            { type = "hide" },
+            { type = "continue_completion" },
+        }, actions)
+    end)
+
+    it("finishes a nil-payload completion at minimum and ignores later callbacks", function()
+        local showing = select(1, reveal(initial()))
+        local finished, actions = transition(showing, {
+            type = "complete", now_ms = 2000, completion = nil,
+        })
+        local later, later_actions = transition(finished, {
+            type = "content", now_ms = 2000, qid = "q", chunk = "late",
+        })
+
+        assert.are.equal("finished", finished.phase)
+        assert.are.same({
+            { type = "hide" },
+            { type = "continue_completion" },
+        }, actions)
+        assert.are.equal(finished, later)
+        assert.are.same({}, later_actions)
+    end)
+
+    local terminal_cases = {
+        { name = "owned failure", event = { type = "failure", owns_transcript = true, error = "failed" } },
+        { name = "unowned failure", event = { type = "failure", owns_transcript = false, error = "failed" } },
+        { name = "cancel", event = { type = "cancel" } },
+        { name = "stale", event = { type = "stale" } },
+        { name = "invalid", event = { type = "invalid" } },
+    }
+    local phase_cases = {
+        { name = "waiting", make = function() return initial() end },
+        { name = "showing", make = function() return select(1, reveal(initial())) end },
+        { name = "released", make = function()
+            return select(1, transition(initial(), {
+                type = "content", now_ms = 500, qid = "q", chunk = "visible",
+            }))
+        end },
+    }
+    for _, phase_case in ipairs(phase_cases) do
+        for _, terminal_case in ipairs(terminal_cases) do
+            it(terminal_case.name .. " terminates " .. phase_case.name .. " with phase-appropriate actions", function()
+                local state = phase_case.make()
+                if phase_case.name == "showing" then
+                    state = select(1, transition(state, {
+                        type = "content", now_ms = 1200, qid = "q", chunk = "partial",
+                    }))
+                end
+                local event = {}
+                for key, value in pairs(terminal_case.event) do
+                    event[key] = value
+                end
+                event.now_ms = 1300
+                local finished, actions = transition(state, event)
+
+                local expected = {}
+                if phase_case.name == "showing" then
+                    expected[#expected + 1] = { type = "hide" }
+                end
+                if terminal_case.event.owns_transcript then
+                    if phase_case.name == "showing" then
+                        expected[#expected + 1] = { type = "emit_content", qid = "q", chunk = "partial" }
+                    end
+                    expected[#expected + 1] = { type = "surface_failure", error = "failed" }
+                end
+                assert.are.equal("finished", finished.phase)
+                assert.are.equal(0, finished.staged_count)
+                assert.is_nil(finished.staged_tail)
+                assert.are.same(expected, actions)
+
+                local later, later_actions = transition(finished, {
+                    type = "content", now_ms = 1400, qid = "q", chunk = "late",
+                })
+                assert.are.equal(finished, later)
+                assert.are.same({}, later_actions)
+            end)
+        end
+    end
+
+    it("events after a terminal transition are no-ops", function()
+        local finished = select(1, transition(initial(), {
+            type = "complete", now_ms = 100, completion = "done",
+        }))
+        local later, actions = transition(finished, {
+            type = "content", now_ms = 200, qid = "q", chunk = "late",
+        })
+
+        assert.are.equal(finished, later)
+        assert.are.same({}, actions)
+    end)
+
+    it("same-deadline callback order decides reveal versus direct release exactly once", function()
+        local waiting = initial()
+        local direct, direct_actions = transition(waiting, {
+            type = "content", now_ms = 1000, qid = "q", chunk = "first",
+        })
+        local direct_after_timer, timer_actions = transition(direct, {
+            type = "reveal_due", now_ms = 1000,
+        })
+
+        assert.are.equal("released", direct_after_timer.phase)
+        assert.are.same({ { type = "emit_content", qid = "q", chunk = "first" } }, direct_actions)
+        assert.are.same({}, timer_actions)
+
+        local shown, show_actions = transition(initial(), { type = "reveal_due", now_ms = 1000 })
+        local staged, staged_actions = transition(shown, {
+            type = "content", now_ms = 1000, qid = "q", chunk = "second",
+        })
+        assert.are.equal("showing", staged.phase)
+        assert.are.same({ { type = "show_playful", verb = "brewing" } }, show_actions)
+        assert.are.same({}, staged_actions)
+    end)
+
+    it("same-deadline callback order flushes once", function()
+        local showing = select(1, reveal(initial()))
+        local staged = select(1, transition(showing, {
+            type = "content", now_ms = 1500, qid = "q", chunk = "one",
+        }))
+        local released, timer_actions = transition(staged, { type = "minimum_due", now_ms = 2000 })
+        local after_visible, visible_actions = transition(released, {
+            type = "content", now_ms = 2000, qid = "q", chunk = "two",
+        })
+
+        assert.are.same({
+            { type = "hide" },
+            { type = "emit_content", qid = "q", chunk = "one" },
+        }, timer_actions)
+        assert.are.same({ { type = "emit_content", qid = "q", chunk = "two" } }, visible_actions)
+        assert.are.equal("released", after_visible.phase)
+
+        local shown_again = select(1, reveal(initial()))
+        local at_min, visible_first = transition(shown_again, {
+            type = "content", now_ms = 2000, qid = "q", chunk = "first",
+        })
+        local after_timer, timer_second = transition(at_min, { type = "minimum_due", now_ms = 2000 })
+        assert.are.same({
+            { type = "hide" },
+            { type = "emit_content", qid = "q", chunk = "first" },
+        }, visible_first)
+        assert.are.same({}, timer_second)
+        assert.are.equal("released", after_timer.phase)
+    end)
+end)
+
+describe("progress_message", function()
+    it("accumulates and compacts reasoning detail fragments", function()
+        local state, first = presentation.progress_message({}, {
+            phase = "reasoning", kind = "reasoning", block_type = "thinking",
+            message = "Reasoning...", text = "  Think\n",
+        })
+        local continued, second = presentation.progress_message(state, {
+            phase = "reasoning", kind = "reasoning", block_type = "thinking",
+            message = "Reasoning...", text = "  carefully  ",
+        })
+
+        assert.are.equal("Reasoning: Think ", first)
+        assert.are.equal("Reasoning: Think carefully ", second)
+        assert.are.equal("  Think\n  carefully  ", continued.text)
+    end)
+
+    it("uses the provider message or fallback for tool detail", function()
+        local state, with_base = presentation.progress_message({}, {
+            phase = "tooling", kind = "tool_update", tool = "web_search",
+            block_type = "tool_calls_delta", message = "Searching web...", text = "parley",
+        })
+        local _, fallback = presentation.progress_message(state, {
+            phase = "tooling", kind = "tool_update", tool = "read",
+            block_type = "tool_calls_delta", text = "README",
+        })
+
+        assert.are.equal("Searching web... parley", with_base)
+        assert.are.equal("Working... README", fallback)
+    end)
+
+    it("resets accumulation when the detail key changes", function()
+        local state = select(1, presentation.progress_message({}, {
+            phase = "tooling", kind = "tool_update", tool = "web_search",
+            block_type = "input", message = "Searching web...", text = "first",
+        }))
+        local changed, message = presentation.progress_message(state, {
+            phase = "tooling", kind = "tool_update", tool = "web_search",
+            block_type = "result", message = "Searching web...", text = "second",
+        })
+
+        assert.are.equal("second", changed.text)
+        assert.are.equal("Searching web... second", message)
+    end)
+
+    it("clears detail state when an event has no detail", function()
+        local state = select(1, presentation.progress_message({}, {
+            phase = "reasoning", kind = "reasoning", text = "thinking",
+        }))
+        local cleared, message = presentation.progress_message(state, { message = "Done" })
+
+        assert.are.same({}, cleared)
+        assert.are.equal("Done", message)
+    end)
+end)
diff --git a/tests/unit/dispatcher_query_spec.lua b/tests/unit/dispatcher_query_spec.lua
index a300921..ad3d072 100644
--- a/tests/unit/dispatcher_query_spec.lua
+++ b/tests/unit/dispatcher_query_spec.lua
@@ -15,6 +15,7 @@ local dispatcher = require("parley.dispatcher")
 local vault = require("parley.vault")
 local tasker = require("parley.tasker")
 local helpers = require("parley.helper")
+local logger = require("parley.logger")

 describe("dispatcher.query internals", function()
     local original_vault_get_secret
@@ -22,6 +23,8 @@ describe("dispatcher.query internals", function()
     local original_tasker_run
     local original_tasker_set_query
     local captured_out_reader
+    local captured_terminal
+    local captured_args
     local captured_qid
     local handler_calls
     local on_exit_calls
@@ -37,6 +40,8 @@ describe("dispatcher.query internals", function()

         -- Reset capture variables
         captured_out_reader = nil
+        captured_terminal = nil
+        captured_args = nil
         captured_qid = nil
         handler_calls = {}
         on_exit_calls = {}
@@ -63,6 +68,8 @@ describe("dispatcher.query internals", function()
         -- Mock tasker.run to capture out_reader
         tasker.run = function(buf, cmd, args, callback, out_reader, err_reader)
             captured_out_reader = out_reader
+            captured_terminal = callback
+            captured_args = args
         end

         -- Set up minimal fake providers with names that match the code
@@ -109,6 +116,20 @@ describe("dispatcher.query internals", function()
         end
     end

+    local function status_stderr(status, prefix)
+        local write_out
+        for i, arg in ipairs(captured_args) do
+            if arg == "--write-out" then
+                write_out = captured_args[i + 1]
+                break
+            end
+        end
+        assert.is_truthy(write_out)
+        local sentinel = write_out:match("%%{stderr}(.-)%%{http_code}")
+        assert.is_truthy(sentinel)
+        return (prefix or "") .. sentinel .. status .. "\n"
+    end
+
     describe("Group A: out_reader chunk reassembly", function()
         it("A1: single complete chunk emits content to handler", function()
             local handler = make_handler()
@@ -256,6 +277,8 @@ describe("dispatcher.query internals", function()
             captured_out_reader(nil, clean_fixture .. "\n")
             captured_out_reader(nil, nil) -- EOF

+            captured_terminal(0, 0, "", status_stderr("200"), nil)
+
             -- Check metrics (flexible assertions - exact values depend on fixture)
             local metrics = tasker.get_cache_metrics()
             -- input_tokens should be present and > 0
@@ -285,6 +308,8 @@ describe("dispatcher.query internals", function()
             captured_out_reader(nil, chunk)
             captured_out_reader(nil, nil) -- EOF

+            captured_terminal(0, 0, "", status_stderr("200"), nil)
+
             -- Metrics should be reset to nil
             local metrics = tasker.get_cache_metrics()
             assert.is_nil(metrics.input)
@@ -371,6 +396,7 @@ describe("dispatcher.query internals", function()
             local chunk = 'data: {"choices":[{"delta":{"content":"Test"}}]}\n'
             captured_out_reader(nil, chunk)
             captured_out_reader(nil, nil) -- EOF
+            captured_terminal(0, 0, "", status_stderr("200"), nil)

             -- on_exit should have been called once
             assert.equals(1, #on_exit_calls)
@@ -389,6 +415,7 @@ describe("dispatcher.query internals", function()
             local chunk = 'data: {"choices":[{"delta":{"content":"Hello world"}}]}\n'
             captured_out_reader(nil, chunk)
             captured_out_reader(nil, nil) -- EOF
+            captured_terminal(0, 0, "", status_stderr("200"), nil)

             -- Need to wait for vim.schedule to execute
             vim.wait(100, function()
@@ -572,4 +599,312 @@ describe("dispatcher.query internals", function()
             assert.is_not_nil(captured_out_reader) -- query() ran (tasker.run captured)
         end)
     end)
+
+    describe("Group I: raw activity and drained transport terminal", function()
+        it("I1: emits one activity per SSE record before semantic callbacks", function()
+            local observed = {}
+            local handler = function() table.insert(observed, "content") end
+            local progress = function() table.insert(observed, "progress") end
+            local activity = function() table.insert(observed, "activity") end
+            dispatcher.query(nil, "openai", { model = "gpt-4", messages = {} },
+                handler, nil, nil, progress, nil, activity)
+
+            captured_out_reader(nil,
+                'event: message\n: comment\ndata: {"choices":[{"delta":{"reasoning_content":"x"}}]}\n' ..
+                'data: {"choices":[{"delta":{"content":"hi"}}]}\n\n' ..
+                'extension: value\ndata: {"choices":[{"delta":{"content":"!"}}]}\n\n')
+            assert.same({ "activity", "progress", "content", "activity", "content" }, observed)
+        end)
+
+        it("I2: counts structural JSONL lines independently and EOF does not duplicate", function()
+            local activities = 0
+            local content = {}
+            dispatcher.query(nil, "openai", { model = "m", messages = {} }, function(_qid, chunk)
+                table.insert(content, chunk)
+            end,
+                nil, nil, nil, nil, function() activities = activities + 1 end)
+            captured_out_reader(nil,
+                '{"choices":[{"delta":{"content":"a"}}]}\n {"choices":[{"delta":{"content":"b"}}]}')
+            assert.equals(1, activities)
+            assert.same({ "a" }, content)
+            captured_out_reader(nil, nil)
+            assert.equals(2, activities)
+            assert.same({ "a", "b" }, content)
+        end)
+
+        it("I3: waits for drained 2xx terminal before legacy completion", function()
+            local events = {}
+            dispatcher.query(nil, "openai", { model = "gpt-4", messages = {} }, function() end,
+                function() table.insert(events, "exit") end,
+                function() table.insert(events, "callback") end)
+            captured_out_reader(nil, 'data: {"choices":[{"delta":{"content":"ok"}}]}')
+            captured_out_reader(nil, nil)
+            assert.same({}, events)
+            captured_terminal(0, 0, 'data: {"choices":[{"delta":{"content":"ok"}}]}',
+                status_stderr("200"), nil)
+            assert.equals("exit", events[1])
+            assert.is_true(vim.wait(100, function() return #events == 2 end, 10))
+            assert.same({ "exit", "callback" }, events)
+        end)
+
+        it("I4: reports HTTP and process failures once without legacy completion", function()
+            local errors = {}
+            local legacy = 0
+            dispatcher.query(nil, "openai", { model = "gpt-4", messages = {} }, function() end,
+                function() legacy = legacy + 1 end, function() legacy = legacy + 1 end,
+                nil, nil, nil, function(_qid, failure) table.insert(errors, failure) end)
+            captured_out_reader(nil, "denied")
+            captured_out_reader(nil, nil)
+            captured_terminal(0, 0, "denied", status_stderr("401", "curl warning\n"), nil)
+            assert.equals(1, #errors)
+            assert.equals(401, errors[1].http_status)
+            assert.equals("denied", errors[1].body)
+            assert.equals("curl warning\n", errors[1].stderr)
+            assert.equals(0, legacy)
+
+            captured_terminal(7, 0, "denied", status_stderr("000"), nil)
+            assert.equals(1, #errors)
+        end)
+
+        it("I5: missing status is an opted-in IO failure and legacy fallback otherwise", function()
+            local failure
+            dispatcher.query(nil, "openai", { model = "gpt-4", messages = {} }, function() end,
+                nil, nil, nil, nil, nil, function(_qid, value) failure = value end)
+            captured_out_reader(nil, nil)
+            captured_terminal(0, 0, "", "plain stderr", nil)
+            assert.is_truthy(failure.io_error)
+
+            local exits = 0
+            dispatcher.query(nil, "openai", { model = "gpt-4", messages = {} }, function() end,
+                function() exits = exits + 1 end)
+            captured_out_reader(nil, nil)
+            captured_terminal(22, 0, "", status_stderr("500"), nil)
+            assert.equals(1, exits)
+        end)
+
+        it("I6: pre-start vault and task launch failures share once-guarded abort", function()
+            local aborts = 0
+            vault.run_with_secret = function(_provider, _success, on_error)
+                on_error("missing")
+                on_error("duplicate")
+            end
+            dispatcher.query(nil, "openai", { model = "gpt-4", messages = {} }, function() end,
+                nil, nil, nil, function() aborts = aborts + 1 end)
+            assert.equals(1, aborts)
+
+            vault.run_with_secret = function(_provider, success) success() end
+            tasker.run = function(_buf, _cmd, _args, _terminal, _out, _err, on_start_error)
+                on_start_error("busy")
+                on_start_error("duplicate")
+            end
+            dispatcher.query(nil, "openai", { model = "gpt-4", messages = {} }, function() end,
+                nil, nil, nil, function() aborts = aborts + 1 end)
+            assert.equals(2, aborts)
+        end)
+
+        it("I7: flushes an unterminated semantic line after a read error before failure", function()
+            local events = {}
+            local failure
+            local body = 'data: {"choices":[{"delta":{"content":"partial"}}]}'
+            dispatcher.query(nil, "openai", { model = "gpt-4", messages = {} },
+                function(_qid, content) table.insert(events, "content:" .. content) end,
+                nil, nil, nil, nil, nil, function(_qid, value)
+                    table.insert(events, "failure")
+                    failure = value
+                end)
+            captured_out_reader(nil, body)
+            captured_out_reader("read boom", nil)
+            assert.same({}, events)
+            captured_out_reader(nil, nil)
+            assert.same({ "content:partial" }, events)
+            captured_terminal(9, 0, body, status_stderr("000"), "stdout: read boom")
+            assert.same({ "content:partial", "failure" }, events)
+            assert.equals(body, failure.body)
+            assert.is_truthy(failure.io_error)
+        end)
+
+        it("I8: reports partial SSE plus HTTP 500 with byte-exact body", function()
+            local chunks = {}
+            local failure
+            local body = 'data: {"choices":[{"delta":{"content":"partial"}}]}'
+            dispatcher.query(nil, "openai", { model = "gpt-4", messages = {} },
+                function(_qid, content) table.insert(chunks, content) end,
+                nil, nil, nil, nil, nil, function(_qid, value) failure = value end)
+            captured_out_reader(nil, body)
+            captured_out_reader(nil, nil)
+            captured_terminal(0, 0, body, status_stderr("500"), nil)
+            assert.same({ "partial" }, chunks)
+            assert.equals(body, failure.body)
+            assert.equals(500, failure.http_status)
+        end)
+
+        it("I9: reports a process terminal failure independently and only once", function()
+            local failures = {}
+            dispatcher.query(nil, "openai", { model = "gpt-4", messages = {} }, function() end,
+                nil, nil, nil, nil, nil, function(_qid, value)
+                    table.insert(failures, value)
+                end)
+            captured_out_reader(nil, nil)
+            captured_terminal(28, 9, "", status_stderr("000"), nil)
+            captured_terminal(0, 0, "", status_stderr("200"), nil)
+            assert.equals(1, #failures)
+            assert.equals(28, failures[1].code)
+            assert.equals(9, failures[1].signal)
+            assert.equals(0, failures[1].http_status)
+        end)
+
+        it("I10: treats malformed as well as missing status trailers as IO errors", function()
+            local failures = {}
+            dispatcher.query(nil, "openai", { model = "gpt-4", messages = {} }, function() end,
+                nil, nil, nil, nil, nil, function(_qid, value)
+                    table.insert(failures, value)
+                end)
+            local malformed = status_stderr("200"):gsub("200\n$", "20x\n")
+            captured_out_reader(nil, nil)
+            captured_terminal(0, 0, "", malformed, nil)
+            assert.is_truthy(failures[1].io_error)
+
+            dispatcher.query(nil, "openai", { model = "gpt-4", messages = {} }, function() end,
+                nil, nil, nil, nil, nil, function(_qid, value)
+                    table.insert(failures, value)
+                end)
+            captured_out_reader(nil, nil)
+            captured_terminal(0, 0, "", "", nil)
+            assert.is_truthy(failures[2].io_error)
+        end)
+
+        it("I11: legacy failure logging exposes only bounded metadata", function()
+            local marker = "AUTHORIZATION_SECRET_MARKER"
+            local body = 'data: {"choices":[{"delta":{"content":"' .. marker .. '"}}]}\n'
+            local stderr_prefix = "Authorization: Bearer " .. marker .. "\n"
+            local messages = {}
+            local notifications = {}
+            local original_debug = logger.debug
+            local original_error = logger.error
+            local original_warning = logger.warning
+            local original_notify = vim.notify
+            local function capture(message) table.insert(messages, tostring(message)) end
+            logger.debug = capture
+            logger.error = capture
+            logger.warning = capture
+            vim.notify = function(message) table.insert(notifications, tostring(message)) end
+
+            local ok, err = pcall(function()
+                dispatcher.query(nil, "openai", { model = "gpt-4", messages = {} }, function() end)
+                captured_out_reader(nil, body)
+                captured_out_reader(nil, nil)
+                captured_terminal(0, 0, body, status_stderr("500", stderr_prefix), nil)
+            end)
+
+            logger.debug = original_debug
+            logger.error = original_error
+            logger.warning = original_warning
+            vim.notify = original_notify
+            assert.is_true(ok, tostring(err))
+
+            local combined = table.concat(messages, "\n") .. table.concat(notifications, "\n")
+            assert.is_falsy(combined:find(marker, 1, true))
+            local failure_log
+            for _, message in ipairs(messages) do
+                if message:find("query failed", 1, true) then failure_log = message end
+                assert.is_true(#message < 512, "log message must remain bounded")
+            end
+            assert.is_truthy(failure_log)
+            assert.is_truthy(failure_log:find("body_bytes=" .. #body, 1, true))
+            assert.is_truthy(failure_log:find("stderr_bytes=" .. #stderr_prefix, 1, true))
+        end)
+
+        it("I12: throwing on_exit cannot block namespace cleanup or assembled callback", function()
+            local marker = "RESPONSE_SECRET_MARKER"
+            local body = 'data: {"choices":[{"delta":{"content":"' .. marker .. '"}}]}\n'
+            local callback_calls = 0
+            local exit_calls = 0
+            local logs = {}
+            local buf = vim.api.nvim_create_buf(false, true)
+            local ns = vim.api.nvim_create_namespace("parley-dispatcher-throwing-exit")
+            vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {})
+            local original_error = logger.error
+            logger.error = function(message) table.insert(logs, tostring(message)) end
+
+            dispatcher.query(buf, "openai", { model = "gpt-4", messages = {} }, function() end,
+                function()
+                    exit_calls = exit_calls + 1
+                    error("on_exit exploded")
+                end,
+                function(response)
+                    callback_calls = callback_calls + 1
+                    assert.equals(marker, response)
+                end)
+            local qt = tasker.get_query(captured_qid)
+            qt.ns_id = ns
+            captured_out_reader(nil, body)
+            captured_out_reader(nil, nil)
+            local ok, err = pcall(captured_terminal, 0, 0, body, status_stderr("200"), nil)
+            local completed = vim.wait(100, function()
+                return callback_calls == 1 and #vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {}) == 0
+            end, 5)
+
+            logger.error = original_error
+            pcall(vim.api.nvim_buf_delete, buf, { force = true })
+            assert.is_true(ok, tostring(err))
+            assert.is_true(completed)
+            assert.equals(1, exit_calls)
+            assert.equals(1, callback_calls)
+            local combined = table.concat(logs, "\n")
+            assert.is_truthy(combined:find("on_exit", 1, true))
+            assert.is_falsy(combined:find(marker, 1, true))
+            assert.is_true(#combined < 512)
+        end)
+
+        it("I13: contains and logs a throwing scheduled assembled callback", function()
+            local callback_calls = 0
+            local logs = {}
+            local original_error = logger.error
+            logger.error = function(message) table.insert(logs, tostring(message)) end
+            dispatcher.query(nil, "openai", { model = "gpt-4", messages = {} }, function() end,
+                nil, function()
+                    callback_calls = callback_calls + 1
+                    error("assembled callback exploded")
+                end)
+            captured_out_reader(nil, nil)
+            captured_terminal(0, 0, "", status_stderr("200"), nil)
+            assert.is_true(vim.wait(100, function() return callback_calls == 1 end, 5))
+            vim.wait(20, function() return false end, 5)
+            logger.error = original_error
+
+            assert.equals(1, callback_calls)
+            local combined = table.concat(logs, "\n")
+            assert.is_truthy(combined:find("assembled response callback", 1, true))
+            assert.is_true(#combined < 512)
+        end)
+
+        for _, terminal_kind in ipairs({ "success", "error_fallback" }) do
+            for _, surfaces in ipairs({
+                { name = "on_exit only", on_exit = true },
+                { name = "callback only", callback = true },
+                { name = "both", on_exit = true, callback = true },
+                { name = "neither" },
+            }) do
+                it("legacy " .. terminal_kind .. " invokes " .. surfaces.name .. " once after drain", function()
+                    local events = {}
+                    local on_exit = surfaces.on_exit and function() table.insert(events, "exit") end or nil
+                    local callback = surfaces.callback and function() table.insert(events, "callback") end or nil
+                    dispatcher.query(nil, "openai", { model = "gpt-4", messages = {} }, function() end,
+                        on_exit, callback)
+                    captured_out_reader(nil, nil)
+                    assert.same({}, events)
+                    local status = terminal_kind == "success" and "200" or "500"
+                    captured_terminal(0, 0, "", status_stderr(status), nil)
+
+                    local expected = {}
+                    if surfaces.on_exit then table.insert(expected, "exit") end
+                    if surfaces.callback then
+                        assert.is_true(vim.wait(100, function() return #events == #expected + 1 end, 5))
+                        table.insert(expected, "callback")
+                    end
+                    assert.same(expected, events)
+                end)
+            end
+        end
+    end)
 end)
diff --git a/tests/unit/vault_spec.lua b/tests/unit/vault_spec.lua
index c8c20a7..6f1c1eb 100644
--- a/tests/unit/vault_spec.lua
+++ b/tests/unit/vault_spec.lua
@@ -172,6 +172,72 @@ describe("vault", function()

             tasker.run = original_run
         end)
+
+        it("B9: reports missing and empty resolver results once without success", function()
+            local successes = 0
+            local errors = {}
+            vault.resolve_secret("missing", nil, function() successes = successes + 1 end,
+                function(message) table.insert(errors, message) end)
+            assert.equals(0, successes)
+            assert.equals(1, #errors)
+
+            tasker.run = function(_buf, _cmd, _args, callback)
+                callback(0, 0, "   ", "")
+            end
+            vault.resolve_secret("empty", { "echo" }, function() successes = successes + 1 end,
+                function(message) table.insert(errors, message) end)
+            assert.equals(0, successes)
+            assert.equals(2, #errors)
+        end)
+
+        it("B10: reports resolver exit and launch rejection once", function()
+            local errors = 0
+            tasker.run = function(_buf, _cmd, _args, callback)
+                callback(7, 0, "", "bad")
+            end
+            vault.resolve_secret("exit", { "bad" }, function() error("success") end,
+                function() errors = errors + 1 end)
+            assert.equals(1, errors)
+
+            tasker.run = function(_buf, _cmd, _args, _callback, _out, _err, on_start_error)
+                on_start_error("could not start")
+                on_start_error("duplicate")
+            end
+            vault.resolve_secret("launch", { "bad" }, function() error("success") end,
+                function() errors = errors + 1 end)
+            assert.equals(2, errors)
+        end)
+
+        it("B11: rejects empty string and command inputs without launching or succeeding", function()
+            local runs = 0
+            local successes = 0
+            local errors = 0
+            tasker.run = function() runs = runs + 1 end
+
+            for _, secret in ipairs({ "", "   ", {} }) do
+                vault.resolve_secret("empty_" .. tostring(errors), secret,
+                    function() successes = successes + 1 end,
+                    function() errors = errors + 1 end)
+            end
+
+            assert.equals(0, runs)
+            assert.equals(0, successes)
+            assert.equals(3, errors)
+        end)
+
+        it("B12: never treats a stored empty string as resolved", function()
+            local successes = 0
+            local errors = 0
+            vault.add_secret("stored_empty", "")
+            vault.run_with_secret("stored_empty", function() successes = successes + 1 end,
+                function() errors = errors + 1 end)
+            vault.add_secret("stored_space", "   ")
+            vault.run_with_secret("stored_space", function() successes = successes + 1 end,
+                function() errors = errors + 1 end)
+
+            assert.equals(0, successes)
+            assert.equals(2, errors)
+        end)
     end)

     describe("Group C: run_with_secret", function()
@@ -213,6 +279,24 @@ describe("vault", function()
             end)
             assert.is_false(called)
         end)
+
+        it("C4: propagates missing and resolver failures once", function()
+            local successes = 0
+            local errors = 0
+            vault.run_with_secret("missing", function() successes = successes + 1 end,
+                function() errors = errors + 1 end)
+            assert.equals(0, successes)
+            assert.equals(1, errors)
+
+            vault.add_secret("command", { "bad" })
+            tasker.run = function(_buf, _cmd, _args, callback)
+                callback(1, 0, "", "bad")
+            end
+            vault.run_with_secret("command", function() successes = successes + 1 end,
+                function() errors = errors + 1 end)
+            assert.equals(0, successes)
+            assert.equals(2, errors)
+        end)
     end)

     describe("Group D: setup", function()
diff --git a/workshop/lessons.md b/workshop/lessons.md
index 54d90dc..d8b8d50 100644
--- a/workshop/lessons.md
+++ b/workshop/lessons.md
@@ -165,3 +165,14 @@
 - **Core-concept tables must name greppable code entities and classify the whole named boundary, not its pure subset.** #170 called conceptual `PerfSampleSet`/`PerfReport` entities PURE even though their shared harness also owned the clock, timestamp, and Neovim JSON encoder. The close review correctly treated the contradiction as architectural. Rule: before close, resolve every Core-concept row to an actual symbol/module and inspect all side effects at that location; name a deterministic function separately from its INTEGRATION shell instead of assigning purity to a conceptual bundle.
 - **A synchronous event contract must be tested through the production registration path, not an already-installed callback.** #170's lifecycle tests manually called `setup(buf)` before `BufEnter`, masking that the production classifier itself used `vim.schedule_wrap` and returned before setup; making entry direct then exposed a scheduled unload cleanup erasing classification after numeric handle reuse. Rule: for first-entry hydration, create a fresh unowned buffer, fire the real registered event, and assert state immediately on return; audit both setup and teardown wrappers for scheduling and exercise handle reuse before claiming synchronous convergence.
 - **When making a shared event callback synchronous, classify each side effect by the contract that needs synchronization.** #170 needed immediate classification, diagnostics, and structure, but moving branch-reference topic refresh with them changed timer ownership/order and broke the timer-race oracle. Rule: trace every callback side effect before changing scheduling; keep unrelated timer/UI work deferred and add the full integration suite to the synchronization change's GREEN gate.
+
+## 2026-07-13 (#182)
+- **A public callback is an untrusted lifecycle boundary: complete cleanup independently, contain exceptions, and keep diagnostics bounded.** Task 2's first transport review found that throwing readers and terminal callbacks could skip pipe closure, handle removal, or completion events; the follow-up found that raw tracebacks could still create huge notifications or expose callback input. Rule: protect each independently promised callback surface, make resource cleanup unconditional, test a throwing callback at every lifecycle seam, and log only a generic or explicitly truncated diagnostic. Never include provider bodies, stderr, or arbitrary exception text in ordinary user-facing logs.
+- **Call a process test “real” only when it actually crosses the OS process boundary.** A dispatcher test drove a captured tasker terminal callback but was named “real process failure,” obscuring that the real curl/SSE fixture belongs to a later boundary. Rule: reserve “real process” for tests that spawn the executable/fixture; name callback-driven coverage after the simulated terminal it exercises.
+- **A state transition must retire every timer owned only by the state being left, including transitions that bypass the visible state.** Task 3 canceled playful timers for `showing → released` but missed the fast `waiting → released` path, leaking the startup idle timer; its frame tick also checked buffer validity but not lease ownership. Rule: enumerate every source phase for each destination and assert the complete live-timer set after the transition. Every recurring timer callback must revalidate both resource validity and logical ownership before touching UI.
+- **Publish an object in a global ownership registry only after construction and injected validation succeed atomically.** Task 3 registered a chat session before its clock, verb chooser, and reducer initialization ran, so an initializer exception left an uncancellable half-object that blocked retries and crashed global cleanup. Rule: build and validate privately, install all terminal methods, then publish; test constructor exceptions followed by both retry and global cleanup.
+- **A one-shot timer callback can arrive before a higher-resolution logical deadline; ignoring it without rearming strands the state forever.** Task 4's real curl stress run intermittently completed the provider response while the minimum-visible extmark remained forever because libuv's millisecond timer fired fractionally before an `hrtime` deadline. Rule: use one coherent clock for timers and deadlines or, whenever a deadline callback observes `now < due`, rearm the remaining duration. Stress the real process path repeatedly; one green timing run is not evidence.
+- **Ending a presentation controller is not the same as completing its caller's lifecycle.** Task 4 initially let cancel/stale/invalid finish the extmark controller while skipping the chat shell collapse, lifecycle finalization, and lease release; the later transport error was correctly ignored and therefore could not rescue cleanup. Rule: every terminal class needs an explicit exact-once owner at each layer. UI discard hooks must release caller-owned resources without surfacing staged output or errors.
+- **Ownership conflicts must be rejected before durable mutation, including force/bypass paths.** Task 4's force respond bypassed the busy guard, inserted a second response shell, began a lease, and only then collided with the existing per-buffer presentation registry. Rule: preflight every independently owned resource before transcript/model writes; tests for force or bypass flags must assert both the error result and byte-for-byte unchanged durable state.
+- **A centralized `finish` closure provides no safety unless every fallible operation before it is protected and converges into it.** Task 5 made skill terminals exact-once, but malformed tool decoding/execution could still throw inside the scheduled completion pipeline before `finish`, stranding `_in_flight`, detached progress, and Definition's inline spinner. Rule: wrap the whole asynchronous completion body—not only callbacks—in a protected boundary; on exception log bounded metadata and call the same terminal owner. Test with malformed provider output that reaches real decode/dispatch code.
+- **A generic lifecycle test does not prove a consumer-owned transient UI seam.** Task 5's invocation table covered source failure, no agent, buffer deletion, and no-tool output, but the first Definition suite did not assert its inline spinner/timer and footnote state on those same terminals. Rule: for every consumer that supplies an `on_terminal` cleanup hook, run each materially distinct terminal through the real consumer entry and assert its owned UI/resource is gone; keep one late/repeated delivery case at that seam.
diff --git a/workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md b/workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md
index b6730b2..78c06de 100644
--- a/workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md
+++ b/workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md
@@ -93,7 +93,7 @@ All three symbols are tested without Neovim IO or mocks in `tests/unit/chat_pres
 - Create: `lua/parley/chat_presentation.lua`
 - Create: `tests/unit/chat_presentation_spec.lua`

-- [ ] **Step 1: Write failing state-table tests for fast and delayed visible output**
+- [x] **Step 1: Write failing state-table tests for fast and delayed visible output**

 Define the wished-for public API and assert actions, not internal mutation:

@@ -122,7 +122,7 @@ assert.are.same({}, staged_actions)
 assert.are.equal(1, #staged.staged)
 ```

-- [ ] **Step 2: Run the unit spec and verify RED**
+- [x] **Step 2: Run the unit spec and verify RED**

 Run:

@@ -133,15 +133,15 @@ nvim -n --headless --noplugin -u tests/minimal_init.vim \

 Expected: FAIL because `parley.chat_presentation` does not exist.

-- [ ] **Step 3: Implement `initial` and the minimal waiting/showing/released transitions**
+- [x] **Step 3: Implement `initial` and the minimal waiting/showing/released transitions**

 Use immutable plain-table returns (copy only the small state), explicit millisecond deadlines (`reveal_at = start + 1000`, `minimum_at = reveal + 1000`, `verb_due_at = last_activity + 15000`), and tagged staged events. Visible `content` and `progress` share release timing but retain their distinct payloads.

-- [ ] **Step 4: Run the unit spec and verify GREEN**
+- [x] **Step 4: Run the unit spec and verify GREEN**

 Expected: PASS for the fast path, reveal, staging, minimum release, and ordered flush tests.

-- [ ] **Step 5: Add RED tests for the complete transition matrix**
+- [x] **Step 5: Add RED tests for the complete transition matrix**

 Cover separately:

@@ -160,11 +160,11 @@ same-deadline permutations -> callback order decides exactly once

 Use a deterministic requested `verb_index`; `transition` advances to the next available non-current index rather than calling `math.random`.

-- [ ] **Step 6: Implement the remaining minimal transitions and `progress_message`**
+- [x] **Step 6: Implement the remaining minimal transitions and `progress_message`**

 Port the current reasoning/tool detail accumulation from `chat_respond.lua` into `progress_message(detail_state, event) -> new_detail_state, message`, preserving whitespace compaction and key resets.

-- [ ] **Step 7: Run the unit spec, then lint the new files**
+- [x] **Step 7: Run the unit spec, then lint the new files**

 Run the unit command above, then:

@@ -174,7 +174,7 @@ luacheck lua/parley/chat_presentation.lua tests/unit/chat_presentation_spec.lua

 Expected: PASS with no warnings.

-- [ ] **Step 8: Commit the pure core**
+- [x] **Step 8: Commit the pure core**

 ```bash
 git add lua/parley/chat_presentation.lua tests/unit/chat_presentation_spec.lua
@@ -193,7 +193,7 @@ git commit -m "#182: add pure chat presentation controller"
 - Modify: `tests/integration/topic_gen_spec.lua`
 - Modify: `tests/integration/cliproxy_caller_teardown_spec.lua`

-- [ ] **Step 1: Write RED drain-order and dispatcher callback tests**
+- [x] **Step 1: Write RED drain-order and dispatcher callback tests**

 First drive captured process-exit and pipe-reader callbacks in both permutations: stdout/stderr EOF before process exit, and process exit before stdout/stderr EOF. Assert `tasker.run` waits for all three signals, retains final fragments, invokes its public callback once, and reports read failure through an additive fifth `io_error` result.

@@ -220,7 +220,7 @@ proves its supplied assembled-response callback advances every tag and finishes
 the batch. These tests use the real consumer functions and real dispatcher,
 monkeypatching only `tasker.run` to deliver a drained nonzero transport terminal.

-- [ ] **Step 2: Run tasker and dispatcher specs and verify RED**
+- [x] **Step 2: Run tasker and dispatcher specs and verify RED**

 Run:

@@ -241,7 +241,7 @@ Expected: FAIL because `tasker.run` closes pipes at process exit instead of
 draining, `query` has no activity/error callbacks or task exit status, and the
 vault/task launch failures and real legacy consumers have no reliable terminal.

-- [ ] **Step 3: Make `tasker.run` drain-safe**
+- [x] **Step 3: Make `tasker.run` drain-safe**

 Replace process-exit-time `read_stop`/close with a production three-signal coordinator:

@@ -270,7 +270,7 @@ launch rejection through one once-guarded error closure; never run the success
 callback on those paths. Existing vault consumers that omit it remain
 backward-compatible.

-- [ ] **Step 4: Implement the additive dispatcher contract**
+- [x] **Step 4: Implement the additive dispatcher contract**

 Change the public signature only by appending callbacks:

@@ -314,7 +314,7 @@ for `generate_topic`, callback-only memory preferences, callers that supply both
 surfaces, and callers that supply neither. Callers that opt into `on_error`
 receive only that terminal and never either legacy surface.

-- [ ] **Step 5: Run dispatcher and tasker tests and verify GREEN**
+- [x] **Step 5: Run dispatcher and tasker tests and verify GREEN**

 Run:

@@ -334,7 +334,7 @@ nvim -n --headless --noplugin -u tests/minimal_init.vim \
 Expected: PASS; existing semantic progress expectations remain unchanged, and
 both real legacy consumers terminate after a failed transport.

-- [ ] **Step 6: Commit the drain and dispatcher contracts**
+- [x] **Step 6: Commit the drain and dispatcher contracts**

 ```bash
 git add lua/parley/tasker.lua lua/parley/vault.lua lua/parley/dispatcher.lua \
@@ -350,7 +350,7 @@ git commit -m "#182: expose SSE activity and transport failures"
 - Create: `lua/parley/chat_pending.lua`
 - Create: `tests/integration/chat_pending_spec.lua`

-- [ ] **Step 1: Write RED integration tests against a real scratch buffer**
+- [x] **Step 1: Write RED integration tests against a real scratch buffer**

 Create a response header line and pass a fake production-shaped clock/scheduler (`now_ms`, FIFO `enqueue`, `after`, `every`; each timer registration returns an idempotent cancel closure). Advance it rather than sleeping or calling private adapter methods, and inspect the dedicated namespace with `nvim_buf_get_extmarks(..., {details=true})`. Assert:

@@ -368,7 +368,7 @@ method there, and assert the resulting extmark/UI observation occurs later on
 the main loop with `vim.in_fast_event() == false`. This guards the real default,
 not only the injected fake queue.

-- [ ] **Step 2: Run the adapter spec and verify RED**
+- [x] **Step 2: Run the adapter spec and verify RED**

 ```bash
 nvim -n --headless --noplugin -u tests/minimal_init.vim \
@@ -377,7 +377,7 @@ nvim -n --headless --noplugin -u tests/minimal_init.vim \

 Expected: FAIL because `parley.chat_pending` does not exist.

-- [ ] **Step 3: Implement `chat_pending.start` as the only chat IO owner**
+- [x] **Step 3: Implement `chat_pending.start` as the only chat IO owner**

 The constructor accepts:

@@ -397,11 +397,11 @@ Expose `activity`, `content`, `progress`, `complete`, `failure`, and `cancel` me

 Use a dedicated namespace, `invalidate=true`, `virt_lines_above=false`, and `pcall` cleanup. Every timer callback first checks `nvim_buf_is_valid(buf)` and self-cancels the whole session when false; extmark invalidation alone does not own libuv timer closure. Reuse `require("parley.progress").SPINNER`; do not add spinner frames or chat content to `exchange_model`.

-- [ ] **Step 4: Run the adapter and pure specs and verify GREEN**
+- [x] **Step 4: Run the adapter and pure specs and verify GREEN**

 Run both Task 1 and Task 3 commands. Expected: PASS with no leaked timer warnings after Neovim exits.

-- [ ] **Step 5: Commit the chat adapter**
+- [x] **Step 5: Commit the chat adapter**

 ```bash
 git add lua/parley/chat_pending.lua tests/integration/chat_pending_spec.lua
@@ -416,7 +416,7 @@ git commit -m "#182: render staged chat progress with extmarks"
 - Create: `tests/fixtures/fake_sse_server`
 - Create: `tests/integration/chat_progress_process_spec.lua`

-- [ ] **Step 1: Rewrite the old spinner tests as RED behavioral tests**
+- [x] **Step 1: Rewrite the old spinner tests as RED behavioral tests**

 Through `parley.chat_respond`, cover:

@@ -439,11 +439,11 @@ delivery for the exhaustive timing cases. For missing-secret and launch-reject
 cases keep the real dispatcher and replace only the failing vault/task boundary,
 then inspect the real pending namespace and timer registry after abort delivery.

-- [ ] **Step 2: Run `chat_respond_spec.lua` and verify RED**
+- [x] **Step 2: Run `chat_respond_spec.lua` and verify RED**

 Expected: failures show the current immediate `🔎 … Submitting...` buffer line, web-search gating, and direct stream writes.

-- [ ] **Step 3: Add and run one process-level curl/SSE RED test**
+- [x] **Step 3: Add and run one process-level curl/SSE RED test**

 Implement `fake_sse_server` as an executable local Python HTTP server whose mode is selected by an argument/environment variable. The test starts it on a free port, points an OpenAI-compatible test provider at it, and invokes the real chat entry without monkeypatching `dispatcher.query` or `tasker.run`. Specify a delayed-stream mode that must show the virtual line, buffer first text until the minimum, then flush and complete. Add a partial-then-broken-connection mode that makes curl exit nonzero, an HTTP 401 error-body mode, and a partial-SSE-then-HTTP-500 mode. Each failure must hide the extmark first, expose any real partial text second, and notify the body/status error last; the status trailer is never visible or counted as activity. Ensure the server is reaped in teardown even on assertion failure.

@@ -458,7 +458,7 @@ Expected: FAIL against the pre-wiring chat path because the delayed response has
 no extmark-backed presentation session and the broken transport lacks the
 required chat failure ordering.

-- [ ] **Step 4: Wire one presentation session into every `M.respond` dispatcher leg**
+- [x] **Step 4: Wire one presentation session into every `M.respond` dispatcher leg**

 Delete the old `spinner_active`, spinner exchange block, buffer-line mutation, and timer code. Always create only `agent_header` + `stream_placeholder` real blocks. After `chat_lease.begin`, start `chat_pending` anchored directly at `model:block_start(target_idx, 2)` (already the response header's 0-based buffer row); with `virt_lines_above=false`, the virtual line renders below that durable header.

@@ -479,7 +479,7 @@ Extract the current completion body into an idempotent continuation. Classify to

 Modify `M.cmd_stop` explicitly to call `require("parley.chat_pending").cancel_all("user")` before `_parley.tasker.stop(signal)`. This makes user cancellation discard staged output before curl termination can be observed as a transport error.

-- [ ] **Step 5: Run chat response, process, lease, and timer-race specs and verify GREEN**
+- [x] **Step 5: Run chat response, process, lease, and timer-race specs and verify GREEN**

 ```bash
 nvim -n --headless --noplugin -u tests/minimal_init.vim \
@@ -494,7 +494,7 @@ nvim -n --headless --noplugin -u tests/minimal_init.vim \

 Expected: PASS; playful text is absent from buffer lines and the exchange model.

-- [ ] **Step 6: Commit the chat integration**
+- [x] **Step 6: Commit the chat integration**

 ```bash
 git add lua/parley/chat_respond.lua tests/integration/chat_respond_spec.lua \
@@ -512,21 +512,21 @@ git commit -m "#182: stage slow LLM chat output behind playful progress"
 - Modify: `tests/integration/define_spec.lua:193-412`
 - Modify: `tests/integration/cliproxy_caller_teardown_spec.lua`

-- [ ] **Step 1: Write RED skill lifecycle tests**
+- [x] **Step 1: Write RED skill lifecycle tests**

 Assert `opts.detached_progress=false` never activates `progress.is_active()`, while the default still activates it for existing callers. Add one table of terminal paths: no file, already running, source failure, no agent, success, pre-query abort, post-start transport error through dispatcher argument 10, explicit `skill_invoke.cancel`, buffer deletion before scheduled completion, and late callback after cancellation. For every row assert `on_terminal` runs exactly once; on normal completion/abort/transport error it runs before `on_done`; repeated finish/cancel is harmless. On transport error, assert detached progress stops before delivery and no later `on_exit` can deliver a second terminal.

-- [ ] **Step 2: Run `skill_invoke_spec.lua` and verify RED**
+- [x] **Step 2: Run `skill_invoke_spec.lua` and verify RED**

 Expected: suppression and terminal-hook assertions fail because progress is unconditional and cancellation only bumps generation.

-- [ ] **Step 3: Centralize the invocation terminal path**
+- [x] **Step 3: Centralize the invocation terminal path**

 Document the full opts shape and implement one once-guarded `finish(result, deliver_done)` per generation. Store the active terminal closure per buffer so `M.cancel(buf)` calls it before invalidating the generation and stopping the task. Start/stop the detached luabar only when `opts.detached_progress ~= false`; defaults remain unchanged. `finish` calls `opts.on_terminal(result)` before optional `opts.on_done(result)` and clears `_in_flight`/terminal registry exactly once. Pass dispatcher argument 10 and route its post-start transport error into `finish({ ok=false, msg=... }, true)`; because the dispatcher chooses one terminal, the normal exit callback cannot race a second delivery.

 At the top of scheduled completion, before reload, `nvim_buf_get_lines`, tool rendering, or decoration work, check `nvim_buf_is_valid(buf)`. An invalid buffer immediately takes the centralized terminal path with `{ok=false, msg="buffer invalid"}` and skips `on_done`; the terminal hook still runs once. Guard every remaining completion-time buffer access that can race deletion.

-- [ ] **Step 4: Run skill and cliproxy caller teardown specs and verify GREEN**
+- [x] **Step 4: Run skill and cliproxy caller teardown specs and verify GREEN**

 ```bash
 nvim -n --headless --noplugin -u tests/minimal_init.vim \
@@ -537,7 +537,7 @@ nvim -n --headless --noplugin -u tests/minimal_init.vim \

 Expected: PASS; existing Review/Voice/generic luabar assertions remain green.

-- [ ] **Step 5: Write RED selection-spinner and real Definition entry tests**
+- [x] **Step 5: Write RED selection-spinner and real Definition entry tests**

 Hold the real `define_visual` query open and assert immediately:

@@ -550,7 +550,7 @@ detached progress is inactive

 Then cover success (spinner removed before `CVR[^cvr]` edit), no tool output, source/no-agent synchronous failure, pre-query abort, post-start transport failure, missing vault secret, subprocess busy/spawn rejection, explicit cancel, stale selection, and deleted buffer. Drive the secret/launch cases through real `define_visual` and real dispatcher while replacing only the failing vault/task boundary; assert the terminal hook removes the inline spinner exactly once, detached progress remains inactive, and no footnote is written. Every non-success leaves no footnote and no timer/extmark.

-- [ ] **Step 6: Implement `selection_spinner.start` and Definition wiring**
+- [x] **Step 6: Implement `selection_spinner.start` and Definition wiring**

 Create a dedicated namespace and `virt_text_pos="inline"` mark at `{row=er-1, col=ec}` with `invalidate=true`. Initialize the canonical spinner tick to `1`, so the synchronous first render is exactly `progress.frame(1) == "⠙"`; subsequent timer callbacks increment and wrap it. Return an idempotent stop closure that always stops/closes its 90 ms timer before attempting `pcall(nvim_buf_del_extmark, ...)`. Each animation callback checks buffer validity first and invokes that stop closure when invalid, so buffer deletion cannot leave the timer alive.

@@ -568,7 +568,7 @@ skill_invoke.invoke(buf, manifest, { phrase = phrase }, {

 Guard `render_definition` against an invalid buffer before reading lines.

-- [ ] **Step 7: Run Definition tests and verify GREEN**
+- [x] **Step 7: Run Definition tests and verify GREEN**

 ```bash
 nvim -n --headless --noplugin -u tests/minimal_init.vim \
@@ -577,7 +577,7 @@ nvim -n --headless --noplugin -u tests/minimal_init.vim \

 Expected: PASS; the durable footnote/undo/projection tests remain unchanged after the transient spinner disappears.

-- [ ] **Step 8: Commit Definition progress**
+- [x] **Step 8: Commit Definition progress**

 ```bash
 git add lua/parley/selection_spinner.lua lua/parley/skill_invoke.lua lua/parley/init.lua \
@@ -598,11 +598,11 @@ git commit -m "#182: anchor definition progress to the selection"
 - Modify: `README.md`
 - Modify: `workshop/issues/000182-claude-code-style-progression-text-in-parley-chat.md`

-- [ ] **Step 1: Write the atlas page and reconcile every old behavior statement**
+- [x] **Step 1: Write the atlas page and reconcile every old behavior statement**

 Map eligibility, state/event timing, extmark ownership, semantic status handoff, tool-only continuation, failure/cancellation distinction, and Definition's separate immediate renderer. Remove the old claim that web search owns a buffer-backed initial spinner. Add all new files/tests to traceability and link the new page from `atlas/index.md`; update README's chat and Definition descriptions.

-- [ ] **Step 2: Run architecture shadow searches**
+- [x] **Step 2: Run architecture shadow searches**

 ```bash
 rg -n "Submitting|spinner_active|spinner_block_idx|🔎" lua tests atlas README.md
@@ -612,7 +612,7 @@ rg -n "chat_presentation|chat_pending|selection_spinner" atlas README.md tests l

 Expected: no obsolete buffer-backed initial spinner implementation or stale documentation; every new consumer derives from the canonical spinner frames and lifecycle helpers (`ARCH-DRY`, `ARCH-PURPOSE`).

-- [ ] **Step 3: Run mapped feature tests**
+- [x] **Step 3: Run mapped feature tests**

 ```bash
 make test-spec SPEC=chat/response_progress
@@ -623,7 +623,7 @@ make test-spec SPEC=context/web_search

 Expected: all mapped unit, integration, architecture, and process-fake specs pass.

-- [ ] **Step 4: Run lint, changed-spec checks, and the full suite**
+- [x] **Step 4: Run lint, changed-spec checks, and the full suite**

 ```bash
 make lint
@@ -634,11 +634,11 @@ git diff --check origin/main...HEAD

 Expected: every command exits 0 with no warnings or whitespace errors.

-- [ ] **Step 5: Perform the manual temporal smoke test**
+- [x] **Step 5: Perform the manual temporal smoke test**

 In Neovim, use a test provider or temporarily delayed endpoint to verify: fast answer/no spinner; slow answer/playful line after one second; staged burst after minimum; remote status handoff; tool recursion with no spinner during local execution; immediate `CVR ⠙` Definition transition to `CVR[^cvr]`; Review still uses the detached luabar. Record exact observations in the issue Log.

-- [ ] **Step 6: Check off the issue plan and commit docs/evidence**
+- [x] **Step 6: Check off the issue plan and commit docs/evidence**

 ```bash
 git add atlas/chat/response_progress.md atlas/index.md atlas/chat/lifecycle.md \
@@ -653,6 +653,69 @@ Run `sdlc actual --issue 182`, then follow `sdlc close --help`. Close with the t

 ## Revisions

+### 2026-07-13T03:28:13-07:00 — Task 6 execution
+
+Reconciled the product map across the planned chat and Definition pages plus
+the provider/tool-use maps that also described the affected boundary, and
+removed the now-orphaned buffer-progress editing API. Because the execution
+environment is noninteractive, substituted production-shaped headless temporal
+smoke coverage for the GUI-manual step: real scratch-buffer extmarks, injected
+clocks, real entry points, and the loopback curl/SSE fixture cover every listed
+observation. Four mapped feature groups, lint, changed-spec selection, the full
+suite, shadow searches, and diff checks passed.
+
+### 2026-07-13T03:18:36-07:00 — Task 5 execution
+
+Checked off Definition's immediate inline progress after 16 skill lifecycle, 23
+real Definition, and 5 cliproxy teardown cases passed two fresh review loops.
+Review-driven cases now protect the entire scheduled completion pipeline and
+prove source, agent, malformed output, no-tool, transport, launch, cancel,
+stale-selection, and deleted-buffer terminals remove the inline timer/extmark
+exactly once before any durable footnote delivery.
+
+### 2026-07-13T02:58:16-07:00 — Task 4 execution
+
+Checked off real chat integration after the expanded entry matrix passed 43
+cases, the real curl/prestart matrix passed 7 cases, and the process suite
+passed 12 consecutive stress runs. Two fresh review loops verified exact-once
+discard teardown, force preflight before mutation, early-timer rearming,
+initial/recursive session ownership, tool timing, failure ordering, and fixture
+reaping with no remaining blocking findings.
+
+### 2026-07-13T02:37:40-07:00 — Task 4 production-clock correction
+
+The real curl/SSE stress run exposed a mismatch between `chat_pending`'s
+high-resolution default clock and libuv's millisecond timer clock: a one-shot
+minimum callback could arrive fractionally before the reducer deadline and be
+ignored forever. Expanded Task 4's review-fix surface to
+`lua/parley/chat_pending.lua` and `tests/integration/chat_pending_spec.lua` so
+the adapter owns one coherent production timing contract rather than injecting
+a chat-only clock override. Added repeated process verification to the GREEN
+gate.
+
+### 2026-07-13T02:16:55-07:00 — Task 3 execution
+
+Checked off the extmark/timer adapter after 16 integration tests, 41 reducer
+tests, and two fresh review loops. Review-driven cases now retire every playful
+timer on fast release, terminate stale leases from animation callbacks, publish
+registry ownership only after successful construction, and contain callback
+failures with static bounded diagnostics.
+
+### 2026-07-13T01:58:42-07:00 — Task 2 execution
+
+Checked off the drain-safe task/dispatcher boundary after RED/GREEN
+implementation and independent specification and quality reviews. Review-driven
+fixes contain callback exceptions without stranding lifecycle cleanup, isolate
+legacy completion surfaces, and keep provider and callback diagnostics bounded;
+the focused boundary now passes 110 tests.
+
+### 2026-07-13T01:26:31-07:00 — Task 1 execution
+
+Checked off the pure-controller task after RED/GREEN implementation and two
+fresh review loops. Review-driven tests now cover actual delayed reveal, nil
+completion terminals, cross-phase failure/cancellation, and structurally linear
+persistent staging.
+
 ### 2026-07-13T00:56:07-07:00 — framing precision gate correction

 Pinned Definition's first canonical frame to tick 1 (`⠙`), classified structural


codex
I’ll inspect the repository’s review instructions, issue/spec/plan, and the actual base-to-HEAD diff, then run focused checks/tests where useful. I’ll treat the pasted diff as a lead, not as proof.
exec
/bin/zsh -lc "pwd && rg --files -g 'AGENTS.md' -g 'workshop/issues/000182*' -g 'workshop/plans/000182*' -g 'Makefile' -g '.luacheckrc' | sort && git status --short && git diff --stat 27a778b7876adfdf3816b8c701e2b355252c357b..HEAD" in /Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat
 succeeded in 0ms:
/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat
.luacheckrc
workshop/issues/000182-claude-code-style-progression-text-in-parley-chat.md
workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md
 README.md                                          |   8 +-
 atlas/chat/inline_define.md                        |  30 +-
 atlas/chat/lifecycle.md                            |   4 +-
 atlas/chat/response_progress.md                    |  99 +++
 atlas/context/web_search.md                        |   5 +-
 atlas/index.md                                     |   1 +
 atlas/providers/tool_use.md                        |   4 +-
 atlas/traceability.yaml                            |  25 +
 lua/parley/buffer_edit.lua                         |  22 -
 lua/parley/chat_pending.lua                        | 442 +++++++++++++
 lua/parley/chat_presentation.lua                   | 286 +++++++++
 lua/parley/chat_respond.lua                        | 715 ++++++++-------------
 lua/parley/dispatcher.lua                          | 310 +++++----
 lua/parley/init.lua                                |   6 +
 lua/parley/selection_spinner.lua                   |  76 +++
 lua/parley/skill_invoke.lua                        | 211 +++---
 lua/parley/tasker.lua                              | 147 ++++-
 lua/parley/vault.lua                               |  65 +-
 tests/fixtures/fake_sse_server                     |  60 ++
 tests/integration/chat_pending_spec.lua            | 686 ++++++++++++++++++++
 tests/integration/chat_progress_process_spec.lua   | 233 +++++++
 tests/integration/chat_respond_spec.lua            | 639 ++++++++++++------
 .../integration/cliproxy_caller_teardown_spec.lua  |  67 ++
 tests/integration/define_spec.lua                  | 188 ++++++
 tests/integration/skill_invoke_spec.lua            | 209 ++++++
 tests/integration/tasker_run_spec.lua              | 319 +++++++++
 tests/integration/topic_gen_spec.lua               |  30 +
 tests/unit/buffer_edit_spec.lua                    |  16 -
 tests/unit/chat_presentation_spec.lua              | 506 +++++++++++++++
 tests/unit/dispatcher_query_spec.lua               | 335 ++++++++++
 tests/unit/vault_spec.lua                          |  84 +++
 ...e-code-style-progression-text-in-parley-chat.md |  89 ++-
 workshop/lessons.md                                |  11 +
 ...e-style-progression-text-in-parley-chat-plan.md | 141 ++--
 34 files changed, 5089 insertions(+), 980 deletions(-)

exec
/bin/zsh -lc 'for f in ../AGENTS.md ../../AGENTS.md ../../../AGENTS.md ../../../../AGENTS.md AGENTS.md; do if [ -f "$f" ]; then echo "$f"; sed -n '"'1,260p' \""'$f"; fi; done
sed -n '"'1,280p' workshop/issues/000182-claude-code-style-progression-text-in-parley-chat.md
sed -n '1,220p' workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md" in /Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat
 succeeded in 0ms:
---
id: 000182
status: working
deps: []
github_issue:
created: 2026-07-10
updated: 2026-07-12
estimate_hours: 8.94
started: 2026-07-12T21:56:40-07:00
---

# claude code style progression text in parley chat

## Problem

Agentic chat responses can remain silent long enough that users cannot tell
whether Parley is still working. The existing in-buffer progress indicator is
limited to web-search mode, mutates buffer text, and does not provide one
consistent waiting cue for every LLM response that will become chat content.

Inline definition has the same feedback gap at a smaller spatial scale: it
currently uses the detached luabar even though the selected term is the clear
place to show pending work.

## Spec

### Chat response presentation

- Apply the playful pending state only to dispatcher legs started by
  `chat_respond.respond`: both the initial response leg and each recursive LLM
  leg around local tool calls. Exclude `generate_topic`, memory preferences,
  generic skill invocations (including Document Review and Voice Apply), and
  every other background/utility LLM call. Definition uses its dedicated
  immediate adapter below. Do not show playful chat progress while a local tool
  itself is executing.
- Start each eligible call in a silent waiting state. If visible output arrives
  within one second, stream normally and never show the playful indicator.
  Visible output means answer text, reasoning status, or remote-tool status; a
  raw SSE event without visible content does not end the wait.
- If the call remains without visible output for one second, render an
  ephemeral virtual line below the response header in the form `⠙ brewing`.
  The line must be an extmark decoration: it does not enter buffer text, the
  exchange model, undo history, saved files, parsing, or later prompts.
- Animate the glyph from the canonical braille spinner sequence. Choose the
  verb from an internal playful vocabulary (for example `brewing`, `cooking`,
  and `dragon-slaying`) and avoid immediately repeating the visible verb. The
  vocabulary is cosmetic and is not user configuration in this issue.
- While the playful line is visible, change its verb on each received SSE event
  or after 15 seconds without an SSE event, whichever happens first. Spinner
  glyph animation remains independent of verb changes. Avoid immediate verb
  repetition within one call; consecutive calls do not share verb history.
  Here an SSE event is one blank-line-delimited record: comments, `event:`, and
  multiple `data:` fields inside that record rotate the verb only once, and EOF
  terminates one final unterminated record. Activity is observed at the first
  field/comment and never delays semantic parsing; supported non-SSE JSONL
  streams treat each complete non-empty line as one activity record.
- Once shown, keep the playful line visible for at least one second. Buffer all
  visible server output received during that minimum window. Hide the line at
  the later of (a) the first visible output and (b) the minimum-visible
  deadline, flush all buffered output once in original order, then resume
  ordinary streaming. If no visible output has arrived, retain the indicator
  beyond its minimum rather than hiding it into another silent state.
- After release, preserve existing provider-specific progress behavior such as
  reasoning and remote web-search status. The playful indicator is only the
  pre-output presentation stage, not a replacement for meaningful status.
- A tool-use-only LLM leg that completes before the playful indicator appears
  starts its local tool immediately. If the indicator is already visible, stage
  the transition until its minimum-visible deadline, then remove the indicator
  before starting the local tool. Never run a local tool behind a still-visible
  playful indicator.
- A successful empty completion honors the minimum duration if the indicator
  became visible, then removes it. A provider failure—either a transport/process
  failure or an HTTP response outside 200–299—with a still-valid chat lease
  bypasses the minimum: remove the indicator, flush any staged real output once
  in original order, then surface the existing error. User cancellation,
  a stale lease, or an invalid/deleted buffer removes the indicator immediately
  and discards staged output because that response no longer owns a writable
  transcript. No terminal path may leave timers or extmarks alive.
- Callbacks are serialized through the Neovim event loop, and the controller
  applies events in callback order. The first event that crosses the reveal or
  minimum deadline performs that transition exactly once: visible output
  processed before reveal releases directly with no indicator; reveal processed
  first shows it; visible output at/after the minimum releases and flushes;
  failure preempts either timer using the valid-lease rule above; cancellation,
  stale lease, and invalid buffer preempt every write. Later callbacks become
  no-ops after the controller reaches its terminal state.

### Inline definition presentation

- On visual `<M-CR>`, immediately place an animated virtual spinner after the
  selected term, so `CVR` is presented as `CVR ⠙` without changing buffer text.
  Anchor it to the selection with an extmark and remove it on every terminal
  path.
- Definition does not use the detached luabar. Document Review remains a
  luabar consumer because it has no unambiguous inline anchor.
- The shared skill invocation boundary must therefore support two independent,
  backward-compatible controls: suppress detached progress for Definition, and
  run an idempotent terminal cleanup hook on success, failure, cancellation, or
  process abort. Review, Voice Apply, and existing generic callers retain their
  current luabar behavior by default.
- On a valid definition result, remove the virtual spinner immediately and run
  the existing durable footnote flow, producing `CVR[^cvr]` and its managed
  definition. There is no one-second delay or minimum-visible duration for
  definition.
- On failure, missing structured output, a stale selection, cancellation, or
  buffer deletion, remove the virtual spinner without adding a footnote.

### Design boundaries

- Use a small pure response-presentation controller for chat timing, state
  transitions, buffering decisions, and verb selection. Inject time and random
  choice so its behavior is deterministic under unit test (`ARCH-PURE`).
- Keep Neovim timers, extmarks, dispatcher callbacks, exchange-model access,
  and stream writes in thin adapters. The exchange model remains the sole owner
  of real chat positions; cosmetic virtual text is anchored to its durable
  response header rather than modeled as content.
- Reuse the existing canonical spinner frames. Keep the detached luabar,
  chat-pending virtual line, and selection-anchored definition spinner as
  separate renderers because they have different locations and lifecycle
  policies (`ARCH-DRY`, `ARCH-PURPOSE`).
- Expose raw SSE activity separately from semantic provider progress so playful
  verb changes do not alter existing progress-event contracts.
- Give callers an additive post-start provider-error callback. Callers that do
  not opt in receive every historical completion surface they supplied—both
  `on_exit(qid)` and the assembled-response callback, when present—exactly once
  after transport drain, so topic generation, memory preferences, and other
  existing consumers cannot strand teardown.
- Preserve each HTTP response body while classifying its final status outside
  the SSE stream. Curl writes a qid-specific status trailer to stderr, leaving
  response stdout byte-for-byte untouched. The trailer is transport metadata:
  it is not an SSE event, visible content, raw provider response, or playful
  activity.
- Route failures before a transport starts through the existing pre-start abort
  class exactly once. Missing/unresolved vault secrets, a busy subprocess slot,
  and process-spawn rejection must all notify the chat/skill caller so it can
  remove pending extmarks and timers rather than waiting forever.
- Model provider failure, cancellation/invalidation, successful completion, and
  deferred local-tool transition as distinct terminal actions; do not collapse
  them into a single cleanup callback that loses real buffered output.

## Done when

- Fast chat output streams normally without ever showing playful progress.
- A chat call silent for one second shows an ephemeral animated playful line;
  once shown, it remains at least one second, stages incoming output, flushes it
  exactly once in order, and resumes streaming without transcript drift.
- SSE activity and a 15-second idle interval independently rotate the playful
  verb without coupling verb changes to spinner-frame animation.
- Every chat-producing LLM leg is covered, while topic generation and local
  tool execution do not show the playful line.
- Terminal, cancellation, stale-lease, and invalid-buffer paths clean up all
  timers, extmarks, and buffered state. Provider failures bypass the minimum
  and preserve valid partial output; cancellation or lost ownership discards it.
- Definition shows an immediate selection-anchored virtual spinner, never uses
  the luabar, and replaces the spinner with the existing durable footnote on
  success; all non-success paths remove it without a footnote.
- Document Review continues to use the detached luabar.
- Pure timing/state tests, real-entry-point chat and definition integration
  tests, atlas updates, and the full `make test` suite pass.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=1.20 impl=0.08
item: lua-neovim design=0.50 impl=0.60
item: lua-neovim design=0.60 impl=0.60
item: lua-neovim design=0.60 impl=0.60
item: lua-neovim design=0.40 impl=0.50
item: api-integration design=0.50 impl=0.60
item: cross-cutting-refactor design=0.40 impl=0.50
item: atlas-docs design=0.15 impl=0.08
item: milestone-review design=0.15 impl=0.20
design-buffer: 0.15
total: 8.94
```

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md`
against `baseline-v3.1.md`. Method A only. The four `lua-neovim` primitives
separate the pure response controller, chat adapter/integration, drain-safe
task/dispatcher transport, and Definition's selection-anchored lifecycle. The
API integration covers the real curl/SSE process fixture; the cross-cutting
item covers compatibility consumers and pre-launch vault/task ownership.
Implementation values already apply
v3.1's 40% AI-paired ship-wall-clock scale.

## Plan

- [x] Approve the durable plan at `workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md`.
- [x] Build the pure chat presentation reducer with exhaustive event-order tests.
- [x] Add separate raw-SSE activity and post-start transport-error callbacks.
- [x] Replace the buffer-backed web spinner with the extmark-backed chat adapter.
- [x] Add Definition's immediate selection spinner and generalized skill terminal cleanup.
- [x] Update README/atlas/traceability and pass targeted, process, mapped, and full verification.
- [ ] Close, publish, and merge through the SDLC gates.

## Revisions

### 2026-07-13T00:56:07-07:00 — framing precision gate correction

Pinned Definition's initial canonical frame to tick 1 (`⠙`), made every valid
SSE field part of one record while distinguishing JSONL structurally, and moved
the qid-specific HTTP status trailer to stderr so response stdout is preserved
byte-for-byte across unterminated bodies and arbitrary chunk splits. Reset plan
approval pending fresh review.

### 2026-07-13T00:50:00-07:00 — streaming-framing gate correction

Decoupled raw activity framing from semantic delivery: the first field marks
SSE activity, every semantic line still streams immediately, blank lines only
reset record ownership, and non-SSE JSONL lines remain independently streamed.
Reset revised-plan approval pending fresh review.

### 2026-07-13T00:45:35-07:00 — HTTP failure gate correction

Expanded provider failure to include non-2xx HTTP responses while preserving
streamed bodies and excluding curl's internal status trailer from SSE activity.
Added real 401 and partial-body 500 process coverage, reset revised-plan
approval, and recalibrated the API fixture work from 8.72 to 8.94 hours.

### 2026-07-13T00:38:31-07:00 — launch-failure gate correction

Required missing/unresolved secrets, busy subprocess rejection, and spawn
failure to reach the existing pre-start abort owner exactly once. Added
real-entry chat and Definition cleanup coverage, reset revised-plan approval,
and recalibrated the expanded compatibility work from 8.19 to 8.72 hours.

### 2026-07-13T00:32:14-07:00 — compatibility review correction

Expanded the dispatcher fallback to cover both historical completion surfaces:
topic generation's `on_exit` and memory preferences' assembled-response
callback. Reset plan approval while the materially revised plan returns through
fresh review.

### 2026-07-13T00:28:50-07:00 — SDLC plan-quality gate corrections

Defined blank-line-delimited SSE event framing, preserved a legacy completion
fallback for dispatcher consumers that omit the additive transport-error hook,
required Definition to own post-start transport failure, and made main-loop
FIFO scheduling part of the chat adapter contract. Recalibrated the estimate
from 4.62 to 8.19 hours for the expanded transport, compatibility, process-fake,
race-test, documentation, and review surface.

### 2026-07-13T00:13:49-07:00 — plan review corrections

Made subprocess draining an explicit production contract in `tasker.run`, added
injected clock/scheduler seams for deterministic adapter tests, assigned
semantic status rendering to the chat adapter, wired global user Stop to cancel
all sessions before process termination, and moved invalid-buffer Definition
cleanup ahead of completion-time Neovim access. Recalibrated the estimate from
4.09 to 4.62 hours by replacing the generic refactor item with a third focused
Lua/Neovim primitive for transport lifecycle work.

### 2026-07-13T00:07:30-07:00 — implementation plan

Added the calibrated v3.1 estimate and replaced the workflow placeholders with
the concrete durable-plan tasks. The plan adds a real curl/SSE process fixture
after code exploration found that dispatcher currently has neither raw-event
activity nor a post-start transport terminal; both are required to implement
the approved partial-output failure contract faithfully.

### 2026-07-12T23:53:24-07:00 — fresh-eyes spec review

Clarified the exact eligible LLM entry points, deferred tool-use-only
transitions until a visible indicator satisfies its minimum, separated provider
failure from cancellation/lost ownership, preserved valid partial output before
errors, defined callback-order tie breaking, and specified the shared
invocation controls required for Definition-owned cleanup without changing
Review or Voice Apply progress.

## Log

### 2026-07-10

### 2026-07-12

Claimed the issue and crystallized the temporal UI contract. The design uses a
pure chat presentation controller with extmark-backed renderers: delayed and
minimum-visible staging for chat, immediate selection-anchored feedback for
# Playful LLM Progress Presentation Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give chat-producing LLM calls delayed, minimum-visible playful progress with ordered output staging, and give inline Definition an immediate selection-anchored spinner without transient buffer edits.

**Architecture:** A pure reducer owns chat presentation states, deadlines, verb choice, and ordered staged events. Thin chat and selection adapters own Neovim timers/extmarks; `chat_respond` routes dispatcher callbacks through the chat adapter, while `skill_invoke` exposes backward-compatible terminal/progress controls for Definition. The dispatcher adds raw-SSE activity and post-start provider-failure channels without changing semantic progress callbacks.

**Tech Stack:** Lua, Neovim extmarks (`virt_lines` and inline `virt_text`), libuv timers, Plenary/Busted, curl/SSE, Python process-level test fixture.

**Spec:** `workshop/issues/000182-claude-code-style-progression-text-in-parley-chat.md`

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `chat_presentation.initial` | `lua/parley/chat_presentation.lua` | new |
| `chat_presentation.transition` | `lua/parley/chat_presentation.lua` | new |
| `chat_presentation.progress_message` | `lua/parley/chat_presentation.lua` | new |

- **`chat_presentation.initial`** — constructs one LLM leg's `waiting` state with reveal and verb-idle deadlines, an initial non-repeating verb, and no staged events.
  - **Relationships:** One state per dispatcher leg; a recursive tool loop creates a new state rather than sharing history with the prior leg.
  - **DRY rationale:** One initial-state contract prevents chat callbacks and timers from inventing different deadline defaults.
  - **Future extensions:** New cosmetic vocabularies can widen the injected verb list; timings remain fixed for #182.
- **`chat_presentation.transition`** — reduces one serialized event (`reveal_due`, `minimum_due`, `activity`, `content`, `progress`, `complete`, `failure`, or `cancel`) into a new plain-table state plus ordered actions (`show_playful`, `render_status`, `emit_content`, `hide`, `continue_completion`, `surface_failure`). It never calls Neovim, a clock, or randomness.
  - **Relationships:** N:1 events to one leg state; actions are consumed 1:1 in order by `chat_pending`.
  - **DRY rationale:** Timer, SSE, stream, completion, and cancellation races converge through one transition table instead of independently mutating flags in `chat_respond`.
  - **Future extensions:** Additional visible event kinds can join the staged-event union without changing adapter ownership.
- **`chat_presentation.progress_message`** — accumulates provider detail fragments and derives the existing meaningful reasoning/tool status text from semantic progress events.
  - **Relationships:** One progress-detail state belongs to one presentation state; each `progress` event yields at most one rendered status.
  - **DRY rationale:** Moves the current deterministic formatter out of async glue and makes both staged and released progress use the same rule.
  - **Future extensions:** New provider-normalized `kind` values widen this formatter, not `chat_respond`.

All three symbols are tested without Neovim IO or mocks in `tests/unit/chat_presentation_spec.lua` (`ARCH-PURE`).

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `chat_pending.start` | `lua/parley/chat_pending.lua` | new | Neovim extmarks, libuv timers, serialized callback actions |
| `selection_spinner.start` | `lua/parley/selection_spinner.lua` | new | selection-anchored extmark and animation timer |
| `tasker.run` | `lua/parley/tasker.lua` | modified | drain-safe subprocess exit plus stdout/stderr pipe EOF |
| `vault.run_with_secret` | `lua/parley/vault.lua` | modified | secret resolution and exactly-once launch abort delivery |
| `dispatcher.query` | `lua/parley/dispatcher.lua` | modified | curl process, raw SSE stream, transport terminal |
| `chat_respond.respond` | `lua/parley/chat_respond.lua` | modified | exchange model, chat lease, stream/tool continuations |
| `skill_invoke.invoke` / `skill_invoke.cancel` | `lua/parley/skill_invoke.lua` | modified | headless skill process and terminal ownership |
| `define_visual` | `lua/parley/init.lua` | modified | visual selection and durable footnote rendering |
| `fake_sse_server` | `tests/fixtures/fake_sse_server` | new | real local HTTP/SSE process used by curl |

- **`chat_pending.start`** — creates one registered per-buffer session, anchors a dedicated `virt_lines` extmark below the durable response header, owns reveal/minimum/animation/verb timers, feeds every callback through the pure reducer, and executes emitted actions in order.
  - **Injected into:** `chat_respond.respond` supplies `lease_valid`, the real content emitter, and the existing completion/failure continuations.
  - **Future extensions:** A different chat progress renderer can consume the same reducer actions.
- **`selection_spinner.start`** — initializes `tick=1` and renders `" " .. progress.frame(tick)` (`⠙`) at the selection's exclusive end, then advances through the canonical sequence and returns an idempotent stop function.
  - **Injected into:** `define_visual`; it reuses `progress.SPINNER` but has no dependency on the detached luabar session (`ARCH-DRY`).
  - **Future extensions:** Other precisely anchored read-only skills can opt in explicitly.
- **`tasker.run`** — drains stdout and stderr to EOF before reporting the process terminal, regardless of whether pipe EOF or process exit arrives first.
  - **Injected into:** `dispatcher.query` receives a callback only after its stdout reader has consumed the final fragment; existing four-argument callbacks remain compatible.
  - **Future extensions:** The optional fifth `io_error` result can classify pipe failures for other subprocess consumers.
- **`vault.run_with_secret`** — appends an optional error callback that reports
  missing secrets and every resolver terminal that cannot produce a usable
  secret; `tasker.run` likewise appends a launch-error callback for busy/spawn
  rejection.
  - **Injected into:** Dispatcher folds both sources into its once-guarded
    qid-free `on_abort(msg)` path; existing vault/task callers omit the new
    arguments and retain their current behavior.
  - **Future extensions:** Other interactive callers may opt into explicit
    launch-failure teardown without changing legacy fire-and-forget callers.
- **`dispatcher.query`** — invokes raw activity once per blank-line-delimited SSE event record (including a final EOF-terminated record), preserves semantic `on_progress`, captures curl's final HTTP status outside the provider stream, and chooses exactly one normal or provider-error terminal after drain-safe `tasker.run` completion.
  - **Injected into:** Chat and Definition's `skill_invoke` path use the new error callback. Existing callers that omit it receive the historical `on_exit(qid)` fallback and retain teardown behavior.
  - **Future extensions:** Provider HTTP-status classification can widen the typed failure record without overloading pre-query `on_abort`.
- **`chat_respond.respond`** — removes the web-search-only buffer/model spinner, starts one presentation session for every initial/recursive leg, and defers tool-loop execution behind a visible minimum when required.
  - **Injected into:** The session receives the existing lease and `create_handler` seams; it never computes transcript positions itself.
  - **Future extensions:** None planned; background topic generation stays deliberately separate.
- **`skill_invoke.invoke` / `skill_invoke.cancel`** — centralizes one idempotent terminal path, with `opts.detached_progress` defaulting true and `opts.on_terminal` running before `opts.on_done` on every terminal path.
  - **Injected into:** Definition passes `detached_progress=false`; Review, Voice Apply, and generic callers rely on defaults.
  - **Future extensions:** Other callers can own contextual progress without changing cancellation semantics.
- **`define_visual`** — starts the inline spinner only after validating a non-empty selection, passes its stop function as terminal cleanup, and performs the existing footnote flow only after cleanup.
  - **Injected into:** `selection_spinner.start` and the generalized `skill_invoke` lifecycle.
  - **Future extensions:** None; the spinner has no one-second delay by design.
- **`fake_sse_server`** — speaks actual HTTP/SSE to curl with deterministic fast, delayed, activity-only-then-visible, partial-then-fail, and tool-use-only modes.
  - **Injected into:** A process integration spec points a test provider endpoint at the local server; callback-only tests remain for exhaustive race permutations.
  - **Future extensions:** Additional transport edge fixtures can become modes instead of new fake processes.

## Chunk 1: Presentation controller, adapters, and integrations

### Task 1: Build the pure chat presentation reducer

**Files:**
- Create: `lua/parley/chat_presentation.lua`
- Create: `tests/unit/chat_presentation_spec.lua`

- [x] **Step 1: Write failing state-table tests for fast and delayed visible output**

Define the wished-for public API and assert actions, not internal mutation:

```lua
local presentation = require("parley.chat_presentation")

local s = presentation.initial({
    now_ms = 0,
    verbs = { "brewing", "cooking" },
    verb_index = 1,
})
local fast, actions = presentation.transition(s, {
    type = "content", now_ms = 999, qid = "q", chunk = "hello",
})
assert.are.equal("released", fast.phase)
assert.are.same({ { type = "emit_content", qid = "q", chunk = "hello" } }, actions)

local showing = select(1, presentation.transition(s, {
    type = "reveal_due", now_ms = 1000,
}))
local staged, staged_actions = presentation.transition(showing, {
    type = "content", now_ms = 1200, qid = "q", chunk = "hello",
})
assert.are.equal("showing", staged.phase)
assert.are.same({}, staged_actions)
assert.are.equal(1, #staged.staged)
```

- [x] **Step 2: Run the unit spec and verify RED**

Run:

```bash
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/unit/chat_presentation_spec.lua" -c "qa!"
```

Expected: FAIL because `parley.chat_presentation` does not exist.

- [x] **Step 3: Implement `initial` and the minimal waiting/showing/released transitions**

Use immutable plain-table returns (copy only the small state), explicit millisecond deadlines (`reveal_at = start + 1000`, `minimum_at = reveal + 1000`, `verb_due_at = last_activity + 15000`), and tagged staged events. Visible `content` and `progress` share release timing but retain their distinct payloads.

- [x] **Step 4: Run the unit spec and verify GREEN**

Expected: PASS for the fast path, reveal, staging, minimum release, and ordered flush tests.

- [x] **Step 5: Add RED tests for the complete transition matrix**

Cover separately:

```text
activity while showing -> different verb + next 15s deadline, never visible output
verb-idle deadline -> different verb; spinner tick -> no verb change
minimum due without staged visible output -> remain showing
tool-only complete before reveal -> continue immediately, never show
tool-only complete while showing -> stage continuation until minimum, hide first
empty success while showing -> honor minimum, then hide
provider failure with ownership -> hide, ordered flush, then surface failure
cancel/stale/invalid -> hide and discard staged output
events after finished -> no actions
same-deadline permutations -> callback order decides exactly once
```

Use a deterministic requested `verb_index`; `transition` advances to the next available non-current index rather than calling `math.random`.

- [x] **Step 6: Implement the remaining minimal transitions and `progress_message`**

Port the current reasoning/tool detail accumulation from `chat_respond.lua` into `progress_message(detail_state, event) -> new_detail_state, message`, preserving whitespace compaction and key resets.

- [x] **Step 7: Run the unit spec, then lint the new files**

Run the unit command above, then:

```bash
luacheck lua/parley/chat_presentation.lua tests/unit/chat_presentation_spec.lua
```

Expected: PASS with no warnings.

- [x] **Step 8: Commit the pure core**

```bash
git add lua/parley/chat_presentation.lua tests/unit/chat_presentation_spec.lua
git commit -m "#182: add pure chat presentation controller"
```

### Task 2: Add raw-SSE activity and a real post-start failure terminal

**Files:**
- Modify: `lua/parley/dispatcher.lua:155-415`
- Modify: `lua/parley/tasker.lua:282-355`
- Modify: `lua/parley/vault.lua:75-218`
- Modify: `tests/unit/dispatcher_query_spec.lua:422-526`
- Modify: `tests/integration/tasker_run_spec.lua`
- Modify: `tests/unit/vault_spec.lua`
- Modify: `tests/integration/topic_gen_spec.lua`
- Modify: `tests/integration/cliproxy_caller_teardown_spec.lua`

- [x] **Step 1: Write RED drain-order and dispatcher callback tests**

First drive captured process-exit and pipe-reader callbacks in both permutations: stdout/stderr EOF before process exit, and process exit before stdout/stderr EOF. Assert `tasker.run` waits for all three signals, retains final fragments, invokes its public callback once, and reports read failure through an additive fifth `io_error` result.

Add launch tests for the appended `tasker.run(..., on_start_error)` callback:
busy rejection and `uv.spawn` returning no handle each schedule exactly one
error, close any allocated pipes, never invoke the process-terminal callback,
and never register a handle. In vault tests, append `on_error` to
`resolve_secret`/`run_with_secret` and cover a missing secret, empty resolver
input/output, resolver command nonzero exit, and resolver launch rejection;
each failure calls it once and never calls the success callback.

Then retain the dispatcher-facing `tasker.run` terminal callback and stdout reader. Assert that one complete SSE event calls callbacks in this order:

```lua
assert.are.same({ "activity", "progress", "content" }, observed)
```

Add cases for: a multiline `event:` + comment + multiple-`data:` SSE record (one activity at its first field/comment while each semantic line is parsed immediately); an unknown `extension: value` field followed by `data:` in the same record (one activity); two blank-line-delimited records (two activities); an EOF-terminated final record (one activity already emitted, no duplicate at EOF); empty keepalive separators (no activity); and two GoogleAI/Ollama-style structural JSON/array lines without blank separators (two activities and immediate per-line content). Preserve exact `activity` before `progress`/`content` order for the first semantic line of each record. Also cover normal 2xx exit; curl `code ~= 0` after partial stdout with `on_error` present; HTTP 401 with an error body; partial SSE content followed by HTTP 500; and failures with `on_error=nil`. Assert response stdout, including an unterminated final body, remains byte-for-byte intact and the internal stderr status trailer produces no activity/content/raw-response bytes. Split the qid-specific stderr sentinel at every byte boundary through the tasker readers and prove the drain callback reconstructs one parseable trailer. With `on_error`, process failure or non-2xx calls it once with retained body/status and no legacy completion. For both normal and fallback completion, assert each supplied legacy surface—`on_exit(qid)` and scheduled `callback(qt.response)`—runs exactly once and only after the three-signal drain; either surface may be nil independently.

At the real consumer boundary, add a topic-generation transport-failure test
that proves its supplied `on_exit` tears down the scratch buffer/spinner and
calls the topic callback, plus a memory-preferences transport-failure test that
proves its supplied assembled-response callback advances every tag and finishes
the batch. These tests use the real consumer functions and real dispatcher,

exec
/bin/zsh -lc "find /Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat -name AGENTS.md -print
rg -n '"'^## (Log|Core concepts|Revisions)|manual|PASS|full suite|make test|status:'"' workshop/issues/000182-claude-code-style-progression-text-in-parley-chat.md workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md
rg -n 'D\\.query\\(|dispatcher\\.query\\(|\\.query\\(' lua/parley | head -200" in /Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat
 succeeded in 0ms:
workshop/issues/000182-claude-code-style-progression-text-in-parley-chat.md:3:status: working
workshop/issues/000182-claude-code-style-progression-text-in-parley-chat.md:159:  tests, atlas updates, and the full `make test` suite pass.
workshop/issues/000182-claude-code-style-progression-text-in-parley-chat.md:198:## Revisions
workshop/issues/000182-claude-code-style-progression-text-in-parley-chat.md:272:## Log
workshop/issues/000182-claude-code-style-progression-text-in-parley-chat.md:443:`make test-changed`, and the full `make test` suite all exited 0; `git diff
workshop/issues/000182-claude-code-style-progression-text-in-parley-chat.md:452:claiming an unavailable GUI-manual run while exercising the same user-visible
workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md:15:## Core concepts
workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md:142:Expected: PASS for the fast path, reveal, staging, minimum release, and ordered flush tests.
workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md:175:Expected: PASS with no warnings.
workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md:334:Expected: PASS; existing semantic progress expectations remain unchanged, and
workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md:402:Run both Task 1 and Task 3 commands. Expected: PASS with no leaked timer warnings after Neovim exits.
workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md:495:Expected: PASS; playful text is absent from buffer lines and the exchange model.
workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md:538:Expected: PASS; existing Review/Voice/generic luabar assertions remain green.
workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md:578:Expected: PASS; the durable footnote/undo/projection tests remain unchanged after the transient spinner disappears.
workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md:618:make test-spec SPEC=chat/response_progress
workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md:619:make test-spec SPEC=chat/lifecycle
workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md:620:make test-spec SPEC=chat/inline_define
workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md:621:make test-spec SPEC=context/web_search
workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md:626:- [x] **Step 4: Run lint, changed-spec checks, and the full suite**
workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md:630:make test-changed
workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md:631:make test
workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md:637:- [x] **Step 5: Perform the manual temporal smoke test**
workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md:652:Run `sdlc actual --issue 182`, then follow `sdlc close --help`. Close with the targeted, process-fake, mapped, full-suite, diff, and manual evidence; use only the precise atlas/project bypass if the gate says it is genuinely inapplicable. Publish once with `sdlc pr` then `sdlc merge`; verify `main` contains the branch tip.
workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md:654:## Revisions
workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md:662:smoke coverage for the GUI-manual step: real scratch-buffer extmarks, injected
lua/parley/memory_prefs.lua:251:		_parley.dispatcher.query(nil, provider, payload, handler, nil, function(response)
lua/parley/chat_respond.lua:1028:    _parley.dispatcher.query(
lua/parley/chat_respond.lua:1673:        _parley.dispatcher.query(

codex
The main design is present: a pure reducer, thin extmark/timer adapters, real transport-drain changes, and both README and atlas coverage. I’m now tracing every dispatcher/tasker consumer and terminal path, because compatibility and exact-once teardown are the highest-risk parts of this diff.
exec
/bin/zsh -lc "rg -n '(dispatcher|llm)\\.query\\(' lua tests | sed -n '1,260p'
rg -n 'tasker\\.run\\(' lua/parley | sed -n '1,260p'
rg -n 'run_with_secret\\(|resolve_secret\\(' lua/parley | sed -n '1,260p'
sed -n '980,1065p' lua/parley/chat_respond.lua
sed -n '220,285p' lua/parley/memory_prefs.lua
sed -n '1,380p' lua/parley/tasker.lua" in /Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat
 succeeded in 0ms:
lua/parley/memory_prefs.lua:251:		_parley.dispatcher.query(nil, provider, payload, handler, nil, function(response)
lua/parley/chat_respond.lua:1028:    _parley.dispatcher.query(
lua/parley/chat_respond.lua:1673:        _parley.dispatcher.query(
tests/integration/cliproxy_dispatch_spec.lua:4:--   dispatcher.query("cliproxyapi", …, on_abort)
tests/integration/cliproxy_dispatch_spec.lua:82:        dispatcher.query(
tests/unit/dispatcher_query_spec.lua:138:            dispatcher.query(nil, "openai", payload, handler, nil, nil)
tests/unit/dispatcher_query_spec.lua:153:            dispatcher.query(nil, "openai", payload, handler, nil, nil)
tests/unit/dispatcher_query_spec.lua:166:            dispatcher.query(nil, "openai", payload, handler, nil, nil)
tests/unit/dispatcher_query_spec.lua:182:            dispatcher.query(nil, "openai", payload, handler, nil, nil)
tests/unit/dispatcher_query_spec.lua:199:            dispatcher.query(nil, "openai", payload, handler, nil, nil)
tests/unit/dispatcher_query_spec.lua:227:            dispatcher.query(nil, "openai", payload, handler, nil, nil)
tests/unit/dispatcher_query_spec.lua:250:            dispatcher.query(nil, "anthropic", payload, handler, nil, nil)
tests/unit/dispatcher_query_spec.lua:304:            dispatcher.query(nil, "anthropic", payload, handler, nil, nil)
tests/unit/dispatcher_query_spec.lua:331:            dispatcher.query(nil, "googleai", payload, handler, nil, nil)
tests/unit/dispatcher_query_spec.lua:353:            dispatcher.query(nil, "openai", payload, handler, nil, nil)
tests/unit/dispatcher_query_spec.lua:373:            dispatcher.query(nil, "openai", payload, handler, nil, nil)
tests/unit/dispatcher_query_spec.lua:393:            dispatcher.query(nil, "openai", payload, handler, on_exit, nil)
tests/unit/dispatcher_query_spec.lua:412:            dispatcher.query(nil, "openai", payload, handler, nil, callback)
tests/unit/dispatcher_query_spec.lua:435:            dispatcher.query(nil, "openai", payload, handler, nil, nil)
tests/unit/dispatcher_query_spec.lua:458:            dispatcher.query(nil, "anthropic", payload, handler, nil, nil, on_progress)
tests/unit/dispatcher_query_spec.lua:475:            dispatcher.query(nil, "openai", payload, handler, nil, nil, on_progress)
tests/unit/dispatcher_query_spec.lua:488:            dispatcher.query(nil, "openai", payload, handler, nil, nil, on_progress)
tests/unit/dispatcher_query_spec.lua:506:            dispatcher.query(nil, "openai", payload, handler, nil, nil, on_progress)
tests/unit/dispatcher_query_spec.lua:524:            dispatcher.query(nil, "googleai", payload, handler, nil, nil, on_progress)
tests/unit/dispatcher_query_spec.lua:544:            dispatcher.query(nil, "googleai", payload, handler, nil, nil, on_progress)
tests/unit/dispatcher_query_spec.lua:575:            dispatcher.query(nil, "managedprov", { model = "m", messages = {} },
tests/unit/dispatcher_query_spec.lua:597:            dispatcher.query(nil, "managedprov", { model = "m", messages = {} },
tests/unit/dispatcher_query_spec.lua:609:            dispatcher.query(nil, "openai", { model = "gpt-4", messages = {} },
tests/unit/dispatcher_query_spec.lua:622:            dispatcher.query(nil, "openai", { model = "m", messages = {} }, function(_qid, chunk)
tests/unit/dispatcher_query_spec.lua:637:            dispatcher.query(nil, "openai", { model = "gpt-4", messages = {} }, function() end,
tests/unit/dispatcher_query_spec.lua:653:            dispatcher.query(nil, "openai", { model = "gpt-4", messages = {} }, function() end,
tests/unit/dispatcher_query_spec.lua:671:            dispatcher.query(nil, "openai", { model = "gpt-4", messages = {} }, function() end,
tests/unit/dispatcher_query_spec.lua:678:            dispatcher.query(nil, "openai", { model = "gpt-4", messages = {} }, function() end,
tests/unit/dispatcher_query_spec.lua:691:            dispatcher.query(nil, "openai", { model = "gpt-4", messages = {} }, function() end,
tests/unit/dispatcher_query_spec.lua:700:            dispatcher.query(nil, "openai", { model = "gpt-4", messages = {} }, function() end,
tests/unit/dispatcher_query_spec.lua:709:            dispatcher.query(nil, "openai", { model = "gpt-4", messages = {} },
tests/unit/dispatcher_query_spec.lua:730:            dispatcher.query(nil, "openai", { model = "gpt-4", messages = {} },
tests/unit/dispatcher_query_spec.lua:743:            dispatcher.query(nil, "openai", { model = "gpt-4", messages = {} }, function() end,
tests/unit/dispatcher_query_spec.lua:758:            dispatcher.query(nil, "openai", { model = "gpt-4", messages = {} }, function() end,
tests/unit/dispatcher_query_spec.lua:767:            dispatcher.query(nil, "openai", { model = "gpt-4", messages = {} }, function() end,
tests/unit/dispatcher_query_spec.lua:793:                dispatcher.query(nil, "openai", { model = "gpt-4", messages = {} }, function() end)
tests/unit/dispatcher_query_spec.lua:829:            dispatcher.query(buf, "openai", { model = "gpt-4", messages = {} }, function() end,
tests/unit/dispatcher_query_spec.lua:864:            dispatcher.query(nil, "openai", { model = "gpt-4", messages = {} }, function() end,
tests/unit/dispatcher_query_spec.lua:892:                    dispatcher.query(nil, "openai", { model = "gpt-4", messages = {} }, function() end,
lua/parley/vault.lua:121:		tasker.run(nil, cmd, args, function(code, signal, stdout_data, stderr_data, io_error)
lua/parley/vault.lua:206:	tasker.run(nil, "curl", curl_params, function(code, signal, stdout, stderr)
lua/parley/oauth.lua:830:        tasker.run(nil, "sh", { "-c", "printf '%s' " .. vim.fn.shellescape(json_data) .. " | " .. cmd .. " " .. table.concat(escaped_args, " ") }, function(code)
lua/parley/oauth.lua:837:        tasker.run(nil, cmd, cmd_args, function(code)
lua/parley/oauth.lua:858:    tasker.run(nil, cmd, cmd_args, function(code, _signal, stdout_data)
lua/parley/oauth.lua:902:    tasker.run(nil, cmd, cmd_args, function(code)
lua/parley/oauth.lua:935:    tasker.run(nil, "curl", args, function(code, _signal, stdout_data)
lua/parley/oauth.lua:1006:    tasker.run(nil, "curl", args, callback)
lua/parley/oauth.lua:1329:    tasker.run(nil, "pandoc", { "-t", "plain", "--wrap=none", tmp_path }, function(code, _, stdout)
lua/parley/oauth.lua:1337:        tasker.run(nil, "textutil", { "-convert", "txt", "-stdout", tmp_path }, function(code2, _, stdout2)
lua/parley/oauth.lua:1402:    tasker.run(nil, "curl", args, function(code, _, stdout_data)
lua/parley/oauth.lua:1609:    tasker.run(nil, "curl", meta_args, function(code, _signal, stdout_data)
lua/parley/oauth.lua:1658:        tasker.run(nil, "curl", content_args, function(content_code, _, content_data)
lua/parley/oauth.lua:1684:                    tasker.run(nil, "curl", fallback_args, function(fb_code, _, fb_data)
lua/parley/oauth.lua:1776:    tasker.run(nil, "curl", args, callback)
lua/parley/oauth.lua:1794:    tasker.run(nil, "curl", args, callback)
lua/parley/oauth.lua:1909:    tasker.run(nil, "curl", args, callback)
lua/parley/oauth.lua:1926:    tasker.run(nil, "curl", args, callback)
lua/parley/dispatcher.lua:426:	tasker.run(buf, "curl", curl_params, terminal, out_reader(), nil, abort_before_start)
lua/parley/dispatcher.lua:458:		return vault.run_with_secret(provider, function()
lua/parley/dispatcher.lua:466:	vault.run_with_secret(provider, function()
lua/parley/vault.lua:236:		V.resolve_secret(name, secret, function()
        spinner_timer:start(0, 120, vim.schedule_wrap(function()
            if not vim.api.nvim_buf_is_valid(spinner.buf) then
                stop_and_close_timer(spinner_timer)
                spinner_timer = nil
                return
            end
            local line_nr = spinner.find_line()
            if line_nr then
                if spinner.before_write and not spinner.before_write() then
                    stop_and_close_timer(spinner_timer)
                    spinner_timer = nil
                    return
                end
                local text = "topic: " .. spinner_frames[spinner_idx] .. " generating..."
                -- Issue #80: same undo-pollution fix as the agent-response
                -- spinner. Each frame joins the previous undo block.
                require("parley.helper").undojoin(spinner.buf)
                require("parley.buffer_edit").replace_line_at(spinner.buf, line_nr, text)
                if spinner.after_write then
                    spinner.after_write()
                end
            end
            spinner_idx = spinner_idx % #spinner_frames + 1
        end))
    end

    local topic_buf = vim.api.nvim_create_buf(false, true)
    local topic_handler = _parley.dispatcher.create_handler(topic_buf, nil, 0, false, "", false)

    local finished = false
    local function finish(topic, reason)
        if finished then return end
        finished = true
        stop_and_close_timer(spinner_timer)
        spinner_timer = nil
        if vim.api.nvim_buf_is_valid(topic_buf) then
            vim.api.nvim_buf_delete(topic_buf, { force = true })
        end
        callback(topic, reason)
    end

    -- Abort teardown (#131): stop the topic spinner + drop the scratch buffer
    -- if the managed cliproxy can't start, so topic-gen fails quietly (no hang).
    local function on_abort(msg)
        finish(nil, "abort")
        vim.notify(msg or "parley: topic generation aborted", vim.log.levels.WARN)
    end

    _parley.dispatcher.query(
        nil,
        provider,
        _parley.dispatcher.prepare_payload(msgs, model, provider),
        topic_handler,
        vim.schedule_wrap(function()
            local topic = vim.api.nvim_buf_get_lines(topic_buf, 0, -1, false)[1] or ""
            topic = topic:gsub("^%s*(.-)%s*$", "%1")
            topic = topic:gsub("%.$", "")
            if topic ~= "" then
                finish(topic, nil)
            else
                finish(nil, "empty")
            end
        end),
        nil,
        nil,
        on_abort
    )
end

--------------------------------------------------------------------------------
-- _resolve_remote_references
--------------------------------------------------------------------------------

-- Resolve all remote (URL-based) file references asynchronously before building messages
-- Calls callback with resolved_remote_content map when all fetches complete
---@param opts table # { parsed_chat, config, chat_file, exchange_idx }
---@param callback function # called with resolved_remote_content table
M.resolve_remote_references = function(opts, callback)
    local helpers = require("parley.helper")
    local oauth = require("parley.oauth")
    local parsed_chat = opts.parsed_chat
    local opts_config = opts.config
    local chat_file = opts.chat_file or ""
    local exchange_idx = opts.exchange_idx or #parsed_chat.exchanges
    local resolved = {}
    local seen_prior = {}
		idx = idx + 1
		if idx > #tags then
			vim.schedule(function()
				callback(preferences)
			end)
			return
		end

		local tag = tags[idx]
		local summaries = buckets[tag]
		local tag_label = tag == "_all" and "all topics" or ("topic: " .. tag)

		vim.schedule(function()
			vim.notify(
				string.format("Memory prefs: generating %s (%d/%d)", tag_label, idx, #tags),
				vim.log.levels.INFO
			)
		end)

		local messages = {
			{ role = "system", content = prompt },
			{ role = "user", content = "Topic: " .. tag_label .. "\n\n" .. table.concat(summaries, "\n") },
		}

		local payload = _parley.dispatcher.prepare_payload(messages, model, provider)
		_parley.logger.debug("memory_prefs: querying LLM for tag [" .. tag .. "] with " .. #summaries .. " summaries")

		local handler = function(_qid, content)
			_parley.logger.debug("memory_prefs: handler chunk for [" .. tag .. "]: " .. tostring(content and #content or "nil") .. " chars")
		end

		_parley.dispatcher.query(nil, provider, payload, handler, nil, function(response)
			_parley.logger.debug("memory_prefs: callback for [" .. tag .. "]: response=" .. tostring(response and #response or "nil") .. " chars")
			if response and response ~= "" then
				local trimmed = vim.trim(response)
				preferences[tag] = trimmed
				M.save_tag(tag, trimmed)
				_parley.logger.debug("memory_prefs: saved preference for [" .. tag .. "]")
			else
				_parley.logger.warning("memory_prefs: empty response for tag [" .. tag .. "]")
			end
			process_next()
		end, nil, function(msg)
			-- Abort teardown (#131): if the managed cliproxy can't start, skip
			-- this tag and keep the batch moving instead of silently stalling.
			_parley.logger.warning("memory_prefs: tag [" .. tag .. "] aborted: " .. tostring(msg))
			process_next()
		end)
	end

	process_next()
end

--------------------------------------------------------------------------------
-- Persistence
--------------------------------------------------------------------------------

--- Save a single tag's preference to its own markdown file.
---@param tag string
---@param text string preference content
M.save_tag = function(tag, text)
	local out = {}
	table.insert(out, "<!-- last_generated: " .. os.date("!%Y-%m-%dT%H:%M:%S") .. " -->")
	table.insert(out, "")
	for _, line in ipairs(vim.split(text, "\n")) do
		table.insert(out, line)
--------------------------------------------------------------------------------
-- Task managmenet module
--------------------------------------------------------------------------------

local logger = require("parley.logger")

local uv = vim.uv or vim.loop

local M = {}
M._handles = {}
M._uv = nil -- injectable transport seam for deterministic drain-order tests
M._queries = {} -- table of latest queries
M._debug = {
    is_busy_calls = 0,
    warnings_suppressed = 0,
    last_warning_time = 0,
    warning_interval = 1 -- seconds between warnings
}
M._cache_metrics = {
    creation = 0,   -- tokens created in cache
    read = 0,       -- tokens read from cache
    input = 0       -- total input tokens
}

---@param fn function # function to wrap so it only gets called once
M.once = function(fn)
	local once = false
	return function(...)
		if once then
			return
		end
		once = true
		fn(...)
	end
end

---@param N number # number of queries to keep
---@param age number # age of queries to keep in seconds
M.cleanup_old_queries = function(N, age)
	local current_time = os.time()

	local query_count = 0
	for _ in pairs(M._queries) do
		query_count = query_count + 1
	end

	if query_count <= N then
		return
	end

	for qid, query_data in pairs(M._queries) do
		if current_time - query_data.timestamp > age then
			M._queries[qid] = nil
		end
	end
end

---@param qid string # query id
---@return table | nil # query data
M.get_query = function(qid)
	if not M._queries[qid] then
		logger.error("query with ID " .. tostring(qid) .. " not found.")
		return nil
	end
	return M._queries[qid]
end

---@param buf number | nil # buffer number
---@return table | nil # newest query for this buffer
M.get_active_query_by_buf = function(buf)
	if buf == nil then
		return nil
	end

	local active_query = nil
	for _, query_data in pairs(M._queries) do
		if query_data.buf == buf then
			if not active_query or (query_data.timestamp or 0) > (active_query.timestamp or 0) then
				active_query = query_data
			end
		end
	end

	return active_query
end

---@param qid string # query id
---@param payload table # query payload
M.set_query = function(qid, payload)
	M._queries[qid] = payload
	M._queries[qid].timestamp = os.time()
	M.cleanup_old_queries(10, 60)

	-- Trigger event for lualine update
	vim.schedule(function()
		vim.cmd("doautocmd User ParleyQueryStarted")
	end)
end

-- add a process handle and its corresponding pid to the _handles table
---@param handle userdata | nil # the Lua uv handle
---@param pid number | string # the process id
---@param buf number | nil # buffer number
M.add_handle = function(handle, pid, buf)
    -- Check if this PID is already in the handles table
    for _, h in ipairs(M._handles) do
        if h.pid == pid then
            logger.debug("Process " .. pid .. " is already in handles table, not adding duplicate")
            return
        end
    end
	table.insert(M._handles, { handle = handle, pid = pid, buf = buf })
	logger.debug("Added handle for PID " .. pid .. ", total handles: " .. #M._handles)
end

-- remove a process handle from the _handles table using its pid
---@param pid number | string # the process id to find the corresponding handle
M.remove_handle = function(pid)
	for i, h in ipairs(M._handles) do
		if h.pid == pid then
			table.remove(M._handles, i)
			logger.debug("Removed handle for PID " .. pid .. ", remaining handles: " .. (#M._handles))
			return
		end
	end
	logger.debug("Attempted to remove nonexistent handle for PID " .. pid)
end

--- check if there is some pid running for the given buffer
---@param buf number | nil # buffer number
---@return boolean
M.is_busy = function(buf, skip_warning)
	-- Increment debug counter
	M._debug.is_busy_calls = M._debug.is_busy_calls + 1

	if buf == nil then
		return false
	end

	-- Initialize variables to track the first active process we find
	local active_pid = nil

	-- Count active processes for this buffer
	local active_count = 0

	for _, h in ipairs(M._handles) do
		if h.buf == buf then
			-- Check if the process is still active by sending signal 0 (doesn't kill the process, just checks existence)
			local is_active = false

			-- Use pcall since kill might throw an error if process doesn't exist
			pcall(function()
				if type(h.pid) == "number" and h.pid > 0 then
					is_active = uv.kill(h.pid, 0) == 0
				end
			end)

			if is_active then
				active_count = active_count + 1
				if active_pid == nil then
					active_pid = h.pid -- Store the first active PID we find
				end
			else
				-- Process no longer exists, remove it from handles
				logger.debug("Removing stale process handle: " .. h.pid)
				M.remove_handle(h.pid)
			end
		end
	end

	-- After processing all handles, report the result once
	if active_pid ~= nil then
		-- Only log warnings if not explicitly suppressed (for UI calls)
		if not skip_warning then
			-- Limit warning frequency to prevent log spam
			local current_time = os.time()
			if (current_time - M._debug.last_warning_time) >= M._debug.warning_interval then
				-- Only log warning if enough time has passed since the last one
				logger.warning("Another Parley process [" .. active_pid .. "] is already running for buffer " .. buf ..
							" (found " .. active_count .. " active process(es))")
				M._debug.last_warning_time = current_time
			else
				-- Count suppressed warnings
				M._debug.warnings_suppressed = M._debug.warnings_suppressed + 1
			end
		end
		return true
	end

	return false
end

-- Set cache metrics
---@param metrics table # table with creation and read fields
M.set_cache_metrics = function(metrics)
    if metrics then
        -- Handle nil values explicitly - this allows clearing values
        M._cache_metrics.creation = metrics.creation
        M._cache_metrics.read = metrics.read
        M._cache_metrics.input = metrics.input

        -- Format log message with proper handling for nil values
        local input_str = metrics.input ~= nil and tostring(metrics.input) or "nil"
        local creation_str = metrics.creation ~= nil and tostring(metrics.creation) or "nil"
        local read_str = metrics.read ~= nil and tostring(metrics.read) or "nil"

        logger.debug("Cache metrics updated: input=" .. input_str ..
                    ", creation=" .. creation_str ..
                    ", read=" .. read_str)
    end
end

-- Get cache metrics
---@return table # table with creation, read and input fields
M.get_cache_metrics = function()
    return {
        creation = M._cache_metrics.creation,
        read = M._cache_metrics.read,
        input = M._cache_metrics.input
    }
end

-- report_debug_stats function removed - only used internally

-- Clean up stale process handles that are no longer running
M.cleanup_stale_handles = function()
	local i = 1
	local active_count = 0
	local removed_count = 0

	while i <= #M._handles do
		local h = M._handles[i]

		-- Check if process still exists
		local process_exists = false
		pcall(function()
			if type(h.pid) == "number" and h.pid > 0 then
				process_exists = uv.kill(h.pid, 0) == 0
			end
		end)

		if not process_exists then
			-- Process no longer exists, remove from handles
			logger.debug("Cleanup: Removing stale process handle [" .. h.pid .. "]")
			table.remove(M._handles, i)
			removed_count = removed_count + 1
		else
			active_count = active_count + 1
			i = i + 1
		end
	end

	logger.debug("Cleanup completed: " .. active_count .. " active processes, " ..
				 removed_count .. " stale processes removed")

end

-- stop receiving responses for all processes and clean the handles
---@param signal number | nil # signal to send to the process
M.stop = function(signal)
	if #M._handles == 0 then
		return
	end

	for _, h in ipairs(M._handles) do
		if h.handle ~= nil and not h.handle:is_closing() then
			pcall(function()
				if type(h.pid) == "number" and h.pid > 0 then
					uv.kill(h.pid, signal or 15)
				end
			end)
		end
	end

	M._handles = {}

	-- Trigger event for lualine update when stopping queries
	vim.schedule(function()
		vim.cmd("doautocmd User ParleyQueryFinished")
	end)
end

---@param buf number | nil # buffer number
---@param cmd string # command to execute
---@param args table # arguments for command
---@param callback function | nil # exit callback function(code, signal, stdout_data, stderr_data, io_error)
---@param out_reader function | nil # stdout reader function(err, data)
---@param err_reader function | nil # stderr reader function(err, data)
---@param on_start_error function | nil # scheduled launch rejection callback(message)
M.run = function(buf, cmd, args, callback, out_reader, err_reader, on_start_error)
	logger.debug("run command: " .. cmd .. " " .. table.concat(args, " "), true)
	local run_uv = M._uv or uv

	-- Run cleanup routine to remove stale processes
	M.cleanup_stale_handles()

	if M.is_busy(buf, false) then
		if on_start_error then
			vim.schedule(function()
				on_start_error("task start rejected: buffer is busy")
			end)
		end
		return
	end

	local handle, pid
	local stdout = run_uv.new_pipe(false)
	local stderr = run_uv.new_pipe(false)
	local stdout_data = ""
	local stderr_data = ""
	local exit_code
	local exit_signal
	local process_done = false
	local stdout_done = false
	local stderr_done = false
	local io_error

	local function call_safely(label, fn, ...)
		if not fn then return end
		local call_args = { ... }
		local arg_count = select("#", ...)
		local ok = xpcall(function()
			fn(unpack(call_args, 1, arg_count))
		end, function() return nil end)
		if not ok then
			logger.error(label .. " callback failed")
		end
	end

	local finish = M.once(function()
		vim.schedule(function()
			call_safely("task terminal", callback,
				exit_code, exit_signal, stdout_data, stderr_data, io_error)
			M.remove_handle(pid)
			local ok, message = pcall(vim.cmd, "doautocmd User ParleyQueryFinished")
			if not ok then logger.error("ParleyQueryFinished failed: " .. tostring(message)) end
		end)
	end)

	local function maybe_finish()
		if process_done and stdout_done and stderr_done then
			finish()
		end
	end

	local function close_pipe(pipe)
		pcall(function() pipe:read_stop() end)
		if not pipe:is_closing() then
			pipe:close()
		end
	end

	local function on_exit(code, signal)
		exit_code = code
		exit_signal = signal
		process_done = true
		if handle and not handle:is_closing() then
			handle:close()
		end
		maybe_finish()
	end

	local spawn_error
	handle, pid = run_uv.spawn(cmd, {
		args = args,
		stdio = { nil, stdout, stderr },
		hide = true,
		detach = true,
	}, on_exit)
	if not handle then
		spawn_error = pid
		close_pipe(stdout)
		close_pipe(stderr)
		if on_start_error then
			local report_start_error = M.once(on_start_error)
			vim.schedule(function()
				report_start_error("task start failed: " .. tostring(spawn_error))
			end)
		end
		return

exec
/bin/zsh -lc "rg -n 'function D\\._extract_sse_progress_event|_extract_sse_progress_event =' lua/parley/dispatcher.lua && sed -n '1,180p' lua/parley/dispatcher.lua
sed -n '380,470p' workshop/issues/000182-claude-code-style-progression-text-in-parley-chat.md
git log --oneline --decorate 27a778b7876adfdf3816b8c701e2b355252c357b..HEAD
rg -n 'fake_sse_server|activity-only|tool-use-only|fast.*mode|MODE ==' workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md tests/fixtures/fake_sse_server tests/integration/chat_progress_process_spec.lua" in /Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat
 succeeded in 0ms:
147:D._extract_sse_progress_event = function(line, provider)
--------------------------------------------------------------------------------
-- Dispatcher handles the communication between the plugin and LLM providers.
--------------------------------------------------------------------------------

local logger = require("parley.logger")
local tasker = require("parley.tasker")
local vault = require("parley.vault")
local helpers = require("parley.helper")

local default_config = require("parley.config")
local providers = require("parley.providers")

local D = {
	config = {},
	providers = {},
	query_dir = vim.fn.stdpath("cache") .. "/parley/query",
}

---@param opts table #	user config
D.setup = function(opts)
	logger.debug("dispatcher setup started\n" .. vim.inspect(opts))

	D.config.curl_params = opts.curl_params or default_config.curl_params

	D.providers = vim.deepcopy(default_config.providers)
	opts.providers = opts.providers or {}
	for k, v in pairs(opts.providers) do
		D.providers[k] = D.providers[k] or {}
		D.providers[k].disable = false
		for pk, pv in pairs(v) do
			D.providers[k][pk] = pv
		end
		if next(v) == nil then
			D.providers[k].disable = true
		end
	end

	-- remove invalid providers
	for name, provider in pairs(D.providers) do
		if type(provider) ~= "table" or provider.disable then
			D.providers[name] = nil
		elseif not provider.endpoint then
			logger.warning("Provider " .. name .. " is missing endpoint")
			D.providers[name] = nil
		end
	end

	for name, provider in pairs(D.providers) do
		vault.add_secret(name, provider.secret)
		provider.secret = nil
	end

	D.query_dir = helpers.prepare_dir(D.query_dir, "query store")

	local files = vim.fn.glob(D.query_dir .. "/*.json", false, true)
	if #files > 200 then
		logger.debug("too many query files, truncating cache")
		table.sort(files, function(a, b)
			return a > b
		end)
		for i = 100, #files do
			helpers.delete_file(files[i])
		end
	end

	logger.debug("dispatcher setup finished\n" .. vim.inspect(D))
end

---@param messages table
---@param model string | table
---@param provider string | nil
--- Build the provider-specific request payload for a chat turn.
---
--- @param messages table[]     # messages array in parley's internal shape
--- @param model string|table   # model name or params table
--- @param provider string      # provider name ("anthropic", "openai", ...)
--- @param agent_tools string[]|nil # optional list of client-side tool names
---   declared by the agent (M1 of issue #81). When non-empty, the dispatcher
---   resolves the names against the registry, encodes them via the provider's
---   tool encoder, and APPENDS the result to payload.tools — never overwriting
---   any server-side tools the adapter may have already emitted (e.g. Anthropic
---   web_search / web_fetch). Nil or empty = no client-side tools; byte-
---   identical to pre-#81 behavior for vanilla agents.
--- @return table payload
D.prepare_payload = function(messages, model, provider, agent_tools)
	if type(model) == "string" then
		return {
			model = model,
			stream = true,
			messages = messages,
		}
	end

	local adapter = providers.get(provider)
	local payload = adapter.format_payload(messages, model, provider)

	-- M1 Task 1.5: append client-side tools to whatever the adapter emitted.
	-- Non-Anthropic providers raise here when agent_tools is non-empty.
	if agent_tools and #agent_tools > 0 then
		local tools_registry = require("parley.tools")
		local defs = tools_registry.select(agent_tools)
		local client_tools
		if provider == "anthropic" then
			client_tools = providers.anthropic_encode_tools(defs)
		elseif provider == "cliproxyapi" then
			client_tools = providers.cliproxyapi_encode_tools(defs, model)
		elseif provider == "openai" then
			client_tools = providers.openai_encode_tools(defs) -- raises
		elseif provider == "googleai" then
			client_tools = providers.googleai_encode_tools(defs) -- raises
		elseif provider == "ollama" then
			client_tools = providers.ollama_encode_tools(defs) -- raises
		else
			error("tools not supported for this provider yet — see #81 follow-up (provider: "
				.. tostring(provider) .. ")")
		end

		-- APPEND, do not CLOBBER: preserves server-side tools (web_search,
		-- web_fetch) that the adapter may have already written into
		-- payload.tools. Task 1.0 baseline capture discovery.
		payload.tools = payload.tools or {}
		for _, t in ipairs(client_tools) do
			table.insert(payload.tools, t)
		end
	end

	logger.debug("payload: " .. vim.inspect(payload))
	return payload
end

-- Extract text content from a single SSE line.
-- This is the pure extraction logic, separated from query/process_lines for testability.
-- Returns extracted content string, or "" if no content found or if line is malformed.
---@param line string # a single SSE line (may have "data: " prefix which will be stripped)
---@param provider string # provider name ("openai", "anthropic", "googleai", etc.)
---@return string # extracted text content, or ""
D._extract_sse_content = function(line, provider)
	local adapter = providers.get(provider)
	return adapter.parse_sse_content(line)
end

-- Extract progress/status metadata from a single SSE line.
-- Returns nil if no progress event is available for the provider/line.
---@param line string
---@param provider string
---@return table | nil
D._extract_sse_progress_event = function(line, provider)
	local adapter = providers.get(provider)
	if type(adapter.parse_sse_progress_event) ~= "function" then
		return nil
	end
	return adapter.parse_sse_progress_event(line)
end

-- LLM query
---@param buf number | nil # buffer number
---@param provider string # provider name
---@param payload table # payload for api
---@param handler function # response handler
---@param on_exit function | nil # optional on_exit handler
---@param callback function | nil # optional callback handler
---@param on_progress function | nil # optional progress/status handler
local query = function(buf, provider, payload, handler, on_exit, callback, on_progress,
	on_activity, on_error, abort_before_start)
	-- make sure handler is a function
	if type(handler) ~= "function" then
		logger.error(
			string.format("query() expects a handler function, but got %s:\n%s", type(handler), vim.inspect(handler))
		)
		return
	end

    logger.debug("query to send is: " .. vim.json.encode(payload))

	local qid = helpers.uuid()
	tasker.set_query(qid, {
		timestamp = os.time(),
		buf = buf,
		provider = provider,
		payload = payload,
nil completion ownership, and quadratic staged-event copying; staging now uses
an O(1) persistent chain with one linear ordered flush.

### 2026-07-13 — Task 2 complete

Made subprocess completion drain-safe across process exit, stdout EOF, and
stderr EOF; added raw SSE/JSONL activity plus body-preserving provider failure
terminals; and preserved every legacy completion surface. The focused boundary
passes 110 tests. Fresh specification and quality reviews found no blocking
issues after callback exception containment, bounded diagnostics, and completion
isolation were added. `ARCH-PURE` kept transport framing deterministic at the
dispatcher seam while lifecycle ownership remains in the task integration.

### 2026-07-13 — Task 3 complete

Added the dedicated chat pending adapter: one extmark-backed virtual line per
buffer, canonical spinner frames, injected FIFO scheduler/clock seams, and
idempotent timer/registry cleanup. Sixteen integration tests include a real
libuv fast-event handoff and deterministic reveal, minimum, activity, idle,
status, cancellation, invalid-buffer, stale-lease, reentrancy, and callback
failure cases. Fresh reviews approved the boundary after closing three timer and
construction ownership gaps. `ARCH-PURE` keeps all timing policy in the reducer;
the adapter is the sole Neovim IO owner.

### 2026-07-13 — Task 4 review correction

The first fresh review reproduced an intermittent real-process stall and found
the real-entry behavioral matrix incomplete. The stall revealed that the
adapter compared high-resolution deadlines against millisecond libuv timers;
an early one-shot callback could be ignored without rescheduling. Task 4 now
fixes that timing contract at `chat_pending` itself, stress-runs the process
fixture, and adds the missing `M.respond` glue-path coverage before acceptance.

### 2026-07-13 — Task 4 complete

Removed the buffer/model-backed web spinner and routed every chat-producing
initial and recursive LLM leg through the extmark adapter. The accepted boundary
covers fast and slow output, exact deadline orders, semantic status, tool-only
completion, recursive verbs, topic exclusion, provider and pre-start failures,
Stop/stale/deleted discard cleanup, and force preflight. A real loopback curl/SSE
fixture verifies delayed success plus broken, HTTP 401, and partial HTTP 500
failures; it passed 12 consecutive stress runs. `ARCH-PURPOSE` drove the full
entry matrix, while `ARCH-DRY` moved deadline correction into the shared adapter.

### 2026-07-13 — Task 5 complete

Definition now renders an immediate selection-anchored ` ⠙` virtual spinner,
suppresses the detached luabar, and removes the transient mark before writing
the durable footnote. The generalized skill invocation terminal is exact-once
across synchronous setup failures, dispatcher abort/error, completion, cancel,
late delivery, and invalid buffers while existing Review and Voice Apply callers
retain their detached progress default. Fresh reviews approved the boundary
after malformed tool completion and every Definition-owned failure seam were
covered. `ARCH-DRY` centralizes terminal cleanup; `ARCH-PURPOSE` keeps the
selection spinner specific to Definition's natural inline anchor.

### 2026-07-13 — Task 6 complete

Mapped the new presentation boundary in README, atlas lifecycle, response
progress, web-search, inline-Definition, tool-use, provider, and traceability
documentation, then removed the orphaned buffer-progress editing API. Shadow
searches found no obsolete implementation (the sole `Submitting...` match is a
negative regression assertion). The four mapped feature groups, `make lint`,
`make test-changed`, and the full `make test` suite all exited 0; `git diff
--check origin/main...HEAD` was clean.

The noninteractive temporal smoke used real scratch-buffer extmarks, injected
production-shaped clocks, and the loopback curl/SSE process fixture. It
observed fast-answer/no-mark, delayed reveal and minimum-visible staged flush,
semantic remote-status handoff, tool recursion with the mark removed before
local execution, immediate Definition `CVR ⠙` cleanup before `CVR[^cvr]`, and
unchanged detached luabar behavior for Review. This automated substitute avoids
claiming an unavailable GUI-manual run while exercising the same user-visible
state transitions.
3653c0c (HEAD -> 000182-claude-code-style-progression-text-in-parley-chat) #182: record full verification
a7352a9 #182: document LLM progress presentation
c812c08 #182: remove obsolete buffer progress edits
1665edb #182: record Definition progress boundary
618f7ba #182: contain definition completion failures
7485f49 #182: anchor definition progress to the selection
6a13e08 #182: record real chat integration boundary
eeb29c8 #182: clarify pending chat resubmission guard
5007e67 #182: close pending chat terminal gaps
26c1c41 #182: make pending teardown deadline-safe
91c69ac #182: stage slow LLM chat output behind playful progress
cfd659b #182: record chat adapter boundary
5d69c77 #182: bound pending callback failures
d21e759 #182: close pending session ownership gaps
c4fdd6e #182: render staged chat progress with extmarks
de165dc #182: record transport boundary
70c0f1a #182: redact callback failure diagnostics
a4f5fa9 #182: isolate legacy completion surfaces
f7dd767 #182: contain transport callback failures
7245ada #182: harden drained transport contracts
2d9be72 #182: expose SSE activity and provider failures
bbc4a1c #182: record pure presentation boundary
cb46d67 #182: make staged presentation output linear
2c5356b #182: preserve nil presentation completions
7ea59f7 #182: add pure chat presentation controller
tests/fixtures/fake_sse_server:22:        if MODE == "unauthorized":
tests/fixtures/fake_sse_server:30:        if MODE == "http500":
tests/fixtures/fake_sse_server:40:        if MODE == "broken":
tests/fixtures/fake_sse_server:43:        if MODE == "delayed":
tests/fixtures/fake_sse_server:47:        if MODE == "broken":
tests/integration/chat_progress_process_spec.lua:24:local fixture = vim.fn.getcwd() .. "/tests/fixtures/fake_sse_server"
workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md:52:| `fake_sse_server` | `tests/fixtures/fake_sse_server` | new | real local HTTP/SSE process used by curl |
workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md:84:- **`fake_sse_server`** — speaks actual HTTP/SSE to curl with deterministic fast, delayed, activity-only-then-visible, partial-then-fail, and tool-use-only modes.
workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md:416:- Create: `tests/fixtures/fake_sse_server`
workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md:427:- tool-use-only completion: immediate local tool before reveal, deferred local tool after reveal until hide;
workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md:448:Implement `fake_sse_server` as an executable local Python HTTP server whose mode is selected by an argument/environment variable. The test starts it on a free port, points an OpenAI-compatible test provider at it, and invokes the real chat entry without monkeypatching `dispatcher.query` or `tasker.run`. Specify a delayed-stream mode that must show the virtual line, buffer first text until the minimum, then flush and complete. Add a partial-then-broken-connection mode that makes curl exit nonzero, an HTTP 401 error-body mode, and a partial-SSE-then-HTTP-500 mode. Each failure must hide the extmark first, expose any real partial text second, and notify the body/status error last; the status trailer is never visible or counted as activity. Ensure the server is reaped in teardown even on assertion failure.
workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md:478:Extract the current completion body into an idempotent continuation. Classify tool-use-only from the completed query's raw response before running `tool_loop.process_response`; pass that continuation to the controller so it cannot execute behind a minimum-visible indicator. Preserve `finalize_mutated_api_leg`, cursor placement, topic generation, raw logging, and lease clear ordering.
workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md:501:  tests/fixtures/fake_sse_server tests/integration/chat_progress_process_spec.lua

exec
/bin/zsh -lc 'make lint' in /Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat
 exited 2 in 0ms:
make: Makefile: No such file or directory
make: *** No rule to make target `Makefile'.  Stop.

codex
One traceability inconsistency is already concrete: the plan’s Core concepts description says the real SSE fixture implements activity-only and tool-use-only modes, but the fixture has neither. Also, the issue/plan claim `make lint`, mapped tests, and full `make test` passed, yet this checkout has no Makefile, so those recorded commands cannot run here. I’m checking whether an alternate documented harness explains that before assigning severity.
exec
/bin/zsh -lc "ls -la | sed -n '1,180p'
rg -n 'test-spec|test-changed|"'^lint:|PlenaryBusted|make test'"' . --glob '"'!workshop/issues/**'"' --glob '"'!workshop/plans/**'"' --glob '"'!workshop/lessons.md'"' --glob '"'!tests/**'"' | head -200
find . -maxdepth 3 -type f \\( -name 'Makefile' -o -name 'makefile' -o -name '*.mk' \\) -print
git ls-tree -r --name-only HEAD | rg '("'^|/)Makefile$|'"\\.mk"'$|AGENTS'"\\.md"'$'"'" in /Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat
 succeeded in 0ms:
total 200
drwxr-xr-x@ 40 xianxu  staff   1280 Jul 13 03:27 .
drwxr-xr-x@  3 xianxu  staff     96 Jul 13 01:01 ..
-rw-r--r--@  1 xianxu  staff      7 Jul 13 01:01 .ariadne-mode
drwxr-xr-x@  4 xianxu  staff    128 Jul 13 01:01 .claude
drwxr-xr-x@  3 xianxu  staff     96 Jul 13 01:01 .codex
-rw-r--r--@  1 xianxu  staff    128 Jul 13 01:01 .editorconfig
-rw-r--r--@  1 xianxu  staff    116 Jul 13 01:01 .git
drwxr-xr-x@  4 xianxu  staff    128 Jul 13 01:01 .github
-rw-r--r--@  1 xianxu  staff    892 Jul 13 01:01 .gitignore
-rw-r--r--@  1 xianxu  staff    728 Jul 13 01:01 .luacheckrc
drwxr-xr-x@  4 xianxu  staff    128 Jul 13 01:01 .opencode
drwxr-xr-x@  9 xianxu  staff    288 Jul 13 01:01 .openshell
-rw-r--r--@  1 xianxu  staff      0 Jul 13 01:01 .parley
drwxr-xr-x@  4 xianxu  staff    128 Jul 13 01:01 .tart
drwxr-xr-x@  4 xianxu  staff    128 Jul 13 01:06 .test-home
drwxr-xr-x@ 30 xianxu  staff    960 Jul 13 03:27 .test-tmp
drwxr-xr-x@  5 xianxu  staff    160 Jul 13 01:06 .test-xdg
-rw-r--r--@  1 xianxu  staff    518 Jul 13 01:01 AGENTS.local.md
-rw-r--r--@  1 xianxu  staff    318 Jul 13 01:01 ARCH.md
-rw-r--r--@  1 xianxu  staff   1100 Jul 13 01:01 LICENSE
lrwxr-xr-x@  1 xianxu  staff     19 Jul 13 01:01 Makefile -> ../ariadne/Makefile
-rw-r--r--@  1 xianxu  staff    128 Jul 13 01:01 Makefile.local
-rw-r--r--@  1 xianxu  staff   7463 Jul 13 01:01 Makefile.parley
lrwxr-xr-x@  1 xianxu  staff     28 Jul 13 01:01 Makefile.workflow -> ../ariadne/Makefile.workflow
-rw-r--r--@  1 xianxu  staff  10631 Jul 13 03:22 README.md
-rw-r--r--@  1 xianxu  staff   3959 Jul 13 01:01 SKILL.md
-rw-r--r--@  1 xianxu  staff    624 Jul 13 01:01 STYLE.md
-rw-r--r--@  1 xianxu  staff   3660 Jul 13 01:01 TOOLING.md
drwxr-xr-x@ 16 xianxu  staff    512 Jul 13 01:01 atlas
-rwxr-xr-x@  1 xianxu  staff   9293 Jul 13 01:01 bootstrap.sh
drwxr-xr-x@  8 xianxu  staff    256 Jul 13 01:05 construct
drwxr-xr-x@ 19 xianxu  staff    608 Jul 13 01:01 debug-slowness
drwxr-xr-x@  3 xianxu  staff     96 Jul 13 01:01 docs
-rw-r--r--@  1 xianxu  staff     48 Jul 13 01:01 go.mod
-rw-r--r--@  1 xianxu  staff      0 Jul 13 01:01 go.sum
drwxr-xr-x@  3 xianxu  staff     96 Jul 13 01:01 lua
-rw-r--r--@  1 xianxu  staff  14039 Jul 13 01:01 pitch-deck.html
drwxr-xr-x@ 20 xianxu  staff    640 Jul 13 01:01 scripts
drwxr-xr-x@ 10 xianxu  staff    320 Jul 13 01:01 tests
drwxr-xr-x@ 12 xianxu  staff    384 Jul 13 01:05 workshop
./TOOLING.md:5:- Run tests: `make test` (runs all unit + integration tests via plenary.nvim in headless Neovim)
./TOOLING.md:7:- Run tests for one spec: `make test-spec SPEC=chat/lifecycle` (uses `atlas/traceability.yaml` mapping)
./TOOLING.md:8:- Run tests for changed specs: `make test-changed` (runs mapped tests for changed `atlas/*/*.md` files), this is faster than full test run
./TOOLING.md:69:Verify with `luacheck --version`. If `make test` still complains, ensure
./Makefile.parley:4:.PHONY: help-parley test test-unit test-integration test-spec test-changed perf lint fixtures model-check model-checker test-clean-env
./Makefile.parley:9:	"  make test             Run all tests (unit parallel + integration sequential)" \
./Makefile.parley:10:	"  make test-unit        Run unit tests in parallel" \
./Makefile.parley:11:	"  make test-integration Run integration tests sequentially" \
./Makefile.parley:12:	"  make test-spec SPEC=  Run tests for a specific spec key" \
./Makefile.parley:13:	"  make test-changed     Run tests for changed spec files" \
./Makefile.parley:18:	"  make test-clean-env   Remove test environment directories" \
./Makefile.parley:46:RUN_SPEC = sh -c 'out=$$(mktemp "$$TMPDIR/parley-test.XXXXXX"); if nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile $$1" -c "qa!" >"$$out" 2>&1; then printf "PASS: %s\n" "$$1"; rm -f "$$out"; else { printf "===FAIL: %s===\n" "$$1"; sed "s/^/  /" "$$out"; }; echo "$$1" >> "$$FAILED_LOG"; rm -f "$$out"; exit 1; fi' _
./Makefile.parley:82:# Example: make test-spec SPEC=chat/lifecycle
./Makefile.parley:83:test-spec:
./Makefile.parley:85:		echo "Usage: make test-spec SPEC=chat/lifecycle"; \
./Makefile.parley:98:		  -c "PlenaryBustedFile $$test_file" \
./Makefile.parley:105:test-changed:
./Makefile.parley:153:			  -c "PlenaryBustedFile $$test_file" \
./Makefile.parley:174:lint:
./workshop/continuation/20260614T234009-parley-skill-system-resume.md:26:# Then: make test (expect green), and either `sdlc pr`+`sdlc merge` to land M1,
./workshop/continuation/20260611T181856-parley-readonly-harness.md:22:Start at Task 1 (the `Matcher` pure entity). Per-task test runs use the direct plenary form (`nvim --headless -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/discovery_matcher_spec.lua"`), **not** `make test-spec` (atlas-keyed, inert until Task 8).
./workshop/continuation/20260611T213232-p116.md:24:Start at Task 1 (the `Matcher` pure entity). Per-task test runs use the direct plenary form (`nvim --headless -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/discovery_matcher_spec.lua"`), **not** `make test-spec` (atlas-keyed, inert until Task 8).
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:774:- When adding ONLY new files (no modifications to existing code), regression risk in untouched modules is zero. A full `make test` regression gate is belt-and-suspenders, not load-bearing — individual file verification suffices if you can't run the full suite.
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:785:- Run `make test-changed` after spec doc changes
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:855:- **Run the FULL `make test` (lint + unit + integration) before claiming "suite green" in `--verified` — running specs individually skips the lint gate.** This session I ran each `PlenaryBustedFile` spec directly (all green) and wrote "go test/full suite green" in the close evidence — but never ran `make test`, whose FIRST target is `lint` (luacheck). A new `while pos <= #line do` (every branch returns → luacheck 542 "loop executed at most once") failed luacheck, so `make test` was RED at the gate while my Log claimed green. The boundary review caught it (FIX-THEN-SHIP), but nothing *prevented* the premature claim. Rule: the evidence for "green" is a full `make test` exit 0, not a hand-picked set of specs; individual `PlenaryBustedFile` runs are for the red→green TDD loop, not the final gate. (Bonus: luacheck flags a `while` whose body always returns — use `if` and let the iterator's repeated closure-calls do the looping.)
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:860:- **Raw `nvim_buf_set_text` is arch-forbidden (empty allow-list in `tests/arch/buffer_mutation_spec.lua`); `nvim_buf_set_lines` is allowed in `init.lua`.** #90's buffer-mutation boundary confines span edits to `buffer_edit.lua` (set_text allow-list is `{}` = zero uses). My first R1 cut used `nvim_buf_set_text` for the `[term]` wrap → `make test` red on the arch spec (lint was clean, so I only caught it at the full-suite run, not the unit loop). Fix: wrap via `nvim_buf_set_lines` (rewrite the affected whole line(s)) — the same primitive `drill_in_visual` already uses to wrap a selection, and it's on the set_lines allow-list for `init.lua`. Rule: before reaching for `nvim_buf_set_text`/`set_lines` in a non-`buffer_edit` file, check `tests/arch/buffer_mutation_spec.lua` — prefer the set_lines whole-line rewrite that existing wrappers use.
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:959:- Verification: `make lint` passed; `nvim --headless -c "PlenaryBustedFile
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:960:  tests/unit/define_spec.lua"` passed; `nvim --headless -c "PlenaryBustedFile
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:962:  passed. Full `make test` still fails in unrelated
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:1747:/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"' in /Users/xianxu/workspace/parley.nvim
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:1749:/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"' in /Users/xianxu/workspace/parley.nvim
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:2853:- I ran `git diff --check c481296d..HEAD`, `PlenaryBustedFile tests/unit/define_spec.lua`, and `PlenaryBustedFile tests/integration/highlighting_spec.lua`; all passed, with existing local Neovim startup warnings.
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:2888:- I ran `git diff --check c481296d..HEAD`, `PlenaryBustedFile tests/unit/define_spec.lua`, and `PlenaryBustedFile tests/integration/highlighting_spec.lua`; all passed, with existing local Neovim startup warnings.
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:4379:+- When adding ONLY new files (no modifications to existing code), regression risk in untouched modules is zero. A full `make test` regression gate is belt-and-suspenders, not load-bearing — individual file verification suffices if you can't run the full suite.
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:4390:+- Run `make test-changed` after spec doc changes
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:4460:+- **Run the FULL `make test` (lint + unit + integration) before claiming "suite green" in `--verified` — running specs individually skips the lint gate.** This session I ran each `PlenaryBustedFile` spec directly (all green) and wrote "go test/full suite green" in the close evidence — but never ran `make test`, whose FIRST target is `lint` (luacheck). A new `while pos <= #line do` (every branch returns → luacheck 542 "loop executed at most once") failed luacheck, so `make test` was RED at the gate while my Log claimed green. The boundary review caught it (FIX-THEN-SHIP), but nothing *prevented* the premature claim. Rule: the evidence for "green" is a full `make test` exit 0, not a hand-picked set of specs; individual `PlenaryBustedFile` runs are for the red→green TDD loop, not the final gate. (Bonus: luacheck flags a `while` whose body always returns — use `if` and let the iterator's repeated closure-calls do the looping.)
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:4465:+- **Raw `nvim_buf_set_text` is arch-forbidden (empty allow-list in `tests/arch/buffer_mutation_spec.lua`); `nvim_buf_set_lines` is allowed in `init.lua`.** #90's buffer-mutation boundary confines span edits to `buffer_edit.lua` (set_text allow-list is `{}` = zero uses). My first R1 cut used `nvim_buf_set_text` for the `[term]` wrap → `make test` red on the arch spec (lint was clean, so I only caught it at the full-suite run, not the unit loop). Fix: wrap via `nvim_buf_set_lines` (rewrite the affected whole line(s)) — the same primitive `drill_in_visual` already uses to wrap a selection, and it's on the set_lines allow-list for `init.lua`. Rule: before reaching for `nvim_buf_set_text`/`set_lines` in a non-`buffer_edit` file, check `tests/arch/buffer_mutation_spec.lua` — prefer the set_lines whole-line rewrite that existing wrappers use.
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:4564:+- Verification: `make lint` passed; `nvim --headless -c "PlenaryBustedFile
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:4565:+  tests/unit/define_spec.lua"` passed; `nvim --headless -c "PlenaryBustedFile
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:4567:+  passed. Full `make test` still fails in unrelated
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:5352:+/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"' in /Users/xianxu/workspace/parley.nvim
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:5354:+/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"' in /Users/xianxu/workspace/parley.nvim
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:6458:+- I ran `git diff --check c481296d..HEAD`, `PlenaryBustedFile tests/unit/define_spec.lua`, and `PlenaryBustedFile tests/integration/highlighting_spec.lua`; all passed, with existing local Neovim startup warnings.
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:6493:+- I ran `git diff --check c481296d..HEAD`, `PlenaryBustedFile tests/unit/define_spec.lua`, and `PlenaryBustedFile tests/integration/highlighting_spec.lua`; all passed, with existing local Neovim startup warnings.
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:6780:- When adding ONLY new files (no modifications to existing code), regression risk in untouched modules is zero. A full `make test` regression gate is belt-and-suspenders, not load-bearing — individual file verification suffices if you can't run the full suite.
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:6791:- Run `make test-changed` after spec doc changes
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:6861:- **Run the FULL `make test` (lint + unit + integration) before claiming "suite green" in `--verified` — running specs individually skips the lint gate.** This session I ran each `PlenaryBustedFile` spec directly (all green) and wrote "go test/full suite green" in the close evidence — but never ran `make test`, whose FIRST target is `lint` (luacheck). A new `while pos <= #line do` (every branch returns → luacheck 542 "loop executed at most once") failed luacheck, so `make test` was RED at the gate while my Log claimed green. The boundary review caught it (FIX-THEN-SHIP), but nothing *prevented* the premature claim. Rule: the evidence for "green" is a full `make test` exit 0, not a hand-picked set of specs; individual `PlenaryBustedFile` runs are for the red→green TDD loop, not the final gate. (Bonus: luacheck flags a `while` whose body always returns — use `if` and let the iterator's repeated closure-calls do the looping.)
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:6866:- **Raw `nvim_buf_set_text` is arch-forbidden (empty allow-list in `tests/arch/buffer_mutation_spec.lua`); `nvim_buf_set_lines` is allowed in `init.lua`.** #90's buffer-mutation boundary confines span edits to `buffer_edit.lua` (set_text allow-list is `{}` = zero uses). My first R1 cut used `nvim_buf_set_text` for the `[term]` wrap → `make test` red on the arch spec (lint was clean, so I only caught it at the full-suite run, not the unit loop). Fix: wrap via `nvim_buf_set_lines` (rewrite the affected whole line(s)) — the same primitive `drill_in_visual` already uses to wrap a selection, and it's on the set_lines allow-list for `init.lua`. Rule: before reaching for `nvim_buf_set_text`/`set_lines` in a non-`buffer_edit` file, check `tests/arch/buffer_mutation_spec.lua` — prefer the set_lines whole-line rewrite that existing wrappers use.
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:6976:- Verification: `make lint` passed; `nvim --headless -c "PlenaryBustedFile
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:6977:  tests/unit/define_spec.lua"` passed; `nvim --headless -c "PlenaryBustedFile
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:6979:  passed. Full `make test` still fails in unrelated
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:6986:- Rework verification: `nvim --headless -c "PlenaryBustedFile
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:6987:  tests/unit/parse_chat_spec.lua"` passed; `nvim --headless -c "PlenaryBustedFile
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:6988:  tests/unit/define_spec.lua"` passed; `nvim --headless -c "PlenaryBustedFile
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:6990:  "PlenaryBustedFile tests/unit/build_messages_spec.lua"` passed; `make lint`
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:6991:  passed; scoped `git diff --check` passed. Full `make test` still fails only at
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:7665:/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"' in /Users/xianxu/workspace/parley.nvim
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:7667:/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/unit/parse_chat_spec.lua"' in /Users/xianxu/workspace/parley.nvim
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:7669:/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"' in /Users/xianxu/workspace/parley.nvim
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:7817:/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/unit/build_messages_spec.lua"' in /Users/xianxu/workspace/parley.nvim
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:8163:- Passed: `PlenaryBustedFile tests/unit/define_spec.lua`
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:8164:- Passed: `PlenaryBustedFile tests/unit/parse_chat_spec.lua`
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:8165:- Passed: `PlenaryBustedFile tests/integration/highlighting_spec.lua`
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:8166:- Passed: `PlenaryBustedFile tests/unit/build_messages_spec.lua`
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:8203:- Passed: `PlenaryBustedFile tests/unit/define_spec.lua`
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:8204:- Passed: `PlenaryBustedFile tests/unit/parse_chat_spec.lua`
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:8205:- Passed: `PlenaryBustedFile tests/integration/highlighting_spec.lua`
./workshop/history/000178-recognize-footnote-footer-without-divider-close-review.md:8206:- Passed: `PlenaryBustedFile tests/unit/build_messages_spec.lua`
./workshop/history/000181-repo-root-read-wide-completion-for-all-markdown.md:191:(`ARCH-PURE`). Verification: `make -f Makefile.parley test-spec
./workshop/history/000087-in-parley-chat-s-repo-mode-put-the-name-of-the-repo-as-default-filter-in-chat-finder.md:34:- [x] `make lint` clean, `make test-unit` clean.
./workshop/history/000167-define-diagnostic-highlight-span.md:71:- 2026-07-08: closed — Implemented span-scoped define highlighting from e.diagnostic_span and snapshot/apply preservation for highlight plus diagnostic columns; verified focused red/green with nvim --headless PlenaryBustedFile tests/unit/skill_render_spec.lua and tests/integration/define_spec.lua, then git diff --check on touched files and full make test. No atlas update: bugfix only, no new architecture or workflow surface.; review verdict: FIX-THEN-SHIP
./workshop/history/000167-define-diagnostic-highlight-span.md:84:  `nvim --headless -c "PlenaryBustedFile tests/unit/skill_render_spec.lua"` and
./workshop/history/000167-define-diagnostic-highlight-span.md:85:  `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`.
./workshop/history/000167-define-diagnostic-highlight-span.md:91:  `make test`.
./workshop/history/000167-define-diagnostic-highlight-span.md:98:  `nvim --headless -c "PlenaryBustedFile tests/unit/skill_render_spec.lua"`,
./workshop/history/000167-define-diagnostic-highlight-span.md:99:  and `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`.
./workshop/history/000170-parley-chat-performance-problem-plan.md:102:      `nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/unit/perf_harness_spec.lua' -c 'qa!'`;
./workshop/history/000170-parley-chat-performance-problem-plan.md:156:      `nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/unit/line_reader_spec.lua' -c 'qa!'`,
./workshop/history/000170-parley-chat-performance-problem-plan.md:157:      `nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/arch/performance_line_reader_spec.lua' -c 'qa!'`,
./workshop/history/000170-parley-chat-performance-problem-plan.md:158:      `nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/integration/highlighting_spec.lua' -c 'qa!'`,
./workshop/history/000170-parley-chat-performance-problem-plan.md:159:      and `make -f Makefile.parley test-spec SPEC=providers/tool_use`; expect
./workshop/history/000170-parley-chat-performance-problem-plan.md:223:      `nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/integration/perf_chat_typing_spec.lua' -c 'qa!'`;
./workshop/history/000170-parley-chat-performance-problem-plan.md:453:      'PlenaryBustedFile <path>' -c 'qa!'`; expect all pass.
./workshop/history/000170-parley-chat-performance-problem-plan.md:458:nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/unit/perf_harness_spec.lua' -c 'qa!'
./workshop/history/000170-parley-chat-performance-problem-plan.md:459:nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/unit/line_reader_spec.lua' -c 'qa!'
./workshop/history/000170-parley-chat-performance-problem-plan.md:460:nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/unit/diagnostic_refresh_spec.lua' -c 'qa!'
./workshop/history/000170-parley-chat-performance-problem-plan.md:461:nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/unit/buffer_lifecycle_spec.lua' -c 'qa!'
./workshop/history/000170-parley-chat-performance-problem-plan.md:462:nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/unit/chat_respond_footnote_spec.lua' -c 'qa!'
./workshop/history/000170-parley-chat-performance-problem-plan.md:463:nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/unit/highlight_structure_spec.lua' -c 'qa!'
./workshop/history/000170-parley-chat-performance-problem-plan.md:464:nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/integration/perf_chat_typing_spec.lua' -c 'qa!'
./workshop/history/000170-parley-chat-performance-problem-plan.md:465:nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/integration/diagnostic_refresh_spec.lua' -c 'qa!'
./workshop/history/000170-parley-chat-performance-problem-plan.md:466:nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/integration/highlighting_spec.lua' -c 'qa!'
./workshop/history/000170-parley-chat-performance-problem-plan.md:467:nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/integration/chat_respond_spec.lua' -c 'qa!'
./workshop/history/000170-parley-chat-performance-problem-plan.md:468:nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/arch/performance_line_reader_spec.lua' -c 'qa!'
./workshop/history/000170-parley-chat-performance-problem-plan.md:669:Delta: added the literal `PlenaryBustedFile
./workshop/history/000135-consume-issue-vocabulary.md:73:- 2026-06-25: closed — make test-spec SPEC=issues/issue-management, make lint, make test, status-shadow sweep, and decomposed-template regression pass; issue statuses now derive from construct/generated/vocabulary/issue.json; review verdict: FIX-THEN-SHIP
./workshop/history/000135-consume-issue-vocabulary.md:74:- 2026-06-25: closed — make test-spec SPEC=issues/issue-management, make lint, make test, and status-shadow sweep pass; issue statuses now derive from construct/generated/vocabulary/issue.json; review verdict: REWORK
./workshop/history/000135-consume-issue-vocabulary.md:95:- Verification: `make test-spec SPEC=issues/issue-management` passed; `make lint` passed;
./workshop/history/000135-consume-issue-vocabulary.md:96:  `make test` passed; shadow sweep leaves only test-local fake/generated status fixtures.
./workshop/history/000135-consume-issue-vocabulary.md:99:  `make test-spec SPEC=issues/issue-management`, `make lint`, status-shadow sweep,
./workshop/history/000135-consume-issue-vocabulary.md:100:  `git diff --check`, and `make test`.
./workshop/history/000144-tool-input-safety-ls-grep-find-shell-injection-cwd-escape.md:127:- 2026-06-26: closed — judgment actual 3.5h because sdlc actual found no measurable activity; verified ack close-gate fix with direct Plenary ack spec, make test-spec SPEC=providers/tool_use, make test, and make lint all passed; review verdict: FIX-THEN-SHIP
./workshop/history/000144-tool-input-safety-ls-grep-find-shell-injection-cwd-escape.md:131:- 2026-06-26: closed — judgment actual 3.2h because sdlc actual found no measurable activity; verified after REWORK fix with make test-spec SPEC=providers/tool_use, make test, and make lint all passed; review verdict: FIX-THEN-SHIP
./workshop/history/000144-tool-input-safety-ls-grep-find-shell-injection-cwd-escape.md:132:- 2026-06-26: closed — judgment actual 3.0h because sdlc actual found no measurable activity; verified make test-spec SPEC=providers/tool_use, make test, and make lint all passed; review verdict: REWORK
./workshop/history/000144-tool-input-safety-ls-grep-find-shell-injection-cwd-escape.md:152:- Verification: `make test-spec SPEC=providers/tool_use` passed; `make test`
./workshop/history/000144-tool-input-safety-ls-grep-find-shell-injection-cwd-escape.md:166:  `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/tools_builtin_ack_spec.lua" -c "qa!"`
./workshop/history/000144-tool-input-safety-ls-grep-find-shell-injection-cwd-escape.md:167:  passed; `make test-spec SPEC=providers/tool_use` passed and includes the ack
./workshop/history/000144-tool-input-safety-ls-grep-find-shell-injection-cwd-escape.md:168:  spec; `make test` passed; `make lint` passed.
./workshop/history/000166-visual-selection-definition-system-manages-footnote-plan.md:81:Run: `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`
./workshop/history/000166-visual-selection-definition-system-manages-footnote-plan.md:104:Run: `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`
./workshop/history/000166-visual-selection-definition-system-manages-footnote-plan.md:125:Run: `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`
./workshop/history/000166-visual-selection-definition-system-manages-footnote-plan.md:144:- `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`
./workshop/history/000166-visual-selection-definition-system-manages-footnote-plan.md:145:- `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`
./workshop/history/000166-visual-selection-definition-system-manages-footnote-plan.md:176:Run: `nvim --headless -c "PlenaryBustedFile tests/unit/build_messages_spec.lua"`
./workshop/history/000166-visual-selection-definition-system-manages-footnote-plan.md:186:Run: `nvim --headless -c "PlenaryBustedFile tests/unit/build_messages_spec.lua"`
./workshop/history/000166-visual-selection-definition-system-manages-footnote-plan.md:216:- `make test`
./workshop/history/000166-visual-selection-definition-system-manages-footnote-plan.md:221:`git diff --check` passed; final `make test` passed on rerun with 0 lint
./workshop/history/000113-create-a-super-repo-mode.md:127:- [x] **M7 — Tests + atlas.** Added `atlas/modes/super_repo.md`, indexed it, mapped `modes/super_repo` in `atlas/traceability.yaml` (so `make test-spec SPEC=modes/super_repo` works). Added 5 more unit tests (markdown _scan_members, scan_issues multi-root, expand_roots, persistence gate, lualine glyph). 18 super_repo cases pass; full unit suite green.
./workshop/history/000140-file-read-tool-failed.md:51:- [x] Verify: full `make test`.
./workshop/history/000140-file-read-tool-failed.md:68:- 2026-06-25: closed — tools_dispatcher_spec 31/31 (7 new #140: absolute + relative-to-cwd roots, symlink escaping cwd+roots rejected, symlink INTO an allowed root accepted, read-vs-write gate); full make test green (exit 0, incl. parley_harness_golden 7/7); luacheck clean. Diagnosis confirmed: resolve_path_in_cwd is the single cwd-scope guard; reads-only allowlist with edit_file/write_file staying cwd-confined per the confirmed design (def.kind gate). Atlas: providers/tool_use.md cwd-scope bullet updated. Actual labeled — active-time found no window.; review verdict: FIX-THEN-SHIP
./workshop/history/000036-make-test-should-test-all.md:9:# `make test` should test all
./workshop/history/000181-repo-root-read-wide-completion-for-all-markdown-plan.md:100:Run: `make test-spec SPEC=neighborhood`
./workshop/history/000181-repo-root-read-wide-completion-for-all-markdown-plan.md:158:Run: `make test-spec SPEC=neighborhood`
./workshop/history/000181-repo-root-read-wide-completion-for-all-markdown-plan.md:190:Run: `make test-spec SPEC=providers/tool_use`
./workshop/history/000181-repo-root-read-wide-completion-for-all-markdown-plan.md:232:Run: `make test-spec SPEC=providers/tool_use`
./workshop/history/000181-repo-root-read-wide-completion-for-all-markdown-plan.md:272:Run: `make test-spec SPEC=providers/tool_use`
./workshop/history/000181-repo-root-read-wide-completion-for-all-markdown-plan.md:274:Run: `make test-spec SPEC=skills/skill-system`
./workshop/history/000181-repo-root-read-wide-completion-for-all-markdown-plan.md:300:Run: `make test-spec SPEC=providers/tool_use`
./workshop/history/000181-repo-root-read-wide-completion-for-all-markdown-plan.md:302:Run: `make test-spec SPEC=skills/skill-system`
./workshop/history/000181-repo-root-read-wide-completion-for-all-markdown-plan.md:344:Run: `make test-spec SPEC=providers/tool_use`
./workshop/history/000181-repo-root-read-wide-completion-for-all-markdown-plan.md:356:Run: `make test-spec SPEC=providers/tool_use`
./workshop/history/000181-repo-root-read-wide-completion-for-all-markdown-plan.md:385:Run: `make test-spec SPEC=providers/tool_use`
./workshop/history/000181-repo-root-read-wide-completion-for-all-markdown-plan.md:410:Run: `make test-spec SPEC=providers/tool_use`
./workshop/history/000181-repo-root-read-wide-completion-for-all-markdown-plan.md:429:Run: `make test-spec SPEC=providers/tool_use`
./workshop/history/000181-repo-root-read-wide-completion-for-all-markdown-plan.md:467:Run: `make test-spec SPEC=providers/tool_use`
./workshop/history/000181-repo-root-read-wide-completion-for-all-markdown-plan.md:487:Run: `make test-spec SPEC=providers/tool_use`
./workshop/history/000181-repo-root-read-wide-completion-for-all-markdown-plan.md:571:make test-spec SPEC=providers/tool_use
./workshop/history/000181-repo-root-read-wide-completion-for-all-markdown-plan.md:572:make test-spec SPEC=skills/skill-system
./workshop/history/000181-repo-root-read-wide-completion-for-all-markdown-plan.md:587:Run: `make test`
./workshop/history/000181-repo-root-read-wide-completion-for-all-markdown-plan.md:630:sdlc close --issue 181 --actual <MEASURED_VALUE_EMITTED_BY_SDLC_ACTUAL> --verified 'make test-spec SPEC=providers/tool_use and SPEC=skills/skill-system passed; make lint and make test exited 0; root-policy consumer/path-shape/completion shadow sweeps found no stale parallel policy; git diff --check and unfiltered origin/main...HEAD review passed'
./workshop/history/000108-timezone-diagnostics-plan.md:69:- [x] Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/timezone_diagnostics_spec.lua" -c "qa!"`
./workshop/history/000108-timezone-diagnostics-plan.md:93:- [x] Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/highlighting_spec.lua" -c "qa!"`
./workshop/history/000108-timezone-diagnostics-plan.md:125:- [x] Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/timezone_diagnostics_spec.lua" -c "qa!"`
./workshop/history/000108-timezone-diagnostics-plan.md:126:- [x] Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/highlighting_spec.lua" -c "qa!"`
./workshop/history/000108-timezone-diagnostics-plan.md:127:- [x] Run: `make test`
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:820:+Run: `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:834:+Run: `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:857:+- `nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"`
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:858:+- `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:874:+- `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:875:+- `nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"`
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:876:+- `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:894:+- `make test`
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:1174:- When adding ONLY new files (no modifications to existing code), regression risk in untouched modules is zero. A full `make test` regression gate is belt-and-suspenders, not load-bearing — individual file verification suffices if you can't run the full suite.
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:1185:- Run `make test-changed` after spec doc changes
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:1255:- **Run the FULL `make test` (lint + unit + integration) before claiming "suite green" in `--verified` — running specs individually skips the lint gate.** This session I ran each `PlenaryBustedFile` spec directly (all green) and wrote "go test/full suite green" in the close evidence — but never ran `make test`, whose FIRST target is `lint` (luacheck). A new `while pos <= #line do` (every branch returns → luacheck 542 "loop executed at most once") failed luacheck, so `make test` was RED at the gate while my Log claimed green. The boundary review caught it (FIX-THEN-SHIP), but nothing *prevented* the premature claim. Rule: the evidence for "green" is a full `make test` exit 0, not a hand-picked set of specs; individual `PlenaryBustedFile` runs are for the red→green TDD loop, not the final gate. (Bonus: luacheck flags a `while` whose body always returns — use `if` and let the iterator's repeated closure-calls do the looping.)
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:1260:- **Raw `nvim_buf_set_text` is arch-forbidden (empty allow-list in `tests/arch/buffer_mutation_spec.lua`); `nvim_buf_set_lines` is allowed in `init.lua`.** #90's buffer-mutation boundary confines span edits to `buffer_edit.lua` (set_text allow-list is `{}` = zero uses). My first R1 cut used `nvim_buf_set_text` for the `[term]` wrap → `make test` red on the arch spec (lint was clean, so I only caught it at the full-suite run, not the unit loop). Fix: wrap via `nvim_buf_set_lines` (rewrite the affected whole line(s)) — the same primitive `drill_in_visual` already uses to wrap a selection, and it's on the set_lines allow-list for `init.lua`. Rule: before reaching for `nvim_buf_set_text`/`set_lines` in a non-`buffer_edit` file, check `tests/arch/buffer_mutation_spec.lua` — prefer the set_lines whole-line rewrite that existing wrappers use.
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:1398:- Red tests: `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:1400:  "PlenaryBustedFile tests/integration/highlighting_spec.lua"` failed on missing
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:1406:- Focused green: `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`;
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:1407:  `nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"`;
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:1408:  `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`.
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:1414:  workshop/plans/000172-markdown-footnote-diagnostics-plan.md`; `make test`.
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:3404:/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"' in /Users/xianxu/workspace/parley.nvim
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:3700:+- Red tests: `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:3702:+  "PlenaryBustedFile tests/integration/highlighting_spec.lua"` failed on missing
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:3708:+- Focused green: `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`;
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:3709:+  `nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"`;
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:3710:+  `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`.
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:3716:+  workshop/plans/000172-markdown-footnote-diagnostics-plan.md`; `make test`.
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:3782:+Run: `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:3796:+Run: `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:3819:+- `nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"`
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:3820:+- `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:3836:+- `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:3837:+- `nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"`
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:3838:+- `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:3856:+- `make test`
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:3861:/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"' in /Users/xianxu/workspace/parley.nvim
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:3863:/bin/zsh -lc 'nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"' in /Users/xianxu/workspace/parley.nvim
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:3867:/bin/zsh -lc 'rg -n "''^[a-zA-Z_].*=|''^test|''^unit|''^integration|PlenaryBusted|make test|nvim --headless" Makefile TOOLING.md' in /Users/xianxu/workspace/parley.nvim
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:3869:TOOLING.md:5:- Run tests: `make test` (runs all unit + integration tests via plenary.nvim in headless Neovim)
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:3870:TOOLING.md:7:- Run tests for one spec: `make test-spec SPEC=chat/lifecycle` (uses `atlas/traceability.yaml` mapping)
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:3871:TOOLING.md:8:- Run tests for changed specs: `make test-changed` (runs mapped tests for changed `atlas/*/*.md` files), this is faster than full test run
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:3873:TOOLING.md:27:Verify with `luacheck --version`. If `make test` still complains, ensure
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:3953:- Run tests: `make test` (runs all unit + integration tests via plenary.nvim in headless Neovim)
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:3955:- Run tests for one spec: `make test-spec SPEC=chat/lifecycle` (uses `atlas/traceability.yaml` mapping)
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:3956:- Run tests for changed specs: `make test-changed` (runs mapped tests for changed `atlas/*/*.md` files), this is faster than full test run
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:3975:Verify with `luacheck --version`. If `make test` still complains, ensure
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:4006:/bin/zsh -lc "rg -n \"minimal|init.lua|PlenaryBustedFile|headless|nvim\" . tests Makefile scripts -g '"'!**/.git/**'"'" in /Users/xianxu/workspace/parley.nvim
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:4018:tests/minimal_init.vim:2:" Usage: nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedDirectory tests/ {sequential=true}"
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:4206:./TOOLING.md:5:- Run tests: `make test` (runs all unit + integration tests via plenary.nvim in headless Neovim)
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:4406:./workshop/lessons.md:123:- **Run the FULL `make test` (lint + unit + integration) before claiming "suite green" in `--verified` — running specs individually skips the lint gate.** This session I ran each `PlenaryBustedFile` spec directly (all green) and wrote "go test/full suite green" in the close evidence — but never ran `make test`, whose FIRST target is `lint` (luacheck). A new `while pos <= #line do` (every branch returns → luacheck 542 "loop executed at most once") failed luacheck, so `make test` was RED at the gate while my Log claimed green. The boundary review caught it (FIX-THEN-SHIP), but nothing *prevented* the premature claim. Rule: the evidence for "green" is a full `make test` exit 0, not a hand-picked set of specs; individual `PlenaryBustedFile` runs are for the red→green TDD loop, not the final gate. (Bonus: luacheck flags a `while` whose body always returns — use `if` and let the iterator's repeated closure-calls do the looping.)
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:4407:./workshop/lessons.md:128:- **Raw `nvim_buf_set_text` is arch-forbidden (empty allow-list in `tests/arch/buffer_mutation_spec.lua`); `nvim_buf_set_lines` is allowed in `init.lua`.** #90's buffer-mutation boundary confines span edits to `buffer_edit.lua` (set_text allow-list is `{}` = zero uses). My first R1 cut used `nvim_buf_set_text` for the `[term]` wrap → `make test` red on the arch spec (lint was clean, so I only caught it at the full-suite run, not the unit loop). Fix: wrap via `nvim_buf_set_lines` (rewrite the affected whole line(s)) — the same primitive `drill_in_visual` already uses to wrap a selection, and it's on the set_lines allow-list for `init.lua`. Rule: before reaching for `nvim_buf_set_text`/`set_lines` in a non-`buffer_edit` file, check `tests/arch/buffer_mutation_spec.lua` — prefer the set_lines whole-line rewrite that existing wrappers use.
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:4427:./workshop/issues/000172-markdown-footnote-diagnostics.md:83:- Red tests: `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:4429:./workshop/issues/000172-markdown-footnote-diagnostics.md:85:  "PlenaryBustedFile tests/integration/highlighting_spec.lua"` failed on missing
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:4430:./workshop/issues/000172-markdown-footnote-diagnostics.md:91:- Focused green: `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`;
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:4431:./workshop/issues/000172-markdown-footnote-diagnostics.md:92:  `nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"`;
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:4432:./workshop/issues/000172-markdown-footnote-diagnostics.md:93:  `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`.
./workshop/history/000172-markdown-footnote-diagnostics-close-review.md:4500:./workshop/continuation/20260611T181856-parley-readonly-harness.md:22:Start at Task 1 (the `Matcher` pure entity). Per-task test runs use the direct plenary form (`nvim --headless -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/discovery_matcher_spec.lua"`), **not** `make test-spec` (atlas-keyed, inert until Task 8).
.openshell/Makefile
.tart/Makefile
Makefile

exec
/bin/zsh -lc "sed -n '1,240p' AGENTS.local.md
sed -n '1,240p' Makefile.local
sed -n '1,220p' Makefile.parley
make -f Makefile.parley lint" in /Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat
 succeeded in 2140ms:
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

exec
/bin/zsh -lc 'make -f Makefile.parley test-spec SPEC=chat/response_progress' in /Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat
 exited 2 in 5122ms:
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

[32mSuccess: [0m	21
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
Running tests/integration/chat_progress_process_spec.lua
Scheduling: tests/integration/chat_progress_process_spec.lua

========================================
Testing:	/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/tests/integration/chat_progress_process_spec.lua
[31mFail[0m	||	chat progress real curl process stages a delayed SSE answer behind the minimum-visible playful line
            ...ey-chat/tests/integration/chat_progress_process_spec.lua:45: (number) -1
            Expected objects to be the same.
            Passed in:
            (boolean) false
            Expected:
            (boolean) true

            stack traceback:
	...ey-chat/tests/integration/chat_progress_process_spec.lua:45: in function 'start_server'
	...ey-chat/tests/integration/chat_progress_process_spec.lua:151: in function 'run'
	...ey-chat/tests/integration/chat_progress_process_spec.lua:159: in function <...ey-chat/tests/integration/chat_progress_process_spec.lua:158>

[31mFail[0m	||	chat progress real curl process orders partial output before the broken provider failure
            ...ey-chat/tests/integration/chat_progress_process_spec.lua:45: (number) -1
            Expected objects to be the same.
            Passed in:
            (boolean) false
            Expected:
            (boolean) true

            stack traceback:
	...ey-chat/tests/integration/chat_progress_process_spec.lua:45: in function 'start_server'
	...ey-chat/tests/integration/chat_progress_process_spec.lua:151: in function 'run'
	...ey-chat/tests/integration/chat_progress_process_spec.lua:178: in function <...ey-chat/tests/integration/chat_progress_process_spec.lua:177>

[31mFail[0m	||	chat progress real curl process orders partial output before the unauthorized provider failure
            ...ey-chat/tests/integration/chat_progress_process_spec.lua:45: (number) -1
            Expected objects to be the same.
            Passed in:
            (boolean) false
            Expected:
            (boolean) true

            stack traceback:
	...ey-chat/tests/integration/chat_progress_process_spec.lua:45: in function 'start_server'
	...ey-chat/tests/integration/chat_progress_process_spec.lua:151: in function 'run'
	...ey-chat/tests/integration/chat_progress_process_spec.lua:178: in function <...ey-chat/tests/integration/chat_progress_process_spec.lua:177>

[31mFail[0m	||	chat progress real curl process orders partial output before the http500 provider failure
            ...ey-chat/tests/integration/chat_progress_process_spec.lua:45: (number) -1
            Expected objects to be the same.
            Passed in:
            (boolean) false
            Expected:
            (boolean) true

            stack traceback:
	...ey-chat/tests/integration/chat_progress_process_spec.lua:45: in function 'start_server'
	...ey-chat/tests/integration/chat_progress_process_spec.lua:151: in function 'run'
	...ey-chat/tests/integration/chat_progress_process_spec.lua:178: in function <...ey-chat/tests/integration/chat_progress_process_spec.lua:177>

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
/bin/zsh -lc "nl -ba tests/integration/chat_progress_process_spec.lua | sed -n '30,52p'
ls -l tests/fixtures/fake_sse_server
head -1 tests/fixtures/fake_sse_server
command -v python3
TMP="'$(mktemp -d); tests/fixtures/fake_sse_server delayed "$TMP/ready" & pid=$!; for i in 1 2 3 4 5; do [ -f "$TMP/ready" ] && break; sleep 0.1; done; ls -l "$TMP"; [ -f "$TMP/ready" ] && cat "$TMP/ready"; kill $pid 2>/dev/null || true; wait $pid 2>/dev/null || true; rm -rf "$TMP"' in /Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat
 succeeded in 534ms:
total 0

exec
/bin/zsh -lc "rg -n '"'^function M'"\\.start|M\\.start =|return.*start|function M\\.stop|M\\.stop =' lua/parley/progress.lua && sed -n '1,220p' lua/parley/progress.lua
nl -ba lua/parley/chat_pending.lua | sed -n '225,375p'
nl -ba lua/parley/skill_invoke.lua | sed -n '100,360p'" in /Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat
 succeeded in 0ms:
47:function M.start(message)
93:function M.stop()
-- parley.progress — a detached, reusable progress bar (#133 M7).
--
-- Parley's first "substantive progress" surface: most ops are instant, but a
-- review round takes ~30s and needs a visible running cue. A floating bar pinned
-- just above the statusline (detached — not lualine, not the native 'winbar' —
-- so it can grow to multi-line detail for future long-running ops), with an
-- animated spinner + message + elapsed seconds. One active bar at a time (parley
-- runs one such op at a time). Pure `frame`/`format`; the float + timer are the
-- thin IO seam.

local M = {}

-- The single source of the braille spinner glyphs — other surfaces (the two
-- chat_respond spinners) reuse this instead of open-coding their own copy (#133).
M.SPINNER = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

--- PURE: the spinner glyph for an animation tick.
--- @param tick number
--- @return string
function M.frame(tick)
    return M.SPINNER[(tick % #M.SPINNER) + 1]
end

--- PURE: the bar's display line.
--- @param spinner string
--- @param message string|nil
--- @param elapsed number|nil  seconds
--- @return string
function M.format(spinner, message, elapsed)
    return string.format(" %s %s  (%ds)", spinner or "", message or "", elapsed or 0)
end

-- The single active session: { buf, win, timer, tick, start, message }.
local _s = nil

local function render()
    if not _s or not vim.api.nvim_buf_is_valid(_s.buf) then
        return
    end
    local line = M.format(M.frame(_s.tick), _s.message, os.time() - _s.start)
    vim.api.nvim_buf_set_lines(_s.buf, 0, -1, false, { line })
end

--- Start (or replace) the progress bar with `message`.
--- @param message string|nil
--- @return boolean ok
function M.start(message)
    M.stop()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    local ui = vim.api.nvim_list_uis()[1] or { width = 80, height = 24 }
    local ok, win = pcall(vim.api.nvim_open_win, buf, false, {
        relative = "editor",
        row = math.max(0, ui.height - 2), -- just above the statusline
        col = 0,
        width = math.max(1, ui.width),
        height = 1,
        style = "minimal",
        focusable = false,
        zindex = 200,
    })
    if not ok then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
        return false
    end
    pcall(function()
        vim.wo[win].winhighlight = "Normal:StatusLine" -- read as a bar
    end)
    _s = { buf = buf, win = win, tick = 0, start = os.time(), message = message or "working…" }
    render()
    _s.timer = vim.loop.new_timer()
    _s.timer:start(120, 120, vim.schedule_wrap(function()
        if not _s then
            return
        end
        _s.tick = _s.tick + 1
        render()
    end))
    return true
end

--- Update the bar's message (no-op if not active).
--- @param message string
function M.update(message)
    if _s then
        _s.message = message
        render()
    end
end

--- Stop + tear down the bar (idempotent).
function M.stop()
    if not _s then
        return
    end
    if _s.timer then
        pcall(function()
            _s.timer:stop()
            _s.timer:close()
        end)
    end
    pcall(vim.api.nvim_win_close, _s.win, true)
    _s = nil
end

--- Is a progress bar currently shown?
--- @return boolean
function M.is_active()
    return _s ~= nil
end

return M
   225
   226	    local function rearm_early_timer(event, state)
   227	        local deadline
   228	        local name
   229	        local event_factory
   230	        if event.type == "reveal_due" and state.phase == "waiting" then
   231	            deadline = state.reveal_at
   232	            name = "reveal"
   233	            event_factory = function()
   234	                return { type = "reveal_due", now_ms = now_ms() }
   235	            end
   236	        elseif event.type == "minimum_due" and state.phase == "showing" then
   237	            deadline = state.minimum_at
   238	            name = "minimum"
   239	            event_factory = function()
   240	                return { type = "minimum_due", now_ms = now_ms() }
   241	            end
   242	        elseif event.type == "idle"
   243	                and (state.phase == "waiting" or state.phase == "showing") then
   244	            deadline = state.verb_due_at
   245	            name = "idle"
   246	            event_factory = function()
   247	                return {
   248	                    type = "idle",
   249	                    now_ms = now_ms(),
   250	                    verb_index = session.choose_verb_index(#verbs),
   251	                }
   252	            end
   253	        end
   254	        if deadline and event.now_ms < deadline then
   255	            schedule_after(name, math.max(1, math.ceil(deadline - event.now_ms)), event_factory)
   256	            return true
   257	        end
   258	        return false
   259	    end
   260
   261	    local function apply_actions(actions, context)
   262	        for _, action in ipairs(actions) do
   263	            if action.type == "show_playful" then
   264	                session.playful_verb = action.verb
   265	                if not render_playful() then
   266	                    finish()
   267	                    return
   268	                end
   269	                start_frame_timer()
   270	            elseif action.type == "render_status" then
   271	                session.playful_verb = nil
   272	                cancel_timer("frame")
   273	                if not render(action.message) then
   274	                    finish()
   275	                    return
   276	                end
   277	            elseif action.type == "emit_content" then
   278	                call_safely("content emitter", session.emit_content, action.qid, action.chunk)
   279	            elseif action.type == "hide" then
   280	                hide()
   281	            elseif action.type == "continue_completion" then
   282	                hide()
   283	                call_safely("completion", action.completion)
   284	            elseif action.type == "surface_failure" then
   285	                hide()
   286	                call_safely("failure surface", context and context.surface_failure, action.error)
   287	            end
   288	        end
   289	    end
   290
   291	    dispatch = function(event, context)
   292	        if session.finished then
   293	            return
   294	        end
   295	        if event.type ~= "cancel" and event.type ~= "invalid" then
   296	            local ok, valid = pcall(session.lease_valid)
   297	            if not ok or not valid then
   298	                event = { type = "stale" }
   299	            end
   300	        end
   301	        local previous_phase = session.state.phase
   302	        local next_state, actions = presentation.transition(session.state, event)
   303	        session.state = next_state
   304	        if next_state.phase == "finished" then
   305	            -- Release registry/timer ownership before a continuation starts a
   306	            -- recursive LLM leg in this buffer.
   307	            finish()
   308	            if event.type == "cancel" or event.type == "stale" or event.type == "invalid" then
   309	                call_safely("discard terminal", session.on_discard, event.type, event.reason)
   310	            end
   311	            apply_actions(actions, context)
   312	            return
   313	        end
   314	        apply_actions(actions, context)
   315
   316	        if session.finished then
   317	            return
   318	        end
   319	        if rearm_early_timer(event, next_state) then
   320	            return
   321	        end
   322	        if previous_phase == "waiting" and next_state.phase ~= "waiting" then
   323	            cancel_timer("reveal")
   324	            if next_state.phase == "released" then
   325	                cancel_timer("idle")
   326	            end
   327	        end
   328	        if next_state.phase == "showing" and previous_phase ~= "showing" then
   329	            schedule_after("minimum", 1000, function()
   330	                return { type = "minimum_due", now_ms = now_ms() }
   331	            end)
   332	        end
   333	        if previous_phase == "showing" and next_state.phase ~= "showing" then
   334	            cancel_timer("minimum")
   335	            cancel_timer("frame")
   336	            cancel_timer("idle")
   337	        elseif (event.type == "activity" or event.type == "idle")
   338	                and (next_state.phase == "waiting" or next_state.phase == "showing") then
   339	            reset_idle_timer()
   340	        end
   341	    end
   342
   343	    local function submit(event_factory, context)
   344	        scheduler.enqueue(function()
   345	            if session.finished then
   346	                return
   347	            end
   348	            if not vim.api.nvim_buf_is_valid(session.buf) then
   349	                dispatch({ type = "invalid" })
   350	                return
   351	            end
   352	            dispatch(event_factory(), context)
   353	        end)
   354	    end
   355
   356	    session.activity = function(_self, _qid)
   357	        submit(function()
   358	            return {
   359	                type = "activity",
   360	                now_ms = now_ms(),
   361	                verb_index = session.choose_verb_index(#verbs),
   362	            }
   363	        end)
   364	    end
   365
   366	    session.content = function(_self, qid, chunk)
   367	        submit(function()
   368	            return { type = "content", now_ms = now_ms(), qid = qid, chunk = chunk }
   369	        end)
   370	    end
   371
   372	    session.progress = function(_self, _qid, event)
   373	        submit(function()
   374	            if type(event) ~= "table" then
   375	                event = { message = tostring(event or "") }
   100	--- @param buf number the artifact buffer
   101	--- @param manifest table SkillManifest
   102	--- @param args table|nil completable-arg values
   103	--- @param opts table|nil { manual=boolean?, no_reload=boolean?, document=string?,
   104	---   detached_progress=boolean?, on_terminal=fun(result)?, on_done=fun(result)? }
   105	function M.invoke(buf, manifest, args, opts)
   106	    opts = opts or {}
   107	    local manual = opts.manual
   108	    if manual == nil then
   109	        manual = true
   110	    end
   111
   112	    local p = parley()
   113	    local llm = require("parley.dispatcher") -- LLM dispatcher: prepare_payload / query
   114	    local tools_dispatcher = require("parley.tools.dispatcher") -- tool dispatcher: execute_call
   115	    local providers = require("parley.providers")
   116	    local tasker = require("parley.tasker")
   117	    local tools_registry = require("parley.tools")
   118	    local assembly = require("parley.skill_assembly")
   119	    local skill_render = require("parley.skill_render")
   120
   121	    local function deliver_attempt(result, deliver_done)
   122	        if opts.on_terminal then
   123	            local ok = pcall(opts.on_terminal, result)
   124	            if not ok then p.logger.error("skill terminal callback failed") end
   125	        end
   126	        if deliver_done and opts.on_done then
   127	            local ok = pcall(opts.on_done, result)
   128	            if not ok then p.logger.error("skill completion callback failed") end
   129	        end
   130	    end
   131
   132	    if _in_flight[buf] then
   133	        p.logger.warning("skill " .. tostring(manifest.name) .. ": already running on this buffer")
   134	        deliver_attempt({ ok = false, msg = "already running" }, true)
   135	        return
   136	    end
   137
   138	    -- This exchange's generation; on_exit/on_abort no-op if superseded (#133).
   139	    local gen = (_gen[buf] or 0) + 1
   140	    _gen[buf] = gen
   141	    local finished = false
   142	    local detached_progress = opts.detached_progress ~= false
   143	    local progress_started = false
   144	    local function finish(result, deliver_done)
   145	        if finished then return false end
   146	        finished = true
   147	        if progress_started then
   148	            pcall(function() require("parley.progress").stop() end)
   149	            progress_started = false
   150	        end
   151	        if _terminals[buf] == finish then
   152	            _terminals[buf] = nil
   153	            _in_flight[buf] = nil
   154	        end
   155	        deliver_attempt(result, deliver_done)
   156	        return true
   157	    end
   158	    _terminals[buf] = finish
   159
   160	    if not vim.api.nvim_buf_is_valid(buf) then
   161	        finish({ ok = false, msg = "buffer invalid" }, false)
   162	        return
   163	    end
   164	    local ok_path, artifact_path = pcall(vim.api.nvim_buf_get_name, buf)
   165	    if not ok_path or artifact_path == "" then
   166	        p.logger.warning("skill " .. tostring(manifest.name) .. ": buffer has no file — open the artifact first")
   167	        finish({ ok = false, msg = "buffer has no file" }, true)
   168	        return
   169	    end
   170
   171	    -- Sync file == buffer so edits compute + apply against the same content.
   172	    -- A read-only skill (opts.no_reload — e.g. define, #161) makes no edits, so
   173	    -- it must NOT persist the user's in-progress buffer to disk.
   174	    if vim.bo[buf].modified and not opts.no_reload then
   175	        vim.api.nvim_buf_call(buf, function()
   176	            pcall(vim.cmd, "silent write")
   177	        end)
   178	    end
   179
   180	    local original = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
   181	    -- source(ctx) does IO (reads SKILL.md / style guides) and can fail — e.g.
   182	    -- voice_apply with a missing style file. Route the failure through the SAME
   183	    -- on_done({ok=false}) channel as the other early-outs (no file / no agent)
   184	    -- rather than throwing a raw Lua error; skill_invoke is the generic P2 driver.
   185	    local ok_src, body = pcall(manifest.source, { args = args or {}, repo_root = p.config.repo_root })
   186	    if not ok_src then
   187	        p.logger.error("skill " .. tostring(manifest.name) .. ": source failed: " .. tostring(body))
   188	        finish({ ok = false, msg = "source failed: " .. tostring(body) }, true)
   189	        return
   190	    end
   191	    -- opts.document lets a caller send a bounded context (e.g. define's enclosing
   192	    -- exchange) instead of the whole buffer; defaults to the buffer content.
   193	    local inv = assembly.build_invocation(manifest, { body = body, document = opts.document or original, manual = manual })
   194
   195	    local agent = assembly.resolve_agent(manifest, {
   196	        config = p.config,
   197	        get_agent = p.get_agent,
   198	        agent_names = p._agents,
   199	        agents = p.agents,
   200	    })
   201	    if not agent then
   202	        p.logger.warning("skill " .. tostring(manifest.name) .. ": no tool-capable agent resolved")
   203	        finish({ ok = false, msg = "no agent" }, true)
   204	        return
   205	    end
   206
   207	    local payload = llm.prepare_payload(inv.messages, agent.model, agent.provider, inv.tools)
   208	    if inv.tool_choice then
   209	        payload.tool_choice = inv.tool_choice
   210	    end
   211	    -- Large-document tool output needs headroom: a multi-edit propose_edits batch
   212	    -- echoes old/new/explain per edit and easily exceeds the default (4096),
   213	    -- truncating the tool JSON → empty decode. (Was skill_runner's explicit bump.)
   214	    payload.max_tokens = math.max(payload.max_tokens or 0, 100000)
   215
   216	    skill_render.clear_decorations(buf)
   217
   218	    local neighborhood = require("parley.neighborhood")
   219	    local root_policy = neighborhood.policy_for_buf(buf)
   220	        or neighborhood.policy_from_roots(vim.fn.fnamemodify(artifact_path, ":h"), nil, {})
   221	    local cwd = root_policy.write_root
   222
   223	    _in_flight[buf] = true
   224	    -- Detached progress bar: this is a ~30s headless op, so show a running cue
   225	    -- (the first substantive-progress surface, #133 M7). Stopped on exit/abort.
   226	    if detached_progress then
   227	        progress_started = require("parley.progress").start(
   228	            "Parley " .. tostring(manifest.name) .. " running…")
   229	    end
   230	    local ok_query = pcall(llm.query,
   231	        nil, -- headless: no streaming buffer insertion
   232	        agent.provider,
   233	        payload,
   234	        function() end, -- handler (headless)
   235	        function(qid) -- on_exit
   236	            vim.schedule(function()
   237	                -- Superseded by a newer exchange (the old one was cancelled) →
   238	                -- no-op so we don't reload/re-render or clobber the new state.
   239	                if finished or _gen[buf] ~= gen then
   240	                    return
   241	                end
   242	                if not vim.api.nvim_buf_is_valid(buf) then
   243	                    finish({ ok = false, msg = "buffer invalid" }, false)
   244	                    return
   245	                end
   246	                local function complete()
   247	                    local qt = tasker.get_query(qid) or {}
   248	                    local calls = providers.decode_anthropic_tool_calls_from_stream(qt.raw_response or "")
   249	                    local results = {}
   250	                    local applied = 0
   251	                    local errors = {}
   252	                    for i, call in ipairs(calls) do
   253	                        if call.name == "propose_edits" then
   254	                            call.input = call.input or {}
   255	                            call.input.file_path = artifact_path -- artifact-bound
   256	                            -- Some models emit `edits` as a JSON STRING rather than an
   257	                            -- array; coerce it once here so the batch actually applies
   258	                            -- (and render_propose_edits below gets a table). #133
   259	                            if type(call.input.edits) == "string" then
   260	                                local ok, decoded = pcall(vim.json.decode, call.input.edits)
   261	                                if ok and type(decoded) == "table" then
   262	                                    call.input.edits = decoded
   263	                                end
   264	                            end
   265	                        end
   266	                        results[i] = tools_dispatcher.execute_call(call, tools_registry,
   267	                            { cwd = cwd, root_policy = root_policy,
   268	                              page_limit = require("parley.config").tool_result_page_lines }) -- #140 #139
   269	                        if call.name == "propose_edits" then
   270	                            if results[i].is_error then
   271	                                table.insert(errors, results[i].content)
   272	                            else
   273	                                applied = applied + 1
   274	                            end
   275	                        end
   276	                    end
   277	                    if not vim.api.nvim_buf_is_valid(buf) then
   278	                        finish({ ok = false, msg = "buffer invalid" }, false)
   279	                        return
   280	                    end
   281	                    if not opts.no_reload then
   282	                        reload_buffer(buf)
   283	                    end
   284	                    if not vim.api.nvim_buf_is_valid(buf) then
   285	                        finish({ ok = false, msg = "buffer invalid" }, false)
   286	                        return
   287	                    end
   288	                    local new_content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
   289	                    local decorations = {}
   290	                    for _, call in ipairs(calls) do
   291	                        if not vim.api.nvim_buf_is_valid(buf) then
   292	                            finish({ ok = false, msg = "buffer invalid" }, false)
   293	                            return
   294	                        end
   295	                        if call.name == "propose_edits" then
   296	                            for _, d in ipairs(render_propose_edits(buf, call, original, new_content)) do
   297	                                table.insert(decorations, d)
   298	                            end
   299	                        end
   300	                    end
   301	                    -- Surface failure rather than swallowing it: a tool error, or no
   302	                    -- tool call at all (a truncated/empty response), is logged so the
   303	                    -- caller (review) can STOP rather than resubmit blindly.
   304	                    if #calls == 0 then
   305	                        p.logger.warning("skill " .. tostring(manifest.name)
   306	                            .. ": model returned no tool call (response may be truncated)")
   307	                    end
   308	                    for _, e in ipairs(errors) do
   309	                        p.logger.error("skill " .. tostring(manifest.name) .. ": " .. tostring(e))
   310	                    end
   311	                    -- Pure-fed payload: original/new_content/decorations let a
   312	                    -- caller (review) journal the round without re-reading the
   313	                    -- buffer (#133 M3).
   314	                    finish({
   315	                        ok = (#errors == 0),
   316	                        applied = applied,
   317	                        calls = calls,
   318	                        results = results,
   319	                        original = original,
   320	                        new_content = new_content,
   321	                        decorations = decorations,
   322	                    }, true)
   323	                end
   324	                local ok_completion = xpcall(complete, function() return nil end)
   325	                if not ok_completion then
   326	                    p.logger.error("skill " .. tostring(manifest.name) .. " completion failed")
   327	                    finish({ ok = false, msg = "completion failed" }, true)
   328	                end
   329	            end)
   330	        end,
   331	        nil,
   332	        nil,
   333	        function(msg) -- on_abort
   334	            if finished or _gen[buf] ~= gen then
   335	                return -- superseded by a newer exchange (cancelled) → no-op
   336	            end
   337	            p.logger.error("skill " .. tostring(manifest.name) .. " abort: " .. tostring(msg))
   338	            finish({ ok = false, msg = tostring(msg) }, true)
   339	        end,
   340	        nil,
   341	        function(_qid, transport_error) -- on_error (dispatcher argument 10)
   342	            if finished or _gen[buf] ~= gen then return end
   343	            p.logger.error("skill " .. tostring(manifest.name) .. " transport error")
   344	            finish({ ok = false, msg = "transport error", error = transport_error }, true)
   345	        end
   346	    )
   347	    if not ok_query then
   348	        p.logger.error("skill " .. tostring(manifest.name) .. " query failed")
   349	        finish({ ok = false, msg = "query failed" }, true)
   350	    end
   351	end
   352
   353	return M

exec
/bin/zsh -lc "sed -n '1,300p' lua/parley/skill_assembly.lua
sed -n '1,240p' lua/parley/skill_providers.lua
sed -n '1,160p' lua/parley/skills/define/init.lua
rg -n 'function M\\.clear_decorations|clear_decorations' lua/parley/skill_render.lua
nl -ba workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md | sed -n '15,92p'
nl -ba workshop/issues/000182-claude-code-style-progression-text-in-parley-chat.md | sed -n '100,165p'" in /Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat
 succeeded in 0ms:
-- parley.skill_assembly — the PURE P2 (artifact-mode) context-assembler.
--
-- build_invocation turns a skill manifest + the already-sourced body + the
-- artifact document into the LLM-call inputs the thin M3 driver feeds to
-- dispatcher.prepare_payload. resolve_agent is the agent cascade salvaged from
-- skill_runner, made PURE by INJECTING its config + agent-registry deps (v1 read
-- the parley module directly). No IO, no require("parley") here — the driver
-- supplies `body` (the source() result) and the agent deps at the boundary.

local M = {}

--- Build the LLM-call inputs for invoking a skill on an artifact.
--- The skill body is conveyed AS the `role="system"` message (the provider
--- adapter extracts it into the top-level `system`, per parley convention) — so
--- there is NO separate `system_prompt` field (that would double-apply).
--- @param manifest table SkillManifest
--- @param opts table { body = string, document = string, manual = boolean? }
--- @return table { messages, tools, tool_choice }
function M.build_invocation(manifest, opts)
    opts = opts or {}
    local body = opts.body or ""

    -- tools granted whenever invoked; elevated granted only on MANUAL invocation
    -- (the #129 hook — manual-only elevation).
    local tools = {}
    for _, t in ipairs(manifest.tools or {}) do
        table.insert(tools, t)
    end
    if opts.manual then
        for _, t in ipairs(manifest.elevated or {}) do
            table.insert(tools, t)
        end
    end

    local tool_choice = nil
    if manifest.force_tool then
        tool_choice = { type = "tool", name = manifest.force_tool }
    end

    return {
        messages = {
            { role = "system", content = body },
            { role = "user", content = opts.document or "" },
        },
        tools = tools,
        tool_choice = tool_choice,
    }
end

--- Resolve the agent for a skill via the salvaged cascade. PURE given `deps`:
---   deps.config       = { skills = {...}, review_agent = name?, skill_agent = name? }
---   deps.get_agent    = function(name) -> agent|nil
---   deps.agent_names  = ordered list of agent names (for the tool-capable scan)
---   deps.agents       = name -> agent table
--- Cascade: per-skill config → legacy review_agent → manifest default →
--- global skill_agent → first tool-capable (anthropic|cliproxyapi).
--- @param manifest table SkillManifest
--- @param deps table injected config + agent registry
--- @return table|nil agent
function M.resolve_agent(manifest, deps)
    local config = deps.config or {}
    local get_agent = deps.get_agent or function() return nil end

    -- 1: per-skill config override
    for _, cfg in ipairs(config.skills or {}) do
        if cfg.name == manifest.name and cfg.agent then
            local agent = get_agent(cfg.agent)
            if agent then return agent end
        end
    end

    -- 1b: legacy review_agent fallback (review skill only)
    if manifest.name == "review" and config.review_agent then
        local agent = get_agent(config.review_agent)
        if agent then return agent end
    end

    -- 2: manifest default
    if manifest.agent then
        local agent = get_agent(manifest.agent)
        if agent then return agent end
    end

    -- 3: global skill_agent config
    if config.skill_agent then
        local agent = get_agent(config.skill_agent)
        if agent then return agent end
    end

    -- 4: first tool-capable agent
    for _, name in ipairs(deps.agent_names or {}) do
        local agent = (deps.agents or {})[name]
        if agent and (agent.provider == "anthropic" or agent.provider == "cliproxyapi") then
            return agent
        end
    end

    return nil
end

return M
-- parley.skill_providers — skill sources, all emitting uniform SkillManifests.
--
-- A provider is just `{ list = function() → {SkillManifest…} }`. The registry
-- (skill_registry.lua) unions providers; consumers never branch on origin —
-- the disk/virtual difference lives entirely inside how the provider built the
-- manifest's `source` closure.
--
-- DiskProvider scans a root dir and loads each `<dir>/init.lua` by ABSOLUTE
-- path (`loadfile`, so it works for the plugin root AND `~/.config/parley/
-- skills/` alike — not just package-path requires). The manifest's `source` is
-- a closure capturing that absolute dir, which DELETES the v1 `debug.getinfo`
-- path-guessing dance (the deleted skill_runner did this): the path is already
-- in hand at discovery time.

local M = {}

local function read_file(path)
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    local content = f:read("*a")
    f:close()
    return content
end

local function file_exists(path)
    return vim.loop.fs_stat(path) ~= nil
end

-- Build a manifest from a loaded skill-definition table + its absolute dir.
-- Source resolution (the unified `source(ctx)` contract):
--   1. an explicit `source(ctx)` function (the new declarative field), wrapped so
--      the provider injects `ctx.skill_md` from `<dir>/SKILL.md` — the dir is a
--      discovery-time fact the closure already holds, so a dynamic-body skill
--      (voice_apply) composes `ctx.skill_md ⊕ <extra>` without re-deriving the
--      dir (this is v1's 4th `skill_md` arg, minus the debug.getinfo dance).
--   2. else `<dir>/SKILL.md` read via a closure over `dir`.
-- (No v1 `system_prompt` fallback: that 4-arg contract is retired in M4, and no
-- bundled skill needs it — all ship a SKILL.md. A dir with neither yields
-- source = nil and is validate-dropped by the registry.)
local function manifest_from_def(def, dir)
    local source
    if type(def.source) == "function" then
        local inner = def.source
        source = function(ctx)
            ctx = ctx or {}
            -- Enrich (without mutating the caller's table) with two discovery-time
            -- facts the closure already holds: `skill_md` (the dir's SKILL.md, only
            -- if a SKILL.md exists and the caller didn't supply one) and `skill_dir`
            -- (the absolute dir, whenever absent — independent of SKILL.md, since a
            -- dynamic skill like review reads its modes/ subdir from it). #133.
            local needs_md = ctx.skill_md == nil and file_exists(dir .. "/SKILL.md")
            local needs_dir = ctx.skill_dir == nil
            if needs_md or needs_dir then
                local enriched = {}
                for k, v in pairs(ctx) do
                    enriched[k] = v
                end
                if needs_md then
                    enriched.skill_md = read_file(dir .. "/SKILL.md") or ""
                end
                if needs_dir then
                    enriched.skill_dir = dir
                end
                ctx = enriched
            end
            return inner(ctx)
        end
    elseif file_exists(dir .. "/SKILL.md") then
        source = function()
            return read_file(dir .. "/SKILL.md") or ""
        end
    end
    return {
        name = def.name,
        description = def.description,
        scope = def.scope,
        activation = def.activation,
        source = source,
        tools = def.tools,
        elevated = def.elevated,
        force_tool = def.force_tool,
        args = def.args,
        agent = def.agent,
    }
end

--- A disk provider over `root` (a dir of `<name>/init.lua` skill dirs).
--- Emits CANDIDATE manifests — a dir with a `name` but no resolvable body
--- (no `source`/SKILL.md) yields `source = nil`; the registry is the single
--- validation point and validate-drops such a candidate.
--- @param root string absolute directory path
--- @return table provider with a `list()` method
function M.disk(root)
    return {
        list = function()
            local out = {}
            local handle = vim.loop.fs_scandir(root)
            if not handle then
                return out
            end
            while true do
                local name, typ = vim.loop.fs_scandir_next(handle)
                if not name then
                    break
                end
                if typ == "directory" then
                    local dir = root .. "/" .. name
                    local initpath = dir .. "/init.lua"
                    if file_exists(initpath) then
                        local ok, def = pcall(function()
                            return loadfile(initpath)()
                        end)
                        if ok and type(def) == "table" then
                            -- support both { name, ... } and { skill = { ... } }
                            local skill = def.skill or def
                            if type(skill.name) == "string" then
                                table.insert(out, manifest_from_def(skill, dir))
                            end
                        end
                    end
                    -- dir without a loadable init.lua/name → skipped (not an error)
                end
            end
            return out
        end,
    }
end

--- A virtual provider over a list of generators (`function() → SkillManifest`).
--- The seam for runtime-generated skills (the first, `repo_discovery`, arrives
--- in M5). A generator that errors is skipped (it shouldn't sink discovery).
--- @param generators table list of zero-arg manifest generators
--- @return table provider with a `list()` method
function M.virtual(generators)
    return {
        list = function()
            local out = {}
            for _, gen in ipairs(generators or {}) do
                local ok, m = pcall(gen)
                if ok and type(m) == "table" then
                    table.insert(out, m)
                end
            end
            return out
        end,
    }
end

return M
-- The `define` skill (#161): define a user-selected term concisely, inline.
--
-- Auto-discovered by the disk provider (no registry edit). Invoked from
-- `define_visual` (lua/parley/init.lua) via skill_invoke with args.phrase and a
-- bounded `opts.document`. There is deliberately NO `force_tool`: an unforced
-- turn (tool_choice = auto) lets the server-side web_search tool run when the
-- global `:ToggleWebSearch` is on. `source(ctx)` owns the whole system prompt
-- (folding in the phrase), so there is no SKILL.md.

local M = {
    name = "define",
    description = "Define a selected term concisely, inline.",
    scope = "global",
    activation = { manual = true },
    tools = { "emit_definition" },
    -- no force_tool (see note above)
}

function M.source(ctx)
    local phrase = ctx and ctx.args and ctx.args.phrase or ""
    return table.concat({
        "You define a single term for a reader of a chat transcript.",
        "The user selected this phrase: «" .. phrase .. "».",
        "Define it concisely (1–3 sentences) AS USED in the document below.",
        "Prefer a plain, jargon-free explanation.",
        "If it is an unfamiliar or fresh proper noun and web search is available,",
        "you may search first. Then ALWAYS call the emit_definition tool exactly",
        "once with {term, definition}. Do not reply in plain prose.",
    }, "\n")
end

return M
32:function M.clear_decorations(buf)
42:M.dismiss = M.clear_decorations
325:    M.clear_decorations(buf)
    15	## Core concepts
    16
    17	### Pure entities
    18
    19	| Name | Lives in | Status |
    20	|------|----------|--------|
    21	| `chat_presentation.initial` | `lua/parley/chat_presentation.lua` | new |
    22	| `chat_presentation.transition` | `lua/parley/chat_presentation.lua` | new |
    23	| `chat_presentation.progress_message` | `lua/parley/chat_presentation.lua` | new |
    24
    25	- **`chat_presentation.initial`** — constructs one LLM leg's `waiting` state with reveal and verb-idle deadlines, an initial non-repeating verb, and no staged events.
    26	  - **Relationships:** One state per dispatcher leg; a recursive tool loop creates a new state rather than sharing history with the prior leg.
    27	  - **DRY rationale:** One initial-state contract prevents chat callbacks and timers from inventing different deadline defaults.
    28	  - **Future extensions:** New cosmetic vocabularies can widen the injected verb list; timings remain fixed for #182.
    29	- **`chat_presentation.transition`** — reduces one serialized event (`reveal_due`, `minimum_due`, `activity`, `content`, `progress`, `complete`, `failure`, or `cancel`) into a new plain-table state plus ordered actions (`show_playful`, `render_status`, `emit_content`, `hide`, `continue_completion`, `surface_failure`). It never calls Neovim, a clock, or randomness.
    30	  - **Relationships:** N:1 events to one leg state; actions are consumed 1:1 in order by `chat_pending`.
    31	  - **DRY rationale:** Timer, SSE, stream, completion, and cancellation races converge through one transition table instead of independently mutating flags in `chat_respond`.
    32	  - **Future extensions:** Additional visible event kinds can join the staged-event union without changing adapter ownership.
    33	- **`chat_presentation.progress_message`** — accumulates provider detail fragments and derives the existing meaningful reasoning/tool status text from semantic progress events.
    34	  - **Relationships:** One progress-detail state belongs to one presentation state; each `progress` event yields at most one rendered status.
    35	  - **DRY rationale:** Moves the current deterministic formatter out of async glue and makes both staged and released progress use the same rule.
    36	  - **Future extensions:** New provider-normalized `kind` values widen this formatter, not `chat_respond`.
    37
    38	All three symbols are tested without Neovim IO or mocks in `tests/unit/chat_presentation_spec.lua` (`ARCH-PURE`).
    39
    40	### Integration points
    41
    42	| Name | Lives in | Status | Wraps |
    43	|------|----------|--------|-------|
    44	| `chat_pending.start` | `lua/parley/chat_pending.lua` | new | Neovim extmarks, libuv timers, serialized callback actions |
    45	| `selection_spinner.start` | `lua/parley/selection_spinner.lua` | new | selection-anchored extmark and animation timer |
    46	| `tasker.run` | `lua/parley/tasker.lua` | modified | drain-safe subprocess exit plus stdout/stderr pipe EOF |
    47	| `vault.run_with_secret` | `lua/parley/vault.lua` | modified | secret resolution and exactly-once launch abort delivery |
    48	| `dispatcher.query` | `lua/parley/dispatcher.lua` | modified | curl process, raw SSE stream, transport terminal |
    49	| `chat_respond.respond` | `lua/parley/chat_respond.lua` | modified | exchange model, chat lease, stream/tool continuations |
    50	| `skill_invoke.invoke` / `skill_invoke.cancel` | `lua/parley/skill_invoke.lua` | modified | headless skill process and terminal ownership |
    51	| `define_visual` | `lua/parley/init.lua` | modified | visual selection and durable footnote rendering |
    52	| `fake_sse_server` | `tests/fixtures/fake_sse_server` | new | real local HTTP/SSE process used by curl |
    53
    54	- **`chat_pending.start`** — creates one registered per-buffer session, anchors a dedicated `virt_lines` extmark below the durable response header, owns reveal/minimum/animation/verb timers, feeds every callback through the pure reducer, and executes emitted actions in order.
    55	  - **Injected into:** `chat_respond.respond` supplies `lease_valid`, the real content emitter, and the existing completion/failure continuations.
    56	  - **Future extensions:** A different chat progress renderer can consume the same reducer actions.
    57	- **`selection_spinner.start`** — initializes `tick=1` and renders `" " .. progress.frame(tick)` (`⠙`) at the selection's exclusive end, then advances through the canonical sequence and returns an idempotent stop function.
    58	  - **Injected into:** `define_visual`; it reuses `progress.SPINNER` but has no dependency on the detached luabar session (`ARCH-DRY`).
    59	  - **Future extensions:** Other precisely anchored read-only skills can opt in explicitly.
    60	- **`tasker.run`** — drains stdout and stderr to EOF before reporting the process terminal, regardless of whether pipe EOF or process exit arrives first.
    61	  - **Injected into:** `dispatcher.query` receives a callback only after its stdout reader has consumed the final fragment; existing four-argument callbacks remain compatible.
    62	  - **Future extensions:** The optional fifth `io_error` result can classify pipe failures for other subprocess consumers.
    63	- **`vault.run_with_secret`** — appends an optional error callback that reports
    64	  missing secrets and every resolver terminal that cannot produce a usable
    65	  secret; `tasker.run` likewise appends a launch-error callback for busy/spawn
    66	  rejection.
    67	  - **Injected into:** Dispatcher folds both sources into its once-guarded
    68	    qid-free `on_abort(msg)` path; existing vault/task callers omit the new
    69	    arguments and retain their current behavior.
    70	  - **Future extensions:** Other interactive callers may opt into explicit
    71	    launch-failure teardown without changing legacy fire-and-forget callers.
    72	- **`dispatcher.query`** — invokes raw activity once per blank-line-delimited SSE event record (including a final EOF-terminated record), preserves semantic `on_progress`, captures curl's final HTTP status outside the provider stream, and chooses exactly one normal or provider-error terminal after drain-safe `tasker.run` completion.
    73	  - **Injected into:** Chat and Definition's `skill_invoke` path use the new error callback. Existing callers that omit it receive the historical `on_exit(qid)` fallback and retain teardown behavior.
    74	  - **Future extensions:** Provider HTTP-status classification can widen the typed failure record without overloading pre-query `on_abort`.
    75	- **`chat_respond.respond`** — removes the web-search-only buffer/model spinner, starts one presentation session for every initial/recursive leg, and defers tool-loop execution behind a visible minimum when required.
    76	  - **Injected into:** The session receives the existing lease and `create_handler` seams; it never computes transcript positions itself.
    77	  - **Future extensions:** None planned; background topic generation stays deliberately separate.
    78	- **`skill_invoke.invoke` / `skill_invoke.cancel`** — centralizes one idempotent terminal path, with `opts.detached_progress` defaulting true and `opts.on_terminal` running before `opts.on_done` on every terminal path.
    79	  - **Injected into:** Definition passes `detached_progress=false`; Review, Voice Apply, and generic callers rely on defaults.
    80	  - **Future extensions:** Other callers can own contextual progress without changing cancellation semantics.
    81	- **`define_visual`** — starts the inline spinner only after validating a non-empty selection, passes its stop function as terminal cleanup, and performs the existing footnote flow only after cleanup.
    82	  - **Injected into:** `selection_spinner.start` and the generalized `skill_invoke` lifecycle.
    83	  - **Future extensions:** None; the spinner has no one-second delay by design.
    84	- **`fake_sse_server`** — speaks actual HTTP/SSE to curl with deterministic fast, delayed, activity-only-then-visible, partial-then-fail, and tool-use-only modes.
    85	  - **Injected into:** A process integration spec points a test provider endpoint at the local server; callback-only tests remain for exhaustive race permutations.
    86	  - **Future extensions:** Additional transport edge fixtures can become modes instead of new fake processes.
    87
    88	## Chunk 1: Presentation controller, adapters, and integrations
    89
    90	### Task 1: Build the pure chat presentation reducer
    91
    92	**Files:**
   100	  current luabar behavior by default.
   101	- On a valid definition result, remove the virtual spinner immediately and run
   102	  the existing durable footnote flow, producing `CVR[^cvr]` and its managed
   103	  definition. There is no one-second delay or minimum-visible duration for
   104	  definition.
   105	- On failure, missing structured output, a stale selection, cancellation, or
   106	  buffer deletion, remove the virtual spinner without adding a footnote.
   107
   108	### Design boundaries
   109
   110	- Use a small pure response-presentation controller for chat timing, state
   111	  transitions, buffering decisions, and verb selection. Inject time and random
   112	  choice so its behavior is deterministic under unit test (`ARCH-PURE`).
   113	- Keep Neovim timers, extmarks, dispatcher callbacks, exchange-model access,
   114	  and stream writes in thin adapters. The exchange model remains the sole owner
   115	  of real chat positions; cosmetic virtual text is anchored to its durable
   116	  response header rather than modeled as content.
   117	- Reuse the existing canonical spinner frames. Keep the detached luabar,
   118	  chat-pending virtual line, and selection-anchored definition spinner as
   119	  separate renderers because they have different locations and lifecycle
   120	  policies (`ARCH-DRY`, `ARCH-PURPOSE`).
   121	- Expose raw SSE activity separately from semantic provider progress so playful
   122	  verb changes do not alter existing progress-event contracts.
   123	- Give callers an additive post-start provider-error callback. Callers that do
   124	  not opt in receive every historical completion surface they supplied—both
   125	  `on_exit(qid)` and the assembled-response callback, when present—exactly once
   126	  after transport drain, so topic generation, memory preferences, and other
   127	  existing consumers cannot strand teardown.
   128	- Preserve each HTTP response body while classifying its final status outside
   129	  the SSE stream. Curl writes a qid-specific status trailer to stderr, leaving
   130	  response stdout byte-for-byte untouched. The trailer is transport metadata:
   131	  it is not an SSE event, visible content, raw provider response, or playful
   132	  activity.
   133	- Route failures before a transport starts through the existing pre-start abort
   134	  class exactly once. Missing/unresolved vault secrets, a busy subprocess slot,
   135	  and process-spawn rejection must all notify the chat/skill caller so it can
   136	  remove pending extmarks and timers rather than waiting forever.
   137	- Model provider failure, cancellation/invalidation, successful completion, and
   138	  deferred local-tool transition as distinct terminal actions; do not collapse
   139	  them into a single cleanup callback that loses real buffered output.
   140
   141	## Done when
   142
   143	- Fast chat output streams normally without ever showing playful progress.
   144	- A chat call silent for one second shows an ephemeral animated playful line;
   145	  once shown, it remains at least one second, stages incoming output, flushes it
   146	  exactly once in order, and resumes streaming without transcript drift.
   147	- SSE activity and a 15-second idle interval independently rotate the playful
   148	  verb without coupling verb changes to spinner-frame animation.
   149	- Every chat-producing LLM leg is covered, while topic generation and local
   150	  tool execution do not show the playful line.
   151	- Terminal, cancellation, stale-lease, and invalid-buffer paths clean up all
   152	  timers, extmarks, and buffered state. Provider failures bypass the minimum
   153	  and preserve valid partial output; cancellation or lost ownership discards it.
   154	- Definition shows an immediate selection-anchored virtual spinner, never uses
   155	  the luabar, and replaces the spinner with the existing durable footnote on
   156	  success; all non-success paths remove it without a footnote.
   157	- Document Review continues to use the detached luabar.
   158	- Pure timing/state tests, real-entry-point chat and definition integration
   159	  tests, atlas updates, and the full `make test` suite pass.
   160
   161	## Estimate
   162
   163	```estimate
   164	model: estimate-logic-v3.1
   165	familiarity: 1.0

exec
/bin/zsh -lc "rg -n 'D\\.create_handler|create_handler = function' lua/parley/dispatcher.lua && nl -ba lua/parley/dispatcher.lua | sed -n '475,650p'
rg -n 'staged.*progress|progress.*staged|callback order|FIFO|render_status' tests/integration/chat_respond_spec.lua tests/integration/chat_pending_spec.lua tests/unit/chat_presentation_spec.lua" in /Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat
 succeeded in 0ms:
478:D.create_handler = function(buf, win, line, first_undojoin, prefix, cursor, on_lines_changed, opts)
   475	---@param first_undojoin boolean | nil # whether to skip first undojoin
   476	---@param prefix string | nil # prefix to insert before each response line
   477	---@param cursor boolean | function # whether to move cursor to the end of the response
   478	D.create_handler = function(buf, win, line, first_undojoin, prefix, cursor, on_lines_changed, opts)
   479		buf = buf or vim.api.nvim_get_current_buf()
   480		opts = opts or {}
   481		prefix = prefix or ""
   482		local first_line = line or vim.api.nvim_win_get_cursor(win or 0)[1] - 1
   483		local finished_lines = 0
   484		local skip_first_undojoin = not first_undojoin
   485
   486		local hl_handler_group = "ParleyHandlerStandout"
   487		vim.cmd("highlight default link " .. hl_handler_group .. " CursorLine")
   488
   489		local ns_id = vim.api.nvim_create_namespace("ParleyHandler_" .. helpers.uuid())
   490
   491		local ex_id = vim.api.nvim_buf_set_extmark(buf, ns_id, first_line, 0, {
   492			strict = false,
   493			right_gravity = false,
   494		})
   495
   496		local has_started = false
   497		local pending_line = ""
   498
   499		local function with_prefix(lines)
   500			if prefix == "" then
   501				return lines
   502			end
   503			local prefixed = {}
   504			for i, l in ipairs(lines) do
   505				prefixed[i] = prefix .. l
   506			end
   507			return prefixed
   508		end
   509
   510		local function split_pending_and_completed(text)
   511			local lines = vim.split(text, "\n")
   512			local completed = {}
   513			for i = 1, #lines - 1 do
   514				completed[i] = lines[i]
   515			end
   516			local pending = lines[#lines] or ""
   517			return completed, pending
   518		end
   519
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
   578			if opts.after_write then
   579				opts.after_write(qid, chunk, delta)
   580			end
   581			pending_line = new_pending
   582			helpers.undojoin(buf)
   583
   584			for i = previous_pending_index, finished_lines do
   585				vim.api.nvim_buf_add_highlight(buf, qt.ns_id, hl_handler_group, first_line + i, 0, -1)
   586			end
   587
   588			local end_line = first_line + finished_lines + 1
   589			qt.first_line = first_line
   590			qt.last_line = end_line - 1
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
   602		end)
   603	end
   604
   605	return D
tests/integration/chat_pending_spec.lua:242:    it("stages content until the minimum and flushes it in FIFO order", function()
tests/unit/chat_presentation_spec.lua:60:        assert.are.same({ { type = "render_status", message = "Reasoning: checking" } }, actions)
tests/unit/chat_presentation_spec.lua:63:    it("reveals playful status and stages visible events in callback order", function()
tests/unit/chat_presentation_spec.lua:72:        local staged, progress_actions = transition(with_content, {
tests/unit/chat_presentation_spec.lua:83:        assert.are.equal("progress", staged.staged_tail.event.type)
tests/unit/chat_presentation_spec.lua:116:            { type = "render_status", message = "Reasoning: two" },
tests/unit/chat_presentation_spec.lua:400:    it("same-deadline callback order decides reveal versus direct release exactly once", function()
tests/unit/chat_presentation_spec.lua:422:    it("same-deadline callback order flushes once", function()

exec
/bin/zsh -lc 'set -o pipefail
for f in tests/unit/chat_presentation_spec.lua tests/unit/dispatcher_query_spec.lua tests/unit/vault_spec.lua tests/integration/tasker_run_spec.lua tests/integration/skill_invoke_spec.lua tests/integration/define_spec.lua tests/integration/chat_respond_spec.lua; do
  echo "RUN $f"
  nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile $f" -c '"'qa"'!'"' > /tmp/parley-review-test.out 2>&1 || { tail -100 /tmp/parley-review-test.out; exit 1; }
  tail -6 /tmp/parley-review-test.out
done" in /Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat
 exited 1 in 1573ms:
[32mSuccess[0m	||	progress_message clears detail state when an event has no detail

[32mSuccess: [0m	41
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
RUN tests/unit/dispatcher_query_spec.lua
[32mSuccess: [0m	43
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
Parley.nvim: openai query failed: code=0 signal=0 http_status=500 io_error=none body_bytes=0 stderr_bytes=0
Parley.nvim: Failed to open file for writing: /Users/xianxu/.cache/nvim/parley/query/2026-07-13.03-32-11.784.ee1aa7.json
RUN tests/unit/vault_spec.lua
Parley.nvim: vault secret missing_key not found
Parley.nvim: vault secret missing not found
Parley.nvim: vault resolver for commandsecret command { "bad" } failed:
code: 1, signal: 0
stdout:
stderr: bad
RUN tests/integration/tasker_run_spec.lua

[32mSuccess: [0m	29
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
Parley.nvim: Error reading stderr: "stderr read_start failed: stderr start rejected"
RUN tests/integration/skill_invoke_spec.lua
Scheduling: tests/integration/skill_invoke_spec.lua

========================================
Testing:	/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/tests/integration/skill_invoke_spec.lua

[32mSuccess: [0m	0
[31mFailed : [0m	0
[31mErrors : [0m	2
========================================
We had an unexpected error:	{ {
    descriptions = { "skill_invoke.invoke" },
    msg = "vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for \"/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/DeCRdV/0-si/doc.md\", recovery impossible\n\nstack traceback:\n\tvim/_editor.lua: in function 'cmd'\n\t...t-in-parley-chat/tests/integration/skill_invoke_spec.lua:66: in function 'w'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:167: in function 'run_each'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:174: in function 'it'\n\t...t-in-parley-chat/tests/integration/skill_invoke_spec.lua:98: in function <...t-in-parley-chat/tests/integration/skill_invoke_spec.lua:55>\n"
  }, {
    descriptions = { "skill_invoke terminal ownership (#182)" },
    msg = "vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for \"/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/DeCRdV/1-skill-terminal/doc.md\", recovery impossible\n\nstack traceback:\n\tvim/_editor.lua: in function 'cmd'\n\t...t-in-parley-chat/tests/integration/skill_invoke_spec.lua:324: in function 'w'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:167: in function 'run_each'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:174: in function 'it'\n\t...t-in-parley-chat/tests/integration/skill_invoke_spec.lua:343: in function <...t-in-parley-chat/tests/integration/skill_invoke_spec.lua:301>\n"
  } }	{
  errs = { {
      descriptions = { "skill_invoke.invoke" },
      msg = "vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for \"/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/DeCRdV/0-si/doc.md\", recovery impossible\n\nstack traceback:\n\tvim/_editor.lua: in function 'cmd'\n\t...t-in-parley-chat/tests/integration/skill_invoke_spec.lua:66: in function 'w'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:167: in function 'run_each'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:174: in function 'it'\n\t...t-in-parley-chat/tests/integration/skill_invoke_spec.lua:98: in function <...t-in-parley-chat/tests/integration/skill_invoke_spec.lua:55>\n"
    }, {
      descriptions = { "skill_invoke terminal ownership (#182)" },
      msg = "vim/_editor.lua:0: command line..script nvim_exec2() called at command line:0, line 1: Vim(edit):E303: Unable to open swap file for \"/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim.xianxu/DeCRdV/1-skill-terminal/doc.md\", recovery impossible\n\nstack traceback:\n\tvim/_editor.lua: in function 'cmd'\n\t...t-in-parley-chat/tests/integration/skill_invoke_spec.lua:324: in function 'w'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:167: in function 'run_each'\n\t...ocal/share/nvim/lazy/plenary.nvim/lua/plenary/busted.lua:174: in function 'it'\n\t...t-in-parley-chat/tests/integration/skill_invoke_spec.lua:343: in function <...t-in-parley-chat/tests/integration/skill_invoke_spec.lua:301>\n"
    } },
  fail = {},
  pass = {}
}

exec
/bin/zsh -lc "rg -n 'providers\\.get =|P\\.get =|function .*get\\(' lua/parley/providers.lua && sed -n '1,140p' lua/parley/providers.lua
rg -n 'function .*encode_tools|_encode_tools' lua/parley/providers.lua | head -50
nl -ba lua/parley/skill_invoke.lua | sed -n '138,232p'
nl -ba tests/integration/skill_invoke_spec.lua | sed -n '430,510p'" in /Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat
 succeeded in 0ms:
748:-- works like `providers.anthropic_encode_tools`. The tool_loop driver
1323:function M.anthropic_encode_tools(tool_definitions)
1337:function M.openai_encode_tools(_tool_definitions)
1343:function M.googleai_encode_tools(_tool_definitions)
1349:function M.ollama_encode_tools(_tool_definitions)
1359:function M.cliproxyapi_encode_tools(tool_definitions, model_name)
1364:    return M.anthropic_encode_tools(tool_definitions)
   138	    -- This exchange's generation; on_exit/on_abort no-op if superseded (#133).
   139	    local gen = (_gen[buf] or 0) + 1
   140	    _gen[buf] = gen
   141	    local finished = false
   142	    local detached_progress = opts.detached_progress ~= false
   143	    local progress_started = false
   144	    local function finish(result, deliver_done)
   145	        if finished then return false end
   146	        finished = true
   147	        if progress_started then
   148	            pcall(function() require("parley.progress").stop() end)
   149	            progress_started = false
   150	        end
   151	        if _terminals[buf] == finish then
   152	            _terminals[buf] = nil
   153	            _in_flight[buf] = nil
   154	        end
   155	        deliver_attempt(result, deliver_done)
   156	        return true
   157	    end
   158	    _terminals[buf] = finish
   159
   160	    if not vim.api.nvim_buf_is_valid(buf) then
   161	        finish({ ok = false, msg = "buffer invalid" }, false)
   162	        return
   163	    end
   164	    local ok_path, artifact_path = pcall(vim.api.nvim_buf_get_name, buf)
   165	    if not ok_path or artifact_path == "" then
   166	        p.logger.warning("skill " .. tostring(manifest.name) .. ": buffer has no file — open the artifact first")
   167	        finish({ ok = false, msg = "buffer has no file" }, true)
   168	        return
   169	    end
   170
   171	    -- Sync file == buffer so edits compute + apply against the same content.
   172	    -- A read-only skill (opts.no_reload — e.g. define, #161) makes no edits, so
   173	    -- it must NOT persist the user's in-progress buffer to disk.
   174	    if vim.bo[buf].modified and not opts.no_reload then
   175	        vim.api.nvim_buf_call(buf, function()
   176	            pcall(vim.cmd, "silent write")
   177	        end)
   178	    end
   179
   180	    local original = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
   181	    -- source(ctx) does IO (reads SKILL.md / style guides) and can fail — e.g.
   182	    -- voice_apply with a missing style file. Route the failure through the SAME
   183	    -- on_done({ok=false}) channel as the other early-outs (no file / no agent)
   184	    -- rather than throwing a raw Lua error; skill_invoke is the generic P2 driver.
   185	    local ok_src, body = pcall(manifest.source, { args = args or {}, repo_root = p.config.repo_root })
   186	    if not ok_src then
   187	        p.logger.error("skill " .. tostring(manifest.name) .. ": source failed: " .. tostring(body))
   188	        finish({ ok = false, msg = "source failed: " .. tostring(body) }, true)
   189	        return
   190	    end
   191	    -- opts.document lets a caller send a bounded context (e.g. define's enclosing
   192	    -- exchange) instead of the whole buffer; defaults to the buffer content.
   193	    local inv = assembly.build_invocation(manifest, { body = body, document = opts.document or original, manual = manual })
   194
   195	    local agent = assembly.resolve_agent(manifest, {
   196	        config = p.config,
   197	        get_agent = p.get_agent,
   198	        agent_names = p._agents,
   199	        agents = p.agents,
   200	    })
   201	    if not agent then
   202	        p.logger.warning("skill " .. tostring(manifest.name) .. ": no tool-capable agent resolved")
   203	        finish({ ok = false, msg = "no agent" }, true)
   204	        return
   205	    end
   206
   207	    local payload = llm.prepare_payload(inv.messages, agent.model, agent.provider, inv.tools)
   208	    if inv.tool_choice then
   209	        payload.tool_choice = inv.tool_choice
   210	    end
   211	    -- Large-document tool output needs headroom: a multi-edit propose_edits batch
   212	    -- echoes old/new/explain per edit and easily exceeds the default (4096),
   213	    -- truncating the tool JSON → empty decode. (Was skill_runner's explicit bump.)
   214	    payload.max_tokens = math.max(payload.max_tokens or 0, 100000)
   215
   216	    skill_render.clear_decorations(buf)
   217
   218	    local neighborhood = require("parley.neighborhood")
   219	    local root_policy = neighborhood.policy_for_buf(buf)
   220	        or neighborhood.policy_from_roots(vim.fn.fnamemodify(artifact_path, ":h"), nil, {})
   221	    local cwd = root_policy.write_root
   222
   223	    _in_flight[buf] = true
   224	    -- Detached progress bar: this is a ~30s headless op, so show a running cue
   225	    -- (the first substantive-progress surface, #133 M7). Stopped on exit/abort.
   226	    if detached_progress then
   227	        progress_started = require("parley.progress").start(
   228	            "Parley " .. tostring(manifest.name) .. " running…")
   229	    end
   230	    local ok_query = pcall(llm.query,
   231	        nil, -- headless: no streaming buffer insertion
   232	        agent.provider,
   430	                end,
   431	                manifest = terminal_manifest(),
   432	                message = "buffer has no file",
   433	            },
   434	            {
   435	                name = "source failure",
   436	                setup = function() end,
   437	                manifest = terminal_manifest({ source = function() error("boom") end }),
   438	                message = "source failed",
   439	            },
   440	            {
   441	                name = "no agent",
   442	                setup = function() assembly.resolve_agent = function() return nil end end,
   443	                manifest = terminal_manifest(),
   444	                message = "no agent",
   445	            },
   446	        }
   447	        for _, case in ipairs(cases) do
   448	            if case.name ~= "no file" then
   449	                vim.cmd("edit! " .. vim.fn.fnameescape(path))
   450	                buf = vim.api.nvim_get_current_buf()
   451	            end
   452	            case.setup()
   453	            local events = {}
   454	            skill_invoke.invoke(buf, case.manifest, {}, {
   455	                detached_progress = false,
   456	                on_terminal = function(result) table.insert(events, "terminal:" .. result.msg) end,
   457	                on_done = function() table.insert(events, "done") end,
   458	            })
   459	            assert.are.equal(2, #events, case.name)
   460	            assert.is_truthy(events[1]:find(case.message, 1, true), case.name)
   461	            assert.are.equal("done", events[2], case.name)
   462	            assert.is_false(skill_invoke.is_in_flight(buf), case.name)
   463	        end
   464	    end)
   465
   466	    it("rejects a second invocation through its own ordered terminal", function()
   467	        parley.dispatcher.query = function() end
   468	        skill_invoke.invoke(buf, terminal_manifest(), {}, { detached_progress = false })
   469	        local events = {}
   470	        skill_invoke.invoke(buf, terminal_manifest(), {}, {
   471	            detached_progress = false,
   472	            on_terminal = function(result) table.insert(events, "terminal:" .. result.msg) end,
   473	            on_done = function() table.insert(events, "done") end,
   474	        })
   475	        assert.are.same({ "terminal:already running", "done" }, events)
   476	        assert.is_true(skill_invoke.is_in_flight(buf), "the first invocation must remain owned")
   477	        skill_invoke.cancel(buf)
   478	    end)
   479
   480	    it("finishes a malformed scheduled completion and contains terminal callback failure", function()
   481	        parley.dispatcher.query = function(_b, _p, _payload, _handler, on_exit)
   482	            tasker.set_query("malformed", {
   483	                raw_response = sse({
   484	                    { type = "content_block_start", index = 0,
   485	                      content_block = { type = "tool_use", id = "bad", input = {} } },
   486	                    { type = "content_block_stop", index = 0 },
   487	                    { type = "message_stop" },
   488	                }),
   489	            })
   490	            vim.schedule(function() on_exit("malformed") end)
   491	        end
   492	        local done, terminal_calls = nil, 0
   493	        skill_invoke.invoke(buf, terminal_manifest(), {}, {
   494	            on_terminal = function()
   495	                terminal_calls = terminal_calls + 1
   496	                error("caller failure must be contained")
   497	            end,
   498	            on_done = function(result) done = result end,
   499	        })
   500	        assert.is_true(vim.wait(1000, function() return done ~= nil end, 10),
   501	            "malformed completion leaked its terminal")
   502	        assert.are.equal(1, terminal_calls)
   503	        assert.is_false(done.ok)
   504	        assert.are.equal("completion failed", done.msg)
   505	        assert.is_false(skill_invoke.is_in_flight(buf))
   506	        assert.is_false(require("parley.progress").is_active())
   507	    end)
   508	end)

exec
/bin/zsh -lc "sed -n '1280,1375p' lua/parley/providers.lua
rg -n 'function M\\.get|M\\.get\\s*=' lua/parley/providers.lua" in /Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat
 succeeded in 0ms:
    end
    return get_cliproxy_strategy(model_config)
end

--- Get cache metrics display config for a provider.
---@param name string provider name
---@return table {read = bool, creation = bool}
M.get_cache_metrics_config = function(name)
    local adapter = M.get(name)
    return adapter.cache_metrics or { read = false, creation = false }
end

--- Get the secret name for a provider (usually the provider name itself).
---@param name string provider name
---@return string secret name
M.get_secret_name = function(name)
    local adapter = M.get(name)
    return adapter.secret_name or name
end

--------------------------------------------------------------------------------
-- Tool-use encoders (issue #81 M1)
--
-- These are pure table-transformation helpers that convert parley's
-- provider-agnostic internal ToolDefinition shape into the wire format
-- each provider expects in its `tools` request field. Only Anthropic
-- is implemented in v1; OpenAI / Google / Ollama stubs raise a clear
-- "not yet implemented" error so tool-enabled agents fail fast.
--
-- Convention: the dispatcher's prepare_payload APPENDS the result of
-- these encoders onto any existing `payload.tools` (e.g. server-side
-- web_search / web_fetch already populated by existing code paths).
-- See dispatcher.lua for the append logic.
--------------------------------------------------------------------------------

--- Convert a list of parley ToolDefinitions into the Anthropic payload
--- shape for the `tools` array. Each entry contains only the fields
--- Anthropic cares about: name, description, input_schema. Internal
--- fields (handler, kind, needs_backup) are intentionally dropped.
---
--- Pure. Accepts nil or empty list and returns an empty table.
---@param tool_definitions ToolDefinition[]|nil
---@return table[] anthropic_tools
function M.anthropic_encode_tools(tool_definitions)
    local out = {}
    for _, def in ipairs(tool_definitions or {}) do
        table.insert(out, {
            name = def.name,
            description = def.description,
            input_schema = def.input_schema,
        })
    end
    return out
end

--- OpenAI tool encoder — stub that raises. Deferred to a #81 follow-up.
---@diagnostic disable-next-line: unused-local
function M.openai_encode_tools(_tool_definitions)
    error("tools not supported for this provider yet — see #81 follow-up")
end

--- Google AI tool encoder — stub that raises. Deferred to a #81 follow-up.
---@diagnostic disable-next-line: unused-local
function M.googleai_encode_tools(_tool_definitions)
    error("tools not supported for this provider yet — see #81 follow-up")
end

--- Ollama tool encoder — stub that raises. Deferred to a #81 follow-up.
---@diagnostic disable-next-line: unused-local
function M.ollama_encode_tools(_tool_definitions)
    error("tools not supported for this provider yet — see #81 follow-up")
end

--- CLIProxyAPI tool encoder — delegates to the Anthropic encoder only
--- when the target model name begins with "claude-" (i.e. routed to
--- an Anthropic-family model). Otherwise raises with an
--- anthropic-family-only message so the error is specific and actionable.
---@param tool_definitions ToolDefinition[]
---@param model_name string|table the model name (or table containing .model)
function M.cliproxyapi_encode_tools(tool_definitions, model_name)
    local name = type(model_name) == "table" and model_name.model or model_name
    if type(name) ~= "string" or not name:match("^claude%-") then
        error("tools not supported for this provider yet — cliproxyapi requires an anthropic-family model (see #81 follow-up)")
    end
    return M.anthropic_encode_tools(tool_definitions)
end

return M
1231:M.get = function(name)

exec
/bin/zsh -lc 'make -f Makefile.parley test-spec SPEC=chat/inline_define' in /Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat
 succeeded in 13041ms:
Memory prefs: scanning chat history...
Memory prefs: no summaries found in chat history
Memory prefs: generating topic: topicA (1/2)
Error detected while processing command line:
Parley.nvim: query abort before start [cliproxyapi]: cliproxy: process exited (code 1) right after spawn — check the binary/config
Parley.nvim: memory_prefs: tag [topicA] aborted: cliproxy: process exited (code 1) right after spawn — check the binary/config
Memory prefs: generating topic: topicB (2/2)
Parley.nvim: query abort before start [cliproxyapi]: cliproxy: process exited (code 1) right after spawn — check the binary/config
[32mSuccess[0m	||	cliproxy on_abort teardown per caller memory_prefs advances the batch past aborted tags
Parley.nvim: memory_prefs: tag [topicB] aborted: cliproxy: process exited (code 1) right after spawn — check the binary/config
Memory prefs: generating topic: topicA (1/2)
Parley.nvim: anthropic response is empty: body_bytes=0
Parley.nvim: anthropic query failed: code=7 signal=0 http_status=0 io_error=none body_bytes=0 stderr_bytes=0
Parley.nvim: memory_prefs: empty response for tag [topicA]
Memory prefs: generating topic: topicB (2/2)
Parley.nvim: anthropic response is empty: body_bytes=0
Parley.nvim: anthropic query failed: code=7 signal=0 http_status=0 io_error=none body_bytes=0 stderr_bytes=0
[32mSuccess[0m	||	cliproxy on_abort teardown per caller memory_prefs advances every tag after drained transport failures
[32mSuccess[0m	||	cliproxy on_abort teardown per caller chat_respond on_abort collapses the inserted empty answer block
[32mSuccess[0m	||	cliproxy on_abort teardown per caller skill_invoke on_abort clears the _in_flight guard
Parley.nvim: memory_prefs: empty response for tag [topicB]Parley.nvim: skill testskill abort: test abort
[32mSuccess[0m	||	cliproxy on_abort teardown per caller skill_invoke transport terminal uses argument 10 exactly once

[32mSuccess: [0m	5
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
Parley.nvim: skill testskill transport error
Running tests/integration/define_spec.lua
Scheduling: tests/integration/define_spec.lua

========================================
Testing:	/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/tests/integration/define_spec.lua
[32mSuccess[0m	||	emit_definition tool is registered and selectable without raising
[32mSuccess[0m	||	emit_definition tool does not advertise pager offset/limit params
[32mSuccess[0m	||	define skill is auto-discovered by the registry
[32mSuccess[0m	||	define skill folds the phrase into the system prompt and forces no tool
[32mSuccess[0m	||	define: skill_invoke read-only seams (#161) does not write or reload the buffer under opts.no_reload
[32mSuccess[0m	||	define: skill_invoke read-only seams (#161) sends opts.document as the user message, not the whole buffer
[32mSuccess[0m	||	define: web-toggle payload (#161) includes web_search in the anthropic payload iff the global toggle is on
[32mSuccess[0m	||	define_visual + render_definition (#161) stores the definition as a durable footnote, highlights the term/reference span, and shows the diagnostic
[32mSuccess[0m	||	define_visual + render_definition (#161) shows immediate inline canonical progress without mutating chat text or opening detached progress
[32mSuccess[0m	||	define_visual + render_definition (#161) removes inline progress on pre-query abort, transport failure, and explicit cancel
[32mSuccess[0m	||	define_visual + render_definition (#161) cleans inline progress through real dispatcher prestart failures
Error detected while processing command line:
Parley.nvim: skill define abort: missing secret
Parley.nvim: Define: no definition returned
Parley.nvim: skill define transport error
Parley.nvim: Define: no definition returned
Parley.nvim: vault secret anthropic not found
Parley.nvim: query abort before start [anthropic]: vault secret anthropic not found
Parley.nvim: skill define abort: vault secret anthropic not found
Parley.nvim: Define: no definition returned
Parley.nvim: query abort before start [anthropic]: busy
Parley.nvim: skill define abort: busy
Parley.nvim: Define: no definition returned
Parley.nvim: query abort before start [anthropic]: spawn rejected
Parley.nvim: skill define abort: spawn rejected
Parley.nvim: Define: no definition returned
[32mSuccess[0m	||	define_visual + render_definition (#161) removes progress and writes no footnote when the selection becomes stale
[32mSuccess[0m	||	define_visual + render_definition (#161) cleans immediate progress on real Definition source and agent failures
Parley.nvim: Define: selection changed during lookup — re-select to defineE211: File "/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/.test-tmp/nvim.xianxu/PeD1pB/8-dv/chat.md" no longer availableParley.nvim: skill define: source failed: ...on-text-in-parley-chat/tests/integration/define_spec.lua:404: source unavailable
Parley.nvim: Define: no definition returned
Parley.nvim: skill define: no tool-capable agent resolved
[32mSuccess[0m	||	define_visual + render_definition (#161) stops and closes the inline timer when the Definition buffer is deleted
Parley.nvim: Define: no definition returnedParley.nvim: skill define completion failed
[32mSuccess[0m	||	define_visual + render_definition (#161) cleans Definition progress when malformed tool output breaks completion
Parley.nvim: Define: no definition returnedMemory prefs: scanning chat history...
[32mSuccess[0m	||	define_visual + render_definition (#161) word-wraps long define diagnostics to the diagnostic display width
[32mSuccess[0m	||	define_visual + render_definition (#161) re-defining a footnoted term updates the footer without duplicating the inline reference
[32mSuccess[0m	||	define_visual + render_definition (#161) u undoes the footnote edit + clears decorations; C-r restores them (R1)
[32mSuccess[0m	||	define_visual + render_definition (#161) no-ops on a whitespace-only selection (no query, no diagnostic)
Memory prefs: no summaries found in chat historyParley.nvim: Define: empty selectionParley.nvim: skill define: model returned no tool call (response may be truncated)
[32mSuccess[0m	||	define_visual + render_definition (#161) no-ops on a no-tool-call response
[32mSuccess[0m	||	define keybinding split (#161) routes visual <M-CR> to define, keeps visual <C-g><C-g> as respond, n/i respond
[32mSuccess[0m	||	define keybinding split (#161) real prep_chat wiring: <M-CR>/<C-g><C-g> buffer-mapped in visual mode
[32mSuccess[0m	||	define: context_for_selection vs real parse_chat (#161) slices the enclosing exchange from real parse_chat output (field contract)

[32mSuccess: [0m	23
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
Parley.nvim: Define: no definition returned
Running tests/integration/skill_invoke_spec.lua
Scheduling: tests/integration/skill_invoke_spec.lua

========================================
Testing:	/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/tests/integration/skill_invoke_spec.lua
[32mSuccess[0m	||	skill_invoke.invoke drives one exchange: payload + force_tool, applies propose_edits, reloads, on_done
[32mSuccess[0m	||	skill_invoke.invoke coerces a stringified edits array and applies it (model quirk, #133)
Error detected while processing command line:
[32mSuccess[0m	||	skill_invoke.invoke surfaces a failed edit: on_done ok=false, applied=0, file untouched
[32mSuccess[0m	||	skill_invoke.invoke is_in_flight true during a query; cancel clears it + supersedes the exchange (#133)
[32mSuccess[0m	||	skill_invoke.invoke shows the progress bar during the query and stops it on completion (#133 M7)
[32mSuccess[0m	||	skill_invoke.invoke aborts (on_done ok=false) when no agent resolves
[32mSuccess[0m	||	skill_invoke.invoke aborts gracefully (on_done ok=false) when source() throws
Parley.nvim: skill t: old_string not unique: ab
Parley.nvim: skill t: no tool-capable agent resolved
[32mSuccess[0m	||	skill_invoke.invoke widens relative reads from ordinary nested repo Markdown
[32mSuccess[0m	||	skill_invoke.invoke executes relative tool paths from a super-repo sibling chat neighborhood
[32mSuccess[0m	||	skill_invoke terminal ownership (#182) suppresses detached progress only when explicitly requested
Parley.nvim: skill t: source failed: ...t-in-parley-chat/tests/integration/skill_invoke_spec.lua:221: style file not found
[32mSuccess[0m	||	skill_invoke terminal ownership (#182) owns each async terminal once and orders terminal before done
Parley.nvim: skill terminal-test: model returned no tool call (response may be truncated)
Parley.nvim: skill terminal-test abort: abort
[32mSuccess[0m	||	skill_invoke terminal ownership (#182) cancel delivers terminal cleanup once, skips done, and ignores late callbacks
Parley.nvim: skill terminal-test transport error
[32mSuccess[0m	||	skill_invoke terminal ownership (#182) finishes invalid scheduled completion without reading or delivering done
[32mSuccess[0m	||	skill_invoke terminal ownership (#182) delivers synchronous terminal failures once before done
[32mSuccess[0m	||	skill_invoke terminal ownership (#182) rejects a second invocation through its own ordered terminal
E211: File "/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/.test-tmp/nvim.xianxu/H62GY3/11-skill-terminal/doc.md" no longer availableParley.nvim: skill terminal-test: buffer has no file — open the artifact first
Parley.nvim: skill terminal-test: source failed: ...t-in-parley-chat/tests/integration/skill_invoke_spec.lua:437: boom
Parley.nvim: skill terminal-test: no tool-capable agent resolved
Parley.nvim: skill terminal-test: already running on this buffer
Parley.nvim: skill terminal-test completion failed
[32mSuccess[0m	||	skill_invoke terminal ownership (#182) finishes a malformed scheduled completion and contains terminal callback failure

[32mSuccess: [0m	16
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
Parley.nvim: skill terminal callback failed
Running tests/unit/define_spec.lua
Scheduling: tests/unit/define_spec.lua

========================================
Testing:	/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/tests/unit/define_spec.lua
[32mSuccess[0m	||	define.slice_selection extracts a single-line span
[32mSuccess[0m	||	define.slice_selection extracts a multi-line span joined with newline
[32mSuccess[0m	||	define.slice_selection clamps an end column past line length
[32mSuccess[0m	||	define.slice_selection returns empty string for a reversed/empty span
[32mSuccess[0m	||	define.context_for_selection returns the enclosing exchange's lines (question..answer)
[32mSuccess[0m	||	define.context_for_selection handles an answerless exchange (question only)
[32mSuccess[0m	||	define.context_for_selection falls back to the whole buffer when outside any exchange
[32mSuccess[0m	||	define.format_definition composes 'TERM — definition'
[32mSuccess[0m	||	define.format_definition hard-wraps to width
[32mSuccess[0m	||	define.format_definition passes nil width through to the shared diagnostic formatter
[32mSuccess[0m	||	define.format_definition trims a nil/blank definition to a safe string
[32mSuccess[0m	||	define.bracket_edit wraps a single-line span into a set_lines edit
[32mSuccess[0m	||	define.bracket_edit clamps end col past line length
[32mSuccess[0m	||	define.bracket_edit wraps a multi-line span
[32mSuccess[0m	||	define.diagnostic_span_after_bracket anchors a single-line selection on the selected text after brackets
[32mSuccess[0m	||	define.diagnostic_span_after_bracket anchors a multi-line selection without shifting the final line
[32mSuccess[0m	||	define durable footnotes slugifies a definition term into a markdown footnote id
[32mSuccess[0m	||	define durable footnotes adds an inline footnote reference and appends a managed footer
[32mSuccess[0m	||	define durable footnotes updates an existing managed footnote instead of duplicating it
[32mSuccess[0m	||	define durable footnotes updates an existing inline reference without duplicating it
[32mSuccess[0m	||	define durable footnotes strips only a final managed footnote footer
[32mSuccess[0m	||	define durable footnotes preserves ordinary horizontal rules that are not managed footnote footers
[32mSuccess[0m	||	define durable footnotes reports a dividerless managed footnote footer range from the first definition
[32mSuccess[0m	||	define durable footnotes reports a divider-based managed footnote footer range from the first definition
[32mSuccess[0m	||	define durable footnotes reports the content trim start at an optional legacy divider
[32mSuccess[0m	||	define durable footnotes reports the content trim start at the first definition without a divider
[32mSuccess[0m	||	define durable footnotes does not report ordinary horizontal rules as managed footnote footers
[32mSuccess[0m	||	define durable footnotes keeps earlier horizontal-rule content and strips only the final managed footer
[32mSuccess[0m	||	define durable footnotes strips a final dividerless managed footnote footer
[32mSuccess[0m	||	define durable footnotes extracts persisted footnote diagnostics from the managed footer
[32mSuccess[0m	||	define durable footnotes uses a leading quoted footnote term to span a multi-word persisted anchor
[32mSuccess[0m	||	define durable footnotes uses a leading backquoted footnote term to span a multi-word persisted anchor
[32mSuccess[0m	||	define durable footnotes matches a structured term already enclosed in body quotes
[32mSuccess[0m	||	define durable footnotes falls back to contiguous-token anchors when the structured term is not before the reference
[32mSuccess[0m	||	define durable footnotes uses the footnote id slug to recover an unstructured multi-word anchor
[32mSuccess[0m	||	define durable footnotes matches slug-derived anchors case-insensitively while preserving typed body text
[32mSuccess[0m	||	define durable footnotes falls back to contiguous-token anchors when a hyphenated slug phrase is absent
[32mSuccess[0m	||	define durable footnotes extracts every inline reference to a managed footnote
[32mSuccess[0m	||	define durable footnotes treats the first footnote definition as the footer even with trailing text

[32mSuccess: [0m	39
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================

codex
Focused lint and deterministic suites are green, including the pure reducer, dispatcher/vault/tasker lifecycle tests, and the mapped Definition/skill suites. The real loopback curl fixture cannot bind a localhost socket in this review sandbox, so its four process cases are unverified here; the failures occur at server bind, not in Parley logic. I’ve also confirmed one substantive terminal-ownership hole outside the covered matrix.
exec
/bin/zsh -lc 'git diff --check 27a778b7876adfdf3816b8c701e2b355252c357b..HEAD
make -f Makefile.parley test-spec SPEC=chat/lifecycle' in /Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat
 succeeded in 16699ms:
Running tests/integration/chat_lease_spec.lua
Scheduling: tests/integration/chat_lease_spec.lua

========================================
Testing:	/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/tests/integration/chat_lease_spec.lua
[32mSuccess[0m	||	chat_lease (extmark-anchored, #138) validates while the anchor line exists
[32mSuccess[0m	||	chat_lease (extmark-anchored, #138) stays valid across in-place edits to the anchor line (streaming in)
[32mSuccess[0m	||	chat_lease (extmark-anchored, #138) stays valid when unrelated lines above change (anchor rides the edit)
[32mSuccess[0m	||	chat_lease (extmark-anchored, #138) invalidates when the anchor line is deleted (structural break)
[32mSuccess[0m	||	chat_lease (extmark-anchored, #138) rejects stale generations
[32mSuccess[0m	||	chat_lease (extmark-anchored, #138) invalidate() marks the active lease invalid with a reason
[32mSuccess[0m	||	chat_lease (extmark-anchored, #138) commit is a no-op that still reports the live generation
[32mSuccess[0m	||	chat_lease (extmark-anchored, #138) clears only the matching generation when provided

[32mSuccess: [0m	8
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
Running tests/integration/chat_move_spec.lua
Scheduling: tests/integration/chat_move_spec.lua

========================================
Testing:	/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/tests/integration/chat_move_spec.lua
[32mSuccess[0m	||	chat move moves the current chat to another registered chat directory
[32mSuccess[0m	||	chat move rejects moving chats to unregistered directories

[32mSuccess: [0m	2
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
Moved chat tree to: /Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/.test-tmp/nvim.xianxu/hFghtj/1-parley-chat-move-secondary/2026-03-11-move-test.mdParley.nvim: Failed to open file for writing: /Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/.test-tmp/nvim.xianxu/hFghtj/0-parley-chat-move-primary/state/state.json
Running tests/integration/chat_respond_spec.lua
Scheduling: tests/integration/chat_respond_spec.lua

========================================
Testing:	/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/tests/integration/chat_respond_spec.lua
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
Parley.nvim: chat transcript structure changed during pending requestParley.nvim: File "/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/.test-tmp/claude/not-a-chat-file.md" does not look like a chat file: "resolved file (/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/.test-tmp/claude/not-a-chat-file.md) not in configured chat roots (/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/.test-tmp/claude/parley-test-chat-respond-1783938812)"
[32mSuccess[0m	||	chat_respond: pending request transcript drift runs a tool-only completion immediately before playful reveal
[32mSuccess[0m	||	chat_respond: pending request transcript drift rejects force resubmit before mutating a chat that already owns a pending session
[32mSuccess[0m	||	chat_respond: pending request transcript drift hides a shown leg before its local tool and starts recursion with a fresh verb
Parley.nvim: File "/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/.test-tmp/claude/parley-test-chat-respond-1783938812/2026-03-01-test-1783938815-77915.md" does not look like a chat file: "missing header separator"Parley.nvim: A Parley response is already pending in this chat. Stop it before resubmitting.chat transcript structure changed during pending request
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
Parley.nvim: Completed resubmitting all questionsParley.nvim: File "/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/.test-tmp/claude/not-a-chat-all.md" does not look like a chat file: "resolved file (/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/.test-tmp/claude/not-a-chat-all.md) not in configured chat roots (/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/.test-tmp/claude/parley-test-chat-respond-1783938812)"
Parley.nvim: Drill-in: gathered 1 marker(s) into next turn
Parley.nvim: Drill-in branch: 1 marker(s) → new turn after exchange #1
Running tests/integration/create_handler_spec.lua
Scheduling: tests/integration/create_handler_spec.lua

========================================
Testing:	/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/tests/integration/create_handler_spec.lua
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

[32mSuccess: [0m	12
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
Running tests/integration/diagnostic_refresh_spec.lua
Scheduling: tests/integration/diagnostic_refresh_spec.lua

========================================
Testing:	/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/tests/integration/diagnostic_refresh_spec.lua
[32mSuccess[0m	||	diagnostic refresh lifecycle keeps diagnostics stale during TextChangedI
[32mSuccess[0m	||	diagnostic refresh lifecycle refreshes synchronously on InsertLeave
[32mSuccess[0m	||	diagnostic refresh lifecycle refreshes synchronously on TextChanged
[32mSuccess[0m	||	diagnostic refresh lifecycle refreshes synchronously on BufWritePost
[32mSuccess[0m	||	diagnostic refresh lifecycle hydrates on BufEnter
[32mSuccess[0m	||	diagnostic refresh lifecycle hydrates on WinEnter
[32mSuccess[0m	||	diagnostic refresh lifecycle footnote teardown preserves unrelated shared diagnostics
[32mSuccess[0m	||	diagnostic refresh lifecycle clears on BufUnload
[32mSuccess[0m	||	diagnostic refresh lifecycle clears on BufDelete

[32mSuccess: [0m	9
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
Running tests/integration/highlighting_spec.lua
Scheduling: tests/integration/highlighting_spec.lua

========================================
Testing:	/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/tests/integration/highlighting_spec.lua
[32mSuccess[0m	||	highlight_question_block: question lines applies Question highlight to 💬: line (row 0)
[32mSuccess[0m	||	highlight_question_block: question lines applies ParleyQuestion highlight to continuation lines of a question block
[32mSuccess[0m	||	highlight_question_block: question lines does NOT apply ParleyQuestion highlight to 🤖: answer lines
[32mSuccess[0m	||	highlight_question_block: thinking lines applies Think highlight to 📝: summary line
[32mSuccess[0m	||	highlight_question_block: thinking lines applies ParleyThinking highlight to 🧠: reasoning line
[32mSuccess[0m	||	highlight_question_block: file reference lines applies FileLoading highlight to @@ file reference lines in a question block
[32mSuccess[0m	||	highlight_question_block: file reference lines does NOT apply ParleyFileReference highlight to @@ lines outside question blocks
[32mSuccess[0m	||	highlight_question_block: managed footnote footer uses a dedicated footnote highlight instead of open-question coloring
[32mSuccess[0m	||	decoration provider cache BufUnload invalidates LineReader observer state before handle reuse
[32mSuccess[0m	||	decoration provider cache BufDelete invalidates LineReader observer state before handle reuse
[32mSuccess[0m	||	decoration provider cache keeps highlight caches isolated per window for the same buffer
[32mSuccess[0m	||	decoration provider cache attributes every provider read to decoration_redraw and performs no on_line read
[32mSuccess[0m	||	decoration provider cache computes a visible non-streaming reasoning opener with the shared phased reader
[32mSuccess[0m	||	decoration provider cache dims thinking-block continuation lines when viewport top falls between 🧠: and 🧠:[END]
[32mSuccess[0m	||	decoration provider cache dims streaming thinking-block continuation lines before 🧠:[END] is emitted
[32mSuccess[0m	||	decoration provider cache restores question highlights when redraw starts inside a long unanswered question
[32mSuccess[0m	||	decoration provider cache does identical bounded work for matched 1000 and 5000 line viewports
[32mSuccess[0m	||	decoration provider cache recomputes after scroll
[32mSuccess[0m	||	decoration provider cache marks structural edits dirty until lifecycle convergence rebuilds
[32mSuccess[0m	||	decoration provider cache keeps an unfinished reasoning paragraph busy only while streaming
[32mSuccess[0m	||	decoration provider cache keeps failed rebuilds unrenderable and retries transactionally
[32mSuccess[0m	||	decoration provider cache rejects an initial failed build and renders only after retry
[32mSuccess[0m	||	decoration provider cache sets up one shared build and attachment across reentry and windows
[32mSuccess[0m	||	decoration provider cache makes obsolete attached callbacks no-op after teardown
[32mSuccess[0m	||	decoration provider cache refreshes a normal completed API leg
[32mSuccess[0m	||	decoration provider cache converges after undo
1 change; before #2  0 seconds ago
1 change; before #2  0 seconds ago
[32mSuccess[0m	||	decoration provider cache converges after redo
[32mSuccess[0m	||	decoration provider cache converges after external edit
[32mSuccess[0m	||	decoration provider cache shares structure across a second window
[32mSuccess[0m	||	decoration provider cache clears on BufUnload
[32mSuccess[0m	||	decoration provider cache clears on BufDelete
[32mSuccess[0m	||	decoration provider cache retains one attachment and rebuild after teardown reentry
[32mSuccess[0m	||	decoration provider cache retains the prior real cache across lifecycle rebuild failure and swaps on retry
[32mSuccess[0m	||	timezone diagnostics publishes local-time diagnostics in its own namespace and clears stale diagnostics
[32mSuccess[0m	||	timezone diagnostics refreshes diagnostics for registered buffers on text changes
[32mSuccess[0m	||	markdown footnote diagnostics publishes persisted managed footnotes as Parley diagnostics
[32mSuccess[0m	||	markdown footnote diagnostics rehydrates the inline term/reference highlight for persisted footnotes
[32mSuccess[0m	||	markdown footnote diagnostics rehydrates a multi-word structured footnote anchor highlight
[32mSuccess[0m	||	markdown footnote diagnostics rehydrates an unstructured slug-derived multi-word footnote anchor highlight
[32mSuccess[0m	||	markdown footnote diagnostics refreshes footnote diagnostics on markdown text changes without clearing other Parley diagnostics
[32mSuccess[0m	||	markdown footnote diagnostics renders managed footnote footers with ParleyFootnote in markdown buffers
[32mSuccess[0m	||	markdown chat reference rendering refreshes 🌿: branch lines with the chat topic in markdown buffers
[32mSuccess[0m	||	markdown chat reference rendering does not rewrite 🌿: lines pointing to non-chat files in markdown buffers
[32mSuccess[0m	||	markdown chat reference rendering refreshes from the updated topic in an open unsaved chat buffer
[32mSuccess[0m	||	production first-entry convergence hydrates an unattached chat buffer before BufEnter returns
[32mSuccess[0m	||	production first-entry convergence hydrates an unattached markdown buffer before BufEnter returns
1 change; after #2  0 seconds agoMemory prefs: scanning chat history...
[32mSuccess[0m	||	production first-entry convergence keeps classification after an edit reuses an unloaded buffer handle

[32mSuccess: [0m	47
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
Memory prefs: no summaries found in chat history
Running tests/integration/new_chat_spec.lua
Scheduling: tests/integration/new_chat_spec.lua

========================================
Testing:	/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/tests/integration/new_chat_spec.lua
[32mSuccess[0m	||	ChatNew creates a .md file in chat_dir
[32mSuccess[0m	||	ChatNew created file has a timestamp-based name (YYYY-MM-DD format)
[32mSuccess[0m	||	ChatNew created file contains a 💬: user prefix line
[32mSuccess[0m	||	ChatNew created file contains a --- separator
[32mSuccess[0m	||	ChatNew created file starts with front matter and contains topic line
[32mSuccess[0m	||	ChatNew created file contains a file: front matter line
[32mSuccess[0m	||	ChatNew the new chat buffer passes not_chat validation
[32mSuccess[0m	||	ChatNew creates new chats only in the primary chat_dir when secondary roots are configured

[32mSuccess: [0m	8
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
Running tests/integration/not_chat_spec.lua
Scheduling: tests/integration/not_chat_spec.lua

========================================
Testing:	/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/tests/integration/not_chat_spec.lua
[32mSuccess[0m	||	not_chat: valid chat files returns nil for a properly formatted chat file in chat_dir
[32mSuccess[0m	||	not_chat: valid chat files returns nil for a properly formatted chat file in a secondary chat root
[32mSuccess[0m	||	not_chat: invalid files returns a reason string for a file outside chat_dir
[32mSuccess[0m	||	not_chat: invalid files returns a reason for a file in chat_dir without timestamp format
[32mSuccess[0m	||	not_chat: invalid files returns a reason for a file that is too short (< 5 lines)
[32mSuccess[0m	||	not_chat: invalid files returns a reason for a file missing the topic header
[32mSuccess[0m	||	not_chat: invalid files returns a reason for a file missing the file header

[32mSuccess: [0m	7
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
Running tests/integration/perf_chat_typing_spec.lua
Scheduling: tests/integration/perf_chat_typing_spec.lua

========================================
Testing:	/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/tests/integration/perf_chat_typing_spec.lua
[32mSuccess[0m	||	chat typing performance scenario builds the exact deterministic fixture shape
[32mSuccess[0m	||	chat typing performance scenario aggregates observer work component-wise and resets every sample
[32mSuccess[0m	||	chat typing performance scenario rejects invalid work samples before max aggregation
[32mSuccess[0m	||	chat typing performance scenario excludes warmups from measured sample indexes
[32mSuccess[0m	||	chat typing performance scenario uses fresh LineReader observer tokens and phase attribution
[32mSuccess[0m	||	chat typing performance scenario keeps capture logic out of the default timed observer
[32mSuccess[0m	||	chat typing performance scenario rejects missing observer conditions with useful timeout diagnostics
[32mSuccess[0m	||	chat typing performance scenario keeps inclusive and isolated JSON attribution explicit
[32mSuccess[0m	||	chat typing performance scenario creates arbitrary PERF_OUTPUT parents
[32mSuccess[0m	||	chat typing performance scenario enforces immutable full-read, scaling, and structure gates
[32mSuccess[0m	||	chat typing performance scenario asserts direct range bounds for the measured TextChangedI
[32mSuccess[0m	||	chat typing performance scenario uses real input and production attachment for an edit sample
[32mSuccess[0m	||	chat typing performance scenario terminates a failed async benchmark promptly with nonzero status

[32mSuccess: [0m	13
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
Running tests/integration/timer_race_spec.lua
Scheduling: tests/integration/timer_race_spec.lua

========================================
Testing:	/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/tests/integration/timer_race_spec.lua
[32mSuccess[0m	||	timer replacement race safety stale markdown topic callback does not double-close timer

[32mSuccess: [0m	1
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
Running tests/unit/buffer_lifecycle_spec.lua
Scheduling: tests/unit/buffer_lifecycle_spec.lua

========================================
Testing:	/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/tests/unit/buffer_lifecycle_spec.lua
[32mSuccess[0m	||	buffer lifecycle registers named convergence events once and never TextChangedI
[32mSuccess[0m	||	buffer lifecycle converges diagnostics then structure exactly once per event
[32mSuccess[0m	||	buffer lifecycle uses the same convergence entry for stream finalization
[32mSuccess[0m	||	buffer lifecycle tears down consumers independently and ignores later events
[32mSuccess[0m	||	buffer lifecycle propagates structure convergence failures after notifying
[32mSuccess[0m	||	buffer lifecycle rolls back initial ownership so setup can retry after convergence failure

[32mSuccess: [0m	6
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
Running tests/unit/chat_respond_footnote_spec.lua
Scheduling: tests/unit/chat_respond_footnote_spec.lua

========================================
Testing:	/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/tests/unit/chat_respond_footnote_spec.lua
[32mSuccess[0m	||	chat_respond managed footnote boundary uses define grammar for leading-whitespace footnote definitions

[32mSuccess: [0m	1
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
Running tests/unit/diagnostic_refresh_spec.lua
Scheduling: tests/unit/diagnostic_refresh_spec.lua

========================================
Testing:	/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/tests/unit/diagnostic_refresh_spec.lua
[32mSuccess[0m	||	diagnostic refresh refreshes timezone before footnotes synchronously
[32mSuccess[0m	||	diagnostic refresh does nothing for an invalid buffer
[32mSuccess[0m	||	diagnostic refresh clears timezone and only footnote-owned decorations

[32mSuccess: [0m	3
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
Running tests/unit/highlight_structure_spec.lua
Scheduling: tests/unit/highlight_structure_spec.lua

========================================
Testing:	/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/tests/unit/highlight_structure_spec.lua
[32mSuccess[0m	||	highlight_structure classifies canonical decoration grammar into compact fingerprints
[32mSuccess[0m	||	highlight_structure builds state, footer, and multiple half-open draft ranges
[32mSuccess[0m	||	highlight_structure overlays active reasoning for streaming without mutating stored state
[32mSuccess[0m	||	highlight_structure returns copied query values
[32mSuccess[0m	||	highlight_structure fast-replaces fingerprint-identical body edits with exact bounded work
[32mSuccess[0m	||	highlight_structure indexes many reasoning openers with linear, exactly-accounted work
[32mSuccess[0m	||	highlight_structure separates cardinality rejection's contract count from actual visits
[32mSuccess[0m	||	highlight_structure rejects structural replacements without suffix work or mutation
[32mSuccess[0m	||	highlight_structure rebuilds shifted footer/drafts and downstream state after structural edits

[32mSuccess: [0m	9
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
Running tests/unit/line_reader_spec.lua
Scheduling: tests/unit/line_reader_spec.lua

========================================
Testing:	/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/tests/unit/line_reader_spec.lua
[32mSuccess[0m	||	parley.line_reader preserves reads and reports requested versus returned line work
[32mSuccess[0m	||	parley.line_reader forwards nil text options unchanged to the production API
[32mSuccess[0m	||	parley.line_reader reports precise rows touched by text reads
[32mSuccess[0m	||	parley.line_reader matches native half-open text results at an end-row column zero
[32mSuccess[0m	||	parley.line_reader observes invalid attempts while preserving the delegate error
[32mSuccess[0m	||	parley.line_reader isolates observers, checks tokens, and invalidates state on clear
[32mSuccess[0m	||	parley.line_reader restores nested phases on success and error
[32mSuccess[0m	||	parley.line_reader records CPU-side structural work in the active phase

[32mSuccess: [0m	8
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
Running tests/unit/perf_harness_spec.lua
Scheduling: tests/unit/perf_harness_spec.lua

========================================
Testing:	/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/tests/unit/perf_harness_spec.lua
[32mSuccess[0m	||	performance harness summarizes odd and even samples without mutating input
[32mSuccess[0m	||	performance harness uses nearest-rank p95 and rejects empty samples
[32mSuccess[0m	||	performance harness measures elapsed milliseconds with an injected clock
[32mSuccess[0m	||	performance harness creates and encodes the exact report envelope
[32mSuccess[0m	||	performance harness validates scenarios and does not retain caller-owned tables
[32mSuccess[0m	||	performance harness rejects invalid counts and work counters
[32mSuccess[0m	||	performance harness rejects invalid elapsed samples and inconsistent statistics
[32mSuccess[0m	||	performance harness renders grouped ratios in deterministic size order and two-decimal precision

[32mSuccess: [0m	8
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================

codex
```verdict
verdict: REWORK
confidence: high
```

The core presentation architecture is strong and most tested behavior matches the Spec, but the shared skill terminal boundary can still throw after registering cleanup and before dispatch, leaking Definition’s spinner and terminal ownership. The plan’s Core concepts also overstates the real SSE fixture’s implemented modes, which is a Critical traceability contradiction under this review contract.

1. Strengths

- The pure reducer cleanly owns timing and ordered state transitions in [chat_presentation.lua](/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/lua/parley/chat_presentation.lua:132), with 41 passing IO-free tests.
- Chat progress uses extmarks rather than transcript/model mutations, with lease validation, serialized callbacks, and timer cleanup in [chat_pending.lua](/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/lua/parley/chat_pending.lua:291).
- The subprocess boundary now waits for process exit and both pipe EOFs before terminal delivery in [tasker.lua](/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/lua/parley/tasker.lua:302).
- Canonical spinner frames are reused by both new renderers; no parallel frame sequence was introduced.
- README, atlas, index, provider/tool-use documentation, and traceability were updated for the new user and architectural surfaces.

2. Critical findings

- [skill_invoke.lua:193](/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/lua/parley/skill_invoke.lua:193) — `finish` and `_terminals[buf]` are installed, but subsequent setup remains outside any protected boundary: invocation assembly, agent resolution, `prepare_payload`, decoration clearing, root-policy construction, and detached progress startup can throw before `llm.query`’s `pcall`. `prepare_payload` deliberately raises for tool-enabled OpenAI, Google AI, and Ollama agents. Definition starts its selection spinner before invoking this code, so such a failure bypasses `on_terminal`, propagates an exception, and leaves its timer/extmark plus stale terminal ownership behind. This contradicts the Spec and the Core-concept claim that every failure converges through one terminal (`ARCH-PURPOSE`). Fix by protecting all fallible work after terminal registration and routing exceptions through `finish({ok=false, msg=...}, true)`. Add a real `define_visual` test with an injected throwing `prepare_payload` or unsupported configured skill agent.

- [plan.md:84](/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md:84) — The Core concepts entry claims `fake_sse_server` implements fast, delayed, activity-only-then-visible, partial-failure, and tool-use-only modes. The fixture only has explicit delayed, broken, unauthorized, and HTTP-500 behavior, plus its default success path; there are no activity-only or tool-use-only modes in [fake_sse_server:22](/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/tests/fixtures/fake_sse_server:22). Per the required Core-concepts cross-check, this code/plan contradiction is Critical. Either add the claimed modes and process tests or revise the Core-concept description to state that activity/tool behavior is covered through callback-driven entry tests.

3. Important findings

None beyond the missing regression test attached to the first Critical finding.

4. Minor findings

None.

5. Test coverage notes

- Passed: lint, `git diff --check`, 41 reducer tests, 43 dispatcher tests, 29 vault tests, 29 tasker tests, 21 chat-pending tests, and mapped chat lifecycle and inline-definition suites.
- The mapped Definition suite passed 23 integration tests; skill terminal ownership passed 16.
- The loopback process suite’s three pre-start cases passed. Its four HTTP/SSE cases could not run because this sandbox rejects localhost socket binding with `PermissionError`; this is an environment restriction rather than an observed Parley failure.
- The normal `Makefile` symlink target is unavailable in this checkout environment, so validation used `Makefile.parley` directly.

6. Architectural notes for upcoming work

- `ARCH-DRY`: Pass. Spinner frames, reducer transitions, and terminal helpers are centralized without substantive copied policy.
- `ARCH-PURE`: Pass. The three declared pure entities exist and their tests require no network, process, filesystem, clock, or Neovim UI mocks. Integration entities remain in IO-facing modules.
- `ARCH-PURPOSE`: Flag. Main chat behavior is delivered, but Definition’s promised every-terminal cleanup is not enforced across synchronous setup exceptions.
- All Core-concept entities exist at their stated paths and their new/modified status matches the diff. The exception is the overstated fixture behavior noted above.
- Docs update gate: Pass for both atlas and README.

7. Plan revision recommendations

Add entries under `## Revisions` recording:

- Task 5 terminal ownership must include synchronous failures after source resolution, especially payload preparation, decoration/root setup, and progress startup; reset the affected completion checkbox until covered.
- Correct `fake_sse_server`’s Core-concept description to enumerate its actual modes and identify activity/tool-only behavior as callback-driven coverage—or implement those fixture modes if process-level coverage is intended.
tokens used
190,332
```verdict
verdict: REWORK
confidence: high
```

The core presentation architecture is strong and most tested behavior matches the Spec, but the shared skill terminal boundary can still throw after registering cleanup and before dispatch, leaking Definition’s spinner and terminal ownership. The plan’s Core concepts also overstates the real SSE fixture’s implemented modes, which is a Critical traceability contradiction under this review contract.

1. Strengths

- The pure reducer cleanly owns timing and ordered state transitions in [chat_presentation.lua](/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/lua/parley/chat_presentation.lua:132), with 41 passing IO-free tests.
- Chat progress uses extmarks rather than transcript/model mutations, with lease validation, serialized callbacks, and timer cleanup in [chat_pending.lua](/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/lua/parley/chat_pending.lua:291).
- The subprocess boundary now waits for process exit and both pipe EOFs before terminal delivery in [tasker.lua](/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/lua/parley/tasker.lua:302).
- Canonical spinner frames are reused by both new renderers; no parallel frame sequence was introduced.
- README, atlas, index, provider/tool-use documentation, and traceability were updated for the new user and architectural surfaces.

2. Critical findings

- [skill_invoke.lua:193](/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/lua/parley/skill_invoke.lua:193) — `finish` and `_terminals[buf]` are installed, but subsequent setup remains outside any protected boundary: invocation assembly, agent resolution, `prepare_payload`, decoration clearing, root-policy construction, and detached progress startup can throw before `llm.query`’s `pcall`. `prepare_payload` deliberately raises for tool-enabled OpenAI, Google AI, and Ollama agents. Definition starts its selection spinner before invoking this code, so such a failure bypasses `on_terminal`, propagates an exception, and leaves its timer/extmark plus stale terminal ownership behind. This contradicts the Spec and the Core-concept claim that every failure converges through one terminal (`ARCH-PURPOSE`). Fix by protecting all fallible work after terminal registration and routing exceptions through `finish({ok=false, msg=...}, true)`. Add a real `define_visual` test with an injected throwing `prepare_payload` or unsupported configured skill agent.

- [plan.md:84](/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/workshop/plans/000182-claude-code-style-progression-text-in-parley-chat-plan.md:84) — The Core concepts entry claims `fake_sse_server` implements fast, delayed, activity-only-then-visible, partial-failure, and tool-use-only modes. The fixture only has explicit delayed, broken, unauthorized, and HTTP-500 behavior, plus its default success path; there are no activity-only or tool-use-only modes in [fake_sse_server:22](/Users/xianxu/workspace/worktree/parley.nvim/000182-claude-code-style-progression-text-in-parley-chat/tests/fixtures/fake_sse_server:22). Per the required Core-concepts cross-check, this code/plan contradiction is Critical. Either add the claimed modes and process tests or revise the Core-concept description to state that activity/tool behavior is covered through callback-driven entry tests.

3. Important findings

None beyond the missing regression test attached to the first Critical finding.

4. Minor findings

None.

5. Test coverage notes

- Passed: lint, `git diff --check`, 41 reducer tests, 43 dispatcher tests, 29 vault tests, 29 tasker tests, 21 chat-pending tests, and mapped chat lifecycle and inline-definition suites.
- The mapped Definition suite passed 23 integration tests; skill terminal ownership passed 16.
- The loopback process suite’s three pre-start cases passed. Its four HTTP/SSE cases could not run because this sandbox rejects localhost socket binding with `PermissionError`; this is an environment restriction rather than an observed Parley failure.
- The normal `Makefile` symlink target is unavailable in this checkout environment, so validation used `Makefile.parley` directly.

6. Architectural notes for upcoming work

- `ARCH-DRY`: Pass. Spinner frames, reducer transitions, and terminal helpers are centralized without substantive copied policy.
- `ARCH-PURE`: Pass. The three declared pure entities exist and their tests require no network, process, filesystem, clock, or Neovim UI mocks. Integration entities remain in IO-facing modules.
- `ARCH-PURPOSE`: Flag. Main chat behavior is delivered, but Definition’s promised every-terminal cleanup is not enforced across synchronous setup exceptions.
- All Core-concept entities exist at their stated paths and their new/modified status matches the diff. The exception is the overstated fixture behavior noted above.
- Docs update gate: Pass for both atlas and README.

7. Plan revision recommendations

Add entries under `## Revisions` recording:

- Task 5 terminal ownership must include synchronous failures after source resolution, especially payload preparation, decoration/root setup, and progress startup; reset the affected completion checkbox until covered.
- Correct `fake_sse_server`’s Core-concept description to enumerate its actual modes and identify activity/tool-only behavior as callback-driven coverage—or implement those fixture modes if process-level coverage is intended.
