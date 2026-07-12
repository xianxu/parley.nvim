# Boundary Review — Issue #181

| field | value |
|---|---|
| issue | 181 — repo-root read-wide completion for all markdown |
| boundary | whole-issue close |
| window | `7719c33ff31ae977796b1032c4bb64f1693b3fc1..0f0b025f` |
| reviewer | codex |
| timestamp | 2026-07-11 |
| final verdict | `FIX-THEN-SHIP` |

## Review history

The close gate ran several fresh-context passes. Each blocking finding was fixed
and committed before the next pass:

1. Preserve global-chat narrowing and canonicalize policy roots.
2. Make the first existing read candidate authoritative; do not fall through
   after containment rejection.
3. Reject dangling read candidates deterministically.
4. Filter completion through canonical read enforcement and complete
   traceability.
5. Add ordinary nested-Markdown chat and skill regressions that distinguish
   repo-root read widening from the legacy artifact-root behavior.

## Final review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The reviewer found no Critical implementation defect. It confirmed that one
root policy drives read resolution, write confinement, completion, skill/chat
dispatch, and model guidance; completion reuses `resolve_read_path`; attachment
is idempotent; ordinary non-repo Markdown is unchanged; and atlas/traceability
coverage is present.

The sole Important finding was an evidence gap: chat and skill integration
tests used repo-backed chat artifacts whose legacy neighborhood was already the
repo root. The follow-up commit replaced those cases with ordinary
`data/nested/doc.md` buffers, proving repo-root-only reads at both seams. The
chat regression additionally proves the identical relative write lands in the
nested write neighborhood and leaves the repo-root candidate unchanged. The
reviewer's stale dispatcher-annotation note was also resolved.

Verification after the follow-up: mapped `providers/tool_use` and
`skills/skill-system` suites passed; `make -f Makefile.parley test JOBS=1`
passed with lint clean across 244 files and all unit, integration, and
architecture specs green; `git diff --check` passed.

## Architecture

- `ARCH-DRY`: pass — all consumers derive from `RootPolicy` and completion
  acceptance reuses the dispatcher resolver.
- `ARCH-PURE`: pass — deterministic policy/merge/formatting helpers are kept
  separate from filesystem and Neovim adapters.
- `ARCH-PURPOSE`: pass after follow-up — ordinary nested-Markdown regressions
  now demonstrate the issue's actual read-wide/write-narrow purpose.

---

## Re-review — 2026-07-11T21:28:28-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 181 — repo-root read-wide completion for all markdown |
| repo | 000181-repo-root-read-wide-completion-for-all-markdown |
| issue file | workshop/issues/000181-repo-root-read-wide-completion-for-all-markdown.md |
| boundary | whole-issue close |
| milestone | — |
| window | 7719c33ff31ae977796b1032c4bb64f1693b3fc1..HEAD |
| command | sdlc close --issue 181 |
| reviewer | codex |
| timestamp | 2026-07-11T21:28:28-07:00 |
| verdict | SHIP |

## Review

Reading additional input from stdin...
OpenAI Codex v0.144.1
--------
workdir: /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown
model: gpt-5.6-sol
provider: openai
approval: never
sandbox: workspace-write [workdir, /tmp, $TMPDIR]
reasoning effort: none
reasoning summaries: none
session id: 019f5493-39a1-7bc1-929f-edaccf8d5630
--------
user
# Code review — the one SDLC boundary review

You are conducting a fresh-context code review at a development boundary —
whole-issue close — in the **000181-repo-root-read-wide-completion-for-all-markdown** repository.

- repository: 000181-repo-root-read-wide-completion-for-all-markdown   (root: /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown)
- issue:      000181-repo-root-read-wide-completion-for-all-markdown#181   (file: workshop/issues/000181-repo-root-read-wide-completion-for-all-markdown.md)
- window:     Base: 7719c33ff31ae977796b1032c4bb64f1693b3fc1   Head: HEAD

Review the **000181-repo-root-read-wide-completion-for-all-markdown** repo and its tracker — the ariadne base-layer repo itself (changes here propagate to dependent repos). Do not assume any
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
diff --git a/atlas/infra/repo_mode.md b/atlas/infra/repo_mode.md
index 5145034..ccd0445 100644
--- a/atlas/infra/repo_mode.md
+++ b/atlas/infra/repo_mode.md
@@ -33,14 +33,12 @@ chat_roots = [config.chat_dir]
 ### Reference neighborhood (#147)
 Relative tool paths and chat-buffer file completion use a per-artifact
 neighborhood root, not the editor process cwd. `lua/parley/neighborhood.lua`
-derives the root from the artifact path: repo-backed Parley artifacts under the
-repo-local chat/note/issue/vision/history dirs resolve to `config.repo_root`;
-global chats and ordinary content files resolve to their own folder. `prep_chat`
-attaches a buffer-local `completefunc` for chat buffers, and when `nvim-cmp` is
-available it also installs a buffer-local `cmp-path` source whose `get_cwd()`
-returns the same neighborhood. Root-relative file candidates therefore come from
-the same neighborhood that tool calls use, including setups where markdown
-completion is driven by `cmp-path` instead of Vim's built-in completion.
+derives a root policy from the artifact path: writes use the artifact
+neighborhood, while reads search neighborhood first, then `config.repo_root` in
+repo mode, then configured read roots. The first existing match wins. Repo-mode
+`prep_md` attaches built-in and nvim-cmp completion backed by the same ordered
+candidate merger; global chats retain own-folder completion, and ordinary
+non-repo Markdown is unchanged. (#181)

 ### Note roots
 Notes still use the multi-root manager with freeform add/remove/rename via `:ParleyNoteDirs` / `<C-n>h` and persist `note_roots` / `note_dirs` to state.json. The shared `root_dirs.lua` generic manager and `root_dir_picker.lua` UI exist primarily to serve the note system now; the chat side only uses the read paths (get/find/normalize/apply) and `super_repo.set_chat_roots`.
@@ -68,7 +66,8 @@ All directory names are relative to git root unless they start with `/`.
 - `repo_chat_dir` and `repo_note_dir` are excluded from the generic `_dir$` prepare loop in setup
 - `repo_artifacts.dir_keys` is the shared source for repo-local artifact dirs that repo setup creates and `neighborhood` classifies as repo-backed
 - `apply_repo_local()` builds `config.chat_roots = [{dir=repo_chat, label="repo"}, {dir=config.chat_dir, label="global"}, ...]` directly, bypassing the basename-derived label heuristic in `default_root_label`
-- Parley chat buffers with `nvim-cmp` replace the buffer's cmp sources with `cmp-path` and `buffer` so path completion is anchored to the artifact neighborhood
+- Repo-mode Markdown and Parley chat buffers use the policy-backed `parley_path`
+  nvim-cmp source plus `buffer`; attachment is buffer-idempotent
 - `refresh_state()` re-asserts the repo *note* dir as primary after restoring persisted state (chat side does not need this — chat state is never persisted), and strips note_roots entries marked transient (plain repo's `label = "repo"` and super-repo's pushed sibling dirs) from `state.json`
 - `detect_buffer_context` checks all note roots (not just primary) for scope detection
 - `neighborhood.derive_for_path()` canonicalizes `/var`/`/private/var` style path aliases before testing repo-local artifact directories
diff --git a/atlas/providers/tool_use.md b/atlas/providers/tool_use.md
index e085490..f3ae791 100644
--- a/atlas/providers/tool_use.md
+++ b/atlas/providers/tool_use.md
@@ -60,7 +60,15 @@ Tool blocks in the transcript:

 ## Safety

-- **cwd-scope**: dispatcher (`resolve_path_in_cwd`) checks `path`, `file_path`, and every element of `paths` against the working directory, symlink-resolved (`fs_realpath`), so a symlink whose real path escapes is rejected. Chat tool calls and `skill_invoke` derive that working directory from `parley.neighborhood`: repo-backed Parley artifacts use the repo root; global chats/content artifacts use their own folder. Tool-enabled chat payloads also tell the agent `Relative tool paths resolve from: <root>`, so model guidance and dispatcher enforcement share the same root (#147). Read tools (`kind ~= "write"`, so an absent `kind` counts as read — same predicate as `@readonly`) may additionally reach any root in the global `tool_read_roots` config — entries are absolute (`/x`), home (`~/workspace`, `~` expanded), or relative-to-cwd (`../`); write tools (`edit_file`/`write_file`) stay cwd-confined regardless (#140). Default `tool_read_roots = {'../'}` → cwd plus its parent directory, so repo-mode peer/sibling repos are reachable by read tools; set it to `{}` for cwd-only. A rejection names the knob. `chat_history_search` deliberately accepts no path fields, so it can search chat roots that live outside cwd (global iCloud dir, super-repo siblings).
+- **root-policy scope**: chat and `skill_invoke` pass one neighborhood policy to
+  the dispatcher and model guidance. Read tools search its canonical roots in
+  order (artifact neighborhood, repo root in repo mode, configured
+  `tool_read_roots`) and require the first existing match; this applies to
+  `path`, `file_path`, `paths`, and injected `default_path`. Absolute paths and
+  symlinks must remain within a read root. Write tools ignore the wider set and
+  retain `resolve_path_in_cwd` confinement plus missing-leaf creation semantics.
+  Tools without path fields, such as `chat_history_search`, are unaffected.
+  (#147, #181)
 - **Tool argv safety** (#144, #149): `ls`, `grep`, `find`, `chat_history_search`, and optional `ack` no longer accept raw shell fragments. Each exposes structured fields and builds argv lists for the named binary, so shell metacharacters (`;`, `|`, `$()`, backticks, `>`) are data, not syntax. The shared pure helper (`lua/parley/tools/builtin/argv.lua`) validates local positive allowlists and numeric process flags: `ls` allows compact display flags only; `grep` allows a small read-only flag set and rejects `rg` execution/arbitrary-read flags such as `--pre`, `--hostname-bin`, and `-f`; `find` has no free `flags` field and only exposes path/name/type/depth predicates; `ack` exposes pattern/path/type/context fields with no raw `command` or `flags` escape hatch; `chat_history_search` keeps its explicit chat-root cwd bypass but validates `before`/`after`/`max_count` as non-negative integers before invoking `rg` or `grep` through argv-list execution. `grep`, `ack`, and `chat_history_search` insert `--` before pattern/path positionals so dash-leading patterns cannot be parsed as options; omitted-path defaults for cwd-confined tools are declared as `default_path = "."` so the dispatcher canonicalizes them through the cwd/read-root guard before execution.
 - **Output pager** (#139): a horizontal substrate cap — *every tool's output is a paged stream.* The registry (`register`) injects `offset`/`limit` params into every non-write, non-`self_paginates` tool's schema, and the dispatcher windows each result to lines `[offset, offset+limit)` (offset 1-indexed; `limit` defaults to `tool_result_page_lines` = 200, clamped ≤ 2000), stripping the params so the handler never sees them. When the window is partial it appends a footer naming the **true total** + the next page: `[lines 1-200 of 1,240,118 — pass offset=201 for the next page, or narrow your query]`. `read_file` sets `self_paginates = true` — its native `offset`/`limit` (line-window of the file) *is* the contract, so the dispatcher neither injects nor slices it (a no-limit read falls back to the byte-cap). Deep paging on shell tools re-runs the tool (run+slice, no cache — v1). The 100KB byte-cap (`truncate`) stays as the backstop for pathological single lines. Orthogonal to input safety (#144) — slices *after* the handler.
 - **Iteration cap**: `max_tool_iterations` (default 42, single-sourced in `defaults.lua` `#154`) — writes synthetic `📎: (iteration limit reached — max N rounds)` when hit
diff --git a/atlas/traceability.yaml b/atlas/traceability.yaml
index 7e79a42..7554658 100644
--- a/atlas/traceability.yaml
+++ b/atlas/traceability.yaml
@@ -352,6 +352,7 @@ atlas:
       - tests/integration/neighborhood_completion_spec.lua
       - tests/unit/tool_loop_spec.lua
       - tests/unit/neighborhood_spec.lua
+      - tests/unit/build_messages_spec.lua
       - tests/unit/tools_registry_spec.lua
       - tests/unit/tools_dispatcher_spec.lua
       - tests/unit/tools_serialize_spec.lua
diff --git a/lua/parley/chat_respond.lua b/lua/parley/chat_respond.lua
index 11491f7..9be24fb 100644
--- a/lua/parley/chat_respond.lua
+++ b/lua/parley/chat_respond.lua
@@ -8,14 +8,14 @@ local M = {}
 -- (M.config, M._state, M._remote_reference_cache) are visible here by reference.
 local _parley = nil

-local function append_neighborhood_context(agent_info, root)
+local function append_neighborhood_context(agent_info, policy)
     if not agent_info or type(agent_info.tools) ~= "table" or #agent_info.tools == 0 then
         return
     end
-    if type(root) ~= "string" or root == "" then
+    local line = require("parley.neighborhood").format_tool_context(policy)
+    if not line then
         return
     end
-    local line = "Relative tool paths resolve from: " .. root
     if type(agent_info.system_prompt) ~= "string" or agent_info.system_prompt == "" then
         agent_info.system_prompt = line
         return
@@ -374,7 +374,7 @@ M.build_messages_from_model = function(buf, model, target_idx, agent_info)
     local system_prompt_msgs = require("parley.system_prompt_msgs")
     local prov = require("parley.providers")
     local define = require("parley.define")
-    append_neighborhood_context(agent_info, agent_info and agent_info.neighborhood_root)
+    append_neighborhood_context(agent_info, agent_info and agent_info.root_policy)
     local messages = system_prompt_msgs.build(agent_info, function(provider)
         return prov.has_feature(provider, "cache_control")
     end)
@@ -702,7 +702,7 @@ M.build_messages = function(opts)
     then
         agent_info.system_prompt = agent_info.system_prompt .. "\n"
     end
-    append_neighborhood_context(agent_info, opts.neighborhood_root)
+    append_neighborhood_context(agent_info, opts.root_policy)

     -- Convert parsed_chat to messages for the model using a single-pass approach.
     -- Leading messages (system prompt or synthetic pair) are prepended after the
@@ -1337,7 +1337,8 @@ M.respond = function(params, callback, override_free_cursor, force, live_model,
     }, function(resolved_remote_content)
         -- Get agent info early — needed by build_messages_from_model
         local agent_info = _parley.get_agent_info(headers, agent)
-        agent_info.neighborhood_root = require("parley.neighborhood").for_buf(buf)
+        agent_info.root_policy = params.root_policy
+            or require("parley.neighborhood").policy_for_buf(buf)

         -- Handle resubmit BEFORE building messages: if cursor is on a
         -- question/answer with an existing answer (and not mid-tool-loop),
@@ -1382,7 +1383,7 @@ M.respond = function(params, callback, override_free_cursor, force, live_model,
                 helpers = _parley.helpers,
                 logger = _parley.logger,
                 resolved_remote_content = resolved_remote_content,
-                neighborhood_root = agent_info.neighborhood_root,
+                root_policy = agent_info.root_policy,
             })
         end

@@ -1824,7 +1825,7 @@ M.respond = function(params, callback, override_free_cursor, force, live_model,
                     local outcome = tool_loop.process_response(buf, qt.raw_response or "", {
                         max_tool_iterations = agent_info.max_tool_iterations or require("parley.defaults").max_tool_iterations,
                         tool_result_max_bytes = agent_info.tool_result_max_bytes or 102400,
-                        cwd = agent_info.neighborhood_root,
+                        root_policy = agent_info.root_policy,
                     }, model, target_idx)
                     lease_commit()
                     if outcome == "recurse" then
@@ -1839,7 +1840,8 @@ M.respond = function(params, callback, override_free_cursor, force, live_model,
                                 chat_lease.clear(buf, lease_generation)
                                 return
                             end
-                            M.respond({}, callback, override_free_cursor, true, model, target_idx)
+                            M.respond({ root_policy = agent_info.root_policy }, callback,
+                                override_free_cursor, true, model, target_idx)
                         end)
                         return
                     end
diff --git a/lua/parley/init.lua b/lua/parley/init.lua
index 89de32b..be07637 100644
--- a/lua/parley/init.lua
+++ b/lua/parley/init.lua
@@ -1439,6 +1439,9 @@ M.prep_md = function(buf)
     vim.api.nvim_command("setlocal noswapfile")
     -- better text wrapping
     vim.api.nvim_command("setlocal wrap linebreak")
+    if type(M.config.repo_root) == "string" and M.config.repo_root ~= "" then
+        require("parley.neighborhood").attach_completion(buf)
+    end
     -- auto save on TextChanged, InsertLeave (debounced to avoid disk thrashing on large files)
     local save_timer = nil
     local SAVE_DEBOUNCE_MS = 1000
diff --git a/lua/parley/neighborhood.lua b/lua/parley/neighborhood.lua
index 1354621..4e553fa 100644
--- a/lua/parley/neighborhood.lua
+++ b/lua/parley/neighborhood.lua
@@ -93,6 +93,55 @@ function M.derive_for_path(path, config, chat_roots)
     return dirname(artifact_path)
 end

+function M.build_policy(write_root, ordered_roots)
+    local seen, read_roots = {}, {}
+    for _, root in ipairs(ordered_roots or {}) do
+        if type(root) == "string" and root ~= "" and not seen[root] then
+            seen[root] = true
+            read_roots[#read_roots + 1] = root
+        end
+    end
+    return { write_root = write_root, read_roots = read_roots }
+end
+
+function M.policy_from_roots(write_root, repo_root, configured_roots)
+    local function canonical(path)
+        path = clean(path)
+        return path and (vim.loop.fs_realpath(path) or path) or nil
+    end
+    write_root = canonical(write_root)
+    if not write_root then return nil, "buffer has no file" end
+    local roots = { write_root }
+    repo_root = canonical(repo_root)
+    if repo_root then roots[#roots + 1] = repo_root end
+    for _, root in ipairs(configured_roots or {}) do
+        if type(root) == "string" and root ~= "" then
+            if root:sub(1, 1) == "~" then root = vim.fn.expand(root) end
+            local resolved = root:sub(1, 1) == "/" and root or join(write_root, root)
+            roots[#roots + 1] = canonical(resolved)
+        end
+    end
+    return M.build_policy(write_root, roots)
+end
+
+function M.policy_for_path(path, config, chat_roots)
+    local write_root, err = M.derive_for_path(path, config, chat_roots)
+    if not write_root then return nil, err end
+    local configured_repo = clean(config and config.repo_root)
+    local repo_root = configured_repo and path_within(path, configured_repo)
+        and configured_repo or nil
+    return M.policy_from_roots(write_root, repo_root,
+        config and config.tool_read_roots)
+end
+
+function M.format_tool_context(policy)
+    if not policy or not policy.write_root then return nil end
+    local lines = { "Relative reads search these roots in order (first existing match wins):" }
+    for _, root in ipairs(policy.read_roots or {}) do lines[#lines + 1] = "- " .. root end
+    lines[#lines + 1] = "Relative writes resolve only from: " .. policy.write_root
+    return table.concat(lines, "\n")
+end
+
 function M.for_buf(buf)
     local path = vim.api.nvim_buf_get_name(buf)
     local config = require("parley").config
@@ -107,6 +156,18 @@ function M.for_buf(buf)
     return M.derive_for_path(path, config, roots)
 end

+function M.policy_for_buf(buf)
+    local path = vim.api.nvim_buf_get_name(buf)
+    local config = require("parley").config
+    local ok, chat_dirs = pcall(require, "parley.chat_dirs")
+    local roots = {}
+    if ok and type(chat_dirs.get_chat_roots) == "function" then
+        local roots_ok, derived_roots = pcall(chat_dirs.get_chat_roots)
+        if roots_ok then roots = derived_roots end
+    end
+    return M.policy_for_path(path, config, roots)
+end
+
 local function relative_to_root(path, root)
     path = clean(path)
     root = clean(root)
@@ -122,15 +183,43 @@ local function relative_to_root(path, root)
     return nil
 end

-local function root_for_buf(buf)
-    local root = vim.b[buf].parley_neighborhood_root
-    if type(root) ~= "string" or root == "" then
-        root = M.for_buf(buf)
+local function policy_for_completion(buf)
+    return vim.b[buf].parley_root_policy or M.policy_for_buf(buf)
+end
+
+function M.merge_completion_candidates(per_root)
+    local seen, out = {}, {}
+    for _, items in ipairs(per_root or {}) do
+        local sorted = vim.deepcopy(items)
+        table.sort(sorted)
+        for _, item in ipairs(sorted) do
+            if not seen[item] then seen[item] = true; out[#out + 1] = item end
+        end
     end
-    if type(root) ~= "string" or root == "" then
-        return nil
+    return out
+end
+
+function M.completion_candidates(policy, base)
+    local groups = {}
+    for _, root in ipairs(policy and policy.read_roots or {}) do
+        local items = {}
+        for _, match in ipairs(vim.fn.glob(root .. "/" .. (base or "") .. "*", false, true)) do
+            local rel = relative_to_root(match, root)
+            if rel and rel ~= "" then
+                if vim.fn.isdirectory(match) == 1 then rel = rel .. "/" end
+                items[#items + 1] = rel
+            end
+        end
+        groups[#groups + 1] = items
     end
-    return root
+    local accepted = {}
+    local resolver = require("parley.tools.dispatcher").resolve_read_path
+    for _, label in ipairs(M.merge_completion_candidates(groups)) do
+        if resolver(label:gsub("/$", ""), policy.read_roots) then
+            accepted[#accepted + 1] = label
+        end
+    end
+    return accepted
 end

 function M.completefunc(findstart, base)
@@ -149,37 +238,18 @@ function M.completefunc(findstart, base)
     end

     local buf = vim.api.nvim_get_current_buf()
-    local root = root_for_buf(buf)
-    if not root then
+    local policy = policy_for_completion(buf)
+    if not policy then
         return {}
     end
-
-    base = base or ""
-    local pattern = root .. "/" .. base .. "*"
-    local matches = vim.fn.glob(pattern, false, true)
-    local items = {}
-    for _, match in ipairs(matches) do
-        local rel = relative_to_root(match, root)
-        if rel and rel ~= "" then
-            if vim.fn.isdirectory(match) == 1 then
-                rel = rel .. "/"
-            end
-            table.insert(items, rel)
-        end
-    end
-    table.sort(items)
-    return items
+    return M.completion_candidates(policy, base)
 end

-local function cmp_path_sources(cmp, root)
+local cmp_registered = false
+local function cmp_path_sources(cmp)
     local sources = {
         {
-            name = "path",
-            option = {
-                get_cwd = function()
-                    return root
-                end,
-            },
+            name = "parley_path",
         },
         { name = "buffer" },
     }
@@ -195,8 +265,8 @@ function M.attach_cmp_completion(buf)
         return nil
     end

-    local root = root_for_buf(buf)
-    if not root then
+    local policy = policy_for_completion(buf)
+    if not policy then
         return nil
     end

@@ -204,15 +274,29 @@ function M.attach_cmp_completion(buf)
     if not ok or type(cmp) ~= "table" or type(cmp.setup) ~= "table" or type(cmp.setup.buffer) ~= "function" then
         return nil
     end
+    if not cmp_registered and type(cmp.register_source) == "function" then
+        cmp.register_source("parley_path", {
+            complete = function(_, params, callback)
+                local target = params.context and params.context.bufnr or vim.api.nvim_get_current_buf()
+                local before = params.context and params.context.cursor_before_line or ""
+                local base = before:match("([^%s%(%[%{]+)$") or ""
+                local words = M.completion_candidates(policy_for_completion(target), base)
+                local items = {}
+                for _, word in ipairs(words) do items[#items + 1] = { label = word, word = word } end
+                callback(items)
+            end,
+        })
+        cmp_registered = true
+    end

     cmp.setup.buffer({
         completion = {
             keyword_pattern = [[\~\?\(\k\|[\/\.\-]\)\+]],
             keyword_length = 1,
         },
-        sources = cmp_path_sources(cmp, root),
+        sources = cmp_path_sources(cmp),
     })
-    return root
+    return policy.write_root
 end

 local function schedule_cmp_attach(buf)
@@ -222,11 +306,13 @@ local function schedule_cmp_attach(buf)
 end

 function M.attach_completion(buf)
-    local root = M.for_buf(buf)
-    if type(root) ~= "string" or root == "" then
+    local policy = M.policy_for_buf(buf)
+    if not policy then
         return nil
     end
-    vim.b[buf].parley_neighborhood_root = root
+    if vim.b[buf].parley_completion_attached then return policy.write_root end
+    vim.b[buf].parley_completion_attached = true
+    vim.b[buf].parley_root_policy = policy
     vim.api.nvim_set_option_value("completefunc", "v:lua.require'parley.neighborhood'.completefunc", { buf = buf })
     schedule_cmp_attach(buf)
     vim.api.nvim_create_autocmd("InsertEnter", {
@@ -236,7 +322,7 @@ function M.attach_completion(buf)
             schedule_cmp_attach(buf)
         end,
     })
-    return root
+    return policy.write_root
 end

 return M
diff --git a/lua/parley/skill_invoke.lua b/lua/parley/skill_invoke.lua
index c65e020..67fc071 100644
--- a/lua/parley/skill_invoke.lua
+++ b/lua/parley/skill_invoke.lua
@@ -180,8 +180,10 @@ function M.invoke(buf, manifest, args, opts)

     skill_render.clear_decorations(buf)

-    local cwd = require("parley.neighborhood").for_buf(buf)
-        or vim.fn.fnamemodify(artifact_path, ":h")
+    local neighborhood = require("parley.neighborhood")
+    local root_policy = neighborhood.policy_for_buf(buf)
+        or neighborhood.policy_from_roots(vim.fn.fnamemodify(artifact_path, ":h"), nil, {})
+    local cwd = root_policy.write_root

     _in_flight[buf] = true
     -- Detached progress bar: this is a ~30s headless op, so show a running cue
@@ -221,7 +223,7 @@ function M.invoke(buf, manifest, args, opts)
                         end
                     end
                     results[i] = tools_dispatcher.execute_call(call, tools_registry,
-                        { cwd = cwd, read_roots = require("parley.config").tool_read_roots,
+                        { cwd = cwd, root_policy = root_policy,
                           page_limit = require("parley.config").tool_result_page_lines }) -- #140 #139
                     if call.name == "propose_edits" then
                         if results[i].is_error then
diff --git a/lua/parley/tool_loop.lua b/lua/parley/tool_loop.lua
index aa59589..fc39de2 100644
--- a/lua/parley/tool_loop.lua
+++ b/lua/parley/tool_loop.lua
@@ -242,16 +242,16 @@ function M.process_response(bufnr, raw_response, agent_info, live_model, exchang
     -- Execute each tool call and write 🔧:/📎: blocks in streaming order.
     local dispatcher = require("parley.tools.dispatcher")
     local registry = require("parley.tools")
-    local neighborhood_root = agent_info.cwd
-    if not neighborhood_root then
-        neighborhood_root = neighborhood.for_buf(bufnr)
-    end
+    local root_policy = agent_info.root_policy
+        or (agent_info.cwd and neighborhood.policy_from_roots(agent_info.cwd, nil,
+            require("parley.config").tool_read_roots))
+        or neighborhood.policy_for_buf(bufnr)

     local exec_opts = {
-        cwd = neighborhood_root or vim.fn.getcwd(),
+        cwd = root_policy and root_policy.write_root or vim.fn.getcwd(),
+        root_policy = root_policy,
         max_bytes = agent_info.tool_result_max_bytes or 102400,
         -- #140: extra read-tool roots (global config); write tools ignore it.
-        read_roots = require("parley.config").tool_read_roots,
         -- #139: default output-pager page size; the dispatcher windows results.
         page_limit = require("parley.config").tool_result_page_lines,
     }
diff --git a/lua/parley/tools/dispatcher.lua b/lua/parley/tools/dispatcher.lua
index 965dfeb..7167451 100644
--- a/lua/parley/tools/dispatcher.lua
+++ b/lua/parley/tools/dispatcher.lua
@@ -6,14 +6,9 @@
 -- error wrapping. Every safety concern lives HERE so there's
 -- exactly one place to audit and one place to fix.
 --
--- At M2 this module exposes read-path helpers (resolve_path_in_cwd,
--- truncate, execute_call). Write-path concerns (dirty-buffer guard,
--- .parley-backup, gitignore auto-append, checktime-reload,
--- metadata-preserving truncation for write_file's pre-image footer)
--- land in M5 Task 5.1 / 5.2 / 5.3 / 5.6 and extend this same file.
---
 -- SINGLE source for each invariant:
---   - cwd-scope + symlink safety: resolve_path_in_cwd
+--   - ordered read roots:         resolve_read_path
+--   - write-root confinement:     resolve_path_in_cwd
 --   - result size cap:            truncate / truncate_preserving_footer (M5)
 --   - pcall-guarded handler call: execute_call
 --   - dirty-buffer guard:         check_dirty_buffer (M5)
@@ -124,6 +119,37 @@ function M.resolve_path_in_cwd(path, cwd, allowed_roots)
     return nil, "path outside working directory: " .. path
 end

+function M.resolve_read_path(path, read_roots)
+    if type(path) ~= "string" or path == "" then
+        return nil, "path must be a non-empty string"
+    end
+    local roots = {}
+    for _, root in ipairs(read_roots or {}) do
+        local resolved = resolve_root(root, root)
+        if resolved then roots[#roots + 1] = resolved end
+    end
+    local candidates = {}
+    if path:sub(1, 1) == "/" then
+        candidates[1] = path
+    else
+        for _, root in ipairs(roots) do candidates[#candidates + 1] = root .. "/" .. path end
+    end
+    for _, candidate in ipairs(candidates) do
+        candidate = vim.fs.normalize(candidate)
+        if vim.loop.fs_lstat(candidate) then
+            local real = vim.loop.fs_realpath(candidate)
+            if not real then
+                return nil, "cannot resolve read path: " .. path
+            end
+            for _, root in ipairs(roots) do
+                if real == root or real:sub(1, #root + 1) == root .. "/" then return real end
+            end
+            return nil, "read path resolves outside configured roots: " .. path
+        end
+    end
+    return nil, "read path not found in configured roots: " .. path
+end
+
 --------------------------------------------------------------------------------
 -- Result truncation
 --------------------------------------------------------------------------------
@@ -202,17 +228,16 @@ end
 --- go wrong — the tool loop driver can serialize it directly without
 --- further checks.
 ---
---- M5 will add a write-path prelude to this function (cwd-scope,
---- dirty-buffer, backup, gitignore, checktime) branched on
---- `def.kind == "write"`. At M2 the shared prelude only handles
---- the cwd-scope check when `call.input.path` is present.
----
 --- @param call ToolCall { id, name, input }
 --- @param tools_registry table module exposing `get(name)` (parley.tools)
---- @param opts table|nil { max_bytes?: number, cwd?: string }
+--- @param opts table|nil { max_bytes?: number, root_policy?: RootPolicy, cwd?: string, read_roots?: string[] }
 --- @return ToolResult
 function M.execute_call(call, tools_registry, opts)
     opts = opts or {}
+    local policy = opts.root_policy
+    if not policy and opts.cwd then
+        policy = require("parley.neighborhood").policy_from_roots(opts.cwd, nil, opts.read_roots)
+    end

     local def = tools_registry.get(call.name)
     if not def then
@@ -240,18 +265,23 @@ function M.execute_call(call, tools_registry, opts)
         -- write tools get nil → cwd-only. Gate on `~= "write"` (the canonical
         -- read-tool predicate `@readonly` uses): `kind` defaults to read when
         -- absent, so `== "read"` would wrongly confine an absent-kind tool.
-        return (def.kind ~= "write") and (opts.read_roots or {}) or nil
+        return (def.kind ~= "write") and (policy and policy.read_roots or {}) or nil
     end

     local path_fields = { "path", "file_path" }
-    if opts.cwd and call.input and def.default_path and call.input.path == nil
+    if policy and call.input and def.default_path and call.input.path == nil
         and call.input.file_path == nil and call.input.paths == nil then
         call.input.path = def.default_path
     end
     for _, field in ipairs(path_fields) do
-        if opts.cwd and call.input and type(call.input[field]) == "string" then
+        if policy and call.input and type(call.input[field]) == "string" then
             local roots = roots_for_def()
-            local abs, scope_err = M.resolve_path_in_cwd(call.input[field], opts.cwd, roots)
+            local abs, scope_err
+            if def.kind ~= "write" then
+                abs, scope_err = M.resolve_read_path(call.input[field], roots)
+            else
+                abs, scope_err = M.resolve_path_in_cwd(call.input[field], policy.write_root)
+            end
             if not abs then
                 return {
                     id = call.id,
@@ -263,7 +293,7 @@ function M.execute_call(call, tools_registry, opts)
             call.input[field] = abs
         end
     end
-    if opts.cwd and call.input and type(call.input.paths) == "table" then
+    if policy and call.input and type(call.input.paths) == "table" then
         local roots = roots_for_def()
         local resolved = {}
         for i, path in ipairs(call.input.paths) do
@@ -275,7 +305,12 @@ function M.execute_call(call, tools_registry, opts)
                     is_error = true,
                 }
             end
-            local abs, scope_err = M.resolve_path_in_cwd(path, opts.cwd, roots)
+            local abs, scope_err
+            if def.kind ~= "write" then
+                abs, scope_err = M.resolve_read_path(path, roots)
+            else
+                abs, scope_err = M.resolve_path_in_cwd(path, policy.write_root)
+            end
             if not abs then
                 return {
                     id = call.id,
diff --git a/tests/integration/neighborhood_completion_spec.lua b/tests/integration/neighborhood_completion_spec.lua
index 9d8e289..0a72bea 100644
--- a/tests/integration/neighborhood_completion_spec.lua
+++ b/tests/integration/neighborhood_completion_spec.lua
@@ -45,10 +45,34 @@ describe("neighborhood completion", function()
     end)

     after_each(function()
+        parley.config.repo_root = repo
         package.loaded.cmp = saved_cmp
         pcall(vim.cmd, "bwipeout!")
     end)

+    it("attaches once to repo markdown and leaves non-repo markdown untouched", function()
+        vim.fn.mkdir(repo .. "/docs", "p")
+        local path = repo .. "/docs/note.md"
+        vim.fn.writefile({ "note" }, path)
+        vim.cmd("edit! " .. vim.fn.fnameescape(path))
+        local buf = vim.api.nvim_get_current_buf()
+        parley.prep_md(buf)
+        assert.is_true(vim.b[buf].parley_completion_attached)
+        local policy = vim.b[buf].parley_root_policy
+        parley.prep_md(buf)
+        assert.same(policy, vim.b[buf].parley_root_policy)
+
+        pcall(vim.cmd, "bwipeout!")
+        parley.config.repo_root = nil
+        local outside = tmpdir .. "/outside.md"
+        vim.fn.writefile({ "outside" }, outside)
+        vim.cmd("edit! " .. vim.fn.fnameescape(outside))
+        buf = vim.api.nvim_get_current_buf()
+        parley.prep_md(buf)
+        assert.is_nil(vim.b[buf].parley_completion_attached)
+        assert.equals("", vim.bo[buf].completefunc)
+    end)
+
     it("attaches a chat-local completefunc rooted at the neighborhood", function()
         local buf, path = make_chat()

@@ -73,8 +97,25 @@ describe("neighborhood completion", function()
         assert.equals(#"open ", neighborhood.completefunc(1, ""))
     end)

-    it("configures cmp-path completion from the neighborhood root", function()
+    it("omits escaping and dangling authoritative candidates without fallback", function()
+        local first, second, outside = repo .. "/first", repo .. "/second", tmpdir .. "/outside"
+        vim.fn.mkdir(first, "p")
+        vim.fn.mkdir(second, "p")
+        vim.fn.mkdir(outside, "p")
+        vim.fn.writefile({ "outside" }, outside .. "/same.md")
+        vim.fn.writefile({ "second" }, second .. "/same.md")
+        vim.loop.fs_symlink(outside .. "/same.md", first .. "/same.md")
+        vim.loop.fs_symlink(outside .. "/missing.md", first .. "/dangling.md")
+        local policy = { write_root = first, read_roots = { first, second } }
+        assert.same({}, neighborhood.completion_candidates(policy, "same"))
+        assert.same({}, neighborhood.completion_candidates(policy, "dangling"))
+    end)
+
+    it("configures the policy-backed Parley completion source", function()
         local captured
+        local registered
+        local setup_count = 0
+        local register_count = 0
         package.loaded.cmp = {
             config = {
                 sources = function(sources)
@@ -84,8 +125,13 @@ describe("neighborhood completion", function()
             setup = {
                 buffer = function(config)
                     captured = config
+                    setup_count = setup_count + 1
                 end,
             },
+            register_source = function(name, source)
+                registered = { name = name, source = source }
+                register_count = register_count + 1
+            end,
         }

         local buf, path = make_chat()
@@ -96,7 +142,16 @@ describe("neighborhood completion", function()
         end)

         assert.is_not_nil(captured)
-        assert.same({ "path", "buffer" }, { captured.sources[1].name, captured.sources[2].name })
-        assert.equals(repo, captured.sources[1].option.get_cwd({ context = { bufnr = buf } }))
+        assert.same({ "parley_path", "buffer" }, { captured.sources[1].name, captured.sources[2].name })
+        assert.equals("parley_path", registered.name)
+        local before_repeat = setup_count
+        neighborhood.attach_completion(buf)
+        vim.wait(20)
+        assert.equals(before_repeat, setup_count)
+        assert.equals(1, register_count)
+        local items
+        registered.source:complete({ context = { bufnr = buf, cursor_before_line = "REA" } },
+            function(result) items = result end)
+        assert.equals("README.md", items[1].word)
     end)
 end)
diff --git a/tests/integration/skill_invoke_spec.lua b/tests/integration/skill_invoke_spec.lua
index 1d432e2..07c4dd7 100644
--- a/tests/integration/skill_invoke_spec.lua
+++ b/tests/integration/skill_invoke_spec.lua
@@ -227,18 +227,17 @@ describe("skill_invoke.invoke", function()
         assert.is_false(query_called, "must not query when source failed")
     end)

-    it("executes relative tool paths from a repo-backed artifact neighborhood", function()
+    it("widens relative reads from ordinary nested repo Markdown", function()
         local repo = tmpdir .. "/repo"
-        local repo_chat = repo .. "/workshop/parley"
-        vim.fn.mkdir(repo_chat, "p")
+        local nested = repo .. "/data/nested"
+        vim.fn.mkdir(nested, "p")
         vim.fn.writefile({ "repo root file" }, repo .. "/README.md")
-        path = repo_chat .. "/2026-06-29.topic.md"
+        path = nested .. "/doc.md"
         vim.fn.writefile({ "alpha beta" }, path)
         vim.cmd("edit! " .. vim.fn.fnameescape(path))
         buf = vim.api.nvim_get_current_buf()

         parley.config.repo_root = repo
-        parley.config.repo_chat_dir = "workshop/parley"

         parley.dispatcher.query = function(_b, _p, _payload, _h, on_exit)
             tasker.set_query("qid_read", {
diff --git a/tests/unit/build_messages_spec.lua b/tests/unit/build_messages_spec.lua
index 429ef48..b77d306 100644
--- a/tests/unit/build_messages_spec.lua
+++ b/tests/unit/build_messages_spec.lua
@@ -127,10 +127,14 @@ describe("_build_messages: basic structure", function()
             config = parley.config,
             helpers = stub_helpers,
             logger = stub_logger,
-            neighborhood_root = "/workspace/repo",
+            root_policy = {
+                write_root = "/workspace/repo",
+                read_roots = { "/workspace/repo" },
+            },
         })

-        assert.matches("Relative tool paths resolve from: /workspace/repo", messages[1].content)
+        assert.matches("Relative reads search these roots in order", messages[1].content)
+        assert.matches("Relative writes resolve only from: /workspace/repo", messages[1].content)
     end)

     it("single exchange with answer produces system + user + assistant", function()
diff --git a/tests/unit/neighborhood_spec.lua b/tests/unit/neighborhood_spec.lua
index 703c670..45fffb7 100644
--- a/tests/unit/neighborhood_spec.lua
+++ b/tests/unit/neighborhood_spec.lua
@@ -79,3 +79,61 @@ describe("neighborhood.derive_for_path", function()
         assert.equals("buffer has no file", err)
     end)
 end)
+
+describe("neighborhood root policy (#181)", function()
+    it("builds a stable first-wins policy without mutating input", function()
+        local roots = { "/a", "", "/b", "/a" }
+        assert.same({ write_root = "/a", read_roots = { "/a", "/b" } },
+            neighborhood.build_policy("/a", roots))
+        assert.same({ "/a", "", "/b", "/a" }, roots)
+    end)
+    it("orders neighborhood, repo, and configured roots first-wins", function()
+        local policy = neighborhood.policy_for_path(
+            "/repo/data/career/note.md",
+            cfg({ repo_root = "/repo", tool_read_roots = { "/repo", "../../../sibling" } }),
+            {})
+        assert.equals("/repo/data/career", policy.write_root)
+        assert.same({ "/repo/data/career", "/repo", "/sibling" }, policy.read_roots)
+    end)
+
+    it("does not add a repo root outside repo mode", function()
+        local config = cfg({ tool_read_roots = {} })
+        config.repo_root = nil
+        local policy = neighborhood.policy_for_path("/notes/note.md", config, {})
+        assert.same({ "/notes" }, policy.read_roots)
+    end)
+
+    it("keeps a global chat narrow while repo mode is active", function()
+        local policy = neighborhood.policy_for_path("/global/chats/chat.md", cfg({
+            tool_read_roots = {},
+        }), { "/global/chats" })
+        assert.same({ "/global/chats" }, policy.read_roots)
+    end)
+
+    it("canonicalizes symlink aliases before de-duplicating roots", function()
+        local base = (os.getenv("TMPDIR") or "/tmp") .. "/parley-policy-" .. math.random(1, 999999)
+        vim.fn.mkdir(base .. "/real", "p")
+        vim.loop.fs_symlink(base .. "/real", base .. "/alias")
+        local policy = neighborhood.policy_from_roots(base .. "/real", nil, { base .. "/alias" })
+        assert.same({ vim.loop.fs_realpath(base .. "/real") }, policy.read_roots)
+        vim.fn.delete(base, "rf")
+    end)
+
+    it("formats guidance from the policy", function()
+        assert.equals(table.concat({
+            "Relative reads search these roots in order (first existing match wins):",
+            "- /repo/data",
+            "- /repo",
+            "Relative writes resolve only from: /repo/data",
+        }, "\n"), neighborhood.format_tool_context({
+            write_root = "/repo/data",
+            read_roots = { "/repo/data", "/repo" },
+        }))
+    end)
+
+    it("merges string candidates first-root-first without mutating inputs", function()
+        local groups = { { "z", "same" }, { "a", "same" } }
+        assert.same({ "same", "z", "a" }, neighborhood.merge_completion_candidates(groups))
+        assert.same({ { "z", "same" }, { "a", "same" } }, groups)
+    end)
+end)
diff --git a/tests/unit/tool_loop_spec.lua b/tests/unit/tool_loop_spec.lua
index 78dba55..99e221c 100644
--- a/tests/unit/tool_loop_spec.lua
+++ b/tests/unit/tool_loop_spec.lua
@@ -51,6 +51,26 @@ local function mk_read_file_sse_response(toolu_id, path)
     return table.concat(lines, "\n")
 end

+local function mk_write_file_sse_response(toolu_id, path, content)
+    local events = {
+        { type = "message_start", message = { id = "msg_test", model = "claude-sonnet-4-6" } },
+        { type = "content_block_start", index = 0,
+          content_block = { type = "tool_use", id = toolu_id, name = "write_file", input = {} } },
+        { type = "content_block_delta", index = 0,
+          delta = { type = "input_json_delta", partial_json = vim.json.encode({ path = path, content = content }) } },
+        { type = "content_block_stop", index = 0 },
+        { type = "message_delta", delta = { stop_reason = "tool_use" } },
+        { type = "message_stop" },
+    }
+    local lines = {}
+    for _, ev in ipairs(events) do
+        table.insert(lines, "event: " .. (ev.type or "unknown"))
+        table.insert(lines, "data: " .. vim.json.encode(ev))
+        table.insert(lines, "")
+    end
+    return table.concat(lines, "\n")
+end
+
 -- Build an SSE response that returns plain text (no tool_use) —
 -- the "final answer" phase of a tool loop.
 local function mk_plain_text_sse_response(text)
@@ -227,23 +247,22 @@ describe("tool_loop.process_response: with tool_use", function()
         assert.matches("🔧: read_file id=toolu_ERR", text)
         assert.matches("📎: read_file id=toolu_ERR", text)
         assert.matches("error=true", text)
-        assert.matches("outside working directory", text)
+        assert.matches("read path .* configured roots", text)
     end)

-    it("uses the chat buffer neighborhood as cwd when agent cwd is absent", function()
+    it("widens reads but not writes from ordinary nested repo Markdown", function()
         local parley = require("parley")
         local repo = tmp_base .. "/repo-" .. math.random(0, 0xFFFFFF)
-        local repo_chat = repo .. "/workshop/parley"
+        local nested = repo .. "/data/nested"
         local other_cwd = tmp_base .. "/other-cwd-" .. math.random(0, 0xFFFFFF)
-        vim.fn.mkdir(repo_chat, "p")
+        vim.fn.mkdir(nested, "p")
         vim.fn.mkdir(other_cwd, "p")
         vim.fn.writefile({ "from repo root" }, repo .. "/README.md")

         parley.config.repo_root = repo
-        parley.config.repo_chat_dir = "workshop/parley"

         local bufnr = mk_buffer({ "💬: q", "🤖: [Claude]" })
-        vim.api.nvim_buf_set_name(bufnr, repo_chat .. "/2026-06-29.topic.md")
+        vim.api.nvim_buf_set_name(bufnr, nested .. "/doc.md")

         local old_cwd = vim.fn.getcwd()
         vim.cmd("cd " .. vim.fn.fnameescape(other_cwd))
@@ -257,6 +276,16 @@ describe("tool_loop.process_response: with tool_use", function()
         local text = buf_text(bufnr)
         assert.matches("📎: read_file id=toolu_NEIGHBORHOOD", text)
         assert.matches("from repo root", text)
+
+        local write_raw = mk_write_file_sse_response("toolu_NARROW_WRITE", "README.md", "replaced")
+        local write_outcome = tool_loop.process_response(bufnr, write_raw, {
+            max_tool_iterations = 20,
+        })
+        assert.equals("recurse", write_outcome)
+        text = buf_text(bufnr)
+        assert.matches("📎: write_file id=toolu_NARROW_WRITE", text)
+        assert.are.same({ "replaced" }, vim.fn.readfile(nested .. "/README.md"))
+        assert.are.same({ "from repo root" }, vim.fn.readfile(repo .. "/README.md"))
     end)

     it("emits 📎: result in dynamic-fence form that survives backticks in file content", function()
diff --git a/tests/unit/tools_dispatcher_spec.lua b/tests/unit/tools_dispatcher_spec.lua
index 8eee4ae..e2ebad1 100644
--- a/tests/unit/tools_dispatcher_spec.lua
+++ b/tests/unit/tools_dispatcher_spec.lua
@@ -195,6 +195,84 @@ describe("resolve_path_in_cwd allowed_roots (#140)", function()
     end)
 end)

+describe("resolve_read_path ordered roots (#181)", function()
+    it("falls through to repo root and prefers neighborhood collisions", function()
+        local n = math.random(0, 0xFFFFFF)
+        local repo = tmp_base .. "/policy-repo-" .. n
+        local neighborhood = repo .. "/data"
+        vim.fn.mkdir(neighborhood .. "/atlas", "p")
+        vim.fn.mkdir(repo .. "/atlas", "p")
+        vim.fn.writefile({ "local" }, neighborhood .. "/atlas/index.md")
+        vim.fn.writefile({ "repo" }, repo .. "/atlas/index.md")
+        assert.equals(canonical(neighborhood .. "/atlas/index.md"),
+            dispatcher.resolve_read_path("atlas/index.md", { neighborhood, repo }))
+        vim.fn.delete(neighborhood .. "/atlas/index.md")
+        assert.equals(canonical(repo .. "/atlas/index.md"),
+            dispatcher.resolve_read_path("atlas/index.md", { neighborhood, repo }))
+    end)
+
+    it("rejects missing reads instead of synthesizing a leaf", function()
+        local root = tmp_base .. "/missing-read-" .. math.random(0, 0xFFFFFF)
+        vim.fn.mkdir(root, "p")
+        local path, err = dispatcher.resolve_read_path("missing.md", { root })
+        assert.is_nil(path)
+        assert.matches("read path .* configured roots", err)
+    end)
+
+    it("accepts absolute paths inside roots and rejects symlink escapes", function()
+        local root = tmp_base .. "/abs-read-" .. math.random(0, 0xFFFFFF)
+        local outside = tmp_base .. "/abs-outside-" .. math.random(0, 0xFFFFFF)
+        vim.fn.mkdir(root, "p")
+        vim.fn.mkdir(outside, "p")
+        vim.fn.writefile({ "inside" }, root .. "/inside.md")
+        vim.fn.writefile({ "outside" }, outside .. "/outside.md")
+        assert.equals(canonical(root .. "/inside.md"),
+            dispatcher.resolve_read_path(root .. "/inside.md", { root }))
+        vim.loop.fs_symlink(outside .. "/outside.md", root .. "/escape.md")
+        local escaped, err = dispatcher.resolve_read_path("escape.md", { root })
+        assert.is_nil(escaped)
+        assert.matches("read path resolves outside configured roots", err)
+    end)
+
+    it("rejects an escaping first candidate instead of falling through", function()
+        local base = tmp_base .. "/precedence-" .. math.random(0, 0xFFFFFF)
+        local first, second, outside = base .. "/first", base .. "/second", base .. "/outside"
+        vim.fn.mkdir(first .. "/docs", "p")
+        vim.fn.mkdir(second .. "/docs", "p")
+        vim.fn.mkdir(outside, "p")
+        vim.fn.writefile({ "outside" }, outside .. "/note.md")
+        vim.fn.writefile({ "second" }, second .. "/docs/note.md")
+        vim.loop.fs_symlink(outside .. "/note.md", first .. "/docs/note.md")
+        local path, err = dispatcher.resolve_read_path("docs/note.md", { first, second })
+        assert.is_nil(path)
+        assert.matches("resolves outside configured roots", err)
+    end)
+
+    it("rejects a dangling symlink without crashing", function()
+        local root = tmp_base .. "/dangling-" .. math.random(0, 0xFFFFFF)
+        vim.fn.mkdir(root, "p")
+        vim.loop.fs_symlink(root .. "/missing-target", root .. "/dangling.md")
+        local ok, path, err = pcall(dispatcher.resolve_read_path, "dangling.md", { root })
+        assert.is_true(ok)
+        assert.is_nil(path)
+        assert.matches("cannot resolve read path", err)
+    end)
+
+    it("enforces an injected root_policy without legacy cwd", function()
+        local root = tmp_base .. "/policy-only-" .. math.random(0, 0xFFFFFF)
+        vim.fn.mkdir(root, "p")
+        vim.fn.writefile({ "ok" }, root .. "/doc.md")
+        registry.register({ name = "policy_read", kind = "read", description = "r",
+            input_schema = { type = "object" }, handler = function(input)
+                return { content = input.path, is_error = false }
+            end })
+        local res = dispatcher.execute_call({ id = "rp", name = "policy_read",
+            input = { path = "doc.md" } }, registry,
+            { root_policy = { write_root = root, read_roots = { root } } })
+        assert.equals(canonical(root .. "/doc.md"), res.content)
+    end)
+end)
+
 describe("truncate", function()
     it("returns content unchanged when under the byte cap", function()
         assert.equals("hello", dispatcher.truncate("hello", 100))
@@ -492,7 +570,7 @@ describe("execute_call", function()
             { cwd = cwd, read_roots = {} }
         )
         assert.is_true(res.is_error)
-        assert.matches("tool_read_roots", res.content)
+        assert.matches("read path not found in configured roots", res.content)
         assert.not_matches("should not run", res.content)
     end)

diff --git a/workshop/plans/000181-repo-root-read-wide-completion-for-all-markdown-close-review.md b/workshop/plans/000181-repo-root-read-wide-completion-for-all-markdown-close-review.md
new file mode 100644
index 0000000..7edbb8c
--- /dev/null
+++ b/workshop/plans/000181-repo-root-read-wide-completion-for-all-markdown-close-review.md
@@ -0,0 +1,59 @@
+# Boundary Review — Issue #181
+
+| field | value |
+|---|---|
+| issue | 181 — repo-root read-wide completion for all markdown |
+| boundary | whole-issue close |
+| window | `7719c33ff31ae977796b1032c4bb64f1693b3fc1..0f0b025f` |
+| reviewer | codex |
+| timestamp | 2026-07-11 |
+| final verdict | `FIX-THEN-SHIP` |
+
+## Review history
+
+The close gate ran several fresh-context passes. Each blocking finding was fixed
+and committed before the next pass:
+
+1. Preserve global-chat narrowing and canonicalize policy roots.
+2. Make the first existing read candidate authoritative; do not fall through
+   after containment rejection.
+3. Reject dangling read candidates deterministically.
+4. Filter completion through canonical read enforcement and complete
+   traceability.
+5. Add ordinary nested-Markdown chat and skill regressions that distinguish
+   repo-root read widening from the legacy artifact-root behavior.
+
+## Final review
+
+```verdict
+verdict: FIX-THEN-SHIP
+confidence: high
+```
+
+The reviewer found no Critical implementation defect. It confirmed that one
+root policy drives read resolution, write confinement, completion, skill/chat
+dispatch, and model guidance; completion reuses `resolve_read_path`; attachment
+is idempotent; ordinary non-repo Markdown is unchanged; and atlas/traceability
+coverage is present.
+
+The sole Important finding was an evidence gap: chat and skill integration
+tests used repo-backed chat artifacts whose legacy neighborhood was already the
+repo root. The follow-up commit replaced those cases with ordinary
+`data/nested/doc.md` buffers, proving repo-root-only reads at both seams. The
+chat regression additionally proves the identical relative write lands in the
+nested write neighborhood and leaves the repo-root candidate unchanged. The
+reviewer's stale dispatcher-annotation note was also resolved.
+
+Verification after the follow-up: mapped `providers/tool_use` and
+`skills/skill-system` suites passed; `make -f Makefile.parley test JOBS=1`
+passed with lint clean across 244 files and all unit, integration, and
+architecture specs green; `git diff --check` passed.
+
+## Architecture
+
+- `ARCH-DRY`: pass — all consumers derive from `RootPolicy` and completion
+  acceptance reuses the dispatcher resolver.
+- `ARCH-PURE`: pass — deterministic policy/merge/formatting helpers are kept
+  separate from filesystem and Neovim adapters.
+- `ARCH-PURPOSE`: pass after follow-up — ordinary nested-Markdown regressions
+  now demonstrate the issue's actual read-wide/write-narrow purpose.
diff --git a/workshop/plans/000181-repo-root-read-wide-completion-for-all-markdown-plan.md b/workshop/plans/000181-repo-root-read-wide-completion-for-all-markdown-plan.md
index e518463..aa92836 100644
--- a/workshop/plans/000181-repo-root-read-wide-completion-for-all-markdown-plan.md
+++ b/workshop/plans/000181-repo-root-read-wide-completion-for-all-markdown-plan.md
@@ -26,7 +26,9 @@ already-canonical absolute roots by pure `build_policy(write_root, roots)`.
 - **DRY rationale:** `tool_loop`, `skill_invoke`, completion, and model context currently receive pieces of path policy separately. A shared value prevents enforcement and guidance from reconstructing different root sets (`ARCH-DRY`). Filesystem-dependent canonicalization stays in `policy_for_path`; the pure builder only orders and de-duplicates supplied strings (`ARCH-PURE`).
 - **Future extensions:** A subtree marker can change policy construction later without changing dispatcher or completion consumers.

-**CompletionCandidates** — ordered root-relative candidate labels merged from per-root filesystem results.
+**CompletionCandidates** — ordered root-relative string labels merged from
+per-root filesystem results; adapters wrap strings as cmp items only at the UI
+boundary.

 - **Relationships:** N:1 from per-root match lists to one de-duplicated display list; the earliest root owns a collision.
 - **DRY rationale:** Both built-in completion and cmp configuration need the same ordering and collision rule.
@@ -674,3 +676,57 @@ Reason: `change-code` review caught that moving attachment unconditionally into
 Delta: `prep_md` attaches only with `config.repo_root`; `prep_chat` retains the
 global-chat path and relies on the idempotence guard in repo mode. Tests pin
 both unchanged non-repo cases.
+
+### 2026-07-11 — close-review completion of the test matrix
+
+Reason: the first close review exposed global-chat widening and implicit rather
+than explicit root canonicalization, both missed by the initial tests.
+
+Delta: repo-root inclusion is artifact-scoped, policy roots are realpath-first,
+and the integration/security matrix now covers global chats in repo mode,
+ordinary repo/non-repo Markdown, repeat attachment, absolute reads, and symlink
+escape behavior.
+
+### 2026-07-11 — enforce first-existing containment and reconcile candidates
+
+Reason: the second close review found that an escaping first candidate could
+fall through to a lower root, and the plan described structured completion
+items while the shared pure core intentionally merges strings.
+
+Delta: the first existing candidate is now authoritative and rejected on
+containment failure; it never falls through. The Core Concepts contract now
+matches the string-label pure entity, with cmp item wrapping confined to the UI
+adapter. Root-policy enforcement no longer depends on legacy `cwd`.
+
+### 2026-07-11 — reject unresolved existing candidates
+
+Reason: close review identified the `fs_lstat`/`fs_realpath` disagreement for
+dangling symlinks and gaps between the aspirational test checklist and landed
+evidence.
+
+Delta: dangling symlinks return a deterministic read error; direct policy,
+real cmp callback/registration, and repeated attachment are tested. Scalar,
+array, default, kind, and write-narrow semantics are pinned at the shared
+dispatcher boundary consumed by chat and skills; their existing integration
+tests pin policy wiring rather than duplicating every dispatcher case.
+
+### 2026-07-11 — unify completion with canonical read acceptance
+
+Reason: close review found lexical completion candidates could violate the
+dispatcher containment contract.
+
+Delta: both completion adapters filter the shared labels through the canonical
+read resolver; escaping and dangling authoritative candidates are omitted
+without lower-root fallback. Added the missing build-message traceability entry.
+
+### 2026-07-11 — exercise widening at the chat and skill seams
+
+Reason: the final close review found that the existing chat and skill wiring
+tests used repo-backed chat artifacts whose legacy neighborhood was already the
+repo root, so they did not distinguish the new policy from the old behavior.
+
+Delta: both seams now execute a repo-root-only relative read from ordinary
+`data/nested/doc.md`. The chat regression also proves the same relative write
+lands in the nested write neighborhood and leaves the repo-root file unchanged
+(`ARCH-PURPOSE`). Dispatcher annotations were refreshed to describe the landed
+root-policy API.


codex
I’ll verify the issue and plan against the actual base-to-HEAD diff, inspect repository guidance, and run the relevant tests. I’ll keep the review read-only.
exec
/bin/zsh -lc "pwd && rg --files -g 'AGENTS.md' -g 'workshop/issues/000181*' -g 'workshop/plans/000181*' -g 'Makefile*' | sort && git status --short && git log --oneline --decorate -8 && git diff --stat 7719c33ff31ae977796b1032c4bb64f1693b3fc1..HEAD" in /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown
 succeeded in 0ms:
/Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown
Makefile.local
Makefile.parley
workshop/issues/000181-repo-root-read-wide-completion-for-all-markdown.md
workshop/plans/000181-repo-root-read-wide-completion-for-all-markdown-close-review.md
workshop/plans/000181-repo-root-read-wide-completion-for-all-markdown-plan.md
9004259 (HEAD -> 000181-repo-root-read-wide-completion-for-all-markdown) #181: compact boundary review record
cf6f60e #181: close read-wide neighborhood completion
0f0b025 #181: align completion with read enforcement
a65eaac #181: reject dangling read candidates
9aad3ea #181: enforce first-existing read precedence
ec35f04 #181: preserve global chat neighborhood
963381b #181: add read-wide neighborhood policy
7719c33 (main) issue: #181 preserve non-repo completion scope
 atlas/infra/repo_mode.md                           |  17 +--
 atlas/providers/tool_use.md                        |  10 +-
 atlas/traceability.yaml                            |   1 +
 lua/parley/chat_respond.lua                        |  20 +--
 lua/parley/init.lua                                |   3 +
 lua/parley/neighborhood.lua                        | 166 ++++++++++++++++-----
 lua/parley/skill_invoke.lua                        |   8 +-
 lua/parley/tool_loop.lua                           |  12 +-
 lua/parley/tools/dispatcher.lua                    |  73 ++++++---
 tests/integration/neighborhood_completion_spec.lua |  61 +++++++-
 tests/integration/skill_invoke_spec.lua            |   9 +-
 tests/unit/build_messages_spec.lua                 |   8 +-
 tests/unit/neighborhood_spec.lua                   |  58 +++++++
 tests/unit/tool_loop_spec.lua                      |  41 ++++-
 tests/unit/tools_dispatcher_spec.lua               |  80 +++++++++-
 ...o-root-read-wide-completion-for-all-markdown.md |  72 ++++++++-
 ...ide-completion-for-all-markdown-close-review.md |  59 ++++++++
 ...t-read-wide-completion-for-all-markdown-plan.md |  58 ++++++-
 18 files changed, 644 insertions(+), 112 deletions(-)

exec
/bin/zsh -lc "find .. -name AGENTS.md -print; sed -n '1,240p' workshop/issues/000181-repo-root-read-wide-completion-for-all-markdown.md; sed -n '1,220p' workshop/plans/000181-repo-root-read-wide-completion-for-all-markdown-plan.md" in /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown
 succeeded in 107ms:
---
id: 000181
status: codecomplete
deps: []
github_issue:
created: 2026-07-10
updated: 2026-07-11
estimate_hours: 3.58
started: 2026-07-10T08:38:14-07:00
actual_hours: N/A
---

# repo-root read-wide completion for all markdown

## Problem

The #147 reference-neighborhood rule derives a **single** root per artifact and
uses it for *both* relative tool-path resolution and file-path completion. The
root is `repo_root` only for repo-backed Parley artifacts (files under
`repo_artifacts.dir_keys` → `workshop/parley|notes|issues|vision|history`);
every other file — including ordinary content under `data/`, `atlas/`,
`docs/`, or a data-file at repo top-level — falls through to `dirname(path)`,
its own folder.

Two consequences bite in a `.parley` repo:

1. **No repo-root escape hatch.** Editing `data/career/2026/xnurta-plan.md`, a
   reference/path resolves relative to `data/career/2026/` (`./`), and there is
   no way to reach a repo-root-relative path — even though the file is squarely
   inside the repo and repo-root-relative is how one naturally thinks
   (`data/career/2026/foo.md`, `atlas/index.md`).
2. **Completion is chat-only anyway.** `neighborhood.attach_completion` is
   called *only* from `prep_chat` (init.lua:1947). Non-chat markdown goes
   through `prep_md`, which never attaches it — so plain data/content markdown
   gets no neighborhood-aware completion at all (falls back to vim/cmp default,
   which isn't repo-anchored).

Design context + the option we picked (option 1, read-wide/write-narrow) is in
the parley chat `workshop/parley/` for 2026-07-10; option 2 (`.parley-neighborhood`
intermediate-scope marker) was considered and **deferred** — see Log.

## Spec

Adopt a **read-wide / write-narrow** split of the neighborhood root, and extend
completion to all markdown buffers in repo mode.

- **Write / primary root — unchanged.** `write_file` / `edit_file` and the
  dispatcher's `resolve_path_in_cwd` write-side enforcement keep using the
  current per-artifact neighborhood (`derive_for_path`). Writes stay confined —
  this is the rogue-agent boundary (`brain/atlas/threat-model-shared-brain.md`);
  do NOT widen it. Repo-root is NOT added to the write root.

- **Read + completion roots — widened to an ordered set.** When repo mode is active
  (`config.repo_root` set), fold `repo_root` into the set of roots used for (a)
  read-tool path resolution and (b) file-path completion candidates, *in
  addition to* the per-artifact neighborhood and the existing `tool_read_roots`.
  Repo-root-relative paths become resolvable and completable from any file in
  the repo. This mirrors the existing `tool_read_roots = {'../'}` mechanism —
  it's the same "reads may reach beyond the write root" philosophy, just always
  including `repo_root` in repo mode.

  The ordered read roots are: **artifact neighborhood first, then repo root,
  then configured `tool_read_roots`**, canonicalized and de-duplicated. For a
  relative read path, resolve against each root in that order and select the
  first existing candidate; this makes a collision deterministic (the local
  neighborhood wins). `.` and other default paths therefore keep their current
  local meaning. An absolute path is accepted only when its real path is within
  one of the ordered roots. A relative path with no existing candidate is an
  error for read tools; writes retain today's missing-leaf behavior against the
  single write root. Every accepted candidate and every containing root is
  symlink-canonicalized before the containment check, preserving the escape
  guard.

  This lookup applies uniformly in the dispatcher to every read-kind tool and
  every supported path shape: `read_file`, `ls`, `find`, `grep`, `ack`, custom
  read tools, `path`, `file_path`, `paths`, and injected `default_path`. Both
  chat `tool_loop` and `skill_invoke` derive and pass the same ordered roots;
  write-kind tools (`write_file`, `edit_file`, `propose_edits`) ignore the wider
  set and remain confined to the artifact neighborhood. Tools without path
  fields, such as `chat_history_search`, are unaffected.

- **Completion attaches to all markdown, not just chats.** Wire the neighborhood
  completion (`attach_completion` and a Parley-owned nvim-cmp source) into
  `prep_md`, so every markdown buffer in a repo-mode repo gets neighborhood +
  repo-root completion candidates. Chat buffers keep today's behavior (they
  already call it via `prep_chat`; avoid double-attach).

  Completion enumerates the same ordered read roots and presents root-relative
  candidates in that order. Duplicate display paths are collapsed first-wins,
  matching dispatcher collision precedence. Both Vim `completefunc` and one
  Parley-owned nvim-cmp source consume the same candidate merger; attachment is
  idempotent so `prep_chat -> prep_md` cannot register duplicate sources or
  autocmds. The existing single-root cmp-path adapter is replaced because
  nvim-cmp keys source options by source name: repeating `path` sources would
  silently reuse the first root's options and could not implement this contract.

- **Self-consistency invariant preserved.** #147's property — "what the model is
  told" == "what the dispatcher enforces" — must still hold *per side*: the read
  side advertises and enforces the same widened set; the write side advertises
  and enforces the same narrow root. A completed/suggested path must never be one
  the enforcing side then rejects.

  The model-facing context is derived from the same root-policy value passed to
  the dispatcher and says, in substance: relative reads search the ordered roots
  (listed in precedence order), while relative writes resolve only from the
  listed write root; the first existing read match wins. The formatter is a
  shared pure helper, not a separately maintained restatement in
  `chat_respond`.

Non-goals:
- No change to write confinement.
- No `.parley-neighborhood` marker (option 2 — deferred; see Log).
- No change outside repo mode (global chats / non-repo cwd keep own-folder
  behavior).

## Done when

- In a `.parley` repo, editing a non-chat markdown file (e.g. under `data/`)
  offers repo-root-relative path completion candidates (e.g. `atlas/index.md`,
  `data/career/2026/…`) alongside neighborhood-relative ones.
- A read-tool call (`read_file`) from such a buffer resolves a repo-root-relative
  path successfully; the same path used in a write-tool call is still rejected
  as outside the write root (write-narrow preserved).
- When the same relative read path exists under both the artifact neighborhood
  and repo root, the neighborhood copy wins; completion shows the relative path
  once.
- Chat buffers retain existing behavior (no regression, no double-attach).
- Outside repo mode, behavior is unchanged: global chats retain their existing
  own-folder completion, while ordinary non-chat Markdown receives no new
  Parley completion/source/autocmd attachment.
- Atlas `infra/repo_mode.md` "Reference neighborhood (#147)" section updated to
  document the read-wide/write-narrow split and the all-markdown completion attach.
- Unit tests cover: ordered read-set includes repo_root in repo mode; relative
  lookup across roots; collision precedence; missing reads; absolute paths and
  symlink escapes; `path`/`file_path`/`paths`/`default_path`; write root excludes
  repo root; completion de-duplicates in resolver order; completion attaches
  once on `prep_md`; chat and `skill_invoke` wiring; model guidance matches the
  shared policy; non-repo-mode unaffected.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.50 impl=0.60
item: lua-neovim design=0.50 impl=0.60
item: skill-or-dispatcher design=0.20 impl=0.20
item: cross-cutting-refactor design=0.20 impl=0.20
item: atlas-docs design=0.04 impl=0.08
item: milestone-review design=0.04 impl=0.20
design-buffer: 0.15
total: 3.58
```

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md`
against `baseline-v3.1.md`. Method A only. The spec and durable plan resolve the
lookup-order decisions, so the ×0.2 spec-quality discount and +15% design buffer
apply; implementation values use v3.1's 40% scaling. Calibration is currently
marked stale by `sdlc estimate-source`, so treat this as provisional evidence for
the next recalibration rather than a timeless constant.

## Plan

- [x] Read-set: teach `neighborhood` to return the widened read/completion root
      set (per-artifact ∪ `repo_root`-in-repo-mode ∪ `tool_read_roots`), leaving
      `derive_for_path` (the write/primary root) intact.
- [x] Dispatcher: ordered read-tool lookup consumes the widened read set for
      every supported path shape and read-kind tool;
      write tools keep the narrow root. Update the payload guidance line
      through a shared policy formatter to reflect lookup precedence and the
      read/write split.
- [x] Completion: attach the policy-backed Parley completion source in
      `prep_md` for repo-mode markdown; preserve the existing `prep_chat`
      attachment for global chats; guard against double-attach.
- [x] Tests: read-set includes/excludes repo_root correctly; write-narrow
      rejection holds; `prep_md` attaches; non-repo-mode unchanged.
- [x] Atlas: update `infra/repo_mode.md` #147 section + `providers/tool_use.md`
      cwd-scope note for the read-wide/write-narrow split.

## Log

### 2026-07-11 — implementation
- 2026-07-11: addressed final FIX-THEN-SHIP review — chat/tool-loop and skill invocation now prove repo-root-only reads from ordinary nested Markdown; the chat regression proves an identical relative write remains in the nested neighborhood and does not overwrite the repo-root candidate (`ARCH-PURPOSE`). Focused provider/tool-use and skill-system suites passed; stale dispatcher annotations now describe the root-policy API.
- 2026-07-11: closed — Telemetry unavailable for the SDLC-created worktree, so no actual was guessed; focused provider/tool-use and skill-system suites passed; git diff --check passed; make -f Makefile.parley test JOBS=1 passed with lint 0 warnings/errors across 244 files and all unit/integration/architecture specs green; completion now filters through authoritative read enforcement with escaping/dangling collision parity tests and complete traceability; review verdict: FIX-THEN-SHIP

Implemented one ordered root policy consumed by dispatcher enforcement, model
guidance, chat recursion, skill invocation, Vim completion, and a dedicated
nvim-cmp source (`ARCH-DRY`, `ARCH-PURPOSE`). Pure ordering/merging/formatting
stays in `neighborhood`, with filesystem and Neovim work at thin adapters
(`ARCH-PURE`). Verification: `make -f Makefile.parley test-spec
SPEC=providers/tool_use`, `SPEC=skills/skill-system`, `git diff --check`, and
full `make -f Makefile.parley test` passed after the final message-context seam
update.

### 2026-07-10

Created from a brain-side design chat. Decision: **option 1
(read-wide/write-narrow)**, scoped to **all markdown files in repo mode** (not
just repo-backed artifact dirs).

- The self-consistency subtlety that shaped the design: #147 fuses completion +
  tool resolution under one root; a completion-only escape hatch would break that
  (suggest a path the enforcer rejects). Fix is to split the root into a **read
  set** (wide) and a **write root** (narrow) and keep each side self-consistent.
- **Option 2 deferred** (`.parley-neighborhood` marker for an explicit
  intermediate scope between repo-root and file-dir): a different axis — it picks
  a different *single primary* root for a subtree, not a read-set widening.
  Reach for it only if repo-root completion proves too noisy and own-folder too
  narrow for some subtree. YAGNI until a concrete case appears; the two layer
  cleanly and don't conflict.
- Motivating artifact: `brain/data/career/2026/xnurta-plan.md` had
  `Reference: ./` resolving to its own folder with no repo-root path reachable.

## Revisions

### 2026-07-10 — specify ordered multi-root resolution

Reason: fresh-context spec review found that authorizing `repo_root` as an
allowed root would not by itself make a bare repo-relative path resolve there;
the existing dispatcher joins relative inputs only to `cwd`.

Delta: defined neighborhood-first ordered lookup, collision and missing-path
behavior, symlink enforcement, completion ordering/de-duplication, exact path
shapes and dispatcher entry points in scope, and shared model-guidance derivation
(`ARCH-PURPOSE`, `ARCH-PURE`, `ARCH-DRY`).

### 2026-07-10 — reconcile the implementation plan and estimate

Reason: the approved spec is now decomposed into a durable TDD plan, and
`start-plan` requires the estimate to use the current calibrated method before
`change-code`.

Delta: added `workshop/plans/000181-repo-root-read-wide-completion-for-all-markdown-plan.md`
and replaced the provisional v2 estimate with the itemized v3.1 derivation.

### 2026-07-10 — replace cmp-path with one policy-backed cmp source

Reason: plan review verified that nvim-cmp retrieves source configuration by
source name, so multiple `path` entries cannot carry different `get_cwd` roots;
cmp-path also does not enforce the required first-root-wins de-duplication.
# Repo-root Read-wide Completion for All Markdown Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let reads and file completion search repo-root paths from every repo-mode Markdown buffer while keeping writes confined to the artifact neighborhood.

**Architecture:** Extend `parley.neighborhood` with one ordered `RootPolicy` value containing a narrow `write_root` and widened `read_roots`; every caller consumes that policy rather than reconstructing roots. Keep filesystem probing in the dispatcher/completion adapters, while root derivation, ordering, de-duplication, and model guidance remain directly testable helpers.

**Tech Stack:** Lua, Neovim APIs, Plenary/Busted, nvim-cmp integration.

---

## Core Concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `RootPolicy` | `lua/parley/neighborhood.lua` | new |
| `CompletionCandidates` | `lua/parley/neighborhood.lua` | new |

**RootPolicy** — immutable data `{ write_root, read_roots }` constructed from
already-canonical absolute roots by pure `build_policy(write_root, roots)`.

- **Relationships:** 1:1 with an artifact path at use time; 1:N from one policy to its ordered read roots. The write root is the existing `derive_for_path` result. Read roots are write root, repo root in repo mode, then configured `tool_read_roots`, canonicalized and de-duplicated first-wins.
- **DRY rationale:** `tool_loop`, `skill_invoke`, completion, and model context currently receive pieces of path policy separately. A shared value prevents enforcement and guidance from reconstructing different root sets (`ARCH-DRY`). Filesystem-dependent canonicalization stays in `policy_for_path`; the pure builder only orders and de-duplicates supplied strings (`ARCH-PURE`).
- **Future extensions:** A subtree marker can change policy construction later without changing dispatcher or completion consumers.

**CompletionCandidates** — ordered root-relative string labels merged from
per-root filesystem results; adapters wrap strings as cmp items only at the UI
boundary.

- **Relationships:** N:1 from per-root match lists to one de-duplicated display list; the earliest root owns a collision.
- **DRY rationale:** Both built-in completion and cmp configuration need the same ordering and collision rule.
- **Future extensions:** Candidate metadata can later expose the owning root or ranking without changing root derivation.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `ReadPathResolver` | `lua/parley/tools/dispatcher.lua` | modified | filesystem existence, realpath, and containment checks |
| `ArtifactRootPolicy` | `lua/parley/neighborhood.lua` | modified | path normalization, buffer name, live config, and chat-root discovery |
| `MarkdownCompletionAttach` | `lua/parley/neighborhood.lua`, `lua/parley/init.lua` | modified | Neovim completefunc/autocmds and nvim-cmp |
| `ToolPolicyWiring` | `lua/parley/tool_loop.lua`, `lua/parley/chat_respond.lua`, `lua/parley/skill_invoke.lua` | modified | chat and skill tool dispatch plus model payload |

**ReadPathResolver** — resolves relative reads by probing each ordered root and accepting the first existing, contained real path; absolute reads must lie within one root. Writes continue through `resolve_path_in_cwd`, including its missing-leaf behavior.

- **Injected into:** `dispatcher.execute_call` through `opts.root_policy`; tests use temporary directories and real symlinks rather than mocking filesystem calls.
- **Future extensions:** Additional read path shapes still enter through the dispatcher's single prelude.

**ArtifactRootPolicy** — thin adapter that canonicalizes configured roots and calls the pure policy builder; `policy_for_buf` adds live buffer/config discovery.

- **Injected into:** tool dispatch, completion attachment, and payload construction.
- **Future extensions:** Buffer-local policy invalidation if repo configuration becomes mutable while a buffer is open.

**MarkdownCompletionAttach** — stores the policy buffer-locally, installs one completefunc/InsertEnter hook, and registers one Parley cmp source backed by the shared candidate merger.

- **Injected into:** repo-mode `prep_md`; `prep_chat` retains the existing call
  for global chats and becomes an idempotent no-op after repo-mode `prep_md`.
- **Future extensions:** Candidate metadata and ranking can widen inside the dedicated source without changing attachment.

**ToolPolicyWiring** — passes one policy to the dispatcher and formats model context from that same value.

- **Injected into:** `tool_loop.process_response`, `skill_invoke.invoke`, `_build_messages`, and `build_messages_from_model`.
- **Future extensions:** Structured provider metadata can replace prose without changing policy semantics.

## Chunk 1: Root Policy and Read Resolution

### Task 1: Derive the ordered root policy

**Files:**
- Modify: `lua/parley/neighborhood.lua`
- Test: `tests/unit/neighborhood_spec.lua`

- [ ] **Step 1: Write failing pure policy-builder tests**

Test only `build_policy(write_root, roots)`: write root is retained, root order is
stable, duplicate/blank roots are removed first-wins, and inputs are not mutated.

- [ ] **Step 2: Write failing filesystem-adapter tests**

Add `policy_for_path(path, config, chat_roots)` cases proving:

```lua
assert.same({
    write_root = "/repo/data/career",
    read_roots = { "/repo/data/career", "/repo", "/repo-sibling" },
}, neighborhood.policy_for_path(
    "/repo/data/career/note.md",
    { repo_root = "/repo", tool_read_roots = { "/repo", "../../../repo-sibling" } },
    {}
))
```

Also cover repo-backed artifacts (write root and repo root collapse to one),
non-repo mode, invalid paths, and absolute/`~`/relative configured roots.

- [ ] **Step 3: Run the focused spec and verify RED**

Run: `make test-spec SPEC=neighborhood`

Expected: non-zero exit with `attempt to call field 'build_policy' (a nil value)`
from the named policy test.

- [ ] **Step 4: Implement the pure policy builder**

Keep `derive_for_path` unchanged as the narrow source. Add a pure constructor:

```lua
function M.build_policy(write_root, ordered_roots)
    local seen, read_roots = {}, {}
    for _, root in ipairs(ordered_roots or {}) do
        if type(root) == "string" and root ~= "" and not seen[root] then
            seen[root] = true
            read_roots[#read_roots + 1] = root
        end
    end
    return { write_root = write_root, read_roots = read_roots }
end
```

Expected implementation is the `build_policy` function above only.

- [ ] **Step 5: Implement shared canonical policy construction**

Add `canonical_roots(write_root, repo_root, configured_roots) -> string[]`.
It emits candidates strictly as `write_root`, then `repo_root` when nonblank,
then configured roots in list order. Absolute roots normalize directly; `~/x`
expands before normalization; relative roots join to `write_root`. Each uses
`fs_realpath` when it exists and otherwise the normalized absolute path. The
helper returns canonical candidates without de-duplication; `build_policy`
performs the one pure first-wins fold.

Export `policy_from_roots(write_root, repo_root, configured_roots) -> RootPolicy`
as the only public canonicalization entry point; it calls private
`canonical_roots` and then `build_policy`. Both `policy_for_path` and the
temporary dispatcher adapter must call this API, so dispatcher never reaches a
private helper or duplicates root normalization.

- [ ] **Step 6: Implement the artifact adapter**

Add:

```lua
function M.policy_for_path(path, config, chat_roots)
    local write_root, err = M.derive_for_path(path, config, chat_roots)
    if not write_root then return nil, err end
    return M.policy_from_roots(write_root, config and config.repo_root,
        config and config.tool_read_roots)
end
```

Add `policy_for_buf(buf)` in a separate edit as the thin live-state wrapper and
keep `for_buf(buf)` returning only `write_root` until Chunk 2 migration.

- [ ] **Step 7: Run focused tests and verify GREEN**

Run: `make test-spec SPEC=neighborhood`

Expected: exit 0 with zero failed assertions in `tests/unit/neighborhood_spec.lua`.

- [ ] **Step 8: Commit the policy core**

```bash
git add lua/parley/neighborhood.lua tests/unit/neighborhood_spec.lua
git commit -m "#181: derive ordered neighborhood root policy"
```

### Task 2: Resolve read paths across ordered roots

**Files:**
- Modify: `lua/parley/tools/dispatcher.lua`
- Test: `tests/unit/tools_dispatcher_spec.lua`

- [ ] **Step 1: Write failing relative lookup and collision tests**

Add `resolve_read_path(path, read_roots)` tests for:

- a bare `atlas/index.md` absent under neighborhood but present under repo root;
- the same relative path under both roots (neighborhood wins);

- [ ] **Step 2: Write failing missing/absolute/symlink tests**

Add separate cases for missing relative reads, absolute reads inside/outside the
set, a symlink escaping every root, and a symlink resolving into another allowed
root.

- [ ] **Step 3: Run dispatcher tests and verify RED**

Run: `make test-spec SPEC=providers/tool_use`

Expected: non-zero exit with `attempt to call field 'resolve_read_path' (a nil value)`
from the new resolver test.

- [ ] **Step 4: Implement the read-only resolver**

Add `resolve_read_path(path, read_roots) -> abs_path|nil, err` beside
`resolve_path_in_cwd`. For relative input, loop roots in order, join and
`fs_realpath` each candidate, and return the first existing candidate whose real
path is contained by any canonical root. For absolute input, require
`fs_realpath(path)` and validate it against the full set. If no relative
candidate exists, return `nil, "read path not found in configured roots: " ..
path`. Preserve `resolve_path_in_cwd` unchanged for writes/new files.

- [ ] **Step 5: Add and test the legacy option adapter**

`policy_from_opts(opts)` must transform legacy `{ cwd, read_roots }` via
`neighborhood.policy_from_roots(cwd, nil, read_roots)`: cwd first,
each relative read root resolved against cwd, canonical first-wins order. Test
`cwd=/repo/data` plus `read_roots={"../", "/repo"}` yields one `/repo/data`
then one `/repo` and resolves `atlas/index.md` from `/repo`.

- [ ] **Step 6: Migrate scalar dispatcher fields**

Change `execute_call` to accept `opts.root_policy`. Route read `path` and
`file_path` through `resolve_read_path`; route write scalars through
`resolve_path_in_cwd(policy.write_root)`.

- [ ] **Step 7: Migrate arrays and defaults**


codex
The core policy wiring is present and the security-sensitive first-existing/symlink cases are explicitly tested. I’m now checking edge semantics around repo membership, completion attachment, and legacy dispatcher compatibility, then I’ll validate with the suite.
exec
/bin/zsh -lc 'git diff --check 7719c33ff31ae977796b1032c4bb64f1693b3fc1..HEAD && make -f Makefile.parley test JOBS=1' in /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown
 exited 130 in 77304ms:
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
PASS: tests/unit/anthropic_tool_encode_spec.lua
PASS: tests/unit/arch_helper_spec.lua
PASS: tests/unit/artifact_ref_spec.lua
PASS: tests/unit/buffer_edit_spec.lua
PASS: tests/unit/build_messages_spec.lua
PASS: tests/unit/chat_dirs_spec.lua
PASS: tests/unit/chat_finder_logic_spec.lua
PASS: tests/unit/chat_parser_section_lines_spec.lua
PASS: tests/unit/chat_parser_tools_spec.lua
PASS: tests/unit/chat_slug_resolve_spec.lua
PASS: tests/unit/chat_slug_spec.lua
PASS: tests/unit/cliproxy_config_spec.lua
PASS: tests/unit/config_tools_spec.lua
PASS: tests/unit/custom_prompts_spec.lua
PASS: tests/unit/define_spec.lua
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
PASS: tests/unit/file_tracker_spec.lua
PASS: tests/unit/finder_sticky_spec.lua
PASS: tests/unit/float_picker_spec.lua
PASS: tests/unit/get_week_number_spec.lua
PASS: tests/unit/helper_io_spec.lua
PASS: tests/unit/helper_spec.lua
PASS: tests/unit/highlighter_spec.lua
PASS: tests/unit/inline_branch_spec.lua
PASS: tests/unit/issue_finder_spec.lua
PASS: tests/unit/issue_vocabulary_spec.lua
PASS: tests/unit/issues_spec.lua
PASS: tests/unit/keybindings_spec.lua
PASS: tests/unit/log_emit_spec.lua
PASS: tests/unit/logger_spec.lua
PASS: tests/unit/markdown_draft_block_spec.lua
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
PASS: tests/integration/chat_lease_spec.lua
PASS: tests/integration/chat_move_spec.lua
PASS: tests/integration/chat_respond_spec.lua
PASS: tests/integration/cliproxy_auth_login_spec.lua
PASS: tests/integration/cliproxy_caller_teardown_spec.lua
PASS: tests/integration/cliproxy_command_spec.lua
===FAIL: tests/integration/cliproxy_dispatch_spec.lua===
  Scheduling: tests/integration/cliproxy_dispatch_spec.lua

  ========================================
  Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/integration/cliproxy_dispatch_spec.lua
  Error detected while processing command line:
  [31mFail[0m    ||    managed cliproxy dispatch (e2e) aborts the dispatch (no hang) when the managed proxy is foreign
              ...ll-markdown/tests/integration/cliproxy_dispatch_spec.lua:104: Expected to be truthy, but value was:
              (nil)

              stack traceback:
                  ...ll-markdown/tests/integration/cliproxy_dispatch_spec.lua:104: in function <...ll-markdown/tests/integration/cliproxy_dispatch_spec.lua:96>

  Parley.nvim: pre_query abort [cliproxyapi]: cliproxy: process exited (code 1) right after spawn — check the binary/config
  [31mFail[0m    ||    managed cliproxy dispatch (e2e) proceeds to the query when the managed proxy is healthy
              ...ll-markdown/tests/integration/cliproxy_dispatch_spec.lua:113: Expected objects to be the same.
              Passed in:
              (boolean) false
              Expected:
              (boolean) true

              stack traceback:
                  ...ll-markdown/tests/integration/cliproxy_dispatch_spec.lua:113: in function <...ll-markdown/tests/integration/cliproxy_dispatch_spec.lua:107>

  Parley.nvim: pre_query abort [cliproxyapi]: cliproxy: process exited (code 1) right after spawn — check the binary/config
  [31mFail[0m    ||    managed cliproxy dispatch (e2e) cold-starts then proceeds, and after stop re-spawns (transient stop)
              ...ll-markdown/tests/integration/cliproxy_dispatch_spec.lua:124: Expected objects to be the same.
              Passed in:
              (boolean) false
              Expected:
              (boolean) true

              stack traceback:
                  ...ll-markdown/tests/integration/cliproxy_dispatch_spec.lua:124: in function <...ll-markdown/tests/integration/cliproxy_dispatch_spec.lua:117>


  [32mSuccess: [0m    0
  [31mFailed : [0m    3
  [31mErrors : [0m    0
  ========================================
  Tests Failed. Exit: 1
  Parley.nvim: pre_query abort [cliproxyapi]: cliproxy: process exited (code 1) right after spawn — check the binary/config
===FAIL: tests/integration/cliproxy_download_spec.lua===
  Scheduling: tests/integration/cliproxy_download_spec.lua

  ========================================
  Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/integration/cliproxy_download_spec.lua
  [31mFail[0m    ||    cliproxy auto_download downloads, checksum-verifies, and extracts the binary
              ...ll-markdown/tests/integration/cliproxy_download_spec.lua:80: download failed: download failed (http://127.0.0.1:0/v9.9.9/CLIProxyAPI_9.9.9_darwin_aarch64.tar.gz): curl: (7) Failed to connect to 127.0.0.1 port 0 after 0 ms: Couldn't connect to server

              Expected to be truthy, but value was:
              (nil)

              stack traceback:
                  ...ll-markdown/tests/integration/cliproxy_download_spec.lua:80: in function <...ll-markdown/tests/integration/cliproxy_download_spec.lua:78>

  [32mSuccess[0m    ||    cliproxy auto_download makes the downloaded binary discoverable
  [31mFail[0m    ||    cliproxy auto_download REFUSES to install on a checksum mismatch
              ...ll-markdown/tests/integration/cliproxy_download_spec.lua:99: Expected to be truthy, but value was:
              (nil)

              stack traceback:
                  ...ll-markdown/tests/integration/cliproxy_download_spec.lua:99: in function <...ll-markdown/tests/integration/cliproxy_download_spec.lua:94>


  [32mSuccess: [0m    1
  [31mFailed : [0m    2
  [31mErrors : [0m    0
  ========================================
  Tests Failed. Exit: 1

=== Failed integration test files ===
tests/integration/cliproxy_dispatch_spec.lua
tests/integration/cliproxy_download_spec.lua
make: *** [test-integration] Error 1

codex
All changed unit tests passed and lint/diff checks are clean. The full suite hit unrelated managed-cliproxy environment failures (local proxy/download fixtures could not start); I’m isolating the mapped neighborhood, provider/tool-use, and skill-system suites so the verdict distinguishes product failures from harness infrastructure.
exec
/bin/zsh -lc 'make -f Makefile.parley test-spec SPEC=neighborhood && make -f Makefile.parley test-spec SPEC=providers/tool_use && make -f Makefile.parley test-spec SPEC=skills/skill-system' in /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown
 exited 2 in 0ms:
No tests mapped for spec: neighborhood
Update atlas/traceability.yaml to add mappings.
make: *** [test-spec] Error 1

exec
/bin/zsh -lc 'make -f Makefile.parley test-spec SPEC=providers/tool_use && make -f Makefile.parley test-spec SPEC=skills/skill-system' in /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown
 succeeded in 8061ms:
Running tests/integration/neighborhood_completion_spec.lua
Scheduling: tests/integration/neighborhood_completion_spec.lua

========================================
Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/integration/neighborhood_completion_spec.lua
[32mSuccess[0m    ||    neighborhood completion attaches once to repo markdown and leaves non-repo markdown untouched
[32mSuccess[0m    ||    neighborhood completion attaches a chat-local completefunc rooted at the neighborhood
[32mSuccess[0m    ||    neighborhood completion finds the start column for the current path token
[32mSuccess[0m    ||    neighborhood completion omits escaping and dangling authoritative candidates without fallback
[32mSuccess[0m    ||    neighborhood completion configures the policy-backed Parley completion source

[32mSuccess: [0m    5
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
Running tests/unit/anthropic_tool_decode_spec.lua
Scheduling: tests/unit/anthropic_tool_decode_spec.lua

========================================
Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/unit/anthropic_tool_decode_spec.lua
[32mSuccess[0m    ||    anthropic.decode_tool_calls_from_stream (synthetic fixtures) returns empty list when the stream has no tool_use blocks
[32mSuccess[0m    ||    anthropic.decode_tool_calls_from_stream (synthetic fixtures) decodes a single tool_use with all input streamed in one delta
[32mSuccess[0m    ||    anthropic.decode_tool_calls_from_stream (synthetic fixtures) decodes a single tool_use with input streamed across multiple deltas
[32mSuccess[0m    ||    anthropic.decode_tool_calls_from_stream (synthetic fixtures) decodes multiple tool_use blocks in one message, preserving order
[32mSuccess[0m    ||    anthropic.decode_tool_calls_from_stream (synthetic fixtures) handles interleaved text + tool_use (assistant explains then calls)
[32mSuccess[0m    ||    anthropic.decode_tool_calls_from_stream (synthetic fixtures) handles a tool_use with empty input (partial_json is '{}')
[32mSuccess[0m    ||    anthropic.decode_tool_calls_from_stream (synthetic fixtures) handles a tool_use with NO input deltas at all (malformed stream)
[32mSuccess[0m    ||    anthropic.decode_tool_calls_from_stream (synthetic fixtures) IGNORES server_tool_use blocks (web_search is resolved server-side)
[32mSuccess[0m    ||    anthropic.decode_tool_calls_from_stream (synthetic fixtures) IGNORES thinking blocks
[32mSuccess[0m    ||    anthropic.decode_tool_calls_from_stream (synthetic fixtures) coexists with server-side and client-side tools in same message
[32mSuccess[0m    ||    anthropic.decode_tool_calls_from_stream (synthetic fixtures) returns empty list for malformed/empty raw response
[32mSuccess[0m    ||    anthropic.decode_tool_calls_from_stream (synthetic fixtures) tolerates missing `index` field by defaulting to 0
[32mSuccess[0m    ||    anthropic.decode_tool_calls_from_stream (real fixture) real fixture exists (skip if user hasn't run capture script)
[32mSuccess[0m    ||    anthropic.decode_tool_calls_from_stream (real fixture) decodes the captured stream to exactly one ToolCall
[32mSuccess[0m    ||    anthropic.decode_tool_calls_from_stream (real fixture) the ToolCall has a toolu_* id
[32mSuccess[0m    ||    anthropic.decode_tool_calls_from_stream (real fixture) the ToolCall name is read_file (the prompt was deliberate)
[32mSuccess[0m    ||    anthropic.decode_tool_calls_from_stream (real fixture) the ToolCall input has a path field (assembled from partial_json chunks)
[32mSuccess[0m    ||    anthropic.decode_tool_calls_from_stream (real fixture) real captured input parses to a proper table (not a string of JSON)
[32mSuccess[0m    ||    anthropic.decode_tool_calls_from_stream (real fixture) trailing whitespace on data lines does not break decoding

[32mSuccess: [0m    19
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
Running tests/unit/anthropic_tool_encode_spec.lua
Scheduling: tests/unit/anthropic_tool_encode_spec.lua

========================================
Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/unit/anthropic_tool_encode_spec.lua
[32mSuccess[0m    ||    providers.anthropic_encode_tools converts a single ToolDefinition to the Anthropic payload shape
[32mSuccess[0m    ||    providers.anthropic_encode_tools converts multiple definitions preserving input order
[32mSuccess[0m    ||    providers.anthropic_encode_tools returns an empty table on empty input
[32mSuccess[0m    ||    providers.anthropic_encode_tools returns an empty table on nil input
[32mSuccess[0m    ||    providers.anthropic_encode_tools drops handler field from output (not sent to API)
[32mSuccess[0m    ||    providers.anthropic_encode_tools drops kind and needs_backup metadata (dispatcher-internal only)

[32mSuccess: [0m    6
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
Running tests/unit/build_messages_spec.lua
Scheduling: tests/unit/build_messages_spec.lua

========================================
Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/unit/build_messages_spec.lua
[32mSuccess[0m    ||    _build_messages: basic structure single exchange with no answer produces system + user message
[32mSuccess[0m    ||    _build_messages: basic structure adds neighborhood root context for tool-enabled agents
[32mSuccess[0m    ||    _build_messages: basic structure single exchange with answer produces system + user + assistant
[32mSuccess[0m    ||    _build_messages: memory truncation old exchanges beyond max_full_exchanges become placeholder text
[32mSuccess[0m    ||    _build_messages: summary usage when exchange has summary, uses summary instead of full answer
[32mSuccess[0m    ||    _build_messages: file references file reference injects system message with file content before user message
[32mSuccess[0m    ||    _build_messages: file references multiple file references accumulate file_content
[32mSuccess[0m    ||    _build_messages: file references file reference with directory pattern calls process_directory_pattern
[32mSuccess[0m    ||    _build_messages: Anthropic cache_control system prompt gets cache_control for anthropic provider
[32mSuccess[0m    ||    _build_messages: Anthropic cache_control system prompt does NOT get cache_control for openai provider
[32mSuccess[0m    ||    _build_messages: header config overrides config_max_full_exchanges header overrides config value
[32mSuccess[0m    ||    _build_messages: raw request mode when question contains typed YAML request fence, stores raw_payload
[32mSuccess[0m    ||    _build_messages: raw request mode ignores plain YAML fences without type:request metadata
[32mSuccess[0m    ||    _build_messages: raw request mode parses typed request fence regardless of raw_mode log toggles
[32mSuccess[0m    ||    _build_messages: raw request mode stores complete payload structure from typed request fence
[32mSuccess[0m    ||    _build_messages: raw request mode handles invalid YAML in typed request fence gracefully
[32mSuccess[0m    ||    _build_messages: raw request mode ignores response type fences and only matches request type
[32mSuccess[0m    ||    _build_messages: raw request mode builds normal messages when question has no typed fence
[32mSuccess[0m    ||    _build_messages: range filtering only includes exchanges where question.line_start >= start_index
[32mSuccess[0m    ||    _build_messages: range filtering only includes answers where answer.line_start <= end_index
[32mSuccess[0m    ||    _build_messages: durable definition footnotes strips managed definition footnote footers from user and assistant content
[32mSuccess[0m    ||    _build_messages: durable definition footnotes preserves ordinary horizontal-rule content that is not a managed footer
[32mSuccess[0m    ||    _build_messages: durable definition footnotes keeps earlier horizontal-rule content and strips only the final managed footer
[32mSuccess[0m    ||    _build_messages: whitespace trimming trims leading and trailing whitespace from all message content
[32mSuccess[0m    ||    _build_messages: system_prompt+ header appends appends system_prompt+ to selected/default system prompt
[32mSuccess[0m    ||    _build_messages: system_prompt+ header appends uses system_prompt override then appends system_prompt+ values
[32mSuccess[0m    ||    _build_messages: system_prompt+ header appends supports legacy role and role+ aliases
[32mSuccess[0m    ||    _build_messages: file references with preserved answer when exchange has file references, answer is summarized even if should_preserve
[32mSuccess[0m    ||    _build_messages: remote file references uses resolved_remote_content for URL references
[32mSuccess[0m    ||    _build_messages: remote file references uses cached-miss placeholder for unresolved remote URL references
[32mSuccess[0m    ||    _build_messages: content_blocks with tool round-trips emits a single flat assistant message when content_blocks has only text
[32mSuccess[0m    ||    _build_messages: content_blocks with tool round-trips emits assistant-with-content-blocks + user-with-tool_result for a single round
[32mSuccess[0m    ||    _build_messages: content_blocks with tool round-trips emits multiple rounds of tool_use → tool_result correctly
[32mSuccess[0m    ||    _build_messages: content_blocks with tool round-trips emits is_error=true tool_results correctly
[32mSuccess[0m    ||    _build_messages: content_blocks with tool round-trips includes the CURRENT exchange's partial answer when it has tool blocks (tool-loop recursion)
[32mSuccess[0m    ||    _build_messages: content_blocks with tool round-trips does NOT include the current exchange's answer when it has NO tool blocks (vanilla resubmit)
[32mSuccess[0m    ||    _build_messages: synthetic_system_prompt anthropic: emits user-with-content-blocks + assistant ack instead of system
[32mSuccess[0m    ||    _build_messages: synthetic_system_prompt openai (no cache_control): plain string user content + assistant ack
[32mSuccess[0m    ||    _build_messages: synthetic_system_prompt custom ack overrides the default
[32mSuccess[0m    ||    _build_messages: synthetic_system_prompt flag = false produces the default single system message
[32mSuccess[0m    ||    _emit_content_blocks_as_messages: dangling tool_use invariant (#155) synthesizes an error result for a single dangling tool_use
[32mSuccess[0m    ||    _emit_content_blocks_as_messages: dangling tool_use invariant (#155) keeps trailing text in the assistant run and still synthesizes (dangling-then-text)
[32mSuccess[0m    ||    _emit_content_blocks_as_messages: dangling tool_use invariant (#155) synthesizes only for the dangling call in a partial parallel resolution
[32mSuccess[0m    ||    _emit_content_blocks_as_messages: dangling tool_use invariant (#155) leaves a matched single round unchanged (no synthetic added)
[32mSuccess[0m    ||    _emit_content_blocks_as_messages: dangling tool_use invariant (#155) emits a single assistant message for text-only blocks
[32mSuccess[0m    ||    _emit_content_blocks_as_messages: dangling tool_use invariant (#155) coerces empty tool input to a JSON object, not an array
[32mSuccess[0m    ||    _build_messages: dangling tool_use synthesized on the parse path (#155) emits a synthetic error tool_result for an unmatched tool_use in a past exchange
[32mSuccess[0m    ||    build_messages_from_model: dangling tool_use synthesized on the live path (#155) emits a synthetic error tool_result for a dangling tool_use read from the buffer
[32mSuccess[0m    ||    build_messages_from_model: durable definition footnotes strips managed footnote footers from live question and answer blocks
[32mSuccess[0m    ||    _emit_content_blocks_as_messages: orphan tool_result dropped (#156) drops an orphan-only tool_result (no preceding tool_use)
[32mSuccess[0m    ||    _emit_content_blocks_as_messages: orphan tool_result dropped (#156) drops an orphan tool_result after an unrelated matched round
[32mSuccess[0m    ||    _emit_content_blocks_as_messages: orphan tool_result dropped (#156) drops an orphan interleaved before a real result, keeps the real one
[32mSuccess[0m    ||    _emit_content_blocks_as_messages: orphan tool_result dropped (#156) keeps a matched result when text sits between the call and the result
[32mSuccess[0m    ||    _emit_content_blocks_as_messages: orphan tool_result dropped (#156) drops a duplicate tool_result (second result for the same id)
[32mSuccess[0m    ||    _emit_content_blocks_as_messages: orphan tool_result dropped (#156) dangling tool_use + orphan result: synthetic for the dangling, drop the orphan
[32mSuccess[0m    ||    _emit_content_blocks_as_messages: orphan tool_result dropped (#156) does not split surrounding text into consecutive assistant turns [text, orphan, text]

[32mSuccess: [0m    56
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
Running tests/unit/config_tools_spec.lua
Scheduling: tests/unit/config_tools_spec.lua

========================================
Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/unit/config_tools_spec.lua
[32mSuccess[0m    ||    per-agent tools config accepts an agent with a valid tools list
[32mSuccess[0m    ||    per-agent tools config raises on unknown tool name, mentioning the offending name
[32mSuccess[0m    ||    per-agent tools config backward compatible: agent without tools field works unchanged
[32mSuccess[0m    ||    per-agent tools config single-sources the max_tool_iterations default in parley.defaults (= 42)
[32mSuccess[0m    ||    per-agent tools config defaults max_tool_iterations to 42 when tools set but override absent
[32mSuccess[0m    ||    per-agent tools config defaults tool_result_max_bytes to 102400 when tools set but override absent
[32mSuccess[0m    ||    per-agent tools config respects explicit max_tool_iterations override
[32mSuccess[0m    ||    per-agent tools config respects explicit tool_result_max_bytes override
[32mSuccess[0m    ||    default ToolSonnet ships in the default config with the @all tool set
[32mSuccess[0m    ||    default ToolSonnet has default loop limits applied
[32mSuccess[0m    ||    default ToolSonnet every tool-enabled default agent pins to EXPECTED_DEFAULT_TOOLS
[32mSuccess[0m    ||    get_agent forwards client-side tool config (full wiring chain) get_agent(ToolSonnet) carries the tools field from M.agents
[32mSuccess[0m    ||    get_agent forwards client-side tool config (full wiring chain) get_agent(ToolSonnet) forwards max_tool_iterations and tool_result_max_bytes
[32mSuccess[0m    ||    get_agent forwards client-side tool config (full wiring chain) get_agent on a vanilla agent has nil tools (no defaults leak)
[32mSuccess[0m    ||    get_agent forwards client-side tool config (full wiring chain) get_agent_info(headers, get_agent('ToolSonnet')).tools carries the @all sentinel
[32mSuccess[0m    ||    get_agent forwards client-side tool config (full wiring chain) full wiring chain: ToolSonnet request payload resolves @all to the full read+write tool set
[32mSuccess[0m    ||    get_agent forwards client-side tool config (full wiring chain) full wiring chain + web_search: @all client tools APPEND to web_search/web_fetch
[32mSuccess[0m    ||    get_agent forwards synthetic_system_prompt config forwards both fields when present on the agent record
[32mSuccess[0m    ||    get_agent forwards synthetic_system_prompt config forwards as nil when the agent has no synthetic config
[32mSuccess[0m    ||    get_agent forwards synthetic_system_prompt config flag survives the full wiring chain into agent_info
[32mSuccess[0m    ||    new config prefix + shortcut defaults defines chat_tool_use_prefix and chat_tool_result_prefix
[32mSuccess[0m    ||    new config prefix + shortcut defaults defines chat_shortcut_toggle_tool_folds

[32mSuccess: [0m    22
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
Running tests/unit/neighborhood_spec.lua
Scheduling: tests/unit/neighborhood_spec.lua

========================================
Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/unit/neighborhood_spec.lua
[32mSuccess[0m    ||    neighborhood.derive_for_path returns repo root for repo-moded chat artifacts
[32mSuccess[0m    ||    neighborhood.derive_for_path returns repo root for every repo-local artifact directory
[32mSuccess[0m    ||    neighborhood.derive_for_path returns sibling repo root for super-repo chat roots
[32mSuccess[0m    ||    neighborhood.derive_for_path returns the artifact folder for global chat artifacts
[32mSuccess[0m    ||    neighborhood.derive_for_path returns the artifact folder for non-chat content artifacts
[32mSuccess[0m    ||    neighborhood.derive_for_path rejects blank artifact paths
[32mSuccess[0m    ||    neighborhood root policy (#181) builds a stable first-wins policy without mutating input
[32mSuccess[0m    ||    neighborhood root policy (#181) orders neighborhood, repo, and configured roots first-wins
[32mSuccess[0m    ||    neighborhood root policy (#181) does not add a repo root outside repo mode
[32mSuccess[0m    ||    neighborhood root policy (#181) keeps a global chat narrow while repo mode is active
[32mSuccess[0m    ||    neighborhood root policy (#181) canonicalizes symlink aliases before de-duplicating roots
[32mSuccess[0m    ||    neighborhood root policy (#181) formats guidance from the policy
[32mSuccess[0m    ||    neighborhood root policy (#181) merges string candidates first-root-first without mutating inputs

[32mSuccess: [0m    13
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
Running tests/unit/parley_harness_golden_spec.lua
Scheduling: tests/unit/parley_harness_golden_spec.lua

========================================
Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/unit/parley_harness_golden_spec.lua
[32mSuccess[0m    ||    parley_harness golden round-trip payload for single-user matches golden
[32mSuccess[0m    ||    parley_harness golden round-trip payload for simple-chat matches golden
[32mSuccess[0m    ||    parley_harness golden round-trip payload for one-round-tool-use matches golden
[32mSuccess[0m    ||    parley_harness golden round-trip payload for two-round-tool-use matches golden
[32mSuccess[0m    ||    parley_harness golden round-trip payload for mixed-text-and-tools matches golden
[32mSuccess[0m    ||    parley_harness golden round-trip payload for tool-error matches golden
[32mSuccess[0m    ||    parley_harness golden round-trip payload for dynamic-fence-stress matches golden

[32mSuccess: [0m    7
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
Running tests/unit/tool_loop_spec.lua
Scheduling: tests/unit/tool_loop_spec.lua

========================================
Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/unit/tool_loop_spec.lua
[32mSuccess[0m    ||    tool_loop: per-buffer state get_iter returns 0 for a fresh buffer
[32mSuccess[0m    ||    tool_loop: per-buffer state increment_iter bumps the counter per buffer
[32mSuccess[0m    ||    tool_loop: per-buffer state state is independent across buffers
[32mSuccess[0m    ||    tool_loop: per-buffer state reset clears iteration state for a buffer
[32mSuccess[0m    ||    tool_loop.process_response: no tool_use blocks returns 'done' when the stream has no tool_use
[32mSuccess[0m    ||    tool_loop.process_response: no tool_use blocks returns 'done' on empty raw response
[32mSuccess[0m    ||    tool_loop.process_response: no tool_use blocks resets iteration counter on 'done'
[32mSuccess[0m    ||    tool_loop.process_response: with tool_use writes 🔧: and 📎: blocks to the buffer and returns 'recurse'
[32mSuccess[0m    ||    tool_loop.process_response: with tool_use increments iter counter on recurse
[32mSuccess[0m    ||    tool_loop.process_response: with tool_use stops with 'done' when max_tool_iterations is hit (cap behavior)
[32mSuccess[0m    ||    tool_loop.process_response: with tool_use handles tool execution errors gracefully (cwd-scope rejection)
[32mSuccess[0m    ||    tool_loop.process_response: with tool_use widens reads but not writes from ordinary nested repo Markdown
[32mSuccess[0m    ||    tool_loop.process_response: with tool_use emits 📎: result in dynamic-fence form that survives backticks in file content

[32mSuccess: [0m    13
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
Running tests/unit/tools_builtin_ack_spec.lua
Scheduling: tests/unit/tools_builtin_ack_spec.lua

========================================
Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/unit/tools_builtin_ack_spec.lua
[32mSuccess[0m    ||    ack tool finds matches with structured pattern and path fields
[32mSuccess[0m    ||    ack tool rejects legacy raw command fields
[32mSuccess[0m    ||    ack tool treats command substitution text in the pattern as data
[32mSuccess[0m    ||    ack tool treats dash-leading patterns as data, not options
[32mSuccess[0m    ||    ack tool rejects raw flags escape hatch

[32mSuccess: [0m    5
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
Running tests/unit/tools_builtin_chat_history_search_spec.lua
Scheduling: tests/unit/tools_builtin_chat_history_search_spec.lua

========================================
Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/unit/tools_builtin_chat_history_search_spec.lua
[32mSuccess[0m    ||    chat_history_search tool description is non-empty
[32mSuccess[0m    ||    chat_history_search tool returns error for missing pattern
[32mSuccess[0m    ||    chat_history_search tool finds matches across all chat roots
[32mSuccess[0m    ||    chat_history_search tool rewrites paths to {repo}/<repo-relative> for /workshop/parley roots
[32mSuccess[0m    ||    chat_history_search tool rewrites paths to {label}/<file> for non-repo roots
[32mSuccess[0m    ||    chat_history_search tool returns no-matches sentinel when nothing hits
[32mSuccess[0m    ||    chat_history_search tool respects the glob filter
[32mSuccess[0m    ||    chat_history_search tool is case-insensitive by default
[32mSuccess[0m    ||    chat_history_search tool rejects injection-shaped numeric fields before process launch
[32mSuccess[0m    ||    chat_history_search tool rejects non-integer numeric context and count fields
[32mSuccess[0m    ||    chat_history_search tool accepts zero context and positive max_count

[32mSuccess: [0m    11
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
Running tests/unit/tools_builtin_find_spec.lua
Scheduling: tests/unit/tools_builtin_find_spec.lua

========================================
Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/unit/tools_builtin_find_spec.lua
[32mSuccess[0m    ||    find tool finds files by structured name and type fields
[32mSuccess[0m    ||    find tool does not accept a raw flags escape hatch
[32mSuccess[0m    ||    find tool rejects action and write predicates as unknown structured fields
[32mSuccess[0m    ||    find tool treats command substitution text in name as data

[32mSuccess: [0m    4
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
Running tests/unit/tools_builtin_grep_spec.lua
Scheduling: tests/unit/tools_builtin_grep_spec.lua

========================================
Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/unit/tools_builtin_grep_spec.lua
[32mSuccess[0m    ||    grep tool description advertises available grep version
[32mSuccess[0m    ||    grep tool finds matches with a simple pattern
[32mSuccess[0m    ||    grep tool supports ripgrep glob filter
[32mSuccess[0m    ||    grep tool returns no matches for non-matching pattern
[32mSuccess[0m    ||    grep tool returns error for missing pattern
[32mSuccess[0m    ||    grep tool case insensitive search works
[32mSuccess[0m    ||    grep tool defaults missing path to cwd
[32mSuccess[0m    ||    grep tool rejects shell metacharacters in flags
[32mSuccess[0m    ||    grep tool treats command substitution in the pattern as data
[32mSuccess[0m    ||    grep tool treats dash-leading patterns as data, not options
[32mSuccess[0m    ||    grep tool does not allow command-execution flags through the pattern positional
[32mSuccess[0m    ||    grep tool rejects ripgrep command execution flags
[32mSuccess[0m    ||    grep tool rejects ripgrep arbitrary pattern-file flags
[32mSuccess[0m    ||    grep tool rejects legacy raw command fields

[32mSuccess: [0m    14
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
Running tests/unit/tools_builtin_ls_spec.lua
Scheduling: tests/unit/tools_builtin_ls_spec.lua

========================================
Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/unit/tools_builtin_ls_spec.lua
[32mSuccess[0m    ||    ls tool lists a path with a safe flag array
[32mSuccess[0m    ||    ls tool accepts compact allowlisted short flags
[32mSuccess[0m    ||    ls tool rejects shell metacharacters in flags
[32mSuccess[0m    ||    ls tool rejects pipeline-shaped flag fragments
[32mSuccess[0m    ||    ls tool rejects long flags and value forms
[32mSuccess[0m    ||    ls tool rejects legacy raw command fields

[32mSuccess: [0m    6
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
Running tests/unit/tools_builtin_read_file_spec.lua
Scheduling: tests/unit/tools_builtin_read_file_spec.lua

========================================
Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/unit/tools_builtin_read_file_spec.lua
[32mSuccess[0m    ||    read_file handler: happy path returns content with 1-indexed line numbers
[32mSuccess[0m    ||    read_file handler: happy path returns empty content for an empty file
[32mSuccess[0m    ||    read_file handler: happy path handles a single-line file
[32mSuccess[0m    ||    read_file handler: happy path stamps name field on the result for dispatcher serialization
[32mSuccess[0m    ||    read_file handler: line range respects line_start inclusive
[32mSuccess[0m    ||    read_file handler: line range respects line_end inclusive
[32mSuccess[0m    ||    read_file handler: line range respects both line_start and line_end
[32mSuccess[0m    ||    read_file handler: line range line_start beyond EOF returns empty content (not an error)
[32mSuccess[0m    ||    read_file handler: line range line_start == line_end returns exactly one line
[32mSuccess[0m    ||    read_file handler: error cases returns is_error=true when path is missing
[32mSuccess[0m    ||    read_file handler: error cases returns is_error=true when path is not a string
[32mSuccess[0m    ||    read_file handler: error cases returns is_error=true when file does not exist
[32mSuccess[0m    ||    read_file handler: purity does not mutate input
[32mSuccess[0m    ||    read_file handler: purity returns same output for same input (deterministic)
[32mSuccess[0m    ||    read_file handler: purity does not stamp the id field (dispatcher's job)

[32mSuccess: [0m    15
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
Running tests/unit/tools_builtin_registered_spec.lua
Scheduling: tests/unit/tools_builtin_registered_spec.lua

========================================
Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/unit/tools_builtin_registered_spec.lua
[32mSuccess[0m    ||    register_builtins registers all expected builtin names
[32mSuccess[0m    ||    register_builtins each builtin passes types.validate_definition
[32mSuccess[0m    ||    register_builtins each builtin has a non-empty description
[32mSuccess[0m    ||    register_builtins each builtin has an object-typed input_schema
[32mSuccess[0m    ||    register_builtins each handler returns a well-shaped error ToolResult on empty input
[32mSuccess[0m    ||    register_builtins is idempotent — calling register_builtins twice does not error
[32mSuccess[0m    ||    register_builtins write-type builtins declare kind = 'write'
[32mSuccess[0m    ||    register_builtins write_file declares needs_backup = true (for M5 dispatcher)
[32mSuccess[0m    ||    register_builtins edit_file declares needs_backup = false (delta is in the call)
[32mSuccess[0m    ||    register_builtins read-type builtins declare kind = 'read' (or nil defaulting to read)

[32mSuccess: [0m    10
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
Running tests/unit/tools_dispatcher_spec.lua
Scheduling: tests/unit/tools_dispatcher_spec.lua

========================================
Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/unit/tools_dispatcher_spec.lua
[32mSuccess[0m    ||    resolve_path_in_cwd resolves a relative path inside cwd to an absolute path
[32mSuccess[0m    ||    resolve_path_in_cwd accepts an absolute path that lies inside cwd
[32mSuccess[0m    ||    resolve_path_in_cwd rejects an absolute path outside cwd
[32mSuccess[0m    ||    resolve_path_in_cwd rejects a relative path that escapes cwd via ..
[32mSuccess[0m    ||    resolve_path_in_cwd rejects a nested .. that ultimately escapes cwd
[32mSuccess[0m    ||    resolve_path_in_cwd accepts a nested .. that stays within cwd
[32mSuccess[0m    ||    resolve_path_in_cwd resolves symlinks pointing INSIDE cwd
[32mSuccess[0m    ||    resolve_path_in_cwd REJECTS symlinks whose real path escapes cwd
[32mSuccess[0m    ||    resolve_path_in_cwd accepts a path to a NEW file (parent dir inside cwd, file doesn't exist)
[32mSuccess[0m    ||    resolve_path_in_cwd rejects a new file whose parent dir does not exist
[32mSuccess[0m    ||    resolve_path_in_cwd rejects non-string path
[32mSuccess[0m    ||    resolve_path_in_cwd rejects empty string path
[32mSuccess[0m    ||    resolve_path_in_cwd allowed_roots (#140) accepts a file inside an absolute allowed root
[32mSuccess[0m    ||    resolve_path_in_cwd allowed_roots (#140) accepts a path reached via a relative-to-cwd root (../sibling)
[32mSuccess[0m    ||    resolve_path_in_cwd allowed_roots (#140) rejects a path outside cwd and all configured roots, naming the knob
[32mSuccess[0m    ||    resolve_path_in_cwd allowed_roots (#140) accepts a symlink in cwd whose real path is inside an allowed root
[32mSuccess[0m    ||    resolve_path_in_cwd allowed_roots (#140) rejects a symlink whose real path escapes cwd and all roots
[32mSuccess[0m    ||    resolve_path_in_cwd allowed_roots (#140) empty roots list scopes to cwd but still reports the read-roots hint
[32mSuccess[0m    ||    resolve_read_path ordered roots (#181) falls through to repo root and prefers neighborhood collisions
[32mSuccess[0m    ||    resolve_read_path ordered roots (#181) rejects missing reads instead of synthesizing a leaf
[32mSuccess[0m    ||    resolve_read_path ordered roots (#181) accepts absolute paths inside roots and rejects symlink escapes
[32mSuccess[0m    ||    resolve_read_path ordered roots (#181) rejects an escaping first candidate instead of falling through
[32mSuccess[0m    ||    resolve_read_path ordered roots (#181) rejects a dangling symlink without crashing
[32mSuccess[0m    ||    resolve_read_path ordered roots (#181) enforces an injected root_policy without legacy cwd
[32mSuccess[0m    ||    truncate returns content unchanged when under the byte cap
[32mSuccess[0m    ||    truncate returns content unchanged when exactly at the byte cap
[32mSuccess[0m    ||    truncate truncates with trailing marker when over the cap
[32mSuccess[0m    ||    truncate handles nil content as empty string (no error)
[32mSuccess[0m    ||    truncate handles zero-length content
[32mSuccess[0m    ||    page_lines (#139) returns content unchanged with no footer when it fits
[32mSuccess[0m    ||    page_lines (#139) windows to [offset, offset+limit) and appends a next-page footer
[32mSuccess[0m    ||    page_lines (#139) pages a middle window and points at the next page
[32mSuccess[0m    ||    page_lines (#139) marks end-of-output on the final window (no next page)
[32mSuccess[0m    ||    page_lines (#139) reports an empty window when offset is past the end
[32mSuccess[0m    ||    page_lines (#139) drops a spurious trailing-newline line from the count
[32mSuccess[0m    ||    page_lines (#139) clamps offset/limit to sane minimums
[32mSuccess[0m    ||    execute_call looks up the tool, runs the handler, and stamps id+name
[32mSuccess[0m    ||    execute_call returns is_error on unknown tool name, with name in the message
[32mSuccess[0m    ||    execute_call pcall-guards a raising handler and returns is_error
[32mSuccess[0m    ||    execute_call handles a handler that returns non-table (defensive)
[32mSuccess[0m    ||    execute_call truncates oversized content when max_bytes is provided
[32mSuccess[0m    ||    execute_call stamps id even on unknown-tool errors
[32mSuccess[0m    ||    execute_call stamps id even when handler raises
[32mSuccess[0m    ||    execute_call read tools reach configured read_roots; write tools stay cwd-confined (#140)
[32mSuccess[0m    ||    execute_call a tool with ABSENT kind is treated as read (kind defaults to read) (#140)
[32mSuccess[0m    ||    execute_call canonicalizes every element of a read tool's paths array (#144)
[32mSuccess[0m    ||    execute_call rejects a read tool's paths array when any element escapes (#144)
[32mSuccess[0m    ||    execute_call canonicalizes a read tool's default_path before handler execution (#144)
[32mSuccess[0m    ||    execute_call pages output + strips offset/limit from the handler input (#139)
[32mSuccess[0m    ||    execute_call applies the configured default page_limit when limit is omitted (#139)
[32mSuccess[0m    ||    execute_call clamps a requested limit above the max (#139)
[32mSuccess[0m    ||    execute_call does NOT window a self_paginates tool (read_file-style) (#139)
[32mSuccess[0m    ||    execute_call registry injects offset/limit into read tools, not write/self-paginating (#139)
[32mSuccess[0m    ||    execute_call does NOT window a write tool's multi-line output (#139)

[32mSuccess: [0m    54
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
Running tests/unit/tools_registry_spec.lua
Scheduling: tests/unit/tools_registry_spec.lua

========================================
Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/unit/tools_registry_spec.lua
[32mSuccess[0m    ||    tool registry register accepts and stores a valid definition
[32mSuccess[0m    ||    tool registry register raises on invalid definition (missing name)
[32mSuccess[0m    ||    tool registry register raises on invalid definition (empty name)
[32mSuccess[0m    ||    tool registry register raises on non-table input
[32mSuccess[0m    ||    tool registry register overwrites when registering the same name twice
[32mSuccess[0m    ||    tool registry get returns nil for unknown names
[32mSuccess[0m    ||    tool registry get returns the definition for a registered name
[32mSuccess[0m    ||    tool registry list_names returns empty list when registry is empty
[32mSuccess[0m    ||    tool registry list_names returns all registered names
[32mSuccess[0m    ||    tool registry select returns matching definitions in the order given
[32mSuccess[0m    ||    tool registry select returns an empty list for an empty input
[32mSuccess[0m    ||    tool registry select raises on unknown tool name with the offending name in the message
[32mSuccess[0m    ||    tool registry select raises on the first unknown name even when some are known
[32mSuccess[0m    ||    tool registry select group sentinels @all expands to every registered tool, alphabetically
[32mSuccess[0m    ||    tool registry select group sentinels @readonly excludes write tools
[32mSuccess[0m    ||    tool registry select group sentinels @readonly treats absent kind as read (default per contract)
[32mSuccess[0m    ||    tool registry select group sentinels de-duplicates when a group overlaps an explicit name
[32mSuccess[0m    ||    tool registry select group sentinels raises on an unknown group sentinel, naming it
[32mSuccess[0m    ||    tool registry reset clears all registered tools
[32mSuccess[0m    ||    tool registry reset is idempotent on an empty registry

[32mSuccess: [0m    20
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
Running tests/unit/tools_serialize_spec.lua
Scheduling: tests/unit/tools_serialize_spec.lua

========================================
Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/unit/tools_serialize_spec.lua
[32mSuccess[0m    ||    serialize.render_call / parse_call round-trips a minimal ToolCall
[32mSuccess[0m    ||    serialize.render_call / parse_call round-trips a ToolCall with nested JSON input
[32mSuccess[0m    ||    serialize.render_call / parse_call round-trips an empty input table
[32mSuccess[0m    ||    serialize.render_call / parse_call parse_call returns nil on missing prefix
[32mSuccess[0m    ||    serialize.render_call / parse_call parse_call tolerates missing fence body (empty input)
[32mSuccess[0m    ||    serialize.render_result / parse_result round-trips a successful ToolResult
[32mSuccess[0m    ||    serialize.render_result / parse_result round-trips is_error=true with error=true tag in header
[32mSuccess[0m    ||    serialize.render_result / parse_result round-trips an empty content string
[32mSuccess[0m    ||    serialize.render_result / parse_result round-trips content with triple backticks (dynamic fence)
[32mSuccess[0m    ||    serialize.render_result / parse_result round-trips content with four consecutive backticks
[32mSuccess[0m    ||    serialize.render_result / parse_result round-trips content with mixed backtick runs
[32mSuccess[0m    ||    serialize.render_result / parse_result parse_result returns nil on missing prefix
[32mSuccess[0m    ||    serialize.render_result / parse_result is_error defaults to false when header lacks error=true tag
[32mSuccess[0m    ||    serialize fence length invariant opening and closing fences match in length for empty content
[32mSuccess[0m    ||    serialize fence length invariant opening and closing fences scale past content's longest run

[32mSuccess: [0m    15
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
Running tests/unit/tools_types_spec.lua
Scheduling: tests/unit/tools_types_spec.lua

========================================
Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/unit/tools_types_spec.lua
[32mSuccess[0m    ||    types.validate_definition accepts a minimal valid definition
[32mSuccess[0m    ||    types.validate_definition rejects non-table input
[32mSuccess[0m    ||    types.validate_definition rejects missing name
[32mSuccess[0m    ||    types.validate_definition rejects empty string name
[32mSuccess[0m    ||    types.validate_definition rejects non-string name
[32mSuccess[0m    ||    types.validate_definition rejects missing description
[32mSuccess[0m    ||    types.validate_definition rejects empty string description
[32mSuccess[0m    ||    types.validate_definition rejects missing input_schema
[32mSuccess[0m    ||    types.validate_definition rejects non-table input_schema
[32mSuccess[0m    ||    types.validate_definition rejects missing handler
[32mSuccess[0m    ||    types.validate_definition rejects non-function handler
[32mSuccess[0m    ||    types.validate_call accepts a minimal valid call
[32mSuccess[0m    ||    types.validate_call accepts a call with empty input table
[32mSuccess[0m    ||    types.validate_call rejects non-table input to validator
[32mSuccess[0m    ||    types.validate_call rejects missing id
[32mSuccess[0m    ||    types.validate_call rejects empty id
[32mSuccess[0m    ||    types.validate_call rejects missing name
[32mSuccess[0m    ||    types.validate_call rejects missing input
[32mSuccess[0m    ||    types.validate_call rejects non-table input field
[32mSuccess[0m    ||    types.validate_result accepts a result without is_error
[32mSuccess[0m    ||    types.validate_result accepts a result with is_error = false
[32mSuccess[0m    ||    types.validate_result accepts a result with is_error = true
[32mSuccess[0m    ||    types.validate_result accepts empty content string
[32mSuccess[0m    ||    types.validate_result rejects non-table input
[32mSuccess[0m    ||    types.validate_result rejects missing id
[32mSuccess[0m    ||    types.validate_result rejects empty id
[32mSuccess[0m    ||    types.validate_result rejects missing content
[32mSuccess[0m    ||    types.validate_result rejects non-string content
[32mSuccess[0m    ||    types.validate_result rejects non-boolean is_error

[32mSuccess: [0m    29
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
Running tests/integration/skill_invoke_review_spec.lua
Scheduling: tests/integration/skill_invoke_review_spec.lua

========================================
Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/integration/skill_invoke_review_spec.lua
[32mSuccess[0m    ||    review.run_via_invoke invokes skill_invoke with the review manifest when a ready marker exists
[32mSuccess[0m    ||    review.run_via_invoke does NOT invoke when there are no markers
[32mSuccess[0m    ||    review.run_via_invoke does NOT invoke when the last marker is a pending agent question
[32mSuccess[0m    ||    review.run_via_invoke resubmits when the marker set shrank and a ready marker remains (bounded at 3)
[32mSuccess[0m    ||    review.run_via_invoke does NOT resubmit when the marker set did not shrink (no-progress storm guard)
[32mSuccess[0m    ||    review.run_via_invoke does NOT resubmit when the remaining marker is a pending question
[32mSuccess[0m    ||    review.run_via_invoke does NOT resubmit on a failed exchange
[32mSuccess[0m    ||    review.run_via_invoke invokes a mode run even with NO markers (general review)
[32mSuccess[0m    ||    review.run_via_invoke does NOT resubmit when a mode round inserts {} findings (fact-check 0→N)
[32mSuccess[0m    ||    review.run_via_invoke invokes (processes ready) even when an unaddressed pending {} marker is present
[32mSuccess[0m    ||    review.run_via_invoke does NOT invoke a strike-only doc with no mode (no ready markers)
[32mSuccess[0m    ||    review.run_via_invoke records projection states (base empty + post) so undo/redo re-render style (#133 M5)
[32mSuccess[0m    ||    review.run_via_invoke journals the round to a sidecar beside the doc (#133 M3)
[32mSuccess[0m    ||    review journal sidecar exclusion (#133 M3) is_journal_sidecar matches only *.parley-journal.md
[32mSuccess[0m    ||    review journal sidecar exclusion (#133 M3) setup_keymaps no-ops on a sidecar buffer (no review map bound)
[32mSuccess[0m    ||    review.should_resubmit (pure) resubmits while ready work remains, shrank, and under the bound
[32mSuccess[0m    ||    review.should_resubmit (pure) stops when no ready markers remain (e.g. mode inserted only {} findings)
[32mSuccess[0m    ||    review.should_resubmit (pure) stops when the ready count did not shrink (no progress)
[32mSuccess[0m    ||    review.should_resubmit (pure) stops at the resubmit bound (3)

[32mSuccess: [0m    19
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
Parley.nvim: Review: complete — no markers found
Parley.nvim: Review: no ready markers — pending agent turns await your reply
Parley.nvim: Review: 1 ready marker(s) remain, resubmitting...
Parley.nvim: Review: round complete
Parley.nvim: Review: round complete
Parley.nvim: Review: round complete
Parley.nvim: Review: nothing to do — markers present but none ready (e.g. strike proposals; accept/reject with <M-a>/<M-r>)
Parley.nvim: Review: all comments addressed
Parley.nvim: Review: all comments addressed
Running tests/integration/skill_invoke_spec.lua
Scheduling: tests/integration/skill_invoke_spec.lua

========================================
Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/integration/skill_invoke_spec.lua
[32mSuccess[0m    ||    skill_invoke.invoke drives one exchange: payload + force_tool, applies propose_edits, reloads, on_done
[32mSuccess[0m    ||    skill_invoke.invoke coerces a stringified edits array and applies it (model quirk, #133)
Error detected while processing command line:
[32mSuccess[0m    ||    skill_invoke.invoke surfaces a failed edit: on_done ok=false, applied=0, file untouched
[32mSuccess[0m    ||    skill_invoke.invoke is_in_flight true during a query; cancel clears it + supersedes the exchange (#133)
[32mSuccess[0m    ||    skill_invoke.invoke shows the progress bar during the query and stops it on completion (#133 M7)
[32mSuccess[0m    ||    skill_invoke.invoke aborts (on_done ok=false) when no agent resolves
[32mSuccess[0m    ||    skill_invoke.invoke aborts gracefully (on_done ok=false) when source() throws
Parley.nvim: skill t: old_string not unique: ab
Parley.nvim: skill t: no tool-capable agent resolved
[32mSuccess[0m    ||    skill_invoke.invoke widens relative reads from ordinary nested repo Markdown
[32mSuccess[0m    ||    skill_invoke.invoke executes relative tool paths from a super-repo sibling chat neighborhood

[32mSuccess: [0m    9
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
Parley.nvim: skill t: source failed: ...for-all-markdown/tests/integration/skill_invoke_spec.lua:221: style file not found
Running tests/integration/skill_providers_spec.lua
Scheduling: tests/integration/skill_providers_spec.lua

========================================
Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/integration/skill_providers_spec.lua
[32mSuccess[0m    ||    providers.disk emits a valid manifest per skill dir, skipping dirs without init.lua
[32mSuccess[0m    ||    providers.disk sources the body from SKILL.md via a closure over the captured path
[32mSuccess[0m    ||    providers.disk unwraps the { skill = {...} } shape and honors an inline source
[32mSuccess[0m    ||    providers.disk injects ctx.skill_md from the dir's SKILL.md into an explicit source(ctx)
[32mSuccess[0m    ||    providers.disk injects ctx.skill_dir (the discovery-time dir) into an explicit source(ctx)
[32mSuccess[0m    ||    providers.disk skips a dir whose init.lua throws, still listing the rest
[32mSuccess[0m    ||    providers.disk emits a source-less candidate for a dir with no source/SKILL.md (registry drops it)
[32mSuccess[0m    ||    providers.virtual lists the manifests its generators produce
[32mSuccess[0m    ||    providers.virtual is empty with no generators
[32mSuccess[0m    ||    providers.virtual skips an erroring generator, keeping the valid ones

[32mSuccess: [0m    10
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
Running tests/integration/skill_registry_spec.lua
Scheduling: tests/integration/skill_registry_spec.lua

========================================
Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/integration/skill_registry_spec.lua
[32mSuccess[0m    ||    skill_registry.discover unions all providers' manifests; get/names expose them
[32mSuccess[0m    ||    skill_registry.discover dedupes by name with LAST-provider-wins precedence
[32mSuccess[0m    ||    skill_registry.discover preserves first-appearance order in names()
[32mSuccess[0m    ||    skill_registry.discover returns nil for an unknown name
[32mSuccess[0m    ||    skill_registry.discover drops invalid manifests rather than sinking discovery
[32mSuccess[0m    ||    skill_registry.current — real plugin skills as manifests discovers review as a valid global manifest with the expected fields
[32mSuccess[0m    ||    skill_registry.current — real plugin skills as manifests discovers voice-apply as a valid global manifest

[32mSuccess: [0m    7
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
Running tests/integration/voice_apply_spec.lua
Scheduling: tests/integration/voice_apply_spec.lua

========================================
Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/integration/voice_apply_spec.lua
[32mSuccess[0m    ||    voice_apply source(ctx) composes SKILL.md ⊕ the per-slug style guide
[32mSuccess[0m    ||    voice_apply source(ctx) errors with a clear message when the style file is missing

[32mSuccess: [0m    2
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
Running tests/unit/skill_assembly_spec.lua
Scheduling: tests/unit/skill_assembly_spec.lua

========================================
Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/unit/skill_assembly_spec.lua
[32mSuccess[0m    ||    skill_assembly.build_invocation builds system+user messages from body + document (no redundant system_prompt field)
[32mSuccess[0m    ||    skill_assembly.build_invocation grants elevated tools only on a manual invocation
[32mSuccess[0m    ||    skill_assembly.build_invocation sets tool_choice from force_tool, else nil
[32mSuccess[0m    ||    skill_assembly.resolve_agent (pure, injected deps) tier 1: per-skill config override wins
[32mSuccess[0m    ||    skill_assembly.resolve_agent (pure, injected deps) tier 1b: legacy review_agent for the review skill
[32mSuccess[0m    ||    skill_assembly.resolve_agent (pure, injected deps) tier 2: manifest.agent default
[32mSuccess[0m    ||    skill_assembly.resolve_agent (pure, injected deps) tier 3: global skill_agent
[32mSuccess[0m    ||    skill_assembly.resolve_agent (pure, injected deps) tier 4: first tool-capable agent (anthropic/cliproxyapi)
[32mSuccess[0m    ||    skill_assembly.resolve_agent (pure, injected deps) returns nil when nothing resolves

[32mSuccess: [0m    9
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
Running tests/unit/skill_edits_spec.lua
Scheduling: tests/unit/skill_edits_spec.lua

========================================
Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/unit/skill_edits_spec.lua
[32mSuccess[0m    ||    skill_edits.compute_edits applies multiple edits (reverse-position order) and reports them
[32mSuccess[0m    ||    skill_edits.compute_edits fails when old_string is not found
[32mSuccess[0m    ||    skill_edits.compute_edits fails when old_string is not unique
[32mSuccess[0m    ||    skill_edits.compute_edits fails when an edit is missing old_string/new_string
[32mSuccess[0m    ||    skill_edits.compute_edits does not mutate on failure (atomic)

[32mSuccess: [0m    5
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
Running tests/unit/skill_manifest_spec.lua
Scheduling: tests/unit/skill_manifest_spec.lua

========================================
Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/unit/skill_manifest_spec.lua
[32mSuccess[0m    ||    skill_manifest.validate accepts a fully-formed manifest
[32mSuccess[0m    ||    skill_manifest.validate accepts a minimal manifest (no tools/elevated/force_tool/args/agent)
[32mSuccess[0m    ||    skill_manifest.validate rejects non-table input
[32mSuccess[0m    ||    skill_manifest.validate rejects a missing name
[32mSuccess[0m    ||    skill_manifest.validate rejects a missing description
[32mSuccess[0m    ||    skill_manifest.validate rejects a scope outside {global, repo, super_repo}
[32mSuccess[0m    ||    skill_manifest.validate accepts each valid scope
[32mSuccess[0m    ||    skill_manifest.validate rejects activation that is not a table
[32mSuccess[0m    ||    skill_manifest.validate rejects an empty activation (a skill no one can activate is a bug)
[32mSuccess[0m    ||    skill_manifest.validate rejects an unknown activation flag
[32mSuccess[0m    ||    skill_manifest.validate rejects a non-boolean activation flag value
[32mSuccess[0m    ||    skill_manifest.validate rejects a source that is not a function
[32mSuccess[0m    ||    skill_manifest.validate rejects tools that is not a list of strings
[32mSuccess[0m    ||    skill_manifest.validate rejects elevated that is not a list of strings
[32mSuccess[0m    ||    skill_manifest.validate rejects a non-string force_tool
[32mSuccess[0m    ||    skill_manifest constants exposes SCOPES and ACTIVATION_FLAGS for reuse

[32mSuccess: [0m    16
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
Running tests/unit/skill_picker_spec.lua
Scheduling: tests/unit/skill_picker_spec.lua

========================================
Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/unit/skill_picker_spec.lua
[32mSuccess[0m    ||    skill_picker.run_skill routing routes review through run_via_invoke (marker pre-check + resubmit)
[32mSuccess[0m    ||    skill_picker.run_skill routing routes a non-review skill through skill_invoke.invoke (single-shot)

[32mSuccess: [0m    2
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
Running tests/unit/skill_render_spec.lua
Scheduling: tests/unit/skill_render_spec.lua

========================================
Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/unit/skill_render_spec.lua
[32mSuccess[0m    ||    skill_render attach_diagnostics sets an INFO diagnostic per edit, on the edit's line
[32mSuccess[0m    ||    skill_render clear_decorations removes the diagnostics
[32mSuccess[0m    ||    skill_render highlight_edits runs without error on edited regions
[32mSuccess[0m    ||    skill_render a non-empty edit produces highlight extmarks
[32mSuccess[0m    ||    skill_render a deletion (empty new_string) gets a gutter diagnostic but no highlight
[32mSuccess[0m    ||    skill_render wrap hard-wraps at word boundaries to the given width
[32mSuccess[0m    ||    skill_render format_diagnostic_message word-wraps display text at the requested width
[32mSuccess[0m    ||    skill_render attach_diagnostics wraps the message + spans the edit's lines (end_lnum)
[32mSuccess[0m    ||    skill_render snapshot captures highlights + diagnostics; apply_snapshot restores them
[32mSuccess[0m    ||    skill_render snapshot captures and restores highlight and diagnostic column spans
[32mSuccess[0m    ||    skill_render dismiss clears decorations (alias of clear_decorations)

[32mSuccess: [0m    11
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================
Running tests/unit/tools_builtin_propose_edits_spec.lua
Scheduling: tests/unit/tools_builtin_propose_edits_spec.lua

========================================
Testing:     /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/tests/unit/tools_builtin_propose_edits_spec.lua
[32mSuccess[0m    ||    propose_edits tool definition is a valid write ToolDefinition
[32mSuccess[0m    ||    propose_edits handler applies a batch of edits to file_path
[32mSuccess[0m    ||    propose_edits handler errors and leaves the file unchanged on a non-unique old_string
[32mSuccess[0m    ||    propose_edits handler errors on a missing file_path
[32mSuccess[0m    ||    propose_edits handler errors on missing/invalid edits
[32mSuccess[0m    ||    propose_edits handler errors on an empty edits batch (no-op write) and writes nothing
[32mSuccess[0m    ||    propose_edits inline backup backs up the prior content to a numbered .parley-backup before writing
[32mSuccess[0m    ||    propose_edits inline backup uses the next free backup number on a second apply
[32mSuccess[0m    ||    propose_edits inline backup writes NO backup when the edit batch fails (no destructive write)
[32mSuccess[0m    ||    propose_edits via dispatcher.execute_call (cwd-scope keystone) applies edits when file_path is inside cwd
[32mSuccess[0m    ||    propose_edits via dispatcher.execute_call (cwd-scope keystone) refuses a file_path outside cwd (the cwd-scope guard fires)

[32mSuccess: [0m    11
[31mFailed : [0m    0
[31mErrors : [0m    0
========================================

exec
/bin/zsh -lc "nl -ba lua/parley/neighborhood.lua | sed -n '90,340p'; nl -ba lua/parley/tools/dispatcher.lua | sed -n '115,325p'; nl -ba lua/parley/init.lua | sed -n '1435,1450p'; nl -ba lua/parley/tool_loop.lua | sed -n '238,265p'; nl -ba lua/parley/skill_invoke.lua | sed -n '176,230p'" in /Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown
 succeeded in 0ms:
    90            end
    91        end
    92
    93        return dirname(artifact_path)
    94    end
    95
    96    function M.build_policy(write_root, ordered_roots)
    97        local seen, read_roots = {}, {}
    98        for _, root in ipairs(ordered_roots or {}) do
    99            if type(root) == "string" and root ~= "" and not seen[root] then
   100                seen[root] = true
   101                read_roots[#read_roots + 1] = root
   102            end
   103        end
   104        return { write_root = write_root, read_roots = read_roots }
   105    end
   106
   107    function M.policy_from_roots(write_root, repo_root, configured_roots)
   108        local function canonical(path)
   109            path = clean(path)
   110            return path and (vim.loop.fs_realpath(path) or path) or nil
   111        end
   112        write_root = canonical(write_root)
   113        if not write_root then return nil, "buffer has no file" end
   114        local roots = { write_root }
   115        repo_root = canonical(repo_root)
   116        if repo_root then roots[#roots + 1] = repo_root end
   117        for _, root in ipairs(configured_roots or {}) do
   118            if type(root) == "string" and root ~= "" then
   119                if root:sub(1, 1) == "~" then root = vim.fn.expand(root) end
   120                local resolved = root:sub(1, 1) == "/" and root or join(write_root, root)
   121                roots[#roots + 1] = canonical(resolved)
   122            end
   123        end
   124        return M.build_policy(write_root, roots)
   125    end
   126
   127    function M.policy_for_path(path, config, chat_roots)
   128        local write_root, err = M.derive_for_path(path, config, chat_roots)
   129        if not write_root then return nil, err end
   130        local configured_repo = clean(config and config.repo_root)
   131        local repo_root = configured_repo and path_within(path, configured_repo)
   132            and configured_repo or nil
   133        return M.policy_from_roots(write_root, repo_root,
   134            config and config.tool_read_roots)
   135    end
   136
   137    function M.format_tool_context(policy)
   138        if not policy or not policy.write_root then return nil end
   139        local lines = { "Relative reads search these roots in order (first existing match wins):" }
   140        for _, root in ipairs(policy.read_roots or {}) do lines[#lines + 1] = "- " .. root end
   141        lines[#lines + 1] = "Relative writes resolve only from: " .. policy.write_root
   142        return table.concat(lines, "\n")
   143    end
   144
   145    function M.for_buf(buf)
   146        local path = vim.api.nvim_buf_get_name(buf)
   147        local config = require("parley").config
   148        local ok, chat_dirs = pcall(require, "parley.chat_dirs")
   149        local roots = {}
   150        if ok and type(chat_dirs.get_chat_roots) == "function" then
   151            local roots_ok, derived_roots = pcall(chat_dirs.get_chat_roots)
   152            if roots_ok then
   153                roots = derived_roots
   154            end
   155        end
   156        return M.derive_for_path(path, config, roots)
   157    end
   158
   159    function M.policy_for_buf(buf)
   160        local path = vim.api.nvim_buf_get_name(buf)
   161        local config = require("parley").config
   162        local ok, chat_dirs = pcall(require, "parley.chat_dirs")
   163        local roots = {}
   164        if ok and type(chat_dirs.get_chat_roots) == "function" then
   165            local roots_ok, derived_roots = pcall(chat_dirs.get_chat_roots)
   166            if roots_ok then roots = derived_roots end
   167        end
   168        return M.policy_for_path(path, config, roots)
   169    end
   170
   171    local function relative_to_root(path, root)
   172        path = clean(path)
   173        root = clean(root)
   174        if not path or not root then
   175            return nil
   176        end
   177        if path == root then
   178            return ""
   179        end
   180        if path:sub(1, #root + 1) == root .. "/" then
   181            return path:sub(#root + 2)
   182        end
   183        return nil
   184    end
   185
   186    local function policy_for_completion(buf)
   187        return vim.b[buf].parley_root_policy or M.policy_for_buf(buf)
   188    end
   189
   190    function M.merge_completion_candidates(per_root)
   191        local seen, out = {}, {}
   192        for _, items in ipairs(per_root or {}) do
   193            local sorted = vim.deepcopy(items)
   194            table.sort(sorted)
   195            for _, item in ipairs(sorted) do
   196                if not seen[item] then seen[item] = true; out[#out + 1] = item end
   197            end
   198        end
   199        return out
   200    end
   201
   202    function M.completion_candidates(policy, base)
   203        local groups = {}
   204        for _, root in ipairs(policy and policy.read_roots or {}) do
   205            local items = {}
   206            for _, match in ipairs(vim.fn.glob(root .. "/" .. (base or "") .. "*", false, true)) do
   207                local rel = relative_to_root(match, root)
   208                if rel and rel ~= "" then
   209                    if vim.fn.isdirectory(match) == 1 then rel = rel .. "/" end
   210                    items[#items + 1] = rel
   211                end
   212            end
   213            groups[#groups + 1] = items
   214        end
   215        local accepted = {}
   216        local resolver = require("parley.tools.dispatcher").resolve_read_path
   217        for _, label in ipairs(M.merge_completion_candidates(groups)) do
   218            if resolver(label:gsub("/$", ""), policy.read_roots) then
   219                accepted[#accepted + 1] = label
   220            end
   221        end
   222        return accepted
   223    end
   224
   225    function M.completefunc(findstart, base)
   226        if tonumber(findstart) == 1 then
   227            local line = vim.api.nvim_get_current_line()
   228            local col = vim.fn.col(".") - 1
   229            local start = col
   230            while start > 0 do
   231                local ch = line:sub(start, start)
   232                if ch:match("[%s%(%[%{]") then
   233                    break
   234                end
   235                start = start - 1
   236            end
   237            return start
   238        end
   239
   240        local buf = vim.api.nvim_get_current_buf()
   241        local policy = policy_for_completion(buf)
   242        if not policy then
   243            return {}
   244        end
   245        return M.completion_candidates(policy, base)
   246    end
   247
   248    local cmp_registered = false
   249    local function cmp_path_sources(cmp)
   250        local sources = {
   251            {
   252                name = "parley_path",
   253            },
   254            { name = "buffer" },
   255        }
   256
   257        if cmp.config and type(cmp.config.sources) == "function" then
   258            return cmp.config.sources(sources)
   259        end
   260        return sources
   261    end
   262
   263    function M.attach_cmp_completion(buf)
   264        if not vim.api.nvim_buf_is_valid(buf) then
   265            return nil
   266        end
   267
   268        local policy = policy_for_completion(buf)
   269        if not policy then
   270            return nil
   271        end
   272
   273        local ok, cmp = pcall(require, "cmp")
   274        if not ok or type(cmp) ~= "table" or type(cmp.setup) ~= "table" or type(cmp.setup.buffer) ~= "function" then
   275            return nil
   276        end
   277        if not cmp_registered and type(cmp.register_source) == "function" then
   278            cmp.register_source("parley_path", {
   279                complete = function(_, params, callback)
   280                    local target = params.context and params.context.bufnr or vim.api.nvim_get_current_buf()
   281                    local before = params.context and params.context.cursor_before_line or ""
   282                    local base = before:match("([^%s%(%[%{]+)$") or ""
   283                    local words = M.completion_candidates(policy_for_completion(target), base)
   284                    local items = {}
   285                    for _, word in ipairs(words) do items[#items + 1] = { label = word, word = word } end
   286                    callback(items)
   287                end,
   288            })
   289            cmp_registered = true
   290        end
   291
   292        cmp.setup.buffer({
   293            completion = {
   294                keyword_pattern = [[\~\?\(\k\|[\/\.\-]\)\+]],
   295                keyword_length = 1,
   296            },
   297            sources = cmp_path_sources(cmp),
   298        })
   299        return policy.write_root
   300    end
   301
   302    local function schedule_cmp_attach(buf)
   303        vim.schedule(function()
   304            M.attach_cmp_completion(buf)
   305        end)
   306    end
   307
   308    function M.attach_completion(buf)
   309        local policy = M.policy_for_buf(buf)
   310        if not policy then
   311            return nil
   312        end
   313        if vim.b[buf].parley_completion_attached then return policy.write_root end
   314        vim.b[buf].parley_completion_attached = true
   315        vim.b[buf].parley_root_policy = policy
   316        vim.api.nvim_set_option_value("completefunc", "v:lua.require'parley.neighborhood'.completefunc", { buf = buf })
   317        schedule_cmp_attach(buf)
   318        vim.api.nvim_create_autocmd("InsertEnter", {
   319            buffer = buf,
   320            once = true,
   321            callback = function()
   322                schedule_cmp_attach(buf)
   323            end,
   324        })
   325        return policy.write_root
   326    end
   327
   328    return M
   115        if allowed_roots then
   116            return nil, "path outside working directory and configured read roots: "
   117                .. path .. " (add a root to parley `tool_read_roots` to allow it)"
   118        end
   119        return nil, "path outside working directory: " .. path
   120    end
   121
   122    function M.resolve_read_path(path, read_roots)
   123        if type(path) ~= "string" or path == "" then
   124            return nil, "path must be a non-empty string"
   125        end
   126        local roots = {}
   127        for _, root in ipairs(read_roots or {}) do
   128            local resolved = resolve_root(root, root)
   129            if resolved then roots[#roots + 1] = resolved end
   130        end
   131        local candidates = {}
   132        if path:sub(1, 1) == "/" then
   133            candidates[1] = path
   134        else
   135            for _, root in ipairs(roots) do candidates[#candidates + 1] = root .. "/" .. path end
   136        end
   137        for _, candidate in ipairs(candidates) do
   138            candidate = vim.fs.normalize(candidate)
   139            if vim.loop.fs_lstat(candidate) then
   140                local real = vim.loop.fs_realpath(candidate)
   141                if not real then
   142                    return nil, "cannot resolve read path: " .. path
   143                end
   144                for _, root in ipairs(roots) do
   145                    if real == root or real:sub(1, #root + 1) == root .. "/" then return real end
   146                end
   147                return nil, "read path resolves outside configured roots: " .. path
   148            end
   149        end
   150        return nil, "read path not found in configured roots: " .. path
   151    end
   152
   153    --------------------------------------------------------------------------------
   154    -- Result truncation
   155    --------------------------------------------------------------------------------
   156
   157    --- Byte-length truncation with a trailing marker.
   158    ---
   159    --- Used by execute_call to cap the size of each ToolResult at
   160    --- `opts.max_bytes` (default 100KB via the agent config). M5 will
   161    --- add a metadata-preserving variant (truncate_preserving_footer)
   162    --- that write_file uses to keep its `pre-image:` footer intact.
   163    ---
   164    --- Pure. Handles nil content as empty string.
   165    ---
   166    --- @param content string|nil
   167    --- @param max_bytes number
   168    --- @return string
   169    function M.truncate(content, max_bytes)
   170        content = content or ""
   171        if #content <= max_bytes then return content end
   172        local omitted = #content - max_bytes
   173        return content:sub(1, max_bytes) .. string.format("\n... [truncated: %d bytes omitted]", omitted)
   174    end
   175
   176    -- #139: horizontal output pager. Window `content` to lines [offset, offset+limit)
   177    -- (offset 1-indexed) and, when the window doesn't cover the whole output, append a
   178    -- footer naming the true total + how to page/narrow. Pure. Returns the windowed
   179    -- string (with footer) and the total line count.
   180    M.PAGE_DEFAULT_LIMIT = 200
   181    M.PAGE_MAX_LIMIT = 2000
   182
   183    function M.page_lines(content, offset, limit)
   184        content = content or ""
   185        local lines = vim.split(content, "\n", { plain = true })
   186        -- A trailing newline yields a spurious empty final element; drop it so the
   187        -- count matches the visible lines.
   188        if #lines > 1 and lines[#lines] == "" then
   189            table.remove(lines)
   190        end
   191        local total = #lines
   192        offset = math.max(1, math.floor(offset or 1))
   193        limit = math.max(1, math.floor(limit or M.PAGE_DEFAULT_LIMIT))
   194
   195        if offset > total then
   196            return "... [no lines at offset " .. offset .. "; output has " .. total .. " line(s)]", total
   197        end
   198
   199        local last = math.min(offset + limit - 1, total)
   200        local window = {}
   201        for i = offset, last do
   202            window[#window + 1] = lines[i]
   203        end
   204        local text = table.concat(window, "\n")
   205
   206        local windowed = (offset > 1) or (last < total)
   207        if windowed then
   208            local note = (last < total)
   209                and (" — pass offset=" .. (last + 1) .. " for the next page, or narrow your query")
   210                or " — end of output"
   211            text = text .. "\n... [lines " .. offset .. "-" .. last .. " of " .. total .. note .. "]"
   212        end
   213        return text, total
   214    end
   215
   216    --------------------------------------------------------------------------------
   217    -- Handler invocation
   218    --------------------------------------------------------------------------------
   219
   220    --- Execute a ToolCall against the registered handler, with:
   221    ---   - registry lookup (is_error on unknown name)
   222    ---   - pcall around handler (is_error on raise)
   223    ---   - non-table return guard (is_error on misbehaving handler)
   224    ---   - id/name stamping on the returned result
   225    ---   - byte-length truncation when opts.max_bytes is set
   226    ---
   227    --- The returned ToolResult is ALWAYS well-shaped even when things
   228    --- go wrong — the tool loop driver can serialize it directly without
   229    --- further checks.
   230    ---
   231    --- @param call ToolCall { id, name, input }
   232    --- @param tools_registry table module exposing `get(name)` (parley.tools)
   233    --- @param opts table|nil { max_bytes?: number, root_policy?: RootPolicy, cwd?: string, read_roots?: string[] }
   234    --- @return ToolResult
   235    function M.execute_call(call, tools_registry, opts)
   236        opts = opts or {}
   237        local policy = opts.root_policy
   238        if not policy and opts.cwd then
   239            policy = require("parley.neighborhood").policy_from_roots(opts.cwd, nil, opts.read_roots)
   240        end
   241
   242        local def = tools_registry.get(call.name)
   243        if not def then
   244            return {
   245                id = call.id,
   246                name = call.name,
   247                content = "Tool '" .. call.name .. "' is not available on this client. Please continue without it.",
   248                is_error = true,
   249            }
   250        end
   251
   252        -- SHARED PRELUDE: cwd-scope check for any tool whose input has a
   253        -- `path` string field. Read tools additionally honor configured
   254        -- `tool_read_roots` (#140); write tools stay cwd-confined.
   255        -- (M5 adds write-specific additional guards on top of this.)
   256        --
   257        -- `opts.cwd` is optional — the tool_loop passes it explicitly so
   258        -- the dispatcher does not need to know about vim.fn.getcwd() from
   259        -- pure test contexts. When absent, the check is skipped (caller
   260        -- accepts responsibility).
   261        -- Resolve path fields: tools may use `path` or `file_path`.
   262        -- Check both so the cwd-scope guard applies uniformly.
   263        local function roots_for_def()
   264            -- #140: read tools may also reach any configured `tool_read_roots`;
   265            -- write tools get nil → cwd-only. Gate on `~= "write"` (the canonical
   266            -- read-tool predicate `@readonly` uses): `kind` defaults to read when
   267            -- absent, so `== "read"` would wrongly confine an absent-kind tool.
   268            return (def.kind ~= "write") and (policy and policy.read_roots or {}) or nil
   269        end
   270
   271        local path_fields = { "path", "file_path" }
   272        if policy and call.input and def.default_path and call.input.path == nil
   273            and call.input.file_path == nil and call.input.paths == nil then
   274            call.input.path = def.default_path
   275        end
   276        for _, field in ipairs(path_fields) do
   277            if policy and call.input and type(call.input[field]) == "string" then
   278                local roots = roots_for_def()
   279                local abs, scope_err
   280                if def.kind ~= "write" then
   281                    abs, scope_err = M.resolve_read_path(call.input[field], roots)
   282                else
   283                    abs, scope_err = M.resolve_path_in_cwd(call.input[field], policy.write_root)
   284                end
   285                if not abs then
   286                    return {
   287                        id = call.id,
   288                        name = call.name,
   289                        content = scope_err,
   290                        is_error = true,
   291                    }
   292                end
   293                call.input[field] = abs
   294            end
   295        end
   296        if policy and call.input and type(call.input.paths) == "table" then
   297            local roots = roots_for_def()
   298            local resolved = {}
   299            for i, path in ipairs(call.input.paths) do
   300                if type(path) ~= "string" then
   301                    return {
   302                        id = call.id,
   303                        name = call.name,
   304                        content = "paths must be an array of strings",
   305                        is_error = true,
   306                    }
   307                end
   308                local abs, scope_err
   309                if def.kind ~= "write" then
   310                    abs, scope_err = M.resolve_read_path(path, roots)
   311                else
   312                    abs, scope_err = M.resolve_path_in_cwd(path, policy.write_root)
   313                end
   314                if not abs then
   315                    return {
   316                        id = call.id,
   317                        name = call.name,
   318                        content = scope_err,
   319                        is_error = true,
   320                    }
   321                end
   322                resolved[i] = abs
   323            end
   324            call.input.paths = resolved
   325        end
  1435
  1436    ---@param buf number | nil # buffer number
  1437    M.prep_md = function(buf)
  1438        -- disable swapping for this buffer and set filetype to markdown
  1439        vim.api.nvim_command("setlocal noswapfile")
  1440        -- better text wrapping
  1441        vim.api.nvim_command("setlocal wrap linebreak")
  1442        if type(M.config.repo_root) == "string" and M.config.repo_root ~= "" then
  1443            require("parley.neighborhood").attach_completion(buf)
  1444        end
  1445        -- auto save on TextChanged, InsertLeave (debounced to avoid disk thrashing on large files)
  1446        local save_timer = nil
  1447        local SAVE_DEBOUNCE_MS = 1000
  1448        vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
  1449            buffer = buf,
  1450            callback = function()
   238            M.reset(bufnr)
   239            return "done"
   240        end
   241
   242        -- Execute each tool call and write 🔧:/📎: blocks in streaming order.
   243        local dispatcher = require("parley.tools.dispatcher")
   244        local registry = require("parley.tools")
   245        local root_policy = agent_info.root_policy
   246            or (agent_info.cwd and neighborhood.policy_from_roots(agent_info.cwd, nil,
   247                require("parley.config").tool_read_roots))
   248            or neighborhood.policy_for_buf(bufnr)
   249
   250        local exec_opts = {
   251            cwd = root_policy and root_policy.write_root or vim.fn.getcwd(),
   252            root_policy = root_policy,
   253            max_bytes = agent_info.tool_result_max_bytes or 102400,
   254            -- #140: extra read-tool roots (global config); write tools ignore it.
   255            -- #139: default output-pager page size; the dispatcher windows results.
   256            page_limit = require("parley.config").tool_result_page_lines,
   257        }
   258
   259        for _, call in ipairs(tool_calls) do
   260            -- 🔧: section for the tool_use
   261            M._append_section_to_answer(bufnr, model, active_exchange_idx, {
   262                kind = "tool_use",
   263                id = call.id,
   264                name = call.name,
   265                input = call.input,
   176        -- Large-document tool output needs headroom: a multi-edit propose_edits batch
   177        -- echoes old/new/explain per edit and easily exceeds the default (4096),
   178        -- truncating the tool JSON → empty decode. (Was skill_runner's explicit bump.)
   179        payload.max_tokens = math.max(payload.max_tokens or 0, 100000)
   180
   181        skill_render.clear_decorations(buf)
   182
   183        local neighborhood = require("parley.neighborhood")
   184        local root_policy = neighborhood.policy_for_buf(buf)
   185            or neighborhood.policy_from_roots(vim.fn.fnamemodify(artifact_path, ":h"), nil, {})
   186        local cwd = root_policy.write_root
   187
   188        _in_flight[buf] = true
   189        -- Detached progress bar: this is a ~30s headless op, so show a running cue
   190        -- (the first substantive-progress surface, #133 M7). Stopped on exit/abort.
   191        require("parley.progress").start("Parley " .. tostring(manifest.name) .. " running…")
   192        llm.query(
   193            nil, -- headless: no streaming buffer insertion
   194            agent.provider,
   195            payload,
   196            function() end, -- handler (headless)
   197            function(qid) -- on_exit
   198                vim.schedule(function()
   199                    -- Superseded by a newer exchange (the old one was cancelled) →
   200                    -- no-op so we don't reload/re-render or clobber the new state.
   201                    if _gen[buf] ~= gen then
   202                        return
   203                    end
   204                    require("parley.progress").stop()
   205                    _in_flight[buf] = nil
   206                    local qt = tasker.get_query(qid) or {}
   207                    local calls = providers.decode_anthropic_tool_calls_from_stream(qt.raw_response or "")
   208                    local results = {}
   209                    local applied = 0
   210                    local errors = {}
   211                    for i, call in ipairs(calls) do
   212                        if call.name == "propose_edits" then
   213                            call.input = call.input or {}
   214                            call.input.file_path = artifact_path -- artifact-bound
   215                            -- Some models emit `edits` as a JSON STRING rather than an
   216                            -- array; coerce it once here so the batch actually applies
   217                            -- (and render_propose_edits below gets a table). #133
   218                            if type(call.input.edits) == "string" then
   219                                local ok, decoded = pcall(vim.json.decode, call.input.edits)
   220                                if ok and type(decoded) == "table" then
   221                                    call.input.edits = decoded
   222                                end
   223                            end
   224                        end
   225                        results[i] = tools_dispatcher.execute_call(call, tools_registry,
   226                            { cwd = cwd, root_policy = root_policy,
   227                              page_limit = require("parley.config").tool_result_page_lines }) -- #140 #139
   228                        if call.name == "propose_edits" then
   229                            if results[i].is_error then
   230                                table.insert(errors, results[i].content)

codex
```verdict
verdict: SHIP
confidence: high
```

The implementation fulfills issue #181’s read-wide/write-narrow contract. A shared root policy drives dispatcher enforcement, completion, model guidance, chat recursion, and skill invocation. Ordered precedence, missing reads, absolute paths, symlink escapes, completion parity, idempotent attachment, global-chat narrowing, and ordinary nested-repo Markdown are covered. No blocking or important defects were found.

## 1. Strengths

- `RootPolicy` preserves a single ordered source of truth with canonicalization and first-wins de-duplication ([neighborhood.lua:96](/Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/lua/parley/neighborhood.lua:96)).
- Read resolution correctly treats the first existing candidate as authoritative and rejects escaping or dangling symlinks without falling through ([dispatcher.lua:122](/Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/lua/parley/tools/dispatcher.lua:122)).
- Read and write paths take deliberately separate enforcement paths in the shared dispatcher prelude ([dispatcher.lua:271](/Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/lua/parley/tools/dispatcher.lua:271)).
- Completion reuses the canonical read resolver, maintaining the “suggested path is accepted” invariant ([neighborhood.lua:202](/Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/lua/parley/neighborhood.lua:202)).
- Chat and skill seams both pass the same policy rather than reconstructing behavior independently ([tool_loop.lua:245](/Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/lua/parley/tool_loop.lua:245), [skill_invoke.lua:183](/Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/lua/parley/skill_invoke.lua:183)).

## 2. Critical findings

None.

## 3. Important findings

None.

## 4. Minor findings

None.

## 5. Test coverage notes

The mapped `providers/tool_use` and `skills/skill-system` suites passed, including neighborhood completion, dispatcher, tool-loop, build-message, and skill invocation coverage. Lint passed across 244 files and `git diff --check` was clean.

The full suite encountered unrelated managed-cliproxy fixture failures: the proxy process exited immediately and the download fixture attempted `127.0.0.1:0`. These failures do not exercise this diff.

## 6. Architectural notes for upcoming work

- `ARCH-DRY`: **pass** — policy derivation is shared, and completion delegates acceptance to `resolve_read_path`.
- `ARCH-PURE`: **pass** — deterministic ordering, merging, and formatting remain separate from filesystem/Neovim adapters.
- `ARCH-PURPOSE`: **pass** — ordinary nested Markdown demonstrably gains repo-root reads while identical relative writes remain neighborhood-confined.
- Atlas changes document both the architectural policy and tool safety behavior. No README update is required because no command, flag, keybinding, configuration key, or installation workflow was introduced.

## 7. Plan revision recommendations

None. The Core Concepts entities exist at their stated locations with the declared PURE/INTEGRATION separation, and the issue-level Plan and Done-when claims match the implementation.
tokens used
62,060
```verdict
verdict: SHIP
confidence: high
```

The implementation fulfills issue #181’s read-wide/write-narrow contract. A shared root policy drives dispatcher enforcement, completion, model guidance, chat recursion, and skill invocation. Ordered precedence, missing reads, absolute paths, symlink escapes, completion parity, idempotent attachment, global-chat narrowing, and ordinary nested-repo Markdown are covered. No blocking or important defects were found.

## 1. Strengths

- `RootPolicy` preserves a single ordered source of truth with canonicalization and first-wins de-duplication ([neighborhood.lua:96](/Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/lua/parley/neighborhood.lua:96)).
- Read resolution correctly treats the first existing candidate as authoritative and rejects escaping or dangling symlinks without falling through ([dispatcher.lua:122](/Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/lua/parley/tools/dispatcher.lua:122)).
- Read and write paths take deliberately separate enforcement paths in the shared dispatcher prelude ([dispatcher.lua:271](/Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/lua/parley/tools/dispatcher.lua:271)).
- Completion reuses the canonical read resolver, maintaining the “suggested path is accepted” invariant ([neighborhood.lua:202](/Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/lua/parley/neighborhood.lua:202)).
- Chat and skill seams both pass the same policy rather than reconstructing behavior independently ([tool_loop.lua:245](/Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/lua/parley/tool_loop.lua:245), [skill_invoke.lua:183](/Users/xianxu/workspace/worktree/parley.nvim/000181-repo-root-read-wide-completion-for-all-markdown/lua/parley/skill_invoke.lua:183)).

## 2. Critical findings

None.

## 3. Important findings

None.

## 4. Minor findings

None.

## 5. Test coverage notes

The mapped `providers/tool_use` and `skills/skill-system` suites passed, including neighborhood completion, dispatcher, tool-loop, build-message, and skill invocation coverage. Lint passed across 244 files and `git diff --check` was clean.

The full suite encountered unrelated managed-cliproxy fixture failures: the proxy process exited immediately and the download fixture attempted `127.0.0.1:0`. These failures do not exercise this diff.

## 6. Architectural notes for upcoming work

- `ARCH-DRY`: **pass** — policy derivation is shared, and completion delegates acceptance to `resolve_read_path`.
- `ARCH-PURE`: **pass** — deterministic ordering, merging, and formatting remain separate from filesystem/Neovim adapters.
- `ARCH-PURPOSE`: **pass** — ordinary nested Markdown demonstrably gains repo-root reads while identical relative writes remain neighborhood-confined.
- Atlas changes document both the architectural policy and tool safety behavior. No README update is required because no command, flag, keybinding, configuration key, or installation workflow was introduced.

## 7. Plan revision recommendations

None. The Core Concepts entities exist at their stated locations with the declared PURE/INTEGRATION separation, and the issue-level Plan and Done-when claims match the implementation.
