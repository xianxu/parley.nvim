---
id: 000419
status: open
deps: []
github_issue:
created: 2026-10-22
updated: 2026-10-22
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'a019415ce83fb5acae8c51b830ac683b5fc535a2' # card fields mirrored from issue-cards; edit via sdlc
---

# unified-editorial-interface: typeahead for the mode keys and heading comments; conceal comments as badges

## Problem

## Spec

**Settled with the operator (10-22, design chat in brain `session.side/2026-10/2026-10-22-01-editorial-modes.md`):**
- **Uniform names:** `collaboration-mode` (where an answer goes: discussion / collaboration / chat),
  `presentation-mode` (how edits are shown: highlight / direct / propose), `processing-mode` (how an edit is made:
  the review modes in `ariadne/construct/local/universal-review/modes/`: copy-editing, developmental, fact-check,
  free-form, line-editing, proofreading; unique prefixes allowed). The old keys `presentation` and
  `process-instruction` stay readable as aliases. `process-instruction`'s free text splits out into
  `processing-instruction`.
- **Per section:** all three can be set for one section by an HTML comment directly under its heading:
  `<!-- collaboration-mode: chat; processing-mode: copy-editing -->`. Couch protects that line as operator-owned;
  parley conceals it as a badge.
- **Frontmatter:** each key is one value covering the whole document; the per-section map form
  (`collaboration-mode: {chat: ["Operator instructions"]}`) is retired.
- **Precedence:** section comment, then document frontmatter, then the built-in default.
- **Typeahead (required):** on a line next to a heading, `<!-- ` offers the three keys, `key: ` offers that key's
  values, `; ` offers the keys not yet used, and accepting the first key inserts the closing ` -->`. Values come from
  the modules that enforce them (extending parley's `lua/parley/frontmatter_enum.lua`), never a second list.


Project `unified-editorial-interface`; follows the spec in ariadne (dependency). In parley:
- **Typeahead** for the new frontmatter keys and their values (key-name completion, `presentation-mode` and
  `processing-mode` values, `processing-instruction` free), extending `lua/parley/frontmatter_enum.lua`, with values
  drawn from the enforcing modules.
- **Heading-comment typeahead:** the `<!-- ` / `key: ` / `; ` flow on a line next to a heading, auto-inserting
  ` -->` on the first accepted key; works with nvim-cmp and with Vim's popup, as today.
- **Conceal** the heading comment as a small badge next to the heading (showing the effective overrides), revealed for
  editing when the cursor is on the line.


**Side-doc layout (decided 10-22):** `<doc>.side/YYYY-MM/YYYY-MM-DD-NN-slug.md`: a year-month subfolder, with the full date kept in the filename so a file still makes sense when linked, grepped or moved. **No migration:** existing flat names stay valid (readers accept both). Reason: `ops/session.side/` already holds about 270 entries, 261 from October alone. For this issue: make this repo's side-doc creator use the new layout and its readers accept both. Applies to the naming rule in the universal-review spec (`collaboration-modes.md` §4) and to every side-doc creator (parley, Couch, and tl-lead's side-doc helpers).

## Done when

- Typing `<!-- ` under a heading offers the three keys; `key: ` offers its values; `; ` offers only unused keys; the
  closing ` -->` is inserted (tests on both nvim versions).
- Frontmatter key and value completion covers all three keys (test).
- The comment renders as a badge and reveals on the cursor line (test).

## Plan

- [ ]

## Log

### 2026-10-22
