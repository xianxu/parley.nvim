---
id: 000066
status: working
deps: []
created: 2026-04-05
updated: 2026-04-06
---

# issue system to support links between parent/child issues

and keyboard short cut to jump between them

## Done when

- Parley-inserted cross-issue references use standard markdown links `[issue NNNNNN](./NNNNNN-slug.md)` (renderable in any markdown viewer).
- `cmd_issue_decompose` writes a markdown link in the parent's plan line and a `Parent: [...](...)` line in the child's body.
- `:ParleyIssueGoto` (`<C-y>g`) follows a markdown link under the cursor; with no link under cursor, it jumps to the current issue's parent (derived from `deps`).
- Vim's jumplist (`<C-o>`) returns to the previous issue.
- Pre-existing decomposed issues (no `Parent:` body line) still navigate child→parent.
- Spec, tests, and lint all green.

## Plan

- [x] Plan approved (see `/sandbox/.claude/plans/ticklish-squishing-hopcroft.md`)
- [x] Update `lua/parley/issues.lua`: add `parse_md_link_at_cursor`, `find_parent`, `cmd_issue_goto`
- [x] Update `cmd_issue_decompose` to emit markdown link + child `Parent:` backlink
- [x] Register `IssueGoto` command in `lua/parley/init.lua` (cmd table, shortcut, keybindings-help)
- [x] Add `global_shortcut_issue_goto` to `lua/parley/config.lua`
- [x] Add unit tests in `tests/unit/issues_spec.lua`
- [x] Update `specs/issues/issue-management.md`
- [x] Run `make test` and `make lint`
- [ ] Manual end-to-end check (decompose → goto child → goto parent → jumplist back) — to be performed by user

## Log

### 2026-04-06

- Reviewed existing code: `cmd_issue_decompose` already writes a custom `→ issue NNN` annotation; replacing with real markdown links per user instruction.
- `parse_frontmatter` (`issues.lua:81`) silently ignores unknown keys, so future schema changes are safe.
- `vision.lua:1718` (`cmd_goto_ref`) provides the cursor-column-based extraction pattern to mirror.
- Decision: child→parent navigation derives from `deps` at scan time (no schema change), so already-decomposed children keep working without migration.
