# Skill System

> **Redesigned (#128), re-scoped 2026-06-15.** Parley has **two modes**
> (see `workshop/pensive/parley-two-modes-chat-vs-artifact.md`): **P1** — parley
> *chat* as an ariadne workbench (read-only, repo-aware, tools); **P2** — a
> workbench around *one artifact* (the markdown file is the subject; *skills*
> construct context + mutation tools). **"Skill" is a P2 concept.** The redesign
> deleted the parallel `skill_runner` engine by having P2 **reuse the existing
> dispatcher/tools layer** — **P1's chat loop is untouched**, and **no new shared
> kernel was built.** As of M4, both P2 skills (`review`, `voice-apply`) run
> through `skill_invoke`; `skill_runner` no longer exists.

## Redesign (#128) — P2 rides the shared dispatcher; skill = P2 descriptor

A skill is **data, not a pipeline**: a `SkillManifest`
(`{name, description, scope, activation, source, tools?, elevated?, force_tool?, args?, agent?}`).
The "shared kernel" is the **existing dispatcher/tools layer**
(`prepare_payload` / `query` / `decode` / `execute_call`) that P1's chat loop
already rides; P2 gets a **thin driver** (`skill_invoke`) that rides the same
layer instead of `skill_runner`'s bespoke copies. The keystone: **`propose_edits`
is a real registered tool**, so P2's edit-apply flows through the same
`execute_call` path as every chat tool — cwd-scope active, with an **inline
numbered `.parley-backup`** before each write (via `lua/parley/tools/backup.lua`,
shared with `write_file`).

**Milestones** (plan: `workshop/plans/000128-skill-system-redesign-plan.md`):
M1 manifest + providers + registry (done) · M2 `propose_edits` tool + pure P2
context-assembler (done) · M3 thin `skill_invoke` driver + `review` ported
(done) · **M4 `voice-apply` ported + `skill_runner` deleted (done)** ·
~~M5 `repo_discovery`~~ **dropped** (it's P1 context, not a skill).

**M1 modules:**
- `lua/parley/skill_manifest.lua` — `SkillManifest` shape + `validate` (PURE).
- `lua/parley/skill_providers.lua` — `disk(root)` (closure `source` — kills the v1 `debug.getinfo` dance; injects `ctx.skill_md` for an explicit `source(ctx)`) + `virtual(generators)` seam.
- `lua/parley/skill_registry.lua` — `discover` (union + validate-drop + last-wins dedup), `current()`; exposed as `parley.skills`.

**M2 modules (the shared pieces P2 reuses — no LLM, no chat-loop change):**
- `lua/parley/skill_edits.lua` — `compute_edits` (PURE batch-edit transform; the single source — the `propose_edits` handler is its one caller).
- `lua/parley/tools/builtin/propose_edits.lua` — the real `propose_edits` builtin (`kind=write`); edit-apply via the shared dispatch path.
- `lua/parley/skill_assembly.lua` — PURE `build_invocation` (manifest + body + document → LLM-call inputs) + `resolve_agent` (the agent cascade, pure given injected config/registry deps).

**M3 modules (the P2 path goes live — chat loop still untouched):**
- `lua/parley/skill_invoke.lua` — the thin P2 driver: one tool-use exchange on an artifact via the EXISTING dispatchers (`prepare_payload`/`query`/`execute_call`); `on_done` hook; per-buffer `is_in_flight` guard; reloads the artifact with `:edit!`; binds edits to the artifact (injects `file_path`).
- `lua/parley/skill_render.lua` — the single source of `clear_decorations`/`attach_diagnostics`/`highlight_edits` (salvaged from `skill_runner`).
- `propose_edits` gains an inline numbered `.parley-backup` before each write.
- `review` runs via `skill_invoke` (`review.run_via_invoke`): marker pre-check + resubmit-up-to-3 stay in the skill.

**M4 (engine unified — `skill_runner` deleted):**
- `voice-apply` ported to an explicit `source(ctx)` composing `ctx.skill_md` (the SKILL.md body, injected by the disk provider) ⊕ the per-slug `~/.personal/<slug>-writing-style.md` style guide.
- `skill_picker` lists skills from `parley.skills.current().all()` and routes via `M.run_skill`: `review` → `run_via_invoke` (marker-aware); every other skill → `skill_invoke.invoke` (single-shot).
- `lua/parley/skill_runner.lua` **deleted**; `review.lua`'s v1 edit/diagnostic re-exports and `review/init.lua`'s dead `pre_submit`/`post_apply`/`system_prompt` removed.

Key design points: P2's edit-apply is a normal tool (not special-cased);
`build_invocation`/`compute_edits`/`resolve_agent` are pure (the `source()` IO +
`query` + `execute_call` stay in the driver); the chat loop is never touched.

### Tooling decision — no structured `glob`/`list_dir` (YAGNI, M4)

`glob.lua`/`list_dir.lua` do not exist (the issue's "present but unregistered"
premise was stale). `builtin/` ships `ls` + `find` (registered) + `grep`; P2's
artifact mode reads with `read_file` and edits with `propose_edits`. No structured
directory-listing tool has a consumer in either mode today, so **none was added**.
Revisit only when a concrete consumer appears (`ARCH-DRY` — don't add surface
without a caller).

## Entry Points

- `<C-g>s` — skill picker (cascading typeahead: select skill → select args → run)
- `<C-g>ve` — fast path for review skill (bypass picker)

## Skill Definition

Each skill is a folder under `lua/parley/skills/` (the plugin disk provider root;
`~/.config/parley/skills/` is the user override root):

```
lua/parley/skills/<name>/
  init.lua    -- returns a SkillManifest: { name, description, scope, activation,
              --   tools?, elevated?, force_tool?, args?, agent?, source? }
  SKILL.md    -- the skill body (system prompt); the disk provider's default source
```

`SKILL.md` is the default body. A skill needing a **dynamic** body declares an
explicit `source(ctx)` (e.g. `voice-apply` composing `ctx.skill_md ⊕ <style>`);
the disk provider injects `ctx.skill_md` from the dir's SKILL.md. `args` lists
completable picker arguments (`{ name, description, complete }`).

## Built-in Skills

- **review** — edit document based on 🤖 markers (light edit / heavy revision); marker-aware resubmit loop
- **voice-apply** — rewrite to match a personal writing voice from `~/.personal/<slug>-writing-style.md`

## Config

```lua
skill_shortcut = { modes = { "n" }, shortcut = "<C-g>s" },
skill_agent = "Claude-Sonnet",   -- global default agent
skills = {},                      -- per-skill overrides: { { name = "review", agent = "..." }, { name = "...", disable = true } }
```

## Key Files

Redesign (#128) — M1 (manifest + discovery):
- `lua/parley/skill_manifest.lua` — declarative `SkillManifest` shape + `validate` (PURE)
- `lua/parley/skill_providers.lua` — `disk(root)` (+ `ctx.skill_md` injection) + `virtual(generators)` providers (uniform manifests)
- `lua/parley/skill_registry.lua` — `discover`/`get`/`names`/`all`/`default_stack`/`current()` (exposed as `parley.skills`)
- `tests/unit/skill_manifest_spec.lua`, `tests/integration/skill_providers_spec.lua`, `tests/integration/skill_registry_spec.lua`

Redesign (#128) — M2 (shared pieces P2 reuses):
- `lua/parley/skill_edits.lua` — `compute_edits` (PURE; single source of the batch-edit transform)
- `lua/parley/tools/builtin/propose_edits.lua` — the real `propose_edits` builtin (P2 edit-apply via the shared dispatch path)
- `lua/parley/tools/backup.lua` — numbered `.parley-backup` helper (shared by `propose_edits` + `write_file`)
- `lua/parley/skill_assembly.lua` — PURE `build_invocation` + `resolve_agent` (injected-config cascade)
- `tests/unit/skill_edits_spec.lua`, `tests/unit/tools_builtin_propose_edits_spec.lua`, `tests/unit/skill_assembly_spec.lua`

Redesign (#128) — M3/M4 (P2 path live; both skills ported; engine unified):
- `lua/parley/skill_invoke.lua` — the thin P2 driver (one exchange on the existing dispatchers; `is_in_flight` guard)
- `lua/parley/skill_render.lua` — diagnostics/highlights (single source; was salvaged from skill_runner)
- `lua/parley/skill_picker.lua` — `<C-g>s` picker UI; lists `parley.skills.current()`, routes via `M.run_skill`
- `lua/parley/skills/review/init.lua` — `review.run_via_invoke` (markers + resubmit; runs via skill_invoke)
- `lua/parley/skills/voice_apply/init.lua` — `voice-apply` via explicit `source(ctx)` (SKILL.md ⊕ style guide)
- `lua/parley/review.lua` — backward-compatible shim (marker/quickfix/submit API)
- `tests/integration/skill_invoke_spec.lua`, `tests/integration/skill_invoke_review_spec.lua`, `tests/integration/voice_apply_spec.lua`, `tests/unit/skill_picker_spec.lua`, `tests/unit/skill_render_spec.lua`
