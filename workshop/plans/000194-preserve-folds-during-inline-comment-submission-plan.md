# Preserve Folds During Inline-Comment Submission Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Submit inline comments through bounded text edits so unrelated Parley and user manual folds retain their logical ranges and closed state.

**Architecture:** Extend the pure drill-in gatherer to expose the normalized original-coordinate edits it already derives, preserving `gather_and_strip` as a compatibility consumer. A thin `buffer_edit` adapter applies those edits from bottom to top with `nvim_buf_set_text`; `chat_respond` then performs each path's distinct bounded destination mutation instead of replacing the chat buffer.

**Tech Stack:** Lua, Neovim buffer/manual-fold APIs, Plenary/Busted.

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `drill_in.gather_edit_plan` | `lua/parley/drill_in.lua` | new |
| `DrillInEdit` | `lua/parley/drill_in.lua` | new |

- **`drill_in.gather_edit_plan(text, opts)`** — returns gathered blocks, the
  compatibility transformed text, and a deterministic normalized list of edits
  in original 1-based byte coordinates.
  - **Relationships:** one submission source owns 0:N `DrillInEdit` values and
    0:N formatted comment blocks. `gather_and_strip` delegates to it 1:1 so
    marker grammar and serialization remain single-sourced (`ARCH-DRY`).
  - **Conflict contract:** edits are sorted ascending and non-overlapping;
    zero-width bracket inserts at the same boundary have deterministic order.
    An inferred anchor candidate that overlaps a ready marker/anchor candidate
    is clipped/suppressed rather than enclosing marker syntax. The resulting
    compatibility text remains byte-identical to current expectations.
  - **Future extensions:** another bounded consumer can use the same edits
    without reconstructing a whole document.
- **`DrillInEdit`** — `{ byte_start, byte_end, replacement }`, where
  `byte_start == byte_end + 1` represents insertion at a boundary.
  - **Relationships:** N:1 with the original joined text; coordinates never
    refer to already-mutated content.
  - **DRY rationale:** one edit representation serves end and branch paths.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `buffer_edit.apply_text_edits` | `lua/parley/buffer_edit.lua` | new | `nvim_buf_set_text` |
| Drill-in submission orchestration | `lua/parley/chat_respond.lua` | modified | chat buffer and exchange targeting |

- **`buffer_edit.apply_text_edits(buf, start_row0, source_text, edits)`** — maps
  original byte coordinates to row/column pairs once, then applies edits in
  descending order. It rejects unsorted/overlapping/out-of-range plans before
  mutating and never reads or writes outside the supplied source slice.
  - **Injected into:** both drill-in submission paths as their sole marker and
    anchor mutation shell (`ARCH-PURE`).
- **Drill-in submission orchestration** — creates extmark position handles for
  destination boundaries before marker edits, applies the shared plan, then
  either appends blocks within the final unanswered user turn or inserts a new
  prefixed turn after a past exchange. It never calls `replace_all_lines`.
  - **Future extensions:** destination placement stays path-specific rather than
    leaking into marker transformation.

## Chunk 1: Pure edit plan and bounded adapter

### Task 1: Expose and normalize the drill-in edit plan

**Files:**
- Modify: `lua/parley/drill_in.lua`
- Modify: `tests/unit/drill_in_spec.lua`

- [ ] **Step 1: Write RED tests for original-coordinate plans**

Add named cases asserting explicit markers, inferred bracket insertions,
multiline markers, multiple markers, and nearby unquoted markers produce sorted,
non-overlapping edits whose application equals the existing `new_text`. Pin
interacting inferred-anchor behavior: marker bytes never appear inside an
anchor bracket and neither ready marker is lost.

- [ ] **Step 2: Run the exact unit spec and verify RED**

Run:
`nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/drill_in_spec.lua" -c "qa!"`

Expected: FAIL because `gather_edit_plan` is absent.

- [ ] **Step 3: Implement the minimum normalized planner**

Promote the existing local edit collection out of `gather_and_strip`. Validate
and normalize candidates before returning them; retain `splice` as the single
compatibility renderer. Make `gather_and_strip` delegate and return its existing
two values unchanged.

- [ ] **Step 4: Re-run the exact unit spec and verify GREEN**

Expected: all existing and new drill-in assertions pass without expectation
changes.

### Task 2: Add the bounded Neovim edit adapter

**Files:**
- Modify: `lua/parley/buffer_edit.lua`
- Modify: `tests/unit/buffer_edit_spec.lua`

- [ ] **Step 1: Write RED adapter tests**

Using a real scratch buffer, assert byte edits map across multibyte/multiline
text, apply bottom-to-top, touch only the requested slice, and reject malformed
or overlapping plans before the first mutation.

- [ ] **Step 2: Run the exact adapter spec and verify RED**

Run:
`nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/buffer_edit_spec.lua" -c "qa!"`

Expected: FAIL because `apply_text_edits` is absent.

- [ ] **Step 3: Implement `apply_text_edits`**

Convert every byte boundary against `source_text` before mutation, validate the
plan, then issue descending `nvim_buf_set_text` calls. Return the net line delta
for destination bookkeeping while leaving coordinate ownership with extmark
handles.

- [ ] **Step 4: Re-run the exact adapter spec and verify GREEN**

Expected: adapter tests and all existing buffer-edit tests pass.

- [ ] **Step 5: Commit Chunk 1**

Commit the pure plan and thin adapter with a `#194:` subject and model co-author
trailer.

## Chunk 2: Submission integration and fold regression

### Task 3: Replace both whole-buffer submission rewrites

**Files:**
- Modify: `lua/parley/chat_respond.lua`
- Modify: `tests/integration/chat_respond_spec.lua`

- [ ] **Step 1: Write RED production integration tests**

For end submission, start with a closed one-line summary fold and a separate
user fold, submit a ready marker in the final unanswered question, and assert
both folds retain logical text/closed state and no fold covers unchanged
question text. For branch submission, place a user fold below the insertion and
assert it shifts only by the inserted line delta while retaining logical text
and closed state. Spy on `replace_all_lines` and fail if either path calls it.
Keep the existing serialized-buffer and dispatched-payload assertions unchanged.

- [ ] **Step 2: Run the exact integration spec and verify RED**

Run:
`nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/chat_respond_spec.lua" -c "qa!"`

Expected: the new tests fail because both paths call `replace_all_lines`, the
summary fold disappears, or a fold migrates into question text.

- [ ] **Step 3: Implement bounded end submission**

Plan over the full joined chat, create a handle for the final unanswered turn's
tail, apply marker/anchor edits, trim only trailing blank rows, and insert the
formatted blocks at the resolved tail. Re-read/reparse exactly as today.

- [ ] **Step 4: Implement bounded branch submission**

Plan over the selected exchange slice, create a handle immediately after that
exchange, apply the slice-relative edits at `exch_start - 1`, then insert the
blank separator, user prefix, and formatted blocks at the resolved boundary.
Preserve `new_turn_end`, cursor retargeting, and stale-later-exchange exclusion.

- [ ] **Step 5: Re-run unit and integration specs and verify GREEN**

Run the exact `drill_in_spec.lua`, `buffer_edit_spec.lua`, and
`chat_respond_spec.lua` commands from prior steps.

Expected: all pass; old serialization/payload assertions require no changes.

### Task 4: Documentation and repository gates

**Files:**
- Modify: `atlas/chat/lifecycle.md`
- Modify: `atlas/traceability.yaml`
- Modify: `workshop/issues/000194-preserve-folds-during-inline-comment-submission.md`
- Modify: `workshop/plans/000194-preserve-folds-during-inline-comment-submission-plan.md`

- [ ] **Step 1: Update atlas and traceability**

Document drill-in submission as bounded marker/anchor edits plus path-specific
destination insertion. Map planner, adapter, unit specs, and integration fold
regressions.

- [ ] **Step 2: Run mapped verification**

Run: `make test-spec SPEC=chat/lifecycle`

Expected: every mapped file passes.

- [ ] **Step 3: Run full verification**

Run: `make test`

Run: `make test-changed`

Run: `git diff --check`

Expected: all exit 0 with no lint warnings or test failures.

- [ ] **Step 4: Reconcile tracker evidence**

Tick issue/plan checks and append exact RED/GREEN/full-suite evidence to the
issue Log.

- [ ] **Step 5: Commit Chunk 2**

Commit integration, regressions, docs, and tracker evidence with a `#194:`
subject and model co-author trailer.

## Revisions

### 2026-07-17 — initial implementation plan

Translated the approved, fresh-reviewed spec into two TDD chunks: expose the
existing pure candidate edits as a normalized plan, apply them through one
bounded Neovim adapter, then preserve the distinct end/branch destination
semantics while proving real manual-fold stability.
