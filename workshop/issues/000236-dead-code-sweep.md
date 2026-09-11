---
id: 000236
status: open
deps: []
github_issue:
created: 2026-09-11
updated: 2026-09-11
estimate_hours:
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

## Plan

- [ ] Decide discovery vs #115; if deleted, note the restore commit in #115.
- [ ] Delete the unused modules with their specs and atlas entries; record counts before and after.
- [ ] Point `highlighter.lua` and `review_spec.lua` at `parley.skills.review`; delete the shim.
- [ ] Remove the dead config keys and `get_agent()`'s `cmd_prefix` field.
- [ ] Remove azure, with a setup notice.
- [ ] Add the reachability check; see it fail on a planted orphan.

## Log

### 2026-09-11

Split from #213, which kept only the v1 blockers (checkhealth and copilot).
Outside the v1 release by operator decision. A require-graph scan from the
entry points in the Spec found six unreached modules: `spinner`,
`test_agent_picker`, `google_drive`, `obfuscate`, `discovery.descriptor` and
`discovery.matcher`. The rest of discovery counts as reached only because
`init.lua:99` requires it.
