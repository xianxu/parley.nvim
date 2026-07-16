---
id: 000140
status: done
deps: []
created: 2026-06-25
updated: 2026-06-25
started: 2026-06-25T21:54:02-07:00
estimate_hours: 1.5
actual_hours: 1.5
---

# file read tool failed
file read failed for an nvim with cwd in brain, to read ../ariadne/README.md. why? is some permission system we have? we should allow such permission to be configurable, e.g. allow ../, or ~/workspace. etc.

## Done when

- A read tool (`read_file`/`ls`/`find`/`grep`/`ack`) can read a file under any
  configured root (e.g. `../`, `~/workspace`) even when it resolves outside cwd.
- Write tools (`edit_file`/`write_file`) stay cwd-confined regardless of config.
- Default config (`tool_read_roots = {}`) preserves today's cwd-only behavior.
- The rejection error names the `tool_read_roots` knob so the limit is discoverable.

## Spec

**Diagnosis.** All file tools route through one guard,
`dispatcher.execute_call` → `resolve_path_in_cwd(path, cwd)`
(`lua/parley/tools/dispatcher.lua`), which normalizes, `fs_realpath`-resolves
symlinks, and rejects any path not equal to / under `cwd` →
`"path outside working directory"`. From a `brain` cwd, `../ariadne/README.md`
resolves to a sibling outside cwd → rejected. Deliberate sandbox, hardcoded to
cwd-only.

**Design** (decisions confirmed: reads-only, global config):
- New global config `tool_read_roots = {}` — list of extra read roots: absolute,
  `~`-expanded, or relative-to-cwd (`../`). Opt-in; empty = current behavior.
- `resolve_path_in_cwd(path, cwd, allowed_roots)` gains `allowed_roots`; a path
  passes if it resolves under cwd **or** any root (each `fs_realpath`'d, so
  symlink escapes still caught). Rejection names `tool_read_roots`.
- `execute_call` passes the roots **only for `def.kind == "read"`** tools; write
  tools get `nil` → unchanged cwd-confinement.
- `tool_loop.lua` + `skill_invoke.lua` thread `read_roots = config.tool_read_roots`
  into `exec_opts`. The dispatcher stays the single path-safety guard.

## Plan

- [x] `resolve_path_in_cwd` + `resolve_root` helper: accept `allowed_roots`, pass if under cwd or any root.
- [x] `execute_call`: gate roots on `def.kind == "read"`.
- [x] Config `tool_read_roots = {}`; thread via `tool_loop` + `skill_invoke`.
- [x] Tests (`tools_dispatcher_spec`): root forms, symlink escape, read-vs-write gate.
- [x] Atlas (`providers/tool_use.md`): document the knob + read-only scope.
- [x] Verify: full `make test`.

## Revisions

### 2026-06-25 — boundary review (FIX-THEN-SHIP) addressed
- ARCH-DRY: the read-vs-write gate used `def.kind == "read"`, but `kind` defaults
  to read when absent and `@readonly` uses `~= "write"` — two predicates for "is a
  read tool." Switched the gate to `def.kind ~= "write"` (the canonical one) so an
  absent-kind read tool reaches configured roots; added a test for it (32/32 now).
- Moved the `resolve_path_in_cwd` EmmyLua doc block below `resolve_root` so its
  `@param`/`@return` attach correctly, and added `@param allowed_roots`.
- Tightened the write-rejection test to assert it does NOT carry the read-roots
  message (proves the nil-roots branch).

## Log

### 2026-06-25
- 2026-06-25: closed — tools_dispatcher_spec 31/31 (7 new #140: absolute + relative-to-cwd roots, symlink escaping cwd+roots rejected, symlink INTO an allowed root accepted, read-vs-write gate); full make test green (exit 0, incl. parley_harness_golden 7/7); luacheck clean. Diagnosis confirmed: resolve_path_in_cwd is the single cwd-scope guard; reads-only allowlist with edit_file/write_file staying cwd-confined per the confirmed design (def.kind gate). Atlas: providers/tool_use.md cwd-scope bullet updated. Actual labeled — active-time found no window.; review verdict: FIX-THEN-SHIP

