---
id: 000221
status: open
deps: []
github_issue:
created: 2026-09-07
updated: 2026-09-07
estimate_hours:
---

# Tool discoverability: @all should mean @all public

## Problem

`emit_definition` is the define feature's **output channel** — the model calls it
to deliver `{term, definition}`, its handler is a deliberate no-op, and
`render_definition` (`init.lua:1863-1867`) reads the answer out of the call's
*arguments*. It is not a capability.

But it is registered in `BUILTIN_NAMES` (`tools/init.lua:167`), so `@all` picks
it up — and the only agent parley ships, `ToolOpus*`, declares
`tools = { "@all" }` (`config.lua:226`). So every chat advertises it, described
to the model as *"Return a concise definition of the selected term… Call this
exactly once with your answer."*

Found by the operator while smoke-testing #214: a branched child seeded with
`<M-q>` quotes reading "what's this" is a definition-shaped question, and the
model obliged. Outside `define`, nothing reads the arguments — the handler
returns `""`, the tool loop feeds that back, and the model answers again in
text. The cost is a wasted round-trip, a spurious `🔧:`/`📎:` pair in the
transcript, and an answer that arrives a hop late. Not data loss (I checked
before claiming it), but noise in the artifact the user is trying to read.

The instance is `emit_definition`. **The class is that a wildcard selector
offers every registered tool, including ones that belong to one feature.**

## Spec

A tool declares whether it may be offered *without being asked for*. Wildcard
selectors match only tools that do; a tool named explicitly always resolves.

- **`@all` means "all public"** (operator's framing). Same for `@readonly` and
  any later group — discoverability composes with the group's own predicate
  rather than being a group of its own.
- **Opt-in, because the failure costs are asymmetric.** A general tool that
  forgets the flag is missing from `@all` — visible immediately, no damage. A
  private tool that forgets it leaks into every agent — silent, which is the bug
  being fixed.
- **"Forgot to decide" must not be silent either.** Default private (fail
  closed) *and* assert that every builtin declares the field explicitly. Same
  reasoning as `skill_assembly.is_partition` (#215) and #214 BR-80: when a wrong
  answer is costly, require the decision rather than fabricating a default.
- **Explicit naming is consent.** `skills/define/init.lua:15` already declares
  `tools = { "emit_definition" }`; that keeps working unchanged, and any agent
  may name a private tool deliberately.
- **Not in scope:** an `output_only` marker. `emit_definition` is *also*
  output-only — its call IS the answer, so a loop that understood that could
  terminate on it instead of round-tripping an empty result. That is a real
  second property (private and output-only are independent), but nothing needs
  it once the tool stops being offered. Recorded here as the reason a leak is
  harmful, not as work.

The seam already exists: `expand_group` (`tools/init.lua:96-117`) has exactly
one `keep` predicate per group, so this is one condition applied to every group.

## Done when

- A tool declares its discoverability; `@all` and `@readonly` return only
  discoverable tools, and an explicitly named private tool still resolves —
  asserted in both directions, seen red.
- Every builtin declares the field explicitly; a builtin that omits it fails a
  test rather than defaulting.
- `emit_definition` is private, and a test asserts `@all` does not contain it
  while `select({"emit_definition"})` does.
- `define` is unaffected: its skill invocation still gets the tool.
- The atlas records the property where the tool contract is documented.

## Plan

- [ ] Add the field to the ToolDefinition contract + `atlas/` docs
- [ ] Filter every group expansion on it; test `@all`/`@readonly` both ways
- [ ] Declare it on all ten builtins; assert no builtin omits it
- [ ] Mark `emit_definition` private; confirm `define` still works end-to-end

## Log

### 2026-09-07

Split out of #214 rather than added as a milestone: #214's Done-when is entirely
keybinding clauses (M3 already had to add one because its boundary had nothing
to certify against), this is behaviour in a different subsystem, and #214 is at
14.53h against a 3.83h estimate — a fourth milestone would make that number
useless for calibration.

Related but distinct: **#209** (safe-by-default posture) and **#210** (consent
model for write-capable tools). Neither covers this: the defect is not that the
tools are dangerous, it is that a private one is offered at all. Worth noting
alongside them that `@all` currently includes `edit_file` and `write_file` — that
part belongs to #210.
