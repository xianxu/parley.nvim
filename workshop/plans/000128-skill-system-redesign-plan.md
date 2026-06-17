# Skill System Redesign Implementation Plan (#128)

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Delete parley's duplicate execution engine (the single-shot forced-write `skill_runner`) by having the **P2 artifact-workbench** skills reuse the *existing* dispatcher/tools layer through a thin driver. A *skill* is a declarative `SkillManifest`; the **P1 chat loop is untouched**. (Re-scoped 2026-06-15/16 — see `## Revisions`; the original "one engine = the chat loop, skills configure a chat turn" framing was a premature P1/P2 conflation.)

**Architecture:** A skill is data, not a pipeline: a `SkillManifest` (`name/description/scope/activation/source/tools/elevated/force_tool/args`). Uniform-manifest *providers* (plugin/user disk + virtual) are unioned by `discover` into a registry. The salvaged batch-edit logic becomes a real `propose_edits` builtin, so P2's edit-apply flows through the *same* `execute_call` dispatch path as every chat tool. A thin **`skill_invoke`** driver runs one tool-use exchange on an artifact by reusing the existing dispatchers (`prepare_payload`/`query`/`execute_call`) — a *second* driver beside the chat loop, **not** a refactor of it. `review`/`voice_apply` run through `skill_invoke`; `skill_runner` is then deleted (M4).

**Tech Stack:** Lua (Neovim plugin), `plenary.nvim` headless test harness (per-spec `nvim --headless -u tests/minimal_init.vim -c "PlenaryBustedFile …"`), the existing `lua/parley/tools/` registry + chat tool loop. Follows parley module conventions (`local M = {} … return M`) and mirrors the validation style of `lua/parley/tools/types.lua` / `lua/parley/discovery/descriptor.lua`.

---

## Scope & milestones

> **RE-SCOPED 2026-06-15/16 (see `## Revisions`).** Parley has two modes —
> P1 (chat-as-ariadne-workbench) and P2 (artifact-workbench); **skill = P2 only**;
> **P1's chat loop is UNTOUCHED**; the "shared kernel" is the *existing*
> dispatcher/tools layer (P2 gets a thin driver that rides it). The bullets below
> are the re-scoped milestones (they supersede the original one-engine /
> read_skill-in-chat framing). The authoritative per-milestone detail is in the
> `## M1`…`## M4` sections + the boundary-review entries in `## Revisions`.

This is a large, integration-heavy redesign ("the main event"). Critical-path-first decomposition; each `Mx` is a **review boundary** (its own `sdlc milestone-close`).

- **M1 — Declarative manifest + provider-based discovery (done).** `SkillManifest` shape + `validate`; the unified `source(ctx)` closure (kills the `debug.getinfo` dance); providers (plugin/user disk + virtual seam) unioned by `discover` into a registry; `review`/`voice_apply` re-expressed as manifests. No chat-loop code.
- **M2 — `propose_edits` tool + pure P2 context-assembler (done).** Salvage `compute_edits` → `skill_edits` (single source); the real `propose_edits` builtin (P2's edit-apply flows through the existing `execute_call` path); pure `build_invocation` + `resolve_agent` (`skill_assembly`). No LLM, no chat-loop change.
- **M3 — thin `skill_invoke` driver + port `review` (done).** `skill_invoke` drives one tool-use exchange on an artifact by **reusing the existing dispatchers** (a second driver, not a refactor of the chat loop); `propose_edits` gains inline backup; `review` runs through it (markers + resubmit preserved). `skill_render` salvaged.
- **M4 — port `voice_apply`; delete `skill_runner`; resolve callers + dead tools.** Port `voice_apply` (explicit `source(ctx)`); delete `skill_runner` + reconcile callers (`skill_picker` transitional branch, `review.lua`, keybindings); **glob/list_dir** = a YAGNI *decision* (Design note 2).
- **~~M5 — `repo_discovery` virtual skill~~ DROPPED** — `repo_discovery` is P1 context/tools, not a P2 skill (category error). #116 feeds P1 directly; that's a future P1 issue.

**#129** (capability permission model) layers onto the `tools`/`elevated` fields *after* this issue — out of scope here; the fields are the hook.

### Design notes (decisions that shaped this plan)

1. **P2 rides the existing dispatcher; P1's chat loop is untouched.** The "shared kernel" is the *existing* dispatcher/tools layer (`prepare_payload`/`query`/`execute_call`) that P1 already uses; M3's `skill_invoke` is a *second* driver on it — no new shared-loop kernel, no `chat_respond` change. *(This supersedes the original Design note 1, which proposed injecting skill state into the chat loop's per-turn assembly — dropped with the re-scope.)*
2. **`glob.lua`/`list_dir.lua` do not exist** — the issue's "present in `builtin/` but not in `BUILTIN_NAMES`" is stale. `builtin/` holds `ls.lua` + `find.lua` (both registered). So M4's task is **not** dead-code cleanup; it's a YAGNI decision: does P2 need a new structured glob tool, or do `ls`/`find`/`grep` suffice? (Lean: suffice — don't add a tool without a consumer.)
3. **#116 is merged.** M1+M2 of this issue (and #116's discovery registry) are on `main`; the original "merge ordering vs. the unmerged `000116` branch" note is moot. (`repo_discovery`-as-skill is dropped anyway — see M5.)

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
| `skill_render` (salvaged diagnostics/highlights) | `lua/parley/skill_render.lua` | new (M3) | buffer diagnostics + highlights (vim API) |

- **DiskProvider / VirtualProvider / SkillRegistry** (done, M1) — the disk closure-`source` (kills the `debug.getinfo` dance) + virtual seam + the `discover` union (last-wins dedup). Unchanged by the re-scope; they describe the available P2 skills. **(M4 modifies DiskProvider:** for a skill with an explicit `source(ctx)`, it enriches `ctx.skill_md` from the captured `<dir>/SKILL.md` so a dynamic body — `voice_apply` — can compose `SKILL.md ⊕ <extra>` without re-deriving the dir.)
- **propose_edits tool** (M2) — a **real registered builtin** (`BUILTIN_NAMES`), `kind="write"`, `needs_backup=true`, schema `{file_path, edits:[{old_string,new_string,explain}]}` (salvaged from `REVIEW_EDIT_TOOL`). Handler applies the batch via `skill_edits.compute_edits` (read→compute→write). **This is the unification's keystone:** P2's edit-apply now flows through the *same* `dispatcher.execute_call` path (with cwd-scope + backup) as every chat tool, instead of `skill_runner`'s special-cased `apply_edits`. The diagnostics/highlights rendering stays driver-side (M3), not in the handler.
  - **Injected into:** `BUILTIN_NAMES` (`tools/init.lua`); granted via a skill's `tools`/`elevated`, compelled via `force_tool`. Tested with a temp-file fixture (no LLM).
- **skill_invoke** (M3, the thin P2 driver) — replaces `skill_runner.run`'s bespoke pipeline by **riding the existing dispatcher layer**: `resolve_agent` → source the body (`manifest.source(ctx)`) → read the artifact buffer → `build_invocation` (pure) → `dispatcher.prepare_payload` + set `tool_choice` → `dispatcher.query` → decode → `dispatcher.execute_call` per tool → reload + render (via `skill_render`). Exposes an `on_done(result)` hook so callers (review) run post-apply logic (its resubmit loop). **Does NOT touch `chat_respond`** — it's a second driver on the shared primitives, not a refactor of the first.
- **skill_render** (M3) — `clear_decorations`/`attach_diagnostics`/`highlight_edits`, salvaged out of `skill_runner.lua:112-163` into their own module so `skill_invoke` doesn't depend on the to-be-deleted `skill_runner` (`ARCH-DRY` — `skill_runner` then delegates to it, like `compute_edits`). Thin vim-API/UI wrapper (not pure).
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

## M3 — the thin P2 driver + port `review`

The first time the M2 pieces go *live*: a thin `skill_invoke` driver that drives
one LLM tool-use exchange on an artifact by **reusing the existing dispatcher**
(`prepare_payload`/`query`/`execute_call`), and `review` ported onto it. The chat
loop (`chat_respond`) and `skill_runner.run` are **untouched** — `skill_invoke`
is a *second* driver on the shared dispatcher; `skill_runner` stays live for
`voice_apply` until M4.

**Design decisions (resolved at plan time; cite in Log):**
- **Backup = inline numbered `.parley-backup` in `propose_edits`** (the
  `write_file.lua:40-63` pattern). `propose_edits` is destructive but
  `needs_backup` is a dispatcher no-op today; rather than block on the
  (deferred) write-path prelude, self-back-up inline now — safe, M3-scoped,
  matches the established `write_file` tool. (The prelude is a future
  generalization; YAGNI to wait for it.) **Task 1.**
- **`review`'s marker logic stays in `review/init.lua`.** `parse_markers` + the
  pre-submit gate (abort if no ready markers / pending questions) + the
  resubmit-up-to-3 loop are review-specific; they stay in the skill and *wrap*
  `skill_invoke` (which runs one generic exchange). Don't bake marker semantics
  into the driver (`ARCH-PURE`/separation). The resubmit loop = re-call
  `skill_invoke` (replacing `post_apply`'s `skill_runner.run` recursion).
- **Test with parley's existing LLM fake** — monkeypatch `parley.dispatcher.query`
  (save/restore), inject a tool-use `raw_response` into `tasker`, trigger the real
  `on_exit`/callback, exactly as `tests/integration/chat_respond_spec.lua:78-92`
  does. Reuse it; don't invent a fake (`ARCH-DRY`).
- **Picker wiring:** route `review` → `skill_invoke`; `voice_apply` still goes
  through `skill_runner.run` until M4. A small transitional branch (removed in M4).

**Module layout:** new `lua/parley/skill_invoke.lua` (the driver, INTEGRATION);
modify `lua/parley/tools/builtin/propose_edits.lua` (inline backup),
`lua/parley/skills/review/init.lua` (invoke via `skill_invoke`), and the
picker/entry that runs `review`. Specs: `tests/unit/tools_builtin_propose_edits_spec.lua`
(extend — backup), `tests/integration/skill_invoke_spec.lua`,
`tests/integration/skill_invoke_review_spec.lua`.

### Task 1: `propose_edits` inline backup (the destructive-edit safety prereq)

**Files:**
- Modify: `lua/parley/tools/builtin/propose_edits.lua`
- Test: `tests/unit/tools_builtin_propose_edits_spec.lua` (extend)

- [x] **Step 1: Write failing test** — before overwriting, the handler writes the prior content to the next free `<file_path>.parley-backup.<n>` (numbered, like `write_file`): apply an edit to a temp file that has prior content → assert `<path>.parley-backup.1` exists with the *original* content, and a second apply creates `.parley-backup.2`. A failed `compute_edits` (non-unique) writes **no** backup (no destructive write happened).
- [x] **Step 2: Run, verify fail.**
- [x] **Step 3: Implement** — port the numbered-backup block from `write_file.lua:40-63` into the handler, *before* the write, *after* `compute_edits` succeeds (so an invalid batch leaves no backup). Update the tool header + `atlas` to state backup is now active inline. Keep `needs_backup=true` (still the right classification; the future prelude can supersede the inline copy).
- [x] **Step 4: Run, verify pass** (propose_edits spec, incl. the M2 cwd-scope tests — regression).
- [x] **Step 5: Commit** — `#128 M3: propose_edits inline backup (write_file pattern)`.

### Task 2: `skill_invoke` — the thin one-exchange P2 driver (INTEGRATION)

**Files:**
- Create: `lua/parley/skill_invoke.lua`
- Test: `tests/integration/skill_invoke_spec.lua`

The driver, riding the existing dispatcher (no chat-loop touch):
```lua
-- skill_invoke.invoke(buf, manifest, args, opts?)  opts.manual defaults true
--   ctx        = { args = args, repo_root = config.repo_root, ... }
--   body       = manifest.source(ctx)                         -- IO (disk/virtual)
--   document   = table.concat(nvim_buf_get_lines(buf), "\n")  -- IO
--   inv        = skill_assembly.build_invocation(manifest, { body, document, manual })
--   agent      = skill_assembly.resolve_agent(manifest, {     -- deps from live parley
--                  config = P.config, get_agent = P.get_agent,
--                  agent_names = P._agents, agents = P.agents })
--   payload    = dispatcher.prepare_payload(inv.messages, agent.model, agent.provider, inv.tools)
--   payload.tool_choice = inv.tool_choice                     -- force_tool
--   skill_render.clear_decorations(buf)
--   dispatcher.query(nil, agent.provider, payload, handler, on_exit, nil, nil, on_abort)
--     -- buf=nil: headless (no streaming buffer insertion); the artifact buffer
--     -- is reloaded in on_exit after execute_call writes the file (checktime)
--     on_exit(qid): qt = tasker.get_query(qid)
--       calls = providers.decode_anthropic_tool_calls_from_stream(qt.raw_response)
--       for each call: dispatcher.execute_call(call, tools_registry, { cwd = getcwd() })
--         -- propose_edits applies through the shared path (cwd-scope + the Task-1 backup)
--       reload buffer (checktime), then render the applied edits via the salvaged
--       highlight_edits/attach_diagnostics (move those + clear_decorations into a
--       small `skill_render` module, OR call skill_runner's until M4 — see note)
--       invoke opts.on_done(result) so callers (review) can run post-apply logic
```

- [x] **Step 1: Write failing test** (reuse the `chat_respond_spec.lua:78-92` monkeypatch of `parley.dispatcher.query`, save/restore in `after_each`). **Two fixtures to reuse (don't hand-roll):** (a) build the tool-use `raw_response` with the SSE-builder helper in `tests/unit/anthropic_tool_decode_spec.lua` (~line 38 — "build a raw SSE response from a list of event objects") so it decodes via `providers.decode_anthropic_tool_calls_from_stream` to **one `propose_edits` call** editing the buffer's file; (b) since `dispatcher.query` fires `on_exit` via `vim.schedule`, **`vim.wait()` for `opts.on_done`** before asserting (per `chat_respond_spec` ~line 100). Assert: file edited (via the real `execute_call` path), a `.parley-backup` made (Task 1), `on_done` ran with the applied result. Second test: a `force_tool` manifest sets `payload.tool_choice`.
- [x] **Step 2: Run, verify fail.**
- [x] **Step 3: Implement** `skill_invoke.invoke`. Reuse `skill_assembly` (M2), `dispatcher.*`, `providers.decode_anthropic_tool_calls_from_stream`, `tasker.get_query`. **Salvage the rendering**: extract `highlight_edits`/`attach_diagnostics`/`clear_decorations` from `skill_runner.lua:112-163` into a small `lua/parley/skill_render.lua` (so the driver doesn't depend on the to-be-deleted `skill_runner`; `ARCH-DRY` — `skill_runner` then delegates to it, like `compute_edits`).
- [x] **Step 4: Run, verify pass.**
- [x] **Step 5: Commit** — `#128 M3: skill_invoke driver (one exchange on the shared dispatcher)`.

### Task 3: port `review` onto `skill_invoke` (INTEGRATION)

**Files:**
- Modify: `lua/parley/skills/review/init.lua` (invoke via `skill_invoke`; keep `parse_markers` + pre-check + resubmit)
- Modify: `lua/parley/skill_picker.lua` (route `review` → `skill_invoke`; others → `skill_runner.run`) and/or `lua/parley/review.lua` shim
- Test: `tests/integration/skill_invoke_review_spec.lua`

- [x] **Step 1: Write failing test** (same LLM fake + SSE-builder + `vim.wait` as Task 2): a buffer with one *ready* `🤖…[…]` marker → invoking `review` calls `skill_invoke` with the `review` manifest, the faked tool response applies a `propose_edits`, the buffer updates, diagnostics attach. Pre-check: a buffer with **no** markers → aborts before any query (assert the faked `dispatcher.query` was **not** called — a call counter on the fake). Resubmit: a *pending-question* marker after apply → stops (no re-invoke); a remaining *ready* marker → re-invokes (bounded at 3 — assert the counter).
- [x] **Step 2: Run, verify fail.**
- [x] **Step 3: Implement** — repoint `review`'s run path: the pre-submit marker gate runs, then `skill_invoke.invoke(buf, review_manifest, args, { manual = true, on_done = <resubmit-decider> })`; the `on_done` re-implements `post_apply`'s logic (parse markers; pending → quickfix+stop; ready & count<3 → re-invoke). Resolve the `review` manifest from `parley.skills.current():get("review")`. Wire the picker/keybinding for `review` to this path; leave `voice_apply` on `skill_runner.run`.
- [x] **Step 4: Run, verify pass** — review spec + `skill_runner_spec` (voice path still intact, 9/9).
- [x] **Step 5: Commit** — `#128 M3: port review onto skill_invoke (markers + resubmit preserved)`.

### Task 4: Atlas + milestone close

- [x] **Step 1:** Update `atlas/skills/skill-system.md` — M3 (the `skill_invoke` driver, `skill_render` salvage, `review` ported; backup now inline). Update `atlas/traceability.yaml`.
- [x] **Step 2:** `make test` green; `make lint` clean.
- [x] **Step 3:** `sdlc milestone-close --issue 128 --milestone M3`; log the verdict.
- [x] **Step 4: Commit** — `#128 M3: atlas + traceability`.

**M3 Done when:** `skill_invoke` drives a one-exchange skill on an artifact via the existing dispatcher (no `chat_respond` change); `review` runs through it end-to-end (marker pre-check + batch-edit-with-explanations + resubmit-up-to-3 preserved) with edits applied through `propose_edits` (cwd-scope + inline backup); `voice_apply` still works via `skill_runner` (9/9); suite green.

## M4 — port `voice_apply`; delete `skill_runner`; cleanup

The last milestone: move `voice_apply` onto the M3 driver, then **delete
`skill_runner`** — the duplicate execution engine this whole issue exists to
remove — and reconcile every caller. After M4 both P2 skills (`review`,
`voice_apply`) run through `skill_invoke` on the existing dispatcher; nothing
imports `skill_runner`.

**Design decisions (resolved at plan time; cite in Log):**
- **`voice_apply`'s dynamic body via `ctx.skill_md`.** `voice_apply` needs
  `SKILL.md ⊕ per-slug style guide`, but the SKILL.md path is a discovery-time
  fact known only to the *provider* (the closure captures `dir`), not the driver.
  So the **DiskProvider** enriches the `ctx` passed to an explicit `source(ctx)`
  with `ctx.skill_md` (read lazily from `<dir>/SKILL.md`). `voice_apply.source`
  then returns `ctx.skill_md .. style`. This mirrors v1's 4th `skill_md` arg
  (`skill_runner.lua:289`) without re-introducing the `debug.getinfo` dance — the
  dir is already in hand (`ARCH-DRY`/`ARCH-PURE`: IO stays in the provider seam).
- **Picker reads the registry, not `skill_runner`.** `skill_picker` lists from
  `parley.skills.current().all()` (manifests carry `args` with `complete`) and
  routes `review` → `review.run_via_invoke` (marker pre-check + resubmit),
  everything else → `skill_invoke.invoke`. The M3 transitional `skill_name=="review"`
  branch (`skill_picker.lua:18-24`) becomes the permanent two-way split; the
  `skill_runner.list_skills`/`run` calls are removed. Extract the routing into a
  testable `M.run_skill(buf, manifest, args)` seam (the float-picker UI itself
  stays untested glue).
- **`review`'s dead v1 fields go.** `review/init.lua`'s `M.skill.system_prompt`/
  `pre_submit`/`post_apply` + the `get_runner` helper were consumed only by
  `skill_runner.run`; `run_via_invoke` (M3) re-implements the marker pre-check +
  resubmit. They're dead the moment `skill_runner` is gone — delete them
  (`ARCH-DRY`, no duplicate marker logic).
- **`review.lua` shim trims to what's used.** Its `compute_edits`/`apply_edits`/
  `attach_diagnostics`/`highlight_edits` re-exports delegate to `skill_runner`
  and have **no non-test callers** (grep-verified). The IO-apply path is now the
  `propose_edits` builtin; the compute path is `skill_edits`; rendering is
  `skill_render`. Drop the four dead exports; keep the live marker/quickfix/submit
  API. The `review_spec.lua` `apply_edits` block (its only caller) is redundant
  with `tools_builtin_propose_edits_spec` + `skill_edits_spec` — remove it.
- **glob/list_dir (Design note 2) = a recorded YAGNI decision, not code.**
  `glob.lua`/`list_dir.lua` don't exist; `builtin/` has `ls`/`find` (registered)
  + `grep`. P2's artifact mode reads with `read_file` and edits with
  `propose_edits`; structured directory listing has **no consumer** in either P1
  or P2 today. **Decision: do not add a glob/list_dir tool.** Record it in the
  Log + atlas; revisit only when a concrete consumer appears.
- **Abort-teardown coverage moves with the code.** The `_in_flight`-clearing
  on_abort test (`cliproxy_caller_teardown_spec.lua:158-168`, #131) targeted
  `skill_runner`; `skill_invoke` has the same guard + on_abort. Port the test to
  `skill_invoke` and expose `M.is_in_flight(buf)` on it (the v1 helper at
  `skill_runner.lua:203`).

**Module layout:** modify `lua/parley/skill_providers.lua` (skill_md enrichment),
`lua/parley/skills/voice_apply/init.lua` + `SKILL.md` (source(ctx)),
`lua/parley/skill_picker.lua` (registry + routing), `lua/parley/skills/review/init.lua`
(drop dead v1 fields), `lua/parley/review.lua` (trim shim),
`lua/parley/skill_invoke.lua` (`is_in_flight`). **Delete**
`lua/parley/skill_runner.lua` + `tests/unit/skill_runner_spec.lua`. Specs:
`tests/integration/skill_providers_spec.lua` (extend), new
`tests/integration/voice_apply_spec.lua`, new `tests/unit/skill_picker_spec.lua`,
`tests/unit/review_spec.lua` (trim), `tests/integration/cliproxy_caller_teardown_spec.lua`
(port). Per-task TDD: `nvim --headless -u tests/minimal_init.vim -c "PlenaryBustedFile tests/<spec>.lua"`.

### Task 1: DiskProvider enriches `ctx.skill_md` for explicit `source(ctx)` (INTEGRATION)

**Files:**
- Modify: `lua/parley/skill_providers.lua` (`manifest_from_def`)
- Test: `tests/integration/skill_providers_spec.lua` (extend)

- [ ] **Step 1: Write failing test** — a fixture dir with `init.lua` returning
  `{ name=…, source = function(ctx) return "BODY=" .. (ctx.skill_md or "<none>") end }`
  **and** a `SKILL.md` containing `the-skill-md`: `providers.disk(root):list()`'s
  manifest `source({})` returns `BODY=the-skill-md` (the provider injected
  `ctx.skill_md` from the captured dir). A second assert: caller-supplied ctx
  fields survive (`source({ args = { slug = "x" } })` still sees `ctx.args.slug`).
  Regression: the SKILL.md-only branch (no `def.source`) is unchanged.
- [ ] **Step 2: Run, verify fail** (provider passes `def.source` un-enriched today).
- [ ] **Step 3: Implement** — in `manifest_from_def`, when `def.source` is a
  function, wrap it: `source = function(ctx) … end` that, if `ctx.skill_md == nil`
  and `<dir>/SKILL.md` exists, shallow-copies `ctx` and sets `skill_md` from the
  file (read via the existing `read_file` helper), then calls the inner fn. No
  mutation of the caller's table; SKILL.md read only when an explicit source needs
  it. The SKILL.md-only branch (no `def.source`) is untouched.
- [ ] **Step 4: Run, verify pass** — provider spec (incl. the M1 cases — regression).
- [ ] **Step 5: Commit** — `#128 M4: DiskProvider injects ctx.skill_md for explicit source(ctx)`.

### Task 2: port `voice_apply` to `source(ctx)` (INTEGRATION)

**Files:**
- Modify: `lua/parley/skills/voice_apply/init.lua` (`system_prompt` → `source`)
- Modify: `lua/parley/skills/voice_apply/SKILL.md` (`review_edit` → `propose_edits`)
- Test: new `tests/integration/voice_apply_spec.lua`

- [ ] **Step 1: Write failing test** — set `vim.env.HOME` to a temp dir
  (save/restore in `after_each`), write `~/.personal/myvoice-writing-style.md`
  with `STYLE-BODY`, then `parley.skills.current().get("voice-apply").source({ args = { slug = "myvoice" } })`
  returns a string containing **both** the SKILL.md body and `STYLE-BODY` under a
  `## Voice Style Guide` heading. (Exercises Task 1's `ctx.skill_md` injection +
  voice_apply's composition end-to-end through the real disk provider.) Edge: a
  missing style file → `source` errors with a clear message (the slug is bad).
- [ ] **Step 2: Run, verify fail** (voice_apply still has `system_prompt`, no `source`).
- [ ] **Step 3: Implement** — replace `voice_apply`'s `system_prompt = function(args, _file, _content, skill_md)`
  with `source = function(ctx)` reading `~/.personal/<ctx.args.slug>-writing-style.md`
  and returning `(ctx.skill_md or "") .. "\n\n## Voice Style Guide\n\n" .. style`.
  Drop the in-file M4 NOTE comment. Update `SKILL.md`: `review_edit` →
  `propose_edits` (the forced tool — same fix as M3's review I3).
- [ ] **Step 4: Run, verify pass** — voice_apply spec; `skill_registry_spec` (still
  yields a valid `voice-apply` manifest — `source` fn is the valid shape).
- [ ] **Step 5: Commit** — `#128 M4: port voice_apply to explicit source(ctx)`.

### Task 3: picker reads the registry + routes through the driver (INTEGRATION)

**Files:**
- Modify: `lua/parley/skill_picker.lua` (registry discovery + `M.run_skill` routing)
- Test: new `tests/unit/skill_picker_spec.lua`

- [ ] **Step 1: Write failing test** — stub `parley.skills.review.run_via_invoke`
  and `skill_invoke.invoke` (record calls). `skill_picker.run_skill(buf, { name = "review" }, {})`
  → calls `run_via_invoke` (not `skill_invoke.invoke`); `run_skill(buf, { name = "voice-apply" }, { slug = "x" })`
  → calls `skill_invoke.invoke(buf, <manifest>, { slug = "x" }, …)` (not `run_via_invoke`).
- [ ] **Step 2: Run, verify fail** (`run_skill` is a file-local fn calling `skill_runner.run`).
- [ ] **Step 3: Implement** — make `run_skill` a module function `M.run_skill(buf, manifest, args)`:
  `review` → `require("parley.skills.review").run_via_invoke(buf, args or {})`; else
  → `require("parley.skill_invoke").invoke(buf, manifest, args or {}, {})`. Change
  `M.open` to list from `parley.skills.current().all()` (manifests: `name`,
  `description`, `args`); `open_arg_picker` already drives `arg_def.complete` —
  manifests carry `args`, so it's unchanged. Remove the `skill_runner` requires.
- [ ] **Step 4: Run, verify pass** — picker spec.
- [ ] **Step 5: Commit** — `#128 M4: picker lists the registry + routes via the driver`.

### Task 4: delete `skill_runner` + reconcile every caller (INTEGRATION)

**Files:**
- Delete: `lua/parley/skill_runner.lua`, `tests/unit/skill_runner_spec.lua`
- Modify: `lua/parley/skills/review/init.lua` (drop `get_runner` + dead `M.skill` v1 fields)
- Modify: `lua/parley/review.lua` (drop the 4 dead delegating exports)
- Modify: `lua/parley/skill_invoke.lua` (add `M.is_in_flight`)
- Modify: `tests/unit/review_spec.lua` (remove the `apply_edits` describe block)
- Modify: `tests/integration/cliproxy_caller_teardown_spec.lua` (port the abort test to `skill_invoke`)
- Modify (comments only): `lua/parley/skill_edits.lua`, `lua/parley/skill_providers.lua` headers

- [ ] **Step 1: Add `skill_invoke.is_in_flight` + port the abort test** — add
  `function M.is_in_flight(buf) return _in_flight[buf] == true end` to
  `skill_invoke.lua`. Rewrite `cliproxy_caller_teardown_spec.lua`'s
  "on_abort clears the _in_flight guard" test to build a minimal real artifact
  buffer + a `voice-apply`/stub manifest, call `skill_invoke.invoke`, mock
  `dispatcher.query` to fire `on_abort` (arg 8), and assert
  `skill_invoke.is_in_flight(buf) == false`. Run → pass.
- [ ] **Step 2: Delete `skill_runner` + its spec; drop dead callers** — `git rm
  lua/parley/skill_runner.lua tests/unit/skill_runner_spec.lua`. In
  `review/init.lua` remove the `get_runner`/`_skill_runner` helper and delete
  `M.skill.system_prompt`/`pre_submit`/`post_apply` (dead — `run_via_invoke`
  owns that logic), leaving only the manifest fields. In `review.lua` delete the
  `compute_edits`/`apply_edits`/`attach_diagnostics`/`highlight_edits` exports.
  In `review_spec.lua` delete the `review.apply_edits` describe block. Fix the
  `skill_edits.lua`/`skill_providers.lua` header comments that cite
  `skill_runner` line numbers.
- [ ] **Step 3: Run the full suite** — `make test`. Verify nothing imports
  `skill_runner` (`grep -rn 'require("parley.skill_runner")' lua/ tests/` → empty)
  and the suite is green (review, voice_apply, picker, abort, providers all pass).
- [ ] **Step 4: `make lint`** clean.
- [ ] **Step 5: Commit** — `#128 M4: delete skill_runner; reconcile all callers`.

### Task 5: glob/list_dir YAGNI record + atlas + milestone close

- [ ] **Step 1: Record the glob/list_dir YAGNI decision** — a short note in the
  issue `## Log` + `atlas/skills/skill-system.md` (and/or `atlas/providers/tool_use.md`):
  no structured `glob`/`list_dir` tool is added — `ls`/`find`/`grep` cover P1, and
  P2's artifact mode needs only `read_file`/`propose_edits`; revisit when a
  concrete consumer appears.
- [ ] **Step 2: Atlas** — `atlas/skills/skill-system.md`: drop the "v1 pipeline
  (transitional — live until M4)" section (skill_runner is gone); state both P2
  skills run via `skill_invoke`. `atlas/modes/review.md`: remove the
  "voice-apply still on skill_runner until M4" caveats. `atlas/traceability.yaml`:
  remove the `skill_runner.lua`/`skill_runner_spec.lua` mappings; add
  `voice_apply_spec`/`skill_picker_spec`; reflect `backup.lua` under
  `providers/tool_use` too (the M3 merge judge's optional note).
- [ ] **Step 3:** `make test` green; `make lint` clean.
- [ ] **Step 4:** `sdlc milestone-close --issue 128 --milestone M4` (fresh-context judge); log the verdict.
- [ ] **Step 5: Commit** — `#128 M4: atlas + traceability; glob/list_dir YAGNI record`.

**M4 Done when:** `voice_apply` runs through `skill_invoke` with a dynamic
`source(ctx)` (SKILL.md ⊕ per-slug style); `skill_runner.lua` is **deleted** and
nothing imports it; the picker lists the registry and routes both skills through
the driver; the abort-teardown coverage lives on `skill_invoke`; the glob/list_dir
YAGNI decision is recorded; suite green; atlas reconciled.

## ~~M5 — repo_discovery virtual skill~~ — DROPPED (re-scope)

`repo_discovery` is **P1 context/tools, not a P2 skill** (category error — see Revisions / pensive). #116's registry feeds P1's chat context directly; that work belongs to the future **P1 issue** ("parley chat as ariadne workbench"), not this issue.

---

## Notes for the executor

- **The pure core is `skill_manifest.lua` (M1) + `skill_edits.lua` + `skill_assembly.lua` (M2).** Keep them IO-free with colocated specs so the purity boundary is visible (the milestone judge greps the entity table against the diff). The M3 thin IO seam is `skill_invoke` (drives the dispatcher) + `skill_render` (vim-API rendering) + the `propose_edits` tool.
- **Don't re-fork disk vs virtual.** The whole point is one `source(ctx)` contract; `read_skill` calls `manifest.source(ctx)` and never branches on origin (`ARCH-DRY`). The disk/virtual difference lives entirely inside how the *provider* built the closure.
- **Reuse, don't re-implement** (`ARCH-DRY`): the tool registry/dispatcher (`tools/init.lua`, `tools/dispatcher.lua`), the cwd-bypass pattern (`chat_history_search.lua`), the per-buffer-state pattern (`tool_loop.lua:36`), the agent-resolution cascade + arg picker + scan structure salvaged from `skill_runner`/`skill_picker`. Name the existing thing in each task.
- **The deletion of `skill_runner` is M4, not earlier** — `review`/`voice_apply` must already run through the loop (M3) before their old engine is removed, or the skills break mid-stream.
- **#129 is the next issue, not a task here.** The `tools`/`elevated` split + the `assemble_turn` gate-point are the hooks it will use; don't build the permission model now (YAGNI).

---

## Revisions

### 2026-06-16 — M3 boundary review (FIX-THEN-SHIP → addressed)

M3 implemented (`skill_invoke` driver, inline backup, `skill_render` salvage,
`review` ported) + closed; boundary review **FIX-THEN-SHIP** (no Critical). It
caught three behaviors the port dropped vs. `skill_runner` — all fixed in
`skill_invoke` (shared, so M4's `voice_apply` inherits the fixes):
- **I1 — error surfacing + resubmit storm.** `on_done` was always `ok=true`; a
  failed/empty `propose_edits` was silent and `review` resubmitted 3×. Now
  `skill_invoke` derives `ok` + an `applied` count from the tool ToolResults,
  logs tool errors / a no-tool-call warning; `review`'s `on_done` STOPs when
  `applied==0` (no progress → don't loop).
- **I2 — `max_tokens` regression.** Restored the `max_tokens=100000` bump
  (review was running at the 4096 default → truncated multi-edit batches).
- **I3 — stale SKILL.md tool name.** `review/SKILL.md` `review_edit` →
  `propose_edits` (worked only via forced `tool_choice`).
- Minors fixed: unnamed-buffer guard + per-buffer in-flight re-entrancy guard.
- Tests added: the I1 failure path (`skill_invoke_spec`: failed edit → ok=false,
  applied=0, file untouched) + review no-resubmit cases + the `max_tokens`
  assertion.

**2nd-round re-judge (FIX-THEN-SHIP) — also addressed:**
- **Empty-edits/no-progress storm (I1 hole).** `compute_edits([])` returns ok →
  `propose_edits` would write unchanged content → `applied=1` → review resubmits.
  Fixed two ways: `propose_edits` now **rejects an empty edits batch** (no write,
  no backup), and `review` uses a **marker-shrank guard** — resubmit only if the
  marker set actually decreased (catches empty/no-op/wrong-place edits, not just
  no-apply). Tests reworked to simulate the buffer shrinking.
- **ARCH-DRY: shared backup helper.** Extracted `lua/parley/tools/backup.lua`
  (`numbered(path, content)`); `propose_edits` + `write_file` both delegate (M4's
  `voice_apply` won't be a third copy).
- Removed stray committed debug files (`.mdbg*`), gitignored them.

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
