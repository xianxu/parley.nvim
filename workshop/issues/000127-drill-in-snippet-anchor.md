---
id: 000127
status: done
deps: []
github_issue:
created: 2026-06-10
updated: 2026-06-10
estimate_hours: 2.5
actual_hours: 1.51
---

# Smart-snippet anchoring for unquoted drill-in comments

## Problem

When an unquoted marker `🤖[comment]` is gathered into the next user turn
(`drill_in.gather_and_strip`), the marker is stripped from the reply and the
comment floats into the new turn **with no anchor** — the next-turn agent reads
a free-floating comment with no idea which part of its prior reply it refers to.
Today only the *quoted* form `🤖<Q>[comment]` carries an anchor (the quoted
text is reproduced as `> Q`); the unquoted form loses position entirely
(`drill_in.lua:136`, `replacement = quoted_text or ""` → empty).

This is the flatten-vs-anchor coupling: moving the comment out of the reply
destroys the position it pointed at. The fix is to give the flattened comment a
recovered anchor.

## Spec

**Core reframe: an unquoted comment is a quoted comment whose quote we infer.**
For an unquoted *ready* marker, synthesize the `quoted` text from the reply
prose surrounding the marker, then let the **existing** quoted pipeline
(`format_block` → `> Q` / comment; `append_blocks`; both `chat_respond` paths)
do the rest unchanged. This is a DRY slot-in, not new machinery.

### Anchor = a verbatim snippet, not a reference token

Refs (`[^-N]` position tokens in the reply) were considered and **rejected**.
Rationale (keep this — it's the path not taken):
- LLMs anchor by *meaning*, not byte offset; a semantically-close snippet
  reliably routes attention to the right region.
- The "snippet recurs verbatim" case is a non-failure: if two spans mean the
  same thing, quoting either anchors the same meaning — position was never the
  question.
- Refs would cost a monotonic counter (frontmatter high-water mark), conceal
  rules, and a delete-sync burden (ref-in-reply + comment-in-turn = two spots).
  A pure snippet lives *with* its comment in the user turn — delete the comment,
  the anchor goes with it, atomically. No counter, no conceal, no frontmatter.

The only thing refs would have bought is disambiguating near-identical spots
("this number" among three look-alikes). Judged not worth the cost.

### Snippet rules (the one new function: `generate_snippet(text, marker)`)

Pure function of `(joined_text, marker.byte_start, marker.byte_end)`. Classify
by where the marker sits, after stripping it from its own line:

- **inline** — prose remains before the marker on its (stripped) line, OR the
  line is bare but *not* blank-line-separated (a hard break mid-paragraph):
  take the preceding **~10–20 words** ending at the marker, **snapped back to a
  sentence boundary** (`.!?` / paragraph start). If the current sentence is
  < 10 words, extend back across the boundary until ≥10 words or the paragraph
  start; cap at 20 (keep the words nearest the marker; prefix `…` if truncated).
- **standalone** — the marker is its own blank-line-separated paragraph: anchor
  = **first sentence of the previous prose block** (cap ~20 words).

### Degradation (all safe — empty snippet ⇒ today's bare-removal behavior)

- inline with nothing before it → fall back to the standalone rule.
- standalone with no previous *prose* block (reply start, or prev block is a
  heading / code fence / list / table) → first line of that block, else empty.
- empty snippet ⇒ `block.quoted = nil` ⇒ no `> ` line, exactly as today.

### The crux: decouple block-quote from inline-replacement

The synthesized snippet is **already present** in the reply (it's preceding
text we're quoting), so unlike the explicit-quote form it must **not** be
re-inserted inline — only the marker is removed. In `gather_and_strip`:

```lua
local explicit   = m.quoted and m.quoted.text or nil
local block_quote = explicit or generate_snippet(text, m)  -- inferred when unquoted
table.insert(blocks, { quoted = block_quote, sections = m.sections })
table.insert(replacements, {
    byte_start = m.byte_start, byte_end = m.byte_end,
    replacement = explicit or "",   -- unchanged: only an EXPLICIT quote restores inline
})
```

Explicit-quote behavior is byte-for-byte unchanged (regression-protected).

### LLM fallback — explicitly deferred (YAGNI)

A small-LLM "summarize the span" fallback was discussed. **Not now.** A verbatim
quote is a *strictly better* meaning-anchor than a paraphrase (no lossy
rewording), so the LLM buys nothing for anchor quality — only cosmetic
compaction for long/messy spans (code, tables). It would also tax the otherwise
instant `<C-g>g` transform with a round-trip + nondeterminism. It lives behind
the same `generate_snippet` seam, so deterministic-first costs nothing later —
it's a drop-in swap, not a rewrite.

## Done when

- Unquoted `🤖[comment]` gathered into the next turn carries a `> <snippet>`
  anchor recovered from the surrounding reply (inline and standalone rules).
- Explicit-quote form `🤖<Q>[comment]` behavior is unchanged.
- Snippet is never inserted inline (no duplication); only the marker is removed.
- Degradation cases yield an empty snippet and behave like today's bare removal.
- `generate_snippet` is a pure function with full unit coverage in
  `tests/unit/drill_in_spec.lua`; whole suite green.

## Plan

- [x] Add pure `M.generate_snippet(text, marker, opts)` to `drill_in.lua` —
      inline + standalone classification, word/sentence-boundary snapping,
      neighboring-marker stripping, `opts.boundaries` turn-prefix stops,
      degradation.
- [x] Wire it into `M.gather_and_strip` per the decouple snippet (block-quote
      vs inline-replacement); explicit-quote path untouched. `chat_respond`
      assembles config boundaries and threads `di_opts` into both call sites.
- [x] Tests in `drill_in_spec.lua`: all enumerated cases + turn-boundary
      cross-protection (both directions) + neighboring-marker strip +
      abbreviation-pin. 14 new + 2 updated; 90/90 in the file.
- [x] Ran the suite; demonstrated end-to-end on a realistic multi-paragraph
      reply (inline + standalone markers → correct `> snippet` blocks, header
      boundary respected).
- [x] **Referenced-span enclosing (added per operator request).** Refactor
      `generate_snippet` to offset-based selection returning the span byte range
      (behavior-preserving for the snippet text). `gather_and_strip` gains
      `opts.bracket`: explicit `<Q>` → `[Q]`; inferred span bracketed in place
      (inline absorbs gap+marker into `]`; standalone inserts `]` + removes
      marker). `chat_respond` enables it via `config.mark_reference_span`
      (default on). `ParleyReference` highlight (underline; `highlight.reference`
      override) + a conservative per-line matcher (skips `](` links, checkboxes,
      `[^..]`, 1-char). Tests: span-range + bracket cases (101/101 unit, 20/20
      integration). Brackets persist across reload; the experiment is one flag.

## Log

### 2026-06-10
- 2026-06-10: FIX-THEN-SHIP follow-ups before merge. Important: extracted pure
  `highlighter.is_reference_span` + `highlighter_spec.lua` (7 tests:
  link/footnote/checkbox/1-char skips) and added a live-🤖-marker-section skip
  (a marker's `[U]` chained after 🤖/`>`/`}` no longer double-marks while you
  compose). Minors: DRY'd boundary-prefix logic into `boundary_prefix_len` (3
  sites→1); dropped redundant checkbox checks; atlas notes `chat_local_prefix`.
  Incidental `claude-Opus-4-7`→`claude-opus-4-7` id-casing fix swept in — kept
  (correct). Forward notes (cosmetic/untested): nested bracket when a neighbor
  marker sits in the span window; multi-line unquoted marker. drill_in 101/101,
  highlighter 7/7, integration 20/20.
- 2026-06-10: closed — referenced-span [] enclosing both forms; generate_snippet offset-refactor returns span range (behavior-preserving); drill_in 101/101, integration 20/20; matcher selectivity verified ([train on Soviet soil]/[RedShift] color, [docs](),[ ],[1] skip); operator verified the live effect and approved; gated by config.mark_reference_span; review verdict: FIX-THEN-SHIP
- 2026-06-10: closed — drill_in_spec 90/90 (14 new+2 updated); generate_snippet inline+standalone+boundary+degradation covered; integration chat_respond_spec 20/20; e2e demo recovered correct > anchors for inline & standalone markers, header boundary respected; 8 unrelated pre-existing failures confirmed identical with edits stashed; review verdict: SHIP

Design converged in-session (parley brainstorm). Started as a `[^-N]` reference
scheme; talked it down to pure-snippet (no refs) once it was clear meaning-based
anchoring makes verbatim recurrence a non-issue and dissolves the counter /
conceal / edit-sync costs. Lineage: #123 (quoted body) → #124 (review
convention) → #125 (bounded multiline) → #127 (infer the quote when absent).

**Plan-quality judge (INFO, non-blocking) — resolved the standalone scan
boundary.** Both `gather_and_strip` call sites pass wide text (whole buffer /
full exchange), so a naive backward scan could pull a standalone marker's anchor
across a speaker boundary (the agent's comment anchored to the *user's* words,
or to a 🧠:/📎: block). Decision (ARCH-PURE preserved): `generate_snippet` takes
an optional `opts.boundaries` = list of turn-prefix strings; the backward scan
never crosses a line starting with one. The config→prefix coupling lives in the
`chat_respond` glue (the IO layer), which assembles `{💬: 🤖: 🧠: 📝: 🔧: 📎:
🌿:}` from config and threads it through. Confirmed from a real chat that `---`
is a *body* section separator (not a turn boundary) — so only the emoji-colon
prefixes bound the scan, never `---`. Judge's two advisory notes also handled:
neighboring raw markers are stripped from a candidate snippet (reuse `M.parse`);
abbreviation/decimal mis-snap on `.!?` accepted per the forgiving-anchor
philosophy (pinned by a test).

**Implemented.** `generate_snippet` + helpers (`index_lines`, `is_boundary_line`,
`split_sentences`, `tail_snippet`, `first_sentence_snippet`, `strip_markers`)
landed in `drill_in.lua`; `gather_and_strip` gained the explicit-vs-inferred
decouple + optional `opts`; `chat_respond` builds the boundary list from config
and threads it into both call sites. Atlas (`atlas/chat/drill_in.md`) updated
with an "Anchor inference (#127)" section + key-files note.

**Verification.** `drill_in_spec.lua` 90/90 green (76 baseline + 14 new, 2
updated). Full `tests/unit` sweep: the only failures are 8 pre-existing,
unrelated, env-dependent ones (note_finder ×4, super_repo ×1, chat_slug_resolve
×3) — confirmed identical with my edits stashed. `chat_respond.lua` loads clean;
integration `chat_respond_spec.lua` 20/20 green (uses only quoted markers, so the
unquoted-path change touches none). End-to-end demo on a realistic reply:
inline marker → `> Germany rebuilt its army…The Treaty of Rapallo let them`
(cross-line collect + sentence extension); standalone marker → `> Blitzkrieg was
less a new invention than a synthesis of old doctrine.` (prev-paragraph first
sentence), correctly stopping before the `🤖:[Claude]` header.

**Referenced-span enclosing (reopened — operator wants a persistent visual cue
of the referenced segment).** Folded into #127 rather than a follow-up.
- Chose literal `[]` per operator preference. It's the one cue that *persists*
  across the flatten + a file reload (extmark-only color would not — parley's
  inline-branch conceal re-derives extmarks from on-disk `[🌿:..]()` text each
  render; after flatten there's no marker to re-derive from, so the cue must be
  in the text). `ParleyReviewQuoted` (reverse+bold on `🤖<…>`) already marks the
  scope but only while the *live* marker exists.
- Needed the span's byte range → refactored `generate_snippet` to offset-based
  token selection (`tokenize`/`select_tail`/`select_head`/`span_text`),
  reproducing every prior snippet text (93→101 tests stay green) and returning
  `(text, span_start, span_end)`. Removed now-dead `split_sentences`/`word_count`.
- Coloring caveat (told operator): plain `[]` can't be told apart from
  markdown links / incidental brackets / single-word explicit quotes
  (`[RedShift]` looks like any bracketed word). The matcher is a heuristic
  (skip `](`, checkboxes, `[^..]`, 1-char); residual false positives on genuine
  multi-char agent `[brackets]`). Gated by `config.mark_reference_span` so the
  whole experiment is one flag — operator will evaluate the rendered effect and
  decide whether to keep it / switch to a distinguishable delimiter.
