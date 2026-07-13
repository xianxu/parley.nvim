# Everyday Cooking Progress Verbs Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Parley's repetitive lowercase progress vocabulary with the 28 approved capitalized cooking and everyday-life words.

**Architecture:** Change only the private verb data owned by `chat_pending`; retain the existing pure reducer injection and all rotation/timing behavior. Integration tests drive deterministic indices so the rendered capitalization and distinct activity/idle entries are observable without exposing a new API.

**Tech Stack:** Lua, Neovim extmarks, Plenary/Busted.

---

## Core concepts

### Pure entities

No pure entities change. `chat_presentation` continues to accept an injected
non-empty verb array and remains the single source for rotation semantics.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| Playful verb pool | `lua/parley/chat_pending.lua` | modified | User-visible Neovim pending copy |

- **Playful verb pool** — the private vocabulary supplied to the pure reducer
  by the existing UI adapter.
  - **Injected into:** `chat_presentation.initial`; no parallel list or public
    configuration is introduced (`ARCH-DRY`, `ARCH-PURE`).
  - **Future extensions:** widen this one list if the operator curates more
    vocabulary later.

## Chunk 1: Replace and verify the vocabulary

### Task 1: Pin the approved pool through rendered behavior

**Files:**
- Modify: `tests/integration/chat_pending_spec.lua`
- Modify: `lua/parley/chat_pending.lua:11`

- [ ] **Step 1: Write the failing adapter assertions**

Add one table-driven adapter case containing the exact 28 approved words. For
each controlled chooser index, start a session, record the chooser's `count`
argument, reveal it, and assert the rendered suffix is the corresponding word.
Require every observed count to equal 28. This proves exact order, cardinality,
capitalization, and membership without exposing the private pool solely for
testing; it also excludes `dragon-slaying`.

Update the deterministic activity/idle case to require `Brewing`,
`Caramelizing`, and `Zesting`, using chooser indices 2, 3, and 28.

- [ ] **Step 2: Run the focused spec and verify RED**

Run:

```bash
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/integration/chat_pending_spec.lua" -c "qa!"
```

Expected: FAIL because the existing pool is lowercase, has only three entries,
and index 28 does not select `Zesting`.

- [ ] **Step 3: Replace the private verb pool**

Set `verbs` in `chat_pending.lua` to the exact 28-item approved capitalized list
from the issue Spec. Do not modify the reducer, timers, chooser, or renderer.

- [ ] **Step 4: Update remaining capitalization assertions and verify GREEN**

Update existing deterministic expectations from lowercase `brewing` to
`Brewing`, then rerun the focused spec. Expected: all cases pass.

- [ ] **Step 5: Run mapped and repository verification**

Run:

```bash
make test-spec SPEC=chat/response_progress
make lint
make test JOBS=1
git diff --check
```

Expected: all mapped specs and the serialized repository suite pass; lint and
diff checking are clean.

- [ ] **Step 6: Record implementation evidence and commit**

Check all implementation/verification rows once their evidence exists. Append
RED/GREEN/full-suite evidence to the issue Log, and commit only #185's source,
test, issue, and plan files. The issue is then structurally ready for close.

- [ ] **Step 7: Close, publish, and record completion**

Run `sdlc actual --issue 185`, then pass its measured suggestion to:

```bash
sdlc close --issue 185 --actual <measured> --agent codex \
  --verified '<behavior evidence>'
```

Commit the close artifacts with the emitted review trailers. After a `SHIP`
verdict, run:

```bash
sdlc pr
sdlc merge --yes
```

The merge gate publishes and archives the already-complete issue and plan; no
post-merge bookkeeping commit is needed. Preserve the operator's unrelated #162
working-tree edit throughout.
