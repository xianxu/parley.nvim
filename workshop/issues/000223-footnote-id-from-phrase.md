---
id: 000223
status: open
deps: []
github_issue:
created: 2026-09-07
updated: 2026-09-07
estimate_hours:
---

# Footnote id comes from the model's term, not the selected phrase

## Problem

`render_definition` builds the footnote from the **model's** returned term:

```lua
define.apply_definition_footnote(lines, sr, sc - 1, er, ec - 1,
    input.term or phrase, input.definition)   -- init.lua:1895
```

`footnote_id(term)` slugs that, and the reference is inserted at the **user's
selection**. When the two disagree the artifact contradicts itself. Measured, in
a live transcript:

```
- Euclid[^liu-hui] (*Elements* XII.2, ~300 BCE) proved circles are proportional…
[^liu-hui]: A third-century CE Chinese mathematician, best known for his 263 CE…
```

The user selected *Euclid*; the model answered about *Liu Hui*. The model being
wrong is the model's problem — but parley then labels the anchor with an id that
names something else.

**Corrected 2026-09-08, after the operator pushed back.** I originally claimed
two consequences and could support neither:

- *"Reopened-chat recovery breaks."* **False.** `footnote_diagnostics`
  (`define.lua:318-336`) has a three-tier fallback — structured term, then slug,
  then expand backwards from the reference. Run against the exact transcript
  above it recovers `term="Euclid"` at the right column: the slug tier misses
  and the third tier gets it. I cited an atlas sentence about slug recovery and
  asserted breakage without running the code.
- *"The error is disguised."* Weak. The definition is visibly about someone else
  either way; the id is not what tells you the answer is wrong.

What actually remains:

- **Cosmetic incoherence.** `Euclid[^liu-hui]` reads oddly. Nothing misreads it.
- **One narrow collision.** `replace_or_append_footnote` keys on the id, so two
  different phrases whose definitions come back with the same `term` collapse to
  one footnote — the second overwrites the first. Real, but it needs the model to
  answer wrongly twice in the same direction, and repeatedly re-defining is not
  the workflow (operator).

Also not a reason to do this: the spurious `emit_definition` call in a branched
child. That is **#221** — once wildcard selectors mean "public only" the child
never sees the tool.

**So this is a Minor, not the defect the first draft described.** Worth doing
when the define path is open for another reason; not worth doing on its own.

## Spec

Derive the footnote **id** from the selected phrase, always. Keep the model's
`term` where it is useful — in the definition text — but never let it name the
anchor.

- `footnote_id` is fed `phrase`, not `input.term or phrase`.
- The rendered footer may still open with the model's term (`[^euclid]: "Liu
  Hui". A third-century…`) — that is informative, and it makes a mismatch
  visible instead of hiding it.
- Not in scope: detecting or correcting a mismatched definition. Parley cannot
  know the model answered about the wrong thing; making the artifact coherent is
  the whole fix.

## Done when

*(Unchanged; the fix is still one argument. The priority is what changed.)*

- The footnote id derives from the selected phrase; a definition whose `term`
  differs still anchors as `phrase[^phrase-slug]` — asserted with a model term
  that deliberately disagrees.
- Reopened-chat phrase recovery works for that case.
- The existing agreeing case is unchanged.

## Plan

- [ ] Pure test first: `term` ≠ `phrase` produces a phrase-derived id
- [ ] Change the call site; keep the model's term in the footer text
- [ ] Recovery test over a reopened transcript
- [ ] Atlas note in `chat/inline_define.md`

## Log

### 2026-09-07

Found while designing #222, in the operator's own transcript rather than by
reading code: they reported "Euclid returned a Chinese mathematician" as a model
error, which it partly was — the parley half is that the footnote id came from
the model instead of from the selection.
