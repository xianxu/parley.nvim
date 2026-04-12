---
id: 000084
status: open
deps: [000081]
created: 2026-04-09
updated: 2026-04-09
---

# transcript-driven filesystem reconciliation (backtrack)

Parent: [issue 000081](./000081-support-anthropic-tool-use-protocol.md)

Elevate parley's chat transcript from a historical record into a **declarative specification** of the filesystem. The transcript becomes the source of truth; the filesystem state is derived by applying the recorded tool calls against a captured initial state. Editing the transcript re-derives the filesystem.

Mathematically:

```
apply(initial_filesystem, transcript) → current_filesystem
```

## Modes unlocked (all fall out of the same replay function)

1. **Edit in place.** User edits `new_string` inside a past `🔧: edit_file` block; parley re-applies. File reflects the edited version as if the LLM had produced it that way.
2. **Delete to undo.** User deletes a `🔧:` block (or wraps in `🔒:`); parley replays the chain without that step.
3. **Manual authoring.** User writes a `🔧: edit_file` or `🔧: write_file` block by hand; parley applies it. Transcript is a scriptable persistent file editor.
4. **Reorder.** User moves a tool call earlier in the transcript; parley replays in the new order.
5. **Branch & resume.** User truncates at a prior `🔧:`, edits the tool result, re-runs LLM from that point.

## Prerequisites landed by #81

- `edit_file` is naturally reversible (old_string/new_string both in the call).
- `write_file` pre-image is captured on first write as `<path>.parley-backup`, referenced from the `📎:` result body as `pre-image: <path>.parley-backup`.
- New-file writes create a sentinel `<path>.parley-backup` with `# parley:deleted-before-write`.
- Read-only tools (`read_file`, `list_dir`, `grep`, `glob`) are NOT replayed — results are historical facts matching parley's existing `@@` file embed semantics.

## Open design questions (to brainstorm when this ticket becomes active)

- **Partial vs full replay.** Partial re-run of the edited block only (cheap, usually right, can't express Mode 2) vs full chain replay from pre-image (correct, handles all 5 modes uniformly).
- **Apply trigger.** Explicit keybind (e.g., `<C-g>r` for "reconcile") vs auto-apply-on-save. Lean: explicit.
- **Non-determinism guards.** What if the filesystem was modified outside parley since the transcript was written? Refuse replay, or warn, or force?
- **Dirty-buffer interaction.** Replay touching a file with unsaved changes — same dirty-buffer rule as #81's write tools (refuse), or override?
- **Multi-write to same path.** Only the first `write_file` creates a backup (per #81). Replay must understand that intermediate writes have no pre-image of their own — the chain is reconstructed from the initial backup forward.
- **Delete semantics.** #81 has no `delete_file` tool. If added later, same `.parley-backup` convention applies.
- **Integration with #85** (file reference freshness) — both features are about transcript/filesystem consistency; designs should compose cleanly.

## Done when

- (TBD — brainstorm when ticket becomes active)

## Plan

- [ ] Brainstorm after #81 lands and has been used enough to surface real pain points

## Log

### 2026-04-09

- Created as a follow-up to the #81 brainstorm when the user described "transcript as source of truth" backtrack modes
- #81 will capture pre-image data via `.parley-backup` files so this ticket has the raw data it needs
