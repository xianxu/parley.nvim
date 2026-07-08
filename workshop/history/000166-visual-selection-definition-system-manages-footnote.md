---
id: 000166
status: done
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 2.29
started: 2026-07-08T08:45:50-07:00
actual_hours: 0.39
---

# move visual selection definition system to be based on durable footnote

Right now, the definition is inserted as diagnosis, and convert the text to [anchor text]. Persisting the definition is useful, and let's do that. It works roughly like the following:

1. when a `definition` is selected and queried, we do the same LLM call, get back definition. 
2. then we insert a footnote for that definition: [^definition]: .... 
3. at end of chat transcript, we manage a section of footnote. footnote is separated from main chat with a divider line ---. 
4. then we stop converting definition to anchor text [definition] as we have definition [^definition]. 
5. diagnosis should pull definition stored in footnote directly. 
6. footnote is not submitted to LLM.

## Problem

Inline visual definitions currently write only an ephemeral diagnostic and a
minimal `[term]` text anchor. The definition itself disappears from the chat
file, so the lookup cannot be preserved or reloaded as durable transcript state.
Persisting the definition in ordinary markdown footnotes solves that, but the
managed footnote block must not become part of the next LLM prompt.

## Spec

Visual-selecting a term and invoking definition keeps the existing LLM lookup
and diagnostic behavior, but the durable text edit changes:

- The selected text remains readable in place and gains a markdown footnote
  reference: `term[^term]`.
- The definition is stored in a managed footnote footer at the end of the chat
  transcript, separated from the main chat by `---`.
- The managed footer is recognized only as a final block: the last standalone
  `---` line in the content, followed only by blank lines and markdown footnote
  definitions (`[^id]: text`). Any ordinary horizontal rule, or any trailing
  block that mixes non-footnote prose after `---`, stays part of chat content.
- Re-defining an existing term updates the corresponding managed footnote line
  instead of duplicating it.
- The diagnostic text is still shown inline, but it is derived from the stored
  footnote definition rather than being the only copy of the definition.
- The managed footnote footer is stripped from message content before payload
  construction so it is not submitted to the LLM.

ARCH-PURE: footnote slugging, footer insertion/update, and footer stripping live
in `lua/parley/define.lua` as pure helpers with unit coverage. ARCH-DRY: the same
footer boundary helper protects both user and assistant message content.
ARCH-PURPOSE: this is not complete unless both persistence and LLM-exclusion are
implemented.

## Done when

- Defining `ASIN` rewrites the line to include `ASIN[^asin]` and appends or
  updates `[^asin]: ...` in a footer after a `---` divider.
- Existing no-definition and empty-selection safeguards remain intact.
- Built LLM messages exclude only the managed final footnote footer; ordinary
  `---` content remains submitted.
- Focused define/build-message tests and the full suite pass.

## Estimate

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.20 impl=0.00
item: lua-neovim design=0.60 impl=1.00
item: atlas-docs design=0.00 impl=0.05
item: milestone-review design=0.00 impl=0.20
design-buffer: 0.30
total: 2.29
```

## Plan

- [x] Implement pure definition-footnote helpers in `lua/parley/define.lua`.
- [x] Render visual definitions as durable markdown footnotes while preserving
      diagnostics and undo/redo projection.
- [x] Strip managed definition footnotes from LLM message content.
- [x] Update inline-define atlas docs and run focused/full verification.

## Log

### 2026-07-08
- 2026-07-08: closed — Implemented durable visual-definition footnotes, LLM footer stripping, and close-review fixes. Verified with PlenaryBustedFile tests/unit/define_spec.lua (22 pass), tests/integration/define_spec.lua (15 pass), tests/unit/build_messages_spec.lua (56 pass), git diff --check on #166 files, isolated tests/unit/tools_builtin_find_spec.lua after transient full-suite flake, and final make test passing with 0 lint warnings/errors plus all unit, integration, and arch tests green.; review verdict: SHIP
- Claimed issue, wrote durable plan, and passed `sdlc change-code` after refining
  the managed-footer predicate to avoid naive `---` stripping.
- TDD red/green:
  `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"` first
  failed on missing footnote helpers, then passed after adding pure helpers.
- TDD red/green:
  `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`
  first failed on `[ASIN]` output, then passed after rendering durable footnotes.
- TDD red/green:
  `nvim --headless -c "PlenaryBustedFile tests/unit/build_messages_spec.lua"`
  first failed with `[^asin]:` leaking into messages, then passed after wiring
  `define.strip_definition_footnote_footer` through message construction.
- Added live-model coverage for `build_messages_from_model` so recursive
  tool-loop payload construction also strips managed definition footers.
- Verification:
  `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"` passed
  (21 tests);
  `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`
  passed (14 tests);
  `nvim --headless -c "PlenaryBustedFile tests/unit/build_messages_spec.lua"`
  passed (56 tests);
  `git diff --check -- lua/parley/define.lua lua/parley/init.lua lua/parley/buffer_edit.lua lua/parley/chat_respond.lua tests/unit/define_spec.lua tests/integration/define_spec.lua tests/unit/build_messages_spec.lua atlas/chat/inline_define.md workshop/issues/000166-visual-selection-definition-system-manages-footnote.md workshop/plans/000166-visual-selection-definition-system-manages-footnote-plan.md`
  passed.
- Full verification: first `make test` run hit an unrelated transient failure
  in `tests/unit/tools_builtin_find_spec.lua`; the spec passed in isolation, and
  a second `make test` passed with 0 lint warnings/errors and all unit,
  integration, and arch tests green. After replacing `define.lua`'s remaining
  Neovim table helpers with Lua-only helpers, the focused specs still passed;
  `make test` hit the same transient `tools_builtin_find_spec.lua` flake once,
  passed in isolation again, then the final `make test` passed with 0 lint
  warnings/errors and all unit, integration, and arch tests green.
- Close review returned REWORK: re-defining an already-footnoted term could
  duplicate the inline `[^id]` reference, and README still described the old
  non-durable behavior. Fixed both, added pure and integration regressions, and
  revised the durable plan with the redefinition edge.
