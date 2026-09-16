---
gate: boundary-review
issue: 262
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-16T13:53:02-07:00"
      agent: claude
      boundary: M1
      blocked: false
      protocol_error: no valid findings block
    - "n": 2
      timestamp: "2026-09-16T14:06:15-07:00"
      agent: claude
      findings:
        - id: BR-1
          severity: Critical
          title: header floor exists only for chat-classified buffers; dae on line 1 of a markdown-classified transcript empties the file
          detail: "entity_range.lua:206 derives floor from parsed.header_end, and parsed is\nnon-nil only when not_chat() passed. not_chat rejects for five reasons\nunrelated to document shape (not under a chat root, non-timestamp\nfilename, <5 lines, missing topic, missing file header). Reproduced: a\ntranscript saved as notes-about-entities.md is classified markdown, the\nae map is still installed, and dae on line 1 reduces the buffer to a\nsingle empty line. With a blank \"# topic:\" both surfaces also delete a\nsection through EOF across the next \U0001F4AC:. Violates the issue Done-when and\natlas/chat/entity_delete.md:37. Fix: derive the floor from a pure\ntranscript_header_end(lines) (topic-shaped line 1 or front matter, plus a\n--- terminator) whenever parsed is absent."
          family: guard-gated-on-classification
          round: 2
        - id: BR-2
          severity: Critical
          title: the command path's unparsable-header refusal is unreachable when not_chat fails, so the two surfaces diverge
          detail: |-
            init.lua:4534-4545 puts the new refusal inside `if not reason then`.
            Editing the --- away leaves the latch at "chat" but makes not_chat return
            "missing header separator", so the guard is skipped and parsed_chat stays
            nil -- unclamped markdown semantics, no log line. Reproduced:
            :ParleyDeleteEntity on a heading inside the first answer deletes through
            EOF and swallows the next exchange, while `normal dae` on the identical
            state refuses. Breaks the parity claim the parity spec exists to defend.
          family: guard-gated-on-classification
          round: 2
        - id: BR-3
          severity: Important
          title: plan Task 11 Step 4 is ticked but no test exercises the streaming refusal
          detail: |-
            grep over tests/ for DeleteEntity/DeleteToEnd/replace_user_lines finds
            only the parity spec's two vim.cmd calls. The refusal is the single
            documented asymmetry between the surfaces, named in the issue Done-when,
            in the plan's ARCH-ORDER paragraph ("Task 11 tests the refusal") and in
            the parity spec's scoping comment. Deliver it or untick Step 4 and record
            the deferral.
          family: checkbox-without-artifact
          round: 2
        - id: BR-4
          severity: Important
          title: the parity spec varies only the cursor row, never the document shape, so classification divergence is invisible to it
          detail: |-
            tests/integration/entity_delete_parity_spec.lua always builds a
            well-formed chat, so all 24 rows exercise the same classification branch.
            Both Criticals above stay green under it. Parameterise fresh() over a
            valid fixture, one with the --- removed, and one with the `- file:`
            header removed, and loop the existing assertions over all three.
          family: parity-varies-only-cursor
          round: 2
        - id: BR-5
          severity: Minor
          title: section_range's floor parameter is dead code
          detail: |-
            entity_range.lua:88-90 can never fire: M.range:207 already returns nil
            for row < floor, and the to_end back-scan at :255 starts at floor. The
            second call site (:257) omits the argument. Drop it or make it the real
            enforcement point.
          family: unreachable-guard
          round: 2
        - id: BR-6
          severity: Minor
          title: parse_chat is pcall-wrapped on one surface and bare on the other, with two different warning strings for one condition
          detail: |-
            entity_textobj.lua:41 wraps parse_chat in pcall; init.lua:4544 calls
            M.parse_chat bare on identical input. The same "unreadable header"
            condition warns as "Parley: entity object needs a readable chat header…"
            on one surface and "DeleteEntity: chat header is unreadable…" on the
            other.
          family: inconsistent-error-handling
          round: 2
        - id: BR-7
          severity: Minor
          title: Core concepts table still names only outline.lua:52-60 as the modified outline consumer
          detail: |-
            plan.md:43 reads `lua/parley/outline.lua:52-60`; the diff also changed
            the token path at :254. The Revisions entry records this but the table
            row was never updated, so the table still understates the consumer set.
          family: plan-table-understates-code
          round: 2
        - id: BR-8
          severity: Minor
          title: README documents dae/daE/yae/cae but not ie, <C-g>k or <C-g>K
          detail: |-
            README.md:16-20 covers the outer objects only. atlas/ui/keybindings.md
            lists the full set, so this is a README-side omission of user-typed
            surface introduced in the same range.
          family: readme-omits-new-surface
          round: 2
        - id: BR-9
          severity: Minor
          title: the atlas perf figures cannot be re-derived from the repo
          detail: |-
            atlas/chat/entity_delete.md:80-88 records 13.6 / 24.7 / 97.8 ms, but no
            perf spec landed, so the numbers go stale silently when parse_chat
            changes.
          family: unreproducible-measurement
          round: 2
      boundary: M1
      blocked: true
---

# Gate ledger — parley.nvim#262 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-16T13:53:02-07:00 (claude) — passed

**Protocol error:** no valid findings block — this round contributed no findings.

## Round 2 — 2026-09-16T14:06:15-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Critical] `guard-gated-on-classification` header floor exists only for chat-classified buffers; dae on line 1 of a markdown-classified transcript empties the file
  entity_range.lua:206 derives floor from parsed.header_end, and parsed is
  non-nil only when not_chat() passed. not_chat rejects for five reasons
  unrelated to document shape (not under a chat root, non-timestamp
  filename, <5 lines, missing topic, missing file header). Reproduced: a
  transcript saved as notes-about-entities.md is classified markdown, the
  ae map is still installed, and dae on line 1 reduces the buffer to a
  single empty line. With a blank "# topic:" both surfaces also delete a
  section through EOF across the next 💬:. Violates the issue Done-when and
  atlas/chat/entity_delete.md:37. Fix: derive the floor from a pure
  transcript_header_end(lines) (topic-shaped line 1 or front matter, plus a
  --- terminator) whenever parsed is absent.
- **BR-2** [Critical] `guard-gated-on-classification` the command path's unparsable-header refusal is unreachable when not_chat fails, so the two surfaces diverge
  init.lua:4534-4545 puts the new refusal inside `if not reason then`.
  Editing the --- away leaves the latch at "chat" but makes not_chat return
  "missing header separator", so the guard is skipped and parsed_chat stays
  nil -- unclamped markdown semantics, no log line. Reproduced:
  :ParleyDeleteEntity on a heading inside the first answer deletes through
  EOF and swallows the next exchange, while `normal dae` on the identical
  state refuses. Breaks the parity claim the parity spec exists to defend.
- **BR-3** [Important] `checkbox-without-artifact` plan Task 11 Step 4 is ticked but no test exercises the streaming refusal
  grep over tests/ for DeleteEntity/DeleteToEnd/replace_user_lines finds
  only the parity spec's two vim.cmd calls. The refusal is the single
  documented asymmetry between the surfaces, named in the issue Done-when,
  in the plan's ARCH-ORDER paragraph ("Task 11 tests the refusal") and in
  the parity spec's scoping comment. Deliver it or untick Step 4 and record
  the deferral.
- **BR-4** [Important] `parity-varies-only-cursor` the parity spec varies only the cursor row, never the document shape, so classification divergence is invisible to it
  tests/integration/entity_delete_parity_spec.lua always builds a
  well-formed chat, so all 24 rows exercise the same classification branch.
  Both Criticals above stay green under it. Parameterise fresh() over a
  valid fixture, one with the --- removed, and one with the `- file:`
  header removed, and loop the existing assertions over all three.
- **BR-5** [Minor] `unreachable-guard` section_range's floor parameter is dead code
  entity_range.lua:88-90 can never fire: M.range:207 already returns nil
  for row < floor, and the to_end back-scan at :255 starts at floor. The
  second call site (:257) omits the argument. Drop it or make it the real
  enforcement point.
- **BR-6** [Minor] `inconsistent-error-handling` parse_chat is pcall-wrapped on one surface and bare on the other, with two different warning strings for one condition
  entity_textobj.lua:41 wraps parse_chat in pcall; init.lua:4544 calls
  M.parse_chat bare on identical input. The same "unreadable header"
  condition warns as "Parley: entity object needs a readable chat header…"
  on one surface and "DeleteEntity: chat header is unreadable…" on the
  other.
- **BR-7** [Minor] `plan-table-understates-code` Core concepts table still names only outline.lua:52-60 as the modified outline consumer
  plan.md:43 reads `lua/parley/outline.lua:52-60`; the diff also changed
  the token path at :254. The Revisions entry records this but the table
  row was never updated, so the table still understates the consumer set.
- **BR-8** [Minor] `readme-omits-new-surface` README documents dae/daE/yae/cae but not ie, <C-g>k or <C-g>K
  README.md:16-20 covers the outer objects only. atlas/ui/keybindings.md
  lists the full set, so this is a README-side omission of user-typed
  surface introduced in the same range.
- **BR-9** [Minor] `unreproducible-measurement` the atlas perf figures cannot be re-derived from the repo
  atlas/chat/entity_delete.md:80-88 records 13.6 / 24.7 / 97.8 ms, but no
  perf spec landed, so the numbers go stale silently when parse_chat
  changes.

## Open findings

- **BR-1** [Critical] `guard-gated-on-classification` header floor exists only for chat-classified buffers; dae on line 1 of a markdown-classified transcript empties the file
- **BR-2** [Critical] `guard-gated-on-classification` the command path's unparsable-header refusal is unreachable when not_chat fails, so the two surfaces diverge
- **BR-3** [Important] `checkbox-without-artifact` plan Task 11 Step 4 is ticked but no test exercises the streaming refusal
- **BR-4** [Important] `parity-varies-only-cursor` the parity spec varies only the cursor row, never the document shape, so classification divergence is invisible to it
- **BR-5** [Minor] `unreachable-guard` section_range's floor parameter is dead code
- **BR-6** [Minor] `inconsistent-error-handling` parse_chat is pcall-wrapped on one surface and bare on the other, with two different warning strings for one condition
- **BR-7** [Minor] `plan-table-understates-code` Core concepts table still names only outline.lua:52-60 as the modified outline consumer
- **BR-8** [Minor] `readme-omits-new-surface` README documents dae/daE/yae/cae but not ie, <C-g>k or <C-g>K
- **BR-9** [Minor] `unreproducible-measurement` the atlas perf figures cannot be re-derived from the repo
