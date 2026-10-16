---
id: 000236
status: working
deps: []
github_issue:
created: 2026-09-11
updated: 2026-10-16
estimate_hours:
card_mirror: 'cafd037b6a6adafcfd884200ea9c2346c0c0787c' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T05:39:39-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "a6fe848e", done: "1b0ee071"}
---

# delete unreachable modules and dead config

## Problem

Code that never runs still ships, loads, and carries tests. This is the Tier 4
list from `workshop/plans/000206-shipping-surface-inventory.md`, split from #213
on 2026-09-11 and kept outside the v1 release. Each row was checked against the
code that day; several had drifted from the audit.

| Thing | State |
|---|---|
| `lua/parley/discovery/` (7 files, 7 specs) | Required at plugin load and given `setup(M)` (`init.lua:99-101`); stored as `M.discovery`, which nothing reads. `local_types.lua:17` probes `executable("rg")` at require time. Its planned consumer is #115 (faceted typed finder), which #116 handed the generic faceted picker to at close |
| `skill_registry.lua:66-68` | `repo_generators` / `virtual_generators` seams, always passed empty |
| `lua/parley/spinner.lua` | Empty placeholder; nothing requires it |
| `lua/parley/test_agent_picker.lua` | 16-line scratch harness; nothing requires it; untouched since 2025-05-26 |
| `lua/parley/google_drive.lua` | Two-line alias for `parley.oauth`; nothing requires it |
| `lua/parley/obfuscate.lua` | XOR helper required only by its own spec; `oauth.lua` does not use it. Not in the audit |
| `lua/parley/review.lua` | Shim, but live: `highlighter.lua:391` reads `_parse_marker_sections` through it, and `tests/unit/review_spec.lua` runs 48 marker-parsing tests through it |
| `command_prompt_prefix_template` | Read at `init.lua:4847` to build the `cmd_prefix` field `get_agent()` returns; nothing reads that field |
| `command_auto_select_response` | Nothing reads it (`config.lua:658`) |
| azure adapter | `providers.lua:1215-1237`, `tools/wire.lua:39`. Not in the default `config.providers`, no `api_keys.azure`; reachable only through an undocumented user `providers` table (`init.lua:586`) |
| panvimdoc markers | `README.md:1,7`; there is no panvimdoc and no `doc/`. #206's README rewrite may remove them first |

Stale references to clean up with them: `atlas/discovery/registry.md`,
`atlas/index.md:78`, `atlas/traceability.yaml:213,679,762`, and the azure text
in `atlas/providers/{architecture,openai,tool_use}.md`.

## Spec

Delete what does not run, and add a check that catches the next orphaned module.

- Delete each row with its specs and atlas entries, except as noted below.
- `review.lua`: point `highlighter.lua` at `parley.skills.review`, which exports
  `_parse_marker_sections` (`:340`), then delete the shim. Repoint
  `review_spec.lua` at `parley.skills.review` instead of deleting it; it is the
  main coverage of marker parsing.
- `command_prompt_prefix_template`: delete it together with `get_agent()`'s
  `cmd_prefix` field (`init.lua:4848,4863`) and its docstring.
- discovery: decide at plan time, since #115 is designed on its
  `TypeDescriptor` and `Matcher`. Recommended: delete it along with the
  `skill_registry` seams, and add a note to #115 naming the commit to restore
  from.
- azure: remove it, with the same setup notice #213 adds for copilot.
- Reachability check in `tests/arch/`: walk the static `require` graph from the
  real entry points (`parley`, `parley.health`, the builtin tool list at
  `tools/init.lua:155`, which is loaded by name, and each skill directory,
  loaded by `loadfile` at `skill_providers.lua:113`) and fail on any module in
  `lua/` it does not reach. State its limit: it finds orphaned files, not
  modules that are required but never used, which is what discovery is today
  (`ARCH-PURPOSE`).

## Done when

- Every row above is deleted, or kept with the reason recorded in the Log.
- The reachability check fails on a planted orphan and passes on the tree.
- `make test` passes, with spec and test counts before and after recorded in
  the Log. The repo has no coverage tool; adding luacov is a plan-time decision.
- `rg` over `atlas/` finds no reference to a deleted module.

## Core concepts

| Entity | Status | Where | What |
|---|---|---|---|
| `current` | changed | lua/parley/skill_registry.lua | `skill_registry.current()` takes no options: the repo/virtual generator seams it forwarded were always empty and are gone. |
| `virtual` | deleted | lua/parley/skill_providers.lua | The virtual provider: its only callers were the two empty seams, and its planned consumer (`repo_discovery`) was withdrawn as a category error. |

## Plan

Evidence, 2026-10-16 (base 5abad047). Production code has exactly one require by computed name: `tools/init.lua` loads `"parley.tools.builtin." .. name` over BUILTIN_NAMES and OPTIONAL_NAMES. (The first draft of this Plan said none; the reachability check found the OPTIONAL list.) Every other `require` in `lua/` takes a string literal, and the only `loadfile` is skill_providers' skill-directory loader. So a literal reference scan plus those name lists is complete for `lua/`.
- `spinner`, `test_agent_picker`, `google_drive`: no reference anywhere outside their own files.
- `obfuscate`: required only by its own spec; `oauth.lua` does not use it.
- `review.lua` shim: **now unreached in production**. `highlighter.lua` no longer reads through it, and `comment/view.lua` requires `parley.skills.review` directly. Only `tests/unit/review_spec.lua` requires the shim.
- `skill_registry` `repo_generators` / `virtual_generators`: no caller passes either, so both are always `{}`.
- `command_prompt_prefix_template`: read only to build `get_agent()`'s `cmd_prefix` field. No reader of an agent's `.cmd_prefix` exists in `lua/` or `tests/` (`config.cmd_prefix` is a different field).
- `command_auto_select_response`: no reader.
- panvimdoc markers: already gone from README.md.
- Azure: **reachable**, through a user `providers` table that the dispatcher routes. And #213 never added the copilot setup notice the Spec cites (copilot still ships). Not dead, so it is kept, unless the TL decides to drop the provider.
- discovery: required at load (`init.lua:109`), but `M.discovery` has no reader. It is the foundation open #115 is designed on (`TypeDescriptor`, `Matcher`). This is a design call for the TL. Recommended (the Spec's): delete, with a note in #115 naming the restore commit.

Baseline counts (5abad047): 442 spec files, 6397 `it()` cases, 247 `lua/` files, 74823 `lua/` lines.

- [x] Delete spinner, test_agent_picker, google_drive, obfuscate (+ its spec).
- [x] Repoint `review_spec.lua` at `parley.skills.review`; delete the shim.
- [x] Drop the `skill_registry` generator seams; drop both dead config keys and `get_agent()`'s `cmd_prefix` field.
- [x] discovery and azure per the TL's call.
- [x] Reachability arch check: the static require graph from the entry points (`parley`, `parley.health`, the builtin tool names, each skill directory, loaded by `loadfile`). It fails on any unreached `lua/` module; seen red with a planted orphan. Its stated limit: it finds orphaned files, not required-but-unused modules (ARCH-PURPOSE).
- [x] After-counts, atlas and traceability cleanup, and a scan of `atlas/` for deleted names.

## Log

### 2026-09-11

Split from #213, which kept only the v1 blockers (checkhealth and copilot).
Outside the v1 release by operator decision. A require-graph scan from the
entry points in the Spec found six unreached modules: `spinner`,
`test_agent_picker`, `google_drive`, `obfuscate`, `discovery.descriptor` and
`discovery.matcher`. The rest of discovery counts as reached only because
`init.lua:99` requires it.

### 2026-10-16 (parley.nvim:4)
- 2026-10-16: closed — Full suite green on d1daab0a (sdlc-local/suite); the later commits are atlas/docs and lua comment-only edits (lint clean). Round-2 fix: no lua/ comment names the removed skill seams (init.lua:107; skill_manifest.lua:4 and :14); the concept sweep now covers lua/ and tests/ as well as atlas/ and README. All earlier evidence holds (rows, reachability check red on a planted orphan, counts, net minus 1744 lines).; review verdict: SHIP

Row by row (base 5abad047):

| Row | Outcome |
|---|---|
| `spinner`, `test_agent_picker`, `google_drive` | Deleted (no reference anywhere). `google_drive.lua` also dropped from atlas/context/google_drive.md and traceability. |
| `obfuscate` | Deleted with `tests/unit/obfuscate_spec.lua` (only that spec required it). |
| `review.lua` shim | Deleted. `highlighter.lua` no longer read through it, and `comment/view.lua` requires `parley.skills.review` directly. `review_spec.lua` (48 cases) now requires `parley.skills.review`; the atlas `modes/review.md` shim entries are removed. |
| `skill_registry` seams | Deleted, with `skill_providers.virtual` and its 3-case spec block: the seams were its only caller. |
| `command_prompt_prefix_template` | Deleted with `get_agent()`'s `cmd_prefix` field (no reader of an agent's `.cmd_prefix`). |
| `command_auto_select_response` | Deleted (no reader). parley does not validate unknown setup keys, so a user who sets either key sees no change: they already did nothing. |
| discovery | **Deleted by TL decision** (no reader; loaded on every start for an unscheduled feature): 7 modules, 7 specs, `atlas/discovery/registry.md`, the index line, the traceability block, the init.lua require, and its spawn_seam allowlist entry. #115 has a restore note naming main commit `5abad04737d396828eb9614b28c20dbec43d7486`. |
| azure | **Kept, by TL decision**: it is reachable through a user's `providers` table, which the dispatcher routes. The Spec's "same setup notice #213 adds for copilot" does not exist (#213 kept copilot, which still ships). The atlas azure text stays accurate. |
| panvimdoc markers | Already gone from README.md before this issue. |
| `tools/version.lua` | **New, found by the reachability check**: a 7-line helper (`stable_command_version`) that nothing names anywhere. Deleted. |

- Reachability check `tests/arch/module_reachability_spec.lua`:
  - It walks literal `require` / `pcall(require, …)` / `package.loaded[…]` edges.
  - Entries: `parley`, `parley.health` and `parley.starter`; BUILTIN_NAMES and OPTIONAL_NAMES; each skill directory; and what packaging/ and scripts/ require.
  - Its first run found three modules. `parley.tools.builtin.ack` (OPTIONAL_NAMES) and `parley.editor_bundle` (the packaging launcher and the export script) were gaps in my entry list, now fixed. `parley.tools.version` was the real orphan.
  - Seen red on a planted `lua/parley/zz_planted_orphan.lua`, and on a synthetic graph, where a planted orphan requiring others is still unreached.
  - Its limit: it finds orphaned files, not required-but-unused modules (ARCH-PURPOSE).
- Counts, before (5abad047) → after:
  - spec files 442 → 435;
  - `it()` cases 6397 → 6319;
  - `lua/` files 247 → 234;
  - `lua/` lines 74823 → 73980.
  - Branch diff vs main: 36 files, +142 / −1886, a net deletion of 1744 lines (counted at the change, before the commit of this log).
- `atlas/`, README, the Makefiles and scripts/ have no reference to a deleted module, and every file traceability.yaml routes exists.
- Close round 1 (FIX-THEN-SHIP):
  - BR-1: `atlas/skills/skill-system.md` still described the deleted virtual provider and generator seams. My atlas scan had matched module PATHS, not the concepts the deleted code carried. The re-sweep covered `atlas/` and README by concept name: virtual provider, generators, repo_discovery, TypeDescriptor, Matcher, discovery registry, cmd_prefix field, the two config keys, the shim, the alias, the tools/version helper. That page was the only remaining instance; it now states the actual stack (plugin, then user).
  - Minor: the empty "10. Discovery Registry" heading is gone from `atlas/index.md`, and Traceability is 10.
- Close round 2 (BR-1 kept open): the concept re-sweep had covered `atlas/` and README but not `lua/` comments. Three comments still named the removed seams: `init.lua:107`, and `skill_manifest.lua:4` and `:14`. All three are fixed. The concept sweep is now run over `lua/` and `tests/` too; the other "virtual" hits are Neovim virtual lines and virtual text, which are unrelated.

