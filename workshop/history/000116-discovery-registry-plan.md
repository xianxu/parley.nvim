# Discovery Registry Implementation Plan (#116)

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give parley a data-driven *discovery registry* — the repo's noun-vocabulary (what file types exist and how to find their instances) — that a readonly research chat consumes, replacing hard-coded type knowledge.

**Architecture:** A registry is `name → TypeDescriptor`. Each descriptor carries a `locate` glob set + a pure `Matcher` predicate, because the four highest-value nouns (chat/note/vision/issue) are *not* `type:`-frontmatter artifacts (per the source-map audit) and need different discriminator kinds. The effective registry is **base ∪ local**: a parley-shipped base (the universal + parley-native types) unioned with grep-discovered local `type:` values from the inspected repo. Two consumers: `query(type, term)` produces a deterministic search command; `render()` produces the noun-vocabulary text that becomes #128's `repo_discovery` virtual skill body. The registry *interface* is decoupled from its *production* (grep now; a `datatype`-binary index later).

**Tech Stack:** Lua (Neovim plugin), `plenary.nvim` headless test harness (`make test`), `rg` for content/glob discovery. Follows parley module conventions (`local M = {}` … `return M`) and the existing `lua/parley/tools/` registry pattern.

---

## Scope & milestones

The original #116 spans read-side pickers + write-side scaffolding + an embedded descriptor format. Critical-path-first decomposition:

- **M1 — Discovery registry core (readonly).** Base registry + local grep discovery + `Registry.render()` + `Registry.query()` + base∪local scope composition. **This is what unblocks #128.** No embedded-descriptor format needed.
- **M2 — Typed picker.** Wire the registry to `<C-g>m`; preserve `<C-g>M` escape hatch. (Original read-side UI.)
- **M3 — Embedded descriptor format + new-instance scaffolding.** Settle the descriptor format (the long-open #116 question), parse descriptors from datatype docs, add templates + a "new instance" command. (Original write-side; human-driven creation, consistent with the readonly-*agent* posture.)

Only **M1** is detailed below to task granularity; M2/M3 are milestone sketches to be expanded when reached. Each `Mx` is a review boundary (its own `sdlc milestone-close`).

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `Matcher` | `lua/parley/discovery/matcher.lua` | new |
| `TypeDescriptor` | `lua/parley/discovery/descriptor.lua` | new |
| `Registry` | `lua/parley/discovery/registry.lua` | new |
| `DiscoverySpec` | `lua/parley/discovery/registry.lua` | new |
| `base_registry` (data) | `lua/parley/discovery/base.lua` | new |

- **Matcher** — a tagged-union predicate over `(path, frontmatter_table)` deciding whether a file is an instance of a type. Kinds (from the audit's discriminator taxonomy):
  - `{kind="frontmatter", field="type", value="<name>"}` → `fm.type == value` (the 14 datatype types).
  - `{kind="frontmatter_present", field="file"}` → `fm.file ~= nil` (chat — header `file:`/`topic:`, no `type:`).
  - `{kind="filename", pattern="^%d%d%d%d%d%d%-"}` → basename matches (issue — `NNNNNN-*.md`).
  - `{kind="any"}` → always true; the `locate` glob alone discriminates (note, plan, vision).
  - **Relationships:** N:1 owned by TypeDescriptor (one matcher per descriptor). **DRY rationale:** every type's "is this file an instance" test routes through one pure predicate instead of per-type bespoke checks scattered across finders. **Future extensions:** a `yaml` kind that parses YAML `id`/`status` (vision today is handled as `any` + `*.yaml` locate; promote if vision needs status-filtered discovery).

- **TypeDescriptor** — everything deterministic code needs about one type: `{ name, label, scope, locate, matcher, blurb }`.
  - `name` (registry key), `label` (display), `scope` ∈ `"base" | "local"`, `locate` = list of path globs (relative to a root; carries extension, e.g. `*.md`/`*.yaml`), `matcher` = a Matcher, `blurb` = one line for `render()` ("what it is + how to find it").
  - **Relationships:** 1:1 with a Matcher; N:1 held by Registry. **DRY rationale:** first occurrence of "type knowledge as data" — replaces hard-coded type assumptions in finders (#116's whole premise). **Future extensions:** add `template`/`new_location`/`slug_rule` fields in M3 for the write-side; add `discriminator: yaml` for vision status filters.

- **Registry** — `name → TypeDescriptor` plus the two consumers. Pure given its descriptor set (assembly IO lives in integration points).
  - `Registry.of(descriptors) → registry` (constructor); `registry:get(name)`; `registry:names()`.
  - `registry:query(type, term) → DiscoverySpec` (pure — turns a noun + optional content term into a search spec).
  - `registry:render() → string` (pure — the noun-vocabulary text for #128; one line per type from `label`+`blurb`+derived search hint).
  - **Relationships:** holds N TypeDescriptors. **DRY rationale:** the single surface both the picker (M2) and the `repo_discovery` skill (#128) read; neither re-derives type knowledge. **Future extensions:** `render()` gains grouping (base vs local) and per-type instance counts.

- **DiscoverySpec** — the deterministic search a `query` compiles to: `{ roots = [glob…], content_term = "…"|nil, frontmatter = {field,value}|nil }`. A separate pure function (`spec_to_command`) renders it to an `rg` pipeline; execution is IO (M2/consumer side). Keeps "decide the search" pure and testable apart from "run the search."
  - **DRY rationale:** every consumer (picker, skill, future CLI) compiles the same spec the same way. **Future extensions:** spec carries sort key (mtime), `max_count`.

- **base_registry** — the static, parley-shipped descriptor list: the universal types (`pensive`, `prose`, `continuation`) + the parley-native ones the audit flagged as *not* datatype docs (`chat`, `note`, `vision`, `issue`, `plan`). Pure data; no IO. This is the "parley ships the base, repo declares the delta" half made concrete.
  - **DRY rationale:** the four non-doc types have nowhere else to be declared; centralizing them here is the single source. **Future extensions:** a few more universal types as conventions stabilize.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `LocalTypeDiscovery` | `lua/parley/discovery/local_types.lua` | new | `rg` over the repo |
| `RegistryBuilder` | `lua/parley/discovery/init.lua` | new | repo-mode state + base ∪ local |

- **LocalTypeDiscovery** — discovers a repo's *novel* `type:` values: `rg -o '^type: \w+'` over the repo root, `sort -u`, minus the base names. Each surviving value becomes a minimal `local` TypeDescriptor (`matcher = frontmatter type=value`, `locate = {"**/*.md"}`, `blurb` synthesized). This is the cheap, grep-backed *production* behind the registry interface.
  - **Injected into:** RegistryBuilder. Tested with a temp fixture dir (files carrying assorted `type:` headers) — no network, real `rg`.
  - **Future extensions:** the swap point for a `datatype`-binary-maintained index (same output shape, different producer) — see #116 Revisions (loom/cloth).

- **RegistryBuilder** — composes the effective registry for the current parley mode: `base` always; `+ local` when in repo mode; `+ union(siblings' local)` in super-repo mode (reuses `super_repo.compute_members`). Returns a `Registry`.
  - **Injected into:** the M2 picker and (via `render()`) the #128 `repo_discovery` skill source closure. Tested with a fake repo-mode context (no real cwd dependence — `repo_root`/members passed in).
  - **Future extensions:** caching keyed by repo_root + mtime; repo-provided descriptors (a repo shipping its own descriptor file) merged here.

---

## M1 — Discovery registry core

**Module layout:** new `lua/parley/discovery/` folder (matcher, descriptor, base, registry, local_types, init). Specs are **flat** in `tests/` per parley convention (no subdirs — match the existing `tools_builtin_grep_spec.lua` naming): pure entities → `tests/unit/discovery_<name>_spec.lua`; `local_types` + `init` → `tests/integration/discovery_<name>_spec.lua` with a temp fixture.

**Per-task TDD runs use a direct file path, NOT `make test-spec`.** `make test-spec SPEC=...` resolves SPEC as an *atlas/traceability key* (via `scripts/spec_test_map.sh` → `atlas/traceability.yaml`), and the `discovery/*` keys don't exist until Task 8 — so it would run zero tests for Tasks 1–7. Run a single spec with the plenary file form (as `make test-unit` does):

```
nvim --headless -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/discovery_matcher_spec.lua"
```

Reserve `make test` (full) and `make test-spec SPEC=discovery/...` (keyed) for *after* Task 8 registers traceability.

Follow parley conventions: modules `local M = {} … return M`; tests use `plenary.busted` (`describe`/`it`). Match the existing `lua/parley/tools/types.lua` validation style (`fail(msg)` → `(false, err)` / `(true)`) for descriptor validation.

### Task 1: Matcher predicate (PURE)

**Files:**
- Create: `lua/parley/discovery/matcher.lua`
- Test: `tests/unit/discovery_matcher_spec.lua`

`M.match(matcher, path, fm)` is pure over `(path, frontmatter_table)`. **Note:** the `fm` table is produced by the *caller* per candidate, and that producer is not uniform (datatype docs → YAML frontmatter; `chat` → parley's chat-header parse via `chat_parser.parse_header_key_value`). Producing `fm` is an M2 concern; the matcher only consumes the table, so M1 stays agnostic to the parse.

- [x] **Step 1: Write failing tests** — `M.match(matcher, path, fm)` for each kind:
  - `frontmatter` `{field="type",value="pensive"}`: matches `fm={type="pensive"}`, rejects `fm={type="prose"}` and `fm={}`.
  - `frontmatter_present` `{field="file"}`: matches `fm={file="x"}`, rejects `fm={}`.
  - `filename` `{pattern="^%d%d%d%d%d%d%-"}`: matches basename of `path="workshop/issues/000128-x.md"`, rejects `path="notes/foo.md"`. **Also assert** it matches `path="workshop/plans/000116-x-plan.md"` — the predicate is basename-only and does NOT distinguish issue from plan; disambiguation is the `locate` glob's job (Task 3/Task 4). This documents the invariant: *a `filename` matcher is only sound within its descriptor's `locate` scope.*
  - `any`: always true.
  - unknown kind → `error` (fail-loud: a malformed matcher is a programming bug, never valid input).
- [x] **Step 2: Run, verify fail** (module missing):
  `nvim --headless -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/discovery_matcher_spec.lua"`
- [x] **Step 3: Implement** `M.match` as a dispatch on `matcher.kind` (pure; no IO). Provide `M.KINDS` constant for validation reuse.
- [x] **Step 4: Run, verify pass** (same command). _11/11 green._
- [x] **Step 5: Commit** — `#116 M1: matcher predicate (pure discriminator kinds)`. _7e4d95f_

### Task 2: TypeDescriptor shape + validation (PURE)

**Files:**
- Create: `lua/parley/discovery/descriptor.lua`
- Test: `tests/unit/discovery_descriptor_spec.lua`

- [x] **Step 1: Write failing tests** — `M.validate(desc)` returns `(ok, err)`:
  - valid descriptor (all required fields + a valid matcher) → `(true, nil)`.
  - missing `name`/`locate`/`matcher` → `(false, "<specific field>")`.
  - `scope` not in `{base, local}` → false.
  - `matcher` failing `matcher.KINDS` membership → false (delegates to Task 1's `KINDS`).
- [x] **Step 2–4:** fail → implement `validate` (mirror `tools/types.lua` style) → pass. _9/9 green._
- [x] **Step 5: Commit** — `#116 M1: TypeDescriptor shape + validation`. _f1a91d0_

### Task 3: base_registry data (PURE data)

**Files:**
- Create: `lua/parley/discovery/base.lua`
- Test: `tests/unit/discovery_base_spec.lua`

- [x] **Step 1: Write failing tests:**
  - `M.descriptors` is a list; every entry passes `descriptor.validate`.
  - contains exactly the base nouns: `chat, note, vision, issue, plan, pensive, prose, continuation` (assert names present).
  - `chat` uses `frontmatter_present field=file`; `note`/`plan`/`vision` use `any`; `issue` uses `filename`; `pensive`/`prose`/`continuation` use `frontmatter type=<name>`.
  - locate globs carry correct extension (`vision` → `*.yaml`; rest → `*.md`).
- [x] **Step 2–4:** fail → author the static table → pass. _6/6 green._ Locations from the audit. **Derive dir-backed globs from config, not literals** (`ARCH-DRY`): `issue`→`config.issues_dir .. "/*.md"`, `vision`→`config.vision_dir .. "/*.yaml"`, `chat`→chat roots, `note`→note roots (read the same config keys `repo_mode.md` uses; repo mode demotes the globals). `plan` has **no config key** (parley doesn't auto-create `workshop/plans/`) — use the literal `workshop/plans/*.md` with a comment noting the absent key. `pensive`→`**/*.md` (no fixed home; the matcher discriminates). _Resolution: chat/note carry BOTH repo-primary (`repo_chat_dir`/`repo_note_dir`) and demoted-global (`chat_dir`/`notes_dir`) globs._
- [x] **Step 5: Commit** — `#116 M1: base registry (parley-shipped universal + native types)`. _0d7026a_

### Task 4: Registry — `of` / `get` / `query` → DiscoverySpec (PURE)

**Files:**
- Create: `lua/parley/discovery/registry.lua`
- Test: `tests/unit/discovery_registry_spec.lua`

- [x] **Step 1: Write failing tests:** _(unknown-type contract settled → `nil`, per plan-quality advisory, mirrors `get`)_
  - `Registry.of(base.descriptors):get("pensive")` returns the descriptor; `get("nope")` → nil.
  - `registry:query("pensive","duality")` → spec `{roots=<pensive locate>, frontmatter={field="type",value="pensive"}, content_term="duality"}`.
  - `registry:query("note","async")` → spec with `frontmatter=nil` (note matcher is `any`), `content_term="async"`.
  - `query` of unknown type → nil.
  - `query("issue")` and `query("plan")` produce specs whose `roots` differ (`workshop/issues/*` vs `workshop/plans/*`) — proving the `locate` glob (not the basename matcher) separates the two identical `NNNNNN-slug` filename conventions.
  - `spec_to_command(spec)` renders the expected `rg` pipeline string (frontmatter case → `rg -l '^type: pensive' … | xargs rg -il 'duality'`; any case → glob roots → `rg -il 'async'`).
- [x] **Step 2–4:** fail → implement `of`/`get`/`names`/`query`/`spec_to_command` (all pure) → pass. _12/12 green. Roots rendered as rg `-g` globs + search-path `.`; `--files` for the no-filter/no-term case._
- [x] **Step 5: Commit** — `#116 M1: Registry query → DiscoverySpec + command compilation`. _cb50829_

### Task 5: Registry — `render()` for #128 (PURE)

**Files:**
- Modify: `lua/parley/discovery/registry.lua`
- Test: `tests/unit/discovery_registry_spec.lua` (extend)

- [x] **Step 1: Write failing test:** `registry:render()` returns a string that (a) lists every type's `label`, (b) includes each `blurb`, (c) includes a search hint per type, (d) is stable/sorted by name. Assert a couple of representative lines verbatim (e.g. the `pensive` and `chat` lines) so the #128 skill body has a contract.
- [x] **Step 2–4:** fail → implement `render` (deterministic, sorted; this is the noun-vocabulary the `repo_discovery` skill embeds) → pass. _16/16 green. find-hint derived from matcher/locate (DRY, deterministic — no absolute globs); base blurbs simplified to "what it is" so the how-to lives only in the derived hint._
- [x] **Step 5: Commit** — `#116 M1: Registry.render() noun-vocabulary (the #128 consumer surface)`. _423d02c_

### Task 6: LocalTypeDiscovery (INTEGRATION — wraps `rg`)

**Files:**
- Create: `lua/parley/discovery/local_types.lua`
- Test: `tests/integration/discovery_local_types_spec.lua`

- [x] **Step 1: Write failing test** with a temp fixture dir: write 4 files — `a.md` (`type: pensive`), `b.md` (`type: widget`), `c.md` (`type: gadget`), `d.md` (`type: widget-spec`). `M.discover(root, base_names)` where `base_names` includes `pensive` (not `widget`/`gadget`/`widget-spec`) → returns descriptors for `widget`, `gadget`, **and `widget-spec`** only (novel `type:` minus base), each a valid `local` descriptor with `matcher.frontmatter value=<name>`. The `widget-spec` case guards hyphen handling (Step 3).
  - edge: a repo with no novel types → empty list.
  - edge: file with no `type:` → ignored.
- [x] **Step 2: Run, verify fail.**
- [x] **Step 3: Implement** — discover novel types over `root`, parse values, subtract base, synthesize descriptors. Invoke rg via `grep.lua`'s pattern — load-time `detect_grep()` then `vim.fn.system(...)` (NOT a hand-rolled `vim.system` wrapper; `ARCH-DRY`). **Regex must allow hyphens:** `^type: [A-Za-z0-9_-]+` — datatype values are hyphenated (`meeting-notes`, `travel-plan`), so `\w+` would silently truncate them. Strip the `type: ` prefix from each match. _Used `rg -o --no-filename` + load-time `vim.fn.executable("rg")`; degrades to empty when rg absent._
- [x] **Step 4: Run, verify pass** — `nvim --headless -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/discovery_local_types_spec.lua"`. _4/4 green._ (Traceability key added in Task 8.)
- [x] **Step 5: Commit** — `#116 M1: LocalTypeDiscovery (grep novel type: minus base)`. _2a03ac9_

### Task 7: RegistryBuilder — base ∪ local, mode-aware (INTEGRATION)

**Files:**
- Create: `lua/parley/discovery/init.lua`
- Modify: `lua/parley/init.lua` (expose `parley.discovery`)
- Test: `tests/integration/discovery_builder_spec.lua`

- [x] **Step 1: Write failing tests** (inject mode context — `{repo_root=…, super_repo_members=…}` — don't depend on real cwd):
  - global mode (no repo_root) → registry = base only.
  - repo mode → base ∪ local(repo_root) (use the Task 6 fixture).
  - super-repo mode → base ∪ union(local over members); a `widget` declared in two members appears once (dedup by name, base wins ties). _Also: a member's `type: chat` (base-name collision) does not shadow the base chat — proves base wins._
- [x] **Step 2: Run, verify fail.**
- [x] **Step 3: Implement** `M.build(ctx)` → `Registry.of(base ∪ deduped local)`. Reuse `super_repo.compute_members` for the member list _(transitively, via `config.super_repo_members` which `super_repo.activate` populates — no recompute)_. Wire `parley.discovery.build`/`current()` in `init.lua`. **Multi-root (the merge):** repo-relative `locate` globs expanded across `[repo_root] + members`; absolute/global globs pass through unchanged. _members already include the current repo, so they supersede the lone repo_root._
- [x] **Step 4: Run, verify pass.** _7/7 green; smoke-checked `parley.discovery.current()`/`render()` (8 lines)._
- [x] **Step 5: Commit** — `#116 M1: RegistryBuilder (base ∪ local, repo/super-repo aware)`. _f064eb8_

### Task 8: Atlas + milestone close

- [x] **Step 1:** Add `atlas/discovery/registry.md` (new surface: the registry, descriptor/matcher kinds, base∪local composition, the `render()`/`query()` consumers, grep-now/index-later seam). Link it in `atlas/index.md`. _§11; Traceability bumped to §12._
- [x] **Step 2:** Update `atlas/traceability.yaml` mapping the new specs. _`discovery/registry` → 6 modules + 6 specs._
- [x] **Step 3:** `make test` green; `make lint` clean. _0 warnings/0 errors, 87 spec files PASS, EXIT=0. (Fixed a pre-existing `highlighter_spec.lua` lint warning out of band — side-quest 6ab6ad8 — that was red at the branch base and blocked the gate.)_
- [x] **Step 4:** `sdlc milestone-close --issue 116 --milestone M1` (runs the fresh-context `judge`; fix Critical/Important before crossing). Log the verdict in `## Log`. _Arc: REWORK (C1/I1/I2) → fixed → FIX-THEN-SHIP (I-A/I-C) → fixed → **SHIP** (high confidence). I-B carried to M2. Logged in `## Log`; trailer `Review-Verdict: SHIP` in commit e3147f4._
- [x] **Step 5: Commit** — `#116 M1: atlas + traceability for discovery registry`. _28baeeb_

**M1 Done when:** `parley.discovery.current()` returns a mode-correct `Registry`; `registry:render()` yields the noun-vocabulary string (#128's `repo_discovery` body); `registry:query(type, term)` compiles a correct `rg` pipeline *for the base/relative registry* (reconciling the **built** registry's absolute globs with the search root is M2 — the M2-carried I-B decision in `## Revisions`); base∪local composition verified across global/repo/super-repo; all specs green; atlas updated. **#128 is unblocked** — it consumes `render()`, which is fully correct, not `query()`.

---

## M2 — Finder root-sourcing (sketch)

**Minimal scope (operator decision):** the existing per-type finders source their *home root folder* from the registry instead of hardcoding it. Nothing else — `<C-g>m` stays the type-blind escape hatch; no typed picker, no generic browser.

For each existing finder (chat `<C-g>f`, note `<C-n>f`, issue `<C-y>f`, vision `<C-j>f`): replace its hardcoded dir constant (e.g. `repo_chat_dir`, `issues_dir`) with the registry descriptor's `locate`. The finder keeps its own type-specific display *and* its existing multi-root expansion (global + repo + super-repo siblings via `chat_roots`/`note_roots`/`compute_members`); only *where the home folder comes from* changes.

**Accepted simplification:** assumes each type is folder-homed (the 4 finders are). Scatter types (instances spread across the repo, no fixed home) are out of scope — parley doesn't handle them today, and the agent (#128) still finds them via M1's frontmatter `Matcher`.

**Deferred to #115:** the generic *faceted* finder (one shared UI parameterized by type; per-type facet bars; per-type finders as instances) is a separate design — the "two filter bars" problem (type-switch + per-type facets) makes an all-types view incoherent, so it warrants its own issue/plan. `#115 deps [000116]`.

### M2 tasks (expanded 2026-06-30)

**Scope (supersedes the M1-era "M2 — Typed picker" line in Scope & milestones):**
M2 is the **data-correctness layer** — get `issue`'s home **sourced from
`issue.cue`** (repo-as-source-of-truth) AND make the registry's query surface
correct on the **built** registry (the I-B fix). #115 is the UI layer on top of
that sound data. **Only `issue` is repo-sourced** (ariadne-owned); chat/note/vision
keep their existing parley-native root-managers — routing them through the registry
would be a circular no-op and would drop the root-managers' labels/persistence
(anti–Simplicity-First). Issue *creation* is M3 (delegate to `sdlc issue new`).

**Single source for the issue home:** `issue_vocabulary.home()` reads
`discovery.home` from `construct/generated/vocabulary/issue.json` (cue →
weave-emitted), fallback `config.issues_dir`. BOTH the issue finder AND the
registry's issue descriptor consume it (`ARCH-DRY`).

#### Task M2.1 — ariadne: model issue location in cue (cross-repo)
- Add a concrete block to `../ariadne/construct/vocabulary/issue.cue`:
  `discovery: { home: "workshop/issues", glob: "*.md" }`.
- Verify `cue export …/issue.cue --out json` includes `discovery`, and `make weave`
  materializes it into parley's `construct/generated/vocabulary/issue.json` (the
  emit is automatic — `construct/local/vocabulary/.dynamic-skill` runs `vocabulary
  export` at `weave compile`).
- Note in ariadne#145 that the location half landed here; #145 stays for the
  creation-template unification.

#### Task M2.2 — parley: `issue_vocabulary.home()` (cue-sourced, graceful fallback)
- `lua/parley/issue_vocabulary.lua`: add `M.home()` → the **relative**
  `discovery.home` from the loaded JSON (NOT joined), or **nil** when absent.
  Relative is the consistent form: `config.issues_dir` is relative
  (`"workshop/issues"`, `config.lua:520`), `get_issues_dir()` does its own git-root
  join (`issues.lua:333-352`), and `base.lua` globs are repo-relative by contract.
- The loader **raises** on a missing/unreadable file (`M.load()` → `error()`,
  `issue_vocabulary.lua:147`), so wrap it in `pcall` and return **nil** (not raise)
  in a fresh clone / pre-weave. Keep the module **config-decoupled** — no `config`
  access here; the default fallback lives at the seed site (M2.3).
- Test: cue JSON with `discovery.home` → returns the **exact relative string**
  (`"workshop/issues"`, not merely non-nil — TDD forces the relative contract);
  missing `discovery` field → nil; missing/unreadable file → nil (the pcall path).
  (`ARCH-PURE`)

#### Task M2.3 — seed `config.issues_dir` from the cue home at setup (root-cause, one source)

**Plan-quality finding (high-confidence) corrected the original per-reader reroute.**
`config.issues_dir` has **five** direct readers, not one:
`get_issues_dir()` (`issues.lua:334`), `get_issues_repo_root()` (`issues.lua:358`),
the **super-repo finder** `super_repo.expand_roots(config.issues_dir)`
(`issue_finder.lua:133` — the motivating #114 consumer), the status-typeahead
autocmd (`init.lua:872`), and `base.lua`'s issue descriptor (`base.lua:63`).
Rerouting only `get_issues_dir()` leaves the super-repo finder + others on raw
config → divergence (`ARCH-PURPOSE` failure), invisible today only because the
default and the cue home are the same string.

- **Fix (root cause, `ARCH-DRY`):** at setup, right after the opts→config merge
  (`init.lua:537-538`), seed:
  `if opts.issues_dir == nil then local h = require("parley.issue_vocabulary").home(); if h then M.config.issues_dir = h end end`.
  Precedence **explicit user override > cue `discovery.home` > built-in default**.
  All five readers then derive from the one seeded value — **no per-reader
  rerouting, no base.lua injection** (base.lua reads the seeded `config.issues_dir`).
- **Relative preserved:** `issues_dir` ∈ `repo_artifacts.dir_keys` → `skip_prepare`
  (`init.lua:644-646`), so dir-prep never absolutizes it; the cue home is relative
  and stays relative (base.lua's locate contract + `get_issues_dir`'s join rely on
  this).
- Tests: setup with cue home + no user override → `config.issues_dir == "<cue home>"`;
  `opts.issues_dir` set → override wins; fresh clone (`home()` nil) → built-in
  default. Plus a **registry super-repo** test: the issue `locate` expands across
  `[repo_root] + members` (relative-glob behavior), guarding against a collapse to
  the current repo.

#### Task M2.4 — I-B root-cause fix (built-registry query correctness)
- `spec_to_command` → return a **structured form** (search_dirs + filename_globs +
  term + frontmatter); a thin executor renders the rg argv with `shellescape`,
  using **directories as positional search paths** and **relative filename globs in
  `-g`** so absolute (repo-prefixed) roots match. (`ARCH-PURE` pure-compiler/thin-shell;
  Root-Cause, not a patch.)
- Flip `discovery_builder_spec.lua` "spec_to_command on a built registry (I-B / M2
  seam)" from pinning the broken absolute-glob output to asserting the corrected,
  *matching* command; add an integration test (built registry over a temp fixture →
  the executed command actually lists the fixture's files).
- **Contract change — update the four `assert.are.equal` string assertions** at
  `tests/unit/discovery_registry_spec.lua:74-77, 84-87, 93, 99` (they assert the
  current `rg … -g <glob> .` string). Changing `spec_to_command` to a structured
  form breaks them; `make test` surfaces them, but they're listed here so the
  contract change is deliberate, not accidental.

#### Task M2.5 — atlas + milestone-close
- Update `atlas/discovery/registry.md` (issue home cue-sourced; `spec_to_command`
  structured argv) + traceability for changed specs.
- `make test` green, `make lint` clean.
- `sdlc milestone-close --issue 116 --milestone M2`; log the verdict in `## Log`.

## M3 — issue creation via sdlc delegation (sketch)

**Superseded 2026-06-30** (see the issue #116 revision + the 2026-06-30 entry in
`## Revisions` below). M3 is no longer an embedded-descriptor scaffolder.
`sdlc issue new`'s template is **hardcoded Go** (`cmd/sdlc/internal/issue/scaffold.go`),
not cue-sourced — ariadne#145 will unify that. So parley **delegates** issue
creation to `sdlc issue new` (retire the duplicate `render_issue_template`/
`cmd_issue_new` in `lua/parley/issues.lua`), then opens the created file (the
command prints its path). id-allocation stays in sdlc. Issue-first; other
datatypes deferred.

### M3 tasks (expanded 2026-06-30)

**Scope:** delegate the **top-level** new-issue command (`cmd_issue_new` →
`create_issue`, the `<C-y>c` flow) to `sdlc issue new "<title>"` — full delegation
(it scaffolds + broadcasts to origin/main; operator-confirmed UX). `render_issue_template`
has a **second caller**: the child-decomposition flow (`issues.lua:749` — adds a
`Parent:` backlink, uses parley's `next_issue_id`). Aim to route that through
`sdlc issue new --deps <parent>` too and **fully retire** `render_issue_template`
+ `ISSUE_TEMPLATE` (+ `next_issue_id`/`create_issue` if grep shows no other
callers) so sdlc is the single issue-creation source incl. id allocation
(`ARCH-DRY`). If the child flow's parent-link / parent-buffer-write semantics make
delegation gnarly, keep `render_issue_template` for that one flow and note the
partial retirement.

#### Task M3.1 — pure: parse `sdlc issue new` stdout → created path
- `sdlc issue new "<title>"` writes the dest path to **stdout** (last line,
  `cmd/sdlc/issue.go:319`) + `Created <dest>` to stderr, exit 0 on success. Add a
  PURE `M.parse_issue_new_output(stdout) → path|nil` (last non-empty line).
  Test: normal output → path; empty/garbage → nil. (`ARCH-PURE` core)

#### Task M3.2 — IO seam: run sdlc issue new (injected runner)
- `M.run_sdlc_issue_new(title, opts, runner?) → (path|nil, err)`: build argv
  `{"sdlc","issue","new",title}` (+ `--deps`/`--slug`), run via an **injectable
  runner** (default = `vim.fn.system`); check shell error / non-zero exit /
  unparseable output → err; else `parse_issue_new_output`. Thin IO over the pure
  parser. **Tests fake the runner** — real sdlc would create+push an issue; never
  call it in tests.

#### Task M3.3 — rewrite `cmd_issue_new` to delegate
- Keep the title prompt (repo label, `#142`); call `run_sdlc_issue_new(title)`;
  `:edit` the returned path (or log the err). Drop `create_issue`'s template path.

#### Task M3.4 — child-decomposition flow + retire `render_issue_template`
- Route the child flow through `run_sdlc_issue_new(task_text, {deps={parent_id}})`,
  add the `Parent:` backlink to the created file, open it. sdlc's id allocation
  replaces parley's `next_issue_id` here. THEN delete `render_issue_template` +
  `ISSUE_TEMPLATE` (+ `next_issue_id`/`create_issue` if grep shows no other
  callers — `slugify` likely stays, used elsewhere). Fallback: keep
  `render_issue_template` for the child flow + note, if delegation isn't clean.

#### Task M3.5 — atlas + milestone-close
- Atlas: issue creation delegates to `sdlc issue new` (cue/sdlc single source;
  ariadne#145 unifies the template onto cue). `make test` + lint. `sdlc
  milestone-close --issue 116 --milestone M3` (fresh-eyes subagent review if the
  auto-dispatch E2BIGs, as in M2); `--no-actual` likewise if the window
  mis-resolves.

_Original sketch (kept for history):_ Settle #116's long-open descriptor-format question (lean: structured fenced block embedded in each datatype doc — single source, diffable — parsed into a TypeDescriptor with added `template`/`new_location`/`slug_rule` fields). Add a descriptor parser (extends RegistryBuilder as a third source: base ∪ grep-local ∪ embedded-descriptors), a template scaffolder, and a "new instance of type X" command (human-driven creation — consistent with the readonly-*agent* posture). Update `construct/datatype/type.md` so future prototypes ship a descriptor.

---

## Notes for the executor

- The pure entities (Tasks 1–5) carry the design weight and run without IO — keep them in `lua/parley/discovery/` with colocated specs so the purity boundary is visible (the milestone judge greps the entity table against the diff).
- `query`/`spec_to_command` is the "deterministic shell, thin model" surface: the model only ever decides *which noun + which term*; the registry compiles the actual search. Don't let search logic leak into the model layer.
- Exact `rg` invocation matches `lua/parley/tools/builtin/grep.lua`: load-time `detect_grep()` then `vim.fn.system(cmd)` — don't hand-roll a second rg wrapper or use `vim.system` (`ARCH-DRY`).
- `render()`'s output is a *contract* with #128 — when its format changes, the `repo_discovery` skill body changes; keep the verbatim-line assertions in Task 5 as the guard.

---

## Revisions

### 2026-06-11 — M1 boundary-review rework (REWORK → FIX-THEN-SHIP)

The first `sdlc milestone-close` boundary review returned **REWORK** (one
Critical, two Important). All addressed; re-review returned **FIX-THEN-SHIP**
(no Critical). Deltas to the as-built design vs. the task text above:

- **`base_registry` ships as `base.build(config)`, NOT a static `M.descriptors`
  (supersedes Task 3 Step 1 + the Core-concepts "Pure data; no IO" line).** It is
  a *pure function of live config* — still pure (deterministic, no IO) but reads
  the config passed by the caller, not a load-time snapshot of defaults. This was
  the **I2** fix: a module-load snapshot ignored user overrides of
  `chat_dir`/`notes_dir`. RegistryBuilder calls `base.build(_parley.config)`.
- **C1 (Critical, fixed):** `discovery.current()` read `require("parley.config")`
  — the immutable *default* table that never gets `repo_root`/`super_repo_members`
  — so it returned a base-only registry in *every* mode. Now `discovery.setup(parley)`
  injects the live `M` (same pattern as `super_repo.setup`/`note_dirs.setup`) and
  `current()` reads `_parley.config`. Wired `discovery.setup(M)` in `init.lua`.
  Regression test: `discovery_builder_spec.lua` "current — live-config wiring".
- **I1 (Important, fixed):** `render()`'s find-hint must stay repo-relative even
  on the *built* registry (whose locate globs are absolute). The builder now
  precomputes `find_hint` from the RELATIVE descriptor BEFORE glob expansion and
  stashes it; `render()` prefers it. Regression test: builder spec "render of the
  built registry".
- **I-A (Important, fixed):** `spec_to_command` now `shellescape`s every
  interpolated value (globs, frontmatter pattern, content term) — a term with a
  quote can't break/inject the command.
- **I-C (Important, fixed):** the pure merge logic (`expand_locate`,
  `dedupe_compose`) moved to a new pure module `lua/parley/discovery/merge.lua`,
  unit-tested directly (no rg) — `discovery_merge_spec.lua`. RegistryBuilder is
  now thin glue over it.
- **descriptor.validate** now enforces kind-specific matcher fields (a bare
  `{kind="frontmatter"}` was silently always-true).

### M2-carried decision — execution model for the built (absolute-glob) registry

**I-B (deferred to M2, by design — execution is M2 scope).** On the *built*
registry the `locate` globs are absolute (repo-prefixed), so
`spec_to_command`'s `rg … -g '<abs>' .` anchors the glob under cwd and matches
nothing. `query()` compiling a correct pipeline holds for the *base* (relative)
registry; the built registry needs M2 to reconcile glob-vs-search-root.
`discovery_builder_spec.lua` "spec_to_command on a built registry (I-B / M2
seam)" **pins the current absolute-glob output** so M2 changes it consciously
(not a silently-empty search). **M2 decision to make first:** either return a
structured argv (dir-roots + term + frontmatter) and let the executor render
safely with `shellescape`, or set the rg search-path to each root and pass only
the filename glob via `-g`. Decide before M2/#115 consume `query()`.

### 2026-06-30 — M2 = data-correctness layer; I-B FOLDED INTO M2 (not deferred); cue-sourced issue home

Settles the M2-carried open decision above, and reframes M2/M3 after auditing
the cue→weave→parley pipeline.

- **M2 owns "correct data sourced from `issue.cue`"; #115 owns common UI
  treatment** (operator framing). Under that split **I-B is a data-correctness
  bug → fixed in M2**, not deferred. Rationale `ARCH-PURPOSE`: the data layer is
  the point; shipping a half-broken `query()` because no current finder calls it
  is under-delivery. Fix = structured-argv **root cause** (search-dirs as rg
  positional paths, relative filename globs), not a patch.
- **Transport confirmed (already in production):** parley reads weave-emitted,
  gitignored `construct/generated/vocabulary/issue.json` via
  `lua/parley/issue_vocabulary.lua` (status today; we add `discovery.home`). No
  commit/vendor/runtime-shell-out. parley is a weave derivative
  (`construct/deps` → `substrate ../ariadne`).
- **Repo-sourcing realized via cue:** add `discovery:{home,glob}` to ariadne
  `issue.cue` (Task M2.1); the emit is automatic. ariadne#145 carries the deeper
  *creation-from-cue* unification (`sdlc issue new`'s template is hardcoded Go
  today). chat/note/vision stay parley-native.
- **M3 = `sdlc issue new` delegation** (retire `render_issue_template`), not a
  descriptor scaffolder. See the M3 section + the #116 issue revision.
- Tasks: the "M2 tasks (expanded 2026-06-30)" subsection in the M2 section.
