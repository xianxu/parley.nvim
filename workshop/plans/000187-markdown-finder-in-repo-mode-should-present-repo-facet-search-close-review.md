# Boundary Review — parley.nvim#187 (whole-issue close)

| field | value |
|-------|-------|
| issue | 187 — markdown finder in repo mode should present repo facet search |
| repo | parley.nvim |
| issue file | workshop/issues/000187-markdown-finder-in-repo-mode-should-present-repo-facet-search.md |
| boundary | whole-issue close |
| milestone | — |
| window | 6c0579776239fa26c78d2faf9d03d9739a791e5c..HEAD |
| command | `sdlc close --issue 187` |
| reviewer | codex |
| timestamp | 2026-07-14T22:31:54-07:00 |
| verdict | FIX-THEN-SHIP |

## Summary

The implementation fulfills #187's behavioral and architectural purpose:
contextual facets are explicit, session states are separate, runtime
super-repo state is authoritative, and query persistence is verbatim. No
correctness or architectural blocker was found. Shipping was sanctioned after
adding README discoverability and recording a clean full-suite rerun.

## Strengths

- Shared eligibility replaces Issue Finder's private implementation without
  changing its behavior.
- `markdown_finder.build_picker_data` is deterministic and side-effect free;
  runtime state and filesystem/UI work remain in `open`.
- Super-repo facets derive from active member roots, retain zero-row
  repositories, reject incomplete identity domains, and avoid partial
  filtering.
- Query callbacks preserve exact whitespace and clearing, while facet repaint
  passes only items and tags to the picker.
- Atlas pages and traceability mappings cover the new flow and terminology.

## Findings and resolutions

### Important — README discoverability

`README.md` did not mention `:ParleyMarkdownFinder` / `<C-g>m`, its contextual
directory/repository facet bar, or in-session query persistence.

Resolution: added the keybinding and corresponding command to README's basic
command surfaces, including the contextual facet and persistence behavior.

### Minor — stale module comments

The Markdown Finder header described only directory facets, and `_scan_members`
documented the display as `<repo>/<relative>` instead of `{repo} <relative>`.

Resolution: corrected both comments to match the implementation.

### Verification retry

The review's independent `make test` run hit an unchanged process-fixture race:
the fake SSE server's ready file became readable after `open()` but before the
port write/close, so one attempt read `port=nil`. The review's immediate retry
then encountered temporary swap-file errors left by the failed run. A clean
standalone retry of `chat_progress_process_spec.lua` passed 7/7. No #187 code
participates in that fixture path; the final close commit records a fresh clean
full-suite run.

A subsequent full run exposed another unchanged parallel-test race in
`tools_builtin_find_spec.lua` while `find .` traversed files being created or
deleted by other suites; its isolated rerun passed 4/4. The final fresh
`make test` run then passed all 105 unit and 40 integration/architecture spec
files, including both process and find suites.

## Test coverage notes

- Focused suites independently passed: `finder_facets_spec.lua` 17/17,
  `markdown_finder_spec.lua` 15/15, `issue_finder_spec.lua` 19/19, and
  `super_repo_spec.lua` 23/23.
- `make lint` passed across 270 files.
- Coverage pins both facet domains, runtime mode switching, root-derived empty
  facets, ineligible aggregation, NONE recovery, immutable policy inputs, exact
  query persistence, and selection/window behavior.

## Architecture

- `ARCH-DRY`: pass. Discovery, eligibility, transitions, filtering, and
  projection remain canonical in `finder_facets`; no parallel Markdown state
  machine remains.
- `ARCH-PURE`: pass. All pure entities are greppable and tested directly
  without filesystem or UI dependencies; the integration entities match their
  declared locations and responsibilities.
- `ARCH-PURPOSE`: pass. The complete contextual-facet and query-persistence
  purpose ships, and both Issue and Markdown consumers use the shared
  eligibility source.

## Plan revision recommendations

None. The durable plan matches the delivered entities and behavior.
