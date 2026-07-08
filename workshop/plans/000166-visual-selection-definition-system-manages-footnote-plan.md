# Durable Definition Footnotes Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist visual-selection definitions as managed markdown footnotes while keeping the durable footnote section out of LLM submissions.

**Architecture:** Keep document transforms in `lua/parley/define.lua` as pure helpers (ARCH-PURE), put buffer writes behind `lua/parley/buffer_edit.lua`, and keep `render_definition` as the thin IO shell that stitches lookup results to the pure transform. `chat_respond.build_messages` receives already-parsed exchanges, so it will scrub only the managed final footnote footer from question/answer strings before adding messages (ARCH-PURPOSE).

**Tech Stack:** Lua, Neovim buffer APIs via `buffer_edit`, Plenary/Busted tests, existing Parley skill invocation and diagnostic rendering.

---

## Core Concepts

### Pure Entities

| Name | Kind | Lives in | Status |
|------|------|----------|--------|
| `DefinitionFootnote` | PURE | `lua/parley/define.lua` | new |
| `DefinitionFootnoteFooter` | PURE | `lua/parley/define.lua` | new |
| `DefinitionSubmissionScrubber` | PURE | `lua/parley/define.lua` | new |

- **DefinitionFootnote** — a durable markdown footnote pair: inline reference `[^definition]` plus footer line `[^definition]: ...`.
  - **Relationships:** N:1 with a chat file; many selected terms may create footnotes in one managed footer.
  - **DRY rationale:** One source handles slugging, reference text, and footer line formatting instead of duplicating string construction in render and tests.
  - **Future extensions:** Conflict handling can widen from numeric suffixes to stable IDs or renames without changing render callers.

- **DefinitionFootnoteFooter** — pure transform that inserts or updates a managed footnote section after the transcript separator.
  - **Relationships:** Owns the footer section lines; consumed by `buffer_edit.replace_all_lines`.
  - **DRY rationale:** Keeps footer location, divider insertion, replacement policy, and footer-boundary recognition together.
  - **Future extensions:** Can support multiple footer groups or metadata comments if the managed section needs migration.

- **DefinitionSubmissionScrubber** — pure helper that removes the managed footnote footer from strings before they are sent to the LLM.
  - **Relationships:** Consumed by `chat_respond.build_messages`; separate from parser so parse positions remain truthful to the buffer.
  - **DRY rationale:** The same footer boundary rule protects user and assistant content.
  - **Future extensions:** If other local-only transcript sections appear, this helper can become a generic local-footer scrubber.

### Integration Points

| Name | Kind | Lives in | Status | Wraps |
|------|------|----------|--------|-------|
| `render_definition` | INTEGRATION | `lua/parley/init.lua` | modified | Neovim diagnostics/projection |
| `DefinitionBufferEdit` | INTEGRATION | `lua/parley/buffer_edit.lua` | modified | `nvim_buf_set_lines` |
| `chat_respond.build_messages` | INTEGRATION | `lua/parley/chat_respond.lua` | modified | LLM payload construction |

- **render_definition** — after `emit_definition`, verifies the selection, rewrites the selected text to include a footnote reference, stores/updates the managed footer, and attaches the current-line diagnostic from the durable footnote text.
  - **Injected into:** Existing `skill_invoke.invoke` `on_done` callback.
  - **Future extensions:** On-cursor rehydration can later read existing footnotes without a new LLM call.

- **DefinitionBufferEdit** — chat-buffer mutation entry point for full-buffer definition-footnote rewrites.
  - **Injected into:** `render_definition`.
  - **Future extensions:** Can narrow to range edits if the footer transform later returns minimal edit hunks.

- **chat_respond.build_messages** — strips managed definition footnotes from preserved and summarized exchange content.
  - **Injected into:** Existing chat response pipeline.
  - **Future extensions:** Live-model recursion path can consume the same scrubber if footnotes ever appear during tool-loop recursion.

---

## Chunk 1: Pure Footnote Transforms

**Files:**
- Modify: `lua/parley/define.lua`
- Test: `tests/unit/define_spec.lua`

- [x] **Step 1: Write failing tests for slug/reference/footer transform**

Add tests showing:
- `footnote_id("Amazon Standard Identification Number")` returns `amazon-standard-identification-number`.
- `apply_definition_footnote` changes `here is ASIN in context` to `here is ASIN[^asin] in context`.
- It appends a managed footer:

```markdown
---

[^asin]: Amazon Standard Identification Number.
```

- Reapplying the same id updates/replaces the footer line rather than duplicating it.

Run: `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`

Expected: FAIL because the helpers do not exist yet.

- [x] **Step 2: Implement pure helpers minimally**

In `lua/parley/define.lua`, add:
- `footnote_id(term)`
- `format_footnote_line(id, definition)`
- `apply_definition_footnote(lines, l1, c1, l2, c2, term, definition)`
- `strip_definition_footnote_footer(text)`

Keep all helpers deterministic and free of Neovim API calls. Preserve the existing selection text; only append `[^id]` after the selected span. For this issue, single-line selections are the required path; multi-line can return a conservative full-line transform using the existing selection slice if straightforward, but do not add a broad markdown engine.

The managed footer predicate is exact and shared by insertion/update and stripping:
- scan for the last standalone line whose trimmed text is exactly `---`;
- treat it as the managed footer only if every following nonblank line matches `^%[%^[^%]]+%]:`;
- otherwise no managed footer exists and the content must remain untouched.

Add negative tests that prove ordinary horizontal rules are preserved when the trailing block contains non-footnote prose.

- [x] **Step 3: Verify pure tests pass**

Run: `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`

Expected: PASS.

---

## Chunk 2: Render Visual Definitions as Durable Footnotes

**Files:**
- Modify: `lua/parley/init.lua`
- Modify: `lua/parley/buffer_edit.lua`
- Test: `tests/integration/define_spec.lua`

- [x] **Step 1: Update the integration test to expect footnotes**

Replace the bracket assertion in `define_visual + render_definition`:
- selected line becomes `here is ASIN[^asin] in context`
- footer exists at end of file with `[^asin]: Amazon Standard Identification Number.`
- diagnostic message still includes `ASIN`
- diagnostic range anchors to selected text plus footnote reference as appropriate for the current render.

Run: `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`

Expected: FAIL because render still writes `[ASIN]`.

- [x] **Step 2: Add buffer edit wrapper**

In `lua/parley/buffer_edit.lua`, add a named wrapper such as `replace_all_lines_for_definition(buf, lines)` delegating to `replace_all_lines`. This keeps call sites semantically clear and avoids adding new direct `nvim_buf_set_lines` callers.

- [x] **Step 3: Wire `render_definition` to the pure transform**

In `lua/parley/init.lua`:
- Replace `define.bracket_edit` with `define.apply_definition_footnote`.
- Use `buffer_edit.replace_all_lines_for_definition` for the rewrite.
- Keep `projection.record_empty_for`, `projection.record`, and `ensure_watch` so undo/redo remains coherent.
- Set the diagnostic text from the durable footnote definition. The diagnostic itself remains ephemeral, but its source text is now persisted.

- [x] **Step 4: Verify focused integration**

Run:
- `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`
- `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`

Expected: PASS.

---

## Chunk 3: Exclude Managed Footnotes from LLM Submission

**Files:**
- Modify: `lua/parley/chat_respond.lua`
- Test: `tests/unit/build_messages_spec.lua`

- [x] **Step 1: Write failing build-message test**

Add a test where preserved question/answer content contains:

```markdown
answer text

---

[^asin]: Amazon Standard Identification Number.
```

Assert built messages contain `answer text` but not `[^asin]:`.

Also add tests proving:
- `answer\n\n---\n\nnot a footnote` is not stripped.
- A message with an earlier horizontal rule and a final managed footnote block keeps the earlier horizontal rule content and strips only the final managed block.
- Both user and assistant content pass through the same `strip_definition_footnote_footer` helper.

Run: `nvim --headless -c "PlenaryBustedFile tests/unit/build_messages_spec.lua"`

Expected: FAIL because footer text is currently submitted as content.

- [x] **Step 2: Apply the scrubber at message construction boundaries**

In `chat_respond.build_messages`, call `define.strip_definition_footnote_footer` before inserting string question/answer/summary content into `messages`. Keep content-block arrays unchanged unless they contain text blocks created from parsed answer strings; for the parse path, scrub flat string content first.

- [x] **Step 3: Verify build-message test**

Run: `nvim --headless -c "PlenaryBustedFile tests/unit/build_messages_spec.lua"`

Expected: PASS.

- [x] **Step 4: Cover the live model path**

Add a `build_messages_from_model` regression using a real exchange model and
buffer lines, proving the recursive/live path strips the same managed footer
from question and answer text.

---

## Chunk 4: Docs and Final Verification

**Files:**
- Modify: `atlas/chat/inline_define.md`
- Modify: `workshop/issues/000166-visual-selection-definition-system-manages-footnote.md`

- [x] **Step 1: Update atlas**

Update `atlas/chat/inline_define.md` to describe durable footnotes, managed footer, and LLM-submission exclusion.

- [x] **Step 2: Mark issue checklist and log**

Tick issue plan items and log red/green evidence.

- [x] **Step 3: Full verification**

Run:
- `git diff --check -- lua/parley/define.lua lua/parley/init.lua lua/parley/buffer_edit.lua lua/parley/chat_respond.lua tests/unit/define_spec.lua tests/integration/define_spec.lua tests/unit/build_messages_spec.lua atlas/chat/inline_define.md workshop/issues/000166-visual-selection-definition-system-manages-footnote.md`
- `make test`

Expected: all pass.

Actual: focused define, integration define, and build-message specs passed;
`git diff --check` passed; final `make test` passed on rerun with 0 lint
warnings/errors and all unit, integration, and arch tests green. The repeated
rerun was needed because `tests/unit/tools_builtin_find_spec.lua` flaked in the
parallel full-suite run but passed each time it was run in isolation.

## Revisions

### 2026-07-08 — close-review redefinition edge

Reason: Boundary review found that re-defining an already-footnoted term would
append a duplicate inline `[^id]` reference even though the spec requires
re-definitions to update the corresponding footnote.

Delta: `apply_definition_footnote` must detect an immediate existing reference
after the selected span and skip reinserting it while still updating the managed
footer; unit and integration regressions cover the duplicate-reference case.
The Core Concepts tables now include explicit `Kind` columns for the SDLC review
contract.
