# Boundary Review — parley.nvim#194 (whole-issue close)

| field | value |
|-------|-------|
| issue | 194 — Preserve folds during inline-comment submission |
| repo | parley.nvim |
| issue file | workshop/issues/000194-preserve-folds-during-inline-comment-submission.md |
| boundary | whole-issue close |
| milestone | — |
| window | d0f1b4c83a4e3d5e1714325aee348dc1aca2e6fb..HEAD |
| command | sdlc close --issue 194 |
| reviewer | codex |
| timestamp | 2026-07-17T16:57:08-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

The implementation delivers the intended bounded-edit behavior and preserves
manual folds through both end and branch drill-in submission. The review found
no correctness blocker.

### Strengths

- `drill_in.gather_edit_plan` keeps marker and anchor planning pure while
  preserving the compatibility surface of `gather_and_strip`.
- `buffer_edit.apply_text_edits` validates the complete plan before mutation
  and applies original-coordinate edits bottom-to-top.
- Branch and end submission share the same bounded edit applicator
  (`ARCH-DRY`, `ARCH-PURE`).
- Production integration tests exercise real closed manual folds and gutter
  markers for both submission paths.

### Findings

- Important: the durable plan promised production coverage for multiple
  trailing blanks and a marker on the final physical line, but those two cases
  were not explicit in `chat_respond_spec.lua`. Add both before shipping.
- Minor: `buffer_edit.replace_all_lines` still described drill-in as a caller;
  update the stale comment.

### Architecture

- `ARCH-DRY`: pass — one edit representation and applicator serve both paths.
- `ARCH-PURE`: pass — planning is pure and Neovim mutation is isolated.
- `ARCH-PURPOSE`: pass on behavior; the missing promised edge cases must be
  instantiated before shipping.

### Resolution

The close commit adds the two production edge tests, corrects the stale comment,
and records the resulting lesson. No plan revision is required.
