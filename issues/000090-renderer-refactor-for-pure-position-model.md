---
id: 000090
status: open
deps: [000081]
created: 2026-04-09
---

# Renderer refactor — pure position model for chat buffer

## Summary

Extract a pure data model + pure render layer + single mutation entry point for the chat buffer, replacing the ad-hoc line-offset arithmetic that currently lives inside `lua/parley/chat_respond.lua::M.respond`. Unblocks #81 M2 Task 2.7 and everything downstream (M3 edit_file, M4 iteration cap + synthetic results, M5 write_file, M6 cancellation UI).

## Problem

`chat_respond.M.respond` computes buffer line positions imperatively through a chain of dependent variables:

```
response_line      ← helpers.last_content_line(buf)
                     OR answer.line_end (recursion branch)
                     OR question.line_end - 1 (new-question branch)
response_block_lines ← {"", "🤖: [Agent]", "", progress} (normal)
                     OR {""} (recursion)
raw_request_offset ← 0 or N (after inserting raw-request fence)
progress_line      ← response_line + 3 + raw_request_offset (normal)
                     OR response_line + 1 + raw_request_offset (recursion)
response_start_line ← spinner_active and (progress_line + 2) or progress_line
```

Each new scenario stacks another branch. The `+3` vs `+1` magic numbers are the direct cause of two M2 Task 2.7 bugs (progress_line offset mismatch, stuck-spinner cleanup failure), and a third bug — Anthropic rejecting the recursive call as "assistant message prefill" — is strongly suspected to come from the same mutation path corrupting buffer state.

As #81 M3/M4/M5/M6 add more states (multi-round tool use, iteration-cap synthetic `📎:`, cancellation mid-tool-call, error rendering, fold/expand, streaming-into-existing-sections), every new state multiplies the number of offset branches. The code becomes non-deterministic to reason about and increasingly hostile to test.

## Why now

- Blocks #81 M2 Task 2.7 manual verification (current Anthropic rejection bug)
- Blocks #81 M2 Task 2.11 code review gate
- Blocks all of #81 M3–M6 (each tool-use feature stacks more renderer branches)
- Cheaper to refactor now while the M2 surface is small than after M3–M6 have piled more branches on top
- Golden-snapshot test catalog (part of this refactor) is also the missing piece for regression detection in #81's remaining milestones

## Out of scope

- `chat_parser.lua` — already clean, only gains precise `lines = [start,end]` per section
- `providers.lua` payload shape — clean
- `tool_loop.lua` driver logic — clean, only its one line-offset call site (`_append_block_to_buffer`) gets rewritten on top of the new mutation layer
- `_build_messages` + `_emit_content_blocks_as_messages` — clean
- `tools/*` — untouched
- UI features (fold, highlight, lualine indicator refinements) — follow-ups
- Any #81 M3–M6 feature work — blocked on this landing

## Spec

Full design at [`docs/plans/000090-renderer-refactor.md`](../docs/plans/000090-renderer-refactor.md). Brainstormed and approved 2026-04-09.

**Three new modules + one extension:**
1. **`chat_parser.lua` extension** — every section in `answer.sections` (renamed from `content_blocks`) gains `line_start/line_end` line spans recorded as the parser walks. Backward-compat alias kept.
2. **`lua/parley/render_buffer.lua` (NEW, pure)** — `render_section`, `render_exchange`, `positions`, plus standalone helpers (`agent_header_lines`, `raw_request_fence_lines`). No buffer access, no nvim API beyond `vim.json/vim.tbl_*`. Goes in `PURE_FILES` arch list.
3. **`lua/parley/buffer_edit.lua` (NEW)** — single entry point for all `nvim_buf_set_lines`/`nvim_buf_set_text` calls in the plugin. Returns opaque `PosHandle` (extmark-backed) so callers chain operations without ever computing line offsets.
4. **`tests/arch/arch_helper.lua` (NEW)** — architectural fitness functions. `assert_pattern_scoping({pattern, scope, allow_only_in, rationale, ignore_comments})`. Initial 3 rules: `nvim_buf_set_lines` only in `buffer_edit.lua`; `nvim_buf_set_text` only in `buffer_edit.lua`; pure files contain no `vim.api/cmd/schedule/defer_fn`.

**Plus the test harness** (`scripts/test-anthropic-interaction.sh` + `scripts/parley_harness.lua`) — one-shot payload sender that takes a parley transcript file (`💬/🤖/🔧/📎` shape), runs it through parser → build_messages → prepare_payload → curl Anthropic, prints status + body. Dry-run mode skips curl and prints just the JSON payload (CI-safe). Seven fixture transcripts in `tests/fixtures/transcripts/` doubling as round-trip golden snapshots for `render_buffer.render_exchange`.

**Migration**: ~25 commits across 5 phases. Phase 0 = infrastructure (arch helper, harness, fixtures, golden payloads). Phase 1 = pure layers (chat_parser extension, render_buffer, buffer_edit). Phase 2 = migrate `chat_respond.lua` mutation sites in 7 logical groups. Phase 3 = migrate `tool_loop.lua` and `dispatcher.create_handler` streaming, then tighten arch test #1 to `allow_only_in = { "lua/parley/buffer_edit.lua" }`. Phase 4 = re-validate #81 M2.

**Definition of done**: `grep -rn "nvim_buf_set_lines\|nvim_buf_set_text" lua/parley/` returns ONLY `lua/parley/buffer_edit.lua`. `chat_respond.lua` ≥300 lines lighter. All ~406 tests green (~321 existing + ~85 new). Manual verification: vanilla chat byte-identical, ClaudeAgentTools round-trip clean.

## Plan

_TBD — will be filled out after brainstorm, in the plan phase._

## Log

- **2026-04-09 — filed**. Problem + scope + why-now captured above. Next: fresh session, enter brainstorming mode, write `## Spec`, then write `docs/plans/000090-renderer-refactor.md`, then execute.
- **2026-04-09 — brainstormed + planned + executed (Phases 0–3)**. User chose to address #90 in the same session as #81 M2 deferral.
  - Brainstormed 9 sections with section-by-section approval (architecture, data model, buffer_edit API, render_buffer API, arch helper, harness, test strategy, migration order, risks).
  - Plan written to `docs/plans/000090-renderer-refactor.md` with 30 TDD tasks across 5 chunks.
  - Executed Phases 0–3 (24 of 30 tasks):
    - **Chunk 0 (Phase 0)**: arch_helper + arch baseline tests + harness + 7 fixtures + 7 goldens + round-trip guard. 15 new tests. Commits: b18ed16, 4a13bc2, cb044e1, f8b9e8a, b18d8d8, c05e176, 95eacea.
    - **Chunk 1 (Phase 1)**: chat_parser line spans + helpers, render_buffer.lua (pure render), buffer_edit.lua (mutation entry point). 32 new tests. Commits: 8f828f8, 074f7b0, 1059604, 860146e, f31a774, ac1f6ff, 1ef84e9.
    - **Chunk 2 (Phase 2)**: chat_respond.lua mutations migrated to buffer_edit (10 sites). Commits: b3ea1a3, 7f0c956.
    - **Chunk 3 (Phase 3)**: tool_loop and dispatcher streaming migrated. Final arch state: `nvim_buf_set_lines` only in `buffer_edit.lua` (within the chat-rendering pipeline). Commits: aae15c8, ff7f51d.
  - **Task 2.8 deferred** (dead-variable deletion of `response_line / progress_line / raw_request_offset` in chat_respond.lua): would require `dispatcher.create_handler` to accept a PosHandle instead of a raw line number, which is a separate larger refactor of the streaming protocol. The minimum-change form of #90 routes the existing offset arithmetic THROUGH buffer_edit without converting it to PosHandle. The intermittent Anthropic rejection bug may or may not be fixed by what's landed; the next manual test (Chunk 4) will tell.
  - **Picker/UI helpers deferred**: chat_finder, init, vision, issues, float_picker, config, system_prompt_picker, highlighter all still use raw `nvim_buf_set_lines`. Migrating them is desirable for consistency but YAGNI for #90's renderer scope. They are listed in the arch test allow list with the explicit "deferred follow-up" comment.
  - All ~406 tests green except the pre-existing unrelated `export_allocation_report` failure.
  - **Chunk 4 (Phase 4 — re-validation)** is up next: full make test green ✓, manual nvim verification (vanilla chat + ClaudeAgentTools tool round-trip), live Anthropic harness against `one-round-tool-use.md`, then resume #81 M2 Task 2.7.

- **2026-04-09 — Manual testing + diagnosis + exchange_model**. Multiple rounds of manual testing exposed a deeper architectural issue than the initial scope anticipated:

  **Root cause identified**: `chat_respond.M.respond` computes `response_start_line` as `response_line + N` using absolute line offsets. When the buffer has a placeholder `💬:` (parley's standard convention for the next-question prompt), `response_start_line` lands ON the placeholder. The streaming handler then OVERWRITES the placeholder with Claude's response text. Subsequently, `tool_loop` appends `🔧:/📎:` blocks at the end of the buffer (past the destroyed placeholder), which the parser sees as belonging to a DIFFERENT exchange. The recursive call then sends only the original question (without tool_result), and Claude re-requests the same file.

  **What was built and is solid (keep all of this)**:
  - `lua/parley/exchange_model.lua` (pure, 13 tests) — size-based positional model. Computes "section K in exchange J → buffer line N" from sizes, never from stored absolute positions. answer_append_pos() is always bounded inside the active exchange.
  - `tests/arch/arch_helper.lua` + `tests/arch/buffer_mutation_spec.lua` — architectural fitness functions
  - `scripts/parley_harness.lua` + `scripts/test-anthropic-interaction.sh` — offline payload tester
  - 7 fixture transcripts + 7 golden payloads + round-trip tests
  - `lua/parley/render_buffer.lua` — pure render layer
  - `lua/parley/buffer_edit.lua` — single mutation entry point
  - `chat_parser.lua` line span extension + helpers
  - `M.dump_exchanges()` debug helper — invoke `:lua require('parley').dump_exchanges()`
  - Trace infrastructure in chat_respond/dispatcher (temporary, remove after fix)

  **What needs to be done in the NEXT session**:
  1. **Rewrite the ~100-line insert block in `chat_respond.M.respond`** (roughly lines 950–1080). Remove ALL of: `response_line`, `response_block_lines`, `progress_line`, `response_start_line`, `raw_request_offset`, `in_tool_loop_recursion` branching. Replace with exchange_model calls. ONE code path for ALL agents (not two paths for tool vs non-tool).
  2. **Change `dispatcher.create_handler` signature** to receive the streaming target position from the exchange_model (not compute it independently via extmarks).
  3. **Handle the spinner** as part of the model (or skip it for tool-use agents — they're fast enough).
  4. **Handle `raw_request_fence`** insert via the model.
  5. **Remove all trace logging** once the fix is verified.
  6. **Run manual test**: fresh chat, ClaudeAgentTools, "read ./ARCH.md and tell me what it is about" → expect clean 🔧:/📎: blocks inside the answer, Claude's text response streaming below them, no buffer corruption.

  **Key lesson**: having TWO code paths (legacy + model-based) in the same function is WORSE than having just one (even if wrong). The paths interact through shared variables and produce unpredictable buffer states. The next session must commit to ONE path.

  **How to start the next session**: say "work on issues/90" — the issue file, exchange_model, and all infrastructure are committed and ready. The rewrite is surgical: one function in one file, backed by the existing test suite + arch tests + golden payloads as regression guards.
