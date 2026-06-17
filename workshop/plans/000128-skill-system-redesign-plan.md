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

> **Re-scoped (2026-06-15/16).** The entities below reflect the P2 (artifact-mode)
> direction: **P1's chat loop is untouched** and the "shared kernel" is the
> *existing* dispatcher/tools layer. Dropped from the original (M1-era) set:
> `assemble_turn`, `ActiveSkills`, the `read_skill` tool, the chat-loop turn hook
> — those built skills into the *chat* loop (the premature P1/P2 conflation).

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `SkillManifest` (shape + `validate`) | `lua/parley/skill_manifest.lua` | done (M1) |
| `compute_edits` (salvaged, pure) | `lua/parley/skill_edits.lua` | new (M2) — moved from `skill_runner.lua:54` |
| `build_invocation` (manifest + body + doc → invocation) | `lua/parley/skill_assembly.lua` | new (M2) |
| `resolve_agent` (salvaged cascade, pure given injected config) | `lua/parley/skill_assembly.lua` | new (M2) — moved from `skill_runner.lua:284` |

- **SkillManifest** (done, M1) — the declarative description of one **P2 skill**: `{ name, description, scope, activation, source, tools, elevated, force_tool?, args?, agent? }`. `validate(m)` returns `(true)` or `(false, err)`.
  - `source` = `function(ctx) → string` (the body — unified across disk/virtual); `tools` granted whenever the skill is invoked; `elevated` granted only on **manual** invocation (the #129 hook); `force_tool` compels a tool (e.g. `propose_edits`); `args` = the completable-arg picker. **Re-scope note:** `scope` + `activation.auto/always` were for the dropped chat-menu idea; for P2 they trim toward "how a skill is surfaced in the artifact-workbench UI" (revisit when the P2 UI lands — not M2).
  - **DRY rationale:** one manifest shape across all providers; `discover` reads one shape. **Future extensions:** #129 reads `tools`/`elevated`.
- **compute_edits** (M2, salvaged from `skill_runner.lua:54-109`) — pure: `(content, edits) → {ok, msg, content, applied}`; validates uniqueness, applies in reverse position order. The single source of the batch-edit transform; the `propose_edits` tool handler (IO) wraps it; `skill_runner.apply_edits` delegates to it until M4 deletes `skill_runner`.
  - **DRY rationale:** one batch-edit transform, two callers (the tool + the v1 path) until v1 goes. **Future extensions:** none expected — stable.
- **build_invocation** (M2) — pure: `(manifest, {body, document, manual?}) → {system_prompt, messages, tools, tool_choice}`. The **P2 context-assembler** — turns a skill + the artifact text into the LLM-call inputs the thin driver (M3) feeds to `prepare_payload`. `tools` = `manifest.tools` ∪ (`elevated` only when `manual`); `tool_choice` from `force_tool`. The `source()` IO stays in the driver — `body` is passed in, so this is pure.
  - **DRY rationale:** the one place "skill → call inputs" is decided; testable without an LLM. **Future extensions:** when P2 goes recursive, it grows a "messages-so-far" param; #129 filters `tools` here.
- **resolve_agent** (M2, salvaged from `skill_runner.lua:284-322`) — the agent cascade (per-skill config → `review_agent` legacy → manifest default → global `skill_agent` → first tool-capable). v1's copy reads the parley module (not pure); **M2 salvages it as a pure function of *injected* `config`** (`(config, manifest) → agent`) so the core stays pure and the config read lives at the driver boundary (`ARCH-PURE`).

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `DiskProvider` | `lua/parley/skill_providers.lua` | done (M1) | filesystem scan (`vim.loop.fs_scandir`) |
| `VirtualProvider` | `lua/parley/skill_providers.lua` | done (M1) | runtime-generated manifests |
| `SkillRegistry` (`discover`/`get`/`names`) | `lua/parley/skill_registry.lua` | done (M1) | provider union |
| `propose_edits` tool | `lua/parley/tools/builtin/propose_edits.lua` | new (M2) | file write (via the dispatcher's cwd-scope + backup) |
| `skill_invoke` (the thin P2 driver) | `lua/parley/skill_invoke.lua` | new (M3) | the existing dispatcher layer (`prepare_payload`/`query`/`execute_call`) |

- **DiskProvider / VirtualProvider / SkillRegistry** (done, M1) — the disk closure-`source` (kills the `debug.getinfo` dance) + virtual seam + the `discover` union (last-wins dedup). Unchanged by the re-scope; they describe the available P2 skills.
- **propose_edits tool** (M2) — a **real registered builtin** (`BUILTIN_NAMES`), `kind="write"`, `needs_backup=true`, schema `{file_path, edits:[{old_string,new_string,explain}]}` (salvaged from `REVIEW_EDIT_TOOL`). Handler applies the batch via `skill_edits.compute_edits` (read→compute→write). **This is the unification's keystone:** P2's edit-apply now flows through the *same* `dispatcher.execute_call` path (with cwd-scope + backup) as every chat tool, instead of `skill_runner`'s special-cased `apply_edits`. The diagnostics/highlights rendering stays driver-side (M3), not in the handler.
  - **Injected into:** `BUILTIN_NAMES` (`tools/init.lua`); granted via a skill's `tools`/`elevated`, compelled via `force_tool`. Tested with a temp-file fixture (no LLM).
- **skill_invoke** (M3, the thin P2 driver) — replaces `skill_runner.run`'s bespoke pipeline by **riding the existing dispatcher layer**: `resolve_agent` → source the body (`manifest.source(ctx)`) → read the artifact buffer → `build_invocation` (pure) → `dispatcher.prepare_payload` + set `tool_choice` → `dispatcher.query` → decode → `dispatcher.execute_call` per tool → reload + render (`highlight_edits`/`attach_diagnostics`, salvaged). **Does NOT touch `chat_respond`** — it's a second driver on the shared primitives, not a refactor of the first.
  - **Injected into:** `skill_picker` + the `review`/`voice_apply` invocation paths (M3/M4). Tested with parley's existing LLM fake (the `chat_respond` integration-spec pattern — reused, not reinvented).

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

> **The M2–M5 below supersede the original (M1-era) sketches**, per the
> 2026-06-15 RE-SCOPE (see `## Revisions` + `workshop/pensive/parley-two-modes-chat-vs-artifact.md`).
> Scope confirmed with operator 2026-06-16: **P1's chat loop stays untouched;
> the "shared kernel" is the *existing* dispatcher/tools layer**
> (`prepare_payload`/`query`/`decode`/`execute_call`); **P2 gets a thin driver
> that rides it** instead of `skill_runner`'s bespoke copies; **`propose_edits`
> becomes a real registered tool** so P2's edit-apply flows through the same
> `execute_call` path as every chat tool. No new shared-loop kernel is built.

## M2 — `propose_edits` tool + the pure P2 context-assembler

The fully **unit-testable** shared pieces, with **no LLM call and no chat-loop
change**: salvage the pure edit logic, register `propose_edits` as a real tool,
and build the pure "skill → invocation" assembler. The IO driver that wires
these to the dispatcher + ports `review` is **M3** (it needs the LLM fake).

**Module layout:** new pure modules `lua/parley/skill_edits.lua` (compute_edits)
and `lua/parley/skill_assembly.lua` (build_invocation + resolve_agent); new tool
`lua/parley/tools/builtin/propose_edits.lua`. Specs flat in `tests/` per
convention. Per-task TDD runs use the direct plenary form:
`nvim --headless -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/<spec>.lua"`.

### Task 1: `skill_edits.compute_edits` — salvage the pure edit logic (PURE)

**Files:**
- Create: `lua/parley/skill_edits.lua`
- Modify: `lua/parley/skill_runner.lua` (delegate its `compute_edits`/`apply_edits` to the new module — keep the v1 path working until M4 deletes it; `ARCH-DRY`, one source)
- Test: `tests/unit/skill_edits_spec.lua`

- [x] **Step 1: Write failing tests** — `M.compute_edits(content, edits)` returns `{ok, msg, content, applied}` (exact behavior salvaged from `skill_runner.lua:54-109`):
  - happy path: two edits applied in reverse-position order; `content` reflects both; `applied` lists `{pos, old_string, new_string, explain}`.
  - `old_string` not found → `{ok=false, msg~="not found"}`.
  - `old_string` not unique → `{ok=false, msg~="not unique"}`.
  - non-string `old_string`/`new_string` → `{ok=false}`. _(+ atomic: a failing edit rejects the whole batch, content=nil.)_
- [x] **Step 2: Run, verify fail** (module missing).
- [x] **Step 3: Implement** — move `compute_edits` verbatim from `skill_runner.lua:54` into `skill_edits.lua` (pure; no IO). In `skill_runner.lua`, replace its body with `return require("parley.skill_edits").compute_edits(...)` and have `apply_edits` call the module (so `skill_runner_spec` + the live v1 path stay green — single source of the edit logic).
- [x] **Step 4: Run, verify pass** — the new spec **and** `tests/unit/skill_runner_spec.lua` (regression — v1 delegation intact). _5/5 + 9/9._
- [x] **Step 5: Commit** — `#128 M2: skill_edits.compute_edits (salvage pure edit logic, DRY)`. _92abf4c_

### Task 2: `propose_edits` real builtin tool (INTEGRATION — file write)

**Files:**
- Create: `lua/parley/tools/builtin/propose_edits.lua`
- Modify: `lua/parley/tools/init.lua` (add `"propose_edits"` to `BUILTIN_NAMES`)
- Test: `tests/integration/tools_builtin_propose_edits_spec.lua`

- [x] **Step 1: Write failing test** (temp-file fixture): a `ToolDefinition` with `name="propose_edits"`, `kind="write"`, `needs_backup=true`, `input_schema` = `{file_path, edits:[{old_string,new_string,explain}]}` (the salvaged `REVIEW_EDIT_TOOL` schema). handler applies the batch (file reflects edits, `is_error=false`, count reported); non-unique → `is_error=true`, no write; missing `file_path`/`edits` → `is_error=true`; `validate_definition` passes. _Spec in `tests/unit/` to match the `tools_builtin_*_spec` convention (not `tests/integration/`)._
- [x] **Step 2: Run, verify fail.**
- [x] **Step 3: Implement** the tool, modeled on `write_file.lua`/`edit_file.lua` (cwd-scope via `file_path` + the M5 backup prelude via `needs_backup` are the dispatcher's job — no special-casing). Handler: read → `skill_edits.compute_edits` → write → checktime. Add `"propose_edits"` to `BUILTIN_NAMES`.
- [x] **Step 4: Run, verify pass** — new spec (5/5) + `tools_builtin_registered_spec` (10/10, now a registered builtin).
- [x] **Step 5: Commit** — `#128 M2: propose_edits builtin (P2 edit-apply via the shared dispatch path)`. _6d54d2e_

### Task 3: `skill_assembly` — pure P2 context-assembler + `resolve_agent` (PURE)

**Files:**
- Create: `lua/parley/skill_assembly.lua`
- Test: `tests/unit/skill_assembly_spec.lua`

- [x] **Step 1: Write failing tests:**
  - `M.build_invocation(manifest, opts)` where `opts = {body, document, manual?}` → `{system_prompt, messages, tools, tool_choice}` (PURE — `body` already-sourced; `source()` IO stays in the M3 driver): system_prompt==body; messages == system+user; tools = `manifest.tools` ∪ (`elevated` only when `manual`); tool_choice from `force_tool` else nil.
  - `M.resolve_agent(manifest, deps)` → agent (salvaged cascade, **pure function of injected deps** = config + agent registry): assert each tier (per-skill → legacy review_agent → manifest default → global skill_agent → first tool-capable); unknown → nil.
- [x] **Step 2–4:** fail → implement both (pure; no `require("parley")` — deps injected) → pass. _9/9 (signature: `resolve_agent(manifest, deps)`; deps = {config, get_agent, agent_names, agents})._
- [x] **Step 5: Commit** — `#128 M2: skill_assembly (pure invocation builder + injected-config resolve_agent)`. _9d20e8f_

### Task 4: Atlas + milestone close

- [x] **Step 1:** Update `atlas/skills/skill-system.md` — the M2 pieces (`propose_edits` real tool, `skill_edits`, `skill_assembly`) + the "P2 rides the existing dispatcher; chat loop untouched" framing. _(Also rewrote the stale chat-turn Redesign section to the re-scope.)_
- [x] **Step 2:** Update `atlas/traceability.yaml` (`skills/skill-system` → add the new modules + specs).
- [x] **Step 3:** `make test` green; `make lint` clean. _lint 0/0 (197 files), 103 spec files pass._
- [x] **Step 4:** `sdlc milestone-close --issue 128 --milestone M2`. _Boundary review **FIX-THEN-SHIP** (no Critical) → addressed (drop redundant system_prompt; pin cwd-scope keystone; correct backup-pending docs + flag M3). Actual recorded as a labeled ~1h estimate (cf #128 M1's 0.90h) — the auto-measure 9.67h is rebase-contaminated (orphaned base → cross-issue window)._
- [x] **Step 5: Commit** — `#128 M2: atlas + traceability` (+ the FIX-THEN-SHIP fixes).

**M2 Done when:** `propose_edits` is a registered builtin that applies batch edits via the dispatcher path; `skill_edits.compute_edits` is the single source of the edit logic (v1 delegates); `skill_assembly.build_invocation`/`resolve_agent` are pure + tested; suite green; **chat loop + `skill_runner.run` untouched** (v1 still works).

## M3 — the thin P2 driver + port `review` (sketch)

**Prerequisite (M2 boundary-review carry):** before `review` applies destructive edits through `propose_edits`, **secure a backup** — either add an inline numbered `.parley-backup` to `propose_edits.handler` (the `write_file.lua:40-63` pattern) or land the dispatcher's write-path prelude. `needs_backup=true` is currently classification-only (the dispatcher doesn't honor it yet).

Build `lua/parley/skill_invoke.lua` — the thin P2 driver that **reuses the existing dispatcher layer**: resolve agent (`skill_assembly.resolve_agent`), source the skill body (`manifest.source(ctx)` — IO), read the artifact buffer, `build_invocation` (pure, M2) → `dispatcher.prepare_payload(messages, model, provider, tools)` + set `payload.tool_choice` → `dispatcher.query` → on_exit decode → `dispatcher.execute_call` per tool (so `propose_edits` applies through the shared path) → reload buffer + render via the salvaged `highlight_edits`/`attach_diagnostics`. Single-shot now (the `review` resubmit loop → a bounded recursive option later). **Port `review`** to invoke via this driver (its M1 manifest already declares `tools`/`elevated`/`force_tool=propose_edits`); preserve the marker pre-check + batch-edit-with-explanations UX. **Test with parley's existing LLM fake** (the pattern the `chat_respond` integration specs use — reuse it, don't invent a new one; `ARCH-DRY`). `skill_runner.run` stays alive in parallel until M4. To be expanded at M3 start.

## M4 — port `voice_apply`; delete `skill_runner`; cleanup (sketch)

Port `voice_apply` via the driver — give it an explicit `source(ctx)` composing `ctx.skill_md` + the per-slug style guide (the disk provider has no `system_prompt` fallback — removed in M1). **Delete `skill_runner`** (`run`/`_in_flight`/resubmit/hardcoded `tool_choice`/`max_tokens`/`REVIEW_EDIT_TOOL` + the leftover `compute_edits`/`apply_edits` delegations + `system_prompt` fields). Reconcile callers: `skill_picker.lua` (`:22,28,86` → invoke via the driver, keep the arg picker), `review.lua` shim (`:43`), `keybinding_registry.lua`. **glob/list_dir (Design note 2):** they don't exist; this is a YAGNI *decision* — `ls`/`find`/`grep` suffice for P1; record it, don't hunt for files. To be expanded at M4 start.

## ~~M5 — repo_discovery virtual skill~~ — DROPPED (re-scope)

`repo_discovery` is **P1 context/tools, not a P2 skill** (category error — see Revisions / pensive). #116's registry feeds P1's chat context directly; that work belongs to the future **P1 issue** ("parley chat as ariadne workbench"), not this issue.

---

## Notes for the executor

- **The pure core is `skill_manifest.lua` + `skill_assembly.lua` (M2) + `skill_edits.lua` (M3).** Keep them IO-free with colocated specs so the purity boundary is visible (the milestone judge greps the entity table against the diff). Providers/registry/active-state/tools are the thin IO seam.
- **Don't re-fork disk vs virtual.** The whole point is one `source(ctx)` contract; `read_skill` calls `manifest.source(ctx)` and never branches on origin (`ARCH-DRY`). The disk/virtual difference lives entirely inside how the *provider* built the closure.
- **Reuse, don't re-implement** (`ARCH-DRY`): the tool registry/dispatcher (`tools/init.lua`, `tools/dispatcher.lua`), the cwd-bypass pattern (`chat_history_search.lua`), the per-buffer-state pattern (`tool_loop.lua:36`), the agent-resolution cascade + arg picker + scan structure salvaged from `skill_runner`/`skill_picker`. Name the existing thing in each task.
- **The deletion of `skill_runner` is M4, not earlier** — `review`/`voice_apply` must already run through the loop (M3) before their old engine is removed, or the skills break mid-stream.
- **#129 is the next issue, not a task here.** The `tools`/`elevated` split + the `assemble_turn` gate-point are the hooks it will use; don't build the permission model now (YAGNI).

---

## Revisions

### 2026-06-16 — M2 boundary review (FIX-THEN-SHIP → addressed)

M2 implemented (`skill_edits` / `propose_edits` / `skill_assembly`) + closed;
boundary review **FIX-THEN-SHIP** (no Critical). Findings addressed:
- **`build_invocation` dropped the redundant `system_prompt` field** — the body
  is conveyed as the `role="system"` message (the adapter extracts it); a
  separate field would double-apply in the M3 driver.
- **Pinned the cwd-scope keystone** — added a `dispatcher.execute_call` test
  (file_path inside cwd → applies; outside → refused), since the handler-only
  tests bypassed the dispatcher (the whole reason `propose_edits` is a real tool).
- **Backup claim corrected** — `needs_backup=true` is the right *classification*
  (propose_edits destroys content) but the dispatcher's backup prelude is
  deferred, so backup is NOT active yet. Atlas reworded to "cwd-scope now; backup
  pending." **M3 must secure a backup** (inline like `write_file`, or via the
  prelude) before `review` applies destructive edits through the tool.
- Minor (noted, not fixed): empty-`edits` no-op rewrite; `build_invocation` tool
  dedup (harmless — `tools.select` dedups).

### 2026-06-15 — RE-SCOPED (M1 stands; M2–M5 below are STALE pending re-plan)

The issue was re-scoped (see `workshop/issues/000128-…` `## Revisions` +
`workshop/pensive/parley-two-modes-chat-vs-artifact.md`). Parley has **two
modes**: P1 chat-as-ariadne-workbench (read-only, tools, transcript) and P2
artifact-workbench (the markdown file is the subject; *skills* construct context
+ mutation tools; single-shot→recursive; multi-headed). **Skill = P2 only; tools
= both.** The original "skills configure a chat turn" was premature.

Effect on this plan:
- **M1 stands** (manifest + providers + registry; done, boundary-clean) — now
  understood as the **P2-skill descriptor + discovery**. Its chat-flavored fields
  (`scope`, `activation.auto/always`) will trim to "how a skill is surfaced in
  the P2 UI."
- **M2–M5 below are STALE.** The new direction: **extract one shared
  context-assembler + recursive tool-loop** that both `chat_respond` (P1) and the
  P2 skill driver call (the real DRY win — `skill_runner` deletes); port
  `review`/`voice_apply` to drive it on the artifact via a `propose_edits`
  mutation tool. **Dropped:** `read_skill`-in-chat, `auto`/`always` chat
  activation, `repo_discovery`-as-skill (that's P1 context). The Core-concepts +
  M2–M5 sections above predate this and need a fresh `superpowers-writing-plans`
  pass when we resume — do not execute them as written.

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
