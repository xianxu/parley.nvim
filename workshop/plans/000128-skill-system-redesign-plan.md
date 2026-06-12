# Skill System Redesign Implementation Plan (#128)

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace parley's two execution engines (the chat tool loop + the single-shot forced-write `skill_runner`) with **one engine** — the chat loop — where a *skill* is a declarative manifest that configures a single turn of that loop.

**Architecture:** A skill is data, not a pipeline: a `SkillManifest` (`name/description/scope/activation/source/tools/elevated/force_tool/args`). Uniform-manifest *providers* (plugin-disk / user-disk / repo-provided / virtual) are unioned by a `discover` step into a registry. A thin, **pure per-turn assembly** function maps the buffer's *active-skill set* + current scope → (extra system context, granted tool set, optional forced tool); the existing chat loop consumes that each turn. A `read_skill(name)` tool lets the model pull a skill mid-loop (cwd-scope-exempt, transcript-visible). The salvaged batch-edit logic becomes a normal `propose_edits` builtin tool, so `review`/`voice_apply` run through the one loop instead of a bespoke pipeline. `skill_runner`'s forced-write engine is then deleted.

**Tech Stack:** Lua (Neovim plugin), `plenary.nvim` headless test harness (per-spec `nvim --headless -u tests/minimal_init.vim -c "PlenaryBustedFile …"`), the existing `lua/parley/tools/` registry + chat tool loop. Follows parley module conventions (`local M = {} … return M`) and mirrors the validation style of `lua/parley/tools/types.lua` / `lua/parley/discovery/descriptor.lua`.

---

## Scope & milestones

This is a large, integration-heavy redesign ("the main event"). Critical-path-first decomposition; each `Mx` is a **review boundary** (its own `sdlc milestone-close`).

- **M1 — Declarative manifest + provider-based discovery (no engine change).** The pure foundation: `SkillManifest` shape + `validate`; the unified `source(ctx)` closure contract (kills the `debug.getinfo` path-guessing dance); provider abstraction (plugin-disk / user-disk / repo / virtual) each emitting uniform manifests; `discover` unions + dedups them into a registry (`get`/`names`). Existing `review`/`voice_apply` re-expressed as manifests via the disk provider. **Touches no chat-loop code** — fully unit/integration-testable in isolation. This is the declarative core everything else consumes.
- **M2 — read_skill tool + per-turn assembly + route through the loop.** The engine integration: a per-buffer **active-skill state**; a **pure assembly** function (active set + scope → extra system context + granted tools + forced tool); the chat-loop turn-assembly hook that consults it *every turn* (critical: the recursive `respond()` rebuilds `agent_info` fresh — see Design note 1); the `read_skill(name)` builtin (source-agnostic, cwd-exempt, transcript-visible) that activates a pulled skill. After M2 the loop is the one engine for *loading* skills.
- **M3 — `propose_edits` builtin + `force_tool`; port `review` through the loop.** Salvage `compute_edits`/`apply_edits` → a `propose_edits` builtin (batch edits + `explain`, the kept UX); `highlight_edits`/`attach_diagnostics` → that tool's result rendering; the `force_tool` manifest field compels the tool for the turn. Port `review` to run end-to-end through the loop (batch-edit-with-explanations UX preserved).
- **M4 — port `voice_apply`; delete `skill_runner`; resolve callers + dead tools.** Port `voice_apply`; delete `skill_runner.run` + `_in_flight`/resubmit/hardcoded `tool_choice`/`max_tokens`; reconcile callers (`skill_picker`, `review.lua` shim, `keybinding_registry`); **resolve the glob/list_dir question** (see Design note 2 — they don't exist; decide whether `repo_discovery` warrants a structured glob tool vs. existing `ls`/`find`/`grep`).
- **M5 — `repo_discovery` virtual skill (the #116 bridge).** A virtual provider emitting `repo_discovery` (`scope=repo`, `activation={always=true}`, `tools=<read set>`, `source=ctx → parley.discovery.current():render()`). Requires #116 **M1** (already landed on the `000116` branch — merge ordering noted in Design note 3). The merge point where a repo's borrowed substrate joins parley's own.

Only **M1** is detailed to task granularity below; M2–M5 are milestone sketches to be expanded when reached. **#129** (capability permission model) layers onto the `tools`/`elevated` fields *after* this issue — out of scope here; the fields exist as the hook.

### Design notes (decisions that shaped this plan)

1. **Per-turn tool grants must derive from per-buffer state, not a one-time `agent_info` mutation** (`ARCH-PURE`/correctness). The recursive tool-loop call (`chat_respond.lua:1533`) re-enters `respond()` *without* passing `agent_info` — each turn rebuilds it fresh from headers/agent config. So skill-granted tools/context cannot be injected once; they must be re-derived every turn from a durable **active-skill set** (per-buffer) that the turn-assembly reads. This also makes "model pulls a skill mid-loop" fall out for free: `read_skill` records activation → the *next* turn's assembly grants its tools.
2. **`glob.lua`/`list_dir.lua` do not exist** — the issue's "present in `builtin/` but not in `BUILTIN_NAMES`" is stale. `builtin/` holds `ls.lua` + `find.lua` (both registered, structured, no injection surface). So M4's task is **not** dead-code cleanup; it's a YAGNI decision: does `repo_discovery` need a new structured glob tool, or do `ls`/`find`/`grep` + the registry's `query()` suffice? (Lean: suffice — don't add a tool without a consumer.)
3. **Merge ordering.** `repo_discovery` (M5) consumes `parley.discovery.current():render()`, which lives on the unmerged `000116` branch. Sequencing: land #116 M1 on `main` before M5 (or develop #128 atop a base that includes it). M1–M4 of *this* plan are independent of #116 and can proceed first. Confirm with operator at execution time.

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `SkillManifest` (shape + `validate`) | `lua/parley/skill_manifest.lua` | new |
| `assemble_turn` (active set + scope → turn config) | `lua/parley/skill_assembly.lua` | new (M2) |
| `compute_edits` (salvaged, pure) | `lua/parley/skill_edits.lua` | new (M3) — moved from `skill_runner.lua:54` |
| `resolve_agent` (salvaged cascade) | `lua/parley/skill_assembly.lua` | new (M2) — moved from `skill_runner.lua:284`; pure given injected config |

- **SkillManifest** — the declarative description of one skill: `{ name, description, scope, activation, source, tools, elevated, force_tool?, args?, agent? }`. `validate(m)` returns `(true)` or `(false, err)`.
  - `scope` ∈ `global | repo | super_repo`; `activation` = table of independent boolean flags `{ always?, auto?, manual? }` (any combination — `always`=preloaded by scope, `auto`=offered in the model's menu, `manual`=hotkey-activatable); `source` = `function(ctx) → string` (the body — unified across disk/virtual, see DiskProvider); `tools` = list of tool names granted whenever active; `elevated` = list granted only on **manual** activation (the #129 hook); `force_tool` = optional tool name to compel this turn; `args` = optional completable-arg specs (kept from v1); `agent` = optional model override.
  - **Relationships:** N:1 held by the SkillRegistry; 1:1 with a `source` closure. **DRY rationale:** one manifest shape across *all* providers (disk/virtual/repo) — `discover` and the assembly read one shape, no per-source branching (replaces v1's `skill.system_prompt` fn + `_dir`/`_module` internals + `pre_submit`/`post_apply` hooks). **Future extensions:** #129 reads `tools`/`elevated`; a `priority` field if menu ordering matters.
- **assemble_turn** (M2) — pure: `(active_manifests, scope, manual_active) → { system_context = string, tools = {…}, forced_tool = string|nil }`. Unions the bodies/tool-grants of the manifests active for this turn; applies `elevated` only for `manual_active` skills; surfaces a single `force_tool` if exactly one active skill sets it.
  - **Relationships:** consumes N SkillManifests; produces one turn-config. **DRY rationale:** the single place "what does this turn get" is decided — the chat loop and any future headless caller share it. **Future extensions:** #129 permission filtering slots in here (gate `elevated` on a capability check, not just `manual`).
- **compute_edits** (M3, salvaged from `skill_runner.lua:54-109`) — pure: `(content, edits) → (ok, msg, new_content, applied)`; validates uniqueness, applies in reverse position order. Becomes the core of the `propose_edits` tool handler.
  - **DRY rationale:** the one batch-edit transform; the tool handler (IO) wraps it. **Future extensions:** none expected — stable.
- **resolve_agent** (M2, salvaged from `skill_runner.lua:284-322`) — the agent cascade (per-skill config → skill default → global `skill_agent` → first tool-capable agent), reused by the assembly to pick a model when a skill declares one. v1's copy reads the parley module directly (not pure); **M2 salvages it as a pure function of *injected* config** (`(config, skill) → agent`) so the core stays pure and the IO (config read) lives at the assembly boundary (`ARCH-PURE`). Deferred from M1 Task 1 — it isn't part of the manifest schema and belongs where it's consumed.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `DiskProvider` | `lua/parley/skill_providers.lua` | new | filesystem scan (`vim.loop.fs_scandir`) |
| `VirtualProvider` | `lua/parley/skill_providers.lua` | new (seam in M1, used M5) | runtime-generated manifests |
| `SkillRegistry` (`discover`/`get`/`names`) | `lua/parley/skill_registry.lua` | new | provider union |
| `ActiveSkills` (per-buffer state) | `lua/parley/skill_active.lua` | new (M2) | per-buffer mutable state |
| `read_skill` tool | `lua/parley/tools/builtin/read_skill.lua` | new (M2) | registry lookup → transcript block |
| `propose_edits` tool | `lua/parley/tools/builtin/propose_edits.lua` | new (M3) | file write + buffer diagnostics/highlights |
| chat-loop turn hook | `lua/parley/chat_respond.lua` (modify) | modified (M2) | the existing turn assembly |

- **DiskProvider** — scans a skill root (`lua/parley/skills/*` plugin-bundled; `~/.config/parley/skills/` user) and emits a `SkillManifest` per dir. The manifest's `source` is **a closure capturing the absolute path the provider already found** (`function(ctx) return read(captured_path .. "/SKILL.md") end`) — this *deletes* the `debug.getinfo` path-guessing dance (`skill_runner.lua:226,376-392`). The dir's `init.lua` supplies the declarative fields (scope/activation/tools/…).
  - **Injected into:** the SkillRegistry's provider list. Tested with a temp fixture skill dir (no network).
  - **Future extensions:** a **RepoProvider** (the inspected repo ships skills via its readonly manifest) is a third disk-shaped provider — same emission shape, different root.
- **VirtualProvider** — emits manifests generated at runtime (no disk). The M1 deliverable is the *seam* (a provider that returns a list of manifests built from registered generators); the first concrete virtual skill (`repo_discovery`) arrives in M5.
  - **Injected into:** the SkillRegistry. Tested by registering a fake generator and asserting the manifest appears in `discover`.
- **SkillRegistry** — `discover()` unions all providers (dedup by name, last-wins precedence); `get(name)` / `names()` / `all()`. The single surface the assembly + `read_skill` read. (No cache built — `discover`/`current` recompute per call; add one only when a consumer needs it, YAGNI.)
  - **Injected into:** `read_skill`, `assemble_turn`'s caller, the picker. Tested with fake providers (no real fs).
- **ActiveSkills** (M2) — per-buffer mutable set of currently-active skill names (+ which were manually activated). Mirrors `tool_loop`'s `state_by_buf` pattern (`tool_loop.lua:36`). `read_skill`/hotkey write it; turn-assembly reads it.
  - **Injected into:** the chat-loop turn hook. The *logic* (assemble_turn) stays pure; this is the thin state seam.
- **read_skill tool** (M2) — `read_skill(name)`: looks up the manifest, calls `manifest.source(ctx)`, returns the body as a tool result (rendered 🔧/📎 in the transcript), and marks the skill active in ActiveSkills. **cwd-scope-exempt** — passes no `path`/`file_path` to the dispatcher, exactly like `chat_history_search` (`chat_history_search.lua:1-9`); a skill is a parley-namespace concept, not a repo file.
  - **Injected into:** `BUILTIN_NAMES` (`tools/init.lua:129`). Tested via the dispatcher with a fake registry.
- **propose_edits tool** (M3) — builtin wrapping the salvaged `compute_edits`/`apply_edits` + `highlight_edits`/`attach_diagnostics` for result rendering. `kind="write"`, `needs_backup` per existing edit-tool convention. Replaces v1's hardcoded `REVIEW_EDIT_TOOL` (`skill_runner.lua:22`).
  - **Injected into:** `BUILTIN_NAMES`; granted via a skill's `elevated`/`tools` + compelled via `force_tool`.
- **chat-loop turn hook** (M2, modify `chat_respond.lua`) — at turn assembly (after `agent_info` is resolved, before `prepare_payload` at `chat_respond.lua:1341`), call `assemble_turn(ActiveSkills[buf], scope)` and union its `system_context` into the system prompt + its `tools` into `agent_info.tools` + set `tool_choice` from `forced_tool`. Because the recursive call rebuilds `agent_info`, this hook runs **every turn** and re-reads ActiveSkills (Design note 1).
  - **Future extensions:** #129 inserts a permission gate between assemble_turn and the grant.

---

## M1 — Declarative manifest + provider-based discovery

**Module layout:** new flat infra modules `lua/parley/skill_manifest.lua`, `lua/parley/skill_providers.lua`, `lua/parley/skill_registry.lua` (matching the existing flat `skill_runner.lua`/`skill_picker.lua` convention; definition dirs stay at `lua/parley/skills/<name>/`). Specs flat in `tests/` (`tests/unit/skill_manifest_spec.lua`, `tests/integration/skill_providers_spec.lua`, `tests/integration/skill_registry_spec.lua`) per parley convention. Per-task TDD runs use the direct plenary form:

```
nvim --headless -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/skill_manifest_spec.lua"
```

Follow parley conventions: modules `local M = {} … return M`; tests use `plenary.busted` (`describe`/`it`); mirror `lua/parley/tools/types.lua` validation style (`fail(msg) → (false, err)` / `(true)`).

### Task 1: SkillManifest shape + `validate` (PURE)

**Files:**
- Create: `lua/parley/skill_manifest.lua`
- Test: `tests/unit/skill_manifest_spec.lua`

- [x] **Step 1: Write failing tests** — `M.validate(manifest)` returns `(ok, err)`:
  - a fully-formed manifest (name, description, scope, activation, source fn, tools list) → `(true, nil)`.
  - missing `name`/`description`/`source` → `(false, "<specific field>")`.
  - `scope` not in `{global, repo, super_repo}` → false.
  - `activation` not a table, or with an unknown flag key, or with a non-boolean flag → false; an empty `{}` activation → false (a skill no one can activate is a config bug — fail loud).
  - `source` not a function → false.
  - `tools`/`elevated` present but not a list-of-strings → false; absent → ok (default empty).
  - `force_tool` present but not a string → false; absent → ok.
- [x] **Step 2: Run, verify fail** (module missing).
- [x] **Step 3: Implement** `M.validate` (mirror `tools/types.lua`); expose `M.SCOPES` + `M.ACTIVATION_FLAGS` constants for reuse. ~~Also move the salvaged pure `resolve_agent` cascade here~~ — **deferred to M2** (it reads the parley module, so it's not pure; belongs where it's consumed at turn assembly — `ARCH-PURE`).
- [x] **Step 4: Run, verify pass.** _16/16 green._
- [x] **Step 5: Commit** — `#128 M1: SkillManifest shape + validate (declarative skill core)`. _8720009_

### Task 2: DiskProvider — manifests with closure `source` (INTEGRATION)

**Files:**
- Create: `lua/parley/skill_providers.lua`
- Test: `tests/integration/skill_providers_spec.lua`

- [x] **Step 1: Write failing test** with a temp fixture skill root containing `myskill/init.lua` (returns declarative fields) + `myskill/SKILL.md` (body): `providers.disk(root):list()` → a list of valid `SkillManifest`s (each passes `manifest.validate`), and `manifest.source({})` returns the SKILL.md body **read from the captured absolute path** (no `debug.getinfo`).
  - edge: a dir missing `init.lua` → skipped (not an error).
  - edge: `init.lua` with no SKILL.md but an explicit `source` fn → body from the fn. _(A dir with neither → `source = nil`, validate-dropped by the registry. The v1 `system_prompt` fallback that originally lived here was removed in the boundary-review round — see Revisions.)_
- [x] **Step 2: Run, verify fail.**
- [x] **Step 3: Implement** the disk provider: `vim.loop.fs_scandir` the root, for each dir load `init.lua`, build a manifest whose `source` is a closure over the dir's absolute path. Reuse the scan structure from `skill_runner.discover_skills` **but without** the `debug.getinfo` dance — root passed in. `providers.disk(root)` → `{ list = fn }`. _Loads init.lua via `loadfile` (absolute path → generic across plugin/user roots); source priority: explicit fn → SKILL.md (no v1 system_prompt fallback — removed in the boundary-review round)._
- [x] **Step 4: Run, verify pass.** _3/3 green._
- [x] **Step 5: Commit** — `#128 M1: DiskProvider (closure source, kills debug.getinfo dance)`. _dd1c4ff_

### Task 3: VirtualProvider seam (INTEGRATION)

**Files:**
- Modify: `lua/parley/skill_providers.lua`
- Test: `tests/integration/skill_providers_spec.lua` (extend)

- [x] **Step 1: Write failing test** — `providers.virtual({ generators })` where a generator is `function() → SkillManifest`: `:list()` returns the generated manifests, each valid. (No concrete virtual skill yet — `repo_discovery` is M5; this is just the seam.)
- [x] **Step 2–4:** fail → implement `providers.virtual(generators)` → pass. _5/5 green; erroring generator skipped._
- [x] **Step 5: Commit** — `#128 M1: VirtualProvider seam (runtime-generated manifests)`. _62f600b_

### Task 4: SkillRegistry — `discover` / `get` / `names` (INTEGRATION)

**Files:**
- Create: `lua/parley/skill_registry.lua`
- Test: `tests/integration/skill_registry_spec.lua`

- [x] **Step 1: Write failing tests** (inject fake providers — lists of manifests — so the test needs no real fs):
  - `registry.discover({ providerA, providerB })` unions both providers' manifests; `get(name)` returns the manifest; `names()` lists all.
  - **dedup by name with provider precedence** — settled **LAST-provider-wins** (later overrides; default stack plugin→user→repo→virtual so user/repo shadow plugin; operator-confirmable). `names()` keeps first-appearance order; value is last-seen.
  - `get("nope")` → nil; invalid manifests dropped (not fatal).
- [x] **Step 2: Run, verify fail.**
- [x] **Step 3: Implement** `discover(providers)` (ordered union + dedup), `get`, `names`, `all`, `default_stack`, `current()`. Wire `parley.skills` in `init.lua`. _`current()` resolves the plugin root via `nvim_get_runtime_file` (no debug.getinfo) ∪ `~/.config/parley/skills`; repo+virtual seams empty until M5._
- [x] **Step 4: Run, verify pass.** _5/5 green; smoke-verified `current()` loads real skill dirs without error._
- [x] **Step 5: Commit** — `#128 M1: SkillRegistry (provider union + dedup + cache)`. _cf6d7a3_

### Task 5: Express `review` + `voice_apply` as manifests (INTEGRATION)

**Files:**
- Modify: `lua/parley/skills/review/init.lua`, `lua/parley/skills/voice_apply/init.lua`
- Test: `tests/integration/skill_registry_spec.lua` (extend, real plugin root)

- [x] **Step 1: Write failing test** — `registry.current()` (real plugin disk root) yields valid manifests for `review` and `voice-apply`, with the expected declarative fields. Does NOT wire the chat loop (M2) — only proves they load as conformant manifests.
- [x] **Step 2–4:** fail → add the declarative fields to each skill's `init.lua` (keeping the existing `args`/prompt behavior + `pre_submit`/`post_apply` for M3/M4 to retire) → pass. _7/7 green; skill_runner_spec still 9/9 (v1 behavior unchanged). voice-apply's manifest source is SKILL.md-only; its dynamic per-slug style-guide composition is wired into an explicit source(ctx) when ported in M4 (noted in-file)._
- [x] **Step 5: Commit** — `#128 M1: express review + voice_apply as declarative manifests`. _b52beda_

### Task 6: Atlas + milestone close

- [x] **Step 1:** Update `atlas/skills/skill-system.md` with the redesign surface (one-engine principle, manifest shape, provider union, M1 modules, design points); v1 marked transitional. Linked + noted in `atlas/index.md` §8/§11.
- [x] **Step 2:** Update `atlas/traceability.yaml` mapping the new `skills/skill-system` key → the new modules + specs.
- [x] **Step 3:** `make test` green; `make lint` clean. _lint 0/0 (180 files), 91 spec files pass._
- [x] **Step 4:** `sdlc milestone-close --issue 128 --milestone M1` (runs the fresh-context judge). _Arc: FIX-THEN-SHIP → addressed (resolve_agent table drift, cache claim, disk docstring, branch-3 removal) → re-judge FIX-THEN-SHIP (boundary clean, no Critical). Logged in `## Log`._
- [x] **Step 5: Commit** — `#128 M1: atlas + traceability for declarative skill system`. _5abbf78_

**M1 Done when:** `parley.skills.discover()` returns a registry unioning disk providers (with the virtual/repo seams present); `review`/`voice_apply` load as valid `SkillManifest`s with no `debug.getinfo` path-guessing; manifest validation rejects malformed manifests; all specs green; atlas updated. **No chat-loop code touched yet** — the engine integration is M2.

---

## M2 — read_skill + per-turn assembly + route through the loop (sketch)

Build `ActiveSkills` (per-buffer state, mirroring `tool_loop.state_by_buf`); the **pure** `assemble_turn(active, scope, manual_active)` (→ system context + tools + forced tool); the `read_skill` builtin (cwd-exempt like `chat_history_search`, transcript-visible, marks the skill active); and the chat-loop hook at turn assembly (`chat_respond.lua` ~1341, *after* `agent_info` resolves) that unions assembly output into the system prompt + `agent_info.tools` + `tool_choice`. **Critical (Design note 1):** the hook must run on the recursive turn too — since `respond()` rebuilds `agent_info`, re-read `ActiveSkills[buf]` each turn rather than mutating once. Preload `always` skills by scope; append `(name, description)` of `auto` skills to the system context as a menu. To be expanded to tasks at M2 start.

## M3 — propose_edits builtin + force_tool; port review (sketch)

Move `compute_edits` (pure) to `skill_edits.lua`; build `propose_edits` builtin (`tools/builtin/propose_edits.lua`) wrapping it + `apply_edits` (IO) with `highlight_edits`/`attach_diagnostics` as result rendering (salvaged from `skill_runner.lua:54-213`). Implement `force_tool` handling in the turn hook (sets `tool_choice`). Port `review` to run through the loop: manual activation grants `elevated = {propose_edits}` + `force_tool = propose_edits`, the loop produces the batch edits, the tool applies + renders them (batch-edit-with-explanations UX preserved). Retire `review`'s `pre_submit`/`post_apply`/resubmit hooks in favor of loop-native behavior. To be expanded at M3 start.

## M4 — port voice_apply; delete skill_runner; cleanup (sketch)

Port `voice_apply` similarly — including an explicit `source(ctx)` that composes its SKILL.md (`ctx.skill_md`) + the per-slug style guide, replacing the v1 `system_prompt` (the disk provider has no `system_prompt` fallback — that branch was removed in M1, so `voice_apply` must carry an explicit `source` once `skill_runner` is gone). Delete `skill_runner.run` + `_in_flight`/resubmit/hardcoded `tool_choice`/`max_tokens`/`REVIEW_EDIT_TOOL` + the now-unused `system_prompt` fields. Reconcile callers: `skill_picker.lua` (`:22,28,86` — repoint to activation, keep the arg picker), `review.lua` shim (`:43`), `keybinding_registry.lua` (hotkey → activate a `manual` skill). **Resolve glob/list_dir (Design note 2):** they don't exist; decide whether `repo_discovery` needs a structured glob tool vs. existing `ls`/`find`/`grep` — lean YAGNI (no new tool without a consumer); record the decision. To be expanded at M4 start.

## M5 — repo_discovery virtual skill (the #116 bridge) (sketch)

A `VirtualProvider` generator emitting `repo_discovery` (`scope=repo`, `activation={always=true}`, `tools=<read set>`, `source = function(ctx) return require("parley").discovery.current():render() end`). Always-loaded in repo mode; its body is the #116 noun-vocabulary. **Requires #116 M1 on the base** (Design note 3 — confirm merge ordering with operator). The conflict-free merge point: situational facts only. To be expanded at M5 start.

---

## Notes for the executor

- **The pure core is `skill_manifest.lua` + `skill_assembly.lua` (M2) + `skill_edits.lua` (M3).** Keep them IO-free with colocated specs so the purity boundary is visible (the milestone judge greps the entity table against the diff). Providers/registry/active-state/tools are the thin IO seam.
- **Don't re-fork disk vs virtual.** The whole point is one `source(ctx)` contract; `read_skill` calls `manifest.source(ctx)` and never branches on origin (`ARCH-DRY`). The disk/virtual difference lives entirely inside how the *provider* built the closure.
- **Reuse, don't re-implement** (`ARCH-DRY`): the tool registry/dispatcher (`tools/init.lua`, `tools/dispatcher.lua`), the cwd-bypass pattern (`chat_history_search.lua`), the per-buffer-state pattern (`tool_loop.lua:36`), the agent-resolution cascade + arg picker + scan structure salvaged from `skill_runner`/`skill_picker`. Name the existing thing in each task.
- **The deletion of `skill_runner` is M4, not earlier** — `review`/`voice_apply` must already run through the loop (M3) before their old engine is removed, or the skills break mid-stream.
- **#129 is the next issue, not a task here.** The `tools`/`elevated` split + the `assemble_turn` gate-point are the hooks it will use; don't build the permission model now (YAGNI).

---

## Revisions

### 2026-06-12 — M1 boundary-review (FIX-THEN-SHIP → addressed)

M1 implemented (Tasks 1–6); boundary review **FIX-THEN-SHIP** (no Critical; "no
engine change" verified — `skill_runner` untouched, its spec 9/9). Findings were
plan-doc traceability drift + minors, addressed:

- **`resolve_agent` deferred M1 → M2** (Important): the Core-concepts table now
  marks it `(M2)`, locates it in `skill_assembly.lua` (its consumer), and
  commits M2 to salvaging it as a **pure function of injected config**
  (`(config, skill) → agent`) so the core stays pure (`ARCH-PURE`) — reconciling
  the earlier "PURE" label with the deferral's "reads the parley module" note.
- **Registry cache not built** (YAGNI): dropped the "cache" claim from the
  Integration-points table + the SkillRegistry prose; `discover`/`current`
  recompute per call (add a cache only when a consumer needs it).
- **DiskProvider candidate-manifest docstring** softened — `disk():list()` may
  emit a `source = nil` candidate for a dir with a name but no body; the
  registry is the single validate-drop point.

### 2026-06-12 — M1 re-judge (2nd round; FIX-THEN-SHIP → addressed)

- **Removed the v1 `system_prompt` source fallback (branch #3).** The re-judge
  found it mislabeled: it called `def.system_prompt(ctx)` (1 arg) but v1's
  contract is 4-arg `(args, file_path, content, skill_md)`. Rather than repair a
  branch no bundled skill hits (all ship SKILL.md → branch #2) and that M4
  retires anyway, it was **deleted**. Source priority is now explicit-fn →
  SKILL.md; a dir with neither → `source = nil` → registry validate-drops it.
  The test is the **source-less-candidate** (`bodyless`) case, not a
  `system_prompt` fixture. `voice_apply`'s dynamic body gets an explicit
  `source(ctx)` when ported in M4 (M4 sketch updated).
- **Closed the `pcall` error-path coverage gaps**: added a disk test (an
  `init.lua` that throws at load → that dir skipped, the rest still listed) and
  a virtual test (an erroring generator → skipped, valid manifests survive) —
  the robustness contracts the code/Task-3 log claimed but didn't pin.
- Minor: `fs_stat` existence checks (no double full-read); `atlas/index.md` §8
  redesign note.
