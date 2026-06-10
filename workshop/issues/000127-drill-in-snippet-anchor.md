---
id: 000127
status: working
deps: []
github_issue:
created: 2026-06-10
updated: 2026-06-10
estimate_hours: 2.5
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

- [ ] Add pure `M.generate_snippet(text, marker)` to `drill_in.lua` — inline +
      standalone classification, word/sentence-boundary snapping, degradation.
- [ ] Wire it into `M.gather_and_strip` per the decouple snippet (block-quote
      vs inline-replacement); explicit-quote path untouched.
- [ ] Tests in `drill_in_spec.lua`: inline mid-sentence; inline short-sentence
      extends back; inline cap-at-20; standalone → prev-paragraph first sentence;
      standalone no-prev-prose degrades; marker at reply start degrades; bare
      marker mid-paragraph treated as inline; explicit-quote regression; mixed
      quoted+unquoted markers in document order.
- [ ] Run the suite; verify end-to-end in a scratch chat (`<C-g>g` on an
      unquoted comment shows the recovered `> snippet` in the new turn).

## Log

### 2026-06-10

Design converged in-session (parley brainstorm). Started as a `[^-N]` reference
scheme; talked it down to pure-snippet (no refs) once it was clear meaning-based
anchoring makes verbatim recurrence a non-issue and dissolves the counter /
conceal / edit-sync costs. Lineage: #123 (quoted body) → #124 (review
convention) → #125 (bounded multiline) → #127 (infer the quote when absent).
