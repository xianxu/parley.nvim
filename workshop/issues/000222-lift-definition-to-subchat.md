---
id: 000222
status: open
deps: []
github_issue:
created: 2026-09-07
updated: 2026-09-07
estimate_hours:
---

# Lift a definition into a sub-chat with <M-i>

## Problem

`<M-CR>` on a selection gives you a definition inline, as a markdown footnote —
good for a term you just need to know. But a definition can be *wrong*, or
merely the start of something you want to pull on, and there is currently no
move from "I have a footnote" to "let me argue with this."

Operator, verified in a live transcript: defined **Euclid**, got back *"a
third-century CE Chinese mathematician…"* — a definition of Liu Hui. Reaction:
*"that's not a Chinese name even!"* The next thing you want is to challenge it,
which today means retyping the definition into a new chat by hand.

The `<M-i>` chord already means **"branch from here, carrying what is here."** A
footnote is a thing that is here.

## Spec

`<M-i>` with the cursor on a footnote **reference** (`Euclid[^liu-hui]`) or on
its **footer line** (`[^liu-hui]: …`) lifts that definition into a child chat.

- **The child** opens seeded with the definition as a quote, and the cursor in
  insert mode beneath it, so the follow-up is typed there:

  ```
  💬:
  > Euclid: A third-century CE Chinese mathematician, best known for…

  ```

- **The parent** loses the footnote — both the `[^id]` marker and the `[^id]:`
  footer, because a marker with no footer is a dangling reference. The anchor
  text stays, wrapped as an inline branch link:

  ```
  - Euclid[^liu-hui] (*Elements* XII.2 …      →   - [🌿:Euclid](0907.…md) (*Elements* XII.2 …
  ```

  That is exactly what the visual-selection case already produces, so a lifted
  definition and a branched selection leave the parent in the same shape.

- **Either end works.** The cursor may be on the reference or on the footer; a
  reader challenging a definition is usually looking at whichever one they were
  reading.

- **The definition is the payload, not a re-derivation.** Quote what the footer
  says. The child is where the argument happens; parley does not re-ask.

**Where this sits in the chord.** `branch_submit.plan_submission` decides what
`<M-i>` carries. It currently returns a plan only for the pending-`<M-q>` case.
This is a second case — cursor on a footnote — with the same shape: strip
something from the parent, seed the child with it, leave a reference. The
placement rule is unchanged (at the cursor) and so is the never-deletes rule:
the footnote is not deleted, it *moves*.

**Interaction to get right.** `#214 BR-75/BR-79` established that a resubmit
keeps annotations, including inline `[🌿:…](file)` links. A lifted definition
produces exactly such a link, so it inherits that protection — worth an explicit
test rather than an assumption.

## Done when

- `<M-i>` on a footnote reference, and on a footer line, both lift: child
  created and seeded with the quoted definition, footnote fully removed from the
  parent (marker and footer), anchor text left as an inline branch link.
- Driven through the real keymap callback on a real chat buffer, not the planner
  alone.
- No dangling `[^id]` survives in the parent — asserted.
- A lifted definition's link survives a resubmit of its exchange (#214 BR-79).
- `<M-i>` elsewhere is unchanged: the three existing cases keep their behaviour,
  asserted so this case cannot capture them.

## Plan

- [ ] Pure: locate the footnote at a cursor line (reference or footer) and
      return `{ id, anchor_span, footer_line, definition }`; unit-tested with no
      buffer
- [ ] Extend `plan_submission` with the case; the existing three stay untouched
- [ ] Effects in `branch_inserters`: remove marker + footer, splice the inline
      link, seed the child
- [ ] Integration: both cursor positions, the no-dangling-reference assertion,
      and the resubmit-survival test
- [ ] Atlas + README

## Log

### 2026-09-07

Operator request during the #214 smoke test, after `<M-i>` was verified working.
Filed separately from #214: that issue is closed on all three milestones and is
already 4x its estimate, and this is a new case rather than a fix to what
shipped.

Related: **#223** — the footnote id is derived from the model's returned `term`
rather than the selected phrase, which is why the Euclid case produced
`Euclid[^liu-hui]`. Independent defect; this feature works either way, but the
quote a lift produces reads better once the id and the anchor agree.
