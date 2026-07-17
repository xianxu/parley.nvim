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
  in original 1-based half-open byte coordinates.
  - **Relationships:** one submission source owns 0:N `DrillInEdit` values and
    0:N formatted comment blocks. `gather_and_strip` delegates to it 1:1 so
    marker grammar and serialization remain single-sourced (`ARCH-DRY`).
  - **Conflict contract:** marker replacement/removal has precedence over
    inferred decoration. Drop an inferred bracket pair if its source span
    intersects any ready-marker span. Among intersecting inferred spans, the
    earliest ready marker in document order owns decoration and later markers
    retain their gathered quote block but receive no in-place brackets. Coalesce
    all same-boundary insertions into one replacement before returning. Thus the
    result is sorted ascending, non-overlapping, and contains no hidden ordering
    dependency. Existing compatibility output remains byte-identical; new
    nearby-marker cases pin this previously unspecified edge.
  - **Future extensions:** another bounded consumer can use the same edits
    without reconstructing a whole document.
- **`DrillInEdit`** — `{ start_byte, end_byte, replacement }` with
  `1 <= start_byte <= end_byte <= #text + 1`; it replaces
  `[start_byte, end_byte)`, and equality represents insertion.
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
- **Drill-in submission orchestration** — applies the shared plan, then either
  appends blocks at EOF within the final unanswered user turn or uses an extmark
  boundary to insert a new prefixed turn after a past exchange. It never calls
  `replace_all_lines`.
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
interacting inferred-anchor behavior with literal input → normalized edit list →
output fixtures: marker edits win; the first intersecting inferred span owns its
bracket pair; later intersecting inferred spans are undecorated; neither ready
marker nor gathered block is lost.

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
or overlapping plans before the first mutation. Cover insertion at byte 1 and
`#source_text + 1`, replacements adjacent to both sides of `\n`, multiline
replacement, multibyte text before each endpoint, nonzero `start_row0`, empty
source, and a source slice ending before later untouched buffer text.

- [ ] **Step 2: Run the exact adapter spec and verify RED**

Run:
`nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/buffer_edit_spec.lua" -c "qa!"`

Expected: FAIL because `apply_text_edits` is absent.

- [ ] **Step 3: Implement `apply_text_edits`**

Convert every half-open byte boundary against `source_text` before mutation,
validate the entire plan before the first write, then issue descending
`nvim_buf_set_text` calls. Return the net line delta
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

In a real window set `foldmethod=manual`, `foldenable=true`, `foldminlines=0`,
and `foldcolumn=1`; create and close a one-line summary fold plus a separate user
fold before submission. For end submission, assert exact covered text and
`foldclosed`/`foldclosedend` survive, `screenstring()` after `redraw!` shows the
summary fold-column marker, and every unchanged question/answer line reports
`foldclosed(line) == -1`. For branch submission, place a user fold below the
insertion and assert its logical text/closed state survives while numeric rows
shift by the measured insertion delta. Spy on `replace_all_lines` and fail if
either path calls it. Keep existing serialized-buffer and dispatched-payload
assertions unchanged.

- [ ] **Step 2: Run the exact integration spec and verify RED**

Run:
`nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/chat_respond_spec.lua" -c "qa!"`

Expected: the new tests fail because both paths call `replace_all_lines`, the
summary fold disappears, or a fold migrates into question text.

- [ ] **Step 3: Implement bounded end submission**

Plan over the full joined chat and apply marker/anchor edits. Because the
destination is EOF, use no extmark: after edits, delete only the maximal
trailing-empty-line suffix, then append exactly one separator when the remaining
buffer is nonempty followed by `format_blocks(blocks)`. Test no trailing blank,
one/multiple trailing blanks, and a marker on the final line. Re-read/reparse
exactly as today.

- [ ] **Step 4: Implement bounded branch submission**

Plan over the selected exchange slice. For a middle branch, create the position
handle at 0-based row `exch_end`, the insertion boundary before
`lines[exch_end + 1]`; after slice-relative edits at `exch_start - 1`, resolve
the handle and insert `{ "", user_prefix, unpack(block_lines) }`. For a branch
after the final exchange, use the post-edit buffer line count as the EOF
boundary rather than anchoring a nonexistent row. Derive `new_turn_end` from the
resolved 0-based insertion row plus inserted-line count. Test middle and final-
exchange branches and preserve cursor retargeting plus stale-later-exchange
exclusion.

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

### 2026-07-17 — plan-review coordinate and fold-proof correction

Changed edit coordinates to 1-based half-open spans, coalesced same-boundary
insertions, and defined marker/inferred-anchor precedence. Made end and branch
destination rows exact (including EOF), expanded adapter boundary cases, and
required a rendered fold-column assertion in addition to logical range checks.
Revised the estimate to 2.5h after correcting its arithmetic and accounting for
the newly explicit edge work.
