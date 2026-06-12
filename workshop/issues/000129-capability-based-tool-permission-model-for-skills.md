---
id: 000129
status: open
deps: [000128]
github_issue:
created: 2026-06-11
updated: 2026-06-11
estimate_hours:
---

# Capability-based tool permission model for skills

## Problem

Today tools are controlled per **agent definition** (e.g. `ToolSonnet` carries
write tools, plain `Sonnet` doesn't). Two problems:

1. Even with a write-capable agent, you usually want writes only during a
   *deliberate* skill invocation (e.g. `/review`), not ambiently for the whole
   session. Ambient write authority is a footgun and the source of a
   confused-deputy risk (the LLM can mutate without a human asking).
2. It bloats the agent zoo: `ToolSonnet` vs `Sonnet` exist only to carry
   different tool sets.

The settled model: **knowledge is free; power requires a human act.** The LLM can
*think* like a reviewer on its own initiative, but can only *act* (mutate) when a
human deliberately invoked the skill. The model can never self-escalate its own
permissions. This is the concrete mechanism behind "readonly harness with a
human-gated write middle-tier."

Settled in the brain design conversation 2026-06-11. Builds on the manifest's
`tools`/`elevated` fields from #128.

## Spec

**Two-tier tools on a skill** (#128 manifest):
- `tools` — granted whenever the skill is active, *including* model `auto`-selection;
- `elevated` — granted **only** via manual/human invocation.

**Authorization rule** for any tool call:

```
permitted = agent.ambient_tools
          ∪ (⋃ active skills' .tools)
          ∪ (⋃ .elevated of skills whose activation IN THIS CHAIN was manual)
```

**Invariants:**
- *The model never self-elevates.* `auto`-activation contributes `.tools` but
  **never** `.elevated`. Only a human manual invocation — or a config-ambient
  grant — adds elevated capability.
- *Grants are scoped to the **call chain** rooted at the granting act, not the
  session.* Recursive tool calls under a manual invocation inherit its grant
  (so the loop can finish its edits); a later *unrelated* human turn is a **new
  chain** with ambient-only perms — no leak. (This is the safe reading of "the
  recursion's trigger was manual.")
- *Session-wide grants only via an explicit **sticky toggle*** (like super-repo
  mode `<C-g>S`), never as an accidental bleed from a one-shot invocation. Two
  manual modes: **one-shot** (chain-scoped, default) and **sticky** (session
  until toggled off). The model can't self-elevate in either.
- *Elevation is **chain-level, not per-skill.*** Once a human opens a
  write-capable chain (e.g. `/review`), an `auto`-picked helper skill later in
  that same chain inherits the chain's elevated tools — the human already
  sanctioned the write-flow.

**Consequences (features, not just safety):**
- **Collapses the agent zoo.** One readonly-ambient agent + just-in-time write
  grants from manual skills, instead of `ToolSonnet` vs `Sonnet`. Config-ambient
  grants remain as a power-user escape hatch ("trust this agent, let it write
  without ceremony"); the *default* is readonly + human-gated elevation.
- **Dry-run vs commit falls out for free.** The same `review` skill: `auto`-picked
  it has `read_file` only → proposes edits *in prose*; manually invoked it gets
  `propose_edits`/`edit_file` → *applies* them. The activation path itself
  produces suggest-vs-commit, no extra design.

## Done when

- A skill can declare `elevated` tools granted only on manual invocation.
- The dispatcher authorizes a tool call iff it is in the chain's accumulated
  grant set (ambient ∪ active `.tools` ∪ manual-chain `.elevated`); `auto`
  selection cannot add elevated tools.
- Grants are chain-scoped: a fresh unrelated turn starts ambient-only; a sticky
  toggle is the only way to persist a grant across turns.
- Demonstrated end-to-end: `/review` (manual) can edit; an `auto`-picked review
  can only propose in prose; a normal turn *after* `/review` cannot edit.
- Agent definitions no longer need bespoke write-tool variants for the common case.

## Plan

_Detail in a plan doc with #128 (the manifest + dispatcher changes are
intertwined). Rough shape:_

- [ ] thread a per-chain permission set through the tool loop (root = manual invocation or config-ambient)
- [ ] dispatcher authorization check against the chain grant set (extends the existing cwd-scope prelude)
- [ ] `tools` vs `elevated` honored by activation path (auto adds tools only; manual adds both)
- [ ] sticky-toggle mode for session-scoped grants
- [ ] migrate agent defs to readonly-ambient default; keep config-ambient as opt-in

## Log

### 2026-06-11

Filed from the brain design conversation alongside #128. Product behavior
settled (capability-based, chain-scoped, human-gated; model never
self-elevates). Depends on #128 for the manifest's `tools`/`elevated` and the
one-engine chain to scope grants against.
