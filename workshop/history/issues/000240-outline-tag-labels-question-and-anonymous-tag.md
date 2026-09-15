---
id: 000240
status: done
deps: []
github_issue:
created: 2026-09-12
updated: 2026-09-14
estimate_hours: 1.345
started: 2026-09-14T20:14:11-07:00
actual_hours: 2.04
---

# Outline tag conventions: an @@tag@@ immediately before a question labels it; @@_@@ is anonymous and hides itself, or the question it precedes

## Problem

Since #232 every `@@…@@` line reaches the chat outline as its own item,
rendered at the question level (`"  → " .. text`, `outline.lua:43-49`), with
one item rule shared by the flat and tree builders. That makes the outline a
usable syllabus — but a tag and the question it annotates are still two rows,
and there is no way to keep a question *out* of the outline at all.

The operator's use (astro, the learning test bed): re-read a transcript, put
a short tag above a question so the outline reads as a curriculum of tags
rather than of full question text; and mark throwaway questions ("try
again", "shorter") so they stop cluttering the syllabus. Three conventions,
one mechanism:

1. **A tag on the line immediately before a question labels the question.**
   The outline shows the tag *in place of* the question's text — one row,
   not two.
2. **`@@_@@` is the anonymous tag.** It never appears in the outline.
3. **Together:** `@@_@@` immediately before a question removes that
   question from the outline structure entirely.

"Immediately before" is strict: the tag on line *i*, the `💬:` line on
*i+1*. A blank line between them breaks adjacency and both rows render as
today.

## Spec

**One post-pass over the item list, shared by both builders** — the same
shape #232 chose for the item rule (ARCH-DRY; the tree builder's private
rule is how annotations went missing for months). Both builders already
walk `all_lines`/`file_lines` and emit `{ display, value.lnum, type }` in
document order, so the pass is pure and needs only the items and the lines:

```
for each annotation item A whose text is T:
  if next item Q is a question with Q.lnum == A.lnum + 1:
    if T == "_": drop A and Q
    else:        Q.display = indent .. "  " .. T   (the question's row, labelled T)
                 drop A
  elif T == "_": drop A
```

Points that need deciding in code rather than left to the implementer:

- **The merged row is the question's row.** Its `type` stays `question`
  (the trailing-placeholder drop at `outline.lua:190/304` and anything else
  keyed on type keep working), and its `value.lnum` is the **question
  line**, so Enter lands where it lands today. The picker's
  cursor-to-item mapping (`find_nearest_outline_line`, `outline.lua:71`)
  must treat the tag line as belonging to that item: with the cursor on the
  tag line, the merged row is the selected one. Simplest: after the pass,
  the merged item records `value.tag_lnum = A.lnum`, and the mapping checks
  both.
- **Labelling only replaces the display.** Search/filter in the picker
  matches the tag, not the hidden question text — that is the point (the
  tag is the learner's own name for it). Say so in the help text.
- **`@@_@@` before a question hides the question from the outline, not from
  the chat.** Nothing about context building, highlighting, or the buffer
  changes. This is display-only, in one file.
- **Adjacency is line-exact.** No blank-line tolerance; the rule is easy to
  state and easy to see in the buffer.
- **Nested/inline branches**: the tree builder emits branch rows from the
  parser, not from lines, so a `🌿` row between a tag and a question cannot
  occur at adjacent line numbers; nothing to special-case. An annotation as
  the last item (no following question) renders as today.

**Context is untouched, by rule.** `@@…@@` lines are ordinary content to the
parser — they sit at the end of the previous answer and are sent to the
model — and the operator's rule is that everything authored is in context
except `🔒:`. Tags, `@@_@@` included, stay in. This issue changes only what
the outline shows.

## Done when

- `@@polar alignment@@` on the line above `💬: how do I…` → one outline row
  reading `polar alignment`, Enter jumps to the question, filter matches
  "polar".
- `@@_@@` alone → no row. `@@_@@` above a question → neither row; the
  outline's next row is the following question.
- A blank line between tag and question → two rows, as today.
- Flat and tree outlines agree (extend `outline_parity_spec.lua`); the pass
  has its own unit tests on hand-built item lists (merge, anonymous,
  anonymous+merge, non-adjacent, tag-as-last-item).
- Cursor on the tag line selects the merged row in the picker.

## Plan

- [x] Pure `apply_tag_conventions(items, lines)` in `outline.lua`; unit tests on hand-built items
- [x] Call it from `_build_picker_items` and the tree builder; parity test cases
- [x] `find_nearest_outline_line` / picker preselect: tag line maps to the merged row
- [x] Help text: tag replaces the label; `_` is anonymous

## Log


- 2026-09-14: closed — Full isolated make test: 260 files pass, lint clean; clipboard/prune/definition/drill-in regressions RED to GREEN; parser/context/outline/regeneration coverage passes; unrelated SVG prompt excluded.; review verdict: SHIP
### 2026-09-12

- Filed from the brain advisor session on the operator's conventions (1–3
  verbatim in Problem). Builds on #232, shipped 2026-09-12 (one item rule;
  annotations at the question level — the side-quest `8213799` set the
  indentation this issue's merged row inherits). Motivated by astro, where
  the outline is meant to read as a syllabus.
- **Measured: tags ARE sent to the model.** Headless probe through
  `chat_parser.parse_chat` with the unit-test config, tags mid-answer,
  end-of-answer (i.e. the line above the next question), and `@@_@@`:

      exchange 1 answer = "answer line A\n@@mid tag@@\nanswer line B\n@@end tag@@"
      exchange 2 answer = "answer two\n\n@@_@@"

  **Settled by the operator (2026-09-12): everything is in context except
  `🔒:`.** Tags stay in what the model sees, `@@_@@` included; the outline
  conventions in this issue are display-only and that is the whole of it.
  (`🌿:` is the other line withheld today, per `annotation.lua`, and it is
  a reference rather than content — the operator's rule is about authored
  text.) The "obvious next question" in the Spec is closed: not a decision
  to make later, a rule already made.
- Probe artifact worth a glance, not part of this issue: text on the `🤖:`
  prefix line itself (`🤖: first answer line one.`) was dropped from the
  answer content, while text on the `💬:` line is kept. parley never writes
  answers that way, so it is likely inert; noted so it is not rediscovered.

## Revisions

### 2026-09-14 — Question-owned context, approved by operator

Reason: operator asked that an adjacent tag prefix the following question's AI context, and approved the proposed strict-adjacency behavior. Delta supersedes the Spec's “Context is untouched” paragraph and the prior display-only decision: an eligible whole-line tag immediately before a question is included once, verbatim, at the beginning of that user message, and removed from the preceding assistant message. This includes `@@_@@`; hiding is only an outline convention. Blank-separated and non-adjacent tags remain where authored. The visible document and physical parser/model positions stay unchanged.

Use one pure association rule for outline labels and context ownership. Preserve attached tags when the preceding answer is regenerated; a tag belongs to the next question even if its physical line lies in the prior answer span. File-shaped markers keep existing file-reference semantics when projected into a question. Fenced lookalikes are excluded using the existing fence grammar and live prefixes.

Detailed implementation plan: `workshop/plans/000240-question-tag-ownership-plan.md`. Work is claimed; no production changes yet.

### 2026-09-14 — Exchange preface architecture

Operator requested: “extend the exchange structure and add a preface field to capture what's before a question that should be considered part of the question.” This supersedes the draft's virtual context snapshot approach. Parsed exchange.preface holds raw content and source span; live exchange.preface holds a derived size, without changing question block index or double-counting leading rows. Parser assigns the tag to the next exchange, all context builders compose preface+question, and rendering/resubmit retain physical placement. Full details are in the plan's authoritative Revisions section. No code changed.

## Estimate

Derived after the preface plan cleared plan-quality: architecture/consumer sweep baseline1.5h ×0.2 =0.3h design; parser/model/render + outline + context integrations and regression/full-suite/performance verification baseline2h ×0.4 =0.8h implementation; one fresh review, fixes and PR bookkeeping baseline0.5h ×0.4 =0.2h.15% design buffer adds0.045h. No overlap discount: integration and final verification remain serialized even with bounded agent work.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.3 impl=0.8
item: milestone-review design=0 impl=0.2
design-buffer: 0.15
total: 1.345
```

Baseline measured before implementation, synthetic100/1,000/5,000-line transcripts, median of11 after warmup: parse1.05/8.70/44.14ms, outline1.20/9.63/48.59ms. `/tmp/parley240-benchmark.lua` and `/tmp/parley240-baseline.json`; isolated profile and no providers.

### 2026-09-14 — Implementation checkpoint

Implemented exchange preface ownership through parser, live model, rendering, context, outline and cursor lookup. Bounded workers are finished. Focused suites passed: parser70, section7, build_messages84, ancestors9, respond integration73; model/render/tool regressions also passed. Regeneration regressions reproduce deletion with the original parser and pass with preface ownership. Cursor on a preface now resolves to its following exchange, including when the preceding question is unanswered. Full-suite and boundary review remain.

Synthetic median performance at5,000 lines: parse45.44ms (+1.30ms), outline51.16ms (+2.58ms), within the planned20ms incremental budget. Unrelated defaults and workshop chat edits are preserved outside this issue.

### 2026-09-14 — Verification complete

All plan work implemented under the approved exchange-preface revision (the shared helper is question_tags.apply_outline, superseding the original outline-local helper name). Full make test passed in an indexed isolated checkout excluding the unrelated pending SVG-default edit; lint clean and all test files passed. The working-checkout run confirmed that SVG edit alone changes11 golden payloads, so no unrelated defaults or golden fixtures were changed for this issue. Scoped diff check clean. Ready for boundary review.

### 2026-09-14 — Boundary review rework

Review returned REWORK: semantic ownership had not reached cut/paste/prune and scoped exchange context; parser classification ignored existing logging IO; README lacked a concise syntax note. Reproduced pruning and clipboard failures, added semantic_start and swept lookup/movement/context consumers. Plan revision records the consumer enumeration and parser classification correction. Targeted regression and fresh combined verification follow before re-review.

Rework verification: full isolated make test passed again (260 files, clean lint). Six clipboard, one prune, one definition-context and one drill-in regression demonstrated RED→GREEN. All reviewed semantic-start consumers now share the same helper; physical anchors remain unchanged.
