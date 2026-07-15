# Boundary Review — parley.nvim#190 (whole-issue close)

| field | value |
|-------|-------|
| issue | 190 — persist repo super-repo state across nvim sessions |
| repo | parley.nvim |
| issue file | workshop/issues/000190-persist-repo-super-repo-state-across-nvim-sessions.md |
| boundary | whole-issue close |
| milestone | — |
| window | ac2706896b00ddb30e3ab229674c671f604c4a4f..HEAD |
| command | sdlc close --issue 190 |
| reviewer | codex |
| timestamp | 2026-07-15T16:38:18-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Reading additional input from stdin...
OpenAI Codex v0.144.4
--------
workdir: /Users/xianxu/workspace/parley.nvim
model: gpt-5.6-sol
provider: openai
approval: never
sandbox: workspace-write [workdir, /tmp, $TMPDIR, /tmp] (network access enabled)
reasoning effort: none
reasoning summaries: none
session id: 019f6821-7f7c-7e42-b1df-38ca52129feb
--------
user
# Code review — the one SDLC boundary review

You are conducting a fresh-context code review at a development boundary —
whole-issue close — in the **parley.nvim** repository.

- repository: parley.nvim   (root: /Users/xianxu/workspace/parley.nvim)
- issue:      parley.nvim#190   (file: workshop/issues/000190-persist-repo-super-repo-state-across-nvim-sessions.md)
- window:     Base: ac2706896b00ddb30e3ab229674c671f604c4a4f   Head: HEAD

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
diff --git a/README.md b/README.md
index a82eb6a..3345053 100644
--- a/README.md
+++ b/README.md
@@ -124,6 +124,9 @@ Most-used defaults:
   across finder reopenings within the current Neovim session. When a facet bar
   wraps beyond its visible height, point at the bar and use the mouse wheel to
   reach the remaining facets.
+- `<C-g>p` toggle peer (super-repo) mode - aggregate reads across sibling
+  `.parley` repositories. The explicit repo/peer choice persists separately for
+  each repository; an unsaved repository starts in ordinary repo mode.

 **In Chat Buffer**
 - `<C-g>?` show key bindings
@@ -138,6 +141,11 @@ Most-used defaults:
 - `<C-g>a` change agent
 - `<C-g>P` next system prompt
 - `<C-g>s` skill picker (review, voice-apply, etc.)
+- `<C-g>b` branch/prune - move the current exchange and following exchanges to
+  a child chat
+
+Tool-fold toggling is configurable but unbound by default. To opt in, set
+`chat_shortcut_toggle_tool_folds = { modes = { "n" }, shortcut = "<leader>tf" }`.
 - `<C-g>l` toggle follow cursor
 - `<C-g>i` to insert a fork in the chat tree, can be inline or standalone
 - `gf` smart go-to-file: on an ariadne artifact ref (`ariadne#11`, `#15 M4`, `pair#84`) resolves it and jumps (family picker when it resolves to many); on a plain path, Vim's native `gf`
diff --git a/atlas/chat/lifecycle.md b/atlas/chat/lifecycle.md
index a01cac3..5c58e26 100644
--- a/atlas/chat/lifecycle.md
+++ b/atlas/chat/lifecycle.md
@@ -9,9 +9,14 @@ When a chat's `topic:` header changes, the file is auto-renamed to include a slu
 ## Move (`:ParleyChatMove`)
 Moves entire chat tree (root + descendants) to another chat root; rewrites all `🌿:` references.

-## Pruning (`<C-g>p`)
+## Branching / Pruning (`<C-g>b`)
 Splits current exchange + following into a new child chat with `🌿:` links. Async LLM topic generation.

+The tool-fold toggle remains configurable as
+`chat_shortcut_toggle_tool_folds`, but has no default mapping. A configured
+non-empty shortcut is registered and shown through the shared keybinding
+registry.
+
 ## Response (`:ParleyChatRespond` / `<C-g><C-g>`)
 Assembles context (with memory summarization), streams LLM response into buffer. The [exchange model](exchange_model.md) is the single source of truth for all transcript mutations during the response lifecycle — streaming text growth, tool block insertion, and prompt append all go through the model. [Response progress](response_progress.md) is cosmetic extmark state that begins at the response header (or a recursive leg's last visible block), then follows the current generation tip; it never becomes a model block. A per-buffer pending-session guard prevents duplicate calls.

diff --git a/atlas/index.md b/atlas/index.md
index e26b22e..d76096f 100644
--- a/atlas/index.md
+++ b/atlas/index.md
@@ -63,7 +63,7 @@ This index provides a central directory for all atlas entries of the `parley.nvi
 - [Interview Mode](modes/interview.md): Mechanics, automatic timestamps, and `{thought}` highlighting.
 - [Raw Mode](modes/raw_mode.md): API debugging via raw requests/responses — see [Raw-Mode Logging](infra/raw_logging.md) for the debug workflow.
 - [Document Review](modes/review.md): LLM-powered document review via 🤖 markers (implemented as a skill).
-- [Super-Repo Mode](modes/super_repo.md): Toggle (`<C-g>S`) to aggregate reads across sibling `.parley` repos under the workspace root.
+- [Super-Repo Mode](modes/super_repo.md): Toggle peers (`<C-g>p`) to aggregate reads across sibling `.parley` repos; the explicit choice persists per repository.

 ## 9. Export
 - [Export Formats](export/formats.md): Jekyll HTML and Markdown export logic.
diff --git a/atlas/infra/repo_mode.md b/atlas/infra/repo_mode.md
index ccd0445..f72b173 100644
--- a/atlas/infra/repo_mode.md
+++ b/atlas/infra/repo_mode.md
@@ -30,6 +30,11 @@ chat_roots = [config.chat_dir]

 `apply_repo_local()` materializes this list at setup; super-repo toggling pushes/pops sibling entries at runtime. There are no `:ParleyChatDirs` / `:ParleyChatDirAdd` / `:ParleyChatDirRemove` commands and no `<C-g>h` keybinding — they were removed in issue #117 because the original use case (drop a folder in for deliberation) is fully covered by repo + super-repo modes. State.json no longer carries `chat_dirs` / `chat_roots`; old state files with these fields are silently ignored on load.

+`state.json.repo_modes` separately stores each canonical repo root's explicit
+`repo` / `super_repo` choice. Missing or invalid entries mean ordinary repo
+mode. Setup applies the saved choice once after all state refreshes, and brain
+repositories use exactly the same policy; `.brain` does not imply peer mode.
+
 ### Reference neighborhood (#147)
 Relative tool paths and chat-buffer file completion use a per-artifact
 neighborhood root, not the editor process cwd. `lua/parley/neighborhood.lua`
@@ -68,7 +73,7 @@ All directory names are relative to git root unless they start with `/`.
 - `apply_repo_local()` builds `config.chat_roots = [{dir=repo_chat, label="repo"}, {dir=config.chat_dir, label="global"}, ...]` directly, bypassing the basename-derived label heuristic in `default_root_label`
 - Repo-mode Markdown and Parley chat buffers use the policy-backed `parley_path`
   nvim-cmp source plus `buffer`; attachment is buffer-idempotent
-- `refresh_state()` re-asserts the repo *note* dir as primary after restoring persisted state (chat side does not need this — chat state is never persisted), and strips note_roots entries marked transient (plain repo's `label = "repo"` and super-repo's pushed sibling dirs) from `state.json`
+- `refresh_state()` re-asserts the repo *note* dir as primary after restoring persisted state, then calls the shared atomic write-only persistence boundary. That boundary strips chat roots and note roots marked transient (plain repo's `label = "repo"` and super-repo's pushed sibling dirs) without reloading or disturbing live roots.
 - `detect_buffer_context` checks all note roots (not just primary) for scope detection
 - `neighborhood.derive_for_path()` canonicalizes `/var`/`/private/var` style path aliases before testing repo-local artifact directories
 - Finders scan all roots, tagging non-primary entries with `{label}` prefix
diff --git a/atlas/modes/super_repo.md b/atlas/modes/super_repo.md
index c24071b..fcebd58 100644
--- a/atlas/modes/super_repo.md
+++ b/atlas/modes/super_repo.md
@@ -7,12 +7,21 @@ Writes are unchanged: still go to the current repo.

 ## Activation

-- **Toggle**: `<C-g>S` (`global_shortcut_super_repo_toggle`).
+- **Toggle peers**: `<C-g>p` (`global_shortcut_super_repo_toggle`).
 - **Pre-condition**: cwd must be inside a `.parley` repo (i.e. `repo_root`
   is set by `apply_repo_local`). If not, the toggle fails with a notice.
 - **Workspace root**: parent of `repo_root`. Members are direct children of
   the workspace root whose own direct child is `.parley`.
-- **Transient** — never persisted to `state.json`.
+- **Per-repo preference**: a successful explicit toggle stores `repo` or
+  `super_repo` under the canonical current repo root in `state.json.repo_modes`.
+  A repository with no saved entry starts in ordinary repo mode. Global mode
+  has no repo preference.
+
+Setup restores a saved peer choice synchronously once, after the initial and
+optional default-agent state refreshes have settled repo-local roots. The
+restoration path changes only the runtime overlay and does not rewrite the
+preference. `.brain` has no special behavior: brain repositories follow the
+same saved choice and ordinary unsaved default as every other repository.

 ## Mode glyphs (lualine)

@@ -85,6 +94,12 @@ design (see `workshop/issues/000113-create-a-super-repo-mode.md`).

 ## Persistence safety

+State replacement is atomic and result-bearing. Explicit toggles update the
+runtime overlay first, then write a transient-safe snapshot without reloading
+state or reapplying roots. If that write fails, the new runtime mode remains
+active, the previous `state.json` remains intact, and Parley emits one bounded
+“preference not saved” warning.
+
 For **chat** roots: trivially safe. Issue #117 stopped persisting
 `chat_roots` / `chat_dirs` to `state.json` entirely — the chat root list
 is derived on every read from `config.chat_dir + repo + super-repo`.
@@ -99,10 +114,12 @@ filter for plain repo mode's primary note root.

 ## Code

-- `lua/parley/super_repo.lua` — module: `compute_members`, `is_active`,
-  `toggle`, `get_pushed_chat_dirs` / `get_pushed_note_dirs`.
+- `lua/parley/repo_mode.lua` — pure saved-mode selection and immutable map update.
+- `lua/parley/super_repo.lua` — runtime-only module: `compute_members`,
+  `is_active`, `set_active`, `toggle`, and pushed-root accessors.
 - `lua/parley/init.lua` — wires `parley.toggle_super_repo()` /
-  `parley.is_super_repo_active()`; persistence gate consults pushed-dirs.
+  `parley.is_super_repo_active()`, restores after setup refreshes, and owns the
+  write-only transient-safe persistence boundary.
 - `lua/parley/issues.lua` — `scan_issues` accepts `repo_name` +
   `history_dir_override` opts.
 - `lua/parley/issue_finder.lua`, `vision_finder.lua` — multi-root aggregation
diff --git a/atlas/traceability.yaml b/atlas/traceability.yaml
index 2f09d73..3598b86 100644
--- a/atlas/traceability.yaml
+++ b/atlas/traceability.yaml
@@ -16,6 +16,8 @@ atlas:
   chat/lifecycle:
     code:
       - lua/parley/init.lua
+      - lua/parley/config.lua
+      - lua/parley/keybinding_registry.lua
       - lua/parley/chat_respond.lua
       - lua/parley/buffer_lifecycle.lua
       - lua/parley/diagnostic_refresh.lua
@@ -31,6 +33,8 @@ atlas:
       - lua/parley/chat_pending.lua
       - lua/parley/tasker.lua
     tests:
+      - tests/unit/keybindings_spec.lua
+      - tests/unit/config_tools_spec.lua
       - tests/unit/perf_harness_spec.lua
       - tests/unit/line_reader_spec.lua
       - tests/unit/diagnostic_refresh_spec.lua
@@ -252,6 +256,8 @@ atlas:

   modes/super_repo:
     code:
+      - lua/parley/helper.lua
+      - lua/parley/repo_mode.lua
       - lua/parley/super_repo.lua
       - lua/parley/init.lua
       - lua/parley/issues.lua
@@ -263,6 +269,8 @@ atlas:
       - lua/parley/lualine.lua
       - lua/parley/keybinding_registry.lua
     tests:
+      - tests/unit/helper_io_spec.lua
+      - tests/unit/repo_mode_spec.lua
       - tests/unit/super_repo_spec.lua
       - tests/unit/finder_facets_spec.lua
       - tests/unit/chat_finder_logic_spec.lua
@@ -437,6 +445,17 @@ atlas:
       - .openshell/overlay/setup.sh
     tests: []

+  infra/repo_mode:
+    code:
+      - lua/parley/init.lua
+      - lua/parley/helper.lua
+      - lua/parley/repo_mode.lua
+      - lua/parley/super_repo.lua
+    tests:
+      - tests/unit/helper_io_spec.lua
+      - tests/unit/repo_mode_spec.lua
+      - tests/unit/super_repo_spec.lua
+
   infra/workflow:
     code:
       - Makefile.workflow
@@ -533,8 +552,10 @@ atlas:
     code:
       - lua/parley/init.lua
       - lua/parley/config.lua
+      - lua/parley/keybinding_registry.lua
     tests:
       - tests/unit/keybindings_spec.lua
+      - tests/unit/config_tools_spec.lua

   skills/skill-system:
     code:
diff --git a/lua/parley/config.lua b/lua/parley/config.lua
index 6be9c04..1666102 100644
--- a/lua/parley/config.lua
+++ b/lua/parley/config.lua
@@ -454,8 +454,9 @@ local config = {
	chat_shortcut_delete = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>d" },
	chat_shortcut_delete_tree = { modes = { "n" }, shortcut = "<C-g>D" },
	chat_shortcut_stop = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>x" },
-	-- Toggle folds of 🔧:/📎: components within the exchange under cursor
-	chat_shortcut_toggle_tool_folds = { modes = { "n" }, shortcut = "<C-g>b" },
+	-- Toggle folds of 🔧:/📎: components within the exchange under cursor.
+	-- Intentionally unbound by default; configure chat_shortcut_toggle_tool_folds
+	-- to opt in.
	chat_shortcut_agent = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>a" },
	chat_shortcut_system_prompt = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>P" },
	chat_shortcut_follow_cursor = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>l" },
@@ -465,7 +466,7 @@ local config = {
	-- `sdlc resolve`), else native go-to-file. Transparent (native gf preserved on
	-- plain paths); remap here to disable.
	chat_shortcut_resolve_ref_gf = { modes = { "n" }, shortcut = "gf" },
-	chat_shortcut_prune = { modes = { "n" }, shortcut = "<C-g>p" },
+	chat_shortcut_prune = { modes = { "n" }, shortcut = "<C-g>b" },
	chat_shortcut_export_markdown = { modes = { "n" }, shortcut = "<C-g>em" },
	chat_shortcut_export_html = { modes = { "n" }, shortcut = "<C-g>eh" },
	chat_shortcut_exchange_cut = { modes = { "n", "v" }, shortcut = "<C-g>X" },
@@ -570,7 +571,7 @@ local config = {
	-- maximum directory depth for markdown finder (from repo root)
	markdown_finder_max_depth = 6,
	-- super-repo mode toggle (aggregates reads across sibling .parley repos)
-	global_shortcut_super_repo_toggle = { modes = { "n", "i" }, shortcut = "<C-g>S" },
+	global_shortcut_super_repo_toggle = { modes = { "n", "i" }, shortcut = "<C-g>p" },
	-- global shortcuts for issue management
	global_shortcut_issue_new = { modes = { "n", "i" }, shortcut = "<C-y>c" },
	global_shortcut_issue_finder = { modes = { "n", "i" }, shortcut = "<C-y>f" },
diff --git a/lua/parley/helper.lua b/lua/parley/helper.lua
index f5ecbcf..c685f3e 100644
--- a/lua/parley/helper.lua
+++ b/lua/parley/helper.lua
@@ -436,6 +436,65 @@ _H.table_to_file = function(tbl, file_path)
	file:close()
 end

+---@param tbl table # table to encode as JSON
+---@param file_path string # destination replaced only after a complete write
+---@param adapter table|nil # optional IO adapter for deterministic failure tests
+---@return boolean ok
+---@return string|nil err
+_H.table_to_file_atomic = function(tbl, file_path, adapter)
+	adapter = adapter or {}
+	local encode = adapter.encode or vim.json.encode
+	local open = adapter.open or io.open
+	local rename = adapter.rename or os.rename
+	local remove = adapter.remove or os.remove
+	local temp_path = adapter.temp_path or function(path)
+		local uv = vim.uv or vim.loop
+		local nonce = uv and uv.hrtime and uv.hrtime() or os.time()
+		return string.format("%s.tmp-%s-%06x", path, tostring(nonce), math.random(0, 0xFFFFFF))
+	end
+
+	local function failure(stage, detail)
+		local message = tostring(detail or "unknown error")
+		return false, (stage .. " failed: " .. message):sub(1, 240)
+	end
+	local function cleanup(path)
+		pcall(remove, path)
+	end
+
+	local encoded_ok, json = pcall(encode, tbl)
+	if not encoded_ok then
+		return failure("encode", json)
+	end
+
+	local tmp = temp_path(file_path)
+	local open_ok, file, open_err = pcall(open, tmp, "w")
+	if not open_ok or not file then
+		cleanup(tmp)
+		return failure("open", open_ok and open_err or file)
+	end
+
+	local write_ok, write_result, write_err = pcall(function() return file:write(json) end)
+	if not write_ok or not write_result then
+		pcall(function() file:close() end)
+		cleanup(tmp)
+		return failure("write", write_ok and write_err or write_result)
+	end
+
+	local close_ok, close_result, close_err = pcall(function() return file:close() end)
+	if not close_ok or not close_result then
+		cleanup(tmp)
+		return failure("close", close_ok and close_err or close_result)
+	end
+
+	local rename_ok, rename_result, rename_err = pcall(rename, tmp, file_path)
+	if not rename_ok or not rename_result then
+		cleanup(tmp)
+		return failure("rename", rename_ok and rename_err or rename_result)
+	end
+
+	return true
+end
+
 ---@param file_path string # the file path from where to read the json into a table
 ---@return table | nil # the table read from the file, or nil if an error occurred
 _H.file_to_table = function(file_path)
diff --git a/lua/parley/init.lua b/lua/parley/init.lua
index 36ea260..af38875 100644
--- a/lua/parley/init.lua
+++ b/lua/parley/init.lua
@@ -64,9 +64,28 @@ note_dirs.setup(M)

 -- Super-repo module (loaded here; wired up immediately since it only needs M reference)
 local super_repo = require("parley.super_repo")
+local repo_mode = require("parley.repo_mode")
 super_repo.setup(M)
 M.super_repo = super_repo
-M.toggle_super_repo = function() return super_repo.toggle() end
+M.toggle_super_repo = function()
+	local transitioned, err = super_repo.toggle()
+	if not transitioned then
+		return false, err
+	end
+
+	local root = M.config.repo_root
+	if type(root) == "string" and root ~= "" then
+		local canonical_root = vim.fn.resolve(vim.fn.expand(root)):gsub("/+$", "")
+		local mode = super_repo.is_active() and "super_repo" or "repo"
+		M._state.repo_modes = repo_mode.updated(M._state.repo_modes, canonical_root, mode)
+		local persisted = M.persist_state()
+		if not persisted then
+			M.logger.warning("super-repo: preference not saved")
+		end
+	end
+
+	return true
+end
 M.is_super_repo_active = function() return super_repo.is_active() end

 -- Discovery registry (#116): the repo's noun-vocabulary (what file types exist
@@ -637,21 +656,6 @@ M.setup = function(opts)
	apply_chat_roots(normalize_chat_roots(M.config.chat_dir, M.config.chat_dirs, M.config.chat_roots))
	apply_note_roots(normalize_note_roots(M.config.notes_dir, M.config.note_dirs, M.config.note_roots))

-	-- Brain repos auto-enter super-repo mode. A repo is a brain iff it has a
-	-- `.brain/` directory at root (constitution convention). Deferred to
-	-- VimEnter so chat_roots/note_roots have settled before super_repo mutates
-	-- them, and to avoid racing other plugins' setup().
-	if M.config.repo_root and vim.fn.isdirectory(M.config.repo_root .. "/.brain") == 1 then
-		vim.api.nvim_create_autocmd("VimEnter", {
-			once = true,
-			callback = function()
-				if not super_repo.is_active() then
-					super_repo.toggle()
-				end
-			end,
-		})
-	end
-
	-- repo-local dirs (issues, history, vision, notes) are resolved in apply_repo_local
	-- against git root; skip them here to avoid creating in CWD
	local skip_prepare = { chat_dir = true }
@@ -752,6 +756,14 @@ M.setup = function(opts)
		M.refresh_state({ agent = M.config.default_agent })
	end

+	-- Restore the current repo's explicit mode only after every state refresh has
+	-- settled roots. This runtime transition is intentionally non-persisting.
+	if type(M.config.repo_root) == "string" and M.config.repo_root ~= "" then
+		local canonical_root = vim.fn.resolve(vim.fn.expand(M.config.repo_root)):gsub("/+$", "")
+		local saved_mode = repo_mode.resolve(M._state.repo_modes, canonical_root)
+		super_repo.set_active(saved_mode == "super_repo")
+	end
+
	-- register user commands
	for hook, _ in pairs(M.hooks) do
		M.helpers.create_user_command(M.config.cmd_prefix .. hook, function(params)
@@ -1129,6 +1141,45 @@ M.setup = function(opts)
	M.logger.debug("setup finished")
 end

+--- Persist the current state without reloading disk state or reapplying roots.
+--- Runtime-derived chat roots and repo/super-repo note roots are excluded.
+---@return boolean ok
+---@return string|nil err
+M.persist_state = function()
+	local persist_state = vim.deepcopy(M._state)
+	persist_state.chat_roots = nil
+	persist_state.chat_dirs = nil
+
+	local function resolve_dir(dir)
+		return vim.fn.resolve(vim.fn.expand(dir)):gsub("/+$", "")
+	end
+	local pushed_note = {}
+	for _, dir in ipairs(super_repo.get_pushed_note_dirs()) do
+		pushed_note[dir] = true
+	end
+	if type(persist_state.note_roots) == "table" then
+		local filtered = {}
+		for _, root in ipairs(persist_state.note_roots) do
+			if root.label ~= "repo" and not pushed_note[resolve_dir(root.dir)] then
+				table.insert(filtered, root)
+			end
+		end
+		persist_state.note_roots = #filtered > 0 and filtered or nil
+	end
+	if type(persist_state.note_roots) == "table" then
+		local dirs = {}
+		for _, root in ipairs(persist_state.note_roots) do
+			table.insert(dirs, root.dir)
+		end
+		persist_state.note_dirs = #dirs > 0 and dirs or nil
+	else
+		persist_state.note_dirs = nil
+	end
+
+	local state_file = M.config.state_dir .. "/state.json"
+	return M.helpers.table_to_file_atomic(persist_state, state_file)
+end
+
 ---@param update table | nil # table with options
 M.refresh_state = function(update)
	local state_file = M.config.state_dir .. "/state.json"
@@ -1244,44 +1295,12 @@ M.refresh_state = function(update)
		end
	end

-	-- Note-mode roots are transient (super-repo toggle, or plain repo
-	-- mode tagging the primary with label = "repo"). Never persist them
-	-- — otherwise a later session with a different cwd would restore
-	-- roots it shouldn't have. Issue #117 M2: chat roots are no longer
-	-- persisted at all (derived from config + repo + super-repo); only
-	-- the note side still goes through strip_transient.
-	local persist_state = vim.deepcopy(M._state)
-	persist_state.chat_roots = nil
-	persist_state.chat_dirs = nil
-	local function resolve_dir(d)
-		local out = vim.fn.resolve(vim.fn.expand(d)):gsub("/+$", "")
-		return out
-	end
-	local function set_of(list)
-		local s = {}
-		for _, d in ipairs(list or {}) do s[d] = true end
-		return s
-	end
-	local pushed_note = set_of(super_repo.get_pushed_note_dirs())
-	if type(persist_state.note_roots) == "table" then
-		local filtered = {}
-		for _, root in ipairs(persist_state.note_roots) do
-			if root.label ~= "repo" and not pushed_note[resolve_dir(root.dir)] then
-				table.insert(filtered, root)
-			end
-		end
-		persist_state.note_roots = #filtered > 0 and filtered or nil
-	end
-	if type(persist_state.note_roots) == "table" then
-		local dirs = {}
-		for _, root in ipairs(persist_state.note_roots) do
-			table.insert(dirs, root.dir)
-		end
-		persist_state.note_dirs = #dirs > 0 and dirs or nil
-	else
-		persist_state.note_dirs = nil
+	-- Runtime roots are filtered by the shared write-only boundary. Writing must
+	-- not reload state or disturb a live super-repo overlay.
+	local persisted, persist_err = M.persist_state()
+	if not persisted then
+		M.logger.warning("state: persistence failed: " .. tostring(persist_err or "unknown error"))
	end
-	M.helpers.table_to_file(persist_state, state_file)

	local buf = vim.api.nvim_get_current_buf()
	local file_name = vim.api.nvim_buf_get_name(buf)
diff --git a/lua/parley/keybinding_registry.lua b/lua/parley/keybinding_registry.lua
index 41847b7..41aec52 100644
--- a/lua/parley/keybinding_registry.lua
+++ b/lua/parley/keybinding_registry.lua
@@ -99,7 +99,7 @@ end
 -- Each entry:
 --   id           - unique identifier, used as callback key
 --   config_key   - key in parley config table (nil if not configurable)
---   default_key  - default shortcut string
+--   default_key  - default shortcut string (optional when config_key is set)
 --   default_modes - default mode list
 --   scope        - scope name from the forest
 --   desc         - vim keymap description
@@ -193,7 +193,6 @@ M.entries = {
	{
		id = "super_repo_toggle",
		config_key = "global_shortcut_super_repo_toggle",
-		default_key = "<C-g>S",
		default_modes = { "n", "i" },
		scope = "global",
		desc = "Toggle super-repo mode (aggregate reads across sibling .parley repos)",
@@ -573,7 +572,6 @@ M.entries = {
	{
		id = "chat_prune",
		config_key = "chat_shortcut_prune",
-		default_key = "<C-g>p",
		default_modes = { "n" },
		scope = "chat",
		desc = "Parley prune chat",
@@ -623,7 +621,6 @@ M.entries = {
	{
		id = "chat_toggle_tool_folds",
		config_key = "chat_shortcut_toggle_tool_folds",
-		default_key = "<C-g>b",
		default_modes = { "n" },
		scope = "chat",
		desc = "Parley toggle tool folds",
@@ -916,8 +913,13 @@ end
 function M.resolve_keys(entry, config)
	local function as_list(v)
		if v == nil then return nil end
-		if type(v) == "string" then return { v } end
-		return v
+		if type(v) == "string" then return v ~= "" and { v } or nil end
+		if type(v) ~= "table" then return nil end
+		local keys = {}
+		for _, key in ipairs(v) do
+			if type(key) == "string" and key ~= "" then table.insert(keys, key) end
+		end
+		return #keys > 0 and keys or nil
	end

	if not entry.config_key then
@@ -1002,7 +1004,7 @@ function M.help_lines(context, config, bufnr)
			table.insert(lines, M.scope_labels[scope] or scope)
			for _, entry in ipairs(scope_entries) do
				local key = resolve_display_shortcut(entry, config, bufnr)
-				add(key, entry.help_desc or entry.desc)
+				if key then add(key, entry.help_desc or entry.desc) end
			end
			table.insert(lines, "")
		end
diff --git a/lua/parley/repo_mode.lua b/lua/parley/repo_mode.lua
new file mode 100644
index 0000000..23d3a48
--- /dev/null
+++ b/lua/parley/repo_mode.lua
@@ -0,0 +1,37 @@
+local M = {}
+
+local function valid_mode(mode)
+    return mode == "repo" or mode == "super_repo"
+end
+
+local function valid_root(root)
+    return type(root) == "string" and root ~= ""
+end
+
+M.resolve = function(repo_modes, canonical_root)
+    if type(repo_modes) ~= "table" or not valid_root(canonical_root) then
+        return nil
+    end
+    local mode = repo_modes[canonical_root]
+    if valid_mode(mode) then
+        return mode
+    end
+    return nil
+end
+
+M.updated = function(repo_modes, canonical_root, mode)
+    local result = {}
+    if type(repo_modes) == "table" then
+        for root, saved_mode in pairs(repo_modes) do
+            if valid_root(root) and valid_mode(saved_mode) then
+                result[root] = saved_mode
+            end
+        end
+    end
+    if valid_root(canonical_root) and valid_mode(mode) then
+        result[canonical_root] = mode
+    end
+    return result
+end
+
+return M
diff --git a/lua/parley/super_repo.lua b/lua/parley/super_repo.lua
index a7297b5..1ae62a1 100644
--- a/lua/parley/super_repo.lua
+++ b/lua/parley/super_repo.lua
@@ -3,12 +3,12 @@
 -- Toggle activates a runtime overlay on top of plain repo mode:
 --   * Discovers sibling .parley repos under the current repo's parent dir.
 --   * Pushes their workshop/parley and workshop/notes paths into chat_roots
---     and note_roots as extras (label = "repo" so they are filtered out of
---     persisted state.json — see init.lua persistence gate).
+--     and note_roots as labelled transient extras.
 --   * Writes are unchanged: still go to the current repo, exactly as plain
 --     repo mode does today.
 --
--- Toggle is transient — never persisted.
+-- This module owns only the runtime overlay. parley.init persists explicit
+-- user choices and restores them through set_active().

 local M = {}
 local _parley
@@ -213,11 +213,15 @@ local function deactivate()
	return true
 end

-M.toggle = function()
-	if _state.active then
-		return deactivate()
+M.set_active = function(active)
+	if active then
+		return activate()
	end
-	return activate()
+	return deactivate()
+end
+
+M.toggle = function()
+	return M.set_active(not _state.active)
 end

 return M
diff --git a/tests/unit/config_tools_spec.lua b/tests/unit/config_tools_spec.lua
index 23d6dca..248815b 100644
--- a/tests/unit/config_tools_spec.lua
+++ b/tests/unit/config_tools_spec.lua
@@ -335,11 +335,12 @@ describe("new config prefix + shortcut defaults", function()
         assert.equals("📎:", parley.config.chat_tool_result_prefix)
     end)

-    it("defines chat_shortcut_toggle_tool_folds", function()
+    it("uses peer/branch defaults and leaves tool folds unbound", function()
         fresh_setup(nil)
-        local s = parley.config.chat_shortcut_toggle_tool_folds
-        assert.is_table(s)
-        assert.equals("<C-g>b", s.shortcut)
-        assert.same({ "n" }, s.modes)
+        assert.equals("<C-g>p", parley.config.global_shortcut_super_repo_toggle.shortcut)
+        assert.same({ "n", "i" }, parley.config.global_shortcut_super_repo_toggle.modes)
+        assert.equals("<C-g>b", parley.config.chat_shortcut_prune.shortcut)
+        assert.same({ "n" }, parley.config.chat_shortcut_prune.modes)
+        assert.is_nil(parley.config.chat_shortcut_toggle_tool_folds)
     end)
 end)
diff --git a/tests/unit/helper_io_spec.lua b/tests/unit/helper_io_spec.lua
index 23c2228..41f435c 100644
--- a/tests/unit/helper_io_spec.lua
+++ b/tests/unit/helper_io_spec.lua
@@ -226,6 +226,88 @@ describe("helper I/O functions", function()

             assert.equals("deep", loaded.level1.level2.value)
         end)
+
+        it("F5: table_to_file_atomic replaces complete JSON and reports success", function()
+            local path = tmpdir .. "/atomic.json"
+            vim.fn.writefile({ "old" }, path)
+
+            local ok, err = helper.table_to_file_atomic({ nested = { value = 42 } }, path)
+
+            assert.is_true(ok)
+            assert.is_nil(err)
+            assert.same({ nested = { value = 42 } }, helper.file_to_table(path))
+            assert.same({}, vim.fn.glob(path .. ".tmp-*", false, true))
+        end)
+
+        it("F6: encode failure is bounded and leaves destination unchanged", function()
+            local path = tmpdir .. "/atomic.json"
+            vim.fn.writefile({ "durable" }, path)
+
+            local ok, err = helper.table_to_file_atomic({}, path, {
+                encode = function() error(string.rep("secret", 100)) end,
+            })
+
+            assert.is_false(ok)
+            assert.is_true(err:find("encode", 1, true) ~= nil)
+            assert.is_true(#err <= 240)
+            assert.same({ "durable" }, vim.fn.readfile(path))
+            assert.same({}, vim.fn.glob(path .. ".tmp-*", false, true))
+        end)
+
+        for _, stage in ipairs({ "write", "close" }) do
+            it("F7: " .. stage .. " failure cleans the temporary file and preserves destination", function()
+                local path = tmpdir .. "/atomic.json"
+                local temp_path = path .. ".tmp-test"
+                vim.fn.writefile({ "durable" }, path)
+                local removed
+                local handle = {
+                    write = function()
+                        if stage == "write" then return nil, string.rep("secret", 100) end
+                        return true
+                    end,
+                    close = function()
+                        if stage == "close" then return nil, string.rep("secret", 100) end
+                        return true
+                    end,
+                }
+
+                local ok, err = helper.table_to_file_atomic({}, path, {
+                    temp_path = function() return temp_path end,
+                    open = function()
+                        vim.fn.writefile({ "partial" }, temp_path)
+                        return handle
+                    end,
+                    remove = function(candidate)
+                        removed = candidate
+                        return os.remove(candidate)
+                    end,
+                })
+
+                assert.is_false(ok)
+                assert.is_true(err:find(stage, 1, true) ~= nil)
+                assert.is_true(#err <= 240)
+                assert.equals(temp_path, removed)
+                assert.equals(0, vim.fn.filereadable(temp_path))
+                assert.same({ "durable" }, vim.fn.readfile(path))
+            end)
+        end
+
+        it("F8: rename failure removes partial output and preserves destination bytes", function()
+            local path = tmpdir .. "/atomic.json"
+            local temp_path = path .. ".tmp-test"
+            vim.fn.writefile({ "durable" }, path)
+
+            local ok, err = helper.table_to_file_atomic({ changed = true }, path, {
+                temp_path = function() return temp_path end,
+                rename = function() return nil, string.rep("secret", 100) end,
+            })
+
+            assert.is_false(ok)
+            assert.is_true(err:find("rename", 1, true) ~= nil)
+            assert.is_true(#err <= 240)
+            assert.equals(0, vim.fn.filereadable(temp_path))
+            assert.same({ "durable" }, vim.fn.readfile(path))
+        end)
     end)

     describe("Group G: prepare_dir", function()
diff --git a/tests/unit/keybindings_spec.lua b/tests/unit/keybindings_spec.lua
index fc92c25..b20add9 100644
--- a/tests/unit/keybindings_spec.lua
+++ b/tests/unit/keybindings_spec.lua
@@ -163,11 +163,31 @@ describe("key bindings help", function()
         assert.is_false(has_line(lines, "<C-g><C-g>", "Respond"))
     end)

-    it("chat context includes toggle tool folds", function()
+    it("chat context uses branch mnemonic and omits unconfigured tool folds", function()
         setup_parley()

         local lines = parley._keybinding_help_lines("chat")
-        assert.is_true(has_line(lines, "<C-g>b", "Toggle tool folds"))
+        assert.is_true(has_line(lines, "<C-g>b", "Prune"))
+        assert.is_false(has_line(lines, "<C-g>b", "Toggle tool folds"))
+        assert.is_false(has_line(lines, "", "Toggle tool folds"))
+    end)
+
+    it("shows a configured tool-fold shortcut through the shared registry", function()
+        setup_parley({
+            chat_shortcut_toggle_tool_folds = { modes = { "n" }, shortcut = "<leader>tf" },
+        })
+
+        local lines = parley._keybinding_help_lines("chat")
+        assert.is_true(has_line(lines, "<leader>tf", "Toggle tool folds"))
+    end)
+
+    it("treats an empty configured shortcut as unbound", function()
+        setup_parley({
+            chat_shortcut_toggle_tool_folds = { modes = { "n" }, shortcut = "" },
+        })
+
+        local lines = parley._keybinding_help_lines("chat")
+        assert.is_false(has_line(lines, "", "Toggle tool folds"))
     end)

     it("markdown context includes review shortcuts", function()
@@ -198,7 +218,10 @@ describe("keybinding registry", function()
         local reg = require("parley.keybinding_registry")
         for _, entry in ipairs(reg.entries) do
             assert.is_not_nil(entry.id, "entry missing id")
-            assert.is_not_nil(entry.default_key, "entry " .. entry.id .. " missing default_key")
+            assert.is_true(
+                entry.default_key ~= nil or entry.config_key ~= nil,
+                "entry " .. entry.id .. " missing default_key/config_key"
+            )
             assert.is_not_nil(entry.default_modes, "entry " .. entry.id .. " missing default_modes")
             assert.is_not_nil(entry.scope, "entry " .. entry.id .. " missing scope")
             assert.is_not_nil(entry.desc, "entry " .. entry.id .. " missing desc")
@@ -231,4 +254,45 @@ describe("keybinding registry", function()
         end
         assert.is_true(has_repo)
     end)
+
+    it("derives migrated bindings from exposed config without registry literals", function()
+        setup_parley()
+        local reg = require("parley.keybinding_registry")
+        local by_id = {}
+        for _, entry in ipairs(reg.entries) do by_id[entry.id] = entry end
+
+        for _, expected in ipairs({
+            { id = "super_repo_toggle", key = "<C-g>p", modes = { "n", "i" } },
+            { id = "chat_prune", key = "<C-g>b", modes = { "n" } },
+        }) do
+            local entry = by_id[expected.id]
+            assert.is_nil(entry.default_key)
+            local keys, modes = reg.resolve_keys(entry, parley.config)
+            assert.same({ expected.key }, keys)
+            assert.same(expected.modes, modes)
+        end
+
+        assert.is_nil(by_id.chat_toggle_tool_folds.default_key)
+        local tool_keys = reg.resolve_keys(by_id.chat_toggle_tool_folds, parley.config)
+        assert.is_nil(tool_keys)
+        assert.is_true(has_line(parley._keybinding_help_lines("other"), "<C-g>p", "super-repo"))
+        assert.is_true(has_line(parley._keybinding_help_lines("chat"), "<C-g>b", "Prune"))
+    end)
+
+    it("registers tool folds only when a non-empty shortcut is configured", function()
+        local reg = require("parley.keybinding_registry")
+        local calls = {}
+        local callbacks = { chat_toggle_tool_folds = function() end }
+        local function set_keymap(_, mode, key)
+            table.insert(calls, { mode = mode, key = key })
+        end
+
+        reg.register_buffer({ "chat" }, 1, {}, callbacks, set_keymap)
+        assert.same({}, calls)
+
+        reg.register_buffer({ "chat" }, 1, {
+            chat_shortcut_toggle_tool_folds = { modes = { "n" }, shortcut = "<leader>tf" },
+        }, callbacks, set_keymap)
+        assert.same({ { mode = "n", key = "<leader>tf" } }, calls)
+    end)
 end)
diff --git a/tests/unit/repo_mode_spec.lua b/tests/unit/repo_mode_spec.lua
new file mode 100644
index 0000000..06c2c78
--- /dev/null
+++ b/tests/unit/repo_mode_spec.lua
@@ -0,0 +1,58 @@
+local repo_mode = require("parley.repo_mode")
+
+describe("repo_mode.resolve", function()
+    it("selects only exact modes for a canonical repository root", function()
+        local modes = {
+            ["/workspace/a"] = "super_repo",
+            ["/workspace/b"] = "repo",
+            ["/workspace/c"] = "SUPER_REPO",
+        }
+
+        assert.equals("super_repo", repo_mode.resolve(modes, "/workspace/a"))
+        assert.equals("repo", repo_mode.resolve(modes, "/workspace/b"))
+        assert.is_nil(repo_mode.resolve(modes, "/workspace/c"))
+        assert.is_nil(repo_mode.resolve(modes, "/workspace/missing"))
+    end)
+
+    it("treats malformed maps and roots as unsaved", function()
+        assert.is_nil(repo_mode.resolve(nil, "/workspace/a"))
+        assert.is_nil(repo_mode.resolve("bad", "/workspace/a"))
+        assert.is_nil(repo_mode.resolve({}, nil))
+        assert.is_nil(repo_mode.resolve({}, ""))
+        assert.is_nil(repo_mode.resolve({}, 42))
+    end)
+end)
+
+describe("repo_mode.updated", function()
+    it("returns a fresh sanitized map with only the current root replaced", function()
+        local input = {
+            ["/workspace/a"] = "repo",
+            ["/workspace/b"] = "super_repo",
+            ["/workspace/invalid"] = "other",
+            [""] = "repo",
+            [42] = "repo",
+        }
+        local before = vim.deepcopy(input)
+
+        local result = repo_mode.updated(input, "/workspace/a", "super_repo")
+
+        assert.same({
+            ["/workspace/a"] = "super_repo",
+            ["/workspace/b"] = "super_repo",
+        }, result)
+        assert.same(before, input)
+        assert.is_not.equal(input, result)
+    end)
+
+    it("starts empty when the input map is malformed", function()
+        assert.same({ ["/workspace/a"] = "repo" }, repo_mode.updated("bad", "/workspace/a", "repo"))
+    end)
+
+    it("rejects invalid roots and modes without mutating the input", function()
+        local input = { ["/workspace/a"] = "repo" }
+
+        assert.same({ ["/workspace/a"] = "repo" }, repo_mode.updated(input, "", "super_repo"))
+        assert.same({ ["/workspace/a"] = "repo" }, repo_mode.updated(input, "/workspace/a", "other"))
+        assert.same({ ["/workspace/a"] = "repo" }, input)
+    end)
+end)
diff --git a/tests/unit/super_repo_spec.lua b/tests/unit/super_repo_spec.lua
index 0b127b8..8153d8e 100644
--- a/tests/unit/super_repo_spec.lua
+++ b/tests/unit/super_repo_spec.lua
@@ -241,6 +241,87 @@ describe("super_repo.toggle", function()
		assert.same(dirs(chat_before), dirs(parley.get_chat_roots()))
	end)

+	it("set_active is idempotent and does not persist preferences", function()
+		local writes = 0
+		local original_writer = parley.helpers.table_to_file_atomic
+		parley.helpers.table_to_file_atomic = function()
+			writes = writes + 1
+			return true
+		end
+
+		assert.is_true(parley.super_repo.set_active(true))
+		local chat_once = vim.deepcopy(parley.get_chat_roots())
+		assert.is_true(parley.super_repo.set_active(true))
+		assert.same(chat_once, parley.get_chat_roots())
+		assert.is_true(parley.super_repo.set_active(false))
+		assert.is_true(parley.super_repo.set_active(false))
+		parley.helpers.table_to_file_atomic = original_writer
+
+		assert.equals(0, writes)
+		assert.is_false(parley.is_super_repo_active())
+	end)
+
+	it("explicit toggles persist canonical per-repo choices in both directions", function()
+		parley._state.repo_modes = {
+			[resolve(sibling_a)] = "repo",
+			invalid = "other",
+		}
+
+		assert.is_true(parley.toggle_super_repo())
+		local on_state = assert(parley.helpers.file_to_table(state_dir .. "/state.json"))
+		assert.equals("super_repo", on_state.repo_modes[resolve(current_repo)])
+		assert.equals("repo", on_state.repo_modes[resolve(sibling_a)])
+		assert.is_nil(on_state.repo_modes.invalid)
+
+		assert.is_true(parley.toggle_super_repo())
+		local off_state = assert(parley.helpers.file_to_table(state_dir .. "/state.json"))
+		assert.equals("repo", off_state.repo_modes[resolve(current_repo)])
+		assert.equals("repo", off_state.repo_modes[resolve(sibling_a)])
+	end)
+
+	it("stores an explicit toggle under the canonical root", function()
+		local linked_repo = workspace .. "/parley-link"
+		assert((vim.uv or vim.loop).fs_symlink(current_repo, linked_repo))
+		parley.config.repo_root = linked_repo
+
+		assert.is_true(parley.toggle_super_repo())
+
+		assert.equals("super_repo", parley._state.repo_modes[resolve(current_repo)])
+		assert.is_nil(parley._state.repo_modes[linked_repo])
+	end)
+
+	it("failed activation changes neither runtime mode nor saved preference", function()
+		parley._state.repo_modes = { [resolve(current_repo)] = "repo" }
+		local before = vim.deepcopy(parley._state.repo_modes)
+		parley.config.repo_root = nil
+
+		assert.is_false(parley.toggle_super_repo())
+
+		assert.is_false(parley.is_super_repo_active())
+		assert.same(before, parley._state.repo_modes)
+	end)
+
+	it("keeps a successful runtime toggle when its preference cannot be saved", function()
+		local state_file = state_dir .. "/state.json"
+		local durable_before = table.concat(vim.fn.readfile(state_file), "\n")
+		local original_writer = parley.helpers.table_to_file_atomic
+		local original_warning = parley.logger.warning
+		local warnings = {}
+		parley.helpers.table_to_file_atomic = function() return false, "forced failure" end
+		parley.logger.warning = function(message) table.insert(warnings, message) end
+
+		local ok = parley.toggle_super_repo()
+		parley.helpers.table_to_file_atomic = original_writer
+		parley.logger.warning = original_warning
+
+		assert.is_true(ok)
+		assert.is_true(parley.is_super_repo_active())
+		assert.equals("super_repo", parley._state.repo_modes[resolve(current_repo)])
+		assert.equals(durable_before, table.concat(vim.fn.readfile(state_file), "\n"))
+		assert.equals(1, #warnings)
+		assert.is_true(warnings[1]:find("preference not saved", 1, true) ~= nil)
+	end)
+
	it("markdown_finder._scan_members aggregates with {repo} prefix and repo_name tag", function()
		local md_finder = require("parley.markdown_finder")
		md_finder.setup(parley)
@@ -385,6 +466,58 @@ describe("super_repo.toggle", function()
		assert.is_nil(persisted_note_set[resolve(sibling_b .. "/workshop/notes")])
	end)

+	it("persist_state writes a transient-safe snapshot without changing live overlay roots", function()
+		parley.toggle_super_repo()
+		parley._state.repo_modes = {
+			[resolve(current_repo)] = "super_repo",
+			[resolve(sibling_a)] = "repo",
+		}
+		parley._state.durable_probe = "kept"
+		local chat_before = vim.deepcopy(parley.get_chat_roots())
+		local note_before = vim.deepcopy(parley.get_note_roots())
+
+		local ok, err = parley.persist_state()
+
+		assert.is_true(ok)
+		assert.is_nil(err)
+		assert.same(chat_before, parley.get_chat_roots())
+		assert.same(note_before, parley.get_note_roots())
+		local persisted = assert(parley.helpers.file_to_table(state_dir .. "/state.json"))
+		assert.is_nil(persisted.chat_roots)
+		assert.is_nil(persisted.chat_dirs)
+		assert.equals("kept", persisted.durable_probe)
+		assert.same(parley._state.repo_modes, persisted.repo_modes)
+		for _, root in ipairs(persisted.note_roots or {}) do
+			assert.is_not.equal("repo", root.label)
+			assert.is_false(vim.tbl_contains(parley.super_repo.get_pushed_note_dirs(), resolve(root.dir)))
+		end
+	end)
+
+	it("persist_state reports writer failure after passing a sanitized snapshot", function()
+		parley.toggle_super_repo()
+		parley._state.repo_modes = { [resolve(current_repo)] = "super_repo" }
+		local chat_before = vim.deepcopy(parley.get_chat_roots())
+		local note_before = vim.deepcopy(parley.get_note_roots())
+		local captured
+		local original_writer = parley.helpers.table_to_file_atomic
+		parley.helpers.table_to_file_atomic = function(snapshot)
+			captured = vim.deepcopy(snapshot)
+			return false, "forced write failure"
+		end
+
+		local ok, err = parley.persist_state()
+		parley.helpers.table_to_file_atomic = original_writer
+
+		assert.is_false(ok)
+		assert.equals("forced write failure", err)
+		assert.is_not_nil(captured)
+		assert.is_nil(captured.chat_roots)
+		assert.is_nil(captured.chat_dirs)
+		assert.same(parley._state.repo_modes, captured.repo_modes)
+		assert.same(chat_before, parley.get_chat_roots())
+		assert.same(note_before, parley.get_note_roots())
+	end)
+
	it("lualine.format_mode returns glyph plus repo label for repo-backed modes", function()
		local lualine = require("parley.lualine")

@@ -571,3 +704,130 @@ describe("super_repo.toggle", function()
		assert.equal(2, fired)
	end)
 end)
+
+describe("super_repo startup restoration", function()
+	local function run_case(seed_modes, body, opts)
+		opts = opts or {}
+		local base = vim.fn.tempname() .. "-parley-super-repo-startup"
+		local workspace = base .. "/workspace"
+		local current = workspace .. "/current"
+		local sibling = workspace .. "/sibling"
+		local state_dir = base .. "/state"
+		local old_cwd = vim.fn.getcwd()
+
+		mkdir(current .. "/.git")
+		touch(current .. "/.parley")
+		touch(sibling .. "/.parley")
+		if opts.brain then mkdir(current .. "/.brain") end
+		local cwd = current
+		if opts.symlink then
+			cwd = workspace .. "/current-link"
+			assert((vim.uv or vim.loop).fs_symlink(current, cwd))
+		end
+		mkdir(state_dir)
+		if type(seed_modes) == "function" then
+			seed_modes = seed_modes({ current = current, sibling = sibling })
+		end
+		if seed_modes then
+			vim.fn.writefile({ vim.json.encode({ repo_modes = seed_modes }) }, state_dir .. "/state.json")
+		end
+
+		if parley.is_super_repo_active() then parley.super_repo.set_active(false) end
+		parley._state = {}
+		vim.cmd("cd " .. vim.fn.fnameescape(cwd))
+		local ok, err = pcall(body, {
+			base = base,
+			current = current,
+			sibling = sibling,
+			state_dir = state_dir,
+		})
+		if parley.is_super_repo_active() then parley.super_repo.set_active(false) end
+		vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
+		vim.fn.delete(base, "rf")
+		if not ok then error(err) end
+	end
+
+	it("restores saved super-repo mode once after the default-agent refresh", function()
+		run_case(function(ctx) return { [resolve(ctx.current)] = "super_repo" } end, function(ctx)
+			local writes = {}
+			local original_writer = parley.helpers.table_to_file_atomic
+			parley.helpers.table_to_file_atomic = function(snapshot, path, adapter)
+				table.insert(writes, vim.deepcopy(snapshot))
+				return original_writer(snapshot, path, adapter)
+			end
+
+			parley.setup({ state_dir = ctx.state_dir, default_agent = "GPT5.4", api_keys = {} })
+			parley.helpers.table_to_file_atomic = original_writer
+
+			assert.equals(2, #writes)
+			for _, snapshot in ipairs(writes) do
+				assert.equals("super_repo", snapshot.repo_modes[resolve(ctx.current)])
+			end
+			assert.is_true(parley.is_super_repo_active())
+			assert.equals(resolve(ctx.base .. "/workspace"), parley.config.super_repo_root)
+			assert.same({ "current", "sibling" }, names(parley.config.super_repo_members))
+			assert.is_true(vim.tbl_contains(dirs(parley.get_chat_roots()), resolve(ctx.sibling .. "/workshop/parley")))
+			assert.is_true(vim.tbl_contains(dirs(parley.get_note_roots()), resolve(ctx.sibling .. "/workshop/notes")))
+		end)
+	end)
+
+	it("leaves unsaved brain repositories in ordinary mode after VimEnter", function()
+		run_case(nil, function(ctx)
+			parley.setup({ state_dir = ctx.state_dir, default_agent = "GPT5.4", api_keys = {} })
+
+			assert.is_false(parley.is_super_repo_active())
+			vim.api.nvim_exec_autocmds("VimEnter", {})
+			assert.is_false(parley.is_super_repo_active())
+		end, { brain = true })
+	end)
+
+	it("ignores invalid preferences and honors an explicit repo preference", function()
+		for _, saved in ipairs({ "invalid", "repo" }) do
+			run_case(function(ctx) return { [resolve(ctx.current)] = saved } end, function(ctx)
+				parley.setup({ state_dir = ctx.state_dir, default_agent = "GPT5.4", api_keys = {} })
+				assert.is_false(parley.is_super_repo_active())
+			end, { brain = true })
+		end
+	end)
+
+	it("uses canonical roots and isolates another repository's saved choice", function()
+		run_case(function(ctx) return { [resolve(ctx.current)] = "super_repo" } end, function(ctx)
+			parley.setup({ state_dir = ctx.state_dir, default_agent = "GPT5.4", api_keys = {} })
+			assert.is_true(parley.is_super_repo_active())
+		end, { symlink = true })
+
+		run_case(function(ctx) return { [resolve(ctx.sibling)] = "super_repo" } end, function(ctx)
+			parley.setup({ state_dir = ctx.state_dir, default_agent = "GPT5.4", api_keys = {} })
+			assert.is_false(parley.is_super_repo_active())
+		end)
+	end)
+
+	it("keeps a saved super-repo preference when startup activation fails", function()
+		run_case(function(ctx) return { [resolve(ctx.current)] = "super_repo" } end, function(ctx)
+			local original_compute = parley.super_repo.compute_members
+			local original_warning = parley.logger.warning
+			local original_writer = parley.helpers.table_to_file_atomic
+			local warnings = {}
+			local writes = {}
+			parley.super_repo.compute_members = function() return nil, "forced activation failure" end
+			parley.logger.warning = function(message) table.insert(warnings, message) end
+			parley.helpers.table_to_file_atomic = function(snapshot, path, adapter)
+				table.insert(writes, vim.deepcopy(snapshot))
+				return original_writer(snapshot, path, adapter)
+			end
+
+			parley.setup({ state_dir = ctx.state_dir, default_agent = "GPT5.4", api_keys = {} })
+			parley.super_repo.compute_members = original_compute
+			parley.logger.warning = original_warning
+			parley.helpers.table_to_file_atomic = original_writer
+
+			assert.equals(2, #writes)
+			assert.is_false(parley.is_super_repo_active())
+			assert.equals("super_repo", parley._state.repo_modes[resolve(ctx.current)])
+			local persisted = assert(parley.helpers.file_to_table(ctx.state_dir .. "/state.json"))
+			assert.equals("super_repo", persisted.repo_modes[resolve(ctx.current)])
+			assert.equals(1, #warnings)
+			assert.is_true(warnings[1]:find("forced activation failure", 1, true) ~= nil)
+		end)
+	end)
+end)
diff --git a/workshop/plans/000190-persist-repo-super-repo-state-across-nvim-sessions-plan.md b/workshop/plans/000190-persist-repo-super-repo-state-across-nvim-sessions-plan.md
index cd2557e..2a234c4 100644
--- a/workshop/plans/000190-persist-repo-super-repo-state-across-nvim-sessions-plan.md
+++ b/workshop/plans/000190-persist-repo-super-repo-state-across-nvim-sessions-plan.md
@@ -68,27 +68,27 @@
 - Create: `tests/unit/repo_mode_spec.lua`
 - Modify: `atlas/traceability.yaml`

-- [ ] **Step 1: Write failing pure-policy tests**
+- [x] **Step 1: Write failing pure-policy tests**

 Cover `resolve(repo_modes, canonical_root)` returning `nil` for non-table maps, empty/non-string roots, missing entries, and unknown values; returning exact valid values; and keeping repo A isolated from repo B. Cover `updated(repo_modes, root, mode)` returning a fresh map, preserving only valid entries with non-empty string roots, discarding malformed entries, replacing the current root, starting empty for non-table input, and never mutating its input.

-- [ ] **Step 2: Run the focused test and verify RED**
+- [x] **Step 2: Run the focused test and verify RED**

 Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/repo_mode_spec.lua" -c "qa!"`

 Expected: FAIL because `parley.repo_mode` does not exist.

-- [ ] **Step 3: Implement the minimal pure module**
+- [x] **Step 3: Implement the minimal pure module**

 Create `repo_mode.resolve` and `repo_mode.updated` around one private exact-value predicate. Do not call `vim`, touch files, or mutate arguments. Add the module and unit spec to the existing `modes/super_repo` traceability entry.

-- [ ] **Step 4: Run the focused test and verify GREEN**
+- [x] **Step 4: Run the focused test and verify GREEN**

 Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/repo_mode_spec.lua" -c "qa!"`

 Expected: PASS with zero failures.

-- [ ] **Step 5: Commit the pure policy**
+- [x] **Step 5: Commit the pure policy**

 Commit: `super-repo: #190 add pure persisted-mode policy`

@@ -100,47 +100,47 @@ Commit: `super-repo: #190 add pure persisted-mode policy`
 - Modify: `lua/parley/init.lua`
 - Modify: `tests/unit/super_repo_spec.lua`

-- [ ] **Step 1: Write failing atomic-writer tests**
+- [x] **Step 1: Write failing atomic-writer tests**

 Add tests proving `table_to_file_atomic` returns true and round-trips nested JSON. Through an optional IO adapter, force write, close, and rename failures independently; each must return false plus a bounded error, remove its unique sibling temporary file, and preserve pre-existing destination bytes byte-for-byte. Encoding happens before any destination-adjacent file is opened, so an encode exception is inherently destination-safe and must also return a bounded failure.

-- [ ] **Step 2: Run helper IO tests and verify RED**
+- [x] **Step 2: Run helper IO tests and verify RED**

 Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/helper_io_spec.lua" -c "qa!"`

 Expected: FAIL because `table_to_file_atomic` is undefined.

-- [ ] **Step 3: Implement atomic replacement**
+- [x] **Step 3: Implement atomic replacement**

 Encode before opening, write to a unique sibling temporary path, check write/close outcomes, rename to the destination, remove the temporary file on every failure, and return a result. Keep legacy `table_to_file` behavior unchanged for unrelated consumers.

-- [ ] **Step 4: Run helper IO tests and verify GREEN**
+- [x] **Step 4: Run helper IO tests and verify GREEN**

 Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/helper_io_spec.lua" -c "qa!"`

 Expected: PASS with zero failures.

-- [ ] **Step 5: Write failing state-boundary regressions**
+- [x] **Step 5: Write failing state-boundary regressions**

 Add production-facing tests that call the wished-for `parley.persist_state()`: it must omit `chat_roots`/`chat_dirs`, repo-labeled and super-repo-pushed note roots; preserve durable scalar state and `repo_modes`; and leave the active overlay roots byte-for-byte unchanged. Add an injected writer-failure test asserting `(false, err)`, no root reload/mutation, and that the writer received the correctly sanitized snapshot before failing.

-- [ ] **Step 6: Run mapped state tests and verify RED**
+- [x] **Step 6: Run mapped state tests and verify RED**

 Run: `make test-spec SPEC=modes/super_repo`

 Expected: FAIL because `parley.persist_state` is undefined.

-- [ ] **Step 7: Extract and reuse the persistence boundary**
+- [x] **Step 7: Extract and reuse the persistence boundary**

 Move the snapshot/filter/write tail of `refresh_state` into `M.persist_state()`, returning the atomic writer result. Make `refresh_state` call it once after its load/update/root-restoration work. Keep display refresh in `refresh_state`, not the write-only function.

-- [ ] **Step 8: Run mapped state tests and verify GREEN**
+- [x] **Step 8: Run mapped state tests and verify GREEN**

 Run: `make test-spec SPEC=modes/super_repo`

 Expected: PASS with zero failures and unchanged live roots.

-- [ ] **Step 9: Commit the persistence boundary**
+- [x] **Step 9: Commit the persistence boundary**

 Commit: `state: #190 add atomic write-only persistence`

@@ -154,47 +154,47 @@ Commit: `state: #190 add atomic write-only persistence`
 - Modify: `tests/unit/super_repo_spec.lua`
 - Modify: `atlas/traceability.yaml`

-- [ ] **Step 1: Write failing runtime-transition tests**
+- [x] **Step 1: Write failing runtime-transition tests**

 Add tests for `super_repo.set_active(true|false)` being idempotent and non-persisting. Through `parley.toggle_super_repo`, assert successful on/off transitions update the current canonical root in `repo_modes`, preserve valid peer entries, and atomically persist; activation failure changes neither runtime state nor saved preference. Add a successful-runtime/failed-save regression starting from an existing state file: runtime and in-memory preference change, durable bytes remain identical, exactly one bounded warning contains “preference not saved,” and no success notification is emitted.

-- [ ] **Step 2: Run the super-repo spec and verify RED**
+- [x] **Step 2: Run the super-repo spec and verify RED**

 Run: `make test-spec SPEC=modes/super_repo`

 Expected: FAIL because `set_active` and toggle persistence are absent.

-- [ ] **Step 3: Implement explicit transition orchestration**
+- [x] **Step 3: Implement explicit transition orchestration**

 Export idempotent `super_repo.set_active(active)` as the non-persisting overlay API. Make `M.toggle_super_repo()` call the runtime toggle, update `M._state.repo_modes` through `repo_mode.updated` only on success, then call `M.persist_state`. On write failure, retain runtime mode and in-memory choice while emitting one bounded warning containing “preference not saved”; preserve the existing boolean runtime-transition return contract so callers do not misread persistence failure as transition failure.

-- [ ] **Step 4: Run the super-repo spec and verify GREEN**
+- [x] **Step 4: Run the super-repo spec and verify GREEN**

 Run: `make test-spec SPEC=modes/super_repo`

 Expected: PASS with zero failures.

-- [ ] **Step 5: Write failing production-path startup tests**
+- [x] **Step 5: Write failing production-path startup tests**

 Create temporary current/sibling repositories with `.parley`, pre-seed `state.json` under the configured state directory, supply a valid `default_agent`, and call real `parley.setup()`. Assert that setup returns with super-repo active, complete sibling chat/note roots, and member config; no later `VimEnter` is required. Spy on the atomic writer, account for the expected initial/default-agent refresh writes, assert every refresh payload preserves the saved preference, and prove restoration adds no writer call after `super_repo.set_active`. Add cases for unsaved default repo mode, explicit saved repo mode, per-repo isolation, canonical/symlink root lookup, invalid values, and an unsaved `.brain` repository remaining ordinary after setup plus synthetic `VimEnter`. For failed saved-super restoration, assert ordinary mode remains usable, the final saved preference remains `"super_repo"`, no post-transition write occurs, and exactly one bounded warning is emitted.

-- [ ] **Step 6: Run the startup tests and verify RED**
+- [x] **Step 6: Run the startup tests and verify RED**

 Run: `make test-spec SPEC=modes/super_repo`

 Expected: FAIL because setup does not restore saved preferences and still installs brain-specific `VimEnter` behavior.

-- [ ] **Step 7: Restore once after setup refreshes and remove brain treatment**
+- [x] **Step 7: Restore once after setup refreshes and remove brain treatment**

 Delete the `.brain` autocmd block. After the initial `refresh_state()` and optional default-agent `refresh_state(...)`, canonicalize `M.config.repo_root`, resolve its saved mode, and call `super_repo.set_active(mode == "super_repo")` exactly once for repo mode. Do nothing in global mode. A failed saved-super activation keeps the preference and uses the existing bounded warning path. Map the policy, state persistence, runtime transition, setup restoration, and toggle orchestration surfaces to `tests/unit/repo_mode_spec.lua`, `tests/unit/helper_io_spec.lua`, and `tests/unit/super_repo_spec.lua` in traceability.

-- [ ] **Step 8: Run the startup tests and verify GREEN**
+- [x] **Step 8: Run the startup tests and verify GREEN**

 Run: `make test-spec SPEC=modes/super_repo`

 Expected: PASS with zero failures; the default-agent case includes all sibling roots immediately on return.

-- [ ] **Step 9: Commit startup and toggle persistence**
+- [x] **Step 9: Commit startup and toggle persistence**

 Commit: `super-repo: #190 persist and restore peer mode`

@@ -208,11 +208,11 @@ Commit: `super-repo: #190 persist and restore peer mode`
 - Modify: `tests/unit/keybindings_spec.lua`
 - Modify: `tests/unit/config_tools_spec.lua`

-- [ ] **Step 1: Write failing registry and mapping tests**
+- [x] **Step 1: Write failing registry and mapping tests**

 Assert exposed config owns peer toggle `<C-g>p` in normal/insert and chat prune `<C-g>b` in normal, while tool-fold config is absent by default. Assert the three migrated registry entries carry no independent `default_key` and resolve solely from their `config_key`, so registration/help cannot drift from exposed config. Assert a configurable entry with no default is valid; absent or empty-string tool-fold configuration produces neither mapping nor help row; and a user config `{ modes = { "n" }, shortcut = "<leader>tf" }` restores both registration and help through the shared resolver.

-- [ ] **Step 2: Run keybinding tests and verify RED**
+- [x] **Step 2: Run keybinding tests and verify RED**

 Run: `make test-spec SPEC=ui/keybindings`

@@ -220,11 +220,11 @@ Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedF

 Expected: both fail on old exposed defaults, duplicated registry defaults, the mandatory `default_key` invariant, and configured tool-fold default.

-- [ ] **Step 3: Implement optional-default resolution and new defaults**
+- [x] **Step 3: Implement optional-default resolution and new defaults**

 Set peer and prune defaults only in `config.lua`. Remove `default_key` from all three migrated registry entries so their `config_key` is the sole resolution path; remove the tool-fold default config value while retaining registry modes, callback, and descriptions. Treat nil/empty shortcuts as unbound. Make help skip entries resolving to no key, while registration naturally skips them; require either `default_key` or `config_key` in the registry invariant. Add a drift test proving the peer/prune registration and help keys equal exposed config rather than a second registry literal (`ARCH-DRY`).

-- [ ] **Step 4: Run keybinding and config tests and verify GREEN**
+- [x] **Step 4: Run keybinding and config tests and verify GREEN**

 Run: `make test-spec SPEC=ui/keybindings`

@@ -232,7 +232,7 @@ Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedF

 Expected: both PASS with zero failures.

-- [ ] **Step 5: Commit the keybinding migration**
+- [x] **Step 5: Commit the keybinding migration**

 Commit: `keybindings: #190 use peer and branch mnemonics`

@@ -248,17 +248,17 @@ Commit: `keybindings: #190 use peer and branch mnemonics`
 - Modify: `workshop/issues/000190-persist-repo-super-repo-state-across-nvim-sessions.md`
 - Modify: `workshop/plans/000190-persist-repo-super-repo-state-across-nvim-sessions-plan.md`

-- [ ] **Step 1: Update every user-facing description**
+- [x] **Step 1: Update every user-facing description**

 Document `<C-g>p` as peer-mode toggle, `<C-g>b` as branch/prune, tool-fold as configurable with no default, per-canonical-repo persistence in `state.json`, ordinary unsaved default, synchronous startup restore, and brain parity. Add README discoverability for the peer toggle and configuration override.

-- [ ] **Step 2: Search for stale behavior and resolve every relevant hit**
+- [x] **Step 2: Search for stale behavior and resolve every relevant hit**

 Run: `rg -n '<C-g>S|Pruning \(`<C-g>p`\)|chat_shortcut_toggle_tool_folds.*<C-g>b|Brain repos auto|Toggle is transient|never persisted' README.md atlas lua tests`

 Expected: no stale assertions; fixture strings that intentionally test migration must be labeled as such or updated.

-- [ ] **Step 3: Run mapped tests and static checks**
+- [x] **Step 3: Run mapped tests and static checks**

 Before running mapped tests, confirm `atlas/traceability.yaml` maps optional-default registry/help behavior to `keybindings_spec.lua`, default-config migration to `config_tools_spec.lua`, repository-mode policy to `repo_mode_spec.lua`, atomic JSON writes to `helper_io_spec.lua`, and persistence/startup/toggle orchestration to `super_repo_spec.lua`. Extend the existing `modes/super_repo`, `ui/keybindings`, and `chat/lifecycle` entries and add an `infra/repo_mode` entry so every changed atlas file is mapped. Run these concrete selection checks and verify every intended test is selected:

@@ -278,19 +278,19 @@ Run: `git diff --check`

 Expected: all commands exit 0 with no failures or whitespace errors.

-- [ ] **Step 4: Run the full suite**
+- [x] **Step 4: Run the full suite**

 Run: `make test`

 Expected: exit 0 with zero failing tests.

-- [ ] **Step 5: Reconcile artifacts and commit**
+- [x] **Step 5: Reconcile artifacts and commit**

 Check every completed issue and durable-plan box, append implementation discoveries and exact verification evidence to `## Log`, and ensure atlas index/traceability stay consistent.

 Commit: `docs: #190 document persistent peer mode`

-- [ ] **Step 6: Prepare and invoke the close boundary**
+- [x] **Step 6: Prepare and invoke the close boundary**

 Run `sdlc actual --issue 190`, then `sdlc close --issue 190 --verified '<fresh mapped/full test, lint, diff-check, and smoke-test evidence>'`, using only the precise `--no-atlas`/other gate flag if the command identifies a genuinely inapplicable guard. Let `sdlc close` dispatch the mandatory fresh-context boundary review; fix all Critical/Important findings before shipping.



codex
I’m applying the repository’s `superpowers-using-superpowers` and `sdlc` checkpoint instructions, then I’ll inspect the issue/plan, actual diff, relevant surrounding code, and run focused verification. I’ll keep the review read-only and lead the final response with the required verdict block.
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

## 2026-07-12 (#170)
- **Core-concept tables must name greppable code entities and classify the whole named boundary, not its pure subset.** #170 called conceptual `PerfSampleSet`/`PerfReport` entities PURE even though their shared harness also owned the clock, timestamp, and Neovim JSON encoder. The close review correctly treated the contradiction as architectural. Rule: before close, resolve every Core-concept row to an actual symbol/module and inspect all side effects at that location; name a deterministic function separately from its INTEGRATION shell instead of assigning purity to a conceptual bundle.
- **A synchronous event contract must be tested through the production registration path, not an already-installed callback.** #170's lifecycle tests manually called `setup(buf)` before `BufEnter`, masking that the production classifier itself used `vim.schedule_wrap` and returned before setup; making entry direct then exposed a scheduled unload cleanup erasing classification after numeric handle reuse. Rule: for first-entry hydration, create a fresh unowned buffer, fire the real registered event, and assert state immediately on return; audit both setup and teardown wrappers for scheduling and exercise handle reuse before claiming synchronous convergence.
- **When making a shared event callback synchronous, classify each side effect by the contract that needs synchronization.** #170 needed immediate classification, diagnostics, and structure, but moving branch-reference topic refresh with them changed timer ownership/order and broke the timer-race oracle. Rule: trace every callback side effect before changing scheduling; keep unrelated timer/UI work deferred and add the full integration suite to the synchronization change's GREEN gate.

## 2026-07-13 (#182)
- **A public callback is an untrusted lifecycle boundary: complete cleanup independently, contain exceptions, and keep diagnostics bounded.** Task 2's first transport review found that throwing readers and terminal callbacks could skip pipe closure, handle removal, or completion events; the follow-up found that raw tracebacks could still create huge notifications or expose callback input. Rule: protect each independently promised callback surface, make resource cleanup unconditional, test a throwing callback at every lifecycle seam, and log only a generic or explicitly truncated diagnostic. Never include provider bodies, stderr, or arbitrary exception text in ordinary user-facing logs.
- **Call a process test “real” only when it actually crosses the OS process boundary.** A dispatcher test drove a captured tasker terminal callback but was named “real process failure,” obscuring that the real curl/SSE fixture belongs to a later boundary. Rule: reserve “real process” for tests that spawn the executable/fixture; name callback-driven coverage after the simulated terminal it exercises.
- **A state transition must retire every timer owned only by the state being left, including transitions that bypass the visible state.** Task 3 canceled playful timers for `showing → released` but missed the fast `waiting → released` path, leaking the startup idle timer; its frame tick also checked buffer validity but not lease ownership. Rule: enumerate every source phase for each destination and assert the complete live-timer set after the transition. Every recurring timer callback must revalidate both resource validity and logical ownership before touching UI.
- **Publish an object in a global ownership registry only after construction and injected validation succeed atomically.** Task 3 registered a chat session before its clock, verb chooser, and reducer initialization ran, so an initializer exception left an uncancellable half-object that blocked retries and crashed global cleanup. Rule: build and validate privately, install all terminal methods, then publish; test constructor exceptions followed by both retry and global cleanup.
- **A one-shot timer callback can arrive before a higher-resolution logical deadline; ignoring it without rearming strands the state forever.** Task 4's real curl stress run intermittently completed the provider response while the minimum-visible extmark remained forever because libuv's millisecond timer fired fractionally before an `hrtime` deadline. Rule: use one coherent clock for timers and deadlines or, whenever a deadline callback observes `now < due`, rearm the remaining duration. Stress the real process path repeatedly; one green timing run is not evidence.
- **Ending a presentation controller is not the same as completing its caller's lifecycle.** Task 4 initially let cancel/stale/invalid finish the extmark controller while skipping the chat shell collapse, lifecycle finalization, and lease release; the later transport error was correctly ignored and therefore could not rescue cleanup. Rule: every terminal class needs an explicit exact-once owner at each layer. UI discard hooks must release caller-owned resources without surfacing staged output or errors.
- **Ownership conflicts must be rejected before durable mutation, including force/bypass paths.** Task 4's force respond bypassed the busy guard, inserted a second response shell, began a lease, and only then collided with the existing per-buffer presentation registry. Rule: preflight every independently owned resource before transcript/model writes; tests for force or bypass flags must assert both the error result and byte-for-byte unchanged durable state.
- **A centralized `finish` closure provides no safety unless every fallible operation before it is protected and converges into it.** Task 5 made skill terminals exact-once, but malformed tool decoding/execution could still throw inside the scheduled completion pipeline before `finish`, stranding `_in_flight`, detached progress, and Definition's inline spinner. Rule: wrap the whole asynchronous completion body—not only callbacks—in a protected boundary; on exception log bounded metadata and call the same terminal owner. Test with malformed provider output that reaches real decode/dispatch code.
- **A generic lifecycle test does not prove a consumer-owned transient UI seam.** Task 5's invocation table covered source failure, no agent, buffer deletion, and no-tool output, but the first Definition suite did not assert its inline spinner/timer and footnote state on those same terminals. Rule: for every consumer that supplies an `on_terminal` cleanup hook, run each materially distinct terminal through the real consumer entry and assert its owned UI/resource is gone; keep one late/repeated delivery case at that seam.
- **Registering a terminal owner turns every later synchronous setup operation into part of that lifecycle.** The #182 close review found that payload assembly, decoration clearing, root-policy construction, or progress startup could throw after `skill_invoke` installed Definition cleanup but before dispatch, leaking the inline spinner and ownership registry. Rule: once terminal ownership is published, run the entire remaining synchronous setup region inside one protected boundary that converges through the terminal; add a real consumer-entry test with an injected setup throw, not only async completion failures.
- **A failed review sidecar must not make its own re-review window unreviewable.** #182's generated REWORK sidecar embedded the full prompt, diff, and test output; committing its 11,000 lines put that transcript back into the next whole-window diff and exhausted the reviewer before it could emit a verdict. Rule: before committing a failed-review sidecar that will be included in the immediate re-review window, compact generated bulk to durable metadata, actionable findings, resolutions, and evidence while preserving the verdict; let the successful re-review append its fresh record.
- **An extmark update must repaint at the mark's live tracked position, not its creation coordinates.** #182 correctly used extmarks for transient progress, but each animation tick passed the original row/column back to `nvim_buf_set_extmark`, snapping marks backward after edits above their anchors. Rule: creation owns initial coordinates; every later repaint first resolves `nvim_buf_get_extmark_by_id`, stops on missing/invalid marks, and updates at the returned position. Test by moving text before the live mark and then forcing a frame or semantic repaint.

## 2026-07-13 (#183)

- **Repair authorization for a writer-invalidated UI anchor must be established immediately before mutation and consumed in the same uninterrupted callback.** #183 intentionally placed progress on the mutable stream tip, whose replacement invalidates its extmark. A first implementation repaired any missing mark afterward, which could revive one invalidated earlier by an external edit. Rule: validate the live mark immediately before the write, grant a one-use authorization, then mutate and relocate synchronously; never infer the cause of invalidation after the fact. Test both expected writer invalidation and pre-existing external invalidation through the real queued stream path.
- **Normalize generated boundary-review sidecars before committing them.** The #183 re-review produced an 18,000-line raw terminal transcript with ANSI escapes and trailing whitespace, obscuring the actual verdict and failing `git diff --check`. Rule: retain durable metadata, findings, resolutions, and evidence in a concise sidecar; discard terminal plumbing and run `git diff --check` on the whole review window before publishing.

## 2026-07-13 (#184)

- **An “exactly once” requirement needs a cardinality oracle, not a presence oracle.** The folded-recursion regression proved staged output appeared after the spinner minimum, but `buffer_contains` would also pass if the release duplicated that output. Rule: when the contract says once/exactly-once/idempotent, count occurrences or assert the exact resulting sequence after the terminal transition.

## 2026-07-14 (#168)

- **A mapped native operation needs production assertions for every promised count/direction seam and for its ordering boundary.** Unit policy tests proved confirmation choices, while the first production cut only counted undo and checked cleanup after uncounted confirmation. That left counted redo and mutation-before-retirement unenforced. Rule: when thin keymap glue captures counts or uses different execution mechanisms per direction, drive each mapping with counts, assert the exact history result, and observe state inside the next lifecycle stage—not only after the transaction returns.
- **Resource cleanup and operation success are separate results.** The scoped tasker stop correctly partitioned handles even when signaling failed, but `pcall` discarded the failure, preventing the guarded transaction from surfacing its bounded generic error. Rule: complete deterministic ownership cleanup, then propagate a sanitized failure signal to the protected orchestration boundary; never equate “record removed” with “external operation succeeded.”
- **A protected external call must test both exceptions and the API's documented failure return.** The first scoped-stop regression modeled `kill` throwing, but real libuv returns `nil, message, code` for `EPERM`/`ESRCH`; `pcall` therefore succeeded and the failure stayed hidden. Rule: inspect the production API's success sentinel inside the protected call and test a non-throwing failure tuple as well as an exception.

## 2026-07-14 (#186)

- **Durable plan checkboxes are boundary evidence, not optional bookkeeping.** The implementation, tests, issue Plan, and Log were complete, but the close review correctly refused to ship while the detailed plan still presented every step as pending. Rule: immediately before `sdlc close`, reconcile every durable-plan checkbox against commits and verification; leave only genuinely pending boundary or publish work unchecked.
- **Core-concept tables must name symbols a reviewer can grep at their stated locations.** #186 described accurate architectural roles but labeled them with conceptual CamelCase entities that did not exist in Lua, making the plan/code cross-check fail despite correct behavior. Rule: name actual module exports, scoped entry points, local helpers, or state paths in the table; keep explanatory concepts in the prose below it.

## 2026-07-15 (#188)

- **A close-gate checkbox must describe readiness/invocation, while the revision
  log records the verdict chronology.** `sdlc close` requires every plan box to
  be checked before it dispatches the review, so wording such as “successfully
  crossed” creates an impossible truth window and can contradict an earlier
  REWORK revision. Rule: name the pre-gate step “prepare and invoke the close
  boundary”; after the verdict, append the outcome and status transition instead
  of making historical revision prose sound like current state.

  → Read issue, durable plan, architecture principles, and review-window metadata
  • Inspect changed code and surrounding consumers against Spec/Plan
  • Run focused tests, full-suite/static evidence as practical, and stale-surface searches
  • Classify findings and produce the machine-readable boundary verdict
exec
/bin/zsh -lc "sdlc arch-principles && sed -n '1,320p' workshop/issues/000190-persist-repo-super-repo-state-across-nvim-sessions.md && sed -n '1,360p' workshop/plans/000190-persist-repo-super-repo-state-across-nvim-sessions-plan.md && git status --short && git log --oneline --decorate ac2706896b00ddb30e3ab229674c671f604c4a4f..HEAD && git diff --stat ac2706896b00ddb30e3ab229674c671f604c4a4f..HEAD && git diff --check ac2706896b00ddb30e3ab229674c671f604c4a4f..HEAD" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
ARCHITECTURE PRINCIPLES — work through each of the 3 entries below explicitly, applying its `at-plan` lens; cite the marker (e.g. ARCH-DRY) in any finding.

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

---
id: 000190
status: working
deps: []
github_issue:
created: 2026-07-15
updated: 2026-07-15
estimate_hours: 2.75
started: 2026-07-15T12:00:53-07:00
---

# persist repo super-repo state across nvim sessions

## Problem

Repo mode is derived from the current `.parley` repository, but super-repo mode
is a transient overlay. A user who prefers peer aggregation for one repository
must re-enable it in every Neovim session. Brain repositories currently receive
a separate automatic super-repo rule, so startup behavior depends on repository
type rather than the user's explicit choice.

The mode toggle also uses `<C-g>S`, while the desired mnemonic is `<C-g>p` for
“peer.” That key is currently used by chat pruning, and the agreed replacement
`<C-g>b` is currently used by the optional tool-fold toggle.

## Spec

- Persist an explicit mode preference per `.parley` repository in Parley's
  existing `state.json`. The stored shape is a `repo_modes` map from canonical,
  resolved repository-root paths to exactly `"repo"` or `"super_repo"`.
- A repository with no saved entry starts in ordinary repo mode. Global mode
  outside a `.parley` repository remains unchanged and does not create a
  preference.
- Remove all `.brain`-specific startup behavior. Brain repositories follow the
  same saved-preference/default rules as every other `.parley` repository; a
  saved ordinary-repo choice therefore overrides the former automatic overlay.
- Restore a saved `"super_repo"` preference only after repo-local chat/note
  roots and persisted state have settled. Restoration activates the existing
  super-repo overlay before normal use without rewriting the preference.
- After all setup-time state refreshes have completed, including the optional
  default-agent refresh, `setup()` synchronously resolves and applies the saved
  mode exactly once before returning. Restoration must not depend on a future
  `VimEnter` event and must use a non-persisting activation path.
- A successful user toggle immediately records the resulting mode for the
  current canonical repo root. Toggling on records `"super_repo"`; toggling off
  records `"repo"`. Failed activation leaves both the runtime mode and saved
  preference unchanged.
- Unknown values, malformed maps, or entries for other repositories are ignored
  without error. If a valid saved super-repo preference cannot be activated,
  Parley remains usable in ordinary repo mode, keeps the saved preference for a
  future session, and uses the existing bounded warning path.
- Selection treats a non-table `repo_modes` value as empty and recognizes only
  exact `"repo"`/`"super_repo"` values for the current canonical root. Updating
  a malformed map starts from empty; otherwise it returns a fresh map that
  preserves entries for other non-empty string roots only when their value is
  valid, discards invalid entries, and replaces only the current root. It never
  mutates the caller's map.
- Keep runtime roots transient: `chat_roots`, `chat_dirs`, and super-repo-pushed
  note roots must remain absent from persisted state. Extract the current state
  serialization/write policy into one reusable write-only boundary so saving a
  mode preference does not run the full state reload/root-restoration path
  (`ARCH-DRY`, `ARCH-PURE`).
- The write-only state boundary reports success/failure and replaces
  `state.json` atomically, so a failed preference save leaves the previous
  durable file intact. If the runtime transition succeeds but persistence
  fails, keep the resulting runtime mode, keep the last durable preference,
  and emit one bounded warning that explicitly says the preference was not
  saved; do not report persistence success.
- Keep preference selection/updates in a small deterministic core: resolving a
  mode from `(repo_modes, canonical_root)` and returning an updated fresh map
  must not mutate callers. Neovim filesystem resolution and JSON IO stay in the
  adapter (`ARCH-PURE`).
- Change the global peer-mode toggle default from `<C-g>S` to `<C-g>p` in normal
  and insert mode. Change chat branch/prune from `<C-g>p` to `<C-g>b` in normal
  mode. Remove the default key for `chat_shortcut_toggle_tool_folds`; users may
  still assign that configurable action their own shortcut.
- Extend the shared keybinding registry to support configured actions with no
  default shortcut. An unconfigured tool-fold action registers no mapping and
  appears in no keybinding-help row; a non-empty user shortcut registers and is
  displayed through the existing registry path, with the callback unchanged
  (`ARCH-DRY`).
- Update help, README, and atlas descriptions so “peer,” persistence, default
  behavior, brain parity, and the two keybinding migrations agree with code
  (`ARCH-PURPOSE`).

## Done when

- A repo explicitly left in super-repo mode reopens in super-repo mode in a new
  Neovim setup/session, while another repo with no preference opens in repo mode.
- A production-path setup test pre-seeds `state.json`, supplies a default agent,
  calls `setup()` without a future `VimEnter` trigger, and observes both active
  super-repo mode and the complete live sibling chat/note overlay immediately
  on return. An unsaved `.brain` repo remains in repo mode both after setup and
  after a synthetic `VimEnter`.
- Toggling back to repo mode persists and prevents a later session—including in
  a brain repo—from auto-enabling super-repo mode.
- Mode persistence never restores transient sibling chat/note roots from disk
  and never disturbs the live overlay while saving a toggle.
- Invalid stored preferences and failed restoration degrade to ordinary repo
  mode without corrupting the stored map.
- Mixed valid/invalid maps preserve other valid repo choices while discarding
  invalid entries; a write-failure regression proves the runtime transition,
  unchanged durable file, and one bounded “preference not saved” warning.
- `<C-g>p` toggles peer aggregation, `<C-g>b` branches/prunes a chat, and the
  tool-fold action has no default collision.
- With no configured tool-fold shortcut, neither a mapping nor help row exists;
  assigning one restores both through the shared registry.
- Automated tests cover per-repo isolation, canonical-root lookup, immutable
  preference updates, first-run defaulting, startup restoration, toggle-on/off
  persistence, brain parity, failure preservation, transient-root filtering,
  and the keybinding defaults.

## Plan

- [x] Add the pure per-repo mode-preference policy and focused tests.
- [x] Extract reusable state serialization and integrate startup/toggle
  persistence without reloading live roots.
- [x] Migrate the peer, branch, and tool-fold keybinding defaults with collision
  regressions.
- [x] Reconcile user-facing and atlas documentation; run mapped and full tests.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.50 impl=1.60
item: atlas-docs design=0.15 impl=0.20
item: milestone-review design=0.00 impl=0.20
design-buffer: 0.15
total: 2.75
```

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md`
against `baseline-v3.1.md`. Method A only.*

## Log

### 2026-07-15

- Claimed before design. The approved direction stores a canonical-root-keyed
  `repo_modes` map in existing state rather than modifying `.parley` or adding
  per-repo files. Ordinary repo mode is the unsaved default; explicit choices
  win uniformly, so the brain-only auto-enable path is removed.
- Keybinding design: `<C-g>p` becomes the peer overlay toggle, `<C-g>b` becomes
  branch/prune, and tool-fold toggling remains configurable without a default.
- Root-cause inspection found that calling the full `refresh_state()` after a
  successful activation could restore pre-overlay note roots. The design
  therefore reuses one extracted write-only persistence policy instead of
  reloading state while saving the scalar preference (`ARCH-DRY`, `ARCH-PURE`).
- The first code-change gate rejected duplicated keybinding ownership. For the
  migrated configurable actions, `config.lua` now remains the sole default
  source and registry registration/help derive through `config_key`
  (`ARCH-DRY`).
- Implemented a pure `repo_mode` policy plus one atomic, write-only state
  boundary. Explicit peer-mode toggles now persist only after successful
  runtime transitions, while a failed save keeps the live choice and preserves
  the prior durable file.
- Startup now applies the saved canonical-repo preference once, after all state
  refreshes, through an idempotent non-persisting overlay transition. Removed
  the `.brain` startup exception so unsaved brain repositories follow the same
  ordinary-repo default as every peer.
- Migrated peer toggle to `<C-g>p` and chat branch/prune to `<C-g>b`. Tool-fold
  toggling remains configurable but intentionally has no default mapping or
  help row; registry resolution and exposed config share one source of truth.
- Verification: exact traceability selections for `modes/super_repo`,
  `ui/keybindings`, `infra/repo_mode`, and `chat/lifecycle`; `make
  test-changed`; `make lint` (0 warnings/errors in 275 files); `git diff
  --check`; and `make test JOBS=1` all exited 0. The first parallel full-suite
  run exposed a pre-existing ready-file race in
  `chat_progress_process_spec.lua`; the unchanged test passed three isolated
  repetitions and the complete reduced-parallelism rerun.

## Revisions

### 2026-07-15 — fresh-context spec review

- Reason: review found implementation-defining ambiguity in startup timing,
  optional keybinding/help semantics, mixed-map sanitization, and persistence
  write failure.
- Delta: made restoration synchronous before `setup()` returns; defined one
  registry path for configurable unbound actions; specified immutable map
  filtering; and required atomic, result-bearing state writes with bounded
  failure behavior and production-path regressions.

### 2026-07-15 — startup sequencing correction

- Reason: follow-up review found that restoring after each setup refresh could
  let the optional default-agent refresh replace live overlay roots while the
  super-repo state still appeared active.
- Delta: require exactly one restoration after all setup refreshes and verify
  the complete live sibling chat/note overlay in the default-agent setup path.

### 2026-07-15 — implementation planning

- Reason: the approved multi-file behavior needs a durable, test-first execution
  record before crossing the code-change gate.
- Delta: added the reconciled v3.1 estimate and detailed implementation plan at
  `workshop/plans/000190-persist-repo-super-repo-state-across-nvim-sessions-plan.md`.

### 2026-07-15 — code-gate architecture refinement

- Reason: plan-quality review found that changing defaults independently in
  config and registry would preserve two authoritative definitions.
- Delta: make config the sole owner for migrated configurable defaults; registry
  registration/help derive them through `config_key`, with a drift regression.
# Persistent Repo/Super-Repo Mode Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist each repository's explicit repo/peer mode choice, restore it synchronously at startup, remove brain-only behavior, and migrate the peer/branch keybindings without a tool-fold collision.

**Architecture:** A new pure `repo_mode` module owns validation, selection, and immutable updates of the canonical-root-keyed preference map. `init.lua` owns orchestration: it serializes transient-safe state through one atomic write-only boundary, restores mode once after all setup refreshes, and persists only successful explicit toggles. For migrated configurable actions, `config.lua` is the sole default owner; the existing keybinding registry derives registration/help through `config_key` and gains optional-default resolution so one action may intentionally remain unbound.

**Tech Stack:** Lua, Neovim APIs, plenary/busted tests, Markdown atlas/docs.

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `repo_mode.resolve` | `lua/parley/repo_mode.lua` | new |
| `repo_mode.updated` | `lua/parley/repo_mode.lua` | new |
| `keybinding_registry.resolve_keys` | `lua/parley/keybinding_registry.lua` | modified |

- **`repo_mode.resolve`** — selects only exact `repo`/`super_repo` values for one already-canonical repository root.
  - **Relationships:** N:1 preferences-to-repository map lookup; the caller owns the map and canonical root.
  - **DRY rationale:** Startup restoration and toggle persistence must share one validity rule.
  - **Future extensions:** Additional explicitly modeled repo modes widen the allowed-value set here.
- **`repo_mode.updated`** — returns a fresh sanitized preference map with one repository choice replaced.
  - **Relationships:** one input map produces one independent output map; valid entries for other roots are preserved.
  - **DRY rationale:** Both toggle directions need identical immutable filtering and replacement.
  - **Future extensions:** Migration/version policy can be added without coupling it to Neovim IO.
- **`keybinding_registry.resolve_keys`** — resolves configured shortcuts while allowing an entry to have no default key.
  - **Relationships:** one registry entry plus one config table resolves to zero-or-more keys and modes.
  - **DRY rationale:** Registration and help already consume this single resolver; teaching it the unbound state prevents parallel special cases.
  - **Future extensions:** Other opt-in actions can use the same optional-default contract.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `helper.table_to_file_atomic` | `lua/parley/helper.lua` | new | JSON encoding, temporary-file IO, atomic rename |
| `parley.persist_state` | `lua/parley/init.lua` | new | live state sanitization and `state.json` persistence |
| `parley.setup` mode restoration | `lua/parley/init.lua` | modified | setup ordering, canonical filesystem roots, saved preference |
| `parley.toggle_super_repo` | `lua/parley/init.lua` | modified | runtime overlay transition, durable preference, bounded warning |
| `super_repo.set_active` | `lua/parley/super_repo.lua` | new | non-persisting runtime overlay activation/deactivation |

- **`helper.table_to_file_atomic`** — writes encoded JSON beside the destination, renames only after a complete close, reports `(true)` or `(false, err)`, and leaves the prior file intact on failure.
  - **Injected into:** `parley.persist_state` through `M.helpers`, allowing failure tests to substitute a deterministic fake.
  - **Future extensions:** Other durable JSON stores can opt into atomic replacement without changing legacy `table_to_file` consumers.
- **`parley.persist_state`** — builds the single transient-safe state snapshot and sends it to the atomic writer without reloading disk state or live roots.
  - **Injected into:** `refresh_state` and explicit peer-mode toggle persistence.
  - **Future extensions:** Additional transient fields are filtered at this one policy boundary.
- **`parley.setup` mode restoration** — after the base and optional default-agent refreshes, resolves the canonical current repo preference and calls the non-persisting runtime transition exactly once.
  - **Injected into:** normal plugin setup; production-path tests use real temporary repositories and `state.json`.
  - **Future extensions:** Setup migrations remain ordered before this final mode application.
- **`parley.toggle_super_repo`** — persists the resulting preference only after a successful explicit runtime transition; persistence failure keeps runtime state and warns once.
  - **Injected into:** public Lua API and the existing global keybinding callback.
  - **Future extensions:** Commands or status UI continue calling the same public transition.
- **`super_repo.set_active`** — exposes idempotent activation/deactivation without owning preference IO.
  - **Injected into:** setup restoration and explicit toggle orchestration.
  - **Future extensions:** Additional restoration callers avoid impersonating a user toggle.

## Chunk 1: Pure preference and durable state boundaries

### Task 1: Add the pure repository-mode policy

**Files:**
- Create: `lua/parley/repo_mode.lua`
- Create: `tests/unit/repo_mode_spec.lua`
- Modify: `atlas/traceability.yaml`

- [x] **Step 1: Write failing pure-policy tests**

Cover `resolve(repo_modes, canonical_root)` returning `nil` for non-table maps, empty/non-string roots, missing entries, and unknown values; returning exact valid values; and keeping repo A isolated from repo B. Cover `updated(repo_modes, root, mode)` returning a fresh map, preserving only valid entries with non-empty string roots, discarding malformed entries, replacing the current root, starting empty for non-table input, and never mutating its input.

- [x] **Step 2: Run the focused test and verify RED**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/repo_mode_spec.lua" -c "qa!"`

Expected: FAIL because `parley.repo_mode` does not exist.

- [x] **Step 3: Implement the minimal pure module**

Create `repo_mode.resolve` and `repo_mode.updated` around one private exact-value predicate. Do not call `vim`, touch files, or mutate arguments. Add the module and unit spec to the existing `modes/super_repo` traceability entry.

- [x] **Step 4: Run the focused test and verify GREEN**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/repo_mode_spec.lua" -c "qa!"`

Expected: PASS with zero failures.

- [x] **Step 5: Commit the pure policy**

Commit: `super-repo: #190 add pure persisted-mode policy`

### Task 2: Add atomic JSON replacement and one write-only state boundary

**Files:**
- Modify: `lua/parley/helper.lua`
- Modify: `tests/unit/helper_io_spec.lua`
- Modify: `lua/parley/init.lua`
- Modify: `tests/unit/super_repo_spec.lua`

- [x] **Step 1: Write failing atomic-writer tests**

Add tests proving `table_to_file_atomic` returns true and round-trips nested JSON. Through an optional IO adapter, force write, close, and rename failures independently; each must return false plus a bounded error, remove its unique sibling temporary file, and preserve pre-existing destination bytes byte-for-byte. Encoding happens before any destination-adjacent file is opened, so an encode exception is inherently destination-safe and must also return a bounded failure.

- [x] **Step 2: Run helper IO tests and verify RED**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/helper_io_spec.lua" -c "qa!"`

Expected: FAIL because `table_to_file_atomic` is undefined.

- [x] **Step 3: Implement atomic replacement**

Encode before opening, write to a unique sibling temporary path, check write/close outcomes, rename to the destination, remove the temporary file on every failure, and return a result. Keep legacy `table_to_file` behavior unchanged for unrelated consumers.

- [x] **Step 4: Run helper IO tests and verify GREEN**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/helper_io_spec.lua" -c "qa!"`

Expected: PASS with zero failures.

- [x] **Step 5: Write failing state-boundary regressions**

Add production-facing tests that call the wished-for `parley.persist_state()`: it must omit `chat_roots`/`chat_dirs`, repo-labeled and super-repo-pushed note roots; preserve durable scalar state and `repo_modes`; and leave the active overlay roots byte-for-byte unchanged. Add an injected writer-failure test asserting `(false, err)`, no root reload/mutation, and that the writer received the correctly sanitized snapshot before failing.

- [x] **Step 6: Run mapped state tests and verify RED**

Run: `make test-spec SPEC=modes/super_repo`

Expected: FAIL because `parley.persist_state` is undefined.

- [x] **Step 7: Extract and reuse the persistence boundary**

Move the snapshot/filter/write tail of `refresh_state` into `M.persist_state()`, returning the atomic writer result. Make `refresh_state` call it once after its load/update/root-restoration work. Keep display refresh in `refresh_state`, not the write-only function.

- [x] **Step 8: Run mapped state tests and verify GREEN**

Run: `make test-spec SPEC=modes/super_repo`

Expected: PASS with zero failures and unchanged live roots.

- [x] **Step 9: Commit the persistence boundary**

Commit: `state: #190 add atomic write-only persistence`

## Chunk 2: Startup restoration and explicit toggle persistence

### Task 3: Restore and persist mode through production orchestration

**Files:**
- Modify: `lua/parley/super_repo.lua`
- Modify: `lua/parley/init.lua`
- Modify: `tests/unit/super_repo_spec.lua`
- Modify: `atlas/traceability.yaml`

- [x] **Step 1: Write failing runtime-transition tests**

Add tests for `super_repo.set_active(true|false)` being idempotent and non-persisting. Through `parley.toggle_super_repo`, assert successful on/off transitions update the current canonical root in `repo_modes`, preserve valid peer entries, and atomically persist; activation failure changes neither runtime state nor saved preference. Add a successful-runtime/failed-save regression starting from an existing state file: runtime and in-memory preference change, durable bytes remain identical, exactly one bounded warning contains “preference not saved,” and no success notification is emitted.

- [x] **Step 2: Run the super-repo spec and verify RED**

Run: `make test-spec SPEC=modes/super_repo`

Expected: FAIL because `set_active` and toggle persistence are absent.

- [x] **Step 3: Implement explicit transition orchestration**

Export idempotent `super_repo.set_active(active)` as the non-persisting overlay API. Make `M.toggle_super_repo()` call the runtime toggle, update `M._state.repo_modes` through `repo_mode.updated` only on success, then call `M.persist_state`. On write failure, retain runtime mode and in-memory choice while emitting one bounded warning containing “preference not saved”; preserve the existing boolean runtime-transition return contract so callers do not misread persistence failure as transition failure.

- [x] **Step 4: Run the super-repo spec and verify GREEN**

Run: `make test-spec SPEC=modes/super_repo`

Expected: PASS with zero failures.

- [x] **Step 5: Write failing production-path startup tests**

Create temporary current/sibling repositories with `.parley`, pre-seed `state.json` under the configured state directory, supply a valid `default_agent`, and call real `parley.setup()`. Assert that setup returns with super-repo active, complete sibling chat/note roots, and member config; no later `VimEnter` is required. Spy on the atomic writer, account for the expected initial/default-agent refresh writes, assert every refresh payload preserves the saved preference, and prove restoration adds no writer call after `super_repo.set_active`. Add cases for unsaved default repo mode, explicit saved repo mode, per-repo isolation, canonical/symlink root lookup, invalid values, and an unsaved `.brain` repository remaining ordinary after setup plus synthetic `VimEnter`. For failed saved-super restoration, assert ordinary mode remains usable, the final saved preference remains `"super_repo"`, no post-transition write occurs, and exactly one bounded warning is emitted.

- [x] **Step 6: Run the startup tests and verify RED**

Run: `make test-spec SPEC=modes/super_repo`

Expected: FAIL because setup does not restore saved preferences and still installs brain-specific `VimEnter` behavior.

- [x] **Step 7: Restore once after setup refreshes and remove brain treatment**

Delete the `.brain` autocmd block. After the initial `refresh_state()` and optional default-agent `refresh_state(...)`, canonicalize `M.config.repo_root`, resolve its saved mode, and call `super_repo.set_active(mode == "super_repo")` exactly once for repo mode. Do nothing in global mode. A failed saved-super activation keeps the preference and uses the existing bounded warning path. Map the policy, state persistence, runtime transition, setup restoration, and toggle orchestration surfaces to `tests/unit/repo_mode_spec.lua`, `tests/unit/helper_io_spec.lua`, and `tests/unit/super_repo_spec.lua` in traceability.

- [x] **Step 8: Run the startup tests and verify GREEN**

Run: `make test-spec SPEC=modes/super_repo`

Expected: PASS with zero failures; the default-agent case includes all sibling roots immediately on return.

- [x] **Step 9: Commit startup and toggle persistence**

Commit: `super-repo: #190 persist and restore peer mode`

## Chunk 3: Optional keybindings, documentation, and verification

### Task 4: Migrate peer/branch defaults and make tool folds opt-in

**Files:**
- Modify: `lua/parley/config.lua`
- Modify: `lua/parley/keybinding_registry.lua`
- Modify: `tests/unit/keybindings_spec.lua`
- Modify: `tests/unit/config_tools_spec.lua`

- [x] **Step 1: Write failing registry and mapping tests**

Assert exposed config owns peer toggle `<C-g>p` in normal/insert and chat prune `<C-g>b` in normal, while tool-fold config is absent by default. Assert the three migrated registry entries carry no independent `default_key` and resolve solely from their `config_key`, so registration/help cannot drift from exposed config. Assert a configurable entry with no default is valid; absent or empty-string tool-fold configuration produces neither mapping nor help row; and a user config `{ modes = { "n" }, shortcut = "<leader>tf" }` restores both registration and help through the shared resolver.

- [x] **Step 2: Run keybinding tests and verify RED**

Run: `make test-spec SPEC=ui/keybindings`

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/config_tools_spec.lua" -c "qa!"`

Expected: both fail on old exposed defaults, duplicated registry defaults, the mandatory `default_key` invariant, and configured tool-fold default.

- [x] **Step 3: Implement optional-default resolution and new defaults**

Set peer and prune defaults only in `config.lua`. Remove `default_key` from all three migrated registry entries so their `config_key` is the sole resolution path; remove the tool-fold default config value while retaining registry modes, callback, and descriptions. Treat nil/empty shortcuts as unbound. Make help skip entries resolving to no key, while registration naturally skips them; require either `default_key` or `config_key` in the registry invariant. Add a drift test proving the peer/prune registration and help keys equal exposed config rather than a second registry literal (`ARCH-DRY`).

- [x] **Step 4: Run keybinding and config tests and verify GREEN**

Run: `make test-spec SPEC=ui/keybindings`

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/config_tools_spec.lua" -c "qa!"`

Expected: both PASS with zero failures.

- [x] **Step 5: Commit the keybinding migration**

Commit: `keybindings: #190 use peer and branch mnemonics`

### Task 5: Reconcile documentation and close-ready evidence

**Files:**
- Modify: `README.md`
- Modify: `atlas/index.md`
- Modify: `atlas/modes/super_repo.md`
- Modify: `atlas/infra/repo_mode.md`
- Modify: `atlas/chat/lifecycle.md`
- Modify: `atlas/traceability.yaml`
- Modify: `workshop/issues/000190-persist-repo-super-repo-state-across-nvim-sessions.md`
- Modify: `workshop/plans/000190-persist-repo-super-repo-state-across-nvim-sessions-plan.md`

- [x] **Step 1: Update every user-facing description**

Document `<C-g>p` as peer-mode toggle, `<C-g>b` as branch/prune, tool-fold as configurable with no default, per-canonical-repo persistence in `state.json`, ordinary unsaved default, synchronous startup restore, and brain parity. Add README discoverability for the peer toggle and configuration override.

- [x] **Step 2: Search for stale behavior and resolve every relevant hit**

Run: `rg -n '<C-g>S|Pruning \(`<C-g>p`\)|chat_shortcut_toggle_tool_folds.*<C-g>b|Brain repos auto|Toggle is transient|never persisted' README.md atlas lua tests`

Expected: no stale assertions; fixture strings that intentionally test migration must be labeled as such or updated.

- [x] **Step 3: Run mapped tests and static checks**

Before running mapped tests, confirm `atlas/traceability.yaml` maps optional-default registry/help behavior to `keybindings_spec.lua`, default-config migration to `config_tools_spec.lua`, repository-mode policy to `repo_mode_spec.lua`, atomic JSON writes to `helper_io_spec.lua`, and persistence/startup/toggle orchestration to `super_repo_spec.lua`. Extend the existing `modes/super_repo`, `ui/keybindings`, and `chat/lifecycle` entries and add an `infra/repo_mode` entry so every changed atlas file is mapped. Run these concrete selection checks and verify every intended test is selected:

Run: `scripts/spec_test_map.sh list-tests modes/super_repo`

Run: `scripts/spec_test_map.sh list-tests ui/keybindings`

Run: `scripts/spec_test_map.sh list-tests infra/repo_mode`

Run: `scripts/spec_test_map.sh list-tests chat/lifecycle`

Run: `make test-changed`

Run: `make lint`

Run: `git diff --check`

Expected: all commands exit 0 with no failures or whitespace errors.

- [x] **Step 4: Run the full suite**

Run: `make test`

Expected: exit 0 with zero failing tests.

- [x] **Step 5: Reconcile artifacts and commit**

Check every completed issue and durable-plan box, append implementation discoveries and exact verification evidence to `## Log`, and ensure atlas index/traceability stay consistent.

Commit: `docs: #190 document persistent peer mode`

- [x] **Step 6: Prepare and invoke the close boundary**

Run `sdlc actual --issue 190`, then `sdlc close --issue 190 --verified '<fresh mapped/full test, lint, diff-check, and smoke-test evidence>'`, using only the precise `--no-atlas`/other gate flag if the command identifies a genuinely inapplicable guard. Let `sdlc close` dispatch the mandatory fresh-context boundary review; fix all Critical/Important findings before shipping.

## Revisions

### 2026-07-15 — fresh-context plan review

- Reason: review found missing failure-path oracles and incomplete traceability/test command coverage.
- Delta: added write/close/rename atomic preservation tests, exact successful-runtime/failed-save warning assertions, zero-write startup restoration checks, explicit traceability mappings, both RED keybinding/config runs, and empty-shortcut behavior; removed an unused `chat_dirs_spec.lua` modification.

### 2026-07-15 — plan re-review sequencing correction

- Reason: re-review found that setup refresh writes make original-file byte equality an invalid oracle for restoration and that one traceability command remained symbolic.
- Delta: count expected refresh writes and forbid only post-restoration writes while preserving `repo_modes`; name concrete traceability keys and selection commands for every changed atlas surface.

### 2026-07-15 — plan-quality gate architecture refinement

- Reason: the code-change gate found that setting migrated defaults in both config and registry retained duplicate authority.
- Delta: `config.lua` solely owns peer/prune defaults; all three migrated registry entries derive via `config_key`, and a regression pins registration/help to exposed config (`ARCH-DRY`).
?? workshop/issues/000189-all-finders-should-have-a-spinner-in-case-of-large-input.md
?? workshop/parley/2026-07-14.12-21-57.267.md
?? workshop/parley/2026-07-15.11-59-03.488.md
2717e3d (HEAD -> 000190-persist-repo-super-repo-state-across-nvim-sessions) sdlc: #190 prepare close boundary
5f49137 docs: #190 document persistent peer mode
f5da2f8 keybindings: #190 use peer and branch mnemonics
8bb2cb0 super-repo: #190 persist and restore peer mode
befc743 state: #190 add atomic write-only persistence
d2a501a super-repo: #190 add pure persisted-mode policy
 README.md                                          |   8 +
 atlas/chat/lifecycle.md                            |   7 +-
 atlas/index.md                                     |   2 +-
 atlas/infra/repo_mode.md                           |   7 +-
 atlas/modes/super_repo.md                          |  27 ++-
 atlas/traceability.yaml                            |  21 ++
 lua/parley/config.lua                              |   9 +-
 lua/parley/helper.lua                              |  59 +++++
 lua/parley/init.lua                                | 125 +++++-----
 lua/parley/keybinding_registry.lua                 |  16 +-
 lua/parley/repo_mode.lua                           |  37 +++
 lua/parley/super_repo.lua                          |  18 +-
 tests/unit/config_tools_spec.lua                   |  11 +-
 tests/unit/helper_io_spec.lua                      |  82 +++++++
 tests/unit/keybindings_spec.lua                    |  70 +++++-
 tests/unit/repo_mode_spec.lua                      |  58 +++++
 tests/unit/super_repo_spec.lua                     | 260 +++++++++++++++++++++
 ...t-repo-super-repo-state-across-nvim-sessions.md |  26 ++-
 ...o-super-repo-state-across-nvim-sessions-plan.md |  68 +++---
 19 files changed, 786 insertions(+), 125 deletions(-)

codex
The Spec and durable plan are internally aligned, including a greppable Core concepts table, and the review window is clean apart from unrelated untracked user files. I’m now tracing the state-load/write sequence, runtime overlay transitions, and registry consumers—the seams most likely to hide a contract failure despite focused green tests.
exec
/bin/zsh -lc "nl -ba lua/parley/init.lua | sed -n '1,110p;600,790p;1120,1325p' && nl -ba lua/parley/super_repo.lua | sed -n '1,270p' && nl -ba lua/parley/helper.lua | sed -n '410,525p' && nl -ba lua/parley/keybinding_registry.lua | sed -n '880,1040p' && nl -ba lua/parley/config.lua | sed -n '1,180p;430,490p;550,590p' && rg -n \"repo_modes|toggle_super_repo|set_active\\(|table_to_file_atomic|persist_state\\(|global_shortcut_super_repo_toggle|chat_shortcut_prune|chat_shortcut_toggle_tool_folds|<C-g>S|<C-g>p|<C-g>b\" --glob '"'!workshop/history/**'"' ." in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
     1	-- Parley - A Neovim LLM Chat Plugin
     2	-- https://github.com/xianxu/parley.nvim/
     3	-- A streamlined LLM chat interface for Neovim with highlighting and navigation
     4
     5	--------------------------------------------------------------------------------
     6	-- This is the main module
     7	--------------------------------------------------------------------------------
     8	local config = require("parley.config")
     9	local repo_artifacts = require("parley.repo_artifacts")
    10
    11	local M = {
    12		_Name = "Parley", -- plugin name
    13		_state = {
    14			interview_mode = false, -- interview mode state
    15			interview_start_time = nil, -- interview start timestamp
    16			interview_timer = nil, -- timer handle for statusline updates
    17		}, -- table of state variables
    18		agents = {}, -- table of agents
    19		system_prompts = {}, -- table of system prompts
    20		cmd = {}, -- default command functions
    21		config = {}, -- config variables
    22		hooks = {}, -- user defined command functions
    23		defaults = require("parley.defaults"), -- some useful defaults
    24	chat_parser = require("parley.chat_parser"), -- chat file parser
    25		dispatcher = require("parley.dispatcher"), -- handle communication with LLM providers
    26		helpers = require("parley.helper"), -- helper functions
    27		logger = require("parley.logger"), -- logger module
    28		outline = require("parley.outline"), -- outline navigation module
    29		render = require("parley.render"), -- render module
    30		tasker = require("parley.tasker"), -- tasker module
    31		vault = require("parley.vault"), -- handles secrets
    32		lualine = require("parley.lualine"), -- lualine integration
    33		agent_picker = require("parley.agent_picker"), -- agent selection UI
    34		system_prompt_picker = require("parley.system_prompt_picker"), -- system prompt selection UI
    35		note_dir_picker = require("parley.note_dir_picker"), -- note root management UI
    36		float_picker = require("parley.float_picker"), -- shared floating window picker
    37	}
    38
    39	-- Chat slug module for filename slug generation and parsing
    40	local chat_slug = require("parley.chat_slug")
    41
    42	-- Custom system prompts persistence (loaded here; wired up via custom_prompts.setup() inside M.setup())
    43	local custom_prompts = require("parley.custom_prompts")
    44
    45	-- Interview mode module (loaded here; wired up via interview.setup() inside M.setup())
    46	local interview = require("parley.interview")
    47
    48	-- Notes module (loaded here; wired up immediately since it only needs M reference)
    49	local notes = require("parley.notes")
    50	notes.setup(M)
    51
    52	-- Chat dirs module (loaded here; wired up immediately since it only needs M reference)
    53	local chat_dirs = require("parley.chat_dirs")
    54	chat_dirs.setup(M)
    55	-- Local wrappers so all existing callers in init.lua work unchanged
    56	local find_chat_root = function(f) return chat_dirs.find_chat_root(f) end
    57	local find_chat_root_record = function(f) return chat_dirs.find_chat_root_record(f) end
    58	local registered_chat_dir = function(d) return chat_dirs.registered_chat_dir(d) end
    59	local chat_root_display = function(r, i) return chat_dirs.chat_root_display(r, i) end
    60
    61	-- Note dirs module (loaded here; wired up immediately since it only needs M reference)
    62	local note_dirs = require("parley.note_dirs")
    63	note_dirs.setup(M)
    64
    65	-- Super-repo module (loaded here; wired up immediately since it only needs M reference)
    66	local super_repo = require("parley.super_repo")
    67	local repo_mode = require("parley.repo_mode")
    68	super_repo.setup(M)
    69	M.super_repo = super_repo
    70	M.toggle_super_repo = function()
    71		local transitioned, err = super_repo.toggle()
    72		if not transitioned then
    73			return false, err
    74		end
    75
    76		local root = M.config.repo_root
    77		if type(root) == "string" and root ~= "" then
    78			local canonical_root = vim.fn.resolve(vim.fn.expand(root)):gsub("/+$", "")
    79			local mode = super_repo.is_active() and "super_repo" or "repo"
    80			M._state.repo_modes = repo_mode.updated(M._state.repo_modes, canonical_root, mode)
    81			local persisted = M.persist_state()
    82			if not persisted then
    83				M.logger.warning("super-repo: preference not saved")
    84			end
    85		end
    86
    87		return true
    88	end
    89	M.is_super_repo_active = function() return super_repo.is_active() end
    90
    91	-- Discovery registry (#116): the repo's noun-vocabulary (what file types exist
    92	-- and how to find their instances). Pure given mode context; current() reads it
    93	-- from live config (repo_root + super_repo_members) via the injected M ref.
    94	local discovery = require("parley.discovery")
    95	discovery.setup(M)
    96	M.discovery = discovery
    97
    98	-- Skill registry (#128): declarative skill manifests unioned from providers
    99	-- (plugin-disk ∪ user-disk ∪ repo/virtual seams). current() discovers the live
   100	-- stack; the per-turn assembly + read_skill tool (M2) consume it.
   101	M.skills = require("parley.skill_registry")
   102
   103	-- Memory preferences module (loaded here; wired up immediately since it only needs M reference)
   104	local memory_prefs = require("parley.memory_prefs")
   105	memory_prefs.setup(M)
   106
   107	-- Issues module (loaded here; wired up immediately since it only needs M reference)
   108	local issues_mod = require("parley.issues")
   109	issues_mod.setup(M)
   110
   600			-- explicit labels, the normalizer derives labels from the directory
   601			-- basename, which surfaces as e.g. {parley} in the finder when the
   602			-- global chat dir's basename is "parley".
   603			if M.config.repo_chat_dir and M.config.repo_chat_dir ~= "" then
   604				local repo_chat = git_root .. "/" .. M.config.repo_chat_dir
   605				local old_dir = M.config.chat_dir
   606				local old_dirs = M.config.chat_dirs
   607
   608				M.config.chat_dir = repo_chat
   609				local roots = { { dir = repo_chat, label = "repo" } }
   610				if old_dir and old_dir ~= repo_chat then
   611					table.insert(roots, { dir = old_dir, label = "global" })
   612				end
   613				-- Preserve any pre-existing extras (legacy multi-root from setup
   614				-- config). They keep their default basename labels — the only
   615				-- relabels here are repo_chat → "repo" and config.chat_dir →
   616				-- "global". Issue #117 M2 will drop this preservation entirely.
   617				if type(old_dirs) == "table" then
   618					for _, d in ipairs(old_dirs) do
   619						if d ~= repo_chat and d ~= old_dir then
   620							table.insert(roots, { dir = d })
   621						end
   622					end
   623				end
   624				M.config.chat_roots = roots
   625				M.config.chat_dirs = vim.tbl_map(function(r) return r.dir end, roots)
   626			end
   627
   628			-- Prepend repo note dir as primary, demoting global notes_dir to extra
   629			if M.config.repo_note_dir and M.config.repo_note_dir ~= "" then
   630				local repo_note = git_root .. "/" .. M.config.repo_note_dir
   631				local old_dir = M.config.notes_dir
   632				local old_dirs = M.config.note_dirs
   633
   634				M.config.notes_dir = repo_note
   635				local extras = {}
   636				if type(old_dirs) == "table" and #old_dirs > 0 then
   637					extras = vim.deepcopy(old_dirs)
   638				end
   639				if old_dir and old_dir ~= repo_note then
   640					table.insert(extras, 1, old_dir)
   641				end
   642				M.config.note_dirs = extras
   643				M.config.note_roots = {}
   644			end
   645
   646			-- Disable chat memory and memory prefs for repo-local chats
   647			if type(M.config.chat_memory) == "table" then
   648				M.config.chat_memory.enable = false
   649			end
   650			if type(M.config.memory_prefs) == "table" then
   651				M.config.memory_prefs.enable = false
   652			end
   653		end
   654		apply_repo_local()
   655
   656		apply_chat_roots(normalize_chat_roots(M.config.chat_dir, M.config.chat_dirs, M.config.chat_roots))
   657		apply_note_roots(normalize_note_roots(M.config.notes_dir, M.config.note_dirs, M.config.note_roots))
   658
   659		-- repo-local dirs (issues, history, vision, notes) are resolved in apply_repo_local
   660		-- against git root; skip them here to avoid creating in CWD
   661		local skip_prepare = { chat_dir = true }
   662		for _, key in ipairs(repo_artifacts.dir_keys) do
   663			skip_prepare[key] = true
   664		end
   665		for k, v in pairs(M.config) do
   666			if not skip_prepare[k] and k:match("_dir$") and type(v) == "string" then
   667				M.config[k] = M.helpers.prepare_dir(v, k)
   668			end
   669		end
   670
   671		-- remove disabled agents
   672		for name, agent in pairs(M.agents) do
   673			if type(agent) ~= "table" or agent.disable then
   674				M.agents[name] = nil
   675			elseif not agent.model or not agent.system_prompt then
   676				M.logger.warning(
   677					"Agent "
   678						.. name
   679						.. " is missing model or system_prompt\n"
   680						.. "If you want to disable an agent, use: { name = '"
   681						.. name
   682						.. "', disable = true },"
   683				)
   684				M.agents[name] = nil
   685			end
   686		end
   687
   688		-- prepare agent list
   689		M._agents = {}
   690		local tools_mod = require("parley.tools")
   691		for name, _ in pairs(M.agents) do
   692			M.agents[name].provider = M.agents[name].provider or "openai"
   693
   694			if M.dispatcher.providers[M.agents[name].provider] then
   695				-- Validate per-agent tool-use config (M1 of #81). Agents opting
   696				-- into client-side tool use must reference only registered
   697				-- builtin names. Unknown names raise with the offending name.
   698				-- Defaults for max_tool_iterations and tool_result_max_bytes
   699				-- are applied here, not on vanilla agents (byte-identity lock).
   700				local agent = M.agents[name]
   701				if agent.tools and #agent.tools > 0 then
   702					-- `tools_mod.select` raises on unknown names
   703					local ok, err = pcall(tools_mod.select, agent.tools)
   704					if not ok then
   705						error(string.format("agent %q: %s", name, tostring(err)))
   706					end
   707					agent.max_tool_iterations = agent.max_tool_iterations or M.defaults.max_tool_iterations
   708					agent.tool_result_max_bytes = agent.tool_result_max_bytes or 102400
   709				end
   710
   711				table.insert(M._agents, name)
   712			else
   713				M.agents[name] = nil
   714			end
   715		end
   716		table.sort(M._agents)
   717
   718		-- remove disabled system_prompts
   719		for name, prompt in pairs(M.system_prompts) do
   720			if type(prompt) ~= "table" or prompt.disable then
   721				M.system_prompts[name] = nil
   722			elseif not prompt.system_prompt then
   723				M.logger.warning(
   724					"System prompt "
   725						.. name
   726						.. " is missing system_prompt field\n"
   727						.. "If you want to disable a system prompt, use: { name = '"
   728						.. name
   729						.. "', disable = true },"
   730				)
   731				M.system_prompts[name] = nil
   732			end
   733		end
   734
   735		-- snapshot builtin prompts (after config merge and disabled removal)
   736		M._builtin_system_prompts = vim.deepcopy(M.system_prompts)
   737
   738		-- merge custom (user-edited) prompts over builtins
   739		local user_prompts = custom_prompts.load()
   740		for name, prompt in pairs(user_prompts) do
   741			if type(prompt) == "table" and prompt.system_prompt then
   742				M.system_prompts[name] = prompt
   743			end
   744		end
   745
   746		-- prepare system_prompts list
   747		M._system_prompts = {}
   748		for name, _ in pairs(M.system_prompts) do
   749			table.insert(M._system_prompts, name)
   750		end
   751		table.sort(M._system_prompts)
   752
   753		M.refresh_state()
   754
   755		if M.config.default_agent then
   756			M.refresh_state({ agent = M.config.default_agent })
   757		end
   758
   759		-- Restore the current repo's explicit mode only after every state refresh has
   760		-- settled roots. This runtime transition is intentionally non-persisting.
   761		if type(M.config.repo_root) == "string" and M.config.repo_root ~= "" then
   762			local canonical_root = vim.fn.resolve(vim.fn.expand(M.config.repo_root)):gsub("/+$", "")
   763			local saved_mode = repo_mode.resolve(M._state.repo_modes, canonical_root)
   764			super_repo.set_active(saved_mode == "super_repo")
   765		end
   766
   767		-- register user commands
   768		for hook, _ in pairs(M.hooks) do
   769			M.helpers.create_user_command(M.config.cmd_prefix .. hook, function(params)
   770				if M.hooks[hook] ~= nil then
   771					M.refresh_state()
   772					M.logger.debug("running hook: " .. hook)
   773					return M.hooks[hook](M, params)
   774				end
   775				M.logger.error("The hook '" .. hook .. "' does not exist.")
   776			end)
   777		end
   778
   779		-- :ParleyProxy <subcommand> — manage the optional bundled cliproxyapi (#131)
   780		M.register_proxy_command(M.config.cmd_prefix)
   781
   782		-- :ParleyShowDiagnostics — toggle inline display of review "why" diagnostics
   783		-- (cursor-region auto-show, scoped to parley's namespace). Default on. (#133 M6)
   784		M.helpers.create_user_command(M.config.cmd_prefix .. "ShowDiagnostics", function()
   785			local on = require("parley.skills.review.diag_display").toggle()
   786			M.logger.info("Parley review diagnostics: inline display " .. (on and "ON" or "OFF"))
   787		end)
   788		require("parley.skills.review.diag_display").set(true)
   789
   790		-- Register all global keymaps from the keybinding registry
  1120			M.logger.error("curl is not installed, run :checkhealth parley")
  1121		end
  1122
  1123		-- Set up custom Search highlight for better visibility of all matches
  1124		local st = vim.api.nvim_get_hl(0, { name = "PmenuSel" })
  1125		vim.api.nvim_set_hl(0, "Search", {
  1126			bg = st.bg or st.background,
  1127			fg = st.fg or st.foreground,
  1128			bold = false,
  1129		})
  1130		vim.api.nvim_set_hl(0, "ParleyPickerApproximateMatch", {
  1131			link = "IncSearch",
  1132		})
  1133
  1134		-- Prewarm finder caches in the background (deferred, non-blocking)
  1135		chat_finder_mod.prewarm()
  1136		note_finder_mod.prewarm()
  1137
  1138		-- Auto-generate memory preferences if enabled and stale
  1139		memory_prefs.maybe_generate()
  1140
  1141		M.logger.debug("setup finished")
  1142	end
  1143
  1144	--- Persist the current state without reloading disk state or reapplying roots.
  1145	--- Runtime-derived chat roots and repo/super-repo note roots are excluded.
  1146	---@return boolean ok
  1147	---@return string|nil err
  1148	M.persist_state = function()
  1149		local persist_state = vim.deepcopy(M._state)
  1150		persist_state.chat_roots = nil
  1151		persist_state.chat_dirs = nil
  1152
  1153		local function resolve_dir(dir)
  1154			return vim.fn.resolve(vim.fn.expand(dir)):gsub("/+$", "")
  1155		end
  1156		local pushed_note = {}
  1157		for _, dir in ipairs(super_repo.get_pushed_note_dirs()) do
  1158			pushed_note[dir] = true
  1159		end
  1160		if type(persist_state.note_roots) == "table" then
  1161			local filtered = {}
  1162			for _, root in ipairs(persist_state.note_roots) do
  1163				if root.label ~= "repo" and not pushed_note[resolve_dir(root.dir)] then
  1164					table.insert(filtered, root)
  1165				end
  1166			end
  1167			persist_state.note_roots = #filtered > 0 and filtered or nil
  1168		end
  1169		if type(persist_state.note_roots) == "table" then
  1170			local dirs = {}
  1171			for _, root in ipairs(persist_state.note_roots) do
  1172				table.insert(dirs, root.dir)
  1173			end
  1174			persist_state.note_dirs = #dirs > 0 and dirs or nil
  1175		else
  1176			persist_state.note_dirs = nil
  1177		end
  1178
  1179		local state_file = M.config.state_dir .. "/state.json"
  1180		return M.helpers.table_to_file_atomic(persist_state, state_file)
  1181	end
  1182
  1183	---@param update table | nil # table with options
  1184	M.refresh_state = function(update)
  1185		local state_file = M.config.state_dir .. "/state.json"
  1186		update = update or {}
  1187
  1188		local old_state = vim.deepcopy(M._state)
  1189
  1190		local disk_state = {}
  1191		if vim.fn.filereadable(state_file) ~= 0 then
  1192			disk_state = M.helpers.file_to_table(state_file) or {}
  1193		end
  1194
  1195		if not disk_state.updated then
  1196			local primary_chat_dir = M.get_chat_dirs()[1]
  1197			local last = primary_chat_dir and (primary_chat_dir .. "/last.md") or nil
  1198			if last and vim.fn.filereadable(last) == 1 then
  1199				os.remove(last)
  1200			end
  1201		end
  1202
  1203		if not M._state.updated or (disk_state.updated and M._state.updated < disk_state.updated) then
  1204			M._state = vim.deepcopy(disk_state)
  1205		end
  1206		M._state.updated = os.time()
  1207
  1208		-- Always ensure interview mode starts as false (don't persist interview mode across sessions)
  1209		M._state.interview_mode = false
  1210		M._state.interview_start_time = nil
  1211		-- Stop any running interview timer
  1212		interview.stop_timer()
  1213
  1214		-- apply in-memory updates
  1215		for k, v in pairs(update) do
  1216			M._state[k] = v
  1217		end
  1218		-- initialize per-chat web_search setting if missing (migrate from old key name)
  1219		if M._state.web_search == nil then
  1220			if M._state.claude_web_search ~= nil then
  1221				M._state.web_search = M._state.claude_web_search
  1222				M._state.claude_web_search = nil
  1223			else
  1224				M._state.web_search = M.config.web_search
  1225			end
  1226		end
  1227
  1228		if M._state.follow_cursor == nil then
  1229			M._state.follow_cursor = not M.config.chat_free_cursor
  1230		end
  1231
  1232		-- Issue #117 M2: chat roots are derived from config.chat_dir + repo
  1233		-- mode + super-repo, never restored from state.json. Old state files
  1234		-- may still carry chat_dirs/chat_roots fields — they are ignored.
  1235
  1236		-- Restore note roots from persisted state
  1237		if type(M._state.note_roots) == "table" and #M._state.note_roots > 0 then
  1238			apply_note_roots(M._state.note_roots)
  1239		else
  1240			M._state.note_roots = vim.deepcopy(M.get_note_roots())
  1241			M._state.note_dirs = vim.deepcopy(M.get_note_dirs())
  1242		end
  1243
  1244		-- Issue #117 M2: the chat-side defensive re-injection of repo_chat
  1245		-- as primary lived here. With state.json no longer carrying chat
  1246		-- roots, apply_repo_local at setup is the single source of truth
  1247		-- for the chat roots list — there's no stale state to defend
  1248		-- against. The note-side block below is unchanged because notes
  1249		-- still persist their roots (separate cleanup, separate issue).
  1250
  1251		-- In repo mode, ensure repo note dir is the primary root (overrides persisted state)
  1252		if M.config.repo_root and M.config.repo_note_dir then
  1253			local repo_note = M.config.repo_root .. "/" .. M.config.repo_note_dir
  1254			local resolved_repo = vim.fn.resolve(vim.fn.expand(repo_note)):gsub("/+$", "")
  1255			local current_roots = M.get_note_roots()
  1256			local already_primary = #current_roots > 0
  1257				and vim.fn.resolve(vim.fn.expand(current_roots[1].dir)):gsub("/+$", "") == resolved_repo
  1258
  1259			if not already_primary then
  1260				local new_roots = { { dir = repo_note, label = "repo" } }
  1261				for _, root in ipairs(current_roots) do
  1262					if vim.fn.resolve(vim.fn.expand(root.dir)):gsub("/+$", "") ~= resolved_repo then
  1263						table.insert(new_roots, root)
  1264					end
  1265				end
  1266				apply_note_roots(new_roots)
  1267				M._state.note_roots = vim.deepcopy(M.get_note_roots())
  1268				M._state.note_dirs = vim.deepcopy(M.get_note_dirs())
  1269			end
  1270		end
  1271
  1272		if not M._state.agent or not M.agents[M._state.agent] then
  1273			M._state.agent = M._agents[1]
  1274		end
  1275
  1276		if not M._state.system_prompt or not M.system_prompts[M._state.system_prompt] then
  1277			M._state.system_prompt = "default"
  1278		end
  1279
  1280		if M._state.last_chat and vim.fn.filereadable(M._state.last_chat) == 0 then
  1281			M._state.last_chat = nil
  1282		end
  1283
  1284		for k, _ in pairs(M._state) do
  1285			if M._state[k] ~= old_state[k] or M._state[k] ~= disk_state[k] then
  1286				M.logger.debug(
  1287					string.format(
  1288						"state[%s]: disk=%s old=%s new=%s",
  1289						k,
  1290						vim.inspect(disk_state[k]),
  1291						vim.inspect(old_state[k]),
  1292						vim.inspect(M._state[k])
  1293					)
  1294				)
  1295			end
  1296		end
  1297
  1298		-- Runtime roots are filtered by the shared write-only boundary. Writing must
  1299		-- not reload state or disturb a live super-repo overlay.
  1300		local persisted, persist_err = M.persist_state()
  1301		if not persisted then
  1302			M.logger.warning("state: persistence failed: " .. tostring(persist_err or "unknown error"))
  1303		end
  1304
  1305		local buf = vim.api.nvim_get_current_buf()
  1306		local file_name = vim.api.nvim_buf_get_name(buf)
  1307		M.display_agent(buf, file_name)
  1308	end
  1309
  1310	---@return string
  1311	M._remote_reference_cache_file = function() return chat_respond.remote_reference_cache_file() end
  1312	M._load_remote_reference_cache = function() return chat_respond.load_remote_reference_cache() end
  1313	M._save_remote_reference_cache = function() return chat_respond.save_remote_reference_cache() end
  1314	M._get_chat_remote_reference_cache = function(f) return chat_respond.get_chat_remote_reference_cache(f) end
  1315	M._format_remote_reference_error_content = function(u, e) return chat_respond.format_remote_reference_error_content(u, e) end
  1316	M._format_missing_remote_reference_cache_content = function(u) return chat_respond.format_missing_remote_reference_cache_content(u) end
  1317
  1318	-- stop receiving responses for all processes and clean the handles
  1319	---@param signal number | nil # signal to send to the process
  1320	M.cmd.Stop = function(s) chat_respond.cmd_stop(s) end
  1321
  1322	--------------------------------------------------------------------------------
  1323	-- Keybinding help (driven by keybinding_registry)
  1324	--------------------------------------------------------------------------------
  1325
     1	-- parley.super_repo — super-repo mode (read-aggregation overlay)
     2	--
     3	-- Toggle activates a runtime overlay on top of plain repo mode:
     4	--   * Discovers sibling .parley repos under the current repo's parent dir.
     5	--   * Pushes their workshop/parley and workshop/notes paths into chat_roots
     6	--     and note_roots as labelled transient extras.
     7	--   * Writes are unchanged: still go to the current repo, exactly as plain
     8	--     repo mode does today.
     9	--
    10	-- This module owns only the runtime overlay. parley.init persists explicit
    11	-- user choices and restores them through set_active().
    12
    13	local M = {}
    14	local _parley
    15
    16	-- Active state. Cleared on toggle-off.
    17	local _state = {
    18		active = false,
    19		workspace_root = nil,
    20		members = {},          -- list of { path, name }
    21		pushed_chat_dirs = {}, -- resolved paths we appended (for cleanup)
    22		pushed_note_dirs = {}, -- resolved paths we appended (for cleanup)
    23	}
    24
    25	local function resolve_dir_key(dir)
    26		local out = vim.fn.resolve(vim.fn.expand(dir)):gsub("/+$", "")
    27		return out
    28	end
    29
    30	M.setup = function(parley)
    31		_parley = parley
    32	end
    33
    34	M.is_active = function()
    35		return _state.active
    36	end
    37
    38	M.get_state = function()
    39		return {
    40			active = _state.active,
    41			workspace_root = _state.workspace_root,
    42			members = vim.deepcopy(_state.members),
    43		}
    44	end
    45
    46	--- Resolved paths of sibling chat dirs currently pushed into chat_roots.
    47	--- Used by the persistence gate in init.lua to exclude these from state.json.
    48	M.get_pushed_chat_dirs = function()
    49		return vim.deepcopy(_state.pushed_chat_dirs)
    50	end
    51
    52	--- Resolved paths of sibling note dirs currently pushed into note_roots.
    53	M.get_pushed_note_dirs = function()
    54		return vim.deepcopy(_state.pushed_note_dirs)
    55	end
    56
    57	--- Compute per-finder roots for a given repo-relative subdir (e.g. "workshop/issues").
    58	--- When super-repo is active and has members, returns a list of
    59	--- `{ dir = <abs>, repo_name = <name> }` per member. Otherwise returns nil so
    60	--- the caller falls back to its single-repo path.
    61	--- @param subdir string repo-relative path (or absolute; absolute is left as-is)
    62	--- @return table|nil list of {dir, repo_name} or nil for single-repo
    63	M.expand_roots = function(subdir)
    64		if not _state.active or #_state.members == 0 then
    65			return nil
    66		end
    67		if type(subdir) ~= "string" or subdir == "" then
    68			return nil
    69		end
    70		local roots = {}
    71		for _, m in ipairs(_state.members) do
    72			local dir = subdir
    73			if dir:sub(1, 1) ~= "/" then
    74				dir = m.path .. "/" .. dir
    75			end
    76			table.insert(roots, { dir = dir, repo_name = m.name })
    77		end
    78		return roots
    79	end
    80
    81	--- Compute sibling .parley repos under repo_root's parent directory.
    82	--- Returns { workspace_root, members } where members is a list of
    83	--- { path, name } sorted by name. Returns nil, err on failure.
    84	M.compute_members = function(repo_root)
    85		if type(repo_root) ~= "string" or repo_root == "" then
    86			return nil, "repo_root is empty"
    87		end
    88		local resolved = resolve_dir_key(repo_root)
    89		local workspace_root = vim.fn.fnamemodify(resolved, ":h")
    90		if not workspace_root or workspace_root == "" or workspace_root == "/" or workspace_root == resolved then
    91			return nil, "repo_root has no parent"
    92		end
    93		local matches = vim.fn.glob(workspace_root .. "/*/.parley", false, true) or {}
    94		local members = {}
    95		for _, marker in ipairs(matches) do
    96			local path = vim.fn.fnamemodify(marker, ":h")
    97			local name = vim.fn.fnamemodify(path, ":t")
    98			table.insert(members, { path = path, name = name })
    99		end
   100		table.sort(members, function(a, b) return a.name < b.name end)
   101		return { workspace_root = workspace_root, members = members }
   102	end
   103
   104	local function fire_changed()
   105		pcall(function()
   106			vim.api.nvim_exec_autocmds("User", { pattern = "ParleySuperRepoChanged", modeline = false })
   107		end)
   108	end
   109
   110	local function activate()
   111		if _state.active then return true end
   112
   113		local repo_root = _parley.config.repo_root
   114		if type(repo_root) ~= "string" or repo_root == "" then
   115			_parley.logger.warning("super-repo: cwd is not inside a .parley repo")
   116			return false, "not in repo"
   117		end
   118
   119		local discovered, err = M.compute_members(repo_root)
   120		if not discovered then
   121			_parley.logger.warning("super-repo: " .. (err or "discovery failed"))
   122			return false, err
   123		end
   124
   125		local current_resolved = resolve_dir_key(repo_root)
   126		local repo_chat_subdir = _parley.config.repo_chat_dir or "workshop/parley"
   127		local repo_note_subdir = _parley.config.repo_note_dir or "workshop/notes"
   128
   129		-- Build sibling dir lists (excluding current repo, which is already primary).
   130		-- Label = repo name so the finder UI shows "{ariadne}" / "{brain}" etc.
   131		-- Persistence filtering is handled separately (init.lua persist gate consults
   132		-- super_repo.get_pushed_*_dirs() to drop these from state.json), so we don't
   133		-- need to overload the label as a sentinel.
   134		local sibling_chat_roots = {}
   135		local sibling_note_roots = {}
   136		for _, m in ipairs(discovered.members) do
   137			if resolve_dir_key(m.path) ~= current_resolved then
   138				table.insert(sibling_chat_roots, {
   139					dir = m.path .. "/" .. repo_chat_subdir,
   140					label = m.name,
   141				})
   142				table.insert(sibling_note_roots, {
   143					dir = m.path .. "/" .. repo_note_subdir,
   144					label = m.name,
   145				})
   146			end
   147		end
   148
   149		-- Append to existing chat_roots / note_roots (persist=false: transient)
   150		local new_chat_roots = vim.deepcopy(_parley.get_chat_roots())
   151		for _, r in ipairs(sibling_chat_roots) do
   152			table.insert(new_chat_roots, r)
   153		end
   154		_parley.set_chat_roots(new_chat_roots, false)
   155
   156		local new_note_roots = vim.deepcopy(_parley.get_note_roots())
   157		for _, r in ipairs(sibling_note_roots) do
   158			table.insert(new_note_roots, r)
   159		end
   160		_parley.set_note_roots(new_note_roots, false)
   161
   162		_state.active = true
   163		_state.workspace_root = discovered.workspace_root
   164		_state.members = vim.deepcopy(discovered.members)
   165		_state.pushed_chat_dirs = vim.tbl_map(function(r) return resolve_dir_key(r.dir) end, sibling_chat_roots)
   166		_state.pushed_note_dirs = vim.tbl_map(function(r) return resolve_dir_key(r.dir) end, sibling_note_roots)
   167		_parley.config.super_repo_root = discovered.workspace_root
   168		_parley.config.super_repo_members = vim.deepcopy(discovered.members)
   169
   170		fire_changed()
   171		return true
   172	end
   173
   174	local function strip_pushed(roots, pushed_set)
   175		local kept = {}
   176		for _, r in ipairs(roots) do
   177			if not pushed_set[resolve_dir_key(r.dir)] then
   178				table.insert(kept, r)
   179			end
   180		end
   181		return kept
   182	end
   183
   184	local function deactivate()
   185		if not _state.active then return true end
   186
   187		local pushed_chat_set = {}
   188		for _, d in ipairs(_state.pushed_chat_dirs) do pushed_chat_set[d] = true end
   189		local pushed_note_set = {}
   190		for _, d in ipairs(_state.pushed_note_dirs) do pushed_note_set[d] = true end
   191
   192		-- Always re-apply, even when the user has mutated roots in the meantime.
   193		-- The set_*_roots API requires at least one root, so fall back to the
   194		-- existing primary if stripping pushed siblings would leave nothing.
   195		local kept_chat = strip_pushed(vim.deepcopy(_parley.get_chat_roots()), pushed_chat_set)
   196		if #kept_chat > 0 then
   197			_parley.set_chat_roots(kept_chat, false)
   198		end
   199		local kept_note = strip_pushed(vim.deepcopy(_parley.get_note_roots()), pushed_note_set)
   200		if #kept_note > 0 then
   201			_parley.set_note_roots(kept_note, false)
   202		end
   203
   204		_state.active = false
   205		_state.workspace_root = nil
   206		_state.members = {}
   207		_state.pushed_chat_dirs = {}
   208		_state.pushed_note_dirs = {}
   209		_parley.config.super_repo_root = nil
   210		_parley.config.super_repo_members = nil
   211
   212		fire_changed()
   213		return true
   214	end
   215
   216	M.set_active = function(active)
   217		if active then
   218			return activate()
   219		end
   220		return deactivate()
   221	end
   222
   223	M.toggle = function()
   224		return M.set_active(not _state.active)
   225	end
   226
   227	return M
   410		-- not the current buffer (e.g. a scheduled callback fired while focus
   411		-- was elsewhere), the marker would land on the wrong buffer and the
   412		-- next change in `buf` would not be merged. nvim_buf_call temporarily
   413		-- sets the current buffer to `buf` for the duration of the callback.
   414		vim.api.nvim_buf_call(buf, function()
   415			local status, result = pcall(vim.cmd.undojoin)
   416			if not status then
   417				if result:match("E790") then
   418					return
   419				end
   420				logger.error("Error running undojoin: " .. vim.inspect(result))
   421			end
   422		end)
   423	end
   424
   425	---@param tbl table # the table to be stored
   426	---@param file_path string # the file path where the table will be stored as json
   427	_H.table_to_file = function(tbl, file_path)
   428		local json = vim.json.encode(tbl)
   429
   430		local file = io.open(file_path, "w")
   431		if not file then
   432			logger.warning("Failed to open file for writing: " .. file_path)
   433			return
   434		end
   435		file:write(json)
   436		file:close()
   437	end
   438
   439	---@param tbl table # table to encode as JSON
   440	---@param file_path string # destination replaced only after a complete write
   441	---@param adapter table|nil # optional IO adapter for deterministic failure tests
   442	---@return boolean ok
   443	---@return string|nil err
   444	_H.table_to_file_atomic = function(tbl, file_path, adapter)
   445		adapter = adapter or {}
   446		local encode = adapter.encode or vim.json.encode
   447		local open = adapter.open or io.open
   448		local rename = adapter.rename or os.rename
   449		local remove = adapter.remove or os.remove
   450		local temp_path = adapter.temp_path or function(path)
   451			local uv = vim.uv or vim.loop
   452			local nonce = uv and uv.hrtime and uv.hrtime() or os.time()
   453			return string.format("%s.tmp-%s-%06x", path, tostring(nonce), math.random(0, 0xFFFFFF))
   454		end
   455
   456		local function failure(stage, detail)
   457			local message = tostring(detail or "unknown error")
   458			return false, (stage .. " failed: " .. message):sub(1, 240)
   459		end
   460		local function cleanup(path)
   461			pcall(remove, path)
   462		end
   463
   464		local encoded_ok, json = pcall(encode, tbl)
   465		if not encoded_ok then
   466			return failure("encode", json)
   467		end
   468
   469		local tmp = temp_path(file_path)
   470		local open_ok, file, open_err = pcall(open, tmp, "w")
   471		if not open_ok or not file then
   472			cleanup(tmp)
   473			return failure("open", open_ok and open_err or file)
   474		end
   475
   476		local write_ok, write_result, write_err = pcall(function() return file:write(json) end)
   477		if not write_ok or not write_result then
   478			pcall(function() file:close() end)
   479			cleanup(tmp)
   480			return failure("write", write_ok and write_err or write_result)
   481		end
   482
   483		local close_ok, close_result, close_err = pcall(function() return file:close() end)
   484		if not close_ok or not close_result then
   485			cleanup(tmp)
   486			return failure("close", close_ok and close_err or close_result)
   487		end
   488
   489		local rename_ok, rename_result, rename_err = pcall(rename, tmp, file_path)
   490		if not rename_ok or not rename_result then
   491			cleanup(tmp)
   492			return failure("rename", rename_ok and rename_err or rename_result)
   493		end
   494
   495		return true
   496	end
   497
   498	---@param file_path string # the file path from where to read the json into a table
   499	---@return table | nil # the table read from the file, or nil if an error occurred
   500	_H.file_to_table = function(file_path)
   501		local file, err = io.open(file_path, "r")
   502		if not file then
   503			logger.warning("Failed to open file for reading: " .. file_path .. "\nError: " .. err)
   504			return nil
   505		end
   506		local content = file:read("*a")
   507		file:close()
   508
   509		if content == nil or content == "" then
   510			logger.warning("Failed to read any content from file: " .. file_path)
   511			return nil
   512		end
   513
   514		local tbl = vim.json.decode(content)
   515		return tbl
   516	end
   517
   518	_H.get_week_number_sunday_based = function(date_str)
   519	  local function is_leap(year)
   520	    return (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0)
   521	  end
   522
   523	  -- parse "YYYY-MM-DD"
   524	  local y, m, d = date_str:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
   525	  local year, month, day = tonumber(y), tonumber(m), tonumber(d)
   880	M._by_scope = {}
   881	for _, entry in ipairs(M.entries) do
   882		if not M._by_scope[entry.scope] then
   883			M._by_scope[entry.scope] = {}
   884		end
   885		table.insert(M._by_scope[entry.scope], entry)
   886	end
   887
   888	-------------------------------------------------------------------
   889	-- Config resolution
   890	-------------------------------------------------------------------
   891
   892	--- Resolve the key and modes for an entry, checking config overrides.
   893	--- Handles both flat config keys (e.g. "global_shortcut_new") and
   894	--- nested dot-notation (e.g. "chat_finder_mappings.delete").
   895	--- For entries with multiple bound keys (default_key as list), returns the
   896	--- primary (first) key. Use `resolve_keys` to get the full list.
   897	--- @param entry table
   898	--- @param config table
   899	--- @return string|nil key
   900	--- @return string[]|nil modes
   901	function M.resolve_key(entry, config)
   902		local keys, modes = M.resolve_keys(entry, config)
   903		return keys and keys[1] or nil, modes
   904	end
   905
   906	--- Resolve all bound keys (primary + aliases) and modes for an entry.
   907	--- Both `default_key` and config-supplied `shortcut` may be a single string
   908	--- or a list of strings — both shapes are normalized to a list.
   909	--- @param entry table
   910	--- @param config table
   911	--- @return string[]|nil keys
   912	--- @return string[]|nil modes
   913	function M.resolve_keys(entry, config)
   914		local function as_list(v)
   915			if v == nil then return nil end
   916			if type(v) == "string" then return v ~= "" and { v } or nil end
   917			if type(v) ~= "table" then return nil end
   918			local keys = {}
   919			for _, key in ipairs(v) do
   920				if type(key) == "string" and key ~= "" then table.insert(keys, key) end
   921			end
   922			return #keys > 0 and keys or nil
   923		end
   924
   925		if not entry.config_key then
   926			return as_list(entry.default_key), entry.default_modes
   927		end
   928
   929		-- Handle dot-notation for nested config (e.g. "chat_finder_mappings.delete")
   930		local cfg_val
   931		if entry.config_key:find(".", 1, true) then
   932			local parts = {}
   933			for part in entry.config_key:gmatch("[^.]+") do
   934				table.insert(parts, part)
   935			end
   936			cfg_val = config
   937			for _, part in ipairs(parts) do
   938				if type(cfg_val) ~= "table" then
   939					cfg_val = nil
   940					break
   941				end
   942				cfg_val = cfg_val[part]
   943			end
   944		else
   945			cfg_val = config[entry.config_key]
   946		end
   947
   948		if cfg_val and type(cfg_val) == "table" then
   949			return as_list(cfg_val.shortcut) or as_list(entry.default_key),
   950				cfg_val.modes or entry.default_modes
   951		end
   952		return as_list(entry.default_key), entry.default_modes
   953	end
   954
   955	-------------------------------------------------------------------
   956	-- Help display
   957	-------------------------------------------------------------------
   958
   959	--- Resolve the actual runtime shortcut by querying vim keymaps.
   960	--- Falls back to config/default if runtime lookup fails.
   961	--- @param entry table  registry entry
   962	--- @param config table  parley config
   963	--- @param bufnr integer|nil  buffer number for buffer-local lookup
   964	--- @return string  display string for the shortcut
   965	local function resolve_display_shortcut(entry, config, _bufnr)
   966		-- Use config resolution (preserves user-facing format like <C-g>?)
   967		local key, _ = M.resolve_key(entry, config)
   968		return key or entry.default_key
   969	end
   970
   971	--- Generate help lines for a given context.
   972	--- @param context string  buffer context (e.g. "chat", "issue", "other")
   973	--- @param config table  parley config
   974	--- @param bufnr integer|nil  current buffer number
   975	--- @return string[]  lines for the help window
   976	function M.help_lines(context, config, bufnr)
   977		-- Title
   978		local title_suffix = {
   979			chat = " (Chat)",
   980			note = " (Note)",
   981			issue = " (Issue)",
   982			markdown = " (Markdown)",
   983			chat_finder = " (Chat Finder)",
   984			note_finder = " (Note Finder)",
   985			issue_finder = " (Issue Finder)",
   986			vision = " (Vision)",
   987			repo = " (Repo)",
   988		}
   989		local lines = {
   990			"Parley Key Bindings" .. (title_suffix[context] or ""),
   991			"",
   992		}
   993
   994		local function add(shortcut, description)
   995			table.insert(lines, string.format("  %-12s %s", shortcut, description))
   996		end
   997
   998		-- Get applicable scopes in display order
   999		local display_scopes = M.get_display_scopes(context)
  1000
  1001		for _, scope in ipairs(display_scopes) do
  1002			local scope_entries = M._by_scope[scope]
  1003			if scope_entries and #scope_entries > 0 then
  1004				table.insert(lines, M.scope_labels[scope] or scope)
  1005				for _, entry in ipairs(scope_entries) do
  1006					local key = resolve_display_shortcut(entry, config, bufnr)
  1007					if key then add(key, entry.help_desc or entry.desc) end
  1008				end
  1009				table.insert(lines, "")
  1010			end
  1011		end
  1012
  1013		-- Finder recency note
  1014		if context == "chat_finder" then
  1015			local months = (config.chat_finder_recency or {}).months or 6
  1016			table.insert(lines, string.format("  %-12s %s", "", "(Recent window default: last " .. tostring(months) .. " months)"))
  1017			table.insert(lines, "")
  1018		elseif context == "note_finder" then
  1019			local months = (config.note_finder_recency or {}).months or 6
  1020			table.insert(lines, string.format("  %-12s %s", "", "(Recent window default: last " .. tostring(months) .. " months)"))
  1021			table.insert(lines, "")
  1022		end
  1023
  1024		table.insert(lines, "Close: q or <Esc>")
  1025		return lines
  1026	end
  1027
  1028	-------------------------------------------------------------------
  1029	-- Registration
  1030	-------------------------------------------------------------------
  1031
  1032	--- Register all non-buffer-local keybindings for the given scopes.
  1033	--- @param scopes string[]  list of scope names to register
  1034	--- @param config table  parley config
  1035	--- @param callbacks table  map of entry.id → callback function
  1036	function M.register_global(scopes, config, callbacks)
  1037		local scope_set = {}
  1038		for _, s in ipairs(scopes) do
  1039			scope_set[s] = true
  1040		end
     1	-- Parley - A Neovim LLM Chat Plugin
     2	-- https://github.com/xianxu/parley.nvim/
     3
     4	--------------------------------------------------------------------------------
     5	-- Default config
     6	--------------------------------------------------------------------------------
     7
     8	---@class ParleyConfig
     9	-- README_REFERENCE_MARKER_START
    10	local config = {
    11		-- Please start with minimal config possible.
    12		-- Just openai_api_key if you don't have OPENAI_API_KEY env set up.
    13		-- Defaults change over time to improve things, options might get deprecated.
    14		-- It's better to change only things where the default doesn't fit your needs.
    15
    16		-- required openai api key (string or table with command and arguments)
    17		-- openai_api_key = { "cat", "path_to/openai_api_key" },
    18		-- openai_api_key = { "bw", "get", "password", "OPENAI_API_KEY" },
    19		-- openai_api_key: "sk-...",
    20		-- openai_api_key = os.getenv("env_name.."),
    21		-- openai_api_key = os.getenv("OPENAI_API_KEY"),
    22
    23		-- API keys for each provider - easy to override just this section without copying entire config
    24		-- Set these in your local configuration - this is separate from providers section
    25		api_keys = {
    26			-- Different ways to provide API keys (from lowest to highest security):
    27			-- 1. Hardcode: api_key = "sk-..."
    28			-- 2. Environment variable: api_key = os.getenv("OPENAI_API_KEY")
    29			-- 3. File: api_key = { "cat", "/path/to/api_key_file" }
    30			-- 4. Password manager: api_key = { "pass", "show", "openai-key" }
    31			-- 5. macOS Keychain: api_key = { "security", "find-generic-password", "-a", "your_username", "-s", "OPENAI_API_KEY", "-w" }
    32
    33			openai = os.getenv("OPENAI_API_KEY"),
    34			anthropic = os.getenv("ANTHROPIC_API_KEY"),
    35
    36			googleai = os.getenv("GOOGLEAI_API_KEY"),
    37			ollama = "dummy_secret", -- ollama typically uses a dummy token for local instances
    38			copilot = os.getenv("GITHUB_TOKEN"), -- for GitHub Copilot
    39			-- Local client↔proxy handshake token (NOT your subscription auth — that
    40			-- lives in the cliproxy auth-dir via :ParleyProxy login). In managed mode
    41			-- parley renders this into the proxy's api-keys AND sends it as the bearer,
    42			-- so a fixed local default works out-of-the-box over loopback. Override
    43			-- via the env var if you point at a proxy that expects a specific key.
    44			cliproxyapi = os.getenv("CLIPROXYAPI_API_KEY") or "parley-local",
    45		},
    46
    47		-- Google Drive OAuth configuration for @@ URL references
    48		-- Users can override with plaintext values in their setup() call.
    49		google_drive = {
    50			client_id = "",
    51			client_secret = "",
    52			scopes = { "https://www.googleapis.com/auth/drive.readonly" },
    53		},
    54
    55		-- Provider-neutral OAuth configuration for remote @@ URL references.
    56		-- New provider integrations should be added here. The legacy
    57		-- `google_drive` config above remains supported for backward compatibility.
    58		oauth = {
    59			dropbox = {
    60				client_id = "",
    61				client_secret = "",
    62				redirect_port = nil,
    63				scopes = { "sharing.read" },
    64			},
    65			google = {
    66				client_id = "",
    67				client_secret = "",
    68				redirect_port = nil,
    69				scopes = { "https://www.googleapis.com/auth/drive.readonly" },
    70			},
    71		},
    72
    73		-- at least one working provider is required
    74		-- to disable a provider set it to empty table like openai = {}
    75		providers = {
    76			openai = {
    77				disable = false,
    78				endpoint = "https://api.openai.com/v1/chat/completions",
    79				-- secret will be loaded from api_keys.openai
    80			},
    81			anthropic = {
    82				disable = false,
    83				endpoint = "https://api.anthropic.com/v1/messages",
    84				-- secret will be loaded from api_keys.anthropic
    85			},
    86			googleai = {
    87				disable = false,
    88				endpoint = "https://generativelanguage.googleapis.com/v1beta/models/{{model}}:streamGenerateContent?key={{secret}}",
    89				-- secret will be loaded from api_keys.googleai
    90			},
    91			ollama = {
    92				disable = true,
    93				endpoint = "http://localhost:11434/v1/chat/completions",
    94				-- secret will be loaded from api_keys.ollama
    95			},
    96			cliproxyapi = {
    97				disable = false,
    98				endpoint = "http://127.0.0.1:8317/v1/chat/completions",
    99				-- default strategy; model.web_search_strategy can override per agent/model
   100				-- none | openai_search_model | openai_tools_route | anthropic_tools_route
   101				web_search_strategy = "openai_tools_route",
   102				-- secret will be loaded from api_keys.cliproxyapi
   103			},
   104		},
   105
   106		-- Let parley manage the cliproxyapi process itself (issue #131). parley
   107		-- renders config.yaml from this block on demand and lazily starts / reuses /
   108		-- health-checks the proxy whenever a cliproxyapi-provider agent is used. It
   109		-- is DORMANT unless such an agent runs, and it REUSES an already-running proxy
   110		-- (e.g. `brew services`) if one answers healthy — so this default is safe even
   111		-- if you don't use cliproxyapi. host:port come from providers.cliproxyapi.endpoint
   112		-- (single source of truth); the generated config is a derived 0600 artifact
   113		-- under stdpath('data') — your committed Lua is the source of truth, no secret
   114		-- in it. A new machine needs only: `brew install cliproxyapi` + one-time
   115		-- `:ParleyProxy login <provider>` (OAuth). Set manage=false to opt out.
   116		cliproxy = {
   117			manage = true,
   118			-- auth_dir defaults to cliproxy's own ~/.cli-proxy-api when omitted.
   119			-- binary_path = nil,  -- else `cliproxyapi` / `cli-proxy-api` on PATH
   120			auto_download = true,  -- if no cliproxy binary is found, fetch a pinned,
   121			--   checksum-verified release into stdpath('data') (skips `brew install`).
   122			--   ON in this config. NOTE: auto-fetching an executable is a trust
   123			--   decision — a general distribution may prefer to comment this out (the
   124			--   original opt-in default; see issue #131 spec). `:ParleyProxy update`
   125			--   re-fetches; `download_version` overrides the pin.
   126			-- Raw cliproxyapi config, rendered into the proxy's config.yaml. This is
   127			-- where parley drives cliproxyapi as a wrapped dependency — tinker here in
   128			-- Lua instead of hand-editing /opt/homebrew/etc/cliproxyapi.conf.
   129			config = {
   130				-- skip the management-panel GitHub download for faster startup
   131				["remote-management"] = { ["disable-control-panel"] = true },
   132				-- Route model NAMES to the Claude OAuth credential in auth-dir (the
   133				-- cliproxyapi-provider agents below use them). Without this,
   134				-- cliproxyapi answers "unknown provider for model claude-…". Keyed by
   135				-- cliproxyapi's CANONICAL channel name (`claude`) — so the key == the
   136				-- provider, which is how parley resolves "which login does this model
   137				-- need" on an auth failure. Extend for custom models. Channels:
   138				-- claude / codex / gemini-cli / vertex / aistudio / kimi / antigravity.
   139				-- Verified against cliproxyapi 7.1.71.
   140				["oauth-model-alias"] = {
   141					["claude"] = {
   142						{ name = "claude-fable-5", alias = "claude-fable-5", fork = true },
   143						{ name = "claude-sonnet-5", alias = "claude-sonnet-5", fork = true },
   144						{ name = "claude-opus-4-8", alias = "claude-opus-4-8", fork = true },
   145						{ name = "claude-fable-5", alias = "claude-fable-5", fork = true },
   146					},
   147				},
   148			},
   149		},
   150
   151		-- prefix for all commands
   152		cmd_prefix = "Parley",
   153		-- optional curl parameters (for proxy, etc.)
   154		-- curl_params = { "--proxy", "http://X.X.X.X:XXXX" }
   155		curl_params = {},
   156
   157		-- log file location
   158		log_file = vim.fn.stdpath("log"):gsub("/$", "") .. "/parley.nvim.log",
   159		-- write sensitive data to log file for debugging purposes (like api keys)
   160		log_sensitive = false,
   161
   162		-- directory for persisting state dynamically changed by user (like model or persona)
   163		-- directory for persisting state dynamically changed by user (like model or persona)
   164		state_dir = vim.fn.stdpath("data"):gsub("/$", "") .. "/parley/persisted",
   165		-- default per-chat: enable server-side web_search tool (supported by Anthropic, GoogleAI, OpenAI)
   166		web_search = true,
   167
   168		-- default agent name set during startup, if nil last used agent is used
   169		default_agent = nil,
   170
   171		-- default agents (model + persona)
   172		-- name, model and system_prompt are mandatory fields
   173		-- to remove some default agent completely set it like:
   174		-- agents = {  { name = "ChatGPT3-5", disable = true, }, ... },
   175		agents = {
   176			{
   177				provider = "openai",
   178				name = "GPT5.4",
   179				-- string with model name or table with model name and parameters
   180				-- search_model: when web_search is enabled, swap to this model
   430		-- explicitly confirm deletion of a chat file
   431		chat_confirm_delete = true,
   432		-- conceal model parameters in chat
   433		chat_conceal_model_params = true,
   434		-- spellcheck + as-you-type spell-suggestion typeahead in chat buffers.
   435		-- `enable` turns on visible spell underlines (vim `spell`); `typeahead` pops a
   436		-- completion menu of `spellsuggest()` results when a misspelled word ≥ `min_word`
   437		-- chars is typed (built-in `spellsuggest`/`spellbadword`, no plugin). The two are
   438		-- independent — `spellsuggest()` works even with `spell` off.
   439		chat_spell = {
   440			enable = true, -- visible spell underlines on chat buffers
   441			typeahead = true, -- as-you-type spell-suggestion popup + <CR> handling
   442			spelllang = "en_us",
   443			min_word = 4, -- min misspelled-word length before suggesting
   444			max_suggest = 9, -- max suggestions shown in the menu
   445		},
   446		-- local shortcuts bound to the chat buffer
   447		-- (be careful to choose something which will work across specified modes)
   448		chat_shortcut_respond = { modes = { "n", "i", "v", "x" }, shortcut = { "<C-g><C-g>" } },
   449		-- #161: <M-CR> owns its own binding so visual mode routes to inline term
   450		-- definition while n/i keep respond (one entry can't split key×mode). Visual
   451		-- <C-g><C-g> stays respond, preserving the line-scoped resubmit.
   452		chat_shortcut_define = { modes = { "n", "i", "v", "x" }, shortcut = "<M-CR>" },
   453		chat_shortcut_respond_all = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>G" },
   454		chat_shortcut_delete = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>d" },
   455		chat_shortcut_delete_tree = { modes = { "n" }, shortcut = "<C-g>D" },
   456		chat_shortcut_stop = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>x" },
   457		-- Toggle folds of 🔧:/📎: components within the exchange under cursor.
   458		-- Intentionally unbound by default; configure chat_shortcut_toggle_tool_folds
   459		-- to opt in.
   460		chat_shortcut_agent = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>a" },
   461		chat_shortcut_system_prompt = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>P" },
   462		chat_shortcut_follow_cursor = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>l" },
   463		chat_shortcut_search = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>n" },
   464		chat_shortcut_open_file = { modes = { "n", "i" }, shortcut = "<C-g>o" },
   465		-- #160: smart `gf` — resolve an ariadne artifact ref under the cursor (via
   466		-- `sdlc resolve`), else native go-to-file. Transparent (native gf preserved on
   467		-- plain paths); remap here to disable.
   468		chat_shortcut_resolve_ref_gf = { modes = { "n" }, shortcut = "gf" },
   469		chat_shortcut_prune = { modes = { "n" }, shortcut = "<C-g>b" },
   470		chat_shortcut_export_markdown = { modes = { "n" }, shortcut = "<C-g>em" },
   471		chat_shortcut_export_html = { modes = { "n" }, shortcut = "<C-g>eh" },
   472		chat_shortcut_exchange_cut = { modes = { "n", "v" }, shortcut = "<C-g>X" },
   473		chat_shortcut_exchange_paste = { modes = { "n" }, shortcut = "<C-g>V" },
   474		chat_shortcut_copy_fence = { modes = { "n" }, shortcut = "<leader>cf" },
   475		-- global shortcuts (available in any buffer)
   476		global_shortcut_copy_location = { modes = { "n", "v" }, shortcut = "<leader>cl" },
   477		global_shortcut_copy_location_content = { modes = { "n", "v" }, shortcut = "<leader>cL" },
   478		global_shortcut_copy_context = { modes = { "n", "v" }, shortcut = "<leader>cc" },
   479		global_shortcut_copy_context_wide = { modes = { "n", "v" }, shortcut = "<leader>cC" },
   480		global_shortcut_new = { modes = { "n", "i" }, shortcut = "<C-g>c" },
   481		global_shortcut_review = { modes = { "n" }, shortcut = "<C-g>C" },
   482		global_shortcut_finder = { modes = { "n", "i" }, shortcut = "<C-g>f" },
   483		global_shortcut_keybindings = { modes = { "n", "i" }, shortcut = "<C-g>?" },
   484		-- shortcut for adding chat references in markdown files
   485		global_shortcut_add_chat_ref = { modes = { "n", "i" }, shortcut = "<C-g>a" },
   486		-- global shortcuts for note taking
   487		global_shortcut_note_new = { modes = { "n", "i" }, shortcut = "<C-n>c" },
   488		global_shortcut_note_finder = { modes = { "n", "i" }, shortcut = "<C-n>f" },
   489		global_shortcut_year_root = { modes = { "n", "i" }, shortcut = "<C-n>r" },
   490		global_shortcut_note_dirs = { modes = { "n", "i" }, shortcut = "<C-n>h" },
   550		-- root for src: URL scheme (parent of sibling repos). nil = auto-detect via git rev-parse.
   551		src_root = nil,
   552		-- #160: the ariadne `sdlc` command used to resolve artifact refs (ariadne#11,
   553		-- #15 M4, pair#84) under the cursor. Point this at the sdlc BINARY — a shell
   554		-- *function* named `sdlc` is not reachable from vim.system. If a real `sdlc`
   555		-- binary is on $PATH, "sdlc" works as-is; otherwise set an absolute path
   556		-- (e.g. "~/workspace/ariadne/bin/sdlc"). Read-only, so it's lock-free + fast.
   557		sdlc_cmd = "sdlc",
   558		-- issue history (repo-local, relative to git root)
   559		history_dir = "workshop/history",
   560		-- vision tracker (repo-local, relative to git root)
   561		vision_dir = "workshop/vision",
   562		-- global shortcuts for vision tracker
   563		global_shortcut_vision_validate = { modes = { "n" }, shortcut = "<C-j>v" },
   564		global_shortcut_vision_export_csv = { modes = { "n" }, shortcut = "<C-j>ec" },
   565		global_shortcut_vision_export_dot = { modes = { "n" }, shortcut = "<C-j>ed" },
   566		global_shortcut_vision_finder = { modes = { "n", "i" }, shortcut = "<C-j>f" },
   567		global_shortcut_vision_new = { modes = { "n" }, shortcut = "<C-j>n" },
   568		global_shortcut_vision_goto = { modes = { "n" }, shortcut = "<C-j>o" },
   569		-- global shortcuts for markdown file finder
   570		global_shortcut_markdown_finder = { modes = { "n", "i" }, shortcut = "<C-g>m" },
   571		-- maximum directory depth for markdown finder (from repo root)
   572		markdown_finder_max_depth = 6,
   573		-- super-repo mode toggle (aggregates reads across sibling .parley repos)
   574		global_shortcut_super_repo_toggle = { modes = { "n", "i" }, shortcut = "<C-g>p" },
   575		-- global shortcuts for issue management
   576		global_shortcut_issue_new = { modes = { "n", "i" }, shortcut = "<C-y>c" },
   577		global_shortcut_issue_finder = { modes = { "n", "i" }, shortcut = "<C-y>f" },
   578		global_shortcut_issue_next = { modes = { "n", "i" }, shortcut = "<C-y>x" },
   579		global_shortcut_issue_status = { modes = { "n" }, shortcut = "<C-y>s" },
   580		global_shortcut_issue_decompose = { modes = { "n" }, shortcut = "<C-y>i" },
   581		global_shortcut_issue_goto = { modes = { "n" }, shortcut = "<C-y>g" },
   582		issue_finder_mappings = {
   583			delete = { modes = { "n", "i", "v", "x" }, shortcut = "<C-d>" },
   584			cycle_status = { modes = { "n", "i", "v", "x" }, shortcut = "<C-s>" },
   585			-- cycle the 2-state view (issues ↔ history); <Tab> is the natural key,
   586			-- <C-a> kept for back-compat — both trigger the same cycle (#158).
   587			cycle_view = { modes = { "n", "i", "v", "x" }, shortcut = "<Tab>" },
   588			toggle_done = { modes = { "n", "i", "v", "x" }, shortcut = "<C-a>" },
   589		},
   590
./atlas/index.md:66:- [Super-Repo Mode](modes/super_repo.md): Toggle peers (`<C-g>p`) to aggregate reads across sibling `.parley` repos; the explicit choice persists per repository.
./README.md:127:- `<C-g>p` toggle peer (super-repo) mode - aggregate reads across sibling
./README.md:144:- `<C-g>b` branch/prune - move the current exchange and following exchanges to
./README.md:148:`chat_shortcut_toggle_tool_folds = { modes = { "n" }, shortcut = "<leader>tf" }`.
./atlas/infra/repo_mode.md:33:`state.json.repo_modes` separately stores each canonical repo root's explicit
./atlas/chat/lifecycle.md:12:## Branching / Pruning (`<C-g>b`)
./atlas/chat/lifecycle.md:16:`chat_shortcut_toggle_tool_folds`, but has no default mapping. A configured
./workshop/issues/000190-persist-repo-super-repo-state-across-nvim-sessions.md:22:The mode toggle also uses `<C-g>S`, while the desired mnemonic is `<C-g>p` for
./workshop/issues/000190-persist-repo-super-repo-state-across-nvim-sessions.md:24:`<C-g>b` is currently used by the optional tool-fold toggle.
./workshop/issues/000190-persist-repo-super-repo-state-across-nvim-sessions.md:29:  existing `state.json`. The stored shape is a `repo_modes` map from canonical,
./workshop/issues/000190-persist-repo-super-repo-state-across-nvim-sessions.md:52:- Selection treats a non-table `repo_modes` value as empty and recognizes only
./workshop/issues/000190-persist-repo-super-repo-state-across-nvim-sessions.md:70:  mode from `(repo_modes, canonical_root)` and returning an updated fresh map
./workshop/issues/000190-persist-repo-super-repo-state-across-nvim-sessions.md:73:- Change the global peer-mode toggle default from `<C-g>S` to `<C-g>p` in normal
./workshop/issues/000190-persist-repo-super-repo-state-across-nvim-sessions.md:74:  and insert mode. Change chat branch/prune from `<C-g>p` to `<C-g>b` in normal
./workshop/issues/000190-persist-repo-super-repo-state-across-nvim-sessions.md:75:  mode. Remove the default key for `chat_shortcut_toggle_tool_folds`; users may
./workshop/issues/000190-persist-repo-super-repo-state-across-nvim-sessions.md:104:- `<C-g>p` toggles peer aggregation, `<C-g>b` branches/prunes a chat, and the
./workshop/issues/000190-persist-repo-super-repo-state-across-nvim-sessions.md:142:  `repo_modes` map in existing state rather than modifying `.parley` or adding
./workshop/issues/000190-persist-repo-super-repo-state-across-nvim-sessions.md:145:- Keybinding design: `<C-g>p` becomes the peer overlay toggle, `<C-g>b` becomes
./workshop/issues/000190-persist-repo-super-repo-state-across-nvim-sessions.md:163:- Migrated peer toggle to `<C-g>p` and chat branch/prune to `<C-g>b`. Tool-fold
./workshop/issues/000129-capability-based-tool-permission-model-for-skills.md:58:  mode `<C-g>S`), never as an accidental bleed from a one-shot invocation. Two
./lua/parley/super_repo.lua:11:-- user choices and restores them through set_active().
./lua/parley/super_repo.lua:224:	return M.set_active(not _state.active)
./lua/parley/init.lua:70:M.toggle_super_repo = function()
./lua/parley/init.lua:80:		M._state.repo_modes = repo_mode.updated(M._state.repo_modes, canonical_root, mode)
./lua/parley/init.lua:81:		local persisted = M.persist_state()
./lua/parley/init.lua:763:		local saved_mode = repo_mode.resolve(M._state.repo_modes, canonical_root)
./lua/parley/init.lua:764:		super_repo.set_active(saved_mode == "super_repo")
./lua/parley/init.lua:811:				M.toggle_super_repo()
./lua/parley/init.lua:1180:	return M.helpers.table_to_file_atomic(persist_state, state_file)
./lua/parley/init.lua:1300:	local persisted, persist_err = M.persist_state()
./atlas/modes/super_repo.md:10:- **Toggle peers**: `<C-g>p` (`global_shortcut_super_repo_toggle`).
./atlas/modes/super_repo.md:16:  `super_repo` under the canonical current repo root in `state.json.repo_modes`.
./atlas/modes/super_repo.md:120:- `lua/parley/init.lua` — wires `parley.toggle_super_repo()` /
./lua/parley/config.lua:458:	-- Intentionally unbound by default; configure chat_shortcut_toggle_tool_folds
./lua/parley/config.lua:469:	chat_shortcut_prune = { modes = { "n" }, shortcut = "<C-g>b" },
./lua/parley/config.lua:574:	global_shortcut_super_repo_toggle = { modes = { "n", "i" }, shortcut = "<C-g>p" },
./lua/parley/keybinding_registry.lua:195:		config_key = "global_shortcut_super_repo_toggle",
./lua/parley/keybinding_registry.lua:574:		config_key = "chat_shortcut_prune",
./lua/parley/keybinding_registry.lua:623:		config_key = "chat_shortcut_toggle_tool_folds",
./workshop/plans/000190-persist-repo-super-repo-state-across-nvim-sessions-plan.md:40:| `helper.table_to_file_atomic` | `lua/parley/helper.lua` | new | JSON encoding, temporary-file IO, atomic rename |
./workshop/plans/000190-persist-repo-super-repo-state-across-nvim-sessions-plan.md:43:| `parley.toggle_super_repo` | `lua/parley/init.lua` | modified | runtime overlay transition, durable preference, bounded warning |
./workshop/plans/000190-persist-repo-super-repo-state-across-nvim-sessions-plan.md:46:- **`helper.table_to_file_atomic`** — writes encoded JSON beside the destination, renames only after a complete close, reports `(true)` or `(false, err)`, and leaves the prior file intact on failure.
./workshop/plans/000190-persist-repo-super-repo-state-across-nvim-sessions-plan.md:55:- **`parley.toggle_super_repo`** — persists the resulting preference only after a successful explicit runtime transition; persistence failure keeps runtime state and warns once.
./workshop/plans/000190-persist-repo-super-repo-state-across-nvim-sessions-plan.md:73:Cover `resolve(repo_modes, canonical_root)` returning `nil` for non-table maps, empty/non-string roots, missing entries, and unknown values; returning exact valid values; and keeping repo A isolated from repo B. Cover `updated(repo_modes, root, mode)` returning a fresh map, preserving only valid entries with non-empty string roots, discarding malformed entries, replacing the current root, starting empty for non-table input, and never mutating its input.
./workshop/plans/000190-persist-repo-super-repo-state-across-nvim-sessions-plan.md:105:Add tests proving `table_to_file_atomic` returns true and round-trips nested JSON. Through an optional IO adapter, force write, close, and rename failures independently; each must return false plus a bounded error, remove its unique sibling temporary file, and preserve pre-existing destination bytes byte-for-byte. Encoding happens before any destination-adjacent file is opened, so an encode exception is inherently destination-safe and must also return a bounded failure.
./workshop/plans/000190-persist-repo-super-repo-state-across-nvim-sessions-plan.md:111:Expected: FAIL because `table_to_file_atomic` is undefined.
./workshop/plans/000190-persist-repo-super-repo-state-across-nvim-sessions-plan.md:125:Add production-facing tests that call the wished-for `parley.persist_state()`: it must omit `chat_roots`/`chat_dirs`, repo-labeled and super-repo-pushed note roots; preserve durable scalar state and `repo_modes`; and leave the active overlay roots byte-for-byte unchanged. Add an injected writer-failure test asserting `(false, err)`, no root reload/mutation, and that the writer received the correctly sanitized snapshot before failing.
./workshop/plans/000190-persist-repo-super-repo-state-across-nvim-sessions-plan.md:135:Move the snapshot/filter/write tail of `refresh_state` into `M.persist_state()`, returning the atomic writer result. Make `refresh_state` call it once after its load/update/root-restoration work. Keep display refresh in `refresh_state`, not the write-only function.
./workshop/plans/000190-persist-repo-super-repo-state-across-nvim-sessions-plan.md:159:Add tests for `super_repo.set_active(true|false)` being idempotent and non-persisting. Through `parley.toggle_super_repo`, assert successful on/off transitions update the current canonical root in `repo_modes`, preserve valid peer entries, and atomically persist; activation failure changes neither runtime state nor saved preference. Add a successful-runtime/failed-save regression starting from an existing state file: runtime and in-memory preference change, durable bytes remain identical, exactly one bounded warning contains “preference not saved,” and no success notification is emitted.
./workshop/plans/000190-persist-repo-super-repo-state-across-nvim-sessions-plan.md:169:Export idempotent `super_repo.set_active(active)` as the non-persisting overlay API. Make `M.toggle_super_repo()` call the runtime toggle, update `M._state.repo_modes` through `repo_mode.updated` only on success, then call `M.persist_state`. On write failure, retain runtime mode and in-memory choice while emitting one bounded warning containing “preference not saved”; preserve the existing boolean runtime-transition return contract so callers do not misread persistence failure as transition failure.
./workshop/plans/000190-persist-repo-super-repo-state-across-nvim-sessions-plan.md:189:Delete the `.brain` autocmd block. After the initial `refresh_state()` and optional default-agent `refresh_state(...)`, canonicalize `M.config.repo_root`, resolve its saved mode, and call `super_repo.set_active(mode == "super_repo")` exactly once for repo mode. Do nothing in global mode. A failed saved-super activation keeps the preference and uses the existing bounded warning path. Map the policy, state persistence, runtime transition, setup restoration, and toggle orchestration surfaces to `tests/unit/repo_mode_spec.lua`, `tests/unit/helper_io_spec.lua`, and `tests/unit/super_repo_spec.lua` in traceability.
./workshop/plans/000190-persist-repo-super-repo-state-across-nvim-sessions-plan.md:213:Assert exposed config owns peer toggle `<C-g>p` in normal/insert and chat prune `<C-g>b` in normal, while tool-fold config is absent by default. Assert the three migrated registry entries carry no independent `default_key` and resolve solely from their `config_key`, so registration/help cannot drift from exposed config. Assert a configurable entry with no default is valid; absent or empty-string tool-fold configuration produces neither mapping nor help row; and a user config `{ modes = { "n" }, shortcut = "<leader>tf" }` restores both registration and help through the shared resolver.
./workshop/plans/000190-persist-repo-super-repo-state-across-nvim-sessions-plan.md:253:Document `<C-g>p` as peer-mode toggle, `<C-g>b` as branch/prune, tool-fold as configurable with no default, per-canonical-repo persistence in `state.json`, ordinary unsaved default, synchronous startup restore, and brain parity. Add README discoverability for the peer toggle and configuration override.
./workshop/plans/000190-persist-repo-super-repo-state-across-nvim-sessions-plan.md:257:Run: `rg -n '<C-g>S|Pruning \(`<C-g>p`\)|chat_shortcut_toggle_tool_folds.*<C-g>b|Brain repos auto|Toggle is transient|never persisted' README.md atlas lua tests`
./workshop/plans/000190-persist-repo-super-repo-state-across-nvim-sessions-plan.md:307:- Delta: count expected refresh writes and forbid only post-restoration writes while preserving `repo_modes`; name concrete traceability keys and selection commands for every changed atlas surface.
./lua/parley/repo_mode.lua:11:M.resolve = function(repo_modes, canonical_root)
./lua/parley/repo_mode.lua:12:    if type(repo_modes) ~= "table" or not valid_root(canonical_root) then
./lua/parley/repo_mode.lua:15:    local mode = repo_modes[canonical_root]
./lua/parley/repo_mode.lua:22:M.updated = function(repo_modes, canonical_root, mode)
./lua/parley/repo_mode.lua:24:    if type(repo_modes) == "table" then
./lua/parley/repo_mode.lua:25:        for root, saved_mode in pairs(repo_modes) do
./lua/parley/helper.lua:444:_H.table_to_file_atomic = function(tbl, file_path, adapter)
./tests/unit/config_tools_spec.lua:340:        assert.equals("<C-g>p", parley.config.global_shortcut_super_repo_toggle.shortcut)
./tests/unit/config_tools_spec.lua:341:        assert.same({ "n", "i" }, parley.config.global_shortcut_super_repo_toggle.modes)
./tests/unit/config_tools_spec.lua:342:        assert.equals("<C-g>b", parley.config.chat_shortcut_prune.shortcut)
./tests/unit/config_tools_spec.lua:343:        assert.same({ "n" }, parley.config.chat_shortcut_prune.modes)
./tests/unit/config_tools_spec.lua:344:        assert.is_nil(parley.config.chat_shortcut_toggle_tool_folds)
./tests/unit/super_repo_spec.lua:135:			parley.toggle_super_repo()
./tests/unit/super_repo_spec.lua:145:		assert.is_true(parley.toggle_super_repo())
./tests/unit/super_repo_spec.lua:163:		parley.toggle_super_repo()
./tests/unit/super_repo_spec.lua:182:		parley.toggle_super_repo()
./tests/unit/super_repo_spec.lua:192:		parley.toggle_super_repo()
./tests/unit/super_repo_spec.lua:198:		parley.toggle_super_repo()
./tests/unit/super_repo_spec.lua:207:		parley.toggle_super_repo()
./tests/unit/super_repo_spec.lua:209:		parley.toggle_super_repo()
./tests/unit/super_repo_spec.lua:223:		parley.toggle_super_repo()
./tests/unit/super_repo_spec.lua:228:		parley.toggle_super_repo()
./tests/unit/super_repo_spec.lua:238:		local ok = parley.toggle_super_repo()
./tests/unit/super_repo_spec.lua:246:		local original_writer = parley.helpers.table_to_file_atomic
./tests/unit/super_repo_spec.lua:247:		parley.helpers.table_to_file_atomic = function()
./tests/unit/super_repo_spec.lua:252:		assert.is_true(parley.super_repo.set_active(true))
./tests/unit/super_repo_spec.lua:254:		assert.is_true(parley.super_repo.set_active(true))
./tests/unit/super_repo_spec.lua:256:		assert.is_true(parley.super_repo.set_active(false))
./tests/unit/super_repo_spec.lua:257:		assert.is_true(parley.super_repo.set_active(false))
./tests/unit/super_repo_spec.lua:258:		parley.helpers.table_to_file_atomic = original_writer
./tests/unit/super_repo_spec.lua:265:		parley._state.repo_modes = {
./tests/unit/super_repo_spec.lua:270:		assert.is_true(parley.toggle_super_repo())
./tests/unit/super_repo_spec.lua:272:		assert.equals("super_repo", on_state.repo_modes[resolve(current_repo)])
./tests/unit/super_repo_spec.lua:273:		assert.equals("repo", on_state.repo_modes[resolve(sibling_a)])
./tests/unit/super_repo_spec.lua:274:		assert.is_nil(on_state.repo_modes.invalid)
./tests/unit/super_repo_spec.lua:276:		assert.is_true(parley.toggle_super_repo())
./tests/unit/super_repo_spec.lua:278:		assert.equals("repo", off_state.repo_modes[resolve(current_repo)])
./tests/unit/super_repo_spec.lua:279:		assert.equals("repo", off_state.repo_modes[resolve(sibling_a)])
./tests/unit/super_repo_spec.lua:287:		assert.is_true(parley.toggle_super_repo())
./tests/unit/super_repo_spec.lua:289:		assert.equals("super_repo", parley._state.repo_modes[resolve(current_repo)])
./tests/unit/super_repo_spec.lua:290:		assert.is_nil(parley._state.repo_modes[linked_repo])
./tests/unit/super_repo_spec.lua:294:		parley._state.repo_modes = { [resolve(current_repo)] = "repo" }
./tests/unit/super_repo_spec.lua:295:		local before = vim.deepcopy(parley._state.repo_modes)
./tests/unit/super_repo_spec.lua:298:		assert.is_false(parley.toggle_super_repo())
./tests/unit/super_repo_spec.lua:301:		assert.same(before, parley._state.repo_modes)
./tests/unit/super_repo_spec.lua:307:		local original_writer = parley.helpers.table_to_file_atomic
./tests/unit/super_repo_spec.lua:310:		parley.helpers.table_to_file_atomic = function() return false, "forced failure" end
./tests/unit/super_repo_spec.lua:313:		local ok = parley.toggle_super_repo()
./tests/unit/super_repo_spec.lua:314:		parley.helpers.table_to_file_atomic = original_writer
./tests/unit/super_repo_spec.lua:319:		assert.equals("super_repo", parley._state.repo_modes[resolve(current_repo)])
./tests/unit/super_repo_spec.lua:420:		parley.toggle_super_repo()
./tests/unit/super_repo_spec.lua:443:		parley.toggle_super_repo()
./tests/unit/super_repo_spec.lua:470:		parley.toggle_super_repo()
./tests/unit/super_repo_spec.lua:471:		parley._state.repo_modes = {
./tests/unit/super_repo_spec.lua:479:		local ok, err = parley.persist_state()
./tests/unit/super_repo_spec.lua:489:		assert.same(parley._state.repo_modes, persisted.repo_modes)
./tests/unit/super_repo_spec.lua:497:		parley.toggle_super_repo()
./tests/unit/super_repo_spec.lua:498:		parley._state.repo_modes = { [resolve(current_repo)] = "super_repo" }
./tests/unit/super_repo_spec.lua:502:		local original_writer = parley.helpers.table_to_file_atomic
./tests/unit/super_repo_spec.lua:503:		parley.helpers.table_to_file_atomic = function(snapshot)
./tests/unit/super_repo_spec.lua:508:		local ok, err = parley.persist_state()
./tests/unit/super_repo_spec.lua:509:		parley.helpers.table_to_file_atomic = original_writer
./tests/unit/super_repo_spec.lua:516:		assert.same(parley._state.repo_modes, captured.repo_modes)
./tests/unit/super_repo_spec.lua:700:		parley.toggle_super_repo()
./tests/unit/super_repo_spec.lua:701:		parley.toggle_super_repo()
./tests/unit/super_repo_spec.lua:732:			vim.fn.writefile({ vim.json.encode({ repo_modes = seed_modes }) }, state_dir .. "/state.json")
./tests/unit/super_repo_spec.lua:735:		if parley.is_super_repo_active() then parley.super_repo.set_active(false) end
./tests/unit/super_repo_spec.lua:744:		if parley.is_super_repo_active() then parley.super_repo.set_active(false) end
./tests/unit/super_repo_spec.lua:753:			local original_writer = parley.helpers.table_to_file_atomic
./tests/unit/super_repo_spec.lua:754:			parley.helpers.table_to_file_atomic = function(snapshot, path, adapter)
./tests/unit/super_repo_spec.lua:760:			parley.helpers.table_to_file_atomic = original_writer
./tests/unit/super_repo_spec.lua:764:				assert.equals("super_repo", snapshot.repo_modes[resolve(ctx.current)])
./tests/unit/super_repo_spec.lua:809:			local original_writer = parley.helpers.table_to_file_atomic
./tests/unit/super_repo_spec.lua:814:			parley.helpers.table_to_file_atomic = function(snapshot, path, adapter)
./tests/unit/super_repo_spec.lua:822:			parley.helpers.table_to_file_atomic = original_writer
./tests/unit/super_repo_spec.lua:826:			assert.equals("super_repo", parley._state.repo_modes[resolve(ctx.current)])
./tests/unit/super_repo_spec.lua:828:			assert.equals("super_repo", persisted.repo_modes[resolve(ctx.current)])
./tests/unit/helper_io_spec.lua:230:        it("F5: table_to_file_atomic replaces complete JSON and reports success", function()
./tests/unit/helper_io_spec.lua:234:            local ok, err = helper.table_to_file_atomic({ nested = { value = 42 } }, path)
./tests/unit/helper_io_spec.lua:246:            local ok, err = helper.table_to_file_atomic({}, path, {
./tests/unit/helper_io_spec.lua:274:                local ok, err = helper.table_to_file_atomic({}, path, {
./tests/unit/helper_io_spec.lua:300:            local ok, err = helper.table_to_file_atomic({ changed = true }, path, {
./tests/unit/keybindings_spec.lua:170:        assert.is_true(has_line(lines, "<C-g>b", "Prune"))
./tests/unit/keybindings_spec.lua:171:        assert.is_false(has_line(lines, "<C-g>b", "Toggle tool folds"))
./tests/unit/keybindings_spec.lua:177:            chat_shortcut_toggle_tool_folds = { modes = { "n" }, shortcut = "<leader>tf" },
./tests/unit/keybindings_spec.lua:186:            chat_shortcut_toggle_tool_folds = { modes = { "n" }, shortcut = "" },
./tests/unit/keybindings_spec.lua:265:            { id = "super_repo_toggle", key = "<C-g>p", modes = { "n", "i" } },
./tests/unit/keybindings_spec.lua:266:            { id = "chat_prune", key = "<C-g>b", modes = { "n" } },
./tests/unit/keybindings_spec.lua:278:        assert.is_true(has_line(parley._keybinding_help_lines("other"), "<C-g>p", "super-repo"))
./tests/unit/keybindings_spec.lua:279:        assert.is_true(has_line(parley._keybinding_help_lines("chat"), "<C-g>b", "Prune"))
./tests/unit/keybindings_spec.lua:294:            chat_shortcut_toggle_tool_folds = { modes = { "n" }, shortcut = "<leader>tf" },

exec
/bin/zsh -lc "nl -ba lua/parley/super_repo.lua | sed -n '1,250p' && nl -ba lua/parley/helper.lua | sed -n '430,515p' && nl -ba lua/parley/keybinding_registry.lua | sed -n '900,1020p' && nl -ba lua/parley/init.lua | sed -n '1180,1320p' && nl -ba lua/parley/init.lua | sed -n '790,825p' && rg -n \"function M.resolve_keys|resolve_keys\\(|resolve_display_shortcut|register_buffer|register_global\" lua/parley/keybinding_registry.lua && rg -n \"M.setup =|function.*setup|vim.tbl_deep_extend|config\" lua/parley/config.lua | head -80" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
     1	-- parley.super_repo — super-repo mode (read-aggregation overlay)
     2	--
     3	-- Toggle activates a runtime overlay on top of plain repo mode:
     4	--   * Discovers sibling .parley repos under the current repo's parent dir.
     5	--   * Pushes their workshop/parley and workshop/notes paths into chat_roots
     6	--     and note_roots as labelled transient extras.
     7	--   * Writes are unchanged: still go to the current repo, exactly as plain
     8	--     repo mode does today.
     9	--
    10	-- This module owns only the runtime overlay. parley.init persists explicit
    11	-- user choices and restores them through set_active().
    12
    13	local M = {}
    14	local _parley
    15
    16	-- Active state. Cleared on toggle-off.
    17	local _state = {
    18		active = false,
    19		workspace_root = nil,
    20		members = {},          -- list of { path, name }
    21		pushed_chat_dirs = {}, -- resolved paths we appended (for cleanup)
    22		pushed_note_dirs = {}, -- resolved paths we appended (for cleanup)
    23	}
    24
    25	local function resolve_dir_key(dir)
    26		local out = vim.fn.resolve(vim.fn.expand(dir)):gsub("/+$", "")
    27		return out
    28	end
    29
    30	M.setup = function(parley)
    31		_parley = parley
    32	end
    33
    34	M.is_active = function()
    35		return _state.active
    36	end
    37
    38	M.get_state = function()
    39		return {
    40			active = _state.active,
    41			workspace_root = _state.workspace_root,
    42			members = vim.deepcopy(_state.members),
    43		}
    44	end
    45
    46	--- Resolved paths of sibling chat dirs currently pushed into chat_roots.
    47	--- Used by the persistence gate in init.lua to exclude these from state.json.
    48	M.get_pushed_chat_dirs = function()
    49		return vim.deepcopy(_state.pushed_chat_dirs)
    50	end
    51
    52	--- Resolved paths of sibling note dirs currently pushed into note_roots.
    53	M.get_pushed_note_dirs = function()
    54		return vim.deepcopy(_state.pushed_note_dirs)
    55	end
    56
    57	--- Compute per-finder roots for a given repo-relative subdir (e.g. "workshop/issues").
    58	--- When super-repo is active and has members, returns a list of
    59	--- `{ dir = <abs>, repo_name = <name> }` per member. Otherwise returns nil so
    60	--- the caller falls back to its single-repo path.
    61	--- @param subdir string repo-relative path (or absolute; absolute is left as-is)
    62	--- @return table|nil list of {dir, repo_name} or nil for single-repo
    63	M.expand_roots = function(subdir)
    64		if not _state.active or #_state.members == 0 then
    65			return nil
    66		end
    67		if type(subdir) ~= "string" or subdir == "" then
    68			return nil
    69		end
    70		local roots = {}
    71		for _, m in ipairs(_state.members) do
    72			local dir = subdir
    73			if dir:sub(1, 1) ~= "/" then
    74				dir = m.path .. "/" .. dir
    75			end
    76			table.insert(roots, { dir = dir, repo_name = m.name })
    77		end
    78		return roots
    79	end
    80
    81	--- Compute sibling .parley repos under repo_root's parent directory.
    82	--- Returns { workspace_root, members } where members is a list of
    83	--- { path, name } sorted by name. Returns nil, err on failure.
    84	M.compute_members = function(repo_root)
    85		if type(repo_root) ~= "string" or repo_root == "" then
    86			return nil, "repo_root is empty"
    87		end
    88		local resolved = resolve_dir_key(repo_root)
    89		local workspace_root = vim.fn.fnamemodify(resolved, ":h")
    90		if not workspace_root or workspace_root == "" or workspace_root == "/" or workspace_root == resolved then
    91			return nil, "repo_root has no parent"
    92		end
    93		local matches = vim.fn.glob(workspace_root .. "/*/.parley", false, true) or {}
    94		local members = {}
    95		for _, marker in ipairs(matches) do
    96			local path = vim.fn.fnamemodify(marker, ":h")
    97			local name = vim.fn.fnamemodify(path, ":t")
    98			table.insert(members, { path = path, name = name })
    99		end
   100		table.sort(members, function(a, b) return a.name < b.name end)
   101		return { workspace_root = workspace_root, members = members }
   102	end
   103
   104	local function fire_changed()
   105		pcall(function()
   106			vim.api.nvim_exec_autocmds("User", { pattern = "ParleySuperRepoChanged", modeline = false })
   107		end)
   108	end
   109
   110	local function activate()
   111		if _state.active then return true end
   112
   113		local repo_root = _parley.config.repo_root
   114		if type(repo_root) ~= "string" or repo_root == "" then
   115			_parley.logger.warning("super-repo: cwd is not inside a .parley repo")
   116			return false, "not in repo"
   117		end
   118
   119		local discovered, err = M.compute_members(repo_root)
   120		if not discovered then
   121			_parley.logger.warning("super-repo: " .. (err or "discovery failed"))
   122			return false, err
   123		end
   124
   125		local current_resolved = resolve_dir_key(repo_root)
   126		local repo_chat_subdir = _parley.config.repo_chat_dir or "workshop/parley"
   127		local repo_note_subdir = _parley.config.repo_note_dir or "workshop/notes"
   128
   129		-- Build sibling dir lists (excluding current repo, which is already primary).
   130		-- Label = repo name so the finder UI shows "{ariadne}" / "{brain}" etc.
   131		-- Persistence filtering is handled separately (init.lua persist gate consults
   132		-- super_repo.get_pushed_*_dirs() to drop these from state.json), so we don't
   133		-- need to overload the label as a sentinel.
   134		local sibling_chat_roots = {}
   135		local sibling_note_roots = {}
   136		for _, m in ipairs(discovered.members) do
   137			if resolve_dir_key(m.path) ~= current_resolved then
   138				table.insert(sibling_chat_roots, {
   139					dir = m.path .. "/" .. repo_chat_subdir,
   140					label = m.name,
   141				})
   142				table.insert(sibling_note_roots, {
   143					dir = m.path .. "/" .. repo_note_subdir,
   144					label = m.name,
   145				})
   146			end
   147		end
   148
   149		-- Append to existing chat_roots / note_roots (persist=false: transient)
   150		local new_chat_roots = vim.deepcopy(_parley.get_chat_roots())
   151		for _, r in ipairs(sibling_chat_roots) do
   152			table.insert(new_chat_roots, r)
   153		end
   154		_parley.set_chat_roots(new_chat_roots, false)
   155
   156		local new_note_roots = vim.deepcopy(_parley.get_note_roots())
   157		for _, r in ipairs(sibling_note_roots) do
   158			table.insert(new_note_roots, r)
   159		end
   160		_parley.set_note_roots(new_note_roots, false)
   161
   162		_state.active = true
   163		_state.workspace_root = discovered.workspace_root
   164		_state.members = vim.deepcopy(discovered.members)
   165		_state.pushed_chat_dirs = vim.tbl_map(function(r) return resolve_dir_key(r.dir) end, sibling_chat_roots)
   166		_state.pushed_note_dirs = vim.tbl_map(function(r) return resolve_dir_key(r.dir) end, sibling_note_roots)
   167		_parley.config.super_repo_root = discovered.workspace_root
   168		_parley.config.super_repo_members = vim.deepcopy(discovered.members)
   169
   170		fire_changed()
   171		return true
   172	end
   173
   174	local function strip_pushed(roots, pushed_set)
   175		local kept = {}
   176		for _, r in ipairs(roots) do
   177			if not pushed_set[resolve_dir_key(r.dir)] then
   178				table.insert(kept, r)
   179			end
   180		end
   181		return kept
   182	end
   183
   184	local function deactivate()
   185		if not _state.active then return true end
   186
   187		local pushed_chat_set = {}
   188		for _, d in ipairs(_state.pushed_chat_dirs) do pushed_chat_set[d] = true end
   189		local pushed_note_set = {}
   190		for _, d in ipairs(_state.pushed_note_dirs) do pushed_note_set[d] = true end
   191
   192		-- Always re-apply, even when the user has mutated roots in the meantime.
   193		-- The set_*_roots API requires at least one root, so fall back to the
   194		-- existing primary if stripping pushed siblings would leave nothing.
   195		local kept_chat = strip_pushed(vim.deepcopy(_parley.get_chat_roots()), pushed_chat_set)
   196		if #kept_chat > 0 then
   197			_parley.set_chat_roots(kept_chat, false)
   198		end
   199		local kept_note = strip_pushed(vim.deepcopy(_parley.get_note_roots()), pushed_note_set)
   200		if #kept_note > 0 then
   201			_parley.set_note_roots(kept_note, false)
   202		end
   203
   204		_state.active = false
   205		_state.workspace_root = nil
   206		_state.members = {}
   207		_state.pushed_chat_dirs = {}
   208		_state.pushed_note_dirs = {}
   209		_parley.config.super_repo_root = nil
   210		_parley.config.super_repo_members = nil
   211
   212		fire_changed()
   213		return true
   214	end
   215
   216	M.set_active = function(active)
   217		if active then
   218			return activate()
   219		end
   220		return deactivate()
   221	end
   222
   223	M.toggle = function()
   224		return M.set_active(not _state.active)
   225	end
   226
   227	return M
   430		local file = io.open(file_path, "w")
   431		if not file then
   432			logger.warning("Failed to open file for writing: " .. file_path)
   433			return
   434		end
   435		file:write(json)
   436		file:close()
   437	end
   438
   439	---@param tbl table # table to encode as JSON
   440	---@param file_path string # destination replaced only after a complete write
   441	---@param adapter table|nil # optional IO adapter for deterministic failure tests
   442	---@return boolean ok
   443	---@return string|nil err
   444	_H.table_to_file_atomic = function(tbl, file_path, adapter)
   445		adapter = adapter or {}
   446		local encode = adapter.encode or vim.json.encode
   447		local open = adapter.open or io.open
   448		local rename = adapter.rename or os.rename
   449		local remove = adapter.remove or os.remove
   450		local temp_path = adapter.temp_path or function(path)
   451			local uv = vim.uv or vim.loop
   452			local nonce = uv and uv.hrtime and uv.hrtime() or os.time()
   453			return string.format("%s.tmp-%s-%06x", path, tostring(nonce), math.random(0, 0xFFFFFF))
   454		end
   455
   456		local function failure(stage, detail)
   457			local message = tostring(detail or "unknown error")
   458			return false, (stage .. " failed: " .. message):sub(1, 240)
   459		end
   460		local function cleanup(path)
   461			pcall(remove, path)
   462		end
   463
   464		local encoded_ok, json = pcall(encode, tbl)
   465		if not encoded_ok then
   466			return failure("encode", json)
   467		end
   468
   469		local tmp = temp_path(file_path)
   470		local open_ok, file, open_err = pcall(open, tmp, "w")
   471		if not open_ok or not file then
   472			cleanup(tmp)
   473			return failure("open", open_ok and open_err or file)
   474		end
   475
   476		local write_ok, write_result, write_err = pcall(function() return file:write(json) end)
   477		if not write_ok or not write_result then
   478			pcall(function() file:close() end)
   479			cleanup(tmp)
   480			return failure("write", write_ok and write_err or write_result)
   481		end
   482
   483		local close_ok, close_result, close_err = pcall(function() return file:close() end)
   484		if not close_ok or not close_result then
   485			cleanup(tmp)
   486			return failure("close", close_ok and close_err or close_result)
   487		end
   488
   489		local rename_ok, rename_result, rename_err = pcall(rename, tmp, file_path)
   490		if not rename_ok or not rename_result then
   491			cleanup(tmp)
   492			return failure("rename", rename_ok and rename_err or rename_result)
   493		end
   494
   495		return true
   496	end
   497
   498	---@param file_path string # the file path from where to read the json into a table
   499	---@return table | nil # the table read from the file, or nil if an error occurred
   500	_H.file_to_table = function(file_path)
   501		local file, err = io.open(file_path, "r")
   502		if not file then
   503			logger.warning("Failed to open file for reading: " .. file_path .. "\nError: " .. err)
   504			return nil
   505		end
   506		local content = file:read("*a")
   507		file:close()
   508
   509		if content == nil or content == "" then
   510			logger.warning("Failed to read any content from file: " .. file_path)
   511			return nil
   512		end
   513
   514		local tbl = vim.json.decode(content)
   515		return tbl
   900	--- @return string[]|nil modes
   901	function M.resolve_key(entry, config)
   902		local keys, modes = M.resolve_keys(entry, config)
   903		return keys and keys[1] or nil, modes
   904	end
   905
   906	--- Resolve all bound keys (primary + aliases) and modes for an entry.
   907	--- Both `default_key` and config-supplied `shortcut` may be a single string
   908	--- or a list of strings — both shapes are normalized to a list.
   909	--- @param entry table
   910	--- @param config table
   911	--- @return string[]|nil keys
   912	--- @return string[]|nil modes
   913	function M.resolve_keys(entry, config)
   914		local function as_list(v)
   915			if v == nil then return nil end
   916			if type(v) == "string" then return v ~= "" and { v } or nil end
   917			if type(v) ~= "table" then return nil end
   918			local keys = {}
   919			for _, key in ipairs(v) do
   920				if type(key) == "string" and key ~= "" then table.insert(keys, key) end
   921			end
   922			return #keys > 0 and keys or nil
   923		end
   924
   925		if not entry.config_key then
   926			return as_list(entry.default_key), entry.default_modes
   927		end
   928
   929		-- Handle dot-notation for nested config (e.g. "chat_finder_mappings.delete")
   930		local cfg_val
   931		if entry.config_key:find(".", 1, true) then
   932			local parts = {}
   933			for part in entry.config_key:gmatch("[^.]+") do
   934				table.insert(parts, part)
   935			end
   936			cfg_val = config
   937			for _, part in ipairs(parts) do
   938				if type(cfg_val) ~= "table" then
   939					cfg_val = nil
   940					break
   941				end
   942				cfg_val = cfg_val[part]
   943			end
   944		else
   945			cfg_val = config[entry.config_key]
   946		end
   947
   948		if cfg_val and type(cfg_val) == "table" then
   949			return as_list(cfg_val.shortcut) or as_list(entry.default_key),
   950				cfg_val.modes or entry.default_modes
   951		end
   952		return as_list(entry.default_key), entry.default_modes
   953	end
   954
   955	-------------------------------------------------------------------
   956	-- Help display
   957	-------------------------------------------------------------------
   958
   959	--- Resolve the actual runtime shortcut by querying vim keymaps.
   960	--- Falls back to config/default if runtime lookup fails.
   961	--- @param entry table  registry entry
   962	--- @param config table  parley config
   963	--- @param bufnr integer|nil  buffer number for buffer-local lookup
   964	--- @return string  display string for the shortcut
   965	local function resolve_display_shortcut(entry, config, _bufnr)
   966		-- Use config resolution (preserves user-facing format like <C-g>?)
   967		local key, _ = M.resolve_key(entry, config)
   968		return key or entry.default_key
   969	end
   970
   971	--- Generate help lines for a given context.
   972	--- @param context string  buffer context (e.g. "chat", "issue", "other")
   973	--- @param config table  parley config
   974	--- @param bufnr integer|nil  current buffer number
   975	--- @return string[]  lines for the help window
   976	function M.help_lines(context, config, bufnr)
   977		-- Title
   978		local title_suffix = {
   979			chat = " (Chat)",
   980			note = " (Note)",
   981			issue = " (Issue)",
   982			markdown = " (Markdown)",
   983			chat_finder = " (Chat Finder)",
   984			note_finder = " (Note Finder)",
   985			issue_finder = " (Issue Finder)",
   986			vision = " (Vision)",
   987			repo = " (Repo)",
   988		}
   989		local lines = {
   990			"Parley Key Bindings" .. (title_suffix[context] or ""),
   991			"",
   992		}
   993
   994		local function add(shortcut, description)
   995			table.insert(lines, string.format("  %-12s %s", shortcut, description))
   996		end
   997
   998		-- Get applicable scopes in display order
   999		local display_scopes = M.get_display_scopes(context)
  1000
  1001		for _, scope in ipairs(display_scopes) do
  1002			local scope_entries = M._by_scope[scope]
  1003			if scope_entries and #scope_entries > 0 then
  1004				table.insert(lines, M.scope_labels[scope] or scope)
  1005				for _, entry in ipairs(scope_entries) do
  1006					local key = resolve_display_shortcut(entry, config, bufnr)
  1007					if key then add(key, entry.help_desc or entry.desc) end
  1008				end
  1009				table.insert(lines, "")
  1010			end
  1011		end
  1012
  1013		-- Finder recency note
  1014		if context == "chat_finder" then
  1015			local months = (config.chat_finder_recency or {}).months or 6
  1016			table.insert(lines, string.format("  %-12s %s", "", "(Recent window default: last " .. tostring(months) .. " months)"))
  1017			table.insert(lines, "")
  1018		elseif context == "note_finder" then
  1019			local months = (config.note_finder_recency or {}).months or 6
  1020			table.insert(lines, string.format("  %-12s %s", "", "(Recent window default: last " .. tostring(months) .. " months)"))
  1180		return M.helpers.table_to_file_atomic(persist_state, state_file)
  1181	end
  1182
  1183	---@param update table | nil # table with options
  1184	M.refresh_state = function(update)
  1185		local state_file = M.config.state_dir .. "/state.json"
  1186		update = update or {}
  1187
  1188		local old_state = vim.deepcopy(M._state)
  1189
  1190		local disk_state = {}
  1191		if vim.fn.filereadable(state_file) ~= 0 then
  1192			disk_state = M.helpers.file_to_table(state_file) or {}
  1193		end
  1194
  1195		if not disk_state.updated then
  1196			local primary_chat_dir = M.get_chat_dirs()[1]
  1197			local last = primary_chat_dir and (primary_chat_dir .. "/last.md") or nil
  1198			if last and vim.fn.filereadable(last) == 1 then
  1199				os.remove(last)
  1200			end
  1201		end
  1202
  1203		if not M._state.updated or (disk_state.updated and M._state.updated < disk_state.updated) then
  1204			M._state = vim.deepcopy(disk_state)
  1205		end
  1206		M._state.updated = os.time()
  1207
  1208		-- Always ensure interview mode starts as false (don't persist interview mode across sessions)
  1209		M._state.interview_mode = false
  1210		M._state.interview_start_time = nil
  1211		-- Stop any running interview timer
  1212		interview.stop_timer()
  1213
  1214		-- apply in-memory updates
  1215		for k, v in pairs(update) do
  1216			M._state[k] = v
  1217		end
  1218		-- initialize per-chat web_search setting if missing (migrate from old key name)
  1219		if M._state.web_search == nil then
  1220			if M._state.claude_web_search ~= nil then
  1221				M._state.web_search = M._state.claude_web_search
  1222				M._state.claude_web_search = nil
  1223			else
  1224				M._state.web_search = M.config.web_search
  1225			end
  1226		end
  1227
  1228		if M._state.follow_cursor == nil then
  1229			M._state.follow_cursor = not M.config.chat_free_cursor
  1230		end
  1231
  1232		-- Issue #117 M2: chat roots are derived from config.chat_dir + repo
  1233		-- mode + super-repo, never restored from state.json. Old state files
  1234		-- may still carry chat_dirs/chat_roots fields — they are ignored.
  1235
  1236		-- Restore note roots from persisted state
  1237		if type(M._state.note_roots) == "table" and #M._state.note_roots > 0 then
  1238			apply_note_roots(M._state.note_roots)
  1239		else
  1240			M._state.note_roots = vim.deepcopy(M.get_note_roots())
  1241			M._state.note_dirs = vim.deepcopy(M.get_note_dirs())
  1242		end
  1243
  1244		-- Issue #117 M2: the chat-side defensive re-injection of repo_chat
  1245		-- as primary lived here. With state.json no longer carrying chat
  1246		-- roots, apply_repo_local at setup is the single source of truth
  1247		-- for the chat roots list — there's no stale state to defend
  1248		-- against. The note-side block below is unchanged because notes
  1249		-- still persist their roots (separate cleanup, separate issue).
  1250
  1251		-- In repo mode, ensure repo note dir is the primary root (overrides persisted state)
  1252		if M.config.repo_root and M.config.repo_note_dir then
  1253			local repo_note = M.config.repo_root .. "/" .. M.config.repo_note_dir
  1254			local resolved_repo = vim.fn.resolve(vim.fn.expand(repo_note)):gsub("/+$", "")
  1255			local current_roots = M.get_note_roots()
  1256			local already_primary = #current_roots > 0
  1257				and vim.fn.resolve(vim.fn.expand(current_roots[1].dir)):gsub("/+$", "") == resolved_repo
  1258
  1259			if not already_primary then
  1260				local new_roots = { { dir = repo_note, label = "repo" } }
  1261				for _, root in ipairs(current_roots) do
  1262					if vim.fn.resolve(vim.fn.expand(root.dir)):gsub("/+$", "") ~= resolved_repo then
  1263						table.insert(new_roots, root)
  1264					end
  1265				end
  1266				apply_note_roots(new_roots)
  1267				M._state.note_roots = vim.deepcopy(M.get_note_roots())
  1268				M._state.note_dirs = vim.deepcopy(M.get_note_dirs())
  1269			end
  1270		end
  1271
  1272		if not M._state.agent or not M.agents[M._state.agent] then
  1273			M._state.agent = M._agents[1]
  1274		end
  1275
  1276		if not M._state.system_prompt or not M.system_prompts[M._state.system_prompt] then
  1277			M._state.system_prompt = "default"
  1278		end
  1279
  1280		if M._state.last_chat and vim.fn.filereadable(M._state.last_chat) == 0 then
  1281			M._state.last_chat = nil
  1282		end
  1283
  1284		for k, _ in pairs(M._state) do
  1285			if M._state[k] ~= old_state[k] or M._state[k] ~= disk_state[k] then
  1286				M.logger.debug(
  1287					string.format(
  1288						"state[%s]: disk=%s old=%s new=%s",
  1289						k,
  1290						vim.inspect(disk_state[k]),
  1291						vim.inspect(old_state[k]),
  1292						vim.inspect(M._state[k])
  1293					)
  1294				)
  1295			end
  1296		end
  1297
  1298		-- Runtime roots are filtered by the shared write-only boundary. Writing must
  1299		-- not reload state or disturb a live super-repo overlay.
  1300		local persisted, persist_err = M.persist_state()
  1301		if not persisted then
  1302			M.logger.warning("state: persistence failed: " .. tostring(persist_err or "unknown error"))
  1303		end
  1304
  1305		local buf = vim.api.nvim_get_current_buf()
  1306		local file_name = vim.api.nvim_buf_get_name(buf)
  1307		M.display_agent(buf, file_name)
  1308	end
  1309
  1310	---@return string
  1311	M._remote_reference_cache_file = function() return chat_respond.remote_reference_cache_file() end
  1312	M._load_remote_reference_cache = function() return chat_respond.load_remote_reference_cache() end
  1313	M._save_remote_reference_cache = function() return chat_respond.save_remote_reference_cache() end
  1314	M._get_chat_remote_reference_cache = function(f) return chat_respond.get_chat_remote_reference_cache(f) end
  1315	M._format_remote_reference_error_content = function(u, e) return chat_respond.format_remote_reference_error_content(u, e) end
  1316	M._format_missing_remote_reference_cache_content = function(u) return chat_respond.format_missing_remote_reference_cache_content(u) end
  1317
  1318	-- stop receiving responses for all processes and clean the handles
  1319	---@param signal number | nil # signal to send to the process
  1320	M.cmd.Stop = function(s) chat_respond.cmd_stop(s) end
   790		-- Register all global keymaps from the keybinding registry
   791		kb_registry.register_global(
   792			{ "global", "repo", "note", "issue", "vision", "chat" },
   793			M.config,
   794			{
   795				help = function() M.cmd.KeyBindings() end,
   796				chat_new = function() M.cmd.ChatNew({}) end,
   797				chat_finder = function() M.cmd.ChatFinder() end,
   798				chat_review = function() M.cmd.ChatReview({}) end,
   799				note_new = function() M.cmd.NoteNew() end,
   800				note_finder = function() M.cmd.NoteFinder({}) end,
   801				note_dirs = function() M.cmd.NoteDirs({}) end,
   802				year_root = function()
   803					local current_year = os.date("%Y")
   804					local year_dir = M.config.notes_dir .. "/" .. current_year
   805					M.helpers.prepare_dir(year_dir, "year")
   806					vim.cmd("cd " .. year_dir)
   807				end,
   808				markdown_finder = function() M.cmd.MarkdownFinder() end,
   809				super_repo_toggle = function()
   810					local before = M.is_super_repo_active()
   811					M.toggle_super_repo()
   812					local after = M.is_super_repo_active()
   813					if after and not before then
   814						local members = M.config.super_repo_members or {}
   815						local count = #members
   816						if count <= 1 then
   817							vim.notify(
   818								"super-repo: ON, but no sibling .parley repos found under " ..
   819									(M.config.super_repo_root or "?"),
   820								vim.log.levels.WARN
   821							)
   822						else
   823							vim.notify("super-repo: ON (" .. count .. " members)", vim.log.levels.INFO)
   824						end
   825					elseif not after and before then
902:	local keys, modes = M.resolve_keys(entry, config)
913:function M.resolve_keys(entry, config)
965:local function resolve_display_shortcut(entry, config, _bufnr)
1006:				local key = resolve_display_shortcut(entry, config, bufnr)
1036:function M.register_global(scopes, config, callbacks)
1046:				local keys, modes = M.resolve_keys(entry, config)
1074:function M.register_buffer(scopes, buf, config, callbacks, set_keymap)
1084:				local keys, modes = M.resolve_keys(entry, config)
5:-- Default config
10:local config = {
11:	-- Please start with minimal config possible.
23:	-- API keys for each provider - easy to override just this section without copying entire config
24:	-- Set these in your local configuration - this is separate from providers section
47:	-- Google Drive OAuth configuration for @@ URL references
55:	-- Provider-neutral OAuth configuration for remote @@ URL references.
57:	-- `google_drive` config above remains supported for backward compatibility.
107:	-- renders config.yaml from this block on demand and lazily starts / reuses /
112:	-- (single source of truth); the generated config is a derived 0600 artifact
122:		--   ON in this config. NOTE: auto-fetching an executable is a trust
126:		-- Raw cliproxyapi config, rendered into the proxy's config.yaml. This is
129:		config = {
458:	-- Intentionally unbound by default; configure chat_shortcut_toggle_tool_folds
525:	-- chat finder recency filtering configuration
596:	-- chat memory configuration (for summarizing older messages)
664:	-- raw_mode configuration for debugging and learning. Writes per-turn
678:	-- command config and templates below are used by commands like GpRewrite, GpEnew, etc.
693:			local key = copy.config.openai_api_key or ""
694:			copy.config.openai_api_key = key:sub(1, 3) .. string.rep("*", #key - 6) .. key:sub(-3)
704:			local log_file = plugin.config.log_file
716:return config

exec
/bin/zsh -lc "nl -ba lua/parley/init.lua | sed -n '180,360p;805,845p' && nl -ba lua/parley/keybinding_registry.lua | sed -n '1028,1105p' && git diff ac2706896b00ddb30e3ab229674c671f604c4a4f..HEAD -- lua/parley/init.lua lua/parley/super_repo.lua lua/parley/helper.lua lua/parley/keybinding_registry.lua lua/parley/config.lua lua/parley/repo_mode.lua" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
   180			return
   181		end
   182
   183		pcall(function()
   184			timer:stop()
   185		end)
   186
   187		ok, is_closing = pcall(function()
   188			return timer:is_closing()
   189		end)
   190		if ok and is_closing then
   191			return
   192		end
   193
   194		pcall(function()
   195			timer:close()
   196		end)
   197	end
   198
   199	local function find_chat_header_end(lines)
   200		return M.chat_parser.find_header_end(lines)
   201	end
   202
   203	local function parse_chat_headers(lines)
   204		local header_end = find_chat_header_end(lines)
   205		if not header_end then
   206			return nil, nil
   207		end
   208		local cfg = M.config or {}
   209		local parse_config = {
   210			chat_user_prefix = cfg.chat_user_prefix or "💬:",
   211			chat_local_prefix = cfg.chat_local_prefix or "🔒:",
   212			chat_assistant_prefix = cfg.chat_assistant_prefix or { "🤖:" },
   213			chat_memory = cfg.chat_memory or {
   214				enable = true,
   215				summary_prefix = "📝:",
   216				reasoning_prefix = "🧠:",
   217			},
   218		}
   219		local parsed = M.chat_parser.parse_chat(lines, header_end, parse_config)
   220		return parsed.headers, header_end
   221	end
   222
   223	-- Passthroughs to chat_dirs module (see lua/parley/chat_dirs.lua)
   224	-- Local helpers are defined as wrappers at the top of this file (near require).
   225	-- apply_chat_roots / normalize_chat_roots accessed via chat_dirs.*
   226	local apply_chat_roots = function(...) return chat_dirs.apply_chat_roots(...) end
   227	local normalize_chat_roots = function(...) return chat_dirs.normalize_chat_roots(...) end
   228	local resolve_dir_key = function(d) return vim.fn.resolve(vim.fn.expand(d)):gsub("/+$", "") end
   229
   230	M.get_chat_roots = function() return chat_dirs.get_chat_roots() end
   231	M.get_chat_dirs = function() return chat_dirs.get_chat_dirs() end
   232	M.set_chat_dirs = function(d, p) return chat_dirs.set_chat_dirs(d, p) end
   233	M.set_chat_roots = function(r, p) return chat_dirs.set_chat_roots(r, p) end
   234
   235	-- Passthroughs to note_dirs module (see lua/parley/note_dirs.lua)
   236	local apply_note_roots = function(...) return note_dirs.apply_note_roots(...) end
   237	local normalize_note_roots = function(...) return note_dirs.normalize_note_roots(...) end
   238
   239	M.get_note_roots = function() return note_dirs.get_note_roots() end
   240	M.get_note_dirs = function() return note_dirs.get_note_dirs() end
   241	M.set_note_dirs = function(d, p) return note_dirs.set_note_dirs(d, p) end
   242	M.set_note_roots = function(r, p) return note_dirs.set_note_roots(r, p) end
   243	M.add_note_dir = function(d, p, l) return note_dirs.add_note_dir(d, p, l) end
   244	M.remove_note_dir = function(d, p) return note_dirs.remove_note_dir(d, p) end
   245	M.rename_note_dir = function(d, l, p) return note_dirs.rename_note_dir(d, l, p) end
   246
   247
   248	local function set_chat_topic_line(buf, lines, topic)
   249		local header_end = find_chat_header_end(lines)
   250		if not header_end then
   251			vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "# topic: " .. topic })
   252			return
   253		end
   254
   255		if lines[1] and lines[1]:gsub("^%s*(.-)%s*$", "%1") == "---" then
   256			for i = 2, header_end - 1 do
   257				if lines[i]:match("^%s*topic:%s*") then
   258					vim.api.nvim_buf_set_lines(buf, i - 1, i, false, { "topic: " .. topic })
   259					return
   260				end
   261			end
   262			vim.api.nvim_buf_set_lines(buf, 1, 1, false, { "topic: " .. topic })
   263			return
   264		end
   265
   266		vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "# topic: " .. topic })
   267	end
   268
   269	local function is_follow_cursor_enabled(override_free_cursor)
   270		if override_free_cursor ~= nil then
   271			return override_free_cursor
   272		end
   273		if M._state.follow_cursor ~= nil then
   274			return M._state.follow_cursor
   275		end
   276		return not M.config.chat_free_cursor
   277	end
   278
   279	local function query_cursor_line(qt)
   280		if not qt then
   281			return nil
   282		end
   283
   284		if type(qt.last_line) == "number" and qt.last_line >= 0 then
   285			return qt.last_line + 1
   286		end
   287		if type(qt.first_line) == "number" and qt.first_line >= 0 then
   288			return qt.first_line + 1
   289		end
   290
   291		return nil
   292	end
   293
   294	local function jump_to_active_response(buf, win)
   295		if not M.tasker.is_busy(buf, true) then
   296			return false
   297		end
   298
   299		local qt = M.tasker.get_active_query_by_buf(buf)
   300		if not qt then
   301			return false
   302		end
   303
   304		local line = query_cursor_line(qt)
   305		if not line then
   306			return false
   307		end
   308
   309		M.helpers.cursor_to_line(line, buf, win)
   310		return true
   311	end
   312
   313	-- Forward declaration so setup() closure can reference it (defined after setup())
   314	local show_keybindings
   315
   316	--- Register `:<prefix>Proxy <subcommand>` to manage the optional bundled
   317	--- cliproxyapi instance (issue #131). Harmless when the feature isn't opted
   318	--- into — `status` just reports `managed: false`.
   319	---@param prefix string # M.config.cmd_prefix (e.g. "Parley")
   320	M.register_proxy_command = function(prefix)
   321		-- Single source of truth for the subcommands: drives the usage text AND the
   322		-- completion list (ARCH-DRY). `arg` is the per-subcommand argument shown in
   323		-- usage; nil for the no-arg ones.
   324		local SUBS_HELP = {
   325			{ name = "status", desc = "show managed-proxy health, endpoint, binary, drift" },
   326			{ name = "start", desc = "ensure the proxy is running (spawn if needed)" },
   327			{ name = "stop", desc = "stop parley-spawned proxies (+ reap a leftover on the port)" },
   328			{ name = "restart", desc = "stop, then start with a freshly rendered config" },
   329			{ name = "models", arg = "<provider>", desc = "list the models a provider currently serves" },
   330			{ name = "providers", desc = "list the supported provider names" },
   331			{ name = "login", arg = "<provider>", desc = "run an interactive OAuth login for a provider" },
   332			{ name = "update", desc = "download the pinned cliproxyapi release" },
   333		}
   334		local SUBS = vim.tbl_map(function(e)
   335			return e.name
   336		end, SUBS_HELP)
   337
   338		local function usage()
   339			local lines = { "usage: " .. prefix .. "Proxy <subcommand>" }
   340			for _, e in ipairs(SUBS_HELP) do
   341				local name = e.name .. (e.arg and (" " .. e.arg) or "")
   342				lines[#lines + 1] = ("  %-20s %s"):format(name, e.desc)
   343			end
   344			return table.concat(lines, "\n")
   345		end
   346
   347		vim.api.nvim_create_user_command(prefix .. "Proxy", function(params)
   348			local cliproxy = require("parley.cliproxy")
   349			local sub = params.fargs[1]
   350			local arg = params.fargs[2]
   351			if sub == "status" then
   352				cliproxy.status(function(info)
   353					vim.notify(table.concat({
   354						"cliproxy status",
   355						"  managed:       " .. tostring(info.managed),
   356						"  health:        " .. tostring(info.health),
   357						"  binary:        " .. tostring(info.binary) .. " (" .. info.binary_source .. ")",
   358						"  endpoint:      " .. tostring(info.host) .. ":" .. tostring(info.port),
   359						"  auth-dir:      " .. tostring(info.auth_dir),
   360						"  config:        " .. tostring(info.config_path),
   805					M.helpers.prepare_dir(year_dir, "year")
   806					vim.cmd("cd " .. year_dir)
   807				end,
   808				markdown_finder = function() M.cmd.MarkdownFinder() end,
   809				super_repo_toggle = function()
   810					local before = M.is_super_repo_active()
   811					M.toggle_super_repo()
   812					local after = M.is_super_repo_active()
   813					if after and not before then
   814						local members = M.config.super_repo_members or {}
   815						local count = #members
   816						if count <= 1 then
   817							vim.notify(
   818								"super-repo: ON, but no sibling .parley repos found under " ..
   819									(M.config.super_repo_root or "?"),
   820								vim.log.levels.WARN
   821							)
   822						else
   823							vim.notify("super-repo: ON (" .. count .. " members)", vim.log.levels.INFO)
   824						end
   825					elseif not after and before then
   826						vim.notify("super-repo: OFF", vim.log.levels.INFO)
   827					end
   828				end,
   829				oil = function()
   830					local ok, oil = pcall(require, "oil")
   831					if ok then
   832						oil.open()
   833					else
   834						M.logger.error("oil.nvim is not installed. Please install it with your package manager.")
   835					end
   836				end,
   837				copy_location = function() M.cmd.CopyLocation() end,
   838				copy_location_content = function() M.cmd.CopyLocationContent() end,
   839				copy_context = function() M.cmd.CopyContext() end,
   840				copy_context_wide = function() M.cmd.CopyContextWide() end,
   841				review_finder = function() require("parley.skills.review").cmd_review_finder() end,
   842				skill_picker = function() require("parley.skill_picker").open() end,
   843				-- Repo scope
   844				issue_new = function() M.cmd.IssueNew() end,
   845				issue_finder = function() M.cmd.IssueFinder({}) end,
  1028	-------------------------------------------------------------------
  1029	-- Registration
  1030	-------------------------------------------------------------------
  1031
  1032	--- Register all non-buffer-local keybindings for the given scopes.
  1033	--- @param scopes string[]  list of scope names to register
  1034	--- @param config table  parley config
  1035	--- @param callbacks table  map of entry.id → callback function
  1036	function M.register_global(scopes, config, callbacks)
  1037		local scope_set = {}
  1038		for _, s in ipairs(scopes) do
  1039			scope_set[s] = true
  1040		end
  1041
  1042		for _, entry in ipairs(M.entries) do
  1043			if scope_set[entry.scope] and not entry.buffer_local and not entry.help_only then
  1044				local cb = callbacks[entry.id]
  1045				if cb then
  1046					local keys, modes = M.resolve_keys(entry, config)
  1047					if keys and modes then
  1048						for _, key in ipairs(keys) do
  1049							for _, mode in ipairs(modes) do
  1050								local wrapped
  1051								if mode == "i" then
  1052									wrapped = function()
  1053										vim.cmd("stopinsert")
  1054										cb()
  1055									end
  1056								else
  1057									wrapped = cb
  1058								end
  1059								vim.keymap.set(mode, key, wrapped, { silent = true, desc = entry.desc })
  1060							end
  1061						end
  1062					end
  1063				end
  1064			end
  1065		end
  1066	end
  1067
  1068	--- Register buffer-local keybindings for the given scopes on a buffer.
  1069	--- @param scopes string[]  list of scope names to register
  1070	--- @param buf integer  buffer number
  1071	--- @param config table  parley config
  1072	--- @param callbacks table  map of entry.id → callback function (or table of mode→fn)
  1073	--- @param set_keymap function  keymap setter (e.g. parley.helpers.set_keymap)
  1074	function M.register_buffer(scopes, buf, config, callbacks, set_keymap)
  1075		local scope_set = {}
  1076		for _, s in ipairs(scopes) do
  1077			scope_set[s] = true
  1078		end
  1079
  1080		for _, entry in ipairs(M.entries) do
  1081			if scope_set[entry.scope] and entry.buffer_local and not entry.help_only then
  1082				local cb = callbacks[entry.id]
  1083				if cb then
  1084					local keys, modes = M.resolve_keys(entry, config)
  1085					if keys and modes then
  1086						for _, key in ipairs(keys) do
  1087							if type(cb) == "table" then
  1088								-- Mode-specific callbacks: { n = fn, i = fn, v = fn }
  1089								for _, mode in ipairs(modes) do
  1090									local mode_cb = cb[mode]
  1091									if mode_cb then
  1092										set_keymap({ buf }, mode, key, mode_cb, entry.desc)
  1093									end
  1094								end
  1095							else
  1096								-- Single callback for all modes
  1097								for _, mode in ipairs(modes) do
  1098									set_keymap({ buf }, mode, key, cb, entry.desc)
  1099								end
  1100							end
  1101						end
  1102					end
  1103				end
  1104			end
  1105		end
diff --git a/lua/parley/config.lua b/lua/parley/config.lua
index 6be9c04..1666102 100644
--- a/lua/parley/config.lua
+++ b/lua/parley/config.lua
@@ -454,8 +454,9 @@ local config = {
	chat_shortcut_delete = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>d" },
	chat_shortcut_delete_tree = { modes = { "n" }, shortcut = "<C-g>D" },
	chat_shortcut_stop = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>x" },
-	-- Toggle folds of 🔧:/📎: components within the exchange under cursor
-	chat_shortcut_toggle_tool_folds = { modes = { "n" }, shortcut = "<C-g>b" },
+	-- Toggle folds of 🔧:/📎: components within the exchange under cursor.
+	-- Intentionally unbound by default; configure chat_shortcut_toggle_tool_folds
+	-- to opt in.
	chat_shortcut_agent = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>a" },
	chat_shortcut_system_prompt = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>P" },
	chat_shortcut_follow_cursor = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>l" },
@@ -465,7 +466,7 @@ local config = {
	-- `sdlc resolve`), else native go-to-file. Transparent (native gf preserved on
	-- plain paths); remap here to disable.
	chat_shortcut_resolve_ref_gf = { modes = { "n" }, shortcut = "gf" },
-	chat_shortcut_prune = { modes = { "n" }, shortcut = "<C-g>p" },
+	chat_shortcut_prune = { modes = { "n" }, shortcut = "<C-g>b" },
	chat_shortcut_export_markdown = { modes = { "n" }, shortcut = "<C-g>em" },
	chat_shortcut_export_html = { modes = { "n" }, shortcut = "<C-g>eh" },
	chat_shortcut_exchange_cut = { modes = { "n", "v" }, shortcut = "<C-g>X" },
@@ -570,7 +571,7 @@ local config = {
	-- maximum directory depth for markdown finder (from repo root)
	markdown_finder_max_depth = 6,
	-- super-repo mode toggle (aggregates reads across sibling .parley repos)
-	global_shortcut_super_repo_toggle = { modes = { "n", "i" }, shortcut = "<C-g>S" },
+	global_shortcut_super_repo_toggle = { modes = { "n", "i" }, shortcut = "<C-g>p" },
	-- global shortcuts for issue management
	global_shortcut_issue_new = { modes = { "n", "i" }, shortcut = "<C-y>c" },
	global_shortcut_issue_finder = { modes = { "n", "i" }, shortcut = "<C-y>f" },
diff --git a/lua/parley/helper.lua b/lua/parley/helper.lua
index f5ecbcf..c685f3e 100644
--- a/lua/parley/helper.lua
+++ b/lua/parley/helper.lua
@@ -436,6 +436,65 @@ _H.table_to_file = function(tbl, file_path)
	file:close()
 end

+---@param tbl table # table to encode as JSON
+---@param file_path string # destination replaced only after a complete write
+---@param adapter table|nil # optional IO adapter for deterministic failure tests
+---@return boolean ok
+---@return string|nil err
+_H.table_to_file_atomic = function(tbl, file_path, adapter)
+	adapter = adapter or {}
+	local encode = adapter.encode or vim.json.encode
+	local open = adapter.open or io.open
+	local rename = adapter.rename or os.rename
+	local remove = adapter.remove or os.remove
+	local temp_path = adapter.temp_path or function(path)
+		local uv = vim.uv or vim.loop
+		local nonce = uv and uv.hrtime and uv.hrtime() or os.time()
+		return string.format("%s.tmp-%s-%06x", path, tostring(nonce), math.random(0, 0xFFFFFF))
+	end
+
+	local function failure(stage, detail)
+		local message = tostring(detail or "unknown error")
+		return false, (stage .. " failed: " .. message):sub(1, 240)
+	end
+	local function cleanup(path)
+		pcall(remove, path)
+	end
+
+	local encoded_ok, json = pcall(encode, tbl)
+	if not encoded_ok then
+		return failure("encode", json)
+	end
+
+	local tmp = temp_path(file_path)
+	local open_ok, file, open_err = pcall(open, tmp, "w")
+	if not open_ok or not file then
+		cleanup(tmp)
+		return failure("open", open_ok and open_err or file)
+	end
+
+	local write_ok, write_result, write_err = pcall(function() return file:write(json) end)
+	if not write_ok or not write_result then
+		pcall(function() file:close() end)
+		cleanup(tmp)
+		return failure("write", write_ok and write_err or write_result)
+	end
+
+	local close_ok, close_result, close_err = pcall(function() return file:close() end)
+	if not close_ok or not close_result then
+		cleanup(tmp)
+		return failure("close", close_ok and close_err or close_result)
+	end
+
+	local rename_ok, rename_result, rename_err = pcall(rename, tmp, file_path)
+	if not rename_ok or not rename_result then
+		cleanup(tmp)
+		return failure("rename", rename_ok and rename_err or rename_result)
+	end
+
+	return true
+end
+
 ---@param file_path string # the file path from where to read the json into a table
 ---@return table | nil # the table read from the file, or nil if an error occurred
 _H.file_to_table = function(file_path)
diff --git a/lua/parley/init.lua b/lua/parley/init.lua
index 36ea260..af38875 100644
--- a/lua/parley/init.lua
+++ b/lua/parley/init.lua
@@ -64,9 +64,28 @@ note_dirs.setup(M)

 -- Super-repo module (loaded here; wired up immediately since it only needs M reference)
 local super_repo = require("parley.super_repo")
+local repo_mode = require("parley.repo_mode")
 super_repo.setup(M)
 M.super_repo = super_repo
-M.toggle_super_repo = function() return super_repo.toggle() end
+M.toggle_super_repo = function()
+	local transitioned, err = super_repo.toggle()
+	if not transitioned then
+		return false, err
+	end
+
+	local root = M.config.repo_root
+	if type(root) == "string" and root ~= "" then
+		local canonical_root = vim.fn.resolve(vim.fn.expand(root)):gsub("/+$", "")
+		local mode = super_repo.is_active() and "super_repo" or "repo"
+		M._state.repo_modes = repo_mode.updated(M._state.repo_modes, canonical_root, mode)
+		local persisted = M.persist_state()
+		if not persisted then
+			M.logger.warning("super-repo: preference not saved")
+		end
+	end
+
+	return true
+end
 M.is_super_repo_active = function() return super_repo.is_active() end

 -- Discovery registry (#116): the repo's noun-vocabulary (what file types exist
@@ -637,21 +656,6 @@ M.setup = function(opts)
	apply_chat_roots(normalize_chat_roots(M.config.chat_dir, M.config.chat_dirs, M.config.chat_roots))
	apply_note_roots(normalize_note_roots(M.config.notes_dir, M.config.note_dirs, M.config.note_roots))

-	-- Brain repos auto-enter super-repo mode. A repo is a brain iff it has a
-	-- `.brain/` directory at root (constitution convention). Deferred to
-	-- VimEnter so chat_roots/note_roots have settled before super_repo mutates
-	-- them, and to avoid racing other plugins' setup().
-	if M.config.repo_root and vim.fn.isdirectory(M.config.repo_root .. "/.brain") == 1 then
-		vim.api.nvim_create_autocmd("VimEnter", {
-			once = true,
-			callback = function()
-				if not super_repo.is_active() then
-					super_repo.toggle()
-				end
-			end,
-		})
-	end
-
	-- repo-local dirs (issues, history, vision, notes) are resolved in apply_repo_local
	-- against git root; skip them here to avoid creating in CWD
	local skip_prepare = { chat_dir = true }
@@ -752,6 +756,14 @@ M.setup = function(opts)
		M.refresh_state({ agent = M.config.default_agent })
	end

+	-- Restore the current repo's explicit mode only after every state refresh has
+	-- settled roots. This runtime transition is intentionally non-persisting.
+	if type(M.config.repo_root) == "string" and M.config.repo_root ~= "" then
+		local canonical_root = vim.fn.resolve(vim.fn.expand(M.config.repo_root)):gsub("/+$", "")
+		local saved_mode = repo_mode.resolve(M._state.repo_modes, canonical_root)
+		super_repo.set_active(saved_mode == "super_repo")
+	end
+
	-- register user commands
	for hook, _ in pairs(M.hooks) do
		M.helpers.create_user_command(M.config.cmd_prefix .. hook, function(params)
@@ -1129,6 +1141,45 @@ M.setup = function(opts)
	M.logger.debug("setup finished")
 end

+--- Persist the current state without reloading disk state or reapplying roots.
+--- Runtime-derived chat roots and repo/super-repo note roots are excluded.
+---@return boolean ok
+---@return string|nil err
+M.persist_state = function()
+	local persist_state = vim.deepcopy(M._state)
+	persist_state.chat_roots = nil
+	persist_state.chat_dirs = nil
+
+	local function resolve_dir(dir)
+		return vim.fn.resolve(vim.fn.expand(dir)):gsub("/+$", "")
+	end
+	local pushed_note = {}
+	for _, dir in ipairs(super_repo.get_pushed_note_dirs()) do
+		pushed_note[dir] = true
+	end
+	if type(persist_state.note_roots) == "table" then
+		local filtered = {}
+		for _, root in ipairs(persist_state.note_roots) do
+			if root.label ~= "repo" and not pushed_note[resolve_dir(root.dir)] then
+				table.insert(filtered, root)
+			end
+		end
+		persist_state.note_roots = #filtered > 0 and filtered or nil
+	end
+	if type(persist_state.note_roots) == "table" then
+		local dirs = {}
+		for _, root in ipairs(persist_state.note_roots) do
+			table.insert(dirs, root.dir)
+		end
+		persist_state.note_dirs = #dirs > 0 and dirs or nil
+	else
+		persist_state.note_dirs = nil
+	end
+
+	local state_file = M.config.state_dir .. "/state.json"
+	return M.helpers.table_to_file_atomic(persist_state, state_file)
+end
+
 ---@param update table | nil # table with options
 M.refresh_state = function(update)
	local state_file = M.config.state_dir .. "/state.json"
@@ -1244,44 +1295,12 @@ M.refresh_state = function(update)
		end
	end

-	-- Note-mode roots are transient (super-repo toggle, or plain repo
-	-- mode tagging the primary with label = "repo"). Never persist them
-	-- — otherwise a later session with a different cwd would restore
-	-- roots it shouldn't have. Issue #117 M2: chat roots are no longer
-	-- persisted at all (derived from config + repo + super-repo); only
-	-- the note side still goes through strip_transient.
-	local persist_state = vim.deepcopy(M._state)
-	persist_state.chat_roots = nil
-	persist_state.chat_dirs = nil
-	local function resolve_dir(d)
-		local out = vim.fn.resolve(vim.fn.expand(d)):gsub("/+$", "")
-		return out
-	end
-	local function set_of(list)
-		local s = {}
-		for _, d in ipairs(list or {}) do s[d] = true end
-		return s
-	end
-	local pushed_note = set_of(super_repo.get_pushed_note_dirs())
-	if type(persist_state.note_roots) == "table" then
-		local filtered = {}
-		for _, root in ipairs(persist_state.note_roots) do
-			if root.label ~= "repo" and not pushed_note[resolve_dir(root.dir)] then
-				table.insert(filtered, root)
-			end
-		end
-		persist_state.note_roots = #filtered > 0 and filtered or nil
-	end
-	if type(persist_state.note_roots) == "table" then
-		local dirs = {}
-		for _, root in ipairs(persist_state.note_roots) do
-			table.insert(dirs, root.dir)
-		end
-		persist_state.note_dirs = #dirs > 0 and dirs or nil
-	else
-		persist_state.note_dirs = nil
+	-- Runtime roots are filtered by the shared write-only boundary. Writing must
+	-- not reload state or disturb a live super-repo overlay.
+	local persisted, persist_err = M.persist_state()
+	if not persisted then
+		M.logger.warning("state: persistence failed: " .. tostring(persist_err or "unknown error"))
	end
-	M.helpers.table_to_file(persist_state, state_file)

	local buf = vim.api.nvim_get_current_buf()
	local file_name = vim.api.nvim_buf_get_name(buf)
diff --git a/lua/parley/keybinding_registry.lua b/lua/parley/keybinding_registry.lua
index 41847b7..41aec52 100644
--- a/lua/parley/keybinding_registry.lua
+++ b/lua/parley/keybinding_registry.lua
@@ -99,7 +99,7 @@ end
 -- Each entry:
 --   id           - unique identifier, used as callback key
 --   config_key   - key in parley config table (nil if not configurable)
---   default_key  - default shortcut string
+--   default_key  - default shortcut string (optional when config_key is set)
 --   default_modes - default mode list
 --   scope        - scope name from the forest
 --   desc         - vim keymap description
@@ -193,7 +193,6 @@ M.entries = {
	{
		id = "super_repo_toggle",
		config_key = "global_shortcut_super_repo_toggle",
-		default_key = "<C-g>S",
		default_modes = { "n", "i" },
		scope = "global",
		desc = "Toggle super-repo mode (aggregate reads across sibling .parley repos)",
@@ -573,7 +572,6 @@ M.entries = {
	{
		id = "chat_prune",
		config_key = "chat_shortcut_prune",
-		default_key = "<C-g>p",
		default_modes = { "n" },
		scope = "chat",
		desc = "Parley prune chat",
@@ -623,7 +621,6 @@ M.entries = {
	{
		id = "chat_toggle_tool_folds",
		config_key = "chat_shortcut_toggle_tool_folds",
-		default_key = "<C-g>b",
		default_modes = { "n" },
		scope = "chat",
		desc = "Parley toggle tool folds",
@@ -916,8 +913,13 @@ end
 function M.resolve_keys(entry, config)
	local function as_list(v)
		if v == nil then return nil end
-		if type(v) == "string" then return { v } end
-		return v
+		if type(v) == "string" then return v ~= "" and { v } or nil end
+		if type(v) ~= "table" then return nil end
+		local keys = {}
+		for _, key in ipairs(v) do
+			if type(key) == "string" and key ~= "" then table.insert(keys, key) end
+		end
+		return #keys > 0 and keys or nil
	end

	if not entry.config_key then
@@ -1002,7 +1004,7 @@ function M.help_lines(context, config, bufnr)
			table.insert(lines, M.scope_labels[scope] or scope)
			for _, entry in ipairs(scope_entries) do
				local key = resolve_display_shortcut(entry, config, bufnr)
-				add(key, entry.help_desc or entry.desc)
+				if key then add(key, entry.help_desc or entry.desc) end
			end
			table.insert(lines, "")
		end
diff --git a/lua/parley/repo_mode.lua b/lua/parley/repo_mode.lua
new file mode 100644
index 0000000..23d3a48
--- /dev/null
+++ b/lua/parley/repo_mode.lua
@@ -0,0 +1,37 @@
+local M = {}
+
+local function valid_mode(mode)
+    return mode == "repo" or mode == "super_repo"
+end
+
+local function valid_root(root)
+    return type(root) == "string" and root ~= ""
+end
+
+M.resolve = function(repo_modes, canonical_root)
+    if type(repo_modes) ~= "table" or not valid_root(canonical_root) then
+        return nil
+    end
+    local mode = repo_modes[canonical_root]
+    if valid_mode(mode) then
+        return mode
+    end
+    return nil
+end
+
+M.updated = function(repo_modes, canonical_root, mode)
+    local result = {}
+    if type(repo_modes) == "table" then
+        for root, saved_mode in pairs(repo_modes) do
+            if valid_root(root) and valid_mode(saved_mode) then
+                result[root] = saved_mode
+            end
+        end
+    end
+    if valid_root(canonical_root) and valid_mode(mode) then
+        result[canonical_root] = mode
+    end
+    return result
+end
+
+return M
diff --git a/lua/parley/super_repo.lua b/lua/parley/super_repo.lua
index a7297b5..1ae62a1 100644
--- a/lua/parley/super_repo.lua
+++ b/lua/parley/super_repo.lua
@@ -3,12 +3,12 @@
 -- Toggle activates a runtime overlay on top of plain repo mode:
 --   * Discovers sibling .parley repos under the current repo's parent dir.
 --   * Pushes their workshop/parley and workshop/notes paths into chat_roots
---     and note_roots as extras (label = "repo" so they are filtered out of
---     persisted state.json — see init.lua persistence gate).
+--     and note_roots as labelled transient extras.
 --   * Writes are unchanged: still go to the current repo, exactly as plain
 --     repo mode does today.
 --
--- Toggle is transient — never persisted.
+-- This module owns only the runtime overlay. parley.init persists explicit
+-- user choices and restores them through set_active().

 local M = {}
 local _parley
@@ -213,11 +213,15 @@ local function deactivate()
	return true
 end

-M.toggle = function()
-	if _state.active then
-		return deactivate()
+M.set_active = function(active)
+	if active then
+		return activate()
	end
-	return activate()
+	return deactivate()
+end
+
+M.toggle = function()
+	return M.set_active(not _state.active)
 end

 return M

exec
/bin/zsh -lc "sed -n '1,260p' TOOLING.md && scripts/spec_test_map.sh list-tests modes/super_repo && scripts/spec_test_map.sh list-tests ui/keybindings && scripts/spec_test_map.sh list-tests infra/repo_mode && scripts/spec_test_map.sh list-tests chat/lifecycle && rg -n '<C-g>S|Pruning \\("'`<C-g>p`'"\\)|chat_shortcut_toggle_tool_folds.*<C-g>b|Brain repos auto|Toggle is transient|never persisted' README.md atlas lua tests || true && rg -n 'super.repo|super_repo|peer mode|peer-mode|repo_modes|\\.brain' README.md atlas lua tests --glob '"'!tests/unit/super_repo_spec.lua'"'" in /Users/xianxu/workspace/parley.nvim
 succeeded in 0ms:
# Tooling

## Development Commands
- Manual testing: Start Neovim and use `:lua require('parley').setup()` followed by `:Parley`
- Run tests: `make test` (runs all unit + integration tests via plenary.nvim in headless Neovim)
- Lint: `make lint` (requires `luacheck`; see install note below)
- Run tests for one spec: `make test-spec SPEC=chat/lifecycle` (uses `atlas/traceability.yaml` mapping)
- Run tests for changed specs: `make test-changed` (runs mapped tests for changed `atlas/*/*.md` files), this is faster than full test run
- Run the report-only real chat-typing benchmark: `make perf` (details below).
- Refresh SSE fixtures: `ANTHROPIC_API_KEY=... OPENAI_API_KEY=... make fixtures`
- Test files live in `tests/unit/` (pure logic, no Neovim APIs) and `tests/integration/` (full Neovim runtime)

## Chat-Typing Performance Report

`make perf` opens normally attached Parley chat buffers at 100, 1,000, and
5,000 lines, performs 5 warmups and 20 measured samples, and reports the real
insert-event/redraw interval plus isolated timezone, footnote, decoration, and
spell phases. Inclusive `edit_total` overlaps the isolated measurements; do not
add or subtract the isolated phase timings as if they decomposed it.

The command prints median/p95 timings and scaling ratios, then overwrites
`.test-tmp/perf/parley-chat-typing.json`. Override the destination (including a
new parent directory) with:

```sh
make perf PERF_OUTPUT=/path/to/parley-chat-typing.json
```

The JSON envelope has `schema_version: 1`, `generated_at`,
`timing_unit: "milliseconds"`, `environment` (`os`, `nvim`, and the measured
git `commit`), and `scenarios`. Every scenario records `name`, `phase`,
`attribution` (`inclusive` or `isolated`), `line_count`, `iteration_count`,
`elapsed_ms` (`samples`, `median`, `p95`), and `work`
(`line_read_calls`, `lines_requested`, `full_buffer_reads`, and
`structure_rows_processed`). Generated reports are ignored artifacts; durable
baseline/optimized summaries belong in the issue log.

Elapsed timings are report-only and never fail CI. Scenario validity and
structural bounds are correctness gates: the measured insert event must not
perform a full-buffer read; decoration reads stay within the viewport/context
allowances; matched 1,000/5,000-line viewports request identical work; and
ordinary prose edits process the same bounded structure rows. Timezone and
managed-footnote diagnostics deliberately remain stale during `TextChangedI`,
then converge synchronously on `InsertLeave`, normal `TextChanged`,
`BufWritePost`, `BufEnter`, `WinEnter`, and stream-leg finalization. Structural
marker edits may suppress decorations during insertion; the same convergence
events rebuild structure before returning. Redraw itself consumes only the
buffer-owned bounded structure snapshot and visible/context rows.

For an optional manual comparison, repeat ordinary typing with
`:MarkdownPreview` enabled. The automated report intentionally excludes that
external plugin so its measurements attribute only Parley-owned work.

## Installing `luacheck` (macOS)

`luacheck` 1.2.0 (current stable) is incompatible with Lua 5.5's stricter
`<const>` semantics — loading fails with `attempt to assign to const variable
'field_name'`. Brew's `lua` formula tracks latest, so a fresh
`brew install luarocks` pulls in 5.5 and breaks lint.

Install against Lua 5.4 instead:

```
brew install lua@5.4
luarocks --lua-version=5.4 install luacheck
ln -sf "$(brew --prefix lua@5.4)/bin/luacheck-5.4" "$(brew --prefix)/bin/luacheck"
```

Verify with `luacheck --version`. If `make test` still complains, ensure
`luacheck` is on `PATH` ahead of any 5.5 install.
tests/unit/chat_finder_logic_spec.lua
tests/unit/finder_facets_spec.lua
tests/unit/float_picker_spec.lua
tests/unit/helper_io_spec.lua
tests/unit/issue_finder_spec.lua
tests/unit/markdown_finder_spec.lua
tests/unit/repo_mode_spec.lua
tests/unit/super_repo_spec.lua
tests/unit/config_tools_spec.lua
tests/unit/keybindings_spec.lua
tests/unit/helper_io_spec.lua
tests/unit/repo_mode_spec.lua
tests/unit/super_repo_spec.lua
tests/arch/performance_line_reader_spec.lua
tests/integration/chat_lease_spec.lua
tests/integration/chat_move_spec.lua
tests/integration/chat_pending_spec.lua
tests/integration/chat_respond_spec.lua
tests/integration/create_handler_spec.lua
tests/integration/diagnostic_refresh_spec.lua
tests/integration/highlighting_spec.lua
tests/integration/new_chat_spec.lua
tests/integration/not_chat_spec.lua
tests/integration/perf_chat_typing_spec.lua
tests/integration/tasker_run_spec.lua
tests/integration/timer_race_spec.lua
tests/unit/buffer_lifecycle_spec.lua
tests/unit/chat_history_spec.lua
tests/unit/chat_respond_footnote_spec.lua
tests/unit/config_tools_spec.lua
tests/unit/diagnostic_refresh_spec.lua
tests/unit/highlight_structure_spec.lua
tests/unit/keybindings_spec.lua
tests/unit/line_reader_spec.lua
tests/unit/perf_harness_spec.lua
tests/unit/chat_dirs_spec.lua:4:-- mode + super-repo, never freeform-mutated and never persisted to
README.md:123:  repository facets in super-repo mode; query text and facet choices persist
README.md:127:- `<C-g>p` toggle peer (super-repo) mode - aggregate reads across sibling
atlas/issues/issue-management.md:20:- `:ParleyIssueFinder` (`<C-y>f`): float picker with status badges and 2-state view cycling — `<Tab>` (natural key; `<C-a>` kept for back-compat) toggles between `issues` (all of `workshop/issues/`, done items visible — the default, sorted by the existing status/ID order) and `history` (archived items in `workshop/history/`, sorted by file modification time ascending so the newest archive row sits closest to the bottom-anchored prompt) (#158, superseding the tri-state all/active/all+history from #152). The complete prompt query is kept verbatim across that repaint and later Issue Finder invocations; clearing the prompt persists the empty query (#177). In super-repo mode, a completely labelled root set with at least two distinct repositories adds Chat Finder's existing `[ALL] [NONE]   [repo…]` facet bar. Repo choices share one persistent state across both views and invocations, and facet updates repaint in place without touching the query; newly discovered repos default on while temporarily absent choices are retained. Incomplete labels, a single unique repo, and ordinary single-root mode omit the bar and leave rows unfiltered. Persisted NONE still opens the empty picker so ALL remains reachable (#186).
tests/fixtures/golden_payloads/two-round-tool-use.json:1:{"model":"claude-sonnet-4-6","stream":true,"max_tokens":4096,"system":[{"text":"A conversation between You and Me. \n\nWe collaboratively seek knowledge, truth and learn together. \n\nWe are peers, we should be serious, transparent and critical in our discussion. \n\nYou MUST first think about how to response before responding. \n\nReason about how much information is appropriate. \n\nToo much information will overwhelm the user; too general information is useless. \n\nThe best way is to assess how much I know about the topic as the conversation proceeds. \n\nAssess my intention behind a question as they may not be fomulated perfectly. \n\nPay close attention to nuiances in my question; when they seem to be repetitive, that usually is a sign your answer did not hit the point.\n\nStrive to understand the question behind my questions. \n\nDo not repeat information if information is already provided in previous chat\n\nFinish the thinking process first before proceed to answer my question. \n\nThis thinking should contain a concise a plan of your answer, including key concepts, facts. \n\nThose key concepts and facts should be selected based on your perception of my knowledge, with the goal to engage in a deeper discussion.\n\nMake sure you respond in correct grammar, use Markdown to organize information hierarchy your reply. \n\nIMPORTANT: avoid top two levels of markdown heading: #, ## in answers, they are reserved for me to use. \n\nYou can use Markdown heading level 3 and beyond. \n\nYou should assess your confidence of answers, and leverage qualifiers that reflects your confidence level. \n\nYou should use Definitely or Certainly when you're highly confident; Probably or Likely when you're moderately confident; Maybe, Possibly, or Not Sure when uncertain. \n\nIf you're unsure or lacking information, don't guess and just say you don't know instead.\n\nSay you don't know when your confidence in answer is really low, below 30% of confidence\n\nIt is better for you to ask clarifying questions when you do not have confidence you understand my questions, the intention behind the questions.\n\nDon't elide any code from your output if the answer requires coding.\n\nWhen providing code, make sure it works.\n\nAfter you finish your answer, create a single plaintext line summary of my question, key points and facts of your answer.\n\nThis summary should the format of: you asked about [summary of question], I answered with [summary of answer], without any newline, no need to form proper sentence, prefixed with 📝:.\n\nLeave an empty line between the main answer, and summary line (📝:)\n\nWhen you write code, consider also generating test cases and commands for user to manually test.\n\nEnclose those in markdown code block ```\n\nWhen you did web_search, or web_fetch, generate reference your answer is based on.\n\nFormat your reference as links in markdown, around key phrases only, such as [issue x](link), or [more details](link)\n\nWhen you have tools available, use the minimum number of tool calls needed to answer. If one or two tool calls give you enough context, answer immediately — do not explore further. Prefer answering from the context you already have over making additional tool calls.\n\nIMPORTANT: always generate summary line prefixed with `📝:` at the end.","type":"text","cache_control":{"type":"ephemeral"}}],"tools":[{"max_uses":5,"type":"web_search_20260209","name":"web_search"},{"max_uses":5,"type":"web_fetch_20260209","name":"web_fetch"},{"input_schema":{"required":["file_path"],"type":"object","properties":{"offset":{"description":"Line number to start reading from (1-indexed). Default: 1.","type":"integer"},"limit":{"description":"Maximum number of lines to return. Default: no limit.","type":"integer"},"file_path":{"description":"Path to the file. Relative to the working directory or absolute.","type":"string"}}},"name":"read_file","description":"Read a file and return its contents with line numbers. Use offset to start from a specific line, limit to cap the number of lines returned (default: all lines)."},{"input_schema":{"required":["path"],"type":"object","properties":{"path":{"description":"Directory or file path to list. Relative to the working directory or absolute.","type":"string"},"flags":{"type":"array","description":"Safe ls display flags, e.g. { '-la' }, { '-R' }. Allowed compact characters: a A l h R t r S 1 d F. Long flags are not accepted.","items":{"type":"string"}},"limit":{"description":"Output pager: max lines to return (default 200, max 2000). Re-call with a higher offset to page through, or narrow your query.","type":"integer"},"offset":{"description":"Output pager: 1-indexed line to start the returned window at (default 1).","type":"integer"}}},"name":"ls","description":"List directory contents using the system ls command (BSD ls (macOS)). Use structured fields: path plus safe short flags such as '-la', '-R', '-t'. Example: { path = '.', flags = { '-la' } }. Paths are confined to the working directory and configured read roots."},{"input_schema":{"required":["path"],"type":"object","properties":{"maxdepth":{"description":"Maximum directory depth.","type":"integer"},"type":{"description":"Entry type: f (file), d (directory), or l (symlink).","type":"string"},"offset":{"description":"Output pager: 1-indexed line to start the returned window at (default 1).","type":"integer"},"iname":{"description":"Case-insensitive basename pattern.","type":"string"},"path":{"description":"Directory path to search. Relative to the working directory or absolute.","type":"string"},"mindepth":{"description":"Minimum directory depth.","type":"integer"},"limit":{"description":"Output pager: max lines to return (default 200, max 2000). Re-call with a higher offset to page through, or narrow your query.","type":"integer"},"name":{"description":"Find entries whose basename matches this pattern, e.g. '*.lua'.","type":"string"}}},"name":"find","description":"Search for files and directories using the system find command (BSD find (macOS)). Use structured fields: path, name/iname, type, maxdepth, and mindepth. Example: { path = '.', name = '*.lua', type = 'f' }. Paths are confined to the working directory and configured read roots."},{"input_schema":{"required":["pattern"],"type":"object","properties":{"paths":{"type":"array","description":"File or directory paths to search. Overrides path when present.","items":{"type":"string"}},"path":{"description":"File or directory path to search. Defaults to '.'.","type":"string"},"context":{"description":"Context lines before and after each match.","type":"integer"},"limit":{"description":"Output pager: max lines to return (default 200, max 2000). Re-call with a higher offset to page through, or narrow your query.","type":"integer"},"context_after":{"description":"Context lines after each match.","type":"integer"},"context_before":{"description":"Context lines before each match.","type":"integer"},"ignore_case":{"description":"Case-insensitive search.","type":"boolean"},"glob":{"description":"File glob filter, e.g. '*.lua'. Supported natively by ripgrep.","type":"string"},"offset":{"description":"Output pager: 1-indexed line to start the returned window at (default 1).","type":"integer"},"flags":{"type":"array","description":"Safe read-only flags only: -n, --line-number, -w, --word-regexp, -F, --fixed-strings, --hidden, --no-ignore.","items":{"type":"string"}},"pattern":{"description":"Regex or fixed-string pattern to search for.","type":"string"},"type":{"description":"Ripgrep file type filter, e.g. 'lua'. Ignored by system grep fallback.","type":"string"}}},"name":"grep","description":"Search file contents using ripgrep (ripgrep 15.1.0). Use structured fields: pattern, path/paths, glob, type, ignore_case, context, and safe flags. Example: { pattern = 'foo', path = 'lua', glob = '*.lua' }. Paths are confined to the working directory and configured read roots."},{"input_schema":{"required":["pattern"],"type":"object","properties":{"after":{"description":"Lines of context after each match. Default: 2.","type":"integer"},"max_count":{"description":"Maximum matches per file. Optional.","type":"integer"},"limit":{"description":"Output pager: max lines to return (default 200, max 2000). Re-call with a higher offset to page through, or narrow your query.","type":"integer"},"glob":{"description":"File glob filter. Default: '*.md'.","type":"string"},"offset":{"description":"Output pager: 1-indexed line to start the returned window at (default 1).","type":"integer"},"case_insensitive":{"description":"Case-insensitive match. Default: true.","type":"boolean"},"pattern":{"description":"Regex pattern to search for. Required.","type":"string"},"before":{"description":"Lines of context before each match. Default: 1.","type":"integer"}}},"name":"chat_history_search","description":"Use this whenever the user refers to past chats — phrases like 'do you remember when we talked about X', 'what did we discuss about Y', 'have we chatted about Z before', 'find past chats on W'. Searches the user's saved chat transcripts (markdown files) across all configured chat roots: global, current repo, and any super-repo siblings. Output paths are prefixed with `{<repo>}/` so you can tell which repo each hit lives in. Default context is -B1 -A2 lines around each match. Backend: ripgrep (ripgrep 15.1.0)."}],"messages":[{"role":"user","content":"read foo.txt and bar.txt"},{"role":"assistant","content":[{"input":{"path":"foo.txt"},"type":"tool_use","id":"toolu_A","name":"read_file"}]},{"role":"user","content":[{"tool_use_id":"toolu_A","type":"tool_result","is_error":false,"content":"    1  hi from foo"}]},{"role":"assistant","content":[{"input":{"path":"bar.txt"},"type":"tool_use","id":"toolu_B","name":"read_file"}]},{"role":"user","content":[{"tool_use_id":"toolu_B","type":"tool_result","is_error":false,"content":"    1  hi from bar"}]}]}
lua/parley/issue_finder.lua:155:    -- Compute issue roots: in super-repo mode, one per member; otherwise just the single repo.
lua/parley/issue_finder.lua:156:    local sr_issues = _parley.super_repo and _parley.super_repo.expand_roots(_parley.config.issues_dir) or nil
lua/parley/issue_finder.lua:157:    local sr_history = _parley.super_repo and _parley.super_repo.expand_roots(_parley.config.history_dir) or nil
tests/fixtures/golden_payloads/tool-error.json:1:{"model":"claude-sonnet-4-6","stream":true,"max_tokens":4096,"system":[{"text":"A conversation between You and Me. \n\nWe collaboratively seek knowledge, truth and learn together. \n\nWe are peers, we should be serious, transparent and critical in our discussion. \n\nYou MUST first think about how to response before responding. \n\nReason about how much information is appropriate. \n\nToo much information will overwhelm the user; too general information is useless. \n\nThe best way is to assess how much I know about the topic as the conversation proceeds. \n\nAssess my intention behind a question as they may not be fomulated perfectly. \n\nPay close attention to nuiances in my question; when they seem to be repetitive, that usually is a sign your answer did not hit the point.\n\nStrive to understand the question behind my questions. \n\nDo not repeat information if information is already provided in previous chat\n\nFinish the thinking process first before proceed to answer my question. \n\nThis thinking should contain a concise a plan of your answer, including key concepts, facts. \n\nThose key concepts and facts should be selected based on your perception of my knowledge, with the goal to engage in a deeper discussion.\n\nMake sure you respond in correct grammar, use Markdown to organize information hierarchy your reply. \n\nIMPORTANT: avoid top two levels of markdown heading: #, ## in answers, they are reserved for me to use. \n\nYou can use Markdown heading level 3 and beyond. \n\nYou should assess your confidence of answers, and leverage qualifiers that reflects your confidence level. \n\nYou should use Definitely or Certainly when you're highly confident; Probably or Likely when you're moderately confident; Maybe, Possibly, or Not Sure when uncertain. \n\nIf you're unsure or lacking information, don't guess and just say you don't know instead.\n\nSay you don't know when your confidence in answer is really low, below 30% of confidence\n\nIt is better for you to ask clarifying questions when you do not have confidence you understand my questions, the intention behind the questions.\n\nDon't elide any code from your output if the answer requires coding.\n\nWhen providing code, make sure it works.\n\nAfter you finish your answer, create a single plaintext line summary of my question, key points and facts of your answer.\n\nThis summary should the format of: you asked about [summary of question], I answered with [summary of answer], without any newline, no need to form proper sentence, prefixed with 📝:.\n\nLeave an empty line between the main answer, and summary line (📝:)\n\nWhen you write code, consider also generating test cases and commands for user to manually test.\n\nEnclose those in markdown code block ```\n\nWhen you did web_search, or web_fetch, generate reference your answer is based on.\n\nFormat your reference as links in markdown, around key phrases only, such as [issue x](link), or [more details](link)\n\nWhen you have tools available, use the minimum number of tool calls needed to answer. If one or two tool calls give you enough context, answer immediately — do not explore further. Prefer answering from the context you already have over making additional tool calls.\n\nIMPORTANT: always generate summary line prefixed with `📝:` at the end.","type":"text","cache_control":{"type":"ephemeral"}}],"tools":[{"max_uses":5,"type":"web_search_20260209","name":"web_search"},{"max_uses":5,"type":"web_fetch_20260209","name":"web_fetch"},{"input_schema":{"required":["file_path"],"type":"object","properties":{"offset":{"description":"Line number to start reading from (1-indexed). Default: 1.","type":"integer"},"limit":{"description":"Maximum number of lines to return. Default: no limit.","type":"integer"},"file_path":{"description":"Path to the file. Relative to the working directory or absolute.","type":"string"}}},"name":"read_file","description":"Read a file and return its contents with line numbers. Use offset to start from a specific line, limit to cap the number of lines returned (default: all lines)."},{"input_schema":{"required":["path"],"type":"object","properties":{"path":{"description":"Directory or file path to list. Relative to the working directory or absolute.","type":"string"},"flags":{"type":"array","description":"Safe ls display flags, e.g. { '-la' }, { '-R' }. Allowed compact characters: a A l h R t r S 1 d F. Long flags are not accepted.","items":{"type":"string"}},"limit":{"description":"Output pager: max lines to return (default 200, max 2000). Re-call with a higher offset to page through, or narrow your query.","type":"integer"},"offset":{"description":"Output pager: 1-indexed line to start the returned window at (default 1).","type":"integer"}}},"name":"ls","description":"List directory contents using the system ls command (BSD ls (macOS)). Use structured fields: path plus safe short flags such as '-la', '-R', '-t'. Example: { path = '.', flags = { '-la' } }. Paths are confined to the working directory and configured read roots."},{"input_schema":{"required":["path"],"type":"object","properties":{"maxdepth":{"description":"Maximum directory depth.","type":"integer"},"type":{"description":"Entry type: f (file), d (directory), or l (symlink).","type":"string"},"offset":{"description":"Output pager: 1-indexed line to start the returned window at (default 1).","type":"integer"},"iname":{"description":"Case-insensitive basename pattern.","type":"string"},"path":{"description":"Directory path to search. Relative to the working directory or absolute.","type":"string"},"mindepth":{"description":"Minimum directory depth.","type":"integer"},"limit":{"description":"Output pager: max lines to return (default 200, max 2000). Re-call with a higher offset to page through, or narrow your query.","type":"integer"},"name":{"description":"Find entries whose basename matches this pattern, e.g. '*.lua'.","type":"string"}}},"name":"find","description":"Search for files and directories using the system find command (BSD find (macOS)). Use structured fields: path, name/iname, type, maxdepth, and mindepth. Example: { path = '.', name = '*.lua', type = 'f' }. Paths are confined to the working directory and configured read roots."},{"input_schema":{"required":["pattern"],"type":"object","properties":{"paths":{"type":"array","description":"File or directory paths to search. Overrides path when present.","items":{"type":"string"}},"path":{"description":"File or directory path to search. Defaults to '.'.","type":"string"},"context":{"description":"Context lines before and after each match.","type":"integer"},"limit":{"description":"Output pager: max lines to return (default 200, max 2000). Re-call with a higher offset to page through, or narrow your query.","type":"integer"},"context_after":{"description":"Context lines after each match.","type":"integer"},"context_before":{"description":"Context lines before each match.","type":"integer"},"ignore_case":{"description":"Case-insensitive search.","type":"boolean"},"glob":{"description":"File glob filter, e.g. '*.lua'. Supported natively by ripgrep.","type":"string"},"offset":{"description":"Output pager: 1-indexed line to start the returned window at (default 1).","type":"integer"},"flags":{"type":"array","description":"Safe read-only flags only: -n, --line-number, -w, --word-regexp, -F, --fixed-strings, --hidden, --no-ignore.","items":{"type":"string"}},"pattern":{"description":"Regex or fixed-string pattern to search for.","type":"string"},"type":{"description":"Ripgrep file type filter, e.g. 'lua'. Ignored by system grep fallback.","type":"string"}}},"name":"grep","description":"Search file contents using ripgrep (ripgrep 15.1.0). Use structured fields: pattern, path/paths, glob, type, ignore_case, context, and safe flags. Example: { pattern = 'foo', path = 'lua', glob = '*.lua' }. Paths are confined to the working directory and configured read roots."},{"input_schema":{"required":["pattern"],"type":"object","properties":{"after":{"description":"Lines of context after each match. Default: 2.","type":"integer"},"max_count":{"description":"Maximum matches per file. Optional.","type":"integer"},"limit":{"description":"Output pager: max lines to return (default 200, max 2000). Re-call with a higher offset to page through, or narrow your query.","type":"integer"},"glob":{"description":"File glob filter. Default: '*.md'.","type":"string"},"offset":{"description":"Output pager: 1-indexed line to start the returned window at (default 1).","type":"integer"},"case_insensitive":{"description":"Case-insensitive match. Default: true.","type":"boolean"},"pattern":{"description":"Regex pattern to search for. Required.","type":"string"},"before":{"description":"Lines of context before each match. Default: 1.","type":"integer"}}},"name":"chat_history_search","description":"Use this whenever the user refers to past chats — phrases like 'do you remember when we talked about X', 'what did we discuss about Y', 'have we chatted about Z before', 'find past chats on W'. Searches the user's saved chat transcripts (markdown files) across all configured chat roots: global, current repo, and any super-repo siblings. Output paths are prefixed with `{<repo>}/` so you can tell which repo each hit lives in. Default context is -B1 -A2 lines around each match. Backend: ripgrep (ripgrep 15.1.0)."}],"messages":[{"role":"user","content":"read /etc/hosts"},{"role":"assistant","content":[{"input":{"path":"/etc/hosts"},"type":"tool_use","id":"toolu_E","name":"read_file"}]},{"role":"user","content":[{"tool_use_id":"toolu_E","type":"tool_result","is_error":true,"content":"path /etc/hosts is outside working directory"}]}]}
tests/fixtures/golden_payloads/mixed-text-and-tools.json:1:{"model":"claude-sonnet-4-6","stream":true,"max_tokens":4096,"system":[{"text":"A conversation between You and Me. \n\nWe collaboratively seek knowledge, truth and learn together. \n\nWe are peers, we should be serious, transparent and critical in our discussion. \n\nYou MUST first think about how to response before responding. \n\nReason about how much information is appropriate. \n\nToo much information will overwhelm the user; too general information is useless. \n\nThe best way is to assess how much I know about the topic as the conversation proceeds. \n\nAssess my intention behind a question as they may not be fomulated perfectly. \n\nPay close attention to nuiances in my question; when they seem to be repetitive, that usually is a sign your answer did not hit the point.\n\nStrive to understand the question behind my questions. \n\nDo not repeat information if information is already provided in previous chat\n\nFinish the thinking process first before proceed to answer my question. \n\nThis thinking should contain a concise a plan of your answer, including key concepts, facts. \n\nThose key concepts and facts should be selected based on your perception of my knowledge, with the goal to engage in a deeper discussion.\n\nMake sure you respond in correct grammar, use Markdown to organize information hierarchy your reply. \n\nIMPORTANT: avoid top two levels of markdown heading: #, ## in answers, they are reserved for me to use. \n\nYou can use Markdown heading level 3 and beyond. \n\nYou should assess your confidence of answers, and leverage qualifiers that reflects your confidence level. \n\nYou should use Definitely or Certainly when you're highly confident; Probably or Likely when you're moderately confident; Maybe, Possibly, or Not Sure when uncertain. \n\nIf you're unsure or lacking information, don't guess and just say you don't know instead.\n\nSay you don't know when your confidence in answer is really low, below 30% of confidence\n\nIt is better for you to ask clarifying questions when you do not have confidence you understand my questions, the intention behind the questions.\n\nDon't elide any code from your output if the answer requires coding.\n\nWhen providing code, make sure it works.\n\nAfter you finish your answer, create a single plaintext line summary of my question, key points and facts of your answer.\n\nThis summary should the format of: you asked about [summary of question], I answered with [summary of answer], without any newline, no need to form proper sentence, prefixed with 📝:.\n\nLeave an empty line between the main answer, and summary line (📝:)\n\nWhen you write code, consider also generating test cases and commands for user to manually test.\n\nEnclose those in markdown code block ```\n\nWhen you did web_search, or web_fetch, generate reference your answer is based on.\n\nFormat your reference as links in markdown, around key phrases only, such as [issue x](link), or [more details](link)\n\nWhen you have tools available, use the minimum number of tool calls needed to answer. If one or two tool calls give you enough context, answer immediately — do not explore further. Prefer answering from the context you already have over making additional tool calls.\n\nIMPORTANT: always generate summary line prefixed with `📝:` at the end.","type":"text","cache_control":{"type":"ephemeral"}}],"tools":[{"max_uses":5,"type":"web_search_20260209","name":"web_search"},{"max_uses":5,"type":"web_fetch_20260209","name":"web_fetch"},{"input_schema":{"required":["file_path"],"type":"object","properties":{"offset":{"description":"Line number to start reading from (1-indexed). Default: 1.","type":"integer"},"limit":{"description":"Maximum number of lines to return. Default: no limit.","type":"integer"},"file_path":{"description":"Path to the file. Relative to the working directory or absolute.","type":"string"}}},"name":"read_file","description":"Read a file and return its contents with line numbers. Use offset to start from a specific line, limit to cap the number of lines returned (default: all lines)."},{"input_schema":{"required":["path"],"type":"object","properties":{"path":{"description":"Directory or file path to list. Relative to the working directory or absolute.","type":"string"},"flags":{"type":"array","description":"Safe ls display flags, e.g. { '-la' }, { '-R' }. Allowed compact characters: a A l h R t r S 1 d F. Long flags are not accepted.","items":{"type":"string"}},"limit":{"description":"Output pager: max lines to return (default 200, max 2000). Re-call with a higher offset to page through, or narrow your query.","type":"integer"},"offset":{"description":"Output pager: 1-indexed line to start the returned window at (default 1).","type":"integer"}}},"name":"ls","description":"List directory contents using the system ls command (BSD ls (macOS)). Use structured fields: path plus safe short flags such as '-la', '-R', '-t'. Example: { path = '.', flags = { '-la' } }. Paths are confined to the working directory and configured read roots."},{"input_schema":{"required":["path"],"type":"object","properties":{"maxdepth":{"description":"Maximum directory depth.","type":"integer"},"type":{"description":"Entry type: f (file), d (directory), or l (symlink).","type":"string"},"offset":{"description":"Output pager: 1-indexed line to start the returned window at (default 1).","type":"integer"},"iname":{"description":"Case-insensitive basename pattern.","type":"string"},"path":{"description":"Directory path to search. Relative to the working directory or absolute.","type":"string"},"mindepth":{"description":"Minimum directory depth.","type":"integer"},"limit":{"description":"Output pager: max lines to return (default 200, max 2000). Re-call with a higher offset to page through, or narrow your query.","type":"integer"},"name":{"description":"Find entries whose basename matches this pattern, e.g. '*.lua'.","type":"string"}}},"name":"find","description":"Search for files and directories using the system find command (BSD find (macOS)). Use structured fields: path, name/iname, type, maxdepth, and mindepth. Example: { path = '.', name = '*.lua', type = 'f' }. Paths are confined to the working directory and configured read roots."},{"input_schema":{"required":["pattern"],"type":"object","properties":{"paths":{"type":"array","description":"File or directory paths to search. Overrides path when present.","items":{"type":"string"}},"path":{"description":"File or directory path to search. Defaults to '.'.","type":"string"},"context":{"description":"Context lines before and after each match.","type":"integer"},"limit":{"description":"Output pager: max lines to return (default 200, max 2000). Re-call with a higher offset to page through, or narrow your query.","type":"integer"},"context_after":{"description":"Context lines after each match.","type":"integer"},"context_before":{"description":"Context lines before each match.","type":"integer"},"ignore_case":{"description":"Case-insensitive search.","type":"boolean"},"glob":{"description":"File glob filter, e.g. '*.lua'. Supported natively by ripgrep.","type":"string"},"offset":{"description":"Output pager: 1-indexed line to start the returned window at (default 1).","type":"integer"},"flags":{"type":"array","description":"Safe read-only flags only: -n, --line-number, -w, --word-regexp, -F, --fixed-strings, --hidden, --no-ignore.","items":{"type":"string"}},"pattern":{"description":"Regex or fixed-string pattern to search for.","type":"string"},"type":{"description":"Ripgrep file type filter, e.g. 'lua'. Ignored by system grep fallback.","type":"string"}}},"name":"grep","description":"Search file contents using ripgrep (ripgrep 15.1.0). Use structured fields: pattern, path/paths, glob, type, ignore_case, context, and safe flags. Example: { pattern = 'foo', path = 'lua', glob = '*.lua' }. Paths are confined to the working directory and configured read roots."},{"input_schema":{"required":["pattern"],"type":"object","properties":{"after":{"description":"Lines of context after each match. Default: 2.","type":"integer"},"max_count":{"description":"Maximum matches per file. Optional.","type":"integer"},"limit":{"description":"Output pager: max lines to return (default 200, max 2000). Re-call with a higher offset to page through, or narrow your query.","type":"integer"},"glob":{"description":"File glob filter. Default: '*.md'.","type":"string"},"offset":{"description":"Output pager: 1-indexed line to start the returned window at (default 1).","type":"integer"},"case_insensitive":{"description":"Case-insensitive match. Default: true.","type":"boolean"},"pattern":{"description":"Regex pattern to search for. Required.","type":"string"},"before":{"description":"Lines of context before each match. Default: 1.","type":"integer"}}},"name":"chat_history_search","description":"Use this whenever the user refers to past chats — phrases like 'do you remember when we talked about X', 'what did we discuss about Y', 'have we chatted about Z before', 'find past chats on W'. Searches the user's saved chat transcripts (markdown files) across all configured chat roots: global, current repo, and any super-repo siblings. Output paths are prefixed with `{<repo>}/` so you can tell which repo each hit lives in. Default context is -B1 -A2 lines around each match. Backend: ripgrep (ripgrep 15.1.0)."}],"messages":[{"role":"user","content":"tell me about init.lua"},{"role":"assistant","content":[{"text":"I'll read the file first.","type":"text"},{"input":{"path":"init.lua"},"type":"tool_use","id":"toolu_M","name":"read_file"}]},{"role":"user","content":[{"tool_use_id":"toolu_M","type":"tool_result","is_error":false,"content":"    1  local M = {}\n    2  return M"}]},{"role":"assistant","content":[{"text":"This is a minimal Lua module that exports an empty table.","type":"text"}]}]}
tests/fixtures/golden_payloads/simple-chat.json:1:{"model":"claude-sonnet-4-6","stream":true,"max_tokens":4096,"system":[{"text":"A conversation between You and Me. \n\nWe collaboratively seek knowledge, truth and learn together. \n\nWe are peers, we should be serious, transparent and critical in our discussion. \n\nYou MUST first think about how to response before responding. \n\nReason about how much information is appropriate. \n\nToo much information will overwhelm the user; too general information is useless. \n\nThe best way is to assess how much I know about the topic as the conversation proceeds. \n\nAssess my intention behind a question as they may not be fomulated perfectly. \n\nPay close attention to nuiances in my question; when they seem to be repetitive, that usually is a sign your answer did not hit the point.\n\nStrive to understand the question behind my questions. \n\nDo not repeat information if information is already provided in previous chat\n\nFinish the thinking process first before proceed to answer my question. \n\nThis thinking should contain a concise a plan of your answer, including key concepts, facts. \n\nThose key concepts and facts should be selected based on your perception of my knowledge, with the goal to engage in a deeper discussion.\n\nMake sure you respond in correct grammar, use Markdown to organize information hierarchy your reply. \n\nIMPORTANT: avoid top two levels of markdown heading: #, ## in answers, they are reserved for me to use. \n\nYou can use Markdown heading level 3 and beyond. \n\nYou should assess your confidence of answers, and leverage qualifiers that reflects your confidence level. \n\nYou should use Definitely or Certainly when you're highly confident; Probably or Likely when you're moderately confident; Maybe, Possibly, or Not Sure when uncertain. \n\nIf you're unsure or lacking information, don't guess and just say you don't know instead.\n\nSay you don't know when your confidence in answer is really low, below 30% of confidence\n\nIt is better for you to ask clarifying questions when you do not have confidence you understand my questions, the intention behind the questions.\n\nDon't elide any code from your output if the answer requires coding.\n\nWhen providing code, make sure it works.\n\nAfter you finish your answer, create a single plaintext line summary of my question, key points and facts of your answer.\n\nThis summary should the format of: you asked about [summary of question], I answered with [summary of answer], without any newline, no need to form proper sentence, prefixed with 📝:.\n\nLeave an empty line between the main answer, and summary line (📝:)\n\nWhen you write code, consider also generating test cases and commands for user to manually test.\n\nEnclose those in markdown code block ```\n\nWhen you did web_search, or web_fetch, generate reference your answer is based on.\n\nFormat your reference as links in markdown, around key phrases only, such as [issue x](link), or [more details](link)\n\nWhen you have tools available, use the minimum number of tool calls needed to answer. If one or two tool calls give you enough context, answer immediately — do not explore further. Prefer answering from the context you already have over making additional tool calls.\n\nIMPORTANT: always generate summary line prefixed with `📝:` at the end.","type":"text","cache_control":{"type":"ephemeral"}}],"tools":[{"max_uses":5,"type":"web_search_20260209","name":"web_search"},{"max_uses":5,"type":"web_fetch_20260209","name":"web_fetch"},{"input_schema":{"required":["file_path"],"type":"object","properties":{"offset":{"description":"Line number to start reading from (1-indexed). Default: 1.","type":"integer"},"limit":{"description":"Maximum number of lines to return. Default: no limit.","type":"integer"},"file_path":{"description":"Path to the file. Relative to the working directory or absolute.","type":"string"}}},"name":"read_file","description":"Read a file and return its contents with line numbers. Use offset to start from a specific line, limit to cap the number of lines returned (default: all lines)."},{"input_schema":{"required":["path"],"type":"object","properties":{"path":{"description":"Directory or file path to list. Relative to the working directory or absolute.","type":"string"},"flags":{"type":"array","description":"Safe ls display flags, e.g. { '-la' }, { '-R' }. Allowed compact characters: a A l h R t r S 1 d F. Long flags are not accepted.","items":{"type":"string"}},"limit":{"description":"Output pager: max lines to return (default 200, max 2000). Re-call with a higher offset to page through, or narrow your query.","type":"integer"},"offset":{"description":"Output pager: 1-indexed line to start the returned window at (default 1).","type":"integer"}}},"name":"ls","description":"List directory contents using the system ls command (BSD ls (macOS)). Use structured fields: path plus safe short flags such as '-la', '-R', '-t'. Example: { path = '.', flags = { '-la' } }. Paths are confined to the working directory and configured read roots."},{"input_schema":{"required":["path"],"type":"object","properties":{"maxdepth":{"description":"Maximum directory depth.","type":"integer"},"type":{"description":"Entry type: f (file), d (directory), or l (symlink).","type":"string"},"offset":{"description":"Output pager: 1-indexed line to start the returned window at (default 1).","type":"integer"},"iname":{"description":"Case-insensitive basename pattern.","type":"string"},"path":{"description":"Directory path to search. Relative to the working directory or absolute.","type":"string"},"mindepth":{"description":"Minimum directory depth.","type":"integer"},"limit":{"description":"Output pager: max lines to return (default 200, max 2000). Re-call with a higher offset to page through, or narrow your query.","type":"integer"},"name":{"description":"Find entries whose basename matches this pattern, e.g. '*.lua'.","type":"string"}}},"name":"find","description":"Search for files and directories using the system find command (BSD find (macOS)). Use structured fields: path, name/iname, type, maxdepth, and mindepth. Example: { path = '.', name = '*.lua', type = 'f' }. Paths are confined to the working directory and configured read roots."},{"input_schema":{"required":["pattern"],"type":"object","properties":{"paths":{"type":"array","description":"File or directory paths to search. Overrides path when present.","items":{"type":"string"}},"path":{"description":"File or directory path to search. Defaults to '.'.","type":"string"},"context":{"description":"Context lines before and after each match.","type":"integer"},"limit":{"description":"Output pager: max lines to return (default 200, max 2000). Re-call with a higher offset to page through, or narrow your query.","type":"integer"},"context_after":{"description":"Context lines after each match.","type":"integer"},"context_before":{"description":"Context lines before each match.","type":"integer"},"ignore_case":{"description":"Case-insensitive search.","type":"boolean"},"glob":{"description":"File glob filter, e.g. '*.lua'. Supported natively by ripgrep.","type":"string"},"offset":{"description":"Output pager: 1-indexed line to start the returned window at (default 1).","type":"integer"},"flags":{"type":"array","description":"Safe read-only flags only: -n, --line-number, -w, --word-regexp, -F, --fixed-strings, --hidden, --no-ignore.","items":{"type":"string"}},"pattern":{"description":"Regex or fixed-string pattern to search for.","type":"string"},"type":{"description":"Ripgrep file type filter, e.g. 'lua'. Ignored by system grep fallback.","type":"string"}}},"name":"grep","description":"Search file contents using ripgrep (ripgrep 15.1.0). Use structured fields: pattern, path/paths, glob, type, ignore_case, context, and safe flags. Example: { pattern = 'foo', path = 'lua', glob = '*.lua' }. Paths are confined to the working directory and configured read roots."},{"input_schema":{"required":["pattern"],"type":"object","properties":{"after":{"description":"Lines of context after each match. Default: 2.","type":"integer"},"max_count":{"description":"Maximum matches per file. Optional.","type":"integer"},"limit":{"description":"Output pager: max lines to return (default 200, max 2000). Re-call with a higher offset to page through, or narrow your query.","type":"integer"},"glob":{"description":"File glob filter. Default: '*.md'.","type":"string"},"offset":{"description":"Output pager: 1-indexed line to start the returned window at (default 1).","type":"integer"},"case_insensitive":{"description":"Case-insensitive match. Default: true.","type":"boolean"},"pattern":{"description":"Regex pattern to search for. Required.","type":"string"},"before":{"description":"Lines of context before each match. Default: 1.","type":"integer"}}},"name":"chat_history_search","description":"Use this whenever the user refers to past chats — phrases like 'do you remember when we talked about X', 'what did we discuss about Y', 'have we chatted about Z before', 'find past chats on W'. Searches the user's saved chat transcripts (markdown files) across all configured chat roots: global, current repo, and any super-repo siblings. Output paths are prefixed with `{<repo>}/` so you can tell which repo each hit lives in. Default context is -B1 -A2 lines around each match. Backend: ripgrep (ripgrep 15.1.0)."}],"messages":[{"role":"user","content":"what is 2+2?"}]}
tests/fixtures/golden_payloads/single-user.json:1:{"model":"claude-sonnet-4-6","stream":true,"max_tokens":4096,"system":[{"text":"A conversation between You and Me. \n\nWe collaboratively seek knowledge, truth and learn together. \n\nWe are peers, we should be serious, transparent and critical in our discussion. \n\nYou MUST first think about how to response before responding. \n\nReason about how much information is appropriate. \n\nToo much information will overwhelm the user; too general information is useless. \n\nThe best way is to assess how much I know about the topic as the conversation proceeds. \n\nAssess my intention behind a question as they may not be fomulated perfectly. \n\nPay close attention to nuiances in my question; when they seem to be repetitive, that usually is a sign your answer did not hit the point.\n\nStrive to understand the question behind my questions. \n\nDo not repeat information if information is already provided in previous chat\n\nFinish the thinking process first before proceed to answer my question. \n\nThis thinking should contain a concise a plan of your answer, including key concepts, facts. \n\nThose key concepts and facts should be selected based on your perception of my knowledge, with the goal to engage in a deeper discussion.\n\nMake sure you respond in correct grammar, use Markdown to organize information hierarchy your reply. \n\nIMPORTANT: avoid top two levels of markdown heading: #, ## in answers, they are reserved for me to use. \n\nYou can use Markdown heading level 3 and beyond. \n\nYou should assess your confidence of answers, and leverage qualifiers that reflects your confidence level. \n\nYou should use Definitely or Certainly when you're highly confident; Probably or Likely when you're moderately confident; Maybe, Possibly, or Not Sure when uncertain. \n\nIf you're unsure or lacking information, don't guess and just say you don't know instead.\n\nSay you don't know when your confidence in answer is really low, below 30% of confidence\n\nIt is better for you to ask clarifying questions when you do not have confidence you understand my questions, the intention behind the questions.\n\nDon't elide any code from your output if the answer requires coding.\n\nWhen providing code, make sure it works.\n\nAfter you finish your answer, create a single plaintext line summary of my question, key points and facts of your answer.\n\nThis summary should the format of: you asked about [summary of question], I answered with [summary of answer], without any newline, no need to form proper sentence, prefixed with 📝:.\n\nLeave an empty line between the main answer, and summary line (📝:)\n\nWhen you write code, consider also generating test cases and commands for user to manually test.\n\nEnclose those in markdown code block ```\n\nWhen you did web_search, or web_fetch, generate reference your answer is based on.\n\nFormat your reference as links in markdown, around key phrases only, such as [issue x](link), or [more details](link)\n\nWhen you have tools available, use the minimum number of tool calls needed to answer. If one or two tool calls give you enough context, answer immediately — do not explore further. Prefer answering from the context you already have over making additional tool calls.\n\nIMPORTANT: always generate summary line prefixed with `📝:` at the end.","type":"text","cache_control":{"type":"ephemeral"}}],"tools":[{"max_uses":5,"type":"web_search_20260209","name":"web_search"},{"max_uses":5,"type":"web_fetch_20260209","name":"web_fetch"},{"input_schema":{"required":["file_path"],"type":"object","properties":{"offset":{"description":"Line number to start reading from (1-indexed). Default: 1.","type":"integer"},"limit":{"description":"Maximum number of lines to return. Default: no limit.","type":"integer"},"file_path":{"description":"Path to the file. Relative to the working directory or absolute.","type":"string"}}},"name":"read_file","description":"Read a file and return its contents with line numbers. Use offset to start from a specific line, limit to cap the number of lines returned (default: all lines)."},{"input_schema":{"required":["path"],"type":"object","properties":{"path":{"description":"Directory or file path to list. Relative to the working directory or absolute.","type":"string"},"flags":{"type":"array","description":"Safe ls display flags, e.g. { '-la' }, { '-R' }. Allowed compact characters: a A l h R t r S 1 d F. Long flags are not accepted.","items":{"type":"string"}},"limit":{"description":"Output pager: max lines to return (default 200, max 2000). Re-call with a higher offset to page through, or narrow your query.","type":"integer"},"offset":{"description":"Output pager: 1-indexed line to start the returned window at (default 1).","type":"integer"}}},"name":"ls","description":"List directory contents using the system ls command (BSD ls (macOS)). Use structured fields: path plus safe short flags such as '-la', '-R', '-t'. Example: { path = '.', flags = { '-la' } }. Paths are confined to the working directory and configured read roots."},{"input_schema":{"required":["path"],"type":"object","properties":{"maxdepth":{"description":"Maximum directory depth.","type":"integer"},"type":{"description":"Entry type: f (file), d (directory), or l (symlink).","type":"string"},"offset":{"description":"Output pager: 1-indexed line to start the returned window at (default 1).","type":"integer"},"iname":{"description":"Case-insensitive basename pattern.","type":"string"},"path":{"description":"Directory path to search. Relative to the working directory or absolute.","type":"string"},"mindepth":{"description":"Minimum directory depth.","type":"integer"},"limit":{"description":"Output pager: max lines to return (default 200, max 2000). Re-call with a higher offset to page through, or narrow your query.","type":"integer"},"name":{"description":"Find entries whose basename matches this pattern, e.g. '*.lua'.","type":"string"}}},"name":"find","description":"Search for files and directories using the system find command (BSD find (macOS)). Use structured fields: path, name/iname, type, maxdepth, and mindepth. Example: { path = '.', name = '*.lua', type = 'f' }. Paths are confined to the working directory and configured read roots."},{"input_schema":{"required":["pattern"],"type":"object","properties":{"paths":{"type":"array","description":"File or directory paths to search. Overrides path when present.","items":{"type":"string"}},"path":{"description":"File or directory path to search. Defaults to '.'.","type":"string"},"context":{"description":"Context lines before and after each match.","type":"integer"},"limit":{"description":"Output pager: max lines to return (default 200, max 2000). Re-call with a higher offset to page through, or narrow your query.","type":"integer"},"context_after":{"description":"Context lines after each match.","type":"integer"},"context_before":{"description":"Context lines before each match.","type":"integer"},"ignore_case":{"description":"Case-insensitive search.","type":"boolean"},"glob":{"description":"File glob filter, e.g. '*.lua'. Supported natively by ripgrep.","type":"string"},"offset":{"description":"Output pager: 1-indexed line to start the returned window at (default 1).","type":"integer"},"flags":{"type":"array","description":"Safe read-only flags only: -n, --line-number, -w, --word-regexp, -F, --fixed-strings, --hidden, --no-ignore.","items":{"type":"string"}},"pattern":{"description":"Regex or fixed-string pattern to search for.","type":"string"},"type":{"description":"Ripgrep file type filter, e.g. 'lua'. Ignored by system grep fallback.","type":"string"}}},"name":"grep","description":"Search file contents using ripgrep (ripgrep 15.1.0). Use structured fields: pattern, path/paths, glob, type, ignore_case, context, and safe flags. Example: { pattern = 'foo', path = 'lua', glob = '*.lua' }. Paths are confined to the working directory and configured read roots."},{"input_schema":{"required":["pattern"],"type":"object","properties":{"after":{"description":"Lines of context after each match. Default: 2.","type":"integer"},"max_count":{"description":"Maximum matches per file. Optional.","type":"integer"},"limit":{"description":"Output pager: max lines to return (default 200, max 2000). Re-call with a higher offset to page through, or narrow your query.","type":"integer"},"glob":{"description":"File glob filter. Default: '*.md'.","type":"string"},"offset":{"description":"Output pager: 1-indexed line to start the returned window at (default 1).","type":"integer"},"case_insensitive":{"description":"Case-insensitive match. Default: true.","type":"boolean"},"pattern":{"description":"Regex pattern to search for. Required.","type":"string"},"before":{"description":"Lines of context before each match. Default: 1.","type":"integer"}}},"name":"chat_history_search","description":"Use this whenever the user refers to past chats — phrases like 'do you remember when we talked about X', 'what did we discuss about Y', 'have we chatted about Z before', 'find past chats on W'. Searches the user's saved chat transcripts (markdown files) across all configured chat roots: global, current repo, and any super-repo siblings. Output paths are prefixed with `{<repo>}/` so you can tell which repo each hit lives in. Default context is -B1 -A2 lines around each match. Backend: ripgrep (ripgrep 15.1.0)."}],"messages":[{"role":"user","content":"hello"}]}
tests/fixtures/golden_payloads/dynamic-fence-stress.json:1:{"model":"claude-sonnet-4-6","stream":true,"max_tokens":4096,"system":[{"text":"A conversation between You and Me. \n\nWe collaboratively seek knowledge, truth and learn together. \n\nWe are peers, we should be serious, transparent and critical in our discussion. \n\nYou MUST first think about how to response before responding. \n\nReason about how much information is appropriate. \n\nToo much information will overwhelm the user; too general information is useless. \n\nThe best way is to assess how much I know about the topic as the conversation proceeds. \n\nAssess my intention behind a question as they may not be fomulated perfectly. \n\nPay close attention to nuiances in my question; when they seem to be repetitive, that usually is a sign your answer did not hit the point.\n\nStrive to understand the question behind my questions. \n\nDo not repeat information if information is already provided in previous chat\n\nFinish the thinking process first before proceed to answer my question. \n\nThis thinking should contain a concise a plan of your answer, including key concepts, facts. \n\nThose key concepts and facts should be selected based on your perception of my knowledge, with the goal to engage in a deeper discussion.\n\nMake sure you respond in correct grammar, use Markdown to organize information hierarchy your reply. \n\nIMPORTANT: avoid top two levels of markdown heading: #, ## in answers, they are reserved for me to use. \n\nYou can use Markdown heading level 3 and beyond. \n\nYou should assess your confidence of answers, and leverage qualifiers that reflects your confidence level. \n\nYou should use Definitely or Certainly when you're highly confident; Probably or Likely when you're moderately confident; Maybe, Possibly, or Not Sure when uncertain. \n\nIf you're unsure or lacking information, don't guess and just say you don't know instead.\n\nSay you don't know when your confidence in answer is really low, below 30% of confidence\n\nIt is better for you to ask clarifying questions when you do not have confidence you understand my questions, the intention behind the questions.\n\nDon't elide any code from your output if the answer requires coding.\n\nWhen providing code, make sure it works.\n\nAfter you finish your answer, create a single plaintext line summary of my question, key points and facts of your answer.\n\nThis summary should the format of: you asked about [summary of question], I answered with [summary of answer], without any newline, no need to form proper sentence, prefixed with 📝:.\n\nLeave an empty line between the main answer, and summary line (📝:)\n\nWhen you write code, consider also generating test cases and commands for user to manually test.\n\nEnclose those in markdown code block ```\n\nWhen you did web_search, or web_fetch, generate reference your answer is based on.\n\nFormat your reference as links in markdown, around key phrases only, such as [issue x](link), or [more details](link)\n\nWhen you have tools available, use the minimum number of tool calls needed to answer. If one or two tool calls give you enough context, answer immediately — do not explore further. Prefer answering from the context you already have over making additional tool calls.\n\nIMPORTANT: always generate summary line prefixed with `📝:` at the end.","type":"text","cache_control":{"type":"ephemeral"}}],"tools":[{"max_uses":5,"type":"web_search_20260209","name":"web_search"},{"max_uses":5,"type":"web_fetch_20260209","name":"web_fetch"},{"input_schema":{"required":["file_path"],"type":"object","properties":{"offset":{"description":"Line number to start reading from (1-indexed). Default: 1.","type":"integer"},"limit":{"description":"Maximum number of lines to return. Default: no limit.","type":"integer"},"file_path":{"description":"Path to the file. Relative to the working directory or absolute.","type":"string"}}},"name":"read_file","description":"Read a file and return its contents with line numbers. Use offset to start from a specific line, limit to cap the number of lines returned (default: all lines)."},{"input_schema":{"required":["path"],"type":"object","properties":{"path":{"description":"Directory or file path to list. Relative to the working directory or absolute.","type":"string"},"flags":{"type":"array","description":"Safe ls display flags, e.g. { '-la' }, { '-R' }. Allowed compact characters: a A l h R t r S 1 d F. Long flags are not accepted.","items":{"type":"string"}},"limit":{"description":"Output pager: max lines to return (default 200, max 2000). Re-call with a higher offset to page through, or narrow your query.","type":"integer"},"offset":{"description":"Output pager: 1-indexed line to start the returned window at (default 1).","type":"integer"}}},"name":"ls","description":"List directory contents using the system ls command (BSD ls (macOS)). Use structured fields: path plus safe short flags such as '-la', '-R', '-t'. Example: { path = '.', flags = { '-la' } }. Paths are confined to the working directory and configured read roots."},{"input_schema":{"required":["path"],"type":"object","properties":{"maxdepth":{"description":"Maximum directory depth.","type":"integer"},"type":{"description":"Entry type: f (file), d (directory), or l (symlink).","type":"string"},"offset":{"description":"Output pager: 1-indexed line to start the returned window at (default 1).","type":"integer"},"iname":{"description":"Case-insensitive basename pattern.","type":"string"},"path":{"description":"Directory path to search. Relative to the working directory or absolute.","type":"string"},"mindepth":{"description":"Minimum directory depth.","type":"integer"},"limit":{"description":"Output pager: max lines to return (default 200, max 2000). Re-call with a higher offset to page through, or narrow your query.","type":"integer"},"name":{"description":"Find entries whose basename matches this pattern, e.g. '*.lua'.","type":"string"}}},"name":"find","description":"Search for files and directories using the system find command (BSD find (macOS)). Use structured fields: path, name/iname, type, maxdepth, and mindepth. Example: { path = '.', name = '*.lua', type = 'f' }. Paths are confined to the working directory and configured read roots."},{"input_schema":{"required":["pattern"],"type":"object","properties":{"paths":{"type":"array","description":"File or directory paths to search. Overrides path when present.","items":{"type":"string"}},"path":{"description":"File or directory path to search. Defaults to '.'.","type":"string"},"context":{"description":"Context lines before and after each match.","type":"integer"},"limit":{"description":"Output pager: max lines to return (default 200, max 2000). Re-call with a higher offset to page through, or narrow your query.","type":"integer"},"context_after":{"description":"Context lines after each match.","type":"integer"},"context_before":{"description":"Context lines before each match.","type":"integer"},"ignore_case":{"description":"Case-insensitive search.","type":"boolean"},"glob":{"description":"File glob filter, e.g. '*.lua'. Supported natively by ripgrep.","type":"string"},"offset":{"description":"Output pager: 1-indexed line to start the returned window at (default 1).","type":"integer"},"flags":{"type":"array","description":"Safe read-only flags only: -n, --line-number, -w, --word-regexp, -F, --fixed-strings, --hidden, --no-ignore.","items":{"type":"string"}},"pattern":{"description":"Regex or fixed-string pattern to search for.","type":"string"},"type":{"description":"Ripgrep file type filter, e.g. 'lua'. Ignored by system grep fallback.","type":"string"}}},"name":"grep","description":"Search file contents using ripgrep (ripgrep 15.1.0). Use structured fields: pattern, path/paths, glob, type, ignore_case, context, and safe flags. Example: { pattern = 'foo', path = 'lua', glob = '*.lua' }. Paths are confined to the working directory and configured read roots."},{"input_schema":{"required":["pattern"],"type":"object","properties":{"after":{"description":"Lines of context after each match. Default: 2.","type":"integer"},"max_count":{"description":"Maximum matches per file. Optional.","type":"integer"},"limit":{"description":"Output pager: max lines to return (default 200, max 2000). Re-call with a higher offset to page through, or narrow your query.","type":"integer"},"glob":{"description":"File glob filter. Default: '*.md'.","type":"string"},"offset":{"description":"Output pager: 1-indexed line to start the returned window at (default 1).","type":"integer"},"case_insensitive":{"description":"Case-insensitive match. Default: true.","type":"boolean"},"pattern":{"description":"Regex pattern to search for. Required.","type":"string"},"before":{"description":"Lines of context before each match. Default: 1.","type":"integer"}}},"name":"chat_history_search","description":"Use this whenever the user refers to past chats — phrases like 'do you remember when we talked about X', 'what did we discuss about Y', 'have we chatted about Z before', 'find past chats on W'. Searches the user's saved chat transcripts (markdown files) across all configured chat roots: global, current repo, and any super-repo siblings. Output paths are prefixed with `{<repo>}/` so you can tell which repo each hit lives in. Default context is -B1 -A2 lines around each match. Backend: ripgrep (ripgrep 15.1.0)."}],"messages":[{"role":"user","content":"read example.md"},{"role":"assistant","content":[{"input":{"path":"example.md"},"type":"tool_use","id":"toolu_F","name":"read_file"}]},{"role":"user","content":[{"tool_use_id":"toolu_F","type":"tool_result","is_error":false,"content":"    1  ```lua\n    2  local x = 1\n    3  ```\n    4  ````bash\n    5  echo hi\n    6  ````"}]}]}
tests/fixtures/golden_payloads/one-round-tool-use.json:1:{"model":"claude-sonnet-4-6","stream":true,"max_tokens":4096,"system":[{"text":"A conversation between You and Me. \n\nWe collaboratively seek knowledge, truth and learn together. \n\nWe are peers, we should be serious, transparent and critical in our discussion. \n\nYou MUST first think about how to response before responding. \n\nReason about how much information is appropriate. \n\nToo much information will overwhelm the user; too general information is useless. \n\nThe best way is to assess how much I know about the topic as the conversation proceeds. \n\nAssess my intention behind a question as they may not be fomulated perfectly. \n\nPay close attention to nuiances in my question; when they seem to be repetitive, that usually is a sign your answer did not hit the point.\n\nStrive to understand the question behind my questions. \n\nDo not repeat information if information is already provided in previous chat\n\nFinish the thinking process first before proceed to answer my question. \n\nThis thinking should contain a concise a plan of your answer, including key concepts, facts. \n\nThose key concepts and facts should be selected based on your perception of my knowledge, with the goal to engage in a deeper discussion.\n\nMake sure you respond in correct grammar, use Markdown to organize information hierarchy your reply. \n\nIMPORTANT: avoid top two levels of markdown heading: #, ## in answers, they are reserved for me to use. \n\nYou can use Markdown heading level 3 and beyond. \n\nYou should assess your confidence of answers, and leverage qualifiers that reflects your confidence level. \n\nYou should use Definitely or Certainly when you're highly confident; Probably or Likely when you're moderately confident; Maybe, Possibly, or Not Sure when uncertain. \n\nIf you're unsure or lacking information, don't guess and just say you don't know instead.\n\nSay you don't know when your confidence in answer is really low, below 30% of confidence\n\nIt is better for you to ask clarifying questions when you do not have confidence you understand my questions, the intention behind the questions.\n\nDon't elide any code from your output if the answer requires coding.\n\nWhen providing code, make sure it works.\n\nAfter you finish your answer, create a single plaintext line summary of my question, key points and facts of your answer.\n\nThis summary should the format of: you asked about [summary of question], I answered with [summary of answer], without any newline, no need to form proper sentence, prefixed with 📝:.\n\nLeave an empty line between the main answer, and summary line (📝:)\n\nWhen you write code, consider also generating test cases and commands for user to manually test.\n\nEnclose those in markdown code block ```\n\nWhen you did web_search, or web_fetch, generate reference your answer is based on.\n\nFormat your reference as links in markdown, around key phrases only, such as [issue x](link), or [more details](link)\n\nWhen you have tools available, use the minimum number of tool calls needed to answer. If one or two tool calls give you enough context, answer immediately — do not explore further. Prefer answering from the context you already have over making additional tool calls.\n\nIMPORTANT: always generate summary line prefixed with `📝:` at the end.","type":"text","cache_control":{"type":"ephemeral"}}],"tools":[{"max_uses":5,"type":"web_search_20260209","name":"web_search"},{"max_uses":5,"type":"web_fetch_20260209","name":"web_fetch"},{"input_schema":{"required":["file_path"],"type":"object","properties":{"offset":{"description":"Line number to start reading from (1-indexed). Default: 1.","type":"integer"},"limit":{"description":"Maximum number of lines to return. Default: no limit.","type":"integer"},"file_path":{"description":"Path to the file. Relative to the working directory or absolute.","type":"string"}}},"name":"read_file","description":"Read a file and return its contents with line numbers. Use offset to start from a specific line, limit to cap the number of lines returned (default: all lines)."},{"input_schema":{"required":["path"],"type":"object","properties":{"path":{"description":"Directory or file path to list. Relative to the working directory or absolute.","type":"string"},"flags":{"type":"array","description":"Safe ls display flags, e.g. { '-la' }, { '-R' }. Allowed compact characters: a A l h R t r S 1 d F. Long flags are not accepted.","items":{"type":"string"}},"limit":{"description":"Output pager: max lines to return (default 200, max 2000). Re-call with a higher offset to page through, or narrow your query.","type":"integer"},"offset":{"description":"Output pager: 1-indexed line to start the returned window at (default 1).","type":"integer"}}},"name":"ls","description":"List directory contents using the system ls command (BSD ls (macOS)). Use structured fields: path plus safe short flags such as '-la', '-R', '-t'. Example: { path = '.', flags = { '-la' } }. Paths are confined to the working directory and configured read roots."},{"input_schema":{"required":["path"],"type":"object","properties":{"maxdepth":{"description":"Maximum directory depth.","type":"integer"},"type":{"description":"Entry type: f (file), d (directory), or l (symlink).","type":"string"},"offset":{"description":"Output pager: 1-indexed line to start the returned window at (default 1).","type":"integer"},"iname":{"description":"Case-insensitive basename pattern.","type":"string"},"path":{"description":"Directory path to search. Relative to the working directory or absolute.","type":"string"},"mindepth":{"description":"Minimum directory depth.","type":"integer"},"limit":{"description":"Output pager: max lines to return (default 200, max 2000). Re-call with a higher offset to page through, or narrow your query.","type":"integer"},"name":{"description":"Find entries whose basename matches this pattern, e.g. '*.lua'.","type":"string"}}},"name":"find","description":"Search for files and directories using the system find command (BSD find (macOS)). Use structured fields: path, name/iname, type, maxdepth, and mindepth. Example: { path = '.', name = '*.lua', type = 'f' }. Paths are confined to the working directory and configured read roots."},{"input_schema":{"required":["pattern"],"type":"object","properties":{"paths":{"type":"array","description":"File or directory paths to search. Overrides path when present.","items":{"type":"string"}},"path":{"description":"File or directory path to search. Defaults to '.'.","type":"string"},"context":{"description":"Context lines before and after each match.","type":"integer"},"limit":{"description":"Output pager: max lines to return (default 200, max 2000). Re-call with a higher offset to page through, or narrow your query.","type":"integer"},"context_after":{"description":"Context lines after each match.","type":"integer"},"context_before":{"description":"Context lines before each match.","type":"integer"},"ignore_case":{"description":"Case-insensitive search.","type":"boolean"},"glob":{"description":"File glob filter, e.g. '*.lua'. Supported natively by ripgrep.","type":"string"},"offset":{"description":"Output pager: 1-indexed line to start the returned window at (default 1).","type":"integer"},"flags":{"type":"array","description":"Safe read-only flags only: -n, --line-number, -w, --word-regexp, -F, --fixed-strings, --hidden, --no-ignore.","items":{"type":"string"}},"pattern":{"description":"Regex or fixed-string pattern to search for.","type":"string"},"type":{"description":"Ripgrep file type filter, e.g. 'lua'. Ignored by system grep fallback.","type":"string"}}},"name":"grep","description":"Search file contents using ripgrep (ripgrep 15.1.0). Use structured fields: pattern, path/paths, glob, type, ignore_case, context, and safe flags. Example: { pattern = 'foo', path = 'lua', glob = '*.lua' }. Paths are confined to the working directory and configured read roots."},{"input_schema":{"required":["pattern"],"type":"object","properties":{"after":{"description":"Lines of context after each match. Default: 2.","type":"integer"},"max_count":{"description":"Maximum matches per file. Optional.","type":"integer"},"limit":{"description":"Output pager: max lines to return (default 200, max 2000). Re-call with a higher offset to page through, or narrow your query.","type":"integer"},"glob":{"description":"File glob filter. Default: '*.md'.","type":"string"},"offset":{"description":"Output pager: 1-indexed line to start the returned window at (default 1).","type":"integer"},"case_insensitive":{"description":"Case-insensitive match. Default: true.","type":"boolean"},"pattern":{"description":"Regex pattern to search for. Required.","type":"string"},"before":{"description":"Lines of context before each match. Default: 1.","type":"integer"}}},"name":"chat_history_search","description":"Use this whenever the user refers to past chats — phrases like 'do you remember when we talked about X', 'what did we discuss about Y', 'have we chatted about Z before', 'find past chats on W'. Searches the user's saved chat transcripts (markdown files) across all configured chat roots: global, current repo, and any super-repo siblings. Output paths are prefixed with `{<repo>}/` so you can tell which repo each hit lives in. Default context is -B1 -A2 lines around each match. Backend: ripgrep (ripgrep 15.1.0)."}],"messages":[{"role":"user","content":"read foo.txt"},{"role":"assistant","content":[{"input":{"path":"foo.txt"},"type":"tool_use","id":"toolu_ABC","name":"read_file"}]},{"role":"user","content":[{"tool_use_id":"toolu_ABC","type":"tool_result","is_error":false,"content":"    1  hello world"}]}]}
atlas/index.md:66:- [Super-Repo Mode](modes/super_repo.md): Toggle peers (`<C-g>p`) to aggregate reads across sibling `.parley` repos; the explicit choice persists per repository.
lua/parley/config.lua:573:	-- super-repo mode toggle (aggregates reads across sibling .parley repos)
lua/parley/config.lua:574:	global_shortcut_super_repo_toggle = { modes = { "n", "i" }, shortcut = "<C-g>p" },
lua/parley/config.lua:660:		-- (○ global / ⊚ repo / ⦿ super-repo). Set to false to keep filetype.
lua/parley/markdown_finder.lua:4:-- top-level directory in ordinary mode and repository in super-repo mode.
lua/parley/markdown_finder.lua:121:	elseif opts.mode == "super_repo" then
lua/parley/markdown_finder.lua:147:--- Aggregate markdown entries across super-repo members.
lua/parley/markdown_finder.lua:178:	local super_state = _parley.super_repo and _parley.super_repo.get_state()
lua/parley/markdown_finder.lua:180:	local mode = super_state.active and "super_repo" or "ordinary"
lua/parley/markdown_finder.lua:184:	if mode == "super_repo" then
atlas/traceability.yaml:257:  modes/super_repo:
atlas/traceability.yaml:261:      - lua/parley/super_repo.lua
atlas/traceability.yaml:274:      - tests/unit/super_repo_spec.lua
atlas/traceability.yaml:453:      - lua/parley/super_repo.lua
atlas/traceability.yaml:457:      - tests/unit/super_repo_spec.lua
atlas/traceability.yaml:512:      - tests/unit/super_repo_spec.lua
lua/parley/issues.lua:327:-- result, so every reader (get_issues_dir, get_issues_repo_root, the super-repo
lua/parley/issues.lua:594:-- opts.history_dir_override: explicit history dir (super-repo per-member); else M.get_history_dir()
lua/parley/issues.lua:595:-- opts.repo_name: if set, every returned issue is tagged with .repo_name (super-repo display)
lua/parley/lualine.lua:48:--   ⦿-name  super-repo — super-repo toggle is on (read-aggregation across siblings)
lua/parley/lualine.lua:59:    if parley.is_super_repo_active and parley.is_super_repo_active() then
lua/parley/lualine.lua:64:  if parley.is_super_repo_active and parley.is_super_repo_active() then
lua/parley/lualine.lua:493:      -- Refresh lualine when super-repo toggles (mode glyph changes)
lua/parley/keybinding_registry.lua:194:		id = "super_repo_toggle",
lua/parley/keybinding_registry.lua:195:		config_key = "global_shortcut_super_repo_toggle",
lua/parley/keybinding_registry.lua:198:		desc = "Toggle super-repo mode (aggregate reads across sibling .parley repos)",
lua/parley/keybinding_registry.lua:199:		help_desc = "Toggle super-repo mode",
tests/integration/skill_invoke_spec.lua:261:    it("executes relative tool paths from a super-repo sibling chat neighborhood", function()
atlas/discovery/registry.md:77:(`{repo_root, super_repo_members}` — no real-cwd dependence):
atlas/discovery/registry.md:80:- **super-repo** → base ∪ union(local over members), deduped by name (base
atlas/discovery/registry.md:87:parley's existing root union (super_repo members, sourced from
atlas/discovery/registry.md:88:`super_repo.compute_members`) — no separate root-scope enum. `current()` reads
atlas/discovery/registry.md:89:the live `config.repo_root` + `config.super_repo_members`.
atlas/discovery/registry.md:110:`get_issues_repo_root`, the super-repo finder `issue_finder.lua:133`, the status
atlas/discovery/registry.md:128:- [Super-Repo Mode](../modes/super_repo.md) — sibling-repo member discovery.
lua/parley/discovery/base.lua:15:-- super-repo members. Absolute global globs (chat/note's chat_dir/notes_dir)
lua/parley/discovery/init.lua:6:--   super-repo  → base ∪ union(local over members), deduped (base wins ties)
lua/parley/discovery/init.lua:16:-- setup() builds and repo-mode detection / super_repo.lua mutate, NOT the
lua/parley/discovery/init.lua:18:-- repo_root / super_repo_members, so reading it returns global mode always).
lua/parley/discovery/init.lua:20:-- super_repo.setup / note_dirs.setup. super_repo.compute_members is the reused
lua/parley/discovery/init.lua:21:-- member-discovery source (populates config.super_repo_members).
lua/parley/discovery/init.lua:45:--- @param ctx table|nil { config?, repo_root?, super_repo_members? }
lua/parley/discovery/init.lua:47:---        overrides of chat_dir/notes_dir); repo_root/super_repo_members select
lua/parley/discovery/init.lua:53:    local members = ctx.super_repo_members
lua/parley/discovery/init.lua:57:    -- super_repo members already include the current repo (compute_members
lua/parley/discovery/init.lua:96:--- (repo_root + super_repo_members) populated by repo-mode detection and
lua/parley/discovery/init.lua:97:--- super_repo.compute_members — NOT the default config table.
lua/parley/discovery/init.lua:104:        super_repo_members = config.super_repo_members,
lua/parley/repo_mode.lua:4:    return mode == "repo" or mode == "super_repo"
lua/parley/repo_mode.lua:11:M.resolve = function(repo_modes, canonical_root)
lua/parley/repo_mode.lua:12:    if type(repo_modes) ~= "table" or not valid_root(canonical_root) then
lua/parley/repo_mode.lua:15:    local mode = repo_modes[canonical_root]
lua/parley/repo_mode.lua:22:M.updated = function(repo_modes, canonical_root, mode)
lua/parley/repo_mode.lua:24:    if type(repo_modes) == "table" then
lua/parley/repo_mode.lua:25:        for root, saved_mode in pairs(repo_modes) do
atlas/chat/memory.md:20:- The `chat_history_search` tool lets agents search across ALL configured chat roots (global + repo + super-repo siblings). Use this when the user asks "do you remember when we talked about X?". Output paths are prefixed with `{<repo>}/...` so the agent can identify which repo each hit belongs to. See [Tool Use](../providers/tool_use.md).
tests/integration/discovery_builder_spec.lua:6:--   super-repo  → base ∪ union(local over members), deduped (base wins ties)
tests/integration/discovery_builder_spec.lua:10:-- Mode context is INJECTED ({repo_root, super_repo_members}) so the tests do
tests/integration/discovery_builder_spec.lua:85:describe("discovery.build — super-repo mode", function()
tests/integration/discovery_builder_spec.lua:102:            super_repo_members = { { path = m1, name = "m1" }, { path = m2, name = "m2" } },
tests/integration/discovery_builder_spec.lua:113:            super_repo_members = { { path = m1, name = "m1" }, { path = m2, name = "m2" } },
tests/integration/discovery_builder_spec.lua:121:            super_repo_members = { { path = m1, name = "m1" }, { path = m2, name = "m2" } },
tests/integration/discovery_builder_spec.lua:131:    -- current() must read the LIVE config (repo_root/super_repo_members on the
tests/integration/discovery_builder_spec.lua:145:        local live = vim.tbl_extend("force", config, { repo_root = root, super_repo_members = nil })
atlas/modes/super_repo.md:10:- **Toggle peers**: `<C-g>p` (`global_shortcut_super_repo_toggle`).
atlas/modes/super_repo.md:16:  `super_repo` under the canonical current repo root in `state.json.repo_modes`.
atlas/modes/super_repo.md:23:preference. `.brain` has no special behavior: brain repositories follow the
atlas/modes/super_repo.md:35:| `⦿-<repo>`     | super-repo | super-repo toggle is on                     |
atlas/modes/super_repo.md:38:`⊚-brain` in plain repo mode and `⦿-brain` when super-repo is active.
atlas/modes/super_repo.md:53:super-repo simply pushes each member's chat/note dir into `chat_roots` /
atlas/modes/super_repo.md:57:Markdown Finder obtains the active member roots from `super_repo.get_state()`
atlas/modes/super_repo.md:59:list as the authority. In super-repo mode its tag bar is repo-only:
atlas/modes/super_repo.md:93:design (see `workshop/issues/000113-create-a-super-repo-mode.md`).
atlas/modes/super_repo.md:105:is derived on every read from `config.chat_dir + repo + super-repo`.
atlas/modes/super_repo.md:112:`super_repo.get_pushed_note_dirs()`, in addition to the `label = "repo"`
atlas/modes/super_repo.md:118:- `lua/parley/super_repo.lua` — runtime-only module: `compute_members`,
atlas/modes/super_repo.md:120:- `lua/parley/init.lua` — wires `parley.toggle_super_repo()` /
atlas/modes/super_repo.md:121:  `parley.is_super_repo_active()`, restores after setup refreshes, and owns the
atlas/modes/super_repo.md:126:  through `super_repo.expand_roots`.
atlas/modes/super_repo.md:128:  facets from the active `super_repo.get_state()` member roots.
atlas/modes/super_repo.md:134:- `lua/parley/keybinding_registry.lua` — `super_repo_toggle` entry.
lua/parley/chat_finder.lua:42:-- Skipped in super-repo mode: that mode's whole point is aggregating siblings,
lua/parley/chat_finder.lua:50:	local super_repo_root = config.super_repo_root
lua/parley/chat_finder.lua:51:	if type(super_repo_root) == "string" and super_repo_root ~= "" then
lua/parley/tools/builtin/chat_history_search.lua:2:-- across all configured chat roots (global + repo-local + super-repo
lua/parley/tools/builtin/chat_history_search.lua:6:-- outside cwd (global iCloud dir, sibling super-repo members), so
lua/parley/tools/builtin/chat_history_search.lua:35:        .. "roots: global, current repo, and any super-repo siblings. Output paths are "
lua/parley/skill_manifest.lua:11:--     scope       global | repo | super_repo
lua/parley/skill_manifest.lua:27:M.SCOPES = { global = true, repo = true, super_repo = true }
lua/parley/skill_manifest.lua:63:        return fail("manifest.scope must be one of global|repo|super_repo")
lua/parley/init.lua:66:local super_repo = require("parley.super_repo")
lua/parley/init.lua:68:super_repo.setup(M)
lua/parley/init.lua:69:M.super_repo = super_repo
lua/parley/init.lua:70:M.toggle_super_repo = function()
lua/parley/init.lua:71:	local transitioned, err = super_repo.toggle()
lua/parley/init.lua:79:		local mode = super_repo.is_active() and "super_repo" or "repo"
lua/parley/init.lua:80:		M._state.repo_modes = repo_mode.updated(M._state.repo_modes, canonical_root, mode)
lua/parley/init.lua:83:			M.logger.warning("super-repo: preference not saved")
lua/parley/init.lua:89:M.is_super_repo_active = function() return super_repo.is_active() end
lua/parley/init.lua:93:-- from live config (repo_root + super_repo_members) via the injected M ref.
lua/parley/init.lua:563:	-- get_issues_repo_root, the super-repo finder, the status autocmd, base.lua's
lua/parley/init.lua:763:		local saved_mode = repo_mode.resolve(M._state.repo_modes, canonical_root)
lua/parley/init.lua:764:		super_repo.set_active(saved_mode == "super_repo")
lua/parley/init.lua:809:			super_repo_toggle = function()
lua/parley/init.lua:810:				local before = M.is_super_repo_active()
lua/parley/init.lua:811:				M.toggle_super_repo()
lua/parley/init.lua:812:				local after = M.is_super_repo_active()
lua/parley/init.lua:814:					local members = M.config.super_repo_members or {}
lua/parley/init.lua:818:							"super-repo: ON, but no sibling .parley repos found under " ..
lua/parley/init.lua:819:								(M.config.super_repo_root or "?"),
lua/parley/init.lua:823:						vim.notify("super-repo: ON (" .. count .. " members)", vim.log.levels.INFO)
lua/parley/init.lua:826:					vim.notify("super-repo: OFF", vim.log.levels.INFO)
lua/parley/init.lua:1145:--- Runtime-derived chat roots and repo/super-repo note roots are excluded.
lua/parley/init.lua:1157:	for _, dir in ipairs(super_repo.get_pushed_note_dirs()) do
lua/parley/init.lua:1233:	-- mode + super-repo, never restored from state.json. Old state files
lua/parley/init.lua:1299:	-- not reload state or disturb a live super-repo overlay.
atlas/providers/tool_use.md:15:| `chat_history_search` | read | Search past chats across ALL chat roots (global + repo + super-repo siblings). Output is `{<repo>}/...`-prefixed. Default context `-B1 -A2`, `*.md` glob, case-insensitive. Params: `pattern`, `before`, `after`, `glob`, `case_insensitive`, `max_count` |
lua/parley/super_repo.lua:1:-- parley.super_repo — super-repo mode (read-aggregation overlay)
lua/parley/super_repo.lua:58:--- When super-repo is active and has members, returns a list of
lua/parley/super_repo.lua:115:		_parley.logger.warning("super-repo: cwd is not inside a .parley repo")
lua/parley/super_repo.lua:121:		_parley.logger.warning("super-repo: " .. (err or "discovery failed"))
lua/parley/super_repo.lua:132:	-- super_repo.get_pushed_*_dirs() to drop these from state.json), so we don't
lua/parley/super_repo.lua:167:	_parley.config.super_repo_root = discovered.workspace_root
lua/parley/super_repo.lua:168:	_parley.config.super_repo_members = vim.deepcopy(discovered.members)
lua/parley/super_repo.lua:209:	_parley.config.super_repo_root = nil
lua/parley/super_repo.lua:210:	_parley.config.super_repo_members = nil
lua/parley/vision_finder.lua:21:    -- Compute vision roots: in super-repo mode, one per member; else just the single repo.
lua/parley/vision_finder.lua:22:    local sr_vision = _parley.super_repo and _parley.super_repo.expand_roots(_parley.config.vision_dir) or nil
atlas/ui/lualine.md:6:- `lualine.replace_filetype`: when true (default), auto-replaces the user's filetype component with a parley mode glyph (`○` global / `⊚-<repo>` repo / `⦿-<repo>` super-repo). See [Super-Repo Mode](../modes/super_repo.md).
atlas/infra/repo_mode.md:28:           + (sibling repos' chat dirs if super-repo mode is active)
atlas/infra/repo_mode.md:31:`apply_repo_local()` materializes this list at setup; super-repo toggling pushes/pops sibling entries at runtime. There are no `:ParleyChatDirs` / `:ParleyChatDirAdd` / `:ParleyChatDirRemove` commands and no `<C-g>h` keybinding — they were removed in issue #117 because the original use case (drop a folder in for deliberation) is fully covered by repo + super-repo modes. State.json no longer carries `chat_dirs` / `chat_roots`; old state files with these fields are silently ignored on load.
atlas/infra/repo_mode.md:33:`state.json.repo_modes` separately stores each canonical repo root's explicit
atlas/infra/repo_mode.md:34:`repo` / `super_repo` choice. Missing or invalid entries mean ordinary repo
atlas/infra/repo_mode.md:36:repositories use exactly the same policy; `.brain` does not imply peer mode.
atlas/infra/repo_mode.md:49:Notes still use the multi-root manager with freeform add/remove/rename via `:ParleyNoteDirs` / `<C-n>h` and persist `note_roots` / `note_dirs` to state.json. The shared `root_dirs.lua` generic manager and `root_dir_picker.lua` UI exist primarily to serve the note system now; the chat side only uses the read paths (get/find/normalize/apply) and `super_repo.set_chat_roots`.
atlas/infra/repo_mode.md:76:- `refresh_state()` re-asserts the repo *note* dir as primary after restoring persisted state, then calls the shared atomic write-only persistence boundary. That boundary strips chat roots and note roots marked transient (plain repo's `label = "repo"` and super-repo's pushed sibling dirs) without reloading or disturbing live roots.
atlas/infra/repo_mode.md:82:- [Super-Repo Mode](../modes/super_repo.md) — read-aggregation overlay across sibling `.parley` repos.
tests/unit/neighborhood_spec.lua:45:    it("returns sibling repo root for super-repo chat roots", function()
atlas/ui/pickers.md:14:The chat finder additionally pre-seeds `{}` (the primary chat root, which in repo mode is the repo chat root) on the first open of a parley session in plain repo mode, so the default view is scoped to repo chats and global chats are filtered out. The pre-seed is a one-shot — once the user clears or modifies the filter, sticky-query takes over and the default is never re-applied. Skipped in super-repo mode (whose whole point is aggregating siblings, which a `{}` narrowing would defeat).
atlas/ui/pickers.md:46:eligible super-repo expansion shows alphabetically ordered repository facets
tests/unit/chat_dirs_spec.lua:4:-- mode + super-repo, never freeform-mutated and never persisted to
tests/unit/config_tools_spec.lua:340:        assert.equals("<C-g>p", parley.config.global_shortcut_super_repo_toggle.shortcut)
tests/unit/config_tools_spec.lua:341:        assert.same({ "n", "i" }, parley.config.global_shortcut_super_repo_toggle.modes)
tests/unit/markdown_finder_spec.lua:45:	it("uses only alphabetized repository facets in eligible super-repo mode", function()
tests/unit/markdown_finder_spec.lua:47:			mode = "super_repo",
tests/unit/markdown_finder_spec.lua:65:			mode = "super_repo",
tests/unit/markdown_finder_spec.lua:78:			mode = "super_repo",
tests/unit/markdown_finder_spec.lua:91:	it("renders invalid super-repo expansions unfiltered without a bar", function()
tests/unit/markdown_finder_spec.lua:102:				mode = "super_repo",
tests/unit/markdown_finder_spec.lua:121:			mode = "super_repo",
tests/unit/markdown_finder_spec.lua:134:			mode = "super_repo",
tests/unit/markdown_finder_spec.lua:219:				-- Deliberately stale: runtime super-repo state must win.
tests/unit/markdown_finder_spec.lua:220:				super_repo_members = { { path = "/stale", name = "stale" } },
tests/unit/markdown_finder_spec.lua:222:			super_repo = {
tests/unit/chat_finder_logic_spec.lua:993:        it("returns nil in super-repo mode (don't override aggregation intent)", function()
tests/unit/chat_finder_logic_spec.lua:996:                super_repo_root = "/some/workspace",
tests/unit/skill_manifest_spec.lua:63:    it("rejects a scope outside {global, repo, super_repo}", function()
tests/unit/skill_manifest_spec.lua:72:        for _, s in ipairs({ "global", "repo", "super_repo" }) do
tests/unit/skill_manifest_spec.lua:148:        assert.is_true(manifest.SCOPES.super_repo)
tests/unit/keybindings_spec.lua:265:            { id = "super_repo_toggle", key = "<C-g>p", modes = { "n", "i" } },
tests/unit/keybindings_spec.lua:278:        assert.is_true(has_line(parley._keybinding_help_lines("other"), "<C-g>p", "super-repo"))
tests/unit/repo_mode_spec.lua:6:            ["/workspace/a"] = "super_repo",
tests/unit/repo_mode_spec.lua:11:        assert.equals("super_repo", repo_mode.resolve(modes, "/workspace/a"))
tests/unit/repo_mode_spec.lua:30:            ["/workspace/b"] = "super_repo",
tests/unit/repo_mode_spec.lua:37:        local result = repo_mode.updated(input, "/workspace/a", "super_repo")
tests/unit/repo_mode_spec.lua:40:            ["/workspace/a"] = "super_repo",
tests/unit/repo_mode_spec.lua:41:            ["/workspace/b"] = "super_repo",
tests/unit/repo_mode_spec.lua:54:        assert.same({ ["/workspace/a"] = "repo" }, repo_mode.updated(input, "", "super_repo"))
tests/unit/issue_finder_spec.lua:271:    local function use_super_repos(repos)
tests/unit/issue_finder_spec.lua:278:        fake.super_repo = {
tests/unit/issue_finder_spec.lua:291:    it("shows sorted repository facets for completely labelled super-repo roots", function()
tests/unit/issue_finder_spec.lua:292:        use_super_repos({
tests/unit/issue_finder_spec.lua:313:        use_super_repos({
tests/unit/issue_finder_spec.lua:323:        use_super_repos({
tests/unit/issue_finder_spec.lua:335:        use_super_repos({
tests/unit/issue_finder_spec.lua:351:        use_super_repos({
tests/unit/issue_finder_spec.lua:384:        use_super_repos({
tests/unit/issue_finder_spec.lua:395:        use_super_repos({
tests/unit/issue_finder_spec.lua:406:        use_super_repos({
tests/unit/issue_finder_spec.lua:415:        use_super_repos({

codex
The shadow sweep found no stale keybinding or brain-auto-enable claims in the changed user-facing surfaces, and traceability selects all intended focused specs. The pure entities exist at the plan’s stated paths and remain deterministic; the integration boundaries are exercised through injected writers and real setup paths. I’m moving to fresh execution evidence now.
exec
/bin/zsh -lc 'make test-spec SPEC=modes/super_repo && make test-spec SPEC=ui/keybindings && nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/config_tools_spec.lua" -c "qa!" && make lint && git diff --check ac2706896b00ddb30e3ab229674c671f604c4a4f..HEAD' in /Users/xianxu/workspace/parley.nvim
 succeeded in 7295ms:
Moved chat tree to: /Users/xianxu/workspace/parley.nvim/.test-tmp/claude/parley-test-chatfinder-[archive]-2e98da/2026-02-04-10-00-00-escaped-root.md
Parley.nvim: Moved chat tree to: /Users/xianxu/workspace/parley.nvim/.test-tmp/claude/parley-test-chatfinder-tilde-360f5b/2026-02-04-10-00-00-tilde-root.md
[32mSuccess[0m	||	ChatFinder logic Group F: Chat finder picker mappings reopens on moved chats when the destination root was configured with a tilde path
[32mSuccess[0m	||	ChatFinder logic Group F: Chat finder picker mappings passes filename, tags, and topic as search text for matcher ranking
[32mSuccess[0m	||	ChatFinder logic Group F: Chat finder picker mappings keeps canonical facet behavior across toggles and rediscovery
[32mSuccess[0m	||	ChatFinder logic Group F: Chat finder picker mappings includes extra-root labels in finder search text
[32mSuccess[0m	||	ChatFinder logic Group F: Chat finder picker mappings includes empty braces in primary-root search text
[32mSuccess[0m	||	ChatFinder logic Group F: Chat finder picker mappings passes preserved tag filters back into the picker prompt
[32mSuccess[0m	||	ChatFinder logic Group F: Chat finder picker mappings preserves only bracket-tag and brace-label fragments from finder queries
[32mSuccess[0m	||	ChatFinder logic Group F: Chat finder picker mappings matches extra-root labels when the query uses brace syntax
[32mSuccess[0m	||	ChatFinder logic Group F: Chat finder picker mappings preserves empty brace filters for the primary root
[32mSuccess[0m	||	ChatFinder logic Group F: Chat finder picker mappings falls back to the newer visual neighbor when deleting the oldest item
[32mSuccess[0m	||	ChatFinder logic default_sticky_query_for_repo_mode returns {} in plain repo mode
[32mSuccess[0m	||	ChatFinder logic default_sticky_query_for_repo_mode returns nil when not in repo mode
[32mSuccess[0m	||	ChatFinder logic default_sticky_query_for_repo_mode returns nil in super-repo mode (don't override aggregation intent)

[32mSuccess: [0m	36
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
Moved chat tree to: /Users/xianxu/workspace/parley.nvim/.test-tmp/claude/parley-test-chatfinder-tilde-360f5b/2026-02-04-10-00-00-tilde-root.md
Running tests/unit/finder_facets_spec.lua
Scheduling: tests/unit/finder_facets_spec.lua

========================================
Testing:	/Users/xianxu/workspace/parley.nvim/tests/unit/finder_facets_spec.lua
[32mSuccess[0m	||	finder facets discover defaults to alphabetical non-empty keys before the untagged key
[32mSuccess[0m	||	finder facets discover preserves first appearance in source order while keeping the untagged key last
[32mSuccess[0m	||	finder facets discover returns an empty list when no facets are discovered
[32mSuccess[0m	||	finder facets eligible_labels returns nil when the label domain is inactive
[32mSuccess[0m	||	finder facets eligible_labels returns nil when any projected label is incomplete
[32mSuccess[0m	||	finder facets eligible_labels returns nil with fewer than two distinct labels
[32mSuccess[0m	||	finder facets eligible_labels returns sorted distinct labels without mutating entries
[32mSuccess[0m	||	finder facets merge_state enables new keys while retaining prior and temporarily absent choices
[32mSuccess[0m	||	finder facets merge_state starts with every discovered key enabled
[32mSuccess[0m	||	finder facets state transitions toggles only the requested key without mutating state
[32mSuccess[0m	||	finder facets state transitions sets every retained key without mutating state
[32mSuccess[0m	||	finder facets filter uses OR semantics and preserves entry order
[32mSuccess[0m	||	finder facets filter includes untagged entries through the empty-string facet
[32mSuccess[0m	||	finder facets filter returns no mapped entries when every facet is disabled
[32mSuccess[0m	||	finder facets filter does not mutate the input list
[32mSuccess[0m	||	finder facets project projects discovered keys in order
[32mSuccess[0m	||	finder facets project returns nil without discovered facets

[32mSuccess: [0m	17
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
Running tests/unit/float_picker_spec.lua
Scheduling: tests/unit/float_picker_spec.lua

========================================
Testing:	/Users/xianxu/workspace/parley.nvim/tests/unit/float_picker_spec.lua
[32mSuccess[0m	||	float_picker window creation opens a floating window
[32mSuccess[0m	||	float_picker window creation creates one line per item
[32mSuccess[0m	||	float_picker window creation renders logical item order from bottom to top
[32mSuccess[0m	||	float_picker window creation selects the first logical item on the bottom row by default
[32mSuccess[0m	||	float_picker window creation keeps the selected row on the bottom edge when the list exceeds window height
[32mSuccess[0m	||	float_picker window creation keeps short filtered lists pinned to the bottom of a taller window
[32mSuccess[0m	||	float_picker window creation does not open a window when items list is empty
[32mSuccess[0m	||	float_picker window creation opens an empty picker when facets can restore its items
[32mSuccess[0m	||	float_picker window creation truncates long items with an ellipsis
[32mSuccess[0m	||	float_picker window creation seeds the prompt and filtered results from initial_query
[32mSuccess[0m	||	float_picker window creation preserves a synchronized live query when items and facets update
[32mSuccess[0m	||	float_picker key mappings <CR> calls on_select with the current item and closes the window
[32mSuccess[0m	||	float_picker key mappings <Esc> calls on_cancel and closes the window
[32mSuccess[0m	||	float_picker key mappings q calls on_cancel and closes the window
[32mSuccess[0m	||	float_picker key mappings extra mappings are called with the current item
[32mSuccess[0m	||	float_picker key mappings does not let a <C-m> extra mapping override <CR> confirm
[32mSuccess[0m	||	float_picker key mappings extra mapping close_fn closes the window
[32mSuccess[0m	||	float_picker key mappings extra mapping close_fn does not trigger on_cancel
[32mSuccess[0m	||	float_picker key mappings control-key extra mappings are called from the prompt buffer
[32mSuccess[0m	||	float_picker key mappings maps short bottom-padded visual rows back to logical indices
[32mSuccess[0m	||	float_picker key mappings maps top-anchored visual rows back to logical indices
[32mSuccess[0m	||	float_picker anchor=top renders logical item order from top to bottom
[32mSuccess[0m	||	float_picker anchor=top selects the first logical item on the top row by default
[32mSuccess[0m	||	float_picker anchor=top keeps short lists pinned to the top of a taller window
[32mSuccess[0m	||	float_picker sizing and layout height equals number of items when fewer than screen allows
[32mSuccess[0m	||	float_picker sizing and layout opts.height overrides the item-count default
[32mSuccess[0m	||	float_picker sizing and layout opts.width overrides the content-driven default
[32mSuccess[0m	||	float_picker sizing and layout width is capped so the window stays within screen bounds
[32mSuccess[0m	||	float_picker sizing and layout height is capped so the window stays within screen bounds
[32mSuccess[0m	||	float_picker sizing and layout window is centered horizontally and vertically
[32mSuccess[0m	||	float_picker sizing and layout VimResized repositions the window without closing it
[32mSuccess[0m	||	float_picker _fuzzy_score returns 0 for empty query
[32mSuccess[0m	||	float_picker _fuzzy_score matches a simple subsequence (case-insensitive)
[32mSuccess[0m	||	float_picker _fuzzy_score returns nil when word is not a subsequence
[32mSuccess[0m	||	float_picker _fuzzy_score is case-insensitive
[32mSuccess[0m	||	float_picker _fuzzy_score requires ALL words to match (AND logic)
[32mSuccess[0m	||	float_picker _fuzzy_score word order in query does not matter
[32mSuccess[0m	||	float_picker _fuzzy_score prefix match scores higher than mid-string token match
[32mSuccess[0m	||	float_picker _fuzzy_score consecutive characters score higher than scattered
[32mSuccess[0m	||	float_picker _fuzzy_score accepts small typos in token prefixes
[32mSuccess[0m	||	float_picker _fuzzy_score requires approximate prefix matches to keep the first query character
[32mSuccess[0m	||	float_picker _fuzzy_score rejects tokens that are too far from any candidate prefix
[32mSuccess[0m	||	float_picker _fuzzy_score does not match by collapsing to a too-short prefix
[32mSuccess[0m	||	float_picker _fuzzy_score prefers token prefix matches over whole-string scattered matches
[32mSuccess[0m	||	float_picker _fuzzy_score does not match full plain words across word boundaries
[32mSuccess[0m	||	float_picker _fuzzy_score matches bracketed query tokens only against bracketed haystack tags
[32mSuccess[0m	||	float_picker _fuzzy_score matches braced query tokens only against braced haystack labels
[32mSuccess[0m	||	float_picker _fuzzy_score matches empty braced query tokens only against empty braced haystack labels
[32mSuccess[0m	||	float_picker _fuzzy_score matches in-progress { query (no closing brace) against braced haystack labels
[32mSuccess[0m	||	float_picker _fuzzy_score matches in-progress [ query (no closing bracket) against bracketed haystack tags
[32mSuccess[0m	||	float_picker _tokenize_query classifies completed brace tokens as root
[32mSuccess[0m	||	float_picker _tokenize_query classifies in-progress brace tokens as root
[32mSuccess[0m	||	float_picker _tokenize_query classifies in-progress bracket tokens as tag
[32mSuccess[0m	||	float_picker _tokenize_query ignores lone { or [ with no payload
[32mSuccess[0m	||	float_picker _fuzzy_match_details marks edit-distance positions separately for approximate prefix matches
[32mSuccess[0m	||	float_picker _fuzzy_match_details rejects approximate prefix details when the first query character differs
[32mSuccess[0m	||	float_picker _fuzzy_match_details keeps exact prefix matches on the exact highlight path only
[32mSuccess[0m	||	float_picker recall records confirmed item.value under recall_key
[32mSuccess[0m	||	float_picker recall restores cursor to recalled value on reopen
[32mSuccess[0m	||	float_picker recall falls back when recalled value is no longer in items
[32mSuccess[0m	||	float_picker recall explicit initial_index wins over recall
[32mSuccess[0m	||	float_picker recall recall_id_fn extracts identity from a non-value field
[32mSuccess[0m	||	float_picker recall Esc / cancel does not update recall

[32mSuccess: [0m	63
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
Running tests/unit/helper_io_spec.lua
Scheduling: tests/unit/helper_io_spec.lua

========================================
Testing:	/Users/xianxu/workspace/parley.nvim/tests/unit/helper_io_spec.lua
[32mSuccess[0m	||	helper I/O functions Group A: read_file_content A1: returns file contents as a string
[32mSuccess[0m	||	helper I/O functions Group A: read_file_content A2: returns nil for non-existent file
[32mSuccess[0m	||	helper I/O functions Group A: read_file_content A3: returns empty string for empty file
[32mSuccess[0m	||	helper I/O functions Group A: read_file_content A4: handles file with single line (no trailing newline)
[32mSuccess[0m	||	helper I/O functions Group B: format_file_content B1: returns formatted output with 'File:' header
[32mSuccess[0m	||	helper I/O functions Group B: format_file_content B2: includes line numbers
[32mSuccess[0m	||	helper I/O functions Group B: format_file_content B3: wraps content in code fences
[32mSuccess[0m	||	helper I/O functions Group B: format_file_content B4: returns error message for non-readable file
[32mSuccess[0m	||	helper I/O functions Group C: is_directory C1: returns true for existing directory
[32mSuccess[0m	||	helper I/O functions Group C: is_directory C2: returns false for existing file
[32mSuccess[0m	||	helper I/O functions Group C: is_directory C3: returns false for non-existent path
[32mSuccess[0m	||	helper I/O functions Group D: find_files D1: finds files matching *.lua in flat directory
[32mSuccess[0m	||	helper I/O functions Group D: find_files D2: recursive=true finds files in subdirectories
[32mSuccess[0m	||	helper I/O functions Group D: find_files D3: returns empty table for non-existent directory
[32mSuccess[0m	||	helper I/O functions Group D: find_files D4: excludes directories from results
[32mSuccess[0m	||	helper I/O functions Group E: find_git_root E1: finds .git in directory containing it
[32mSuccess[0m	||	helper I/O functions Group E: find_git_root E2: walks up parent directories to find .git
[32mSuccess[0m	||	helper I/O functions Group E: find_git_root E3: returns empty string when no .git found
[32mSuccess[0m	||	helper I/O functions Group F: table_to_file + file_to_table F1: round-trip preserves table structure
[32mSuccess[0m	||	helper I/O functions Group F: table_to_file + file_to_table F2: file_to_table returns nil for non-existent file
[32mSuccess[0m	||	helper I/O functions Group F: table_to_file + file_to_table F3: file_to_table returns nil for empty file
[32mSuccess[0m	||	helper I/O functions Group F: table_to_file + file_to_table F4: table_to_file with nested table serializes correctly
[32mSuccess[0m	||	helper I/O functions Group F: table_to_file + file_to_table F5: table_to_file_atomic replaces complete JSON and reports success
[32mSuccess[0m	||	helper I/O functions Group F: table_to_file + file_to_table F6: encode failure is bounded and leaves destination unchanged
[32mSuccess[0m	||	helper I/O functions Group F: table_to_file + file_to_table F7: write failure cleans the temporary file and preserves destination
[32mSuccess[0m	||	helper I/O functions Group F: table_to_file + file_to_table F7: close failure cleans the temporary file and preserves destination
[32mSuccess[0m	||	helper I/O functions Group F: table_to_file + file_to_table F8: rename failure removes partial output and preserves destination bytes
[32mSuccess[0m	||	helper I/O functions Group G: prepare_dir G1: creates directory if it does not exist
[32mSuccess[0m	||	helper I/O functions Group G: prepare_dir G2: returns resolved path
[32mSuccess[0m	||	helper I/O functions Group G: prepare_dir G3: strips trailing slash
[32mSuccess[0m	||	helper I/O functions Group G: prepare_dir G4: existing directory is not recreated
[32mSuccess[0m	||	helper I/O functions Group G: prepare_dir G5: expands tilde paths before creating directories

[32mSuccess: [0m	32
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
Parley.nvim: File not found: /Users/xianxu/workspace/parley.nvim/.test-tmp/claude/parley-test-helper-io-b2e7fe/nonexistent.txt
Parley.nvim: File not found: /Users/xianxu/workspace/parley.nvim/.test-tmp/claude/parley-test-helper-io-bc5964/missing.txt
Parley.nvim: Directory not found: /Users/xianxu/workspace/parley.nvim/.test-tmp/claude/parley-test-helper-io-b494fc/nonexistent
Parley.nvim: Failed to open file for reading: /Users/xianxu/workspace/parley.nvim/.test-tmp/claude/parley-test-helper-io-add343/missing.json
Error: /Users/xianxu/workspace/parley.nvim/.test-tmp/claude/parley-test-helper-io-add343/missing.json: No such file or directory
Parley.nvim: Failed to read any content from file: /Users/xianxu/workspace/parley.nvim/.test-tmp/claude/parley-test-helper-io-933c7e/empty.json
Running tests/unit/issue_finder_spec.lua
Scheduling: tests/unit/issue_finder_spec.lua

========================================
Testing:	/Users/xianxu/workspace/parley.nvim/tests/unit/issue_finder_spec.lua
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
[32mSuccess[0m	||	IssueFinder query persistence shows sorted repository facets for completely labelled super-repo roots
[32mSuccess[0m	||	IssueFinder query persistence omits repository facets outside a complete multi-repo expansion
[32mSuccess[0m	||	IssueFinder query persistence derives facets from roots even when one repo has no issues in the current view
[32mSuccess[0m	||	IssueFinder query persistence filters in place while preserving query and state across views and reopens
[32mSuccess[0m	||	IssueFinder query persistence defaults new repos on and restores choices for temporarily absent repos
[32mSuccess[0m	||	IssueFinder query persistence reopens after NONE with ALL available to restore every row

[32mSuccess: [0m	19
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
Running tests/unit/markdown_finder_spec.lua
Scheduling: tests/unit/markdown_finder_spec.lua

========================================
Testing:	/Users/xianxu/workspace/parley.nvim/tests/unit/markdown_finder_spec.lua
[32mSuccess[0m	||	markdown finder picker policy uses only source-ordered directory facets in ordinary mode
[32mSuccess[0m	||	markdown finder picker policy uses only alphabetized repository facets in eligible super-repo mode
[32mSuccess[0m	||	markdown finder picker policy keeps an eligible member with no rows in the repository facets
[32mSuccess[0m	||	markdown finder picker policy retains the repository bar for an eligible zero-row input
[32mSuccess[0m	||	markdown finder picker policy renders invalid super-repo expansions unfiltered without a bar
[32mSuccess[0m	||	markdown finder picker policy renders repository identity mismatches unfiltered without a bar
[32mSuccess[0m	||	markdown finder picker policy enables new repository facets and retains absent choices
[32mSuccess[0m	||	markdown finder picker policy does not mutate inputs and returns fresh tables
[32mSuccess[0m	||	markdown finder entry point opens an ordinary directory bar and repaints without changing the live query
[32mSuccess[0m	||	markdown finder entry point preserves picker identity and restores the source window before opening a selection
[32mSuccess[0m	||	markdown finder entry point reopens with verbatim whitespace and a subsequently cleared query
[32mSuccess[0m	||	markdown finder entry point keeps directory and repository choices independent across runtime mode changes
[32mSuccess[0m	||	markdown finder entry point reopens after NONE with the directory bar available for ALL restore
[32mSuccess[0m	||	markdown finder entry point scans invalidly labelled members and opens the aggregate without a bar
[32mSuccess[0m	||	markdown finder entry point opens an eligible zero-row super expansion with a sorted repository bar

[32mSuccess: [0m	15
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
Running tests/unit/repo_mode_spec.lua
Scheduling: tests/unit/repo_mode_spec.lua

========================================
Testing:	/Users/xianxu/workspace/parley.nvim/tests/unit/repo_mode_spec.lua
[32mSuccess[0m	||	repo_mode.resolve selects only exact modes for a canonical repository root
[32mSuccess[0m	||	repo_mode.resolve treats malformed maps and roots as unsaved
[32mSuccess[0m	||	repo_mode.updated returns a fresh sanitized map with only the current root replaced
[32mSuccess[0m	||	repo_mode.updated starts empty when the input map is malformed
[32mSuccess[0m	||	repo_mode.updated rejects invalid roots and modes without mutating the input

[32mSuccess: [0m	5
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
Running tests/unit/super_repo_spec.lua
Scheduling: tests/unit/super_repo_spec.lua

========================================
Testing:	/Users/xianxu/workspace/parley.nvim/tests/unit/super_repo_spec.lua
[32mSuccess[0m	||	super_repo.compute_members discovers sibling .parley repos sorted by name
[32mSuccess[0m	||	super_repo.compute_members returns the current repo as one of the members (writes still go there)
[32mSuccess[0m	||	super_repo.compute_members returns empty members list when no siblings have .parley
[32mSuccess[0m	||	super_repo.compute_members returns nil + err for empty input
[32mSuccess[0m	||	super_repo.compute_members returns nil + err for non-string input
[32mSuccess[0m	||	super_repo.toggle activates and adds sibling chat & note roots
[32mSuccess[0m	||	super_repo.toggle labels pushed roots with the sibling repo name (so finder shows {ariadne} etc.)
[32mSuccess[0m	||	super_repo.toggle exposes pushed dirs via get_pushed_*_dirs for the persistence gate
[32mSuccess[0m	||	super_repo.toggle sets super_repo_root and super_repo_members on config
[32mSuccess[0m	||	super_repo.toggle toggle off restores prior chat & note roots
[32mSuccess[0m	||	super_repo.toggle does not modify write paths (chat_dir / notes_dir / repo_root unchanged)
[32mSuccess[0m	||	super_repo.toggle fails to activate when repo_root is unset
[32mSuccess[0m	||	super_repo.toggle set_active is idempotent and does not persist preferences
[32mSuccess[0m	||	super_repo.toggle explicit toggles persist canonical per-repo choices in both directions
[32mSuccess[0m	||	super_repo.toggle stores an explicit toggle under the canonical root
[32mSuccess[0m	||	super_repo.toggle failed activation changes neither runtime mode nor saved preference
[32mSuccess[0m	||	super_repo.toggle keeps a successful runtime toggle when its preference cannot be saved
[32mSuccess[0m	||	super_repo.toggle markdown_finder._scan_members aggregates with {repo} prefix and repo_name tag
[32mSuccess[0m	||	super_repo.toggle scan_issues honours repo_name and history_dir_override (multi-root)
[32mSuccess[0m	||	super_repo.toggle expand_roots returns per-member abs paths when super-repo is active, nil otherwise
[32mSuccess[0m	||	super_repo.toggle super-repo siblings are stripped from persisted state.json
[32mSuccess[0m	||	super_repo.toggle persist_state writes a transient-safe snapshot without changing live overlay roots
[32mSuccess[0m	||	super_repo.toggle persist_state reports writer failure after passing a sanitized snapshot
[32mSuccess[0m	||	super_repo.toggle lualine.format_mode returns glyph plus repo label for repo-backed modes
[32mSuccess[0m	||	super_repo.toggle lualine.format_branch_label shortens long SDLC branch names for display
[32mSuccess[0m	||	super_repo.toggle lualine.create_branch_component preserves lualine branch detection and shortens display text
[32mSuccess[0m	||	super_repo.toggle lualine.format_directory hides cwd labels in repo mode but keeps interview visible
[32mSuccess[0m	||	super_repo.toggle lualine.create_filename_component hides filename only in repo mode
Parley.nvim: super-repo: cwd is not inside a .parley repo
[32mSuccess[0m	||	super_repo.toggle lualine.setup hides configured filename components in repo mode
[32mSuccess[0m	||	super_repo.toggle fires User ParleySuperRepoChanged on toggle on and off
[32mSuccess[0m	||	super_repo startup restoration restores saved super-repo mode once after the default-agent refresh
[32mSuccess[0m	||	super_repo startup restoration leaves unsaved brain repositories in ordinary mode after VimEnter
[32mSuccess[0m	||	super_repo startup restoration ignores invalid preferences and honors an explicit repo preference
[32mSuccess[0m	||	super_repo startup restoration uses canonical roots and isolates another repository's saved choice
[32mSuccess[0m	||	super_repo startup restoration keeps a saved super-repo preference when startup activation fails

[32mSuccess: [0m	35
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
Parley.nvim: super-repo: cwd is not inside a .parley repo
Parley.nvim: Directory not found: /Users/xianxu/workspace/parley.nvim/.test-tmp/nvim.xianxu/DMU7mM/36-parley-super-repo-startup/workspace/current/workshop/notes
Running tests/unit/config_tools_spec.lua
Scheduling: tests/unit/config_tools_spec.lua

========================================
Testing:	/Users/xianxu/workspace/parley.nvim/tests/unit/config_tools_spec.lua
[32mSuccess[0m	||	per-agent tools config accepts an agent with a valid tools list
[32mSuccess[0m	||	per-agent tools config raises on unknown tool name, mentioning the offending name
[32mSuccess[0m	||	per-agent tools config backward compatible: agent without tools field works unchanged
[32mSuccess[0m	||	per-agent tools config single-sources the max_tool_iterations default in parley.defaults (= 42)
[32mSuccess[0m	||	per-agent tools config defaults max_tool_iterations to 42 when tools set but override absent
[32mSuccess[0m	||	per-agent tools config defaults tool_result_max_bytes to 102400 when tools set but override absent
[32mSuccess[0m	||	per-agent tools config respects explicit max_tool_iterations override
[32mSuccess[0m	||	per-agent tools config respects explicit tool_result_max_bytes override
[32mSuccess[0m	||	default ToolSonnet ships in the default config with the @all tool set
[32mSuccess[0m	||	default ToolSonnet has default loop limits applied
[32mSuccess[0m	||	default ToolSonnet every tool-enabled default agent pins to EXPECTED_DEFAULT_TOOLS
[32mSuccess[0m	||	get_agent forwards client-side tool config (full wiring chain) get_agent(ToolSonnet) carries the tools field from M.agents
[32mSuccess[0m	||	get_agent forwards client-side tool config (full wiring chain) get_agent(ToolSonnet) forwards max_tool_iterations and tool_result_max_bytes
[32mSuccess[0m	||	get_agent forwards client-side tool config (full wiring chain) get_agent on a vanilla agent has nil tools (no defaults leak)
[32mSuccess[0m	||	get_agent forwards client-side tool config (full wiring chain) get_agent_info(headers, get_agent('ToolSonnet')).tools carries the @all sentinel
[32mSuccess[0m	||	get_agent forwards client-side tool config (full wiring chain) full wiring chain: ToolSonnet request payload resolves @all to the full read+write tool set
[32mSuccess[0m	||	get_agent forwards client-side tool config (full wiring chain) full wiring chain + web_search: @all client tools APPEND to web_search/web_fetch
[32mSuccess[0m	||	get_agent forwards synthetic_system_prompt config forwards both fields when present on the agent record
[32mSuccess[0m	||	get_agent forwards synthetic_system_prompt config forwards as nil when the agent has no synthetic config
[32mSuccess[0m	||	get_agent forwards synthetic_system_prompt config flag survives the full wiring chain into agent_info
[32mSuccess[0m	||	new config prefix + shortcut defaults defines chat_tool_use_prefix and chat_tool_result_prefix
[32mSuccess[0m	||	new config prefix + shortcut defaults uses peer/branch defaults and leaves tool folds unbound

[32mSuccess: [0m	22
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
Running tests/unit/keybindings_spec.lua
Scheduling: tests/unit/keybindings_spec.lua

========================================
Testing:	/Users/xianxu/workspace/parley.nvim/tests/unit/keybindings_spec.lua
[32mSuccess[0m	||	key bindings help other context shows global keys only
[32mSuccess[0m	||	key bindings help chat context shows global + repo + buffer + chat keys
[32mSuccess[0m	||	key bindings help chat_finder context shows only finder keys
[32mSuccess[0m	||	key bindings help note_finder context shows only finder keys
[32mSuccess[0m	||	key bindings help issue_finder context shows only finder keys
[32mSuccess[0m	||	key bindings help markdown context shows global + repo + buffer + markdown keys
[32mSuccess[0m	||	key bindings help issue context shows global + repo + buffer + markdown + issue keys
[32mSuccess[0m	||	key bindings help note context shows global + repo + buffer + markdown + note keys
[32mSuccess[0m	||	key bindings help title reflects context
[32mSuccess[0m	||	key bindings help uses configured shortcut for key bindings help
[32mSuccess[0m	||	key bindings help global section includes copy shortcuts
[32mSuccess[0m	||	key bindings help repo scope includes issue and vision finders
[32mSuccess[0m	||	key bindings help chat context uses branch mnemonic and omits unconfigured tool folds
[32mSuccess[0m	||	key bindings help shows a configured tool-fold shortcut through the shared registry
[32mSuccess[0m	||	key bindings help treats an empty configured shortcut as unbound
[32mSuccess[0m	||	key bindings help markdown context includes review shortcuts
[32mSuccess[0m	||	key bindings help issue context includes vision shortcuts via repo ancestry
[32mSuccess[0m	||	key bindings help review finder shows in global scope
[32mSuccess[0m	||	keybinding registry every entry has required fields
[32mSuccess[0m	||	keybinding registry all entry ids are unique
[32mSuccess[0m	||	keybinding registry all scopes are valid
[32mSuccess[0m	||	keybinding registry ancestor scopes for issue includes repo
[32mSuccess[0m	||	keybinding registry derives migrated bindings from exposed config without registry literals
[32mSuccess[0m	||	keybinding registry registers tool folds only when a non-empty shortcut is configured

[32mSuccess: [0m	24
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
Scheduling: tests/unit/config_tools_spec.lua

========================================
Testing:	/Users/xianxu/workspace/parley.nvim/tests/unit/config_tools_spec.lua
[32mSuccess[0m	||	per-agent tools config accepts an agent with a valid tools list
[32mSuccess[0m	||	per-agent tools config raises on unknown tool name, mentioning the offending name
[32mSuccess[0m	||	per-agent tools config backward compatible: agent without tools field works unchanged
[32mSuccess[0m	||	per-agent tools config single-sources the max_tool_iterations default in parley.defaults (= 42)
[32mSuccess[0m	||	per-agent tools config defaults max_tool_iterations to 42 when tools set but override absent
[32mSuccess[0m	||	per-agent tools config defaults tool_result_max_bytes to 102400 when tools set but override absent
[32mSuccess[0m	||	per-agent tools config respects explicit max_tool_iterations override
[32mSuccess[0m	||	per-agent tools config respects explicit tool_result_max_bytes override
[32mSuccess[0m	||	default ToolSonnet ships in the default config with the @all tool set
[32mSuccess[0m	||	default ToolSonnet has default loop limits applied
[32mSuccess[0m	||	default ToolSonnet every tool-enabled default agent pins to EXPECTED_DEFAULT_TOOLS
[32mSuccess[0m	||	get_agent forwards client-side tool config (full wiring chain) get_agent(ToolSonnet) carries the tools field from M.agents
[32mSuccess[0m	||	get_agent forwards client-side tool config (full wiring chain) get_agent(ToolSonnet) forwards max_tool_iterations and tool_result_max_bytes
[32mSuccess[0m	||	get_agent forwards client-side tool config (full wiring chain) get_agent on a vanilla agent has nil tools (no defaults leak)
[32mSuccess[0m	||	get_agent forwards client-side tool config (full wiring chain) get_agent_info(headers, get_agent('ToolSonnet')).tools carries the @all sentinel
[32mSuccess[0m	||	get_agent forwards client-side tool config (full wiring chain) full wiring chain: ToolSonnet request payload resolves @all to the full read+write tool set
[32mSuccess[0m	||	get_agent forwards client-side tool config (full wiring chain) full wiring chain + web_search: @all client tools APPEND to web_search/web_fetch
[32mSuccess[0m	||	get_agent forwards synthetic_system_prompt config forwards both fields when present on the agent record
[32mSuccess[0m	||	get_agent forwards synthetic_system_prompt config forwards as nil when the agent has no synthetic config
[32mSuccess[0m	||	get_agent forwards synthetic_system_prompt config flag survives the full wiring chain into agent_info
[32mSuccess[0m	||	new config prefix + shortcut defaults defines chat_tool_use_prefix and chat_tool_result_prefix
[32mSuccess[0m	||	new config prefix + shortcut defaults uses peer/branch defaults and leaves tool folds unbound

[32mSuccess: [0m	22
[31mFailed : [0m	0
[31mErrors : [0m	0
========================================
Checking lua/parley/agent_info.lua                OK
Checking lua/parley/agent_picker.lua              OK
Checking lua/parley/artifact_ref.lua              OK
Checking lua/parley/buffer_edit.lua               OK
Checking lua/parley/buffer_lifecycle.lua          OK
Checking lua/parley/chat_dirs.lua                 OK
Checking lua/parley/chat_finder.lua               OK
Checking lua/parley/chat_history.lua              OK
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
Checking lua/parley/facet_bar_layout.lua          OK
Checking lua/parley/file_tracker.lua              OK
Checking lua/parley/finder_facets.lua             OK
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
Checking lua/parley/repo_mode.lua                 OK
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
Checking tests/unit/chat_history_spec.lua         OK
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
Checking tests/unit/facet_bar_layout_spec.lua     OK
Checking tests/unit/file_tracker_spec.lua         OK
Checking tests/unit/finder_facets_spec.lua        OK
Checking tests/unit/finder_sticky_spec.lua        OK
Checking tests/unit/float_picker_spec.lua         OK
Checking tests/unit/float_picker_tag_bar_spec.lua OK
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
Checking tests/unit/markdown_finder_spec.lua      OK
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
Checking tests/unit/repo_mode_spec.lua            OK
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

Total: 0 warnings / 0 errors in 275 files

codex
Fresh mapped tests, the config regression, lint (275 files, zero warnings/errors), and windowed diff checks all pass. I have not found a contract violation so far; I’m running the full suite once at reduced parallelism to confirm there is no cross-surface regression before assigning the verdict.
exec
/bin/zsh -lc 'make test JOBS=1' in /Users/xianxu/workspace/parley.nvim
 succeeded in 80333ms:
Checking lua/parley/agent_info.lua                OK
Checking lua/parley/agent_picker.lua              OK
Checking lua/parley/artifact_ref.lua              OK
Checking lua/parley/buffer_edit.lua               OK
Checking lua/parley/buffer_lifecycle.lua          OK
Checking lua/parley/chat_dirs.lua                 OK
Checking lua/parley/chat_finder.lua               OK
Checking lua/parley/chat_history.lua              OK
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
Checking lua/parley/facet_bar_layout.lua          OK
Checking lua/parley/file_tracker.lua              OK
Checking lua/parley/finder_facets.lua             OK
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
Checking lua/parley/repo_mode.lua                 OK
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
Checking tests/unit/chat_history_spec.lua         OK
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
Checking tests/unit/facet_bar_layout_spec.lua     OK
Checking tests/unit/file_tracker_spec.lua         OK
Checking tests/unit/finder_facets_spec.lua        OK
Checking tests/unit/finder_sticky_spec.lua        OK
Checking tests/unit/float_picker_spec.lua         OK
Checking tests/unit/float_picker_tag_bar_spec.lua OK
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
Checking tests/unit/markdown_finder_spec.lua      OK
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
Checking tests/unit/repo_mode_spec.lua            OK
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

Total: 0 warnings / 0 errors in 275 files
PASS: tests/unit/ancestor_messages_spec.lua
PASS: tests/unit/anthropic_tool_decode_spec.lua
PASS: tests/unit/anthropic_tool_encode_spec.lua
PASS: tests/unit/arch_helper_spec.lua
PASS: tests/unit/artifact_ref_spec.lua
PASS: tests/unit/buffer_edit_spec.lua
PASS: tests/unit/buffer_lifecycle_spec.lua
PASS: tests/unit/build_messages_spec.lua
PASS: tests/unit/chat_dirs_spec.lua
PASS: tests/unit/chat_finder_logic_spec.lua
PASS: tests/unit/chat_history_spec.lua
PASS: tests/unit/chat_parser_section_lines_spec.lua
PASS: tests/unit/chat_parser_tools_spec.lua
PASS: tests/unit/chat_presentation_spec.lua
PASS: tests/unit/chat_respond_footnote_spec.lua
PASS: tests/unit/chat_slug_resolve_spec.lua
PASS: tests/unit/chat_slug_spec.lua
PASS: tests/unit/cliproxy_config_spec.lua
PASS: tests/unit/config_tools_spec.lua
PASS: tests/unit/custom_prompts_spec.lua
PASS: tests/unit/define_spec.lua
PASS: tests/unit/diagnostic_refresh_spec.lua
PASS: tests/unit/discovery_base_spec.lua
PASS: tests/unit/discovery_descriptor_spec.lua
PASS: tests/unit/discovery_matcher_spec.lua
PASS: tests/unit/discovery_merge_spec.lua
PASS: tests/unit/discovery_registry_spec.lua
PASS: tests/unit/dispatcher_query_spec.lua
PASS: tests/unit/dispatcher_spec.lua
PASS: tests/unit/drill_in_spec.lua
PASS: tests/unit/exchange_clipboard_spec.lua
PASS: tests/unit/exchange_model_spec.lua
PASS: tests/unit/exporter_tree_spec.lua
PASS: tests/unit/facet_bar_layout_spec.lua
PASS: tests/unit/file_tracker_spec.lua
PASS: tests/unit/finder_facets_spec.lua
PASS: tests/unit/finder_sticky_spec.lua
PASS: tests/unit/float_picker_spec.lua
PASS: tests/unit/float_picker_tag_bar_spec.lua
PASS: tests/unit/get_week_number_spec.lua
PASS: tests/unit/helper_io_spec.lua
PASS: tests/unit/helper_spec.lua
PASS: tests/unit/highlight_structure_spec.lua
PASS: tests/unit/highlighter_spec.lua
PASS: tests/unit/inline_branch_spec.lua
PASS: tests/unit/issue_finder_spec.lua
PASS: tests/unit/issue_vocabulary_spec.lua
PASS: tests/unit/issues_spec.lua
PASS: tests/unit/keybindings_spec.lua
PASS: tests/unit/line_reader_spec.lua
PASS: tests/unit/log_emit_spec.lua
PASS: tests/unit/logger_spec.lua
PASS: tests/unit/markdown_draft_block_spec.lua
PASS: tests/unit/markdown_finder_spec.lua
PASS: tests/unit/memory_prefs_spec.lua
PASS: tests/unit/neighborhood_spec.lua
PASS: tests/unit/note_finder_logic_spec.lua
PASS: tests/unit/oauth_spec.lua
PASS: tests/unit/obfuscate_spec.lua
PASS: tests/unit/open_chat_reference_spec.lua
PASS: tests/unit/outline_spec.lua
PASS: tests/unit/parley_harness_golden_spec.lua
PASS: tests/unit/parley_harness_spec.lua
PASS: tests/unit/parse_at_reference_spec.lua
PASS: tests/unit/parse_chat_spec.lua
PASS: tests/unit/perf_harness_spec.lua
PASS: tests/unit/picker_items_spec.lua
PASS: tests/unit/process_directory_pattern_spec.lua
PASS: tests/unit/progress_spec.lua
PASS: tests/unit/provider_params_spec.lua
PASS: tests/unit/providers_pre_query_spec.lua
PASS: tests/unit/pure_functions_spec.lua
PASS: tests/unit/raw_log_spec.lua
PASS: tests/unit/remote_references_spec.lua
PASS: tests/unit/render_buffer_roundtrip_spec.lua
PASS: tests/unit/render_buffer_spec.lua
PASS: tests/unit/render_spec.lua
PASS: tests/unit/repo_mode_spec.lua
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
PASS: tests/unit/super_repo_spec.lua
PASS: tests/unit/system_prompt_msgs_spec.lua
PASS: tests/unit/tasker_unit_spec.lua
PASS: tests/unit/timezone_diagnostics_spec.lua
PASS: tests/unit/tool_folds_spec.lua
PASS: tests/unit/tool_loop_spec.lua
PASS: tests/unit/tools_builtin_ack_spec.lua
PASS: tests/unit/tools_builtin_chat_history_search_spec.lua
PASS: tests/unit/tools_builtin_find_spec.lua
PASS: tests/unit/tools_builtin_grep_spec.lua
PASS: tests/unit/tools_builtin_ls_spec.lua
PASS: tests/unit/tools_builtin_propose_edits_spec.lua
PASS: tests/unit/tools_builtin_read_file_spec.lua
PASS: tests/unit/tools_builtin_registered_spec.lua
PASS: tests/unit/tools_dispatcher_spec.lua
PASS: tests/unit/tools_registry_spec.lua
PASS: tests/unit/tools_serialize_spec.lua
PASS: tests/unit/tools_types_spec.lua
PASS: tests/unit/vault_spec.lua
PASS: tests/unit/vision_spec.lua
PASS: tests/arch/buffer_mutation_spec.lua
PASS: tests/arch/performance_line_reader_spec.lua
PASS: tests/integration/chat_lease_spec.lua
PASS: tests/integration/chat_move_spec.lua
PASS: tests/integration/chat_pending_spec.lua
PASS: tests/integration/chat_progress_process_spec.lua
PASS: tests/integration/chat_respond_spec.lua
PASS: tests/integration/cliproxy_auth_login_spec.lua
PASS: tests/integration/cliproxy_caller_teardown_spec.lua
PASS: tests/integration/cliproxy_command_spec.lua
PASS: tests/integration/cliproxy_dispatch_spec.lua
PASS: tests/integration/cliproxy_download_spec.lua
PASS: tests/integration/cliproxy_lifecycle_spec.lua
PASS: tests/integration/create_handler_spec.lua
PASS: tests/integration/define_spec.lua
PASS: tests/integration/diagnostic_refresh_spec.lua
PASS: tests/integration/discovery_builder_spec.lua
PASS: tests/integration/discovery_local_types_spec.lua
PASS: tests/integration/export_spec.lua
PASS: tests/integration/highlighting_spec.lua
PASS: tests/integration/neighborhood_completion_spec.lua
PASS: tests/integration/new_chat_spec.lua
PASS: tests/integration/not_chat_spec.lua
PASS: tests/integration/perf_chat_typing_spec.lua
PASS: tests/integration/progress_spec.lua
PASS: tests/integration/review_diag_display_spec.lua
PASS: tests/integration/review_journal_io_spec.lua
PASS: tests/integration/review_menu_spec.lua
PASS: tests/integration/review_mode_load_spec.lua
PASS: tests/integration/review_projection_spec.lua
PASS: tests/integration/skill_invoke_review_spec.lua
PASS: tests/integration/skill_invoke_spec.lua
PASS: tests/integration/skill_providers_spec.lua
PASS: tests/integration/skill_registry_spec.lua
PASS: tests/integration/spell_chat_spec.lua
PASS: tests/integration/tasker_run_spec.lua
PASS: tests/integration/timer_race_spec.lua
PASS: tests/integration/topic_gen_spec.lua
PASS: tests/integration/tree_export_spec.lua
PASS: tests/integration/voice_apply_spec.lua

codex
The full suite passes at `JOBS=1`, including all unit, architecture, and integration specs. One cheap architecture issue remains: canonical repository-root normalization—the identity boundary for persisted preferences—is repeated in three new call sites despite an existing helper in the same module. I’m classifying that as Important under `ARCH-DRY`; everything else, including `ARCH-PURE` and `ARCH-PURPOSE`, passes.
Review complete: fresh focused/full verification is green; one Important ARCH-DRY consolidation finding remains.
  ✓ Read issue, durable plan, architecture principles, and review-window metadata
  ✓ Inspect changed code and surrounding consumers against Spec/Plan
  ✓ Run focused tests, full-suite/static evidence as practical, and stale-surface searches
  ✓ Classify findings and produce the machine-readable boundary verdict
codex
```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The implementation fulfills issue #190 and passes fresh focused, lint, diff, and full-suite verification. Startup restoration, failure preservation, brain parity, atomic persistence, transient-root filtering, and keybinding migration are well covered. One cheap `ARCH-DRY` consolidation should be completed before shipping.

### 1. Strengths

- [`repo_mode.lua`](/Users/xianxu/workspace/parley.nvim/lua/parley/repo_mode.lua:1) provides a genuinely pure, immutable preference policy with malformed-input coverage.
- [`helper.lua`](/Users/xianxu/workspace/parley.nvim/lua/parley/helper.lua:444) performs result-bearing atomic replacement; tests cover encode/write/close/rename failures and destination preservation.
- [`super_repo_spec.lua`](/Users/xianxu/workspace/parley.nvim/tests/unit/super_repo_spec.lua:704) exercises real setup sequencing, canonical/symlink roots, brain parity, failed restoration, and live overlay preservation.
- Keybinding registration and help derive from exposed config through the shared resolver; README and atlas document all new user-facing behavior.

### 2. Critical findings

None.

### 3. Important findings

- **`ARCH-DRY` — canonical path normalization has parallel implementations.** [`init.lua:78`](/Users/xianxu/workspace/parley.nvim/lua/parley/init.lua:78), [`init.lua:762`](/Users/xianxu/workspace/parley.nvim/lua/parley/init.lua:762), and [`init.lua:1153`](/Users/xianxu/workspace/parley.nvim/lua/parley/init.lua:1153) repeat normalization already represented by `resolve_dir_key` at [`init.lua:228`](/Users/xianxu/workspace/parley.nvim/lua/parley/init.lua:228). This normalization defines persisted repository identity, so future changes could make toggle writes and startup lookup disagree. Hoist one helper above `M.toggle_super_repo` and reuse it for preference keys and transient-root filtering.

### 4. Minor findings

None.

### 5. Test coverage notes

Fresh verification passed:

- `make test-spec SPEC=modes/super_repo`
- `make test-spec SPEC=ui/keybindings`
- `config_tools_spec.lua`
- `make lint`: 0 warnings/errors across 275 files
- `git diff --check Base..HEAD`
- `make test JOBS=1`: all unit, architecture, and integration specs passed

### 6. Architectural notes for upcoming work

- `ARCH-DRY`: flag as above.
- `ARCH-PURE`: pass. Deterministic policy is isolated from Neovim and filesystem operations; integration boundaries use injected adapters or real production setup tests.
- `ARCH-PURPOSE`: pass. The shadow sweep confirms startup, explicit toggles, brain behavior, registration, help, README, and atlas all consume or accurately describe the new policy.

### 7. Plan revision recommendations

None. The Core concepts table and completed Plan still match the implementation.
tokens used
125,475
```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The implementation fulfills issue #190 and passes fresh focused, lint, diff, and full-suite verification. Startup restoration, failure preservation, brain parity, atomic persistence, transient-root filtering, and keybinding migration are well covered. One cheap `ARCH-DRY` consolidation should be completed before shipping.

### 1. Strengths

- [`repo_mode.lua`](/Users/xianxu/workspace/parley.nvim/lua/parley/repo_mode.lua:1) provides a genuinely pure, immutable preference policy with malformed-input coverage.
- [`helper.lua`](/Users/xianxu/workspace/parley.nvim/lua/parley/helper.lua:444) performs result-bearing atomic replacement; tests cover encode/write/close/rename failures and destination preservation.
- [`super_repo_spec.lua`](/Users/xianxu/workspace/parley.nvim/tests/unit/super_repo_spec.lua:704) exercises real setup sequencing, canonical/symlink roots, brain parity, failed restoration, and live overlay preservation.
- Keybinding registration and help derive from exposed config through the shared resolver; README and atlas document all new user-facing behavior.

### 2. Critical findings

None.

### 3. Important findings

- **`ARCH-DRY` — canonical path normalization has parallel implementations.** [`init.lua:78`](/Users/xianxu/workspace/parley.nvim/lua/parley/init.lua:78), [`init.lua:762`](/Users/xianxu/workspace/parley.nvim/lua/parley/init.lua:762), and [`init.lua:1153`](/Users/xianxu/workspace/parley.nvim/lua/parley/init.lua:1153) repeat normalization already represented by `resolve_dir_key` at [`init.lua:228`](/Users/xianxu/workspace/parley.nvim/lua/parley/init.lua:228). This normalization defines persisted repository identity, so future changes could make toggle writes and startup lookup disagree. Hoist one helper above `M.toggle_super_repo` and reuse it for preference keys and transient-root filtering.

### 4. Minor findings

None.

### 5. Test coverage notes

Fresh verification passed:

- `make test-spec SPEC=modes/super_repo`
- `make test-spec SPEC=ui/keybindings`
- `config_tools_spec.lua`
- `make lint`: 0 warnings/errors across 275 files
- `git diff --check Base..HEAD`
- `make test JOBS=1`: all unit, architecture, and integration specs passed

### 6. Architectural notes for upcoming work

- `ARCH-DRY`: flag as above.
- `ARCH-PURE`: pass. Deterministic policy is isolated from Neovim and filesystem operations; integration boundaries use injected adapters or real production setup tests.
- `ARCH-PURPOSE`: pass. The shadow sweep confirms startup, explicit toggles, brain behavior, registration, help, README, and atlas all consume or accurately describe the new policy.

### 7. Plan revision recommendations

None. The Core concepts table and completed Plan still match the implementation.
